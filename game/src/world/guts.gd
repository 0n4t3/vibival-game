extends StaticBody3D
## A pile of guts (and maybe a skin) left by gutting an animal, or thrown or
## dropped guts. It lies for one in-game day unless something eats it, and is
## saved with the world (group "guts"). Every ROLL_EVERY real seconds while the
## player is within ROLL_RANGE, the smell may draw an Eogyrinus and a land
## scavenger to it (swamp.draw_to_guts). E picks the guts back up, one at a time.

const ROLL_EVERY := 300.0
const ROLL_RANGE := 160.0
const ROLL_CHANCE := 0.25

var n := 1                   # handfuls of guts in it (the item "guts")
var skin := false            # a skin thrown on top (not worth keeping)
var made := 0.0              # Game.time it was left
var roll_t := ROLL_EVERY     # real seconds to the next scavenger roll
var eaten_by: Node3D = null  # a scavenger eating it
var world: Node = null

var _body: Node3D
var _rng := RandomNumberGenerator.new()


func setup(count: int, with_skin: bool, w: Node) -> Node3D:
	n = count
	skin = with_skin
	made = Game.time
	world = w
	return self


func _ready() -> void:
	add_to_group("guts")
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.4
	cs.shape = sh
	cs.position.y = 0.1
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	_rng.randomize()
	rebuild()


func rebuild() -> void:
	## Coils of gut heaped up, one heap per handful, under a flat skin.
	for c in _body.get_children():
		c.queue_free()
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	var b = Assets.builder()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(made * 10.0) + n
	var col: Color = Items.def("guts").color
	for i in mini(n, 6):
		var o := Vector3(rng.randf_range(-0.18, 0.18), 0.0, rng.randf_range(-0.18, 0.18))
		Assets.gut_coil(b, rng, o, col * rng.randf_range(0.85, 1.1))
	if skin:
		b.blob(Vector3(0.12, 0.015, -0.1), Vector3(0.32, 0.015, 0.22), 2, 7, Color(0.36, 0.34, 0.22), rng, 0.3, "organic")
	if n <= 0 and not skin:
		b.blob(Vector3(0, 0.01, 0), Vector3(0.2, 0.01, 0.16), 2, 6, col.darkened(0.4), rng, 0.3, "organic")
	mi.mesh = b.commit(Assets.materials)
	_body.add_child(mi)


func _process(delta: float) -> void:
	if Game.time > made + Game.DAY_LENGTH:
		queue_free()
		return
	roll_t -= delta
	if roll_t > 0.0:
		return
	roll_t = ROLL_EVERY
	var p: Node3D = Game.player
	if p == null or p.global_position.distance_to(global_position) > ROLL_RANGE or world == null \
			or not world.has_method("draw_to_guts"):
		return
	if _rng.randf() < ROLL_CHANCE:
		world.draw_to_guts(self, "eogyrinus")
	if _rng.randf() < ROLL_CHANCE:
		world.draw_to_guts(self, "medium")


func add(count: int, with_skin := false) -> void:
	n += count
	skin = skin or with_skin
	rebuild()


func prompt(_player: Node) -> String:
	if eaten_by and is_instance_valid(eaten_by) and not eaten_by.dead:
		return "A %s is eating the guts" % eaten_by.def.name
	if n <= 0:
		return "A discarded skin"
	return "Pick up Guts%s [E]" % (" x%d" % n if n > 1 else "")


func interact(_player: Node) -> void:
	if eaten_by and is_instance_valid(eaten_by) and not eaten_by.dead or n <= 0:
		return
	if Game.inventory.add("guts", 1) > 0:
		Game.notify("Too heavy to carry any more.")
		return
	Sfx.play("pickup", -8.0)
	Game.picked.emit("guts")
	n -= 1
	if n <= 0 and not skin:
		queue_free()
		return
	rebuild()


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "n": n, "skin": skin, "made": made, "roll_t": roll_t}
