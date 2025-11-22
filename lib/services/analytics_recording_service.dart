import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';

class AnalyticsRecordingService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Map<String, Timer> _recordingTimers = {};
  final Map<String, Timer> _cleanupTimers = {};
  final Map<String, StreamSubscription> _plugStreamSubscriptions = {};

  // Cache the latest plug data from the stream (instead of fetching every second)
  final Map<String, Map<String, dynamic>> _latestPlugData = {};

  // Track paused state for each hub
  final Map<String, bool> _pausedHubs = {};

  // Start recording per-second data for a hub
  void startRecording(String hubSerialNumber) {
    if (_recordingTimers.containsKey(hubSerialNumber)) {
      debugPrint('[AnalyticsRecording] ⚠️ Already recording for hub: $hubSerialNumber');
      return;
    }

    debugPrint('[AnalyticsRecording] 🚀 Starting per-second recording for hub: $hubSerialNumber');

    // Delete all existing per_second data before starting
    _deleteAllPerSecondData(hubSerialNumber);

    // Listen to ALL hub data (including plugs) once instead of fetching every second
    final hubRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber');
    _plugStreamSubscriptions[hubSerialNumber] = hubRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        // Convert to Map<String, dynamic> properly
        final value = event.snapshot.value;
        if (value is Map) {
          _latestPlugData[hubSerialNumber] = Map<String, dynamic>.from(value.map((k, v) => MapEntry(k.toString(), v)));
          debugPrint('[AnalyticsRecording] 🔄 Cached hub data for hub: $hubSerialNumber');
        }
      }
    });

    // Record immediately if we have cached data, then every second
    _recordSnapshot(hubSerialNumber);

    _recordingTimers[hubSerialNumber] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        debugPrint('[AnalyticsRecording] ⏰ Timer tick for hub: $hubSerialNumber');
        _recordSnapshot(hubSerialNumber);
      },
    );

    // Cleanup old data every 5 seconds
    _cleanupTimers[hubSerialNumber] = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _cleanupOldData(hubSerialNumber),
    );

    debugPrint('[AnalyticsRecording] ✅ Timers initialized for hub: $hubSerialNumber');
  }

  // Stop recording for a hub
  void stopRecording(String hubSerialNumber) {
    debugPrint('[AnalyticsRecording] Stopping recording for hub: $hubSerialNumber');

    _recordingTimers[hubSerialNumber]?.cancel();
    _recordingTimers.remove(hubSerialNumber);

    _cleanupTimers[hubSerialNumber]?.cancel();
    _cleanupTimers.remove(hubSerialNumber);

    _plugStreamSubscriptions[hubSerialNumber]?.cancel();
    _plugStreamSubscriptions.remove(hubSerialNumber);

    _latestPlugData.remove(hubSerialNumber);
    _pausedHubs.remove(hubSerialNumber);

    // Final cleanup when stopping
    _cleanupOldData(hubSerialNumber);
  }

  // Stop all recordings
  void stopAllRecordings() {
    debugPrint('[AnalyticsRecording] Stopping all recordings');

    for (final timer in _recordingTimers.values) {
      timer.cancel();
    }
    _recordingTimers.clear();

    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _cleanupTimers.clear();
  }

  // Delete all existing per_second data
  Future<void> _deleteAllPerSecondData(String hubSerialNumber) async {
    try {
      final perSecondRef = _dbRef.child(
        '$rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second/data',
      );
      await perSecondRef.remove();
      debugPrint('[AnalyticsRecording] 🗑️ Deleted all existing per_second data for hub: $hubSerialNumber');
    } catch (e) {
      debugPrint('[AnalyticsRecording] Error deleting per_second data for $hubSerialNumber: $e');
    }
  }

  // Pause recording for a specific hub (stops writing to database)
  void pauseRecording(String hubSerialNumber) {
    if (!_recordingTimers.containsKey(hubSerialNumber)) {
      debugPrint('[AnalyticsRecording] ⚠️ No active recording for hub: $hubSerialNumber');
      return;
    }

    _pausedHubs[hubSerialNumber] = true;
    debugPrint('[AnalyticsRecording] ⏸️ Paused recording for hub: $hubSerialNumber');
  }

  // Resume recording for a specific hub
  void resumeRecording(String hubSerialNumber) {
    if (!_recordingTimers.containsKey(hubSerialNumber)) {
      debugPrint('[AnalyticsRecording] ⚠️ No active recording for hub: $hubSerialNumber');
      return;
    }

    _pausedHubs[hubSerialNumber] = false;
    debugPrint('[AnalyticsRecording] ▶️ Resumed recording for hub: $hubSerialNumber');
  }

  // Check if recording is paused for a hub
  bool isRecordingPaused(String hubSerialNumber) {
    return _pausedHubs[hubSerialNumber] ?? false;
  }

  // Record a snapshot of current sensor data
  Future<void> _recordSnapshot(String hubSerialNumber) async {
    // Skip recording if paused
    if (isRecordingPaused(hubSerialNumber)) {
      debugPrint('[AnalyticsRecording] ⏸️ Skipping snapshot for paused hub: $hubSerialNumber');
      return;
    }

    try {
      final hubRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber');

      // EFFICIENCY: Use cached hub data from the stream instead of fetching
      final hubData = _latestPlugData[hubSerialNumber];

      if (hubData == null || hubData.isEmpty) {
        debugPrint('[AnalyticsRecording] ⚠️ No cached hub data for hub: $hubSerialNumber (waiting for stream)');
        return;
      }

      // Extract plugs data from the hub data
      final plugsData = hubData['plugs'];
      if (plugsData == null || plugsData is! Map) {
        debugPrint('[AnalyticsRecording] ⚠️ No plugs data in hub: $hubSerialNumber');
        return;
      }

      debugPrint('[AnalyticsRecording] 📊 Using cached data from ${plugsData.keys.length} plugs for hub: $hubSerialNumber');

      // Aggregate all plug data
      double totalPower = 0.0;
      double totalVoltage = 0.0;
      double totalCurrent = 0.0;
      double totalEnergy = 0.0;
      int plugCount = 0;

      plugsData.forEach((plugId, plugData) {
        if (plugData is Map) {
          // Sensor data is nested inside 'data' field
          final data = plugData['data'];
          if (data is Map) {
            totalPower += (data['power'] as num? ?? 0.0).toDouble();
            totalVoltage += (data['voltage'] as num? ?? 0.0).toDouble();
            totalCurrent += (data['current'] as num? ?? 0.0).toDouble();
            totalEnergy += (data['energy'] as num? ?? 0.0).toDouble();
            plugCount++;
          }
        }
      });

      // Average voltage (not sum)
      if (plugCount > 0) {
        totalVoltage = totalVoltage / plugCount;
      }

      // Create record with timestamp as key (milliseconds since epoch for Firebase compatibility)
      final timestamp = DateTime.now();
      final timestampKey = timestamp.millisecondsSinceEpoch.toString();

      final record = {
        'timestamp': timestamp.millisecondsSinceEpoch,
        'total_power': totalPower,
        'total_voltage': totalVoltage,
        'total_current': totalCurrent,
        'total_energy': totalEnergy,
      };

      // Write to per_second/data/ with timestamp as key
      final path = 'aggregations/per_second/data/$timestampKey';
      await hubRef.child(path).set(record);

      debugPrint(
        '[AnalyticsRecording] ✅ Recorded to $path: hub=$hubSerialNumber, '
        'power=${totalPower.toStringAsFixed(2)}W, voltage=${totalVoltage.toStringAsFixed(2)}V, '
        'current=${totalCurrent.toStringAsFixed(2)}A, energy=${totalEnergy.toStringAsFixed(2)}kWh, '
        'timestamp=$timestampKey',
      );
    } catch (e) {
      debugPrint('[AnalyticsRecording] Error recording snapshot for $hubSerialNumber: $e');
    }
  }

  // Delete records older than 65 seconds
  Future<void> _cleanupOldData(String hubSerialNumber) async {
    try {
      final perSecondRef = _dbRef.child(
        '$rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second/data',
      );

      // Get all records
      final snapshot = await perSecondRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('[AnalyticsRecording] 🧹 No data to cleanup for hub: $hubSerialNumber');
        return;
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final cutoffTime = DateTime.now().subtract(const Duration(seconds: 65));
      final cutoffTimestamp = cutoffTime.millisecondsSinceEpoch;

      debugPrint('[AnalyticsRecording] 🧹 Cleanup check for hub: $hubSerialNumber');
      debugPrint('[AnalyticsRecording]    Total records: ${data.keys.length}');
      debugPrint('[AnalyticsRecording]    Cutoff timestamp: $cutoffTimestamp');

      int deletedCount = 0;
      final List<String> keysToDelete = [];

      // Collect keys to delete (batch deletion is more efficient)
      for (final entry in data.entries) {
        final key = entry.key as String;

        // Compare timestamps (keys are milliseconds since epoch as strings)
        try {
          final keyTimestamp = int.parse(key);
          if (keyTimestamp < cutoffTimestamp) {
            keysToDelete.add(key);
          }
        } catch (e) {
          // Skip invalid keys
          debugPrint('[AnalyticsRecording]    Skipping invalid key: $key');
        }
      }

      // Delete in batch
      if (keysToDelete.isNotEmpty) {
        debugPrint('[AnalyticsRecording]    Deleting ${keysToDelete.length} old records...');
        for (final key in keysToDelete) {
          await perSecondRef.child(key).remove();
          deletedCount++;
        }
        debugPrint(
          '[AnalyticsRecording] ✅ Cleaned up $deletedCount old records for hub: $hubSerialNumber (${data.keys.length - deletedCount} remaining)',
        );
      } else {
        debugPrint('[AnalyticsRecording]    No old records to delete (all within 65 seconds)');
      }
    } catch (e) {
      debugPrint('[AnalyticsRecording] Error cleaning up data for $hubSerialNumber: $e');
    }
  }

  void dispose() {
    stopAllRecordings();
  }
}
