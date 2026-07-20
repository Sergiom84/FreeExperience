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
        // Al terminar, oculta el reproductor (mini y grande) tras una breve
        // pausa. Se cancela si el usuario vuelve a reproducir o carga otra
        // pista dentro de ese margen. Con LoopMode.one no ocurre (repite).
        _scheduleHide();
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _noisySubscription;
  Timer? _hideTimer;

  static const _hideDelay = Duration(seconds: 3);
  static const _pauseHideDelay = Duration(seconds: 5);

  void _scheduleHide([Duration delay = _hideDelay]) {
    _hideTimer?.cancel();
    _hideTimer = Timer(delay, () {
      // Nada que sonar: se limpia la pista para que la UI oculte el player.
      mediaItem.add(null);
      unawaited(_player.stop());
    });
  }

  /// Corta la reproducción y oculta el reproductor al instante (p. ej. al
  /// salir de la pantalla del portal con la locución sonando).
  Future<void> dismiss() async {
    _cancelHide();
    mediaItem.add(null);
    await _player.stop();
  }

  void _cancelHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  Duration get position => _player.position;

  /// Modo de bucle actual (off / repetir pista). Lo consume el reproductor
  /// maximizado para pintar el icono de repetición.
  Stream<LoopMode> get loopMode => _player.loopModeStream;

  Future<void> setLoop(bool enabled) =>
      _player.setLoopMode(enabled ? LoopMode.one : LoopMode.off);

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
    _cancelHide();
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
      // Stream remoto: cachea progresivamente a disco mientras reproduce para
      // evitar cortes/rebuffer en redes inestables (móvil).
      try {
        // ignore: experimental_member_use
        await _player.setAudioSource(LockCachingAudioSource(uri, tag: item));
      } on Object {
        // La fuente cacheada usa un proxy HTTP local; en la primera carga en
        // frío (p. ej. la locución de bienvenida, primera reproducción de la
        // app) y en algunos dispositivos falla con "(0) Source error" antes de
        // que el proxy esté listo. Se reintenta con una fuente progresiva
        // simple, que ExoPlayer/AVPlayer resuelven de forma más robusta aunque
        // sin caché a disco.
        await _player.setAudioSource(AudioSource.uri(uri, tag: item));
      }
    }
  }

  @override
  Future<void> play() {
    _cancelHide();
    return _player.play();
  }

  @override
  Future<void> pause() {
    // En pausa el reproductor también se oculta a los pocos segundos; volver
    // a reproducir siempre empieza desde el principio, así que no se pierde
    // nada al descargar la pista.
    if (mediaItem.value != null) _scheduleHide(_pauseHideDelay);
    return _player.pause();
  }

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
    // Interacción en pausa: se pospone el auto-ocultado mientras el usuario
    // sigue moviéndose por la pista.
    if (!_player.playing && _hideTimer != null) {
      _scheduleHide(_pauseHideDelay);
    }
    _pendingSeek = safePosition;
    return _player.seek(safePosition).whenComplete(() {
      if (_pendingSeek == safePosition) _pendingSeek = null;
    });
  }

  /// Avanza o retrocede respecto al último seek pedido, no respecto a la
  /// posición real: con toques rápidos sobre una fuente de red la posición
  /// tarda en actualizarse y los saltos se "tragaban" unos a otros.
  Future<void> seekRelative(Duration offset) {
    final base = _pendingSeek ?? _player.position;
    return seek(base + offset);
  }

  Duration? _pendingSeek;

  // 10 segundos, en línea con los iconos replay_10/forward_10 de la UI.
  @override
  Future<void> fastForward() => seekRelative(const Duration(seconds: 10));

  @override
  Future<void> rewind() => seekRelative(const Duration(seconds: -10));

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  Future<void> dispose() async {
    _cancelHide();
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
