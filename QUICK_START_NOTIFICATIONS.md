# Quick Start: Using the Notification System

## How to Use the Notifications (User Guide)

### 1. Viewing Notifications

**Step 1:** Look for the bell icon 🔔 in the top-right corner of the header

**Step 2:** If you have unread notifications, you'll see a red badge with a number

**Step 3:** Click the bell icon to open the notification panel

### 2. Managing Notifications

#### Mark as Read
- **Tap** any notification to mark it as read
- The blue dot disappears, and the background color fades

#### Delete a Notification
- **Swipe left** on any notification
- The notification will be deleted

#### Mark All as Read
- Click the **"Mark all read"** button in the header
- All notifications will be marked as read at once

#### Clear All Notifications
- Click the **⋮** (three dots) menu in the header
- Select **"Clear all"**
- Confirm the action

### 3. What Gets Tracked?

Currently, the system tracks:

✅ **Price Changes**
- When you update the electricity rate
- Shows old price → new price

🔄 **Coming Soon:**
- Hub power toggles
- Device on/off actions
- Schedule changes
- Due date updates
- Energy alerts
- Cost alerts

---

## Developer Guide: Adding Notification Tracking

### Quick Integration Pattern

```dart
// 1. Import the provider
import 'package:provider/provider.dart';
import '../notification_provider.dart';

// 2. Get the notification provider (inside a function with BuildContext)
final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);

// 3. Track the activity
await notificationProvider.trackXXX(...);
```

### Example 1: Track Device Toggle

```dart
// When toggling a device on/off
Future<void> toggleDevice(String deviceName, bool newState) async {
  // Your existing device toggle logic here
  // ...

  // Add notification tracking
  if (context.mounted) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.trackPlugToggle(deviceName, newState);
  }
}
```

### Example 2: Track Hub Toggle

```dart
// When toggling a hub on/off
Future<void> toggleHub(String hubName, bool newState) async {
  // Your existing hub toggle logic here
  // ...

  // Add notification tracking
  if (context.mounted) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.trackHubToggle(hubName, newState);
  }
}
```

### Example 3: Track Schedule Creation

```dart
// When creating a new schedule
Future<void> createSchedule(String scheduleName) async {
  // Your existing schedule creation logic here
  // ...

  // Add notification tracking
  if (context.mounted) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notificationProvider.trackScheduleCreated(scheduleName);
  }
}
```

### Example 4: Custom Alert

```dart
// When energy consumption exceeds threshold
if (energyConsumption > threshold) {
  final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
  await notificationProvider.trackEnergyAlert(
    'High energy usage: ${energyConsumption.toStringAsFixed(2)} kWh',
    metadata: {
      'consumption': energyConsumption,
      'threshold': threshold,
    },
  );
}
```

---

## Available Tracking Methods

| Method | Parameters | Use Case |
|--------|------------|----------|
| `trackHubToggle` | hubName, newState | Hub power on/off |
| `trackPlugToggle` | plugName, newState | Device power on/off |
| `trackPriceUpdate` | oldPrice, newPrice | Electricity rate change |
| `trackDueDateUpdate` | oldDate, newDate | Bill due date change |
| `trackDeviceAdded` | deviceName | New device added |
| `trackDeviceRemoved` | deviceName | Device removed |
| `trackScheduleCreated` | scheduleName | Schedule created |
| `trackScheduleUpdated` | scheduleName | Schedule modified |
| `trackScheduleDeleted` | scheduleName | Schedule deleted |
| `trackEnergyAlert` | message, metadata | Energy consumption alert |
| `trackCostAlert` | message, metadata | Cost/budget alert |

---

## Where to Add Tracking

### Priority Locations

1. **Device Controls**
   - File: `lib/screen/explore.dart`
   - File: `lib/screen/settings.dart`
   - Look for: Device toggle buttons/switches
   - Add: `trackPlugToggle(deviceName, newState)`

2. **Hub Controls**
   - File: `lib/screen/explore.dart`
   - File: `lib/screen/settings.dart`
   - Look for: Hub power controls
   - Add: `trackHubToggle(hubName, newState)`

3. **Schedule Management**
   - File: `lib/screen/schedule.dart`
   - Look for: Schedule create/update/delete functions
   - Add: `trackScheduleCreated/Updated/Deleted(scheduleName)`

4. **Due Date Updates**
   - File: Where `DueDateProvider` is used
   - Look for: Due date change functions
   - Add: `trackDueDateUpdate(oldDate, newDate)`

### Testing Your Integration

After adding tracking:

1. Perform the action (e.g., toggle a device)
2. Click the bell icon
3. Verify the notification appears
4. Check the notification details
5. Test marking as read
6. Test deleting

---

## Troubleshooting

### Notification not appearing?
- Check if the tracking method is being called
- Verify the user is authenticated
- Check Firebase Realtime Database rules
- Look for errors in the debug console

### Badge not showing?
- Refresh the page
- Check if notifications are marked as read
- Verify NotificationProvider is in the widget tree

### Panel not opening?
- Check if CustomHeader is using NotificationProvider
- Verify the bell icon has the `onPressed` handler

---

## Tips

1. **Always check context.mounted** before using context after async operations
2. **Use descriptive names** for devices/schedules in tracking calls
3. **Test each integration** immediately after adding it
4. **Keep notifications relevant** - don't over-notify
5. **Use metadata** to store additional information

---

## Need Help?

See the full documentation:
- [NOTIFICATION_INTEGRATION.md](NOTIFICATION_INTEGRATION.md) - Detailed integration guide
- [NOTIFICATION_SUMMARY.md](NOTIFICATION_SUMMARY.md) - Implementation summary
- [lib/services/notification_service.dart](lib/services/notification_service.dart) - Service code
- [lib/notification_provider.dart](lib/notification_provider.dart) - Provider code
