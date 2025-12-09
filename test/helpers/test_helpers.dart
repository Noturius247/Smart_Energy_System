import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'dart:async';

/// Test helper utilities and common functions
class TestHelpers {
  /// Creates a fake Firestore instance with optional initial data
  static FakeFirebaseFirestore createFakeFirestore({
    Map<String, Map<String, dynamic>>? initialData,
  }) {
    final firestore = FakeFirebaseFirestore();

    if (initialData != null) {
      initialData.forEach((path, data) {
        final parts = path.split('/');
        if (parts.length == 2) {
          firestore.collection(parts[0]).doc(parts[1]).set(data);
        }
      });
    }

    return firestore;
  }

  /// Creates a mock authenticated user
  static MockUser createMockUser({
    String uid = 'test-user-123',
    String email = 'test@example.com',
    String displayName = 'Test User',
  }) {
    return MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
      isAnonymous: false,
    );
  }

  /// Creates a mock Firebase Auth instance with an authenticated user
  static MockFirebaseAuth createMockAuth({
    MockUser? user,
    bool signedIn = true,
  }) {
    final mockUser = user ?? createMockUser();
    return MockFirebaseAuth(
      signedIn: signedIn,
      mockUser: mockUser,
    );
  }

  /// Waits for a stream to emit a specific number of events
  static Future<List<T>> collectStreamEvents<T>(
    Stream<T> stream, {
    int count = 1,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final events = <T>[];
    final completer = Completer<List<T>>();

    final subscription = stream.listen((event) {
      events.add(event);
      if (events.length >= count) {
        completer.complete(events);
      }
    });

    try {
      return await completer.future.timeout(timeout);
    } finally {
      await subscription.cancel();
    }
  }

  /// Waits for a stream to emit at least one event
  static Future<T> waitForStreamEvent<T>(
    Stream<T> stream, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final events = await collectStreamEvents<T>(stream, count: 1, timeout: timeout);
    return events.first;
  }

  /// Waits for a condition to become true
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition()) {
      if (stopwatch.elapsed > timeout) {
        throw TimeoutException('Condition not met within timeout', timeout);
      }
      await Future.delayed(checkInterval);
    }
  }

  /// Pumps the widget tree and waits for all animations to complete
  static Future<void> pumpAndSettle(
    WidgetTester tester, {
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    await tester.pump(duration);
    await tester.pumpAndSettle();
  }

  /// Creates a test widget wrapper with Material app
  static Widget createTestWidget(
    Widget child, {
    NavigatorObserver? navigatorObserver,
    ThemeData? theme,
  }) {
    return MaterialApp(
      home: Scaffold(body: child),
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
      theme: theme ?? ThemeData.light(),
    );
  }

  /// Expects a future to throw a specific exception type
  static Future<void> expectThrows<T extends Object>(
    Future<dynamic> Function() function,
  ) async {
    try {
      await function();
      fail('Expected exception of type $T but none was thrown');
    } catch (e) {
      expect(e, isA<T>());
    }
  }

  /// Formats a timestamp for comparison in tests
  static String formatTimestamp(DateTime timestamp) {
    return timestamp.toIso8601String();
  }

  /// Compares two doubles with a tolerance
  static bool doubleEquals(double a, double b, {double tolerance = 0.0001}) {
    return (a - b).abs() < tolerance;
  }

  /// Creates a delayed future for testing async operations
  static Future<T> delayed<T>(T value, {Duration duration = const Duration(milliseconds: 100)}) {
    return Future.delayed(duration, () => value);
  }

  /// Creates a stream controller with cleanup tracking
  static StreamController<T> createTrackedStreamController<T>({
    bool broadcast = false,
  }) {
    if (broadcast) {
      return StreamController<T>.broadcast();
    }
    return StreamController<T>();
  }

  /// Converts a list of maps to a stream for testing
  static Stream<T> listToStream<T>(List<T> items, {Duration delay = const Duration(milliseconds: 10)}) async* {
    for (final item in items) {
      await Future.delayed(delay);
      yield item;
    }
  }

  /// Creates a test DateTime with specific components
  static DateTime createDate(int year, [int month = 1, int day = 1, int hour = 0]) {
    return DateTime(year, month, day, hour);
  }

  /// Generates a range of DateTimes for testing
  static List<DateTime> generateDateRange(DateTime start, int count, Duration interval) {
    final dates = <DateTime>[];
    DateTime current = start;

    for (int i = 0; i < count; i++) {
      dates.add(current);
      current = current.add(interval);
    }

    return dates;
  }

  /// Mocks a database snapshot response
  static Map<String, dynamic> createDbSnapshot({
    required String key,
    required dynamic value,
  }) {
    return {
      'key': key,
      'value': value,
      'exists': value != null,
    };
  }

  /// Verifies that a provider notifies listeners
  static Future<void> verifyProviderNotifies(
    ChangeNotifier provider,
    Future<void> Function() action,
  ) async {
    bool notified = false;

    void listener() {
      notified = true;
    }

    provider.addListener(listener);

    try {
      await action();
      // Give the notification time to propagate
      await Future.delayed(const Duration(milliseconds: 10));
      expect(notified, isTrue, reason: 'Provider should have notified listeners');
    } finally {
      provider.removeListener(listener);
    }
  }

  /// Counts the number of times a provider notifies listeners
  static Future<int> countProviderNotifications(
    ChangeNotifier provider,
    Future<void> Function() action,
  ) async {
    int count = 0;

    void listener() {
      count++;
    }

    provider.addListener(listener);

    try {
      await action();
      // Give the notifications time to propagate
      await Future.delayed(const Duration(milliseconds: 10));
      return count;
    } finally {
      provider.removeListener(listener);
    }
  }

  /// Captures debug print statements for testing
  static Future<List<String>> captureDebugPrints(
    Future<void> Function() action,
  ) async {
    final prints = <String>[];

    await runZoned(
      action,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) {
          prints.add(message);
        },
      ),
    );

    return prints;
  }

  /// Creates a fake timestamp for testing
  static DateTime fakePastDate({int daysAgo = 1}) {
    return DateTime.now().subtract(Duration(days: daysAgo));
  }

  static DateTime fakeFutureDate({int daysAhead = 1}) {
    return DateTime.now().add(Duration(days: daysAhead));
  }

  /// Verifies a list is sorted in ascending order
  static bool isSortedAscending<T extends Comparable>(List<T> list) {
    for (int i = 0; i < list.length - 1; i++) {
      if (list[i].compareTo(list[i + 1]) > 0) {
        return false;
      }
    }
    return true;
  }

  /// Verifies a list is sorted in descending order
  static bool isSortedDescending<T extends Comparable>(List<T> list) {
    for (int i = 0; i < list.length - 1; i++) {
      if (list[i].compareTo(list[i + 1]) < 0) {
        return false;
      }
    }
    return true;
  }
}

/// Custom matchers for testing

/// Matches a value within a range
class InRange extends Matcher {
  final num min;
  final num max;

  const InRange(this.min, this.max);

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is! num) return false;
    return item >= min && item <= max;
  }

  @override
  Description describe(Description description) {
    return description.add('a value between $min and $max');
  }
}

// Convenience functions for custom matchers
Matcher inRange(num min, num max) => InRange(min, max);
// Note: closeTo is already provided by flutter_test, so we don't define it here
