import 'package:shared_preferences/shared_preferences.dart';

import '../../core/util/app_log.dart';
import 'profile_repository.dart';

/// Estado "introducción escuchada": vive en el perfil remoto (cross-device)
/// con respaldo local para operar sin red. Antes esta coordinación estaba
/// duplicada entre la pantalla de login y la de bienvenida.
class IntroSeenStore {
  IntroSeenStore(this._profile);

  static const _prefKey = 'intro_seen';

  final ProfileRepository _profile;

  /// Flag combinado: el remoto manda si responde; sin red se usa el local.
  Future<bool> isSeen() async {
    final prefs = await SharedPreferences.getInstance();
    var seen = prefs.getBool(_prefKey) ?? false;
    try {
      final remote = await _profile.introSeen();
      if (remote != null) {
        seen = remote;
        await prefs.setBool(_prefKey, remote);
      }
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace, context: 'IntroSeenStore.isSeen');
    }
    return seen;
  }

  /// Marca la introducción como escuchada en local y en el perfil remoto.
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    await _profile.setIntroSeen();
  }
}
