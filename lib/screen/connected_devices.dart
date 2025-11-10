import 'package:flutter/material.dart';

class ConnectedDevice {
  String name;
  String status; // ✅ make it mutable
  IconData icon;
  double usage;
  double percent;
   int plug;

  ConnectedDevice({
    required this.name,
    required this.status,
    required this.icon,
    required this.usage,
    required this.percent,
     this.plug = 1,
  });
}

// ✅ Shared device list
List<ConnectedDevice> connectedDevices = [
  ConnectedDevice(
      name: "Rice Cooker",
      icon: Icons.kitchen,
      status: "Off",
      usage: 78.1,
      percent: 0.46),
  ConnectedDevice(
      name: "Washing Machine",
      icon: Icons.local_laundry_service,
      status: "Off",
      usage: 20.5,
      percent: 0.15),
  ConnectedDevice(
      name: "TV",
      icon: Icons.tv,
      status: "Off",
      usage: 15.2,
      percent: 0.12),
  ConnectedDevice(
      name: "Security Camera",
      icon: Icons.videocam,
      status: "Off",
      usage: 8.3,
      percent: 0.06),
  ConnectedDevice(
      name: "Smart Light",
      icon: Icons.lightbulb,
      status: "Off",
      usage: 12.7,
      percent: 0.09),
  ConnectedDevice(
      name: "Thermostat",
      icon: Icons.thermostat,
      status: "Off",
      usage: 5.4,
      percent: 0.04),
  ConnectedDevice(
      name: "Cellphone",
      icon: Icons.phone_android,
      status: "Off",
      usage: 2.1,
      percent: 0.02),
  ConnectedDevice(
      name: "Electric Fan",
      icon: Icons.toys,
      status: "Off",
      usage: 10.0,
      percent: 0.07),
  ConnectedDevice(
      name: "Laptop",
      icon: Icons.laptop,
      status: "Off",
      usage: 18.6,
      percent: 0.14),
      
];
