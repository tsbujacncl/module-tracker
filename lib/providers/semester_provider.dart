import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/semester.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/services/app_logger.dart';

// Get all semesters for current user
// Note: Not using autoDispose to prevent disposal issues during navigation
final semestersProvider = StreamProvider<List<Semester>>((ref) {
  AppLogger.debug(' PROVIDER: semestersProvider initialized');
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    AppLogger.debug(' PROVIDER: semestersProvider - no user, returning empty');
    return Stream.value([]);
  }

  AppLogger.debug('PROVIDER: semestersProvider - user found, setting up stream for UID: ${user.uid}');
  return repository.getUserSemesters(user.uid);
});

// FutureProvider to check and auto-archive completed semesters
// This should be triggered from the app initialization or home screen
final autoArchiveCompletedSemestersProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;

  final semestersAsync = ref.watch(semestersProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  await semestersAsync.when(
    data: (semesters) async {
      final now = DateTime.now();

      // Find semesters that have ended (end date is in the past)
      final completedSemesters = semesters.where(
        (s) => !s.isArchived && s.endDate.isBefore(now),
      ).toList();

      // Auto-archive modules for each completed semester
      for (final semester in completedSemesters) {
        try {
          await repository.autoArchiveSemesterModules(user.uid, semester.id);
          AppLogger.debug(': Auto-archived modules for semester: ${semester.name}');
        } catch (e) {
          AppLogger.debug(': Error auto-archiving modules for semester ${semester.name}: $e');
        }
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Current/active semester provider (semester where today falls between start and end dates)
final currentSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) {
      if (list.isEmpty) return null;

      final now = DateTime.now();
      final activeSemesters = list.where((s) => !s.isArchived).toList();

      // Find semester where current date is between start and end
      try {
        return activeSemesters.firstWhere(
          (s) => !now.isBefore(s.startDate) && !now.isAfter(s.endDate),
        );
      } catch (_) {
        // No active semester found, return most recent started semester
        final startedSemesters =
            activeSemesters.where((s) => s.startDate.isBefore(now)).toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate));

        return startedSemesters.isNotEmpty ? startedSemesters.first : null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Future semesters provider (non-archived semesters starting in the future)
final futureSemestersProvider = Provider<List<Semester>>((ref) {
  final semesters = ref.watch(semestersProvider);
  final currentSemester = ref.watch(currentSemesterProvider);

  return semesters.when(
    data: (list) {
      final now = DateTime.now();
      return list
          .where(
            (s) =>
                !s.isArchived &&
                s.startDate.isAfter(now) &&
                s.id != currentSemester?.id,
          )
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Archived semesters provider
final archivedSemestersProvider = Provider<List<Semester>>((ref) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) =>
        list.where((s) => s.isArchived).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate)),
    loading: () => [],
    error: (_, __) => [],
  );
});

// Provider for current week's start date (based on today)
final currentWeekStartDateProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  // Start of current week (Monday)
  return now.subtract(Duration(days: now.weekday - 1));
});

// State provider for selected week's start date (for navigation)
final selectedWeekStartDateProvider = StateProvider<DateTime>((ref) {
  return ref.watch(currentWeekStartDateProvider);
});

// Provider to find which semester a given date falls into
final semesterForDateProvider = Provider.family<Semester?, DateTime>((
  ref,
  date,
) {
  final semesters = ref.watch(semestersProvider);
  return semesters.when(
    data: (list) {
      try {
        // Find semester where date is between start and end
        return list.firstWhere(
          (s) =>
              !s.isArchived &&
              !date.isBefore(s.startDate) &&
              !date.isAfter(s.endDate),
        );
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Provider for the semester of the currently selected week
final selectedSemesterProvider = Provider<Semester?>((ref) {
  final selectedDate = ref.watch(selectedWeekStartDateProvider);
  return ref.watch(semesterForDateProvider(selectedDate));
});

// Provider for selected week number within its semester
final selectedWeekNumberProvider = Provider<int>((ref) {
  final semester = ref.watch(selectedSemesterProvider);
  final selectedDate = ref.watch(selectedWeekStartDateProvider);

  if (semester == null) return 1;

  final daysSinceStart = selectedDate.difference(semester.startDate).inDays;
  final weekNumber = (daysSinceStart / 7).floor() + 1;

  return weekNumber.clamp(1, semester.numberOfWeeks);
});
