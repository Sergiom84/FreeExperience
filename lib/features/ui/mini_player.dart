import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item == null) return const SizedBox.shrink();
        return StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnapshot) {
            final playing = stateSnapshot.data?.playing ?? false;
            return Material(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniSeekBar(duration: item.duration ?? Duration.zero),
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
                          tooltip: 'Retroceder 15 segundos',
                          onPressed: () => handler.seek(
                            handler.position - const Duration(seconds: 15),
                          ),
                          icon: const Icon(Icons.replay_10),
                        ),
                        IconButton(
                          tooltip: playing ? 'Pausar' : 'Reproducir',
                          onPressed: playing ? handler.pause : handler.play,
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        ),
                        IconButton(
                          tooltip: 'Avanzar 15 segundos',
                          onPressed: () => handler.seek(
                            handler.position + const Duration(seconds: 15),
                          ),
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniSeekBar extends ConsumerWidget {
  const _MiniSeekBar({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final max = duration.inMilliseconds
            .toDouble()
            .clamp(1, double.infinity)
            .toDouble();
        final value = (snapshot.data ?? Duration.zero).inMilliseconds
            .toDouble()
            .clamp(0, max)
            .toDouble();
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            max: max,
            onChanged: (milliseconds) =>
                handler.seek(Duration(milliseconds: milliseconds.round())),
          ),
        );
      },
    );
  }
}
