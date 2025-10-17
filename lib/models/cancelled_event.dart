import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  recurringTask,
  assessment,
}

class CancelledEvent {
  final String id;
  final String moduleId;
  final String eventId; // Reference to recurringTasks or assessments
  final int weekNumber;
  final EventType eventType;
  final DateTime cancelledAt;

  CancelledEvent({
    required this.id,
    required this.moduleId,
    required this.eventId,
    required this.weekNumber,
    required this.eventType,
    required this.cancelledAt,
  });

  factory CancelledEvent.fromFirestore(DocumentSnapshot doc, String moduleId) {
    final data = doc.data() as Map<String, dynamic>;
    return CancelledEvent(
      id: doc.id,
      moduleId: moduleId,
      eventId: data['eventId'] ?? '',
      weekNumber: data['weekNumber'] ?? 1,
      eventType: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${data['eventType']}',
        orElse: () => EventType.recurringTask,
      ),
      cancelledAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'eventId': eventId,
      'weekNumber': weekNumber,
      'eventType': eventType.toString().split('.').last,
      'cancelledAt': Timestamp.fromDate(cancelledAt),
    };
  }

  // For local storage
  factory CancelledEvent.fromMap(Map<String, dynamic> map) {
    return CancelledEvent(
      id: map['id'] ?? '',
      moduleId: map['moduleId'] ?? '',
      eventId: map['eventId'] ?? '',
      weekNumber: map['weekNumber'] ?? 1,
      eventType: EventType.values.firstWhere(
        (e) => e.toString() == 'EventType.${map['eventType']}',
        orElse: () => EventType.recurringTask,
      ),
      cancelledAt: map['cancelledAt'] != null
          ? DateTime.parse(map['cancelledAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'moduleId': moduleId,
      'eventId': eventId,
      'weekNumber': weekNumber,
      'eventType': eventType.toString().split('.').last,
      'cancelledAt': cancelledAt.toIso8601String(),
    };
  }

  CancelledEvent copyWith({
    String? id,
    String? moduleId,
    String? eventId,
    int? weekNumber,
    EventType? eventType,
    DateTime? cancelledAt,
  }) {
    return CancelledEvent(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      eventId: eventId ?? this.eventId,
      weekNumber: weekNumber ?? this.weekNumber,
      eventType: eventType ?? this.eventType,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
