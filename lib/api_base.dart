import 'package:flutter/foundation.dart';

/// Centralized API base URL.
///
/// - Web and desktop: http://localhost:3000
/// - Android emulator: http://10.0.2.2:3000 (so emulator can reach host)
///
/// Use `apiBaseUrl` anywhere you need to call your local backend.
String get apiBaseUrl {
  // Web should use localhost:3000 so your OAuth redirect and local dev server match
  if (kIsWeb) return 'http://localhost:3000';

  // For Android emulator, the host machine is reachable at 10.0.2.2
  // For other platforms (iOS simulator, desktop), localhost usually works.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }

  return 'http://localhost:3000';
}

/// Convenience constant for tests or simple string interpolation.
final String apiBase = apiBaseUrl;
