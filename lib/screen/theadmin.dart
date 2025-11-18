
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart'; // Import for Realtime Database
import 'dart:async'; // Import for StreamSubscription

import '../theme_provider.dart';
import 'login.dart';
import 'profile.dart';

// ------------------ USER MODEL ------------------
class UserModel {
  String uid;
  String name;
  String email;
  String status;
  String dateRegistered;
  String address;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.dateRegistered,
    required this.address,
  });
}

// ------------------ ADMIN SCREEN ------------------
class MyAdminScreen extends StatefulWidget {
  const MyAdminScreen({super.key});

  @override
  State<MyAdminScreen> createState() => _MyAdminScreenState();
}

class _MyAdminScreenState extends State<MyAdminScreen> {
  List<UserModel> users = [];
  List<UserModel> allUsers = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isCentralHubPaused = false; // New state variable
  final DatabaseReference _centralHubStatusRef =
      FirebaseDatabase.instance.ref().child('central_hub/data_reception_paused'); // New database reference
  StreamSubscription? _centralHubStatusSubscription; // New stream subscription

  String _currentHubSerialNumber = "default_hub_serial"; // Placeholder, needs to be dynamic

  @override
  void initState() {
    super.initState();
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
    _centralHubStatusSubscription = _centralHubStatusRef.onValue.listen((event) {
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
    }, onError: (error) {
      print("Error listening to central hub status: $error");
    });
  }



  // --------------------------------------------------
  // FETCH USERS
  // --------------------------------------------------
  Future<void> _fetchUsers() async {
    print('Fetching users from Firestore...');
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    print('Fetched ${snapshot.docs.length} documents.');

    final fetchedUsers = snapshot.docs.map((doc) {
      final data = doc.data();
      return UserModel(
        uid: doc.id,
        name: data['displayName'] ?? 'N/A',
        email: data['email'] ?? 'N/A',
        status: data['status'] ?? 'Active',
        dateRegistered: data['createdAt'] != null
            ? DateFormat('yyyy-MM-dd').format(
                (data['createdAt'] as Timestamp).toDate(),
              )
            : 'N/A',
        address: data['address'] ?? 'N/A',
      );
    }).toList();
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
        title: const Text(
          "Add User",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Enter full name",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Enter email",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            TextField(
              controller: passwordController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Enter password",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            TextField(
              controller: addressController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Enter address",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              dropdownColor:
                  Theme.of(context).primaryColor.withOpacity(0.8),
              initialValue: statusValue,
              items: ["Active", "Inactive"]
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: const TextStyle(color: Colors.white),
                      )))
                  .toList(),
              onChanged: (val) {
                if (val != null) statusValue = val;
              },
              decoration: const InputDecoration(
                labelText: "Select Status",
                labelStyle: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            onPressed: () async {
              try {
                final auth = FirebaseAuth.instance;
                final userCredential =
                    await auth.createUserWithEmailAndPassword(
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
                        'An unexpected error occurred: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(ctx); // Pop the dialog on error
              }
            },
            child: const Text(
              "Add",
              style: TextStyle(color: Colors.white),
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
    final addressController =
        TextEditingController(text: users[index].address);

    String statusValue = users[index].status;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
        title: const Text(
          "Edit User",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Update full name",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Update email",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            TextField(
              controller: addressController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Update address",
                hintStyle: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              dropdownColor:
                  Theme.of(context).primaryColor.withOpacity(0.8),
              initialValue: statusValue,
              items: ["Active", "Inactive"]
                  .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s,
                        style: const TextStyle(color: Colors.white),
                      )))
                  .toList(),
              onChanged: (val) {
                if (val != null) statusValue = val;
              },
              decoration: const InputDecoration(
                labelText: "Update Status",
                labelStyle: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).primaryColor.withOpacity(0.8),
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
            child: const Text(
              "Save",
              style: TextStyle(color: Colors.white),
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
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
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
          )
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.admin_panel_settings, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Admin Monitoring List',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications,
              color: Colors.white,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              themeNotifier.darkTheme ? Icons.dark_mode : Icons.light_mode,
              color: Colors.white,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.white,
            ),
            onSelected: (value) {
              if (value == 'view_profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EnergyProfileScreen()),
                );
              } else if (value == 'logout') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthPage()),
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
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search user...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              prefixIcon:
                  Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
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
          child: const Text(
            "Enter",
            style: TextStyle(
              color: Colors.white,
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
          columns: const [
            DataColumn(
                label: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Name",
                      style: TextStyle(color: Colors.white),
                    ))),
            DataColumn(
                label: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Email",
                      style: TextStyle(color: Colors.white),
                    ))),
            DataColumn(
                label: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Address",
                      style: TextStyle(color: Colors.white),
                    ))),
            DataColumn(
                label: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Status",
                      style: TextStyle(color: Colors.white),
                    ))),
            DataColumn(
                label: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Date Registered",
                      style: TextStyle(color: Colors.white),
                    ))),
            DataColumn(
                label: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Actions",
                      style: TextStyle(color: Colors.white),
                    ))),
          ],
          rows: List.generate(users.length, (index) {
            final user = users[index];
            return DataRow(
              cells: [
                DataCell(Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.name,
                      style: const TextStyle(color: Colors.white),
                    ))),
                DataCell(Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.email,
                      style: const TextStyle(color: Colors.white),
                    ))),
                DataCell(Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      user.address,
                      style: const TextStyle(color: Colors.white),
                    ))),
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
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                ),
                DataCell(
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blueAccent),
                          onPressed: () => _editUser(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent),
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
      final dbRef = FirebaseDatabase.instance.ref()
          .child('users')
          .child('espthesisbmn_at_gmail_com') // Hardcoded email as per user's request
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

                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(

                                    fontWeight: FontWeight.bold,

                                    color: Colors.white,

                                  ),

                            ),

                            const SizedBox(height: 16),

                            Row(

                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [

                                Text(

                                  'Pause Data Reception',

                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(

                                        color: Colors.white,

                                      ),

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
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.8),
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plugData['name'] ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                        'Status: ${plugData['status'] ?? 'N/A'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        )),
                                    Text('Power: ${plugData['power'] ?? 0} W',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        )),
                                    Text(
                                        'Voltage: ${plugData['voltage'] ?? 0} V',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        )),
                                    Text(
                                        'Current: ${plugData['current'] ?? 0} A',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        )),
                                    Text(
                                        'Energy: ${plugData['energy'] ?? 0} kWh',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        return const Center(
                            child: Text('Invalid data format'));
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
