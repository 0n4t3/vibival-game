extends Node3D
## Dev tool: renders each tree mesh from a few angles to .dev-out/trees_*.png.
## tools/dev-run.sh res://tests/view_trees.tscn [-- --trees=calamites,tree_fern]
## --parts renders the stump and the cut ends of a felled trunk instead.

const OUT := "res://../.dev-out/"

var _cam: Camera3D
var _mi: MeshInstance3D


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.70)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 1.6
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.4
	add_child(sun)
	_mi = MeshInstance3D.new()
	add_child(_mi)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://").path_join("../.dev-out/trees_%s.png" % name)
	img.save_png(path)
	print("saved ", path)


func _parts(names: Array) -> void:
	## The stump left standing, and the felled trunk from its cut end, fresh
	## and rotten (tree units = metres at scale 1).
	var top := 0.65
	for n in names:
		for part in [["stump", Assets.tree_part(n, -INF, top), Vector3(1, 0.8, 0.6), Vector3(0, 0.3, 0), 2.2],
				["butt", Assets.tree_part(n, top, INF), Vector3(0.5, -1, 0.4), Vector3(0, top, 0), 2.2],
				["rotten", Assets.tree_part(n, top, INF, true, Color(0.55, 0.5, 0.42)), Vector3(1, 0.3, 0.5), Vector3(0, top + 3.0, 0), 9.0]]:
			_mi.mesh = part[1]
			_cam.look_at_from_position(part[3] + part[2].normalized() * part[4], part[3])
			await _shot("%s_%s" % [n, part[0]])


func _run() -> void:
	var names: Array = Game.dev.get("trees", ",".join(Assets.TREES)).split(",")
	if Game.dev.has("parts"):
		await _parts(names)
		get_tree().quit()
		return
	for n in names:
		_mi.mesh = Assets.mesh(n)
		var aabb := _mi.mesh.get_aabb()
		var c := aabb.get_center()
		var size := aabb.size.length()
		for view in [["side", Vector3(1, 0.15, 0.3), c, size * 0.95], ["base", Vector3(1, 0.5, 0.6), Vector3(0, 1.0, 0), 6.0],
				["top", Vector3(0.6, 0.9, 0.4), Vector3(c.x, aabb.end.y - aabb.size.y * 0.15, c.z), aabb.size.x * 1.2],
				["crown", Vector3(1, -0.2, 0.2), Vector3(c.x, aabb.end.y - aabb.size.y * 0.15, c.z), aabb.size.x * 1.1]]:
			_cam.look_at_from_position(view[2] + view[1].normalized() * view[3], view[2])
			await _shot("%s_%s" % [n, view[0]])
	get_tree().quit()
