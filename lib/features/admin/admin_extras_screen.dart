import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/domain/content_item.dart';
import 'admin_content_repository.dart';
import 'admin_controller.dart';
import 'admin_gate_screen.dart';
import 'file_pick.dart';

/// Tarjeta "Extras" del panel: por ahora solo contiene "Introducción".
class AdminExtrasScreen extends ConsumerWidget {
  const AdminExtrasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(isAdminProvider).value ?? false;
    if (!admin) return const AdminGateScreen();
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
      // Reemplaza la intro anterior (solo debe existir una publicada).
      final existing = await repo.listByKind(ContentKind.intro);
      for (final row in existing) {
        await repo.delete(row.id);
      }
      final cover = await rootBundle.load(
        'assets/images/login_illustration.png',
      );
      await repo.submit(
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
      ref.invalidate(adminItemsProvider(ContentKind.intro));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Introducción publicada')));
        context.pop();
      }
    } on Object catch (e) {
      setState(() => _error = 'No se pudo publicar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(isAdminProvider).value ?? false;
    if (!admin) return const AdminGateScreen();
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
