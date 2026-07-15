import 'package:flutter/material.dart';

/// Fondo global de la app: imagen de nubes (tonos blanco/oro/negro) cubierta
/// por un velo del color de fondo del tema para mantener el texto legible.
///
/// Se coloca detrás de todo el árbol de navegación desde `MaterialApp.builder`.
/// Los `Scaffold` usan `scaffoldBackgroundColor` transparente, así que este
/// fondo se ve a través de ellos. Si la imagen aún no existe, `errorBuilder`
/// cae al color de fondo sólido y la app se ve como antes.
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  static const _asset = 'assets/images/fondo.png';

  @override
  Widget build(BuildContext context) {
    // Color base del velo, teñido según dirección/brillo del tema.
    final scrimBase = _scrimBase(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _asset,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(color: scrimBase),
        ),
        // Velo: oscurece (o aclara en tema claro) para que el texto del tema,
        // pensado para fondo plano, conserve contraste sobre las nubes.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scrimBase.withValues(alpha: 0.72),
                scrimBase.withValues(alpha: 0.58),
                scrimBase.withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        child,
      ],
    );
  }

  Color _scrimBase(BuildContext context) {
    // Color base del velo por dirección de diseño: negro-azulado para los temas
    // oscuros, crema para el claro. Se deriva del brillo del tema.
    final scheme = Theme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? const Color(0xFF080B0F)
        : const Color(0xFFE9E5DC);
  }
}
