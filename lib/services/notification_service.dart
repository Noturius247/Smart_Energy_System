import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum NotificationType {
  hubToggle,
  plugToggle,
  priceUpdate,
  dueDateUpdate,
  deviceAdded,
  deviceRemoved,
  scheduleCreated,
  scheduleUpdated,
  scheduleDeleted,
  energyAlert,
  costAlert,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory NotificationItem.fromJson(String id, Map<dynamic, dynamic> json) {
    return NotificationItem(
      id: id,
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.energyAlert,
      ),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isRead: json['isRead'] as bool? ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NotificationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference? get _notificationsRef {
    if (_userId == null) return null;
    // Store notifications per user, not in the shared espthesisbmn path
    return _dbRef.child('users/$_userId/notifications');
  }

  // Add a notification
  Future<void> addNotification({
    required NotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final ref = _notificationsRef;
      if (ref == null) {
        debugPrint('[NotificationService] User not authenticated');
        return;
      }

      final notification = NotificationItem(
        id: ref.push().key!,
        type: type,
        title: title,
        message: message,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      await ref.child(notification.id).set(notification.toJson());
      debugPrint('[NotificationService] Notification added: ${notification.title}');
    } catch (e) {
      debugPrint('[NotificationService] Error adding notification: $e');
    }
  }

  // Get notifications stream
  Stream<List<NotificationItem>> getNotificationsStream() {
    final ref = _notificationsRef;
    if (ref == null) {
      return Stream.value([]);
    }

    return ref
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <NotificationItem>[];
      }

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final notifications = data.entries
          .map((entry) => NotificationItem.fromJson(
                entry.key as String,
                entry.value as Map<dynamic, dynamic>,
              ))
          .toList();

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return notifications;
    }).handleError((error) {
      debugPrint('[NotificationService] Error streaming notifications: $error');
      return <NotificationItem>[];
    });
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final ref = _notificationsRef;
      if (ref == null) return;

      await ref.child(notificationId).update({'isRead': true});
      debugPrint('[NotificationService] Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('[NotificationService] Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final ref = _notificationsRef;
      if (ref == null) return;

      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) return;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final updates = <String, dynamic>{};

      data.forEach((key, value) {
        if (value is Map && value['isRead'] != true) {
          updates['$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await ref.update(updates);
        debugPrint('[NotificationService] All notifications marked as read');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final ref = _notificationsRef;
      if (ref == null) return;

      await ref.child(notificationId).remove();
      debugPrint('[NotificationService] Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('[NotificationService] Error deleting notification: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      final ref = _notificationsRef;
      if (ref == null) return;

      await ref.remove();
      debugPrint('[NotificationService] All notifications deleted');
    } catch (e) {
      debugPrint('[NotificationService] Error deleting all notifications: $e');
    }
  }

  // Helper methods to track specific activities

  Future<void> trackHubToggle(String hubName, bool newState) async {
    await addNotification(
      type: NotificationType.hubToggle,
      title: 'Hub ${newState ? 'Activated' : 'Deactivated'}',
      message: 'Hub "$hubName" has been turned ${newState ? 'ON' : 'OFF'}',
      metadata: {'hubName': hubName, 'state': newState},
    );
  }

  Future<void> trackPlugToggle(String plugName, bool newState) async {
    await addNotification(
      type: NotificationType.plugToggle,
      title: 'Device ${newState ? 'Turned On' : 'Turned Off'}',
      message: 'Device "$plugName" has been ${newState ? 'activated' : 'deactivated'}',
      metadata: {'plugName': plugName, 'state': newState},
    );
  }

  Future<void> trackPriceUpdate(double oldPrice, double newPrice) async {
    final change = newPrice - oldPrice;
    final isIncrease = change > 0;

    await addNotification(
      type: NotificationType.priceUpdate,
      title: 'Electricity Rate ${isIncrease ? 'Increased' : 'Decreased'}',
      message: 'Rate changed from ₱${oldPrice.toStringAsFixed(2)} to ₱${newPrice.toStringAsFixed(2)} per kWh',
      metadata: {
        'oldPrice': oldPrice,
        'newPrice': newPrice,
        'change': change,
      },
    );
  }

  Future<void> trackDueDateUpdate(DateTime oldDate, DateTime newDate) async {
    await addNotification(
      type: NotificationType.dueDateUpdate,
      title: 'Bill Due Date Updated',
      message: 'Due date changed to ${newDate.day}/${newDate.month}/${newDate.year}',
      metadata: {
        'oldDate': oldDate.toIso8601String(),
        'newDate': newDate.toIso8601String(),
      },
    );
  }

  Future<void> trackDeviceAdded(String deviceName) async {
    await addNotification(
      type: NotificationType.deviceAdded,
      title: 'New Device Added',
      message: 'Device "$deviceName" has been added to your system',
      metadata: {'deviceName': deviceName},
    );
  }

  Future<void> trackDeviceRemoved(String deviceName) async {
    await addNotification(
      type: NotificationType.deviceRemoved,
      title: 'Device Removed',
      message: 'Device "$deviceName" has been removed from your system',
      metadata: {'deviceName': deviceName},
    );
  }

  Future<void> trackScheduleCreated(String scheduleName) async {
    await addNotification(
      type: NotificationType.scheduleCreated,
      title: 'Schedule Created',
      message: 'New schedule "$scheduleName" has been created',
      metadata: {'scheduleName': scheduleName},
    );
  }

  Future<void> trackScheduleUpdated(String scheduleName) async {
    await addNotification(
      type: NotificationType.scheduleUpdated,
      title: 'Schedule Updated',
      message: 'Schedule "$scheduleName" has been modified',
      metadata: {'scheduleName': scheduleName},
    );
  }

  Future<void> trackScheduleDeleted(String scheduleName) async {
    await addNotification(
      type: NotificationType.scheduleDeleted,
      title: 'Schedule Deleted',
      message: 'Schedule "$scheduleName" has been removed',
      metadata: {'scheduleName': scheduleName},
    );
  }

  Future<void> trackEnergyAlert(String message, {Map<String, dynamic>? metadata}) async {
    await addNotification(
      type: NotificationType.energyAlert,
      title: 'Energy Alert',
      message: message,
      metadata: metadata,
    );
  }

  Future<void> trackCostAlert(String message, {Map<String, dynamic>? metadata}) async {
    await addNotification(
      type: NotificationType.costAlert,
      title: 'Cost Alert',
      message: message,
      metadata: metadata,
    );
  }
}
