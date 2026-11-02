#!/usr/bin/env bash
# Exports the Godot client as a Meta Quest APK: Release/BalatroInVR-Quest.apk. Add --install for adb.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d client/addons/godotopenxrvendors ] || { echo "run quest/fetch_deps.sh first" >&2; exit 1; }

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${BALATRO_VR_KEYSTORE:-$HOME/.local/share/godot/keystores/debug.keystore}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android

mkdir -p Release
rm -rf client/android
godot --headless --xr-mode off --path client --import
godot --headless --xr-mode off --path client --install-android-build-template --export-release "Meta Quest" ../Release/BalatroInVR-Quest.apk

if [ "${1:-}" = "--install" ]; then
    adb install -r Release/BalatroInVR-Quest.apk
fi
