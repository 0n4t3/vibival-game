extends StaticBody3D
## An item lying in the world. Picked up with interact.
## Items the player drops are kept in the save (group "drops"); discarded
## ones and the world's own generated items are not.

var item_id := ""
var count := 1
var age := 0.0
var uid := ""   # stable id for generated items so they stay taken
var data := {}  # a one of a kind item's own values (see Inventory)
var _aged_to := 0.0  # Game.time `age` was last brought up to
var _mesh: MeshInstance3D


func setup(id: String, n := 1, item_age := 0.0, unique_id := "") -> Node3D:
	item_id = id
	count = n
	age = item_age
	uid = unique_id
	return self


func _ready() -> void:
	# Food rots on the ground as in the bag, and an ember (`goes_out`) burns down.
	set_process(float(Items.def(item_id).get("decay", 0.0)) > 0.0 or carcass())
	_aged_to = Game.time
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	cs.shape = sh
	cs.position.y = 0.12
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Assets.mesh("item_" + item_id)
	_mesh.visibility_range_end = 50.0
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _process(_delta: float) -> void:
	# By the world clock, so it rots (or burns down) through a night's sleep too.
	age += maxf(Game.time - _aged_to, 0.0)
	_aged_to = Game.time
	var def := Items.def(item_id)
	if carcass():
		# A small carcass lies there until it rots away altogether, a day
		# after the kill; picked up before then it spoils in the bag by its age.
		if age >= Game.DAY_LENGTH:
			if uid != "":
				Game.taken[uid] = true
			queue_free()
		return
	if age < float(def.get("decay", 0.0)):
		return
	var into: String = "" if def.get("goes_out", false) else def.get("spoil", "rotten")
	if into == "":
		queue_free()
		return
	# Spoiled where it lies, as it would in the bag (Inventory.tick).
	item_id = into
	age = 0.0
	data = {}
	if uid != "":
		Game.taken[uid] = true  # the world's own item is gone; this one is kept instead
		uid = ""
		add_to_group("drops")
	_mesh.mesh = Assets.mesh("item_" + item_id)
	set_process(float(Items.def(item_id).get("decay", 0.0)) > 0.0)


func carcass() -> bool:
	return item_id.ends_with("_carcass")


func prompt(_player: Node) -> String:
	var n := " x%d" % count if count > 1 else ""
	return "Pick up %s%s [E]" % [Items.item_name(item_id), n]


func interact(_player: Node) -> void:
	var left: int = Game.inventory.add(item_id, count, age, false, data)
	if left == count:
		Game.notify("Too heavy to carry any more.")
		return
	Sfx.play("pickup", -8.0)
	Game.picked.emit(item_id)
	if left > 0:
		count = left
		return
	if uid != "":
		Game.taken[uid] = true
	queue_free()


func to_dict() -> Dictionary:
	var p := global_position
	var d := {"id": item_id, "n": count, "age": age, "pos": [p.x, p.y, p.z]}
	if not data.is_empty():
		d.data = data.duplicate(true)
	return d
