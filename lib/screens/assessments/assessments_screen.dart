import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';
import 'package:module_tracker/providers/grade_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/screens/module/module_form_screen.dart';
import 'package:module_tracker/widgets/hover_scale_widget.dart';
import 'package:module_tracker/widgets/module_selection_dialog.dart';

class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  String? _selectedSemesterId;

  @override
  void initState() {
    super.initState();
    // selectedSemesterId will be set from currentSemesterProvider in build
  }

  void _onSemesterChanged(String newSemesterId) {
    setState(() {
      _selectedSemesterId = newSemesterId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSemester = ref.watch(currentSemesterProvider);

    // Initialize selectedSemesterId to current semester if not set
    final selectedSemesterId = _selectedSemesterId ?? currentSemester?.id;

    final modulesAsync = selectedSemesterId != null
        ? ref.watch(modulesForSemesterProvider(selectedSemesterId))
        : ref.watch(currentSemesterModulesProvider);
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
            child: Column(
              children: [
                // Semester Overview Card
                if (selectedSemesterId != null)
                  _SemesterOverviewCard(
                    semesterId: selectedSemesterId,
                    onSemesterChanged: _onSemesterChanged,
                  ),
                const SizedBox(height: 16),
                // Module boxes
                Wrap(
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
              ],
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

class _SemesterOverviewCard extends ConsumerWidget {
  final String semesterId;
  final Function(String) onSemesterChanged;

  const _SemesterOverviewCard({
    required this.semesterId,
    required this.onSemesterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get all semesters and find the selected one
    final allSemestersAsync = ref.watch(semestersProvider);
    final currentSemester = ref.watch(currentSemesterProvider);

    // Use current semester providers (these watch the global current semester)
    // TODO: These should be family providers that accept semesterId
    final semesterAverage = ref.watch(semesterAverageProvider);
    final semesterContribution = ref.watch(semesterContributionProvider);
    final assessmentsCount = ref.watch(totalAssessmentsCountProvider);
    final (completedCount, totalCount) = assessmentsCount;

    // Get credits for this semester
    final creditsData = ref.watch(accountedCreditsProvider(semesterId));
    final (accountedCredits, totalCredits) = creditsData;

    return allSemestersAsync.when(
      data: (allSemesters) {
        // Find the selected semester
        final semester = allSemesters.where((s) => s.id == semesterId).firstOrNull;
        if (semester == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with dropdown
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 20,
                    color: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semester Overview - ${semester.name}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  // Dropdown button
                  allSemestersAsync.when(
                    data: (allSemesters) {
                      if (allSemesters.length <= 1) return const SizedBox.shrink();

                      return PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down, size: 24),
                        tooltip: 'Change semester',
                        onSelected: onSemesterChanged,
                        itemBuilder: (context) {
                          return allSemesters.map((s) {
                            final isSelected = s.id == semesterId;
                            final isCurrent = s.id == currentSemester?.id;

                            return PopupMenuItem<String>(
                              value: s.id,
                              child: Row(
                                children: [
                                  if (isSelected)
                                    const Icon(Icons.check, size: 20)
                                  else
                                    const SizedBox(width: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                        color: s.isArchived
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Current',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Semester',
                      value: '${semesterAverage.toStringAsFixed(1)}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      label: 'Total',
                      value: '${semesterContribution.toStringAsFixed(1)}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      label: 'Completion',
                      value: '$completedCount/$totalCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _StatBox(
                          label: 'Credits',
                          value: accountedCredits == totalCredits
                            ? '$totalCredits'
                            : '$accountedCredits/$totalCredits',
                          isIncomplete: accountedCredits != totalCredits,
                        ),
                        // Credits warning message
                        if (accountedCredits != totalCredits) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${totalCredits - accountedCredits} credits unaccounted for',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFEF4444),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, _) {
                        final overallGrade = ref.watch(currentSemesterOverallGradeProvider);

                        if (overallGrade == null) {
                          return const _StatBox(
                            label: 'Overall',
                            value: '-',
                          );
                        }

                        final (percentage, classification) = overallGrade;
                        return _StatBox(
                          label: 'Overall',
                          value: '${percentage.toStringAsFixed(1)}% (${classification.replaceAll(' Class', '').replaceAll('Upper Second ', '').replaceAll('Lower Second ', '')})',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatBox extends StatefulWidget {
  final String label;
  final String value;
  final bool isIncomplete;

  const _StatBox({
    required this.label,
    required this.value,
    this.isIncomplete = false,
  });

  @override
  State<_StatBox> createState() => _StatBoxState();
}

class _StatBoxState extends State<_StatBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(_StatBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getAnimatedValue() {
    // Try to parse numeric values for animation
    final currentValue = widget.value;

    // Check if value contains a percentage
    if (currentValue.contains('%')) {
      final numericPart = currentValue.replaceAll('%', '').trim();
      final targetNumber = double.tryParse(numericPart);
      if (targetNumber != null) {
        final animatedNumber = targetNumber * _animation.value;
        return '${animatedNumber.toStringAsFixed(1)}%';
      }
    }

    // Check if value is just a number
    final targetNumber = double.tryParse(currentValue);
    if (targetNumber != null) {
      final animatedNumber = targetNumber * _animation.value;
      return animatedNumber.toStringAsFixed(0);
    }

    // Check if value contains a fraction like "5/10"
    if (currentValue.contains('/')) {
      final parts = currentValue.split('/');
      if (parts.length == 2) {
        final completed = double.tryParse(parts[0].trim());
        final total = double.tryParse(parts[1].trim());
        if (completed != null && total != null) {
          final animatedCompleted = (completed * _animation.value).round();
          return '$animatedCompleted/$total';
        }
      }
    }

    // For complex values (like "68.0% (2:1)"), show without animation
    return currentValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Text(
              _getAnimatedValue(),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: widget.isIncomplete ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6),
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      ],
    );
  }
}

class _ModuleBox extends ConsumerWidget {
  final Module module;

  const _ModuleBox({required this.module});

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Module module) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Module'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete "${module.name}"?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All tasks, assessments, and grades will be permanently deleted.',
                        style: TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              final user = ref.read(currentUserProvider);
              if (user == null) return;

              final repository = ref.read(firestoreRepositoryProvider);

              try {
                await repository.deleteModule(user.uid, module.id);

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Module deleted successfully'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting module: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

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
                padding: const EdgeInsets.all(16),
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
                    // Module name row with menu
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                module.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              if (module.code.isNotEmpty || module.credits > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (module.code.isNotEmpty) module.code,
                                    if (module.credits > 0) '(${module.credits} credits)',
                                  ].join(' '),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Three dots menu with hover animation
                        Builder(
                          builder: (context) => UniversalInteractiveWidget(
                            style: InteractiveStyle.elastic,
                            onTap: () {
                              final RenderBox button = context.findRenderObject() as RenderBox;
                              final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                              final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

                              showMenu<String>(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  buttonPosition.dx - 80, // Move left 80px
                                  buttonPosition.dy + 30, // Move down 30px
                                  overlay.size.width - buttonPosition.dx - button.size.width + 80,
                                  overlay.size.height - buttonPosition.dy - button.size.height - 30,
                                ),
                                items: const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit Module'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share_rounded, size: 18, color: Color(0xFF0EA5E9)),
                                        SizedBox(width: 8),
                                        Text('Share Module'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                        SizedBox(width: 8),
                                        Text('Delete Module', style: TextStyle(color: Color(0xFFEF4444))),
                                      ],
                                    ),
                                  ),
                                ],
                              ).then((value) {
                                if (!context.mounted) return;

                                if (value == 'share') {
                                  // Show module selection dialog
                                  showDialog(
                                    context: context,
                                    builder: (context) => ModuleSelectionDialog(
                                      preSelectedModule: module,
                                      semesterId: module.semesterId,
                                    ),
                                  );
                                } else if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ModuleFormScreen(
                                        existingModule: module,
                                        semesterId: module.semesterId,
                                      ),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  _showDeleteDialog(context, ref, module);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.more_vert,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Progress Indicators
                    if (assessments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ModuleProgressIndicator(
                        assessments: assessments,
                        module: module,
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

class _ModuleProgressIndicator extends ConsumerStatefulWidget {
  final List<Assessment> assessments;
  final Module module;

  const _ModuleProgressIndicator({
    required this.assessments,
    required this.module,
  });

  @override
  ConsumerState<_ModuleProgressIndicator> createState() => _ModuleProgressIndicatorState();
}

class _ModuleProgressIndicatorState extends ConsumerState<_ModuleProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetGrade = ref.watch(userPreferencesProvider).targetGrade;
    final moduleGrade = ref.watch(moduleGradeProvider(widget.module.id));
    final completedCount = widget.assessments.where((a) => a.markEarned != null).length;
    final totalCount = widget.assessments.length;

    // Calculate current grade (weighted average of completed work)
    double currentGrade = 0.0;

    for (final assessment in widget.assessments) {
      if (assessment.markEarned != null) {
        currentGrade += (assessment.markEarned! / 100 * assessment.weighting);
      }
    }

    // Calculate grade still available
    final gradeAvailable = widget.assessments.fold<double>(0.0, (sum, a) {
      if (a.markEarned == null) {
        return sum + a.weighting;
      }
      return sum;
    });

    // Calculate max possible grade (current + remaining if get 100%)
    final maxGrade = currentGrade + gradeAvailable;

    // Calculate lost/unreachable percentage
    final totalWeight = widget.assessments.fold<double>(0.0, (sum, a) => sum + a.weighting);
    final lostPercentage = 100.0 - totalWeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current & Projected Grades (NEW)
        if (moduleGrade != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Current: ',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '${moduleGrade.currentGrade.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Projected: ${moduleGrade.projectedGrade.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Required average text
          if (moduleGrade.isAchievable && gradeAvailable > 0)
            Text(
              'Need ${moduleGrade.requiredAverage.toStringAsFixed(0)}% average on remaining to hit ${targetGrade.toStringAsFixed(0)}% target',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          const SizedBox(height: 12),
        ],
        // Multi-section progress bar with markers (animated)
        AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            final animatedCurrentGrade = currentGrade * _progressAnimation.value;
            final animatedGradeAvailable = gradeAvailable * _progressAnimation.value;
            final animatedLostPercentage = lostPercentage * _progressAnimation.value;

            return LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  height: 24,
                  child: Stack(
                    children: [
                      // Progress bar sections
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            // Current grade (green)
                            if (animatedCurrentGrade > 0)
                              Expanded(
                                flex: (animatedCurrentGrade * 100).toInt().clamp(1, 10000),
                                child: Container(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            // Max potential (light green)
                            if (animatedGradeAvailable > 0)
                              Expanded(
                                flex: (animatedGradeAvailable * 100).toInt().clamp(1, 10000),
                                child: Container(
                                  color: const Color(0xFF10B981).withOpacity(0.3),
                                ),
                              ),
                            // Lost/Unreachable (light grey)
                            if (animatedLostPercentage > 0 || _progressAnimation.value < 1.0)
                              Expanded(
                                flex: (animatedLostPercentage * 100).toInt().clamp(1, 10000) +
                                    ((currentGrade + gradeAvailable + lostPercentage - animatedCurrentGrade - animatedGradeAvailable - animatedLostPercentage) * 100).toInt().clamp(0, 10000),
                                child: Container(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                          ],
                        ),
                      ),
                  // Pass mark line at 40% with tooltip
                  Positioned(
                    left: constraints.maxWidth * 0.4,
                    top: 0,
                    bottom: 0,
                    child: Tooltip(
                      message: 'Pass Mark (40%)',
                      preferBelow: false,
                      child: GestureDetector(
                        onTap: () {
                          // Show snackbar on mobile tap
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pass Mark (40%)'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          width: 2,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                  // Target grade line with tooltip
                  Positioned(
                    left: constraints.maxWidth * (targetGrade / 100),
                    top: 0,
                    bottom: 0,
                    child: Tooltip(
                      message: 'Target (${targetGrade.toStringAsFixed(0)}%)',
                      preferBelow: false,
                      child: GestureDetector(
                        onTap: () {
                          // Show snackbar on mobile tap
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Target (${targetGrade.toStringAsFixed(0)}%)'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          width: 2,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        // Info boxes
        Row(
          children: [
            Expanded(
              child: _InfoBox(
                label: 'Completed',
                value: '$completedCount/$totalCount',
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _InfoBox(
                label: 'Progress',
                value: '${currentGrade.toStringAsFixed(0)}%',
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _InfoBox(
                label: 'Target',
                value: '${targetGrade.toStringAsFixed(0)}%',
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _InfoBox(
                label: 'Maximum',
                value: '${maxGrade.toStringAsFixed(0)}%',
                color: const Color(0xFF8B5CF6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoBox({
    required this.label,
    required this.value,
    required this.color,
  });

  IconData _getIcon() {
    switch (label) {
      case 'Completed':
        return Icons.task_alt;
      case 'Progress':
        return Icons.show_chart;
      case 'Target':
        return Icons.flag_outlined;
      case 'Maximum':
        return Icons.stars_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIcon(),
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PieChartSection extends StatefulWidget {
  final Module module;
  final List<Assessment> assessments;

  const _PieChartSection({
    required this.module,
    required this.assessments,
  });

  @override
  State<_PieChartSection> createState() => _PieChartSectionState();
}

class _PieChartSectionState extends State<_PieChartSection> with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animationController;
  late Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _radiusAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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

  void _handleTapDown(TapDownDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tapPosition = details.localPosition;

    // Calculate angle of tap
    final dx = tapPosition.dx - center.dx;
    final dy = tapPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2 * 0.85;

    // Check if tap is within pie chart
    if (distance > radius * 1.15) {
      // Tapped outside, clear selection
      _clearSelection();
      return;
    }

    double angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;

    // Adjust for starting at top
    angle = (angle + math.pi / 2) % (2 * math.pi);

    // Find which slice was tapped
    double currentAngle = 0;
    final totalWeighting = widget.assessments.fold<double>(0, (sum, a) => sum + a.weighting);
    final unaccountedPercentage = math.max(0.0, 100.0 - totalWeighting);

    for (int i = 0; i < widget.assessments.length; i++) {
      final assessment = widget.assessments[i];
      final sweepAngle = (assessment.weighting / 100) * 2 * math.pi;

      if (angle >= currentAngle && angle < currentAngle + sweepAngle) {
        setState(() {
          _selectedIndex = i;
        });
        _animationController.forward();
        return;
      }

      currentAngle += sweepAngle;
    }

    // Check unaccounted slice
    if (unaccountedPercentage > 0) {
      final sweepAngle = (unaccountedPercentage / 100) * 2 * math.pi;
      if (angle >= currentAngle && angle < currentAngle + sweepAngle) {
        // Tapped on unaccounted, clear selection
        _clearSelection();
      }
    }
  }

  void _clearSelection() {
    if (_selectedIndex != null) {
      setState(() {
        _selectedIndex = null;
      });
      _animationController.reverse();
    }
  }

  void _handleHover(PointerEvent event, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hoverPosition = event.localPosition;

    // Calculate angle of hover
    final dx = hoverPosition.dx - center.dx;
    final dy = hoverPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final radius = math.min(size.width, size.height) / 2 * 0.85;

    // Check if hover is within pie chart
    if (distance > radius * 1.15) {
      _clearSelection();
      return;
    }

    double angle = math.atan2(dy, dx);
    if (angle < 0) angle += 2 * math.pi;

    // Adjust for starting at top
    angle = (angle + math.pi / 2) % (2 * math.pi);

    // Find which slice is being hovered
    double currentAngle = 0;

    for (int i = 0; i < widget.assessments.length; i++) {
      final assessment = widget.assessments[i];
      final sweepAngle = (assessment.weighting / 100) * 2 * math.pi;

      if (angle >= currentAngle && angle < currentAngle + sweepAngle) {
        if (_selectedIndex != i) {
          setState(() {
            _selectedIndex = i;
          });
          _animationController.forward();
        }
        return;
      }

      currentAngle += sweepAngle;
    }

    // Hovering over unaccounted or nothing
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final totalWeighting = widget.assessments.fold<double>(0, (sum, a) => sum + a.weighting);
    final unaccountedPercentage = math.max(0.0, 100.0 - totalWeighting);
    final colors = _generateColors(widget.assessments.length);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit Breakdown',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          // Pie chart and legend side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pie chart on the left with tooltip overlay
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MouseRegion(
                      onHover: (event) => _handleHover(event, const Size(120, 120)),
                      onExit: (_) => _clearSelection(),
                      child: GestureDetector(
                        onTapDown: (details) => _handleTapDown(details, const Size(120, 120)),
                        onTapUp: (_) => _clearSelection(),
                        onTapCancel: () => _clearSelection(),
                        child: AnimatedBuilder(
                          animation: _radiusAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: _PieChartPainter(
                                assessments: widget.assessments,
                                colors: colors,
                                unaccountedPercentage: unaccountedPercentage,
                                selectedIndex: _selectedIndex,
                                radiusMultiplier: _radiusAnimation.value,
                              ),
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Legend on the right
              Expanded(
                child: Column(
                  children: [
                    ...widget.assessments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final assessment = entry.value;
                      final typeString = assessment.type.toString().split('.').last[0].toUpperCase() +
                          assessment.type.toString().split('.').last.substring(1);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Tooltip(
                          message: typeString,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                margin: const EdgeInsets.only(top: 2),
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
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (unaccountedPercentage > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(top: 2),
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
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
    // Sort assessments by due date (upcoming first, then completed)
    final sortedAssessments = [...assessments]..sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1; // TBC items go to end
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedAssessments.map((assessment) {
          return _AssessmentCard(
            assessment: assessment,
            module: module,
          );
        }).toList(),
      ),
    );
  }
}

class _AssessmentCard extends ConsumerStatefulWidget {
  final Assessment assessment;
  final Module module;

  const _AssessmentCard({
    required this.assessment,
    required this.module,
  });

  @override
  ConsumerState<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends ConsumerState<_AssessmentCard> with TickerProviderStateMixin {
  bool _isEditingDescription = false;
  bool _hasValidationError = false;
  late TextEditingController _gradeController;
  late TextEditingController _descriptionController;
  late AnimationController _successFlashController;
  late Animation<Color?> _successFlashAnimation;

  @override
  void initState() {
    super.initState();
    _gradeController = TextEditingController(
      text: widget.assessment.markEarned?.toStringAsFixed(1) ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.assessment.description ?? '',
    );

    // Success flash animation for grade save
    _successFlashController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successFlashAnimation = ColorTween(
      begin: Colors.white,
      end: const Color(0xFF10B981).withOpacity(0.2),
    ).animate(CurvedAnimation(
      parent: _successFlashController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _descriptionController.dispose();
    _successFlashController.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    final gradeText = _gradeController.text.trim();
    final grade = gradeText.isEmpty ? null : double.tryParse(gradeText);

    // Validation: Invalid input
    if (gradeText.isNotEmpty && grade == null) {
      setState(() {
        _hasValidationError = true;
      });
      return;
    }

    // Validation: Out of range
    if (grade != null && (grade < 0 || grade > 100)) {
      setState(() {
        _hasValidationError = true;
      });
      return;
    }

    // Clear validation error
    if (_hasValidationError) {
      setState(() {
        _hasValidationError = false;
      });
    }

    // Save the grade (status is controlled by buttons now)
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final repository = ref.read(firestoreRepositoryProvider);

      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        widget.assessment.copyWith(
          markEarned: grade,
        ).toFirestore(),
      );

      if (mounted) {
        // Trigger success flash animation
        _successFlashController.forward().then((_) {
          _successFlashController.reverse();
        });
      }
    }
  }

  Future<void> _saveDescription() async {
    final description = _descriptionController.text.trim();
    final user = ref.read(currentUserProvider);

    if (user != null) {
      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        widget.assessment.copyWith(description: description.isEmpty ? null : description).toFirestore(),
      );

      if (mounted) {
        setState(() {
          _isEditingDescription = false;
        });
      }
    }
  }

  Future<void> _updateStatus(AssessmentStatus newStatus) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repository = ref.read(firestoreRepositoryProvider);

    await repository.updateAssessment(
      user.uid,
      widget.module.semesterId,
      widget.module.id,
      widget.assessment.id,
      widget.assessment.copyWith(status: newStatus).toFirestore(),
    );
  }

  Color _getTypeBadgeColor() {
    switch (widget.assessment.type) {
      case AssessmentType.coursework:
        return const Color(0xFF8B5CF6); // Purple
      case AssessmentType.exam:
        return const Color(0xFFEF4444); // Red
      case AssessmentType.weekly:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  String _getTypeName() {
    switch (widget.assessment.type) {
      case AssessmentType.coursework:
        return 'Coursework';
      case AssessmentType.exam:
        return 'Exam';
      case AssessmentType.weekly:
        return 'Weekly';
    }
  }

  Color _getStatusColor() {
    switch (widget.assessment.status) {
      case AssessmentStatus.notStarted:
        return const Color(0xFFEF4444); // Red
      case AssessmentStatus.working:
        return const Color(0xFFF59E0B); // Yellow/Amber
      case AssessmentStatus.submitted:
        return const Color(0xFF3B82F6); // Blue
      case AssessmentStatus.graded:
        return const Color(0xFF10B981); // Green
    }
  }

  String _getStatusName() {
    switch (widget.assessment.status) {
      case AssessmentStatus.notStarted:
        return 'Not Started';
      case AssessmentStatus.working:
        return 'Working';
      case AssessmentStatus.submitted:
        return 'Submitted';
      case AssessmentStatus.graded:
        return 'Graded';
    }
  }


  @override
  Widget build(BuildContext context) {
    final typeBadgeColor = _getTypeBadgeColor();
    final typeName = _getTypeName();

    return AnimatedBuilder(
      animation: _successFlashAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _successFlashAnimation.value ?? Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Name + Weighting + Type badge + Status badge + Grade
                Row(
                  children: [
                    // Name and weighting
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: widget.assessment.name,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text: ' • ${widget.assessment.weighting.toStringAsFixed(0)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeBadgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: typeBadgeColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        typeName,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeBadgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status badge (no emoji)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor().withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getStatusColor().withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getStatusName(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(),
                        ),
                      ),
                    ),
                    // Grade display (right side)
                    if (widget.assessment.markEarned != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${widget.assessment.markEarned!.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ],
                ),
                // Divider
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 12),
                // Description section with edit button
                Row(
                  children: [
                    Text(
                      'Description',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    UniversalInteractiveWidget(
                      style: InteractiveStyle.elastic,
                      onTap: () {
                        setState(() {
                          _isEditingDescription = !_isEditingDescription;
                        });
                      },
                      child: Icon(
                        _isEditingDescription ? Icons.close : Icons.edit_outlined,
                        size: 16,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Description box or editor
                if (_isEditingDescription) ...[
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a description...',
                      isDense: true,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditingDescription = false;
                            _descriptionController.text = widget.assessment.description ?? '';
                          });
                        },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveDescription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.assessment.description?.isNotEmpty == true
                          ? widget.assessment.description!
                          : 'No description provided',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: widget.assessment.description?.isNotEmpty == true
                            ? const Color(0xFF64748B)
                            : Colors.grey[400],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                // Divider
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey[300]),
                const SizedBox(height: 12),
                // Progress section
                Text(
                  'Progress',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                // 4 status buttons (all on one line)
                Row(
                  children: [
                    Expanded(
                      child: _StatusButton(
                        label: 'Not Started',
                        status: AssessmentStatus.notStarted,
                        isSelected: widget.assessment.status == AssessmentStatus.notStarted,
                        onTap: () => _updateStatus(AssessmentStatus.notStarted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatusButton(
                        label: 'Working',
                        status: AssessmentStatus.working,
                        isSelected: widget.assessment.status == AssessmentStatus.working,
                        onTap: () => _updateStatus(AssessmentStatus.working),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatusButton(
                        label: 'Submitted',
                        status: AssessmentStatus.submitted,
                        isSelected: widget.assessment.status == AssessmentStatus.submitted,
                        onTap: () => _updateStatus(AssessmentStatus.submitted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _StatusButton(
                        label: 'Graded',
                        status: AssessmentStatus.graded,
                        isSelected: widget.assessment.status == AssessmentStatus.graded,
                        onTap: () => _updateStatus(AssessmentStatus.graded),
                      ),
                    ),
                  ],
                ),
                // Conditional grade input (appears when Graded is selected)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: widget.assessment.status == AssessmentStatus.graded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  'Grade',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _gradeController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0-100',
                                      suffixText: '%',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: _hasValidationError ? Colors.red : Colors.grey[300]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: _hasValidationError ? Colors.red : Colors.grey[300]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: _hasValidationError ? Colors.red : const Color(0xFF0EA5E9),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    style: GoogleFonts.inter(fontSize: 13),
                                    onSubmitted: (_) {
                                      _saveGrade();
                                      FocusScope.of(context).unfocus();
                                    },
                                    onEditingComplete: () {
                                      _saveGrade();
                                      FocusScope.of(context).unfocus();
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_hasValidationError) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Please enter a valid grade between 0 and 100',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final AssessmentStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (status) {
      case AssessmentStatus.notStarted:
        return const Color(0xFFEF4444); // Red
      case AssessmentStatus.working:
        return const Color(0xFFF59E0B); // Yellow/Amber
      case AssessmentStatus.submitted:
        return const Color(0xFF3B82F6); // Blue
      case AssessmentStatus.graded:
        return const Color(0xFF10B981); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? statusColor
              : statusColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: statusColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : statusColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  final int? selectedIndex;
  final double radiusMultiplier;

  _PieChartPainter({
    required this.assessments,
    required this.colors,
    required this.unaccountedPercentage,
    this.selectedIndex,
    this.radiusMultiplier = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2 * 0.85;

    double startAngle = -math.pi / 2; // Start from top

    // Draw each assessment slice
    for (int i = 0; i < assessments.length; i++) {
      final assessment = assessments[i];
      final sweepAngle = (assessment.weighting / 100) * 2 * math.pi;

      // Determine color and radius for this slice
      final isSelected = selectedIndex == i;
      Color sliceColor = colors[i];
      double sliceRadius = baseRadius;

      if (isSelected) {
        // Lighten the color by mixing with white
        sliceColor = Color.lerp(colors[i], Colors.white, 0.3)!;
        // Increase radius by multiplier (1.0 to 1.15)
        sliceRadius = baseRadius * radiusMultiplier;
      }

      final paint = Paint()
        ..color = sliceColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: sliceRadius),
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
        Rect.fromCircle(center: center, radius: baseRadius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
    }

    // Draw white borders between slices
    startAngle = -math.pi / 2;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (int i = 0; i < assessments.length; i++) {
      final assessment = assessments[i];
      final sweepAngle = (assessment.weighting / 100) * 2 * math.pi;
      final isSelected = selectedIndex == i;
      double sliceRadius = baseRadius;

      if (isSelected) {
        sliceRadius = baseRadius * radiusMultiplier;
      }

      // Draw border line at start of slice
      final lineEnd = Offset(
        center.dx + math.cos(startAngle) * sliceRadius,
        center.dy + math.sin(startAngle) * sliceRadius,
      );
      canvas.drawLine(center, lineEnd, borderPaint);

      startAngle += sweepAngle;
    }

    // Draw final border line
    if (assessments.isNotEmpty) {
      // Check if last slice is selected
      final isLastSelected = selectedIndex == assessments.length - 1;
      double sliceRadius = baseRadius;
      if (isLastSelected) {
        sliceRadius = baseRadius * radiusMultiplier;
      }

      final lineEnd = Offset(
        center.dx + math.cos(startAngle) * sliceRadius,
        center.dy + math.sin(startAngle) * sliceRadius,
      );
      canvas.drawLine(center, lineEnd, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.radiusMultiplier != radiusMultiplier;
  }
}
