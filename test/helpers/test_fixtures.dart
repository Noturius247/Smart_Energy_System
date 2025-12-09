import 'package:smartenergy_app/models/usage_history_entry.dart';
import 'package:smartenergy_app/models/history_record.dart';

/// Comprehensive test fixtures and sample data for unit tests
class TestFixtures {
  // ==================== USAGE HISTORY FIXTURES ====================

  /// Sample hourly readings for a single day (24 hours)
  static List<Map<String, dynamic>> hourlyReadingsOneDayRaw() => [
    {'timestamp': '2025-12-09T00:00:00Z', 'totalEnergy': 100.0},
    {'timestamp': '2025-12-09T01:00:00Z', 'totalEnergy': 102.5},
    {'timestamp': '2025-12-09T02:00:00Z', 'totalEnergy': 105.0},
    {'timestamp': '2025-12-09T03:00:00Z', 'totalEnergy': 107.8},
    {'timestamp': '2025-12-09T04:00:00Z', 'totalEnergy': 110.2},
    {'timestamp': '2025-12-09T05:00:00Z', 'totalEnergy': 112.5},
    {'timestamp': '2025-12-09T06:00:00Z', 'totalEnergy': 115.0},
    {'timestamp': '2025-12-09T07:00:00Z', 'totalEnergy': 118.5},
    {'timestamp': '2025-12-09T08:00:00Z', 'totalEnergy': 122.0},
    {'timestamp': '2025-12-09T09:00:00Z', 'totalEnergy': 125.5},
    {'timestamp': '2025-12-09T10:00:00Z', 'totalEnergy': 129.0},
    {'timestamp': '2025-12-09T11:00:00Z', 'totalEnergy': 132.5},
    {'timestamp': '2025-12-09T12:00:00Z', 'totalEnergy': 136.0},
    {'timestamp': '2025-12-09T13:00:00Z', 'totalEnergy': 139.5},
    {'timestamp': '2025-12-09T14:00:00Z', 'totalEnergy': 143.0},
    {'timestamp': '2025-12-09T15:00:00Z', 'totalEnergy': 146.5},
    {'timestamp': '2025-12-09T16:00:00Z', 'totalEnergy': 150.0},
    {'timestamp': '2025-12-09T17:00:00Z', 'totalEnergy': 153.5},
    {'timestamp': '2025-12-09T18:00:00Z', 'totalEnergy': 157.0},
    {'timestamp': '2025-12-09T19:00:00Z', 'totalEnergy': 160.5},
    {'timestamp': '2025-12-09T20:00:00Z', 'totalEnergy': 164.0},
    {'timestamp': '2025-12-09T21:00:00Z', 'totalEnergy': 167.5},
    {'timestamp': '2025-12-09T22:00:00Z', 'totalEnergy': 171.0},
    {'timestamp': '2025-12-09T23:00:00Z', 'totalEnergy': 174.5},
  ];

  /// Sample daily readings for a month (30 days)
  static List<Map<String, dynamic>> dailyReadingsOneMonthRaw() {
    final readings = <Map<String, dynamic>>[];
    double energy = 100.0;

    for (int day = 1; day <= 30; day++) {
      readings.add({
        'timestamp': '2025-12-${day.toString().padLeft(2, '0')}T00:00:00Z',
        'totalEnergy': energy,
      });
      energy += 24.0; // 24 kWh per day
    }

    return readings;
  }

  /// Sample weekly aggregated data
  static List<Map<String, dynamic>> weeklyAggregatedDataRaw() => [
    {
      'periodKey': '2025-W01',
      'totalEnergy': 168.0,
      'averagePower': 1000.0,
      'minPower': 500.0,
      'maxPower': 2000.0,
      'averageVoltage': 220.0,
      'minVoltage': 215.0,
      'maxVoltage': 225.0,
      'averageCurrent': 4.5,
      'minCurrent': 2.3,
      'maxCurrent': 9.1,
      'totalReadings': 1008,
    },
    {
      'periodKey': '2025-W02',
      'totalEnergy': 175.2,
      'averagePower': 1050.0,
      'minPower': 550.0,
      'maxPower': 2100.0,
      'averageVoltage': 220.5,
      'minVoltage': 216.0,
      'maxVoltage': 226.0,
      'averageCurrent': 4.8,
      'minCurrent': 2.5,
      'maxCurrent': 9.5,
      'totalReadings': 1008,
    },
  ];

  /// Sample monthly aggregated data
  static List<Map<String, dynamic>> monthlyAggregatedDataRaw() => [
    {
      'periodKey': '2025-01',
      'totalEnergy': 720.0,
      'averagePower': 1000.0,
      'minPower': 400.0,
      'maxPower': 2500.0,
      'averageVoltage': 220.0,
      'minVoltage': 210.0,
      'maxVoltage': 230.0,
      'averageCurrent': 4.5,
      'minCurrent': 1.8,
      'maxCurrent': 11.4,
      'totalReadings': 44640,
    },
    {
      'periodKey': '2025-02',
      'totalEnergy': 672.0,
      'averagePower': 1000.0,
      'minPower': 400.0,
      'maxPower': 2400.0,
      'averageVoltage': 220.0,
      'minVoltage': 212.0,
      'maxVoltage': 228.0,
      'averageCurrent': 4.5,
      'minCurrent': 1.9,
      'maxCurrent': 10.9,
      'totalReadings': 40320,
    },
  ];

  /// Sample realtime sensor readings (per-second data)
  static List<Map<String, dynamic>> realtimeSensorReadings() => [
    {
      'timestamp': DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String(),
      'power': 1200.0,
      'voltage': 220.0,
      'current': 5.45,
      'energy': 150.5,
    },
    {
      'timestamp': DateTime.now().subtract(const Duration(seconds: 9)).toIso8601String(),
      'power': 1205.0,
      'voltage': 220.5,
      'current': 5.46,
      'energy': 150.51,
    },
    {
      'timestamp': DateTime.now().subtract(const Duration(seconds: 8)).toIso8601String(),
      'power': 1198.0,
      'voltage': 219.8,
      'current': 5.45,
      'energy': 150.52,
    },
  ];

  /// Edge case: readings with gaps (missing hours)
  static List<Map<String, dynamic>> hourlyReadingsWithGaps() => [
    {'timestamp': '2025-12-09T00:00:00Z', 'totalEnergy': 100.0},
    {'timestamp': '2025-12-09T01:00:00Z', 'totalEnergy': 102.5},
    // Missing hour 2
    {'timestamp': '2025-12-09T03:00:00Z', 'totalEnergy': 107.8},
    {'timestamp': '2025-12-09T04:00:00Z', 'totalEnergy': 110.2},
    // Missing hours 5-7
    {'timestamp': '2025-12-09T08:00:00Z', 'totalEnergy': 122.0},
  ];

  /// Edge case: zero usage periods (meter reading doesn't change)
  static List<Map<String, dynamic>> hourlyReadingsWithZeroUsage() => [
    {'timestamp': '2025-12-09T00:00:00Z', 'totalEnergy': 100.0},
    {'timestamp': '2025-12-09T01:00:00Z', 'totalEnergy': 102.5},
    {'timestamp': '2025-12-09T02:00:00Z', 'totalEnergy': 102.5}, // No usage
    {'timestamp': '2025-12-09T03:00:00Z', 'totalEnergy': 102.5}, // No usage
    {'timestamp': '2025-12-09T04:00:00Z', 'totalEnergy': 105.0},
  ];

  /// Edge case: single reading
  static List<Map<String, dynamic>> singleReading() => [
    {'timestamp': '2025-12-09T00:00:00Z', 'totalEnergy': 100.0},
  ];

  /// Edge case: empty readings
  static List<Map<String, dynamic>> emptyReadings() => [];

  // ==================== USAGE HISTORY ENTRY FIXTURES ====================

  static UsageHistoryEntry sampleHourlyEntry() => UsageHistoryEntry(
    timestamp: DateTime(2025, 12, 9, 1),
    interval: UsageInterval.hourly,
    previousReading: 100.0,
    currentReading: 102.5,
    usage: 2.5,
  );

  static UsageHistoryEntry sampleDailyEntry() => UsageHistoryEntry(
    timestamp: DateTime(2025, 12, 9),
    interval: UsageInterval.daily,
    previousReading: 100.0,
    currentReading: 124.0,
    usage: 24.0,
  );

  static UsageHistoryEntry sampleWeeklyEntry() => UsageHistoryEntry(
    timestamp: DateTime(2025, 12, 8), // Week starts on Monday
    interval: UsageInterval.weekly,
    previousReading: 100.0,
    currentReading: 268.0,
    usage: 168.0,
  );

  static UsageHistoryEntry sampleMonthlyEntry() => UsageHistoryEntry(
    timestamp: DateTime(2025, 12, 1),
    interval: UsageInterval.monthly,
    previousReading: 100.0,
    currentReading: 820.0,
    usage: 720.0,
  );

  static UsageHistoryEntry zeroUsageEntry() => UsageHistoryEntry(
    timestamp: DateTime(2025, 12, 9, 2),
    interval: UsageInterval.hourly,
    previousReading: 102.5,
    currentReading: 102.5,
    usage: 0.0,
  );

  // ==================== HISTORY RECORD FIXTURES ====================

  static HistoryRecord sampleHourlyRecord() => HistoryRecord(
    timestamp: DateTime(2025, 12, 9, 14),
    deviceName: 'Living Room Hub',
    hubName: 'HUB001',
    averagePower: 1200.0,
    minPower: 500.0,
    maxPower: 2000.0,
    averageVoltage: 220.0,
    minVoltage: 215.0,
    maxVoltage: 225.0,
    averageCurrent: 5.45,
    minCurrent: 2.27,
    maxCurrent: 9.09,
    totalEnergy: 1.2,
    totalReadings: 3600,
    aggregationType: AggregationType.hourly,
    periodKey: '2025-12-09-14',
  );

  static HistoryRecord sampleDailyRecord() => HistoryRecord(
    timestamp: DateTime(2025, 12, 9),
    deviceName: 'Living Room Hub',
    hubName: 'HUB001',
    averagePower: 1100.0,
    minPower: 400.0,
    maxPower: 2200.0,
    averageVoltage: 220.0,
    minVoltage: 212.0,
    maxVoltage: 228.0,
    averageCurrent: 5.0,
    minCurrent: 1.82,
    maxCurrent: 10.0,
    totalEnergy: 26.4,
    totalReadings: 86400,
    aggregationType: AggregationType.daily,
    periodKey: '2025-12-09',
  );

  static HistoryRecord sampleWeeklyRecord() => HistoryRecord(
    timestamp: DateTime(2025, 12, 8),
    deviceName: 'Living Room Hub',
    hubName: 'HUB001',
    averagePower: 1050.0,
    minPower: 350.0,
    maxPower: 2300.0,
    averageVoltage: 220.5,
    minVoltage: 210.0,
    maxVoltage: 230.0,
    averageCurrent: 4.77,
    minCurrent: 1.59,
    maxCurrent: 10.45,
    totalEnergy: 176.4,
    totalReadings: 604800,
    aggregationType: AggregationType.weekly,
    periodKey: '2025-W50',
  );

  static HistoryRecord sampleMonthlyRecord() => HistoryRecord(
    timestamp: DateTime(2025, 12, 1),
    deviceName: 'Living Room Hub',
    hubName: 'HUB001',
    averagePower: 1000.0,
    minPower: 300.0,
    maxPower: 2500.0,
    averageVoltage: 220.0,
    minVoltage: 208.0,
    maxVoltage: 232.0,
    averageCurrent: 4.55,
    minCurrent: 1.36,
    maxCurrent: 11.36,
    totalEnergy: 744.0,
    totalReadings: 2678400,
    aggregationType: AggregationType.monthly,
    periodKey: '2025-12',
  );

  // ==================== HUB & DEVICE FIXTURES ====================

  static Map<String, dynamic> sampleHubData() => {
    'serialNumber': 'HUB001',
    'nickname': 'Living Room Hub',
    'isActive': true,
    'isPrimary': true,
    'addedAt': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
  };

  static List<Map<String, dynamic>> multipleHubsData() => [
    {
      'serialNumber': 'HUB001',
      'nickname': 'Living Room Hub',
      'isActive': true,
      'isPrimary': true,
    },
    {
      'serialNumber': 'HUB002',
      'nickname': 'Bedroom Hub',
      'isActive': true,
      'isPrimary': false,
    },
    {
      'serialNumber': 'HUB003',
      'nickname': 'Kitchen Hub',
      'isActive': false,
      'isPrimary': false,
    },
  ];

  // ==================== PRICE & BILLING FIXTURES ====================

  static Map<String, dynamic> samplePriceData() => {
    'pricePerKWH': 0.50,
    'currency': 'PHP',
    'lastUpdated': DateTime.now().toIso8601String(),
  };

  static List<Map<String, dynamic>> priceHistoryData() => [
    {
      'price': 0.50,
      'previousPrice': 0.45,
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'note': 'Monthly rate adjustment',
    },
    {
      'price': 0.45,
      'previousPrice': 0.42,
      'timestamp': DateTime.now().subtract(const Duration(days: 30)),
      'note': 'Seasonal rate change',
    },
    {
      'price': 0.42,
      'previousPrice': 0.40,
      'timestamp': DateTime.now().subtract(const Duration(days: 60)),
      'note': 'Initial setup',
    },
  ];

  static Map<String, dynamic> dueDateData() => {
    'dueDate': DateTime(2025, 12, 25).toIso8601String(),
    'billingCycle': 'monthly',
  };

  // ==================== NOTIFICATION FIXTURES ====================

  static List<Map<String, dynamic>> notificationData() => [
    {
      'id': 'notif_001',
      'type': 'hub_added',
      'message': 'New hub "Living Room Hub" was added',
      'hubSerialNumber': 'HUB001',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'isRead': false,
    },
    {
      'id': 'notif_002',
      'type': 'price_updated',
      'message': 'Electricity price updated to ₱0.50/kWh',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'isRead': true,
    },
    {
      'id': 'notif_003',
      'type': 'high_usage_alert',
      'message': 'High energy usage detected: 5.5 kWh in the last hour',
      'hubSerialNumber': 'HUB001',
      'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
      'isRead': false,
    },
  ];

  // ==================== CHART DATA FIXTURES ====================

  static List<Map<String, dynamic>> chartDataPoints() {
    final now = DateTime.now();
    final points = <Map<String, dynamic>>[];

    for (int i = 0; i < 60; i++) {
      points.add({
        'timestamp': now.subtract(Duration(seconds: 60 - i)),
        'power': 1000.0 + (i % 10) * 50.0,
        'voltage': 220.0 + (i % 5) * 0.5,
        'current': 4.5 + (i % 8) * 0.2,
        'energy': 100.0 + (i * 0.01),
      });
    }

    return points;
  }

  // ==================== HELPER METHODS ====================

  /// Creates a date range for testing
  static List<DateTime> dateRange(DateTime start, DateTime end) {
    final dates = <DateTime>[];
    DateTime current = start;

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Creates hourly timestamps for a given day
  static List<DateTime> hourlyTimestamps(DateTime day) {
    final timestamps = <DateTime>[];

    for (int hour = 0; hour < 24; hour++) {
      timestamps.add(DateTime(day.year, day.month, day.day, hour));
    }

    return timestamps;
  }

  /// Calculates expected usage from readings
  static double calculateExpectedUsage(double previousReading, double currentReading) {
    return currentReading - previousReading;
  }

  /// Calculates expected cost
  static double calculateExpectedCost(double kWh, double pricePerKWh) {
    return kWh * pricePerKWh;
  }
}
