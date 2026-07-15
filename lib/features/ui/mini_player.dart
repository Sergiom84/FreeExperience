import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import 'widgets/seek_bar.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  StreamSubscription<PlaybackState>? _stateSub;
  Timer? _hideTimer;

  /// Se oculta la barra cuando la pista terminó hace ya unos segundos. Red de
  /// seguridad de UI (además de la limpieza del mediaItem en el handler): aquí
  /// se decide con el propio `PlaybackState` que ya observamos.
  bool _hidden = false;

  static const _hideDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _stateSub = ref
        .read(audioHandlerProvider)
        .playbackState
        .listen(_onPlaybackState);
  }

  void _onPlaybackState(PlaybackState state) {
    final completed = state.processingState == AudioProcessingState.completed;
    if (completed) {
      _hideTimer ??= Timer(_hideDelay, () {
        if (mounted) setState(() => _hidden = true);
      });
    } else {
      _hideTimer?.cancel();
      _hideTimer = null;
      if (_hidden && mounted) setState(() => _hidden = false);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item == null || _hidden) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final playing = stateSnapshot.data?.playing ?? false;
            return Material(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                  SeekBar.mini(duration: item.duration ?? Duration.zero),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: 'Abrir reproductor: ${item.title}',
                            child: InkWell(
                              onTap: () => context.push('/player'),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (item.artist != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.artist!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Retroceder 10 segundos',
                          onPressed: handler.rewind,
                          icon: const Icon(Icons.replay_10),
                        ),
                        IconButton(
                          tooltip: playing ? 'Pausar' : 'Reproducir',
                          onPressed: playing ? handler.pause : handler.play,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        ),
                        IconButton(
                          tooltip: 'Avanzar 10 segundos',
                          onPressed: handler.fastForward,
                          icon: const Icon(Icons.forward_10),
                        ),
                        IconButton(
                          tooltip: 'Abrir reproductor',
                          onPressed: () => context.push('/player'),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Theme.of(context).dividerColor),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
