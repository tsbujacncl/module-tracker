import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';

/// A compact chip displaying module information
/// Format: "Module Name - CODE"
class ModuleChip extends StatelessWidget {
  final Module module;
  final VoidCallback? onTap;

  const ModuleChip({
    super.key,
    required this.module,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          '${module.name} - ${module.code}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }
}
