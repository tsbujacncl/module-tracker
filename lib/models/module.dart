import 'package:cloud_firestore/cloud_firestore.dart';

class Module {
  final String id;
  final String userId;
  final String name;
  final String code;
  final String semesterId;
  final bool isActive;
  final DateTime createdAt;

  Module({
    required this.id,
    required this.userId,
    required this.name,
    required this.code,
    required this.semesterId,
    required this.isActive,
    required this.createdAt,
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
  }) {
    return Module(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      code: code ?? this.code,
      semesterId: semesterId ?? this.semesterId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}