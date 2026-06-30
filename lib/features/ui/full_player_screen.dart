import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/providers.dart';
import '../player/free_experience_audio_handler.dart';
import 'widgets/content_cover.dart';

class FullPlayerScreen extends ConsumerWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<MediaItem?>(
        stream: handler.mediaItem,
        builder: (context, mediaSnapshot) {
          final media = mediaSnapshot.data;
          if (media == null) {
            return const Center(
              child: Text(
                'Sin reproducción',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          final content = ref.watch(contentByIdProvider(media.id)).value;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (content != null)
                ContentCover(path: content.coverPath)
              else
                const ColoredBox(color: Colors.black),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x4D000000),
                      Color(0x00000000),
                      Color(0xCC000000),
                      Color(0xF2000000),
                    ],
                    stops: [0.0, 0.30, 0.70, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const _TopBar(),
                    Expanded(child: _TransportControls(handler: handler)),
                    _BottomPanel(media: media),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: 26,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Compartir',
            onPressed: () => _share(context),
            icon: const Icon(Icons.ios_share, color: Colors.white),
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(const ClipboardData(text: 'Free Experience'));
    messenger.showSnackBar(const SnackBar(content: Text('Copiado')));
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.handler});

  final FreeExperienceAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StreamBuilder<PlaybackState>(
        stream: handler.playbackState,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final playing = state?.playing ?? false;
          final buffering =
              state?.processingState == AudioProcessingState.loading ||
              state?.processingState == AudioProcessingState.buffering;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Retroceder 15 segundos',
                onPressed: () => handler.seek(
                  handler.position - const Duration(seconds: 15),
                ),
                icon: const Icon(Icons.replay_10, color: Colors.white),
                iconSize: 42,
              ),
              const SizedBox(width: 24),
              _PlayButton(
                playing: playing,
                buffering: buffering,
                onPressed: buffering
                    ? null
                    : playing
                    ? handler.pause
                    : handler.play,
              ),
              const SizedBox(width: 24),
              IconButton(
                tooltip: 'Avanzar 15 segundos',
                onPressed: () => handler.seek(
                  handler.position + const Duration(seconds: 15),
                ),
                icon: const Icon(Icons.forward_10, color: Colors.white),
                iconSize: 42,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.playing,
    required this.buffering,
    required this.onPressed,
  });

  final bool playing;
  final bool buffering;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: IconButton(
            tooltip: playing ? 'Pausar' : 'Reproducir',
            onPressed: onPressed,
            icon: buffering
                ? const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 44,
                  ),
          ),
        ),
      ),
    );
  }
}

class _BottomPanel extends ConsumerWidget {
  const _BottomPanel({required this.media});

  final MediaItem media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    final duration = media.duration ?? Duration.zero;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _format(duration),
                  style: Theme.of(
                    context,
                  ).textTheme.displaySmall?.copyWith(color: Colors.white),
                ),
              ),
              _LoopButton(handler: handler),
              _FavoriteButton(contentId: media.id),
              _MoreButton(handler: handler),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressBar(item: media),
          const SizedBox(height: 18),
          Text(
            media.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          if (media.artist != null) ...[
            const SizedBox(height: 4),
            Text(
              media.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _LoopButton extends StatelessWidget {
  const _LoopButton({required this.handler});

  final FreeExperienceAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LoopMode>(
      stream: handler.loopMode,
      builder: (context, snapshot) {
        final on = snapshot.data == LoopMode.one;
        return IconButton(
          tooltip: on ? 'Repetición activada' : 'Repetir',
          onPressed: () => handler.setLoop(!on),
          icon: Icon(Icons.repeat, color: on ? Colors.white : Colors.white54),
        );
      },
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(isFavoriteProvider(contentId)).value ?? false;
    return IconButton(
      tooltip: favorite ? 'Quitar de guardados' : 'Guardar',
      onPressed: () =>
          ref.read(contentRepositoryProvider).toggleFavorite(contentId),
      icon: Icon(
        favorite ? Icons.bookmark : Icons.bookmark_border,
        color: Colors.white,
      ),
    );
  }
}

class _MoreButton extends ConsumerWidget {
  const _MoreButton({required this.handler});

  final FreeExperienceAudioHandler handler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Más opciones',
      onPressed: () => _showMenu(context, ref),
      icon: const Icon(Icons.more_horiz, color: Colors.white),
    );
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) =>
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
                  'Velocidad',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                StreamBuilder<PlaybackState>(
                  stream: handler.playbackState,
                  builder: (context, snapshot) {
                    final speed = snapshot.data?.speed ?? 1.0;
                    return Wrap(
                      spacing: 8,
                      children: [
                        for (final value in const [0.75, 1.0, 1.25, 1.5])
                          ChoiceChip(
                            label: Text(_speedLabel(value)),
                            selected: (speed - value).abs() < 0.01,
                            onSelected: (_) {
                              handler.setSpeed(value);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Temporizador',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                for (final minutes in const [10, 20, 30])
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

  String _speedLabel(double speed) {
    final text = speed == speed.roundToDouble()
        ? speed.toStringAsFixed(0)
        : speed.toStringAsFixed(2);
    return '${text}x';
  }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _format(position),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  Text(
                    _remaining(position, duration),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value,
                max: max,
                semanticFormatterCallback: (ms) =>
                    _format(Duration(milliseconds: ms.round())),
                onChanged: (milliseconds) =>
                    handler.seek(Duration(milliseconds: milliseconds.round())),
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

  String _remaining(Duration position, Duration duration) {
    if (duration <= Duration.zero) return '--:--';
    final left = duration - position;
    final clamped = left.isNegative ? Duration.zero : left;
    return '-${_format(clamped)}';
  }
}
