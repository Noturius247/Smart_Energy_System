import 'package:flutter/foundation.dart';
import 'dart:async';
import 'services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<NotificationItem> _notifications = [];
  StreamSubscription<List<NotificationItem>>? _notificationSubscription;

  List<NotificationItem> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  NotificationProvider() {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    _notificationSubscription?.cancel();
    _notificationSubscription = _notificationService
        .getNotificationsStream()
        .listen((notifications) {
      _notifications = notifications;
      notifyListeners();
    }, onError: (error) {
      debugPrint('[NotificationProvider] Error: $error');
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    // The stream will automatically update
  }

  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
  }

  Future<void> deleteAllNotifications() async {
    await _notificationService.deleteAllNotifications();
  }

  // Tracking methods
  Future<void> trackHubToggle(String hubName, bool newState) async {
    await _notificationService.trackHubToggle(hubName, newState);
  }

  Future<void> trackPlugToggle(String plugName, bool newState) async {
    await _notificationService.trackPlugToggle(plugName, newState);
  }

  Future<void> trackPriceUpdate(double oldPrice, double newPrice) async {
    await _notificationService.trackPriceUpdate(oldPrice, newPrice);
  }

  Future<void> trackDueDateUpdate(DateTime oldDate, DateTime newDate) async {
    await _notificationService.trackDueDateUpdate(oldDate, newDate);
  }

  Future<void> trackDeviceAdded(String deviceName) async {
    await _notificationService.trackDeviceAdded(deviceName);
  }

  Future<void> trackDeviceRemoved(String deviceName) async {
    await _notificationService.trackDeviceRemoved(deviceName);
  }

  Future<void> trackScheduleCreated(String scheduleName) async {
    await _notificationService.trackScheduleCreated(scheduleName);
  }

  Future<void> trackScheduleUpdated(String scheduleName) async {
    await _notificationService.trackScheduleUpdated(scheduleName);
  }

  Future<void> trackScheduleDeleted(String scheduleName) async {
    await _notificationService.trackScheduleDeleted(scheduleName);
  }

  Future<void> trackEnergyAlert(String message, {Map<String, dynamic>? metadata}) async {
    await _notificationService.trackEnergyAlert(message, metadata: metadata);
  }

  Future<void> trackCostAlert(String message, {Map<String, dynamic>? metadata}) async {
    await _notificationService.trackCostAlert(message, metadata: metadata);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
