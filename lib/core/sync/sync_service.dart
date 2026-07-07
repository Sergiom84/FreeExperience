import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../util/app_log.dart';
import '../../features/identity/identity_service.dart';

abstract interface class SyncService {
  Future<void> synchronize();
}

class SupabaseSyncService implements SyncService {
  SupabaseSyncService({
    required AppDatabase database,
    required IdentityService identity,
    SupabaseClient? remote,
  }) : _database = database,
       _identity = identity,
       _remote = remote;

  final AppDatabase _database;
  final IdentityService _identity;
  final SupabaseClient? _remote;

  @override
  Future<void> synchronize() async {
    final remote = _remote;
    final userId = _identity.current.userId;
    if (remote == null || userId == null) return;

    final pending = await _database.pendingSync();
    for (final operation in pending) {
      try {
        if (operation.entityType == 'favorite') {
          if (operation.operation == 'delete') {
            await remote
                .from('favorites')
                .delete()
                .eq('user_id', userId)
                .eq('content_id', operation.entityId);
          } else {
            await remote.from('favorites').upsert({
              'user_id': userId,
              'content_id': operation.entityId,
              'updated_at': operation.occurredAt.toIso8601String(),
            });
          }
          await _database.markFavoriteSynced(operation.entityId);
        } else if (operation.entityType == 'progress') {
          final payload =
              jsonDecode(operation.payloadJson) as Map<String, dynamic>;
          await remote.from('playback_progress').upsert({
            'user_id': userId,
            'content_id': operation.entityId,
            ...payload,
          });
          await _database.markProgressSynced(operation.entityId);
        }
        await _database.removePendingSync(operation.id);
      } on Object catch (error, stackTrace) {
        // La cola se conserva y se reintenta en la próxima sincronización.
        reportError(error, stackTrace, context: 'Sync.push');
        return;
      }
    }

    await _pull(remote, userId);
  }

  Future<void> _pull(SupabaseClient remote, String userId) async {
    try {
      final favoriteRows = await remote
          .from('favorites')
          .select('content_id, updated_at')
          .eq('user_id', userId);
      await _database.replaceFavoritesFromRemote({
        for (final row in favoriteRows)
          row['content_id'] as String: DateTime.parse(
            row['updated_at'] as String,
          ).toUtc(),
      });

      final progressRows = await remote
          .from('playback_progress')
          .select('content_id, position_seconds, completed, updated_at')
          .eq('user_id', userId);
      for (final row in progressRows) {
        await _database.mergeRemoteProgress(
          contentId: row['content_id'] as String,
          position: Duration(seconds: row['position_seconds'] as int? ?? 0),
          completed: row['completed'] as bool? ?? false,
          updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
        );
      }
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'Sync.pull');
      return;
    }
  }
}
