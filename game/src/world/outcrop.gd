extends "res://src/world/harvestable.gd"
## A copper outcrop on an island (metals.md): a hump of rock streaked green
## with copper ore. A copper hammer breaks out 3-5 lumps of ore (wearing the
## hammer); then it takes days before more is worth breaking loose. It is
## made from the island's seed, so it is always where it was (Game.harvested
## keeps when it was last worked by its uid).

const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const NEED := "The ore is locked in hard rock. A copper hammer would break it out."


func _ready() -> void:
	super()
	add_to_group("outcrops")
	var m := MeshInstance3D.new()
	m.visibility_range_end = 160.0
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(uid)
	b.blob(Vector3(0, 0.35, 0), Vector3(1.0, 0.55, 0.85), 2, 7, Color(0.36, 0.34, 0.32), rng, 0.25, "stone")
	for i in 5:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a) * 0.55, rng.randf_range(0.3, 0.7), sin(a) * 0.45)
		b.blob(p, Vector3(0.22, 0.12, 0.18), 1, 5, Color(0.22, 0.52, 0.40).lerp(Color(0.45, 0.32, 0.18), rng.randf() * 0.4), rng, 0.2, "stone")
	m.mesh = b.commit(Assets.materials)
	add_child(m)


func prompt(player: Node) -> String:
	if not is_ready():
		return "Copper outcrop (broken out: %s before more is worth breaking loose)" % days_text(_ready_time - Game.time)
	if not Game.inventory.has_tag("hammer"):
		return "Copper outcrop: green ore in the rock (a copper hammer would break it out)"
	return super(player)


func interact(player: Node) -> void:
	if not is_ready():
		return
	if not Game.inventory.has_tag("hammer"):
		Game.notify(NEED)
		return
	Sfx.play_at("hit", global_position, -2.0, 0.2)
	super(player)
	Game.inventory.use_tag("hammer")  # wears a copper hammer (Inventory.use_tool)
