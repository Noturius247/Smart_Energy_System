import 'dart:async'; // Added for StreamSubscription
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme_provider.dart';

import '../realtime_db_service.dart';
import 'connected_devices.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';

class AnalyticsScreen extends StatefulWidget {
  final RealtimeDbService realtimeDbService;
  const AnalyticsScreen({super.key, required this.realtimeDbService});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}


enum AnalyticsMetric { current, voltage, power, energy }

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  late AnimationController _profileController;
  late final RealtimeDbService _realtimeDbService;
  List<ConnectedDevice> _userDevices = [];
  final Map<AnalyticsMetric, StreamSubscription<List<TimestampedFlSpot>>> _subscriptions = {};
  bool _isLoading = true;
  DateTime? _dueDate;
  int? _daysUntilDue;
  DateTime? _lastUpdated;

  final Map<AnalyticsMetric, List<TimestampedFlSpot>> _chartData = {
    AnalyticsMetric.current: [],
    AnalyticsMetric.voltage: [],
    AnalyticsMetric.power: [],
    AnalyticsMetric.energy: [],
  };
  final Map<AnalyticsMetric, double> _metricValues = {
    AnalyticsMetric.current: 0.0,
    AnalyticsMetric.voltage: 0.0,
    AnalyticsMetric.power: 0.0,
    AnalyticsMetric.energy: 0.0,
  };

  IconData getIconFromCodePoint(int codePoint) {
    return IconData(codePoint, fontFamily: 'MaterialIcons');
  }

  @override
  void initState() {
    super.initState();

    _profileController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _realtimeDbService = widget.realtimeDbService;
    _fetchUserDevices().then((_) {
      _listenToAnalyticsData();
    });
    _loadDueDate();
  }

  Future<void> _loadDueDate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('dueDate')) {
        setState(() {
          _dueDate = (doc.data()!['dueDate'] as Timestamp).toDate();
          final difference = _dueDate!.difference(DateTime.now()).inDays;
          _daysUntilDue = difference >= 0 ? difference : null;
        });
      }
    } catch (e) {
      // Handle error, maybe show a snackbar
      debugPrint('Error loading due date: $e');
    }
  }

  Future<void> _fetchUserDevices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _userDevices = [];
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .get();

      final fetchedDevices = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return ConnectedDevice(
          name: data['name'] ?? 'Unknown Device',
          status: data['status'] ?? 'off',
          icon: getIconFromCodePoint(data['icon'] as int? ?? Icons.devices_other.codePoint),
          usage: (data['usage'] as num?)?.toDouble() ?? 0.0,
          percent: (data['percent'] as num?)?.toDouble() ?? 0.0,
          plug: (data['plug'] ?? 1).toString(),
          serialNumber: data['serialNumber']?.toString(),
        );
      }).toList();

      setState(() {
        _userDevices = fetchedDevices;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching devices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _listenToAnalyticsData() {
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();

    setState(() {
      _isLoading = true;
      for (var key in _chartData.keys) {
        _chartData[key] = [];
      }
      for (var key in _metricValues.keys) {
        _metricValues[key] = 0.0;
      }
    });

    if (_userDevices.isEmpty || _userDevices.first.serialNumber == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final String hubSerialNumber = _userDevices.first.serialNumber!;
    
    int loadedMetrics = 0;
    for (var metric in AnalyticsMetric.values) {
      final subscription = _realtimeDbService
          .getAnalyticsDataStream(hubSerialNumber, metric.name)
          .listen((spots) {
        if (!mounted) return;
        
        double value;
        if (metric == AnalyticsMetric.energy) {
          value = spots.fold(0.0, (total, spot) => total + spot.y);
        } else {
          value = spots.isEmpty ? 0.0 : spots.fold(0.0, (total, spot) => total + spot.y) / spots.length;
        }

        setState(() {
          _chartData[metric] = spots;
          _metricValues[metric] = value;
          loadedMetrics++;
          if (loadedMetrics == AnalyticsMetric.values.length) {
            _isLoading = false;
            _lastUpdated = DateTime.now();
          }
        });
      }, onError: (error) {
        debugPrint('Error listening to analytics data for $metric: $error');
        if (!mounted) return;
        setState(() {
          _chartData[metric] = [];
          _metricValues[metric] = 0.0;
          loadedMetrics++;
          if (loadedMetrics == AnalyticsMetric.values.length) {
            _isLoading = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics for $metric: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
      _subscriptions[metric] = subscription;
    }
  }

  @override
  void dispose() {
    _profileController.dispose();
    for (var sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    // Define the breakpoint for switching to bottom navigation (e.g., 800 pixels)
    const double breakpoint = 800;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should use the bottom navigation bar
        final isMobileLayout = constraints.maxWidth < breakpoint;

        // The main content widget (excluding the nav)
        final mainContent = Expanded(
          child: Container(
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
                  isSidebarOpen: true,
                  isDarkMode: Provider.of<ThemeNotifier>(context).darkTheme,
                  onToggleDarkMode: () {
                    Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
                  },
                  realtimeDbService: _realtimeDbService,
                ),
               Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          'Analytics',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildDueDateCard(),
                        const SizedBox(height: 16),
                        _buildChart(AnalyticsMetric.energy, 'Total Consumption', 'kWh'),
                        const SizedBox(height: 16),
                        _buildChart(AnalyticsMetric.power, 'Average Power', 'W'),
                        const SizedBox(height: 16),
                        _buildChart(AnalyticsMetric.voltage, 'Average Voltage', 'V'),
                        const SizedBox(height: 16),
                        _buildChart(AnalyticsMetric.current, 'Average Current', 'A'),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        );

        // Build the appropriate layout based on screen size
        if (isMobileLayout) {
          // Mobile/Small Screen Layout: Column with Bottom Navigation Bar
          return Scaffold(
            body: mainContent,
            bottomNavigationBar: CustomSidebarNav(
              currentIndex: 2,
              realtimeDbService: _realtimeDbService,
              onTap: (index, page) {
                if (index != 2) {
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => page),
                  );
                }
              },
              isBottomNav: true,
            ),
          );
        } else {
          // Desktop/Tablet Layout: Row with Sidebar
          return Scaffold(
            body: Row(
              children: [
                // Sidebar on the left
                CustomSidebarNav(
                  currentIndex: 2,
                  realtimeDbService: _realtimeDbService,
                  onTap: (index, page) {
                    if (index != 2) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => page),
                      );
                    }
                  },
                ),
                // Main content on the right
                mainContent,
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildDueDateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.3).round()), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Billing Due Date',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (_dueDate != null)
                Text(
                  '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
                )
              else
                Text(
                  'Not Set',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          if (_daysUntilDue != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Days Remaining',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_daysUntilDue',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChart(AnalyticsMetric metric, String title, String unit) {
    final spots = _chartData[metric]!;
    final value = _metricValues[metric]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Last Updated: ${DateFormat('MMM d, yyyy hh:mm:ss a').format(_lastUpdated!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        summaryCard(title, '${value.toStringAsFixed(1)} $unit', '+0.0%'), // placeholder for change
        const SizedBox(height: 8),
        SizedBox(
          height: 300, // Doubled the height
          child: lineChart(spots),
        ),
      ],
    );
  }


  Widget summaryCard(String title, String value, String change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.3).round()), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(change, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget lineChart(List<TimestampedFlSpot> spots) {
  final double maxY = spots.isEmpty ? 50 : spots.map((spot) => spot.y).reduce(max) * 1.2;

  return LineChart(
    LineChartData(
      minX: 0,
      maxX: 60,
      minY: 0,
      maxY: maxY,
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            getTitlesWidget: (value, _) {
              return Text(
                '${value.toInt()}s',
                style: Theme.of(context).textTheme.bodyMedium,
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.secondary,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.2).round()),
          ),
          dotData: const FlDotData(show: true),
        ),
      ],
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Theme.of(context).colorScheme.secondary,
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final spot = spots[barSpot.spotIndex];
              final formattedTime = DateFormat('HH:mm:ss').format(spot.timestamp);
                            return LineTooltipItem(
                              '${spot.y.toStringAsFixed(2)}\n$formattedTime',
                              const TextStyle(color: Colors.white),
                            );
            }).toList();
          },
        ),
      ),
    ),
  );
}

  Widget breakdownTile(IconData icon, String label, String value, double percent, bool isOnline, String status) {
    double baseUsage = double.parse(value.replaceAll(' kWh', ''));
    double ratePerKwh = 11.50;
    double dailyCost = baseUsage * ratePerKwh;
    double weeklyCost = dailyCost * 7;
    double monthlyCost = dailyCost * 30;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        border: Border.all(color: isOnline ? Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.3).round()) : Colors.grey.withAlpha((255 * 0.3).round())),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((255 * 0.3).round()), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isOnline ? Theme.of(context).colorScheme.secondary : Colors.grey[700],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(status, style: TextStyle(color: isOnline ? Colors.green[300] : Colors.red[300], fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.secondary.withAlpha((255 * 0.3).round())),
                ),
                child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Usage Progress', style: Theme.of(context).textTheme.bodyMedium),
                Text('${(percent * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: percent, color: Theme.of(context).colorScheme.secondary, backgroundColor: Colors.grey[700], minHeight: 8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black.withAlpha((255 * 0.2).round()), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[800]!)),
            child: Column(
              children: [
                Text('Cost Breakdown', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _costItem('Daily', '₱${dailyCost.toStringAsFixed(2)}', '${baseUsage.toStringAsFixed(1)} kWh'),
                    _verticalDivider(),
                    _costItem('Weekly', '₱${weeklyCost.toStringAsFixed(2)}', '${(baseUsage*7).toStringAsFixed(1)} kWh'),
                    _verticalDivider(),
                    _costItem('Monthly', '₱${monthlyCost.toStringAsFixed(2)}', '${(baseUsage*30).toStringAsFixed(1)} kWh'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costItem(String period, String cost, String kwh) {
    return Expanded(
      child: Column(
        children: [
          Text(period, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(cost, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(kwh, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(width: 1, height: 40, color: Colors.grey[700], margin: const EdgeInsets.symmetric(horizontal: 8));
}