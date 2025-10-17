import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/screens/assessments/assessments_screen.dart'
    show AssignmentsScreen;
import 'package:module_tracker/utils/responsive_text_utils.dart';

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

        // Get full screen width for responsive scaling
        final fullScreenWidth = MediaQuery.of(context).size.width;

        // Responsive height to accommodate larger text on big screens
        final navBarHeight = fullScreenWidth < 600 ? 44.0 : fullScreenWidth < 1200 ? 48.0 : fullScreenWidth < 1600 ? 52.0 : 56.0;
        // Reduce gap between week and semester name
        final gapBetweenHeaders = fullScreenWidth < 1200 ? 1.0 : 0.5;
        // Reduce vertical padding on small devices for tighter spacing
        final topPadding = fullScreenWidth < 600 ? 1.0 : 2.5;
        final bottomPadding = fullScreenWidth < 600 ? 2.0 : 4.0;

        return Padding(
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding,
          ),
          child: SizedBox(
            height: navBarHeight + 4, // Add extra space to prevent overflow
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
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1.5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Week $currentWeek (${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)})',
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveText.getSubtitleFontSize(fullScreenWidth),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              ),
                            SizedBox(height: gapBetweenHeaders),
                            Flexible(
                              child: GestureDetector(
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
                                  style: GoogleFonts.poppins(
                                    fontSize: ResponsiveText.getSubtitleFontSize(fullScreenWidth) * 0.92,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF64748B),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      // Navigation controls overlaid - aligned with week text line
                      Positioned(
                        left: 0,
                        top: (navBarHeight - 48) / 2 - 7.5,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => onWeekChanged(currentWeek - 1),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: (navBarHeight - 48) / 2 - 7.5,
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
