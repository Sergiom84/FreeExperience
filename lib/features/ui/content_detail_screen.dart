import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers.dart';
import '../content/domain/content_item.dart';
import '../downloads/download_manager.dart';
import 'widgets/content_cover.dart';

class ContentDetailScreen extends ConsumerWidget {
  const ContentDetailScreen({required this.contentId, super.key});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(contentByIdProvider(contentId));
    return Scaffold(
      appBar: AppBar(
        actions: [
          _FavoriteButton(contentId: contentId),
          const SizedBox(width: 8),
        ],
      ),
      body: item.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) =>
            const Center(child: Text('No disponible')),
        data: (content) {
          if (content == null) {
            return const Center(child: Text('No disponible'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ContentCover(path: content.coverPath),
              ),
              const SizedBox(height: 24),
              Text(
                content.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 10),
              Text(
                [content.author, content.durationLabel]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              if (content.kind.isAudio) _AudioActions(item: content),
              if (content.kind == ContentKind.video)
                _VideoSection(item: content),
              if (content.kind == ContentKind.recommendation)
                _RecommendationSection(item: content),
            ],
          );
        },
      ),
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
      onPressed: () async {
        await ref.read(contentRepositoryProvider).toggleFavorite(contentId);
        await ref.read(syncServiceProvider).synchronize();
      },
      icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
    );
  }
}

class _AudioActions extends ConsumerWidget {
  const _AudioActions({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download =
        ref.watch(downloadProvider(item.id)).value ??
        const DownloadSnapshot(state: DownloadState.none);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () async {
              try {
                await ref.read(playbackCoordinatorProvider).play(item);
                if (context.mounted) context.push('/player');
              } on Object {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No se pudo reproducir')),
                  );
                }
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Reproducir'),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          height: 48,
          child: switch (download.state) {
            DownloadState.queued || DownloadState.downloading => Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator.adaptive(
                  value: download.progress,
                  strokeWidth: 2,
                ),
              ),
            ),
            DownloadState.downloaded => IconButton.outlined(
              tooltip: 'Eliminar descarga',
              onPressed: () =>
                  ref.read(downloadManagerProvider).remove(item.id),
              icon: const Icon(Icons.download_done),
            ),
            _ => IconButton.outlined(
              tooltip: 'Descargar',
              onPressed: () => ref.read(downloadManagerProvider).download(item),
              icon: const Icon(Icons.download_outlined),
            ),
          },
        ),
      ],
    );
  }
}

class _VideoSection extends ConsumerStatefulWidget {
  const _VideoSection({required this.item});

  final ContentItem item;

  @override
  ConsumerState<_VideoSection> createState() => _VideoSectionState();
}

class _VideoSectionState extends ConsumerState<_VideoSection> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final uri = await ref.read(downloadManagerProvider).resolve(widget.item);
      if (uri == null) throw StateError('video unavailable');
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_error != null) {
      return OutlinedButton(
        onPressed: _initialize,
        child: const Text('Reintentar'),
      );
    }
    if (controller == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
          icon: Icon(
            controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
          label: Text(controller.value.isPlaying ? 'Pausar' : 'Reproducir'),
        ),
      ],
    );
  }
}

class _RecommendationSection extends StatelessWidget {
  const _RecommendationSection({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.body != null)
          Text(item.body!, style: Theme.of(context).textTheme.bodyLarge),
        if (item.externalUrl != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(item.externalUrl!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.arrow_outward),
            label: const Text('Abrir'),
          ),
        ],
      ],
    );
  }
}
