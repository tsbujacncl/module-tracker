import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:intl/intl.dart';

class WeekNavigationBar extends StatelessWidget {
  final Semester semester;
  final int currentWeek;
  final Function(int) onWeekChanged;

  const WeekNavigationBar({
    super.key,
    required this.semester,
    required this.currentWeek,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFirstWeek = currentWeek == 1;
    final isLastWeek = currentWeek == semester.numberOfWeeks;

    // Calculate week date range
    final weekStart = semester.startDate.add(Duration(days: (currentWeek - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: isFirstWeek
                ? null
                : () => onWeekChanged(currentWeek - 1),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Week $currentWeek of ${semester.numberOfWeeks}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isLastWeek
                ? null
                : () => onWeekChanged(currentWeek + 1),
          ),
        ],
      ),
    );
  }
}