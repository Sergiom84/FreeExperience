# Flujo editorial de la beta

## Publicar una pieza

1. Sube la portada al bucket público `covers`.
2. Sube audio o vídeo al bucket privado `media` dentro de una carpeta cuyo nombre sea el UUID del contenido.
3. Crea `content_items` con estado `draft`.
4. Crea su fila en `media_assets` con la ruta de Storage.
5. Revisa título, autor, duración, orden y tipo.
6. Cambia el estado a `published`.

La base de datos rechaza una publicación sin portada o sin el medio exigido por su tipo.

## Formatos de beta

- Portada: WebP o JPEG, proporción 4:5, mínimo 1200×1500.
- Audio: M4A/AAC o MP3, estéreo, volumen normalizado.
- Vídeo: MP4 H.264 con `faststart`, máximo 1080p.
- No incrustar títulos ni marcas en las portadas.

## Retirar contenido

Cambia el estado a `archived`. La app lo eliminará del catálogo en la siguiente sincronización y limpiará su descarga local. No borres inmediatamente el registro: conserva integridad para métricas e historial.

## Reglas de contenido

- Sin emojis.
- Sin claims médicos o terapéuticos.
- Confirmar derechos de voz, música, imagen y vídeo.
- Las recomendaciones externas deben usar HTTPS.

