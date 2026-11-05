#!/usr/bin/env bash
# Run eNet APP on an iOS simulator/device against a remote HTTPS API.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS builds and simulator runs require macOS with Xcode." >&2
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK is required. Install Flutter and retry." >&2
  exit 1
fi
if [[ -z "${ENET_API_URL:-}" ]]; then
  echo "Set ENET_API_URL to the public HTTPS address of your deployed eNet API." >&2
  echo "Example: export ENET_API_URL=https://api.your-domain.example" >&2
  exit 1
fi
if [[ ! "$ENET_API_URL" =~ ^https:// ]]; then
  echo "A public iOS API endpoint must use HTTPS." >&2
  exit 1
fi

cd "$ROOT"
if [[ ! -f "$ROOT/ios/Runner.xcodeproj/project.pbxproj" ]]; then
  flutter create --platforms=ios .
fi
flutter pub get
flutter run -d ios --dart-define="ENET_API_URL=$ENET_API_URL"
