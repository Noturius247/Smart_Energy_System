import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_home.dart';
import 'login_header.dart'; // Import CustomHeader

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool showForm = true; // <-- new: controls form visibility
  bool _isLoading = false;

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
            backgroundColor: Colors.red,
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
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.54),
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
          showForm = true; // <-- show form when toggle tapped
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
            obscureText: true,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: _inputDecoration('Password', Icons.lock),
          ),
          const SizedBox(height: 12),

          if (!isLogin)
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration:
                  _inputDecoration('Confirm Password', Icons.lock_outline),
            ),

          if (isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
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

  Future<bool> _validateEmailInDatabase(String email) async {
    try {
      debugPrint('🔍 Checking if email exists in database: $email');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      final exists = querySnapshot.docs.isNotEmpty;
      debugPrint('✅ Email check result: exists=$exists');
      return exists;
    } catch (e) {
      debugPrint('❌ Error checking email: $e');
      return false;
    }
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
      // In sign-in mode, verify email exists in database
      if (isLogin) {
        debugPrint('🔵 Sign-in mode: Checking if email exists...');
        final emailExists = await _validateEmailInDatabase(email);

        if (!emailExists) {
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Email not found. Please sign up or use Google Sign-In.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      // Proceed with email/password authentication via Firebase
      debugPrint('🔵 Authenticating with Firebase...');
      
      try {
        final userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
        
        debugPrint('✅ Firebase authentication successful: ${userCredential.user?.uid}');
        final signedInUser = userCredential.user;
        // Enforce email verification for password accounts
  if (signedInUser != null && !signedInUser.emailVerified) {
          // Not verified: sign out and ask user to verify first
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Please verify your email before logging in.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Resend',
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  onPressed: () async {
                    // Attempt to resend verification email
                    await _resendVerificationEmail();
                  },
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
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
      }
    } catch (e) {
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
            content: Text('Verification email sent. Please verify your email before signing in.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
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

            // Step 5: Check if user exists in Firestore (sign-in vs sign-up)
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(firebaseUser.uid)
                .get();
      
            // Determine if this is a new user
            final bool isNewUser = !userDoc.exists ||
                (userCredential.additionalUserInfo?.isNewUser ?? false);
      
            // If in sign-in mode (isLogin == true) and it's a new user for the app,
            // ask for confirmation to create a new account.
            if (isLogin && isNewUser) {
              final bool? confirmCreate = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Create New Account?'),
                    content: Text(
                        'This Google account is not yet registered with Smart Energy System. Would you like to create a new account using ${firebaseUser.email}?'),
                    actions: <Widget>[
                      TextButton(
                        child: const Text('Cancel'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(false); // User declined
                        },
                      ),
                      TextButton(
                        child: const Text('Create Account'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true); // User confirmed
                        },
                      ),
                    ],
                  );
                },
              );
      
              if (confirmCreate == false || confirmCreate == null) {
                // User cancelled or dismissed the dialog, sign out from Firebase and Google
                await FirebaseAuth.instance.signOut();
                await _googleSignIn.signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Account creation cancelled.'),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                return; // Stop the sign-in process
              }
            }
      
            // If in sign-up mode and user already exists, show message
            if (!isLogin && userDoc.exists &&
                (userCredential.additionalUserInfo?.isNewUser == false)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This account already exists. Please sign in instead.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
              // Sign out from Firebase and Google if the user tried to sign up with an existing account
              await FirebaseAuth.instance.signOut();
              await _googleSignIn.signOut();
              return; // _isLoading will be reset in finally block
            }
      
            // Step 6: Save/Update user data in Firestore      await FirebaseFirestore.instance
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
            // The AuthWrapper in main.dart will handle navigation based on auth state
            // No explicit navigation needed here.
          }
        });
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
