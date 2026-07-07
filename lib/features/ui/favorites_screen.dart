import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../content/domain/content_item.dart';
import 'catalog_screen.dart' show CatalogError;
import 'widgets/content_cover.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteContentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Guardados')),
      body: favorites.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, stackTrace) => Center(
          child: CatalogError(
            onRetry: () => ref.invalidate(favoriteContentProvider),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Sin guardados'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 25),
                itemBuilder: (context, index) =>
                    _FavoriteRow(item: items[index]),
              ),
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: item.title,
      child: InkWell(
        onTap: () => context.push('/content/${item.id}'),
        child: SizedBox(
          height: 104,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ContentCover(path: item.coverPath),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      [item.kind.label, item.author, item.durationLabel]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar de guardados',
                onPressed: () =>
                    ref.read(contentRepositoryProvider).toggleFavorite(item.id),
                icon: const Icon(Icons.bookmark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
