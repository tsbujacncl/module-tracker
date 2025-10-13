import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/screens/semester/semester_setup_screen.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:module_tracker/utils/grade_calculator.dart';

class SemesterArchiveScreen extends ConsumerStatefulWidget {
  const SemesterArchiveScreen({super.key});

  @override
  ConsumerState<SemesterArchiveScreen> createState() =>
      _SemesterArchiveScreenState();
}

class _SemesterArchiveScreenState extends ConsumerState<SemesterArchiveScreen> {
  int _displayCount = 10; // Initial display count
  String? _selectedYear; // Filter by year

  Future<void> _archiveSemester(
    BuildContext context,
    WidgetRef ref,
    Semester semester,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive ${semester.name}?'),
        content: const Text(
          'This will move the semester to the archive. You can restore it later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final repository = ref.read(firestoreRepositoryProvider);
        await repository.updateSemester(
          user.uid,
          semester.id,
          semester.copyWith(isArchived: true).toFirestore(),
        );
      }
    }
  }

  Future<void> _restoreSemester(
    BuildContext context,
    WidgetRef ref,
    Semester semester,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore ${semester.name}?'),
        content: const Text(
          'This will restore the semester and set it as the active semester.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        final repository = ref.read(firestoreRepositoryProvider);
        await repository.updateSemester(
          user.uid,
          semester.id,
          semester.copyWith(isArchived: false).toFirestore(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSemester = ref.watch(currentSemesterProvider);
    final futureSemesters = ref.watch(futureSemestersProvider);
    final allArchivedSemesters = ref.watch(archivedSemestersProvider);

    // Filter by year if selected
    final filteredSemesters = _selectedYear != null
        ? allArchivedSemesters.where((s) {
            return s.startDate.year.toString() == _selectedYear;
          }).toList()
        : allArchivedSemesters;

    // Apply pagination
    final archivedSemesters = filteredSemesters.take(_displayCount).toList();
    final hasMore = filteredSemesters.length > _displayCount;

    // Get unique years for filter
    final years =
        allArchivedSemesters
            .map((s) => s.startDate.year.toString())
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a)); // Sort descending

    return Scaffold(
      appBar: AppBar(
        title: const GradientHeader(title: 'Semesters'),
        actions: [
          // Year filter
          if (years.isNotEmpty)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter by year',
              onSelected: (year) {
                setState(() {
                  _selectedYear = year;
                  _displayCount = 10; // Reset pagination on filter change
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      if (_selectedYear == null)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      const Text('All Years'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ...years.map(
                  (year) => PopupMenuItem<String>(
                    value: year,
                    child: Row(
                      children: [
                        if (_selectedYear == year)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(year),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Semester Section
                if (currentSemester != null) ...[
                  Text(
                    'Current Semester',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SemesterCard(
                    semester: currentSemester,
                    status: SemesterStatus.current,
                  ),
                  const SizedBox(height: 32),
                ],
                // Future Semesters Section
                if (futureSemesters.isNotEmpty) ...[
                  Text(
                    'Future Semesters',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...futureSemesters.map(
                    (semester) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SemesterCard(
                        semester: semester,
                        status: SemesterStatus.future,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                // Archived Semesters Section
                Text(
                  'Archived Semesters',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                if (archivedSemesters.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.archive_outlined,
                            size: 64,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No archived semesters',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...archivedSemesters.map(
                    (semester) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SemesterCard(
                        semester: semester,
                        status: SemesterStatus.archived,
                        onRestore: () =>
                            _restoreSemester(context, ref, semester),
                      ),
                    ),
                  ),
                  // Load More button
                  if (hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 32),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _displayCount += 10; // Load 10 more
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'Load More (${filteredSemesters.length - _displayCount} remaining)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum SemesterStatus { current, future, archived }

class _SemesterCard extends ConsumerStatefulWidget {
  final Semester semester;
  final SemesterStatus status;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  const _SemesterCard({
    required this.semester,
    required this.status,
    this.onArchive,
    this.onRestore,
  });

  @override
  ConsumerState<_SemesterCard> createState() => _SemesterCardState();
}

class _SemesterCardState extends ConsumerState<_SemesterCard> {
  List<Color> _getGradientColors() {
    switch (widget.status) {
      case SemesterStatus.current:
        return [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)];
      case SemesterStatus.future:
        return [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
      case SemesterStatus.archived:
        return [const Color(0xFF64748B), const Color(0xFF475569)];
    }
  }

  String? _getStatusLabel() {
    switch (widget.status) {
      case SemesterStatus.current:
        return 'CURRENT';
      case SemesterStatus.future:
        return 'UPCOMING';
      case SemesterStatus.archived:
        return 'ARCHIVED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');
    final gradientColors = _getGradientColors();
    final statusLabel = _getStatusLabel();

    // Watch modules for this semester
    final modulesAsync = ref.watch(modulesForSemesterProvider(widget.semester.id));

    return modulesAsync.when(
      data: (modules) {
        // Sort modules by code (alphabetically/numerically)
        final sortedModules = [...modules]..sort((a, b) => a.code.compareTo(b.code));

        // Fetch assessments for each module and build map
        final assessmentsByModule = <String, List<Assessment>>{};
        for (final module in sortedModules) {
          final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
          assessmentsAsync.whenData((assessments) {
            assessmentsByModule[module.id] = assessments;
          });
        }

        // Calculate totals
        final totalCredits = sortedModules.fold<int>(0, (sum, m) => sum + m.credits);
        final overallGrade = GradeCalculator.calculateSemesterGrade(
          sortedModules,
          assessmentsByModule,
        );

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AssignmentsScreen(),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.semester.name,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (statusLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Menu button
                    Builder(
                      builder: (context) => GestureDetector(
                        onTap: () {
                          final RenderBox button = context.findRenderObject() as RenderBox;
                          final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                          final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

                          showMenu<String>(
                            context: context,
                            position: RelativeRect.fromLTRB(
                              buttonPosition.dx,
                              buttonPosition.dy + button.size.height,
                              overlay.size.width - buttonPosition.dx - button.size.width,
                              overlay.size.height - buttonPosition.dy - button.size.height,
                            ),
                            items: [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Edit Semester'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'assignments',
                                child: Row(
                                  children: [
                                    Icon(Icons.assessment_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('View Assignments'),
                                  ],
                                ),
                              ),
                            ],
                          ).then((value) {
                            if (!context.mounted) return;

                            if (value == 'assignments') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AssignmentsScreen(),
                                ),
                              );
                            } else if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SemesterSetupScreen(
                                    semesterToEdit: widget.semester,
                                  ),
                                ),
                              );
                            }
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${dateFormat.format(widget.semester.startDate)} - ${dateFormat.format(widget.semester.endDate)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    '${widget.semester.numberOfWeeks} weeks',
                    if (sortedModules.isNotEmpty && totalCredits > 0)
                      '$totalCredits credits',
                  ].join(' • '),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: overallGrade != null
                          ? Text(
                              'Overall: ${overallGrade.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            )
                          : Text(
                              'No grades yet',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ),
                    if (widget.status == SemesterStatus.archived && widget.onRestore != null)
                      TextButton.icon(
                        onPressed: widget.onRestore,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                        ),
                        icon: const Icon(Icons.unarchive_outlined, size: 18),
                        label: const Text('Restore'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
      loading: () => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
      error: (error, stack) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error loading modules',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}
