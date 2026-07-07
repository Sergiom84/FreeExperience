import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:free_experience/core/database/app_database.dart';
import 'package:free_experience/core/sync/sync_service.dart';
import 'package:free_experience/features/content/data/content_repository.dart';

class _RecordingSync implements SyncService {
  int calls = 0;

  @override
  Future<void> synchronize() async {
    calls++;
  }
}

void main() {
  late AppDatabase database;
  late _RecordingSync sync;
  late DriftContentRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    sync = _RecordingSync();
    repository = DriftContentRepository(database: database, sync: sync);
  });

  tearDown(() => database.close());

  test('bootstrap siembra el catálogo local cuando está vacío', () async {
    await repository.bootstrap();
    expect(await database.contentCount(), greaterThan(0));
  });

  test('toggleFavorite alterna y programa la sincronización', () async {
    await repository.toggleFavorite('audio-uno');
    await Future<void>.delayed(Duration.zero);
    expect(await database.isFavorite('audio-uno'), isTrue);
    expect(sync.calls, 1);

    await repository.toggleFavorite('audio-uno');
    await Future<void>.delayed(Duration.zero);
    expect(await database.isFavorite('audio-uno'), isFalse);
    expect(sync.calls, 2);
  });

  test('sin servicio de sincronización el toggle sigue funcionando', () async {
    final offline = DriftContentRepository(database: database);
    await offline.toggleFavorite('audio-dos');
    expect(await database.isFavorite('audio-dos'), isTrue);
  });
}
