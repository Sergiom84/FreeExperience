import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';

class ScreenHeader extends ConsumerWidget {
  const ScreenHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(avatarUrlProvider).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 58,
          child: Row(
            children: [
              Text(
                'Free Experience',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Inicio',
                visualDensity: VisualDensity.compact,
                onPressed: () => context.go('/bienvenida'),
                icon: const Icon(Icons.home_outlined, size: 20),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Guardados',
                onPressed: () => context.push('/favorites'),
                icon: const Icon(Icons.bookmark_border),
              ),
              _ProfileButton(avatarUrl: avatarUrl),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 22),
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
