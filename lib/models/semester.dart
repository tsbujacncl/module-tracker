import 'package:cloud_firestore/cloud_firestore.dart';

class Semester {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfWeeks;
  final DateTime? examPeriodStart;
  final DateTime? examPeriodEnd;
  final DateTime? readingWeekStart;
  final DateTime? readingWeekEnd;
  final DateTime createdAt;
  final bool isArchived;

  Semester({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.numberOfWeeks,
    this.examPeriodStart,
    this.examPeriodEnd,
    this.readingWeekStart,
    this.readingWeekEnd,
    required this.createdAt,
    this.isArchived = false,
  });

  factory Semester.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Semester(
      id: doc.id,
      name: data['name'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      numberOfWeeks: data['numberOfWeeks'] ?? 0,
      examPeriodStart: data['examPeriodStart'] != null ? (data['examPeriodStart'] as Timestamp).toDate() : null,
      examPeriodEnd: data['examPeriodEnd'] != null ? (data['examPeriodEnd'] as Timestamp).toDate() : null,
      readingWeekStart: data['readingWeekStart'] != null ? (data['readingWeekStart'] as Timestamp).toDate() : null,
      readingWeekEnd: data['readingWeekEnd'] != null ? (data['readingWeekEnd'] as Timestamp).toDate() : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isArchived: data['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfWeeks': numberOfWeeks,
      'examPeriodStart': examPeriodStart != null ? Timestamp.fromDate(examPeriodStart!) : null,
      'examPeriodEnd': examPeriodEnd != null ? Timestamp.fromDate(examPeriodEnd!) : null,
      'readingWeekStart': readingWeekStart != null ? Timestamp.fromDate(readingWeekStart!) : null,
      'readingWeekEnd': readingWeekEnd != null ? Timestamp.fromDate(readingWeekEnd!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
    };
  }

  // For local storage
  factory Semester.fromMap(Map<String, dynamic> map) {
    return Semester(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      numberOfWeeks: map['numberOfWeeks'] ?? 0,
      examPeriodStart: map['examPeriodStart'] != null ? DateTime.parse(map['examPeriodStart']) : null,
      examPeriodEnd: map['examPeriodEnd'] != null ? DateTime.parse(map['examPeriodEnd']) : null,
      readingWeekStart: map['readingWeekStart'] != null ? DateTime.parse(map['readingWeekStart']) : null,
      readingWeekEnd: map['readingWeekEnd'] != null ? DateTime.parse(map['readingWeekEnd']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      isArchived: map['isArchived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'numberOfWeeks': numberOfWeeks,
      'examPeriodStart': examPeriodStart?.toIso8601String(),
      'examPeriodEnd': examPeriodEnd?.toIso8601String(),
      'readingWeekStart': readingWeekStart?.toIso8601String(),
      'readingWeekEnd': readingWeekEnd?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isArchived': isArchived,
    };
  }

  Semester copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfWeeks,
    DateTime? examPeriodStart,
    DateTime? examPeriodEnd,
    DateTime? readingWeekStart,
    DateTime? readingWeekEnd,
    DateTime? createdAt,
    bool? isArchived,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfWeeks: numberOfWeeks ?? this.numberOfWeeks,
      examPeriodStart: examPeriodStart ?? this.examPeriodStart,
      examPeriodEnd: examPeriodEnd ?? this.examPeriodEnd,
      readingWeekStart: readingWeekStart ?? this.readingWeekStart,
      readingWeekEnd: readingWeekEnd ?? this.readingWeekEnd,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}