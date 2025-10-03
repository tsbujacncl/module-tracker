import 'package:flutter/material.dart';

/// Notification settings for the user
class NotificationSettings {
  // Daily reminder settings
  final bool dailyReminderEnabled;
  final TimeOfDay dailyReminderTime;
  final Set<int> dailyReminderDays; // 1=Mon, 7=Sun

  // Assessment alert settings
  final bool assessmentAlerts1Day;
  final bool assessmentAlerts3Days;
  final bool assessmentAlerts1Week;

  // Lecture reminder settings
  final bool lectureRemindersEnabled;
  final int lectureReminderMinutes; // Minutes before lecture

  // Weekend planning reminder
  final bool weekendPlanningEnabled;
  final TimeOfDay weekendPlanningTime; // Sunday evening time

  const NotificationSettings({
    this.dailyReminderEnabled = true,
    this.dailyReminderTime = const TimeOfDay(hour: 17, minute: 0),
    this.dailyReminderDays = const {1, 2, 3, 4, 5}, // Mon-Fri
    this.assessmentAlerts1Day = true,
    this.assessmentAlerts3Days = true,
    this.assessmentAlerts1Week = false,
    this.lectureRemindersEnabled = false,
    this.lectureReminderMinutes = 30,
    this.weekendPlanningEnabled = true,
    this.weekendPlanningTime = const TimeOfDay(hour: 18, minute: 0),
  });

  NotificationSettings copyWith({
    bool? dailyReminderEnabled,
    TimeOfDay? dailyReminderTime,
    Set<int>? dailyReminderDays,
    bool? assessmentAlerts1Day,
    bool? assessmentAlerts3Days,
    bool? assessmentAlerts1Week,
    bool? lectureRemindersEnabled,
    int? lectureReminderMinutes,
    bool? weekendPlanningEnabled,
    TimeOfDay? weekendPlanningTime,
  }) {
    return NotificationSettings(
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      dailyReminderDays: dailyReminderDays ?? this.dailyReminderDays,
      assessmentAlerts1Day: assessmentAlerts1Day ?? this.assessmentAlerts1Day,
      assessmentAlerts3Days: assessmentAlerts3Days ?? this.assessmentAlerts3Days,
      assessmentAlerts1Week: assessmentAlerts1Week ?? this.assessmentAlerts1Week,
      lectureRemindersEnabled: lectureRemindersEnabled ?? this.lectureRemindersEnabled,
      lectureReminderMinutes: lectureReminderMinutes ?? this.lectureReminderMinutes,
      weekendPlanningEnabled: weekendPlanningEnabled ?? this.weekendPlanningEnabled,
      weekendPlanningTime: weekendPlanningTime ?? this.weekendPlanningTime,
    );
  }

  /// Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderHour': dailyReminderTime.hour,
      'dailyReminderMinute': dailyReminderTime.minute,
      'dailyReminderDays': dailyReminderDays.toList(),
      'assessmentAlerts1Day': assessmentAlerts1Day,
      'assessmentAlerts3Days': assessmentAlerts3Days,
      'assessmentAlerts1Week': assessmentAlerts1Week,
      'lectureRemindersEnabled': lectureRemindersEnabled,
      'lectureReminderMinutes': lectureReminderMinutes,
      'weekendPlanningEnabled': weekendPlanningEnabled,
      'weekendPlanningHour': weekendPlanningTime.hour,
      'weekendPlanningMinute': weekendPlanningTime.minute,
    };
  }

  /// Create from map
  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      dailyReminderEnabled: map['dailyReminderEnabled'] as bool? ?? true,
      dailyReminderTime: TimeOfDay(
        hour: map['dailyReminderHour'] as int? ?? 17,
        minute: map['dailyReminderMinute'] as int? ?? 0,
      ),
      dailyReminderDays: (map['dailyReminderDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toSet() ??
          {1, 2, 3, 4, 5},
      assessmentAlerts1Day: map['assessmentAlerts1Day'] as bool? ?? true,
      assessmentAlerts3Days: map['assessmentAlerts3Days'] as bool? ?? true,
      assessmentAlerts1Week: map['assessmentAlerts1Week'] as bool? ?? false,
      lectureRemindersEnabled: map['lectureRemindersEnabled'] as bool? ?? false,
      lectureReminderMinutes: map['lectureReminderMinutes'] as int? ?? 30,
      weekendPlanningEnabled: map['weekendPlanningEnabled'] as bool? ?? true,
      weekendPlanningTime: TimeOfDay(
        hour: map['weekendPlanningHour'] as int? ?? 18,
        minute: map['weekendPlanningMinute'] as int? ?? 0,
      ),
    );
  }
}
