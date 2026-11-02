extends SceneTree
## Builds the jokers whose figures were generated as 3D models (ComfyUI, see jokers/README.md).
##
##   ... --headless --xr-mode off --path client -s res://tools/build_ai_jokers.gd -- shrink <raw.glb> <key> [cut_below]
##       Shrinks one raw model (~700 000 triangles, 4K textures) to jokers/models/<key>.res
##       (a few thousand triangles) and jokers/models/<key>_mat.res (one 1024 px texture).
##       cut_below (model units, y): triangles lying completely below it are dropped - a base the
##       generator put under a figure (the game adds the joker pedestal itself).
##   ... -- scenes [key ...]
##       Writes jokers/<key>.tscn for every joker in tools/ai_jokers.json (or only the given keys):
##       the figure stood upright, scaled to its height, and its live effects (glow, fill, ...).
##   ... -- islands <key> [ratio]
##       Drops loose pieces floating next to a figure (smaller than ratio x its biggest part, 0.1).
##   ... -- cutbox <key> x0 y0 z0 x1 y1 z1
##       Drops every triangle whose middle lies in that box (model units, like cut_below) - a part
##       grown onto the figure that doesn't belong there (Stuntman: the handlebar on his back).
##
## ai_jokers.json: { "<key>": { "tilt": [x°, z°], "height": 0.11, "label": [source, format],
##   "glow": [source 0..1, energy], "fill": [source, max, min], "alpha": source, "shake": true | source,
##   "spin": speed, "suit": source, "text": [source, format], "split": 0..1 (fill squashes only the
##   part above), "center": "mass" (stands centred by its weight instead of its outline), "cards": {"ranks": [...], "size", "at", "only"} (a card fan built from code) } }
##   - all fields optional.
## "label" is a floating value (hidden while the pedestal shows the joker's value),
## "text" is other information that always stays visible (e.g. "Discard: King").

const TRIS := 6000
const TEX_SIZE := 1024
const SPEC := "res://tools/ai_jokers.json"
const MODELS := "res://jokers/models/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "shrink":
		quit(_shrink(args[1], args[2], float(args[3]) if args.size() > 3 else -INF))
	elif args.size() >= 1 and args[0] == "scenes":
		quit(_scenes(args.slice(1)))
	elif args.size() >= 2 and args[0] == "islands":
		quit(_islands(args[1], float(args[2]) if args.size() > 2 else 0.1))
	elif args.size() >= 8 and args[0] == "cutbox":
		quit(_cutbox(args[1], Vector3(float(args[2]), float(args[3]), float(args[4])),
			Vector3(float(args[5]), float(args[6]), float(args[7]))))
	else:
		push_error("usage: -- shrink <raw.glb> <key> [cut_below] | -- scenes [key ...] | -- islands <key> [ratio] | -- cutbox <key> x0 y0 z0 x1 y1 z1")
		quit(1)


# ---------------------------------------------------------------- shrink

func _shrink(path: String, key: String, cut: float) -> int:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("cannot read %s" % path)
		return 1
	var im: ImporterMesh = (state.get_meshes()[0] as GLTFMesh).mesh
	var arrays := im.get_surface_arrays(0)
	var src_mat := im.get_surface_material(0)
	var img: Image = null
	if src_mat is BaseMaterial3D and src_mat.albedo_texture:
		img = src_mat.albedo_texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
	_report_base(arrays[Mesh.ARRAY_VERTEX])
	if cut > -INF:
		var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t in range(0, src_i.size(), 3):
			if pos[src_i[t]].y >= cut or pos[src_i[t + 1]].y >= cut or pos[src_i[t + 2]].y >= cut:
				kept.append_array([src_i[t], src_i[t + 1], src_i[t + 2]])
		arrays[Mesh.ARRAY_INDEX] = kept
		im.clear()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, src_mat)
		print("  cut below y=%.3f" % cut)

	# The first LOD with at most TRIS triangles (or the smallest one).
	im.generate_lods(60.0, 60.0, [])
	var best := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	for k in im.get_surface_lod_count(0):
		best = im.get_surface_lod_indices(0, k)
		if best.size() / 3 <= TRIS:
			break

	# Keep only the used vertices.
	var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var remap := {}
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var uv := PackedVector2Array()
	var ni := PackedInt32Array()
	for o in best:
		if not remap.has(o):
			remap[o] = v.size()
			v.append(src_v[o])
			if src_n.size() > 0:
				nn.append(src_n[o])
			if src_uv.size() > 0:
				uv.append(src_uv[o])
		ni.append(remap[o])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	if nn.size() > 0:
		a[Mesh.ARRAY_NORMAL] = nn
	if uv.size() > 0:
		a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_INDEX] = ni
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)

	var mat := StandardMaterial3D.new()
	mat.roughness = 0.8
	if img:
		img.generate_mipmaps()
		img.compress(Image.COMPRESS_ETC2, Image.COMPRESS_SOURCE_SRGB)
		var tex := ImageTexture.create_from_image(img)
		mat.albedo_texture = tex
		mat.emission_texture = tex # glowing jokers glow in their own colours
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELS))
	var mat_path := MODELS + key + "_mat.res"
	ResourceSaver.save(mat, mat_path, ResourceSaver.FLAG_COMPRESS)
	mesh.surface_set_material(0, load(mat_path))
	ResourceSaver.save(mesh, MODELS + key + ".res", ResourceSaver.FLAG_COMPRESS)
	var aabb := mesh.get_aabb()
	print("  %s: %d triangles, size %s" % [key, ni.size() / 3, aabb.size])
	return OK


## Drops loose pieces floating next to a figure (the generator sometimes leaves some): every part
## that isn't connected to the rest and has less than `ratio` of the biggest part's area goes.
func _islands(key: String, ratio: float) -> int:
	var path := MODELS + key + ".res"
	var mesh: ArrayMesh = load(path)
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# vertices at the same place belong together (the texture seams split them)
	var weld := {}
	var root := PackedInt32Array()
	root.resize(v.size())
	for i in v.size():
		var k := v[i].snapped(Vector3.ONE * 1e-4)
		if not weld.has(k):
			weld[k] = i
		root[i] = weld[k]
	var parent := range(v.size())
	var find := func(f: Callable, a: int) -> int:
		while parent[a] != a:
			parent[a] = parent[parent[a]]
			a = parent[a]
		return a
	for t in range(0, idx.size(), 3):
		var a: int = find.call(find, root[idx[t]])
		for j in [1, 2]:
			var b: int = find.call(find, root[idx[t + j]])
			if a != b:
				parent[b] = a
	var area := {}
	for t in range(0, idx.size(), 3):
		var c: int = find.call(find, root[idx[t]])
		area[c] = area.get(c, 0.0) + (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]]).length() * 0.5
	var biggest: float = area.values().max()
	var kept := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if area[find.call(find, root[idx[t]])] >= biggest * ratio:
			kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
	var sizes: Array = area.values()
	sizes.sort()
	sizes.reverse()
	print("  %s: %d parts, areas %s; %d of %d triangles kept" % [key, area.size(),
		sizes.slice(0, 8).map(func(x): return snappedf(x / biggest, 0.001)), kept.size() / 3, idx.size() / 3])
	arrays[Mesh.ARRAY_INDEX] = kept
	var mat := mesh.surface_get_material(0)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mat)
	ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
	return OK


## Drops the triangles whose middle lies inside the box lo..hi (model units).
func _cutbox(key: String, lo: Vector3, hi: Vector3) -> int:
	var path := MODELS + key + ".res"
	var mesh: ArrayMesh = load(path)
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var kept := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var c := (v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0
		var inside := c.x >= lo.x and c.x <= hi.x and c.y >= lo.y and c.y <= hi.y and c.z >= lo.z and c.z <= hi.z
		if not inside:
			kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
	print("  %s: %d of %d triangles kept (box %s .. %s)" % [key, kept.size() / 3, idx.size() / 3, lo, hi])
	arrays[Mesh.ARRAY_INDEX] = kept
	var mat := mesh.surface_get_material(0)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mat)
	ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
	return OK


## Prints where a wide slab at the bottom (a base under a figure) seems to end, as a hint for cut_below.
func _report_base(v: PackedVector3Array) -> void:
	var lo := INF
	var hi := -INF
	for p in v:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var n := 50
	var ext := []
	for s in 18:
		var y0 := lo + (hi - lo) * s / n
		var y1 := lo + (hi - lo) * (s + 1) / n
		var mn := Vector2(INF, INF)
		var mx := -mn
		for p in v:
			if p.y >= y0 and p.y < y1:
				mn = mn.min(Vector2(p.x, p.z))
				mx = mx.max(Vector2(p.x, p.z))
		ext.append((mx - mn).length() if mx.x > mn.x else 0.0)
	for s in range(1, 12):
		var below: float = ext.slice(0, s).max()
		var above: float = ext.slice(s, s + 4).max()
		if below > 0.0 and above > 0.0 and below > above * 1.35:
			print("  base? wide part up to y=%.3f (%.2f vs %.2f wide above)" % [lo + (hi - lo) * s / n, below, above])
			return


# ---------------------------------------------------------------- scenes

func _scenes(only: Array) -> int:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC))
	var script := load("res://jokers/augmented_joker.gd")
	var suit_script := load("res://jokers/suit_shape.gd")
	var made := 0
	for key in spec:
		if not only.is_empty() and not only.has(key):
			continue
		if not FileAccess.file_exists(MODELS + key + ".res"):
			print("%s: no model yet" % key)
			continue
		var s: Dictionary = spec[key]
		var root := Node3D.new()
		root.set("name", key)
		root.set_script(script)

		# Model: the pivot at the figure's feet; fill / spin / shake move this node.
		var model := Node3D.new()
		model.name = "Model"
		root.add_child(model)
		var mesh: ArrayMesh = load(MODELS + key + ".res")
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		mi.material_override = load(MODELS + key + "_mat.res") # (per instance, so it can glow)
		var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var basis := Basis()
		if s.has("tilt"):
			var tilt: Array = s.tilt
			basis = Basis.from_euler(Vector3(deg_to_rad(tilt[0]), 0, deg_to_rad(tilt[1])))
		else:
			basis = _upright(mesh)
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p in verts:
			var q := basis * p
			lo = lo.min(q)
			hi = hi.max(q)
		var height: float = s.get("height", 0.11)
		var k := height / (hi.y - lo.y)
		var width := maxf(hi.x - lo.x, hi.z - lo.z) * k
		if width > 0.14: # wide things (a banner, a bus) must still fit next to the others
			k *= 0.14 / width
		var mid := Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
		if s.get("center", "") == "mass": # stands on the pedestal's middle by its weight, not its outline
			var c := _centroid(mesh, basis)
			mid = Vector3(c.x, lo.y, c.z)
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * k), -mid * k)
		model.add_child(mi)
		var top := (hi.y - lo.y) * k
		var fill_at := "Model"
		if s.has("split"):
			fill_at = _split(key, mi, model, top * float(s.split))
		if s.has("cards"):
			var c: Dictionary = s.cards
			var fan := _card_fan(c.ranks, c.get("size", 0.05), suit_script)
			var at: Array = c.get("at", [0, 0, 0.03])
			fan.position = Vector3(at[0], at[1], at[2])
			root.add_child(fan)
			if c.get("only", false): # the cards are the whole joker (no generated figure)
				root.remove_child(model)
				model.free()
				model = Node3D.new()
				model.name = "Model"
				root.add_child(model)
				root.remove_child(fan)
				model.add_child(fan)
				top = c.get("size", 0.05) * 1.1

		if s.has("label") or s.has("text"):
			var info: Array = s.get("label", s.get("text"))
			var label := Label3D.new()
			label.name = "Value" if s.has("label") else "Sign"
			label.position.y = top + 0.02
			label.pixel_size = 0.0005
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if s.has("label") else BaseMaterial3D.BILLBOARD_FIXED_Y
			label.font_size = 36
			label.outline_size = 8
			root.add_child(label)
			root.set("label_node", NodePath(label.name))
			root.set("label_source", info[0])
			root.set("label_format", info[1] if info.size() > 1 else "%s")
		if s.has("glow"):
			root.set("glow_node", NodePath("Model"))
			root.set("glow_source", s.glow[0])
			root.set("glow_energy", (s.glow[1] if s.glow.size() > 1 else 1.5) * 0.3) # emission = its own texture: a little goes a long way
		if s.has("fill"):
			root.set("fill_node", NodePath(fill_at))
			root.set("fill_source", s.fill[0])
			root.set("fill_max", s.fill[1])
			root.set("fill_min", s.fill[2])
			root.set("fill_uniform", fill_at == "Model") # (a split figure: only its top sinks down)
		if s.has("alpha"):
			root.set("alpha_node", NodePath("Model"))
			root.set("alpha_source", s.alpha)
		if s.get("shake", false):
			root.set("shake_node", NodePath("Model"))
			if s.shake is String: # trembles only while this is true (DNA: the first hand of the round)
				root.set("shake_source", s.shake)
		if s.has("spin"):
			root.set("spin_node", NodePath("Model"))
			root.set("spin_speed", s.spin)
		if s.has("suit"):
			# a suit symbol hovering above the figure: only the current suit shows, in its colour
			var sym := Node3D.new()
			sym.name = "Symbol"
			sym.position.y = top + 0.025
			root.add_child(sym)
			for suit in ["Hearts", "Diamonds", "Clubs", "Spades"]:
				var shape := CSGCombiner3D.new()
				shape.set_script(suit_script)
				shape.name = suit
				shape.set("suit", suit)
				shape.set("size", 0.025)
				shape.visible = false
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.9, 0.9, 0.9)
				shape.material_override = m
				sym.add_child(shape)
			root.set("suit_node", NodePath("Symbol"))
			root.set("suit_shapes", NodePath("Symbol"))
			root.set("suit_source", s.suit)
			if not s.has("glow"):
				root.set("glow_node", NodePath("Symbol"))

		_own(root, root)
		var packed := PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, "res://jokers/%s.tscn" % key)
		root.free()
		made += 1
	print("%d scenes written" % made)
	return OK


## "cards": a little fan of playing cards built from code, so ranks can be read (a straight for
## Crazy Joker and The Order - the generator can't write the ranks). {"ranks": [...], "size": card
## height, "at": [x, y, z], "only": true = no generated figure, just the cards}
func _card_fan(ranks: Array, h: float, suit_script: Script) -> Node3D:
	var fan := Node3D.new()
	fan.name = "Cards"
	var suits := ["Hearts", "Spades", "Diamonds", "Clubs"]
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.96, 0.95, 0.9)
	paper.roughness = 0.6
	for i in ranks.size():
		var red := i % 2 == 0
		var ink := Color(0.85, 0.15, 0.2) if red else Color(0.12, 0.13, 0.2)
		var pivot := Node3D.new()
		pivot.name = "Card%d" % i
		pivot.rotation.z = deg_to_rad(((ranks.size() - 1) * 0.5 - i) * 18.0) # spread like a hand of cards
		pivot.position.z = i * 0.0025
		fan.add_child(pivot)
		var card := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(h * 0.7, h, 0.0015)
		card.mesh = bm
		card.material_override = paper
		card.position.y = h * 0.5
		pivot.add_child(card)
		for corner in [Vector3(-0.25, 0.37, 0), Vector3(0.25, -0.37, 0)]:
			var l := Label3D.new()
			l.text = str(ranks[i])
			l.font_size = 64
			l.pixel_size = h * 0.0042
			l.modulate = ink
			l.outline_size = 0
			l.double_sided = false # (no mirror writing on the backs)
			l.position = Vector3(corner.x * h, h * 0.5 + corner.y * h, 0.001)
			if corner.y < 0:
				l.rotation.z = PI
			pivot.add_child(l)
		# the suit under the corner rank (the cards overlap, the corners stay visible), big in the
		# middle of the top card
		for big in ([false, true] if i == ranks.size() - 1 else [false]):
			var sym := CSGCombiner3D.new()
			sym.set_script(suit_script)
			sym.set("suit", suits[i % 4])
			sym.set("size", h * (0.3 if big else 0.12))
			sym.set("depth", 0.001)
			var m := StandardMaterial3D.new()
			m.albedo_color = ink
			sym.material_override = m
			sym.position = Vector3(0, h * 0.42, 0.001) if big else Vector3(-0.25 * h, h * 0.68, 0.001)
			pivot.add_child(sym)
	return fan


## "split": the figure in two at that height (e.g. Ice Cream: cone and scoops). The upper part goes
## on its own node Model/Top, pivoted at the cut, so a fill squashes only it down onto the lower part
## (the scoops melt into the cone). Both halves are saved as models/<key>_low.res / _top.res.
func _split(key: String, mi: MeshInstance3D, model: Node3D, at: float) -> String:
	var arrays := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var low := PackedInt32Array()
	var high := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var c := mi.transform * ((v[idx[t]] + v[idx[t + 1]] + v[idx[t + 2]]) / 3.0)
		(low if c.y < at else high).append_array([idx[t], idx[t + 1], idx[t + 2]])
	var mat := mi.mesh.surface_get_material(0)
	var parts := {}
	for part in [["low", low], ["top", high]]:
		arrays[Mesh.ARRAY_INDEX] = part[1]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, mat)
		ResourceSaver.save(m, MODELS + key + "_" + part[0] + ".res", ResourceSaver.FLAG_COMPRESS)
		parts[part[0]] = load(MODELS + key + "_" + part[0] + ".res")
	mi.mesh = parts["low"]
	var top := Node3D.new()
	top.name = "Top"
	top.position.y = at
	model.add_child(top)
	var tmi := MeshInstance3D.new()
	tmi.name = "Mesh"
	tmi.mesh = parts["top"]
	tmi.material_override = mi.material_override
	tmi.transform = Transform3D(Basis(), Vector3(0, -at, 0)) * mi.transform
	top.add_child(tmi)
	return "Model/Top"


## The middle of a figure by its surface (each triangle weighted by its area), turned by basis.
func _centroid(mesh: ArrayMesh, basis: Basis) -> Vector3:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var sum := Vector3.ZERO
	var w := 0.0
	for t in range(0, idx.size(), 3):
		var a := basis * v[idx[t]]
		var b := basis * v[idx[t + 1]]
		var c := basis * v[idx[t + 2]]
		var area := (b - a).cross(c - a).length() * 0.5
		sum += (a + b + c) / 3.0 * area
		w += area
	return sum / w if w > 0.0 else Vector3.ZERO


## The generator often leans a figure a little: turns it so the line from the middle of its feet
## (the lowest 8 %) to the middle of the whole figure stands vertical (at most 30°).
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


func _own(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_own(child, owner)
