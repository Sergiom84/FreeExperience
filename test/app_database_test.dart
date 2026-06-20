import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_experience/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('conserva catálogo, favoritos y cola de sincronización', () async {
    await database.upsertContent([
      CachedContentItemsCompanion.insert(
        id: 'meditacion-uno',
        kind: 'meditation',
        title: 'Quietud',
        coverPath: 'assets/images/cover_umbral.svg',
        updatedAt: DateTime.utc(2026, 6, 20),
      ),
    ]);

    expect(await database.contentCount(), 1);
    await database.setFavorite('meditacion-uno', favorite: true);
    expect(await database.isFavorite('meditacion-uno'), isTrue);
    expect((await database.pendingSync()).single.operation, 'upsert');

    await database.setFavorite('meditacion-uno', favorite: false);
    expect(await database.isFavorite('meditacion-uno'), isFalse);
    expect((await database.pendingSync()).single.operation, 'delete');
  });

  test('persiste la posición y sustituye el conflicto pendiente', () async {
    await database.saveProgress(
      contentId: 'audio-uno',
      position: const Duration(seconds: 35),
      completed: false,
    );
    await database.saveProgress(
      contentId: 'audio-uno',
      position: const Duration(seconds: 72),
      completed: true,
    );

    final progress = await database.progressFor('audio-uno');
    expect(progress?.positionSeconds, 72);
    expect(progress?.completed, isTrue);
    final pending = await database.pendingSync();
    expect(pending, hasLength(1));
    expect(pending.single.entityType, 'progress');
  });

  test('registra una descarga terminada', () async {
    await database.saveDownload(
      DownloadRecordsCompanion.insert(
        contentId: 'audio-uno',
        state: const Value('downloaded'),
        filePath: const Value('asset:///assets/audio/starter_ambient.m4a'),
        updatedAt: DateTime.utc(2026, 6, 20),
      ),
    );

    final download = await database.downloadFor('audio-uno');
    expect(download?.state, 'downloaded');
    expect(download?.filePath, startsWith('asset:'));
  });

  test('acepta progreso remoto nuevo sin crear otra operación', () async {
    await database.mergeRemoteProgress(
      contentId: 'audio-remoto',
      position: const Duration(seconds: 91),
      completed: false,
      updatedAt: DateTime.utc(2026, 6, 20, 12),
    );

    final progress = await database.progressFor('audio-remoto');
    expect(progress?.positionSeconds, 91);
    expect(progress?.pendingSync, isFalse);
    expect(await database.pendingSync(), isEmpty);
  });
}
