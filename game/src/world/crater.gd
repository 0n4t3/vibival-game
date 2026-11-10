extends Node3D
## Where a meteorite came down (group "craters", metals.md): a scorched hollow
## with a raised rim, smoking for a day (LIFE). The meteorite itself
## (heavy_stone.gd) lies half buried in the middle.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const LIFE := 1440.0
const R := 2.2

var made_at := 0.0
var _smoke: CPUParticles3D


func _ready() -> void:
	add_to_group("craters")
	var m := MeshInstance3D.new()
	m.visibility_range_end = 200.0
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	b.blob(Vector3(0, -0.02, 0), Vector3(R, 0.06, R), 1, 9, Color(0.10, 0.09, 0.08), rng, 0.15, "clay")
	for i in 12:
		var a := TAU * i / 12.0 + rng.randf_range(-0.15, 0.15)
		b.blob(Vector3(cos(a), 0, sin(a)) * R * 1.05, Vector3(0.6, 0.22, 0.45), 1, 5, Color(0.28, 0.22, 0.17) * rng.randf_range(0.8, 1.1), rng, 0.25, "clay")
	m.mesh = b.commit(Assets.materials)
	add_child(m)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 40
	_smoke.lifetime = 8.0
	_smoke.position = Vector3(0, 0.3, 0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.8
	_smoke.initial_velocity_max = 1.6
	_smoke.gravity = Vector3(0.1, 0.25, 0)
	_smoke.scale_amount_min = 1.0
	_smoke.scale_amount_max = 3.0
	var puff := QuadMesh.new()
	puff.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.29, 0.28, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff.material = mat
	_smoke.mesh = puff
	add_child(_smoke)
	_smoke.emitting = smoking()


func smoking() -> bool:
	return Game.time - made_at < LIFE


func _process(_delta: float) -> void:
	if _smoke.emitting and not smoking():
		_smoke.emitting = false


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "made_at": made_at}


func from_dict(d: Dictionary) -> void:
	made_at = float(d.get("made_at", 0.0))
	if _smoke:
		_smoke.emitting = smoking()
