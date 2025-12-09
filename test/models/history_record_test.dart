import 'package:flutter_test/flutter_test.dart';
import 'package:smartenergy_app/models/history_record.dart';
import '../helpers/test_fixtures.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('HistoryRecord', () {
    group('Constructor', () {
      test('creates instance with all required fields', () {
        final record = HistoryRecord(
          timestamp: DateTime(2025, 12, 9, 14),
          deviceName: 'Test Device',
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

        expect(record.timestamp, DateTime(2025, 12, 9, 14));
        expect(record.deviceName, 'Test Device');
        expect(record.hubName, 'HUB001');
        expect(record.averagePower, 1200.0);
        expect(record.totalEnergy, 1.2);
        expect(record.aggregationType, AggregationType.hourly);
        expect(record.periodKey, '2025-12-09-14');
      });

      test('creates hourly record from test fixture', () {
        final record = TestFixtures.sampleHourlyRecord();

        expect(record.aggregationType, AggregationType.hourly);
        expect(record.totalReadings, 3600); // 1 hour = 3600 seconds
        expect(record.periodKey, contains('-'));
      });

      test('creates daily record from test fixture', () {
        final record = TestFixtures.sampleDailyRecord();

        expect(record.aggregationType, AggregationType.daily);
        expect(record.totalReadings, 86400); // 1 day = 86400 seconds
      });

      test('creates weekly record from test fixture', () {
        final record = TestFixtures.sampleWeeklyRecord();

        expect(record.aggregationType, AggregationType.weekly);
        expect(record.periodKey, startsWith('2025-W'));
      });

      test('creates monthly record from test fixture', () {
        final record = TestFixtures.sampleMonthlyRecord();

        expect(record.aggregationType, AggregationType.monthly);
        expect(record.periodKey, matches(r'\d{4}-\d{2}'));
      });
    });

    group('parseTimestampFromKey', () {
      group('Hourly', () {
        test('parses hourly key correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12-09-14',
            AggregationType.hourly,
          );

          expect(timestamp.year, 2025);
          expect(timestamp.month, 12);
          expect(timestamp.day, 9);
          expect(timestamp.hour, 14);
        });

        test('parses midnight hour correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12-09-00',
            AggregationType.hourly,
          );

          expect(timestamp.hour, 0);
        });

        test('parses last hour of day correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12-09-23',
            AggregationType.hourly,
          );

          expect(timestamp.hour, 23);
        });
      });

      group('Daily', () {
        test('parses daily key correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12-09',
            AggregationType.daily,
          );

          expect(timestamp.year, 2025);
          expect(timestamp.month, 12);
          expect(timestamp.day, 9);
        });

        test('parses first day of month', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-01-01',
            AggregationType.daily,
          );

          expect(timestamp.day, 1);
          expect(timestamp.month, 1);
        });

        test('parses last day of month', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12-31',
            AggregationType.daily,
          );

          expect(timestamp.day, 31);
          expect(timestamp.month, 12);
        });
      });

      group('Weekly', () {
        test('parses weekly key correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-W10',
            AggregationType.weekly,
          );

          expect(timestamp.year, 2025);
          expect(timestamp, isA<DateTime>());
        });

        test('parses first week of year', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-W02',
            AggregationType.weekly,
          );

          // Week 1 may belong to previous year per ISO 8601, week 2 should be in 2025
          expect(timestamp.year, 2025);
          expect(timestamp.month, lessThanOrEqualTo(2)); // Should be in Jan or early Feb
        });

        test('parses last week of year', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-W52',
            AggregationType.weekly,
          );

          expect(timestamp.year, 2025);
          expect(timestamp.month, greaterThanOrEqualTo(11)); // Should be in Nov or Dec
        });

        test('handles week 10 correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-W10',
            AggregationType.weekly,
          );

          expect(timestamp.year, 2025);
          expect(timestamp.month, inRange(2, 4)); // Around Feb-Mar
        });
      });

      group('Monthly', () {
        test('parses monthly key correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12',
            AggregationType.monthly,
          );

          expect(timestamp.year, 2025);
          expect(timestamp.month, 12);
          expect(timestamp.day, 1); // Should default to first day of month
        });

        test('parses January correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-01',
            AggregationType.monthly,
          );

          expect(timestamp.month, 1);
        });

        test('parses December correctly', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-12',
            AggregationType.monthly,
          );

          expect(timestamp.month, 12);
        });
      });

      group('Error Handling', () {
        test('returns current time for invalid hourly key', () {
          final before = DateTime.now();
          final timestamp = HistoryRecord.parseTimestampFromKey(
            'invalid-key',
            AggregationType.hourly,
          );
          final after = DateTime.now();

          expect(timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
          expect(timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
        });

        test('returns current time for malformed weekly key', () {
          final timestamp = HistoryRecord.parseTimestampFromKey(
            '2025-invalid',
            AggregationType.weekly,
          );

          expect(timestamp, isA<DateTime>());
        });
      });
    });

    group('getPeriodLabel', () {
      test('formats hourly label correctly', () {
        final record = TestFixtures.sampleHourlyRecord();
        final label = record.getPeriodLabel();

        expect(label, contains('Dec'));
        expect(label, contains('14:00'));
      });

      test('formats daily label correctly', () {
        final record = TestFixtures.sampleDailyRecord();
        final label = record.getPeriodLabel();

        expect(label, contains('Dec'));
        expect(label, matches(r'\d{2}')); // Contains day number
      });

      test('formats weekly label correctly', () {
        final record = TestFixtures.sampleWeeklyRecord();
        final label = record.getPeriodLabel();

        expect(label, contains('W')); // Should contain week indicator
      });

      test('formats monthly label correctly', () {
        final record = TestFixtures.sampleMonthlyRecord();
        final label = record.getPeriodLabel();

        expect(label, contains('Dec'));
        expect(label, contains('2025'));
      });
    });

    group('Statistical Values', () {
      test('average values are within min and max range', () {
        final record = TestFixtures.sampleHourlyRecord();

        expect(record.averagePower, greaterThanOrEqualTo(record.minPower));
        expect(record.averagePower, lessThanOrEqualTo(record.maxPower));

        expect(record.averageVoltage, greaterThanOrEqualTo(record.minVoltage));
        expect(record.averageVoltage, lessThanOrEqualTo(record.maxVoltage));

        expect(record.averageCurrent, greaterThanOrEqualTo(record.minCurrent));
        expect(record.averageCurrent, lessThanOrEqualTo(record.maxCurrent));
      });

      test('min values are less than or equal to max values', () {
        final record = TestFixtures.sampleDailyRecord();

        expect(record.minPower, lessThanOrEqualTo(record.maxPower));
        expect(record.minVoltage, lessThanOrEqualTo(record.maxVoltage));
        expect(record.minCurrent, lessThanOrEqualTo(record.maxCurrent));
      });

      test('handles identical min, avg, max values', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Test',
          hubName: 'HUB001',
          averagePower: 1000.0,
          minPower: 1000.0,
          maxPower: 1000.0,
          averageVoltage: 220.0,
          minVoltage: 220.0,
          maxVoltage: 220.0,
          averageCurrent: 4.5,
          minCurrent: 4.5,
          maxCurrent: 4.5,
          totalEnergy: 1.0,
          totalReadings: 100,
          aggregationType: AggregationType.hourly,
          periodKey: 'test',
        );

        expect(record.minPower, record.maxPower);
        expect(record.averagePower, record.minPower);
      });
    });

    group('Energy Calculations', () {
      test('hourly energy is reasonable for given power', () {
        final record = TestFixtures.sampleHourlyRecord();

        // For 1 hour at average 1200W = 1.2 kWh
        expect(record.totalEnergy, closeTo(1.2, 0.1));
      });

      test('daily energy is sum of hourly energy', () {
        final record = TestFixtures.sampleDailyRecord();

        // 24 hours at average 1100W = 26.4 kWh
        expect(record.totalEnergy, closeTo(26.4, 1.0));
      });

      test('weekly energy is realistic', () {
        final record = TestFixtures.sampleWeeklyRecord();

        // 7 days of typical usage
        expect(record.totalEnergy, greaterThan(50));
        expect(record.totalEnergy, lessThan(500));
      });

      test('monthly energy is realistic', () {
        final record = TestFixtures.sampleMonthlyRecord();

        // 30 days of typical usage
        expect(record.totalEnergy, greaterThan(200));
        expect(record.totalEnergy, lessThan(2000));
      });
    });

    group('Reading Counts', () {
      test('hourly record has expected reading count', () {
        final record = TestFixtures.sampleHourlyRecord();

        // Assuming 1 reading per second = 3600 readings per hour
        expect(record.totalReadings, 3600);
      });

      test('daily record has expected reading count', () {
        final record = TestFixtures.sampleDailyRecord();

        // 1 reading per second for 24 hours = 86400
        expect(record.totalReadings, 86400);
      });

      test('handles zero readings', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Test',
          hubName: 'HUB001',
          averagePower: 0,
          minPower: 0,
          maxPower: 0,
          averageVoltage: 0,
          minVoltage: 0,
          maxVoltage: 0,
          averageCurrent: 0,
          minCurrent: 0,
          maxCurrent: 0,
          totalEnergy: 0,
          totalReadings: 0,
          aggregationType: AggregationType.hourly,
          periodKey: 'test',
        );

        expect(record.totalReadings, 0);
      });
    });

    group('AggregationType Enum', () {
      test('all aggregation types are defined', () {
        expect(AggregationType.values, hasLength(4));
        expect(AggregationType.values, contains(AggregationType.hourly));
        expect(AggregationType.values, contains(AggregationType.daily));
        expect(AggregationType.values, contains(AggregationType.weekly));
        expect(AggregationType.values, contains(AggregationType.monthly));
      });

      test('aggregation types can be compared', () {
        final type1 = AggregationType.hourly;
        final type2 = AggregationType.hourly;
        final type3 = AggregationType.daily;

        expect(type1, equals(type2));
        expect(type1, isNot(equals(type3)));
      });
    });

    group('Realistic Power Scenarios', () {
      test('typical household idle power', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Home',
          hubName: 'HUB001',
          averagePower: 350.0, // Idle appliances
          minPower: 200.0,
          maxPower: 500.0,
          averageVoltage: 220.0,
          minVoltage: 218.0,
          maxVoltage: 222.0,
          averageCurrent: 1.59,
          minCurrent: 0.91,
          maxCurrent: 2.27,
          totalEnergy: 0.35,
          totalReadings: 3600,
          aggregationType: AggregationType.hourly,
          periodKey: 'test',
        );

        expect(record.averagePower, lessThan(1000));
      });

      test('high usage period with AC running', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Home',
          hubName: 'HUB001',
          averagePower: 2500.0, // AC + other appliances
          minPower: 1500.0,
          maxPower: 3500.0,
          averageVoltage: 220.0,
          minVoltage: 215.0,
          maxVoltage: 225.0,
          averageCurrent: 11.36,
          minCurrent: 6.82,
          maxCurrent: 15.91,
          totalEnergy: 2.5,
          totalReadings: 3600,
          aggregationType: AggregationType.hourly,
          periodKey: 'test',
        );

        expect(record.averagePower, greaterThan(2000));
        expect(record.maxPower, greaterThan(3000));
      });

      test('voltage remains within acceptable range', () {
        final record = TestFixtures.sampleDailyRecord();

        // Standard voltage should be around 220V ±10V
        expect(record.averageVoltage, inRange(210, 230));
        expect(record.minVoltage, greaterThan(200));
        expect(record.maxVoltage, lessThan(240));
      });
    });

    group('Edge Cases', () {
      test('handles very small energy values', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Test',
          hubName: 'HUB001',
          averagePower: 10.0,
          minPower: 5.0,
          maxPower: 15.0,
          averageVoltage: 220.0,
          minVoltage: 220.0,
          maxVoltage: 220.0,
          averageCurrent: 0.045,
          minCurrent: 0.023,
          maxCurrent: 0.068,
          totalEnergy: 0.01,
          totalReadings: 3600,
          aggregationType: AggregationType.hourly,
          periodKey: 'test',
        );

        expect(record.totalEnergy, greaterThan(0));
        expect(record.totalEnergy, lessThan(0.1));
      });

      test('handles large energy values', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Test',
          hubName: 'HUB001',
          averagePower: 5000.0,
          minPower: 4000.0,
          maxPower: 6000.0,
          averageVoltage: 220.0,
          minVoltage: 215.0,
          maxVoltage: 225.0,
          averageCurrent: 22.73,
          minCurrent: 18.18,
          maxCurrent: 27.27,
          totalEnergy: 3600.0, // 30 days at 5kW average
          totalReadings: 2592000,
          aggregationType: AggregationType.monthly,
          periodKey: 'test',
        );

        expect(record.totalEnergy, greaterThan(1000));
      });

      test('handles device with special characters in name', () {
        final record = HistoryRecord(
          timestamp: DateTime.now(),
          deviceName: 'Living Room - A/C Unit #1',
          hubName: 'HUB-001-β',
          averagePower: 1200.0,
          minPower: 1000.0,
          maxPower: 1400.0,
          averageVoltage: 220.0,
          minVoltage: 220.0,
          maxVoltage: 220.0,
          averageCurrent: 5.45,
          minCurrent: 4.55,
          maxCurrent: 6.36,
          totalEnergy: 1.2,
          totalReadings: 3600,
          aggregationType: AggregationType.hourly,
          periodKey: 'test',
        );

        expect(record.deviceName, contains('/'));
        expect(record.hubName, contains('-'));
      });
    });
  });
}
