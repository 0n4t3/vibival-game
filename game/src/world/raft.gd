extends "res://src/world/site.gd"
## A raft of six Calamites logs (group "rafts", Game.rafts), built part by
## part on a finished dock's slipway (dock.gd), then poled out over the water.
##
## Board it with E. Holding a raft pole, the movement keys pole it along, at
## any depth; it is slow, carries its way and is pushed by the wind. It
## grounds in the shallows, where you step off and wade. Stepping off at a
## finished dock ties it up there.
##
## It has no hold: sacks set down on it (Use) are lashed to its four corners
## and ride with it, and one hauled thing (a log, a pot, an anvil stone, a
## meteorite) set down on it rides in the middle. Their weight slows it,
## makes it ride lower and, packed to one side, makes it list.
##
## Out on open water a big amphibian may clamp its jaws on a corner
## (creature.gd "raft_bite"): the corner dips, and you have a few seconds to
## strike the biter with anything (a jab of the pole will do) before it drags
## the corner under and tips you in. Bites never damage the raft, never come
## within a finished dock's or an island's safe water, and never more than
## once in BITE_GAP seconds.
##
## It is light, dry Calamites and rides high: the logs barely dip into the
## water (RIDE), so it floats in all but the barest shallows.
##
## Local space: y = 0 is RIDE above the waterline, the bow is -Z.

const ThrownRock := preload("res://src/world/thrown_rock.gd")

const LOGS := 6
const LOG_GAP := 0.32
const HALF := Vector2(0.96, 1.0)     # half its width and length
const TOP := 0.24                    # the deck stands this high over the water
const STAND := Vector3(0, TOP, 0.42) # where you stand to pole
const CARGO_AT := Vector3(0, TOP, -0.38)
const SPOTS := [Vector3(-0.56, TOP, -0.62), Vector3(0.56, TOP, -0.62), Vector3(-0.56, TOP, 0.62), Vector3(0.56, TOP, 0.62)]
const CORNERS := [Vector3(-0.92, 0, -0.96), Vector3(0.92, 0, -0.96), Vector3(-0.92, 0, 0.96), Vector3(0.92, 0, 0.96)]
const CORNER_NAMES := ["front left", "front right", "back left", "back right"]
const CARGO_GROUPS := ["logs", "workbenches", "soup_pots", "vessels", "traps", "anvils", "meteorites"]
const SPEED := 3.0
const ACCEL := 2.0
const DRAG := 0.5
const TURN := 0.9
const DRAFT := 0.1                   # it grounds in water shallower than this (a little more when loaded)
const RIDE := 0.1                    # how high it floats: its origin is this far above the water
const LOAD_REF := 150.0              # kg of cargo that halves how fast it gets going
const WIND_PUSH := 0.035
const TIE_REACH := 7.0               # stepping off this near a finished dock's berth ties up there
const TIP := 0.5                     # radians of tilt that tips you in

const BITE_GAP := 20.0               # never bitten again sooner than this
const BITE_RATE := [0.02, 0.035]     # chance a second of a bite beginning, by day and by night
const BITE_WARN := 2.5               # seconds of ripples before the jaws close
const BITE_WINDOW := 3.5             # seconds to strike the biter
const BITE_SECOND := 2.0             # and a last, shorter chance once the corner is under
const BITE_DEPTH := 0.9              # only over water at least this deep

const PARTS := [
	{"id": "log_0", "verb": "Roll on the first deck log", "log": true, "in": {}, "steps": 3},
	{"id": "log_1", "verb": "Roll on the second deck log", "log": true, "in": {}, "steps": 3},
	{"id": "log_2", "verb": "Roll on the third deck log", "log": true, "in": {}, "steps": 3},
	{"id": "log_3", "verb": "Roll on the fourth deck log", "log": true, "in": {}, "steps": 3},
	{"id": "log_4", "verb": "Roll on the fifth deck log", "log": true, "in": {}, "steps": 3},
	{"id": "log_5", "verb": "Roll on the sixth deck log", "log": true, "in": {}, "steps": 3},
	{"id": "cross", "verb": "Lay the crosspieces", "in": {"board_calamites": 3}, "steps": 4,
		"how": "Click to lay three Calamites boards across the logs and square them up."},
	{"id": "lashing", "verb": "Lash the raft", "in": {"cordage": 8, "string": 4}, "steps": 8,
		"how": "Click along the crosspieces to lash every log to them with cordage, then cinch the lashings tight with string."},
	{"id": "line", "verb": "Tie on the mooring line", "in": {"cordage": 2}, "steps": 2,
		"how": "Click to tie a line to the raft and make it fast to the mooring post."},
	{"id": "launch", "verb": "Launch the raft", "in": {}, "steps": 3,
		"how": "Click to heave it down the rollers into the water."},
]

var tied := true
var rider: Node3D = null
var push := Vector3.ZERO     # which way the rider poles this frame (world, 0..1 long)
var vel := Vector3.ZERO
var grounded := false
var tilt := Vector2.ZERO     # x: the +X side dips, y: the stern (+Z) dips, in radians
var sacks: Array = [null, null, null, null]
var cargo: Node3D = null

var biter: Node3D = null     # the animal with its jaws on a corner
var bite_corner := -1        # the corner under attack (from the warning on), or -1
var bite_cd := BITE_GAP
var bite_t := 0.0            # seconds left: of the warning, then of the window
var bite_missed := false     # the first window ran out: the corner is under
var next_bite := -1.0        # tests: force the next bite roll (0..1)

var _tilt_v := Vector2.ZERO
var _yaw := 0.0
var _scan_t := 0.0
var _roll_t := 0.0
var _rng := RandomNumberGenerator.new()


func parts() -> Array:
	return PARTS


func site_name() -> String:
	return "raft"


func _ready() -> void:
	super()
	_rng.randomize()
	_yaw = rotation.y
	add_to_group("rafts")
	Game.rafts.append(self)


func _exit_tree() -> void:
	Game.rafts.erase(self)
	if rider and is_instance_valid(rider) and rider.riding == self:
		rider.riding = null


func _on_complete(tell := true) -> void:
	Game.crafted.emit("raft_built")
	if tell:
		Game.notify("The raft slides down the rollers and floats, tied up at the dock. Board it (E) with a raft pole in hand and pole out with the movement keys.")


# --- Building ----------------------------------------------------------------------------

func recipe_for(p: Dictionary) -> Dictionary:
	var r := super(p)
	if p.get("log", false):
		r.how = "Carry a Calamites log to the slipway in your arms and press E. Click to roll it down beside the others."
	return r


func step_how(id: String, k: int) -> String:
	if id.begins_with("log"):
		return ["Set the log on the rollers.", "Roll it down the slipway.", "Square it up against the others."][mini(k, 2)]
	match id:
		"cross":
			return "Lay a board across the logs (%d of 3)." % (k + 1) if k < 3 else "Square them up."
		"lashing":
			return "Lash the logs to the crosspieces (%d of 6)." % (k + 1) if k < 6 else "Cinch the lashings tight with string."
		"line":
			return "Tie the line to the raft." if k == 0 else "Make it fast to the mooring post."
		"launch":
			return "Heave it down the rollers."
	return ""


func step_sound(id: String, k: int) -> Array:
	if id.begins_with("log") or id == "launch":
		return ["step", -4.0] if k < 2 else ["splash", -6.0]
	return ["hit", -10.0] if id == "cross" else ["rustle", -8.0]


func face_point(_p: Dictionary) -> Vector3:
	return to_global(Vector3(0, 0.1, 0))


func marker(id: String, k: int) -> Vector3:
	if id.begins_with("log"):
		var i := int(id.substr(4))
		return to_global(Vector3(_log_x(i), 0.3, lerpf(-0.6, 0.6, k / 2.0)))
	if id == "launch":
		return to_global(Vector3(0, 0.4, lerpf(0.6, -0.6, k / 2.0)))
	return super(id, k)


func _log_x(i: int) -> float:
	return (i - (LOGS - 1) * 0.5) * LOG_GAP


func can_tear_down() -> bool:
	return not preview and rider == null and biter == null


func _on_torn_down() -> void:
	## Its sacks and whatever rode on it end up where you stand, not in the water.
	var at := drop_point()
	var k := 0
	for s in sacks:
		if s != null and is_instance_valid(s):
			s.global_position = Vector3(at.x + 0.8 * (k % 2) - 0.4, at.y - 0.05, at.z - 1.2 - 0.8 * (k / 2))
			s.rotation = Vector3(0, s.rotation.y, 0)
			k += 1
	if cargo and is_instance_valid(cargo):
		cargo.global_position = Vector3(at.x + 1.4, at.y, at.z - 1.0)
		cargo.rotation = Vector3(0, cargo.rotation.y, 0)


# --- Where things stand -------------------------------------------------------------------

func floor_top(p: Vector3) -> float:
	## The height of the deck at p, once it floats and p is up at it; else -INF.
	if preview or not complete():
		return -INF
	var l := to_local(p)
	if absf(l.x) > HALF.x or absf(l.z) > HALF.y or l.y < -0.8 or l.y > 3.0:
		return -INF
	return global_position.y + TOP


func over(p: Vector3, margin := 0.0) -> bool:
	var l := to_local(p)
	return absf(l.x) <= HALF.x + margin and absf(l.z) <= HALF.y + margin


func covers(p: Vector3, margin := 0.0) -> bool:
	return over(p, margin)


func stand_global() -> Vector3:
	return to_global(STAND)


func free_spot(near: Vector3) -> int:
	## The free sack spot nearest `near` (global), or -1 with all four taken.
	_drop_gone()
	var best := -1
	for i in SPOTS.size():
		if sacks[i] == null and (best < 0 or to_global(SPOTS[i]).distance_to(near) < to_global(SPOTS[best]).distance_to(near)):
			best = i
	return best


func lash_sack(s: Node3D, spot: int) -> void:
	sacks[spot] = s
	_carry()


func load_kg() -> float:
	## What rides on it: the sacks' contents and the hauled thing.
	var kg := 0.0
	for s in sacks:
		if s != null and is_instance_valid(s):
			kg += s.inv.weight() + Items.weight(s.sack_id)
	if cargo and is_instance_valid(cargo):
		kg += _cargo_kg()
	return kg


func _cargo_kg() -> float:
	if cargo.get("mass") != null:
		return float(cargo.mass)
	return 20.0


func draft() -> float:
	## Water shallower than this grounds it.
	return DRAFT + load_kg() / 2500.0


func rest_tilt() -> Vector2:
	## How it lists at rest under what is lashed to its corners.
	var t := Vector2.ZERO
	for i in SPOTS.size():
		var s = sacks[i]
		if s != null and is_instance_valid(s):
			var kg: float = s.inv.weight()
			t += Vector2(SPOTS[i].x, SPOTS[i].z) * kg / 500.0
	return t.limit_length(0.2)


func depth_at(p: Vector3) -> float:
	return _water() - _ground(p)


func _drop_gone() -> void:
	for i in sacks.size():
		if sacks[i] != null and (not is_instance_valid(sacks[i]) or sacks[i].is_queued_for_deletion()):
			sacks[i] = null
	if cargo != null and (not is_instance_valid(cargo) or cargo.is_queued_for_deletion() or cargo.get("hauled_by") != null):
		cargo = null


func _adopt() -> void:
	## Sacks and one hauled thing set down on the deck are lashed on, and ride
	## with it from then on (after a load, too: they were saved where they rode).
	_drop_gone()
	for s in get_tree().get_nodes_in_group("stashes"):
		if s in sacks or s.is_queued_for_deletion() or not over(s.global_position, 0.1) \
				or absf(s.global_position.y - (global_position.y + TOP)) > 0.7:
			continue
		var spot := free_spot(s.global_position)
		if spot >= 0:
			sacks[spot] = s
	if cargo == null:
		for g in CARGO_GROUPS:
			for n in get_tree().get_nodes_in_group(g):
				if n.is_queued_for_deletion() or n.get("hauled_by") != null or not over(n.global_position, -0.1) \
						or absf(n.global_position.y - (global_position.y + TOP)) > 0.9:
					continue
				cargo = n
				return


func _carry() -> void:
	## Keeps what rides on it where it is lashed, tilting with the deck.
	for i in sacks.size():
		var s = sacks[i]
		if s != null and is_instance_valid(s):
			s.global_position = to_global(SPOTS[i] + Vector3(0, -0.05, 0))
			s.rotation = Vector3(rotation.x, s.rotation.y, rotation.z)
	if cargo and is_instance_valid(cargo):
		cargo.global_position = to_global(CARGO_AT)


# --- Afloat --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if preview or not complete():
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_adopt()
	else:
		_drop_gone()
	if rider and (not is_instance_valid(rider) or rider.riding != self):
		rider = null
	if rider == null:
		push = Vector3.ZERO
	var mass := 1.0 + load_kg() / LOAD_REF
	if push.length() > 0.05 and tied:
		tied = false
		Game.notify("You cast off.")
	if tied:
		vel = Vector3.ZERO
	else:
		var deep := depth_at(global_position) > 1.6
		if push.length() > 0.05:
			vel = vel.move_toward(push * SPEED * (0.85 if deep else 1.0), ACCEL / mass * delta)
		else:
			vel *= maxf(1.0 - DRAG * delta, 0.0)
		if world and world.get("wind") is Vector3 and not grounded:
			vel += world.wind * WIND_PUSH / mass * delta
		var step := Vector3(vel.x, 0, vel.z) * delta
		if step.length() > 0.0001:
			var ahead := global_position + step + step.normalized() * 0.8
			if depth_at(global_position + step) < draft() or depth_at(ahead) < draft():
				if not grounded and rider and vel.length() > 0.4:
					Game.notify("The raft grounds in the shallows.")
				grounded = true
				vel = Vector3.ZERO
			else:
				grounded = false
				global_position += step
			if vel.length() > 0.4:
				_yaw = lerp_angle(_yaw, atan2(-vel.x, -vel.z), minf(TURN / mass * delta, 1.0))
	global_position.y = _water() + RIDE
	_update_bite(delta)
	# The deck eases back to how it lists at rest.
	var rest := rest_tilt()
	if bite_corner >= 0 and biter != null:
		var c: Vector3 = CORNERS[bite_corner]
		rest += Vector2(signf(c.x), signf(c.z)) * (0.3 if bite_missed else 0.17)
	_tilt_v += (rest - tilt) * 14.0 * delta
	_tilt_v *= maxf(1.0 - 3.0 * delta, 0.0)
	tilt += _tilt_v * delta
	rotation = Vector3(tilt.y, _yaw, -tilt.x)
	_carry()
	push = Vector3.ZERO


func out_on_water() -> bool:
	## Ridden away from the dock: no sleeping or saving here.
	return complete() and not tied


# --- Getting on and off ----------------------------------------------------------------------

func prompt(player: Node) -> String:
	if preview:
		return ""
	if not complete():
		return super(player)
	if player and player.riding == self:
		return "Step off the raft [E]%s" % ("" if _holds_pole() else "   (hold a raft pole to move it)")
	if player and player.hauling:
		return ""
	return "Board the raft [E]"


func interact(player: Node) -> void:
	if preview:
		return
	if not complete():
		super(player)
		return
	if player.riding == self:
		leave(player)
	else:
		board(player)


func _holds_pole() -> bool:
	return "pole" in Items.def(Game.inventory.held_id()).get("tags", [])


func board(player: Node3D) -> void:
	if rider != null or player.hauling or player.grabbed_by:
		return
	rider = player
	player.riding = self
	player.velocity = Vector3.ZERO
	player.global_position = stand_global()
	Sfx.play("step", -4.0)
	if not _holds_pole():
		Game.notify("You step onto the raft. Hold a raft pole to move it.")
	elif Game.hints_seen.get("raft", false) == false:
		Game.hints_seen["raft"] = true
		Game.notify("Pole the raft along with the movement keys. If jaws clamp on a corner, strike them: a jab of the pole will do. E steps off.")


func leave(player: Node3D) -> void:
	## Onto a finished dock close by (which ties it up), into the shallows
	## beside it, or over the side.
	if biter != null:
		Game.notify("Not with its jaws on the raft!")
		return
	var dock := _dock_near()
	rider = null
	player.riding = null
	vel = Vector3.ZERO
	if dock:
		tie_up(dock)
		player.global_position = dock.deck_point(global_position) + Vector3(0, 0.05, 0)
		Game.notify("You tie the raft up at the dock.")
	else:
		var best := Vector3.INF
		for i in 12:
			var a := TAU * i / 12.0
			var q := global_position + Vector3(cos(a), 0, sin(a)) * (HALF.y + 0.9)
			var g := _ground(q)
			if not best.is_finite() or g > best.y:
				best = Vector3(q.x, g, q.z)
		player.global_position = Vector3(best.x, maxf(best.y, _water() - 1.3) + 0.05, best.z)
		if depth_at(best) > 1.25:
			Game.notify("You slip over the side into deep water.")
	Sfx.play("step", -4.0)


func _dock_near() -> Node3D:
	for d in Game.docks:
		if is_instance_valid(d) and d.complete() and d.berth().distance_to(global_position) < TIE_REACH:
			return d
	return null


func tie_up(dock: Node3D) -> void:
	tied = true
	grounded = false
	vel = Vector3.ZERO
	global_position = dock.berth()
	_yaw = dock.rotation.y
	rotation.y = _yaw
	_carry()


func tip_in(player: Node3D) -> void:
	## The corner goes under and you with it.
	rider = null
	player.riding = null
	var c: Vector3 = CORNERS[maxi(bite_corner, 0)]
	var at := to_global(c * 1.5)
	player.global_position = Vector3(at.x, _water() - 1.2, at.z)
	player.velocity = Vector3.ZERO
	Sfx.play_at("splash", at, 2.0)


# --- Bites -------------------------------------------------------------------------------------

func corner_global(i: int) -> Vector3:
	var g := to_global(CORNERS[i])
	g.y = _water()
	return g


func bite_chance() -> float:
	## The chance a second of a bite beginning, out here, now.
	if rider == null or tied or grounded or bite_cd > 0.0 or bite_corner >= 0 or not Game.hostile():
		return 0.0
	if Game.safe(global_position) or depth_at(global_position) < BITE_DEPTH:
		return 0.0
	if world and float(world.get("_frenzy_left")) > 0.0:
		return 0.0  # a baitbox off the side has them all busy
	var c: float = BITE_RATE[1 if Game.is_night() else 0]
	if Game.inventory.count("raw_meat") > 0 or rider.vitals.bleeding():
		c *= 1.5
	return c


func _update_bite(delta: float) -> void:
	bite_cd = maxf(bite_cd - delta, 0.0)
	if bite_corner < 0:
		_roll_t += delta
		if _roll_t >= 1.0:
			_roll_t = 0.0
			var roll := next_bite if next_bite >= 0.0 else _rng.randf()
			if roll < bite_chance():
				next_bite = -1.0
				warn_bite(_rng.randi() % CORNERS.size())
		return
	if Game.safe(global_position) or rider == null:
		end_bite(false)  # it breaks off at the edge of safe water
		return
	bite_t -= delta
	if biter == null:
		# The warning: rings spreading round a corner, a dark shape rising.
		if int(bite_t * 2.0) != int((bite_t + delta) * 2.0) and world:
			ThrownRock.ripple(world, corner_global(bite_corner))
		if bite_t <= 0.0:
			_bite()
		return
	if not is_instance_valid(biter) or biter.dead:
		end_bite(true)
		return
	if bite_t > 0.0:
		return
	if not bite_missed:
		bite_missed = true
		bite_t = BITE_SECOND
		_tilt_v += Vector2(signf(CORNERS[bite_corner].x), signf(CORNERS[bite_corner].z)) * 1.2
		if rider:
			rider.shake(0.8)
		Sfx.play_at("splash", corner_global(bite_corner), 2.0)
		Game.notify("It drags the %s corner under! Strike it!" % CORNER_NAMES[bite_corner])
		return
	# Held too long: over you go, and it has you.
	var b := biter
	var p := rider
	tip_in(p)
	biter = null
	bite_corner = -1
	bite_cd = BITE_GAP
	b.end_raft_bite(false)
	Game.notify("The raft tips and you go into the water!")
	if Game.hostile() and not p.vitals.dead:
		b.attack_now(p)


func warn_bite(corner: int) -> void:
	bite_corner = corner
	biter = null
	bite_missed = false
	bite_t = BITE_WARN
	if world:
		ThrownRock.ripple(world, corner_global(corner))
	Game.notify("Rings spread on the water. A dark shape is circling the raft.")


func _bite() -> void:
	## Jaws clamp on the corner: the nearest big amphibian lying idle, or one
	## that was following unseen.
	var at := corner_global(bite_corner)
	var b: Node3D = null
	for c in Game.creatures:
		if is_instance_valid(c) and not c.dead and c.def.behavior in ["ambusher", "lurker"] and c.state in ["hide", "lurk"] \
				and c.global_position.distance_to(at) < 45.0 and (b == null or c.global_position.distance_to(at) < b.global_position.distance_to(at)):
			b = c
	if b == null and world and world.has_method("spawn_amphibian"):
		b = world.spawn_amphibian("uranocentrodon", "hide", Vector3(at.x, _ground(at), at.z), Vector3(at.x, _ground(at), at.z))
		b.home = b.global_position
	if b == null:
		end_bite(false)
		return
	biter = b
	bite_missed = false
	bite_t = BITE_WINDOW
	b.start_raft_bite(self, bite_corner)
	_tilt_v += Vector2(signf(CORNERS[bite_corner].x), signf(CORNERS[bite_corner].z)) * 1.0
	if rider:
		rider.shake(0.6)
	Sfx.play_at("roar", at, 2.0, 0.05)
	Sfx.play_at("splash", at, 2.0)
	Game.notify("Jaws clamp on the %s corner! Strike it before it drags you under!" % CORNER_NAMES[bite_corner])


func bite_hit(c: Node3D) -> void:
	## The biter was struck in time: it lets go.
	if c != biter:
		return
	end_bite(true)
	Game.notify("It lets go and sinks away. The raft rights itself.")
	Game.crafted.emit("raft_bite_beaten")


func end_bite(struck: bool) -> void:
	var b := biter
	biter = null
	bite_corner = -1
	bite_missed = false
	bite_cd = BITE_GAP
	if b and is_instance_valid(b) and not b.dead:
		b.end_raft_bite(struck)


# --- Looks -------------------------------------------------------------------------------------

func _outline_shapes() -> Array:
	return [_box_shape(Vector3(HALF.x * 2.0, 0.5, HALF.y * 2.0), Vector3(0, 0.1, 0))]


func _pieces(id: String, _k: int) -> Array:
	var out := []
	var cal: Color = Items.def("board_calamites").color
	if id.begins_with("log"):
		var i := int(id.substr(4))
		var x := _log_x(i)
		var stripped: bool = built.get(id, {}).has("log_stripped")
		out.append_array(_log_pieces(0, Vector3(x, 0.04, -HALF.y), Vector3(x, 0.04, HALF.y), Assets.LOG_R, stripped))
		return out
	match id:
		"cross":
			for j in 3:
				out.append(_box(j, Vector3(0, 0.2, (j - 1) * 0.72), Vector3(HALF.x * 2.0, 0.045, 0.2), cal * _shade(j)))
		"lashing":
			for j in 6:
				var x := _log_x(j)
				for z in [-0.72, 0.72]:
					out.append_array(_lash(j, Vector3(x, 0.1, z), Vector3.BACK, Assets.LOG_R + 0.03))
			out.append_array(_lash(6, Vector3(_log_x(0), 0.1, 0), Vector3.BACK, Assets.LOG_R + 0.035))
			out.append_array(_lash(7, Vector3(_log_x(5), 0.1, 0), Vector3.BACK, Assets.LOG_R + 0.035))
		"line":
			out.append(_cyl(0, Vector3(-HALF.x + 0.05, 0.22, -HALF.y + 0.1), Vector3(-HALF.x - 0.5, 0.3, -HALF.y - 0.3), 0.012, Assets.CORD, "fiber", -1.0, 5))
			out.append_array(_lash(1, Vector3(-HALF.x + 0.08, 0.22, -HALF.y + 0.12), Vector3.UP, 0.05))
		"launch":
			for j in 3:
				out.append({"s": j, "t": "cyl", "a": Vector3(0, 0.26, 0.6 - j * 0.6), "b": Vector3(0, 0.262, 0.6 - j * 0.6), "r": 0.001, "r1": 0.001,
						"col": cal, "slot": "wood", "sides": 3, "caps": false})
	return out


# --- Saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := super()
	d["yaw"] = _yaw
	d["tied"] = tied
	return d


func from_dict(d: Dictionary) -> void:
	super(d)
	_yaw = float(d.get("yaw", 0.0))
	rotation = Vector3(0, _yaw, 0)
	tied = bool(d.get("tied", true))
