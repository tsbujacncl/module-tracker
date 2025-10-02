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
  final String? endTime; // Optional end time for scheduled items like "10:00"
  final String name;
  final String? location; // Optional location for lectures/labs
  final String? parentTaskId; // For custom tasks linked to a lecture/lab

  RecurringTask({
    required this.id,
    required this.moduleId,
    required this.type,
    required this.dayOfWeek,
    this.time,
    this.endTime,
    required this.name,
    this.location,
    this.parentTaskId,
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
      endTime: data['endTime'],
      name: data['name'] ?? '',
      location: data['location'],
      parentTaskId: data['parentTaskId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString().split('.').last,
      'dayOfWeek': dayOfWeek,
      'time': time,
      'endTime': endTime,
      'name': name,
      'location': location,
      'parentTaskId': parentTaskId,
    };
  }

  // For local storage
  factory RecurringTask.fromMap(Map<String, dynamic> map) {
    return RecurringTask(
      id: map['id'] ?? '',
      moduleId: map['moduleId'] ?? '',
      type: RecurringTaskType.values.firstWhere(
        (e) => e.toString() == 'RecurringTaskType.${map['type']}',
        orElse: () => RecurringTaskType.custom,
      ),
      dayOfWeek: map['dayOfWeek'] ?? 1,
      time: map['time'],
      endTime: map['endTime'],
      name: map['name'] ?? '',
      location: map['location'],
      parentTaskId: map['parentTaskId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'moduleId': moduleId,
      'type': type.toString().split('.').last,
      'dayOfWeek': dayOfWeek,
      'time': time,
      'endTime': endTime,
      'name': name,
      'location': location,
      'parentTaskId': parentTaskId,
    };
  }

  RecurringTask copyWith({
    String? id,
    String? moduleId,
    RecurringTaskType? type,
    int? dayOfWeek,
    String? time,
    String? endTime,
    String? name,
    String? location,
    String? parentTaskId,
  }) {
    return RecurringTask(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      type: type ?? this.type,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      name: name ?? this.name,
      location: location ?? this.location,
      parentTaskId: parentTaskId ?? this.parentTaskId,
    );
  }
}