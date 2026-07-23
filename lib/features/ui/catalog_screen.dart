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
          // Formato "Audio Calendar" (handoff de Claude Design): selector de
          // mes + días plegables con contador de sin-escuchar. Único formato
          // para las tres secciones de audio (Canaliza, Medita, Duerme).
          _AudioCalendar(items: rest, direction: direction),
        ],
      ],
    );
  }
}

const _dayRowIndent = 58.0;

class _MonthGroup {
  const _MonthGroup({
    required this.key,
    required this.label,
    required this.items,
  });

  final String key;
  final String label;
  final List<ContentItem> items;
}

class _DayGroup {
  const _DayGroup({
    required this.dateKey,
    required this.date,
    required this.items,
  });

  final String dateKey;
  final DateTime date;
  final List<ContentItem> items;
}

const _weekdayAbbr = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];

/// Agrupa por mes (clave "YYYY-MM") conservando el orden de entrada. Los
/// audios sin fecha caen en un grupo final "sin-fecha".
List<_MonthGroup> _groupByMonth(List<ContentItem> items) {
  final order = <String>[];
  final byMonth = <String, List<ContentItem>>{};
  for (final item in items) {
    final date = item.publishedAt;
    final key = date == null
        ? 'sin-fecha'
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
    if (!byMonth.containsKey(key)) {
      order.add(key);
      byMonth[key] = <ContentItem>[];
    }
    byMonth[key]!.add(item);
  }
  return order
      .map(
        (key) => _MonthGroup(
          key: key,
          label: formatMonthYear(byMonth[key]!.first.publishedAt),
          items: byMonth[key]!,
        ),
      )
      .toList();
}

/// Agrupa un mes por día calendario, conservando el orden de entrada.
List<_DayGroup> _groupByDay(List<ContentItem> items) {
  final order = <String>[];
  final byDay = <String, List<ContentItem>>{};
  for (final item in items) {
    final date = item.publishedAt;
    final key = date == null
        ? 'sin-fecha'
        : '${date.year}-${date.month}-${date.day}';
    if (!byDay.containsKey(key)) {
      order.add(key);
      byDay[key] = <ContentItem>[];
    }
    byDay[key]!.add(item);
  }
  return order
      .map(
        (key) => _DayGroup(
          dateKey: key,
          date: byDay[key]!.first.publishedAt ?? DateTime(1970),
          items: byDay[key]!,
        ),
      )
      .toList();
}

class _AudioCalendar extends ConsumerStatefulWidget {
  const _AudioCalendar({required this.items, required this.direction});

  final List<ContentItem> items;
  final DesignDirection direction;

  @override
  ConsumerState<_AudioCalendar> createState() => _AudioCalendarState();
}

class _AudioCalendarState extends ConsumerState<_AudioCalendar> {
  int _monthIndex = 0;
  final Map<String, bool> _dayExpandOverride = {};

  @override
  Widget build(BuildContext context) {
    final listenedById = <String, bool>{
      for (final item in widget.items)
        item.id: ref.watch(isListenedProvider(item.id)).value ?? false,
    };
    final months = _groupByMonth(widget.items);
    final monthIndex = _monthIndex.clamp(0, months.length - 1);
    final month = months[monthIndex];
    final days = _groupByDay(month.items);
    final monthUnread = month.items
        .where((item) => !(listenedById[item.id] ?? false))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthJumper(
          months: months,
          listenedById: listenedById,
          selectedIndex: monthIndex,
          onSelect: (i) => setState(() => _monthIndex = i),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    month.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: AppTokens.labelLetterSpacing,
                    ),
                  ),
                  Text(
                    '${month.items.length} ${month.items.length == 1 ? 'audio' : 'audios'} · '
                    '${monthUnread == 0 ? 'todo escuchado' : '$monthUnread sin escuchar'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        for (final day in days)
          _CalendarDay(
            day: day,
            direction: widget.direction,
            listenedById: listenedById,
            expandedOverride: _dayExpandOverride[day.dateKey],
            onToggle: () => setState(() {
              final current =
                  _dayExpandOverride[day.dateKey] ??
                  day.items.any((item) => !(listenedById[item.id] ?? false));
              _dayExpandOverride[day.dateKey] = !current;
            }),
          ),
      ],
    );
  }
}

class _MonthJumper extends StatelessWidget {
  const _MonthJumper({
    required this.months,
    required this.listenedById,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_MonthGroup> months;
  final Map<String, bool> listenedById;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: months.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final group = months[i];
          final unread = group.items
              .where((item) => !(listenedById[item.id] ?? false))
              .length;
          final active = i == selectedIndex;
          return Semantics(
            button: true,
            selected: active,
            label: group.label,
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(AppTokens.pillRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.pillRadius),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      group.label,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (unread > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(
                            AppTokens.pillRadius,
                          ),
                        ),
                        child: Text(
                          '$unread',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                        ),
                      ),
                    ],
                    if (active) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.direction,
    required this.listenedById,
    required this.expandedOverride,
    required this.onToggle,
  });

  final _DayGroup day;
  final DesignDirection direction;
  final Map<String, bool> listenedById;
  final bool? expandedOverride;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final unread = day.items
        .where((item) => !(listenedById[item.id] ?? false))
        .length;
    final hasUnread = unread > 0;
    // Los días ya escuchados arrancan plegados; los que tienen algo
    // pendiente arrancan abiertos, salvo que el usuario los haya tocado.
    final expanded = expandedOverride ?? hasUnread;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: '${day.date.day} ${_weekdayAbbr[day.date.weekday % 7]}',
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Column(
                          children: [
                            Text(
                              day.date.day.toString().padLeft(2, '0'),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 30,
                                    height: 1,
                                    color: hasUnread ? null : scheme.outline,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _weekdayAbbr[day.date.weekday % 7],
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontSize: 9, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              day.items.length == 1
                                  ? '1 audio'
                                  : '${day.items.length} audios',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              unread == 0
                                  ? 'Todo escuchado'
                                  : unread == day.items.length
                                  ? 'Sin escuchar'
                                  : '$unread sin escuchar',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 12),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(
                              AppTokens.pillRadius,
                            ),
                          ),
                          child: Text(
                            '$unread',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.only(left: _dayRowIndent, bottom: 6),
              child: Column(
                children: [
                  for (final item in day.items)
                    _CalendarRow(
                      item: item,
                      listened: listenedById[item.id] ?? false,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila de audio dentro de un día: sin fecha, porque ya la marca la
/// cabecera del día.
class _CalendarRow extends StatelessWidget {
  const _CalendarRow({required this.item, required this.listened});

  final ContentItem item;
  final bool listened;

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
                  path: item.thumbOrCover,
                  borderRadius: BorderRadius.circular(2),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: listened
                            ? Theme.of(context).textTheme.bodySmall?.color
                            : null,
                      ),
                    ),
                    if (item.author != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.author!,
                        style: Theme.of(context).textTheme.bodySmall,
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
