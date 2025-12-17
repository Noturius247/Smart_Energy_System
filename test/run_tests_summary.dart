import 'dart:io';

/// Simple test runner that provides a summary
///
/// Usage:
/// ```bash
/// dart test/run_tests_summary.dart
/// ```
void main() async {
  print('========================================');
  print('Smart Energy System - Test Suite');
  print('========================================\n');

  print('Running all unit tests...\n');

  // Run flutter test and capture output
  final result = await Process.run(
    'flutter',
    ['test', '--reporter', 'expanded'],
  );

  print('\n========================================');
  print('Test Results Summary');
  print('========================================\n');

  if (result.exitCode == 0) {
    print('✓ All tests PASSED!');
  } else {
    print('✗ Some tests FAILED!');
    print('Exit code: ${result.exitCode}');
  }

  exit(result.exitCode);
}
