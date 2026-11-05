#!/usr/bin/env bash
# Build/run eNet on iOS. Physical devices must use a reachable HTTPS API.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS development requires macOS with Xcode installed." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required." >&2
  exit 1
fi

API_URL="${ENET_API_URL:-}"
if [[ -z "$API_URL" ]]; then
  echo "Set ENET_API_URL to your reachable HTTPS API before running on iPhone." >&2
  echo "For the iOS Simulator only, http://127.0.0.1:8787 is also allowed." >&2
  exit 1
fi
case "$API_URL" in
  https://*) ;;
  http://127.0.0.1:*|http://localhost:*) ;;
  *)
    echo "Remote API connections must use HTTPS. Only localhost may use HTTP." >&2
    exit 1
    ;;
esac

cd "$ROOT"
flutter create --platforms=ios .
flutter pub get
flutter run -d ios --dart-define="ENET_API_URL=$API_URL"
