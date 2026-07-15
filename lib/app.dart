import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_theme.dart';
import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'features/ui/widgets/app_background.dart';

class FreeExperienceApp extends ConsumerWidget {
  const FreeExperienceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(designDirectionProvider);
    ref.watch(appBootstrapProvider);
    ref.watch(contentAutoRefreshProvider);
    return MaterialApp.router(
      title: 'Free Experience',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forDirection(direction),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            boldText: media.boldText,
            disableAnimations: media.disableAnimations,
          ),
          child: AppBackground(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
