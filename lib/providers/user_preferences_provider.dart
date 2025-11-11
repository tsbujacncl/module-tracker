import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/repositories/firestore_repository.dart';
import 'package:module_tracker/services/app_logger.dart';

/// User preferences model
class UserPreferences {
  final bool enableThreeStateTaskToggle;
  final Color? customLectureColor;
  final Color? customLabTutorialColor;
  final Color? customAssignmentColor;
  final double targetGrade;
  final String? userName;
  final String? notificationTime; // 'morning', 'afternoon', 'evening', 'off'
  final bool hasCompletedOnboarding;
  final bool isLoading; // Track if preferences are still being loaded

  const UserPreferences({
    this.enableThreeStateTaskToggle = false, // Default to 2-state (simpler)
    this.customLectureColor,
    this.customLabTutorialColor,
    this.customAssignmentColor,
    this.targetGrade = 70.0, // Default to First Class (70%)
    this.userName,
    this.notificationTime,
    this.hasCompletedOnboarding = false,
    this.isLoading = true, // Start with loading state
  });

  UserPreferences copyWith({
    bool? enableThreeStateTaskToggle,
    Color? customLectureColor,
    Color? customLabTutorialColor,
    Color? customAssignmentColor,
    double? targetGrade,
    ValueGetter<String?>? userName,
    String? notificationTime,
    bool? hasCompletedOnboarding,
    bool? isLoading,
  }) {
    return UserPreferences(
      enableThreeStateTaskToggle: enableThreeStateTaskToggle ?? this.enableThreeStateTaskToggle,
      customLectureColor: customLectureColor ?? this.customLectureColor,
      customLabTutorialColor: customLabTutorialColor ?? this.customLabTutorialColor,
      customAssignmentColor: customAssignmentColor ?? this.customAssignmentColor,
      targetGrade: targetGrade ?? this.targetGrade,
      userName: userName != null ? userName() : this.userName,
      notificationTime: notificationTime ?? this.notificationTime,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isLoading: isLoading ?? this.isLoading,
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
  static const String _notificationTimeKey = 'notification_time';
  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  Box? _settingsBox;
  final String? _userId; // Firebase user ID for user-specific storage
  final FirestoreRepository _repository;

  UserPreferencesNotifier({String? userId, required FirestoreRepository repository})
      : _userId = userId,
        _repository = repository,
        super(const UserPreferences()) {
    _loadPreferences();
  }

  /// Get user-specific key by prefixing with user ID
  String _getUserKey(String baseKey) {
    if (_userId != null && _userId!.isNotEmpty) {
      return 'user_${_userId}_$baseKey';
    }
    // Fallback to global key if no user ID (shouldn't happen in normal flow)
    return baseKey;
  }

  /// Ensure settings box is initialized
  Future<Box> _ensureBox() async {
    // Try to get the already-opened box first
    if (Hive.isBoxOpen('settings')) {
      _settingsBox = Hive.box('settings');
      AppLogger.debug('DEBUG: Using already-opened settings box');
      return _settingsBox!;
    }

    // If not open, open it (shouldn't happen if main.dart opens it first)
    if (_settingsBox != null && _settingsBox!.isOpen) {
      return _settingsBox!;
    }

    AppLogger.debug(': Opening new settings box');
    _settingsBox = await Hive.openBox('settings');
    return _settingsBox!;
  }

  /// Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      AppLogger.debug('DEBUG LOAD: ========== LOADING PREFERENCES START ==========');
      AppLogger.debug('DEBUG LOAD: User ID: $_userId');

      // If no user ID, keep loading state and don't load anything
      // This prevents loading preferences for null user before auth completes
      if (_userId == null || _userId!.isEmpty) {
        AppLogger.debug('DEBUG LOAD: No user ID - keeping loading state');
        return; // Keep isLoading: true
      }

      // Try loading from Firestore (we know userId is not null here)
      AppLogger.debug('DEBUG LOAD: Attempting to load from Firestore...');
      final firestorePrefs = await _repository.getUserPreferencesOnce(_userId!);

      if (firestorePrefs != null && firestorePrefs.isNotEmpty) {
        AppLogger.debug('DEBUG LOAD: Found preferences in Firestore: $firestorePrefs');
        _applyPreferencesFromMap(firestorePrefs);
        // Also cache in Hive for offline access
        await _cachePreferencesToHive(firestorePrefs);
        AppLogger.debug('DEBUG LOAD: Loaded from Firestore - userName: ${state.userName}');
        return;
      } else {
        AppLogger.debug('DEBUG LOAD: No preferences in Firestore (or empty), checking Hive...');
      }

      // Fall back to Hive if Firestore has no data (first time or offline)
      AppLogger.debug('DEBUG LOAD: Loading from Hive...');
      final box = await _ensureBox();
      AppLogger.debug('DEBUG LOAD: Box obtained, isOpen: ${box.isOpen}');

      // Debug: print all keys in the box for this user
      final allKeys = box.keys.where((k) => k.toString().contains('user_')).toList();
      AppLogger.debug('DEBUG LOAD: All user keys in Hive: $allKeys');

      final threeStateToggle = box.get(_getUserKey(_threeStateToggleKey), defaultValue: false) as bool;
      final lectureColorValue = box.get(_getUserKey(_lectureColorKey)) as int?;
      final labTutorialColorValue = box.get(_getUserKey(_labTutorialColorKey)) as int?;
      final assignmentColorValue = box.get(_getUserKey(_assignmentColorKey)) as int?;
      final targetGrade = box.get(_getUserKey(_targetGradeKey), defaultValue: 70.0) as double;

      final userNameKey = _getUserKey(_userNameKey);
      final onboardingKey = _getUserKey(_hasCompletedOnboardingKey);

      AppLogger.debug('DEBUG LOAD: Keys being used - Name: $userNameKey, Onboarding: $onboardingKey');

      final userName = box.get(userNameKey) as String?;
      final notificationTime = box.get(_getUserKey(_notificationTimeKey)) as String?;
      final hasCompletedOnboarding = box.get(onboardingKey, defaultValue: false) as bool;

      AppLogger.debug('DEBUG LOAD: Loaded from Hive - userName: $userName, onboarding: $hasCompletedOnboarding');

      state = UserPreferences(
        enableThreeStateTaskToggle: threeStateToggle,
        customLectureColor: lectureColorValue != null ? Color(lectureColorValue) : null,
        customLabTutorialColor: labTutorialColorValue != null ? Color(labTutorialColorValue) : null,
        customAssignmentColor: assignmentColorValue != null ? Color(assignmentColorValue) : null,
        targetGrade: targetGrade,
        userName: userName,
        notificationTime: notificationTime,
        hasCompletedOnboarding: hasCompletedOnboarding,
        isLoading: false, // Loading complete
      );
      AppLogger.debug('DEBUG LOAD: ========== LOADING PREFERENCES COMPLETE ==========');
    } catch (e, stackTrace) {
      AppLogger.debug('ERROR LOAD: Error loading user preferences: $e');
      AppLogger.debug('ERROR LOAD: Stack trace: $stackTrace');
      // Even on error, set loading to false so UI doesn't hang
      state = state.copyWith(isLoading: false);
    }
  }

  /// Apply preferences from Firestore map
  void _applyPreferencesFromMap(Map<String, dynamic> map) {
    state = UserPreferences(
      enableThreeStateTaskToggle: map[_threeStateToggleKey] as bool? ?? false,
      customLectureColor: map[_lectureColorKey] != null ? Color(map[_lectureColorKey] as int) : null,
      customLabTutorialColor: map[_labTutorialColorKey] != null ? Color(map[_labTutorialColorKey] as int) : null,
      customAssignmentColor: map[_assignmentColorKey] != null ? Color(map[_assignmentColorKey] as int) : null,
      targetGrade: (map[_targetGradeKey] as num?)?.toDouble() ?? 70.0,
      userName: map[_userNameKey] as String?,
      notificationTime: map[_notificationTimeKey] as String?,
      hasCompletedOnboarding: map[_hasCompletedOnboardingKey] as bool? ?? false,
      isLoading: false, // Loading complete from Firestore
    );
  }

  /// Cache Firestore preferences to Hive for offline access
  Future<void> _cachePreferencesToHive(Map<String, dynamic> firestorePrefs) async {
    try {
      final box = await _ensureBox();
      for (final entry in firestorePrefs.entries) {
        await box.put(_getUserKey(entry.key), entry.value);
      }
      AppLogger.debug('DEBUG: Cached Firestore preferences to Hive');
    } catch (e) {
      AppLogger.debug('Error caching preferences to Hive: $e');
    }
  }

  /// Save current state to Firestore
  Future<void> _syncToFirestore() async {
    if (_userId == null || _userId!.isEmpty) {
      AppLogger.debug('DEBUG: No user ID, skipping Firestore sync');
      return;
    }

    try {
      final map = <String, dynamic>{
        _threeStateToggleKey: state.enableThreeStateTaskToggle,
        _targetGradeKey: state.targetGrade,
        _hasCompletedOnboardingKey: state.hasCompletedOnboarding,
      };

      if (state.customLectureColor != null) {
        map[_lectureColorKey] = state.customLectureColor!.value;
      }
      if (state.customLabTutorialColor != null) {
        map[_labTutorialColorKey] = state.customLabTutorialColor!.value;
      }
      if (state.customAssignmentColor != null) {
        map[_assignmentColorKey] = state.customAssignmentColor!.value;
      }
      if (state.userName != null) {
        map[_userNameKey] = state.userName!;
      }
      if (state.notificationTime != null) {
        map[_notificationTimeKey] = state.notificationTime!;
      }

      await _repository.saveUserPreferences(_userId!, map);
      AppLogger.debug('DEBUG: Synced preferences to Firestore');
    } catch (e) {
      AppLogger.debug('Error syncing to Firestore: $e');
    }
  }

  /// Toggle three-state task mode
  Future<void> setThreeStateTaskToggle(bool enabled) async {
    state = state.copyWith(enableThreeStateTaskToggle: enabled);

    try {
      final box = await _ensureBox();
      await box.put(_getUserKey(_threeStateToggleKey), enabled);
      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('Error saving three-state toggle preference: $e');
    }
  }

  /// Set custom lecture color
  Future<void> setLectureColor(Color color) async {
    state = state.copyWith(customLectureColor: color);

    try {
      final box = await _ensureBox();
      // ignore: deprecated_member_use
      await box.put(_getUserKey(_lectureColorKey), color.value);
      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('Error saving lecture color: $e');
    }
  }

  /// Set custom lab/tutorial color
  Future<void> setLabTutorialColor(Color color) async {
    state = state.copyWith(customLabTutorialColor: color);

    try {
      final box = await _ensureBox();
      // ignore: deprecated_member_use
      await box.put(_getUserKey(_labTutorialColorKey), color.value);
      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('Error saving lab/tutorial color: $e');
    }
  }

  /// Set custom assignment color
  Future<void> setAssignmentColor(Color color) async {
    state = state.copyWith(customAssignmentColor: color);

    try {
      final box = await _ensureBox();
      // ignore: deprecated_member_use
      await box.put(_getUserKey(_assignmentColorKey), color.value);
      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('Error saving assignment color: $e');
    }
  }

  /// Set target grade
  Future<void> setTargetGrade(double grade) async {
    state = state.copyWith(targetGrade: grade);

    try {
      final box = await _ensureBox();
      await box.put(_getUserKey(_targetGradeKey), grade);
      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('Error saving target grade: $e');
    }
  }

  /// Set user name
  Future<void> setUserName(String name) async {
    AppLogger.debug(' SAVE: setUserName called with: $name, userId: $_userId');
    state = state.copyWith(userName: () => name);
    AppLogger.debug(' SAVE: State updated, userName is now: ${state.userName}');

    try {
      final box = await _ensureBox();
      final key = _getUserKey(_userNameKey);
      await box.put(key, name);
      AppLogger.debug('DEBUG SAVE: User name saved to Hive: $name (key: $key)');

      // Verify it was saved
      final verify = box.get(key);
      AppLogger.debug('DEBUG SAVE: Verification read from Hive: $verify');

      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('ERROR SAVE: Error saving user name: $e');
      AppLogger.debug('ERROR SAVE: Stack trace: ${StackTrace.current}');
    }
  }

  /// Set notification time
  Future<void> setNotificationTime(String time) async {
    state = state.copyWith(notificationTime: time);

    try {
      final box = await _ensureBox();
      await box.put(_getUserKey(_notificationTimeKey), time);
      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('Error saving notification time: $e');
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding() async {
    AppLogger.debug(' SAVE: completeOnboarding called, userId: $_userId');
    state = state.copyWith(hasCompletedOnboarding: true);
    AppLogger.debug(' SAVE: State updated, hasCompletedOnboarding is now: ${state.hasCompletedOnboarding}');
    AppLogger.debug(' SAVE: Current state - userName: ${state.userName}');

    try {
      final box = await _ensureBox();
      final key = _getUserKey(_hasCompletedOnboardingKey);
      await box.put(key, true);
      AppLogger.debug('DEBUG SAVE: Onboarding completed and saved to Hive (key: $key)');

      // Verify all data is in Hive
      final verifyName = box.get(_getUserKey(_userNameKey));
      final verifyOnboarding = box.get(key);
      AppLogger.debug('DEBUG SAVE: VERIFICATION - Name: $verifyName, Onboarding: $verifyOnboarding');

      await _syncToFirestore();
    } catch (e) {
      AppLogger.debug('ERROR SAVE: Error saving onboarding status: $e');
      AppLogger.debug('ERROR SAVE: Stack trace: ${StackTrace.current}');
    }
  }
}

/// User preferences provider
/// Automatically uses the current Firebase user's ID for user-specific storage
final userPreferencesProvider = StateNotifierProvider<UserPreferencesNotifier, UserPreferences>((ref) {
  // Import Firebase Auth to get current user
  // Note: We need to add this import at the top of the file
  final currentUser = ref.watch(currentUserProvider);
  final userId = currentUser?.uid;
  final repository = FirestoreRepository();

  AppLogger.debug(' Creating UserPreferencesNotifier for user: $userId');
  return UserPreferencesNotifier(userId: userId, repository: repository);
});

// Provider to track when user is dragging over checkboxes (prevents scroll)
final isDraggingCheckboxProvider = StateProvider<bool>((ref) => false);
