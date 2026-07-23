import 'dart:math' as math;

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
          // Cada sección recoge sus audios con un formato propio: Canaliza en
          // línea de tiempo por mes, Medita en acordeón plegable por mes y
          // Duerme en una rueda circular que evoca la esfera de entrada.
          switch (featured.kind) {
            ContentKind.channeling => _MonthlyTimeline(
              items: rest,
              direction: direction,
            ),
            ContentKind.meditation => _MonthlyAccordion(
              items: rest,
              direction: direction,
            ),
            ContentKind.practice => _LunarWheel(
              items: rest,
              direction: direction,
            ),
            _ => Column(
              children: rest
                  .map((item) => _CatalogRow(item: item, direction: direction))
                  .toList(),
            ),
          },
        ],
      ],
    );
  }
}

/// Agrupa una lista de audios por mes de publicación conservando el orden de
/// entrada. Los audios sin fecha caen en un grupo final "Sin fecha".
List<MapEntry<String, List<ContentItem>>> _groupByMonth(
  List<ContentItem> items,
) {
  final groups = <String, List<ContentItem>>{};
  for (final item in items) {
    final label = formatMonthYear(item.publishedAt);
    groups.putIfAbsent(label, () => <ContentItem>[]).add(item);
  }
  return groups.entries.toList();
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: AppTokens.labelLetterSpacing,
        ),
      ),
    );
  }
}

/// Canaliza — línea de tiempo: cabecera de mes discreta seguida de sus filas.
class _MonthlyTimeline extends StatelessWidget {
  const _MonthlyTimeline({required this.items, required this.direction});

  final List<ContentItem> items;
  final DesignDirection direction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _groupByMonth(items)) ...[
          _MonthHeader(label: group.key),
          for (final item in group.value)
            _CatalogRow(item: item, direction: direction),
        ],
      ],
    );
  }
}

/// Medita — acordeón: cada mes es un bloque plegable; el primero abierto.
class _MonthlyAccordion extends StatelessWidget {
  const _MonthlyAccordion({required this.items, required this.direction});

  final List<ContentItem> items;
  final DesignDirection direction;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByMonth(items);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < groups.length; i++)
            ExpansionTile(
              key: PageStorageKey('medita-${groups[i].key}'),
              initiallyExpanded: i == 0,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              title: Text(
                groups[i].key,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              children: [
                for (final item in groups[i].value)
                  _CatalogRow(item: item, direction: direction),
              ],
            ),
        ],
      ),
    );
  }
}

/// Duerme — rueda: los audios se reparten alrededor de un círculo que evoca la
/// esfera de entrada. Al tocar un punto, su ficha aparece en el centro.
class _LunarWheel extends StatefulWidget {
  const _LunarWheel({required this.items, required this.direction});

  final List<ContentItem> items;
  final DesignDirection direction;

  @override
  State<_LunarWheel> createState() => _LunarWheelState();
}

class _LunarWheelState extends State<_LunarWheel> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.items;
    final selected = items[_selected.clamp(0, items.length - 1)];
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth.clamp(0.0, 420.0);
        final radius = side / 2;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.14),
                    scheme.surface.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(side * 0.24),
                      child: _WheelCenter(item: selected),
                    ),
                  ),
                  for (var i = 0; i < items.length; i++)
                    Align(
                      alignment: _dotAlignment(i, items.length),
                      child: _WheelDot(
                        item: items[i],
                        selected: i == _selected,
                        onTap: () => setState(() => _selected = i),
                        maxDiameter: (radius * 0.24).clamp(28.0, 56.0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Reparte el punto i sobre la circunferencia empezando arriba (12 en punto)
  // y avanzando en el sentido de las agujas del reloj.
  Alignment _dotAlignment(int i, int count) {
    final angle = -math.pi / 2 + (2 * math.pi * i / count);
    return Alignment(0.82 * math.cos(angle), 0.82 * math.sin(angle));
  }
}

class _WheelCenter extends StatelessWidget {
  const _WheelCenter({required this.item});

  final ContentItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reproducir ${item.title}',
      child: InkWell(
        onTap: () => context.push('/content/${item.id}'),
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              joinMeta([item.durationLabel, formatMonthYear(item.publishedAt)]),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _PlayGlyph(item: item, circular: true),
          ],
        ),
      ),
    );
  }
}

class _WheelDot extends StatelessWidget {
  const _WheelDot({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.maxDiameter,
  });

  final ContentItem item;
  final bool selected;
  final VoidCallback onTap;
  final double maxDiameter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diameter = selected ? maxDiameter : maxDiameter * 0.86;
    return Semantics(
      button: true,
      selected: selected,
      label: item.title,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.5),
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ContentCover(path: item.thumbOrCover),
        ),
      ),
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

class _CatalogRow extends ConsumerWidget {
  const _CatalogRow({required this.item, required this.direction});

  final ContentItem item;
  final DesignDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listened = ref.watch(isListenedProvider(item.id)).value ?? false;
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
              if (listened) ...[
                Semantics(
                  label: 'Escuchado',
                  child: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
