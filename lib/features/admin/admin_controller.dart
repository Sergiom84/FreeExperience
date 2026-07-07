import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

/// True only for a signed-in, non-anonymous user present in public.admins.
/// Recomputed whenever the auth identity changes. Los errores (p. ej. un corte
/// de red durante el RPC) se propagan como estado de error para que la UI
/// ofrezca reintentar, en vez de tratarlos como "no es admin" y expulsar al
/// administrador a la pantalla de acceso.
final isAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(identityProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return false;
  final session = client.auth.currentSession;
  if (session == null || session.user.isAnonymous) return false;
  final result = await client.rpc('is_admin');
  return result == true;
});

class AdminAuth {
  AdminAuth(this._client);

  final SupabaseClient? _client;

  Future<void> signIn(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    // Sign out any active anonymous session before creating a new account.
    if (client.auth.currentSession != null) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
    await client.auth.signUp(email: email.trim(), password: password);
  }

  Future<void> signOut() async {
    await _client?.auth.signOut(scope: SignOutScope.local);
  }
}

final adminAuthProvider = Provider<AdminAuth>(
  (ref) => AdminAuth(ref.watch(supabaseClientProvider)),
);
