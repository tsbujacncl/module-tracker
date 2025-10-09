import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:module_tracker/models/assessment.dart';
import 'package:module_tracker/models/recurring_task.dart';

/// Represents a shared module that can be imported by other users
class SharedModule {
  final String id; // Unique short code (e.g., "ABC123")
  final String moduleCode;
  final String moduleName;
  final String moduleColor;
  final List<SharedAssessment> assessments;
  final List<SharedTask> tasks;
  final String sharedBy; // User ID who shared
  final DateTime createdAt;
  final DateTime expiresAt;
  final int importCount; // How many times imported

  SharedModule({
    required this.id,
    required this.moduleCode,
    required this.moduleName,
    required this.moduleColor,
    required this.assessments,
    required this.tasks,
    required this.sharedBy,
    required this.createdAt,
    required this.expiresAt,
    this.importCount = 0,
  });

  factory SharedModule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedModule(
      id: doc.id,
      moduleCode: data['moduleCode'] ?? '',
      moduleName: data['moduleName'] ?? '',
      moduleColor: data['moduleColor'] ?? '#3B82F6',
      assessments: (data['assessments'] as List<dynamic>?)
              ?.map((a) => SharedAssessment.fromMap(a))
              .toList() ??
          [],
      tasks: (data['tasks'] as List<dynamic>?)
              ?.map((t) => SharedTask.fromMap(t))
              .toList() ??
          [],
      sharedBy: data['sharedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      importCount: data['importCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'moduleCode': moduleCode,
      'moduleName': moduleName,
      'moduleColor': moduleColor,
      'assessments': assessments.map((a) => a.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
      'sharedBy': sharedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'importCount': importCount,
    };
  }

  /// Generate shareable URL
  String getShareUrl() {
    // TODO: Replace with your actual domain when deployed
    return 'https://moduletracker.app/share/$id';
  }
}

/// Simplified assessment for sharing (no personal data)
class SharedAssessment {
  final String name;
  final double weight;
  final DateTime? dueDate;
  final String description;

  SharedAssessment({
    required this.name,
    required this.weight,
    this.dueDate,
    required this.description,
  });

  factory SharedAssessment.fromAssessment(Assessment assessment) {
    return SharedAssessment(
      name: assessment.name,
      weight: assessment.weighting,
      dueDate: assessment.dueDate,
      description: assessment.description ?? '',
    );
  }

  factory SharedAssessment.fromMap(Map<String, dynamic> map) {
    return SharedAssessment(
      name: map['name'] ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      dueDate: map['dueDate'] != null
          ? (map['dueDate'] as Timestamp).toDate()
          : null,
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'weight': weight,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'description': description,
    };
  }
}

/// Simplified task for sharing (no personal completion state)
class SharedTask {
  final String name;
  final int dayOfWeek; // 1=Monday, 5=Friday
  final String? time; // "09:00" format

  SharedTask({
    required this.name,
    required this.dayOfWeek,
    this.time,
  });

  factory SharedTask.fromRecurringTask(RecurringTask task) {
    return SharedTask(
      name: task.name,
      dayOfWeek: task.dayOfWeek,
      time: task.time,
    );
  }

  factory SharedTask.fromMap(Map<String, dynamic> map) {
    return SharedTask(
      name: map['name'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? 1,
      time: map['time'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dayOfWeek': dayOfWeek,
      'time': time,
    };
  }
}

/// Represents multiple shared modules bundled together
class SharedModuleBundle {
  final String id; // Unique short code (e.g., "ABC123")
  final List<SharedModuleInfo> modules;
  final String sharedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int importCount;

  SharedModuleBundle({
    required this.id,
    required this.modules,
    required this.sharedBy,
    required this.createdAt,
    required this.expiresAt,
    this.importCount = 0,
  });

  // Convenience getters
  int get totalAssessments => modules.fold(
        0,
        (total, module) => total + module.assessments.length,
      );

  int get totalTasks => modules.fold(
        0,
        (total, module) => total + module.tasks.length,
      );

  factory SharedModuleBundle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedModuleBundle(
      id: doc.id,
      modules: (data['modules'] as List<dynamic>?)
              ?.map((m) => SharedModuleInfo.fromMap(m))
              .toList() ??
          [],
      sharedBy: data['sharedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      importCount: data['importCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'modules': modules.map((m) => m.toMap()).toList(),
      'sharedBy': sharedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'importCount': importCount,
      'isBundle': true, // Flag to identify multi-module shares
    };
  }

  String getShareUrl() {
    return 'https://moduletracker.app/share/$id';
  }
}

/// Simplified module info for bundled sharing
class SharedModuleInfo {
  final String moduleCode;
  final String moduleName;
  final String moduleColor;
  final int credits;
  final List<SharedAssessment> assessments;
  final List<SharedTask> tasks;

  SharedModuleInfo({
    required this.moduleCode,
    required this.moduleName,
    required this.moduleColor,
    required this.credits,
    required this.assessments,
    required this.tasks,
  });

  factory SharedModuleInfo.fromMap(Map<String, dynamic> map) {
    return SharedModuleInfo(
      moduleCode: map['moduleCode'] ?? '',
      moduleName: map['moduleName'] ?? '',
      moduleColor: map['moduleColor'] ?? '#3B82F6',
      credits: map['credits'] ?? 0,
      assessments: (map['assessments'] as List<dynamic>?)
              ?.map((a) => SharedAssessment.fromMap(a))
              .toList() ??
          [],
      tasks: (map['tasks'] as List<dynamic>?)
              ?.map((t) => SharedTask.fromMap(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'moduleCode': moduleCode,
      'moduleName': moduleName,
      'moduleColor': moduleColor,
      'credits': credits,
      'assessments': assessments.map((a) => a.toMap()).toList(),
      'tasks': tasks.map((t) => t.toMap()).toList(),
    };
  }
}
