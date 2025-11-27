import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'constants.dart';

class TimestampedFlSpot {
  final DateTime timestamp;
  final double power;
  final double voltage;
  final double current;
  final double energy; // Assuming this is energy consumption

  TimestampedFlSpot({
    required this.timestamp,
    this.power = 0.0,
    this.voltage = 0.0,
    this.current = 0.0,
    this.energy = 0.0,
  });
}

// Helper class for stream triggering
class _TriggerData {
  final List<String> hubSerialNumbers;
  _TriggerData(this.hubSerialNumbers);
}

class RealtimeDbService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  // Store a map of subscriptions, keyed by hub serial number
  final Map<String, List<StreamSubscription>> _hubSubscriptions = {};
  final _activeHubController = BehaviorSubject<List<String>>.seeded([]);

  // START: Added for primary hub tracking
  final _primaryHubController = BehaviorSubject<String?>.seeded(null);

  // Public stream for the UI to listen to
  Stream<List<String>> get activeHubStream => _activeHubController.stream;

  // Stream and getter for the primary hub
  Stream<String?> get primaryHubStream => _primaryHubController.stream;
  String? get primaryHub => _primaryHubController.value;

  /// Sets the primary hub for analytics across the app.
  void setPrimaryHub(String? serialNumber) {
    if (_primaryHubController.value != serialNumber) {
      _primaryHubController.add(serialNumber);
      debugPrint('[RealtimeDbService] Primary hub set to: $serialNumber');
    }
  }
  // END: Added for primary hub tracking

  // StreamController to broadcast structured hub data events to the UI
  final _hubDataController = StreamController<Map<String, dynamic>>.broadcast();

  // Public stream for the UI to listen to
  Stream<Map<String, dynamic>> get hubDataStream => _hubDataController.stream;

  // StreamController to broadcast hub removal events to all pages
  final _hubRemovedController = StreamController<String>.broadcast();

  // Public stream for pages to listen to hub removal events
  Stream<String> get hubRemovedStream => _hubRemovedController.stream;

  // StreamController to broadcast hub addition events to all pages
  final _hubAddedController = StreamController<Map<String, String>>.broadcast();

  // Public stream for pages to listen to hub addition events (contains serialNumber and nickname)
  Stream<Map<String, String>> get hubAddedStream => _hubAddedController.stream;

  // New getter to expose the current active hubs synchronously
  List<String> get currentActiveHubs => _activeHubController.value;

  void startRealtimeDataStream(String hubSerialNumber) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('User not authenticated, cannot start stream.');
      // Stop all streams if user logs out
      stopAllRealtimeDataStreams();
      return;
    }
    final String uid = user.uid;

    final currentActiveHubs = _activeHubController.value;
    if (currentActiveHubs.contains(hubSerialNumber)) {
      debugPrint('Stream already active for hub: $hubSerialNumber');
      return;
    }

    // Stop any existing streams for this specific hub before restarting
    // This is important if the hub was "active" but its stream somehow stopped
    _hubSubscriptions[hubSerialNumber]?.forEach((sub) => sub.cancel());
    _hubSubscriptions[hubSerialNumber] = []; // Clear old subscriptions

    final newActiveHubs = List<String>.from(currentActiveHubs)..add(hubSerialNumber);
    _activeHubController.add(newActiveHubs);

    final hubBasePath = '$rtdbUserPath/hubs/$hubSerialNumber';

    // 1. Listen to hub's main ssr_state changes
    // BUG FIX: Listen specifically to ssr_state child to catch toggle updates
    final hubSsrStateRef = _dbRef.child('$hubBasePath/ssr_state');
    final hubStateSub = hubSsrStateRef.onValue.listen((event) {
      if (!_hubDataController.isClosed) {
        final ssrState = event.snapshot.value as bool?;
        debugPrint('[RealtimeDbService] Hub $hubSerialNumber ssr_state event: $ssrState (snapshot.value: ${event.snapshot.value})');
        // CRITICAL FIX: Always broadcast the state, even if null, so UI can handle it
        // The UI will default to false if null
        _hubDataController.add({
          'type': 'hub_state',
          'serialNumber': hubSerialNumber,
          'ssr_state': ssrState ?? false, // Default to false if null
          'ownerId': uid, // Include current user's UID
        });
      }
    }, onError: _handleError);
    _hubSubscriptions[hubSerialNumber]!.add(hubStateSub);

    final plugsRef = _dbRef.child('$hubBasePath/plugs');

    // 2. Listen for plug changes (e.g., sensor data updates)
    final plugsChangedSub = plugsRef.onChildChanged.listen((event) {
      if (!_hubDataController.isClosed) {
        _hubDataController.add({
          'type': 'plug_changed',
          'serialNumber': hubSerialNumber,
          'plugId': event.snapshot.key,
          'plugData': event.snapshot.value,
        });
      }
    }, onError: _handleError);
    _hubSubscriptions[hubSerialNumber]!.add(plugsChangedSub);

    // 3. Listen for newly added plugs
    final plugsAddedSub = plugsRef.onChildAdded.listen((event) {
      if (!_hubDataController.isClosed) {
        _hubDataController.add({
          'type': 'plug_added',
          'serialNumber': hubSerialNumber,
          'plugId': event.snapshot.key,
          'plugData': event.snapshot.value,
        });
      }
    }, onError: _handleError);
    _hubSubscriptions[hubSerialNumber]!.add(plugsAddedSub);

    // 4. Listen for removed plugs
    final plugsRemovedSub = plugsRef.onChildRemoved.listen((event) {
      if (!_hubDataController.isClosed) {
        _hubDataController.add({
          'type': 'plug_removed',
          'serialNumber': hubSerialNumber,
          'plugId': event.snapshot.key,
        });
      }
    }, onError: _handleError);
    _hubSubscriptions[hubSerialNumber]!.add(plugsRemovedSub);

    debugPrint('Efficient real-time streams started for hub: $hubSerialNumber');
  }

  void stopRealtimeDataStream(String hubSerialNumber) {
    // Stop streams for a specific hub
    _hubSubscriptions[hubSerialNumber]?.forEach((sub) => sub.cancel());
    _hubSubscriptions.remove(hubSerialNumber);

    final currentActiveHubs = List<String>.from(_activeHubController.value);
    currentActiveHubs.remove(hubSerialNumber);
    _activeHubController.add(currentActiveHubs);

    debugPrint('Real-time data streams stopped for hub: $hubSerialNumber.');
  }

  /// Handles hub removal - stops streams, clears primary hub if needed, and broadcasts removal event
  void notifyHubRemoved(String hubSerialNumber) {
    debugPrint('[RealtimeDbService] Hub removed: $hubSerialNumber');

    // Stop all streams for this hub
    stopRealtimeDataStream(hubSerialNumber);

    // Clear primary hub if it matches the removed hub
    if (_primaryHubController.value == hubSerialNumber) {
      _primaryHubController.add(null);
      debugPrint('[RealtimeDbService] Primary hub cleared as it was removed.');
    }

    // Broadcast removal event to all listening pages
    if (!_hubRemovedController.isClosed) {
      _hubRemovedController.add(hubSerialNumber);
      debugPrint('[RealtimeDbService] Broadcasted hub removal event for: $hubSerialNumber');
    }
  }

  /// Handles hub addition - starts streams, sets as primary if first hub, and broadcasts addition event
  void notifyHubAdded(String hubSerialNumber, {String? nickname}) {
    debugPrint('[RealtimeDbService] Hub added: $hubSerialNumber (nickname: $nickname)');

    // Start real-time data stream for the new hub
    startRealtimeDataStream(hubSerialNumber);

    // Set as primary hub if no other hub is currently primary
    if (_primaryHubController.value == null) {
      setPrimaryHub(hubSerialNumber);
      debugPrint('[RealtimeDbService] Set new hub as primary hub.');
    }

    // Broadcast addition event to all listening pages
    if (!_hubAddedController.isClosed) {
      _hubAddedController.add({
        'serialNumber': hubSerialNumber,
        'nickname': nickname ?? 'Central Hub',
      });
      debugPrint('[RealtimeDbService] Broadcasted hub addition event for: $hubSerialNumber');
    }
  }

  void stopAllRealtimeDataStreams() {
    for (final subs in _hubSubscriptions.values) {
      for (final sub in subs) {
        sub.cancel();
      }
    }
    _hubSubscriptions.clear();
    _activeHubController.add([]); // Emit empty list when all streams are stopped
    debugPrint('All real-time data streams stopped.');
  }

  void _handleError(Object error) {
    debugPrint('RealtimeDbService stream error: $error');
    if (!_hubDataController.isClosed) {
      _hubDataController.addError(error);
    }
  }

  void dispose() {
    stopAllRealtimeDataStreams();
    _hubDataController.close();
    _activeHubController.close();
    _primaryHubController.close(); // Close the new controller
    _hubRemovedController.close(); // Close the hub removed controller
    _hubAddedController.close(); // Close the hub added controller
  }

  Future<List<Map<String, dynamic>>> getHistoricalEnergyData(
    String userId,
    String deviceSerialNumber,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final dataRef = _dbRef
          .child('$rtdbUserPath/devices/$deviceSerialNumber/readings')
          .orderByKey() // Order by timestamp string
          .startAt(startTime.toIso8601String())
          .endAt(endTime.toIso8601String());

      final DataSnapshot snapshot = await dataRef.get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> readings =
            snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> historicalData = [];
        readings.forEach((key, value) {
          // Assuming key is the timestamp (ISO 8601 string) and value is a map of metrics
          // Further assumption: energy_consumption_kWh is directly under the timestamp
          if (value is Map<dynamic, dynamic> &&
              value.containsKey('energy_consumption_kWh')) {
                
            historicalData.add({
              'timestamp': DateTime.parse(key),
              'energy_consumption_kWh': (value['energy_consumption_kWh'] as num)
                  .toDouble(),
            });
          }
        });
        // Sort by timestamp to ensure correct order for chart
        historicalData.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        return historicalData;
      }
    } catch (e) {
      debugPrint(
        'Error fetching historical energy data for device $deviceSerialNumber: $e',
      );
    }
    return [];
  }

  Stream<List<TimestampedFlSpot>> getLiveChartDataStream() {
    debugPrint('getLiveChartDataStream called. Active Hubs: ${_activeHubController.value}');
    return _activeHubController.stream.switchMap((hubSerialNumbers) {
      if (hubSerialNumbers.isEmpty) {
        return Stream.value(<TimestampedFlSpot>[]);
      }

      final List<Stream<List<TimestampedFlSpot>>> individualHubStreams = [];

      for (final hubSerialNumber in hubSerialNumbers) {
        // Flutter writes timestamped records to per_second/data/
        final dataRef = _dbRef
            .child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second/data')
            .orderByKey()
            .limitToLast(65); // Last 65 seconds of data

        debugPrint('[getLiveChartDataStream] Listening to path: $rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second/data');

        individualHubStreams.add(dataRef.onValue.map((event) {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          debugPrint('[getLiveChartDataStream] Hub: $hubSerialNumber, data is null: ${data == null}, data keys: ${data?.keys.length ?? 0}');

          if (data == null) {
            debugPrint('[getLiveChartDataStream] No per_second/data found for hub: $hubSerialNumber');
            return <TimestampedFlSpot>[];
          }

          final List<TimestampedFlSpot> spots = [];

          // Structure: per_second/data/{timestamp}/ with timestamp, total_power, etc.
          data.forEach((key, value) {
            try {
              if (value is Map) {
                final timestampValue = value['timestamp'];
                if (timestampValue is int) {
                  final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
                  final power = (value['total_power'] as num? ?? 0.0).toDouble();
                  final voltage = (value['total_voltage'] as num? ?? 0.0).toDouble();
                  final current = (value['total_current'] as num? ?? 0.0).toDouble();
                  final energy = (value['total_energy'] as num? ?? 0.0).toDouble();

                  spots.add(TimestampedFlSpot(
                    timestamp: timestamp,
                    power: power,
                    voltage: voltage,
                    current: current,
                    energy: energy,
                  ));
                }
              }
            } catch (e) {
              debugPrint('[getLiveChartDataStream] Failed to parse record $key for hub $hubSerialNumber: $e');
            }
          });

          debugPrint('[getLiveChartDataStream] Hub: $hubSerialNumber, parsed ${spots.length} spots');
          return spots;
        }).handleError((error) {
          debugPrint('Error streaming live chart data for hub $hubSerialNumber: $error');
          return <TimestampedFlSpot>[];
        }));
      }

      // Combine the streams from all active hubs
      return Rx.combineLatestList<List<TimestampedFlSpot>>(individualHubStreams)
          .map((listOfLists) {
        final allSpots = listOfLists.expand((list) => list).toList();
        allSpots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        debugPrint('[getLiveChartDataStream] Combined spots from all hubs: ${allSpots.length}');
        return allSpots;
      });
    });
  }

  /// Get live chart data stream for a specific hub only
  /// This allows filtering analytics to show data from a single hub
  Stream<List<TimestampedFlSpot>> getLiveChartDataStreamForHub(String hubSerialNumber) {
    debugPrint('getLiveChartDataStreamForHub called for hub: $hubSerialNumber');

    // Check if this hub is active
    return _activeHubController.stream.switchMap((hubSerialNumbers) {
      if (!hubSerialNumbers.contains(hubSerialNumber)) {
        debugPrint('[getLiveChartDataStreamForHub] Hub $hubSerialNumber not in active hubs list');
        return Stream.value(<TimestampedFlSpot>[]);
      }

      final dataRef = _dbRef
          .child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second/data')
          .orderByKey()
          .limitToLast(65); // Last 65 seconds of data

      debugPrint('[getLiveChartDataStreamForHub] Listening to: $rtdbUserPath/hubs/$hubSerialNumber/aggregations/per_second/data');

      return dataRef.onValue.map((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data == null) {
          debugPrint('[getLiveChartDataStreamForHub] No data for hub: $hubSerialNumber');
          return <TimestampedFlSpot>[];
        }

        final List<TimestampedFlSpot> spots = [];

        data.forEach((key, value) {
          try {
            if (value is Map) {
              final timestampValue = value['timestamp'];
              if (timestampValue is int) {
                final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampValue);
                final power = (value['total_power'] as num? ?? 0.0).toDouble();
                final voltage = (value['total_voltage'] as num? ?? 0.0).toDouble();
                final current = (value['total_current'] as num? ?? 0.0).toDouble();
                final energy = (value['total_energy'] as num? ?? 0.0).toDouble();

                spots.add(TimestampedFlSpot(
                  timestamp: timestamp,
                  power: power,
                  voltage: voltage,
                  current: current,
                  energy: energy,
                ));
              }
            }
          } catch (e) {
            debugPrint('[getLiveChartDataStreamForHub] Parse error for hub $hubSerialNumber: $e');
          }
        });

        spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        debugPrint('[getLiveChartDataStreamForHub] Hub $hubSerialNumber: ${spots.length} spots');
        return spots;
      }).handleError((error) {
        debugPrint('Error streaming data for hub $hubSerialNumber: $error');
        return <TimestampedFlSpot>[];
      });
    });
  }

  /// Get SSR state stream for a specific hub
  /// Returns a stream of boolean values indicating whether the hub's SSR is on (true) or off (false)
  Stream<bool> getHubSsrStateStream(String hubSerialNumber) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[getHubSsrStateStream] User not authenticated');
      return Stream.value(false);
    }

    final hubBasePath = '$rtdbUserPath/hubs/$hubSerialNumber';
    final hubSsrStateRef = _dbRef.child('$hubBasePath/ssr_state');

    return hubSsrStateRef.onValue.map((event) {
      final ssrState = event.snapshot.value as bool?;
      debugPrint('[getHubSsrStateStream] Hub $hubSerialNumber SSR state: $ssrState');
      return ssrState ?? false;
    }).handleError((error) {
      debugPrint('[getHubSsrStateStream] Error for hub $hubSerialNumber: $error');
      return false;
    });
  }

  /// Get combined SSR state for all active hubs
  /// Returns true if ANY hub has SSR on, false if ALL hubs have SSR off
  Stream<bool> getCombinedSsrStateStream() {
    return _activeHubController.stream.switchMap((hubSerialNumbers) {
      if (hubSerialNumbers.isEmpty) {
        return Stream.value(false);
      }

      final List<Stream<bool>> ssrStreams = hubSerialNumbers
          .map((serialNumber) => getHubSsrStateStream(serialNumber))
          .toList();

      return Rx.combineLatestList<bool>(ssrStreams).map((states) {
        // Return true if any hub has SSR on
        final anyOn = states.any((state) => state == true);
        debugPrint('[getCombinedSsrStateStream] Combined SSR state: $anyOn (from ${states.length} hubs)');
        return anyOn;
      });
    });
  }

  /// Get historical hourly aggregation data for a specific hub
  /// Returns a list of TimestampedFlSpot for the specified time range
  Future<List<TimestampedFlSpot>> getHourlyAggregationData(
    String hubSerialNumber,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[getHourlyAggregationData] User not authenticated');
        return [];
      }

      final hourlyRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/hourly');
      final snapshot = await hourlyRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('[getHourlyAggregationData] No hourly data found for hub: $hubSerialNumber');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<TimestampedFlSpot> spots = [];

      data.forEach((key, value) {
        try {
          if (value is Map) {
            // Key format: "2025-11-22-02" (YYYY-MM-DD-HH)
            final parts = (key as String).split('-');
            if (parts.length == 4) {
              final timestamp = DateTime(
                int.parse(parts[0]), // year
                int.parse(parts[1]), // month
                int.parse(parts[2]), // day
                int.parse(parts[3]), // hour
              );

              // Filter by time range (inclusive of boundaries)
              if (!timestamp.isBefore(startTime) && !timestamp.isAfter(endTime)) {
                final averagePower = (value['average_power'] as num? ?? 0.0).toDouble();
                final averageVoltage = (value['average_voltage'] as num? ?? 0.0).toDouble();
                final averageCurrent = (value['average_current'] as num? ?? 0.0).toDouble();
                final totalEnergy = (value['total_energy'] as num? ?? 0.0).toDouble();

                spots.add(TimestampedFlSpot(
                  timestamp: timestamp,
                  power: averagePower,
                  voltage: averageVoltage,
                  current: averageCurrent,
                  energy: totalEnergy,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('[getHourlyAggregationData] Error parsing hourly data key $key: $e');
        }
      });

      spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint('[getHourlyAggregationData] Loaded ${spots.length} hourly data points for hub $hubSerialNumber');
      return spots;
    } catch (e) {
      debugPrint('[getHourlyAggregationData] Error fetching hourly data: $e');
      return [];
    }
  }

  /// Get historical daily aggregation data for a specific hub
  /// Returns a list of TimestampedFlSpot for the specified time range
  Future<List<TimestampedFlSpot>> getDailyAggregationData(
    String hubSerialNumber,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[getDailyAggregationData] User not authenticated');
        return [];
      }

      final dailyRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/daily');
      final snapshot = await dailyRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('[getDailyAggregationData] No daily data found for hub: $hubSerialNumber');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<TimestampedFlSpot> spots = [];

      data.forEach((key, value) {
        try {
          if (value is Map) {
            // Try parsing timestamp field first (new format)
            DateTime? timestamp;
            if (value['timestamp'] != null) {
              timestamp = DateTime.parse(value['timestamp'] as String);
            } else {
              // Fallback to key format: "2025-11-20" (YYYY-MM-DD)
              final parts = (key as String).split('-');
              if (parts.length == 3) {
                timestamp = DateTime(
                  int.parse(parts[0]), // year
                  int.parse(parts[1]), // month
                  int.parse(parts[2]), // day
                );
              }
            }

            if (timestamp != null) {
              // Filter by time range (inclusive of boundaries)
              if (!timestamp.isBefore(startTime) && !timestamp.isAfter(endTime)) {
                final averagePower = (value['average_power'] as num? ?? value['average_power_w'] as num? ?? 0.0).toDouble();
                final averageVoltage = (value['average_voltage'] as num? ?? 0.0).toDouble();
                final averageCurrent = (value['average_current'] as num? ?? 0.0).toDouble();
                final totalEnergy = (value['total_energy'] as num? ?? 0.0).toDouble();

                spots.add(TimestampedFlSpot(
                  timestamp: timestamp,
                  power: averagePower,
                  voltage: averageVoltage,
                  current: averageCurrent,
                  energy: totalEnergy,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('[getDailyAggregationData] Error parsing daily data key $key: $e');
        }
      });

      spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint('[getDailyAggregationData] Loaded ${spots.length} daily data points for hub $hubSerialNumber');
      return spots;
    } catch (e) {
      debugPrint('[getDailyAggregationData] Error fetching daily data: $e');
      return [];
    }
  }

  /// Get historical weekly aggregation data for a specific hub
  /// Returns a list of TimestampedFlSpot for the specified time range
  Future<List<TimestampedFlSpot>> getWeeklyAggregationData(
    String hubSerialNumber,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[getWeeklyAggregationData] User not authenticated');
        return [];
      }

      final weeklyRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/weekly');
      final snapshot = await weeklyRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('[getWeeklyAggregationData] No weekly data found for hub: $hubSerialNumber');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<TimestampedFlSpot> spots = [];

      data.forEach((key, value) {
        try {
          if (value is Map) {
            // Parse timestamp from value (format: "2025-09-01T00:00:00+08:00")
            DateTime? timestamp;
            if (value['timestamp'] != null) {
              timestamp = DateTime.parse(value['timestamp'] as String);
            }

            if (timestamp != null) {
              // Filter by time range (inclusive of boundaries)
              if (!timestamp.isBefore(startTime) && !timestamp.isAfter(endTime)) {
                final averagePower = (value['average_power'] as num? ?? 0.0).toDouble();
                final averageVoltage = (value['average_voltage'] as num? ?? 0.0).toDouble();
                final averageCurrent = (value['average_current'] as num? ?? 0.0).toDouble();
                final totalEnergy = (value['total_energy'] as num? ?? 0.0).toDouble();

                spots.add(TimestampedFlSpot(
                  timestamp: timestamp,
                  power: averagePower,
                  voltage: averageVoltage,
                  current: averageCurrent,
                  energy: totalEnergy,
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('[getWeeklyAggregationData] Error parsing weekly data key $key: $e');
        }
      });

      spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint('[getWeeklyAggregationData] Loaded ${spots.length} weekly data points for hub $hubSerialNumber');
      return spots;
    } catch (e) {
      debugPrint('[getWeeklyAggregationData] Error fetching weekly data: $e');
      return [];
    }
  }

  /// Get historical monthly aggregation data for a specific hub
  /// Returns a list of TimestampedFlSpot for the specified time range
  Future<List<TimestampedFlSpot>> getMonthlyAggregationData(
    String hubSerialNumber,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[getMonthlyAggregationData] User not authenticated');
        return [];
      }

      final monthlyRef = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/monthly');
      final snapshot = await monthlyRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('[getMonthlyAggregationData] No monthly data found for hub: $hubSerialNumber');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<TimestampedFlSpot> spots = [];

      data.forEach((key, value) {
        try {
          if (value is Map) {
            // Parse timestamp from value (format: "2025-09-01T00:00:00+08:00")
            DateTime? timestamp;
            if (value['timestamp'] != null) {
              timestamp = DateTime.parse(value['timestamp'] as String);
            }

            debugPrint('[getMonthlyAggregationData] Processing key: $key, timestamp: $timestamp, startTime: $startTime, endTime: $endTime');

            if (timestamp != null) {
              // Filter by time range (inclusive of boundaries)
              final isInRange = !timestamp.isBefore(startTime) && !timestamp.isAfter(endTime);
              debugPrint('[getMonthlyAggregationData] Key $key in range: $isInRange');

              if (isInRange) {
                final averagePower = (value['average_power'] as num? ?? 0.0).toDouble();
                final averageVoltage = (value['average_voltage'] as num? ?? 0.0).toDouble();
                final averageCurrent = (value['average_current'] as num? ?? 0.0).toDouble();
                final totalEnergy = (value['total_energy'] as num? ?? 0.0).toDouble();

                spots.add(TimestampedFlSpot(
                  timestamp: timestamp,
                  power: averagePower,
                  voltage: averageVoltage,
                  current: averageCurrent,
                  energy: totalEnergy,
                ));
                debugPrint('[getMonthlyAggregationData] ✅ Added key $key to spots');
              }
            }
          }
        } catch (e) {
          debugPrint('[getMonthlyAggregationData] Error parsing monthly data key $key: $e');
        }
      });

      spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint('[getMonthlyAggregationData] ✅ Loaded ${spots.length} monthly data points for hub $hubSerialNumber');
      debugPrint('[getMonthlyAggregationData] Date range: $startTime to $endTime');
      for (final spot in spots) {
        debugPrint('[getMonthlyAggregationData]   - ${spot.timestamp}: ${spot.power}W');
      }
      return spots;
    } catch (e) {
      debugPrint('[getMonthlyAggregationData] Error fetching monthly data: $e');
      return [];
    }
  }

  /// Fetches paginated aggregated data for a specific hub and aggregation type.
  ///
  /// This method is designed for efficient, reverse chronological pagination.
  /// It fetches a `limit` number of records ending at `endAtKey`.
  Future<Map<String, dynamic>> getAggregatedDataPaginated({
    required String hubSerialNumber,
    required String aggregationType,
    required int limit,
    String? endAtKey,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[getAggregatedDataPaginated] User not authenticated');
        return {};
      }

      // OPTIMIZED: Fetch ALL data on initial load to show everything available
      // Only use pagination for loading more (when endAtKey is provided)
      final ref = _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/$aggregationType');

      final DataSnapshot snapshot;
      if (endAtKey != null) {
        // Pagination: fetch page before the endAtKey
        Query query = ref.orderByKey().endBefore(endAtKey).limitToLast(limit);
        snapshot = await query.get();
      } else {
        // Initial load: fetch ALL data (no limit, no query, no filtering!)
        // Just get everything directly from the reference
        snapshot = await ref.get();
      }

      if (snapshot.exists && snapshot.value != null) {
        // Data is returned as a Map, so we can just cast and return it.
        // The keys are the aggregation periods (e.g., "2025-11-20").
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        // Debug: Log the keys (dates) being returned
        final keys = data.keys.toList()..sort();
        debugPrint('[getAggregatedDataPaginated] $aggregationType: Fetched ${data.length} records. Keys: ${keys.take(5).join(", ")}${keys.length > 5 ? "... ${keys.skip(keys.length - 2).join(", ")}" : ""}');

        return data;
      } else {
        debugPrint('[getAggregatedDataPaginated] $aggregationType: No data found for hub $hubSerialNumber');
        return {};
      }
    } catch (e) {
      debugPrint('[getAggregatedDataPaginated] Error fetching paginated $aggregationType data: $e');
      return {};
    }
  }

  /// Stream the list of hubs owned by the current user.
  /// Returns a list of maps containing serialNumber and nickname for each hub.
  /// This eliminates the need for separate database calls to fetch hub lists.
  ///
  /// Returns: List<Map<String, String>> with format:
  /// [
  ///   {'serialNumber': 'ESP32_001', 'nickname': 'Living Room'},
  ///   {'serialNumber': 'ESP32_002', 'nickname': 'Bedroom'},
  /// ]
  Stream<List<Map<String, String>>> getHubListStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[getHubListStream] User not authenticated');
      return Stream.value([]);
    }

    final String uid = user.uid;
    final hubsRef = _dbRef.child('$rtdbUserPath/hubs');

    return hubsRef
        .orderByChild('ownerId')
        .equalTo(uid)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        debugPrint('[getHubListStream] No hubs found for user');
        return <Map<String, String>>[];
      }

      final hubs = Map<String, dynamic>.from(event.snapshot.value as Map);
      final List<Map<String, String>> hubList = [];

      for (final entry in hubs.entries) {
        final String serialNumber = entry.key;
        final hubData = entry.value is Map
            ? Map<String, dynamic>.from(entry.value)
            : {'nickname': null, 'assigned': true, 'ownerId': uid};

        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        // Only include hubs owned by this user
        if (isAssigned && hubOwnerId == uid) {
          final String nickname = hubData['nickname'] as String? ?? 'Hub ${serialNumber.substring(0, 6)}';
          hubList.add({
            'serialNumber': serialNumber,
            'nickname': nickname,
          });
        }
      }

      debugPrint('[getHubListStream] Streaming ${hubList.length} hubs');
      return hubList;
    });
  }

  /// Stream aggregated data for all user's hubs based on the selected aggregation type.
  /// This provides real-time updates when new aggregation data is written to Firebase.
  /// Returns a map with hub serial numbers as keys and their aggregated data as values.
  ///
  /// The returned data structure includes hub metadata (_hubNickname) along with aggregation data:
  /// {
  ///   "hub_serial_123": {
  ///     "_hubNickname": "My Hub",
  ///     "2025-01-15": { aggregation data... },
  ///     "2025-01-16": { aggregation data... },
  ///   }
  /// }
  Stream<Map<String, Map<String, dynamic>>> getAggregatedDataStreamForAllHubs(
    String aggregationType,
  ) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[getAggregatedDataStreamForAllHubs] User not authenticated');
      return Stream.value({});
    }

    final String uid = user.uid;

    // First, get the list of hubs owned by this user
    final hubsRef = _dbRef.child('$rtdbUserPath/hubs');

    return hubsRef
        .orderByChild('ownerId')
        .equalTo(uid)
        .onValue
        .switchMap((hubsEvent) { // Use switchMap to manage changing hub lists
      if (!hubsEvent.snapshot.exists || hubsEvent.snapshot.value == null) {
        debugPrint('[getAggregatedDataStreamForAllHubs] No hubs found for user');
        return Stream.value({});
      }

      final hubs = Map<String, dynamic>.from(hubsEvent.snapshot.value as Map);
      final List<Stream<MapEntry<String, Map<String, dynamic>>>> hubStreams = [];

      // For each hub, create a stream that listens to its aggregation data
      for (final hubEntry in hubs.entries) {
        final String serialNumber = hubEntry.key;
        final hubData = hubEntry.value is Map
            ? Map<String, dynamic>.from(hubEntry.value)
            : {'nickname': null, 'assigned': true, 'ownerId': uid};

        final bool isAssigned = hubData['assigned'] as bool? ?? false;
        final String? hubOwnerId = hubData['ownerId'] as String?;

        if (!isAssigned || hubOwnerId != uid) continue;

        // Extract nickname for inclusion in stream data
        final String nickname = hubData['nickname'] as String? ?? 'Hub ${serialNumber.substring(0, 6)}';

        final aggregatedRef = _dbRef.child(
          '$rtdbUserPath/hubs/$serialNumber/aggregations/$aggregationType'
        );

        hubStreams.add(
          aggregatedRef.onValue.map((event) { // Stream changes for each hub
            Map<String, dynamic> aggregationData = {};
            if (event.snapshot.exists && event.snapshot.value != null) {
              aggregationData = Map<String, dynamic>.from(event.snapshot.value as Map);
            }
            debugPrint('[getAggregatedDataStreamForAllHubs] Hub $serialNumber ($nickname): ${aggregationData.length} $aggregationType records');

            // Include hub metadata (nickname) WITH aggregation data in the stream
            // This eliminates the need for separate database calls or caching
            return MapEntry(serialNumber, {
              '_hubNickname': nickname, // Hub metadata
              ...aggregationData,       // Spread aggregation data (hourly/daily/weekly/monthly records)
            });
          })
        );
      }

      if (hubStreams.isEmpty) {
        return Stream.value({});
      }

      // Combine the latest data from all individual hub streams
      return Rx.combineLatestList(hubStreams).map((listOfEntries) {
        // Convert the list of MapEntry back into the desired Map structure
        final combinedData = Map.fromEntries(listOfEntries);
        debugPrint('[getAggregatedDataStreamForAllHubs] Streaming ${combinedData.length} hubs with $aggregationType data');
        return combinedData;
      });
    });
  }

  /// Returns an efficient, listening stream of the last 24 hours of HOURLY data.
  /// This is specifically for the Energy Overview screen's 24h chart.
  /// The stream re-emits every minute to update the 24-hour rolling window.
  Stream<List<TimestampedFlSpot>> getOverviewHourlyStream(
      String hubSerialNumber) {
    // This is more efficient than polling. It listens for any changes on the 'hourly' node.
    final hourlyRef =
        _dbRef.child('$rtdbUserPath/hubs/$hubSerialNumber/aggregations/hourly');

    // Combine Firebase updates with periodic timer to keep the 24h window current
    final periodicStream = Stream.periodic(const Duration(minutes: 1), (count) => count).startWith(0);

    return Rx.combineLatest2<DatabaseEvent, int, List<TimestampedFlSpot>>(
      hourlyRef.onValue,
      periodicStream,
      (event, _) {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          debugPrint(
              '[getOverviewHourlyStream] No hourly data found for hub: $hubSerialNumber');
          return <TimestampedFlSpot>[];
        }

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final List<TimestampedFlSpot> spots = [];
        // Define the 24-hour window based on the current time.
        final windowEnd = DateTime.now();
        final windowStart = windowEnd.subtract(const Duration(hours: 24));

        // First pass: collect all hourly data points
        final List<TimestampedFlSpot> rawSpots = [];
        data.forEach((key, value) {
          try {
            if (value is Map) {
              // Key format: "2025-11-22-02" (YYYY-MM-DD-HH)
              final parts = (key as String).split('-');
              if (parts.length == 4) {
                final timestamp = DateTime(
                  int.parse(parts[0]), // year
                  int.parse(parts[1]), // month
                  int.parse(parts[2]), // day
                  int.parse(parts[3]), // hour
                );

                // Filter for the last 24 hours on the client side.
                if (!timestamp.isBefore(windowStart) &&
                    !timestamp.isAfter(windowEnd)) {
                  final averagePower =
                      (value['average_power'] as num? ?? 0.0).toDouble();
                  final averageVoltage =
                      (value['average_voltage'] as num? ?? 0.0).toDouble();
                  final averageCurrent =
                      (value['average_current'] as num? ?? 0.0).toDouble();
                  final totalEnergy =
                      (value['total_energy'] as num? ?? 0.0).toDouble();

                  rawSpots.add(TimestampedFlSpot(
                    timestamp: timestamp,
                    power: averagePower,
                    voltage: averageVoltage,
                    current: averageCurrent,
                    energy: totalEnergy,
                  ));
                }
              }
            }
          } catch (e) {
            debugPrint(
                '[getOverviewHourlyStream] Error parsing hourly data key $key: $e');
          }
        });

        // Sort by timestamp ascending for proper calculation
        rawSpots.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Second pass: calculate hourly consumption as difference between consecutive readings
        for (int i = 1; i < rawSpots.length; i++) {
          final previous = rawSpots[i - 1];
          final current = rawSpots[i];

          // Calculate hourly consumption: current reading minus previous reading
          final hourlyConsumption = (current.energy - previous.energy).abs();

          spots.add(TimestampedFlSpot(
            timestamp: current.timestamp,
            power: current.power,
            voltage: current.voltage,
            current: current.current,
            energy: hourlyConsumption, // Use the calculated hourly consumption
          ));
        }

        spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        debugPrint(
            '[getOverviewHourlyStream] Loaded ${spots.length} hourly data points for hub $hubSerialNumber (window: $windowStart to $windowEnd)');
        return spots;
      },
    );
  }

  /// Returns a combined efficient, listening stream of the last 24 hours of HOURLY data for ALL active hubs.
  /// This is specifically for the Energy Overview screen's 24h chart.
  Stream<List<TimestampedFlSpot>> getOverviewHourlyStreamForAllHubs() {
    return _activeHubController.switchMap((hubSerialNumbers) {
      if (hubSerialNumbers.isEmpty) {
        return Stream.value(<TimestampedFlSpot>[]);
      }

      final List<Stream<List<TimestampedFlSpot>>> hubStreams =
          hubSerialNumbers.map((serial) {
        // Reuse the efficient single-hub stream for each active hub
        return getOverviewHourlyStream(serial);
      }).toList();

      // Combine the latest data from all individual hub streams
      return Rx.combineLatestList(hubStreams).map((listOfHubData) {
        // listOfHubData is a List<List<TimestampedFlSpot>>
        // We flatten it into a single list, then sort it by time.
        final List<TimestampedFlSpot> allSpots =
            listOfHubData.expand((spots) => spots).toList();
        allSpots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        debugPrint(
            '[getOverviewHourlyStreamForAllHubs] Combined data from ${hubSerialNumbers.length} hubs, total points: ${allSpots.length}');
        return allSpots;
      });
    });
  }

  /// Get historical aggregated data stream (WITHOUT live per-second data)
  /// Uses appropriate aggregation level: H (hourly), D (daily), W (weekly), M (monthly)
  /// This is for the historical chart only - the 60-second live chart uses getLiveChartDataStream()
  /// The stream re-emits periodically to update the rolling time window.
  Stream<List<TimestampedFlSpot>> getCombinedHistoricalAndLiveDataStream(
    String hubSerialNumber,
    DateTime startTime,
  ) {
    // Determine which aggregation level to use based on initial time range
    final initialNow = DateTime.now();
    final duration = initialNow.difference(startTime);

    // For hourly data (24h), use the efficient streaming method
    if (duration.inHours <= 24) {
      debugPrint(
          '[getCombinedHistoricalAndLiveDataStream] Using HOURLY streaming for ${duration.inHours} hours');
      return getOverviewHourlyStream(hubSerialNumber);
    }

    // For other time ranges, create a stream that re-emits periodically
    final updateInterval = duration.inDays <= 7
        ? const Duration(minutes: 5) // Daily: update every 5 minutes
        : const Duration(minutes: 15); // Weekly/Monthly: update every 15 minutes

    // Combine periodic timer with manual refresh capability
    final periodicStream = Stream.periodic(updateInterval, (count) => count).startWith(0);

    return periodicStream.asyncMap((_) async {
      final now = DateTime.now();
      final currentDuration = now.difference(startTime);

      List<TimestampedFlSpot> historicalData = [];

      if (currentDuration.inDays <= 7) {
        // D: For last 7 days, use daily aggregation
        debugPrint(
            '[getCombinedHistoricalAndLiveDataStream] Using DAILY aggregation for ${currentDuration.inDays} days');
        historicalData =
            await getDailyAggregationData(hubSerialNumber, startTime, now);
      } else if (currentDuration.inDays <= 28) {
        // W: For last 28 days (4 weeks), use weekly aggregation
        debugPrint(
            '[getCombinedHistoricalAndLiveDataStream] Using WEEKLY aggregation for ${currentDuration.inDays} days');
        historicalData =
            await getWeeklyAggregationData(hubSerialNumber, startTime, now);
      } else {
        // M: For longer periods (28-180 days / 6 months), use monthly aggregation
        debugPrint(
            '[getCombinedHistoricalAndLiveDataStream] Using MONTHLY aggregation for ${currentDuration.inDays} days');
        historicalData =
            await getMonthlyAggregationData(hubSerialNumber, startTime, now);
      }

      return historicalData;
    });
  }

  /// Get historical aggregated data for all active hubs (WITHOUT live per-second data)
  /// Uses appropriate aggregation level: H (hourly), D (daily), W (weekly), M (monthly)
  /// The stream re-emits periodically to update the rolling time window.
  Stream<List<TimestampedFlSpot>> getCombinedHistoricalAndLiveDataForAllHubs(
    DateTime startTime,
  ) {
    // Determine which aggregation level to use based on initial time range
    final initialNow = DateTime.now();
    final duration = initialNow.difference(startTime);

    // For hourly data (24h), use the efficient streaming method
    if (duration.inHours <= 24) {
      debugPrint(
          '[getCombinedHistoricalAndLiveDataForAllHubs] Using HOURLY streaming for ${duration.inHours} hours');
      return getOverviewHourlyStreamForAllHubs();
    }

    // For other time ranges, create a stream that re-emits periodically
    final updateInterval = duration.inDays <= 7
        ? const Duration(minutes: 5) // Daily: update every 5 minutes
        : const Duration(minutes: 15); // Weekly/Monthly: update every 15 minutes

    // Combine periodic timer with hub changes
    final periodicStream = Stream.periodic(updateInterval, (count) => count).startWith(0);

    return Rx.combineLatest2<List<String>, int, _TriggerData>(
      _activeHubController.stream,
      periodicStream,
      (hubSerialNumbers, _) => _TriggerData(hubSerialNumbers),
    ).asyncMap((trigger) async {
      if (trigger.hubSerialNumbers.isEmpty) {
        return <TimestampedFlSpot>[];
      }

      final now = DateTime.now();
      final currentDuration = now.difference(startTime);

      // Collect historical data from all hubs
      final List<TimestampedFlSpot> allHistoricalData = [];

      for (final hubSerial in trigger.hubSerialNumbers) {
        List<TimestampedFlSpot> hubHistoricalData = [];

        if (currentDuration.inDays <= 7) {
          // D: For last 7 days, use daily aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using DAILY aggregation');
          hubHistoricalData = await getDailyAggregationData(hubSerial, startTime, now);
        } else if (currentDuration.inDays <= 28) {
          // W: For last 28 days (4 weeks), use weekly aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using WEEKLY aggregation');
          hubHistoricalData = await getWeeklyAggregationData(hubSerial, startTime, now);
        } else {
          // M: For longer periods (28-180 days / 6 months), use monthly aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using MONTHLY aggregation');
          hubHistoricalData = await getMonthlyAggregationData(hubSerial, startTime, now);
        }

        allHistoricalData.addAll(hubHistoricalData);
      }

      // Sort aggregated data by timestamp
      allHistoricalData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return allHistoricalData;
    });
  }
}