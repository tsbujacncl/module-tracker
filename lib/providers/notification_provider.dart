import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:module_tracker/models/notification_settings.dart';
import 'package:module_tracker/services/app_logger.dart';
import 'package:module_tracker/services/notification_service.dart';

/// Notification settings provider
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  static const String _settingsKey = 'notification_settings';
  Box? _settingsBox;
  final NotificationService _notificationService = NotificationService();

  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _loadSettings();
  }

  /// Load saved notification settings
  Future<void> _loadSettings() async {
    try {
      _settingsBox = await Hive.openBox('settings');
      final savedSettings = _settingsBox?.get(_settingsKey);

      if (savedSettings != null && savedSettings is Map) {
        state = NotificationSettings.fromMap(Map<String, dynamic>.from(savedSettings));
      }
    } catch (e) {
      AppLogger.debug('Error loading notification settings: $e');
    }
  }

  /// Save settings and reschedule notifications
  Future<void> _saveSettings() async {
    try {
      await _settingsBox?.put(_settingsKey, state.toMap());
      // Reschedule all notifications with new settings
      await _rescheduleNotifications();
    } catch (e) {
      AppLogger.debug('Error saving notification settings: $e');
    }
  }

  /// Reschedule all notifications based on current settings
  Future<void> _rescheduleNotifications() async {
    // Daily reminder
    if (state.dailyReminderEnabled) {
      await _notificationService.scheduleDailyReminderCustom(
        state.dailyReminderTime,
        state.dailyReminderDays,
      );
    } else {
      await _notificationService.cancelDailyReminder();
    }

    // Weekend planning
    if (state.weekendPlanningEnabled) {
      await _notificationService.scheduleWeekendPlanning(
        state.weekendPlanningTime,
      );
    } else {
      await _notificationService.cancelWeekendPlanning();
    }
  }

  // Update methods
  Future<void> setDailyReminderEnabled(bool enabled) async {
    state = state.copyWith(dailyReminderEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    state = state.copyWith(dailyReminderTime: time);
    await _saveSettings();
  }

  Future<void> setDailyReminderDays(Set<int> days) async {
    state = state.copyWith(dailyReminderDays: days);
    await _saveSettings();
  }

  Future<void> setAssessmentAlerts1Day(bool enabled) async {
    state = state.copyWith(assessmentAlerts1Day: enabled);
    await _saveSettings();
  }

  Future<void> setAssessmentAlerts3Days(bool enabled) async {
    state = state.copyWith(assessmentAlerts3Days: enabled);
    await _saveSettings();
  }

  Future<void> setAssessmentAlerts1Week(bool enabled) async {
    state = state.copyWith(assessmentAlerts1Week: enabled);
    await _saveSettings();
  }

  Future<void> setLectureRemindersEnabled(bool enabled) async {
    state = state.copyWith(lectureRemindersEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setLectureReminderMinutes(int minutes) async {
    state = state.copyWith(lectureReminderMinutes: minutes);
    await _saveSettings();
  }

  Future<void> setWeekendPlanningEnabled(bool enabled) async {
    state = state.copyWith(weekendPlanningEnabled: enabled);
    await _saveSettings();
  }

  Future<void> setWeekendPlanningTime(TimeOfDay time) async {
    state = state.copyWith(weekendPlanningTime: time);
    await _saveSettings();
  }
}

/// Provider for notification settings
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);
