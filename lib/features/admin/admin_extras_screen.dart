import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'file_pick.dart';

/// Tarjeta "Extras" del panel: por ahora solo contiene "Introducción".
/// El acceso lo protege AdminGuard en la ruta.
class AdminExtrasScreen extends ConsumerWidget {
  const AdminExtrasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extras')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Introducción'),
            subtitle: const Text('Audio del reproductor de bienvenida'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/extras/introduccion'),
          ),
        ],
      ),
    );
  }
}

/// Subida del único audio de introducción. Sin portada ni título: el admin solo
/// elige el archivo. La portada se asigna automáticamente para cumplir la
/// validación de publicación.
class AdminIntroScreen extends ConsumerStatefulWidget {
  const AdminIntroScreen({super.key});

  @override
  ConsumerState<AdminIntroScreen> createState() => _AdminIntroScreenState();
}

class _AdminIntroScreenState extends ConsumerState<AdminIntroScreen> {
  PickedFile? _audio;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final picked = await pickFile('audio/*');
    if (picked == null) return;
    setState(() {
      _audio = picked;
      _error = null;
    });
  }

  Future<void> _publish() async {
    final audio = _audio;
    if (audio == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(adminContentRepositoryProvider);
      // Publica la nueva antes de borrar la anterior: si la subida falla, la
      // app conserva la introducción vigente (antes se borraba primero y un
      // fallo dejaba la app sin introducción).
      final previous = await repo.listByKind(ContentKind.intro);
      final cover = await rootBundle.load(
        'assets/images/login_illustration.png',
      );
      final newId = await repo.submit(
        ContentDraftInput(
          kind: ContentKind.intro,
          title: 'Introducción',
          coverBytes: cover.buffer.asUint8List(),
          coverFilename: 'cover.png',
          mediaBytes: audio.bytes,
          mediaFilename: audio.name,
        ),
        publish: true,
      );
      // Solo debe existir una publicada; la limpieza es best-effort porque la
      // bienvenida ya prioriza la más reciente.
      for (final row in previous) {
        if (row.id == newId) continue;
        try {
          await repo.delete(row.id);
        } on Object {
          // La intro nueva ya está publicada; una antigua huérfana no bloquea.
        }
      }
      ref.invalidate(adminItemsProvider(ContentKind.intro));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Introducción publicada')));
        context.pop();
      }
    } on Object {
      if (mounted) setState(() => _error = 'No se pudo publicar');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(adminItemsProvider(ContentKind.intro));
    return Scaffold(
      appBar: AppBar(title: const Text('Introducción')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          current.maybeWhen(
            data: (rows) => rows.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Audio actual: ${rows.first.status == 'published' ? 'publicado' : 'borrador'}'
                      '${rows.first.durationSeconds > 0 ? ' · ${rows.first.durationSeconds}s' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.audiotrack),
            label: Text(_audio == null ? 'Elegir audio' : _audio!.name),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (_audio == null || _busy) ? null : _publish,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publicar introducción'),
          ),
        ],
      ),
    );
  }
}
