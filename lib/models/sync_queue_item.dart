/// Represents a pending sync operation
class SyncQueueItem {
  final String id;
  final SyncOperation operation;
  final SyncEntityType entityType;
  final String entityId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  final String? parentId; // For nested entities (e.g., assessment under module)
  final String userId;

  const SyncQueueItem({
    required this.id,
    required this.operation,
    required this.entityType,
    required this.entityId,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    this.parentId,
    required this.userId,
  });

  SyncQueueItem copyWith({
    String? id,
    SyncOperation? operation,
    SyncEntityType? entityType,
    String? entityId,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    int? retryCount,
    String? parentId,
    String? userId,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation': operation.index,
      'entityType': entityType.index,
      'entityId': entityId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'parentId': parentId,
      'userId': userId,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as String,
      operation: SyncOperation.values[map['operation'] as int],
      entityType: SyncEntityType.values[map['entityType'] as int],
      entityId: map['entityId'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
      timestamp: DateTime.parse(map['timestamp'] as String),
      retryCount: map['retryCount'] as int? ?? 0,
      parentId: map['parentId'] as String?,
      userId: map['userId'] as String,
    );
  }
}

/// Type of sync operation
enum SyncOperation {
  create,
  update,
  delete,
}

/// Type of entity being synced
enum SyncEntityType {
  semester,
  module,
  weeklyTask,
  assessment,
  taskCompletion,
}
