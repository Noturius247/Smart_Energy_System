import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_html/html.dart' as html;
import '../realtime_db_service.dart';
import '../due_date_provider.dart';
import '../constants.dart';
import '../models/usage_history_entry.dart';
import '../services/usage_history_service.dart';

enum AggregationType {
  hourly,
  daily,
  weekly,
  monthly,
}

class EnergyHistoryScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;
  const EnergyHistoryScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergyHistoryScreen> createState() => _EnergyHistoryScreenState();
}

class _EnergyHistoryScreenState extends State<EnergyHistoryScreen> {
  late RealtimeDbService _realtimeDbService;
  List<HistoryRecord> _historyRecords = [];
  List<HistoryRecord> _filteredHistoryRecords = [];
  bool _isLoading = true;
  AggregationType _selectedAggregation = AggregationType.daily;
  StreamSubscription<String>? _hubRemovedSubscription;
  StreamSubscription<Map<String, String>>? _hubAddedSubscription;

  // -- Pagination state for Central Hub Data --
  final ScrollController _historyScrollController = ScrollController();
  bool _isLoadingMoreHistory = false;
  bool _canLoadMoreHistory = true;
  static const int _historyPageLimit = 10; // Optimized: Reduced from 15 for better efficiency with multiple hubs
  Timer? _historyScrollDebounce; // Debounce timer for scroll events

  // -- Cache for aggregation data to avoid refetching --
  final Map<String, List<HistoryRecord>> _aggregationCache = {};
  List<Map<String, String>>? _cachedHubList; // Cache hub list to avoid repeated queries

  // Usage History - Live calculation from readings
  late UsageHistoryService _usageHistoryService;
  List<UsageHistoryEntry> _usageHistoryEntries = [];
  List<UsageHistoryEntry> _filteredUsageHistoryEntries = [];
  bool _isLoadingUsageHistory = false;
  UsageInterval _selectedUsageInterval = UsageInterval.daily;
  String? _selectedHubForUsage;
  List<Map<String, String>> _availableHubs = [];
  int _usageHistoryOffset = 0; // For pagination/scrolling
  final ScrollController _usageScrollController = ScrollController();


  // Sorting state
  String? _sortColumn;
  bool _sortAscending = true;

  // Calculator state
  final TextEditingController _kwhController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  double _calculatedCost = 0.0;

  // Previous data for comparison
  List<HistoryRecord> _previousHistoryRecords = [];

  // Color mapping for each aggregation type
  Color _getAggregationColor(AggregationType type) {
    switch (type) {
      case AggregationType.hourly:
        return Colors.blue;
      case AggregationType.daily:
        return Colors.green;
      case AggregationType.weekly:
        return Colors.orange;
      case AggregationType.monthly:
        return Colors.purple;
    }
  }

  @override
  void initState() {
    super.initState();
    _realtimeDbService = widget.realtimeDbService;
    _usageHistoryService = UsageHistoryService(_realtimeDbService);
    _loadHistoryData(); // Initial data load
    _loadAvailableHubs();
    _startHubRemovedListener();
    _startHubAddedListener();

    // Setup scroll listener for infinite scroll for both tables
    _usageScrollController.addListener(_onUsageScroll);
    _historyScrollController.addListener(_onHistoryScroll);
  }

  void _onUsageScroll() {
    if (_usageScrollController.position.pixels >= _usageScrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingUsageHistory) {
        _loadMoreUsageHistory();
      }
    }
  }

  void _onHistoryScroll() {
    // Debounce scroll events to prevent rapid-fire downloads
    _historyScrollDebounce?.cancel();
    _historyScrollDebounce = Timer(const Duration(milliseconds: 300), () {
      if (_historyScrollController.position.pixels >= _historyScrollController.position.maxScrollExtent * 0.8) {
        if (_canLoadMoreHistory && !_isLoadingMoreHistory) {
          _loadMoreHistory();
        }
      }
    });
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMoreHistory || !_canLoadMoreHistory) return;

    setState(() => _isLoadingMoreHistory = true);
    debugPrint('[EnergyHistory] Loading more history data...');

    // Use the key of the last record as the cursor for the next page
    final String? lastKey = _historyRecords.isNotEmpty ? _historyRecords.last.periodKey : null;

    await _loadHistoryData(endAtKey: lastKey);

    setState(() => _isLoadingMoreHistory = false);
  }

  Future<void> _loadAvailableHubs({bool forceRefresh = false}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use cached hub list if available and not forcing refresh
    if (_cachedHubList != null && !forceRefresh) {
      setState(() {
        _availableHubs = _cachedHubList!;
        if (_availableHubs.isNotEmpty && _selectedHubForUsage == null) {
          _selectedHubForUsage = _availableHubs.first['serialNumber'];
        }
      });
      return;
    }

    try {
      final hubSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (hubSnapshot.exists && hubSnapshot.value != null) {
        final allHubs = json.decode(json.encode(hubSnapshot.value)) as Map<String, dynamic>;
        final List<Map<String, String>> hubList = [];

        for (final serialNumber in allHubs.keys) {
          final hubData = allHubs[serialNumber] as Map<String, dynamic>;
          final String? nickname = hubData['nickname'] as String?;

          hubList.add({
            'serialNumber': serialNumber,
            'nickname': nickname ?? 'Central Hub',
          });
        }

        // Cache the hub list
        _cachedHubList = hubList;

        setState(() {
          final previouslySelectedHub = _selectedHubForUsage;
          _availableHubs = hubList;

          if (hubList.isNotEmpty) {
            // Check if the previously selected hub still exists
            final stillExists = hubList.any((hub) => hub['serialNumber'] == previouslySelectedHub);

            if (stillExists) {
              _selectedHubForUsage = previouslySelectedHub;
            } else {
              _selectedHubForUsage = hubList.first['serialNumber'];
              debugPrint('[EnergyHistory] Previously selected hub removed, switching to: $_selectedHubForUsage');
            }
            _loadUsageHistory();
          } else {
            _selectedHubForUsage = null;
            _usageHistoryEntries = [];
            debugPrint('[EnergyHistory] No hubs available, cleared usage history');
          }
        });
      } else {
        // No hubs found in database
        _cachedHubList = [];
        setState(() {
          _availableHubs = [];
          _selectedHubForUsage = null;
          _usageHistoryEntries = [];
        });
      }
    } catch (e) {
      debugPrint('[EnergyHistory] Error loading hubs: $e');
    }
  }

  Future<void> _loadUsageHistory() async {
    if (_selectedHubForUsage == null) return;

    setState(() => _isLoadingUsageHistory = true);

    try {
      final dueDateProvider = Provider.of<DueDateProvider>(context, listen: false);

      // Load ALL available data (service will return all data when offset is 0)
      // The minRows parameter is now just a placeholder for the initial load
      final minRows = 1000; // Large number to ensure we get all data

      final entries = await _usageHistoryService.calculateUsageHistory(
        hubSerialNumber: _selectedHubForUsage!,
        interval: _selectedUsageInterval,
        customDueDate: dueDateProvider.dueDate,
        minRows: minRows,
        offset: 0,
      );

      setState(() {
        _usageHistoryEntries = entries;
        _filteredUsageHistoryEntries = List.from(entries);
        _usageHistoryOffset = 0;
        _isLoadingUsageHistory = false;
      });
    } catch (e) {
      debugPrint('[EnergyHistory] Error loading usage history: $e');
      setState(() => _isLoadingUsageHistory = false);
    }
  }

  Future<void> _loadMoreUsageHistory() async {
    if (_selectedHubForUsage == null) return;

    setState(() => _isLoadingUsageHistory = true);

    try {
      final dueDateProvider = Provider.of<DueDateProvider>(context, listen: false);
      final newOffset = _usageHistoryOffset + 10;

      final entries = await _usageHistoryService.calculateUsageHistory(
        hubSerialNumber: _selectedHubForUsage!,
        interval: _selectedUsageInterval,
        customDueDate: dueDateProvider.dueDate,
        minRows: 10,
        offset: newOffset,
      );

      setState(() {
        _usageHistoryEntries.addAll(entries);
        _filteredUsageHistoryEntries = List.from(_usageHistoryEntries);
        _usageHistoryOffset = newOffset;
        _isLoadingUsageHistory = false;
      });
    } catch (e) {
      debugPrint('[EnergyHistory] Error loading more usage history: $e');
      setState(() => _isLoadingUsageHistory = false);
    }
  }

  void _startHubRemovedListener() {
    _hubRemovedSubscription = _realtimeDbService.hubRemovedStream.listen((removedHubSerial) {
      if (!mounted) return;
      debugPrint('[EnergyHistory] Hub removed event received: $removedHubSerial. Updating caches...');
      final bool wasSelectedHub = _selectedHubForUsage == removedHubSerial;

      // OPTIMIZED: Only invalidate affected data, not entire cache
      // Remove records for the deleted hub from cache instead of clearing everything
      for (var cacheKey in _aggregationCache.keys) {
        _aggregationCache[cacheKey] = _aggregationCache[cacheKey]!
            .where((record) => record.hubName != removedHubSerial)
            .toList();
      }
      _cachedHubList = null; // Only clear hub list cache

      // Reload hub list and history with force refresh
      _loadAvailableHubs(forceRefresh: true).then((_) {
        if (wasSelectedHub && _availableHubs.isEmpty) {
          setState(() {
            _usageHistoryEntries = [];
            _selectedHubForUsage = null;
          });
        }
      });
      _loadHistoryData(forceRefresh: true); // Single call with force refresh

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hub $removedHubSerial has been unlinked. ${wasSelectedHub ? 'Usage history updated.' : 'History updated.'}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _startHubAddedListener() {
    _hubAddedSubscription = _realtimeDbService.hubAddedStream.listen((hubData) {
      if (!mounted) return;
      final String serialNumber = hubData['serialNumber']!;
      final String nickname = hubData['nickname'] ?? 'Central Hub';
      debugPrint('[EnergyHistory] Hub added event received: $serialNumber. Updating caches...');

      // OPTIMIZED: Keep existing cache, just invalidate hub list
      // No need to clear aggregation cache since new hub won't have old cached data
      _cachedHubList = null; // Only clear hub list cache

      // Reload hub list and history with force refresh
      _loadAvailableHubs(forceRefresh: true).then((_) {
        if (_availableHubs.length == 1) {
          debugPrint('[EnergyHistory] First hub added, automatically loading usage history');
        }
      });
      _loadHistoryData(forceRefresh: true); // Single call with force refresh

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$nickname has been linked. History updated.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  /// Refactored to support pagination for the Central Hub Data table with caching and parallel queries.
  Future<void> _loadHistoryData({String? endAtKey, bool forceRefresh = false}) async {
    // Check cache first (only for initial load, not pagination)
    if (endAtKey == null && !forceRefresh) {
      final cacheKey = _selectedAggregation.name;
      if (_aggregationCache.containsKey(cacheKey)) {
        setState(() {
          _historyRecords = _aggregationCache[cacheKey]!;
          _filteredHistoryRecords = List.from(_historyRecords); // CRITICAL: Update filtered records too!
          _isLoading = false;
          _canLoadMoreHistory = true;
        });
        debugPrint('[EnergyHistory] Loaded from cache: $cacheKey (${_historyRecords.length} records)');
        return;
      }
    }

    // For initial load, show main spinner. For subsequent loads, use the bottom spinner.
    if (endAtKey == null) {
      setState(() => _isLoading = true);
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (endAtKey == null) setState(() => _isLoading = false);
        return;
      }

      // Use cached hub list if available to avoid extra query
      Map<String, dynamic> hubs;
      if (_cachedHubList != null && _cachedHubList!.isNotEmpty) {
        hubs = {for (var hub in _cachedHubList!) hub['serialNumber']!: {'nickname': hub['nickname'], 'assigned': true, 'ownerId': user.uid}};
      } else {
        // First, get the list of user's hubs
        final hubSnapshot = await FirebaseDatabase.instance
            .ref('$rtdbUserPath/hubs')
            .orderByChild('ownerId')
            .equalTo(user.uid)
            .get();

        if (!hubSnapshot.exists) {
          if (endAtKey == null) {
            setState(() {
              _historyRecords = [];
              _isLoading = false;
              _canLoadMoreHistory = false;
            });
          }
          return;
        }
        hubs = Map<String, dynamic>.from(hubSnapshot.value as Map);
      }

      List<HistoryRecord> newRecords = [];
      String aggregationType = _selectedAggregation.name;

      // OPTIMIZATION: Fetch data for all hubs in parallel instead of sequentially
      final futures = hubs.entries.map((hubEntry) async {
        final hubData = hubEntry.value is Map ? Map<String, dynamic>.from(hubEntry.value) : {'nickname': null, 'assigned': true, 'ownerId': user.uid};
        final String serialNumber = hubEntry.key;
        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        if (!isAssigned || hubOwnerId != user.uid) return <HistoryRecord>[];

        final String hubNickname = hubData['nickname'] as String? ?? 'Hub ${serialNumber.substring(0, 6)}';

        try {
          final paginatedData = await _realtimeDbService.getAggregatedDataPaginated(
            hubSerialNumber: serialNumber,
            aggregationType: aggregationType,
            limit: _historyPageLimit,
            endAtKey: endAtKey,
          );

          final hubRecords = <HistoryRecord>[];
          for (var entry in paginatedData.entries) {
            final String timeKey = entry.key;
            final data = Map<String, dynamic>.from(entry.value);

            DateTime timestamp;
            if (data['timestamp'] != null) {
              timestamp = DateTime.parse(data['timestamp']);
            } else {
              timestamp = _parseTimestampFromKey(timeKey, _selectedAggregation);
            }

            hubRecords.add(HistoryRecord(
              timestamp: timestamp,
              deviceName: 'All Devices',
              hubName: hubNickname,
              averagePower: (data['average_power'] ?? 0).toDouble(),
              minPower: (data['min_power'] ?? 0).toDouble(),
              maxPower: (data['max_power'] ?? 0).toDouble(),
              averageVoltage: (data['average_voltage'] ?? 0).toDouble(),
              minVoltage: (data['min_voltage'] ?? 0).toDouble(),
              maxVoltage: (data['max_voltage'] ?? 0).toDouble(),
              averageCurrent: (data['average_current'] ?? 0).toDouble(),
              minCurrent: (data['min_current'] ?? 0).toDouble(),
              maxCurrent: (data['max_current'] ?? 0).toDouble(),
              totalEnergy: (data['total_energy'] ?? 0).toDouble(),
              totalReadings: (data['total_readings'] ?? data['total_readings_in_snapshot'] ?? 0).toInt(),
              aggregationType: _selectedAggregation,
              periodKey: timeKey,
            ));
          }
          return hubRecords;
        } catch (e) {
          debugPrint('[EnergyHistory] Error loading data for hub $serialNumber: $e');
          return <HistoryRecord>[];
        }
      });

      // Wait for all hub queries to complete in parallel
      final results = await Future.wait(futures);
      for (var hubRecords in results) {
        newRecords.addAll(hubRecords);
      }

      // Sort all records fetched from all hubs by timestamp
      newRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        if (endAtKey == null) {
          // Initial load - cache the results
          _previousHistoryRecords = List.from(_historyRecords);
          _historyRecords = newRecords;
          _filteredHistoryRecords = List.from(newRecords);
          if (!forceRefresh) {
            _aggregationCache[_selectedAggregation.name] = newRecords;
            debugPrint('[EnergyHistory] Cached ${newRecords.length} records for ${_selectedAggregation.name}');
          }
        } else {
          // Loading more, append new records
          _historyRecords.addAll(newRecords);
          _filteredHistoryRecords = List.from(_historyRecords);
        }

        // If we received fewer records than we asked for, we've reached the end
        if (newRecords.length < _historyPageLimit) {
          _canLoadMoreHistory = false;
        } else {
          _canLoadMoreHistory = true;
        }

        _isLoading = false;
        _isLoadingMoreHistory = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMoreHistory = false;
      });
    }
  }

  DateTime _parseTimestampFromKey(String key, AggregationType type) {
    try {
      switch (type) {
        case AggregationType.hourly:
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]), int.parse(parts[3]));
        case AggregationType.daily:
          return DateTime.parse(key);
        case AggregationType.weekly:
          final parts = key.split('-W');
          final year = int.parse(parts[0]);
          final week = int.parse(parts[1]);
          return _getDateFromWeek(year, week);
        case AggregationType.monthly:
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _getDateFromWeek(int year, int week) {
    DateTime jan1 = DateTime(year, 1, 1);
    int daysToAdd = (week - 1) * 7;
    int dayOfWeek = jan1.weekday;
    if (dayOfWeek <= 4) {
      daysToAdd -= (dayOfWeek - 1);
    } else {
      daysToAdd += (8 - dayOfWeek);
    }
    return jan1.add(Duration(days: daysToAdd));
  }

  String _formatTimestamp(DateTime timestamp, AggregationType type) {
    switch (type) {
      case AggregationType.hourly:
        return DateFormat('MMM dd, HH:00').format(timestamp);
      case AggregationType.daily:
        return DateFormat('MMM dd, yyyy').format(timestamp);
      case AggregationType.weekly:
        final weekNumber = ((timestamp.difference(DateTime(timestamp.year, 1, 1)).inDays) / 7).ceil();
        return 'Week $weekNumber, ${timestamp.year}';
      case AggregationType.monthly:
        return DateFormat('MMMM yyyy').format(timestamp);
    }
  }

  String _getPeriodLabel(HistoryRecord record) {
    switch (record.aggregationType) {
      case AggregationType.hourly:
        return DateFormat('MMM dd, HH:00').format(record.timestamp);
      case AggregationType.daily:
        return DateFormat('MMM dd').format(record.timestamp);
      case AggregationType.weekly:
        return record.periodKey.replaceAll('2025-', '');
      case AggregationType.monthly:
        return DateFormat('MMM yyyy').format(record.timestamp);
    }
  }

  void _calculateCost() {
    final kwh = double.tryParse(_kwhController.text) ?? 0.0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    setState(() {
      _calculatedCost = kwh * price;
    });
  }

  void _sortBy(String column) {
    setState(() {
      // Update sort column and direction
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }

      // Apply sorting immediately within the same setState to avoid double rebuilds
      if (_sortColumn != null) {
        _filteredHistoryRecords.sort((a, b) {
          int comparison = 0;
          switch (_sortColumn) {
            case 'period':
              comparison = a.timestamp.compareTo(b.timestamp);
              break;
            case 'hub':
              comparison = a.hubName.compareTo(b.hubName);
              break;
            case 'power':
              comparison = a.averagePower.compareTo(b.averagePower);
              break;
            case 'energy':
              comparison = a.totalEnergy.compareTo(b.totalEnergy);
              break;
            case 'voltage':
              comparison = a.averageVoltage.compareTo(b.averageVoltage);
              break;
            case 'current':
              comparison = a.averageCurrent.compareTo(b.averageCurrent);
              break;
            case 'readings':
              comparison = a.totalReadings.compareTo(b.totalReadings);
              break;
          }
          return _sortAscending ? comparison : -comparison;
        });
      }
    });
  }

  // Get percentage change from previous period
  double _getPercentageChange(double current, double previous) {
    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }

  // Get color based on energy level
  Color _getEnergyLevelColor(double energy) {
    if (energy < 5) return Colors.green;
    if (energy < 15) return Colors.orange;
    return Colors.red;
  }

  // Get usage calculation description based on selected interval
  String _getUsageCalculationDescription() {
    switch (_selectedUsageInterval) {
      case UsageInterval.hourly:
        return 'Hourly: Current Hour Reading - Previous Hour Reading = Usage for that hour';
      case UsageInterval.daily:
        return 'Daily: Current Day Reading - Previous Day Reading = Usage for that day';
      case UsageInterval.weekly:
        return 'Weekly: Current Week Reading - Previous Week Reading = Usage for that week';
      case UsageInterval.monthly:
        return 'Monthly: Current Month Reading - Previous Month Reading = Usage for that month';
    }
  }

  // Get color for each interval type
  Color getIntervalColor(UsageInterval interval) {
    switch (interval) {
      case UsageInterval.hourly: return Colors.cyan;
      case UsageInterval.daily: return Colors.teal;
      case UsageInterval.weekly: return Colors.amber;
      case UsageInterval.monthly: return Colors.deepPurple;
    }
  }

  /// EFFICIENT Excel export for Central Hub Data with progress indicator
  Future<void> _exportCentralHubDataToExcel() async {
    if (_historyRecords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Fetching all data for export...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Fetch ALL data from the database (not just the paginated view)
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }

      List<HistoryRecord> allRecords = [];
      String aggregationType = _selectedAggregation.name;

      // Get all hubs
      Map<String, dynamic> hubs;
      if (_cachedHubList != null && _cachedHubList!.isNotEmpty) {
        hubs = {for (var hub in _cachedHubList!) hub['serialNumber']!: {'nickname': hub['nickname'], 'assigned': true, 'ownerId': user.uid}};
      } else {
        final hubSnapshot = await FirebaseDatabase.instance
            .ref('$rtdbUserPath/hubs')
            .orderByChild('ownerId')
            .equalTo(user.uid)
            .get();

        if (!hubSnapshot.exists) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hubs found'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        hubs = Map<String, dynamic>.from(hubSnapshot.value as Map);
      }

      // Fetch ALL data for each hub (no pagination limit for export)
      final futures = hubs.entries.map((hubEntry) async {
        final hubData = hubEntry.value is Map ? Map<String, dynamic>.from(hubEntry.value) : {'nickname': null, 'assigned': true, 'ownerId': user.uid};
        final String serialNumber = hubEntry.key;
        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        if (!isAssigned || hubOwnerId != user.uid) return <HistoryRecord>[];

        final String hubNickname = hubData['nickname'] as String? ?? 'Hub ${serialNumber.substring(0, 6)}';

        try {
          // Fetch ALL data (limit set to a very large number to get everything)
          final allData = await _realtimeDbService.getAggregatedDataPaginated(
            hubSerialNumber: serialNumber,
            aggregationType: aggregationType,
            limit: 10000, // Large limit to get all data
            endAtKey: null,
          );

          final hubRecords = <HistoryRecord>[];
          for (var entry in allData.entries) {
            final String timeKey = entry.key;
            final data = Map<String, dynamic>.from(entry.value);

            DateTime timestamp;
            if (data['timestamp'] != null) {
              timestamp = DateTime.parse(data['timestamp']);
            } else {
              timestamp = _parseTimestampFromKey(timeKey, _selectedAggregation);
            }

            hubRecords.add(HistoryRecord(
              timestamp: timestamp,
              deviceName: 'All Devices',
              hubName: hubNickname,
              averagePower: (data['average_power'] ?? 0).toDouble(),
              minPower: (data['min_power'] ?? 0).toDouble(),
              maxPower: (data['max_power'] ?? 0).toDouble(),
              averageVoltage: (data['average_voltage'] ?? 0).toDouble(),
              minVoltage: (data['min_voltage'] ?? 0).toDouble(),
              maxVoltage: (data['max_voltage'] ?? 0).toDouble(),
              averageCurrent: (data['average_current'] ?? 0).toDouble(),
              minCurrent: (data['min_current'] ?? 0).toDouble(),
              maxCurrent: (data['max_current'] ?? 0).toDouble(),
              totalEnergy: (data['total_energy'] ?? 0).toDouble(),
              totalReadings: (data['total_readings'] ?? data['total_readings_in_snapshot'] ?? 0).toInt(),
              aggregationType: _selectedAggregation,
              periodKey: timeKey,
            ));
          }
          return hubRecords;
        } catch (e) {
          debugPrint('[EnergyHistory] Error loading all data for hub $serialNumber: $e');
          return <HistoryRecord>[];
        }
      });

      // Wait for all hub queries to complete
      final results = await Future.wait(futures);
      for (var hubRecords in results) {
        allRecords.addAll(hubRecords);
      }

      // Sort all records by timestamp
      allRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint('[EnergyHistory] Fetched ${allRecords.length} records for export');

      // Create Excel file efficiently
      final excel = excel_lib.Excel.createExcel();

      // Create our custom sheet first
      excel.copy('Sheet1', 'Central Hub Data');

      // Remove default sheet
      excel.delete('Sheet1');

      final sheet = excel['Central Hub Data'];

      // Add headers with styling
      final headerStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.green,
        fontColorHex: excel_lib.ExcelColor.white,
        bold: true,
      );

      // Add headers
      final headers = ['Period', 'Hub Name', 'Avg Power (W)', 'Min Power (W)', 'Max Power (W)',
                       'Total Energy (kWh)', 'Avg Voltage (V)', 'Min Voltage (V)', 'Max Voltage (V)',
                       'Avg Current (A)', 'Min Current (A)', 'Max Current (A)', 'Total Readings'];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = excel_lib.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Add ALL data rows (not just the paginated view)
      for (var i = 0; i < allRecords.length; i++) {
        final record = allRecords[i];
        final rowIndex = i + 1;

        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
            excel_lib.TextCellValue(_getPeriodLabel(record));
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            excel_lib.TextCellValue(record.hubName);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.averagePower);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.minPower);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.maxPower);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.totalEnergy);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.averageVoltage);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.minVoltage);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.maxVoltage);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.averageCurrent);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.minCurrent);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(record.maxCurrent);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).value =
            excel_lib.IntCellValue(record.totalReadings);
      }

      // Get user info for filename
      final String userName = user.displayName ?? user.email?.split('@').first ?? 'User';
      final String sanitizedUserName = userName.replaceAll(RegExp(r'[^\w\s-]'), '');

      // Get hub serial numbers (combine all if multiple hubs)
      final hubSerials = allRecords.map((r) => r.hubName).toSet().join('_');
      final String sanitizedSerials = hubSerials.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');

      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName = 'SmartEnergyMeter_${sanitizedUserName}_${sanitizedSerials}_CentralHub_$timestamp.xlsx';

      // Save file
      await _saveExcelFile(excel, fileName);

    } catch (e) {
      debugPrint('[EnergyHistory] Error exporting to Excel: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// EFFICIENT Excel export for Usage History
  Future<void> _exportUsageHistoryToExcel() async {
    if (_usageHistoryEntries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No usage data to export'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Generating Excel file...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final excel = excel_lib.Excel.createExcel();

      // Create our custom sheet first
      excel.copy('Sheet1', 'Usage History');

      // Remove default sheet
      excel.delete('Sheet1');

      final sheet = excel['Usage History'];

      // Add headers with styling
      final headerStyle = excel_lib.CellStyle(
        backgroundColorHex: excel_lib.ExcelColor.teal,
        fontColorHex: excel_lib.ExcelColor.white,
        bold: true,
      );

      // Add headers
      final headers = ['Timestamp', 'Interval', 'Previous Reading (kWh)', 'Current Reading (kWh)', 'Usage (kWh)'];

      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = excel_lib.TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Add data rows
      for (var i = 0; i < _usageHistoryEntries.length; i++) {
        final entry = _usageHistoryEntries[i];
        final rowIndex = i + 1;

        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
            excel_lib.TextCellValue(entry.getFormattedTimestamp());
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            excel_lib.TextCellValue(entry.getIntervalText());
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(entry.previousReading);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(entry.currentReading);
        sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
            excel_lib.DoubleCellValue(entry.usage);
      }

      // Get user info for filename
      final User? user = FirebaseAuth.instance.currentUser;
      final String userName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
      final String sanitizedUserName = userName.replaceAll(RegExp(r'[^\w\s-]'), '');

      // Get hub info
      final hubInfo = _availableHubs.firstWhere(
        (hub) => hub['serialNumber'] == _selectedHubForUsage,
        orElse: () => {'nickname': 'Hub', 'serialNumber': 'Unknown'},
      );
      final String hubSerial = hubInfo['serialNumber'] ?? 'Unknown';
      final String sanitizedSerial = hubSerial.replaceAll(RegExp(r'[^\w\s-]'), '');

      final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName = 'SmartEnergyMeter_${sanitizedUserName}_${sanitizedSerial}_Usage_$timestamp.xlsx';

      await _saveExcelFile(excel, fileName);

    } catch (e) {
      debugPrint('[EnergyHistory] Error exporting usage to Excel: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Save Excel file with proper permissions handling
  Future<void> _saveExcelFile(excel_lib.Excel excel, String fileName) async {
    try {
      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      if (kIsWeb) {
        // Web platform - trigger browser download with proper filename
        final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: $fileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Mobile/Desktop platforms
      Directory? directory;

      if (Platform.isAndroid) {
        // Request storage permission for Android
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          // Try manageExternalStorage for Android 11+
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) {
            throw Exception('Storage permission denied');
          }
        }

        // Use Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported successfully!\n$filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[EnergyHistory] Error saving file: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _hubRemovedSubscription?.cancel();
    _hubAddedSubscription?.cancel();
    _historyScrollDebounce?.cancel(); // Cancel debounce timer
    _usageScrollController.dispose();
    _historyScrollController.dispose(); // Dispose the new controller
    _kwhController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).primaryColor,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadHistoryData(forceRefresh: true);
                await _loadUsageHistory();
              },
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Due Date Display
                  Consumer<DueDateProvider>(
                    builder: (context, dueDateProvider, _) {
                      if (dueDateProvider.dueDate == null) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: dueDateProvider.isOverdue
                              ? Colors.red.withOpacity(0.1)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: dueDateProvider.isOverdue
                                ? Colors.red
                                : Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: dueDateProvider.isOverdue
                                    ? Colors.red.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: dueDateProvider.isOverdue
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.secondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payment Due Date',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dueDateProvider.getFormattedDueDate() ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: dueDateProvider.isOverdue
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.secondary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dueDateProvider.isOverdue
                                    ? 'Overdue ${dueDateProvider.getDaysRemaining()!.abs()}d'
                                    : '${dueDateProvider.getDaysRemaining()}d left',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Central Hub Data Title
                  Text(
                    'Central Hub Data',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Aggregation Type Selector with Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: AggregationType.values.map((type) {
                              final isSelected = _selectedAggregation == type;
                              final aggregationColor = _getAggregationColor(type);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(type.name.toUpperCase()),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedAggregation = type;
                                      });
                                      // Load data for the new aggregation type
                                      _loadHistoryData();
                                    }
                                  },
                                  selectedColor: aggregationColor,
                                  backgroundColor: aggregationColor.withOpacity(0.1),
                                  side: BorderSide(
                                    color: aggregationColor,
                                    width: 1.5,
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : aggregationColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.download,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            tooltip: 'Export to Excel',
                            onPressed: _exportCentralHubDataToExcel,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            tooltip: 'Refresh',
                            onPressed: () => _loadHistoryData(forceRefresh: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary Cards
                  if (_historyRecords.isNotEmpty) ...[
                    _buildSummaryCards(isMobile),
                    const SizedBox(height: 16),
                  ],

                  // Table Section
                  Container(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          )
                        : _historyRecords.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 64,
                                      color: Colors.grey.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No history records found',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Data will appear once aggregations are generated',
                                      style: TextStyle(
                                        color: Colors.grey.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SizedBox(
                                  height: isMobile ? 500 : 400, // Taller for mobile cards
                                  child: Column(
                                    children: [
                                      // Table Header (Desktop only)
                                      if (!isMobile)
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context).colorScheme.secondary,
                                                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                              ],
                                            ),
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            child: Row(
                                              children: [
                                                _buildHeaderCell('Period', flex: 2, sortKey: 'period'),
                                                _buildHeaderCell('Hub', flex: 2, sortKey: 'hub'),
                                                _buildHeaderCell('Avg Power\n(W)', flex: 2, sortKey: 'power'),
                                                _buildHeaderCell('Total Energy\n(kWh)', flex: 2, sortKey: 'energy'),
                                                _buildHeaderCell('Avg Voltage\n(V)', flex: 2, sortKey: 'voltage'),
                                                _buildHeaderCell('Readings', flex: 1, sortKey: 'readings'),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Table Body with scroll
                                      Expanded(
                                        child: ListView.builder(
                                          controller: _historyScrollController,
                                          itemCount: _filteredHistoryRecords.length + (_isLoadingMoreHistory ? 1 : 0),
                                          itemBuilder: (context, index) {
                                            // Loading indicator at the bottom
                                            if (index == _filteredHistoryRecords.length) {
                                              return _isLoadingMoreHistory
                                                  ? const Center(child: Padding(
                                                      padding: EdgeInsets.all(8.0),
                                                      child: CircularProgressIndicator(),
                                                    ))
                                                  : const SizedBox.shrink();
                                            }

                                            final record = _filteredHistoryRecords[index];

                                            if (isMobile) {
                                              // Mobile view: Card-based layout
                                              return _buildHistoryRowMobile(record);
                                            } else {
                                              // Desktop view: Row-based layout
                                              final isEven = index % 2 == 0;
                                              return InkWell(
                                                onTap: () => _showRecordDetails(record),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isEven
                                                        ? Theme.of(context).cardColor
                                                        : Theme.of(context).primaryColor.withOpacity(0.3),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                    child: Row(
                                                      children: [
                                                        _buildDataCell(_getPeriodLabel(record), flex: 2),
                                                        _buildDataCell(record.hubName, flex: 2),
                                                        _buildDataCell(record.averagePower.toStringAsFixed(2), flex: 2),
                                                        _buildDataCell(
                                                          record.totalEnergy.toStringAsFixed(3),
                                                          flex: 2,
                                                          color: _getEnergyLevelColor(record.totalEnergy),
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        _buildDataCell(record.averageVoltage.toStringAsFixed(1), flex: 2),
                                                        _buildDataCell('${record.totalReadings}', flex: 1),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),

                                      // Footer with record count
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withOpacity(0.5),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _filteredHistoryRecords.length != _historyRecords.length
                                                  ? 'Showing: ${_filteredHistoryRecords.length} of ${_historyRecords.length} Records'
                                                  : 'Showing: ${_historyRecords.length} Records',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (_canLoadMoreHistory)
                                              Text(
                                                'Scroll for more',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: Colors.grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                  ),

                  // USAGE HISTORY TABLE - Live Calculated from Readings
                  const SizedBox(height: 32),
                  _buildCostCalculator(isMobile),
                  const SizedBox(height: 16),
                  _buildUsageHistorySection(isMobile),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build the responsive Summary Cards grid/list
  Widget _buildSummaryCards(bool isMobile) {
    // Calculate current totals
    final currentTotalEnergy = _historyRecords.fold<double>(0, (sum, record) => sum + record.totalEnergy);
    final currentAvgPower = _historyRecords.isNotEmpty
        ? _historyRecords.fold<double>(0, (sum, record) => sum + record.averagePower) / _historyRecords.length
        : 0.0;
    final currentTotalReadings = _historyRecords.fold<int>(0, (sum, record) => sum + record.totalReadings);

    // Calculate previous totals for comparison
    final previousTotalEnergy = _previousHistoryRecords.fold<double>(0, (sum, record) => sum + record.totalEnergy);
    final previousAvgPower = _previousHistoryRecords.isNotEmpty
        ? _previousHistoryRecords.fold<double>(0, (sum, record) => sum + record.averagePower) / _previousHistoryRecords.length
        : 0.0;
    final previousTotalReadings = _previousHistoryRecords.fold<int>(0, (sum, record) => sum + record.totalReadings);

    final cards = [
      _buildSummaryCard(
        'Total Energy',
        '${currentTotalEnergy.toStringAsFixed(2)} kWh',
        Icons.bolt,
        Colors.orange,
        percentageChange: _getPercentageChange(currentTotalEnergy, previousTotalEnergy),
      ),
      _buildSummaryCard(
        'Avg Power',
        '${currentAvgPower.toStringAsFixed(2)} W',
        Icons.power,
        Colors.blue,
        percentageChange: _getPercentageChange(currentAvgPower, previousAvgPower),
      ),
      _buildSummaryCard(
        'Records',
        '${_historyRecords.length}',
        Icons.dataset,
        Colors.green,
        percentageChange: _getPercentageChange(_historyRecords.length.toDouble(), _previousHistoryRecords.length.toDouble()),
      ),
      _buildSummaryCard(
        'Total Readings',
        '$currentTotalReadings',
        Icons.analytics,
        Colors.purple,
        percentageChange: _getPercentageChange(currentTotalReadings.toDouble(), previousTotalReadings.toDouble()),
      ),
    ];

    if (isMobile) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6, // Reduced from 2.0 to give more vertical space
        children: cards,
      );
    } else {
      return SizedBox(
        height: 80,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: cards,
        ),
      );
    }
  }

  /// Build the mobile-friendly card for a history record
  Widget _buildHistoryRowMobile(HistoryRecord record) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Theme.of(context).cardColor.withOpacity(0.8),
      child: InkWell(
        onTap: () => _showRecordDetails(record),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getPeriodLabel(record),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                record.hubName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMobileDetailItem('Total Energy', '${record.totalEnergy.toStringAsFixed(3)} kWh', _getEnergyLevelColor(record.totalEnergy)),
                  _buildMobileDetailItem('Avg Power', '${record.averagePower.toStringAsFixed(2)} W'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMobileDetailItem('Avg Voltage', '${record.averageVoltage.toStringAsFixed(1)} V'),
                  _buildMobileDetailItem('Readings', '${record.totalReadings}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the mobile-friendly card for a usage history entry
  Widget _buildUsageHistoryRowMobile(UsageHistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Theme.of(context).cardColor.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.getFormattedTimestamp(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.getIntervalText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: getIntervalColor(_selectedUsageInterval).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: getIntervalColor(_selectedUsageInterval), width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Usage',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: getIntervalColor(_selectedUsageInterval),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${entry.usage.toStringAsFixed(3)} kWh',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: getIntervalColor(_selectedUsageInterval),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDetailItem(String label, String value, [Color? valueColor, bool isCentered = false]) {
    return Column(
      crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Build the Cost Calculator widget (now responsive)
  Widget _buildCostCalculator(bool isMobile) {
    final kwhField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Usage (kWh)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _kwhController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _calculateCost(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            hintText: '0.00',
            suffixText: 'kWh',
            suffixStyle: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );

    final priceField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price per kWh',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _calculateCost(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            hintText: '0.00',
            prefixText: '₱',
            prefixStyle: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );

    final resultDisplay = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Cost',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.green, Colors.green.shade700]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('₱', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _calculatedCost.toStringAsFixed(2),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.secondary.withOpacity(0.1), Theme.of(context).colorScheme.primary.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calculate, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Electricity Cost Calculator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 2),
                    Text('Calculate your total electricity cost', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          isMobile
              ? Column(
                  children: [
                    kwhField,
                    const SizedBox(height: 16),
                    priceField,
                    const SizedBox(height: 24),
                    resultDisplay,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: kwhField),
                    const SizedBox(width: 16),
                    Padding(padding: const EdgeInsets.only(top: 32), child: Icon(Icons.close, color: Theme.of(context).colorScheme.secondary, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(child: priceField),
                    const SizedBox(width: 16),
                    Padding(padding: const EdgeInsets.only(top: 32), child: Icon(Icons.drag_handle, color: Theme.of(context).colorScheme.secondary, size: 28)),
                    const SizedBox(width: 16),
                    Expanded(child: resultDisplay),
                  ],
                ),
        ],
      ),
    );
  }

  /// Build the Usage History section with live calculations
  Widget _buildUsageHistorySection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Usage History',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 28, color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.download, color: Theme.of(context).colorScheme.secondary),
                  tooltip: 'Export to Excel',
                  onPressed: _exportUsageHistoryToExcel,
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.secondary),
                  tooltip: 'Refresh',
                  onPressed: _loadUsageHistory,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _getUsageCalculationDescription(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
        ),
        const SizedBox(height: 16),

        if (_availableHubs.length > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.3), width: 2),
            ),
            child: Row(
              children: [
                Icon(Icons.router, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedHubForUsage,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _availableHubs.map((hub) {
                      final serial = hub['serialNumber']!;
                      final nickname = hub['nickname']!;
                      final displaySerial = serial.length > 8 ? '${serial.substring(0, 8)}...' : serial;
                      return DropdownMenuItem<String>(value: serial, child: Text('$nickname ($displaySerial)', style: const TextStyle(fontSize: 14)));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedHubForUsage = value;
                        _loadUsageHistory();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: UsageInterval.values.map((interval) {
              final isSelected = _selectedUsageInterval == interval;
              final intervalColor = getIntervalColor(interval);
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(interval.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedUsageInterval = interval;
                        _loadUsageHistory();
                      });
                    }
                  },
                  selectedColor: intervalColor,
                  backgroundColor: intervalColor.withOpacity(0.1),
                  side: BorderSide(color: intervalColor, width: 1.5),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : intervalColor, fontSize: 15, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          height: isMobile ? 500 : 400,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              if (!isMobile)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [getIntervalColor(_selectedUsageInterval), getIntervalColor(_selectedUsageInterval).withOpacity(0.8)]),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Timestamp',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Interval',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Usage (kWh)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: _isLoadingUsageHistory && _usageHistoryEntries.isEmpty
                    ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary))
                    : _usageHistoryEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  _availableHubs.isEmpty ? 'No hubs available' : 'No usage history available',
                                  style: const TextStyle(color: Colors.grey, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _availableHubs.isEmpty
                                      ? 'Link a hub in the Explore tab to see usage history'
                                      : 'Usage data will appear once meter readings are recorded',
                                  style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _usageScrollController,
                            itemCount: _filteredUsageHistoryEntries.length + (_isLoadingUsageHistory ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _filteredUsageHistoryEntries.length) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                );
                              }
                              final entry = _filteredUsageHistoryEntries[index];
                              
                              if (isMobile) {
                                return _buildUsageHistoryRowMobile(entry);
                              } else {
                                final isEven = index % 2 == 0;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isEven ? Theme.of(context).cardColor : Theme.of(context).primaryColor.withOpacity(0.3),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    child: Row(
                                      children: [
                                        _buildDataCell(entry.getFormattedTimestamp(), flex: 3),
                                        _buildDataCell(entry.getIntervalText(), flex: 2),
                                        _buildDataCell(
                                          entry.usage.toStringAsFixed(3),
                                          flex: 3,
                                          color: getIntervalColor(_selectedUsageInterval),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
              ),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_usageHistoryEntries.length} periods',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      'Scroll down for more history',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, {double? percentageChange}) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10), // Reduced from 12 to 10
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28), // Reduced from 32 to 28
          const SizedBox(width: 10), // Reduced from 12 to 10
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Added to prevent overflow
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12, // Reduced from 13 to 12
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
                const SizedBox(height: 3), // Reduced from 4 to 3
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16, // Reduced from 17 to 16
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
                if (percentageChange != null && percentageChange != 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2), // Added small top padding
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          percentageChange > 0 ? Icons.trending_up : Icons.trending_down,
                          color: Colors.white70,
                          size: 12, // Reduced from 14 to 12
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${percentageChange.abs().toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10, // Reduced from 11 to 10
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, String? sortKey}) {
    final bool isSorted = _sortColumn == sortKey;

    return Expanded(
      flex: flex,
      child: sortKey != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  debugPrint('[EnergyHistory] Sorting by: $sortKey');
                  _sortBy(sortKey);
                },
                hoverColor: Colors.white.withValues(alpha: 0.1),
                splashColor: Colors.white.withValues(alpha: 0.3),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Flexible(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isSorted
                            ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                            : Icons.unfold_more,
                        color: isSorted ? Colors.white : Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  Widget _buildDataCell(String text, {int flex = 1, Color? color, FontWeight? fontWeight}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 13,
          color: color,
          fontWeight: fontWeight,
        ),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  void _showRecordDetails(HistoryRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Details - ${_getPeriodLabel(record)}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Hub', record.hubName),
              _buildDetailRow('Period', record.periodKey),
              const Divider(),
              _buildDetailRow('Avg Power', '${record.averagePower.toStringAsFixed(2)} W'),
              _buildDetailRow('Min Power', '${record.minPower.toStringAsFixed(2)} W'),
              _buildDetailRow('Max Power', '${record.maxPower.toStringAsFixed(2)} W'),
              const Divider(),
              _buildDetailRow('Avg Voltage', '${record.averageVoltage.toStringAsFixed(2)} V'),
              _buildDetailRow('Min Voltage', '${record.minVoltage.toStringAsFixed(2)} V'),
              _buildDetailRow('Max Voltage', '${record.maxVoltage.toStringAsFixed(2)} V'),
              const Divider(),
              _buildDetailRow('Avg Current', '${record.averageCurrent.toStringAsFixed(3)} A'),
              _buildDetailRow('Min Current', '${record.minCurrent.toStringAsFixed(3)} A'),
              _buildDetailRow('Max Current', '${record.maxCurrent.toStringAsFixed(3)} A'),
              const Divider(),
              _buildDetailRow('Total Energy', '${record.totalEnergy.toStringAsFixed(3)} kWh', isHighlight: true),
              _buildDetailRow('Total Readings', '${record.totalReadings}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Theme.of(context).colorScheme.secondary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// History Record Model
class HistoryRecord {
  final DateTime timestamp;
  final String deviceName;
  final String hubName;
  final double averagePower;
  final double minPower;
  final double maxPower;
  final double averageVoltage;
  final double minVoltage;
  final double maxVoltage;
  final double averageCurrent;
  final double minCurrent;
  final double maxCurrent;
  final double totalEnergy;
  final int totalReadings;
  final AggregationType aggregationType;
  final String periodKey;

  HistoryRecord({
    required this.timestamp,
    required this.deviceName,
    required this.hubName,
    required this.averagePower,
    required this.minPower,
    required this.maxPower,
    required this.averageVoltage,
    required this.minVoltage,
    required this.maxVoltage,
    required this.averageCurrent,
    required this.minCurrent,
    required this.maxCurrent,
    required this.totalEnergy,
    required this.totalReadings,
    required this.aggregationType,
    required this.periodKey,
  });
}
