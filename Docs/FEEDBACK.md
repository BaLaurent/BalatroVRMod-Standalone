# Balatro in VR – Feedback photos (test mode)

While testing in VR, a problem is reported by taking a photo of it and saying what is wrong.
Later Claude goes through these photos and fixes the problems.

## Taking feedback photos

Only in **test mode**: `TEST_MONEY = true` at the top of `BalatroVRBridge.lua` (the mod tells the
VR client through the state field `test_mode`). Then:

1. VR menu ≡ → **Photo Camera: On**, grab the camera and pull the trigger (or the self-timer).
2. A keyboard appears in front of you: type what is wrong (SHIFT = capitals, `<-` = delete).
   The PC keyboard works too (Enter / Esc = done).
3. **OK** saves the comment. A photo without a comment (OK right away, or the next photo) still gets
   its text file with the context.

Without test mode the camera works as always (no keyboard, photos in `Photos/`).

## Where they are

`Photos/Feedback/` next to the program:

- run from the Godot project: `C:\Users\Anwender\Balatro in VR\Photos\Feedback\`
- exported build: `Photos\Feedback\` next to `Balatro in VR.exe`
- if that folder can't be written: `Pictures\Balatro in VR\Feedback\`

Each photo is a pair with the same name:

- `BalatroVR_<date>_<time>.png` – the photo
- `BalatroVR_<date>_<time>.txt` – `Comment: ...`, then the context as JSON: the game's screen
  (`state_name`, `menu`, `overlay`, `in_run`, `round`, `blind`, `stake_name`, `shop_open`, ...),
  the jokers (keys) and where the camera stood and looked (`camera.pos`, `camera.look`, metres)

`Photos/` is not in git (`.gitignore`), the photos stay on the PC.

## Working through them (for Claude)

1. List `Photos/Feedback/*.txt` (not the `done/` folder), oldest first.
2. For each pair: read the comment and the context, look at the PNG. Find the code with the
   context (jokers → `client/jokers/<key>.tscn`, screens/menus → `client/scripts/main.gd` and the
   mod `BalatroVRBridge.lua`). A comment without text: describe what the photo shows and ask Alex
   if the problem isn't clear.
3. Fix it locally (both copies of the mod: `BalatroMod/` in the repo and
   `%APPDATA%\Balatro\Mods\BalatroVRBridge`). Nothing goes to GitHub until Alex says so.
4. Move the finished pair to `Photos/Feedback/done/` and add a line `Fixed: <what was changed>` at
   the end of its `.txt`. Pairs that need a question to Alex stay where they are.
5. Report to Alex: one line per photo, fixed or open question.
