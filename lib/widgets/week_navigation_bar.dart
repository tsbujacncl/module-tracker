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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use actual available width (same as calendar)
        final screenWidth = constraints.maxWidth;
        final bool isSmall = screenWidth < 400;
        final bool isLarge = screenWidth >= 500;

        final double marginSize;
        if (isSmall) {
          marginSize = 16.0;
        } else if (isLarge) {
          marginSize = 30.0;
        } else {
          marginSize = 20.0;
        }

        final timeColumnWidth = marginSize; // Same as margin (always equal)
        final rightMargin = marginSize;

        return Padding(
          padding: const EdgeInsets.only(
            top: 4,
            bottom: 4,
          ),
          child: SizedBox(
            height: 44, // Fixed height for the navigation bar
            child: Row(
              children: [
                // Time column spacer (flush left) - matches calendar
                SizedBox(width: timeColumnWidth),
                // Content area - aligns with calendar's 5 day columns
                Expanded(
                  child: Stack(
                    children: [
                      // Text centered in the content area
                      Center(
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
                // Right margin - matches calendar
                SizedBox(width: rightMargin),
              ],
            ),
          ),
        );
  },
);
  }
}
