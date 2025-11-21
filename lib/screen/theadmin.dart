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

  DeviceModel({
    required this.id,
    required this.name,
    required this.status,
    this.power = 0.0,
    this.voltage = 0.0,
    this.current = 0.0,
    this.energy = 0.0,
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
  bool _isCentralHubPaused = false; // New state variable
  final DatabaseReference _centralHubStatusRef = FirebaseDatabase.instance
      .ref()
      .child('central_hub/data_reception_paused'); // New database reference
  StreamSubscription? _centralHubStatusSubscription; // New stream subscription

  String _currentHubSerialNumber =
      "default_hub_serial"; // Placeholder, needs to be dynamic
  late RealtimeDbService _realtimeDbService;

  @override
  void initState() {
    super.initState();
    _realtimeDbService = widget.realtimeDbService;
    _fetchUsers();
    _listenToCentralHubStatus(); // Listen to central hub status on init
  }

  @override
  void dispose() {
    _centralHubStatusSubscription?.cancel(); // Cancel subscription
    _searchController.dispose();
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
        final String safeUserEmail = userEmail.replaceAll(
          '.',
          ',',
        ); // Firebase RTDB key cannot contain '.'

        List<DeviceModel> userDevices = [];
        if (userEmail != 'N/A') {
          final hubRef = FirebaseDatabase.instance
              .ref()
              .child('users')
              .child(safeUserEmail)
              .child('hubs');
          final hubSnapshot = await hubRef.get();

          if (hubSnapshot.exists &&
              hubSnapshot.value is Map<dynamic, dynamic>) {
            final hubs = hubSnapshot.value as Map<dynamic, dynamic>;
            for (var hubEntry in hubs.entries) {
              if (hubEntry.value is Map<dynamic, dynamic>) {
                final hubData = hubEntry.value as Map<dynamic, dynamic>;
                if (hubData.containsKey('plugs') &&
                    hubData['plugs'] is Map<dynamic, dynamic>) {
                  final plugs = hubData['plugs'] as Map<dynamic, dynamic>;
                  plugs.forEach((plugId, plugData) {
                    if (plugData is Map<dynamic, dynamic>) {
                      userDevices.add(DeviceModel.fromMap(plugId, plugData));
                    }
                  });
                }
              }
            }
          }
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
            Expanded(child: _buildTableContainer()),
            const SizedBox(height: 16), // Add some spacing
            Flexible(child: _buildPlugsSection()), // Add the plugs section here
          ],
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

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

  Widget _buildTableContainer() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            Expanded(child: _buildDataTable()),
          ],
        ),
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
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 50,
          dataRowMinHeight: 60,
          dataRowMaxHeight: 60,
          columnSpacing: 20, // Add some spacing
          horizontalMargin: 10, // Add some margin
          headingRowColor: WidgetStateProperty.all(
            Theme.of(context).primaryColor.withOpacity(0.8),
          ),
          columns: [
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Name",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Email",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Address",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Status",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Date Registered",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Devices",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Actions",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ],
          rows: List.generate(users.length, (index) {
            final user = users[index];
            return DataRow(
              cells: [
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.status,
                      style: TextStyle(
                        color: user.status == "Active"
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.dateRegistered,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.amber),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '${user.devices.length} Devices: ${user.devices.map((e) => e.name).join(', ')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () => _editUser(index),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteUser(index),
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

            Expanded(
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
