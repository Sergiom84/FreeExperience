import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class FreeExperienceAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  FreeExperienceAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null && item.duration != duration) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.completed,
          ),
        );
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _noisySubscription;

  Duration get position => _player.position;

  Future<void> initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _interruptionSubscription = session.interruptionEventStream.listen((event) {
      if (event.begin && _player.playing) {
        unawaited(pause());
      }
    });
    _noisySubscription = session.becomingNoisyEventStream.listen((_) {
      if (_player.playing) unawaited(pause());
    });
  }

  Future<void> load(MediaItem item, Uri uri) async {
    mediaItem.add(item);
    if (uri.scheme == 'asset') {
      final assetPath = uri.path.startsWith('/')
          ? uri.path.substring(1)
          : uri.path;
      await _player.setAudioSource(AudioSource.asset(assetPath, tag: item));
    } else if (uri.scheme == 'file') {
      await _player.setAudioSource(
        AudioSource.file(uri.toFilePath(), tag: item),
      );
    } else {
      await _player.setAudioSource(AudioSource.uri(uri, tag: item));
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> seek(Duration position) {
    final duration = _player.duration;
    final safePosition = position < Duration.zero
        ? Duration.zero
        : duration != null && position > duration
        ? duration
        : position;
    return _player.seek(safePosition);
  }

  @override
  Future<void> fastForward() => seek(position + const Duration(seconds: 15));

  @override
  Future<void> rewind() => seek(position - const Duration(seconds: 15));

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  Future<void> dispose() async {
    await _interruptionSubscription?.cancel();
    await _noisySubscription?.cancel();
    await _player.dispose();
  }

  PlaybackState _transformEvent(PlaybackEvent event) => PlaybackState(
    controls: [
      MediaControl.rewind,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.fastForward,
      MediaControl.stop,
    ],
    systemActions: const {
      MediaAction.seek,
      MediaAction.seekForward,
      MediaAction.seekBackward,
    },
    androidCompactActionIndices: const [0, 1, 2],
    processingState: switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    },
    playing: _player.playing,
    updatePosition: _player.position,
    bufferedPosition: _player.bufferedPosition,
    speed: _player.speed,
    queueIndex: event.currentIndex,
  );
}
