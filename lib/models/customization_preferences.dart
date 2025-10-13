/// User customization preferences
class CustomizationPreferences {
  final FontSize fontSize;
  final WeekStartDay weekStartDay;
  final TaskView defaultTaskView;
  final GradeDisplayFormat gradeDisplayFormat;

  const CustomizationPreferences({
    this.fontSize = FontSize.medium,
    this.weekStartDay = WeekStartDay.monday,
    this.defaultTaskView = TaskView.calendar,
    this.gradeDisplayFormat = GradeDisplayFormat.percentage,
  });

  CustomizationPreferences copyWith({
    FontSize? fontSize,
    WeekStartDay? weekStartDay,
    TaskView? defaultTaskView,
    GradeDisplayFormat? gradeDisplayFormat,
  }) {
    return CustomizationPreferences(
      fontSize: fontSize ?? this.fontSize,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      defaultTaskView: defaultTaskView ?? this.defaultTaskView,
      gradeDisplayFormat: gradeDisplayFormat ?? this.gradeDisplayFormat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize.index,
      'weekStartDay': weekStartDay.index,
      'defaultTaskView': defaultTaskView.index,
      'gradeDisplayFormat': gradeDisplayFormat.index,
    };
  }

  factory CustomizationPreferences.fromMap(Map<String, dynamic> map) {
    return CustomizationPreferences(
      fontSize: FontSize.values[map['fontSize'] as int? ?? 1],
      weekStartDay: WeekStartDay.values[map['weekStartDay'] as int? ?? 0],
      defaultTaskView: TaskView.values[map['defaultTaskView'] as int? ?? 0],
      gradeDisplayFormat: GradeDisplayFormat.values[map['gradeDisplayFormat'] as int? ?? 0],
    );
  }
}

/// Font size options
enum FontSize {
  small,
  medium,
  large;

  String get displayName {
    switch (this) {
      case FontSize.small:
        return 'Small';
      case FontSize.medium:
        return 'Medium';
      case FontSize.large:
        return 'Large';
    }
  }

  double get scaleFactor {
    switch (this) {
      case FontSize.small:
        return 0.9;
      case FontSize.medium:
        return 1.0;
      case FontSize.large:
        return 1.1;
    }
  }
}

/// Week start day options
enum WeekStartDay {
  monday,
  sunday;

  String get displayName {
    switch (this) {
      case WeekStartDay.monday:
        return 'Monday';
      case WeekStartDay.sunday:
        return 'Sunday';
    }
  }

  int get weekdayNumber {
    switch (this) {
      case WeekStartDay.monday:
        return 1;
      case WeekStartDay.sunday:
        return 7;
    }
  }
}

/// Task view options
enum TaskView {
  calendar,
  list;

  String get displayName {
    switch (this) {
      case TaskView.calendar:
        return 'Calendar';
      case TaskView.list:
        return 'List';
    }
  }
}

/// Grade display format options
enum GradeDisplayFormat {
  percentage,
  letter,
  gpa;

  String get displayName {
    switch (this) {
      case GradeDisplayFormat.percentage:
        return 'Percentage (40%, 70%, etc.)';
      case GradeDisplayFormat.letter:
        return 'Letter (A, B+, etc.)';
      case GradeDisplayFormat.gpa:
        return 'GPA (3.5, 4.0, etc.)';
    }
  }

  String formatGrade(double percentage) {
    switch (this) {
      case GradeDisplayFormat.percentage:
        return '${percentage.toStringAsFixed(1)}%';
      case GradeDisplayFormat.letter:
        return _getLetterGrade(percentage);
      case GradeDisplayFormat.gpa:
        return _getGPA(percentage).toStringAsFixed(2);
    }
  }

  String _getLetterGrade(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 85) return 'A-';
    if (percentage >= 80) return 'B+';
    if (percentage >= 75) return 'B';
    if (percentage >= 70) return 'B-';
    if (percentage >= 65) return 'C+';
    if (percentage >= 60) return 'C';
    if (percentage >= 55) return 'C-';
    if (percentage >= 50) return 'D';
    return 'F';
  }

  double _getGPA(double percentage) {
    if (percentage >= 90) return 4.0;
    if (percentage >= 85) return 3.7;
    if (percentage >= 80) return 3.3;
    if (percentage >= 75) return 3.0;
    if (percentage >= 70) return 2.7;
    if (percentage >= 65) return 2.3;
    if (percentage >= 60) return 2.0;
    if (percentage >= 55) return 1.7;
    if (percentage >= 50) return 1.0;
    return 0.0;
  }
}
