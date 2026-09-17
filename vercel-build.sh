#!/bin/bash
set -e

echo "=== Vercel Flutter Web Build Hook ==="

if ! command -v flutter &> /dev/null; then
  echo "Flutter not found on PATH. Installing Flutter SDK (stable)..."
  if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$HOME/flutter"
  fi
  export PATH="$HOME/flutter/bin:$PATH"
fi

echo "Flutter version:"
flutter --version

echo "Fetching dependencies..."
flutter pub get

echo "Building release web bundle..."
flutter build web --release

echo "=== Build Complete! Output is in build/web ==="
