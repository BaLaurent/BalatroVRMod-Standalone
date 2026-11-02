# Balatro in VR – Installation Guide (Meta Quest, standalone)

You need: a **Meta Quest 3 / 3S** in developer mode, a Linux (or other) computer to build and install the two apps once, and your own copy of **Balatro** from Steam (`Balatro.exe`, version 1.0.1o).

Everything runs on the headset, no PC while playing. Two apps are installed:

- **Balatro VR Host** – Balatro itself, built from your own `Balatro.exe` and patched with the VR mod. It runs in the background.
- **Balatro in VR** – the VR client that shows the game around you.

## Step 1: Prepare the headset (once)

1. Enable **developer mode** for your Quest: in the Meta Horizon phone app → Devices → your headset → Developer Mode (needs a free Meta developer account/organisation).
2. Connect the Quest to the computer with a USB-C cable, put it on and accept **Allow USB debugging** (tick "Always allow").
3. On the computer, `adb devices` must list the headset as `device` (not `unauthorized`).

## Step 2: Install the tools on the computer (once)

| Tool | Version | Notes |
|---|---|---|
| [Godot](https://godotengine.org/download/archive/4.7.2-stable/) | **4.7.2** exactly | the `godot` command must be on your PATH |
| JDK | **17** | e.g. `/usr/lib/jvm/java-17-openjdk` (newer JDKs break the Android builds) |
| Android SDK | platform-tools, `platforms;android-34` and `android-36`, a recent `build-tools`, **`ndk;25.2.9519653`** | install with `sdkmanager`, e.g. `sdkmanager "platform-tools" "platforms;android-34" "platforms;android-36" "build-tools;35.0.0" "ndk;25.2.9519653"`; if a build asks for another component, install that one too |
| `git`, `python3`, `curl`, `unzip`, `keytool`, `apksigner`, `adb` | any | `keytool` comes with the JDK, `apksigner` with the build-tools |

Tell Godot where the SDK and JDK are. Close Godot, then in `~/.config/godot/editor_settings-4.7.tres` (Linux; on Windows `%APPDATA%\Godot\editor_settings-4.7.tres`) set:

```
export/android/android_sdk_path = "/path/to/android-sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-17-openjdk"
```

(or set the same two fields in the Godot editor: Editor → Editor Settings → Export → Android). Before building the host, `export JAVA_HOME=/path/to/jdk-17` (the script also finds `/usr/lib/jvm/java-17-openjdk[-amd64]` by itself) and, if the SDK is not at `/opt/android-sdk`, `export ANDROID_HOME=/path/to/android-sdk`.

## Step 3: Build both apps

From the repository root:

```
quest/fetch_deps.sh
quest/build_client.sh
python3 quest/host/build_host.py --balatro "<path>/Balatro.exe"
```

- `fetch_deps.sh` downloads the Godot 4.7.2 Android export templates (~1.2 GB, only the Android parts are kept), the OpenXR vendors plugin into `client/addons/`, and creates a signing keystore at `~/.local/share/godot/keystores/debug.keystore` (or `$BALATRO_VR_KEYSTORE`). It skips what is already there.
- `build_client.sh` exports the VR client → `Release/BalatroInVR-Quest.apk`.
- `build_host.py` reads your Steam `Balatro.exe` (Steam → right-click Balatro → Manage → Browse local files; on Linux e.g. `~/.local/share/Steam/steamapps/common/Balatro/Balatro.exe`), patches it for Android, adds the VR mod, downloads and compiles LÖVE 11.5 for Android (first run: ~10 min, later runs under a minute) → `Release/BalatroVRHost.apk`. It stops with an "anchor not found" message if your Balatro version differs from 1.0.1o.

Both APKs are signed with the same keystore. **`BalatroVRHost.apk` contains your copy of Balatro: keep it for yourself, never share it or upload it.**

## Step 4: Install on the headset

```
adb install -r Release/BalatroInVR-Quest.apk
adb install -r Release/BalatroVRHost.apk
```

(or add `--install` to the two build commands). To update later, pull the repo, rebuild and install again: your settings, layout and Balatro profile are kept.

### On Windows: build inside WSL2

The build scripts are written for Linux; on Windows run them in WSL2 (Ubuntu) and follow Steps 2–4 there:

1. In PowerShell: `wsl --install -d Ubuntu`, then open the Ubuntu terminal.
2. Inside Ubuntu install the Linux tools: `sudo apt install openjdk-17-jdk git python3 curl unzip`, the Linux Godot 4.7.2 (as `godot` on your PATH) and the Android SDK command-line tools with the packages from Step 2. The editor settings file is `~/.config/godot/editor_settings-4.7.tres` inside Ubuntu.
3. Clone this repo inside the Ubuntu home folder (not under `/mnt/c`: much faster). Your `Balatro.exe` is reachable from Ubuntu, e.g. `/mnt/c/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe`.
4. Build as in Step 3, **without** `--install`.
5. Install from Windows (WSL can't see USB devices): get [platform-tools](https://developer.android.com/tools/releases/platform-tools) for Windows, then in PowerShell, from that folder:
   ```
   .\adb install -r \\wsl$\Ubuntu\home\<you>\BalatroVRMod-Standalone\Release\BalatroInVR-Quest.apk
   .\adb install -r \\wsl$\Ubuntu\home\<you>\BalatroVRMod-Standalone\Release\BalatroVRHost.apk
   ```
   (or connect adb over Wi-Fi from inside WSL: `adb tcpip 5555` while on USB from Windows, then `adb connect <headset-ip>` in Ubuntu).

Native Windows (without WSL) is not supported yet.

## Step 5: Play

1. Put on the headset and turn on both controllers (the VR app refuses to start without them).
2. In the app library choose **Unknown sources** and open **Balatro VR Host**.
3. Balatro starts in the background and brings up **Balatro in VR** by itself. After a few seconds the game appears around you, with the card table in the middle of the casino.
4. Sitting somewhere else? Press **Recenter** in the VR menu (≡): the table and the room come to you.
5. Tap the Host icon again at any time to come back to the VR app. When you close the VR app, Balatro quits by itself after 30 seconds.

Balatro starts with a fresh profile on the headset (your PC save is not copied).

---

## Your first steps in VR

- A small hint above the game table points to **How To Play**. Press the **X button** on the left controller (left-handed: **A** on the right one) or the **≡ button** and choose **How To Play**.
- This button also opens the VR menu: adjust the layout, sitting/standing, background, sound, floor height, your **Achievements** and more.
- In VR the casino table is the main menu: slap the red **PLAY** buzzer to start, or try **SOLATRO**, the solo card game.
- Use **Adjust VR Layout** to move everything to where you want it.

---

## If something does not work

| Problem | Solution |
|---|---|
| The VR app says "Waiting for Balatro …" | Open **Balatro VR Host** from the app library. |
| Nothing opens and the headset shows a "controllers required" dialog | Turn on the Touch controllers. |
| Everything is in strange places | In the VR menu (≡) open **Adjust VR Layout**, then press **Y** (left-handed: **B**). Everything returns to the default positions. |
| Anything else | `adb logcat -s godot SDL/APP BalatroVRHost`: the mod's lines start with `[BalatroVR]`. |

Your own joker figures go in `Android/data/io.github.balaurent.balatroinvr/files/Documents/custom_jokers` on the headset. Photos are saved in the headset's `Pictures/Balatro in VR` folder.
