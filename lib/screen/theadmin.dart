import 'package:flutter/material.dart';
import 'login.dart';

class UserModel {
  String name;
  String email;
  String status;
  String dateRegistered;
  String address;

  UserModel({
    required this.name,
    required this.email,
    required this.status,
    required this.dateRegistered,
    required this.address,
  });
}

class MyAdminScreen extends StatefulWidget {
  const MyAdminScreen({super.key});

  @override
  State<MyAdminScreen> createState() => _MyAdminScreenState();
}

class _MyAdminScreenState extends State<MyAdminScreen> {
  List<UserModel> users = [
    UserModel(
        name: "Alice Johnson",
        email: "alice@example.com",
        status: "Active",
        dateRegistered: "2025-09-01",
        address: "123 Main St"),
    UserModel(
        name: "Bob Martinez",
        email: "bob@example.com",
        status: "Inactive",
        dateRegistered: "2025-09-02",
        address: "456 Oak Ave"),
    UserModel(
        name: "Charlie Gomez",
        email: "charlie@example.com",
        status: "Active",
        dateRegistered: "2025-09-05",
        address: "321 Elm St"),
    UserModel(
        name: "Diana Smith",
        email: "diana@example.com",
        status: "Inactive",
        dateRegistered: "2025-09-07",
        address: "789 Pine Rd"),
  ];

  List<UserModel> allUsers = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    allUsers = List.from(users);
  }

  void _applySearch(String query) {
    setState(() {
      if (query.isEmpty) {
        users = List.from(allUsers);
      } else {
        users = allUsers
            .where((u) =>
                u.name.toLowerCase().contains(query.toLowerCase()) ||
                u.email.toLowerCase().contains(query.toLowerCase()) ||
                u.address.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _addUser() {
    TextEditingController nameController = TextEditingController();
    TextEditingController emailController = TextEditingController();
    TextEditingController addressController = TextEditingController();
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
                decoration: const InputDecoration(hintText: "Enter full name")),
            TextField(
                controller: emailController,
                decoration:
                    const InputDecoration(hintText: "Enter email address")),
            TextField(
                controller: addressController,
                decoration: const InputDecoration(hintText: "Enter address")),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                String today = DateTime.now().toIso8601String().split('T').first;
                final newUser = UserModel(
                  name: nameController.text,
                  email: emailController.text,
                  status: statusValue,
                  dateRegistered: today,
                  address: addressController.text,
                );
                users.add(newUser);
                allUsers.add(newUser);
              });
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

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
                decoration: const InputDecoration(hintText: "Update full name")),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(hintText: "Update email")),
            TextField(
                controller: addressController,
                decoration: const InputDecoration(hintText: "Update address")),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                users[index].name = nameController.text;
                users[index].email = emailController.text;
                users[index].address = addressController.text;
                users[index].status = statusValue;
                allUsers[index] = users[index];
              });
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteUser(int index) {
    setState(() {
      allUsers.remove(users[index]);
      users.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: _addUser,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDarkMode
                    ? [const Color(0xFF0f1419), const Color(0xFF1a2332)]
                    : [const Color(0xFF1a2332), const Color(0xFF0f1419)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.admin_panel_settings, color: Colors.teal),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Admin Monitoring List',
                          style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                      Switch(
                          value: _isDarkMode,
                          activeThumbColor: Colors.teal,
                          onChanged: (value) =>
                              setState(() => _isDarkMode = value)),
                      IconButton(
                          icon: const Icon(Icons.notifications, color: Colors.teal),
                          onPressed: () {}),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.account_circle,
                            color: Colors.teal, size: 28),
                        onSelected: (value) {
                          if (value == 'view_profile') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("View Profile clicked")),
                            );
                            // TODO: Navigate to Profile screen
                          } else if (value == 'logout') {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => AuthPage()),
                              (route) => false,
                            );
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'view_profile',
                            child: Text('View Profile'),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Text('Logout'),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: "Search user...",
                                    hintStyle:
                                        const TextStyle(color: Colors.white70),
                                    prefixIcon:
                                        const Icon(Icons.search, color: Colors.white70),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  onSubmitted: (query) => _applySearch(query),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _applySearch(_searchController.text),
                                child: const Text("Enter"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              child: SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  headingRowHeight: 50,
                                  dataRowHeight: 60,
                                  columnSpacing: 40,
                                  headingRowColor:
                                      WidgetStateProperty.all(Colors.teal.shade700),
                                  columns: const [
                                    DataColumn(
                                        label: Text("Name",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text("Email",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text("Address",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text("Status",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text("Date Registered",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text("Actions",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                  ],
                                  rows: List.generate(users.length, (index) {
                                    return DataRow(cells: [
                                      DataCell(Text(users[index].name,
                                          style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(users[index].email,
                                          style: const TextStyle(color: Colors.white70))),
                                      DataCell(Text(users[index].address,
                                          style: const TextStyle(color: Colors.white70))),
                                      DataCell(Text(
                                        users[index].status,
                                        style: TextStyle(
                                          color: users[index].status == "Active"
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                        ),
                                      )),
                                      DataCell(Text(users[index].dateRegistered,
                                          style: const TextStyle(color: Colors.amber))),
                                      DataCell(Row(
                                        children: [
                                          IconButton(
                                              icon: const Icon(Icons.edit,
                                                  color: Colors.blueAccent),
                                              onPressed: () => _editUser(index)),
                                          IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.redAccent),
                                              onPressed: () => _deleteUser(index)),
                                        ],
                                      )),
                                    ]);
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
