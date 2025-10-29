import 'package:flutter/material.dart';
import 'profile.dart'; // ✅ make sure this path is correct

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
                radius: 22, // Slightly larger for photo
                backgroundColor: Colors.teal,
                backgroundImage: userPhotoUrl != null
                    ? NetworkImage(userPhotoUrl!) // Use network photo if provided
                    : null,
                child: userPhotoUrl == null
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 28,
                      )
                    : null, // Fallback icon if no photo
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
