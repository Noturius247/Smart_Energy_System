import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'models/usage_history_entry_test.dart' as usage_history_entry_tests;
import 'models/history_record_test.dart' as history_record_tests;

/// Main test runner that executes all unit tests
///
/// Run this file using:
/// ```bash
/// flutter test test/run_all_tests.dart
/// ```
///
/// Or run all tests in the test directory:
/// ```bash
/// flutter test
/// ```
///
/// For verbose output with detailed results:
/// ```bash
/// flutter test --reporter expanded
/// ```
///
/// For coverage report:
/// ```bash
/// flutter test --coverage
/// ```
void main() {
  group('Smart Energy System - All Unit Tests', () {
    group('Model Tests', () {
      usage_history_entry_tests.main();
      history_record_tests.main();
    });
  });
}
