import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/util/app_log.dart';
import '../../core/util/image_prep.dart';
import '../../core/util/spell_checker.dart';
import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'admin_media_player.dart';
import 'file_pick.dart';
import 'widgets/cover_cropper.dart';

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
  // Encuadres elegidos en el recortador guiado. null = usa el recorte centrado
  // por defecto (comportamiento anterior).
  CropRect? _thumbCrop;
  CropRect? _coverCrop;
  Uint8List? _mediaBytes;
  String? _mediaName;

  String? _existingCoverUrl;
  bool _existingHasMedia = false;
  String? _existingMediaSignedUrl;

  /// Borrador creado por un intento anterior de guardar: se reutiliza en el
  /// reintento para no acumular borradores huérfanos si una subida falló.
  String? _createdId;

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
      if (!mounted) return;
      _title.text = detail.title;
      _author.text = detail.author ?? '';
      _body.text = detail.body ?? '';
      _url.text = detail.externalUrl ?? '';
      _existingHasMedia = detail.hasMedia;
      _existingMediaSignedUrl = detail.mediaSignedUrl;
      _existingCoverUrl = repo.resolveCoverUrl(detail.coverPath);
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'AdminWizard.load');
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
      // Nueva imagen: los recortadores reemitirán su encuadre centrado.
      _thumbCrop = null;
      _coverCrop = null;
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
      final repo = ref.read(adminContentRepositoryProvider);
      final input = ContentDraftInput(
        kind: widget.kind,
        title: _title.text,
        author: _author.text,
        body: _body.text,
        externalUrl: _url.text,
        coverBytes: _coverBytes,
        coverFilename: _coverName,
        thumbCrop: _thumbCrop,
        coverCrop: _coverCrop,
        mediaBytes: _mediaBytes,
        mediaFilename: _mediaName,
        mediaDurationSeconds: _detectedDuration > 0 ? _detectedDuration : null,
      );
      // El borrador se crea (o reutiliza) antes de las subidas: si una subida
      // falla, el reintento continúa sobre el mismo id.
      var id = widget.editId ?? _createdId;
      id ??= _createdId = await repo.createDraft(input);
      await repo.submit(input, publish: publish, existingId: id);
      ref.invalidate(adminItemsProvider(widget.kind));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publish ? 'Publicado' : 'Borrador guardado')),
      );
      context.pop();
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'AdminWizard.submit');
      if (mounted) setState(() => _error = 'No se pudo guardar');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Revisión ortográfica previa a publicar. Si hay palabras desconocidas se
  /// muestran subrayadas y se pide confirmación; el aviso nunca bloquea la
  /// publicación. Si el diccionario no puede cargarse, se publica sin revisar.
  Future<void> _publishWithSpellCheck() async {
    if (_busy) return;
    Map<String, List<SpellIssue>> issues = const {};
    try {
      setState(() => _busy = true);
      final checker = await SpellChecker.load();
      issues = {
        for (final entry in {
          'Título': _title.text,
          'Texto': _body.text,
        }.entries)
          if (checker.check(entry.value).isNotEmpty)
            entry.key: checker.check(entry.value),
      };
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'AdminWizard.spellCheck');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (issues.isEmpty) return _submit(publish: true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _SpellWarningDialog(
        fields: {'Título': _title.text, 'Texto': _body.text},
        issues: issues,
      ),
    );
    if (confirmed == true && mounted) await _submit(publish: true);
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
          onPressed: _busy || !_canPublish ? null : _publishWithSpellCheck,
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
      onThumbCrop: (rect) => _thumbCrop = rect,
      onCoverCrop: (rect) => _coverCrop = rect,
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
    required this.onThumbCrop,
    required this.onCoverCrop,
  });

  final Uint8List? bytes;
  final String? existingUrl;
  final void Function(Uint8List bytes, String name) onPicked;
  final ValueChanged<CropRect> onThumbCrop;
  final ValueChanged<CropRect> onCoverCrop;

  @override
  Widget build(BuildContext context) {
    final hasCover = bytes != null || existingUrl != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bytes != null) ...[
          // Encuadre guiado: la misma imagen se ajusta por separado para la
          // miniatura (cuadrada) y para la portada grande (4:5, que también se
          // usa en el reproductor).
          _CropLabel('Miniatura — lista (cuadrada)'),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: CoverCropper(
                bytes: bytes!,
                aspect: 1,
                onChanged: onThumbCrop,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _CropLabel('Portada — detalle y reproductor (4:5)'),
          const SizedBox(height: 8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: CoverCropper(
                bytes: bytes!,
                aspect: 4 / 5,
                onChanged: onCoverCrop,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arrastra y pellizca para encuadrar cada una.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ] else
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

class _CropLabel extends StatelessWidget {
  const _CropLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
          AdminMediaPlayer.fromBytes(
            bytes: pickedBytes!,
            mimeType: mimeType,
            isVideo: isVideo,
            onDurationDetected: onDurationDetected,
          ),
        ] else if (existingSignedUrl != null) ...[
          const SizedBox(height: 20),
          AdminMediaPlayer.fromUrl(
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

// ---------------------------------------------------------------------------
// Aviso de ortografía al publicar
// ---------------------------------------------------------------------------

class _SpellWarningDialog extends StatelessWidget {
  const _SpellWarningDialog({required this.fields, required this.issues});

  /// Texto completo de cada campo revisado, por etiqueta.
  final Map<String, String> fields;

  /// Palabras desconocidas por campo. Solo aparecen los campos con avisos.
  final Map<String, List<SpellIssue>> issues;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Faltas ortográficas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hay faltas ortográficas, ¿seguro que lo quieres lanzar?'),
            for (final entry in issues.entries) ...[
              const SizedBox(height: 16),
              Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _UnderlinedText(
                text: fields[entry.key] ?? '',
                issues: entry.value,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Revisar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Publicar igualmente'),
        ),
      ],
    );
  }
}

/// Muestra el texto original con las palabras dudosas subrayadas en ondulado.
class _UnderlinedText extends StatelessWidget {
  const _UnderlinedText({required this.text, required this.issues});

  final String text;
  final List<SpellIssue> issues;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final error = Theme.of(context).colorScheme.error;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final issue in issues) {
      if (issue.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, issue.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(issue.start, issue.end),
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: error,
            color: error,
          ),
        ),
      );
      cursor = issue.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
