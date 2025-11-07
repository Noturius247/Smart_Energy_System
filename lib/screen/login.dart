import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
        Lottie.asset(
          'assets/Animation - 1750510706715.json',
          width: 250,
          height: 250,
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
            children: const [
              Icon(FontAwesomeIcons.google, color: Colors.white),
              SizedBox(width: 16),
              Icon(FontAwesomeIcons.facebook, color: Colors.white),
              SizedBox(width: 16),
              Icon(FontAwesomeIcons.microsoft, color: Colors.white),
            ],
          ),
        ],
      ),
    );
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
