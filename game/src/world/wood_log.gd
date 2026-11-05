extends StaticBody3D
## A log or short log lying loose on the ground (group "logs"). It is too big
## for the bag: E picks it up to carry in your arms (player.start_haul), and
## kneeling at it (C) with an axe works it (work_spot.gd). A log keeps on dry
## ground, but one left lying in water soaks; after ROT_AFTER in the water it
## is rotten, can be searched like any rotting log, and is gone GONE_AFTER later.
##
## A log remembers the `kind` of tree it came from and looks like it (bark,
## and wood once stripped: Assets.log_mesh); logs of one kind pile together.
##
## Local space: the log lies along X with its middle at the origin, resting on
## the ground.

const Chunk := preload("res://src/world/chunk.gd")

const ROT_AFTER := 3.0 * 1440.0
const GONE_AFTER := 3.0 * 1440.0
const TICK := 2.0

var item_id := "log"
var kind := Assets.LOG_KIND   # the tree it was cut from (Chunk.TREES)
var soak := 0.0            # seconds spent lying in water
var rotted_at := -1.0      # Game.time it went rotten, or -1
var searched := false
var hauled_by: Node3D = null
var world: Node = null

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _tick := 0.0


func setup(id: String, w: Node, tree_kind := Assets.LOG_KIND) -> Node3D:
	item_id = id
	world = w
	kind = tree_kind if Chunk.TREES.has(tree_kind) else Assets.LOG_KIND
	return self


static func wood_name(id: String, tree_kind: String) -> String:
	## "Calamites log", "Tree Fern stripped log"...
	var tree: String = Chunk.TREES[tree_kind].name if Chunk.TREES.has(tree_kind) else ""
	return (tree + " " + Items.item_name(id).to_lower()).strip_edges()


func _ready() -> void:
	add_to_group("logs")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length(), Assets.LOG_R * 2.0, Assets.LOG_R * 2.4)
	_shape.shape = box
	_shape.position.y = Assets.LOG_R
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.visibility_range_end = 80.0
	add_child(_mesh)
	_rebuild()


func length() -> float:
	return Assets.SHORT_LOG_LEN if item_id == "short_log" else Assets.LOG_LEN


func rotten() -> bool:
	return rotted_at >= 0.0


func name_lower() -> String:
	return wood_name(item_id, kind).to_lower()


func _rebuild() -> void:
	_mesh.mesh = Assets.rotten_log(item_id) if rotten() else Assets.log_mesh(item_id, kind)


func lie_on_ground() -> void:
	## Tips along its length to the slope under it, so neither end sinks into
	## the ground.
	if world == null or not world.has_method("floor_height"):
		return
	var yaw := rotation.y
	var axis := Vector3(cos(yaw), 0, -sin(yaw))  # the log's length (X)
	var p := global_position
	var half := length() * 0.5
	var a: float = world.floor_height(p + axis * half)
	var b: float = world.floor_height(p - axis * half)
	var c: float = world.floor_height(p)
	if not (is_finite(a) and is_finite(b) and is_finite(c)):
		return
	rotation = Vector3(0, yaw, clampf(atan2(a - b, length()), -0.5, 0.5))
	global_position.y = maxf(c, (a + b) * 0.5)


func set_id(id: String) -> void:
	## Worked into another kind of log (stripped, or cut down short).
	item_id = id
	(_shape.shape as BoxShape3D).size.x = length()
	_rebuild()


func in_water() -> bool:
	if world == null or not world.has_method("water_level"):
		return false
	var g: float = world.floor_height(global_position) if world.has_method("floor_height") else world.ground_height(global_position.x, global_position.z)
	return g + Assets.LOG_R < world.water_level()


func _process(delta: float) -> void:
	if hauled_by:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	var dt := TICK - _tick
	_tick = TICK
	if rotten():
		if Game.time > rotted_at + GONE_AFTER:
			queue_free()
		return
	if in_water():
		soak += dt
		if soak >= ROT_AFTER:
			rotted_at = Game.time
			_rebuild()


# --- Carrying (see player.start_haul) ---------------------------------------------

func can_haul() -> bool:
	return not rotten()


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return name_lower()


func haul_radius() -> float:
	return Assets.LOG_R


func haul_yaw() -> float:
	## Carried across your arms.
	return 0.0


func haul_lift() -> float:
	## Hugged up at chest height, where you can see it.
	return 1.0


func haul_prompt(_player: Node) -> String:
	var bin := _compost_bin(_player)
	if bin:
		return "Put the %s in the compost [E]   (+10, slows it to %d days; Q puts it down)" % [haul_name(), roundi(bin.DAYS * 4.0)]
	var site := _stilt_site(_player)
	if site and _stilt_wood():
		return "%s with this log [E]   (Q puts it down)" % site.next_part().verb
	if site:
		return "Put down the %s [E]   (a stilt needs a 2 m Calamites log)" % haul_name()
	return "Put down the %s [E]" % haul_name()


func haul_interact(player: Node) -> bool:
	## Carried to a house site waiting for its next stilt: raise it. Carried
	## to a compost basket that isn't full: it goes in.
	var bin := _compost_bin(player)
	if bin:
		bin.add(item_id)
		player.hauling = null
		queue_free()
		return true
	var site := _stilt_site(player)
	if site == null or not _stilt_wood():
		return false
	world.start_house_work(site, self)
	return true


func _compost_bin(player: Node) -> Node3D:
	## A compost basket close by with room for a log (not a short log).
	if world == null or not world.has_method("compost_near") or player == null or not item_id in ["log", "log_stripped"]:
		return null
	var c: Node3D = world.compost_near(player.global_position, 2.2)
	return c if c and not c.full() else null


func _stilt_wood() -> bool:
	return kind == "calamites" and item_id in ["log", "log_stripped"]


func _stilt_site(player: Node) -> Node3D:
	## A house site close by whose next part is a stilt.
	if world == null or not world.has_method("house_at") or player == null:
		return null
	var h: Node3D = world.house_at(player.global_position, 3.0)
	return h if h and not h.complete() and h.wants_log() else null


func set_hauled(by: Node3D) -> void:
	## Picked up (or put down, by = null). A log put down beside others of its
	## kind goes on their pile.
	hauled_by = by
	_shape.disabled = by != null
	if by == null:
		var g: float = world.floor_height(global_position) if world else global_position.y
		global_position.y = g
		rotation = Vector3(0, rotation.y, 0)
		lie_on_ground()
		if world and world.has_method("settle_log"):
			world.settle_log(self)


# --- Interaction ---------------------------------------------------------------------

func prompt(_player: Node) -> String:
	if hauled_by:
		return ""
	if rotten():
		return "A rotten log (searched)" if searched else "Search the rotten log [E]"
	return "Pick up the %s [E]   or kneel to work it [C]" % wood_name(item_id, kind)


func interact(player: Node) -> void:
	if hauled_by:
		return
	if rotten():
		if not searched:
			searched = true
			search_rotten(player, global_position)
		return
	player.start_haul(self)


static func search_rotten(player: Node, at: Vector3) -> void:
	## Rotten wood is full of grubs, with dry punk for tinder and a few sticks.
	var got := []
	for spec in [["grub", 1, 3], ["tinder", 1, 2], ["stick", 0, 2]]:
		var n := randi_range(spec[1], spec[2])
		if n <= 0:
			continue
		var left: int = Game.inventory.add(spec[0], n)
		if left > 0 and player.world and player.world.has_method("spawn_pickup"):
			player.world.spawn_pickup(spec[0], left, at + Vector3(0, 0.5, 0))
		got.append("%s x%d" % [Items.item_name(spec[0]), n])
		Game.picked.emit(spec[0])
	Sfx.play("rustle", -6.0)
	Game.notify("Found " + ", ".join(got) + ".")


func to_dict() -> Dictionary:
	var p := global_position
	return {"id": item_id, "kind": kind, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "soak": soak, "rotted_at": rotted_at, "searched": searched}


func from_dict(d: Dictionary) -> void:
	var k := String(d.get("kind", Assets.LOG_KIND))
	kind = k if Chunk.TREES.has(k) else Assets.LOG_KIND
	soak = float(d.get("soak", 0.0))
	rotted_at = float(d.get("rotted_at", -1.0))
	searched = bool(d.get("searched", false))
	rotation.y = float(d.get("yaw", 0.0))
	if is_inside_tree():
		_rebuild()
		lie_on_ground()
