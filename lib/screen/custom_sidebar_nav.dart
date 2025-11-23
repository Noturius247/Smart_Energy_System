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
      HomeScreen(realtimeDbService: widget.realtimeDbService),
      DevicesTab(realtimeDbService: widget.realtimeDbService),
      AnalyticsScreen(realtimeDbService: widget.realtimeDbService),
      EnergyHistoryScreen(realtimeDbService: widget.realtimeDbService),
      EnergySettingScreen(realtimeDbService: widget.realtimeDbService),
    ];

    final List<Map<String, dynamic>> navItems = [
      {
        'icon': Icons.flash_on,
        'label': 'Energy',
      },
      {
        'icon': Icons.devices,
        'label': 'Devices',
      },
      {
        'icon': Icons.show_chart,
        'label': 'Analytics',
      },
      {
        'icon': Icons.history,
        'label': 'History',
      },
      {
        'icon': Icons.settings,
        'label': 'Settings',
      },
    ];

    // Bottom Navigation (mobile)
    if (widget.isBottomNav) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = index == widget.currentIndex;

                return InkWell(
                  onTap: () {
                    if (index != widget.currentIndex) {
                      widget.onTap(index, pages[index]);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'],
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).iconTheme.color,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'],
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 10,
                        ),
                      ),
                    ],
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
      duration: const Duration(milliseconds: 250),
      width: isCollapsed ? 80 : 200,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Column(
              children: [
                Lottie.asset(
                  'assets/Animation - 1750510706715.json',
                  height: 80,
                  repeat: true,
                  fit: BoxFit.contain,
                ),
                if (!isCollapsed) const SizedBox(height: 6),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final isSelected = index == widget.currentIndex;
                _hoverStates[index] ??= false;

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverStates[index] = true),
                  onExit: (_) => setState(() => _hoverStates[index] = false),
                  child: InkWell(
                    onTap: () {
                      if (index != widget.currentIndex) {
                        widget.onTap(index, pages[index]);
                      }
                    },

                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary.withAlpha(
                                (255 * 0.2).round(),
                              )
                            : _hoverStates[index]!
                            ? Theme.of(
                                context,
                              ).primaryColor.withAlpha((255 * 0.5).round())
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: isCollapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            navItems[index]['icon'],
                            color: isSelected || _hoverStates[index]!
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(context).iconTheme.color,
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(width: 10),
                            Text(
                              navItems[index]['label'],
                              style: TextStyle(
                                color: isSelected || _hoverStates[index]!
                                    ? Theme.of(context).colorScheme.secondary
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Display Price per kWh
          if (!widget.isBottomNav && _pricePerKWH > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 5.0,
              ),
              child: AnimatedOpacity(
                opacity: isCollapsed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  'Price/kWh: ₱${_pricePerKWH.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Collapse & Logout
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => isCollapsed = !isCollapsed),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          isCollapsed
                              ? Icons.arrow_forward_ios
                              : Icons.arrow_back_ios_new,
                          size: 16,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 8),
                          Text(
                            "Collapse",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.logout,
                          color: Theme.of(context).colorScheme.onError,
                          size: 16,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 8),
                          Text(
                            "Logout",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onError,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
