import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers.dart';
import '../content/domain/content_item.dart';

/// Clave de preferencia: el usuario ya escuchó la introducción de bienvenida.
const introSeenPrefKey = 'intro_seen';

/// Variante de bienvenida: atardecer de playa animado (cielo, sol, olas,
/// estrellas, cometas) con el sol como botón de entrada y las cuatro
/// secciones orbitando a su alrededor.
class WelcomeSunsetScreen extends ConsumerStatefulWidget {
  const WelcomeSunsetScreen({super.key});

  @override
  ConsumerState<WelcomeSunsetScreen> createState() =>
      _WelcomeSunsetScreenState();
}

class _Section {
  const _Section({required this.label, required this.route});
  final String label;
  final String route;
}

const _sections = <_Section>[
  _Section(label: 'Meditar', route: '/meditar'),
  _Section(label: 'Prácticas', route: '/practicas'),
  _Section(label: 'Canalizaciones', route: '/canalizaciones'),
  _Section(label: 'Inspiración', route: '/inspiracion'),
];

// Centro del sol como fracción de la pantalla.
const double _sunFracX = 0.5;
const double _sunFracY = 0.46;

class _WelcomeSunsetScreenState extends ConsumerState<WelcomeSunsetScreen>
    with TickerProviderStateMixin {
  late final AnimationController _waves;
  late final AnimationController _breath;
  late final AnimationController _clouds;
  late final AnimationController _sunCycle;
  late final AnimationController _oceanTime;
  ui.FragmentShader? _ocean;
  Timer? _cometTimer;
  final _rnd = math.Random();
  final List<_CometData> _comets = [];
  int _cometId = 0;

  @override
  void initState() {
    super.initState();
    _waves = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    _clouds = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 70),
    );
    _sunCycle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
    _oceanTime = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
      upperBound: 120,
    );
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/ocean.frag');
      if (!mounted) return;
      setState(() => _ocean = program.fragmentShader());
    } on Object {
      // Sin shader se conserva el fondo pintado (_SunsetPainter) como respaldo.
    }
  }

  void _startMotion(bool reduceMotion) {
    if (reduceMotion) {
      _waves.value = 0;
      _breath.value = 0.5;
      _clouds.value = 0;
      _sunCycle.value = 0;
      _oceanTime.value = 6;
      return;
    }
    if (!_waves.isAnimating) _waves.repeat();
    if (!_breath.isAnimating) _breath.repeat(reverse: true);
    if (!_clouds.isAnimating) _clouds.repeat();
    if (!_sunCycle.isAnimating) _sunCycle.repeat(reverse: true);
    if (!_oceanTime.isAnimating) _oceanTime.repeat();
    _cometTimer ??= Timer(
      Duration(milliseconds: 1500 + _rnd.nextInt(2000)),
      _spawnComet,
    );
  }

  void _spawnComet() {
    if (!mounted) return;
    final id = _cometId++;
    // Parte de un borde superior y cruza hacia abajo, pasando cerca del sol.
    final startX = 0.15 + _rnd.nextDouble() * 0.7;
    final startY = -0.05 + _rnd.nextDouble() * 0.2;
    final dx = -(0.25 + _rnd.nextDouble() * 0.35);
    final dy = 0.3 + _rnd.nextDouble() * 0.3;
    setState(() {
      _comets.add(
        _CometData(
          id: id,
          start: Offset(startX, startY),
          delta: Offset(dx, dy),
          duration: Duration(milliseconds: 900 + _rnd.nextInt(500)),
        ),
      );
    });
    _cometTimer = Timer(
      Duration(milliseconds: 2200 + _rnd.nextInt(4000)),
      _spawnComet,
    );
  }

  void _removeComet(int id) {
    if (!mounted) return;
    setState(() => _comets.removeWhere((c) => c.id == id));
  }

  Future<void> _playIntro() async {
    // Reproduce el último audio publicado en Extras > Introducción (si existe),
    // marca la intro como vista (local + perfil) y entra a Meditaciones. El
    // audio continúa en el mini reproductor.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(introSeenPrefKey, true);
    unawaited(ref.read(profileRepositoryProvider).setIntroSeen());

    ContentItem? intro;
    try {
      // Asegura que el catálogo local tiene la intro recién publicada y espera
      // el primer valor del stream (ref.read(.value) puede ser null sin watch).
      await ref.read(contentRepositoryProvider).refresh();
      final intros = await ref.read(
        contentByKindProvider(ContentKind.intro).future,
      );
      for (final item in intros) {
        if (item.hasPlayableMedia) {
          intro = item;
          break;
        }
      }
    } on Object {
      // Sin red o sin intro publicada: entra directo a Meditaciones.
    }

    if (intro != null) {
      await ref.read(playbackCoordinatorProvider).play(intro);
    }
    if (mounted) context.go('/meditar');
  }

  @override
  void dispose() {
    _cometTimer?.cancel();
    _waves.dispose();
    _breath.dispose();
    _clouds.dispose();
    _sunCycle.dispose();
    _oceanTime.dispose();
    _ocean?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _startMotion(reduceMotion);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1E),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final sunSize = math.min(w * 0.30, 132.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Fondo: océano raymarched (shader). Respaldo pintado mientras
              // el shader carga o si falla.
              RepaintBoundary(
                child: _ocean != null
                    ? AnimatedBuilder(
                        animation: _oceanTime,
                        builder: (context, _) => CustomPaint(
                          size: Size.infinite,
                          painter: _OceanPainter(
                            shader: _ocean!,
                            time: _oceanTime.value,
                          ),
                        ),
                      )
                    : AnimatedBuilder(
                        animation: Listenable.merge([_waves, _clouds]),
                        builder: (context, _) => CustomPaint(
                          size: Size.infinite,
                          painter: _SunsetPainter(
                            wavePhase: _waves.value,
                            cloudPhase: _clouds.value,
                            sunCenter: Offset(w * _sunFracX, h * _sunFracY),
                          ),
                        ),
                      ),
              ),
              // Sol-reproductor (capa sobre el océano)
              AnimatedBuilder(
                animation: Listenable.merge([_sunCycle, _breath]),
                builder: (context, _) {
                  // El sol desciende lentamente hacia el horizonte y vuelve.
                  final sunY = reduceMotion
                      ? _sunFracY
                      : 0.40 + _sunCycle.value * 0.14;
                  final sunCenter = Offset(w * _sunFracX, h * sunY);
                  final breathT = Curves.easeInOut.transform(_breath.value);
                  final scale = reduceMotion ? 1.0 : 0.97 + breathT * 0.06;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned(
                        left: sunCenter.dx - sunSize / 2,
                        top: sunCenter.dy - sunSize / 2,
                        width: sunSize,
                        height: sunSize,
                        child: Transform.scale(
                          scale: scale,
                          child: _Sun(size: sunSize, onPlay: _playIntro),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Cometas
              for (final comet in _comets)
                _Comet(
                  key: ValueKey(comet.id),
                  data: comet,
                  bounds: Size(w, h),
                  onDone: () => _removeComet(comet.id),
                ),
              // Cabecera
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Secciones',
                            onPressed: () => _showSections(context),
                            icon: const Icon(
                              Icons.star_border,
                              color: Colors.white,
                            ),
                            iconSize: 26,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Perfil',
                            onPressed: () => context.push('/profile'),
                            icon: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                            ),
                            iconSize: 24,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _Greeting(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSections(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final section in _sections)
                  ListTile(
                    title: Text(
                      section.label,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.go(section.route);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Text(
        'Te damos la bienvenida',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          shadows: [Shadow(blurRadius: 16, color: Color(0x99000000))],
        ),
      ),
    );
  }
}

// ─── Sun ─────────────────────────────────────────────────────────────────────

class _Sun extends StatelessWidget {
  const _Sun({required this.size, required this.onPlay});

  final double size;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFFFF7D6),
            Color(0xFFFFD24A),
            Color(0xFFFF8A2B),
            Color(0xFFE9531A),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8A2B).withValues(alpha: 0.55),
            blurRadius: 70,
            spreadRadius: 18,
          ),
          BoxShadow(
            color: const Color(0xFFFFD24A).withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: IconButton(
        tooltip: 'Comenzar',
        onPressed: onPlay,
        icon: Icon(
          Icons.play_arrow_rounded,
          color: const Color(0xFF5A2400),
          size: size * 0.4,
        ),
      ),
    );
  }
}

// ─── Comet ─────────────────────────────────────────────────────────────────────

class _CometData {
  _CometData({
    required this.id,
    required this.start,
    required this.delta,
    required this.duration,
  });
  final int id;
  final Offset start; // fracción
  final Offset delta; // fracción
  final Duration duration;
}

class _Comet extends StatefulWidget {
  const _Comet({
    required this.data,
    required this.bounds,
    required this.onDone,
    super.key,
  });

  final _CometData data;
  final Size bounds;
  final VoidCallback onDone;

  @override
  State<_Comet> createState() => _CometState();
}

class _CometState extends State<_Comet> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.data.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.bounds.width;
    final h = widget.bounds.height;
    final angle = math.atan2(
      widget.data.delta.dy * h,
      widget.data.delta.dx * w,
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final x = (widget.data.start.dx + widget.data.delta.dx * v) * w;
        final y = (widget.data.start.dy + widget.data.delta.dy * v) * h;
        final opacity = v < 0.15
            ? v / 0.15
            : v > 0.7
            ? (1 - v) / 0.3
            : 1.0;
        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: angle,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00FFFFFF), Color(0xCCFFE9B0)],
                      ),
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFE9B0).withValues(alpha: 0.9),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
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
}

// ─── Ocean shader painter ───────────────────────────────────────────────────

class _OceanPainter extends CustomPainter {
  _OceanPainter({required this.shader, required this.time});

  final ui.FragmentShader shader;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _OceanPainter oldDelegate) =>
      oldDelegate.time != time;
}

// ─── Sunset painter (cielo, estrellas, océano, olas, reflejo) ────────────────

class _SunsetPainter extends CustomPainter {
  _SunsetPainter({
    required this.wavePhase,
    required this.cloudPhase,
    required this.sunCenter,
  });

  final double wavePhase;
  final double cloudPhase;
  final Offset sunCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.62;

    // Cielo
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1B1033),
          Color(0xFF49214A),
          Color(0xFFB14A2E),
          Color(0xFFF0A24B),
        ],
        stops: [0.0, 0.34, 0.78, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon), sky);

    final rnd = math.Random(7);
    final starPaint = Paint()..color = Colors.white;

    // Estrellas dispersas por el cielo
    for (var i = 0; i < 80; i++) {
      final x = rnd.nextDouble() * w;
      final y = rnd.nextDouble() * horizon * 0.7;
      final base = rnd.nextDouble();
      final twinkle =
          0.3 +
          0.7 * (0.5 + 0.5 * math.sin(wavePhase * 2 * math.pi + base * 9));
      final fade = (1 - y / (horizon * 0.7)).clamp(0.0, 1.0);
      starPaint.color = Colors.white.withValues(alpha: twinkle * 0.55 * fade);
      canvas.drawCircle(Offset(x, y), base * 1.1 + 0.3, starPaint);
    }

    // Cúmulo de estrellas alrededor del sol
    final rnd2 = math.Random(21);
    for (var i = 0; i < 46; i++) {
      final ang = rnd2.nextDouble() * 2 * math.pi;
      final dist = (0.16 + rnd2.nextDouble() * 0.5) * w;
      final p = sunCenter + Offset(math.cos(ang), math.sin(ang)) * dist;
      if (p.dy < 0 || p.dy > horizon) continue;
      final base = rnd2.nextDouble();
      final twinkle =
          0.4 +
          0.6 * (0.5 + 0.5 * math.sin(wavePhase * 2 * math.pi + base * 11));
      starPaint.color = const Color(
        0xFFFFF3D6,
      ).withValues(alpha: twinkle * 0.75);
      canvas.drawCircle(p, base * 1.3 + 0.4, starPaint);
    }

    // Halo cálido alrededor del sol
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD27A).withValues(alpha: 0.4),
          const Color(0x00FFD27A),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: w * 0.6));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, horizon), glow);

    // Nubes a la deriva
    _drawClouds(canvas, w, horizon);

    // Océano
    final ocean = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF7A3A2E),
          Color(0xFF2C1E40),
          Color(0xFF101028),
          Color(0xFF080814),
        ],
        stops: [0.0, 0.3, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon));
    canvas.drawRect(Rect.fromLTWH(0, horizon, w, h - horizon), ocean);

    // Reflejo del sol en el agua
    final refl = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFC84A).withValues(alpha: 0.5),
              const Color(0xFFFF8A2B).withValues(alpha: 0.2),
              const Color(0x00FF8A2B),
            ],
          ).createShader(
            Rect.fromLTWH(sunCenter.dx - 50, horizon, 100, h - horizon),
          );
    canvas.drawRect(
      Rect.fromLTWH(sunCenter.dx - 50, horizon, 100, h - horizon),
      refl,
    );

    _drawWaves(canvas, w, h, horizon);
  }

  void _drawClouds(Canvas canvas, double w, double horizon) {
    // Cada nube: (y fracción del cielo, escala, opacidad, velocidad relativa).
    const defs = [
      (y: 0.16, scale: 1.0, a: 0.16, spd: 1.0, offset: 0.0),
      (y: 0.30, scale: 0.7, a: 0.12, spd: 0.7, offset: 0.45),
      (y: 0.10, scale: 0.85, a: 0.10, spd: 1.3, offset: 0.78),
    ];
    final blur = Paint()
      ..color = const Color(0xFFF3C79A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    for (final d in defs) {
      // Desplazamiento continuo de derecha a izquierda, con envoltura.
      final travel = ((cloudPhase * d.spd + d.offset) % 1.0);
      final cx = (1.2 - travel * 1.4) * w;
      final cy = horizon * d.y;
      blur.color = const Color(0xFFF3C79A).withValues(alpha: d.a);
      final s = d.scale;
      // Grupo de óvalos solapados que forman la nube.
      final blobs = [
        (dx: 0.0, dy: 0.0, rw: 60.0, rh: 24.0),
        (dx: -34.0, dy: 8.0, rw: 42.0, rh: 18.0),
        (dx: 34.0, dy: 6.0, rw: 46.0, rh: 20.0),
        (dx: 64.0, dy: 10.0, rw: 32.0, rh: 15.0),
        (dx: -62.0, dy: 11.0, rw: 30.0, rh: 14.0),
      ];
      for (final b in blobs) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx + b.dx * s, cy + b.dy * s),
            width: b.rw * 2 * s,
            height: b.rh * 2 * s,
          ),
          blur,
        );
      }
    }
  }

  void _drawWaves(Canvas canvas, double w, double h, double horizon) {
    final oceanH = h - horizon;
    final phase = wavePhase * 2 * math.pi;
    // Capas de oleaje: cada una suma varias senoides para un movimiento
    // orgánico (no un seno mecánico). Relleno con gradiente cálido→profundo.
    final layers = [
      (y: 0.14, a: 0.10, spd: 0.9, tint: const Color(0xFFFFD7A0)),
      (y: 0.30, a: 0.10, spd: -0.6, tint: const Color(0xFFE0A0B0)),
      (y: 0.48, a: 0.12, spd: 0.45, tint: const Color(0xFF9DA3D6)),
      (y: 0.66, a: 0.14, spd: -0.35, tint: const Color(0xFF6E78B8)),
      (y: 0.84, a: 0.16, spd: 0.25, tint: const Color(0xFF3A4488)),
    ];
    for (final l in layers) {
      final baseY = horizon + oceanH * l.y;
      final shift = phase * l.spd;
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            l.tint.withValues(alpha: l.a + 0.05),
            l.tint.withValues(alpha: l.a * 0.4),
          ],
        ).createShader(Rect.fromLTWH(0, baseY - 16, w, oceanH));
      final path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= w; x += 4) {
        final t = x / w;
        // Suma de tres componentes de distinta longitud y velocidad.
        final y =
            baseY +
            math.sin(t * 7 + shift) * 5 +
            math.sin(t * 13 - shift * 1.4) * 3 +
            math.sin(t * 23 + shift * 0.6) * 1.6;
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, fill);

      // Cresta tenue sobre cada capa para dar relieve.
      final crest = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: l.a * 0.6);
      final crestPath = Path()..moveTo(0, baseY);
      for (double x = 0; x <= w; x += 4) {
        final t = x / w;
        final y =
            baseY +
            math.sin(t * 7 + shift) * 5 +
            math.sin(t * 13 - shift * 1.4) * 3 +
            math.sin(t * 23 + shift * 0.6) * 1.6;
        crestPath.lineTo(x, y);
      }
      canvas.drawPath(crestPath, crest);
    }
  }

  @override
  bool shouldRepaint(covariant _SunsetPainter oldDelegate) =>
      oldDelegate.wavePhase != wavePhase ||
      oldDelegate.cloudPhase != cloudPhase ||
      oldDelegate.sunCenter != sunCenter;
}
