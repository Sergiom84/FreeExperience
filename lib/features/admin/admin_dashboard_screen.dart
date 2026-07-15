import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/domain/content_item.dart';
import 'admin_controller.dart';

/// Panel principal de administración: rejilla de secciones y salida.
/// Extraído de admin_gate_screen.dart.
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  // Secciones con logo propio (imagen rica de nav) agrupadas primero; Vídeos y
  // Extras conservan su glifo Material y quedan en las últimas casillas. El
  // `label` mostrado difiere del catálogo para alinearse con la nav (Prácticas
  // se presenta como "Duerme", Recomendaciones como "Inspira").
  static const _sections = [
    (
      kind: ContentKind.meditation,
      label: 'Meditaciones',
      image: 'assets/icons/nav/medita.png',
      icon: Icons.self_improvement,
      color: Color(0xFF7C3AED),
    ),
    (
      kind: ContentKind.practice,
      label: 'Duerme',
      image: 'assets/icons/nav/duerme.png',
      icon: Icons.spa,
      color: Color(0xFF059669),
    ),
    (
      kind: ContentKind.channeling,
      label: 'Canalizaciones',
      image: 'assets/icons/nav/canaliza.png',
      icon: Icons.waves,
      color: Color(0xFF2563EB),
    ),
    (
      kind: ContentKind.recommendation,
      label: 'Inspira',
      image: 'assets/icons/nav/inspira.png',
      icon: Icons.star,
      color: Color(0xFFD97706),
    ),
    (
      kind: ContentKind.video,
      label: 'Vídeos',
      image: null,
      icon: Icons.play_circle,
      color: Color(0xFFDC2626),
    ),
    (
      kind: ContentKind.intro,
      label: 'Extras',
      image: null,
      icon: Icons.wb_sunny,
      color: Color(0xFFEA8C2A),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(adminAuthProvider).signOut();
              ref.invalidate(isAdminProvider);
              if (context.mounted) context.go('/meditar');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 480 ? 3 : 2;
              return GridView.count(
                padding: const EdgeInsets.all(20),
                crossAxisCount: columns,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
                children: [
                  for (final s in _sections)
                    _SectionCard(
                      label: s.label,
                      icon: s.icon,
                      image: s.image,
                      color: s.color,
                      onTap: () => context.push(
                        s.kind == ContentKind.intro
                            ? '/admin/extras'
                            : '/admin/${s.kind.databaseValue}',
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.icon,
    required this.image,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? image;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.85),
                          color.withValues(alpha: 0.45),
                        ],
                      ),
                    ),
                    child: Center(
                      child: image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                image!,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(icon, color: Colors.white, size: 34),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
