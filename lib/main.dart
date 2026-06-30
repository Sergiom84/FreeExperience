import 'dart:async';
import 'dart:io';

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

/// Returns true on iOS 27+ where audio_service native init crashes due to an
/// internal GCD API change ([OS_dispatch_mach_msg _setContext:]).
bool _isIOS27OrAbove() {
  if (!Platform.isIOS) return false;
  final match = RegExp(
    r'Version (\d+)',
  ).firstMatch(Platform.operatingSystemVersion);
  return (int.tryParse(match?.group(1) ?? '0') ?? 0) >= 27;
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

  // iOS 27 beta introduced an API change in GCD (OS_dispatch_mach_msg) that
  // makes AudioService.init + AudioSession.configure crash natively with
  // [OS_dispatch_mach_msg _setContext:] unrecognized selector — a SIGABRT that
  // Dart try/catch cannot intercept. Skip the full native audio stack on iOS
  // 27+ beta; just_audio still plays audio in-app, only lock-screen controls
  // and background notifications are unavailable on those builds.
  final bool skipNativeAudio = !kIsWeb && _isIOS27OrAbove();

  final FreeExperienceAudioHandler audioHandler;
  if (kIsWeb || skipNativeAudio) {
    audioHandler = FreeExperienceAudioHandler();
  } else {
    FreeExperienceAudioHandler? handler;
    try {
      handler = await AudioService.init(
        builder: FreeExperienceAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.freeexperience.audio',
          androidNotificationChannelName: 'Reproducción',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (_) {
      handler = FreeExperienceAudioHandler();
    }
    audioHandler = handler;
  }
  if (!skipNativeAudio) {
    await audioHandler.initialize();
  }

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
