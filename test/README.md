# Smart Energy System - Unit Testing Guide

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run All Tests with Detailed Output
```bash
flutter test --reporter expanded
```

### Run Specific Test File
```bash
# Run usage history entry tests
flutter test test/models/usage_history_entry_test.dart

# Run price provider tests
flutter test test/providers/price_provider_test.dart

# Run history record tests
flutter test test/models/history_record_test.dart
```

### Run All Tests Using the Test Runner
```bash
flutter test test/run_all_tests.dart --reporter expanded
```

### Generate Coverage Report
```bash
flutter test --coverage
```

To view coverage in HTML format (requires lcov):
```bash
# On Windows (install lcov via Chocolatey or use WSL)
genhtml coverage/lcov.info -o coverage/html
```

### Watch Mode (Re-run tests on file changes)
```bash
flutter test --watch
```

## Test File Organization

```
test/
├── run_all_tests.dart          # Main test runner (runs all tests)
├── widget_test.dart            # Widget/integration tests
├── models/
│   ├── usage_history_entry_test.dart
│   └── history_record_test.dart
├── providers/
│   └── price_provider_test.dart
└── helpers/
    ├── mock_firebase.dart      # Firebase mocking utilities
    ├── test_fixtures.dart      # Test data fixtures
    └── test_helpers.dart       # Helper functions
```

## Test Coverage

### Current Test Suites

1. **UsageHistoryEntry Tests** (`test/models/usage_history_entry_test.dart`)
   - Constructor validation
   - Timestamp formatting (hourly, daily, weekly, monthly)
   - Usage calculations
   - Edge cases (leap years, year boundaries, midnight timestamps)
   - Realistic usage scenarios

2. **HistoryRecord Tests** (`test/models/history_record_test.dart`)
   - Record creation and validation
   - Data consistency checks

3. **PriceProvider Tests** (`test/providers/price_provider_test.dart`)
   - User authentication scenarios
   - Price calculations
   - Currency formatting (Philippine Peso)
   - State management (ChangeNotifier)
   - Price history tracking
   - Edge cases and validation
   - Concurrent operations

## Writing New Tests

### Example Test Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:smartenergy_app/your_module.dart';

void main() {
  group('YourModule', () {
    group('Feature Name', () {
      test('should do something specific', () {
        // Arrange
        final instance = YourClass();

        // Act
        final result = instance.doSomething();

        // Assert
        expect(result, expectedValue);
      });
    });
  });
}
```

### Best Practices

1. **Use descriptive test names** - Test names should clearly describe what is being tested
2. **Follow AAA pattern** - Arrange, Act, Assert
3. **Test edge cases** - Include tests for boundary conditions, null values, empty data
4. **Use test fixtures** - Reuse common test data from `test/helpers/test_fixtures.dart`
5. **Mock external dependencies** - Use mocktail for mocking Firebase and other services
6. **Keep tests isolated** - Each test should be independent and not rely on other tests

## Continuous Integration

Tests should be run automatically in CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: flutter test --reporter expanded

- name: Generate coverage
  run: flutter test --coverage
```

## Troubleshooting

### Tests Fail to Run
- Ensure all dependencies are installed: `flutter pub get`
- Verify Flutter SDK is up to date: `flutter doctor`

### Firebase Initialization Errors
- Tests use mock Firebase instances from `test/helpers/mock_firebase.dart`
- Ensure `TestWidgetsFlutterBinding.ensureInitialized()` is called

### Coverage Not Generated
- Ensure you run: `flutter test --coverage`
- Coverage files are generated in `coverage/lcov.info`

## Test Output Examples

### Compact Output (Default)
```
00:02 +25: All tests passed!
```

### Expanded Output
```
00:01 +1: UsageHistoryEntry Constructor creates instance with all required fields
00:01 +2: UsageHistoryEntry Constructor creates hourly entry from test fixture
00:02 +25: All tests passed!
```

## Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mocktail Package](https://pub.dev/packages/mocktail)
- [Flutter Test API Reference](https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html)
