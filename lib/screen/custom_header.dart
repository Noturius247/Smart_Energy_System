import 'package:flutter/material.dart';
import 'profile.dart';
import 'chatbot.dart'; // ✅ Import chatbot

class CustomHeader extends StatelessWidget {
  final bool isDarkMode;
  final bool isSidebarOpen;
  final VoidCallback onToggleDarkMode;
  final String? userPhotoUrl; 

  const CustomHeader({
    super.key,
    required this.isDarkMode,
    required this.isSidebarOpen,
    required this.onToggleDarkMode,
    this.userPhotoUrl,
  });

  // ✅ Function to open Chatbot as side panel
  void _openChatbotSidePanel(BuildContext context) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withOpacity(0.3),
      pageBuilder: (_, __, ___) => const ChatbotScreen(),
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1, 0); // slide from right
        const end = Offset(0, 0);
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Smart Energy System',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            // ✅ Chat button added here
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.teal),
              onPressed: () => _openChatbotSidePanel(context),
              tooltip: 'Open Chatbot',
            ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.teal),
              onPressed: () {
                // Optional: Add notifications page navigation here
              },
            ),
            IconButton(
              icon: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Colors.teal,
              ),
              onPressed: onToggleDarkMode,
            ),
            GestureDetector(
              onTap: () {
                // Navigate to profile screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EnergyProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.teal,
                backgroundImage: userPhotoUrl != null
                    ? NetworkImage(userPhotoUrl!)
                    : null,
                child: userPhotoUrl == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 28,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}