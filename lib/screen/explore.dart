import 'package:rflutter_alert/rflutter_alert.dart';
import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // Added for firstWhereOrNull
import '../constants.dart';
import 'connected_devices.dart';

import '../realtime_db_service.dart';
import '../notification_provider.dart';

class DevicesTab extends StatefulWidget {
  final RealtimeDbService realtimeDbService;
  const DevicesTab({super.key, required this.realtimeDbService});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> with TickerProviderStateMixin {
  late RealtimeDbService _realtimeDbService;
  StreamSubscription?
  _hubDataSubscription; // Existing subscription for old stream
  StreamSubscription?
  _hubDataStreamSubscription; // New subscription for the updated hub data stream

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  Map<String, List<ConnectedDevice>> _groupedDevices = {};
  bool _isInitializing = true; // Track initial load state


  // Timer? _refreshTimer; // Removed: No longer needed for periodic refresh
  double _pricePerKWH = 0.0; // New state variable for price per kWh
  String _currencySymbol = '₱'; // Currency symbol loaded from settings
  DateTime? _dueDate;

  Future<void> _loadAllDevices() async {
    print('[_loadAllDevices] Starting to load all devices...');
    final List<ConnectedDevice> allDevices = [
      ...await _fetchUserDevices(),
      ...await _fetchLinkedCentralHubs(), // This now only returns hubs
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
      print(
        '[_loadAllDevices] Total devices loaded and grouped: ${grouped.length}',
      );
      // Debug: Log hub states after loading
      for (final entry in grouped.entries) {
        final hubs = entry.value.where((d) => d.plug == null);
        for (final hub in hubs) {
          print('[_loadAllDevices] Hub ${hub.serialNumber} loaded with ssr_state: ${hub.ssr_state}, status: ${hub.status}');
        }
      }
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


    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {

      return [];
    }

    final String? authenticatedUserUID = currentUser.uid;

    if (authenticatedUserUID == null) {

      return [];
    }

    try {
      // EFFICIENCY FIX: Filter hubs by ownerId at query level
      final hubSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(authenticatedUserUID)
          .get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) {
        print('[_fetchLinkedCentralHubs] No hubs found in Realtime Database.');

        return [];
      }

      final allHubs =
          json.decode(json.encode(hubSnapshot.value)) as Map<String, dynamic>;
      final List<ConnectedDevice> fetchedPlugDevices = [];

      print(
        '[_fetchLinkedCentralHubs] Fetched ${allHubs.length} hubs from RTDB (filtered by ownerId).',
      );

      // Process user's hubs (already filtered by query)
      for (final serialNumber in allHubs.keys) {
        final hubData = allHubs[serialNumber] as Map<String, dynamic>;

        // IMPORTANT: Double-check the hub is actually assigned and belongs to this user
        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        if (!isAssigned || hubOwnerId != authenticatedUserUID) {
          print(
            '[_fetchLinkedCentralHubs] Skipping hub $serialNumber - not assigned or wrong owner (assigned: $isAssigned, ownerId: $hubOwnerId)',
          );
          continue; // Skip this hub
        }

        print(
          '[_fetchLinkedCentralHubs] Found owned hub with serial number: $serialNumber.',
        );

        // FIX: Fetch the current ssr_state directly from Firebase to ensure accuracy
        final ssrStateSnapshot = await FirebaseDatabase.instance
            .ref('$rtdbUserPath/hubs/$serialNumber/ssr_state')
            .get();

        final bool hubSsrState = ssrStateSnapshot.exists
            ? (ssrStateSnapshot.value as bool? ?? false)
            : (hubData['ssr_state'] as bool? ?? false);

        print('[_fetchLinkedCentralHubs] Hub $serialNumber actual ssr_state from Firebase: $hubSsrState');

        final String? hubNickname = hubData['nickname'] as String?;

        // Add the central hub itself as a ConnectedDevice
        fetchedPlugDevices.add(
          ConnectedDevice(
            name: hubNickname != null && hubNickname.isNotEmpty
                ? '$hubNickname ($serialNumber)'
                : 'Central Hub ($serialNumber)',
            status: hubSsrState
                ? 'on'
                : 'off', // Assuming hub is "on" if found
            icon: Icons.router, // Icon for the central hub
            usage: 0.0,
            percent: 0.0,
            plug: null, // Central hub itself, not a specific plug
            serialNumber: serialNumber,
            ssr_state: hubSsrState,
            nickname: hubNickname, // Load nickname from Firebase
          ),
        );
      }


      return fetchedPlugDevices;
    } catch (e) {
      print('[_fetchLinkedCentralHubs] An error occurred: $e');

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

      final fetchedDevices = querySnapshot.docs.map((doc) {
        final data = doc.data();
        print('[_fetchUserDevices] Document data: $data');

        final device = ConnectedDevice(
          name: data['name']?.toString() ?? 'Unknown Device',
          status: data['status']?.toString() ?? 'off',
          icon: getIconFromCodePoint(
            data['icon'] as int? ?? Icons.devices_other.codePoint,
          ), // Use helper for tree-shaking
          usage: (data['usage'] as num?)?.toDouble() ?? 0.0,
          percent: (data['percent'] as num?)?.toDouble() ?? 0.0,
          plug: data['plug']?.toString(),
          serialNumber: data['serialNumber']?.toString(),
          userEmail: data['user_email']?.toString(), // Safely convert to string
          createdAt: (data['createdAt'] as Timestamp?)
              ?.toDate()
              .toString(), // Populate createdAt
        );
        print('[_fetchUserDevices] Created ConnectedDevice: ${device.name}');
        return device;
      }).toList();

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
  void initState() {
    super.initState();
    _realtimeDbService = widget.realtimeDbService; // Initialize the service
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // CRITICAL FIX: Initialize devices FIRST, then start listeners
    // This ensures we have the correct state before listeners can overwrite it
    _initializeDevicesAndHubs(); // Call a new async method to handle setup

    _loadPricePerKWH(); // Load price per KWH on init
    _loadCurrencySymbol(); // Load currency symbol from settings
    _loadDueDate();
    // NOTE: _listenToHubDataStream() is now called AFTER devices are loaded in _initializeDevicesAndHubs()
    _activeHubSubscription = _realtimeDbService.activeHubStream.listen((_) {
      if (mounted) {
        setState(() {}); // Rebuild to update 'Active' indicator
      }
    });
  }

  Future<void> _initializeDevicesAndHubs() async {
    // CRITICAL FIX: Load devices FIRST to populate _groupedDevices
    // This ensures the data structure is ready when stream events arrive
    await _loadAllDevices(); // Await to ensure _groupedDevices is populated
    debugPrint('[_initializeDevicesAndHubs] Devices loaded, now starting listeners');

    // CRITICAL FIX: Start listening to hub data stream AFTER devices are loaded
    // This ensures _groupedDevices is populated when stream events arrive
    _listenToHubDataStream();
    debugPrint('[_initializeDevicesAndHubs] Started listening to hub data stream');

    // FIX: Ensure real-time listeners are active and wait for initial state sync
    // This prevents the hub from appearing "off" during page refresh
    final hubSerialNumbers = _groupedDevices.entries
        .where((entry) => entry.key != 'generic')
        .expand((entry) => entry.value)
        .where((device) => device.plug == null && device.serialNumber != null)
        .map((device) => device.serialNumber!)
        .toSet();

    if (hubSerialNumbers.isNotEmpty) {
      // Start streams for all hubs to ensure fresh connections
      for (final serialNumber in hubSerialNumbers) {
        if (!_realtimeDbService.currentActiveHubs.contains(serialNumber)) {
          _realtimeDbService.startRealtimeDataStream(serialNumber);
          debugPrint('[_initializeDevicesAndHubs] Started stream for hub: $serialNumber');
        }
      }

      // Auto-activate the first hub if no hub is currently active for analytics
      if (_realtimeDbService.currentActiveHubs.isEmpty) {
        final firstHubSerialNumber = hubSerialNumbers.first;
        _setActiveHub(firstHubSerialNumber);
        debugPrint('ExploreScreen: Automatically activated hub: $firstHubSerialNumber for analytics.');
      }

      // CRITICAL FIX: Wait for real-time stream to deliver initial ssr_state
      // This ensures the UI displays the correct state on refresh
      await Future.delayed(const Duration(milliseconds: 800));
      debugPrint('[_initializeDevicesAndHubs] Waited for initial ssr_state sync');

      // CRITICAL FIX: Re-fetch SSR state from Firebase to ensure accuracy after stream initialization
      // This handles any edge cases where the stream event might have been missed
      for (final serialNumber in hubSerialNumbers) {
        final ssrStateSnapshot = await FirebaseDatabase.instance
            .ref('$rtdbUserPath/hubs/$serialNumber/ssr_state')
            .get();

        final bool currentSsrState = ssrStateSnapshot.exists
            ? (ssrStateSnapshot.value as bool? ?? false)
            : false;

        debugPrint('[_initializeDevicesAndHubs] Re-fetched SSR state for $serialNumber: $currentSsrState');

        // Update the hub's state in _groupedDevices
        final List<ConnectedDevice>? devices = _groupedDevices[serialNumber];
        if (devices != null) {
          final hubIndex = devices.indexWhere((d) => d.plug == null);
          if (hubIndex != -1) {
            devices[hubIndex].ssr_state = currentSsrState;
            devices[hubIndex].status = currentSsrState ? 'on' : 'off';
            debugPrint('[_initializeDevicesAndHubs] Force-updated hub $serialNumber to ssr_state: $currentSsrState');
          }
        }
      }
    }

    // CRITICAL FIX: Mark initialization complete and force UI rebuild
    // This ensures the UI renders with the correct hub state we just loaded
    if (mounted) {
      setState(() {
        _isInitializing = false;
        debugPrint('[_initializeDevicesAndHubs] Initialization complete, forcing final UI update');
      });
    }
  }

  Future<void> _loadDueDate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('dueDate')) {
        setState(() {
          _dueDate = (doc.data()!['dueDate'] as Timestamp).toDate();
        });
      }
    } catch (e) {
      print('Error loading due date: $e');
    }
  }

  void _listenToHubDataStream() {
    _hubDataStreamSubscription = _realtimeDbService.hubDataStream.listen(
      (data) {
        if (!mounted) return; // Check if the widget is still mounted
        print('[_listenToHubDataStream] Received data: $data');
        setState(() {
          final String? serialNumber = data['serialNumber'];
          if (serialNumber == null) return;

          final String type = data['type'];

          // Handle hub state updates
          if (type == 'hub_state') {
            final bool? ssrState = data['ssr_state'] as bool?;
            print('[_listenToHubDataStream] Hub state update - Serial: $serialNumber, SSR: $ssrState, Type: $type');

            // Only skip update if we're actively toggling AND the state matches what we just set
            // This prevents conflicts but still allows database to override if values differ
            if (_pendingHubToggles.contains(serialNumber)) {
              final List<ConnectedDevice>? devices = _groupedDevices[serialNumber];
              if (devices != null) {
                final hubIndex = devices.indexWhere((d) => d.plug == null);
                if (hubIndex != -1 && devices[hubIndex].ssr_state == ssrState) {
                  // State matches our pending toggle, safe to ignore
                  print('[_listenToHubDataStream] State matches pending toggle, skipping update for: $serialNumber');
                  return;
                }
              }
            }

            if (ssrState != null) {
              final List<ConnectedDevice>? devices =
                  _groupedDevices[serialNumber];
              if (devices != null) {
                final hubIndex = devices.indexWhere((d) => d.plug == null);
                print('[_listenToHubDataStream] Found hub at index: $hubIndex');
                if (hubIndex != -1) {
                  devices[hubIndex].ssr_state = ssrState;
                  devices[hubIndex].status = ssrState ? 'on' : 'off';
                  print('[_listenToHubDataStream] Updated hub SSR state to: $ssrState, status: ${devices[hubIndex].status}');
                }
              }
            }
          }
          // Handle plug data updates (changed or added)
          else if (type == 'plug_changed' || type == 'plug_added') {
            final String? plugId = data['plugId'];
            final Map<dynamic, dynamic>? plugData = data['plugData'];
            if (plugId != null && plugData != null) {
              final Map<dynamic, dynamic>? realTimeData = plugData['data'];
              final String? plugNickname = plugData['nickname'] as String?;

              final bool plugSsrState =
                  (realTimeData?['ssr_state'] as bool?) ?? false;

              List<ConnectedDevice> currentDevices =
                  _groupedDevices[serialNumber] ?? [];
              ConnectedDevice? existingPlug;

              // Find existing plug
              for (var device in currentDevices) {
                if (device.plug == plugId) {
                  existingPlug = device;
                  break;
                }
              }

              if (existingPlug != null) {
                // Update existing plug's real-time properties
                existingPlug.status = plugSsrState ? 'on' : 'off';
                existingPlug.ssr_state = plugSsrState;
                existingPlug.current = (realTimeData?['current'] as num?)
                    ?.toDouble();
                existingPlug.energy = (realTimeData?['energy'] as num?)
                    ?.toDouble();
                existingPlug.power = (realTimeData?['power'] as num?)
                    ?.toDouble();
                existingPlug.voltage = (realTimeData?['voltage'] as num?)
                    ?.toDouble();
                // Update nickname if changed
                if (plugNickname != existingPlug.nickname) {
                  existingPlug.nickname = plugNickname;
                  existingPlug.name = plugNickname != null && plugNickname.isNotEmpty
                      ? '$plugNickname ($plugId)'
                      : 'Plug $plugId';
                }
              } else {
                // Plug is new, create it with initial properties.
                // For icon, usage, and percent, we use defaults or assume they are not dynamically updated
                // through the real-time stream.
                final ConnectedDevice newPlug = ConnectedDevice(
                  name: plugNickname != null && plugNickname.isNotEmpty
                      ? '$plugNickname ($plugId)'
                      : 'Plug $plugId',
                  status: plugSsrState ? 'on' : 'off',
                  ssr_state: plugSsrState,
                  icon: Icons.power, // Default icon
                  usage: 0.0, // Default usage
                  percent: 0.0, // Default percent
                  plug: plugId,
                  serialNumber: serialNumber,
                  current: (realTimeData?['current'] as num?)?.toDouble(),
                  energy: (realTimeData?['energy'] as num?)?.toDouble(),
                  power: (realTimeData?['power'] as num?)?.toDouble(),
                  voltage: (realTimeData?['voltage'] as num?)?.toDouble(),
                  nickname: plugNickname, // Include nickname
                );

                // Add new plug, ensuring the hub itself is always the first item if present
                final hubDevice = currentDevices.firstWhereOrNull(
                  (d) => d.plug == null,
                );
                if (hubDevice != null) {
                  _groupedDevices[serialNumber] = [
                    hubDevice,
                    newPlug,
                    ...currentDevices.where(
                      (d) => d.plug != null && d.plug != plugId,
                    ),
                  ];
                } else {
                  _groupedDevices[serialNumber] = [...currentDevices, newPlug];
                }
              }
            }
          }
          // Handle plug removal
          else if (type == 'plug_removed') {
            final String? plugId = data['plugId'];
            if (plugId != null) {
              _groupedDevices[serialNumber]?.removeWhere(
                (device) => device.plug == plugId,
              );
            }
          }
        });
      },
      onError: (error) {
        debugPrint('Error in hubDataStream: $error');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Real-time data error: $error')));
      },
    );
  }

  Future<void> _loadPricePerKWH() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('pricePerKWH')) {
        setState(() {
          _pricePerKWH = (doc.data()!['pricePerKWH'] as num?)?.toDouble() ?? 12.0;
        });
      } else {
        setState(() {
          _pricePerKWH = 12.0; // Default value
        });
      }
    } catch (e) {
      print('Error loading price per kWh: $e');
      setState(() {
        _pricePerKWH = 12.0;
      });
    }
  }

  Future<void> _loadCurrencySymbol() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('currency')) {
        setState(() {
          _currencySymbol = doc.data()!['currency'] as String? ?? '₱';
        });
      }
    } catch (e) {
      print('Error loading currency symbol: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _serialNumberController.dispose();
    _hubDataSubscription?.cancel(); // Cancel the old stream subscription
    _hubDataStreamSubscription?.cancel(); // Cancel the new stream subscription
    _activeHubSubscription?.cancel(); // Cancel the active hub subscription
    // DO NOT call stopAllRealtimeDataStreams() or dispose() on the service
    // RealtimeDbService is a singleton shared across the app
    // Other screens (like Analytics) are still using it
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

    final dbRef = FirebaseDatabase.instance.ref(
      '$rtdbUserPath/hubs/$serialNumber',
    );
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
                      backgroundColor: Colors.green,
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

            // Track device added notification
            if (mounted) {
              final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
              await notificationProvider.trackDeviceAdded('Central Hub ($serialNumber)');
            }

            // Notify the service about hub addition (broadcasts to all pages)
            _realtimeDbService.notifyHubAdded(serialNumber);
            print('[_searchSerialNumber] Notified hub addition for: $serialNumber');

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Device successfully linked to all pages.'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  color: Theme.of(context).colorScheme.secondary,
                  size: isSmallScreen ? 32 : 48,
                ),
                SizedBox(width: isSmallScreen ? 12 : 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isSmallScreen ? 16 : null,
                      ),
                    ),
                    Text(
                      device.status == "on" ? "Status: On" : "Status: Off",
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
                    device.status == "on" ? Icons.toggle_on : Icons.toggle_off,
                    color: device.status == "on" ? Colors.green : Colors.grey,
                    size: isSmallScreen ? 32 : 40,
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
  }

  Widget _buildPlugDeviceRow(ConnectedDevice plug, bool isSmallScreen, bool isHubActive) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 14.0 : 20.0,
        vertical: isSmallScreen ? 12.0 : 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                // Modern Icon Container
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    color: isHubActive
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: isHubActive
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    plug.icon,
                    color: Colors.white,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Device Name with modern styling
                      Text(
                        plug.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: isSmallScreen ? 15 : 17,
                          fontWeight: FontWeight.w600,
                          color: isHubActive ? null : Colors.grey,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 4 : 6),
                      // Status Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 10,
                          vertical: isSmallScreen ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: !isHubActive
                                ? [Colors.grey.shade400, Colors.grey.shade600]
                                : plug.status == "on"
                                    ? [Colors.green.shade400, Colors.green.shade600]
                                    : [Colors.red.shade400, Colors.red.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: isSmallScreen ? 6 : 8,
                              height: isSmallScreen ? 6 : 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              !isHubActive ? "INACTIVE" : (plug.status == "on" ? "ONLINE" : "OFFLINE"),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 10 : 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 6 : 8),
                      // Metrics with modern layout - Hide when hub is inactive
                      if (isHubActive)
                        Wrap(
                          spacing: isSmallScreen ? 12 : 16,
                          runSpacing: isSmallScreen ? 4 : 6,
                          children: [
                            if (plug.current != null)
                              _buildMetricChip(
                                Icons.flash_on_rounded,
                                '${plug.current?.toStringAsFixed(2)} A',
                                Colors.blue, // Matching analytics
                                isSmallScreen,
                              ),
                            if (plug.power != null)
                              _buildMetricChip(
                                Icons.power_rounded,
                                '${plug.power?.toStringAsFixed(2)} W',
                                Colors.purple, // Matching analytics
                                isSmallScreen,
                              ),
                            if (plug.voltage != null)
                              _buildMetricChip(
                                Icons.electrical_services_rounded,
                                '${plug.voltage?.toStringAsFixed(2)} V',
                                Colors.orange, // Matching analytics
                                isSmallScreen,
                              ),
                            if (plug.energy != null)
                              _buildMetricChip(
                                Icons.battery_charging_full_rounded,
                                '${plug.energy?.toStringAsFixed(2)} kWh',
                                Colors.green, // Matching analytics
                                isSmallScreen,
                              ),
                          ],
                        )
                      else
                        // Show "No Data" when hub is inactive
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10,
                            vertical: isSmallScreen ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sync_disabled_rounded,
                                size: isSmallScreen ? 12 : 14,
                                color: Colors.grey.shade700,
                              ),
                              SizedBox(width: isSmallScreen ? 4 : 6),
                              Text(
                                'No Data - Hub Inactive',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (plug.energy != null && isHubActive) ...[
                        SizedBox(height: isSmallScreen ? 4 : 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10,
                            vertical: isSmallScreen ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purple.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_money_rounded,
                                size: isSmallScreen ? 12 : 14,
                                color: Colors.purple.shade700,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Cost: $_currencySymbol${(plug.energy! * _pricePerKWH).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          // Modern Action Buttons
          Column(
            children: [
              // Edit Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _editNicknameDialog(plug),
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: Colors.blue.shade700,
                      size: isSmallScreen ? 18 : 22,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 10),
              // Toggle Button with animation
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () => _togglePlugSsrState(plug),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 10 : 12,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: (plug.ssr_state ?? false)
                            ? [Colors.green.shade400, Colors.green.shade600]
                            : [Colors.grey.shade300, Colors.grey.shade500],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: (plug.ssr_state ?? false)
                              ? Colors.green.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      (plug.ssr_state ?? false)
                          ? Icons.power_settings_new_rounded
                          : Icons.power_off_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method for metric chips
  Widget _buildMetricChip(IconData icon, String label, MaterialColor color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 12 : 14,
            color: color.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: color.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Track pending toggle operations to prevent listener conflicts
  final Set<String> _pendingHubToggles = {};

  void _toggleHubSsrState(ConnectedDevice hub) async {
    if (hub.serialNumber == null) return;

    final serialNumber = hub.serialNumber!;

    // Prevent duplicate toggle operations
    if (_pendingHubToggles.contains(serialNumber)) {
      debugPrint('[_toggleHubSsrState] Toggle already in progress for hub: $serialNumber');
      return;
    }

    _pendingHubToggles.add(serialNumber);

    // Optimistic UI Update
    setState(() {
      hub.ssr_state = !(hub.ssr_state ?? false);
      hub.status = hub.ssr_state! ? 'on' : 'off';
    });

    final newSsrState = hub.ssr_state!;
    final dbRef = FirebaseDatabase.instance.ref(
      '$rtdbUserPath/hubs/$serialNumber/ssr_state',
    );

    try {
      await dbRef.set(newSsrState);
      debugPrint('[_toggleHubSsrState] Successfully set hub $serialNumber ssr_state to $newSsrState');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${hub.name} turned ${newSsrState ? 'ON' : 'OFF'}'),
          backgroundColor: newSsrState ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('[_toggleHubSsrState] Error updating hub state: $e');
      // Revert UI on error
      setState(() {
        hub.ssr_state = !newSsrState;
        hub.status = hub.ssr_state! ? 'on' : 'off';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating hub state: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Remove from pending set immediately after database operation completes
      _pendingHubToggles.remove(serialNumber);
      debugPrint('[_toggleHubSsrState] Removed $serialNumber from pending toggles');
    }
  }

  void _togglePlugSsrState(ConnectedDevice plug) async {
    if (plug.serialNumber == null || plug.plug == null) return;

    // Optimistic UI Update
    setState(() {
      plug.ssr_state = !(plug.ssr_state ?? false);
      plug.status = plug.ssr_state! ? 'on' : 'off';
    });

    final newSsrState = plug.ssr_state!;
    final dbRef = FirebaseDatabase.instance.ref(
      '$rtdbUserPath/hubs/${plug.serialNumber}/plugs/${plug.plug}/data/ssr_state',
    );

    try {
      await dbRef.set(newSsrState);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${plug.name} turned ${newSsrState ? 'ON' : 'OFF'}'),
          backgroundColor: newSsrState ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      // Revert UI on error
      setState(() {
        plug.ssr_state = !newSsrState;
        plug.status = plug.ssr_state! ? 'on' : 'off';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating plug state: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // NEW: Edit nickname dialog for hubs and plugs
  void _editNicknameDialog(ConnectedDevice device) async {
    final TextEditingController nicknameController = TextEditingController(
      text: device.nickname ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          device.plug == null ? 'Edit Hub Nickname' : 'Edit Plug Nickname',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.plug == null
                  ? 'Hub: ${device.serialNumber}'
                  : 'Plug: ${device.plug} (${device.serialNumber})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nicknameController,
              decoration: InputDecoration(
                labelText: 'Nickname',
                hintText: 'Enter a friendly name',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => nicknameController.clear(),
                ),
              ),
              maxLength: 30,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'Cancel',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, nicknameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _saveNickname(device, result);
    }
  }

  // NEW: Save nickname to Firebase
  Future<void> _saveNickname(ConnectedDevice device, String nickname) async {
    if (device.serialNumber == null) return;

    try {
      String path;
      if (device.plug == null) {
        // Central hub nickname
        path = '$rtdbUserPath/hubs/${device.serialNumber}/nickname';
      } else {
        // Plug nickname
        path = '$rtdbUserPath/hubs/${device.serialNumber}/plugs/${device.plug}/nickname';
      }

      final dbRef = FirebaseDatabase.instance.ref(path);

      if (nickname.isEmpty) {
        // Remove nickname if empty
        await dbRef.remove();
      } else {
        // Save nickname
        await dbRef.set(nickname);
      }

      // Update local state
      setState(() {
        device.nickname = nickname.isEmpty ? null : nickname;
        // Update display name to show nickname
        if (device.plug == null) {
          device.name = nickname.isEmpty
              ? 'Central Hub (${device.serialNumber})'
              : '$nickname (${device.serialNumber})';
        } else {
          device.name = nickname.isEmpty
              ? 'Plug ${device.plug}'
              : '$nickname (${device.plug})';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nickname.isEmpty
                  ? 'Nickname removed'
                  : 'Nickname saved: $nickname',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('[_saveNickname] Saved nickname "$nickname" to $path');
    } catch (e) {
      print('[_saveNickname] Error saving nickname: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving nickname: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteGenericDeviceDialog(ConnectedDevice device) async {
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
            child: Text(
              "Cancel",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to delete a device.'),
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
          .where('name', isEqualTo: device.name)
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

        // Track device removed notification
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          await notificationProvider.trackDeviceRemoved(device.name);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${device.name} has been deleted."),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      await _loadAllDevices(); // Refresh all devices
    }
  }


  void _deleteHubDialog(ConnectedDevice hub) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          "Unlink Central Hub",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        content: Text(
          "Are you sure you want to unlink '${hub.name}'? This will remove it from your account, but it can be re-linked later.",
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Unlink"),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to unlink a hub.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (hub.serialNumber != null) {
        // 1. Unassign hub in Realtime Database by setting fields to null/false
        await FirebaseDatabase.instance
            .ref('$rtdbUserPath/hubs/${hub.serialNumber}')
            .update({'assigned': false, 'ownerId': null, 'user_email': null});

        // 2. Delete hub metadata from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(hub.serialNumber)
            .delete();

        // 3. Notify the service about hub removal (broadcasts to all pages)
        _realtimeDbService.notifyHubRemoved(hub.serialNumber!);
        print('[_deleteHubDialog] Notified hub removal for: ${hub.serialNumber}');

        // Track device removed notification
        if (mounted) {
          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
          await notificationProvider.trackDeviceRemoved(hub.name);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${hub.name} has been unlinked from all pages."),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );

        // 4. Optimistic UI update
        setState(() {
          _groupedDevices.remove(hub.serialNumber);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Cannot unlink hub without a serial number.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  StreamSubscription<List<String>>? _activeHubSubscription;

  void _setActiveHub(String serialNumber) {
    // Set this hub as the primary one for analytics across the app
    _realtimeDbService.setPrimaryHub(serialNumber);

    // First, stop all currently active streams
    _realtimeDbService.stopAllRealtimeDataStreams();
    // Then, start the stream for the newly selected hub.
    // The startRealtimeDataStream now adds to the active list,
    // so this effectively makes it the *only* active one after stopping all.
    _realtimeDbService.startRealtimeDataStream(serialNumber);
    debugPrint('ExploreScreen: Set "$serialNumber" as active hub for analytics.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Set "$serialNumber" as active hub for analytics.'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    // Show loading indicator during initial load to prevent showing stale state
    if (_isInitializing) {
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
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                      Expanded(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: ListView(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 8 : 12,
                              ),
                              children: [
                                // Removed redundant 'Devices' title
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                // Modern Header with Icon - Matching Analytics Style
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 10 : 12,
                                  ),
                                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context).colorScheme.surface,
                                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context).colorScheme.primary,
                                              Theme.of(context).colorScheme.secondary,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: Colors.white,
                                          size: isSmallScreen ? 18 : 22,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 10 : 12),
                                      Text(
                                        'Add Central Hub',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontSize: isSmallScreen ? 16 : 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Modern Search Container
                                Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 4),
                                        spreadRadius: -2,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _serialNumberController,
                                          decoration: InputDecoration(
                                            hintText: 'Enter hub serial number...',
                                            hintStyle: TextStyle(
                                              fontSize: isSmallScreen ? 13 : 15,
                                              color: Colors.grey.shade400,
                                            ),
                                            prefixIcon: Container(
                                              margin: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.qr_code_scanner_rounded,
                                                color: Theme.of(context).colorScheme.primary,
                                                size: isSmallScreen ? 20 : 24,
                                              ),
                                            ),
                                            filled: false,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isSmallScreen ? 12 : 16,
                                              vertical: isSmallScreen ? 14 : 16,
                                            ),
                                          ),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 13 : 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: ElevatedButton(
                                          onPressed: _searchSerialNumber,
                                          style: ElevatedButton.styleFrom(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSmallScreen ? 16 : 24,
                                              vertical: isSmallScreen ? 14 : 16,
                                            ),
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.link_rounded,
                                                size: isSmallScreen ? 18 : 20,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Link',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 13 : 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 16 : 20),

                                // Connected Devices Header - Matching Analytics Style
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 12 : 16,
                                    vertical: isSmallScreen ? 10 : 12,
                                  ),
                                  margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Theme.of(context).colorScheme.surface,
                                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context).colorScheme.secondary,
                                              Theme.of(context).colorScheme.primary,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.devices_rounded,
                                          color: Colors.white,
                                          size: isSmallScreen ? 18 : 22,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 10 : 12),
                                      Text(
                                        'Connected Devices',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontSize: isSmallScreen ? 16 : 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
            
                                // Separate sections per hub
                                if (_groupedDevices.containsKey('generic'))
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Generic Devices',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ..._groupedDevices['generic']!.map((device) {
                                        return _buildGenericDeviceCard(
                                          device,
                                          isSmallScreen,
                                        );
                                      }),
                                      const SizedBox(height: 24),
                                    ],
                                  ),

                                // Display each hub in its own section
                                ..._groupedDevices.entries.where((entry) => entry.key != 'generic').map((entry) {
                                  final serialNumber = entry.key;
                                  final devices = entry.value;

                                  // Get hub and plugs
                                  final hub = devices.firstWhere(
                                    (d) => d.plug == null,
                                    orElse: () => devices.first,
                                  );
                                  final plugs = devices.where((d) => d.plug != null).toList();

                                  // Calculate aggregated values for all plugs under this hub
                                  double totalEnergy = 0.0;
                                  double totalPower = 0.0;
                                  int activePlugs = 0;

                                  for (final plug in plugs) {
                                    if (plug.energy != null) totalEnergy += plug.energy!;
                                    if (plug.power != null) totalPower += plug.power!;
                                    if (plug.current != null ||
                                        plug.energy != null ||
                                        plug.power != null ||
                                        plug.voltage != null) {
                                      activePlugs++;
                                    }
                                  }

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Hub Section Header - Modern Design with Status-Based Colors
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                                        margin: EdgeInsets.only(
                                          bottom: isSmallScreen ? 10 : 14,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Theme.of(context).colorScheme.surface,
                                              // Status-based transparent green or red
                                              (hub.ssr_state ?? false)
                                                  ? Colors.green.withValues(alpha: 0.15)
                                                  : Colors.red.withValues(alpha: 0.15),
                                              (hub.ssr_state ?? false)
                                                  ? Colors.green.withValues(alpha: 0.08)
                                                  : Colors.red.withValues(alpha: 0.08),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: (hub.ssr_state ?? false)
                                                ? Colors.green.withValues(alpha: 0.3)
                                                : Colors.red.withValues(alpha: 0.3),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (hub.ssr_state ?? false)
                                                  ? Colors.green.withValues(alpha: 0.15)
                                                  : Colors.red.withValues(alpha: 0.15),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                              spreadRadius: -5,
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                // Modern Icon with background
                                                Container(
                                                  padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        Theme.of(context).colorScheme.primary,
                                                        Theme.of(context).colorScheme.secondary,
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                        blurRadius: 12,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Icon(
                                                    Icons.router_rounded,
                                                    size: isSmallScreen ? 22 : 28,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: isSmallScreen ? 12 : 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        hub.nickname != null && hub.nickname!.isNotEmpty
                                                            ? hub.nickname!
                                                            : 'Central Hub',
                                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                          fontSize: isSmallScreen ? 18 : 22,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Serial: $serialNumber',
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: Colors.grey[600],
                                                          fontSize: isSmallScreen ? 11 : 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Modern Status Badge
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 300),
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: isSmallScreen ? 10 : 14,
                                                    vertical: isSmallScreen ? 6 : 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: (hub.ssr_state ?? false)
                                                          ? [Colors.green.shade400, Colors.green.shade600]
                                                          : [Colors.red.shade400, Colors.red.shade600],
                                                    ),
                                                    borderRadius: BorderRadius.circular(25),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: (hub.ssr_state ?? false)
                                                            ? Colors.green.withOpacity(0.4)
                                                            : Colors.red.withOpacity(0.4),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: isSmallScreen ? 6 : 8,
                                                        height: isSmallScreen ? 6 : 8,
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          shape: BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.white.withOpacity(0.5),
                                                              blurRadius: 4,
                                                              spreadRadius: 1,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      SizedBox(width: isSmallScreen ? 4 : 6),
                                                      Text(
                                                        (hub.ssr_state ?? false) ? 'ACTIVE' : 'OFFLINE',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: isSmallScreen ? 10 : 12,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: isSmallScreen ? 8 : 12),
                                            // SSR State Snapshot Display
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen ? 10 : 12,
                                                vertical: isSmallScreen ? 6 : 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: (hub.ssr_state ?? false)
                                                    ? Colors.green.withValues(alpha: 0.15)
                                                    : Colors.grey.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: (hub.ssr_state ?? false)
                                                      ? Colors.green.withValues(alpha: 0.4)
                                                      : Colors.grey.withValues(alpha: 0.4),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.info_outline_rounded,
                                                    size: isSmallScreen ? 14 : 16,
                                                    color: (hub.ssr_state ?? false)
                                                        ? Colors.green.shade700
                                                        : Colors.grey.shade700,
                                                  ),
                                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                                  Text(
                                                    'SSR State: ${hub.ssr_state ?? false ? "ON" : "OFF"}',
                                                    style: TextStyle(
                                                      fontSize: isSmallScreen ? 11 : 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: (hub.ssr_state ?? false)
                                                          ? Colors.green.shade800
                                                          : Colors.grey.shade800,
                                                    ),
                                                  ),
                                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: isSmallScreen ? 6 : 8,
                                                      vertical: isSmallScreen ? 2 : 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: (hub.ssr_state ?? false)
                                                          ? Colors.green.shade700
                                                          : Colors.grey.shade600,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      hub.ssr_state ?? false ? 'true' : 'false',
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 9 : 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: isSmallScreen ? 8 : 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Connected Plugs: ${plugs.length}',
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          fontSize: isSmallScreen ? 13 : 15,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // Show inactive message when hub is off
                                                      if (!(hub.ssr_state ?? false)) ...[
                                                        Container(
                                                          padding: EdgeInsets.symmetric(
                                                            horizontal: isSmallScreen ? 8 : 10,
                                                            vertical: isSmallScreen ? 4 : 6,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.withValues(alpha: 0.1),
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(
                                                              color: Colors.red.withValues(alpha: 0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                Icons.power_off_rounded,
                                                                size: isSmallScreen ? 12 : 14,
                                                                color: Colors.red.shade700,
                                                              ),
                                                              SizedBox(width: isSmallScreen ? 4 : 6),
                                                              Text(
                                                                'Hub Inactive - No Data',
                                                                style: TextStyle(
                                                                  fontSize: isSmallScreen ? 10 : 12,
                                                                  color: Colors.red.shade700,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ] else if (activePlugs > 0) ...[
                                                        Text(
                                                          'Total Power: ${totalPower.toStringAsFixed(2)} W',
                                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            fontSize: isSmallScreen ? 11 : 13,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Total Energy: ${totalEnergy.toStringAsFixed(2)} kWh',
                                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            fontSize: isSmallScreen ? 11 : 13,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Total Cost: $_currencySymbol${(totalEnergy * _pricePerKWH).toStringAsFixed(2)}',
                                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                            fontSize: isSmallScreen ? 11 : 13,
                                                            fontWeight: FontWeight.bold,
                                                            color: Theme.of(context).colorScheme.secondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // Edit Button - Modern Style
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(12),
                                                        onTap: () => _editNicknameDialog(hub),
                                                        child: Container(
                                                          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.shade50,
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Icon(
                                                            Icons.edit_rounded,
                                                            color: Colors.blue.shade600,
                                                            size: isSmallScreen ? 18 : 22,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: isSmallScreen ? 6 : 8),
                                                    // Unlink Button - Modern Style
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(12),
                                                        onTap: () => _deleteHubDialog(hub),
                                                        child: Container(
                                                          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red.shade50,
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Icon(
                                                            Icons.link_off_rounded,
                                                            color: Colors.red.shade600,
                                                            size: isSmallScreen ? 18 : 22,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: isSmallScreen ? 6 : 8),
                                                    // Toggle Button - Animated
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        borderRadius: BorderRadius.circular(25),
                                                        onTap: () => _toggleHubSsrState(hub),
                                                        child: AnimatedContainer(
                                                          duration: const Duration(milliseconds: 300),
                                                          padding: EdgeInsets.symmetric(
                                                            horizontal: isSmallScreen ? 12 : 16,
                                                            vertical: isSmallScreen ? 8 : 10,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              colors: (hub.ssr_state ?? false)
                                                                  ? [Colors.green.shade400, Colors.green.shade600]
                                                                  : [Colors.grey.shade300, Colors.grey.shade500],
                                                            ),
                                                            borderRadius: BorderRadius.circular(25),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: (hub.ssr_state ?? false)
                                                                    ? Colors.green.withOpacity(0.3)
                                                                    : Colors.grey.withOpacity(0.2),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 3),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(
                                                                (hub.ssr_state ?? false)
                                                                    ? Icons.power_settings_new_rounded
                                                                    : Icons.power_off_rounded,
                                                                color: Colors.white,
                                                                size: isSmallScreen ? 16 : 20,
                                                              ),
                                                              SizedBox(width: isSmallScreen ? 4 : 6),
                                                              Text(
                                                                (hub.ssr_state ?? false) ? 'ON' : 'OFF',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: isSmallScreen ? 11 : 13,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Plugs under this hub
                                      if (plugs.isNotEmpty)
                                        ...plugs.map((plug) {
                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            margin: EdgeInsets.only(
                                              bottom: isSmallScreen ? 8 : 12,
                                              left: isSmallScreen ? 8 : 16,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Theme.of(context).colorScheme.surface,
                                                  // Status-based transparent green or red for plugs
                                                  (plug.ssr_state ?? false)
                                                      ? Colors.green.withValues(alpha: 0.1)
                                                      : Colors.red.withValues(alpha: 0.1),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: (plug.ssr_state ?? false)
                                                    ? Colors.green.withValues(alpha: 0.2)
                                                    : Colors.red.withValues(alpha: 0.2),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                                BoxShadow(
                                                  color: (plug.ssr_state ?? false)
                                                      ? Colors.green.withValues(alpha: 0.1)
                                                      : Colors.red.withValues(alpha: 0.1),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: _buildPlugDeviceRow(plug, isSmallScreen, hub.ssr_state ?? false),
                                          );
                                        })
                                      else
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left: isSmallScreen ? 8 : 16,
                                            bottom: isSmallScreen ? 8 : 12,
                                          ),
                                          child: Text(
                                            'No plugs connected to this hub',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey,
                                              fontSize: isSmallScreen ? 13 : 15,
                                            ),
                                          ),
                                        ),

                                      SizedBox(height: isSmallScreen ? 16 : 24),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),          ],
        ),
      ),
    );
  }
}
