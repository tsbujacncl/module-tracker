import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/screens/assessments/assessment_detail_screen.dart';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(currentSemesterModulesProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 900 ? 1 : 2;

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF10B981)],
          ).createShader(bounds),
          child: Text(
            'Assignments',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: modulesAsync.when(
        data: (modules) {
          if (modules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assessment_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Assignments Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Add modules with assessments to see your breakdown',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort modules alphabetically by code
          final sortedModules = [...modules]
            ..sort((a, b) => a.code.compareTo(b.code));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: sortedModules.map((module) {
                return SizedBox(
                  width: crossAxisCount == 1
                      ? double.infinity
                      : (screenWidth - 48) / 2, // Account for padding and spacing
                  child: _ModuleBox(module: module),
                );
              }).toList(),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

class _ModuleBox extends ConsumerWidget {
  final Module module;

  const _ModuleBox({required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessmentsAsync = ref.watch(assessmentsProvider(module.id));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: assessmentsAsync.when(
        data: (assessments) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Module Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.name,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (module.code.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF0EA5E9).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              module.code,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0EA5E9),
                              ),
                            ),
                          ),
                          if (module.credits > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${module.credits} credits',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Content
              if (assessments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No assessments yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Pie Chart Section
                _PieChartSection(
                  module: module,
                  assessments: assessments,
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                // Assessments List
                _AssessmentsList(
                  module: module,
                  assessments: assessments,
                ),
              ],
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Error loading assessments',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieChartSection extends StatelessWidget {
  final Module module;
  final List<Assessment> assessments;

  const _PieChartSection({
    required this.module,
    required this.assessments,
  });

  List<Color> _generateColors(int count) {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Green
      const Color(0xFFEF4444), // Red
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF97316), // Orange
    ];

    if (count <= colors.length) {
      return colors.sublist(0, count);
    }

    return List.generate(count, (i) => colors[i % colors.length]);
  }

  @override
  Widget build(BuildContext context) {
    final totalWeighting = assessments.fold<double>(0, (sum, a) => sum + a.weighting);
    final unaccountedPercentage = math.max(0.0, 100.0 - totalWeighting);
    final colors = _generateColors(assessments.length);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assessment Breakdown',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          // Pie chart
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _PieChartPainter(
                assessments: assessments,
                colors: colors,
                unaccountedPercentage: unaccountedPercentage,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          ...assessments.asMap().entries.map((entry) {
            final index = entry.key;
            final assessment = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assessment.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${assessment.weighting.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors[index],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (unaccountedPercentage > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unaccounted',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Text(
                    '${unaccountedPercentage.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Divider(color: Colors.grey[300], height: 1),
          const SizedBox(height: 8),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${totalWeighting.toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssessmentsList extends ConsumerWidget {
  final Module module;
  final List<Assessment> assessments;

  const _AssessmentsList({
    required this.module,
    required this.assessments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    // Separate assessments into categories
    final upcomingAssessments = assessments
        .where((a) => a.dueDate != null && a.dueDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final tbcAssessments = assessments
        .where((a) => a.dueDate == null)
        .toList();

    final completedAssessments = assessments
        .where((a) => a.dueDate != null && !a.dueDate!.isAfter(now))
        .toList()
      ..sort((a, b) => b.dueDate!.compareTo(a.dueDate!)); // Most recent first

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upcoming assessments
          if (upcomingAssessments.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 6),
                Text(
                  'Upcoming',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...upcomingAssessments.map((assessment) {
              return _AssessmentCard(
                assessment: assessment,
                module: module,
                isUpcoming: true,
              );
            }),
            const SizedBox(height: 16),
          ],
          // TBC assessments
          if (tbcAssessments.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 6),
                Text(
                  'TBC',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tbcAssessments.map((assessment) {
              return _AssessmentCard(
                assessment: assessment,
                module: module,
                isTBC: true,
              );
            }),
            const SizedBox(height: 16),
          ],
          // Completed assessments
          if (completedAssessments.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  'Completed',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...completedAssessments.map((assessment) {
              return _AssessmentCard(
                assessment: assessment,
                module: module,
                isCompleted: true,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final Assessment assessment;
  final Module module;
  final bool isUpcoming;
  final bool isTBC;
  final bool isCompleted;

  const _AssessmentCard({
    required this.assessment,
    required this.module,
    this.isUpcoming = false,
    this.isTBC = false,
    this.isCompleted = false,
  });

  Color _getUrgencyColor() {
    if (isTBC) return const Color(0xFFF59E0B);
    if (isCompleted) return const Color(0xFF10B981);

    final daysUntilDue = assessment.dueDate!.difference(DateTime.now()).inDays;
    if (daysUntilDue <= 3) return const Color(0xFFEF4444); // Red: ≤3 days
    if (daysUntilDue <= 14) return const Color(0xFFF59E0B); // Yellow: 4-14 days
    return const Color(0xFF10B981); // Green: >14 days
  }

  String _getUrgencyIcon() {
    if (isTBC) return '⚪';
    if (isCompleted) return '✓';

    final daysUntilDue = assessment.dueDate!.difference(DateTime.now()).inDays;
    if (daysUntilDue <= 3) return '🔴';
    if (daysUntilDue <= 14) return '🟡';
    return '🟢';
  }

  String _getDueDateText() {
    if (isTBC) return 'TBC';
    if (assessment.dueDate == null) return 'No date';

    final daysUntilDue = assessment.dueDate!.difference(DateTime.now()).inDays;
    final dateFormat = '${assessment.dueDate!.day}/${assessment.dueDate!.month}';

    if (isCompleted) {
      return dateFormat;
    }

    if (daysUntilDue == 0) return 'Today';
    if (daysUntilDue == 1) return 'Tomorrow';
    if (daysUntilDue < 0) return dateFormat;
    return '$dateFormat (${daysUntilDue}d)';
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: urgencyColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: urgencyColor.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssessmentDetailScreen(
                assessment: assessment,
                module: module,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Urgency icon
                  Text(
                    _getUrgencyIcon(),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assessment.name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                assessment.type.toString().split('.').last[0].toUpperCase() +
                                    assessment.type.toString().split('.').last.substring(1),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: urgencyColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${assessment.weighting.toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: urgencyColor,
                                ),
                              ),
                            ),
                            if (assessment.markEarned != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${assessment.markEarned!.toStringAsFixed(1)}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Description
                        if (assessment.description != null &&
                            assessment.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            assessment.description!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Due date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _getDueDateText(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: urgencyColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right,
                        color: const Color(0xFF94A3B8),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<Assessment> assessments;
  final List<Color> colors;
  final double unaccountedPercentage;

  _PieChartPainter({
    required this.assessments,
    required this.colors,
    required this.unaccountedPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.8;

    double startAngle = -math.pi / 2; // Start from top

    // Draw each assessment slice
    for (int i = 0; i < assessments.length; i++) {
      final assessment = assessments[i];
      final sweepAngle = (assessment.weighting / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw unaccounted slice if exists
    if (unaccountedPercentage > 0) {
      final sweepAngle = (unaccountedPercentage / 100) * 2 * math.pi;

      final paint = Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
