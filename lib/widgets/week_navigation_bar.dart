import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;

class WeekNavigationBar extends StatelessWidget {
  final Semester semester;
  final int currentWeek;
  final Function(int) onWeekChanged;
  final VoidCallback? onTodayPressed;

  const WeekNavigationBar({
    super.key,
    required this.semester,
    required this.currentWeek,
    required this.onWeekChanged,
    this.onTodayPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate week date range
    final weekStart = semester.startDate.add(
      Duration(days: (currentWeek - 1) * 7),
    );
    final weekEnd = weekStart.add(const Duration(days: 6));
    final dateFormat = DateFormat('MMM d');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 44, // Fixed height for the navigation bar
        child: Stack(
          children: [
            // Match calendar structure: 5 equal columns (no margins)
            Row(
              children: [
                const Expanded(child: SizedBox.shrink()), // Mon
                const Expanded(child: SizedBox.shrink()), // Tue
                const Expanded(child: SizedBox.shrink()), // Wed
                const Expanded(child: SizedBox.shrink()), // Thu
                const Expanded(child: SizedBox.shrink()), // Fri
              ],
            ),
          // Text centered across all columns (positioned to span full width)
          Positioned.fill(
            left: 48, // Leave space for left navigation button
            right: 48, // Leave space for right navigation button
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Week $currentWeek (${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)})',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AssignmentsScreen(),
                        ),
                      );
                    },
                    child: Text(
                      semester.name,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Navigation controls overlaid
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onWeekChanged(currentWeek - 1),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onWeekChanged(currentWeek + 1),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
