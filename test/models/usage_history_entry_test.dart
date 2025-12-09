import 'package:flutter_test/flutter_test.dart';
import 'package:smartenergy_app/models/usage_history_entry.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('UsageHistoryEntry', () {
    group('Constructor', () {
      test('creates instance with all required fields', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 9, 14),
          interval: UsageInterval.hourly,
          previousReading: 100.0,
          currentReading: 102.5,
          usage: 2.5,
        );

        expect(entry.timestamp, DateTime(2025, 12, 9, 14));
        expect(entry.interval, UsageInterval.hourly);
        expect(entry.previousReading, 100.0);
        expect(entry.currentReading, 102.5);
        expect(entry.usage, 2.5);
      });

      test('creates hourly entry from test fixture', () {
        final entry = TestFixtures.sampleHourlyEntry();

        expect(entry.interval, UsageInterval.hourly);
        expect(entry.usage, 2.5);
        expect(entry.currentReading, greaterThan(entry.previousReading));
      });

      test('creates daily entry from test fixture', () {
        final entry = TestFixtures.sampleDailyEntry();

        expect(entry.interval, UsageInterval.daily);
        expect(entry.usage, 24.0);
      });

      test('creates weekly entry from test fixture', () {
        final entry = TestFixtures.sampleWeeklyEntry();

        expect(entry.interval, UsageInterval.weekly);
        expect(entry.usage, 168.0);
      });

      test('creates monthly entry from test fixture', () {
        final entry = TestFixtures.sampleMonthlyEntry();

        expect(entry.interval, UsageInterval.monthly);
        expect(entry.usage, 720.0);
      });

      test('handles zero usage correctly', () {
        final entry = TestFixtures.zeroUsageEntry();

        expect(entry.usage, 0.0);
        expect(entry.previousReading, entry.currentReading);
      });
    });

    group('getFormattedTimestamp', () {
      test('formats hourly timestamp correctly', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 9, 14, 30),
          interval: UsageInterval.hourly,
          previousReading: 100.0,
          currentReading: 102.5,
          usage: 2.5,
        );

        final formatted = entry.getFormattedTimestamp();
        expect(formatted, contains('Dec 9, 2025'));
        expect(formatted, contains('14:00'));
      });

      test('formats daily timestamp correctly', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 9),
          interval: UsageInterval.daily,
          previousReading: 100.0,
          currentReading: 124.0,
          usage: 24.0,
        );

        final formatted = entry.getFormattedTimestamp();
        expect(formatted, contains('Dec 9, 2025'));
        expect(formatted, isNot(contains(':')), reason: 'Daily format should not include time');
      });

      test('formats weekly timestamp correctly', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 8),
          interval: UsageInterval.weekly,
          previousReading: 100.0,
          currentReading: 268.0,
          usage: 168.0,
        );

        final formatted = entry.getFormattedTimestamp();
        expect(formatted, contains('Dec 8, 2025'));
      });

      test('formats monthly timestamp correctly', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 1),
          interval: UsageInterval.monthly,
          previousReading: 100.0,
          currentReading: 820.0,
          usage: 720.0,
        );

        final formatted = entry.getFormattedTimestamp();
        expect(formatted, contains('Dec 2025'));
        expect(formatted, isNot(contains('1')), reason: 'Monthly format should not include day');
      });

      test('handles different months correctly', () {
        final months = [
          DateTime(2025, 1, 15),
          DateTime(2025, 6, 15),
          DateTime(2025, 12, 15),
        ];

        for (final date in months) {
          final entry = UsageHistoryEntry(
            timestamp: date,
            interval: UsageInterval.monthly,
            previousReading: 100.0,
            currentReading: 200.0,
            usage: 100.0,
          );

          final formatted = entry.getFormattedTimestamp();
          expect(formatted, isNotEmpty);
          expect(formatted, contains('2025'));
        }
      });
    });

    group('getIntervalText', () {
      test('returns correct text for hourly interval', () {
        final entry = TestFixtures.sampleHourlyEntry();
        expect(entry.getIntervalText(), 'Hourly');
      });

      test('returns correct text for daily interval', () {
        final entry = TestFixtures.sampleDailyEntry();
        expect(entry.getIntervalText(), 'Daily');
      });

      test('returns correct text for weekly interval', () {
        final entry = TestFixtures.sampleWeeklyEntry();
        expect(entry.getIntervalText(), 'Weekly');
      });

      test('returns correct text for monthly interval', () {
        final entry = TestFixtures.sampleMonthlyEntry();
        expect(entry.getIntervalText(), 'Monthly');
      });
    });

    group('Usage Calculations', () {
      test('usage equals difference between current and previous reading', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime.now(),
          interval: UsageInterval.hourly,
          previousReading: 150.5,
          currentReading: 175.8,
          usage: 25.3,
        );

        expect(entry.usage, closeTo(25.3, 0.001));
        expect(entry.usage, closeTo(entry.currentReading - entry.previousReading, 0.001));
      });

      test('handles large usage values', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime.now(),
          interval: UsageInterval.monthly,
          previousReading: 1000.0,
          currentReading: 2500.0,
          usage: 1500.0,
        );

        expect(entry.usage, 1500.0);
      });

      test('handles small fractional usage values', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime.now(),
          interval: UsageInterval.hourly,
          previousReading: 100.123,
          currentReading: 100.456,
          usage: 0.333,
        );

        expect(entry.usage, closeTo(0.333, 0.001));
      });

      test('zero usage when readings are identical', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime.now(),
          interval: UsageInterval.hourly,
          previousReading: 100.0,
          currentReading: 100.0,
          usage: 0.0,
        );

        expect(entry.usage, 0.0);
        expect(entry.previousReading, entry.currentReading);
      });
    });

    group('Edge Cases', () {
      test('handles midnight timestamp for daily interval', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 9, 0, 0, 0),
          interval: UsageInterval.daily,
          previousReading: 100.0,
          currentReading: 124.0,
          usage: 24.0,
        );

        expect(entry.timestamp.hour, 0);
        expect(entry.timestamp.minute, 0);
        final formatted = entry.getFormattedTimestamp();
        expect(formatted, isNotEmpty);
      });

      test('handles first day of month for monthly interval', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 1, 1),
          interval: UsageInterval.monthly,
          previousReading: 0.0,
          currentReading: 500.0,
          usage: 500.0,
        );

        expect(entry.timestamp.day, 1);
        expect(entry.usage, 500.0);
      });

      test('handles leap year dates', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2024, 2, 29), // Leap year
          interval: UsageInterval.daily,
          previousReading: 100.0,
          currentReading: 125.0,
          usage: 25.0,
        );

        expect(entry.timestamp.month, 2);
        expect(entry.timestamp.day, 29);
      });

      test('handles year boundary', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2024, 12, 31, 23),
          interval: UsageInterval.hourly,
          previousReading: 100.0,
          currentReading: 103.0,
          usage: 3.0,
        );

        expect(entry.timestamp.year, 2024);
        expect(entry.timestamp.month, 12);
        expect(entry.timestamp.day, 31);
      });
    });

    group('UsageInterval Enum', () {
      test('all interval types are defined', () {
        expect(UsageInterval.values, hasLength(4));
        expect(UsageInterval.values, contains(UsageInterval.hourly));
        expect(UsageInterval.values, contains(UsageInterval.daily));
        expect(UsageInterval.values, contains(UsageInterval.weekly));
        expect(UsageInterval.values, contains(UsageInterval.monthly));
      });

      test('interval enum can be compared', () {
        final interval1 = UsageInterval.hourly;
        final interval2 = UsageInterval.hourly;
        final interval3 = UsageInterval.daily;

        expect(interval1, equals(interval2));
        expect(interval1, isNot(equals(interval3)));
      });
    });

    group('Realistic Usage Scenarios', () {
      test('typical hourly usage for residential home', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 9, 14),
          interval: UsageInterval.hourly,
          previousReading: 5432.1,
          currentReading: 5434.8,
          usage: 2.7,
        );

        expect(entry.usage, greaterThan(0));
        expect(entry.usage, lessThan(10)); // Typical hourly usage < 10 kWh
      });

      test('typical daily usage for residential home', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 9),
          interval: UsageInterval.daily,
          previousReading: 5400.0,
          currentReading: 5430.0,
          usage: 30.0,
        );

        expect(entry.usage, greaterThan(10));
        expect(entry.usage, lessThan(100)); // Typical daily usage 10-100 kWh
      });

      test('typical monthly usage for residential home', () {
        final entry = UsageHistoryEntry(
          timestamp: DateTime(2025, 12, 1),
          interval: UsageInterval.monthly,
          previousReading: 5000.0,
          currentReading: 5750.0,
          usage: 750.0,
        );

        expect(entry.usage, greaterThan(300));
        expect(entry.usage, lessThan(2000)); // Typical monthly usage 300-2000 kWh
      });
    });
  });
}
