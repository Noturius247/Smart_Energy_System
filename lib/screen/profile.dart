import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
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
  final TextEditingController _addressController = TextEditingController();

  StreamSubscription<DatabaseEvent>? _energyDataSubscription;

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
    _addressController.dispose();
    _energyDataSubscription?.cancel();
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
        .update({
          'name': _nameController.text,
          'role': _roleController.text,
          'address': _addressController.text,
        });

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
        _addressController.text = _userData!['address'] ?? '';
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
                          const Text('User data not found in Firestore.'),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'User Profile',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return RotationTransition(
                            turns: animation,
                            child: FadeTransition(opacity: animation, child: child),
                          );
                        },
                        child: IconButton(
                          key: ValueKey<bool>(_isEditing),
                          icon: Icon(
                            _isEditing ? Icons.save_rounded : Icons.edit_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 28,
                          ),
                          onPressed: _toggleEditing,
                          tooltip: _isEditing ? 'Save Changes' : 'Edit Profile',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Hero(
                        tag: 'profile_avatar',
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.secondary,
                                Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: _currentUser!.photoURL != null
                                  ? Image.network(
                                      _currentUser!.photoURL!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return CircleAvatar(
                                          backgroundColor: Theme.of(context).colorScheme.secondary,
                                          child: const Icon(
                                            Icons.person_rounded,
                                            size: 45,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    )
                                  : CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.secondary,
                                      child: const Icon(
                                        Icons.person_rounded,
                                        size: 45,
                                        color: Colors.white,
                                      ),
                                    ),
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
                              _displayNameController.text.isNotEmpty
                                  ? _displayNameController.text
                                  : _userData!['displayName'] ?? 'User Profile',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_rounded,
                                  size: 16,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _currentUser!.email ?? 'No email available',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 13,
                                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _userData!['role'] ?? 'User',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 35),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Device Information',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildEditableStatItem('Display Name', _displayNameController),
                        const SizedBox(height: 12),
                        _buildStatItem(
                          'Serial Number',
                          _userData!['serialNumber']?.toString() ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildStatItem(
                          'Provider',
                          _userData!['provider']?.toString() ?? 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildEditableStatItem(
                          'Price per KWH',
                          _pricePerKWHController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _buildEditableStatItem('Address', _addressController),
                        const SizedBox(height: 12),
                        _buildStatItem(
                          'Created At',
                          _formatTimestamp(_userData!['createdAt']),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              )
            : Text(
                controller.text.isEmpty ? 'N/A' : controller.text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
      ],
    );
  }


  Widget _buildMenuOptions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildMenuItem(Icons.person_rounded, 'Personal Info', () {}, Colors.blue),
                _buildMenuItem(Icons.security_rounded, 'Security', () {}, Colors.orange),
                _buildMenuItem(Icons.notifications_rounded, 'Notifications', () {}, Colors.purple),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(
                          Icons.help_outline_rounded,
                          size: 20,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        label: Text(
                          'Help & Support',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Logout',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFFFF6B6B).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).cardColor.withOpacity(0.3),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
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
