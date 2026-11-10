extends Node3D
## Something built in place, part by part, the way a house is (house.gd): a
## dock (dock.gd), a raft (raft.gd), a clay furnace (furnace.gd). It shows a
## holographic outline of what is still to come, and each part is built with
## steps clicked on the thing itself (work_spot.gd treats it as its `house`).
## Until it is finished, TEARDOWN_HITS blows of an axe or a mattock tear it
## down and leave what it took on the ground.
##
## A subclass gives its parts (parts(): [{id, verb, in, steps, log?, tools?,
## tool_tag?, stand?, face?}]), what they look like (_pieces) and their solid
## shapes (_shapes), and may hook _on_part and _on_complete.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")
const HouseScript := preload("res://src/world/house.gd")

const TEARDOWN_HITS := 3
const HIT_WINDOW := 4.0

var world: Node = null
var preview := false         # the plan shown while holding a blueprint
var built := {}              # part id -> {item id: n} it took
var working := ""            # the part being built right now, if any
var work_k := 0

var _solid: MeshInstance3D
var _ghost: MeshInstance3D
var _body: StaticBody3D
var _outline: StaticBody3D
var _hits := 0
var _hit_t := -INF
var _ok := true
var _shown_at := Transform3D()


func parts() -> Array:
	return []


func site_name() -> String:
	return "site"


func _ready() -> void:
	_solid = MeshInstance3D.new()
	add_child(_solid)
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.material_override = HouseScript.holo(true)
	add_child(_ghost)
	if preview:
		_rebuild()
		return
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.set_meta("hard", true)
	add_child(_body)
	_outline = StaticBody3D.new()
	_outline.collision_layer = 2
	_outline.collision_mask = 0
	add_child(_outline)
	_rebuild()


# --- State -----------------------------------------------------------------------------

func complete() -> bool:
	return built.size() >= parts().size()


func next_part() -> Dictionary:
	for p in parts():
		if not built.has(p.id):
			return p
	return {}


func part(id: String) -> Dictionary:
	for p in parts():
		if p.id == id:
			return p
	return {}


func wants_log() -> bool:
	return next_part().get("log", false)


func set_working(id: String, k: int) -> void:
	working = id
	work_k = k
	_rebuild()


func finish_part(id: String, used: Dictionary) -> void:
	built[id] = used.duplicate()
	working = ""
	work_k = 0
	_on_part(id)
	_rebuild()
	if complete():
		_on_complete()
	else:
		Game.notify("Done: %s. Next: %s." % [part(id).verb.to_lower(), next_part().verb.to_lower()])


func build_to(n: int) -> void:
	## Puts up the first n parts at once, as if built (dev worlds and tests).
	var all := parts()
	for i in mini(n, all.size()):
		var p: Dictionary = all[i]
		if built.has(p.id):
			continue
		var used: Dictionary = p.in.duplicate()
		if p.get("log", false):
			used["log"] = 1
		built[p.id] = used
		if is_inside_tree():
			_on_part(p.id)
	if is_inside_tree():
		_rebuild()
		if complete():
			_on_complete(false)


func _on_part(_id: String) -> void:
	pass


func _on_complete(_tell := true) -> void:
	pass


# --- Building (see work_spot.gd) --------------------------------------------------------

func recipe_for(p: Dictionary) -> Dictionary:
	var all := parts()
	return {"house": p.id, "out": "", "n": 0, "in": p.in, "tools": p.get("tools", {}), "log": p.get("log", false),
		"from": p.get("from", ""), "act": "steps", "steps": p.steps, "verb": p.verb,
		"label": "Part %d of %d of the %s" % [all.find(p) + 1, all.size(), site_name()], "how": p.get("how", "")}


func options(log_id: String, player: Node3D) -> Array:
	var p := next_part()
	if p.is_empty():
		return []
	var r := recipe_for(p)
	return [{"recipe": r, "missing": missing_for(r, log_id, player)}]


func missing_for(r: Dictionary, log_id: String, _player: Node3D) -> Array:
	var missing := []
	if r.get("log", false) and log_id == "":
		missing.append("a Calamites log, carried here in your arms")
	for id in r.in:
		var have: int = Game.inventory.count_as(id)
		if have < r.in[id]:
			missing.append("%d %s" % [r.in[id] - have, Items.item_name(id)])
	for id in r.get("tools", {}):
		if Game.inventory.count_as(id) < r.tools[id]:
			missing.append("a %s to work with" % Items.item_name(id))
	var tag: String = part(r.house).get("tool_tag", "")
	if tag != "" and not Game.inventory.has_tag(tag):
		missing.append("a %s to work with" % Items.TAG_TOOLS.get(tag, tag))
	return missing


func step_how(id: String, k: int) -> String:
	var p := part(id)
	var hows: Array = p.get("step_how", [])
	if hows.is_empty():
		return p.get("how", "")
	return hows[mini(k, hows.size() - 1)]


func step_sound(_id: String, _k: int) -> Array:
	return ["hit", -8.0]


func stand_point(p: Dictionary, _player: Node3D) -> Vector3:
	## Where you stand to build a part (global), or INF to stay where you are.
	if not p.has("stand"):
		return Vector3.INF
	var g := to_global(p.stand)
	g.y = maxf(_ground(g), _water() - 1.3)
	return g


func face_point(p: Dictionary) -> Vector3:
	return to_global(p.get("face", Vector3.ZERO))


func eye_height(_id: String, _player: Node3D) -> float:
	return 1.62


func marker(id: String, k: int) -> Vector3:
	## Where the glowing mark for step k of a part is (global).
	for p in _pieces(id, k):
		if p.s == k:
			return to_global(p.get("m", _centre(p)))
	return to_global(part(id).get("face", Vector3.ZERO))


func _ground(g: Vector3) -> float:
	var h: float = world.ground_height(g.x, g.z) if world else -INF
	return h if h > -INF else global_position.y


func _ground_local(at: Vector3) -> float:
	return _ground(to_global(Vector3(at.x, 0, at.z))) - global_position.y


func _water() -> float:
	return world.water_level() if world and world.has_method("water_level") else -INF


# --- The plan shown while holding a blueprint -------------------------------------------

func show_plan(at: Vector3, yaw: float, ok: bool) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), at)
	global_transform = t
	if t.origin.distance_to(_shown_at.origin) > 0.25 or absf(angle_difference(yaw, _shown_at.basis.get_euler().y)) > 0.08:
		_shown_at = t
		_rebuild()
	if ok != _ok:
		_ok = ok
		_ghost.material_override = HouseScript.holo(ok)


# --- Interaction ----------------------------------------------------------------------------

func prompt(player: Node) -> String:
	if preview or complete():
		return ""
	if player and player.hauling:
		return ""
	var p := next_part()
	var tags: Array = Items.def(Game.inventory.held_id()).get("tags", [])
	var tear := "   (hit it %d times with an axe or mattock to tear it down)" % TEARDOWN_HITS if "chop" in tags or "dig" in tags else ""
	return "%s: %s [E]   %d of %d parts built%s" % [site_name().capitalize(), p.verb.to_lower(), built.size(), parts().size(), tear]


func interact(_player: Node) -> void:
	if preview or complete() or world == null or not world.has_method("start_house_work"):
		return
	world.start_house_work(self)


func axe_hit() -> void:
	_hit()


func break_apart() -> void:
	_hit()


func can_tear_down() -> bool:
	return not preview and not complete()


func _hit() -> void:
	if not can_tear_down():
		return
	if Game.time - _hit_t > HIT_WINDOW:
		_hits = 0
	_hit_t = Game.time
	_hits += 1
	Sfx.play_at("chop", global_position, -4.0, 0.2)
	if _hits < TEARDOWN_HITS:
		var left := TEARDOWN_HITS - _hits
		Game.notify("You hack at the %s. %d more blow%s to tear it down." % [site_name(), left, "" if left == 1 else "s"])
		return
	tear_down()


func drop_point() -> Vector3:
	## Where what it took is left when it is torn down: at your feet.
	var p: Vector3 = Game.player.global_position if Game.player and is_instance_valid(Game.player) else global_position
	return p


func tear_down() -> void:
	## What was built comes apart and is left where you stand as the materials
	## it took (logs as logs).
	var got := {}
	for id in built:
		var used: Dictionary = built[id]
		for item in used:
			got[item] = got.get(item, 0) + int(used[item])
	var at := drop_point()
	var spots := 0
	if world:
		for item in got:
			if Items.def(item).get("carry", false):
				for k in got[item]:
					world.add_log(item, at + Vector3(1.2 + 0.4 * k, 0, 0.6), rotation.y, "calamites")
			elif world.has_method("pile_item"):
				world.pile_item(item, got[item], at + Vector3(-1.0 + (spots % 4) * 0.7, 0.3, -1.0 - (spots / 4) * 0.7))
				spots += 1
	var list := []
	for item in got:
		list.append("%s x%d" % [Items.item_name(item), got[item]])
	Sfx.play_at("hit", global_position, -2.0)
	Game.notify("You tear the %s down." % site_name() + (" Left beside you: " + ", ".join(list) + "." if not list.is_empty() else ""))
	_on_torn_down()
	queue_free()


func _on_torn_down() -> void:
	pass


# --- Looks and collision ------------------------------------------------------------------

func _rebuild() -> void:
	var sb := MeshBuilder.new()
	var gb := MeshBuilder.new()
	var done := complete()
	for p in parts():
		var k: int = p.steps if built.has(p.id) else (work_k if p.id == working else 0)
		for piece in _pieces(p.id, k):
			if piece.s < k:
				_draw(sb, piece)
			elif not done:
				_draw(gb, piece)
	_solid.mesh = sb.commit(Assets.materials) if not sb.is_empty() else null
	_ghost.mesh = gb.commit(Assets.materials) if not gb.is_empty() else null
	if preview:
		return
	for c in _body.get_children():
		c.queue_free()
	for p in parts():
		if built.has(p.id):
			for s in _shapes(p.id):
				_body.add_child(s)
	for c in _outline.get_children():
		c.queue_free()
	for s in _outline_shapes():
		_outline.add_child(s)


func _pieces(_id: String, _k: int) -> Array:
	return []


func _shapes(_id: String) -> Array:
	return []


func _outline_shapes() -> Array:
	## What you look at to press E on it.
	return []


func _box_shape(size: Vector3, centre: Vector3, basis := Basis()) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.transform = Transform3D(basis, centre)
	return cs


func _cyl_shape(r: float, a: Vector3, b: Vector3) -> CollisionShape3D:
	## An upright cylinder from a up to b.
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = maxf(b.y - a.y, 0.05)
	cs.shape = cyl
	cs.position = (a + b) * 0.5
	return cs


func _box(s: int, c: Vector3, size: Vector3, col: Color, slot := "wood", basis := Basis()) -> Dictionary:
	return {"s": s, "t": "box", "c": c, "size": size, "col": col, "slot": slot, "basis": basis}


func _cyl(s: int, a: Vector3, b: Vector3, r: float, col: Color, slot := "wood", r1 := -1.0, sides := 8, caps := true) -> Dictionary:
	return {"s": s, "t": "cyl", "a": a, "b": b, "r": r, "r1": r if r1 < 0.0 else r1, "col": col, "slot": slot, "sides": sides, "caps": caps}


func _blob(s: int, c: Vector3, size: Vector3, col: Color, slot := "stone") -> Dictionary:
	return {"s": s, "t": "blob", "c": c, "size": size, "col": col, "slot": slot}


func _lash(s: int, c: Vector3, axis: Vector3, r: float) -> Array:
	## A few turns of cord wound round something at c, along `axis`.
	var out := []
	for i in 3:
		var o := axis * (i - 1) * 0.035
		out.append(_cyl(s, c + o - axis * 0.01, c + o + axis * 0.01, r, Assets.CORD * (0.92 + 0.06 * i), "fiber", -1.0, 8, false))
	out[1].m = c
	return out


func _log_pieces(s: int, a: Vector3, b: Vector3, r: float, stripped := false) -> Array:
	## A Calamites log from a to b, with the joints of a horsetail stem.
	var look: Dictionary = Assets.LOG_LOOKS["calamites"]
	var col: Color = look.wood if stripped else look.bark
	var out := [_cyl(s, a, b, r, col, "wood" if stripped else "bark_calamites", r * 0.95, 10)]
	var n := int(a.distance_to(b) / 0.48)
	for i in range(1, n + 1):
		var c := a.lerp(b, i / float(n + 1))
		var d := (b - a).normalized() * 0.02
		out.append(_cyl(s, c - d, c + d, r + 0.012, col * 0.8, "wood", -1.0, 10, false))
	return out


func _centre(p: Dictionary) -> Vector3:
	match p.t:
		"box":
			return p.c + p.basis.y * p.size.y * 0.5
		"cyl":
			return (p.a + p.b) * 0.5
	return p.c


func _draw(b, p: Dictionary) -> void:
	match p.t:
		"box":
			b.box(p.c, p.size, p.col, p.basis, p.slot)
		"cyl":
			b.cylinder(p.a, p.b, p.r, p.r1, p.sides, p.col, Color(-1, 0, 0), p.slot, p.caps)
		"blob":
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(p.c)
			b.blob(p.c, p.size, 2, 6, p.col, rng, 0.2, p.slot)


func _shade(i: int) -> float:
	return 0.9 + 0.1 * sin(i * 1.7)


# --- Saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "built": built.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	built = {}
	var src: Dictionary = d.get("built", {})
	for p in parts():
		if not src.has(p.id) or not (src[p.id] is Dictionary):
			break  # parts go up in order
		var used := {}
		for item in src[p.id]:
			if Items.exists(item):
				used[item] = int(src[p.id][item])
		built[p.id] = used
	if is_inside_tree():
		_rebuild()
