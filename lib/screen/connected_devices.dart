import 'package:flutter/material.dart';

class ConnectedDevice {
  String name;
  String status; // ✅ make it mutable
  IconData icon;
  double usage;
  double percent;
   int plug;
  String? serialNumber; // Added serial number field

  ConnectedDevice({
    required this.name,
    required this.status,
    required this.icon,
    required this.usage,
    required this.percent,
     this.plug = 1,
    this.serialNumber, // Initialize serial number
  });
}


