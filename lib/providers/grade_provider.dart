import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/models/grade_calculation.dart';
import 'package:module_tracker/models/module.dart';
import 'package:module_tracker/providers/module_provider.dart';
import 'package:module_tracker/providers/semester_provider.dart';

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

/// Provider for all module grades across all semesters
final allModuleGradesProvider = Provider<List<ModuleGrade>>((ref) {
  final modulesAsync = ref.watch(activeModulesProvider);

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

/// Provider for overall average across all semesters (weighted by credits)
final overallAverageProvider = Provider<double>((ref) {
  final modulesAsync = ref.watch(activeModulesProvider);
  final allGrades = ref.watch(allModuleGradesProvider);

  if (allGrades.isEmpty) return 0.0;

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

  for (final grade in allGrades) {
    final credits = (moduleCreditsMap[grade.moduleId] ?? 1).toDouble();
    totalWeightedGrade += grade.currentGrade * credits;
    totalCredits += credits;
  }

  return totalCredits > 0 ? totalWeightedGrade / totalCredits : 0.0;
});

/// Provider for total credits earned across all modules
final totalCreditsEarnedProvider = Provider<int>((ref) {
  final modulesAsync = ref.watch(activeModulesProvider);

  return modulesAsync.maybeWhen(
    data: (modules) {
      return modules.fold<int>(0, (sum, module) => sum + module.credits);
    },
    orElse: () => 0,
  );
});

/// Provider for current semester credits
final semesterCreditsProvider = Provider<int>((ref) {
  final modulesAsync = ref.watch(currentSemesterModulesProvider);

  return modulesAsync.maybeWhen(
    data: (modules) {
      return modules.fold<int>(0, (sum, module) => sum + module.credits);
    },
    orElse: () => 0,
  );
});

/// Provider for semester completion percentage (how much of final grades have been assessed)
final semesterCompletionProvider = Provider<double>((ref) {
  final modulesAsync = ref.watch(currentSemesterModulesProvider);

  return modulesAsync.maybeWhen(
    data: (modules) {
      if (modules.isEmpty) return 0.0;

      double totalWeightage = 0.0;
      double completedWeightage = 0.0;

      for (final module in modules) {
        final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
        assessmentsAsync.whenData((assessments) {
          for (final assessment in assessments) {
            totalWeightage += assessment.weighting;
            if (assessment.markEarned != null) {
              completedWeightage += assessment.weighting;
            }
          }
        });
      }

      return totalWeightage > 0 ? (completedWeightage / totalWeightage) * 100 : 0.0;
    },
    orElse: () => 0.0,
  );
});

/// Provider for semester contribution (actual percentage earned towards final grade)
final semesterContributionProvider = Provider<double>((ref) {
  final average = ref.watch(semesterAverageProvider);
  final completion = ref.watch(semesterCompletionProvider);
  return average * completion / 100;
});

/// Provider for total assessments count across semester (completed, total)
final totalAssessmentsCountProvider = Provider<(int, int)>((ref) {
  final modulesAsync = ref.watch(currentSemesterModulesProvider);

  return modulesAsync.maybeWhen(
    data: (modules) {
      if (modules.isEmpty) return (0, 0);

      int totalCount = 0;
      int completedCount = 0;

      for (final module in modules) {
        final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
        assessmentsAsync.whenData((assessments) {
          totalCount += assessments.length;
          completedCount += assessments.where((a) => a.markEarned != null).length;
        });
      }

      return (completedCount, totalCount);
    },
    orElse: () => (0, 0),
  );
});

/// Provider for total assessments count for a specific semester (completed, total)
final semesterAssessmentsCountProvider = Provider.family<(int, int), String>((ref, semesterId) {
  final modulesAsync = ref.watch(modulesForSemesterProvider(semesterId));

  return modulesAsync.maybeWhen(
    data: (modules) {
      if (modules.isEmpty) return (0, 0);

      int totalCount = 0;
      int completedCount = 0;

      for (final module in modules) {
        final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
        assessmentsAsync.whenData((assessments) {
          totalCount += assessments.length;
          completedCount += assessments.where((a) => a.markEarned != null).length;
        });
      }

      return (completedCount, totalCount);
    },
    orElse: () => (0, 0),
  );
});

/// Provider for accounted credits in a semester (accounted, total)
final accountedCreditsProvider = Provider.family<(int, int), String>((ref, semesterId) {
  final modulesAsync = ref.watch(modulesForSemesterProvider(semesterId));

  return modulesAsync.maybeWhen(
    data: (modules) {
      if (modules.isEmpty) return (0, 0);

      int totalCredits = 0;
      int accountedCredits = 0;

      for (final module in modules) {
        totalCredits += module.credits.toInt();

        // Check if module has at least one assessment
        final assessmentsAsync = ref.watch(assessmentsProvider(module.id));
        assessmentsAsync.whenData((assessments) {
          if (assessments.isNotEmpty) {
            accountedCredits += module.credits.toInt();
          }
        });
      }

      return (accountedCredits, totalCredits);
    },
    orElse: () => (0, 0),
  );
});

/// Provider for semester overall grade (specific semester)
final semesterOverallGradeProvider = Provider.family<(double, String)?, String>((ref, semesterId) {
  final modulesAsync = ref.watch(modulesForSemesterProvider(semesterId));

  return modulesAsync.maybeWhen(
    data: (modules) {
      if (modules.isEmpty) return null;

      double totalWeightedGrade = 0.0;
      double totalCreditsCompleted = 0.0;

      for (final module in modules) {
        final moduleCredits = module.credits.toDouble();
        final assessmentsAsync = ref.watch(assessmentsProvider(module.id));

        assessmentsAsync.whenData((assessments) {
          if (assessments.isEmpty) return;

          // Calculate total weighting and completed weighting
          double totalWeighting = 0.0;
          double completedWeighting = 0.0;
          double earnedPoints = 0.0;

          for (final assessment in assessments) {
            totalWeighting += assessment.weighting;
            if (assessment.markEarned != null) {
              completedWeighting += assessment.weighting;
              // Calculate weighted points
              earnedPoints += (assessment.markEarned! / 100) * assessment.weighting;
            }
          }

          // Calculate proportional credits based on completed weighting
          if (completedWeighting > 0 && totalWeighting > 0) {
            final proportionalCredits = moduleCredits * (completedWeighting / totalWeighting);
            totalCreditsCompleted += proportionalCredits;

            // Calculate module contribution
            totalWeightedGrade += earnedPoints * (proportionalCredits / 100);
          }
        });
      }

      if (totalCreditsCompleted == 0) return null;

      // Calculate overall percentage
      final overallPercentage = (totalWeightedGrade / totalCreditsCompleted) * 100;
      final classification = GradeCalculator.percentageToUKClassification(overallPercentage);

      return (overallPercentage, classification);
    },
    orElse: () => null,
  );
});

/// Provider for current semester overall grade
final currentSemesterOverallGradeProvider = Provider<(double, String)?>((ref) {
  final currentSemester = ref.watch(currentSemesterProvider);
  if (currentSemester == null) return null;

  return ref.watch(semesterOverallGradeProvider(currentSemester.id));
});
