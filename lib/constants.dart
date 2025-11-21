import 'package:flutter/material.dart';

bool isSmallScreen(BuildContext context) {
  return MediaQuery.of(context).size.width < 600.0;
}

// Firebase Realtime Database user path constant
// NOTE: 'espthesisbmn' is used as a central shared data location for all users
// This is the current architecture where all hubs are stored under this path
// and filtered by ownerId. To change to per-user paths, update this constant.
const String rtdbUserPath = 'users/espthesisbmn';

// A map of codePoints to their corresponding IconData objects for tree shaking.
// Only include icons that are dynamically loaded or part of dropdowns.
const Map<int, IconData> iconCodePointMap = {
  // Icons used dynamically for devices (e.g., in _editDeviceDialog)
  0xE31B: Icons.kitchen, // Icons.kitchen.codePoint
  0xE54D: Icons.local_laundry_service, // Icons.local_laundry_service.codePoint
  0xE644: Icons.tv, // Icons.tv.codePoint
  0xE070: Icons.videocam, // Icons.videocam.codePoint
  0xE0A2: Icons.lightbulb, // Icons.lightbulb.codePoint
  0xE0B9: Icons.thermostat, // Icons.thermostat.codePoint
  0xE47D: Icons.phone_android, // Icons.phone_android.codePoint
  0xE238: Icons.toys, // Icons.toys.codePoint
  0xE324: Icons.laptop, // Icons.laptop.codePoint
  0xE733: Icons.devices_other, // Icons.devices_other.codePoint
  0xE032: Icons.router, // Icons.router.codePoint
  0xE6F4: Icons.power, // Icons.power.codePoint
  // Icons used in other parts of the app that might be relevant for tree shaking
  // (though these are mostly used directly as consts in the UI,
  // including them here ensures they are part of the known set if code changes)
  0xE219: Icons.edit, // Icons.edit.codePoint
  0xE872: Icons.delete, // Icons.delete.codePoint
  0xE5F9: Icons.toggle_on, // Icons.toggle_on.codePoint
  0xE449: Icons.toggle_off, // Icons.toggle_off.codePoint
  0xE8B6: Icons.search, // Icons.search.codePoint
  // Add other icons from energy_chart.dart and analytics.dart as needed
  // Placeholder for energy_chart.dart and analytics.dart specific icons
  0xE8A8: Icons.trending_up, // Icons.trending_up.codePoint
  0xE42A: Icons.show_chart, // Icons.show_chart.codePoint
  0xE0A0: Icons.battery_charging_full, // Icons.battery_charging_full.codePoint
  0xE900: Icons.line_axis, // Icons.line_axis.codePoint
};

// Helper function to get IconData from a codePoint
IconData getIconFromCodePoint(int codePoint) {
  return iconCodePointMap[codePoint] ??
      Icons.devices_other; // Default to a generic icon if not found
}
