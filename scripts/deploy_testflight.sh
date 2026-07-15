#!/usr/bin/env bash
# Sube un build a TestFlight desde el Mac, alternativa local al CI de GitHub.
#
# Firma con el certificado de distribución instalado en el llavero (equipo
# P92L2CBRM2). El proyecto queda en firma manual para el CI, así que este script
# lo pasa a automático SOLO durante el build y lo restaura al terminar.
#
# Requisitos (configurados 2026-07-16):
#   - Certificado "iPhone/Apple Distribution (P92L2CBRM2)" en el llavero.
#   - .env con SUPABASE_URL y SUPABASE_Publishable_Key.
#   - Clave API ASC en ~/.appstoreconnect/private_keys/AuthKey_7Y3F6VFK7T.p8
#
# El número de build sale de pubspec.yaml (version: x.y.z+BUILD). Súbelo antes:
#   sed -i '' 's/^version: 1.0.0+N/version: 1.0.0+N+1/' pubspec.yaml
set -euo pipefail
cd "$(dirname "$0")/.."

KEY_ID="7Y3F6VFK7T"
ISSUER="9661d3a6-5f6b-4814-9431-07134d834a31"
PBX="ios/Runner.xcodeproj/project.pbxproj"
PBX_BAK="${TMPDIR:-/tmp}/pbxproj.deploy.bak"

# tr -d '\r': el .env puede tener finales de línea CRLF; un \r en la URL rompe
# el build de Dart.
SUPA_URL=$(grep -E "^SUPABASE_URL=" .env | cut -d= -f2- | tr -d '"\r')
SUPA_KEY=$(grep -E "^SUPABASE_Publishable_Key=" .env | cut -d= -f2- | tr -d '"\r')
if [ -z "$SUPA_URL" ] || [ -z "$SUPA_KEY" ]; then
  echo "ERROR: faltan SUPABASE_URL o SUPABASE_Publishable_Key en .env" >&2
  exit 1
fi

restore_pbx() { [ -f "$PBX_BAK" ] && cp "$PBX_BAK" "$PBX" && rm -f "$PBX_BAK"; }
trap restore_pbx EXIT

echo "==> pub get + codegen"
flutter pub get
dart run build_runner build --delete-conflicting-outputs

echo "==> firma automática temporal (se restaura al salir)"
cp "$PBX" "$PBX_BAK"
sed -i '' 's/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/' "$PBX"
sed -i '' '/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "Apple Distribution";/d' "$PBX"
sed -i '' '/PROVISIONING_PROFILE_SPECIFIER = "Free Experience AppStore";/d' "$PBX"

echo "==> build ipa (release, dart-defines de beta)"
flutter build ipa \
  --release \
  --export-options-plist=ios/ExportOptions.local.plist \
  --dart-define=APP_ENV=beta \
  --dart-define=SUPABASE_URL="$SUPA_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPA_KEY"

restore_pbx
trap - EXIT

IPA=$(find build/ios/ipa -maxdepth 1 -name "*.ipa" | head -1)
[ -n "$IPA" ] || { echo "ERROR: no se generó el .ipa" >&2; exit 1; }

echo "==> subiendo $IPA a App Store Connect"
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$KEY_ID" --apiIssuer "$ISSUER" \
  --private-key "$HOME/.appstoreconnect/private_keys/AuthKey_${KEY_ID}.p8"

echo "OK. Apple procesa el build unos minutos antes de aparecer en TestFlight."
