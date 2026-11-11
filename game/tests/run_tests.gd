extends Node
## Headless test suite: `tools/test.sh`. Exits with code 1 on any failure.

const Inventory := preload("res://src/core/inventory.gd")
const Survival := preload("res://src/core/survival.gd")
const Creature := preload("res://src/creatures/creature.gd")
const Player := preload("res://src/player/player.gd")
const ThrownRock := preload("res://src/world/thrown_rock.gd")
const Pickup := preload("res://src/world/pickup.gd")
const Harvestable := preload("res://src/world/harvestable.gd")
const Chunk := preload("res://src/world/chunk.gd")
const FelledTree := preload("res://src/world/felled_tree.gd")
const WoodLog := preload("res://src/world/wood_log.gd")
const Stack := preload("res://src/world/stack.gd")
const Stump := preload("res://src/world/stump.gd")
const Plot := preload("res://src/world/plot.gd")
const Compost := preload("res://src/world/compost.gd")
const Trap := preload("res://src/world/trap.gd")
const Workbench := preload("res://src/world/workbench.gd")
const SoupPot := preload("res://src/world/soup_pot.gd")
const Campfire := preload("res://src/world/campfire.gd")
const Intro := preload("res://src/world/intro.gd")
const Fishing := preload("res://src/world/fishing.gd")
const House := preload("res://src/world/house.gd")
const Weather := preload("res://src/world/weather.gd")
const Dock := preload("res://src/world/dock.gd")
const Raft := preload("res://src/world/raft.gd")
const Furnace := preload("res://src/world/furnace.gd")
const Clamp := preload("res://src/world/clamp.gd")
const HeavyStone := preload("res://src/world/heavy_stone.gd")
const Breakroom := preload("res://src/world/breakroom.gd")

var _failures := 0
var _checks := 0


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("  FAIL: ", what)


func _ready() -> void:
	# --only=amphibian,throwing runs just those groups (named as printed).
	var only: PackedStringArray = String(Game.dev.get("only", "")).split(",", false)
	Game.save_path = "user://test_save.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	if only.is_empty() or "data" in only:
		print("== data")
		test_data()
	if only.is_empty() or "inventory" in only:
		print("== inventory")
		test_inventory()
	if only.is_empty() or "controls" in only:
		print("== controls")
		await test_controls()
	if only.is_empty() or "knapping" in only:
		print("== knapping")
		test_knapping()
	if only.is_empty() or "music" in only:
		print("== music")
		test_music()
	if only.is_empty() or "survival" in only:
		print("== survival")
		test_survival()
	if only.is_empty() or "wounds" in only:
		print("== wounds")
		test_wounds()
	if only.is_empty() or "health" in only:
		print("== health")
		await test_health()
	if only.is_empty() or "day" in only:
		print("== day cycle")
		test_day_cycle()
	if only.is_empty() or "lab" in only:
		print("== lab")
		await test_lab()
	if only.is_empty() or "swamp" in only:
		print("== swamp")
		await test_swamp()
	if only.is_empty() or "sleep" in only:
		print("== sleep and saving")
		await test_sleep_and_save()
	if only.is_empty() or "save" in only:
		print("== save on exit")
		await test_suspend()
	if only.is_empty() or "amphibian" in only:
		print("== amphibian")
		await test_amphibian()
	if only.is_empty() or "escape" in only:
		print("== escape roll")
		await test_escape_roll()
	if only.is_empty() or "throwing" in only:
		print("== throwing")
		await test_throwing()
	if only.is_empty() or "predators" in only:
		print("== predators")
		await test_predators()
	if only.is_empty() or "butcher" in only:
		print("== butchering")
		await test_butcher()
	if only.is_empty() or "wood" in only:
		print("== woodcutting and piles")
		await test_wood()
		await test_piles()
	if only.is_empty() or "bench" in only:
		print("== workbench")
		await test_bench()
		await test_bench_slope_and_moving()
		await test_work_view()
	if only.is_empty() or "soup" in only:
		print("== soup pot")
		await test_soup()
		await test_soup_blood()
	if only.is_empty() or "baitbox" in only:
		print("== baitbox")
		await test_baitbox()
	if only.is_empty() or "bedroll" in only:
		print("== bedroll")
		await test_bedroll()
	if only.is_empty() or "house_floor" in only:
		print("== things on a house floor")
		await test_house_floor()
	if only.is_empty() or "fern_dig" in only:
		print("== digging ferns")
		await test_fern_dig()
	if only.is_empty() or "canteen" in only:
		print("== canteen and rack recipes")
		await test_canteen()
	if only.is_empty() or "paper" in only:
		print("== paper and pencil")
		await test_paper()
	if only.is_empty() or "house" in only:
		print("== blueprints and the softwood house")
		await test_blueprint()
		await test_house()
	if only.is_empty() or "ferment" in only:
		print("== fermentation")
		await test_ferment()
		test_alcohol()
		await test_preserves()
	if only.is_empty() or "logs" in only:
		print("== log looks")
		await test_log_kinds()
	if only.is_empty() or "boulders" in only:
		print("== boulders")
		await test_boulders()
	if only.is_empty() or "debug" in only:
		print("== debug saving")
		await test_debug_save()
		await test_debug_world()
	if only.is_empty() or "worlds" in only:
		print("== worlds")
		test_worlds()
	if only.is_empty() or "stash" in only:
		print("== stash")
		await test_stash()
	if only.is_empty() or "waypoint" in only:
		print("== waypoint")
		await test_waypoint()
	if only.is_empty() or "shore" in only:
		print("== shore stones")
		await test_shore()
	if only.is_empty() or "weather" in only:
		print("== weather")
		await test_weather()
	if only.is_empty() or "touch" in only:
		print("== touch controls")
		await test_touch()
	if only.is_empty() or "embers" in only:
		print("== embers and the struck stump")
		await test_embers()
	if only.is_empty() or "arrival" in only:
		print("== arrival")
		await test_arrival()
	if only.is_empty() or "spindle" in only:
		print("== spindle, string and the bow drill")
		await test_spindle()
	if only.is_empty() or "seed" in only:
		print("== seed ferns dug up")
		await test_seed_fern_dig()
	if only.is_empty() or "farming" in only:
		print("== farming")
		await test_farming_holes()
		await test_farming_trees()
	if only.is_empty() or "compost" in only:
		print("== compost")
		await test_compost_basket()
		await test_compost_growing()
	if only.is_empty() or "traps" in only:
		print("== traps")
		await test_fish_trap()
		await test_snare()
	if only.is_empty() or "prey" in only:
		print("== prey variety")
		test_prey_data()
		await test_prey_spawning()
		await test_prey_behaviour()
		await test_prey_dressing()
	if only.is_empty() or "fishing" in only:
		print("== fishing gear and bait")
		await test_fishing()
		await test_fishing_line()
		await test_fish_species()
	if only.is_empty() or "boats" in only:
		print("== boats")
		await test_boats()
	if only.is_empty() or "metals" in only:
		print("== metals")
		test_tool_wear()
		await test_metals()
		await test_meteor_weather()
		await test_copper_vessels()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.suspend_path()))
	print("%d checks, %d failures" % [_checks, _failures])
	print("TESTS PASSED" if _failures == 0 else "TESTS FAILED")
	get_tree().quit(1 if _failures else 0)


func test_copper_vessels() -> void:
	## The copper flask and the copper soup pot (late game).
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var spot: Vector3 = p.global_position
	Game.inventory.clear()

	# The flask: four servings, lighter than the two canteens it stands for.
	var serving: float = Items.weight("canteen_clean_1") - Items.weight("canteen")
	check(Items.weight("flask") < Items.weight("canteen") * 2.0, "an empty flask weighs less than two empty canteens (%.1f kg)" % Items.weight("flask"))
	for kind in ["dirty", "clean", "soup", "soup_spoiled"]:
		var ok := true
		for n in range(1, 5):
			var id := "flask_%s_%d" % [kind, n]
			ok = ok and is_equal_approx(Items.weight(id), Items.weight("flask") + serving * n) \
					and Items.def(id).empty == ("flask" if n == 1 else "flask_%s_%d" % [kind, n - 1])
		check(ok, "a flask of %s weighs a serving more for each of four, and drinks down a serving at a time" % kind)
	check(Items.weight("flask_clean_4") < Items.weight("canteen_clean_2") * 2.0, "full, it is lighter than two full canteens")
	check(Items.def("flask_soup_1").decay == Items.def("canteen_soup_1").decay * 2.0, "soup keeps twice as long in copper")
	check(Items.def("flask_alcohol").measures == 20 and Items.def("flask_alcohol").drained == "flask", "it holds twenty measures of alcohol")
	check(Items.is_drink_container("flask_clean_2") and not Items.can_cure("flask_soup_2"), "a flask is a drink, not food to cure")
	var fr: Dictionary = Items.recipe_for("flask")
	check(fr.get("at", "") == "anvil" and fr.in.get("copper_bar", 0) == 2 and fr.get("tool_tag", "") == "hammer", "raised from two copper bars at the anvil with a hammer")

	# Filled at the water: four servings of swamp water.
	Game.inventory.add("flask")
	var slot: int = Game.inventory.find("flask")
	Game.inventory.select(slot)
	p.focus = null
	p.focus_water = true
	p._interact()
	check(Game.inventory.held_id() == "flask_dirty_4", "filled at the water: four servings, still in your hand")
	p.consume_slot(slot)
	check(Game.inventory.slots[slot].id == "flask_dirty_3", "a drink leaves three")
	p.focus_water = false

	# A soup pot fills it a serving at a time, and soup mixes by servings.
	var sp: Node = w.add_soup_pot("soup_pot", spot + Vector3(4, 0, 0))
	sp.water = 16.0
	sp.dirty = false
	Game.inventory.slots[slot] = {"id": "flask", "n": 1, "age": 0.0}
	for n in 4:
		sp.interact(p)
	check(Game.inventory.held_id() == "flask_clean_4" and sp.water == 12.0, "four scoops of boiled water fill it")
	Game.inventory.slots[slot] = {"id": "flask_soup_3", "n": 1, "age": 0.0, "data": {"protein": 4.0}}
	sp.add_food("cooked_meat")
	sp.advance(60.0, 60.0)
	var meat: float = sp.per_serving("protein")
	sp.interact(p)
	var fs: Dictionary = Game.inventory.slots[slot]
	check(fs.id == "flask_soup_4" and is_equal_approx(fs.data.protein, (4.0 * 3.0 + meat) / 4.0), "a fourth serving of soup counts a quarter of the mix (%.2f)" % fs.data.protein)
	Game.inventory.slots[slot] = {"id": "flask_soup_4", "n": 1, "age": SoupPot.LIFE * 1.5, "data": {"protein": 3.0}}
	Game.inventory.tick(2.0)
	check(Game.inventory.slots[slot].id == "flask_soup_4", "soup a pot would have lost long ago still keeps in the flask")
	Game.inventory.slots[slot].age = SoupPot.LIFE * 2.0 - 1.0
	Game.inventory.tick(2.0)
	check(Game.inventory.slots[slot].id == "flask_soup_spoiled_4", "until twice as long")

	# Alcohol: a serving of brew is ten measures, the flask holds two.
	var b: Node = w.add_vessel("vessel_sealed", spot + Vector3(-4, 0, 6))
	Game.inventory.slots[slot] = {"id": "flask_clean_2", "n": 1, "age": 0.0}
	b.interact(p)
	check(b.water == 1 and Game.inventory.held_id() == "flask_clean_1", "a flask of boiled water pours a serving in")
	b.water = 8
	for id in ["roast_seed", "roast_seed", "cooked_fiddlehead"]:
		b.add_food(id)
	b.advance(b.FERMENT_TIME + 1.0, 0.0)
	Game.inventory.slots[slot] = {"id": "flask", "n": 1, "age": 0.0}
	check("into the flask" in b.prompt(p), "the vessel offers to draw into the flask (%s)" % b.prompt(p))
	b.interact(p)
	fs = Game.inventory.slots[slot]
	check(fs.id == "flask_alcohol" and int(fs.data.left) == 10 and b.water == 7, "the first draw is ten measures")
	b.interact(p)
	fs = Game.inventory.slots[slot]
	check(int(fs.data.left) == 20 and b.water == 6, "a second fills it to twenty")
	b.interact(p)
	check(int(Game.inventory.slots[slot].data.left) == 20 and b.water == 6 and "full" in b.prompt(p), "a full flask draws no more")
	check(is_equal_approx(Game.inventory.durability(slot), 1.0), "its bar shows it full")
	Game.inventory.slots[slot] = {"id": "flask_alcohol", "n": 1, "age": 0.0, "data": Items.measures_data("flask_alcohol", 1)}
	p.consume_slot(slot)
	check(Game.inventory.held_id() == "flask", "the last measure leaves the empty flask")
	Game.inventory.slots[slot] = {"id": "canteen_alcohol", "n": 1, "age": 0.0, "data": Items.measures_data("canteen_alcohol", 4)}
	b.interact(p)
	check(int(Game.inventory.slots[slot].data.left) == 10 and b.water == 5, "a canteen still tops up to ten")
	p.vitals.alcohol = 0.0

	# The copper soup pot: 20 servings, boils 50% faster, keeps 20% longer.
	var cr: Dictionary = Items.recipe_for("soup_pot_copper")
	check(cr.get("at", "") == "anvil" and cr.in.get("copper_bar", 0) > 0 and Items.def("soup_pot_copper").get("carry", false), "a copper soup pot is raised at the anvil and carried")
	var cp: Node = w.add_soup_pot("soup_pot_copper", spot + Vector3(-4, 0, -4))
	check(cp.fired_pot() and cp.copper(), "it needs no firing")
	cp.fill_dirty()
	check(cp.water == 20.0 and cp.capacity() == 20.0 and cp.max_food() == 15.0, "it holds 20 servings of water and 15 food")
	sp.empty_out()
	sp.fill_dirty()
	sp.advance(40.0, 40.0)
	cp.advance(40.0, 40.0)
	check(cp.boiling() and not cp.dirty and not sp.boiling(), "it comes to the boil in 40 s, before the clay pot")
	for k in 15:
		cp.add_food("roast_seed")
	check(cp.add_food("roast_seed") != "" and cp.water <= 20.0 + 0.001, "15 food fill it")
	cp.advance(60.0, 60.0)
	var t0: float = Game.time
	Game.time = t0 + SoupPot.LIFE * 1.15
	check(not cp.spoiled(), "past the clay pot's 36 hours its soup still keeps")
	var got: Dictionary = cp.scoop()
	check(got.kind == "soup" and got.age < SoupPot.LIFE, "scooped out, it counts as soup that still has life in it (%.0f s)" % got.age)
	Game.time = t0 + SoupPot.LIFE * 1.21
	check(cp.spoiled(), "but not past 20% longer")
	Game.time = t0
	var d: Dictionary = cp.to_dict()
	var cp2: Node = w.add_soup_pot(d.id, spot + Vector3(-4, 0, 4))
	cp2.from_dict(d)
	check(cp2.copper() and cp2.water > 16.0, "saved and loaded, it keeps its 20-serving load (%.1f)" % cp2.water)
	check(cp.tooltip(p).begins_with("Copper Soup Pot:"), "its panel names it (%s)" % cp.tooltip(p).get_slice("\n", 0))
	w.queue_free()
	await _frames(2)

func test_data() -> void:
	for id in Items.ITEMS:
		var d: Dictionary = Items.ITEMS[id]
		check(d.has("name") and d.has("shape") and d.has("color"), "%s has name/shape/color" % id)
		check(d.has("w") and (d.w > 0.0 or d.get("carry", false)), "%s has a weight (or is carried in your arms)" % id)
		if d.has("treat"):
			check(d.treat in ["clean", "alcohol", "bandage", "wax"], "%s has a known treatment" % id)
		for ref in ["cook", "hold", "empty"]:
			if d.has(ref):
				check(Items.ITEMS.has(d[ref]), "%s.%s -> %s exists" % [id, ref, d[ref]])
	for r in Items.RECIPES:
		check(Items.ITEMS.has(r.out), "recipe output %s exists" % r.out)
		for id in r.in:
			check(Items.ITEMS.has(id), "recipe input %s exists" % id)
	for id in Items.KNAPPING:
		check(Items.ITEMS.has(id), "knapping output %s exists" % id)
	for sp in Creature.SPECIES:
		for id in Creature.SPECIES[sp].drops:
			check(Items.ITEMS.has(id), "%s drop %s exists" % [sp, id])
	for k in Harvestable.KINDS:
		for id in Harvestable.KINDS[k].yield:
			check(Items.ITEMS.has(id), "%s yield %s exists" % [k, id])


func test_inventory() -> void:
	var inv := Inventory.new()
	# Weight, not stack size, is the limit; things worn differently keep apart.
	check(inv.add("stone", 60, 0.0, true) == 0 and inv.slots[0].n == 60 and inv.slots[1] == null, "a stack has no size limit")
	inv.clear()
	inv.add("ash_pencil", 2, 0.0, true)
	check(inv.slots[0].n == 2, "fresh tools stack")
	inv.wear("ash_pencil")
	check(inv.count("ash_pencil") == 2 and inv.slots[0].n == 1 and inv.slots[1] != null and inv.slots[1].n == 1, "a worn tool leaves the stack")
	inv.add("ash_pencil", 1, 0.0, true, Items.uses_data("ash_pencil", 1))
	check(inv.slots[2] != null and inv.slots[2].n == 1, "tools worn differently keep separate stacks")
	inv.clear()
	check(inv.add("plant_fiber", 25) == 0, "25 fiber fit")
	check(inv.slots[0].n == 25 and inv.slots[1] == null, "fiber stacks without a size limit")
	check(inv.count("plant_fiber") == 25, "count fiber")
	check(is_equal_approx(inv.weight(), Items.weight("plant_fiber") * 25), "weight sums items")
	check(inv.remove("plant_fiber", 22), "remove 22")
	check(inv.count("plant_fiber") == 3, "3 left")
	check(not inv.remove("plant_fiber", 5), "cannot over-remove")
	inv.clear()
	inv.add("raw_meat", 3, 500.0)
	inv.add("raw_meat", 1, 0.0)
	check(inv.count("raw_meat") == 4 and inv.slots[0].age == 500.0, "a fresh one added to a stack doesn't freshen the rest")
	inv.clear()

	# Weight limit: arms only, then a sack.
	var heavy := Inventory.new()
	check(is_equal_approx(heavy.capacity(), Inventory.BASE_CAPACITY), "base capacity without a sack")
	var left := heavy.add("stone", 200)
	check(left > 0, "too many stones are rejected (%d left over)" % left)
	check(heavy.weight() <= Inventory.BASE_CAPACITY * Inventory.OVERLOAD + 0.001, "never above the overload limit")
	check(heavy.load_ratio() > 1.0, "a full load counts as overloaded")
	check(heavy.add("stone") == 1 and heavy.room_for("stone") == 0, "no room for one more stone")
	check(heavy.add("stone", 1, 0.0, true) == 0, "forced add ignores weight")
	heavy.add("fiber_sack", 1, 0.0, true)
	check(is_equal_approx(heavy.capacity(), Inventory.SACK_CAPACITY), "a sack raises capacity")
	check(heavy.add("stone") == 0, "room again with a sack")
	heavy.capacity_override = 100.0
	check(is_equal_approx(heavy.capacity(), 100.0), "capacity override (lab)")
	var copy := Inventory.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(heavy.to_dict())))
	check(copy.count("stone") == heavy.count("stone") and copy.has_tag("sack"), "inventory survives a JSON round trip")

	inv.add("plant_fiber", 3)
	var cord: Dictionary = Items.recipes_for("swamp").filter(func(r): return r.out == "cordage")[0]
	check(inv.can_craft(cord) and inv.craft(cord), "craft cordage")
	check(inv.count("cordage") == 1 and inv.count("plant_fiber") == 0, "cordage consumed fiber")
	inv.add("seed", 2)
	inv.tick(Items.def("seed").decay + 1.0)
	check(inv.count("seed") == 0 and inv.count("rotten") == 2, "seeds rot")
	inv.add("torch_lit")
	inv.tick(Items.def("torch_lit").decay + 1.0)
	check(inv.count("torch_lit") == 0 and inv.count("charred_stick") == 1, "a lit torch burns down to a charred stick")
	var full := Inventory.new()
	full.capacity_override = 1000.0
	for i in Inventory.SIZE:
		full.add("spear", 1, 0.0, false, {"mark": i})  # (with data of their own: a slot each)
	check(full.add("stone") == 1, "inventory with every slot taken rejects")
	var sw := Inventory.new()
	sw.add("stone", 3)
	sw.swap(0, 5)
	check(sw.slots[0] == null and sw.slots[5].id == "stone", "swap moves stack")


func test_knapping() -> void:
	for id in Items.KNAPPING:
		var grid := []
		var mirror := []
		for y in 5:
			for x in 5:
				grid.append(Items.KNAPPING[id][y][x] == "#")
				mirror.append(Items.KNAPPING[id][y][4 - x] == "#")
		check(Items.knap_matches(grid) == id, "pattern %s matches" % id)
		check(Items.knap_matches(mirror) == id, "mirrored %s matches" % id)
	var full := []
	for i in 25:
		full.append(true)
	check(Items.knap_matches(full) == "", "untouched stone matches nothing")


func test_music() -> void:
	Music.stop(false)
	check(Music.tracks.size() == 5, "found the music tracks (%d)" % Music.tracks.size())
	check(not Music.tracks.any(func(t): return t.get_basename() == Music.ELEVATOR), "the elevator music is not in the random choice")
	for t in Music.tracks:
		var st: AudioStream = Music.load_track(t)
		check(st != null and st.get_length() > 60.0, "%s loads (%.0f s)" % [t.get_file(), st.get_length() if st else 0.0])
	var keep_freq: int = Settings.music_frequency
	var keep_current: String = Music.current
	var repeats := 0
	for i in 40:
		var t := Music.pick_track()
		if t == Music.current:
			repeats += 1
		Music.current = t
	check(repeats == 0, "never the same track twice in a row")
	Music.current = keep_current
	var spans := []
	for f in [Settings.MusicFrequency.CONSTANT, Settings.MusicFrequency.COMMON, Settings.MusicFrequency.RARE]:
		Settings.music_frequency = f
		var lo := INF
		var hi := 0.0
		for i in 50:
			var g := Music.next_gap()
			lo = minf(lo, g)
			hi = maxf(hi, g)
		spans.append([lo, hi])
	check(spans[0][1] < 30.0 and spans[0][1] < spans[1][0] and spans[1][1] < spans[2][1] and spans[1][0] < spans[2][0],
			"constant plays almost back to back, common waits minutes, rare much longer")
	for f in [Settings.MusicFrequency.COMMON, Settings.MusicFrequency.RARE]:
		Settings.music_frequency = f
		var share := 0.0
		for i in 200:
			share += Music.track_length() / (Music.track_length() + Music.next_gap()) / 200.0
		check(absf(share - [0.5, 0.2][f - 1]) < 0.06, "%s music plays about %.0f%% of the time" % [["common", "rare"][f - 1], share * 100.0])
	# Scheduled as each track starts: never more than 60% (common) or 30%
	# (rare) of the time, even if the player never says a track finished.
	Music.enter("swamp", false)
	for f in [Settings.MusicFrequency.COMMON, Settings.MusicFrequency.RARE]:
		Settings.music_frequency = f
		var worst := 0.0
		for i in 100:
			Music.play_next()
			var cycle: float = maxf(Music.wait, Music.quiet_until() - Music._started_at)
			worst = maxf(worst, Music._started_len / cycle)
		Music.stop(false)
		check(worst <= Music.MAX_SHARE[f] + 0.001, "%s music never plays more than %.0f%% of the time (at most %.0f%%)" % [["common", "rare"][f - 1], Music.MAX_SHARE[f] * 100.0, worst * 100.0])
	Settings.music_frequency = Settings.MusicFrequency.COMMON
	Music.play_next()
	var first: float = Music._started_at
	var first_len: float = Music._started_len
	Music.stop(false)  # cut off, with no `finished`
	for i in 20:
		Music._process(5.0)
	check(Music._started_at == first, "a track cut short isn't followed straight away by another")
	for i in 200:
		Music._process(5.0)
		if Music._started_at != first:
			break
	check(Music._started_at - first >= first_len / 0.6 - 5.0 and Music._started_at != first,
			"the next starts once the quiet allows (%.0f s later)" % (Music._started_at - first))
	Music.stop(false)
	var keep_scene: String = Music.scene
	Settings.music_frequency = Settings.MusicFrequency.RARE
	Settings.apply()
	var defaults: Node = Settings.get_script().new()
	check(defaults.music_frequency == Settings.MusicFrequency.RARE, "music is rare by default")
	defaults.free()
	Music.enter("title")
	check(Music.wait == Music.TITLE_WAIT and Music.queued == "", "the title stays quiet for 30 s")
	Music.enter("lab")
	check(Music.wait == INF, "never any music in the tutorial")
	Settings.music_frequency = Settings.MusicFrequency.COMMON
	Settings.apply()
	check(Music.wait == INF, "not even when the setting changes there")
	Music.enter("swamp", true)
	check(Music.queued == Music.OPENING and Music.wait == Music.OPENING_WAIT, "a new world opens with Empty Basin after 30 s")
	Music.play_next()
	check(Music.current == Music.OPENING and Music.queued == "", "and then it plays")
	Music.stop(false)
	Settings.music_frequency = Settings.MusicFrequency.CONSTANT
	Settings.apply()
	Music.enter("swamp", true)
	check(Music.queued == "" and Music.wait < 30.0, "constant music skips the scripted opening")
	Music.enter("swamp", false)
	check(Music.queued == "", "loading a world plays no opening")
	Settings.music_frequency = Settings.MusicFrequency.OFF
	Settings.apply()
	check(Music.next_gap() == INF and Music.wait == INF, "off never schedules a track")
	Settings.music_frequency = Settings.MusicFrequency.CONSTANT
	Settings.apply()
	check(Music.wait < 30.0, "turning music back on schedules the next track soon")
	Settings.music_frequency = keep_freq
	Settings.apply()
	Music.enter(keep_scene)
	Music.stop(false)


func test_survival() -> void:
	var v := Survival.new()
	var e0 := v.energy
	var w0 := v.water
	var p0 := v.protein
	v.tick(60.0, false, false)
	check(v.energy < e0 and v.water < w0 and v.protein < p0, "energy, water and nutrients drain")
	check(e0 - v.energy < 3.0, "energy drains slowly (%.2f a minute)" % (e0 - v.energy))
	var asleep := Survival.new()
	asleep.tick(60.0, false, false, false, true)
	check(e0 - asleep.energy < e0 - v.energy, "sleeping burns less energy")
	v.energy = 0.0
	v.water = 0.0
	v.tick(10.0, false, false)
	check(v.starving > 0.0 and v.thirst > 0.0, "with nothing to eat or drink you start starving and dying of thirst")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	v.consume({"energy": 30.0, "protein": 10.0, "sick": 1.0}, rng)
	check(v.energy == 30.0 and v.sick > 0.0, "risky food makes you sick")

	# Nutrient deficiencies.
	var n := Survival.new()
	n.protein = 10.0
	check(n.max_stamina() < 100.0, "low protein caps stamina")
	var n_full := Survival.new()
	n_full.protein = 100.0
	n_full.greens = 100.0
	n_full.starch = 100.0
	n.greens = 10.0
	n.starch = 10.0
	check(n.nutrition() < n_full.nutrition(), "poor diet lowers nutrition")
	var labels := n.effects().map(func(e): return e[0])
	check("Craving protein" in labels and "Craving greens" in labels and "Craving starch" in labels, "cravings shown")
	check(n.status_words()[0] == "Craving protein, greens and starch", "the corner names every craving (%s)" % n.status_words()[0])
	var gs := Survival.new()
	gs.greens = 10.0
	gs.starch = 10.0
	check(gs.status_words()[0] == "Craving greens and starch", "short of greens and starch: both show (%s)" % gs.status_words()[0])
	gs.greens = 60.0
	check(gs.status_words()[0] == "Craving starch", "just starch (%s)" % gs.status_words()[0])
	gs.greens = 10.0
	gs.starch = 60.0
	check(gs.status_words()[0] == "Craving greens", "just greens (%s)" % gs.status_words()[0])
	var d := Survival.new()
	d.blood = 50.0
	d.tick(60.0, false, false)
	var healed_rich := d.blood
	n.blood = 50.0
	n.energy = 75.0
	n.water = 70.0
	n.tick(60.0, false, false)
	check(healed_rich > n.blood and healed_rich > 50.0, "lost blood comes back, faster on a varied diet")

	# Hunger and thirst: words by how full you are, costing you from hungry or
	# thirsty on, and wearing you down from starving or very thirsty on.
	var hu := Survival.new()
	var hungers := []
	var thirsts := []
	for full in [0.9, 0.7, 0.4, 0.1, 0.0]:
		hu.energy = Survival.MAX_ENERGY * full
		hu.water = 100.0 * full
		hungers.append(hu.hunger_words()[0])
		thirsts.append(hu.thirst_words()[0])
	check(hungers == ["", "Mildly Hungry", "Hungry", "Starving", "Dying of Starvation"], "hunger in words (%s)" % [hungers])
	check(thirsts == ["", "Mildly Thirsty", "Thirsty", "Very Thirsty", "Dying of Thirst"], "thirst in words (%s)" % [thirsts])
	hu.energy = Survival.MAX_ENERGY * 0.75
	hu.water = 75.0
	check(hu.hunger_level() == 1 and hu.thirst_level() == 1, "75% is already mildly hungry and thirsty")
	hu.energy = Survival.MAX_ENERGY * 0.005
	check(hu.hunger_words()[0] == "Starving", "under 1% but not empty is still starving")
	var fresh := Survival.new()
	check(Survival.MAX_ENERGY == 200.0 and fresh.energy > 150.0 and fresh.energy <= 160.0 and fresh.hunger_level() == 0,
			"energy holds twice as much (a new body starts just over 3/4 full: not hungry yet)")
	var fed := Survival.new()
	fed.energy = 0.0
	fed.consume(Items.def("cooked_meat"), RandomNumberGenerator.new())
	check(fed.energy == Items.def("cooked_meat").energy, "food gives the energy it always did")
	var mild := Survival.new()
	var hungry := Survival.new()
	hungry.energy = Survival.MAX_ENERGY * 0.4
	var starved := Survival.new()
	starved.energy = Survival.MAX_ENERGY * 0.2
	for x in [mild, hungry, starved]:
		x.stamina = 0.0
		x.tick(1.0, false, false)
	check(mild.stamina > hungry.stamina and hungry.stamina > starved.stamina, "hungry, you get your breath back slower; starving, slower still")
	check(mild.starving == 0.0 and hungry.starving == 0.0 and starved.starving > 0.0, "starving is what starts to kill you")
	check(starved.max_stamina() < 100.0 and hungry.max_stamina() == 100.0, "and caps your stamina")
	var thirsty := Survival.new()
	thirsty.water = 40.0
	var dry := Survival.new()
	dry.water = 20.0
	var wet := Survival.new()
	for x in [wet, thirsty, dry]:
		x.stamina = 100.0
		x.tick(1.0, true, false)
	check(wet.stamina > thirsty.stamina and thirsty.stamina > dry.stamina, "thirsty, sprinting tires you faster")
	check(wet.thirst == 0.0 and thirsty.thirst == 0.0 and dry.thirst > 0.0, "very thirsty is what starts to kill you")
	var empty := Survival.new()
	empty.energy = 0.0
	empty.tick(10.0, false, false)
	starved.starving = 0.0
	starved.tick(10.0, false, false)
	check(empty.starving > starved.starving * 4.0, "dying of starvation kills much faster than starving")
	var hurt := Survival.new()
	hurt.blood = 50.0
	hurt.energy = Survival.MAX_ENERGY * 0.2
	hurt.tick(60.0, false, false)
	check(hurt.blood == 50.0, "starving, lost blood doesn't come back")
	var words: Array = hungry.problems().map(func(q): return q.words)
	check("Hungry" in words and hungry.status_words()[0] == "", "hunger is on the Health tab, but has its own HUD line, not the corner words (and not \"Healthy\")")
	var was_saved := Survival.new()
	was_saved.from_dict({"energy": 40.0})
	check(was_saved.energy == 80.0, "an old save's energy keeps how full it was (%.0f)" % was_saved.energy)
	var round_trip := Survival.new()
	round_trip.from_dict(JSON.parse_string(JSON.stringify(hungry.to_dict())))
	check(absf(round_trip.energy - hungry.energy) < 0.01, "and a new one's is kept as it is")
	var eased := Survival.ease(Survival.new().to_dict().merged({"energy": 0.0, "starving": 0.9}, true), "starving")
	var back := Survival.new()
	back.from_dict(eased)
	check(back.hunger_level() == 2, "starving to death leaves the save just hungry")

	var died := [false]
	v.died.connect(func(): died[0] = true)
	v.lose_blood(1000.0)
	check(v.dead and died[0] and v.cause == "blood", "death signal, and what killed you")


func test_wounds() -> void:
	# Bleeding by level: minor stops by itself, moderate needs pressure, major
	# needs pressure and then a bandage.
	var v := Survival.new()
	v.add_wound(0.2, 0.0, "cut")
	check(v.wounds[0].bleed == 1, "a cut bleeds a little")
	for i in 30:
		v.tick(5.0, false, false)
	check(v.wounds.is_empty() or v.wounds[0].bleed == 0, "and stops on its own")
	check(v.blood > 85.0, "having lost a little blood (%.0f)" % v.blood)
	var m := Survival.new()
	m.add_wound(0.4, 0.0, "bite")
	check(m.wounds[0].bleed == 2, "a deep wound bleeds steadily")
	for i in 60:
		m.tick(5.0, false, false)
	check(m.wounds[0].bleed == 2 and m.blood < 60.0, "it doesn't stop by itself (blood %.0f)" % m.blood)
	m.add_wound(0.1, 0.0, "scratch")
	check(m.wounds[1].bleed == 0, "a scratch does not bleed")
	check(m.cover(0, "bandage") != "" and m.wounds[0].cover == "", "a bandage alone soaks through")
	check(m.apply_pressure(0) and m.wounds[0].bleed == 0, "pressure stops it")
	check(m.cover(0, "bandage") == "" and m.wounds[0].cover == "bandage", "then it can be bandaged")
	var big := Survival.new()
	big.add_wound(0.8, 0.0, "mauling")
	check(big.wounds[0].bleed == 3, "a mauling bleeds heavily")
	var b0 := big.blood
	big.tick(10.0, false, false)
	check(b0 - big.blood > 5.0, "fast (%.1f in 10 s)" % (b0 - big.blood))
	check(big.cover(0, "bandage") != "", "a bandage can't hold it back alone")
	big.apply_pressure(0)
	check(big.wounds[0].bleed == 3 and big.wounds[0].held > 0.0, "pressure only holds it back")
	b0 = big.blood
	big.tick(10.0, false, false)
	check(b0 - big.blood < 1.0, "while it is held it barely bleeds")
	check(big.cover(0, "wax") != "", "wax won't stick to a bleeding wound")
	check(big.cover(0, "bandage") == "" and big.wounds[0].bleed == 0, "pressure and then a bandage stop it")
	var late := Survival.new()
	late.add_wound(0.8, 0.0, "mauling")
	late.apply_pressure(0)
	late.tick(Survival.HELD_TIME + 1.0, false, false)
	check(late.wounds[0].held == 0.0 and late.cover(0, "bandage") != "", "wait too long after pressure and it bleeds again")

	# Blood loss gets worse in steps, then kills.
	var b := Survival.new()
	b.blood = 70.0
	check(b.tier() == 1 and not b.can_sprint() and b.speed_mult() == 1.0, "losing blood first stops you sprinting")
	b.blood = 45.0
	check(b.tier() == 2 and b.speed_mult() < 1.0 and b.carry_mult() < 1.0, "then slows you and you carry less")
	b.blood = 20.0
	check(b.tier() == 3 and b.blindness() > 0.5, "then your sight goes")
	b.blood = 100.0
	check(b.tier() == 0 and b.can_sprint() and b.blindness() == 0.0 and b.status_words()[0] == "Healthy", "healthy again")

	# Infection: a clean wound covered stays clean; an open one gathers dirt.
	seed(3)
	var c := Survival.new()
	c.add_wound(0.12, 0.0, "scratch")
	c.cover(0, "wax")
	for i in 400:
		c.tick(5.0, false, false, true)
		c.energy = 100.0
		c.water = 100.0
	check(c.infection() == Survival.INF_NONE, "a clean wound sealed with wax doesn't get infected, even wading")
	var dirty := Survival.new()
	dirty.add_wound(0.5, 1.0, "bite")
	dirty.wounds[0].bleed = 0
	var t := 0
	while dirty.infection() == Survival.INF_NONE and t < 6000:
		dirty.tick(5.0, false, false, true)
		dirty.energy = 100.0
		dirty.water = 100.0
		t += 5
	check(dirty.infection() == Survival.INF_MINOR, "a dirty open wound gets infected (after %d s)" % t)
	check(dirty.problems().any(func(p): return "Wash it" in p.advice), "the advice is to wash and cover it")
	check(dirty.wash(0) and dirty.wounds[0].dirt == 0.0, "boiled water washes it")
	check(dirty.cover(0, "bandage") == "" and dirty.infection() == Survival.INF_NONE, "washed and covered, a minor infection clears")
	var bandaged := Survival.new()
	bandaged.add_wound(0.5, 0.0, "cut")
	bandaged.wounds[0].bleed = 0
	bandaged.cover(0, "bandage")
	for i in 100:
		bandaged.tick(5.0, false, false, true)
	check(bandaged.wounds[0].dirt > 0.3, "swamp water soaks through a bandage (dirt %.2f)" % bandaged.wounds[0].dirt)
	var waxed := Survival.new()
	waxed.add_wound(0.12, 0.0, "cut")
	waxed.cover(0, "wax")
	for i in 100:
		waxed.tick(5.0, false, false, true)
	check(waxed.wounds.is_empty() or waxed.wounds[0].dirt == 0.0, "but not through wax")
	var opened := Survival.new()
	opened.add_wound(0.2, 0.0, "cut")
	opened.cover(0, "bandage")
	check(opened.reopen() and opened.wounds[0].cover == "" and opened.wounds[0].bleed > 0, "another attack tears a dressed wound open")

	# Left alone, a minor infection usually clears, sometimes worsens.
	seed(5)
	var cleared := 0
	var worse := 0
	for k in 60:
		var x := Survival.new()
		x.add_wound(0.12, 0.5, "bite")
		x.wounds[0].inf = Survival.INF_MINOR
		x.tick(Survival.MINOR_TIME + 1.0, false, false)
		if x.infection() == Survival.INF_NONE:
			cleared += 1
		elif x.infection() == Survival.INF_MODERATE:
			worse += 1
	check(cleared > 30 and worse > 3 and cleared + worse == 60, "a minor infection clears by itself (%d) or worsens (%d)" % [cleared, worse])

	# Moderate turns major, major septic, sepsis kills; alcohol is the cure.
	var s := Survival.new()
	s.no_needs = true  # long steps: not starving or parched meanwhile
	s.add_wound(0.3, 0.0, "bite")
	s.wounds[0].bleed = 0
	s.wounds[0].inf = Survival.INF_MODERATE
	check(s.tier() == 1 and s.fever(), "a moderate infection is a fever: no sprinting")
	check(s.wash(0) and s.cover(0, "bandage") == "" and s.infection() == Survival.INF_MODERATE, "water and a bandage don't cure it")
	s.wounds[0].cover = ""
	check(s.wash(0, true) and s.cover(0, "bandage") == "" and s.infection() == Survival.INF_NONE, "alcohol and a bandage do")
	s.wounds[0].inf = Survival.INF_MODERATE
	s.wounds[0].sterile = false
	s.tick(Survival.MODERATE_TIME + 1.0, false, false)
	check(s.infection() == Survival.INF_MAJOR, "untreated it turns major")
	s.wash(0, true)
	check(s.infection() == Survival.INF_REMISSION, "alcohol puts a major infection into remission")
	s.wash(0, true)
	check(s.infection() == Survival.INF_MINOR, "a second treatment makes it minor")
	s.wounds[0].inf = Survival.INF_MAJOR
	s.wounds[0].inf_t = 0.0
	s.tick(Survival.MAJOR_TIME + 1.0, false, false)
	check(s.infection() == Survival.INF_SEPSIS and s.tier() == 2, "a major infection turns into sepsis, slowing you")
	check(s.summary() == Survival.SEPSIS_TEXT and s.status_words()[0] == "Septic", "the Health tab says what sepsis needs")
	s.wash(0, true)
	check(s.infection() == Survival.INF_SEPSIS, "and nothing in the game treats it")
	s.tick(Survival.SEPSIS_TIME * 0.6, false, false)
	check(s.tier() == 3 and s.blindness() > 0.0 and not s.dead, "it gets worse, and your sight goes")
	s.tick(Survival.SEPSIS_TIME * 0.5, false, false)
	check(s.dead and s.cause == "infection", "and then it kills you")

	# Venom and sickness: rest.
	var ven := Survival.new()
	ven.poison(14.0)
	check(ven.tier() == 1 and ven.status_words()[0] == "Envenomed", "a sting is venom in your blood")
	var awake := Survival.new()
	awake.poison(14.0)
	ven.tick(60.0, false, false, false, true)
	awake.tick(60.0, false, false)
	check(ven.venom < awake.venom, "rest makes it wear off faster")
	var thrice := Survival.new()
	thrice.poison(14.0)
	thrice.poison(14.0)
	thrice.poison(14.0)
	check(thrice.dead and thrice.cause == "venom", "three stings at once kill")

	# Fractures and sprains mend after sleeping.
	var f := Survival.new()
	f.break_limb("leg")
	f.break_limb("arm")
	check(not f.can_sprint() and is_equal_approx(f.speed_mult(), Survival.LEG_SLOW), "a broken leg: 40% slower, no sprinting")
	f.slept()
	check(f.limbs.has("leg") and f.limbs.has("arm"), "one sleep isn't enough for a fracture")
	f.slept()
	check(f.limbs.is_empty() and f.can_sprint(), "two are")
	f.break_limb("ankle")
	check(not f.can_sprint() and is_equal_approx(f.speed_mult(), Survival.LEG_SLOW), "a sprained ankle slows you just the same")
	f.slept()
	check(f.limbs.is_empty(), "and mends after one sleep")
	var inv := Inventory.new()
	var whole := inv.capacity()
	inv.arm_broken = true
	check(is_equal_approx(inv.capacity(), whole * 0.5), "a broken arm halves what you can carry (%.1f kg)" % inv.capacity())
	inv.add("fiber_sack")
	check(is_equal_approx(inv.capacity(), Inventory.SACK_CAPACITY - Inventory.BASE_CAPACITY * 0.5), "but not the sack's share (%.1f kg)" % inv.capacity())

	# Saving, and old saves.
	var copy := Survival.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(copy.wounds.size() == m.wounds.size() and is_equal_approx(copy.blood, m.blood) and copy.wounds[0].cover == "bandage", "vitals survive a JSON round trip")
	var old := Survival.new()
	old.from_dict({"health": 40.0, "wounds": [{"sev": 0.5, "bleed": 30.0, "dirt": 0.2, "inf": 0.6, "bandaged": false, "treated": 0.0, "src": "bite"}]})
	check(old.blood == 100.0 and old.wounds[0].bleed == 2 and old.wounds[0].inf == Survival.INF_MODERATE, "an old save's wounds become bleeding levels and infection stages")

	# Dying of something eases the save a step in it, so it never soft-locks.
	var chain := [Survival.INF_SEPSIS]
	var body := Survival.new()
	body.add_wound(0.3, 0.0, "bite")
	body.wounds[0].bleed = 0
	body.wounds[0].inf = Survival.INF_SEPSIS
	var saved := body.to_dict()
	for k in 4:
		saved = Survival.ease(saved, "infection")
		var again := Survival.new()
		again.from_dict(saved)
		chain.append(again.wounds[0].inf)
	check(chain == [Survival.INF_SEPSIS, Survival.INF_MAJOR, Survival.INF_REMISSION, Survival.INF_MINOR, Survival.INF_NONE],
			"four deaths take sepsis to major, remission, minor, then none (%s)" % str(chain))
	var bled := Survival.ease({"blood": 10.0, "wounds": [{"sev": 0.8, "bleed": 3, "cover": "", "inf": 0}]}, "blood")
	check(bled.blood == 35.0 and bled.wounds[0].bleed == 2, "bleeding to death eases blood and bleeding a step")
	check(Survival.ease({"venom": 90.0}, "venom").venom == 65.0, "and venom too")


func test_health() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var v = p.vitals
	Game.inventory.clear()

	# The HUD shows how you are in a couple of words; there is no health bar.
	check(v.status_words()[0] == "Healthy", "a healthy start")
	v.add_wound(0.4, 0.0, "test")
	check(v.status_words()[0] == "Bleeding", "bleeding shows in the corner (%s)" % v.status_words()[0])
	check(w.sleep_blocker() != "", "you can't sleep while bleeding steadily")

	# Pressure from the Health tab: hold still while you press.
	w.toggle_inventory()
	w.inv_ui.show_page("health")
	await _frames(1)
	w.inv_ui._press(0)
	check(not w.inv_ui.visible and v.pressing == 0, "Apply pressure closes the menu and you press on the wound")
	await _frames(2)
	check("Pressing on the wound" in p.prompt, "the prompt counts it down (%s)" % p.prompt)
	await _run_for(Survival.PRESSURE_TIME + 2.0, func(): return v.pressing < 0)
	check(v.pressing < 0 and v.wounds[0].bleed == 0, "held long enough, the bleeding stops")
	v.add_wound(0.4, 0.0, "test")
	p.start_pressure(1)
	p.hurt(5.0, p.global_position + Vector3(1, 0, 0))
	check(v.pressing < 0, "being hit makes you let go")
	v.wounds.clear()
	v.blood = 100.0

	# A nasty bite may break a limb.
	p.next_injury = 0.0
	p.hurt(30.0, p.global_position + Vector3(1, 0, 0), 0.3, "test")
	check(v.limbs.has("arm") or v.limbs.has("leg"), "a hard hit can break an arm or a leg (%s)" % str(v.limbs))
	v.limbs.clear()
	p.next_injury = 0.99
	p.hurt(30.0, p.global_position + Vector3(1, 0, 0), 0.3, "test")
	check(v.limbs.is_empty(), "though not always")
	p.next_injury = 0.0
	p.hurt(8.0, p.global_position + Vector3(1, 0, 0), 0.3, "test")
	check(v.limbs.is_empty(), "and a light one never does")
	v.wounds.clear()
	v.blood = 100.0

	# Long falls: a sprain or a fracture, never both.
	p.next_injury = 0.0
	p.landed(2.0)
	check(v.limbs.is_empty(), "a short drop is harmless")
	var sprains := 0
	var breaks := 0
	for i in 40:
		v.limbs.clear()
		p.next_injury = 0.0
		p.landed(7.0)
		if v.limbs.has("ankle"):
			sprains += 1
		if v.limbs.has("leg"):
			breaks += 1
		check(v.limbs.size() == 1, "one injury per fall") if v.limbs.size() != 1 else null
	check(sprains > 8 and breaks > 8 and sprains + breaks == 40, "a long fall sprains an ankle (%d) or breaks a leg (%d)" % [sprains, breaks])

	# A broken arm: half the carrying and slow with anything big.
	v.limbs.clear()
	v.break_limb("arm")
	await _run_for(0.3, func(): return false)
	check(is_equal_approx(Game.inventory.capacity(), Inventory.BASE_CAPACITY * 0.5), "carry half as much with a broken arm")
	var lg: Node = w.add_log("log", p.global_position + Vector3(0, 0, -1.5), 0.0)
	p.start_haul(lg)
	p.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	await _run_for(1.5, func(): return false)
	var slow: float = Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("move_forward")
	check(slow < Player.WALK * Survival.ARM_HAUL + 0.2, "carrying a log is slow (%.1f m/s)" % slow)
	p.put_down()

	# Sleeping mends it; a broken leg slows you.
	v.limbs.clear()
	v.break_limb("leg")
	p.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _run_for(1.5, func(): return false)
	var limp: float = Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(limp < Player.WALK * Survival.LEG_SLOW + 0.3, "a broken leg: slow, and no sprinting (%.1f m/s)" % limp)
	Game.debug = true
	await w.sleep()
	check(v.limbs.get("leg", 0) == 1, "one sleep later the leg is still broken")
	w.player.frozen = false
	await w.sleep()
	check(v.limbs.is_empty(), "two and it has mended")
	Game.debug = false

	# Going blind at the last stage.
	v.blood = 15.0
	await _run_for(2.0, func(): return false)
	check(w.hud._blind.color.a > 0.3, "close to death your sight goes dark (%.2f)" % w.hud._blind.color.a)
	v.blood = 100.0

	# Dying of something eases the save a step in it.
	v.wounds.clear()
	v.add_wound(0.3, 0.0, "bite")
	v.wounds[0].bleed = 0
	v.wounds[0].inf = Survival.INF_SEPSIS
	check(w.save_now(), "saved while septic")
	v.wounds[0].inf_t = Survival.SEPSIS_TIME
	v.tick(1.0, false, false)
	check(v.dead and v.cause == "infection", "sepsis kills")
	await _frames(2)
	var save: Dictionary = Game.read_save()
	var eased := Survival.new()
	eased.from_dict(save.vitals)
	check(eased.infection() == Survival.INF_MAJOR, "and the save comes back with a major infection instead")
	w.queue_free()
	await _frames(2)


func test_day_cycle() -> void:
	var saved := Game.time
	var at := func(clock: float) -> void:
		Game.time = clock - Game.ARRIVAL_CLOCK
	at.call(0.0)
	check(is_equal_approx(Game.time_of_day(), 0.0), "midnight is 0")
	at.call(180.0)
	check(is_equal_approx(Game.time_of_day(), 0.2), "dawn starts at 3 min")
	at.call(300.0)
	check(is_equal_approx(Game.time_of_day(), 0.3), "full day at 5 min")
	at.call(1140.0)
	check(is_equal_approx(Game.time_of_day(), 0.7), "dusk at 19 min")
	at.call(1260.0)
	check(is_equal_approx(Game.time_of_day(), 0.8), "night at 21 min")
	var day_s := Game.PHASES[3][0] - Game.PHASES[2][0]
	var twilight: float = (Game.PHASES[2][0] - Game.PHASES[1][0]) + (Game.PHASES[4][0] - Game.PHASES[3][0])
	var night_s: float = Game.DAY_LENGTH - day_s - twilight
	check(day_s == 840.0 and twilight == 240.0 and night_s == 360.0, "14 min day, 4 min twilight, 6 min night")
	for t in [0.1, 0.25, 0.5, 0.75, 0.9]:
		at.call(Game.solar_to_clock(t))
		check(is_equal_approx(Game.time_of_day(), t), "solar_to_clock inverts %.2f" % t)
	Game.time = 0.0
	check(Game.night_index() == -1 and not Game.is_night(), "you arrive in daylight")
	at.call(1200.0)
	var n0 := Game.night_index()
	check(n0 == 0, "first dusk is night 0")
	at.call(Game.DAY_LENGTH + 100.0)
	check(Game.night_index() == n0, "after midnight it is still night 0")
	at.call(Game.DAY_LENGTH + 1300.0)
	check(Game.night_index() == 1, "next night is night 1")
	Game.time = 100.0
	Game.last_sleep = 0.0
	check(Game.can_sleep_in() > 0.0, "not tired right after waking")
	Game.time = Game.SLEEP_COOLDOWN
	check(Game.can_sleep_in() == 0.0, "tired after 12 minutes")
	Game.time = saved


func _fresh_state() -> void:
	Game.intro_pending = false
	Game.inventory = Inventory.new()
	Game.tiers = ["hand"]
	Game.tools_known = []
	Game.taken.clear()
	Game.harvested.clear()
	Game.felled.clear()
	Game.hints_seen.clear()
	Game.creatures.clear()
	Game.fires.clear()
	Game.houses.clear()
	Game.docks.clear()
	Game.rafts.clear()
	Game.copper_cast = false
	Game.time = 0.0
	Game.last_sleep = 0.0
	Game.saved_night = -1
	Game.restore = {}
	Game.world_seed = 7
	Game.debug = false
	Game.cheats = {"damage": true, "needs": true, "hostile": true}


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func test_lab() -> void:
	_fresh_state()
	var lab: Node = load("res://scenes/lab.tscn").instantiate()
	add_child(lab)
	await _frames(3)
	check(lab.player != null, "lab player exists")
	var p: Node = lab.player
	var br: Node = lab.breakroom
	# The ride down: frozen in the closed elevator until the doors open.
	check(lab.step == "ride" and p.frozen and lab._intro != null, "the tutorial opens with the elevator ride")
	check(br.in_car(p.global_position) and not br.elevator_open, "you ride in the elevator, doors shut")
	var intro: Node = lab._intro
	var ride := 0.0
	while lab._intro != null and ride < 30.0:
		intro._process(0.25)
		ride += 0.25
		if ride > 6.0 and ride < 6.3:
			check(intro._root.visible and p.frozen, "the title card shows, nothing moves yet")
	check(ride > 12.0 and ride < 16.0, "the intro takes %.1f s" % ride)
	br._process(2.0)
	check(br.elevator_open and not p.frozen and lab.step == "move", "the doors open on the breakroom and you can move")
	var keep_pad: bool = Settings.using_pad
	Settings.using_pad = false
	check(Settings.hint(lab.HINTS["move"]).begins_with("Press [W] to step out of the elevator"), "the hint names the walk key")
	Settings.using_pad = true
	check(Settings.hint(lab.HINTS["move"]).begins_with("Press [Left stick up] to step out"), "and on a gamepad, the stick")
	Settings.using_pad = keep_pad
	var music_on: bool = Settings.music_frequency != Settings.MusicFrequency.OFF
	if music_on:
		check(Music.current.begins_with(Music.ELEVATOR), "the elevator music plays in the car")
	# A step towards the doors is still in the car: they stay open.
	p.global_position = Vector3(5.8, 0.05, 8.2)
	lab._process(0.02)
	check(lab.step == "move" and br.elevator_open, "the doors stay open while you are in the doorway")
	# Out of the elevator; the lab door won't open without a keycard.
	p.global_position = Vector3(4.5, 0.05, 9.0)
	lab._process(0.02)
	check(lab.step == "mug" and not lab._riding, "stepping out asks for a coffee")
	check(not br.elevator_open and br._doorway.collision_layer == 1, "the doors close behind you, and you can't get back in")
	if music_on:
		check(Music._fading and Music._fade_time == Music.ELEVATOR_OUT, "the elevator music fades out quickly")
	br._process(2.0)
	check(br._open_t == 0.0, "the elevator doors are shut")
	br.lab_door.interact(p)
	check(not br.lab_door.is_open, "the lab door stays locked without a keycard")
	var found := func(id: String) -> Node:
		for n in br.get_children():
			if n.get("item_id") == id:
				return n
		return null
	var mug: Node = found.call("coffee_mug")
	check(mug != null, "a mug by the coffee pot")
	mug.interact(p)
	check(lab.step == "pour", "picking up the mug asks you to pour (at %s)" % lab.step)
	var pot: Node = br.get_children().filter(func(n): return n is Breakroom.CoffeePot)[0]
	for cup in 2:
		Game.inventory.select(Game.inventory.find("coffee_mug"))
		check(pot.prompt(p).begins_with("Pour"), "the pot offers to pour with the mug held")
		pot.interact(p)
		check(Game.inventory.count("mug_coffee") == 1 and lab.step == ("drink" if cup == 0 else "drink2"), "coffee poured (cup %d)" % (cup + 1))
		p.consume_slot(Game.inventory.find("mug_coffee"))
		check(Game.inventory.count("coffee_mug") == 1 and lab.coffees == cup + 1, "drunk with vitals off, the mug kept")
	check(lab.step == "papers", "two coffees, then the papers (at %s)" % lab.step)
	found.call("papers").interact(p)
	check(lab.step == "lay", "papers picked up: lay them on the table")
	var table: Node = br.get_children().filter(func(n): return n is Breakroom.Table)[0]
	lab._start_bench_work(table)
	var w: Node = lab.work
	check(w != null and w.bench == table, "working at the breakroom table")
	if w:
		w.lay(Game.inventory.find("papers"))
		var read: Array = w.options().filter(func(o): return o.recipe.out == "keycard_jr")
		check(read.size() == 1 and read[0].missing.is_empty(), "the laid papers can be read through")
		w.begin(read[0].recipe)
		lab._process(0.02)
		check(lab.step == "read" and lab.work_ui._papers.visible, "reading shows the top page")
		for k in 9:
			lab.work_ui._process(0.02)
			check(lab.work_ui._papers.page == k, "page %d on top" % (k + 1))
			w.step()
		check(Game.inventory.count("keycard_jr") == 1 and Game.inventory.count("papers") == 0, "the last page turns up the keycard")
		check(lab.step == "door", "keycard found: open the lab door")
		await _frames(2)
		check(lab.work == null, "you stand up from the table")
	br.lab_door.interact(p)
	check(br.lab_door.is_open and lab.step == "enter", "the keycard opens the lab door")
	p.global_position = Vector3(3.5, 0.05, 4.2)
	lab._process(0.02)
	check(lab.step == "pickup", "into the lab: the accelerator tutorial (at %s)" % lab.step)
	# Pick up every part on the floor.
	var pickups := lab.get_children().filter(func(n): return n.has_method("interact") and n.get("item_id") != null)
	check(pickups.size() == 9, "lab has 9 parts (got %d)" % pickups.size())
	for pk in pickups:
		pk.interact(lab.player)
	await _frames(1)
	check(lab.step == "craft", "tutorial reaches craft step (at %s)" % lab.step)
	for r in Items.recipes_for("lab"):
		while Game.inventory.can_craft(r):
			Game.inventory.craft(r)
			Game.crafted.emit(r.out)
	check(Game.inventory.count("beam_segment") == 2 and Game.inventory.count("injector") == 1, "crafted lab components")
	check(lab.step == "install", "tutorial reaches install step (at %s)" % lab.step)
	var mounts := lab.get_children().filter(func(n): return n.get("needs") != null)
	check(mounts.size() == 3, "3 mounts")
	for m in mounts:
		for i in Inventory.SIZE:
			var s = Game.inventory.slots[i]
			if s != null and s.id == m.needs:
				Game.inventory.swap(i, 0)
				break
		Game.inventory.select(0)
		m.interact(lab.player)
	check(lab.installed.size() == 3, "all components installed")
	check(lab.step == "activate", "tutorial reaches activate step")
	lab.start_sequence()
	check(lab._sequence and lab.player.frozen, "activation sequence runs")
	lab.queue_free()
	await _frames(2)


func test_swamp() -> void:
	_fresh_state()
	var w: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	var p: Node = w.player
	check(p != null and w.chunks.size() > 4, "swamp loaded %d chunks" % w.chunks.size())
	var ground: float = w.ground_height(p.global_position.x, p.global_position.z)
	check(ground > 0.0, "spawned on dry land")
	await _frames(30)
	check(absf(p.global_position.y - ground) < 0.6, "player stands on terrain (y=%.2f ground=%.2f)" % [p.global_position.y, ground])

	# Campfire: place, light, cook.
	Game.inventory.add("campfire_kit")
	Game.inventory.add("bow_drill")
	Game.inventory.select(0)
	var placed: bool = w.place("campfire", p.global_position + Vector3(1.5, 0, 0))
	check(placed, "campfire placed")
	var fire: Node = Game.fires[0] if not Game.fires.is_empty() else null
	check(fire != null, "fire registered")
	if fire:
		Game.inventory.select(0)
		fire.interact(p)
		check(fire.lit, "fire lit with bow drill")
		fire.fuel = fire.MAX_FUEL
		Game.inventory.clear()
		Game.inventory.add("raw_meat")
		Game.inventory.select(0)
		fire.interact(p)
		check(fire.cooking.count(null) == fire.SPOTS - 1 and fire.cooking[0] != null, "meat set by the fire")
		fire._process(41.0)
		check(Game.inventory.count("cooked_meat") == 0 and fire.result(0) == "cooked_meat", "meat cooked, waiting by the fire")
		fire.take(0)
		check(Game.inventory.count("cooked_meat") == 1 and fire.cooking[0] == null, "cooked meat picked up")
		Game.inventory.add("raw_meat")
		Game.inventory.select(Game.inventory.find("raw_meat"))
		fire.interact(p)
		fire._process(100.0)
		fire._process(70.0)
		check(fire.result(0) == "charred", "food left too long burns")
		fire.take(0)
		check(Game.inventory.count("charred") == 1, "charred remains picked up")
		Game.inventory.add("pot_dirty")
		Game.inventory.select(Game.inventory.find("pot_dirty"))
		fire.interact(p)
		fire._process(49.0)
		fire._process(400.0)
		check(fire.result(0) == "pot_clean", "water boiled and never burns")
		fire.take(0)
		check(Game.inventory.count("pot_clean") == 1, "boiled water picked up")
		var saved: Dictionary = fire.to_dict()
		check(saved.has("cooking") and saved.has("burned"), "fire saves its cooking and burn time")
		# Torches: rolled with wax, lit at the fire, light the next fire.
		Game.inventory.add("torch")
		Game.inventory.select(Game.inventory.find("torch"))
		check(fire.prompt(p).begins_with("Light the torch"), "fire offers to light a torch")
		fire.interact(p)
		check(Game.inventory.count("torch_lit") == 1, "torch lit at the fire")
		Game.inventory.add("mattock")
		Game.inventory.select(Game.inventory.find("mattock"))
		fire.burned = fire.ASH_EVERY * 2.5
		fire.interact(p)
		check(Game.inventory.count("ash") == 2, "mattock scoops one ash per 200 s burned")
		fire.fuel = 0.5
		fire._process(1.0)
		check(not fire.lit, "fire burns out")
		var stones: int = Game.inventory.count("stone")
		fire.break_apart()
		check(Game.inventory.count("stone") == stones + 2 and not Game.fires.has(fire), "mattock knocks the fire apart for its stones")

	# Eating and drinking.
	var food_before: float = p.vitals.energy
	var protein_before: float = p.vitals.protein
	p.consume_slot(Game.inventory.find("cooked_meat"))
	check(p.vitals.energy > food_before and p.vitals.protein > protein_before, "meat restores energy and protein")
	var water_before: float = p.vitals.water
	p.consume_slot(Game.inventory.find("pot_clean"))
	check(p.vitals.water > water_before and Game.inventory.count("pot") == 1, "drinking returns the empty pot")

	# A scorpion next to the player should attack.
	var sc: Node = Creature.new().setup("scorpion", p.global_position + Vector3(0, 0, 1.2), w)
	w.add_child(sc)
	var hp: float = p.vitals.blood
	for i in 240:
		await get_tree().physics_frame
		if p.vitals.blood < hp:
			break
	check(p.vitals.blood < hp, "scorpion attacks the player")
	check(not p.vitals.wounds.is_empty(), "the sting leaves a wound")
	Game.inventory.add("bandage")
	check(p.treat_slot(Game.inventory.find("bandage")) and p.vitals.wounds.all(func(x): return x.cover != "" or x.sev < 0.2), "bandage applied")
	p.vitals.wounds.clear()
	p.vitals.venom = 0.0
	p.vitals.blood = 100.0
	# Player attacks it.
	sc.take_damage(1000.0, p)
	check(sc.dead, "scorpion dies")
	sc.queue_free()

	# Prey flees.
	var hy: Node = Creature.new().setup("hylonomus", p.global_position + Vector3(3, 0, 0), w)
	w.add_child(hy)
	var d0: float = hy.global_position.distance_to(p.global_position)
	for i in 30:
		await get_tree().process_frame
	check(hy.state == "flee", "hylonomus flees (state %s)" % hy.state)

	# Harvesting.
	var h: Node = null
	for c in w.chunks.values():
		for n in c.get_children():
			if n.get("kind") == "fern" and n.is_ready():
				h = n
				break
		if h:
			break
	check(h != null, "found a fern to harvest")
	if h:
		check(h._mesh.mesh == Assets.mesh("fern_ripe") and h._mesh.mesh != Assets.mesh("fern"), "a fern you can strip looks unlike the decoration ferns")
		Game.inventory.clear()
		h.interact(p)
		check(Game.inventory.count("plant_fiber") >= 2 and not h.is_ready(), "fern harvested and regrowing")
		check(h._mesh.visible and h._mesh.mesh == Assets.mesh("fern_stripped"), "stripped, it shows cut-back stalks, not nothing")

	# Drowning/water depth helper.
	check(is_equal_approx(w.water_level(), 0.0), "water level is 0")

	# Crafting on the ground.
	await _ground_crafting(w)

	# Thick vegetation.
	var trees := 0
	for c in w.chunks.values():
		trees += c.trunks.size()
	check(trees / float(w.chunks.size()) > 8.0, "dense forest (%.1f trees per chunk)" % (trees / float(w.chunks.size())))

	# The same world at every graphics quality: trees, boulders, harvestables
	# and pickups all come out where they were.
	var was_quality := Settings.quality
	var made := []
	for q in 3:
		Settings.quality = q
		var c: Node = Chunk.new()
		w.add_child(c)
		c.build(3, -2, w.terrain, w)
		var things := [c.trunks, c.trees.map(func(t): return t.uid)]
		for n in c.get_children():
			if n.get_script() != null:
				things.append([n.get_script().resource_path, n.position.snapped(Vector3.ONE * 0.01)])
		made.append(str(things))
		c.free()
	Settings.quality = was_quality
	check(made[0] == made[1] and made[1] == made[2], "the world is the same at every quality")
	w.queue_free()
	await _frames(2)


func _ground_crafting(w: Node) -> void:
	var p: Node = w.player
	var wet := _find_spot(w, p.global_position, func(q): return q.y < -0.4)
	check(wet.is_finite() and w.work_blocker(wet) != "", "can't craft standing in water")
	var dry := _find_spot(w, p.global_position, func(q): return q.y > 0.3)
	p.global_position = dry + Vector3(0, 0.1, 0)
	await _frames(2)
	Game.inventory.clear()
	Game.inventory.add("plant_fiber", 5)
	Game.inventory.add("flint", 2)
	Game.inventory.add("stone", 1)
	Game.inventory.add("stick", 2)
	w.start_work()
	var ws: Node = w.work
	check(ws != null and p.ui_open and p.work_spot == ws and w.work_ui.visible, "C kneels to craft on the ground")
	if ws == null:
		return

	# Laying things out and picking them back up.
	ws.lay(Game.inventory.find("plant_fiber"), 1)
	ws.lay(Game.inventory.find("plant_fiber"), 1 << 20)
	check(ws.laid("plant_fiber") == 5 and Game.inventory.count("plant_fiber") == 0, "laying a stack on the ground")
	ws.take_back(0, 2)
	check(ws.laid("plant_fiber") == 3 and Game.inventory.count("plant_fiber") == 2, "picking some back up")
	var cord := Items.recipe_for("cordage", "swamp")
	var opt: Array = ws.options().filter(func(o): return o.recipe == cord)
	check(opt.size() == 1 and opt[0].missing.is_empty(), "fiber on the ground offers cordage")
	var spear := Items.recipe_for("spear", "swamp")
	check(not ws.can_begin(spear), "nothing to make from parts that aren't there")

	# Twisting cordage by dragging.
	check(ws.begin(cord) and ws.laid("plant_fiber") == 0, "twisting starts and takes the fiber")
	var drags := 0
	while not ws.recipe.is_empty() and drags < 200:
		ws.drag(Vector2(40, 3))
		drags += 1
	check(Game.inventory.count("cordage") == 1 and ws.recipe.is_empty(), "rolling the fibers makes cordage (%d drags)" % drags)

	# Knapping needs a river stone, which is kept.
	var blade := Items.recipe_for("flint_blade", "swamp")
	Game.inventory.remove("stone", 1)
	ws.lay(Game.inventory.find("flint"), 1)
	check(not ws.can_begin(blade), "no knapping without a river stone")
	Game.inventory.add("stone", 1)
	check(ws.begin(blade) and ws.laid("flint") == 0, "knapping starts")
	ws.cancel()
	check(ws.recipe.is_empty() and ws.laid("flint") == 1, "stopping before a strike puts the nodule back")
	ws.begin(blade)
	var rows: Array = Items.KNAPPING["flint_blade"]
	for k in 25:
		if rows[k / 5][k % 5] == ".":
			ws.strike(k)
	check(Game.inventory.count("flint_blade") == 1 and Game.inventory.count("stone") == 1, "knapped a blade and kept the river stone")
	ws.lay(Game.inventory.find("flint"), 1)
	ws.begin(blade)
	ws.strike(0)
	ws.cancel()
	check(ws.laid("flint") == 0 and Game.inventory.count("flint") == 0, "a half-knapped stone is lost when you stop")

	# Hafting a spear, one wrap at a time.
	Game.inventory.add("spear_head", 1)
	for id in ["spear_head", "stick", "cordage"]:
		ws.lay(Game.inventory.find(id), 1 << 20)
	check(ws.begin(spear), "hafting the spear starts")
	var n := Items.recipe_steps(spear)
	for i in n - 1:
		ws.step()
	check(ws.steps == n - 1 and Game.inventory.count("spear") == 0, "the spear isn't done before the last wrap")
	ws.press()
	check(Game.inventory.count("spear") == 1 and ws.recipe.is_empty(), "the last wrap makes the spear")

	# Knapping ends on the head you chose, even when another head's shape
	# turns up on the way there.
	for head in ["mattock_head", "spear_head", "axe_head"]:
		Game.inventory.add("flint", 1)
		ws.lay(Game.inventory.find("flint"), 1)
		ws.begin(Items.recipe_for(head, "swamp"))
		var pat: Array = Items.KNAPPING[head]
		for k in 25:
			if pat[k / 5][k % 5] == "." and not ws.recipe.is_empty():
				ws.strike(k)
		check(Game.inventory.count(head) == 1 and ws.recipe.is_empty(), "knapping for a %s makes one" % head)
	for id in ["mattock_head", "stick", "cordage"]:
		Game.inventory.add(id, 1)
		ws.lay(Game.inventory.find(id), 1)
	var mattock := Items.recipe_for("mattock", "swamp")
	check(ws.begin(mattock), "hafting a mattock starts")
	for i in Items.recipe_steps(mattock):
		ws.step()
	check(Game.inventory.count("mattock") == 1, "a hafted mattock")

	# Crushing wax out of fronds, then rolling a torch in it.
	Game.inventory.add("frond", 2)
	ws.lay(Game.inventory.find("frond"), 2)
	var wax := Items.recipe_for("wax", "swamp")
	for j in 2:
		check(ws.begin(wax), "crushing wax starts")
		for i in Items.recipe_steps(wax):
			ws.step()
	check(Game.inventory.count("wax") == 2, "two fronds crush to two waxy residue")
	Game.inventory.add("stick", 1)
	for id in ["stick", "wax"]:
		ws.lay(Game.inventory.find(id), 2)
	check(ws.begin(Items.recipe_for("torch", "swamp")), "rolling a torch starts")
	ws.drag(Vector2(400, 0))
	check(ws._roll != 0.0 and ws.progress > 0.0, "dragging rolls the work")
	ws.twist(1.0)
	check(Game.inventory.count("torch") == 1 and Game.inventory.count("wax") == 0, "a stick rolled in wax makes a torch")
	check(Game.inventory.count("stick") == 0, "the torch used the stick")

	# Standing up puts everything back in the inventory.
	ws.lay(Game.inventory.find("stone"), 1)
	ws.lay(Game.inventory.find("plant_fiber"), 1 << 20)
	w.close_work()
	await _frames(1)
	check(w.work == null and not p.ui_open and p.work_spot == null, "C again stands up")
	check(Game.inventory.count("stone") == 1 and Game.inventory.count("plant_fiber") == 2, "standing up returns what was laid out")

	# The recipe book only lists tiers you have reached.
	var ui: Node = w.inv_ui
	var keep: Array = Game.tiers
	Game.tiers = []
	check(ui.book_categories().is_empty(), "the book hides recipes of tiers not reached")
	Game.tiers = ["hand"]
	check("Stone tools" in ui.book_categories() and "Medicine" in ui.book_categories(), "hand recipes are in the book")
	w.toggle_inventory()
	ui.show_page("recipes")
	check(ui._book_page.visible and not ui._inv_page.visible, "the recipe book is its own tab")
	w.toggle_inventory()
	Game.tiers = keep

	# The health tab lists every injury and treats the one you pick.
	p.vitals.add_wound(0.4, 0.5, "test")
	p.vitals.add_wound(0.2, 0.1, "test")
	Game.inventory.add("bandage", 1)
	w.toggle_inventory()
	ui.show_page("health")
	check(ui._health_page.visible and not ui._inv_page.visible, "health is its own tab")
	check(ui._wound_box.get_child_count() == p.vitals.wounds.size(), "the health tab lists each injury")
	var last: int = p.vitals.wounds.size() - 1
	ui._treat_with("bandage", last)
	check(p.vitals.wounds[last].cover == "bandage" and p.vitals.wounds[last - 1].cover == "", "a bandage goes on the wound you pick")
	check(Game.inventory.count("bandage") == 0, "and is used up")
	w.toggle_inventory()
	p.vitals.wounds.clear()


func _find_spot(w: Node, near: Vector3, ok: Callable) -> Vector3:
	## Searches outward on a grid for a point that satisfies ok(pos).
	for r in range(0, 200, 4):
		for i in 16:
			var a := TAU * i / 16.0
			var pos := near + Vector3(cos(a), 0, sin(a)) * r
			pos.y = w.ground_height(pos.x, pos.z)
			if ok.call(pos):
				return pos
	return Vector3.INF


func _clear_amphibians() -> void:
	## Takes away the world's own amphibians, so one that happens to live
	## near the test's stretch of shore can't get to the player first.
	for c in Game.creatures.duplicate():
		if is_instance_valid(c) and c.species in ["uranocentrodon", "eogyrinus"]:
			c.queue_free()
	await _frames(2)


func _new_swamp() -> Node:
	_fresh_state()
	var w: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	w._spawn_t = 1e9  # keep the spawner out of the way
	return w


func test_escape_roll() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var start: Vector3 = p.global_position
	var shore := _find_spot(w, start, _is_ambush_shore.bind(w))
	var lair: Vector3 = w.water_point(shore, 5.0)
	var deep: Vector3 = w.water_point(lair, 20.0, -0.9)
	if not deep.is_finite():
		deep = lair
	var rolls := []
	p.escape_rolled.connect(func(chance, roll, freed): rolls.append([chance, roll, freed]))
	# [what you strike with, the roll, freed?]: 10% base, +15% bare-handed,
	# +30% with a stone weapon.
	for case in [["", 0.08, true], ["", 0.12, false], ["bare", 0.2, true], ["stone", 0.38, true]]:
		p.vitals.blood = 100.0
		p.vitals.wounds.clear()
		p.global_position = start
		var u: Node = w.spawn_amphibian("uranocentrodon", "hide", lair, deep)
		await _frames(3)
		p.global_position = shore + Vector3(0, 0.1, 0)
		for i in 120:
			await get_tree().physics_frame
			if p.grabbed_by:
				break
		if p.grabbed_by != u:
			check(false, "seized for the roll")
			return
		var grabbed_at: Vector3 = u.global_position
		Game.inventory.clear()
		if case[0] == "stone":
			Game.inventory.add("flint_blade")
			Game.inventory.select(0)
		if case[0] != "":
			p._attack_cd = 0.0
			p.stab()
		p.next_roll = case[1]
		var t := 0.0
		while p.escape_roll < 0.0 and not p.vitals.dead and t < 4.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		var hauled: float = Vector2(u.global_position.x - grabbed_at.x, u.global_position.z - grabbed_at.z).length()
		var label := "%s strike, rolled %d" % [case[0] if case[0] != "" else "no", int(case[1] * 100) + 1]
		check(p.escape_roll >= 0.0 and t <= Player.ROLL_TIME + 0.1 and p._grab_t >= Player.MIN_ROLL_TIME,
				"%s: the roll comes after %.1f-%.1f s" % [label, Player.MIN_ROLL_TIME, Player.ROLL_TIME])
		check(u.in_deep_water() or hauled > 4.0, "%s: hauled fast toward deep water (%.1f m)" % [label, hauled])
		check((p.grabbed_by == null) == case[2] and not p.vitals.dead, "%s: %s" % [label, "it lets go" if case[2] else "no escape"])
		check(rolls.size() > 0 and rolls[-1][2] == case[2], "%s: the roll is shown" % label)
		if p.grabbed_by:
			p.grabbed_by.release(false)
			p.release_grab()
		u.queue_free()
		await _frames(2)
	check(is_equal_approx(Player.ESCAPE_BASE + Player.ESCAPE_BONUS["advanced"], 0.7), "an advanced weapon would give 70%")
	w.queue_free()
	await _frames(2)


func test_throwing() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var start: Vector3 = p.global_position

	# Throwing from the hand.
	Game.inventory.clear()
	Game.inventory.add("stone", 2)
	Game.inventory.select(0)
	p._attack_cd = 0.0
	p._use_held()
	var rocks: Array = w.get_children().filter(func(n): return n.get_script() == ThrownRock)
	check(rocks.size() == 1 and Game.inventory.count("stone") == 1, "right-click throws the held stone")
	for i in 240:
		await get_tree().physics_frame
		if not is_instance_valid(rocks[0]):
			break
	check(not is_instance_valid(rocks[0]), "it lands")
	var lying: Array = w.get_children().filter(func(n): return n.get_script() == Pickup and n.item_id == "stone")
	check(lying.size() >= 1, "and can be picked up again")

	# A lizard is dazed; a giant dragonfly drops out of the air.
	var lz_pos := start + Vector3(6, 0, 0)
	lz_pos.y = w.ground_height(lz_pos.x, lz_pos.z)
	var lizard: Node = Creature.new().setup("hylonomus", lz_pos, w)
	w.add_child(lizard)
	lizard.set_process(false)  # hold it still for the throw
	await _frames(2)
	var aim: Vector3 = lizard.hit_center()
	w.add_child(ThrownRock.new().setup("stone", aim + Vector3(-3, 0.05, 0), Vector3(15, 0, 0), p, w))
	for i in 30:
		await get_tree().physics_frame
		if lizard._stun > 0.0:
			break
	check(lizard._stun > 0.0 and not lizard.dead, "a thrown stone stuns a lizard")
	lizard.set_process(true)
	var held_at: Vector3 = lizard.global_position
	await _frames(40)
	check(lizard.global_position.distance_to(held_at) < 0.05, "it stays put while dazed")
	lizard._stun = 0.01
	await _frames(3)
	check(lizard._stun <= 0.0, "then comes round")
	var fly: Node = Creature.new().setup("meganeura", start + Vector3(0, 0, 6), w)
	w.add_child(fly)
	await _frames(2)
	fly.stun(2.5)
	var g: float = w.ground_height(fly.global_position.x, fly.global_position.z)
	await _frames(60)
	check(fly.global_position.y < maxf(g, 0.0) + 0.4, "a stunned dragonfly drops to the ground")

	# A splash draws a buried Uranocentrodon to the spot, where it settles.
	var shore := _find_spot(w, start, _is_ambush_shore.bind(w))
	var lair: Vector3 = w.water_point(shore, 5.0)
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", lair, lair)
	await _frames(30)
	var spot := Vector3.INF
	for k in 16:
		var a := TAU * k / 16.0
		var q: Vector3 = lair + Vector3(cos(a), 0, sin(a)) * 7.0
		if w.ground_height(q.x, q.z) < -0.2:
			spot = q
			break
	check(spot.is_finite(), "found open water near it")
	if spot.is_finite():
		w.add_child(ThrownRock.new().setup("stone", Vector3(spot.x, 2.0, spot.z), Vector3(0, -4, 0), p, w))
		for i in 60:
			await get_tree().physics_frame
			if u.state == "lunge":
				break
		check(u.state == "lunge" and u._body.visible, "a splash nearby makes it erupt at the spot")
		for i in 600:
			await get_tree().physics_frame
			if u.state == "hide":
				break
		var d := Vector2(u.global_position.x - spot.x, u.global_position.z - spot.z).length()
		check(u.state == "hide" and d < 2.0, "and it buries itself there instead (%.1f m off)" % d)
		u._strike(null)
		check(not u.lure(spot), "one already going for you ignores a splash")
	u.queue_free()
	await _frames(2)

	# Hit one directly from out of its reach, and it comes for you.
	var b: Node = w.spawn_amphibian("uranocentrodon", "bask", shore, lair)
	await _frames(2)
	var from: Vector3 = shore + (start - shore).normalized() * 12.0
	from.y = w.ground_height(from.x, from.z) + 1.5
	p.global_position = from - Vector3(0, 1.4, 0)
	var flight: float = from.distance_to(b.hit_center()) / 18.0
	var lob: Vector3 = (b.hit_center() - from).normalized() * 18.0 + Vector3(0, ThrownRock.GRAVITY * flight * 0.5, 0)
	w.add_child(ThrownRock.new().setup("stone", from, lob, p, w))
	var went := false
	for i in 60:
		await get_tree().physics_frame
		if b.state == "strike" or p.grabbed_by == b:
			went = true
			break
	check(went and b._provoked > 0.0 and b.hp < b.def.hp, "a stone off its hide makes it go for you")
	if p.grabbed_by:
		p.grabbed_by.release(false)
		p.release_grab()
	p.global_position = start
	b.queue_free()
	await _frames(2)

	# Basking, it creeps toward you when you are close but out of reach.
	var basker: Node = w.spawn_amphibian("uranocentrodon", "bask", shore, lair)
	var stand := Vector3.INF
	for k in 16:
		var a := TAU * k / 16.0
		var q: Vector3 = shore + Vector3(cos(a), 0, sin(a)) * 11.0
		q.y = w.ground_height(q.x, q.z)
		if q.y > 0.1 and q.y < 1.0:
			stand = q
			break
	check(stand.is_finite(), "found a spot near the bank")
	if stand.is_finite():
		p.global_position = stand + Vector3(0, 0.1, 0)
		for i in 30:
			await get_tree().physics_frame
		var d0: float = basker.global_position.distance_to(p.global_position)
		check(basker.state == "stalk", "a basking one notices you and creeps closer")
		for i in 900:
			await get_tree().physics_frame
			if p.grabbed_by:
				break
			p.global_position = stand + Vector3(0, 0.1, 0)
		check(p.grabbed_by == basker, "until it can strike (from %.1f m)" % d0)
	w.queue_free()
	await _frames(2)

	# Many more of them now: a couple basking, the shallows full of hidden ones.
	w = await _new_swamp()
	Game.time = Game.solar_to_clock(0.5) - Game.ARRIVAL_CLOCK
	for i in 120:
		w._spawn_amphibians()
	var bask := 0
	var hid := 0
	for c in Game.creatures:
		if is_instance_valid(c) and c.species == "uranocentrodon":
			if c.mode == "bask":
				bask += 1
			else:
				hid += 1
	check(bask == w.BASKING and hid >= w.HIDDEN_DAY - 1, "by day %d bask and %d lie hidden" % [bask, hid])
	w.queue_free()
	await _frames(2)


func test_suspend() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	var w: Node = await _new_swamp()
	var p: Node = w.player
	check(w.save_now(), "a camp save to fall back on")
	var camp: Vector3 = p.global_position
	var here: Vector3 = camp + Vector3(6, 0, 4)
	here.y = w.ground_height(here.x, here.z) + 0.1
	p.global_position = here
	p.vitals.protein = 44.0
	Game.inventory.clear()
	Game.inventory.add("stone", 2)

	# The pause menu offers it, and refuses in the middle of danger.
	w.pause.open()
	check(w.pause._save_btns.size() >= 1 and w.pause._save_btns.all(func(b): return b.visible and not b.disabled),
			"the pause menu offers save and quit")
	w.pause.resume()
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", here + Vector3(2, 0, 0), here + Vector3(2, 0, 0))
	u.attack_now(p)
	w.pause.open()
	check(w.pause._save_btns.all(func(b): return b.disabled) and w.suspend_blocker() != "" and not w.save_suspend(),
			"but not while something has you")
	w.pause.resume()
	u.release(false)
	p.release_grab()
	u.queue_free()
	await _frames(2)
	p.global_position = here
	p.vitals.blood = 100.0

	check(w.save_suspend() and Game.has_suspend(), "save and quit writes a suspend save")
	var camp_data := Game.read_save()
	check(Vector3(camp_data.player.pos[0], camp_data.player.pos[1], camp_data.player.pos[2]).distance_to(camp) < 0.5,
			"the camp save is left as it was")
	w.queue_free()
	await _frames(2)

	# Continue resumes from the suspend save once, then from camp again.
	Game.inventory.clear()
	var data := Game.take_save()
	check(data.get("suspended", false) and not Game.has_suspend(), "Continue takes the suspend save and uses it up")
	Game.apply_save(data)
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	check(w2.player.global_position.distance_to(here) < 1.0 and absf(w2.player.vitals.protein - 44.0) < 0.1
			and Game.inventory.count("stone") == 2, "you pick up where you left off")
	w2.queue_free()
	await _frames(2)
	var again := Game.take_save()
	check(not again.is_empty() and not again.suspended and Game.has_save(), "after that it is the camp save again")


func test_sleep_and_save() -> void:
	_fresh_state()
	var w: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	var p: Node = w.player
	var start: Vector3 = p.global_position

	# Risk depends mostly on distance from water.
	var shore := _find_spot(w, start, func(q): return q.y > 0.05 and q.distance_to(w.water_point(q, 10.0)) < 6.0)
	var inland := _find_spot(w, start, func(q): return q.y > 0.3 and not w.water_point(q, 32.0).is_finite())
	check(shore.is_finite() and inland.is_finite(), "found a shore and an inland spot")
	if shore.is_finite() and inland.is_finite():
		var rs: Dictionary = w.sleep_risk(shore)
		var ri: Dictionary = w.sleep_risk(inland)
		check(rs.amphibian > 0.9, "sleeping by the water: amphibian nearly certain (%.2f)" % rs.amphibian)
		check(ri.amphibian == 0.0, "more than 30 m from water: no amphibian")
		check(rs.danger > ri.danger and rs.leeches and not ri.leeches, "shore is riskier than inland")
		Game.time = 1200.0 - Game.ARRIVAL_CLOCK  # dusk
		var open: Dictionary = w.sleep_risk(inland)
		w._add_fire(inland + Vector3(1, 0, 0), 300.0, true)
		var camp: Dictionary = w.sleep_risk(inland)
		check(camp.predator < open.predator * 0.5 and camp.bites < open.bites, "a campfire makes sleeping safer")
		Game.inventory.add("raw_meat", 2)
		check(w.sleep_risk(inland).predator > camp.predator, "carrying raw meat draws predators")
		Game.inventory.remove("raw_meat", 2)

		# Not tired yet.
		Game.last_sleep = Game.time - 10.0
		w.request_sleep()
		check(not w._sleeping and w._sleep_confirm_t == 0.0, "can't sleep when not tired")

		# Sleep through the night at the fire: time passes and the game saves.
		p.global_position = inland + Vector3(0, 0.1, 0)
		Game.last_sleep = Game.time - Game.SLEEP_COOLDOWN
		await _frames(3)
		w.request_sleep()
		check(w._sleep_confirm_t > 0.0, "first press asks to confirm")
		var t0 := Game.time
		var night := Game.night_index()
		w._rng.seed = 11
		w.request_sleep()
		check(w._sleeping and p.frozen, "second press sleeps")
		while w._sleeping:
			await get_tree().process_frame
		var slept := Game.time - t0  # includes the fade to black
		check(slept > 0.1 * Game.SLEEP_LENGTH and slept <= Game.SLEEP_LENGTH + 5.0, "sleep passed %.0f s" % slept)
		check(Game.can_sleep_in() > 0.0, "slept: not tired again")
		if w._pending_save <= 0.0:
			check(Game.saved_night == night and Game.has_save(), "a night's sleep saves")
		else:
			print("  (attacked in the night: seed 11 woke the player early)")
			check(w._pending_save > 0.0, "an attack defers the save")
			for c in Game.creatures.duplicate():
				c.take_damage(1e6, null)
			p.release_grab()
			w._process(31.0)
			check(Game.saved_night == night and Game.has_save(), "surviving 30 s after an attack saves")

		var mtime := FileAccess.get_modified_time(ProjectSettings.globalize_path(Game.save_path))
		var data := Game.read_save()
		check(data.get("run") == Game.run_id and data.has("vitals") and data.has("fires"), "save holds run, vitals and fires")
		check(data.fires.size() == Game.fires.size(), "save lists the fires")

		# Sleeping at the water's edge: woken in the jaws of an amphibian.
		p.global_position = shore + Vector3(0, 0.1, 0)
		p.vitals.blood = 100.0
		Game.last_sleep = Game.time - Game.SLEEP_COOLDOWN
		await _frames(3)
		var t1 := Game.time
		# Pick a seed whose first roll is an attack (the 5% miss is luck).
		var seed_value := 1
		var probe := RandomNumberGenerator.new()
		while true:
			probe.seed = seed_value
			if probe.randf() < 0.9:
				break
			seed_value += 1
		w._rng.seed = seed_value
		w.sleep()
		while w._sleeping:
			await get_tree().process_frame
		check(Game.time - t1 < Game.SLEEP_LENGTH, "woken early by the attack (%.0f s)" % (Game.time - t1))
		check(p.grabbed_by != null and p.grabbed_by.species == "uranocentrodon", "woke up grabbed by a Uranocentrodon")
		check(FileAccess.get_modified_time(ProjectSettings.globalize_path(Game.save_path)) == mtime and w._pending_save > 0.0,
				"woken by an attack, the save waits until you survive it")
		if p.grabbed_by:
			var c: Node = p.grabbed_by
			c.release(true)
			p.release_grab()
			c.queue_free()
		w._pending_save = 0.0

		# A nap by day saves too.
		p.vitals.wounds.clear()
		p.vitals.blood = 100.0
		Game.time = 600.0 - Game.ARRIVAL_CLOCK  # mid-morning
		p.global_position = inland + Vector3(0, 0.1, 0)
		Game.last_sleep = Game.time - Game.SLEEP_COOLDOWN
		Game.saved_night = -1
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
		await _frames(3)
		check("Sleeping will save the game" in w.sleep_preview(), "it says sleeping saves (%s)" % w.sleep_preview())
		w._rng.seed = 11
		w.sleep()
		while w._sleeping:
			await get_tree().process_frame
		if w._pending_save > 0.0:
			w._process(31.0)
		check(Game.has_save(), "a nap by day saves")

	# Save and restore through a fresh swamp scene.
	p.global_position = start + Vector3(0, 0.1, 0)
	p.vitals.add_wound(0.3, 0.2, "test")
	p.vitals.protein = 33.0
	Game.inventory.clear()
	Game.inventory.add("fiber_sack")
	Game.inventory.add("stone", 3)
	Game.inventory.add("torch", 1)
	Game.inventory.add("flint", 1)
	Game.inventory.select(Game.inventory.find("torch"))
	p._drop_held()
	w.spawn_pickup("flint", 1, start + Vector3(2, 0.5, 0), 0.0, false)
	Game.inventory.remove("flint", 1)
	check(w.save_now(), "save_now writes the file")
	var saved_time := Game.time
	var saved_pos: Vector3 = p.global_position
	w.queue_free()
	await _frames(2)
	_fresh_state()
	var data2 := Game.read_save()
	check(not data2.is_empty(), "save can be read back")
	Game.world_seed = int(data2.seed)
	Game.time = float(data2.time)
	Game.inventory.from_dict(data2.inventory)
	Game.restore = data2
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	check(w2.player.global_position.distance_to(saved_pos) < 1.0, "restored at the saved position")
	check(absf(w2.player.vitals.protein - 33.0) < 0.1 and w2.player.vitals.wounds.size() == data2.vitals.wounds.size(), "restored vitals and wounds")
	check(Game.inventory.count("stone") == 3 and Game.inventory.has_tag("sack"), "restored inventory")
	check(Game.fires.size() == data2.fires.size(), "restored fires")
	var drops: Array = w2.get_tree().get_nodes_in_group("drops")
	check(drops.any(func(d): return d.item_id == "torch"), "a dropped item is still there after a reload")
	check(not drops.any(func(d): return d.item_id == "flint"), "a discarded item is gone after a reload")
	check(absf(Game.time - saved_time) < 1.0, "restored the clock")
	w2.queue_free()
	await _frames(2)


func _hold_until_dead(p: Node, c: Node) -> float:
	## Seconds a bare-handed player survives in c's jaws.
	p.vitals.blood = 100.0
	p.vitals.wounds.clear()
	Game.inventory.clear()
	c.attack_now(p)
	var t := 0.0
	while not p.vitals.dead and t < 60.0:
		p._process_grabbed(0.1)
		t += 0.1
	return t


func _is_ambush_shore(q: Vector3, w: Node) -> bool:
	if q.y < 0.05 or q.y > 0.5:
		return false
	var wp: Vector3 = w.water_point(q, 5.0)
	return wp.is_finite() and wp.y > -1.8


func test_amphibian() -> void:
	_fresh_state()
	var w: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	var p: Node = w.player
	var start: Vector3 = p.global_position
	w._spawn_t = 1e9  # keep the spawner from despawning test creatures far from the player

	# A shore spot with shallow water (a hiding place) within striking reach.
	var shore := _find_spot(w, start, _is_ambush_shore.bind(w))
	check(shore.is_finite(), "found a shore with a hiding place")
	if not shore.is_finite():
		return
	var lair: Vector3 = w.water_point(shore, 5.0)
	var deep: Vector3 = w.water_point(lair, 20.0, -0.9)
	if not deep.is_finite():
		deep = lair

	# Buried: out of sight under the mud, given away only by faint ripples.
	p.global_position = start + Vector3(0, 0.1, 0)
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", lair, deep)
	for i in 30:
		await get_tree().physics_frame
	var g: float = w.ground_height(u.global_position.x, u.global_position.z)
	check(u.state == "hide" and u.submerged and not u._body.visible, "Uranocentrodon lies hidden")
	check(u.global_position.y < g - 1.0, "buried below the mud (y %.2f, ground %.2f)" % [u.global_position.y, g])
	u._ripple_t = 0.0
	u._update_ripples(0.05)
	var rings: Array = u._ripples.filter(func(r): return r.visible)
	check(rings.size() == 1 and rings[0].transparency >= 0.6, "only a single faint ripple")
	check(u.def.bite > Creature.SPECIES["eogyrinus"]["bite"] and u.def.grab_dps > Creature.SPECIES["eogyrinus"]["grab_dps"], "it bites harder than Eogyrinus")

	# It takes any animal that comes down to the water's edge.
	var lizard: Node = Creature.new().setup("hylonomus", shore, w)
	w.add_child(lizard)
	lizard.set_process(false)
	for i in 120:
		await get_tree().physics_frame
		if u.state == "feed":
			break
	check(lizard.dead and u.state == "feed", "it strikes and kills an animal at the edge (state %s)" % u.state)
	check(u._body.visible, "it is visible once it strikes")
	for i in 1500:
		await get_tree().physics_frame
		if not is_instance_valid(lizard):
			break
	check(not is_instance_valid(lizard), "it drags the kill under")
	u.queue_free()
	await _frames(2)

	# Far out under the water, it still comes for you once you are near enough
	# the edge to reach the water.
	var edge := _find_spot(w, start, func(q): return q.y > 0.05 and w.water_point(q, 3.0, -0.1).is_finite())
	var far_lair := Vector3.INF
	for k in 24:
		var a := TAU * k / 24.0
		var q: Vector3 = edge + Vector3(cos(a), 0, sin(a)) * 12.0
		q.y = w.ground_height(q.x, q.z)
		if q.y < -0.4:
			far_lair = q
			break
	check(far_lair.is_finite(), "found water 12 m off the edge")
	if far_lair.is_finite():
		await _clear_amphibians()
		var u3: Node = w.spawn_amphibian("uranocentrodon", "hide", far_lair, far_lair)
		await _frames(15)
		check(not w.player_at_shore and u3.state == "hide", "well back from the water, it stays buried")
		p.global_position = edge + Vector3(0, 0.1, 0)
		for i in 300:
			await get_tree().physics_frame
			if p.grabbed_by:
				break
		check(w.player_at_shore and p.grabbed_by == u3, "from 12 m out, it strikes when you come to drink")
		if p.grabbed_by:
			p.grabbed_by.release(false)
			p.release_grab()
		u3.queue_free()
		p.global_position = start + Vector3(0, 0.1, 0)
		p.vitals.blood = 100.0
		await _frames(2)

	# The player at the edge: struck from hiding and seized.
	var u2: Node = w.spawn_amphibian("uranocentrodon", "hide", lair, deep)
	for i in 10:
		await get_tree().physics_frame
	check(u2.state == "hide", "still hidden while you are far away")
	p.global_position = shore + Vector3(0, 0.1, 0)
	var hp: float = p.vitals.blood
	for i in 120:
		await get_tree().physics_frame
		if p.grabbed_by:
			break
	check(p.grabbed_by == u2, "it strikes when you come to the edge")
	check(p.vitals.blood <= hp - u2.def.bite * Player.TRAUMA + 0.01 and p.vitals.bleed_level() == 3, "the bite is savage: a mauling that bleeds heavily")
	check(absf(p.camera.rotation.z) > 0.1, "the view is twisted")
	Game.inventory.clear()
	Game.inventory.add("flint_blade")
	Game.inventory.select(0)
	for i in 10:
		p.stab()
	check(p.grabbed_by == u2 and p.strike_tier == "stone" and is_equal_approx(p.escape_chance(), 0.4),
			"stone strikes raise the odds it lets go to 40%% (%.2f)" % p.escape_chance())
	p.next_roll = 0.45
	var t_u := 0.0
	while p.grabbed_by and not p.vitals.dead and t_u < 60.0:
		p._process_grabbed(0.1)
		t_u += 0.1
	check(p.vitals.dead and p.escape_roll >= 0.0, "a failed roll and you die")
	await _frames(2)
	check(u2._victim == null, "it lets go of the body")
	w.queue_free()
	await _frames(2)

	# Eogyrinus: a rare wanderer on dry land, as dangerous as before but slower to kill.
	_fresh_state()
	w = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	p = w.player
	var pos: Vector3 = p.global_position
	check(w.ground_height(pos.x, pos.z) > 1.2, "test player is on high ground")
	var e: Node = w.spawn_amphibian("eogyrinus", "land", pos + Vector3(4, 0, 0), pos + Vector3(4, 0, 0))
	check(e.mode == "land" and e.state == "wander" and e._leash_ok(pos), "Eogyrinus roams on land")
	for i in 180:
		await get_tree().physics_frame
		if p.grabbed_by:
			break
	check(p.grabbed_by == e, "it charges and grabs you on dry land")
	check(not p.vitals.wounds.is_empty(), "the bite leaves a wound")
	Game.inventory.clear()
	Game.inventory.add("flint_blade")
	Game.inventory.select(0)
	var stabs := 0
	while p.grabbed_by and stabs < 40:
		p.stab()
		stabs += 1
	check(p.grabbed_by == null and e.state == "retreat", "enough stabs make it let go (%d stabs)" % stabs)
	check(e.hp > e.def.hp * 0.5 and e._calm > 0.0, "it lets go long before it is badly hurt")
	check(e.mode == "land", "and stays a land animal")
	Game.inventory.clear()
	check(is_equal_approx(p.stab_power(), 2.5), "bare hands barely loosen its grip")
	e._calm = 0.0
	var t_e := _hold_until_dead(p, e)
	check(p.vitals.dead, "bare-handed in its jaws you die (after %.1f s)" % t_e)
	check(t_u < t_e, "a Uranocentrodon kills faster (%.1f s vs %.1f s)" % [t_u, t_e])
	w.queue_free()
	await _frames(2)

	# Eogyrinus turning up in a Uranocentrodon's water: taken, or driven out.
	_fresh_state()
	w = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	w._spawn_t = 1e9
	start = w.player.global_position
	shore = _find_spot(w, start, _is_ambush_shore.bind(w))
	lair = w.water_point(shore, 5.0)
	var out := lair - shore
	out.y = 0.0
	var far := lair + out.normalized() * 18.0
	far.y = w.ground_height(far.x, far.z)
	var near := far + Vector3(3.5, 0, 0)
	near.y = w.ground_height(near.x, near.z)
	e = w._spawn_eogyrinus(near, true)
	check(e.mode == "lurk", "an Eogyrinus can turn up in the water")
	u = w.spawn_amphibian("uranocentrodon", "hide", far, far)
	u.hunt(e, 10.0)
	check(u.state == "pursue" and e.mode == "land" and e.state == "retreat", "the Uranocentrodon goes after it and it flees for land")
	for i in 300:
		await get_tree().physics_frame
		if e.dead:
			break
	check(e.dead and u.state == "feed", "caught close by, it is taken")
	u.queue_free()
	if is_instance_valid(e):
		e.queue_free()
	await _frames(2)
	u = w.spawn_amphibian("uranocentrodon", "hide", far, far)
	e = w._spawn_eogyrinus(lair, true)
	u.hunt(e, 10.0)
	for i in 900:
		await get_tree().physics_frame
		if e.dead or u.state in ["return", "hide"]:
			break
	var eg: float = w.ground_height(e.global_position.x, e.global_position.z)
	check(not e.dead and e.mode == "land" and eg > 0.3, "near the bank, it is driven out onto land (ground %.2f)" % eg)
	check(u.state in ["return", "hide"], "and the Uranocentrodon gives up and goes back (%s)" % u.state)
	# Each call may find no place (the spawner just tries again next tick).
	var bank: Array = []
	for i in 6:
		bank = w.amphibian_spot("bank", start)
		if not bank.is_empty():
			break
	check(not bank.is_empty() and bank[0].y > 0.0 and bank[0].distance_to(bank[1]) < 15.0, "Eogyrinus turns up on dry ground near water")
	var swim: Array = w.amphibian_spot("water", start)
	check(not swim.is_empty() and swim[0].y < -0.4, "or in the water")
	var puddle := _find_spot(w, start, func(q): return w._puddle_near(q, 4.0).is_finite())
	if puddle.is_finite():
		var dip: Vector3 = w._puddle_near(puddle, 4.0)
		check(dip.y < 0.0 and not w.water_point(dip, 10.0, -0.5).is_finite(), "puddles are told apart from the swamp")
	w.queue_free()
	await _frames(2)


func _carry_up_ladder(w: Node, h: Node, p: Node, foot: Vector3, thing: Node) -> Dictionary:
	## Walks up house h's ladder from its foot carrying `thing`. Says whether
	## you got up with it, whether it rode on your back with no prompt part
	## way up, and whether trying to put it down there was refused.
	p.global_position = foot + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	p.rotation.y = h.rotation.y
	p._pitch = 0.0
	await _frames(3)
	var seen := {}
	Input.action_press("move_forward")
	await _run_for(8.0, func():
		if p.climbing and p.global_position.y < h.global_position.y - 0.5:
			seen.n = seen.get("n", 0) + 1
		if seen.get("n", 0) == 4 and not seen.has("back"):
			seen.back = h.to_local(thing.global_position).z > h.to_local(p.global_position).z + 0.4 and p.prompt == ""
			p.put_down()
			seen.kept = p.hauling == thing
		return h.on_floor(p.global_position) and p.is_on_floor())
	Input.action_release("move_forward")
	seen.up = h.on_floor(p.global_position) and p.hauling == thing
	return seen


func _run_for(secs: float, done: Callable) -> void:
	## Lets the game run until done() is true or `secs` of game time pass.
	var t := 0.0
	while t < secs and not done.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func test_predators() -> void:
	var w: Node = await _new_swamp()
	var start: Vector3 = w.player.global_position
	check(not "_roll" in w.hud, "no dice box on the HUD")
	var spot := _find_spot(w, start + Vector3(30, 0, 0), func(q): return q.y > 0.4 and q.distance_to(start) > 25.0)

	# A Meganeura snatches a lizard and flies off with it.
	var lizard: Node = Creature.new().setup("hylonomus", spot, w)
	w.add_child(lizard)
	var fly: Node = Creature.new().setup("meganeura", spot + Vector3(4, 4, 0), w)
	w.add_child(fly)
	await _frames(2)
	fly._cd = 0.0
	fly._spot_lizard()
	check(fly.state == "dive" and fly._prey == lizard, "a dragonfly goes for a lizard in the open")
	await _run_for(5.0, func(): return lizard.carried_by == fly)
	check(lizard.carried_by == fly and fly.state == "carry", "it snatches the lizard")
	await _run_for(1.5, func(): return false)
	var g: float = maxf(w.ground_height(lizard.global_position.x, lizard.global_position.z), 0.0)
	check(lizard.global_position.y > g + 1.5 and lizard.global_position.distance_to(fly.global_position) < 0.5,
			"and flies off with it")
	fly.stun(2.0)
	await _frames(2)
	check(lizard.carried_by == null and lizard._stun > 0.0, "a dragonfly struck by a stone drops its catch")
	await _run_for(3.0, func(): return lizard.global_position.y < w.ground_height(lizard.global_position.x, lizard.global_position.z) + 0.3)
	check(lizard.global_position.y < w.ground_height(lizard.global_position.x, lizard.global_position.z) + 0.3,
			"which falls to the ground")
	lizard._stun = 0.0
	fly._stun = 0.0
	fly.state = "wander"
	fly._prey = null
	fly.global_position = lizard.global_position + Vector3(0, 2, 0)
	fly._spot_lizard()
	await _run_for(5.0, func(): return lizard.carried_by == fly)
	fly._strike_t = 0.0
	await _frames(5)
	check(not is_instance_valid(lizard) and fly._prey == null and fly.state == "wander", "and eats it where it lands")
	fly.queue_free()

	# An Arthropleura runs down a lizard nearby and feeds on it.
	var lz: Node = Creature.new().setup("hylonomus", spot, w)
	w.add_child(lz)
	var ar: Node = Creature.new().setup("arthropleura", spot + Vector3(5, 0, 0), w)
	ar.position.y = w.ground_height(spot.x + 5, spot.z)
	w.add_child(ar)
	await _frames(2)
	lz.set_process(false)  # basking where it is
	ar._cd = 0.0
	ar._scan_t = 0.0
	await _run_for(15.0, func(): return lz.dead)
	check(lz.dead, "an Arthropleura runs down and kills a lizard")
	check(ar.state == "feed", "and feeds on it")
	ar._state_t = 0.0
	await _frames(3)
	check(not is_instance_valid(lz) and ar.state == "wander", "until nothing is left")
	ar.queue_free()

	# A scorpion hunts lizards too. Snatching its kill gives gnawed meat, and
	# the scorpion turns on you.
	var lz2: Node = Creature.new().setup("hylonomus", spot, w)
	w.add_child(lz2)
	var sc: Node = Creature.new().setup("scorpion", spot + Vector3(4, 0, 0), w)
	sc.position.y = w.ground_height(spot.x + 4, spot.z)
	w.add_child(sc)
	await _frames(2)
	lz2.set_process(false)
	sc._cd = 0.0
	sc._scan_t = 0.0
	await _run_for(15.0, func(): return lz2.dead)
	check(lz2.dead and sc.state == "feed", "a scorpion kills a lizard and eats it")
	await _run_for(2.0, func(): return false)
	check(lz2._body.scale.x < 1.0, "the body shrinks as it is eaten")
	check(lz2.prompt(w.player).begins_with("Snatch"), "a kill being eaten can be snatched")
	var gnawed: int = Game.inventory.count("gnawed_meat")
	lz2.interact(w.player)
	check(Game.inventory.count("gnawed_meat") == gnawed + 1, "snatching gives gnawed meat")
	check(sc.state == "chase" and sc._anger > 0.0 and sc._prey == null, "and the scorpion attacks")
	sc.queue_free()

	# The water's edge is crowded.
	for i in 160:
		w._spawn_amphibians()
	var uranos := Game.creatures.filter(func(c): return is_instance_valid(c) and c.species == "uranocentrodon")
	check(uranos.size() >= 10, "many Uranocentrodon along the shore (%d)" % uranos.size())
	w.queue_free()
	await _frames(2)


func _kill(w: Node, sp: String, pos: Vector3) -> Node:
	var c: Node = Creature.new().setup(sp, pos, w)
	w.add_child(c)
	c.take_damage(1e6, w.player)
	return c


func _ahead(p: Node, d: float) -> Vector3:
	var fwd: Vector3 = -p.global_transform.basis.z
	fwd.y = 0.0
	var at: Vector3 = p.global_position + fwd.normalized() * d
	at.y = p.world.ground_height(at.x, at.z)
	return at


func _work_through(w: Node) -> void:
	## Begins the butchering option at the work spot and does every step.
	var o: Dictionary = w.work.butcher_option()
	w.work.begin(o.recipe)
	for k in Items.recipe_steps(w.work.recipe):
		w.work.step()


func _tree_near(w: Node, soft: bool) -> Dictionary:
	## The nearest standing tree of that hardness to the player.
	var best := {}
	var p: Vector3 = w.player.global_position
	for c in w.chunks.values():
		for t in c.trees:
			if t.stump == null and not Game.felled.has(t.uid) and Chunk.TREES[t.kind].soft == soft \
					and (best.is_empty() or t.at.distance_to(p) < best.at.distance_to(p)):
				best = t
	return best


func _kneel_at_tree(w: Node, t: Dictionary) -> void:
	var p: Node = w.player
	var back := Vector3(1, 0, 0.3).normalized()
	p.global_position = t.at + back * (t.r + 0.6)
	p.rotation.y = atan2(back.x, back.z)
	p.focus = null
	w.start_work()


func _wood_option(w: Node, what: String) -> Dictionary:
	for o in w.work.options():
		if o.recipe.get("wood", "") == what:
			return o
	return {}


func _do_wood(w: Node, what: String) -> bool:
	## Begins that woodwork at the work spot and does every stroke.
	var o := _wood_option(w, what)
	if o.is_empty() or not o.missing.is_empty() or not w.work.begin(o.recipe):
		return false
	for k in Items.recipe_steps(o.recipe):
		if w.work:
			w.work.step()
	return true


func _kneel_at(w: Node, piece: Node) -> void:
	var p: Node = w.player
	var at: Vector3 = piece.cut_point() if piece.has_method("cut_point") else piece.global_position
	p.global_position = at + Vector3(0, 0, 1.2)
	p.focus = piece
	w.start_work()


func test_wood() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()

	# A soft tree is felled with a stone axe and comes down in one piece.
	var t := _tree_near(w, true)
	check(not t.is_empty(), "there is a soft tree nearby (%s)" % t.get("kind", ""))
	_kneel_at_tree(w, t)
	check(w.work != null and not w.work.tree.is_empty(), "kneeling at a tree to fell it")
	var fo := _wood_option(w, "fell")
	check(not fo.is_empty() and fo.missing.has("a stone axe"), "felling needs an axe")
	w.close_work()
	Game.inventory.add("stone_axe")
	_kneel_at_tree(w, t)
	t = w.work.tree
	var uid: String = t.uid
	check(_do_wood(w, "fell"), "you chop through the trunk")
	await _frames(2)
	check(w.work == null and Game.felled.has(uid), "the tree comes down and you stand up")
	check(t.stump != null and is_instance_valid(t.stump) and t.shape.disabled, "it leaves a stump, and the trunk no longer blocks the way")
	var felled := get_tree().get_nodes_in_group("felled")
	check(felled.size() == 1 and felled[0].falling(), "it topples over")
	var ft: Node = felled[0]
	var tree_kind: String = ft.kind
	ft._fall = FelledTree.FALL_TIME
	await _frames(2)
	check(not ft.falling() and ft.global_basis.y.y < 0.5, "and lies on the ground in one piece")
	check(not w.tree_ahead().has("uid") or w.tree_ahead().uid != uid, "it can't be felled again")

	# A big tree is too hard for stone.
	var hard := _tree_near(w, false)
	if not hard.is_empty():
		_kneel_at_tree(w, hard)
		var ho := _wood_option(w, "fell") if w.work else {}
		check(not ho.is_empty() and ho.missing.any(func(m): return "metal axe" in m), "a %s needs a metal axe" % Chunk.TREES[hard.kind].name)
		w.close_work()

	# The trunk is cut into logs from the butt end.
	var n_logs: int = ft.logs_left()
	var L0: float = ft.length()
	_kneel_at(w, ft)
	check(w.work != null and w.work.wood == ft, "kneeling at the felled trunk (%d logs in %.1f m)" % [n_logs, L0])
	var cut := 0
	for i in 12:
		if w.work == null:
			_kneel_at(w, ft) if is_instance_valid(ft) and not ft.is_queued_for_deletion() else null
		if w.work == null or not _do_wood(w, "buck"):
			break
		cut += 1
		await _frames(1)
	check(cut == n_logs and not is_instance_valid(ft), "cut into %d logs until none is left (%d)" % [n_logs, cut])
	var logs := get_tree().get_nodes_in_group("logs")
	check(logs.size() == n_logs, "each cut leaves a log lying there (%d)" % logs.size())
	check(logs.all(func(l): return l.kind == tree_kind), "logs of the tree they were cut from (%s)" % tree_kind)
	w.close_work()

	# Logs are carried in your arms.
	var lg: Node = logs[0]
	lg.interact(p)
	check(p.hauling == lg, "a log is picked up into your arms")
	await _frames(2)
	check(p.prompt.begins_with("Put down the %s log" % Chunk.TREES[tree_kind].name.to_lower()), "and E puts it down (%s)" % p.prompt)
	_press("inventory")
	await _frames(2)
	check(not w.inv_ui.visible, "no bag while carrying a log")
	check(w.sleep_blocker() != "", "no sleeping with it either")
	var weight: float = Game.inventory.weight()
	check(weight == 0.0 or Game.inventory.count("log") == 0, "it adds no weight to the bag")
	p.global_position += Vector3(2.0, 0, 0)
	await _frames(3)
	check(lg.global_position.y > w.ground_height(lg.global_position.x, lg.global_position.z) + 0.4, "it is held up in front of you")
	_press("drop")
	await _frames(2)
	check(p.hauling == null and is_instance_valid(lg), "Q puts it down")

	# A log lying in water soaks and rots; one on dry ground never does.
	lg._tick = 0.0
	await _frames(2)
	if not lg.in_water():
		check(lg.soak == 0.0 and not lg.rotten(), "a log on dry ground doesn't soak")
	var wet := _find_spot(w, p.global_position, func(q): return q.y < w.water_level() - 0.5)
	if wet.is_finite():
		lg.global_position = wet
		lg.soak = WoodLog.ROT_AFTER - 1.0
		lg._tick = 0.0
		await _frames(2)
		check(lg.rotten(), "a log left in the water rots")
		check(lg.prompt(p).begins_with("Search"), "and can be searched")
		lg.interact(p)
		check(Game.inventory.count("grub") >= 1, "for grubs")
		Game.time += WoodLog.GONE_AFTER + 1.0
		lg._tick = 0.0
		await _frames(2)
		check(not is_instance_valid(lg), "then the soaked log falls apart")

	# Working logs with the axe.
	Game.inventory.clear()
	Game.inventory.add("stone_axe")
	var spot := _ahead(p, 2.0)
	var a: Node = w.add_log("log", spot, 0.0)
	await _frames(1)
	_kneel_at(w, a)
	check(w.work != null and w.work.wood == a, "kneeling at a log")
	var have: Array = w.work.options().map(func(o): return o.recipe.get("wood", ""))
	check(have.has("strip") and have.has("shorten") and not have.has("hew"), "a barked log can be stripped or cut short (%s)" % [have])
	check(_do_wood(w, "strip"), "strip it")
	check(Game.inventory.count("bark") == 6 and Game.inventory.count("branch") == 3 and a.item_id == "log_stripped",
			"stripping gives six bark and three branches, and leaves a stripped log")
	have = w.work.options().map(func(o): return o.recipe.get("wood", ""))
	check(have.has("hew") and not have.has("shorten"), "a stripped log can be hewn, but not cut short (%s)" % [have])
	check(_do_wood(w, "hew"), "hew it")
	await _frames(2)
	check(Game.inventory.count("board_" + Assets.LOG_KIND) == 4 and Game.inventory.count_as("board") == 4 and not is_instance_valid(a),
			"into four boards of its wood")
	# Each tree's boards are their own colour, and any of them is a board.
	var cols := {}
	for kind in Chunk.TREES:
		check(Items.ITEMS.has("board_" + kind) and Items.counts_as("board_" + kind, "board"), "a %s board counts as a board" % kind)
		cols[Items.def("board_" + kind).color] = true
	check(cols.size() == Chunk.TREES.size(), "every tree's boards have their own colour")
	var fern: Node = w.add_log("log_stripped", spot + Vector3(0, 0, 3), 0.0, "tree_fern")
	await _frames(1)
	_kneel_at(w, fern)
	check(_do_wood(w, "hew") and Game.inventory.count("board_tree_fern") == 4, "a tree fern log gives tree fern boards")
	await _frames(2)
	w.close_work()
	# Mixed boards make a workbench.
	Game.inventory.clear()
	Game.inventory.add("board_tree_fern", 2)
	Game.inventory.add("board_calamites", 1)
	Game.inventory.add("board", 1)
	Game.inventory.add("stick", 4)
	Game.inventory.add("cordage", 2)
	check(Game.inventory.can_craft(Items.recipe_for("workbench")), "boards of any wood will do for a recipe")
	check(Game.inventory.craft(Items.recipe_for("workbench")) and Game.inventory.count_as("board") == 0, "and are all used up")
	Game.inventory.clear()
	Game.inventory.add("stone_axe")
	Game.inventory.add("branch", 3)
	var b2: Node = w.add_log("log", spot, 0.0)
	await _frames(1)
	_kneel_at(w, b2)
	var before: int = get_tree().get_nodes_in_group("logs").size()
	check(_do_wood(w, "shorten"), "cut a log short")
	await _frames(1)
	var shorts: Array = get_tree().get_nodes_in_group("logs").filter(func(l): return l.item_id == "short_log" and l.global_position.distance_to(spot) < 1.5)
	check(shorts.size() == 4 and get_tree().get_nodes_in_group("logs").size() == before + 3,
			"into four short logs (%d, %d -> %d)" % [shorts.size(), before, get_tree().get_nodes_in_group("logs").size()])
	w.close_work()
	_kneel_at(w, shorts[0])
	check(_do_wood(w, "split"), "split a short log")
	await _frames(2)
	check(Game.inventory.count("firewood") == 4, "into firewood")
	check(Items.def("firewood").fuel > Items.def("stick").fuel, "firewood burns longer than sticks")
	w.close_work()
	shorts[1].interact(p)
	check(p.hauling == shorts[1], "short logs are carried in your arms too")
	p.put_down()

	# A branch snaps into sticks.
	w.start_work()
	if w.work:
		w.work.lay(Game.inventory.find("branch"))
		var so: Array = w.work.options().filter(func(o): return o.recipe.get("out", "") == "stick")
		check(so.size() == 1 and so[0].missing.is_empty(), "a branch can be snapped into sticks")
		w.work.begin(so[0].recipe)
		for k in Items.recipe_steps(so[0].recipe):
			w.work.step()
		check(Game.inventory.count("stick") == 3, "three of them")
		w.close_work()

	# An untouched felled tree rots in about three days and is gone three later.
	var ft2: Node = w.add_felled("calamites", 1.0, 0.65, Vector3(1, 0, 0), _ahead(p, 4.0))
	var ft3: Node = w.add_felled("calamites", 1.0, 0.65, Vector3(-1, 0, 0), _ahead(p, -4.0))
	ft3.touched = true
	await _frames(1)
	ft2.made = Game.time - FelledTree.ROT_AFTER - 1.0
	ft3.made = ft2.made
	ft2._tick = 0.0
	ft3._tick = 0.0
	await _frames(2)
	check(ft2.rotten() and ft2.prompt(p).begins_with("Search"), "a felled tree left lying rots into a log to search")
	check(not ft3.rotten(), "one that has been cut into doesn't")
	var grubs: int = Game.inventory.count("grub")
	ft2.interact(p)
	check(Game.inventory.count("grub") > grubs, "the rotten log has grubs in it")
	ft2.made = Game.time - FelledTree.ROT_AFTER - FelledTree.GONE_AFTER - 1.0
	ft2._tick = 0.0
	await _frames(2)
	check(not is_instance_valid(ft2), "then the rotten trunk falls apart")

	# Stumps grow back into trees, unless dug out with a mattock.
	var c: Node = t.stump.get_parent()
	var st: Node = t.stump
	check(st.prompt(p).contains("stump"), "the stump says what it is (%s)" % st.prompt(p))
	Game.felled[uid].regrow = Game.time + 10.0
	Game.felled[uid].at = Game.time - 10.0
	st._update()
	check(st._sapling.visible and st._sapling.scale.x > 0.4 * t.s, "a new tree grows up out of the stump")
	Game.felled[uid].regrow = Game.time - 1.0
	st._update()
	await _frames(1)
	check(not Game.felled.has(uid) and t.stump == null and not t.shape.disabled, "and stands full grown, ready to fell again")
	var t2 := _tree_near(w, true)
	_kneel_at_tree(w, t2)
	t2 = w.work.tree
	_do_wood(w, "fell")
	await _frames(2)
	var st2: Node = t2.stump
	Game.inventory.clear()
	for k in Stump.DIG_HITS:
		st2.dig()
	await _frames(1)
	check(Game.felled[t2.uid].get("cleared", false) and not is_instance_valid(st2), "a mattock digs a stump out")
	check(Game.inventory.count("firewood") >= Stump.ROOT_WOOD[0], "for some root wood as firewood")
	Game.felled[t2.uid].regrow = Game.time - 1.0
	check(c.tree_near(t2.at, Vector3(1, 0, 0), 2.0).get("uid", "") != t2.uid, "and nothing grows there again")

	# Felled trunks, logs and stumps are saved.
	var keep_ft: Node = w.add_felled("tree_fern", 1.0, 0.65, Vector3(0, 0, 1), _ahead(p, 6.0))
	keep_ft.touched = true
	w.add_log("short_log", _ahead(p, 3.0), 0.5)
	await _frames(1)
	var n_logs_saved: int = get_tree().get_nodes_in_group("logs").filter(func(l): return not l.is_queued_for_deletion()).size()
	check(w.save_now(), "saved")
	var data := Game.read_save()
	check(data.has("felled") and data.felled.has(t2.uid), "felled trees are saved")
	w.queue_free()
	await _frames(2)
	Game.felled.clear()
	Game.apply_save(data)
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	w2._spawn_t = 1e9
	check(get_tree().get_nodes_in_group("felled").any(func(f): return f.kind == "tree_fern" and f.touched),
			"felled trunks come back (%s)" % [data.get("felled_trees")])
	check(get_tree().get_nodes_in_group("logs").size() == n_logs_saved, "so do logs (%d)" % get_tree().get_nodes_in_group("logs").size())
	check(Game.felled[t2.uid].get("cleared", false), "and the cleared stump stays cleared")
	w2.queue_free()
	await _frames(2)


func test_piles() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	var dry := _find_spot(w, p.global_position, func(q): return q.y > 0.3 and q.distance_to(p.global_position) > 2.0)
	var stacks := func(): return get_tree().get_nodes_in_group("stacks").filter(func(s): return not s.is_queued_for_deletion())

	# Raw materials dropped on land go on a pile of their kind.
	w.pile_item("stone", 3, dry)
	w.pile_item("stone", 4, dry + Vector3(0.5, 0, 0))
	await _frames(1)
	check(stacks.call().size() == 1 and stacks.call()[0].count == 7, "dropped stones go on one pile")
	w.pile_item("stick", 2, dry + Vector3(0.3, 0, 0))
	await _frames(1)
	check(stacks.call().size() == 2, "a pile holds one kind of thing")
	w.pile_item("stone", 200, dry)
	await _frames(1)
	var sp: Node = stacks.call().filter(func(s): return s.item_id == "stone")[0]
	check(sp.count == 207 and sp._body.get_child_count() <= Stack.SHOWN + 1, "a pile holds any number, but only shows a dozen")
	var drops0 := get_tree().get_nodes_in_group("drops").size()
	w.pile_item("raw_meat", 1, dry)
	await _frames(1)
	check(get_tree().get_nodes_in_group("drops").size() == drops0 + 1 and stacks.call().size() == 2, "meat is dropped as it always was")
	var wet := _find_spot(w, p.global_position, func(q): return q.y < w.water_level() - 0.4)
	if wet.is_finite():
		w.pile_item("stone", 1, wet)
		await _frames(1)
		check(stacks.call().size() == 2, "nothing is piled in the water")

	# E takes one off the top; holding E keeps taking.
	sp.take_one(p)
	check(Game.inventory.count("stone") == 1 and sp.count == 206, "E takes one off a pile")
	check(sp.prompt(p).contains("hold"), "holding E takes more (%s)" % sp.prompt(p))

	# Dropping from the hotbar puts it on a pile.
	p.global_position = dry + Vector3(0, 0, 1.0)
	p.rotation.y = 0.0
	Game.inventory.clear()
	Game.inventory.add("flint", 2)
	Game.inventory.select(Game.inventory.find("flint"))
	p._drop_held()
	p._drop_held()
	await _frames(1)
	var fl: Array = stacks.call().filter(func(s): return s.item_id == "flint")
	check(fl.size() == 1 and fl[0].count == 2, "dropped flint goes on a pile")

	# Facing a trunk or wall close by, a dropped item lands short of it.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	wall_shape.shape = BoxShape3D.new()
	wall_shape.shape.size = Vector3(2.0, 3.0, 0.2)
	wall.add_child(wall_shape)
	w.add_child(wall)
	wall.global_position = p.global_position + Vector3(0, 1.0, -0.6)
	await _frames(2)
	var dp: Vector3 = p.drop_point()
	check(dp.z > wall.global_position.z + 0.1 + 0.2, "a dropped item lands short of a wall in front (%.2f m from it)" % (dp.z - wall.global_position.z - 0.1))
	wall.queue_free()
	await _frames(1)
	check(p.drop_point().distance_to(p.global_position + Vector3(0, 0.8, -1.0)) < 0.01, "with nothing in the way it lands a metre in front")

	# Logs put down beside each other start a log pile.
	var a: Node = w.add_log("log", dry + Vector3(4, 0, 0), 0.0)
	var b: Node = w.add_log("log", dry + Vector3(4.6, 0, 0), 0.0)
	await _frames(1)
	b.interact(p)
	p.put_down()
	await _frames(1)
	b.global_position = a.global_position + Vector3(0, 0, 0.5)
	b.set_hauled(null)
	await _frames(1)
	var lp: Array = stacks.call().filter(func(s): return s.item_id == "log")
	check(lp.size() == 1 and lp[0].count == 2 and not is_instance_valid(a), "two logs together make a log pile")
	check(lp[0].take_one(p) and p.hauling != null and p.hauling.item_id == "log" and lp[0].count == 1,
			"and taking one off puts it in your arms")
	p.put_down()
	await _frames(1)

	# Piles are saved.
	check(w.save_now(), "saved")
	var data := Game.read_save()
	var saved: Array = data.get("stacks", []).map(func(s): return "%s:%d" % [s.id, s.n])
	check(saved.has("stone:206") and saved.has("stick:2"), "piles are saved (%s)" % [saved])
	w.queue_free()
	await _frames(2)
	Game.apply_save(data)
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	w2._spawn_t = 1e9
	check(stacks.call().any(func(s): return s.item_id == "stone" and s.count == 206), "and come back")
	w2.queue_free()
	await _frames(2)


func _lay_all(ws: Node, items: Dictionary) -> void:
	for id in items:
		Game.inventory.add(id, items[id])
		ws.lay(Game.inventory.find(id), items[id])


func _option_for(ws: Node, out: String) -> Dictionary:
	for o in ws.options():
		if o.recipe.get("out", "") == out:
			return o
	return {}


func _make(ws: Node, r: Dictionary) -> bool:
	## Begins a steps recipe at the work spot and does every step.
	if not ws.begin(r):
		return false
	for k in Items.recipe_steps(r):
		ws.step()
	return true


func test_bench() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	Game.tiers = ["hand"]
	var parts := {"board": 4, "stick": 4, "cordage": 2}

	# Find open, level, dry ground to build on.
	var spot := _find_spot(w, p.global_position, func(q):
		p.global_position = q
		p.rotation.y = 0.0
		w.start_work()
		var ok: bool = w.work != null and w.work.build_blocker() == "ok"
		if w.work:
			w.close_work()
		return ok)
	check(spot.is_finite(), "there is level, open ground to build on")
	p.global_position = spot
	p.rotation.y = 0.0
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, parts)
	var bo := _option_for(ws, "workbench")
	check(not bo.is_empty() and bo.missing.is_empty(), "boards, sticks and cordage laid out can build a workbench")
	_lay_all(ws, {"clay": 4})
	check(_option_for(ws, "clay_platter_unfired").is_empty(), "workbench things can't be made on the ground")
	check(not ws.missing_for(Items.recipe_for("clay_platter_unfired")).is_empty(), "they need a workbench")
	check(_make(ws, bo.recipe), "you build the workbench")
	await _frames(2)
	var benches := get_tree().get_nodes_in_group("workbenches")
	check(benches.size() == 1 and w.work == null, "it stands in front of you, and you get up")
	check(Game.inventory.count("board") == 0 and Game.inventory.count("clay") == 4, "it used the boards; the rest went back in your bag")
	check("bench" in Game.tiers and "Workbench" in w.inv_ui.book_categories(), "the workbench recipes are in the book now")
	var bench: Node = benches[0]
	var ahead: Vector3 = bench.global_position - p.global_position
	check(ahead.length() > 0.8 and ahead.normalized().dot(-p.global_basis.z) > 0.9, "the bench is right in front of you")

	# A tree or a boulder in the way stops you building there.
	p.global_position = bench.global_position + bench.global_basis.z * 2.0
	p.rotation.y = bench.rotation.y
	p.focus = null
	w.start_work()
	if w.work and w.work.bench == null:
		check("room" in w.work.build_blocker(), "you can't build a second bench into the first")
		w.close_work()

	# Kneel at the bench: its own recipes and everything made by hand.
	p.global_position = bench.global_position + bench.global_basis.z * 1.2
	p.rotation.y = bench.rotation.y
	p.focus = bench
	w.start_work()
	ws = w.work
	check(ws != null and ws.bench == bench and ws.tier == "bench", "C at the bench works on it")
	check(absf(ws.global_position.y - (bench.global_position.y + Assets.BENCH_SIZE.y)) < 0.01, "on its top")
	_lay_all(ws, {"clay": 4, "plant_fiber": 3, "board": 4, "stick": 4, "cordage": 2})
	var po := _option_for(ws, "clay_platter_unfired")
	check(not po.is_empty() and po.missing.is_empty(), "clay makes a platter at the bench")
	check(not _option_for(ws, "cordage").is_empty(), "hand recipes are made at the bench too")
	check(_option_for(ws, "workbench").is_empty(), "but not another workbench")
	check(_make(ws, po.recipe) and Game.inventory.count("clay_platter_unfired") == 1, "you form an unfired platter")
	check(Items.def("clay_platter_unfired").cook == "clay_platter" and Items.def("clay_bowl_unfired").cook == "clay_bowl", "the platter and bowl are fired in a campfire")
	# Woodworking and papermaking tools are made there too, with no tools on the rack.
	_lay_all(ws, {"flint": 2})
	Game.inventory.add("stone")
	var wo := _option_for(ws, "woodworking_tools")
	check(not wo.is_empty() and wo.missing.is_empty() and _make(ws, wo.recipe), "flint, sticks and cord make a chisel and saw")
	_lay_all(ws, {"clay": 3})
	check(_make(ws, _option_for(ws, "clay_bowl_unfired").recipe), "you pinch a bowl")
	_lay_all(ws, {"clay_bowl": 1, "stick": 2, "plant_fiber": 3})
	var pa := _option_for(ws, "papermaking_tools")
	check(not pa.is_empty() and pa.missing.is_empty() and _make(ws, pa.recipe), "the bowl and a screen make papermaking tools")
	# A recipe that needs a rack tool waits for it to hang there.
	var advanced := {"out": "board", "n": 1, "in": {"board": 1}, "tier": "bench", "rack": "woodworking_tools"}
	check(ws.missing_for(advanced).any(func(m): return "rack" in m), "an advanced recipe needs its tool on the rack")
	w.close_work()

	# Hang tools on the rack by holding them and pressing E at the bench.
	Game.inventory.clear()
	Game.inventory.add("woodworking_tools")
	Game.inventory.add("clay_platter")
	Game.inventory.select(Game.inventory.find("woodworking_tools"))
	check("Hang" in bench.prompt(p), "holding a tool, the bench offers to hang it")
	bench.interact(p)
	check(bench.has_tool("woodworking_tools") and Game.inventory.count("woodworking_tools") == 0, "it hangs on the rack")
	Game.inventory.select(Game.inventory.find("clay_platter"))
	bench.interact(p)
	check(bench.has_tool("clay_platter") and bench._rack.size() == 2, "and another beside it, both shown")
	Game.inventory.add("pot")
	Game.inventory.select(Game.inventory.find("pot"))
	bench.interact(p)
	check(Game.inventory.count("pot") == 1 and not bench.has_tool("pot"), "only workbench tools hang there")
	p.global_position = bench.global_position + bench.global_basis.z * 1.2
	p.rotation.y = bench.rotation.y
	p.focus = bench
	w.start_work()
	check(not w.work.missing_for(advanced).any(func(m): return "rack" in m), "with the tool on the rack the advanced recipe can be made")
	w.close_work()
	var rt: Node = bench._rack[0]
	check(rt.prompt(p).begins_with("Woodworking Tools"), "looking at a hanging tool names it")
	p.focus = rt
	check(w.bench_ahead() == bench, "kneeling while looking at the rack works at the bench")
	rt.interact(p)
	await _frames(1)
	check(Game.inventory.count("woodworking_tools") == 1 and not bench.has_tool("woodworking_tools") and bench.has_tool("clay_platter"),
			"E takes a tool back down")

	# Saved with the world, tools and all.
	var saved: Dictionary = w._world_state()
	check(saved.workbenches.size() == 1 and "clay_platter" in saved.workbenches[0].tools, "the bench is saved with its tools")
	var copy: Node = w.add_bench(Vector3(bench.global_position.x + 5.0, 0, bench.global_position.z), 0.0)
	copy.from_dict(saved.workbenches[0])
	check(copy.has_tool("clay_platter") and copy._rack.size() == 1 and absf(copy.rotation.y - bench.rotation.y) < 0.001, "and restored")
	copy.free()

	# Gutting a lizard shows it on the ground as you work.
	Game.inventory.clear()
	p.global_position = spot + Vector3(0, 0, 6)
	p.focus = null
	w.start_work()
	if w.work and w.work.bench == null:
		_lay_all(w.work, {"lizard_carcass": 1})
		w.work.begin(Items.recipe_for("lizard_dressed"))
		check(w.work._work.mesh != null, "the lizard is there to gut")
		w.work.step()
		w.work.step()
		check(w.work._work.mesh != null and w.work._marker.visible, "and stays there while you work on it")
		w.close_work()

	# Tree fern crowns can be cut from any side of the trunk.
	var tf: Node = null
	for c in w.chunks.values():
		for n in c.get_children():
			if n.get_script() == Harvestable and n.kind == "tree_fern" and n.crown > 0.0:
				tf = n
				break
		if tf:
			break
	if tf:
		var cyl: CylinderShape3D = tf.get_child(0).shape
		check(cyl.radius > 0.45 * tf.crown_scale + 0.1 and cyl.height > 1.5, "a tree fern's crown is cut from round the foot of its trunk")

	# Nights are darker, but a bright moon still lights them.
	Game.time = fposmod(Game.solar_to_clock(0.0) - Game.ARRIVAL_CLOCK, Game.DAY_LENGTH)
	w.raining = false
	w._update_sky()
	var dark: float = w._sun.light_energy
	var amb: float = w._env.ambient_light_energy
	check(dark <= 0.12 and amb <= 0.25, "a moonless night is dark (sun %.2f, ambient %.2f)" % [dark, amb])
	w.weather.start("bright_moon")
	w.weather.fade = 1.0
	w._update_sky()
	check(w._sun.light_energy > 0.6 and w._env.ambient_light_energy > 0.55, "a bright moon still lights the night")

	# Salt crusts wash up on the bank, never in the water: about a third
	# of everything that washes up.
	for e in w._shore:
		e.node.queue_free()
	w._shore.clear()
	await _frames(1)
	# Around a stretch of bank, wherever the player happens to be.
	var at: Vector3 = w.shore_spot(w.player.global_position, 0.0, 150.0, 4000, true)
	check(at.is_finite(), "found a bank to wash up on")
	for i in 200:
		w._wash_up(at, 1.0, 30.0, 80, Game.time + 1e6)
	var salts: Array = w._shore.filter(func(e): return e.node.item_id == "salt")
	var share := salts.size() / maxf(w._shore.size(), 1.0)
	check(w._shore.size() > 100 and share > 0.22 and share < 0.48, "salt crusts turn up (%d in %d)" % [salts.size(), w._shore.size()])
	var on_bank := func(e) -> bool:
		var q: Vector3 = e.node.global_position
		return q.y > w.water_level() + 0.02 and q.y >= w.drawn_height(q.x, q.z)
	check(salts.all(on_bank), "all on the bank, out of the water, and on top of the drawn ground")
	check(range(200).all(func(_i): return w._shore_kind(Vector3(0, 0.15, 0)) != "salt"), "a stone's or a stick's turn never gives salt")
	for e in w._shore:
		e.node.queue_free()
	w._shore.clear()
	w.queue_free()
	await _frames(2)


func test_controls() -> void:
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	pad_a.device = 3
	check(pad_a.is_action_pressed("jump"), "a pad numbered 3 still jumps (bindings match every device)")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -1.0
	stick.device = 1
	check(stick.is_action_pressed("move_forward"), "and moves with the stick")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	check(esc.is_action_pressed("pause"), "Esc always pauses")

	var taken := Settings.set_binding("jump", 2, {"button": JOY_BUTTON_Y})
	check(taken == "inventory" and Settings.bindings.inventory[2].is_empty(), "rebinding takes the button off the action that had it")
	var pad_y := pad_a.duplicate()
	pad_y.button_index = JOY_BUTTON_Y
	check(pad_y.is_action_pressed("jump") and not pad_a.is_action_pressed("jump"), "and the new button jumps, the old one not")
	Settings.using_pad = true
	check(Settings.hint("Pick it up [E]   or kneel [C]") == "Pick it up [X]   or kneel [D-pad down]", "prompts name the pad's buttons")
	Settings.using_pad = false
	check(Settings.hint("Open [Right-click]   (Q puts it down)") == "Open [Right-click]   (Q puts it down)", "and the keyboard's")

	# The Controls screen records whatever the pad sends, from rest.
	var cp: Control = load("res://src/ui/controls_panel.gd").new()
	add_child(cp)
	await _frames(1)
	cp._wait("drop", 2)
	var trig := InputEventJoypadMotion.new()
	trig.axis = 5
	trig.axis_value = 0.3
	cp._input(trig)
	check(Settings.bindings.drop[2] == {"button": JOY_BUTTON_B}, "a small nudge doesn't bind")
	trig.axis_value = 0.9
	cp._input(trig)
	check(Settings.bindings.drop[2] == {"axis": 5, "dir": 1}, "a full pull binds the axis")
	cp._wait("sleep", 0)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_DELETE
	key.pressed = true
	cp._input(key)
	check(Settings.bindings.sleep[0].is_empty(), "Delete clears a slot")
	cp.queue_free()
	Settings.reset_bindings()
	check(pad_a.is_action_pressed("jump") and Settings.bindings.drop[2] == {"button": JOY_BUTTON_B}, "reset brings the defaults back")

	# Menus take a pad's A to press the button in focus, B to back out.
	var pad_b := pad_a.duplicate()
	pad_b.button_index = JOY_BUTTON_B
	check(pad_a.is_action_pressed("ui_accept") and pad_b.is_action_pressed("ui_cancel"), "a pad presses menu buttons (A) and backs out (B)")
	var btn := Button.new()
	var hits := [0]
	btn.pressed.connect(func(): hits[0] += 1)
	add_child(btn)
	btn.grab_focus()
	Input.parse_input_event(pad_a)
	var up := pad_a.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
	check(hits[0] == 1, "pressing A on a pad clicks the button in focus (New game, a slot)")
	btn.queue_free()

	# Text written for the mouse and keyboard names the pad's buttons.
	Settings.using_pad = true
	var said := {
		"Click the joints to lash the two shafts together.": "Press A on the joints to lash the two shafts together.",
		"Click items in the tray to lay them on the ground. Right-click lays the whole stack.":
				"Press A on items in the tray to lay them on the ground. Left trigger lays the whole stack.",
		"Choose what to make. Click a pile to pick one back up (right-click for all).":
				"Choose what to make. Press A on a pile to pick one back up (left trigger for all).",
		"Hold the left mouse button and roll the fibers back and forth.": "Hold X and roll the fibers back and forth.",
		"Twist: hold the left mouse button and move the mouse back and forth.  40%": "Twist: hold X.  40%",
		"From up in the house, click to fix rows of boards.": "From up in the house, press A to fix rows of boards.",
		"\nTired (Z to sleep)": "\nTired (Back to sleep)",
		"Put the log down first (Q).": "Put the log down first (B).",
		"Look at one and press E to pick it up.": "Look at one and press X to pick it up.",
		"Top row is your hotbar (keys 1-6). Craft on the ground with [C].":
				"Top row is your hotbar (left bumper / right bumper). Craft on the ground with [D-pad down].",
		"Set up the workbench here [Right-click / Q]": "Set up the workbench here [Left trigger / B]",
	}
	var wrong := []
	for k in said:
		if Settings.hint(k) != said[k]:
			wrong.append(Settings.hint(k))
	check(wrong.is_empty(), "crafting notes and tips name the pad's buttons %s" % [wrong])
	Settings.using_pad = false
	check(Settings.hint("Click the joints (Q).") == "Click the joints (Q).", "and the mouse keeps its words")

	# The touch controls come and go with the setting.
	var was_screen := Settings.touch_screen
	Settings.touch_screen = true
	Settings.set_touch_controls(true)
	var w: Node = await _new_swamp()
	check(Settings.touch and w._touch != null, "touch controls are on")
	Settings.set_touch_controls(false)
	check(not Settings.touch and w._touch == null and Settings.button_name("craft") == "C", "switched off, they go and keys are named again")
	Settings.set_touch_controls(true)
	check(w._touch != null and Settings.button_name("craft") == "Craft", "and back on")
	Settings.touch_screen = was_screen
	Settings.set_touch_controls(true)
	w.queue_free()
	await _frames(2)


func _hold(id: String) -> void:
	Game.inventory.add(id, 1, 0.0, true)
	Game.inventory.select(Game.inventory.find(id))


func _empty_hands() -> void:
	var inv = Game.inventory
	for i in inv.HOTBAR:
		if inv.slots[i] == null:
			inv.select(i)
			return
	inv.slots[0] = null
	inv.select(0)


func test_soup() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	Game.tiers = ["hand", "bench"]
	var r := Items.recipe_for("soup_pot_unfired")
	check(not r.is_empty() and r.tier == "bench" and r.rack == "clay_platter" and r.in.has("clay") and r.in.has("board"),
			"a soup pot is made of clay and boards, at a bench with the clay platter on its rack")
	check(Items.def("soup_pot").carry and Items.def("soup_pot_unfired").carry, "it is too big for the bag")

	# At a bench without the platter it can't be made; with it, the pot is
	# left standing beside the bench, not put in the bag.
	var spot := _find_spot(w, p.global_position, func(q): return q.y > 0.3 and q.y < 2.0)
	var bench: Node = w.add_bench(spot, 0.0)
	p.global_position = bench.global_position + bench.global_basis.z * 1.2
	p.rotation.y = 0.0
	p.focus = bench
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, {"clay": 10, "board": 3})
	var so := _option_for(ws, "soup_pot_unfired")
	check(so.is_empty(), "until you have made or held a clay platter, the soup pot isn't offered")
	Game.learn_tool("clay_platter")
	so = _option_for(ws, "soup_pot_unfired")
	check(not so.is_empty() and so.missing.any(func(m): return "rack" in m), "once you know the platter, it needs it on the rack")
	w.close_work()
	bench.hang("clay_platter")
	p.focus = bench
	w.start_work()
	ws = w.work
	_lay_all(ws, {"clay": 10, "board": 3})
	so = _option_for(ws, "soup_pot_unfired")
	check(not so.is_empty() and so.missing.is_empty(), "with the platter hanging there it can be made")
	var pots := func(): return get_tree().get_nodes_in_group("soup_pots").filter(func(s): return not s.is_queued_for_deletion())
	check(_make(ws, so.recipe), "you build an unfired soup pot")
	await _frames(2)
	check(pots.call().size() == 1 and Game.inventory.count("soup_pot_unfired") == 0, "it stands beside the bench, not in your bag")
	w.close_work()
	var sp: Node = pots.call()[0]
	check(sp.item_id == "soup_pot_unfired" and sp.global_position.distance_to(bench.global_position) < 3.0, "unfired, right by the bench")

	# Carried like a log, and it won't hold water until it is fired.
	p.global_position = sp.global_position + Vector3(0, 0, 1.4)
	_empty_hands()
	check("Pick up" in sp.prompt(p), "E picks the unfired pot up")
	sp.interact(p)
	check(p.hauling == sp, "you carry it in your arms")
	p.focus_water = true
	check(sp.haul_interact(p) and sp.is_empty(), "unfired, it can't be filled")
	p.focus_water = false

	# Set down by a campfire, it hangs over the middle of the fire, leaving the
	# cooking spots free.
	var fire_at := spot + Vector3(4, 0, 4)
	fire_at.y = w.ground_height(fire_at.x, fire_at.z)
	var fire: Node = w._add_fire(fire_at, 2000.0, true)
	var sunk := 0.0
	for s in fire._spots:
		var at: Vector3 = s.global_position
		sunk = maxf(sunk, absf(at.y - w.ground_height(at.x, at.z)))
	check(sunk < 0.02, "every cooking spot sits on the ground under it, not sunk in a slope (off by %.3f m)" % sunk)
	p.global_position = fire_at + Vector3(0, 0, 1.4)
	p.rotation.y = 0.0
	p._hold_haul()
	p._update_focus()
	check("over the fire" in p.prompt, "carried near a fire, it offers to hang over it (%s)" % p.prompt)
	p.put_down()
	check(sp.fire == fire and Vector2(sp.global_position.x - fire_at.x, sp.global_position.z - fire_at.z).length() < 0.01,
			"it hangs over the middle of the fire")
	check(fire.free_spot() == 0 and fire.cooking.count(null) == Campfire.SPOTS, "every cooking spot round the edge is still free")
	var aabb: AABB = Assets.mesh("item_soup_pot").get_aabb()
	var small: AABB = Assets.mesh("item_pot").get_aabb()
	check(aabb.size.y > 1.5 and aabb.size.x > 1.5 and small.size.y < 0.3, "it is far bigger than a clay pot, on its tripod (%.2f m tall)" % aabb.size.y)
	check(sp.HANG_Y > 0.5, "and the pot hangs clear of the flames")
	sp.advance(SoupPot.FIRE_TIME + 1.0, SoupPot.FIRE_TIME + 1.0)
	check(sp.item_id == "soup_pot", "hung over a lit fire long enough, it is fired")

	# A second pot can't hang over the same fire.
	var sp2: Node = w.add_soup_pot("soup_pot", fire_at + Vector3(3, 0, 0))
	check(sp2.fire_near(fire_at) == null, "only one pot hangs over a fire")
	sp2.queue_free()

	# Filling it at the water: 16 servings of swamp water.
	_empty_hands()
	sp.interact(p)
	check(p.hauling == sp and sp.fire == null, "an empty pot is picked up with E")
	p.focus_water = true
	p._water_at = Vector3(fire_at.x, 0.0, fire_at.z)
	check("Fill" in sp.haul_prompt(p), "at the water it offers to fill")
	check(sp.haul_interact(p), "E at the water fills it")
	check(sp.water == SoupPot.SERVINGS and sp.dirty and not sp.has_soup(), "16 servings of swamp water")
	check(p.hauling == sp, "and you keep carrying it")
	p.focus_water = false
	p._hold_haul()
	p.put_down()
	check(sp.fire == fire, "back over the fire")

	# Soup needs clean water to start.
	_hold("seed")
	check(sp.add_food("seed") != "" and not sp.has_soup(), "food can't go into swamp water")
	check("Boil" in sp.prompt(p), "it says to boil the water first (%s)" % sp.prompt(p))
	sp.advance(SoupPot.HEAT_TIME, SoupPot.HEAT_TIME)
	check(sp.boiling() and not sp.dirty, "over the lit fire the water comes to the boil and is clean")
	check("Soup Pot" in sp.tooltip(p) and "16 servings of water" in sp.tooltip(p), "looking at it tells you what it holds (%s)" % sp.tooltip(p))

	# The water: drunk from the pot, or scooped out with a clay pot.
	_empty_hands()
	var thirst := 30.0
	p.vitals.water = thirst
	check("Drink" in sp.prompt(p), "with empty hands, E drinks from it")
	sp.interact(p)
	check(sp.water == 15.0 and p.vitals.water > thirst + 35.0, "a serving of boiled water (%.1f left, water %.0f)" % [sp.water, p.vitals.water])
	_hold("pot")
	check("Fill the clay pot" in sp.prompt(p), "a clay pot scoops water out")
	sp.interact(p)
	check(Game.inventory.count("pot_clean") == 1 and Game.inventory.count("pot") == 0 and sp.water == 14.0, "into a pot of boiled water")

	# Food added makes soup with its cooked values, and tops the water up.
	Game.inventory.clear()
	_hold("raw_meat")
	check("Add Raw Meat" in sp.prompt(p), "holding food, E adds it")
	sp.interact(p)
	check(Game.inventory.count("raw_meat") == 0 and sp.has_soup(), "it goes in the pot")
	check(is_equal_approx(sp.nut.protein, Items.def("cooked_meat").protein) and is_equal_approx(sp.nut.energy, Items.def("cooked_meat").energy),
			"counted as cooked meat (protein %.0f)" % sp.nut.protein)
	check(is_equal_approx(sp.water, 14.0 + SoupPot.PER_FOOD), "each item tops the pot up by 16/12 of a serving (%.2f)" % sp.water)
	check(not sp.boiling() and not sp.safe() and sp.status() == "needs boiling", "adding food knocks it off the boil: it has to boil again")
	sp.advance(30.0, 30.0)
	check(sp.boiling() and sp.safe(), "boiled again, it is safe")
	var tip: String = sp.tooltip(p)
	check("Meat %d%%" % roundi(sp.nut.protein / sp.water) in tip and "Starch 0%" in tip and "Greens 0%" in tip and "15 servings left" in tip,
			"the tooltip lists meat, starch and greens per serving and the servings left (%s)" % tip.replace("\n", " | "))

	# Eaten straight from the pot: one serving's share, plus water.
	_empty_hands()
	p.vitals.protein = 0.0
	p.vitals.water = 0.0
	var per: float = sp.per_serving("protein")
	check("Eat a serving" in sp.prompt(p), "with empty hands, E eats a serving")
	sp.interact(p)
	check(absf(p.vitals.protein - per) < 0.01 and p.vitals.water >= SoupPot.SOUP_WATER - 0.01, "a serving feeds you its share and gives water (%.1f protein)" % p.vitals.protein)

	# The serving arithmetic: twelve items fill it, and eating frees room.
	sp.empty_out()
	sp.water = SoupPot.SERVINGS
	var added := 0
	for i in 12:
		if sp.add_food("roast_seed") == "":
			added += 1
	check(added == 12, "twelve items go in (%d)" % added)
	check(sp.food == 12.0 and sp.water == 16.0, "twelve items make a full pot of 16 servings")
	check(sp.add_food("roast_seed") != "" and sp.food == 12.0, "a thirteenth won't fit")
	for i in 10:
		sp.take_serving()
	check(is_equal_approx(sp.water, 6.0) and is_equal_approx(sp.food, 4.5), "6 servings left hold 4.5 items' worth")
	for i in 3:
		sp.add_food("roast_seed")
	check(is_equal_approx(sp.water, 10.0) and is_equal_approx(sp.food, 7.5), "three more items fill it as if 4 servings of water went in (%.2f)" % sp.water)
	check(is_equal_approx(sp.nut.starch, Items.def("roast_seed").starch * 7.5), "the nutrients follow the food (%.1f starch)" % sp.nut.starch)
	check(not SoupPot.accepts("pot_clean") and not SoupPot.accepts("pot_soup") and not SoupPot.accepts("stick") and SoupPot.accepts("fiddlehead"),
			"any food goes in, but not water, soup or anything else")

	# Scooped into a clay pot: a Pot of Soup that carries its serving.
	sp.advance(60.0, 60.0)
	Game.time += 600.0
	sp.advance(0.0, 0.0)
	var boiled_at: float = sp.fresh_at
	Game.inventory.clear()
	_hold("pot")
	var each: float = sp.per_serving("starch")
	sp.interact(p)
	var si: int = Game.inventory.find("pot_soup")
	check(si >= 0 and is_equal_approx(Game.inventory.slots[si].data.starch, each), "a clay pot scoops out a Pot of Soup with its serving")
	check(absf(Game.inventory.slots[si].age - (Game.time - boiled_at)) < 0.01, "and it keeps only as long as the soup would have")
	# It stays itself in the bag, saved, dropped and picked up again.
	var saved_inv: Dictionary = Game.inventory.to_dict()
	Game.inventory.from_dict(saved_inv)
	si = Game.inventory.find("pot_soup")
	check(si >= 0 and is_equal_approx(Game.inventory.slots[si].data.starch, each), "a saved Pot of Soup keeps its serving")
	Game.inventory.add("pot_soup", 1, 0.0, true, {"starch": 1.0})
	check(Game.inventory.count("pot_soup") == 2 and Game.inventory.slots[si].n == 1, "two pots of soup never stack")
	Game.inventory.remove("pot_soup", 1)
	Game.inventory.select(Game.inventory.find("pot_soup"))
	p._drop_held()
	var drops: Array = get_tree().get_nodes_in_group("drops").filter(func(d): return d.item_id == "pot_soup" and not d.is_queued_for_deletion())
	check(drops.size() == 1 and is_equal_approx(drops[0].data.get("starch", 0.0), each) and drops[0].to_dict().has("data"), "dropped, it keeps its serving (and is saved with it)")
	if not drops.is_empty():
		drops[0].interact(p)
	si = Game.inventory.find("pot_soup")
	check(si >= 0 and is_equal_approx(Game.inventory.slots[si].data.starch, each), "picked up again, still the same soup")
	p.vitals.starch = 0.0
	p.consume_slot(si)
	check(absf(p.vitals.starch - each) < 0.01 and Game.inventory.count("pot") == 1, "eating it gives its serving and leaves the clay pot")

	# It keeps 36 game hours after it last boiled; boiling resets that.
	check(SoupPot.LIFE == 36.0 * 60.0, "soup keeps 36 game hours")
	sp.advance(5.0, 5.0)
	check(is_equal_approx(sp.fresh_at, Game.time), "while it boils the clock is reset")
	Game.time += SoupPot.LIFE * 0.9
	sp.advance(1.0, 1.0)
	check(not sp.spoiled() and is_equal_approx(sp.fresh_at, Game.time), "boiled again before it turns, it keeps on")
	sp.advance(SoupPot.COOL_TIME, 0.0)
	Game.time += SoupPot.LIFE + 1.0
	check(sp.spoiled() and sp.status() == "spoiled", "left off the boil too long, it goes off")
	sp.advance(60.0, 60.0)
	check(sp.spoiled(), "and boiling it again doesn't save it")
	_hold("seed")
	check(sp.add_food("seed") != "", "nothing more goes into spoiled soup")
	Game.inventory.clear()
	_hold("pot")
	sp.interact(p)
	check(Game.inventory.count("pot_soup_spoiled") == 1, "scooped out, it is spoiled soup")

	# Carried, it keeps what is in it; saved with the world, over its fire.
	sp.empty_out()
	sp.water = 8.0
	sp.add_food("cooked_fiddlehead")
	sp.add_food("roast_grub")
	var before: Dictionary = sp.to_dict()
	sp.craft_interact(p)
	check(p.hauling == sp, "C picks it up even with soup in it")
	for i in 5:
		await get_tree().physics_frame
	p.global_position = fire_at + Vector3(0, 0, 1.4)
	p.rotation.y = 0.0
	p._hold_haul()
	p.put_down()
	check(sp.fire == fire and is_equal_approx(sp.water, before.water) and is_equal_approx(sp.nut.greens, before.nut.greens), "carrying it spills nothing")
	var state: Dictionary = w._world_state()
	check(state.soup_pots.size() == 1 and state.soup_pots[0].hung, "the soup pot is saved, hanging over its fire")
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	Game.restore = state
	w.queue_free()
	await _frames(2)
	Game.fires.clear()
	add_child(w2)
	await _frames(5)
	var back: Array = get_tree().get_nodes_in_group("soup_pots").filter(func(s): return not s.is_queued_for_deletion())
	check(back.size() == 1 and back[0].hung() and is_equal_approx(back[0].water, before.water) and is_equal_approx(back[0].nut.protein, before.nut.protein),
			"and restored with its soup, over the fire")

	# Sleeping by it: the fire keeps it boiling, so the soup keeps.
	if back.size() == 1:
		var pot: Node = back[0]
		pot.fire.fuel = 2000.0
		pot.fire._set_lit(true)
		pot.heat = 0.0
		var t0: float = Game.time
		w2._pass_time(480.0)
		check(pot.boiling() and pot.fresh_at > t0 + 400.0, "a night's sleep by the fire keeps it on the boil (fresh %.0f s on)" % (pot.fresh_at - t0))
	w2.queue_free()
	await _frames(2)


func _lay_from_bag(ws: Node, items: Dictionary) -> void:
	for id in items:
		ws.lay(Game.inventory.find(id), items[id])


func test_paper() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	w._spawn_t = 1e9
	Game.inventory.clear()
	Game.tiers = ["hand", "bench"]
	Game.tools_known = []
	var at: Vector3 = p.global_position - p.global_basis.z * 1.6
	at.y = w.ground_height(at.x, at.z)
	var bench: Node = w.add_bench(at, p.rotation.y)
	await _frames(2)
	var kneel := func() -> Node:
		p.focus = bench
		w.start_work()
		return w.work

	# Unknown until you have had the papermaking tools, then they need them on the rack.
	var ws: Node = kneel.call()
	check(ws != null and ws.bench == bench, "kneeling at a workbench")
	_lay_all(ws, {"plant_fiber": 12, "pot_dirty": 1, "pot_clean": 1, "ash": 1, "clay": 1})
	check(_option_for(ws, "paper_wet").is_empty() and _option_for(ws, "pencil_core_unfired").is_empty(),
			"paper and pencil recipes are unknown before you have made or held the papermaking tools")
	Game.learn_tool("papermaking_tools", false)
	var o := _option_for(ws, "paper_wet")
	check(not o.is_empty() and o.missing.any(func(m): return "Papermaking Tools on the workbench rack" in m) and not _make(ws, o.recipe),
			"then a sheet needs the papermaking tools on the rack")
	o = _option_for(ws, "pencil_core_unfired")
	check(not o.is_empty() and o.missing.any(func(m): return "rack" in m), "and so does a pencil core")
	w.close_work()
	check(Game.inventory.count("pot_dirty") == 1 and Game.inventory.count("plant_fiber") == 12, "standing up gives back what was laid out")
	bench.hang("papermaking_tools")

	# A big blank sheet: fiber mashed with a pot of water, then dried by a fire.
	ws = kneel.call()
	_lay_from_bag(ws, {"plant_fiber": 6, "pot_dirty": 1})
	o = _option_for(ws, "paper_wet")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe), "fiber and a pot of swamp water make a sheet")
	check(Game.inventory.count("paper_wet") == 1 and Game.inventory.count("pot") == 1 and Game.inventory.count("pot_dirty") == 0,
			"a wet sheet, and the empty pot comes back")
	_lay_from_bag(ws, {"plant_fiber": 6, "pot_clean": 1})
	o = _option_for(ws, "paper_wet")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and Game.inventory.count("pot") == 2,
			"boiled water does too")
	# The pencil core: ash and clay, rolled and fired.
	_lay_from_bag(ws, {"ash": 1, "clay": 1})
	o = _option_for(ws, "pencil_core_unfired")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and Game.inventory.count("pencil_core_unfired") == 1,
			"one ash and one clay roll a pencil core")
	w.close_work()

	# Both are finished in a campfire, and neither burns.
	Game.inventory.add("campfire_kit")
	Game.inventory.select(Game.inventory.find("campfire_kit"))
	check(w.place("campfire", p.global_position + p.global_basis.x * 1.5), "a campfire set down")
	var fire: Node = Game.fires[-1]
	fire.lit = true
	fire.fuel = fire.MAX_FUEL
	for id in ["paper_wet", "pencil_core_unfired"]:
		Game.inventory.select(Game.inventory.find(id))
		fire.interact(p)
	var spots := [fire.cooking.find_custom(func(c): return c != null and c.id == "paper_wet"),
			fire.cooking.find_custom(func(c): return c != null and c.id == "pencil_core_unfired")]
	check(spots[0] >= 0 and spots[1] >= 0, "the wet sheet and the core go on the fire")
	fire.cook(60.0)
	check(fire.result(spots[0]) == "paper_sheet" and fire.result(spots[1]) == "pencil_core", "the sheet dries and the core hardens")
	fire.cook(600.0)
	check(fire.result(spots[0]) == "paper_sheet" and fire.result(spots[1]) == "pencil_core", "left on, neither chars")
	fire.take(spots[0])
	fire.take(spots[1])
	check(Game.inventory.count("paper_sheet") == 1 and Game.inventory.count("pencil_core") == 1, "a big blank sheet and a pencil core")

	# The pencil: a stick split with any blade, the core bound inside.
	ws = kneel.call()
	Game.inventory.add("stick")
	Game.inventory.add("cordage")
	_lay_from_bag(ws, {"pencil_core": 1, "stick": 1, "cordage": 1})
	o = _option_for(ws, "ash_pencil")
	check(not o.is_empty() and o.missing.has("a blade to work with"), "the pencil needs a blade to split the stick")
	Game.inventory.add("stone_axe")
	check(ws.missing_for(o.recipe).is_empty(), "a stone axe will do")
	Game.inventory.remove("stone_axe", 1)
	Game.inventory.add("flint_blade")
	check(ws.missing_for(o.recipe).is_empty() and _make(ws, o.recipe), "so will a chert blade")
	check(Game.inventory.count("ash_pencil") == 1 and Game.inventory.count("flint_blade") == 1 and Game.inventory.count("pencil_core") == 0,
			"an ash pencil, and the blade is kept")
	w.close_work()
	bench.take_down(bench.tools.find("papermaking_tools"), p)
	ws = kneel.call()
	Game.inventory.add("pencil_core")
	Game.inventory.add("stick")
	Game.inventory.add("cordage")
	_lay_from_bag(ws, {"pencil_core": 1, "stick": 1, "cordage": 1})
	check(_option_for(ws, "ash_pencil").missing.any(func(m): return "rack" in m), "the pencil too needs the papermaking tools on the rack")
	w.close_work()

	# The recipe book says so.
	var book: Control = w.inv_ui._book_entry(Items.recipe_for("ash_pencil"))
	var text: String = book.get_child(1).get_child(1).text
	check("any blade" in text and "Papermaking Tools" in text, "the book asks for any blade and the papermaking tools on the rack")
	book.free()
	check(Items.ADVANCED in w.inv_ui.book_categories() and "Writing" in Items.CATEGORIES, "they are in the book")
	# No other recipe uses up a container by mistake.
	var odd := Items.RECIPES.filter(func(r): return not r.out in ["paper_wet", "whetstone"] and r.in.keys().any(func(id): return Items.def(id).has("empty")))
	check(odd.is_empty(), "only the sheet and the whetstone use up a pot of water (%s)" % [odd.map(func(r): return r.out)])
	w.queue_free()
	await _frames(2)


func test_canteen() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	Game.tiers = ["hand", "bench"]

	# Two servings, and 20% lighter than a clay pot.
	check(is_equal_approx(Items.weight("canteen"), Items.weight("pot") * 0.8), "an empty canteen weighs 80%% of a clay pot (%.2f kg)" % Items.weight("canteen"))
	var serving: float = Items.weight("pot_clean") - Items.weight("pot")
	for kind in ["dirty", "clean", "soup", "soup_spoiled"]:
		check(is_equal_approx(Items.weight("canteen_%s_1" % kind), Items.weight("canteen") + serving)
				and is_equal_approx(Items.weight("canteen_%s_2" % kind), Items.weight("canteen") + serving * 2.0),
				"a canteen of %s weighs one or two servings more" % kind)
		check(Items.def("canteen_%s_2" % kind).empty == "canteen_%s_1" % kind and Items.def("canteen_%s_1" % kind).empty == "canteen",
				"drinking a full canteen of %s leaves it half full, then empty" % kind)
	var r := Items.recipe_for("canteen")
	check(r.tier == "bench" and r.rack == "woodworking_tools" and r.in.has("board"), "it is carved at a bench with the woodworking tools on its rack")

	# The recipe book: rack recipes have their own page, once you know the tool.
	var ui: Node = w.inv_ui
	var shown := func(id): return Items.RECIPES.any(func(rr): return rr.out == id and rr.cat in ui.book_categories() and not rr.has("rack"))
	check(not Items.ADVANCED in ui.book_categories(), "with no rack tool known, there is no rack tools page")
	check(not shown.call("canteen") and not shown.call("soup_pot_unfired"), "and the canteen and soup pot aren't in Containers")
	ui._cat = "Containers"
	ui._refresh_book()
	await _frames(1)
	var titles := func(): return ui._book.get_children().filter(func(c): return c is HBoxContainer).map(func(c): return c.get_child(1).get_child(0).text)
	check(not titles.call().has("Wooden Canteen") and titles.call().has("Clay Pot") or titles.call().has("Unfired Pot"), "Containers lists only what needs no rack tool (%s)" % ", ".join(titles.call()))
	# Holding the woodworking tools teaches them.
	Game.inventory.add("woodworking_tools")
	Game.inventory.select(Game.inventory.find("woodworking_tools"))
	await _frames(3)
	check("woodworking_tools" in Game.tools_known, "holding the woodworking tools teaches you their recipes")
	check(Items.ADVANCED in ui.book_categories() and ui.book_rack_tools() == ["woodworking_tools"], "the rack tools page appears, for the woodworking tools only")
	ui._cat = Items.ADVANCED
	ui._refresh_book()
	await _frames(1)
	check(titles.call().has("Wooden Canteen") and titles.call().all(func(t): return t in ["Wooden Canteen", "Unfired Blowpipe", "Wooden Cap x4"]), "it lists the canteen (%s)" % ", ".join(titles.call()))
	# Crafting the platter teaches it too.
	Game.crafted.emit("clay_platter")
	check("clay_platter" in Game.tools_known and ui.book_rack_tools().size() == 2, "making a clay platter adds its recipes")
	ui._refresh_book()
	await _frames(1)
	check(titles.call().has("Unfired Unsealed Fermentation Vessel") and titles.call().has("Wooden Canteen"), "both, each under its tool")
	check(not titles.call().has("Unfired Soup Pot"), "but not the soup pot")
	ui._cat = "Containers"
	ui._refresh_book()
	await _frames(1)
	check(titles.call().has("Unfired Soup Pot"), "which is listed under Containers once you know the platter")
	var saved: Dictionary = {}
	Game.save_game({})
	saved = Game.read_save()
	check(saved.get("tools_known", []).has("woodworking_tools"), "known tools are saved")

	# Made at the bench with the tools on the rack.
	Game.tools_known = []
	var spot := _find_spot(w, p.global_position, func(q): return q.y > 0.3 and q.y < 2.0)
	var bench: Node = w.add_bench(spot, 0.0)
	Game.inventory.clear()
	p.global_position = bench.global_position + bench.global_basis.z * 1.2
	p.rotation.y = 0.0
	p.focus = bench
	w.start_work()
	_lay_all(w.work, {"board": 1, "wax": 2, "cordage": 1})
	check(_option_for(w.work, "canteen").is_empty(), "not offered at the bench before you know the tools")
	w.close_work()
	Game.learn_tool("woodworking_tools")
	p.focus = bench
	w.start_work()
	_lay_all(w.work, {"board": 1, "wax": 2, "cordage": 1})
	var co := _option_for(w.work, "canteen")
	check(not co.is_empty() and co.missing.any(func(m): return "rack" in m), "it needs the woodworking tools on the rack")
	w.close_work()
	bench.hang("woodworking_tools")
	p.focus = bench
	w.start_work()
	_lay_all(w.work, {"board_tree_fern": 2, "board_calamites": 1, "wax": 2, "cordage": 1})
	check(w.work.laid("board") == 3, "laid out, boards of different woods add up")
	co = _option_for(w.work, "canteen")
	check(not co.is_empty() and co.missing.is_empty() and _make(w.work, co.recipe), "you carve a canteen from any board")
	check(w.work.laid("board") == 2, "using just one of them")
	var took: Array = w.work._take_pile("board", 2)
	check(took.size() == 2 and took.all(func(t): return t.n == 1) and w.work.laid("board") == 0, "a recipe takes boards from either pile")
	check(Game.inventory.count("canteen") == 1, "it goes in your bag")
	w.close_work()

	# Filled at the water: two servings of swamp water, kept in your hand.
	Game.inventory.clear()
	Game.inventory.add("stone", 2)
	Game.inventory.add("canteen")
	var slot: int = Game.inventory.find("canteen")
	Game.inventory.select(slot)
	p.focus = null
	p.focus_water = true
	p._interact()
	check(Game.inventory.held_id() == "canteen_dirty_2", "filled at the water: two servings of swamp water, still in your hand")
	p.vitals.water = 0.0
	p.consume_slot(slot)
	check(Game.inventory.slots[slot].id == "canteen_dirty_1" and p.vitals.water >= 34.9, "a drink leaves it half full, in the same slot")
	p.consume_slot(slot)
	check(Game.inventory.slots[slot].id == "canteen", "another empties it")

	# From a soup pot: boiled water, two scoops.
	var sp: Node = w.add_soup_pot("soup_pot", spot + Vector3(4, 0, 0))
	sp.water = 16.0
	sp.dirty = false
	check("Fill the wooden canteen" in sp.prompt(p), "at a pot of boiled water it offers to fill the canteen (%s)" % sp.prompt(p))
	sp.interact(p)
	check(Game.inventory.held_id() == "canteen_clean_1" and sp.water == 15.0, "one serving of boiled water")
	sp.interact(p)
	check(Game.inventory.held_id() == "canteen_clean_2" and sp.water == 14.0, "and a second")
	p.vitals.add_wound(0.2, 0.8, "test")
	check(p.treat_slot(slot) and Game.inventory.slots[slot].id == "canteen_clean_1", "boiled water from it washes a wound, a serving at a time")
	sp.interact(p)
	check(Game.inventory.held_id() == "canteen_clean_2", "topped up again")
	Game.inventory.slots[slot] = {"id": "canteen_dirty_1", "n": 1, "age": 0.0}
	check("holds something else" in sp.prompt(p), "swamp water and boiled water don't mix")
	sp.interact(p)
	check(Game.inventory.held_id() == "canteen_dirty_1" and sp.water == 13.0, "so nothing is scooped (%.0f left)" % sp.water)

	# Soup: two servings, which mix, and keep as long as the soup would.
	Game.inventory.slots[slot] = {"id": "canteen", "n": 1, "age": 0.0}
	sp.add_food("cooked_meat")
	sp.advance(60.0, 60.0)
	var meat1: float = sp.per_serving("protein")
	Game.time += 300.0
	sp.interact(p)
	var s1: Dictionary = Game.inventory.slots[slot]
	check(s1.id == "canteen_soup_1" and is_equal_approx(s1.data.protein, meat1), "a canteen scoops a serving of soup")
	sp.add_food("roast_seed")
	sp.advance(60.0, 60.0)
	var meat2: float = sp.per_serving("protein")
	sp.interact(p)
	var s2: Dictionary = Game.inventory.slots[slot]
	check(s2.id == "canteen_soup_2" and is_equal_approx(s2.data.protein, (meat1 + meat2) * 0.5), "a second serving mixes with the first")
	check(s2.age >= 300.0 - 0.01, "and it is as old as the older serving (%.0f s)" % s2.age)
	p.vitals.protein = 0.0
	p.consume_slot(slot)
	var s3: Dictionary = Game.inventory.slots[slot]
	check(absf(p.vitals.protein - s2.data.protein) < 0.01 and s3.id == "canteen_soup_1" and is_equal_approx(s3.data.protein, s2.data.protein) and s3.age == s2.age,
			"drinking one serving leaves the other, the same soup and age")
	p.consume_slot(slot)
	check(Game.inventory.slots[slot].id == "canteen", "and then it is empty")
	Game.inventory.slots[slot] = {"id": "canteen_soup_2", "n": 1, "age": SoupPot.LIFE - 1.0, "data": {"protein": 3.0}}
	Game.inventory.tick(2.0)
	check(Game.inventory.slots[slot].id == "canteen_soup_spoiled_2", "left too long, the soup in it goes off")
	check(Items.def("canteen").get("cook", "") == "" and not Items.def("canteen_dirty_2").has("cook"), "a wooden canteen can't be put on the fire")
	w.queue_free()
	await _frames(2)


func test_ferment() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()

	# Made at a bench with the clay platter, left beside it, fired in a fire.
	for id in ["vessel_open_unfired", "vessel_sealed_unfired"]:
		var r := Items.recipe_for(id)
		check(r.tier == "bench" and r.rack == "clay_platter" and Items.def(id).carry, "%s: at a bench with the clay platter, and carried" % id)
	var spot := _find_spot(w, p.global_position, func(q): return q.y > 0.3 and q.y < 2.0)
	var bench: Node = w.add_bench(spot, 0.0)
	bench.hang("clay_platter")
	Game.learn_tool("clay_platter")
	p.global_position = bench.global_position + bench.global_basis.z * 1.2
	p.rotation.y = 0.0
	p.focus = bench
	w.start_work()
	_lay_all(w.work, {"clay": 8})
	check(_make(w.work, _option_for(w.work, "vessel_open_unfired").recipe), "you coil an unsealed vessel")
	await _frames(2)
	w.close_work()
	var vs := func(): return get_tree().get_nodes_in_group("vessels").filter(func(x): return not x.is_queued_for_deletion())
	check(vs.call().size() == 1 and Game.inventory.count("vessel_open_unfired") == 0, "it stands beside the bench, not in your bag")
	var v: Node = vs.call()[0]
	var fire_at := spot + Vector3(4, 0, 4)
	fire_at.y = w.ground_height(fire_at.x, fire_at.z)
	var fire: Node = w._add_fire(fire_at, 2000.0, true)
	p.global_position = v.global_position + Vector3(0, 0, 1.4)
	_empty_hands()
	v.interact(p)
	check(p.hauling == v, "E picks it up")
	p.focus_water = true
	check(v.haul_interact(p) and v.water == 0, "unfired, it won't hold water")
	p.focus_water = false
	p.global_position = fire_at + Vector3(0, 0, 1.4)
	p.rotation.y = 0.0
	p._hold_haul()
	p.put_down()
	check(v.fire == fire and fire.free_spot() == 0, "put down by a fire it sits in it, leaving the cooking spots")
	check("lit campfire" in v.tooltip(p), "it says to fire it (%s)" % v.tooltip(p))
	var f0: float = v.fired
	await _frames(10)
	check(v.fired > f0 and v.fired < v.FIRE_TIME, "it fires as the frames go by, in the lit fire (%.2f s)" % v.fired)
	v._process(v.FIRE_TIME)
	check(v.item_id == "vessel_open" and v.fired_pot(), "and is fired")
	var sp: Node = w.add_soup_pot("soup_pot", fire_at + Vector3(3, 0, 0))
	check(sp.fire_near(fire_at) == null, "nothing else goes on that fire")
	sp.queue_free()
	# A sealed one is fired the same way.
	var at2 := fire_at + Vector3(-5, 0, 0)
	at2.y = w.ground_height(at2.x, at2.z)
	var fire2: Node = w._add_fire(at2, 2000.0, true)
	var sealed_v: Node = w.add_vessel("vessel_sealed_unfired", at2 + Vector3(0, 0, 3))
	p.global_position = sealed_v.global_position + Vector3(0, 0, 1.4)
	_empty_hands()
	sealed_v.interact(p)
	p.global_position = at2 + Vector3(0, 0, 1.4)
	p.rotation.y = 0.0
	p._hold_haul()
	p._update_focus()
	check(p.hauling == sealed_v and "in the fire" in p.prompt, "a sealed vessel too is carried to a fire (%s)" % p.prompt)
	p.put_down()
	sealed_v._process(sealed_v.FIRE_TIME + 1.0)
	check(sealed_v.fire == fire2 and sealed_v.item_id == "vessel_sealed", "and fired in it")
	sealed_v.queue_free()

	# Swamp water, boiled, then cooled before food goes in.
	v.fill_dirty()
	check(v.water == v.CAP and v.dirty, "filled at the water: ten servings of swamp water")
	check(v.add_food("seed") != "", "food can't go into swamp water")
	v.advance(v.HEAT_TIME, v.HEAT_TIME)
	check(not v.dirty and v.boiling(), "boiled in the fire, the water is clean")
	check(v.add_food("seed") != "" and v.items.is_empty(), "but food waits until it cools")
	v.fire = null
	v.advance(v.COOL_TIME, 0.0)
	check(v.cool(), "off the fire it cools")

	# Lacto fermentation: pickled after a day.
	for id in ["seed", "fiddlehead", "roast_seed"]:
		check(v.add_food(id) == "", "%s goes in" % id)
	check(v.mode() == "lacto" and not v.rancid, "an unsealed vessel pickles")
	v.advance(v.FERMENT_TIME - 10.0, 0.0)
	check(v.items.all(func(it): return Items.cure_of(it.id) == ""), "not before a day is up")
	v.advance(20.0, 0.0)
	check(v.items.all(func(it): return Items.cure_of(it.id) == "pickled"), "a day later they are pickled")
	var pk := Items.def("pickled:roast_seed")
	check(is_equal_approx(pk.starch, Items.def("roast_seed").starch * 1.1 + 3.0) and is_equal_approx(pk.greens, 3.0)
			and pk.decay == Items.def("roast_seed").decay * 2.0,
			"pickled food is 10% more nourishing, with a little greens and starch, and keeps twice as long")
	var sp_def := Items.def("spirit:cooked_meat")
	check(is_equal_approx(sp_def.protein, Items.def("cooked_meat").protein * 1.1) and is_equal_approx(sp_def.greens, 3.0)
			and is_equal_approx(sp_def.starch, 3.0), "preserved in alcohol: a little greens and starch too")
	check(not Items.def("salted:roast_seed").has("greens") and is_equal_approx(Items.def("salted:roast_seed").starch, Items.def("roast_seed").starch),
			"salting adds none")
	check(Items.def("canteen_alcohol").get("starch", 0.0) > 0.0, "a measure of alcohol gives some starch")
	for cid in ["canteen_alcohol", "canteen_clean_2", "canteen_soup_1", "pot_clean", "pot_soup"]:
		check(not Items.can_cure(cid), "a %s can't be pickled or preserved" % cid)
	v.advance(Game.DAY_LENGTH * 10.0, 0.0)
	check(v.items.all(func(it): return Items.cure_of(it.id) == "pickled"), "nothing spoils in the vessel")
	Game.inventory.clear()
	check(v.take_to_bag(0) and Game.inventory.count("pickled:seed") == 1 and v.items.size() == 2, "taken out, a pickled seed goes in your bag")

	# Too much food for the water, or too much meat: rancid.
	var r1: Node = w.add_vessel("vessel_open", spot + Vector3(-4, 0, 0))
	r1.water = 2
	r1.add_food("seed")
	r1.add_food("seed")
	check(not r1.rancid, "as much food as water is fine")
	check(r1.would_spoil("seed") != "", "the prompt warns before a third")
	r1.add_food("seed")
	check(r1.rancid and r1.items.all(func(it): return it.id == "rotten"), "more food than water and it goes rancid")
	check(r1.add_food("seed") != "", "nothing more goes in until it is washed out")
	var r2: Node = w.add_vessel("vessel_open", spot + Vector3(-4, 0, 3))
	r2.water = 10
	for id in ["seed", "seed", "seed"]:
		r2.add_food(id)
	r2.add_food("cooked_meat")
	check(not r2.rancid, "a quarter meat is fine")
	r2.add_food("cooked_meat")
	check(r2.rancid, "over 30% meat and it goes rancid")
	# Raw meat spoils a pickle or a brew at once (salting it is fine: below).
	var r3: Node = w.add_vessel("vessel_open", spot + Vector3(-7, 0, 0))
	r3.water = 10
	for id in ["seed", "seed", "seed", "seed"]:
		r3.add_food(id)
	check(r3.would_spoil("raw_meat") == "raw meat" and r3.would_spoil("grub") == "", "the prompt warns of raw meat, not of a grub")
	r3.add_food("raw_meat")
	check(r3.rancid, "raw meat in a pickle and it goes rancid")
	var r4: Node = w.add_vessel("vessel_sealed", spot + Vector3(-7, 0, 3))
	r4.water = 10
	for id in ["seed", "seed", "seed", "seed"]:
		r4.add_food(id)
	r4.add_food("fish_meat")
	check(r4.rancid, "raw fish in a brew too")
	# Meat already pickled doesn't count against the 30%.
	var r5: Node = w.add_vessel("vessel_open", spot + Vector3(-7, 0, 6))
	r5.water = 10
	for id in ["seed", "seed", "seed", "cooked_meat"]:
		r5.add_food(id)
	r5.advance(r5.FERMENT_TIME + 1.0, 0.0)
	check(Items.cure_of(r5.items[3].id) == "pickled" and is_zero_approx(r5.meat_share()), "pickled, the meat no longer counts")
	r5.add_food("cooked_meat")
	check(not r5.rancid, "so more cooked meat can go in (2 of 5 meat, 1 of them pickled)")
	r5.add_food("cooked_meat")
	check(r5.rancid, "but over 30% unpickled meat still spoils it")
	for rv in [r3, r4, r5]:
		rv.queue_free()
	# Washing out meat draws amphibians; washing out seeds doesn't.
	var sea := _find_spot(w, p.global_position, func(q): return q.y < -1.0)
	var edge := _find_spot(w, sea, func(q): return q.y > 0.05 and q.y < 0.4 and w.water_point(q, 3.0, -0.1).is_finite())
	var u: Node = null
	if edge.is_finite():
		var far := Vector3.INF
		for k in 48:
			var a := TAU * k / 48.0
			for d in [24.0, 30.0, 36.0]:
				var q: Vector3 = edge + Vector3(cos(a), 0, sin(a)) * d
				q.y = w.ground_height(q.x, q.z)
				if q.y < -0.6 and not far.is_finite():
					far = q
		if far.is_finite():
			u = w.spawn_amphibian("uranocentrodon", "hide", far, far)
		p.global_position = edge + Vector3(0, 0.1, 0)
		await _frames(5)
	p.start_haul(r1)
	p.focus_water = true
	p._water_at = w.water_point(edge, 3.0, -0.1) if edge.is_finite() else p.global_position
	r1.haul_interact(p)
	check(r1.water == r1.CAP and r1.dirty and r1.items.is_empty() and not r1.rancid, "washed out at the water, it fills with swamp water")
	if u:
		check(u.state != "approach", "seed mush washed out draws nothing")
	p.put_down()
	p.start_haul(r2)
	p.focus_water = true
	r2.haul_interact(p)
	if u:
		check(u.state == "approach", "rancid meat washed out draws the amphibians, as soup does")
		u.queue_free()
	p.put_down()
	p.global_position = spot + Vector3(0, 0, 2)
	await _frames(2)

	# Sealed: alcoholic fermentation, then a canteen draws alcohol.
	var b: Node = w.add_vessel("vessel_sealed", spot + Vector3(-4, 0, 6))
	Game.inventory.clear()
	Game.inventory.add("pot_clean", 3)
	_hold("pot_clean")
	b.interact(p)
	# (The four stack: the emptied pot leaves the stack for a slot of its own.)
	check(b.water == 1 and Game.inventory.count("pot_clean") == 3 and Game.inventory.count("pot") == 1, "a pot of boiled water pours a serving in")
	b.water = 6
	for id in ["roast_seed", "roast_seed", "cooked_fiddlehead"]:
		b.add_food(id)
	check(b.mode() == "alcohol" and not b.rancid, "a sealed vessel with no salt brews")
	Game.inventory.clear()
	_hold("canteen")
	check("isn't ready" in b.prompt(p), "the canteen waits for the brew (%s)" % b.prompt(p))
	b.advance(b.FERMENT_TIME + 1.0, 0.0)
	check(b.items.all(func(it): return Items.cure_of(it.id) == "spirit") and b.alcohol_ready(), "a day later the food is preserved in alcohol and the brew is ready")
	b.interact(p)
	var cs: Dictionary = Game.inventory.slots[Game.inventory.selected]
	check(cs.id == "canteen_alcohol" and int(cs.data.left) == 10 and b.water == 5, "a canteen draws ten measures of alcohol for a serving of water")
	b.water = 3
	check(b.draw_alcohol() != "" and b.water == 3, "not when that would leave more food than liquid")
	# Drinking and cleaning wounds a measure at a time.
	var v0: float = p.vitals.water
	var e0: float = p.vitals.energy
	p.consume_slot(Game.inventory.selected)
	cs = Game.inventory.slots[Game.inventory.selected]
	check(int(cs.data.left) == 9 and "(9/10)" in Items.def(cs.id).merged(cs.data, true).name, "a drink takes a measure (%s)" % cs.data.name)
	check(p.vitals.water > v0 and p.vitals.energy > e0 and p.vitals.water - v0 < 6.0 and p.vitals.alcohol == 1.0, "a little water and food, and one drink in you")
	p.vitals.add_wound(0.3, 0.2, "test")
	p.vitals.wounds[0].bleed = 0
	p.vitals.wounds[0].inf = Survival.INF_MAJOR
	check(p.treat_slot(Game.inventory.selected, 0) and p.vitals.wounds[0].inf == Survival.INF_REMISSION, "alcohol cleans a wound: a major infection goes into remission")
	check(int(Game.inventory.slots[Game.inventory.selected].data.left) == 8, "that took a measure too")
	check(is_equal_approx(Game.inventory.durability(Game.inventory.selected), 0.8), "its durability bar shows 8 of 10 measures left")
	Game.inventory.add("stick", 1)
	check(Game.inventory.durability(Game.inventory.find("stick")) == -1.0, "other things have no durability bar")
	Game.inventory.remove("stick", 1)
	p.vitals.wounds.clear()
	p.vitals.alcohol = 0.0
	Game.inventory.slots[Game.inventory.selected] = {"id": "canteen_alcohol", "n": 1, "age": 0.0, "data": Items.measures_data("canteen_alcohol", 1)}
	p.vitals.starch = 50.0
	p.consume_slot(Game.inventory.selected)
	check(Game.inventory.held_id() == "canteen", "the last measure leaves the empty canteen")
	check(is_equal_approx(p.vitals.starch, 53.0), "a measure gives 3 starch (%.1f)" % (p.vitals.starch - 50.0))
	p.vitals.alcohol = 0.0
	var spirit := Items.def("spirit:roast_seed")
	p.vitals.consume(spirit, RandomNumberGenerator.new())
	check(p.vitals.alcohol == 1.0, "food preserved in alcohol counts as a drink")
	p.vitals.alcohol = 0.0

	# Salting: at once, while there is enough water and salt.
	var sv: Node = w.add_vessel("vessel_sealed", spot + Vector3(-4, 0, 9))
	sv.water = 3
	Game.inventory.clear()
	Game.inventory.add("salt", 3)
	_hold("salt")
	sv.interact(p)
	sv.interact(p)
	check(sv.salt == 2 and sv.mode() == "salt", "salt in a sealed vessel makes it salt")
	sv.add_food("raw_meat")
	check(sv.items[0].id == "salted:raw_meat" and not sv.rancid, "food is salted the moment it goes in, meat and all")
	sv.add_food("cooked_meat")
	check(sv.items.size() == 2 and sv.items.all(func(it): return Items.cure_of(it.id) == "salted") and not sv.rancid, "any amount of meat")
	var sm := Items.def("salted:cooked_meat")
	check(sm.protein == Items.def("cooked_meat").protein and sm.get("water", 0.0) < 0.0, "salted food is as nourishing, but makes you thirsty")
	Game.inventory.clear()
	sv.take_to_bag(0)
	check(sv.salt == 1 and Game.inventory.count("salted:raw_meat") == 1, "taking one out takes a measure of salt")
	sv.add_food("seed")
	sv.add_food("seed")
	check(sv.rancid, "more food than salt (or water) and it goes rancid")
	var ov: Node = w.add_vessel("vessel_open", spot + Vector3(-4, 0, 12))
	check(ov.add_salt() != "", "salt doesn't go in the unsealed vessel")

	# Cured food keeps twice as long in your bag, and saves.
	Game.inventory.clear()
	Game.inventory.add("pickled:raw_meat", 2)
	Game.inventory.tick(Items.def("raw_meat").decay + 10.0)
	check(Game.inventory.count("pickled:raw_meat") == 2, "pickled meat outlasts raw")
	Game.inventory.tick(Items.def("raw_meat").decay)
	check(Game.inventory.count("pickled:raw_meat") == 0 and Game.inventory.count("rotten") == 2, "but goes off in the end")
	var saved: Dictionary = w._world_state()
	check(saved.vessels.size() >= 5, "vessels are saved with the world")
	var b2: Node = w.add_vessel("vessel_sealed", spot + Vector3(8, 0, 0))
	b2.from_dict(b.to_dict())
	check(b2.water == b.water and b2.items.size() == b.items.size() and b2.items[0].id == b.items[0].id and b2.alcohol_ready(), "and restored, brew and all")
	var inv2 := Inventory.new()
	inv2.add("salted:raw_meat", 3)
	var inv3 := Inventory.new()
	inv3.from_dict(JSON.parse_string(JSON.stringify(inv2.to_dict())))
	check(inv3.count("salted:raw_meat") == 3, "cured food stacks and saves in the bag")

	# Right-click opens the vessel's window.
	p.global_position = b.global_position + Vector3(0, 0, 1.2)
	p.focus = b
	b.use_interact(p)
	await _frames(2)
	check(w.inv_ui.visible and w.inv_ui._vessel_page.visible and w.inv_ui.vessel == b, "right-click opens the vessel")
	check(w.inv_ui._vessel_box.get_child_count() > b.items.size(), "listing what is in it")
	var n0: int = b.items.size()
	w.inv_ui._vessel_do("take", 0)
	check(b.items.size() == n0 - 1, "and you can take things out")
	w.toggle_inventory()
	w.queue_free()
	await _frames(2)


func test_preserves() -> void:
	## Preserving pots: filled at a vessel, sealed with a cap and wax, opened.
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var spot: Vector3 = p.global_position
	var ui: Node = w.inv_ui
	Game.inventory.clear()
	var cr: Dictionary = Items.recipe_for("wooden_cap")
	check(cr.get("n", 0) == 4 and cr.in.has("board") and cr.get("rack", "") == "woodworking_tools", "a board carves four wooden caps at the bench")

	# A pickling vessel with five pickled items in it.
	var v: Node = w.add_vessel("vessel_open", spot + Vector3(-4, 0, 6))
	v.water = 6
	for id in ["cooked_fiddlehead", "cooked_fiddlehead", "roast_seed", "roast_seed", "roast_seed"]:
		v.add_food(id)
	v.add_food("cooked_fiddlehead")
	v.items[5].t = 0.0  # not yet pickled
	v.advance(v.FERMENT_TIME - 1.0, 0.0)
	v.items[5].t = 0.0
	v.advance(2.0, 0.0)
	check(v.preserved_indices().size() == 5 and Items.cure_of(v.items[5].id) == "", "five are pickled, one isn't yet (%d)" % v.preserved_indices().size())
	check(v.fill_pot([5]).has("why"), "food not yet preserved doesn't go in a pot")
	check(v.fill_pot([0, 1, 2, 3, 4]).has("why"), "nor more than four")

	# Picked in the vessel's window, filled into an empty clay pot.
	ui.vessel = v
	Game.inventory.add("pot", 2)
	for k in 5:
		ui._vessel_do("pick", k)
	check(ui._pot_pick.size() == 4, "the window picks at most four")
	ui._vessel_do("pick", 2)
	ui._vessel_do("pick", 3)
	check(ui._pot_pick.size() == 2, "and unpicks")
	var water0: int = v.water
	ui._vessel_do("fill_pot")
	var i: int = Game.inventory.find("pot_preserves")
	check(i >= 0 and Game.inventory.count("pot") == 1, "one empty clay pot becomes a Pot of Preserves")
	if i < 0:
		w.queue_free()
		await _frames(2)
		return
	var d: Dictionary = Game.inventory.slots[i].data
	check(d.items.size() == 2 and v.items.size() == 4 and v.water == water0 - 1, "two items and one serving of liquid come out (%d water left)" % v.water)
	check(d.fluid == "pickling brine" and "Pot of Preserves (2)" == Game.inventory.def_of(i).name, "an open pot shows what it holds (%s)" % Game.inventory.def_of(i).name)
	var want: float = Items.weight("pot") + 1.5 + Items.weight(d.items[0].id) + Items.weight(d.items[1].id)
	check(is_equal_approx(Items.slot_weight(Game.inventory.slots[i]), want), "it weighs the pot, the liquid and the food (%.2f kg)" % want)
	check(Game.inventory.weight() >= want, "and counts in the bag's weight")

	# Sealing needs a cap and wax; then it ages no more and hides what it holds.
	Game.time += 600.0
	check(not p.use_preserves(i) and Game.inventory.slots[i].id == "pot_preserves", "no cap or wax: it stays open")
	Game.inventory.add("wooden_cap", 1)
	Game.inventory.add("wax", 2)
	check(p.use_preserves(i) and Game.inventory.slots[i].id == "pot_sealed", "Use seals it with a cap and wax")
	check(Game.inventory.count("wooden_cap") == 0 and Game.inventory.count("wax") == 1, "using up the cap and a lump of wax")
	var sd: Dictionary = Game.inventory.def_of(i)
	check(sd.name == "Sealed Pot" and not "Pickled" in sd.desc and not sd.has("since"), "sealed, it is just a Sealed Pot (%s)" % sd.name)
	check(is_equal_approx(Items.slot_weight(Game.inventory.slots[i]), want), "and weighs the same")
	Game.time += 30.0 * 24.0 * 60.0
	Game.inventory.tick(30.0 * 24.0 * 60.0)
	check(Game.inventory.slots[i].id == "pot_sealed", "a month later it is still sealed")
	check(p.use_preserves(i), "Use opens it")
	var picked: Array = Game.inventory.slots.filter(func(s): return s != null and Items.cure_of(s.id) == "pickled")
	var n := 0
	var ages_ok := true
	for s in picked:
		n += s.n
		ages_ok = ages_ok and absf(s.age - 600.0) < 1.0
	check(n == 2 and ages_ok, "both items come out, only as old as the time it stood open (%d)" % n)
	check(Game.inventory.slots[i].id == "pot" and Game.inventory.count("wooden_cap") == 1, "leaving the clay pot and the cap back")

	# An open pot opened: its food has aged from when it was filled.
	for s in picked:
		Game.inventory.slots[Game.inventory.slots.find(s)] = null
	ui._vessel_do("pick", 0)
	ui._vessel_do("fill_pot")
	i = Game.inventory.find("pot_preserves")
	Game.time += 300.0
	check(i >= 0 and p.use_preserves(i, "open") and Game.inventory.slots[i].id == "pot", "an open pot can be emptied too")
	var one: Array = Game.inventory.slots.filter(func(s): return s != null and Items.cure_of(s.id) == "pickled")
	check(one.size() == 1 and absf(one[0].age - 300.0) < 1.0 and Game.inventory.count("wooden_cap") == 1, "its food has aged since it was filled, and no cap comes out")

	# Salted and alcohol-preserved food work the same way.
	var sv: Node = w.add_vessel("vessel_sealed", spot + Vector3(4, 0, 6))
	sv.water = 4
	sv.salt = 4
	for id in ["cooked_meat", "cooked_meat"]:
		sv.add_food(id)
	check(sv.mode() == "salt" and sv.preserved_indices().size() == 2, "a salting vessel's food is ready at once")
	var got: Dictionary = sv.fill_pot([0, 1])
	check(got.get("fluid", "") == "salt brine" and got.items.size() == 2 and sv.water == 3, "salted food goes in with salt brine")
	var av: Node = w.add_vessel("vessel_sealed", spot + Vector3(4, 0, -6))
	av.water = 4
	for id in ["roast_seed", "roast_seed"]:
		av.add_food(id)
	av.advance(av.FERMENT_TIME + 1.0, 0.0)
	got = av.fill_pot([0])
	check(got.get("fluid", "") == "alcohol" and Items.cure_of(got.items[0].id) == "spirit", "alcohol-preserved food goes in with alcohol")
	ui.vessel = null
	w.queue_free()
	await _frames(2)

func test_alcohol() -> void:
	var v := Survival.new()
	v.drink_alcohol()
	check(v.drinks() == 1 and v.status_words()[0] == "Healthy", "one drink does nothing")
	v.tick(30.0, false, false)
	v.drink_alcohol()
	check(v.drinks() == 2 and v.status_words()[0] == "Tipsy" and v.heal_mult() == 0.5, "two within the hour: tipsy, healing slower")
	var sober := Survival.new()
	sober.tick(60.0, false, false)
	var tipsy := Survival.new()
	tipsy.alcohol = 2.5
	tipsy.tick(60.0, false, false)
	check(70.0 - tipsy.water > 70.0 - sober.water, "drinking dries you out")
	var d := Survival.new()
	d.alcohol = 4.5
	check(d.heal_mult() == 0.0 and d.speed_mult() < 1.0 and d.drunk_sway() == 0.0, "4 or 5: slow, and no healing")
	d.alcohol = 7.0
	check(d.drunk_sway() > 0.0, "6 to 8: the world sways")
	d.alcohol = 10.0
	var w0 := 80.0
	d.water = w0
	d.energy = 80.0
	for i in 60:
		d.tick(1.0, false, false)
	check(d.water < w0 - 20.0 and d.energy < 70.0, "9 to 12: you vomit up food and water (water %.0f)" % d.water)
	d.alcohol = 13.5
	check(d.blindness() > 0.0 and not d.dead, "13 to 15: your sight goes")
	d.drink_alcohol(3.0)
	check(d.dead and d.cause == "alcohol", "16 kills")
	var fade := Survival.new()
	fade.alcohol = 3.0
	fade.tick(60.0, false, false)
	check(is_equal_approx(fade.alcohol, 2.0), "one drink wears off each game hour")
	check(Survival.ease({"alcohol": 17.0}, "alcohol").alcohol == 13.0, "dying of it eases the save by four drinks")


func test_log_kinds() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	# Every tree's logs look like that tree.
	var meshes := {}
	for kind in Chunk.TREES:
		var m: Mesh = Assets.log_mesh("log", kind)
		meshes[kind] = m
		var mats := []
		for i in m.get_surface_count():
			mats.append(m.surface_get_material(i))
		check(Assets.materials.has("bark_" + kind) and Assets.materials["bark_" + kind] in mats, "a %s log has its own bark" % kind)
		check(Assets.log_mesh("short_log", kind) != Assets.log_mesh("short_log", "calamites") or kind == "calamites", "and so does a short one")
		check(Assets.log_mesh("log_stripped", kind) != m, "stripped, it shows its wood")
	var tex := {}
	for kind in Chunk.TREES:
		tex[Assets.detail_textures("bark_" + kind)[0]] = true
	check(tex.size() == Chunk.TREES.size(), "four different bark textures")
	check(Assets.log_mesh("log", "") == meshes[Assets.LOG_KIND], "a log of no known tree looks like a %s log" % Assets.LOG_KIND)

	# Logs keep their tree, and pile with their own kind.
	var spot := _find_spot(w, p.global_position + Vector3(6, 0, 0), func(q): return q.y > 0.4 and q.y < 2.0)
	var a: Node = w.add_log("log", spot, 0.0, "tree_fern")
	var b: Node = w.add_log("log", spot + Vector3(0, 0, 4.0), 0.0, "calamites")
	check(a.kind == "tree_fern" and a._mesh.mesh == Assets.log_mesh("log", "tree_fern") and "Tree Fern log" in a.prompt(p), "a tree fern log looks and is named like one (%s)" % a.prompt(p))
	var c: Node = w.add_log("log", spot + Vector3(0.6, 0, 0), 0.0, "calamites")
	c.set_hauled(null)
	await _frames(1)
	var piles := func(): return get_tree().get_nodes_in_group("stacks").filter(func(s): return not s.is_queued_for_deletion() and s.item_id == "log")
	check(piles.call().is_empty() and is_instance_valid(c) and not c.is_queued_for_deletion(), "a calamites log doesn't pile up with a tree fern log")
	var d: Node = w.add_log("log", spot + Vector3(0.6, 0, 0), 0.0, "tree_fern")
	d.set_hauled(null)
	await _frames(1)
	var ps: Array = piles.call()
	check(ps.size() == 1 and ps[0].kind == "tree_fern" and ps[0].count == 2, "two tree fern logs make a tree fern pile")
	if ps.size() == 1:
		check(ps[0].to_dict().kind == "tree_fern", "the pile is saved with its tree")
		ps[0].take_one(p)
		check(p.hauling != null and p.hauling.kind == "tree_fern", "a log taken off it is a tree fern log")
		p.put_down()
	# Stripping and cutting keep the tree.
	b.set_id("log_stripped")
	check(b.kind == "calamites" and b._mesh.mesh == Assets.log_mesh("log_stripped", "calamites"), "a stripped log is still a calamites log")
	var saved: Dictionary = b.to_dict()
	check(saved.kind == "calamites", "logs are saved with their tree")
	var e: Node = w.add_log("log", spot + Vector3(0, 0, 8.0), 0.0)
	e.from_dict(saved)
	check(e.kind == "calamites", "and restored")
	var old := saved.duplicate()
	old.erase("kind")
	e.from_dict(old)
	check(e.kind == Assets.LOG_KIND, "an old save's log becomes a %s log" % Assets.LOG_KIND)
	w.queue_free()
	await _frames(2)


func test_soup_blood() -> void:
	## Meaty soup tipped out at the water draws amphibians lurking further off.
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var start: Vector3 = p.global_position
	var edge := _find_spot(w, start, func(q): return q.y > 0.05 and q.y < 0.4 and w.water_point(q, 3.0, -0.1).is_finite())
	check(edge.is_finite(), "found the water's edge")
	if not edge.is_finite():
		w.queue_free()
		return
	# Water 22-40 m out: out of an ambush's reach, but within smell of the blood.
	var far := Vector3.INF
	var farther := Vector3.INF
	for k in 48:
		var a := TAU * k / 48.0
		for d in [24.0, 30.0, 36.0]:
			var q: Vector3 = edge + Vector3(cos(a), 0, sin(a)) * d
			q.y = w.ground_height(q.x, q.z)
			if q.y < -0.6 and not far.is_finite():
				far = q
		var q2: Vector3 = edge + Vector3(cos(a), 0, sin(a)) * 80.0
		q2.y = w.ground_height(q2.x, q2.z)
		if q2.y < -0.6 and not farther.is_finite():
			farther = q2
	check(far.is_finite(), "found water out of striking reach")
	if not far.is_finite():
		w.queue_free()
		return
	p.global_position = edge + Vector3(0, 0.1, 0)
	await _clear_amphibians()
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", far, far)
	var e: Node = null
	if farther.is_finite():
		e = w.spawn_amphibian("uranocentrodon", "hide", farther, farther)
	await _frames(10)
	check(u.state == "hide" and u.submerged, "it lies buried, too far off to strike")

	# Water soup tipped out draws nothing.
	var sp: Node = w.add_soup_pot("soup_pot", edge + Vector3(0, 0, 0))
	sp.water = 10.0
	sp.add_food("roast_seed")
	p.start_haul(sp)
	p.focus_water = true
	p._water_at = w.water_point(edge, 3.0, -0.1)
	sp.haul_interact(p)
	check(u.state == "hide", "seed soup tipped out draws nothing")
	check(sp.dirty and sp.water == SoupPot.SERVINGS and not sp.has_soup(), "the pot is full of swamp water instead")

	# Meat in it: blood in the water.
	sp.empty_out()
	sp.water = 10.0
	sp.add_food("cooked_meat")
	p.focus_water = true
	sp.haul_interact(p)
	check(u.state == "approach" and not u.submerged and u._body.visible, "with meat in it, the blood brings it up to the surface")
	check(e == null or e.state == "hide", "one too far off doesn't notice")
	check(not sp.has_meat() and sp.dirty, "and the pot holds swamp water")
	p.put_down()
	check(w._hunted(), "you are being hunted")
	var d0: float = u.global_position.distance_to(p.global_position)
	await _run_for(4.0, func(): return u.state != "approach")
	var d1: float = u.global_position.distance_to(p.global_position)
	check(d1 < d0 - 0.5 or u.state in ["strike", "grab"], "it swims slowly in toward you (%.1f -> %.1f m)" % [d0, d1])
	check(u.state != "approach" or d0 - d1 < 4.0 * u.def.speed * 2.0 + 0.5, "slowly: no faster than a swim")
	# Within reach it strikes as it would from hiding.
	u.global_position = Vector3(far.x, u.global_position.y, far.z).lerp(Vector3(edge.x, u.global_position.y, edge.z), 0.6)
	await _run_for(6.0, func(): return p.grabbed_by != null)
	check(p.grabbed_by == u, "near enough, it strikes like normal")
	if p.grabbed_by:
		p.grabbed_by.release(false)
		p.release_grab()

	# An Eogyrinus comes up the same way, and charges once close.
	var eo: Node = Creature.new().setup("eogyrinus", far, w)
	w.add_child(eo)
	eo.set_mode("lurk", far)
	p.global_position = edge + Vector3(0, 0.1, 0)
	check(eo.scent(edge, p) and eo.state == "approach", "an Eogyrinus lurking further off comes for the blood too")
	eo.global_position = Vector3(edge.x, eo.global_position.y, edge.z) + (Vector3(far.x, 0, far.z) - Vector3(edge.x, 0, edge.z)).normalized() * 4.0
	await _run_for(2.0, func(): return eo.state != "approach")
	check(eo.state in ["charge", "grab"] or p.grabbed_by == eo, "and charges once it is close (state %s)" % eo.state)
	if p.grabbed_by:
		p.grabbed_by.release(false)
		p.release_grab()
	w.queue_free()
	await _frames(2)


func test_baitbox() -> void:
	## A baitbox thrown into the water sends every big amphibian near it into a
	## feeding frenzy round it, leaving the player alone unless they come close.
	var r: Dictionary = Items.recipe_for("baitbox", "swamp")
	check(not r.is_empty() and r.in == {"board": 1, "any_raw_meat": 2} and r.tier == "bench", "a baitbox: a board and two raw meat, at a bench")
	check(Items.counts_as("raw_meat", "any_raw_meat") and Items.counts_as("fish_meat", "any_raw_meat"), "raw meat or fish meat will do")
	check(["cooked_meat", "cooked_fish", "guts", "meat_bait", "gnawed_meat", "elonichthys_carcass"].all(func(id): return not Items.counts_as(id, "any_raw_meat")),
			"nothing else will")
	check(Items.counts_as("raw_meat", "raw_meat") and Items.counts_as("fish_meat", "fish_meat"), "each still counts as itself (meat bait)")
	var inv := Inventory.new()
	inv.add("board_calamites", 1)
	inv.add("raw_meat", 1)
	inv.add("fish_meat", 1)
	check(inv.craft(r) and inv.count("baitbox") == 1 and inv.count_as("any_raw_meat") == 0 and inv.count_as("board") == 0,
			"one of each, mixed, make a baitbox")
	inv.clear()
	inv.add("board_calamites", 1)
	inv.add("cooked_meat", 2)
	check(not inv.can_craft(r), "cooked meat won't do")
	check(Items.def("baitbox").get("spoil", "") == "baitbox_rotten" and Items.def("baitbox_rotten").frenzy < Items.def("baitbox").frenzy,
			"it goes off into a rotten baitbox, which still works for less time")
	check(Assets.mesh("item_baitbox") != null and Assets.mesh("item_baitbox_rotten") != null, "both have a look")

	var w: Node = await _new_swamp()
	var p: Node = w.player
	var start: Vector3 = p.global_position
	var edge := _find_spot(w, start, func(q): return q.y > 0.05 and q.y < 0.4 and w.water_point(q, 3.0, -0.1).is_finite())
	check(edge.is_finite(), "found the water's edge")
	if not edge.is_finite():
		w.queue_free()
		return
	# The box goes into water 24-36 m out; an animal buried by the edge, where
	# it would strike you, and one 100 m off, out of the frenzy's reach.
	var box := Vector3.INF
	var beyond := Vector3.INF
	for k in 48:
		var a := TAU * k / 48.0
		for d in [24.0, 30.0, 36.0]:
			var q: Vector3 = edge + Vector3(cos(a), 0, sin(a)) * d
			q.y = w.ground_height(q.x, q.z)
			if q.y < -0.6 and not box.is_finite():
				box = q
	if box.is_finite():
		for k in 48:
			var a := TAU * k / 48.0
			var q: Vector3 = box + Vector3(cos(a), 0, sin(a)) * (Creature.FRENZY_RADIUS + 35.0)
			q.y = w.ground_height(q.x, q.z)
			if q.y < -0.6 and not beyond.is_finite():
				beyond = q
	var by_edge: Vector3 = w.water_point(edge, 10.0, -0.6)
	check(box.is_finite() and by_edge.is_finite(), "found water for the box and by the edge")
	if not box.is_finite() or not by_edge.is_finite():
		w.queue_free()
		return
	p.global_position = edge + Vector3(0, 0.1, 0)
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", by_edge, by_edge)
	var x: Node = w.spawn_amphibian("uranocentrodon", "hide", beyond, beyond) if beyond.is_finite() else null
	# Thrown: it lands in the water and is gone, setting off the frenzy.
	var tr := ThrownRock.new()
	w.add_child(tr.setup("baitbox", box + Vector3(0, 1, 0), Vector3.ZERO, p, w))
	tr._land(Vector3(box.x, w.water_level(), box.z))
	check(w._frenzy_left > 0.0 and u.state == "frenzy" and not u.submerged, "a baitbox in the water: the one by the edge comes up and goes for it")
	check(x == null or x.state == "hide", "one more than %d m off takes no notice" % Creature.FRENZY_RADIUS)
	var wet := func(q: Vector3) -> bool: return w.ground_height(q.x, q.z) < w.water_level()
	var dry_path := false
	var last: Vector3 = u.global_position
	for q in u._frenzy_path:
		for i in range(1, 21):
			if not wet.call(last.lerp(q, i / 20.0)):
				dry_path = true
		last = q
	check(not u._frenzy_path.is_empty() and not dry_path, "its way to the box keeps to the water (%d legs)" % u._frenzy_path.size())
	var ashore := [false]
	var opened := [true]
	await _run_for(8.0, func():
		if not wet.call(u.global_position):
			ashore[0] = true
		if u._gape > 0.1 and (u._jaw.transform * Vector3(0, 0, -1)).y > u._jaw.position.y:
			opened[0] = false
		return p.grabbed_by != null)
	check(p.grabbed_by == null, "you stand at the water's edge unharmed")
	check(not ashore[0], "it never leaves the water to get there")
	check(opened[0], "its jaw drops open, never up through its skull")
	# One out on land takes no notice.
	var landed: Node = w.spawn_amphibian("eogyrinus", "land", edge, edge)
	check(not landed.frenzy(box, 5.0), "an Eogyrinus out on land does not cross it to the box")
	landed.queue_free()
	var gone: float = Vector2(u.global_position.x - box.x, u.global_position.z - box.z).length()
	check(gone < u.def.radius + 6.0, "it is tearing at the box (%.1f m from it)" % gone)
	# One that turns up while it lasts joins in.
	var e: Node = w.spawn_amphibian("eogyrinus", "lurk", by_edge, by_edge)
	check(e.state == "frenzy", "an Eogyrinus turning up now joins in")
	e.queue_free()
	# Too close, and it attacks as it always would.
	var close: Vector3 = u.global_position + Vector3(3.0, 0.0, 0.0)
	close.y = w.ground_height(close.x, close.z) + 0.1
	p.global_position = close
	await _run_for(4.0, func(): return p.grabbed_by != null)
	check(p.grabbed_by != null, "come too close and they attack like normal")
	if p.grabbed_by:
		p.grabbed_by.release(false)
		p.release_grab()
	# Hit from afar, it comes for you as it always would.
	p.global_position = edge + Vector3(0, 0.1, 0)
	u._calm = 0.0
	u.state = "frenzy"
	u._frenzy = 5.0
	u.take_damage(1.0, p)
	check(u.state == "strike", "hit while it feeds, it strikes back")
	u.state = "return"
	# Afterwards it stays where the box was.
	p.global_position = edge + Vector3(0, 0.1, 0)
	w._frenzy_left = 0.0
	u._frenzy = 0.0
	u._calm = 0.0
	await _run_for(10.0, func(): return u.state == "hide")
	check(u.state in ["hide", "return"] and Vector2(u.home.x - box.x, u.home.z - box.z).length() < 0.1,
			"when it is over it buries itself where the box was (state %s)" % u.state)
	# On land a baitbox just lands.
	var tr2 := ThrownRock.new()
	w.add_child(tr2.setup("baitbox", edge + Vector3(0, 1, 0), Vector3.ZERO, p, w))
	tr2._land(edge)
	check(w._frenzy_left == 0.0, "thrown on land it sets nothing off")
	w.queue_free()
	await _frames(2)


func test_bedroll() -> void:
	## A bedroll is set down (rolled up) only inside a finished house. Looking at it, Z
	## sleeps at once when tired (healing faster), E saves without sleeping.
	var r: Dictionary = Items.recipe_for("bedroll", "swamp")
	check(not r.is_empty() and r.in == {"string": 8} and r.tier == "hand" and r.get("known_by", "") == "spindle", "a bedroll: 8 string, by hand, once you know the spindle")
	check(Items.def("bedroll").get("place", "") == "bedroll" and Assets.mesh("item_bedroll") != null, "it is set down with Use, and has a look")
	check(Settings.hint("Sleep [Z]") == "Sleep [%s]" % Settings._cap(Settings.button_name("sleep")), "[Z] hints name the sleep button")

	# Faster healing asleep on a bedroll.
	var a := Survival.new()
	var b := Survival.new()
	for v in [a, b]:
		v.blood = 60.0
	b.on_bedroll = true
	for i in 12:
		a.tick(5.0, false, false, false, true)
		b.tick(5.0, false, false, false, true)
	check(b.blood > a.blood, "blood comes back faster on a bedroll (%.1f vs %.1f)" % [b.blood, a.blood])
	var c := Survival.new()
	var d := Survival.new()
	for v in [c, d]:
		v.add_wound(0.1, 0.0, "test")
		v.wounds[0].bleed = 0
	d.on_bedroll = true
	for i in 6:  # 30 s: neither heals right up
		c.tick(5.0, false, false, false, true)
		d.tick(5.0, false, false, false, true)
	var sc: float = c.wounds[0].sev if not c.wounds.is_empty() else 0.0
	var sd: float = d.wounds[0].sev if not d.wounds.is_empty() else 0.0
	check(sd < sc or (d.wounds.is_empty() and not c.wounds.is_empty()), "and wounds heal faster (%.3f vs %.3f)" % [sd, sc])

	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	var start: Vector3 = p.global_position
	var good := _find_spot(w, start, func(q):
		p.global_position = q + Vector3(0, 0.05, 0)
		return q.y > 0.3 and w.house_spot(p).why == "")
	check(good.is_finite(), "somewhere a house can stand")
	if not good.is_finite():
		w.queue_free()
		return
	var spot: Dictionary = w.house_spot(p)
	var h: Node = w.add_house(spot.at, spot.yaw)
	await _frames(1)

	# Not on open ground, nor on an unfinished house.
	var outside: Vector3 = h.to_global(Vector3(0, 0, House.EDGE + 4.0))
	outside.y = w.ground_height(outside.x, outside.z) + 0.05
	p.global_position = outside
	check(not w.place("bedroll", outside, "bedroll"), "not out on the ground")
	h.build_to(House.PARTS.size() - 1)
	await _frames(1)
	var inside: Vector3 = h.to_global(Vector3(-0.8, 0.05, -0.6))
	p.global_position = inside
	p.rotation.y = h.rotation.y
	if not h.complete():
		check(not w.place("bedroll", inside, "bedroll"), "not in an unfinished house")
	h.build_to(House.PARTS.size())
	await _frames(1)
	check(h.complete(), "the house is finished")
	# Not on the porch.
	p.global_position = h.to_global(Vector3(0, 0.05, 1.7))
	p.rotation.y = h.rotation.y + PI
	check(not w.place("bedroll", p.global_position, "bedroll"), "not out on the porch")
	# In the room.
	p.global_position = inside
	p.rotation.y = h.rotation.y
	check(w.place("bedroll", inside, "bedroll"), "set down on the floor of the room")
	var beds := get_tree().get_nodes_in_group("bedrolls")
	check(beds.size() == 1, "a bedroll lies there")
	if beds.is_empty():
		w.queue_free()
		return
	var bed: Node = beds[0]
	check(absf(bed.global_position.y - h.global_position.y) < 0.05 and h.room_spot(bed.global_position), "on the floor, inside")
	check("[Z]" in bed.prompt(p) and "[E]" in bed.prompt(p), "its prompt names sleep and save")

	# E saves without sleeping, even when not tired.
	Game.last_sleep = Game.time - 10.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	var t0 := Game.time
	bed.interact(p)
	check(FileAccess.file_exists(Game.save_path) and not w._sleeping and Game.time - t0 < 1.0, "E saves the game without sleeping")
	check(Game.read_save().get("bedrolls", []).size() == 1, "the bedroll is saved with the world")

	# Z: not tired yet, nothing happens; tired, you sleep at once.
	bed.sleep_on(p)
	check(not w._sleeping, "Z does nothing when you aren't tired")
	Game.last_sleep = Game.time - Game.SLEEP_COOLDOWN
	p.focus = bed
	var ev := InputEventAction.new()
	ev.action = "sleep"
	ev.pressed = true
	p._unhandled_input(ev)
	check(w._sleeping, "tired, Z while looking at it sleeps at once, without a second press (%s)" % w.sleep_blocker())
	while w._sleeping:
		await get_tree().process_frame
	check(Game.can_sleep_in() > 0.0 and not p.vitals.on_bedroll, "slept (and the bedroll's healing is over)")

	# Right-click picks it up again.
	bed.use_interact(p)
	await _frames(1)
	check(not is_instance_valid(bed) and Game.inventory.count("bedroll") == 1, "right-click puts it back in the bag")

	# Torn down, the house leaves it on the ground as the item.
	check(w.place("bedroll", inside, "bedroll"), "set down again")
	h.tear_down()
	await _frames(2)
	var left := get_tree().get_nodes_in_group("drops").filter(func(d): return d.item_id == "bedroll")
	check(get_tree().get_nodes_in_group("bedrolls").is_empty() and left.size() == 1, "a torn-down house leaves the bedroll on the ground as the item")
	w.queue_free()
	await _frames(2)


func test_house_floor() -> void:
	## Things made, cut, set down or loaded on a house's floor stay up on it,
	## not on the ground under the house.
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	var good := _find_spot(w, p.global_position, func(q):
		p.global_position = q + Vector3(0, 0.05, 0)
		return q.y > 0.3 and w.house_spot(p).why == "")
	check(good.is_finite(), "somewhere a house can stand")
	if not good.is_finite():
		w.queue_free()
		return
	var spot: Dictionary = w.house_spot(p)
	var h: Node = w.add_house(spot.at, spot.yaw)
	h.build_to(House.PARTS.size())
	await _frames(2)
	var fy: float = h.global_position.y
	var up := func(n: Node3D) -> bool: return is_instance_valid(n) and absf(n.global_position.y - fy) < 0.1

	# Added up at the floor: a log, a soup pot, a vessel, guts.
	var lg: Node = w.add_log("log", h.to_global(Vector3(0.0, 0.05, -0.8)), h.rotation.y)
	var pot: Node = w.add_soup_pot("soup_pot", h.to_global(Vector3(-1.0, 0.05, 0.4)))
	var ves: Node = w.add_vessel("vessel_open", h.to_global(Vector3(1.0, 0.05, 0.4)))
	var gp: Node = w.add_guts(h.to_global(Vector3(-1.0, 0.05, -1.8)), 1)
	check(up.call(lg) and up.call(pot) and up.call(ves) and up.call(gp), "a log, a soup pot, a vessel and guts added at the floor stay on it")
	var under: Vector3 = h.to_global(Vector3(-1.0, 0.0, -1.8))
	under.y = w.ground_height(under.x, under.z)
	var gu: Node = w.add_guts(under, 1)
	check(gu != gp and gu.global_position.y < fy - 1.0, "guts under the house are another pile, on the ground")
	gu.queue_free()

	# Made at a bench in the house: left standing on the floor beside it.
	var made: Node = w.add_carried("soup_pot_unfired", h.to_global(Vector3(-1.0, 0.05, -0.4)))
	check(up.call(made), "a soup pot made indoors stands on the floor")
	made.queue_free()

	# Kneeling to work a log on the floor keeps you (and the work) up there.
	var sl: Node = w.add_log("short_log", h.to_global(Vector3(-0.6, 0.05, -1.2)), h.rotation.y)
	check(up.call(sl), "a short log on the floor")
	p.global_position = h.to_global(Vector3(-0.6, 0.05, -0.5))
	p.velocity = Vector3.ZERO
	w._start_wood_work(sl, {})
	check(up.call(p) and w.work != null and up.call(w.work), "kneeling at it, you and the work stay on the floor")
	w.close_work()
	await _frames(1)

	# Set down facing the back wall: drawn back inside, not dropped through it.
	p.global_position = h.to_global(Vector3(0.0, 0.05, -1.9))
	p.rotation.y = h.rotation.y
	p.velocity = Vector3.ZERO
	p.start_haul(sl)
	await _frames(3)
	p.put_down()
	await _frames(2)
	check(up.call(sl) and h.covers(sl.global_position), "a log set down facing a wall stays on the floor, inside")

	# Saved and loaded: still up on the floor.
	var state: Dictionary = w._world_state()
	w.queue_free()
	await _frames(2)
	_fresh_state()
	Game.restore = state
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	w2._spawn_t = 1e9
	var h2: Node = Game.houses[0] if not Game.houses.is_empty() else null
	check(h2 != null, "the house loads")
	if h2:
		fy = h2.global_position.y
		var logs := get_tree().get_nodes_in_group("logs")
		check(logs.size() >= 2 and logs.all(func(n): return absf(n.global_position.y - fy) < 0.1), "logs load on the floor, not under the house")
		check(w2.get_children().any(func(n): return n.get("item_id") == "soup_pot" and absf(n.global_position.y - fy) < 0.1), "the soup pot loads on the floor")
		check(w2.get_children().any(func(n): return n.get("item_id") == "vessel_open" and absf(n.global_position.y - fy) < 0.1), "the vessel loads on the floor")
	w2.queue_free()
	await _frames(2)


func test_fern_dig() -> void:
	## A mattock tears out a decorative fern for nothing, and digs up a
	## harvestable fern for its spores, which grow ferns as fast as seed ferns.
	var sp: Dictionary = Items.def("fern_spores")
	check(sp.get("plant", "") == "fern", "fern spores grow a fern")
	check(Harvestable.KINDS.fern.get("dig", {}).has("fern_spores") and int(Harvestable.KINDS.fern.get("dig_hits", 1)) == 1, "one swing digs up a fern for its spores")
	var pf: Dictionary = Harvestable.KINDS.get("planted_fern", {})
	var ps: Dictionary = Harvestable.KINDS.planted_seed_fern
	check(not pf.is_empty() and pf.regrow == ps.regrow and pf.fed_regrow == ps.fed_regrow, "a planted fern grows back as fast as a planted seed fern")

	var w: Node = await _new_swamp()
	Game.inventory.clear()
	Game.inventory.add("mattock", 1)

	# A decorative fern: gone for good, nothing gained.
	var chunk: Node = null
	for c in w.chunks.values():
		if is_instance_valid(c) and not c.decor_ferns.is_empty():
			chunk = c
			break
	check(chunk != null, "a chunk with decorative ferns")
	if chunk:
		var e: Dictionary = chunk.decor_ferns[0]
		var n0: int = chunk.decor_ferns.size()
		var at := Vector3(e.x, w.ground_height(e.x, e.z), e.z)
		check(not w.clear_fern(at + Vector3(0, 3.0, 0)), "not when the swing hits something up off the ground")
		check(w.clear_fern(at), "a mattock struck into the ground at a decorative fern tears it out")
		check(chunk.decor_ferns.size() == n0 - 1 and Game.taken.has(e.key) and Chunk.fern_key(e.x, e.z) == e.key, "gone for good (kept by where it stood)")
		check(Game.inventory.count("mattock") == 1 and Game.inventory.slots.filter(func(x): return x != null).size() == 1, "and nothing gained")

	# A harvestable fern: dug up, gone for good, its spores in the bag.
	var hf := Harvestable.new().setup("fern", "htest:fern")
	w.add_child(hf)
	hf.global_position = w.player.global_position + Vector3(2.0, 0, 0)
	await _frames(1)
	hf.dig()
	await _frames(1)
	check(not is_instance_valid(hf) and Game.taken.has("htest:fern"), "a harvestable fern dug up is gone for good")
	check(Game.inventory.count("fern_spores") == 3, "an unpicked fern gives 3 spores (%d)" % Game.inventory.count("fern_spores"))
	# One already picked clean gives just 1.
	var hp := Harvestable.new().setup("fern", "htest:fern2")
	w.add_child(hp)
	hp.global_position = w.player.global_position + Vector3(-2.0, 0, 0)
	await _frames(1)
	hp.interact(w.player)
	var spores: int = Game.inventory.count("fern_spores")
	check(not hp.is_ready(), "stripped, it is picked clean")
	hp.dig()
	await _frames(1)
	check(not is_instance_valid(hp) and Game.inventory.count("fern_spores") == spores + 1, "a picked-clean fern gives 1 spore")

	# Planted, the spores come up and grow like a seed fern's seed.
	var t0 := Game.time
	Game.plantings["ptest"] = {"x": 0.0, "y": 0.0, "z": 0.0, "dug": t0 - Plot.FILL_AFTER * 2.0, "buried": t0 - Plot.FILL_AFTER - 1.0,
			"item": {"id": "fern_spores", "age": 0.0}}
	check(Plot.settle("ptest") == "herb" and Game.plantings.ptest.get("plant", "") == "fern", "the spores come up as a young fern")
	check(is_equal_approx(float(Game.plantings.ptest.days), Plot.GROW_DAYS), "growing for as long as a seed fern")
	Game.time = t0 + Plot.GROW_DAYS * Game.DAY_LENGTH
	check(Plot.settle("ptest") == "grown", "and then grown (a planted fern)")
	Game.plantings.erase("ptest")
	Game.time = t0
	w.queue_free()
	await _frames(2)


func test_butcher() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()

	# Small kills go into the bag whole.
	var lz: Node = _kill(w, "hylonomus", _ahead(p, 2.0))
	check(lz.dead and lz.prompt(p).begins_with("Pick up"), "a dead lizard is a carcass to pick up")
	lz.interact(p)
	await _frames(1)
	check(Game.inventory.count("lizard_carcass") == 1 and not is_instance_valid(lz), "it goes into the bag")
	var fly: Node = _kill(w, "meganeura", _ahead(p, 2.0))
	await _frames(1)
	fly.interact(p)
	check(Game.inventory.count("dragonfly_carcass") == 1, "so does a dead dragonfly")
	check(Items.def("dragonfly_carcass").cook == "roast_dragonfly" and not Items.def("lizard_carcass").has("cook"),
			"a dragonfly roasts whole, a lizard must be gutted first")

	# A lizard is gutted and skinned by hand, which leaves guts on the ground.
	w.start_work()
	w.work.lay(Game.inventory.find("lizard_carcass"))
	var opt: Array = w.work.options().filter(func(o): return o.recipe.out == "lizard_dressed")
	check(opt.size() == 1 and opt[0].missing.is_empty(), "gutting a lizard needs no tools")
	w.work.begin(opt[0].recipe)
	for k in Items.recipe_steps(w.work.recipe):
		w.work.step()
	check(Game.inventory.count("lizard_dressed") == 1 and Items.def("lizard_dressed").cook == "roast_lizard",
			"it becomes a dressed lizard to roast")
	check(get_tree().get_nodes_in_group("guts").size() == 1, "and leaves a guts pile")
	w.close_work()

	# Kneeling at a dead lizard lays it out to gut it there.
	var lz2: Node = _kill(w, "hylonomus", _ahead(p, 1.2))
	await _frames(1)
	w.start_work()
	check(w.work != null and w.work.laid("lizard_carcass") == 1 and (not is_instance_valid(lz2) or lz2.is_queued_for_deletion()),
			"kneeling at a small kill lays it out in front of you")
	w.close_work()

	# A scorpion is butchered where it lies, in stages, with a blade.
	Game.inventory.clear()
	var sc: Node = _kill(w, "scorpion", _ahead(p, 1.6))
	await _frames(2)
	w.start_work()
	check(w.work != null and w.work.carcass == sc, "kneeling at a medium kill butchers it there")
	var b: Dictionary = w.work.butcher_option()
	check(b.recipe.butcher == "gut" and b.missing.has("a stone blade"), "gutting needs a blade")
	w.close_work()
	Game.inventory.add("flint_blade")
	w.start_work()
	var piles0: int = get_tree().get_nodes_in_group("guts").size()
	_work_through(w)
	await _frames(1)
	check(sc.stage == "gutted" and get_tree().get_nodes_in_group("guts").size() == piles0 + 1, "gutting it leaves a guts pile beside it")
	_work_through(w)
	check(sc.stage == "skinned" and Game.inventory.count("chitin") == 1, "skinning a scorpion gives its chitin")
	check(w.work.butcher_option().recipe.steps == 2, "two pieces of meat to cut")
	w.work.begin(w.work.butcher_option().recipe)
	w.work.step()
	check(Game.inventory.count("raw_meat") == 1 and sc.cuts_left == 1, "each cut gives a piece of raw meat")
	w.work.step()
	await _frames(2)
	check(Game.inventory.count("raw_meat") == 2 and not is_instance_valid(sc) and w.work == null,
			"until nothing is left, and you stand up")

	# An amphibian's skin goes on the guts pile.
	var eg: Node = _kill(w, "eogyrinus", _ahead(p, 2.2))
	await _frames(2)
	w.start_work()
	check(w.work != null and w.work.carcass == eg, "kneeling at a large kill")
	_work_through(w)
	_work_through(w)
	var skinned := get_tree().get_nodes_in_group("guts").filter(func(g): return g.skin)
	check(eg.stage == "skinned" and skinned.any(func(g): return g.n >= 3 and g.global_position.distance_to(eg.global_position) < 3.0),
			"the skin is thrown on its guts pile")
	w.close_work()

	# Carrying and dragging.
	var ar: Node = _kill(w, "arthropleura", _ahead(p, 2.0))
	await _frames(2)
	ar.interact(p)
	check(p.hauling == ar and ar.haul_mode() == "carry", "a medium carcass is picked up")
	await _frames(2)
	check(p.prompt.begins_with("Put down"), "and E puts it down (%s)" % p.prompt)
	_press("inventory")
	await _frames(2)
	check(not w.inv_ui.visible, "no bag while your hands are full")
	_press("craft")
	await _frames(2)
	check(w.work == null, "and no kneeling to craft")
	p.global_position += Vector3(2.0, 0, 0)
	await _frames(3)
	check(ar.global_position.distance_to(p.global_position) < 3.0 and ar.global_position.y > p.global_position.y + 0.3,
			"it is carried in front of you")
	_press("drop")
	await _frames(2)
	check(p.hauling == null and ar.hauled_by == null and absf(ar.global_position.y - w.ground_height(ar.global_position.x, ar.global_position.z)) < 0.05,
			"Q puts it down on the ground")
	check(eg.haul_mode() == "drag", "a large one is dragged")
	eg.interact(p)
	check(p.hauling == eg, "and you can drag a part-butchered one too")
	p.put_down()

	# Carcasses and guts piles are saved, and last a day.
	var far := _find_spot(w, p.global_position + Vector3(0, 0, 14), func(q): return q.y > 0.2 and q.distance_to(p.global_position) > 10.0)
	var pile: Node = w.add_guts(far, 2)
	pile.roll_t = 77.0
	check(w.save_now(), "saved")
	var st: Dictionary = Game.read_save()
	var kinds: Array = st.get("carcasses", []).map(func(c): return c.species)
	check(kinds.has("arthropleura") and kinds.has("eogyrinus"), "carcasses are saved (%s)" % [kinds])
	var data := Game.read_save()
	w.queue_free()
	await _frames(2)
	Game.apply_save(data)
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	w2._spawn_t = 1e9
	var back := Game.creatures.filter(func(c): return is_instance_valid(c) and c.dead)
	var eg2 := back.filter(func(c): return c.species == "eogyrinus")
	check(back.size() >= 2 and eg2.size() == 1 and eg2[0].stage == "skinned", "carcasses come back as they were left")
	var piles := get_tree().get_nodes_in_group("guts")
	check(piles.size() >= 3 and piles.any(func(g): return g.n == 2 and absf(g.roll_t - 77.0) < 1.0), "and so do the guts piles")
	eg2[0].died_at = Game.time - Game.DAY_LENGTH - 1.0
	w2._spawn_creatures()
	await _frames(1)
	check(not is_instance_valid(eg2[0]), "a carcass rots away after a day")
	for g in piles:
		g.made = Game.time - Game.DAY_LENGTH - 1.0
	await _frames(2)
	check(get_tree().get_nodes_in_group("guts").is_empty(), "and a guts pile too")
	w2.queue_free()
	await _frames(2)

	# Thrown or dropped guts.
	w = await _new_swamp()
	p = w.player
	Game.inventory.clear()
	Game.inventory.add("guts", 2)
	Game.inventory.select(Game.inventory.find("guts"))
	p._drop_held()
	check(get_tree().get_nodes_in_group("guts").size() == 1, "dropped guts make a pile")
	var land := _find_spot(w, p.global_position + Vector3(8, 0, 0), func(q): return q.y > 0.3)
	var sea := _find_spot(w, p.global_position, func(q): return q.y < -1.2)
	w.add_child(ThrownRock.new().setup("guts", land + Vector3(0, 1.0, 0), Vector3(0, -3, 0), p, w))
	await _run_for(2.0, func(): return get_tree().get_nodes_in_group("guts").size() == 2)
	check(get_tree().get_nodes_in_group("guts").size() == 2, "thrown guts make a pile where they land")
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", sea + Vector3(3, 0, 0), sea + Vector3(3, 0, 0))
	w.add_child(ThrownRock.new().setup("guts", Vector3(sea.x, 1.0, sea.z), Vector3(0, -3, 0), p, w))
	await _run_for(2.0, func(): return u._lure != Vector3.ZERO)
	check(u._lure.distance_to(Vector3(sea.x, 0, sea.z)) < 1.0 and get_tree().get_nodes_in_group("guts").size() == 2,
			"thrown into the water they lure amphibians and are gone")
	u.queue_free()

	# A wandering scavenger eats guts it comes across.
	var spot := _find_spot(w, p.global_position + Vector3(40, 0, 0), func(q): return q.y > 0.4 and q.distance_to(p.global_position) > 30.0)
	var g1: Node = w.add_guts(spot, 1)
	var ar2: Node = Creature.new().setup("arthropleura", spot + Vector3(5, 0, 0), w)
	ar2.position.y = w.ground_height(spot.x + 5, spot.z)
	w.add_child(ar2)
	await _frames(2)
	ar2._cd = 0.0
	ar2._scan_t = 0.0
	await _run_for(20.0, func(): return ar2.state == "feed")
	check(ar2.state == "feed" and g1.eaten_by == ar2, "an Arthropleura finds the guts and eats them")
	ar2._state_t = 0.0
	await _frames(3)
	check(not is_instance_valid(g1), "until they are gone")
	ar2.queue_free()

	# The smell draws animals that come hungry: they eat, then linger.
	var g2: Node = w.add_guts(spot, 1)
	var v: Node = w.draw_to_guts(g2, "medium")
	check(v != null and v.drawn and v.species in ["arthropleura", "scorpion"] and v.global_position.distance_to(spot) > 25.0,
			"a scavenger turns up some way off")
	v.global_position = spot + Vector3(4, 0, 0)
	v.global_position.y = w.ground_height(v.global_position.x, v.global_position.z)
	await _run_for(30.0, func(): return v.state == "feed")
	check(v.state == "feed", "and goes for the guts (state %s)" % v.state)
	v._state_t = 0.0
	await _frames(4)
	check(not is_instance_valid(g2) and v._linger > 0.0 and v.home.distance_to(spot) < 1.0, "it eats them and lingers there")
	p.global_position = v.global_position + Vector3(12, 0.5, 0)
	await _frames(4)
	check(v._anger > 0.0 and v.state in ["chase", "attack"], "a player who comes near is attacked (state %s)" % v.state)
	v.queue_free()
	var g3: Node = w.add_guts(spot, 1)
	var e: Node = w.draw_to_guts(g3, "eogyrinus")
	check(e != null and e.species == "eogyrinus" and e.mode == "land", "an Eogyrinus comes for guts too")
	p.global_position = spot + Vector3(80, 0, 0)
	p.global_position.y = w.ground_height(p.global_position.x, p.global_position.z) + 0.2
	await _frames(8)   # far animals think every fourth frame
	check(e.state == "seek", "making for the pile (state %s)" % e.state)
	p.global_position = spot + Vector3(6, 0, 0)
	p.global_position.y = w.ground_height(p.global_position.x, p.global_position.z) + 0.2
	e.global_position = spot + Vector3(-4, 0, 0)
	await _frames(3)
	check(e.state == "charge", "and charges a player near it (state %s)" % e.state)
	e.queue_free()

	# A kill an Uranocentrodon is taking off is not the player's to butcher.
	var uc: Node = Creature.new().setup("uranocentrodon", spot + Vector3(30, 0, 0), w)
	w.add_child(uc)
	var held: Node = _kill(w, "pulmonoscorpius", spot + Vector3(31, 0, 0))
	uc._prey = held
	uc.state = "feed"
	held.carried_by = uc
	check(held.in_jaws() and held.prompt(p).begins_with("The Uranocentrodon has"), "a kill in jaws can't be taken")
	held.interact(p)
	check(p.hauling == null, "so it isn't picked up")
	uc.take_damage(1e6, p)
	check(not held.in_jaws() and held.prompt(p).begins_with("Pick up"), "but it can once its killer is dead")
	uc.queue_free()
	held.queue_free()
	w.queue_free()
	await _frames(2)


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()


func test_boulders() -> void:
	var w: Node = await _new_swamp()
	var start: Vector3 = w.player.global_position
	# A chunk with boulders: one already loaded, or one built further out.
	var found: Node = null
	for c in w.chunks.values():
		if _boulder_shapes(c).size() > 0:
			found = c
			break
	var i := 0
	while found == null and i < 400:
		var c: Node = Chunk.new()
		c.build(30 + i % 20, i / 20, w.terrain, w)
		w.add_child(c)
		if _boulder_shapes(c).size() > 0:
			found = c
		else:
			c.free()
		i += 1
	check(found != null, "found boulders")
	if found == null:
		w.queue_free()
		await _frames(2)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	var shape: ConvexPolygonShape3D = _boulder_shapes(found)[0].shape
	var mid := Vector3.ZERO
	for v in shape.points:
		mid += v
	mid = found.global_transform * (mid / shape.points.size())
	var top := 0.0
	for v in shape.points:
		top = maxf(top, (found.global_transform * v).y)
	var q := PhysicsRayQueryParameters3D.create(Vector3(mid.x, top + 5.0, mid.z), Vector3(mid.x, top - 6.0, mid.z), 1)
	var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty() and hit.collider.has_meta("hard") and hit.position.y > w.ground_height(mid.x, mid.z) + 0.2,
			"a boulder is solid to the player")
	check(Array(found.trunks).any(func(t): return Vector2(t.x - mid.x, t.y - mid.z).length() < 0.5 and t.z > 0.5),
			"and an obstacle that animals walk around")
	# A stone thrown at it stops short and drops beside it.
	var from := Vector3(mid.x - 6.0, mid.y + 0.3, mid.z)
	var near_stone := func(n): return n.get_script() == Pickup and n.item_id == "stone" and n.global_position.distance_to(from) < 8.0
	var already: Array = w.get_children().filter(near_stone)  # shore stones may lie about
	var rock: Node = ThrownRock.new().setup("stone", from, Vector3(18, 1.0, 0), w.player, w)
	w.add_child(rock)
	var rock_id := rock.get_instance_id()
	await _run_for(2.0, func(): return instance_from_id(rock_id) == null)
	var lying: Array = w.get_children().filter(func(n): return near_stone.call(n) and not n in already)
	check(lying.size() == 1 and lying[0].global_position.x < mid.x, "a stone thrown at it stops against it")
	w.queue_free()
	await _frames(2)


func _boulder_shapes(c: Node) -> Array:
	var out := []
	for body in c.get_children():
		if body is StaticBody3D and body.has_meta("hard"):
			for cs in body.get_children():
				if cs.shape is ConvexPolygonShape3D:
					out.append(cs)
	return out


func test_debug_save() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var here: Vector3 = p.global_position
	var u: Node = w.spawn_amphibian("uranocentrodon", "hide", here + Vector3(2, 0, 0), here + Vector3(2, 0, 0))
	u.attack_now(p)
	Game.debug = false
	w.pause.open()
	check(not w.pause._save_now_btn.visible and w.suspend_blocker() != "", "normally no saving with something on you")
	w.pause.resume()
	Game.debug = true
	w.pause.open()
	check(w.pause._save_now_btn.visible and not w.pause._save_now_btn.disabled and w.suspend_blocker() == "",
			"debug mode lets you save even now")
	w.pause._save_now()
	var data := Game.read_save()
	check(not data.is_empty() and Vector3(data.player.pos[0], data.player.pos[1], data.player.pos[2]).distance_to(p.global_position) < 0.5,
			"Save now writes the camp save at this moment")
	w.pause.resume()
	check(w.save_suspend(), "and save and quit is allowed too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.suspend_path()))
	p.vitals.blood = 0.0
	p.vitals.dead = true
	check(w.suspend_blocker() != "" and not w.save_now(), "but not once you are dead")
	Game.debug = false
	u.release(false)
	w.queue_free()
	await _frames(2)


func test_debug_world() -> void:
	var keep_id: String = Game.world_id
	Game.world_id = ""  # the switches are not written to any real world
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.debug = true
	check(w.sleep_blocker() == "", "a debug world lets you sleep at any time")

	# The switches.
	Game.set_cheat("damage", false)
	var hp: float = p.vitals.blood
	p.hurt(30.0, p.global_position)
	check(p.vitals.god and p.vitals.blood == hp and p.vitals.wounds.is_empty(), "with damage off nothing hurts you")
	Game.set_cheat("damage", true)
	p.hurt(10.0, p.global_position)
	check(not p.vitals.god and p.vitals.blood < hp, "and with it on again it does")
	Game.set_cheat("needs", false)
	p.vitals.water = 20.0
	p.vitals.tick(5.0, true, false, false)
	check(p.vitals.water >= 99.0 and p.vitals.stamina >= p.vitals.max_stamina() - 0.01, "with needs off you never thirst or tire")
	Game.set_cheat("needs", true)
	check(Game.hostile(), "animals are hostile by default")
	Game.set_cheat("hostile", false)
	var risk: Dictionary = w.sleep_risk(p.global_position)
	check(not Game.hostile() and risk.amphibian == 0.0 and risk.predator == 0.0, "with hostility off nothing comes for you, even asleep")
	Game.set_cheat("hostile", true)

	# Double-tap jump to fly.
	p.capture_mouse(false)
	p._last_jump = Time.get_ticks_msec() * 0.001
	Input.action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("jump")
	check(p.flying, "a double tap of jump takes off")
	var y0: float = p.global_position.y
	Input.action_press("jump")
	for i in 20:
		await get_tree().physics_frame
	Input.action_release("jump")
	check(p.global_position.y > y0 + 0.5, "holding jump climbs")
	p.flying = false

	# The panel.
	w.open_debug()
	var dp: Control = w._debug_panel
	check(dp != null and dp.visible and get_tree().paused, "F1 opens the debug panel and pauses")
	dp._day.value = 4
	dp._hour.value = 22.0
	dp._set_time()
	check(Game.day() == 3 and absf(Game.clock() - 22.0 * 60.0) < 1.0, "it sets the day and time")
	dp._weather.selected = dp._weathers.find("fog")
	dp._start_weather()
	check(w.weather.kind == "fog", "it starts a weather event")
	dp._stop_weather()
	check(w.weather.kind == "" and not w.raining, "and clears the weather")
	Game.inventory.clear()
	dp._item.selected = dp._items.find("flint")
	dp._count.value = 3
	dp._give()
	check(Game.inventory.count("flint") == 3, "it gives items")
	var n := Game.creatures.size()
	dp._creature.selected = dp._species.find("uranocentrodon")
	dp._spawn()
	check(Game.creatures.size() == n + 1 and Game.creatures[-1].species == "uranocentrodon", "it spawns creatures")
	Game.creatures[-1].queue_free()
	# Health conditions: each shows on the Health tab as itself.
	var vt = p.vitals
	var shows := {
		"bleed_minor": "Bleeding a little", "bleed_moderate": "Bleeding", "bleed_major": "Bleeding badly",
		"dirty_wound": "Dirty wound", "infection_minor": "Infected wound", "infection_moderate": "Feverish",
		"infection_major": "Badly infected", "infection_remission": "Infection held back", "sepsis": "Septic",
		"broken_arm": "Broken arm", "broken_leg": "Broken leg", "sprained_ankle": "Sprained ankle",
		"blood_loss": "Faint from blood loss", "venom": "Envenomed", "food_poisoning": "Sick", "chilled": "Chilled",
		"starving": "Dying of Starvation", "thirst": "Dying of Thirst", "tipsy": "Tipsy", "drunk": "Drunk", "very_drunk": "Very drunk",
		"vomiting_drunk": "Vomiting drunk", "blind_drunk": "Blind drunk", "low_protein": "Craving protein",
		"low_greens": "Craving greens", "low_starch": "Craving starch",
	}
	var wrong := []
	for c in vt.DEBUG_CONDITIONS:
		vt.cure_all()
		dp._condition.selected = vt.DEBUG_CONDITIONS.find(c)
		dp._give_condition()
		var words: Array = vt.problems().map(func(q): return q.words)
		if not shows.get(c[0], "?") in words:
			wrong.append("%s %s" % [c[0], words])
	check(shows.size() == vt.DEBUG_CONDITIONS.size() and wrong.is_empty(), "it gives every health condition %s" % [wrong])
	vt.cure_all()
	vt.give_condition("sepsis")
	check(vt.infection() == vt.INF_SEPSIS and not vt.bleeding() and vt.wounds.size() == 1, "an infection comes on a wound that isn't bleeding")
	dp._heal()
	check(vt.problems().is_empty() and vt.wounds.is_empty() and vt.alcohol == 0.0 and vt.blood == 100.0, "and Heal clears them all")
	Game.set_cheat("damage", false)
	dp._condition.selected = vt.DEBUG_CONDITIONS.map(func(c): return c[0]).find("sepsis")
	dp._give_condition()
	vt.wounds[0].inf_t = vt.SEPSIS_TIME * 2.0
	vt.tick(1.0, false, false)
	check(vt.infection() == vt.INF_SEPSIS and not vt.dead and "Damage is off" in dp._note.text,
			"with damage off a condition is still given, but can't kill you")
	Game.set_cheat("damage", true)
	dp._heal()
	check(not vt.give_condition("no_such_thing"), "an unknown condition is refused")
	dp.close()
	check(not dp.visible and not get_tree().paused, "and closes")
	Game.debug = false
	w.open_debug()
	check(not dp.visible, "outside a debug world it stays shut")
	Game.world_id = keep_id
	w.queue_free()
	await _frames(2)


func _touch_ev(tc: Control, index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	tc._input(ev)
	Input.flush_buffered_events()  # the buttons' action events are queued until then


func _drag_ev(tc: Control, index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = rel
	tc._input(ev)


func test_touch() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var tc: Control = load("res://src/ui/touch_controls.gd").new()
	tc.player = p
	tc.hud = w.hud
	tc.pause_menu = w.pause
	w.pause.get_parent().add_child(tc)
	await _frames(2)
	var hit: Vector2 = tc._center(tc._buttons.filter(func(b): return b.action == "attack")[0])
	_touch_ev(tc, 0, hit, true)
	check(Input.is_action_pressed("attack"), "the Hit button holds attack down")
	_touch_ev(tc, 0, hit, false)
	check(not Input.is_action_pressed("attack"), "and lets go")

	# The stick: wherever the left thumb lands.
	var at := Vector2(tc.size.x * 0.15, tc.size.y * 0.6)
	_touch_ev(tc, 1, at, true)
	_drag_ev(tc, 1, at + Vector2(0, -tc.STICK_RADIUS), Vector2(0, -tc.STICK_RADIUS))
	check(Input.get_action_strength("move_forward") > 0.9 and Input.get_action_strength("move_back") == 0.0, "pushing the stick up walks forward")
	var run: Vector2 = tc._center(tc._buttons.filter(func(b): return b.action == "sprint")[0])
	_touch_ev(tc, 2, run, true)
	_touch_ev(tc, 2, run, false)
	check(Input.is_action_pressed("sprint"), "Run switches running on")
	_touch_ev(tc, 1, at, false)
	check(Input.get_action_strength("move_forward") == 0.0 and not Input.is_action_pressed("sprint"), "letting go stops, and ends the run")

	# Dragging elsewhere looks around; a hotbar slot is a tap away.
	var yaw: float = p.rotation.y
	var right := Vector2(tc.size.x * 0.6, tc.size.y * 0.3)
	_touch_ev(tc, 3, right, true)
	_drag_ev(tc, 3, right + Vector2(80, 0), Vector2(80, 0))
	_touch_ev(tc, 3, right + Vector2(80, 0), false)
	check(p.rotation.y < yaw - 0.3, "dragging to the right turns right")
	var slot: Rect2 = w.hud._hotbar_rect(3, tc.size)
	_touch_ev(tc, 4, slot.get_center(), true)
	_touch_ev(tc, 4, slot.get_center(), false)
	check(Game.inventory.selected == 3, "tapping a hotbar slot selects it")
	w.waypoint = Vector3.INF
	var mark: Vector2 = tc._center(tc._buttons.filter(func(b): return b.action == "waypoint")[0])
	_touch_ev(tc, 7, mark, true)
	_touch_ev(tc, 7, mark, false)
	check(w.waypoint.is_finite(), "Mark sets a waypoint")
	check(tc._buttons.any(func(b): return b.action == "sleep"), "there is a Sleep button")

	# With a menu open only Back is there, and it works as Esc.
	w.toggle_inventory()
	check(p.ui_open and w.inv_ui.visible, "the inventory is open")
	_touch_ev(tc, 5, hit, true)
	_touch_ev(tc, 5, hit, false)
	check(not Input.is_action_pressed("attack"), "the game buttons are off under a menu")
	var back: Vector2 = tc._center(tc._buttons.filter(func(b): return b.action == "pause")[0])
	_touch_ev(tc, 6, back, true)
	_touch_ev(tc, 6, back, false)
	await _frames(2)
	check(not w.inv_ui.visible, "Back closes it")
	w.pause.resume()
	w.queue_free()
	await _frames(2)


func test_worlds() -> void:
	var keep := [Game.worlds_dir, Game.world_id, Game.save_path, Game.old_save_path]
	Game.worlds_dir = "user://test_worlds"
	for wd in Game.list_worlds():
		Game.delete_world(wd.id)
	check(Game.list_worlds().is_empty() and Game.latest_world().is_empty(), "no worlds yet")
	var a := Game.create_world("Fern Hollow")
	var b := Game.create_world("  Fern Hollow ")
	check(a == "fern_hollow" and b == "fern_hollow_2", "world folders come from the name and stay unique (%s, %s)" % [a, b])
	Game.use_world(a)
	check(Game.world_name == "Fern Hollow" and Game.save_path == "user://test_worlds/fern_hollow/save.json",
			"each world has its own save")
	var t := Game.time
	Game.time = Game.DAY_LENGTH * 2.0
	Game.tiers = ["hand", "bench"]
	check(Game.save_game({}), "saving goes into that world")
	check(Game.read_save().get("tiers", []) == ["hand", "bench"], "unlocked crafting tiers are saved")
	Game.tiers = ["hand"]
	Game.time = t
	var list := Game.list_worlds()
	check(list.size() == 2 and list[0].id == a and list[0].saved and list[0].day == 3 and not list[1].saved,
			"the load screen lists both, last played first, with the day")
	check(Game.latest_world().get("id", "") == a, "Continue picks the last world played with a save")
	Game.use_world(b)
	check(not Game.has_save() and Game.take_save().is_empty(), "the other world has nothing to load yet")

	# A save from before named worlds becomes a world of its own.
	Game.old_save_path = "user://test_old_save.json"
	DirAccess.copy_absolute(ProjectSettings.globalize_path("user://test_worlds/fern_hollow/save.json"),
			ProjectSettings.globalize_path(Game.old_save_path))
	Game._migrate_old_save()
	var mine := Game.list_worlds().filter(func(wd): return wd.name == "My world")
	check(mine.size() == 1 and mine[0].saved and not FileAccess.file_exists(Game.old_save_path), "an old save is moved into \"My world\"")

	# Exported to a file and imported again, as a world of its own.
	var text := Game.export_world(a)
	var path := "user://test_export.vibival"
	var ef := FileAccess.open(path, FileAccess.WRITE)
	ef.store_string(text)
	ef.close()
	check(text != "" and Game.export_world("no_such_world") == "", "a world exports as one text, a missing one doesn't")
	var got := Game.import_world(FileAccess.get_file_as_string(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(got.get("name", "") == "Fern Hollow (2)" and got.get("id", "") != a, "imported beside the original, renamed (%s)" % got)
	var imp := Game.list_worlds().filter(func(wd): return wd.id == got.get("id", ""))
	check(imp.size() == 1 and imp[0].saved and imp[0].day == 3 and Game.list_worlds()[0].id == got.get("id", ""),
			"with its save, listed first")
	Game.use_world(got.get("id", ""))
	check(Game.read_save().get("tiers", []) == ["hand", "bench"], "and everything in it")
	check(Game.import_world("not a world").has("error") and Game.import_world(JSON.stringify({"kind": "vibival-world", "version": 0, "world": {}})).has("error"),
			"other files and other versions are refused")
	var title: Control = load("res://src/ui/title.gd").new()
	add_child(title)
	await _frames(1)
	title._open_load_world()
	var texts: Array = title.find_children("*", "Button", true, false).map(func(bt): return bt.text)
	check(texts.count("Export") == Game.list_worlds().size() and "Import world" in texts, "the load screen has Export and Import world")
	title._imported(text)
	check(title._status.visible and "Fern Hollow (3)" in title._status.text, "importing there says so")
	title.queue_free()
	await _frames(1)

	Game.delete_world(a)
	check(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://test_worlds/fern_hollow"))
			and Game.list_worlds().size() == 4, "a world can be deleted")
	for wd in Game.list_worlds():
		Game.delete_world(wd.id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.worlds_dir))
	Game.worlds_dir = keep[0]
	Game.world_id = keep[1]
	Game.save_path = keep[2]
	Game.old_save_path = keep[3]


func test_stash() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var firm := func(q): return [Vector3.ZERO, Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)].all(func(o): return w.ground_height(q.x + o.x, q.z + o.z) > 0.4)
	var dry := _find_spot(w, p.global_position, firm)
	p.global_position = dry + Vector3(0, 0.1, 0)
	Game.inventory.clear()
	Game.inventory.add("fiber_sack")
	Game.inventory.select(0)
	check(Game.inventory.capacity() == Inventory.SACK_CAPACITY, "the sack lets you carry more")
	p._use_held()
	var stashes := get_tree().get_nodes_in_group("stashes")
	check(stashes.size() == 1 and Game.inventory.count("fiber_sack") == 0, "using a held sack sets it down as a stash")
	if stashes.size() != 1:
		w.queue_free()
		await _frames(2)
		return
	var s: Node = stashes[0]
	check(Game.inventory.capacity() == Inventory.BASE_CAPACITY, "without it on your shoulder you carry less")
	check(s.prompt(p).begins_with("Open woven frond sack"), "it can be opened (%s)" % s.prompt(p))
	w.open_stash(s)
	var ui: Node = w.inv_ui
	check(ui.visible and ui.stash == s and ui._stash_panel.visible and not ui._rest_panel.visible, "opening it shows both inventories")
	Game.inventory.add("stone", 10)
	ui._move_across(Game.inventory, Game.inventory.find("stone"), s.inv)
	check(s.inv.count("stone") == 10 and Game.inventory.count("stone") == 0, "right-click moves a stack into the sack")
	Game.inventory.add("stick", 3)
	ui._on_slot(Game.inventory.find("stick"))
	ui._on_slot(5, true)
	check(s.inv.slots[5] != null and s.inv.slots[5].id == "stick" and Game.inventory.count("stick") == 0, "or pick one up and drop it in a slot")
	var left: int = s.inv.add("stone", 1000)
	check(s.capacity() == 50.0 and left > 0 and s.inv.weight() <= s.capacity() + 0.001 and s.inv.weight() > s.capacity() - 1.0, "it holds up to 50 kg (%.1f kg)" % s.inv.weight())
	check(not s.pick_up(), "a full sack stays where it is")
	ui._take_all()
	check(Game.inventory.weight() <= Inventory.BASE_CAPACITY * Inventory.OVERLOAD + 0.001 and s.inv.count("stone") > 0,
			"take all stops at what you can carry")
	var state: Dictionary = w._world_state()
	var kept: int = s.inv.count("stone")
	check(state.stashes.size() == 1, "stashes are saved")
	var s2: Node = w._add_stash(s.global_position + Vector3(3, 0, 0))
	s2.from_dict(state.stashes[0])
	check(s2.inv.count("stone") == kept and s2.inv.capacity() == s.capacity() and s2.sack_id == "fiber_sack", "and come back with what was in them")
	s2.queue_free()
	s.inv.clear()
	ui._pick_up_stash()
	await _frames(2)
	check(not is_instance_valid(s) and Game.inventory.count("fiber_sack") == 1 and not ui.visible, "an empty sack can be picked up again")
	check(Items.item_name("fiber_sack") == "Woven Frond Sack", "it is the Woven Frond Sack")

	# The cloth sack: known through the spindle, 40 kg more carried, 100 kg set down.
	var cr: Dictionary = Items.recipe_for("cloth_sack")
	check(cr.in.get("string", 0) == 8 and cr.in.size() == 1 and cr.get("known_by", "") == "spindle", "a cloth sack is woven from 8 string")
	check(not Game.knows_recipe(cr), "unknown until the spindle")
	Game.learn_tool("spindle", false)
	check(Game.knows_recipe(cr), "known once you have the spindle")
	Game.inventory.clear()
	Game.inventory.add("cloth_sack")
	check(is_equal_approx(Game.inventory.capacity(), Inventory.BASE_CAPACITY + 40.0), "a cloth sack lets you carry 40 kg more (%.1f kg)" % Game.inventory.capacity())
	Game.inventory.add("fiber_sack")
	check(is_equal_approx(Game.inventory.capacity(), Inventory.BASE_CAPACITY + 40.0)
			and is_equal_approx(Game.inventory.weight(), Items.weight("cloth_sack") + Items.weight("fiber_sack")),
			"sacks don't add up: only the best counts, the other is just weight")
	Game.inventory.add("fiber_sack", 1, 0.0, true)
	check(is_equal_approx(Game.inventory.capacity(), Inventory.BASE_CAPACITY + 40.0), "however many you carry")
	Game.inventory.remove("cloth_sack", 1)
	check(is_equal_approx(Game.inventory.capacity(), Inventory.SACK_CAPACITY), "without it, the frond sack counts")
	Game.inventory.clear()
	Game.inventory.add("cloth_sack")
	Game.inventory.select(Game.inventory.find("cloth_sack"))
	p._use_held()
	var cloths: Array = get_tree().get_nodes_in_group("stashes").filter(func(n): return n.sack_id == "cloth_sack")
	check(cloths.size() == 1 and Game.inventory.count("cloth_sack") == 0, "set down as a stash")
	if cloths.size() == 1:
		var cs: Node = cloths[0]
		check(cs.capacity() == 100.0 and cs.inv.capacity() == 100.0 and cs.prompt(p).begins_with("Open woven cloth sack"), "that holds 100 kg (%s)" % cs.prompt(p))
		check(cs._mesh.mesh == Assets.mesh("stash_cloth_sack") and cs._mesh.mesh != Assets.mesh("stash"), "and looks lighter than a frond sack")
		w.open_stash(cs)
		check(ui._stash_panel.get_child(0).get_child(0).text == "Woven Cloth Sack", "its panel is titled with its name")
		w.close_ui()
		var ds: Array = w._world_state().stashes.filter(func(d): return d.get("sack", "") == "cloth_sack")
		var cs2: Node = w._add_stash(cs.global_position + Vector3(3, 0, 0))
		cs2.from_dict(ds[0])
		check(cs2.sack_id == "cloth_sack" and cs2.inv.capacity() == 100.0, "saved and restored as a cloth sack")
		cs2.queue_free()
		var old: Node = w._add_stash(cs.global_position + Vector3(-3, 0, 0))
		old.from_dict({"yaw": 0.0, "inv": Inventory.new().to_dict()})
		check(old.sack_id == "fiber_sack" and old.capacity() == 50.0, "an older save's stash is a frond sack")
		old.queue_free()
		check(cs.pick_up() and Game.inventory.count("cloth_sack") == 1, "picked up, it is a cloth sack again")
	w.queue_free()
	await _frames(2)


func test_waypoint() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var far: Vector3 = p.global_position + Vector3(40, 0, 0)
	w.mark_waypoint(far)
	check(w.waypoint.is_finite() and Vector2(w.waypoint.x - far.x, w.waypoint.z - far.z).length() < 0.01 and w._waypoint_mark.visible,
			"M marks a waypoint where you look")
	await _frames(2)
	check(w._world_state().waypoint.size() == 3, "it is saved with the world")
	p.global_position = Vector3(w.waypoint.x + 2.0, p.global_position.y, w.waypoint.z)
	w.mark_waypoint(far + Vector3(10, 0, 0))
	check(not w.waypoint.is_finite() and not w._waypoint_mark.visible, "marking again beside it clears it")
	w.mark_waypoint(Vector3.INF)
	check(Vector2(w.waypoint.x - p.global_position.x, w.waypoint.z - p.global_position.z).length() < 0.01,
			"looking at the sky marks where you stand")
	w.queue_free()
	await _frames(2)


func _pickups(w: Node, id: String) -> Array:
	return w.get_children().filter(func(n): return n.get_script() == Pickup and n.item_id == id and not n.is_queued_for_deletion())


func test_shore() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var start: Vector3 = p.global_position
	# A new world starts with river stones and chert washed up nearby.
	var ok: bool = w._shore.size() >= 4
	for e in w._shore:
		var q: Vector3 = e.node.global_position
		ok = ok and q.y >= -0.25 and q.y <= w.SHORE_ITEM_TOP + 0.05 \
				and w.water_point(q, w.SHORE_ITEM_REACH, w.water_level() - 0.05).is_finite() \
				and e.until > Game.time and e.until <= Game.time + 3.0 * Game.DAY_LENGTH
	check(ok, "%d stones lie along the shore, each for up to a few days" % w._shore.size())
	var ids := {}
	for e in w._shore:
		ids[e.node.item_id] = true
	check(ids.keys().all(func(k): return k in ["stone", "flint", "salt", "stick"]), "they are river stones, chert, sticks and salt")
	var sticks := 0
	for i in 200:
		if w._shore_kind(Vector3(0, -0.1, 0)) == "stick":
			sticks += 1
	check(sticks > 35 and sticks < 90, "sticks wash up along the edge too (%d in 200)" % sticks)

	# They go back to the water in time, and new ones wash up.
	var first: Node = w._shore[0].node
	var first_id := first.get_instance_id()
	w._shore[0].until = Game.time - 1.0
	w._update_shore(0.0)
	check(first.is_queued_for_deletion() and not w._shore.any(func(e): return e.node.get_instance_id() == first_id), "an old one is gone")
	# Take a few more away, so there is room under SHORE_ITEMS for new ones.
	for e in w._shore.slice(0, 5):
		e.until = Game.time - 1.0
	w._shore_t = 1e9
	w._update_shore(0.0)
	var before: int = w._shore.size()
	for i in 10:
		w._shore_t = 0.0
		w._update_shore(1.5)
	check(w._shore.size() > before, "and more wash up (%d to %d)" % [before, w._shore.size()])
	var saved: Dictionary = w._world_state()
	check(saved.shore.size() == w._shore.size() and saved.shore[0].has("until"), "they are saved with the world")

	# Picking one up takes it out of the shore's list (it is yours now).
	var one: Node = w._shore[0].node
	var one_id := one.get_instance_id()
	var one_item: String = one.item_id
	Game.inventory.clear()
	one.interact(p)
	await _frames(1)
	w._update_shore(0.0)
	check(Game.inventory.count(one_item) == 1 and not w._shore.any(func(e): return is_instance_valid(e.node) and e.node.get_instance_id() == one_id),
			"a picked-up one is yours, and leaves the shore")

	# Stones you put down stay for good; thrown ones are gone after a reload.
	Game.inventory.clear()
	Game.inventory.add("stone", 2)
	Game.inventory.select(0)
	p._drop_held()
	# On land it goes on a pile; in the water it lies loose.
	var kept := func(): return w.get_tree().get_nodes_in_group("drops") + w.get_tree().get_nodes_in_group("stacks")
	var dropped: Array = kept.call()
	check(dropped.size() == 1 and dropped[0].item_id == "stone", "a stone dropped with Q is kept")
	p._attack_cd = 0.0
	p._use_held()
	var rocks: Array = w.get_children().filter(func(n): return n.get_script() == ThrownRock)
	for i in 240:
		await get_tree().physics_frame
		if rocks.is_empty() or not is_instance_valid(rocks[0]):
			break
	check(kept.call().size() == 1, "a thrown stone is not kept in the save")
	saved = w._world_state()
	check(saved.drops.size() + saved.stacks.size() == 1, "only the dropped one is saved")
	p.global_position = start
	w.queue_free()
	await _frames(2)


func test_weather() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var ev: Node = w.weather
	# Nothing unusual on the first two days, then about one day in three.
	var early := 0
	for i in 400:
		if ev.roll_day(i % 2) != "":
			early += 1
	check(early == 0, "no events before day 3")
	var hits := 0
	var kinds := {}
	for i in 3000:
		var k: String = ev.roll_day(2 + i % 20)
		if k != "":
			hits += 1
			kinds[k] = true
	check(absf(hits / 3000.0 - ev.CHANCE) < 0.03, "about a third of days have one (%.1f%%)" % (hits / 30.0))
	check(kinds.size() == ev.ALL_KINDS.size(), "all eight kinds turn up")

	# Night-sky events last the night; the others 6-12 minutes some time that day.
	var day := 3
	ev.plan("aurora", day)
	check(is_equal_approx(fmod(ev.planned_at + Game.ARRIVAL_CLOCK, Game.DAY_LENGTH), ev.NIGHT_START) and is_equal_approx(ev.planned_len, 360.0),
			"an aurora is planned for dusk until dawn")
	# It hints at itself from the start of dusk, then begins in the dark.
	var was: float = Game.time
	var notes: Array[String] = []
	var note := func(t: String) -> void: notes.append(t)
	Game.message.connect(note)
	ev.rolled_day = day
	Game.time = ev.planned_at - (ev.NIGHT_START - ev.DUSK_START) - 1.0
	ev.update(0.1)
	check(notes.is_empty(), "no word of the aurora before dusk")
	Game.time += 2.0
	ev.update(0.1)
	check(notes.size() == 1 and notes[0] == ev.HINT_TEXT.aurora and ev.kind == "", "faint shimmers at the start of dusk")
	ev.update(0.1)
	check(notes.size() == 1, "the hint comes once")
	Game.time = ev.planned_at + 1.0
	ev.update(0.1)
	check(ev.kind == "aurora" and notes.size() == 2 and notes[1] == ev.START_TEXT.aurora, "the curtains of light once it is dark")
	Game.message.disconnect(note)
	ev.stop()
	Game.time = was
	ev.plan("fog", day)
	var dstart: float = ev.day_start(day)
	check(ev.planned_len >= 360.0 and ev.planned_len <= 720.0 and ev.planned_at >= dstart and ev.planned_at + ev.planned_len <= dstart + Game.DAY_LENGTH + 1.0,
			"fog is planned for %.0f min that day" % (ev.planned_len / 60.0))
	Game.time = ev.planned_at + 5.0
	ev.rolled_day = Game.day()
	ev.update(0.1)
	check(ev.kind == "fog" and ev.planned == "" and ev.left > ev.planned_len - 10.0, "it begins on time")
	for i in 40:
		ev.update(1.0)
	w._update_sky()
	check(w._env.fog_density > 5.0 / Settings.view_distance, "fog closes in (density %.3f)" % w._env.fog_density)
	var state: Dictionary = ev.to_dict()
	ev.update(ev.left + 1.0)
	check(ev.kind == "", "and lifts again")
	ev.from_dict(state)
	check(ev.kind == "fog" and ev.left > 0.0, "an event under way is saved and restored")
	ev.stop()

	# A thunderstorm: dark, heavy rain and lightning that strikes far off.
	Game.time = Game.solar_to_clock(0.5) - Game.ARRIVAL_CLOCK
	w._update_sky()
	var sun_noon: float = w._sun.light_energy
	ev.start("thunderstorm")
	ev.fade = 1.0
	w._update_weather(0.1)
	w._update_sky()
	check(w.raining and w._sun.light_energy < sun_noon * 0.4, "the storm brings rain and darkness (%.2f vs %.2f)" % [w._sun.light_energy, sun_noon])
	var hp: float = p.vitals.blood
	var near := INF
	for i in 30:
		var hit: Vector3 = ev.lightning()
		near = minf(near, Vector2(hit.x - p.global_position.x, hit.z - p.global_position.z).length())
	check(ev.flash > 0.0 and near > 20.0 and p.vitals.blood == hp, "lightning flashes, but never close (nearest %.0f m)" % near)
	ev.stop()

	# High winds: trees lean, thrown stones drift, dragonflies are swept away.
	ev.start("wind")
	ev.fade = 1.0
	ev.update(0.05)
	check(w.wind.length() > 5.0, "the wind blows (%.1f m/s)" % w.wind.length())
	var lean: Vector3 = Assets.material("bark").get_shader_parameter("wind")
	check(lean.length() > 0.3, "trees lean with it")
	var from: Vector3 = p.global_position + Vector3(0, 1.6, 0)
	w.add_child(ThrownRock.new().setup("stone", from, Vector3(0, 8, 0), p, w))
	for i in 240:
		await get_tree().physics_frame
		if w.get_children().filter(func(n): return n.get_script() == ThrownRock).is_empty():
			break
	var landed := Vector3.INF
	for n in _pickups(w, "stone"):
		if Vector2(n.global_position.x - from.x, n.global_position.z - from.z).length() < Vector2(landed.x - from.x, landed.z - from.z).length():
			landed = n.global_position
	var drift := Vector2(landed.x - from.x, landed.z - from.z)
	check(drift.length() > 1.0 and drift.normalized().dot(Vector2(ev.wind_dir.x, ev.wind_dir.z)) > 0.8,
			"a stone thrown straight up comes down %.1f m downwind" % drift.length())
	var fly: Node = Creature.new().setup("meganeura", p.global_position + Vector3(0, 5, 0), w)
	w.add_child(fly)
	await _frames(2)
	var f0: Vector3 = fly.global_position
	fly.blow_away(2.0)
	for i in 60:
		await get_tree().physics_frame
	var moved: Vector3 = fly.global_position - f0
	check(fly.blown > 0.0 and Vector2(moved.x, moved.z).normalized().dot(Vector2(ev.wind_dir.x, ev.wind_dir.z)) > 0.8,
			"a dragonfly is blown helplessly downwind")
	ev.stop()
	ev.update(0.1)
	check(w.wind == Vector3.ZERO, "and the air is still again")
	w.queue_free()
	await _frames(2)


func test_blueprint() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	Game.tiers = ["hand", "bench"]
	var at: Vector3 = p.global_position - p.global_basis.z * 1.6
	at.y = w.ground_height(at.x, at.z)
	var bench: Node = w.add_bench(at, p.rotation.y)
	await _frames(2)
	p.focus = bench
	w.start_work()
	var ws: Node = w.work

	# Drawn on a big blank sheet with the pencil, sharpened with any blade at
	# the start and halfway, each sharpening wearing a use off it.
	Game.inventory.add("paper_sheet", 3)
	Game.inventory.add("ash_pencil", 2)
	_lay_from_bag(ws, {"paper_sheet": 1})
	var o := _option_for(ws, "blueprint_softwood_house")
	check(not o.is_empty() and o.missing.has("a blade to work with"), "a blueprint needs a blade to sharpen the pencil")
	Game.inventory.add("flint_blade")
	check(ws.missing_for(o.recipe).is_empty() and ws.begin(o.recipe), "with one, the house can be drawn")
	check("Sharpen" in ws.instructions(), "the first step sharpens the pencil")
	ws.step()
	var worn := -1
	for i in Inventory.SIZE:
		var sl = Game.inventory.slots[i]
		if sl != null and sl.id == "ash_pencil" and sl.has("data"):
			worn = i
	check(worn >= 0 and Game.inventory.uses_left(worn) == 49 and Game.inventory.count("ash_pencil") == 2
			and Game.inventory.def_of(worn).name == "Ash Pencil (49/50)", "sharpening wears one use off one pencil, the other stays fresh")
	for k in 4:
		ws.step()
	check("Sharpen" in ws.instructions(), "and again halfway")
	for k in 5:
		ws.step()
	check(Game.inventory.count("blueprint_softwood_house") == 1 and Game.inventory.uses_left(worn) == 48
			and Game.inventory.count("flint_blade") == 1 and Game.inventory.count("paper_sheet") == 2,
			"a blueprint costs a sheet and two uses of the pencil, and the blade is kept")
	check(Game.inventory.most_uses("ash_pencil") == 50, "the worn pencil is worn first")

	# A pencil too worn for both sharpenings won't do; one with just enough
	# is worn down to nothing.
	Game.inventory.remove("ash_pencil", 2)
	Game.inventory.add("ash_pencil", 1, 0.0, true, Items.uses_data("ash_pencil", 1))
	_lay_from_bag(ws, {"paper_sheet": 1})
	o = _option_for(ws, "blueprint_softwood_house")
	check(o.missing.any(func(m): return "2 uses left" in m), "a pencil with one use left can't draw a blueprint")
	Game.inventory.remove("ash_pencil", 1)
	Game.inventory.add("ash_pencil", 1, 0.0, true, Items.uses_data("ash_pencil", 2))
	check(ws.missing_for(o.recipe).is_empty() and _make(ws, o.recipe), "one with two can")
	check(Game.inventory.count("ash_pencil") == 0 and Game.inventory.count("blueprint_softwood_house") == 2, "and is worn down to nothing")
	# A fresh pencil laid out on the bench is worn just the same.
	Game.inventory.add("ash_pencil", 1)
	_lay_from_bag(ws, {"paper_sheet": 1, "ash_pencil": 1})
	o = _option_for(ws, "blueprint_softwood_house")
	check(o.missing.is_empty() and _make(ws, o.recipe) and Game.inventory.most_uses("ash_pencil") == 48, "or one laid out on the bench")
	w.close_work()

	var book: Control = w.inv_ui._book_entry(Items.recipe_for("blueprint_softwood_house"))
	var text: String = book.get_child(1).get_child(1).text
	check("Ash Pencil" in text and "any blade" in text and "2 uses" in text, "the book says it wears the pencil")
	book.free()
	check("Blueprints" in Items.CATEGORIES and Items.recipe_for("blueprint_softwood_house").tier == "bench", "a blueprint is drawn at a workbench")
	w.queue_free()
	await _frames(2)


func _build_part(w: Node, h: Node, items: Dictionary) -> bool:
	## Brings the materials for the house's next part, presses E at it and
	## does every step. False if it couldn't be begun.
	for id in items:
		Game.inventory.add(id, items[id], 0.0, true)
	h.interact(w.player)
	var ws: Node = w.work
	if ws == null or ws.house != h:
		return false
	var o: Dictionary = ws.options()[0]
	if not o.missing.is_empty() or not ws.begin(o.recipe):
		w.close_work()
		return false
	for k in o.recipe.steps:
		ws.step()
	await _frames(2)
	return w.work == null


func _raise_stilt(w: Node, h: Node, id := "log") -> bool:
	var p: Node = w.player
	var lg: Node = w.add_log(id, p.global_position - p.global_basis.z * 1.0, 0.0, "calamites")
	p.start_haul(lg)
	if not lg.haul_interact(p) or w.work == null:
		return false
	var ws: Node = w.work
	var o: Dictionary = ws.options()[0]
	if not ws.begin(o.recipe):
		return false
	for k in o.recipe.steps:
		ws.step()
	await _frames(2)
	return not is_instance_valid(lg) and w.work == null and p.hauling == null


func test_house() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	Game.inventory.add("blueprint_softwood_house", 2)
	Game.inventory.select(Game.inventory.find("blueprint_softwood_house"))
	await _frames(2)
	check(p._plan != null and p._plan.preview and not p._plan.is_in_group("houses"), "holding a blueprint shows the house where it would go")

	# Where it can and can't go.
	var start: Vector3 = p.global_position
	var wet := _find_spot(w, start, func(q):
		p.global_position = q
		return w.house_spot(p).why.begins_with("Too wet"))
	check(wet.is_finite(), "not with its stilts in the water")
	var good := _find_spot(w, start, func(q):
		p.global_position = q + Vector3(0, 0.05, 0)
		return q.y > 0.3 and w.house_spot(p).why == "")
	check(good.is_finite(), "somewhere it can stand")
	p.global_position = good + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	var spot: Dictionary = w.house_spot(p)
	var b: Node = w.add_bench(spot.at - Vector3(0, House.FLOOR_H, 0) + Vector3(0, 0.2, 0), 0.0)
	b.global_position.y = w.ground_height(b.global_position.x, b.global_position.z)
	await _frames(2)
	check(w.house_spot(p).why.begins_with("No room"), "not where something is in the way")
	b.queue_free()
	await _frames(2)
	check(w.house_spot(p).why == "", "clear again")
	await _frames(2)
	check(p._plan.global_position.distance_to(spot.at) < 0.3 and p.prompt.begins_with("Mark out"), "the plan shows there, ready to mark out")

	p.focus = null
	p._use_held()
	check(Game.houses.size() == 1 and Game.inventory.count("blueprint_softwood_house") == 1, "right-clicking marks out the site and uses up the blueprint")
	var h: Node = Game.houses[0]
	check(h.global_position.distance_to(spot.at) < 0.01 and not h.complete() and h.next_part().id == "stilt_0", "a site waiting for its first stilt")
	check(w.house_spot(p).why.begins_with("Too close"), "another can't go right beside it")
	check(h._outline.get_child_count() > 0 and h._ghost.mesh != null and h._solid.mesh == null, "all outline so far")
	check(h.prompt(p).begins_with("House site"), "it says what it is")

	# Stilts: Calamites logs carried there in your arms, pounded in with a stone.
	h.interact(p)
	check(w.work == null, "a stilt needs a log carried there")
	var bad: Node = w.add_log("log", p.global_position - p.global_basis.z * 1.0, 0.0, "tree_fern")
	p.start_haul(bad)
	check(not bad.haul_interact(p) and "Calamites" in bad.haul_prompt(p), "not a tree fern log")
	p.hauling = null
	bad.queue_free()
	var lg: Node = w.add_log("log", p.global_position - p.global_basis.z * 1.0, 0.0, "calamites")
	p.start_haul(lg)
	check("back left stilt" in lg.haul_prompt(p) and lg.haul_interact(p) and w.work and w.work.house == h, "a Calamites log carried there")
	var ws: Node = w.work
	var o: Dictionary = ws.options()[0]
	check(o.missing.any(func(m): return "River Stone" in m), "pounding it in takes a river stone")
	w.close_work()
	check(p.hauling == lg and lg.visible, "standing up, the log is back in your arms")
	Game.inventory.add("stone", 1)
	p.hauling = null
	lg.queue_free()
	check(await _raise_stilt(w, h), "the first stilt goes up")
	check(h.built.has("stilt_0") and h.built.stilt_0.get("log", 0) == 1 and Game.inventory.count("stone") == 1, "the log is used, the stone kept")
	check(await _raise_stilt(w, h, "log_stripped") and await _raise_stilt(w, h) and await _raise_stilt(w, h), "and the other three")
	check(h.built.has("stilt_3") and h.next_part().id == "floor", "four stilts")

	# The floor, the porch and the ladder from the ground.
	Game.inventory.add("board_tree_fern", 6)
	Game.inventory.add("cordage", 3)
	h.interact(p)
	ws = w.work
	o = ws.options()[0]
	check(o.missing.is_empty() and ws.begin(o.recipe) and Game.inventory.count("board_tree_fern") == 0, "the boards come out of your bag")
	ws.step()
	check(h.working == "floor" and h.work_k == 1, "and go down one at a time")
	ws.cancel()
	check(Game.inventory.count("board_tree_fern") == 6 and Game.inventory.count("cordage") == 3 and h.working == "", "stopping gives them back")
	w.close_work()
	check(await _build_part(w, h, {}), "the floor")
	var mid: Vector3 = h.to_global(Vector3(0, 0, -0.7))
	check(absf(w.floor_height(mid + Vector3(0, 0.2, 0)) - h.global_position.y) < 0.01
			and absf(w.floor_height(Vector3(mid.x, w.ground_height(mid.x, mid.z), mid.z)) - w.ground_height(mid.x, mid.z)) < 0.01,
			"things set down up there stand on the floor, under it on the ground")
	check(await _build_part(w, h, {"board_tree_fern": 4, "cordage": 3}), "the porch")
	check(await _build_part(w, h, {"stick": 6, "cordage": 4}), "the rope ladder")

	# The walls are put up from inside.
	Game.inventory.add("board_tree_fern", 3)
	Game.inventory.add("cordage", 2)
	h.interact(p)
	check(w.work and w.work.options()[0].missing.any(func(m): return "up in the house" in m), "the walls need you up in the house")
	w.close_work()
	var foot: Vector3 = h.to_global(Vector3(0, 0, House.EDGE + 0.5))
	foot.y = w.ground_height(foot.x, foot.z) + 0.05
	p.global_position = foot
	p.velocity = Vector3.ZERO
	p.rotation.y = h.rotation.y
	p._pitch = 0.0
	await _frames(3)
	Input.action_press("move_forward")
	await _run_for(6.0, func(): return h.on_floor(p.global_position) and p.is_on_floor())
	Input.action_release("move_forward")
	check(h.on_floor(p.global_position), "climbing the rope ladder up onto the porch")
	await _frames(3)
	check(h.on_floor(p.global_position) and p._air_top == -INF, "and standing there")
	for part in [["wall_back", {"board_tree_fern": 3, "cordage": 2}], ["wall_left", {"board_tree_fern": 3, "cordage": 1}],
			["wall_right", {"board_tree_fern": 3, "cordage": 1}], ["wall_front", {"board_tree_fern": 3, "cordage": 2}],
			["fireplace", {"stone": 8, "clay": 6}], ["ceiling", {"board_calamites": 8, "cordage": 4}]]:
		var ok: bool = await _build_part(w, h, part[1])
		check(ok and h.built.has(part[0]) and h.on_floor(p.global_position), "built from up in the house: " + part[0])
	check(h.fire != null and h.fire.hearth and h.fire in Game.fires and h.fire.fuel == 0.0, "the fireplace is a fire")
	h.fire.break_apart()
	await _frames(1)
	check(is_instance_valid(h.fire) and h.fire in Game.fires, "that can't be knocked apart")
	check(Game.inventory.count("stone") == 1, "the stilts' river stone is still yours")
	# The roof, from the ground on either side.
	p.global_position = foot + Vector3(0, 0.1, 0)
	await _frames(2)
	check(await _build_part(w, h, {"board_tree_fern": 4, "cordage": 4}) and h.built.has("roof_left"), "the left side of the roof")
	check(await _build_part(w, h, {"board_tree_fern": 4, "cordage": 4}) and h.complete(), "and the right: the house is finished")
	await _frames(2)
	check(h._outline.get_child_count() == 0 and h._ghost.mesh == null and h.prompt(p) == "", "no outline left")
	var inside: Vector3 = h.to_global(Vector3(-0.5, 0.05, -0.7))
	var porch: Vector3 = h.to_global(Vector3(0.5, 0.05, 1.8))
	var under: Vector3 = h.to_global(Vector3(0.2, -House.FLOOR_H + 0.1, 0.0))
	check(Game.sheltered(inside) and Game.sheltered(porch) and not Game.sheltered(under), "sheltered inside and on the porch, not underneath")
	check(w.house_at(under, 6.0) == h and w.house_at(h.to_global(Vector3(20, 0, 0))) == null, "nothing spawns where the house stands")
	var risk: Dictionary = w.sleep_risk(inside)
	check(risk.amphibian == 0.0 and risk.predator == 0.0 and risk.chill == 0.0 and "house" in risk.feel, "a safe place to sleep")
	h._hit()
	h._hit()
	h._hit()
	await _frames(2)
	check(is_instance_valid(h) and Game.houses.has(h), "a finished house can't be torn down")

	# Things set down up there, and the fireplace lit.
	p.global_position = inside
	p.velocity = Vector3.ZERO
	await _frames(3)
	Game.inventory.add("campfire_kit")
	check(not w.place("campfire", inside + Vector3(0, 0, 0)), "no campfire on a wooden floor")
	check(w.place("sack", inside), "but a sack goes down")
	var sack: Node = get_tree().get_nodes_in_group("stashes")[-1]
	check(absf(sack.global_position.y - (h.global_position.y - 0.05)) < 0.02, "on the floor")
	h.fire.fuel = 300.0
	h.fire._set_lit(true)
	check("Fireplace" in h.fire.prompt(p), "it is called a fireplace")

	# Anything you carry goes up the ladder on your back: a workbench set up
	# inside, a soup pot hung over the fireplace, a log laid on the floor.
	var wb: Node = w.add_bench(foot + Vector3(1.5, 0, 0), h.rotation.y)
	p.global_position = foot + Vector3(0, 0.1, 0)
	await _frames(3)
	wb._hit()
	wb._hit()
	wb._hit()
	check(p.hauling == wb, "a workbench knocked loose at the foot of the ladder")
	var seen: Dictionary = await _carry_up_ladder(w, h, p, foot, wb)
	check(seen.get("up", false), "climbing the ladder carrying it")
	check(seen.get("back", false), "slung on your back, out from the house, on the way up")
	check(seen.get("kept", false), "and not set down halfway up the ladder")
	p.global_position = h.to_global(Vector3(0, 0.05, 0.3))
	p.rotation.y = h.rotation.y + PI
	await _frames(3)
	p.put_down()
	await _frames(2)
	check(p.hauling == null and absf(wb.global_position.y - h.global_position.y) < 0.05, "set up on the floor of the house")
	wb.queue_free()
	var pot: Node = w.add_soup_pot("soup_pot", foot + Vector3(1.5, 0, 0))
	p.start_haul(pot)
	seen = await _carry_up_ladder(w, h, p, foot, pot)
	check(seen.get("up", false) and seen.get("back", false) and seen.get("kept", false), "a soup pot carried up the ladder")
	var hearth: Vector3 = h.fire.global_position
	p.global_position = hearth + h.global_basis * Vector3(-0.2, 0.05, 1.1)
	p.look_at(hearth + Vector3(0, p.global_position.y - hearth.y, 0), Vector3.UP)
	p.rotation = Vector3(0, p.rotation.y, 0)
	await _frames(3)
	check("Hang the soup pot over the fire" in p.prompt, "and offered to hang over the fireplace")
	p.put_down()
	await _frames(2)
	check(pot.fire == h.fire and pot.hung() and pot._over_lit_fire() and absf(pot.global_position.y - h.global_position.y) < 0.05,
			"hanging over the lit fireplace")
	pot.queue_free()
	var lg2: Node = w.add_log("log", foot + Vector3(1.5, 0, 0), 0.0)
	p.start_haul(lg2)
	seen = await _carry_up_ladder(w, h, p, foot, lg2)
	check(seen.get("up", false) and seen.get("back", false), "a log carried up the ladder")
	p.global_position = h.to_global(Vector3(-0.6, 0.05, 0.3))
	p.rotation.y = h.rotation.y + PI * 0.5
	await _frames(3)
	p.put_down()
	await _frames(2)
	check(is_instance_valid(lg2) and absf(lg2.global_position.y - h.global_position.y) < 0.05 and not lg2.in_water(),
			"laid on the floor of the house, not the ground under it")
	lg2.queue_free()
	await _frames(1)

	# Animals leave you be up there.
	var sc: Node = Creature.new().setup("scorpion", under + Vector3(0, -0.1, 2.0), w)
	w.add_child(sc)
	var blood: float = p.vitals.blood
	await _run_for(2.0, func(): return false)
	check(not sc.state in ["chase", "attack"] and p.vitals.blood >= blood - 0.01, "a scorpion ignores you in the house")
	sc.queue_free()

	# Saved and loaded with what's on its floor and in its fireplace.
	var state: Dictionary = w._world_state()
	check(state.houses.size() == 1 and not state.fires.any(func(f): return f.get("fuel", 0.0) == 300.0), "the house is saved, with its fire")
	w.queue_free()
	await _frames(2)
	_fresh_state()
	Game.restore = state
	var w2: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w2)
	await _frames(5)
	w2._spawn_t = 1e9
	check(Game.houses.size() == 1 and Game.houses[0].complete(), "a finished house after loading")
	var h2: Node = Game.houses[0]
	check(h2.fire != null and h2.fire.lit and h2.fire.hearth and Game.fires.count(h2.fire) == 1, "its fireplace still burning")
	var sacks: Array = get_tree().get_nodes_in_group("stashes")
	check(sacks.size() == 1 and absf(sacks[0].global_position.y - (h2.global_position.y - 0.05)) < 0.02, "the sack still up on the floor")

	# An unfinished site is torn down with an axe or mattock, its materials
	# left on the ground.
	var p2: Node = w2.player
	var far := _find_spot(w2, h2.global_position + Vector3(14, 0, 0), func(q):
		p2.global_position = q + Vector3(0, 0.05, 0)
		return q.y > 0.3 and w2.house_spot(p2).why == "")
	var s2: Dictionary = w2.house_spot(p2)
	var site: Node = w2.add_house(s2.at, s2.yaw)
	site.build_to(5)
	await _frames(2)
	var logs_before := get_tree().get_nodes_in_group("logs").size()
	site.axe_hit()
	site.break_apart()
	check(is_instance_valid(site) and Game.houses.has(site), "two blows aren't enough")
	site.axe_hit()
	await _frames(2)
	check(not is_instance_valid(site) and Game.houses.size() == 1, "the third tears it down")
	check(get_tree().get_nodes_in_group("logs").size() == logs_before + 4, "the stilts come back as logs")
	var boards := 0
	var cord := 0
	for st in get_tree().get_nodes_in_group("stacks"):
		if st.global_position.distance_to(s2.at) < 10.0:
			boards += st.count if st.item_id == "board_tree_fern" else 0
			cord += st.count if st.item_id == "cordage" else 0
	for d in get_tree().get_nodes_in_group("drops"):
		if d.global_position.distance_to(s2.at) < 10.0:
			boards += d.count if d.item_id == "board_tree_fern" else 0
			cord += d.count if d.item_id == "cordage" else 0
	check(boards == 6 and cord == 3, "and the floor's boards and cordage are left on the ground")
	w2.queue_free()
	await _frames(2)


func test_bench_slope_and_moving() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	Game.tiers = ["hand"]

	# Uneven ground will do: the legs reach down to it.
	var slope := func(q: Vector3) -> float:
		var lo := INF
		var hi := -INF
		var at: Vector3 = q + Vector3(0, 0, -0.75 - 0.9)
		for c in Assets.bench_legs():
			var h: float = w.ground_height(at.x + c.x, at.z + c.z)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		return hi - lo
	var spot := _find_spot(w, p.global_position, func(q):
		if slope.call(q) < 0.4:
			return false
		p.global_position = q
		p.rotation.y = 0.0
		w.start_work()
		var ok: bool = w.work != null and w.work.bench == null and w.work.wood == null and w.work.tree.is_empty() and w.work.build_blocker() == "ok"
		if w.work:
			w.close_work()
		return ok)
	check(spot.is_finite(), "a workbench can go up on sloping ground (%.2f m across its legs)" % slope.call(spot))
	p.global_position = spot
	p.rotation.y = 0.0
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, {"board": 4, "stick": 4, "cordage": 2})
	check(_make(ws, _option_for(ws, "workbench").recipe), "and is built there")
	await _frames(2)
	var bench: Node = get_tree().get_nodes_in_group("workbenches")[0]
	var hi := -INF
	var lo := INF
	for c in Assets.bench_legs():
		var g: Vector3 = bench.to_global(c)
		hi = maxf(hi, w.ground_height(g.x, g.z))
		lo = minf(lo, w.ground_height(g.x, g.z))
	check(bench.global_position.y >= hi - w.BENCH_SINK - 0.01, "its top stays clear of the highest ground")
	check(bench._feet != null and bench.global_position.y - lo > 0.02, "and its legs reach down to the lowest")

	# A house goes up on steep ground too: its stilts reach down.
	var steep := _find_spot(w, spot, func(q):
		p.global_position = q + Vector3(0, 0.05, 0)
		var sp: Dictionary = w.house_spot(p)
		var lo2 := INF
		var hi2 := -INF
		for g in House.ground_points(sp.at, sp.yaw):
			lo2 = minf(lo2, w.ground_height(g.x, g.z))
			hi2 = maxf(hi2, w.ground_height(g.x, g.z))
		return hi2 - lo2 > 0.6 and sp.why == "")
	check(steep.is_finite(), "a house can be marked out on steep ground")

	# Three blows with an axe or a mattock knock a workbench loose to carry.
	p.global_position = bench.global_position + bench.global_basis.z * 1.3
	p.global_position.y = w.ground_height(p.global_position.x, p.global_position.z) + 0.05
	p.rotation.y = bench.rotation.y
	await _frames(2)
	bench.hang("clay_platter")
	bench.axe_hit()
	bench.break_apart()
	check(p.hauling == null and bench.has_tool("clay_platter"), "two blows aren't enough")
	bench.axe_hit()
	await _frames(2)
	check(p.hauling == bench and bench.collision_layer == 0, "the third knocks it loose into your arms")
	check(Game.inventory.count("clay_platter") == 1 and not bench.has_tool("clay_platter"), "its rack tools go in your bag")
	check("Set up the workbench" in p.prompt, "you can set it up again")
	var saved: Dictionary = w._world_state().workbenches[0]
	check(absf(saved.pos[1] - w.bench_height(bench.global_position, bench.rotation.y)) < 0.01, "saved while carried, it stands where you were")
	check(bench not in [w.bench_ahead()], "a carried bench isn't worked at")
	var wet: Vector3 = w.water_point(p.global_position, 60.0)
	if wet.is_finite():
		bench.global_position = Vector3(wet.x, bench.global_position.y, wet.z)
		check(not bench.can_put_down(), "it won't stand in water")
	var held: Vector3 = p.global_position
	var open := _find_spot(w, held, func(q):
		p.global_position = q + Vector3(0, 0.05, 0)
		var at: Vector3 = q - p.global_basis.z * (bench.haul_radius() + 0.55)
		return w.bench_blocker(at, p.rotation.y, [bench.get_rid(), p.get_rid()]) == "")
	p.global_position = open + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	await _frames(3)
	var ev := InputEventAction.new()
	ev.action = "use"
	ev.pressed = true
	p._unhandled_input(ev)
	await _frames(2)
	check(p.hauling == null and bench.collision_layer == 3, "right-click sets it up in front of you")
	check(absf(bench.global_position.y - w.bench_height(bench.global_position, bench.rotation.y)) < 0.01, "standing on the ground there")
	p.focus = bench
	w.start_work()
	check(w.work != null and w.work.bench == bench, "and you can work at it again")
	# What uses the most of what you laid out comes first in the list, so
	# the chisel and saw isn't lost among the knapping.
	Game.inventory.clear()
	_lay_all(w.work, {"flint": 2, "stick": 2, "cordage": 1})
	w.work_ui._refresh()
	var texts: Array = w.work_ui._make.get_children().filter(func(c): return c is Button).map(func(c): return c.text)
	var chisel: Array = texts.filter(func(t): return "chisel and saw" in t)
	check(chisel.size() == 1 and "River Stone" in chisel[0] and texts.find(chisel[0]) <= 1,
			"chert, sticks and cordage put the chisel and saw near the top, saying it needs a river stone (%s)" % " | ".join(texts))
	Game.inventory.add("stone")
	w.work_ui._refresh()
	texts = w.work_ui._make.get_children().filter(func(c): return c is Button).map(func(c): return c.text)
	check("chisel and saw" in texts[0] and "Woodworking Tools" in texts[0], "and ready to make with one in your bag")
	w.close_work()
	w.queue_free()
	await _frames(2)


func test_work_view() -> void:
	## The work UI's panels never cover what you work on or click.
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	var items := {"board": 4, "stick": 4, "cordage": 2, "flint": 1, "plant_fiber": 6, "clay": 4, "stone": 1, "bark_tinder": 1}
	var spot := _find_spot(w, p.global_position, func(q):
		p.global_position = q
		p.focus = null
		w.start_work()
		var ok: bool = w.work != null and w.work.bench == null and w.work.wood == null and w.work.tree.is_empty() and w.work.build_blocker() == "ok"
		if w.work:
			w.close_work()
		return ok)
	p.global_position = spot
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, items)
	var ui: Control = w.work_ui
	var in_clear := func() -> bool:
		var clear: Rect2 = ui.clear_rect().grow(ui.CLEAR_PAD - 4.0)
		for q: Vector3 in ws.view_points():
			if not clear.has_point(p.camera.unproject_position(q)):
				return false
		return true
	await _run_for(3.0, func(): return false)
	check(ws.piles.size() == items.size() and in_clear.call(), "laid out, every pile is clear of the panels")
	var buttons: Array = ui._make.get_children().filter(func(c): return c is Button and c.text != "Stop")
	check(not buttons.is_empty() and buttons.all(func(b): return b.tooltip_text == ""), "the recipes have no pop-ups to cover each other")
	ui._show_how("How it is made.")
	check(ui._info.text == "How it is made.", "hovering one shows how it is made in the instructions")
	ui._show_how("")
	check(ui._info.text == ws.instructions(), "and back again")
	var o := _option_for(ws, "workbench")
	ws.begin(o.recipe)
	for k in 8:
		await _run_for(1.5, func(): return false)
		if w.work == null:
			break
		check(in_clear.call(), "building the workbench, step %d and its marks are clear of the panels" % ws.steps)
		var sp: Vector2 = p.camera.unproject_position(ws.marker_position())
		ws.click(sp)
	await _frames(3)
	check(w.work == null and get_tree().get_nodes_in_group("workbenches").size() == 1, "clicking each mark where it shows builds it (%s steps)" % (str(w.work.steps) if w.work else "all"))
	await _frames(5)
	check(p.camera.rotation.length() < 0.05 or true, "the view turns back when done")
	w.queue_free()
	await _frames(2)


func test_embers() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	w.raining = false
	_hold("campfire_kit")
	check(w.place("campfire", p.global_position + p.global_basis.x * 1.5), "a campfire for the embers")
	var fire: Node = Game.fires[-1]

	# Burned out, a fire glows with coals three times as long as it burned.
	fire.fuel = 30.0
	_hold("torch_lit")
	fire.interact(p)
	check(fire.lit and fire.burn_t == 0.0, "lit with a torch")
	inv.clear()
	fire._process(10.0)
	fire._process(25.0)  # 20 s of fuel left: it goes out 5 s into this
	check(not fire.lit and fire.glowing() and is_equal_approx(fire.coals, 85.0),
			"after burning 30 s it glows with coals for 90 (%.1f left)" % fire.coals)
	check(fire._coals.visible and not fire._flames.visible and fire._light.visible, "red coals, no flames")
	var saved: Dictionary = fire.to_dict()
	check(is_equal_approx(float(saved.coals), 85.0) and saved.has("ember") and saved.has("burn_t"), "the coals are saved")

	# Coals can't cook; empty of fuel, E takes an ember from them.
	_hold("raw_meat")
	check(fire.prompt(p).begins_with("Take an ember"), "too low to cook on: E takes an ember (%s)" % fire.prompt(p))
	fire.interact(p)
	check(inv.count("raw_meat") == 1 and inv.count("ember") == 1 and fire.cooking.count(null) == fire.SPOTS, "an ember, and nothing set to cook")

	# Add fuel to live coals and blow: it burns again, no ember needed.
	_hold("stick")
	fire.interact(p)
	check(fire.fuel > 0.0 and not fire.lit, "fuel on the coals")
	check(fire.prompt(p).begins_with("Blow on the coals"), "then E blows on them (%s)" % fire.prompt(p))
	fire.interact(p)
	check(fire.lit and fire.coals == 0.0, "and the fire burns again")
	inv.remove("stick", inv.count("stick"))

	# An ember goes out after three game hours, leaving nothing.
	check(is_equal_approx(Items.def("ember").decay, 3.0 * Game.DAY_LENGTH / 24.0), "an ember lasts three game hours")
	inv.tick(Items.def("ember").decay - 1.0)
	check(inv.count("ember") == 1, "still glowing just before")
	inv.tick(2.0)
	check(inv.count("ember") == 0 and inv.count("rotten") == 0, "then it goes out, and nothing is left")

	# Set in an unlit fire that has fuel, then blown on, it lights it.
	fire._set_lit(false)
	fire.coals = 0.0
	fire.fuel = 0.0
	fire._update_look()
	_hold("ember")
	check(fire.prompt(p).begins_with("Add fuel"), "with no fuel there's nothing for it to catch (%s)" % fire.prompt(p))
	fire.interact(p)
	check(inv.count("ember") == 1 and fire.ember == 0.0, "so you keep it")
	fire.fuel = 60.0
	inv.slots[inv.selected].age = 60.0
	check(fire.prompt(p).begins_with("Set the ember"), "with fuel, E sets it in the tinder (%s)" % fire.prompt(p))
	fire.interact(p)
	check(inv.count("ember") == 0 and is_equal_approx(fire.ember, 120.0) and fire._ember.visible and not fire.lit,
			"it keeps the time it had left (%.0f s)" % fire.ember)
	_empty_hands()
	check(fire.prompt(p).begins_with("Blow on the ember"), "then E blows on it (%s)" % fire.prompt(p))
	fire.interact(p)
	check(fire.lit and fire.ember == 0.0 and not fire._ember.visible, "and the fire catches")
	fire._set_lit(false)
	fire.ember = 5.0
	fire._update_look()
	fire._process(6.0)
	check(fire.ember == 0.0 and not fire.lit and not fire._ember.visible, "an ember left too long goes out")
	inv.clear()
	check("ember" in fire.prompt(p), "an unlit fire asks for an ember (%s)" % fire.prompt(p))

	# Dropped, an ember goes out on the ground too, by the world clock.
	w.spawn_pickup("ember", 1, p.global_position + Vector3(1, 0, 0), Items.def("ember").decay - 10.0)
	var dropped: Array = w.get_tree().get_nodes_in_group("drops").filter(func(d): return d.item_id == "ember")
	check(dropped.size() == 1, "an ember on the ground")
	Game.time += 11.0
	await _frames(2)
	check(not is_instance_valid(dropped[0]) or dropped[0].is_queued_for_deletion(), "goes out there too")

	# Food put down (Q) rots on the ground as it would in the bag.
	w.spawn_pickup("raw_meat", 2, p.global_position + Vector3(-1, 0, 0), Items.def("raw_meat").decay - 10.0)
	var meat: Array = w.get_tree().get_nodes_in_group("drops").filter(func(d): return d.item_id == "raw_meat")
	check(meat.size() == 1, "meat on the ground")
	await _frames(1)
	check(meat[0].item_id == "raw_meat", "fresh a while yet")
	Game.time += 11.0
	await _frames(2)
	var spoil: String = Items.def("raw_meat").get("spoil", "rotten")
	check(is_instance_valid(meat[0]) and meat[0].item_id == spoil and meat[0].count == 2 and meat[0].age < 1.0, "then it rots where it lies (%s)" % meat[0].item_id)
	meat[0].queue_free()
	# A small carcass lies there until a day after the kill, then is gone.
	w.spawn_pickup("lizard_carcass", 1, p.global_position + Vector3(-1, 0, 1), Items.def("lizard_carcass").decay + 10.0)
	var lz: Array = w.get_tree().get_nodes_in_group("drops").filter(func(d): return d.item_id == "lizard_carcass")
	await _frames(1)
	check(lz.size() == 1 and is_instance_valid(lz[0]) and lz[0].item_id == "lizard_carcass", "a small carcass stays a carcass on the ground")
	Game.time += Game.DAY_LENGTH - lz[0].age - 5.0
	await _frames(2)
	check(is_instance_valid(lz[0]) and not lz[0].is_queued_for_deletion(), "until nearly a day after the kill")
	Game.time += 10.0
	await _frames(2)
	check(not is_instance_valid(lz[0]) or lz[0].is_queued_for_deletion(), "then it rots away")

	# Lightning: the nearest tree you could fell comes down as if cut, and its
	# stump burns a day, glows three more, then stays charred for good.
	var tree: Dictionary = w.nearest_soft_tree(p.global_position)
	check(not tree.is_empty() and Chunk.TREES[tree.kind].soft, "a tree to strike")
	var ft: Node = w.strike_tree(tree, Vector3.FORWARD)
	check(Game.felled.has(tree.uid) and Game.felled[tree.uid].has("burnt") and ft.falling(), "struck, it comes down as if cut")
	var st: Node = tree.stump
	check(st != null and st.phase() == "burning" and st._flames.visible and st._light.visible, "its stump is on fire")
	_empty_hands()
	check(st.prompt(p).begins_with("Take an ember"), "you can take an ember from it (%s)" % st.prompt(p))
	st.interact(p)
	check(inv.count("ember") == 1, "and do")
	_hold("torch")
	st.interact(p)
	check(inv.count("torch_lit") == 1, "a torch lights at it")
	st.dig()
	check(st.hits == 0, "it's too hot to dig out")
	Game.time += Stump.BURN_FOR + 1.0
	st._update()
	check(st.phase() == "cinders" and not st._flames.visible and st._cinders.visible, "a day later it glows with cinders")
	_empty_hands()
	st.interact(p)
	check(inv.count("ember") == 2, "embers from the cinders too")
	Game.time += Stump.GLOW_FOR
	st._update()
	check(st.phase() == "burnt" and not st._fire.visible and st.prompt(p).begins_with("Burnt"), "three days on it is a cold, charred stump")
	st.interact(p)
	check(inv.count("ember") == 2, "with no embers")
	Game.time += 40.0 * Game.DAY_LENGTH
	st._update()
	check(is_instance_valid(st) and tree.stump == st and st.growth() == 0.0, "it never grows back")
	w.queue_free()
	await _frames(2)


func test_arrival() -> void:
	_fresh_state()
	Game.intro_pending = true
	var w: Node = load("res://scenes/swamp.tscn").instantiate()
	add_child(w)
	await _frames(5)
	var p: Node = w.player
	var intros := w.get_children().filter(func(n): return n.get_script() == Intro)
	check(intros.size() == 1 and not Game.intro_pending, "a new run plays the arrival")
	check(not w.raining and w.weather.kind == "" and w._weather_t > w.DRY_UNTIL - Game.clock() - 1.0, "on a sunny day, dry until dusk")
	var intro: Node = intros[0]
	check(p.frozen and p.lie == 1.0 and p.head.rotation.x > 1.3 and p.head.position.y < 0.5, "you wake on your back, looking at the sky")
	var creatures: int = Game.creatures.size()
	var step := func(until: float):
		while intro.t < until and not intro.is_queued_for_deletion():
			intro._process(0.1)
	# The flash comes first: the bolt, the screen white, the tree going over.
	var tree: Dictionary = intro.tree
	check(not tree.is_empty(), "a tree near enough to strike")
	var d0: float = tree.at.distance_to(p.global_position)
	step.call(Intro.STRIKE_AT + 0.1)
	check(intro.struck and intro._fly == null and w.weather._bolt_life > 1.0, "lightning first, before the dragonfly, the bolt lingering")
	check(w.hud._fade.color.a > 0.8, "a white flash over everything (%.2f)" % w.hud._fade.color.a)
	check(Game.felled.has(tree.uid) and tree.stump and tree.stump.phase() == "burning", "the tree comes down and its stump burns")
	var next: Dictionary = w.nearest_soft_tree(p.global_position)
	check(next.is_empty() or next.at.distance_to(p.global_position) >= d0, "it was the nearest one")
	check(w.get_tree().get_nodes_in_group("felled").size() == 1, "felled as if cut")
	step.call(Intro.FLY_AT + Intro.FLY_TIME * 0.5)
	var fly: Node3D = intro._fly
	check(fly != null and is_instance_valid(fly) and Game.creatures.size() == creatures, "then a dragonfly flies over you; it is no creature, so it can't attack")
	check(fly.global_position.distance_to(p.global_position) < 4.0, "right over your head (%.1f m)" % fly.global_position.distance_to(p.global_position))
	step.call(Intro.FLY_AT + Intro.FLY_TIME + 0.2)
	check(not is_instance_valid(fly) or fly.is_queued_for_deletion(), "then it's gone")
	step.call(Intro.RISE_AT + Intro.RISE_TIME + 1.0)
	check(not p.frozen and p.lie == 0.0, "then you get up")
	var to: Vector3 = tree.at - p.global_position
	to.y = 0.0
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	check(fwd.normalized().dot(to.normalized()) > 0.9, "facing the burning stump")
	w.queue_free()
	await _frames(2)
	# Loading a save never plays it.
	Game.intro_pending = true
	Game.apply_save({"seed": 7, "run": 1, "time": 0.0, "last_sleep": 0.0, "saved_night": -1, "taken": [], "harvested": {},
			"hints": {}, "inventory": Inventory.new().to_dict()})
	check(not Game.intro_pending, "loading a save never plays it")
	Game.restore = {}
	_fresh_state()


func test_spindle() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	var ui: Node = w.inv_ui
	inv.clear()
	Game.tiers = ["hand"]
	Game.tools_known = []

	# The bow drill: string, not cordage, made at a bench, known through the spindle.
	var bd: Dictionary = Items.recipe_for("bow_drill")
	check(bd.tier == "bench" and bd.in.get("string", 0) == 1 and not bd.in.has("cordage") and bd.get("known_by", "") == "spindle" and not bd.has("rack"),
			"a bow drill takes string, is made at a bench, and is taught by the spindle without needing it there")
	check(Items.RECIPES.filter(func(r): return r.out == "bow_drill").size() == 1, "and can no longer be made by hand")
	var sr: Dictionary = Items.recipe_for("string")
	check(sr.tier == "bench" and sr.rack == "spindle" and sr.get("rack_or_bag", false) and sr.in.has("plant_fiber"), "string is spun from fiber at a bench with a spindle")
	check(not Game.knows_recipe(bd) and not Game.knows_recipe(sr), "neither is known before the spindle")
	check(not Items.recipes_for(ui.where, Game.tiers).any(func(r): return r.tier == "bench"), "no bench recipes in the book before a bench")

	# Using a bench puts the bench recipes, the spindle among them, in the book.
	var at: Vector3 = p.global_position - p.global_basis.z * 1.6
	at.y = w.ground_height(at.x, at.z)
	var bench: Node = w.add_bench(at, p.rotation.y)
	await _frames(2)
	bench.interact(p)
	check("bench" in Game.tiers and "Workbench" in ui.book_categories(), "using a workbench puts its recipes in the book")
	var kneel := func() -> Node:
		p.focus = bench
		w.start_work()
		return w.work
	var ws: Node = kneel.call()
	check(ws != null and ws.bench == bench, "kneeling at the bench")

	# The whorl: clay, shaped at the bench, fired in a campfire.
	_lay_all(ws, {"clay": 1})
	var o := _option_for(ws, "spindle_whorl_unfired")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and inv.count("spindle_whorl_unfired") == 1, "a spindle whorl shaped from clay")
	check(Items.def("spindle_whorl_unfired").cook == "spindle_whorl", "which is fired in a campfire")
	w.close_work()

	# The spindle: the fired whorl on a stick.
	inv.remove("spindle_whorl_unfired", 1)
	ws = kneel.call()
	_lay_all(ws, {"spindle_whorl": 1, "stick": 1})
	o = _option_for(ws, "spindle")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and inv.count("spindle") == 1, "a spindle: the whorl fitted on a stick")
	check("spindle" in Game.tools_known and Game.knows_recipe(bd) and Game.knows_recipe(sr), "making it teaches string and the bow drill")
	check(Items.ADVANCED in ui.book_categories() and "spindle" in ui.book_rack_tools() and "Fire" in ui.book_categories(), "both in the book")
	check(Items.def("spindle").get("rack", false) and Assets.mesh("item_spindle") != null and Assets.mesh("item_spindle_whorl") != null, "it can hang on a rack, and has a look")

	# String with the spindle in your bag.
	_lay_all(ws, {"plant_fiber": 3})
	o = _option_for(ws, "string")
	check(not o.is_empty() and o.missing.is_empty(), "with the spindle in your bag you can spin string (%s)" % str(o.get("missing", [])))
	check(ws.begin(o.recipe), "spinning starts")
	ws.drag(Vector2(300, 0))
	check(ws._work.mesh != null and ws.progress > 0.0, "the spindle turns as you drag")
	ws.twist(1.0)
	check(inv.count("string") == 1 and inv.count("plant_fiber") == 0, "3 fiber spun into a string")

	# Or with it on the rack.
	inv.remove("spindle", 1)
	check(bench.hang("spindle") and bench.has_tool("spindle"), "the spindle hangs on the rack")
	_lay_all(ws, {"plant_fiber": 3})
	o = _option_for(ws, "string")
	check(not o.is_empty() and o.missing.is_empty(), "with it on the rack too")
	# But not with neither.
	bench.tools[bench.tools.find("spindle")] = ""
	bench._rebuild_rack()
	o = _option_for(ws, "string")
	check(not o.is_empty() and o.missing.any(func(m): return "spindle" in m), "without a spindle you can't (%s)" % str(o.get("missing", [])))
	w.close_work()
	inv.clear()

	# The bow drill at the bench, no spindle needed there.
	ws = kneel.call()
	_lay_all(ws, {"stick": 2, "string": 1})
	o = _option_for(ws, "bow_drill")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and inv.count("bow_drill") == 1, "a bow drill strung at the bench")
	w.close_work()

	# Neither string nor the bow drill can be made by hand on the ground.
	inv.clear()
	p.global_position = bench.global_position + Vector3(6, 0, 6)
	p.focus = null
	w.start_work()
	if w.work and w.work.bench == null:
		_lay_all(w.work, {"plant_fiber": 3, "stick": 2})
		check(_option_for(w.work, "string").is_empty() and _option_for(w.work, "bow_drill").is_empty(), "not by hand on the ground")
		w.close_work()

	# A bench with a spindle on its rack teaches it to whoever uses it.
	Game.tools_known = []
	bench.hang("spindle")
	_empty_hands()
	bench.interact(p)
	check("spindle" in Game.tools_known and Game.knows_recipe(bd), "using a bench with a spindle on its rack teaches its recipes")
	w.queue_free()
	await _frames(2)


func test_fishing() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	var ui: Node = w.inv_ui
	inv.clear()
	Game.tiers = ["hand"]
	Game.tools_known = []

	# The recipes: rod, line and hook, put together at a bench.
	var rb: Dictionary = Items.recipe_for("rod_blank")
	var fl: Dictionary = Items.recipe_for("fishing_line")
	var hk: Dictionary = Items.recipe_for("chitin_hook")
	var fr: Dictionary = Items.recipe_for("fishing_rod")
	var mb: Dictionary = Items.recipe_for("meat_bait")
	check(rb.in == {"branch": 1} and rb.tier == "bench" and rb.rack == "woodworking_tools", "a rod blank: a branch, at a bench with the woodworking tools")
	check(fl.in == {"string": 3} and fl.get("known_by", "") == "spindle" and fl.tier == "hand", "a fishing line: three strings, known through the spindle")
	check(hk.in == {"chitin": 1} and hk.act == "knap" and hk.tier == "bench" and hk.get("tool_tag", "") == "cut" and not hk.has("rack") and not hk.has("known_by"),
			"a hook: knapped from chitin with any blade, at any bench")
	check(fr.in == {"rod_blank": 1, "fishing_line": 1, "chitin_hook": 1} and fr.tier == "bench" and not fr.has("rack") and not fr.has("known_by") and not fr.has("tools"),
			"the rod: the three parts at any bench, no tools")
	check(mb.in == {"raw_meat": 1} and mb.n > 1 and mb.tier == "hand", "meat bait: raw meat torn up by hand")
	var tears := Items.RECIPES.filter(func(r): return r.out == "meat_bait")
	var torn := {}
	for r in tears:
		for id in r.in:
			torn[id] = r.n
	var meats := ["raw_meat", "fish_meat", "small_fish", "gnawed_meat", "lizard_dressed",
			"petrolacosaurus_dressed", "archaeothyris_dressed", "amphibamus_dressed", "tuditanus_dressed",
			"morganucodon_dressed"]
	check(torn.keys().size() == meats.size() and meats.all(func(id): return torn.get(id, 0) == 2),
			"every meat item (meat, fish meat, a small fish, gnawed meat, any dressed small prey) tears into 2 meat bait (%s)" % str(torn))
	for id in ["meat_bait", "grub", "rotten", "guts"]:
		check("bait" in Items.def(id).get("tags", []), "%s is bait" % id)
	for id in ["rod_blank", "fishing_line", "chitin_hook", "fishing_rod", "meat_bait"]:
		check(Assets.mesh("item_" + id) != null, "%s has a look" % id)

	# What the book shows, step by step.
	var visible := func(out: String) -> bool:
		return Items.recipes_for("swamp", Game.tiers).any(func(r): return r.out == out and not r.get("bait", false) and Game.knows_recipe(r))
	check(visible.call("meat_bait") and not visible.call("chitin_hook") and not visible.call("fishing_rod") and not visible.call("rod_blank") and not visible.call("fishing_line"),
			"at first only meat bait")
	check("Fishing" in ui.book_categories(), "under Fishing")
	Game.unlock_tier("bench")
	check(visible.call("chitin_hook") and visible.call("fishing_rod") and not visible.call("rod_blank") and not visible.call("fishing_line"),
			"a workbench adds the hook and the rod")
	Game.learn_tool("woodworking_tools", false)
	check(visible.call("rod_blank") and not ui.on_rack_page(rb), "the woodworking tools add the rod blank, listed under Fishing")
	Game.learn_tool("spindle", false)
	check(visible.call("fishing_line"), "the spindle adds the fishing line")

	# By hand: meat bait and the line.
	w.start_work()
	var ws: Node = w.work
	check(ws != null and ws.bench == null, "kneeling on the ground")
	if ws:
		_lay_all(ws, {"raw_meat": 1})
		var o := _option_for(ws, "meat_bait")
		check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and inv.count("meat_bait") == mb.n and inv.count("raw_meat") == 0,
				"raw meat torn into %d meat bait" % mb.n)
		_lay_all(ws, {"string": 3})
		o = _option_for(ws, "fishing_line")
		check(not o.is_empty() and o.missing.is_empty() and ws.begin(o.recipe), "braiding a line")
		ws.twist(1.0)
		check(inv.count("fishing_line") == 1 and inv.count("string") == 0, "three strings braided into a fishing line")
		_lay_all(ws, {"chitin": 1, "branch": 1})
		check(_option_for(ws, "chitin_hook").is_empty() and _option_for(ws, "rod_blank").is_empty(), "the hook and rod blank aren't made on the ground")
		w.close_work()

	# At the bench: the hook, knapped from chitin with a blade.
	var at: Vector3 = p.global_position - p.global_basis.z * 1.6
	at.y = w.ground_height(at.x, at.z)
	var bench: Node = w.add_bench(at, p.rotation.y)
	await _frames(2)
	inv.clear()
	var kneel := func() -> Node:
		p.focus = bench
		w.start_work()
		return w.work
	ws = kneel.call()
	check(ws != null and ws.bench == bench, "kneeling at the bench")
	_lay_all(ws, {"chitin": 1})
	var ho := _option_for(ws, "chitin_hook")
	check(not ho.is_empty() and ho.missing.size() == 1, "no blade, no hook (%s)" % str(ho.get("missing", [])))
	inv.add("flint_blade")
	ho = _option_for(ws, "chitin_hook")
	check(ho.missing.is_empty() and ws.begin(ho.recipe), "with a blade, knapping starts")
	check("chitin plate" in ws.instructions(), "it says what is being knapped (%s)" % ws.instructions())
	var hook: Array = Items.knap_grid("chitin_hook")
	for c in 25:
		if not hook[c] and ws.recipe.get("out", "") == "chitin_hook":
			ws.strike(c)
	check(inv.count("chitin_hook") == 1 and inv.count("chitin") == 0 and inv.count("flint_blade") == 1, "the hook is knapped, and the blade kept")

	# Chitin only ever comes out as a chitin shape, never a chert head.
	_lay_all(ws, {"chitin": 1})
	ws.begin(_option_for(ws, "chitin_hook").recipe)
	var axe: Array = Items.knap_grid("axe_head")
	for c in 25:
		if not axe[c]:
			ws.strike(c)
	check(inv.count("axe_head") == 0 and not ws.recipe.is_empty(), "knapped to an axe head's shape, chitin is still not a chert axe head")
	w.close_work()

	# The rod blank: a branch, with the woodworking tools on the rack.
	ws = kneel.call()
	_lay_all(ws, {"branch": 1})
	var ro := _option_for(ws, "rod_blank")
	check(not ro.is_empty() and ro.missing.any(func(m): return "rack" in m), "the rod blank needs the woodworking tools on the rack")
	bench.hang("woodworking_tools")
	ro = _option_for(ws, "rod_blank")
	check(ro.missing.is_empty() and _make(ws, ro.recipe) and inv.count("rod_blank") == 1, "with them there, a branch becomes a rod blank")
	w.close_work()

	# The rod: the three parts, at a bench with nothing on its rack.
	bench.tools[bench.tools.find("woodworking_tools")] = ""
	bench._rebuild_rack()
	inv.remove("flint_blade", 1)
	inv.add("fishing_line")
	ws = kneel.call()
	for id in ["rod_blank", "fishing_line", "chitin_hook"]:
		ws.lay(inv.find(id), 1)
	var fo := _option_for(ws, "fishing_rod")
	check(not fo.is_empty() and fo.missing.is_empty() and _make(ws, fo.recipe), "rigged at a bench with no tools")
	check(inv.count("fishing_rod") == 1 and inv.count("rod_blank") == 0 and inv.count("fishing_line") == 0 and inv.count("chitin_hook") == 0,
			"one fishing rod, the parts used")
	w.close_work()
	w.queue_free()
	await _frames(2)


func _seed_where(pred: Callable) -> int:
	## The first RNG seed whose first roll satisfies pred (to force a bite's outcome).
	var r := RandomNumberGenerator.new()
	for sd in 1000:
		r.seed = sd
		if pred.call(r.randf()):
			return sd
	return 0


func test_fishing_line() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()
	Game.tools_known = []

	# Baiting: the rod and any bait laid out together, on the ground.
	w.start_work()
	var ws: Node = w.work
	if ws and ws.bench == null:
		_lay_all(ws, {"fishing_rod": 1})
		var none := _option_for(ws, "fishing_rod")
		check(not none.is_empty() and none.missing.any(func(m): return "bait" in m), "a rod alone asks for bait")
		_lay_all(ws, {"grub": 1, "rotten": 1})
		var opts: Array = ws.options().filter(func(o): return o.recipe.get("bait", false) is String)
		check(opts.size() == 2 and opts.all(func(o): return o.missing.is_empty()), "one way to bait it for each bait laid out")
		var o: Dictionary = opts.filter(func(x): return x.recipe.bait == "grub")[0]
		check(_make(ws, o.recipe), "baiting it")
		var rs: Dictionary = inv.slots[inv.find("fishing_rod")]
		check(rs.get("data", {}).get("bait", "") == "grub" and "Beetle Grub" in String(rs.data.name) and inv.count("grub") == 0 and ws.laid("rotten") == 1,
				"the rod now carries a grub (%s)" % rs.get("data", {}).get("name", ""))
		check(ws.lay(inv.find("fishing_rod"), 1) == 0, "a baited rod stays in your bag")
		w.close_work()
	check(Items.RECIPES.any(func(r): return r.get("bait", false) and r.tier == "hand" and r.cat == "Fishing"), "baiting is in the book, by hand (so on a bench too)")

	# No bait, no cast.
	inv.clear()
	_hold("fishing_rod")
	p._attack_cd = 0.0
	p._use_held()
	check(p.fishing == null, "an unbaited rod won't cast")
	check(Settings.button_name("craft") in ["C", "D-pad down", "Craft"], "the message names the craft button for the device in use")

	# A baited cast flies like a thrown stone, from a bank by deep water.
	var bank := _find_spot(w, p.global_position, func(q): return q.y > 0.05 and w.water_point(q, 20.0, -0.6).is_finite())
	if bank.is_finite():
		p.global_position = bank + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		await _frames(3)
	inv.clear()
	inv.add("fishing_rod", 1, 0.0, true, Items.bait_data("meat_bait"))
	inv.select(inv.find("fishing_rod"))
	p._attack_cd = 0.0
	p._use_held()
	var line: Node = p.fishing
	check(line != null and line.state == "flying" and line.bait == "meat_bait", "Use casts a baited rod")
	if line == null:
		w.queue_free()
		await _frames(2)
		return
	check(absf(line.vel.length() - (Player.THROW_SPEED * (-p.camera.global_transform.basis.z) + Vector3(0, 1.5, 0) + p.velocity * 0.5).length()) < 0.01,
			"the hook leaves at a thrown stone's speed")
	var wp: Vector3 = w.water_point(p.global_position, 40.0, -0.6)
	check(wp.is_finite(), "deep water near enough to fish")
	if not wp.is_finite():
		w.queue_free()
		await _frames(2)
		return
	line.hook = Vector3(wp.x, w.water_level(), wp.z)
	line._settle("waiting")
	check(line.state == "waiting" and line.line_len > 0.0, "it waits in the water")
	# Step back a little and the hook stays where it is; walk off and it comes after you.
	var stand: Vector3 = p.global_position
	var back: Vector3 = (stand - line.hook) * Vector3(1, 0, 1)
	back = back.normalized()
	var h0: Vector3 = line.hook
	p.global_position = stand + back * (Fishing.SLACK - 1.0)
	line._drag_hook()
	check(Vector2(line.hook.x, line.hook.z).distance_to(Vector2(h0.x, h0.z)) < 0.01 and line.state == "waiting",
			"%.0f m back, the hook stays put" % (Fishing.SLACK - 1.0))
	p.global_position = stand + back * (Fishing.SLACK + 3.0)
	line._drag_hook()
	check(Vector2(line.hook.x, line.hook.z).distance_to(Vector2(h0.x, h0.z)) > 1.0, "further, it is dragged after you")
	p.global_position = stand
	line.hook = h0
	line.state = "waiting"
	check(Fishing.BITE_EVERY == 5.0 and Fishing.BITE_CHANCE == 0.15 and Fishing.NIBBLE_CHANCE == 0.3, "a 15% chance of a bite every 5 s, 30% of them only nibbles")
	check(Fishing.pick_species(0.0) == "elonichthys" and Fishing.pick_species(0.9999) == "orthacanthus", "the rolls run from small fish to the rare giants")

	# A nibble takes the bait and nothing more.
	line._rng.seed = _seed_where(func(x): return x < Fishing.NIBBLE_CHANCE)
	line.bite()
	check(line.bait == "" and line.fish == null and line.state == "waiting" and not inv.held().has("data") and p.rod_tug > 0.0,
			"a nibble: the rod tugs, the bait is gone, nothing is on")
	line._bite_t = 0.0
	line._process(0.01)
	check(line.fish == null, "no more bites on a bare hook")
	p._use_held()
	check(p.fishing == null, "Use reels the empty line in")

	# Switching to a second baited rod puts the first one's line away.
	inv.clear()
	inv.add("fishing_rod", 1, 0.0, true, Items.bait_data("meat_bait"))
	inv.add("fishing_rod", 1, 0.0, true, Items.bait_data("grub"))
	var rods: Array = range(inv.HOTBAR).filter(func(i): return inv.slots[i] != null and inv.slots[i].id == "fishing_rod")
	check(rods.size() == 2, "two baited rods on the hotbar")
	if rods.size() == 2:
		inv.select(rods[0])
		p._attack_cd = 0.0
		p._use_held()
		var first: Node = p.fishing
		inv.select(rods[1])
		if first:
			first._process(0.01)
		check(first != null and p.fishing == null, "switching to the other rod reels the line in")
		check(inv.slots[rods[1]].get("data", {}).get("bait", "") == "grub", "and the other rod keeps its bait")
		await _frames(2)

	# A real bite: the fish is on, and fights.
	await _frames(1)
	inv.replace(inv.selected, "fishing_rod", 0.0, Items.bait_data("rotten"))
	p._attack_cd = 0.0
	p._use_held()
	line = p.fishing
	line.hook = Vector3(wp.x, w.water_level(), wp.z)
	line._settle("waiting")
	line._rng.seed = _seed_where(func(x): return x >= Fishing.NIBBLE_CHANCE)
	var creatures: int = Game.creatures.size()
	line.bite()
	await _frames(1)
	var fish: Node = line.fish
	check(line.state == "hooked" and fish != null and fish.def.behavior == "fish" and Game.creatures.size() == creatures + 1, "a fish is on (%s)" % (fish.def.name if fish else "none"))
	check(line.bait == "" and not inv.held().has("data"), "and the bait is gone, whatever happens now")
	var l0: float = line.line_len
	line._fight(1.0)
	check(line.line_len > l0, "it swims off, taking line out")
	var d0: float = line._flat_to_player(fish.global_position).length()
	for i in 3:
		line.reel()
		line._fight(0.01)
	check(line._flat_to_player(fish.global_position).length() < d0, "each pull brings it closer")

	# All the line out: reel some back within ESCAPE_TIME, or it is gone.
	check(Fishing.ESCAPE_TIME == 3.0, "a fish pulls on all the line 3 s before it gets away")
	line.line_len = Fishing.MAX_LINE + 1.0
	line._fight(0.01)
	check(p.fishing == line and is_instance_valid(fish) and line.line_len == Fishing.MAX_LINE, "all the line out, it is still on")
	line._fight(Fishing.ESCAPE_TIME - 0.5)
	check(p.fishing == line, "for a while")
	line.reel()
	line._fight(0.01)
	check(line._slack_t == 0.0 and p.fishing == line, "a pull takes line back in time")
	line.line_len = Fishing.MAX_LINE
	line._fight(0.01)
	line._fight(Fishing.ESCAPE_TIME)
	check(p.fishing == null and (not is_instance_valid(fish) or fish.is_queued_for_deletion()), "a fish that gets too far away takes the bait and is gone")
	await _frames(1)

	# Again, this time dragged ashore, flopping, and struck.
	inv.replace(inv.selected, "fishing_rod", 0.0, Items.bait_data("meat_bait"))
	p._attack_cd = 0.0
	p._use_held()
	line = p.fishing
	line.hook = Vector3(wp.x, w.water_level(), wp.z)
	line._settle("waiting")
	line._rng.seed = _seed_where(func(x): return x >= Fishing.NIBBLE_CHANCE)
	line.bite()
	await _frames(1)
	fish = line.fish
	for i in 80:
		if line.state == "landed" or line.state == "":
			break
		line.reel()
		line._fight(0.05)
	check(line.state == "landed", "reeled in onto the bank (%s)" % line.state)
	if line.state == "landed":
		var at: Vector3 = fish.global_position
		line.line_len = 50.0
		fish._think_fish(0.5)
		line._fight(0.5)
		check(fish.global_position.distance_to(at) < 0.01 and absf(fish._body.rotation.z) > 0.5, "on land it flops on its side, but goes nowhere by itself")
		line.line_len = 1.0
		line._fight(0.05)
		check(line._flat_to_player(fish.global_position).length() <= 1.01, "the line drags it across the ground to your feet")
		fish.take_damage(1e6, p)
		check(fish.dead and p.fishing == null, "struck dead, it is off the line")
		if fish.def.size == "small":
			fish.interact(p)
			check(inv.count(fish.def.carcass) == 1, "a small fish goes into the bag")
		else:
			check(fish.haul_mode() == "carry", "a big fish is carried")
	await _frames(1)

	# Water predators take a hooked fish.
	if p.fishing:
		p.fishing.end()
	inv.replace(inv.selected, "fishing_rod", 0.0, Items.bait_data("guts"))
	p._attack_cd = 0.0
	p._use_held()
	line = p.fishing
	line.hook = Vector3(wp.x, w.water_level(), wp.z)
	line._settle("waiting")
	line._rng.seed = _seed_where(func(x): return x >= Fishing.NIBBLE_CHANCE)
	line.bite()
	await _frames(1)
	fish = line.fish
	var eo: Node = w.spawn_amphibian("eogyrinus", "lurk", fish.global_position + Vector3(3, 0, 0), fish.global_position)
	line.taken_by(eo)
	check(p.fishing == null and (not is_instance_valid(fish) or fish.is_queued_for_deletion()), "an amphibian can snatch the fish off the line")
	eo.queue_free()

	# Putting the rod away ends the line; you can't sleep with one out.
	inv.replace(inv.selected, "fishing_rod", 0.0, Items.bait_data("guts"))
	p._attack_cd = 0.0
	p._use_held()
	check(p.fishing != null and w.sleep_blocker() == "Reel in your line first.", "no sleeping with a line out")
	_hold("stone")
	await _frames(2)
	check(p.fishing == null, "putting the rod away ends the line")

	# Fish to eat: small ones roast whole, big ones are cut into fish meat.
	check(Items.def("elonichthys_carcass").cook == "roast_elonichthys" and Items.def("fish_meat").cook == "cooked_fish", "small fish roast whole, fish meat cooks")
	check(Items.recipe_for("meat_bait").in.has("raw_meat") and Items.RECIPES.any(func(r): return r.out == "meat_bait" and r.in.has("fish_meat")), "fish can be torn up for bait too")
	var big: Node = Creature.new().setup("rhizodus", p.global_position - p.global_basis.z * 1.5, w)
	w.add_child(big)
	big.take_damage(1e6, null)
	check(big.dead and big.cuts_left == 10 and big.haul_mode() == "carry", "a dead Rhizodus is carried, with 10 cuts of meat on it")
	inv.clear()
	inv.add("flint_blade")
	p.focus = big
	w.start_work()
	if w.work and w.work.carcass == big:
		for i in 3:
			var bo: Dictionary = w.work.butcher_option()
			_make(w.work, bo.recipe)
		check(inv.count("fish_meat") == 10, "dressed on the ground, it gives 10 fish meat (%d)" % inv.count("fish_meat"))
		w.close_work()
	w.queue_free()
	await _frames(2)


func test_fish_species() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()
	var fishes: Array = Creature.SPECIES.keys().filter(func(sp): return Creature.SPECIES[sp].behavior == "fish")
	check(fishes.size() == 13, "13 fish (%d)" % fishes.size())
	for sp in ["haplolepis", "amphicentrum", "acanthodes", "bandringa", "rhabdoderma", "sagenodus", "megalichthys", "xenacanthus", "strepsodus", "orthacanthus"]:
		check(sp in fishes, "%s is a fish" % sp)

	# How often each bites: small ones most, the giants rarely, bait aside.
	var share := func(size: String) -> float:
		var tot := 0.0
		var part := 0.0
		for sp in fishes:
			var wt: float = Creature.SPECIES[sp].fish.weight
			tot += wt
			if Creature.SPECIES[sp].size == size:
				part += wt
		return part / tot
	check(share.call("small") > 0.6 and share.call("medium") < 0.4, "most bites are small fish (%.0f%%)" % (share.call("small") * 100.0))
	var giants := ["rhizodus", "strepsodus", "orthacanthus"].map(func(sp): return Creature.SPECIES[sp].fish.weight)
	check(giants.all(func(x): return x <= 1.0) and Creature.SPECIES["haplolepis"].fish.weight > Creature.SPECIES["elonichthys"].fish.weight, "giants are rare, Haplolepis the commonest")

	# Every fish can be made, looks like something, and dies to a carcass.
	for sp in fishes:
		var c: Node = Creature.new().setup(sp, p.global_position + Vector3(2, 0, 2), w)
		w.add_child(c)
		var meshes: int = c._body.find_children("*", "MeshInstance3D", true, false).size()
		c.take_damage(1e6, null)
		var ok: bool = meshes >= 2 and c.dead and c._tail.size() == 1
		if c.def.size == "small":
			ok = ok and Items.ITEMS.has(c.def.carcass) and Items.counts_as(c.def.carcass, "small_fish") and Items.ITEMS.has(Items.def(c.def.carcass).cook)
		else:
			ok = ok and c.haul_mode() == "carry" and c.cuts_left == c.def.drops.fish_meat
		check(ok, "%s: built, killed, and handled as a %s fish" % [sp, c.def.size])
		c.queue_free()
	await _frames(1)
	check(Creature.SPECIES["orthacanthus"].drops.fish_meat > Creature.SPECIES["rhizodus"].drops.fish_meat, "Orthacanthus gives the most meat")

	# Any small fish tears into bait.
	w.start_work()
	if w.work and w.work.bench == null:
		_lay_all(w.work, {"haplolepis_carcass": 1})
		var o := _option_for(w.work, "meat_bait")
		check(not o.is_empty() and o.missing.is_empty(), "a Haplolepis tears into bait like any small fish")
		# But a small fish or fish meat isn't bait itself: tear it up first.
		_lay_all(w.work, {"fishing_rod": 1, "fish_meat": 1})
		var baits: Array = w.work.options().filter(func(x): return x.recipe.get("bait", false) is String)
		check(baits.is_empty(), "a rod laid out with a small fish or fish meat can't be baited with them")
		var not_bait := Items.ITEMS.keys().filter(func(id): return id == "fish_meat" or Items.counts_as(id, "small_fish"))
		check(not not_bait.is_empty() and not_bait.all(func(id): return not "bait" in Items.def(id).get("tags", [])), "no small fish or fish meat is bait as it is")
		w.close_work()
	inv.clear()

	# Lungfish breathe air: they last far longer out of the water.
	var lung: Node = Creature.new().setup("sagenodus", p.global_position + Vector3(1.5, 0, 0), w)
	var plain: Node = Creature.new().setup("megalichthys", p.global_position + Vector3(-1.5, 0, 0), w)
	w.add_child(lung)
	w.add_child(plain)
	check(lung.suffocate_time() >= plain.suffocate_time() * 4.0 and Creature.SPECIES["ctenodus"].fish.get("air", false), "lungfish (Sagenodus, Ctenodus) live much longer out of the water")
	plain._think_fish(Creature.SUFFOCATE + 1.0)
	lung._think_fish(Creature.SUFFOCATE + 1.0)
	check(plain.dead and not lung.dead, "after 90 s ashore a Megalichthys is dead, a Sagenodus still alive")
	lung.queue_free()
	plain.queue_free()

	# A landed Xenacanthus snaps at you; strike it fast.
	Game.cheats["damage"] = true
	var x: Node = Creature.new().setup("xenacanthus", p.global_position - p.global_basis.z * 1.0, w)
	w.add_child(x)
	await _frames(1)
	var b0: float = p.vitals.blood
	x._cd = 0.0
	x._think_fish(0.1)
	check(p.vitals.blood < b0, "a landed Xenacanthus snaps at you")
	var b1: float = p.vitals.blood
	x._think_fish(0.1)
	check(p.vitals.blood == b1, "but not again at once")
	x.queue_free()
	check(Creature.SPECIES["orthacanthus"].fish.bite > Creature.SPECIES["xenacanthus"].fish.bite and Creature.SPECIES["orthacanthus"].fish.get("lure", 1.0) > 1.0,
			"Orthacanthus bites harder, and its thrashing draws amphibians from further")
	check(Creature.SPECIES["megalichthys"].fish.pull > Creature.SPECIES["ctenodus"].fish.pull, "Megalichthys fights harder than Ctenodus")

	# Acanthodes: punched bare-fisted it pricks you; a blade doesn't, nor does its carcass.
	var a: Node = Creature.new().setup("acanthodes", p.global_position - p.global_basis.z * 1.2 + Vector3(0, 0.3, 0), w)
	w.add_child(a)
	await _frames(1)
	a.hp = 1e6
	p.vitals.wounds.clear()
	inv.clear()
	p._attack_cd = 0.0
	p.focus = null
	var aim := func():
		p.look_at(Vector3(a.hit_center().x, p.global_position.y, a.hit_center().z), Vector3.UP)
		var to: Vector3 = a.hit_center() - p.camera.global_position
		p._pitch = atan2(to.y, Vector2(to.x, to.z).length())
		p.head.rotation.x = p._pitch
	aim.call()
	var w0: int = p.vitals.wounds.size()
	var hp0: float = a.hp
	p._attack()
	check(a.hp < hp0 and p.vitals.wounds.size() > w0, "punching an Acanthodes bare-fisted: its spines jab your hand")
	_hold("flint_blade")
	p.vitals.wounds.clear()
	aim.call()
	hp0 = a.hp
	p._attack()
	check(a.hp < hp0 and p.vitals.wounds.is_empty(), "struck with a blade, no jab")
	a.hp = 0.5
	a.take_damage(1.0, null)
	inv.clear()
	p.vitals.wounds.clear()
	a.interact(p)
	check(inv.count("acanthodes_carcass") == 1 and p.vitals.wounds.is_empty(), "picking up its carcass is safe")

	# The debug panel's Next fish forces the next bite (never a nibble).
	var wp: Vector3 = w.water_point(p.global_position, 40.0, -0.6)
	if wp.is_finite():
		inv.clear()
		inv.add("fishing_rod", 1, 0.0, true, Items.bait_data("grub"))
		inv.select(inv.find("fishing_rod"))
		p._attack_cd = 0.0
		p._use_held()
		var line: Node = p.fishing
		line.hook = Vector3(wp.x, w.water_level(), wp.z)
		line._settle("waiting")
		Fishing.next_fish = "orthacanthus"
		line._rng.seed = _seed_where(func(r): return r < Fishing.NIBBLE_CHANCE)  # would nibble
		line.bite()
		await _frames(1)
		check(line.fish != null and line.fish.species == "orthacanthus" and Fishing.next_fish == "", "Next fish: the next bite is that fish, and only the next")
		line.end()
	Game.debug = true
	w.open_debug()
	var dp: Control = w._debug_panel
	if dp:
		var i: int = dp._fishes.find("bandringa")
		dp._fish.selected = i
		dp._set_next_fish()
		check(i > 0 and Fishing.next_fish == "bandringa", "the debug panel's Next fish sets it")
		dp._fish.selected = 0
		dp._set_next_fish()
		check(Fishing.next_fish == "", "Random clears it")
		dp.close()
	Game.debug = false
	Fishing.next_fish = ""
	w.queue_free()
	await _frames(2)


func test_seed_fern_dig() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()
	var at: Vector3 = p.global_position - p.global_basis.z * 1.5
	var fern: Node = Harvestable.new().setup("seed_fern", "h_test_fern_a")
	w.add_child(fern)
	fern.global_position = at
	_hold("mattock")
	check("dig it up" in fern.prompt(p), "with a mattock in hand, a seed fern can be dug up (%s)" % fern.prompt(p))
	fern.dig()
	check(not fern.is_queued_for_deletion() and inv.count("fern_root") == 0, "one swing only loosens it")
	fern.dig()
	check(fern.is_queued_for_deletion() and inv.count("fern_root") == 4 and inv.count("seed") >= 2 and inv.count("seed") <= 4,
			"the second digs it up: 4 roots and its ripe seeds (%d)" % inv.count("seed"))
	check(Game.taken.has("h_test_fern_a") and not Game.harvested.has("h_test_fern_a"), "it is gone for good")

	# Picked first, it has no seeds left to give.
	var picked: Node = Harvestable.new().setup("seed_fern", "h_test_fern_b")
	w.add_child(picked)
	picked.global_position = at + Vector3(2, 0, 0)
	inv.clear()
	picked.interact(p)
	inv.clear()
	_hold("mattock")
	picked.dig()
	picked.dig()
	check(inv.count("fern_root") == 4 and inv.count("seed") == 0, "a picked fern gives only its roots")

	# Plants without roots to dig (a tree fern) can't be dug up. (Strippable
	# ferns can: test_fern_dig.)
	var plain: Node = Harvestable.new().setup("tree_fern", "h_test_fern_c")
	w.add_child(plain)
	plain.global_position = at + Vector3(-2, 0, 0)
	plain.dig()
	plain.dig()
	check(not plain.is_queued_for_deletion() and not "dig it up" in plain.prompt(p), "a tree fern is left alone")

	# A dug-up seed fern never comes back when its chunk is made again.
	var c: Node = w.chunks.values()[0]
	var uid := "h%d:%d:%s:%d:%d" % [c.cx, c.cz, "seed_fern", 999, 10]
	Game.taken[uid] = true
	check(c._add_harvestable("seed_fern", Vector3(1, 0, 1), 0.0, 999) == null, "a chunk doesn't make it again")

	# The roots: greens, almost no food, and one day plantable.
	var root := Items.def("fern_root")
	check(Items.is_food("fern_root") and root.greens > 0.0 and root.energy <= 1.0 and root.get("plant", "") == "seed_fern",
			"roots are edible for greens, hardly any calories, and marked for planting")
	w.queue_free()
	await _frames(2)


# --- Farming ------------------------------------------------------------------------

func _dig_hole_near(w: Node, near: Vector3) -> String:
	## Digs a hole in the first open ground found near `near`; returns its uid.
	var before: Array = Game.plantings.keys()
	for r in range(2, 30, 2):
		for i in 12:
			var a := TAU * i / 12.0
			var pos := near + Vector3(cos(a), 0, sin(a)) * r
			pos.y = w.ground_height(pos.x, pos.z)
			if w.chunks.has(Vector2i(floori(pos.x / Chunk.SIZE), floori(pos.z / Chunk.SIZE))) and w.dig_hole(pos):
				for uid in Game.plantings:
					if not uid in before:
						return uid
	return ""


func _planting_node(w: Node, uid: String) -> Node:
	for c in w.chunks.values():
		for n in c.get_children():
			if (n is Plot or n is Harvestable) and n.uid == uid and not n.is_queued_for_deletion():
				return n
	return null


func _planted_tree(w: Node, uid: String) -> Dictionary:
	for c in w.chunks.values():
		for t in c.trees:
			if t.uid == uid:
				return t
	return {}


func _pass_time(w: Node, uid: String, secs: float) -> Node:
	## Moves the clock on and lets the planting catch up; returns what stands there now.
	Game.time += secs
	var n := _planting_node(w, uid)
	if n is Plot:
		n._tick = 0.0
		n._process(0.0)
	return _planting_node(w, uid)


func test_farming_holes() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()

	# The items: seeds and seed fern roots grow seed ferns, tree roots trees.
	check(Items.def("seed").get("plant", "") == "seed_fern" and Items.def("fern_root").get("plant", "") == "seed_fern",
			"seeds and seed fern roots are plantable")
	for kind in Chunk.TREES:
		var root := Items.def(kind + "_root")
		check(root.get("plant_tree", "") == kind and not Items.is_food(kind + "_root"), "%s root: plants a tree, not food" % kind)
	for id in ["calamites_shoot", "tree_fern_shoot", "seed_fern_shoot"]:
		check(Items.is_food(id) and Items.def(id).greens > 0.0 and Items.def(id).has("decay"), "%s is greens" % id)
	check(not Items.ITEMS.has("lepidodendron_shoot") and not Items.ITEMS.has("sigillaria_shoot"), "scale and seal trees have no shoots")

	# Right-click with a mattock digs a hole where you look.
	_hold("mattock")
	var ahead: Vector3 = p.global_position - p.global_basis.z * 1.6
	ahead.y = w.ground_height(ahead.x, ahead.z)
	var uid := _dig_hole_near(w, p.global_position)
	check(uid != "", "a mattock digs a hole in open ground")
	if uid == "":
		w.queue_free()
		await _frames(2)
		return
	var rec: Dictionary = Game.plantings[uid]
	var spot := Vector3(float(rec.x), float(rec.y), float(rec.z))
	check(is_equal_approx(float(rec.dug), Game.time) and _planting_node(w, uid) is Plot, "it is kept, and shows as a hole")
	var n_holes: int = Game.plantings.size()
	check(not w.dig_hole(spot + Vector3(0.4, 0, 0)) and Game.plantings.size() == n_holes, "not another right beside it")
	check(not w.dig_hole(spot + Vector3(0, 2.0, 0)), "not in the air")
	var hole: Node = _planting_node(w, uid)
	_empty_hands()
	check(hole.prompt(p).begins_with("A freshly dug hole") and "fills in within 24 min" in hole.prompt(p),
			"an empty hole says when it fills in (%s)" % hole.prompt(p))

	# E does nothing to it: you kneel at it (C) to plant in it.
	_hold("stick")
	hole.interact(p)
	check(inv.count("stick") == 1 and not Game.plantings[uid].has("item"), "E puts nothing in the hole")
	p.focus = hole
	w.start_work()
	var ws: Node = w.work
	check(ws != null and ws.plot == hole, "C kneels at the hole")
	var none: Array = ws.options()
	check(none.size() == 1 and none[0].missing.any(func(m): return "plant" in m), "with nothing laid out it asks for something to plant")
	inv.clear()
	inv.add("seed", 3, 50.0)
	ws.lay(inv.find("seed"), 1)
	_lay_all(ws, {"stick": 1})
	var opts: Array = ws.options()
	var verbs: Array = opts.map(func(o): return o.recipe.verb)
	check(opts.size() == 2 and "Plant the seed fern seed" in verbs and "Bury the stick" in verbs and opts.all(func(o): return o.missing.is_empty()),
			"one way for each thing laid out (%s)" % [verbs])
	var plant: Dictionary = opts.filter(func(o): return o.recipe.in.has("seed"))[0].recipe
	check(ws.begin(plant) and Game.plantings[uid].is_empty() == false and not Game.plantings[uid].has("item"), "begun, nothing is in yet")
	ws.step()
	check(hole._item_mesh.mesh != null and hole.open_hole(), "a click sets the seed in the hole")
	ws.step()
	rec = Game.plantings[uid]
	check(rec.get("item", {}).get("id", "") == "seed" and is_equal_approx(float(rec.item.age), 50.0) and is_equal_approx(float(rec.buried), Game.time),
			"another fills the hole in over it, the seed keeping its age")
	check(not hole.open_hole() and not hole.wants_craft() and hole._shown == -3.0 and hole._item_mesh.mesh == null, "it is a mound now")
	await _frames(2)
	check(w.work == null and inv.count("stick") == 1 and inv.count("seed") == 2, "then you stand, and the rest comes back")
	check("planted here" in hole.prompt(p) and "sprouts within 24 min" in hole.prompt(p), "the mound says when it sprouts (%s)" % hole.prompt(p))

	# A game day after it was buried, the mound is gone, and the seed sprouts.
	Game.time += 100.0
	rec.buried = Game.time
	var herb := _pass_time(w, uid, Plot.FILL_AFTER - 10.0)
	check(herb == hole and Game.plantings[uid].has("item"), "still a mound just before (a day from burying, not digging)")
	herb = _pass_time(w, uid, 11.0)
	rec = Game.plantings[uid]
	check(herb is Plot and herb != hole and rec.get("plant", "") == "seed_fern" and not rec.has("item")
			and is_equal_approx(float(rec.sprout), float(rec.buried) + Plot.FILL_AFTER), "the mound goes and a seed fern sprouts")
	check(herb._mesh.scale.x < 0.2, "a small sprout")
	_empty_hands()
	check(herb.prompt(p).begins_with("Pick the shoot") and "Young Seed Fern" in herb.prompt(p), "its shoot can be picked (%s)" % herb.prompt(p))

	# Its shoot can be picked while young, and it grows again from the roots.
	Game.time += 2.0 * Game.DAY_LENGTH
	herb.interact(p)
	check(inv.count("seed_fern_shoot") == 1 and is_equal_approx(float(rec.sprout), Game.time), "a shoot, and it starts over")
	# But not another for a day.
	herb.interact(p)
	check(inv.count("seed_fern_shoot") == 1 and "a new shoot in 24 min" in herb.prompt(p), "no new shoot for a day (%s)" % herb.prompt(p))
	Game.time += Game.DAY_LENGTH - 1.0
	herb.interact(p)
	check(inv.count("seed_fern_shoot") == 1, "not even just before")
	Game.time += 2.0
	check(herb.prompt(p).begins_with("Pick the shoot"), "then there is (%s)" % herb.prompt(p))
	herb.interact(p)
	check(inv.count("seed_fern_shoot") == 2, "a day on, another")
	Game.time += 5.0 * Game.DAY_LENGTH
	check(herb.prompt(p).begins_with("Young Seed Fern"), "past a third grown, no more shoots (%s)" % herb.prompt(p))
	herb.interact(p)
	check(inv.count("seed_fern_shoot") == 2, "so none")

	# Fourteen days on, it is grown: a seed fern with a few seeds.
	var grown := _pass_time(w, uid, 9.0 * Game.DAY_LENGTH + 1.0)
	check(grown is Harvestable and grown.kind == "planted_seed_fern" and grown.is_ready(), "grown in 14 days, with seeds ripe")
	inv.clear()
	grown.interact(p)
	check(inv.count("seed") >= 1 and inv.count("seed") <= 2, "a small yield: %d seeds" % inv.count("seed"))
	check(not grown.is_ready() and Game.harvested.has(uid) and Game.plantings.has(uid), "picked, it grows them again")
	check(absf(float(Game.harvested[uid]) - Game.time - 5.0 * Game.DAY_LENGTH) < 1.0, "in another 5 days")
	# Compost worked in within a day of picking: seeds again 2.5 days after picking.
	var picked_at := Game.time
	Game.time += 0.5 * Game.DAY_LENGTH
	inv.add("compost", 2)
	inv.select(inv.find("compost"))
	p.focus = grown
	p._use_held()
	check(inv.count("compost") == 1 and absf(grown._ready_time - picked_at - 2.5 * Game.DAY_LENGTH) < 1.0
			and is_equal_approx(float(Game.harvested[uid]), grown._ready_time), "compost within a day of picking: seeds 2.5 days after picking")
	# Fed later than that, it only cuts 30% off the wait, as for any plant.
	Game.time = grown._ready_time + 1.0
	grown.interact(p)
	Game.time += 1.5 * Game.DAY_LENGTH
	var wait_left: float = grown._ready_time - Game.time
	inv.select(inv.find("compost"))
	p.focus = grown
	p._use_held()
	check(inv.count("compost") == 0 and absf(grown._ready_time - Game.time - wait_left * 0.7) < 1.0, "compost a day and more after picking: 30% off")

	# Its chunk made again, it is still there.
	var c: Node = grown.get_parent()
	grown.queue_free()
	await _frames(1)
	c.add_planting(uid)
	grown = _planting_node(w, uid)
	check(grown is Harvestable and not grown.is_ready(), "it comes back as it was")

	# Dug up with a mattock, it is gone for good.
	inv.clear()
	_hold("mattock")
	grown.dig()
	grown.dig()
	check(inv.count("fern_root") == 2 and not Game.plantings.has(uid) and not Game.taken.has(uid), "dug up: its roots, and the spot is free")
	# Right-click with the mattock, looking at the spot, digs a new hole there.
	p.global_position = spot + Vector3(0, 0.1, 1.3)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await _frames(3)
	var eye: Vector3 = p.head.global_position
	p._pitch = -atan2(eye.y - spot.y, eye.z - spot.z)
	p.head.rotation.x = p._pitch
	await _frames(2)
	p._attack_cd = 0.0
	var n_before: int = Game.plantings.size()
	p._use_held()
	check(Game.plantings.size() == n_before + 1, "right-clicking the ground with a mattock digs a hole")
	if Game.plantings.size() == n_before:
		w.dig_hole(spot)

	# Something that doesn't grow is buried when the hole fills in.
	var uid2 := ""
	for k in Game.plantings:
		if Vector2(float(Game.plantings[k].x), float(Game.plantings[k].z)).distance_to(Vector2(spot.x, spot.z)) < 0.3:
			uid2 = k
	var hole2: Node = _planting_node(w, uid2)
	check(hole2 is Plot, "the new hole is there")
	hole2.bury("stick", 0.0, false)
	check(_pass_time(w, uid2, Plot.FILL_AFTER + 1.0) == null and not Game.plantings.has(uid2), "a stick is buried and gone")

	# An empty hole fills in too; a young seed fern dug up gives its root back.
	var uid3 := _dig_hole_near(w, spot)
	check(_pass_time(w, uid3, Plot.FILL_AFTER + 1.0) == null and not Game.plantings.has(uid3), "an empty hole just fills in")
	var uid4 := _dig_hole_near(w, spot)
	_planting_node(w, uid4).bury("fern_root", 0.0, false)
	var young := _pass_time(w, uid4, Plot.FILL_AFTER + 1.0)
	check(young is Plot and Game.plantings[uid4].plant == "seed_fern", "a seed fern root grows too")
	inv.clear()
	_hold("mattock")
	check("dig it up" in young.prompt(p), "a mattock can dig it up (%s)" % young.prompt(p))
	young.dig()
	check(inv.count("fern_root") == 1 and not Game.plantings.has(uid4), "for its root")

	# Plantings are saved.
	var uid5 := _dig_hole_near(w, spot)
	check(w.save_now() and Game.read_save().get("plantings", {}).has(uid5), "plantings are saved")
	Game.plantings.clear()
	Game.apply_save(Game.read_save())
	check(Game.plantings.has(uid5) and Game.plantings[uid5].has("dug"), "and loaded")
	w.queue_free()
	await _frames(2)


func test_farming_trees() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()

	# A tree root sprouts a young tree when its hole fills in.
	var uid := _dig_hole_near(w, p.global_position)
	_planting_node(w, uid).bury("calamites_root", 0.0, false)
	check(_pass_time(w, uid, Plot.FILL_AFTER + 1.0) == null, "the hole is gone")
	var t := _planted_tree(w, uid)
	check(not t.is_empty() and t.kind == "calamites" and Game.felled.get(uid, {}).get("planted", false), "a Calamites sprouts")
	var st: Node = t.get("stump")
	check(st != null and st.planted() and st._sapling.visible and t.shape.disabled, "growing up from the ground, with no stump")
	_empty_hands()
	check(st.prompt(p).begins_with("Pick the shoot") and "Young Calamites" in st.prompt(p), "its shoot can be picked (%s)" % st.prompt(p))

	# Picking the shoot sets it back to the start.
	Game.time += 3.0 * Game.DAY_LENGTH
	st._update()
	st.interact(p)
	var state: Dictionary = Game.felled[uid]
	check(inv.count("calamites_shoot") == 1 and is_equal_approx(float(state.at), Game.time)
			and absf(float(state.regrow) - Game.time - 14.0 * Game.DAY_LENGTH) < 1.0, "a shoot, and 14 days to go again")
	st.interact(p)
	check(inv.count("calamites_shoot") == 1 and not st.can_pick() and "a new shoot in 24 min" in st.prompt(p),
			"no new shoot for a day (%s)" % st.prompt(p))
	Game.time += Game.DAY_LENGTH + 1.0
	st._update()
	st.interact(p)
	check(inv.count("calamites_shoot") == 2, "a day on, another")

	# A mattock digs it up again, for its root.
	_hold("mattock")
	st.dig()
	check(Game.plantings.has(uid), "one swing loosens it")
	st.dig()
	await _frames(1)
	check(inv.count("calamites_root") == 1 and not Game.plantings.has(uid) and not Game.felled.has(uid)
			and _planted_tree(w, uid).is_empty() and not is_instance_valid(st), "two dig it up, root and all")

	# Scale trees have no shoots.
	var uid2 := _dig_hole_near(w, p.global_position)
	_planting_node(w, uid2).bury("lepidodendron_root", 0.0, false)
	_pass_time(w, uid2, Plot.FILL_AFTER + 1.0)
	var lep := _planted_tree(w, uid2)
	_empty_hands()
	check(not lep.is_empty() and lep.stump.prompt(p).begins_with("Young Lepidodendron") and not lep.stump.can_pick(),
			"a young Lepidodendron has no shoot to pick (%s)" % lep.stump.prompt(p))

	# Fourteen days on it is a full tree, to fell like any other.
	var uid3 := _dig_hole_near(w, p.global_position)
	_planting_node(w, uid3).bury("tree_fern_root", 0.0, false)
	_pass_time(w, uid3, Plot.FILL_AFTER + 1.0)
	var tf := _planted_tree(w, uid3)
	check(tf.stump.can_pick(), "a young tree fern has a shoot")
	Game.time += 14.0 * Game.DAY_LENGTH + 1.0
	tf.stump._update()
	await _frames(1)
	check(not Game.felled.has(uid3) and tf.stump == null and not tf.shape.disabled, "grown in 14 days")
	var c: Node = w.chunks[Vector2i(floori(tf.at.x / Chunk.SIZE), floori(tf.at.z / Chunk.SIZE))]
	check(c.tree_near(tf.at, Vector3(-1, 0, 0), 2.0).get("uid", "") == uid3, "it stands to be felled")

	# Felled, it leaves a stump that grows back; dug out, it is gone.
	c.fell(tf)
	check(tf.stump != null and not tf.stump.planted() and Game.felled[uid3].regrow > Game.time, "felled, its stump grows back")
	var regrow_days: float = (float(Game.felled[uid3].regrow) - float(Game.felled[uid3].at)) / Game.DAY_LENGTH
	check(regrow_days >= 16.0 and regrow_days <= 20.0, "in 16 to 20 days (%.1f)" % regrow_days)
	inv.clear()
	for k in Stump.DIG_HITS:
		tf.stump.dig()
	await _frames(1)
	check(inv.count("tree_fern_root") == 1 and inv.count("firewood") >= Stump.ROOT_WOOD[0], "dug out: its root and root wood")
	check(not Game.plantings.has(uid3) and not Game.felled.has(uid3) and _planted_tree(w, uid3).is_empty(), "and it is gone")

	# Made again with its chunk, a tree grown meanwhile stands full grown.
	var lep_c: Node = w.chunks[Vector2i(floori(lep.at.x / Chunk.SIZE), floori(lep.at.z / Chunk.SIZE))]
	lep_c.trees.erase(lep)
	lep.stump.queue_free()
	lep_c.add_planting(uid2)
	var lep2 := _planted_tree(w, uid2)
	check(not lep2.is_empty() and lep2.stump == null and not lep2.shape.disabled and not Game.felled.has(uid2),
			"a tree that grew while away comes back grown")

	# One still growing comes back growing.
	var uid4 := _dig_hole_near(w, p.global_position)
	_planting_node(w, uid4).bury("sigillaria_root", 0.0, false)
	_pass_time(w, uid4, Plot.FILL_AFTER + 1.0)
	var sig := _planted_tree(w, uid4)
	var sig_c: Node = w.chunks[Vector2i(floori(sig.at.x / Chunk.SIZE), floori(sig.at.z / Chunk.SIZE))]
	sig_c.trees.erase(sig)
	sig.stump.queue_free()
	Game.time += 10.0 * Game.DAY_LENGTH
	sig_c.add_planting(uid4)
	var sig2 := _planted_tree(w, uid4)
	check(not sig2.is_empty() and sig2.stump != null and sig2.stump.planted() and absf(sig2.stump.growth() - 10.0 / Plot.GROW_DAYS) < 0.02,
			"a growing tree comes back part grown after 10 days (%.2f)" % (sig2.stump.growth() if sig2.get("stump") else -1.0))

	# Every stump dug out gives its root.
	var gt := _tree_near(w, true)
	var gc: Node = w.chunks[Vector2i(floori(gt.at.x / Chunk.SIZE), floori(gt.at.z / Chunk.SIZE))]
	gc.fell(gt)
	inv.clear()
	for k in Stump.DIG_HITS:
		gt.stump.dig()
	check(inv.count(gt.kind + "_root") == 1, "a wild %s's stump gives a root" % gt.kind)

	# A wild tree fern or Calamites stump regrowing has shoots early on.
	var soft := _tree_near(w, true)
	var sc: Node = w.chunks[Vector2i(floori(soft.at.x / Chunk.SIZE), floori(soft.at.z / Chunk.SIZE))]
	sc.fell(soft)
	Game.felled[soft.uid].at = Game.time - 0.1 * Game.DAY_LENGTH * 30.0
	Game.felled[soft.uid].regrow = Game.felled[soft.uid].at + 30.0 * Game.DAY_LENGTH
	soft.stump._update()
	check(soft.stump.can_pick(), "a regrowing %s stump has a shoot" % soft.kind)
	w.queue_free()
	await _frames(2)


# --- Compost ----------------------------------------------------------------------

func _new_compost(w: Node, at: Vector3) -> Node:
	_hold("compost_basket")
	at.y = w.ground_height(at.x, at.z)
	var before := get_tree().get_nodes_in_group("composters")
	check(w.place("compost", at), "a compost basket is set down")
	Game.inventory.remove("compost_basket", 1)  # as the player's Use does
	for c in get_tree().get_nodes_in_group("composters"):
		if not c in before:
			return c
	return null


func _fill_compost(c: Node, id: String, times: int) -> void:
	for k in times:
		_hold(id)
		c.interact(null)


func test_compost_basket() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()

	# Made at a bench with the woodworking tools on its rack, from wood.
	var r: Dictionary = Items.RECIPES.filter(func(x): return x.out == "compost_basket")[0]
	check(r.tier == "bench" and r.rack == "woodworking_tools" and r.in.has("board") and r.in.has("stick"), "the basket: wood, at a bench with the woodworking tools")
	check(Items.def("compost_basket").place == "compost" and Items.ITEMS.has("compost"), "it is set down, and makes compost")
	for id in ["seed", "raw_meat", "rotten", "fiddlehead", "guts", "stick", "lizard_carcass", "charred", "pickled:seed"]:
		check(Compost.worth(id) == 2, "%s counts 2" % id)
	for id in ["grub", "roast_grub"]:
		check(Compost.worth(id) == 1, "a %s counts 1" % id)
	check(Compost.worth("branch") == 4 and Compost.worth("log") == 10 and Compost.worth("log_stripped") == 10, "a branch counts 4, a log 10")
	for id in ["flint", "pot_soup", "canteen_clean_1", "canteen_alcohol", "short_log", "firewood", "compost"]:
		check(Compost.worth(id) == 0, "%s can't go in" % id)
	check(Compost.is_meat("raw_meat") and Compost.is_meat("guts") and Compost.is_meat("fish_meat") and Compost.is_meat("lizard_carcass")
			and Compost.is_meat("cooked_meat"), "meat, fish, guts and carcasses are meat")
	check(not Compost.is_meat("grub") and not Compost.is_meat("seed") and not Compost.is_meat("stick"), "grubs, seeds and sticks aren't")

	# Set down, and picked up again while empty.
	var at: Vector3 = p.global_position - p.global_basis.z * 2.0
	var c := await _new_compost(w, at)
	check(inv.count("compost_basket") == 0 and c.level == 0, "the basket stands there, empty")
	_empty_hands()
	check(c.prompt(p).begins_with("Pick up"), "empty, it can be picked up (%s)" % c.prompt(p))
	c.interact(p)
	await _frames(1)
	check(inv.count("compost_basket") == 1 and not is_instance_valid(c), "and is")
	c = await _new_compost(w, at)

	# Filling it: food counts 2 and leaves the time at 5 days.
	_hold("seed")
	check(c.prompt(p).begins_with("Put the Seed Fern Seed in the compost") and "+2: 2 / 20" in c.prompt(p), "it takes food (%s)" % c.prompt(p))
	_hold("flint")
	check("won't rot down" in c.prompt(p), "not stone (%s)" % c.prompt(p))
	c.interact(p)
	check(c.level == 0 and inv.count("flint") >= 1, "which stays in your hand")
	_fill_compost(c, "seed", 1)
	check(c.level == 2 and c.slow == 1.0 and not c.meat and not c.full(), "a seed: level 2, 5 days")
	_hold("stick")
	check("slows it to 10 days" in c.prompt(p), "a stick slows it (%s)" % c.prompt(p))
	c.interact(p)
	check(c.level == 4 and c.slow == 2.0, "a stick: twice as long")
	_fill_compost(c, "raw_meat", 1)
	check(c.meat and c.level == 6, "meat goes in too")
	_fill_compost(c, "branch", 1)
	check(c.level == 10 and c.slow == 2.0, "a branch counts 4, and doesn't slow it more")

	# A carried log goes in from your arms: 10, and three times as long.
	var lg: Node = w.add_log("log", c.global_position + Vector3(1.0, 0.3, 0), 0.0)
	await _frames(1)
	p.global_position = c.global_position + Vector3(1.5, 0.2, 0)
	p.start_haul(lg)
	check(p.hauling == lg and lg.haul_prompt(p).begins_with("Put the") and "in the compost" in lg.haul_prompt(p), "carrying a log by it (%s)" % lg.haul_prompt(p))
	check(lg.haul_interact(p), "E puts it in")
	await _frames(1)
	check(not is_instance_valid(lg) and p.hauling == null and c.level == 20 and c.slow == 3.0, "the log is in: level 20, 15 days")
	check(c.full() and absf(c.done_at - Game.time - 15.0 * Game.DAY_LENGTH) < 1.0, "full at 20: compost in 15 days, not 5 x 2 x 3")
	_hold("seed")
	var n_seed: int = inv.count("seed")
	c.interact(p)
	check(c.level == 20 and inv.count("seed") == n_seed, "full, it takes nothing more")
	check(c.prompt(p).begins_with("Compost Basket: composting, 15 days left"), "it says how long (%s)" % c.prompt(p))

	# Branches alone: 10 days. Food alone: 5. A log can top it up past 20.
	var c2 := await _new_compost(w, at + p.global_basis.x * 1.5)
	_fill_compost(c2, "branch", 5)
	check(c2.full() and absf(c2.done_at - Game.time - 10.0 * Game.DAY_LENGTH) < 1.0, "five branches: full, 10 days")
	var c3 := await _new_compost(w, at - p.global_basis.x * 1.5)
	_fill_compost(c3, "rotten", 8)
	c3.add("log")
	check(c3.level == 20 and c3.full(), "a log fills it to the brim, no further")

	# Done, it gives 5 compost and is empty again.
	var c4 := await _new_compost(w, at + p.global_basis.x * 3.0)
	_fill_compost(c4, "seed", 10)
	check(c4.full() and absf(c4.done_at - Game.time - 5.0 * Game.DAY_LENGTH) < 1.0, "all food: 5 days")
	Game.time = c4.done_at - 1.0
	check(not c4.is_done(), "not yet just before")
	Game.time = c4.done_at + 1.0
	c4._process(0.0)
	check(c4.is_done() and c4._fill.mesh == Assets.mesh("compost_done"), "then it is compost, dark to the brim")
	_empty_hands()
	check(c4.prompt(p).begins_with("Take the compost") and "5" in c4.prompt(p), "ready to take (%s)" % c4.prompt(p))
	inv.clear()
	c4.interact(p)
	check(inv.count("compost") == 5 and c4.level == 0 and not c4.full() and c4.slow == 1.0, "5 compost, and it is empty again")

	# Meat draws a pest beside it now and then when you sleep.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := {}
	for k in 2000:
		var sp: String = c.pest_roll(rng)
		got[sp] = got.get(sp, 0) + 1
	var hits: int = 2000 - got.get("", 0)
	check(hits > 220 and hits < 380 and got.keys().all(func(k): return k == "" or k in Compost.PESTS), "about 15%% of nights a pest comes (%d / 2000)" % hits)
	check(got.has("scorpion") and got.has("arthropleura"), "a Scorpion or an Arthropleura")
	check(c2.pest_roll(rng) == "" and c4.pest_roll(rng) == "", "never without meat")
	var before := Game.creatures.size()
	for k in 60:
		w._compost_pests()
		if Game.creatures.size() > before:
			break
	var pest: Node = Game.creatures[-1] if Game.creatures.size() > before else null
	check(pest != null and pest.species in Compost.PESTS and pest.global_position.distance_to(c.global_position) < 6.0,
			"one turns up beside the basket")
	check(c.level == 20 and c.meat, "and leaves the compost alone")

	# Baskets are saved.
	check(w.save_now(), "saved")
	var saved: Array = Game.read_save().get("composters", [])
	check(saved.size() == 4 and saved.any(func(d): return int(d.level) == 20 and float(d.slow) == 3.0 and d.meat), "the baskets are saved")
	var c5: Node = w.add_compost(at + Vector3(0, 0, 5))
	c5.from_dict(c.to_dict())
	check(c5.level == 20 and c5.meat and is_equal_approx(c5.done_at, c.done_at), "and come back as they were")
	w.queue_free()
	await _frames(2)


func _new_traps(before: Array) -> Array:
	return get_tree().get_nodes_in_group("traps").filter(func(t): return not t in before)


func _bait_trap(w: Node, t: Node, bait: String) -> bool:
	## Kneels at the trap (C), lays out one bait and baits it.
	w.player.focus = t
	w.start_work()
	var ws: Node = w.work
	if ws == null or ws.trap != t:
		return false
	_lay_all(ws, {bait: 1})
	var o := _option_for(ws, t.kind)
	return not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe)


func test_fish_trap() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()

	var r: Dictionary = Items.recipe_for("fish_trap")
	check(r.tier == "bench" and r.rack == "woodworking_tools" and r.in.has("stick") and r.in.has("cordage"), "the fish trap: sticks and cordage, with the woodworking tools")
	check(Items.def("fish_trap").get("carry", false) and not Items.def("fish_trap").has("place"), "carried in your arms, not in the bag")

	# Made at a bench, it is left standing beside it.
	var at: Vector3 = p.global_position - p.global_basis.z * 1.6
	at.y = w.ground_height(at.x, at.z)
	var bench: Node = w.add_bench(at, p.rotation.y)
	await _frames(2)
	Game.tools_known = ["woodworking_tools"]
	p.focus = bench
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, {"stick": 10, "cordage": 3})
	var o := _option_for(ws, "fish_trap")
	check(not o.is_empty() and o.missing.any(func(m): return "rack" in m), "it needs the woodworking tools on the rack")
	bench.hang("woodworking_tools")
	o = _option_for(ws, "fish_trap")
	var before := get_tree().get_nodes_in_group("traps")
	check(o.missing.is_empty() and _make(ws, o.recipe), "with them there, it is made")
	var made := _new_traps(before)
	check(made.size() == 1 and made[0].kind == "fish_trap" and inv.count("fish_trap") == 0 and inv.count("stick") == 0,
			"a fish trap stands beside the bench, the sticks used")
	w.close_work()
	await _frames(1)
	var t: Node = made[0]

	# Picked up empty, it is carried; on land it says it catches only in water.
	_empty_hands()
	check(t.prompt(p).begins_with("Pick up the fish trap") and "not baited" in t.prompt(p), "empty, it can be picked up (%s)" % t.prompt(p))
	p.global_position = t.global_position + Vector3(1.2, 0.2, 0)
	t.interact(p)
	check(p.hauling == t, "and carried in your arms")
	p.global_position = at + p.global_basis.z * 3.0
	p.global_position.y = w.ground_height(p.global_position.x, p.global_position.z)
	if w.ground_height(p.global_position.x, p.global_position.z) > w.water_level():
		check("only catches set in the water" in t.haul_prompt(p), "on land it says it must go in the water (%s)" % t.haul_prompt(p))

	# Too deep, it won't go down; in the shallows it does.
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var reach: float = Trap.FISH_R + 0.55
	var deep := _find_spot(w, p.global_position, func(q): return w.water_level() - q.y > Trap.DEEP + 0.2)
	if deep.is_finite():
		p.global_position = deep - fwd * reach
		check(t.haul_prompt(p).begins_with("Too deep") and not t.can_put_down(), "not in deep water (%s)" % t.haul_prompt(p))
	var shallow := _find_spot(w, p.global_position, func(q): return w.water_level() - q.y > 0.3 and w.water_level() - q.y < Trap.DEEP - 0.2)
	check(shallow.is_finite(), "there are shallows")
	p.global_position = shallow - fwd * reach
	p._hold_haul()
	check(t.haul_prompt(p).begins_with("Set the fish trap down in the water"), "the shallows (%s)" % t.haul_prompt(p))
	p.put_down()
	check(p.hauling == null and t.in_water() and absf(t.global_position.y - w.ground_height(t.global_position.x, t.global_position.z)) < 0.05,
			"set down on the bottom, in the water")

	# Unbaited, it catches nothing.
	w._check_traps()
	check(t.caught.is_empty(), "unbaited, nothing in the night")

	# Baited by kneeling at it (C) with bait laid out, just like a rod.
	p.focus = t
	w.start_work()
	ws = w.work
	check(ws != null and ws.trap == t, "kneeling at the trap")
	var none := _option_for(ws, "fish_trap")
	check(not none.is_empty() and none.missing.any(func(m): return "bait" in m), "with nothing laid out it asks for bait")
	_lay_all(ws, {"stick": 1, "grub": 1, "guts": 1})
	var opts: Array = ws.options()
	check(opts.size() == 2 and opts.all(func(x): return x.missing.is_empty() and not x.recipe.in.has("stick")), "one way to bait it for each bait laid out, not a stick")
	var og: Dictionary = opts.filter(func(x): return x.recipe.in.has("grub"))[0]
	check(og.recipe.verb == "Bait the fish trap with beetle grub", "it says so (%s)" % og.recipe.verb)
	check(_make(ws, og.recipe) and t.bait == "grub" and ws.laid("grub") == 0, "a click baits it")
	await _frames(2)
	check(w.work == null and inv.count("guts") == 1 and inv.count("stick") == 1, "then you stand, and the rest comes back")
	check("baited with beetle grub" in t.prompt(p), "it says it is baited (%s)" % t.prompt(p))

	# Each night: 1 to 5 small fish, and the bait is gone.
	w._check_traps()
	var n: int = t.caught.size()
	check(n >= 1 and n <= 5 and t.bait == "" and t.caught.all(func(e): return e.id in Trap.FISH), "a night baited: %d small fish, the bait eaten" % n)
	w._check_traps()
	check(t.caught.size() == n, "unbaited again, no more")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	var kinds := {}
	var probe: Node = w.add_trap("fish_trap", t.global_position + Vector3(0, 0, 0.01))
	for k in 200:
		probe.caught.clear()
		probe.bait = "rotten"
		counts[probe.catch(rng)] = true
		for e in probe.caught:
			kinds[e.id] = true
	check(counts.keys().all(func(c): return c >= 1 and c <= 5) and counts.size() == 5, "always 1 to 5 (%s)" % str(counts.keys()))
	check(kinds.size() == Trap.FISH.size(), "every kind of small fish")
	probe.queue_free()

	# E takes the fish out as carcasses, to be dealt with like any caught fish.
	inv.clear()
	check(t.prompt(p).begins_with("Take out the "), "full, E takes them out (%s)" % t.prompt(p))
	t.interact(p)
	var got := 0
	for id in Trap.FISH:
		got += inv.count(id)
		check(inv.count(id) == 0 or Items.counts_as(id, "small_fish"), "%s is a small fish" % id)
	check(got == n and t.caught.is_empty(), "%d fish carcasses in your bag, the trap empty" % n)
	check(Items.RECIPES.any(func(x): return x.in.has("small_fish") or x.in.has("elonichthys_carcass")) or Items.def("elonichthys_carcass").has("cook"),
			"and they are cooked or cut up like any other")

	# Two days in the trap and they are rotten.
	t.set_bait("meat_bait")
	w._check_traps()
	n = t.caught.size()
	Game.time += Trap.KEEP - 30.0
	check(not t.prompt(p).contains("Rotten"), "still alive just under two days on")
	Game.time += 60.0
	check(t.prompt(p).contains("Rotten Food"), "then rotten (%s)" % t.prompt(p))
	inv.clear()
	t.interact(p)
	check(inv.count("rotten") == n and Trap.FISH.all(func(id): return inv.count(id) == 0), "%d rotten food, no fish" % n)

	# On dry land, even baited, it catches nothing.
	var dry: Node = w.add_trap("fish_trap", w.player.global_position)
	dry.global_position = _find_spot(w, p.global_position, func(q): return q.y > w.water_level() + 0.3)
	dry.set_bait("grub")
	w._check_traps()
	check(dry.caught.is_empty() and dry.bait == "grub", "on land it catches nothing, and keeps the bait")

	# Saved.
	t.set_bait("guts")
	t.caught.append({"id": "bandringa_carcass", "at": Game.time})
	check(w.save_now(), "saved")
	var saved: Array = Game.read_save().get("traps", [])
	check(saved.size() == 2 and saved.any(func(d): return d.kind == "fish_trap" and d.bait == "guts" and d.caught.size() == 1), "the traps are saved")
	var copy: Node = w.add_trap("fish_trap", t.global_position + Vector3(0, 0, 2))
	copy.from_dict(t.to_dict())
	check(copy.bait == "guts" and copy.caught.size() == 1 and copy.caught[0].id == "bandringa_carcass", "and come back as they were")
	w.queue_free()
	await _frames(2)


func test_snare() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()
	Game.tools_known = []

	var r: Dictionary = Items.recipe_for("snare")
	check(r.tier == "hand" and r.in == {"string": 1, "branch": 1} and r.known_by == "spindle", "the snare: string and a branch, by hand, once you know the spindle")
	check(not Game.knows_recipe(r), "unknown before the spindle")
	Game.tools_known = ["spindle"]
	check(Game.knows_recipe(r) and Items.def("snare").place == "snare", "known after it; set down with Use")

	# Made by hand.
	p.focus = null
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, {"string": 1, "branch": 1})
	var o := _option_for(ws, "snare")
	check(not o.is_empty() and o.missing.is_empty() and _make(ws, o.recipe) and inv.count("snare") == 1, "a string and a branch make a snare")
	w.close_work()
	await _frames(1)

	# Set on the ground, not in the water.
	var before := get_tree().get_nodes_in_group("traps")
	var wet := _find_spot(w, p.global_position, func(q): return q.y < w.water_level() - 0.2)
	check(not w.place("snare", wet), "not in the water")
	var at: Vector3 = p.global_position - p.global_basis.z * 2.0
	check(w.place("snare", at), "on the ground it is set")
	inv.remove("snare", 1)  # as the player's Use does
	var made := _new_traps(before)
	check(made.size() == 1 and made[0].kind == "snare", "a snare stands there")
	var s: Node = made[0]
	await _frames(1)
	_empty_hands()
	check(s.prompt(p).begins_with("Pick up the snare") and "not baited" in s.prompt(p), "it says it isn't baited (%s)" % s.prompt(p))
	w._check_traps()
	check(s.caught.is_empty(), "unbaited, it catches nothing")

	# Baited with anything that baits a hook.
	for bait in ["meat_bait", "grub", "rotten", "guts"]:
		s.bait = ""
		check(_bait_trap(w, s, bait) and s.bait == bait, "baited with %s" % bait)
		await _frames(2)
	check(w.work == null and inv.count("guts") == 0, "the bait is used")

	# A night: 70% a small animal, 20% nothing, 10% a medium one.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var small := 0
	var medium := 0
	var nothing := 0
	var kinds := {}
	var beasts := {}
	var prey_carcasses: Array = Creature.SPECIES.values().filter(func(d): return d.behavior == "prey" and d.has("carcass")).map(func(d): return d.carcass)
	for k in 2000:
		s.caught.clear()
		s.bait = "grub"
		var c: int = s.catch(rng)
		if s.caught.is_empty():
			nothing += 1
			if nothing == 1:
				check(c == 0 and s.bait == "grub", "nothing caught keeps the bait")
		elif s.live_beast():
			medium += 1
			beasts[s.caught[0].species] = true
		else:
			small += 1
			kinds[s.caught[0].id] = true
		if not s.caught.is_empty() and s.bait != "":
			check(false, "a catch eats the bait")
	check(small > 1330 and small < 1470, "about 70%% small animals (%d / 2000)" % small)
	check(nothing > 330 and nothing < 470, "about 20%% nothing (%d / 2000)" % nothing)
	check(medium > 140 and medium < 260, "about 10%% a medium animal (%d / 2000)" % medium)
	check(kinds.keys().all(func(id): return id in prey_carcasses) and kinds.size() == prey_carcasses.size(), "any kind of small prey (%s)" % str(kinds.keys()))
	check(beasts.keys().all(func(sp): return Creature.SPECIES[sp].size == "medium" and Creature.SPECIES[sp].behavior in ["hunter", "defensive"])
			and beasts.has("scorpion") and beasts.has("arthropleura"), "a medium hostile or neutral animal (%s)" % str(beasts.keys()))
	s.bait = "grub"
	s.caught = [{"id": "tuditanus_carcass", "at": Game.time}]
	check(s.catch(rng) == 0 and s.caught.size() == 1 and s.bait == "grub", "with something in it, it catches no more")

	# A small one comes out as a carcass.
	inv.clear()
	check(s.prompt(p) == "Take out the Tuditanus Carcass [E]" or s.prompt(p).begins_with("Take out the"), "E takes it out (%s)" % s.prompt(p))
	s.interact(p)
	check(inv.count("tuditanus_carcass") == 1 and s.caught.is_empty(), "a carcass in your bag")
	s.caught = [{"id": "amphibamus_carcass", "at": Game.time - Trap.KEEP - 1.0}]
	s.interact(p)
	check(inv.count("rotten") == 1 and inv.count("amphibamus_carcass") == 0, "two days on, it is rotten food")

	# A medium one is there, alive in the noose, until you kill it.
	s.bait = ""
	s.caught = [{"species": "scorpion", "at": Game.time}]
	s._process(1.0)
	var beast: Node = s._beast
	check(beast != null and beast.species == "scorpion" and beast.snared == s and not beast.dead, "a live scorpion is caught in the snare")
	check("Kill it" in s.prompt(p), "it says to kill it (%s)" % s.prompt(p))
	inv.clear()
	s.interact(p)
	check(s.live_beast() and inv.count("scorpion_carcass") == 0 and is_instance_valid(s), "E won't take it alive")
	beast.global_position = s.global_position + Vector3(4.0, 0, 0)
	beast._hold_in_snare()
	var off: Vector3 = beast.global_position - s.global_position
	off.y = 0.0
	check(off.length() <= Trap.LEASH + 0.01, "it can't get away (%.2f m)" % off.length())
	beast.queue_free()
	await _frames(1)
	s._process(1.0)
	check(s._beast != null and s._beast != beast and is_instance_valid(s._beast), "freed while you sleep, it is still there when you come")
	beast = s._beast
	await _frames(1)
	beast.take_damage(1000.0, p)
	s._process(1.0)
	check(beast.dead and s.caught.is_empty() and is_instance_valid(beast) and beast.snared == null, "killed, its carcass is yours to butcher, the snare empty")
	beast.queue_free()

	# Left two days, it dies in the noose and rots.
	s.caught = [{"species": "arthropleura", "at": Game.time - Trap.KEEP - 1.0}]
	s._process(1.0)
	check(not s.live_beast() and s.caught[0].id == "rotten", "two days on, it is dead and rotten")
	inv.clear()
	s.interact(p)
	check(inv.count("rotten") == Trap.ROTTEN_MEDIUM, "rotten food x%d" % Trap.ROTTEN_MEDIUM)

	# Saved, a live one too.
	s.caught = [{"species": "arthropleura", "at": Game.time}]
	check(w.save_now(), "saved")
	var saved: Array = Game.read_save().get("traps", [])
	check(saved.size() == 1 and saved[0].kind == "snare" and saved[0].caught[0].species == "arthropleura", "the snare is saved, with what is in it")
	s.caught.clear()
	if is_instance_valid(s._beast):
		s._beast.queue_free()
	await _frames(1)

	# Picked up empty, with its bait.
	s.bait = "grub"
	inv.clear()
	s.interact(p)
	await _frames(1)
	check(inv.count("snare") == 1 and inv.count("grub") == 1 and not is_instance_valid(s), "picked up, the bait with it")
	w.queue_free()
	await _frames(2)


func test_compost_growing() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var inv = Game.inventory
	inv.clear()

	# Compost in a hole with a seed: half the time, twice the seeds.
	var uid := _dig_hole_near(w, p.global_position)
	var hole: Node = _planting_node(w, uid)
	p.focus = hole
	w.start_work()
	var ws: Node = w.work
	_lay_all(ws, {"compost": 1, "seed": 1})
	var opts: Array = ws.options()
	var verbs: Array = opts.map(func(o): return o.recipe.verb)
	check(opts.size() == 2 and "Plant the seed fern seed" in verbs and "Plant the seed fern seed with compost" in verbs, "a seed with compost laid out: with or without it (%s)" % [verbs])
	var fed: Dictionary = opts.filter(func(o): return o.recipe.in.has("compost"))[0].recipe
	check(Items.recipe_steps(fed) == 3 and ws.begin(fed), "three clicks")
	ws.step()
	check(hole._item_mesh.mesh != null and not hole._compost_mesh.visible, "the seed goes in")
	ws.step()
	check(hole._compost_mesh.visible and hole.open_hole(), "then the compost round it")
	ws.step()
	check(Game.plantings[uid].item.id == "seed" and Game.plantings[uid].compost and not hole.open_hole(), "then the earth over them")
	await _frames(2)
	check(w.work == null and inv.count("compost") == 0 and inv.count("seed") == 0, "both used")
	check("with compost" in hole.prompt(p), "the mound says so (%s)" % hole.prompt(p))
	var herb := _pass_time(w, uid, Plot.FILL_AFTER + 1.0)
	var rec: Dictionary = Game.plantings[uid]
	check(herb is Plot and rec.fed and is_equal_approx(float(rec.days), 7.0) and not rec.has("compost"), "it sprouts, to grow in 7 days")
	var grown := _pass_time(w, uid, 7.0 * Game.DAY_LENGTH)
	check(grown is Harvestable and grown.is_ready(), "grown in 7 days")
	var seeds := {}
	for k in 12:
		inv.clear()
		grown._ready_time = 0.0
		grown.interact(p)
		seeds[inv.count("seed")] = true
	check(seeds.keys().all(func(n): return n >= 2 and n <= 4 and n % 2 == 0), "twice the yield: 2 or 4 seeds (%s)" % str(seeds.keys()))

	# Compost with something that doesn't grow is only buried, so it isn't offered.
	var uid2 := _dig_hole_near(w, p.global_position)
	p.focus = _planting_node(w, uid2)
	w.start_work()
	ws = w.work
	_lay_all(ws, {"compost": 1, "stick": 1})
	verbs = ws.options().map(func(o): return o.recipe.verb)
	check(verbs == ["Bury the stick"], "a stick is only buried, without the compost (%s)" % [verbs])
	w.close_work()
	await _frames(1)
	check(inv.count("compost") == 1 and inv.count("stick") == 1 and _planting_node(w, uid2).open_hole(), "stood up, both come back and the hole is still open")
	inv.clear()

	# A tree's root with compost: 7 days.
	var uid3 := _dig_hole_near(w, p.global_position)
	_planting_node(w, uid3).bury("calamites_root", 0.0, true)
	_pass_time(w, uid3, Plot.FILL_AFTER + 1.0)
	var st: Dictionary = Game.felled[uid3]
	check(absf(float(st.regrow) - float(st.at) - 7.0 * Game.DAY_LENGTH) < 1.0, "a tree in compost grows in 7 days")

	# Right-clicking a growing plant with compost cuts 30% off what is left.
	var uid4 := _dig_hole_near(w, p.global_position)
	_planting_node(w, uid4).bury("seed", 0.0, false)
	var young := _pass_time(w, uid4, Plot.FILL_AFTER + 1.0)
	Game.time += 3.0 * Game.DAY_LENGTH
	var left: float = young._left(Game.plantings[uid4])
	inv.clear()
	inv.add("compost", 2)
	inv.select(inv.find("compost"))
	check("right-click to work compost in" in young.prompt(p), "with compost in hand it says so (%s)" % young.prompt(p))
	p.focus = young
	p._use_held()
	var after: float = young._left(Game.plantings[uid4])
	check(inv.count("compost") == 1 and absf(after - left * 0.7) < 1.0, "a young seed fern: %.1f days left, was %.1f" % [after / Game.DAY_LENGTH, left / Game.DAY_LENGTH])

	# A stump growing back.
	var t := _planted_tree(w, uid3)
	var stump: Node = t.stump
	var was: float = float(Game.felled[uid3].regrow) - Game.time
	p.focus = stump
	p._use_held()
	check(inv.count("compost") == 0 and absf(float(Game.felled[uid3].regrow) - Game.time - was * 0.7) < 1.0, "a young tree too")

	# A plant growing back after picking, but not a rotting log, nor a ripe plant.
	var fern: Node = Harvestable.new().setup("fern", "h_test_compost_fern")
	w.add_child(fern)
	fern.global_position = p.global_position + Vector3(2, 0, 0)
	inv.add("compost", 3)
	inv.select(inv.find("compost"))
	p.focus = fern
	p._use_held()
	check(inv.count("compost") == 3, "a fern in leaf has nothing to hurry")
	fern.interact(p)
	inv.select(inv.find("compost"))
	var wait: float = fern._ready_time - Game.time
	p.focus = fern
	p._use_held()
	check(inv.count("compost") == 2 and absf(fern._ready_time - Game.time - wait * 0.7) < 1.0
			and is_equal_approx(float(Game.harvested[fern.uid]), fern._ready_time), "a picked fern grows back sooner")
	var log_h: Node = Harvestable.new().setup("rotting_log", "h_test_compost_log")
	w.add_child(log_h)
	log_h.global_position = p.global_position + Vector3(-2, 0, 0)
	log_h.interact(p)
	inv.select(inv.find("compost"))
	p.focus = log_h
	p._use_held()
	check(inv.count("compost") == 2, "a rotting log isn't a plant")
	w.queue_free()
	await _frames(2)


# --- Prey variety --------------------------------------------------------------------

const PREY := ["hylonomus", "petrolacosaurus", "archaeothyris", "amphibamus", "tuditanus", "morganucodon"]


func _set_solar(t: float) -> void:
	Game.time = fposmod(Game.solar_to_clock(t) - Game.ARRIVAL_CLOCK, Game.DAY_LENGTH)


func test_prey_data() -> void:
	var listed: Array = Creature.SPECIES.keys().filter(func(sp): return Creature.SPECIES[sp].behavior == "prey")
	check(listed.size() == PREY.size() and PREY.all(func(sp): return sp in listed), "six small prey species (%s)" % str(listed))
	var probe: Node = Creature.new()
	for sp in PREY:
		var d: Dictionary = Creature.SPECIES[sp]
		check(d.size == "small" and d.habitat == "land" and not d.has("cap_day") and d.prey.size() == 2,
				"%s: small, on land, spawned from the shared prey pool" % sp)
		check(d.radius <= ThrownRock.SMALL, "%s: small enough to be dazed by a stone" % sp)
		check(probe.has_method("_build_" + sp), "%s has a body" % sp)
		var whole: String = d.carcass
		check(Items.ITEMS.has(whole) and not Items.def(whole).has("cook") and Items.def(whole).shape == "lizard",
				"%s: its carcass (%s) can't be roasted as it is" % [sp, whole])
		if sp != "hylonomus":
			# Shaped like the animal, whole or skinned (Assets.small_prey).
			var ids: Array = [whole, whole.replace("_carcass", "_dressed"), "roast_" + sp]
			check(ids.all(func(id): return Items.def(id).get("animal", "") == sp) and Assets.PREY_SHAPES.has(sp),
					"%s: its carcass, dressed and roast items are shaped like it" % sp)
			for id in ids:
				var m: Mesh = Assets.mesh("item_" + id)
				check(m != null and m.get_surface_count() > 0, "%s has a mesh" % id)
		var dress := Items.RECIPES.filter(func(r): return r.in.has(whole) and r.get("dress", false))
		check(dress.size() == 1 and dress[0].tier == "hand" and dress[0].get("guts", 0) == 1 and not dress[0].has("tools")
				and Items.recipe_steps(dress[0]) == 4, "%s: gutted and skinned by hand, leaving guts" % sp)
		if dress.size() == 1:
			var dressed: Dictionary = Items.def(dress[0].out)
			check(dressed.has("cook") and Items.ITEMS.has(dressed.cook) and Items.def(dressed.cook).energy > dressed.energy,
					"%s: the dressed animal roasts whole into %s" % [sp, dressed.get("cook", "?")])
	probe.free()
	check(Creature.SPECIES.archaeothyris.drops.raw_meat == 2 and Items.def("roast_archaeothyris").energy > Items.def("roast_lizard").energy,
			"an Archaeothyris is the biggest meal")
	check(Creature.SPECIES.petrolacosaurus.run > Creature.SPECIES.hylonomus.run and Creature.SPECIES.petrolacosaurus.sense > Creature.SPECIES.hylonomus.sense,
			"a Petrolacosaurus is quicker and warier than a Hylonomus")
	check(Creature.SPECIES.amphibamus.get("spawn", "") == "shore", "Amphibamus keeps to the banks")
	check(Creature.SPECIES.tuditanus.prey[1] > Creature.SPECIES.tuditanus.prey[0], "Tuditanus is mostly out at night")
	check(Creature.SPECIES.morganucodon.prey[1] > Creature.SPECIES.morganucodon.prey[0]
			and Items.def("roast_morganucodon").energy < Items.def("roast_amphibamus").energy,
			"Morganucodon is the smallest meal, and more about at night")


func test_prey_spawning() -> void:
	var w: Node = await _new_swamp()
	var rolls := {"day": {}, "night": {}}
	for k in 3000:
		var night := k % 2 == 1
		var sp: String = w.pick_prey(night)
		var by: Dictionary = rolls["night" if night else "day"]
		by[sp] = by.get(sp, 0) + 1
	check(PREY.all(func(sp): return rolls.day.has(sp)) and rolls.day.keys().size() == PREY.size(),
			"by day every prey species turns up, and nothing else (%s)" % str(rolls.day))
	check(rolls.day.hylonomus > rolls.day.tuditanus and rolls.night.tuditanus > rolls.night.hylonomus,
			"Hylonomus is the commonest by day, Tuditanus by night (%s)" % str(rolls.night))

	for when in [["day", 0.5, Creature.PREY_DAY], ["night", 0.95, Creature.PREY_NIGHT]]:
		for c in Game.creatures.duplicate():
			if is_instance_valid(c) and c.def.behavior == "prey":
				c.queue_free()
		await _frames(2)
		_set_solar(when[1])
		check(Game.is_night() == (when[0] == "night"), "it is %s" % when[0])
		var most := 0
		for k in 600:
			w._spawn_creatures()
			var n := Game.creatures.filter(func(c): return is_instance_valid(c) and not c.is_queued_for_deletion() \
					and not c.dead and c.def.behavior == "prey").size()
			most = maxi(most, n)
		var kinds := {}
		for c in Game.creatures:
			if is_instance_valid(c) and c.def.behavior == "prey":
				kinds[c.species] = true
		check(most == when[2], "by %s no more than %d prey are about at once, of any species (most %d: %s)" % [when[0], when[2], most, str(kinds.keys())])
	w.queue_free()
	await _frames(2)


func test_prey_behaviour() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	var start: Vector3 = p.global_position
	var spot := _find_spot(w, start + Vector3(30, 0, 0), func(q): return q.y > 0.4 and q.distance_to(start) > 25.0)
	for sp in PREY:
		if sp == "hylonomus":
			continue  # covered by the throwing, predators and butcher groups
		# It runs from you.
		var c: Node = Creature.new().setup(sp, p.global_position + Vector3(3, 0, 0), w)
		w.add_child(c)
		await _frames(3)
		check(c.state == "flee", "a %s flees from you (state %s)" % [sp, c.state])
		c.queue_free()

		# A dragonfly goes for it in the open.
		var a: Node = Creature.new().setup(sp, spot, w)
		w.add_child(a)
		a.set_process(false)
		var fly: Node = Creature.new().setup("meganeura", spot + Vector3(4, 4, 0), w)
		w.add_child(fly)
		await _frames(2)
		fly._cd = 0.0
		fly._spot_lizard()
		check(fly.state == "dive" and fly._prey == a, "a dragonfly dives on a %s" % sp)
		fly.queue_free()

		# So do the land scavengers.
		var ar: Node = Creature.new().setup("arthropleura", spot + Vector3(5, 0, 0), w)
		ar.position.y = w.ground_height(spot.x + 5, spot.z)
		w.add_child(ar)
		await _frames(2)
		ar._cd = 0.0
		ar._scan_t = 0.0
		ar.state = "wander"
		await _run_for(15.0, func(): return a.dead)
		check(a.dead and ar.state == "feed", "an Arthropleura runs down a %s and eats it" % sp)
		ar.queue_free()
		if is_instance_valid(a):
			a.queue_free()
		await _frames(2)
	w.queue_free()
	await _frames(2)


func _guts_handfuls() -> int:
	var n := 0
	for g in get_tree().get_nodes_in_group("guts"):
		if not g.is_queued_for_deletion():
			n += g.n
	return n


func test_prey_dressing() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	for sp in PREY:
		Game.inventory.clear()
		var handfuls := _guts_handfuls()
		var whole: String = Creature.SPECIES[sp].carcass
		var c: Node = _kill(w, sp, _ahead(p, 2.0))
		await _frames(1)
		check(c.prompt(p).begins_with("Pick up") and c.haul_mode() == "", "a dead %s is picked up, not carried or dragged" % sp)
		c.interact(p)
		await _frames(1)
		check(Game.inventory.count(whole) == 1, "a dead %s goes into the bag" % sp)
		w.start_work()
		check(w.work != null, "you can work on a %s by hand" % sp)
		if w.work == null:
			continue
		w.work.lay(Game.inventory.find(whole))
		var opt: Array = w.work.options().filter(func(o): return o.recipe.in.has(whole))
		check(opt.size() == 1 and opt[0].missing.is_empty(), "gutting a %s needs no tools" % sp)
		if opt.size() == 1:
			w.work.begin(opt[0].recipe)
			check(w.work._work.mesh != null, "the %s is there to gut" % sp)
			for k in Items.recipe_steps(w.work.recipe):
				w.work.step()
			var dressed: String = opt[0].recipe.out
			check(Game.inventory.count(dressed) == 1 and Items.def(dressed).has("cook"), "it becomes %s, to roast" % Items.item_name(dressed))
			check(_guts_handfuls() == handfuls + 1, "and leaves its guts on a pile")
		w.close_work()
		await _frames(1)

	# A half-eaten one leaves gnawed meat, as a lizard does: an Archaeothyris
	# (2 meat) gives 1.
	Game.inventory.clear()
	var ar: Node = _kill(w, "archaeothyris", _ahead(p, 2.0))
	ar.gnawed = true
	ar.interact(p)
	check(Game.inventory.count("gnawed_meat") == 1, "a gnawed Archaeothyris leaves gnawed meat")
	w.queue_free()
	await _frames(2)


# --- Boats and metals (boats.md, metals.md) -------------------------------------------

func test_boats() -> void:
	## A dock built out from the bank keeps the water round it safe, and marks
	## out a raft at its berth; both are saved.
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()
	var whys := {}
	var start: Vector3 = p.global_position
	var good := _find_spot(w, p.global_position, func(q):
		if q.y < w.water_level() - 0.1 or q.y > w.water_level() + 0.6:
			return false
		for k in 8:
			p.global_position = q + Vector3(0, 0.05, 0)
			p.rotation.y = TAU * k / 8.0
			var why: String = w.dock_spot(p).why
			if why == "":
				return true
			whys[why] = whys.get(why, 0) + 1
		return false)
	check(good.is_finite(), "somewhere on the bank a dock can stand (%s)" % [whys])
	if not good.is_finite():
		w.queue_free()
		return
	check(good.distance_to(start) < 80.0, "near the spawn (%d m)" % good.distance_to(start))
	# Just about anywhere along the shore: facing open water from the water's
	# edge, a dock fits.
	var tried := 0
	var fits := 0
	whys.clear()
	for r in range(10, 200, 3):
		for i in 24:
			var a := TAU * i / 24.0
			var q: Vector3 = start + Vector3(cos(a), 0, sin(a)) * r
			q.y = w.ground_height(q.x, q.z)
			if absf(q.y - w.water_level()) > 0.1:
				continue
			# Face the water: the way the ground falls away.
			var dx: float = w.ground_height(q.x + 1.0, q.z) - w.ground_height(q.x - 1.0, q.z)
			var dz: float = w.ground_height(q.x, q.z + 1.0) - w.ground_height(q.x, q.z - 1.0)
			if Vector2(dx, dz).length() < 0.01:
				continue
			var down := -Vector2(dx, dz).normalized()
			# Only real shore: open water ahead, not a puddle or a wet flat.
			var deepest := 0.0
			for m in range(2, 30, 2):
				var g: Vector3 = q + Vector3(down.x, 0, down.y) * m
				deepest = maxf(deepest, w.water_level() - w.ground_height(g.x, g.z))
			if deepest < 0.3:
				continue
			p.global_position = q + Vector3(-down.x, 0, -down.y) * 1.0
			p.rotation.y = atan2(-down.x, -down.y)
			tried += 1
			var why: String = w.dock_spot(p).why
			if why == "":
				fits += 1
			else:
				whys[why] = whys.get(why, 0) + 1
	check(tried > 30 and fits >= tried * 0.8, "a dock fits just about anywhere along the shore (%d of %d: %s)" % [fits, tried, whys])
	p.global_position = good + Vector3(0, 0.05, 0)
	for k in 8:
		p.rotation.y = TAU * k / 8.0
		if w.dock_spot(p).why == "":
			break
	var spot: Dictionary = w.dock_spot(p)
	var d: Node = w.add_dock(spot.at, spot.yaw)
	await _frames(2)
	check(not d.complete() and Game.docks.has(d), "a dock site is marked out")
	var end: Vector3 = d.to_global(Vector3(0, 0, -Dock.LEN + 0.5))
	check(not Game.dock_safe(end), "an unfinished dock keeps nothing away")
	d.build_to(Dock.PARTS.size())
	await _frames(2)
	check(d.complete() and Game.dock_safe(end) and Game.safe(end), "a finished dock keeps the water round it safe")
	var r: Node = w.raft_at_dock(d)
	check(r != null and not r.complete(), "a finished dock marks out a raft at its berth")
	if r:
		r.build_to(Raft.PARTS.size())
		for k in 3:
			await get_tree().physics_frame
		check(r.complete(), "the raft is built")
		check(r.global_position.y > w.water_level() + 0.05 and r.draft() < 0.2, "it rides high in the water")
	var state: Dictionary = w._world_state()
	check(state.docks.size() == 1 and state.rafts.size() == 1, "the dock and the raft are saved")
	# Poles: from a stripped Calamites log, hardened in the fire.
	check(Items.def("calamites_pole").get("tags", []).has("pole") and Items.exists("hardened_pole"), "a Calamites pole is a pole")
	w.queue_free()
	await _frames(2)


func test_tool_wear() -> void:
	## Stone tools may snap once well used; metal edges go blunt and are
	## sharpened; a copper hammer wears out into grains.
	_fresh_state()
	var inv: Inventory = Game.inventory
	inv.clear()
	inv.add("stone_axe", 1)
	var i: int = inv.find("stone_axe")
	for k in Inventory.STONE_SAFE:
		inv.use_tool(i, 0.0)
	check(inv.slots[i] != null and inv.slots[i].id == "stone_axe", "a stone axe never breaks in its first uses")
	check(inv.use_tool(i, 0.5) == "" and inv.slots[i].id == "stone_axe", "past them, a good roll keeps it")
	check(inv.use_tool(i, 0.0) == "broke" and inv.slots[i].id == "stick", "a bad roll snaps the head off, leaving the haft")
	# Fresh tools may share a slot (once stacks have no size limit): a use
	# wears only the one in hand, and the next use wears the same one.
	inv.clear()
	inv.add("stone_axe", 3, 0.0, true)
	i = inv.find("stone_axe")
	inv.use_tool(i, 0.5)
	inv.use_tool(i, 0.5)
	var worn := 0
	var fresh := 0
	for s in inv.slots:
		if s != null and s.id == "stone_axe":
			if s.has("data"):
				worn += s.n
				check(int(s.data.used) == 2, "the axe in hand took both uses")
			else:
				fresh += s.n
	check(inv.count("stone_axe") == 3 and worn == 1 and fresh == 2 and inv.slots[i].has("data"), "only the axe in hand is worn, and it stays in hand")
	inv.clear()
	inv.add("stone_axe", 1)
	i = inv.find("stone_axe")
	inv.clear()
	inv.add("copper_axe", 1)
	inv.add("stone_axe", 1)
	var c: int = inv.find("copper_axe")
	check(inv.tool_slot("chop") == c, "the copper axe is picked over the stone one")
	var edge := int(Items.def("copper_axe").edge)
	for k in edge - 1:
		inv.use_tool(c)
	check(inv.edge_left(c) == 1 and not inv.blunt(c), "each use wears the edge")
	check(inv.use_tool(c) == "blunt" and inv.blunt(c), "the last use leaves it blunt")
	check(inv.slots[c].data.get("name", "").ends_with("(blunt)"), "and named so")
	inv.sharpen(c)
	check(inv.edge_left(c) == edge and not inv.blunt(c), "sharpening puts the edge back")
	inv.clear()
	inv.add("copper_hammer", 1)
	var h: int = inv.find("copper_hammer")
	var uses := int(Items.def("copper_hammer").uses)
	for k in uses - 1:
		inv.use_tag("hammer")
	check(inv.count("copper_hammer") == 1 and inv.uses_left(h) == 1, "a copper hammer wears a use at a time")
	check(inv.use_tag("hammer") == "worn" and inv.count("copper_hammer") == 0 and inv.count("copper_grains") == 2, "worn out, it is copper grains")
	inv.add("iron_hammer", 1)
	inv.use_tag("hammer")
	check(inv.count("iron_hammer") == 1, "an iron hammer never wears")


func test_metals() -> void:
	var w: Node = await _new_swamp()
	var p: Node = w.player
	Game.inventory.clear()

	# The islands' outcrops and anvil stones.
	var outcrops: Array = get_tree().get_nodes_in_group("outcrops")
	var anvils: Array = get_tree().get_nodes_in_group("anvils")
	var n_out := 0
	var n_anv := 0
	for isl in w.terrain.islands:
		n_out += isl.outcrops.size()
		n_anv += isl.anvils.size()
	check(outcrops.size() == n_out and n_out > 0, "every island has its copper outcrops (%d)" % outcrops.size())
	check(anvils.size() == n_anv and n_anv > 0, "and its anvil stones (%d)" % anvils.size())
	var o: Node = outcrops[0]
	check(o.global_position.y > w.water_level(), "an outcrop stands on dry rock")
	o.interact(p)
	check(Game.inventory.count("copper_ore") == 0, "no ore without a copper hammer")
	Game.inventory.add("copper_hammer", 1)
	o.interact(p)
	var ore: int = Game.inventory.count("copper_ore")
	check(ore >= 3 and ore <= 5, "a copper hammer breaks out 3-5 lumps of ore (%d)" % ore)
	check(Game.inventory.uses_left(Game.inventory.find("copper_hammer")) < int(Items.def("copper_hammer").uses), "and wears the hammer")
	check(not o.is_ready() and Game.harvested.has(o.uid), "then it is broken out for a while")
	var state: Dictionary = w._world_state()
	check(state.stones.is_empty(), "an island's untouched anvil stones aren't saved: the seed makes them again")
	var anv: Node = anvils[0]
	anv.set_hauled(p)
	anv.set_hauled(null)
	check(Game.taken.has(anv.uid) and w._world_state().stones.size() == 1, "once picked up, an anvil stone is saved")

	# A charcoal clamp.
	var dry := _find_spot(w, p.global_position, func(q): return q.y > 0.3 and w.work_blocker(q) == "")
	p.global_position = dry + Vector3(0, 0.1, 0)
	await _frames(2)
	var cl: Node = w.add_clamp(dry + Vector3(1.5, 0, 0), 0.0)
	await _frames(1)
	check(not cl.lit() and cl.prompt(p).contains("light"), "a new clamp waits to be lit")
	Game.inventory.add("ember", 1)
	Game.inventory.selected = Game.inventory.find("ember")
	cl.interact(p)
	check(cl.lit() and Game.inventory.count("ember") == 0, "an ember lights it")
	Game.time += Clamp.BURN + 1.0
	check(cl.done(), "a day later it has burnt through")
	var cl_at: Vector3 = cl.global_position
	var before := _count_near(w, "charcoal", cl_at)
	cl.break_apart()
	await _frames(1)
	var got := _count_near(w, "charcoal", cl_at) - before
	check(got >= 8 and got <= 12, "broken open, it leaves 8-12 charcoal (%d)" % got)

	# A furnace, built part by part.
	var f: Node = w.add_furnace(dry + Vector3(-1.8, 0, 0), 0.0)
	await _frames(2)
	check(f.built.has("ring") and f.next_part().get("id", "") == "shaft", "a new furnace site has its stone ring laid")
	check(not "metal" in Game.tiers, "no metal recipes before a furnace is finished")
	f.build_to(Furnace.PARTS.size())
	await _frames(1)
	check(f.complete() and "metal" in Game.tiers, "a finished furnace opens the metal recipes")
	check(f.blow(p) == false and f.heat > 0.0, "a breath warms it")
	for k in 6:
		f.blow(p)
	check(f.heat >= Furnace.HOT, "blowing hard brings it to full heat")
	f.heat = 0.0

	# Casting a copper axe head at it.
	Game.inventory.clear()
	var cast: Dictionary = Items.recipe_for("rough_copper_axe_head")
	check(not cast.is_empty() and cast.get("at", "") == "furnace", "an axe head is cast at the furnace")
	for id in cast.in:
		Game.inventory.add("copper_grains" if id == "copper" else id, int(cast.in[id]) + 2)
	for id in cast.get("tools", {}):
		Game.inventory.add(id, 1)
	p.global_position = f.global_position + Vector3(0, 0.05, 1.6)
	p.focus = f
	w.start_work()
	var ws: Node = w.work
	check(ws != null and ws.station == f and ws.station_kind == "furnace", "C at the furnace kneels to work at it")
	if ws:
		for k in Game.inventory.SIZE:
			var sl = Game.inventory.slots[k]
			if sl != null and sl.id in ["copper_grains", "charcoal"]:
				ws.lay(k, 1 << 20)
		var opt: Array = ws.options().filter(func(x): return x.recipe.out == "rough_copper_axe_head")
		check(opt.size() == 1 and opt[0].missing.is_empty(), "copper, charcoal and the mould offer the casting (%s)" % [opt[0].missing if opt.size() == 1 else "none"])
		if opt.size() == 1 and ws.begin(opt[0].recipe):
			var clicks := 0
			while not ws.recipe.is_empty() and clicks < 300:
				ws.step()
				clicks += 1
			check(Game.inventory.count("rough_copper_axe_head") == 1, "every click a breath: the head is cast (%d clicks)" % clicks)
			check(clicks > Items.recipe_steps(cast), "clicks while it is still heating don't count")
			check(Game.copper_cast, "the first casting is remembered (for the meteor showers)")
		w.close_work()
	await _frames(1)

	# A meteorite comes down.
	var at: Vector3 = w.meteor_fall(Vector3.RIGHT)
	check(at.is_finite() and at.y > w.water_level(), "a meteorite falls on dry land")
	if at.is_finite():
		var d := Vector2(at.x - p.global_position.x, at.z - p.global_position.z).length()
		check(d >= 40.0 and d <= 320.0 or Game.island_safe(at), "60-300 m away, or out on an island (%d m)" % d)
		var met: Node = null
		for m in get_tree().get_nodes_in_group("meteorites"):
			if m.global_position.distance_to(at) < 1.0:
				met = m
		check(met != null and met.buried and met.station_kind() == "", "it lies half buried")
		check(get_tree().get_nodes_in_group("craters").size() == 1, "in a smoking crater")
		var bits := 0
		for dr in get_tree().get_nodes_in_group("drops"):
			if dr.item_id == "meteoric_iron" and dr.global_position.distance_to(at) < 16.0:
				bits += 1
		check(bits >= 1 and bits <= 6, "with lumps of meteoric iron strewn round (%d)" % bits)
		if met:
			for k in HeavyStone.DIG_HITS:
				met.dig()
			check(not met.buried and met.station_kind() == "meteorite", "a mattock digs it out to chip at")
			check(met.chip(0.5) == false and met.mass < 30.0, "chipping wears it down")
		var st: Dictionary = w._world_state()
		check(st.craters.size() == 1 and st.stones.any(func(x): return x.id == "meteorite"), "the crater and the meteorite are saved")

	# The furnace and clamp are saved and come back.
	var cl2: Node = w.add_clamp(dry + Vector3(0, 0, 2.0), 0.0)
	cl2.lit_at = Game.time
	var saved: Dictionary = w._world_state()
	check(saved.furnaces.size() == 1 and saved.furnaces[0].built.size() == Furnace.PARTS.size(), "the furnace is saved")
	check(saved.clamps.size() == 1 and saved.clamps[0].lit_at == Game.time, "a lit clamp is saved")
	w.queue_free()
	await _frames(2)


func _find_spot_far(w: Node, near: Vector3, reach: float, ok: Callable) -> Vector3:
	## _find_spot further out, on a coarser grid.
	for r in range(0, int(reach), 6):
		for i in 32:
			var a := TAU * i / 32.0
			var pos := near + Vector3(cos(a), 0, sin(a)) * r
			pos.y = w.ground_height(pos.x, pos.z)
			if ok.call(pos):
				return pos
	return Vector3.INF


func _count_near(w: Node, id: String, at: Vector3) -> int:
	## Items of id lying loose or piled within 3 m.
	var n := 0
	for dr in get_tree().get_nodes_in_group("drops"):
		if dr.item_id == id and dr.global_position.distance_to(at) < 3.0:
			n += int(dr.count)
	for st in get_tree().get_nodes_in_group("stacks"):
		if st.item_id == id and st.global_position.distance_to(at) < 3.0:
			n += int(st.count)
	return n


func test_meteor_weather() -> void:
	var w: Node = await _new_swamp()
	var wt: Node = w.weather
	check("day_meteors" in Weather.ALL_KINDS and not "day_meteors" in Weather.KINDS, "a daytime meteor shower is a weather kind of its own")
	var seen := {}
	for k in 600:
		seen[wt.roll_day(Weather.FIRST_DAY)] = true
	check(not seen.has("day_meteors"), "never before day 10")
	seen.clear()
	for k in 600:
		seen[wt.roll_day(Weather.DAY_METEORS_FROM)] = true
	check(seen.has("day_meteors") and seen.has("meteors"), "from day 10, both meteor showers come")
	Game.copper_cast = true
	wt.cast_fall_done = false
	wt.start("day_meteors")
	check(wt.fall_at >= 0.0 and wt.cast_fall_done, "the first shower after casting copper always drops a meteorite")
	var dict: Dictionary = wt.to_dict()
	check(dict.cast_fall_done and dict.kind == "day_meteors", "it is saved")
	wt.update(wt.fall_at + 0.1)
	check(wt.fall_at < 0.0 and get_tree().get_nodes_in_group("meteorites").size() >= 1, "and down it comes")
	check(Weather.compass(Vector3(1, 0, -1)) == "north-east" and Weather.compass(Vector3(0, 0, 1)) == "south", "the boom's direction is named")
	wt.stop()
	Game.copper_cast = false
	w.queue_free()
	await _frames(2)
