import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import 'package:cloud_firestore/cloud_firestore.dart'; // Added import
import '../theme_provider.dart';
import 'connected_devices.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';

enum EnergyRange { daily, weekly, monthly }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  EnergyRange _selectedRange = EnergyRange.daily;
  DateTime? _selectedDateFromChart;

  late AnimationController _profileController;

  int _selectedMonth = DateTime.now().month;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

  List<ConnectedDevice> _userDevices = []; // New list to hold user-specific devices

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _weekDays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

  @override
  void initState() {
    super.initState();
    _profileController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fetchUserDevices(); // Fetch devices when the widget initializes
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
          icon: data['icon'] != null ? IconData(data['icon'], fontFamily: 'MaterialIcons') : Icons.devices_other,
          usage: (data['usage'] as num?)?.toDouble() ?? 0.0,
          percent: (data['percent'] as num?)?.toDouble() ?? 0.0,
          plug: data['plug'] ?? 1,
          serialNumber: data['serialNumber'],
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

  @override
  void dispose() {
    _profileController.dispose();
    super.dispose();
  }

  Widget _rangeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _rangeButton(EnergyRange.daily, 'Daily'),
        const SizedBox(width: 8),
        _rangeButton(EnergyRange.weekly, 'Weekly'),
        const SizedBox(width: 8),
        _rangeButton(EnergyRange.monthly, 'Monthly'),
      ],
    );
  }

  Widget _rangeButton(EnergyRange r, String label) {
    final sel = _selectedRange == r;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? Theme.of(context).colorScheme.secondary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _headerWidget() {
    switch (_selectedRange) {
      case EnergyRange.daily:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${_monthNames[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.calendar_today, color: Theme.of(context).iconTheme.color, size: 20),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(() => _selectedDate = picked);
                }
              },
            )
          ],
        );
      case EnergyRange.weekly:
        final end = _selectedWeekStart.add(const Duration(days: 6));
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${_monthNames[_selectedWeekStart.month - 1]} ${_selectedWeekStart.day} – ${_monthNames[end.month - 1]} ${end.day}, ${end.year}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.calendar_month, color: Theme.of(context).iconTheme.color, size: 20),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedWeekStart,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  final monday = picked.subtract(Duration(days: picked.weekday - 1));
                  setState(() => _selectedWeekStart = monday);
                }
              },
            )
          ],
        );
      case EnergyRange.monthly:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${_monthNames[_selectedMonth - 1]}, ${DateTime.now().year}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.calendar_view_month, color: Theme.of(context).iconTheme.color, size: 20),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(DateTime.now().year, _selectedMonth, 1),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null && mounted) {
                  setState(() => _selectedMonth = picked.month);
                }
              },
            )
          ],
        );
    }
  }

  List<FlSpot> _getUsageData() {
    switch (_selectedRange) {
      case EnergyRange.daily:
        return List.generate(24, (h) => FlSpot(h.toDouble(), 10 + (h % 6) * 3));
      case EnergyRange.weekly:
        return List.generate(7, (d) => FlSpot(d.toDouble(), 20 + (d % 3) * 5));
      case EnergyRange.monthly:
        final daysInMonth = DateTime(DateTime.now().year, _selectedMonth + 1, 0).day;
        return List.generate(daysInMonth, (i) => FlSpot((i + 1).toDouble(), 30 + (i % 5) * 4));
    }
  }

 @override
  Widget build(BuildContext context) {
    double totalUsage = _userDevices.fold(0, (sum, d) => sum + d.usage);
    
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
                ),
               Expanded(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(8), // reduced padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10), // smaller spacing
        Text(
          'Analytics',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: summaryCard('Total Consumption', '${totalUsage.toStringAsFixed(1)} kWh', '+4.2%')),
            const SizedBox(width: 8), // reduced width
            Expanded(child: summaryCard('Cost', '₱${(totalUsage * 0.188).toStringAsFixed(2)}', '+16.5%')),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Energy Usage',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        _rangeSelector(),
        const SizedBox(height: 8),
        _headerWidget(),
        const SizedBox(height: 8),
        SizedBox(height: 150, child: lineChart()), // smaller chart height
        const SizedBox(height: 16),
        if (_selectedDateFromChart != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Devices on ${_monthNames[_selectedDateFromChart!.month - 1]} ${_selectedDateFromChart!.day}, ${_selectedDateFromChart!.year}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Column(
                children: _userDevices.map((device) {
                  double adjustedUsage = device.usage;
                  bool isOnline = true;
                  String status = "Good";

                  return breakdownTile(
                    device.icon,
                    device.name,
                    '${adjustedUsage.toStringAsFixed(1)} kWh',
                    adjustedUsage / totalUsage,
                    isOnline,
                    status,
                  );
                }).toList(),
              ),
            ],
          ),
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
              onTap: (index, page) {
                if (index != 2) {
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => page),
                  );
                }
              },
              isBottomNav: true, // Use the bottom navigation layout
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

  Widget lineChart() {
  final spots = _getUsageData();

  // Correct minX and maxX for all ranges
  double minX = 0;
  double maxX = 0;

  switch (_selectedRange) {
    case EnergyRange.daily:
      minX = 0;
      maxX = 23;
      break;
    case EnergyRange.weekly:
      minX = 0;
      maxX = 6; // last index of week
      break;
    case EnergyRange.monthly:
      minX = 1;
      maxX = spots.length.toDouble(); // number of days in month
      break;
  }

  return LineChart(
    LineChartData(
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: 50,
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, _) {
              if (_selectedRange == EnergyRange.weekly) {
                int idx = value.toInt();
                if (idx >= 0 && idx < 7) {
                  return Text(_weekDays[idx],
                      style: Theme.of(context).textTheme.bodyMedium);
                }
              } else if (_selectedRange == EnergyRange.monthly) {
                int day = value.toInt();
                if (day >= 1 && day <= spots.length) {
                  return Text(day.toString(),
                      style: Theme.of(context).textTheme.bodyMedium);
                }
              }  else {
    // Daily: show 12:00 AM → 11:59 PM
    int hour = value.toInt();
    if (hour >= 0 && hour < 24) {
      String period = hour < 12 ? 'AM' : 'PM';
      int displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;

      // Label for first hour is 12:00 AM, last hour shows 11:59 PM
      String label = hour == 23
          ? '$displayHour:59 $period'
          : '$displayHour:00 $period';

      return Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
  }
              return const SizedBox();
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
          dotData: FlDotData(show: true),
        ),
      ],
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Theme.of(context).colorScheme.secondary,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((touchedSpot) {
              String label = '';
              switch (_selectedRange) {
                case EnergyRange.daily:
                  label = '${touchedSpot.x.toInt()}:00';
                  break;
                case EnergyRange.weekly:
                  DateTime date =
                      _selectedWeekStart.add(Duration(days: touchedSpot.x.toInt()));
                  label =
                      '${_weekDays[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
                  break;
                case EnergyRange.monthly:
                  DateTime date =
                      DateTime(DateTime.now().year, _selectedMonth, touchedSpot.x.toInt());
                  label = '${_monthNames[date.month - 1]} ${date.day}';
                  break;
              }
              return LineTooltipItem(label, const TextStyle(color: Colors.white));
            }).toList();
          },
        ),
        touchCallback: (event, response) {
          if (!event.isInterestedForInteractions ||
              response == null ||
              response.lineBarSpots == null) {
            return;
          }

          setState(() {
            final spot = response.lineBarSpots!.first;
            if (_selectedRange == EnergyRange.monthly) {
              _selectedDateFromChart =
                  DateTime(DateTime.now().year, _selectedMonth, spot.x.toInt());
            } else if (_selectedRange == EnergyRange.weekly) {
              _selectedDateFromChart =
                  _selectedWeekStart.add(Duration(days: spot.x.toInt()));
            } else {
              _selectedDateFromChart = DateTime(
                  _selectedDate.year, _selectedDate.month, _selectedDate.day, spot.x.toInt());
            }
          });
        },
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