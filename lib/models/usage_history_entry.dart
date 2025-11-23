import 'package:intl/intl.dart';

/// Represents a single row in the usage history table
/// Calculated live from readings stored in the database
class UsageHistoryEntry {
  final DateTime timestamp;
  final UsageInterval interval;
  final double previousReading;
  final double currentReading;
  final double usage;

  UsageHistoryEntry({
    required this.timestamp,
    required this.interval,
    required this.previousReading,
    required this.currentReading,
    required this.usage,
  });

  /// Formats the timestamp based on the interval type
  String getFormattedTimestamp() {
    switch (interval) {
      case UsageInterval.hourly:
        return DateFormat('MMM d, yyyy HH:00').format(timestamp);
      case UsageInterval.daily:
        return DateFormat('MMM d, yyyy').format(timestamp);
      case UsageInterval.weekly:
        return DateFormat('MMM d, yyyy').format(timestamp);
      case UsageInterval.monthly:
        return DateFormat('MMM yyyy').format(timestamp);
    }
  }

  /// Gets the interval display text
  String getIntervalText() {
    switch (interval) {
      case UsageInterval.hourly:
        return 'Hourly';
      case UsageInterval.daily:
        return 'Daily';
      case UsageInterval.weekly:
        return 'Weekly';
      case UsageInterval.monthly:
        return 'Monthly';
    }
  }
}

/// Enum for the different time intervals
enum UsageInterval {
  hourly,
  daily,
  weekly,
  monthly,
}
