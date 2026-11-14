extends "res://src/world/scene_base.gd"
## The Carboniferous swamp: streams terrain chunks around the player, runs the
## day/night cycle and weather, spawns fauna, handles sleeping and saving, and
## shows contextual hints.

const Terrain := preload("res://src/world/terrain.gd")
const Chunk := preload("res://src/world/chunk.gd")
const Creature := preload("res://src/creatures/creature.gd")
const Campfire := preload("res://src/world/campfire.gd")
const Stash := preload("res://src/world/stash.gd")
const Weather := preload("res://src/world/weather.gd")
const DebugPanel := preload("res://src/ui/debug_panel.gd")
const Guts := preload("res://src/world/guts.gd")
const ThrownRock := preload("res://src/world/thrown_rock.gd")
const FelledTree := preload("res://src/world/felled_tree.gd")
const Intro := preload("res://src/world/intro.gd")
const WoodLog := preload("res://src/world/wood_log.gd")
const Stack := preload("res://src/world/stack.gd")
const Workbench := preload("res://src/world/workbench.gd")
const SoupPot := preload("res://src/world/soup_pot.gd")
const FermentVessel := preload("res://src/world/ferment_vessel.gd")
const House := preload("res://src/world/house.gd")
const Plot := preload("res://src/world/plot.gd")
const Compost := preload("res://src/world/compost.gd")
const Trap := preload("res://src/world/trap.gd")
const Baitbox := preload("res://src/world/baitbox.gd")
const Bedroll := preload("res://src/world/bedroll.gd")
const Dock := preload("res://src/world/dock.gd")
const Raft := preload("res://src/world/raft.gd")
const Furnace := preload("res://src/world/furnace.gd")
const Clamp := preload("res://src/world/clamp.gd")
const HeavyStone := preload("res://src/world/heavy_stone.gd")
const Outcrop := preload("res://src/world/outcrop.gd")
const Crater := preload("res://src/world/crater.gd")
const Chart := preload("res://src/core/chart.gd")
const MapView := preload("res://src/ui/map_view.gd")

var terrain: RefCounted
var chunks := {}            # Vector2i -> chunk
var raining := false
var weather: Node3D           # rare events: fog, storms, aurora...

var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _water: MeshInstance3D
var _rain: CPUParticles3D
var _rain_sound: AudioStreamPlayer
var _rain_mat: ShaderMaterial
var _amb: AudioStreamPlayer
var _weather_t := 300.0
const DRY_UNTIL := 1140.0  # clock seconds: a new world's first day stays sunny until dusk
var _spawn_t := 0.0
var _decay_t := 0.0
var _hint_t := 0.0
var _calm_until := 300.0
var _rng := RandomNumberGenerator.new()
# Uranocentrodon kept around the player: basking on the bank by day, and many
# more buried under the shallows, so any stretch of water may hold one.
const BASKING := 5
const HIDDEN_DAY := 16
const HIDDEN_NIGHT := 20
const RIVAL_CHANCE := 0.45  # an Eogyrinus turning up in a Uranocentrodon's water is set upon
const EOGYRINUS_MAX := 4
const EOGYRINUS_CHANCE := 1.0 / 37.0  # per spawn tick (1.5 s) below the cap: ~55 s
# River stones, chert and sticks washed up along the shore, and crusts of salt
# where the water dried on the bank: a few lie within reach at any time, each staying
# a couple of days before the water takes it back.
const SHORE_ITEMS := 18         # kept within SHORE_RANGE of the player
const SHORE_RANGE := 100.0
const SHORE_LIFE := [1.0, 3.0]  # days each one lies there
const SHORE_CHERT := 0.3
const SHORE_STICK := 0.3        # driftwood sticks stranded at the edge, in the shallows or on the bank
const SHORE_COPPER := 0.55      # of what turns up on an island's shore: native copper
const ISLAND_COPPER := 4        # lumps of native copper washed up round each island at a time
const SHORE_SALT := 0.35        # of everything washing up: a salt crust, on dry bank
const SHORE_ITEM_REACH := 8.0   # sticks and stones lie up to this far from open water
const SHORE_SALT_REACH := 6.0   # salt crusts lie up to this far from the water's edge
const SHORE_ITEM_TOP := 0.6     # ...on ground no higher than this above the water
var _shore := []                # [{node, until, isle (an island's native copper)}]
var _chart_nag := 0.0             # seconds until charting may complain again
var _isle_copper := {}            # island index -> Game.time its native copper washes away (_island_copper)
var _shore_t := 0.0
# Twice as far from the edge as you can reach the water to drink: any closer
# and a Uranocentrodon buried nearby comes for you.
const STRIKE_BAND := 6.5
var player_at_shore := false
# A thrown baitbox's feeding frenzy (start_frenzy): where, and seconds left.
# Big amphibians that turn up near it while it lasts join in.
var _frenzy_at := Vector3.ZERO
var _frenzy_left := 0.0
var _edge_t := 0.0
var _sleeping := false
var _debug_panel: Control = null
var _map_view: Control = null
var _sleep_confirm_t := 0.0
var _pending_save := 0.0       # seconds to survive after a night attack before saving
var _pending_night := -1
var waypoint := Vector3.INF    # placeholder navigation: one marked spot
var _waypoint_mark: Node3D
const WAYPOINT_CLEAR := 6.0    # marking again this close to the waypoint clears it


func _ready() -> void:
	where = "swamp"
	_rng.seed = Game.world_seed
	terrain = Terrain.new(Game.world_seed)
	Game.islands = terrain.islands
	_build_environment()
	weather = Weather.new()
	weather.swamp = self
	add_child(weather)
	Game.inventory.capacity_override = 0.0
	var restore: Dictionary = Game.restore
	Game.restore = {}
	var spawn: Vector3 = terrain.find_spawn() + Vector3(0, 0.2, 0)
	if not restore.is_empty():
		var sp: Array = restore.player.pos
		spawn = Vector3(sp[0], sp[1] + 0.1, sp[2])
	_update_chunks(spawn, 1000, 72.0)
	setup_common(spawn, true)
	if not Game.dev.has("yaw"):
		player.rotation.y = _rng.randf() * TAU
	_calm_until = Game.time + 300.0
	if Game.dev.get("weather", "") in Weather.ALL_KINDS:
		weather.start(Game.dev["weather"])
		weather.fade = 1.0
	if Game.dev.has("crater"):
		# --crater=METRES: a fresh meteorite crater that far straight ahead
		# (to look at its smoke column).
		var fwd := -player.global_transform.basis.z
		var at := player.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * float(Game.dev["crater"])
		at.y = ground_height(at.x, at.z)
		add_crater(at, Game.time)
		add_heavy_stone("meteorite", at, 0.0, 15.0, {"buried": true})
	if Game.dev.has("meteor-fall"):
		# --meteor-fall=SECONDS: a daytime shower that brings one down then.
		weather.start("day_meteors")
		weather.fade = 1.0
		weather.fall_at = float(Game.dev["meteor-fall"])
	_spawn_islands()
	if not restore.is_empty():
		_apply_restore(restore)
		return
	# A new world opens on a sunny day: the first rain can't come before dusk.
	if Game.day() == 0:
		_weather_t = maxf(DRY_UNTIL - Game.clock(), 0.0) + _rng.randf_range(0.0, 120.0)
	for i in SHORE_ITEMS:
		_wash_up(spawn, 8.0, SHORE_RANGE - 10.0, 80, Game.time + _rng.randf_range(0.2, SHORE_LIFE[1]) * Game.DAY_LENGTH)
	_dev_wood()
	if Game.dev.has("spawn"):
		# Dev: line up creatures in front of the player for inspection.
		var list: PackedStringArray = Game.dev["spawn"].split(",")
		var fwd := -player.global_transform.basis.z
		var side := player.global_transform.basis.x
		for i in list.size():
			var pos := player.global_position + fwd * float(Game.dev.get("spawn-dist", "5")) + side * (i - (list.size() - 1) * 0.5) * 2.2
			pos.y = ground_height(pos.x, pos.z)
			var c := Creature.new().setup(list[i], pos, self)
			c.home = pos
			add_child(c)
			if Game.dev.has("spawn-heading"):
				# Degrees relative to the view: 0 faces away, 90 shows the left flank.
				c.heading = atan2(fwd.x, fwd.z) + deg_to_rad(float(Game.dev["spawn-heading"]))
				c.rotation.y = c.heading + PI
			if c.species == "eogyrinus":
				c.set_mode("lurk" if pos.y < -0.3 else "land", pos)
			elif c.species == "uranocentrodon":
				c.set_mode("bask", pos)
			if c.def.behavior in ["lurker", "ambusher"] and Game.dev.has("grab"):
				c.attack_now(player)
			c.set_process(Game.dev.has("spawn-active"))
			if Game.dev.has("spawn-dead"):
				c.take_damage(1e6, null)
				if Game.dev.has("stage"):
					c.set_stage(Game.dev["stage"])
		_calm_until = INF
		if Game.dev.has("spawn-dead"):
			# --haul picks up the first carcass; --butcher kneels at it.
			var first: Node3D = Game.creatures.filter(func(k): return k.dead)[0] if Game.dev.has("haul") or Game.dev.has("butcher") else null
			if Game.dev.has("haul"):
				player.start_haul.call_deferred(first)
			elif Game.dev.has("butcher"):
				_dev_butcher.call_deferred(first)

	var first_time: bool = Game.hints_seen.get("arrived", true) == false
	if first_time:
		Game.hints_seen["arrived"] = true
		hud.show_message("Late Carboniferous. 307 million years ago.")
	if Game.intro_pending:
		# A new run: a flash of lightning sets a tree alight, and you wake on
		# your back (the intro fades in from its white).
		Game.intro_pending = false
		add_child(Intro.new().setup(self))
	elif first_time:
		hud.set_fade(Color(1, 1, 1, 1))
		hud.fade_to(Color(1, 1, 1, 0), 3.5)
	else:
		hud.set_fade(Color(0, 0, 0, 1))
		hud.fade_to(Color(0, 0, 0, 0), 1.5)


func _dev_butcher(c: Node3D) -> void:
	player.focus = c
	start_work()
	if work and work.carcass:
		var o: Dictionary = work.butcher_option()
		if o.missing.is_empty():
			work.begin(o.recipe)
			for k in int(Game.dev.get("work-steps", "0")):
				work.step()


func _dev_wood() -> void:
	## Dev: --spawn-felled=kind, --spawn-log=log,short_log, --stack=stone:30,log:8
	## lay wood out in front of you; --carry picks up the first log, and
	## --woodwork=<work> kneels at the first piece and begins that work.
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	var at := player.global_position + fwd * 3.0
	if Game.dev.has("spawn-felled"):
		var kind: String = Game.dev["spawn-felled"]
		if Chunk.TREES.has(kind):
			var p := at + fwd * 3.0 - side * 3.0
			p.y = ground_height(p.x, p.z) + Chunk.STUMP_H
			add_felled(kind, 1.0, (Chunk.SINK + Chunk.STUMP_H), side, p)
	if Game.dev.has("strike"):
		# --strike=<minutes ago>: lightning fells the nearest fellable tree,
		# struck that long ago (0 burning, 1500 cinders, 6000 charred), and
		# you face its stump.
		var tree := nearest_soft_tree(player.global_position, 40.0)
		if not tree.is_empty():
			var away: Vector3 = tree.at - player.global_position
			away.y = 0.0
			strike_tree(tree, away.normalized())
			Game.felled[tree.uid].burnt = Game.time - float(Game.dev["strike"])
			player.rotation.y = atan2(-away.x, -away.z)
			player.global_position = Vector3(tree.at.x, player.global_position.y, tree.at.z) - away.normalized() * 2.5
			player.global_position.y = ground_height(player.global_position.x, player.global_position.z) + 0.1
	if Game.dev.has("campfire"):
		# --campfire=lit|coals|ember|cold: a campfire ahead of you in that state.
		var fp := at
		fp.y = ground_height(fp.x, fp.z)
		var f := _add_fire(fp, 480.0, Game.dev["campfire"] != "cold" and Game.dev["campfire"] != "ember")
		match Game.dev["campfire"]:
			"coals":
				f.fuel = 0.0
				f.burn_t = 300.0
				f.coals = 900.0
				f._set_lit(false)
			"ember":
				f.ember = 120.0
		f._update_look()
	if Game.dev.has("plant"):
		# --plant=seed:-1,seed:5,calamites_root:12,hole: holes in a row ahead,
		# each with that item set in it, that many game days after it sprouted
		# (negative: still a mound; "hole": an open one to plant in).
		var specs: PackedStringArray = Game.dev["plant"].split(",")
		for i in specs.size():
			var bits: PackedStringArray = specs[i].split(":")
			var days := float(bits[1]) if bits.size() > 1 else -1.0
			var hp: Vector3 = at + fwd * 1.0 + side * (i - (specs.size() - 1) * 0.5) * 1.6
			hp.y = ground_height(hp.x, hp.z)
			var uid := "pldev%d" % i
			var dug := Game.time - 600.0 if days < 0.0 else Game.time - Plot.FILL_AFTER - days * Game.DAY_LENGTH
			Game.plantings[uid] = {"x": hp.x, "y": hp.y, "z": hp.z, "dug": dug}
			if Items.exists(bits[0]):
				Game.plantings[uid].item = {"id": bits[0], "age": 0.0}
				Game.plantings[uid].buried = dug
			var c: Node = chunks.get(Vector2i(floori(hp.x / Chunk.SIZE), floori(hp.z / Chunk.SIZE)))
			if c:
				c.add_planting(uid)
	if Game.dev.has("trap"):
		# --trap=fish|snare[,BAIT][,fish=N|small|medium|rotten]: a trap in front
		# of you (a fish trap in the nearest shallows ahead), baited with BAIT
		# or holding what it caught ("rotten": two days ago).
		var bits: PackedStringArray = Game.dev["trap"].split(",")
		var kind := "fish_trap" if bits[0] == "fish" else "snare"
		var tp: Vector3 = player.global_position + fwd * 2.0
		if kind == "fish_trap":
			# The nearest shallows, and you stand on the bank facing them.
			var found := false
			for r in range(2, 120, 2):
				for k in 32:
					var a := TAU * k / 32.0
					var q: Vector3 = player.global_position + Vector3(cos(a), 0, sin(a)) * r
					var d := water_level() - ground_height(q.x, q.z)
					if d > 0.3 and d < Trap.DEEP * 0.8:
						tp = q
						found = true
						break
				if found:
					break
			var back := Vector3(player.global_position.x - tp.x, 0, player.global_position.z - tp.z).normalized()
			var stand := tp + back * 2.2
			player.global_position = Vector3(stand.x, maxf(ground_height(stand.x, stand.z), water_level() - 0.8), stand.z)
			player.rotation.y = atan2(back.x, back.z)
		tp.y = floor_height(tp)
		var t := add_trap(kind, tp, player.rotation.y + (PI * 0.5 if kind == "snare" else 0.0))
		var when := Game.time - (Trap.KEEP + 60.0 if "rotten" in bits else 600.0)
		for b in bits.slice(1):
			if Items.exists(b) and "bait" in Items.def(b).get("tags", []):
				t.bait = b
			elif b.begins_with("fish="):
				for i in int(b.substr(5)):
					t.caught.append({"id": Trap.FISH[i % Trap.FISH.size()], "at": when})
			elif b == "small":
				t.caught.append({"id": "archaeothyris_carcass", "at": when})
			elif b == "medium":
				t.caught.append({"species": "scorpion", "at": when})
		t._refresh()
	if Game.dev.has("compost"):
		# --compost=LEVEL[,meat][,log|stick][,done]: a compost basket in front of you.
		var bits: PackedStringArray = Game.dev["compost"].split(",")
		var cp: Vector3 = at - side * 1.2
		var c := add_compost(Vector3(cp.x, ground_height(cp.x, cp.z) - 0.03, cp.z))
		c.rotation.y = player.rotation.y
		c.level = clampi(int(bits[0]), 0, Compost.FULL)
		c.meat = "meat" in bits
		c.slow = Compost.WOODY["log"] if "log" in bits else (Compost.WOODY["stick"] if "stick" in bits else 1.0)
		if c.level >= Compost.FULL:
			c.done_at = Game.time + (-1.0 if "done" in bits else c.days() * Game.DAY_LENGTH)
		c._refresh()
	if Game.dev.has("spawn-log"):
		# --spawn-log=log:sigillaria,short_log:tree_fern (a tree kind for each).
		var ids: PackedStringArray = Game.dev["spawn-log"].split(",")
		for i in ids.size():
			var bits: PackedStringArray = ids[i].split(":")
			if Items.exists(bits[0]):
				add_log(bits[0], at - side * 1.5 + fwd * i * 0.6, atan2(-side.z, side.x), bits[1] if bits.size() > 1 else Assets.LOG_KIND)
	if Game.dev.has("stack"):
		var i := 0
		for spec in Game.dev["stack"].split(","):
			var bits: PackedStringArray = spec.split(":")
			if Items.exists(bits[0]):
				add_stack(bits[0], int(bits[1]) if bits.size() > 1 else 6, at + side * (0.6 + i * 1.4), player.rotation.y)
				i += 1
	if Game.dev.has("soup-pot"):
		var kind: String = Game.dev["soup-pot"]
		var fp := at
		fp.y = ground_height(fp.x, fp.z)
		var sp := add_soup_pot("soup_pot_unfired" if kind == "unfired" else "soup_pot", fp)
		sp.fire = _add_fire(fp, SoupPot.HEAT_TIME * 40.0, true)
		if kind in ["1", "soup", "water"]:
			sp.water = SoupPot.SERVINGS
			if kind != "water":
				for id in ["cooked_meat", "roast_seed", "cooked_fiddlehead", "roast_seed", "cooked_fiddlehead"]:
					sp.add_food(id)
			sp.heat = 1.0
			sp.raw = false
			sp.fresh_at = Game.time
		_calm_until = INF
		if Game.dev.has("carry"):
			player.start_haul.call_deferred(sp)
	if Game.dev.has("vessel"):
		# --vessel=open|sealed|brew|salt|pickled|open-unfired|sealed-unfired puts
		# one in front of you.
		var vk: String = Game.dev["vessel"]
		var vp := at
		var vid := "vessel_open" if vk in ["1", "open", "pickled", "open-unfired"] else "vessel_sealed"
		var v := add_vessel(vid + ("_unfired" if vk.ends_with("-unfired") else ""), vp, player.rotation.y)
		if vk in ["brew", "salt", "pickled"]:
			v.water = 8
			if vk == "salt":
				v.salt = 4
			for id in ["roast_seed", "cooked_fiddlehead", "seed", "cooked_meat"]:
				v.add_food(id)
			if vk in ["brew", "pickled"]:
				v.advance(v.FERMENT_TIME + 1.0, 0.0)
		_calm_until = INF
		if Game.dev.has("carry"):
			player.start_haul.call_deferred(v)
	if Game.dev.has("carry") and not Game.dev.has("soup-pot") and not Game.dev.has("vessel"):
		var lg: Array = get_tree().get_nodes_in_group("logs")
		if not lg.is_empty():
			player.start_haul.call_deferred(lg[0])
	if Game.dev.has("woodwork"):
		_calm_until = INF
		_dev_woodwork.call_deferred(Game.dev["woodwork"])
	if Game.dev.has("house"):
		# --house=N marks out a softwood house site ahead of you with its first
		# N parts built (all: finished); --house-stand=inside|porch|under|far|side
		# puts you there.
		var spot := house_spot(player)
		for i in 24:
			# Turn until there's room for it, if there is any.
			if spot.why == "":
				break
			player.rotation.y += TAU / 24.0
			spot = house_spot(player)
		var h := add_house(spot.at, spot.yaw)
		h.build_to(House.PARTS.size() if Game.dev["house"] == "all" else int(Game.dev["house"]))
		var pots := get_tree().get_nodes_in_group("soup_pots")
		if h.fire and not pots.is_empty():
			# With --soup-pot, it hangs over the lit fireplace instead.
			var sp: Node3D = pots[0]
			sp.fire.queue_free()
			sp.fire = h.fire
			sp.global_position = h.fire.global_position
			h.fire.fuel = 600.0
			h.fire._set_lit(true)
		if h.fire and Game.dev.has("hearth"):
			# --hearth=id,id,...: those on the lit fireplace, and you looking at it.
			var ids := String(Game.dev["hearth"]).split(",", false)
			for i in mini(ids.size(), h.fire.SPOTS):
				h.fire.cooking[i] = {"id": ids[i], "t": 0.0}
			h.fire.fuel = 600.0
			h.fire._set_lit(true)
			h.fire._refresh_spots()
			player.global_position = h.to_global(House.HEARTH + Vector3(-0.2, 0.05, 1.7))
			var to: Vector3 = h.fire.global_position + Vector3(0, 0.9, 0) - player.global_position
			player.rotation.y = atan2(-to.x, -to.z)
		match String(Game.dev.get("house-stand", "")):
			"inside":
				player.global_position = h.to_global(Vector3(-0.6, 0.05, 0.4))
			"porch":
				player.global_position = h.to_global(Vector3(-0.9, 0.05, 2.0))
			"far", "side":
				var f := h.to_global(Vector3(-9.0, 0, 8.0) if Game.dev["house-stand"] == "side" else Vector3(-1.5, 0, 11.0))
				player.global_position = Vector3(f.x, ground_height(f.x, f.z), f.z)
				var to := h.global_position + Vector3(0, -0.5, 0) - player.global_position
				player.rotation.y = atan2(-to.x, -to.z)
			"under":
				var u := h.to_global(Vector3(0.6, 0, 0.2))
				player.global_position = Vector3(u.x, ground_height(u.x, u.z), u.z)
		_calm_until = INF
	if Game.dev.has("dock"):
		# --dock=N: a dock site on the nearest shore with its first N parts
		# built, you at its land end; --dock-work kneels to build the next part
		# (with what it needs in your bag), --dock-steps=N beginning it and
		# doing N steps.
		_dev_dock()
	if Game.dev.has("bench"):
		# --bench=clay_platter,woodworking_tools puts a workbench in front of
		# you with those tools on its rack; --at-bench works at it.
		var b := add_bench(player.global_position + fwd * 1.6, player.rotation.y)
		for id in String(Game.dev["bench"]).split(",", false):
			b.hang(id)
			Game.learn_tool(id, false)
		Game.unlock_tier("bench")
		if Game.dev.has("at-bench"):
			_calm_until = INF
			_dev_make.call_deferred(b)


func _dev_make(b: Node3D) -> void:
	## Works at the bench, lays out what --make=<item> needs and begins it,
	## doing --work-steps of it.
	player.focus = b
	start_work()
	var make: String = Game.dev.get("make", "")
	if work and Game.dev.has("lay"):
		# --lay=item:n,...: these laid out on the bench.
		for e in String(Game.dev["lay"]).split(",", false):
			var kv := e.split(":")
			var n := int(kv[1]) if kv.size() > 1 else 1
			Game.inventory.add(kv[0], n)
			work.lay(Game.inventory.find(kv[0]), n)
	if work and make != "":
		var r := Items.recipe_for(make, where)
		for id in r.get("in", {}):
			Game.inventory.add(id, r.in[id])
			work.lay(Game.inventory.find(id), r.in[id])
		for id in r.get("tools", {}):
			Game.inventory.add(id, r.tools[id])
		if r.get("tool_tag", "") == "cut":
			Game.inventory.add("flint_blade", 1)
		if work.begin(r):
			for k in int(Game.dev.get("work-steps", "0")):
				work.step()


func _dev_woodwork(what: String) -> void:
	var piece: Node3D = null
	for g in ["logs", "felled"]:
		var n: Array = get_tree().get_nodes_in_group(g)
		if not n.is_empty():
			piece = n[0]
			break
	if what == "fell":
		# Walk up to the nearest soft tree and face it.
		var best := nearest_soft_tree(player.global_position)
		if best.is_empty():
			return
		var back: Vector3 = player.global_position - best.at
		back.y = 0.0
		player.global_position = best.at + back.normalized() * (best.r + 0.6)
		player.rotation.y = atan2(back.x, back.z)
	elif piece:
		var at: Vector3 = piece.cut_point() if piece is FelledTree else piece.global_position
		var back := (player.global_position - at)
		back.y = 0.0
		player.global_position = at + back.normalized() * 1.2
	player.focus = piece
	start_work()
	if work == null:
		return
	for o in work.options():
		if o.recipe.get("wood", "") == what and o.missing.is_empty():
			work.begin(o.recipe)
			for k in int(Game.dev.get("work-steps", "0")):
				if work:
					work.step()
			return


func ground_height(x: float, z: float) -> float:
	return terrain.height(x, z)


func water_level() -> float:
	return Terrain.WATER


func floor_height(p: Vector3) -> float:
	## The ground, or the floor of a house, a dock's deck or a raft's where p
	## is up at it.
	var h := ground_height(p.x, p.z)
	for house in Game.houses:
		h = maxf(h, house.floor_top(p))
	for d in Game.docks:
		h = maxf(h, d.floor_top(p))
	for r in Game.rafts:
		h = maxf(h, r.floor_top(p))
	return h


func floor_below(p: Vector3) -> float:
	## The highest thing under p to come to rest on, however far above it p
	## is: the ground, or a house's floor, a dock's deck or a raft's (things
	## falling from high up land on them rather than through them).
	var h := ground_height(p.x, p.z)
	for s in Game.houses + Game.docks + Game.rafts:
		if not is_instance_valid(s):
			continue
		var t: float = s.floor_top(Vector3(p.x, s.global_position.y, p.z))
		if t > h and t <= p.y + 0.3:
			h = t
	return h


const FERN_REACH := 0.8   # how near where a mattock strikes a decorative fern must stand


func clear_fern(p: Vector3) -> bool:
	## A mattock swung at the ground: tears out the decorative fern there, if
	## any (chunk.clear_fern), its own chunk first, then the ones around it.
	## Only where it strikes the ground (not a trunk or a wall above one).
	if absf(p.y - ground_height(p.x, p.z)) > 0.6:
		return false
	var at := Vector2i(floori(p.x / Chunk.SIZE), floori(p.z / Chunk.SIZE))
	var order: Array[Vector2i] = [at]
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx != 0 or dz != 0:
				order.append(at + Vector2i(dx, dz))
	for k in order:
		var c: Node = chunks.get(k)
		if c and c.clear_fern(p, FERN_REACH):
			Sfx.play_at("rustle", p, -2.0, 0.2)
			return true
	return false


func trunks_near(pos: Vector3) -> PackedVector3Array:
	var c: Node = chunks.get(Vector2i(floori(pos.x / Chunk.SIZE), floori(pos.z / Chunk.SIZE)))
	return c.trunks if c else PackedVector3Array()


func dig_hole(pos: Vector3) -> bool:
	## A mattock's right-click: a hole in the open ground at pos, for planting
	## (plot.gd). It fills itself in again a game day later.
	var h := ground_height(pos.x, pos.z)
	if absf(pos.y - h) > 0.25:
		Game.notify("Aim at open ground to dig a hole.")
		return false
	if floor_height(pos) > h + 0.3:
		Game.notify("You can't dig through a wooden floor.")
		return false
	if h < Terrain.WATER + 0.05:
		Game.notify("The ground here is too wet to hold a hole.")
		return false
	if terrain.rockiness(pos.x, pos.z) > 0.3:
		Game.notify("The ground here is too rocky to dig.")
		return false
	for uid in Game.plantings:
		var rec: Dictionary = Game.plantings[uid]
		if Vector2(float(rec.x), float(rec.z)).distance_to(Vector2(pos.x, pos.z)) < 0.9:
			Game.notify("That's too close to another hole or planting.")
			return false
	for v in trunks_near(pos):
		if v.z > 0.0 and Vector2(v.x, v.y).distance_to(Vector2(pos.x, pos.z)) < v.z + 0.4:
			Game.notify("Too close to a tree: its roots are in the way.")
			return false
	var uid := "pl%d_%d_%d" % [roundi(pos.x * 10.0), roundi(pos.z * 10.0), roundi(Game.time)]
	Game.plantings[uid] = {"x": pos.x, "y": h, "z": pos.z, "dug": Game.time}
	var c: Node = chunks.get(Vector2i(floori(pos.x / Chunk.SIZE), floori(pos.z / Chunk.SIZE)))
	if c:
		c.add_planting(uid)
	Sfx.play_at("thud", pos, -6.0)
	return true


func place(kind: String, pos: Vector3, item := "") -> bool:
	## Sets down what you hold (`item`, for a sack: which one) at pos.
	if kind == "sack":
		return _place_stash(pos, item if item != "" else "fiber_sack")
	if kind == "compost":
		return _place_compost(pos)
	if kind == "snare":
		return _place_snare(pos)
	if kind == "bedroll":
		return _place_bedroll()
	if kind != "campfire":
		return false
	if floor_height(pos) > ground_height(pos.x, pos.z) + 0.5:
		Game.notify("Not on a wooden floor. Build the fire on the ground, or use the fireplace.")
		return false
	var h := ground_height(pos.x, pos.z)
	if h < 0.05:
		Game.notify("The ground here is too wet for a fire.")
		return false
	_add_fire(Vector3(pos.x, h, pos.z), 480.0, false)
	Sfx.play("craft", -4.0)
	return true


func mark_waypoint(at: Vector3) -> void:
	## Puts the waypoint where you look (or where you stand when you look at
	## the sky). Standing near it, marking again clears it.
	if waypoint.is_finite() and Vector2(waypoint.x - player.global_position.x, waypoint.z - player.global_position.z).length() < WAYPOINT_CLEAR:
		clear_waypoint()
		Game.notify("Waypoint cleared.")
		return
	if not at.is_finite():
		at = player.global_position
	set_waypoint(at)
	Sfx.play("click", -6.0)
	Game.notify("Waypoint set, %d m away." % roundi(player.global_position.distance_to(at)))


func set_waypoint(at: Vector3) -> void:
	waypoint = Vector3(at.x, maxf(ground_height(at.x, at.z), Terrain.WATER), at.z)
	if _waypoint_mark == null:
		_waypoint_mark = MeshInstance3D.new()
		var beam := CylinderMesh.new()
		beam.top_radius = 0.06
		beam.bottom_radius = 0.12
		beam.height = 40.0
		beam.radial_segments = 6
		beam.rings = 1
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.75, 0.25, 0.35)
		beam.material = m
		_waypoint_mark.mesh = beam
		_waypoint_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_waypoint_mark)
	_waypoint_mark.global_position = waypoint + Vector3(0, 20.0, 0)
	_waypoint_mark.visible = true


func clear_waypoint() -> void:
	waypoint = Vector3.INF
	if _waypoint_mark:
		_waypoint_mark.visible = false


func _place_stash(pos: Vector3, sack := "fiber_sack") -> bool:
	var raft := raft_under(pos)
	if raft == null and player.riding:
		raft = player.riding
	if raft:
		# Lashed to one of its four corners.
		var spot: int = raft.free_spot(pos)
		if spot < 0:
			Game.notify("No room on the raft for another sack.")
			return false
		var rs := _add_stash(raft.to_global(Raft.SPOTS[spot]))
		rs.set_sack(sack)
		rs.rotation.y = raft.rotation.y
		raft.lash_sack(rs, spot)
		Sfx.play("pickup", -6.0)
		return true
	var h := floor_height(pos)
	if h < -0.2:
		Game.notify("The water would soak the sack. Set it down on firmer ground.")
		return false
	var s := _add_stash(Vector3(pos.x, maxf(h, 0.0) - 0.05, pos.z))
	s.set_sack(sack)
	s.rotation.y = player.rotation.y
	Sfx.play("pickup", -6.0)
	return true


func _place_compost(pos: Vector3) -> bool:
	var h := ground_height(pos.x, pos.z)
	if floor_height(pos) > h + 0.3:
		Game.notify("Set the compost basket down on the ground, not on a floor.")
		return false
	if h < Terrain.WATER + 0.05:
		Game.notify("The ground here is too wet for a compost basket.")
		return false
	var c := add_compost(Vector3(pos.x, h - 0.03, pos.z))
	c.rotation.y = player.rotation.y
	Sfx.play("craft", -4.0)
	return true


func _place_snare(pos: Vector3) -> bool:
	var h := ground_height(pos.x, pos.z)
	if floor_height(pos) > h + 0.3:
		Game.notify("Set the snare on the ground, where animals run, not on a floor.")
		return false
	if h < Terrain.WATER + 0.05:
		Game.notify("The ground here is too wet for a snare. Set it on dry land.")
		return false
	add_trap("snare", Vector3(pos.x, h, pos.z), player.rotation.y + PI * 0.5)  # the noose facing you, the bait beyond it
	Sfx.play("rustle", -6.0)
	Game.notify("You set the snare. Kneel at it (C) to bait it.")
	return true


func _place_bedroll() -> bool:
	## Sets the rolled-up bedroll down on the floor in front of you, only inside the room
	## of a finished house (not on its porch), and not in the fireplace.
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for d in [1.0, 0.6, 0.0]:
		var at: Vector3 = player.global_position + fwd * d
		var h := house_at(at)
		if h == null or not h.room_spot(at, Bedroll.LENGTH * 0.5):
			continue
		if h.built.has("fireplace") and Vector2(at.x - h.to_global(House.HEARTH).x, at.z - h.to_global(House.HEARTH).z).length() < 1.0:
			Game.notify("Not in the fireplace. Set the bedroll down somewhere else in the room.")
			return false
		var b := add_bedroll(Vector3(at.x, h.floor_top(at), at.z))
		b.rotation.y = player.rotation.y + PI * 0.5  # lying across your view
		Sfx.play("rustle", -6.0)
		Game.notify("You set the bedroll down. Look at it: %s to sleep, %s to save the game." \
				% [Settings.button_name("sleep"), Settings.button_name("interact")])
		return true
	Game.notify("Set the bedroll down on the floor inside your house.")
	return false


func add_bedroll(pos: Vector3) -> Node3D:
	var b := Bedroll.new()
	add_child(b)
	b.global_position = pos
	return b


func sleep_on_bedroll() -> void:
	## Sleep (Z) while looking at a bedroll: lies down at once, without the
	## usual second press, if nothing stops you (sleep_blocker: not tired yet,
	## hunted, bleeding...).
	if player.ui_open:
		return
	var why := sleep_blocker()
	if why != "":
		if not _sleeping:
			Game.notify(why)
		return
	_sleep_confirm_t = 0.0
	hud.set_hint("")
	_hint_t = 0.0
	sleep(true)


func save_at_bedroll() -> void:
	## Interact (E) at a bedroll: the camp save, without sleeping. Not while
	## anything stops a save and quit (suspend_blocker: hunted, in jaws...).
	var why := suspend_blocker()
	if why != "":
		Game.notify(why)
		return
	save_now()


func add_trap(kind: String, pos: Vector3, yaw := 0.0) -> Node3D:
	## A fish trap or a snare (trap.gd), set down there unbaited.
	var t := Trap.new().setup(kind, self)
	t.position = pos
	t.rotation.y = yaw
	add_child(t)
	return t


func _check_traps() -> void:
	## On waking: what each baited trap caught in the night (trap.catch).
	for t in get_tree().get_nodes_in_group("traps"):
		if not t.is_queued_for_deletion() and t.hauled_by == null:
			t.catch(_rng)


func add_compost(pos: Vector3) -> Node3D:
	var c := Compost.new()
	add_child(c)
	c.global_position = pos
	return c


func compost_near(pos: Vector3, reach: float) -> Node3D:
	## The compost basket within reach of pos, if any.
	var best: Node3D = null
	for c in get_tree().get_nodes_in_group("composters"):
		var d: float = Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
		if not c.is_queued_for_deletion() and d < reach and (best == null or d < Vector2(best.global_position.x - pos.x, best.global_position.z - pos.z).length()):
			best = c
	return best


func _compost_pests() -> Array:
	## On waking: compost baskets with meat in them may have drawn a pest each
	## (a Scorpion or an Arthropleura) that wanders about beside it.
	var news := []
	for c in get_tree().get_nodes_in_group("composters"):
		var sp: String = c.pest_roll(_rng)
		if sp == "":
			continue
		for k in 8:
			var a := _rng.randf() * TAU
			var at: Vector3 = c.global_position + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.5, 5.0)
			at.y = ground_height(at.x, at.z)
			if at.y > 0.15:
				add_child(Creature.new().setup(sp, at, self))
				if at.distance_to(player.global_position) < 60.0:
					news.append("Something drawn by the smell of your compost is rooting about beside it.")
				break
	return news


func _add_stash(pos: Vector3) -> Node3D:
	var s := Stash.new()
	add_child(s)
	s.global_position = pos
	return s


func _age_torches(seconds: float) -> void:
	## Rain makes lit torches burn down twice as fast (the inventory ages them
	## once; this adds the second share). Says so when one burns out.
	var inv = Game.inventory
	var lit_before: int = inv.count("torch_lit")
	if lit_before == 0:
		return
	if raining:
		for s in inv.slots:
			if s != null and s.id == "torch_lit":
				s.age += seconds
	_torch_check.call_deferred(lit_before)


func _torch_check(lit_before: int) -> void:
	if Game.inventory.count("torch_lit") < lit_before:
		Game.notify("Your torch has burned out.")


func _add_fire(pos: Vector3, fuel: float, lit: bool) -> Node3D:
	var f := Campfire.new()
	f.fuel = fuel
	f.position = pos  # before it is added: it fits its ring to the ground there
	add_child(f)
	if lit:
		f._set_lit(true)
	return f


# --- Environment ----------------------------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.85
	_env.glow_enabled = Settings.quality == Settings.Quality.HIGH
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = Settings.shadows()
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 45.0 if Settings.quality == Settings.Quality.MEDIUM else 70.0
	_sun.shadow_blur = 1.5
	add_child(_sun)

	var plane := PlaneMesh.new()
	var extent := Settings.view_distance * 2.0 + 128.0
	plane.size = Vector2(extent, extent)
	var subdiv := 0 if Settings.quality == Settings.Quality.LOW else 48
	plane.subdivide_width = subdiv
	plane.subdivide_depth = subdiv
	plane.material = Assets.material("water")
	_water = MeshInstance3D.new()
	_water.mesh = plane
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)

	_rain = CPUParticles3D.new()
	_rain.amount = [150, 350, 600][Settings.quality]
	_rain.lifetime = 0.9
	_rain.emitting = false
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(16, 1, 16)
	_rain.direction = Vector3(0.05, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 18.0
	_rain.initial_velocity_max = 22.0
	_rain.gravity = Vector3(0, -9.8, 0)
	_rain.particle_flag_align_y = true
	var drop := QuadMesh.new()
	drop.size = Vector2(0.025, 0.55)
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = Shader.new()
	_rain_mat.shader.code = RAIN_SHADER
	drop.material = _rain_mat
	_rain.mesh = drop
	add_child(_rain)

	_rain_sound = AudioStreamPlayer.new()
	_rain_sound.stream = Sfx.stream("rain")
	_rain_sound.volume_db = -60.0
	add_child(_rain_sound)
	_amb = AudioStreamPlayer.new()
	_amb.stream = Sfx.stream("swamp")
	_amb.volume_db = -14.0
	add_child(_amb)
	_amb.play()


## Raindrops: upright billboards, left out under a finished roof (up to
## MAX_ROOFS houses near you, given as world-to-house transforms and the
## x range each roof covers; see _update_roofs).
const MAX_ROOFS := 8
const RAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform int roofs = 0;
uniform mat4 to_house[8];
uniform vec2 cover[8];  // the roof's x range in the house's space (one side may be missing)
uniform vec4 shape;     // eave x, eave y, ridge y, roof z half-length
varying vec3 world;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	world = (INV_VIEW_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	for (int i = 0; i < roofs; i++) {
		vec3 l = (to_house[i] * vec4(world, 1.0)).xyz;
		if (l.x > cover[i].x && l.x < cover[i].y && abs(l.z) < shape.w
				&& l.y < mix(shape.z, shape.y, abs(l.x) / shape.x)) {
			discard;
		}
	}
	ALBEDO = vec3(0.7, 0.78, 0.8);
	ALPHA = 0.35;
}
"""


func _update_roofs() -> void:
	## Tells the rain where the finished roofs near you are.
	var mats: Array[Projection] = []
	var cover := PackedVector2Array()
	for h in get_tree().get_nodes_in_group("houses"):
		if mats.size() >= MAX_ROOFS or h.global_position.distance_to(player.global_position) > 40.0:
			continue
		var left: bool = h.built.has("roof_left")
		var right: bool = h.built.has("roof_right")
		if not left and not right:
			continue
		mats.append(Projection(h.global_transform.affine_inverse()))
		cover.append(Vector2(-House.EAVE.x if left else 0.0, House.EAVE.x if right else 0.0))
	var n := mats.size()
	while mats.size() < MAX_ROOFS:
		mats.append(Projection.IDENTITY)
		cover.append(Vector2.ZERO)
	_rain_mat.set_shader_parameter("roofs", n)
	_rain_mat.set_shader_parameter("to_house", mats)
	_rain_mat.set_shader_parameter("cover", cover)
	_rain_mat.set_shader_parameter("shape", Vector4(House.EAVE.x, House.EAVE.y, House.RIDGE, House.ROOF_Z.y))


func _update_sky() -> void:
	var t := Game.time_of_day()
	# Sun travels east to west; t = 0.25 sunrise, 0.5 noon, 0.75 sunset.
	var ang := (t - 0.25) * TAU
	var elev := sin(ang)
	var day := smoothstep(-0.08, 0.25, elev)
	var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)
	var rain_k := 0.55 if raining else 1.0
	var sun_dir := Vector3(cos(ang), elev, 0.35).normalized()
	if elev < -0.05:
		sun_dir = Vector3(-cos(ang), -elev, -0.3).normalized()  # moonlight from the opposite side
	_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.FORWARD)
	_sun.light_color = Color(0.55, 0.62, 0.85).lerp(Color(1.0, 0.92, 0.78), day).lerp(Color(1.0, 0.6, 0.35), dusk * day)
	# Nights are dark but for the moon (and brighter on a bright moon night,
	# see weather.gd).
	_sun.light_energy = lerpf(0.1, 1.0, day) * rain_k

	var top := Color(0.025, 0.035, 0.08).lerp(Color(0.32, 0.48, 0.62), day)
	var horizon := Color(0.05, 0.07, 0.085).lerp(Color(0.62, 0.68, 0.58), day).lerp(Color(0.85, 0.5, 0.3), dusk * 0.7)
	if raining:
		top = top.lerp(Color(0.25, 0.28, 0.28) * maxf(day, 0.15), 0.7)
		horizon = horizon.lerp(Color(0.32, 0.35, 0.33) * maxf(day, 0.15), 0.7)
	_sky.sky_top_color = top
	_sky.sky_horizon_color = horizon
	_sky.ground_horizon_color = horizon
	_sky.ground_bottom_color = horizon * 0.5
	_sky.sun_curve = 0.1
	_env.ambient_light_energy = lerpf(0.22, 0.45, day) * rain_k
	_env.fog_light_color = horizon.lerp(Color(0.45, 0.5, 0.42), 0.4 * day)
	_env.fog_density = (2.2 if raining else 1.3) / Settings.view_distance
	weather.apply_sky(_env, _sky, _sun, day)


func _process(delta: float) -> void:
	if player == null:
		return
	Game.time += delta
	var p := player.global_position
	_update_chunks(p, 1, 0.0)
	_water.global_position = Vector3(snappedf(p.x, 8.0), Terrain.WATER, snappedf(p.z, 8.0))
	_rain.global_position = p + Vector3(0, 12, 0)
	if raining:
		_update_roofs()
	weather.update(delta)
	_update_sky()
	_update_weather(delta)
	_edge_t -= delta
	if _edge_t <= 0.0:
		_edge_t = 0.2
		# Never on a raft, a finished dock or an island (Game.safe).
		player_at_shore = player.riding == null and not Game.safe(p) \
				and water_point(p, STRIKE_BAND, Terrain.WATER - 0.1).is_finite()

	_decay_t += delta
	if _decay_t > 1.0:
		_age_torches(_decay_t)
		Game.inventory.tick(_decay_t)
		_chart(_decay_t)
		_decay_t = 0.0

	_frenzy_left = maxf(_frenzy_left - delta, 0.0)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 1.5
		_spawn_creatures()
		_spawn_amphibians()
		_update_shore(1.5)

	_sleep_confirm_t = maxf(_sleep_confirm_t - delta, 0.0)
	if _pending_save > 0.0 and not player.vitals.dead:
		_pending_save -= delta
		if _pending_save <= 0.0:
			if player.grabbed_by:
				_pending_save = 5.0
			else:
				Game.saved_night = _pending_night
				Game.notify("You survived the attack.")
				save_now()

	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			hud.set_hint("")


# --- Chunks -----------------------------------------------------------------------------

func _update_chunks(center: Vector3, budget: int, radius_override: float) -> void:
	var radius := radius_override if radius_override > 0.0 else Settings.view_distance + 16.0
	var r := ceili(radius / Chunk.SIZE)
	var pc := Vector2i(floori(center.x / Chunk.SIZE), floori(center.z / Chunk.SIZE))
	var missing := []
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := pc + Vector2i(dx, dz)
			if chunks.has(key):
				continue
			var cc := Vector2((key.x + 0.5) * Chunk.SIZE, (key.y + 0.5) * Chunk.SIZE)
			var d := cc.distance_to(Vector2(center.x, center.z))
			if d < radius:
				missing.append([d, key])
	if not missing.is_empty():
		missing.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(budget, missing.size()):
			var key: Vector2i = missing[i][1]
			var c := Chunk.new()
			add_child(c)
			c.build(key.x, key.y, terrain, self)
			chunks[key] = c
	# Unload far chunks (with some hysteresis).
	var far := Settings.view_distance + 80.0
	for key in chunks.keys():
		var cc := Vector2((key.x + 0.5) * Chunk.SIZE, (key.y + 0.5) * Chunk.SIZE)
		if cc.distance_to(Vector2(center.x, center.z)) > far:
			chunks[key].queue_free()
			chunks.erase(key)


# --- Weather -----------------------------------------------------------------------------

func _update_weather(delta: float) -> void:
	_weather_t -= delta
	if weather.storm() and not raining:
		_weather_t = 0.0  # a thunderstorm brings rain with it
	if weather.storm():
		_weather_t = maxf(_weather_t, 60.0) if raining else _weather_t
	if _weather_t <= 0.0:
		set_rain(weather.storm() or (not raining and _rng.randf() < 0.6))
		if raining and not weather.storm():
			Game.notify("Warm rain begins to fall.")
	var target := (-3.0 if weather.storm() else -10.0) if raining else -60.0
	_rain_sound.volume_db = move_toward(_rain_sound.volume_db, target, delta * 15.0)
	if not raining and _rain_sound.volume_db <= -59.0 and _rain_sound.playing:
		_rain_sound.stop()


func set_rain(on: bool) -> void:
	## Starts or stops the rain, and sets how long until it next changes.
	raining = on
	_weather_t = _rng.randf_range(120.0, 240.0) if on else _rng.randf_range(240.0, 480.0)
	_rain.emitting = on
	if on and not _rain_sound.playing:
		_rain_sound.play()


# --- Fauna -------------------------------------------------------------------------------

func _spawn_creatures() -> void:
	var p := player.global_position
	var counts := {}
	for c in Game.creatures.duplicate():
		if not is_instance_valid(c):
			continue
		if not c.dead and c.global_position.distance_to(p) > 160.0:
			c.queue_free()
			continue
		if c.expired() and not c.is_queued_for_deletion():
			if player.hauling == c:
				player.put_down()
			c.queue_free()
			continue
		if not c.dead:
			counts[c.species] = counts.get(c.species, 0) + 1
	var night := Game.is_night()
	# Small prey share one population (Creature.PREY_DAY / PREY_NIGHT), so
	# more species means more variety, not more animals.
	var prey := 0
	for sp in counts:
		if Creature.SPECIES[sp].behavior == "prey":
			prey += counts[sp]
	var order: Array = Creature.SPECIES.keys().filter(func(k): return Creature.SPECIES[k].behavior != "prey")
	if prey < (Creature.PREY_NIGHT if night else Creature.PREY_DAY):
		order.push_front(pick_prey(night))
	for sp in order:
		var def: Dictionary = Creature.SPECIES[sp]
		if def.behavior == "lurker":
			continue
		# The prey species picked for this tick is only there while the pool
		# has room, so it has no cap of its own.
		var cap: int = 999 if def.behavior == "prey" else (def.cap_night if night else def.cap_day)
		if def.behavior == "hunter" and Game.time < _calm_until:
			cap = 0
		if counts.get(sp, 0) >= cap:
			continue
		var a := _rng.randf() * TAU
		var dist := _rng.randf_range(35.0, 80.0) if def.habitat != "air" else _rng.randf_range(25.0, 55.0)
		var x := p.x + cos(a) * dist
		var z := p.z + sin(a) * dist
		var h: float = terrain.height(x, z)
		var ok := true
		match def.habitat:
			"land":
				ok = h > 0.15
		if def.get("spawn", "") == "shore":
			# On the bank or in the very shallows, right by open water.
			var s := shore_spot(p, 35.0, 80.0, 4)
			ok = s.is_finite()
			if ok:
				x = s.x
				z = s.z
				h = s.y
		if not ok or Game.nearest_fire(Vector3(x, h, z), 25.0) or house_at(Vector3(x, h, z), 6.0) \
				or (def.get("spawn", "") == "shore" and Game.safe(Vector3(x, h, z))):
			continue
		var y := h
		if def.habitat == "air":
			y = maxf(h, 0.0) + 4.0
		var c := Creature.new().setup(sp, Vector3(x, y, z), self)
		add_child(c)
		return  # at most one spawn per tick


func pick_prey(night: bool) -> String:
	## A small prey species, picked by its `prey` weight for the time of day.
	var total := 0.0
	for sp in Creature.SPECIES:
		total += float(Creature.SPECIES[sp].get("prey", [0.0, 0.0])[1 if night else 0])
	var roll := _rng.randf() * total
	var last := ""
	for sp in Creature.SPECIES:
		var wt := float(Creature.SPECIES[sp].get("prey", [0.0, 0.0])[1 if night else 0])
		if wt <= 0.0:
			continue
		last = sp
		if roll < wt:
			return sp
		roll -= wt
	return last


func _spawn_amphibians() -> void:
	## Keeps Uranocentrodon along the player's part of the shoreline: a couple
	## basking on the bank in daylight, and many more buried under the shallows
	## day and night. Now and then an Eogyrinus turns up: usually on the bank near
	## water, sometimes in the water, and rarely further inland by a puddle.
	var basking := 0
	var hidden := 0
	var roaming := 0
	for c in Game.creatures:
		if not is_instance_valid(c) or c.dead:
			continue
		if c.species == "uranocentrodon":
			if c.mode == "bask":
				basking += 1
			else:
				hidden += 1
		elif c.species == "eogyrinus":
			roaming += 1
	var night := Game.is_night()
	var want := ""
	if basking < (0 if night else BASKING) and basking + hidden < BASKING + HIDDEN_NIGHT:
		want = "bask"
	elif hidden < (HIDDEN_NIGHT if night else HIDDEN_DAY):
		want = "hide"
	elif roaming < EOGYRINUS_MAX and Game.time > _calm_until and _rng.randf() < EOGYRINUS_CHANCE:
		var roll := _rng.randf()
		want = "bank" if roll < 0.6 else ("water" if roll < 0.85 else "inland")
	if want == "":
		return
	var spot := amphibian_spot(want, player.global_position)
	if spot.is_empty():
		return
	if want in ["bask", "hide"]:
		spawn_amphibian("uranocentrodon", want, spot[0], spot[1])
	else:
		_spawn_eogyrinus(spot[0], want == "water")


func amphibian_spot(want: String, p: Vector3) -> Array:
	## [position, water home] for an amphibian spawn of the given kind somewhere
	## around p, or [] when no place was found this time.
	var tries: int = {"bask": 8, "hide": 20, "inland": 24}.get(want, 40)
	for attempt in tries:
		var a := _rng.randf() * TAU
		var dist := _rng.randf_range(45.0, 90.0) if want == "inland" else _rng.randf_range(30.0, 90.0)
		var pos := Vector3(p.x + cos(a) * dist, 0, p.z + sin(a) * dist)
		pos.y = terrain.height(pos.x, pos.z)
		var water := Vector3.INF
		match want:
			"bask":
				# On the bank or in the shallows, with deep water close by.
				if pos.y < -0.3 or pos.y > 0.4:
					continue
				water = water_point(pos, 12.0, -0.9)
			"hide":
				# Buried under the shallows, close enough to the edge to reach it.
				if pos.y > -0.3 or pos.y < -1.8 or not _near_land(pos, 9.0, 0.0):
					continue
				water = water_point(pos, 15.0, -0.9)
				if not water.is_finite():
					water = pos
			"bank":
				# Eogyrinus on dry ground a short way up from the water.
				if pos.y < 0.1 or pos.y > 0.9 or terrain.rockiness(pos.x, pos.z) > 0.3:
					continue
				water = water_point(pos, 14.0)
			"water":
				if pos.y > -0.5 or pos.y < -1.8:
					continue
				water = pos
			"inland":
				# Away from the marsh, mostly by a puddle or a small pond; only
				# now and then out on plain dry ground.
				if pos.y < 0.4 or terrain.rockiness(pos.x, pos.z) > 0.3:
					continue
				water = _puddle_near(pos, 20.0)
				if water.is_finite():
					pos = water
				elif attempt == tries - 1 and _rng.randf() < 0.3:
					water = pos
		if water.is_finite() and not Game.nearest_fire(pos, 15.0) and not Game.dock_keeps_out(pos) and not Game.island_safe(pos):
			return [pos, water]
	return []


# --- The charted map (core/chart.gd) --------------------------------------------------

const CHART_NAG := 20.0          # how often charting complains of no pencil or a blunt one

func _chart(dt: float) -> void:
	## Draws the ground round you onto your Map as you go, if you carry a
	## sharp pencil; on new ground without one, says so now and then.
	_chart_nag = maxf(_chart_nag - dt, 0.0)
	if player.vitals.dead:
		return
	var why: String = Chart.chart_round(Game.inventory, player.global_position)
	if why == "" or _chart_nag > 0.0:
		return
	_chart_nag = CHART_NAG
	if why == "pencil":
		Game.notify("You have no pencil to draw your map with.")
	else:
		Game.notify("Your pencil is blunt and the map isn't being drawn. Sharpen it: Use the pencil with a blade in your bag.")


func open_map() -> void:
	## Opens the charted map (ui/map_view.gd).
	if inv_ui.visible or work or player.vitals.dead:
		return
	if _map_view == null:
		_map_view = MapView.new()
		_map_view.world = self
		inv_ui.get_parent().add_child(_map_view)
		_map_view.closed.connect(func():
			player.ui_open = false
			player.capture_mouse(true))
	player.ui_open = true
	player.capture_mouse(false)
	_map_view.open()


# --- Shore stones --------------------------------------------------------------------------

func _update_shore(delta: float) -> void:
	## Washes new stones up along the nearby shore and lets old ones go. Those
	## far from the player are dropped (nobody sees them go).
	var p := player.global_position
	var near := 0
	for e in _shore.duplicate():
		var n: Node3D = e.node
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			_shore.erase(e)
		elif Game.time > e.until or n.global_position.distance_to(p) > SHORE_RANGE * 2.0:
			if e.has("isle") and Game.time <= e.until:
				_isle_copper.erase(e.isle)  # left lying, not picked up: lay them again next visit
			n.queue_free()
			_shore.erase(e)
		elif n.global_position.distance_to(p) < SHORE_RANGE:
			near += 1
	_island_copper(p)
	_shore_t -= delta
	if near >= SHORE_ITEMS or _shore_t > 0.0:
		return
	# Refill a bare stretch quickly, then trickle in at about the rate they go.
	_shore_t = 30.0 if near < SHORE_ITEMS / 2 else Game.DAY_LENGTH * 2.0 / SHORE_ITEMS * _rng.randf_range(0.5, 1.5)
	_wash_up(p, 15.0, SHORE_RANGE - 10.0, 16, Game.time + _rng.randf_range(SHORE_LIFE[0], SHORE_LIFE[1]) * Game.DAY_LENGTH)


func _wash_up(p: Vector3, near: float, far: float, tries: int, until: float) -> void:
	## One thing turns up on the shore near p: SHORE_SALT of the time a salt
	## crust, which only forms on dry bank just above the water (most of the
	## shore is shallows, so it looks for bank on purpose); otherwise a
	## stick, stone or chert anywhere along the edge.
	var salt: bool = _rng.randf() < SHORE_SALT and terrain.island_at(p.x, p.z, 60.0).is_empty()
	var spot := shore_spot(p, near, far, tries * 4, true, SHORE_SALT_REACH, SHORE_ITEM_TOP) if salt else Vector3.INF
	if not spot.is_finite():
		salt = false
		spot = shore_spot(p, near, far, tries, false, SHORE_ITEM_REACH, SHORE_ITEM_TOP)
	if not spot.is_finite():
		return
	var pk := add_shore_item("salt" if salt else _shore_kind(spot), spot, until)
	if salt:
		# A thin crust: keep it on top of the drawn ground, which on a coarse
		# terrain mesh can sit a few centimetres above the true height.
		pk.global_position.y = maxf(spot.y, drawn_height(spot.x, spot.z)) + 0.005


func _shore_kind(spot: Vector3) -> String:
	## Sticks wash up anywhere along the edge; stones lie anywhere. Round a
	## rocky island it is gravel: stones, and native copper (metals).
	if not terrain.island_at(spot.x, spot.z, 12.0).is_empty():
		return "native_copper" if _rng.randf() < SHORE_COPPER else "stone"
	if _rng.randf() < SHORE_STICK:
		return "stick"
	return "flint" if _rng.randf() < SHORE_CHERT else "stone"


func drawn_height(x: float, z: float) -> float:
	## About where the terrain mesh is drawn at x, z: the true heights at the
	## corners of its grid cell (Settings.terrain_step() apart), blended.
	var step := float(Settings.terrain_step())
	var x0 := floorf(x / step) * step
	var z0 := floorf(z / step) * step
	var fx := (x - x0) / step
	var fz := (z - z0) / step
	return lerpf(lerpf(terrain.height(x0, z0), terrain.height(x0 + step, z0), fx),
			lerpf(terrain.height(x0, z0 + step), terrain.height(x0 + step, z0 + step), fx), fz)


func shore_spot(p: Vector3, near: float, far: float, tries := 16, dry := false, reach := 0.0, top := 0.3) -> Vector3:
	## A point on the bank or in the very shallows, right by open water (dry:
	## only on the bank, out of the water, within a few steps of its edge;
	## the wading-deep water most of the shore needs is rarely that close to
	## dry ground), or Vector3.INF if none turned up. reach: how far from the
	## water it may be (0: 3 m dry, 4 m otherwise); top: the highest ground.
	var low := water_level() + 0.03 if dry else -0.25
	var r := reach if reach > 0.0 else (3.0 if dry else 4.0)
	for attempt in tries:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(near, far)
		var x := p.x + cos(a) * d
		var z := p.z + sin(a) * d
		var h: float = terrain.height(x, z)
		if h < low or h > top:
			continue
		var wet := water_point(Vector3(x, h, z), r, water_level() - 0.05) if dry else water_point(Vector3(x, h, z), r)
		if not wet.is_finite():
			continue
		return Vector3(x, h, z)
	return Vector3.INF


func add_shore_item(id: String, pos: Vector3, until: float) -> Node3D:
	var pk := Pickup.new().setup(id)
	add_child(pk)
	pk.global_position = pos
	pk.rotation.y = _rng.randf() * TAU
	_shore.append({"node": pk, "until": until})
	return pk


func _island_copper(p: Vector3) -> void:
	## Every island always has native copper on its shore: coming within
	## SHORE_RANGE of one whose last batch has gone (washed away after
	## SHORE_LIFE days, or never laid), ISLAND_COPPER lumps wash up round its
	## waterline together. Those picked up are gone until the next batch.
	for i in terrain.islands.size():
		var isl: Dictionary = terrain.islands[i]
		if Game.time <= float(_isle_copper.get(i, -1.0)) \
				or Vector2(p.x - isl.x, p.z - isl.z).length() > float(isl.r) + SHORE_RANGE:
			continue
		var until: float = Game.time + _rng.randf_range(SHORE_LIFE[0], SHORE_LIFE[1]) * Game.DAY_LENGTH
		_isle_copper[i] = until
		for k in ISLAND_COPPER:
			var spot := island_shore_spot(isl)
			if spot.is_finite():
				add_shore_item("native_copper", spot, until)
				_shore[-1].isle = i


func island_shore_spot(isl: Dictionary, tries := 24) -> Vector3:
	## A point on an island's gravel at the waterline (from the shallows up
	## to SHORE_ITEM_TOP above the water), or Vector3.INF.
	for t in tries:
		var a := _rng.randf() * TAU
		var dir := Vector2(cos(a), sin(a))
		# Walk in from the foot of the shelf to where it comes up out of the water.
		var r := float(isl.r)
		while r > float(isl.r) * 0.2:
			var q := Vector2(isl.x, isl.z) + dir * r
			var h: float = terrain.height(q.x, q.y)
			if h > water_level() + SHORE_ITEM_TOP:
				break
			if h > water_level() - 0.25:
				return Vector3(q.x, h, q.y)
			r -= 0.5
	return Vector3.INF


func _spawn_eogyrinus(pos: Vector3, in_water: bool) -> Node3D:
	## In the water it lurks as it always has; anywhere else it roams the
	## ground around where it turned up. Turning up in the water near a
	## Uranocentrodon can go badly: sometimes the bigger animal goes after it,
	## and either takes it or drives it out onto land.
	var e := spawn_amphibian("eogyrinus", "lurk" if in_water else "land", pos, pos)
	e.home = pos
	if not in_water:
		return e
	var rival: Node3D = null
	for c in Game.creatures:
		if is_instance_valid(c) and not c.dead and c.species == "uranocentrodon" \
				and c.state in ["hide", "bask"] and c.global_position.distance_to(pos) < 25.0 \
				and (rival == null or c.global_position.distance_to(pos) < rival.global_position.distance_to(pos)):
			rival = c
	if rival and _rng.randf() < RIVAL_CHANCE:
		rival.hunt(e, _rng.randf_range(4.0, 12.0))
	return e


# --- Guts piles ---------------------------------------------------------------------------
# Gutting an animal leaves its guts (and skin) in a pile beside it. Thrown or
# dropped guts make a pile where they land, or splash in the water like a stone.
# A pile's smell draws scavengers (see guts.gd).

func add_guts(pos: Vector3, n: int, skin := false) -> Node3D:
	## Adds to a pile right there, or starts a new one: on the ground, or a
	## house's floor when pos is up at it (a pile under the house is another).
	var y := floor_height(pos)
	for g in get_tree().get_nodes_in_group("guts"):
		if not g.is_queued_for_deletion() and Vector2(g.global_position.x - pos.x, g.global_position.z - pos.z).length() < 1.2 \
				and absf(g.global_position.y - y) < 1.0:
			g.add(n, skin)
			return g
	var pile := Guts.new().setup(n, skin, self)
	add_child(pile)
	pile.global_position = Vector3(pos.x, y, pos.z)
	return pile


func splat_guts(pos: Vector3) -> void:
	## A handful of guts hits the ground (a new pile) or the water (a lure).
	var g := ground_height(pos.x, pos.z)
	if g < water_level() - 0.1:
		ThrownRock.splash(self, Vector3(pos.x, water_level(), pos.z))
	else:
		add_guts(pos, 1)


func draw_to_guts(pile: Node3D, kind: String) -> Node3D:
	## The smell of a guts pile brings an animal: an Eogyrinus ("eogyrinus"), or
	## ("medium") a scorpion or an Arthropleura (only Arthropleura by day or in
	## the calm first minutes). It turns up 30-50 m from the pile, out of the
	## player's sight if it can, and comes hungry.
	var at: Vector3 = pile.global_position
	var sp := kind
	if kind == "medium":
		sp = "arthropleura" if not Game.is_night() or Game.time < _calm_until or _rng.randf() < 0.5 else "scorpion"
	var p := player.global_position
	var best := Vector3.INF
	for attempt in 30:
		var a := _rng.randf() * TAU
		var pos := at + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(30.0, 50.0)
		pos.y = terrain.height(pos.x, pos.z)
		if pos.distance_to(p) < 25.0 or pos.distance_to(p) > 150.0 or Game.nearest_fire(pos, 20.0):
			continue
		if sp != "eogyrinus" and pos.y < 0.15:
			continue
		best = pos
		# An Eogyrinus comes up out of the water if there is some close by.
		if sp != "eogyrinus" or pos.y < -0.3:
			break
	if not best.is_finite():
		return null
	var c: Node3D
	if sp == "eogyrinus":
		c = spawn_amphibian(sp, "land", best, best)
	else:
		c = Creature.new().setup(sp, best, self)
		add_child(c)
	c.home = at
	c.drawn = true
	c.bait = pile
	c._bait_pos = at
	return c


func _puddle_near(pos: Vector3, max_r: float) -> Vector3:
	## A puddle or small pond within max_r: a dip below the waterline with no
	## real swamp water around it. Vector3.INF when there is none.
	var dip := water_point(pos, max_r, Terrain.WATER - 0.05)
	if not dip.is_finite() or water_point(dip, 10.0, -0.5).is_finite():
		return Vector3.INF
	return dip


func debug_spawn(sp: String) -> Node3D:
	## Debug panel: puts a creature 5 m in front of the player, facing them.
	## Amphibians settle as they would there: in the water a Uranocentrodon
	## buries itself and an Eogyrinus lurks; on land they bask or roam.
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	var pos := player.global_position + fwd.normalized() * 5.0
	pos.y = ground_height(pos.x, pos.z)
	var wet := pos.y < Terrain.WATER - 0.3
	var c: Node3D
	if sp == "uranocentrodon":
		c = spawn_amphibian(sp, "hide" if wet else "bask", pos, pos)
	elif sp == "eogyrinus":
		c = spawn_amphibian(sp, "lurk" if wet else "land", pos, pos)
	else:
		c = Creature.new().setup(sp, pos, self)
		add_child(c)
	c.home = pos
	c.heading = atan2(-fwd.x, -fwd.z)
	c.rotation.y = c.heading + PI
	return c


func open_debug() -> void:
	if not Game.debug or player.vitals.dead or _sleeping:
		return
	if _debug_panel == null:
		_debug_panel = DebugPanel.new()
		_debug_panel.world = self
		pause.get_parent().add_child(_debug_panel)
		_debug_panel.closed.connect(func(): player.capture_mouse(not player.ui_open))
	close_work()
	player.capture_mouse(false)
	_debug_panel.open()


func spawn_amphibian(sp: String, m: String, pos: Vector3, water: Vector3) -> Node3D:
	var c := Creature.new().setup(sp, pos, self)
	add_child(c)
	c.set_mode(m, water)
	if _frenzy_left > 0.0:
		c.frenzy(_frenzy_at, _frenzy_left)  # one turning up near a baitbox joins in
	return c


func start_frenzy(at: Vector3, secs: float, item_id := "baitbox") -> int:
	## A baitbox has landed in the water at `at`: every Uranocentrodon and
	## Eogyrinus within Creature.FRENZY_RADIUS rushes to it and tears at it for
	## `secs`, leaving the player alone unless they come as close as would
	## always set one off. Returns how many came.
	add_child(Baitbox.new().setup(item_id, at, secs, self))
	ThrownRock.ripple(self, at)
	_frenzy_at = at
	_frenzy_left = secs
	var n := 0
	for c in Game.creatures:
		if is_instance_valid(c) and c.frenzy(at, secs):
			n += 1
	return n


func water_point(pos: Vector3, max_r: float, depth := -0.3) -> Vector3:
	## Nearest point within max_r whose ground lies below `depth` (by default,
	## swamp water you would wade into, not a puddle), searched in rings.
	## Vector3.INF when there is none.
	var r := 1.0
	while r <= max_r:
		var n := maxi(12, int(r * 1.5))
		for i in n:
			var a := TAU * i / n
			var x := pos.x + cos(a) * r
			var z := pos.z + sin(a) * r
			var h: float = terrain.height(x, z)
			if h < depth:
				return Vector3(x, h, z)
		r += 1.5
	return Vector3.INF


func _near_land(pos: Vector3, r: float, land := -0.2) -> bool:
	for i in 12:
		var a := TAU * i / 12.0
		for d in [r * 0.5, r]:
			if terrain.height(pos.x + cos(a) * d, pos.z + sin(a) * d) > land:
				return true
	return false


# --- Sleep and saving ---------------------------------------------------------------------
# Sleep anywhere once you are tired (12+ min awake); 8 minutes pass. Sleeping
# through a night saves the game, once per night. Unsafe spots can go wrong:
# predators, bites and leeches, chills and floods. Distance from water matters
# most: within 10 m an amphibian attack is nearly certain, past 30 m impossible.

func sleep_risk(pos: Vector3) -> Dictionary:
	var wp := water_point(pos, 40.0)
	var d_water := pos.distance_to(Vector3(wp.x, pos.y, wp.z)) if wp.is_finite() else INF
	var h: float = terrain.height(pos.x, pos.z)
	var fire := Game.nearest_fire(pos, 6.0) != null
	var rocky: bool = terrain.rockiness(pos.x, pos.z) > 0.2
	var cover := 0
	for t in trunks_near(pos):
		if Vector2(t.x - pos.x, t.y - pos.z).length() < 4.5:
			cover += 1
	var carcass := false
	for c in Game.creatures:
		if is_instance_valid(c) and c.dead and c.global_position.distance_to(pos) < 20.0:
			carcass = true
	for g in get_tree().get_nodes_in_group("guts"):
		if g.global_position.distance_to(pos) < 20.0:
			carcass = true
	var blood: bool = carcass or Game.inventory.count("raw_meat") > 0 or player.vitals.bleeding()
	var night := Game.night_index() >= 0

	var amph := 0.0
	if d_water < 10.0:
		amph = 0.95
	elif d_water < 30.0:
		amph = lerpf(0.95, 0.0, (d_water - 10.0) / 20.0)
	if fire:
		amph *= 0.7
	if blood:
		amph = minf(amph * 1.2, 0.97)
	var pred := 0.16 if night else 0.06
	if fire:
		pred *= 0.15
	if rocky:
		pred *= 0.5
	if cover >= 2:
		pred *= 0.7
	if blood:
		pred *= 2.0
	var bites := 0.22 * (0.5 if fire else 1.0) * (0.5 if rocky else 1.0) * (1.8 if d_water < 15.0 else 1.0)
	var chill := 0.0
	if raining:
		chill = 0.1 if fire else 0.65
	elif night and not fire:
		chill = 0.08
	var flood := 0.5 if raining and h < 0.6 and d_water < 20.0 else 0.0

	var feel := []
	if d_water < 10.0:
		feel.append("The water is right there. Something could come out of it.")
	elif d_water < 30.0:
		feel.append("Open water is uncomfortably close.")
	else:
		feel.append("You are well away from the water.")
	if fire:
		feel.append("The fire will keep most animals off.")
	if rocky:
		feel.append("High, rocky ground.")
	elif cover >= 2:
		feel.append("Trunks shelter your back.")
	elif not fire:
		feel.append("You are out in the open.")
	if blood:
		feel.append("The smell of blood hangs around you.")
	if raining:
		feel.append("Rain is soaking everything." + (" The ground here could flood." if flood > 0.0 else ""))
	if Game.island_safe(pos) or Game.dock_safe(pos):
		# Nothing big lies in the water round an island or a finished dock.
		amph = 0.0
		feel[0] = "Nothing big lives in the water here." if Game.island_safe(pos) else "Nothing will come out of the water among the dock's spiked piles."
	var leeches := d_water < 15.0
	if Game.sheltered(pos):
		# Up off the ground behind walls, under a roof: nothing bites, no leeches.
		amph = 0.0
		pred = 0.0
		bites = 0.0
		leeches = false
		chill = 0.0
		flood = 0.0
		feel = ["You are up in your house, off the ground, behind walls and under a roof. Nothing will come for you here."]
		if blood:
			feel.append("The smell of blood hangs around you, but nothing can reach you.")
	if not Game.hostile():
		amph = 0.0
		pred = 0.0
	var danger := 1.0 - (1.0 - amph) * (1.0 - pred) * (1.0 - bites * 0.5) * (1.0 - flood * 0.5)
	return {
		"water": d_water, "amphibian": amph, "predator": pred, "bites": bites,
		"leeches": leeches, "chill": chill, "flood": flood, "danger": danger,
		"feel": " ".join(feel),
	}


# --- Woodcutting and piles ----------------------------------------------------------
# A soft tree is felled by kneeling at it with an axe (work_spot.gd): it falls in
# one piece (felled_tree.gd) and leaves a stump that grows back (stump.gd). The
# felled trunk is cut into logs (wood_log.gd), carried in your arms, and worked
# into short logs, firewood, boards, bark and branches. Raw materials dropped on
# land go on piles of their kind (stack.gd).

func tree_ahead() -> Dictionary:
	## The standing tree right in front of you, or {}.
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p := player.global_position
	var best := {}
	var best_d := INF
	var pc := Vector2i(floori(p.x / Chunk.SIZE), floori(p.z / Chunk.SIZE))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c: Node3D = chunks.get(pc + Vector2i(dx, dz))
			if c == null:
				continue
			var t: Dictionary = c.tree_near(p, fwd, 1.6)
			if t.is_empty():
				continue
			var d: float = Vector2(t.at.x - p.x, t.at.z - p.z).length() - t.r
			if d < best_d:
				best = t
				best_d = d
	if not best.is_empty():
		best.chunk = chunks[Vector2i(floori(best.at.x / Chunk.SIZE), floori(best.at.z / Chunk.SIZE))]
	return best


func wood_ahead() -> Node3D:
	## The felled trunk or loose log you are looking at, or one right in front.
	var f: Object = player.focus
	if f != null and is_instance_valid(f) and (f is FelledTree or f is WoodLog):
		return f if _workable(f) else null
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best: Node3D = null
	var best_d := INF
	for g in ["logs", "felled"]:
		for w in get_tree().get_nodes_in_group(g):
			if not _workable(w):
				continue
			var at: Vector3 = w.cut_point() if w is FelledTree else w.global_position
			var to: Vector3 = at - player.global_position
			to.y = 0.0
			if to.length() < 1.8 and to.length() < best_d and (to.length() < 0.5 or to.normalized().dot(fwd) > 0.3):
				best = w
				best_d = to.length()
	return best


func _workable(w: Object) -> bool:
	if not is_instance_valid(w) or w.is_queued_for_deletion():
		return false
	if w is FelledTree:
		return not w.falling() and not w.rotten()
	return w.hauled_by == null and not w.rotten()


func nearest_soft_tree(pos: Vector3, within := INF) -> Dictionary:
	## The nearest standing tree that can be felled (with its `chunk`), or {}.
	var best := {}
	var best_d := within
	for c in chunks.values():
		for t in c.trees:
			var d: float = t.at.distance_to(pos)
			if d < best_d and t.stump == null and not Game.felled.has(t.uid) and Chunk.TREES[t.kind].soft:
				best = t
				best_d = d
				best.chunk = c
	return best


func strike_tree(tree: Dictionary, away: Vector3) -> Node3D:
	## Lightning: the tree comes down away from you as if cut, and its stump
	## is left burning; it never grows back (stump.gd).
	var c: Node3D = tree.chunk
	c.fell(tree, true)
	var top := Vector3(tree.at.x, tree.at.y + Chunk.STUMP_H, tree.at.z)
	var ft := add_felled(tree.kind, tree.s, (Chunk.SINK + Chunk.STUMP_H) / tree.s, away, top)
	ft.start_fall()
	return ft


func fell_tree(tree: Dictionary, away: Vector3) -> Node3D:
	## The tree comes down away from you, leaving its stump.
	var c: Node3D = tree.chunk
	c.fell(tree)
	var top := Vector3(tree.at.x, tree.at.y + Chunk.STUMP_H, tree.at.z)
	var ft := add_felled(tree.kind, tree.s, (Chunk.SINK + Chunk.STUMP_H) / tree.s, away, top)
	ft.start_fall()
	Game.crafted.emit("felled")
	return ft


func add_felled(kind: String, scale: float, lo: float, fall_dir: Vector3, pos: Vector3) -> Node3D:
	var ft := FelledTree.new().setup(kind, scale, lo, fall_dir, self)
	ft.position = pos
	add_child(ft)
	return ft


func add_log(id: String, pos: Vector3, yaw: float, kind := Assets.LOG_KIND) -> Node3D:
	## A log lying loose on the ground (or a house's floor, when pos is up at
	## it), cut from a tree of this kind.
	var lg := WoodLog.new().setup(id, self, kind)
	lg.position = Vector3(pos.x, floor_height(pos), pos.z)
	lg.rotation.y = yaw
	add_child(lg)
	lg.lie_on_ground()
	return lg


func _on_land(pos: Vector3) -> bool:
	return floor_height(pos) >= water_level() - 0.05


func stack_near(id: String, pos: Vector3, kind := "") -> Node3D:
	for st in get_tree().get_nodes_in_group("stacks"):
		if st.item_id == id and st.kind == kind and not st.is_queued_for_deletion() \
				and Vector2(st.global_position.x - pos.x, st.global_position.z - pos.z).length() < Stack.REACH:
			return st
	return null


func add_bench(pos: Vector3, yaw: float) -> Node3D:
	## A workbench standing there, its front facing along yaw (see workbench.gd).
	var b := Workbench.new()
	b.position = pos
	b.rotation.y = yaw
	add_child(b)
	return b


func add_soup_pot(id: String, pos: Vector3, yaw := 0.0) -> Node3D:
	## A soup pot standing there on its tripod (see soup_pot.gd), empty: on
	## the ground, or a house's floor when pos is up at it.
	var sp := SoupPot.new().setup(id, self)
	sp.position = Vector3(pos.x, floor_height(pos), pos.z)
	sp.rotation.y = yaw
	add_child(sp)
	return sp


func add_vessel(id: String, pos: Vector3, yaw := 0.0) -> Node3D:
	## A fermentation vessel standing there (see ferment_vessel.gd), empty: on
	## the ground, or a house's floor when pos is up at it.
	var v := FermentVessel.new().setup(id, self)
	v.position = Vector3(pos.x, floor_height(pos), pos.z)
	v.rotation.y = yaw
	add_child(v)
	return v


func open_vessel(v: Node, page := "vessel") -> void:
	## Opens a fermentation vessel's window beside your bag, or ("fill_pot")
	## the menu to fill a clay pot of preserves from it.
	if inv_ui.visible or player.vitals.dead or player.hauling:
		return
	close_work()
	inv_ui.vessel = v
	inv_ui.open(null, page)
	player.ui_open = true
	player.capture_mouse(false)


func add_carried(id: String, pos: Vector3, yaw := 0.0) -> Node3D:
	## Something too big for the bag, made and left there: a soup pot, a
	## fermentation vessel or a log.
	if id.begins_with("soup_pot"):
		return add_soup_pot(id, pos, yaw)
	if id.begins_with("vessel_"):
		return add_vessel(id, pos, yaw)
	if id == "fish_trap":
		return add_trap(id, Vector3(pos.x, floor_height(pos), pos.z), yaw)
	if id in ["anvil_stone", "meteorite"]:
		return add_heavy_stone(id, pos, yaw)
	return add_log(id, pos, yaw)


func blood_in_water(at: Vector3, by: Node3D) -> void:
	## Meaty soup tipped into the water: rings spread from it, and the
	## amphibians lurking further off than they would strike from come up and
	## close in on whoever did it (Creature.scent).
	ThrownRock.ripple(self, Vector3(at.x, water_level(), at.z))
	var drawn := 0
	for c in Game.creatures:
		if is_instance_valid(c) and c.def.behavior in ["ambusher", "lurker"] and c.scent(at, by):
			drawn += 1
	if drawn > 0:
		Game.notify("Something stirs out in the water.")


func add_stack(id: String, n: int, pos: Vector3, yaw := 0.0, kind := "") -> Node3D:
	var st := Stack.new().setup(id, n, kind)
	st.position = Vector3(pos.x, floor_height(pos), pos.z)
	st.rotation.y = yaw
	add_child(st)
	return st


func pile_item(id: String, n: int, pos: Vector3, age := 0.0, data := {}) -> void:
	## Puts items down on the pile of their kind there, or starts a pile. Items
	## that don't pile, and anything dropped in the water, lie loose instead.
	if not Items.def(id).get("pile", false) or not _on_land(pos) or not data.is_empty():
		spawn_pickup(id, n, pos, age, true, data)
		return
	var st := stack_near(id, pos)
	if st:
		st.add(n)
	else:
		add_stack(id, n, pos, player.rotation.y if player else 0.0)


func settle_log(lg: Node3D) -> void:
	## A log just put down joins a pile of its kind there, or starts one with a
	## loose log of its kind lying beside it.
	if lg.rotten() or not _on_land(lg.global_position):
		return
	var st := stack_near(lg.item_id, lg.global_position, lg.kind)
	if st:
		st.add(1)
		lg.queue_free()
		return
	for other in get_tree().get_nodes_in_group("logs"):
		if other != lg and other.item_id == lg.item_id and other.kind == lg.kind and other.hauled_by == null and not other.rotten() \
				and not other.is_queued_for_deletion() and other.global_position.distance_to(lg.global_position) < Stack.REACH:
			add_stack(lg.item_id, 2, other.global_position, other.rotation.y, lg.kind)
			other.queue_free()
			lg.queue_free()
			Sfx.play_at("step", lg.global_position, -6.0, 0.2)
			return


# --- Houses ---------------------------------------------------------------------------
# A Softwood House Blueprint held in hand shows where the house would go,
# ahead of you with its porch toward you; right-clicking marks out the site
# (house.gd), which is then built part by part.

func house_spot(from: Node3D) -> Dictionary:
	## Where a house would go for someone standing at `from`: {at, yaw, why}
	## (why is "" when it can go there).
	var yaw: float = from.rotation.y
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var centre: Vector3 = from.global_position + fwd * (House.EDGE + 2.6)
	var hi := -INF
	for g in House.ground_points(centre, yaw):
		hi = maxf(hi, ground_height(g.x, g.z))
	var at := Vector3(centre.x, hi + House.FLOOR_H, centre.z)
	return {"at": at, "yaw": yaw, "why": house_blocker(at, yaw)}


func house_blocker(at: Vector3, yaw: float) -> String:
	## Why a house can't stand at `at` (its floor) facing `yaw`, or "".
	var lo := INF
	var hi := -INF
	for g in House.ground_points(at, yaw):
		var h := ground_height(g.x, g.z)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if lo < water_level() + 0.15:
		return "Too wet: the stilts would stand in water."
	for h in Game.houses:
		if Vector2(h.global_position.x - at.x, h.global_position.z - at.z).length() < House.SPACING:
			return "Too close to the other house."
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(House.EAVE.x * 2.0, at.y + House.RIDGE - (hi + 0.3), House.EDGE + 0.8 - House.ROOF_Z.x)
	q.shape = box
	var basis := Basis(Vector3.UP, yaw)
	var mid := basis * Vector3(0, 0, (House.EDGE + 0.8 + House.ROOF_Z.x) * 0.5)
	q.transform = Transform3D(basis, Vector3(at.x + mid.x, (hi + 0.3 + at.y + House.RIDGE) * 0.5, at.z + mid.z))
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "No room: something is in the way."
	return ""


func place_blueprint(kind: String, from: Node3D) -> bool:
	## Marks out a house (or dock) site where the blueprint shows it.
	if kind == "dock":
		var ds := dock_spot(from)
		if ds.why != "":
			Game.notify(ds.why)
			return false
		add_dock(ds.at, ds.yaw)
		Sfx.play("rustle", -4.0)
		Game.notify("You mark out the dock. Press E at it to build it, part by part: first the land post, from a Calamites log carried here in your arms.")
		return true
	if kind != "softwood_house":
		return false
	var spot := house_spot(from)
	if spot.why != "":
		Game.notify(spot.why)
		return false
	add_house(spot.at, spot.yaw)
	Sfx.play("rustle", -4.0)
	Game.notify("You mark out the site for a softwood house. Press E at it to build it, part by part: first the stilts, from Calamites logs carried here in your arms.")
	return true


func add_house(at: Vector3, yaw: float, d := {}) -> Node3D:
	var h := House.new()
	h.world = self
	h.position = at
	h.rotation.y = yaw
	if not d.is_empty():
		h.from_dict(d)
	add_child(h)
	return h


# --- Docks and rafts --------------------------------------------------------------------
# A Dock Blueprint held in hand shows the dock running out from the bank in
# front of you (dock.gd). A finished dock marks out a raft (raft.gd) beside it.

const DOCK_SLIDE := [1.0, 2.0, 0.0, 3.0, 4.0, -1.0, 5.0, 6.0, 8.0]   # how far ahead to try the land end
const DOCK_TURN := [0.0, 0.2, -0.2, 0.4, -0.4]                   # and turned this much from the way you face


func _dev_dock() -> void:
	var start := player.global_position
	for r in range(6, 200, 3):
		for i in 24:
			var a := TAU * i / 24.0
			var q := start + Vector3(cos(a), 0, sin(a)) * r
			q.y = ground_height(q.x, q.z)
			if absf(q.y - water_level()) > 0.1:
				continue
			var dx := ground_height(q.x + 1.0, q.z) - ground_height(q.x - 1.0, q.z)
			var dz := ground_height(q.x, q.z + 1.0) - ground_height(q.x, q.z - 1.0)
			if Vector2(dx, dz).length() < 0.01:
				continue
			var down := -Vector2(dx, dz).normalized()
			player.global_position = q + Vector3(-down.x, 0.05, -down.y)
			player.rotation.y = atan2(-down.x, -down.y)
			var spot := dock_spot(player)
			if spot.why != "":
				continue
			if Game.dev.has("dock-deep"):
				# --dock-deep: only where the spikes are worked from swimming.
				var st: Vector3 = spot.at + Basis(Vector3.UP, spot.yaw) * Vector3(1.9, 0, -5.5)
				if water_level() - ground_height(st.x, st.z) < 1.6:
					continue
			var d := add_dock(spot.at, spot.yaw)
			d.build_to(int(Game.dev["dock"]))
			_calm_until = INF
			if Game.dev.has("dock-work"):
				var p: Dictionary = d.next_part()
				for id in p.get("in", {}):
					Game.inventory.add(id, p.in[id])
				for id in p.get("tools", {}):
					Game.inventory.add(id, p.tools[id])
				if p.get("tool_tag", "") == "cut":
					Game.inventory.add("flint_blade", 1)
				_dev_dock_work.call_deferred(d)
			if Game.dev.has("raft") and d.complete():
				_dev_raft.call_deferred(d)
			return


func _dev_raft(d: Node3D) -> void:
	## --raft (with a finished --dock): the raft at its berth is built and you
	## stand on it holding a pole; --raft-pole poles it straight ahead.
	var r: Node3D = raft_at_dock(d)
	if r == null:
		return
	r.build_to(r.parts().size())
	Game.inventory.add("calamites_pole", 1)
	Game.inventory.select(Game.inventory.find("calamites_pole"))
	await get_tree().physics_frame
	r.board(player)
	if Game.dev.has("raft-pole"):
		Input.action_press("move_forward")


func _dev_dock_work(d: Node3D) -> void:
	## Kneels at the dock; with --dock-steps=N, begins its next part and does
	## N steps of it.
	start_house_work(d)
	if work == null:
		return
	var opts: Array = work.options()
	if not Game.dev.has("dock-steps"):
		return  # just kneeling: the part not begun
	if opts.is_empty() or not work.begin(opts[0].recipe):
		return
	for k in int(Game.dev.get("dock-steps", "0")):
		work.step()


func dock_spot(from: Node3D) -> Dictionary:
	## Where a dock would go for someone standing at `from`: running out the
	## way they face, its land end at the water's edge just ahead. It is
	## forgiving: if that exact spot won't do, it slides the dock a few metres
	## along and turns it a little to find one that will. {at, yaw, why}.
	var first := {}
	for turn in DOCK_TURN:
		var yaw: float = from.rotation.y + turn
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		for ahead in DOCK_SLIDE:
			var origin: Vector3 = from.global_position + fwd * ahead
			var at := Vector3(origin.x, water_level() + Dock.DECK_H, origin.z)
			var why := dock_blocker(at, yaw)
			if why == "":
				return {"at": at, "yaw": yaw, "why": ""}
			if first.is_empty():
				first = {"at": at, "yaw": yaw, "why": why}
	return first


func dock_blocker(at: Vector3, yaw: float) -> String:
	## Why a dock can't stand at `at` (the land end of its deck) running out
	## along `yaw`, or "".
	var basis := Basis(Vector3.UP, yaw)
	var land := at + basis * Vector3(0, 0, 0.3)
	var land_h := ground_height(land.x, land.z)
	if land_h < water_level() - 0.4:
		return "Start it on the bank, at the water's edge."
	if land_h > water_level() + 1.2:
		return "Too high: the bank here is too far above the water."
	var far := at + basis * Vector3(0, 0, -Dock.LEN + 0.4)
	var depth := water_level() - ground_height(far.x, far.z)
	if depth < Dock.SHALLOW:
		return "The water at the far end is too shallow for a raft."
	for p in Dock.PILES + [Dock.BERTH]:
		var g: Vector3 = at + basis * Vector3(p.x, 0, p.z)
		var dd := water_level() - ground_height(g.x, g.z)
		if dd > Dock.DEEP:
			return "Too deep: the piles wouldn't reach the bottom."
	var berth := at + basis * Vector3(Dock.BERTH.x, 0, Dock.BERTH.z)
	if water_level() - ground_height(berth.x, berth.z) < Raft.DRAFT + 0.1:
		return "Too shallow beside the far end to float a raft."
	for d in Game.docks:
		if Vector2(d.global_position.x - at.x, d.global_position.z - at.z).length() < Dock.SPACING:
			return "Too close to the other dock."
	for h in Game.houses:
		if h.covers(at + basis * Vector3(0, 0, -Dock.LEN * 0.5), Dock.LEN * 0.5):
			return "Too close to the house."
	return ""


func add_dock(at: Vector3, yaw: float, d := {}) -> Node3D:
	var k := Dock.new()
	k.world = self
	k.position = at
	k.rotation.y = yaw
	if not d.is_empty():
		k.from_dict(d)
	add_child(k)
	return k


func add_raft(at: Vector3, yaw: float, d := {}) -> Node3D:
	var r := Raft.new()
	r.world = self
	r.position = at
	r.rotation.y = yaw
	if not d.is_empty():
		r.from_dict(d)
	add_child(r)
	return r


func raft_at_dock(dock: Node3D) -> Node3D:
	## The raft built at (or tied up at) this dock's berth, or null.
	for r in Game.rafts:
		if is_instance_valid(r) and not r.is_queued_for_deletion() and r.global_position.distance_to(dock.berth()) < 2.0:
			return r
	return null


func raft_under(pos: Vector3) -> Node3D:
	## The floating raft whose deck pos is over, or null.
	for r in Game.rafts:
		if is_instance_valid(r) and r.complete() and r.over(pos, 0.2) and absf(pos.y - r.floor_top(r.global_position)) < 1.2:
			return r
	return null


func site_at(pos: Vector3, margin := 0.0) -> Node3D:
	## A house, dock or raft still being built whose footprint pos is within,
	## or null. Finished ones are passed over: a raft is marked out right
	## beside its finished dock, inside the dock's margin.
	for h in Game.houses:
		if not h.complete() and h.covers(pos, margin):
			return h
	for d in Game.docks:
		if not d.complete() and d.covers(pos, margin):
			return d
	for r in Game.rafts:
		if not r.complete() and r.over(pos, margin):
			return r
	return null


# --- Metals ------------------------------------------------------------------------------
# A furnace and a charcoal clamp are built by hand (work_spot._build_here); the
# islands' copper outcrops and anvil stones are made from the world seed; a
# meteor shower may bring a meteorite down (weather.gd, meteor_fall). See
# metals.md.

func add_furnace(at: Vector3, yaw: float, d := {}) -> Node3D:
	## A furnace site: new ones start with the stone ring just laid.
	var f := Furnace.new()
	f.world = self
	f.position = at
	f.rotation.y = yaw
	f.from_dict(d if not d.is_empty() else {"yaw": yaw, "built": {"ring": {"stone": 8}}})
	add_child(f)
	return f


func add_clamp(at: Vector3, yaw: float, d := {}) -> Node3D:
	var c := Clamp.new().setup(self)
	c.position = Vector3(at.x, floor_height(at), at.z)
	c.rotation.y = yaw
	add_child(c)
	if not d.is_empty():
		c.from_dict(d)
	return c


func add_heavy_stone(id: String, pos: Vector3, yaw := 0.0, kg := -1.0, d := {}) -> Node3D:
	## An anvil stone or a meteorite lying on the ground.
	var st := HeavyStone.new().setup(id, self, kg)
	if not d.is_empty():
		st.from_dict(d)
	st.position = Vector3(pos.x, floor_height(pos), pos.z)
	st.rotation.y = yaw
	add_child(st)
	return st


func add_crater(at: Vector3, made_at: float) -> Node3D:
	var c := Crater.new()
	c.made_at = made_at
	c.position = at
	add_child(c)
	return c


func _spawn_islands() -> void:
	## Each island's copper outcrops, and its anvil stones until one is first
	## picked up (then it is saved with everything else: Game.taken).
	for i in terrain.islands.size():
		var isl: Dictionary = terrain.islands[i]
		for k in isl.outcrops.size():
			var p: Vector2 = isl.outcrops[k]
			var o := Outcrop.new().setup("copper_outcrop", "isle%d_ore%d" % [i, k])
			o.position = Vector3(p.x, ground_height(p.x, p.y) - 0.1, p.y)
			o.rotation.y = hash(o.uid) % 628 / 100.0
			add_child(o)
		for k in isl.anvils.size():
			var uid := "isle%d_anvil%d" % [i, k]
			if Game.taken.has(uid):
				continue
			var p: Vector2 = isl.anvils[k]
			add_heavy_stone("anvil_stone", Vector3(p.x, 0, p.y), hash(uid) % 628 / 100.0, -1.0, {"uid": uid})


const METEOR_CLEAR := 60.0   # a meteorite never lands this near anything you have built or put down
const PLAYER_MADE := ["houses", "docks", "stacks", "stashes", "drops", "fires", "workbenches",
	"fire_pots", "vessels", "traps", "soup_pots", "rafts", "furnaces", "composters", "clamps", "bedrolls"]


func player_made_spots() -> Array:
	## Where everything you have built or set down is (flat, x and z).
	var out := []
	for g in PLAYER_MADE:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and n.is_inside_tree():
				out.append(Vector2(n.global_position.x, n.global_position.z))
	return out


static func clear_of(p: Vector3, spots: Array, r := METEOR_CLEAR) -> bool:
	for s in spots:
		if (s as Vector2).distance_to(Vector2(p.x, p.z)) < r:
			return false
	return true


func meteor_fall(dir: Vector3) -> Vector3:
	## A meteorite comes down on dry land 60-300 m away, roughly along dir
	## (now and then out on an island): a smoking crater with the meteorite
	## half buried in it and lumps of meteoric iron strewn round, never within
	## METEOR_CLEAR of anything you have built or set down. Where it fell, or
	## Vector3.INF if it found nowhere dry and clear (lost in the water).
	var from: Vector3 = player.global_position if player else Vector3.ZERO
	var at := Vector3.INF
	var built := player_made_spots()
	if _rng.randf() < 0.15 and not terrain.islands.is_empty():
		var isl: Dictionary = terrain.islands[_rng.randi() % terrain.islands.size()]
		var a := _rng.randf() * TAU
		var p := Vector2(isl.x, isl.z) + Vector2(cos(a), sin(a)) * float(isl.r) * _rng.randf_range(0.0, 0.35)
		at = Vector3(p.x, ground_height(p.x, p.y), p.y)
		if not clear_of(at, built):
			at = Vector3.INF
	if not at.is_finite():
		for t in 40:
			var a := atan2(dir.z, dir.x) + _rng.randf_range(-0.6, 0.6) * (1.0 + t / 10.0)
			var d := _rng.randf_range(60.0, 300.0)
			var x := from.x + cos(a) * d
			var z := from.z + sin(a) * d
			var h := ground_height(x, z)
			if h > water_level() + 0.25 and clear_of(Vector3(x, h, z), built):
				at = Vector3(x, h, z)
				break
	if not at.is_finite() or at.y < water_level() + 0.1:
		return Vector3.INF
	add_crater(at, Game.time)
	var kg: float = [8.0, 15.0, 30.0][_rng.randi() % 3]
	add_heavy_stone("meteorite", at, _rng.randf() * TAU, kg, {"buried": true})
	var n := _rng.randi_range(3, 6)
	for i in n:
		for t in 6:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(3.0, 15.0)
			var p := at + Vector3(cos(a) * r, 0, sin(a) * r)
			p.y = ground_height(p.x, p.z)
			if p.y > water_level():
				spawn_pickup("meteoric_iron", 1, p + Vector3(0, 0.05, 0))
				break
	return at


func house_at(pos: Vector3, margin := 0.0) -> Node3D:
	## The house (or site) whose footprint pos is within, or null.
	for h in Game.houses:
		if h.covers(pos, margin):
			return h
	return null


func ladder_at(pos: Vector3) -> Node3D:
	## The house whose rope ladder pos (your feet) is on, or null.
	for h in Game.houses:
		if h.ladder_at(pos):
			return h
	return null


func sleep_blocker() -> String:
	## Why the player can't lie down right now, or "" if they can.
	if _sleeping or player.vitals.dead or player.grabbed_by:
		return "You can't sleep now."
	if player.hauling:
		return "Put down what you're carrying first (Q)."
	if player.fishing:
		return "Reel in your line first."
	if player.vitals.bleed_level() >= 2:
		return "Stop the bleeding first, or you won't wake up."
	if Game.debug:
		return ""  # sleep any time, anywhere
	var wait := Game.can_sleep_in()
	if wait > 0.0:
		return "You aren't tired enough to sleep yet (%d min)." % ceili(wait / 60.0)
	if player.riding and player.riding.out_on_water():
		return "Not out on the raft. Tie it up at a dock or step ashore first."
	if player.water_depth() > 0.0 and player.riding == null:
		return "You can't sleep in the water."
	if _hunted():
		return "Not with something hunting you!"
	return ""


func sleep_preview() -> String:
	## How this spot feels to sleep in, and whether sleeping now will save.
	var risk := sleep_risk(player.global_position)
	return "%s\nSleeping will save the game." % risk.feel


func request_sleep() -> void:
	## The sleep key: the first press describes the spot, the second lies down.
	if player.ui_open:
		return
	var why := sleep_blocker()
	if why != "":
		if not _sleeping:
			Game.notify(why)
		return
	if _sleep_confirm_t <= 0.0:
		hud.set_hint("%s\n%s again to lie down here." % [sleep_preview(), "Tap Sleep" if Settings.touch else "Press sleep (Z)"])
		_hint_t = 6.0
		_sleep_confirm_t = 6.0
		return
	_sleep_confirm_t = 0.0
	hud.set_hint("")
	_hint_t = 0.0
	sleep()


func sleep(on_bedroll := false) -> void:
	## Sleeps for Game.SLEEP_LENGTH, rolling for what goes wrong. On a bedroll
	## you heal faster while you sleep (Survival.BEDROLL_HEAL).
	if _sleeping:
		return
	_sleeping = true
	player.frozen = true
	var pos := player.global_position
	var risk := sleep_risk(pos)
	var night := Game.night_index()
	await hud.fade_to(Color(0, 0, 0, 1), 1.2).finished

	var attacker := ""
	if _rng.randf() < risk.amphibian:
		attacker = "uranocentrodon"
	elif _rng.randf() < risk.predator:
		attacker = "scorpion"
	var slept := Game.SLEEP_LENGTH * (_rng.randf_range(0.15, 0.9) if attacker != "" else 1.0)
	# Wildlife moves on while you sleep; the spawner refills the area.
	for c in Game.creatures.duplicate():
		if is_instance_valid(c) and not c.dead:
			c.queue_free()
	player.vitals.on_bedroll = on_bedroll
	_pass_time(slept)
	player.vitals.on_bedroll = false

	var v = player.vitals
	var news := _compost_pests()
	_check_traps()
	if _rng.randf() < risk.bites:
		var n := _rng.randi_range(1, 2)
		for i in n:
			v.add_wound(_rng.randf_range(0.08, 0.2), 0.45, "bite")
		news.append("Something bit you in the night.")
	if risk.leeches and _rng.randf() < 0.5:
		v.lose_blood(6.0)
		v.protein = maxf(v.protein - 8.0, 0.0)
		v.add_wound(0.1, 0.5, "leech")
		news.append("Leeches cling to your legs, fat with your blood.")
	if _rng.randf() < risk.flood:
		v.chill = maxf(v.chill, 300.0)
		for w in v.wounds:
			w.dirt = minf(w.dirt + 0.5, 1.0)
		var lost := _wash_away(_rng.randi_range(1, 2))
		news.append("You wake in rising water, soaked through." + (" Some of your things were swept away: %s." % ", ".join(lost) if not lost.is_empty() else ""))
	elif _rng.randf() < risk.chill:
		v.chill = maxf(v.chill, 240.0)
		news.append("You wake cold and stiff from the damp.")
	Game.last_sleep = Game.time
	_sleeping = false
	player.frozen = false
	if v.dead:
		return
	v.slept()  # sprains and broken bones mend a step

	if attacker != "":
		hud.set_fade(Color(0, 0, 0, 0))
		_wake_attack(attacker)
		_pending_save = 30.0  # saved once you have come through it
		_pending_night = night
	else:
		hud.fade_to(Color(0, 0, 0, 0), 1.5)
		news.push_front("You wake up." if news.is_empty() else "A bad night.")
		for m in news:
			Game.notify(m)
		Game.saved_night = night
		save_now()  # every sleep saves, a daytime nap as well as a night
	if attacker != "":
		for m in news:
			Game.notify(m)
	Game.crafted.emit("slept")


func _pass_time(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not player.vitals.dead:
		var d := minf(5.0, seconds - t)
		Game.time += d
		player.vitals.tick(d, false, false, false, true)
		t += d
	Game.inventory.tick(seconds)
	# How long each fire burns of that, for the soup pots hanging over them.
	var burns := {}
	for f in Game.fires:
		burns[f] = minf(f.fuel / (1.8 if raining else 1.0), seconds) if f.lit else 0.0
	for f in Game.fires.duplicate():
		f._process(seconds)
	for sp in get_tree().get_nodes_in_group("fire_pots"):
		sp.advance(seconds, burns.get(sp.fire, 0.0) if sp.hung() and sp.hauled_by == null else 0.0)
	weather.update(seconds)
	_update_weather(seconds)


func _wash_away(n: int) -> Array:
	## A flood carries off a few light, loose things (never tools or the sack).
	var inv = Game.inventory
	var candidates := []
	for i in inv.SIZE:
		var s = inv.slots[i]
		if s != null and Items.def(s.id).get("tags", []).is_empty() and not Items.def(s.id).has("damage"):
			candidates.append(i)
	candidates.shuffle()
	var lost := []
	for i in candidates.slice(0, n):
		lost.append(Items.item_name(inv.slots[i].id))
		inv.take(i, inv.slots[i].n)
	return lost


func _wake_attack(species: String) -> void:
	var p := player.global_position
	if species == "uranocentrodon":
		var wp := water_point(p, 40.0, -0.9)
		if not wp.is_finite():
			wp = p + Vector3(8, 0, 0)
		var dir := Vector3(wp.x - p.x, 0, wp.z - p.z).normalized()
		var pos := p + dir * 2.6
		pos.y = ground_height(pos.x, pos.z)
		var c := spawn_amphibian("uranocentrodon", "hide", pos, wp)
		c.attack_now(player)
		hud.show_message("You wake to jaws closing on you!")
	else:
		var a := _rng.randf() * TAU
		var pos := p + Vector3(cos(a), 0, sin(a)) * 2.5
		pos.y = ground_height(pos.x, pos.z)
		var c := Creature.new().setup(species, pos, self)
		add_child(c)
		c.state = "chase"
		c.take_damage(0.0, player)
		player.hurt(c.def.damage, pos, 0.4, species)
		hud.show_message("You wake to something tearing at you!")


func save_now() -> bool:
	## The camp save: written when you sleep through a night, or at any moment
	## in debug mode.
	if player.vitals.dead:
		return false
	close_work()
	var ok := Game.save_game(_world_state())
	Game.notify("Game saved." if ok else "The game could not be saved!")
	return ok


func suspend_blocker() -> String:
	## Why you can't save and quit right now, or "" if you can. Debug mode
	## lifts every limit but death.
	if player.vitals.dead:
		return "You are dead."
	if Game.debug:
		return ""
	if player.grabbed_by:
		return "Not while it has you in its jaws!"
	if _sleeping:
		return "Not while you sleep."
	if player.riding and player.riding.out_on_water():
		return "Not out on the raft. Tie it up at a dock or step ashore first."
	if _hunted():
		return "Not with something hunting you!"
	return ""


func save_suspend() -> bool:
	## Save where you stand before quitting. Continue picks up from here once;
	## the camp save is left alone, so dying later still sends you back to camp.
	if suspend_blocker() != "":
		return false
	close_work()
	return Game.save_game(_world_state(), true)


func _world_state() -> Dictionary:
	var fires := []
	for f in Game.fires:
		if not f.is_queued_for_deletion() and not f.hearth:
			fires.append(f.to_dict())  # a fireplace is saved with its house
	var houses := []
	for h in Game.houses:
		if not h.is_queued_for_deletion():
			houses.append(h.to_dict())
	var docks := []
	for d in Game.docks:
		if not d.is_queued_for_deletion():
			docks.append(d.to_dict())
	var rafts := []
	for r in Game.rafts:
		if not r.is_queued_for_deletion():
			rafts.append(r.to_dict())
	var furnaces := []
	for f in get_tree().get_nodes_in_group("furnaces"):
		if not f.is_queued_for_deletion():
			furnaces.append(f.to_dict())
	var clamps := []
	for c in get_tree().get_nodes_in_group("clamps"):
		if not c.is_queued_for_deletion():
			clamps.append(c.to_dict())
	var stones := []
	for g in ["anvils", "meteorites"]:
		for st in get_tree().get_nodes_in_group(g):
			if not st.is_queued_for_deletion() and (st.uid == "" or Game.taken.has(st.uid)):
				stones.append(st.to_dict())  # an island's anvil stone untouched is made again from the seed
	var craters := []
	for c in get_tree().get_nodes_in_group("craters"):
		if not c.is_queued_for_deletion() and c.smoking():
			craters.append(c.to_dict())
	var stashes := []
	for s in get_tree().get_nodes_in_group("stashes"):
		if not s.is_queued_for_deletion():
			stashes.append(s.to_dict())
	var composters := []
	for c in get_tree().get_nodes_in_group("composters"):
		if not c.is_queued_for_deletion():
			composters.append(c.to_dict())
	var bedrolls := []
	for b in get_tree().get_nodes_in_group("bedrolls"):
		if not b.is_queued_for_deletion():
			bedrolls.append(b.to_dict())
	var traps := []
	for t in get_tree().get_nodes_in_group("traps"):
		if not t.is_queued_for_deletion():
			traps.append(t.to_dict())
	var drops := []
	for d in get_tree().get_nodes_in_group("drops"):
		if not d.is_queued_for_deletion():
			drops.append(d.to_dict())
	var carcasses := []
	for c in Game.creatures:
		if is_instance_valid(c) and c.dead and not c.is_queued_for_deletion() and c._eater() == null and not c.expired():
			carcasses.append(c.carcass_dict())
	var guts := []
	for g in get_tree().get_nodes_in_group("guts"):
		if not g.is_queued_for_deletion():
			guts.append(g.to_dict())
	var stacks := []
	for st in get_tree().get_nodes_in_group("stacks"):
		if not st.is_queued_for_deletion():
			stacks.append(st.to_dict())
	var logs := []
	for lg in get_tree().get_nodes_in_group("logs"):
		if not lg.is_queued_for_deletion():
			logs.append(lg.to_dict())
	var felled := []
	for ft in get_tree().get_nodes_in_group("felled"):
		if not ft.is_queued_for_deletion():
			felled.append(ft.to_dict())
	var benches := []
	for b in get_tree().get_nodes_in_group("workbenches"):
		if not b.is_queued_for_deletion():
			benches.append(b.to_dict())
	var soup_pots := []
	for sp in get_tree().get_nodes_in_group("soup_pots"):
		if not sp.is_queued_for_deletion():
			soup_pots.append(sp.to_dict())
	var vessels := []
	for v in get_tree().get_nodes_in_group("vessels"):
		if not v.is_queued_for_deletion():
			vessels.append(v.to_dict())
	var shore := []
	for e in _shore:
		if is_instance_valid(e.node) and not e.node.is_queued_for_deletion():
			var sp: Vector3 = e.node.global_position
			shore.append({"id": e.node.item_id, "pos": [sp.x, sp.y, sp.z], "until": e.until})
	var p := player.global_position
	return {
		"player": {"pos": [p.x, p.y, p.z], "yaw": player.rotation.y},
		"vitals": player.vitals.to_dict(),
		"fires": fires,
		"houses": houses,
		"docks": docks,
		"rafts": rafts,
		"furnaces": furnaces,
		"clamps": clamps,
		"stones": stones,
		"craters": craters,
		"stashes": stashes,
		"composters": composters,
		"bedrolls": bedrolls,
		"traps": traps,
		"drops": drops,
		"carcasses": carcasses,
		"guts": guts,
		"stacks": stacks,
		"logs": logs,
		"felled_trees": felled,
		"workbenches": benches,
		"soup_pots": soup_pots,
		"vessels": vessels,
		"shore": shore,
		"waypoint": [waypoint.x, waypoint.y, waypoint.z] if waypoint.is_finite() else [],
		"raining": raining,
		"weather_t": _weather_t,
		"events": weather.to_dict(),
	}


func _hunted() -> bool:
	for c in Game.creatures:
		if is_instance_valid(c) and not c.dead and c.state in ["chase", "attack", "charge", "strike", "stalk", "approach"] \
				and c.global_position.distance_to(player.global_position) < 30.0:
			return true
	return false


func _apply_restore(r: Dictionary) -> void:
	player.rotation.y = float(r.player.yaw)
	player.vitals.from_dict(r.vitals)
	for d in r.get("houses", []):
		# First, so what was left on their floors goes back up there.
		add_house(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), d)
	for d in r.get("docks", []):
		add_dock(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), d)
	for d in r.get("rafts", []):
		# Before the logs and sacks that rode on them, which it takes back on.
		add_raft(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), d)
	for f in r.fires:
		_add_fire(Vector3(f.pos[0], f.pos[1], f.pos[2]), float(f.fuel), false).from_dict(f)
	for sd in r.get("stashes", []):
		_add_stash(Vector3(sd.pos[0], sd.pos[1], sd.pos[2])).from_dict(sd)
	for cd in r.get("composters", []):
		add_compost(Vector3(cd.pos[0], cd.pos[1], cd.pos[2])).from_dict(cd)
	for bd in r.get("bedrolls", []):
		add_bedroll(Vector3(bd.pos[0], bd.pos[1], bd.pos[2])).from_dict(bd)
	for td in r.get("traps", []):
		if td.get("kind", "") in ["fish_trap", "snare"]:
			add_trap(td.kind, Vector3(td.pos[0], td.pos[1], td.pos[2])).from_dict(td)
	for d in r.get("drops", []):
		if Items.exists(d.get("id", "")):
			spawn_pickup(d.id, int(d.n), Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.age), true, d.get("data", {}))
	for d in r.get("carcasses", []):
		if Creature.SPECIES.has(d.get("species", "")):
			var c := Creature.new().setup(d.species, Vector3(d.pos[0], d.pos[1], d.pos[2]), self)
			add_child(c)
			c.restore_carcass(d)
	for d in r.get("guts", []):
		var pile := Guts.new().setup(int(d.n), bool(d.get("skin", false)), self)
		pile.made = float(d.made)
		pile.roll_t = float(d.get("roll_t", Guts.ROLL_EVERY))
		add_child(pile)
		pile.global_position = Vector3(d.pos[0], d.pos[1], d.pos[2])
	for d in r.get("stacks", []):
		if Items.exists(d.get("id", "")):
			add_stack(d.id, int(d.n), Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), String(d.get("kind", "")))
	for d in r.get("logs", []):
		if Items.exists(d.get("id", "")):
			add_log(d.id, Vector3(d.pos[0], d.pos[1], d.pos[2]), 0.0).from_dict(d)
	for d in r.get("furnaces", []):
		add_furnace(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), d)
	for d in r.get("clamps", []):
		add_clamp(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), d)
	for d in r.get("stones", []):
		if String(d.get("id", "")) in ["anvil_stone", "meteorite"]:
			add_heavy_stone(d.id, Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0)), float(d.get("mass", -1.0)), d)
	for d in r.get("craters", []):
		add_crater(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("made_at", 0.0)))
	for d in r.get("felled_trees", []):
		if Chunk.TREES.has(d.get("kind", "")):
			add_felled(d.kind, float(d.s), float(d.lo), Vector3(d.dir[0], 0, d.dir[1]),
					Vector3(d.pos[0], d.pos[1], d.pos[2])).from_dict(d)
	for d in r.get("workbenches", []):
		add_bench(Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.get("yaw", 0.0))).from_dict(d)
	for d in r.get("soup_pots", []):
		if String(d.get("id", "")).begins_with("soup_pot") and Items.exists(d.id):
			var at := Vector3(d.pos[0], d.pos[1], d.pos[2])
			var sp := add_soup_pot(d.id, at)
			sp.from_dict(d)
			if d.get("hung", false):
				for f in Game.fires:
					if Vector2(f.global_position.x - at.x, f.global_position.z - at.z).length() < 0.3:
						sp.fire = f
						sp.global_position = f.global_position
	for d in r.get("vessels", []):
		if String(d.get("id", "")).begins_with("vessel_") and Items.exists(d.id):
			var at := Vector3(d.pos[0], d.pos[1], d.pos[2])
			var v := add_vessel(d.id, at)
			v.from_dict(d)
			if d.get("hung", false):
				for f in Game.fires:
					if Vector2(f.global_position.x - at.x, f.global_position.z - at.z).length() < 0.3:
						v.fire = f
						v.global_position = f.global_position
	for d in r.get("shore", []):
		if Items.exists(d.get("id", "")):
			add_shore_item(d.id, Vector3(d.pos[0], d.pos[1], d.pos[2]), float(d.until))
	var wp: Array = r.get("waypoint", [])
	if wp.size() == 3:
		set_waypoint(Vector3(wp[0], wp[1], wp[2]))
	raining = bool(r.raining)
	_weather_t = float(r.weather_t)
	weather.from_dict(r.get("events", {}))
	_rain.emitting = raining
	if raining:
		_rain_sound.play()
	hud.set_fade(Color(0, 0, 0, 1))
	hud.fade_to(Color(0, 0, 0, 0), 2.0)
	if r.get("suspended", false):
		hud.show_message("Day %d. You pick up where you left off." % (Game.day() + 1))
	else:
		hud.show_message("Day %d. You wake at your camp." % (Game.day() + 1))


const DEATHS := {
	"blood": "You bled to death.", "venom": "The venom stopped your heart.", "infection": "Sepsis killed you.",
	"starving": "You starved to death.", "thirst": "You died of thirst.", "drowning": "You drowned.",
	"alcohol": "Alcohol poisoning killed you.",
}
const EASED := {
	"blood": "In your save you have lost a little less blood, and your wounds bleed a little less.",
	"venom": "In your save there is a little less venom in you.",
	"alcohol": "In your save you have had four fewer drinks.",
	"infection": "In your save your worst infection is a stage less serious.",
	"starving": "In your save you are a little less starved.",
	"thirst": "In your save you are a little less parched.",
}


func _on_player_died() -> void:
	var how := "You lasted %d day%s in the Carboniferous swamp." % [Game.day() + 1, "" if Game.day() == 0 else "s"]
	var cause: String = player.vitals.cause
	if player.grabbed_by:
		var who: String = player.grabbed_by.def.name
		how = ("A %s mauled you.\n" % who if player.grabbed_by.mode == "land" else "A %s dragged you into the swamp.\n" % who) + how
	elif DEATHS.has(cause):
		how = DEATHS[cause] + "\n" + how
	# So a save can't be stuck dying of the same thing, it is eased a step in
	# whatever killed you (Survival.ease).
	if EASED.has(cause) and Game.ease_saves(cause):
		how += "\n\n" + EASED[cause]
	var save := Game.read_save()
	hud.show_death(how, not save.is_empty() and int(save.run) == Game.run_id)
