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
          // del bottom bar usan formas cortas ("Canales", "Inspirar") porque
          // los nombres completos no caben en una línea a 4 pestañas; el nombre
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
                  icon: Icon(Icons.water_drop_outlined),
                  selectedIcon: Icon(Icons.water_drop),
                  label: 'Meditar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.self_improvement_outlined),
                  selectedIcon: Icon(Icons.self_improvement),
                  label: 'Prácticas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.graphic_eq_outlined),
                  selectedIcon: Icon(Icons.graphic_eq),
                  label: 'Canales',
                ),
                NavigationDestination(
                  icon: Icon(Icons.slow_motion_video_outlined),
                  selectedIcon: Icon(Icons.slow_motion_video),
                  label: 'Inspirar',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
