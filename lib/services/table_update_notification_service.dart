import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import 'notification_service.dart';

/// Service to monitor database tables and send notifications on updates
class TableUpdateNotificationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final NotificationService _notificationService = NotificationService();

  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, int> _lastNotificationTime = {};

  // Debounce time to prevent notification spam (in milliseconds)
  static const int _debounceMs = 5000; // 5 seconds

  /// Start monitoring analytics table updates for a hub
  void startMonitoringAnalytics(String hubSerialNumber) {
    final key = 'analytics_$hubSerialNumber';

    if (_subscriptions.containsKey(key)) {
      debugPrint('[TableUpdateNotification] Already monitoring analytics for: $hubSerialNumber');
      return;
    }

    debugPrint('[TableUpdateNotification] Starting analytics monitoring for: $hubSerialNumber');

    // Monitor hourly aggregations (most common for analytics table)
    final hourlyRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/hourly');

    _subscriptions[key] = hourlyRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        _handleAnalyticsUpdate(hubSerialNumber);
      }
    });
  }

  /// Start monitoring daily aggregations for history table
  void startMonitoringHistory(String hubSerialNumber) {
    final key = 'history_$hubSerialNumber';

    if (_subscriptions.containsKey(key)) {
      debugPrint('[TableUpdateNotification] Already monitoring history for: $hubSerialNumber');
      return;
    }

    debugPrint('[TableUpdateNotification] Starting history monitoring for: $hubSerialNumber');

    // Monitor daily aggregations (history table)
    final dailyRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/daily');

    _subscriptions[key] = dailyRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        _handleHistoryUpdate(hubSerialNumber);
      }
    });
  }

  /// Monitor both analytics and history for a hub
  void startMonitoringAll(String hubSerialNumber) {
    startMonitoringAnalytics(hubSerialNumber);
    startMonitoringHistory(hubSerialNumber);
  }

  /// Handle analytics table update
  void _handleAnalyticsUpdate(String hubSerialNumber) {
    final key = 'analytics_$hubSerialNumber';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastNotificationTime[key] ?? 0;

    // Debounce: Only send notification if enough time has passed
    if (now - lastTime < _debounceMs) {
      debugPrint('[TableUpdateNotification] Debouncing analytics update for: $hubSerialNumber');
      return;
    }

    _lastNotificationTime[key] = now;

    _notificationService.addNotification(
      type: NotificationType.analyticsUpdate,
      title: 'Analytics Data Updated',
      message: 'New analytics data available for hub $hubSerialNumber',
      metadata: {
        'hubSerialNumber': hubSerialNumber,
        'timestamp': now,
      },
    );

    debugPrint('[TableUpdateNotification] Sent analytics update notification for: $hubSerialNumber');
  }

  /// Handle history table update
  void _handleHistoryUpdate(String hubSerialNumber) {
    final key = 'history_$hubSerialNumber';
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _lastNotificationTime[key] ?? 0;

    // Debounce: Only send notification if enough time has passed
    if (now - lastTime < _debounceMs) {
      debugPrint('[TableUpdateNotification] Debouncing history update for: $hubSerialNumber');
      return;
    }

    _lastNotificationTime[key] = now;

    _notificationService.addNotification(
      type: NotificationType.historyUpdate,
      title: 'Usage History Updated',
      message: 'New usage history data available for hub $hubSerialNumber',
      metadata: {
        'hubSerialNumber': hubSerialNumber,
        'timestamp': now,
      },
    );

    debugPrint('[TableUpdateNotification] Sent history update notification for: $hubSerialNumber');
  }

  /// Stop monitoring analytics for a hub
  void stopMonitoringAnalytics(String hubSerialNumber) {
    final key = 'analytics_$hubSerialNumber';
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);
    _lastNotificationTime.remove(key);
    debugPrint('[TableUpdateNotification] Stopped analytics monitoring for: $hubSerialNumber');
  }

  /// Stop monitoring history for a hub
  void stopMonitoringHistory(String hubSerialNumber) {
    final key = 'history_$hubSerialNumber';
    _subscriptions[key]?.cancel();
    _subscriptions.remove(key);
    _lastNotificationTime.remove(key);
    debugPrint('[TableUpdateNotification] Stopped history monitoring for: $hubSerialNumber');
  }

  /// Stop monitoring both analytics and history for a hub
  void stopMonitoringAll(String hubSerialNumber) {
    stopMonitoringAnalytics(hubSerialNumber);
    stopMonitoringHistory(hubSerialNumber);
  }

  /// Stop all monitoring
  void stopAllMonitoring() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _lastNotificationTime.clear();
    debugPrint('[TableUpdateNotification] Stopped all monitoring');
  }

  /// Dispose resources
  void dispose() {
    stopAllMonitoring();
  }
}
