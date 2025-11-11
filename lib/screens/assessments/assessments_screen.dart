import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:module_tracker/widgets/module_card.dart';
import 'package:module_tracker/services/app_logger.dart';

class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  String? _selectedSemesterId;

  // Track pending changes: assessmentId → {moduleId, semesterId, changes}
  final Map<String, Map<String, dynamic>> _pendingChanges = {};

  // Track if save is in progress
  bool _isSaving = false;

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

  // Check if there are any pending changes
  bool get _hasPendingChanges => _pendingChanges.isNotEmpty;

  // Add/update pending change
  void _addPendingChange(
    String assessmentId,
    String moduleId,
    String semesterId,
    Map<String, dynamic> changes,
  ) {
    setState(() {
      _pendingChanges[assessmentId] = {
        'moduleId': moduleId,
        'semesterId': semesterId,
        'changes': changes,
      };
    });
  }

  // Clear all pending changes
  void _clearPendingChanges() {
    setState(() => _pendingChanges.clear());
  }

  // Save all pending changes
  Future<void> _saveAllChanges() async {
    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('User not logged in');

      final repository = ref.read(firestoreRepositoryProvider);

      // Save all pending changes
      for (final entry in _pendingChanges.entries) {
        final assessmentId = entry.key;
        final data = entry.value;
        final moduleId = data['moduleId'] as String;
        final semesterId = data['semesterId'] as String;
        final changes = data['changes'] as Map<String, dynamic>;

        await repository.updateAssessment(
          user.uid,
          semesterId,
          moduleId,
          assessmentId,
          changes,
        );
      }

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Changes saved successfully'),
            backgroundColor: Color(0xFF10B981), // Green
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Clear pending changes
      _clearPendingChanges();
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: const Color(0xFFEF4444), // Red
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Show confirmation dialog for unsaved changes
  Future<bool?> _showUnsavedChangesDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Unsaved Changes',
          style: GoogleFonts.poppins(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'You have unsaved changes. What would you like to do?',
          style: GoogleFonts.inter(color: const Color(0xFF0F172A)),
        ),
        actions: [
          // Cancel - stay on page
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Go Back',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ),

          // Discard - exit without saving
          TextButton(
            onPressed: () {
              _clearPendingChanges();
              Navigator.of(context).pop(true);
            },
            child: Text(
              'Discard',
              style: GoogleFonts.inter(color: const Color(0xFFEF4444)), // Red
            ),
          ),

          // Save - save then exit
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop(false); // Close dialog first
              await _saveAllChanges();
              if (context.mounted && !_hasPendingChanges) {
                Navigator.of(context).pop(); // Exit screen
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6), // Blue
            ),
            child: Text(
              'Save Changes',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Get responsive horizontal padding for smooth margin scaling
  /// Mobile (<600px): 8px each side
  /// Tablet (600-900px): smoothly 8px → 32px
  /// Desktop (900-1200px): smoothly 32px → 60px
  /// Large Desktop (>1200px): smoothly 60px → 100px
  double _getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) {
      return 8.0;
    } else if (width < 900) {
      // Smooth interpolation from 8 to 32 between 600-900px
      final progress = (width - 600) / 300; // 0.0 to 1.0
      return 8.0 + (24.0 * progress); // 8 + 24 = 32
    } else if (width < 1200) {
      // Smooth interpolation from 32 to 60 between 900-1200px
      final progress = (width - 900) / 300; // 0.0 to 1.0
      return 32.0 + (28.0 * progress); // 32 + 28 = 60
    } else {
      // Smooth interpolation from 60 to 100 for screens >1200px
      final progress = ((width - 1200) / 400).clamp(
        0.0,
        1.0,
      ); // Capped at 1600px
      return 60.0 + (40.0 * progress); // 60 + 40 = 100
    }
  }

  // Show archive dialog to select past semesters
  Future<void> _showArchiveDialog(BuildContext context, List<dynamic> semesters) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Select Semester',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: semesters.map((semester) {
              final isCurrent = semester.id == _selectedSemesterId;
              return ListTile(
                title: Text(
                  semester.name,
                  style: GoogleFonts.inter(
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: semester.isArchived
                    ? Text(
                        'Archived',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      )
                    : null,
                leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.folder_outlined,
                  color: isCurrent ? const Color(0xFF10B981) : const Color(0xFF64748B),
                ),
                selected: isCurrent,
                onTap: () => Navigator.pop(context, semester.id),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null && result != _selectedSemesterId) {
      _onSemesterChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSemester = ref.watch(currentSemesterProvider);
    final allSemestersAsync = ref.watch(semestersProvider);

    // Initialize selectedSemesterId to current semester if not set
    final selectedSemesterId = _selectedSemesterId ?? currentSemester?.id;

    final modulesAsync = selectedSemesterId != null
        ? ref.watch(modulesForSemesterProvider(selectedSemesterId))
        : ref.watch(currentSemesterModulesProvider);
    final horizontalPadding = _getHorizontalPadding(context);

    return PopScope(
      canPop: !_hasPendingChanges, // Allow pop only if no pending changes
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return; // Already popped, nothing to do

        // Show confirmation dialog
        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const GradientHeader(title: 'Assignments')),
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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Semester Overview Box
                  if (selectedSemesterId != null)
                    allSemestersAsync.when(
                      data: (allSemesters) {
                        // Find the selected semester
                        final semester = allSemesters
                            .where((s) => s.id == selectedSemesterId)
                            .firstOrNull;
                        if (semester == null) return const SizedBox.shrink();

                        // Get overall grade
                        final overallGradeData = ref.watch(
                          semesterOverallGradeProvider(selectedSemesterId),
                        );
                        final overallGrade = overallGradeData?.$1;

                        // Get credits
                        final creditsData = ref.watch(
                          accountedCreditsProvider(selectedSemesterId),
                        );
                        final (_, totalCredits) = creditsData;

                        // Get assignment completion
                        final assessmentsCount = ref.watch(
                          semesterAssessmentsCountProvider(selectedSemesterId),
                        );
                        final (completedCount, totalCount) = assessmentsCount;

                        // Build full-width Semester Overview box
                        const targetGrade = 70.0; // Default target grade

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
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row: Title + Dropdown
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Semester Overview',
                                          style: GoogleFonts.poppins(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          semester.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Archive button
                                  if (allSemestersAsync.hasValue &&
                                      allSemestersAsync.value!.length > 1)
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _showArchiveDialog(context, allSemestersAsync.value!);
                                      },
                                      icon: const Icon(Icons.folder_outlined, size: 18),
                                      label: const Text('Archive'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF64748B),
                                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Divider
                              const Divider(
                                height: 1,
                                color: Color(0xFFE2E8F0),
                              ),
                              const SizedBox(height: 16),
                              // Stats line with bullets
                              Text(
                                [
                                  if (totalCredits > 0) '$totalCredits credits',
                                  '$completedCount of $totalCount assignments completed',
                                  if (overallGrade != null)
                                    'Overall: ${overallGrade.toStringAsFixed(1)}%'
                                  else
                                    'Overall: No grades yet',
                                ].join(' • '),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Progress bar (only show if we have a grade)
                              if (overallGrade != null)
                                _buildProgressBar(
                                  currentGrade: overallGrade,
                                  targetGrade: targetGrade,
                                ),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  const SizedBox(height: 16),
                  // Module boxes (vertical stack)
                  ...sortedModules.map((module) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ModuleBox(
                        module: module,
                        onPendingChange: _addPendingChange,
                        pendingChanges: _pendingChanges,
                      ),
                    );
                  }),
                  // Save button (centered like Edit Module)
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: 300,
                      child: FilledButton(
                        onPressed: (_isSaving || !_hasPendingChanges)
                            ? null
                            : _saveAllChanges,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _hasPendingChanges
                                    ? 'Save Changes'
                                    : 'No Changes',
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  // Build progress bar widget for semester overview
  Widget _buildProgressBar({
    required double currentGrade,
    required double targetGrade,
  }) {
    // Calculate fill percentage
    final fillPercentage = (currentGrade / 100).clamp(0.0, 1.0);
    final targetPercentage = (targetGrade / 100).clamp(0.0, 1.0);

    return Column(
      children: [
        // Current and Target labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Current: ${currentGrade.toStringAsFixed(1)}%',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            Text(
              'Target: ${targetGrade.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar with grey bg, green fill, and blue target line
        SizedBox(
          height: 8,
          child: Stack(
            children: [
              // Background (grey)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Filled portion (green)
              FractionallySizedBox(
                widthFactor: fillPercentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981), // Green
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Target line (thin blue vertical line)
              Positioned(
                left: targetPercentage * MediaQuery.of(context).size.width * 0.9,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: const Color(0xFF3B82F6), // Blue
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleBox extends ConsumerWidget {
  final Module module;
  final void Function(String, String, String, Map<String, dynamic>)?
  onPendingChange;
  final Map<String, Map<String, dynamic>> pendingChanges;

  const _ModuleBox({
    required this.module,
    this.onPendingChange,
    this.pendingChanges = const {},
  });

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
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All tasks, assessments, and grades will be permanently deleted.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFEF4444),
                        ),
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
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
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
            mainAxisSize: MainAxisSize.min,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Module info
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  module.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Weighting validation badge
                              Builder(
                                builder: (context) {
                                  final totalWeighting = assessments
                                      .fold<double>(
                                        0.0,
                                        (sum, a) => sum + a.weighting,
                                      );
                                  final isComplete = totalWeighting == 100.0;
                                  final badgeColor = isComplete
                                      ? const Color(0xFF10B981) // Green
                                      : const Color(0xFFF59E0B); // Orange

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: badgeColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isComplete)
                                          Icon(
                                            Icons.check,
                                            size: 10,
                                            color: badgeColor,
                                          )
                                        else
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            size: 10,
                                            color: badgeColor,
                                          ),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${totalWeighting.toStringAsFixed(0)}%',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (module.code.isNotEmpty || module.credits > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (module.code.isNotEmpty) module.code,
                                if (module.credits > 0)
                                  '(${module.credits} credits)',
                              ].join(' '),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right side: Stats (will be added by _ModuleProgressIndicator)
                    if (assessments.isNotEmpty)
                      Expanded(
                        flex: 6,
                        child: _ModuleProgressIndicator(
                          assessments: assessments,
                          module: module,
                          isCompact: true,
                        ),
                      ),
                    // Three dots menu with hover animation
                    Builder(
                      builder: (context) {
                        // Fetch semester for this module
                        final semestersAsync = ref.watch(semestersProvider);
                        final moduleSemester = semestersAsync.maybeWhen(
                          data: (semesters) => semesters
                              .where((s) => s.id == module.semesterId)
                              .firstOrNull,
                          orElse: () => null,
                        );

                        return UniversalInteractiveWidget(
                          style: InteractiveStyle.elastic,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => ModuleActionsDialog(
                                module: module,
                                semester: moduleSemester,
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ModuleFormScreen(
                                        existingModule: module,
                                        semesterId: module.semesterId,
                                      ),
                                    ),
                                  );
                                },
                                onShare: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => ModuleSelectionDialog(
                                      preSelectedModule: module,
                                      semesterId: module.semesterId,
                                    ),
                                  );
                                },
                                onDelete: () {
                                  _showDeleteDialog(context, ref, module);
                                },
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Divider between header and content
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 4),
              // Content
              if (assessments.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
              else
                _AssessmentsList(
                  module: module,
                  assessments: assessments,
                  onPendingChange: onPendingChange,
                  pendingChanges: pendingChanges,
                ),
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
  final bool isCompact;

  const _ModuleProgressIndicator({
    required this.assessments,
    required this.module,
    this.isCompact = false,
  });

  @override
  ConsumerState<_ModuleProgressIndicator> createState() =>
      _ModuleProgressIndicatorState();
}

class _ModuleProgressIndicatorState
    extends ConsumerState<_ModuleProgressIndicator>
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
    final completedCount = widget.assessments
        .where((a) => a.markEarned != null)
        .length;
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

    // Calculate lost/unreachable percentage
    final totalWeight = widget.assessments.fold<double>(
      0.0,
      (sum, a) => sum + a.weighting,
    );
    final lostPercentage = 100.0 - totalWeight;

    // Compact mode for side-by-side layout
    if (widget.isCompact && moduleGrade != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Line 1: Grade percentage
          Text(
            'Grade: ${moduleGrade.currentGrade.toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          // Line 2: Progress bar with target marker
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              final animatedCurrentGrade =
                  currentGrade * _progressAnimation.value;
              final animatedGradeAvailable =
                  gradeAvailable * _progressAnimation.value;
              final animatedLostPercentage =
                  lostPercentage * _progressAnimation.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: 16,
                        child: Stack(
                          children: [
                            // Progress bar background
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                children: [
                                  if (animatedCurrentGrade > 0)
                                    Expanded(
                                      flex: (animatedCurrentGrade * 100)
                                          .toInt()
                                          .clamp(1, 10000),
                                      child: Container(
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  if (animatedGradeAvailable > 0)
                                    Expanded(
                                      flex: (animatedGradeAvailable * 100)
                                          .toInt()
                                          .clamp(1, 10000),
                                      child: Container(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                  if (animatedLostPercentage > 0 ||
                                      _progressAnimation.value < 1.0)
                                    Expanded(
                                      flex:
                                          (animatedLostPercentage * 100)
                                              .toInt()
                                              .clamp(1, 10000) +
                                          ((currentGrade +
                                                      gradeAvailable +
                                                      lostPercentage -
                                                      animatedCurrentGrade -
                                                      animatedGradeAvailable -
                                                      animatedLostPercentage) *
                                                  100)
                                              .toInt()
                                              .clamp(0, 10000),
                                      child: Container(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Target marker line
                            Positioned(
                              left: constraints.maxWidth * (targetGrade / 100),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0EA5E9,
                                      ).withOpacity(0.4),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target: ${targetGrade.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      );
    }

    // Full mode (original layout)
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
            final animatedCurrentGrade =
                currentGrade * _progressAnimation.value;
            final animatedGradeAvailable =
                gradeAvailable * _progressAnimation.value;
            final animatedLostPercentage =
                lostPercentage * _progressAnimation.value;

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
                                flex: (animatedCurrentGrade * 100)
                                    .toInt()
                                    .clamp(1, 10000),
                                child: Container(
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            // Max potential (light grey)
                            if (animatedGradeAvailable > 0)
                              Expanded(
                                flex: (animatedGradeAvailable * 100)
                                    .toInt()
                                    .clamp(1, 10000),
                                child: Container(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                            // Lost/Unreachable (light grey)
                            if (animatedLostPercentage > 0 ||
                                _progressAnimation.value < 1.0)
                              Expanded(
                                flex:
                                    (animatedLostPercentage * 100)
                                        .toInt()
                                        .clamp(1, 10000) +
                                    ((currentGrade +
                                                gradeAvailable +
                                                lostPercentage -
                                                animatedCurrentGrade -
                                                animatedGradeAvailable -
                                                animatedLostPercentage) *
                                            100)
                                        .toInt()
                                        .clamp(0, 10000),
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
                          message:
                              'Target (${targetGrade.toStringAsFixed(0)}%)',
                          preferBelow: false,
                          child: GestureDetector(
                            onTap: () {
                              // Show snackbar on mobile tap
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Target (${targetGrade.toStringAsFixed(0)}%)',
                                  ),
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
        const SizedBox(height: 8),
        // Completion and Target info
        Row(
          children: [
            Text(
              '$completedCount/$totalCount complete',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '•',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Target: ${targetGrade.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AssessmentsList extends ConsumerWidget {
  final Module module;
  final List<Assessment> assessments;
  final void Function(String, String, String, Map<String, dynamic>)?
  onPendingChange;
  final Map<String, Map<String, dynamic>> pendingChanges;

  const _AssessmentsList({
    required this.module,
    required this.assessments,
    this.onPendingChange,
    this.pendingChanges = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sort assessments by due date (upcoming first, then completed)
    final sortedAssessments = [...assessments]
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1; // TBC items go to end
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sortedAssessments.map((assessment) {
          return _AssessmentCard(
            assessment: assessment,
            module: module,
            onPendingChange: onPendingChange,
            pendingChanges: pendingChanges,
          );
        }).toList(),
      ),
    );
  }
}

class _AssessmentCard extends ConsumerStatefulWidget {
  final Assessment assessment;
  final Module module;
  final void Function(String, String, String, Map<String, dynamic>)?
  onPendingChange;
  final Map<String, Map<String, dynamic>> pendingChanges;

  const _AssessmentCard({
    required this.assessment,
    required this.module,
    this.onPendingChange,
    this.pendingChanges = const {},
  });

  @override
  ConsumerState<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends ConsumerState<_AssessmentCard>
    with TickerProviderStateMixin {
  bool _hasValidationError = false;
  late TextEditingController _gradeController;
  late TextEditingController _descriptionController;
  late AnimationController _successFlashController;
  late Animation<Color?> _successFlashAnimation;

  // Local state to track pending changes
  late AssessmentStatus _localStatus;
  late AssessmentPriority _localPriority;
  late double? _localMarkEarned;
  late String? _localDescription;

  @override
  void initState() {
    super.initState();

    // Initialize local state from assessment
    _localStatus = widget.assessment.status;
    _localPriority = widget.assessment.priority;
    _localMarkEarned = widget.assessment.markEarned;
    _localDescription = widget.assessment.description;

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
    _successFlashAnimation =
        ColorTween(
          begin: Colors.white,
          end: const Color(0xFF10B981).withOpacity(0.2),
        ).animate(
          CurvedAnimation(
            parent: _successFlashController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _descriptionController.dispose();
    _successFlashController.dispose();
    super.dispose();
  }

  // Notify parent of pending changes
  void _notifyPendingChange() {
    if (widget.onPendingChange == null) return;

    // Build the changes map with only changed fields
    // NOTE: Status and markEarned are saved immediately, not tracked as pending
    final changes = <String, dynamic>{};

    if (_localPriority != widget.assessment.priority) {
      changes['priority'] = _localPriority.index;
    }

    if (_localDescription != widget.assessment.description) {
      changes['description'] = _localDescription;
    }

    // Notify parent if there are changes
    if (changes.isNotEmpty) {
      widget.onPendingChange!(
        widget.assessment.id,
        widget.module.id,
        widget.module.semesterId,
        widget.assessment
            .copyWith(priority: _localPriority, description: _localDescription)
            .toFirestore(),
      );
    }
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

    // Update local state
    setState(() {
      _localMarkEarned = grade;
    });

    // Save directly to Firestore for immediate grade updates
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        {'markEarned': grade},
      );

      // Trigger success animation
      _successFlashController.forward(from: 0);
    } catch (e) {
      AppLogger.error('Error saving grade', error: e);
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save grade: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDescription() async {
    final description = _descriptionController.text.trim();

    // Update local state and notify parent
    setState(() {
      _localDescription = description.isEmpty ? null : description;
    });

    _notifyPendingChange();
  }

  Future<void> _updateStatus(AssessmentStatus newStatus) async {
    // If switching away from Graded, clear the grade
    final shouldClearGrade =
        newStatus != AssessmentStatus.graded &&
        _localStatus == AssessmentStatus.graded;

    // Update local state
    setState(() {
      _localStatus = newStatus;
      if (shouldClearGrade) {
        _localMarkEarned = null;
        _gradeController.clear();
      }
    });

    // Prepare update data
    final updateData = <String, dynamic>{
      'status': newStatus.toString().split('.').last,
    };

    // If clearing grade, also update that in Firestore
    if (shouldClearGrade) {
      updateData['markEarned'] = null;
    }

    // Save directly to Firestore for immediate updates
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final repository = ref.read(firestoreRepositoryProvider);
      await repository.updateAssessment(
        user.uid,
        widget.module.semesterId,
        widget.module.id,
        widget.assessment.id,
        updateData,
      );

      // Trigger success animation
      _successFlashController.forward(from: 0);
    } catch (e) {
      AppLogger.error('Error saving status', error: e);
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get type badge colors
  Map<String, Color> _getTypeBadgeColors() {
    switch (widget.assessment.type) {
      case AssessmentType.exam:
        return {
          'bg': const Color(0xFFFEE2E2), // Red background
          'text': const Color(0xFFDC2626), // Red text
        };
      case AssessmentType.coursework:
        return {
          'bg': const Color(0xFFE9D5FF), // Purple background
          'text': const Color(0xFF7C3AED), // Purple text
        };
      case AssessmentType.weekly:
        return {
          'bg': const Color(0xFFDBEAFE), // Blue background
          'text': const Color(0xFF2563EB), // Blue text
        };
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

  // Get urgency badge info - shows "Complete" if submitted/graded, otherwise time-based
  Map<String, dynamic>? _getUrgencyBadgeInfo() {
    if (widget.assessment.dueDate == null) return null;

    // If submitted or graded, show "Complete" badge
    if (_localStatus == AssessmentStatus.submitted ||
        _localStatus == AssessmentStatus.graded) {
      return {
        'text': '✓ Complete',
        'bg': const Color(0xFFD1FAE5), // Green
        'text_color': const Color(0xFF059669), // Green
      };
    }

    // Otherwise show urgency based on days until due
    final now = DateTime.now();
    final daysUntil = widget.assessment.dueDate!
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    String badgeText;
    Color bgColor;
    Color textColor;

    if (daysUntil < 0) {
      badgeText = 'Overdue';
      bgColor = const Color(0xFFFEE2E2); // Red
      textColor = const Color(0xFFDC2626);
    } else if (daysUntil == 0) {
      badgeText = 'Today';
      bgColor = const Color(0xFFFEE2E2); // Red
      textColor = const Color(0xFFDC2626);
    } else if (daysUntil <= 7) {
      badgeText = '$daysUntil ${daysUntil == 1 ? "day" : "days"}';
      bgColor = const Color(0xFFFEE2E2); // Red
      textColor = const Color(0xFFDC2626);
    } else if (daysUntil <= 13) {
      badgeText = '$daysUntil days';
      bgColor = const Color(0xFFFED7AA); // Orange
      textColor = const Color(0xFFEA580C);
    } else {
      badgeText = '$daysUntil days';
      bgColor = const Color(0xFFD1FAE5); // Green
      textColor = const Color(0xFF059669);
    }

    return {'text': badgeText, 'bg': bgColor, 'text_color': textColor};
  }

  // Get left border color based on status
  Color _getBorderColor() {
    // Check due date urgency for not started assignments
    if (_localStatus == AssessmentStatus.notStarted &&
        widget.assessment.dueDate != null) {
      final now = DateTime.now();
      final daysUntil = widget.assessment.dueDate!
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      if (daysUntil < 14) {
        return const Color(0xFFFF9800); // Orange for approaching deadline
      }
    }

    switch (_localStatus) {
      case AssessmentStatus.notStarted:
        return const Color(0xFF9CA3AF); // Grey
      case AssessmentStatus.submitted:
        return const Color(0xFF3B82F6); // Blue
      case AssessmentStatus.graded:
        return const Color(0xFF10B981); // Green
    }
  }

  // Get background tint color (5% opacity of border color)
  Color _getBackgroundTint() {
    return _getBorderColor().withValues(alpha: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final typeName = _getTypeName();
    final typeBadgeColors = _getTypeBadgeColors();
    final borderColor = _getBorderColor();
    final bgTint = _getBackgroundTint();
    final urgencyBadge = _getUrgencyBadgeInfo();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        // NO borderRadius - conflicts with non-uniform border!
        border: Border(
          left: BorderSide(color: borderColor, width: 5),
          top: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          right: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          bottom: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgTint,
          // NO borderRadius here either to avoid conflicts
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line 1: Name + Type Badge + Weighting
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    widget.assessment.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeBadgeColors['bg'],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: typeBadgeColors['text'],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '• ${widget.assessment.weighting.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Line 2: Due Date + Urgency Badge
            if (widget.assessment.dueDate != null) ...[
              Row(
                children: [
                  Text(
                    'Due ${DateFormat('MMM d, y').format(widget.assessment.dueDate!)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (urgencyBadge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyBadge['bg'] as Color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        urgencyBadge['text'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: urgencyBadge['text_color'] as Color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Line 3: Description Box (clickable)
            InkWell(
              onTap: () => _showDescriptionDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _localDescription?.isNotEmpty == true
                            ? _localDescription!
                            : 'Add description...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _localDescription?.isNotEmpty == true
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                          fontStyle: _localDescription?.isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Line 4: Status Pills
            Row(
              children: [
                Text(
                  'Status: ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                _StatusPill(
                  label: 'Not Started',
                  status: AssessmentStatus.notStarted,
                  currentStatus: _localStatus,
                  onTap: () => _updateStatus(AssessmentStatus.notStarted),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Submitted',
                  status: AssessmentStatus.submitted,
                  currentStatus: _localStatus,
                  onTap: () => _updateStatus(AssessmentStatus.submitted),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  label: 'Graded',
                  status: AssessmentStatus.graded,
                  currentStatus: _localStatus,
                  onTap: () => _updateStatus(AssessmentStatus.graded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Line 5: Grade display and edit button
            Row(
              children: [
                if (_localMarkEarned != null)
                  Text(
                    'Grade: ${_localMarkEarned!.toStringAsFixed(1)}%',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  )
                else if (_localStatus == AssessmentStatus.submitted)
                  Text(
                    'Awaiting grade...',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const Spacer(),
                UniversalInteractiveWidget(
                  style: InteractiveStyle.elastic,
                  onTap: () => _showGradeDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Show description edit dialog
  void _showDescriptionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Description',
            style: GoogleFonts.poppins(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _descriptionController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Add a description for this assessment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            if (_descriptionController.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  _descriptionController.clear();
                  _saveDescription();
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
                ),
              ),
            TextButton(
              onPressed: () {
                _descriptionController.text = widget.assessment.description ?? '';
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF64748B)),
              ),
            ),
            FilledButton(
              onPressed: () {
                _saveDescription();
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
              child: Text('Save', style: GoogleFonts.inter()),
            ),
          ],
        );
      },
    );
  }

  // Show grade edit dialog
  void _showGradeDialog(BuildContext context) {
    // Initialize grade controller with current grade
    _gradeController.text = _localMarkEarned?.toStringAsFixed(1) ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Edit Grade',
              style: GoogleFonts.poppins(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _gradeController,
                    decoration: InputDecoration(
                      labelText: 'Grade (%)',
                      hintText: '0-100',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                      ),
                      errorText: _hasValidationError ? 'Enter a valid grade (0-100)' : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _hasValidationError = false;
                      });
                    },
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                ],
              ),
            ),
            actions: [
              if (_localMarkEarned != null)
                TextButton(
                  onPressed: () {
                    _gradeController.clear();
                    setDialogState(() {
                      _saveGrade();
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(color: const Color(0xFFEF4444)),
                  ),
                ),
              TextButton(
                onPressed: () {
                  _gradeController.text = widget.assessment.markEarned?.toStringAsFixed(1) ?? '';
                  setDialogState(() {
                    _hasValidationError = false;
                  });
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                ),
              ),
              FilledButton(
                onPressed: () {
                  final gradeText = _gradeController.text.trim();
                  final grade = gradeText.isEmpty ? null : double.tryParse(gradeText);

                  // Validation
                  if (gradeText.isNotEmpty && (grade == null || grade < 0 || grade > 100)) {
                    setDialogState(() {
                      _hasValidationError = true;
                    });
                    return;
                  }

                  _saveGrade();
                  Navigator.pop(dialogContext);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                ),
                child: Text('Save', style: GoogleFonts.inter()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  final AssessmentStatus status;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusBox({
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  String _getStatusLabel() {
    switch (status) {
      case AssessmentStatus.notStarted:
        return 'Not Started';
      case AssessmentStatus.submitted:
        return 'Submitted';
      case AssessmentStatus.graded:
        return 'Graded';
    }
  }

  Color _getStrongBackgroundColor() {
    switch (status) {
      case AssessmentStatus.notStarted:
        return const Color(0xFFFECDD3); // Strong light red
      case AssessmentStatus.submitted:
        return const Color(0xFFBAE6FD); // Strong light blue
      case AssessmentStatus.graded:
        return const Color(0xFFBBF7D0); // Strong light green
    }
  }

  Color _getLightBackgroundColor() {
    switch (status) {
      case AssessmentStatus.notStarted:
        return const Color(0xFFFEE2E2); // Very light red
      case AssessmentStatus.submitted:
        return const Color(0xFFE0F2FE); // Very light blue
      case AssessmentStatus.graded:
        return const Color(0xFFDCFCE7); // Very light green
    }
  }

  Color _getBorderColor() {
    switch (status) {
      case AssessmentStatus.notStarted:
        return const Color(0xFFEF4444); // Red
      case AssessmentStatus.submitted:
        return const Color(0xFF0EA5E9); // Blue
      case AssessmentStatus.graded:
        return const Color(0xFF10B981); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? _getStrongBackgroundColor()
        : _getLightBackgroundColor();
    final borderColor = _getBorderColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 75,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Text(
          _getStatusLabel(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: borderColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final AssessmentStatus status;
  final AssessmentStatus currentStatus;
  final VoidCallback onTap;

  const _StatusPill({
    required this.label,
    required this.status,
    required this.currentStatus,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (status) {
      case AssessmentStatus.notStarted:
        return const Color(0xFF9CA3AF); // Grey
      case AssessmentStatus.submitted:
        return const Color(0xFF3B82F6); // Blue
      case AssessmentStatus.graded:
        return const Color(0xFF10B981); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = status == currentStatus;
    final color = _getStatusColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circle indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
          ),
          const SizedBox(width: 4),
          // Label
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? color : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
