import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum SyncStatus { synced, pending, failed }

/// A small badge indicating the sync state of a ticket or record.
///
/// Usage:
/// ```dart
/// SyncStatusBadge(status: SyncStatus.pending)
/// ```
class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;

  const SyncStatusBadge({super.key, required this.status});

  /// Convenience constructor from a raw statut_sync string.
  factory SyncStatusBadge.fromString(String statutSync) {
    final s = switch (statutSync) {
      'synced'  => SyncStatus.synced,
      'failed'  => SyncStatus.failed,
      _         => SyncStatus.pending,
    };
    return SyncStatusBadge(status: s);
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      SyncStatus.synced  => ('Synchronisé', AppTheme.successGreen, Icons.cloud_done),
      SyncStatus.failed  => ('Échec',        AppTheme.errorRed,    Icons.cloud_off),
      SyncStatus.pending => ('En attente',   AppTheme.goldDark,    Icons.cloud_upload),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}