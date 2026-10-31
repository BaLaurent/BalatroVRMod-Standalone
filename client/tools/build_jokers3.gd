extends "res://tools/build_jokers.gd"
## Builds the jokers that replaced generated (ComfyUI) models with hand-built ones again, using the
## toolkit of build_jokers.gd: Banner, Mail-In Rebate, Trading Card, Throwback, Square Joker.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path client --script res://tools/build_jokers3.gd
##   ... --script res://tools/build_jokers3.gd -- banner square     (only these)
##
## Overwrites the scenes it builds. These keys are not in tools/ai_jokers.json any more, so
## build_ai_jokers.gd leaves them alone.

## Cloth that waves in the wind; the edge at x = -x0 (the pole) stays put. Every piece of the flag
## (cloth, stripes) uses it with its own offset, so they all wave as one.
const WAVE := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 albedo : source_color = vec3(0.75, 0.1, 0.15);
uniform float rough = 0.85;
uniform vec2 offset = vec2(0.0);   // this mesh's origin in flag space (x = distance from the pole)
uniform float width = 0.075;

float wave(vec2 p) {
	return sin(p.x * 95.0 - TIME * 4.2 + p.y * 25.0) * 0.0055 * (p.x / width)
		+ sin(p.x * 160.0 - TIME * 6.3) * 0.0012 * (p.x / width);
}

void vertex() {
	vec2 p = VERTEX.xy + offset;
	VERTEX.z += wave(p);
	float dx = (wave(p + vec2(0.001, 0.0)) - wave(p)) / 0.001;
	float dy = (wave(p + vec2(0.0, 0.001)) - wave(p)) / 0.001;
	NORMAL = normalize(vec3(-dx, -dy, 1.0));
}

void fragment() {
	ALBEDO = albedo * (0.85 + 0.15 * smoothstep(-1.0, 1.0, NORMAL.x));
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
"""

## Holographic foil: shifts through the rainbow as you move your head.
const FOIL := """
shader_type spatial;
uniform float strength = 1.0;
void fragment() {
	float f = dot(NORMAL, VIEW);
	vec2 uv = UV * vec2(3.0, 4.0);
	float h = fract(f * 2.5 + uv.x * 0.35 + uv.y * 0.25 + sin(uv.y * 6.0) * 0.08);
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831 * (h + vec3(0.0, 0.33, 0.67)));
	vec3 gold = vec3(0.95, 0.75, 0.3);
	ALBEDO = mix(gold, rainbow, 0.55 * strength);
	METALLIC = 0.8;
	ROUGHNESS = 0.25;
	EMISSION = rainbow * 0.15 * strength;
}
"""

## Air mail envelope: red and blue diagonal stripes around the edge.
const AIRMAIL := """
shader_type spatial;
uniform vec2 size = vec2(0.046, 0.03);
void fragment() {
	vec2 p = UV * size;
	float edge = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	float band = step(edge, 0.0032);
	float s = fract((p.x + p.y) / 0.008);
	vec3 paper = vec3(0.97, 0.95, 0.9);
	vec3 stripe = s < 0.25 ? vec3(0.82, 0.12, 0.15) : (s < 0.5 ? paper : (s < 0.75 ? vec3(0.15, 0.3, 0.75) : paper));
	ALBEDO = mix(paper, stripe, band);
	ROUGHNESS = 0.8;
}
"""


func _initialize() -> void:
	var builders := {
		"banner": _banner3, "mail": _mail3, "trading": _trading, "throwback": _throwback, "square": _square3,
	}
	var only := OS.get_cmdline_user_args()
	for key in builders:
		if not only.is_empty() and not only.has(key):
			continue
		_rng.seed = hash(key)
		var root: Node3D = builders[key].call()
		_save(root, key)
	quit()


## A flat, finely divided rectangle in the XY plane (so it can bend), w x h, its origin at the centre.
func _sheet(w: float, h: float, nx := 16, ny := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in nx:
		for k in ny:
			var corners := []
			for c in [Vector2(i, k), Vector2(i + 1, k), Vector2(i + 1, k + 1), Vector2(i, k + 1)]:
				var uv := Vector2(c.x / nx, 1.0 - c.y / ny)
				corners.append([Vector3(-w / 2 + w * c.x / nx, -h / 2 + h * c.y / ny, 0), Vector3.BACK, uv])
			_quad(st, corners[0], corners[1], corners[2], corners[3])
	return st.commit()


func _wave_mat(c: Color, offset: Vector2, rough := 0.85) -> ShaderMaterial:
	var m := _shader_mat(WAVE)
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("offset", offset)
	m.set_shader_parameter("rough", rough)
	return m


# ================================================================ jokers

## Banner: +30 Chips for each discard left. A red banner waving on a pole, one gold stripe on it
## per discard left (stripes pop away as you discard); a white flag when none are left.
func _banner3() -> Node3D:
	const W := 0.075        # cloth width (from the pole)
	const H := 0.062        # cloth height
	const TOP := 0.152      # where the cloth hangs from
	const SLOTS := 6        # stripes the cloth has room for
	var j := _begin("banner", {"count_parent": NodePath("Flag/Stripes"), "count_source": "run[\"discards_left\"]",
			"empty_source": "run[\"discards_left\"]", "show_when_empty": NodePath("WhiteFlag"),
			"hide_when_empty": NodePath("Flag")})
	var wood := _mat(Color(0.38, 0.22, 0.12), 0.6)
	var gold := _gold()
	var pole_x := -0.032
	# a round wooden foot with a gold ring, the pole, a gold knob on top
	_mi(j, _cyl(0.016, 0.019, 0.007, 20), wood, Vector3(pole_x, 0.0035, 0))
	_mi(j, _torus(0.015, 0.0175, 24, 6), gold, Vector3(pole_x, 0.007, 0))
	_mi(j, _cyl(0.0022, 0.0026, 0.16, 10), wood, Vector3(pole_x, 0.085, 0), Vector3.ZERO, Vector3.ONE, "Pole")
	_mi(j, _sph(0.0055, -1, 14), gold, Vector3(pole_x, 0.169, 0))
	_mi(j, _cyl(0.0035, 0.002, 0.004, 10), gold, Vector3(pole_x, 0.163, 0))
	# the flag hangs from rings on the pole; everything on it waves with the same wind
	var flag := _node(j, "Flag", Vector3(pole_x + 0.0025, TOP - H / 2, 0))
	for y in [H / 2 - 0.004, -H / 2 + 0.004]:
		_mi(flag, _torus(0.0023, 0.0036, 12, 4), gold, Vector3(-0.0025, y, 0))
	var cloth_mat := _wave_mat(Color(0.72, 0.08, 0.13), Vector2(W / 2, 0))
	_mi(flag, _sheet(W, H, 20, 10), cloth_mat, Vector3(W / 2, 0, 0), Vector3.ZERO, Vector3.ONE, "Cloth")
	# gold trim along the top and bottom edge
	for y in [H / 2 - 0.002, -H / 2 + 0.002]:
		var trim := _wave_mat(Color(0.95, 0.72, 0.25), Vector2(W / 2, y), 0.35)
		_mi(flag, _sheet(W, 0.004, 20, 1), trim, Vector3(W / 2, y, 0.0004))
	# the stripes, top down: Stripe1 is shown first
	var stripes := _node(flag, "Stripes")
	var gap := (H - 0.012) / SLOTS
	for i in SLOTS:
		var y := H / 2 - 0.006 - gap * (i + 0.5)
		var col := Color(0.98, 0.82, 0.28) if i % 2 == 0 else Color(0.99, 0.9, 0.55)
		var s := _mi(stripes, _sheet(W * 0.86, gap * 0.55, 18, 1), _wave_mat(col, Vector2(W * 0.5, y), 0.45),
				Vector3(W * 0.5, y, 0.0005), Vector3.ZERO, Vector3.ONE, "Stripe%d" % (i + 1))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# no discards left: a white flag
	var white := _node(j, "WhiteFlag", Vector3(pole_x + 0.0025, TOP - 0.018, 0))
	_mi(white, _sheet(0.05, 0.034, 14, 6), _wave_mat(Color(0.96, 0.96, 0.93), Vector2(0.025, 0)),
			Vector3(0.025, 0, 0))
	white.visible = false
	return j


## Mail-In Rebate: $5 for each discarded card of this round's rank. A shiny red mailbox on a post,
## flag up, an air mail envelope in its slot with the rank written on it, and a green $5 coupon.
func _mail3() -> Node3D:
	var j := _begin("mail", {"label_node": NodePath("Box/Envelope/Rank"), "label_source": "target[\"rank\"]",
			"label_format": "%s"})
	var wood := _mat(Color(0.38, 0.22, 0.12), 0.6)
	var red := _mat(Color(0.8, 0.1, 0.12), 0.25, 0.15)
	var dark_red := _mat(Color(0.45, 0.05, 0.07), 0.5)
	var metal := _mat(Color(0.75, 0.75, 0.78), 0.3, 0.8)
	var yellow := _mat(Color(0.98, 0.8, 0.15), 0.4)
	# post on a little mound of grass
	_mi(j, _cyl(0.014, 0.018, 0.006, 16), _mat(Color(0.22, 0.5, 0.2), 0.9), Vector3(0, 0.003, 0))
	_mi(j, _box(Vector3(0.009, 0.06, 0.009)), wood, Vector3(0, 0.035, 0), Vector3.ZERO, Vector3.ONE, "Post")
	_mi(j, _box(Vector3(0.014, 0.004, 0.05)), wood, Vector3(0, 0.066, 0))
	# the box: a rounded-top tunnel, lying along Z (the opening to the front)
	var arch := PackedVector2Array([Vector2(-0.019, 0), Vector2(0.019, 0)])
	for i in 17:
		var a := PI * i / 16.0
		arch.append(Vector2(cos(a) * 0.019, 0.016 + sin(a) * 0.019))
	var box := _mi(j, _extrude(arch, 0.056), red, Vector3(0, 0.068, 0), Vector3.ZERO, Vector3.ONE, "Box")
	# the door at the front, a darker rim and a handle; ribs along the top
	_mi(box, _extrude(arch, 0.002), dark_red, Vector3(0, 0, 0.0285), Vector3.ZERO, Vector3(1.04, 1.04, 1))
	_mi(box, _extrude(arch, 0.002), red, Vector3(0, 0.001, 0.0298), Vector3.ZERO, Vector3(0.94, 0.94, 1))
	_mi(box, _cyl(0.0025, 0.0025, 0.004, 10), metal, Vector3(0, 0.03, 0.032), Vector3(90, 0, 0))
	for z in [-0.018, 0.0, 0.018]:
		_mi(box, _torus(0.0185, 0.0198, 24, 4), dark_red, Vector3(0, 0.016, z), Vector3(90, 0, 0), Vector3(1, 1, 1))
	# the flag on the side, raised: you've got mail
	_mi(box, _cyl(0.003, 0.003, 0.003, 10), metal, Vector3(0.0205, 0.012, -0.012), Vector3(0, 0, 90))
	_mi(box, _box(Vector3(0.002, 0.034, 0.004)), yellow, Vector3(0.022, 0.026, -0.012))
	_mi(box, _box(Vector3(0.002, 0.012, 0.016)), yellow, Vector3(0.022, 0.038, -0.004))
	# the envelope, half out of the slot in the door
	var slot := _box(Vector3(0.03, 0.003, 0.004))
	_mi(box, slot, _mat(Color(0.1, 0.02, 0.03), 0.8), Vector3(0, 0.0345, 0.008))
	var env := _node(box, "Envelope", Vector3(0, 0.045, 0.009))
	env.rotation_degrees = Vector3(-12, 0, 0)
	var paper := _shader_mat(AIRMAIL)
	_mi(env, _box(Vector3(0.046, 0.03, 0.0012)), paper)
	_mi(env, _box(Vector3(0.008, 0.0095, 0.0004)), _mat(Color(0.2, 0.55, 0.3), 0.6), Vector3(0.015, 0.0075, 0.0008)) # stamp
	var rank := Label3D.new()
	rank.name = "Rank"
	rank.text = "King"
	rank.font_size = 48
	rank.pixel_size = 0.00018
	rank.outline_size = 0
	rank.modulate = Color(0.12, 0.15, 0.35)
	rank.position = Vector3(-0.003, -0.003, 0.0008)
	env.add_child(rank)
	# a green $5 rebate coupon leaning on the post
	var coupon := _node(j, "Coupon", Vector3(0.013, 0.03, 0.018))
	coupon.rotation_degrees = Vector3(-8, -25, -12)
	_mi(coupon, _box(Vector3(0.026, 0.016, 0.001)), _mat(Color(0.3, 0.68, 0.35), 0.6))
	_mi(coupon, _box(Vector3(0.022, 0.012, 0.0004)), _mat(Color(0.88, 0.96, 0.85), 0.7), Vector3(0, 0, 0.0006))
	_print(coupon, "$5", Vector3(0, 0, 0.0009), Vector3.ZERO, 0.00022, Color(0.12, 0.45, 0.2))
	return j


## Trading Card: the first discard of a round, a single card, is destroyed for $3. A collectible card
## in a clear case on a stand: holographic foil border, a little Jimbo stepping out of the picture.
func _trading() -> Node3D:
	var j := _begin("trading", {})
	var wood := _mat(Color(0.3, 0.17, 0.1), 0.5)
	var gold := _gold()
	# stand: a plinth with a groove
	_mi(j, _box(Vector3(0.07, 0.008, 0.03)), wood, Vector3(0, 0.004, 0))
	_mi(j, _box(Vector3(0.074, 0.002, 0.034)), gold, Vector3(0, 0.0005, 0))
	var card := _node(j, "Card", Vector3(0, 0.051, -0.004))
	card.rotation_degrees = Vector3(-8, 0, 0)
	const CW := 0.06
	const CH := 0.084
	# foil frame, the picture (night sky with a spotlight), the name plate
	var foil := _shader_mat(FOIL)
	_mi(card, _box(Vector3(CW, CH, 0.0016)), foil)
	var sky := StandardMaterial3D.new()
	sky.albedo_color = Color(0.16, 0.12, 0.35)
	sky.roughness = 0.7
	_mi(card, _box(Vector3(CW - 0.008, CH * 0.62, 0.0006)), sky, Vector3(0, 0.008, 0.0009))
	_mi(card, _cyl(0.0, 0.016, 0.04, 16), _see_through(Color(1.0, 0.95, 0.7), 0.18), Vector3(0, 0.02, 0.003), Vector3(0, 0, 0), Vector3(1, 1, 0.12))
	for i in 9: # little stars
		var p := Vector3(_rng.randf_range(-0.022, 0.022), _rng.randf_range(-0.012, 0.03), 0.0013)
		_mi(card, _sph(0.0008, -1, 6), _glowing(Color(1, 0.95, 0.7), 1.5), p)
	var plate := _mat(Color(0.95, 0.93, 0.86), 0.6)
	_mi(card, _box(Vector3(CW - 0.012, 0.011, 0.0008)), plate, Vector3(0, -0.03, 0.0009))
	_print(card, "JIMBO", Vector3(0, -0.03, 0.0014), Vector3.ZERO, 0.00017, Color(0.2, 0.15, 0.3))
	# rarity: three gold stars at the top
	for i in 3:
		_mi(card, _extrude(_star(0.0028, 0.0012), 0.0008), gold, Vector3((i - 1) * 0.0075, 0.036, 0.0012))
	# Jimbo steps out of the picture
	var jim := _jester(card, "Jimbo", 0.42)
	jim.position = Vector3(0, -0.012, 0.004)
	# the clear case around it all
	_mi(card, _box(Vector3(CW + 0.006, CH + 0.006, 0.014)), _see_through(Color(0.85, 0.92, 1.0), 0.14, 0.05), Vector3(0, 0, 0.004))
	return j


## Throwback: x0.25 Mult for each blind skipped this run. Jimbo in a VR headset, looking back at the
## good old days; the visor glows brighter the more Mult he has.
func _throwback() -> Node3D:
	var j := _begin("throwback", {"glow_node": NodePath("Jimbo/Headset/Visor"),
			"glow_source": "clamp((ab[\"x_mult\"] - 1.0) / 2.0, 0.0, 1.0) * 0.8 + 0.2", "glow_energy": 2.5})
	var jim := _jester(j, "Jimbo", 1.0, Color(0.15, 0.55, 0.35), Color(0.55, 0.2, 0.7))
	var shell := _mat(Color(0.93, 0.93, 0.95), 0.35)
	var black := _mat(Color(0.06, 0.06, 0.08), 0.5)
	var hs := _node(jim, "Headset", Vector3(0, 0.0885, 0.0095))
	# the shell, a black face cushion, the strap around the head and over the top
	_mi(hs, _box(Vector3(0.03, 0.015, 0.012)), shell, Vector3(0, 0, 0.004))
	_mi(hs, _box(Vector3(0.028, 0.013, 0.004)), black, Vector3(0, 0, -0.0025))
	_mi(hs, _box(Vector3(0.026, 0.011, 0.001)), _glowing(Color(0.25, 0.75, 1.0), 0.5), Vector3(0, 0, 0.0103),
			Vector3.ZERO, Vector3.ONE, "Visor")
	for side in [-1.0, 1.0]: # the tracking cameras at the corners
		_mi(hs, _sph(0.0016, -1, 8), black, Vector3(side * 0.012, 0.0045, 0.0105))
		_mi(hs, _sph(0.0016, -1, 8), black, Vector3(side * 0.012, -0.0045, 0.0105))
	_mi(jim, _torus(0.0138, 0.0158, 24, 6), black, Vector3(0, 0.0885, -0.001), Vector3(-6, 0, 0), Vector3(1, 1, 1.05))
	# a controller in each hand
	for side in [-1.0, 1.0]:
		var c := _node(jim, "Controller%s" % ("L" if side < 0 else "R"), Vector3(side * 0.027, 0.04, 0.012))
		c.rotation_degrees = Vector3(-30, 0, side * -10)
		_mi(c, _cyl(0.0035, 0.003, 0.016, 10), black)
		_mi(c, _torus(0.006, 0.0075, 16, 4), shell, Vector3(0, 0.011, 0), Vector3(70, 0, 0))
	return j


## Square Joker: +4 Chips for every hand of exactly 4 cards. Jimbo made only of cubes - head, body,
## arms, legs, hat and bells - who grows with the chips he has collected.
func _square3() -> Node3D:
	var j := _begin("square", {"fill_node": NodePath("Fill"), "fill_source": "extra[\"chips\"]", "fill_max": 64.0,
			"fill_min": 0.65, "fill_uniform": true, "label_node": NodePath("Value"), "label_source": "extra[\"chips\"]",
			"label_format": "+%d Chips"})
	var fill := _node(j, "Fill")
	var red := _mat(Color(0.85, 0.15, 0.2), 0.55)
	var blue := _mat(Color(0.16, 0.36, 0.85), 0.55)
	var face := _mat(Color(0.97, 0.95, 0.9), 0.5)
	var dark := _mat(Color(0.08, 0.08, 0.1), 0.4)
	var cheek := _mat(Color(0.95, 0.45, 0.5), 0.6)
	var gold := _gold()
	# legs and shoes
	for side in [-1.0, 1.0]:
		_mi(fill, _box(Vector3(0.011, 0.022, 0.011)), red if side < 0 else blue, Vector3(side * 0.0075, 0.015, 0))
		_mi(fill, _box(Vector3(0.012, 0.005, 0.016)), dark, Vector3(side * 0.0075, 0.0025, 0.002))
	# body: harlequin halves, square buttons, a collar of little white cubes
	_mi(fill, _box(Vector3(0.0145, 0.026, 0.02)), red, Vector3(-0.00725, 0.039, 0))
	_mi(fill, _box(Vector3(0.0145, 0.026, 0.02)), blue, Vector3(0.00725, 0.039, 0))
	for i in 3:
		_mi(fill, _box(Vector3(0.003, 0.003, 0.002)), gold, Vector3(0, 0.032 + i * 0.007, 0.0105), Vector3(0, 0, 45))
	for i in 8:
		var a := TAU * i / 8.0
		_mi(fill, _box(Vector3(0.006, 0.004, 0.006)), face, Vector3(cos(a) * 0.012, 0.0535, sin(a) * 0.01), Vector3(0, -rad_to_deg(a), 0))
	# arms, white glove cubes
	for side in [-1.0, 1.0]:
		_mi(fill, _box(Vector3(0.008, 0.02, 0.008)), red if side < 0 else blue, Vector3(side * 0.019, 0.042, 0), Vector3(0, 0, side * 12))
		_mi(fill, _box(Vector3(0.008, 0.008, 0.008)), face, Vector3(side * 0.021, 0.029, 0.001))
	# the head: a perfect cube with square eyes, square cheeks and a square grin
	_mi(fill, _box(Vector3(0.03, 0.03, 0.03)), face, Vector3(0, 0.071, 0))
	for side in [-1.0, 1.0]:
		_mi(fill, _box(Vector3(0.006, 0.006, 0.001)), dark, Vector3(side * 0.007, 0.075, 0.0152))
		_mi(fill, _box(Vector3(0.0022, 0.0022, 0.0006)), face, Vector3(side * 0.0068 + 0.0012, 0.0765, 0.0157))
		_mi(fill, _box(Vector3(0.006, 0.0035, 0.0008)), cheek, Vector3(side * 0.0105, 0.0665, 0.0152))
	_mi(fill, _box(Vector3(0.014, 0.004, 0.001)), dark, Vector3(0, 0.063, 0.0152))
	_mi(fill, _box(Vector3(0.0035, 0.0035, 0.001)), dark, Vector3(-0.0088, 0.0655, 0.0152))
	_mi(fill, _box(Vector3(0.0035, 0.0035, 0.001)), dark, Vector3(0.0088, 0.0655, 0.0152))
	# hat: a square band and two horns of stepped cubes, each ending in a gold cube bell
	_mi(fill, _box(Vector3(0.032, 0.006, 0.032)), gold, Vector3(0, 0.088, 0))
	_mi(fill, _box(Vector3(0.028, 0.008, 0.028)), red, Vector3(0, 0.095, 0))
	for side in [-1.0, 1.0]:
		var mat := red if side < 0 else blue
		var steps := [Vector3(0.008, 0.103, 0), Vector3(0.016, 0.109, 0), Vector3(0.024, 0.111, 0), Vector3(0.031, 0.107, 0)]
		for k in steps.size():
			var size := 0.012 - k * 0.0018
			_mi(fill, _box(Vector3.ONE * size), mat, Vector3(side * steps[k].x, steps[k].y, 0))
		_mi(fill, _box(Vector3.ONE * 0.006), gold, Vector3(side * 0.035, 0.1, 0), Vector3(45, 0, 45))
	_value_label(j, "Value", 0.14)
	return j
