import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/util/image_prep.dart';

/// Reads and writes the signed-in user's profile photo. The avatar lives in the
/// public `avatars` bucket under `<uid>/avatar.jpg` and its path is mirrored in
/// `public.profiles.avatar_path` so the home and profile can render it.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _remote {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    return client;
  }

  /// Public URL of the current avatar, or null if none / not signed in. A cache
  /// buster keeps the home image fresh after a replacement.
  Future<String?> avatarUrl() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || user.isAnonymous) return null;
    final row = await client
        .from('profiles')
        .select('avatar_path, updated_at')
        .eq('id', user.id)
        .maybeSingle();
    final path = row?['avatar_path'] as String?;
    if (path == null || path.isEmpty) return null;
    final base = client.storage.from('avatars').getPublicUrl(path);
    final stamp = row?['updated_at'] as String?;
    return stamp == null ? base : '$base?v=${Uri.encodeComponent(stamp)}';
  }

  /// Resizes to a square-ish thumbnail, uploads it and records the path. Returns
  /// the fresh public URL.
  Future<String> uploadAvatar(Uint8List bytes) async {
    final user = _remote.auth.currentUser;
    if (user == null) throw StateError('Sin sesión');
    // El avatar se sube siempre como JPEG (ruta y contentType fijos); si el
    // formato no se puede decodificar se rechaza en vez de subir bytes
    // arbitrarios etiquetados como image/jpeg.
    final prepared = prepareImage(bytes, maxDimension: 512);
    if (prepared == null) throw StateError('Formato de imagen no soportado');
    final path = '${user.id}/avatar.jpg';
    await _remote.storage
        .from('avatars')
        .uploadBinary(
          path,
          prepared.bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    await _remote.from('profiles').upsert({'id': user.id, 'avatar_path': path});
    final url = await avatarUrl();
    if (url == null) {
      throw StateError('El avatar no está disponible tras subirlo');
    }
    return url;
  }

  /// Whether the signed-in user already listened to the welcome introduction.
  /// Null when offline/anonymous so callers can fall back to the local flag.
  Future<bool?> introSeen() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || user.isAnonymous) return null;
    final row = await client
        .from('profiles')
        .select('intro_seen')
        .eq('id', user.id)
        .maybeSingle();
    return (row?['intro_seen'] as bool?) ?? false;
  }

  /// Marks the introduction as seen for the signed-in user.
  Future<void> setIntroSeen() async {
    final user = _remote.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    await _remote.from('profiles').upsert({'id': user.id, 'intro_seen': true});
  }
}
