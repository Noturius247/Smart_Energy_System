import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Setup Firebase mocks for testing
///
/// This helper mocks Firebase methods to prevent actual Firebase calls during tests
void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock Firebase Core channel
  const MethodChannel('plugins.flutter.io/firebase_core')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'Firebase#initializeCore') {
      return [
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': 'test-key',
            'appId': 'test-app-id',
            'messagingSenderId': 'test-sender-id',
            'projectId': 'test-project-id',
          },
          'pluginConstants': <String, dynamic>{},
        }
      ];
    }
    if (methodCall.method == 'Firebase#initializeApp') {
      return <String, dynamic>{
        'name': '[DEFAULT]',
        'options': methodCall.arguments['options'],
        'pluginConstants': <String, dynamic>{},
      };
    }
    return null;
  });

  // Mock Firebase Auth channel
  const MethodChannel('plugins.flutter.io/firebase_auth')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    if (methodCall.method == 'Auth#registerIdTokenListener') {
      return <String, dynamic>{'user': null};
    }
    if (methodCall.method == 'Auth#registerAuthStateListener') {
      return null;
    }
    return null;
  });

  // Mock Firestore channel
  const MethodChannel('plugins.flutter.io/cloud_firestore')
      .setMockMethodCallHandler((MethodCall methodCall) async {
    return null;
  });
}
