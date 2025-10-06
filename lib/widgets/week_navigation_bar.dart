import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/screens/semester/semester_setup_screen.dart';
import 'package:intl/intl.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered text with more space (reduced padding since no today button)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40), // Reduced from 48 for more text space
            child: Column(
              children: [
                Text(
                  'Week $currentWeek (${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)})',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onLongPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SemesterSetupScreen(
                          semesterToEdit: semester,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    semester.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
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
    );
  }
}
