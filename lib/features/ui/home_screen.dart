import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/screen_header.dart';

/// Pantalla intermedia de entrada: una esfera con las cuatro llaves de la app
/// (Canaliza, Medita, Duerme, Inspira) y una frase central que va rotando.
/// Al pulsar una llave se abre la sección elegida.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// Frases provisionales del centro de la esfera. Editar aquí para cambiarlas.
const _phrases = <String>[
  'Elige la llave que hoy te llama',
  'Cada llave abre un espacio distinto',
  'Un lugar al que volver cada día',
];

const _phraseInterval = Duration(seconds: 6);

class _Key {
  const _Key(this.label, this.asset, this.route, this.alignment);

  final String label;
  final String asset;
  final String route;
  final Alignment alignment;
}

const _keys = <_Key>[
  _Key(
    'Canaliza',
    'assets/icons/nav/canaliza.png',
    '/canalizaciones',
    Alignment(0, -0.86),
  ),
  _Key('Medita', 'assets/icons/nav/medita.png', '/meditar', Alignment(0.86, 0)),
  _Key(
    'Duerme',
    'assets/icons/nav/duerme.png',
    '/practicas',
    Alignment(0, 0.86),
  ),
  _Key(
    'Inspira',
    'assets/icons/nav/inspira.png',
    '/inspiracion',
    Alignment(-0.86, 0),
  ),
];

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _timer;
  int _phraseIndex = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_phraseInterval, (_) {
      if (!mounted) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const ScreenHeader(),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = math.min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return _Sphere(
                        side: side,
                        phrase: _phrases[_phraseIndex],
                        reduceMotion: reduceMotion,
                      );
                    },
                  ),
                ),
              ),
              // Vuelta al portal de bienvenida (reescuchar la locución).
              IconButton(
                tooltip: 'Bienvenida',
                onPressed: () => context.go('/bienvenida'),
                icon: const Icon(Icons.wb_twilight_outlined),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sphere extends StatelessWidget {
  const _Sphere({
    required this.side,
    required this.phrase,
    required this.reduceMotion,
  });

  final double side;
  final String phrase;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
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
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Stack(
          children: [
            // Frase central rotatoria.
            Center(
              child: Padding(
                // Margen amplio y simétrico: dentro de este hueco cabe la
                // frase sin invadir nunca la zona de las llaves (alineadas a
                // ±0.86 del radio), ni en horizontal ni en vertical.
                padding: EdgeInsets.all(side * 0.28),
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  // La frase se escala hacia abajo para caber siempre en el
                  // hueco central de la esfera sin desbordar ni solaparse
                  // con las llaves.
                  child: FittedBox(
                    key: ValueKey(phrase),
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: side * 0.44,
                      child: Text(
                        phrase,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurface, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (final key in _keys)
              Align(
                alignment: key.alignment,
                child: _KeyButton(item: key, side: side),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.item, required this.side});

  final _Key item;
  final double side;

  @override
  Widget build(BuildContext context) {
    final diameter = (side * 0.21).clamp(56.0, 88.0).toDouble();
    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        onTap: () => context.go(item.route),
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ),
              child: ClipOval(
                child: Image(image: AssetImage(item.asset), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 6),
            Text(item.label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
