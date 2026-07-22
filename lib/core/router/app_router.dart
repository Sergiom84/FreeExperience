import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin_extras_screen.dart';
import '../../features/admin/admin_gate_screen.dart';
import '../../features/admin/admin_guard.dart';
import '../../features/admin/admin_wizard_screen.dart';
import '../../features/content/domain/content_item.dart';
import '../../features/identity/identity_service.dart';
import '../../features/identity/login_screen.dart';
import '../../features/ui/about_me_screen.dart';
import '../../features/ui/app_shell.dart';
import '../../features/ui/catalog_screen.dart';
import '../../features/ui/home_screen.dart';
import '../../features/ui/search_screen.dart';
import '../../features/ui/content_detail_screen.dart';
import '../../features/ui/favorites_screen.dart';
import '../../features/ui/full_player_screen.dart';
import '../../features/ui/inspiration_screen.dart';
import '../../features/ui/legal_screen.dart';
import '../../features/ui/profile_screen.dart';
import '../../features/ui/welcome_screen.dart';
import '../../features/ui/welcome_sunset_screen.dart';
import '../../features/ui/widgets/app_background.dart';
import '../providers.dart';

/// Envuelve cada ruta en el fondo global. Al ser una capa opaca (imagen +
/// velo) por página, la ruta entrante oculta la saliente durante la transición
/// (antes, con scaffolds transparentes, se veía la anterior "arrastrarse").
Widget _bg(Widget child) => AppBackground(child: child);

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
      // La primera pantalla (bienvenida vs canalizaciones) la decide
      // LoginScreen de forma async según si ya se escuchó la introducción
      // (`_goAfterAuth`/`introSeenStoreProvider`). Un redirect síncrono aquí
      // ganaba siempre esa carrera y producía un parpadeo
      // catálogo→bienvenida; el login ya se encarga de salir por su cuenta.
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => _bg(const LoginScreen()),
      ),
      GoRoute(
        path: '/bienvenida',
        builder: (context, state) => _bg(const WelcomeSunsetScreen()),
      ),
      GoRoute(
        path: '/bienvenida-orbita',
        builder: (context, state) => _bg(const WelcomeScreen()),
      ),
      // Home intermedio: esfera con las cuatro llaves. Es la primera pantalla
      // tras la bienvenida y para quien ya escuchó la introducción.
      GoRoute(
        path: '/home',
        builder: (context, state) => _bg(const HomeScreen()),
      ),
      GoRoute(
        path: '/buscar',
        builder: (context, state) => _bg(const SearchScreen()),
      ),
      GoRoute(
        path: '/quien-soy',
        builder: (context, state) => _bg(const AboutMeScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _bg(AppShell(navigationShell: navigationShell)),
        branches: [
          // Canaliza ocupa el primer puesto: es la sección con la que se
          // abre la app (decisión 2026-07-16, revisable).
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
            _bg(ContentDetailScreen(contentId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) => _bg(const FullPlayerScreen()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => _bg(const ProfileScreen()),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => _bg(const FavoritesScreen()),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => _bg(const AdminGateScreen()),
      ),
      GoRoute(
        path: '/admin/:kind/nuevo',
        builder: (context, state) => _bg(
          AdminGuard(
            child: AdminWizardScreen(
              kind: ContentKindLabel.parse(state.pathParameters['kind']!),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/:kind/editar/:id',
        builder: (context, state) => _bg(
          AdminGuard(
            child: AdminWizardScreen(
              kind: ContentKindLabel.parse(state.pathParameters['kind']!),
              editId: state.pathParameters['id'],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/admin/extras',
        builder: (context, state) =>
            _bg(const AdminGuard(child: AdminExtrasScreen())),
      ),
      GoRoute(
        path: '/admin/extras/introduccion',
        builder: (context, state) =>
            _bg(const AdminGuard(child: AdminIntroScreen())),
      ),
      GoRoute(
        path: '/admin/:kind',
        builder: (context, state) => _bg(
          AdminGuard(
            child: AdminSectionScreen(
              kind: ContentKindLabel.parse(state.pathParameters['kind']!),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/legal/:document',
        builder: (context, state) => _bg(
          LegalScreen(
            document: LegalDocumentCopy.parse(
              state.pathParameters['document']!,
            ),
          ),
        ),
      ),
    ],
  );
  ref.onDispose(authNotifier.dispose);
  ref.onDispose(router.dispose);
  return router;
});
