import 'package:flutter/foundation.dart';
import '../models/usage_history_entry.dart';
import '../realtime_db_service.dart';

/// Service for calculating usage history live from meter readings
/// Does NOT store any usage values - all calculations are done on-the-fly
class UsageHistoryService {
  final RealtimeDbService _realtimeDbService;

  UsageHistoryService(this._realtimeDbService);

  /// Calculate usage history for a specific hub and interval
  /// Returns at least 10 rows, more if scrolling up
  ///
  /// For monthly intervals, uses the custom due date set by the user
  Future<List<UsageHistoryEntry>> calculateUsageHistory({
    required String hubSerialNumber,
    required UsageInterval interval,
    DateTime? customDueDate, // For monthly calculations
    int minRows = 10,
    int offset = 0, // For pagination when scrolling up
  }) async {
    debugPrint('[UsageHistoryService] Calculating $interval history for hub: $hubSerialNumber, offset: $offset');

    final now = DateTime.now();
    final List<UsageHistoryEntry> entries = [];

    switch (interval) {
      case UsageInterval.hourly:
        entries.addAll(await _calculateHourlyHistory(
          hubSerialNumber,
          now,
          minRows,
          offset,
        ));
        break;

      case UsageInterval.daily:
        entries.addAll(await _calculateDailyHistory(
          hubSerialNumber,
          now,
          minRows,
          offset,
        ));
        break;

      case UsageInterval.weekly:
        entries.addAll(await _calculateWeeklyHistory(
          hubSerialNumber,
          now,
          minRows,
          offset,
        ));
        break;

      case UsageInterval.monthly:
        entries.addAll(await _calculateMonthlyHistory(
          hubSerialNumber,
          now,
          customDueDate,
          minRows,
          offset,
        ));
        break;
    }

    debugPrint('[UsageHistoryService] Generated ${entries.length} entries for $interval interval');
    return entries;
  }

  /// Calculate hourly usage history
  Future<List<UsageHistoryEntry>> _calculateHourlyHistory(
    String hubSerial,
    DateTime now,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get hourly aggregation data for the time range
    // We need minRows + offset hours of data
    final startTime = now.subtract(Duration(hours: minRows + offset));
    final data = await _realtimeDbService.getHourlyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    // Sort by timestamp descending (newest first)
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Skip the offset entries (for pagination)
    final paginatedData = data.skip(offset).take(minRows).toList();

    // Calculate usage for each hour
    for (int i = 0; i < paginatedData.length - 1; i++) {
      final current = paginatedData[i];
      final previous = paginatedData[i + 1];

      final usage = (current.energy - previous.energy).abs();

      entries.add(UsageHistoryEntry(
        timestamp: current.timestamp,
        interval: UsageInterval.hourly,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));
    }

    return entries;
  }

  /// Calculate daily usage history
  Future<List<UsageHistoryEntry>> _calculateDailyHistory(
    String hubSerial,
    DateTime now,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get daily aggregation data
    final startTime = now.subtract(Duration(days: minRows + offset));
    final data = await _realtimeDbService.getDailyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    // Sort by timestamp descending (newest first)
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Skip the offset entries (for pagination)
    final paginatedData = data.skip(offset).take(minRows).toList();

    // Calculate usage for each day
    for (int i = 0; i < paginatedData.length - 1; i++) {
      final current = paginatedData[i];
      final previous = paginatedData[i + 1];

      final usage = (current.energy - previous.energy).abs();

      entries.add(UsageHistoryEntry(
        timestamp: current.timestamp,
        interval: UsageInterval.daily,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));
    }

    return entries;
  }

  /// Calculate weekly usage history
  Future<List<UsageHistoryEntry>> _calculateWeeklyHistory(
    String hubSerial,
    DateTime now,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get weekly aggregation data
    final startTime = now.subtract(Duration(days: (minRows + offset) * 7));
    final data = await _realtimeDbService.getWeeklyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    // Sort by timestamp descending (newest first)
    data.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Skip the offset entries (for pagination)
    final paginatedData = data.skip(offset).take(minRows).toList();

    // Calculate usage for each week
    for (int i = 0; i < paginatedData.length - 1; i++) {
      final current = paginatedData[i];
      final previous = paginatedData[i + 1];

      final usage = (current.energy - previous.energy).abs();

      entries.add(UsageHistoryEntry(
        timestamp: current.timestamp,
        interval: UsageInterval.weekly,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));
    }

    return entries;
  }

  /// Calculate monthly usage history using custom due date
  ///
  /// IMPORTANT: Monthly data is calculated by aggregating DAILY readings,
  /// not from a separate monthly aggregation table.
  ///
  /// Example: If due date is set to 23rd of each month:
  /// - Nov 23 to Dec 23
  /// - Oct 23 to Nov 23
  /// - Sep 23 to Oct 23
  /// etc.
  Future<List<UsageHistoryEntry>> _calculateMonthlyHistory(
    String hubSerial,
    DateTime now,
    DateTime? customDueDate,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // If no custom due date is set, use the first day of each month
    final int dueDayOfMonth = customDueDate?.day ?? 1;

    // Calculate the billing periods based on due date
    final List<DateTime> billingPeriods = [];

    // Find the most recent due date
    DateTime currentDueDate = DateTime(now.year, now.month, dueDayOfMonth);
    if (currentDueDate.isAfter(now)) {
      // If this month's due date hasn't passed yet, go back one month
      currentDueDate = DateTime(now.year, now.month - 1, dueDayOfMonth);
    }

    // Generate billing periods going backwards
    for (int i = 0; i <= minRows + offset; i++) {
      final periodEnd = DateTime(
        currentDueDate.year,
        currentDueDate.month - i,
        dueDayOfMonth,
      );
      billingPeriods.add(periodEnd);
    }

    debugPrint('[UsageHistoryService] Monthly billing periods (${billingPeriods.length}): ${billingPeriods.map((d) => d.toString()).join(', ')}');

    // Get DAILY aggregation data for the entire range (not monthly!)
    // We'll sum up the daily readings to calculate monthly usage
    final startTime = billingPeriods.last.subtract(const Duration(days: 35)); // Extra buffer
    final dailyData = await _realtimeDbService.getDailyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    debugPrint('[UsageHistoryService] Retrieved ${dailyData.length} DAILY data points for monthly calculation');

    // Sort by timestamp
    dailyData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // For each billing period, find the readings at the start and end
    // and calculate usage
    final paginatedPeriods = billingPeriods.skip(offset).take(minRows).toList();

    for (int i = 0; i < paginatedPeriods.length - 1; i++) {
      final periodEnd = paginatedPeriods[i];
      final periodStart = paginatedPeriods[i + 1];

      // Find the closest readings to these dates from DAILY data
      final endReading = _findClosestReading(dailyData, periodEnd);
      final startReading = _findClosestReading(dailyData, periodStart);

      if (endReading != null && startReading != null) {
        final usage = (endReading.energy - startReading.energy).abs();

        debugPrint('[UsageHistoryService] Monthly period ${periodStart.toString().substring(0, 10)} to ${periodEnd.toString().substring(0, 10)}: '
            'start=${startReading.energy} kWh, end=${endReading.energy} kWh, usage=$usage kWh');

        entries.add(UsageHistoryEntry(
          timestamp: periodEnd,
          interval: UsageInterval.monthly,
          previousReading: startReading.energy,
          currentReading: endReading.energy,
          usage: usage,
        ));
      } else {
        debugPrint('[UsageHistoryService] ⚠️ Missing readings for monthly period ${periodStart.toString().substring(0, 10)} to ${periodEnd.toString().substring(0, 10)}');
        debugPrint('[UsageHistoryService]    - Start reading found: ${startReading != null}');
        debugPrint('[UsageHistoryService]    - End reading found: ${endReading != null}');
      }
    }

    return entries;
  }

  /// Find the reading closest to a specific date
  TimestampedFlSpot? _findClosestReading(List<TimestampedFlSpot> data, DateTime target) {
    if (data.isEmpty) return null;

    TimestampedFlSpot? closest;
    Duration? smallestDiff;

    for (final reading in data) {
      final diff = (reading.timestamp.difference(target)).abs();
      if (smallestDiff == null || diff < smallestDiff) {
        smallestDiff = diff;
        closest = reading;
      }
    }

    // Only return if the closest reading is within a reasonable time window
    // For monthly data, we accept readings within 3 days of the target
    if (smallestDiff != null && smallestDiff.inDays <= 3) {
      return closest;
    }

    return null;
  }
}
