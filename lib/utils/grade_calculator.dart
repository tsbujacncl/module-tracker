import 'package:flutter/material.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/module.dart';

/// Utility class for calculating grades and providing grade-related formatting
class GradeCalculator {
  /// Calculate grade for a single module based on its assessments
  /// Returns null if no assessments are graded yet
  static double? calculateModuleGrade(List<Assessment> assessments) {
    // Filter only graded assessments (where markEarned is not null)
    final gradedAssessments = assessments
        .where((a) => a.markEarned != null)
        .toList();

    if (gradedAssessments.isEmpty) {
      return null;
    }

    // Calculate weighted average: Σ(markEarned × weighting) / Σ(weighting)
    double totalWeightedMarks = 0.0;
    double totalWeighting = 0.0;

    for (final assessment in gradedAssessments) {
      totalWeightedMarks += assessment.markEarned! * assessment.weighting;
      totalWeighting += assessment.weighting;
    }

    // If no weighting, return null
    if (totalWeighting == 0) {
      return null;
    }

    return totalWeightedMarks / totalWeighting;
  }

  /// Calculate overall semester grade based on all modules
  /// Weights by module credits
  /// Returns null if no modules have grades
  static double? calculateSemesterGrade(
    List<Module> modules,
    Map<String, List<Assessment>> assessmentsByModule,
  ) {
    double totalWeightedGrade = 0.0;
    double totalCredits = 0.0;

    for (final module in modules) {
      final assessments = assessmentsByModule[module.id] ?? [];
      final moduleGrade = calculateModuleGrade(assessments);

      if (moduleGrade != null) {
        totalWeightedGrade += moduleGrade * module.credits;
        totalCredits += module.credits;
      }
    }

    // If no modules have grades, return null
    if (totalCredits == 0) {
      return null;
    }

    return totalWeightedGrade / totalCredits;
  }

  /// Get color based on grade and target
  /// - Green: >= target (met goal)
  /// - Yellow/Amber: 40 <= grade < target (pass)
  /// - Red: < 40 (fail)
  /// - Grey: null (no data)
  static Color getGradeColor(double? grade, double targetGrade) {
    if (grade == null) {
      return const Color(0xFF94A3B8); // Grey - no data
    }

    if (grade >= targetGrade) {
      return const Color(0xFF10B981); // Green - met target
    }

    if (grade >= 40.0) {
      return const Color(0xFFF59E0B); // Amber/Yellow - pass
    }

    return const Color(0xFFEF4444); // Red - fail
  }

  /// Format grade text for display
  static String formatGradeText(double? grade) {
    if (grade == null) {
      return 'No grades yet';
    }

    return 'Overall: ${grade.toStringAsFixed(1)}%';
  }

  /// Get grade classification text (UK system)
  static String? getGradeClassification(double? grade) {
    if (grade == null) return null;

    if (grade >= 70) return 'First Class';
    if (grade >= 60) return 'Upper Second (2:1)';
    if (grade >= 50) return 'Lower Second (2:2)';
    if (grade >= 40) return 'Third Class';
    return 'Fail';
  }

  /// Calculate number of graded modules
  static int countGradedModules(
    List<Module> modules,
    Map<String, List<Assessment>> assessmentsByModule,
  ) {
    int count = 0;

    for (final module in modules) {
      final assessments = assessmentsByModule[module.id] ?? [];
      if (calculateModuleGrade(assessments) != null) {
        count++;
      }
    }

    return count;
  }
}
