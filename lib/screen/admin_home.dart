
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:provider/provider.dart'; // Import provider
import '../theme_provider.dart'; // Import ThemeNotifier
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';
import 'energy_chart.dart';


class HomeScreen extends StatefulWidget {
  final int initialIndex;
  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 600; // Define your small screen breakpoint
  }

  @override
  Widget build(BuildContext context) {
    // Check screen width to determine layout
    final isSmallScreen = _isSmallScreen(context);

    return Scaffold(
      body: isSmallScreen
          ? _buildMobileLayout()
          : _buildDesktopLayout(),
    );
  }

  // Desktop Layout (Sidebar on Left)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // ✅ Left Sidebar
        CustomSidebarNav(
          currentIndex: _currentIndex,
          isBottomNav: false,
          onTap: (index, page) {
            setState(() => _currentIndex = index);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
          },
        ),

        // ✅ Main content
        Expanded(child: _buildMainContent()),
      ],
    );
  }

  // Mobile Layout (Bottom Navigation)
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // ✅ Main content
        Expanded(child: _buildMainContent()),

        // ✅ Bottom Navigation
        CustomSidebarNav(
          currentIndex: _currentIndex,
          isBottomNav: true,
          onTap: (index, page) {
            setState(() => _currentIndex = index);
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
          },
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    final themeNotifier = Provider.of<ThemeNotifier>(context); // Access ThemeNotifier
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
            isDarkMode: themeNotifier.darkTheme, // Pass global theme state
            onToggleDarkMode: themeNotifier.toggleTheme, // Pass global toggle method
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _currentEnergyCard()),
                      const SizedBox(width: 10),
                      _solarProductionCard(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _energyConsumptionChart(),
                  const SizedBox(height: 12),
                  _energyTipsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------- Dashboard Cards & Sections ----------------------
  
  Widget _currentEnergyCard() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy - hh:mm a').format(now);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Energy Usage', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text('24.8 kWh', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('+2.5% less than yesterday', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 50,
                width: 50,
                child: CircularProgressIndicator(
                  value: 0.7,
                  color: Theme.of(context).colorScheme.secondary,
                  backgroundColor: Theme.of(context).primaryColor.withAlpha((255 * 0.2).round()),
                  strokeWidth: 5,
                ),
              ),
              Text('70%', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _solarProductionCard() {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Consumption', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('8.2 kWh', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          LinearProgressIndicator(value: 0.7, backgroundColor: Theme.of(context).primaryColor.withAlpha((255 * 0.2).round()), color: Theme.of(context).colorScheme.secondary, minHeight: 5),
          const SizedBox(height: 3),
          Text('Consume hours: 5.2 hrs', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _energyConsumptionChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Energy Consumption",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const EnergyChart(),
        ],
      ),
    );
  }

  // ---------------------- Helper Widgets ----------------------
  Widget _tipTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _energyTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Smart Energy Tips',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _tipTile(Icons.battery_charging_full, 'Unplug Chargers',
            'Unplug devices once fully charged to avoid phantom load.'),
        const SizedBox(height: 6),
        _tipTile(Icons.ac_unit, 'Efficient AC Use', 'Set air conditioners between 24–25°C for efficiency.'),
        const SizedBox(height: 6),
        _tipTile(Icons.lightbulb, 'Switch to LED', 'LED bulbs use up to 80% less energy than incandescent bulbs.'),
        const SizedBox(height: 6),
        _tipTile(Icons.local_laundry_service, 'Run Full Loads',
            'Washers and dishwashers are most efficient when fully loaded.'),
        const SizedBox(height: 6),
        _tipTile(Icons.power, 'Use Smart Plugs', 'Monitor and control appliances remotely with smart plugs.'),
      ],
    );
  }
}