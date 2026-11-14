extends StaticBody3D
## A heavy stone carried in your arms like a log (player.start_haul): an
## anvil stone from the islands (group "anvils"), or a meteorite fallen from
## the sky (group "meteorites", metals.md).
##
## An anvil stone comes off its island a rough, lumpy boulder (`stage`
## ROUGH, station "boulder") and is shaped where it lies, kneeling at it (C,
## work_spot.gd):
##   ROUGH   peck the high spots off its face with a river stone, a 5x5 grid
##           of bumps (`peck`, their heights) knocked down a level a click;
##           no fail state, a strike on flat stone is only a wasted blow.
##           Pecked, it is lighter (Items.weight rather than ROUGH_KG).
##   PECKED  a rough anvil: smashing and crushing go quicker on it. Grind its
##           face smooth with stone grit, a pot of water and a river stone.
##   GROUND  a dressed anvil: castings, bars and iron are worked on it. Peck a
##           seat for a whetstone into one corner with a river stone.
##   SEATED  hold a whetstone and press E to seat it (E again takes it back),
##           to grind castings sharp and sharpen blunt metal tools.
## Without a whetstone in it, E picks it up to carry.
##
## A meteorite lies half buried in its crater until a mattock digs it out
## (`buried`). Then it can be carried home, or knelt at with a copper chisel
## and hammer to chip lumps of iron off it (station "meteorite"), which wears
## its `mass` down until it is gone.
##
## An island's anvil stones (`uid`) lie where they were made until one is
## first picked up: then it is in Game.taken and saved like anything else.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const ANVIL := Vector3(0.9, 0.42, 0.62)    # an anvil stone's size
enum { ROUGH, PECKED, GROUND, SEATED }
const ROUGH_KG := 42.0                      # a boulder before its face is pecked flat
const PECK_CELL := Vector2(0.15, 0.1)       # the face's 5x5 grid, x and z
const BUMP := 0.028                         # height of each level of a high spot
const SEAT := Vector3(ANVIL.x * 0.3, 0.0, ANVIL.z * 0.22)   # the whetstone's corner
const DIG_HITS := 3                         # mattock swings to dig a meteorite out

var item_id := "anvil_stone"
var uid := ""
var mass := 30.0
var whetstone := false
var stage := ROUGH
var peck: Array = []      # ROUGH: the face's 25 high spots, levels still to knock off
var buried := false
var hauled_by: Node3D = null
var world: Node = null

var _dug := 0
var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func setup(id: String, w: Node, kg := -1.0) -> Node3D:
	item_id = id
	world = w
	mass = kg if kg > 0.0 else (ROUGH_KG if id == "anvil_stone" else float(Items.weight(id)))
	return self


func _ready() -> void:
	add_to_group("anvils" if item_id == "anvil_stone" else "meteorites")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.visibility_range_end = 120.0
	add_child(_mesh)
	_rebuild()


func radius() -> float:
	## A meteorite's size, from its mass (iron is heavy: 8 kg is a fist and a half).
	return 0.12 * pow(maxf(mass, 0.5), 1.0 / 3.0)


func _rebuild() -> void:
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uid if uid != "" else str(get_instance_id()))
	var box := _shape.shape as BoxShape3D
	if item_id == "anvil_stone":
		b.blob(Vector3(0, ANVIL.y * 0.42, 0), Vector3(ANVIL.x, ANVIL.y * 0.9, ANVIL.z) * 0.5, 2, 6, Color(0.27, 0.27, 0.29), rng, 0.12, "stone")
		# The face: lumpy, then pecked flat (pitted), ground smooth, a seat cut in.
		var face: Color = [Color(0.29, 0.29, 0.31), Color(0.36, 0.36, 0.37), Color(0.41, 0.41, 0.42), Color(0.41, 0.41, 0.42)][stage]
		b.box(Vector3(0, ANVIL.y - 0.04, 0), Vector3(ANVIL.x * 0.82, 0.08, ANVIL.z * 0.78), face, Basis(), "stone")
		if stage == ROUGH:
			var lumps := heights()
			for k in 25:
				if lumps[k] > 0:
					var c := cell_local(k)
					b.blob(Vector3(c.x, ANVIL.y - 0.01 + lumps[k] * BUMP * 0.5, c.z), Vector3(PECK_CELL.x * 0.62, lumps[k] * BUMP * 0.75 + 0.012, PECK_CELL.y * 0.68),
							3, 7, Color(0.27, 0.27, 0.29).lightened(rng.randf_range(0.0, 0.06)), rng, 0.15, "stone")
		elif stage == PECKED:
			for i in 14:  # pock marks
				var at := Vector3(rng.randf_range(-0.33, 0.33), ANVIL.y + 0.001, rng.randf_range(-0.21, 0.21))
				b.box(at, Vector3(0.025, 0.002, 0.02), Color(0.30, 0.30, 0.31), Basis(Vector3.UP, rng.randf() * PI), "stone")
		if stage == SEATED:
			b.box(SEAT + Vector3(0, ANVIL.y + 0.001, 0), Vector3(0.23, 0.002, 0.11), Color(0.22, 0.22, 0.23), Basis(), "stone")
		if whetstone:
			b.box(SEAT + Vector3(0, ANVIL.y + 0.01, 0), Vector3(0.2, 0.04, 0.09), Color(0.66, 0.66, 0.62), Basis(), "stone")
		box.size = ANVIL
		_shape.position.y = ANVIL.y * 0.5
	else:
		var r := radius()
		var sink := r * 0.6 if buried else 0.0
		b.blob(Vector3(0, r * 0.8 - sink, 0), Vector3(r * 1.15, r * 0.8, r), 2, 6, Color(0.27, 0.21, 0.17), rng, 0.3, "stone")
		box.size = Vector3(r * 2.3, r * 1.6, r * 2.0)
		_shape.position.y = r * 0.8 - sink
	_mesh.mesh = b.commit(Assets.materials)


func station_kind() -> String:
	## What kneeling at it works at (work_spot.gd), or "" while it can't be.
	if hauled_by:
		return ""
	if item_id == "anvil_stone":
		return "boulder" if stage == ROUGH else "anvil"
	return "" if buried else "meteorite"


# --- Shaping an anvil stone -----------------------------------------------------------

func heights() -> Array:
	## The high spots still on a rough boulder's face: 25 levels, a dome with
	## a lumpy top, the same for an island's stone every time.
	if stage != ROUGH:
		peck = []
		peck.resize(25)
		peck.fill(0)
		return peck
	if peck.size() == 25:
		return peck
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uid + "_peck") if uid != "" else hash(str(get_instance_id()) + "_peck")
	peck = []
	for k in 25:
		var d := Vector2(k % 5 - 2, k / 5 - 2).length() / 2.83
		peck.append(clampi(roundi(1.1 * (1.0 - d) + rng.randf_range(-0.4, 1.2)), 0, 3))
	if not peck.has(1) and not peck.has(2) and not peck.has(3):
		peck[12] = 2
	return peck


func high_spots() -> int:
	## Strikes still needed to peck the face flat.
	var n := 0
	for h in heights():
		n += int(h)
	return n


func cell_local(k: int) -> Vector3:
	return Vector3((k % 5 - 2) * PECK_CELL.x, ANVIL.y, (k / 5 - 2) * PECK_CELL.y)


func cell_point(k: int) -> Vector3:
	## Where cell k of the face is, on top of whatever is left on it.
	return to_global(cell_local(k) + Vector3(0, heights()[k] * BUMP + 0.01, 0))


func strike_cell(k: int) -> bool:
	## A blow of the river stone on cell k: true when it knocked a level off.
	var h := heights()
	if k < 0 or k >= 25 or h[k] <= 0:
		return false
	h[k] = int(h[k]) - 1
	_rebuild()
	return true


func shape_mark(k: int, n: int) -> Vector3:
	## Where the k-th of n clicks goes while grinding the face (back and
	## forth across it) or pecking the seat (in its corner).
	if stage == GROUND:
		return to_global(SEAT + Vector3([-0.05, 0.05, 0.0][k % 3], ANVIL.y + 0.02, [0.02, -0.02, 0.0][k % 3]))
	var f := (k + 0.5) / maxf(n, 1.0)
	var row := k % 3
	return to_global(Vector3(lerpf(-0.3, 0.3, f) * (1.0 if row != 1 else -1.0), ANVIL.y + 0.02, (row - 1) * 0.15))


func advance() -> void:
	## The next stage of shaping done.
	if stage >= SEATED:
		return
	stage += 1
	if stage == PECKED:
		mass = float(Items.weight(item_id))
	_rebuild()


func stage_name() -> String:
	return ["rough anvil boulder", "rough anvil", "dressed anvil", "anvil"][stage]


func chip(kg: float) -> bool:
	## A lump knocked off a meteorite: true when that was the last of it.
	mass -= kg * 1.15  # a little more flies off as flakes
	if mass < 0.4:
		Game.notify("That was the last of the meteorite.")
		queue_free()
		return true
	_rebuild()
	return false


func dig() -> void:
	## A mattock swing round a buried meteorite: the last one frees it.
	if not buried:
		return
	_dug += 1
	Sfx.play_at("chop", global_position, -4.0, 0.2)
	if _dug < DIG_HITS:
		Game.notify("You dig round the meteorite (%d / %d)." % [_dug, DIG_HITS])
		return
	buried = false
	_rebuild()
	Game.notify("You dig the meteorite out: about %d kg of iron. Carry it home (E), or kneel at it (C) with a copper chisel and hammer to chip lumps off." % roundi(mass))


# --- Carrying (see player.start_haul) ---------------------------------------------

func can_haul() -> bool:
	return not buried and not (item_id == "anvil_stone" and whetstone)


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return "meteorite" if item_id == "meteorite" else ("anvil boulder" if stage == ROUGH else "anvil stone")


func haul_radius() -> float:
	return 0.45 if item_id == "anvil_stone" else radius()


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	return 0.75


func haul_prompt(_player: Node) -> String:
	return "Put down the %s [E]" % haul_name()


func haul_interact(_player: Node) -> bool:
	return false


func set_hauled(by: Node3D) -> void:
	hauled_by = by
	_shape.disabled = by != null
	if by != null and uid != "":
		Game.taken[uid] = true  # moved from where it lay on its island: saved from now on
	if by == null:
		var g: float = world.floor_height(global_position) if world and world.has_method("floor_height") else global_position.y
		if is_finite(g):
			global_position.y = g
		rotation = Vector3(0, rotation.y, 0)


# --- Interaction ---------------------------------------------------------------------

func prompt(_player: Node) -> String:
	if hauled_by:
		return ""
	if item_id == "meteorite":
		if buried:
			if "dig" in Items.def(Game.inventory.held_id()).get("tags", []):
				return "A meteorite, half buried: swing the mattock to dig it out"
			return "A meteorite, half buried in the crater (dig it out with a mattock)"
		return "Pick up the meteorite (%d kg) [E]   or kneel to chip it [C]" % roundi(mass)
	var held: String = Game.inventory.held_id()
	if whetstone:
		return "Anvil with a whetstone: kneel to work at it [C]   Take the whetstone [E]"
	if stage == ROUGH:
		return "A lumpy boulder (%d kg): kneel to peck its face flat [C]   Pick it up [E]" % roundi(mass)
	if held == "whetstone" and stage == SEATED:
		return "Seat the whetstone in the anvil [E]   or kneel to work at it [C]"
	var what: String = {PECKED: "Rough anvil (grind its face smooth)", GROUND: "Dressed anvil (peck a seat for a whetstone)"}.get(stage, "Anvil")
	return "%s: kneel to work at it [C]   Pick up the anvil stone [E]" % what


func interact(player: Node) -> void:
	if hauled_by or buried:
		return
	if item_id == "anvil_stone":
		if whetstone:
			if Game.inventory.add("whetstone", 1) == 0:
				whetstone = false
				_rebuild()
				Sfx.play("pickup", -6.0)
				Game.notify("You take the whetstone out of the anvil.")
			return
		if Game.inventory.held_id() == "whetstone" and stage < SEATED:
			Game.notify("There is no seat for a whetstone in it yet. Kneel at it (C): %s." % ["peck its face flat first", "grind its face smooth first", "peck a seat into its corner"][stage])
			return
		if Game.inventory.held_id() == "whetstone":
			Game.inventory.take(Game.inventory.selected, 1)
			whetstone = true
			_rebuild()
			Sfx.play("step", -6.0)
			Game.notify("You seat the whetstone in the anvil's corner. Kneel at it (C) to grind and sharpen.")
			return
	player.start_haul(self)


# --- Saving ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := global_position
	return {"id": item_id, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "mass": mass, "whetstone": whetstone, "buried": buried, "uid": uid, "stage": stage, "peck": peck.duplicate() if stage == ROUGH else []}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	mass = float(d.get("mass", mass))
	whetstone = bool(d.get("whetstone", false))
	buried = bool(d.get("buried", false))
	uid = String(d.get("uid", ""))
	# Saved before anvils had to be shaped: those were finished anvils.
	stage = clampi(int(d.get("stage", SEATED if d.has("pos") else stage)), ROUGH, SEATED)
	peck = []
	for h in d.get("peck", []):
		peck.append(int(h))
	if item_id == "anvil_stone" and stage != ROUGH and not d.has("mass"):
		mass = float(Items.weight(item_id))
	if is_inside_tree():
		_rebuild()
