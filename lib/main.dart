import 'dart:async';

import 'package:audio_service/audio_service.dart';
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
  WidgetsFlutterBinding.ensureInitialized();

  if (AppEnvironment.supabaseConfigured) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
    );
  }

  final database = AppDatabase();
  final audioHandler = await AudioService.init(
    builder: FreeExperienceAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.freeexperience.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await audioHandler.initialize();

  final app = ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      audioHandlerProvider.overrideWithValue(audioHandler),
    ],
    child: const FreeExperienceApp(),
  );

  if (AppEnvironment.sentryConfigured) {
    await SentryFlutter.init((options) {
      options.dsn = AppEnvironment.sentryDsn;
      options.environment = AppEnvironment.name;
      options.sendDefaultPii = false;
      options.enableAutoSessionTracking = true;
      options.tracesSampleRate = AppEnvironment.isProduction ? 0.1 : 0.0;
    }, appRunner: () => runApp(app));
  } else {
    runApp(app);
  }
}
