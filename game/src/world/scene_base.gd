extends Node3D
## Shared setup for playable scenes: player, HUD, inventory, pause and death.

const Player := preload("res://src/player/player.gd")
const Hud := preload("res://src/ui/hud.gd")
const InventoryUI := preload("res://src/ui/inventory_ui.gd")
const PauseMenu := preload("res://src/ui/pause_menu.gd")
const Pickup := preload("res://src/world/pickup.gd")
const WorkSpot := preload("res://src/world/work_spot.gd")
const WorkUI := preload("res://src/ui/work_ui.gd")
const TouchControls := preload("res://src/ui/touch_controls.gd")

const BENCH_SINK := 0.2  # how deep a workbench leg may stand in higher ground

var where := "swamp"
var player: CharacterBody3D
var hud: CanvasLayer
var inv_ui: Control
var work_ui: Control
var pause: Control
var _captured := false
var _touch: Control = null
var _ui_layer: CanvasLayer
var work: Node3D = null    # the spot on the ground being worked at, while crafting
var wind := Vector3.ZERO   # m/s; high winds carry thrown things and flyers


func setup_common(spawn: Vector3, vitals: bool) -> void:
	player = Player.new()
	player.world = self
	player.vitals_enabled = vitals
	add_child(player)
	player.global_position = spawn

	hud = Hud.new()
	add_child(hud)
	hud.bind_player(player)
	hud.show_vitals = vitals
	hud.title_requested.connect(func(): Game.goto("title"))
	hud.load_requested.connect(func(): Game.load_game())

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	_ui_layer = ui_layer
	inv_ui = InventoryUI.new()
	inv_ui.where = where
	inv_ui.player = player
	ui_layer.add_child(inv_ui)
	work_ui = WorkUI.new()
	ui_layer.add_child(work_ui)
	work_ui.leave.connect(close_work)
	pause = PauseMenu.new()
	pause.world = self
	ui_layer.add_child(pause)
	_show_touch()
	Settings.input_changed.connect(_show_touch)
	pause.resumed.connect(func(): player.capture_mouse(not player.ui_open))

	player.died.connect(_on_player_died)
	player.capture_mouse(true)

	if Game.dev.has("give"):
		for part in Game.dev["give"].split(","):
			var kv: PackedStringArray = part.split(":")
			Game.inventory.add(kv[0], int(kv[1]) if kv.size() > 1 else 1)
	if Game.dev.has("wound"):
		player.vitals.add_wound(0.45, 0.8, "dev")
		player.vitals.wounds[0].inf = player.vitals.INF_MINOR
	if Game.dev.has("condition"):
		for id in String(Game.dev["condition"]).split(",", false):
			if not player.vitals.give_condition(id):
				push_warning("--condition: no condition '%s'" % id)
	if Game.dev.has("open-inventory"):
		toggle_inventory.call_deferred()
		if String(Game.dev["open-inventory"]) in ["recipes", "health"]:
			inv_ui.show_page.call_deferred(String(Game.dev["open-inventory"]))
	if Game.dev.has("open-pause"):
		pause.open.call_deferred()
	if Game.dev.has("open-debug") and has_method("open_debug"):
		call_deferred("open_debug")
	if Game.dev.has("work"):
		_dev_work.call_deferred()


func _show_touch() -> void:
	## The on-screen controls, while Settings.touch (switched in Settings).
	if Settings.touch and _touch == null:
		var touch := TouchControls.new()
		touch.player = player
		touch.hud = hud
		touch.pause_menu = pause
		_ui_layer.add_child(touch)
		_ui_layer.move_child(touch, 0)  # under the menus
		_touch = touch
	elif not Settings.touch and _touch != null:
		_touch.queue_free()
		_touch = null


func _input(event: InputEvent) -> void:
	if player == null or pause.visible:
		return
	if event.is_action_pressed("pause"):
		if work:
			close_work()
		elif inv_ui.visible:
			toggle_inventory()
		elif not player.vitals.dead:
			player.capture_mouse(false)
			pause.open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and not player.vitals.dead and not player.frozen:
		if player.hauling:
			Game.notify("Your hands are full. Put the %s down first (Q)." % player.hauling.haul_name())
		else:
			close_work()
			toggle_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("craft"):
		if work:
			close_work()
		elif not inv_ui.visible:
			start_work()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_panel") and Game.debug and has_method("open_debug"):
		call("open_debug")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_save") and Game.debug and has_method("save_now"):
		call("save_now")
		get_viewport().set_input_as_handled()


func _dev_work() -> void:
	## --work=id:n,... kneels and lays those items out; --work-make=out starts
	## that recipe and --work-steps=N does N steps of it (strikes, for knapping).
	## With --trap, you kneel at the trap to bait it.
	var traps := get_tree().get_nodes_in_group("traps")
	if Game.dev.has("trap") and not traps.is_empty():
		start_trap_work(traps[0])
	else:
		start_work()
	if work == null:
		return
	for part in String(Game.dev["work"]).split(",", false):
		var kv: PackedStringArray = part.split(":")
		var i: int = Game.inventory.find(kv[0])
		if i >= 0:
			work.lay(i, int(kv[1]) if kv.size() > 1 else 1)
	if not Game.dev.has("work-make"):
		return
	work.begin(Items.recipe_for(Game.dev["work-make"], where))
	var n := int(Game.dev.get("work-steps", "0"))
	for k in n:
		match work.recipe.get("act", ""):
			"steps":
				work.step()
			"twist":
				work.twist(0.1)
			"knap":
				var keep := Items.knap_grid(work.recipe.knap)
				for c in 25:
					if work.knap_grid[c] and not keep[c]:
						work.strike(c)
						break


func work_blocker(at: Vector3, wet_ok := false) -> String:
	## Why you can't kneel and work at `at` right now, or "".
	if player.vitals.dead or player.frozen or player.grabbed_by:
		return "You can't do that now."
	if player.hauling:
		return "Put the %s down first (Q)." % player.hauling.haul_name()
	if wet_ok:
		return ""
	var g := floor_height(at)
	if g > -INF and g < water_level() - 0.1:
		return "It's too wet to work here."
	return ""


func start_work() -> void:
	## Kneel and craft by hand on the ground in front of you, or butcher the
	## carcass you are looking at where it lies. A small one is picked up and
	## laid out in front of you. Kneeling at a tree, a felled trunk or a log
	## works the wood instead, and at a workbench you work on its top
	## (work_spot.gd).
	if work or inv_ui.visible or player.ui_open:
		return
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var at := player.global_position + fwd * 0.75
	at.y = player.global_position.y
	var f: Object = player.focus
	if f != null and is_instance_valid(f) and f.has_method("craft_interact") and not player.hauling \
			and (not f.has_method("wants_craft") or f.wants_craft()):
		f.craft_interact(player)  # a soup pot: pick it up to carry
		return
	if f != null and is_instance_valid(f) and f.has_method("station_kind") and f.station_kind() != "" and not player.hauling:
		# A furnace, an anvil or a meteorite: work at it (metals.md).
		_kneel_beside(f, "station", {"station_kind": f.station_kind()})
		return
	var bench := bench_ahead()
	if bench and not player.hauling:
		_start_bench_work(bench)
		return
	if has_method("wood_ahead") and not player.hauling \
			and (f == null or not is_instance_valid(f) or not ("species" in f)):
		var wood: Node3D = call("wood_ahead")
		var tree: Dictionary = call("tree_ahead") if wood == null and carcass_ahead() == null else {}
		if wood or not tree.is_empty():
			_start_wood_work(wood, tree)
			return
	var carcass := carcass_ahead()
	if carcass and carcass.gnawed and carcass.def.size == "small":
		carcass = null  # only scraps left on it: take them with E
	if carcass and carcass._eater():
		Game.notify("The %s is eating it." % carcass._eater().def.name)
		return
	# Looking at the water with a washing pan: wash copper there, kneeling
	# at the edge (metals.md).
	var washing: bool = carcass == null and bool(player.get("focus_water")) and Game.inventory.count("washing_pan") > 0
	if washing:
		at = player.global_position + fwd * 0.35
	var why := work_blocker(at, carcass != null or washing)
	if why != "":
		Game.notify(why)
		return
	var small: String = carcass.def.get("carcass", "") if carcass and carcass.haul_mode() == "" else ""
	if small != "" and not carcass.take_small(player):
		return
	if carcass and small == "":
		# Kneel at the near side of the carcass, facing it.
		var to := player.global_position - carcass.global_position
		to.y = 0.0
		at = carcass.global_position + to.normalized() * minf(carcass.def.radius * 0.6, maxf(to.length() - 0.5, 0.0))
	var g := floor_height(Vector3(at.x, player.global_position.y, at.z))
	at.y = g if g > -INF else player.global_position.y
	work = WorkSpot.new()
	work.where = where
	work.player = player
	if washing:
		work.station_kind = "water"
	if carcass and small == "":
		work.carcass = carcass
	add_child(work)
	work.global_transform = Transform3D(Basis(Vector3.UP, player.rotation.y), at)
	if small != "":
		var i: int = Game.inventory.find(small)
		if i >= 0:
			work.lay(i)
	player.ui_open = true
	player.work_spot = work
	player.capture_mouse(false)
	work_ui.open(work)


func _start_wood_work(wood: Node3D, tree: Dictionary) -> void:
	## Kneel beside the wood, facing it: at the foot of a standing tree, by the
	## cut end of a felled trunk (2 m along, where the next log comes off), or
	## at the side of a loose log.
	var p := player.global_position
	var centre: Vector3
	var r: float
	var axis := Vector3.ZERO  # a lying trunk or log runs this way
	if not tree.is_empty():
		centre = tree.at
		r = tree.r
	elif wood.has_method("cut_point"):
		centre = wood.cut_point()
		r = wood.radius()
		axis = wood.dir
		if Vector2(centre.x - p.x, centre.z - p.z).length() > 3.5:
			Game.notify("Kneel by the cut end of the trunk to cut logs off it.")
			return
	else:
		centre = wood.global_position
		r = Assets.LOG_R
		axis = wood.global_basis.x
	var side := Vector3(p.x - centre.x, 0, p.z - centre.z)
	if axis != Vector3.ZERO:
		# Square on to the trunk, on whichever side you are.
		var across := Vector3(axis.x, 0, axis.z).normalized().cross(Vector3.UP)
		side = across if side.dot(across) >= 0.0 else -across
	side = side.normalized() if side.length() > 0.01 else -fwd_flat()
	var at := centre + side * (r + 0.1)
	var why := work_blocker(at, true)
	if why != "":
		Game.notify(why)
		return
	var yaw := atan2(side.x, side.z)  # facing the wood: local +Z back toward you
	var stand := centre + side * (r + 1.2)
	# On a house's floor (wood brought indoors) you kneel there, not on the
	# ground under it.
	var sg := floor_height(Vector3(stand.x, p.y, stand.z))
	var up := floor_height(p) > ground_height(p.x, p.z) + 0.5  # standing on a floor now
	if up and sg < p.y - 0.5:
		stand = p  # that spot is off the floor (past a wall): kneel where you are
		sg = p.y
	player.global_position = Vector3(stand.x, sg if sg > -INF else p.y, stand.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	var g := floor_height(Vector3(at.x, player.global_position.y, at.z))
	if up and g < player.global_position.y - 0.5:
		g = player.global_position.y
	at.y = g if g > -INF else player.global_position.y
	work = WorkSpot.new()
	work.where = where
	work.player = player
	work.wood = wood
	work.tree = tree
	add_child(work)
	work.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	player.ui_open = true
	player.work_spot = work
	player.capture_mouse(false)
	work_ui.open(work)


func start_trap_work(trap: Node3D) -> void:
	## Kneel beside a fish trap or a snare (trap.gd), facing it, to bait it
	## with bait laid out on the ground (work_spot.trap_options).
	_kneel_beside(trap, "trap")


func start_plot_work(plot: Node3D) -> void:
	## Kneel beside a dug hole (plot.gd) to plant in it what you lay out
	## (work_spot.plot_options).
	_kneel_beside(plot, "plot")


func _kneel_beside(target: Node3D, field: String, extra := {}) -> void:
	## Kneel facing a thing on the ground, the work spot just short of it, for
	## work done on the thing itself (work_spot's `field` set to it).
	if work or inv_ui.visible or player.ui_open:
		return
	var centre := target.global_position
	var side := Vector3(player.global_position.x - centre.x, 0, player.global_position.z - centre.z)
	side = side.normalized() if side.length() > 0.01 else -fwd_flat()
	var at := centre + side * 0.45
	var why := work_blocker(at, true)
	if why != "":
		Game.notify(why)
		return
	var yaw := atan2(side.x, side.z)
	var stand := centre + side * 1.25
	var sg := floor_height(Vector3(stand.x, player.global_position.y, stand.z))
	player.global_position = Vector3(stand.x, sg if sg > -INF else player.global_position.y, stand.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	var g := floor_height(Vector3(at.x, player.global_position.y, at.z))
	at.y = g if g > -INF else player.global_position.y
	work = WorkSpot.new()
	work.where = where
	work.player = player
	work.set(field, target)
	for k in extra:
		work.set(k, extra[k])
	add_child(work)
	work.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	player.ui_open = true
	player.work_spot = work
	player.capture_mouse(false)
	work_ui.open(work)


func bench_ahead() -> Node3D:
	## The workbench you are looking at (or at a tool on its rack), or else one
	## right in front of you.
	var f: Object = player.focus
	if f != null and is_instance_valid(f):
		if f.is_in_group("workbenches"):
			return f
		if "bench" in f and f.bench is Node3D:
			return f.bench
	var fwd := fwd_flat()
	for b in get_tree().get_nodes_in_group("workbenches"):
		if b.hauled_by:
			continue
		var to: Vector3 = b.global_position - player.global_position
		to.y = 0.0
		if to.length() < 1.3 and to.normalized().dot(fwd) > 0.5:
			return b
	return null


func _start_bench_work(bench: Node3D) -> void:
	## Stand at the front of the bench, facing it, and work on its top.
	var why := work_blocker(bench.global_position, true)
	if why != "":
		Game.notify(why)
		return
	var size: Vector3 = Assets.BENCH_SIZE
	var stand: Vector3 = bench.to_global(Vector3(0, 0, size.z * 0.5 + 0.65))
	var sg := floor_height(stand)
	player.global_position = Vector3(stand.x, sg if sg > -INF else bench.global_position.y, stand.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = bench.global_rotation.y
	if bench.has_method("teach"):
		bench.teach()
	work = WorkSpot.new()
	work.where = where
	work.tier = "bench"
	work.player = player
	work.bench = bench
	add_child(work)
	work.global_transform = Transform3D(Basis(Vector3.UP, bench.global_rotation.y), bench.to_global(Vector3(0, size.y, 0.1)))
	player.ui_open = true
	player.work_spot = work
	player.capture_mouse(false)
	work_ui.open(work)


func start_house_work(house: Node3D, carried: Node3D = null) -> void:
	## Build the next part of a house (house.gd): stood where it is built from,
	## facing it, with steps clicked on the house itself. A stilt is raised
	## from a Calamites log carried there (`carried`).
	if work or inv_ui.visible or player.ui_open:
		return
	if player.vitals.dead or player.frozen or player.grabbed_by:
		return
	if player.hauling and player.hauling != carried:
		Game.notify("Put the %s down first (Q)." % player.hauling.haul_name())
		return
	var p: Dictionary = house.next_part()
	if p.is_empty():
		return
	if p.get("log", false) and carried == null:
		Game.notify("Next: %s. Carry a Calamites log here in your arms and press E." % p.verb.to_lower())
		return
	var stand: Vector3 = house.stand_point(p, player)
	if stand.is_finite():
		player.global_position = stand
	player.velocity = Vector3.ZERO
	var to: Vector3 = house.face_point(p) - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	work = WorkSpot.new()
	work.where = where
	work.player = player
	work.house = house
	if carried:
		# The log is set down at the foot of the stilt while you work.
		work.house_log = carried
		player.hauling = null
		carried.visible = false
	add_child(work)
	work.global_transform = Transform3D(Basis(Vector3.UP, player.rotation.y), player.global_position)
	player.ui_open = true
	player.work_spot = work
	player.capture_mouse(false)
	work_ui.open(work)


func fwd_flat() -> Vector3:
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized()


func carcass_ahead() -> Node3D:
	## The dead animal you are looking at, or else one lying right in front of you.
	var f: Object = player.focus
	if f != null and is_instance_valid(f) and "species" in f and f.dead and not f.in_jaws():
		return f
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	var best: Node3D = null
	var best_d := INF
	for c in Game.creatures:
		if not is_instance_valid(c) or not c.dead or c.hauled_by or c.in_jaws() or c.is_queued_for_deletion():
			continue
		var to: Vector3 = c.global_position - player.global_position
		to.y = 0.0
		var d: float = to.length() - c.def.radius
		if d < 1.6 and d < best_d and (to.length() < 0.5 or to.normalized().dot(fwd.normalized()) > 0.3):
			best = c
			best_d = d
	return best


func close_work() -> void:
	## Stand up: whatever is laid out goes back into your inventory.
	if work == null:
		return
	work.return_all()
	work_ui.close()
	work.queue_free()
	work = null
	player.work_spot = null
	player.ui_open = false
	if not player.vitals.dead:
		player.capture_mouse(true)


func close_ui() -> void:
	## Closes whatever menu or work is open.
	if work:
		close_work()
	elif inv_ui.visible:
		toggle_inventory()


func open_stash(stash: Node) -> void:
	## Opens the inventory beside a stash's contents.
	if inv_ui.visible or player.vitals.dead:
		return
	inv_ui.open(stash)
	player.ui_open = true
	player.capture_mouse(false)


func toggle_inventory() -> void:
	if inv_ui.visible:
		inv_ui.close()
		player.ui_open = false
		player.capture_mouse(true)
	else:
		inv_ui.open()
		player.ui_open = true
		player.capture_mouse(false)


func _physics_process(_delta: float) -> void:
	# In a browser Esc releases the pointer lock before the game sees the key,
	# so losing the lock while playing opens the pause menu, as Esc would.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _captured and not captured and OS.has_feature("web") and player and not player.ui_open \
			and not player.vitals.dead and not pause.visible:
		pause.open()
	_captured = captured


func _notification(what: int) -> void:
	# Pause when the window loses focus (or the app is backgrounded on Android).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player and pause and not pause.visible \
			and not player.vitals.dead and not Game.dev.has("selftest") and not Game.dev.has("shot"):
		player.capture_mouse(false)
		pause.open()


func spawn_pickup(id: String, n: int, pos: Vector3, age := 0.0, keep := true, data := {}) -> void:
	## Drops items on the ground. Unless `keep` is false (discarded), they are
	## saved with the world and still there after a reload. `data` is a one of
	## a kind item's own values (see Inventory).
	var p := Pickup.new().setup(id, n, age)
	if data is Dictionary and not data.is_empty():
		p.data = data.duplicate(true)
	if keep:
		p.add_to_group("drops")
	add_child(p)
	var ground := floor_height(pos)
	p.global_position = Vector3(pos.x, maxf(ground, minf(pos.y, ground + 0.1)) if ground > -INF else pos.y, pos.z)


func ground_height(_x: float, _z: float) -> float:
	return -INF


func floor_height(p: Vector3) -> float:
	## What something set down at p stands on: the ground, or a floor built
	## over it (swamp.gd, a house's).
	return ground_height(p.x, p.z)


func bench_height(at: Vector3, yaw: float) -> float:
	## Where a workbench set up at `at` stands: on the ground under its middle,
	## raised so the top stays clear of the highest ground under its legs
	## (the legs on lower ground reach down to it, workbench.gd).
	var y := floor_height(at)
	for c in Assets.bench_legs():
		y = maxf(y, floor_height(at + Basis(Vector3.UP, yaw) * c) - BENCH_SINK)
	return y


func bench_blocker(at: Vector3, yaw: float, exclude: Array = []) -> String:
	## What a workbench set up at `at` facing `yaw` still needs, or "": dry
	## ground with nothing in the way. Uneven ground will do.
	var lo := INF
	var hi := -INF
	for c in [Vector3.ZERO] + Assets.bench_legs():
		var h := floor_height(at + Basis(Vector3.UP, yaw) * c)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if lo < water_level():
		return "drier ground to build on"
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Assets.BENCH_SIZE.x, 1.0, Assets.BENCH_SIZE.z)
	q.shape = box
	q.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, hi + 0.6, at.z))
	q.collision_mask = 1
	q.exclude = exclude
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return "room to build (something is in the way)"
	return ""


func water_level() -> float:
	return -INF


func _on_player_died() -> void:
	pass
