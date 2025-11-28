import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'dart:async'; // Import for StreamSubscription
import '../realtime_db_service.dart';
import 'admin_home.dart';
import 'explore.dart';
import 'analytics.dart';
import 'history.dart';
import 'settings.dart';
import 'profile.dart';
import 'login.dart';

class CustomSidebarNav extends StatefulWidget {
  final int currentIndex;
  final void Function(int, Widget) onTap;
  final bool isBottomNav;
  final RealtimeDbService realtimeDbService; // New: Add RealtimeDbService

  const CustomSidebarNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isBottomNav = false,
    required this.realtimeDbService, // New: Make it required
  });

  @override
  State<CustomSidebarNav> createState() => _CustomSidebarNavState();
}

class _CustomSidebarNavState extends State<CustomSidebarNav> {
  late bool isCollapsed;
  final Map<int, bool> _hoverStates = {}; // Track hover states per item
  double _pricePerKWH = 0.0; // New state variable for price per kWh
  StreamSubscription?
  _priceSubscription; // StreamSubscription for real-time updates

  @override
  void initState() {
    super.initState();
    isCollapsed = false; // default expanded
    _listenToPricePerKWH(); // Start listening for price updates
  }

  @override
  void dispose() {
    _priceSubscription
        ?.cancel(); // Cancel the subscription when the widget is disposed
    super.dispose();
  }

  // Method to listen for price per kWh from Firestore
  void _listenToPricePerKWH() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _pricePerKWH = 0.0;
      });
      return;
    }

    _priceSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists &&
                snapshot.data()!.containsKey('pricePerKWH')) {
              setState(() {
                _pricePerKWH = (snapshot.data()!['pricePerKWH'] as num)
                    .toDouble();
              });
            } else {
              setState(() {
                _pricePerKWH = 0.0;
              });
            }
          },
          onError: (error) {
            print('Error listening to price per kWh: $error');
            setState(() {
              _pricePerKWH = 0.0; // Default in case of error
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      EnergyProfileScreen(realtimeDbService: widget.realtimeDbService),
      HomeScreen(realtimeDbService: widget.realtimeDbService),
      DevicesTab(realtimeDbService: widget.realtimeDbService),
      AnalyticsScreen(realtimeDbService: widget.realtimeDbService),
      EnergyHistoryScreen(realtimeDbService: widget.realtimeDbService),
      EnergySettingScreen(realtimeDbService: widget.realtimeDbService),
    ];

    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.person_rounded,
        'label': 'Profile',
      },
      {
        'icon': Icons.flash_on_rounded,
        'label': 'Energy',
      },
      {
        'icon': Icons.devices_rounded,
        'label': 'Devices',
      },
      {
        'icon': Icons.show_chart_rounded,
        'label': 'Analytics',
      },
      {
        'icon': Icons.history_rounded,
        'label': 'History',
      },
      {
        'icon': Icons.settings_rounded,
        'label': 'Settings',
      },
    ];

    // Bottom Navigation (mobile)
    if (widget.isBottomNav) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == widget.currentIndex;

                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (index != widget.currentIndex) {
                          widget.onTap(index, pages[index]);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item['icon'],
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).iconTheme.color?.withValues(alpha: 0.6),
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                fontSize: isSelected ? 11 : 10,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                              child: Text(
                                item['label'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    }

    // Sidebar (desktop/tablet)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 80 : 240,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: isCollapsed ? 60 : 80,
                  child: Lottie.asset(
                    'assets/Animation - 1750510706715.json',
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Energy Monitor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final isSelected = index == widget.currentIndex;
                  _hoverStates[index] ??= false;

                  return MouseRegion(
                    onEnter: (_) => setState(() => _hoverStates[index] = true),
                    onExit: (_) => setState(() => _hoverStates[index] = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (index != widget.currentIndex) {
                              widget.onTap(index, pages[index]);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: isCollapsed ? 16 : 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                                        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : null,
                              color: _hoverStates[index]!
                                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border(
                                      left: BorderSide(
                                        color: Theme.of(context).colorScheme.secondary,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: isCollapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    navItems[index]['icon'],
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.secondary
                                        : _hoverStates[index]!
                                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8)
                                            : Theme.of(context).iconTheme.color?.withValues(alpha: 0.7),
                                    size: 24,
                                  ),
                                ),
                                if (!isCollapsed) ...[
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Theme.of(context).colorScheme.secondary
                                            : _hoverStates[index]!
                                                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8)
                                                : Theme.of(context).textTheme.bodyMedium?.color,
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        letterSpacing: 0.2,
                                      ),
                                      child: Text(navItems[index]['label']),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Display Price per kWh
          if (!widget.isBottomNav && _pricePerKWH > 0)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: AnimatedOpacity(
                opacity: isCollapsed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Current Rate',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₱${_pricePerKWH.toStringAsFixed(2)}/kWh',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Collapse & Logout
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => isCollapsed = !isCollapsed),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isCollapsed) ...[
                            Text(
                              "Collapse",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          Icon(
                            isCollapsed
                                ? Icons.keyboard_double_arrow_right_rounded
                                : Icons.keyboard_double_arrow_left_rounded,
                            size: 20,
                            color: Theme.of(context).iconTheme.color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AuthPage(
                            realtimeDbService: widget.realtimeDbService,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.error,
                            Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Theme.of(context).colorScheme.onError,
                            size: 20,
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(width: 12),
                            Text(
                              "Logout",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onError,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
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
