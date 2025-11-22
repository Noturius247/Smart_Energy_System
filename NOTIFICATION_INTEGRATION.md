# Notification System Integration Guide

This guide explains how to integrate the notification system into your Smart Energy System app to track user activities.

## Overview

The notification system consists of:
- **NotificationService**: Handles Firebase operations for notifications
- **NotificationProvider**: Manages notification state with ChangeNotifier
- **NotificationPanel**: UI widget that displays notifications in a side panel
- **CustomHeader**: Shows notification bell icon with unread badge

## How It Works

The bell icon in the header now:
1. Shows a red badge with the count of unread notifications
2. Opens a sliding notification panel when clicked
3. Displays real-time updates of all user activities

## Integration Examples

### 1. Track Price Updates

When a user updates the electricity price, add this to your code:

```dart
import 'package:provider/provider.dart';
import '../notification_provider.dart';

// Inside your price update function
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

// After successfully updating the price
await notificationProvider.trackPriceUpdate(
  oldPrice, // double - previous price
  newPrice, // double - new price
);
```

**Example Location**: [lib/widgets/notification_box.dart:204-208](lib/widgets/notification_box.dart#L204-L208)

Add this after the price update in the `_showPriceDetailsDialog` function:

```dart
final newPrice = double.tryParse(priceController.text) ?? 0.0;
final note = noteController.text.trim();
final oldPrice = priceProvider.pricePerKWH; // Capture old price

final success = await priceProvider.setPrice(
  newPrice,
  note: note.isEmpty ? null : note,
);

if (success && context.mounted) {
  // Track notification
  final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
  await notificationProvider.trackPriceUpdate(oldPrice, newPrice);

  // Show success message
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Price updated successfully!')),
  );
}
```

### 2. Track Hub Toggle (Power On/Off)

When toggling a hub's power state:

```dart
// In your hub toggle function
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

await notificationProvider.trackHubToggle(
  hubName,  // String - name of the hub
  newState, // bool - true for ON, false for OFF
);
```

**Example Location**: Where you handle hub SSR state changes in your explore/settings screens.

### 3. Track Device/Plug Toggle

When turning a device on or off:

```dart
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

await notificationProvider.trackPlugToggle(
  plugName, // String - name of the plug/device
  newState, // bool - true for ON, false for OFF
);
```

### 4. Track Schedule Operations

When creating, updating, or deleting schedules:

```dart
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

// When creating a schedule
await notificationProvider.trackScheduleCreated(scheduleName);

// When updating a schedule
await notificationProvider.trackScheduleUpdated(scheduleName);

// When deleting a schedule
await notificationProvider.trackScheduleDeleted(scheduleName);
```

**Example Location**: [lib/screen/schedule.dart](lib/screen/schedule.dart) - Add in your schedule management functions

### 5. Track Device Addition/Removal

When adding or removing devices from the system:

```dart
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

// When adding a device
await notificationProvider.trackDeviceAdded(deviceName);

// When removing a device
await notificationProvider.trackDeviceRemoved(deviceName);
```

### 6. Track Due Date Updates

When changing the bill due date:

```dart
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

await notificationProvider.trackDueDateUpdate(
  oldDate, // DateTime - previous due date
  newDate, // DateTime - new due date
);
```

### 7. Custom Alerts

For energy consumption or cost alerts:

```dart
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

// Energy alert
await notificationProvider.trackEnergyAlert(
  'High energy usage detected: 15 kWh in the last hour',
  metadata: {'kWh': 15.0, 'duration': 'hour'},
);

// Cost alert
await notificationProvider.trackCostAlert(
  'Daily budget exceeded: ₱250.00',
  metadata: {'amount': 250.0, 'type': 'daily'},
);
```

## Quick Integration Checklist

- [x] NotificationProvider added to main.dart providers
- [x] NotificationPanel created with slide-in animation
- [x] CustomHeader updated with notification bell and badge
- [ ] Price updates tracked in notification_box.dart
- [ ] Hub toggles tracked in explore/settings screens
- [ ] Plug toggles tracked in device control screens
- [ ] Schedule operations tracked in schedule.dart
- [ ] Device additions/removals tracked
- [ ] Due date updates tracked
- [ ] Custom alerts added where needed

## Where to Add Tracking

### High Priority (Most User Activity)
1. **Price Updates** - lib/widgets/notification_box.dart (line 204)
2. **Device Toggles** - lib/screen/explore.dart, lib/screen/settings.dart
3. **Schedule Management** - lib/screen/schedule.dart

### Medium Priority
4. **Hub Power Toggle** - Where SSR state is controlled
5. **Due Date Updates** - Where due date provider is updated

### Optional
6. **Energy Alerts** - Based on consumption thresholds
7. **Cost Alerts** - Based on budget limits
8. **Device Management** - Add/remove devices

## Testing the Notification System

1. **Test the UI**: Click the bell icon in the header - the notification panel should slide in from the right
2. **Test Notifications**: Perform any tracked action (e.g., update price) and check if it appears in the panel
3. **Test Badge**: Unread notifications should show a red badge with count
4. **Test Mark as Read**: Click on a notification to mark it as read
5. **Test Delete**: Swipe left on a notification to delete it
6. **Test Clear All**: Use the menu to clear all notifications

## Firebase Database Structure

Notifications are stored in Firebase Realtime Database:

```
users/
  {userId}/
    notifications/
      {notificationId}/
        type: "priceUpdate"
        title: "Electricity Rate Increased"
        message: "Rate changed from ₱10.50 to ₱11.20 per kWh"
        timestamp: 1234567890
        isRead: false
        metadata: { oldPrice: 10.5, newPrice: 11.2, change: 0.7 }
```

## Notification Types

- `hubToggle` - Hub power on/off
- `plugToggle` - Device/plug power on/off
- `priceUpdate` - Electricity rate changes
- `dueDateUpdate` - Bill due date changes
- `deviceAdded` - New device added to system
- `deviceRemoved` - Device removed from system
- `scheduleCreated` - New schedule created
- `scheduleUpdated` - Schedule modified
- `scheduleDeleted` - Schedule removed
- `energyAlert` - Energy consumption alerts
- `costAlert` - Cost/budget alerts

## UI Features

- **Badge**: Shows unread count (1-9, or "9+" for more)
- **Side Panel**: Slides in from right with smooth animation
- **Notifications**: Display with icons, timestamps, and color coding
- **Swipe to Delete**: Swipe left on any notification
- **Mark as Read**: Tap notification to mark as read
- **Mark All Read**: Button in header when unread exist
- **Clear All**: Menu option to delete all notifications
- **Relative Time**: Shows "Just now", "5m ago", "2h ago", etc.
- **Empty State**: Friendly message when no notifications

## Next Steps

1. Add notification tracking to your most frequently used features
2. Test the notification flow end-to-end
3. Customize notification messages as needed
4. Consider adding energy/cost alerts based on your app's analytics

## Support

For questions or issues with the notification system, check:
- [lib/services/notification_service.dart](lib/services/notification_service.dart) - Core service implementation
- [lib/notification_provider.dart](lib/notification_provider.dart) - State management
- [lib/widgets/notification_panel.dart](lib/widgets/notification_panel.dart) - UI component
- [lib/screen/custom_header.dart](lib/screen/custom_header.dart) - Header integration
