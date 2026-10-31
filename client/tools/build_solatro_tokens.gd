extends SceneTree
## Builds Solatro's tokens from figures generated as 3D models (ComfyUI, the same way as the jokers,
## see jokers/README.md). First shrink each raw model with the joker tool, under the key
## solatro_<token key>:
##
##   ... --headless --xr-mode off --path client -s res://tools/build_ai_jokers.gd -- shrink <raw.glb> solatro_extra_card [cut_below]
##
## then write the token scenes (solatro/tokens/<token key>.tscn) for all tokens that have a model:
##
##   ... --headless --xr-mode off --path client -s res://tools/build_solatro_tokens.gd [-- key ...]
##
## SolatroGame.token_model() takes such a scene when there is one, otherwise it builds the token from
## code as before. A token stands on its feet at y = 0, about 5 cm high and at most 4.6 cm wide (it
## has to fit in its socket on the pedestal and on the sales counter's glass stand).

const KEYS := ["extra_card", "extra_discard", "pocket_points", "extra_hand", "double_score", "shield"]
const MODELS := "res://jokers/models/"
const OUT := "res://solatro/tokens/"
const HEIGHT := 0.05
const WIDTH := 0.046
## Optional per token: "tilt": [x°, z°] instead of the automatic straightening, "height", "turn" (y°).
const SPEC := {}


func _init() -> void:
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for key: String in KEYS:
		if not only.is_empty() and not only.has(key):
			continue
		var res := MODELS + "solatro_" + key + ".res"
		if not FileAccess.file_exists(res):
			print("%s: no model yet" % key)
			continue
		var s: Dictionary = SPEC.get(key, {})
		var root := Node3D.new()
		root.name = "Token"
		var mesh: ArrayMesh = load(res)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		mi.material_override = load(MODELS + "solatro_" + key + "_mat.res")
		var basis := _upright(mesh)
		if s.has("tilt"):
			basis = Basis.from_euler(Vector3(deg_to_rad(s.tilt[0]), 0, deg_to_rad(s.tilt[1])))
		basis = Basis(Vector3.UP, deg_to_rad(s.get("turn", 0.0))) * basis
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var q: Vector3 = basis * p
			lo = lo.min(q)
			hi = hi.max(q)
		var k: float = s.get("height", HEIGHT) / (hi.y - lo.y)
		var width := maxf(hi.x - lo.x, hi.z - lo.z) * k
		if width > WIDTH:
			k *= WIDTH / width
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * k), Vector3(-(lo.x + hi.x) * 0.5, -lo.y, -(lo.z + hi.z) * 0.5) * k)
		root.add_child(mi)
		mi.owner = root
		var scene := PackedScene.new()
		scene.pack(root)
		ResourceSaver.save(scene, OUT + key + ".tscn")
		print("%s: %.3f m high, %.3f m wide" % [key, (hi.y - lo.y) * k, maxf(hi.x - lo.x, hi.z - lo.z) * k])
		root.free()
		made += 1
	print("%d token scenes written" % made)
	quit(0)


## The generator often leans a figure a little: turns it so the line from the middle of its foot
## (the lowest 8 %) to the middle of the whole figure stands vertical (at most 30°) - as for the jokers.
func _upright(mesh: ArrayMesh) -> Basis:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var lo := INF
	var hi := -INF
	for p in v:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var foot_y := lo + (hi - lo) * 0.08
	var all := Vector3.ZERO
	var all_w := 0.0
	var foot := Vector3.ZERO
	var foot_w := 0.0
	for t in range(0, idx.size(), 3):
		var a := v[idx[t]]
		var b := v[idx[t + 1]]
		var c := v[idx[t + 2]]
		var area := (b - a).cross(c - a).length() * 0.5
		var m := (a + b + c) / 3.0
		all += m * area
		all_w += area
		if m.y < foot_y:
			foot += m * area
			foot_w += area
	if all_w <= 0.0 or foot_w <= 0.0:
		return Basis()
	var axis := (all / all_w - foot / foot_w).normalized()
	if axis.angle_to(Vector3.UP) > deg_to_rad(30.0):
		return Basis()
	return Basis(Quaternion(axis, Vector3.UP))
