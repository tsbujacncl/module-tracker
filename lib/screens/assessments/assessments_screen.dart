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
                    if (module.code.isNotEmpty || module.credits > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (module.code.isNotEmpty) module.code,
                          if (module.credits > 0) '(${module.credits} credits)',
                        ].join(' '),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    // Progress Indicators
                    if (assessments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ModuleProgressIndicator(assessments: assessments),
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

class _ModuleProgressIndicator extends ConsumerWidget {
  final List<Assessment> assessments;

  const _ModuleProgressIndicator({required this.assessments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetGrade = ref.watch(userPreferencesProvider).targetGrade;
    final completedCount = assessments.where((a) => a.markEarned != null).length;
    final totalCount = assessments.length;

    // Calculate current grade (weighted average of completed work)
    double currentGrade = 0.0;

    for (final assessment in assessments) {
      if (assessment.markEarned != null) {
        currentGrade += (assessment.markEarned! / 100 * assessment.weighting);
      }
    }

    // Calculate grade still available
    final gradeAvailable = assessments.fold<double>(0.0, (sum, a) {
      if (a.markEarned == null) {
        return sum + a.weighting;
      }
      return sum;
    });

    // Calculate max possible grade (current + remaining if get 100%)
    final maxGrade = currentGrade + gradeAvailable;

    // Calculate lost/unreachable percentage
    final totalWeight = assessments.fold<double>(0.0, (sum, a) => sum + a.weighting);
    final lostPercentage = 100.0 - totalWeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-section progress bar with markers
        LayoutBuilder(
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
                        if (currentGrade > 0)
                          Expanded(
                            flex: (currentGrade * 100).toInt(),
                            child: Container(
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        // Max potential (light green)
                        if (gradeAvailable > 0)
                          Expanded(
                            flex: (gradeAvailable * 100).toInt(),
                            child: Container(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                            ),
                          ),
                        // Lost/Unreachable (light grey)
                        if (lostPercentage > 0)
                          Expanded(
                            flex: (lostPercentage * 100).toInt(),
                            child: Container(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Pass mark line at 40%
                  Positioned(
                    left: constraints.maxWidth * 0.4,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  // Target grade line (customizable)
                  Positioned(
                    left: constraints.maxWidth * (targetGrade / 100),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.all(16),
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

class _AssessmentCardState extends ConsumerState<_AssessmentCard> {
  bool _showGradeInput = false;
  late TextEditingController _gradeController;

  @override
  void initState() {
    super.initState();
    _gradeController = TextEditingController(
      text: widget.assessment.markEarned?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _saveGrade() async {
    final gradeText = _gradeController.text.trim();
    final grade = gradeText.isEmpty ? null : double.tryParse(gradeText);

    // Validation: Out of range
    if (grade != null && (grade < 0 || grade > 100)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Grade must be between 0 and 100'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for unusual grades and show confirmation
    if (grade != null) {
      String? warningMessage;

      if (grade > 100) {
        warningMessage = 'Grade is over 100%. Are you sure this is correct?';
      } else if (grade < 30) {
        warningMessage = 'This is a very low grade (${grade.toStringAsFixed(1)}%). Confirm?';
      } else if (grade == 100) {
        warningMessage = 'Perfect score! Confirm 100%?';
      } else if (widget.assessment.markEarned != null) {
        warningMessage = 'Replace existing grade (${widget.assessment.markEarned!.toStringAsFixed(1)}%) with ${grade.toStringAsFixed(1)}%?';
      }

      if (warningMessage != null && mounted) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Confirm Grade',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                warningMessage!,
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );

        if (confirmed != true) return;
      }
    }

    // Save the grade
    final user = ref.read(currentUserProvider);
    if (user != null) {
      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        widget.assessment.copyWith(markEarned: grade).toFirestore(),
      );

      if (mounted) {
        setState(() {
          _showGradeInput = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(grade == null ? 'Grade removed' : 'Grade saved: ${grade.toStringAsFixed(1)}%'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _markAsComplete() async {
    final now = DateTime.now();
    final user = ref.read(currentUserProvider);

    if (user != null) {
      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        widget.assessment.copyWith(dueDate: now).toFirestore(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as complete'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _markAsIncomplete() async {
    final user = ref.read(currentUserProvider);

    if (user != null) {
      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        widget.assessment.copyWith(dueDate: null).toFirestore(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as incomplete'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.assessment.dueDate != null &&
                        !widget.assessment.dueDate!.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment name with percentage - large and bold
            Text(
              '${widget.assessment.name} (${widget.assessment.weighting.toStringAsFixed(0)}%)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            // Divider
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 16),
            // Description section
            Text(
              'Description',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
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
                  fontSize: 13,
                  color: widget.assessment.description?.isNotEmpty == true
                      ? const Color(0xFF64748B)
                      : Colors.grey[400],
                  height: 1.5,
                ),
              ),
            ),
            // Divider
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 16),
            // Progress section
            Text(
              'Progress',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Completed text on left
                Text(
                  'Completed',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                // Checkbox
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isCompleted,
                    onChanged: (value) async {
                      if (value == true) {
                        await _markAsComplete();
                      } else {
                        await _markAsIncomplete();
                      }
                    },
                    activeColor: const Color(0xFF10B981),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 24),
                // Grade text
                Text(
                  'Grade',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                // Grade display/input
                if (_showGradeInput) ...[
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _gradeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0-100',
                        suffixText: '%',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _saveGrade,
                    icon: const Icon(Icons.check, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showGradeInput = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(28, 28),
                    ),
                  ),
                ] else ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showGradeInput = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.assessment.markEarned != null
                            ? const Color(0xFF10B981).withOpacity(0.15)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.assessment.markEarned != null
                              ? const Color(0xFF10B981).withOpacity(0.3)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Text(
                        widget.assessment.markEarned != null
                            ? '${widget.assessment.markEarned!.toStringAsFixed(1)}%'
                            : 'Pending',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.assessment.markEarned != null
                              ? const Color(0xFF10B981)
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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
