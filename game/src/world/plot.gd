extends StaticBody3D
## Farming: a hole dug with a mattock (right-click), and what grows from it.
## Each one is kept in Game.plantings by its uid: {x, y, z, dug (the Game.time
## it was dug), item (what was buried in it: {id, age}), compost (true:
## compost buried with it), buried (the Game.time it was filled in over them),
## plant / tree (what grows there), sprout (the Game.time it came up), days
## (how long it takes to grow), fed (true: grown with compost, for twice the
## yield), picked (the Game.time its shoot was last picked), s, yaw}.
##
## Kneel at a hole (C) to plant in it (work_spot.plot_options): lay out one
## thing, and compost if you like, and click them into the hole and the earth
## back over them. The hole is then a mound, and FILL_AFTER after it was
## buried the mound is gone: something that grows (an item with `plant` or
## `plant_tree`) comes up as a sprout and grows for GROW_DAYS (half that with
## compost buried with it); anything else is buried for good. A hole left
## empty fills itself in FILL_AFTER after it was dug. Compost held and right-clicked on any
## growing plant (feed) cuts what is left of its growing by Harvestable.FEED_CUT.
## A sprouting tree is a chunk tree regrowing from no stump (stump.gd); this
## node is the hole, and a young seed fern until it is grown, when its chunk
## swaps it for a Harvestable ("planted_seed_fern").

const Harvestable := preload("res://src/world/harvestable.gd")

const FILL_AFTER := 1440.0     # a game day (24 min)
const GROW_DAYS := 14.0
const SHOOT_UNTIL := 1.0 / 3.0  # a young plant's shoot can be picked until it is this far grown
const SHOOTS := {"seed_fern": "seed_fern_shoot"}
const HOLE_R := 0.3

var uid := ""
var chunk: Node3D
var _mesh: MeshInstance3D
var _item_mesh: MeshInstance3D
var _compost_mesh: MeshInstance3D
var _shown := -1.0
var _tick := 0.0


func setup(c: Node3D, id: String) -> Node3D:
	chunk = c
	uid = id
	return self


static func settle(id: String) -> String:
	## Brings a planting up to the clock: a hole whose time is up fills in (its
	## plant sprouting, or what was in it buried). Returns what it is now:
	## "hole", "herb" (a young plant), "grown" (a grown plant), "tree", or ""
	## (gone).
	var rec: Dictionary = Game.plantings.get(id, {})
	if rec.is_empty():
		return ""
	if not rec.has("plant") and not rec.has("tree"):
		if rec.has("item") and not rec.has("buried"):
			rec.buried = rec.dug  # set in a hole before holes were filled in by hand
		var since := float(rec.get("buried", rec.dug))
		if Game.time < since + FILL_AFTER:
			return "hole"
		if not rec.has("buried"):
			Game.plantings.erase(id)  # an empty hole fills itself in
			return ""
		var def := Items.def(rec.get("item", {}).get("id", ""))
		var sprout := since + FILL_AFTER
		var fed: bool = rec.get("compost", false)
		rec.days = GROW_DAYS * (0.5 if fed else 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id)
		if def.has("plant_tree"):
			rec.tree = def.plant_tree
			rec.s = rng.randf_range(0.85, 1.15)
			rec.yaw = rng.randf() * TAU
			# Growing up out of the ground, like a tree from its stump.
			Game.felled[id] = {"at": sprout, "regrow": sprout + float(rec.days) * Game.DAY_LENGTH, "kind": rec.tree, "planted": true}
		elif def.has("plant"):
			rec.plant = def.plant
			rec.yaw = rng.randf() * TAU
		else:
			Game.plantings.erase(id)  # filled in, burying whatever was in it
			return ""
		rec.erase("item")
		rec.erase("compost")
		if fed:
			rec.fed = true
		rec.sprout = sprout
	if rec.has("tree"):
		return "tree"
	return "herb" if growth_of(rec) < 1.0 else "grown"


static func growth_of(rec: Dictionary) -> float:
	return clampf((Game.time - float(rec.get("sprout", Game.time))) / (float(rec.get("days", GROW_DAYS)) * Game.DAY_LENGTH), 0.0, 1.0)



func rec() -> Dictionary:
	return Game.plantings.get(uid, {})


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = HOLE_R + 0.05
	cyl.height = 0.4
	cs.shape = cyl
	cs.position.y = 0.1
	add_child(cs)
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_item_mesh = MeshInstance3D.new()
	_item_mesh.position.y = 0.04
	_item_mesh.scale = Vector3.ONE * 0.8
	add_child(_item_mesh)
	_compost_mesh = MeshInstance3D.new()
	_compost_mesh.mesh = Assets.mesh("item_compost")
	_compost_mesh.position = Vector3(0.05, 0.02, -0.04)
	add_child(_compost_mesh)
	_refresh()


func is_hole() -> bool:
	## A hole or the mound over what was buried in it: not yet grown.
	return not rec().has("plant")


func open_hole() -> bool:
	## Dug and nothing buried in it yet: kneel to plant in it.
	var r := rec()
	return not r.is_empty() and not r.has("plant") and not r.has("buried")


func wants_craft() -> bool:
	## C at a hole kneels to plant in it; at anything else here it is the
	## usual kneeling to craft.
	return open_hole()


func craft_interact(player: Node) -> void:
	var w: Node = player.world if player else null
	if w and w.has_method("start_plot_work"):
		w.start_plot_work(self)


func show_planting(id: String, compost: bool) -> void:
	## While you kneel planting: what is set in the open hole so far.
	if not open_hole():
		return
	_item_mesh.mesh = Assets.mesh("item_" + id) if id != "" else null
	_compost_mesh.visible = compost


func bury(id: String, age: float, compost: bool) -> void:
	## The earth goes back in over it (work_spot._plot_step): a mound, gone a
	## day from now.
	var r := rec()
	if r.is_empty():
		return
	r.item = {"id": id, "age": age}
	if compost:
		r.compost = true
	r.buried = Game.time
	_shown = -1.0
	_refresh()


func _refresh() -> void:
	var r := rec()
	if r.is_empty():
		return
	if is_hole():
		var look := -3.0 if r.has("buried") else -2.0
		if _shown != look:
			_shown = look
			_mesh.mesh = Assets.mesh("mound" if r.has("buried") else "hole")
			_mesh.rotation.y = hash(uid) % 628 / 100.0
			_item_mesh.mesh = null  # under the earth, or not yet set in
			_compost_mesh.visible = false
		return
	_item_mesh.mesh = null
	_compost_mesh.visible = false
	var g := growth_of(r)
	if absf(g - _shown) < 0.002:
		return
	_shown = g
	var kind: Dictionary = Harvestable.KINDS.get("planted_" + String(r.plant), {})
	_mesh.mesh = Assets.mesh(kind.get("bare", r.plant))  # no seeds till it is grown
	_mesh.rotation.y = float(r.get("yaw", 0.0))
	_mesh.scale = Vector3.ONE * lerpf(0.08, 1.0, g)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 1.0
	var r := rec()
	if r.is_empty():
		queue_free()
		return
	var was := is_hole()
	var now := settle(uid)
	if now != ("hole" if was else "herb"):
		# Filled in or grown: the chunk puts up what comes next, if anything.
		if now != "":
			chunk.add_planting(uid)
		queue_free()
		return
	_refresh()


func prompt(_player: Node) -> String:
	var r := rec()
	if r.is_empty():
		return ""
	if is_hole():
		var left := maxi(ceili((float(r.get("buried", r.dug)) + FILL_AFTER - Game.time) / 60.0), 1)
		if not r.has("buried"):
			return "A freshly dug hole: kneel to plant in it [C]   (it fills in within %d min)" % left
		var id: String = r.get("item", {}).get("id", "")
		var def := Items.def(id)
		if def.has("plant") or def.has("plant_tree"):
			return "%s planted here%s: it sprouts within %d min" % [Items.item_name(id), " with compost" if r.get("compost", false) else "", left]
		return "%s buried here: the mound settles within %d min" % [Items.item_name(id), left]
	var g := growth_of(r)
	var what := "Young %s, growing (%d%%)" % [Harvestable.KINDS[r.plant].name, roundi(g * 100.0)]
	if Game.inventory.held_id() == "compost":
		return what + Harvestable.feed_hint(_left(r))
	if "dig" in Items.def(Game.inventory.held_id()).get("tags", []):
		return "%s: swing the mattock to dig it up" % what
	if SHOOTS.has(r.plant) and g < SHOOT_UNTIL:
		var wait := shoot_wait(r)
		if wait > 0.0:
			return "%s; a new shoot in %d min" % [what, ceili(wait / 60.0)]
		return "Pick the shoot [E]   (%s)" % what
	return what


static func shoot_wait(r: Dictionary) -> float:
	## Seconds until a picked young plant has a shoot to pick again (a day
	## after the last was picked), or 0.
	return maxf(float(r.get("picked", -INF)) + Game.DAY_LENGTH - Game.time, 0.0)


func interact(_player: Node) -> void:
	var r := rec()
	if r.is_empty():
		return
	var inv = Game.inventory
	if is_hole():
		if open_hole():
			Game.notify("Kneel at the hole (%s) to plant something in it." % Settings.button_name("craft"))
		return
	if SHOOTS.has(r.plant) and growth_of(r) < SHOOT_UNTIL and shoot_wait(r) <= 0.0:
		var shoot: String = SHOOTS[r.plant]
		if inv.add(shoot, 1) > 0:
			Game.notify("You have no room to carry it.")
			return
		r.sprout = Game.time  # it grows again from its roots
		r.picked = Game.time  # and has no new shoot to pick for a day
		Sfx.play("pickup", -8.0)
		Game.picked.emit(shoot)
		Game.notify("You pick the %s. It will sprout again from its roots, with a new shoot in a day." % Items.item_name(shoot).to_lower())
		_shown = -1.0
		_refresh()


func _left(r: Dictionary) -> float:
	return float(r.sprout) + float(r.get("days", GROW_DAYS)) * Game.DAY_LENGTH - Game.time


func feed(_player: Node) -> bool:
	## Compost worked in round a young plant: FEED_CUT off the time it has left.
	var r := rec()
	if r.is_empty() or is_hole():
		return false
	r.sprout = float(r.sprout) - _left(r) * Harvestable.FEED_CUT
	Harvestable.fed_note(_left(r))
	_shown = -1.0
	_refresh()
	return true


func dig() -> void:
	## A mattock swing digs a young plant up for good, giving its root back.
	var r := rec()
	if r.is_empty() or is_hole():
		return
	var root := "fern_root" if r.plant == "seed_fern" else ""
	if root != "":
		var left: int = Game.inventory.add(root, 1)
		var world: Node = Game.player.world if Game.player else null
		if left > 0 and world and world.has_method("pile_item"):
			world.pile_item(root, left, global_position + Vector3(0.4, 0.3, 0))
		Game.picked.emit(root)
	Game.plantings.erase(uid)
	Sfx.play_at("thud", global_position, -6.0)
	Game.notify("You dig up the young plant%s." % (", roots and all" if root == "" else ": %s x1" % Items.item_name(root)))
	queue_free()
