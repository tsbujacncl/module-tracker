import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A responsive gradient header widget that scales based on screen width
/// Uses the app's blue-green gradient design
class GradientHeader extends StatelessWidget {
  final String title;
  final double? fontSize; // Optional override for font size

  const GradientHeader({
    super.key,
    required this.title,
    this.fontSize,
  });

  /// Calculate responsive font size based on screen width with smooth interpolation
  /// - Small screens (< 600): 23-24 (smoothly scaled)
  /// - Medium screens (600-900): 24-32 (smooth interpolation)
  /// - Large screens (900-1200): 32-37 (smooth interpolation)
  /// - XLarge screens (> 1200): 37
  double _getResponsiveFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      // Smooth interpolation from 23 to 24 for mobile devices
      final progress = (width / 600).clamp(0.0, 1.0);
      return 23.0 + (1.0 * progress);
    } else if (width < 900) {
      // Smooth interpolation from 24 to 32 between 600-900px
      final progress = (width - 600) / 300; // 0.0 to 1.0
      return 24.0 + (8.0 * progress);
    } else if (width < 1200) {
      // Smooth interpolation from 32 to 37 between 900-1200px
      final progress = (width - 900) / 300; // 0.0 to 1.0
      return 32.0 + (5.0 * progress);
    } else {
      return 37.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveFontSize = fontSize ?? _getResponsiveFontSize(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFF0EA5E9), // Vibrant cyan/sky blue
            Color(0xFF06B6D4), // Cyan
            Color(0xFF10B981), // Green
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.w700,
            color: Colors.white, // This is used as the base for the shader
          ),
        ),
      ),
    );
  }
}
