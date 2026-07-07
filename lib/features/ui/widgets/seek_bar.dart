import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/util/formatters.dart';

/// Barra de progreso con etiquetas de posición y tiempo restante, compartida
/// por el mini reproductor y el reproductor completo (antes eran dos widgets
/// casi idénticos, ~120 líneas duplicadas).
///
/// - [SeekBar.mini]: colores del tema, etiquetas bajo el slider.
/// - [SeekBar.overlay]: blanco sobre la portada, etiquetas sobre el slider.
class SeekBar extends ConsumerWidget {
  const SeekBar.mini({required this.duration, super.key}) : _overlay = false;

  const SeekBar.overlay({required this.duration, super.key}) : _overlay = true;

  final Duration duration;
  final bool _overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final max = duration.inMilliseconds
            .toDouble()
            .clamp(1, double.infinity)
            .toDouble();
        final value = position.inMilliseconds
            .toDouble()
            .clamp(0, max)
            .toDouble();

        final labelStyle = _overlay
            ? Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70)
            : Theme.of(context).textTheme.labelSmall;
        final labels = Padding(
          padding: _overlay
              ? const EdgeInsets.symmetric(horizontal: 4)
              : const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatPlaybackClock(position), style: labelStyle),
              Text(
                formatPlaybackRemaining(position, duration),
                style: labelStyle,
              ),
            ],
          ),
        );
        final slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: _overlay ? Colors.white : scheme.primary,
            inactiveTrackColor: _overlay
                ? Colors.white.withValues(alpha: 0.3)
                : scheme.onSurface.withValues(alpha: 0.22),
            thumbColor: _overlay ? Colors.white : scheme.primary,
            overlayColor: _overlay ? Colors.white.withValues(alpha: 0.2) : null,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: _overlay ? 14 : 12,
            ),
          ),
          child: Slider(
            value: value,
            max: max,
            semanticFormatterCallback: (milliseconds) => formatPlaybackClock(
              Duration(milliseconds: milliseconds.round()),
            ),
            onChanged: (milliseconds) =>
                handler.seek(Duration(milliseconds: milliseconds.round())),
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: _overlay ? [labels, slider] : [slider, labels],
        );
      },
    );
  }
}
