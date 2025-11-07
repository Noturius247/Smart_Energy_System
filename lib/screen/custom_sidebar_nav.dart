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
  final bool isBottomNav;

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
  late bool isCollapsed;
  final Map<int, bool> _hoverStates = {}; // Track hover states per item

  @override
  void initState() {
    super.initState();
    isCollapsed = false; // default expanded
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> navItems = [
      {'icon': Icons.flash_on, 'label': 'Energy', 'page': const HomeScreen()},
      {'icon': Icons.devices, 'label': 'Devices', 'page': const DevicesTab()},
      {'icon': Icons.show_chart, 'label': 'Analytics', 'page': const AnalyticsScreen()},
      {'icon': Icons.schedule, 'label': 'Schedule', 'page': const EnergySchedulingScreen()},
      {'icon': Icons.settings, 'label': 'Settings', 'page': const EnergySettingScreen()},
    ];

    // Bottom Navigation (mobile)
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
                  onTap: () => widget.onTap(index, item['page']), // only navigate
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

    // Sidebar (desktop/tablet)
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
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => navItems[index]['page'],
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
},

                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.tealAccent.withValues(alpha: 0.2)
                            : _hoverStates[index]!
                                ? Colors.white24
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
                                ? Colors.tealAccent
                                : Colors.white70,
                          ),
                          if (!isCollapsed) ...[
                            const SizedBox(width: 10),
                            Text(
                              navItems[index]['label'],
                              style: TextStyle(
                                color: isSelected || _hoverStates[index]!
                                    ? Colors.tealAccent
                                    : Colors.white70,
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
                InkWell(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
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
