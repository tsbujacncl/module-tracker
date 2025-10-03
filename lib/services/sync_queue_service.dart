import 'package:hive_flutter/hive_flutter.dart';
import 'package:module_tracker/models/sync_queue_item.dart';
import 'package:uuid/uuid.dart';

/// Service for managing offline sync queue
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  static const String _boxName = 'sync_queue';
  Box<Map>? _queueBox;
  final _uuid = const Uuid();

  /// Initialize the sync queue
  Future<void> initialize() async {
    if (_queueBox == null || !_queueBox!.isOpen) {
      _queueBox = await Hive.openBox<Map>(_boxName);
      print('DEBUG SYNC: Sync queue initialized with ${_queueBox!.length} items');
    }
  }

  /// Add an operation to the sync queue
  Future<String> enqueue({
    required SyncOperation operation,
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> data,
    String? parentId,
    required String userId,
  }) async {
    await initialize();

    final item = SyncQueueItem(
      id: _uuid.v4(),
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      data: data,
      timestamp: DateTime.now(),
      parentId: parentId,
      userId: userId,
    );

    await _queueBox!.put(item.id, item.toMap());
    print('DEBUG SYNC: Enqueued ${operation.name} ${entityType.name} (${item.id})');

    return item.id;
  }

  /// Get all pending sync items
  Future<List<SyncQueueItem>> getPendingItems() async {
    await initialize();

    final items = <SyncQueueItem>[];
    for (final key in _queueBox!.keys) {
      final map = _queueBox!.get(key) as Map;
      items.add(SyncQueueItem.fromMap(Map<String, dynamic>.from(map)));
    }

    // Sort by timestamp (oldest first)
    items.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return items;
  }

  /// Get pending items count
  Future<int> getPendingCount() async {
    await initialize();
    return _queueBox!.length;
  }

  /// Remove an item from the queue (after successful sync)
  Future<void> dequeue(String itemId) async {
    await initialize();
    await _queueBox!.delete(itemId);
    print('DEBUG SYNC: Dequeued item $itemId');
  }

  /// Update retry count for a failed sync
  Future<void> incrementRetryCount(String itemId) async {
    await initialize();

    final map = _queueBox!.get(itemId) as Map?;
    if (map != null) {
      final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(map));
      final updated = item.copyWith(retryCount: item.retryCount + 1);
      await _queueBox!.put(itemId, updated.toMap());
      print('DEBUG SYNC: Retry count for $itemId: ${updated.retryCount}');
    }
  }

  /// Clear all items from the queue
  Future<void> clear() async {
    await initialize();
    await _queueBox!.clear();
    print('DEBUG SYNC: Queue cleared');
  }

  /// Check if there are conflicting operations for the same entity
  Future<bool> hasConflict(String entityId, SyncEntityType entityType) async {
    await initialize();

    final items = await getPendingItems();
    final conflicts = items.where((item) =>
        item.entityId == entityId &&
        item.entityType == entityType &&
        item.operation == SyncOperation.update);

    return conflicts.length > 1;
  }

  /// Merge multiple update operations for the same entity
  Future<void> mergeUpdates(String entityId, SyncEntityType entityType) async {
    await initialize();

    final items = await getPendingItems();
    final updates = items
        .where((item) =>
            item.entityId == entityId &&
            item.entityType == entityType &&
            item.operation == SyncOperation.update)
        .toList();

    if (updates.length <= 1) return;

    // Keep the latest update, merge all data
    final merged = <String, dynamic>{};
    for (final update in updates) {
      merged.addAll(update.data);
    }

    // Remove all but the last update
    for (int i = 0; i < updates.length - 1; i++) {
      await dequeue(updates[i].id);
    }

    // Update the last item with merged data
    final lastItem = updates.last;
    final mergedItem = lastItem.copyWith(data: merged);
    await _queueBox!.put(lastItem.id, mergedItem.toMap());

    print('DEBUG SYNC: Merged ${updates.length} updates for $entityType $entityId');
  }

  /// Get items grouped by entity type
  Future<Map<SyncEntityType, List<SyncQueueItem>>> getItemsByType() async {
    final items = await getPendingItems();
    final grouped = <SyncEntityType, List<SyncQueueItem>>{};

    for (final type in SyncEntityType.values) {
      grouped[type] = items.where((item) => item.entityType == type).toList();
    }

    return grouped;
  }

  /// Remove all items older than specified duration
  Future<void> pruneOldItems(Duration age) async {
    await initialize();

    final cutoff = DateTime.now().subtract(age);
    final items = await getPendingItems();

    for (final item in items) {
      if (item.timestamp.isBefore(cutoff) && item.retryCount > 5) {
        await dequeue(item.id);
        print('DEBUG SYNC: Pruned old item ${item.id} (${item.retryCount} retries)');
      }
    }
  }
}
