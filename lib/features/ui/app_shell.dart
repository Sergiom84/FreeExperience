import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'mini_player.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          // Sin override local de estilo: el labelTextStyle del tema global ya
          // resuelve color, peso y tamaño según el estado seleccionado. El
          // clamp del textScaler evita que el tamaño de texto del sistema
          // (accesibilidad) parta las etiquetas en dos líneas. Las etiquetas
          // del bottom bar usan formas cortas de una palabra porque los
          // nombres completos no caben en una línea a 4 pestañas; el nombre
          // completo de cada sección aparece en su cabecera.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.0,
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              destinations: const [
                NavigationDestination(
                  icon: _NavImageIcon('assets/icons/nav/medita.png'),
                  label: 'Medita',
                ),
                NavigationDestination(
                  icon: _NavImageIcon('assets/icons/nav/canaliza.png'),
                  label: 'Canaliza',
                ),
                NavigationDestination(
                  icon: _NavImageIcon('assets/icons/nav/duerme.png'),
                  label: 'Duerme',
                ),
                NavigationDestination(
                  icon: _NavImageIcon('assets/icons/nav/inspira.png'),
                  label: 'Inspira',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Icono de nav con imagen rica (fondo oscuro propio + brillo dorado). Se
/// muestra tal cual, sin tinte ni recorte de fondo, en un tile redondeado para
/// que los bordes oscuros lean como intencionados sobre la barra. `BoxFit.cover`
/// recorta al cuadrado centrado, dejando el sujeto (figura, llave, luna,
/// corazón) centrado en el tile.
class _NavImageIcon extends StatelessWidget {
  const _NavImageIcon(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Image(
        image: AssetImage(asset),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
}
