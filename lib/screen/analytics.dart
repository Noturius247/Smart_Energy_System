import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../realtime_db_service.dart';
import 'realtime_line_chart.dart';
import '../constants.dart';
import '../services/analytics_recording_service.dart';
import '../due_date_provider.dart';
import '../widgets/notification_box.dart';
import '../price_provider.dart';

enum _MetricType {
  power,
  voltage,
  current,
  energy,
}

enum _TimeRange {
  hourly,
  daily,
  weekly,
  monthly,
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class AnalyticsScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;
  const AnalyticsScreen({super.key, required this.realtimeDbService});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _MetricType _selectedMetric = _MetricType.power;
  _MetricType _liveChartMetric = _MetricType.power; // For 60-second live chart
  _TimeRange _selectedTimeRange = _TimeRange.hourly;
  bool _isInitialized = false;
  DateTime? _lastDataUpdate;
  bool _isDeviceConnected = false;
  final AnalyticsRecordingService _recordingService = AnalyticsRecordingService();
  int _connectionAlertMinutes = 5; // Default connection alert threshold

  // Hub selection for per-hub analytics
  List<Map<String, String>> _availableHubs = []; // List of {serialNumber, nickname}
  String? _selectedHubSerial; // null = show all hubs combined

  // SSR state tracking for pausing the chart
  bool _isChartPaused = false;
  StreamSubscription? _ssrStateSubscription;
  StreamSubscription? _hubRemovedSubscription;
  StreamSubscription? _hubAddedSubscription;

  // Stream key to force rebuild when time range or hub changes
  int _streamKey = 0;

  // Color mapping for each metric type
  Color _getMetricColor(_MetricType metricType) {
    switch (metricType) {
      case _MetricType.power:
        return Colors.purple;
      case _MetricType.voltage:
        return Colors.orange;
      case _MetricType.current:
        return Colors.blue;
      case _MetricType.energy:
        return Colors.green;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserPreferences(); // Load user preferences from Firestore
    _initializeHubStreams();
    _startSsrStateListener();
    _startHubRemovedListener();
    _startHubAddedListener();
  }

  void _startSsrStateListener() {
    // Listen to SSR state changes
    // If a specific hub is selected, listen to that hub's SSR state
    // Otherwise, listen to combined SSR state (true if ANY hub is on)
    _ssrStateSubscription?.cancel();

    Stream<bool> ssrStream;
    if (_selectedHubSerial != null) {
      ssrStream = widget.realtimeDbService.getHubSsrStateStream(_selectedHubSerial!);
    } else {
      ssrStream = widget.realtimeDbService.getCombinedSsrStateStream();
    }

    _ssrStateSubscription = ssrStream.listen((isOn) {
      if (mounted) {
        setState(() {
          // Pause chart when SSR is OFF (false), resume when ON (true)
          _isChartPaused = !isOn;
        });
        debugPrint('[AnalyticsScreen] SSR state changed: ${isOn ? "ON" : "OFF"}, Chart paused: $_isChartPaused');

        // Pause/resume recording service for all active hubs based on SSR state
        _updateRecordingState(isOn);
      }
    });
  }

  void _updateRecordingState(bool isOn) {
    // Pause or resume recording for each available hub
    for (final hub in _availableHubs) {
      final serialNumber = hub['serialNumber'];
      if (serialNumber != null) {
        if (isOn) {
          _recordingService.resumeRecording(serialNumber);
          debugPrint('[AnalyticsScreen] ▶️ Resumed recording for hub: $serialNumber');
        } else {
          _recordingService.pauseRecording(serialNumber);
          debugPrint('[AnalyticsScreen] ⏸️ Paused recording for hub: $serialNumber');
        }
      }
    }
  }

  // Load user preferences from Firestore
  Future<void> _loadUserPreferences() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Load default analytics metric
          final metricString = data['defaultAnalyticsMetric'] as String? ?? 'power';
          _selectedMetric = _MetricType.values.firstWhere(
            (e) => e.toString().split('.').last == metricString,
            orElse: () => _MetricType.power,
          );
          _liveChartMetric = _selectedMetric; // Set live chart to same default

          // Load default time range
          final timeRangeString = data['defaultAnalyticsTimeRange'] as String? ?? 'hourly';
          _selectedTimeRange = _TimeRange.values.firstWhere(
            (e) => e.toString().split('.').last == timeRangeString,
            orElse: () => _TimeRange.hourly,
          );

          // Load connection alert threshold
          _connectionAlertMinutes = data['connectionAlertMinutes'] as int? ?? 5;
        });
      }
    } catch (e) {
      debugPrint('[AnalyticsScreen] Error loading user preferences: $e');
    }
  }

  void _startHubRemovedListener() {
    // Listen to hub removal events from the service
    _hubRemovedSubscription = widget.realtimeDbService.hubRemovedStream.listen((removedHubSerial) {
      if (!mounted) return;

      debugPrint('[AnalyticsScreen] Hub removed event received: $removedHubSerial');

      setState(() {
        // Remove the hub from available hubs list
        _availableHubs.removeWhere((hub) => hub['serialNumber'] == removedHubSerial);

        // If the removed hub was selected, switch to another hub or clear selection
        if (_selectedHubSerial == removedHubSerial) {
          if (_availableHubs.isNotEmpty) {
            _selectedHubSerial = _availableHubs.first['serialNumber'];
            debugPrint('[AnalyticsScreen] Switched to hub: $_selectedHubSerial');
            // Restart SSR state listener for the new hub
            _startSsrStateListener();
          } else {
            _selectedHubSerial = null;
            debugPrint('[AnalyticsScreen] No hubs available after removal');
          }
          // Increment stream key to force rebuild
          _streamKey++;
        }
      });

      // Show notification to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hub $removedHubSerial has been unlinked'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _startHubAddedListener() {
    // Listen to hub addition events from the service
    _hubAddedSubscription = widget.realtimeDbService.hubAddedStream.listen((hubData) {
      if (!mounted) return;

      final String serialNumber = hubData['serialNumber']!;
      final String nickname = hubData['nickname']!;

      debugPrint('[AnalyticsScreen] Hub added event received: $serialNumber');

      setState(() {
        // Add the hub to available hubs list if not already present
        if (!_availableHubs.any((hub) => hub['serialNumber'] == serialNumber)) {
          _availableHubs.add({
            'serialNumber': serialNumber,
            'nickname': nickname,
          });
          debugPrint('[AnalyticsScreen] Added hub to list: $serialNumber');

          // If this is the first hub, select it automatically
          if (_availableHubs.length == 1) {
            _selectedHubSerial = serialNumber;
            debugPrint('[AnalyticsScreen] Auto-selected first hub: $serialNumber');
            // Start SSR state listener for the new hub
            _startSsrStateListener();
            // Increment stream key to force rebuild
            _streamKey++;
          }
        }
      });

      // Show notification to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hub $serialNumber has been linked'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _recordingService.dispose();
    _ssrStateSubscription?.cancel();
    _hubRemovedSubscription?.cancel();
    _hubAddedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeHubStreams() async {
    debugPrint('[AnalyticsScreen] 🔵 _initializeHubStreams called. Already initialized: $_isInitialized');
    if (_isInitialized) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('[AnalyticsScreen] ❌ No authenticated user found.');
      return;
    }

    final String authenticatedUserUID = currentUser.uid;
    debugPrint('[AnalyticsScreen] ✅ User authenticated: $authenticatedUserUID');

    try {
      // EFFICIENCY FIX: Filter hubs by ownerId at query level instead of fetching all
      // This reduces bandwidth significantly when there are many hubs in the system
      final hubSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(authenticatedUserUID)
          .get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) {
        debugPrint('[AnalyticsScreen] No hubs found in Realtime Database.');
        return;
      }

      final allHubs =
          json.decode(json.encode(hubSnapshot.value)) as Map<String, dynamic>;

      debugPrint('[AnalyticsScreen] Fetched ${allHubs.length} hubs from RTDB (filtered by ownerId).');

      // Build list of available hubs with nicknames
      final List<Map<String, String>> hubList = [];

      // Start streams for user's hubs (already filtered by query)
      for (final serialNumber in allHubs.keys) {
        final hubData = allHubs[serialNumber] as Map<String, dynamic>;
        final String? nickname = hubData['nickname'] as String?;

        // Add to available hubs list
        hubList.add({
          'serialNumber': serialNumber,
          'nickname': nickname ?? 'Central Hub',
        });

        debugPrint('[AnalyticsScreen] 🚀 Starting stream for hub: $serialNumber');
        widget.realtimeDbService.startRealtimeDataStream(serialNumber);

        // Start per-second recording for 60-second live chart (65s backend buffer)
        // Flutter aggregates plug data and writes to per_second/data/
        debugPrint('[AnalyticsScreen] 📊 Starting recording service for hub: $serialNumber');
        _recordingService.startRecording(serialNumber);
        debugPrint('[AnalyticsScreen] ✅ Recording service started for hub: $serialNumber');
      }

      setState(() {
        _availableHubs = hubList;
        // Auto-select first hub if only one hub exists
        if (hubList.length == 1) {
          _selectedHubSerial = hubList.first['serialNumber'];
        }
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('[AnalyticsScreen] Error initializing hub streams: $e');
    }
  }

  String _getMetricUnit(_MetricType metricType, {bool showCost = false}) {
    switch (metricType) {
      case _MetricType.power:
        return 'W';
      case _MetricType.voltage:
        return 'V';
      case _MetricType.current:
        return 'A';
      case _MetricType.energy:
        return showCost ? '₱' : 'kWh';
    }
  }

  IconData _getMetricIcon(_MetricType metricType) {
    switch (metricType) {
      case _MetricType.power:
        return Icons.bolt;
      case _MetricType.voltage:
        return Icons.electrical_services;
      case _MetricType.current:
        return Icons.flash_on;
      case _MetricType.energy:
        return Icons.battery_charging_full;
    }
  }

  Duration _getTimeRangeDuration(_TimeRange timeRange) {
    switch (timeRange) {
      case _TimeRange.hourly:
        return const Duration(hours: 24); // Show 24 hours - uses hourly aggregation
      case _TimeRange.daily:
        return const Duration(days: 7); // Show 7 days - uses daily aggregation
      case _TimeRange.weekly:
        return const Duration(days: 28); // Show 28 days (4 weeks) - uses weekly aggregation
      case _TimeRange.monthly:
        return const Duration(days: 180); // Show 180 days (6 months) - uses monthly aggregation
    }
  }

  List<TimestampedFlSpot> _filterDataByTimeRange(List<TimestampedFlSpot> data) {
    if (data.isEmpty) return data;

    final now = DateTime.now();
    final cutoffTime = now.subtract(_getTimeRangeDuration(_selectedTimeRange));

    return data.where((spot) => spot.timestamp.isAfter(cutoffTime)).toList();
  }

  Map<String, double> _calculateStats(List<TimestampedFlSpot> spots) {
    if (spots.isEmpty) {
      return {'min': 0.0, 'max': 0.0, 'avg': 0.0};
    }

    final values = spots.map((spot) => _getMetricValue(spot, _selectedMetric)).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return {'min': min, 'max': max, 'avg': avg};
  }

  String _getTimeSinceLastUpdate() {
    if (_lastDataUpdate == null) return 'Never';

    final difference = DateTime.now().difference(_lastDataUpdate!);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  void _exportDataToCSV(List<TimestampedFlSpot> data) {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export')),
      );
      return;
    }

    // Create CSV content
    final csvHeader = 'Timestamp,Power (W),Voltage (V),Current (A),Energy (kWh)\n';
    final csvRows = data.map((spot) {
      return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(spot.timestamp)},${spot.power},${spot.voltage},${spot.current},${spot.energy}';
    }).join('\n');

    final csvContent = csvHeader + csvRows;

    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: csvContent));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${data.length} records to clipboard! Paste in Excel/Sheets.'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  double _getMetricValue(TimestampedFlSpot spot, _MetricType metricType, {bool calculateCost = false}) {
    switch (metricType) {
      case _MetricType.power:
        return spot.power;
      case _MetricType.voltage:
        return spot.voltage;
      case _MetricType.current:
        return spot.current;
      case _MetricType.energy:
        if (calculateCost) {
          final priceProvider = Provider.of<PriceProvider>(context, listen: false);
          return priceProvider.calculateCost(spot.energy);
        }
        return spot.energy;
    }
  }

  /// Get the appropriate data stream based on selected time range and hub
  /// This combines historical aggregated data with live real-time data
  Stream<List<TimestampedFlSpot>> _getHistoricalDataStream() {
    final now = DateTime.now();
    final startTime = now.subtract(_getTimeRangeDuration(_selectedTimeRange));

    if (_selectedHubSerial != null) {
      // Single hub selected - get combined historical and live data for that hub
      return widget.realtimeDbService.getCombinedHistoricalAndLiveDataStream(
        _selectedHubSerial!,
        startTime,
      );
    } else {
      // All hubs - get combined data for all active hubs
      return widget.realtimeDbService.getCombinedHistoricalAndLiveDataForAllHubs(
        startTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

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
      child: Column(
        children: [
          // Analytics Title Header
          Container(
            height: isSmallScreen ? 50 : 60,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withAlpha(200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Text(
                    'Analytics',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 16 : 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TimestampedFlSpot>>(
              key: ValueKey(_streamKey), // Force rebuild when stream key changes
              stream: _getHistoricalDataStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  debugPrint('AnalyticsScreen: StreamBuilder connectionState: waiting');
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('AnalyticsScreen: StreamBuilder hasError: ${snapshot.error}');
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // Always show the UI, even if data is empty
                final List<TimestampedFlSpot> allData = snapshot.data ?? [];
                final List<TimestampedFlSpot> filteredData = _filterDataByTimeRange(allData);

                // Update connection status and last update time
                if (allData.isNotEmpty) {
                  _lastDataUpdate = allData.last.timestamp;
                  _isDeviceConnected = DateTime.now().difference(allData.last.timestamp).inMinutes < _connectionAlertMinutes;
                }

                debugPrint('AnalyticsScreen: StreamBuilder hasData: ${snapshot.hasData}, isEmpty: ${filteredData.isEmpty}, count: ${filteredData.length}');

                return SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isSmallScreen ? 6 : 10),
                      // Hub Selection Dropdown (if multiple hubs available)
                      if (_availableHubs.length > 1)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 12,
                            vertical: isSmallScreen ? 6 : 8,
                          ),
                          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                              width: isSmallScreen ? 1.5 : 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.router,
                                color: Theme.of(context).colorScheme.secondary,
                                size: isSmallScreen ? 20 : 24,
                              ),
                              SizedBox(width: isSmallScreen ? 8 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Hub',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                        fontSize: isSmallScreen ? 10 : 12,
                                      ),
                                    ),
                                    DropdownButton<String?>(
                                      value: _selectedHubSerial,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(
                                            'All Hubs (Combined)',
                                            style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                                          ),
                                        ),
                                        ..._availableHubs.map((hub) {
                                          final serial = hub['serialNumber']!;
                                          final nickname = hub['nickname']!;
                                          return DropdownMenuItem<String?>(
                                            value: serial,
                                            child: Text(
                                              '$nickname (${serial.substring(0, isSmallScreen ? 6 : 8)}...)',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                                            ),
                                          );
                                        }),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedHubSerial = value;
                                          _streamKey++; // Force stream rebuild
                                        });
                                        // Restart SSR state listener for the new hub selection
                                        _startSsrStateListener();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Combined Price and Due Date on Same Line
                      Row(
                        children: [
                          Expanded(
                            child: MiniNotificationBox(isSmallScreen: isSmallScreen),
                          ),
                          Consumer<DueDateProvider>(
                            builder: (context, dueDateProvider, _) {
                              if (dueDateProvider.dueDate == null) return const SizedBox.shrink();
                              return const SizedBox(width: 8);
                            },
                          ),
                          Consumer<DueDateProvider>(
                            builder: (context, dueDateProvider, _) {
                              if (dueDateProvider.dueDate == null) return const SizedBox.shrink();

                              return Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 8 : 12,
                                    vertical: isSmallScreen ? 6 : 8,
                                  ),
                                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                                  decoration: BoxDecoration(
                                    color: dueDateProvider.isOverdue
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                                    border: Border.all(
                                      color: dueDateProvider.isOverdue
                                          ? Colors.red
                                          : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                      width: isSmallScreen ? 1.5 : 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: dueDateProvider.isOverdue
                                            ? Colors.red
                                            : Theme.of(context).colorScheme.secondary,
                                        size: isSmallScreen ? 20 : 24,
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Due Date',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: Colors.grey,
                                                fontSize: isSmallScreen ? 10 : 12,
                                              ),
                                            ),
                                            Text(
                                              dueDateProvider.getFormattedDueDate() ?? '',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isSmallScreen ? 12 : 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSmallScreen ? 8 : 12,
                                          vertical: isSmallScreen ? 4 : 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: dueDateProvider.isOverdue
                                              ? Colors.red
                                              : Theme.of(context).colorScheme.secondary,
                                          borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                                        ),
                                        child: Text(
                                          dueDateProvider.isOverdue
                                              ? 'Overdue ${dueDateProvider.getDaysRemaining()!.abs()}d'
                                              : '${dueDateProvider.getDaysRemaining()}d left',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 10 : 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      // Metric Selection Buttons for Live Chart - At the very top
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _MetricType.values.map((metric) {
                            final metricColor = _getMetricColor(metric);
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 3.0 : 4.0),
                              child: ChoiceChip(
                                label: Text(
                                  metric.toString().split('.').last.toUpperCase(),
                                  style: TextStyle(
                                    color: _liveChartMetric == metric
                                        ? Colors.white
                                        : metricColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 10 : 12,
                                  ),
                                ),
                                selected: _liveChartMetric == metric,
                                selectedColor: metricColor,
                                backgroundColor: metricColor.withOpacity(0.1),
                                side: BorderSide(
                                  color: metricColor,
                                  width: isSmallScreen ? 1.5 : 2,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 6 : 8,
                                  vertical: isSmallScreen ? 4 : 6,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _liveChartMetric = metric;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      // 60-Second Live Chart Panel with Status-Based Colors
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                        margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              // Status-based transparent green or red
                              !_isChartPaused
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              !_isChartPaused
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !_isChartPaused
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: !_isChartPaused
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: -5,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Panel Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedHubSerial != null
                                            ? 'Central Live Data (${_selectedHubSerial!.length > 8 ? _selectedHubSerial!.substring(0, 8) : _selectedHubSerial}...)'
                                            : 'Central Live Data (All Hubs)',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontSize: isSmallScreen ? 16 : 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 6),
                                      Text(
                                        isSmallScreen
                                            ? 'Live ${_liveChartMetric.toString().split('.').last.capitalize()} (60s)'
                                            : 'Live ${_liveChartMetric.toString().split('.').last.capitalize()} Chart (Last 60 Seconds)',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontSize: isSmallScreen ? 13 : 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 2 : 4),
                                      // Current time/date display for live chart
                                      StreamBuilder<DateTime>(
                                        stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                                        builder: (context, snapshot) {
                                          final now = snapshot.data ?? DateTime.now();
                                          return Text(
                                            DateFormat('MMM d, yyyy • HH:mm:ss').format(now),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: isSmallScreen ? 11 : 13,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Connection Status Indicator
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 6 : 8,
                                        vertical: isSmallScreen ? 3 : 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (_isDeviceConnected && !_isChartPaused) ? Colors.green : Colors.red,
                                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            (_isDeviceConnected && !_isChartPaused) ? Icons.wifi : Icons.wifi_off,
                                            size: isSmallScreen ? 12 : 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: isSmallScreen ? 3 : 4),
                                          if (!isSmallScreen)
                                            Text(
                                              (_isDeviceConnected && !_isChartPaused) ? 'Connected' : 'Offline',
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 4 : 8),
                                    // Export Button
                                    IconButton(
                                      icon: Icon(Icons.download, size: isSmallScreen ? 20 : 24),
                                      onPressed: () => _exportDataToCSV(allData),
                                      tooltip: 'Export to CSV',
                                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                                      constraints: BoxConstraints(
                                        minWidth: isSmallScreen ? 32 : 48,
                                        minHeight: isSmallScreen ? 32 : 48,
                                      ),
                                    ),
                                    // Refresh Button
                                    IconButton(
                                      icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
                                      onPressed: () {
                                        setState(() {
                                          _isInitialized = false;
                                        });
                                        _initializeHubStreams();
                                      },
                                      tooltip: 'Refresh data',
                                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                                      constraints: BoxConstraints(
                                        minWidth: isSmallScreen ? 32 : 48,
                                        minHeight: isSmallScreen ? 32 : 48,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            _build60SecondLiveChart(),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 30),

                      // Historical Analytics Panel with Status-Based Colors
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              // Status-based transparent green or red
                              !_isChartPaused
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              !_isChartPaused
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.red.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !_isChartPaused
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: !_isChartPaused
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                              spreadRadius: -5,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Panel Header
                            Text(
                              _selectedHubSerial != null
                                  ? 'Historical Analytics (${_selectedHubSerial!.length > 8 ? _selectedHubSerial!.substring(0, 8) : _selectedHubSerial}...)'
                                  : 'Historical Analytics (All Hubs)',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: isSmallScreen ? 16 : 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 10),
                            // Current time/date and last update info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Current Date/Time for historical chart - FIRST
                                StreamBuilder<DateTime>(
                                  stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
                                  builder: (context, snapshot) {
                                    final now = snapshot.data ?? DateTime.now();
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 8 : 10,
                                        vertical: isSmallScreen ? 4 : 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: isSmallScreen ? 12 : 14,
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          SizedBox(width: isSmallScreen ? 4 : 6),
                                          Text(
                                            DateFormat('MMM d, yyyy • HH:mm:ss').format(now),
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.secondary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: isSmallScreen ? 10 : 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                // Last Update Time - SECOND
                                Text(
                                  'Last update: ${_getTimeSinceLastUpdate()}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                    fontSize: isSmallScreen ? 11 : 13,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                      // Metric Selection Buttons and Time Range Buttons
                      isSmallScreen
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Metric buttons
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _MetricType.values.map((metric) {
                                      final metricColor = _getMetricColor(metric);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                        child: ChoiceChip(
                                          label: Text(
                                            metric.toString().split('.').last.toUpperCase(),
                                            style: TextStyle(
                                              color: _selectedMetric == metric
                                                  ? Colors.white
                                                  : metricColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                          selected: _selectedMetric == metric,
                                          selectedColor: metricColor,
                                          backgroundColor: metricColor.withOpacity(0.1),
                                          side: BorderSide(
                                            color: metricColor,
                                            width: 1.5,
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedMetric = metric;
                                              });
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Time Range buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: _TimeRange.values.map((timeRange) {
                                    String label;
                                    switch (timeRange) {
                                      case _TimeRange.hourly:
                                        label = 'H';
                                        break;
                                      case _TimeRange.daily:
                                        label = 'D';
                                        break;
                                      case _TimeRange.weekly:
                                        label = 'W';
                                        break;
                                      case _TimeRange.monthly:
                                        label = 'M';
                                        break;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                      child: SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: ChoiceChip(
                                          label: Center(
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                color: _selectedTimeRange == timeRange
                                                    ? Colors.white
                                                    : Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          selected: _selectedTimeRange == timeRange,
                                          selectedColor: Theme.of(context).colorScheme.primary,
                                          padding: EdgeInsets.zero,
                                          labelPadding: EdgeInsets.zero,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedTimeRange = timeRange;
                                                _streamKey++; // Force stream rebuild
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                // Metric buttons on the left
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _MetricType.values.map((metric) {
                                      final metricColor = _getMetricColor(metric);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: ChoiceChip(
                                          label: Text(
                                            metric.toString().split('.').last.toUpperCase(),
                                            style: TextStyle(
                                              color: _selectedMetric == metric
                                                  ? Colors.white
                                                  : metricColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          selected: _selectedMetric == metric,
                                          selectedColor: metricColor,
                                          backgroundColor: metricColor.withOpacity(0.1),
                                          side: BorderSide(
                                            color: metricColor,
                                            width: 2,
                                          ),
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedMetric = metric;
                                              });
                                            }
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const Spacer(),
                                // Time Range buttons on the rightmost side
                                Row(
                                  children: _TimeRange.values.map((timeRange) {
                                    String label;
                                    switch (timeRange) {
                                      case _TimeRange.hourly:
                                        label = 'H';
                                        break;
                                      case _TimeRange.daily:
                                        label = 'D';
                                        break;
                                      case _TimeRange.weekly:
                                        label = 'W';
                                        break;
                                      case _TimeRange.monthly:
                                        label = 'M';
                                        break;
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: ChoiceChip(
                                          label: Center(
                                            child: Text(
                                              label,
                                              style: TextStyle(
                                                color: _selectedTimeRange == timeRange
                                                    ? Colors.white
                                                    : Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          selected: _selectedTimeRange == timeRange,
                                          selectedColor: Theme.of(context).colorScheme.primary,
                                          padding: EdgeInsets.zero,
                                          labelPadding: EdgeInsets.zero,
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _selectedTimeRange = timeRange;
                                                _streamKey++; // Force stream rebuild
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            _buildLiveChart(filteredData), // Historical chart that changes with time range
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _build60SecondLiveChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<String>>(
          stream: widget.realtimeDbService.activeHubStream,
          builder: (context, snapshot) {
            final activeHubs = snapshot.data ?? [];
            if (activeHubs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No active hubs. Link a hub to see real-time data.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sensors, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aggregating data from ${activeHubs.length} hub${activeHubs.length > 1 ? 's' : ''}: ${activeHubs.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Current Value Display
        StreamBuilder<List<TimestampedFlSpot>>(
          stream: widget.realtimeDbService.getLiveChartDataStream(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? [];
            final now = DateTime.now();
            final recentData = data.where((spot) {
              return spot.timestamp.isAfter(now.subtract(const Duration(seconds: 60)));
            }).toList();

            if (recentData.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).primaryColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Waiting for data...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }

            final latestSpot = recentData.last;
            final currentValue = _getMetricValue(latestSpot, _liveChartMetric);
            final unit = _getMetricUnit(_liveChartMetric);

            // For energy metric, also show cost
            final isEnergyMetric = _liveChartMetric == _MetricType.energy;
            final currentCost = isEnergyMetric ? _getMetricValue(latestSpot, _liveChartMetric, calculateCost: true) : 0.0;

            // Calculate stats for 60-second data
            final values = recentData.map((spot) => _getMetricValue(spot, _liveChartMetric)).toList();
            final minValue = values.reduce((a, b) => a < b ? a : b);
            final maxValue = values.reduce((a, b) => a > b ? a : b);
            final avgValue = values.reduce((a, b) => a + b) / values.length;

            // Calculate cost stats if energy metric
            final List<double> costValues = isEnergyMetric ? recentData.map((spot) => _getMetricValue(spot, _liveChartMetric, calculateCost: true)).toList() : <double>[];
            final minCost = isEnergyMetric ? costValues.reduce((a, b) => a < b ? a : b) : 0.0;
            final maxCost = isEnergyMetric ? costValues.reduce((a, b) => a > b ? a : b) : 0.0;
            final avgCost = isEnergyMetric ? costValues.reduce((a, b) => a + b) / costValues.length : 0.0;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).primaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getMetricIcon(_liveChartMetric),
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current ${_liveChartMetric.toString().split('.').last.capitalize()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${currentValue.toStringAsFixed(2)} $unit',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          if (isEnergyMetric)
                            Text(
                              '≈ ₱${currentCost.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Statistics Cards for 60-second chart
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Min',
                        '${minValue.toStringAsFixed(2)} $unit${isEnergyMetric ? '\n₱${minCost.toStringAsFixed(2)}' : ''}',
                        Colors.blue
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        'Avg',
                        '${avgValue.toStringAsFixed(2)} $unit${isEnergyMetric ? '\n₱${avgCost.toStringAsFixed(2)}' : ''}',
                        Colors.green
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard(
                        'Max',
                        '${maxValue.toStringAsFixed(2)} $unit${isEnergyMetric ? '\n₱${maxCost.toStringAsFixed(2)}' : ''}',
                        Colors.orange
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Pause indicator
        if (_isChartPaused)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chart paused - Central Hub SSR is OFF',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        RealtimeLineChart(
          dataStream: widget.realtimeDbService.getLiveChartDataStream(),
          getMetricValue: (spot) => _getMetricValue(spot, _liveChartMetric),
          metricUnit: _getMetricUnit(_liveChartMetric),
          lineColor: _getMetricColor(_liveChartMetric),
          isPaused: _isChartPaused,
        ),
      ],
    );
  }

  Widget _buildLiveChart(List<TimestampedFlSpot> spots) {
    // Calculate statistics
    final stats = _calculateStats(spots);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final isEnergyMetric = _selectedMetric == _MetricType.energy;

    // Calculate cost stats if energy metric is selected
    Map<String, double> costStats = {'min': 0.0, 'max': 0.0, 'avg': 0.0};
    if (isEnergyMetric && spots.isNotEmpty) {
      final List<double> costValues = spots.map((spot) => _getMetricValue(spot, _selectedMetric, calculateCost: true)).toList();
      final minCost = costValues.reduce((a, b) => a < b ? a : b);
      final maxCost = costValues.reduce((a, b) => a > b ? a : b);
      final avgCost = costValues.reduce((a, b) => a + b) / costValues.length;
      costStats = {'min': minCost, 'max': maxCost, 'avg': avgCost};
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Value Display (matching 60-second chart design)
        if (spots.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).primaryColor,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Waiting for data...',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (spots.isNotEmpty)
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 14 : 18,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getMetricColor(_selectedMetric),
                      _getMetricColor(_selectedMetric).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: _getMetricColor(_selectedMetric).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getMetricIcon(_selectedMetric),
                        color: Colors.white,
                        size: isSmallScreen ? 28 : 36,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Current ${_selectedMetric.toString().split('.').last.capitalize()}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 13 : 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_getMetricValue(spots.last, _selectedMetric).toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 26 : 34,
                              letterSpacing: 1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isEnergyMetric)
                            Text(
                              '≈ ₱${_getMetricValue(spots.last, _selectedMetric, calculateCost: true).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 16 : 20,
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Statistics Cards (horizontal row like first chart)
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Min',
                      '${stats['min']!.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}${isEnergyMetric ? '\n₱${costStats['min']!.toStringAsFixed(2)}' : ''}',
                      Colors.blue
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Avg',
                      '${stats['avg']!.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}${isEnergyMetric ? '\n₱${costStats['avg']!.toStringAsFixed(2)}' : ''}',
                      Colors.green
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Max',
                      '${stats['max']!.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}${isEnergyMetric ? '\n₱${costStats['max']!.toStringAsFixed(2)}' : ''}',
                      Colors.orange
                    ),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 12),
        // Use same approach as first chart - animated chart that moves the X-axis
        SizedBox(
          height: MediaQuery.of(context).size.width < 600 ? 250 : 300,
          child: _AnimatedHistoricalChart(
            spots: spots,
            selectedMetric: _selectedMetric,
            selectedTimeRange: _selectedTimeRange,
            getMetricValue: _getMetricValue,
            getMetricUnit: _getMetricUnit,
            getMetricColor: _getMetricColor,
            formatXAxisLabel: _formatXAxisLabel,
            getXAxisInterval: _getXAxisInterval,
            getTimeRangeDuration: _getTimeRangeDuration,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 13,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget summaryCard(String title, String value, String change) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: isSmallScreen ? 13 : 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: isSmallScreen ? 24 : 30,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 10,
              vertical: isSmallScreen ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              change,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatXAxisLabel(double milliseconds) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt());

    switch (_selectedTimeRange) {
      case _TimeRange.hourly: // 24 hours
        return DateFormat('HH:mm').format(dateTime); // Show time (e.g., "14:00")
      case _TimeRange.daily: // 7 days
        return DateFormat('EEE').format(dateTime); // Show day of week (e.g., "Mon")
      case _TimeRange.weekly: // 30 days
        return DateFormat('MMM d').format(dateTime); // Show month and day (e.g., "Jan 15")
      case _TimeRange.monthly: // 365 days (yearly)
        return DateFormat('MMM').format(dateTime); // Show month (e.g., "Jan")
    }
  }

  double _getXAxisInterval(double minX, double maxX) {
    switch (_selectedTimeRange) {
      case _TimeRange.hourly: // 24 hours
        return const Duration(hours: 4).inMilliseconds.toDouble(); // Every 4 hours
      case _TimeRange.daily: // 7 days
        return const Duration(days: 1).inMilliseconds.toDouble(); // Every day
      case _TimeRange.weekly: // 30 days
        return const Duration(days: 5).inMilliseconds.toDouble(); // Every 5 days
      case _TimeRange.monthly: // 180 days (6 months)
        return const Duration(days: 30).inMilliseconds.toDouble(); // Every month
    }
  }
}

// Efficient animated chart widget with isolated timer
// Only rebuilds this small widget, not the entire screen
class _AnimatedLiveChart extends StatefulWidget {
  final List<FlSpot> chartFlSpots;
  final List<TimestampedFlSpot> originalSpots;
  final Widget Function(List<FlSpot>, List<TimestampedFlSpot>) lineChartBuilder;

  const _AnimatedLiveChart({
    required this.chartFlSpots,
    required this.originalSpots,
    required this.lineChartBuilder,
  });

  @override
  State<_AnimatedLiveChart> createState() => _AnimatedLiveChartState();
}

class _AnimatedLiveChartState extends State<_AnimatedLiveChart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Periodic timer to update chart every second for smooth animation
    // EFFICIENCY: Only rebuilds this small chart widget, not the entire screen
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); // Triggers rebuild of just this chart
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.lineChartBuilder(widget.chartFlSpots, widget.originalSpots);
  }
}

// Animated Historical Chart - Similar to RealtimeLineChart
// X-axis moves as time progresses, Y-axis responds to metric button selection
class _AnimatedHistoricalChart extends StatefulWidget {
  final List<TimestampedFlSpot> spots;
  final _MetricType selectedMetric;
  final _TimeRange selectedTimeRange;
  final double Function(TimestampedFlSpot, _MetricType) getMetricValue;
  final String Function(_MetricType) getMetricUnit;
  final Color Function(_MetricType) getMetricColor;
  final String Function(double) formatXAxisLabel;
  final double Function(double, double) getXAxisInterval;
  final Duration Function(_TimeRange) getTimeRangeDuration;

  const _AnimatedHistoricalChart({
    required this.spots,
    required this.selectedMetric,
    required this.selectedTimeRange,
    required this.getMetricValue,
    required this.getMetricUnit,
    required this.getMetricColor,
    required this.formatXAxisLabel,
    required this.getXAxisInterval,
    required this.getTimeRangeDuration,
  });

  @override
  State<_AnimatedHistoricalChart> createState() => _AnimatedHistoricalChartState();
}

class _AnimatedHistoricalChartState extends State<_AnimatedHistoricalChart> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Timer updates the chart every second so X-axis moves smoothly
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Split data into segments when there are time gaps
  /// This prevents connecting lines across disconnected periods
  List<List<FlSpot>> _splitIntoSegments(List<TimestampedFlSpot> spots) {
    if (spots.isEmpty) return [];

    final List<List<FlSpot>> segments = [];
    List<FlSpot> currentSegment = [];

    // Determine gap threshold based on time range
    // Thresholds are set to detect REAL disconnections, not normal data intervals
    Duration gapThreshold;
    switch (widget.selectedTimeRange) {
      case _TimeRange.hourly:
        gapThreshold = const Duration(hours: 3); // 3+ hours gap = disconnection
        break;
      case _TimeRange.daily:
        gapThreshold = const Duration(days: 2); // 2+ days gap = disconnection
        break;
      case _TimeRange.weekly:
        gapThreshold = const Duration(days: 10); // 10+ days gap = disconnection
        break;
      case _TimeRange.monthly:
        gapThreshold = const Duration(days: 45); // 45+ days gap = disconnection
        break;
    }

    for (int i = 0; i < spots.length; i++) {
      final spot = spots[i];
      final xValue = spot.timestamp.millisecondsSinceEpoch.toDouble();
      final yValue = widget.getMetricValue(spot, widget.selectedMetric);

      if (i > 0) {
        final previousSpot = spots[i - 1];
        final timeDiff = spot.timestamp.difference(previousSpot.timestamp);

        // If gap is too large, start a new segment
        if (timeDiff > gapThreshold) {
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
            currentSegment = [];
          }
        }
      }

      currentSegment.add(FlSpot(xValue, yValue));
    }

    // Add the last segment
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startTime = now.subtract(widget.getTimeRangeDuration(widget.selectedTimeRange));

    // Filter spots to time range first
    final filteredSpots = widget.spots.where((spot) {
      final spotTime = spot.timestamp.millisecondsSinceEpoch.toDouble();
      final theoreticalMinX = startTime.millisecondsSinceEpoch.toDouble();
      final theoreticalMaxX = now.millisecondsSinceEpoch.toDouble();
      return spotTime >= theoreticalMinX && spotTime <= theoreticalMaxX;
    }).toList();

    // Gap detection: Split data into segments when there are large time gaps
    // This prevents connecting lines across disconnected periods
    final List<List<FlSpot>> lineSegments = _splitIntoSegments(filteredSpots);

    // X-axis range: Use actual data range if available, otherwise use theoretical range
    double minX;
    double maxX;

    if (filteredSpots.isNotEmpty) {
      // Use the actual data's min/max timestamps
      minX = filteredSpots.map((s) => s.timestamp.millisecondsSinceEpoch.toDouble()).reduce((a, b) => a < b ? a : b);
      maxX = filteredSpots.map((s) => s.timestamp.millisecondsSinceEpoch.toDouble()).reduce((a, b) => a > b ? a : b);

      // Add small padding (2% on each side) for better visualization
      final range = maxX - minX;
      final padding = range * 0.02;
      minX = minX - padding;
      maxX = maxX + padding;
    } else {
      // No data: use theoretical time range
      minX = startTime.millisecondsSinceEpoch.toDouble();
      maxX = now.millisecondsSinceEpoch.toDouble();
    }

    final chartColor = widget.getMetricColor(widget.selectedMetric);

    // Show dots on all time ranges to mark aggregated data points
    final bool showDots = true;

    // Calculate maxY based on all segments or use default
    double maxY = 100;
    double minY = 0;
    if (lineSegments.isNotEmpty) {
      final allYValues = lineSegments.expand((segment) => segment.map((spot) => spot.y)).toList();
      if (allYValues.isNotEmpty) {
        final maxValue = allYValues.reduce((a, b) => a > b ? a : b);
        final minValue = allYValues.reduce((a, b) => a < b ? a : b);

        // Add more padding for better visualization - 25% above and below
        final range = maxValue - minValue;
        final padding = range * 0.25;

        minY = (minValue - padding).clamp(0.0, double.infinity);
        maxY = (maxValue + padding).clamp(10.0, double.infinity);
      }
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: widget.getXAxisInterval(minX, maxX),
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    widget.formatXAxisLabel(value),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(0)} ${widget.getMetricUnit(widget.selectedMetric)}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
              interval: (maxY - minY) / 5 > 0 ? (maxY - minY) / 5 : 1,
              reservedSize: 60,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withAlpha((255 * 0.3).round()),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withAlpha((255 * 0.3).round()),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
            right: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
            left: BorderSide.none,
            top: BorderSide.none,
          ),
        ),
        clipData: FlClipData.all(), // Clip lines to stay within chart boundaries
        lineBarsData: lineSegments.map((segment) {
          return LineChartBarData(
            spots: segment,
            isCurved: true, // Use smooth curves
            curveSmoothness: 0.2, // Low smoothness to prevent extreme curves
            color: chartColor,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: chartColor.withAlpha((255 * 0.2).round()),
            ),
            dotData: FlDotData(
              show: showDots, // Smart dot display: show for H/D, hide for W/M
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: chartColor,
                  strokeWidth: 2,
                  strokeColor: chartColor.withAlpha((255 * 0.5).round()),
                );
              },
            ),
            preventCurveOverShooting: true, // Prevent curve from going beyond data points
            preventCurveOvershootingThreshold: 10.0, // Strict threshold to prevent sideways curves
          );
        }).toList(),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: chartColor,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((LineBarSpot barSpot) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt());

                String formattedTime;
                switch (widget.selectedTimeRange) {
                  case _TimeRange.hourly:
                    formattedTime = DateFormat('HH:mm:ss').format(dateTime);
                    break;
                  case _TimeRange.daily:
                    formattedTime = DateFormat('MMM d, HH:mm').format(dateTime);
                    break;
                  case _TimeRange.weekly:
                    formattedTime = DateFormat('EEE, MMM d').format(dateTime);
                    break;
                  case _TimeRange.monthly:
                    formattedTime = DateFormat('MMM d, yyyy').format(dateTime);
                    break;
                }

                return LineTooltipItem(
                  '${barSpot.y.toStringAsFixed(2)} ${widget.getMetricUnit(widget.selectedMetric)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '\n$formattedTime',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}