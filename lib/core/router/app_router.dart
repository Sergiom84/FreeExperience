import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/content/domain/content_item.dart';
import '../../features/ui/app_shell.dart';
import '../../features/ui/catalog_screen.dart';
import '../../features/ui/content_detail_screen.dart';
import '../../features/ui/favorites_screen.dart';
import '../../features/ui/full_player_screen.dart';
import '../../features/ui/inspiration_screen.dart';
import '../../features/ui/legal_screen.dart';
import '../../features/ui/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/meditar',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/meditar',
                builder: (context, state) =>
                    const CatalogScreen(kind: ContentKind.meditation),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practicas',
                builder: (context, state) =>
                    const CatalogScreen(kind: ContentKind.practice),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/canalizaciones',
                builder: (context, state) =>
                    const CatalogScreen(kind: ContentKind.channeling),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inspiracion',
                builder: (context, state) => const InspirationScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/content/:id',
        builder: (context, state) =>
            ContentDetailScreen(contentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => const FullPlayerScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/legal/:document',
        builder: (context, state) => LegalScreen(
          document: LegalDocumentCopy.parse(state.pathParameters['document']!),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
