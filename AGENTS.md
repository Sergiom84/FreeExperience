# SoulKey

## Design System

Lee `DESIGN.md` antes de cualquier decisión visual. No introduzcas colores, tipografías, espaciados ni patrones fuera del sistema sin aprobación explícita.

Durante la beta interna conviven tres direcciones mediante un selector de evaluación. No elimines ninguna hasta que el equipo apruebe una.

## Product rules

- No emojis en interfaz, datos semilla, notificaciones ni mensajes.
- No subtítulos explicativos ni textos que describan la función de una pantalla.
- No gamificación, rachas, puntos ni afirmaciones terapéuticas.
- No secretos privilegiados en el cliente.
- RLS en todas las tablas expuestas de Supabase.

## Verification

Antes de cerrar cambios ejecuta `dart format`, `flutter analyze` y `flutter test`.

