import 'package:flutter/material.dart';
import 'connected_devices.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';

class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> with TickerProviderStateMixin {
  bool _isDarkMode = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
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
    super.dispose();
  }

  void _filterDevices(String query) {
    final results = connectedDevices.where((device) {
      return device.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    setState(() {
      filteredDevices = results;
    });
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
          backgroundColor: const Color(0xFF2A2F45),
          title: const Text(
            "Add Device",
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Device Name",
                    labelStyle: TextStyle(color: Colors.white70),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.teal),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: const Color(0xFF2A2F45),
                  decoration: const InputDecoration(
                    labelText: "Status",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: "on",
                        child: Text("On", style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(
                        value: "off",
                        child: Text("Off", style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (value) => status = value ?? "off",
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedPlug,
                  dropdownColor: const Color(0xFF2A2F45),
                  decoration: const InputDecoration(
                    labelText: "Plug Number",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 1,
                      child: Text("Plug 1", style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text("Plug 2", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (value) {
                    selectedPlug = value ?? 1;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedIcon,
                  dropdownColor: const Color(0xFF2A2F45),
                  decoration: const InputDecoration(
                    labelText: "Device Icon",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: iconOptions.keys.map((iconName) {
                    return DropdownMenuItem(
                      value: iconName,
                      child: Row(
                        children: [
                          Icon(iconOptions[iconName], color: Colors.white),
                          const SizedBox(width: 8),
                          Text(iconName, style: const TextStyle(color: Colors.white)),
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
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
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
          backgroundColor: const Color(0xFF2A2F45),
          title: const Text("Edit Device", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Device Name",
                    labelStyle: TextStyle(color: Colors.white70),
                    focusedBorder:
                        UnderlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  dropdownColor: const Color(0xFF2A2F45),
                  decoration: const InputDecoration(
                    labelText: "Status",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: "on",
                        child: Text("On", style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(
                        value: "off",
                        child: Text("Off", style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (value) => status = value ?? "off",
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<IconData>(
                  initialValue: selectedIcon,
                  dropdownColor: const Color(0xFF2A2F45),
                  decoration: const InputDecoration(
                    labelText: "Icon",
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(value: Icons.kitchen, child: Icon(Icons.kitchen)),
                    DropdownMenuItem(
                        value: Icons.local_laundry_service,
                        child: Icon(Icons.local_laundry_service)),
                    DropdownMenuItem(value: Icons.tv, child: Icon(Icons.tv)),
                    DropdownMenuItem(value: Icons.videocam, child: Icon(Icons.videocam)),
                    DropdownMenuItem(value: Icons.lightbulb, child: Icon(Icons.lightbulb)),
                    DropdownMenuItem(value: Icons.thermostat, child: Icon(Icons.thermostat)),
                    DropdownMenuItem(
                        value: Icons.phone_android, child: Icon(Icons.phone_android)),
                    DropdownMenuItem(value: Icons.toys, child: Icon(Icons.toys)),
                    DropdownMenuItem(value: Icons.laptop, child: Icon(Icons.laptop)),
                    DropdownMenuItem(
                        value: Icons.devices_other, child: Icon(Icons.devices_other)),
                  ],
                  onChanged: (icon) => selectedIcon = icon ?? Icons.devices_other,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                setState(() {
                  device.name = nameController.text;
                  device.status = status;
                  device.icon = selectedIcon;
                });
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
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a2332), Color(0xFF0f1419)],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              CustomHeader(
                isDarkMode: _isDarkMode,
                isSidebarOpen: true,
                onToggleDarkMode: () {
                  setState(() => _isDarkMode = !_isDarkMode);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      const Text(
                        'Devices',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ✅ Removed chat button from here - now only search bar
                      TextField(
                        controller: _searchController,
                        onChanged: _filterDevices,
                        decoration: InputDecoration(
                          hintText: 'Search devices...',
                          prefixIcon: const Icon(Icons.search, color: Colors.teal),
                          filled: true,
                          fillColor: Colors.white.withAlpha(200),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Connected Devices',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          FloatingActionButton.extended(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            onPressed: _addDeviceDialog,
                            label: const Text(
                              "Add Device",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            icon: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Device Cards
                      ...filteredDevices.map((device) {
                        return Card(
                          color: const Color(0xFF2A2F45),
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
                                    Icon(device.icon, color: Colors.teal, size: 32),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                            backgroundColor: const Color(0xFF2A2F45),
                                            title: const Text(
                                              "Delete Device",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            content: Text(
                                              "Are you sure you want to delete '${device.name}'?",
                                              style: const TextStyle(color: Colors.white70),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text("Cancel",
                                                    style: TextStyle(color: Colors.grey)),
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
      ],
    );
  }
}