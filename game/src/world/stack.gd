extends StaticBody3D
## A pile of one kind of raw material on the ground (group "stacks"): stones,
## sticks, fronds, firewood, boards, logs... Items that can go on a pile have
## `pile` set (see items.gd). Dropping one beside a pile of its kind adds it,
## and a carried log put down beside another log starts a log pile. There is
## no limit to how many a pile holds, though only SHOWN of them are drawn.
## E takes one (a log into your arms); holding E keeps taking.

const WoodLog := preload("res://src/world/wood_log.gd")

const SHOWN := 12
const REACH := 1.5   # how close to a pile a dropped item joins it

var item_id := ""
var count := 0
var kind := ""   # logs: the tree they came from (a pile holds one kind)

var _body: Node3D
var _shape: CollisionShape3D


func setup(id: String, n: int, tree_kind := "") -> Node3D:
	item_id = id
	count = n
	kind = tree_kind if Items.def(id).get("carry", false) and tree_kind != "" else (Assets.LOG_KIND if Items.def(id).get("carry", false) else "")
	return self


func _ready() -> void:
	add_to_group("stacks")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	_body = Node3D.new()
	add_child(_body)
	rebuild()


func carried() -> bool:
	## Logs: taken off the pile into your arms rather than the bag.
	return Items.def(item_id).get("carry", false)


static func layout(id: String, n: int) -> Array:
	## Where each of the first n items sits: [Transform3D], bottom up.
	var out := []
	var def := Items.def(id)
	var mesh: Mesh = Assets.mesh("item_" + id)
	var size := mesh.get_aabb().size
	match def.get("shape", ""):
		"log", "short_log", "firewood":
			# Rows of rounds lying side by side, each row in the grooves of
			# the one below: 5, 4, 3...
			var w := Assets.LOG_R * 2.0 if def.shape != "firewood" else 0.2
			var row := 0
			var in_row := 0
			var per := 5
			for k in n:
				if in_row >= per:
					row += 1
					in_row = 0
					per = maxi(per - 1, 1)
				var z := (in_row - (per - 1) * 0.5) * w
				out.append(Transform3D(Basis(), Vector3(0, row * w * 0.86, z)))
				in_row += 1
		"plank", "bark":
			# Laid flat one on another, a little askew.
			var h := maxf(size.y * 0.8, 0.03)
			for k in n:
				var yaw := sin(k * 2.3) * 0.12
				out.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(sin(k * 1.7) * 0.03, k * h, cos(k * 1.3) * 0.03)))
		_:
			# A heap: one in the middle and five round it, four on those,
			# then two on top.
			var spread := maxf(maxf(size.x, size.z) * 0.55, 0.06)
			var h := maxf(size.y * 0.7, 0.02)
			var spots := [Vector3.ZERO]
			for ring in [[5, 1.0, 0.0], [4, 0.55, 1.0], [2, 0.25, 2.0]]:
				for i in ring[0]:
					var a: float = TAU * i / ring[0] + ring[2] * 0.7
					spots.append(Vector3(cos(a) * ring[1] * spread, ring[2] * h, sin(a) * ring[1] * spread))
			for k in mini(n, spots.size()):
				out.append(Transform3D(Basis(Vector3.UP, k * 2.39), spots[k]))
	return out


func rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	var mesh: Mesh = Assets.log_mesh(item_id, kind) if carried() else Assets.mesh("item_" + item_id)
	var spots := layout(item_id, mini(count, SHOWN))
	var aabb := AABB()
	for k in spots.size():
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = spots[k]
		mi.visibility_range_end = 60.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(mi)
		var box: AABB = spots[k] * mesh.get_aabb()
		aabb = box if k == 0 else aabb.merge(box)
	var size := aabb.size.max(Vector3(0.5, 0.2, 0.5))
	(_shape.shape as BoxShape3D).size = size
	_shape.position = aabb.get_center()


func prompt(_player: Node) -> String:
	var what := Items.item_name(item_id)
	var n := " (%d)" % count if count > 1 else ""
	if carried():
		what = WoodLog.wood_name(item_id, kind)
		return "%s pile%s: pick up a %s [E]" % [what, n, what.to_lower()]
	if count > 1:
		return "%s pile%s: take one [E], hold to take more" % [what, n]
	return "Pick up %s [E]" % what


func interact(player: Node) -> void:
	take_one(player)


func take_one(player: Node) -> bool:
	## One off the top: into the bag, or a log into your arms.
	if count <= 0:
		return false
	if carried():
		if player.hauling or player.world == null or not player.world.has_method("add_log"):
			return false
		var top: Transform3D = layout(item_id, mini(count, SHOWN)).back()
		var lg: Node3D = player.world.add_log(item_id, global_transform * top.origin, rotation.y, kind)
		player.start_haul(lg)
	elif Game.inventory.add(item_id, 1) > 0:
		Game.notify("Too heavy to carry any more.")
		return false
	else:
		Sfx.play("pickup", -8.0)
		Game.picked.emit(item_id)
	count -= 1
	if count <= 0:
		queue_free()
	else:
		rebuild()
	return true


func add(n: int) -> void:
	count += n
	rebuild()
	Sfx.play_at("step", global_position, -6.0, 0.2)


func to_dict() -> Dictionary:
	var p := global_position
	var d := {"id": item_id, "n": count, "pos": [p.x, p.y, p.z], "yaw": rotation.y}
	if kind != "":
		d.kind = kind
	return d
