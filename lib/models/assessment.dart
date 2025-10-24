import 'package:cloud_firestore/cloud_firestore.dart';

enum AssessmentType {
  coursework,
  exam,
  weekly,
}

enum AssessmentStatus {
  notStarted,
  submitted,
  graded,
}

enum AssessmentPriority {
  high,
  medium,
  low,
  optional,
}

enum SubmitTiming {
  startOfNextWeek, // Due on the start of the following week
  endOfCurrentWeek, // Due at the end of the current week
}

class Assessment {
  final String id;
  final String moduleId;
  final String name;
  final AssessmentType type;
  final AssessmentStatus status; // Stage of the assessment
  final AssessmentPriority priority; // Priority level of the assessment
  final DateTime? dueDate; // Optional - can be TBC
  final double weighting; // Percentage (0-100)
  final int? weekNumber; // Optional - calculated from dueDate if available
  final double? score; // Optional, for grade tracking
  final double? markEarned; // Actual mark/percentage earned (0-100)
  final String? description; // Optional description with details
  final int? startWeek; // For weekly assessments - starting week
  final int? endWeek; // For weekly assessments - ending week
  final int? dayOfWeek; // For weekly assessments - day of week (1=Mon, 7=Sun)
  final SubmitTiming? submitTiming; // For weekly assessments - when submissions are due
  final String? time; // For weekly assessments - time of day (e.g., "09:00")
  final bool showInCalendar; // Whether to show this assessment in the calendar view

  Assessment({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.type,
    this.status = AssessmentStatus.notStarted,
    this.priority = AssessmentPriority.medium,
    this.dueDate,
    required this.weighting,
    this.weekNumber,
    this.score,
    this.markEarned,
    this.description,
    this.startWeek,
    this.endWeek,
    this.dayOfWeek,
    this.submitTiming,
    this.time,
    this.showInCalendar = false,
  });

  factory Assessment.fromFirestore(DocumentSnapshot doc, String moduleId) {
    final data = doc.data() as Map<String, dynamic>;
    return Assessment(
      id: doc.id,
      moduleId: moduleId,
      name: data['name'] ?? '',
      type: AssessmentType.values.firstWhere(
        (e) => e.toString() == 'AssessmentType.${data['type']}',
        orElse: () => AssessmentType.coursework,
      ),
      status: data['status'] != null
          ? AssessmentStatus.values.firstWhere(
              (e) => e.toString() == 'AssessmentStatus.${data['status']}',
              orElse: () => AssessmentStatus.notStarted,
            )
          : AssessmentStatus.notStarted,
      priority: data['priority'] != null
          ? AssessmentPriority.values.firstWhere(
              (e) => e.toString() == 'AssessmentPriority.${data['priority']}',
              orElse: () => AssessmentPriority.medium,
            )
          : AssessmentPriority.medium,
      dueDate: data['dueDate'] != null ? (data['dueDate'] as Timestamp).toDate() : null,
      weighting: (data['weighting'] ?? 0.0).toDouble(),
      weekNumber: data['weekNumber'] as int?,
      score: data['score'] != null ? (data['score'] as num).toDouble() : null,
      markEarned: data['markEarned'] != null ? (data['markEarned'] as num).toDouble() : null,
      description: data['description'] as String?,
      startWeek: data['startWeek'] as int?,
      endWeek: data['endWeek'] as int?,
      dayOfWeek: data['dayOfWeek'] as int?,
      submitTiming: data['submitTiming'] != null
          ? SubmitTiming.values.firstWhere(
              (e) => e.toString() == 'SubmitTiming.${data['submitTiming']}',
              orElse: () => SubmitTiming.startOfNextWeek,
            )
          : null,
      time: data['time'] as String?,
      showInCalendar: data['showInCalendar'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'weighting': weighting,
      'weekNumber': weekNumber,
      'score': score,
      'markEarned': markEarned,
      'description': description,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'dayOfWeek': dayOfWeek,
      'submitTiming': submitTiming?.toString().split('.').last,
      'time': time,
      'showInCalendar': showInCalendar,
    };
  }

  // For local storage
  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      id: map['id'] ?? '',
      moduleId: map['moduleId'] ?? '',
      name: map['name'] ?? '',
      type: AssessmentType.values.firstWhere(
        (e) => e.toString() == 'AssessmentType.${map['type']}',
        orElse: () => AssessmentType.coursework,
      ),
      status: map['status'] != null
          ? AssessmentStatus.values.firstWhere(
              (e) => e.toString() == 'AssessmentStatus.${map['status']}',
              orElse: () => AssessmentStatus.notStarted,
            )
          : AssessmentStatus.notStarted,
      priority: map['priority'] != null
          ? AssessmentPriority.values.firstWhere(
              (e) => e.toString() == 'AssessmentPriority.${map['priority']}',
              orElse: () => AssessmentPriority.medium,
            )
          : AssessmentPriority.medium,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      weighting: (map['weighting'] ?? 0.0).toDouble(),
      weekNumber: map['weekNumber'] as int?,
      score: map['score'] != null ? (map['score'] as num).toDouble() : null,
      markEarned: map['markEarned'] != null ? (map['markEarned'] as num).toDouble() : null,
      description: map['description'] as String?,
      startWeek: map['startWeek'] as int?,
      endWeek: map['endWeek'] as int?,
      dayOfWeek: map['dayOfWeek'] as int?,
      submitTiming: map['submitTiming'] != null
          ? SubmitTiming.values.firstWhere(
              (e) => e.toString() == 'SubmitTiming.${map['submitTiming']}',
              orElse: () => SubmitTiming.startOfNextWeek,
            )
          : null,
      time: map['time'] as String?,
      showInCalendar: map['showInCalendar'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'moduleId': moduleId,
      'name': name,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'dueDate': dueDate?.toIso8601String(),
      'weighting': weighting,
      'weekNumber': weekNumber,
      'score': score,
      'markEarned': markEarned,
      'description': description,
      'startWeek': startWeek,
      'endWeek': endWeek,
      'dayOfWeek': dayOfWeek,
      'submitTiming': submitTiming?.toString().split('.').last,
      'time': time,
      'showInCalendar': showInCalendar,
    };
  }

  Assessment copyWith({
    String? id,
    String? moduleId,
    String? name,
    AssessmentType? type,
    AssessmentStatus? status,
    AssessmentPriority? priority,
    DateTime? dueDate,
    double? weighting,
    int? weekNumber,
    double? score,
    double? markEarned,
    String? description,
    int? startWeek,
    int? endWeek,
    int? dayOfWeek,
    SubmitTiming? submitTiming,
    String? time,
    bool? showInCalendar,
  }) {
    return Assessment(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      weighting: weighting ?? this.weighting,
      weekNumber: weekNumber ?? this.weekNumber,
      score: score ?? this.score,
      markEarned: markEarned ?? this.markEarned,
      description: description ?? this.description,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      submitTiming: submitTiming ?? this.submitTiming,
      time: time ?? this.time,
      showInCalendar: showInCalendar ?? this.showInCalendar,
    );
  }

  bool get isCompleted => score != null;

  // Calculate all due dates for weekly assessments
  List<DateTime> getWeeklyDueDates(DateTime semesterStartDate) {
    if (type != AssessmentType.weekly ||
        startWeek == null ||
        endWeek == null ||
        dayOfWeek == null ||
        submitTiming == null) {
      return [];
    }

    final dueDates = <DateTime>[];

    for (int week = startWeek!; week <= endWeek!; week++) {
      // Get the start of this week (Monday)
      final weekStartDate = semesterStartDate.add(Duration(days: (week - 1) * 7));

      DateTime dueDate;

      if (submitTiming == SubmitTiming.startOfNextWeek) {
        // Due on specified day of NEXT week
        final nextWeekStart = weekStartDate.add(const Duration(days: 7));
        dueDate = nextWeekStart.add(Duration(days: dayOfWeek! - 1));
      } else {
        // Due on specified day of CURRENT week
        dueDate = weekStartDate.add(Duration(days: dayOfWeek! - 1));
      }

      dueDates.add(dueDate);
    }

    return dueDates;
  }
}