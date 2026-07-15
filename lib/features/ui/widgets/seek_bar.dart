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
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar.mini({required this.duration, super.key}) : _overlay = false;

  const SeekBar.overlay({required this.duration, super.key}) : _overlay = true;

  final Duration duration;
  final bool _overlay;

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  /// Posición mientras se arrastra. El seek real se lanza solo al soltar:
  /// pedir un seek por cada tick del arrastre satura al reproductor con una
  /// fuente de red y el movimiento se atasca.
  double? _dragValue;
  bool _dragging = false;
  DateTime? _dragEndedAt;

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(audioHandlerProvider);
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        // Tras soltar, se mantiene el valor arrastrado hasta que el stream de
        // posición alcanza el seek; si no, el pulgar saltaba hacia atrás un
        // instante mientras el reproductor completaba el salto.
        if (!_dragging && _dragValue != null) {
          final delta = position.inMilliseconds - _dragValue!;
          final expired =
              _dragEndedAt != null &&
              DateTime.now().difference(_dragEndedAt!) >
                  const Duration(milliseconds: 1500);
          if (delta.abs() < 1000 || expired) {
            _dragValue = null;
            _dragEndedAt = null;
          }
        }
        final max = widget.duration.inMilliseconds
            .toDouble()
            .clamp(1, double.infinity)
            .toDouble();
        final value = (_dragValue ?? position.inMilliseconds.toDouble())
            .clamp(0, max)
            .toDouble();
        final shownPosition = Duration(milliseconds: value.round());

        final labelStyle = widget._overlay
            ? Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70)
            : Theme.of(context).textTheme.labelSmall;
        final labels = Padding(
          padding: widget._overlay
              ? const EdgeInsets.symmetric(horizontal: 4)
              : const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatPlaybackClock(shownPosition), style: labelStyle),
              Text(
                formatPlaybackRemaining(shownPosition, widget.duration),
                style: labelStyle,
              ),
            ],
          ),
        );
        final slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: widget._overlay ? Colors.white : scheme.primary,
            inactiveTrackColor: widget._overlay
                ? Colors.white.withValues(alpha: 0.3)
                : scheme.onSurface.withValues(alpha: 0.22),
            thumbColor: widget._overlay ? Colors.white : scheme.primary,
            overlayColor: widget._overlay
                ? Colors.white.withValues(alpha: 0.2)
                : null,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: widget._overlay ? 14 : 12,
            ),
          ),
          child: Slider(
            value: value,
            max: max,
            semanticFormatterCallback: (milliseconds) => formatPlaybackClock(
              Duration(milliseconds: milliseconds.round()),
            ),
            onChangeStart: (_) => _dragging = true,
            onChanged: (milliseconds) =>
                setState(() => _dragValue = milliseconds),
            onChangeEnd: (milliseconds) {
              handler.seek(Duration(milliseconds: milliseconds.round()));
              setState(() {
                _dragging = false;
                _dragEndedAt = DateTime.now();
              });
            },
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: widget._overlay ? [labels, slider] : [slider, labels],
        );
      },
    );
  }
}
