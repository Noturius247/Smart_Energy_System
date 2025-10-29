import 'package:flutter/material.dart';
import 'package:smartenergy_app/screen/profile.dart';
import 'chatbot.dart';
import 'connected_devices.dart';
import 'custom_bottom_nav.dart';
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

  late AnimationController _profileController;
  late Animation<Offset> _profileSlideAnimation;
  late Animation<double> _profileScaleAnimation;
  late Animation<double> _profileFadeAnimation;

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

    _profileController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _profileSlideAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _profileController, curve: Curves.easeOutBack));
    _profileScaleAnimation = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _profileController, curve: Curves.easeOutBack));
    _profileFadeAnimation = CurvedAnimation(parent: _profileController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _profileController.dispose();
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

  void _showDeviceDialog({ConnectedDevice? device, int? index}) {
    final nameController = TextEditingController(text: device?.name ?? "");
    IconData? selectedIcon = device?.icon;

    final Map<String, IconData> icons = {
      '💡 ': Icons.lightbulb,
      '🔌 ': Icons.power,
      '📱 ': Icons.phone_android,
      '💻 ': Icons.laptop,
      '🎛 ': Icons.devices,
    };

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (context, setStateDialog) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    device == null ? 'Add Device' : 'Edit Device',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Device Name',
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedIcon != null
                        ? icons.entries
                            .firstWhere((e) => e.value == selectedIcon,
                                orElse: () => const MapEntry('🎛 ', Icons.devices))
                            .key
                        : null,
                    hint: const Text('Select Icon'),
                    items: icons.keys
                        .map((iconName) => DropdownMenuItem(value: iconName, child: Text(iconName)))
                        .toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedIcon = icons[value!];
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty) {
                            setState(() {
                              if (device == null) {
                                connectedDevices.add(
                                  ConnectedDevice(
                                    name: nameController.text,
                                    status: "off",
                                    icon: selectedIcon ?? Icons.devices,
                                    usage: 0.0,
                                    percent: 0.0,
                                  ),
                                );
                              } else {
                                connectedDevices[index!] = ConnectedDevice(
                                  name: nameController.text,
                                  status: device.status,
                                  icon: selectedIcon ?? device.icon,
                                  usage: device.usage,
                                  percent: device.percent,
                                );
                              }
                              filteredDevices = List.from(connectedDevices);
                            });
                            Navigator.pop(context);
                          }
                        },
                        child: Text(device == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _removeDevice(int index) {
    setState(() {
      connectedDevices.removeAt(index);
      filteredDevices = List.from(connectedDevices);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // background gradient
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
                // ✅ Reusable Header
                CustomHeader(
                  isDarkMode: _isDarkMode,
                  isSidebarOpen: false,
                  onToggleDarkMode: () {
                    setState(() => _isDarkMode = !_isDarkMode);
                  },
                ),

                const SizedBox(height: 16),

                // Main Body
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      children: [
                        const Text(
                          'Devices',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 16),

                        // Search + Chat
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: _filterDevices,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                                decoration: InputDecoration(
                                  hintText: 'Search devices....',
                                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(200),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.teal,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.chat, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Connected Devices Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Connected Devices',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            FloatingActionButton.extended(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              onPressed: () => _showDeviceDialog(),
                              label: const Text("Add Device",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              icon: const Icon(Icons.add, color: Colors.white, size: 16),
                              extendedPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Device Cards
                        ...filteredDevices.asMap().entries.map((entry) {
                          int index = entry.key;
                          ConnectedDevice device = entry.value;

                          Color statusColor;
                          switch (device.status.toLowerCase()) {
                            case "on":
                            case "active":
                            case "charging":
                              statusColor = Colors.green;
                              break;
                            case "off":
                              statusColor = Colors.red;
                              break;
                            default:
                              statusColor = Colors.orange;
                          }

                          return Card(
                            color: const Color(0xFF2A2F45),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: Icon(device.icon, color: Colors.teal),
                              title: Text(device.name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text("Status: ${device.status}", style: TextStyle(color: statusColor)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        device.status = device.status.toLowerCase() == "on" ? "off" : "on";
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: 70,
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: device.status.toLowerCase() == 'on'
                                              ? [Colors.teal, Colors.greenAccent]
                                              : [Colors.grey.shade700, Colors.grey.shade800],
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          if (device.status.toLowerCase() == 'on')
                                            const BoxShadow(color: Colors.teal, blurRadius: 8, spreadRadius: 1),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: Text(
                                                'OFF',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: device.status.toLowerCase() == 'on'
                                                      ? Colors.transparent
                                                      : Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 8),
                                              child: Text(
                                                'ON',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: device.status.toLowerCase() == 'on'
                                                      ? Colors.black87
                                                      : Colors.transparent,
                                                ),
                                              ),
                                            ),
                                          ),
                                          AnimatedAlign(
                                            duration: const Duration(milliseconds: 250),
                                            alignment: device.status.toLowerCase() == 'on'
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: device.status.toLowerCase() == 'on' ? Colors.white : Colors.black,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.yellow),
                                    onPressed: () => _showDeviceDialog(device: device, index: index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeDevice(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Profile Popover
          Positioned(
            top: 70,
            right: 12,
            child: FadeTransition(
              opacity: _profileFadeAnimation,
              child: SlideTransition(
                position: _profileSlideAnimation,
                child: ScaleTransition(
                  scale: _profileScaleAnimation,
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(150),
                          blurRadius: 10,
                          offset: const Offset(2, 2),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                        const SizedBox(height: 12),
                        const CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.teal,
                            child: Icon(Icons.person, size: 30, color: Colors.white)),
                        const SizedBox(height: 12),
                        const Text('Marie Fe Tapales',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('mariefe@example.com',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            _profileController.reverse();
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (!mounted) return;
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const EnergyProfileScreen()));
                            });
                          },
                          child: const Text('View Profile',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _profileController.reverse,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(36)),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1, // since this is Devices
        onTap: (index, page) {
          if (index == 1) return; // already on Devices
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
      ),
    );
  }
}
