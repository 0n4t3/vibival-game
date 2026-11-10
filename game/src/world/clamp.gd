extends StaticBody3D
## A charcoal clamp (group "clamps", metals.md): a pit of firewood sealed
## under wet clay, built by hand (items.gd, `build` "clamp"). Lit with an
## ember or a lit torch (E), it smoulders under a thin smoke for BURN (a game
## day), then a mattock breaks it open for 8-12 charcoal. Opened early, some
## of the wood is still only charred sticks. Broken up unlit, the firewood
## comes back.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const BURN := 1440.0
const WOOD := 10

var lit_at := -1.0
var world: Node = null
var _rng := RandomNumberGenerator.new()
var _smoke: CPUParticles3D
var _mesh: MeshInstance3D


func setup(w: Node) -> Node3D:
	world = w
	return self


func _ready() -> void:
	add_to_group("clamps")
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.75
	cyl.height = 0.5
	cs.shape = cyl
	cs.position.y = 0.25
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	b.blob(Vector3(0, 0.12, 0), Vector3(0.8, 0.32, 0.8), 2, 7, Color(0.52, 0.47, 0.40), rng, 0.15, "clay")
	b.blob(Vector3(0, 0.38, 0), Vector3(0.12, 0.05, 0.12), 1, 5, Color(0.2, 0.18, 0.16), rng, 0.1, "clay")
	_mesh.mesh = b.commit(Assets.materials)
	add_child(_mesh)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 24
	_smoke.lifetime = 5.0
	_smoke.position = Vector3(0, 0.42, 0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 8.0
	_smoke.initial_velocity_min = 0.3
	_smoke.initial_velocity_max = 0.6
	_smoke.gravity = Vector3(0.05, 0.12, 0)
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.6
	var puff := QuadMesh.new()
	puff.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.7, 0.68, 0.25)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff.material = m
	_smoke.mesh = puff
	add_child(_smoke)
	_smoke.emitting = lit()


func lit() -> bool:
	return lit_at >= 0.0


func done() -> bool:
	return lit() and Game.time - lit_at >= BURN


func prompt(_player: Node) -> String:
	var held: String = Game.inventory.held_id()
	var mattock: bool = "dig" in Items.def(held).get("tags", [])
	if not lit():
		if held in ["ember", "torch_lit"]:
			return "Light the charcoal clamp [E]"
		return "Charcoal clamp: light it with an ember or a lit torch%s" % ("   (swing the mattock to break it up)" if mattock else "")
	if done():
		return "Charcoal clamp, burnt through: %s" % ("swing the mattock to break it open" if mattock else "break it open with a mattock")
	var left := BURN - (Game.time - lit_at)
	return "Charcoal clamp, smouldering (about %d h left)%s" % [ceili(left / 60.0), "   (swing the mattock to open it early)" if mattock else ""]


func interact(_player: Node) -> void:
	if lit():
		return
	var held: String = Game.inventory.held_id()
	if held == "ember":
		Game.inventory.take(Game.inventory.selected, 1)
	elif held != "torch_lit":
		return
	lit_at = Game.time
	_smoke.emitting = true
	Sfx.play_at("fire_light" if Sfx.has_method("has") and Sfx.call("has", "fire_light") else "rustle", global_position, -6.0)
	Game.crafted.emit("clamp_lit")
	Game.notify("The clamp catches and begins to smoulder. Leave it a day, then break it open with a mattock.")


func break_apart() -> void:
	## A mattock opens it: charcoal if it has burnt through, some charcoal and
	## charred sticks if opened early, the firewood back if never lit.
	var got := {}
	if not lit():
		got["firewood"] = WOOD
	elif done():
		got["charcoal"] = _rng.randi_range(8, 12)
	else:
		var f := clampf((Game.time - lit_at) / BURN, 0.0, 1.0)
		got["charcoal"] = floori(f * 8.0)
		got["charred_stick"] = ceili((1.0 - f) * 6.0)
	var list := []
	var k := 0
	for id in got:
		if got[id] <= 0:
			continue
		if world and world.has_method("pile_item"):
			world.pile_item(id, got[id], global_position + Vector3(-0.5 + k * 0.9, 0.3, 0.9))
		list.append("%s x%d" % [Items.item_name(id), got[id]])
		k += 1
	Sfx.play_at("chop", global_position, -3.0, 0.2)
	if not lit():
		Game.notify("You break the clamp up. Left on the ground: %s." % ", ".join(list))
	elif done():
		Game.notify("You break the clamp open. Left on the ground: %s." % ", ".join(list))
		Game.crafted.emit("charcoal")
	else:
		Game.notify("You break the clamp open too soon. Left on the ground: %s." % ", ".join(list))
	queue_free()


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "lit_at": lit_at}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	lit_at = float(d.get("lit_at", -1.0))
	if _smoke:
		_smoke.emitting = lit()
