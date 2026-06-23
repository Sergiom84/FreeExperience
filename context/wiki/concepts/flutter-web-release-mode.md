# Flutter web en Chrome — release mode (FreeExperience)

**Problema:** La build web en release mode fallaba en Chrome con tres bloqueos distintos antes de llegar a `main()`.

## Bloqueos y soluciones

### 1. `passkeys_web` crashea antes de `main()`
**Fix:** Stub JS en `web/index.html` antes de cargar el bundle:
```html
<script>
  window.PasskeyAuthenticator = { init: function(){} };
</script>
```

### 2. `audio_service` no tiene implementación web
**Fix:** Guard `kIsWeb` en `lib/main.dart` para omitir la inicialización de `AudioService` en plataforma web.

### 3. `drift` necesita configuración específica para web
**Fix:** Usar `DriftWebOptions` con WASM y worker en `lib/core/database/app_database.dart`:
```dart
DriftWebOptions(sqlite3Wasm: ..., driftWorker: ...)
```
Los archivos `web/sqlite3.wasm` y `web/drift_worker.js` deben estar en la raíz de `web/`.

## Nota PowerShell
En PowerShell, el carácter de continuación de línea es el backtick (`` ` ``), no la barra invertida (`\`).
