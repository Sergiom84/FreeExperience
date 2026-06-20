# Conexión del proyecto Supabase remoto

No requiere Docker ni una clave de OpenAI.

## Datos necesarios

- Project ref.
- Project URL.
- Publishable key (`sb_publishable_...`).

No compartir ni introducir en Flutter `service_role`, secret keys o la contraseña de base de datos.

## Ajustes del Dashboard

En **Authentication → Providers**:

- Activar Anonymous Sign-Ins.
- Activar Manual Linking.
- Configurar Apple antes de probar esa vinculación.

En **Authentication → URL Configuration** añadir:

```text
com.freeexperience.free-experience://auth-callback
```

Antes de una beta abierta, activar CAPTCHA o Turnstile para reducir abuso del alta anónima.

## Aplicar infraestructura

```powershell
supabase login
supabase link --project-ref PROJECT_REF
supabase db push
supabase functions deploy delete-account
```

Las migraciones crean tablas, RLS y buckets. `seed.sql` contiene rutas editoriales de ejemplo, pero no sube archivos a Storage.

## Ejecutar la app

```powershell
flutter run `
  --dart-define=APP_ENV=beta `
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

## Validación remota

1. Crear un borrador y confirmar que no aparece en la app.
2. Intentar publicarlo sin portada o medio y confirmar el rechazo.
3. Publicarlo completo y confirmar catálogo, URL firmada y reproducción.
4. Crear dos usuarios y verificar que favoritos y progreso no se cruzan.
5. Vincular una cuenta anónima y confirmar que mantiene su UUID y sus datos.
6. Eliminar la cuenta desde la app y confirmar la cascada de datos.
