import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../realtime_db_service.dart';
import 'admin_home.dart';
import 'login_header.dart'; // Import LoginHeader
import 'theadmin.dart';

class AuthPage extends StatefulWidget {
  final RealtimeDbService realtimeDbService; // New: Add RealtimeDbService
  const AuthPage({super.key, required this.realtimeDbService});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true; // New state for password visibility
  bool _obscureConfirmPassword =
      true; // New state for confirm password visibility

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Error messages
  String? _emailError;
  String? _passwordError;
  String? _nameError;
  String? _confirmPasswordError;
  // OAuth 2.0 Web Client ID - Get from the redirect URI configuration
  // Steps to find it:
  // 1. Go to: https://console.cloud.google.com/apis/credentials?project=smart-plug-and-energy-meter
  // 2. Look for OAuth 2.0 Client IDs
  // 3. Find the one with redirect URI: http://localhost (or your domain)
  // 4. Copy that Client ID (not the App ID)
  // Example format: 123456789-abc...xyz.apps.googleusercontent.com
  static const String _webClientId =
      '163950309353-9pu1nfnvfnkuacv3k27o1fe33bd3e6jr.apps.googleusercontent.com';
  late final GoogleSignIn _googleSignIn;
  late RealtimeDbService _realtimeDbService;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? _webClientId : null,
      scopes: const ['email', 'profile'],
    );
    _realtimeDbService = widget.realtimeDbService;
  }

  @override
  Widget build(BuildContext context) {
    try {
      final size = MediaQuery.of(context).size;
      final isMobile = size.width < 768;
      final isTablet = size.width >= 768 && size.width < 1024;

      return Scaffold(
        body: Stack(
          children: [
            // Simplified background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: isMobile ? 80 : 100,
                      bottom: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 20 : 32),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .cardColor
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
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
            ),
            // Header at the top
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LoginHeader(),
            ),
            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Please wait...',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error building AuthPage: $e');
      debugPrint('Stack trace: $stackTrace');
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                SizedBox(height: 20),
                Text(
                  'Error loading login page',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
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
        Expanded(flex: 3, child: _buildLeftPanel(false)),
        SizedBox(width: isTablet ? 20 : 40),
        Expanded(flex: 4, child: _buildRightPanel(context)),
      ],
    );
  }

  // 📱 Vertical Layout for Mobile
  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      children: [
        _buildLeftPanel(true),
        const SizedBox(height: 30),
        _buildRightPanel(context),
      ],
    );
  }

  // 🟦 Left side content
  Widget _buildLeftPanel(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Try to load Lottie, show placeholder if it fails
        Builder(
          builder: (context) {
            try {
              return Lottie.asset(
                'assets/Animation - 1750510706715.json',
                width: isMobile ? 200 : 250,
                height: isMobile ? 200 : 250,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.bolt_rounded,
                    size: isMobile ? 200 : 250,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                  );
                },
              );
            } catch (e) {
              return Icon(
                Icons.bolt_rounded,
                size: isMobile ? 200 : 250,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.54),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Smart Energy Meter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 24 : 28,
            color: Theme.of(context).textTheme.headlineSmall?.color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isMobile
              ? 'Monitor and manage your energy consumption in real-time.'
              : 'Monitor your energy usage, track consumption patterns,\nand optimize your power efficiency with real-time insights.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildToggleButtons(),
      ],
    );
  }

  // 🔘 Sign In / Sign Up toggle
  Widget _buildToggleButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1.5,
        ),
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
    final isSelected = isLogin == loginMode;
    return InkWell(
      onTap: () {
        if (isLogin != loginMode) {
          setState(() {
            isLogin = loginMode;
            // Clear all controllers and errors when switching
            _emailController.clear();
            _passwordController.clear();
            _nameController.clear();
            _confirmPasswordController.clear();
            _emailError = null;
            _passwordError = null;
            _nameError = null;
            _confirmPasswordError = null;
          });
        }
      },
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.secondary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondary
                : Theme.of(context).textTheme.labelLarge?.color,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // 🟨 Right side (Login / Signup form)
  Widget _buildRightPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isLogin ? 'Sign In to Your Dashboard' : 'Create Your Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          if (!isLogin)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Start monitoring your energy consumption',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
            ),
          const SizedBox(height: 28),

          if (!isLogin) ...[
            TextField(
              controller: _nameController,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _inputDecoration('Full Name', Icons.person),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: _emailController,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration('Email', Icons.email_outlined),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: isLogin
                ? const [AutofillHints.password]
                : const [AutofillHints.newPassword],
            textInputAction: isLogin ? TextInputAction.done : TextInputAction.next,
            onSubmitted: isLogin ? (_) => _handleEmailPasswordLogin() : null,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration('Password', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (!isLogin)
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleEmailPasswordSignup(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _inputDecoration('Confirm Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                ),
              ),
            ),

          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _handlePasswordReset,
                icon: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                label: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          SizedBox(height: isLogin ? 24 : 20),

          // ✅ Main button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (isLogin) {
                        _handleEmailPasswordLogin();
                      } else {
                        _handleEmailPasswordSignup();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                shadowColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
              ),
              child: Text(
                isLogin ? 'Sign In' : 'Create Account',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2))),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: const Icon(FontAwesomeIcons.google, size: 20),
              label: Text(
                'Continue with Google',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEmailPasswordLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter email and password'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      debugPrint(
        '✅ Firebase authentication successful: ${userCredential.user?.uid}',
      );
      final signedInUser = userCredential.user;
      if (signedInUser != null) {
        setState(() {
          _isLoading = false;
        });
        await _checkUserVerificationAndData(signedInUser);
      }
    } on FirebaseAuthException catch (firebaseError) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Authentication failed';
      if (firebaseError.code == 'user-not-found') {
        errorMessage = 'Email not registered';
      } else if (firebaseError.code == 'wrong-password') {
        errorMessage = 'Incorrect password';
      } else if (firebaseError.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      } else if (firebaseError.code == 'user-disabled') {
        errorMessage = 'Account has been disabled';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('❌ Firebase auth error: $errorMessage');
    } catch (e) {
      // General catch for any other exceptions
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Always executes after try/catch
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleEmailPasswordSignup() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill name, email and password fields.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (password.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (password != confirm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create Firebase Auth user
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Failed to create user account.');
      }

      // Save user info to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'displayName': name,
        'photoURL': user.photoURL ?? '',
        'provider': 'password',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Optionally send email verification (best practice)
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('Unable to send verification email: $e');
      }
      // After creating account, require email verification before granting access.
      // Sign the user out so they cannot use the app until they verify their email.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error signing out after signup: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent! Please check your inbox to activate your Smart Energy Meter account.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } on FirebaseAuthException catch (firebaseError) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = 'Registration failed';
      if (firebaseError.code == 'email-already-in-use') {
        errorMessage = 'Email is already in use';
      } else if (firebaseError.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      } else if (firebaseError.code == 'weak-password') {
        errorMessage = 'Password is too weak';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('❌ Firebase signup error: $firebaseError');
    } catch (e) {
      // General catch for any other exceptions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // Always executes after try/catch
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your email address first.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Password reset email sent. Please check your inbox.',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else {
        message = 'An error occurred. Please try again later.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('An unexpected error occurred.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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
      // Step 0: Sign out any previously signed-in Google user to force account selection
      await _googleSignIn.signOut();

      // Step 1: Sign in with Google
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
        return; // _isLoading will be reset in finally block
      }

      // Step 2: Get authentication details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Step 3: Create a new credential for Firebase Auth
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase with Google credential
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase authentication failed');
      }

      // Step 5: Use the existing verification and navigation logic
      if (mounted) {
        await _checkUserVerificationAndData(firebaseUser);
      }
    } catch (error) {
      debugPrint('Google sign-in error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Ensure loading state is always reset
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkUserVerificationAndData(User user) async {
    final idTokenResult = await user.getIdTokenResult();
    final isAdmin = idTokenResult.claims?['admin'] == true;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!user.emailVerified && !isAdmin) {
      // Only check email verification for non-admins
      // Email is not verified
      setState(() {
        _isLoading = false;
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please verify your email to access your energy dashboard.'),
            backgroundColor: Theme.of(
              context,
            ).colorScheme.error, // Themed color
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Resend',
              textColor: Theme.of(
                context,
              ).colorScheme.onPrimary, // Themed color
              onPressed: () async {
                await user.sendEmailVerification();
              },
            ),
          ),
        );
      }
    } else if (isAdmin) {
      // User is admin, navigate to admin screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MyAdminScreen(realtimeDbService: _realtimeDbService),
          ),
        );
      }
    } else if (userDoc.exists) {
      // User is verified and data exists
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomeScreen(realtimeDbService: _realtimeDbService),
          ),
        );
      }
    } else {
      // User is verified but no data in Firestore, create it
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'N/A',
        'photoURL': user.photoURL ?? '',
        'provider': user.providerData.first.providerId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                HomeScreen(realtimeDbService: _realtimeDbService),
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        fontSize: 15,
      ),
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        size: 22,
      ),
      filled: true,
      fillColor: Theme.of(context).cardColor.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 2,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
