import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../content/domain/content_item.dart';
import 'catalog_screen.dart';
import 'widgets/screen_header.dart';

class InspirationScreen extends ConsumerWidget {
  const InspirationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: ScreenHeader(title: 'Inspiración'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                tabs: const [
                  Tab(text: 'Vídeos'),
                  Tab(text: 'Recomendaciones'),
                ],
                dividerColor: Theme.of(context).dividerColor,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.onSurface,
                unselectedLabelColor: Theme.of(
                  context,
                ).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TabBarView(
                children: [
                  _InspirationCollection(kind: ContentKind.video),
                  _InspirationCollection(kind: ContentKind.recommendation),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspirationCollection extends ConsumerWidget {
  const _InspirationCollection({required this.kind});

  final ContentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(contentByKindProvider(kind));
    return RefreshIndicator.adaptive(
      onRefresh: () => ref.read(contentRepositoryProvider).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          items.when(
            loading: CatalogLoading.new,
            error: (error, stackTrace) => CatalogError(
              onRetry: () => ref.invalidate(contentByKindProvider(kind)),
            ),
            data: (content) => ContentCollection(items: content),
          ),
        ],
      ),
    );
  }
}
