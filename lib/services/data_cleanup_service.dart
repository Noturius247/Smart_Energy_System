import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class DataCleanupService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Timer? _cleanupTimer;

  // Cleanup interval: every 5 minutes
  static const Duration _cleanupInterval = Duration(minutes: 5);

  // Keep only last 2 minutes of per-second data
  static const Duration _dataRetentionPeriod = Duration(minutes: 2);

  void startCleanupService() {
    if (_cleanupTimer != null && _cleanupTimer!.isActive) {
      debugPrint('[DataCleanupService] Cleanup service already running');
      return;
    }

    debugPrint('[DataCleanupService] Starting automatic cleanup service');

    // Run cleanup immediately on start
    _performCleanup();

    // Schedule periodic cleanup
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _performCleanup();
    });
  }

  void stopCleanupService() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    debugPrint('[DataCleanupService] Cleanup service stopped');
  }

  Future<void> _performCleanup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[DataCleanupService] User not authenticated, skipping cleanup');
      return;
    }

    try {
      debugPrint('[DataCleanupService] Starting cleanup cycle...');

      // Calculate cutoff time (keep only last 2 minutes)
      final cutoffTime = DateTime.now().subtract(_dataRetentionPeriod);
      final cutoffTimeStr = cutoffTime.toIso8601String();

      // Get all hubs owned by current user
      final hubSnapshot = await _dbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) {
        debugPrint('[DataCleanupService] No hubs found for user');
        return;
      }

      final hubsData = hubSnapshot.value as Map<dynamic, dynamic>;
      int totalRecordsDeleted = 0;

      for (final hubEntry in hubsData.entries) {
        final hubSerialNumber = hubEntry.key as String;
        final recordsDeleted = await _cleanupHubPerSecondData(
          hubSerialNumber,
          cutoffTimeStr,
        );
        totalRecordsDeleted += recordsDeleted;
      }

      debugPrint(
        '[DataCleanupService] Cleanup cycle completed. '
        'Total records deleted: $totalRecordsDeleted',
      );
    } catch (e) {
      debugPrint('[DataCleanupService] Error during cleanup: $e');
    }
  }

  Future<int> _cleanupHubPerSecondData(
    String hubSerialNumber,
    String cutoffTimeStr,
  ) async {
    try {
      final perSecondRef = _dbRef.child(
        '$rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second',
      );

      // Query all records older than cutoff time
      final oldDataSnapshot = await perSecondRef
          .orderByKey()
          .endBefore(cutoffTimeStr)
          .get();

      if (!oldDataSnapshot.exists || oldDataSnapshot.value == null) {
        // No old data to delete
        return 0;
      }

      final oldData = oldDataSnapshot.value as Map<dynamic, dynamic>;
      final recordCount = oldData.length;

      // Delete each old record
      for (final key in oldData.keys) {
        await perSecondRef.child(key as String).remove();
      }

      debugPrint(
        '[DataCleanupService] Hub $hubSerialNumber: '
        'Deleted $recordCount old per-second records',
      );

      return recordCount;
    } catch (e) {
      debugPrint(
        '[DataCleanupService] Error cleaning hub $hubSerialNumber: $e',
      );
      return 0;
    }
  }

  void dispose() {
    stopCleanupService();
  }
}
