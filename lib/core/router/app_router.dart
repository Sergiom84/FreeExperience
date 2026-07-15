import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_extras_screen.dart';
import '../../features/admin/admin_gate_screen.dart';
import '../../features/admin/admin_guard.dart';
import '../../features/admin/admin_wizard_screen.dart';
import '../../features/content/domain/content_item.dart';
import '../../features/identity/identity_service.dart';
import '../../features/identity/login_screen.dart';
import '../../features/ui/app_shell.dart';
import '../../features/ui/catalog_screen.dart';
import '../../features/ui/content_detail_screen.dart';
import '../../features/ui/favorites_screen.dart';
import '../../features/ui/full_player_screen.dart';
import '../../features/ui/inspiration_screen.dart';
import '../../features/ui/legal_screen.dart';
import '../../features/ui/profile_screen.dart';
import '../../features/ui/welcome_screen.dart';
import '../../features/ui/welcome_sunset_screen.dart';
import '../providers.dart';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(identityProvider, (prev, next) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final identity = ref.read(identityProvider).asData?.value;
      final isLinked = identity?.status == IdentityStatus.linked;
      final onLogin = state.matchedLocation == '/login';
      final onLegal = state.matchedLocation.startsWith('/legal/');

      if (!isLinked && !onLogin && !onLegal) return '/login';
      // La primera pantalla (bienvenida vs meditar) la decide LoginScreen según
      // si ya se escuchó la introducción; aquí solo sacamos del login.
      if (isLinked && onLogin) return '/meditar';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/bienvenida',
        builder: (context, state) => const WelcomeSunsetScreen(),
      ),
      GoRoute(
        path: '/bienvenida-orbita',
        builder: (context, state) => const WelcomeScreen(),
      ),
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
                path: '/canalizaciones',
                builder: (context, state) =>
                    const CatalogScreen(kind: ContentKind.channeling),
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
        path: '/admin',
        builder: (context, state) => const AdminGateScreen(),
      ),
      GoRoute(
        path: '/admin/:kind/nuevo',
        builder: (context, state) => AdminGuard(
          child: AdminWizardScreen(
            kind: ContentKindLabel.parse(state.pathParameters['kind']!),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/:kind/editar/:id',
        builder: (context, state) => AdminGuard(
          child: AdminWizardScreen(
            kind: ContentKindLabel.parse(state.pathParameters['kind']!),
            editId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/admin/extras',
        builder: (context, state) =>
            const AdminGuard(child: AdminExtrasScreen()),
      ),
      GoRoute(
        path: '/admin/extras/introduccion',
        builder: (context, state) =>
            const AdminGuard(child: AdminIntroScreen()),
      ),
      GoRoute(
        path: '/admin/:kind',
        builder: (context, state) => AdminGuard(
          child: AdminSectionScreen(
            kind: ContentKindLabel.parse(state.pathParameters['kind']!),
          ),
        ),
      ),
      GoRoute(
        path: '/legal/:document',
        builder: (context, state) => LegalScreen(
          document: LegalDocumentCopy.parse(state.pathParameters['document']!),
        ),
      ),
    ],
  );
  ref.onDispose(authNotifier.dispose);
  ref.onDispose(router.dispose);
  return router;
});
