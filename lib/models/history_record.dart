import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AggregationType {
  hourly,
  daily,
  weekly,
  monthly,
}

class HistoryRecord {
  final DateTime timestamp;
  final String deviceName;
  final String hubName;
  final double averagePower;
  final double minPower;
  final double maxPower;
  final double averageVoltage;
  final double minVoltage;
  final double maxVoltage;
  final double averageCurrent;
  final double minCurrent;
  final double maxCurrent;
  final double totalEnergy;
  final int totalReadings;
  final AggregationType aggregationType;
  final String periodKey;

  HistoryRecord({
    required this.timestamp,
    required this.deviceName,
    required this.hubName,
    required this.averagePower,
    required this.minPower,
    required this.maxPower,
    required this.averageVoltage,
    required this.minVoltage,
    required this.maxVoltage,
    required this.averageCurrent,
    required this.minCurrent,
    required this.maxCurrent,
    required this.totalEnergy,
    required this.totalReadings,
    required this.aggregationType,
    required this.periodKey,
  });

  static DateTime parseTimestampFromKey(String key, AggregationType type) {
    try {
      switch (type) {
        case AggregationType.hourly:
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]), int.parse(parts[3]));
        case AggregationType.daily:
          return DateTime.parse(key);
        case AggregationType.weekly:
          final parts = key.split('-W');
          final year = int.parse(parts[0]);
          final week = int.parse(parts[1]);
          return _getDateFromWeek(year, week);
        case AggregationType.monthly:
          final parts = key.split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  static DateTime _getDateFromWeek(int year, int week) {
    DateTime jan1 = DateTime(year, 1, 1);
    int daysToAdd = (week - 1) * 7;
    int dayOfWeek = jan1.weekday;
    if (dayOfWeek <= 4) {
      daysToAdd -= (dayOfWeek - 1);
    } else {
      daysToAdd += (8 - dayOfWeek);
    }
    return jan1.add(Duration(days: daysToAdd));
  }

  String getPeriodLabel() {
    switch (aggregationType) {
      case AggregationType.hourly:
        return DateFormat('MMM dd, HH:00').format(timestamp);
      case AggregationType.daily:
        return DateFormat('MMM dd').format(timestamp);
      case AggregationType.weekly:
        return periodKey.replaceAll('2025-', '');
      case AggregationType.monthly:
        return DateFormat('MMM yyyy').format(timestamp);
    }
  }
}
