extends Node3D
## A softwood house on stilts (group "houses", Game.houses), put up from a
## Softwood House Blueprint (items.gd `blueprint`). Right-clicking with the
## blueprint marks out the site: a holographic outline of the whole house,
## which stays until the house is finished or is torn down by hitting it
## TEARDOWN_HITS times with an axe or a mattock (what was built is dropped
## back on the ground as the materials it took).
##
## The house goes up one part at a time, in PARTS order: four Calamites stilts
## pounded into the ground, the floor and the porch on them, the rope ladder,
## the four walls (the sides with a window each, the front with the doorway),
## the fireplace, the ceiling and the two sides of the roof. Press E at the
## outline with the materials in your bag (a stilt's log carried in your arms)
## and click through the steps (work_spot.gd), each one putting a board, a
## cord, a stone or a lump of clay in place.
##
## Once finished, nothing spawns in it and no animal goes for you inside or
## out on the porch (Game.sheltered), and you sleep there safely. Its floor
## holds what you set down (swamp.floor_height), and the fireplace works like
## a campfire that can't be knocked apart (campfire.gd `hearth`).
##
## Local space: y = 0 is the top of the floor, +Z points out through the
## doorway to the porch and the ladder, -Z to the back wall, and the left wall
## (-X) is on your left as you face the doorway from the porch.

const Campfire := preload("res://src/world/campfire.gd")
const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const HALF_W := 1.7            # half the width of the platform and the room
const BACK := -2.4             # z of the back wall
const DOOR_Z := 1.0            # z of the front wall, between the room and the porch
const EDGE := 2.4              # z of the front edge of the porch
const FLOOR_H := 1.8           # the floor stands this high over the highest ground under it
const WALL_H := 2.2
const T := 0.08                # wall thickness
const ROWS := 8                # rows of boards up a wall
const DOOR := Vector2(0.45, 1.925)       # half width and height of the doorway
const WINDOW_Z := Vector2(-1.15, -0.35)  # where the side walls' windows are along z
const WINDOW_Y := Vector2(1.1, 1.65)     # and how high
const RIDGE := 3.35
const EAVE := Vector2(2.05, 2.0)         # how far out from the middle each eave is, and how high
const ROOF_Z := Vector2(-2.7, 2.7)
const STILTS := [Vector3(-1.55, 0, -2.25), Vector3(1.55, 0, -2.25), Vector3(-1.55, 0, 2.25), Vector3(1.55, 0, 2.25)]
const STILT_R := 0.14
const SINK := 0.3              # how deep the stilts are pounded in
const LADDER := Vector3(0, 0, 2.47)
const LADDER_W := 0.32
const HEARTH := Vector3(0.95, 0, -1.7)
const SPACING := 9.0           # houses stand at least this far apart
const TEARDOWN_HITS := 3
const HIT_WINDOW := 4.0        # seconds within which the blows must land

## The parts, in the order they go up. `steps` is one per item put in place
## (a stilt: stood up, then pounded in four times). `from` says where you
## build it: on the ground beside the house, up on its floor, or wherever you
## stand. `stand` and `face` are where you are put to build it and what you
## look at (local, y up from the floor). Parts built from the ground can be
## built from up in the house too, where you stay.
const PARTS := [
	{"id": "stilt_0", "verb": "Raise the back left stilt", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5, "from": "ground"},
	{"id": "stilt_1", "verb": "Raise the back right stilt", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5, "from": "ground"},
	{"id": "stilt_2", "verb": "Raise the front left stilt", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5, "from": "ground"},
	{"id": "stilt_3", "verb": "Raise the front right stilt", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5, "from": "ground"},
	{"id": "floor", "verb": "Lay the floor", "in": {"board_tree_fern": 6, "cordage": 3}, "steps": 9, "from": "ground",
		"stand": Vector3(-3.4, 0, -0.7), "face": Vector3(0, 0, -0.7)},
	{"id": "porch", "verb": "Lay the porch", "in": {"board_tree_fern": 4, "cordage": 3}, "steps": 7, "from": "ground",
		"stand": Vector3(0, 0, 4.4), "face": Vector3(0, 0, 1.7)},
	{"id": "ladder", "verb": "Hang the rope ladder", "in": {"cordage": 4, "stick": 6}, "steps": 10, "from": "ground",
		"stand": Vector3(0.3, 0, 4.3), "face": Vector3(0, -0.9, 2.47)},
	{"id": "wall_back", "verb": "Put up the back wall", "in": {"board_tree_fern": 3, "cordage": 2}, "steps": 5, "from": "floor",
		"stand": Vector3(0, 0, 0.6), "face": Vector3(0, 1.1, -2.4)},
	{"id": "wall_left", "verb": "Put up the left wall", "in": {"board_tree_fern": 3, "cordage": 1}, "steps": 4, "from": "floor",
		"stand": Vector3(1.0, 0, -0.7), "face": Vector3(-1.7, 1.1, -0.7)},
	{"id": "wall_right", "verb": "Put up the right wall", "in": {"board_tree_fern": 3, "cordage": 1}, "steps": 4, "from": "floor",
		"stand": Vector3(-1.0, 0, -0.7), "face": Vector3(1.7, 1.1, -0.7)},
	{"id": "wall_front", "verb": "Put up the front wall", "in": {"board_tree_fern": 3, "cordage": 2}, "steps": 5, "from": "floor",
		"stand": Vector3(0, 0, -1.9), "face": Vector3(0, 1.1, 1.0)},
	{"id": "fireplace", "verb": "Build the fireplace", "in": {"stone": 8, "clay": 6}, "steps": 14, "from": "floor",
		"stand": Vector3(-0.3, 0, -0.2), "face": Vector3(0.95, 0.6, -1.7)},
	{"id": "ceiling", "verb": "Lay the ceiling", "in": {"board_calamites": 8, "cordage": 4}, "steps": 12, "from": "floor",
		"stand": Vector3(0, 0, 0.4), "face": Vector3(0, 2.2, -0.8)},
	{"id": "roof_left", "verb": "Roof the left side", "in": {"board_tree_fern": 4, "cordage": 4}, "steps": 8, "from": "ground",
		"stand": Vector3(-5.2, 0, 0.3), "face": Vector3(-1.0, 2.7, 0)},
	{"id": "roof_right", "verb": "Roof the right side", "in": {"board_tree_fern": 4, "cordage": 4}, "steps": 8, "from": "ground",
		"stand": Vector3(5.2, 0, 0.3), "face": Vector3(1.0, 2.7, 0)},
]

var world: Node = null
var preview := false         # the plan shown while holding a blueprint: all outline, nothing solid
var built := {}              # part id -> {item id: n} it took (dropped back if torn down)
var working := ""            # the part being built right now, if any
var work_k := 0              # and how many of its steps are done
var fire: Node3D = null      # the fireplace's fire, once built

var _solid: MeshInstance3D
var _ghost: MeshInstance3D
var _body: StaticBody3D
var _outline: StaticBody3D
var _hits := 0
var _hit_t := -INF
var _ok := true
var _shown_at := Transform3D()
var _fire_save := {}         # the fireplace's saved state, put back once it is lit up in the world

static var _holo := {}


static func holo(ok := true) -> StandardMaterial3D:
	## The see-through glow of the outline: blue, or red where it can't go.
	if not _holo.has(ok):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.45, 0.85, 1.0, 0.26) if ok else Color(1.0, 0.35, 0.3, 0.3)
		_holo[ok] = m
	return _holo[ok]


static func ground_points(centre: Vector3, yaw: float) -> Array:
	## Where the ground matters to a house standing at `centre` facing `yaw`:
	## under each stilt, at the foot of the ladder, and under the middle.
	var out := []
	var basis := Basis(Vector3.UP, yaw)
	for p in STILTS + [LADDER + Vector3(0, 0, 0.3), Vector3(0, 0, -0.7), Vector3(0, 0, 1.7)]:
		out.append(centre + basis * Vector3(p.x, 0, p.z))
	return out


func _ready() -> void:
	_solid = MeshInstance3D.new()
	add_child(_solid)
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.material_override = holo(true)
	add_child(_ghost)
	if preview:
		_rebuild()
		return
	add_to_group("houses")
	Game.houses.append(self)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta("hard", true)
	add_child(_body)
	_outline = StaticBody3D.new()
	_outline.collision_layer = 2
	_outline.collision_mask = 0
	add_child(_outline)
	if built.has("fireplace"):
		_make_fire()
	_rebuild()


func _exit_tree() -> void:
	Game.houses.erase(self)


# --- State -----------------------------------------------------------------------------

func complete() -> bool:
	return built.size() >= PARTS.size()


func next_part() -> Dictionary:
	## The next part to build, or {} once the house is finished.
	for p in PARTS:
		if not built.has(p.id):
			return p
	return {}


func part(id: String) -> Dictionary:
	for p in PARTS:
		if p.id == id:
			return p
	return {}


func wants_log() -> bool:
	return next_part().get("log", false)


func set_working(id: String, k: int) -> void:
	## Shows `id` k steps along (as you build it), or nothing in progress for "".
	working = id
	work_k = k
	_rebuild()


func finish_part(id: String, used: Dictionary) -> void:
	built[id] = used.duplicate()
	working = ""
	work_k = 0
	if id == "fireplace":
		_make_fire()
	_rebuild()
	if complete():
		Game.crafted.emit("house_built")
		Game.notify("Your softwood house is finished. Nothing will come for you inside it or out on the porch.")
	else:
		Game.notify("Done: %s. Next: %s." % [part(id).verb.to_lower(), next_part().verb.to_lower()])


func build_to(n: int) -> void:
	## Puts up the first n parts at once, as if built (dev worlds and tests).
	for i in mini(n, PARTS.size()):
		var p: Dictionary = PARTS[i]
		var used: Dictionary = p.in.duplicate()
		if p.get("log", false):
			used["log"] = 1
		built[p.id] = used
	if built.has("fireplace") and is_inside_tree():
		_make_fire()
	if is_inside_tree():
		_rebuild()


func _make_fire() -> void:
	if fire:
		return
	fire = Campfire.new()
	fire.hearth = true
	fire.fuel = 0.0
	fire.position = HEARTH
	add_child(fire)
	if not _fire_save.is_empty():
		fire.from_dict(_fire_save)
		_fire_save = {}


# --- Building (see work_spot.gd) --------------------------------------------------------

func recipe_for(p: Dictionary) -> Dictionary:
	## The next part as a work spot recipe.
	return {"house": p.id, "out": "", "n": 0, "in": p.in, "tools": p.get("tools", {}), "log": p.get("log", false),
		"from": p.from, "act": "steps", "steps": p.steps, "verb": p.verb,
		"label": "Part %d of %d of the house" % [PARTS.find(p) + 1, PARTS.size()], "how": _how(p.id)}


func options(log_id: String, player: Node3D) -> Array:
	## What can be built here now: [{recipe, missing}] for the next part.
	var p := next_part()
	if p.is_empty():
		return []
	var r := recipe_for(p)
	return [{"recipe": r, "missing": missing_for(r, log_id, player)}]


func missing_for(r: Dictionary, log_id: String, player: Node3D) -> Array:
	## What is still needed to build a part: the materials in your bag, the
	## stilt log carried in your arms, and being up in the house for the
	## parts built from its floor.
	var missing := []
	if r.get("log", false) and log_id == "":
		missing.append("a Calamites log, carried here in your arms")
	for id in r.in:
		var have: int = Game.inventory.count(id)
		if have < r.in[id]:
			missing.append("%d %s" % [r.in[id] - have, Items.item_name(id)])
	for id in r.get("tools", {}):
		if Game.inventory.count(id) < r.tools[id]:
			missing.append("a %s to pound it in with" % Items.item_name(id))
	if r.get("from", "") == "floor" and player and not on_floor(player.global_position):
		missing.append("to be up in the house (climb the ladder)")
	return missing


func _how(id: String) -> String:
	if id.begins_with("stilt"):
		return "Carry a Calamites log here in your arms and press E. Click to stand it in its hole, then pound it into the ground with a river stone from your bag."
	match id:
		"floor":
			return "Click to lay six tree fern boards across the bearers on the stilts, then tie them down with cordage."
		"porch":
			return "Click to lay four tree fern boards out in front of the room, then tie them down with cordage."
		"ladder":
			return "Click to tie two ropes to the edge of the porch, tie six sticks across them for rungs and knot them off. Then climb it: walk into it, look up and go forward (back, or forward looking down, climbs down)."
		"wall_back", "wall_left", "wall_right", "wall_front":
			var extra: String = {"wall_back": "", "wall_left": " A window is left open in it.", "wall_right": " A window is left open in it.",
				"wall_front": " The doorway is left open."}[id]
			return "From up in the house, click to fix rows of tree fern boards up the wall, then lash the corners with cordage." + extra
		"fireplace":
			return "Click to set eight river stones in a ring in the back corner, then daub them with wet clay and build a clay chimney up through the roof. It works like a campfire."
		"ceiling":
			return "Click to lay eight Calamites boards across the tops of the walls, then tie them on with cordage."
		"roof_left", "roof_right":
			return "Click to lay tree fern boards from the eave up to the ridge, then lash them along the ridge with cordage. The roof reaches out over the porch."
	return ""


func step_how(id: String, k: int) -> String:
	## What step k of a part does.
	if id.begins_with("stilt"):
		return "Stand the log up in its hole." if k == 0 else "Pound it in with the river stone (%d of 4)." % k
	match id:
		"floor", "porch":
			var nb: int = part(id).in.board_tree_fern
			return "Lay a board across the bearers (%d of %d)." % [k + 1, nb] if k < nb else "Tie the boards down with cordage."
		"ladder":
			if k < 2:
				return "Tie a rope to the edge of the porch."
			if k < 8:
				return "Tie on a stick for a rung (%d of 6)." % (k - 1)
			return "Knot the ropes off."
		"wall_back", "wall_left", "wall_right", "wall_front":
			return "Fix a row of boards up the wall (%d of 3)." % (k + 1) if k < 3 else "Lash the corner with cordage."
		"fireplace":
			if k < 8:
				return "Set a river stone in the hearth ring (%d of 8)." % (k + 1)
			return "Daub the hearth with wet clay." if k < 10 else "Build up the clay chimney (%d of 4)." % (k - 9)
		"ceiling":
			return "Lay a Calamites board across the walls (%d of 8)." % (k + 1) if k < 8 else "Tie the ceiling boards to the walls."
		"roof_left", "roof_right":
			return "Lay boards from the eave to the ridge (%d of 4)." % (k + 1) if k < 4 else "Lash the boards along the ridge."
	return ""


func step_sound(id: String, k: int) -> Array:
	## [sound, volume] for step k of a part.
	if id.begins_with("stilt"):
		return ["step", -4.0] if k == 0 else ["hit", -2.0]
	match id:
		"fireplace":
			return ["hit", -8.0] if k < 8 else ["step", -4.0]
		"ladder":
			return ["rustle", -8.0] if k < 2 or k >= 8 else ["pickup", -6.0]
	var nb: int = part(id).in.get("board_tree_fern", part(id).in.get("board_calamites", 0))
	return ["hit", -10.0] if k < nb else ["rustle", -8.0]


func stand_point(p: Dictionary, player: Node3D) -> Vector3:
	## Where you stand to build a part (global), or INF to stay where you are.
	var local := Vector3.INF
	if p.id.begins_with("stilt"):
		var s: Vector3 = STILTS[int(p.id.substr(6))]
		local = s + Vector3(signf(s.x), 0, signf(s.z)) * 1.1
	elif p.has("stand"):
		local = p.stand
	if not local.is_finite():
		return Vector3.INF
	match p.from:
		"floor":
			return to_global(local) if on_floor(player.global_position) else Vector3.INF
		"ground":
			if on_floor(player.global_position):
				return Vector3.INF
			var g := to_global(local)
			g.y = _ground(g)
			return g
	return Vector3.INF


func face_point(p: Dictionary) -> Vector3:
	## What you look at while building a part (global).
	if p.id.begins_with("stilt"):
		return to_global(STILTS[int(p.id.substr(6))] + Vector3(0, -0.6, 0))
	return to_global(p.get("face", Vector3.ZERO))


func eye_height(id: String, player: Node3D) -> float:
	## Laying the floor and the porch from the ground you look down on them,
	## as if stood up on the bearers.
	if id in ["floor", "porch"] and player:
		return clampf(global_position.y - player.global_position.y + 0.8, 1.62, 3.2)
	return 1.62


func marker(id: String, k: int) -> Vector3:
	## Where the glowing mark for step k of a part is (global).
	if id.begins_with("stilt"):
		var s: Vector3 = STILTS[int(id.substr(6))]
		if k == 0:
			return to_global(Vector3(s.x, _ground_local(s) + 1.1, s.z))
		return to_global(Vector3(s.x, _lift(k) + 0.05, s.z))
	for p in _pieces(id, k):
		if p.s == k:
			return to_global(p.get("m", _centre(p)))
	return to_global(part(id).get("face", Vector3.ZERO))


# --- Where things stand -------------------------------------------------------------------

func floor_top(p: Vector3) -> float:
	## The height of the floor (or porch) at p, if it is built there and p is
	## up at it rather than on the ground underneath; -INF otherwise.
	if preview:
		return -INF
	var l := to_local(p)
	if absf(l.x) > HALF_W + 0.02 or l.y < -0.8 or l.y > WALL_H + 1.0:
		return -INF
	if l.z >= BACK - 0.02 and l.z <= DOOR_Z and built.has("floor"):
		return global_position.y
	if l.z > DOOR_Z and l.z <= EDGE + 0.02 and built.has("porch"):
		return global_position.y
	return -INF


func on_floor(p: Vector3) -> bool:
	return floor_top(p) > -INF and absf(p.y - global_position.y) < 0.5


func shelters(p: Vector3) -> bool:
	## Whether p is inside the finished house or out on its porch.
	if preview or not complete():
		return false
	var l := to_local(p)
	return absf(l.x) <= HALF_W + 0.1 and l.z >= BACK - 0.1 and l.z <= EDGE + 0.1 and l.y > -0.5 and l.y < RIDGE


func room_spot(p: Vector3, inset := 0.0) -> bool:
	## Whether p is on the floor inside the finished house's room (not the
	## porch), at least `inset` from its walls.
	if preview or not complete() or not on_floor(p):
		return false
	var l := to_local(p)
	return absf(l.x) <= HALF_W - T - inset and l.z >= BACK + T + inset and l.z <= DOOR_Z - T - inset


func covers(p: Vector3, margin := 0.0) -> bool:
	## Whether p (at any height) is within the house's footprint.
	var l := to_local(p)
	return absf(l.x) <= EAVE.x + margin and l.z >= ROOF_Z.x - margin and l.z <= EDGE + 0.8 + margin


func ladder_at(p: Vector3) -> bool:
	## Whether p (your feet) is on the rope ladder.
	if preview or not built.has("ladder"):
		return false
	var l := to_local(p)
	return absf(l.x) < 0.55 and l.z > EDGE - 0.15 and l.z < EDGE + 0.8 and l.y > _ground_local(LADDER) - 0.4 and l.y < 0.95


func _ground(g: Vector3) -> float:
	var h: float = world.ground_height(g.x, g.z) if world else -INF
	return h if h > -INF else global_position.y - FLOOR_H


func _ground_local(at: Vector3) -> float:
	## The height of the ground under a local point, from the floor.
	return _ground(to_global(Vector3(at.x, 0, at.z))) - global_position.y


func _lift(k: int) -> float:
	## How far a stilt still sticks up past where it ends after k steps.
	return [0.0, 0.6, 0.45, 0.3, 0.15, 0.0][clampi(k, 0, 5)]


# --- The plan shown while holding a blueprint -------------------------------------------

func show_plan(at: Vector3, yaw: float, ok: bool) -> void:
	## Moves the plan to `at` facing `yaw`. Its stilts are fitted to the
	## ground again once it has moved far enough to matter.
	var t := Transform3D(Basis(Vector3.UP, yaw), at)
	global_transform = t
	if t.origin.distance_to(_shown_at.origin) > 0.25 or absf(angle_difference(yaw, _shown_at.basis.get_euler().y)) > 0.08:
		_shown_at = t
		_rebuild()
	if ok != _ok:
		_ok = ok
		_ghost.material_override = holo(ok)


# --- Interaction ----------------------------------------------------------------------------

func prompt(player: Node) -> String:
	if preview or complete():
		return ""
	var p := next_part()
	var tags: Array = Items.def(Game.inventory.held_id()).get("tags", [])
	var tear := "   (hit it %d times with an axe or mattock to tear it down)" % TEARDOWN_HITS if "chop" in tags or "dig" in tags else ""
	if player and player.hauling:
		return ""
	return "House site: %s [E]   %d of %d parts built%s" % [p.verb.to_lower(), built.size(), PARTS.size(), tear]


func interact(player: Node) -> void:
	if preview or complete() or world == null or not world.has_method("start_house_work"):
		return
	world.start_house_work(self)


func axe_hit() -> void:
	_hit()


func break_apart() -> void:
	_hit()


func _hit() -> void:
	## Blows from an axe or a mattock tear an unfinished house down.
	if preview or complete():
		return
	if Game.time - _hit_t > HIT_WINDOW:
		_hits = 0
	_hit_t = Game.time
	_hits += 1
	Sfx.play_at("chop", global_position, -4.0, 0.2)
	if _hits < TEARDOWN_HITS:
		var left := TEARDOWN_HITS - _hits
		Game.notify("You hack at the house site. %d more blow%s to tear it down." % [left, "" if left == 1 else "s"])
		return
	tear_down()


func tear_down() -> void:
	## Gives up on the house: what was built comes down and is left on the
	## ground as the materials it took (stilts as logs), and what stood on its
	## floor falls to the ground. The blueprint is lost.
	Game.houses.erase(self)
	var got := {}
	var spots := 0
	for id in built:
		var used: Dictionary = built[id]
		for item in used:
			var n: int = used[item]
			got[item] = got.get(item, 0) + n
			if world == null:
				continue
			if Items.def(item).get("carry", false):
				var s: Vector3 = STILTS[int(id.substr(6))] if id.begins_with("stilt") else Vector3.ZERO
				var at := to_global(Vector3(s.x * 1.5, 0, s.z + 0.6))
				at.y = _ground(at)
				for k in n:
					world.add_log(item, at + global_basis.x * k * 0.5, rotation.y, "calamites")
	if world and world.has_method("pile_item"):
		for item in got:
			if Items.def(item).get("carry", false):
				continue
			var at := to_global(Vector3(-2.0 + (spots % 5) * 1.0, 0, EDGE + 1.6 + (spots / 5) * 1.0))
			at.y = _ground(at) + 0.3
			world.pile_item(item, got[item], at)
			spots += 1
	if fire:
		_spill_fire()
	_drop_what_stands_here()
	var list := []
	for item in got:
		list.append("%s x%d" % [Items.item_name(item), got[item]])
	Sfx.play_at("hit", global_position, -2.0)
	Game.notify("You tear the house site down." + (" Left on the ground: " + ", ".join(list) + "." if not list.is_empty() else ""))
	queue_free()


func _spill_fire() -> void:
	## Whatever was cooking in the fireplace, and its ash, end up on the ground.
	if world == null or not world.has_method("spawn_pickup"):
		return
	var at := to_global(HEARTH)
	at.y = _ground(at) + 0.2
	for i in Campfire.SPOTS:
		var id: String = fire.result(i)
		if id != "":
			world.spawn_pickup(id, 1, at)
	if fire.ash() > 0:
		world.spawn_pickup("ash", fire.ash(), at)


func _drop_what_stands_here() -> void:
	## Sacks, piles, benches and loose things up on the floor fall to the ground.
	for b in get_tree().get_nodes_in_group("bedrolls"):
		# A bedroll only lies in a house: it comes down as the item.
		if b.is_queued_for_deletion() or not covers(b.global_position):
			continue
		var at: Vector3 = b.global_position
		at.y = _ground(at) + 0.2
		spawn_pickup("bedroll", 1, at)
		b.queue_free()
	for g in ["stashes", "stacks", "drops", "workbenches"]:
		for n in get_tree().get_nodes_in_group(g):
			if not (n is Node3D) or n.is_queued_for_deletion():
				continue
			var p: Vector3 = n.global_position
			var l := to_local(p)
			if absf(l.x) <= HALF_W + 0.1 and l.z >= BACK - 0.1 and l.z <= EDGE + 0.1 and l.y > -0.6:
				n.global_position.y = _ground(p) - (0.05 if g == "stashes" else 0.0)


func spawn_pickup(id: String, n: int, pos: Vector3, age := 0.0, keep := true, data := {}) -> void:
	## For the fireplace: what it gives back lands in the world.
	if world and world.has_method("spawn_pickup"):
		world.spawn_pickup(id, n, pos, age, keep, data)


# --- Looks and collision ------------------------------------------------------------------

func _rebuild() -> void:
	var sb := MeshBuilder.new()
	var gb := MeshBuilder.new()
	var done := complete()
	for p in PARTS:
		var k: int = p.steps if built.has(p.id) else (work_k if p.id == working else 0)
		for piece in _pieces(p.id, k):
			if piece.s < k:
				_draw(sb, piece)
			elif not done:
				_draw(gb, piece)
	_solid.mesh = sb.commit(Assets.materials) if not sb.is_empty() else null
	_ghost.mesh = gb.commit(Assets.materials) if not gb.is_empty() else null
	if preview:
		return
	_rebuild_collision()


func _rebuild_collision() -> void:
	for c in _body.get_children():
		c.queue_free()
	for p in PARTS:
		if built.has(p.id):
			for s in _shapes(p.id):
				_body.add_child(s)
	for c in _outline.get_children():
		c.queue_free()
	if complete():
		return
	# Something to look at and press E on: the house from the floor up, and
	# where each stilt goes. Low down it leaves the ground clear, so what lies
	# about under the site can still be picked up.
	_outline.add_child(_box_shape(Vector3(EAVE.x * 2.0, RIDGE + 0.1, EDGE - ROOF_Z.x + 0.6), Vector3(0, RIDGE * 0.5, (ROOF_Z.x + EDGE + 0.6) * 0.5)))
	for s in STILTS:
		var g := _ground_local(s)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = -g + 0.1
		cs.shape = cyl
		cs.position = Vector3(s.x, g * 0.5, s.z)
		_outline.add_child(cs)


func _box_shape(size: Vector3, centre: Vector3, basis := Basis()) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(basis, centre)
	return cs


func _shapes(id: String) -> Array:
	## The solid shapes of a built part.
	if id.begins_with("stilt"):
		var s: Vector3 = STILTS[int(id.substr(6))]
		var g := _ground_local(s)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = STILT_R
		cyl.height = -g + SINK
		cs.shape = cyl
		cs.position = Vector3(s.x, (g - SINK) * 0.5, s.z)
		return [cs]
	var w := HALF_W * 2.0
	match id:
		"floor":
			return [_box_shape(Vector3(w, 0.12, DOOR_Z - BACK), Vector3(0, -0.06, (BACK + DOOR_Z) * 0.5))]
		"porch":
			return [_box_shape(Vector3(w, 0.12, EDGE - DOOR_Z), Vector3(0, -0.06, (DOOR_Z + EDGE) * 0.5))]
		"wall_back":
			return [_box_shape(Vector3(w, WALL_H, T), Vector3(0, WALL_H * 0.5, BACK + T * 0.5))]
		"wall_left", "wall_right":
			var x := (HALF_W - T * 0.5) * (-1.0 if id == "wall_left" else 1.0)
			var z0 := BACK + T
			var wz := WINDOW_Z.y - WINDOW_Z.x
			return [
				_box_shape(Vector3(T, WALL_H, WINDOW_Z.x - z0), Vector3(x, WALL_H * 0.5, (z0 + WINDOW_Z.x) * 0.5)),
				_box_shape(Vector3(T, WALL_H, DOOR_Z - WINDOW_Z.y), Vector3(x, WALL_H * 0.5, (WINDOW_Z.y + DOOR_Z) * 0.5)),
				_box_shape(Vector3(T, WINDOW_Y.x, wz), Vector3(x, WINDOW_Y.x * 0.5, (WINDOW_Z.x + WINDOW_Z.y) * 0.5)),
				_box_shape(Vector3(T, WALL_H - WINDOW_Y.y, wz), Vector3(x, (WINDOW_Y.y + WALL_H) * 0.5, (WINDOW_Z.x + WINDOW_Z.y) * 0.5)),
			]
		"wall_front":
			var z := DOOR_Z - T * 0.5
			var side := HALF_W - T - DOOR.x
			return [
				_box_shape(Vector3(side, WALL_H, T), Vector3(-(DOOR.x + side * 0.5), WALL_H * 0.5, z)),
				_box_shape(Vector3(side, WALL_H, T), Vector3(DOOR.x + side * 0.5, WALL_H * 0.5, z)),
				_box_shape(Vector3(DOOR.x * 2.0, WALL_H - DOOR.y, T), Vector3(0, (DOOR.y + WALL_H) * 0.5, z)),
			]
		"ceiling":
			return [_box_shape(Vector3(w, 0.06, DOOR_Z - BACK), Vector3(0, WALL_H + 0.03, (BACK + DOOR_Z) * 0.5))]
		"roof_left", "roof_right":
			var r := _roof(-1.0 if id == "roof_left" else 1.0)
			return [_box_shape(Vector3(r.len + 0.1, 0.06, ROOF_Z.y - ROOF_Z.x), r.mid + r.normal * 0.03, r.basis)]
	return []


func _roof(side: float) -> Dictionary:
	## One side of the roof: from its eave up to the ridge.
	var eave := Vector3(side * EAVE.x, EAVE.y, 0)
	var ridge := Vector3(0, RIDGE, 0)
	var d := ridge - eave
	var basis := Basis(Vector3.BACK, atan2(d.y, d.x))
	var normal := basis.y if basis.y.y > 0.0 else -basis.y
	return {"mid": (eave + ridge) * 0.5, "len": d.length(), "basis": basis, "normal": normal}


# A part is drawn as pieces, each put in place by one of its steps (`s`): a
# box, a cylinder or a lumpy blob, with `m` where its glowing mark goes if
# not at its centre.

func _box(s: int, c: Vector3, size: Vector3, col: Color, slot := "wood", basis := Basis()) -> Dictionary:
	return {"s": s, "t": "box", "c": c, "size": size, "col": col, "slot": slot, "basis": basis}


func _cyl(s: int, a: Vector3, b: Vector3, r: float, col: Color, slot := "wood", r1 := -1.0, sides := 8, caps := true, twist := 0.0) -> Dictionary:
	return {"s": s, "t": "cyl", "a": a, "b": b, "r": r, "r1": r if r1 < 0.0 else r1, "col": col, "slot": slot, "sides": sides, "caps": caps, "twist": twist}


func _blob(s: int, c: Vector3, size: Vector3, col: Color, slot := "stone") -> Dictionary:
	return {"s": s, "t": "blob", "c": c, "size": size, "col": col, "slot": slot}


func _lash(s: int, c: Vector3, axis: Vector3, r: float) -> Array:
	## A few turns of cord wound round something at c, along `axis`.
	var out := []
	for i in 3:
		var o := axis * (i - 1) * 0.035
		out.append(_cyl(s, c + o - axis * 0.01, c + o + axis * 0.01, r, Assets.CORD * (0.92 + 0.06 * i), "fiber", -1.0, 8, false))
	out[1].m = c
	return out


func _centre(p: Dictionary) -> Vector3:
	match p.t:
		"box":
			return p.c + p.basis.y * p.size.y * 0.5
		"cyl":
			return (p.a + p.b) * 0.5
	return p.c


func _draw(b, p: Dictionary) -> void:
	match p.t:
		"box":
			b.box(p.c, p.size, p.col, p.basis, p.slot)
		"cyl":
			b.cylinder(p.a, p.b, p.r, p.r1, p.sides, p.col, Color(-1, 0, 0), p.slot, p.caps, p.twist)
		"blob":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(p.c)
			b.blob(p.c, p.size, 2, 6, p.col, rng, 0.2, p.slot)


func _shade(i: int) -> float:
	return 0.9 + 0.1 * sin(i * 1.7)


func _pieces(id: String, k: int) -> Array:
	## The pieces of a part, as shown k steps along.
	var out := []
	var fern: Color = Items.def("board_tree_fern").color
	var cal: Color = Items.def("board_calamites").color
	if id.begins_with("stilt"):
		var s: Vector3 = STILTS[int(id.substr(6))]
		var g := _ground_local(s)
		var lift := _lift(k)
		var look: Dictionary = Assets.LOG_LOOKS["calamites"]
		var used: Dictionary = built.get(id, {})
		var col: Color = look.wood if used.has("log_stripped") else look.bark
		var bottom := Vector3(s.x, g - SINK + lift, s.z)
		var top := Vector3(s.x, lift, s.z)
		out.append(_cyl(0, bottom, top, STILT_R, col, "bark_calamites" if not used.has("log_stripped") else "wood", STILT_R * 0.95, 10))
		# The joints of a horsetail stem, every half metre or so.
		var y := bottom.y + 0.45
		while y < top.y - 0.1:
			out.append(_cyl(0, Vector3(s.x, y - 0.02, s.z), Vector3(s.x, y + 0.02, s.z), STILT_R + 0.012, col * 0.8, "wood", -1.0, 10, false))
			y += 0.48
		out.append(_cyl(0, top, top + Vector3(0, 0.002, 0), STILT_R * 0.95, Assets.CUT_WOOD, "wood", -1.0, 10))
		return out
	match id:
		"floor", "porch":
			var z0 := BACK if id == "floor" else DOOR_Z
			var z1 := DOOR_Z if id == "floor" else EDGE
			var n := 12 if id == "floor" else 5
			var nb: int = part(id).in.board_tree_fern
			if id == "floor":
				# The bearers the boards rest on, from stilt to stilt.
				for sx in [-1.0, 1.0]:
					out.append(_box(0, Vector3(sx * 1.55, -0.13, 0), Vector3(0.14, 0.13, EDGE * 2.0 + 0.1), fern * 0.8))
			var depth := (z1 - z0) / n
			for j in n:
				out.append(_box(j * nb / n, Vector3(0, -0.03, z0 + (j + 0.5) * depth), Vector3(HALF_W * 2.0, 0.06, depth - 0.012), fern * _shade(j)))
			var ties := [Vector3(-1.55, -0.05, -1.9), Vector3(1.55, -0.05, -0.7), Vector3(-1.55, -0.05, 0.5)] if id == "floor" \
					else [Vector3(1.55, -0.05, 1.3), Vector3(-1.55, -0.05, 1.9), Vector3(1.55, -0.05, 2.3)]
			for c in ties.size():
				out.append_array(_lash(nb + c, ties[c], Vector3.BACK, 0.11))
		"ladder":
			var g := _ground_local(LADDER)
			var top_z := EDGE + 0.03
			var foot := Vector3(0, g + 0.05, EDGE + 0.14)
			for i in 2:
				var x := LADDER_W * (-1.0 if i == 0 else 1.0)
				out.append(_cyl(i, Vector3(x, 0.0, top_z), Vector3(x, foot.y, foot.z), 0.012, Assets.CORD, "fiber", -1.0, 5))
			var stick: Color = Items.def("stick").color
			for j in 6:
				var y := lerpf(-0.3, g + 0.3, j / 5.0)
				var z := lerpf(top_z, foot.z, y / foot.y)
				out.append(_cyl(2 + j, Vector3(-LADDER_W - 0.05, y, z), Vector3(LADDER_W + 0.05, y, z), 0.018, stick * _shade(j)))
			for i in 2:
				var x := LADDER_W * (-1.0 if i == 0 else 1.0)
				out.append_array(_lash(8 + i, Vector3(x, -0.03, EDGE - 0.02), Vector3.RIGHT, 0.05))
		"wall_back", "wall_left", "wall_right", "wall_front":
			_wall(out, id, fern)
		"fireplace":
			var stone: Color = Items.def("stone").color
			var clay: Color = Items.def("clay").color
			for j in 8:
				var a := deg_to_rad(140.0 + j * 260.0 / 7.0)
				out.append(_blob(j, HEARTH + Vector3(cos(a) * 0.5, 0.08, sin(a) * 0.5), Vector3(0.13, 0.1, 0.12), stone * (0.9 + 0.08 * (j % 3))))
			out.append(_cyl(8, HEARTH + Vector3(0, 0.0, 0), HEARTH + Vector3(0, 0.025, 0), 0.68, clay * 0.85, "clay", -1.0, 12))
			for j in 7:
				var a := deg_to_rad(140.0 + (j + 0.5) * 260.0 / 7.0)
				out.append(_blob(9, HEARTH + Vector3(cos(a) * 0.52, 0.06, sin(a) * 0.52), Vector3(0.08, 0.06, 0.07), clay * 0.8, "clay"))
			# A hood over the fire, narrowing into a flue up through the roof.
			var c := HEARTH + Vector3(0, 0, -0.12)
			var flue := [[1.05, 1.45, 0.55, 0.38], [1.45, 1.85, 0.38, 0.2], [1.85, 2.6, 0.2, 0.2], [2.6, 3.25, 0.2, 0.18]]
			for j in 4:
				var f: Array = flue[j]
				out.append(_cyl(10 + j, c + Vector3(0, f[0], 0), c + Vector3(0, f[1], 0), f[2], clay * (0.78 - 0.03 * j), "clay", f[3], 4, true, PI * 0.25))
		"ceiling":
			var n := 8
			var depth := (DOOR_Z - BACK) / n
			for j in n:
				out.append(_box(j, Vector3(0, WALL_H + 0.025, BACK + (j + 0.5) * depth), Vector3(HALF_W * 2.0, 0.05, depth - 0.01), cal * _shade(j)))
			var ties := [Vector3(-1.62, WALL_H, BACK + 0.12), Vector3(1.62, WALL_H, BACK + 0.12), Vector3(-1.62, WALL_H, DOOR_Z - 0.12), Vector3(1.62, WALL_H, DOOR_Z - 0.12)]
			for c in 4:
				out.append_array(_lash(8 + c, ties[c], Vector3.BACK, 0.06))
		"roof_left", "roof_right":
			var side := -1.0 if id == "roof_left" else 1.0
			var r := _roof(side)
			if id == "roof_left":
				out.append(_cyl(0, Vector3(0, RIDGE + 0.02, ROOF_Z.x - 0.15), Vector3(0, RIDGE + 0.02, ROOF_Z.y + 0.15), 0.07, Assets.LOG_LOOKS["calamites"].bark, "wood"))
			var n := 14
			var w := (ROOF_Z.y - ROOF_Z.x) / n
			for j in n:
				var z := ROOF_Z.x + (j + 0.5) * w
				out.append(_box(j * 4 / n, r.mid + r.normal * 0.03 + Vector3(0, 0, z), Vector3(r.len + 0.1, 0.05, w - 0.015), fern * _shade(j + 3), "wood", r.basis))
			for c in 4:
				var z := lerpf(ROOF_Z.x + 0.5, ROOF_Z.y - 0.5, c / 3.0) + side * 0.2
				out.append_array(_lash(4 + c, Vector3(side * 0.12, RIDGE - 0.02, z), Vector3.BACK, 0.09))
	return out


func _wall(out: Array, id: String, col: Color) -> void:
	## Rows of boards up a wall, three steps' worth, with the window or the
	## doorway left open, then cord lashed round its corners.
	var along_x := id in ["wall_back", "wall_front"]
	var at: float          # the wall's x (side walls) or z
	var span: Vector2      # from where to where it runs along
	var gap := Vector2.ZERO
	var gap_rows := Vector2i(-1, -1)
	match id:
		"wall_back":
			at = BACK + T * 0.5
			span = Vector2(-HALF_W, HALF_W)
		"wall_front":
			at = DOOR_Z - T * 0.5
			span = Vector2(-HALF_W + T, HALF_W - T)
			gap = Vector2(-DOOR.x, DOOR.x)
			gap_rows = Vector2i(0, 6)
		"wall_left", "wall_right":
			at = (HALF_W - T * 0.5) * (-1.0 if id == "wall_left" else 1.0)
			span = Vector2(BACK + T, DOOR_Z)
			gap = WINDOW_Z
			gap_rows = Vector2i(4, 5)
	var row_h := WALL_H / ROWS
	for r in ROWS:
		var segs := [span]
		if r >= gap_rows.x and r <= gap_rows.y:
			segs = [Vector2(span.x, gap.x), Vector2(gap.y, span.y)]
		for sg: Vector2 in segs:
			var mid := (sg.x + sg.y) * 0.5
			var len := sg.y - sg.x
			var c := Vector3(mid, (r + 0.5) * row_h, at) if along_x else Vector3(at, (r + 0.5) * row_h, mid)
			var size := Vector3(len, row_h - 0.012, T) if along_x else Vector3(T, row_h - 0.012, len)
			out.append(_box(r * 3 / ROWS, c, size, col * _shade(r + (2 if along_x else 0))))
	var corners := []
	match id:
		"wall_back":
			corners = [Vector3(-HALF_W + 0.04, 1.1, BACK + 0.04), Vector3(HALF_W - 0.04, 1.1, BACK + 0.04)]
		"wall_left":
			corners = [Vector3(-HALF_W + 0.04, 1.1, DOOR_Z - 0.04)]
		"wall_right":
			corners = [Vector3(HALF_W - 0.04, 1.1, DOOR_Z - 0.04)]
		"wall_front":
			corners = [Vector3(-DOOR.x, 1.1, DOOR_Z - 0.04), Vector3(DOOR.x, 1.1, DOOR_Z - 0.04)]
	for c in corners.size():
		out.append_array(_lash(3 + c, corners[c], Vector3.UP, 0.075))


# --- Saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "built": built.duplicate(true), "fire": fire.to_dict() if fire else {}}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	built = {}
	var src: Dictionary = d.get("built", {})
	for p in PARTS:
		if not src.has(p.id) or not (src[p.id] is Dictionary):
			break  # parts go up in order
		var used := {}
		for item in src[p.id]:
			if Items.exists(item):
				used[item] = int(src[p.id][item])
		built[p.id] = used
	_fire_save = d.get("fire", {})
	if is_inside_tree():
		if built.has("fireplace"):
			_make_fire()
		_rebuild()
