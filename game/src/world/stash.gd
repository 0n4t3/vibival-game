extends StaticBody3D
## A sack set down on the ground as a stash. It holds up to capacity() kg
## (its sack item's `stash`: 50 for a frond sack, 100 for a cloth one) in its
## own inventory (food in it still spoils). Open it with interact to move
## things in and out; once it is empty it can be picked up again, as the same
## sack.

const Inventory := preload("res://src/core/inventory.gd")
const TICK := 1.0

var inv: RefCounted = Inventory.new()
var sack_id := "fiber_sack"   # which sack it is
var _tick_t := 0.0
var _mesh: MeshInstance3D


func _init() -> void:
	inv.overload = 1.0
	set_sack(sack_id)


func set_sack(id: String) -> void:
	sack_id = id if Items.def(id).has("stash") else "fiber_sack"
	inv.capacity_override = capacity()
	if _mesh:
		_mesh.mesh = Assets.mesh(_mesh_key())


func capacity() -> float:
	return float(Items.def(sack_id).get("stash", 50.0))


func _mesh_key() -> String:
	return "stash" if sack_id == "fiber_sack" else "stash_" + sack_id


func _ready() -> void:
	add_to_group("stashes")
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	cs.shape = sh
	cs.position.y = 0.3
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Assets.mesh(_mesh_key())
	_mesh.visibility_range_end = 80.0
	add_child(_mesh)


func _process(delta: float) -> void:
	_tick_t += delta
	if _tick_t >= TICK:
		inv.tick(_tick_t)
		_tick_t = 0.0


func prompt(_player: Node) -> String:
	return "Open %s (%.1f / %d kg) [E]" % [Items.item_name(sack_id).to_lower(), inv.weight(), capacity()]


func interact(player: Node) -> void:
	if player.world and player.world.has_method("open_stash"):
		player.world.open_stash(self)


func is_empty() -> bool:
	return inv.slots.all(func(s): return s == null)


func pick_up() -> bool:
	## Back into your inventory, only once it is empty. Its weight never stops
	## you: on your shoulder the sack lets you carry more.
	if not is_empty() or Game.inventory.add(sack_id, 1, 0.0, true) > 0:
		return false
	Sfx.play("pickup", -8.0)
	queue_free()
	return true


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "sack": sack_id, "inv": inv.to_dict()}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	set_sack(String(d.get("sack", "fiber_sack")))  # older saves: the frond sack
	inv.from_dict(d.get("inv", {}))
