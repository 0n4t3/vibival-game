extends "res://src/world/site.gd"
## A dock (group "docks", Game.docks), put up from a Dock Blueprint (items.gd
## `blueprint` "dock"). It starts on the bank and runs straight out over the
## water, built part by part like a house: a land post and four Calamites
## piles pounded in with a river stone (the piles while standing in the
## water), sharpened stakes lashed round the piles under the water, stringers,
## the deck, a slipway and a mooring post.
##
## Once finished, no big amphibian comes for you on it or in the water right
## round it (Game.dock_safe), nor anywhere up to LAND_GUARD behind it on the
## bank (Game.dock_keeps_out): they won't lie among the spiked piles. Until
## then it protects nothing. A finished dock marks out a raft (raft.gd) on
## its slipway.
##
## Local space: y = 0 is the top of the deck, the land end is at z = 0 and the
## dock runs out along -Z; the slipway and the raft's berth are on the +X side
## of its far end.

const LEN := 9.0
const HALF_W := 0.9
const DECK_H := 0.5            # the deck stands this high over the water
const GUARD := 7.0             # the safe water reaches this far past the end and to each side
const LAND_GUARD := 30.0       # and no water predator comes this far behind it, up the bank
const SPACING := 14.0
const PILE_R := 0.14
const SINK := 0.4
const POST := Vector3(0, 0, -0.25)
const PILES := [Vector3(-0.75, 0, -3.5), Vector3(0.75, 0, -3.5), Vector3(-0.75, 0, -7.6), Vector3(0.75, 0, -7.6)]
const BERTH := Vector3(2.25, -DECK_H, -7.0)   # where a raft is built, and lies tied up
const MOORING := Vector3(0.78, 0, -8.6)
const SHALLOW := 0.2           # the far end needs at least this much water (rafts ride high: Raft.DRAFT)
const DEEP := 4.0              # and no more than this, for the piles to reach the bottom

const PARTS := [
	{"id": "post", "verb": "Set the land post", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5,
		"how": "Carry a Calamites log here in your arms and press E. Click to stand it in its hole, then pound it in with a river stone."},
	{"id": "pile_0", "verb": "Drive the near left pile", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5,
		"how": "Carry a Calamites log out into the water and press E. Click to stand it up, then pound it into the bottom with a river stone. Nothing protects you out here: a baitbox thrown along the shore keeps them busy."},
	{"id": "pile_1", "verb": "Drive the near right pile", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5,
		"how": "Carry a Calamites log out into the water and press E. Click to stand it up, then pound it into the bottom with a river stone."},
	{"id": "pile_2", "verb": "Drive the far left pile", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5,
		"how": "Carry a Calamites log out into the water and press E. Click to stand it up, then pound it into the bottom with a river stone."},
	{"id": "pile_3", "verb": "Drive the far right pile", "log": true, "in": {}, "tools": {"stone": 1}, "steps": 5,
		"how": "Carry a Calamites log out into the water and press E. Click to stand it up, then pound it into the bottom with a river stone."},
	{"id": "spikes", "verb": "Spike the piles", "in": {"stick": 16, "cordage": 8}, "tool_tag": "cut", "steps": 8,
		"stand": Vector3(1.9, 0, -5.5), "face": Vector3(0.0, -0.2, -5.5),
		"how": "Click each pile to sharpen four sticks with your blade and lash them round it under the water, points out. Big amphibians won't lie among them: this is what makes a finished dock safe."},
	{"id": "stringers", "verb": "Lash on the stringers", "in": {"board_calamites": 4, "cordage": 4}, "steps": 6,
		"stand": Vector3(0, 0, 1.0), "face": Vector3(0, -0.1, -3.0),
		"how": "Click to lay Calamites boards along the tops of the piles, then lash them down with cordage."},
	{"id": "deck", "verb": "Lay the deck", "in": {"board_tree_fern": 12, "cordage": 6}, "steps": 9,
		"stand": Vector3(0, 0, 1.0), "face": Vector3(0, 0, -3.5),
		"how": "Click to lay tree fern boards across the stringers, then tie them down with cordage. You can walk on it from here on."},
	{"id": "slipway", "verb": "Build the slipway", "in": {"branch": 2, "board_calamites": 4, "cordage": 2}, "steps": 6,
		"stand": Vector3(0, 0, -6.4), "face": Vector3(1.7, -0.4, -7.0),
		"how": "Click to set two rails of Calamites board sloping down into the water beside the end of the dock, brace them, lay two branches across as rollers and lash it all down. A raft is built on it."},
	{"id": "mooring", "verb": "Set the mooring post", "in": {"branch": 1, "cordage": 2}, "steps": 3,
		"stand": Vector3(0, 0, -7.5), "face": Vector3(0.78, 0.3, -8.6),
		"how": "Click to lash a stout branch upright to the far pile and wind a mooring line round it."},
]


func parts() -> Array:
	return PARTS


func site_name() -> String:
	return "dock site"


static func ground_points(origin: Vector3, yaw: float) -> Array:
	## Where the ground matters to a dock whose land end is at `origin`: the
	## land end, under each pile, and at the far end.
	var out := []
	var basis := Basis(Vector3.UP, yaw)
	for p in [Vector3(0, 0, 0.3), POST] + PILES + [Vector3(0, 0, -LEN + 0.4), BERTH]:
		out.append(origin + basis * Vector3(p.x, 0, p.z))
	return out


func _ready() -> void:
	super()
	if preview:
		return
	add_to_group("docks")
	Game.docks.append(self)


func _exit_tree() -> void:
	Game.docks.erase(self)


func _on_complete(tell := true) -> void:
	Game.crafted.emit("dock_built")
	if tell:
		Game.notify("Your dock is finished. Nothing will come for you on it or in the water right round it. A raft is marked out on the slipway: bring six Calamites logs.")
	if world and world.has_method("raft_at_dock") and world.raft_at_dock(self) == null:
		world.add_raft(berth(), rotation.y)


func berth() -> Vector3:
	## Where a raft lies at this dock (global, at the waterline).
	var g := to_global(BERTH)
	g.y = _water()
	return g


func deck_point(p: Vector3) -> Vector3:
	## The nearest point on the deck to p (global).
	var l := to_local(p)
	return to_global(Vector3(clampf(l.x, -HALF_W + 0.3, HALF_W - 0.3), 0.0, clampf(l.z, -LEN + 0.4, -0.3)))


# --- Where things stand -------------------------------------------------------------------

func floor_top(p: Vector3) -> float:
	## The height of the deck at p, if it is built and p is up at it; else -INF.
	if preview or not built.has("deck"):
		return -INF
	var l := to_local(p)
	if absf(l.x) > HALF_W + 0.02 or l.z < -LEN - 0.02 or l.z > 0.32 or l.y < -0.8 or l.y > 3.0:
		return -INF
	return global_position.y


func on_deck(p: Vector3) -> bool:
	return floor_top(p) > -INF and absf(p.y - global_position.y) < 0.5


func guards(p: Vector3) -> bool:
	## Whether p is on the finished dock or in the water in front of it and to
	## each side, where nothing comes for you.
	if preview or not complete():
		return false
	var l := to_local(p)
	return absf(l.x) <= HALF_W + GUARD and l.z >= -LEN - GUARD and l.z <= 1.0


func keeps_out(p: Vector3) -> bool:
	## Whether a finished dock keeps the water predators away from p: the
	## water GUARD past its end and to each side, and LAND_GUARD behind it,
	## so stepping off onto the bank is safe too.
	if preview or not complete():
		return false
	var l := to_local(p)
	return absf(l.x) <= HALF_W + GUARD and l.z >= -LEN - GUARD and l.z <= LAND_GUARD


func way_out(p: Vector3) -> Vector3:
	## The nearest point just past the edge of keeps_out on the water side
	## (past the far end or off either side), for a predator caught inside.
	var l := to_local(p)
	var side := HALF_W + GUARD + 1.0
	var to_side := side - absf(l.x)
	var to_end := l.z + LEN + GUARD + 1.0
	var out := Vector3(signf(l.x if l.x != 0.0 else 1.0) * side, l.y, l.z) if to_side < to_end \
			else Vector3(l.x, l.y, -LEN - GUARD - 1.0)
	return to_global(out)


func covers(p: Vector3, margin := 0.0) -> bool:
	var l := to_local(p)
	return absf(l.x) <= HALF_W + margin and l.z >= -LEN - margin and l.z <= 0.5 + margin


func stand_point(p: Dictionary, player: Node3D) -> Vector3:
	var local := Vector3.INF
	if p.id == "post":
		local = POST + Vector3(0, 0, 1.2)
	elif p.id.begins_with("pile"):
		var s: Vector3 = PILES[int(p.id.substr(5))]
		local = s + Vector3(signf(s.x) * 1.0, 0, 0)
	elif p.has("stand"):
		local = p.stand
	if not local.is_finite():
		return Vector3.INF
	var g := to_global(local)
	if floor_top(Vector3(g.x, global_position.y, g.z)) > -INF:
		g.y = global_position.y  # up on the deck
	else:
		g.y = maxf(_ground(g), _water() - 1.3)
	return g


func face_point(p: Dictionary) -> Vector3:
	if p.id == "post":
		return to_global(POST + Vector3(0, -0.5, 0))
	if p.id.begins_with("pile"):
		return to_global(PILES[int(p.id.substr(5))] + Vector3(0, -0.4, 0))
	return super(p)


func step_how(id: String, k: int) -> String:
	if id == "post" or id.begins_with("pile"):
		return "Stand the log up." if k == 0 else "Pound it in with the river stone (%d of 4)." % k
	match id:
		"spikes":
			return "Sharpen stakes and lash them round the pile (%d of 8)." % (k + 1)
		"stringers":
			return "Lay a board along the piles (%d of 4)." % (k + 1) if k < 4 else "Lash the stringers down."
		"deck":
			return "Lay boards across the stringers (%d of 6)." % (k + 1) if k < 6 else "Tie the deck down."
		"slipway":
			return ["Set a rail.", "Set the other rail.", "Brace the rails.", "Brace the rails.", "Lay the rollers.", "Lash it down."][mini(k, 5)]
		"mooring":
			return "Lash the post upright." if k == 0 else "Wind the mooring line round it."
	return ""


func step_sound(id: String, k: int) -> Array:
	if id == "post" or id.begins_with("pile"):
		return ["step", -4.0] if k == 0 else ["hit", -2.0]
	if id == "spikes":
		return ["rustle", -6.0]
	return ["hit", -10.0] if k < 4 else ["rustle", -8.0]


func marker(id: String, k: int) -> Vector3:
	if id == "post" or id.begins_with("pile"):
		var s: Vector3 = POST if id == "post" else PILES[int(id.substr(5))]
		return to_global(Vector3(s.x, _lift(k) + (0.9 if k == 0 else 0.08), s.z))
	return super(id, k)


func _lift(k: int) -> float:
	## How far a pile still sticks up past where it ends after k steps.
	return [0.0, 0.6, 0.45, 0.3, 0.15, 0.0][clampi(k, 0, 5)]


# --- Interaction ----------------------------------------------------------------------------

func prompt(player: Node) -> String:
	if preview:
		return ""
	if not complete():
		return super(player)
	if world and world.has_method("raft_at_dock") and world.raft_at_dock(self) == null:
		return "Mooring post: mark out a new raft on the slipway [E]"
	return ""


func interact(player: Node) -> void:
	if preview:
		return
	if not complete():
		super(player)
		return
	if world and world.has_method("raft_at_dock") and world.raft_at_dock(self) == null:
		world.add_raft(berth(), rotation.y)
		Sfx.play("rustle", -4.0)
		Game.notify("You mark out a raft on the slipway. Bring six Calamites logs, carried here in your arms.")


# --- Looks and collision ------------------------------------------------------------------

func _outline_shapes() -> Array:
	if complete():
		return [_cyl_shape(0.22, MOORING + Vector3(0, -0.1, 0), MOORING + Vector3(0, 0.9, 0))]
	var out := [_box_shape(Vector3(HALF_W * 2.0, 0.9, LEN), Vector3(0, 0.15, -LEN * 0.5))]
	for s in [POST] + PILES:
		var g := _ground_local(s)
		out.append(_cyl_shape(0.35, Vector3(s.x, g, s.z), Vector3(s.x, 0.1, s.z)))
	return out


func _shapes(id: String) -> Array:
	if id == "post" or id.begins_with("pile"):
		var s: Vector3 = POST if id == "post" else PILES[int(id.substr(5))]
		var g := _ground_local(s)
		return [_cyl_shape(PILE_R, Vector3(s.x, g - SINK, s.z), Vector3(s.x, -0.06, s.z))]
	match id:
		"deck":
			return [_box_shape(Vector3(HALF_W * 2.0, 0.12, LEN + 0.3), Vector3(0, -0.06, (-LEN + 0.3) * 0.5))]
		"mooring":
			return [_cyl_shape(0.07, MOORING, MOORING + Vector3(0, 0.8, 0))]
	return []


func _pieces(id: String, k: int) -> Array:
	var out := []
	var fern: Color = Items.def("board_tree_fern").color
	var cal: Color = Items.def("board_calamites").color
	var stick: Color = Items.def("stick").color
	if id == "post" or id.begins_with("pile"):
		var s: Vector3 = POST if id == "post" else PILES[int(id.substr(5))]
		var g := _ground_local(s)
		var lift := _lift(k)
		var stripped: bool = built.get(id, {}).has("log_stripped")
		out.append_array(_log_pieces(0, Vector3(s.x, g - SINK + lift, s.z), Vector3(s.x, -0.1 + lift, s.z), PILE_R, stripped))
		return out
	match id:
		"spikes":
			# Four sharpened stakes round each pile, just under the water, points out.
			var y := -DECK_H - 0.22
			for i in 4:
				var s: Vector3 = PILES[i]
				for j in 4:
					var a := PI * 0.25 + j * PI * 0.5
					var d := Vector3(cos(a), 0, sin(a))
					var base := Vector3(s.x, y - 0.12, s.z) + d * 0.1
					out.append({"s": i * 2 + j / 2, "t": "cyl", "a": base, "b": base + d * 0.62 + Vector3(0, 0.2, 0), "r": 0.03, "r1": 0.004,
							"col": stick * (0.9 + 0.05 * j), "slot": "wood", "sides": 5, "caps": true, "m": Vector3(s.x, -0.15, s.z)})
				out.append_array(_lash(i * 2 + 1, Vector3(s.x, y - 0.1, s.z), Vector3.UP, PILE_R + 0.02))
		"stringers":
			for i in 4:
				var sx := -0.75 if i % 2 == 0 else 0.75
				var z0 := 0.1 if i < 2 else -4.6
				out.append(_box(i, Vector3(sx, -0.14, z0 - 2.3), Vector3(0.14, 0.1, 4.7), cal * _shade(i)))
			out.append_array(_lash(4, Vector3(-0.75, -0.1, -3.5), Vector3.BACK, 0.17))
			out.append_array(_lash(4, Vector3(0.75, -0.1, -3.5), Vector3.BACK, 0.17))
			out.append_array(_lash(5, Vector3(-0.75, -0.1, -7.6), Vector3.BACK, 0.17))
			out.append_array(_lash(5, Vector3(0.75, -0.1, -7.6), Vector3.BACK, 0.17))
		"deck":
			var n := 24
			var depth := (LEN + 0.3) / n
			for j in n:
				out.append(_box(j * 6 / n, Vector3(0, -0.03, 0.3 - (j + 0.5) * depth), Vector3(HALF_W * 2.0, 0.06, depth - 0.012), fern * _shade(j)))
			var ties := [Vector3(-0.75, -0.02, -1.5), Vector3(0.75, -0.02, -5.0), Vector3(-0.75, -0.02, -8.2)]
			for c in 3:
				out.append_array(_lash(6 + c, ties[c], Vector3.BACK, 0.1))
		"slipway":
			# Two rails sloping from the edge of the deck down into the water.
			var top := Vector3(HALF_W, -0.05, 0)
			var foot := Vector3(BERTH.x + 0.9, -DECK_H - 0.25, 0)
			var d := foot - top
			var basis := Basis(Vector3.BACK, atan2(d.y, d.x))
			for i in 2:
				var z := BERTH.z + (-0.7 if i == 0 else 0.7)
				out.append(_box(i, (top + foot) * 0.5 + Vector3(0, 0, z), Vector3(d.length(), 0.06, 0.2), cal * _shade(i), "wood", basis))
			for i in 2:
				var x := lerpf(top.x, foot.x, 0.3 + 0.4 * i)
				var y := lerpf(top.y, foot.y, 0.3 + 0.4 * i) - 0.05
				out.append(_box(2 + i, Vector3(x, y, BERTH.z), Vector3(0.18, 0.05, 1.7), cal * _shade(i + 2)))
			for i in 2:
				var x := lerpf(top.x, foot.x, 0.45 + 0.3 * i)
				var y := lerpf(top.y, foot.y, 0.45 + 0.3 * i) + 0.07
				var roller := _cyl(4, Vector3(x, y, BERTH.z - 0.85), Vector3(x, y, BERTH.z + 0.85), 0.05, Items.def("branch").color)
				out.append(roller)
			out.append_array(_lash(5, Vector3(HALF_W, -0.05, BERTH.z), Vector3.BACK, 0.09))
		"mooring":
			out.append(_cyl(0, MOORING + Vector3(0, -0.3, 0), MOORING + Vector3(0, 0.8, 0), 0.06, Items.def("branch").color))
			out.append_array(_lash(1, MOORING + Vector3(0, 0.1, 0), Vector3.UP, 0.08))
			out.append_array(_lash(2, MOORING + Vector3(0, 0.55, 0), Vector3.UP, 0.08))
	return out
