import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/theme/design_tokens.dart';

/// Banner to display when assessments have TBC (To Be Confirmed) dates
class TbcAssessmentBanner extends StatelessWidget {
  final int tbcCount;
  final VoidCallback? onTap;

  const TbcAssessmentBanner({
    super.key,
    required this.tbcCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF59E0B).withOpacity(0.1),
              const Color(0xFFF59E0B).withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFF59E0B),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.schedule,
                color: Color(0xFFF59E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$tbcCount Assessment${tbcCount == 1 ? '' : 's'} To Be Confirmed',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to review and update dates',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDarkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }
}
