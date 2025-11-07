import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'connected_devices.dart';
import 'custom_sidebar_nav.dart';
import 'custom_header.dart';
import 'profile.dart';

enum EnergyRange { daily, weekly, monthly }

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  bool _isDarkMode = false;
  EnergyRange _selectedRange = EnergyRange.daily;
  DateTime? _selectedDateFromChart;

  late AnimationController _profileController;
  late Animation<Offset> _profileSlideAnimation;
  late Animation<double> _profileScaleAnimation;
  late Animation<double> _profileFadeAnimation;

  int _selectedMonth = DateTime.now().month;
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));

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
    _profileSlideAnimation = Tween<Offset>(
      begin: const Offset(0.2, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _profileController, curve: Curves.easeOutBack));

    _profileScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _profileController, curve: Curves.easeOutBack),
    );
    _profileFadeAnimation = CurvedAnimation(parent: _profileController, curve: Curves.easeInOut);
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
          color: sel ? Colors.teal : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.white, size: 20),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_view_month, color: Colors.white, size: 20),
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
    double totalUsage = connectedDevices.fold(0, (sum, d) => sum + d.usage);
    
    // Define the breakpoint for switching to bottom navigation (e.g., 800 pixels)
    const double breakpoint = 800;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should use the bottom navigation bar
        final isMobileLayout = constraints.maxWidth < breakpoint;

        // The main content widget (excluding the nav)
        final mainContent = Expanded(
          child: Stack(
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
                    isSidebarOpen: true,
                    onToggleDarkMode: () {
                      setState(() => _isDarkMode = !_isDarkMode);
                    },
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'Analytics',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: summaryCard('Total Consumption', '${totalUsage.toStringAsFixed(1)} kWh', '+4.2%')),
                              const SizedBox(width: 12),
                              Expanded(child: summaryCard('Cost', '₱${(totalUsage * 0.188).toStringAsFixed(2)}', '+16.5%')),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Energy Usage',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          _rangeSelector(),
                          const SizedBox(height: 12),
                          _headerWidget(),
                          const SizedBox(height: 12),
                          SizedBox(height: 200, child: lineChart()),
                          const SizedBox(height: 24),
                          if (_selectedDateFromChart != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Devices on ${_monthNames[_selectedDateFromChart!.month - 1]} ${_selectedDateFromChart!.day}, ${_selectedDateFromChart!.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Column(
                                  children: connectedDevices.map((device) {
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
                  ),
                ],
              ),
              // Profile popup
              Positioned(
                top: 70,
                right: 12,
                child: FadeTransition(
                  opacity: _profileFadeAnimation,
                  child: SlideTransition(
                    position: _profileSlideAnimation,
                    child: ScaleTransition(
                      scale: _profileScaleAnimation,
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 10,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            const CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.teal,
                                child: Icon(Icons.person,
                                    size: 30, color: Colors.white)),
                            const SizedBox(height: 12),
                            const Text(
                              'Marie Fe Tapales',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text('marie@example.com',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () async {
                                _profileController.reverse();
                                await Future.delayed(
                                    const Duration(milliseconds: 300));
                                if (!mounted) return;
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const EnergyProfileScreen()));
                              },
                              child: const Text('View Profile',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _profileController.reverse,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  minimumSize: const Size.fromHeight(36)),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
        gradient: const LinearGradient(colors: [Color(0xFF1e293b), Color(0xFF0f172a)]),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[400], fontWeight: FontWeight.w400)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 6),
          Text(change, style: const TextStyle(fontSize: 14, color: Color(0xFF10b981), fontWeight: FontWeight.w500)),
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
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12));
                }
              } else if (_selectedRange == EnergyRange.monthly) {
                int day = value.toInt();
                if (day >= 1 && day <= spots.length) {
                  return Text(day.toString(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10));
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
        style: const TextStyle(color: Colors.white, fontSize: 10),
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
          color: Colors.teal,
          barWidth: 3,
          belowBarData: BarAreaData(
            show: true,
            color: Colors.teal.withOpacity(0.2),
          ),
          dotData: FlDotData(show: true),
        ),
      ],
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.teal,
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
              response.lineBarSpots == null) return;

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
        gradient: const LinearGradient(colors: [Color(0xFF1e293b), Color(0xFF0f172a)]),
        border: Border.all(color: isOnline ? Colors.teal.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.teal : Colors.grey[700],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
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
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Usage Progress', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
                Text('${(percent * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: percent, color: Colors.teal, backgroundColor: Colors.grey[700], minHeight: 8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[800]!)),
            child: Column(
              children: [
                Text('Cost Breakdown', style: TextStyle(color: Colors.grey[300], fontSize: 14, fontWeight: FontWeight.w600)),
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
          Text(period, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(cost, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(kwh, style: TextStyle(color: Colors.teal[300], fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _verticalDivider() => Container(width: 1, height: 40, color: Colors.grey[700], margin: const EdgeInsets.symmetric(horizontal: 8));
}