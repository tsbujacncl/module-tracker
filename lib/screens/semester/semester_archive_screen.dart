import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/semester_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:intl/intl.dart';

class SemesterArchiveScreen extends ConsumerStatefulWidget {
  const SemesterArchiveScreen({super.key});

  @override
  ConsumerState<SemesterArchiveScreen> createState() => _SemesterArchiveScreenState();
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
    final years = allArchivedSemesters
        .map((s) => s.startDate.year.toString())
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Semester Archive',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                ...years.map((year) => PopupMenuItem<String>(
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
                    )),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                isArchived: false,
                onArchive: () => _archiveSemester(context, ref, currentSemester),
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
                    isArchived: true,
                    onRestore: () => _restoreSemester(context, ref, semester),
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
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final Semester semester;
  final bool isArchived;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  const _SemesterCard({
    required this.semester,
    required this.isArchived,
    this.onArchive,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isArchived
              ? [const Color(0xFF64748B), const Color(0xFF475569)]
              : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isArchived ? const Color(0xFF64748B) : const Color(0xFF0EA5E9))
                .withOpacity(0.3),
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
                    semester.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isArchived)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ARCHIVED',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dateFormat.format(semester.startDate)} - ${dateFormat.format(semester.endDate)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${semester.numberOfWeeks} weeks',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isArchived && onArchive != null)
                  TextButton.icon(
                    onPressed: onArchive,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('Archive'),
                  ),
                if (isArchived && onRestore != null)
                  TextButton.icon(
                    onPressed: onRestore,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                    icon: const Icon(Icons.unarchive_outlined, size: 18),
                    label: const Text('Restore'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
