import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'admin_home.dart';
import 'explore.dart';
import 'analytics.dart';
import 'schedule.dart';
import 'settings.dart';
import 'login.dart';

class CustomSidebarNav extends StatefulWidget {
  final int currentIndex;
  final void Function(int, Widget) onTap;
  final bool isBottomNav; // ✅ New parameter to switch between sidebar and bottom nav

  const CustomSidebarNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isBottomNav = false,
  });

  @override
  State<CustomSidebarNav> createState() => _CustomSidebarNavState();
}

class _CustomSidebarNavState extends State<CustomSidebarNav> {
  bool isCollapsed = true;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.flash_on, 'label': 'Energy', 'page': const HomeScreen()},
      {'icon': Icons.devices, 'label': 'Devices', 'page': const DevicesTab()},
      {'icon': Icons.show_chart, 'label': 'Analytics', 'page': const AnalyticsScreen()},
      {'icon': Icons.schedule, 'label': 'Schedule', 'page': const EnergySchedulingScreen()},
      {'icon': Icons.settings, 'label': 'Settings', 'page': const EnergySettingScreen()},
    ];

    // ✅ Bottom Navigation Layout for Mobile
    if (widget.isBottomNav) {
      return Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1e293b),
          border: Border(top: BorderSide(color: Colors.white24, width: 1)),
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
                  onTap: () => widget.onTap(index, item['page']),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'],
                        color: isSelected ? Colors.tealAccent : Colors.white70,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['label'],
                        style: TextStyle(
                          color: isSelected ? Colors.tealAccent : Colors.white70,
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

    // ✅ Sidebar Layout for Desktop/Tablet
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isCollapsed ? 80 : 200,
      decoration: const BoxDecoration(
        color: Color(0xFF1e293b),
        border: Border(right: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ Top Logo Section
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Lottie.asset(
                  'assets/Animation - 1750510706715.json',
                  height: 60,
                  repeat: true,
                  fit: BoxFit.contain,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),

          // ✅ Navigation Items
          Expanded(
            child: ListView.builder(
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final isSelected = index == widget.currentIndex;
                return InkWell(
                  onTap: () => widget.onTap(index, navItems[index]['page']),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.tealAccent.withValues(alpha: 0.2)
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
                          color: isSelected ? Colors.tealAccent : Colors.white70,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 10),
                          Text(
                            navItems[index]['label'],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.tealAccent
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ✅ Collapse and Logout Buttons
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                // Collapse / Expand Button
                InkWell(
                  onTap: () {
                    setState(() {
                      isCollapsed = !isCollapsed;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
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
                          color: Colors.white70,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 8),
                          const Text(
                            "Collapse",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Logout Button
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: isCollapsed
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      children: [
                        const Icon(Icons.logout, color: Colors.white, size: 16),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 8),
                          const Text(
                            "Logout",
                            style: TextStyle(color: Colors.white, fontSize: 12),
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