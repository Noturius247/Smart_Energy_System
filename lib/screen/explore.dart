import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'connected_devices.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';

class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  List<ConnectedDevice> filteredDevices = List.from(connectedDevices);

  @override
  void initState() {
    super.initState();
    filteredDevices = connectedDevices;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }

  void _searchSerialNumber() async {
    final serialNumber = _serialNumberController.text.trim();
    if (serialNumber.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to link a device.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }


    final dbRef = FirebaseDatabase.instance.ref('users/espthesisbmn_at_gmail_com/hubs/$serialNumber');
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final assigned = data['assigned'] ?? false;

      if (assigned) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device is already assigned.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        if (!mounted) return;
        final bool confirmLink = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text(
                  "Link Central Hub",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                content: Text(
                  "A Central Hub with serial number '$serialNumber' was found and is available. Do you want to link it to your account?",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text("Cancel",
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Link"),
                  ),
                ],
              ),
            ) ??
            false;

        if (confirmLink) {
          // Link to user account and add to Firestore
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await dbRef.update({'assigned': true, 'ownerId': user.uid, 'user_email': user.email});
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('devices')
                .doc(serialNumber)
                .set({
              'name': 'Central Hub',
              'serialNumber': serialNumber,
              'createdAt': FieldValue.serverTimestamp(),
              'user_email': user.email,
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device successfully linked.'),
                backgroundColor: Colors.green,
              ),
            );

            // Add the newly linked device to the local list
            setState(() {
              connectedDevices.add(
                ConnectedDevice(
                  name: 'Central Hub',
                  icon: Icons.router, // Using Icons.router for Central Hub
                  status: 'on', // Default status
                  usage: 0.0,
                  percent: 0.0,
                  plug: 1,
                  serialNumber: serialNumber,
                ),
              );
              filteredDevices = List.from(connectedDevices);
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device linking cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serial number not found.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addDeviceDialog() {
    final nameController = TextEditingController();
    String status = "off";
    String selectedIcon = "Devices";
    int selectedPlug = 1;

    final Map<String, IconData> iconOptions = {
      "Devices": Icons.devices_other,
      "Light": Icons.lightbulb_outline,
      "Fan": Icons.toys,
      "TV": Icons.tv,
      "AC": Icons.ac_unit,
      "Fridge": Icons.kitchen,
      "Washer": Icons.local_laundry_service,
      "Microwave": Icons.microwave,
      "Computer": Icons.computer,
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            "Add Device",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Device Name",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: InputDecoration(
                    labelText: "Status",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: "on",
                        child: Text("On", style: Theme.of(context).textTheme.bodyLarge)),
                    DropdownMenuItem(
                        value: "off",
                        child: Text("Off", style: Theme.of(context).textTheme.bodyLarge)),
                  ],
                  onChanged: (value) => status = value ?? "off",
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedPlug,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: InputDecoration(
                    labelText: "Plug Number",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 1,
                      child: Text("Plug 1", style: Theme.of(context).textTheme.bodyLarge),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text("Plug 2", style: Theme.of(context).textTheme.bodyLarge),
                    ),
                  ],
                  onChanged: (value) {
                    selectedPlug = value ?? 1;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: InputDecoration(
                    labelText: "Device Icon",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  items: iconOptions.keys.map((iconName) {
                    return DropdownMenuItem(
                      value: iconName,
                      child: Row(
                        children: [
                          Icon(iconOptions[iconName], color: Theme.of(context).iconTheme.color),
                          const SizedBox(width: 8),
                          Text(iconName, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedIcon = value ?? "Devices";
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: Theme.of(context).textTheme.bodyMedium),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  setState(() {
                    connectedDevices.add(ConnectedDevice(
                      name: nameController.text,
                      icon: iconOptions[selectedIcon] ?? Icons.devices_other,
                      status: status,
                      usage: 0.0,
                      percent: 0.0,
                      plug: selectedPlug,
                    ));
                    filteredDevices = List.from(connectedDevices);
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  void _editDeviceDialog(ConnectedDevice device) {
    final nameController = TextEditingController(text: device.name);
    String status = device.status.toLowerCase();
    IconData selectedIcon = device.icon;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text("Edit Device", style: Theme.of(context).textTheme.bodyLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Device Name",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                    focusedBorder:
                        UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary)),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: InputDecoration(
                    labelText: "Status",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: "on",
                        child: Text("On", style: Theme.of(context).textTheme.bodyLarge)),
                    DropdownMenuItem(
                        value: "off",
                        child: Text("Off", style: Theme.of(context).textTheme.bodyLarge)),
                  ],
                  onChanged: (value) => status = value ?? "off",
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IconData>(
                  initialValue: selectedIcon,
                  dropdownColor: Theme.of(context).cardColor,
                  decoration: InputDecoration(
                    labelText: "Icon",
                    labelStyle: Theme.of(context).textTheme.bodyMedium,
                  ),
                  items: [
                    DropdownMenuItem(value: Icons.kitchen, child: Icon(Icons.kitchen, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(
                        value: Icons.local_laundry_service,
                        child: Icon(Icons.local_laundry_service, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(value: Icons.tv, child: Icon(Icons.tv, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(value: Icons.videocam, child: Icon(Icons.videocam, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(value: Icons.lightbulb, child: Icon(Icons.lightbulb, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(value: Icons.thermostat, child: Icon(Icons.thermostat, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(
                        value: Icons.phone_android, child: Icon(Icons.phone_android, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(value: Icons.toys, child: Icon(Icons.toys, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(value: Icons.laptop, child: Icon(Icons.laptop, color: Theme.of(context).iconTheme.color)),
                    DropdownMenuItem(
                        value: Icons.devices_other, child: Icon(Icons.devices_other, color: Theme.of(context).iconTheme.color)),
                  ],
                  onChanged: (icon) => selectedIcon = icon ?? Icons.devices_other,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: Theme.of(context).textTheme.bodyMedium),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.secondary),
              onPressed: () {
                setState(() {
                  device.name = nameController.text;
                  device.status = status;
                  device.icon = selectedIcon;
                });
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    return Scaffold(
      body: isSmallScreen ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        CustomSidebarNav(
          currentIndex: 1,
          isBottomNav: false,
          onTap: (index, page) {
            if (index == 1) return;
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => page),
            );
          },
        ),
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildMainContent()),
        CustomSidebarNav(
          currentIndex: 1,
          isBottomNav: true,
          onTap: (index, page) {
            if (index == 1) return;
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => page),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).primaryColor,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            CustomHeader(
              isSidebarOpen: true,
              isDarkMode: Provider.of<ThemeNotifier>(context).darkTheme,
              onToggleDarkMode: () {
                Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    Text(
                      'Devices',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add Central Hub',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _serialNumberController,
                            decoration: InputDecoration(
                              hintText: 'Enter Serial Number...',
                              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.secondary),
                              filled: true,
                              fillColor: Theme.of(context).primaryColor.withAlpha(200),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _searchSerialNumber,
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connected Devices',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        FloatingActionButton.extended(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          onPressed: _addDeviceDialog,
                          label: Text(
                            "Add Device",
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          icon: Icon(Icons.add, color: Theme.of(context).iconTheme.color, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Device Cards
                    ...filteredDevices.map((device) {
                      return Card(
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(device.icon, color: Theme.of(context).colorScheme.secondary, size: 32),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name,
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                      if (device.serialNumber != null)
                                        Text(
                                          'S/N: ${device.serialNumber}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                        ),
                                      Text(
                                        device.status == "on"
                                            ? "Status: On | Plug ${device.plug}"
                                            : "Status: Off",
                                        style: TextStyle(
                                          color: device.status == "on" ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                    tooltip: "Edit Device",
                                    onPressed: () => _editDeviceDialog(device),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    tooltip: "Delete Device",
                                    onPressed: () async {
                                      final confirmDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: Theme.of(context).cardColor,
                                          title: Text(
                                            "Delete Device",
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                          content: Text(
                                            "Are you sure you want to delete '${device.name}'?",
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: Text("Cancel",
                                                  style: Theme.of(context).textTheme.bodyMedium),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text("Delete"),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmDelete == true) {
                                        setState(() {
                                          connectedDevices.remove(device);
                                          filteredDevices = List.from(connectedDevices);
                                        });
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("${device.name} has been deleted."),
                                            backgroundColor: Colors.redAccent,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      device.status == "on" ? Icons.toggle_on : Icons.toggle_off,
                                      color: device.status == "on" ? Colors.green : Colors.grey,
                                      size: 36,
                                    ),
                                    tooltip: device.status == "on" ? "Turn Off" : "Turn On",
                                    onPressed: () {
                                      setState(() {
                                        device.status = device.status == "on" ? "off" : "on";
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}