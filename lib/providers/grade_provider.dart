import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/grade_calculation.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/providers/module_provider.dart';

/// Grade settings for a specific module
final moduleGradeSettingsProvider = StateProvider.family<GradeSettings, String>(
  (ref, moduleId) => const GradeSettings(targetGrade: 70.0),
);

/// Provider for calculated grade of a specific module
final moduleGradeProvider = Provider.family<ModuleGrade?, String>((ref, moduleId) {
  final assessmentsAsync = ref.watch(assessmentsProvider(moduleId));
  final gradeSettings = ref.watch(moduleGradeSettingsProvider(moduleId));

  return assessmentsAsync.maybeWhen(
    data: (assessments) {
      return GradeCalculator.calculateModuleGrade(
        moduleId,
        assessments,
        targetGrade: gradeSettings.targetGrade,
      );
    },
    orElse: () => null,
  );
});

/// Provider for all module grades in current semester
final semesterGradesProvider = Provider<List<ModuleGrade>>((ref) {
  final modulesAsync = ref.watch(currentSemesterModulesProvider);

  return modulesAsync.maybeWhen(
    data: (modules) {
      final grades = <ModuleGrade>[];

      for (final module in modules) {
        final moduleGrade = ref.watch(moduleGradeProvider(module.id));
        if (moduleGrade != null) {
          grades.add(moduleGrade);
        }
      }

      return grades;
    },
    orElse: () => [],
  );
});

/// Provider for semester GPA calculation
final semesterGPAProvider = Provider<double>((ref) {
  final modulesAsync = ref.watch(currentSemesterModulesProvider);
  final semesterGrades = ref.watch(semesterGradesProvider);

  final moduleCreditsMap = modulesAsync.maybeWhen(
    data: (modules) {
      return Map<String, int>.fromEntries(
        modules.map((m) => MapEntry(m.id, m.credits)),
      );
    },
    orElse: () => <String, int>{},
  );

  return GradeCalculator.calculateSemesterGPA(semesterGrades, moduleCreditsMap);
});

/// Provider for semester average percentage
final semesterAverageProvider = Provider<double>((ref) {
  final modulesAsync = ref.watch(currentSemesterModulesProvider);
  final semesterGrades = ref.watch(semesterGradesProvider);

  if (semesterGrades.isEmpty) return 0.0;

  final moduleCreditsMap = modulesAsync.maybeWhen(
    data: (modules) {
      return Map<String, int>.fromEntries(
        modules.map((m) => MapEntry(m.id, m.credits)),
      );
    },
    orElse: () => <String, int>{},
  );

  double totalWeightedGrade = 0.0;
  double totalCredits = 0.0;

  for (final grade in semesterGrades) {
    final credits = (moduleCreditsMap[grade.moduleId] ?? 1).toDouble();
    totalWeightedGrade += grade.currentGrade * credits;
    totalCredits += credits;
  }

  return totalCredits > 0 ? totalWeightedGrade / totalCredits : 0.0;
});

/// Provider for grade status of a module
final moduleGradeStatusProvider = Provider.family<GradeStatus, String>((ref, moduleId) {
  final moduleGrade = ref.watch(moduleGradeProvider(moduleId));
  final gradeSettings = ref.watch(moduleGradeSettingsProvider(moduleId));

  if (moduleGrade == null) return GradeStatus.onTrack;

  return GradeCalculator.getGradeStatus(
    moduleGrade.currentGrade,
    gradeSettings.targetGrade,
    moduleGrade.projectedGrade,
  );
});
