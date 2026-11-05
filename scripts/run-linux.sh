#!/usr/bin/env bash
# Start the local eNet API and Flutter desktop app together on Ubuntu.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 22.16+ is required. Install Node and retry." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required. Install Flutter and retry." >&2
  exit 1
fi

cd "$ROOT"
flutter config --enable-linux-desktop
if [ ! -f "$ROOT/linux/CMakeLists.txt" ]; then
  flutter create --platforms=linux .
fi
flutter pub get

API_PID=""
cleanup() {
  if [ -n "$API_PID" ]; then
    kill "$API_PID" 2>/dev/null || true
    wait "$API_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if command -v curl >/dev/null 2>&1 && curl -fsS http://127.0.0.1:8787/ready >/dev/null 2>&1; then
  echo "Using existing eNet API on localhost:8787"
else
  ( cd "$ROOT/api" && exec node src/server.mjs ) &
  API_PID=$!
  echo "Started local eNet API (PID $API_PID)"
fi

flutter run -d linux --dart-define=ENET_API_URL=http://127.0.0.1:8787
