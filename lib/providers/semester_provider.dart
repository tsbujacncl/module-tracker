import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';

// Get all semesters for current user
final semestersProvider = StreamProvider<List<Semester>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getUserSemesters(user.uid);
});

// Current/active semester provider (most recent)
final currentSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) {
      if (list.isEmpty) return null;
      // Return the most recent semester (first in list due to orderBy descending)
      return list.first;
    },
    loading: () => null,
    error: (_, __) => null,
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