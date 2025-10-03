import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User preferences model
class UserPreferences {
  final bool enableThreeStateTaskToggle;

  const UserPreferences({
    this.enableThreeStateTaskToggle = false, // Default to 2-state (simpler)
  });

  UserPreferences copyWith({
    bool? enableThreeStateTaskToggle,
  }) {
    return UserPreferences(
      enableThreeStateTaskToggle: enableThreeStateTaskToggle ?? this.enableThreeStateTaskToggle,
    );
  }
}

/// User preferences notifier
class UserPreferencesNotifier extends StateNotifier<UserPreferences> {
  static const String _threeStateToggleKey = 'enable_three_state_task_toggle';
  Box? _settingsBox;

  UserPreferencesNotifier() : super(const UserPreferences()) {
    _loadPreferences();
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      _settingsBox = await Hive.openBox('settings');

      final threeStateToggle = _settingsBox?.get(_threeStateToggleKey, defaultValue: false) as bool;

      state = UserPreferences(
        enableThreeStateTaskToggle: threeStateToggle,
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
}

/// User preferences provider
final userPreferencesProvider = StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
  return UserPreferencesNotifier();
});
