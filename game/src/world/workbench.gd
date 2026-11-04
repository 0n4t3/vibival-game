extends StaticBody3D
## A workbench (group "workbenches"): a plain wooden table with a tool rack
## along its back, built where you kneel with boards, sticks and cordage (the
## "workbench" recipe). Kneeling at it (C) works on its top, where "bench"
## tier recipes can be made as well as everything you can make by hand.
## Workbench tools (items with `rack`) hang on the rack: hold one and press E
## at the bench to hang it up, look at a hanging tool and press E to take it
## down again. A recipe with `rack` needs that tool hanging there.
##
## Three blows with an axe or a mattock knock it loose: its tools go in your
## bag and you carry it in your arms (player.gd `hauling`), to set it up
## again in front of you with right-click, Q or E. Its legs reach down to
## uneven ground (scene_base.bench_height).
##
## Local space: the front edge of the top faces +Z, where you stand to work,
## and the rack runs along the back at -Z.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const SLOTS := 4
const LOOSE_HITS := 3
const HIT_WINDOW := 4.0  # seconds within which the blows must land

var tools: Array = []   # SLOTS item ids hanging on the rack, left to right ("" for none)
var hauled_by: Node3D = null

var _rack: Array = []   # RackTool nodes, by slot
var _feet: MeshInstance3D = null
var _hits := 0
var _hit_t := -INF


## A tool hanging on the rack, which you can look at and take down.
class RackTool extends StaticBody3D:
	var bench: Node3D
	var slot := 0

	func prompt(_player: Node) -> String:
		return "%s on the rack: take it down [E]" % Items.item_name(bench.tools[slot])

	func interact(player: Node) -> void:
		bench.take_down(slot, player)


func _ready() -> void:
	add_to_group("workbenches")
	collision_layer = 1 | 2
	collision_mask = 0
	set_meta("hard", true)
	var size: Vector3 = Assets.BENCH_SIZE
	var top := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y + 0.02, size.z)
	top.shape = box
	top.position.y = (size.y + 0.02) * 0.5
	add_child(top)
	var back := CollisionShape3D.new()
	var board := BoxShape3D.new()
	board.size = Vector3(size.x, 0.66, 0.1)
	back.shape = board
	back.position = Vector3(0, 1.12, -0.36)
	add_child(back)
	var mi := MeshInstance3D.new()
	mi.mesh = Assets.mesh("item_workbench")
	mi.visibility_range_end = 90.0
	add_child(mi)
	_add_feet()
	tools.resize(SLOTS)
	for i in SLOTS:
		if tools[i] == null:
			tools[i] = ""
	_rebuild_rack()


func _add_feet() -> void:
	## On uneven ground, longer legs down to the ground under each one.
	if _feet:
		_feet.queue_free()
		_feet = null
	var world := get_parent()
	if world == null or not world.has_method("floor_height") or hauled_by:
		return
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for leg in Assets.bench_legs():
		var g: float = world.floor_height(to_global(leg) + Vector3(0, 0.05, 0))
		var low := global_position.y - g
		if g > -INF and low > 0.02:
			b.cylinder(leg - Vector3(0, low, 0), leg + Vector3(0, 0.05, 0), 0.042, 0.04, 5, Assets.WOOD, Color(-1, 0, 0), "wood")
	if not b.is_empty():
		_feet = MeshInstance3D.new()
		_feet.mesh = b.commit(Assets.materials)
		_feet.visibility_range_end = 90.0
		add_child(_feet)


func has_tool(id: String) -> bool:
	return id in tools


func teach() -> void:
	## Using a bench (E or kneeling at it) teaches its recipes and those of
	## every tool on its rack.
	Game.unlock_tier("bench")
	for id in tools:
		if id != "":
			Game.learn_tool(id)


func free_slot() -> int:
	return tools.find("")


func hang(id: String) -> bool:
	## Puts a workbench tool up on the first free peg.
	var i := free_slot()
	if i < 0 or not Items.def(id).get("rack", false) or has_tool(id):
		return false
	tools[i] = id
	_rebuild_rack()
	return true


func take_down(slot: int, _player: Node) -> void:
	var id: String = tools[slot]
	if id == "":
		return
	if Game.inventory.add(id, 1) > 0:
		Game.notify("Too heavy to carry any more.")
		return
	tools[slot] = ""
	Sfx.play("pickup", -6.0)
	Game.picked.emit(id)
	_rebuild_rack()


func _rebuild_rack() -> void:
	## Each tool hangs from its peg, face out, with its own body to look at.
	for n in _rack:
		n.queue_free()
	_rack.clear()
	if not is_inside_tree():
		return
	for i in SLOTS:
		var id: String = tools[i]
		if id == "":
			continue
		var t := RackTool.new()
		t.bench = self
		t.slot = i
		t.collision_layer = 2
		t.collision_mask = 0
		var at := Vector3(Assets.bench_slot_x(i), Assets.BENCH_RACK.y, Assets.BENCH_RACK.z)
		t.position = at
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.28, 0.4, 0.12)
		cs.shape = box
		cs.position.z = 0.04
		t.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = Assets.mesh("item_" + id)
		var size := mi.mesh.get_aabb().size
		# Stood up against the rack board, the side that lies uppermost on the
		# ground facing out toward you. Long tools hang by their handles.
		var basis := Basis(Vector3.RIGHT, PI * 0.5)
		var k := minf(1.0, minf(0.27 / maxf(size.x, 0.01), 0.38 / maxf(size.z, 0.01)))
		if size.x > size.z * 1.4:
			basis = Basis(Vector3.BACK, -PI * 0.5) * basis
			k = minf(1.0, minf(0.38 / maxf(size.x, 0.01), 0.27 / maxf(size.z, 0.01)))
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * k), Vector3.ZERO)
		mi.position -= mi.transform.basis * mi.mesh.get_aabb().get_center()
		mi.position.z = 0.0
		t.add_child(mi)
		add_child(t)
		_rack.append(t)


func prompt(_player: Node) -> String:
	var held: String = Game.inventory.held_id()
	if Items.def(held).get("rack", false):
		if has_tool(held):
			return "Workbench: a %s already hangs on its rack" % Items.item_name(held).to_lower()
		if free_slot() < 0:
			return "Workbench: the rack is full"
		return "Hang the %s on the rack [E]   or kneel to work at the bench [C]" % Items.item_name(held).to_lower()
	return "Workbench: kneel to work at it [C]"


func interact(_player: Node) -> void:
	teach()
	var held: String = Game.inventory.held_id()
	if not Items.def(held).get("rack", false):
		Game.notify("Kneel (C) to work at the bench. Hold a workbench tool and press E to hang it on the rack.")
		return
	if has_tool(held) or free_slot() < 0:
		return
	if Game.inventory.remove(held, 1) and hang(held):
		Sfx.play("pickup", -6.0)
		Game.notify("You hang the %s on the rack." % Items.item_name(held).to_lower())


# --- Knocked loose and carried ------------------------------------------------------

func axe_hit() -> void:
	_hit()


func break_apart() -> void:
	_hit()


func _hit() -> void:
	## Blows from an axe or a mattock knock the bench loose to carry it off.
	if hauled_by:
		return
	if Game.time - _hit_t > HIT_WINDOW:
		_hits = 0
	_hit_t = Game.time
	_hits += 1
	Sfx.play_at("chop", global_position + Vector3(0, 0.6, 0), -4.0, 0.2)
	if _hits < LOOSE_HITS:
		var left := LOOSE_HITS - _hits
		Game.notify("You knock at the workbench. %d more blow%s to knock it loose." % [left, "" if left == 1 else "s"])
		return
	_hits = 0
	var world := get_parent()
	var player: Node = world.player if world and "player" in world else null
	if player == null or player.hauling:
		return
	# Its tools come off the rack into your bag (onto the ground if it is full).
	for i in SLOTS:
		var id: String = tools[i]
		if id == "":
			continue
		tools[i] = ""
		if Game.inventory.add(id, 1) > 0 and world.has_method("spawn_pickup"):
			world.spawn_pickup(id, 1, global_position + global_basis.z * 0.8 + Vector3(0, 0.3, 0))
	_rebuild_rack()
	player.start_haul(self)
	Game.notify("You knock the workbench loose and pick it up. Right-click (or Q) sets it up in front of you.")


func can_haul() -> bool:
	return true


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return "workbench"


func haul_radius() -> float:
	return Assets.BENCH_SIZE.z * 0.5 + 0.3


func haul_yaw() -> float:
	## Its front toward you, the rack on the far side.
	return 0.0


func haul_lift() -> float:
	## Held low, its feet just off the ground, so you can see over it.
	return 0.1


func haul_prompt(_player: Node) -> String:
	return "Set up the workbench here [Right-click / Q]"


func haul_use(player: Node) -> bool:
	## Right-click while carrying it: set it up in front of you.
	player.put_down()
	return true


func can_put_down() -> bool:
	## Only somewhere it can stand: dry, with room for it.
	var world := get_parent()
	if world == null or not world.has_method("bench_blocker"):
		return true
	var exclude := [get_rid()]
	if hauled_by is CollisionObject3D:
		exclude.append(hauled_by.get_rid())
	var why: String = world.bench_blocker(global_position, rotation.y, exclude)
	if why != "":
		Game.notify("The workbench needs %s." % why)
	return why == ""


func set_hauled(by: Node3D) -> void:
	## Picked up (or set up again, by = null) where it is.
	hauled_by = by
	collision_layer = 0 if by else 1 | 2
	if by == null:
		var world := get_parent()
		if world and world.has_method("bench_height"):
			global_position.y = world.bench_height(global_position, rotation.y)
		rotation = Vector3(0, rotation.y, 0)
		Sfx.play_at("thud", global_position, -6.0)
	_add_feet()


func to_dict() -> Dictionary:
	var p := global_position
	if hauled_by and get_parent() and get_parent().has_method("bench_height"):
		p.y = get_parent().bench_height(p, rotation.y)  # saved standing where it was carried
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "tools": tools.duplicate()}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	var list: Array = d.get("tools", [])
	tools.resize(SLOTS)
	for i in SLOTS:
		var id: String = list[i] if i < list.size() and list[i] is String else ""
		tools[i] = id if Items.def(id).get("rack", false) else ""
	_rebuild_rack()
