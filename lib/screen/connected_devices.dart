import 'package:flutter/material.dart';

// Existing ConnectedDevice class (kept for potential future use or if other parts of the app depend on it)
class ConnectedDevice {
  String name;
  String status; // ✅ make it mutable
  IconData icon;
  double usage;
  double percent;
  String? plug;
  String? serialNumber; // Added serial number field
  double? current; // New field for current
  double? energy; // New field for energy
  double? power; // New field for power
  double? voltage; // New field for voltage
  String? userEmail; // New field for user email
  String? createdAt; // New field for creation timestamp
  bool? ssr_state;
  String? nickname; // NEW: User-defined nickname for hub or plug
  List<ScheduleData>? schedules; // Scheduling data for this device

  ConnectedDevice({
    required this.name,
    required this.status,
    required this.icon,
    required this.usage,
    required this.percent,
    this.plug,
    this.serialNumber, // Initialize serial number
    this.current,
    this.energy,
    this.power,
    this.voltage,
    this.userEmail, // Initialize user email
    this.createdAt, // Initialize creation timestamp
    this.ssr_state,
    this.nickname, // Initialize nickname
    this.schedules, // Initialize schedules
  });
}

// Schedule data model for device scheduling
class ScheduleData {
  String id; // Unique identifier for this schedule
  TimeOfDay time; // Time to execute the schedule
  bool isEnabled; // Whether this schedule is active
  ScheduleAction action; // What action to perform (turn off/on)
  List<int> repeatDays; // Days of week to repeat (1=Monday, 7=Sunday, 0=No repeat)
  String? label; // Optional user-defined label
  DateTime createdAt; // When this schedule was created

  ScheduleData({
    required this.id,
    required this.time,
    this.isEnabled = true,
    required this.action,
    this.repeatDays = const [],
    this.label,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to JSON for Firebase storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'isEnabled': isEnabled,
      'action': action.toString().split('.').last,
      'repeatDays': repeatDays,
      'label': label,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory ScheduleData.fromJson(Map<String, dynamic> json) {
    return ScheduleData(
      id: json['id'] as String,
      time: TimeOfDay(
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      ),
      isEnabled: json['isEnabled'] as bool? ?? true,
      action: ScheduleAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
        orElse: () => ScheduleAction.turnOff,
      ),
      repeatDays: (json['repeatDays'] as List<dynamic>?)?.cast<int>() ?? [],
      label: json['label'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  // Check if schedule should run today (DEPRECATED - use PhilippinesTime.shouldRunToday instead)
  // Kept for backward compatibility
  bool shouldRunToday() {
    if (repeatDays.isEmpty) return true; // One-time schedule
    // WARNING: This uses device timezone, not Philippine timezone
    // Use PhilippinesTime.shouldRunToday(repeatDays) for accurate Philippine time checking
    final today = DateTime.now().weekday; // 1=Monday, 7=Sunday
    return repeatDays.contains(today);
  }

  // Get human-readable repeat description
  String getRepeatDescription() {
    if (repeatDays.isEmpty) return 'Once';
    if (repeatDays.length == 7) return 'Every day';
    if (repeatDays.length == 5 && !repeatDays.contains(6) && !repeatDays.contains(7)) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 && repeatDays.contains(6) && repeatDays.contains(7)) {
      return 'Weekends';
    }

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return repeatDays.map((day) => dayNames[day - 1]).join(', ');
  }
}

// Actions that can be scheduled
enum ScheduleAction {
  turnOff,
  turnOn,
}
