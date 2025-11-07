import 'package:flutter/material.dart';
import 'admin_home.dart';
import 'explore.dart';
import 'analytics.dart';
import 'schedule.dart';
import 'profile.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';

class EnergySettingScreen extends StatefulWidget {
  const EnergySettingScreen({super.key});

  @override
  State<EnergySettingScreen> createState() => _EnergySettingScreenState();
}

class _EnergySettingScreenState extends State<EnergySettingScreen>
    with TickerProviderStateMixin {
  bool smartScheduling = true;
  bool peakHourAlerts = true;
  double powerSavingLevel = 0.6;
  bool _isDarkMode = false;
  int _currentIndex = 4;
  bool _breakerStatus = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _profileController;
  late Animation<Offset> _profileSlideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    _profileController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _profileSlideAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  String get powerSavingText {
    if (powerSavingLevel < 0.33) return 'Low';
    if (powerSavingLevel > 0.66) return 'High';
    return 'Medium';
  }

  void _navigateToConnectedDevices() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _navigateToAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DevicesTab()),
    );
  }

  void _navigateToThemeSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
    );
  }

  void _navigateToProfileSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnergyProfileScreen()),
    );
  }

  void _navigateToSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnergySchedulingScreen()),
    );
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check screen width to determine layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;

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
          onTap: (index, page) {
            setState(() {
              _currentIndex = index;
            });
            if (index != 4) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            }
          },
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
          onTap: (index, page) {
            setState(() {
              _currentIndex = index;
            });
            if (index != 4) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a2332), Color(0xFF0f1419)],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildEnergyUsageAndBreaker(),
                    const SizedBox(height: 30),
                    _buildEnergyManagement(),
                    const SizedBox(height: 40),
                    _buildDeviceManagement(),
                    const SizedBox(height: 40),
                    _buildPreferences(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Top Header
        CustomHeader(
          isDarkMode: _isDarkMode,
          isSidebarOpen: false,
          onToggleDarkMode: () {
            setState(() {
              _isDarkMode = !_isDarkMode;
            });
          },
        ),

        // Profile Popover
        Positioned(
          top: 70,
          right: 12,
          child: FadeTransition(
            opacity: _profileController,
            child: SlideTransition(
              position: _profileSlideAnimation,
              child: ScaleTransition(
                scale: _profileController,
                alignment: Alignment.topRight,
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(150),
                        blurRadius: 10,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.person, size: 30, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Marie Fe Tapales',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'marie@example.com',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          _profileController.reverse();
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EnergyProfileScreen()),
                            );
                          });
                        },
                        child: const Text(
                          'View Profile',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _profileController.reverse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          minimumSize: const Size.fromHeight(36),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.only(top: 80, bottom: 12),
      child: Text(
        'Settings',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w300,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEnergyUsageAndBreaker() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: _buildEnergyUsage(),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildBreakerControl(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyUsage() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Energy Usage",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '7.4 kWh',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w200,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _navigateToSchedule,
            child: Text(
              'Next Task: 10:30 AM',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ENERGY MANAGEMENT'),
        const SizedBox(height: 20),
        _buildSettingItem(
          icon: Icons.schedule,
          iconColor: const Color(0xFF10b981),
          title: 'Smart Scheduling',
          trailing: Switch(
            value: smartScheduling,
            onChanged: (value) {
              setState(() {
                smartScheduling = value;
              });
              if (value) {
                _navigateToSchedule();
              }
            },
            activeColor: const Color(0xFF10b981),
          ),
        ),
        _buildSettingItem(
          icon: Icons.notifications,
          iconColor: const Color(0xFFf59e0b),
          title: 'Peak Hour Alerts',
          trailing: Switch(
            value: peakHourAlerts,
            onChanged: (value) {
              setState(() {
                peakHourAlerts = value;
              });
            },
            activeColor: const Color(0xFF10b981),
          ),
        ),
        _buildSettingItem(
          icon: Icons.power_settings_new,
          iconColor: const Color(0xFF10b981),
          title: 'Power Saving Mode',
        ),
        const SizedBox(height: 15),
        _buildPowerSlider(),
      ],
    );
  }

  Widget _buildPowerSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF10b981),
            inactiveTrackColor: const Color(0xFF1e293b),
            thumbColor: const Color(0xFF10b981),
            overlayColor: const Color(0xFF10b981).withAlpha(80),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: powerSavingLevel,
            onChanged: (value) {
              setState(() {
                powerSavingLevel = value;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              Text('High', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          powerSavingText,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF10b981),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakerControl() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F36), Color(0xFF111629)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.power,
            color: _breakerStatus
                ? const Color.fromARGB(255, 25, 207, 98)
                : Colors.grey.shade400,
            size: 36,
          ),
          const SizedBox(height: 8),
          const Text(
            'Breaker',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _breakerStatus = !_breakerStatus;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: _breakerStatus
                    ? const Color.fromARGB(255, 110, 219, 168)
                    : Colors.grey[800],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _breakerStatus
                        ? const Color.fromARGB(255, 60, 197, 108).withAlpha(150)
                        : Colors.black26,
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _breakerStatus ? 'ON' : 'OFF',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DEVICE MANAGEMENT'),
        const SizedBox(height: 20),
        _buildSettingItem(
          icon: Icons.devices,
          iconColor: const Color(0xFF3b82f6),
          title: 'Connected Devices',
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          onTap: _navigateToConnectedDevices,
        ),
        _buildSettingItem(
          icon: Icons.add,
          iconColor: const Color(0xFF10b981),
          title: 'Add New Device',
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          onTap: _navigateToAddDevice,
        ),
      ],
    );
  }

  Widget _buildPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PREFERENCES & ACCOUNT'),
        const SizedBox(height: 20),
        _buildSettingItem(
          icon: Icons.palette,
          iconColor: const Color(0xFF06b6d4),
          title: 'Theme & Units',
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          onTap: _navigateToThemeSettings,
        ),
        _buildSettingItem(
          icon: Icons.person,
          iconColor: const Color(0xFF8b5cf6),
          title: 'Profile Settings',
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          onTap: _navigateToProfileSettings,
        ),
        _buildSettingItem(
          icon: Icons.home,
          iconColor: const Color(0xFF10b981),
          title: 'Back to Home',
          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 24),
          onTap: _navigateToMain,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[400],
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1e293b), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: iconColor,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    fontSize: 18, color: Colors.white, fontWeight: FontWeight.w400),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}