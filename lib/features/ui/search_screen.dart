import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/util/formatters.dart';
import '../content/domain/content_item.dart';
import 'widgets/content_cover.dart';

/// Búsqueda global sobre todo el contenido publicado (canalizaciones,
/// meditaciones, prácticas, vídeos y recomendaciones). Compara título, autor
/// y texto ignorando mayúsculas y tildes: "utero" encuentra "Útero".
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(allPublishedContentProvider);
    final query = _normalize(_query);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Buscar',
            border: InputBorder.none,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ),
      body: items.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudo cargar'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(allPublishedContentProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (content) {
          if (query.isEmpty) return const SizedBox.shrink();
          final results = content
              .where((item) => _matches(item, query))
              .toList();
          if (results.isEmpty) {
            return const Center(child: Text('Sin resultados'));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: results.length,
            itemBuilder: (context, index) =>
                _ResultRow(item: results[index]),
          );
        },
      ),
    );
  }
}

bool _matches(ContentItem item, String query) {
  // La locución de introducción no es contenido navegable.
  if (item.kind == ContentKind.intro) return false;
  bool contains(String? value) =>
      value != null && _normalize(value).contains(query);
  return contains(item.title) || contains(item.author) || contains(item.body);
}

/// Minúsculas y sin diacríticos, para comparar de forma tolerante.
String _normalize(String value) {
  const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const plain = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = accents.indexOf(char);
    buffer.write(index >= 0 ? plain[index] : char);
  }
  return buffer.toString().trim();
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final meta = joinMeta([item.kind.label, item.author]);
    return Semantics(
      button: true,
      label: [item.title, meta].join(', '),
      child: InkWell(
        onTap: () => context.push('/content/${item.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: ContentCover(
                  path: item.thumbOrCover,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(meta, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                item.durationLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
