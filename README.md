# Balatro in VR

Play [Balatro](https://www.playbalatro.com/) in virtual reality, standalone on a Meta Quest. Balatro runs on the headset itself (the **Balatro VR Host** app, built from your own copy of the game); a small mod (**BalatroVRBridge**) sends the whole game to a VR client built with Godot, which shows it around you in a virtual casino:

- your cards in your hand – grab them, play them on the stake chip, throw them over your shoulder to discard
- jokers as 3D models on the table, booster packs to tear open, a reroll machine with a lever
- a shop counter where you grab what you buy, a real Wheel of Fortune, boss blinds that change the room
- a score tower and chip mountains that grow with your run
- the casino table as the main menu, Solatro – a solo card game on the table – and VR achievements


Watch the Showcase Trailer here: https://youtu.be/jdWvll1mY_0

You need your own copy of Balatro: the Balatro VR Host app is built on your own machine from your own `Balatro.exe`, and the client takes all card art, sounds and the font from that running game – **no game files from Balatro are included here.** The built `BalatroVRHost.apk` contains your copy of the game: never share it or attach it to a release; only the client APK (`BalatroInVR-Quest.apk`) can be distributed. Fan project, not affiliated with LocalThunk or Playstack.

## Install

You need a **Meta Quest 3 / 3S** in developer mode, a computer to build and install the apps once, and your own **Balatro** from Steam (`Balatro.exe`, version 1.0.1o). There is no download: both apps are built on your machine, the host one from your own copy of the game.

1. Headset in developer mode, connected with USB, `adb devices` lists it.
2. Install Godot 4.7.2, JDK 17 and the Android SDK (platform-tools, platforms 34 + 36, build-tools, NDK 25.2.9519653), and point Godot's editor settings at the SDK and JDK.
3. From this repo:
   ```
   quest/fetch_deps.sh
   quest/build_client.sh --install
   python3 quest/host/build_host.py --balatro "<path>/Balatro.exe" --install
   ```
4. On the headset, turn on the controllers and open **Balatro VR Host** from the library (Unknown sources). It runs Balatro in the background and opens **Balatro in VR** by itself.

**[INSTALL.md](INSTALL.md) has every step in detail** (exact SDK packages, where the settings go, updating, troubleshooting).

## Build it yourself

- `client/` – the Godot 4.7 VR client (see `client/README.md` for all controls and features)
- `BalatroMod/` – the Balatro mod, injected into the host app by `quest/host/build_host.py`
- `quest/` – build scripts for the two Quest apps
- `Docs/` – the protocol between mod and client, architecture notes

Everything is built with the scripts in `quest/` (details in `INSTALL.md`): Godot 4.7.2, JDK 17, the Android SDK and `adb` are required.

1. `quest/fetch_deps.sh` – Godot Android export templates, OpenXR vendors plugin, signing keystore (once).
2. `quest/build_client.sh [--install]` – exports the VR client to `Release/BalatroInVR-Quest.apk`.
3. `python3 quest/host/build_host.py --balatro <path>/Balatro.exe [--install]` – builds `Release/BalatroVRHost.apk` from your own Balatro.

For development, set `TEST_TOOLS := true` in `client/scripts/main.gd` (joker gallery and boss preview in the VR menu) and `TEST_MONEY = true` in `BalatroVRBridge.lua` (money and test buttons in Balatro).

Running Godot without a headset (scripts, imports, test renders): always pass `--xr-mode off`, otherwise OpenXR fails and Godot shows a "headset missing" message that blocks the run, e.g. `godot --headless --xr-mode off --path client -s res://tools/shrink_ai_models.gd -- ...`. Without `--headless` it opens a non-VR camera view for a quick look.

### Reporting bugs

Open an [issue](https://github.com/alextreumer/BalatroVRMod/issues) and attach, if you can:

- the log lines from the headset: `adb logcat -s godot SDL/APP BalatroVRHost` (the mod's lines start with `[BalatroVR]`), and your headset model

## License

GPL-3.0 – see [LICENSE](LICENSE). Balatro and its art belong to LocalThunk and Playstack and are not covered by this license.

By [Under the VRadar](https://www.youtube.com/@UnderTheVRadar).
