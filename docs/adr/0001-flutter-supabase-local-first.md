# ADR 0001 — Flutter, Supabase y estado local-first

**Estado:** aceptado  
**Fecha:** 2026-06-20

## Contexto

Free Experience necesita iOS y Android, audio en segundo plano, descargas, entrada sin registro visible y publicación editorial. El desarrollo comienza antes de disponer de un proyecto Supabase remoto y sin Docker local.

## Decisión

- Flutter comparte UI y dominio entre plataformas.
- Riverpod gestiona dependencias y estado observable.
- go_router define navegación declarativa.
- Drift conserva catálogo, progreso, favoritos, descargas y cola de sincronización.
- Supabase proporciona Auth, Postgres y Storage cuando existe configuración remota.
- La app arranca siempre con catálogo semilla; Supabase refresca y sustituye la caché cuando está disponible.
- Los servicios se definen mediante interfaces para que la ausencia de Supabase no contamine la UI.

## Consecuencias

- La interfaz y las pruebas no dependen de red ni credenciales.
- Los conflictos se resuelven por `updated_at`; las operaciones de historial usan identificadores idempotentes.
- Las migraciones pueden versionarse sin Docker, pero RLS y Storage requieren verificación posterior contra Supabase real o CI con servicios locales.
- Audio y descargas tienen implementaciones propias de infraestructura, pero contratos pequeños y testeables.

## Seguridad

- Solo publishable key en el cliente.
- `service_role` queda limitado a Supabase Edge Functions y Dashboard.
- Todo dato personal se protege por `auth.uid()`.
- Las funciones privilegiadas viven fuera de esquemas expuestos.

