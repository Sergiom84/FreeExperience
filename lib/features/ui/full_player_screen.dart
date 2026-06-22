import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'widgets/content_cover.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    final queue = ref.watch(playbackQueueProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproduciendo'),
        actions: [
          StreamBuilder<PlaybackState>(
            stream: handler.playbackState,
            builder: (context, snapshot) {
              final speed = snapshot.data?.speed ?? 1.0;
              return TextButton(
                onPressed: () => handler.setSpeed(_nextSpeed(speed)),
                child: Text(_speedLabel(speed)),
              );
            },
          ),
          IconButton(
            tooltip: 'Temporizador',
            onPressed: () => _showTimer(context, ref),
            icon: const Icon(Icons.timer_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, mediaSnapshot) {
          final media = mediaSnapshot.data;
          if (media == null) {
            return const Center(child: Text('Sin reproducción'));
          }
          final content = ref.watch(contentByIdProvider(media.id)).value;
          return SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 4 / 5,
                            child: content == null
                                ? ColoredBox(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  )
                                : ContentCover(path: content.coverPath),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        media.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      if (media.artist != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          media.artist!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 22),
                      _ProgressBar(item: media),
                      const SizedBox(height: 18),
                      StreamBuilder<PlaybackState>(
                        stream: handler.playbackState,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          final playing = state?.playing ?? false;
                          final buffering =
                              state?.processingState ==
                                  AudioProcessingState.loading ||
                              state?.processingState ==
                                  AudioProcessingState.buffering;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                tooltip: 'Anterior',
                                onPressed: (queue?.hasPrevious ?? false)
                                    ? () => ref
                                          .read(playbackCoordinatorProvider)
                                          .skipToPrevious()
                                    : null,
                                icon: const Icon(Icons.skip_previous),
                                iconSize: 28,
                              ),
                              IconButton(
                                tooltip: 'Retroceder 15 segundos',
                                onPressed: () => handler.seek(
                                  handler.position -
                                      const Duration(seconds: 15),
                                ),
                                icon: const Icon(Icons.replay_10),
                                iconSize: 30,
                              ),
                              SizedBox(
                                width: 68,
                                height: 68,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                  ),
                                  onPressed: buffering
                                      ? null
                                      : playing
                                      ? handler.pause
                                      : handler.play,
                                  child: buffering
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          playing
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          size: 32,
                                        ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Avanzar 15 segundos',
                                onPressed: () => handler.seek(
                                  handler.position +
                                      const Duration(seconds: 15),
                                ),
                                icon: const Icon(Icons.forward_10),
                                iconSize: 30,
                              ),
                              IconButton(
                                tooltip: 'Siguiente',
                                onPressed: (queue?.hasNext ?? false)
                                    ? () => ref
                                          .read(playbackCoordinatorProvider)
                                          .skipToNext()
                                    : null,
                                icon: const Icon(Icons.skip_next),
                                iconSize: 28,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _nextSpeed(double speed) => switch (speed) {
    < 1.0 => 1.0,
    < 1.25 => 1.25,
    < 1.5 => 1.5,
    _ => 0.75,
  };

  String _speedLabel(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toStringAsFixed(2);
    return '${text}x';
  }

  Future<void> _showTimer(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temporizador',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                for (final minutes in [10, 20, 30])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$minutes min'),
                    onTap: () {
                      ref
                          .read(playbackCoordinatorProvider)
                          .setSleepTimer(Duration(minutes: minutes));
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desactivar'),
                  onTap: () {
                    ref.read(playbackCoordinatorProvider).setSleepTimer(null);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

class _ProgressBar extends ConsumerWidget {
  const _ProgressBar({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final duration = item.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final max = duration.inMilliseconds
            .toDouble()
            .clamp(1, double.infinity)
            .toDouble();
        final value = position.inMilliseconds
            .toDouble()
            .clamp(0, max)
            .toDouble();
        return Column(
          children: [
            Slider(
              value: value,
              max: max,
              semanticFormatterCallback: (ms) =>
                  _format(Duration(milliseconds: ms.round())),
              onChanged: (milliseconds) =>
                  handler.seek(Duration(milliseconds: milliseconds.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(position),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    _format(duration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
