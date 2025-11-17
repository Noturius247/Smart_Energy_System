import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../theme_provider.dart'; // Import ThemeNotifier
import 'profile.dart';
import 'chatbot.dart'; // ✅ Import chatbot

class CustomHeader extends StatelessWidget {
  final bool isSidebarOpen;
  final String? userPhotoUrl;
  // Make these optional, as the Consumer will handle the actual theme state
  final bool? isDarkMode;
  final VoidCallback? onToggleDarkMode;
  final bool showChatIcon;
  final bool showNotificationIcon;
  final bool showProfileIcon;

  const CustomHeader({
    super.key,
    required this.isSidebarOpen,
    this.userPhotoUrl,
    this.isDarkMode, // Now optional
    this.onToggleDarkMode, // Now optional
    this.showChatIcon = true, // Default to true
    this.showNotificationIcon = true, // Default to true
    this.showProfileIcon = true, // Default to true
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
          color: Theme.of(context).primaryColor.withAlpha(200), // Use theme color
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
            Expanded(
              child: Text(
                'Smart Energy System',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith( // Use theme text style
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            // ✅ Chat button added here
            if (showChatIcon)
              IconButton(
                icon: Icon(Icons.chat, color: Theme.of(context).colorScheme.secondary), // Use theme color
                onPressed: () => _openChatbotSidePanel(context),
                tooltip: 'Open Chatbot',
              ),
            if (showNotificationIcon)
              IconButton(
                icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.secondary), // Use theme color
                onPressed: () {
                  // Optional: Add notifications page navigation here
                },
              ),
            // Theme Toggle (always present, self-managed)
            Consumer<ThemeNotifier>(
              builder: (context, notifier, child) => IconButton(
                icon: Icon(
                  notifier.darkTheme ? Icons.dark_mode : Icons.light_mode,
                  color: Theme.of(context).colorScheme.secondary, // Use theme color
                ),
                onPressed: () {
                  notifier.toggleTheme();
                },
                tooltip: notifier.darkTheme ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              ),
            ),
            if (showProfileIcon)
              GestureDetector(
                onTap: () {
                  // Navigate to profile screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EnergyProfileScreen()),
                  );
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(context).colorScheme.secondary, // Use theme color
                  backgroundImage: userPhotoUrl != null
                      ? NetworkImage(userPhotoUrl!)
                      : null,
                  child: userPhotoUrl == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onSecondary, // Use theme color
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