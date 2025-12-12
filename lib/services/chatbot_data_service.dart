import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants.dart';
import '../realtime_db_service.dart';
import '../services/usage_history_service.dart';
import '../models/usage_history_entry.dart';

/// Service class to fetch real-time data for the chatbot
class ChatbotDataService {
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final UsageHistoryService _usageHistoryService;

  ChatbotDataService() {
    final realtimeDbService = RealtimeDbService();
    _usageHistoryService = UsageHistoryService(realtimeDbService);
  }

  /// Get current user's energy metrics (power, voltage, current, energy)
  Future<Map<String, dynamic>?> getCurrentEnergyMetrics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Get user's hubs
      final hubsSnapshot = await _rtdbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!hubsSnapshot.exists || hubsSnapshot.value == null) {
        return null;
      }

      final hubsData = Map<String, dynamic>.from(hubsSnapshot.value as Map);

      // Aggregate data from all hubs
      double totalPower = 0.0;
      double totalVoltage = 0.0;
      double totalCurrent = 0.0;
      double totalEnergy = 0.0;
      int activeHubs = 0;
      DateTime? latestTimestamp;
      bool anyHubOnline = false;

      for (var hubEntry in hubsData.entries) {
        final hubData = hubEntry.value as Map?;
        if (hubData == null) continue;

        // Data is stored under plugs/{plugId}/data, not directly under hub/data
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

                    // Check if data is recent (within last 5 minutes)
                    final minutesSinceUpdate = DateTime.now().difference(timestamp).inMinutes;
                    if (minutesSinceUpdate < 5) {
                      anyHubOnline = true;
                      activeHubs++;

                      totalPower += (plugData['power'] as num?)?.toDouble() ?? 0.0;
                      totalVoltage += (plugData['voltage'] as num?)?.toDouble() ?? 0.0;
                      totalCurrent += (plugData['current'] as num?)?.toDouble() ?? 0.0;
                      totalEnergy += (plugData['energy'] as num?)?.toDouble() ?? 0.0;

                      if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
                        latestTimestamp = timestamp;
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing timestamp in getCurrentEnergyMetrics: $e');
                }
              }
            }
          }
        }
      }

      if (!anyHubOnline) {
        return {
          'online': false,
          'message': 'No recent data from hubs (check if hubs are connected)',
        };
      }

      // Average voltage (not summed)
      final avgVoltage = activeHubs > 0 ? totalVoltage / activeHubs : 0.0;

      return {
        'online': true,
        'power': totalPower,
        'voltage': avgVoltage,
        'current': totalCurrent,
        'energy': totalEnergy,
        'activeHubs': activeHubs,
        'lastUpdate': latestTimestamp,
      };
    } catch (e) {
      debugPrint('Error fetching energy metrics: $e');
      return null;
    }
  }

  /// Get user's hub information
  Future<List<Map<String, dynamic>>> getUserHubs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final hubsSnapshot = await _rtdbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!hubsSnapshot.exists || hubsSnapshot.value == null) {
        return [];
      }

      final hubsData = Map<String, dynamic>.from(hubsSnapshot.value as Map);
      final List<Map<String, dynamic>> hubs = [];

      for (var hubEntry in hubsData.entries) {
        final hubData = hubEntry.value as Map?;
        if (hubData == null) continue;

        final serialNumber = hubEntry.key;
        final nickname = hubData['nickname'] as String? ?? 'Unnamed Hub';
        final ssrState = hubData['ssr_state'] as bool? ?? false;
        final ownerId = hubData['ownerId'] as String? ?? '';

        // Check if hub is online by looking at plug data
        bool isOnline = false;
        DateTime? lastSeen;
        final plugsMap = hubData['plugs'] as Map?;
        if (plugsMap != null) {
          for (var plugEntry in plugsMap.values) {
            if (plugEntry is Map && plugEntry['data'] != null) {
              final plugData = plugEntry['data'] as Map?;
              if (plugData != null && plugData['lastUpdate'] != null) {
                try {
                  final lastUpdateMs = plugData['lastUpdate'] as num?;
                  if (lastUpdateMs != null) {
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(lastUpdateMs.toInt());
                    final minutesSinceUpdate = DateTime.now().difference(timestamp).inMinutes;
                    if (minutesSinceUpdate < 5) {
                      isOnline = true;
                    }
                    if (lastSeen == null || timestamp.isAfter(lastSeen)) {
                      lastSeen = timestamp;
                    }
                  }
                } catch (e) {
                  debugPrint('Error parsing lastUpdate in getUserHubs: $e');
                }
              }
            }
          }
        }

        hubs.add({
          'serialNumber': serialNumber,
          'nickname': nickname,
          'ssrState': ssrState,
          'isOnline': isOnline,
          'lastSeen': lastSeen,
          'ownerId': ownerId,
        });
      }

      return hubs;
    } catch (e) {
      debugPrint('Error fetching user hubs: $e');
      return [];
    }
  }

  /// Get user's devices/plugs information
  Future<List<Map<String, dynamic>>> getUserDevices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final hubsSnapshot = await _rtdbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!hubsSnapshot.exists || hubsSnapshot.value == null) {
        return [];
      }

      final hubsData = Map<String, dynamic>.from(hubsSnapshot.value as Map);
      final List<Map<String, dynamic>> devices = [];

      for (var hubEntry in hubsData.entries) {
        final hubData = hubEntry.value as Map?;
        if (hubData == null) continue;

        final hubSerial = hubEntry.key;
        final hubNickname = hubData['nickname'] as String? ?? 'Unnamed Hub';
        final plugsData = hubData['plugs'] as Map?;

        if (plugsData != null) {
          for (var plugEntry in plugsData.entries) {
            final plugData = plugEntry.value as Map?;
            if (plugData == null) continue;

            final plugId = plugEntry.key;
            final nickname = plugData['nickname'] as String? ?? 'Device $plugId';

            // Get data from the 'data' field where actual metrics are stored
            final dataMap = plugData['data'] as Map?;
            final state = (dataMap?['ssr_state'] as bool?) ?? false;
            final power = (dataMap?['power'] as num?)?.toDouble() ?? 0.0;
            final energy = (dataMap?['energy'] as num?)?.toDouble() ?? 0.0;

            devices.add({
              'plugId': plugId,
              'nickname': nickname,
              'state': state,
              'power': power,
              'energy': energy,
              'hubSerial': hubSerial,
              'hubNickname': hubNickname,
            });
          }
        }
      }

      return devices;
    } catch (e) {
      debugPrint('Error fetching user devices: $e');
      return [];
    }
  }

  /// Get current price per kWh from Firestore
  Future<double> getCurrentPrice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0.0;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('pricePerKWH')) {
        return (doc.data()!['pricePerKWH'] as num).toDouble();
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error fetching price: $e');
      return 0.0;
    }
  }

  /// Get daily energy and cost
  Future<Map<String, dynamic>> getDailyEnergyAndCost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'energy': 0.0, 'cost': 0.0};

    try {
      final price = await getCurrentPrice();

      // Get current energy
      final metrics = await getCurrentEnergyMetrics();
      final currentEnergy = metrics?['energy'] ?? 0.0;

      // Get yesterday's energy from daily aggregation
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      double yesterdayEnergy = 0.0;
      final hubsSnapshot = await _rtdbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (hubsSnapshot.exists && hubsSnapshot.value != null) {
        final hubsData = Map<String, dynamic>.from(hubsSnapshot.value as Map);
        for (var hubEntry in hubsData.entries) {
          final hubData = hubEntry.value as Map?;
          if (hubData == null) continue;

          final dailyData = hubData['daily_aggregation'] as Map?;
          if (dailyData != null && dailyData[yesterdayKey] != null) {
            final dayData = dailyData[yesterdayKey] as Map?;
            yesterdayEnergy += (dayData?['total_energy'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      final dailyEnergy = (currentEnergy - yesterdayEnergy).clamp(0.0, double.infinity);
      final dailyCost = dailyEnergy * price;

      return {
        'energy': dailyEnergy,
        'cost': dailyCost,
        'price': price,
      };
    } catch (e) {
      debugPrint('Error fetching daily energy and cost: $e');
      return {'energy': 0.0, 'cost': 0.0};
    }
  }

  /// Get monthly cost estimate
  /// Uses the same approach as energy_overview_screen: current energy minus yesterday's energy
  Future<Map<String, dynamic>> getMonthlyEstimate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {'energy': 0.0, 'cost': 0.0, 'dailyAverage': 0.0};

    try {
      final price = await getCurrentPrice();

      // Get daily energy and cost (this already calculates today's usage)
      final dailyData = await getDailyEnergyAndCost();
      final dailyEnergy = dailyData['energy'] as double;

      // Estimate monthly cost (daily * 30 days) - same as energy_overview_screen
      final monthlyEnergy = dailyEnergy * 30;
      final monthlyCost = monthlyEnergy * price;

      debugPrint('[ChatbotDataService] Monthly Estimate - Daily Energy: ${dailyEnergy.toStringAsFixed(2)} kWh, '
          'Monthly Cost: \$${monthlyCost.toStringAsFixed(2)}');

      return {
        'energy': monthlyEnergy,
        'cost': monthlyCost,
        'dailyAverage': dailyEnergy,
        'price': price,
      };
    } catch (e) {
      debugPrint('Error fetching monthly estimate: $e');
      return {'energy': 0.0, 'cost': 0.0, 'dailyAverage': 0.0, 'price': 0.0};
    }
  }

  /// Get top energy consumer device
  Future<Map<String, dynamic>?> getTopConsumer() async {
    final devices = await getUserDevices();
    if (devices.isEmpty) return null;

    // Sort by energy consumption
    devices.sort((a, b) => (b['energy'] as double).compareTo(a['energy'] as double));

    final topDevice = devices.first;
    final price = await getCurrentPrice();
    final cost = topDevice['energy'] * price;

    return {
      'nickname': topDevice['nickname'],
      'energy': topDevice['energy'],
      'cost': cost,
      'power': topDevice['power'],
      'state': topDevice['state'],
    };
  }

  /// Get analytics summary for a specific time range
  Future<Map<String, dynamic>> getAnalyticsSummary(String timeRange) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final hubsSnapshot = await _rtdbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!hubsSnapshot.exists || hubsSnapshot.value == null) {
        return {};
      }

      final hubsData = Map<String, dynamic>.from(hubsSnapshot.value as Map);

      double minValue = double.infinity;
      double maxValue = 0.0;
      double sumValue = 0.0;
      int count = 0;

      final now = DateTime.now();
      DateTime startTime;

      switch (timeRange.toLowerCase()) {
        case 'hourly':
          startTime = now.subtract(const Duration(hours: 24));
          break;
        case 'daily':
          startTime = now.subtract(const Duration(days: 7));
          break;
        case 'weekly':
          startTime = now.subtract(const Duration(days: 28));
          break;
        case 'monthly':
          startTime = now.subtract(const Duration(days: 180));
          break;
        default:
          startTime = now.subtract(const Duration(hours: 24));
      }

      for (var hubEntry in hubsData.entries) {
        final hubData = hubEntry.value as Map?;
        if (hubData == null) continue;

        final aggregationKey = '${timeRange.toLowerCase()}_aggregation';
        final aggregationData = hubData[aggregationKey] as Map?;

        if (aggregationData != null) {
          for (var entry in aggregationData.entries) {
            try {
              final timestamp = DateTime.parse(entry.key as String);
              if (timestamp.isAfter(startTime) && timestamp.isBefore(now)) {
                final data = entry.value as Map?;
                final energy = (data?['total_energy'] as num?)?.toDouble() ?? 0.0;

                if (energy > 0) {
                  sumValue += energy;
                  count++;
                  if (energy < minValue) minValue = energy;
                  if (energy > maxValue) maxValue = energy;
                }
              }
            } catch (e) {
              continue;
            }
          }
        }
      }

      if (count == 0) {
        return {
          'min': 0.0,
          'max': 0.0,
          'avg': 0.0,
          'count': 0,
        };
      }

      return {
        'min': minValue == double.infinity ? 0.0 : minValue,
        'max': maxValue,
        'avg': sumValue / count,
        'count': count,
        'total': sumValue,
      };
    } catch (e) {
      debugPrint('Error fetching analytics summary: $e');
      return {};
    }
  }

  /// Get due date information
  Future<Map<String, dynamic>?> getDueDateInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('dueDate')) {
        final dueDate = (doc.data()!['dueDate'] as Timestamp).toDate();
        final daysRemaining = dueDate.difference(DateTime.now()).inDays;

        return {
          'dueDate': dueDate,
          'daysRemaining': daysRemaining,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching due date: $e');
      return null;
    }
  }

  /// Get recent history records using UsageHistoryService
  /// Uses the same approach as the History screen for consistent data
  Future<Map<String, dynamic>> getRecentHistory({String timeRange = 'daily', int limit = 5}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      // Get user's hubs first
      final hubs = await getUserHubs();
      if (hubs.isEmpty) {
        return {
          'records': [],
          'totalEnergy': 0.0,
          'avgPower': 0.0,
          'totalCost': 0.0,
          'count': 0,
          'price': 0.0,
        };
      }

      // Use the first hub (or you could aggregate across all hubs)
      final hubSerial = hubs.first['serialNumber'] as String;

      // Map timeRange to UsageInterval
      UsageInterval interval;
      switch (timeRange.toLowerCase()) {
        case 'hourly':
          interval = UsageInterval.hourly;
          break;
        case 'weekly':
          interval = UsageInterval.weekly;
          break;
        case 'monthly':
          interval = UsageInterval.monthly;
          break;
        case 'daily':
        default:
          interval = UsageInterval.daily;
          break;
      }

      // Get usage history from the service
      final entries = await _usageHistoryService.calculateUsageHistory(
        hubSerialNumber: hubSerial,
        interval: interval,
        minRows: limit,
        offset: 0,
      );

      if (entries.isEmpty) {
        return {
          'records': [],
          'totalEnergy': 0.0,
          'avgPower': 0.0,
          'totalCost': 0.0,
          'count': 0,
          'price': 0.0,
        };
      }

      // Convert UsageHistoryEntry to the format expected by chatbot
      final price = await getCurrentPrice();
      final records = entries.take(limit).map((entry) {
        final cost = entry.usage * price;
        return {
          'timestamp': entry.timestamp,
          'hubNickname': hubs.first['nickname'] ?? 'Hub',
          'usage': entry.usage,
          'cost': cost,
          'currentReading': entry.currentReading,
          'previousReading': entry.previousReading,
        };
      }).toList();

      // Calculate totals
      double totalEnergy = 0.0;
      double totalCost = 0.0;

      for (var record in records) {
        totalEnergy += record['usage'] as double;
        totalCost += record['cost'] as double;
      }

      return {
        'records': records,
        'totalEnergy': totalEnergy,
        'avgPower': 0.0, // Usage history doesn't track power, only energy
        'totalCost': totalCost,
        'count': records.length,
        'price': price,
      };
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return {
        'records': [],
        'totalEnergy': 0.0,
        'avgPower': 0.0,
        'totalCost': 0.0,
        'count': 0,
        'price': 0.0,
      };
    }
  }

  /// Get usage comparison (today vs yesterday, this week vs last week, etc.)
  Future<Map<String, dynamic>> getUsageComparison() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final hubsSnapshot = await _rtdbRef
          .child('$rtdbUserPath/hubs')
          .orderByChild('ownerId')
          .equalTo(user.uid)
          .get();

      if (!hubsSnapshot.exists || hubsSnapshot.value == null) {
        return {};
      }

      final hubsData = Map<String, dynamic>.from(hubsSnapshot.value as Map);

      double todayEnergy = 0.0;
      double yesterdayEnergy = 0.0;

      final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final yesterdayKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      for (var hubEntry in hubsData.entries) {
        final hubData = hubEntry.value as Map?;
        if (hubData == null) continue;

        final dailyData = hubData['daily_aggregation'] as Map?;
        if (dailyData != null) {
          if (dailyData[todayKey] != null) {
            final dayData = dailyData[todayKey] as Map?;
            todayEnergy += (dayData?['total_energy'] as num?)?.toDouble() ?? 0.0;
          }
          if (dailyData[yesterdayKey] != null) {
            final dayData = dailyData[yesterdayKey] as Map?;
            yesterdayEnergy += (dayData?['total_energy'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }

      final price = await getCurrentPrice();
      final difference = todayEnergy - yesterdayEnergy;
      final percentChange = yesterdayEnergy > 0 ? ((difference / yesterdayEnergy) * 100) : 0.0;

      return {
        'todayEnergy': todayEnergy,
        'yesterdayEnergy': yesterdayEnergy,
        'difference': difference,
        'percentChange': percentChange,
        'todayCost': todayEnergy * price,
        'yesterdayCost': yesterdayEnergy * price,
        'isIncreasing': difference > 0,
        'price': price,
      };
    } catch (e) {
      debugPrint('Error fetching usage comparison: $e');
      return {};
    }
  }

  /// Get user profile information
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      // Get data from Firebase Auth
      final email = user.email ?? 'No email';
      final uid = user.uid;
      final creationTime = user.metadata.creationTime;
      final lastSignIn = user.metadata.lastSignInTime;

      // Get additional data from Firestore
      final doc = await _firestore.collection('users').doc(uid).get();

      String fullName = 'Not set';
      String address = 'Not set';
      String phoneNumber = 'Not set';

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        fullName = data['fullName'] as String? ?? 'Not set';
        address = data['address'] as String? ?? 'Not set';
        phoneNumber = data['phoneNumber'] as String? ?? 'Not set';
      }

      return {
        'email': email,
        'uid': uid,
        'fullName': fullName,
        'address': address,
        'phoneNumber': phoneNumber,
        'accountCreated': creationTime,
        'lastSignIn': lastSignIn,
      };
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }
}
