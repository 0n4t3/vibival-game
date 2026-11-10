extends StaticBody3D
## A bedroll set down, still rolled up, on the floor of a finished house
## (swamp.place, "bedroll"). It is never unrolled: everything works on the roll.
## Looking at it: sleep (Z) sleeps there at once if you are tired enough
## (swamp.sleep_on_bedroll, no second press needed), interact (E) saves the
## game without sleeping (swamp.save_at_bedroll), and right-click picks it up
## again. Saved in the world state as "bedrolls".

const LENGTH := 0.75   # how long the rolled-up bag lies (Assets "bedroll" item)

var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("bedrolls")
	collision_layer = 2   # under the crosshair, but nothing walks into it
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH, 0.3, 0.3)
	cs.shape = box
	cs.position.y = 0.15
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Assets.mesh("item_bedroll")
	_mesh.visibility_range_end = 80.0
	add_child(_mesh)


func prompt(_player: Node) -> String:
	return "Bedroll: sleep [Z]   Save the game [E]   Pick it up [Right-click]"


func interact(player: Node) -> void:
	if player.world and player.world.has_method("save_at_bedroll"):
		player.world.save_at_bedroll()


func sleep_on(player: Node) -> void:
	if player.world and player.world.has_method("sleep_on_bedroll"):
		player.world.sleep_on_bedroll()


func use_interact(_player: Node) -> void:
	## Back into the bag (refused if there is no room).
	if Game.inventory.add("bedroll", 1, 0.0, true) > 0:
		Game.notify("There's no room in your bag for the bedroll.")
		return
	Sfx.play("pickup", -8.0)
	queue_free()


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
