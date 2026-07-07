import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Hub de entrada: un sol central rodeado por las cuatro secciones.
/// Sustituye la llegada directa a "Meditar" por un espacio de bienvenida.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Section {
  const _Section({
    required this.label,
    required this.route,
    required this.angle,
  });

  final String label;
  final String route;
  final double angle; // radianes; -pi/2 = arriba
}

const _sections = <_Section>[
  _Section(label: 'Meditar', route: '/meditar', angle: -math.pi / 2),
  _Section(label: 'Prácticas', route: '/practicas', angle: 0),
  _Section(
    label: 'Canalizaciones',
    route: '/canalizaciones',
    angle: math.pi / 2,
  ),
  _Section(label: 'Inspiración', route: '/inspiracion', angle: math.pi),
];

/// Aforismos breves y atribuidos. Cortos a propósito: la esfera busca
/// presencia, no lectura.
const _aphorisms = <String>[
  'El viaje de mil millas comienza con un paso.\n— Lao Tse',
  'En lo que piensas, te conviertes.\n— atribuido a Buda',
  'Conócete a ti mismo.\n— Inscripción de Delfos',
  'La quietud también es respuesta.\n— Proverbio zen',
  'Respira. Ya estás aquí.',
];

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breath;
  late final AnimationController _orbit;
  Timer? _phraseTimer;
  Duration? _phraseInterval;
  int _phrase = 0;
  int? _highlighted;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aquí y no en build: reacciona a los cambios de reducir movimiento y,
    // al activarse, detiene las animaciones y re-ajusta la cadencia de las
    // frases (antes el intervalo quedaba fijado en la primera construcción).
    _syncMotion(MediaQuery.disableAnimationsOf(context));
  }

  void _syncMotion(bool reduceMotion) {
    if (reduceMotion) {
      _breath.stop();
      _orbit.stop();
      _breath.value = 0.5;
      _orbit.value = 0;
    } else {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
      if (!_orbit.isAnimating) _orbit.repeat();
    }
    final interval = Duration(seconds: reduceMotion ? 9 : 7);
    if (_phraseInterval != interval) {
      _phraseInterval = interval;
      _phraseTimer?.cancel();
      _phraseTimer = Timer.periodic(interval, (_) => _advancePhrase());
    }
  }

  void _advancePhrase() {
    if (!mounted) return;
    setState(() => _phrase = (_phrase + 1) % _aphorisms.length);
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _breath.dispose();
    _orbit.dispose();
    super.dispose();
  }

  void _onPan(Offset local, double square) {
    final center = square / 2;
    final dx = local.dx - center;
    final dy = local.dy - center;
    if (dx.abs() < center * 0.18 && dy.abs() < center * 0.18) return;
    final deg = math.atan2(dy, dx) * 180 / math.pi;
    int index;
    if (deg >= -45 && deg < 45) {
      index = 1; // derecha
    } else if (deg >= 45 && deg < 135) {
      index = 2; // abajo
    } else if (deg >= -135 && deg < -45) {
      index = 0; // arriba
    } else {
      index = 3; // izquierda
    }
    if (index != _highlighted) setState(() => _highlighted = index);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Introducción',
                    onPressed: () => _showIntro(context),
                    icon: Icon(Icons.star_border, color: scheme.primary),
                    iconSize: 26,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Perfil',
                    onPressed: () => context.push('/profile'),
                    icon: Icon(Icons.person_outline, color: scheme.onSurface),
                    iconSize: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Greeting(phrase: _aphorisms[_phrase], reduceMotion: reduceMotion),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final square = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final center = square / 2;
                    final r = square * 0.36;
                    return Center(
                      child: SizedBox(
                        width: square,
                        height: square,
                        child: GestureDetector(
                          onPanUpdate: (d) => _onPan(d.localPosition, square),
                          onPanEnd: (_) => setState(() => _highlighted = null),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: _OrbitRing(
                                  controller: _orbit,
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.16,
                                  ),
                                  accent: scheme.primary,
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: _Sun(
                                  breath: _breath,
                                  reduceMotion: reduceMotion,
                                  size: square * 0.34,
                                  onPlay: () => context.go('/meditar'),
                                ),
                              ),
                              for (var i = 0; i < _sections.length; i++)
                                Positioned(
                                  left:
                                      center + r * math.cos(_sections[i].angle),
                                  top:
                                      center + r * math.sin(_sections[i].angle),
                                  child: FractionalTranslation(
                                    translation: const Offset(-0.5, -0.5),
                                    child: _OrbitLabel(
                                      label: _sections[i].label,
                                      active: _highlighted == i,
                                      onTap: () =>
                                          context.go(_sections[i].route),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showIntro(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Introducción',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            for (final section in _sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  section.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Arrastra alrededor del sol o toca un nombre para entrar.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Comenzar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.phrase, required this.reduceMotion});

  final String phrase;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Text(
            'Te damos la bienvenida',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.6,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: Center(
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                child: Text(
                  phrase,
                  key: ValueKey(phrase),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sun extends StatelessWidget {
  const _Sun({
    required this.breath,
    required this.reduceMotion,
    required this.size,
    required this.onPlay,
  });

  final Animation<double> breath;
  final bool reduceMotion;
  final double size;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: breath,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(breath.value);
        final scale = reduceMotion ? 1.0 : 0.97 + t * 0.06;
        return Transform.scale(scale: scale, child: child);
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _SunPainter(
                core: scheme.primary,
                ray: scheme.primary.withValues(alpha: 0.55),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.primary,
                    Color.alphaBlend(
                      scheme.primary.withValues(alpha: 0.7),
                      scheme.surface,
                    ),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.45),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: SizedBox(
                width: size * 0.56,
                height: size * 0.56,
                child: IconButton(
                  tooltip: 'Comenzar',
                  onPressed: onPlay,
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: scheme.onPrimary,
                    size: size * 0.34,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SunPainter extends CustomPainter {
  _SunPainter({required this.core, required this.ray});

  final Color core;
  final Color ray;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final inner = size.width * 0.30;
    final outer = size.width * 0.48;
    final paint = Paint()
      ..color = ray
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * (2 * math.pi / 12);
      final p1 = center + Offset(math.cos(angle), math.sin(angle)) * inner;
      final p2 = center + Offset(math.cos(angle), math.sin(angle)) * outer;
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunPainter oldDelegate) =>
      oldDelegate.core != core || oldDelegate.ray != ray;
}

class _OrbitRing extends StatelessWidget {
  const _OrbitRing({
    required this.controller,
    required this.color,
    required this.accent,
  });

  final Animation<double> controller;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: CustomPaint(
            size: Size.infinite,
            painter: _RingPainter(color: color, accent: accent),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.36;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    canvas.drawCircle(center, radius, ring);

    final dot = Paint()..color = accent.withValues(alpha: 0.6);
    for (var i = 0; i < 12; i++) {
      final angle = i * (2 * math.pi / 12);
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(p, i.isEven ? 2.2 : 1.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.accent != accent;
}

class _OrbitLabel extends StatelessWidget {
  const _OrbitLabel({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? scheme.primary.withValues(alpha: 0.16)
                : scheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: active ? scheme.primary : scheme.onSurface,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
