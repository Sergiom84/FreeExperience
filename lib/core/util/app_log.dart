import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_environment.dart';

/// Registra un error atrapado en una degradación suave: la app sigue
/// funcionando, pero el fallo queda en Sentry (y en consola en desarrollo)
/// en vez de perderse en silencio.
void reportError(Object error, StackTrace stackTrace, {String? context}) {
  if (kDebugMode) {
    debugPrint('Error${context == null ? '' : ' [$context]'}: $error');
  }
  if (AppEnvironment.sentryConfigured) {
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
  }
}
