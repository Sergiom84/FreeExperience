# Design System — SoulKey

## Product Context

- **Producto:** biblioteca móvil editorial de meditación, prácticas, canalizaciones, vídeos y recomendaciones.
- **Audiencia:** personas que buscan una experiencia contemplativa directa, sin gamificación ni fricción de registro.
- **Tipo:** aplicación móvil de consumo, audio-first.
- **Recuerdo buscado:** un espacio íntimo, sobrio y cuidado que no necesita explicarse.

## Principios compartidos

1. La interfaz se entiende por jerarquía y comportamiento, no por párrafos explicativos.
2. Cero emojis, rachas, puntos, celebraciones o lenguaje terapéutico.
3. Solo títulos, autores, duración, estado y acciones esenciales.
4. Las portadas son cinematográficas y atmosféricas; nunca llevan texto incrustado.
5. El audio y su continuidad tienen prioridad sobre cualquier decoración.
6. Toda acción táctil mide al menos 44×44 puntos.
7. Dynamic Type, VoiceOver y Reduce Motion forman parte del diseño, no del pulido final.

## Direcciones candidatas

Las tres direcciones permanecen implementadas durante la beta interna para revisión conjunta. Comparten estructura y accesibilidad, pero cambian tipografía, color, ritmo y tratamiento del catálogo.

### A — Umbral nocturno

- **Dirección:** editorial cinematográfica nocturna.
- **Display:** Cormorant Garamond 500/600.
- **UI:** Manrope 400/500/600.
- **Fondo:** `#080B0F`.
- **Superficie:** `#141A21`.
- **Marfil:** `#F4EFE6`.
- **Secundario:** `#AAA397`.
- **Acento:** `#C6A15B`.
- **Layout:** portada protagonista, ritmo espacioso y minirreproductor flotante.

### B — Materia quieta

- **Dirección:** orgánica, cálida y táctil.
- **Display:** Fraunces 500/600.
- **UI:** Source Sans 3 400/500/600.
- **Fondo:** `#17130F`.
- **Superficie:** `#241D17`.
- **Hueso:** `#F2E8DA`.
- **Secundario:** `#B7A58F`.
- **Acento:** `#BE7C56`.
- **Layout:** composición asimétrica, arcos contenidos y listas editoriales.

### C — Silencio mineral

- **Dirección:** minimalismo editorial luminoso.
- **Display:** Instrument Serif 400.
- **UI:** DM Sans 400/500/600.
- **Fondo:** `#E9E5DC`.
- **Superficie:** `#F3F0E9`.
- **Grafito:** `#181A1B`.
- **Secundario:** `#6E6A63`.
- **Acento:** `#8A6A3E`.
- **Layout:** líneas finas, imágenes desaturadas y mínimo uso de contenedores.

## Tipografía

- Escala: display 52/48, título de página 42/40, sección 26/30, tarjeta 17/22, cuerpo 15/22, metadato 12/16.
- Máximo dos familias activas por dirección.
- Los metadatos pueden usar mayúsculas únicamente cuando sean breves.
- Nunca se reduce el cuerpo por debajo de 14 px equivalentes.

## Espaciado y forma

- Unidad base: 4 px.
- Escala: 4, 8, 12, 16, 20, 24, 32, 48, 64.
- Márgenes móviles: 20 px; 16 px en anchos compactos.
- Radios jerárquicos, no universales: 2, 8, 14 y 22 px.
- Las tarjetas solo se usan cuando toda la superficie es interactiva.

## Motion

- Enfoque intencional y discreto.
- Microinteracción: 100–160 ms.
- Transición corta: 180–240 ms.
- Entrada atmosférica: 320–450 ms.
- Curva principal: `easeOutCubic`.
- Con Reduce Motion, eliminar desplazamiento y conservar únicamente cambios instantáneos o fundidos breves.

## Navegación

- Barra inferior: cuatro secciones. Etiquetas cortas de una sola línea a 10 px
  ("Meditar", "Prácticas", "Canales", "Inspirar"): los nombres completos de las
  secciones (Canalizaciones, Inspiración) no caben en una línea a 4 pestañas y
  aparecen íntegros en cada cabecera.
- Inspiración: control segmentado Vídeos/Recomendaciones.
- Perfil y Guardados: acciones persistentes del encabezado.
- Minirreproductor: sobre la barra inferior cuando existe un contenido cargado.
- El estado activo se identifica por color y forma; nunca solo por color.

## Estados

- **Carga:** esqueletos silenciosos con la geometría final.
- **Vacío:** una frase breve y, si existe recuperación, una sola acción.
- **Error:** problema directo y acción `Reintentar`.
- **Offline:** conservar catálogo local y distinguir disponibilidad descargada.
- **Reproducción:** cargando, listo, reproduciendo, pausado, completado y error.

## Referencias Gstack

- [Tablero comparativo](http://127.0.0.1:64772/boards/b-20260620-085731-ybgkf6/)
- Artefactos locales: `~/.gstack/projects/FreeExperience/designs/design-system-20260620/`

## Decisiones

| Fecha | Decisión | Razón |
|---|---|---|
| 2026-06-20 | Conservar A, B y C durante beta interna | Permitir que el equipo compare en dispositivo antes de fijar la identidad final. |
| 2026-06-20 | Prohibir texto tutorial y emojis | Mantener una experiencia adulta, directa y serena. |

