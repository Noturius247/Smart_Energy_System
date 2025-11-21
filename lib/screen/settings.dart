import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import '../theme_provider.dart';
import '../realtime_db_service.dart';
import 'admin_home.dart';
import 'explore.dart';
import 'schedule.dart';
import 'profile.dart';


class EnergySettingScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;
  const EnergySettingScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergySettingScreen> createState() => _EnergySettingScreenState();
}

class _EnergySettingScreenState extends State<EnergySettingScreen>
    with TickerProviderStateMixin {
  bool smartScheduling = true;
  bool peakHourAlerts = true;
  double powerSavingLevel = 0.6;
  bool _breakerStatus = false;
  double _pricePerKWH = 0.0; // New state variable for price per kWh
  late RealtimeDbService _realtimeDbService;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadPricePerKWH(); // Load saved price on init
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _realtimeDbService = widget.realtimeDbService;
  }

  // Method to save price per kWh to Firestore
  Future<void> _savePricePerKWH() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to save settings.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'pricePerKWH': _pricePerKWH}, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price per kWh saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving price: $e')),
      );
    }
  }

  // Method to load price per kWh from Firestore
  Future<void> _loadPricePerKWH() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // If user is not logged in, set default and don't try to load from Firestore
      setState(() {
        _pricePerKWH = 0.0;
      });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('pricePerKWH')) {
        setState(() {
          _pricePerKWH = (doc.data()!['pricePerKWH'] as num).toDouble();
        });
      } else {
        setState(() {
          _pricePerKWH = 0.0;
        });
      }
    } catch (e) {
      print('Error loading price per kWh: $e');
      setState(() {
        _pricePerKWH = 0.0; // Default in case of error
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      MaterialPageRoute(builder: (context) => HomeScreen(realtimeDbService: _realtimeDbService)),
    );
  }

  void _navigateToAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DevicesTab(realtimeDbService: _realtimeDbService)),
    );
  }

  void _navigateToProfileSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EnergyProfileScreen(realtimeDbService: _realtimeDbService)),
    );
  }

  void _navigateToSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EnergySchedulingScreen(realtimeDbService: _realtimeDbService)),
    );
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(realtimeDbService: _realtimeDbService)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.surface, Theme.of(context).scaffoldBackgroundColor],
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
                const SizedBox(height: 40),
                _buildPricingSettings(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 80, bottom: 12),
      child: Text(
        'Settings',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w300,
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
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(80),
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
      ),
    ),
    const SizedBox(height: 4), // less spacing
    Text(
      '7.4 kWh',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w200,
      ),
    ),
    const SizedBox(height: 4), // less spacing
    GestureDetector(
      onTap: _navigateToSchedule,
      child: Text(
        'Next Task: 10:30 AM',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  ],
)

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
          iconColor: Theme.of(context).colorScheme.secondary,
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
            activeColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
        _buildSettingItem(
          icon: Icons.notifications,
          iconColor: Theme.of(context).colorScheme.primary,
          title: 'Peak Hour Alerts',
          trailing: Switch(
            value: peakHourAlerts,
            onChanged: (value) {
              setState(() {
                peakHourAlerts = value;
              });
            },
            activeColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
        _buildSettingItem(
          icon: Icons.power_settings_new,
          iconColor: Theme.of(context).colorScheme.secondary,
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
            activeTrackColor: Theme.of(context).colorScheme.secondary,
            inactiveTrackColor: Theme.of(context).cardColor,
            thumbColor: Theme.of(context).colorScheme.secondary,
            overlayColor: Theme.of(context).colorScheme.secondary.withAlpha(80),
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
              Text('Low', style: Theme.of(context).textTheme.bodySmall),
              Text('High', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          powerSavingText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBreakerControl() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
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
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).disabledColor,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            'Breaker',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
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
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).disabledColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _breakerStatus
                        ? Theme.of(context).colorScheme.secondary.withAlpha(150)
                        : Theme.of(context).shadowColor.withAlpha(150),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _breakerStatus ? 'ON' : 'OFF',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondary,
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
          iconColor: Theme.of(context).colorScheme.primary,
          title: 'Connected Devices',
          trailing: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color, size: 24),
          onTap: _navigateToConnectedDevices,
        ),
        _buildSettingItem(
          icon: Icons.add,
          iconColor: Theme.of(context).colorScheme.secondary,
          title: 'Add New Device',
          trailing: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color, size: 24),
          onTap: _navigateToAddDevice,
        ),
      ],
    );
  }

  Widget _buildPreferences() {
    return Consumer<ThemeNotifier>(
      builder: (context, theme, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('PREFERENCES & ACCOUNT'),
          const SizedBox(height: 20),
          _buildSettingItem(
            icon: Icons.palette,
            iconColor: Theme.of(context).colorScheme.tertiary,
            title: 'Dark Mode',
            trailing: Switch(
              value: theme.darkTheme,
              onChanged: (value) {
                theme.toggleTheme();
              },
            ),
          ),
          _buildSettingItem(
            icon: Icons.person,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Profile Settings',
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color, size: 24),
            onTap: _navigateToProfileSettings,
          ),
          _buildSettingItem(
            icon: Icons.home,
            iconColor: Theme.of(context).colorScheme.secondary,
            title: 'Back to Home',
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color, size: 24),
            onTap: _navigateToMain,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PRICING SETTINGS'),
        const SizedBox(height: 20),
        _buildSettingItem(
          icon: Icons.attach_money,
          iconColor: Colors.green,
          title: 'Price per kWh',
          trailing: SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: _pricePerKWH.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              textAlign: TextAlign.right,
              onChanged: (value) {
                setState(() {
                  _pricePerKWH = double.tryParse(value) ?? 0.0;
                });
              },
              style: Theme.of(context).textTheme.titleMedium,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0.00',
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () {
              _savePricePerKWH();
            },
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
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
              child: Icon(icon, color: Theme.of(context).colorScheme.onSecondary, size: 18),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}