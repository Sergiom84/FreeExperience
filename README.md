# SoulKey

Aplicación móvil editorial de meditación, prácticas, canalizaciones e inspiración. Flutter comparte la base de código entre iOS y Android; la primera beta se valida en iPhone.

## Estado

El proyecto está en construcción. La app funciona con un catálogo local de demostración cuando Supabase no está configurado, por lo que puede desarrollarse y probarse antes de disponer del proyecto remoto.

## Requisitos

- Flutter estable compatible con Dart 3.11.
- FVM recomendado para mantener la misma versión en Windows y macOS.
- Xcode y Apple Developer para dispositivo físico y TestFlight.
- Supabase CLI para migraciones. Docker no es obligatorio: la validación puede hacerse contra un proyecto remoto.

## Arranque

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Sin configuración adicional se usa el catálogo semilla y la identidad local. Para conectar Supabase:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Nunca uses `service_role` ni una secret key en la aplicación.

Variables opcionales:

- `SENTRY_DSN`: captura de errores sin PII.
- `APP_ENV`: `development`, `beta` o `production`.

## Verificación

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Las pruebas de base de datos se podrán ejecutar contra Supabase cuando el proyecto esté vinculado. Las migraciones y políticas están versionadas en `supabase/`.

La conexión remota está detallada en [docs/supabase-remote-setup.md](docs/supabase-remote-setup.md).

## Diseño

La fuente de verdad es [DESIGN.md](DESIGN.md). Durante la evaluación existen tres direcciones seleccionables desde Perfil → Diseño. El selector se retirará antes de la publicación pública.

## Documentación

- [Roadmap](roadmap.md)
- [Arquitectura](docs/adr/0001-flutter-supabase-local-first.md)
- [Flujo editorial](docs/editorial-workflow.md)
- [Conexión Supabase](docs/supabase-remote-setup.md)
