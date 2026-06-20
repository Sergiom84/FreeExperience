import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../core/sync/sync_service.dart';
import '../content/data/content_repository.dart';
import '../content/domain/content_item.dart';
import '../downloads/download_manager.dart';
import 'free_experience_audio_handler.dart';

class PlaybackCoordinator {
  PlaybackCoordinator({
    required FreeExperienceAudioHandler handler,
    required ProgressRepository progress,
    required DownloadManager downloads,
    required SyncService sync,
  }) : _handler = handler,
       _progress = progress,
       _downloads = downloads,
       _sync = sync {
    _stateSubscription = _handler.playbackState.listen(_handlePlaybackState);
  }

  final FreeExperienceAudioHandler _handler;
  final ProgressRepository _progress;
  final DownloadManager _downloads;
  final SyncService _sync;
  StreamSubscription<PlaybackState>? _stateSubscription;
  Timer? _progressTimer;
  Timer? _sleepTimer;
  DateTime? _sleepEnd;

  Duration? get sleepRemaining {
    final end = _sleepEnd;
    if (_sleepTimer == null || end == null) return null;
    final remaining = end.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> play(ContentItem item) async {
    final uri = await _downloads.resolve(item);
    if (uri == null) throw StateError('Contenido no disponible');
    final progress = await _progress.get(item.id);
    final artUri = item.coverPath.startsWith('http')
        ? Uri.tryParse(item.coverPath)
        : null;
    await _handler.load(
      MediaItem(
        id: item.id,
        title: item.title,
        artist: item.author,
        duration: item.duration,
        artUri: artUri,
        extras: {'kind': item.kind.databaseValue},
      ),
      uri,
    );
    if (progress != null &&
        progress.positionSeconds > 0 &&
        !progress.completed) {
      await _handler.seek(Duration(seconds: progress.positionSeconds));
    }
    await _handler.play();
    _startProgressTimer();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    if (duration == null) return;
    _sleepEnd = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      unawaited(_handler.pause());
      _sleepTimer = null;
      _sleepEnd = null;
    });
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress({
    bool forceCompleted = false,
    bool synchronize = false,
  }) async {
    final item = _handler.mediaItem.value;
    if (item == null) return;
    final duration = item.duration ?? Duration.zero;
    final position = _handler.position;
    final completed =
        forceCompleted ||
        (duration > Duration.zero && position >= duration * 0.95);
    await _progress.save(item.id, position, completed: completed);
    if (synchronize) {
      await _sync.synchronize();
    }
  }

  void _handlePlaybackState(PlaybackState state) {
    if (state.processingState == AudioProcessingState.completed) {
      _progressTimer?.cancel();
      unawaited(_persistProgress(forceCompleted: true, synchronize: true));
    } else if (!state.playing &&
        state.processingState == AudioProcessingState.ready) {
      unawaited(_persistProgress(synchronize: true));
    }
  }

  Future<void> dispose() async {
    _progressTimer?.cancel();
    _sleepTimer?.cancel();
    await _stateSubscription?.cancel();
  }
}
