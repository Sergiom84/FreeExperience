#!/usr/bin/env bash
# Compila el .aab de Android con las credenciales de Supabase y opcionalmente
# lo sube a Play mediante scripts/publish_play.py.
#
# Sin este script, `flutter build appbundle --release` a mano se olvida
# fácilmente de los --dart-define y el .aab resultante arranca en modo
# catálogo local (sin Supabase configurado): la app abre bien pero el
# registro/login falla con "Algo salió mal".
#
# Requisitos:
#   - .env con SUPABASE_URL y SUPABASE_Publishable_Key.
#   - android/key.properties + upload-keystore.jks para la firma de release.
#   - .env con SENTRY_DSN (opcional; sin ella el build sale sin captura de
#     errores en Sentry, degradación silenciosa a solo consola).
#
# Uso:
#   scripts/deploy_play.sh              # solo compila el .aab
#   scripts/deploy_play.sh --publish     # compila y sube a la pista interna
#   scripts/deploy_play.sh --publish --track beta --notes "Texto"
set -euo pipefail
cd "$(dirname "$0")/.."

PUBLISH=0
TRACK="internal"
NOTES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --publish) PUBLISH=1; shift ;;
    --track) TRACK="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

# tr -d '\r': el .env puede tener finales de línea CRLF; un \r en la URL rompe
# el build de Dart.
SUPA_URL=$(grep -E "^SUPABASE_URL=" .env | cut -d= -f2- | tr -d '"\r')
SUPA_KEY=$(grep -E "^SUPABASE_Publishable_Key=" .env | cut -d= -f2- | tr -d '"\r')
if [ -z "$SUPA_URL" ] || [ -z "$SUPA_KEY" ]; then
  echo "ERROR: faltan SUPABASE_URL o SUPABASE_Publishable_Key en .env" >&2
  exit 1
fi

SENTRY_DSN=$(grep -E "^SENTRY_DSN=" .env | cut -d= -f2- | tr -d '"\r')
if [ -z "$SENTRY_DSN" ]; then
  echo "AVISO: SENTRY_DSN no está en .env; el build saldrá sin captura de errores." >&2
fi

if [ ! -f android/key.properties ]; then
  echo "ERROR: falta android/key.properties (firma de release)" >&2
  exit 1
fi

FLUTTER=flutter
DART=dart
if ! flutter --version >/dev/null 2>&1 && command -v puro >/dev/null 2>&1; then
  FLUTTER="puro -e stable flutter"
  DART="puro -e stable dart"
fi

echo "==> pub get + codegen"
$FLUTTER pub get
$DART run build_runner build --delete-conflicting-outputs

echo "==> build appbundle (release, dart-defines de producción)"
$FLUTTER build appbundle \
  --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL="$SUPA_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPA_KEY" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN"

AAB="build/app/outputs/bundle/release/app-release.aab"
[ -f "$AAB" ] || { echo "ERROR: no se generó el .aab" >&2; exit 1; }
echo "OK. .aab generado en $AAB"

if [ "$PUBLISH" -eq 1 ]; then
  echo "==> subiendo a Play (pista: $TRACK)"
  # `python` en PATH puede resolver a una instalación sin google-api-python-client
  # (varias versiones de Python conviven en esta máquina); usar la que tiene
  # las dependencias instaladas.
  PYTHON=python
  if ! python -c "import google.oauth2" >/dev/null 2>&1; then
    for candidate in \
      "/c/Users/sergi/AppData/Local/Programs/Python/Python310/python.exe" \
      "/c/Users/sergi/AppData/Local/Programs/Python/Python313/python.exe"; do
      if "$candidate" -c "import google.oauth2" >/dev/null 2>&1; then
        PYTHON="$candidate"
        break
      fi
    done
  fi
  ARGS=(--track "$TRACK" --aab "$AAB")
  [ -n "$NOTES" ] && ARGS+=(--notes "$NOTES")
  "$PYTHON" scripts/publish_play.py "${ARGS[@]}"
fi
