import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
        title: const Text("Add User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Enter full name"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(hintText: "Enter email"),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Enter password"),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(hintText: "Enter address"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: statusValue,
              items: ["Active", "Inactive"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) statusValue = val;
              },
              decoration: const InputDecoration(labelText: "Select Status"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final auth = FirebaseAuth.instance;
                final userCredential = await auth.createUserWithEmailAndPassword(
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
                    content: Text('An unexpected error occurred: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
                Navigator.pop(ctx); // Pop the dialog on error
              }
            },
            child: const Text("Add"),
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
        title: const Text("Edit User"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Update full name"),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(hintText: "Update email"),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(hintText: "Update address"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: statusValue,
              items: ["Active", "Inactive"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) statusValue = val;
              },
              decoration: const InputDecoration(labelText: "Update Status"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
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
            child: const Text("Save"),
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
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add),
      ),

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(themeNotifier),
            const SizedBox(height: 16),
            Expanded(child: _buildTableContainer()),
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
          Icon(Icons.admin_panel_settings,
              color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Admin Monitoring List',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.notifications,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              themeNotifier.darkTheme ? Icons.dark_mode : Icons.light_mode,
              color: Theme.of(context).colorScheme.secondary,
            ),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.account_circle,
              color: Theme.of(context).colorScheme.secondary,
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
          color: Theme.of(context).cardColor,
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
            decoration: InputDecoration(
              hintText: "Search user...",
              prefixIcon: Icon(Icons.search,
                  color: Theme.of(context).iconTheme.color),
              filled: true,
              fillColor: Theme.of(context).cardColor.withOpacity(0.05),
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
            backgroundColor: Theme.of(context).colorScheme.secondary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => _applySearch(_searchController.text),
          child: const Text("Enter"),
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
            Theme.of(context).colorScheme.secondary.withOpacity(0.5),
          ),
          columns: const [
            DataColumn(label: Padding(padding: EdgeInsets.all(8.0), child: Text("Name"))),
            DataColumn(label: Padding(padding: EdgeInsets.all(8.0), child: Text("Email"))),
            DataColumn(label: Padding(padding: EdgeInsets.all(8.0), child: Text("Address"))),
            DataColumn(label: Padding(padding: EdgeInsets.all(8.0), child: Text("Status"))),
            DataColumn(label: Padding(padding: EdgeInsets.all(8.0), child: Text("Date Registered"))),
            DataColumn(label: Padding(padding: EdgeInsets.all(8.0), child: Text("Actions"))),
          ],
          rows: List.generate(users.length, (index) {
            final user = users[index];
            return DataRow(
              cells: [
                DataCell(Padding(padding: const EdgeInsets.all(8.0), child: Text(user.name))),
                DataCell(Padding(padding: const EdgeInsets.all(8.0), child: Text(user.email))),
                DataCell(Padding(padding: const EdgeInsets.all(8.0), child: Text(user.address))),
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
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () => _editUser(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
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
}
