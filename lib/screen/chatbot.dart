import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../theme_provider.dart';
import '../theme_provider.dart' show darkTheme;
import '../services/chatbot_data_service.dart';
import '../constants.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Connection status tracking
  bool _isOnline = false;
  final int _connectionAlertMinutes = 5;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  // Data service for fetching dynamic data
  final ChatbotDataService _dataService = ChatbotDataService();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
    _slideController.forward();

    // Start monitoring connection status
    _monitorConnectionStatus();

    // Welcome message with system status
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        final welcomeMsg = await _generateWelcomeMessage();
        if (mounted) {
          setState(() {
            _messages.add({
              "sender": "bot",
              "message": welcomeMsg,
            });
          });
        }
      }
    });
  }

  void _monitorConnectionStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isOnline = false;
      });
      return;
    }

    // Monitor the latest data from Firebase to determine connection status
    // Use the correct path from constants.dart and filter by ownerId
    final databaseRef = FirebaseDatabase.instance
        .ref('$rtdbUserPath/hubs')
        .orderByChild('ownerId')
        .equalTo(user.uid);

    _connectionSubscription = databaseRef.onValue.listen((event) {
      if (!mounted) return;

      if (event.snapshot.value != null) {
        try {
          final hubsData = Map<String, dynamic>.from(event.snapshot.value as Map);
          DateTime? latestTimestamp;
          bool hasRecentData = false;

          // Find the most recent data update across user's hubs
          // Data is stored under plugs/{plugId}/data, not directly under hub/data
          for (var hubEntry in hubsData.entries) {
            final hubData = hubEntry.value as Map?;
            if (hubData == null) continue;

            // Check plug data for recent timestamps
            final plugsMap = hubData['plugs'] as Map?;
            if (plugsMap != null) {
              for (var plugEntry in plugsMap.values) {
                if (plugEntry is Map && plugEntry['data'] != null) {
                  final plugData = plugEntry['data'] as Map?;
                  if (plugData != null && plugData['lastUpdate'] != null) {
                    try {
                      // Use lastUpdate timestamp (milliseconds since epoch)
                      final lastUpdateMs = plugData['lastUpdate'] as num?;
                      if (lastUpdateMs != null) {
                        final timestamp = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs.toInt());

                        // Check if this data is recent (within last 5 minutes)
                        final minutesSinceUpdate = DateTime.now().difference(timestamp).inMinutes;
                        if (minutesSinceUpdate < _connectionAlertMinutes) {
                          hasRecentData = true;
                        }

                        if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
                          latestTimestamp = timestamp;
                        }
                      }
                    } catch (e) {
                      debugPrint('Error parsing timestamp: $e');
                    }
                  }
                }
              }
            }
          }

          if (mounted) {
            setState(() {
              _isOnline = hasRecentData && latestTimestamp != null;
            });
          }
        } catch (e) {
          debugPrint('Connection monitoring error (parsing): $e');
          if (mounted) {
            setState(() {
              _isOnline = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isOnline = false;
          });
        }
      }
    }, onError: (error) {
      debugPrint('Connection monitoring error (stream): $error');
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userMessage = _controller.text.trim();
    setState(() {
      _messages.add({"sender": "user", "message": userMessage});
      _isTyping = true;
    });

    _controller.clear();
    _scrollToBottom();

    // Generate bot response with dynamic data
    try {
      final response = await _generateBotResponse(userMessage);
      if (mounted) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "message": response,
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "message": "Sorry, I encountered an error while fetching data. Please try again.",
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<String> _generateBotResponse(String userMessage) async {
    final msg = userMessage.toLowerCase();

    // === DYNAMIC DATA QUERIES ===

    // Quick shorthand queries
    if (msg == 'status' || msg == 'overview' || msg == 'dashboard') {
      final metrics = await _dataService.getCurrentEnergyMetrics();
      final dailyData = await _dataService.getDailyEnergyAndCost();
      final hubs = await _dataService.getUserHubs();

      if (metrics == null || metrics['online'] == false) {
        return "⚠️ System Status: Offline\n\n"
            "Hubs: ${hubs.length}\n"
            "Waiting for hub data... Please ensure hubs are connected.";
      }

      final power = metrics['power'] as double;
      final energy = metrics['energy'] as double;
      final dailyCost = dailyData['cost'] as double;

      return "📊 System Overview:\n\n"
          "⚡ Current Power: ${power.toStringAsFixed(2)} W\n"
          "💡 Total Energy: ${energy.toStringAsFixed(2)} kWh\n"
          "💰 Today's Cost: ₱${dailyCost.toStringAsFixed(2)}\n"
          "🔗 Active Hubs: ${metrics['activeHubs']}\n"
          "🔌 Devices: ${(await _dataService.getUserDevices()).length}";
    }

    // Simple "how much" queries
    if ((msg.contains('how much') || msg.contains('what') || msg.contains('tell me')) &&
        (msg.contains('spending') || msg.contains('spent') || msg.contains('cost today'))) {
      final dailyData = await _dataService.getDailyEnergyAndCost();
      final cost = dailyData['cost'] as double;
      final energy = dailyData['energy'] as double;

      return "💰 Today's Spending:\n\n"
          "₱${cost.toStringAsFixed(2)}\n\n"
          "Energy used: ${energy.toStringAsFixed(2)} kWh\n"
          "Based on consumption since midnight.";
    }

    // Energy/power now queries
    if ((msg.contains('power') || msg.contains('energy') || msg.contains('usage')) &&
        (msg.contains('now') || msg.contains('right now') || msg.contains('currently'))) {
      final metrics = await _dataService.getCurrentEnergyMetrics();
      if (metrics == null || metrics['online'] == false) {
        return "⚠️ Unable to get current reading.\n\nPlease ensure hubs are connected and sending data.";
      }

      final power = metrics['power'] as double;
      return "⚡ Current Power Usage:\n\n${power.toStringAsFixed(2)} Watts\n\nUpdated just now!";
    }

    // Current energy usage
    if (msg.contains('current') && (msg.contains('usage') || msg.contains('energy') || msg.contains('power'))) {
      final metrics = await _dataService.getCurrentEnergyMetrics();
      if (metrics == null) {
        return "❌ Unable to fetch energy data. Please make sure you're logged in and have hubs connected.";
      }
      if (metrics['online'] == false) {
        return "⚠️ ${metrics['message']}\n\nPlease ensure:\n• At least one hub is connected\n• Hub is powered on and connected to internet\n• Hub has reported data within the last 5 minutes";
      }

      final power = metrics['power'] as double;
      final voltage = metrics['voltage'] as double;
      final current = metrics['current'] as double;
      final energy = metrics['energy'] as double;
      final activeHubs = metrics['activeHubs'] as int;
      final lastUpdate = metrics['lastUpdate'] as DateTime?;

      final timeAgo = lastUpdate != null
          ? _formatTimeAgo(lastUpdate)
          : 'Unknown';

      return "⚡ Current Energy Metrics:\n\n"
          "🔌 Power: ${power.toStringAsFixed(2)} W\n"
          "⚡ Voltage: ${voltage.toStringAsFixed(2)} V\n"
          "🔋 Current: ${current.toStringAsFixed(2)} A\n"
          "💡 Energy: ${energy.toStringAsFixed(2)} kWh\n\n"
          "📊 Active Hubs: $activeHubs\n"
          "🕐 Last Update: $timeAgo\n\n"
          "All metrics are live and updating in real-time!";
    }

    // Daily cost
    if (msg.contains('daily') && (msg.contains('cost') || msg.contains('spending') || msg.contains('bill'))) {
      final dailyData = await _dataService.getDailyEnergyAndCost();
      final energy = dailyData['energy'] as double;
      final cost = dailyData['cost'] as double;
      final price = dailyData['price'] as double;

      if (price == 0.0) {
        return "⚠️ Daily Energy: ${energy.toStringAsFixed(2)} kWh\n\n"
            "💰 Cost: Not calculated\n\n"
            "Please set your electricity price in Settings to see cost calculations!";
      }

      return "📊 Today's Energy Usage:\n\n"
          "⚡ Energy Consumed: ${energy.toStringAsFixed(2)} kWh\n"
          "💰 Total Cost: ₱${cost.toStringAsFixed(2)}\n"
          "💵 Price Rate: ₱${price.toStringAsFixed(2)}/kWh\n\n"
          "This is based on consumption since midnight.";
    }

    // Monthly estimate
    if (msg.contains('monthly') && (msg.contains('cost') || msg.contains('estimate') || msg.contains('bill') || msg.contains('projection'))) {
      final monthlyData = await _dataService.getMonthlyEstimate();
      final energy = monthlyData['energy'] as double;
      final cost = monthlyData['cost'] as double;
      final dailyAvg = monthlyData['dailyAverage'] as double;
      final price = monthlyData['price'] as double;

      if (price == 0.0) {
        return "⚠️ Monthly Estimate: ${energy.toStringAsFixed(2)} kWh\n\n"
            "💰 Cost: Not calculated\n\n"
            "Please set your electricity price in Settings to see cost estimates!";
      }

      return "📅 Monthly Cost Estimate:\n\n"
          "⚡ Projected Energy: ${energy.toStringAsFixed(2)} kWh\n"
          "💰 Estimated Cost: ₱${cost.toStringAsFixed(2)}\n"
          "📊 Daily Average: ${dailyAvg.toStringAsFixed(2)} kWh\n"
          "💵 Price Rate: ₱${price.toStringAsFixed(2)}/kWh\n\n"
          "This is a 30-day projection based on your last 24 hours of usage.";
    }

    // Hub information
    if (msg.contains('hub') && (msg.contains('status') || msg.contains('info') || msg.contains('list') || msg.contains('show'))) {
      final hubs = await _dataService.getUserHubs();
      if (hubs.isEmpty) {
        return "❌ No hubs found.\n\n"
            "To get started:\n"
            "1. Go to Settings screen\n"
            "2. Add your hub's serial number\n"
            "3. Your hub will automatically link to your account";
      }

      String response = "🔗 Your Hubs (${hubs.length}):\n\n";
      for (var i = 0; i < hubs.length; i++) {
        final hub = hubs[i];
        final nickname = hub['nickname'] as String;
        final serialNumber = hub['serialNumber'] as String;
        final ssrState = hub['ssrState'] as bool;
        final isOnline = hub['isOnline'] as bool;
        final lastSeen = hub['lastSeen'] as DateTime?;

        final statusIcon = isOnline ? '🟢' : '🔴';
        final ssrIcon = ssrState ? '✅' : '❌';
        final timeAgo = lastSeen != null ? _formatTimeAgo(lastSeen) : 'Never';

        response += "${i + 1}. $nickname\n";
        response += "   Serial: $serialNumber\n";
        response += "   Status: $statusIcon ${isOnline ? 'Online' : 'Offline'}\n";
        response += "   SSR: $ssrIcon ${ssrState ? 'ON' : 'OFF'}\n";
        response += "   Last Seen: $timeAgo\n\n";
      }

      return response;
    }

    // Device information
    if (msg.contains('device') && (msg.contains('status') || msg.contains('info') || msg.contains('list') || msg.contains('show'))) {
      final devices = await _dataService.getUserDevices();
      if (devices.isEmpty) {
        return "❌ No devices found.\n\n"
            "To add devices:\n"
            "1. Go to Devices screen\n"
            "2. Tap 'Add Device' button\n"
            "3. Configure your smart plug";
      }

      String response = "🔌 Your Devices (${devices.length}):\n\n";
      for (var i = 0; i < devices.length; i++) {
        final device = devices[i];
        final nickname = device['nickname'] as String;
        final state = device['state'] as bool;
        final power = device['power'] as double;
        final energy = device['energy'] as double;
        final hubNickname = device['hubNickname'] as String;

        final stateIcon = state ? '🟢 ON' : '🔴 OFF';

        response += "${i + 1}. $nickname\n";
        response += "   State: $stateIcon\n";
        response += "   Power: ${power.toStringAsFixed(2)} W\n";
        response += "   Energy: ${energy.toStringAsFixed(2)} kWh\n";
        response += "   Hub: $hubNickname\n\n";
      }

      return response;
    }

    // Top consumer
    if (msg.contains('top') && msg.contains('consumer')) {
      final topConsumer = await _dataService.getTopConsumer();
      if (topConsumer == null) {
        return "❌ No device data available.\n\n"
            "Make sure you have devices connected and reporting data.";
      }

      final nickname = topConsumer['nickname'] as String;
      final energy = topConsumer['energy'] as double;
      final cost = topConsumer['cost'] as double;
      final power = topConsumer['power'] as double;
      final state = topConsumer['state'] as bool;

      return "🏆 Top Energy Consumer:\n\n"
          "📱 Device: $nickname\n"
          "⚡ Energy Used: ${energy.toStringAsFixed(2)} kWh\n"
          "💰 Total Cost: ₱${cost.toStringAsFixed(2)}\n"
          "🔌 Current Power: ${power.toStringAsFixed(2)} W\n"
          "Status: ${state ? '🟢 ON' : '🔴 OFF'}\n\n"
          "This device is consuming the most energy!";
    }

    // Analytics summary
    if (msg.contains('analytics') || msg.contains('summary') || msg.contains('statistics')) {
      String timeRange = 'hourly';
      if (msg.contains('daily')) timeRange = 'daily';
      if (msg.contains('weekly')) timeRange = 'weekly';
      if (msg.contains('monthly')) timeRange = 'monthly';

      final summary = await _dataService.getAnalyticsSummary(timeRange);
      if (summary.isEmpty || summary['count'] == 0) {
        return "❌ No analytics data available for $timeRange range.\n\n"
            "Data will appear once your hubs start reporting metrics.";
      }

      final min = summary['min'] as double;
      final max = summary['max'] as double;
      final avg = summary['avg'] as double;
      final total = summary['total'] as double;
      final count = summary['count'] as int;

      String rangeName = timeRange.substring(0, 1).toUpperCase() + timeRange.substring(1);

      return "📊 $rangeName Analytics Summary:\n\n"
          "📉 Minimum: ${min.toStringAsFixed(2)} kWh\n"
          "📈 Maximum: ${max.toStringAsFixed(2)} kWh\n"
          "📊 Average: ${avg.toStringAsFixed(2)} kWh\n"
          "💡 Total Energy: ${total.toStringAsFixed(2)} kWh\n"
          "📅 Data Points: $count\n\n"
          "View detailed charts in the Analytics screen!";
    }

    // Price information
    if (msg.contains('price') && (msg.contains('current') || msg.contains('what') || msg.contains('rate'))) {
      final price = await _dataService.getCurrentPrice();
      if (price == 0.0) {
        return "⚠️ No electricity price configured.\n\n"
            "To set your price:\n"
            "1. Go to Settings screen\n"
            "2. Enter your price per kWh\n"
            "3. Tap Save\n\n"
            "Once set, all cost calculations will update automatically!";
      }

      return "💵 Current Electricity Rate:\n\n"
          "₱${price.toStringAsFixed(2)} per kWh\n\n"
          "You can update this in the Settings screen.\n"
          "All cost calculations use this rate.";
    }

    // Due date information
    if (msg.contains('due date') || msg.contains('billing date') || msg.contains('bill due')) {
      final dueDateInfo = await _dataService.getDueDateInfo();
      if (dueDateInfo == null) {
        return "⚠️ No billing due date configured.\n\n"
            "To set your due date:\n"
            "1. Go to Settings screen\n"
            "2. Set your billing due date\n"
            "3. Tap Save";
      }

      final dueDate = dueDateInfo['dueDate'] as DateTime;
      final daysRemaining = dueDateInfo['daysRemaining'] as int;
      final formattedDate = DateFormat('MMM dd, yyyy').format(dueDate);

      String urgency = '';
      if (daysRemaining < 0) {
        urgency = '⚠️ OVERDUE!';
      } else if (daysRemaining <= 3) {
        urgency = '🔴 Due soon!';
      } else if (daysRemaining <= 7) {
        urgency = '🟡 Coming up';
      } else {
        urgency = '🟢 On track';
      }

      return "📅 Billing Due Date:\n\n"
          "$urgency\n\n"
          "Due Date: $formattedDate\n"
          "Days Remaining: ${daysRemaining.abs()} ${daysRemaining < 0 ? 'days overdue' : 'days'}\n\n"
          "View monthly estimate to plan your payment!";
    }

    // History queries with specific date/time support
    if (msg.contains('history') || msg.contains('past') || msg.contains('previous') || msg.contains('recent') ||
        msg.contains('yesterday') || msg.contains('last week') || msg.contains('this week') ||
        msg.contains('last month') || msg.contains('this month') || msg.contains('today') ||
        msg.contains('usage')) {

      String timeRange = 'daily';
      int limit = 5;
      DateTime? specificDate;

      // Try to parse specific calendar dates (e.g., "dec 07", "december 7", "12/07")
      final monthNames = {
        'jan': 1, 'january': 1,
        'feb': 2, 'february': 2,
        'mar': 3, 'march': 3,
        'apr': 4, 'april': 4,
        'may': 5,
        'jun': 6, 'june': 6,
        'jul': 7, 'july': 7,
        'aug': 8, 'august': 8,
        'sep': 9, 'sept': 9, 'september': 9,
        'oct': 10, 'october': 10,
        'nov': 11, 'november': 11,
        'dec': 12, 'december': 12,
      };

      // Check for month name + day pattern (e.g., "dec 07", "december 7")
      for (var entry in monthNames.entries) {
        if (msg.contains(entry.key)) {
          // Try to extract day number after the month name
          final regex = RegExp('${entry.key}[a-z]*\\s+(\\d{1,2})');
          final match = regex.firstMatch(msg);
          if (match != null) {
            final day = int.tryParse(match.group(1)!);
            if (day != null && day >= 1 && day <= 31) {
              final now = DateTime.now();
              // Assume current year unless specified
              specificDate = DateTime(now.year, entry.value, day);
              // If the date is in the future, assume last year
              if (specificDate.isAfter(now)) {
                specificDate = DateTime(now.year - 1, entry.value, day);
              }
              break;
            }
          }
        }
      }

      // Check for numeric date patterns (e.g., "12/07", "07/12/2024")
      if (specificDate == null) {
        final numericDateRegex = RegExp(r'(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?');
        final match = numericDateRegex.firstMatch(msg);
        if (match != null) {
          final part1 = int.tryParse(match.group(1)!);
          final part2 = int.tryParse(match.group(2)!);
          final yearStr = match.group(3);

          if (part1 != null && part2 != null) {
            final now = DateTime.now();
            int year = now.year;
            if (yearStr != null) {
              final parsedYear = int.tryParse(yearStr);
              if (parsedYear != null) {
                year = parsedYear < 100 ? 2000 + parsedYear : parsedYear;
              }
            }

            // Try both MM/DD and DD/MM formats
            try {
              specificDate = DateTime(year, part1, part2);
              if (specificDate.isAfter(now)) {
                specificDate = DateTime(year - 1, part1, part2);
              }
            } catch (e) {
              try {
                specificDate = DateTime(year, part2, part1);
                if (specificDate.isAfter(now)) {
                  specificDate = DateTime(year - 1, part2, part1);
                }
              } catch (e) {
                // Invalid date
                specificDate = null;
              }
            }
          }
        }
      }

      // Determine time range from query
      if (msg.contains('hourly') || msg.contains('hour')) {
        timeRange = 'hourly';
        limit = 24; // Show more for hourly
      } else if (msg.contains('weekly') || msg.contains('week')) {
        timeRange = 'weekly';
        limit = 4;
      } else if (msg.contains('monthly') || msg.contains('month')) {
        timeRange = 'monthly';
        limit = 6;
      } else if (msg.contains('daily') || msg.contains('day')) {
        timeRange = 'daily';
        limit = 7;
      }

      // Handle specific date queries
      String queryPrefix = '';
      if (msg.contains('yesterday')) {
        queryPrefix = 'Yesterday\'s ';
        limit = 1;
        specificDate = DateTime.now().subtract(const Duration(days: 1));
      } else if (msg.contains('today')) {
        queryPrefix = 'Today\'s ';
        limit = 1;
        specificDate = DateTime.now();
      } else if (msg.contains('last week')) {
        queryPrefix = 'Last Week\'s ';
        timeRange = 'weekly';
        limit = 1;
      } else if (msg.contains('this week')) {
        queryPrefix = 'This Week\'s ';
        timeRange = 'weekly';
        limit = 1;
      } else if (msg.contains('last month')) {
        queryPrefix = 'Last Month\'s ';
        timeRange = 'monthly';
        limit = 1;
      } else if (msg.contains('this month')) {
        queryPrefix = 'This Month\'s ';
        timeRange = 'monthly';
        limit = 1;
      } else if (specificDate != null) {
        queryPrefix = '${DateFormat('MMM dd, yyyy').format(specificDate)} ';
        // Request more records to search through when looking for a specific date
        limit = 30;
      }

      final history = await _dataService.getRecentHistory(timeRange: timeRange, limit: limit);
      if (history.isEmpty || history['count'] == 0) {
        return "❌ No history data available.\n\n"
            "Historical data will appear once your system has been running for a while.";
      }

      var records = history['records'] as List;
      var totalEnergy = history['totalEnergy'] as double;
      var totalCost = history['totalCost'] as double;

      // Filter by specific date if provided
      if (specificDate != null) {
        final targetDate = DateTime(specificDate.year, specificDate.month, specificDate.day);
        records = records.where((record) {
          final timestamp = record['timestamp'] as DateTime;
          final recordDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
          return recordDate.isAtSameMomentAs(targetDate);
        }).toList();

        // Recalculate totals for filtered records
        totalEnergy = 0.0;
        totalCost = 0.0;
        for (var record in records) {
          totalEnergy += (record['usage'] as double?) ?? 0.0;
          totalCost += (record['cost'] as double?) ?? 0.0;
        }

        if (records.isEmpty) {
          return "❌ No usage data found for ${DateFormat('MMM dd, yyyy').format(specificDate)}.\n\n"
              "This date may be outside your available history range.";
        }
      }

      String timeRangeName = timeRange.substring(0, 1).toUpperCase() + timeRange.substring(1);
      String response = "📜 $queryPrefix${queryPrefix.isEmpty ? 'Recent $timeRangeName ' : ''}History:\n\n";

      int displayCount = limit == 1 ? 1 : (records.length > 5 ? 5 : records.length);
      for (var i = 0; i < displayCount; i++) {
        final record = records[i] as Map<String, dynamic>;
        final timestamp = record['timestamp'] as DateTime;
        final usage = record['usage'] as double;
        final cost = record['cost'] as double;

        String dateStr;
        switch (timeRange) {
          case 'hourly':
            dateStr = DateFormat('MMM dd, HH:mm').format(timestamp);
            break;
          case 'daily':
            dateStr = DateFormat('MMM dd, yyyy').format(timestamp);
            break;
          case 'weekly':
            dateStr = 'Week of ${DateFormat('MMM dd').format(timestamp)}';
            break;
          case 'monthly':
            dateStr = DateFormat('MMMM yyyy').format(timestamp);
            break;
          default:
            dateStr = DateFormat('MMM dd, yyyy').format(timestamp);
        }

        if (limit == 1) {
          // For specific date queries, show more detail
          response += "📅 $dateStr\n\n";
          response += "⚡ Energy Usage: ${usage.toStringAsFixed(2)} kWh\n";
          response += "💰 Cost: ₱${cost.toStringAsFixed(2)}\n";
          final currentReading = record['currentReading'] as double;
          final previousReading = record['previousReading'] as double;
          response += "📊 Reading: ${previousReading.toStringAsFixed(2)} → ${currentReading.toStringAsFixed(2)} kWh\n";
        } else {
          response += "${i + 1}. $dateStr\n";
          response += "   Usage: ${usage.toStringAsFixed(2)} kWh\n";
          response += "   Cost: ₱${cost.toStringAsFixed(2)}\n\n";
        }
      }

      if (limit > 1) {
        response += "\n📊 Summary (last $displayCount periods):\n";
        response += "⚡ Total Energy: ${totalEnergy.toStringAsFixed(2)} kWh\n";
        response += "💰 Total Cost: ₱${totalCost.toStringAsFixed(2)}\n\n";
        response += "View detailed history in the History screen!";
      }

      return response;
    }

    // Compare today vs yesterday
    if ((msg.contains('compare') || msg.contains('comparison') || msg.contains('vs') || msg.contains('versus')) ||
        (msg.contains('today') && msg.contains('yesterday')) ||
        msg.contains('difference')) {
      final comparison = await _dataService.getUsageComparison();
      if (comparison.isEmpty) {
        return "❌ Not enough data for comparison.\n\n"
            "Comparison data will be available after your system runs for at least 2 days.";
      }

      final todayEnergy = comparison['todayEnergy'] as double;
      final yesterdayEnergy = comparison['yesterdayEnergy'] as double;
      final difference = comparison['difference'] as double;
      final percentChange = comparison['percentChange'] as double;
      final todayCost = comparison['todayCost'] as double;
      final yesterdayCost = comparison['yesterdayCost'] as double;
      final isIncreasing = comparison['isIncreasing'] as bool;

      String trend = '';
      String trendIcon = '';
      if (difference.abs() < 0.1) {
        trend = 'About the same';
        trendIcon = '➡️';
      } else if (isIncreasing) {
        trend = 'Increased';
        trendIcon = '📈';
      } else {
        trend = 'Decreased';
        trendIcon = '📉';
      }

      return "📊 Usage Comparison:\n\n"
          "TODAY:\n"
          "⚡ Energy: ${todayEnergy.toStringAsFixed(2)} kWh\n"
          "💰 Cost: ₱${todayCost.toStringAsFixed(2)}\n\n"
          "YESTERDAY:\n"
          "⚡ Energy: ${yesterdayEnergy.toStringAsFixed(2)} kWh\n"
          "💰 Cost: ₱${yesterdayCost.toStringAsFixed(2)}\n\n"
          "CHANGE:\n"
          "$trendIcon $trend ${percentChange.abs().toStringAsFixed(1)}%\n"
          "Difference: ${difference.abs().toStringAsFixed(2)} kWh\n"
          "Cost Impact: ₱${(todayCost - yesterdayCost).abs().toStringAsFixed(2)}\n\n"
          "${isIncreasing ? '⚠️ You\'re using more energy today!' : '✅ You\'re using less energy today!'}";
    }

    // Greetings
    if (msg.contains('hello') || msg.contains('hi') || msg.contains('hey')) {
      return "👋 Hello! I'm your Smart Energy System assistant. I can help you with:\n\n• Energy monitoring & analytics\n• Device & hub management\n• Usage history & reports\n• Settings & configuration\n• Notifications & alerts\n\nWhat would you like to know?";
    }

    // App Overview & Features
    if (msg.contains('what can') || msg.contains('what do') || msg.contains('features') || msg.contains('capabilities')) {
      return "🌟 Smart Energy System Features:\n\n📊 Real-time energy monitoring\n🔌 Smart device & hub management\n📈 Advanced analytics (hourly/daily/weekly/monthly)\n📜 Usage history tracking\n⚙️ Custom settings (pricing, billing dates)\n🔔 Notifications & alerts\n📤 Excel data export\n🌓 Dark/Light theme\n💡 SSR (breaker) control\n\nAsk me about any feature for details!";
    }

    // Dashboard/Energy Overview
    if ((msg.contains('dashboard') || msg.contains('overview') || msg.contains('monitor')) && !msg.contains('how')) {
      return "📊 Energy Dashboard (Profile Screen):\n\nComprehensive monitoring interface:\n\n⚡ REAL-TIME METRICS:\n• Power (W) - Purple - Current load\n• Voltage (V) - Orange - Electrical potential\n• Current (A) - Blue - Current flow\n• Energy (kWh) - Green - Total consumed\n• Per-second live updates\n• Connection status (Green/Red)\n\n📈 24-HOUR HISTORICAL CHART:\n• Smooth line chart with gradients\n• Interactive touch tooltips\n• Switchable metrics via chips\n• Auto-scaling Y-axis\n• Time-based X-axis (every 4 hours)\n• Data points marked with dots\n\n💰 COST CALCULATIONS:\n• Daily Energy & Cost display\n• Monthly cost estimate projection\n• Quick cost calculator widget\n• Device-level cost breakdown\n• Top energy consumer identification\n\n🏠 HUB MANAGEMENT:\n• Multi-hub support\n• Primary hub auto-selection\n• Hub switching dropdown\n• SSR status monitoring\n• Device refresh every 30 seconds\n\n📊 SUMMARY CARDS:\n• Daily cost with progress bar\n• Monthly estimate with projection\n• Device summary with total cost\n• Top consumer card\n\n💡 EXTRA FEATURES:\n• Energy-saving tips\n• Appliance calculator\n• Responsive mobile design\n• Auto-refresh data\n\nFind in Profile screen!";
    }

    // How to use Dashboard
    if (msg.contains('how') && (msg.contains('dashboard') || msg.contains('monitor') || msg.contains('view energy'))) {
      return "📖 How to Use Energy Dashboard:\n\n⚡ MONITOR REAL-TIME:\n1. Go to Profile screen\n2. Check connection status (Green/Red badge)\n3. View current metric values\n4. See circular progress indicator\n5. Values update every second\n\n📈 VIEW 24-HOUR CHART:\n1. Scroll to historical chart section\n2. Select metric using chips:\n   • Power (Purple)\n   • Voltage (Orange)\n   • Current (Blue)\n   • Energy (Green)\n3. Touch chart for detailed tooltips\n4. Chart shows last 24 hours\n5. Auto-refreshes with new data\n\n💰 CHECK COSTS:\n1. View Daily Cost card:\n   • Shows today's consumption\n   • Progress bar indicates usage\n2. Check Monthly Estimate:\n   • Projected 30-day cost\n   • Based on daily average\n3. Use Cost Calculator:\n   • Enter appliance wattage\n   • Enter hours per day\n   • See daily & monthly cost\n\n🔧 MANAGE HUBS:\n• Select hub from dropdown (if multiple)\n• Primary hub auto-selected\n• Check SSR status (Connected/Offline)\n• Devices refresh automatically\n\n📱 TIPS:\n• Green status = Connected & Active\n• Red status = Offline or SSR OFF\n• Chart updates when SSR ON\n• Set price in Settings for accurate costs\n• Top consumer helps identify high usage\n\nComplete monitoring solution!";
    }

    // Analytics
    if (msg.contains('analytics') && !msg.contains('how')) {
      return "📈 Analytics Screen - Complete Overview:\n\nTwo powerful chart systems:\n\n⚡ 60-SECOND LIVE CHART:\n• Real-time per-second updates\n• 60-second streaming window\n• See current consumption NOW\n• Green border when recording\n• Red border when SSR paused\n• Connection status indicator\n• Export live data to Excel\n\n📊 HISTORICAL ANALYTICS:\n• Hourly: 24 hours (hour-by-hour)\n• Daily: 7 days (day-by-day)\n• Weekly: 28 days (week summaries)\n• Monthly: 180 days (6 months)\n• Gap detection for disconnections\n• Smooth animated line charts\n• Interactive touch tooltips\n• Export to Excel & CSV\n\n📐 4 METRICS AVAILABLE:\n• Power (W) - Purple\n• Voltage (V) - Orange\n• Current (A) - Blue\n• Energy (kWh) - Green (with cost)\n\n🔗 HUB OPTIONS:\n• Single hub view\n• All Hubs (Combined) - default\n• Auto-aggregates multi-hub data\n\n📊 STATISTICS CARDS:\n• Min value (Blue)\n• Avg value (Green)\n• Max value (Orange)\n• Auto-calculated from data range\n\n💾 EXPORT OPTIONS:\n• 60-second data → Excel\n• Historical data → Excel\n• Historical data → CSV\n\n✨ Smart features, real insights!";
    }

    // How to use Analytics
    if (msg.contains('how') && msg.contains('analytics')) {
      return "📖 How to Use Analytics Screen:\n\n⚡ LIVE CHART (60-Second):\n1. Go to Analytics screen (top section)\n2. See real-time updates every second\n3. Watch current consumption live\n4. Check connection status (green/red)\n5. SSR status affects chart:\n   • Green border = Recording\n   • Red border = Paused\n6. Click download to export live data\n\n📊 HISTORICAL ANALYTICS:\n1. Scroll to historical section\n2. Select time range:\n   • Hourly - Last 24 hours\n   • Daily - Last 7 days\n   • Weekly - Last 28 days\n   • Monthly - Last 180 days\n3. Choose metric (Power/Voltage/Current/Energy)\n4. Select hub or 'All Hubs'\n5. View statistics cards (Min/Avg/Max)\n6. Touch chart for detailed values\n7. Export options:\n   • Excel icon - Download XLSX\n   • CSV button - Copy to clipboard\n\n🎯 HUB SELECTION:\n• Dropdown appears with multiple hubs\n• Select specific hub by name\n• Or choose 'All Hubs (Combined)'\n• See active hub count below chart\n\n💡 TIPS:\n• Use Hourly for recent patterns\n• Use Daily for week overview\n• Use Weekly for monthly trends\n• Use Monthly for long-term analysis\n• Energy metric shows cost (₱)\n• SSR OFF pauses recording\n• Green WiFi = Connected\n• Red WiFi = Offline (5+ min)\n\nPerfect for consumption analysis!";
    }

    // Devices & Hubs
    if ((msg.contains('device') || msg.contains('plug') || msg.contains('hub')) && !msg.contains('how') && !msg.contains('add')) {
      return "🔌 Device Management:\n\nSmart Plugs:\n• View all connected plugs\n• Real-time status monitoring\n• Custom device nicknames\n• Toggle devices on/off\n• Per-device metrics\n\nHubs:\n• Multi-hub support\n• Hub serial number tracking\n• Device grouping by hub\n• Hub-specific analytics\n\nGo to 'Devices' screen to manage!";
    }

    // How to add devices
    if (msg.contains('how') && (msg.contains('add device') || msg.contains('add plug') || msg.contains('add hub') || msg.contains('connect device'))) {
      return "📖 How to Add Devices:\n\nAdding a Hub:\n1. Go to Settings screen\n2. Enter hub serial number\n3. Hub auto-links to your account\n\nAdding Smart Plugs:\n1. Go to Devices screen\n2. Tap 'Add Device' button\n3. Enter plug details\n4. Assign to a hub\n5. Give it a custom nickname\n\nDevices appear automatically once connected!";
    }

    // How to control devices
    if (msg.contains('how') && (msg.contains('control') || msg.contains('turn on') || msg.contains('turn off') || msg.contains('toggle'))) {
      return "📖 How to Control Devices:\n\nSmart Plugs:\n• Go to Devices screen\n• Find your device\n• Use toggle switch to turn ON/OFF\n\nMain Breaker (SSR):\n• Go to Settings screen\n• Use SSR toggle for main power control\n• Controls all equipment at once\n\nTip: SSR state affects analytics recording!";
    }

    // Device control commands
    if (msg.contains('turn on') || msg.contains('switch on')) {
      return "✅ To turn on devices:\n\n1. Go to 'Devices' screen\n2. Find the device you want\n3. Toggle the switch to ON\n\nFor main power, use SSR toggle in Settings!";
    } else if (msg.contains('turn off') || msg.contains('switch off')) {
      return "✅ To turn off devices:\n\n1. Go to 'Devices' screen\n2. Find the device you want\n3. Toggle the switch to OFF\n\nFor main power, use SSR toggle in Settings!";
    }

    // History
    if (msg.contains('history') && !msg.contains('how')) {
      return "📜 Energy History Screen:\n\nTwo powerful sections:\n\n🔷 CENTRAL HUB DATA:\n• View aggregated historical metrics\n• Select time range: Hourly/Daily/Weekly/Monthly\n• See all metrics: Power, Voltage, Current, Energy\n• Track min/max/average values\n• Sort by any column\n• Summary cards show totals & trends\n• Export complete data to Excel\n\n🔶 USAGE HISTORY:\n• Calculated consumption tracking\n• Shows: Previous Reading → Current Reading → Usage\n• Perfect for billing calculations\n• Custom due date support\n• Per-hub usage breakdown\n• Automatic usage calculations\n• Export usage reports to Excel\n\n💡 COST CALCULATOR:\n• Built-in electricity cost calculator\n• Enter kWh × Price = Total Cost\n• Quick cost estimates\n\nView everything in History screen!";
    }

    // How to use History
    if (msg.contains('how') && msg.contains('history')) {
      return "📖 How to Use History Screen:\n\n📊 CENTRAL HUB DATA:\n1. Go to History screen (top section)\n2. Choose aggregation: Hourly/Daily/Weekly/Monthly\n3. View data table with all metrics\n4. Click column headers to sort\n5. See summary cards at top\n6. Click any row for full details\n7. Click download icon to export Excel\n\n📈 USAGE HISTORY:\n1. Scroll to Usage History section\n2. Select hub from dropdown (if multiple)\n3. Choose interval: Hourly/Daily/Weekly/Monthly\n4. View usage calculations in table\n5. Each row shows consumption between readings\n6. Export to Excel for billing records\n\n💰 COST CALCULATOR:\n1. Find calculator between sections\n2. Enter energy usage (kWh)\n3. Enter your price per kWh\n4. See instant total cost calculation\n\n📅 TIP: Set due date in Settings for accurate monthly billing periods!";
    }

    // Settings
    if (msg.contains('settings') && !msg.contains('how')) {
      return "⚙️ Settings Features:\n\n💰 Price Configuration:\n• Set energy cost per kWh\n• View price history\n• Auto-calculates costs\n\n📅 Billing Setup:\n• Custom due date\n• Days remaining tracking\n\n🔌 Hub Management:\n• View all your hubs\n• SSR (breaker) control\n• Hub status monitoring\n\nCustomize in Settings screen!";
    }

    // How to use Settings
    if (msg.contains('how') && msg.contains('settings')) {
      return "📖 How to Use Settings:\n\n1. Go to Settings screen\n2. Enter price per kWh (e.g., 0.15)\n3. Set your billing due date\n4. Select active hub\n5. Control SSR (main breaker)\n6. Tap Save to apply changes\n\nAll settings sync across devices!";
    }

    // Daily Cost Card
    if (msg.contains('daily cost') || msg.contains('daily energy')) {
      return "💰 Daily Cost Card:\n\nToday's consumption & cost:\n\n📊 DISPLAYS:\n• Daily Energy Used (kWh)\n• Total Cost (₱)\n• Progress bar indicator\n• Yesterday's baseline reference\n\n🧮 CALCULATION:\nDaily Cost = (Current Energy - Yesterday's Total) × Price per kWh\n\n📈 PROGRESS BAR:\n• Visual representation of usage\n• Color-coded indicator\n• Percentage based on max consumption\n\n📍 LOCATION:\nProfile screen, below real-time metrics\n\n💡 FEATURES:\n• Updates in real-time\n• Clamped to positive values\n• Uses yesterday's daily aggregation\n• Resets daily at midnight\n\n⚙️ SETUP:\n• Set price per kWh in Settings\n• System auto-calculates costs\n• Fetches yesterday's baseline\n\nTrack daily spending!";
    }

    // Monthly Estimate
    if (msg.contains('monthly estimate') || msg.contains('monthly cost') || msg.contains('monthly projection')) {
      return "📅 Monthly Cost Estimate:\n\n30-day cost projection:\n\n📊 DISPLAYS:\n• Estimated Monthly Cost (₱)\n• Average Daily Energy (kWh)\n• Projected Monthly Energy (kWh)\n• Based on 24-hour average\n\n🧮 CALCULATION:\nStep 1: Calculate daily average from 24h chart data\nStep 2: Daily Cost = Daily Avg × Price per kWh\nStep 3: Monthly Cost = Daily Cost × 30\nStep 4: Monthly Energy = Daily Avg × 30\n\n📈 ACCURACY:\n• Uses actual 24-hour consumption data\n• Averages all hourly data points\n• Projects realistic monthly usage\n• Updates as consumption patterns change\n\n🎨 DESIGN:\n• Blue gradient card\n• Calendar icon\n• Large prominent cost display\n• Detailed breakdown below\n\n📍 LOCATION:\nProfile screen, middle section\n\n💡 USE CASES:\n• Budget planning\n• Bill estimation\n• Consumption forecasting\n• Cost comparison month-to-month\n\n⚙️ REQUIREMENTS:\n• Price per kWh set in Settings\n• At least some 24h data available\n• Active hub connection\n\nPlan your monthly budget!";
    }

    // Quick Cost Calculator
    if (msg.contains('quick calculator') || msg.contains('appliance calculator') || msg.contains('wattage calculator')) {
      return "🧮 Quick Cost Calculator:\n\nCalculate appliance costs:\n\n📝 INPUTS:\n1. Appliance Wattage (W)\n   • Power rating of device\n   • Example: 100W light bulb\n2. Hours Per Day\n   • Daily usage duration\n   • Example: 8 hours\n\n🧮 CALCULATIONS:\nDaily Cost = (Wattage ÷ 1000) × Hours × Price per kWh\nMonthly Cost = Daily Cost × 30\n\n📊 DISPLAYS:\n• Daily Cost (₱)\n• Monthly Cost (₱)\n• Real-time auto-calculation\n• Clear result display\n\n💡 EXAMPLE:\nWattage: 100W\nHours: 8\nPrice: ₱12/kWh\n\nDaily: (100÷1000) × 8 × 12 = ₱9.60\nMonthly: 9.60 × 30 = ₱288\n\n📍 LOCATION:\nProfile screen, below monthly estimate\n\n🔧 FEATURES:\n• Instant calculation on input\n• Clear input fields\n• Professional gradient result card\n• Helpful tips included\n• Works offline once price loaded\n\n💡 COMMON APPLIANCES:\n• LED Bulb: 10-15W\n• Fan: 50-75W\n• TV: 100-400W\n• AC: 1000-2000W\n• Refrigerator: 150-300W\n\n⚙️ SETUP:\n• Set price per kWh in Settings\n• Enter appliance details\n• See instant results!\n\nBudget for any appliance!";
    }

    // 24-Hour Chart
    if (msg.contains('24 hour chart') || msg.contains('24-hour chart') || msg.contains('historical chart dashboard')) {
      return "📈 24-Hour Historical Chart:\n\nYesterday + today visualization:\n\n⏰ TIME RANGE:\n• Last 24 hours of data\n• Hourly aggregation\n• X-axis: Every 4 hours\n• Auto-refreshes with new data\n\n📊 CHART FEATURES:\n• Smooth curved line\n• Gradient fill below (20% opacity)\n• Interactive data point dots\n• Touch tooltips with values\n• Metric-specific color coding\n• Auto-scaling Y-axis (max × 1.2)\n• Grid lines for easy reading\n\n🎛️ METRIC SWITCHING:\nChips above chart:\n• Power (Purple) - Wattage consumption\n• Voltage (Orange) - Electrical stability\n• Current (Blue) - Current flow\n• Energy (Green) - Total kWh\n\n🖱️ INTERACTIONS:\n• Touch chart to see exact values\n• Tooltip shows metric + time\n• Scroll to see entire chart\n• Switches smoothly between metrics\n\n📐 CHART BEHAVIOR:\n• Y-axis: 0 to (max value × 1.2)\n• X-axis: Time with HH:mm format\n• Grid: Horizontal & vertical lines\n• Dots: Always visible at data points\n• Curve smoothness: 20%\n\n📍 LOCATION:\nProfile screen, middle-bottom section\n\n💡 USE CASES:\n• Identify peak usage times\n• Track daily patterns\n• Compare different metrics\n• Spot anomalies\n• Monitor voltage stability\n\n🔧 REQUIREMENTS:\n• Active hub with SSR ON\n• Internet connection\n• At least some hourly data\n\nVisualize your day!";
    }

    // Top Consumer / Device Summary
    if (msg.contains('top consumer') || msg.contains('device summary') || msg.contains('device cost')) {
      return "🏆 Top Energy Consumer:\n\nIdentify highest usage device:\n\n📊 DISPLAYS:\n• Device with highest energy consumption\n• Device name/nickname\n• Total energy used (kWh)\n• Total cost (₱)\n• Orange gradient card design\n\n🔍 IDENTIFICATION:\n• Scans all connected devices\n• Compares energy usage\n• Selects device with max kWh\n• Updates as devices change\n\n💰 COST BREAKDOWN:\n• Energy (kWh) × Price per kWh = Cost\n• Shows both energy and cost\n• Helps identify expensive devices\n\n📦 DEVICE SUMMARY CARD:\nAlso shows:\n• Total devices monitored\n• Combined energy usage (all devices)\n• Total cost across all devices\n• Device count badge\n\n📍 LOCATION:\nProfile screen, bottom section\n\n💡 USE CASES:\n• Find energy-hogging appliances\n• Identify cost culprits\n• Prioritize efficiency upgrades\n• Make informed decisions\n• Budget by device\n\n🔧 FEATURES:\n• Real-time device monitoring\n• Auto-updates every 30 seconds\n• Works with multiple devices\n• Shows nickname if set\n• Fallback to device ID\n\n⚙️ REQUIREMENTS:\n• At least one device/plug connected\n• Devices reporting energy data\n• Price per kWh configured\n\nOptimize your usage!";
    }

    // Pricing
    if (msg.contains('price') || msg.contains('cost') || msg.contains('kwh') || msg.contains('billing')) {
      return "💰 Energy Pricing:\n\nSet your electricity rate:\n• Go to Settings screen\n• Enter price per kWh\n• System calculates costs automatically\n• View on Dashboard & Analytics\n\nPrice history is tracked with timestamps.\n\nCurrent costs update in real-time!";
    }

    // Notifications
    if (msg.contains('notification') || msg.contains('alert')) {
      return "🔔 Notifications:\n\nStay informed about:\n• Hub on/off events\n• Plug toggle actions\n• Price updates\n• Due date changes\n• Device added/removed\n• Schedule updates\n• Energy & cost alerts\n\nAccess notifications:\n• Click bell icon in header\n• View unread count\n• Mark as read/unread\n• Delete or clear all\n\nNever miss important updates!";
    }

    // Central Hub Data
    if (msg.contains('central hub data') || msg.contains('aggregated data')) {
      return "🔷 Central Hub Data:\n\nHistorical aggregated metrics:\n\n📊 Available Metrics:\n• Average/Min/Max Power (W)\n• Average/Min/Max Voltage (V)\n• Average/Min/Max Current (A)\n• Total Energy (kWh)\n• Total Readings count\n\n⏱️ Time Ranges:\n• Hourly - Hour-by-hour breakdown\n• Daily - Day-by-day totals\n• Weekly - Week summaries\n• Monthly - Monthly reports\n\n✨ Features:\n• Sortable columns (click headers)\n• Color-coded energy levels\n• Summary cards with trends\n• Click row for full details\n• Multi-hub support\n• Excel export\n\nFind in History screen (top section)!";
    }

    // Usage History specific
    if (msg.contains('usage calculation') || msg.contains('usage tracking')) {
      return "🔶 Usage History Calculations:\n\nHow usage is calculated:\n\n📐 Formula:\nUsage = Current Reading - Previous Reading\n\n⏰ Intervals Available:\n• Hourly: Hour-to-hour consumption\n• Daily: Day-to-day consumption\n• Weekly: Week-to-week consumption\n• Monthly: Month-to-month consumption\n\n📋 What You See:\n• Timestamp - When reading was taken\n• Previous Reading - Starting meter value\n• Current Reading - Ending meter value\n• Usage (kWh) - Actual consumption\n\n💡 Perfect For:\n• Billing calculations\n• Consumption tracking\n• Usage pattern analysis\n• Cost estimation\n\n📅 Custom Due Date:\nSet billing cycle date in Settings for accurate monthly calculations!\n\nFind in History screen (bottom section)!";
    }

    // Cost Calculator
    if (msg.contains('cost calculator') || msg.contains('calculate cost')) {
      return "💰 Electricity Cost Calculator:\n\nQuick cost calculations:\n\n🧮 How It Works:\n1. Enter energy usage (kWh)\n2. Enter price per kWh (₱)\n3. See instant total cost!\n\nFormula: kWh × Price = Total Cost\n\n📍 Location:\nHistory screen, between Central Hub Data and Usage History sections\n\n💡 Use Cases:\n• Estimate monthly bills\n• Calculate appliance costs\n• Budget planning\n• Compare time periods\n\n📊 Example:\n• Usage: 150 kWh\n• Price: ₱12.50 per kWh\n• Total: ₱1,875.00\n\nPerfect for quick estimates!";
    }

    // Export
    if (msg.contains('export') || msg.contains('excel') || msg.contains('download')) {
      return "📤 Data Export to Excel:\n\nTwo export types available:\n\n🔷 CENTRAL HUB DATA EXPORT:\n• Exports aggregated historical data\n• Includes ALL metrics (Power/Voltage/Current/Energy)\n• Shows min/max/average values\n• All time periods in selected range\n• File: SmartEnergyMeter_HubName_Daily_CentralHub_[timestamp].xlsx\n\n🔶 USAGE HISTORY EXPORT:\n• Exports consumption calculations\n• Previous/Current readings\n• Usage amounts (kWh)\n• Perfect for billing records\n• File: SmartEnergyMeter_HubName_Daily_Usage_[timestamp].xlsx\n\n📈 ANALYTICS EXPORT:\n• Historical trend data\n• Selected time range\n• Chosen metrics only\n\n📥 How to Export:\n1. Go to desired screen\n2. Select your preferences\n3. Click download icon\n4. Wait for file generation\n5. File downloads automatically\n\n✅ All exports include proper headers and formatting!\n\nPerfect for record-keeping & reports!";
    }

    // SSR / Breaker
    if (msg.contains('ssr') || msg.contains('breaker') || msg.contains('main switch')) {
      return "💡 SSR (Solid State Relay):\n\nMain power control:\n• Acts as master breaker\n• Controls all equipment\n• Located in Settings screen\n\nWhen SSR is OFF:\n• Analytics recording pauses\n• Charts stop updating\n• Energy consumption halts\n\nWhen SSR is ON:\n• Normal operation resumes\n• Data recording continues\n\nUse for equipment safety!";
    }

    // Theme
    if (msg.contains('theme') || msg.contains('dark mode') || msg.contains('light mode')) {
      return "🌓 Theme Options:\n\nToggle between:\n• Dark Mode (default)\n• Light Mode\n\nHow to change:\n1. Find theme toggle in header\n2. Click to switch\n3. Preference saves automatically\n\nWorks across all screens!\nChoose what's comfortable for your eyes!";
    }

    // Profile - Dynamic profile information
    if ((msg.contains('show') || msg.contains('view') || msg.contains('my') || msg.contains('what')) &&
        (msg.contains('profile') || msg.contains('account') || msg.contains('info') || msg.contains('details'))) {
      final profile = await _dataService.getUserProfile();
      if (profile == null) {
        return "❌ Unable to fetch profile data.\n\nPlease ensure you're logged in.";
      }

      final email = profile['email'] as String;
      final fullName = profile['fullName'] as String;
      final address = profile['address'] as String;
      final phoneNumber = profile['phoneNumber'] as String;
      final accountCreated = profile['accountCreated'] as DateTime?;
      final lastSignIn = profile['lastSignIn'] as DateTime?;

      String accountCreatedStr = 'Unknown';
      String lastSignInStr = 'Unknown';

      if (accountCreated != null) {
        accountCreatedStr = DateFormat('MMM dd, yyyy').format(accountCreated);
      }
      if (lastSignIn != null) {
        lastSignInStr = _formatTimeAgo(lastSignIn);
      }

      return "👤 Your Profile:\n\n"
          "📧 Email: $email\n"
          "👨 Name: $fullName\n"
          "📍 Address: $address\n"
          "📱 Phone: $phoneNumber\n\n"
          "📅 Account Info:\n"
          "Created: $accountCreatedStr\n"
          "Last Sign In: $lastSignInStr\n\n"
          "You can update your profile in the Settings screen!";
    }

    // Profile - Static guide (when not asking for data)
    if (msg.contains('profile') || msg.contains('account')) {
      return "👤 Profile Management:\n\nView & edit:\n• Display name\n• Email address\n• Physical address\n• Hub serial numbers\n• Price per kWh\n\nHow to edit:\n1. Go to Profile screen\n2. Click Edit button\n3. Update information\n4. Save changes\n\nAll data syncs to cloud!";
    }

    // Real-time / Live data
    if (msg.contains('real-time') || msg.contains('live') || msg.contains('update')) {
      return "⚡ Real-Time Features:\n\n• Per-second data streaming\n• Live chart updates\n• Instant device status\n• Real-time cost calculations\n• Live SSR state monitoring\n\nData Updates:\n✓ Dashboard: Every second\n✓ Analytics: Live 60-second chart\n✓ Devices: Instant status changes\n✓ Notifications: Immediate alerts\n\nNo refresh needed - always current!";
    }

    // Multi-hub
    if (msg.contains('multi') || msg.contains('multiple hub') || msg.contains('several hub')) {
      return "🔗 Multi-Hub Support:\n\nManage multiple hubs:\n• Link unlimited hubs to account\n• Per-hub analytics\n• Combined view option\n• Hub-specific history\n• Individual hub control\n\nBenefits:\n✓ Monitor multiple locations\n✓ Separate device groups\n✓ Individual or aggregate analytics\n\nAdd hubs in Settings screen!";
    }

    // Data & Privacy
    if (msg.contains('data') || msg.contains('storage') || msg.contains('privacy') || msg.contains('secure')) {
      return "🔒 Data & Security:\n\nYour data is protected:\n• Firebase Authentication\n• Encrypted cloud storage\n• Real-time database sync\n• Per-user data isolation\n• Secure hub ownership\n\nData stored:\n✓ User profiles (Firestore)\n✓ Real-time metrics (Realtime DB)\n✓ Usage history\n✓ Settings & preferences\n✓ Notifications\n\nAll data is private to your account!";
    }

    // How to get started
    if (msg.contains('get started') || msg.contains('begin') || msg.contains('start using')) {
      return "🚀 Getting Started:\n\n1️⃣ Setup:\n   • Login/create account\n   • Add your hub in Settings\n   • Configure price per kWh\n\n2️⃣ Add Devices:\n   • Go to Devices screen\n   • Add your smart plugs\n   • Give them nicknames\n\n3️⃣ Monitor:\n   • Check Dashboard for live data\n   • View Analytics for trends\n   • Review History for usage\n\n4️⃣ Optimize:\n   • Analyze consumption patterns\n   • Reduce energy waste\n   • Save money!\n\nYou're ready to go!";
    }

    // Energy consumption
    if (msg.contains('energy') || msg.contains('power') || msg.contains('usage') || msg.contains('consumption')) {
      return "⚡ Energy Monitoring:\n\nTrack 4 key metrics:\n\n📊 Power (Watts):\n• Instant consumption rate\n• Shows current load\n\n⚡ Voltage (Volts):\n• Electrical potential\n• Monitor stability\n\n🔌 Current (Amps):\n• Electrical flow\n• Safety monitoring\n\n💡 Energy (kWh):\n• Total consumption\n• Basis for cost calculation\n\nView on Dashboard, Analytics, and History screens!";
    }

    // Live Chart specific
    if (msg.contains('live chart') || msg.contains('60 second') || msg.contains('real-time chart')) {
      return "⚡ 60-Second Live Chart:\n\nReal-time streaming visualization:\n\n🔴 LIVE FEATURES:\n• Updates EVERY SECOND\n• Shows last 60 seconds of data\n• Smooth line animation\n• Current value display with icon\n• Color-coded by metric\n\n🎨 VISUAL INDICATORS:\n• Green border = Recording active\n• Red border = SSR paused\n• Green WiFi icon = Connected\n• Red WiFi icon = Offline (5+ min)\n• Orange pause symbol = Chart paused\n\n📊 DISPLAYS:\n• Selected metric in real-time\n• Active hub count\n• Data aggregation status\n• Connection timestamp\n• Current time clock\n\n💾 EXPORT:\n• Download 60-second data as Excel\n• Includes all 4 metrics\n• Filename: SmartEnergyMeter_LiveData_60sec_[timestamp].xlsx\n\n🔧 REQUIREMENTS:\n• SSR must be ON for updates\n• At least one hub active\n• Internet connection required\n\nFind at top of Analytics screen!";
    }

    // Historical Analytics specific
    if (msg.contains('historical analytics') || msg.contains('historical data') || msg.contains('trend analysis')) {
      return "📊 Historical Analytics:\n\nLong-term trend visualization:\n\n⏰ TIME RANGES:\n• Hourly: Last 24 hours\n  - Hour-by-hour breakdown\n  - X-axis: Every 4 hours\n• Daily: Last 7 days\n  - Day-by-day totals\n  - X-axis: Every 1 day\n• Weekly: Last 28 days (4 weeks)\n  - Week summaries\n  - X-axis: Every 5 days\n• Monthly: Last 180 days (6 months)\n  - Month-by-month reports\n  - X-axis: Every 30 days\n\n📈 CHART FEATURES:\n• Smooth animated line curves\n• Data point dots at each interval\n• Gradient fill below line\n• Grid lines for easy reading\n• Touch tooltips with details\n• Auto-scaling Y-axis\n• Time-progressing X-axis\n\n🔍 GAP DETECTION:\nChart splits when disconnections occur:\n• Hourly: 3+ hour gaps\n• Daily: 2+ day gaps\n• Weekly: 10+ day gaps\n• Monthly: 45+ day gaps\n\n📊 STATISTICS CARDS:\n• Min (Blue) - Lowest value\n• Avg (Green) - Average value\n• Max (Orange) - Highest value\n• Auto-calculated for time range\n• Energy shows cost in ₱\n\n💾 EXPORT OPTIONS:\n• Excel: Full XLSX download\n• CSV: Copy to clipboard\n\nFind below live chart in Analytics!";
    }

    // Time ranges explanation
    if (msg.contains('time range') || msg.contains('hourly daily weekly monthly')) {
      return "⏰ Analytics Time Ranges:\n\n🕐 HOURLY (24 Hours):\n• Duration: Last 24 hours\n• Resolution: Per hour\n• Data points: ~24 points\n• Best for: Recent activity patterns\n• Gap threshold: 3 hours\n\n📅 DAILY (7 Days):\n• Duration: Last 7 days\n• Resolution: Per day\n• Data points: ~7 points\n• Best for: Week overview\n• Gap threshold: 2 days\n\n📆 WEEKLY (28 Days):\n• Duration: Last 28 days (4 weeks)\n• Resolution: Per week\n• Data points: ~4 points\n• Best for: Monthly trends\n• Gap threshold: 10 days\n\n🗓️ MONTHLY (180 Days):\n• Duration: Last 180 days (6 months)\n• Resolution: Per month\n• Data points: ~6 points\n• Best for: Long-term analysis\n• Gap threshold: 45 days\n\n💡 TIPS:\n• Shorter ranges = more detail\n• Longer ranges = broader trends\n• Switch ranges to compare patterns\n• Data auto-filtered by duration\n• X-axis intervals adjust automatically\n\nSelect in Analytics screen!";
    }

    // Statistics cards
    if (msg.contains('statistics') || msg.contains('min max avg') || msg.contains('stats card')) {
      return "📊 Statistics Cards:\n\nAuto-calculated metrics:\n\n🔵 MIN (Minimum):\n• Lowest value in time range\n• Blue color coding\n• Shows unit (W/V/A/kWh)\n• Useful for baseline usage\n\n🟢 AVG (Average):\n• Mean value across range\n• Green color coding\n• Shows unit (W/V/A/kWh)\n• Typical consumption level\n\n🟠 MAX (Maximum):\n• Highest value in time range\n• Orange color coding\n• Shows unit (W/V/A/kWh)\n• Peak usage indicator\n\n💰 ENERGY SPECIAL:\nWhen Energy metric selected:\n• Min/Avg/Max in kWh\n• PLUS cost calculation\n• Shows ₱ (Philippine Peso)\n• Uses price from Settings\n\n📈 UPDATES:\n• Recalculates on time range change\n• Updates on metric change\n• Updates on hub change\n• Updates on new data arrival\n\n🎯 USE CASES:\n• Identify peak usage times\n• Compare consumption patterns\n• Budget planning (with cost)\n• Detect anomalies\n\nVisible at top of Historical Analytics!";
    }

    // Charts & Graphs (general)
    if (msg.contains('chart') || msg.contains('graph') || msg.contains('visualization')) {
      return "📊 Charts & Visualization:\n\nInteractive charts available:\n\n⚡ 60-SECOND LIVE CHART:\n• Real-time line chart\n• Per-second updates\n• Current value display\n• Connection status\n• SSR state indicator\n\n📊 HISTORICAL ANALYTICS:\n• Animated line charts\n• 4 time ranges available\n• Statistics cards display\n• Touch tooltips\n• Gap detection\n\n📈 DASHBOARD:\n• Live monitoring chart\n• Per-second updates\n• Single metric view\n• Daily totals\n\nCHART FEATURES:\n✓ Color-coded metrics\n✓ Touch interaction\n✓ Auto-scaling axes\n✓ Smooth animations\n✓ Gradient fills\n✓ Grid lines\n✓ Responsive design\n\n🎨 METRIC COLORS:\n• Purple = Power\n• Orange = Voltage\n• Blue = Current\n• Green = Energy\n\nVisual insights at a glance!";
    }

    // Admin
    if (msg.contains('admin')) {
      return "👨‍💼 Admin Features:\n\nAdmin dashboard includes:\n• View all users\n• Monitor all hubs\n• System-wide device overview\n• Aggregated metrics\n• User administration\n• Hub assignment tracking\n\nAdmin access required for this screen.";
    }

    // Troubleshooting
    if (msg.contains('not working') || msg.contains('problem') || msg.contains('issue') || msg.contains('error') || msg.contains('troubleshoot')) {
      return "🔧 Troubleshooting:\n\nCommon solutions:\n\n❌ No data showing:\n• Check hub is connected\n• Verify SSR is ON\n• Ensure devices are active\n\n❌ Charts not updating:\n• Check internet connection\n• Toggle SSR off/on\n• Refresh the screen\n\n❌ Device not responding:\n• Check hub connection\n• Verify device is online\n• Try toggling device\n\nStill issues? Check Settings screen!";
    }

    // Help
    if (msg.contains('help') || msg.contains('guide') || msg.contains('tutorial')) {
      return "💡 Need Help?\n\nPopular topics:\n\n📱 Features:\n• 'What features?' - App overview\n• 'How to use dashboard?' - Monitoring\n• 'How to add devices?' - Device setup\n\n📊 Monitoring:\n• 'Energy monitoring' - Metrics info\n• 'Real-time updates' - Live data\n• 'Analytics' - Trends & patterns\n\n⚙️ Setup:\n• 'Settings' - Configuration\n• 'Pricing' - Cost setup\n• 'Multi-hub' - Multiple hubs\n\n📤 Data:\n• 'Export' - Excel downloads\n• 'History' - Usage records\n\nAsk me anything!";
    }

    // Thank you
    if (msg.contains('thank')) {
      return "😊 You're welcome! I'm here anytime you need help with your Smart Energy System.\n\nFeel free to ask about features, troubleshooting, or how to use any part of the app!";
    }

    // Goodbye
    if (msg.contains('bye') || msg.contains('goodbye') || msg.contains('see you')) {
      return "👋 Goodbye! Come back anytime if you need help managing your energy consumption. Have a great day!";
    }

    // Scheduling (future feature placeholder)
    if (msg.contains('schedule') || msg.contains('automation') || msg.contains('timer')) {
      return "📅 Scheduling:\n\nScheduling features for device automation are planned for future updates!\n\nCurrently available:\n• Manual device control\n• Real-time monitoring\n• Usage history\n• Analytics\n\nStay tuned for automation features!";
    }

    // Default response with suggestions
    return "I heard: \"$userMessage\"\n\n🤔 Not sure about that! Try asking:\n\n"
        "📊 LIVE DATA:\n"
        "• 'Current energy usage' - Real-time metrics\n"
        "• 'Daily cost' - Today's spending\n"
        "• 'Monthly estimate' - Projected bill\n"
        "• 'Status' - Quick overview\n\n"
        "📜 HISTORY:\n"
        "• 'History' - Recent usage records\n"
        "• 'Daily history' - Last 5 days\n"
        "• 'Compare today vs yesterday'\n"
        "• 'Usage comparison'\n\n"
        "🔌 DEVICES & HUBS:\n"
        "• 'Show my hubs' - Hub status\n"
        "• 'Show my devices' - Device list\n"
        "• 'Top consumer' - Highest usage\n\n"
        "📈 ANALYTICS:\n"
        "• 'Analytics summary' - Stats\n"
        "• 'What's my price?' - Current rate\n\n"
        "💡 GUIDES:\n"
        "• 'Features' - App capabilities\n"
        "• 'How to use dashboard?' - Help\n\n"
        "What would you like to know?";
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }

  Future<String> _generateWelcomeMessage() async {
    try {
      // Get system overview
      final hubs = await _dataService.getUserHubs();
      final devices = await _dataService.getUserDevices();
      final metrics = await _dataService.getCurrentEnergyMetrics();

      String statusMsg = '';

      if (hubs.isEmpty) {
        statusMsg = '⚠️ No hubs connected. Add a hub in Settings to get started!';
      } else {
        final onlineHubs = hubs.where((h) => h['isOnline'] == true).length;
        final totalHubs = hubs.length;

        if (metrics != null && metrics['online'] == true) {
          final power = metrics['power'] as double;
          statusMsg = '✅ System Online\n';
          statusMsg += '📊 Hubs: $onlineHubs/$totalHubs active\n';
          statusMsg += '🔌 Devices: ${devices.length}\n';
          statusMsg += '⚡ Current Power: ${power.toStringAsFixed(1)} W';
        } else {
          statusMsg = '⚠️ System Offline\n';
          statusMsg += '📊 Hubs: $onlineHubs/$totalHubs online\n';
          statusMsg += 'Waiting for hub data...';
        }
      }

      return "👋 Hello! I'm your Smart Energy Assistant.\n\n"
          "$statusMsg\n\n"
          "💬 You can ask me:\n"
          "• 'Current energy usage'\n"
          "• 'Daily cost'\n"
          "• 'Monthly estimate'\n"
          "• 'Show my hubs'\n"
          "• 'Show my devices'\n"
          "• 'Top consumer'\n"
          "• 'Analytics summary'\n"
          "• 'What's my price?'\n\n"
          "What would you like to know?";
    } catch (e) {
      return "👋 Hello! I'm your Smart Energy Assistant.\n\n"
          "I can provide real-time information about your energy usage, costs, devices, and more.\n\n"
          "What would you like to know?";
    }
  }

  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width <
        600; // Define your small screen breakpoint
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = _isSmallScreen(context);
    final panelWidth = isSmallScreen
        ? MediaQuery.of(context).size.width
        : MediaQuery.of(context).size.width * 0.4;

    return SlideTransition(
      position: _slideAnimation,
      child: Align(
        alignment: Alignment.centerRight,
        child: Theme(
          data: darkTheme, // Apply the dark theme explicitly
          child: Material(
            elevation: 16,
            shadowColor: Colors.black45,
            child: Container(
              width: panelWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).cardColor,
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.3).round()),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withAlpha(
                                  (255 * 0.2).round(),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.smart_toy,
                                color: Colors.teal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Smart Assistant",
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _isOnline ? Colors.green : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isOnline ? "Online" : "Offline",
                                      style: TextStyle(
                                        color: _isOnline ? Colors.green : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: () {
                                _slideController.reverse().then((_) {
                                  Navigator.of(context).pop();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Messages
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color?.withAlpha(77),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Start a conversation",
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withAlpha(128),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isUser = msg["sender"] == "user";
                              return _buildMessageBubble(
                                context,
                                msg["message"]!,
                                isUser,
                              );
                            },
                          ),
                  ),

                  // Typing indicator
                  if (_isTyping)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2F45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTypingDot(0),
                              const SizedBox(width: 4),
                              _buildTypingDot(1),
                              const SizedBox(width: 4),
                              _buildTypingDot(2),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Sample questions chips
                  if (_messages.isNotEmpty && !_isTyping)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Try asking:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(179),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSampleQuestionChip(context, '⚡ Current usage', 'Current energy usage'),
                                const SizedBox(width: 8),
                                _buildSampleQuestionChip(context, '💰 Daily cost', 'Daily cost'),
                                const SizedBox(width: 8),
                                _buildSampleQuestionChip(context, '📅 Monthly estimate', 'Monthly estimate'),
                                const SizedBox(width: 8),
                                _buildSampleQuestionChip(context, '🔌 Show devices', 'Show my devices'),
                                const SizedBox(width: 8),
                                _buildSampleQuestionChip(context, '🔗 Show hubs', 'Show my hubs'),
                                const SizedBox(width: 8),
                                _buildSampleQuestionChip(context, '🏆 Top consumer', 'Top consumer'),
                                const SizedBox(width: 8),
                                _buildSampleQuestionChip(context, '📊 Status', 'Status'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input field
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.3).round()),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                style: Theme.of(context).textTheme.bodyLarge,
                                decoration: InputDecoration(
                                  hintText: "Type your message...",
                                  hintStyle: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color
                                        ?.withAlpha(128),
                                  ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                                textInputAction: TextInputAction.send,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary,
                                    Theme.of(
                                      context,
                                    ).colorScheme.secondary.withAlpha(150),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: Theme.of(context).iconTheme.color,
                                ),
                                onPressed: _sendMessage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    String message,
    bool isUser,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withAlpha((255 * 0.2).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(
                            context,
                          ).colorScheme.secondary.withAlpha(150),
                        ],
                      )
                    : null,
                color: isUser ? null : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.2).round()),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
                child: SelectableText(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondary.withAlpha((255 * 0.2).round()),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value - delay).clamp(0.0, 1.0);
        final opacity = (animValue * 2).clamp(0.3, 1.0);

        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildSampleQuestionChip(BuildContext context, String label, String query) {
    return InkWell(
      onTap: () {
        _controller.text = query;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withAlpha((255 * 0.15).round()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.teal.withAlpha((255 * 0.3).round()),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.teal,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
