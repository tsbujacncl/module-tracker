import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User preferences model
class UserPreferences {
  final bool enableThreeStateTaskToggle;
  final Color? customLectureColor;
  final Color? customLabTutorialColor;
  final Color? customAssignmentColor;

  const UserPreferences({
    this.enableThreeStateTaskToggle = false, // Default to 2-state (simpler)
    this.customLectureColor,
    this.customLabTutorialColor,
    this.customAssignmentColor,
  });

  UserPreferences copyWith({
    bool? enableThreeStateTaskToggle,
    Color? customLectureColor,
    Color? customLabTutorialColor,
    Color? customAssignmentColor,
  }) {
    return UserPreferences(
      enableThreeStateTaskToggle: enableThreeStateTaskToggle ?? this.enableThreeStateTaskToggle,
      customLectureColor: customLectureColor ?? this.customLectureColor,
      customLabTutorialColor: customLabTutorialColor ?? this.customLabTutorialColor,
      customAssignmentColor: customAssignmentColor ?? this.customAssignmentColor,
    );
  }
}

/// User preferences notifier
class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  static const String _threeStateToggleKey = 'enable_three_state_task_toggle';
  static const String _lectureColorKey = 'custom_lecture_color';
  static const String _labTutorialColorKey = 'custom_lab_tutorial_color';
  static const String _assignmentColorKey = 'custom_assignment_color';
  Box? _settingsBox;

  UserPreferencesNotifier() : super(const UserPreferences()) {
    _loadPreferences();
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      _settingsBox = await Hive.openBox('settings');

      final threeStateToggle = _settingsBox?.get(_threeStateToggleKey, defaultValue: false) as bool;
      final lectureColorValue = _settingsBox?.get(_lectureColorKey) as int?;
      final labTutorialColorValue = _settingsBox?.get(_labTutorialColorKey) as int?;
      final assignmentColorValue = _settingsBox?.get(_assignmentColorKey) as int?;

      state = UserPreferences(
        enableThreeStateTaskToggle: threeStateToggle,
        customLectureColor: lectureColorValue != null ? Color(lectureColorValue) : null,
        customLabTutorialColor: labTutorialColorValue != null ? Color(labTutorialColorValue) : null,
        customAssignmentColor: assignmentColorValue != null ? Color(assignmentColorValue) : null,
      );
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  /// Toggle three-state task mode
  Future<void> setThreeStateTaskToggle(bool enabled) async {
    state = state.copyWith(enableThreeStateTaskToggle: enabled);

    try {
      await _settingsBox?.put(_threeStateToggleKey, enabled);
    } catch (e) {
      print('Error saving three-state toggle preference: $e');
    }
  }

  /// Set custom lecture color
  Future<void> setLectureColor(Color color) async {
    state = state.copyWith(customLectureColor: color);

    try {
      // ignore: deprecated_member_use
      await _settingsBox?.put(_lectureColorKey, color.value);
    } catch (e) {
      print('Error saving lecture color: $e');
    }
  }

  /// Set custom lab/tutorial color
  Future<void> setLabTutorialColor(Color color) async {
    state = state.copyWith(customLabTutorialColor: color);

    try {
      // ignore: deprecated_member_use
      await _settingsBox?.put(_labTutorialColorKey, color.value);
    } catch (e) {
      print('Error saving lab/tutorial color: $e');
    }
  }

  /// Set custom assignment color
  Future<void> setAssignmentColor(Color color) async {
    state = state.copyWith(customAssignmentColor: color);

    try {
      // ignore: deprecated_member_use
      await _settingsBox?.put(_assignmentColorKey, color.value);
    } catch (e) {
      print('Error saving assignment color: $e');
    }
  }
}

/// User preferences provider
final userPreferencesProvider = StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
  return UserPreferencesNotifier();
});

// Provider to track when user is dragging over checkboxes (prevents scroll)
final isDraggingCheckboxProvider = StateProvider<bool>((ref) => false);
