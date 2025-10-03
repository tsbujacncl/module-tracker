import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';
import 'package:intl/intl.dart';

class AssessmentsTab extends ConsumerStatefulWidget {
  final Module module;

  const AssessmentsTab({
    super.key,
    required this.module,
  });

  @override
  ConsumerState<AssessmentsTab> createState() => _AssessmentsTabState();
}

class _AssessmentsTabState extends ConsumerState<AssessmentsTab> {
  String _sortBy = 'date'; // date, weighting, type

  @override
  Widget build(BuildContext context) {
    final assessmentsAsync = ref.watch(assessmentsProvider(widget.module.id));
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return assessmentsAsync.when(
      data: (assessments) {
        if (assessments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No assessments',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add assessments to this module',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        // Calculate total weighting
        final totalWeighting = assessments.fold<double>(
          0.0,
          (sum, a) => sum + (a.weighting ?? 0.0),
        );

        // Sort assessments
        final sortedAssessments = List<Assessment>.from(assessments);
        switch (_sortBy) {
          case 'date':
            sortedAssessments.sort((a, b) {
              if (a.dueDate == null && b.dueDate == null) return 0;
              if (a.dueDate == null) return 1;
              if (b.dueDate == null) return -1;
              return a.dueDate!.compareTo(b.dueDate!);
            });
            break;
          case 'weighting':
            sortedAssessments.sort((a, b) =>
                (b.weighting ?? 0.0).compareTo(a.weighting ?? 0.0));
            break;
          case 'type':
            sortedAssessments.sort((a, b) =>
                a.type.toString().compareTo(b.type.toString()));
            break;
        }

        return Column(
          children: [
            // Header with weighting indicator and sort
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              color: isDarkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  Expanded(
                    child: _WeightingIndicator(totalWeighting: totalWeighting),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  PopupMenuButton<String>(
                    initialValue: _sortBy,
                    icon: const Icon(Icons.sort),
                    onSelected: (value) {
                      setState(() => _sortBy = value);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'date',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18),
                            SizedBox(width: 8),
                            Text('Sort by Date'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'weighting',
                        child: Row(
                          children: [
                            Icon(Icons.balance, size: 18),
                            SizedBox(width: 8),
                            Text('Sort by Weighting'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'type',
                        child: Row(
                          children: [
                            Icon(Icons.category, size: 18),
                            SizedBox(width: 8),
                            Text('Sort by Type'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Assessments list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: sortedAssessments.length,
                itemBuilder: (context, index) {
                  return _AssessmentCard(
                    assessment: sortedAssessments[index],
                    module: widget.module,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading assessments: $error'),
      ),
    );
  }
}

class _WeightingIndicator extends StatelessWidget {
  final double totalWeighting;

  const _WeightingIndicator({required this.totalWeighting});

  Color _getColor() {
    if (totalWeighting == 100.0) return const Color(0xFF10B981);
    if (totalWeighting >= 95.0 && totalWeighting <= 105.0) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFEF4444);
  }

  String _getMessage() {
    if (totalWeighting == 100.0) return 'Perfect!';
    if (totalWeighting > 100.0) return 'Over 100%';
    if (totalWeighting < 100.0) return 'Under 100%';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            totalWeighting == 100.0
                ? Icons.check_circle
                : Icons.warning,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Total: ${totalWeighting.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _getMessage(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends ConsumerWidget {
  final Assessment assessment;
  final Module module;

  const _AssessmentCard({
    required this.assessment,
    required this.module,
  });

  String _getTypeName(AssessmentType type) {
    switch (type) {
      case AssessmentType.coursework:
        return 'Coursework';
      case AssessmentType.exam:
        return 'Exam';
      case AssessmentType.weekly:
        return 'Weekly';
    }
  }

  Color _getTypeColor(AssessmentType type) {
    switch (type) {
      case AssessmentType.coursework:
        return const Color(0xFF8B5CF6);
      case AssessmentType.exam:
        return const Color(0xFFEF4444);
      case AssessmentType.weekly:
        return const Color(0xFF3B82F6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(assessment.type);
    final hasGrade = assessment.markEarned != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        border: Border(
          left: BorderSide(
            color: typeColor,
            width: 4,
          ),
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      ),
                      child: Text(
                        _getTypeName(assessment.type),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                      ),
                      child: Text(
                        '${assessment.weighting?.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  assessment.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (assessment.dueDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isDarkMode
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(assessment.dueDate!),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDarkMode
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Grade entry section
          if (hasGrade)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppBorderRadius.md),
                  bottomRight: Radius.circular(AppBorderRadius.md),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Grade: ${assessment.markEarned!.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showGradeDialog(context, ref),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppBorderRadius.md),
                  bottomRight: Radius.circular(AppBorderRadius.md),
                ),
              ),
              child: TextButton.icon(
                onPressed: () => _showGradeDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add Grade'),
              ),
            ),
        ],
      ),
    );
  }

  void _showGradeDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: assessment.markEarned?.toStringAsFixed(1) ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Grade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              assessment.name,
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Grade (%)',
                hintText: '0-100',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final grade = double.tryParse(controller.text);
              if (grade == null || grade < 0 || grade > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid grade (0-100)'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
                return;
              }

              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);

              await repository.updateAssessment(
                user.uid,
                module.semesterId,
                module.id,
                assessment.id,
                {'markEarned': grade},
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Grade saved'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
