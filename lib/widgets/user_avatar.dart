import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A circular avatar that displays the first letter of a user's name
/// with a deterministic color based on the user's name/ID
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;

  const UserAvatar({super.key, required this.name, this.size = 40});

  /// Generate a deterministic color based on the name
  /// Uses a palette of pleasant colors for consistency
  Color _getAvatarColor() {
    // Palette of pleasant colors
    const colors = [
      Color(0xFF795548), // Brown
      Color(0xFF1565C0), // Dark Blue
      Color(0xFF4CAF50), // Green
      Color(0xFF9C27B0), // Purple
      Color(0xFF00ACC1), // Cyan
      Color(0xFFFF7043), // Deep Orange
      Color(0xFF5E35B1), // Deep Purple
      Color(0xFF43A047), // Light Green
      Color(0xFFE53935), // Red
      Color(0xFF6D4C41), // Brown variant
      Color(0xFF1E88E5), // Blue
      Color(0xFF7CB342), // Lime Green
    ];

    // Generate hash from name
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }

    // Use absolute value and modulo to get index
    final index = hash.abs() % colors.length;
    return colors[index];
  }

  /// Get the first letter of the name, uppercase
  String _getInitial() {
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getAvatarColor(),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _getInitial(),
          style: GoogleFonts.poppins(
            fontSize: size * 0.5, // Half the size for proper proportions
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
