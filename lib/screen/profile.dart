import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import '../realtime_db_service.dart';
import 'login.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';

class EnergyProfileScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService; // New: Add RealtimeDbService
  const EnergyProfileScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergyProfileScreen> createState() => _EnergyProfileScreenState();
}

class _EnergyProfileScreenState extends State<EnergyProfileScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 5;
  late AnimationController _animationController;
  final bool _isSidebarOpen = false;

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isEditing = false; // New state variable
  late RealtimeDbService _realtimeDbService;

  // Text editing controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _pricePerKWHController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _realtimeDbService = widget.realtimeDbService;
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _serialNumberController.dispose();
    _providerController.dispose();
    _pricePerKWHController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _saveUserData(); // Call save when exiting edit mode
      }
    });
  }

  Future<void> _saveUserData() async {
    if (_currentUser == null || _userData == null) return;

    // Update user document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .update({'name': _nameController.text, 'role': _roleController.text});

    // Update device document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('devices')
        .doc('SP001') // Assuming 'SP001' is the fixed device ID
        .update({
          'pricePerKWH': double.tryParse(_pricePerKWHController.text) ?? 0.0,
          'displayName': _displayNameController.text,
        });

    _loadUserData(); // Reload data to reflect changes
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser == null) {
        throw Exception('No authenticated user found.');
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      // Initialize _userData map
      _userData = {};

      if (userDoc.exists) {
        _userData!.addAll(userDoc.data() as Map<String, dynamic>);
      }

      // Fetch device data
      DocumentSnapshot deviceDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('devices')
          .doc('SP001') // Assuming 'SP001' is the fixed device ID for now
          .get();

      if (deviceDoc.exists) {
        // Add device data to _userData, potentially overriding if keys conflict
        _userData!.addAll(deviceDoc.data() as Map<String, dynamic>);
      } else if (!userDoc.exists) {
        // Only set _userData to null if neither user nor device data exists
        _userData = null;
      }

      // Populate controllers after _userData is loaded
      if (_userData != null) {
        _nameController.text = _userData!['name'] ?? '';
        _roleController.text = _userData!['role'] ?? '';
        _serialNumberController.text = _userData!['serialNumber'] ?? '';
        _providerController.text = _userData!['provider'] ?? '';
        _pricePerKWHController.text =
            _userData!['pricePerKWH']?.toString() ?? '';
        _displayNameController.text = _userData!['displayName'] ?? '';
      }
    } catch (e) {
      _errorMessage = 'Failed to load user data: ${e.toString()}';
      print(_errorMessage); // Print error for debugging
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onTabTapped(int index, Widget page) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width <
        600; // Define your small screen breakpoint
  }

  @override
  Widget build(BuildContext context) {
    // Check screen width to determine layout
    final isSmallScreen = _isSmallScreen(context);

    return Scaffold(
      body: isSmallScreen ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  // Desktop Layout (Sidebar on Left)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        CustomSidebarNav(
          currentIndex: _currentIndex,
          isBottomNav: false,
          realtimeDbService: _realtimeDbService, // Pass the service
          onTap: _onTabTapped,
        ),
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  // Mobile Layout (Bottom Navigation)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildMainContent()),
        CustomSidebarNav(
          currentIndex: _currentIndex,
          isBottomNav: true,
          realtimeDbService: _realtimeDbService, // Pass the service
          onTap: _onTabTapped,
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
              isSidebarOpen: _isSidebarOpen,
              isDarkMode: Provider.of<ThemeNotifier>(context).darkTheme,
              onToggleDarkMode: () {
                Provider.of<ThemeNotifier>(
                  context,
                  listen: false,
                ).toggleTheme();
              },
              realtimeDbService: _realtimeDbService, // Pass the service
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _currentUser == null
                  ? const Center(
                      child: Text('Please log in to view your profile.'),
                    )
                  : _userData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('User data not found in Firestore.'),
                          Text('UID: ${_currentUser!.uid}'),
                          // Optionally, add a button to create user data or re-fetch
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildProfileCard(),
                          const SizedBox(height: 20),
                          _buildMenuOptions(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.3).round()),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Added this
              children: [
                // Display Name prominently at the top
                Expanded(
                  child: Text(
                    _userData!['name'] ?? _currentUser!.email ?? 'User',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ), // Larger font size
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.save : Icons.edit,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: _toggleEditing,
                ),
              ],
            ),
            const SizedBox(height: 20), // Spacing after prominent name
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: _currentUser!.photoURL != null
                        ? Image.network(
                            _currentUser!.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              );
                            },
                          )
                        : CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.secondary,
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ${_userData!['role'] ?? 'No role specified'}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 25),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _currentUser!.email ?? 'No email available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Device Information',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Display device-specific information
            Column(
              children: [
                _buildEditableStatItem('Display Name', _displayNameController),
                _buildStatItem(
                  'Serial Number',
                  _userData!['serialNumber']?.toString() ?? 'N/A',
                ),
                _buildStatItem(
                  'Provider',
                  _userData!['provider']?.toString() ?? 'N/A',
                ),
                _buildEditableStatItem(
                  'Price per KWH',
                  _pricePerKWHController,
                  keyboardType: TextInputType.number,
                ),
                _buildStatItem(
                  'Created At',
                  _formatTimestamp(_userData!['createdAt']),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Energy Stats',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildStatItem(
                        'Current Energy Usage',
                        '350 kWh',
                      ), // These could also be dynamic
                      const SizedBox(height: 5),
                      _buildStatItem(
                        'Monthly Savings',
                        '₱25',
                      ), // These could also be dynamic
                      const SizedBox(height: 5),
                      _buildStatItem(
                        'Carbon Reduction',
                        '120 kg',
                      ), // These could also be dynamic
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // --- Sizing Fix Applied Here ---
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      // Removed const here
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: 0.7,
                        strokeWidth: 7,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withAlpha((255 * 0.2).round()),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),

                    Column(
                      children: [
                        Text(
                          '120',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'kg CO₂',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // New widget for editable stats
  Widget _buildEditableStatItem(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          _isEditing
              ? Expanded(
                  child: TextFormField(
                    controller: controller,
                    textAlign: TextAlign.end,
                    keyboardType: keyboardType,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                )
              : Text(
                  controller.text.isEmpty ? 'N/A' : controller.text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
        ],
      ),
    );
  }

  Widget _buildMenuOptions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.3).round()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuItem(Icons.person_outline, 'Personal Info', () {}),
          _buildDivider(),
          _buildMenuItem(Icons.security, 'Security', () {}),
          _buildDivider(),
          _buildMenuItem(Icons.notifications_outlined, 'Notifications', () {}),
          _buildDivider(),
          _buildMenuItem(Icons.devices, 'Connected Devices', () {}),
          _buildDivider(),
          _buildMenuItem(Icons.bar_chart, 'View Energy History', () {}),
          _buildDivider(),
          _buildMenuItem(Icons.settings, 'Manage Smart Devices', () {}),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Help & Support',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ElevatedButton(
                  onPressed: _showLogoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Theme.of(context).iconTheme.color,
        size: 16,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Divider(color: Theme.of(context).dividerColor, height: 1),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Logout', style: Theme.of(context).textTheme.bodyLarge),
          content: Text(
            'Are you sure you want to logout?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final navigatorContext =
                    context; // Store context before async gap
                try {
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();

                  // Sign out from Google
                  final googleSignIn = GoogleSignIn();
                  await googleSignIn.signOut();
                } catch (e) {
                  debugPrint("Sign out error: $e");
                }
                if (!navigatorContext.mounted) return;
                Navigator.pushAndRemoveUntil(
                  navigatorContext,
                  MaterialPageRoute(
                    builder: (_) =>
                        AuthPage(realtimeDbService: _realtimeDbService),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B6B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
    }
    // Handle other potential types if necessary, or just return toString()
    return timestamp.toString();
  }
}
