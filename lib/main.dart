import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screen/login.dart';
import 'package:firebase_auth/firebase_auth.dart';


import 'screen/theadmin.dart';
import 'screen/explore.dart'; // Import DevicesTab (user home screen)
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: kIsWeb
          ? const FirebaseOptions(
              apiKey: "AIzaSyDBqcfwbFnu8GKAz5MMIhqRwUgMLjN0K-U",
              authDomain: "smart-plug-and-energy-meter.firebaseapp.com",
              databaseURL: "https://smart-plug-and-energy-meter-default-rtdb.asia-southeast1.firebasedatabase.app",
              projectId: "smart-plug-and-energy-meter",
              storageBucket: "smart-plug-and-energy-meter.firebasestorage.app",
              messagingSenderId: "163950309353",
              appId: "1:163950309353:web:3b00a96478d7d0ce066578",
              measurementId: "G-5Q92FQ78LZ",
            )
          : null,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  final themeNotifier = await ThemeNotifier.create();
  
  runApp(
    ChangeNotifierProvider.value(
      value: themeNotifier,
      child: const MyApp(),
    ),
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
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<IdTokenResult>(
            future: user.getIdTokenResult(true), // Force refresh to get latest claims
            builder: (context, tokenSnapshot) {
              if (tokenSnapshot.connectionState == ConnectionState.waiting) {
                return const LoadingScreen();
              }

              if (tokenSnapshot.hasData) {
                final bool isAdmin = tokenSnapshot.data?.claims?['admin'] == true;
                if (isAdmin) {
                  return const MyAdminScreen();
                } else {
                  return const DevicesTab(); // Redirect to user home screen
                }
              }
              // Fallback if token claims can't be fetched
              return const AuthPage();
            },
          );
        }

        return const AuthPage();
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



