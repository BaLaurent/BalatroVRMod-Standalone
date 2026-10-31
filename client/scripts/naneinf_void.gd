class_name NaneinfVoid
extends Node3D
## The naneinf moment (the score overflowed): the number broke the casino. The room comes apart
## piece by piece – walls, floor, ceiling, machines, lamps tumble away into the dark – and deep
## space opens all around you and the card table (it stays, with everything on it). After a while
## the pieces fly back and the casino is whole again. Only the room's own nodes move, and each one
## gets its exact transform back at the end. A child of the CasinoRoom, which says what stays.

const OUT := 7.0                    # seconds the pieces fly away
const HOLD := 9.0                   # ... drift in space
const BACK := 3.5                   # ... and come back
const FAR := 30.0                   # no piece flies further than this (meters)
const SKY_R := 40.0

var room: Node3D
var keep: Array = []                # the room's nodes that stay (card table, its foot)
var calm := false                   # Calm Lights: the floating word doesn't flash in colours

var _pieces: Array[Dictionary] = [] # {"node", "base", "dir", "axis", "spin", "delay", "accel"}
var _t := -1.0                      # time since start (-1: not running)
var _sky: MeshInstance3D
var _sky_mat: ShaderMaterial
var _word: Label3D
var _word_tick := -1


func active() -> bool:
	return _t >= 0.0


## How far the room is gone: 0 (whole) .. 1 (only space around you). main.gd thins the fog with it.
func amount() -> float:
	if _t < 0.0:
		return 0.0
	if _t < OUT + HOLD:
		return smoothstep(0.3, 3.0, _t)
	return 1.0 - smoothstep(0.0, BACK, _t - OUT - HOLD)


## Starts the moment; `center` is where your head is (the pieces fly away from it).
func start(center: Vector3) -> void:
	if _t >= 0.0 or room == null:
		return
	_collect(center)
	_t = 0.0
	_build_sky(center)


func _collect(center: Vector3) -> void:
	_pieces.clear()
	var nodes: Array = []
	for c in room.get_children():
		if c == self or keep.has(c) or not (c is Node3D) or not (c as Node3D).visible:
			continue
		# containers break up into their parts: each machine flies on its own, each part of a wall too
		if c is CasinoMachines or (c.get_class() == "Node3D" and c.get_script() == null and c.get_child_count() > 1):
			for part in c.get_children():
				if part is Node3D and (part as Node3D).visible:
					nodes.append(part)
		else:
			nodes.append(c)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for n: Node3D in nodes:
		var size := _size(n)
		var big := size > 3.0 # floor, ceiling, whole walls: they go last and slowest
		var away := _centre(n) - center
		var dir := away.normalized() if away.length() > 0.05 else Vector3.UP
		dir = (dir + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.4), rng.randf_range(-0.3, 0.3))).normalized()
		var parent := n.get_parent() as Node3D
		var local_dir := (parent.global_basis.inverse() * dir) if parent != null else dir
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		_pieces.append({
			"node": n, "base": n.transform, "dir": local_dir,
			"axis": axis.normalized() if axis.length() > 0.01 else Vector3.UP,
			"spin": rng.randf_range(0.3, 1.4) * (0.35 if big else 1.0),
			"delay": (1.8 if big else 0.0) + rng.randf_range(0.0, 1.6) + clampf(away.length() * 0.08, 0.0, 0.6),
			"accel": rng.randf_range(1.0, 2.2) * (0.6 if big else 1.0),
		})


## The middle of what a node shows (world), for the direction it flies off in.
func _centre(n: Node3D) -> Vector3:
	if n is VisualInstance3D:
		return n.global_transform * (n as VisualInstance3D).get_aabb().get_center()
	return n.global_position


func _size(n: Node3D) -> float:
	if n is VisualInstance3D:
		var s := (n as VisualInstance3D).get_aabb().size
		return maxf(s.x, maxf(s.y, s.z))
	return 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var total := OUT + HOLD + BACK
	if _t >= total:
		_finish()
		return
	var t_out := minf(_t, OUT + HOLD) # how far they got before they turned back
	var k := 1.0 - smoothstep(0.0, BACK, _t - OUT - HOLD) if _t > OUT + HOLD else 1.0
	for p in _pieces:
		var n: Node3D = p["node"]
		if not is_instance_valid(n):
			continue
		var u := maxf(t_out - float(p["delay"]), 0.0)
		var d := minf(0.25 * u + 0.5 * float(p["accel"]) * u * u, FAR) * k
		var s := lerpf(1.0, lerpf(1.0, 0.25, clampf(u / 6.0, 0.0, 1.0)), k)
		var b: Transform3D = p["base"]
		var turned := Basis(p["axis"], float(p["spin"]) * u * k) * b.basis * Basis.from_scale(Vector3.ONE * s)
		n.transform = Transform3D(turned, b.origin + (p["dir"] as Vector3) * d)
	var a := amount()
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("amount", a)
	if _word != null:
		_glitch_word(a)


## Everything back where it was; space closes.
func _finish() -> void:
	for p in _pieces:
		var n: Node3D = p["node"]
		if is_instance_valid(n):
			n.transform = p["base"]
	_pieces.clear()
	_t = -1.0
	if _sky != null:
		_sky.queue_free()
		_sky = null
		_sky_mat = null
	if _word != null:
		_word.queue_free()
		_word = null


## Stops at once (e.g. the casino is switched off): the room is whole again.
func stop() -> void:
	if _t >= 0.0:
		_finish()


func _build_sky(center: Vector3) -> void:
	_sky = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = SKY_R
	sphere.height = SKY_R * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_sky.mesh = sphere
	_sky_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SPACE_SHADER
	_sky_mat.shader = shader
	_sky_mat.set_shader_parameter("amount", 0.0)
	_sky_mat.render_priority = -100 # drawn before everything else see-through (its centre is your head: it would sort last)
	_sky.material_override = _sky_mat
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky.top_level = true
	add_child(_sky)
	_sky.global_position = center
	# far ahead, over where the BALATRO screen was: the number that broke everything
	_word = Label3D.new()
	_word.text = "naneinf"
	_word.font_size = 128
	_word.pixel_size = 0.02
	_word.outline_size = 0
	_word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_word.shaded = false
	_word.top_level = true
	_word.modulate = Color(1.0, 0.3, 0.35, 0.0)
	add_child(_word)
	var ahead := -room.global_basis.z.normalized()
	_word.global_position = center + ahead * 16.0 + Vector3.UP * 3.0
	GameFont.apply_to(_word)


func _glitch_word(a: float) -> void:
	var tick := int(_t * (3.0 if calm else 9.0))
	var show := clampf((a - 0.6) / 0.4, 0.0, 1.0) # only once the room is mostly gone
	if tick != _word_tick:
		_word_tick = tick
		var glitch := not calm and randf() < 0.3
		_word.text = ["NaN", "1.#INF", "e+308", "NANEINF", "n4n3!nf"].pick_random() if glitch else "naneinf"
		var c := Color.from_hsv(randf(), 0.7, 1.0) if glitch else Color(1.0, 0.3, 0.35)
		_word.modulate = Color(c.r * 2.0, c.g * 2.0, c.b * 2.0, _word.modulate.a)
		_word.position.x += randf_range(-0.15, 0.15) if glitch else 0.0
	_word.modulate.a = show


const SPACE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled, depth_draw_never, shadows_disabled;

uniform float amount = 0.0;
varying vec3 dir;

void vertex() {
	dir = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// one star in some cells of a grid through the sky, twinkling
float stars(vec3 d, float scale, float keep, float time) {
	vec3 p = d * scale;
	vec3 c = floor(p);
	float h = hash(c);
	if (h < keep) {
		return 0.0;
	}
	vec3 at = vec3(hash(c + 1.7), hash(c + 3.1), hash(c + 5.3)) * 0.6 + 0.2;
	float r = length(fract(p) - at);
	float twinkle = 0.6 + 0.4 * sin(time * (1.0 + h * 3.0) + h * 40.0);
	return smoothstep(0.09, 0.0, r) * twinkle;
}

void fragment() {
	vec3 d = normalize(dir);
	float t = TIME * 0.01;
	// a slow nebula in the game's red and blue
	float n = fbm(d * 2.2 + vec3(t, 0.0, -t));
	float n2 = fbm(d * 4.0 - vec3(0.0, t * 2.0, 0.0) + 7.0);
	vec3 red = vec3(0.85, 0.12, 0.2);
	vec3 blue = vec3(0.1, 0.3, 0.9);
	vec3 col = vec3(0.004, 0.003, 0.012);
	col += mix(blue, red, smoothstep(0.35, 0.65, n2)) * pow(smoothstep(0.4, 0.85, n), 2.0) * 0.9;
	float s = stars(d, 60.0, 0.93, TIME) + 0.6 * stars(d, 140.0, 0.9, TIME * 1.3);
	col += vec3(1.0, 0.95, 0.9) * s * 2.0;
	ALBEDO = col;
	ALPHA = amount;
}
"""
