import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:module_tracker/models/semester.dart';

enum SemesterCardStatus {
  current,
  future,
  archived,
}

class SemesterCard extends ConsumerWidget {
  final Semester semester;
  final SemesterCardStatus status;
  final double? overallGrade;
  final int? totalCredits;
  final int? completedAssignments;
  final int? totalAssignments;
  final VoidCallback? onTap;
  final VoidCallback? onMenuEdit;
  final VoidCallback? onMenuAssignments;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final bool showMenu;

  const SemesterCard({
    super.key,
    required this.semester,
    required this.status,
    this.overallGrade,
    this.totalCredits,
    this.completedAssignments,
    this.totalAssignments,
    this.onTap,
    this.onMenuEdit,
    this.onMenuAssignments,
    this.onArchive,
    this.onRestore,
    this.showMenu = false,
  });

  List<Color> _getGradientColors() {
    switch (status) {
      case SemesterCardStatus.current:
        return [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)];
      case SemesterCardStatus.future:
        return [const Color(0xFF8B5CF6), const Color(0xFFEC4899)];
      case SemesterCardStatus.archived:
        return [const Color(0xFF64748B), const Color(0xFF475569)];
    }
  }

  String? _getStatusLabel() {
    switch (status) {
      case SemesterCardStatus.current:
        return 'CURRENT';
      case SemesterCardStatus.future:
        return 'UPCOMING';
      case SemesterCardStatus.archived:
        return 'ARCHIVED';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM d, y');
    final gradientColors = _getGradientColors();
    final statusLabel = _getStatusLabel();

    return GestureDetector(
      onTap: onTap,
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
              // Header row: Name, badge, menu
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
                  if (showMenu)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(4),
                      onSelected: (value) {
                        if (value == 'assignments' && onMenuAssignments != null) {
                          onMenuAssignments!();
                        } else if (value == 'edit' && onMenuEdit != null) {
                          onMenuEdit!();
                        }
                      },
                      itemBuilder: (context) => [
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
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Date range
              Text(
                '${dateFormat.format(semester.startDate)} - ${dateFormat.format(semester.endDate)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              // Weeks and credits
              Text(
                [
                  '${semester.numberOfWeeks} weeks',
                  if (totalCredits != null && totalCredits! > 0)
                    '$totalCredits credits',
                ].join(' • '),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              // Assignment completion (NEW)
              if (completedAssignments != null && totalAssignments != null) ...[
                const SizedBox(height: 4),
                Text(
                  '$completedAssignments of $totalAssignments assignments completed',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Overall grade and actions
              Row(
                children: [
                  Expanded(
                    child: overallGrade != null
                        ? Text(
                            'Overall: ${overallGrade!.toStringAsFixed(1)}%',
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
                  if (status == SemesterCardStatus.archived && onRestore != null)
                    TextButton.icon(
                      onPressed: onRestore,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore'),
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
