import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:module_tracker/models/semester_break.dart';

class Semester {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int numberOfWeeks;
  final int? totalCredits;
  final DateTime? examPeriodStart;
  final DateTime? examPeriodEnd;
  final DateTime? readingWeekStart;
  final DateTime? readingWeekEnd;
  final DateTime createdAt;
  final bool isArchived;
  final List<SemesterBreak> breaks;

  Semester({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.numberOfWeeks,
    this.totalCredits,
    this.examPeriodStart,
    this.examPeriodEnd,
    this.readingWeekStart,
    this.readingWeekEnd,
    required this.createdAt,
    this.isArchived = false,
    this.breaks = const [],
  });

  factory Semester.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse breaks array
    final breaksList = <SemesterBreak>[];
    if (data['breaks'] != null && data['breaks'] is List) {
      for (var i = 0; i < (data['breaks'] as List).length; i++) {
        final breakData = data['breaks'][i] as Map<String, dynamic>;
        breaksList.add(SemesterBreak.fromFirestore(breakData, 'break_$i'));
      }
    }

    return Semester(
      id: doc.id,
      name: data['name'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      numberOfWeeks: data['numberOfWeeks'] ?? 0,
      totalCredits: data['totalCredits'] as int?,
      examPeriodStart: data['examPeriodStart'] != null ? (data['examPeriodStart'] as Timestamp).toDate() : null,
      examPeriodEnd: data['examPeriodEnd'] != null ? (data['examPeriodEnd'] as Timestamp).toDate() : null,
      readingWeekStart: data['readingWeekStart'] != null ? (data['readingWeekStart'] as Timestamp).toDate() : null,
      readingWeekEnd: data['readingWeekEnd'] != null ? (data['readingWeekEnd'] as Timestamp).toDate() : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isArchived: data['isArchived'] ?? false,
      breaks: breaksList,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfWeeks': numberOfWeeks,
      'totalCredits': totalCredits,
      'examPeriodStart': examPeriodStart != null ? Timestamp.fromDate(examPeriodStart!) : null,
      'examPeriodEnd': examPeriodEnd != null ? Timestamp.fromDate(examPeriodEnd!) : null,
      'readingWeekStart': readingWeekStart != null ? Timestamp.fromDate(readingWeekStart!) : null,
      'readingWeekEnd': readingWeekEnd != null ? Timestamp.fromDate(readingWeekEnd!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'isArchived': isArchived,
      'breaks': breaks.map((b) => b.toFirestore()).toList(),
    };
  }

  // For local storage
  factory Semester.fromMap(Map<String, dynamic> map) {
    // Parse breaks array
    final breaksList = <SemesterBreak>[];
    if (map['breaks'] != null && map['breaks'] is List) {
      for (final breakData in map['breaks']) {
        breaksList.add(SemesterBreak.fromMap(breakData as Map<String, dynamic>));
      }
    }

    return Semester(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      numberOfWeeks: map['numberOfWeeks'] ?? 0,
      totalCredits: map['totalCredits'] as int?,
      examPeriodStart: map['examPeriodStart'] != null ? DateTime.parse(map['examPeriodStart']) : null,
      examPeriodEnd: map['examPeriodEnd'] != null ? DateTime.parse(map['examPeriodEnd']) : null,
      readingWeekStart: map['readingWeekStart'] != null ? DateTime.parse(map['readingWeekStart']) : null,
      readingWeekEnd: map['readingWeekEnd'] != null ? DateTime.parse(map['readingWeekEnd']) : null,
      createdAt: DateTime.parse(map['createdAt']),
      isArchived: map['isArchived'] ?? false,
      breaks: breaksList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'numberOfWeeks': numberOfWeeks,
      'totalCredits': totalCredits,
      'examPeriodStart': examPeriodStart?.toIso8601String(),
      'examPeriodEnd': examPeriodEnd?.toIso8601String(),
      'readingWeekStart': readingWeekStart?.toIso8601String(),
      'readingWeekEnd': readingWeekEnd?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isArchived': isArchived,
      'breaks': breaks.map((b) => b.toMap()).toList(),
    };
  }

  Semester copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? numberOfWeeks,
    int? totalCredits,
    DateTime? examPeriodStart,
    DateTime? examPeriodEnd,
    DateTime? readingWeekStart,
    DateTime? readingWeekEnd,
    DateTime? createdAt,
    bool? isArchived,
    List<SemesterBreak>? breaks,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      numberOfWeeks: numberOfWeeks ?? this.numberOfWeeks,
      totalCredits: totalCredits ?? this.totalCredits,
      examPeriodStart: examPeriodStart ?? this.examPeriodStart,
      examPeriodEnd: examPeriodEnd ?? this.examPeriodEnd,
      readingWeekStart: readingWeekStart ?? this.readingWeekStart,
      readingWeekEnd: readingWeekEnd ?? this.readingWeekEnd,
      createdAt: createdAt ?? this.createdAt,
      isArchived: isArchived ?? this.isArchived,
      breaks: breaks ?? this.breaks,
    );
  }
}