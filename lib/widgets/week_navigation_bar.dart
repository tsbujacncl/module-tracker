import 'package:flutter/material.dart';
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
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