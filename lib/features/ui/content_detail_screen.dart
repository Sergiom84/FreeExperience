import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/providers.dart';
import '../../core/util/app_log.dart';
import '../../core/util/formatters.dart';
import '../content/domain/content_item.dart';
import '../downloads/download_manager.dart';
import 'catalog_screen.dart' show CatalogError;
import 'mini_player.dart';
import 'widgets/content_cover.dart';
import 'widgets/youtube_embed.dart';

class ContentDetailScreen extends ConsumerWidget {
  const ContentDetailScreen({required this.contentId, super.key});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(contentByIdProvider(contentId));
    return Scaffold(
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      appBar: AppBar(
        actions: [
          _FavoriteButton(contentId: contentId),
          const SizedBox(width: 8),
        ],
      ),
      body: item.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: CatalogError(
            onRetry: () => ref.invalidate(contentByIdProvider(contentId)),
          ),
        ),
        data: (content) {
          if (content == null) {
            return const Center(child: Text('No disponible'));
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
                children: [
                  // Portada a ancho completo en 4:5 (encuadre canónico).
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: ContentCover(path: content.coverPath),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    content.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    joinMeta([content.author, content.durationLabel]),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  if (content.kind.isAudio) _AudioActions(item: content),
                  if (content.kind == ContentKind.video)
                    _VideoSection(item: content),
                  if (content.kind == ContentKind.recommendation)
                    _RecommendationSection(item: content),
                  if (content.kind != ContentKind.recommendation &&
                      (content.body?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 24),
                    Text(
                      content.body!.trim(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ],
              ),
            ),
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
      onPressed: () =>
          ref.read(contentRepositoryProvider).toggleFavorite(contentId),
      icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
    );
  }
}

class _AudioActions extends ConsumerWidget {
  const _AudioActions({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    final download =
        ref.watch(downloadProvider(item.id)).value ??
        const DownloadSnapshot(state: DownloadState.none);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StreamBuilder<MediaItem?>(
                stream: handler.mediaItem,
                builder: (context, snapshot) {
                  final isCurrent = snapshot.data?.id == item.id;
                  return FilledButton.icon(
                    onPressed: () async {
                      if (isCurrent) {
                        context.push('/player');
                        return;
                      }
                      try {
                        await ref.read(playbackCoordinatorProvider).play(item);
                      } on Object catch (error, stackTrace) {
                        reportError(
                          error,
                          stackTrace,
                          context: 'ContentDetail.play',
                        );
                        if (context.mounted) {
                          final reason = error.toString();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'No se pudo reproducir: '
                                '${reason.length > 120 ? '${reason.substring(0, 120)}…' : reason}',
                              ),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      isCurrent ? Icons.keyboard_arrow_up : Icons.play_arrow,
                    ),
                    label: Text(isCurrent ? 'Abrir reproductor' : 'Reproducir'),
                  );
                },
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
                DownloadState.failed => IconButton.outlined(
                  tooltip: 'Reintentar descarga',
                  onPressed: () => _download(context, ref),
                  icon: const Icon(Icons.error_outline),
                ),
                _ => IconButton.outlined(
                  tooltip: 'Descargar',
                  onPressed: () => _download(context, ref),
                  icon: const Icon(Icons.download_outlined),
                ),
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(playbackCoordinatorProvider).addToQueue(item);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Añadido a la cola')),
              );
            }
          },
          icon: const Icon(Icons.playlist_add),
          label: const Text('Añadir a la cola'),
        ),
      ],
    );
  }

  /// Lanza la descarga e informa del motivo real si falla (antes el fallo
  /// era mudo y el botón volvía al icono de descargar).
  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(downloadManagerProvider).download(item);
    } on Object catch (error) {
      if (context.mounted) {
        final reason = error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo descargar: '
              '${reason.length > 120 ? '${reason.substring(0, 120)}…' : reason}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

/// Decide cómo mostrar un vídeo: YouTube embebido, enlace externo
/// (p. ej. Instagram) o el archivo subido a Supabase.
class _VideoSection extends StatelessWidget {
  const _VideoSection({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.externalUrl;
    if (url != null && url.trim().isNotEmpty) {
      final videoId = youtubeVideoId(url);
      if (videoId != null) return YoutubeEmbed(videoId: videoId);
      return _ExternalLinkButton(url: url.trim());
    }
    return _UploadedVideoSection(item: item);
  }
}

/// Abre un enlace externo e informa si no se pudo (antes el fallo era mudo).
Future<void> _openExternal(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } on Object catch (error, stackTrace) {
    reportError(error, stackTrace, context: 'ContentDetail.openExternal');
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
  }
}

class _ExternalLinkButton extends StatelessWidget {
  const _ExternalLinkButton({required this.url});

  final String url;

  bool get _isInstagram => url.toLowerCase().contains('instagram.com');

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _openExternal(context, url),
      icon: Icon(
        _isInstagram ? Icons.camera_alt_outlined : Icons.arrow_outward,
      ),
      label: Text(_isInstagram ? 'Ver en Instagram' : 'Abrir enlace'),
    );
  }
}

class _UploadedVideoSection extends ConsumerStatefulWidget {
  const _UploadedVideoSection({required this.item});

  final ContentItem item;

  @override
  ConsumerState<_UploadedVideoSection> createState() =>
      _UploadedVideoSectionState();
}

class _UploadedVideoSectionState extends ConsumerState<_UploadedVideoSection> {
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
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'UploadedVideo.initialize');
      if (mounted) setState(() => _error = error);
    }
  }

  void _togglePlayback(VideoPlayerController controller) {
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      // El vídeo no pasa por el coordinador de audio: se pausa a mano lo que
      // esté sonando para que no suenen los dos a la vez.
      ref.read(audioHandlerProvider).pause();
      controller.play();
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
        // Solo el botón escucha al controlador: antes un listener global
        // reconstruía toda la sección en cada frame del vídeo.
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => FilledButton.icon(
            onPressed: () => _togglePlayback(controller),
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
            label: Text(value.isPlaying ? 'Pausar' : 'Reproducir'),
          ),
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
            onPressed: () => _openExternal(context, item.externalUrl!),
            icon: const Icon(Icons.arrow_outward),
            label: const Text('Abrir'),
          ),
        ],
      ],
    );
  }
}
