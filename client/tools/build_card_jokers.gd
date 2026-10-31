extends SceneTree
## Builds the jokers that are a flat card in the game (Loyalty Card, Red Card, Business Card,
## Hanging Chad) from code: a thin card in a little wooden stand, its print made of real shapes and
## text (the 3D generator makes blocks of flat things and can't write).
##
##   ... --headless --xr-mode off --path client -s res://tools/build_card_jokers.gd [-- key ...]
##
## Credit Card and Driver's License are cards too (Alex's feedback 2026-10-31: a thin card, not
## a thick slab or a figure holding it).
##
## These jokers are not in tools/ai_jokers.json, so build_ai_jokers.gd leaves them alone.

const W := 0.062                   # card size (a playing card's proportions, like the game)
const H := 0.088
const T := 0.0016
const LEAN := 10.0                 # the card leans back in its stand (degrees)

var _suit_script: Script


func _init() -> void:
	_suit_script = load("res://jokers/suit_shape.gd")
	var only := OS.get_cmdline_user_args()
	var builders := {
		"j_loyalty_card": _loyalty,
		"j_red_card": _red_card,
		"j_business": _business,
		"j_hanging_chad": _hanging_chad,
		"j_credit_card": _credit_card,
		"j_drivers_license": _drivers_license,
	}
	for key in builders:
		if not only.is_empty() and not only.has(key):
			continue
		var root := Node3D.new()
		root.name = key
		root.set_script(load("res://jokers/augmented_joker.gd"))
		(builders[key] as Callable).call(root)
		_own(root, root)
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, "res://jokers/%s.tscn" % key)
		root.free()
		print("%s written" % key)
	quit()


# ---------------------------------------------------------------- the four cards

## Stamp card of "Joker's Deli": a stamp per hand played, glowing when the next hand pays x4.
func _loyalty(root: Node3D) -> void:
	var card := _card(root, Vector2(W, H), Color(0.96, 0.96, 0.94))
	var logo := _disc(card, 0.5, Vector3(0, 0.067, 0), Color(0.86, 0.22, 0.2))
	logo.scale = Vector3(0.05, 1, 0.028) # an oval
	_text(card, "Joker's", Vector3(0, 0.068, 0.0012), 0.000168, Color.WHITE)
	_box(card, Vector3(0.024, 0.008, 0.0006), Vector3(0, 0.051, 0.0004), Color(0.16, 0.5, 0.35))
	_text(card, "DELI", Vector3(0, 0.051, 0.0009), 0.000088, Color.WHITE)
	_text(card, "LOYALTY CARD", Vector3(0, 0.041, 0.0004), 0.000064, Color(0.45, 0.45, 0.5))
	var stamps := Node3D.new()
	stamps.name = "Stamps"
	_place(card, stamps, Vector3.ZERO)
	for i in 6:
		var at := Vector3((i % 3 - 1) * 0.018, 0.027 - (i / 3) * 0.015, 0.0002)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0047
		tm.outer_radius = 0.0058
		ring.mesh = tm
		ring.rotation_degrees.x = 90
		ring.scale = Vector3(1, 0.15, 1)
		ring.material_override = _mat(Color(0.86, 0.22, 0.2))
		_place(card, ring, at)
		var stamp := Node3D.new() # filled in order (Count): the first N are shown
		stamp.name = "Stamp%d" % (i + 1)
		stamp.position = at
		stamps.add_child(stamp)
		var ink := _disc(stamp, 0.0042, Vector3(0, 0, 0.0004), Color(0.42, 0.45, 0.55))
		_text(stamp, "J", Vector3(0, 0, 0.0009), 0.000072, Color(0.85, 0.86, 0.9))
	root.set("count_parent", NodePath("Stand/Card/Stamps"))
	root.set("count_source", "extra[\"every\"] - ab[\"loyalty_remaining\"]")
	root.set("glow_node", NodePath("Stand/Card"))
	root.set("glow_source", "1.0 - min(ab[\"loyalty_remaining\"], 1.0)")
	root.set("glow_energy", 1.5)


## Plain red card (the game's art): glows redder with the Mult it collected.
func _red_card(root: Node3D) -> void:
	var card := _card(root, Vector2(W, H), Color(0.78, 0.16, 0.16))
	_box(card, Vector3(W - 0.006, H - 0.006, 0.0004), Vector3(0, H * 0.5, 0.0002), Color(0.93, 0.3, 0.27))
	_text(card, "JOKER", Vector3(0.017, 0.007, 0.0006), 0.000052, Color(0.7, 0.14, 0.14))
	root.set("glow_node", NodePath("Stand/Card"))
	root.set("glow_source", "clamp(ab[\"mult\"] / 30.0, 0.0, 1.0)")
	root.set("glow_energy", 0.4)


## Joseph J. Joker's business card, landscape in the stand, the back plain white.
func _business(root: Node3D) -> void:
	var card := _card(root, Vector2(0.085, 0.05), Color(0.97, 0.96, 0.92))
	_text(card, "JOSEPH J. JOKER", Vector3(0, 0.03, 0.0004), 0.000104, Color(0.12, 0.12, 0.14))
	_box(card, Vector3(0.05, 0.0006, 0.0003), Vector3(0, 0.024, 0.0002), Color(0.3, 0.3, 0.32))
	_text(card, "Professional Jester", Vector3(0, 0.018, 0.0004), 0.000060, Color(0.35, 0.35, 0.38))
	_text(card, "Face cards pay out", Vector3(0, 0.011, 0.0004), 0.000048, Color(0.45, 0.45, 0.48))


## A ballot, J ? K E R: the O was punched out and hangs on by a corner.
func _hanging_chad(root: Node3D) -> void:
	var card := _card(root, Vector2(W, H), Color(0.94, 0.95, 0.97))
	var blue := Color(0.3, 0.42, 0.55)
	_text(card, "BALLOT", Vector3(0, 0.078, 0.0004), 0.000112, blue)
	var letters := ["J", "", "K", "E", "R"]
	for i in letters.size():
		var y := 0.064 - i * 0.0135
		var empty: bool = letters[i] == ""
		_box(card, Vector3(0.036, 0.0105, 0.0004), Vector3(-0.004, y, 0.0002), Color(0.12, 0.13, 0.16) if empty else Color(0.82, 0.88, 0.94))
		_box(card, Vector3(0.008, 0.0012, 0.0004), Vector3(0.021, y, 0.0002), blue) # the line to the margin
		if not empty:
			_text(card, letters[i], Vector3(-0.004, y, 0.0007), 0.000104, blue)
		else: # the chad: the punched-out piece still hanging on by its upper right corner
			var hinge := Node3D.new()
			_place(card, hinge, Vector3(0.014, y + 0.005, 0.0012))
			hinge.rotation_degrees.z = 22
			_box(hinge, Vector3(0.036, 0.0105, 0.0006), Vector3(-0.018, -0.00525, 0), Color(0.82, 0.88, 0.94))
			_text(hinge, "O", Vector3(-0.018, -0.00525, 0.0005), 0.000104, blue)


## A golden credit card (landscape, like a real one): chip, number, the holder's name and the
## credit limit of -$20 the joker gives.
func _credit_card(root: Node3D) -> void:
	var w := 0.0856
	var h := 0.054
	var card := _card(root, Vector2(w, h), Color(0.96, 0.72, 0.16))
	_box(card, Vector3(w - 0.005, h - 0.005, 0.0004), Vector3(0, h * 0.5, 0.0002), Color(0.99, 0.8, 0.26))
	_box(card, Vector3(w - 0.005, 0.007, 0.0004), Vector3(0, h - 0.009, 0.0004), Color(0.86, 0.24, 0.18))
	_text(card, "JOKER BANK", Vector3(0, h - 0.009, 0.0008), 0.000080, Color.WHITE)
	_box(card, Vector3(0.012, 0.0095, 0.0006), Vector3(-0.028, 0.03, 0.0004), Color(0.8, 0.78, 0.7)) # the chip
	_box(card, Vector3(0.012, 0.0006, 0.0003), Vector3(-0.028, 0.03, 0.0008), Color(0.55, 0.5, 0.4))
	_box(card, Vector3(0.0006, 0.0095, 0.0003), Vector3(-0.028, 0.03, 0.0008), Color(0.55, 0.5, 0.4))
	_text(card, "4242 1337 0000 2020", Vector3(0, 0.019, 0.0006), 0.000088, Color(0.35, 0.18, 0.05))
	_text(card, "J. JOKER", Vector3(-0.022, 0.009, 0.0006), 0.000064, Color(0.35, 0.18, 0.05))
	_text(card, "LIMIT -$20", Vector3(0.024, 0.009, 0.0006), 0.000064, Color(0.75, 0.15, 0.12))
	_text(card, "CREDIT", Vector3(0.024, 0.03, 0.0006), 0.000080, Color(0.75, 0.15, 0.12))


## Jimbo's driver's license (landscape): header, his photo, a few lines of data.
func _drivers_license(root: Node3D) -> void:
	var w := 0.0856
	var h := 0.054
	var card := _card(root, Vector2(w, h), Color(0.86, 0.9, 0.96))
	var blue := Color(0.2, 0.33, 0.6)
	_box(card, Vector3(w - 0.004, 0.009, 0.0004), Vector3(0, h - 0.0075, 0.0002), blue)
	_text(card, "DRIVER'S LICENSE", Vector3(0, h - 0.0075, 0.0006), 0.000088, Color.WHITE)
	# the photo: Jimbo's face under his red and blue jester hat
	_box(card, Vector3(0.024, 0.03, 0.0004), Vector3(-0.026, 0.021, 0.0002), Color(0.62, 0.74, 0.86))
	_disc(card, 0.0075, Vector3(-0.026, 0.017, 0.0006), Color(0.97, 0.95, 0.9))
	_box(card, Vector3(0.009, 0.007, 0.0005), Vector3(-0.0305, 0.028, 0.0008), Color(0.85, 0.2, 0.2))
	_box(card, Vector3(0.009, 0.007, 0.0005), Vector3(-0.0215, 0.028, 0.0008), Color(0.25, 0.4, 0.8))
	_disc(card, 0.0018, Vector3(-0.036, 0.0265, 0.0010), Color(0.98, 0.8, 0.2))
	_disc(card, 0.0018, Vector3(-0.016, 0.0265, 0.0010), Color(0.98, 0.8, 0.2))
	_disc(card, 0.0010, Vector3(-0.029, 0.018, 0.0010), Color(0.1, 0.1, 0.12))
	_disc(card, 0.0010, Vector3(-0.023, 0.018, 0.0010), Color(0.1, 0.1, 0.12))
	_box(card, Vector3(0.006, 0.0012, 0.0004), Vector3(-0.026, 0.0135, 0.0010), Color(0.8, 0.2, 0.25))
	var ink := Color(0.15, 0.17, 0.25)
	_text(card, "NAME  JIMBO", Vector3(0.016, 0.034, 0.0006), 0.000064, ink)
	_text(card, "CLASS  JOKER", Vector3(0.016, 0.026, 0.0006), 0.000064, ink)
	_text(card, "ENHANCED  16+", Vector3(0.016, 0.018, 0.0006), 0.000064, ink)
	_text(card, "X3 MULT", Vector3(0.016, 0.009, 0.0006), 0.000080, Color(0.8, 0.15, 0.15))


# ---------------------------------------------------------------- parts

## The wooden stand with the card in it; returns the card (its origin at its bottom middle, the
## print on +z, towards the player).
func _card(root: Node3D, size: Vector2, colour: Color) -> MeshInstance3D:
	var stand := Node3D.new()
	stand.name = "Stand"
	root.add_child(stand)
	var wood := Color(0.42, 0.25, 0.13)
	_box(stand, Vector3(size.x + 0.01, 0.007, 0.028), Vector3(0, 0.0035, 0), wood)
	_box(stand, Vector3(size.x + 0.004, 0.006, 0.004), Vector3(0, 0.01, -0.004), wood.darkened(0.15))
	var card := MeshInstance3D.new()
	card.name = "Card"
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, T)
	card.mesh = bm
	card.material_override = _mat(colour)
	stand.add_child(card)
	# the box mesh is centred: everything else on the card is placed from its bottom edge
	var pivot := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-LEAN), 0, 0)), Vector3(0, 0.006, -0.0015))
	card.transform = pivot * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0))
	# children are placed relative to the card's bottom middle: shift them down by half its height
	card.set_meta("half", size.y * 0.5)
	return card


func _place(parent: Node3D, n: Node3D, at: Vector3) -> void:
	var half: float = parent.get_meta("half", 0.0)
	n.position = at - Vector3(0, half, -T * 0.5 if half > 0.0 else 0.0)
	parent.add_child(n)


func _box(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(colour)
	_place(parent, mi, at)
	return mi


func _disc(parent: Node3D, radius: float, at: Vector3, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.0006
	cm.radial_segments = 32
	mi.mesh = cm
	mi.material_override = _mat(colour)
	_place(parent, mi, at)
	mi.rotation_degrees.x = 90
	return mi


func _text(parent: Node3D, text: String, at: Vector3, pixel: float, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = pixel
	l.modulate = colour
	l.outline_size = 0
	l.double_sided = false # (the back of the card stays plain, not mirror writing)
	_place(parent, l, at)
	return l


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
