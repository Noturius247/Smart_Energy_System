import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DueDateProvider with ChangeNotifier {
  DateTime? _dueDate;
  bool _isLoading = false;

  DateTime? get dueDate => _dueDate;
  bool get isLoading => _isLoading;

  DueDateProvider() {
    _loadDueDate();
  }

  // Load due date from Firestore
  Future<void> _loadDueDate() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _dueDate = null;
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

      if (doc.exists && doc.data()!.containsKey('dueDate')) {
        final timestamp = doc.data()!['dueDate'] as Timestamp?;
        _dueDate = timestamp?.toDate();
      } else {
        _dueDate = null;
      }
    } catch (e) {
      debugPrint('Error loading due date: $e');
      _dueDate = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Set due date and save to Firestore
  Future<bool> setDueDate(DateTime? newDueDate) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    try {
      if (newDueDate != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'dueDate': Timestamp.fromDate(newDueDate)}, SetOptions(merge: true));
        _dueDate = newDueDate;
      } else {
        // Clear the due date
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'dueDate': FieldValue.delete()});
        _dueDate = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting due date: $e');
      return false;
    }
  }

  // Clear due date
  Future<bool> clearDueDate() async {
    return await setDueDate(null);
  }

  // Get days remaining until due date
  int? getDaysRemaining() {
    if (_dueDate == null) return null;
    final now = DateTime.now();
    final difference = _dueDate!.difference(now);
    return difference.inDays;
  }

  // Check if due date is overdue
  bool get isOverdue {
    if (_dueDate == null) return false;
    return DateTime.now().isAfter(_dueDate!);
  }

  // Get formatted due date string
  String? getFormattedDueDate() {
    if (_dueDate == null) return null;
    return '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}';
  }
}
