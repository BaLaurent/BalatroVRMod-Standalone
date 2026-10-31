# VR-Tutorial: Bilder, Animationen und Sprachaufnahmen

Jede Seite des VR-Tutorials (Schild **VR-TUTORIAL** auf dem Menütisch) sucht hier nach Dateien mit ihrem Namen.
Gesucht wird zuerst in `user://tutorial/` (= `%APPDATA%\Godot\app_userdata\Balatro in VR\tutorial\`), dann in diesem Ordner.
Fehlt eine Datei, zeigt der Bilderrahmen auf der Tafel nur einen Platzhalter mit dem erwarteten Namen.

| Was | Datei |
|---|---|
| Foto | `<name>.png`, `.jpg` oder `.webp` |
| Animation (GIF) | ein Ordner `<name>/` mit den Einzelbildern (z. B. `frame_000.png` ...), 12 Bilder/s |
| Video | `<name>.ogv` (Ogg Theora) |
| Ansage | `<name>.ogg`, `.mp3` oder `.wav` – startet beim Öffnen der Seite, "PLAY AUDIO" wiederholt sie |

Der Bilderrahmen ist 16:9; andere Formate werden ohne Verzerren eingepasst.
GIF umwandeln: `ffmpeg -i anim.gif tutorial/03_flick/frame_%03d.png` oder `ffmpeg -i anim.gif -q:v 7 tutorial/03_flick.ogv`.

## Die Seiten

- `01_hands` – Welcome to the VR Tutorial!
- `02_select` – Select cards
- `03_move_card` – Move a card in your hand
- `04_flick` – Play: the flick
- `05_play_button` – Play: the {A} button
- `06_shoulder` – Discard: over your shoulder
- `07_discard_box` – Discard: the box
- `08_discard_button` – Discard: the {B} button
- `09_sort_stick` – Sort: the thumbstick
- `10_sort_turn` – Sort: turn your hand
- `11_deck_info` – Your deck: hold your hand over it
- `12_shop_grab` – Shop: grab it
- `13_reroll` – Shop: reroll
- `14_pack_tear` – Booster pack: rip it open
- `15_pack_laser` – Booster pack: the laser
- `16_use_throw` – Use a card: throw it up
- `17_use_hand` – Use a card: onto your hand
- `18_wheel` – The Wheel of Fortune
- `19_joker_order` – Jokers: from left to right
- `20_joker_sell` – Jokers: sell one
- `21_adjust` – Adjust your VR layout
- `22_backgrounds` – Three backgrounds
- `23_options` – Good to know: the options
- `24_achievement` – Achievements and rewards
- `25_done` – You're ready!
