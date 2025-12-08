import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import '../realtime_db_service.dart';
import '../due_date_provider.dart';
import '../widgets/notification_box.dart';
import '../constants.dart';
import '../services/usage_history_service.dart';
import '../models/usage_history_entry.dart';

// Device data model
class DeviceData {
  final String name;
  final String plugId;
  final String serialNumber;
  final double? power;
  final double? energy;
  final double? voltage;
  final double? current;
  final bool isOn;

  DeviceData({
    required this.name,
    required this.plugId,
    required this.serialNumber,
    this.power,
    this.energy,
    this.voltage,
    this.current,
    required this.isOn,
  });
}

enum _MetricType {
  power,
  voltage,
  current,
  energy,
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class EnergyOverviewScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;

  const EnergyOverviewScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergyOverviewScreen> createState() => _EnergyOverviewScreenState();
}

class _EnergyOverviewScreenState extends State<EnergyOverviewScreen> {
  // Metric selection
  _MetricType _selectedMetric = _MetricType.power;

  // Hub management
  List<Map<String, String>> _availableHubs = [];
  String? _selectedHubSerial;
  bool _isInitialized = false;
  bool _isHubActive = true; // Track hub ssr_state
  StreamSubscription<bool>? _ssrStateSubscription;
  StreamSubscription<String?>? _primaryHubSubscription; // Added for primary hub
  StreamSubscription<String>? _hubRemovedSubscription; // Added for hub removal
  StreamSubscription<Map<String, String>>? _hubAddedSubscription; // Added for hub addition

  // Settings
  double _pricePerKWH = 0.0;
  String _currencySymbol = '₱';

  // Calculator input state
  final TextEditingController _wattageController =
      TextEditingController(text: '100');
  final TextEditingController _hoursController =
      TextEditingController(text: '1');
  double _calculatedCost = 0.0;

  // Device data caching
  List<DeviceData> _cachedDevices = [];
  DateTime? _lastDeviceFetch;
  Timer? _deviceRefreshTimer;

  // Latest daily usage data from usage history
  UsageHistoryEntry? _latestDailyUsage;
  late UsageHistoryService _usageHistoryService;

  /// Returns a stream of LIVE per-second data for the selected hub or all hubs.
  Stream<List<TimestampedFlSpot>> _getLiveDataStream() {
    if (_selectedHubSerial != null) {
      return widget.realtimeDbService
          .getLiveChartDataStreamForHub(_selectedHubSerial!);
    } else {
      // Fallback to the combined stream for all active hubs
      return widget.realtimeDbService.getLiveChartDataStream();
    }
  }

  @override
  void initState() {
    super.initState();
    // Prioritize the primary hub from the service on initial load
    _selectedHubSerial = widget.realtimeDbService.primaryHub;

    // Initialize usage history service
    _usageHistoryService = UsageHistoryService(widget.realtimeDbService);

    _initializeHubStreams();
    _loadPricePerKWH();
    _loadCurrencySymbol();
    _calculateCustomCost(); // Initialize calculator with default values
    _startDeviceRefreshTimer();
    _startHubRemovedListener();
    _startHubAddedListener();
    _fetchLatestDailyUsage(); // Fetch latest daily usage for cost calculation

    // Listen for changes to the primary hub
    _primaryHubSubscription =
        widget.realtimeDbService.primaryHubStream.listen((hubSerial) {
      // If the hub is different, update the state and re-initialize listeners
      if (hubSerial != null && _selectedHubSerial != hubSerial) {
        debugPrint(
            '[EnergyOverview] Primary hub changed to: $hubSerial. Updating screen...');
        setState(() {
          _selectedHubSerial = hubSerial;
          // Re-initialize listeners for the new hub and force a rebuild to get new data
          _initializeSsrStateListener();
        });
        // Fetch latest daily usage for the new hub
        _fetchLatestDailyUsage();
      }
    });
  }

  void _startDeviceRefreshTimer() {
    // Fetch devices immediately
    _refreshDevices();

    // Refresh device data every 30 seconds instead of on every stream update
    _deviceRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDevices();
    });
  }

  Future<void> _refreshDevices() async {
    final devices = await _fetchAllDevices();
    if (mounted) {
      setState(() {
        _cachedDevices = devices;
        _lastDeviceFetch = DateTime.now();
      });
    }
  }

  /// Fetch the latest daily usage from usage history
  /// This calculates the difference between past and present daily readings
  Future<void> _fetchLatestDailyUsage() async {
    if (_selectedHubSerial == null) {
      debugPrint('[EnergyOverview] No hub selected, skipping latest daily usage fetch');
      return;
    }

    try {
      debugPrint('[EnergyOverview] Fetching latest daily usage for hub $_selectedHubSerial');

      // Get the latest daily usage history (just need 1 entry - the most recent)
      final usageHistory = await _usageHistoryService.calculateUsageHistory(
        hubSerialNumber: _selectedHubSerial!,
        interval: UsageInterval.daily,
        minRows: 1,
        offset: 0,
      );

      if (usageHistory.isNotEmpty && mounted) {
        setState(() {
          // Store the latest daily usage entry
          _latestDailyUsage = usageHistory.first;
          debugPrint('[EnergyOverview] Latest daily usage: '
              '${_latestDailyUsage!.usage.toStringAsFixed(3)} kWh '
              '(${_latestDailyUsage!.getFormattedTimestamp()}) - '
              'Previous: ${_latestDailyUsage!.previousReading.toStringAsFixed(3)} kWh, '
              'Current: ${_latestDailyUsage!.currentReading.toStringAsFixed(3)} kWh');
        });
      } else {
        debugPrint('[EnergyOverview] No daily usage data available');
        if (mounted) {
          setState(() {
            _latestDailyUsage = null;
          });
        }
      }
    } catch (e) {
      debugPrint('[EnergyOverview] Error fetching latest daily usage: $e');
    }
  }

  Future<void> _initializeHubStreams() async {
    if (_isInitialized) return;

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final hubSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(currentUser.uid)
          .get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) {
        return;
      }

      final allHubs = Map<String, dynamic>.from(hubSnapshot.value as Map);
      final List<Map<String, String>> hubList = [];

      for (final serialNumber in allHubs.keys) {
        final hubData = Map<String, dynamic>.from(allHubs[serialNumber]);
        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        if (!isAssigned || hubOwnerId != currentUser.uid) continue;

        final String? nickname = hubData['nickname'] as String?;
        hubList.add({
          'serialNumber': serialNumber,
          'nickname': nickname ?? 'Central Hub',
        });

        widget.realtimeDbService.startRealtimeDataStream(serialNumber);
      }

      setState(() {
        _availableHubs = hubList;
        // If no hub is selected yet (i.e., not set by primary hub), select the first one.
        if (_selectedHubSerial == null && hubList.length == 1) {
          _selectedHubSerial = hubList.first['serialNumber'];
        }
        _isInitialized = true;
      });

      // Initialize SSR state listener
      _initializeSsrStateListener();
    } catch (e) {
      debugPrint('[EnergyOverview] Error initializing hubs: $e');
    }
  }

  void _initializeSsrStateListener() {
    // Cancel any existing subscription before creating a new one
    _ssrStateSubscription?.cancel();

    final Stream<bool> ssrStream;

    if (_selectedHubSerial != null) {
      ssrStream =
          widget.realtimeDbService.getHubSsrStateStream(_selectedHubSerial!);
    } else {
      ssrStream = widget.realtimeDbService.getCombinedSsrStateStream();
    }

    _ssrStateSubscription = ssrStream.listen((isOn) {
      if (mounted) {
        setState(() {
          _isHubActive = isOn;
        });
        debugPrint(
            '[EnergyOverview] Hub active state changed: ${isOn ? "ACTIVE" : "INACTIVE"}');
      }
    });
  }

  Future<void> _loadPricePerKWH() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('pricePerKWH')) {
        setState(() {
          _pricePerKWH = (doc.data()!['pricePerKWH'] as num?)?.toDouble() ?? 12.0;
        });
      }
    } catch (e) {
      debugPrint('[EnergyOverview] Error loading price: $e');
    }
  }

  Future<void> _loadCurrencySymbol() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('currency')) {
        setState(() {
          _currencySymbol = doc.data()!['currency'] as String? ?? '₱';
        });
      }
    } catch (e) {
      debugPrint('[EnergyOverview] Error loading currency: $e');
    }
  }

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

  Stream<List<TimestampedFlSpot>> _getHistoricalDataStream() {
    if (_selectedHubSerial != null) {
      // Use the new, efficient listener stream for the overview screen
      return widget.realtimeDbService.getOverviewHourlyStream(
        _selectedHubSerial!,
      );
    } else {
      // Fallback to the combined listener stream for all hubs
      return widget.realtimeDbService.getOverviewHourlyStreamForAllHubs();
    }
  }

  // Fetch all devices from all hubs
  Future<List<DeviceData>> _fetchAllDevices() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];

    try {
      final hubSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(currentUser.uid)
          .get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) return [];

      final allHubs = Map<String, dynamic>.from(hubSnapshot.value as Map);
      final List<DeviceData> devices = [];

      for (final serialNumber in allHubs.keys) {
        final hubData = Map<String, dynamic>.from(allHubs[serialNumber]);
        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        if (!isAssigned || hubOwnerId != currentUser.uid) continue;

        // Get plugs for this hub
        final plugs = hubData['plugs'];
        if (plugs != null && plugs is Map) {
          for (final plugId in plugs.keys) {
            final plugData = Map<String, dynamic>.from(plugs[plugId]);
            final plugNickname = plugData['nickname'] as String?;
            final data = plugData['data'];

            if (data != null && data is Map) {
              final dataMap = Map<String, dynamic>.from(data);
              devices.add(DeviceData(
                name: plugNickname ?? 'Plug $plugId',
                plugId: plugId,
                serialNumber: serialNumber,
                power: (dataMap['power'] as num?)?.toDouble(),
                energy: (dataMap['energy'] as num?)?.toDouble(),
                voltage: (dataMap['voltage'] as num?)?.toDouble(),
                current: (dataMap['current'] as num?)?.toDouble(),
                isOn: (dataMap['ssr_state'] as bool?) ?? false,
              ));
            }
          }
        }
      }

      return devices;
    } catch (e) {
      debugPrint('[EnergyOverview] Error fetching devices: $e');
      return [];
    }
  }

  Widget _currentEnergyCard(List<TimestampedFlSpot> data,
      {required bool isDeviceConnected}) {
    final now = DateTime.now();
    final formattedDate =
        DateFormat('EEEE, MMMM d, yyyy - hh:mm a').format(now);

    // Get current value from latest data
    final currentValue =
        data.isNotEmpty ? _getMetricValue(data.last, _selectedMetric) : 0.0;
    final unit = _getMetricUnit(_selectedMetric);

    // Calculate percentage (simplified - using max value as 100%)
    final maxValue = data.isNotEmpty
        ? data
            .map((d) => _getMetricValue(d, _selectedMetric))
            .reduce((a, b) => a > b ? a : b)
        : 100.0;
    final percentage =
        maxValue > 0 ? (currentValue / maxValue).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Current ${_selectedMetric.toString().split('.').last.capitalize()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Real-time ${_selectedMetric.toString().split('.').last} reading from your energy hub. The percentage shows current value relative to the maximum recorded in the last 24 hours.',
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${currentValue.toStringAsFixed(2)} $unit',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  (isDeviceConnected && _isHubActive) ? 'Connected' : 'Offline',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: (isDeviceConnected && _isHubActive)
                            ? Colors.green
                            : Colors.red,
                      ),
                ),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: CircularProgressIndicator(
                  value: percentage,
                  color: _getMetricColor(_selectedMetric),
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withAlpha((255 * 0.2).round()),
                  strokeWidth: 5,
                ),
              ),
              Text(
                '${(percentage * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _solarProductionCard(List<TimestampedFlSpot> data) {
    // Use the latest daily usage from Usage History
    // This shows the difference between past and present daily readings
    final totalEnergy = _latestDailyUsage?.usage ?? 0.0;
    final totalCost = totalEnergy * _pricePerKWH;

    // Get the date of the latest daily usage
    final dateLabel = _latestDailyUsage != null
        ? _latestDailyUsage!.getFormattedTimestamp()
        : 'No data';

    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily Usage',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Tooltip(
                message: 'Latest daily energy usage calculated from Usage History as the difference between today\'s reading and yesterday\'s reading, multiplied by your configured price per kWh.',
                child: Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$_currencySymbol${totalCost.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: totalEnergy > 0 ? 0.7 : 0.0,
            backgroundColor: Theme.of(
              context,
            ).primaryColor.withAlpha((255 * 0.2).round()),
            color: Theme.of(context).colorScheme.secondary,
            minHeight: 5,
          ),
          const SizedBox(height: 3),
          Text(
            'Energy: ${totalEnergy.toStringAsFixed(2)} kWh',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 9,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Monthly Cost Estimate Card
  Widget _monthlyCostCard(List<TimestampedFlSpot> data) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    // Use the latest daily usage from Usage History
    // This provides accurate daily consumption based on actual meter readings
    final dailyEnergy = _latestDailyUsage?.usage ?? 0.0;

    // Estimate monthly cost (daily * 30 days)
    final monthlyCost = dailyEnergy * 30 * _pricePerKWH;
    final monthlyEnergy = dailyEnergy * 30;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.cyan.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Monthly Estimate',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Projected monthly cost based on your latest daily usage from Usage History (today\'s consumption × 30 days).',
                          child: Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_currencySymbol${monthlyCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Avg',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$_currencySymbol${(dailyEnergy * _pricePerKWH).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.blue.withOpacity(0.3),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy/Month',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${monthlyEnergy.toStringAsFixed(1)} kWh',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cost Calculator Widget
  Widget _costCalculator() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: Theme.of(context).colorScheme.secondary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Quick Cost Calculator',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Calculate estimated costs based on your current electricity price of $_currencySymbol$_pricePerKWH per kWh.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current Rate: $_currencySymbol$_pricePerKWH per kWh',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Custom Input Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculate Your Cost',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wattage (W)',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _wattageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '100',
                              suffixText: 'W',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 10 : 12,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _calculateCustomCost(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hours/Day',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _hoursController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '1',
                              suffixText: 'hrs',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 10 : 12,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.secondary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (_) => _calculateCustomCost(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Cost:',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$_currencySymbol${_calculatedCost.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Cost:',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$_currencySymbol${(_calculatedCost * 30).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Common appliances - LED bulb: 10W, Laptop: 50W, TV: 100W, AC: 1000W, Ref: 150W',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _calculateCustomCost() {
    final wattage = double.tryParse(_wattageController.text) ?? 0;
    final hours = double.tryParse(_hoursController.text) ?? 0;

    // Calculate: (Wattage / 1000) * Hours * PricePerKWH = Daily Cost
    final energyKWH = (wattage / 1000) * hours;
    setState(() {
      _calculatedCost = energyKWH * _pricePerKWH;
    });
  }

  // Device Summary Widget
  Widget _deviceSummaryCard(List<DeviceData> devices) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    final activeDevices = devices.where((d) => d.isOn).length;
    final totalDevices = devices.length;
    final totalPower = devices.fold<double>(0.0, (sum, d) => sum + (d.power ?? 0.0));
    final totalEnergy = devices.fold<double>(0.0, (sum, d) => sum + (d.energy ?? 0.0));
    final totalCost = totalEnergy * _pricePerKWH;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Device Summary',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 16 : 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Overview of all connected smart plugs showing total power consumption, energy usage, and costs across all devices.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: activeDevices > 0 ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$activeDevices/$totalDevices Active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  'Total Power',
                  '${totalPower.toStringAsFixed(1)} W',
                  Icons.bolt,
                  Colors.purple,
                  isSmallScreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryMetric(
                  'Total Energy',
                  '${totalEnergy.toStringAsFixed(2)} kWh',
                  Icons.battery_charging_full,
                  Colors.green,
                  isSmallScreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _summaryMetric(
            'Total Cost',
            '$_currencySymbol${totalCost.toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.orange,
            isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value, IconData icon, Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Top Energy Consumer Widget
  Widget _topEnergyConsumer(List<DeviceData> devices) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    // Find device with highest power consumption
    final topDevice = devices.reduce((a, b) =>
      (a.power ?? 0.0) > (b.power ?? 0.0) ? a : b
    );

    if ((topDevice.power ?? 0.0) <= 0.0) {
      return const SizedBox.shrink();
    }

    final totalPower = devices.fold<double>(0.0, (sum, d) => sum + (d.power ?? 0.0));
    final percentage = totalPower > 0 ? ((topDevice.power ?? 0.0) / totalPower * 100) : 0.0;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.1),
            Colors.deepOrange.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Top Energy Consumer',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Identifies the device consuming the most power right now. Helps you understand which appliance is using the most energy.',
                          child: Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      topDevice.name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 12,
                  vertical: isSmallScreen ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _topDeviceMetric(
                'Power',
                '${topDevice.power?.toStringAsFixed(1) ?? '0'} W',
                isSmallScreen,
              ),
              _topDeviceMetric(
                'Energy',
                '${topDevice.energy?.toStringAsFixed(2) ?? '0'} kWh',
                isSmallScreen,
              ),
              _topDeviceMetric(
                'Cost',
                '$_currencySymbol${((topDevice.energy ?? 0.0) * _pricePerKWH).toStringAsFixed(2)}',
                isSmallScreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topDeviceMetric(String label, String value, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
      ],
    );
  }

  Widget _historicalChart(List<TimestampedFlSpot> spots,
      {required bool isDeviceConnected}) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    "Historical Data (24h)",
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        'View trends over the last 24 hours. Switch between Power, Voltage, Current, and Energy metrics using the chips below.',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (isDeviceConnected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.wifi, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Live',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Metric Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _MetricType.values.map((metric) {
                final metricColor = _getMetricColor(metric);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 3.0 : 4.0),
                  child: ChoiceChip(
                    label: Text(
                      metric.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        color: _selectedMetric == metric
                            ? Colors.white
                            : metricColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    selected: _selectedMetric == metric,
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
                          _selectedMetric = metric;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Chart
          SizedBox(
            height: 200,
            child: _buildChart(spots),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<TimestampedFlSpot> spots) {
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final now = DateTime.now();
    final startTime = now.subtract(const Duration(hours: 24));
    final minX = startTime.millisecondsSinceEpoch.toDouble();
    final maxX = now.millisecondsSinceEpoch.toDouble();

    final chartSpots = spots.map((spot) {
      final xValue = spot.timestamp.millisecondsSinceEpoch.toDouble();
      return FlSpot(
        xValue.clamp(minX, maxX),
        _getMetricValue(spot, _selectedMetric),
      );
    }).toList();

    final maxY = chartSpots.isNotEmpty
        ? (chartSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2).clamp(10.0, double.infinity)
        : 100.0;

    final chartColor = _getMetricColor(_selectedMetric);

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
              interval: const Duration(hours: 4).inMilliseconds.toDouble(),
              getTitlesWidget: (value, meta) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('HH:mm').format(dateTime),
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
                  '${value.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
              interval: maxY / 5 > 0 ? maxY / 5 : 1,
              reservedSize: 40,
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
            left: BorderSide(color: Colors.grey.withAlpha((255 * 0.5).round()), width: 2),
            right: BorderSide.none,
            top: BorderSide.none,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: chartSpots,
            isCurved: true, // Use smooth curves
            curveSmoothness: 0.2, // Low smoothness to prevent extreme curves
            color: chartColor,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: chartColor.withAlpha((255 * 0.2).round()),
            ),
            dotData: FlDotData(
              show: true, // Always show dots to mark specific data points
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
          ),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: chartColor,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(2)} ${_getMetricUnit(_selectedMetric)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '\n${DateFormat('HH:mm:ss').format(dateTime)}',
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

  Widget _tipTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _energyTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Smart Energy Tips',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Helpful tips to reduce your energy consumption and lower your electricity bills.',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Lighting Tips
        Text(
          'Lighting',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.lightbulb,
          'Switch to LED',
          'LED bulbs use up to 80% less energy than incandescent bulbs.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.wb_sunny,
          'Use Natural Light',
          'Open curtains during the day to reduce artificial lighting needs.',
        ),
        const SizedBox(height: 12),

        // Cooling & Heating Tips
        Text(
          'Cooling & Heating',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.ac_unit,
          'Efficient AC Use',
          'Set air conditioners between 24–25°C for efficiency.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.mode_fan_off,
          'Use Ceiling Fans',
          'Fans make rooms feel 3–4°C cooler, reducing AC dependence.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.filter_alt,
          'Clean AC Filters',
          'Clean or replace AC filters monthly to maintain efficiency.',
        ),
        const SizedBox(height: 12),

        // Appliance Tips
        Text(
          'Appliances',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.kitchen,
          'Refrigerator Efficiency',
          'Keep refrigerator at 2–4°C and freezer at -18°C.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.local_laundry_service,
          'Run Full Loads',
          'Washers and dishwashers are most efficient when fully loaded.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.water_drop,
          'Cold Water Washing',
          'Wash clothes in cold water to save on water heating costs.',
        ),
        const SizedBox(height: 12),

        // Electronics & Standby Power
        Text(
          'Electronics & Standby Power',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.battery_charging_full,
          'Unplug Chargers',
          'Unplug devices once fully charged to avoid phantom load.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.power,
          'Use Smart Plugs',
          'Monitor and control appliances remotely with smart plugs.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.power_settings_new,
          'Enable Sleep Mode',
          'Put computers and monitors to sleep when not in use.',
        ),
        const SizedBox(height: 12),

        // Water Heating
        Text(
          'Water Heating',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.thermostat,
          'Lower Water Heater Temp',
          'Set water heater to 50–55°C to save energy safely.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.shower,
          'Shorter Showers',
          'Reduce shower time by 2–3 minutes to save hot water.',
        ),
        const SizedBox(height: 12),

        // General Habits
        Text(
          'General Habits',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.access_time,
          'Off-Peak Usage',
          'Use high-energy appliances during off-peak hours if available.',
        ),
        const SizedBox(height: 6),
        _tipTile(
          Icons.shield,
          'Seal Air Leaks',
          'Check windows and doors for air leaks to improve insulation.',
        ),
      ],
    );
  }

  void _startHubRemovedListener() {
    // Listen to hub removal events from the service
    _hubRemovedSubscription = widget.realtimeDbService.hubRemovedStream.listen((removedHubSerial) {
      if (!mounted) return;

      debugPrint('[EnergyOverview] Hub removed event received: $removedHubSerial');

      setState(() {
        // Remove the hub from available hubs list
        _availableHubs.removeWhere((hub) => hub['serialNumber'] == removedHubSerial);

        // If the removed hub was selected, switch to another hub or clear selection
        if (_selectedHubSerial == removedHubSerial) {
          if (_availableHubs.isNotEmpty) {
            _selectedHubSerial = _availableHubs.first['serialNumber'];
            debugPrint('[EnergyOverview] Switched to hub: $_selectedHubSerial');
            // Restart SSR state listener for the new hub
            _initializeSsrStateListener();
            // Fetch latest daily usage for the new hub
            _fetchLatestDailyUsage();
          } else {
            _selectedHubSerial = null;
            _isHubActive = false;
            _latestDailyUsage = null;
            debugPrint('[EnergyOverview] No hubs available after removal');
          }
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

      debugPrint('[EnergyOverview] Hub added event received: $serialNumber');

      setState(() {
        // Add the hub to available hubs list if not already present
        if (!_availableHubs.any((hub) => hub['serialNumber'] == serialNumber)) {
          _availableHubs.add({
            'serialNumber': serialNumber,
            'nickname': nickname,
          });
          debugPrint('[EnergyOverview] Added hub to list: $serialNumber');

          // If this is the first hub, select it automatically
          if (_availableHubs.length == 1) {
            _selectedHubSerial = serialNumber;
            debugPrint('[EnergyOverview] Auto-selected first hub: $serialNumber');
            // Start SSR state listener for the new hub
            _initializeSsrStateListener();
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
    _wattageController.dispose();
    _hoursController.dispose();
    _deviceRefreshTimer?.cancel();
    _ssrStateSubscription?.cancel();
    _primaryHubSubscription?.cancel(); // Cancel the primary hub subscription
    _hubRemovedSubscription?.cancel(); // Cancel the hub removed subscription
    _hubAddedSubscription?.cancel(); // Cancel the hub added subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use cached devices instead of fetching on every stream update
    final List<DeviceData> devices = _cachedDevices;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // This StreamBuilder handles all widgets that depend on LIVE data
          StreamBuilder<List<TimestampedFlSpot>>(
            stream: _getLiveDataStream(),
            builder: (context, liveSnapshot) {
              final List<TimestampedFlSpot> liveData = liveSnapshot.data ?? [];
              // Determine connection status based on the live data stream
              final bool isDeviceConnected = liveData.isNotEmpty &&
                  DateTime.now().difference(liveData.last.timestamp).inMinutes <
                      2;

              return Column(
                children: [
                  const SizedBox(height: 12),
                  // Due Date and Notification Box Row
                  Row(
                    children: [
                      const Expanded(
                        child: MiniNotificationBox(),
                      ),
                      Consumer<DueDateProvider>(
                        builder: (context, dueDateProvider, _) {
                          if (dueDateProvider.dueDate == null) {
                            return const SizedBox.shrink();
                          }
                          return const SizedBox(width: 8);
                        },
                      ),
                      Consumer<DueDateProvider>(
                        builder: (context, dueDateProvider, _) {
                          if (dueDateProvider.dueDate == null) {
                            return const SizedBox.shrink();
                          }

                          return Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: dueDateProvider.isOverdue
                                    ? Colors.red.withAlpha(25)
                                    : Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: dueDateProvider.isOverdue
                                      ? Colors.red
                                      : Theme.of(context)
                                          .colorScheme
                                          .secondary
                                          .withAlpha(77),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: dueDateProvider.isOverdue
                                        ? Colors.red
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Due Date',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey,
                                                fontSize: 11,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dueDateProvider
                                                  .getFormattedDueDate() ??
                                              '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: dueDateProvider.isOverdue
                                          ? Colors.red
                                          : Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      dueDateProvider.isOverdue
                                          ? 'Overdue ${dueDateProvider.getDaysRemaining()!.abs()}d'
                                          : '${dueDateProvider.getDaysRemaining()}d left',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                  // Current Energy and Daily Cost Row
                  Row(
                    children: [
                      Expanded(
                          child: _currentEnergyCard(liveData,
                              isDeviceConnected: isDeviceConnected)),
                      const SizedBox(width: 10),
                      _solarProductionCard(liveData),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Monthly Cost Estimate
                  _monthlyCostCard(liveData),
                  const SizedBox(height: 12),
                  // Cost Calculator
                  _costCalculator(),
                  const SizedBox(height: 12),
                  // Device Summary Card
                  if (devices.isNotEmpty) ...[
                    _deviceSummaryCard(devices),
                    const SizedBox(height: 12),
                  ],
                  // Top Energy Consumer
                  if (devices.isNotEmpty) ...[
                    _topEnergyConsumer(devices),
                    const SizedBox(height: 12),
                  ],
                  // This StreamBuilder handles the historical chart
                  StreamBuilder<List<TimestampedFlSpot>>(
                    stream: _getHistoricalDataStream(),
                    builder: (context, historicalSnapshot) {
                      final List<TimestampedFlSpot> historicalData =
                          historicalSnapshot.data ?? [];
                      return _historicalChart(historicalData,
                          isDeviceConnected: isDeviceConnected);
                    },
                  ),
                  const SizedBox(height: 12),
                  _energyTipsSection(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
