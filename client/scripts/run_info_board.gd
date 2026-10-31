class_name RunInfoBoard
extends Node3D
## The game's Run Info (its "Blinds" page) as a board of its own that stays up during the run: the
## ante's Small Blind, Big Blind and boss side by side, each with its state (Current / Upcoming /
## Defeated / Skipped), the score it needs, its reward, the boss rule and the tag for skipping it.
## No Select / Skip buttons: on the game's own blind select the board is not shown at all.
## It can be gripped and put anywhere (like the play stand), or moved with Adjust VR Layout.
## Origin = the middle of the board, its face (+z) towards the player.

const W := 0.56                      # the board
const H := 0.36
const COL_W := 0.172                 # one blind's column
const GAP := 0.008
const TEXT := 0.0004                 # pixel size of the small texts
const STATE_COLOURS := {             # as the game's Run Info colours them
	"Current": Color(0.996, 0.373, 0.333), "Upcoming": Color(0.992, 0.635, 0.0),
	"Defeated": Color(0.5, 0.5, 0.5), "Skipped": Color(0.0, 0.58, 1.0),
}
const RED := Color(0.996, 0.373, 0.333)
const GOLD := Color(0.96, 0.75, 0.15)

var _sig := ""
var _blinds: Array = []
var _faces := []                     # [Node3D for the chip art, sprite ref] per blind and tag


func _ready() -> void:
	_box(Vector3(W + 0.02, H + 0.02, 0.012), Vector3(0, 0, -0.008), _mat(Color(0.3, 0.12, 0.05), 0.5)) # wooden frame
	_box(Vector3(W, H, 0.004), Vector3(0, 0, -0.001), _mat(Color(0.2, 0.24, 0.26), 0.8)) # the dark board
	_box(Vector3(0.03, 0.12, 0.012), Vector3(0, -H * 0.5 - 0.06, -0.012), _mat(Color(0.3, 0.12, 0.05), 0.5)) # a little post below
	_box(Vector3(0.14, 0.012, 0.08), Vector3(0, -H * 0.5 - 0.12, -0.012), _mat(Color(0.3, 0.12, 0.05), 0.5)) # and its foot
	var body := StaticBody3D.new() # (only so the pointer beam stops on it, like on the other boards)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(W + 0.02, H + 0.02, 0.02)
	shape.shape = bs
	body.add_child(shape)
	add_child(body)
	_content = Node3D.new()
	add_child(_content)


var _content: Node3D


## The blinds from the mod (state "run_blinds") and the ante. Rebuilt only when something changed;
## the pictures are put on every time (an atlas may only have arrived since).
func set_data(blinds: Array, ante: int) -> void:
	var sig := JSON.stringify([blinds, ante])
	if sig != _sig:
		_sig = sig
		_blinds = blinds
		_build(ante)
	for f in _faces:
		var sprite = f[1]
		var mat: StandardMaterial3D = null
		if sprite is Dictionary:
			mat = CardArt.material(sprite.get("atlas"), sprite.get("pos"))
		CardArt.apply_layers(f[0], [mat] if mat != null else [], f[2], 0.0, 0.0004, 1)


## Whether a hand is at the board (to grip it).
func reaches(at: Vector3) -> bool:
	var p := global_transform.affine_inverse() * at
	return absf(p.x) < W * 0.5 + 0.03 and absf(p.y) < H * 0.5 + 0.03 and absf(p.z) < 0.08


func _build(ante: int) -> void:
	for c in _content.get_children():
		c.queue_free()
	_faces.clear()
	_label(_content, "RUN INFO  -  ANTE %d" % ante if ante > 0 else "RUN INFO", 44, Color(1, 1, 1), Vector3(0, H * 0.5 - 0.02, 0.003))
	var n := _blinds.size()
	for i in n:
		var x := (i - (n - 1) * 0.5) * (COL_W + GAP)
		_column(_blinds[i], Vector3(x, -0.012, 0.0))


func _column(b: Dictionary, at: Vector3) -> void:
	var col := Node3D.new()
	col.position = at
	_content.add_child(col)
	var state := str(b.get("state", ""))
	var shown := "Current" if state == "Select" else state # (the game shows the next blind to play as Current too)
	var done := shown == "Defeated" or shown == "Skipped"
	var grey := Color(0.6, 0.6, 0.6)
	var top := H * 0.5 - 0.052
	_box(Vector3(COL_W, H - 0.07, 0.003), Vector3(0, -0.025, 0.0015), _mat(Color(0.14, 0.17, 0.18), 0.8), col)
	# the state, like the game's Run Info: a coloured strip on top
	var sc: Color = STATE_COLOURS.get(shown, Color(0.5, 0.5, 0.5))
	_box(Vector3(COL_W - 0.02, 0.024, 0.002), Vector3(0, top, 0.004), _mat(sc, 0.8, 0.5), col)
	_label(col, shown, 40, Color(1, 1, 1), Vector3(0, top, 0.0055))
	# the name on a banner in the blind's colour
	var bc := Color(0.2, 0.3, 0.6)
	var c = b.get("colour")
	if c is Array and (c as Array).size() >= 3:
		bc = Color(float(c[0]), float(c[1]), float(c[2]))
	if done:
		bc = bc.darkened(0.5)
	_box(Vector3(COL_W - 0.012, 0.03, 0.002), Vector3(0, top - 0.032, 0.004), _mat(bc, 0.7, 0.3), col)
	_label(col, str(b.get("name", "")), 46, Color(1, 1, 1) if not done else Color(0.75, 0.75, 0.75), Vector3(0, top - 0.032, 0.0055))
	# the blind's chip
	var y := top - 0.08
	_chip(col, b.get("sprite"), Vector3(0, y, 0.005), 0.058, bc.lightened(0.2))
	y -= 0.04
	# the boss rule
	var desc := str(b.get("desc", ""))
	if desc != "":
		var d := _label(col, desc, 32, Color(1, 1, 1, 0.9), Vector3(0, y, 0.004), COL_W - 0.012)
		d.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		y -= 0.012 + 0.0165 * ceilf(desc.length() / 20.0) # (about 20 letters fit in a line)
	# the score it needs and the reward
	_label(col, "Score at least", 32, Color(1, 1, 1, 0.9) if not done else grey, Vector3(0, y, 0.004))
	_label(col, str(b.get("chips_text", "")), 64, RED if not done else grey, Vector3(0, y - 0.024, 0.004))
	var dollars := int(b.get("dollars", 0))
	_label(col, ("Reward: " + "$".repeat(dollars) + "+") if dollars > 0 else "No reward", 36, GOLD if not done else grey, Vector3(0, y - 0.05, 0.004))
	y -= 0.078
	# the tag for skipping it (Small and Big Blind, while it can still be skipped)
	var tag = b.get("tag")
	if tag is Dictionary and not done:
		_label(col, "or skip for", 30, Color(1, 1, 1, 0.7), Vector3(0, y, 0.004))
		y -= 0.026
		_chip(col, tag.get("sprite"), Vector3(-COL_W * 0.5 + 0.024, y, 0.005), 0.032, Color(0.55, 0.55, 0.6))
		var tn := _label(col, str(tag.get("name", "")), 38, Color(1, 1, 1), Vector3(-COL_W * 0.5 + 0.046, y, 0.004))
		tn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		y -= 0.022
		var tdesc := str(tag.get("desc", "")).replace("\n", " ")
		if tdesc != "":
			var td := _label(col, tdesc, 30, Color(1, 1, 1, 0.85), Vector3(0, y, 0.004), COL_W - 0.012)
			td.vertical_alignment = VERTICAL_ALIGNMENT_TOP


## A blind's chip / a tag: its picture from the game, over a disc in its colour (seen until the
## atlas has arrived).
func _chip(parent: Node3D, sprite, pos: Vector3, size: float, colour: Color) -> void:
	var face := Node3D.new()
	face.position = pos
	parent.add_child(face)
	_faces.append([face, sprite, Vector2.ONE * size])
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = size * 0.42
	cyl.bottom_radius = size * 0.42
	cyl.height = 0.003
	disc.mesh = cyl
	disc.rotation_degrees.x = 90.0
	disc.position = pos - Vector3(0, 0, 0.002)
	disc.material_override = _mat(colour, 0.6, 0.3)
	parent.add_child(disc)


func _label(parent: Node3D, text: String, size: int, colour: Color, pos: Vector3, wrap := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = TEXT
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.modulate = colour
	l.position = pos
	if wrap > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = wrap / TEXT
	parent.add_child(l)
	return l


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func _mat(colour: Color, rough: float, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if glow > 0.0: # (readable in the dark casino too)
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = glow
	return m
