import 'package:flutter/material.dart';

/// Utility class for handling Philippine Time (UTC+8)
/// Ensures all schedule operations use Philippine timezone regardless of device timezone
class PhilippinesTime {
  // Philippine timezone offset from UTC
  static const Duration _phOffset = Duration(hours: 8);

  /// Get current time in Philippine timezone (UTC+8)
  static DateTime now() {
    final utcNow = DateTime.now().toUtc();
    return utcNow.add(_phOffset);
  }

  /// Get current TimeOfDay in Philippine timezone
  static TimeOfDay nowTimeOfDay() {
    final phNow = now();
    return TimeOfDay(hour: phNow.hour, minute: phNow.minute);
  }

  /// Get current day of week in Philippine timezone (1=Monday, 7=Sunday)
  static int nowWeekday() {
    return now().weekday;
  }

  /// Convert device DateTime to Philippine DateTime
  static DateTime toPhilippineTime(DateTime deviceTime) {
    final utc = deviceTime.toUtc();
    return utc.add(_phOffset);
  }

  /// Create a Philippine DateTime from components
  static DateTime create({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
  }) {
    // Create UTC time first
    final utc = DateTime.utc(year, month, day, hour, minute, second);
    // Subtract offset to get the UTC time that becomes the desired PH time
    return utc.subtract(_phOffset);
  }

  /// Check if a schedule time matches current Philippine time
  static bool isScheduleTime(TimeOfDay scheduleTime) {
    final phNow = nowTimeOfDay();
    return scheduleTime.hour == phNow.hour && scheduleTime.minute == phNow.minute;
  }

  /// Check if a schedule should run today in Philippine timezone
  static bool shouldRunToday(List<int> repeatDays) {
    if (repeatDays.isEmpty) return true; // One-time schedule
    final today = nowWeekday();
    return repeatDays.contains(today);
  }

  /// Format Philippine time as string
  static String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Get timezone offset string for display
  static String getTimezoneInfo() {
    return 'Philippine Time (UTC+8)';
  }
}
