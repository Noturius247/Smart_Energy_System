import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import '../theme_provider.dart';
import '../realtime_db_service.dart';
import '../due_date_provider.dart';
import '../price_provider.dart';
import '../notification_provider.dart';
import '../constants.dart';
import 'admin_home.dart';
import 'explore.dart';
import 'history.dart';


class EnergySettingScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;
  const EnergySettingScreen({super.key, required this.realtimeDbService});

  @override
  State<EnergySettingScreen> createState() => _EnergySettingScreenState();
}

class _EnergySettingScreenState extends State<EnergySettingScreen>
    with TickerProviderStateMixin {
  bool _breakerStatus = false;
  double _pricePerKWH = 0.0; // New state variable for price per kWh
  late RealtimeDbService _realtimeDbService;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Hub selection and SSR state management
  List<Map<String, String>> _availableHubs = [];
  String? _selectedHubSerial;
  StreamSubscription? _hubDataSubscription;
  StreamSubscription? _ssrStateSubscription;

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
    _loadUserHubs();
    _listenToHubDataStream();
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

  // Load user's hubs from Firebase
  Future<void> _loadUserHubs() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final hubSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(currentUser.uid)
          .get();

      if (!hubSnapshot.exists || hubSnapshot.value == null) {
        debugPrint('[Settings] No hubs found for user');
        return;
      }

      final allHubs = json.decode(json.encode(hubSnapshot.value)) as Map<String, dynamic>;
      final List<Map<String, String>> hubList = [];

      for (final serialNumber in allHubs.keys) {
        final hubData = allHubs[serialNumber] as Map<String, dynamic>;
        final String? nickname = hubData['nickname'] as String?;

        hubList.add({
          'serialNumber': serialNumber,
          'nickname': nickname ?? 'Central Hub',
        });
      }

      setState(() {
        _availableHubs = hubList;
        if (hubList.isNotEmpty) {
          _selectedHubSerial = hubList.first['serialNumber'];
          _loadSsrState();
        }
      });
    } catch (e) {
      debugPrint('[Settings] Error loading hubs: $e');
    }
  }

  // Load SSR state for selected hub
  Future<void> _loadSsrState() async {
    if (_selectedHubSerial == null) return;

    try {
      final ssrSnapshot = await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs/$_selectedHubSerial/ssr_state')
          .get();

      if (ssrSnapshot.exists && ssrSnapshot.value != null) {
        setState(() {
          _breakerStatus = ssrSnapshot.value as bool;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Error loading SSR state: $e');
    }

    // Subscribe to SSR state changes
    _ssrStateSubscription?.cancel();
    _ssrStateSubscription = FirebaseDatabase.instance
        .ref('$rtdbUserPath/hubs/$_selectedHubSerial/ssr_state')
        .onValue
        .listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        setState(() {
          _breakerStatus = event.snapshot.value as bool;
        });
      }
    });
  }

  // Listen to hub data stream for real-time updates
  void _listenToHubDataStream() {
    _hubDataSubscription = _realtimeDbService.hubDataStream.listen((data) {
      if (data['type'] == 'hub_state' && data['serialNumber'] == _selectedHubSerial) {
        setState(() {
          _breakerStatus = data['ssr_state'] as bool;
        });
      }
    });
  }

  // Show dialog to edit hub nickname
  Future<void> _showEditNicknameDialog() async {
    if (_selectedHubSerial == null) return;

    // Get current nickname
    final currentHub = _availableHubs.firstWhere(
      (hub) => hub['serialNumber'] == _selectedHubSerial,
      orElse: () => {'serialNumber': '', 'nickname': 'Central Hub'},
    );
    final currentNickname = currentHub['nickname'] ?? 'Central Hub';

    final TextEditingController nicknameController = TextEditingController(text: currentNickname);
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.darkTheme;

    final String? newNickname = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1a2332) : Colors.white,
          title: Text(
            'Edit Hub Nickname',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hub: ${_selectedHubSerial!.length > 8 ? _selectedHubSerial!.substring(0, 8) : _selectedHubSerial!}...',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nicknameController,
                autofocus: true,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: 'Nickname',
                  hintText: 'Enter hub nickname',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.secondary,
                      width: 2,
                    ),
                  ),
                  counterStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final nickname = nicknameController.text.trim();
                if (nickname.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nickname cannot be empty')),
                  );
                  return;
                }
                Navigator.of(context).pop(nickname);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    // If user provided a new nickname, update Firebase
    if (newNickname != null && newNickname != currentNickname && mounted) {
      try {
        await FirebaseDatabase.instance
            .ref('$rtdbUserPath/hubs/$_selectedHubSerial/nickname')
            .set(newNickname);

        // Update local state
        setState(() {
          final index = _availableHubs.indexWhere((hub) => hub['serialNumber'] == _selectedHubSerial);
          if (index != -1) {
            _availableHubs[index]['nickname'] = newNickname;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hub nickname updated to "$newNickname"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating nickname: $e')),
          );
        }
      }
    }
  }

  // Toggle SSR state
  Future<void> _toggleBreaker() async {
    if (_selectedHubSerial == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hub selected')),
      );
      return;
    }

    final newState = !_breakerStatus;

    try {
      await FirebaseDatabase.instance
          .ref('$rtdbUserPath/hubs/$_selectedHubSerial/ssr_state')
          .set(newState);

      if (!mounted) return;
      setState(() {
        _breakerStatus = newState;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Breaker turned ${newState ? "ON" : "OFF"}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling breaker: $e')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hubDataSubscription?.cancel();
    _ssrStateSubscription?.cancel();
    super.dispose();
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

  void _navigateToSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EnergyHistoryScreen(realtimeDbService: _realtimeDbService)),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.darkTheme;
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1a2332) : Colors.white,
          title: Text(
            'Change Password',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A password reset link will be sent to:',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user.email!,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Check your email and follow the instructions to reset your password.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Send Email'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _sendPasswordResetEmail(user.email!);
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many requests. Please try again later';
          break;
        default:
          errorMessage = 'Error sending reset email: ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openGoogleAccountSettings() async {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.darkTheme;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1a2332) : Colors.white,
          title: Text(
            'Manage Google Account',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You signed in with Google. To change your password or manage your account settings, you need to visit your Google Account page.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This will open your browser and redirect you to Google Account settings.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Open Google Account'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final Uri url = Uri.parse('https://myaccount.google.com/');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open Google Account settings')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening link: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return Scaffold(
      body: Container(
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
                  if (_availableHubs.isNotEmpty) _buildHubSelector(),
                  if (_availableHubs.isNotEmpty) const SizedBox(height: 20),
                  _buildPricingSettings(),
                  const SizedBox(height: 30),
                  _buildEnergyUsageAndBreaker(),
                  const SizedBox(height: 30),
                  _buildDeviceManagement(),
                  const SizedBox(height: 40),
                  _buildPreferences(),
                  const SizedBox(height: 40),
                  _buildDueDateSettings(),
                  const SizedBox(height: 100),
                ],
              ),
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

  Widget _buildHubSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withAlpha(60),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.router,
            color: Theme.of(context).colorScheme.secondary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control Hub',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
                if (_availableHubs.length > 1)
                  DropdownButton<String>(
                    value: _selectedHubSerial,
                    isExpanded: true,
                    underline: const SizedBox(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    items: _availableHubs.map((hub) {
                      final serial = hub['serialNumber']!;
                      final nickname = hub['nickname']!;
                      final serialDisplay = serial.length > 8 ? serial.substring(0, 8) : serial;
                      return DropdownMenuItem<String>(
                        value: serial,
                        child: Text(
                          '$nickname ($serialDisplay...)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedHubSerial = value;
                        });
                        _loadSsrState();
                      }
                    },
                  ),
                if (_availableHubs.length == 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      '${_availableHubs.first['nickname']} (${_availableHubs.first['serialNumber']!.length > 8 ? _availableHubs.first['serialNumber']!.substring(0, 8) : _availableHubs.first['serialNumber']!}...)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Edit Hub Nickname',
            onPressed: _selectedHubSerial != null ? () => _showEditNicknameDialog() : null,
          ),
        ],
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
            child: _buildScheduleCard(),
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

  Widget _buildScheduleCard() {
    return Consumer<DueDateProvider>(
      builder: (context, dueDateProvider, _) {
        final hasDueDate = dueDateProvider.dueDate != null;
        final isOverdue = dueDateProvider.isOverdue;

        return Container(
          padding: const EdgeInsets.all(25),
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
                color: Theme.of(context).shadowColor.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasDueDate) ...[
                  Text(
                    'Due Date',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 28,
                        color: isOverdue ? Colors.red : Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dueDateProvider.getFormattedDueDate() ?? '',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w300,
                          color: isOverdue ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isOverdue ? Colors.red : Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOverdue
                              ? 'Overdue by ${dueDateProvider.getDaysRemaining()!.abs()} days'
                              : '${dueDateProvider.getDaysRemaining()} days remaining',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'No Due Date Set',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 28,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tap to set',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        );
      },
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
            onTap: _toggleBreaker,
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
    final User? user = FirebaseAuth.instance.currentUser;
    final bool isPasswordProvider = user?.providerData.any((info) => info.providerId == 'password') ?? false;
    final bool isGoogleProvider = user?.providerData.any((info) => info.providerId == 'google.com') ?? false;

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
          if (isPasswordProvider)
            _buildSettingItem(
              icon: Icons.lock,
              iconColor: Theme.of(context).colorScheme.primary,
              title: 'Change Password',
              trailing: Icon(Icons.chevron_right, color: Theme.of(context).iconTheme.color, size: 24),
              onTap: _showChangePasswordDialog,
            ),
          if (isGoogleProvider)
            _buildSettingItem(
              icon: Icons.manage_accounts,
              iconColor: Colors.red,
              title: 'Manage Google Account',
              trailing: Icon(Icons.open_in_new, color: Theme.of(context).iconTheme.color, size: 24),
              onTap: _openGoogleAccountSettings,
            ),
        ],
      ),
    );
  }

  Widget _buildPricingSettings() {
    return Consumer<PriceProvider>(
      builder: (context, priceProvider, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('PRICING SETTINGS'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).cardColor,
                  Theme.of(context).primaryColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          '₱',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Electricity Rate',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set your price per kWh',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withAlpha(100),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '₱',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: priceProvider.pricePerKWH.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _pricePerKWH = double.tryParse(value) ?? 0.0;
                            });
                          },
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: Colors.grey.withAlpha(128),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        'per kWh',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final oldPrice = priceProvider.pricePerKWH; // Capture old price
                      final success = await priceProvider.setPrice(_pricePerKWH);

                      if (success) {
                        // Track price update notification
                        if (mounted) {
                          final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
                          await notificationProvider.trackPriceUpdate(oldPrice, _pricePerKWH);
                        }

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Price per kWh saved successfully!')),
                          );
                        }
                      } else if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error saving price')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Save Price',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (priceProvider.pricePerKWH > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cost for 1000 kWh: ₱${(priceProvider.pricePerKWH * 1000).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildDueDateSettings() {
    return Consumer<DueDateProvider>(
      builder: (context, dueDateProvider, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('DUE DATE SETTINGS'),
          const SizedBox(height: 20),
          _buildSettingItem(
            icon: Icons.calendar_today,
            iconColor: Colors.red,
            title: dueDateProvider.dueDate != null
                ? 'Due Date: ${dueDateProvider.getFormattedDueDate()}'
                : 'Set Due Date',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dueDateProvider.dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () async {
                      final success = await dueDateProvider.clearDueDate();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Due date cleared')),
                        );
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showDueDatePicker(dueDateProvider),
                ),
              ],
            ),
          ),
          if (dueDateProvider.dueDate != null) ...[
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dueDateProvider.isOverdue
                        ? 'Overdue by ${dueDateProvider.getDaysRemaining()!.abs()} days'
                        : 'Days remaining: ${dueDateProvider.getDaysRemaining()}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: dueDateProvider.isOverdue
                              ? Colors.red
                              : Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDueDatePicker(DueDateProvider dueDateProvider) async {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.darkTheme;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: dueDateProvider.dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: Theme.of(context).colorScheme.secondary,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1a2332),
                    onSurface: Colors.white,
                    secondary: Theme.of(context).colorScheme.secondary,
                  )
                : ColorScheme.light(
                    primary: Theme.of(context).colorScheme.secondary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                    secondary: Theme.of(context).colorScheme.secondary,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDarkMode ? const Color(0xFF1a2332) : Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final success = await dueDateProvider.setDueDate(pickedDate);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Due date set to ${dueDateProvider.getFormattedDueDate()}'),
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error setting due date')),
        );
      }
    }
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