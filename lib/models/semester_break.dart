import 'package:cloud_firestore/cloud_firestore.dart';

class SemesterBreak {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  SemesterBreak({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  // Calculate duration in days
  int get durationInDays {
    return endDate.difference(startDate).inDays + 1;
  }

  // Get formatted duration string
  String get durationString {
    final days = durationInDays;
    if (days < 7) {
      return '$days ${days == 1 ? 'day' : 'days'}';
    } else {
      final weeks = (days / 7).round();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'}';
    }
  }

  // Check if a date falls within this break
  bool containsDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
    final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
    return (dateOnly.isAtSameMomentAs(startOnly) || dateOnly.isAfter(startOnly)) &&
        (dateOnly.isAtSameMomentAs(endOnly) || dateOnly.isBefore(endOnly));
  }

  // Firestore serialization
  factory SemesterBreak.fromFirestore(Map<String, dynamic> data, String id) {
    return SemesterBreak(
      id: id,
      name: data['name'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    };
  }

  // Local storage
  factory SemesterBreak.fromMap(Map<String, dynamic> map) {
    return SemesterBreak(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  SemesterBreak copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return SemesterBreak(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
