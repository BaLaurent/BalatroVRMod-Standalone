#!/usr/bin/env python3
"""Builds "Balatro VR Host": the user's own Steam Balatro.exe (a fused LÖVE zip), patched for
Android and with the BalatroVRBridge mod injected, packed into love-android 11.5a.

Usage: python3 quest/host/build_host.py --balatro <path/to/Balatro.exe> [--install]
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
WORK = os.path.join(HERE, ".work")
LOVE_ANDROID = os.path.join(WORK, "love-android")
BRIDGE = os.path.join(ROOT, "BalatroMod", "BalatroVRBridge", "BalatroVRBridge.lua")
OUT_APK = os.path.join(ROOT, "Release", "BalatroVRHost.apk")
CLIENT_ID = "io.github.balaurent.balatroinvr"
HOST_PKG = "io.github.balaurent.balatrovr.host"


def die(msg):
    sys.exit(msg)


def patch(text, old, new, count=1, first_only=False, name="?"):
    """Replace `old` by `new`; die unless `old` occurs exactly `count` times (>= 1 with first_only)."""
    n = text.count(old)
    if n != count and not (first_only and n >= 1):
        die(f"{name}: anchor not found exactly {count} time(s) (found {n}): {old!r}")
    return text.replace(old, new, 1) if first_only else text.replace(old, new)


def patch_re(text, pattern, new, name="?", flags=0):
    text, n = re.subn(pattern, new, text, flags=flags)
    if n != 1:
        die(f"{name}: regex matched {n} times, expected 1: {pattern!r}")
    return text


def read_game(exe):
    files = {}
    with zipfile.ZipFile(exe) as z:  # zipfile tolerates the exe bytes prepended to the archive
        for info in z.infolist():
            if not info.is_dir():
                files[info.filename] = z.read(info)
    if "version.jkr" in files:
        print("Balatro version:", files["version.jkr"].decode("utf-8", "replace").splitlines()[0])
    return files


def patch_game(files):
    def edit(member, fn):
        if member not in files:
            die(f"{member}: not in Balatro.exe")
        files[member] = fn(files[member].decode("utf-8")).encode("utf-8")

    android_flags = (
        "    if love.system.getOS() == 'Android' then\n"
        "        self.F_SAVE_TIMER = 5\n"
        "        self.F_DISCORD = true\n"
        "        self.F_NO_ACHIEVEMENTS = true\n"
        "        self.F_CRASH_REPORTS = false\n"
        "        self.F_SOUND_THREAD = true\n"
        "        self.F_VIDEO_SETTINGS = false\n"
        "        self.F_ENGLISH_ONLY = false\n"
        "        self.F_QUIT_BUTTON = false\n"
        "    end\n"
    )
    win = "    if love.system.getOS() == 'Windows' then\n"

    def globals(t):
        t = patch(t, win, android_flags + win, name="globals.lua")
        return patch(t, "crt = 70,", "crt = 0,", name="globals.lua")

    edit("globals.lua", globals)
    edit("game.lua", lambda t: patch(
        t, "        love.graphics.setShader( G.SHADERS['CRT'])\n", "\n", name="game.lua"))

    def flame(t):
        t = t.replace("\r\n", "\n")  # the shaders ship with CRLF line endings
        t = patch(t, "#endif\n", "#endif\n#ifdef GL_ES\n\tprecision MY_HIGHP_OR_MEDIUMP float;\n#endif\n",
                  first_only=True, name="flame.fs")
        return patch(
            t,
            "vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )",
            "mediump vec4 effect( mediump vec4 colour, Image texture, mediump vec2 texture_coords, mediump vec2 screen_coords )",
            name="flame.fs")

    edit("resources/shaders/flame.fs", flame)

    def main(t):
        t = patch(t, "G.FPS_CAP = G.FPS_CAP or 500", "G.FPS_CAP = 60", name="main.lua")
        return t + '\n-- Balatro in VR (Quest host): the bridge, loaded after every game file\nrequire("BalatroVRBridge")\n'

    edit("main.lua", main)
    with open(BRIDGE, "rb") as f:
        files["BalatroVRBridge.lua"] = f.read()


def prepare_love_android():
    def git(*args, cwd=LOVE_ANDROID):
        return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()

    tag = None
    if os.path.isdir(LOVE_ANDROID):
        try:
            tag = git("describe", "--tags")
        except subprocess.CalledProcessError:
            pass
    if tag != "11.5a":
        shutil.rmtree(LOVE_ANDROID, ignore_errors=True)
        os.makedirs(WORK, exist_ok=True)
        subprocess.run(["git", "clone", "--recurse-submodules", "--shallow-submodules", "--depth", "1",
                        "-b", "11.5a", "https://github.com/love2d/love-android", LOVE_ANDROID], check=True)
    else:
        # back to pristine; build outputs stay for incremental native builds
        git("checkout", "--", ".")
        git("checkout", "--", ".", cwd=os.path.join(LOVE_ANDROID, "love", "src", "jni", "love"))
        git("clean", "-fd", "app/src/main/java", "app/src/embed/assets")


def la_edit(rel, fn):
    path = os.path.join(LOVE_ANDROID, rel)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    with open(path, "w", encoding="utf-8") as f:
        f.write(fn(text))


def patch_love_android(files):
    def props(t):
        t = patch_re(t, r"^app\.name_byte_array=.*$", "app.name=Balatro VR Host", "gradle.properties", re.M)
        t = patch(t, "app.application_id=org.love2d.android", f"app.application_id={HOST_PKG}", name="gradle.properties")
        t = patch(t, "app.version_code=32", "app.version_code=1", name="gradle.properties")
        return patch(t, "app.version_name=11.5a", "app.version_name=1.1", name="gradle.properties")

    la_edit("gradle.properties", props)
    la_edit("app/build.gradle", lambda t: patch(t, "minSdk 16", "minSdk 29", name="app/build.gradle"))
    la_edit("love/build.gradle", lambda t: patch(
        t, "abiFilters 'armeabi-v7a', 'arm64-v8a'", "abiFilters 'arm64-v8a'", name="love/build.gradle"))

    def manifest(t):
        name = "AndroidManifest.xml"
        internet = '<uses-permission android:name="android.permission.INTERNET" />'
        t = patch(t, internet, internet + (
            '\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />'
            '\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />'
            f'\n    <queries><package android:name="{CLIENT_ID}" /></queries>'), name=name)
        t = patch(t, 'android:name="org.love2d.android.GameActivity"',
                  f'android:name="{HOST_PKG}.HostActivity"', name=name)
        extra = (
            f'    <service android:name="{HOST_PKG}.HostService" android:exported="false"'
            ' android:foregroundServiceType="mediaPlayback" />\n'
            f'    <activity android:name="{HOST_PKG}.LaunchClientActivity" android:exported="true"'
            ' android:theme="@android:style/Theme.NoDisplay" android:noHistory="true"'
            ' android:excludeFromRecents="true" android:taskAffinity="">\n'
            '        <intent-filter>\n'
            '            <action android:name="android.intent.action.VIEW" />\n'
            '            <category android:name="android.intent.category.DEFAULT" />\n'
            '            <data android:scheme="balatrovr-host" />\n'
            '        </intent-filter>\n'
            '    </activity>\n'
            '    <meta-data android:name="SDL_ENV.SDL_ANDROID_BLOCK_ON_PAUSE" android:value="0" />\n'
        )
        return patch(t, "</application>", extra + "</application>", name=name)

    la_edit("app/src/main/AndroidManifest.xml", manifest)

    # keep OpenAL playing while minimised: the music must continue behind the VR app
    la_edit("love/src/jni/love/src/modules/event/sdl/Event.cpp", lambda t: patch_re(
        t, r"#ifdef LOVE_ANDROID\n\s*if \(auto audio = Module::getInstance<audio::Audio>\(Module::M_AUDIO\)\).*?#endif\n",
        "", "Event.cpp", re.S))

    # The VR app takes the headset while this one is paused, which destroys its window surface and
    # (stock SDL) leaves the game thread without a GL context: Balatro's canvases/images then fail.
    # Keep the context current without a surface (surfaceless EGL) while paused.
    def sdl_events(t):
        t = patch(t, '#include "../SDL_sysvideo.h"\n', '#include "../SDL_sysvideo.h"\n#include "../SDL_egl_c.h"\n', name="SDL_androidevents.c")
        return patch(
            t, "        SDL_GL_MakeCurrent(window, NULL);\n        data->backup_done = 1;\n",
            "        SDL_GL_MakeCurrent(window, NULL);\n"
            "        {\n"
            "            SDL_VideoDevice *vd = SDL_GetVideoDevice();\n"
            "            if (vd && vd->egl_data && data->egl_context) {\n"
            "                vd->egl_data->eglMakeCurrent(vd->egl_data->egl_display, EGL_NO_SURFACE, EGL_NO_SURFACE, (EGLContext)data->egl_context);\n"
            "            }\n"
            "        }\n"
            "        data->backup_done = 1;\n", name="SDL_androidevents.c")

    la_edit("love/src/jni/SDL2/src/video/android/SDL_androidevents.c", sdl_events)

    java_dst = os.path.join(LOVE_ANDROID, "app/src/main/java", *HOST_PKG.split("."))
    os.makedirs(java_dst, exist_ok=True)
    for src in glob.glob(os.path.join(HERE, "java", "*.java")):
        shutil.copy(src, java_dst)

    assets = os.path.join(LOVE_ANDROID, "app/src/embed/assets")
    os.makedirs(assets, exist_ok=True)
    with zipfile.ZipFile(os.path.join(assets, "game.love"), "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in files.items():
            z.writestr(name, data)


def jdk17():
    """The JDK 17 for Gradle: $BALATRO_VR_JAVA_HOME, $JAVA_HOME, then the usual Linux paths."""
    cands = [os.environ.get("BALATRO_VR_JAVA_HOME"), os.environ.get("JAVA_HOME"),
             "/usr/lib/jvm/java-17-openjdk", "/usr/lib/jvm/java-17-openjdk-amd64"]
    for home in filter(None, cands):
        java = os.path.join(home, "bin", "java")
        if not os.path.exists(java):
            continue
        out = subprocess.run([java, "-version"], capture_output=True, text=True).stderr
        if re.search(r'version "17[."]', out):
            return home
        print(f"skipping {home}: not a JDK 17 ({out.splitlines()[0] if out else '?'})")
    die("no JDK 17 found: set JAVA_HOME (or BALATRO_VR_JAVA_HOME) to a JDK 17")


def build():
    env = dict(os.environ)
    env["JAVA_HOME"] = jdk17()
    env["ANDROID_HOME"] = env.get("ANDROID_HOME", "/opt/android-sdk")
    env["PATH"] = os.path.join(env["JAVA_HOME"], "bin") + os.pathsep + env["PATH"]
    subprocess.run(["./gradlew", "--no-daemon", "assembleEmbedNoRecordRelease"], cwd=LOVE_ANDROID, env=env, check=True)
    apks = glob.glob(os.path.join(LOVE_ANDROID, "app/build/outputs/apk/embedNoRecord/release/*.apk"))
    if len(apks) != 1:
        die(f"expected exactly one apk, found: {apks}")
    return apks[0], env["ANDROID_HOME"]


def sign(unsigned, android_home):
    keystore = os.environ.get("BALATRO_VR_KEYSTORE") or os.path.expanduser("~/.local/share/godot/keystores/debug.keystore")
    apksigner = shutil.which("apksigner")
    if not apksigner:
        cands = sorted(glob.glob(os.path.join(android_home, "build-tools", "*", "apksigner")))
        if not cands:
            die("apksigner not found")
        apksigner = cands[-1]
    os.makedirs(os.path.dirname(OUT_APK), exist_ok=True)
    subprocess.run([apksigner, "sign", "--ks", keystore, "--ks-key-alias", "androiddebugkey",
                    "--ks-pass", "pass:android", "--key-pass", "pass:android", "--out", OUT_APK, unsigned], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--balatro", required=True, help="path to Steam's Balatro.exe")
    ap.add_argument("--install", action="store_true", help="adb install the result")
    args = ap.parse_args()

    files = read_game(args.balatro)
    patch_game(files)
    prepare_love_android()
    patch_love_android(files)
    unsigned, android_home = build()
    sign(unsigned, android_home)
    print("built", OUT_APK)
    if args.install:
        subprocess.run(["adb", "install", "-r", OUT_APK], check=True)


if __name__ == "__main__":
    main()
