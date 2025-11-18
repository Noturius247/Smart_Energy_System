import 'package:rflutter_alert/rflutter_alert.dart';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'connected_devices.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';
import '../constants.dart';

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
  Map<String, List<ConnectedDevice>> _groupedDevices = {};

  // New state variables for Realtime DB linked hubs

  bool _isHubsLoading = true;
  String? _hubErrorMessage;
  Timer? _refreshTimer; // New: Timer for periodic refresh
  double _pricePerKWH = 0.0; // New state variable for price per kWh

  @override
  void initState() {
    super.initState();
    _loadPricePerKWH(); // Load saved price on init
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();
    _loadAllDevices(); // Initial load

    // New: Start periodic refresh
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _loadAllDevices();
      _loadPricePerKWH(); // Also refresh price per kWh
    });
  }

  // Method to load price per kWh from Firestore
  Future<void> _loadPricePerKWH() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _pricePerKWH = 0.0;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('pricePerKWH')) {
        setState(() {
          _pricePerKWH = (doc.data()!['pricePerKWH'] as num).toDouble();
        });
      } else {
        setState(() {
          _pricePerKWH = 0.0;
        });
      }
    } catch (e) {
      print('Error loading price per kWh from Firestore: $e');
      setState(() {
        _pricePerKWH = 0.0; // Default in case of error
      });
    }
  }

  Future<void> _loadAllDevices() async {
    print('[_loadAllDevices] Starting to load all devices...');
    final List<ConnectedDevice> allDevices = [
      ...await _fetchUserDevices(),
      ...await _fetchLinkedCentralHubs(),
    ];
    print('[_loadAllDevices] Fetched ${allDevices.length} total devices.');

    final Map<String, List<ConnectedDevice>> grouped = {};
    for (final device in allDevices) {
      final key = device.serialNumber ?? 'generic';
      if (grouped.containsKey(key)) {
        grouped[key]!.add(device);
      } else {
        grouped[key] = [device];
      }
    }

    setState(() {
      _groupedDevices = grouped;
      print('[_loadAllDevices] Total devices loaded and grouped: ${grouped.length}');
    });

    if (allDevices.isEmpty) {
      Alert(
        context: context,
        title: "No Devices Found",
        desc:
            "No connected devices were found for your account. Please make sure your devices are properly set up and connected.",
        buttons: [
          DialogButton(
            child: Text(
              "Retry",
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            onPressed: () {
              Navigator.pop(context);
              _loadAllDevices();
            },
            width: 120,
          ),
        ],
      ).show();
    }
  }

  Future<List<ConnectedDevice>> _fetchLinkedCentralHubs() async {
    setState(() {
      _isHubsLoading = true;
      _hubErrorMessage = null;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _hubErrorMessage = "Please log in to view your Linked central hubs.";
        _isHubsLoading = false;
      });
      return [];
    }

    final String? authenticatedUserUID = currentUser.uid;

    if (authenticatedUserUID == null) {
      setState(() {
        _hubErrorMessage = "Authenticated user UID is missing.";
        _isHubsLoading = false;
      });
      return [];
    }

    try {
      // 1. Fetch all hubs from Realtime Database
      final hubSnapshot =
          await FirebaseDatabase.instance.ref('users/espthesisbmn_at_gmail_com/hubs').get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) {
        print('[_fetchLinkedCentralHubs] No hubs found in Realtime Database.');
        setState(() {
          _isHubsLoading = false;
        });
        return [];
      }

      final allHubs =
          json.decode(json.encode(hubSnapshot.value)) as Map<String, dynamic>;
      final List<ConnectedDevice> fetchedPlugDevices = [];

      print(
        '[_fetchLinkedCentralHubs] Fetched ${allHubs.length} hubs from RTDB.',
      );

      // 2. Filter hubs by ownerId
      for (final serialNumber in allHubs.keys) {
        final hubData = allHubs[serialNumber] as Map<String, dynamic>;

        if (hubData['ownerId'] == authenticatedUserUID) {
          print(
            '[_fetchLinkedCentralHubs] Found owned hub with serial number: $serialNumber.',
          );

          // Add the central hub itself as a ConnectedDevice
          fetchedPlugDevices.add(
            ConnectedDevice(
              name: 'Central Hub ($serialNumber)',
              status: 'on', // Assuming hub is "on" if found
              icon: Icons.router, // Icon for the central hub
              usage: 0.0,
              percent: 0.0,
              plug: null, // Central hub itself, not a specific plug
              serialNumber: serialNumber,
            ),
          );

          if (hubData.containsKey("plugs")) {
            final plugsData = hubData["plugs"] as Map<String, dynamic>;
            for (final plugId in plugsData.keys) {
              final plugData = plugsData[plugId] as Map<String, dynamic>;
              if (plugData.containsKey("data")) {
                final realTimeData = plugData["data"] as Map<String, dynamic>;
                print(
                  '[_fetchLinkedCentralHubs] Found plug $plugId data: $realTimeData',
                );

                fetchedPlugDevices.add(
                  ConnectedDevice(
                    name: 'Plug $plugId',
                    status: 'on', // Assuming plugs are "on" if reporting data
                    icon: Icons.power, // A generic icon for a plug
                    usage:
                        0.0, // Placeholder, as usage might be calculated differently
                    percent: 0.0, // Placeholder
                    plug: plugId,
                    serialNumber: serialNumber,
                    current: (realTimeData['current'] as num?)?.toDouble(),
                    energy: (realTimeData['energy'] as num?)?.toDouble(),
                    power: (realTimeData['power'] as num?)?.toDouble(),
                    voltage: (realTimeData['voltage'] as num?)?.toDouble(),
                  ),
                );
              }
            }
          }
        }
      }

      setState(() {
        _isHubsLoading = false;
      });
      return fetchedPlugDevices;
    } catch (e) {
      print('[_fetchLinkedCentralHubs] An error occurred: $e');
      setState(() {
        _hubErrorMessage = "Failed to load data from Firebase: $e";
        _isHubsLoading = false;
      });
      return [];
    }
  }

  Future<List<ConnectedDevice>> _fetchUserDevices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[_fetchUserDevices] User not logged in.');
      return [];
    }
    print('[_fetchUserDevices] Fetching devices for user: ${user.uid}');

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .get();

      print(
        '[_fetchUserDevices] Retrieved ${querySnapshot.docs.length} documents.',
      );

      final fetchedDevices = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            print('[_fetchUserDevices] Document data: $data');
            final device = ConnectedDevice(
              name: data['name'] ?? 'Unknown Device',
              status: data['status'] ?? 'off',
              icon: data['icon'] != null
                  ? IconData(data['icon'], fontFamily: 'MaterialIcons')
                  : Icons.devices_other, // Reconstruct IconData
              usage: (data['usage'] as num?)?.toDouble() ?? 0.0,
              percent: (data['percent'] as num?)?.toDouble() ?? 0.0,
              plug: (data['plug']?.toString()),
              serialNumber: data['serialNumber'] as String?,
            );
            print(
              '[_fetchUserDevices] Created ConnectedDevice: ${device.name}',
            );
            return device;
          })
          .toList();

      return fetchedDevices;
    } catch (e) {
      print('[_fetchUserDevices] Error fetching devices: $e');
      if (!mounted) return [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching devices: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return [];
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _serialNumberController.dispose();
    _refreshTimer?.cancel(); // Cancel the timer
    super.dispose();
  }

  void _searchSerialNumber() async {
    final serialNumber = _serialNumberController.text.trim();
    print('[_searchSerialNumber] Searching for serial number: $serialNumber');
    if (serialNumber.isEmpty) {
      print('[_searchSerialNumber] Serial number is empty.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      print(
        '[_searchSerialNumber] User not logged in or email is null. User: $user',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to link a device.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    print(
      '[_searchSerialNumber] Current user UID: ${user.uid}, Email: ${user.email}',
    );

    final dbRef = FirebaseDatabase.instance.ref('users/espthesisbmn_at_gmail_com/hubs/$serialNumber');
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final ownerId = data['ownerId']; // Get ownerId from Realtime DB
      final assigned = data['assigned'] ?? false; // Get assigned status
      print(
        '[_searchSerialNumber] Device found in Realtime DB. Data: $data, Assigned: $assigned, OwnerId: $ownerId',
      );

      if (assigned && ownerId == user.uid) {
        // Hub is assigned AND owned by the current user
        print(
          '[_searchSerialNumber] Hub already assigned to current user. Refreshing and showing plugs.',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hub already linked. Scanning for plugs...'),
            backgroundColor: Colors.blueAccent,
          ),
        );
        _fetchLinkedCentralHubs(); // Refresh the list to show plugs
      } else if (assigned && ownerId != user.uid) {
        // Hub is assigned but to a different user
        print('[_searchSerialNumber] Hub is assigned to another user.');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hub is already assigned to another user.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Hub is found in Realtime DB but not assigned (or assigned is false)
        // Proceed with the linking dialog
        if (!mounted) return;
        final bool confirmLink =
            await showDialog<bool>(
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
                    child: Text(
                      "Cancel",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
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
            print(
              '[_searchSerialNumber] User confirmed link. Updating Realtime DB and Firestore.',
            );
            await dbRef.update({
              'assigned': true,
              'ownerId': user.uid,
              'user_email': user.email,
            });
            final firestoreData = {
              'name': 'Central Hub',
              'serialNumber': serialNumber,
              'createdAt': FieldValue.serverTimestamp(),
              'user_email': user.email,
            };
            print('[_searchSerialNumber] Writing to Firestore: $firestoreData');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('devices')
                .doc(serialNumber)
                .set(firestoreData);

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device successfully linked.'),
                backgroundColor: Colors.green,
              ),
            );

            // Refresh all devices
            await _loadAllDevices();
          }
        } else {
          print('[_searchSerialNumber] Device linking cancelled by user.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device linking cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      print('[_searchSerialNumber] Serial number not found in Realtime DB.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serial number not found.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          title: Text(
            "Edit Device",
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
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
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
                      child: Text(
                        "On",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    DropdownMenuItem(
                      value: "off",
                      child: Text(
                        "Off",
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
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
                    DropdownMenuItem(
                      value: Icons.kitchen,
                      child: Icon(
                        Icons.kitchen,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.local_laundry_service,
                      child: Icon(
                        Icons.local_laundry_service,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.tv,
                      child: Icon(
                        Icons.tv,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.videocam,
                      child: Icon(
                        Icons.videocam,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.lightbulb,
                      child: Icon(
                        Icons.lightbulb,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.thermostat,
                      child: Icon(
                        Icons.thermostat,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.phone_android,
                      child: Icon(
                        Icons.phone_android,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.toys,
                      child: Icon(
                        Icons.toys,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.laptop,
                      child: Icon(
                        Icons.laptop,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                    DropdownMenuItem(
                      value: Icons.devices_other,
                      child: Icon(
                        Icons.devices_other,
                        color: Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ],
                  onChanged: (icon) =>
                      selectedIcon = icon ?? Icons.devices_other,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Cancel",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You must be logged in to edit a device.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Find the document ID for the device in Firestore
                String? docId;
                if (device.serialNumber != null) {
                  // For Central Hubs, the doc ID is the serial number
                  docId = device.serialNumber;
                } else {
                  // For generic devices, we need to query to find the doc ID
                  final querySnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('devices')
                      .where(
                        'name',
                        isEqualTo: device.name,
                      ) // Assuming name is unique enough for generic devices
                      .limit(1)
                      .get();
                  if (querySnapshot.docs.isNotEmpty) {
                    docId = querySnapshot.docs.first.id;
                  }
                }

                if (docId != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('devices')
                      .doc(docId)
                      .update({
                        'name': nameController.text,
                        'status': status,
                        'icon': selectedIcon.codePoint,
                      });
                }

                if (!mounted) return;
                Navigator.pop(context);
                await _loadAllDevices(); // Refresh all devices
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGenericDeviceCard(ConnectedDevice device, bool isSmallScreen) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: isSmallScreen ? 12 : 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  device.icon,
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary,
                  size: isSmallScreen ? 32 : 48,
                ),
                SizedBox(width: isSmallScreen ? 12 : 20),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: isSmallScreen ? 16 : null),
                    ),
                    Text(
                      device.status == "on"
                          ? "Status: On"
                          : "Status: Off",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: isSmallScreen ? 14 : null,
                        color: device.status == "on"
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: Colors.blueAccent,
                    size: isSmallScreen ? 24 : 32,
                  ),
                  tooltip: "Edit Device",
                  onPressed: () => _editDeviceDialog(device),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Colors.redAccent,
                    size: isSmallScreen ? 24 : 32,
                  ),
                  tooltip: "Delete Device",
                  onPressed: () => _deleteGenericDeviceDialog(device),
                ),
                IconButton(
                  icon: Icon(
                    device.status == "on"
                        ? Icons.toggle_on
                        : Icons.toggle_off,
                    color: device.status == "on"
                        ? Colors.green
                        : Colors.grey,
                    size: isSmallScreen ? 32 : 40,
                  ),
                  tooltip: device.status == "on"
                      ? "Turn Off"
                      : "Turn On",
                  onPressed: () {
                    setState(() {
                      device.status = device.status == "on"
                          ? "off"
                          : "on";
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlugDeviceRow(ConnectedDevice plug, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 24.0, vertical: isSmallScreen ? 8.0 : 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                plug.icon,
                color: Theme.of(context).colorScheme.secondary,
                size: isSmallScreen ? 24 : 32,
              ),
              SizedBox(width: isSmallScreen ? 10 : 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plug.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: isSmallScreen ? 14 : null),
                  ),
                  Text(
                    plug.status == "on"
                        ? "Status: On"
                        : "Status: Off",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: isSmallScreen ? 12 : null,
                      color: plug.status == "on"
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  if (plug.current != null)
                    Text(
                      'Current: ${plug.current?.toStringAsFixed(2)} A',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: isSmallScreen ? 10 : null),
                    ),
                  if (plug.energy != null) ...[
                    Text(
                      'Energy: ${plug.energy?.toStringAsFixed(2)} kWh',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: isSmallScreen ? 10 : null),
                    ),
                    Text(
                      'Cost: \$${(plug.energy! * _pricePerKWH).toStringAsFixed(2)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: isSmallScreen ? 10 : null),
                    ),
                  ],
                  if (plug.power != null)
                    Text(
                      'Power: ${plug.power?.toStringAsFixed(2)} W',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: isSmallScreen ? 10 : null),
                    ),
                  if (plug.voltage != null)
                    Text(
                      'Voltage: ${plug.voltage?.toStringAsFixed(2)} V',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: isSmallScreen ? 10 : null),
                    ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: Colors.blueAccent,
                  size: isSmallScreen ? 20 : 28,
                ),
                tooltip: "Edit Device",
                onPressed: () => _editDeviceDialog(plug),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.redAccent,
                  size: isSmallScreen ? 20 : 28,
                ),
                tooltip: "Delete Device",
                onPressed: () => _deletePlugDialog(plug),
              ),
              IconButton(
                icon: Icon(
                  plug.status == "on"
                      ? Icons.toggle_on
                      : Icons.toggle_off,
                  color: plug.status == "on"
                      ? Colors.green
                      : Colors.grey,
                  size: isSmallScreen ? 32 : 40,
                ),
                tooltip: plug.status == "on"
                    ? "Turn Off"
                    : "Turn On",
                onPressed: () {
                  setState(() {
                    plug.status = plug.status == "on"
                        ? "off"
                        : "on";
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _deleteGenericDeviceDialog(ConnectedDevice device) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(
          context,
        ).cardColor,
        title: Text(
          "Delete Device",
          style: Theme.of(
            context,
          ).textTheme.bodyLarge,
        ),
        content: Text(
          "Are you sure you want to delete '${device.name}'?",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'You must be logged in to delete a device.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Find the document ID for the generic device in Firestore
      String? docId;
      // For generic devices, we need to query to find the doc ID
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .where(
            'name',
            isEqualTo: device.name,
          )
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        docId = querySnapshot.docs.first.id;
      }


      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(docId)
            .delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            "${device.name} has been deleted.",
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(
            seconds: 2,
          ),
        ),
      );
      await _loadAllDevices(); // Refresh all devices
    }
  }

  void _deletePlugDialog(ConnectedDevice plug) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(
          context,
        ).cardColor,
        title: Text(
          "Delete Plug",
          style: Theme.of(
            context,
          ).textTheme.bodyLarge,
        ),
        content: Text(
          "Are you sure you want to delete '${plug.name}'?",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'You must be logged in to delete a plug.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (plug.serialNumber != null && plug.plug != null) {
        // Delete plug from Realtime Database
        await FirebaseDatabase.instance
            .ref('users/espthesisbmn_at_gmail_com/hubs/${plug.serialNumber}/plugs/${plug.plug}')
            .remove();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              "${plug.name} has been deleted from Realtime DB.",
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(
              seconds: 2,
            ),
          ),
        );
      } else {
        // This case should ideally not happen for a plug, but as a fallback,
        // it can try to delete from Firestore if it somehow ended up there.
        String? docId;
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .where(
              'name',
              isEqualTo: plug.name,
            )
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          docId = querySnapshot.docs.first.id;
        }

        if (docId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('devices')
              .doc(docId)
              .delete();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              "${plug.name} has been deleted from Firestore.",
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(
              seconds: 2,
            ),
          ),
        );
      }
      await _loadAllDevices(); // Refresh all devices
    }
  }

  void _deleteHubDialog(ConnectedDevice hub) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(
          context,
        ).cardColor,
        title: Text(
          "Delete Central Hub",
          style: Theme.of(
            context,
          ).textTheme.bodyLarge,
        ),
        content: Text(
          "Are you sure you want to delete '${hub.name}' and all its associated plugs? This will also unlink it from your account.",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "Cancel",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'You must be logged in to delete a hub.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (hub.serialNumber != null) {
        // 1. Unassign hub in Realtime Database
        await FirebaseDatabase.instance
            .ref('users/espthesisbmn_at_gmail_com/hubs/${hub.serialNumber}')
            .update({
              'assigned': false,
              'ownerId': null,
              'user_email': null,
            });

        // 2. Delete hub from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(hub.serialNumber)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              "${hub.name} and its plugs have been unlinked and deleted.",
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(
              seconds: 2,
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: Cannot delete hub without a serial number.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _loadAllDevices(); // Refresh all devices
    }
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600; // Define your small screen breakpoint
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = _isSmallScreen(context);
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
                Provider.of<ThemeNotifier>(
                  context,
                  listen: false,
                ).toggleTheme();
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    Text(
                      'Devices',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add Central Hub',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _serialNumberController,
                            decoration: InputDecoration(
                              hintText: 'Enter Serial Number...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).primaryColor.withAlpha(200),
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
                                              style: Theme.of(context).textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              'Price per kWh: \$$_pricePerKWH',
                                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontSize: 16,
                                                    color: Theme.of(context).colorScheme.primary,
                                                  ),
                                            ),                        
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Device Cards
                    ..._groupedDevices.entries.map((entry) {
                      final serialNumber = entry.key;
                      final devices = entry.value;

                      if (serialNumber == 'generic') {
                        // Handle generic devices (without serial number)
                        return Column(
                          children: devices.map((device) {
                            return _buildGenericDeviceCard(device, isSmallScreen(context));
                          }).toList(),
                        );
                      } else {
                        // Handle hubs and their plugs
                        final hub = devices.firstWhere((d) => d.plug == null, orElse: () => devices.first);
                        final plugs = devices.where((d) => d.plug != null).toList();

                        // Calculate aggregated values for all plugs under this hub
                        double totalCurrent = 0.0;
                        double totalEnergy = 0.0;
                        double totalPower = 0.0;
                        double totalVoltage = 0.0;
                        int activePlugs = 0;

                        for (final plug in plugs) {
                          if (plug.current != null) totalCurrent += plug.current!;
                          if (plug.energy != null) totalEnergy += plug.energy!;
                          if (plug.power != null) totalPower += plug.power!;
                          if (plug.voltage != null) totalVoltage += plug.voltage!;
                          if (plug.current != null || plug.energy != null || plug.power != null || plug.voltage != null) {
                            activePlugs++;
                          }
                        }

                        return Card(
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: EdgeInsets.symmetric(vertical: isSmallScreen(context) ? 8 : 12),
                          child: ExpansionTile(
                            title: Row(
                              children: [
                                Icon(
                                  hub.icon,
                                  color: Theme.of(context).colorScheme.secondary,
                                  size: isSmallScreen(context) ? 28 : 40,
                                ),
                                SizedBox(width: isSmallScreen(context) ? 10 : 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hub.name,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: isSmallScreen(context) ? 16 : null),
                                    ),
                                    if (hub.serialNumber != null)
                                      Text(
                                        'S/N: ${hub.serialNumber}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey, fontSize: isSmallScreen(context) ? 10 : null),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent, size: isSmallScreen(context) ? 24 : 32,),
                              tooltip: "Delete Hub",
                              onPressed: () => _deleteHubDialog(hub),
                            ),
                            children: [
                              if (plugs.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen(context) ? 16.0 : 24.0, vertical: isSmallScreen(context) ? 8.0 : 12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Plug Output:',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: isSmallScreen(context) ? 16 : null),
                                      ),
                                      if (activePlugs > 0) ...[
                                        Text(
                                          'Total Current: ${totalCurrent.toStringAsFixed(2)} A',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isSmallScreen(context) ? 14 : null),
                                        ),
                                        Text(
                                          'Total Energy: ${totalEnergy.toStringAsFixed(2)} kWh',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isSmallScreen(context) ? 14 : null),
                                        ),
                                        Text(
                                          'Total Power: ${totalPower.toStringAsFixed(2)} W',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isSmallScreen(context) ? 14 : null),
                                        ),
                                        Text(
                                          'Total Voltage: ${totalVoltage.toStringAsFixed(2)} V',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: isSmallScreen(context) ? 14 : null),
                                        ),
                                      ] else
                                        Text(
                                          'No active plug data available.',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, fontSize: isSmallScreen(context) ? 14 : null),
                                        ),
                                      const Divider(), // Separator
                                    ],
                                  ),
                                ),
                              ...plugs.map((plug) {
                                return _buildPlugDeviceRow(plug, isSmallScreen(context));
                              }).toList(),
                            ],
                          ),
                        );
                      }
                    }).toList(),
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
