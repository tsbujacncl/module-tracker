import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/models/recurring_task.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/task_completion.dart';
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

// Get modules for current semester
final currentSemesterModulesProvider = StreamProvider<List<Module>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);
  final semester = ref.watch(currentSemesterProvider);

  if (user == null || semester == null) {
    return Stream.value([]);
  }

  return repository.getModulesBySemester(user.uid, semester.id, activeOnly: true);
});

// Get recurring tasks for a specific module
final recurringTasksProvider = StreamProvider.family<List<RecurringTask>, String>((ref, moduleId) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getRecurringTasks(user.uid, moduleId);
});

// Get assessments for a specific module
final assessmentsProvider = StreamProvider.family<List<Assessment>, String>((ref, moduleId) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getAssessments(user.uid, moduleId);
});

// Get task completions for a module and week
final taskCompletionsProvider = StreamProvider.family<List<TaskCompletion>, ({String moduleId, int weekNumber})>((ref, params) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getTaskCompletions(user.uid, params.moduleId, params.weekNumber);
});

// Get all task completions for a module (for stats, etc.)
final allTaskCompletionsProvider = StreamProvider.family<List<TaskCompletion>, String>((ref, moduleId) {
  final user = ref.watch(currentUserProvider);
  final repository = ref.watch(firestoreRepositoryProvider);

  if (user == null) {
    return Stream.value([]);
  }

  return repository.getAllTaskCompletions(user.uid, moduleId);
});