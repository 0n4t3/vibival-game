extends StaticBody3D
## A heavy stone carried in your arms like a log (player.start_haul): an
## anvil stone from the islands (group "anvils"), or a meteorite fallen from
## the sky (group "meteorites", metals.md).
##
## An anvil stone set down anywhere is an anvil: hold a whetstone and press E
## to seat it in its corner (E again takes it back), and kneel at it (C) to
## grind castings sharp, sharpen blunt metal tools, smash copper and work
## iron (work_spot.gd, station "anvil"). With no whetstone in it, E picks it
## up to carry.
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
const DIG_HITS := 3                         # mattock swings to dig a meteorite out

var item_id := "anvil_stone"
var uid := ""
var mass := 30.0
var whetstone := false
var buried := false
var hauled_by: Node3D = null
var world: Node = null

var _dug := 0
var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func setup(id: String, w: Node, kg := -1.0) -> Node3D:
	item_id = id
	world = w
	mass = kg if kg > 0.0 else float(Items.weight(id))
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
		b.box(Vector3(0, ANVIL.y - 0.04, 0), Vector3(ANVIL.x * 0.82, 0.08, ANVIL.z * 0.78), Color(0.33, 0.33, 0.35), Basis(), "stone")
		if whetstone:
			b.box(Vector3(ANVIL.x * 0.3, ANVIL.y + 0.02, ANVIL.z * 0.22), Vector3(0.2, 0.05, 0.09), Color(0.66, 0.66, 0.62), Basis(), "stone")
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
		return "anvil"
	return "" if buried else "meteorite"


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
	return "meteorite" if item_id == "meteorite" else "anvil stone"


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
	if held == "whetstone":
		return "Seat the whetstone in the anvil [E]   or kneel to work at it [C]"
	return "Anvil: kneel to work at it [C]   Pick up the anvil stone [E]"


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
	return {"id": item_id, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "mass": mass, "whetstone": whetstone, "buried": buried, "uid": uid}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	mass = float(d.get("mass", mass))
	whetstone = bool(d.get("whetstone", false))
	buried = bool(d.get("buried", false))
	uid = String(d.get("uid", ""))
	if is_inside_tree():
		_rebuild()
