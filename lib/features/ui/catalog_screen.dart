import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design_direction.dart';
import '../../core/design/design_tokens.dart';
import '../../core/providers.dart';
import '../../core/util/formatters.dart';
import '../content/domain/content_item.dart';
import 'widgets/content_cover.dart';
import 'widgets/screen_header.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({required this.kind, super.key});

  final ContentKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(contentByKindProvider(kind));
    return SafeArea(
      bottom: false,
      child: RefreshIndicator.adaptive(
        onRefresh: () => ref.read(contentRepositoryProvider).refresh(),
        child: CustomScrollView(
          key: PageStorageKey(kind.name),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList.list(
                children: [
                  ScreenHeader(
                    title: kind.sectionTitle,
                    subtitle: kind.tagline,
                  ),
                  items.when(
                    loading: () => const CatalogLoading(),
                    error: (error, stackTrace) => CatalogError(
                      onRetry: () =>
                          ref.invalidate(contentByKindProvider(kind)),
                    ),
                    data: (content) => ContentCollection(items: content),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Geometría compartida entre las tarjetas reales y sus esqueletos de carga,
// para que un ajuste de layout no requiera dos ediciones.
// Portada destacada en 4:5 (mismo encuadre que la portada subida y el detalle),
// para que el retrato no se recorte en la card principal.
const _umbralFeatureRatio = 4 / 5;
const _materiaFeatureHeight = 330.0;
const _mineralFeatureRatio = 1.42;
const _rowMinHeight = 82.0;

class ContentCollection extends ConsumerWidget {
  const ContentCollection({required this.items, super.key});

  final List<ContentItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sin contenido'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.read(contentRepositoryProvider).refresh(),
                child: const Text('Actualizar'),
              ),
            ],
          ),
        ),
      );
    }
    final featured = items.first;
    final rest = items.skip(1).toList();
    final direction = ref.watch(designDirectionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (direction) {
          DesignDirection.umbral => _UmbralFeature(item: featured),
          DesignDirection.materia => _MateriaFeature(item: featured),
          DesignDirection.mineral => _MineralFeature(item: featured),
        },
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 24),
          ...rest.map((item) => _CatalogRow(item: item, direction: direction)),
        ],
      ],
    );
  }
}

class _UmbralFeature extends StatelessWidget {
  const _UmbralFeature({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.title,
      child: InkWell(
        onTap: () => context.push('/content/${item.id}'),
        child: AspectRatio(
          aspectRatio: _umbralFeatureRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ContentCover(path: item.coverPath),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTokens.coverOverlay(DesignDirection.umbral),
                ),
              ),
              Positioned(
                left: 20,
                right: 70,
                bottom: 20,
                child: _FeatureCopy(item: item),
              ),
              Positioned(right: 16, bottom: 16, child: _PlayGlyph(item: item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MateriaFeature extends StatelessWidget {
  const _MateriaFeature({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _materiaFeatureHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 7,
            child: Semantics(
              button: true,
              label: item.title,
              child: InkWell(
                onTap: () => context.push('/content/${item.id}'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ContentCover(
                      path: item.coverPath,
                      borderRadius: AppTokens.materiaArc,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppTokens.coverOverlay(
                          DesignDirection.materia,
                        ),
                        borderRadius: AppTokens.materiaArc,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.kind.label.toUpperCase(),
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: AppTokens.labelLetterSpacing,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Metadata(item: item),
                  const SizedBox(height: 20),
                  _PlayGlyph(item: item, circular: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MineralFeature extends StatelessWidget {
  const _MineralFeature({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.title,
      child: InkWell(
        onTap: () => context.push('/content/${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: _mineralFeatureRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x18000000),
                      BlendMode.saturation,
                    ),
                    child: ContentCover(path: item.coverPath),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppTokens.coverOverlay(DesignDirection.mineral),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _FeatureCopy(item: item)),
                  const SizedBox(width: 16),
                  _PlayGlyph(item: item),
                ],
              ),
            ),
            Divider(color: Theme.of(context).dividerColor, height: 1),
          ],
        ),
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.item, required this.direction});

  final ContentItem item;
  final DesignDirection direction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: [item.title, if (item.author != null) item.author!].join(', '),
      child: InkWell(
        onTap: () => context.push('/content/${item.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ContentCover(
                  // Miniatura cuadrada: usa el recorte 1:1 si existe, si no la
                  // portada 4:5 recortada al centro.
                  path: item.thumbOrCover,
                  borderRadius: BorderRadius.circular(
                    direction == DesignDirection.materia ? 4 : 2,
                  ),
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
                    if (item.author != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.author!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (formatLongDate(item.publishedAt).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        formatLongDate(item.publishedAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
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

class _FeatureCopy extends StatelessWidget {
  const _FeatureCopy({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(item.title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        _Metadata(item: item),
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    final values = joinMeta([
      item.author,
      item.durationLabel,
      formatLongDate(item.publishedAt),
    ]);
    return Text(values, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _PlayGlyph extends StatelessWidget {
  const _PlayGlyph({required this.item, this.circular = false});

  final ContentItem item;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final label = item.kind == ContentKind.recommendation
        ? 'Abrir ${item.title}'
        : 'Reproducir ${item.title}';
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 48,
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: circular ? const CircleBorder() : null,
          ),
          onPressed: () => context.push('/content/${item.id}'),
          child: Icon(
            item.kind == ContentKind.recommendation
                ? Icons.arrow_outward
                : Icons.play_arrow,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class CatalogLoading extends ConsumerWidget {
  const CatalogLoading({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(designDirectionProvider);
    final color = Theme.of(context).colorScheme.surface;
    final feature = switch (direction) {
      DesignDirection.umbral => AspectRatio(
        aspectRatio: _umbralFeatureRatio,
        child: ColoredBox(color: color),
      ),
      DesignDirection.materia => SizedBox(
        height: _materiaFeatureHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppTokens.materiaArc,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(flex: 3, child: SizedBox()),
          ],
        ),
      ),
      DesignDirection.mineral => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: _mineralFeatureRatio,
            child: ColoredBox(color: color),
          ),
          const SizedBox(height: 15),
          Divider(color: Theme.of(context).dividerColor, height: 1),
        ],
      ),
    };
    return Column(
      children: [
        feature,
        const SizedBox(height: 24),
        ...List.generate(
          2,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: _rowMinHeight,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class CatalogError extends StatelessWidget {
  const CatalogError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
