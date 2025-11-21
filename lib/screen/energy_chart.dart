import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math'; // Import for max function
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'connected_devices.dart';
import 'dart:convert'; // Import for JSON decoding

// Data model for per-second readings
class PerSecondReading {
  final DateTime timestamp;
  final double totalCurrent;
  final double totalEnergy;
  final double totalPower;
  final double totalVoltage;

  PerSecondReading({
    required this.timestamp,
    required this.totalCurrent,
    required this.totalEnergy,
    required this.totalPower,
    required this.totalVoltage,
  });

  factory PerSecondReading.fromJson(Map<String, dynamic> json) {
    // Replace underscores in the timestamp key with colons for proper DateTime parsing
    final String timestampStr = json['timestamp'].toString().replaceAll('_', ':');
    return PerSecondReading(
      timestamp: DateTime.parse(timestampStr),
      totalCurrent: (json['total_current'] as num).toDouble(),
      totalEnergy: (json['total_energy'] as num).toDouble(),
      totalPower: (json['total_power'] as num).toDouble(),
      totalVoltage: (json['total_voltage'] as num).toDouble(),
    );
  }
}

enum EnergyRange { daily, weekly, monthly, perSecond }

class EnergyChart extends StatefulWidget {
  const EnergyChart({super.key});

  @override
  State<EnergyChart> createState() => _EnergyChartState();
}

class _EnergyChartState extends State<EnergyChart> {
  EnergyRange _selectedRange = EnergyRange.daily;
  final DateTime _selectedDate = DateTime.now();
  final DateTime _selectedWeekStart = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - 1),
  );
  final int _selectedMonth = DateTime.now().month;
  DateTime? _selectedDateFromChart;

  List<ConnectedDevice> _userDevices = [];

  // Hardcoded raw JSON data for per_second (for demonstration)
  // In a real application, this would be fetched dynamically.
  final String _perSecondRawData = r'''
{
  "2025-11-20T02_50_43_873181_08_00": { "timestamp": "2025-11-20T02:50:43.873181+08:00", "total_current": 0.431, "total_energy": 1.292, "total_power": 66.3, "total_voltage": 449.70000000000005 },
  "2025-11-20T02_50_43_883533_08_00": { "timestamp": "2025-11-20T02:50:43.883533+08:00", "total_current": 0.431, "total_energy": 1.292, "total_power": 66.3, "total_voltage": 449.70000000000005 },
  "2025-11-20T02_50_45_875281_08_00": { "timestamp": "2025-11-20T02:50:45.875281+08:00", "total_current": 0.426, "total_energy": 1.292, "total_power": 65.1, "total_voltage": 449.9 },
  "2025-11-20T02_50_45_887193_08_00": { "timestamp": "2025-11-20T02:50:45.887193+08:00", "total_current": 0.426, "total_energy": 1.292, "total_power": 65.1, "total_voltage": 449.9 },
  "2025-11-20T02_50_47_873791_08_00": { "timestamp": "2025-11-20T02:50:47.873791+08:00", "total_current": 0.438, "total_energy": 1.292, "total_power": 66.5, "total_voltage": 449.8 },
  "2025-11-20T02_50_47_883631_08_00": { "timestamp": "2025-11-20T02:50:47.883631+08:00", "total_current": 0.438, "total_energy": 1.292, "total_power": 66.5, "total_voltage": 449.8 },
  "2025-11-20T02_50_49_874959_08_00": { "timestamp": "2025-11-20T02:50:49.874959+08:00", "total_current": 0.438, "total_energy": 1.292, "total_power": 66.5, "total_voltage": 449.8 },
  "2025-11-20T02_50_49_892616_08_00": { "timestamp": "2025-11-20T02:50:49.892616+08:00", "total_current": 0.438, "total_energy": 1.292, "total_power": 66.5, "total_voltage": 449.8 },
  "2025-11-20T02_50_51_870788_08_00": { "timestamp": "2025-11-20T02:50:51.870788+08:00", "total_current": 0.484, "total_energy": 1.292, "total_power": 79.6, "total_voltage": 449.5 },
  "2025-11-20T02_50_51_888802_08_00": { "timestamp": "2025-11-20T02:50:51.888802+08:00", "total_current": 0.484, "total_energy": 1.292, "total_power": 79.6, "total_voltage": 449.5 },
  "2025-11-20T02_50_53_877035_08_00": { "timestamp": "2025-11-20T02:50:53.877035+08:00", "total_current": 0.5700000000000001, "total_energy": 1.292, "total_power": 97.80000000000001, "total_voltage": 449.2 },
  "2025-11-20T02_50_53_881653_08_00": { "timestamp": "2025-11-20T02:50:53.881653+08:00", "total_current": 0.5700000000000001, "total_energy": 1.292, "total_power": 97.80000000000001, "total_voltage": 449.2 },
  "2025-11-20T02_50_55_871428_08_00": { "timestamp": "2025-11-20T02:50:55.871428+08:00", "total_current": 0.532, "total_energy": 1.292, "total_power": 90.4, "total_voltage": 449.29999999999995 },
  "2025-11-20T02_50_55_875261_08_00": { "timestamp": "2025-11-20T02:50:55.875261+08:00", "total_current": 0.532, "total_energy": 1.292, "total_power": 90.4, "total_voltage": 449.29999999999995 },
  "2025-11-20T02_50_57_874203_08_00": { "timestamp": "2025-11-20T02:50:57.874203+08:00", "total_current": 0.557, "total_energy": 1.292, "total_power": 95.5, "total_voltage": 449.1 },
  "2025-11-20T02_50_57_889647_08_00": { "timestamp": "2025-11-20T02:50:57.889647+08:00", "total_current": 0.557, "total_energy": 1.292, "total_power": 95.5, "total_voltage": 449.1 },
  "2025-11-20T02_50_59_867777_08_00": { "timestamp": "2025-11-20T02:50:59.867777+08:00", "total_current": 0.557, "total_energy": 1.292, "total_power": 95.5, "total_voltage": 449.1 },
  "2025-11-20T02_50_59_873306_08_00": { "timestamp": "2025-11-20T02:50:59.873306+08:00", "total_current": 0.557, "total_energy": 1.292, "total_power": 95.5, "total_voltage": 449.1 },
  "2025-11-20T02_51_01_876335_08_00": { "timestamp": "2025-11-20T02:51:01.876335+08:00", "total_current": 0.553, "total_energy": 1.292, "total_power": 95.4, "total_voltage": 450 },
  "2025-11-20T02_51_01_890007_08_00": { "timestamp": "2025-11-20T02:51:01.890007+08:00", "total_current": 0.553, "total_energy": 1.292, "total_power": 95.4, "total_voltage": 450 },
  "2025-11-20T02_51_03_874926_08_00": { "timestamp": "2025-11-20T02:51:03.874926+08:00", "total_current": 0.504, "total_energy": 1.292, "total_power": 83.3, "total_voltage": 450.29999999999995 },
  "2025-11-20T02_51_03_886404_08_00": { "timestamp": "2025-11-20T02:51:03.886404+08:00", "total_current": 0.504, "total_energy": 1.292, "total_power": 83.3, "total_voltage": 450.29999999999995 },
  "2025-11-20T02_51_05_878841_08_00": { "timestamp": "2025-11-20T02:51:05.878841+08:00", "total_current": 0.496, "total_energy": 1.292, "total_power": 82.4, "total_voltage": 450.4 },
  "2025-11-20T02_51_05_882059_08_00": { "timestamp": "2025-11-20T02:51:05.882059+08:00", "total_current": 0.496, "total_energy": 1.292, "total_power": 82.4, "total_voltage": 450.4 },
  "2025-11-20T02_51_07_874379_08_00": { "timestamp": "2025-11-20T02:51:07.874379+08:00", "total_current": 0.512, "total_energy": 1.292, "total_power": 85, "total_voltage": 450.5 },
  "2025-11-20T02_51_07_877777_08_00": { "timestamp": "2025-11-20T02:51:07.877777+08:00", "total_current": 0.512, "total_energy": 1.292, "total_power": 85, "total_voltage": 450.5 },
  "2025-11-20T02_51_09_874646_08_00": { "timestamp": "2025-11-20T02:51:09.874646+08:00", "total_current": 0.512, "total_energy": 1.292, "total_power": 85, "total_voltage": 450.5 },
  "2025-11-20T02_51_09_886598_08_00": { "timestamp": "2025-11-20T02:51:09.886598+08:00", "total_current": 0.512, "total_energy": 1.292, "total_power": 85, "total_voltage": 450.5 },
  "2025-11-20T02_51_11_874217_08_00": { "timestamp": "2025-11-20T02:51:11.874217+08:00", "total_current": 0.487, "total_energy": 1.292, "total_power": 79, "total_voltage": 450.6 },
  "2025-11-20T02_51_11_887287_08_00": { "timestamp": "2025-11-20T02:51:11.887287+08:00", "total_current": 0.487, "total_energy": 1.292, "total_power": 79, "total_voltage": 450.6 },
  "2025-11-20T02_51_13_876980_08_00": { "timestamp": "2025-11-20T02:51:13.876980+08:00", "total_current": 0.489, "total_energy": 1.292, "total_power": 80.7, "total_voltage": 450.70000000000005 },
  "2025-11-20T02_51_13_882237_08_00": { "timestamp": "2025-11-20T02:51:13.882237+08:00", "total_current": 0.489, "total_energy": 1.292, "total_power": 80.7, "total_voltage": 450.70000000000005 },
  "2025-11-20T02_51_15_875898_08_00": { "timestamp": "2025-11-20T02:51:15.875898+08:00", "total_current": 0.45199999999999996, "total_energy": 1.292, "total_power": 72.30000000000001, "total_voltage": 450.70000000000005 },
  "2025-11-20T02_51_15_880023_08_00": { "timestamp": "2025-11-20T02:51:15.880023+08:00", "total_current": 0.45199999999999996, "total_energy": 1.292, "total_power": 72.30000000000001, "total_voltage": 450.70000000000005 },
  "2025-11-20T02_51_17_870805_08_00": { "timestamp": "2025-11-20T02:51:17.870805+08:00", "total_current": 0.44800000000000006, "total_energy": 1.292, "total_power": 71.1, "total_voltage": 450.8 },
  "2025-11-20T02_51_18_182866_08_00": { "timestamp": "2025-11-20T02:51:18.182866+08:00", "total_current": 0.43800000000000006, "total_energy": 1.292, "total_power": 69.4, "total_voltage": 451 },
  "2025-11-20T02_51_18_876930_08_00": { "timestamp": "2025-11-20T02:51:18.876930+08:00", "total_current": 0.43500000000000005, "total_energy": 1.292, "total_power": 69, "total_voltage": 451.2 },
  "2025-11-20T02_51_19_880918_08_00": { "timestamp": "2025-11-20T02:51:19.880918+08:00", "total_current": 0.43500000000000005, "total_energy": 1.292, "total_power": 69, "total_voltage": 451.2 },
  "2025-11-20T02_51_19_884210_08_00": { "timestamp": "2025-11-20T02:51:19.884210+08:00", "total_current": 0.43500000000000005, "total_energy": 1.292, "total_power": 69, "total_voltage": 451.2 },
  "2025-11-20T02_51_21_879162_08_00": { "timestamp": "2025-11-20T02:51:21.879162+08:00", "total_current": 0.43500000000000005, "total_energy": 1.292, "total_power": 69, "total_voltage": 451.2 }
}
''';

  List<PerSecondReading> _parsedPerSecondData = [];

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserDevices();
    _parsePerSecondData(); // Parse per-second data on init
  }

  void _parsePerSecondData() {
    try {
      final Map<String, dynamic> decoded = json.decode(_perSecondRawData);
      _parsedPerSecondData = decoded.entries.map((entry) {
        return PerSecondReading.fromJson(entry.value);
      }).toList();
      // Sort the data by timestamp to ensure chronological order
      _parsedPerSecondData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      // Handle JSON parsing errors
      debugPrint('Error parsing per-second data: $e');
      _parsedPerSecondData = [];
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
          icon: getIconFromCodePoint(
            data['icon'] as int? ?? Icons.devices_other.codePoint,
          ), // Use helper for tree-shaking
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

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFromChart ?? _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDateFromChart = picked;
      });
    }
  }

  List<FlSpot> _getUsageData(int hoursToShow) {
    switch (_selectedRange) {
      case EnergyRange.daily:
        if (hoursToShow < 24) {
          // For dynamic hours, show the last `hoursToShow`
          final now = DateTime.now();
          final currentHour = now.hour;
          return List.generate(hoursToShow, (index) {
            final hour =
                (currentHour - (hoursToShow - 1 - index) + 24) %
                24; // Ensure hour is positive
            return FlSpot(hour.toDouble(), 10 + (hour % 6) * 3); // Dummy data
          });
        } else {
          // For 24 hours, show the full day
          return List.generate(
            24,
            (h) => FlSpot(h.toDouble(), 10 + (h % 6) * 3),
          );
        }

      case EnergyRange.weekly:
        // 📅 Start from 0 → 6 (Mon → Sun)
        return List.generate(7, (d) {
          double usage = 20 + (d % 3) * 5; // dummy usage
          return FlSpot(d.toDouble(), usage);
        });

      case EnergyRange.monthly:
        // 🗓 Start from 1 → number of days
        final daysInMonth = DateTime(
          DateTime.now().year,
          _selectedMonth + 1,
          0,
        ).day;
        return List.generate(
          daysInMonth,
          (i) => FlSpot((i + 1).toDouble(), 30 + (i % 5) * 4),
        );
      case EnergyRange.perSecond: // Add this case
        return _getPerSecondChartData(); // Return aggregated data
    }
  }

  String _getHeaderText() {
    switch (_selectedRange) {
      case EnergyRange.daily:
        return '${_monthNames[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
      case EnergyRange.weekly:
        final end = _selectedWeekStart.add(const Duration(days: 6));
        return '${_monthNames[_selectedWeekStart.month - 1]} ${_selectedWeekStart.day} – ${_monthNames[end.month - 1]} ${end.day}, ${end.year}';
      case EnergyRange.monthly:
        return '${_monthNames[_selectedMonth - 1]}, ${DateTime.now().year}';
      case EnergyRange.perSecond: // Add this case
        return 'Minutely Power'; // A suitable header for per-second data
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    int hoursToShow;
    if (size.width < 600) {
      hoursToShow = 6;
    } else if (size.width < 800) {
      hoursToShow = 8;
    } else if (size.width < 1000) {
      hoursToShow = 12;
    } else if (size.width < 1200) {
      hoursToShow = 18;
    } else {
      hoursToShow = 24;
    }

    double totalUsage = _userDevices.fold(0, (sum, d) => sum + d.usage);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                      // Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _rangeButton(EnergyRange.daily, 'Daily'),
                        const SizedBox(width: 8),
                        _rangeButton(EnergyRange.weekly, 'Weekly'),
                        const SizedBox(width: 8),
                        _rangeButton(EnergyRange.monthly, 'Monthly'),
                        const SizedBox(width: 8),
                        _rangeButton(EnergyRange.perSecond, 'Per Second'),
                      ],
                    ),
          const SizedBox(height: 8),

          // Date Row below buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Row(
                  children: [
                    Text(
                      _selectedDateFromChart != null
                          ? '${_monthNames[_selectedDateFromChart!.month - 1]} ${_selectedDateFromChart!.day}, ${_selectedDateFromChart!.year}'
                          : _getHeaderText(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.calendar_today,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: lineChart(hoursToShow), // Pass hoursToShow to lineChart
          ),
          const SizedBox(height: 24),

          if (_selectedDateFromChart != null) ...{
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
                  children: _userDevices.map((device) {
                    double adjustedUsage = device.usage;
                    bool isOnline = device.status.toLowerCase() == "on";
                    bool isGood = adjustedUsage > 5;
                    return breakdownTile(
                      device.icon,
                      device.name,
                      '${adjustedUsage.toStringAsFixed(1)} kWh',
                      adjustedUsage / (totalUsage == 0 ? 1 : totalUsage),
                      isGood,
                      isOnline,
                    );
                  }).toList(),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }

  Widget _rangeButton(EnergyRange r, String label) {
    final sel = _selectedRange == r;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRange = r;
        _selectedDateFromChart = null;
      }),
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

  Widget lineChart(int hoursToShow) {
    final spots = _getUsageData(hoursToShow);

    double minX = 0;
    double maxX = 0;

    switch (_selectedRange) {
      case EnergyRange.daily:
        if (hoursToShow < 24) {
          final now = DateTime.now();
          final currentHour = now.hour;
          minX = (currentHour - (hoursToShow - 1)).toDouble();
          maxX = currentHour.toDouble();
        } else {
          minX = 0;
          maxX = 23;
        }
        break;
      case EnergyRange.weekly:
        minX = 0;
        maxX = 6;
        break;
      case EnergyRange.monthly:
        minX = 1;
        maxX = spots.length.toDouble();
        break;
      case EnergyRange.perSecond: // Add this case
        minX = 0;
        maxX = spots.isEmpty ? 0 : spots.last.x;
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
              interval: max(1.0, (maxX / 5).ceilToDouble()),
              getTitlesWidget: (value, _) {
                if (_selectedRange == EnergyRange.weekly) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < 7) {
                    DateTime date = _selectedWeekStart.add(Duration(days: idx));
                    return Text(
                      _weekDays[date.weekday - 1],
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }
                } else if (_selectedRange == EnergyRange.monthly) {
                  int day = value.toInt();
                  if (day >= 1 && day <= spots.length) {
                    return Text(
                      day.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    );
                  }
                } else if (_selectedRange == EnergyRange.perSecond) { // Add this else if
                  int minute = value.toInt();
                  return Text(
                    '${minute}m', // Display minutes
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                } else {
                  int hour = value.toInt();
                  // Only show titles for hours within the visible range
                  if (hour >= minX.toInt() && hour <= maxX.toInt()) {
                    String period = hour < 12 ? 'AM' : 'PM';
                    int displayHour = hour % 12;
                    if (displayHour == 0) displayHour = 12;
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
              color: Colors.teal.withAlpha((255 * 0.2).round()),
            ),
            dotData: const FlDotData(show: true),
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
                    DateTime date = _selectedWeekStart.add(
                      Duration(days: touchedSpot.x.toInt()),
                    );
                    label =
                        '${_weekDays[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
                    break;
                  case EnergyRange.monthly:
                    DateTime date = DateTime(
                      DateTime.now().year,
                      _selectedMonth,
                      touchedSpot.x.toInt(),
                    );
                    label = '${_monthNames[date.month - 1]} ${date.day}';
                    break;
                  case EnergyRange.perSecond: // Add this case
                    label = '${touchedSpot.x.toInt()} min'; // Display minute offset
                    break;
                }
                return LineTooltipItem(
                  label,
                  const TextStyle(color: Colors.white),
                );
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
                _selectedDateFromChart = DateTime(
                  DateTime.now().year,
                  _selectedMonth,
                  spot.x.toInt(),
                );
              } else if (_selectedRange == EnergyRange.weekly) {
                _selectedDateFromChart = _selectedWeekStart.add(
                  Duration(days: spot.x.toInt()),
                );
              } else if (_selectedRange == EnergyRange.perSecond) { // Add this case
                // For per-second data, we might not want to set a specific date from chart interaction
                // Or this logic needs to be re-evaluated depending on the desired behavior.
                // For now, simply break to avoid error.
                // If a specific minute should be highlighted, further logic would be needed.
              }
              else {
                _selectedDateFromChart = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  spot.x.toInt(),
                );
              }
            });
          },
        ),
      ),
    );
  }

  Widget breakdownTile(
    IconData icon,
    String label,
    String value,
    double percent,
    bool isGood,
    bool isOnline,
  ) {
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
        ),
        border: Border.all(
          color: isOnline
              ? Colors.teal.withAlpha((0.3 * 255).toInt())
              : Colors.grey.withAlpha((0.3 * 255).toInt()),
        ),
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
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isGood ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: isGood ? 'GOOD' : 'BAD',
                                style: TextStyle(
                                  color: isGood ? Colors.green : Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const TextSpan(text: ' / '),
                              TextSpan(
                                text: isOnline ? 'ON' : 'OFF',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha((0.2 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.teal.withAlpha((0.3 * 255).toInt()),
                  ),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Usage Progress',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              color: Colors.teal,
              backgroundColor: Colors.grey[700],
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _costItem(
                'Daily',
                '₱${dailyCost.toStringAsFixed(2)}',
                '${baseUsage.toStringAsFixed(1)} kWh',
              ),
              _costItem(
                'Weekly',
                '₱${weeklyCost.toStringAsFixed(2)}',
                '${(baseUsage * 7).toStringAsFixed(1)} kWh',
              ),
              _costItem(
                'Monthly',
                '₱${monthlyCost.toStringAsFixed(2)}',
                '${(baseUsage * 30).toStringAsFixed(1)} kWh',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _costItem(String period, String cost, String kwh) {
    return Column(
      children: [
        Text(
          period,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          cost,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          kwh,
          style: TextStyle(
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getPerSecondChartData() {
    if (_parsedPerSecondData.isEmpty) {
      return [];
    }
    final Map<DateTime, PerSecondReading> minuteAggregatedData = {};
    for (var reading in _parsedPerSecondData) {
      final minuteTimestamp = DateTime(
        reading.timestamp.year,
        reading.timestamp.month,
        reading.timestamp.day,
        reading.timestamp.hour,
        reading.timestamp.minute,
      );
      if (!minuteAggregatedData.containsKey(minuteTimestamp) ||
          reading.timestamp.isAfter(minuteAggregatedData[minuteTimestamp]!.timestamp)) {
        minuteAggregatedData[minuteTimestamp] = reading;
      }
    }

    final List<PerSecondReading> aggregatedReadings = minuteAggregatedData.values.toList();
    aggregatedReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (aggregatedReadings.isEmpty) return [];

    final DateTime firstTimestamp = aggregatedReadings.first.timestamp;
    return List.generate(aggregatedReadings.length, (index) {
      final reading = aggregatedReadings[index];
      final Duration difference = reading.timestamp.difference(firstTimestamp);
      return FlSpot(difference.inMinutes.toDouble(), reading.totalPower);
    });
  }
}

