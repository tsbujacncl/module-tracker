import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:module_tracker/providers/connectivity_provider.dart';
import 'package:module_tracker/theme/design_tokens.dart';

/// Widget to display sync status in the app
class SyncStatusIndicator extends ConsumerWidget {
  final bool compact;

  const SyncStatusIndicator({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    if (connectivityState.status == ConnectionStatus.online &&
        connectivityState.pendingChanges == 0) {
      // Don't show anything when fully synced
      return const SizedBox.shrink();
    }

    return _buildIndicator(context, ref, connectivityState);
  }

  Widget _buildIndicator(
    BuildContext context,
    WidgetRef ref,
    ConnectivityState state,
  ) {
    final color = _getStatusColor(state.status);
    final icon = _getStatusIcon(state.status);
    final text = _getStatusText(state);

    if (compact) {
      return IconButton(
        icon: Icon(icon, color: color, size: 20),
        tooltip: text,
        onPressed: () => _showSyncDialog(context, ref, state),
      );
    }

    return InkWell(
      onTap: () => _showSyncDialog(context, ref, state),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.sm),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (state.pendingChanges > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.pendingChanges}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.online:
        return const Color(0xFF10B981);
      case ConnectionStatus.offline:
        return const Color(0xFFEF4444);
      case ConnectionStatus.syncing:
        return const Color(0xFF0EA5E9);
    }
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.online:
        return Icons.cloud_done;
      case ConnectionStatus.offline:
        return Icons.cloud_off;
      case ConnectionStatus.syncing:
        return Icons.cloud_sync;
    }
  }

  String _getStatusText(ConnectivityState state) {
    switch (state.status) {
      case ConnectionStatus.online:
        if (state.pendingChanges > 0) {
          return 'Pending';
        }
        return 'Synced';
      case ConnectionStatus.offline:
        return 'Offline';
      case ConnectionStatus.syncing:
        return 'Syncing';
    }
  }

  void _showSyncDialog(BuildContext context, WidgetRef ref, ConnectivityState state) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getStatusIcon(state.status),
              color: _getStatusColor(state.status),
            ),
            const SizedBox(width: AppSpacing.md),
            const Text('Sync Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow(
              'Status',
              _getStatusText(state),
              _getStatusColor(state.status),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildStatusRow(
              'Pending Changes',
              '${state.pendingChanges}',
              state.pendingChanges > 0
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981),
            ),
            if (state.lastSyncTime != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildStatusRow(
                'Last Sync',
                _formatLastSync(state.lastSyncTime!),
                const Color(0xFF64748B),
              ),
            ],
            if (state.syncError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFEF4444),
                          size: 16,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Sync Error',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.syncError!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.status == ConnectionStatus.offline)
            TextButton(
              onPressed: () {
                ref.read(connectivityProvider.notifier).refreshPendingCount();
                Navigator.pop(dialogContext);
              },
              child: const Text('Refresh'),
            ),
          if (state.status == ConnectionStatus.online && state.pendingChanges > 0)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await ref.read(connectivityProvider.notifier).syncPendingChanges();
              },
              child: const Text('Sync Now'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatLastSync(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
