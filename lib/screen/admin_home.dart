
import 'package:flutter/material.dart';
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
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    // Check screen width to determine layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768; // Tablet/Mobile breakpoint

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
        ),

        Column(
          children: [
            CustomHeader(
              isDarkMode: _isDarkMode,
              isSidebarOpen: false,
              onToggleDarkMode: () {
                setState(() {
                  _isDarkMode = !_isDarkMode;
                });
              },
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
      ],
    );
  }

  // ---------------------- Dashboard Cards & Sections ----------------------

  Widget _currentEnergyCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1e293b), Color(0xFF0f172a)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Current Energy Usage', style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 6),
                Text('24.8 kWh', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('+2.5% less than yesterday', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                  color: Colors.greenAccent,
                  backgroundColor: Colors.white24,
                  strokeWidth: 5,
                ),
              ),
              const Text('70%', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
        gradient: const LinearGradient(colors: [Color(0xFF1e293b), Color(0xFF0f172a)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Monthly Consumption', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
          SizedBox(height: 6),
          Text('8.2 kWh', style: TextStyle(fontSize: 16, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
          SizedBox(height: 3),
          LinearProgressIndicator(value: 0.7, backgroundColor: Colors.white24, color: Colors.orangeAccent, minHeight: 5),
          SizedBox(height: 3),
          Text('Consume hours: 5.2 hrs', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _energyConsumptionChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1e293b), Color(0xFF0f172a)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Energy Consumption",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 10),
          EnergyChart(),
        ],
      ),
    );
  }

  // ---------------------- Helper Widgets ----------------------
  Widget _tipTile(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1e293b),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.tealAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
        const Text('Smart Energy Tips',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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