import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus {
  notStarted,
  inProgress,
  complete,
}

class TaskCompletion {
  final String id;
  final String moduleId;
  final String taskId; // Reference to recurringTasks or assessments
  final int weekNumber;
  final TaskStatus status;
  final DateTime? completedAt;

  TaskCompletion({
    required this.id,
    required this.moduleId,
    required this.taskId,
    required this.weekNumber,
    required this.status,
    this.completedAt,
  });

  factory TaskCompletion.fromFirestore(DocumentSnapshot doc, String moduleId) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskCompletion(
      id: doc.id,
      moduleId: moduleId,
      taskId: data['taskId'] ?? '',
      weekNumber: data['weekNumber'] ?? 1,
      status: TaskStatus.values.firstWhere(
        (e) => e.toString() == 'TaskStatus.${data['status']}',
        orElse: () => TaskStatus.notStarted,
      ),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'taskId': taskId,
      'weekNumber': weekNumber,
      'status': status.toString().split('.').last,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  TaskCompletion copyWith({
    String? id,
    String? moduleId,
    String? taskId,
    int? weekNumber,
    TaskStatus? status,
    DateTime? completedAt,
  }) {
    return TaskCompletion(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      taskId: taskId ?? this.taskId,
      weekNumber: weekNumber ?? this.weekNumber,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}