import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/grade_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class OverviewTab extends ConsumerWidget {
  final Module module;

  const OverviewTab({
    super.key,
    required this.module,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(recurringTasksProvider(module.id));
    final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
    final allCompletionsAsync = ref.watch(allTaskCompletionsProvider(module.id));
    final moduleGrade = ref.watch(moduleGradeProvider(module.id));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attendance section
          Text(
            'Attendance',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          tasksAsync.when(
            data: (tasks) {
              final lecturesAndLabs = tasks.where(
                (t) =>
                    t.type == RecurringTaskType.lecture ||
                    t.type == RecurringTaskType.lab ||
                    t.type == RecurringTaskType.tutorial,
              ).toList();

              return allCompletionsAsync.when(
                data: (completions) {
                  if (lecturesAndLabs.isEmpty) {
                    return _InfoCard(
                      icon: Icons.event_busy,
                      title: 'No scheduled sessions',
                      subtitle: 'Add lectures or labs to track attendance',
                      color: Colors.grey,
                    );
                  }

                  // Count completed lectures/labs
                  int totalSessions = 0;
                  int completedSessions = 0;

                  for (final task in lecturesAndLabs) {
                    final taskCompletions = completions.where((c) => c.taskId == task.id);
                    totalSessions += taskCompletions.length;
                    completedSessions += taskCompletions
                        .where((c) => c.status == TaskStatus.complete)
                        .length;
                  }

                  final attendanceRate = totalSessions > 0
                      ? (completedSessions / totalSessions) * 100
                      : 0.0;

                  return _ProgressCard(
                    icon: Icons.event_available,
                    title: 'Attendance Rate',
                    value: attendanceRate,
                    current: completedSessions,
                    total: totalSessions,
                    color: _getAttendanceColor(attendanceRate),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Assessment completion
          Text(
            'Assessment Progress',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          assessmentsAsync.when(
            data: (assessments) {
              if (assessments.isEmpty) {
                return _InfoCard(
                  icon: Icons.assignment_outlined,
                  title: 'No assessments',
                  subtitle: 'Add assessments to track progress',
                  color: Colors.grey,
                );
              }

              final completedAssessments =
                  assessments.where((a) => a.markEarned != null).length;
              final completionRate =
                  (completedAssessments / assessments.length) * 100;

              return _ProgressCard(
                icon: Icons.assignment_turned_in,
                title: 'Completion Rate',
                value: completionRate,
                current: completedAssessments,
                total: assessments.length,
                color: _getCompletionColor(completionRate),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Grade summary
          Text(
            'Grade Summary',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (moduleGrade != null)
            Column(
              children: [
                _GradeSummaryCard(
                  label: 'Current Grade',
                  value: '${moduleGrade.currentGrade.toStringAsFixed(1)}%',
                  icon: Icons.grade,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: AppSpacing.md),
                _GradeSummaryCard(
                  label: 'Projected Grade',
                  value: '${moduleGrade.projectedGrade.toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: AppSpacing.md),
                _GradeSummaryCard(
                  label: 'Required Average',
                  value: moduleGrade.isAchievable
                      ? '${moduleGrade.requiredAverage.toStringAsFixed(1)}%'
                      : 'Not Achievable',
                  icon: Icons.flag,
                  color: moduleGrade.isAchievable
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFEF4444),
                ),
              ],
            )
          else
            _InfoCard(
              icon: Icons.grade,
              title: 'No grades yet',
              subtitle: 'Complete assessments to see grade summary',
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  Color _getAttendanceColor(double rate) {
    if (rate >= 80) return const Color(0xFF10B981);
    if (rate >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _getCompletionColor(double rate) {
    if (rate >= 75) return const Color(0xFF10B981);
    if (rate >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _ProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double value;
  final int current;
  final int total;
  final Color color;

  const _ProgressCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: color.withOpacity(0.3),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                '${value.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '$current / $total',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  subtitle,
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
        ],
      ),
    );
  }
}

class _GradeSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GradeSummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border.all(
          color: color.withOpacity(0.3),
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
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDarkMode
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
