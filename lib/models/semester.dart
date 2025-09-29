import 'package:cloud_firestore/cloud_firestore.dart';

class Semester {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfWeeks;
  final DateTime createdAt;

  Semester({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.numberOfWeeks,
    required this.createdAt,
  });

  factory Semester.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Semester(
      id: doc.id,
      name: data['name'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      numberOfWeeks: data['numberOfWeeks'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfWeeks': numberOfWeeks,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Semester copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfWeeks,
    DateTime? createdAt,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfWeeks: numberOfWeeks ?? this.numberOfWeeks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}