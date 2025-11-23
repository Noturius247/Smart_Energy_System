import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../realtime_db_service.dart';
import '../theme_provider.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';
// import 'energy_chart.dart'; // EnergyChart is now in EnergyOverviewScreen

import 'energy_overview_screen.dart'; // New: Import the extracted EnergyOverviewScreen
import 'explore.dart'; // Import DevicesTab
import 'analytics.dart'; // Import AnalyticsScreen
import 'history.dart'; // Import EnergyHistoryScreen
import 'settings.dart'; // Import EnergySettingScreen

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final RealtimeDbService realtimeDbService;
  const HomeScreen({
    super.key,
    this.initialIndex = 0,
    required this.realtimeDbService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  late RealtimeDbService _realtimeDbService;

  late final List<Widget> _pages; // List to hold all main navigation pages

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _realtimeDbService = widget.realtimeDbService;

    // Initialize the list of pages
    _pages = [
      EnergyOverviewScreen(
          realtimeDbService:
              _realtimeDbService), // The new 'Energy' dashboard page
      DevicesTab(realtimeDbService: _realtimeDbService),
      AnalyticsScreen(realtimeDbService: _realtimeDbService),
      EnergyHistoryScreen(realtimeDbService: _realtimeDbService),
      EnergySettingScreen(realtimeDbService: _realtimeDbService),
    ];
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = _isSmallScreen(context);

    return Scaffold(
      body: isSmallScreen ? _buildMobileLayout() : _buildDesktopLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Sidebar
        CustomSidebarNav(
          currentIndex: _currentIndex,
          isBottomNav: false,
          realtimeDbService: _realtimeDbService,
          onTap: (index, page) {
            setState(() {
              _currentIndex = index;
              debugPrint('HomeScreen (Desktop): _currentIndex updated to: $_currentIndex');
            });
          },
        ),

        // Main content area using IndexedStack
        Expanded(child: _buildContentWithHeaderAndGradient()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Main content area using IndexedStack
        Expanded(child: _buildContentWithHeaderAndGradient()),

        // Bottom Navigation
        CustomSidebarNav(
          currentIndex: _currentIndex,
          isBottomNav: true,
          realtimeDbService: _realtimeDbService,
          onTap: (index, page) {
            setState(() {
              _currentIndex = index;
              debugPrint('HomeScreen (Mobile): _currentIndex updated to: $_currentIndex');
            });
          },
        ),
      ],
    );
  }

  // Helper to wrap the current page with the common header and gradient background
  Widget _buildContentWithHeaderAndGradient() {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
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
      child: Column(
        children: [
          CustomHeader(
            isSidebarOpen: false,
            isDarkMode: themeNotifier.darkTheme,
            onToggleDarkMode: themeNotifier.toggleTheme,
            realtimeDbService: _realtimeDbService,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  // Removed all previous content-related methods:
  // _buildMainContent, _currentEnergyCard, _solarProductionCard,
  // _energyConsumptionChart, _tipTile, _energyTipsSection
}
