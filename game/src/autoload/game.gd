extends Node
## Game flow and shared run state: scene switching, world time, registries of
## creatures and fires (used by AI), and developer command-line options.
##
## Developer options are passed after `--`, e.g.
##   godot-runner --path game -- --start=swamp --time=0.5 --shot=/tmp/a.png
## Supported: --start=title|lab|swamp|continue (lab and swamp play the "dev" world),
## --seed=N, --time=0..1 (time of day),
## --shot=PATH (save a screenshot and quit), --shot-delay=SECONDS,
## --selftest (run for a few seconds then quit), --yaw=DEG, --pitch=DEG,
## --give=item:n,item:n, --god, --spawn=species,... (--spawn-active, --grab,
## --spawn-dist=M, --spawn-heading=DEG, --spawn-dead (as carcasses: --stage=gutted|skinned,
## --haul picks up the first, --butcher kneels at it, with --work-steps)),
## --wound, --condition=id,... (health conditions, see Survival.DEBUG_CONDITIONS),
## --open-inventory[=health|recipes], --open-pause, --open-debug (with --debug), --tired (able to sleep at once),
## --work=item:n,... (kneel to craft with these laid out), --work-make=item,
## --work-steps=N, --spawn-felled=tree_kind, --spawn-log=log,short_log,..., --stack=item:n,...
## (lay wood or piles out in front of you; --carry picks up the first log,
## --woodwork=fell|buck|strip|shorten|hew|split kneels at the first piece and begins it),
## --bench=tool,tool puts a workbench in front of you with those tools on its rack
## (--at-bench works at it, and --make=item lays out what that recipe needs and begins it),
## --vessel[=open|sealed|brew|salt|pickled] puts a fermentation vessel in front
## of you (empty, or with a brew, salted food or pickles in it),
## --soup-pot[=soup|water|empty|unfired] hangs a soup pot (of boiling soup by
## default) over a lit campfire 3 m in front of you (--carry picks it up),
## --house=N|all puts a house site near you with its first N parts built (all: finished),
## --house-stand=inside|porch|under|far|side (where you stand to it; with
## --soup-pot, the pot hangs over the finished house's fireplace),
## --icons=PATH (save the rendered icon atlas there),
## --intro (play the arrival, intro.gd, which --start=swamp and --start=lab otherwise skip),
## --music (start a music track at once), --weather=fog|aurora|bright_moon|meteors|
## thunderstorm|wind|smoke (start that event, already at full strength),
## --only=group,... (tests: run only those groups), --load-worlds (the title
## opens on Load world).

signal message(text: String)
signal picked(id: String)
signal crafted(id: String)

const Inventory := preload("res://src/core/inventory.gd")
const Survival := preload("res://src/core/survival.gd")
const SAVE_VERSION := 1
var old_save_path := "user://save.json"  # the single save from before named worlds
var worlds_dir := "user://worlds"    # one folder per world; tests point this elsewhere
const EXPORT_KIND := "vibival-world" # marks an exported world (export_world)
var world_id := ""                   # folder of the world being played
var world_name := ""
var save_path := ""                  # that world's camp save

## A day is 24 real minutes: 3 min of night, a 2 min sunrise, 14 min of
## daylight, a 2 min sunset and 3 more min of night. `time_of_day()` maps the
## clock onto a solar fraction where 0.25 is sunrise and 0.75 is sunset.
const DAY_LENGTH := 1440.0
const PHASES := [  # [clock seconds at start, solar fraction at start]
	[0.0, 0.0], [180.0, 0.2], [300.0, 0.3], [1140.0, 0.7], [1260.0, 0.8], [1440.0, 1.0],
]
const ARRIVAL_CLOCK := 330.0  # shortly after sunrise
## Web: the engine copies user:// to IndexedDB from its main loop, which stops
## once a tab is hidden, and a closing page drops writes still in flight. A
## save made as the page hides is also put in localStorage (written at once)
## under this prefix, and moved back into user:// on the next start.
const WEB_PENDING := "vibival:"
const SLEEP_COOLDOWN := 720.0  # seconds awake before you can sleep again
const SLEEP_LENGTH := 480.0    # game seconds that pass while asleep

var inventory: RefCounted = Inventory.new()
var world_seed := 1
var run_id := 0
var time := 0.0
var last_sleep := 0.0      # game time you last woke up (or arrived)
var saved_night := -1      # night index of the last sleep (every sleep saves; -1 by day)
var restore := {}          # save data waiting for the swamp scene to apply
var intro_pending := false # a new run: the swamp plays the arrival (intro.gd) when it starts
var taken := {}       # uid -> true for picked-up world items
var harvested := {}   # uid -> game time when it regrows
var felled := {}      # tree uid -> {at, regrow, kind, cleared?} (see chunk.gd)
var plantings := {}   # uid -> a hole dug for planting, or what grows from it (see plot.gd)
var hints_seen := {}
var tiers: Array = ["hand"]     # crafting tiers unlocked (workbenches built)
var tools_known: Array = []     # workbench rack tools you have made or held: their recipes are in the book
var player: Node3D = null
# A debug world (chosen when it is made): sleep and save at any time, fly, and
# a debug panel (F1) to set the time, start weather, spawn things and switch
# these off. Kept in world.json with the world.
var debug := false
var cheats := {"damage": true, "needs": true, "hostile": true}
var creatures: Array = []
var fires: Array = []
var houses: Array = []      # house sites and finished houses (house.gd)
var dev := {}

var _scene_time := 0.0
var _shot_done := false
var _js_page: JavaScriptObject = null  # keeps the web page callback alive
var _hidden_save := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)  # closing the window saves first
	get_tree().set_quit_on_go_back(false)  # Android back is the pause key (see Settings)
	if OS.has_feature("web"):
		# A browser tab gets no close request, so leave a suspend save
		# whenever the page is hidden (switched away from, closed or reloaded).
		_restore_web_pending()
		_js_page = JavaScriptBridge.create_callback(_on_page_visibility)
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _js_page)
		JavaScriptBridge.get_interface("window").addEventListener("pagehide", _js_page)
	crafted.connect(func(id): learn_tool(id))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var kv := arg.substr(2).split("=", true, 1)
			dev[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if dev.has("seed"):
		world_seed = int(dev["seed"])
	_migrate_old_save()
	if dev.get("start", "title") == "continue":
		var latest := latest_world()
		if not latest.is_empty():
			use_world(latest.id)
			load_game.call_deferred()
	elif dev.has("start") and dev["start"] != "title":
		use_world(create_world("Dev", "dev", dev.has("debug")))
		start_new_game.call_deferred(dev["start"] == "lab")


func new_world(world_name_in: String, tutorial: bool, debug_world := false) -> void:
	## Title screen: create a world with this name and start playing it.
	use_world(create_world(world_name_in, "", debug_world))
	start_new_game(tutorial)


func start_new_game(tutorial: bool) -> void:
	## A fresh run of the current world: a new map, and its old saves erased.
	if world_id == "":
		use_world(create_world("World"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	touch_world()
	inventory = Inventory.new()
	taken.clear()
	harvested.clear()
	felled.clear()
	plantings.clear()
	hints_seen.clear()
	tiers = ["hand"]
	tools_known = []
	restore = {}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(suspend_path()))
	time = 0.0
	run_id = randi()
	saved_night = -1
	if not dev.has("seed"):
		world_seed = randi() % 100000
	if dev.has("time"):
		time = fposmod(solar_to_clock(float(dev["time"])) - ARRIVAL_CLOCK, DAY_LENGTH)
	last_sleep = time - (SLEEP_COOLDOWN if dev.has("tired") else 0.0)
	# The arrival plays once the swamp starts, after the lab or straight away.
	# Dev starts skip it unless asked for (--intro).
	intro_pending = not dev.has("start") or dev.has("intro")
	goto("lab" if tutorial else "swamp")


func goto(scene: String) -> void:
	get_tree().paused = false
	creatures.clear()
	fires.clear()
	houses.clear()
	player = null
	_scene_time = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Music.enter(scene, scene == "swamp" and restore.is_empty())
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % scene)


func clock() -> float:
	return fmod(time + ARRIVAL_CLOCK, DAY_LENGTH)


func time_of_day() -> float:
	var c := clock()
	for i in PHASES.size() - 1:
		var a: Array = PHASES[i]
		var b: Array = PHASES[i + 1]
		if c < b[0]:
			return lerpf(a[1], b[1], (c - a[0]) / (b[0] - a[0]))
	return 0.0


func solar_to_clock(t: float) -> float:
	t = fposmod(t, 1.0)
	for i in PHASES.size() - 1:
		var a: Array = PHASES[i]
		var b: Array = PHASES[i + 1]
		if t < b[1]:
			return lerpf(a[0], b[0], (t - a[1]) / (b[1] - a[1]))
	return 0.0


func day() -> int:
	return int((time + ARRIVAL_CLOCK) / DAY_LENGTH)


func is_night() -> bool:
	var t := time_of_day()
	return t < 0.2 or t > 0.8


func night_index() -> int:
	## Which night it is (dusk through the following dawn), or -1 in daylight.
	var t := time_of_day()
	if t > 0.3 and t < 0.7:
		return -1
	return int(floor((time + ARRIVAL_CLOCK - PHASES[3][0]) / DAY_LENGTH))


func can_sleep_in() -> float:
	## Seconds until the player is tired enough to sleep again (0 = now).
	return maxf(last_sleep + SLEEP_COOLDOWN - time, 0.0)


# --- Worlds ----------------------------------------------------------------------
# Each named world is a folder under worlds_dir holding world.json (its name and
# when it was last played) and that world's camp and suspend saves.

func world_dir(id: String) -> String:
	return worlds_dir.path_join(id)


func use_world(id: String) -> void:
	world_id = id
	save_path = world_dir(id).path_join("save.json")
	var meta := _read_json(world_dir(id).path_join("world.json"))
	world_name = meta.get("name", id)
	debug = bool(meta.get("debug", false))
	cheats = {"damage": true, "needs": true, "hostile": true}
	if debug:
		for k in cheats:
			cheats[k] = bool(meta.get("cheats", {}).get(k, true))


func create_world(name_in: String, fixed_id := "", debug_world := false) -> String:
	## Makes the folder for a new world and returns its id. The id comes from
	## the name, made unique; `fixed_id` reuses one folder (the dev world).
	var display := name_in.strip_edges()
	if display == "":
		display = "World"
	var id := fixed_id
	if id == "":
		var base := ""
		for ch in display.to_lower():
			base += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "_"
		base = base.strip_edges().replace("__", "_").trim_prefix("_").trim_suffix("_")
		if base == "":
			base = "world"
		id = base
		var n := 2
		while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(world_dir(id))):
			id = "%s_%d" % [base, n]
			n += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(world_dir(id)))
	var now := Time.get_unix_time_from_system()
	_write_json(world_dir(id).path_join("world.json"), {"name": display, "created": now, "played": now, "debug": debug_world})
	return id


func set_cheat(key: String, on: bool) -> void:
	## A debug world's switches: "damage", "needs" (hunger, thirst and
	## stamina) and "hostile" (creatures attack you). Saved with the world.
	cheats[key] = on
	if world_id != "":
		var path := world_dir(world_id).path_join("world.json")
		var meta := _read_json(path)
		meta["cheats"] = cheats
		_write_json(path, meta)
	if player and is_instance_valid(player):
		player.apply_cheats()


func hostile() -> bool:
	## Whether creatures may attack the player.
	return not debug or cheats.hostile


func touch_world() -> void:
	## Marks the current world as the one played last.
	var path := world_dir(world_id).path_join("world.json")
	var meta := _read_json(path)
	meta["name"] = world_name
	meta["played"] = Time.get_unix_time_from_system()
	_write_json(path, meta)


func list_worlds() -> Array:
	## Every world, most recently played first: {id, name, played, day, saved}.
	## `day` is the day you would continue on, or 0 when there is no save yet.
	var out := []
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(worlds_dir)):
		return out
	for id in DirAccess.get_directories_at(ProjectSettings.globalize_path(worlds_dir)):
		var dir := world_dir(id)
		var meta := _read_json(dir.path_join("world.json"))
		if meta.is_empty():
			continue
		var camp := dir.path_join("save.json")
		var save := _read_json(camp.get_basename() + "_suspend.json")
		if save.is_empty():
			save = _read_json(camp)
		out.append({"id": id, "name": str(meta.get("name", id)), "played": float(meta.get("played", 0.0)),
				"saved": not save.is_empty(), "day": day_of(save) if not save.is_empty() else 0,
				"debug": bool(meta.get("debug", false))})
	out.sort_custom(func(a, b): return a.played > b.played)
	return out


func latest_world() -> Dictionary:
	## The most recently played world that has a save to continue, or {}.
	for w in list_worlds():
		if w.saved:
			return w
	return {}


func delete_world(id: String) -> void:
	var dir := ProjectSettings.globalize_path(world_dir(id))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	if id == world_id:
		world_id = ""


func export_world(id: String) -> String:
	## World `id` as one JSON text, its world.json and saves, for a .vibival
	## file (title.gd writes it wherever the player picks). "" if there's no
	## such world.
	var dir := world_dir(id)
	var meta := _read_json(dir.path_join("world.json"))
	if meta.is_empty():
		return ""
	var saves := {}
	for f in ["save.json", "save_suspend.json"]:
		var d := _read_json(dir.path_join(f))
		if not d.is_empty():
			saves[f] = d
	return JSON.stringify({"kind": EXPORT_KIND, "version": SAVE_VERSION, "world": meta, "saves": saves})


func import_world(text: String) -> Dictionary:
	## A new world made from export_world's text: {id, name}, or {error}. It
	## is renamed if a world of that name is already here.
	var json := JSON.new()
	var data = json.data if json.parse(text) == OK else null
	if typeof(data) != TYPE_DICTIONARY or data.get("kind", "") != EXPORT_KIND \
			or typeof(data.get("world")) != TYPE_DICTIONARY or typeof(data.get("saves", {})) != TYPE_DICTIONARY:
		return {"error": "That isn't a Vibival world file."}
	if int(data.get("version", 0)) != SAVE_VERSION:
		return {"error": "That world was saved by another version of the game."}
	var meta: Dictionary = data.world
	var taken_names := list_worlds().map(func(w): return w.name)
	var base := str(meta.get("name", "World")).strip_edges()
	if base == "":
		base = "World"
	var display := base
	var n := 2
	while display in taken_names:
		display = "%s (%d)" % [base, n]
		n += 1
	var id := create_world(display, "", bool(meta.get("debug", false)))
	meta["name"] = display
	meta["played"] = Time.get_unix_time_from_system()
	_write_json(world_dir(id).path_join("world.json"), meta)
	for f in ["save.json", "save_suspend.json"]:
		if typeof(data.saves.get(f)) == TYPE_DICTIONARY:
			_write_json(world_dir(id).path_join(f), data.saves[f])
	return {"id": id, "name": display}


func day_of(save: Dictionary) -> int:
	return int((float(save.get("time", 0.0)) + ARRIVAL_CLOCK) / DAY_LENGTH) + 1


func _migrate_old_save() -> void:
	## A save from before named worlds becomes the world "My world".
	var old := ProjectSettings.globalize_path(old_save_path)
	var old_suspend := old.get_basename() + "_suspend.json"
	if not FileAccess.file_exists(old) and not FileAccess.file_exists(old_suspend):
		return
	var id := create_world("My world")
	var dir := ProjectSettings.globalize_path(world_dir(id))
	for pair in [[old, "save.json"], [old_suspend, "save_suspend.json"]]:
		if FileAccess.file_exists(pair[0]):
			DirAccess.rename_absolute(pair[0], dir.path_join(pair[1]))


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


# --- Saving ----------------------------------------------------------------------
# The camp save is written only when you sleep through a night (or survive an
# attack that woke you), so dying sends you back to your last camp. Quitting
# can also write a suspend save: Continue resumes from it once and deletes it,
# and the camp save stays as it was.

func suspend_path() -> String:
	return save_path.get_basename() + "_suspend.json"


func has_save() -> bool:
	return save_path != "" and FileAccess.file_exists(save_path)


func has_suspend() -> bool:
	return save_path != "" and FileAccess.file_exists(suspend_path())


func read_save(suspended := false) -> Dictionary:
	var f := FileAccess.open(suspend_path() if suspended else save_path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return {}
	return data


func save_game(world_state: Dictionary, suspended := false) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"seed": world_seed,
		"run": run_id,
		"time": time,
		"last_sleep": last_sleep,
		"saved_night": saved_night,
		"taken": taken.keys(),
		"harvested": harvested,
		"felled": felled,
		"plantings": plantings,
		"hints": hints_seen,
		"tiers": tiers,
		"tools_known": tools_known,
		"inventory": inventory.to_dict(),
	}
	data.merge(world_state)
	var path := suspend_path() if suspended else save_path
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if world_id != "":
		touch_world()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func ease_saves(cause: String) -> bool:
	## Death by `cause`: this run's camp save (and a suspend save) are
	## rewritten one step less serious in it. True if one was.
	var eased := false
	for suspended in [false, true]:
		var data := read_save(suspended)
		if data.is_empty() or int(data.get("run", -1)) != run_id or not data.has("vitals"):
			continue
		data.vitals = Survival.ease(data.vitals, cause)
		var path := suspend_path() if suspended else save_path
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		eased = true
	return eased


func take_save() -> Dictionary:
	## The save to resume from: the suspend save if there is one (deleted as it
	## is taken), otherwise the camp save. {} when there is neither.
	var suspended := has_suspend()
	var data := read_save(suspended)
	if suspended:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(suspend_path()))
		if data.is_empty():
			data = read_save()
			suspended = false
	if not data.is_empty():
		data["suspended"] = suspended
	return data


func load_game(id := "") -> bool:
	## Continue a world (by default the current one) from its save.
	if id != "":
		use_world(id)
	var data := take_save()
	if data.is_empty():
		return false
	if world_id != "":
		touch_world()
	apply_save(data)
	goto("swamp")
	return true


func apply_save(data: Dictionary) -> void:
	## Restore the run state; the swamp scene applies the rest from `restore`.
	intro_pending = false
	world_seed = int(data.seed)
	run_id = int(data.run)
	time = float(data.time)
	last_sleep = float(data.last_sleep)
	saved_night = int(data.saved_night)
	taken.clear()
	for uid in data.taken:
		taken[uid] = true
	harvested = data.harvested
	felled = data.get("felled", {})
	plantings = data.get("plantings", {})
	hints_seen = data.hints
	tiers = data.get("tiers", ["hand"])
	inventory = Inventory.new()
	inventory.from_dict(data.inventory)
	tools_known = []
	if data.has("tools_known"):
		for id in data.tools_known:
			learn_tool(String(id), false)
	else:
		# A save from before the book kept track: the tools you carry or have
		# hung on a bench are ones you have held.
		for s in inventory.slots:
			if s != null:
				learn_tool(s.id, false)
		for b in data.get("workbenches", []):
			for id in b.get("tools", []):
				learn_tool(String(id), false)
	restore = data


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Closing the window: leave a suspend save if the world allows it now.
		var scene := get_tree().current_scene
		if scene and scene.has_method("save_suspend"):
			scene.save_suspend()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED and OS.has_feature("mobile"):
		_app_hidden()
	elif what == NOTIFICATION_APPLICATION_RESUMED and OS.has_feature("mobile"):
		_app_shown()


func _on_page_visibility(_args: Array) -> void:
	if JavaScriptBridge.eval("document.visibilityState") == "hidden":
		_app_hidden()
	else:
		_app_shown()


func _app_hidden() -> void:
	## The browser tab is hidden or the Android app sent to the background,
	## where it may be closed without warning: leave a suspend save.
	var scene := get_tree().current_scene
	if _hidden_save or scene == null or not scene.has_method("save_suspend") or not scene.save_suspend():
		return
	_hidden_save = true
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("localStorage").setItem(WEB_PENDING + suspend_path(),
				FileAccess.get_file_as_string(suspend_path()))


func _app_shown() -> void:
	# Back and still playing: that save was not a quit after all.
	if not _hidden_save:
		return
	_hidden_save = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(suspend_path()))
	if OS.has_feature("web"):
		JavaScriptBridge.get_interface("localStorage").removeItem(WEB_PENDING + suspend_path())


func _restore_web_pending() -> void:
	## Web: writes saves left in localStorage by a page that closed into user://.
	var ls := JavaScriptBridge.get_interface("localStorage")
	var keys := []
	for i in int(ls.length):
		var k := String(ls.key(i))
		if k.begins_with(WEB_PENDING):
			keys.append(k)
	for k in keys:
		var path: String = k.substr(WEB_PENDING.length())
		if path.begins_with("user://"):
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f:
				f.store_string(String(ls.getItem(k)))
				f.close()
		ls.removeItem(k)


func notify(text: String) -> void:
	message.emit(text)


func sheltered(pos: Vector3) -> bool:
	## Whether pos is inside a finished house or out on its porch, where
	## nothing comes for you.
	for h in houses:
		if is_instance_valid(h) and h.shelters(pos):
			return true
	return false


func nearest_fire(pos: Vector3, radius: float) -> Node3D:
	for f in fires:
		if f.lit and f.global_position.distance_to(pos) < radius:
			return f
	return null


func _process(delta: float) -> void:
	_scene_time += delta
	if dev.has("shot") and not _shot_done and _scene_time > float(dev.get("shot-delay", "6")):
		_shot_done = true
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dev["shot"])
		if player:
			print("player pos=", player.global_position, " vitals b/e/w/s=", player.vitals.blood, "/", player.vitals.energy, "/", player.vitals.water, "/", player.vitals.stamina, " depth=", player.water_depth(), " fps=", Engine.get_frames_per_second(), " creatures=", creatures.size())
		print("Saved screenshot to ", dev["shot"])
		get_tree().quit()
	if dev.has("selftest") and _scene_time > float(dev.get("selftest-time", "8")):
		print("SELFTEST OK scene=", get_tree().current_scene.name if get_tree().current_scene else "none")
		get_tree().quit()


func learn_tool(id: String, tell := true) -> bool:
	## You made or held a workbench rack tool, or used a bench with it on the
	## rack: the recipes needing it (`rack`, or `known_by`) are added to the
	## recipe book (and can be made). True if it is new.
	if id in tools_known or not Items.def(id).get("rack", false):
		return false
	tools_known.append(id)
	var pages := []
	for r in Items.RECIPES:
		var page := ""
		if r.get("rack", "") == id:
			page = r.cat if r.get("listed", false) else Items.ADVANCED
		elif r.get("known_by", "") == id:
			page = r.cat
		if page != "" and not page in pages:
			pages.append(page)
	if tell and not pages.is_empty():
		notify("New recipes for the %s in your recipe book (%s)." % [Items.item_name(id).to_lower(), ", ".join(pages)])
	return true


func knows_recipe(r: Dictionary) -> bool:
	## Whether a recipe is known: one needing a rack tool (`rack`), or taught
	## by one (`known_by`), only once you have made or held that tool or used
	## a bench with it on the rack.
	return (not r.has("rack") or r.rack in tools_known) and (not r.has("known_by") or r.known_by in tools_known)


func unlock_tier(tier: String) -> void:
	## A workbench of this tier was built: its recipes show in the book.
	if not tier in tiers:
		tiers.append(tier)
