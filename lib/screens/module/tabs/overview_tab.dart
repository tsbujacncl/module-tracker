import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/widgets/module_notes_card.dart';
import 'package:module_tracker/widgets/lecture_history_list.dart';
import 'package:module_tracker/providers/module_provider.dart';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats row
          tasksAsync.when(
            data: (tasks) {
              return assessmentsAsync.when(
                data: (assessments) {
                  final lectures = tasks.where((t) => t.type == RecurringTaskType.lecture).length;
                  final labs = tasks.where((t) => t.type == RecurringTaskType.lab).length;
                  final tutorials = tasks.where((t) => t.type == RecurringTaskType.tutorial).length;
                  final completedAssessments = assessments.where((a) => a.markEarned != null).length;

                  return _QuickStatsRow(
                    lectures: lectures,
                    labs: labs,
                    tutorials: tutorials,
                    completedAssessments: completedAssessments,
                    totalAssessments: assessments.length,
                    isDarkMode: isDarkMode,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Module notes
          ModuleNotesCard(module: module),

          // Lecture history
          tasksAsync.when(
            data: (tasks) {
              final hasLectures = tasks.any((t) => t.type == RecurringTaskType.lecture);
              if (!hasLectures) return const SizedBox.shrink();

              return Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  LectureHistoryList(
                    module: module,
                    taskType: RecurringTaskType.lecture,
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Lab history
          tasksAsync.when(
            data: (tasks) {
              final hasLabs = tasks.any((t) => t.type == RecurringTaskType.lab);
              if (!hasLabs) return const SizedBox.shrink();

              return Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  LectureHistoryList(
                    module: module,
                    taskType: RecurringTaskType.lab,
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Tutorial history
          tasksAsync.when(
            data: (tasks) {
              final hasTutorials = tasks.any((t) => t.type == RecurringTaskType.tutorial);
              if (!hasTutorials) return const SizedBox.shrink();

              return Column(
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  LectureHistoryList(
                    module: module,
                    taskType: RecurringTaskType.tutorial,
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final int lectures;
  final int labs;
  final int tutorials;
  final int completedAssessments;
  final int totalAssessments;
  final bool isDarkMode;

  const _QuickStatsRow({
    required this.lectures,
    required this.labs,
    required this.tutorials,
    required this.completedAssessments,
    required this.totalAssessments,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        if (lectures > 0)
          _QuickStatChip(
            icon: Icons.school_outlined,
            label: '$lectures Lecture${lectures != 1 ? 's' : ''}',
            color: const Color(0xFF3B82F6),
            isDarkMode: isDarkMode,
          ),
        if (labs > 0)
          _QuickStatChip(
            icon: Icons.science_outlined,
            label: '$labs Lab${labs != 1 ? 's' : ''}',
            color: const Color(0xFF10B981),
            isDarkMode: isDarkMode,
          ),
        if (tutorials > 0)
          _QuickStatChip(
            icon: Icons.groups_outlined,
            label: '$tutorials Tutorial${tutorials != 1 ? 's' : ''}',
            color: const Color(0xFFF59E0B),
            isDarkMode: isDarkMode,
          ),
        if (totalAssessments > 0)
          _QuickStatChip(
            icon: Icons.assignment_outlined,
            label: '$completedAssessments/$totalAssessments Assessments',
            color: const Color(0xFF8B5CF6),
            isDarkMode: isDarkMode,
          ),
      ],
    );
  }
}

class _QuickStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDarkMode;

  const _QuickStatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
