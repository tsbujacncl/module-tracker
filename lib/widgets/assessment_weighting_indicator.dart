import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/theme/design_tokens.dart';

/// Displays the total weighting of assessments with visual feedback
class AssessmentWeightingIndicator extends StatelessWidget {
  final List<Assessment> assessments;
  final bool showQuickFill;
  final VoidCallback? onQuickFill;

  const AssessmentWeightingIndicator({
    super.key,
    required this.assessments,
    this.showQuickFill = false,
    this.onQuickFill,
  });

  double get totalWeighting {
    return assessments.fold<double>(0, (sum, assessment) => sum + assessment.weighting);
  }

  WeightingStatus get status {
    if (totalWeighting == 100.0) {
      return WeightingStatus.perfect;
    } else if (totalWeighting >= 95.0 && totalWeighting < 100.0 ||
               totalWeighting > 100.0 && totalWeighting <= 105.0) {
      return WeightingStatus.warning;
    } else {
      return WeightingStatus.error;
    }
  }

  Color get statusColor {
    switch (status) {
      case WeightingStatus.perfect:
        return DesignTokens.labGreen;
      case WeightingStatus.warning:
        return DesignTokens.amber;
      case WeightingStatus.error:
        return DesignTokens.red;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case WeightingStatus.perfect:
        return Icons.check_circle;
      case WeightingStatus.warning:
        return Icons.warning;
      case WeightingStatus.error:
        return Icons.error;
    }
  }

  String get statusMessage {
    final difference = (100.0 - totalWeighting).abs();

    if (status == WeightingStatus.perfect) {
      return 'All assessments accounted for';
    } else if (totalWeighting < 100.0) {
      return '${difference.toStringAsFixed(1)}% unaccounted';
    } else {
      return '${difference.toStringAsFixed(1)}% over 100%';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceL),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(isDarkMode ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusM),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                color: statusColor,
                size: DesignTokens.iconL,
              ),
              const SizedBox(width: DesignTokens.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Weighting',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: DesignTokens.getTextSecondaryColor(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${totalWeighting.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (status != WeightingStatus.perfect)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceM,
                    vertical: DesignTokens.spaceS,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusS),
                  ),
                  child: Text(
                    totalWeighting < 100 ? '-${(100 - totalWeighting).toStringAsFixed(0)}%'
                                         : '+${(totalWeighting - 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceS),
          Text(
            statusMessage,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (showQuickFill &&
              onQuickFill != null &&
              totalWeighting < 100.0 &&
              assessments.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.spaceM),
            OutlinedButton.icon(
              onPressed: onQuickFill,
              icon: const Icon(Icons.auto_fix_high, size: DesignTokens.iconS),
              label: const Text('Quick Fill Remaining'),
              style: OutlinedButton.styleFrom(
                foregroundColor: statusColor,
                side: BorderSide(color: statusColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceM,
                  vertical: DesignTokens.spaceS,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact version for inline display
class AssessmentWeightingBadge extends StatelessWidget {
  final double totalWeighting;

  const AssessmentWeightingBadge({
    super.key,
    required this.totalWeighting,
  });

  WeightingStatus get status {
    if (totalWeighting == 100.0) {
      return WeightingStatus.perfect;
    } else if (totalWeighting >= 95.0 && totalWeighting < 100.0 ||
               totalWeighting > 100.0 && totalWeighting <= 105.0) {
      return WeightingStatus.warning;
    } else {
      return WeightingStatus.error;
    }
  }

  Color get statusColor {
    switch (status) {
      case WeightingStatus.perfect:
        return DesignTokens.labGreen;
      case WeightingStatus.warning:
        return DesignTokens.amber;
      case WeightingStatus.error:
        return DesignTokens.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceM,
        vertical: DesignTokens.spaceS,
      ),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusS),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == WeightingStatus.perfect
                ? Icons.check_circle
                : Icons.warning,
            color: statusColor,
            size: DesignTokens.iconS,
          ),
          const SizedBox(width: DesignTokens.spaceS),
          Text(
            '${totalWeighting.toStringAsFixed(0)}%',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status enum for weighting validation
enum WeightingStatus {
  perfect,  // Exactly 100%
  warning,  // Close to 100% (95-99% or 101-105%)
  error,    // Far from 100% (<95% or >105%)
}
