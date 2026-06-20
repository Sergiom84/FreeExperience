import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
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
              const Spacer(),
              IconButton(
                tooltip: 'Guardados',
                onPressed: () => context.push('/favorites'),
                icon: const Icon(Icons.bookmark_border),
              ),
              IconButton(
                tooltip: 'Perfil',
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.person_outline),
              ),
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
