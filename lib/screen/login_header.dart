import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import provider
import '../theme_provider.dart'; // Import ThemeNotifier

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).primaryColor.withAlpha(200), // Use theme color
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  // Use theme text style
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            // Theme Toggle (always present, self-managed)
            Consumer<ThemeNotifier>(
              builder: (context, notifier, child) => IconButton(
                icon: Icon(
                  notifier.darkTheme ? Icons.dark_mode : Icons.light_mode,
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary, // Use theme color
                ),
                onPressed: () {
                  notifier.toggleTheme();
                },
                tooltip: notifier.darkTheme
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
