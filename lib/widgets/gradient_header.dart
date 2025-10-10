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

  /// Calculate responsive font size based on screen width
  /// - Small screens (< 600): base size (20-24)
  /// - Medium screens (600-900): medium size (24-28)
  /// - Large screens (> 900): large size (28-32)
  double _getResponsiveFontSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 20;
    } else if (width < 900) {
      return 24;
    } else if (width < 1200) {
      return 28;
    } else {
      return 32;
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
