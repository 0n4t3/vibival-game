extends Node3D
## A thrown baitbox bobbing where it landed in the water, with the water
## churning round it, while the amphibians it drew tear at it (swamp.start_frenzy).
## It is torn apart and sinks as the frenzy ends, then it is gone. Not saved.

const ThrownRock := preload("res://src/world/thrown_rock.gd")
const SINK := 3.0     # seconds it takes to go under at the end

var left := 30.0      # seconds of frenzy still to go
var world: Node = null
var _t := 0.0
var _churn := 0.0
var _mesh: MeshInstance3D


func setup(item_id: String, at: Vector3, secs: float, w: Node) -> Node3D:
	left = secs
	world = w
	top_level = true
	position = at
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Assets.mesh("item_" + item_id)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	rotation.y = randf() * TAU
	return self


func _process(delta: float) -> void:
	_t += delta
	left -= delta
	# Bobbing and knocked about, then dragged under at the end.
	var sink := clampf(-left / SINK, 0.0, 1.0)
	_mesh.position.y = -0.04 + sin(_t * 5.0) * 0.02 - sink * 0.4
	_mesh.rotation = Vector3(sin(_t * 7.3) * 0.25, 0.0, sin(_t * 6.1) * 0.25) * (1.0 - sink)
	if left > 0.0:
		_churn -= delta
		if _churn <= 0.0:
			_churn = randf_range(0.4, 0.9)
			var off := Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
			ThrownRock.ripple(world, global_position + off)
	elif sink >= 1.0:
		queue_free()
