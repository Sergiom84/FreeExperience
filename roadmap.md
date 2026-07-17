# SoulKey — Roadmap

## Visión

SoulKey es una aplicación móvil editorial de meditación, prácticas, canalizaciones e inspiración. La primera beta se valida en iPhone y comparte código con Android mediante Flutter.

La experiencia debe sentirse serena, íntima y elegante: acceso inmediato, audio fiable, navegación directa, cero gamificación, cero emojis y ningún texto tutorial que explique lo evidente.

## Punto de partida

- Proyecto nuevo, sin deuda técnica previa.
- Flutter + Riverpod + go_router.
- Supabase para Auth, Postgres y Storage.
- Drift para catálogo, progreso y operaciones offline.
- Catálogo administrado exclusivamente desde Supabase Dashboard durante la beta.
- Mac y Apple Developer disponibles para dispositivo físico y TestFlight.

## Destino de la beta

- Cuatro destinos: Meditar, Prácticas, Canalizaciones e Inspiración.
- Inspiración contiene Vídeos y Recomendaciones.
- Reproducción de audio en segundo plano y pantalla bloqueada.
- Temporizador, progreso, favoritos y descargas.
- Entrada anónima y vinculación opcional con Apple o email.
- Catálogo utilizable con mala conexión y audio descargado disponible sin red.
- Distribución TestFlight para 5–15 personas.

## Estado actual — 20 de junio de 2026

- Fundaciones, arquitectura local-first y CI implementadas.
- Tres direcciones Gstack disponibles en Perfil para evaluación conjunta.
- Catálogo semilla, navegación, audio, temporizador, progreso, favoritos, descargas, vídeo y recomendaciones implementados.
- Esquema Supabase, RLS, Storage, seed, pruebas pgTAP y eliminación de cuenta preparados.
- APK de depuración compilado correctamente en Windows.
- Pendiente de infraestructura externa: crear y enlazar Supabase, aportar contenido real y ejecutar QA/TestFlight en Mac y iPhone físico.

## Fases

### Fase 0 — Fundaciones

- [x] Inicializar Git y Flutter.
- [x] Fijar versión de Flutter y convenciones del repositorio.
- [x] Añadir README, DESIGN.md y ADR de arquitectura.
- [x] Configurar análisis, tests y CI.
- [x] Preparar configuración de desarrollo y beta sin secretos versionados.

**Salida:** `flutter analyze` y tests base en verde; documentación de arranque suficiente para Windows y macOS.

### Fase 1 — Dirección visual

- [x] Crear el sistema de diseño con Gstack.
- [x] Comparar tres conceptos para catálogo, reproductor y navegación.
- [ ] Aprobar una dirección visual.
- [ ] Validar iPhone SE, estándar y Pro Max.

**Salida:** DESIGN.md aprobado y referencia visual persistida.

### Fase 2 — Catálogo editorial

- [x] Crear esquema, migraciones, RLS y buckets.
- [x] Añadir contenido de demostración y caché local.
- [x] Documentar publicación desde Supabase Dashboard.
- [x] Impedir por base de datos que un borrador incompleto se publique.
- [ ] Validar las políticas contra el proyecto Supabase remoto.

**Salida:** catálogo publicado, privado por defecto y consultable desde la app.

### Fase 3 — Experiencia principal

- [x] Implementar navegación y catálogos.
- [x] Implementar detalle, favoritos y minirreproductor.
- [x] Añadir audio, segundo plano, temporizador y progreso.
- [x] Añadir descargas, cola y recuperación offline.
- [x] Añadir vídeo en streaming y recomendaciones.
- [x] Añadir identidad anónima y vinculación opcional.
- [ ] Validar el recorrido completo en un iPhone físico.

**Salida:** recorrido completo reproducible en un dispositivo real.

### Fase 4 — Endurecimiento iPhone

- [x] Preparar Dynamic Type, semántica base, contraste y Reduce Motion.
- [ ] Auditar VoiceOver y tamaños ampliados en iPhone físico.
- [ ] Llamadas, Siri, auriculares, Bluetooth y cambios de red.
- [x] Eliminación de cuenta, privacidad y aviso de bienestar.
- [x] Observabilidad sin PII.
- [x] Auditoría automatizada de textos y claves.

**Salida:** ningún fallo P0/P1 y criterios de beta satisfechos.

### Fase 5 — TestFlight

- [ ] Firmar y distribuir desde macOS/Xcode.
- [ ] Ejecutar beta interna de 5–15 personas.
- [ ] Medir primer play, finalización, descargas y fallos.
- [ ] Corregir incidencias antes de ampliar la beta.

### Fase 6 — Android

- [x] Ajustar servicio multimedia y notificación.
- [ ] Validar almacenamiento, permisos y tamaños.
- [ ] Publicar en prueba interna de Google Play.

## Riesgos principales

| Riesgo | Mitigación |
|---|---|
| Audio interrumpido o estado incoherente | Máquina de estados explícita y pruebas en dispositivo. |
| URL firmada expirada | Renovarla antes de iniciar la reproducción. |
| Primera apertura sin red | Catálogo semilla y una sesión breve incluida. |
| Descarga incompleta o sin espacio | Archivo temporal, verificación y limpieza atómica. |
| Acceso cruzado entre usuarios | RLS por `auth.uid()` y tests de seguridad. |
| Coste de vídeo directo | Límites editoriales en beta; vídeo adaptativo en fase posterior. |
| Diseño genérico | Consulta, shotgun y aprobación visual antes de cerrar pantallas. |

## Criterios de salida de beta

- Ningún fallo P0/P1 abierto.
- Audio descargado disponible sin conexión.
- Catálogo en caché tras reiniciar.
- Controles correctos en pantalla bloqueada.
- Vinculación de cuenta conserva datos.
- Eliminación borra datos locales y remotos.
- Cero claves privilegiadas en el binario.
- Cero emojis y cero textos tutoriales.
- Flujo principal probado en iPhone físico y TestFlight.

## Después de la beta

- CMS editorial propio.
- Suscripciones con RevenueCat.
- Vídeo adaptativo mediante Mux o equivalente.
- Notificaciones editoriales.
- Búsqueda, colecciones y personalización.

## Registro de decisiones

| Fecha | Decisión | Razón |
|---|---|---|
| 2026-06-20 | Flutter + Supabase | Compartir iOS/Android y reducir infraestructura inicial. |
| 2026-06-20 | Beta gratuita y editorial | Validar contenido y experiencia antes de monetizar. |
| 2026-06-20 | Entrada anónima | Permitir experimentar valor sin fricción. |
| 2026-06-20 | Audio completo desde MVP | Es la experiencia central, no un añadido posterior. |
| 2026-06-20 | Diseño nocturno y cálido | Conserva la sobriedad de las referencias sin parecer una app deportiva. |
| 2026-06-20 | Conservar los tres diseños durante la beta interna | Facilitar la elección conjunta en dispositivo antes de cerrar la identidad. |
| 2026-06-20 | Supabase remoto sin Docker local | Mantener el entorno del equipo ligero y validar mediante proyecto remoto y CI. |
