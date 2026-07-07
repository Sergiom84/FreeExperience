import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../../core/util/app_log.dart';
import '../../core/util/formatters.dart';
import 'admin_preview_url.dart';

// ---------------------------------------------------------------------------
// Preview player — audio and video
// ---------------------------------------------------------------------------

/// Reproductor de previsualización del asistente de contenidos (audio y
/// vídeo), extraído de admin_wizard_screen.dart donde ocupaba ~330 líneas.
class AdminMediaPlayer extends StatefulWidget {
  const AdminMediaPlayer.fromBytes({
    required Uint8List bytes,
    required String mimeType,
    required this.isVideo,
    this.onDurationDetected,
    super.key,
  }) : _bytes = bytes,
       _mimeType = mimeType,
       _existingUrl = null;

  const AdminMediaPlayer.fromUrl({
    required String url,
    required this.isVideo,
    this.onDurationDetected,
    super.key,
  }) : _bytes = null,
       _mimeType = null,
       _existingUrl = url;

  final Uint8List? _bytes;
  final String? _mimeType;
  final String? _existingUrl;
  final bool isVideo;
  final void Function(int seconds)? onDurationDetected;

  @override
  State<AdminMediaPlayer> createState() => _AdminMediaPlayerState();
}

class _AdminMediaPlayerState extends State<AdminMediaPlayer> {
  String? _blobUrl;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _ready = false;
  Object? _error;

  // Cada _init incrementa la generación; un initialize() que termina cuando ya
  // hay otra fuente en curso descarta su controlador en vez de instalarlo
  // (antes el archivo anterior podía "ganar" al nuevo y fugar el controlador).
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant AdminMediaPlayer old) {
    super.didUpdateWidget(old);
    // Re-init when the source changes (user picks a different file).
    if (old._bytes != widget._bytes ||
        old._existingUrl != widget._existingUrl) {
      _cleanup();
      _init();
    }
  }

  bool _isStale(int generation) => generation != _generation || !mounted;

  Future<void> _init() async {
    final generation = ++_generation;
    setState(() {
      _ready = false;
      _error = null;
    });
    try {
      final String url;
      if (widget._bytes != null) {
        url = await createPreviewUrl(widget._bytes!, widget._mimeType!);
        if (_isStale(generation)) {
          revokePreviewUrl(url);
          return;
        }
        _blobUrl = url;
      } else {
        url = widget._existingUrl!;
      }

      if (widget.isVideo) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
        if (_isStale(generation)) {
          await controller.dispose();
          return;
        }
        final duration = controller.value.duration.inSeconds;
        if (duration > 0) widget.onDurationDetected?.call(duration);
        controller.addListener(_rebuild);
        setState(() {
          _videoController = controller;
          _ready = true;
        });
      } else {
        final player = AudioPlayer();
        await player.setUrl(url);
        if (_isStale(generation)) {
          await player.dispose();
          return;
        }
        final duration = player.duration?.inSeconds ?? 0;
        if (duration > 0) widget.onDurationDetected?.call(duration);
        player.playerStateStream.listen((_) {
          if (mounted) setState(() {});
        });
        setState(() {
          _audioPlayer = player;
          _ready = true;
        });
      }
    } on Object catch (e, stackTrace) {
      reportError(e, stackTrace, context: 'AdminMediaPlayer.init');
      if (!_isStale(generation)) setState(() => _error = e);
    }
  }

  void _cleanup() {
    _generation++;
    final url = _blobUrl;
    if (url != null) {
      revokePreviewUrl(url);
      _blobUrl = null;
    }
    _videoController?.removeListener(_rebuild);
    _videoController?.dispose();
    _videoController = null;
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _ready = false;
    _error = null;
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return OutlinedButton.icon(
        onPressed: () {
          _cleanup();
          _init();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar previsualización'),
      );
    }
    if (!_ready) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return widget.isVideo ? _buildVideo() : _buildAudio();
  }

  Widget _buildVideo() {
    final c = _videoController!;
    final ratio = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              if (!c.value.isPlaying)
                GestureDetector(
                  onTap: c.play,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        VideoProgressIndicator(
          c,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: c.value.isPlaying ? c.pause : c.play,
            ),
            Text(
              formatPlaybackClock(c.value.position),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Text(' / '),
            Text(
              formatPlaybackClock(c.value.duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudio() {
    final player = _audioPlayer!;
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, stateSnapshot) {
        final state = stateSnapshot.data;
        final isPlaying = state?.playing ?? false;
        final loading =
            state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, posSnap) {
                    final position = posSnap.data ?? Duration.zero;
                    final duration = player.duration ?? Duration.zero;
                    final maxMs = duration.inMilliseconds.toDouble().clamp(
                      1.0,
                      double.infinity,
                    );
                    final posMs = position.inMilliseconds.toDouble().clamp(
                      0.0,
                      maxMs,
                    );
                    return Column(
                      children: [
                        Slider(
                          value: posMs,
                          max: maxMs,
                          onChanged: (ms) =>
                              player.seek(Duration(milliseconds: ms.round())),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatPlaybackClock(position),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                formatPlaybackClock(duration),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10),
                      onPressed: () => player.seek(
                        player.position - const Duration(seconds: 10),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        onPressed: loading
                            ? null
                            : isPlaying
                            ? player.pause
                            : player.play,
                        child: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 28,
                              ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_10),
                      onPressed: () => player.seek(
                        player.position + const Duration(seconds: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
