import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/providers/user_preferences_provider.dart';

/// Check if today is the user's birthday (ignoring year)
bool isTodayBirthday(WidgetRef ref) {
  final birthday = ref.watch(userPreferencesProvider).birthday;
  if (birthday == null) return false;

  final now = DateTime.now();
  return now.month == birthday.month && now.day == birthday.day;
}

/// Check if a specific date is the user's birthday (ignoring year)
bool isDateBirthday(DateTime date, DateTime? birthday) {
  if (birthday == null) return false;
  return date.month == birthday.month && date.day == birthday.day;
}

/// Provider to track if birthday celebration was shown today
final birthdayCelebrationShownProvider = StateProvider<DateTime?>((ref) => null);

/// Check if we should show birthday celebration
/// (Only show once per day)
bool shouldShowBirthdayCelebration(WidgetRef ref) {
  if (!isTodayBirthday(ref)) return false;

  final lastShown = ref.read(birthdayCelebrationShownProvider);
  if (lastShown == null) return true;

  final now = DateTime.now();
  // Check if last shown was on a different day
  return lastShown.day != now.day ||
      lastShown.month != now.month ||
      lastShown.year != now.year;
}

/// Mark birthday celebration as shown today
void markBirthdayCelebrationShown(WidgetRef ref) {
  ref.read(birthdayCelebrationShownProvider.notifier).state = DateTime.now();
}
