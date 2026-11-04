extends StaticBody3D
## A plant or deposit that yields items and regrows after a while.
## `regrow` is a range in game days; each harvest rolls the exact wait.
## Plants take days to weeks to grow back, logs and clay a couple of days.
## A planted kind with `fed_regrow` grows back in that many days instead if
## compost is worked in round it within FED_WITHIN of it being picked.
## A kind with `dig` can be dug up with a mattock (`dig_hits` swings): it is
## gone for good (Game.taken, so its chunk never makes it again), giving `dig`
## and, if it is ripe, its `dig_ripe` yield too.

const FEED_CUT := 0.3  # compost worked in round a growing plant cuts this much off the time it has left (plot.gd, stump.gd)
const FED_WITHIN := 1440.0  # a game day: compost this soon after picking a planted kind with `fed_regrow` gives that regrow time

const KINDS := {
	"seed_fern": {"name": "Seed Fern", "verb": "Gather seeds", "mesh": "seed_fern", "bare": "seed_fern_bare",
		"yield": {"seed": [2, 4], "frond": [0, 1]}, "regrow": [5.0, 5.0], "radius": 0.7, "height": 1.3,
		"dig": {"fern_root": 4}, "dig_ripe": "seed", "dig_hits": 2},
	# One grown from a planted seed or root (plot.gd): smaller yields, until
	# fertiliser comes.
	"planted_seed_fern": {"name": "Seed Fern", "verb": "Gather seeds", "mesh": "seed_fern", "bare": "seed_fern_bare",
		"yield": {"seed": [1, 2]}, "regrow": [5.0, 5.0], "fed_regrow": 2.5, "radius": 0.7, "height": 1.3,
		"dig": {"fern_root": 2}, "dig_ripe": "seed", "dig_hits": 2},
	"fern": {"name": "Fern", "verb": "Strip fern", "mesh": "fern_ripe", "bare": "fern_stripped",
		"yield": {"plant_fiber": [2, 3], "fiddlehead": [0, 2]}, "cut_bonus": "plant_fiber",
		"regrow": [30.0, 50.0], "radius": 0.6, "height": 0.5},
	# The fresh crown of young fronds and fiddleheads up top shows which tree
	# ferns can be cut (it is gone once cut).
	"tree_fern": {"name": "Tree Fern", "verb": "Cut fronds", "mesh": "tree_fern_crown", "bare": "",
		"yield": {"frond": [1, 2], "plant_fiber": [1, 2]}, "regrow": [3.0, 3.0], "radius": 0.6, "height": 1.5, "trunk_r": 0.45},
	"rotting_log": {"name": "Rotting Log", "verb": "Search log", "mesh": "rotting_log", "bare": "",
		"yield": {"grub": [1, 3], "tinder": [1, 2], "stick": [0, 2]}, "regrow": [1.5, 2.5],
		"keep": true, "radius": 0.5, "height": 0.4, "length": 4.4},
	"clay_bank": {"name": "Clay Bank", "verb": "Dig clay", "mesh": "clay_bank", "bare": "",
		"yield": {"clay": [2, 4]}, "regrow": [1.5, 2.5], "keep": true, "radius": 1.0, "height": 0.2},
}

var kind := ""
var uid := ""
var crown := 0.0   # tree fern: height of the crown above the base
var crown_scale := 1.0
var _mesh: MeshInstance3D
var _ready_time := 0.0
var _rng := RandomNumberGenerator.new()
var _dug := 0      # mattock swings into its roots so far


func setup(k: String, unique_id: String) -> Node3D:
	kind = k
	uid = unique_id
	return self


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var def: Dictionary = KINDS[kind]
	var cs := CollisionShape3D.new()
	if def.has("length"):
		var box := BoxShape3D.new()
		box.size = Vector3(def.length, def.radius * 2.0, def.radius * 2.0)
		cs.shape = box
	else:
		var cyl := CylinderShape3D.new()
		cyl.radius = def.radius
		cyl.height = def.height
		cs.shape = cyl
	cs.position.y = def.height * 0.5
	if crown > 0.0:
		# The crown is out of reach up top: cut it from the foot of the trunk,
		# from any side. Wrapped round the trunk so the trunk never hides it.
		var cyl := CylinderShape3D.new()
		cyl.radius = def.get("trunk_r", 0.45) * crown_scale + 0.3
		cyl.height = 2.2
		cs.shape = cyl
		cs.position.y = 1.1
	add_child(cs)
	if def.mesh != "":
		_mesh = MeshInstance3D.new()
		_mesh.visibility_range_end = 70.0
		if crown > 0.0:
			_mesh.position.y = crown
			_mesh.scale = Vector3.ONE * crown_scale
			_mesh.visibility_range_end = 110.0
		add_child(_mesh)
	_rng.seed = hash(uid)
	_ready_time = Game.harvested.get(uid, 0.0)
	_refresh()


func is_ready() -> bool:
	return Game.time >= _ready_time


func _refresh() -> void:
	if _mesh == null:
		return
	var def: Dictionary = KINDS[kind]
	if is_ready():
		_mesh.mesh = Assets.mesh(def.mesh)
		_mesh.visible = true
	elif def.bare != "":
		_mesh.mesh = Assets.mesh(def.bare)
	else:
		_mesh.visible = def.get("keep", false)


func growing() -> bool:
	## A plant growing back (logs and clay banks only fill up again).
	return not is_ready() and not kind in ["rotting_log", "clay_bank"]


func feed(_player: Node) -> bool:
	## Compost worked in round its roots: it grows back sooner. A planted kind
	## with `fed_regrow`, fed within FED_WITHIN of being picked (once per
	## picking), grows back `fed_regrow` days after it was picked instead.
	if not growing():
		return false
	var def: Dictionary = KINDS[kind]
	var rec: Dictionary = Game.plantings.get(uid, {})
	if def.has("fed_regrow") and rec.has("seeds_picked") and not rec.get("seeds_fed", false) \
			and Game.time - float(rec.seeds_picked) <= FED_WITHIN:
		_ready_time = minf(_ready_time, float(rec.seeds_picked) + float(def.fed_regrow) * Game.DAY_LENGTH)
		rec.seeds_fed = true
	else:
		_ready_time -= (_ready_time - Game.time) * FEED_CUT
	Game.harvested[uid] = _ready_time
	fed_note(_ready_time - Game.time)
	return true


static func feed_hint(left: float) -> String:
	## A growing plant's prompt with compost in hand.
	return "   (right-click to work compost in: %s left)" % days_text(left)


static func days_text(secs: float) -> String:
	if secs >= Game.DAY_LENGTH:
		return "%d days" % ceili(secs / Game.DAY_LENGTH)
	return "%d min" % maxi(ceili(secs / 60.0), 1)


static func fed_note(left: float) -> void:
	Sfx.play("rustle", -6.0)
	Game.notify("You work the compost in round its roots. It will be grown in %s." % days_text(left))


func regrow_time() -> float:
	## Seconds until it can be harvested again, rolled within the kind's range.
	var r: Array = KINDS[kind].regrow
	return _rng.randf_range(r[0], r[1]) * Game.DAY_LENGTH


func prompt(_player: Node) -> String:
	var def: Dictionary = KINDS[kind]
	if def.has("dig") and "dig" in Items.def(Game.inventory.held_id()).get("tags", []):
		return "%s: swing the mattock to dig it up, roots and all%s" % [def.name, "" if is_ready() else " (picked clean)"]
	if not is_ready():
		_refresh()
		if Game.inventory.held_id() == "compost" and growing():
			return "%s (picked clean)%s" % [def.name, feed_hint(_ready_time - Game.time)]
		return "%s (picked clean)" % def.name
	return "%s [E]" % def.verb


func interact(_player: Node) -> void:
	if not is_ready():
		return
	var def: Dictionary = KINDS[kind]
	var got := []
	for id in def.yield:
		var r: Array = def.yield[id]
		var n := _rng.randi_range(r[0], r[1]) * (2 if Game.plantings.get(uid, {}).get("fed", false) else 1)
		if def.get("cut_bonus", "") == id and Game.inventory.has_tag("cut"):
			n += 2
		if n > 0:
			var left: int = Game.inventory.add(id, n)
			if left > 0 and _player.world and _player.world.has_method("spawn_pickup"):
				_player.world.spawn_pickup(id, left, global_position + Vector3(0, 0.6, 0))
			got.append("%s x%d" % [Items.item_name(id), n])
			Game.picked.emit(id)
	Sfx.play("pickup", -8.0)
	Game.notify("Gathered " + ", ".join(got) if not got.is_empty() else "Found nothing useful.")
	_ready_time = Game.time + regrow_time()
	Game.harvested[uid] = _ready_time
	if def.has("fed_regrow") and Game.plantings.has(uid):
		# When it was picked, for compost worked in soon after (feed).
		Game.plantings[uid].seeds_picked = Game.time
		Game.plantings[uid].erase("seeds_fed")
	_refresh()


func dig() -> void:
	## A mattock swing into the roots. The last one digs the plant up for good:
	## its roots, and its ripe yield if it hadn't been picked.
	var def: Dictionary = KINDS[kind]
	if not def.has("dig"):
		return
	_dug += 1
	Sfx.play_at("chop", global_position, -4.0, 0.2)
	if _dug < int(def.get("dig_hits", 1)):
		Game.notify("You dig around the %s's roots (%d / %d)." % [def.name.to_lower(), _dug, def.dig_hits])
		return
	var got := {}
	for id in def.dig:
		got[id] = int(def.dig[id])
	if is_ready() and def.has("dig_ripe"):
		var r: Array = def.yield[def.dig_ripe]
		got[def.dig_ripe] = got.get(def.dig_ripe, 0) + _rng.randi_range(r[0], r[1])
	var words := []
	var world: Node = Game.player.world if Game.player else null
	for id in got:
		if got[id] <= 0:
			continue
		var left: int = Game.inventory.add(id, got[id])
		if left > 0 and world and world.has_method("spawn_pickup"):
			world.spawn_pickup(id, left, global_position + Vector3(0, 0.4, 0))
		words.append("%s x%d" % [Items.item_name(id), got[id]])
		Game.picked.emit(id)
	if Game.plantings.has(uid):
		Game.plantings.erase(uid)  # planted: gone, and the spot free again
	else:
		Game.taken[uid] = true
	Game.harvested.erase(uid)
	Sfx.play_at("thud", global_position, -6.0)
	Game.notify("You dig up the %s: %s." % [def.name.to_lower(), ", ".join(words)])
	queue_free()
