import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'admin_preview_url.dart';
import 'file_pick.dart';

enum _Step { cover, titleAuthor, body, media, recommendation, preview }

const _maxContentWidth = 520.0;

class AdminWizardScreen extends ConsumerStatefulWidget {
  const AdminWizardScreen({required this.kind, this.editId, super.key});

  final ContentKind kind;
  final String? editId;

  @override
  ConsumerState<AdminWizardScreen> createState() => _AdminWizardScreenState();
}

class _AdminWizardScreenState extends ConsumerState<AdminWizardScreen> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _body = TextEditingController();
  final _url = TextEditingController();

  Uint8List? _coverBytes;
  String? _coverName;
  Uint8List? _mediaBytes;
  String? _mediaName;

  String? _existingCoverUrl;
  bool _existingHasMedia = false;
  String? _existingMediaSignedUrl;

  int _detectedDuration = 0;

  int _index = 0;
  bool _busy = false;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _body.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(adminContentRepositoryProvider);
      final detail = await repo.getDetail(widget.editId!);
      _title.text = detail.title;
      _author.text = detail.author ?? '';
      _body.text = detail.body ?? '';
      _url.text = detail.externalUrl ?? '';
      _existingHasMedia = detail.hasMedia;
      _existingMediaSignedUrl = detail.mediaSignedUrl;
      _existingCoverUrl = detail.coverPath == null
          ? null
          : repo.coverPublicUrl(detail.coverPath!);
    } on Object {
      if (mounted) setState(() => _error = 'No se pudo cargar');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Step> get _steps => switch (widget.kind) {
    ContentKind.recommendation => const [
      _Step.cover,
      _Step.titleAuthor,
      _Step.recommendation,
      _Step.preview,
    ],
    _ => const [
      _Step.cover,
      _Step.titleAuthor,
      _Step.body,
      _Step.media,
      _Step.preview,
    ],
  };

  bool get _hasMediaKind => widget.kind != ContentKind.recommendation;
  bool get _hasCover => _coverBytes != null || _existingCoverUrl != null;
  bool get _hasMedia => _mediaBytes != null || _existingHasMedia;

  bool get _canPublish {
    if (_title.text.trim().isEmpty || !_hasCover) return false;
    if (_hasMediaKind) {
      if (widget.kind == ContentKind.video) {
        return _hasMedia || _url.text.trim().isNotEmpty;
      }
      return _hasMedia;
    }
    return _body.text.trim().isNotEmpty || _url.text.trim().isNotEmpty;
  }

  bool get _canAdvance => switch (_steps[_index]) {
    _Step.titleAuthor => _title.text.trim().isNotEmpty,
    _ => true,
  };

  String get _mediaMimeType {
    final isVideo = widget.kind == ContentKind.video;
    final name = _mediaName;
    if (name == null || !name.contains('.')) {
      return isVideo ? 'video/mp4' : 'audio/mpeg';
    }
    final ext = name.split('.').last.toLowerCase();
    return AdminContentRepository.mediaMime(ext, isVideo: isVideo);
  }

  void _onCoverPicked(Uint8List bytes, String name) {
    setState(() {
      _coverBytes = bytes;
      _coverName = name;
    });
  }

  void _onMediaPicked(Uint8List bytes, String name) {
    setState(() {
      _mediaBytes = bytes;
      _mediaName = name;
      _detectedDuration = 0;
    });
  }

  Future<void> _submit({required bool publish}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(adminContentRepositoryProvider)
          .submit(
            ContentDraftInput(
              kind: widget.kind,
              title: _title.text,
              author: _author.text,
              body: _body.text,
              externalUrl: _url.text,
              coverBytes: _coverBytes,
              coverFilename: _coverName,
              mediaBytes: _mediaBytes,
              mediaFilename: _mediaName,
              mediaDurationSeconds: _detectedDuration > 0
                  ? _detectedDuration
                  : null,
            ),
            publish: publish,
            existingId: widget.editId,
          );
      ref.invalidate(adminItemsProvider(widget.kind));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publish ? 'Publicado' : 'Borrador guardado')),
      );
      context.pop();
    } on Object {
      if (mounted) setState(() => _error = 'No se pudo guardar');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    if (_index < _steps.length - 1) setState(() => _index++);
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _steps.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.label)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : Column(
                children: [
                  LinearProgressIndicator(value: (_index + 1) / _steps.length),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: _maxContentWidth,
                        ),
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            Text(
                              'Paso ${_index + 1} de ${_steps.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 20),
                            _buildStep(_steps[_index]),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxContentWidth,
                      ),
                      child: _NavBar(
                        showBack: _index > 0,
                        busy: _busy,
                        onBack: _back,
                        child: isLast ? _finishButtons() : _nextButton(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _nextButton() => FilledButton(
    onPressed: _canAdvance ? _next : null,
    child: const Text('Siguiente'),
  );

  Widget _finishButtons() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: _busy || _title.text.trim().isEmpty
              ? null
              : () => _submit(publish: false),
          child: const Text('Guardar borrador'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: _busy || !_canPublish
              ? null
              : () => _submit(publish: true),
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Publicar'),
        ),
      ),
    ],
  );

  Widget _buildStep(_Step step) => switch (step) {
    _Step.cover => _CoverStep(
      bytes: _coverBytes,
      existingUrl: _existingCoverUrl,
      onPicked: _onCoverPicked,
    ),
    _Step.titleAuthor => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: !_isEdit,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _author,
          decoration: const InputDecoration(labelText: 'Autor'),
        ),
      ],
    ),
    _Step.body => TextField(
      controller: _body,
      minLines: 4,
      maxLines: 10,
      decoration: const InputDecoration(labelText: 'Texto'),
    ),
    _Step.recommendation => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _body,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Texto'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Enlace (https://)'),
        ),
      ],
    ),
    _Step.media => _MediaStep(
      isVideo: widget.kind == ContentKind.video,
      pickedName: _mediaName,
      pickedBytes: _mediaBytes,
      mimeType: _mediaMimeType,
      hasExisting: _existingHasMedia,
      existingSignedUrl: _existingMediaSignedUrl,
      onPicked: _onMediaPicked,
      urlController: widget.kind == ContentKind.video ? _url : null,
      onUrlChanged: () => setState(() {}),
      onDurationDetected: (seconds) {
        if (seconds > 0) _detectedDuration = seconds;
      },
    ),
    _Step.preview => _PreviewStep(
      title: _title.text,
      author: _author.text,
      body: _body.text,
      coverBytes: _coverBytes,
      existingCoverUrl: _existingCoverUrl,
    ),
  };
}

// ---------------------------------------------------------------------------
// Nav bar
// ---------------------------------------------------------------------------

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.showBack,
    required this.busy,
    required this.onBack,
    required this.child,
  });

  final bool showBack;
  final bool busy;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (showBack) ...[
            OutlinedButton(
              onPressed: busy ? null : onBack,
              child: const Text('Atrás'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cover step
// ---------------------------------------------------------------------------

class _CoverFrame extends StatelessWidget {
  const _CoverFrame({this.bytes, this.url, this.placeholder});

  final Uint8List? bytes;
  final String? url;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover)
            : url != null
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => Center(
                  child: placeholder ?? const Icon(Icons.image_outlined),
                ),
              )
            : Center(child: placeholder ?? const Icon(Icons.image_outlined)),
      ),
    );
  }
}

class _CoverStep extends StatelessWidget {
  const _CoverStep({
    required this.bytes,
    required this.existingUrl,
    required this.onPicked,
  });

  final Uint8List? bytes;
  final String? existingUrl;
  final void Function(Uint8List bytes, String name) onPicked;

  @override
  Widget build(BuildContext context) {
    final hasCover = bytes != null || existingUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoverFrame(
          bytes: bytes,
          url: existingUrl,
          placeholder: const Icon(Icons.add_photo_alternate_outlined),
        ),
        const SizedBox(height: 12),
        FilePickerButton(
          accept: 'image/*',
          label: hasCover ? 'Cambiar portada' : 'Elegir portada',
          onPicked: onPicked,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Media step
// ---------------------------------------------------------------------------

class _MediaStep extends StatelessWidget {
  const _MediaStep({
    required this.isVideo,
    required this.pickedName,
    required this.pickedBytes,
    required this.mimeType,
    required this.hasExisting,
    required this.onPicked,
    this.existingSignedUrl,
    this.urlController,
    this.onUrlChanged,
    this.onDurationDetected,
  });

  final bool isVideo;
  final String? pickedName;
  final Uint8List? pickedBytes;
  final String mimeType;
  final bool hasExisting;
  final String? existingSignedUrl;
  final void Function(Uint8List bytes, String name) onPicked;
  final TextEditingController? urlController;
  final VoidCallback? onUrlChanged;
  final void Function(int seconds)? onDurationDetected;

  @override
  Widget build(BuildContext context) {
    final label = pickedName ?? (hasExisting ? 'Archivo actual' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Icon(isVideo ? Icons.movie_outlined : Icons.audiotrack),
                const SizedBox(width: 12),
                Expanded(child: Text(label)),
              ],
            ),
          ),
        if (label != null) const SizedBox(height: 12),
        FilePickerButton(
          accept: isVideo ? 'video/*' : 'audio/*',
          label: label == null
              ? (isVideo ? 'Elegir vídeo' : 'Elegir audio')
              : 'Cambiar archivo',
          onPicked: onPicked,
        ),
        // ----------------------------------------------------------------
        // Preview player — shown when bytes just picked OR existing media
        // ----------------------------------------------------------------
        if (pickedBytes != null) ...[
          const SizedBox(height: 20),
          _AdminMediaPlayer.fromBytes(
            bytes: pickedBytes!,
            mimeType: mimeType,
            isVideo: isVideo,
            onDurationDetected: onDurationDetected,
          ),
        ] else if (existingSignedUrl != null) ...[
          const SizedBox(height: 20),
          _AdminMediaPlayer.fromUrl(
            url: existingSignedUrl!,
            isVideo: isVideo,
            onDurationDetected: onDurationDetected,
          ),
        ],
        if (urlController != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o'),
              ),
              Expanded(child: Divider(color: Theme.of(context).dividerColor)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onChanged: (_) => onUrlChanged?.call(),
            decoration: const InputDecoration(
              labelText: 'Enlace de YouTube o Instagram',
              helperText: 'Sube un archivo o pega un enlace, no ambos.',
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Preview player — audio and video
// ---------------------------------------------------------------------------

class _AdminMediaPlayer extends StatefulWidget {
  const _AdminMediaPlayer.fromBytes({
    required Uint8List bytes,
    required String mimeType,
    required this.isVideo,
    this.onDurationDetected,
  }) : _bytes = bytes,
       _mimeType = mimeType,
       _existingUrl = null;

  const _AdminMediaPlayer.fromUrl({
    required String url,
    required this.isVideo,
    this.onDurationDetected,
  }) : _bytes = null,
       _mimeType = null,
       _existingUrl = url;

  final Uint8List? _bytes;
  final String? _mimeType;
  final String? _existingUrl;
  final bool isVideo;
  final void Function(int seconds)? onDurationDetected;

  @override
  State<_AdminMediaPlayer> createState() => _AdminMediaPlayerState();
}

class _AdminMediaPlayerState extends State<_AdminMediaPlayer> {
  String? _blobUrl;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _AdminMediaPlayer old) {
    super.didUpdateWidget(old);
    // Re-init when the source changes (user picks a different file).
    if (old._bytes != widget._bytes ||
        old._existingUrl != widget._existingUrl) {
      _cleanup();
      _init();
    }
  }

  Future<void> _init() async {
    setState(() {
      _ready = false;
      _error = null;
    });
    try {
      final String url;
      if (widget._bytes != null) {
        url = await createPreviewUrl(widget._bytes!, widget._mimeType!);
        _blobUrl = url;
      } else {
        url = widget._existingUrl!;
      }

      if (widget.isVideo) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
        final duration = controller.value.duration.inSeconds;
        if (duration > 0) widget.onDurationDetected?.call(duration);
        controller.addListener(_rebuild);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        setState(() {
          _videoController = controller;
          _ready = true;
        });
      } else {
        final player = AudioPlayer();
        await player.setUrl(url);
        final duration = player.duration?.inSeconds ?? 0;
        if (duration > 0) widget.onDurationDetected?.call(duration);
        player.playerStateStream.listen((_) {
          if (mounted) setState(() {});
        });
        if (!mounted) {
          await player.dispose();
          return;
        }
        setState(() {
          _audioPlayer = player;
          _ready = true;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _cleanup() {
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
              _formatDuration(c.value.position),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Text(' / '),
            Text(
              _formatDuration(c.value.duration),
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
                                _formatDuration(position),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                _formatDuration(duration),
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ---------------------------------------------------------------------------
// Preview step
// ---------------------------------------------------------------------------

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.title,
    required this.author,
    required this.body,
    required this.coverBytes,
    required this.existingCoverUrl,
  });

  final String title;
  final String author;
  final String body;
  final Uint8List? coverBytes;
  final String? existingCoverUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverFrame(bytes: coverBytes, url: existingCoverUrl),
        const SizedBox(height: 24),
        Text(
          title.trim().isEmpty ? 'Sin título' : title.trim(),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        if (author.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(author.trim(), style: Theme.of(context).textTheme.bodySmall),
        ],
        if (body.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(body.trim(), style: Theme.of(context).textTheme.bodyLarge),
        ],
      ],
    );
  }
}
