import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum IdentityStatus { offlineGuest, anonymous, linked }

class IdentitySnapshot {
  const IdentitySnapshot({required this.status, this.userId, this.email});

  final IdentityStatus status;
  final String? userId;
  final String? email;
}

abstract interface class IdentityService {
  IdentitySnapshot get current;
  Stream<IdentitySnapshot> get changes;
  Future<void> bootstrap();
  Future<void> signInWithPassword(String email, String password);
  Future<void> signUp(String email, String password);
  Future<void> linkEmail(String email);
  Future<void> linkApple();
  Future<void> signOut();
  Future<void> deleteAccount();
}

class SupabaseIdentityService implements IdentityService {
  SupabaseIdentityService(this._client, {Future<void> Function()? onDeleted})
    : _current = const IdentitySnapshot(status: IdentityStatus.offlineGuest) {
    _onDeleted = onDeleted;
    _authSubscription = _client?.auth.onAuthStateChange.listen((event) {
      _emit(_fromSession(event.session));
    });
  }

  final SupabaseClient? _client;
  late final Future<void> Function()? _onDeleted;
  late final StreamSubscription<AuthState>? _authSubscription;
  final _controller = StreamController<IdentitySnapshot>.broadcast();
  IdentitySnapshot _current;

  @override
  IdentitySnapshot get current => _current;

  @override
  Stream<IdentitySnapshot> get changes => _controller.stream;

  @override
  Future<void> bootstrap() async {
    final client = _client;
    if (client == null) {
      _emit(const IdentitySnapshot(status: IdentityStatus.offlineGuest));
      return;
    }
    final session = client.auth.currentSession;
    if (session != null) {
      _emit(_fromSession(session));
      return;
    }
    try {
      final response = await client.auth.signInAnonymously();
      _emit(_fromSession(response.session));
    } on Object {
      _emit(const IdentitySnapshot(status: IdentityStatus.offlineGuest));
    }
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    await client.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;
    await client.auth.signOut(scope: SignOutScope.local);
    _emit(const IdentitySnapshot(status: IdentityStatus.offlineGuest));
  }

  @override
  Future<void> linkEmail(String email) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    await client.auth.updateUser(UserAttributes(email: email.trim()));
  }

  @override
  Future<void> linkApple() async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado');
    final response = await client.auth.getLinkIdentityUrl(
      OAuthProvider.apple,
      redirectTo: 'com.freeexperience.app://auth-callback',
    );
    final opened = await launchUrl(
      Uri.parse(response.url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) throw StateError('No se pudo abrir Apple');
  }

  @override
  Future<void> deleteAccount() async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) return;
    await client.functions.invoke('delete-account', method: HttpMethod.delete);
    await client.auth.signOut(scope: SignOutScope.local);
    await _onDeleted?.call();
    _emit(const IdentitySnapshot(status: IdentityStatus.offlineGuest));
  }

  IdentitySnapshot _fromSession(Session? session) {
    if (session == null) {
      return const IdentitySnapshot(status: IdentityStatus.offlineGuest);
    }
    final user = session.user;
    final anonymous = user.isAnonymous;
    return IdentitySnapshot(
      status: anonymous ? IdentityStatus.anonymous : IdentityStatus.linked,
      userId: user.id,
      email: user.email,
    );
  }

  void _emit(IdentitySnapshot snapshot) {
    _current = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _controller.close();
  }
}
