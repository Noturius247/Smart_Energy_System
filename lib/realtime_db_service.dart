import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RealtimeDbService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  // Store a list of subscriptions for the current hub to manage them efficiently
  List<StreamSubscription> _hubSubscriptions = [];
  String? _hubSerialNumber;

  // StreamController to broadcast structured hub data events to the UI
  final _hubDataController = StreamController<Map<String, dynamic>>.broadcast();

  // Public stream for the UI to listen to
  Stream<Map<String, dynamic>> get hubDataStream => _hubDataController.stream;

  void startRealtimeDataStream(String hubSerialNumber) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('User not authenticated, cannot start stream.');
      stopRealtimeDataStream(); // Stop any previous streams
      return;
    }
    final String uid = user.uid;

    if (_hubSerialNumber == hubSerialNumber && _hubSubscriptions.isNotEmpty) {
      debugPrint('Streams already running for hub: $hubSerialNumber');
      return;
    }

    stopRealtimeDataStream();
    _hubSerialNumber = hubSerialNumber;

    final hubBasePath = 'users/$uid/hubs/$hubSerialNumber';

    // 1. Listen to hub's main ssr_state changes (infrequent)
    final hubStateRef = _dbRef.child('$hubBasePath/ssr_state');
    final hubStateSub = hubStateRef.onValue.listen((event) {
      if (!_hubDataController.isClosed) {
        _hubDataController.add({
          'type': 'hub_state',
          'serialNumber': hubSerialNumber,
          'ssr_state': event.snapshot.value,
        });
      }
    }, onError: _handleError);
    _hubSubscriptions.add(hubStateSub);

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
    _hubSubscriptions.add(plugsChangedSub);

    // 3. Listen for newly added plugs
    final plugsAddedSub = plugsRef.onChildAdded.listen((event) {
      if (!_hubDataController.isClosed) {
        // Deferring full implementation to avoid duplicates with initial load.
        // A full implementation might require checking if the plug already exists in the UI.
      }
    }, onError: _handleError);
    _hubSubscriptions.add(plugsAddedSub);

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
    _hubSubscriptions.add(plugsRemovedSub);

    debugPrint('Efficient real-time streams started for hub: $hubSerialNumber');
  }

  void stopRealtimeDataStream() {
    for (var sub in _hubSubscriptions) {
      sub.cancel();
    }
    _hubSubscriptions = [];
    _hubSerialNumber = null;
    debugPrint('All real-time data streams stopped.');
  }

  void _handleError(Object error) {
    debugPrint('RealtimeDbService stream error: $error');
    if (!_hubDataController.isClosed) {
      _hubDataController.addError(error);
    }
  }

  void dispose() {
    stopRealtimeDataStream();
    _hubDataController.close();
  }
}
