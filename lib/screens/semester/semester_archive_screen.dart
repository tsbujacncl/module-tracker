import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/grade_provider.dart';
import 'package:module_tracker/screens/semester/semester_setup_screen.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;
import 'package:module_tracker/widgets/gradient_header.dart';
import 'package:module_tracker/widgets/semester_card.dart';

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
                  _buildSemesterCard(
                    currentSemester,
                    SemesterCardStatus.current,
                    null,
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
                      child: _buildSemesterCard(
                        semester,
                        SemesterCardStatus.future,
                        null,
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
                      child: _buildSemesterCard(
                        semester,
                        SemesterCardStatus.archived,
                        () => _restoreSemester(context, ref, semester),
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

  /// Helper method to build a SemesterCard with all required data
  Widget _buildSemesterCard(
    Semester semester,
    SemesterCardStatus status,
    VoidCallback? onRestore,
  ) {
    // Get overall grade
    final overallGradeData = ref.watch(
      semesterOverallGradeProvider(semester.id),
    );
    final overallGrade = overallGradeData?.$1;

    // Get credits
    final creditsData = ref.watch(
      accountedCreditsProvider(semester.id),
    );
    final (_, totalCredits) = creditsData;

    // Get assignment completion
    final assessmentsCount = ref.watch(
      semesterAssessmentsCountProvider(semester.id),
    );
    final (completedCount, totalCount) = assessmentsCount;

    return SemesterCard(
      semester: semester,
      status: status,
      overallGrade: overallGrade,
      totalCredits: totalCredits,
      completedAssignments: completedCount,
      totalAssignments: totalCount,
      showMenu: true,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AssignmentsScreen(),
          ),
        );
      },
      onMenuEdit: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SemesterSetupScreen(
              semesterToEdit: semester,
            ),
          ),
        );
      },
      onMenuAssignments: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AssignmentsScreen(),
          ),
        );
      },
      onRestore: onRestore,
    );
  }
}
