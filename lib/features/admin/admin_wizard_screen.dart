import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
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
    if (_hasMediaKind) return _hasMedia;
    return _body.text.trim().isNotEmpty || _url.text.trim().isNotEmpty;
  }

  bool get _canAdvance => switch (_steps[_index]) {
    _Step.titleAuthor => _title.text.trim().isNotEmpty,
    _ => true,
  };

  Future<void> _pickCover() async {
    final picked = await pickFile('image/*');
    if (picked == null) return;
    setState(() {
      _coverBytes = picked.bytes;
      _coverName = picked.name;
    });
  }

  Future<void> _pickMedia() async {
    final isVideo = widget.kind == ContentKind.video;
    final picked = await pickFile(isVideo ? 'video/*' : 'audio/*');
    if (picked == null) return;
    setState(() {
      _mediaBytes = picked.bytes;
      _mediaName = picked.name;
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
      onPick: _pickCover,
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
      hasExisting: _existingHasMedia,
      onPick: _pickMedia,
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
    required this.onPick,
  });

  final Uint8List? bytes;
  final String? existingUrl;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final hasCover = bytes != null || existingUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onPick,
          child: _CoverFrame(
            bytes: bytes,
            url: existingUrl,
            placeholder: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onPick,
          child: Text(hasCover ? 'Cambiar portada' : 'Elegir portada'),
        ),
      ],
    );
  }
}

class _MediaStep extends StatelessWidget {
  const _MediaStep({
    required this.isVideo,
    required this.pickedName,
    required this.hasExisting,
    required this.onPick,
  });

  final bool isVideo;
  final String? pickedName;
  final bool hasExisting;
  final VoidCallback onPick;

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
        OutlinedButton(
          onPressed: onPick,
          child: Text(
            label == null
                ? (isVideo ? 'Elegir vídeo' : 'Elegir audio')
                : 'Cambiar archivo',
          ),
        ),
      ],
    );
  }
}

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
