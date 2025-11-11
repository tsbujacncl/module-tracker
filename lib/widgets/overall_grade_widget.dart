import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/grade_provider.dart';
import 'package:module_tracker/services/app_logger.dart';

class OverallGradeWidget extends ConsumerWidget {
  const OverallGradeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallGrade = ref.watch(overallUniversityGradeProvider);

    // Debug: Check what's happening
    AppLogger.debug('OverallGrade: $overallGrade');
    if (overallGrade != null) {
      AppLogger.debug('Credits: ${overallGrade.totalCreditsCompleted} / ${overallGrade.totalCreditsPossible}');
      AppLogger.debug('Percentage: ${overallGrade.overallPercentage}%');
    }

    if (overallGrade == null) {
      AppLogger.debug('Overall grade is null - no graded assessments yet');
      return const SizedBox.shrink();
    }

    // Get color based on classification
    Color getClassificationColor() {
      if (overallGrade.overallPercentage >= 70) {
        return const Color(0xFFF59E0B); // Gold for First
      } else if (overallGrade.overallPercentage >= 60) {
        return const Color(0xFF10B981); // Green for 2:1
      } else if (overallGrade.overallPercentage >= 50) {
        return const Color(0xFF3B82F6); // Blue for 2:2
      } else if (overallGrade.overallPercentage >= 40) {
        return const Color(0xFF8B5CF6); // Purple for Third
      } else {
        return const Color(0xFFEF4444); // Red for Fail
      }
    }

    final classificationColor = getClassificationColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            classificationColor,
            classificationColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: classificationColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left side - Overall Grade
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Grade',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${overallGrade.overallPercentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  overallGrade.classification,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ],
            ),
          ),
          // Right side - Credits
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Credits',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${overallGrade.totalCreditsCompleted.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'of ${overallGrade.totalCreditsPossible.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
