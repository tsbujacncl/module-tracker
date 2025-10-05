import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/models/semester.dart';
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
        children: [
          // Match calendar structure: 32px + 5 columns
          Row(
            children: [
              const SizedBox(width: 16), // Adjust for padding + match 32px time column (16 padding + 16)
              const Expanded(child: SizedBox.shrink()), // Mon
              const Expanded(child: SizedBox.shrink()), // Tue
              Expanded(
                child: Column(
                  children: [
                    Text(
                      semester.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)} (Week $currentWeek)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ), // Wed - aligned with Module Tracker
              const Expanded(child: SizedBox.shrink()), // Thu
              const Expanded(child: SizedBox.shrink()), // Fri
            ],
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTodayPressed != null)
                  TextButton(
                    onPressed: onTodayPressed,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Today',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onWeekChanged(currentWeek + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
