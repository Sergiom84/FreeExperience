import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_environment.dart';
import 'core/database/app_database.dart';
import 'core/providers.dart';
import 'features/player/free_experience_audio_handler.dart';

Future<void> main() async {
  // El arranque (Supabase, base de datos, audio) corre dentro del appRunner de
  // Sentry para que cualquier fallo de inicialización quede reportado y no en
  // silencio. Sin Sentry configurado, se arranca igual.
  if (AppEnvironment.sentryConfigured) {
    await SentryFlutter.init((options) {
      options.dsn = AppEnvironment.sentryDsn;
      options.environment = AppEnvironment.name;
      options.sendDefaultPii = false;
      options.enableAutoSessionTracking = true;
      options.tracesSampleRate = AppEnvironment.isProduction ? 0.1 : 0.0;
    }, appRunner: _bootstrapAndRun);
  } else {
    await _bootstrapAndRun();
  }
}

Future<void> _bootstrapAndRun() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppEnvironment.supabaseConfigured) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
    );
  }

  final database = AppDatabase();
  // audio_service no ofrece integración con el sistema en web; allí se
  // construye el handler directamente (just_audio reproduce igual). En móvil
  // se conserva AudioService.init para notificaciones y reproducción en
  // segundo plano.
  final FreeExperienceAudioHandler audioHandler;
  if (kIsWeb) {
    audioHandler = FreeExperienceAudioHandler();
  } else {
    audioHandler = await AudioService.init(
      builder: FreeExperienceAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.freeexperience.audio',
        androidNotificationChannelName: 'Reproducción',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  }
  await audioHandler.initialize();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const FreeExperienceApp(),
    ),
  );
}
