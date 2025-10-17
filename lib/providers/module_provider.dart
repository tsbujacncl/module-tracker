import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/task_completion.dart';
import 'package:module_tracker/models/cancelled_event.dart';
import 'package:module_tracker/providers/auth_provider.dart';
import 'package:module_tracker/providers/repository_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';

// Get all active modules for current user
final activeModulesProvider = StreamProvider<List<Module>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getUserModules(user.uid, activeOnly: true);
});

// Get modules for a specific semester
final modulesForSemesterProvider = StreamProvider.family<List<Module>, String>((
  ref,
  semesterId,
) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null || semesterId.isEmpty) {
    return Stream.value([]);
  }

  return repository.getModulesBySemester(
    user.uid,
    semesterId,
    activeOnly: true,
  );
});

// Get modules for current semester
// Note: Not using autoDispose to prevent disposal issues during navigation
final currentSemesterModulesProvider = StreamProvider<List<Module>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  final semester = ref.watch(currentSemesterProvider);

  if (user == null || semester == null) {
    return Stream.value([]);
  }

  return repository.getModulesBySemester(
    user.uid,
    semester.id,
    activeOnly: true,
  );
});

// Get modules for selected semester (for week navigation)
final selectedSemesterModulesProvider = StreamProvider<List<Module>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  final semester = ref.watch(selectedSemesterProvider);

  if (user == null || semester == null) {
    return Stream.value([]);
  }

  return repository.getModulesBySemester(
    user.uid,
    semester.id,
    activeOnly: true,
  );
});

// Get recurring tasks for a specific module
final recurringTasksProvider =
    StreamProvider.family<List<RecurringTask>, String>((ref, moduleId) {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);

      if (user == null) {
        return Stream.value([]);
      }

      return repository.getRecurringTasks(user.uid, moduleId);
    });

// Get assessments for a specific module
final assessmentsProvider = StreamProvider.family<List<Assessment>, String>((
  ref,
  moduleId,
) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getAssessments(user.uid, moduleId);
});

// Get task completions for a module and week
final taskCompletionsProvider =
    StreamProvider.family<
      List<TaskCompletion>,
      ({String moduleId, int weekNumber})
    >((ref, params) {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);

      if (user == null) {
        return Stream.value([]);
      }

      return repository.getTaskCompletions(
        user.uid,
        params.moduleId,
        params.weekNumber,
      );
    });

// Get all task completions for a module (for stats, etc.)
final allTaskCompletionsProvider =
    StreamProvider.family<List<TaskCompletion>, String>((ref, moduleId) {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);

      if (user == null) {
        return Stream.value([]);
      }

      return repository.getAllTaskCompletions(user.uid, moduleId);
    });

// Get cancelled events for a module and week
final cancelledEventsProvider =
    StreamProvider.family<
      List<CancelledEvent>,
      ({String moduleId, int weekNumber})
    >((ref, params) {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);

      if (user == null) {
        return Stream.value([]);
      }

      return repository.getCancelledEvents(
        user.uid,
        params.moduleId,
        params.weekNumber,
      );
    });

// Get all cancelled events for a module
final allCancelledEventsProvider =
    StreamProvider.family<List<CancelledEvent>, String>((ref, moduleId) {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);

      if (user == null) {
        return Stream.value([]);
      }

      return repository.getAllCancelledEvents(user.uid, moduleId);
    });

// Get all recurring tasks for all modules in current semester (for calendar view)
final allCurrentSemesterTasksProvider =
    StreamProvider<Map<String, List<RecurringTask>>>((ref) async* {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);

      if (user == null) {
        yield {};
        return;
      }

      // Watch the modules stream
      await for (final modules in repository.getModulesBySemester(
        user.uid,
        ref.watch(currentSemesterProvider)?.id ?? '',
        activeOnly: true,
      )) {
        if (modules.isEmpty) {
          yield {};
          continue;
        }

        // Fetch all recurring tasks for all modules
        final tasksByModule = <String, List<RecurringTask>>{};

        for (final module in modules) {
          final tasks = await repository
              .getRecurringTasks(user.uid, module.id)
              .first;
          tasksByModule[module.id] = tasks;
        }

        yield tasksByModule;
      }
    });

// Get all recurring tasks for all modules in selected semester (for calendar view with week navigation)
final allSelectedSemesterTasksProvider =
    StreamProvider<Map<String, List<RecurringTask>>>((ref) async* {
      final user = ref.watch(currentUserProvider);
      final repository = ref.watch(firestoreRepositoryProvider);
      final semester = ref.watch(selectedSemesterProvider);

      if (user == null || semester == null) {
        yield {};
        return;
      }

      // Watch the modules stream
      await for (final modules in repository.getModulesBySemester(
        user.uid,
        semester.id,
        activeOnly: true,
      )) {
        if (modules.isEmpty) {
          yield {};
          continue;
        }

        // Fetch all recurring tasks for all modules
        final tasksByModule = <String, List<RecurringTask>>{};

        for (final module in modules) {
          final tasks = await repository
              .getRecurringTasks(user.uid, module.id)
              .first;
          tasksByModule[module.id] = tasks;
        }

        yield tasksByModule;
      }
    });
