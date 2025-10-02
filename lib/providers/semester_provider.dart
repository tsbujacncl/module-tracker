import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';

// Get all semesters for current user
// Note: Not using autoDispose to prevent disposal issues during navigation
final semestersProvider = StreamProvider<List<Semester>>((ref) {
  print('DEBUG PROVIDER: semestersProvider initialized');
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    print('DEBUG PROVIDER: semestersProvider - no user, returning empty');
    return Stream.value([]);
  }

  print('DEBUG PROVIDER: semestersProvider - user found, setting up stream for UID: ${user.uid}');
  return repository.getUserSemesters(user.uid);
});

// Current/active semester provider (most recent non-archived)
final currentSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) {
      if (list.isEmpty) return null;
      // Return the most recent non-archived semester
      final activeSemesters = list.where((s) => !s.isArchived).toList();
      return activeSemesters.isNotEmpty ? activeSemesters.first : null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Archived semesters provider
final archivedSemestersProvider = Provider<List<Semester>>((ref) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) => list.where((s) => s.isArchived).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for current week number
final currentWeekNumberProvider = Provider<int>((ref) {
  final semester = ref.watch(currentSemesterProvider);
  if (semester == null) return 1;

  final now = DateTime.now();
  final daysSinceStart = now.difference(semester.startDate).inDays;
  final weekNumber = (daysSinceStart / 7).floor() + 1;

  // Clamp between 1 and numberOfWeeks
  return weekNumber.clamp(1, semester.numberOfWeeks);
});

// State provider for navigating weeks
final selectedWeekNumberProvider = StateProvider<int>((ref) {
  return ref.watch(currentWeekNumberProvider);
});