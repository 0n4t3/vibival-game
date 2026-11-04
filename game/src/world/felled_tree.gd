extends StaticBody3D
## A felled tree lying where it fell, in one piece (group "felled"). It topples
## over from its stump when it is cut, then lies there. Kneeling at it with an
## axe cuts 2 m logs off the butt end (work_spot.gd) until what is left is
## short enough to be a log itself; the crown is cut away with the last one.
## Left untouched, it goes rotten after ROT_AFTER and can be searched like any
## rotting log, and it falls apart GONE_AFTER later. Once it has been cut into
## it no longer rots.
##
## Local space: the trunk runs up +Y from the origin (the cut end), so lying
## down the trunk points along `dir`.

const WoodLog := preload("res://src/world/wood_log.gd")
const Chunk := preload("res://src/world/chunk.gd")

const ROT_AFTER := 3.0 * 1440.0
const GONE_AFTER := 3.0 * 1440.0
const FALL_TIME := 2.4
const LOG_LEN := 2.0

var kind := ""
var s := 1.0               # the tree's scale
var lo := 0.0              # where the trunk now starts, in tree units up from its foot
var dir := Vector3.FORWARD # which way it fell (level)
var made := 0.0            # Game.time it fell
var touched := false       # cut into: it won't rot now
var searched := false      # rotten: already searched for grubs
var world: Node = null

var _fall := -1.0          # seconds into the fall, or -1 once it lies still
var _tilt := 0.0           # how far over it ends up (radians from upright)
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _tick := 0.0
var _rotten := false


func setup(k: String, scale: float, start: float, fall_dir: Vector3, w: Node) -> Node3D:
	kind = k
	s = scale
	lo = start
	dir = Vector3(fall_dir.x, 0, fall_dir.z).normalized()
	made = Game.time
	world = w
	return self


func _ready() -> void:
	add_to_group("felled")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.visibility_range_end = Settings.view_distance
	add_child(_mesh)
	_rotten = rotten()
	_rebuild()
	if _fall < 0.0:
		_tilt = _rest_tilt()
		_lie(1.0)


func def() -> Dictionary:
	return Chunk.TREES[kind]


func length() -> float:
	## Metres of trunk left.
	return maxf((def().height - lo) * s, 0.0)


func radius() -> float:
	## The trunk's radius at the cut end.
	return def().r * s * lerpf(1.0, 0.45, clampf(lo / def().height, 0.0, 1.0))


func rotten() -> bool:
	return not touched and Game.time > made + ROT_AFTER


func falling() -> bool:
	return _fall >= 0.0


func start_fall() -> void:
	## Topples over away from the axe.
	_fall = 0.0
	_tilt = _rest_tilt()
	_lie(0.0)
	Sfx.play_at("creak", global_position + Vector3(0, 2, 0), 0.0, 0.05)


func _rest_tilt() -> float:
	## Tipped over far enough for the trunk to lie on the ground at its tip.
	var L := length()
	var tip := global_position + dir * L
	var g: float = world.ground_height(tip.x, tip.z) if world else tip.y
	var drop := clampf((g + radius() * 0.5 - global_position.y) / maxf(L, 0.1), -0.6, 0.4)
	return PI * 0.5 - asin(drop)


func _lie(t: float) -> void:
	## Tipped over t of the way from upright to lying on the ground.
	basis = Basis(Vector3.UP.cross(dir).normalized(), _tilt * t)


func _process(delta: float) -> void:
	if _fall >= 0.0:
		_fall += delta
		var t := clampf(_fall / FALL_TIME, 0.0, 1.0)
		_lie(t * t)
		if t >= 1.0:
			_fall = -1.0
			Sfx.play_at("thud", global_position + dir * length() * 0.5, 4.0, 0.1)
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 2.0
	if touched:
		return
	if Game.time > made + ROT_AFTER + GONE_AFTER:
		queue_free()
		return
	if rotten() != _rotten:
		_rotten = rotten()
		_rebuild()


func _rebuild() -> void:
	## The trunk from its cut end up (and the crown, unless it has rotted).
	var start := lo
	_mesh.mesh = Assets.tree_part(kind, start, INF, _rotten, Color(0.55, 0.5, 0.42) if _rotten else Color(1, 1, 1))
	_mesh.scale = Vector3.ONE * s
	_mesh.position = Vector3(0, -start * s, 0)
	var L := length()
	(_shape.shape as BoxShape3D).size = Vector3(radius() * 2.0, L, radius() * 2.0)
	_shape.position = Vector3(0, L * 0.5, 0)


func cut_point() -> Vector3:
	## Where the next log comes off: LOG_LEN along from the cut end.
	return global_position + global_basis.y.normalized() * minf(LOG_LEN, length())


func logs_left() -> int:
	## 2 m logs still in it (the last, shorter piece included).
	return maxi(ceili(length() / LOG_LEN - 0.25), 1)


func cut_log() -> Node3D:
	## Chops a log off the cut end. The last piece becomes a log itself, and
	## the crown is cut away with it. Returns the log cut off (or null).
	touched = true
	var along := global_basis.y.normalized()
	if length() <= LOG_LEN * 1.25:
		var last := _final_piece()
		queue_free()
		return last
	var mid := global_position + along * LOG_LEN * 0.5
	var lg := _spawn_log("log", mid)
	lo += LOG_LEN / s
	global_position += along * LOG_LEN
	_tilt = _rest_tilt()
	_lie(1.0)
	_rebuild()
	return lg


func _final_piece() -> Node3D:
	var L := length()
	var mid := global_position + global_basis.y.normalized() * L * 0.5
	var lg: Node3D = null
	if L >= 1.0:
		lg = _spawn_log("log", mid)
	elif L >= 0.3:
		lg = _spawn_log("short_log", mid)
	if kind == "tree_fern":
		var n := randi_range(2, 4)
		var left: int = Game.inventory.add("frond", n)
		if left > 0 and world and world.has_method("pile_item"):
			world.pile_item("frond", left, mid + Vector3(0.8, 0.3, 0))
		Game.picked.emit("frond")
		Game.notify("You cut away the crown: Tree Fern Frond x%d." % n)
	return lg


func _spawn_log(id: String, at: Vector3) -> Node3D:
	if world == null or not world.has_method("add_log"):
		return null
	var yaw := atan2(-dir.z, dir.x)  # the log's length (X) along the trunk
	return world.add_log(id, at, yaw, kind)


func prompt(_player: Node) -> String:
	if falling():
		return ""
	if _rotten:
		return "A rotten %s log (searched)" % def().name if searched else "Search the rotten %s log [E]" % def().name
	return "Felled %s: kneel at the cut end to cut it into logs [C]" % def().name


func interact(player: Node) -> void:
	if _rotten and not searched:
		searched = true
		WoodLog.search_rotten(player, global_position + dir * length() * 0.5)


func to_dict() -> Dictionary:
	var p := global_position
	return {"kind": kind, "s": s, "lo": lo, "dir": [dir.x, dir.z], "made": made, "touched": touched,
			"searched": searched, "pos": [p.x, p.y, p.z]}


func from_dict(d: Dictionary) -> void:
	touched = bool(d.get("touched", false))
	searched = bool(d.get("searched", false))
	made = float(d.get("made", Game.time))
