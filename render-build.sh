#!/usr/bin/env bash
set -o errexit

FLUTTER_DIR="$HOME/.flutter-sdk"
FLUTTER_VERSION="3.41.7"

# Check binary specifically — directory may exist but be incomplete after cache corruption
if [ ! -f "$FLUTTER_DIR/bin/flutter" ]; then
  echo "==> Installing Flutter ${FLUTTER_VERSION}..."
  rm -rf "$FLUTTER_DIR"
  ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${ARCHIVE}" \
    -o /tmp/flutter.tar.xz
  mkdir -p "$FLUTTER_DIR"
  tar xf /tmp/flutter.tar.xz --strip-components=1 -C "$FLUTTER_DIR"
  rm /tmp/flutter.tar.xz
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics --no-cli-animations
flutter --version

echo "==> Installing dependencies..."
flutter pub get

echo "==> Building Flutter web (release)..."
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}" \
  --dart-define=APP_ENV=production

echo "==> Done. Output in build/web/"
