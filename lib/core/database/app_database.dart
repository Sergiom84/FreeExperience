import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'dart:convert';

part 'app_database.g.dart';

class CachedContentItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get status => text().withDefault(const Constant('published'))();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get externalUrl => text().nullable()();
  TextColumn get coverPath => text()();
  TextColumn get mediaPath => text().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get featured => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class FavoriteRecords extends Table {
  TextColumn get contentId => text()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {contentId};
}

class PlaybackProgressRecords extends Table {
  TextColumn get contentId => text()();
  IntColumn get positionSeconds => integer().withDefault(const Constant(0))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {contentId};
}

class DownloadRecords extends Table {
  TextColumn get contentId => text()();
  TextColumn get state => text().withDefault(const Constant('none'))();
  TextColumn get filePath => text().nullable()();
  IntColumn get bytesReceived => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {contentId};
}

class PendingSyncRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get occurredAt => dateTime()();
}

@DriftDatabase(
  tables: [
    CachedContentItems,
    FavoriteRecords,
    PlaybackProgressRecords,
    DownloadRecords,
    PendingSyncRecords,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'free_experience',
          // En web, drift exige opciones explícitas: los binarios sqlite3.wasm
          // y drift_worker.js se sirven desde web/. En nativo este parámetro se
          // ignora y se usa un fichero en el directorio de documentos.
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<int> contentCount() async {
    final count = cachedContentItems.id.count();
    final query = selectOnly(cachedContentItems)..addColumns([count]);
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<void> upsertContent(Iterable<CachedContentItemsCompanion> entries) =>
      batch((batch) {
        batch.insertAllOnConflictUpdate(cachedContentItems, entries.toList());
      });

  Stream<List<CachedContentItem>> watchPublished({String? kind}) {
    final query = select(cachedContentItems)
      ..where((table) {
        final published = table.status.equals('published');
        return kind == null ? published : published & table.kind.equals(kind);
      })
      ..orderBy([
        (table) => OrderingTerm.desc(table.featured),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.desc(table.publishedAt),
      ]);
    return query.watch();
  }

  Future<CachedContentItem?> contentById(String id) => (select(
    cachedContentItems,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Stream<CachedContentItem?> watchContentById(String id) => (select(
    cachedContentItems,
  )..where((table) => table.id.equals(id))).watchSingleOrNull();

  Stream<List<CachedContentItem>> watchFavorites() {
    final query = select(cachedContentItems).join([
      innerJoin(
        favoriteRecords,
        favoriteRecords.contentId.equalsExp(cachedContentItems.id),
      ),
    ])..orderBy([OrderingTerm.desc(favoriteRecords.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(cachedContentItems)).toList(),
    );
  }

  Stream<bool> watchIsFavorite(String contentId) =>
      (select(favoriteRecords)
            ..where((table) => table.contentId.equals(contentId)))
          .watchSingleOrNull()
          .map((row) => row != null);

  Future<void> setFavorite(String contentId, {required bool favorite}) async {
    await transaction(() async {
      if (favorite) {
        await into(favoriteRecords).insertOnConflictUpdate(
          FavoriteRecordsCompanion.insert(
            contentId: contentId,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      } else {
        await (delete(
          favoriteRecords,
        )..where((table) => table.contentId.equals(contentId))).go();
      }
      await _replacePendingSync(
        entityType: 'favorite',
        entityId: contentId,
        operation: favorite ? 'upsert' : 'delete',
        payload: const {},
      );
    });
  }

  Future<bool> isFavorite(String contentId) async =>
      await (select(favoriteRecords)
            ..where((table) => table.contentId.equals(contentId)))
          .getSingleOrNull() !=
      null;

  Future<void> markFavoriteSynced(String contentId) =>
      (update(favoriteRecords)
            ..where((table) => table.contentId.equals(contentId)))
          .write(const FavoriteRecordsCompanion(pendingSync: Value(false)));

  Future<void> replaceFavoritesFromRemote(
    Map<String, DateTime> remoteFavorites,
  ) => transaction(() async {
    await delete(favoriteRecords).go();
    if (remoteFavorites.isEmpty) return;
    await batch((batch) {
      batch.insertAll(
        favoriteRecords,
        remoteFavorites.entries
            .map(
              (entry) => FavoriteRecordsCompanion.insert(
                contentId: entry.key,
                updatedAt: entry.value,
                pendingSync: const Value(false),
              ),
            )
            .toList(),
      );
    });
  });

  Stream<PlaybackProgressRecord?> watchProgress(String contentId) => (select(
    playbackProgressRecords,
  )..where((table) => table.contentId.equals(contentId))).watchSingleOrNull();

  Future<PlaybackProgressRecord?> progressFor(String contentId) => (select(
    playbackProgressRecords,
  )..where((table) => table.contentId.equals(contentId))).getSingleOrNull();

  Future<void> saveProgress({
    required String contentId,
    required Duration position,
    required bool completed,
  }) async {
    await transaction(() async {
      await into(playbackProgressRecords).insertOnConflictUpdate(
        PlaybackProgressRecordsCompanion.insert(
          contentId: contentId,
          positionSeconds: Value(position.inSeconds),
          completed: Value(completed),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _replacePendingSync(
        entityType: 'progress',
        entityId: contentId,
        operation: 'upsert',
        payload: {
          'position_seconds': position.inSeconds,
          'completed': completed,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    });
  }

  Future<void> markProgressSynced(String contentId) =>
      (update(
        playbackProgressRecords,
      )..where((table) => table.contentId.equals(contentId))).write(
        const PlaybackProgressRecordsCompanion(pendingSync: Value(false)),
      );

  Future<void> mergeRemoteProgress({
    required String contentId,
    required Duration position,
    required bool completed,
    required DateTime updatedAt,
  }) async {
    final local = await progressFor(contentId);
    if (local?.pendingSync ?? false) return;
    if (local != null && !updatedAt.isAfter(local.updatedAt)) return;
    await into(playbackProgressRecords).insertOnConflictUpdate(
      PlaybackProgressRecordsCompanion.insert(
        contentId: contentId,
        positionSeconds: Value(position.inSeconds),
        completed: Value(completed),
        updatedAt: updatedAt,
        pendingSync: const Value(false),
      ),
    );
  }

  Stream<DownloadRecord?> watchDownload(String contentId) => (select(
    downloadRecords,
  )..where((table) => table.contentId.equals(contentId))).watchSingleOrNull();

  Future<DownloadRecord?> downloadFor(String contentId) => (select(
    downloadRecords,
  )..where((table) => table.contentId.equals(contentId))).getSingleOrNull();

  Future<List<DownloadRecord>> allDownloads() => select(downloadRecords).get();

  Future<void> saveDownload(DownloadRecordsCompanion record) =>
      into(downloadRecords).insertOnConflictUpdate(record);

  Future<void> removeDownload(String contentId) => (delete(
    downloadRecords,
  )..where((table) => table.contentId.equals(contentId))).go();

  Future<void> clearPersonalData() => transaction(() async {
    await delete(favoriteRecords).go();
    await delete(playbackProgressRecords).go();
    await delete(downloadRecords).go();
    await delete(pendingSyncRecords).go();
  });

  Future<List<PendingSyncRecord>> pendingSync() => (select(
    pendingSyncRecords,
  )..orderBy([(table) => OrderingTerm.asc(table.occurredAt)])).get();

  Future<void> removePendingSync(int id) =>
      (delete(pendingSyncRecords)..where((table) => table.id.equals(id))).go();

  Future<void> _replacePendingSync({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await (delete(pendingSyncRecords)..where(
          (table) =>
              table.entityType.equals(entityType) &
              table.entityId.equals(entityId),
        ))
        .go();
    await into(pendingSyncRecords).insert(
      PendingSyncRecordsCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payloadJson: jsonEncode(payload),
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }
}
