import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

/// True only for a signed-in, non-anonymous user present in public.admins.
/// Recomputed whenever the auth identity changes.
final isAdminProvider = FutureProvider<bool>((ref) async {
  ref.watch(identityProvider);
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return false;
  final session = client.auth.currentSession;
  if (session == null || session.user.isAnonymous) return false;
  try {
    final result = await client.rpc('is_admin');
    return result == true;
  } on Object {
    return false;
  }
});

class AdminAuth {
  AdminAuth(this._client);

  final SupabaseClient? _client;

  /// Usernames are mapped to a synthetic email behind the scenes, so people can
  /// sign in with just "sergio" instead of a real address.
  static const _domain = 'freeexperience.app';

  String _emailFor(String username) =>
      '${username.trim().toLowerCase()}@$_domain';

  Future<void> signIn(String username, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    await client.auth.signInWithPassword(
      email: _emailFor(username),
      password: password,
    );
  }

  Future<void> register(String username, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    final name = username.trim().toLowerCase();
    await client.auth.signUp(
      email: _emailFor(name),
      password: password,
      data: {'username': name},
    );
  }

  Future<void> signOut() async {
    await _client?.auth.signOut(scope: SignOutScope.local);
  }
}

final adminAuthProvider = Provider<AdminAuth>(
  (ref) => AdminAuth(ref.watch(supabaseClientProvider)),
);
