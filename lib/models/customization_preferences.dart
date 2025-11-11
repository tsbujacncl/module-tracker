/// User customization preferences
class CustomizationPreferences {
  final FontSize fontSize;
  final WeekStartDay weekStartDay;
  final TaskView defaultTaskView;

  const CustomizationPreferences({
    this.fontSize = FontSize.medium,
    this.weekStartDay = WeekStartDay.monday,
    this.defaultTaskView = TaskView.calendar,
  });

  CustomizationPreferences copyWith({
    FontSize? fontSize,
    WeekStartDay? weekStartDay,
    TaskView? defaultTaskView,
  }) {
    return CustomizationPreferences(
      fontSize: fontSize ?? this.fontSize,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      defaultTaskView: defaultTaskView ?? this.defaultTaskView,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize.index,
      'weekStartDay': weekStartDay.index,
      'defaultTaskView': defaultTaskView.index,
    };
  }

  factory CustomizationPreferences.fromMap(Map<String, dynamic> map) {
    return CustomizationPreferences(
      fontSize: FontSize.values[map['fontSize'] as int? ?? 1],
      weekStartDay: WeekStartDay.values[map['weekStartDay'] as int? ?? 0],
      defaultTaskView: TaskView.values[map['defaultTaskView'] as int? ?? 0],
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
