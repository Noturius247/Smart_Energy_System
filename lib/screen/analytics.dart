import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../realtime_db_service.dart';
import 'realtime_line_chart.dart';
import '../constants.dart';
import '../services/analytics_recording_service.dart';

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

  @override
  void dispose() {
    _recordingService.dispose();
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

      // Start streams for user's hubs (already filtered by query)
      for (final serialNumber in allHubs.keys) {
        debugPrint('[AnalyticsScreen] 🚀 Starting stream for hub: $serialNumber');
        widget.realtimeDbService.startRealtimeDataStream(serialNumber);

        // Start per-second recording for 60-second live chart (65s backend buffer)
        // Flutter aggregates plug data and writes to per_second/data/
        debugPrint('[AnalyticsScreen] 📊 Starting recording service for hub: $serialNumber');
        _recordingService.startRecording(serialNumber);
        debugPrint('[AnalyticsScreen] ✅ Recording service started for hub: $serialNumber');
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('[AnalyticsScreen] Error initializing hub streams: $e');
    }
  }

  String _getMetricUnit(_MetricType metricType) {
    switch (metricType) {
      case _MetricType.power:
        return 'W';
      case _MetricType.voltage:
        return 'V';
      case _MetricType.current:
        return 'A';
      case _MetricType.energy:
        return 'kWh';
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

  String _getTimeRangeLabel(_TimeRange timeRange) {
    switch (timeRange) {
      case _TimeRange.hourly:
        return 'Hourly';
      case _TimeRange.daily:
        return 'Daily';
      case _TimeRange.weekly:
        return 'Weekly';
      case _TimeRange.monthly:
        return 'Monthly';
    }
  }

  Duration _getTimeRangeDuration(_TimeRange timeRange) {
    switch (timeRange) {
      case _TimeRange.hourly:
        return const Duration(hours: 24); // Show 24 hours (daily timeframe)
      case _TimeRange.daily:
        return const Duration(days: 7); // Show 7 days (weekly timeframe)
      case _TimeRange.weekly:
        return const Duration(days: 30); // Show 30 days (monthly timeframe)
      case _TimeRange.monthly:
        return const Duration(days: 365); // Show 365 days (yearly timeframe)
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

  double _getMetricValue(TimestampedFlSpot spot, _MetricType metricType) {
    switch (metricType) {
      case _MetricType.power:
        return spot.power;
      case _MetricType.voltage:
        return spot.voltage;
      case _MetricType.current:
        return spot.current;
      case _MetricType.energy:
        return spot.energy;
    }
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
      child: Column(
        children: [
          // Analytics Title Header
          Container(
            height: 60,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Analytics',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TimestampedFlSpot>>(
              stream: widget.realtimeDbService.getLiveChartDataStream(),
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
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Metric Selection Buttons for Live Chart - At the very top
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: _MetricType.values.map((metric) {
                            final metricColor = _getMetricColor(metric);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ChoiceChip(
                                label: Text(
                                  metric.toString().split('.').last.toUpperCase(),
                                  style: TextStyle(
                                    color: _liveChartMetric == metric
                                        ? Colors.white
                                        : metricColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: _liveChartMetric == metric,
                                selectedColor: metricColor,
                                backgroundColor: metricColor.withOpacity(0.1),
                                side: BorderSide(
                                  color: metricColor,
                                  width: 2,
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
                      const SizedBox(height: 16),
                      // 60-Second Live Chart at the TOP (independent of time range selection)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live ${_liveChartMetric.toString().split('.').last.capitalize()} Chart (Last 60 Seconds)',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Real-time ${_liveChartMetric.toString().split('.').last} from all active hubs',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Connection Status Indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _isDeviceConnected ? Colors.green : Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isDeviceConnected ? Icons.wifi : Icons.wifi_off,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isDeviceConnected ? 'Connected' : 'Offline',
                                      style: const TextStyle(color: Colors.white, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Export Button
                              IconButton(
                                icon: const Icon(Icons.download),
                                onPressed: () => _exportDataToCSV(allData),
                                tooltip: 'Export to CSV',
                              ),
                              // Refresh Button
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  setState(() {
                                    _isInitialized = false;
                                  });
                                  _initializeHubStreams();
                                },
                                tooltip: 'Refresh data',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _build60SecondLiveChart(),
                      const SizedBox(height: 30),

                      // Historical Analytics Section
                      Text(
                        'Historical Analytics',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Last Update Time
                      Text(
                        'Last update: ${_getTimeSinceLastUpdate()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Metric Selection Buttons and Time Range Buttons
                      Row(
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
                      const SizedBox(height: 16),
                      _buildLiveChart(filteredData), // Historical chart that changes with time range
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

            // Calculate stats for 60-second data
            final values = recentData.map((spot) => _getMetricValue(spot, _liveChartMetric)).toList();
            final minValue = values.reduce((a, b) => a < b ? a : b);
            final maxValue = values.reduce((a, b) => a > b ? a : b);
            final avgValue = values.reduce((a, b) => a + b) / values.length;

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
                      child: _statCard('Min', '${minValue.toStringAsFixed(2)} $unit', Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard('Avg', '${avgValue.toStringAsFixed(2)} $unit', Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _statCard('Max', '${maxValue.toStringAsFixed(2)} $unit', Colors.orange),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        RealtimeLineChart(
          dataStream: widget.realtimeDbService.getLiveChartDataStream(),
          getMetricValue: (spot) => _getMetricValue(spot, _liveChartMetric),
          metricUnit: _getMetricUnit(_liveChartMetric),
          lineColor: _getMetricColor(_liveChartMetric),
        ),
      ],
    );
  }

  Widget _buildLiveChart(List<TimestampedFlSpot> spots) {
    // Calculate statistics
    final stats = _calculateStats(spots);

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
                      _getMetricIcon(_selectedMetric),
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Current ${_selectedMetric.toString().split('.').last.capitalize()}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_getMetricValue(spots.last, _selectedMetric).toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Statistics Cards (horizontal row like first chart)
              Row(
                children: [
                  Expanded(
                    child: _statCard('Min', '${stats['min']!.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}', Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard('Avg', '${stats['avg']!.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}', Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard('Max', '${stats['max']!.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}', Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: 12),
        // Use same approach as first chart - animated chart that moves the X-axis
        SizedBox(
          height: 300,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget summaryCard(String title, String value, String change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.3).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            change,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.w500,
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
      case _TimeRange.monthly: // 365 days (yearly)
        return const Duration(days: 60).inMilliseconds.toDouble(); // Every 2 months
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startTime = now.subtract(widget.getTimeRangeDuration(widget.selectedTimeRange));

    // X-axis range based on current time (moves as time progresses)
    final double minX = startTime.millisecondsSinceEpoch.toDouble();
    final double maxX = now.millisecondsSinceEpoch.toDouble();

    // Filter spots to time range and convert to FlSpot with absolute timestamps
    final filteredSpots = widget.spots.where((spot) {
      return spot.timestamp.isAfter(startTime) && spot.timestamp.isBefore(now);
    }).toList();

    List<FlSpot> chartSpots = filteredSpots.map((spot) {
      return FlSpot(
        spot.timestamp.millisecondsSinceEpoch.toDouble(),
        widget.getMetricValue(spot, widget.selectedMetric),
      );
    }).toList();

    final chartColor = widget.getMetricColor(widget.selectedMetric);

    // Calculate maxY based on data or use default
    double maxY = 100;
    if (chartSpots.isNotEmpty) {
      final maxValue = chartSpots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
      maxY = (maxValue * 1.2).clamp(10.0, double.infinity);
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
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
              interval: maxY / 5 > 0 ? maxY / 5 : 1,
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
        lineBarsData: [
          LineChartBarData(
            spots: chartSpots,
            isCurved: true,
            color: chartColor,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: chartColor.withAlpha((255 * 0.2).round()),
            ),
            dotData: FlDotData(
              show: chartSpots.length < 50, // Show dots only if not too many points
            ),
          ),
        ],
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