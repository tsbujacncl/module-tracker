import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/notification_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notification Settings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
          // Daily Task Reminder Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Daily Task Reminder',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Daily Reminder'),
                    subtitle: const Text('Get reminded to check your tasks'),
                    value: settings.dailyReminderEnabled,
                    onChanged: (value) {
                      notifier.setDailyReminderEnabled(value);
                    },
                  ),
                  if (settings.dailyReminderEnabled) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reminder Time'),
                      subtitle: Text(
                        '${settings.dailyReminderTime.hour.toString().padLeft(2, '0')}:${settings.dailyReminderTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: settings.dailyReminderTime,
                        );
                        if (time != null) {
                          notifier.setDailyReminderTime(time);
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active Days'),
                      subtitle: Text(_getDaysText(settings.dailyReminderDays)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showDaysDialog(context, notifier, settings.dailyReminderDays),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Assessment Alerts Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment_late,
                          color: Color(0xFFEF4444),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Assessment Alerts',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('1 Day Before'),
                    subtitle: const Text('Alert when assessment is due tomorrow'),
                    value: settings.assessmentAlerts1Day,
                    onChanged: (value) {
                      notifier.setAssessmentAlerts1Day(value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('3 Days Before'),
                    subtitle: const Text('Alert 3 days before due date'),
                    value: settings.assessmentAlerts3Days,
                    onChanged: (value) {
                      notifier.setAssessmentAlerts3Days(value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('1 Week Before'),
                    subtitle: const Text('Alert 1 week before due date'),
                    value: settings.assessmentAlerts1Week,
                    onChanged: (value) {
                      notifier.setAssessmentAlerts1Week(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Lecture Reminders Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Lecture Reminders',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Lecture Reminders'),
                    subtitle: const Text('Get reminded before lectures start'),
                    value: settings.lectureRemindersEnabled,
                    onChanged: (value) {
                      notifier.setLectureRemindersEnabled(value);
                    },
                  ),
                  if (settings.lectureRemindersEnabled) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind Me'),
                      subtitle: Text('${settings.lectureReminderMinutes} minutes before'),
                      trailing: PopupMenuButton<int>(
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Change'),
                            Icon(Icons.arrow_drop_down),
                          ],
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 15, child: Text('15 minutes before')),
                          const PopupMenuItem(value: 30, child: Text('30 minutes before')),
                          const PopupMenuItem(value: 45, child: Text('45 minutes before')),
                          const PopupMenuItem(value: 60, child: Text('1 hour before')),
                        ],
                        onSelected: (value) {
                          notifier.setLectureReminderMinutes(value);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Weekend Planning Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Weekend Planning',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Weekend Planning'),
                    subtitle: const Text('Sunday reminder to plan your week'),
                    value: settings.weekendPlanningEnabled,
                    onChanged: (value) {
                      notifier.setWeekendPlanningEnabled(value);
                    },
                  ),
                  if (settings.weekendPlanningEnabled) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reminder Time'),
                      subtitle: Text(
                        'Sundays at ${settings.weekendPlanningTime.hour.toString().padLeft(2, '0')}:${settings.weekendPlanningTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: settings.weekendPlanningTime,
                        );
                        if (time != null) {
                          notifier.setWeekendPlanningTime(time);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  String _getDaysText(Set<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll([1, 2, 3, 4, 5])) return 'Weekdays';
    if (days.length == 2 && days.containsAll([6, 7])) return 'Weekends';

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d - 1]).join(', ');
  }

  void _showDaysDialog(BuildContext context, notifier, Set<int> currentDays) {
    final selectedDays = Set<int>.from(currentDays);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Days'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDayCheckbox('Monday', 1, selectedDays, setState),
                _buildDayCheckbox('Tuesday', 2, selectedDays, setState),
                _buildDayCheckbox('Wednesday', 3, selectedDays, setState),
                _buildDayCheckbox('Thursday', 4, selectedDays, setState),
                _buildDayCheckbox('Friday', 5, selectedDays, setState),
                _buildDayCheckbox('Saturday', 6, selectedDays, setState),
                _buildDayCheckbox('Sunday', 7, selectedDays, setState),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedDays.isNotEmpty) {
                    notifier.setDailyReminderDays(selectedDays);
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayCheckbox(String day, int value, Set<int> selectedDays, StateSetter setState) {
    return CheckboxListTile(
      title: Text(day),
      value: selectedDays.contains(value),
      onChanged: (checked) {
        setState(() {
          if (checked == true) {
            selectedDays.add(value);
          } else {
            selectedDays.remove(value);
          }
        });
      },
    );
  }
}
