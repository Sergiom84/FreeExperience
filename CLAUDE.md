# SoulKey

## Design System

Lee `DESIGN.md` antes de cualquier decisión visual. No introduzcas colores, tipografías, espaciados ni patrones fuera del sistema sin aprobación explícita.

Durante la beta interna conviven tres direcciones mediante un selector de evaluación. No elimines ninguna hasta que el equipo apruebe una.

## Product rules

- No emojis en interfaz, datos semilla, notificaciones ni mensajes.
- No subtítulos explicativos ni textos que describan la función de una pantalla. Excepción aprobada (2026-07-15): las cuatro secciones principales (Medita, Canaliza, Duerme, Inspira) llevan un descriptor breve bajo el título de su cabecera, tomado de la guía "tu portal, tus llaves".
- No gamificación, rachas, puntos ni afirmaciones terapéuticas.
- No secretos privilegiados en el cliente.
- RLS en todas las tablas expuestas de Supabase.

## Verification

Antes de cerrar cambios ejecuta `dart format`, `flutter analyze` y `flutter test`.

