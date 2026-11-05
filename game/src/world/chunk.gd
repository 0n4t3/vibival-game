extends Node3D
## One 32 m square of swamp: terrain mesh, heightmap collision, vegetation
## (MultiMesh per species) and generated pickups / harvestables.

const SIZE := 32
const Pickup := preload("res://src/world/pickup.gd")
const Harvestable := preload("res://src/world/harvestable.gd")
const Stump := preload("res://src/world/stump.gd")
const Plot := preload("res://src/world/plot.gd")

## Tree kinds: trunk radius for collision/avoidance, and where they grow.
## `height` is the trunk's height at scale 1, and `soft` trees can be felled
## with a stone axe (the scale trees need a metal one).
const TREES := {
	"lepidodendron": {"name": "Lepidodendron", "r": 0.55, "tries": 6, "min_h": -0.6, "max_h": 99.0, "scale": [0.8, 1.35], "height": 20.0, "soft": false},
	"sigillaria": {"name": "Sigillaria", "r": 0.75, "tries": 2, "min_h": 0.5, "max_h": 99.0, "scale": [0.8, 1.2], "height": 14.0, "soft": false},
	"calamites": {"name": "Calamites", "r": 0.3, "tries": 9, "min_h": -0.4, "max_h": 1.8, "scale": [0.7, 1.4], "height": 10.0, "soft": true},
	"tree_fern": {"name": "Tree Fern", "r": 0.45, "tries": 6, "min_h": 0.35, "max_h": 99.0, "scale": [0.7, 1.3], "height": 5.0, "soft": true},
}
## The world comes out the same at every graphics quality: trees, boulders,
## harvestables and pickups are rolled at this density (Medium's), and the
## quality setting only thins or thickens the ground cover, which is just
## for looks, on rolls of its own.
const WORLD_DENSITY := 0.75
const SINK := 0.2        # trees stand this far down in the ground
const STUMP_H := 0.45    # a felled tree leaves a stump this tall
const REGROW := [16.0, 20.0]  # game days for a stump to grow back into a tree
const DECOR := {
	"fern": {"tries": 70, "clumps": 4, "min_h": 0.15, "max_h": 99.0, "scale": [0.7, 1.5]},
	"horsetail": {"tries": 40, "clumps": 2, "min_h": -0.35, "max_h": 1.2, "scale": [0.7, 1.4]},
	"moss": {"tries": 20, "min_h": 0.1, "max_h": 99.0, "scale": [0.6, 1.6]},
}

var cx := 0
var cz := 0
var trunks := PackedVector3Array()   # (x, z, radius) in world space: trunks and boulders
## Every tree: {uid, kind, at (world point on the ground at its foot), s, yaw,
## r (trunk radius), mm (its kind's MultiMesh), i (instance), shape, trunk
## (index in trunks), crown (a tree fern's harvestable crown), stump}.
var trees: Array = []
var _trunk_body: StaticBody3D

static var _rock_hull := PackedVector3Array()


func build(chunk_x: int, chunk_z: int, terrain: RefCounted, world: Node) -> void:
	cx = chunk_x
	cz = chunk_z
	position = Vector3(cx * SIZE, 0, cz * SIZE)
	var ox := float(cx * SIZE)
	var oz := float(cz * SIZE)

	# --- Heights (1 m grid shared by collision and mesh) ---
	var n := SIZE + 1
	var hmap := PackedFloat32Array()
	hmap.resize(n * n)
	for z in n:
		for x in n:
			hmap[z * n + x] = terrain.height(ox + x, oz + z)

	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = hmap
	cs.shape = shape
	cs.position = Vector3(SIZE * 0.5, 0, SIZE * 0.5)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(cs)
	add_child(body)

	# --- Terrain mesh: flat-shaded triangles, colour jittered per face ---
	var step := Settings.terrain_step()
	var b = Assets.builder()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cx, cz, Game.world_seed))
	var shade := RandomNumberGenerator.new()
	shade.seed = rng.seed
	for z in range(0, SIZE, step):
		for x in range(0, SIZE, step):
			var p00 := Vector3(x, hmap[z * n + x], z)
			var p10 := Vector3(x + step, hmap[z * n + x + step], z)
			var p01 := Vector3(x, hmap[(z + step) * n + x], z + step)
			var p11 := Vector3(x + step, hmap[(z + step) * n + x + step], z + step)
			var slope := maxf(absf(p00.y - p11.y), absf(p10.y - p01.y)) / step
			var col: Color = terrain.ground_color(ox + x, oz + z, (p00.y + p11.y) * 0.5, slope)
			if (x + z) % (step * 2) == 0:
				b.tri(p00, p10, p01, col * shade.randf_range(0.92, 1.06), "terrain")
				b.tri(p10, p11, p01, col * shade.randf_range(0.92, 1.06), "terrain")
			else:
				b.tri(p00, p11, p01, col * shade.randf_range(0.92, 1.06), "terrain")
				b.tri(p00, p10, p11, col * shade.randf_range(0.92, 1.06), "terrain")
	var ground := MeshInstance3D.new()
	ground.mesh = b.commit(Assets.materials)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# The rest rolls on from where full-detail terrain leaves off, whatever
	# the terrain step.
	for i in SIZE * SIZE * 2:
		rng.randf()

	# --- Vegetation ---
	var density := Settings.vegetation_density()
	var look := RandomNumberGenerator.new()  # ground cover thinned or added for the quality
	look.seed = hash(Vector3i(cz, cx, Game.world_seed))
	var trunk_body := StaticBody3D.new()
	_trunk_body = trunk_body
	trunk_body.collision_layer = 1
	trunk_body.collision_mask = 0
	trunk_body.set_meta("hard", true)  # thrown rocks knock against it
	add_child(trunk_body)
	var placed: Array[Vector2] = []
	for kind in TREES:
		var def: Dictionary = TREES[kind]
		var xforms := []
		var mine := []
		for i in roundi(def.tries * WORLD_DENSITY + rng.randf()):
			var lx := rng.randf_range(1.0, SIZE - 1.0)
			var lz := rng.randf_range(1.0, SIZE - 1.0)
			var h: float = terrain.height(ox + lx, oz + lz)
			if h < def.min_h or h > def.max_h or terrain.rockiness(ox + lx, oz + lz) > 0.3:
				continue
			if placed.any(func(q): return q.distance_to(Vector2(lx, lz)) < 2.2):
				continue
			placed.append(Vector2(lx, lz))
			var s := rng.randf_range(def.scale[0], def.scale[1])
			var yaw := rng.randf() * TAU
			var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(lx, h - SINK, lz))
			var tr: float = def.r * s
			var tcs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = tr
			cyl.height = 6.0
			tcs.shape = cyl
			tcs.position = Vector3(lx, h + 2.5, lz)
			trunk_body.add_child(tcs)
			var uid := "t%d_%d" % [roundi((ox + lx) * 10.0), roundi((oz + lz) * 10.0)]
			var tree := {"uid": uid, "kind": kind, "at": Vector3(ox + lx, h, oz + lz), "s": s, "yaw": yaw, "r": tr,
					"i": xforms.size(), "shape": tcs, "trunk": trunks.size(), "crown": null, "stump": null, "xform": t}
			trunks.append(Vector3(ox + lx, oz + lz, tr))
			# The random rolls are the same whether or not it has been felled,
			# so the rest of the chunk always comes out the same.
			var crowned: bool = kind == "tree_fern" and rng.randf() < 0.5
			var crown_yaw := rng.randf() * TAU if crowned else 0.0
			var state: Dictionary = Game.felled.get(uid, {})
			if not state.is_empty() and not state.get("cleared", false) and not state.has("burnt") and Game.time >= float(state.regrow):
				Game.felled.erase(uid)  # grown back while you were away
				state = {}
			if state.is_empty():
				xforms.append(t)
				if crowned:
					# The fresh crown sits on top of the trunk (5 m at scale 1).
					tree.crown = _add_harvestable("tree_fern", Vector3(lx, h, lz), crown_yaw, 0, 5.0 * s - 0.2, s)
			else:
				xforms.append(Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
				tcs.disabled = true
				if state.get("cleared", false):
					_trunk_r(tree.trunk, 0.0)
				else:
					_add_stump(tree, state)
			mine.append(tree)
		var mm := _add_multimesh(kind, xforms, Settings.view_distance, true)
		for tree in mine:
			tree.mm = mm
		trees.append_array(mine)

	for kind in DECOR:
		var def: Dictionary = DECOR[kind]
		var xforms := []
		var spots: Array[Vector2] = []
		for i in roundi(def.tries * WORLD_DENSITY):
			spots.append(Vector2(rng.randf_range(0.0, SIZE), rng.randf_range(0.0, SIZE)))
		# Dense thickets: tight clumps of 15-25 plants.
		for c in roundi(def.get("clumps", 0) * WORLD_DENSITY + rng.randf() * 0.5):
			var centre := Vector2(rng.randf_range(2.0, SIZE - 2.0), rng.randf_range(2.0, SIZE - 2.0))
			for i in rng.randi_range(15, 25):
				var o := Vector2(rng.randfn(0.0, 1.6), rng.randfn(0.0, 1.6))
				spots.append((centre + o).clamp(Vector2.ZERO, Vector2(SIZE, SIZE)))
		# Above Medium, more cover on rolls of its own; below, some left out.
		var rolled := spots.size()
		for i in maxi(roundi(def.tries * (density - WORLD_DENSITY)), 0):
			spots.append(Vector2(look.randf_range(0.0, SIZE), look.randf_range(0.0, SIZE)))
		var keep := minf(density / WORLD_DENSITY, 1.0)
		for k in spots.size():
			var r := rng if k < rolled else look
			var lx := spots[k].x
			var lz := spots[k].y
			var h: float = terrain.height(ox + lx, oz + lz)
			if h < def.min_h or h > def.max_h:
				continue
			var s := r.randf_range(def.scale[0], def.scale[1])
			var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE * s), Vector3(lx, h - 0.05, lz))
			if look.randf() < keep:
				xforms.append(t)
		_add_multimesh(kind, xforms, 40.0 if Settings.quality == 0 else 60.0, false)

	# Rocky knolls get boulders.
	var rocks := []
	for i in 3:
		var lx := rng.randf_range(2.0, SIZE - 2.0)
		var lz := rng.randf_range(2.0, SIZE - 2.0)
		if terrain.rockiness(ox + lx, oz + lz) > 0.35:
			var h: float = terrain.height(ox + lx, oz + lz)
			rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.5)), Vector3(lx, h - 0.4, lz)))
	_add_multimesh("rock_big", rocks, Settings.view_distance, true)
	# Boulders are solid: a hull of the rock mesh, and an obstacle for animals.
	for t: Transform3D in rocks:
		var rcs := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		hull.points = t * _boulder_hull()
		rcs.shape = hull
		trunk_body.add_child(rcs)
		trunks.append(Vector3(ox + t.origin.x, oz + t.origin.z, 1.4 * t.basis.get_scale().x))

	# --- Harvestables and pickups ---
	var idx := 0
	for spec in [["seed_fern", 0.45, 0.5, 99.0], ["fern", 2.0, 0.2, 99.0], ["rotting_log", 0.4, 0.3, 99.0], ["clay_bank", 0.35, -0.25, 0.4]]:
		var count := int(spec[1]) + (1 if rng.randf() < fmod(spec[1], 1.0) else 0)
		for i in count:
			idx += 1
			var lx := rng.randf_range(2.0, SIZE - 2.0)
			var lz := rng.randf_range(2.0, SIZE - 2.0)
			var h: float = terrain.height(ox + lx, oz + lz)
			if h >= spec[2] and h <= spec[3]:
				_add_harvestable(spec[0], Vector3(lx, h - 0.05, lz), rng.randf() * TAU, idx)

	var items := [["stick", 3, 0.1], ["stone", 1, -0.3], ["flint", 0, 0.0]]
	for spec in items:
		var count: int = spec[1] + (1 if rng.randf() < 0.5 else 0)
		var lx0 := rng.randf_range(2.0, SIZE - 2.0)
		var lz0 := rng.randf_range(2.0, SIZE - 2.0)
		var rocky: float = terrain.rockiness(ox + lx0, oz + lz0)
		if spec[0] != "stick" and rocky > 0.1:
			count += 2
		for i in count:
			idx += 1
			var uid := "p%d:%d:%d" % [cx, cz, idx]
			var lx := clampf(lx0 + rng.randf_range(-6, 6), 0.5, SIZE - 0.5) if spec[0] != "stick" else rng.randf_range(1, SIZE - 1)
			var lz := clampf(lz0 + rng.randf_range(-6, 6), 0.5, SIZE - 0.5) if spec[0] != "stick" else rng.randf_range(1, SIZE - 1)
			var h: float = terrain.height(ox + lx, oz + lz)
			if h < spec[2] or Game.taken.has(uid):
				continue
			var p := Pickup.new().setup(spec[0], 1, 0.0, uid)
			p.position = Vector3(lx, h, lz)
			p.rotation.y = rng.randf() * TAU
			add_child(p)

	# --- Holes dug for planting, and what grows from them ---
	for uid in Game.plantings.keys():
		var rec: Dictionary = Game.plantings[uid]
		if floori(float(rec.x) / SIZE) == cx and floori(float(rec.z) / SIZE) == cz:
			add_planting(uid)


func add_planting(uid: String) -> void:
	## Puts up a hole, or what grows from it, as it stands now (plot.gd).
	var rec: Dictionary = Game.plantings.get(uid, {})
	var at := Vector3(float(rec.get("x", 0.0)) - cx * SIZE, float(rec.get("y", 0.0)), float(rec.get("z", 0.0)) - cz * SIZE)
	match Plot.settle(uid):
		"hole", "herb":
			var p := Plot.new().setup(self, uid)
			p.position = at
			add_child(p)
		"grown":
			var h := Harvestable.new().setup("planted_" + String(rec.plant), uid)
			h.position = at - Vector3(0, 0.05, 0)
			h.rotation.y = float(rec.get("yaw", 0.0))
			add_child(h)
		"tree":
			_add_planted_tree(uid, rec, at)


func _add_planted_tree(uid: String, rec: Dictionary, at: Vector3) -> void:
	## A tree grown (or growing) from a planted root: like one of the chunk's
	## own, with a MultiMesh of its own. While it grows it is a stump regrowing,
	## with no stump to see (Game.felled has it as "planted").
	var kind: String = rec.tree
	var s: float = float(rec.get("s", 1.0))
	var yaw: float = float(rec.get("yaw", 0.0))
	var t := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(at.x, at.y - SINK, at.z))
	var tr: float = TREES[kind].r * s
	var tcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = tr
	cyl.height = 6.0
	tcs.shape = cyl
	tcs.position = Vector3(at.x, at.y + 2.5, at.z)
	_trunk_body.add_child(tcs)
	var tree := {"uid": uid, "kind": kind, "at": Vector3(cx * SIZE + at.x, at.y, cz * SIZE + at.z), "s": s, "yaw": yaw, "r": tr,
			"i": 0, "shape": tcs, "trunk": trunks.size(), "crown": null, "stump": null, "xform": t}
	trunks.append(Vector3(tree.at.x, tree.at.z, tr))
	tree.mm = _add_multimesh(kind, [t], Settings.view_distance, true)
	var state: Dictionary = Game.felled.get(uid, {})
	if not state.is_empty() and not state.get("cleared", false) and not state.has("burnt") and Game.time >= float(state.regrow):
		Game.felled.erase(uid)  # grown while you were away
		state = {}
	if not state.is_empty():
		_hide_tree(tree)
		_add_stump(tree, state)
	trees.append(tree)


func _boulder_hull() -> PackedVector3Array:
	## The corners of the boulder mesh, shared by every boulder's collision hull.
	if _rock_hull.is_empty():
		var seen := {}
		for v in Assets.mesh("rock_big").get_faces():
			seen[v.snappedf(0.01)] = true
		_rock_hull = PackedVector3Array(seen.keys())
	return _rock_hull


func _add_harvestable(kind: String, pos: Vector3, yaw: float, idx: int, crown := 0.0, crown_scale := 1.0) -> Node3D:
	var uid := "h%d:%d:%s:%d:%d" % [cx, cz, kind, idx, int(pos.x * 10)]
	if Game.taken.has(uid):
		return null  # dug up for good
	var h := Harvestable.new().setup(kind, uid)
	h.crown = crown
	h.crown_scale = crown_scale
	h.position = pos
	h.rotation.y = yaw
	add_child(h)
	return h


func _add_multimesh(kind: String, xforms: Array, range_end: float, shadows: bool) -> MultiMesh:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Assets.mesh(kind)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = range_end
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and Settings.shadows() \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


# --- Felling and regrowth -------------------------------------------------------
# A felled tree is kept in Game.felled by its uid: {at, regrow, kind}, plus
# cleared = true once its stump has been dug out (nothing grows there again),
# and burnt = the Game.time lightning struck it (it never grows back: stump.gd).
# The tree's instance is hidden and a stump stands in its place, growing a new
# tree that takes over again once it is full grown.

func tree_near(pos: Vector3, fwd: Vector3, reach: float) -> Dictionary:
	## The standing tree whose trunk is within reach of pos, roughly ahead.
	var best := {}
	var best_d := INF
	for t in trees:
		if t.stump != null or Game.felled.has(t.uid):
			continue
		var to: Vector3 = t.at - pos
		to.y = 0.0
		var d: float = to.length() - t.r
		if d < reach and d < best_d and (to.length() < t.r + 0.3 or to.normalized().dot(fwd) > 0.2):
			best = t
			best_d = d
	return best


func fell(t: Dictionary, struck := false) -> void:
	## The tree comes down: its stump is left, and it starts growing back
	## (unless lightning `struck` it: then the stump burns, and never does).
	var days := randf_range(REGROW[0], REGROW[1])
	Game.felled[t.uid] = {"at": Game.time, "regrow": Game.time + days * Game.DAY_LENGTH, "kind": t.kind}
	if struck:
		Game.felled[t.uid].burnt = Game.time
	_hide_tree(t)
	if t.crown and is_instance_valid(t.crown):
		t.crown.queue_free()
	t.crown = null
	_add_stump(t, Game.felled[t.uid])


func regrow(t: Dictionary) -> void:
	## The stump's new tree is full grown: it is an ordinary tree again.
	Game.felled.erase(t.uid)
	if t.stump and is_instance_valid(t.stump):
		t.stump.queue_free()
	t.stump = null
	if t.mm:
		t.mm.set_instance_transform(t.i, t.xform)
	t.shape.disabled = false
	_trunk_r(t.trunk, t.r)


func clear_stump(t: Dictionary) -> void:
	## Dug out with a mattock, roots and all.
	if Game.plantings.has(t.uid):
		# A planted one is gone altogether, leaving the spot free.
		Game.plantings.erase(t.uid)
		Game.felled.erase(t.uid)
		if t.stump and is_instance_valid(t.stump):
			t.stump.queue_free()
		t.stump = null
		_hide_tree(t)
		_trunk_r(t.trunk, 0.0)
		trees.erase(t)
		return
	var state: Dictionary = Game.felled.get(t.uid, {"at": Game.time, "regrow": INF, "kind": t.kind})
	state.cleared = true
	Game.felled[t.uid] = state
	if t.stump and is_instance_valid(t.stump):
		t.stump.queue_free()
	t.stump = null
	_trunk_r(t.trunk, 0.0)


func _hide_tree(t: Dictionary) -> void:
	if t.mm:
		t.mm.set_instance_transform(t.i, Transform3D(Basis().scaled(Vector3.ZERO), t.xform.origin))
	t.shape.disabled = true


func _add_stump(t: Dictionary, state: Dictionary) -> void:
	var st := Stump.new().setup(self, t, state)
	add_child(st)
	st.global_position = Vector3(t.at.x, t.at.y - SINK, t.at.z)
	st.rotation.y = t.yaw
	t.stump = st
	_trunk_r(t.trunk, t.r)


func _trunk_r(i: int, r: float) -> void:
	## Sets how wide a trunk is to animals finding their way around it.
	var v := trunks[i]
	v.z = r
	trunks[i] = v
