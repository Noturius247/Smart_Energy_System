import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PriceProvider with ChangeNotifier {
  double _pricePerKWH = 0.0;
  bool _isLoading = false;

  double get pricePerKWH => _pricePerKWH;
  bool get isLoading => _isLoading;

  PriceProvider() {
    _loadPrice();
  }

  // Load price from Firestore
  Future<void> _loadPrice() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[PriceProvider] No user logged in, price remains: ₱${_pricePerKWH.toStringAsFixed(2)}/kWh');
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data()!.containsKey('pricePerKWH')) {
        final loadedPrice = (doc.data()!['pricePerKWH'] as num).toDouble();
        _pricePerKWH = loadedPrice;
        debugPrint('[PriceProvider] Loaded price from Firestore: ₱${_pricePerKWH.toStringAsFixed(2)}/kWh');
      } else {
        debugPrint('[PriceProvider] Price not found in Firestore, current price: ₱${_pricePerKWH.toStringAsFixed(2)}/kWh');
      }
    } catch (e) {
      debugPrint('[PriceProvider] Error loading price: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Set price and save to Firestore (with history tracking)
  Future<bool> setPrice(double newPrice, {String? note}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    // Don't save if price hasn't changed
    if (_pricePerKWH == newPrice) {
      return true;
    }

    try {
      final timestamp = DateTime.now();

      // Save current price to user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'pricePerKWH': newPrice}, SetOptions(merge: true));

      // Save to price history subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('priceHistory')
          .add({
        'price': newPrice,
        'previousPrice': _pricePerKWH,
        'timestamp': timestamp,
        'note': note ?? '',
      });

      _pricePerKWH = newPrice;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting price: $e');
      return false;
    }
  }

  // Get price history from Firestore
  Future<List<Map<String, dynamic>>> getPriceHistory({int limit = 10}) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('priceHistory')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'price': (data['price'] as num).toDouble(),
          'previousPrice': (data['previousPrice'] as num?)?.toDouble() ?? 0.0,
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
          'note': data['note'] as String? ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error loading price history: $e');
      return [];
    }
  }

  // Get formatted price string
  String getFormattedPrice() {
    return '₱${_pricePerKWH.toStringAsFixed(2)}';
  }

  // Calculate cost for given energy consumption
  double calculateCost(double kWh) {
    return _pricePerKWH * kWh;
  }

  // Get formatted cost string
  String getFormattedCost(double kWh) {
    return '₱${calculateCost(kWh).toStringAsFixed(2)}';
  }
}
