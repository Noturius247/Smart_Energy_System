import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../theme_provider.dart';
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
  bool _isLoading = true;
  AggregationType _selectedAggregation = AggregationType.daily;
  StreamSubscription<String>? _hubRemovedSubscription;
  StreamSubscription<Map<String, String>>? _hubAddedSubscription;

  // Usage History - Live calculation from readings
  late UsageHistoryService _usageHistoryService;
  List<UsageHistoryEntry> _usageHistoryEntries = [];
  bool _isLoadingUsageHistory = false;
  UsageInterval _selectedUsageInterval = UsageInterval.daily;
  String? _selectedHubForUsage;
  List<Map<String, String>> _availableHubs = [];
  int _usageHistoryOffset = 0; // For pagination/scrolling
  final ScrollController _usageScrollController = ScrollController();

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
    _loadHistoryData();
    _loadAvailableHubs();
    _startHubRemovedListener();
    _startHubAddedListener();

    // Setup scroll listener for infinite scroll
    _usageScrollController.addListener(_onUsageScroll);
  }

  void _onUsageScroll() {
    if (_usageScrollController.position.pixels >= _usageScrollController.position.maxScrollExtent * 0.8) {
      // Load more when scrolled to 80% of the list
      if (!_isLoadingUsageHistory) {
        _loadMoreUsageHistory();
      }
    }
  }

  Future<void> _loadAvailableHubs() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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

        setState(() {
          _availableHubs = hubList;
          if (hubList.isNotEmpty) {
            _selectedHubForUsage = hubList.first['serialNumber'];
            _loadUsageHistory();
          }
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

      final entries = await _usageHistoryService.calculateUsageHistory(
        hubSerialNumber: _selectedHubForUsage!,
        interval: _selectedUsageInterval,
        customDueDate: dueDateProvider.dueDate,
        minRows: 10,
        offset: 0,
      );

      setState(() {
        _usageHistoryEntries = entries;
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
        _usageHistoryOffset = newOffset;
        _isLoadingUsageHistory = false;
      });
    } catch (e) {
      debugPrint('[EnergyHistory] Error loading more usage history: $e');
      setState(() => _isLoadingUsageHistory = false);
    }
  }

  void _startHubRemovedListener() {
    // Listen to hub removal events and reload history data
    _hubRemovedSubscription = _realtimeDbService.hubRemovedStream.listen((removedHubSerial) {
      if (!mounted) return;

      debugPrint('[EnergyHistory] Hub removed event received: $removedHubSerial. Reloading history...');

      // Reload history data to exclude the removed hub
      _loadHistoryData();
      _loadAvailableHubs(); // Reload usage history hubs too

      // Show notification to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hub $removedHubSerial has been unlinked. History updated.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _startHubAddedListener() {
    // Listen to hub addition events and reload history data
    _hubAddedSubscription = _realtimeDbService.hubAddedStream.listen((hubData) {
      if (!mounted) return;

      final String serialNumber = hubData['serialNumber']!;
      debugPrint('[EnergyHistory] Hub added event received: $serialNumber. Reloading history...');

      // Reload history data to include the new hub
      _loadHistoryData();
      _loadAvailableHubs(); // Reload usage history hubs too

      // Show notification to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hub $serialNumber has been linked. History updated.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoading = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      List<HistoryRecord> records = [];

      // Fetch aggregated data from Firebase - FILTER BY OWNER
      final snapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (snapshot.exists) {
        final hubs = Map<String, dynamic>.from(snapshot.value as Map);

        for (var hubEntry in hubs.entries) {
          final hubData = Map<String, dynamic>.from(hubEntry.value);
          final String serialNumber = hubEntry.key;

          // IMPORTANT: Double-check the hub is actually assigned and belongs to this user
          final bool isAssigned = hubData['assigned'] as bool? ?? false;
          final String? hubOwnerId = hubData['ownerId'] as String?;

          if (!isAssigned || hubOwnerId != user.uid) {
            debugPrint('[EnergyHistory] Skipping hub $serialNumber - not assigned or wrong owner');
            continue; // Skip this hub
          }

          final String hubNickname = hubData['nickname'] ?? 'Hub ${serialNumber.substring(0, 6)}';

          // Check if hub has aggregations
          if (hubData['aggregations'] != null) {
            final aggregations = Map<String, dynamic>.from(hubData['aggregations']);

            // Get the selected aggregation type data
            String aggregationType = _selectedAggregation.name;
            if (aggregations[aggregationType] != null) {
              final aggregationData = Map<String, dynamic>.from(aggregations[aggregationType]);

              for (var entry in aggregationData.entries) {
                final String timeKey = entry.key;
                final data = Map<String, dynamic>.from(entry.value);

                // Parse timestamp
                DateTime timestamp;
                if (data['timestamp'] != null) {
                  timestamp = DateTime.parse(data['timestamp']);
                } else {
                  // Parse from key for different formats
                  timestamp = _parseTimestampFromKey(timeKey, _selectedAggregation);
                }

                records.add(HistoryRecord(
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
            }
          }
        }
      }

      // Sort by timestamp (newest first)
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _historyRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }

  DateTime _parseTimestampFromKey(String key, AggregationType type) {
    try {
      switch (type) {
        case AggregationType.hourly:
          // Format: "2025-11-22-02" (YYYY-MM-DD-HH)
          final parts = key.split('-');
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
            int.parse(parts[3]),
          );
        case AggregationType.daily:
          // Format: "2025-11-20" (YYYY-MM-DD)
          return DateTime.parse(key);
        case AggregationType.weekly:
          // Format: "2025-W36" (YYYY-Www)
          final parts = key.split('-W');
          final year = int.parse(parts[0]);
          final week = int.parse(parts[1]);
          // Calculate first day of the week
          return _getDateFromWeek(year, week);
        case AggregationType.monthly:
          // Format: "2025-09" (YYYY-MM)
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  DateTime _getDateFromWeek(int year, int week) {
    // Get first day of year
    DateTime jan1 = DateTime(year, 1, 1);
    // Calculate days to add
    int daysToAdd = (week - 1) * 7;
    // Adjust for the day of week of Jan 1
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

  @override
  void dispose() {
    _hubRemovedSubscription?.cancel();
    _hubAddedSubscription?.cancel();
    _usageScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Central Hub Data',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: _loadHistoryData,
                ),
              ],
            ),
            const SizedBox(height: 16),

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

            // Aggregation Type Selector
            SingleChildScrollView(
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
                            _loadHistoryData();
                          });
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
            const SizedBox(height: 16),

            // Summary Cards
            if (_historyRecords.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildSummaryCard(
                      'Total Energy',
                      '${_historyRecords.fold<double>(0, (sum, record) => sum + record.totalEnergy).toStringAsFixed(2)} kWh',
                      Icons.bolt,
                      Colors.orange,
                    ),
                    _buildSummaryCard(
                      'Avg Power',
                      '${(_historyRecords.fold<double>(0, (sum, record) => sum + record.averagePower) / _historyRecords.length).toStringAsFixed(2)} W',
                      Icons.power,
                      Colors.blue,
                    ),
                    _buildSummaryCard(
                      'Records',
                      '${_historyRecords.length}',
                      Icons.dataset,
                      Colors.green,
                    ),
                    _buildSummaryCard(
                      'Total Readings',
                      '${_historyRecords.fold<int>(0, (sum, record) => sum + record.totalReadings)}',
                      Icons.analytics,
                      Colors.purple,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Table Section
            Expanded(
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
                          child: Column(
                            children: [
                              // Table Header
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
                                      _buildHeaderCell('Period', flex: 2),
                                      _buildHeaderCell('Hub', flex: 2),
                                      _buildHeaderCell('Avg Power\n(W)', flex: 2),
                                      _buildHeaderCell('Total Energy\n(kWh)', flex: 2),
                                      _buildHeaderCell('Avg Voltage\n(V)', flex: 2),
                                      _buildHeaderCell('Readings', flex: 1),
                                    ],
                                  ),
                                ),
                              ),

                              // Table Body with scroll
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _historyRecords.length,
                                  itemBuilder: (context, index) {
                                    final record = _historyRecords[index];
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
                                              _buildDataCell(
                                                _getPeriodLabel(record),
                                                flex: 2,
                                              ),
                                              _buildDataCell(record.hubName, flex: 2),
                                              _buildDataCell(
                                                record.averagePower.toStringAsFixed(2),
                                                flex: 2,
                                              ),
                                              _buildDataCell(
                                                record.totalEnergy.toStringAsFixed(3),
                                                flex: 2,
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              _buildDataCell(
                                                record.averageVoltage.toStringAsFixed(1),
                                                flex: 2,
                                              ),
                                              _buildDataCell(
                                                '${record.totalReadings}',
                                                flex: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
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
                                      'Total Records: ${_historyRecords.length}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Updated: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
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

            // USAGE HISTORY TABLE - Live Calculated from Readings
            const SizedBox(height: 32),
            _buildUsageHistorySection(),
          ],
        ),
      ),
    );
  }

  /// Build the Usage History section with live calculations
  Widget _buildUsageHistorySection() {
    // Color mapping for usage intervals
    Color getIntervalColor(UsageInterval interval) {
      switch (interval) {
        case UsageInterval.hourly:
          return Colors.cyan;
        case UsageInterval.daily:
          return Colors.teal;
        case UsageInterval.weekly:
          return Colors.amber;
        case UsageInterval.monthly:
          return Colors.deepPurple;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Usage History',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: _loadUsageHistory,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Live calculation from meter readings - No stored usage data',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Hub Selector (if multiple hubs available)
        if (_availableHubs.length > 1)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.router,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedHubForUsage,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: _availableHubs.map((hub) {
                      final serial = hub['serialNumber']!;
                      final nickname = hub['nickname']!;
                      final displaySerial = serial.length > 8
                          ? '${serial.substring(0, 8)}...'
                          : serial;
                      return DropdownMenuItem<String>(
                        value: serial,
                        child: Text(
                          '$nickname ($displaySerial)',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
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

        // Interval Selector
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
                  side: BorderSide(
                    color: intervalColor,
                    width: 1.5,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : intervalColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Usage History Table
        Container(
          height: 400,
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
          child: Column(
            children: [
              // Table Header
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      getIntervalColor(_selectedUsageInterval),
                      getIntervalColor(_selectedUsageInterval).withOpacity(0.8),
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
                      _buildHeaderCell('Timestamp', flex: 3),
                      _buildHeaderCell('Interval', flex: 2),
                      _buildHeaderCell('Previous\nReading (kWh)', flex: 2),
                      _buildHeaderCell('Current\nReading (kWh)', flex: 2),
                      _buildHeaderCell('Usage\n(kWh)', flex: 2),
                    ],
                  ),
                ),
              ),

              // Table Body with scroll and infinite loading
              Expanded(
                child: _isLoadingUsageHistory && _usageHistoryEntries.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      )
                    : _usageHistoryEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  size: 64,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No usage history available',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _usageScrollController,
                            itemCount: _usageHistoryEntries.length + (_isLoadingUsageHistory ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at the end
                              if (index == _usageHistoryEntries.length) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(),
                                );
                              }

                              final entry = _usageHistoryEntries[index];
                              final isEven = index % 2 == 0;

                              return Container(
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? Theme.of(context).cardColor
                                      : Theme.of(context).primaryColor.withOpacity(0.3),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      _buildDataCell(
                                        entry.getFormattedTimestamp(),
                                        flex: 3,
                                      ),
                                      _buildDataCell(
                                        entry.getIntervalText(),
                                        flex: 2,
                                      ),
                                      _buildDataCell(
                                        entry.previousReading.toStringAsFixed(3),
                                        flex: 2,
                                      ),
                                      _buildDataCell(
                                        entry.currentReading.toStringAsFixed(3),
                                        flex: 2,
                                      ),
                                      _buildDataCell(
                                        entry.usage.toStringAsFixed(3),
                                        flex: 2,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // Footer
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
                      'Total: ${_usageHistoryEntries.length} periods',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Scroll down for more history',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
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

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
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
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
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
