import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/grade_calculation.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/screens/grades/what_if_calculator.dart';
import 'package:module_tracker/theme/design_tokens.dart';
import 'dart:math' as math;

class ModuleGradeCard extends ConsumerWidget {
  final Module module;
  final ModuleGrade moduleGrade;
  final GradeStatus gradeStatus;

  const ModuleGradeCard({
    super.key,
    required this.module,
    required this.moduleGrade,
    required this.gradeStatus,
  });

  Color _getStatusColor() {
    switch (gradeStatus) {
      case GradeStatus.exceeding:
        return const Color(0xFF10B981); // Green
      case GradeStatus.onTrack:
        return const Color(0xFF3B82F6); // Blue
      case GradeStatus.nearlyThere:
        return const Color(0xFFF59E0B); // Orange
      case GradeStatus.atRisk:
        return const Color(0xFFEF4444); // Red
    }
  }

  String _getStatusText() {
    switch (gradeStatus) {
      case GradeStatus.exceeding:
        return 'Exceeding Target';
      case GradeStatus.onTrack:
        return 'On Track';
      case GradeStatus.nearlyThere:
        return 'Nearly There';
      case GradeStatus.atRisk:
        return 'At Risk';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final statusColor = _getStatusColor();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppBorderRadius.md),
                topRight: Radius.circular(AppBorderRadius.md),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (module.code.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          module.code,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // Current grade with progress circle
                Row(
                  children: [
                    // Circular progress
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _CircularProgressPainter(
                          progress: moduleGrade.currentGrade / 100,
                          color: statusColor,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${moduleGrade.currentGrade.toStringAsFixed(1)}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Current',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: isDarkMode
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    // Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatRow(
                            label: 'Projected',
                            value: '${moduleGrade.projectedGrade.toStringAsFixed(1)}%',
                            icon: Icons.trending_up,
                            color: statusColor,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _StatRow(
                            label: 'Required Avg',
                            value: moduleGrade.isAchievable
                                ? '${moduleGrade.requiredAverage.toStringAsFixed(1)}%'
                                : 'Not Achievable',
                            icon: Icons.flag,
                            color: moduleGrade.isAchievable
                                ? (isDarkMode
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B))
                                : const Color(0xFFEF4444),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _StatRow(
                            label: 'Assessments',
                            value:
                                '${moduleGrade.completedAssessments}/${moduleGrade.totalAssessments}',
                            icon: Icons.assignment_turned_in,
                            color: isDarkMode
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // What-if calculator button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => WhatIfCalculator(
                          module: module,
                          moduleGrade: moduleGrade,
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate, size: 18),
                    label: Text(
                      'What-If Calculator',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: statusColor,
                      side: BorderSide(color: statusColor),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
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

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: color,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background circle
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
