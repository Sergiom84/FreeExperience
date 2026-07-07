# Revisión del proyecto — julio 2026

Documento de trabajo para la revisión integral del código, las mejoras propuestas
y el seguimiento de la refactorización. Rama de trabajo: `claude/project-review-refactor-63idr7`.

Estado de cada punto: `[ ]` pendiente · `[~]` en curso · `[x]` hecho · `[-]` descartado.

---

## 1. Valoración general

La base es sólida y coherente con el roadmap: arquitectura local-first con Drift
como fuente de verdad de la UI, Supabase como remoto, Riverpod para inyección y
go_router con guard de sesión. Capas bien separadas (domain / data / features),
interfaces (`ContentRepository`, `SyncService`, `IdentityService`, `DownloadManager`)
que permiten dobles de prueba, cola de sincronización offline con resolución por
`updated_at`, y CI que ejecuta format + analyze + test + pgTAP. Sin TODOs sueltos,
sin secretos privilegiados en el cliente (solo URL + publishable key vía
`--dart-define`), RLS verificada en migraciones.

Las debilidades se concentran en tres frentes:

1. **Errores silenciados**: el patrón `on Object { return; }` aparece en ~20 sitios
   sin registrar nada, con Sentry ya configurado. Depurar producción será a ciegas.
2. **Pantallas-dios**: `admin_wizard_screen` (943 líneas), `welcome_sunset_screen`
   (900), `login_screen` (750), `admin_gate_screen` (677) mezclan UI, estado y
   lógica de negocio.
3. **Cobertura de tests muy baja**: 174 líneas de test para ~9.600 de código.
   Los servicios con más lógica (sync, downloads, coordinator, admin repo) no
   tienen ningún test.

Referencias positivas a imitar: `catalog_screen.dart` (dispatch por dirección con
estados de carga/error correctos) es el patrón que login y bienvenidas deberían
seguir; la seguridad del admin está bien resuelta (RPC `is_admin()` con
SECURITY DEFINER, políticas RLS en todas las escrituras y `grant_admin` en el
esquema `private`, solo accesible con service_role); el test de política de
textos (`test/text_policy_test.dart`) automatiza las reglas de producto.

### Orden de ataque sugerido

1. P0 completo (bugs reproducibles, poco riesgo de regresión).
2. Logging de errores con Sentry (desbloquea depurar todo lo demás).
3. Flujo de introducción + favoritos con sync al repositorio (elimina las dos
   duplicaciones con bugs asociados).
4. Formatters/SeekBar compartidos y `AdminGuard`.
5. Troceo de pantallas-dios y tokens de diseño (requiere decisión del equipo
   sobre las direcciones y las excepciones de DESIGN.md).
6. Tests de servicios.

---

## 2. Hallazgos priorizados

### P0 — Bugs y riesgos reales

- [x] **`AdminWizardScreen` sin guard de admin**: un enlace profundo a
  `/admin/<kind>/nuevo` muestra la UI de autoría completa a cualquier usuario
  (RLS bloquea la escritura, pero la pantalla no debería renderizarse).
  Las otras tres pantallas admin copian el guard a mano; extraer un `AdminGuard`
  y aplicarlo por ruta.
- [x] **`AdminIntroScreen._publish` borra antes de subir**
  (`admin_extras_screen.dart:71-88`): si la subida falla, la app se queda sin
  introducción. Invertir el orden (subir → publicar → borrar la anterior) y mover
  la transacción a `AdminContentRepository`.
- [x] **`pickFile` en web se cuelga si el usuario cancela**
  (`file_pick_web.dart:10-47`): el completer nunca se resuelve. Escuchar el
  evento `cancel` del input.
- [x] **`setState`/`ref` tras `await` sin comprobar `mounted`**:
  `admin_extras_screen.dart:97` (catch sin guard), `admin_gate_screen.dart:79-88`
  (`ref` tras await), `admin_wizard_screen.dart:72-80` (controllers tras await).
- [x] **`Dismissible` sin retirada síncrona de la fila**
  (`admin_gate_screen.dart:430-437`): puede lanzar "dismissed Dismissible still
  part of the tree".
- [x] **Carrera en el preview del wizard** (`admin_wizard_screen.dart:620-678`):
  `didUpdateWidget` reinicializa mientras un `initialize()` anterior sigue en
  vuelo; el controller viejo se instala y el nuevo se fuga. Añadir contador de
  generación.
- [x] **Nombre fijo del fichero de preview** (`admin_preview_url_io.dart:9`):
  dos previews consecutivos con la misma extensión se pisan. Usar nombre único.
- [x] **Las horas se pierden al formatear duración**: `_format` usa
  `inMinutes.remainder(60)`, así que una sesión de 72 min se muestra como
  "12:00". Tres copias privadas (`full_player_screen.dart:267,471`,
  `mini_player.dart:171`). Añadir `formatPlaybackClock` a
  `core/util/formatters.dart` y borrar las copias.
- [x] **`ref` tras reproducir la introducción completa sin guard**
  (`welcome_sunset_screen.dart:194-226`): `_playIntro` espera a que termine el
  audio (minutos) y después usa `ref.read` y `SharedPreferences` sin comprobar
  `mounted`; si el usuario navegó, lanza excepción en el camino feliz.
- [x] **Favorito desde el reproductor no sincroniza**: en
  `content_detail_screen.dart:102-105` y `favorites_screen.dart:84-87` se hace
  `toggleFavorite` + `synchronize()`, pero `full_player_screen.dart:305` solo
  hace el toggle. Mover la orquestación al repositorio (un único
  `toggleFavorite` que programe el sync).
- [x] **Más `setState` tras `await` sin `mounted`**: `login_screen.dart:92`
  (catch de `_submit`), `profile_screen.dart:54-56` (tras el file picker).

### P1 — Robustez y mantenimiento

- [x] **Registrar errores en vez de silenciarlos**: sustituir los `on Object {}`
  mudos por captura con log a Sentry (`Sentry.captureException`) manteniendo la
  degradación suave. Afecta a sync, content repo, admin, perfil y pantallas.
- [x] **`submit` del admin no es atómico ni re-intentable**
  (`admin_content_repository.dart:190-272`): un fallo intermedio deja borradores
  huérfanos y el reintento crea otro. Conservar el id creado y reutilizarlo.
- [x] **`delete` borra storage antes que la fila**
  (`admin_content_repository.dart:166-170`): invertir el orden.
- [x] **Resolución de URL de portada duplicada e inconsistente**
  (wizard `_load` vs `listByKind`): centralizar en un método del repositorio;
  hoy editar un ítem con `cover_path` absoluto o de asset rompe la portada.
- [ ] **Duración de vídeo = 0** (`admin_content_repository.dart:285`): un vídeo
  publicado antes de que el preview termine de inicializar queda con duración 0.
- [x] **Mime map sin `wav`/`aiff`** aunque el picker los permite: se suben como
  `audio/mpeg`.
- [x] **`ProfileRepository.uploadAvatar` termina en `!`**
  (`profile_repository.dart:56`): NPE potencial; devolver error de dominio.
- [x] **`_prepareCover` duplicado** entre `AdminContentRepository` y
  `ProfileRepository`: extraer helper compartido de preparación de imagen.
- [ ] **Subidas con `withData: true`** (`file_pick_io.dart`): un vídeo grande se
  carga entero en RAM. Valorar subida por streaming desde path en IO.
- [x] **Timer de progreso sigue corriendo en pausa**
  (`playback_coordinator.dart:140-145`): persiste cada 10 s aunque no se
  reproduzca nada; cancelarlo al pausar y rearmarlo al reanudar.
- [x] **`isAdminProvider` devuelve `false` ante cualquier error**
  (`admin_controller.dart:17-19`): un fallo de red expulsa al admin al login sin
  opción de reintento.
- [x] **Flujo "introducción escuchada" repartido entre dos pantallas**:
  `welcome_sunset_screen._playIntro` y `login_screen._goAfterAuth` coordinan por
  su cuenta la doble persistencia (SharedPreferences + `profileRepository`), y
  la constante `introSeenPrefKey` vive en un fichero de pantalla que el login
  importa. Extraer a un controlador/repositorio único (`introSeenProvider`).
- [x] **Errores de auth mapeados por substring** (`login_screen.dart:109-120`):
  `_friendlyError` compara contra `e.toString()`; un cambio de mensaje en
  Supabase lo degrada todo a "Algo salió mal". Definir excepciones tipadas en
  `IdentityService`.
- [x] **Redirección post-login de un solo disparo**
  (`login_screen.dart:32-38`): lee `identityProvider` una vez en el post-frame;
  si la sesión se restaura un frame después, el usuario se queda en el login.
  Usar `ref.listen` o el redirect del router.
- [x] **`setState` en cada frame de vídeo**
  (`content_detail_screen.dart:283-285`): el listener del `VideoPlayerController`
  reconstruye toda la sección continuamente solo para el icono play/pausa. Usar
  `ValueListenableBuilder` alrededor del botón.
- [x] **El vídeo subido no coordina con la sesión de audio**
  (`content_detail_screen.dart:266-330`): se reproduce fuera del
  `PlaybackCoordinator`, así que el audio de fondo puede seguir sonando debajo.
- [x] **Estados de error sin `Reintentar`** en `content_detail_screen.dart:34` y
  `favorites_screen.dart:20` (DESIGN.md exige acción de reintento; `CatalogError`
  ya existe y se puede reutilizar).
- [x] **`launchUrl` sin comprobar resultado**
  (`content_detail_screen.dart:236,349`): un fallo al abrir el enlace es mudo.
- [x] **Controller de diálogo liberado antes de tiempo**
  (`profile_screen.dart:420-446`): `_linkEmail` hace `controller.dispose()` al
  volver `showDialog` mientras la transición de salida aún puede construir el
  `TextField`. Mover el controller a un widget con estado propio.
- [ ] **Compartir es un placeholder** (`full_player_screen.dart:100-104`): copia
  el literal "Free Experience" al portapapeles. Cablear datos reales o retirar
  el botón antes de la beta.

### P2 — Refactorización estructural

- [ ] **Trocear `admin_wizard_screen.dart`**: extraer `_AdminMediaPlayer`
  (~320 líneas reutilizables) a su propio fichero y los pasos del wizard a
  `steps/`.
- [ ] **Trocear `admin_gate_screen.dart`**: login, dashboard y listado de sección
  en ficheros separados.
- [ ] **Unificar la barra de progreso del reproductor**: `_ProgressBar`
  (`full_player_screen.dart:403-469`) y `_MiniSeekBar`
  (`mini_player.dart:109-183`) son casi idénticos (~120 líneas duplicadas).
  Extraer un `SeekBar(duration, {compact})`.
- [ ] **Duplicación entre las dos pantallas de bienvenida**: mismo modelo
  `_Section`, misma cabecera (tooltip + perfil), mismo saludo y misma fórmula de
  respiración del sol. Extraer a `widgets/` compartidos. Confirmar además si
  `/bienvenida-orbita` (solo alcanzable escribiendo la URL) sigue en evaluación
  o se puede retirar.
- [ ] **`_InspirationCollection` duplica el cuerpo de `CatalogScreen`**
  (`inspiration_screen.dart:55-80`): extraer un `ContentKindList(kind)` común.
  La línea de metadatos con " · " está escrita tres veces
  (catalog:364, detail:62, favorites:70): extraer `MetadataLine(item)`.
- [ ] **El esqueleto de catálogo re-codifica la geometría a mano**
  (`catalog_screen.dart:407-463`): duplica aspect ratios y alturas de los
  widgets reales y no coincide con las filas (72 vs 82 px). Compartir constantes
  o exponer `skeleton()` por variante.
- [ ] **Login y bienvenidas fuera del sistema de diseño**: `login_screen` usa
  fuentes de Google directas y ~20 colores literales (una "cuarta dirección" de
  facto), `welcome_sunset_screen` ~40 colores fijos, y el dashboard admin tiene
  hex propios (`admin_gate_screen.dart:270-290`). Migrar a tokens o registrarlos
  como excepciones aprobadas en DESIGN.md.
- [ ] **Paleta y tokens duplicados en `core/design/`**: los colores de focus y
  superficie están definidos dos veces (`app_theme.dart` y `design_tokens.dart`);
  no existen tokens de espaciado ni de duración pese a que DESIGN.md los define,
  y por eso las pantallas inventan valores (10/14/18/22/25). Crear un
  `DirectionPalette` único y `AppTokens.space*`/`motion*`.
- [ ] **Efectos secundarios en `build`**: `_startMotion(reduceMotion)` se llama
  desde `build` en ambas bienvenidas; un cambio de reduce-motion en caliente no
  detiene los timers de cometas/frases. Mover a `initState`/`didChangeDependencies`.
  Los cometas además reconstruyen la pantalla entera cada 2-6 s
  (`welcome_sunset_screen.dart:117-144`): aislarlos en una capa propia.
- [ ] **`app_shell.dart:20-27`**: el override local de `NavigationBarTheme`
  pisa el `labelTextStyle` global y pierde el estilo del estado seleccionado.
- [ ] **`ColorScheme` incompleto** (`app_theme.dart:104-114`): solo 8 roles;
  `outline`, `surfaceContainer`, etc. caen en defaults de Material que no casan
  con las paletas.
- [ ] **Tests**: añadir cobertura para `SupabaseSyncService` (push/pull/merge),
  `LocalDownloadManager` (resolve/fallos), `PlaybackCoordinator` (cola/progreso)
  y `AdminContentRepository.submit` con mocks.

### P3 — Textos y reglas de producto

- [ ] "Arrastra alrededor del sol o toca un nombre para entrar."
  (`welcome_screen.dart:246`) y "Dale al play" (`welcome_sunset_screen.dart:422`)
  son textos tutoriales que las reglas prohíben.
- [ ] Revisar "Respira. Entra. Conecta." (`login_screen.dart:312`) y
  "Respira. Ya estás aquí." (`welcome_screen.dart:47`) frente a la regla de
  afirmaciones terapéuticas; el aforismo además está hardcodeado en el widget en
  vez de venir del catálogo.
- [ ] El snackbar "No hay una introducción publicada en Extras."
  (`welcome_sunset_screen.dart:179`) filtra vocabulario de administración al
  usuario final.
- [ ] Diálogo de "Eliminar cuenta" sin cuerpo (`profile_screen.dart:395-410`):
  una acción irreversible merece una línea de consecuencias (es información de
  estado, no texto tutorial).
- [ ] Estados de carga enmascarados como datos (`profile_screen.dart:16-18`):
  mientras la identidad carga se muestra "Modo local". Usar `.when`/esqueletos.

---

## 3. Anotaciones

- 2026-07-07 — Revisión inicial del núcleo completada (datos, sync, player,
  identidad, router, entorno, CI). Informes de UI y admin generados con agentes.
- 2026-07-07 — En este entorno no hay SDK de Flutter, así que `dart format`,
  `flutter analyze` y `flutter test` no se pudieron ejecutar localmente; la CI
  de GitHub los cubre en cada push/PR.
- 2026-07-07 — P0 aplicado. Notas de implementación:
  - `AdminGuard` nuevo en `lib/features/admin/admin_guard.dart`, aplicado en el
    router a todas las rutas `/admin/**`; los guards copiados en las pantallas
    se retiraron. Cubre también el estado de carga (antes `.value ?? false`
    mostraba la puerta de login durante la comprobación).
  - `formatPlaybackClock`/`formatPlaybackRemaining` en `core/util/formatters.dart`
    sustituyen a las cuatro copias privadas (full player ×2, mini player,
    wizard admin). Ahora las duraciones de más de una hora se muestran bien.
  - `toggleFavorite` en `DriftContentRepository` programa el `synchronize()`;
    los botones de detalle y guardados ya no lo llaman a mano y el del
    reproductor sincroniza por primera vez.
  - Bienvenida: además de los arreglos de `ref`/`mounted`, se añadió la cuenta
    atrás con el tiempo restante del audio dentro del sol mientras se reproduce
    la introducción, derivada del mismo `AnimationController` que dibuja el
    anillo (texto y arco avanzan a la par). El anillo no se tocó.
  - Publicar introducción ahora sube y publica la nueva antes de borrar la
    anterior; si el borrado antiguo falla, la bienvenida sigue priorizando la
    más reciente.
  - El preview del wizard usa contador de generación (evita que un archivo
    anterior "gane" al nuevo) y ficheros temporales con nombre único en IO.
- 2026-07-07 — P1 aplicado. Notas de implementación:
  - `reportError` en `core/util/app_log.dart`: consola en desarrollo y
    `Sentry.captureException` cuando hay DSN. Aplicado a los ~18 catches que
    antes tragaban el error (sync, catálogo, admin, perfil, bienvenida,
    detalle, arranque de audio). La degradación suave se mantiene igual.
  - `AdminContentRepository.createDraft` separado de `submit`: el wizard
    conserva el id (`_createdId`) y los reintentos reutilizan el mismo
    borrador. `delete` borra la fila antes que el storage.
  - `resolveCoverUrl` centraliza portadas (http absoluto vs ruta de storage)
    para listado y editor.
  - `prepareImage` compartido en `core/util/image_prep.dart` (portadas 1600,
    avatar 512). `uploadAvatar` rechaza formatos no decodificables en vez de
    subirlos etiquetados como JPEG, y ya no revienta con `!`.
  - Mime map con `wav`/`aiff`/`aif`.
  - `isAdminProvider` propaga errores; `AdminCheckErrorScreen` (en
    `admin_guard.dart`) ofrece Reintentar en vez de expulsar al login.
  - `IntroSeenStore` (`features/profile/intro_seen_store.dart`) unifica el
    flag local + remoto; login y bienvenida lo consumen. `introSeenPrefKey`
    dejó de exportarse desde una pantalla.
  - Errores de auth tipados (`IdentityException` con `IdentityErrorCode`
    mapeado desde los códigos de Supabase); el login ya no compara substrings.
  - Login con `ref.listenManual(identityProvider)` en vez de lectura única
    post-frame (la restauración tardía de sesión ya no deja al usuario
    atascado en el login).
  - Timer de progreso: se detiene al pausar y se rearma al reanudar.
  - Detalle: error con Reintentar (reutiliza `CatalogError`), botón de vídeo
    con `ValueListenableBuilder` (adiós al setState por frame), el vídeo
    subido pausa el audio de fondo al empezar, y `launchUrl` avisa si falla.
    Guardados: error con Reintentar. Perfil: el diálogo de vincular email es
    dueño de su controller.
  - Test nuevo `test/formatters_test.dart` para el reloj de reproducción.
  - Verificado en local con Flutter 3.41.6: `dart format`, `flutter analyze`
    (sin avisos) y `flutter test` (todo en verde).
- 2026-07-07 — Pendientes que requieren decisión de equipo o pruebas en
  dispositivo (no bloquean el merge): duración de vídeo = 0 si se publica
  antes de que el preview la detecte, subida por streaming para vídeos
  grandes (`withData: true`), botón compartir del reproductor (placeholder),
  troceo de pantallas grandes, tokens de espaciado/paleta única, textos P3 y
  tests de servicios.

## 4. Progreso

| Fecha | Cambio | Estado |
| --- | --- | --- |
| 2026-07-07 | Creación del documento y revisión inicial | Hecho |
| 2026-07-07 | Correcciones P0 (11 puntos) + cuenta atrás en la bienvenida | Hecho |
| 2026-07-07 | Correcciones P1 (16 puntos) + test de formatters | Hecho |
| 2026-07-07 | Merge a `main` | Hecho |
