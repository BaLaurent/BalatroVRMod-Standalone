#!/usr/bin/env bash
# One-time (idempotent) download of everything the Quest build needs:
# Godot Android export templates, the OpenXR vendors plugin, a signing keystore.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_VER=4.7.2
TPL_DIR="$HOME/.local/share/godot/export_templates/$GODOT_VER.stable"
VENDORS_VER=5.1.0-stable
KEYSTORE="${BALATRO_VR_KEYSTORE:-$HOME/.local/share/godot/keystores/debug.keystore}"

if [ ! -f "$TPL_DIR/android_source.zip" ]; then
    tpz=/tmp/godot-$GODOT_VER-templates.tpz
    curl -fsSL -o "$tpz" "https://github.com/godotengine/godot-builds/releases/download/$GODOT_VER-stable/Godot_v${GODOT_VER}-stable_export_templates.tpz"
    mkdir -p "$TPL_DIR"
    unzip -j -o "$tpz" "templates/android_source.zip" "templates/android_debug.apk" "templates/android_release.apk" -d "$TPL_DIR"
    rm -f "$tpz"
fi

if [ ! -f client/addons/godotopenxrvendors/plugin.gdextension ]; then
    zipf=/tmp/godotopenxrvendors-$VENDORS_VER.zip
    tmp=$(mktemp -d)
    curl -fsSL -o "$zipf" "https://github.com/GodotVR/godot_openxr_vendors/releases/download/$VENDORS_VER/godotopenxrvendorsaddon.zip"
    unzip -q -o "$zipf" -d "$tmp"
    mkdir -p client/addons
    cp -r "$tmp/asset/addons/godotopenxrvendors" client/addons/godotopenxrvendors
    rm -rf "$tmp" "$zipf"
fi

if [ ! -f "$KEYSTORE" ]; then
    mkdir -p "$(dirname "$KEYSTORE")"
    keytool -genkeypair -v -keystore "$KEYSTORE" -storepass android -keypass android \
        -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US"
fi
echo "deps ok"
