import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart'; // Import for Realtime Database
import 'dart:async'; // Import for StreamSubscription

import '../realtime_db_service.dart';
import '../theme_provider.dart';
import 'login.dart';
import 'profile.dart';

// ------------------ DEVICE MODEL ------------------
class DeviceModel {
  String id;
  String name;
  String status;
  double power;
  double voltage;
  double current;
  double energy;
  String? createdAt;
  String? userEmail;

  DeviceModel({
    required this.id,
    required this.name,
    required this.status,
    this.power = 0.0,
    this.voltage = 0.0,
    this.current = 0.0,
    this.energy = 0.0,
    this.createdAt,
    this.userEmail,
  });

  factory DeviceModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return DeviceModel(
      id: id,
      name: map['name'] ?? 'N/A',
      status: map['status'] ?? 'N/A',
      power: (map['power'] as num?)?.toDouble() ?? 0.0,
      voltage: (map['voltage'] as num?)?.toDouble() ?? 0.0,
      current: (map['current'] as num?)?.toDouble() ?? 0.0,
      energy: (map['energy'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ------------------ USER MODEL ------------------
class UserModel {
  String uid;
  String name;
  String email;
  String status;
  String dateRegistered;
  String address;
  List<DeviceModel> devices; // New field for devices

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.dateRegistered,
    required this.address,
    this.devices = const [], // Initialize with an empty list
  });
}

// ------------------ ADMIN SCREEN ------------------
class MyAdminScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService; // New: Add RealtimeDbService
  const MyAdminScreen({super.key, required this.realtimeDbService});

  @override
  State<MyAdminScreen> createState() => _MyAdminScreenState();
}

class _MyAdminScreenState extends State<MyAdminScreen> {
  List<UserModel> users = [];
  List<UserModel> allUsers = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _centralHubSearchController = TextEditingController(); // New search controller for central hub devices
  bool _isCentralHubPaused = false; // New state variable
  final DatabaseReference _centralHubStatusRef = FirebaseDatabase.instance
      .ref()
      .child('central_hub/data_reception_paused'); // New database reference
  StreamSubscription? _centralHubStatusSubscription; // New stream subscription
  StreamSubscription? _deviceDataSubscription; // For device data by serial number
  StreamSubscription? _centralHubsSubscription; // For all central hub devices

  String _currentHubSerialNumber =
      "default_hub_serial"; // Placeholder, needs to be dynamic
  late RealtimeDbService _realtimeDbService;

  // Selected device info
  Map<String, dynamic>? _selectedDeviceData;
  UserModel? _selectedDeviceOwner;

  // Central hub devices data
  Map<String, Map<String, dynamic>> _centralHubDevices = {};

  @override
  void initState() {
    super.initState();
    _realtimeDbService = widget.realtimeDbService;
    _fetchUsers();
    _listenToCentralHubStatus(); // Listen to central hub status on init
    _listenToCentralHubDevices(); // Listen to all central hub devices
  }

  @override
  void dispose() {
    _centralHubStatusSubscription?.cancel(); // Cancel subscription
    _deviceDataSubscription?.cancel(); // Cancel device data subscription
    _centralHubsSubscription?.cancel(); // Cancel central hubs subscription
    _searchController.dispose();
    _serialNumberController.dispose();
    _centralHubSearchController.dispose(); // Dispose central hub search controller
    super.dispose();
  }

  // --------------------------------------------------
  // LISTEN TO CENTRAL HUB STATUS
  // --------------------------------------------------
  void _listenToCentralHubStatus() {
    _centralHubStatusSubscription = _centralHubStatusRef.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value is bool) {
          setState(() {
            _isCentralHubPaused = event.snapshot.value as bool;
          });
        } else {
          // If no status exists, set a default in the database
          _centralHubStatusRef.set(false);
          setState(() {
            _isCentralHubPaused = false;
          });
        }
      },
      onError: (error) {
        print("Error listening to central hub status: $error");
      },
    );
  }

  // --------------------------------------------------
  // LISTEN TO ALL CENTRAL HUB DEVICES
  // --------------------------------------------------
  void _listenToCentralHubDevices() {
    // Listen to users/espthesisbmn/hubs for all central hub devices
    final centralHubsRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child('espthesisbmn')
        .child('hubs');

    _centralHubsSubscription = centralHubsRef.onValue.listen(
      (event) {
        if (event.snapshot.exists && event.snapshot.value is Map) {
          final hubs = event.snapshot.value as Map<dynamic, dynamic>;

          setState(() {
            _centralHubDevices.clear();
            hubs.forEach((serialNumber, hubData) {
              if (hubData is Map) {
                _centralHubDevices[serialNumber.toString()] =
                    Map<String, dynamic>.from(hubData as Map);
              }
            });
          });

          print("Central hub devices updated: ${_centralHubDevices.length} hubs found");
        } else {
          setState(() {
            _centralHubDevices.clear();
          });
          print("No central hub devices found");
        }
      },
      onError: (error) {
        print("Error listening to central hub devices: $error");
      },
    );
  }

  // --------------------------------------------------
  // FETCH USERS
  // --------------------------------------------------
  Future<void> _fetchUsers() async {
    print('Fetching users from Firestore...');
    // EFFICIENCY FIX: Add pagination limit to avoid loading all users at once
    // This prevents excessive bandwidth usage on free tier
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(50) // Load only 50 users at a time
        .get();
    print('Fetched ${snapshot.docs.length} documents.');

    final fetchedUsers = await Future.wait(
      snapshot.docs.map((doc) async {
        final data = doc.data();
        final userEmail = data['email'] ?? 'N/A';

        List<DeviceModel> userDevices = [];

        // Fetch devices from Firestore subcollection: users/{userId}/devices
        try {
          final devicesSnapshot = await doc.reference
              .collection('devices')
              .get();

          for (var deviceDoc in devicesSnapshot.docs) {
            final deviceData = deviceDoc.data();

            // Extract createdAt timestamp
            String createdAtStr = 'N/A';
            if (deviceData.containsKey('createdAt')) {
              final createdAt = deviceData['createdAt'];
              if (createdAt is Timestamp) {
                createdAtStr = DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate());
              } else if (createdAt != null) {
                createdAtStr = createdAt.toString();
              }
            }

            userDevices.add(DeviceModel(
              id: deviceData['serialNumber']?.toString() ?? deviceDoc.id,
              name: deviceData['name']?.toString() ?? 'Unknown Device',
              status: 'Active', // Default status
              createdAt: createdAtStr,
              userEmail: deviceData['user_email']?.toString() ?? userEmail,
            ));
          }
        } catch (e) {
          print('Error fetching devices for user ${doc.id}: $e');
        }

        return UserModel(
          uid: doc.id,
          name: data['displayName'] ?? 'N/A',
          email: userEmail,
          status: data['status'] ?? 'Active',
          dateRegistered: data['createdAt'] != null
              ? DateFormat(
                  'yyyy-MM-dd',
                ).format((data['createdAt'] as Timestamp).toDate())
              : 'N/A',
          address: data['address'] ?? 'N/A',
          devices: userDevices,
        );
      }).toList(),
    );
    print('Mapped ${fetchedUsers.length} users.');

    setState(() {
      users = fetchedUsers;
      allUsers = List.from(fetchedUsers);
    });
    print('Users list updated. Total users: ${users.length}');
  }

  // --------------------------------------------------
  // SEARCH USERS
  // --------------------------------------------------
  void _applySearch(String query) {
    setState(() {
      if (query.isEmpty) {
        users = List.from(allUsers);
      } else {
        users = allUsers
            .where(
              (u) =>
                  u.name.toLowerCase().contains(query.toLowerCase()) ||
                  u.email.toLowerCase().contains(query.toLowerCase()) ||
                  u.address.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  // --------------------------------------------------
  // ADD USER
  // --------------------------------------------------
  void _addUser() {
    TextEditingController nameController = TextEditingController();
    TextEditingController emailController = TextEditingController();
    TextEditingController addressController = TextEditingController();
    TextEditingController passwordController = TextEditingController();

    String statusValue = "Active";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
        title: Text("Add User", style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Enter full name",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextField(
              controller: emailController,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Enter email",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextField(
              controller: passwordController,
              style: Theme.of(context).textTheme.bodyMedium,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Enter password",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextField(
              controller: addressController,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Enter address",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              dropdownColor: Theme.of(context).primaryColor.withOpacity(0.8),
              initialValue: statusValue,
              items: ["Active", "Inactive"]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) statusValue = val;
              },
              decoration: InputDecoration(
                labelText: "Select Status",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            onPressed: () async {
              try {
                final auth = FirebaseAuth.instance;
                final userCredential = await auth
                    .createUserWithEmailAndPassword(
                      email: emailController.text,
                      password: passwordController.text,
                    );

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userCredential.user!.uid)
                    .set({
                      'displayName': nameController.text,
                      'email': emailController.text,
                      'address': addressController.text,
                      'status': statusValue,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                if (!mounted) return;
                Navigator.pop(ctx);
                _fetchUsers();
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message ?? 'Failed to create user.'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(ctx); // Pop the dialog on error
              } on FirebaseException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message ?? 'Failed to store user data.'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(ctx); // Pop the dialog on error
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'An unexpected error occurred: ${e.toString()}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(ctx); // Pop the dialog on error
              }
            },
            child: Text(
              "Add",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // EDIT USER
  // --------------------------------------------------
  void _editUser(int index) {
    final nameController = TextEditingController(text: users[index].name);
    final emailController = TextEditingController(text: users[index].email);
    final addressController = TextEditingController(text: users[index].address);

    String statusValue = users[index].status;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
        title: Text("Edit User", style: Theme.of(context).textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Update full name",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextField(
              controller: emailController,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Update email",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            TextField(
              controller: addressController,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: "Update address",
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              dropdownColor: Theme.of(context).primaryColor.withOpacity(0.8),
              initialValue: statusValue,
              items: ["Active", "Inactive"]
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) statusValue = val;
              },
              decoration: InputDecoration(
                labelText: "Update Status",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(users[index].uid)
                  .update({
                    'displayName': nameController.text,
                    'email': emailController.text,
                    'address': addressController.text,
                    'status': statusValue,
                  });

              if (!mounted) return;
              Navigator.pop(ctx);
              _fetchUsers();
            },
            child: Text(
              "Save",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // DELETE USER
  // --------------------------------------------------
  Future<void> _deleteUser(int index) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(users[index].uid)
        .delete();

    _fetchUsers();
  }

  // --------------------------------------------------
  // TOGGLE CENTRAL HUB STATUS
  // --------------------------------------------------
  Future<void> _toggleCentralHubStatus(bool newValue) async {
    setState(() {
      _isCentralHubPaused = newValue;
    });
    await _centralHubStatusRef.set(newValue);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newValue
              ? 'Central Hub data reception paused.'
              : 'Central Hub data reception resumed.',
        ),
        backgroundColor: newValue ? Colors.orange : Colors.green,
      ),
    );
  }

  // --------------------------------------------------
  // SEARCH BY SERIAL NUMBER
  // --------------------------------------------------
  Future<void> _searchBySerialNumber(String serialNumber) async {
    if (serialNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a serial number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _selectedDeviceData = null;
      _selectedDeviceOwner = null;
    });

    // Cancel existing subscription
    _deviceDataSubscription?.cancel();

    try {
      // Search across all users' device subcollections
      // Since devices are stored as subcollections under users/{userId}/devices/{serialNumber}
      // We need to iterate through all users and check their devices subcollection

      Map<String, dynamic>? deviceMetadata;
      String? deviceUserId;

      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Search through each user's devices subcollection
      for (var userDoc in usersSnapshot.docs) {
        final devicesSnapshot = await userDoc.reference
            .collection('devices')
            .where('serialNumber', isEqualTo: serialNumber)
            .limit(1)
            .get();

        if (devicesSnapshot.docs.isNotEmpty) {
          deviceMetadata = devicesSnapshot.docs.first.data();
          deviceUserId = userDoc.id;
          break;
        }
      }

      if (deviceMetadata == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device not found in the system'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user email from device metadata
      final userEmail = deviceMetadata['user_email'] as String?;

      if (userEmail == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device not assigned to any user'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Find the user in our allUsers list
      UserModel? owner = allUsers.firstWhere(
        (user) => user.email == userEmail,
        orElse: () => UserModel(
          uid: 'unknown',
          name: 'Unknown User',
          email: userEmail,
          status: 'Unknown',
          dateRegistered: 'N/A',
          address: 'N/A',
        ),
      );

      // Set up realtime listener for the centralized hub data
      // Path: hubs/{serialNumber}
      final hubRef = FirebaseDatabase.instance
          .ref()
          .child('hubs')
          .child(serialNumber);

      _deviceDataSubscription = hubRef.onValue.listen((event) {
        if (event.snapshot.exists && event.snapshot.value is Map) {
          final hubData = Map<String, dynamic>.from(
            event.snapshot.value as Map,
          );

          // Merge Firestore metadata with Realtime Database data
          setState(() {
            _selectedDeviceData = {
              ...?deviceMetadata, // Use null-aware spread
              ...hubData,
            };
            _selectedDeviceOwner = owner;
          });
        } else {
          // If no real-time data exists yet, just use Firestore metadata
          setState(() {
            _selectedDeviceData = deviceMetadata;
            _selectedDeviceOwner = owner;
          });
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device found! Owner: ${owner.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching device: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(themeNotifier),
            const SizedBox(height: 16),
            _buildSerialNumberSearch(), // Add serial number search
            const SizedBox(height: 16),
            if (_selectedDeviceData != null && _selectedDeviceOwner != null)
              _buildDeviceInfoCard(), // Display device info if found
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildCentralHubDevicesTable(), // Add central hub devices table
                    const SizedBox(height: 16),
                    _buildTableContainer(), // Users table
                    const SizedBox(height: 16),
                    _buildPlugsSection(), // Add the plugs section here
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _buildSerialNumberSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _serialNumberController,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: "Enter device serial number...",
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).primaryColor.withOpacity(0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) => _searchBySerialNumber(value),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _searchBySerialNumber(_serialNumberController.text),
              child: Text(
                "Search",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    final owner = _selectedDeviceOwner!;
    final deviceData = _selectedDeviceData!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Device Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedDeviceData = null;
                      _selectedDeviceOwner = null;
                      _serialNumberController.clear();
                    });
                    _deviceDataSubscription?.cancel();
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white54),
            const SizedBox(height: 8),
            Text(
              'Owner Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Name', owner.name),
            _buildInfoRow('Email', owner.email),
            _buildInfoRow('Address', owner.address),
            _buildInfoRow('Status', owner.status),
            _buildInfoRow('Date Registered', owner.dateRegistered),
            const SizedBox(height: 16),
            Text(
              'Device Details (Firestore Metadata)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              'Serial Number',
              deviceData['serialNumber']?.toString() ?? _serialNumberController.text,
            ),
            _buildInfoRow(
              'Device Name',
              deviceData['name']?.toString() ?? 'N/A',
            ),
            if (deviceData.containsKey('createdAt'))
              _buildInfoRow(
                'Created At',
                deviceData['createdAt']?.toString() ?? 'N/A',
              ),
            const SizedBox(height: 16),
            Text(
              'Real-time Hub Data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            if (deviceData.containsKey('aggregations'))
              _buildInfoRow(
                'Has Aggregations',
                'Yes',
              )
            else
              _buildInfoRow(
                'Has Aggregations',
                'No data yet',
              ),
            const SizedBox(height: 16),
            if (deviceData.containsKey('plugs'))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connected Plugs (Real-time)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPlugsList(deviceData['plugs'] as Map<dynamic, dynamic>),
                ],
              )
            else
              Text(
                'No plugs data available yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 16),
            // Display aggregations summary if available
            if (deviceData.containsKey('aggregations'))
              _buildAggregationsSummary(deviceData['aggregations'] as Map<dynamic, dynamic>),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlugsList(Map<dynamic, dynamic> plugs) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plugs.length,
      itemBuilder: (context, index) {
        final plugId = plugs.keys.elementAt(index);
        final plugData = plugs[plugId] as Map<dynamic, dynamic>;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: Theme.of(context).primaryColor.withOpacity(0.6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plugData['name']?.toString() ?? 'Unnamed Plug',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${plugData['status'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Power: ${plugData['power'] ?? 0} W',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Voltage: ${plugData['voltage'] ?? 0} V',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Current: ${plugData['current'] ?? 0} A',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Energy: ${plugData['energy'] ?? 0} kWh',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAggregationsSummary(Map<dynamic, dynamic> aggregations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aggregations Summary',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 8),
        if (aggregations.containsKey('daily'))
          _buildAggregationTypeCard('Daily', aggregations['daily'] as Map<dynamic, dynamic>),
        if (aggregations.containsKey('weekly'))
          _buildAggregationTypeCard('Weekly', aggregations['weekly'] as Map<dynamic, dynamic>),
        if (aggregations.containsKey('monthly'))
          _buildAggregationTypeCard('Monthly', aggregations['monthly'] as Map<dynamic, dynamic>),
      ],
    );
  }

  Widget _buildAggregationTypeCard(String type, Map<dynamic, dynamic> data) {
    final recordCount = data.length;
    final latestKey = data.keys.isNotEmpty ? data.keys.last.toString() : 'N/A';

    // Get latest record if available
    dynamic latestData = data.isNotEmpty ? data[data.keys.last] : null;
    String? avgPower;
    String? totalEnergy;

    if (latestData is Map) {
      avgPower = latestData['average_power']?.toString() ??
                 latestData['average_power_w']?.toString();
      totalEnergy = latestData['total_energy']?.toString();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Theme.of(context).primaryColor.withOpacity(0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$type Aggregation',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Records: $recordCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Latest Period: $latestKey',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (avgPower != null)
              Text(
                'Latest Avg Power: ${double.parse(avgPower).toStringAsFixed(2)} W',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (totalEnergy != null)
              Text(
                'Latest Total Energy: ${double.parse(totalEnergy).toStringAsFixed(3)} kWh',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeNotifier themeNotifier) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.admin_panel_settings),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Admin Monitoring List',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.notifications), onPressed: () {}),
          IconButton(
            icon: Icon(
              themeNotifier.darkTheme ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'view_profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnergyProfileScreen(
                      realtimeDbService: _realtimeDbService,
                    ),
                  ),
                );
              } else if (value == 'logout') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AuthPage(realtimeDbService: _realtimeDbService),
                  ),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'view_profile', child: Text('View Profile')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  // Get filtered central hub devices based on search
  Map<String, Map<String, dynamic>> _getFilteredCentralHubDevices() {
    final searchQuery = _centralHubSearchController.text.toLowerCase().trim();

    if (searchQuery.isEmpty) {
      return _centralHubDevices;
    }

    return Map.fromEntries(
      _centralHubDevices.entries.where((entry) {
        final serialNumber = entry.key.toLowerCase();
        final hubData = entry.value;
        final ownerId = (hubData['ownerId']?.toString() ?? '').toLowerCase();
        final nickname = (hubData['nickname']?.toString() ?? '').toLowerCase();

        return serialNumber.contains(searchQuery) ||
               ownerId.contains(searchQuery) ||
               nickname.contains(searchQuery);
      }),
    );
  }

  // Build search bar for central hub devices
  Widget _buildCentralHubSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _centralHubSearchController,
        onChanged: (value) {
          setState(() {}); // Trigger rebuild to filter devices
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search by serial number, owner ID, or nickname...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          suffixIcon: _centralHubSearchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _centralHubSearchController.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCentralHubDevicesTable() {
    final filteredDevices = _getFilteredCentralHubDevices();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub,
                color: isDarkMode ? Colors.white : Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Central Hub Devices',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${filteredDevices.length}${_centralHubSearchController.text.isNotEmpty ? ' / ${_centralHubDevices.length}' : ''} Devices',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCentralHubSearchBar(),
          const SizedBox(height: 16),
          if (filteredDevices.isEmpty && _centralHubSearchController.text.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No devices found matching "${_centralHubSearchController.text}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else if (_centralHubDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No central hub devices found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 72,
                  ),
                  child: DataTable(
                    headingRowHeight: 56,
                    dataRowMinHeight: 70,
                    dataRowMaxHeight: 90,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    headingRowColor: WidgetStateProperty.all(
                      isDarkMode
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.grey.shade100,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    dividerThickness: 0.5,
                    columns: [
                      DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Serial Number",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Assigned",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Owner ID",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "SSR State",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Plugs",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Aggregations",
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: filteredDevices.entries.map((entry) {
                      final serialNumber = entry.key;
                      final hubData = entry.value;
                      final textColor = isDarkMode ? Colors.white70 : Colors.black87;
                      final subtleHoverColor = isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade200;

                      final assigned = hubData['assigned']?.toString() ?? 'false';
                      final ownerId = hubData['ownerId']?.toString() ?? 'N/A';
                      final nickname = hubData['nickname']?.toString() ?? '';
                      final ssrState = hubData['ssr_state']?.toString() ?? 'false';

                      // Count plugs and collect plug info (nickname, ID, and real-time data)
                      int plugCount = 0;
                      List<Map<String, dynamic>> plugInfo = [];
                      if (hubData.containsKey('plugs') && hubData['plugs'] is Map) {
                        final plugs = hubData['plugs'] as Map;
                        plugCount = plugs.length;
                        plugs.forEach((key, value) {
                          String plugId = key.toString();
                          String plugNickname = 'Unknown Plug';
                          double power = 0.0;
                          double voltage = 0.0;
                          double current = 0.0;
                          double energy = 0.0;

                          if (value is Map) {
                            // Get nickname from the plug's data
                            if (value.containsKey('nickname')) {
                              plugNickname = value['nickname'].toString();
                            }

                            // Extract real-time sensor data from 'data' field
                            if (value.containsKey('data')) {
                              final data = value['data'];
                              if (data is Map) {
                                // Also check nickname in data field as fallback
                                if (plugNickname == 'Unknown Plug' && data.containsKey('nickname')) {
                                  plugNickname = data['nickname'].toString();
                                }

                                // Extract sensor readings
                                power = (data['power'] as num?)?.toDouble() ?? 0.0;
                                voltage = (data['voltage'] as num?)?.toDouble() ?? 0.0;
                                current = (data['current'] as num?)?.toDouble() ?? 0.0;
                                energy = (data['energy'] as num?)?.toDouble() ?? 0.0;
                              }
                            }
                          }

                          plugInfo.add({
                            'id': plugId,
                            'nickname': plugNickname,
                            'power': power,
                            'voltage': voltage,
                            'current': current,
                            'energy': energy,
                          });
                        });
                      }

                      // Check aggregations
                      String aggregationsInfo = 'None';
                      if (hubData.containsKey('aggregations') && hubData['aggregations'] is Map) {
                        final agg = hubData['aggregations'] as Map;
                        List<String> aggTypes = [];
                        if (agg.containsKey('daily')) aggTypes.add('D');
                        if (agg.containsKey('weekly')) aggTypes.add('W');
                        if (agg.containsKey('monthly')) aggTypes.add('M');
                        aggregationsInfo = aggTypes.isNotEmpty ? aggTypes.join(', ') : 'None';
                      }

                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.hovered)) {
                              return subtleHoverColor;
                            }
                            return null;
                          },
                        ),
                        cells: [
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    serialNumber,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                  if (nickname.isNotEmpty)
                                    Text(
                                      nickname,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: textColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: assigned == 'true'
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: assigned == 'true'
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  assigned,
                                  style: TextStyle(
                                    color: assigned == 'true'
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                ownerId.length > 20
                                    ? '${ownerId.substring(0, 20)}...'
                                    : ownerId,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ssrState == 'true'
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ssrState == 'true'
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  ssrState == 'true' ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: ssrState == 'true'
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                              child: plugCount == 0
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'No plugs',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: plugInfo.map((plug) {
                                        return _PlugCard(
                                          plug: plug,
                                          isDarkMode: isDarkMode,
                                        );
                                      }).toList(),
                                    ),
                            ),
                          ),
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    size: 16,
                                    color: aggregationsInfo != 'None'
                                        ? Colors.amber.shade700
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    aggregationsInfo,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableContainer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Theme.of(context).primaryColor.withOpacity(0.8)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.people,
                color: isDarkMode ? Colors.white : Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Users',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${users.length} Users',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildDataTable(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            onSubmitted: (q) => _applySearch(q),
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: "Search user...",
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).iconTheme.color?.withOpacity(0.8),
              ),
              filled: true,
              fillColor: Theme.of(context).primaryColor.withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _applySearch(_searchController.text),
          child: Text(
            "Enter",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 72, // Full width minus margins
          ),
          child: DataTable(
            headingRowHeight: 56,
            dataRowMinHeight: 70,
            dataRowMaxHeight: 90,
            columnSpacing: 24,
            horizontalMargin: 16,
            headingRowColor: WidgetStateProperty.all(
              isDarkMode
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.shade100,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            dividerThickness: 0.5,
          columns: [
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Name",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Email",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Address",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Status",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Date Registered",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Devices",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Actions",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          rows: List.generate(users.length, (index) {
            final user = users[index];
            final textColor = isDarkMode ? Colors.white70 : Colors.black87;
            final subtleHoverColor = isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade200;

            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.hovered)) {
                    return subtleHoverColor;
                  }
                  return null;
                },
              ),
              cells: [
                DataCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            user.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: user.status == "Active"
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: user.status == "Active"
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        user.status,
                        style: TextStyle(
                          color: user.status == "Active"
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          user.dateRegistered,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                    child: user.devices.isEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'No devices',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: user.devices.map((device) {
                              String deviceText = '${device.name} (${device.id})';
                              if (device.createdAt != null && device.createdAt != 'N/A') {
                                deviceText += ' - ${device.createdAt}';
                              }
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.purpleAccent.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.devices,
                                      size: 14,
                                      color: Colors.purpleAccent,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        deviceText,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blueAccent,
                              size: 20,
                            ),
                            tooltip: 'Edit User',
                            onPressed: () => _editUser(index),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: 'Delete User',
                            onPressed: () => _deleteUser(index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          ),
        ),
      ),
    );
  }

  Widget _buildPlugsSection() {
    // Construct the correct database reference for plugs under the hardcoded user's default hub
    final dbRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(
          'espthesisbmn_at_gmail_com',
        ) // Hardcoded email as per user's request
        .child('hubs')
        .child(_currentHubSerialNumber) // Using the placeholder serial number
        .child('plugs');

    return Padding(
      padding: const EdgeInsets.all(16.0),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.8),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Live Energy Consumption (Plugs)',

              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'Pause Data Reception',

                  style: Theme.of(context).textTheme.titleMedium,
                ),

                Switch(
                  value: _isCentralHubPaused,

                  onChanged: (value) {
                    _toggleCentralHubStatus(value);
                  },

                  activeColor: Colors.greenAccent,

                  inactiveThumbColor: Colors.redAccent,

                  inactiveTrackColor: Colors.redAccent.withOpacity(0.5),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 400, // Fixed height for the plugs list
              child: StreamBuilder(
                stream: dbRef.onValue,
                builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const Center(child: Text('No data available'));
                  } else {
                    final data = snapshot.data!.snapshot.value;
                    if (data is Map<dynamic, dynamic>) {
                      final plugs = <String, dynamic>{};
                      data.forEach((key, value) {
                        plugs[key] = value;
                      });

                      return ListView.builder(
                        itemCount: plugs.length,
                        itemBuilder: (context, index) {
                          final plugId = plugs.keys.elementAt(index);
                          final plugData = plugs[plugId];

                          return Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.8),
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plugData['name'] ?? 'N/A',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Status: ${plugData['status'] ?? 'N/A'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Power: ${plugData['power'] ?? 0} W',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Voltage: ${plugData['voltage'] ?? 0} V',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Current: ${plugData['current'] ?? 0} A',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    'Energy: ${plugData['energy'] ?? 0} kWh',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    } else {
                      return const Center(child: Text('Invalid data format'));
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stateful widget for plug card with hover effect
class _PlugCard extends StatefulWidget {
  final Map<String, dynamic> plug;
  final bool isDarkMode;

  const _PlugCard({
    required this.plug,
    required this.isDarkMode,
  });

  @override
  State<_PlugCard> createState() => _PlugCardState();
}

class _PlugCardState extends State<_PlugCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovered
              ? Colors.purple.withValues(alpha: 0.25)
              : Colors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? Colors.purpleAccent.withValues(alpha: 0.8)
                : Colors.purpleAccent.withValues(alpha: 0.5),
            width: _isHovered ? 2.0 : 1.5,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon and nickname
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.power,
                  size: 16,
                  color: _isHovered ? Colors.purpleAccent.shade100 : Colors.purpleAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.plug['nickname'] as String,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Plug ID
            Text(
              widget.plug['id'] as String,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: (widget.isDarkMode ? Colors.white : Colors.black87)
                    .withValues(alpha: 0.6),
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
            // Real-time data (only shown on hover)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isHovered
                  ? Column(
                      children: [
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, size: 10, color: Colors.amber.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(widget.plug['power'] as double).toStringAsFixed(2)} W',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.electric_bolt, size: 10, color: Colors.blue.shade400),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(widget.plug['voltage'] as double).toStringAsFixed(1)} V',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.trending_up, size: 10, color: Colors.orange.shade400),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(widget.plug['current'] as double).toStringAsFixed(3)} A',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.power_settings_new, size: 10, color: Colors.green.shade400),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(widget.plug['energy'] as double).toStringAsFixed(3)} kWh',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: widget.isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
