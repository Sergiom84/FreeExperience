import 'dart:async';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/util/app_log.dart';
import '../domain/content_item.dart';
import 'seed_catalog.dart';

abstract interface class ContentRepository {
  Future<void> bootstrap();
  Future<void> refresh();
  Future<void> dispose();
  Stream<List<ContentItem>> watchPublished({ContentKind? kind});
  Stream<ContentItem?> watchById(String id);
  Future<ContentItem?> getById(String id);
  Stream<List<ContentItem>> watchFavorites();
  Stream<bool> watchIsFavorite(String id);
  Future<void> toggleFavorite(String id);
}

class DriftContentRepository implements ContentRepository {
  DriftContentRepository({
    required AppDatabase database,
    SupabaseClient? remote,
    SyncService? sync,
  }) : _database = database,
       _remote = remote,
       _sync = sync;

  final AppDatabase _database;
  final SupabaseClient? _remote;
  final SyncService? _sync;
  RealtimeChannel? _channel;

  @override
  Future<void> bootstrap() async {
    if (await _database.contentCount() == 0) {
      await _database.upsertContent(seedCatalog.map(_toCompanion));
    }
    if (_remote != null) {
      unawaited(refresh());
      _subscribeToRemoteChanges();
    }
  }

  /// Refresca el catálogo en cuanto el admin publica/edita algo, sin que el
  /// usuario tenga que reabrir la app ni tirar para refrescar.
  void _subscribeToRemoteChanges() {
    final remote = _remote;
    if (remote == null || _channel != null) return;
    _channel = remote
        .channel('public:content_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'content_items',
          callback: (_) => refresh(),
        )
        .subscribe();
  }

  @override
  Future<void> dispose() async {
    final channel = _channel;
    if (channel != null) await _remote?.removeChannel(channel);
    _channel = null;
  }

  @override
  Future<void> refresh() async {
    final remote = _remote;
    if (remote == null) return;
    try {
      final rows = await remote
          .from('content_items')
          .select('*, media_assets(*)')
          .eq('status', 'published')
          .order('sort_order');

      final items = rows
          .map((row) => _fromRemote(Map<String, dynamic>.from(row)))
          .toList();
      await _database.replacePublishedFromRemote(items.map(_toCompanion));
    } on Object catch (error, stackTrace) {
      // Sin red se sigue sirviendo el catálogo local.
      reportError(error, stackTrace, context: 'ContentRepository.refresh');
      return;
    }
  }

  @override
  Stream<List<ContentItem>> watchPublished({ContentKind? kind}) => _database
      .watchPublished(kind: kind?.databaseValue)
      .map((rows) => rows.map(_fromRow).toList());

  @override
  Stream<ContentItem?> watchById(String id) => _database
      .watchContentById(id)
      .map((row) => row == null ? null : _fromRow(row));

  @override
  Future<ContentItem?> getById(String id) async {
    final row = await _database.contentById(id);
    return row == null ? null : _fromRow(row);
  }

  @override
  Stream<List<ContentItem>> watchFavorites() =>
      _database.watchFavorites().map((rows) => rows.map(_fromRow).toList());

  @override
  Stream<bool> watchIsFavorite(String id) => _database.watchIsFavorite(id);

  /// Alterna el favorito y programa la sincronización remota. Antes cada
  /// pantalla lanzaba su propio synchronize() y el reproductor no lo hacía.
  @override
  Future<void> toggleFavorite(String id) async {
    final favorite = await _database.isFavorite(id);
    await _database.setFavorite(id, favorite: !favorite);
    final sync = _sync;
    if (sync != null) unawaited(sync.synchronize());
  }

  CachedContentItemsCompanion _toCompanion(ContentItem item) =>
      CachedContentItemsCompanion.insert(
        id: item.id,
        kind: item.kind.databaseValue,
        status: const Value('published'),
        title: item.title,
        author: Value(item.author),
        body: Value(item.body),
        externalUrl: Value(item.externalUrl),
        coverPath: item.coverPath,
        mediaPath: Value(item.mediaPath),
        durationSeconds: Value(item.duration.inSeconds),
        featured: Value(item.featured),
        sortOrder: Value(item.sortOrder),
        publishedAt: Value(item.publishedAt),
        updatedAt: DateTime.now().toUtc(),
      );

  ContentItem _fromRow(CachedContentItem row) => ContentItem(
    id: row.id,
    kind: ContentKindLabel.parse(row.kind),
    title: row.title,
    author: row.author,
    body: row.body,
    externalUrl: row.externalUrl,
    coverPath: row.coverPath,
    mediaPath: row.mediaPath,
    duration: Duration(seconds: row.durationSeconds),
    featured: row.featured,
    sortOrder: row.sortOrder,
    publishedAt: row.publishedAt,
  );

  ContentItem _fromRemote(Map<String, dynamic> row) {
    final assets = (row['media_assets'] as List<dynamic>? ?? const [])
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    final preferredKind = row['kind'] == 'video' ? 'video' : 'audio';
    final media = assets
        .where((asset) => asset['kind'] == preferredKind)
        .firstOrNull;
    final coverPath = row['cover_path'] as String? ?? '';
    final storagePath = media?['storage_path'] as String?;
    return ContentItem(
      id: row['id'] as String,
      kind: ContentKindLabel.parse(row['kind'] as String),
      title: row['title'] as String,
      author: row['author'] as String?,
      body: row['body'] as String?,
      externalUrl: row['external_url'] as String?,
      coverPath: coverPath.startsWith('http')
          ? coverPath
          : _remote!.storage.from('covers').getPublicUrl(coverPath),
      mediaPath: storagePath == null ? null : 'storage://$storagePath',
      duration: Duration(seconds: row['duration_seconds'] as int? ?? 0),
      featured: row['is_featured'] as bool? ?? false,
      sortOrder: row['sort_order'] as int? ?? 0,
      publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
    );
  }
}

abstract interface class ProgressRepository {
  Stream<PlaybackProgressRecord?> watch(String contentId);
  Future<PlaybackProgressRecord?> get(String contentId);
  Future<void> save(
    String contentId,
    Duration position, {
    required bool completed,
  });
}

class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(this._database);

  final AppDatabase _database;

  @override
  Stream<PlaybackProgressRecord?> watch(String contentId) =>
      _database.watchProgress(contentId);

  @override
  Future<PlaybackProgressRecord?> get(String contentId) =>
      _database.progressFor(contentId);

  @override
  Future<void> save(
    String contentId,
    Duration position, {
    required bool completed,
  }) => _database.saveProgress(
    contentId: contentId,
    position: position,
    completed: completed,
  );
}
