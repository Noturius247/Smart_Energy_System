import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home.dart';
import 'login_header.dart'; // Import LoginHeader
import 'theadmin.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true; // New state for password visibility
  bool _obscureConfirmPassword = true; // New state for confirm password visibility

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      clientId: kIsWeb ? _webClientId : null,
      scopes: const ['email', 'profile'],
    );
  }

  Future<void> _resendVerificationEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enter your email and password to resend verification.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) throw Exception('Unable to sign in to resend verification');
      if (user.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Email already verified. Please sign in.'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

      await user.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email resent. Check your inbox.'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resending verification email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend verification email: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final size = MediaQuery.of(context).size;
      final isMobile = size.width < 600;
      final isTablet = size.width >= 600 && size.width < 1000;

      return Scaffold(
        body: Stack( // Use Stack to place CustomHeader on top
          children: [
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
                            gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
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
            // CustomHeader at the top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LoginHeader(),
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onSurface, size: 64),
                const SizedBox(height: 20),
                Text(
                  'Error loading login page',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20),
                ),
                const SizedBox(height: 10),
                Text(
                  e.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
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
        Expanded(
          flex: 2,
          child: _buildRightPanel(context),
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
        _buildRightPanel(context),
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
                  return Icon(
                    Icons.bolt,
                    size: 250,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                  );
                },
              );
            } catch (e) {
              return Icon(
                Icons.bolt,
                size: 250,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome Back!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            color: Theme.of(context).textTheme.headlineSmall?.color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We are delighted to have you here.\nPlease enter personal details to your user account.\nIf you need any assistance feel free to reach out.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.4),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
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
          // Clear all controllers when switching between login and signup
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
          _confirmPasswordController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isLogin == loginMode
              ? Theme.of(context).colorScheme.secondary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).textTheme.labelLarge?.color,
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
        gradient: LinearGradient(colors: [Theme.of(context).cardColor, Theme.of(context).primaryColor]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            isLogin ? 'Log in to your account' : 'Create Account',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 25),

          if (!isLogin) ...[
            TextField(
              controller: _nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _inputDecoration('Full Name', Icons.person),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _emailController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration('Email', Icons.email),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration('Password', Icons.lock).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (!isLogin)
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration:
                  _inputDecoration('Confirm Password', Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
            ),

          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handlePasswordReset,
                child: Text('Forgot Password?',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              ),
            ),

          const SizedBox(height: 18),

          // ✅ Main button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                if (isLogin) {
                  // Sign-in mode: validate email exists in database
                  _handleEmailPasswordLogin();
                } else {
                  // Sign-up mode: create account, save to Firestore and authenticate
                  _handleEmailPasswordSignup();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onSecondary),
                      ),
                    )
                  : Text(
                      isLogin ? 'Login' : 'Sign Up',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondary),
                    ),
            ),
          ),



          const SizedBox(height: 20),
          Text('Or sign in/up with',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
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
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.onSecondary),
                          ),
                        )
                      : Icon(FontAwesomeIcons.google, color: Theme.of(context).colorScheme.onSurface, size: 24),
                ),
              ),
            ],
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
      
      debugPrint('✅ Firebase authentication successful: ${userCredential.user?.uid}');
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
      } catch (e) { // General catch for any other exceptions
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
    } finally { // Always executes after try/catch
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
            content: Text('A verification email has been sent to your address. Please verify your email to activate your Smart Energy Meter account.'),
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
    } catch (e) { // General catch for any other exceptions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally { // Always executes after try/catch
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
            content: const Text('Password reset email sent. Please check your inbox.'),
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

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!user.emailVerified && !isAdmin) { // Only check email verification for non-admins
      // Email is not verified
      setState(() {
        _isLoading = false;
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please verify your email before logging in.'),
            backgroundColor: Theme.of(context).colorScheme.error, // Themed color
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Resend',
              textColor: Theme.of(context).colorScheme.onPrimary, // Themed color
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
          MaterialPageRoute(builder: (context) => const MyAdminScreen()),
        );
      }
    } else if (userDoc.exists) {
      // User is verified and data exists
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
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
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
      filled: true,
      fillColor: Theme.of(context).cardColor.withOpacity(0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary),
      ),
    );
  }
}
