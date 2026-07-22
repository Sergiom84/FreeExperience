import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';

class ScreenHeader extends ConsumerWidget {
  const ScreenHeader({this.title, this.subtitle, super.key});

  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(avatarUrlProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 66,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Inicio',
                visualDensity: VisualDensity.compact,
                onPressed: () => context.go('/home'),
                icon: const Image(
                  image: AssetImage('assets/icons/nav/llave.png'),
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 6),
              // Título "Tu portal · Tus llaves" como imagen (tipografía dorada
              // exacta de la guía). FittedBox lo agranda hasta donde cabe en el
              // ancho disponible, con tope de 40px de alto.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Image(
                    image: const AssetImage('assets/icons/nav/portal.png'),
                    height: 40,
                    fit: BoxFit.contain,
                    semanticLabel: 'Tu portal · Tus llaves',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Buscar',
                onPressed: () => context.push('/buscar'),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Guardados',
                onPressed: () => context.push('/favorites'),
                icon: const Icon(Icons.bookmark_border),
              ),
              _ProfileButton(avatarUrl: avatarUrl),
            ],
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 20),
          Text(title!, style: Theme.of(context).textTheme.displayMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 22),
        ],
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null) {
      return IconButton(
        tooltip: 'Perfil',
        onPressed: () => context.push('/profile'),
        icon: const Icon(Icons.person_outline),
      );
    }
    return Semantics(
      button: true,
      label: 'Perfil',
      child: InkWell(
        onTap: () => context.push('/profile'),
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: SizedBox(
              width: 28,
              height: 28,
              child: Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person_outline),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
