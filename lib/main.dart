import 'package:flutter/material.dart';

import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screen/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'realtime_db_service.dart'; // Import the new service
import 'services/data_cleanup_service.dart'; // Import cleanup service

import 'screen/admin_home.dart';
import 'screen/theadmin.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  final themeNotifier = await ThemeNotifier.create();

  runApp(
    ChangeNotifierProvider.value(value: themeNotifier, child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, theme, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Energy System',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: theme.darkTheme ? ThemeMode.dark : ThemeMode.light,
        home: ChangeNotifierProvider.value(
          value: theme, // Use the existing ThemeNotifier
          child: const AuthWrapper(), // Wrap AuthWrapper with ThemeNotifier
        ),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final RealtimeDbService _realtimeDbService = RealtimeDbService();
  final DataCleanupService _cleanupService = DataCleanupService();

  @override
  void initState() {
    super.initState();
    // Start cleanup service when user is authenticated
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _cleanupService.startCleanupService();
      } else {
        _cleanupService.stopCleanupService();
      }
    });
  }

  @override
  void dispose() {
    _realtimeDbService.stopAllRealtimeDataStreams();
    _cleanupService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          // User is logged in
          final user = snapshot.data!;
          return FutureBuilder<IdTokenResult>(
            future: user.getIdTokenResult(
              true,
            ), // Force refresh to get latest claims
            builder: (context, tokenSnapshot) {
              if (tokenSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }

              if (tokenSnapshot.hasData) {
                final bool isAdmin =
                    tokenSnapshot.data?.claims?['admin'] == true;
                if (isAdmin) {
                  return MyAdminScreen(realtimeDbService: _realtimeDbService);
                } else {
                  return HomeScreen(
                    realtimeDbService: _realtimeDbService,
                  ); // Redirect to user home screen
                }
              }
              // Fallback if token claims can't be fetched
              return AuthPage(realtimeDbService: _realtimeDbService);
            },
          );
        } else {
          // User is logged out
        }

        return AuthPage(realtimeDbService: _realtimeDbService);
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a2332), Color(0xFF0f1419)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/Animation - 1750510706715.json',
                width: 350,
                height: 350,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 6,
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading Smart Energy System...',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
