import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:module_tracker/services/sync_queue_service.dart';
import 'package:module_tracker/repositories/firestore_repository.dart';
import 'package:module_tracker/models/sync_queue_item.dart';

/// Connection status
enum ConnectionStatus {
  online,
  offline,
  syncing,
}

/// State for connectivity
class ConnectivityState {
  final ConnectionStatus status;
  final int pendingChanges;
  final DateTime? lastSyncTime;
  final String? syncError;

  const ConnectivityState({
    required this.status,
    this.pendingChanges = 0,
    this.lastSyncTime,
    this.syncError,
  });

  ConnectivityState copyWith({
    ConnectionStatus? status,
    int? pendingChanges,
    DateTime? lastSyncTime,
    String? syncError,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      syncError: syncError,
    );
  }
}

/// Notifier for connectivity state
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  final SyncQueueService _syncQueue = SyncQueueService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isSyncing = false;

  ConnectivityNotifier() : super(const ConnectivityState(status: ConnectionStatus.online)) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check initial connectivity
    await _checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // Periodic sync check every 30 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (state.status == ConnectionStatus.online) {
        syncPendingChanges();
      }
    });

    // Update pending count
    await _updatePendingCount();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isConnected = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    if (isConnected && state.status == ConnectionStatus.offline) {
      print('DEBUG SYNC: Connection restored, triggering sync');
      state = state.copyWith(
        status: ConnectionStatus.online,
        syncError: null,
      );
      syncPendingChanges();
    } else if (!isConnected && state.status != ConnectionStatus.offline) {
      print('DEBUG SYNC: Connection lost');
      state = state.copyWith(status: ConnectionStatus.offline);
    }
  }

  Future<void> _updatePendingCount() async {
    final count = await _syncQueue.getPendingCount();
    state = state.copyWith(pendingChanges: count);
  }

  /// Manually trigger sync
  Future<void> syncPendingChanges() async {
    if (_isSyncing) {
      print('DEBUG SYNC: Sync already in progress');
      return;
    }

    if (state.status == ConnectionStatus.offline) {
      print('DEBUG SYNC: Cannot sync while offline');
      return;
    }

    _isSyncing = true;
    state = state.copyWith(status: ConnectionStatus.syncing, syncError: null);

    try {
      final items = await _syncQueue.getPendingItems();
      print('DEBUG SYNC: Processing ${items.length} pending items');

      if (items.isEmpty) {
        state = state.copyWith(
          status: ConnectionStatus.online,
          pendingChanges: 0,
          lastSyncTime: DateTime.now(),
        );
        _isSyncing = false;
        return;
      }

      // Process each item
      for (final item in items) {
        try {
          await _processSyncItem(item);
          await _syncQueue.dequeue(item.id);
          print('DEBUG SYNC: Successfully synced ${item.entityType.name} ${item.operation.name}');
        } catch (e) {
          print('DEBUG SYNC: Failed to sync item ${item.id}: $e');
          await _syncQueue.incrementRetryCount(item.id);

          // If too many retries, it might be a permanent error
          if (item.retryCount >= 5) {
            print('DEBUG SYNC: Item ${item.id} exceeded retry limit');
          }
        }
      }

      // Prune old failed items (older than 7 days with >5 retries)
      await _syncQueue.pruneOldItems(const Duration(days: 7));

      final remainingCount = await _syncQueue.getPendingCount();
      state = state.copyWith(
        status: ConnectionStatus.online,
        pendingChanges: remainingCount,
        lastSyncTime: DateTime.now(),
      );
    } catch (e) {
      print('DEBUG SYNC: Sync error: $e');
      state = state.copyWith(
        status: ConnectionStatus.online,
        syncError: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Process a single sync item
  Future<void> _processSyncItem(SyncQueueItem item) async {
    // This is a placeholder - actual implementation would need access to FirestoreRepository
    // In practice, this would be injected or accessed via a provider
    print('DEBUG SYNC: Processing ${item.operation.name} for ${item.entityType.name}');

    // The actual sync logic will be integrated in the repository
    // For now, we just mark items as processed
    throw UnimplementedError('Sync processing will be implemented in repository integration');
  }

  /// Force refresh pending count
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
  }

  /// Clear sync queue (use with caution)
  Future<void> clearQueue() async {
    await _syncQueue.clear();
    await _updatePendingCount();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}

/// Provider for connectivity state
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});
