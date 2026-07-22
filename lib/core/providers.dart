import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_environment.dart';
import 'database/app_database.dart';
import 'design/design_direction.dart';
import 'sync/sync_service.dart';
import '../features/content/data/content_repository.dart';
import '../features/content/domain/content_item.dart';
import '../features/downloads/download_manager.dart';
import '../features/identity/identity_service.dart';
import '../features/player/free_experience_audio_handler.dart';
import '../features/player/playback_coordinator.dart';
import '../features/profile/intro_seen_store.dart';
import '../features/profile/profile_repository.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('AppDatabase override missing'),
);

final audioHandlerProvider = Provider<FreeExperienceAudioHandler>(
  (ref) => throw UnimplementedError('AudioHandler override missing'),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppEnvironment.supabaseConfigured) return null;
  return Supabase.instance.client;
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final repository = DriftContentRepository(
    database: ref.watch(databaseProvider),
    remote: ref.watch(supabaseClientProvider),
    sync: ref.watch(syncServiceProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return DriftProgressRepository(ref.watch(databaseProvider));
});

final identityServiceProvider = Provider<IdentityService>((ref) {
  final service = SupabaseIdentityService(
    ref.watch(supabaseClientProvider),
    onDeleted: () async {
      await ref.read(downloadManagerProvider).clearAll();
      await ref.read(databaseProvider).clearPersonalData();
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return LocalDownloadManager(
    database: ref.watch(databaseProvider),
    dio: ref.watch(dioProvider),
    remote: ref.watch(supabaseClientProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SupabaseSyncService(
    database: ref.watch(databaseProvider),
    identity: ref.watch(identityServiceProvider),
    remote: ref.watch(supabaseClientProvider),
  );
});

final playbackQueueProvider = StreamProvider<QueueSnapshot>((ref) {
  return ref.watch(playbackCoordinatorProvider).queue;
});

final playbackCoordinatorProvider = Provider<PlaybackCoordinator>((ref) {
  final coordinator = PlaybackCoordinator(
    handler: ref.watch(audioHandlerProvider),
    progress: ref.watch(progressRepositoryProvider),
    downloads: ref.watch(downloadManagerProvider),
    sync: ref.watch(syncServiceProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  // Identity first so the catalogue refresh below runs with a valid session
  // (RLS on content_items only exposes published rows to authenticated users).
  await ref.read(identityServiceProvider).bootstrap();
  await ref.read(contentRepositoryProvider).bootstrap();
  await ref.read(syncServiceProvider).synchronize();
  ref.read(playbackCoordinatorProvider);
});

/// Re-pulls the published catalogue whenever the user becomes linked. A fresh
/// sign-in happens after [appBootstrapProvider] has already run, so without this
/// the local cache would stay empty until a manual pull-to-refresh.
final contentAutoRefreshProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<IdentitySnapshot>>(identityProvider, (prev, next) {
    if (next.asData?.value.status == IdentityStatus.linked) {
      ref.read(contentRepositoryProvider).refresh();
    }
  }, fireImmediately: true);
});

final contentByKindProvider =
    StreamProvider.family<List<ContentItem>, ContentKind>(
      (ref, kind) =>
          ref.watch(contentRepositoryProvider).watchPublished(kind: kind),
    );

final contentByIdProvider = StreamProvider.family<ContentItem?, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).watchById(id),
);

/// Todo el contenido publicado, sin filtrar por sección. Alimenta la búsqueda
/// global de la cabecera.
final allPublishedContentProvider = StreamProvider<List<ContentItem>>(
  (ref) => ref.watch(contentRepositoryProvider).watchPublished(),
);

final favoriteContentProvider = StreamProvider<List<ContentItem>>(
  (ref) => ref.watch(contentRepositoryProvider).watchFavorites(),
);

/// Si el usuario ya escuchó el contenido hasta el final. Alimenta la marca de
/// confirmación en los listados de cada sección.
final isListenedProvider = StreamProvider.family<bool, String>(
  (ref, id) => ref
      .watch(progressRepositoryProvider)
      .watch(id)
      .map((record) => record?.completed ?? false),
);

final isFavoriteProvider = StreamProvider.family<bool, String>(
  (ref, id) => ref.watch(contentRepositoryProvider).watchIsFavorite(id),
);

final downloadProvider = StreamProvider.family<DownloadSnapshot, String>(
  (ref, id) => ref.watch(downloadManagerProvider).watch(id),
);

final identityProvider = StreamProvider<IdentitySnapshot>((ref) async* {
  final identity = ref.watch(identityServiceProvider);
  yield identity.current;
  yield* identity.changes;
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

/// Si el usuario ya escuchó la locución de bienvenida. Decide si el portal
/// muestra la salida a inicio (primera vez no hay salidas: la locución entera).
final introSeenProvider = FutureProvider<bool>(
  (ref) => ref.watch(introSeenStoreProvider).isSeen(),
);

final introSeenStoreProvider = Provider<IntroSeenStore>(
  (ref) => IntroSeenStore(ref.watch(profileRepositoryProvider)),
);

/// Public URL of the signed-in user's avatar. Recomputed when the identity
/// changes (login/logout) so the home reflects it immediately.
final avatarUrlProvider = FutureProvider<String?>((ref) async {
  ref.watch(identityProvider);
  return ref.watch(profileRepositoryProvider).avatarUrl();
});

final designDirectionProvider =
    NotifierProvider<DesignDirectionController, DesignDirection>(
      DesignDirectionController.new,
    );

class DesignDirectionController extends Notifier<DesignDirection> {
  static const _preferenceKey = 'design_direction';

  @override
  DesignDirection build() {
    _restore();
    // Materia quieta es la dirección predeterminada (decisión 2026-07-22).
    return DesignDirection.materia;
  }

  Future<void> select(DesignDirection direction) async {
    state = direction;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, direction.name);
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    if (saved == null) return;
    state = DesignDirection.values.firstWhere(
      (direction) => direction.name == saved,
      orElse: () => DesignDirection.materia,
    );
  }
}
