import 'package:cloud_firestore/cloud_firestore.dart';

class Module {
  final String id;
  final String userId;
  final String name;
  final String code;
  final String semesterId;
  final bool isActive;
  final DateTime createdAt;
  final int credits;

  Module({
    required this.id,
    required this.userId,
    required this.name,
    required this.code,
    required this.semesterId,
    required this.isActive,
    required this.createdAt,
    this.credits = 0,
  });

  factory Module.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Module(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      semesterId: data['semesterId'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      credits: data['credits'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'code': code,
      'semesterId': semesterId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'credits': credits,
    };
  }

  // For local storage
  factory Module.fromMap(Map<String, dynamic> map) {
    return Module(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      semesterId: map['semesterId'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      credits: map['credits'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'code': code,
      'semesterId': semesterId,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'credits': credits,
    };
  }

  Module copyWith({
    String? id,
    String? userId,
    String? name,
    String? code,
    String? semesterId,
    bool? isActive,
    DateTime? createdAt,
    int? credits,
  }) {
    return Module(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      code: code ?? this.code,
      semesterId: semesterId ?? this.semesterId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      credits: credits ?? this.credits,
    );
  }
}