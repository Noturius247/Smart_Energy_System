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

class RealtimeDbService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  // Store a map of subscriptions, keyed by hub serial number
  final Map<String, List<StreamSubscription>> _hubSubscriptions = {};
  final _activeHubController = BehaviorSubject<List<String>>.seeded([]);

  // Public stream for the UI to listen to
  Stream<List<String>> get activeHubStream => _activeHubController.stream;

  // StreamController to broadcast structured hub data events to the UI
  final _hubDataController = StreamController<Map<String, dynamic>>.broadcast();

  // Public stream for the UI to listen to
  Stream<Map<String, dynamic>> get hubDataStream => _hubDataController.stream;

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
        debugPrint('[RealtimeDbService] Hub $hubSerialNumber ssr_state changed to: $ssrState');
        if (ssrState != null) {
          _hubDataController.add({
            'type': 'hub_state',
            'serialNumber': hubSerialNumber,
            'ssr_state': ssrState,
            'ownerId': uid, // Include current user's UID
          });
        }
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
          debugPrint('[getMonthlyAggregationData] Error parsing monthly data key $key: $e');
        }
      });

      spots.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint('[getMonthlyAggregationData] Loaded ${spots.length} monthly data points for hub $hubSerialNumber');
      return spots;
    } catch (e) {
      debugPrint('[getMonthlyAggregationData] Error fetching monthly data: $e');
      return [];
    }
  }

  /// Get combined historical data stream that merges past aggregated data with live per-second data
  /// This provides a seamless transition from historical to real-time data
  /// Uses appropriate aggregation level: H (hourly), D (daily), W (weekly), M (monthly)
  Stream<List<TimestampedFlSpot>> getCombinedHistoricalAndLiveDataStream(
    String hubSerialNumber,
    DateTime startTime,
  ) async* {
    final now = DateTime.now();

    // Determine which aggregation level to use based on time range
    // H: hourly (last 24 hours), D: daily (last 7 days), W: weekly (last 30 days), M: monthly (last 365 days)
    final duration = now.difference(startTime);
    List<TimestampedFlSpot> historicalData = [];

    if (duration.inHours <= 24) {
      // H: For last 24 hours, use hourly aggregation
      debugPrint('[getCombinedHistoricalAndLiveDataStream] Using HOURLY aggregation for ${duration.inHours} hours');
      historicalData = await getHourlyAggregationData(hubSerialNumber, startTime, now);
    } else if (duration.inDays <= 7) {
      // D: For last 7 days, use daily aggregation
      debugPrint('[getCombinedHistoricalAndLiveDataStream] Using DAILY aggregation for ${duration.inDays} days');
      historicalData = await getDailyAggregationData(hubSerialNumber, startTime, now);
    } else if (duration.inDays <= 30) {
      // W: For last 30 days, use weekly aggregation
      debugPrint('[getCombinedHistoricalAndLiveDataStream] Using WEEKLY aggregation for ${duration.inDays} days');
      historicalData = await getWeeklyAggregationData(hubSerialNumber, startTime, now);
    } else {
      // M: For longer periods (up to 365 days), use monthly aggregation
      debugPrint('[getCombinedHistoricalAndLiveDataStream] Using MONTHLY aggregation for ${duration.inDays} days');
      historicalData = await getMonthlyAggregationData(hubSerialNumber, startTime, now);
    }

    // Get live data stream for the last 65 seconds
    await for (final liveData in getLiveChartDataStreamForHub(hubSerialNumber)) {
      // Combine historical and live data
      final combinedData = [...historicalData, ...liveData];
      combinedData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      yield combinedData;
    }
  }

  /// Get combined data for all active hubs
  /// Uses appropriate aggregation level: H (hourly), D (daily), W (weekly), M (monthly)
  Stream<List<TimestampedFlSpot>> getCombinedHistoricalAndLiveDataForAllHubs(
    DateTime startTime,
  ) async* {
    await for (final hubSerialNumbers in _activeHubController.stream) {
      if (hubSerialNumbers.isEmpty) {
        yield <TimestampedFlSpot>[];
        continue;
      }

      final now = DateTime.now();
      final duration = now.difference(startTime);

      // Collect historical data from all hubs
      final List<TimestampedFlSpot> allHistoricalData = [];

      for (final hubSerial in hubSerialNumbers) {
        List<TimestampedFlSpot> hubHistoricalData = [];

        if (duration.inHours <= 24) {
          // H: For last 24 hours, use hourly aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using HOURLY aggregation');
          hubHistoricalData = await getHourlyAggregationData(hubSerial, startTime, now);
        } else if (duration.inDays <= 7) {
          // D: For last 7 days, use daily aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using DAILY aggregation');
          hubHistoricalData = await getDailyAggregationData(hubSerial, startTime, now);
        } else if (duration.inDays <= 30) {
          // W: For last 30 days, use weekly aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using WEEKLY aggregation');
          hubHistoricalData = await getWeeklyAggregationData(hubSerial, startTime, now);
        } else {
          // M: For longer periods (up to 365 days), use monthly aggregation
          debugPrint('[getCombinedHistoricalAndLiveDataForAllHubs] Hub $hubSerial: Using MONTHLY aggregation');
          hubHistoricalData = await getMonthlyAggregationData(hubSerial, startTime, now);
        }

        allHistoricalData.addAll(hubHistoricalData);
      }

      // Get live data for all hubs
      await for (final liveData in getLiveChartDataStream()) {
        final combinedData = [...allHistoricalData, ...liveData];
        combinedData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        yield combinedData;
        break; // Only emit once per active hub change
      }
    }
  }
}