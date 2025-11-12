import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home.dart';
import 'theadmin.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool showForm = false; // <-- new: controls form visibility
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  // OAuth 2.0 Web Client ID - Get from the redirect URI configuration
  // Steps to find it:
  // 1. Go to: https://console.cloud.google.com/apis/credentials?project=smart-plug-and-energy-meter
  // 2. Look for OAuth 2.0 Client IDs
  // 3. Find the one with redirect URI: http://localhost (or your domain)
  // 4. Copy that Client ID (not the App ID)
  // Example format: 123456789-abc...xyz.apps.googleusercontent.com
  static const String _webClientId =
      'Open: https://console.cloud.google.com/apis/credentials?project=smart-plug-and-energy-meter';
  late final GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? _webClientId : null,
      scopes: const ['email', 'profile'],
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final size = MediaQuery.of(context).size;
      final isMobile = size.width < 600;
      final isTablet = size.width >= 600 && size.width < 1000;

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 55, 143, 206)
                            .withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: isMobile
                          ? _buildVerticalLayout(context)
                          : _buildHorizontalLayout(context, isTablet),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error building AuthPage: $e');
      debugPrint('Stack trace: $stackTrace');
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
                const Icon(Icons.error_outline, color: Colors.white, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Error loading login page',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // 🧱 Horizontal Layout for Desktop/Tablets
  Widget _buildHorizontalLayout(BuildContext context, bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: isTablet ? 1 : 2, child: _buildLeftPanel()),
        const SizedBox(width: 20),
        if (showForm)
          Expanded(
  flex: 2,
  child: AnimatedSlide(
    offset: showForm ? Offset(0, 0) : Offset(1.0, 0), // slide from right
    duration: Duration(milliseconds: 800),
    curve: Curves.easeInOut,
    child: _buildRightPanel(context),
  ),
),
 // <-- conditional
      ],
    );
  }

  // 📱 Vertical Layout for Mobile
  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      children: [
        _buildLeftPanel(),
        const SizedBox(height: 30),
        if (showForm) _buildRightPanel(context), // <-- conditional
      ],
    );
  }

  // 🟦 Left side content
  Widget _buildLeftPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Try to load Lottie, show placeholder if it fails
        Builder(
          builder: (context) {
            try {
              return Lottie.asset(
                'assets/Animation - 1750510706715.json',
                width: 250,
                height: 250,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.bolt,
                    size: 250,
                    color: Colors.white54,
                  );
                },
              );
            } catch (e) {
              return const Icon(
                Icons.bolt,
                size: 250,
                color: Colors.white54,
              );
            }
          },
        ),
        const SizedBox(height: 12),
        const Text(
          'Welcome Back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'We are delighted to have you here.\nPlease enter personal details to your user account.\nIf you need any assistance feel free to reach out.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.white70, height: 1.4),
        ),
        const SizedBox(height: 25),
        _buildToggleButtons(),
      ],
    );
  }

  // 🔘 Sign In / Sign Up toggle
  Widget _buildToggleButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Sign in', true),
          _toggleButton('Sign up', false),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool loginMode) {
    return GestureDetector(
      onTap: () {
        setState(() {
          isLogin = loginMode;
          showForm = true; // <-- show form when toggle tapped
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isLogin == loginMode
              ? Colors.white.withOpacity(0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // 🟨 Right side (Login / Signup form)
  Widget _buildRightPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 17, 13, 128).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isLogin ? 'Log in to your account' : 'Create Account',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 25),

          if (!isLogin) ...[
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Full Name', Icons.person),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Email', Icons.email),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Password', Icons.lock),
          ),
          const SizedBox(height: 12),

          if (!isLogin)
            TextField(
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration:
                  _inputDecoration('Confirm Password', Icons.lock_outline),
            ),

          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Forgot Password?',
                    style: TextStyle(color: Colors.white70)),
              ),
            ),

          const SizedBox(height: 18),

          // ✅ Main button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (isLogin) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                } else {
                  // handle signup
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isLogin ? 'Login' : 'Sign Up',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          if (isLogin) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MyAdminScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.admin_panel_settings,
                    color: Colors.white70),
                label: const Text(
                  'Admin Login',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          const Text('Or continue with',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: _isLoading ? null : _handleGoogleSignIn,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(FontAwesomeIcons.google, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    // Check if Client ID is still placeholder
    if (kIsWeb && _webClientId.contains('REPLACE_WITH_YOUR_WEB_CLIENT_ID')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please configure your Google OAuth Client ID first!\nCheck login.dart and web/index.html',
              style: TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Step 1: Sign in with Google
      // For web, try silent sign-in first (recommended approach)
      GoogleSignInAccount? googleUser;
      if (kIsWeb) {
        // Try silent sign-in first (no popup, uses existing session)
        try {
          googleUser = await _googleSignIn.signInSilently();
        } catch (e) {
          // Silent sign-in failed, try regular sign-in
          debugPrint('Silent sign-in failed: $e');
        }
        // If silent sign-in fails, use regular sign-in (shows deprecation warning)
        googleUser ??= await _googleSignIn.signIn();
      } else {
        // For mobile/desktop, use regular sign-in
        googleUser = await _googleSignIn.signIn();
      }

      if (googleUser == null) {
        // User cancelled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Step 2: Get authentication details from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Step 3: Create a new credential for Firebase Auth
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase with Google credential
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed');
      }

      // Step 5: Check if user exists in Firestore (sign-in vs sign-up)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      // Determine if this is a new user
      final bool isNewUser = !userDoc.exists || 
          (userCredential.additionalUserInfo?.isNewUser ?? false);

      // If in sign-up mode and user already exists, show message
      if (!isLogin && userDoc.exists && 
          (userCredential.additionalUserInfo?.isNewUser == false)) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This account already exists. Please sign in instead.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Step 6: Save/Update user data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
        'uid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'displayName': firebaseUser.displayName ?? googleUser.displayName ?? '',
        'photoURL': firebaseUser.photoURL ?? googleUser.photoUrl ?? '',
        'provider': 'google.com',
        'createdAt': isNewUser ? FieldValue.serverTimestamp() : userDoc.data()?['createdAt'],
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isNewUser': isNewUser,
      }, SetOptions(merge: true));

      // Step 7: Show success message and navigate to home screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNewUser 
                ? 'Account created successfully! Welcome!' 
                : 'Signed in successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to home screen after a brief delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white30),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.tealAccent),
      ),
    );
  }
}
