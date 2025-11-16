import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart'; // Explicitly import widgets.dart
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screen/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screen/admin_home.dart';
import 'screen/theadmin.dart';

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
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Energy System',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AuthWrapper(), // Use AuthWrapper as the home
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
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
        // Show a loading screen while waiting for the auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        // If the user is logged in, check if they are an admin
        if (snapshot.hasData) {
          final user = snapshot.data!; // user is guaranteed to be non-null here
          if (user.email == 'smartenergymeter11@gmail.com') {
            return const MyAdminScreen();
          } else {
            return const HomeScreen();
          }
        }

        // If the user is not logged in, show the login page
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



