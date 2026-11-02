class_name TutorialRun
extends Node3D
## The VR TUTORIAL from the menu table: Jimbo's board stands over the table and goes through the
## most important moves, one step at a time. Like Solatro it is played by VR alone - the game stays
## in its main menu, this script deals its own cards, fills its own shop and puts its own jokers on
## the board, and main.gd sends it what would go to the game (with HOW it was done: "flick",
## "chip", "button", "shoulder", "box", "stick", "turn", "grab", "tear", "laser", "throw", "hand").
## A step only goes on when its move was done; after NEXT_AFTER seconds NEXT SLIDE skips it,
## EXIT goes back to the main menu at any time.
##
## Pictures and voice: each step can show a photo / animation and play a spoken line. They are
## looked for by the step's id (see STEPS) in user://tutorial/ first (to try new ones without exporting),
## then res://tutorial/ (client/tutorial: they go into the game's package, players see no folder):
##   <id>.png / .jpg / .webp   a still picture
##   <id>/  (a folder)          an animation: its pictures in name order (an exported GIF), FRAME_FPS
##   <id>.ogv                   a video (Ogg Theora)
##   <id>.ogg / .mp3 / .wav     the spoken line, played when the step opens (PLAY AUDIO repeats it)

signal publish(scene: Dictionary, state: Dictionary)
signal hint(text: String)
signal say(text: String)                 # a short line for Jimbo (when he sits at the table)
signal leave                             # back to the main menu
signal set_hands(left_handed: bool)      # the hand chosen on the first page (main.gd saves it)
signal show_pack(ev: Dictionary)         # a booster pack floats in front of you (main.gd's _show_pack)
signal hide_pack
signal show_wheel(on: bool)              # the Wheel of Fortune in front of you (it always lands on WIN!)
signal effect(kind: String)              # "planet": stars all over the room (main.gd)
signal finished                          # the last page was reached
signal sfx(right: bool)                  # a move done right (or the wrong way): main.gd plays a sound
signal layout_lesson(on: bool)           # the ADJUST page: the score tower in the middle (and the layout put back after)
signal unlock                            # the ACHIEVEMENT page: "Tutorial Achievement" unlocked

const NEXT_AFTER := 30.0                 # seconds on one page before NEXT SLIDE can be pressed
const DONE_HOLD := 1.6                   # "WELL DONE!" stays this long, then the next page opens
const FRAME_FPS := 12.0
const HAND_SIZE := 8
const MEDIA_DIRS := ["user://tutorial/", "res://tutorial/"]
const EXIT_ID := -700
const NEXT_ID := -701
const CARDS_LEFT_ID := -702              # the cards in the left hand, the beam in the right
const CARDS_RIGHT_ID := -703
const AUDIO_ID := -704
const MENU_ID := -705                    # BACK TO MENU on the last page
const UNLOCK_ID := -706                  # UNLOCK on the achievement page
const OK_ID := -707                      # GOT IT on a page that only tells something
const BACKDROP_NAMES := ["DARK", "CASINO"] # main.gd's Backdrop (Background in the VR menu)
const JIMBO_AT := Vector3(0.6, 0.0, -0.45) # Jimbo stands right of the board (main.gd places him there)
const SHOP_ID := 950                     # the joker on the sales counter ...
const REROLL_ID := 951                   # ... and the one a reroll puts there instead
const JOKER_UIDS := [801, 802, 803]      # the three jokers on the board: "1", "2", "3"
const JOKER_KEYS := ["j_joker", "j_greedy_joker", "j_lusty_joker"]
const JOKER_NAMES := ["Joker", "Greedy Joker", "Lusty Joker"]
const JOKER_CELLS := [[0, 0], [6, 1], [7, 1]] # where they sit in the game's Joker picture
const JOKER_GOAL := [803, 801, 802]      # 3 - 1 - 2, read from left to right
const PLANET_UID := 860                  # the cards in the card stand: Mercury ...
const TAROT_UID := 861                   # ... and The Hermit (doubles your money)
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"]
const SUITS := ["Hearts", "Clubs", "Diamonds", "Spades"]
const BOARD := Vector2(0.84, 0.5)
const MEDIA := Vector2(0.39, 0.28)       # the room for the picture: the frame takes the picture's own shape in it
const MEDIA_AT := Vector3(-0.215, 0.24, 0.008)
const TEXT_X := -0.005                   # the step's text: right of the picture
const TEXT_W := 0.4

## The steps. phase: what is on the table ("intro", "cards", "shop", "pack", "use", "wheel", "jokers", "done").
## want: [command, how] that finishes the step ("" = any way). nope: said when it was done another way.
## In the texts {cards} / {point} are the hands, {A} / {B} the pointing hand's buttons.
const STEPS := [
	{"id": "01_hands", "phase": "intro", "want": ["hands", ""],
		"title": "Welcome to the VR Tutorial!",
		"text": "I'm Jimbo, and I'll show you the most important moves - one at a time. Each page only goes on once you've done its move yourself.\n\nFirst: which hand points the laser beam, and which holds your cards? Point at your choice and pull the trigger. (It is saved in your settings - \"Switch Hands\" in the VR menu changes it later.)",
		"jimbo": "Hi! Let's learn the moves!"},
	{"id": "02_select", "phase": "cards", "want": ["select", ""],
		"title": "Select cards",
		"text": "Your cards are in your {cards} hand now. Point the beam of your {point} hand at a card and pull the trigger to select it - pull again to unselect it.\n\nYOUR TURN: select at least 2 cards.",
		"nope": "Select at least 2 cards", "jimbo": "Pick some cards!"},
	{"id": "03_move_card", "phase": "cards", "want": ["move", ""],
		"title": "Move a card in your hand",
		"text": "You can put your cards in any order you like. Point at a card and HOLD the trigger - the card lifts out of the fan. Move the beam onto another card of your hand and let go of the trigger there: the card moves to that place.\n\nYOUR TURN: move a card to another place in your hand.",
		"nope": "Hold the trigger on a card, let go on another one", "jimbo": "Shuffle them around!"},
	{"id": "04_flick", "phase": "cards", "want": ["play", "flick"],
		"title": "Play: the flick",
		"text": "Bring your {point} hand close to the selected cards and hold the grip: you grab them. Now toss them towards the table with a quick little flick of the wrist, letting go of the grip.\n\nYOUR TURN: play your selected cards with a flick.",
		"nope": "Not this time - flick them towards the table", "jimbo": "Flick 'em!"},
	{"id": "05_play_button", "phase": "cards", "want": ["play", "button"],
		"title": "Play: the {A} button",
		"text": "The quickest way: select your cards and press {A} on your {point} controller. They are played at once - no grabbing needed.\n\nYOUR TURN: play cards with the {A} button.",
		"nope": "Not this time - press {A}", "jimbo": "Press {A}!"},
	{"id": "06_shoulder", "phase": "cards", "want": ["discard", "shoulder"],
		"title": "Discard: over your shoulder",
		"text": "Cards you don't want go over your shoulder! Select them, grab them with the grip and throw them back over your shoulder - let go of the grip behind your head.\n\nYOUR TURN: discard cards over your shoulder.",
		"nope": "Not this time - throw them over your shoulder", "jimbo": "Over the shoulder!"},
	{"id": "07_discard_box", "phase": "cards", "want": ["discard", "box"],
		"title": "Discard: the box",
		"text": "Tidier: select cards, grab them and hold them over the SELL / DISCARD box on the table. Let go of the grip there and they drop in.\n\nYOUR TURN: discard cards into the box.",
		"nope": "Not this time - let go over the SELL / DISCARD box", "jimbo": "Into the box!"},
	{"id": "08_discard_button", "phase": "cards", "want": ["discard", "button"],
		"title": "Discard: the {B} button",
		"text": "And the quick way again: select cards and press {B} on your {point} controller.\n\nYOUR TURN: discard cards with the {B} button.",
		"nope": "Not this time - press {B}", "jimbo": "Press {B}!"},
	{"id": "09_sort_stick", "phase": "cards", "want": ["sort", "stick|grip"],
		"title": "Sort: thumbstick or grip",
		"text": "Your hand can be sorted by rank or by suit. On your {cards} controller - the one holding the cards - either press down (click) the thumbstick, or squeeze the grip (with nothing else in reach).\n\nYOUR TURN: sort your cards with the thumbstick or the grip of your {cards} hand.",
		"nope": "Sorted! Now try the thumbstick or the grip of your {cards} hand", "jimbo": "Stick or grip!"},
	{"id": "10_sort_turn", "phase": "cards", "want": ["sort", "turn"],
		"title": "Sort: turn your hand",
		"text": "Or turn your {cards} hand on its side, as if you showed your cards to someone next to you. A blue SORT button appears over the cards: point at it and pull the trigger.\n\nYOUR TURN: sort by turning your hand and pressing SORT.",
		"nope": "Sorted! Now turn your hand on its side", "jimbo": "Turn your hand!"},
	{"id": "11_deck_info", "phase": "cards", "want": ["deck_view", ""],
		"title": "Your deck: hold your hand over it",
		"text": "Which cards are still in your deck? Simply hold one of your hands over the deck on the table - the deck's cards show up while your hand stays there.\n\nYOUR TURN: hold a hand over the deck.",
		"jimbo": "Peek at the deck!"},
	{"id": "12_shop_grab", "phase": "shop", "want": ["buy", "grab"],
		"title": "Shop: grab it",
		"text": "In the shop everything stands on the sales counter. Reach out, take the joker with the grip of either hand, pull it towards you and let go. Bought!\n\n(Pointing at an item with the beam shows BUY buttons too - but this time use your hand.)\n\nYOUR TURN: buy the joker by grabbing it.",
		"nope": "Not this time - grab it and pull it towards you", "jimbo": "Grab it!"},
	{"id": "13_reroll", "phase": "shop", "want": ["reroll", ""],
		"title": "Shop: reroll",
		"text": "Don't like what's on the counter? The reroll machine next to it puts new things there - for a few dollars. Grab the ball of its lever with the grip and pull it down, like a slot machine.\n\nYOUR TURN: pull the lever of the reroll machine.",
		"nope": "Not this time - pull the lever", "jimbo": "Pull the lever!"},
	{"id": "14_pack_tear", "phase": "pack", "want": ["open_pack", "tear"],
		"title": "Booster pack: rip it open",
		"text": "A booster pack floats in front of you. Take hold of it with BOTH hands (grip) and pull your hands apart - rip!\n\nYOUR TURN: tear the pack open with both hands.",
		"nope": "Not this time - pull it apart with both hands", "jimbo": "Rip it!"},
	{"id": "15_pack_laser", "phase": "pack", "want": ["open_pack", "laser"],
		"title": "Booster pack: the laser",
		"text": "In a hurry? Point the beam at the pack and pull the trigger - it opens at once.\n\nYOUR TURN: open the pack with the laser.",
		"nope": "Not this time - point the beam at it and pull the trigger", "jimbo": "Zap it!"},
	{"id": "16_use_throw", "phase": "use", "want": ["use", "throw"],
		"title": "Use a card: throw it up",
		"text": "Tarot, planet and spectral cards wait in the card stand on the table. Take the planet card with the grip of your {point} hand and throw it up into the sky - let go of it above your head.\n\nYOUR TURN: use the planet card by throwing it up.",
		"nope": "Not this time - throw it up into the sky", "jimbo": "To the stars!"},
	{"id": "17_use_hand", "phase": "use", "want": ["use", "hand"],
		"title": "Use a card: onto your hand",
		"text": "Every card also works like this: take it with your {point} hand and hold it right at your {cards} hand - it glows gold there - then let go.\n\nYOUR TURN: use The Hermit by putting it onto your {cards} hand.",
		"nope": "Not this time - let go of it at your {cards} hand", "jimbo": "Hand it over!"},
	{"id": "18_wheel", "phase": "wheel", "want": ["wheel_done", ""],
		"title": "The Wheel of Fortune",
		"text": "When you use the Wheel of Fortune card, this wheel stands in front of you. Take hold of its rim with the trigger or the grip and swing it round - or just swipe it with your hand. WIN! gives a joker an edition.\n\nYOUR TURN: spin the wheel!",
		"jimbo": "Spin it!"},
	{"id": "19_joker_order", "phase": "jokers", "want": ["order", ""],
		"title": "Jokers: from left to right",
		"text": "Just like in Balatro, your jokers always count from LEFT to RIGHT - so their order matters! Grab a joker with the grip, carry it and put it down at another place on the board.\n\nYOUR TURN: put the jokers in the order 3 - 1 - 2, from left to right.",
		"nope": "", "jimbo": "Left to right!"},
	{"id": "20_joker_sell", "phase": "jokers", "want": ["sell", ""],
		"title": "Jokers: sell one",
		"text": "Don't need a joker any more? Grab it and let go of it right over the SELL / DISCARD box on the table. It drops into the slot and you get its sell value.\n\nYOUR TURN: sell one of your jokers.",
		"jimbo": "Cash it in!"},
	{"id": "21_adjust", "phase": "adjust", "want": ["adjust", ""],
		"title": "Adjust your VR layout",
		"text": "Everything at the table can be put where you like it. Press {menu} on your {cards} controller to open the VR menu and choose ADJUST VR LAYOUT: every item gets a yellow ball. Grab the score tower's ball with the grip, move it, and while you hold it push the stick up or down to change its size.\n\n(Just practice: your own layout is put back afterwards.)\n\nYOUR TURN: grab the score tower's yellow ball, move it and resize it.",
		"jimbo": "Make yourself at home!"},
	{"id": "22_backgrounds", "phase": "backgrounds", "want": ["backgrounds", ""],
		"title": "Two backgrounds",
		"text": "You can play in two surroundings: DARK (calm, easy on the eyes) and the CASINO. Press {menu} on your {cards} controller and press BACKGROUND to switch.\n\nYOUR TURN: switch through both backgrounds (then keep the one you like).",
		"jimbo": "Try them all!"},
	{"id": "23_options", "phase": "info", "want": ["ok", ""],
		"title": "Good to know: the options",
		"text": "Everything can be made calmer or simpler in the VR menu ({menu} on your {cards} controller):\n\nCALM LIGHTS - no flickering lights\nJIMBO - send me away (I won't be offended!)\nCASINO SOUNDS - the casino's sound effects\nHANDS - the virtual hands\n\nPress GOT IT to go on.",
		"jimbo": "Make it yours!"},
	{"id": "24_achievement", "phase": "achievement", "want": ["achievement", ""],
		"title": "Achievements and rewards",
		"text": "Things only VR lets you do unlock achievements - and each one has a reward that changes how VR looks. Press UNLOCK for your first one!\n\nRewards can be switched on and off: press {menu} on your {cards} controller, choose ACHIEVEMENTS and press the reward's ON / OFF switch.\n\nYOUR TURN: unlock the Tutorial Achievement, then switch its reward OFF.",
		"jimbo": "Your first trophy!"},
	{"id": "25_done", "phase": "done", "want": ["", ""],
		"title": "You're ready!",
		"text": "That's all the moves! You can open this tutorial again any time with the VR-TUTORIAL sign on the menu table.\n\nHave fun at the table - and Safe Travels!",
		"jimbo": "You're ready! Safe Travels!"},
]
const PRAISE := ["Well done!", "Nice!", "Great!", "Perfect!", "That's it!"]

var active := false
var left_handed := false
var desktop := false                     # no VR: any way counts (testing on the PC)
var joker_node: Callable                 # (uid) -> Node3D: a joker on the board (main.gd)

var _rng := RandomNumberGenerator.new()
var _step := 0
var _step_time := 0.0
var _done_t := -1.0                      # > 0 while "WELL DONE!" shows
var _deck: Array = []
var _hand: Array = []
var _played: Array = []
var _play_t := -1.0                      # > 0 while played cards lie on the stand
var _selected := {}
var _by_suit := false
var _dollars := 10
var _shop_bought := false
var _rerolled := false
var _pack_t := -1.0                      # > 0: a pack comes in that many seconds
var _pack_out := false
var _joker_order: Array = []
var _joker_marks := {}                   # uid -> Label3D (the joker's number over it)
var _used := {}                          # uid -> true: a card from the stand that was used
var _foil := false                       # the wheel landed on WIN!: joker 1 is foil
var _wheel_out := false
var node_for: Callable                   # (kind, id) -> Node3D: "hand", "play", "joker", "shop", "use", "pack" (main.gd)
var layout_probe: Callable               # () -> {"calib", "held", "pos", "scale"}: the score tower in Adjust VR Layout
var reward_on: Callable                  # () -> bool: is the Tutorial Achievement's reward on?
var _adjust := {}                        # the ADJUST page: "start", "scale", and what was done ("open", "held", "moved", "sized")
var _unlocked := false                   # the ACHIEVEMENT page: UNLOCK was pressed
var _fakes := {}                         # "kind:id" -> Label3D: what a card is, while its picture is missing
var _fake_t := 0.0
var backdrop_probe: Callable             # () -> int: the background now (main.gd's Backdrop: 0 dark, 1 casino, 2 passthrough)
var _seen_backdrops := {}                # the BACKGROUNDS page: the ones seen so far
var _deck_label: Label3D                 # the deck's cards while a hand is over it (in the picture frame)

var _bodies: Array[StaticBody3D] = []
var _buttons := {}                       # id -> {root, label, mat, colour, on}
var _header: Label3D
var _counter: Label3D
var _title: Label3D
var _text: Node3D
var _status: Label3D
var _bar: MeshInstance3D
var _portrait: Node3D
var _portrait_art := false
var _media: MeshInstance3D
var _media_mat: StandardMaterial3D
var _placeholder: Label3D
var _frames: Array = []
var _frame_t := 0.0
var _video_port: SubViewport
var _frame_boxes: Array = []     # the picture frame's gold rim and dark back (hidden on the last page)
var _media_size := MEDIA         # the picture's size in the frame
var _voice: AudioStreamPlayer3D


func _ready() -> void:
	_rng.randomize()
	_build_board()
	GameFont.apply_to(self)
	visible = false


# ---------------------------------------------------------------- start, pages, end

func start() -> void:
	active = true
	visible = true
	_hand.clear()
	_played.clear()
	_selected.clear()
	_deck.clear()
	_by_suit = false
	_dollars = 10
	_used.clear()
	_foil = false
	_joker_marks.clear()
	_go(0)


func stop() -> void:
	active = false
	visible = false
	_voice.stop()
	_clear_media()
	if _pack_out:
		hide_pack.emit()
	_pack_out = false
	_pack_t = -1.0
	if _wheel_out:
		show_wheel.emit(false)
	_wheel_out = false
	if STEPS[_step]["phase"] == "adjust":
		layout_lesson.emit(false) # (the layout as it was)
	_clear_fakes()


func _go(i: int) -> void:
	var was: String = STEPS[_step]["phase"]
	_step = clampi(i, 0, STEPS.size() - 1)
	_step_time = 0.0
	_done_t = -1.0
	var phase: String = STEPS[_step]["phase"]
	if was == "pack" and _pack_out:
		hide_pack.emit() # (skipped while it floated there)
		_pack_out = false
	_pack_t = -1.0
	if _wheel_out:
		show_wheel.emit(false)
		_wheel_out = false
	if was == "adjust" and phase != "adjust":
		layout_lesson.emit(false)
	match phase:
		"cards":
			if _hand.is_empty():
				_deal()
		"shop":
			_shop_bought = false
			_rerolled = false
		"wheel":
			_wheel_out = true
			show_wheel.emit(true)
		"pack":
			_pack_t = 0.6
		"jokers":
			if _joker_order.size() != JOKER_UIDS.size() or was != "jokers":
				_joker_order = JOKER_UIDS.duplicate()
		"adjust":
			layout_lesson.emit(true)
			_adjust = {}
		"achievement":
			_unlocked = false
		"backgrounds":
			_seen_backdrops = {}
		"done":
			finished.emit()
	if phase != "cards":
		_selected.clear()
	_show_step()
	_publish()
	say.emit(_fill(str(STEPS[_step].get("jimbo", ""))))


## The page's move was done: "WELL DONE!", then the next page.
func _complete() -> void:
	if _done_t > 0.0:
		return
	_done_t = DONE_HOLD
	sfx.emit(true)
	_status.text = PRAISE[_rng.randi() % PRAISE.size()].to_upper()
	_status.modulate = Color(0.45, 1.8, 0.6)
	_enable(NEXT_ID, false)
	say.emit(PRAISE[_rng.randi() % PRAISE.size()])


func _process(delta: float) -> void:
	if not active:
		return
	_step_time += delta
	if _done_t > 0.0:
		_done_t -= delta
		if _done_t <= 0.0:
			_go(_step + 1)
			return
	elif _step < STEPS.size() - 1:
		var left := ceili(NEXT_AFTER - _step_time)
		var b: Dictionary = _buttons[NEXT_ID]
		if left > 0:
			(b["label"] as Label3D).text = "NEXT SLIDE (%d)" % left
			if b["on"]:
				_enable(NEXT_ID, false)
		elif not b["on"]:
			(b["label"] as Label3D).text = "NEXT SLIDE >"
			_enable(NEXT_ID, true)
	if _play_t > 0.0:
		_play_t -= delta
		if _play_t <= 0.0:
			_played.clear()
			_deal()
			_publish()
	if _pack_t > 0.0:
		_pack_t -= delta
		if _pack_t <= 0.0:
			_pack_out = true
			show_pack.emit({"atlas": "Booster", "pos": [0, 0] if STEPS[_step]["id"] == "14_pack_tear" else [0, 1],
				"name": "Arcana Pack" if STEPS[_step]["id"] == "14_pack_tear" else "Celestial Pack"})
	if STEPS[_step]["phase"] == "jokers":
		_mark_jokers()
	if STEPS[_step]["phase"] == "adjust" and _done_t <= 0.0:
		_check_adjust()
	if STEPS[_step]["phase"] == "backgrounds" and _done_t <= 0.0:
		_check_backgrounds()
	if STEPS[_step]["phase"] == "achievement" and _done_t <= 0.0 and _unlocked and reward_on.is_valid() and not reward_on.call():
		_complete() # switched off in the Achievements page
	_fake_t -= delta
	if _fake_t <= 0.0:
		_fake_t = 0.25
		_update_fakes()
	_place_fakes()
	if _frames.size() > 1:
		_frame_t += delta
		_media_mat.albedo_texture = _frames[int(_frame_t * FRAME_FPS) % _frames.size()]


func press(id: int) -> void:
	match id:
		EXIT_ID, MENU_ID:
			leave.emit()
		NEXT_ID:
			if _buttons[NEXT_ID]["on"]:
				_go(_step + 1) # (skipped)
		AUDIO_ID:
			if _voice.stream != null:
				_voice.play()
		OK_ID:
			if STEPS[_step]["phase"] == "info" and _done_t <= 0.0:
				_complete()
		UNLOCK_ID:
			if STEPS[_step]["phase"] == "achievement" and not _unlocked:
				_unlocked = true
				unlock.emit()
				sfx.emit(true)
				_show_button(UNLOCK_ID, false)
				_status.text = "NOW SWITCH ITS REWARD OFF"
				hint.emit("Reward: a rainbow laser beam!")
		CARDS_LEFT_ID, CARDS_RIGHT_ID:
			if STEPS[_step]["id"] == "01_hands" and _done_t <= 0.0:
				left_handed = id == CARDS_RIGHT_ID # left-handed mode: the cards in the right hand
				set_hands.emit(left_handed)
				_show_step() # (the buttons' names in the texts)
				_complete()


# ---------------------------------------------------------------- main.gd's commands

## What would go to the game; how: the way it was done (see the top).
func command(c: Dictionary, how: String) -> void:
	match str(c.get("cmd", "")):
		"click":
			_toggle(int(c.get("target", -1)))
		"move":
			var a := _hand.find(int(c.get("target", -1)))
			var b := _hand.find(int(c.get("to", -1)))
			if a >= 0 and b >= 0:
				var id: int = _hand[a]
				_hand.remove_at(a)
				_hand.insert(b, id)
			_publish()
			if a >= 0 and b >= 0 and a != b and STEPS[_step]["phase"] == "cards" and _wanted("move", "") and _done_t <= 0.0:
				_complete() # (the MOVE page)
		"play", "discard":
			_cards_away(str(c["cmd"]), how)
		"sort":
			_sort(how)
		"buy":
			_buy(int(c.get("target", -1)), how)
		"open_pack":
			_pack_opened(how)
		"order":
			_order(str(c.get("ids", "")))
		"use":
			_use(int(c.get("target", -1)), how)
		"wheel_done":
			if STEPS[_step]["phase"] == "wheel":
				_wheel_out = false # (it goes by itself)
				_foil = _foil or bool(c.get("win", false))
				if bool(c.get("win", false)):
					hint.emit("WIN! Your first joker turns foil")
				_complete()
		"sell":
			_sell(int(c.get("target", -1)))
		"reroll":
			_reroll()
		"deck_view":
			_show_deck(bool(c.get("on", false)))


func _wanted(cmd: String, how: String) -> bool:
	var want: Array = STEPS[_step]["want"]
	return str(want[0]) == cmd and (desktop or str(want[1]) == "" or how in str(want[1]).split("|")) # ("stick|grip": either way)


func _nope() -> void:
	var text := _fill(str(STEPS[_step].get("nope", "")))
	if text != "":
		hint.emit(text)
	sfx.emit(false)


## Something that doesn't work here: a hint and the "wrong" sound.
func _wrong(text: String) -> void:
	hint.emit(text)
	sfx.emit(false)


## A hand over the deck: its cards in the picture frame (like the game's View Deck); the DECK page is done.
func _show_deck(on: bool) -> void:
	on = on and STEPS[_step]["phase"] == "cards"
	_deck_label.visible = on
	_media.visible = not on and not _frames.is_empty() or (not on and _video_port != null)
	_placeholder.visible = not on and not _media.visible
	_shape_frame(MEDIA if on or not _media.visible else _media_size)
	if not on:
		return
	var lines: Array = ["YOUR DECK: %d CARDS LEFT" % _deck.size()]
	for suit in SUITS.size():
		var ranks: Array = []
		for r in range(12, -1, -1):
			var id := suit * 13 + r + 1
			if _deck.has(id):
				ranks.append(["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"][r])
		lines.append("%s: %s" % [SUITS[suit], " ".join(ranks) if not ranks.is_empty() else "-"])
	_deck_label.text = "\n".join(lines)
	if _wanted("deck_view", "") and _done_t <= 0.0:
		_complete()


## The BACKGROUNDS page: DARK and CASINO each seen once.
func _check_backgrounds() -> void:
	if not backdrop_probe.is_valid():
		return
	var now := int(backdrop_probe.call())
	if now < BACKDROP_NAMES.size() and not _seen_backdrops.has(now): # (passthrough doesn't count, not every headset has it)
		if not _seen_backdrops.is_empty():
			sfx.emit(true)
		_seen_backdrops[now] = true
	var ticks: Array = []
	for i in BACKDROP_NAMES.size():
		ticks.append(("[X] " if _seen_backdrops.has(i) else "[ ] ") + str(BACKDROP_NAMES[i]))
	_status.text = "   ".join(ticks)
	_status.font_size = 30
	if _seen_backdrops.size() >= BACKDROP_NAMES.size():
		_status.font_size = 44
		_complete()


## The ADJUST page: Adjust VR Layout opened, the score tower's ball grabbed, moved, resized - and let go.
func _check_adjust() -> void:
	if not layout_probe.is_valid():
		return
	var p: Dictionary = layout_probe.call()
	if not _adjust.has("start"):
		_adjust["start"] = p.get("pos", Vector3.ZERO)
		_adjust["scale"] = float(p.get("scale", 1.0))
	var was := _adjust.duplicate()
	if p.get("calib", false):
		_adjust["open"] = true
	if p.get("held", false):
		_adjust["held"] = true
	if (p.get("pos", Vector3.ZERO) as Vector3).distance_to(_adjust["start"]) > 0.08:
		_adjust["moved"] = true
	if absf(float(p.get("scale", 1.0)) - float(_adjust["scale"])) > 0.08 * float(_adjust["scale"]):
		_adjust["sized"] = true
	if was.size() != _adjust.size():
		if _adjust.size() > 2:
			sfx.emit(true) # (each part done: a little ding)
	var ticks: Array = []
	for k in [["open", "MENU"], ["held", "GRAB"], ["moved", "MOVE"], ["sized", "RESIZE"]]:
		ticks.append(("[X] " if _adjust.has(k[0]) else "[ ] ") + str(k[1]))
	_status.text = "   ".join(ticks)
	_status.font_size = 26
	if _adjust.has("open") and _adjust.has("held") and _adjust.has("moved") and _adjust.has("sized") and not p.get("held", false):
		_status.font_size = 44
		_complete()


func _toggle(id: int) -> void:
	if STEPS[_step]["phase"] != "cards" or not _hand.has(id):
		return
	if _selected.has(id):
		_selected.erase(id)
	elif _selected.size() >= 5:
		_wrong("Up to 5 cards")
		return
	else:
		_selected[id] = true
	_publish()
	if STEPS[_step]["id"] == "02_select" and _selected.size() >= 2:
		_complete()


func _cards_away(cmd: String, how: String) -> void:
	if STEPS[_step]["phase"] != "cards" or _done_t > 0.0 or _play_t > 0.0:
		_publish() # (grabbed cards go back into the hand)
		return
	if _selected.is_empty():
		_wrong("Select some cards first")
		_publish()
		return
	if not _wanted(cmd, how):
		_nope()
		_publish()
		return
	var ids: Array = []
	for id in _hand:
		if _selected.has(id):
			ids.append(id)
	for id in ids:
		_hand.erase(id)
	_selected.clear()
	if cmd == "play":
		_played = ids # on the stand for a moment, then new cards
		_play_t = 1.3
	else:
		_deal() # (main.gd lets the thrown cards fly to the discard pile)
	_publish()
	_complete()


func _sort(how: String) -> void:
	if STEPS[_step]["phase"] != "cards":
		return
	_by_suit = not _by_suit
	_sort_hand()
	_publish()
	if _done_t > 0.0:
		return
	if _wanted("sort", how):
		_complete()
	elif str(STEPS[_step]["want"][0]) == "sort":
		_nope()


## The reroll machine's lever: a new joker on the counter (the REROLL page is done).
func _reroll() -> void:
	if STEPS[_step]["phase"] != "shop" or _done_t > 0.0:
		_wrong("No rerolls on this page")
		return
	if not _wanted("reroll", ""):
		_nope()
		return
	_rerolled = true
	_shop_bought = false
	_dollars -= 2
	_publish()
	_complete()


func _buy(uid: int, how: String) -> void:
	if STEPS[_step]["phase"] != "shop" or uid != (REROLL_ID if _rerolled else SHOP_ID) or _shop_bought:
		_publish()
		return
	if not _wanted("buy", how):
		_nope()
		_publish() # (it goes back onto the counter)
		return
	_shop_bought = true
	_dollars -= 4
	_publish()
	_complete()


func _pack_opened(how: String) -> void:
	_pack_out = false
	if STEPS[_step]["phase"] != "pack" or _done_t > 0.0:
		return
	if _wanted("open_pack", how):
		_complete()
	else:
		_nope()
		_pack_t = 1.4 # a new pack to try again
	_publish()


func _use(uid: int, how: String) -> void:
	if STEPS[_step]["phase"] != "use" or _used.has(uid) or _done_t > 0.0:
		_publish() # (it goes back into the stand)
		return
	if not _wanted("use", how):
		_nope()
		_publish()
		return
	_used[uid] = true
	if uid == PLANET_UID:
		effect.emit("planet")
	elif uid == TAROT_UID:
		_dollars *= 2 # The Hermit
	_publish()
	_complete()


func _sell(uid: int) -> void:
	if str(STEPS[_step]["want"][0]) != "sell" or not _joker_order.has(uid) or _done_t > 0.0:
		_wrong("Not on this page")
		_publish()
		return
	_joker_order.erase(uid)
	_dollars += 3
	_publish()
	_complete()


## The jokers were put in a new order on the board ("801;803;802", left to right).
func _order(ids: String) -> void:
	if STEPS[_step]["phase"] != "jokers":
		return
	if str(STEPS[_step]["want"][0]) != "order": # (moving them about on the sell page is fine)
		_joker_order = Array(ids.split(";", false)).map(func(s): return int(s))
		_publish()
		return
	var order: Array = []
	for s in ids.split(";", false):
		order.append(int(s))
	order.sort() # (only our three jokers count)
	if order != JOKER_UIDS:
		_publish()
		return
	_joker_order = Array(ids.split(";", false)).map(func(s): return int(s))
	_publish()
	if _done_t > 0.0:
		return
	if _joker_order == JOKER_GOAL:
		_complete()
	else:
		var now: Array = []
		for uid in _joker_order:
			now.append(str(JOKER_UIDS.find(uid) + 1))
		_wrong("Now: %s  -  wanted: 3 - 1 - 2" % " - ".join(now))


# ---------------------------------------------------------------- the cards

func _deal() -> void:
	while _hand.size() < HAND_SIZE:
		if _deck.is_empty():
			for id in range(1, 53):
				if not _hand.has(id) and not _played.has(id):
					_deck.append(id)
			for i in range(_deck.size() - 1, 0, -1): # shuffled
				var j := _rng.randi_range(0, i)
				var t = _deck[i]
				_deck[i] = _deck[j]
				_deck[j] = t
		_hand.append(_deck.pop_back())
	_sort_hand()


func _sort_hand() -> void:
	_hand.sort_custom(func(a: int, b: int) -> bool:
		var ra := (a - 1) % 13
		var rb := (b - 1) % 13
		var sa := (a - 1) / 13
		var sb := (b - 1) / 13
		if _by_suit:
			return sa < sb if sa != sb else ra > rb
		return ra > rb if ra != rb else sa < sb)


func _card_item(id: int, area: String) -> Dictionary:
	var r := (id - 1) % 13
	var s := (id - 1) / 13
	return {"k": "c", "id": id, "area": area, "f": "front", "set": "Default", "rank": RANKS[r], "suit": SUITS[s],
		"ca": "centers", "cp": [1, 0], "fa": "cards_1", "fp": [r, s], "ba": "centers", "bp": [0, 0], "hl": _selected.has(id),
		"x": 0.0, "y": 0.0, "w": 1.4, "h": 1.9}


## Draws the current state again (a card picture arrived late).
func redraw() -> void:
	_portrait_face()
	_publish()


func _publish() -> void:
	var phase: String = STEPS[_step]["phase"]
	var items: Array = []
	if phase == "cards":
		for id in _hand:
			items.append(_card_item(id, "hand"))
		for id in _played:
			items.append(_card_item(id, "play"))
	if phase == "shop" and not _shop_bought and not _rerolled:
		items.append({"k": "c", "id": SHOP_ID, "area": "shop_jokers", "f": "front", "set": "Joker", "name": "Joker",
			"key": "j_joker", "label": "Joker\n+4 Mult", "ca": "Joker", "cp": [0, 0], "cost": 4,
			"x": 0.0, "y": 0.0, "w": 1.4, "h": 1.9})
	elif phase == "shop" and not _shop_bought: # (after the reroll)
		items.append({"k": "c", "id": REROLL_ID, "area": "shop_jokers", "f": "front", "set": "Joker", "name": "Jolly Joker",
			"key": "j_jolly", "label": "Jolly Joker\n+8 Mult if the hand has a Pair", "ca": "Joker", "cp": [2, 0], "cost": 3,
			"x": 0.0, "y": 0.0, "w": 1.4, "h": 1.9})
	if phase == "jokers": # (with "3D Jokers" Off / Custom Only they stand as cards: these are their pictures)
		for uid in _joker_order:
			var n := JOKER_UIDS.find(uid)
			items.append({"k": "c", "id": uid, "area": "jokers", "f": "front", "set": "Joker", "name": JOKER_NAMES[n],
				"key": JOKER_KEYS[n], "ca": "Joker", "cp": JOKER_CELLS[n], "ed": "e_foil" if _foil and uid == JOKER_UIDS[0] else "",
				"x": 0.0, "y": 0.0, "w": 1.4, "h": 1.9})
	var consumables: Array = []
	if phase == "use":
		var card: Array = [PLANET_UID, "Planet", "Mercury", [0, 3]] if STEPS[_step]["id"] == "16_use_throw" \
				else [TAROT_UID, "Tarot", "The Hermit", [9, 0]]
		if not _used.has(card[0]):
			consumables.append({"uid": card[0], "set": card[1], "can_use": true, "can_sell": false})
			items.append({"k": "c", "id": card[0], "area": "consumeables", "f": "front", "set": card[1], "name": card[2],
				"label": card[2], "ca": "Tarot", "cp": card[3], "x": 0.0, "y": 0.0, "w": 1.4, "h": 1.9})
	var jokers: Array = []
	if phase == "jokers":
		for i in _joker_order.size():
			var uid: int = _joker_order[i]
			jokers.append({"uid": uid, "key": JOKER_KEYS[JOKER_UIDS.find(uid)], "slot": i + 1, "sell": 3, "value": "",
				"edition": "e_foil" if _foil and uid == JOKER_UIDS[0] else ""})
	var state_name := "SELECTING_HAND" if phase in ["cards", "adjust"] else ("SHOP" if phase == "shop" else "TUTORIAL") # (adjust: the score tower shows)
	var total := STEPS.size() - 1
	var state := {
		"in_run": true, "state_name": state_name, "won": false, "solatro": true, "tutorial": true,
		"round": {"ante": 1, "round": 1, "hands_left": 4, "discards_left": 3, "chips": _step, "dollars": _dollars, "hand": {}},
		"blind": {"name": "VR Tutorial", "chips": total, "boss": false, "chip_title": "TUTORIAL",
			"chip_text": "STEP %d / %d" % [mini(_step + 1, total), total], "chip_back": "LEARN THE\nVR MOVES"},
		"deck": {"remaining": _deck.size(), "total": 52, "back_key": "b_red", "back_sprite": {"atlas": "centers", "pos": [0, 0]}},
		"jokers": jokers, "consumables": consumables, "shop_open": phase == "shop", "reroll_cost": 2, "can_reroll": phase == "shop",
	}
	var scene := {"room": {"w": 20, "h": 11.5}, "state_name": state_name, "groups": [], "items": items}
	publish.emit(scene, state)


## The jokers' numbers float over them (they come a moment after the state, so: until all have one).
func _mark_jokers() -> void:
	if not joker_node.is_valid():
		return
	for uid in JOKER_UIDS:
		var mark = _joker_marks.get(uid)
		if mark != null and is_instance_valid(mark):
			continue
		var node = joker_node.call(uid)
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var l := Label3D.new()
		l.text = str(JOKER_UIDS.find(uid) + 1)
		l.font_size = 96
		l.pixel_size = 0.0008
		l.modulate = Color(1.0, 0.85, 0.3)
		l.outline_size = 16
		l.outline_modulate = Color(0.05, 0.03, 0.06)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 15
		l.position = Vector3(0, 0.2, 0)
		(node as Node3D).add_child(l)
		GameFont.apply_to(l)
		_joker_marks[uid] = l


# ---------------------------------------------------------------- stand-in texts

## Without the game's pictures (they come from the running game) a card would be blank: then a
## label says what it is - "K of Hearts", "JOKER 1" ... - floating over it.
func _update_fakes() -> void:
	if not node_for.is_valid():
		return
	var want := {} # key -> [kind, id, text]
	var phase: String = STEPS[_step]["phase"]
	if phase == "cards" and CardArt.has_atlas("centers") and not CardArt.has_atlas("cards_1"):
		for id in _hand:
			want["hand:%d" % id] = ["hand", id, _card_name(id)]
		for id in _played:
			want["play:%d" % id] = ["play", id, _card_name(id)]
	if not CardArt.has_atlas("Joker"):
		if phase == "shop" and not _shop_bought:
			if _rerolled:
				want["shop:%d" % REROLL_ID] = ["shop", REROLL_ID, "JOLLY JOKER\n+8 Mult with a Pair"]
			else:
				want["shop:%d" % SHOP_ID] = ["shop", SHOP_ID, "JOKER\n+4 Mult"]
		if phase == "jokers":
			var names := ["JOKER\n+4 Mult", "GREEDY JOKER\nDiamonds: +3 Mult", "LUSTY JOKER\nHearts: +3 Mult"]
			for uid in _joker_order:
				want["joker:%d" % uid] = ["joker", uid, names[JOKER_UIDS.find(uid)]]
	if phase == "use" and not CardArt.has_atlas("Tarot"):
		if not _used.has(PLANET_UID) and STEPS[_step]["id"] == "16_use_throw":
			want["use:%d" % PLANET_UID] = ["use", PLANET_UID, "MERCURY\n(planet)\nlevels up Pair"]
		if not _used.has(TAROT_UID) and STEPS[_step]["id"] == "17_use_hand":
			want["use:%d" % TAROT_UID] = ["use", TAROT_UID, "THE HERMIT\n(tarot)\ndoubles your money"]
	if phase == "pack" and _pack_out and not CardArt.has_atlas("Booster"):
		want["pack:0"] = ["pack", 0, "BOOSTER PACK"]
	for key in _fakes.keys():
		if not want.has(key):
			(_fakes[key][0] as Label3D).queue_free()
			_fakes.erase(key)
	for key in want:
		if _fakes.has(key):
			continue
		var w: Array = want[key]
		var l := Label3D.new()
		l.text = str(w[2])
		l.font_size = 30 if w[0] in ["hand", "play"] else 26
		l.pixel_size = 0.0005
		l.modulate = Color(1.0, 0.95, 0.85)
		var id: int = w[1]
		if w[0] in ["hand", "play"] and ((id - 1) / 13) % 2 == 0: # hearts and diamonds in red
			l.modulate = Color(1.0, 0.45, 0.4)
		l.outline_size = 8
		l.outline_modulate = Color(0.05, 0.03, 0.06)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 14
		l.top_level = true
		add_child(l)
		GameFont.apply_to(l)
		_fakes[key] = [l, w[0], id]


func _place_fakes() -> void:
	for key in _fakes:
		var f: Array = _fakes[key]
		var l: Label3D = f[0]
		var node = node_for.call(str(f[1]), int(f[2])) if node_for.is_valid() else null
		l.visible = node is Node3D and is_instance_valid(node) and (node as Node3D).is_visible_in_tree()
		if not l.visible:
			continue
		var n := node as Node3D
		match str(f[1]):
			"hand", "play": # over the upper part of the card (the fan spreads them apart there)
				l.global_position = n.global_position + n.global_basis.y.normalized() * 0.03
			"joker":
				l.global_position = n.global_position + Vector3(0, 0.13, 0)
			_:
				l.global_position = n.global_position + Vector3(0, 0.07, 0)


func _clear_fakes() -> void:
	for key in _fakes:
		(_fakes[key][0] as Label3D).queue_free()
	_fakes.clear()


func _card_name(id: int) -> String:
	var r := (id - 1) % 13
	var s := (id - 1) / 13
	return "%s\nof %s" % [["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"][r], SUITS[s]]


# ---------------------------------------------------------------- the board

func _fill(text: String) -> String:
	return text.format({
		"cards": "right" if left_handed else "left",
		"point": "left" if left_handed else "right",
		"A": "X" if left_handed else "A",
		"B": "Y" if left_handed else "B",
		"menu": "A" if left_handed else "X"})


func _show_step() -> void:
	var s: Dictionary = STEPS[_step]
	var total := STEPS.size() - 1
	_counter.text = "STEP %d / %d" % [_step + 1, total] if _step < total else "FINISHED"
	_bar.scale.x = maxf(float(_step) / total, 0.001)
	_bar.position.x = -BOARD.x * 0.45 * (1.0 - _bar.scale.x)
	_title.text = _fill(str(s["title"]))
	for c in _text.get_children():
		c.free()
	var y := 0.0
	for para in _fill(str(s["text"])).split("\n\n"):
		var l := Label3D.new()
		l.text = para
		l.font_size = 34
		l.pixel_size = 0.0005
		l.width = TEXT_W / l.pixel_size
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		l.modulate = Color(1.0, 0.8, 0.35) if para.begins_with("YOUR TURN") else Color(1.0, 0.95, 0.85)
		l.outline_size = 0
		l.position.y = y
		_text.add_child(l)
		var font: Font = GameFont.font if GameFont.font != null else ThemeDB.fallback_font
		var h := font.get_multiline_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, l.width, l.font_size, -1,
				TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
		y -= h * l.pixel_size + 0.01
	var hands := str(s["id"]) == "01_hands"
	var last := _step == total
	_status.text = "" if hands or last or s["phase"] in ["achievement", "info"] else "YOUR TURN!"
	_status.modulate = Color(1.0, 0.8, 0.35)
	_show_button(CARDS_LEFT_ID, hands)
	_show_button(CARDS_RIGHT_ID, hands)
	_show_button(MENU_ID, last)
	_show_button(UNLOCK_ID, s["phase"] == "achievement")
	_show_button(OK_ID, s["phase"] == "info")
	if _deck_label != null:
		_deck_label.visible = false
	_status.font_size = 44
	_show_button(NEXT_ID, not last)
	_enable(NEXT_ID, false)
	(_buttons[NEXT_ID]["label"] as Label3D).text = "NEXT SLIDE (%d)" % int(NEXT_AFTER)
	_load_media(str(s["id"]))
	_load_voice(str(s["id"]))
	GameFont.apply_to(self)


func _build_board() -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.18, -0.5) # over the blind chip and the cards, like Solatro's rules
	root.rotation_degrees.x = -12.0 # leaning back a little, towards your eyes
	add_child(root)
	_box(root, Vector3(BOARD.x + 0.02, BOARD.y + 0.02, 0.01), Vector3(0, BOARD.y * 0.5, -0.002), _mat(Color(0.85, 0.65, 0.25), 0.3, 0.8)) # brass frame
	_box(root, Vector3(BOARD.x, BOARD.y, 0.012), Vector3(0, BOARD.y * 0.5, 0), _mat(Color(0.12, 0.04, 0.1), 0.8, 0.0))
	# Jimbo, the assistant: his card in the top left corner, sticking out of the frame
	_portrait = Node3D.new()
	_portrait.position = Vector3(-BOARD.x * 0.5 + 0.01, BOARD.y - 0.005, 0.012)
	_portrait.rotation_degrees.z = 10.0
	root.add_child(_portrait)
	_box(_portrait, Vector3(0.075, 0.1, 0.003), Vector3.ZERO, _mat(Color(0.95, 0.93, 0.88), 0.8, 0.0))
	_portrait_face()
	_header = _label(root, "JIMBO'S VR TUTORIAL", 34, Color(0.6, 1.4, 2.0), Vector3(-0.32, BOARD.y - 0.028, 0.007))
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.outline_size = 8
	_counter = _label(root, "", 30, Color(0.75, 0.7, 0.8), Vector3(BOARD.x * 0.5 - 0.03, BOARD.y - 0.028, 0.007))
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# the progress bar under the header
	_box(root, Vector3(BOARD.x * 0.9, 0.006, 0.002), Vector3(0, BOARD.y - 0.05, 0.007), _mat(Color(0.25, 0.15, 0.25), 0.8, 0.0))
	_bar = _box(root, Vector3(BOARD.x * 0.9, 0.007, 0.003), Vector3(0, BOARD.y - 0.05, 0.008), _glow(Color(0.3, 1.0, 0.5)))
	_title = _label(root, "", 52, Color(1.0, 0.8, 0.35), Vector3(0, BOARD.y - 0.085, 0.007))
	_title.outline_size = 8
	# the picture (photo, animation or video) on the left
	_frame_boxes = [
		_box(root, Vector3(MEDIA.x + 0.012, MEDIA.y + 0.012, 0.002), MEDIA_AT - Vector3(0, 0, 0.001), _mat(Color(0.85, 0.65, 0.25), 0.3, 0.8)),
		_box(root, Vector3(MEDIA.x, MEDIA.y, 0.002), MEDIA_AT, _mat(Color(0.05, 0.02, 0.05), 0.9, 0.0))]
	_media = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = MEDIA
	_media.mesh = quad
	_media_mat = StandardMaterial3D.new()
	_media_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_media.material_override = _media_mat
	_media.position = MEDIA_AT + Vector3(0, 0, 0.0015)
	_media.visible = false
	root.add_child(_media)
	_placeholder = _label(root, "", 22, Color(0.55, 0.5, 0.6), MEDIA_AT + Vector3(0, 0, 0.002))
	_placeholder.width = MEDIA.x * 0.9 / _placeholder.pixel_size
	_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text = Node3D.new() # one text block per paragraph (an empty line in a wrapped text would be dropped)
	_text.position = Vector3(TEXT_X, BOARD.y - 0.125, 0.007)
	root.add_child(_text)
	_status = _label(root, "", 44, Color(1.0, 0.8, 0.35), Vector3(TEXT_X + TEXT_W * 0.5, 0.115, 0.007))
	_status.outline_size = 8
	# the buttons
	_button(root, "EXIT", EXIT_ID, Vector3(-BOARD.x * 0.5 + 0.075, 0.04, 0.0), Vector2(0.11, 0.045), Color(0.75, 0.12, 0.14))
	_button(root, "PLAY AUDIO", AUDIO_ID, MEDIA_AT + Vector3(0, -MEDIA.y * 0.5 - 0.035, -0.008), Vector2(0.13, 0.032), Color(0.33, 0.45, 0.62), 26)
	_button(root, "NEXT SLIDE", NEXT_ID, Vector3(BOARD.x * 0.5 - 0.1, 0.04, 0.0), Vector2(0.17, 0.045), Color(0.2, 0.62, 0.4), 30)
	_button(root, "BACK TO MENU", MENU_ID, Vector3(BOARD.x * 0.5 - 0.1, 0.04, 0.0), Vector2(0.17, 0.045), Color(0.2, 0.62, 0.4), 30)
	_button(root, "LEFT HAND: POINTER\nRIGHT HAND: CARDS", CARDS_RIGHT_ID, Vector3(TEXT_X + 0.1, 0.12, 0.0), Vector2(0.19, 0.07), Color(0.85, 0.3, 0.1), 24)
	_button(root, "LEFT HAND: CARDS\nRIGHT HAND: POINTER", CARDS_LEFT_ID, Vector3(TEXT_X + 0.305, 0.12, 0.0), Vector2(0.19, 0.07), Color(0.0, 0.45, 0.85), 24)
	_button(root, "GOT IT", OK_ID, Vector3(TEXT_X + TEXT_W * 0.5, 0.12, 0.0), Vector2(0.2, 0.06), Color(0.2, 0.62, 0.4), 40)
	_deck_label = _label(root, "", 22, Color(1.0, 0.95, 0.85), MEDIA_AT + Vector3(0, 0, 0.003))
	_deck_label.width = MEDIA.x * 0.95 / _deck_label.pixel_size
	_deck_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_deck_label.visible = false
	_button(root, "UNLOCK", UNLOCK_ID, Vector3(TEXT_X + TEXT_W * 0.5, 0.12, 0.0), Vector2(0.2, 0.06), Color(0.85, 0.6, 0.1), 40)
	_voice = AudioStreamPlayer3D.new()
	_voice.position = Vector3(0, BOARD.y * 0.5, 0.05)
	_voice.unit_size = 4.0
	root.add_child(_voice)


## Jimbo's card picture (once the game sent the joker pictures).
func _portrait_face() -> void:
	if _portrait_art or _portrait == null or not CardArt.has_atlas("Joker"):
		return
	_portrait_art = true
	var face := Node3D.new()
	face.position.z = 0.0016
	_portrait.add_child(face)
	CardArt.apply_layers(face, [CardArt.material("Joker", [0, 0])], Vector2(0.071, 0.095), 0.0, 0.0004, 1)


func _button(parent: Node3D, text: String, id: int, at: Vector3, size: Vector2, colour: Color, font_size := 34) -> void:
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	var m := _mat(colour, 0.5, 0.0)
	_box(root, Vector3(size.x, size.y, 0.012), Vector3(0, 0, 0.008), m)
	var l := _label(root, text, font_size, Color(1, 1, 1), Vector3(0, 0, 0.0145))
	l.outline_size = 6
	l.outline_modulate = Color(0.05, 0.03, 0.06)
	var body := StaticBody3D.new()
	body.set_meta("target_id", id)
	body.set_meta("kind", "vrtut")
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x + 0.01, size.y + 0.01, 0.03)
	shape.shape = bs
	body.add_child(shape)
	body.position.z = 0.01
	root.add_child(body)
	_bodies.append(body)
	_buttons[id] = {"root": root, "label": l, "mat": m, "colour": colour, "on": true, "body": body}


func _show_button(id: int, on: bool) -> void:
	(_buttons[id]["root"] as Node3D).visible = on
	_enable(id, on)


## A button that can't be pressed (yet) is grey, and the beam goes through it.
func _enable(id: int, on: bool) -> void:
	var b: Dictionary = _buttons[id]
	b["on"] = on
	var c: Color = b["colour"]
	(b["mat"] as StandardMaterial3D).albedo_color = c if on else Color(0.3, 0.28, 0.32)
	(b["label"] as Label3D).modulate = Color(1, 1, 1) if on else Color(0.65, 0.62, 0.68)
	var root := b["root"] as Node3D
	(b["body"] as StaticBody3D).collision_layer = 1 if (on and root.visible and is_visible_in_tree()) else 0


## Hidden objects must not be hit: an invisible body still stops the beam in Godot.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		for id in _buttons:
			_enable(id, _buttons[id]["on"])


# ---------------------------------------------------------------- pictures and voice

func _clear_media() -> void:
	_frames.clear()
	_frame_t = 0.0
	_media_mat.albedo_texture = null
	_media.visible = false
	if _video_port != null:
		_video_port.queue_free()
		_video_port = null


func _load_media(id: String) -> void:
	_clear_media()
	for dir in MEDIA_DIRS:
		for ext in ["png", "jpg", "jpeg", "webp"]:
			var tex := _texture(dir + id + "." + ext)
			if tex != null:
				_frames = [tex]
				break
		if _frames.is_empty():
			_frames = _folder_frames(dir + id)
		if not _frames.is_empty():
			_media_mat.albedo_texture = _frames[0]
			_fit_media(_frames[0].get_size())
			break
		if ResourceLoader.exists(dir + id + ".ogv") or FileAccess.file_exists(dir + id + ".ogv"):
			_play_video(dir + id + ".ogv")
			break
	if not _media.visible:
		_shape_frame(MEDIA) # (the placeholder: the whole room)
	var none := id.ends_with("_done") and not _media.visible # (the last page needs no picture: no empty frame either)
	for b in _frame_boxes:
		(b as Node3D).visible = not none
	_placeholder.visible = not _media.visible and not none
	_placeholder.text = "PHOTO / ANIMATION\n\ntutorial/%s.png\n(or .jpg, .ogv, or a folder of pictures)" % id


## The picture fills the frame as far as it can without being stretched.
func _fit_media(size: Vector2) -> void:
	_media.visible = true
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var k := minf(MEDIA.x / size.x, MEDIA.y / size.y)
	_media_size = size * k
	(_media.mesh as QuadMesh).size = _media_size
	_shape_frame(_media_size)


## The gold rim and the dark back fit round the picture (a square video gets a square frame).
func _shape_frame(size: Vector2) -> void:
	if _frame_boxes.size() < 2:
		return
	((_frame_boxes[0] as MeshInstance3D).mesh as BoxMesh).size = Vector3(size.x + 0.012, size.y + 0.012, 0.002)
	((_frame_boxes[1] as MeshInstance3D).mesh as BoxMesh).size = Vector3(size.x, size.y, 0.002)


func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D: # (the pictures in the game's package: imported without mipmaps, they would shimmer in VR)
			var img := (res as Texture2D).get_image()
			if img != null and not img.is_empty() and not img.is_compressed() and not img.has_mipmaps():
				img.generate_mipmaps()
				return ImageTexture.create_from_image(img)
			return res
	if FileAccess.file_exists(path): # (not imported: a picture added to user://, or not yet seen by the editor)
		var img := _image(FileAccess.get_file_as_bytes(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


## A picture by what the file is, not by its name (a PNG saved as .jpg loads too). Big photos are
## made smaller (the frame is small) and get mipmaps, so they don't shimmer in VR.
func _image(data: PackedByteArray) -> Image:
	if data.size() < 12:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if data[0] == 0x89 and data[1] == 0x50:
		err = img.load_png_from_buffer(data)
	elif data[0] == 0xFF and data[1] == 0xD8:
		err = img.load_jpg_from_buffer(data)
	elif data.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(data)
	if err != OK or img.is_empty():
		return null
	var big := maxi(img.get_width(), img.get_height())
	if big > 1600:
		var k := 1600.0 / big
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps()
	return img


func _folder_frames(path: String) -> Array:
	var dir := DirAccess.open(path)
	if dir == null:
		return []
	var names: Array = []
	for f in dir.get_files():
		var file := str(f).trim_suffix(".import").trim_suffix(".remap") # (exported: the pictures are listed like this)
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] and not names.has(file):
			names.append(file)
	names.sort()
	var frames: Array = []
	for n in names:
		var tex := _texture(path + "/" + str(n))
		if tex != null:
			frames.append(tex)
	return frames


func _play_video(path: String) -> void:
	var stream: VideoStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as VideoStream
	if stream == null:
		var theora := VideoStreamTheora.new()
		theora.file = path
		stream = theora
	_video_port = SubViewport.new()
	_video_port.size = Vector2i(480, 480) # (the clips are square; _fit_video takes the real size)
	_video_port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_video_port)
	var player := VideoStreamPlayer.new()
	player.stream = stream
	player.expand = true
	player.size = Vector2(480, 480)
	player.finished.connect(player.play) # (round and round)
	player.volume_db = -80.0 # (the spoken line is its own file)
	_video_port.add_child(player)
	player.play()
	_media_mat.albedo_texture = _video_port.get_texture()
	_fit_media(Vector2(480, 480))
	_fit_video(player, _video_port)


## Once the first picture of the video is there: the frame takes the video's own shape (a square
## clip stays square instead of being stretched to 16:9).
func _fit_video(player: VideoStreamPlayer, port: SubViewport) -> void:
	for i in 60:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if _video_port != port or not is_instance_valid(player):
			return # (another page by now)
		var tex := player.get_video_texture()
		if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
			var size := Vector2(tex.get_size())
			port.size = Vector2i(size)
			player.size = size
			var vis := _media.visible # (the deck list may be over it right now)
			_fit_media(size)
			_media.visible = vis
			if _deck_label != null and _deck_label.visible:
				_shape_frame(MEDIA)
			return


func _load_voice(id: String) -> void:
	_voice.stop()
	_voice.stream = null
	for dir in MEDIA_DIRS:
		for ext in ["ogg", "mp3", "wav"]:
			var path: String = dir + id + "." + ext
			var stream: AudioStream = null
			if ResourceLoader.exists(path):
				stream = load(path) as AudioStream
			elif FileAccess.file_exists(path) and ext == "ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			elif FileAccess.file_exists(path) and ext == "mp3":
				var mp3 := AudioStreamMP3.new()
				mp3.data = FileAccess.get_file_as_bytes(path)
				stream = mp3
			if stream != null:
				_voice.stream = stream
				break
		if _voice.stream != null:
			break
	_show_button(AUDIO_ID, _voice.stream != null)
	if _voice.stream != null and visible:
		_voice.play()


# ---------------------------------------------------------------- helpers

func _label(parent: Node3D, text: String, size: int, colour: Color, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0005
	l.modulate = colour
	l.outline_size = 0
	l.outline_modulate = Color(0.05, 0.03, 0.06)
	l.position = at
	parent.add_child(l)
	return l


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _mat(colour: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 0.8
	return m
