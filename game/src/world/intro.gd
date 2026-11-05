extends Node
## The arrival in the swamp, at the start of a new run (after the lab, or a
## new world that skips the tutorial; Game.intro_pending). It opens on a
## blinding flash: lightning strikes the nearest tree that can be felled,
## which comes down as if cut, its stump left burning (swamp.strike_tree,
## stump.gd). The white fades to the sky above you as you lie on your back,
## the bolt fading and the tree falling. Then a dragonfly flies over you and
## is gone (a stand-in built here, not a creature: it can't attack and isn't
## saved), and you get up, facing the tree. Nothing waits for input, so it plays the same with a
## keyboard, a controller or a touch screen.

const Chunk := preload("res://src/world/chunk.gd")

const STRIKE_AT := 0.05    # seconds in: the lightning, first of all
const WHITE_TIME := 3.0    # the flash fading to the sky
const BOLT_TIME := 2.2     # the bolt lingering, fading
const FLY_AT := 4.0        # the dragonfly comes over, once the tree is down
const FLY_TIME := 3.6
const RISE_AT := 8.5       # you get up
const RISE_TIME := 1.8
const STRIKE_RANGE := 30.0 # how far to look for a tree to strike

var swamp: Node
var player: Node3D
var tree := {}             # the tree lightning strikes, or {} if none is near
var t := 0.0
var struck := false

var _fly: Node3D = null
var _flown := false
var _path: Array[Vector3] = []   # bezier: from, over your head, to
var _wings: Array[Node3D] = []
var _phase := 0.0
var _yaw0 := 0.0
var _face := 0.0


func setup(s: Node) -> Node:
	swamp = s
	player = s.player
	return self


func _ready() -> void:
	player.frozen = true
	player.lie = 1.0
	tree = swamp.nearest_soft_tree(player.global_position, STRIKE_RANGE)
	_yaw0 = player.rotation.y
	_face = _yaw0


func _process(delta: float) -> void:
	t += delta
	if not _flown and t >= FLY_AT:
		_flown = true
		_start_fly()
	if _fly:
		_move_fly()
	if not struck and t >= STRIKE_AT:
		strike()
	if t >= RISE_AT:
		var k := smoothstep(0.0, 1.0, clampf((t - RISE_AT) / RISE_TIME, 0.0, 1.0))
		player.lie = 1.0 - k
		player.rotation.y = lerp_angle(_yaw0, _face, k)
		if k >= 1.0:
			finish()


# --- The dragonfly ---------------------------------------------------------------

func _start_fly() -> void:
	## From off to one side, low over your face, and away to the other.
	var p := player.global_position
	var yaw := player.rotation.y
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	_path = [p - right * 10.0 + fwd * 4.0 + Vector3(0, 4.0, 0), p + fwd * 0.6 + Vector3(0, 1.6, 0),
			p + right * 11.0 - fwd * 2.0 + Vector3(0, 5.0, 0)]
	_fly = _make_dragonfly()
	swamp.add_child(_fly)
	_fly.global_position = _path[0]


func _move_fly() -> void:
	var k := clampf((t - FLY_AT) / FLY_TIME, 0.0, 1.0)
	if k >= 1.0:
		_fly.queue_free()
		_fly = null
		return
	var pos := _bezier(k)
	var ahead := _bezier(minf(k + 0.02, 1.0))
	_fly.global_position = pos
	if ahead.distance_to(pos) > 0.001:
		_fly.look_at(ahead, Vector3.UP)
	_phase += get_process_delta_time() * 38.0
	for i in _wings.size():
		_wings[i].rotation.z = sin(_phase + (i / 2) * 1.5) * 0.6 * (1.0 if i % 2 == 0 else -1.0)


func _bezier(k: float) -> Vector3:
	return _path[0].lerp(_path[1], k).lerp(_path[1].lerp(_path[2], k), k)


func _make_dragonfly() -> Node3D:
	## Looks like a Meganeura (creature.gd's), with its wings beating and its
	## buzz, but it is only scenery.
	var root := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * 1.3
	root.add_child(body)
	var col := Color(0.15, 0.32, 0.30)
	var b = Assets.builder()
	b.blob(Vector3(0, 0, -0.12), Vector3(0.05, 0.05, 0.08), 2, 5, col)
	b.blob(Vector3(0.04, 0.02, -0.2), Vector3(0.035, 0.035, 0.035), 1, 5, Color(0.5, 0.15, 0.1))
	b.blob(Vector3(-0.04, 0.02, -0.2), Vector3(0.035, 0.035, 0.035), 1, 5, Color(0.5, 0.15, 0.1))
	b.cylinder(Vector3(0, 0, -0.05), Vector3(0, 0, 0.45), 0.025, 0.015, 5, col.lerp(Color(0.5, 0.4, 0.1), 0.5))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Assets.materials)
	body.add_child(mi)
	var wb = Assets.builder()
	wb.leaf(Vector3.ZERO, Vector3(1, 0, 0), 0.38, 0.11, 0.0, 3, Color(0.75, 0.80, 0.70), Color(0.55, 0.60, 0.50))
	var wing: Mesh = wb.commit(Assets.materials)
	for z in [-0.1, -0.02]:
		for s in [1.0, -1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(0.03 * s, 0.03, z)
			body.add_child(piv)
			var w := MeshInstance3D.new()
			w.mesh = wing
			w.scale.x = s
			piv.add_child(w)
			_wings.append(piv)
	var buzz := AudioStreamPlayer3D.new()
	buzz.stream = Sfx.stream("buzz")
	buzz.volume_db = -8.0
	buzz.max_distance = 18.0
	buzz.unit_size = 3.0
	buzz.autoplay = true
	root.add_child(buzz)
	return root


# --- The lightning -----------------------------------------------------------------

func strike() -> void:
	## The bolt hits the tree, which comes down away from you, its stump
	## burning. With no tree near enough, it hits the ground some way off.
	struck = true
	player._shake = 0.7
	if swamp.hud and swamp.hud.has_method("set_fade"):
		# A blinding flash over everything, slowly clearing to the sky.
		swamp.hud.set_fade(Color(1, 1, 1, 1))
		swamp.hud.fade_to(Color(1, 1, 1, 0), WHITE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if tree.is_empty():
		var yaw := player.rotation.y
		var at := player.global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * 40.0
		at.y = maxf(swamp.ground_height(at.x, at.z), 0.0)
		swamp.weather.strike(at, BOLT_TIME)
		return
	var top_y: float = tree.at.y + Chunk.TREES[tree.kind].height * tree.s * 0.9
	swamp.weather.strike(Vector3(tree.at.x, top_y, tree.at.z), BOLT_TIME)
	var away: Vector3 = tree.at - player.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	swamp.strike_tree(tree, away.normalized())
	var to: Vector3 = tree.at - player.global_position
	_face = atan2(-to.x, -to.z)


func finish() -> void:
	player.lie = 0.0
	player.frozen = false
	if struck and not tree.is_empty():
		Game.notify("Lightning has set a %s stump alight. Take an ember from it to start a fire of your own." % Chunk.TREES[tree.kind].name)
	queue_free()
