# Smart Energy System - Testing Guide

This guide shows you how to run unit tests and see results in the terminal.

## Quick Start - Run Tests in Terminal

### Method 1: Using Flutter Test (Recommended)

**Run all tests:**
```bash
flutter test
```

**Run with detailed output:**
```bash
flutter test --reporter expanded
```

**Run specific test file:**
```bash
flutter test test/models/usage_history_entry_test.dart --reporter expanded
flutter test test/models/history_record_test.dart --reporter expanded
flutter test test/widget_test.dart --reporter expanded
```

### Method 2: Using Scripts (Windows)

**Double-click or run:**
```bash
run_tests.bat
```

This will:
- Check if Flutter is installed
- Run all tests with detailed output
- Show PASS/FAIL summary
- Pause so you can read results

### Method 3: Using PowerShell Script

```powershell
.\run_tests.ps1
```

### Method 4: Using Bash Script (Linux/Mac/WSL)

```bash
chmod +x run_tests.sh
./run_tests.sh
```

## Understanding Test Output

### Compact Output (Default)
```
00:01 +73: All tests passed!
```
- `00:01` = Time elapsed
- `+73` = Number of tests passed

### Expanded Output
```
00:00 +1: UsageHistoryEntry Constructor creates instance with all required fields
00:00 +2: UsageHistoryEntry Constructor creates hourly entry from test fixture
00:01 +70: All tests passed!
```

Each line shows:
- Timestamp
- Number of tests passed so far
- Test name and description

### Failed Test Output
```
00:01 +5 -1: PriceProvider should calculate cost correctly [E]
  Expected: 50.0
  Actual: 45.0
```
- `+5 -1` = 5 passed, 1 failed
- `[E]` = Error
- Shows expected vs actual values

## Available Test Suites

### 1. Usage History Entry Tests
```bash
flutter test test/models/usage_history_entry_test.dart --reporter expanded
```

**Tests:** (28 tests)
- Constructor validation
- Timestamp formatting
- Usage calculations
- Edge cases
- Realistic scenarios

### 2. History Record Tests
```bash
flutter test test/models/history_record_test.dart --reporter expanded
```

**Tests:** (42 tests)
- Record creation
- Timestamp parsing
- Data formatting
- Energy calculations
- Statistical values
- Realistic power scenarios
- Edge cases

### 3. Widget Tests
```bash
flutter test test/widget_test.dart --reporter expanded
```

**Tests:** (3 tests)
- Basic widget rendering
- MaterialApp creation
- Scaffold with text

## Test Summary

**Total: 73 Unit Tests**
- ✅ UsageHistoryEntry: 28 tests
- ✅ HistoryRecord: 42 tests
- ✅ Widget Tests: 3 tests

## Test Options

### Show Line-by-Line Progress
```bash
flutter test --reporter expanded
```

### Generate Coverage Report
```bash
flutter test --coverage
```
Coverage file generated at: `coverage/lcov.info`

### Run Tests in Watch Mode
```bash
flutter test --watch
```
Automatically re-runs tests when files change.

### Run Only Tests Matching Name
```bash
flutter test --name "price"
```
Only runs tests with "price" in the name.

### Run Tests with Timeout
```bash
flutter test --timeout 30s
```

### See All Available Options
```bash
flutter test --help
```

## Example Terminal Session

```
D:\latestupdate\Smart_Energy_System> flutter test --reporter expanded

00:00 +0: loading test files...
00:00 +1: UsageHistoryEntry Constructor creates instance with all required fields
00:00 +2: UsageHistoryEntry Constructor creates hourly entry from test fixture
00:00 +3: UsageHistoryEntry Constructor creates daily entry from test fixture
...
00:01 +70: All tests passed!
```

## Troubleshooting

### "Flutter not found"
**Solution:** Install Flutter from https://flutter.dev and add to PATH

### "No tests found"
**Solution:** Make sure you're in the project root directory:
```bash
cd D:\latestupdate\Smart_Energy_System
flutter test
```

### "Firebase initialization error"
**Solution:** Some tests may fail due to Firebase mocking. This is expected for provider tests without proper mocks. The model tests should all pass.

### "Tests timeout"
**Solution:** Increase timeout:
```bash
flutter test --timeout 60s
```

## Running Individual Test Groups

To run only model tests:
```bash
flutter test test/models/
```

To run only provider tests:
```bash
flutter test test/providers/
```

## Continuous Integration

For CI/CD pipelines, use:
```bash
flutter test --reporter json > test-results.json
```

This outputs results in JSON format for parsing by CI tools.

## Test File Structure

```
test/
├── run_all_tests.dart          # Aggregated test runner
├── run_tests_summary.dart      # Test runner with summary
├── README.md                   # Detailed testing documentation
├── models/                     # Model tests
│   ├── usage_history_entry_test.dart
│   └── history_record_test.dart
├── providers/                  # Provider tests
│   └── price_provider_test.dart
└── helpers/                    # Test utilities
    ├── mock_firebase.dart
    ├── test_fixtures.dart
    └── test_helpers.dart
```

## Best Practices

1. **Run tests before committing code**
   ```bash
   flutter test
   ```

2. **Use expanded output for debugging**
   ```bash
   flutter test --reporter expanded
   ```

3. **Check coverage periodically**
   ```bash
   flutter test --coverage
   ```

4. **Run specific tests during development**
   ```bash
   flutter test test/models/usage_history_entry_test.dart
   ```

5. **Use watch mode for TDD**
   ```bash
   flutter test --watch
   ```

## Next Steps

- Run `flutter test` to see all tests execute
- Check `test/README.md` for detailed testing documentation
- Add new tests as you develop new features
- Maintain test coverage above 80%

## Need Help?

- Flutter Testing Docs: https://docs.flutter.dev/testing
- Flutter Test API: https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html
- Project test helpers: See `test/helpers/` directory
