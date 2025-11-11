import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:module_tracker/models/customization_preferences.dart';
import 'package:module_tracker/services/app_logger.dart';

/// Notifier for customization preferences
class CustomizationNotifier extends StateNotifier<CustomizationPreferences> {
  static const String _boxName = 'customization';
  static const String _prefsKey = 'preferences';
  Box? _prefsBox;

  CustomizationNotifier() : super(const CustomizationPreferences()) {
    _loadPreferences();
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      _prefsBox = await Hive.openBox(_boxName);
      final savedPrefs = _prefsBox?.get(_prefsKey);

      if (savedPrefs != null && savedPrefs is Map) {
        state = CustomizationPreferences.fromMap(
          Map<String, dynamic>.from(savedPrefs),
        );
      }
    } catch (e) {
      AppLogger.debug('Error loading customization preferences: $e');
    }
  }

  /// Save preferences
  Future<void> _savePreferences() async {
    try {
      await _prefsBox?.put(_prefsKey, state.toMap());
    } catch (e) {
      AppLogger.debug('Error saving customization preferences: $e');
    }
  }

  /// Set font size
  Future<void> setFontSize(FontSize size) async {
    state = state.copyWith(fontSize: size);
    await _savePreferences();
  }

  /// Set week start day
  Future<void> setWeekStartDay(WeekStartDay day) async {
    state = state.copyWith(weekStartDay: day);
    await _savePreferences();
  }

  /// Set default task view
  Future<void> setDefaultTaskView(TaskView view) async {
    state = state.copyWith(defaultTaskView: view);
    await _savePreferences();
  }
}

/// Provider for customization preferences
final customizationProvider =
    StateNotifierProvider<CustomizationNotifier, CustomizationPreferences>((ref) {
  return CustomizationNotifier();
});
