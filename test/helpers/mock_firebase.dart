import 'package:mocktail/mocktail.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase Database Mocks
class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}
class MockDatabaseReference extends Mock implements DatabaseReference {}
class MockDataSnapshot extends Mock implements DataSnapshot {}
class MockDatabaseEvent extends Mock implements DatabaseEvent {}

// Firestore Mocks (using fake_cloud_firestore instead for better testing)
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// Firebase Auth Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

// Note: We don't need to mock StreamSubscription as we can use real streams in tests

// Helper function to create a mock DataSnapshot with data
MockDataSnapshot createMockSnapshot(dynamic value, {String? key}) {
  final snapshot = MockDataSnapshot();
  when(() => snapshot.value).thenReturn(value);
  when(() => snapshot.key).thenReturn(key);
  when(() => snapshot.exists).thenReturn(value != null);
  return snapshot;
}

// Helper function to create a mock DatabaseEvent
MockDatabaseEvent createMockEvent(dynamic value, {String? key, String? previousChildKey}) {
  final event = MockDatabaseEvent();
  final snapshot = createMockSnapshot(value, key: key);
  when(() => event.snapshot).thenReturn(snapshot);
  when(() => event.previousChildKey).thenReturn(previousChildKey);
  when(() => event.type).thenReturn(DatabaseEventType.value);
  return event;
}
