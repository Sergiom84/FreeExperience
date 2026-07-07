import 'package:flutter_test/flutter_test.dart';
import 'package:free_experience/core/util/formatters.dart';

void main() {
  group('formatPlaybackClock', () {
    test('muestra minutos y segundos con dos dígitos', () {
      expect(
        formatPlaybackClock(const Duration(minutes: 5, seconds: 7)),
        '05:07',
      );
    });

    test('conserva las horas en sesiones largas', () {
      // Antes una sesión de 72 minutos se mostraba como "12:00".
      expect(formatPlaybackClock(const Duration(minutes: 72)), '1:12:00');
    });

    test('no muestra valores negativos', () {
      expect(formatPlaybackClock(const Duration(seconds: -3)), '00:00');
    });
  });

  group('formatPlaybackRemaining', () {
    test('resta la posición a la duración', () {
      expect(
        formatPlaybackRemaining(
          const Duration(minutes: 1),
          const Duration(minutes: 4, seconds: 30),
        ),
        '-03:30',
      );
    });

    test('sin duración conocida muestra marcador', () {
      expect(
        formatPlaybackRemaining(const Duration(minutes: 1), Duration.zero),
        '--:--',
      );
    });

    test('no queda en negativo si la posición supera la duración', () {
      expect(
        formatPlaybackRemaining(
          const Duration(minutes: 5),
          const Duration(minutes: 4),
        ),
        '-00:00',
      );
    });
  });
}
