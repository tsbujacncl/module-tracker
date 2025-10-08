import 'package:module_tracker/models/assessment.dart';

/// Grading scale types
enum GradeScale {
  percentage, // 0-100
  uk, // First Class (70+), Upper Second (60-69), etc.
  us4point0, // 4.0 scale (A=4.0, B=3.0, etc.)
}

/// Grade settings for a module
class GradeSettings {
  final double targetGrade; // Target grade (e.g., 70.0 for first class)
  final GradeScale scale;

  const GradeSettings({
    required this.targetGrade,
    this.scale = GradeScale.percentage,
  });

  GradeSettings copyWith({
    double? targetGrade,
    GradeScale? scale,
  }) {
    return GradeSettings(
      targetGrade: targetGrade ?? this.targetGrade,
      scale: scale ?? this.scale,
    );
  }
}

/// Calculated grade for a module
class ModuleGrade {
  final String moduleId;
  final double currentGrade; // Current grade based on completed assessments
  final double currentWeightage; // Total weightage of completed assessments
  final double projectedGrade; // Projected final grade
  final double requiredAverage; // Required average on remaining assessments to meet target
  final bool isAchievable; // Whether target grade is still achievable
  final int completedAssessments;
  final int totalAssessments;

  const ModuleGrade({
    required this.moduleId,
    required this.currentGrade,
    required this.currentWeightage,
    required this.projectedGrade,
    required this.requiredAverage,
    required this.isAchievable,
    required this.completedAssessments,
    required this.totalAssessments,
  });
}

/// Grade calculation utilities
class GradeCalculator {
  /// Calculate the current grade for a module based on completed assessments
  static ModuleGrade calculateModuleGrade(
    String moduleId,
    List<Assessment> assessments, {
    double targetGrade = 70.0,
  }) {
    if (assessments.isEmpty) {
      return ModuleGrade(
        moduleId: moduleId,
        currentGrade: 0.0,
        currentWeightage: 0.0,
        projectedGrade: 0.0,
        requiredAverage: targetGrade,
        isAchievable: true,
        completedAssessments: 0,
        totalAssessments: 0,
      );
    }

    // Calculate total weighting
    final totalWeighting = assessments.fold<double>(
      0.0,
      (sum, a) => sum + (a.weighting ?? 0.0),
    );

    // Calculate completed assessments grade
    double earnedPoints = 0.0;
    double completedWeighting = 0.0;
    int completedCount = 0;

    for (final assessment in assessments) {
      if (assessment.markEarned != null) {
        // markEarned is already stored as a percentage (0-100)
        final percentage = assessment.markEarned!;
        final weightedPoints = percentage * (assessment.weighting ?? 0.0) / 100;
        earnedPoints += weightedPoints;
        completedWeighting += (assessment.weighting ?? 0.0);
        completedCount++;
      }
    }

    // Current grade (only from completed assessments)
    final currentGrade = completedWeighting > 0 ? earnedPoints : 0.0;

    // Remaining weighting
    final remainingWeighting = totalWeighting - completedWeighting;

    // Calculate what's needed on remaining assessments to hit target
    double requiredAverage = 0.0;
    bool isAchievable = true;

    if (remainingWeighting > 0) {
      // Points needed to reach target
      final pointsNeeded = targetGrade - earnedPoints;

      // Average required on remaining assessments (as percentage)
      requiredAverage = (pointsNeeded / remainingWeighting) * 100;

      // Check if achievable (can't score more than 100%)
      isAchievable = requiredAverage <= 100.0;
    } else {
      // All assessments completed
      requiredAverage = 0.0;
      isAchievable = currentGrade >= targetGrade;
    }

    // Projected grade (assuming average performance on remaining)
    double projectedGrade;
    if (remainingWeighting > 0 && completedCount > 0) {
      // Project based on current average
      final currentAverage = completedWeighting > 0
          ? (earnedPoints / completedWeighting) * 100
          : 0.0;
      final projectedRemainingPoints = (currentAverage / 100) * remainingWeighting;
      projectedGrade = earnedPoints + projectedRemainingPoints;
    } else if (remainingWeighting > 0) {
      // No completed assessments yet, project 70% on remaining
      projectedGrade = 0.70 * totalWeighting;
    } else {
      // All completed
      projectedGrade = currentGrade;
    }

    return ModuleGrade(
      moduleId: moduleId,
      currentGrade: currentGrade,
      currentWeightage: completedWeighting,
      projectedGrade: projectedGrade,
      requiredAverage: requiredAverage.clamp(0.0, 100.0),
      isAchievable: isAchievable,
      completedAssessments: completedCount,
      totalAssessments: assessments.length,
    );
  }

  /// Calculate "what if" scenario: what grade is needed on remaining assessments
  static double calculateRequiredGrade(
    List<Assessment> assessments,
    double targetFinalGrade,
  ) {
    double earnedPoints = 0.0;
    double completedWeighting = 0.0;
    double totalWeighting = 0.0;

    for (final assessment in assessments) {
      totalWeighting += (assessment.weighting ?? 0.0);

      if (assessment.markEarned != null) {
        // markEarned is already stored as a percentage (0-100)
        final percentage = assessment.markEarned!;
        final weightedPoints = percentage * (assessment.weighting ?? 0.0) / 100;
        earnedPoints += weightedPoints;
        completedWeighting += (assessment.weighting ?? 0.0);
      }
    }

    final remainingWeighting = totalWeighting - completedWeighting;

    if (remainingWeighting <= 0) {
      return 0.0; // All assessments completed
    }

    final pointsNeeded = targetFinalGrade - earnedPoints;
    final requiredPercentage = (pointsNeeded / remainingWeighting) * 100;

    return requiredPercentage.clamp(0.0, 100.0);
  }

  /// Convert percentage to letter grade (US system)
  static String percentageToLetterGrade(double percentage) {
    if (percentage >= 93) return 'A';
    if (percentage >= 90) return 'A-';
    if (percentage >= 87) return 'B+';
    if (percentage >= 83) return 'B';
    if (percentage >= 80) return 'B-';
    if (percentage >= 77) return 'C+';
    if (percentage >= 73) return 'C';
    if (percentage >= 70) return 'C-';
    if (percentage >= 67) return 'D+';
    if (percentage >= 63) return 'D';
    if (percentage >= 60) return 'D-';
    return 'F';
  }

  /// Convert percentage to UK classification
  static String percentageToUKClassification(double percentage) {
    if (percentage >= 70) return 'First Class';
    if (percentage >= 60) return 'Upper Second (2:1)';
    if (percentage >= 50) return 'Lower Second (2:2)';
    if (percentage >= 40) return 'Third Class';
    return 'Fail';
  }

  /// Convert percentage to GPA (4.0 scale)
  static double percentageToGPA(double percentage) {
    if (percentage >= 93) return 4.0;
    if (percentage >= 90) return 3.7;
    if (percentage >= 87) return 3.3;
    if (percentage >= 83) return 3.0;
    if (percentage >= 80) return 2.7;
    if (percentage >= 77) return 2.3;
    if (percentage >= 73) return 2.0;
    if (percentage >= 70) return 1.7;
    if (percentage >= 67) return 1.3;
    if (percentage >= 60) return 1.0;
    return 0.0;
  }

  /// Calculate semester GPA (weighted by credits)
  static double calculateSemesterGPA(
    List<ModuleGrade> moduleGrades,
    Map<String, int> moduleCredits,
  ) {
    if (moduleGrades.isEmpty) return 0.0;

    double totalWeightedGPA = 0.0;
    int totalCredits = 0;

    for (final grade in moduleGrades) {
      final credits = moduleCredits[grade.moduleId] ?? 1;
      final gpa = percentageToGPA(grade.currentGrade);
      totalWeightedGPA += gpa * credits;
      totalCredits += credits;
    }

    return totalCredits > 0 ? totalWeightedGPA / totalCredits : 0.0;
  }

  /// Get color indicator for grade achievement
  static GradeStatus getGradeStatus(
    double currentGrade,
    double targetGrade,
    double projectedGrade,
  ) {
    if (currentGrade >= targetGrade) {
      return GradeStatus.exceeding;
    } else if (projectedGrade >= targetGrade) {
      return GradeStatus.onTrack;
    } else if (projectedGrade >= targetGrade * 0.9) {
      return GradeStatus.nearlyThere;
    } else {
      return GradeStatus.atRisk;
    }
  }
}

/// Grade achievement status
enum GradeStatus {
  exceeding, // Already met target
  onTrack, // Projected to meet target
  nearlyThere, // Close to target (within 90%)
  atRisk, // Below target projection
}

/// Overall university grade across all semesters
class OverallGrade {
  final double overallPercentage; // Overall weighted percentage
  final double totalCreditsCompleted; // Total credits with grades
  final double totalCreditsPossible; // Total credits across all semesters
  final String classification; // UK classification (First, 2:1, etc.)
  final Map<String, SemesterGradeBreakdown> semesterBreakdown;

  const OverallGrade({
    required this.overallPercentage,
    required this.totalCreditsCompleted,
    required this.totalCreditsPossible,
    required this.classification,
    required this.semesterBreakdown,
  });
}

/// Breakdown of grades per semester
class SemesterGradeBreakdown {
  final String semesterId;
  final String semesterName;
  final double averagePercentage;
  final double creditsCompleted;
  final double creditsPossible;

  const SemesterGradeBreakdown({
    required this.semesterId,
    required this.semesterName,
    required this.averagePercentage,
    required this.creditsCompleted,
    required this.creditsPossible,
  });
}
