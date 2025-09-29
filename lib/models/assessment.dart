import 'package:cloud_firestore/cloud_firestore.dart';

enum AssessmentType {
  coursework,
  exam,
}

class Assessment {
  final String id;
  final String moduleId;
  final String name;
  final AssessmentType type;
  final DateTime dueDate;
  final double weighting; // Percentage (0-100)
  final int weekNumber; // Calculated from dueDate
  final double? score; // Optional, for grade tracking

  Assessment({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.type,
    required this.dueDate,
    required this.weighting,
    required this.weekNumber,
    this.score,
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
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      weighting: (data['weighting'] ?? 0.0).toDouble(),
      weekNumber: data['weekNumber'] ?? 1,
      score: data['score'] != null ? (data['score'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'dueDate': Timestamp.fromDate(dueDate),
      'weighting': weighting,
      'weekNumber': weekNumber,
      'score': score,
    };
  }

  Assessment copyWith({
    String? id,
    String? moduleId,
    String? name,
    AssessmentType? type,
    DateTime? dueDate,
    double? weighting,
    int? weekNumber,
    double? score,
  }) {
    return Assessment(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      name: name ?? this.name,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      weighting: weighting ?? this.weighting,
      weekNumber: weekNumber ?? this.weekNumber,
      score: score ?? this.score,
    );
  }

  bool get isCompleted => score != null;
}