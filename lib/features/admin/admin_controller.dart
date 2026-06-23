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
