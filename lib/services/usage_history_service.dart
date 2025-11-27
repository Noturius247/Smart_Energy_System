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

  /// Applies a timezone correction to a timestamp.
  ///
  /// This handles two cases:
  /// 1. If the timestamp is in UTC, it's converted to the local timezone.
  /// 2. A workaround for a specific issue where timestamps from a UTC+3 source
  ///    are incorrectly parsed as local time (e.g., in a UTC+8 environment),
  ///    causing a 5-hour discrepancy. This is corrected by adding 5 hours.
  DateTime _applyTimezoneCorrection(DateTime timestamp) {
    DateTime corrected = timestamp;
    if (corrected.isUtc) {
      corrected = corrected.toLocal();
      debugPrint('[UsageHistoryService] ✅ Converted UTC to local time: $timestamp -> $corrected');
    } else {
      // WORKAROUND: Correct for potential UTC+3 data parsed as local (UTC+8)
      final hoursDifference = DateTime.now().difference(corrected).inHours;
      if (hoursDifference > 4 && hoursDifference < 6) {
        corrected = corrected.add(const Duration(hours: 5));
        debugPrint('[UsageHistoryService] ⚠️ TIMEZONE CORRECTION: Added 5 hours (UTC+3 → UTC+8) to $timestamp');
      }
    }
    return corrected;
  }

  /// Calculate hourly usage history from aggregated readings
  ///
  /// This calculates usage for each hour by taking the difference between
  /// consecutive hourly readings (current hour - previous hour).
  ///
  /// Since meter readings are cumulative, the actual consumption is:
  /// Hourly Usage = Current Hour Reading - Previous Hour Reading
  Future<List<UsageHistoryEntry>> _calculateHourlyHistory(
    String hubSerial,
    DateTime now,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get ALL hourly aggregation data from the database (no time limit)
    // Start from a very early date to capture all historical data
    final startTime = DateTime(2020, 1, 1); // Get all data from 2020 onwards
    final data = await _realtimeDbService.getHourlyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    debugPrint('[UsageHistoryService] HOURLY: Retrieved ${data.length} total hourly data points from database');

    if (data.isEmpty) {
      debugPrint('[UsageHistoryService] HOURLY: No hourly data available');
      return entries;
    }

    // Sort by timestamp ASCENDING (oldest first) for proper calculation
    data.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate usage by taking difference between consecutive readings
    for (int i = 1; i < data.length; i++) {
      final previous = data[i - 1];
      final current = data[i];

      // Calculate hourly usage: current reading minus previous reading
      // This gives us the actual energy consumed in that hour
      final usage = (current.energy - previous.energy).abs();

      // Apply timezone correction to the timestamp
      final correctedTimestamp = _applyTimezoneCorrection(current.timestamp);

      entries.add(UsageHistoryEntry(
        timestamp: correctedTimestamp,
        interval: UsageInterval.hourly,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));

      debugPrint('[UsageHistoryService] HOURLY: ${correctedTimestamp.toString().substring(0, 16)} - '
          'Previous: ${previous.energy.toStringAsFixed(3)} kWh, '
          'Current: ${current.energy.toStringAsFixed(3)} kWh, '
          'Usage: ${usage.toStringAsFixed(3)} kWh');
    }

    // Sort by timestamp descending (newest first) for display
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Show ALL available data (no pagination limit on initial load)
    final entriesToShow = offset == 0 ? entries : entries.skip(offset).take(minRows).toList();

    debugPrint('[UsageHistoryService] HOURLY: Total entries available: ${entries.length}, showing: ${entriesToShow.length}');

    return entriesToShow;
  }

  /// Calculate daily usage history from daily aggregations
  ///
  /// HIERARCHICAL CALCULATION - LEVEL 2:
  /// Daily Usage = Current Day Reading - Previous Day Reading
  ///
  /// This calculates usage for each day by taking the difference between
  /// consecutive daily readings (current day - previous day).
  Future<List<UsageHistoryEntry>> _calculateDailyHistory(
    String hubSerial,
    DateTime now,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get ALL daily aggregation data from the database (no time limit)
    // Start from a very early date to capture all historical data
    final startTime = DateTime(2020, 1, 1); // Get all data from 2020 onwards
    final dailyData = await _realtimeDbService.getDailyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    debugPrint('[UsageHistoryService] DAILY: Retrieved ${dailyData.length} total daily aggregations from database');

    if (dailyData.isEmpty) {
      debugPrint('[UsageHistoryService] DAILY: No daily data available');
      return entries;
    }

    // Sort by timestamp ASCENDING (oldest first) for proper calculation
    dailyData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate usage by taking difference between consecutive daily readings
    for (int i = 1; i < dailyData.length; i++) {
      final previous = dailyData[i - 1];
      final current = dailyData[i];

      // Calculate daily usage: current reading minus previous reading
      // This gives us the actual energy consumed in that day
      final usage = (current.energy - previous.energy).abs();

      // Apply timezone correction to the timestamp
      final correctedTimestamp = _applyTimezoneCorrection(current.timestamp);

      entries.add(UsageHistoryEntry(
        timestamp: correctedTimestamp,
        interval: UsageInterval.daily,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));

      debugPrint('[UsageHistoryService] DAILY: ${correctedTimestamp.toString().substring(0, 10)} - '
          'Previous: ${previous.energy.toStringAsFixed(3)} kWh, '
          'Current: ${current.energy.toStringAsFixed(3)} kWh, '
          'Usage: ${usage.toStringAsFixed(3)} kWh');
    }

    // Sort by timestamp descending (newest first) for display
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Show ALL available data (no pagination limit on initial load)
    final entriesToShow = offset == 0 ? entries : entries.skip(offset).take(minRows).toList();

    debugPrint('[UsageHistoryService] DAILY: Total entries available: ${entries.length}, showing: ${entriesToShow.length}');
    return entriesToShow;
  }

  /// Calculate weekly usage history from weekly aggregations
  ///
  /// HIERARCHICAL CALCULATION - LEVEL 3:
  /// Weekly Usage = Current Week Reading - Previous Week Reading
  ///
  /// This calculates usage for each week by taking the difference between
  /// consecutive weekly readings (current week - previous week).
  Future<List<UsageHistoryEntry>> _calculateWeeklyHistory(
    String hubSerial,
    DateTime now,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get ALL weekly aggregation data from the database (no time limit)
    // Start from a very early date to capture all historical data
    final startTime = DateTime(2020, 1, 1); // Get all data from 2020 onwards
    final weeklyData = await _realtimeDbService.getWeeklyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    debugPrint('[UsageHistoryService] WEEKLY: Retrieved ${weeklyData.length} total weekly aggregations from database');

    if (weeklyData.isEmpty) {
      debugPrint('[UsageHistoryService] WEEKLY: No weekly data available');
      return entries;
    }

    // Sort by timestamp ASCENDING (oldest first) for proper calculation
    weeklyData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate usage by taking difference between consecutive weekly readings
    for (int i = 1; i < weeklyData.length; i++) {
      final previous = weeklyData[i - 1];
      final current = weeklyData[i];

      // Calculate weekly usage: current reading minus previous reading
      // This gives us the actual energy consumed in that week
      final usage = (current.energy - previous.energy).abs();

      // Apply timezone correction to the timestamp
      final correctedTimestamp = _applyTimezoneCorrection(current.timestamp);

      entries.add(UsageHistoryEntry(
        timestamp: correctedTimestamp,
        interval: UsageInterval.weekly,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));

      debugPrint('[UsageHistoryService] WEEKLY: ${correctedTimestamp.toString().substring(0, 10)} - '
          'Previous: ${previous.energy.toStringAsFixed(3)} kWh, '
          'Current: ${current.energy.toStringAsFixed(3)} kWh, '
          'Usage: ${usage.toStringAsFixed(3)} kWh');
    }

    // Sort by timestamp descending (newest first) for display
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Show ALL available data (no pagination limit on initial load)
    final entriesToShow = offset == 0 ? entries : entries.skip(offset).take(minRows).toList();

    debugPrint('[UsageHistoryService] WEEKLY: Total entries available: ${entries.length}, showing: ${entriesToShow.length}');
    return entriesToShow;
  }

  /// Calculate monthly usage history from monthly aggregations
  ///
  /// HIERARCHICAL CALCULATION - LEVEL 4:
  /// Monthly Usage = Current Month Reading - Previous Month Reading
  ///
  /// This calculates usage for each month by taking the difference between
  /// consecutive monthly readings (current month - previous month).
  Future<List<UsageHistoryEntry>> _calculateMonthlyHistory(
    String hubSerial,
    DateTime now,
    DateTime? customDueDate,
    int minRows,
    int offset,
  ) async {
    final List<UsageHistoryEntry> entries = [];

    // Get ALL monthly aggregation data from the database (no time limit)
    // Start from a very early date to capture all historical data
    final startTime = DateTime(2020, 1, 1); // Get all data from 2020 onwards
    final monthlyData = await _realtimeDbService.getMonthlyAggregationData(
      hubSerial,
      startTime,
      now,
    );

    debugPrint('[UsageHistoryService] MONTHLY: Retrieved ${monthlyData.length} total monthly aggregations from database');

    if (monthlyData.isEmpty) {
      debugPrint('[UsageHistoryService] MONTHLY: No monthly data available');
      return entries;
    }

    // Sort by timestamp ASCENDING (oldest first) for proper calculation
    monthlyData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate usage by taking difference between consecutive monthly readings
    for (int i = 1; i < monthlyData.length; i++) {
      final previous = monthlyData[i - 1];
      final current = monthlyData[i];

      // Calculate monthly usage: current reading minus previous reading
      // This gives us the actual energy consumed in that month
      final usage = (current.energy - previous.energy).abs();

      // Apply timezone correction to the timestamp
      final correctedTimestamp = _applyTimezoneCorrection(current.timestamp);

      entries.add(UsageHistoryEntry(
        timestamp: correctedTimestamp,
        interval: UsageInterval.monthly,
        previousReading: previous.energy,
        currentReading: current.energy,
        usage: usage,
      ));

      debugPrint('[UsageHistoryService] MONTHLY: ${correctedTimestamp.toString().substring(0, 10)} - '
          'Previous: ${previous.energy.toStringAsFixed(3)} kWh, '
          'Current: ${current.energy.toStringAsFixed(3)} kWh, '
          'Usage: ${usage.toStringAsFixed(3)} kWh');
    }

    // Sort by timestamp descending (newest first) for display
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Show ALL available data (no pagination limit on initial load)
    final entriesToShow = offset == 0 ? entries : entries.skip(offset).take(minRows).toList();

    debugPrint('[UsageHistoryService] MONTHLY: Total entries available: ${entries.length}, showing: ${entriesToShow.length}');
    return entriesToShow;
  }

}
