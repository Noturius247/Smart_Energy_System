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
  });
}