# Plan — Gstack Wizard (capa visual con ventana de escritorio)

> **Objetivo en una frase:** convertir Gstack en una experiencia tipo *Wizard*. Al
> invocarlo, abre una **ventana de escritorio** por pasos que (1) pregunta qué
> quieres hacer y en qué carpeta, (2) muestra **auto-descubierto** todo lo que
> Gstack ofrece como seleccionables, (3) te enseña un **resumen y pide
> confirmación**, y (4) ejecuta las skills elegidas reutilizando el motor que
> Gstack ya tiene.

**Decisiones ya tomadas contigo (20-jun-2026):**

| Decisión | Elegido |
|---|---|
| Superficie | **Ventana de navegador estilo Chrome** (modo app, sin barras) |
| Acción final | **Mostrar resumen y confirmar** antes de ejecutar |
| Catálogo del Paso 2 | **Auto-descubierto** de las skills instaladas |

---

## 1. Antes de nada: la realidad técnica (sin adornos)

Quiero separar, como pediste, lo que es **un hecho técnico**, lo que es **seguro
hacer** y lo que es **mi opinión práctica**, porque aquí hay una restricción que
condiciona todo el diseño.

**Hecho técnico.** Cuando me invocas desde el chat, mi shell corre en un entorno
Linux aislado (sandbox). Ese sandbox **no puede abrir una ventana en tu escritorio
de Windows**: no tiene acceso a tu sesión gráfica. Por tanto, "lanzar un pop-up
nativo directamente desde el turno del chat" no es posible tal cual.

**Lo que sí es real y robusto.** Gstack ya es una herramienta que vive en *tu*
máquina (Bun + un servidor local + un PTY que arranca sesiones de `claude`). La
forma sólida de tener la ventana es: un **proceso local en tu Windows**
(arrancado por un comando/acceso directo de Gstack) que sirve la UI del wizard y
la abre en una **ventana de navegador estilo Chrome en modo app** (sin barra de
direcciones ni pestañas). "Desde el chat" se traduce en: una *skill*
(`/gstack-wizard`) que prepara y dispara ese lanzamiento; el render gráfico ocurre
en el proceso local de Windows, no en mi sandbox.

**Mi opinión práctica.** Esto no es un parche: es la arquitectura correcta y la
más mantenible, y además encaja con cómo Gstack ya funciona (servidor local + PTY
de `claude`). Una app de escritorio empaquetada (estilo Electron) sería más
trabajo, más peso y peor mantenimiento, sin ganar nada relevante frente a una
**ventana de navegador en modo app** (Chrome/Edge sin barras, que en Windows ya
está instalado) servida por el propio Gstack. Se ve y se siente como una
aplicación, abre al instante y el coste de mantenimiento es mínimo. Esta es,
además, la opción que has elegido.

---

## 2. Qué construimos (visión)

Una nueva capacidad de Gstack, el **Wizard**, compuesta por cuatro piezas:

1. **Lanzador** — una skill `/gstack-wizard` + un binario `bin/gstack-wizard` +
   `bun run wizard`. Cualquiera de los tres arranca la ventana.
2. **Ventana de navegador estilo Chrome** — Chrome/Edge en modo `--app` (sin
   barra de direcciones ni pestañas, icono propio), apuntando al servidor local
   de Gstack. Aspecto de aplicación, pero es el navegador que ya tienes.
3. **UI por pasos (el wizard en sí)** — HTML/JS servido por el servidor de Gstack,
   con los 3 pasos: tipo de trabajo + carpeta → selección de capacidades →
   resumen y confirmación.
4. **Motor de ejecución** — al confirmar, reutiliza el **PTY de `claude`** que
   Gstack ya tiene para lanzar las skills elegidas en cadena, con la salida en
   vivo dentro de la ventana.

La clave de que esto sea realista y barato de mantener: **no inventamos casi
nada**. Reutilizamos cuatro cosas que ya existen en el repo.

| Necesidad del Wizard | Pieza de Gstack que ya existe | Dónde |
|---|---|---|
| Servir UI + endpoints | Servidor HTTP/SSE | `browse/src/server.ts` (3.170 líneas) |
| Ejecutar `claude` y ver salida en vivo | PTY terminal-agent + WebSocket/SSE | `browse/src/terminal-agent.ts`, `terminal-agent-control.ts` |
| Terminal embebido en la UI | xterm vendorizado | `extension/lib/xterm.js` (script `vendor:xterm`) |
| Leer y entender skills | Parser de SKILL.md + health check | `test/helpers/skill-parser.ts`, `scripts/skill-check.ts` |
| Convenciones de binarios/lanzadores | `bin/gstack-*` (decenas ya) | `bin/` |

---

## 3. Flujo del Wizard (lo que ve el usuario)

**Paso 0 — Lanzamiento.** Escribes `/gstack-wizard` en el chat (o ejecutas
`bun run wizard` / el acceso directo). Se abre la ventana de escritorio.

**Paso 1 — ¿Qué quieres hacer?**
Dos tarjetas grandes y un selector de carpeta:

- **Proyecto desde 0** — empezar algo nuevo.
- **Revisar un proyecto** — auditar/mejorar algo existente.
- **Carpeta del proyecto** — selector nativo. En modo app de Chrome/Edge usamos
  `showDirectoryPicker()` (File System Access API), que abre el diálogo de
  carpetas de Windows sin dependencias extra.

**Paso 2 — Selecciona el potencial de Gstack (auto-descubierto).**
La ventana lista, agrupadas y como *checkboxes*, las capacidades reales
instaladas. Los grupos se derivan de las propias skills (ver §4). Según lo elegido
en el Paso 1, el orden y los valores por defecto cambian:

- *Proyecto desde 0* prioriza: **Planificación** (`/office-hours`,
  `/plan-ceo-review`, `/plan-eng-review`, `/autoplan`), **Diseño**
  (`/design-consultation`, `/design-shotgun`), **Spec** (`/spec`), etc.
- *Revisar un proyecto* prioriza: **Calidad** (`/review`, `/qa`, `/qa-only`),
  **Debug** (`/investigate`), **Seguridad** (`/cso`), **Diseño/QA visual**
  (`/design-review`), **Retro** (`/retro`), etc.

Cada opción muestra su nombre legible y una descripción de una línea (sacada del
frontmatter de la skill), para que el usuario entienda qué hace sin saberse el
comando.

**Paso 3 — Resumen y confirmación.**
Antes de ejecutar nada, una pantalla muestra: tipo de trabajo, carpeta, y la
**lista ordenada de skills** que se van a ejecutar (la "receta"). Botones:
**Confirmar y ejecutar** / **Volver a editar**. Nada se lanza sin tu OK (tu
decisión nº 2).

**Paso 4 — Ejecución en vivo.**
Al confirmar, la ventana muestra un terminal embebido (xterm) donde Gstack lanza
una sesión de `claude` en la carpeta elegida y le va pasando los comandos
seleccionados en orden. Ves el progreso real, igual que en el sidebar actual de
Gstack.

---

## 4. Auto-descubrimiento de capacidades (Paso 2)

Para que el catálogo esté **siempre actualizado** sin mantenerlo a mano (tu
decisión nº 3), el Wizard lee las skills reales en tiempo de arranque:

1. **Fuentes:** los directorios de skills de nivel superior del repo (hay ~70:
   `office-hours/`, `review/`, `investigate/`, `cso/`, etc.) y/o las instaladas
   en `~/.claude/skills/`. Cada una tiene su `SKILL.md` con frontmatter
   (`name`, `description`).
2. **Parseo:** un módulo nuevo `wizard/skill-catalog.ts` reaprovecha la lógica de
   lectura de frontmatter que ya hay en `test/helpers/skill-parser.ts` /
   `scripts/skill-check.ts`. Extrae `name`, `description` y deriva el grupo.
3. **Agrupación:** se usa un mapa **declarativo y pequeño** (categoría → skills)
   en `wizard/categories.ts`. Esto NO es "lista curada a mano" del catálogo —
   las skills se descubren solas; el mapa solo decide **en qué pestaña/grupo**
   cae cada una y el orden por defecto. Cualquier skill nueva no mapeada cae en un
   grupo "Otros" automáticamente, así nunca desaparece del wizard.
4. **Filtros:** se ocultan skills de contribuidor/internas (las de `contrib/`,
   utilidades, etc.) para no abrumar.

Resultado: añadir una skill nueva a Gstack la hace aparecer en el Wizard sin tocar
la UI. El único mantenimiento opcional es ubicarla en un grupo bonito.

---

## 5. Ejecución al confirmar (Paso 4 en detalle)

El Wizard **no reimplementa** la ejecución de skills: compone una "receta" y se la
entrega al motor que Gstack ya usa.

1. La UI envía al servidor la receta: `{ mode, folder, steps: ["/office-hours",
   "/plan-ceo-review", ...] }`.
2. El servidor valida la receta contra el catálogo descubierto (lista blanca: solo
   se ejecutan slash-commands que existen como skill — importante por seguridad).
3. Se arranca/reutiliza el **PTY de `claude`** (`terminal-agent.ts`) con `cwd` en
   la carpeta elegida.
4. Se inyectan los comandos en orden vía el canal que ya existe
   (`window.gstackInjectToTerminal` / endpoint del PTY), esperando a que cada
   skill termine antes de lanzar la siguiente.
5. La salida se transmite a la ventana por el WebSocket/SSE existente (auth por
   `Sec-WebSocket-Protocol`, ya implementada).

Esto es exactamente el patrón que el sidebar de Gstack ya usa hoy, así que el
riesgo técnico es bajo.

---

## 6. Cómo se lanza "desde el chat"

Tres caminos, mismo destino (la ventana):

- **Skill `/gstack-wizard`** (la vía "desde el chat"). Su `SKILL.md` instruye:
  detectar SO, arrancar el servidor local si no corre, y abrir la ventana en modo
  app. Si está en mi sandbox (no puede abrir GUI), responde con el comando exacto
  para que lo lances tú en un clic, y explica por qué (la restricción de §1).
- **Binario `bin/gstack-wizard`** — arranca servidor + ventana. Para doble-clic /
  acceso directo en el escritorio.
- **`bun run wizard`** — para desarrollo.

**La ventana, en concreto.** Ventana de navegador estilo Chrome en modo app:

```
chrome --app=http://127.0.0.1:<port>/wizard  --window-size=960,720
# fallback: msedge --app=...   (Edge ya viene en todo Windows 10/11)
```

Sin barra de direcciones ni pestañas: parece una app, pero es el navegador que ya
tienes (cero instalación, cero empaquetado). Icono propio vía `--app` + manifest.
Se detecta el navegador disponible (Chrome → Edge → Chromium) y se elige el
primero que exista. Nada de toolchains nativos ni Electron: la filosofía de Gstack
es preferir lo ligero (*search before building*).

---

## 7. Arquitectura (mapa de archivos nuevos)

```
gstack/
├── wizard/
│   ├── SKILL.md.tmpl          # la skill /gstack-wizard (se genera el .md)
│   ├── skill-catalog.ts       # descubre y parsea skills instaladas
│   ├── categories.ts          # mapa declarativo grupo→skills (+ "Otros" auto)
│   ├── recipe.ts              # tipos + validación de la "receta" (lista blanca)
│   └── ui/
│       ├── index.html         # las 3 pantallas del wizard
│       ├── wizard.js          # estado de pasos, fetch de catálogo, render
│       └── wizard.css         # estilo app
├── bin/gstack-wizard          # lanzador (servidor + ventana modo app)
└── browse/src/server.ts       # +endpoints: GET /wizard, GET /wizard/catalog,
                               #             POST /wizard/run
```

Endpoints nuevos en el servidor (siguiendo las reglas del repo: pasar por el
helper SSE `createSseEndpoint`, sanitizar egress con `sanitizeLoneSurrogates`,
no exponer tokens en `/health`):

- `GET /wizard` → sirve la UI.
- `GET /wizard/catalog` → JSON con grupos y skills descubiertas.
- `POST /wizard/run` → recibe la receta validada, dispara el PTY.
- Reutiliza el stream del terminal-agent para la salida en vivo.

---

## 8. Plan de implementación por fases

Cada fase es **enviable** (shippable) por sí sola y deja algo funcionando.

**Fase 0 — Andamiaje y catálogo (sin UI).**
`wizard/skill-catalog.ts` + `categories.ts`. Comando de prueba que imprime el
catálogo agrupado. Tests unitarios del parser. *Entregable:* Gstack ya "sabe"
listarse a sí mismo.

**Fase 1 — Servidor: endpoints del wizard.**
`GET /wizard`, `GET /wizard/catalog` en `server.ts`, respetando helpers SSE y
sanitización. *Entregable:* abres `http://127.0.0.1:<port>/wizard/catalog` y ves
el JSON.

**Fase 2 — UI de los 3 pasos (sin ejecutar).**
`wizard/ui/*`. Paso 1 (tipo + carpeta con `showDirectoryPicker`), Paso 2
(checkboxes desde el catálogo), Paso 3 (resumen + confirmar, que de momento solo
muestra la receta). *Entregable:* el wizard navega entero, falta ejecutar.

**Fase 3 — Ventana de navegador estilo Chrome.**
`bin/gstack-wizard` + `bun run wizard`: arranca servidor y abre Chrome/Edge en
modo app (detección de navegador disponible y fallback). *Entregable:* la ventana
tipo app se abre en Windows.

**Fase 4 — Ejecución vía PTY.**
`POST /wizard/run` + `recipe.ts` (validación lista blanca) + inyección secuencial
en el PTY + salida en vivo (xterm) en el Paso 4. *Entregable:* wizard completo de
punta a punta.

**Fase 5 — Skill `/gstack-wizard` + pulido.**
`wizard/SKILL.md.tmpl`, `bun run gen:skill-docs`, routing en CLAUDE.md, icono,
estados de error, y la nota honesta cuando se invoca desde un entorno sin GUI.
Tests E2E del flujo. *Entregable:* "desde el chat" funciona.

### Estimación de esfuerzo

Siguiendo la convención del repo (equipo humano vs. CC+Gstack):

| Fase | Equipo humano | CC+Gstack | Compresión |
|---|---|---|---|
| 0 Catálogo | 1 día | 20 min | ~30x |
| 1 Endpoints | 0,5 día | 15 min | ~20x |
| 2 UI 3 pasos | 2 días | 40 min | ~40x |
| 3 Ventana | 1 día | 30 min | ~30x |
| 4 Ejecución PTY | 2 días | 45 min | ~25x |
| 5 Skill + pulido | 1 día | 30 min | ~20x |
| **Total** | **~7,5 días** | **~3 h** | **~25x** |

---

## 9. Riesgos y decisiones abiertas

**Seguridad (importante: el Wizard ejecuta comandos).** Gstack tiene una postura
de seguridad fuerte (guardas anti-inyección, redacción, allowlists). El Wizard
debe encajar ahí: `POST /wizard/run` solo acepta slash-commands que existan en el
catálogo descubierto (lista blanca), nunca texto arbitrario; el endpoint vive en
el listener **local** (127.0.0.1), nunca en el túnel; y no se expone ningún token
en `/health`. Esto hay que respetarlo o romperá los tripwires de CI del repo.

**Windows y los symlinks de setup.** El repo tiene reglas específicas para Windows
(el helper `_link_or_copy` en `setup`, copia en vez de symlink sin Developer
Mode). El binario `gstack-wizard` debe seguir esas reglas para no quedar "congelado".

**Selector de carpeta.** `showDirectoryPicker()` requiere Chrome/Edge moderno
(lo hay en todo Windows 10/11). El modo app cubre el caso sin dependencias extra.

**"Desde el chat" en mi sandbox.** Repito la honestidad de §1: si me lo pides en
una sesión cuyo shell es Linux aislado, no abro yo la ventana; te doy el comando
exacto en un clic. La experiencia "100% automática desde el chat" depende de que
el lanzador corra en tu Windows (acceso directo o `/gstack-wizard` ejecutándose
en tu entorno local de Gstack, no en el sandbox).

**Convivencia con sesiones concurrentes.** El PTY de Gstack ya gestiona identidad
por sesión (kill por record, no `pkill`); el Wizard reusa ese mecanismo para no
matar sesiones hermanas.

---

## 10. Tests (encaja con los tiers del repo)

- **Tier 1 (free, `bun test`):** parser de catálogo, validación de receta
  (lista blanca rechaza comandos inventados), generación de `SKILL.md`.
- **Tier 2 (gate, E2E):** flujo del wizard hasta componer la receta; el endpoint
  `/wizard/run` con un comando falso devuelve 4xx (guardrail de seguridad → gate).
- **Tier 3 (periódico):** ejecución real de una receta mínima vía PTY (no
  determinista → periodic).

---

## 11. Siguiente paso

Si el plan te encaja, propongo arrancar por la **Fase 0 + Fase 1** (catálogo +
endpoints): es el cimiento, sin UI, y demuestra rápido que Gstack puede "listarse
a sí mismo" para alimentar el wizard. Con eso verde, seguimos con la UI y la
ventana.

Una pregunta abierta menor para cuando empecemos: ¿quieres que el catálogo lea las
skills **del repo** (las ~70 carpetas de este proyecto) o las **instaladas en
`~/.claude/skills/`** del usuario? Recomiendo las instaladas, porque es lo que el
usuario realmente puede ejecutar; lo confirmamos al implementar la Fase 0.
