import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringTaskType {
  lecture,
  lab,
  tutorial,
  flashcards,
  custom,
}

class RecurringTask {
  final String id;
  final String moduleId;
  final RecurringTaskType type;
  final int dayOfWeek; // 1-7, Monday=1
  final String? time; // Optional, for scheduled items like "09:00"
  final String name;

  RecurringTask({
    required this.id,
    required this.moduleId,
    required this.type,
    required this.dayOfWeek,
    this.time,
    required this.name,
  });

  factory RecurringTask.fromFirestore(DocumentSnapshot doc, String moduleId) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurringTask(
      id: doc.id,
      moduleId: moduleId,
      type: RecurringTaskType.values.firstWhere(
        (e) => e.toString() == 'RecurringTaskType.${data['type']}',
        orElse: () => RecurringTaskType.custom,
      ),
      dayOfWeek: data['dayOfWeek'] ?? 1,
      time: data['time'],
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString().split('.').last,
      'dayOfWeek': dayOfWeek,
      'time': time,
      'name': name,
    };
  }

  RecurringTask copyWith({
    String? id,
    String? moduleId,
    RecurringTaskType? type,
    int? dayOfWeek,
    String? time,
    String? name,
  }) {
    return RecurringTask(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      type: type ?? this.type,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      time: time ?? this.time,
      name: name ?? this.name,
    );
  }
}