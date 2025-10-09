import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User preferences model
class UserPreferences {
  final bool enableThreeStateTaskToggle;
  final Color? customLectureColor;
  final Color? customLabTutorialColor;
  final Color? customAssignmentColor;
  final double targetGrade;
  final String? userName;
  final DateTime? birthday;
  final String? notificationTime; // 'morning', 'afternoon', 'evening', 'off'
  final bool hasCompletedOnboarding;

  const UserPreferences({
    this.enableThreeStateTaskToggle = false, // Default to 2-state (simpler)
    this.customLectureColor,
    this.customLabTutorialColor,
    this.customAssignmentColor,
    this.targetGrade = 70.0, // Default to First Class (70%)
    this.userName,
    this.birthday,
    this.notificationTime,
    this.hasCompletedOnboarding = false,
  });

  UserPreferences copyWith({
    bool? enableThreeStateTaskToggle,
    Color? customLectureColor,
    Color? customLabTutorialColor,
    Color? customAssignmentColor,
    double? targetGrade,
    ValueGetter<String?>? userName,
    ValueGetter<DateTime?>? birthday,
    String? notificationTime,
    bool? hasCompletedOnboarding,
  }) {
    return UserPreferences(
      enableThreeStateTaskToggle: enableThreeStateTaskToggle ?? this.enableThreeStateTaskToggle,
      customLectureColor: customLectureColor ?? this.customLectureColor,
      customLabTutorialColor: customLabTutorialColor ?? this.customLabTutorialColor,
      customAssignmentColor: customAssignmentColor ?? this.customAssignmentColor,
      targetGrade: targetGrade ?? this.targetGrade,
      userName: userName != null ? userName() : this.userName,
      birthday: birthday != null ? birthday() : this.birthday,
      notificationTime: notificationTime ?? this.notificationTime,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

/// User preferences notifier
class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  static const String _threeStateToggleKey = 'enable_three_state_task_toggle';
  static const String _lectureColorKey = 'custom_lecture_color';
  static const String _labTutorialColorKey = 'custom_lab_tutorial_color';
  static const String _assignmentColorKey = 'custom_assignment_color';
  static const String _targetGradeKey = 'target_grade';
  static const String _userNameKey = 'user_name';
  static const String _birthdayKey = 'birthday';
  static const String _notificationTimeKey = 'notification_time';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  Box? _settingsBox;

  UserPreferencesNotifier() : super(const UserPreferences()) {
    _loadPreferences();
  }

  /// Ensure settings box is initialized
  Future<Box> _ensureBox() async {
    if (_settingsBox != null && _settingsBox!.isOpen) {
      return _settingsBox!;
    }
    _settingsBox = await Hive.openBox('settings');
    return _settingsBox!;
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      final box = await _ensureBox();

      final threeStateToggle = box.get(_threeStateToggleKey, defaultValue: false) as bool;
      final lectureColorValue = box.get(_lectureColorKey) as int?;
      final labTutorialColorValue = box.get(_labTutorialColorKey) as int?;
      final assignmentColorValue = box.get(_assignmentColorKey) as int?;
      final targetGrade = box.get(_targetGradeKey, defaultValue: 70.0) as double;
      final userName = box.get(_userNameKey) as String?;
      final birthdayString = box.get(_birthdayKey) as String?;
      final notificationTime = box.get(_notificationTimeKey) as String?;
      final hasCompletedOnboarding = box.get(_hasCompletedOnboardingKey, defaultValue: false) as bool;

      state = UserPreferences(
        enableThreeStateTaskToggle: threeStateToggle,
        customLectureColor: lectureColorValue != null ? Color(lectureColorValue) : null,
        customLabTutorialColor: labTutorialColorValue != null ? Color(labTutorialColorValue) : null,
        customAssignmentColor: assignmentColorValue != null ? Color(assignmentColorValue) : null,
        targetGrade: targetGrade,
        userName: userName,
        birthday: birthdayString != null ? DateTime.tryParse(birthdayString) : null,
        notificationTime: notificationTime,
        hasCompletedOnboarding: hasCompletedOnboarding,
      );
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  /// Toggle three-state task mode
  Future<void> setThreeStateTaskToggle(bool enabled) async {
    state = state.copyWith(enableThreeStateTaskToggle: enabled);

    try {
      final box = await _ensureBox();
      await box.put(_threeStateToggleKey, enabled);
    } catch (e) {
      print('Error saving three-state toggle preference: $e');
    }
  }

  /// Set custom lecture color
  Future<void> setLectureColor(Color color) async {
    state = state.copyWith(customLectureColor: color);

    try {
      final box = await _ensureBox();
      // ignore: deprecated_member_use
      await box.put(_lectureColorKey, color.value);
    } catch (e) {
      print('Error saving lecture color: $e');
    }
  }

  /// Set custom lab/tutorial color
  Future<void> setLabTutorialColor(Color color) async {
    state = state.copyWith(customLabTutorialColor: color);

    try {
      final box = await _ensureBox();
      // ignore: deprecated_member_use
      await box.put(_labTutorialColorKey, color.value);
    } catch (e) {
      print('Error saving lab/tutorial color: $e');
    }
  }

  /// Set custom assignment color
  Future<void> setAssignmentColor(Color color) async {
    state = state.copyWith(customAssignmentColor: color);

    try {
      final box = await _ensureBox();
      // ignore: deprecated_member_use
      await box.put(_assignmentColorKey, color.value);
    } catch (e) {
      print('Error saving assignment color: $e');
    }
  }

  /// Set target grade
  Future<void> setTargetGrade(double grade) async {
    state = state.copyWith(targetGrade: grade);

    try {
      final box = await _ensureBox();
      await box.put(_targetGradeKey, grade);
    } catch (e) {
      print('Error saving target grade: $e');
    }
  }

  /// Set user name
  Future<void> setUserName(String name) async {
    state = state.copyWith(userName: () => name);

    try {
      final box = await _ensureBox();
      await box.put(_userNameKey, name);
      print('DEBUG: User name saved successfully: $name');
    } catch (e) {
      print('Error saving user name: $e');
    }
  }

  /// Set birthday
  Future<void> setBirthday(DateTime? birthday) async {
    state = state.copyWith(birthday: () => birthday);

    try {
      final box = await _ensureBox();
      if (birthday != null) {
        await box.put(_birthdayKey, birthday.toIso8601String());
        print('DEBUG: Birthday saved successfully: ${birthday.toIso8601String()}');
      } else {
        await box.delete(_birthdayKey);
        print('DEBUG: Birthday cleared');
      }
    } catch (e) {
      print('Error saving birthday: $e');
    }
  }

  /// Set notification time
  Future<void> setNotificationTime(String time) async {
    state = state.copyWith(notificationTime: time);

    try {
      final box = await _ensureBox();
      await box.put(_notificationTimeKey, time);
    } catch (e) {
      print('Error saving notification time: $e');
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    state = state.copyWith(hasCompletedOnboarding: true);

    try {
      final box = await _ensureBox();
      await box.put(_hasCompletedOnboardingKey, true);
    } catch (e) {
      print('Error saving onboarding status: $e');
    }
  }
}

/// User preferences provider
final userPreferencesProvider = StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
  return UserPreferencesNotifier();
});

// Provider to track when user is dragging over checkboxes (prevents scroll)
final isDraggingCheckboxProvider = StateProvider<bool>((ref) => false);
