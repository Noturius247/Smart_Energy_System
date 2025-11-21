import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart'; // Import FlSpot
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
}