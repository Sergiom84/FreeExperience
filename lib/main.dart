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

/// iOS 27 beta changed an internal GCD API (OS_dispatch_mach_msg) that
/// AVAudioSession.setCategory() relies on, causing a SIGABRT that Dart
/// cannot catch. Detect iOS 27+ by extracting the first integer from
/// Platform.operatingSystemVersion, which can be "27.0" or
/// "Version 27.0 (Build ...)".
bool _isIOS27OrAbove() {
  if (kIsWeb || !Platform.isIOS) return false;
  final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
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
  final FreeExperienceAudioHandler audioHandler;
  final bool skipAudioSession = _isIOS27OrAbove();

  if (kIsWeb) {
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
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      handler = FreeExperienceAudioHandler();
    }
    audioHandler = handler;
    // initialize() calls AVAudioSession.setCategory() which triggers a native
    // SIGABRT on iOS 27 beta — skip it entirely on those builds.
    // just_audio handles audio routing internally; only interruption callbacks
    // are absent on these builds.
    if (!skipAudioSession) {
      try {
        await audioHandler.initialize();
      } catch (_) {}
    }
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
