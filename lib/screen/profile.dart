import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'login.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';


class EnergyProfileScreen extends StatefulWidget {
  const EnergyProfileScreen({super.key});

  @override
  State<EnergyProfileScreen> createState() => _EnergyProfileScreenState();
}

class _EnergyProfileScreenState extends State<EnergyProfileScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 5;
  late AnimationController _animationController;
  final bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index, Widget page) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600; // Define your small screen breakpoint
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
                Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
              },
            ),
            Expanded(
              child: SingleChildScrollView(
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
        colors: [
          Theme.of(context).cardColor,
          Theme.of(context).primaryColor,
        ],
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
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 3),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/profile_avatar.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        child: Icon(Icons.person, size: 40, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Marie Fe Tapales',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Home Owner',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: Theme.of(context).iconTheme.color),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Energy Stats',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildStatItem('Current Energy Usage', '350 kWh'),
                    const SizedBox(height: 5),
                    _buildStatItem('Monthly Savings', '₱25'),
                    const SizedBox(height: 5),
                    _buildStatItem('Carbon Reduction', '120 kg'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // --- Sizing Fix Applied Here ---
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox( // Removed const here
  width: 60,
  height: 60,
  child: CircularProgressIndicator(
    value: 0.7,
    strokeWidth: 7,
    backgroundColor: Theme.of(context).primaryColor.withAlpha((255 * 0.2).round()),
    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.secondary),
  ),
),

                  Column(
                    children: [
                      Text(
                        '120',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'kg CO₂',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMenuOptions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).cardColor,
            Theme.of(context).primaryColor,
          ],
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
                        horizontal: 25, vertical: 12),
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
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).iconTheme.color, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Divider(
        color: Theme.of(context).dividerColor,
        height: 1,
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
              child: Text('Cancel', style: Theme.of(context).textTheme.bodyMedium),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final navigatorContext = context; // Store context before async gap
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
                  MaterialPageRoute(builder: (_) => const AuthPage()),
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
}