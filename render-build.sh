#!/usr/bin/env bash
set -o errexit

FLUTTER_DIR="$HOME/.flutter-sdk"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "==> Installing Flutter (stable)..."
  git clone https://github.com/flutter/flutter.git \
    --branch stable \
    --depth 1 \
    "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --no-analytics --no-cli-animations
flutter --version

echo "==> Installing dependencies..."
flutter pub get

echo "==> Building Flutter web (release)..."
flutter build web --release --web-renderer canvaskit

echo "==> Done. Output in build/web/"
