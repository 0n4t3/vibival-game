extends Node3D
## Crafting by hand on the ground (the "hand" tier). The player kneels and
## lays items from the inventory onto the ground in front of them; what is
## laid out decides what can be made. Making it is a short hands-on step done
## with the mouse on the 3D workpiece:
##   twist  hold the left button and roll the work back and forth (cordage, torches)
##   steps  click the glowing marker once per step (lashing, coiling, weaving)
##   knap   strike cells off a 5x5 chert slab resting on a flat stone anvil
##   peck   knock the high spots off a rough anvil boulder's face (heavy_stone.gd)
##
## At a workbench (`bench`, see workbench.gd) the spot lies on its top instead
## of the ground, and "bench" tier recipes can be made there as well as
## everything made by hand; a recipe with `rack` needs that tool hanging on the
## bench's rack (or, with `rack_or_bag`, laid out or in your bag: the spindle
## for string). A recipe with `build` (the workbench itself) puts up what it
## makes in front of you rather than giving you an item.
##
## Kneeling at a medium or large carcass (`carcass`) also offers the next
## butchering stage for it (Items.BUTCHERING), done with steps on the body.
## Kneeling at a standing tree (`tree`), a felled trunk or a loose log (`wood`)
## offers what an axe can do to it (Items.WOODWORK), done with steps on the wood.
##
## At a house site (`house`, see house.gd) it offers the house's next part
## instead, built from materials in your bag with steps clicked on the house
## itself (a stilt from the Calamites log you carried there, `house_log`).
##
## Kneeling at a fish trap or a snare (`trap`, see trap.gd) offers to bait it
## with any bait laid out, one click on the trap itself.
##
## Kneeling at a dug hole (`plot`, see plot.gd) offers to bury whatever is laid
## out in it (with compost too, if that is laid out), clicked into the hole a
## step at a time: set it in, add the compost, fill the hole in over it.
##
## Local space: +Z points back toward the kneeling player, Y is up from the
## ground under the spot.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")
const Chunk := preload("res://src/world/chunk.gd")
const Preserves := preload("res://src/core/preserves.gd")

const PICK_PX := 44.0
const KNAP_CELL := 0.06
const TWIST_PER_PX := 0.0011
const WORK := Vector3(0, 0, 0.08)  # where the workpiece lies
const STEEL := Color(0.75, 0.77, 0.80)
const COPPER := Color(0.80, 0.45, 0.20)
const FIBER := Color(0.55, 0.65, 0.30)
const BUILD_AT := Vector3(0, 0, -0.9)  # where a workbench goes up, from the spot
const ZOOM := {"ash_pencil": 2.5, "pencil_core_unfired": 2.0, "blueprint_softwood_house": 1.3, "chart_map": 1.3, "spindle_whorl_unfired": 2.5, "spindle": 1.5}  # small work shown bigger, to see what you do
const FISH_TRAP_SIZE := 0.55  # a fish trap being made at a bench, shown smaller
const BLUEPRINT_AT := Vector3(0, 0, -0.19)  # where the sheet lies, the pencil in front of it

signal changed
signal finished(id: String)

var where := "swamp"
var tier := "hand"
var player: Node3D
var piles: Array = []          # [{id, n, age}], laid out in PILES order
var recipe: Dictionary = {}    # what is being made, {} while laying out
var progress := 0.0            # twist: 0..1
var steps := 0                 # steps: steps done
var used: Array = []           # [{id, n, age}] taken off the piles for the recipe
var knap_grid: Array = []      # 25 bools: stone still there
var knap_cortex: Array = []    # 25 bools: rind not yet flaked off
var knap_struck := false
var carcass: Node3D = null     # a dead animal being butchered where it lies
var wood: Node3D = null        # a felled trunk or loose log being worked
var tree: Dictionary = {}      # a standing tree being felled (see chunk.gd)
var bench: Node3D = null       # the workbench whose top this is, or null on the ground
var house: Node3D = null       # a house site being built
var house_log: Node3D = null   # the log carried there for its next stilt (hidden meanwhile)
var trap: Node3D = null        # a fish trap or snare being baited
var plot: Node3D = null        # a dug hole something is being planted in
var station: Node3D = null     # a furnace, anvil or meteorite knelt at (metals.md)
var station_kind := ""         # "furnace", "anvil", "boulder" (an anvil stone still rough), "meteorite", or "water" (looking at the water)

var _piles: Array = []         # pile nodes
var _work: MeshInstance3D
var _marker: MeshInstance3D
var _hammer: MeshInstance3D
var _hammer_at := Vector3.ZERO  # where the striker comes down, from WORK (its face on the work)
var _rng := RandomNumberGenerator.new()
var _shown := -1.0             # twist progress the workpiece was built for
var _roll := 0.0               # twist: how far the work has been rolled (radians)
var _roll_shown := 0.0
var _thump := 0.0              # animation after each step
var _t := 0.0
var _marker_size := 1.0
var _cold_step := false        # the last blow left the furnace short of melting heat
var _wasted := false           # the last peck fell on flat stone


static func piles_layout() -> Array:
	## Pile spots in an arc behind the workpiece.
	var out := []
	for i in 8:
		var a := deg_to_rad(lerpf(-168.0, -12.0, i / 7.0))
		out.append(Vector3(cos(a) * 0.5, 0, sin(a) * 0.36 - 0.06))
	return out


func _ready() -> void:
	_work = MeshInstance3D.new()
	_work.position = WORK
	add_child(_work)
	_marker = MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.cylinder(Vector3(0, -0.004, 0), Vector3(0, 0.004, 0), 0.03, 0.03, 10, Color(1.0, 0.78, 0.3), Color(-1, 0, 0), "glow")
	mb.cylinder(Vector3(0, -0.005, 0), Vector3(0, 0.005, 0), 0.018, 0.018, 10, Color(0.15, 0.1, 0.0), Color(-1, 0, 0), "glow")
	_marker.mesh = mb.commit(Assets.materials)
	_marker.visible = false
	add_child(_marker)
	_hammer = MeshInstance3D.new()
	_hammer.mesh = Assets.mesh("item_stone")
	_hammer.scale = Vector3.ONE * 0.6
	_hammer.visible = false
	add_child(_hammer)


func _exit_tree() -> void:
	if _plot_ok():
		plot.show_planting("", false)  # stood up half way: it comes back out


func _process(delta: float) -> void:
	_t += delta
	if carcass and not _carcass_ok():
		# Eaten, rotted away or taken while you knelt there.
		carcass = null
		if recipe.has("butcher"):
			recipe = {}
			_rebuild_work()
		changed.emit()
	if wood and not _wood_ok():
		wood = null
		if recipe.has("wood"):
			recipe = {}
			_rebuild_work()
		changed.emit()
	if house and not _house_ok():
		# Torn down while you worked at it.
		house = null
		recipe = {}
		used.clear()
		if player and player.world and player.world.has_method("close_work"):
			player.world.close_work.call_deferred()
	if trap and not _trap_ok():
		# Taken away while you knelt there (the bait goes back in your bag).
		trap = null
		if player and player.world and player.world.has_method("close_work"):
			player.world.close_work.call_deferred()
	if plot and not _plot_ok():
		# Filled itself in while you knelt there (what you laid out comes back).
		plot = null
		if player and player.world and player.world.has_method("close_work"):
			player.world.close_work.call_deferred()
	_thump = maxf(_thump - delta * 4.0, 0.0)
	if _marker.visible:
		_marker.scale = Vector3.ONE * _marker_size * (1.0 + 0.2 * sin(_t * 6.0))
	if house and _marker.visible and player and player.camera:
		# Big enough to see across the site, and turned to face you.
		var to: Vector3 = player.camera.global_position - _marker.global_position
		var y := to.normalized()
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		var size := clampf(to.length() * 1.1, 2.5, 6.0) * (1.0 + 0.2 * sin(_t * 6.0))
		_marker.global_basis = Basis(x, y, x.cross(y)).scaled(Vector3.ONE * size)
	if _hammer.visible:
		_hammer.position = WORK + _hammer_at + Vector3(0.02, _floor(WORK) + 0.03 + 0.14 * (1.0 - _thump), 0)


# --- Laying out ---------------------------------------------------------------------

func lay(i: int, n := 1) -> int:
	## Lays up to n items from inventory slot i on the ground. Returns how many.
	if not recipe.is_empty():
		return 0
	if house:
		Game.notify("Building takes the materials straight from your bag.")
		return 0
	var s = Game.inventory.slots[i]
	if s == null:
		return 0
	var keep: bool = s.has("data") and Items.def(s.id).get("preserves", false)
	if s.has("data") and not keep:
		if s.data.has("bait"):
			Game.notify("This rod is already baited.")
		else:
			Game.notify("Keep the %s in your bag." % Items.item_name(s.id).to_lower())
		return 0
	var p := _pile_of(s.id)
	if p < 0 and piles.size() >= piles_layout().size():
		Game.notify("There's no room to lay out more here.")
		return 0
	var took: Dictionary = Game.inventory.take(i, mini(n, s.n))
	# A preserving pot keeps what is in it (its own pile, never merged).
	_add_pile(took.id, took.n, took.age, s.data if keep else {})
	Sfx.play("pickup", -10.0)
	_rebuild_piles()
	changed.emit()
	return took.n


func take_back(p: int, n := 1) -> void:
	## Picks up to n items off pile p.
	if p < 0 or p >= piles.size():
		return
	var pile: Dictionary = piles[p]
	var k: int = mini(n, pile.n)
	_give(pile.id, k, pile.age, pile.get("data", {}))
	pile.n -= k
	if pile.n <= 0:
		piles.remove_at(p)
	Sfx.play("pickup", -10.0)
	_rebuild_piles()
	changed.emit()


func return_all() -> void:
	## Everything laid out goes back into the inventory, and work in hand is
	## put down (a half-knapped stone is lost).
	cancel()
	if house_log and is_instance_valid(house_log):
		# The log you carried here is back in your arms.
		house_log.visible = true
		if player:
			player.hauling = house_log
		house_log = null
	for pile in piles:
		_give(pile.id, pile.n, pile.age, pile.get("data", {}))
	piles.clear()
	_rebuild_piles()
	changed.emit()


func laid(id: String) -> int:
	## How many laid out will do for `id` (any tree's board for "board").
	var n := 0
	for pile in piles:
		if Items.counts_as(pile.id, id):
			n += pile.n
	return n


func _pile_of(id: String) -> int:
	## The pile of `id` more can go on (never one with its own data).
	for p in piles.size():
		if piles[p].id == id and not piles[p].has("data"):
			return p
	return -1


func _add_pile(id: String, n: int, age: float, data := {}) -> void:
	if not data.is_empty():
		if piles.size() >= piles_layout().size():
			_give(id, n, age, data)
		else:
			piles.append({"id": id, "n": n, "age": age, "data": data})
		return
	var p := _pile_of(id)
	if p < 0:
		if piles.size() >= piles_layout().size():
			_give(id, n, age)
			return
		piles.append({"id": id, "n": 0, "age": age})
		p = piles.size() - 1
	var pile: Dictionary = piles[p]
	pile.age = maxf(pile.age, age) if pile.n > 0 else age
	pile.n += n


func _take_pile(id: String, n: int) -> Array:
	## Takes n that will do for `id` off the piles (exact ones first): the
	## stacks taken, [{id, n, age}].
	var out := []
	var order := piles.filter(func(p): return p.id == id) + piles.filter(func(p): return p.id != id and Items.counts_as(p.id, id))
	for pile in order:
		if n <= 0:
			break
		var k: int = mini(n, pile.n)
		pile.n -= k
		n -= k
		var u := {"id": pile.id, "n": k, "age": pile.age}
		if pile.has("data"):
			u.data = pile.data
		out.append(u)
		if pile.n <= 0:
			piles.erase(pile)
	return out


func _give(id: String, n: int, age: float, data := {}) -> void:
	## Into the inventory, or onto the ground if every slot is taken.
	var left: int = Game.inventory.add(id, n, age, true, data)
	if left > 0 and player and player.world:
		player.world.spawn_pickup(id, left, to_global(Vector3(0, 0.2, 0.3)), age, true, data)


# --- What can be made ----------------------------------------------------------------

func options() -> Array:
	## The recipes the laid-out items are for: [{recipe, missing}], where
	## missing lists what is still needed (empty when it can be made now).
	if house:
		return house.options(_log_id(), player) if _house_ok() else []
	if trap:
		return trap_options()
	if plot:
		return plot_options()
	var out := []
	var b := butcher_option()
	if not b.is_empty():
		out.append(b)
	out.append_array(wood_options())
	out.append_array(station_options())
	for r in Items.recipes_for(where, ["hand", "bench"] if bench else [tier]):
		if bench and r.has("build"):
			continue
		if not Game.knows_recipe(r):
			continue  # needs a rack tool you have never made or held
		if r.has("bait"):
			out.append_array(bait_options(r))
			continue
		if r.in.keys().any(func(id): return laid(id) > 0):
			out.append({"recipe": r, "missing": missing_for(r)})
	return out


func station_options() -> Array:
	## What can be made at the furnace, anvil or meteorite knelt at (recipes
	## `at` it), and at an anvil with a whetstone, sharpening each blunt or worn
	## metal tool you carry.
	var out := []
	if station_kind == "" or station_kind == "water":
		return out
	if station == null or not is_instance_valid(station) or station.is_queued_for_deletion():
		return out
	var shape := shape_option()
	if not shape.is_empty():
		out.append({"recipe": shape, "missing": missing_for(shape)})
	for r in Items.recipes_for(where, ["metal"]):
		if r.get("at", "") == station_kind and (r.in.is_empty() or r.in.keys().any(func(id): return laid(id) > 0)):
			out.append({"recipe": r, "missing": missing_for(r)})
	if station_kind == "anvil":
		var seen := {}
		for i in Game.inventory.SIZE:
			var sl = Game.inventory.slots[i]
			if sl == null or seen.has(sl.id):
				continue
			var edge := int(Items.def(sl.id).get("edge", 0))
			if edge <= 0 or Game.inventory.edge_left(i) >= edge:
				continue
			seen[sl.id] = true
			var r := {"sharpen_tool": sl.id, "out": sl.id, "n": 1, "in": {}, "at": "anvil", "whetstone": true, "act": "steps", "steps": 5, "cat": "Metal",
					"verb": "Sharpen the %s" % Items.item_name(sl.id).to_lower(),
					"label": "Its edge made good again (%s)" % ("blunt now" if Game.inventory.blunt(i) else "%d of %d uses left" % [Game.inventory.edge_left(i), edge]),
					"how": "Click to draw the edge along the wet whetstone, again and again, then hone it fine."}
			out.append({"recipe": r, "missing": missing_for(r)})
	return out


func shape_option() -> Dictionary:
	## The next stage of shaping the anvil stone knelt at (heavy_stone.gd), or {}.
	if station == null or not station.has_method("advance") or station.stage >= station.SEATED:
		return {}
	var r := {"shape_anvil": station.stage, "out": "anvil_stone", "n": 1, "in": {}, "tools": {"stone": 1}, "at": station_kind, "cat": "Metal"}
	match station.stage:
		station.ROUGH:
			r.merge({"act": "peck", "verb": "Peck the face flat",
					"label": "A rough anvil, lighter to carry (%d high spots to knock off)" % station.high_spots(),
					"how": "Strike the high spots off the boulder's face with a river stone until it is flat."}, true)
		station.PECKED:
			r.merge({"in": {"stone_grit": 2, "pot_dirty": 1}, "act": "steps", "steps": 10, "verb": "Grind the face smooth",
					"label": "A dressed anvil, to work castings, bars and iron on (the pot comes back empty)",
					"how": "Click to rub the grit round the face with a river stone, wetting it as you go."}, true)
		station.GROUND:
			r.merge({"act": "steps", "steps": 6, "verb": "Peck a whetstone seat",
					"label": "A seat cut into the anvil's corner, to hold a whetstone",
					"how": "Click to peck a shallow seat into the anvil's corner."}, true)
	return r


func _station_ok() -> bool:
	return station != null and is_instance_valid(station) and not station.is_queued_for_deletion() \
			and station.get("hauled_by") == null


func bait_options(r: Dictionary) -> Array:
	## Baiting a laid-out (unbaited) fishing rod: one option per kind of bait
	## laid beside it, or one saying bait is missing. Nothing without a rod.
	var rod := "fishing_rod_copper" if laid("fishing_rod_copper") > 0 else "fishing_rod"
	if laid(rod) == 0:
		return []
	var out := []
	for pile in piles:
		if "bait" in Items.def(pile.id).get("tags", []) and not out.any(func(o): return o.recipe.bait == pile.id):
			var b: Dictionary = r.duplicate()
			b.in = {rod: 1, pile.id: 1}
			b.rod = rod
			b.bait = pile.id
			b.verb = "Bait the rod with %s" % Items.item_name(pile.id).to_lower()
			out.append({"recipe": b, "missing": []})
	if out.is_empty():
		out.append({"recipe": r, "missing": ["some bait (meat bait, beetle grubs, rotten food or guts)"]})
	return out


func _trap_ok() -> bool:
	return trap != null and is_instance_valid(trap) and not trap.is_queued_for_deletion() and trap.hauled_by == null


func trap_options() -> Array:
	## Baiting the trap you knelt at: one option per kind of bait laid out, or
	## one saying bait is missing. Bait already in it comes back to you.
	if not _trap_ok():
		return []
	var out := []
	var what: String = trap.trap_name()
	var r := {"trap": trap.kind, "out": trap.kind, "n": 1, "in": {}, "act": "steps", "steps": 1, "cat": "Fishing",
			"verb": "Bait the %s" % what, "label": "Baited, ready for the night",
			"how": "Click the glowing spot to set the bait %s. Whatever comes for it in the night is caught." \
				% ("in the basket" if trap.kind == "fish_trap" else "just past the noose")}
	for pile in piles:
		if "bait" in Items.def(pile.id).get("tags", []) and not out.any(func(o): return o.recipe.in.has(pile.id)):
			var b: Dictionary = r.duplicate()
			b.in = {pile.id: 1}
			b.verb = "Bait the %s with %s" % [what, Items.item_name(pile.id).to_lower()]
			if trap.bait != "":
				b.label = "Swaps out the %s already in it" % Items.item_name(trap.bait).to_lower()
			out.append({"recipe": b, "missing": []})
	if out.is_empty():
		out.append({"recipe": r, "missing": ["some bait (meat bait, beetle grubs, rotten food or guts)"]})
	return out


func _plot_ok() -> bool:
	return plot != null and is_instance_valid(plot) and not plot.is_queued_for_deletion() and plot.open_hole()


func plot_options() -> Array:
	## Planting in the hole you knelt at: for each kind of thing laid out, bury
	## it there; with compost laid out too, bury it with the compost. Only a
	## seed or a root (`plant`, `plant_tree`) grows; anything else is buried
	## for good.
	if not _plot_ok():
		return []
	var out := []
	var compost := laid("compost") > 0
	for pile in piles:
		if pile.id == "compost" or out.any(func(o): return o.recipe.in.has(pile.id)):
			continue
		var def := Items.def(pile.id)
		var grows: bool = def.has("plant") or def.has("plant_tree")
		var what := Items.item_name(pile.id).to_lower()
		var r := {"plot": true, "out": pile.id, "n": 1, "in": {pile.id: 1}, "act": "steps", "steps": 2, "cat": "Farming",
				"verb": ("Plant the %s" if grows else "Bury the %s") % what,
				"label": "Sprouts a day after it is buried" if grows else "Buried for good: only a seed or a root grows",
				"how": "Click the hole to set the %s in it, then again to fill the hole in over it." % what}
		out.append({"recipe": r, "missing": []})
		if compost and grows:
			var c: Dictionary = r.duplicate()
			c.in = {pile.id: 1, "compost": 1}
			c.steps = 3
			c.verb = "Plant the %s with compost" % what
			c.label = "Grows twice as fast, for twice the yield"
			c.how = "Click the hole to set the %s in it, again to put the compost in round it, then again to fill the hole in." % what
			out.append({"recipe": c, "missing": []})
	if out.is_empty():
		var r := {"plot": true, "out": "", "n": 1, "in": {}, "act": "steps", "steps": 2, "cat": "Farming",
				"verb": "Plant something", "label": "", "how": ""}
		out.append({"recipe": r, "missing": ["something to plant (a seed or a root), and compost if you like"]})
	return out


func _plot_step() -> void:
	## One click into the hole: the seed or root goes in, then the compost (if
	## any), then the earth over them; then you stand up.
	if not _plot_ok() or used.is_empty():
		return
	steps += 1
	_thump = 1.0
	var id: String = recipe.out
	var with_compost: bool = recipe.in.has("compost")
	if steps < Items.recipe_steps(recipe):
		plot.show_planting(id, with_compost and steps >= 2)
		Sfx.play("rustle", -8.0)
		_rebuild_work()
		changed.emit()
		return
	var it: Dictionary = used.filter(func(u): return u.id == id)[0]
	plot.bury(id, float(it.get("age", 0.0)), with_compost)
	used.clear()
	recipe = {}
	Sfx.play("step", -4.0)
	Game.crafted.emit("planted")
	var def := Items.def(id)
	if def.has("plant") or def.has("plant_tree"):
		Game.notify("You plant the %s%s. It will sprout in a day." % [Items.item_name(id).to_lower(), " with compost" if with_compost else ""])
	else:
		Game.notify("You bury the %s." % Items.item_name(id).to_lower())
	_rebuild_work()
	changed.emit()
	finished.emit(id)
	if player and player.world and player.world.has_method("close_work"):
		player.world.close_work.call_deferred()


func missing_for(r: Dictionary) -> Array:
	## What is still needed to make a recipe here (empty when it can be made).
	if r.has("house"):
		return house.missing_for(r, _log_id(), player) if house and _house_ok() else ["the house site"]
	var missing := []
	for id in r.in:
		var have := laid(id)
		if have < r.in[id]:
			missing.append("%d %s" % [r.in[id] - have, Items.item_name(id)])
	for id in r.get("tools", {}):
		if laid(id) + Game.inventory.count(id) < r.tools[id]:
			missing.append("a %s to work with" % Items.item_name(id))
	if r.has("tool_tag") and laid_tag(r.tool_tag) == "" and not Game.inventory.has_tag(r.tool_tag):
		missing.append(r.get("tool_why", "a %s to work with" % Items.TAG_TOOLS.get(r.tool_tag, r.tool_tag)))
	var tags_missing := false
	for tag in r.get("tool_tags", []):
		if laid_tag(tag) == "" and not Game.inventory.has_tag(tag):
			tags_missing = true
			if not r.has("tool_why"):
				missing.append("a %s to work with" % Items.TAG_TOOLS.get(tag, tag))
	if tags_missing and r.has("tool_why"):
		missing.append(r.tool_why)
	if r.has("at"):
		if station_kind != r.at:
			missing.append({"furnace": "a finished furnace to work at (kneel at it)", "anvil": "an anvil to work at (kneel at it)",
					"meteorite": "a meteorite to work at", "water": "the water to wash it in (kneel looking at the water)"}.get(r.at, r.at))
		elif r.at != "water" and not _station_ok():
			missing.append("the %s, where it stands" % r.at)
		elif r.at == "furnace" and not station.complete():
			missing.append("a finished furnace (it still needs: %s)" % station.next_part().verb.to_lower())
	var shaped: int = int(station.get("stage")) if r.get("at", "") == "anvil" and _station_ok() and station.has_method("advance") else 3
	if r.get("at", "") == "anvil" and not r.has("shape_anvil") and station_kind == "anvil" and shaped < 2:
		missing.append("a dressed anvil (kneel at it to grind its face smooth)")
	elif r.get("whetstone", false) and station_kind == "anvil" and _station_ok() and not station.whetstone:
		missing.append("a whetstone seated in the anvil's corner (%s)" % ("peck a seat into the anvil, then hold one and press E at it" if shaped < 3 else "hold one and press E at the anvil"))
	if r.has("wear") and laid(r.wear) + Game.inventory.count(r.wear) > 0 and _uses_of(r.wear) < r.sharpen.size():
		missing.append("a %s with %d uses left" % [Items.item_name(r.wear), r.sharpen.size()])
	if r.get("tier", "hand") == "bench" and bench == null:
		missing.append("a workbench to make it on")
	if r.has("rack") and (bench == null or not bench.has_tool(r.rack)):
		if not r.get("rack_or_bag", false):
			missing.append("the %s on the workbench rack" % Items.item_name(r.rack))
		elif laid(r.rack) + Game.inventory.count(r.rack) == 0:
			missing.append("a %s (on the workbench rack or in your bag)" % Items.item_name(r.rack).to_lower())
	if r.has("build") and missing.is_empty():
		var site := build_blocker()
		if site != "ok":
			missing.append(site)
	return missing


func _uses_of(id: String) -> int:
	## The most uses left on any one `id` laid out (fresh ones) or carried.
	return maxi(Game.inventory.most_uses(id), int(Items.def(id).get("uses", 0)) if laid(id) > 0 else 0)


func _wear() -> void:
	## A sharpening step wears the tool by a use (one that will last the
	## sharpenings still to come), from the bag or else off its pile.
	var id: String = recipe.wear
	var need: int = recipe.sharpen.filter(func(k): return k >= steps).size()
	var left: int = Game.inventory.wear(id, need)
	if left < 0 and laid(id) > 0:
		var u: Array = _take_pile(id, 1)
		left = int(Items.def(id).uses) - 1
		Game.inventory.add(id, 1, u[0].age if not u.is_empty() else 0.0, true, Items.uses_data(id, left))
		_rebuild_piles()
	if left == 0:
		Game.notify("Your %s is worn down to nothing." % Items.item_name(id).to_lower())


func _house_ok() -> bool:
	return is_instance_valid(house) and not house.is_queued_for_deletion()


func _log_id() -> String:
	## The log carried here for a stilt, as the house wants it ("" if none).
	if house_log and is_instance_valid(house_log) and house_log.kind == "calamites" and house_log.item_id in ["log", "log_stripped"]:
		return house_log.item_id
	return ""


func _carcass_ok() -> bool:
	return is_instance_valid(carcass) and not carcass.is_queued_for_deletion() and carcass.dead \
			and carcass.hauled_by == null and carcass._eater() == null and not carcass.in_jaws()


func butcher_option() -> Dictionary:
	## The next butchering stage for the carcass: {recipe, missing}, or {}.
	if carcass == null or not _carcass_ok():
		return {}
	var r: Dictionary = Items.BUTCHERING[carcass.stage].duplicate()
	var name: String = carcass.def.name
	match r.butcher:
		"gut":
			r.verb = "Gut the %s" % name
		"skin":
			r.verb = "Skin the %s" % name
			var shell: int = carcass.def.drops.get("chitin", 0)
			if shell > 0:
				r.label = "Chitin Plate x%d (the shell)" % shell
				r.how = "Click along the body to prise the shell plates off."
		"cut":
			r.verb = "Cut up the %s" % name
			r.steps = maxi(carcass.cuts_left, 1)
			var meat: String = carcass.def.get("meat", "raw_meat")
			r.out = meat
			r.label = "%s x%d" % [Items.item_name(meat), r.steps]
			if meat != "raw_meat":
				r.how = "Click each glowing spot to cut off a piece of %s." % Items.item_name(meat).to_lower()
	var missing := []
	if laid_tag("cut") == "" and not Game.inventory.has_tag("cut"):
		missing.append("a stone blade")
	return {"recipe": r, "missing": missing}


func _wood_ok() -> bool:
	if not is_instance_valid(wood) or wood.is_queued_for_deletion():
		return false
	if wood.has_method("cut_point"):
		return not wood.falling() and not wood.rotten()
	return wood.hauled_by == null and not wood.rotten()


func wood_on() -> String:
	## What is being worked, as Items.WOODWORK names it: "tree", "felled" or a log id.
	if not tree.is_empty():
		return "tree"
	if wood == null or not _wood_ok():
		return ""
	return "felled" if wood.has_method("cut_point") else wood.item_id


func wood_options() -> Array:
	## What the axe can do to the tree or wood you knelt at: [{recipe, missing}].
	var out := []
	var on := wood_on()
	if on == "":
		return out
	var axe: bool = laid_tag("chop") != "" or Game.inventory.has_tag("chop")
	var saw: bool = laid_tag("saw") != "" or Game.inventory.has_tag("saw")
	var kind: String = tree.kind if on == "tree" else String(wood.get("kind")) if wood else ""
	var hard: bool = Chunk.TREES.has(kind) and not Chunk.TREES[kind].get("soft", true)
	# The best axe you have: a hard tree needs metal, and copper is slow on it.
	var axe_tier := ""
	var ai: int = Game.inventory.tool_slot("chop")
	if laid_tag("chop") != "":
		axe_tier = Items.def(laid_tag("chop")).get("tier", "")
	elif ai >= 0:
		axe_tier = Items.def(Game.inventory.slots[ai].id).get("tier", "")
	for best in Game.inventory.slots:
		if best != null and "chop" in Items.def(best.id).get("tags", []):
			var t: String = Items.def(best.id).get("tier", "")
			if t == "advanced" or (t == "metal" and axe_tier != "advanced"):
				axe_tier = t
	var metal_axe := axe_tier in ["metal", "advanced"]
	for r in Items.woodwork(on):
		r = r.duplicate()
		var missing := []
		if r.wood == "poles" and kind != "calamites":
			continue  # only a hollow Calamites trunk splits into poles
		if r.get("saw", false) and not saw:
			continue  # offered only with a saw
		match on:
			"tree":
				var def: Dictionary = Chunk.TREES[tree.kind]
				r.verb = "Fell the %s" % def.get("name", "tree")
				r.steps = clampi(roundi(tree.r * 20.0), 5, 10)
			"felled":
				var left: int = wood.logs_left()
				if left <= 1:
					r.verb = "Cut away the last log"
					r.label = "%s, and the crown is cut off" % ("Log" if wood.length() >= 1.0 else "Short Log")
				else:
					r.label = "Log (2 m), %d more in the trunk" % (left - 1)
		if r.wood == "hew" and hard:
			missing.append("a saw (too hard to hew)")
		elif hard and not r.get("saw", false) and r.wood in ["fell", "buck", "shorten"]:
			if not metal_axe:
				missing.append("a metal axe (too hard for stone)")
			elif axe_tier == "metal":
				r.steps = Items.recipe_steps(r) * 2  # copper bites slowly into hardwood
				r.label = String(r.get("label", "")) + " (slow going with copper)"
		if missing.is_empty() and not axe and not r.get("saw", false):
			missing.append("a stone axe")
		out.append({"recipe": r, "missing": missing})
	return out


func laid_tag(tag: String) -> String:
	for pile in piles:
		if tag in Items.def(pile.id).get("tags", []):
			return pile.id
	return ""


func can_begin(r: Dictionary) -> bool:
	for o in options():
		if o.recipe == r or (r.has("house") and o.recipe.get("house", "") == r.house) or (r.has("butcher") and o.recipe.get("butcher", "") == r.butcher) \
				or (r.has("wood") and o.recipe.get("wood", "") == r.wood):
			return o.missing.is_empty()
	return false


func begin(r: Dictionary) -> bool:
	## Starts making a recipe from the laid-out items.
	if not recipe.is_empty() or not can_begin(r):
		return false
	used.clear()
	if r.has("house"):
		return _begin_house(r)
	for id in r.in:
		used.append_array(_take_pile(id, r.in[id]))
	recipe = _paced(r)
	progress = 0.0
	steps = 0
	_shown = -1.0
	if r.act == "knap":
		knap_grid = Items.knap_grid("")
		knap_cortex = Items.knap_grid("")
		knap_struck = false
	Sfx.play("pickup", -8.0)
	_rebuild_piles()
	_rebuild_work()
	changed.emit()
	return true


func _paced(r: Dictionary) -> Dictionary:
	## The recipe with its steps for the tools at hand: twice as many with a
	## blunt metal tool, half with its `fast_tool`, its `anvil_steps` at an
	## anvil.
	if r.get("act", "") != "steps" or r.has("house") or r.has("plot") or r.has("trap"):
		return r
	var n := Items.recipe_steps(r)
	var m := n
	if r.has("anvil_steps") and station_kind == "anvil":
		m = int(r.anvil_steps)
	if r.has("fast_tool") and laid(r.fast_tool) + Game.inventory.count(r.fast_tool) > 0:
		m = ceili(m / 2.0)
	var tags: Array = r.get("tool_tags", []).duplicate()
	if r.has("tool_tag"):
		tags.append(r.tool_tag)
	if r.has("wood"):
		tags.append("saw" if r.get("saw", false) else "chop")
	if r.has("butcher"):
		tags.append("cut")
	for tag in tags:
		var i: int = Game.inventory.tool_slot(tag)
		if i >= 0 and Game.inventory.blunt(i) and laid_tag(tag) == "":
			m *= 2
			break
	if m == n:
		return r
	var out := r.duplicate()
	out.steps = m
	return out


func _use_tools(r: Dictionary) -> void:
	## A finished job wears the tools it needed (Inventory.use_tool): stone
	## ones may break, metal edges wear. Not tools laid out on the ground.
	var tags: Array = r.get("tool_tags", []).duplicate()
	if r.has("tool_tag"):
		tags.append(r.tool_tag)
	for tag in tags:
		if tag == "hammer" and r.get("hammer_wear", false):
			continue  # worn a strike at a time instead (_hammer_wear)
		if laid_tag(tag) == "":
			Game.inventory.use_tag(tag)


func _hammer_wear() -> void:
	## A strike on iron with a copper hammer mushrooms its face a little (its
	## `uses`); an iron hammer never wears. A worn-out one is only copper now.
	if Game.inventory.count("iron_hammer") > 0 or laid("iron_hammer") > 0:
		return
	if Game.inventory.count("copper_hammer") == 0:
		return
	var left: int = Game.inventory.wear("copper_hammer")
	if left == 0:
		_give("copper_grains", 2, 0.0)
		Game.notify("Your copper hammer's face is beaten out of shape. It is only good for melting down now: Copper Grains x2.")


func cancel() -> void:
	## Stops making the recipe; its parts go back on the ground.
	if recipe.is_empty():
		return
	if recipe.has("house"):
		_cancel_house()
		return
	if recipe.act == "knap" and knap_struck:
		Game.notify("You discard the half-worked stone.")
	else:
		for u in used:
			_add_pile(u.id, u.n, u.age, u.get("data", {}))
	used.clear()
	recipe = {}
	_rebuild_piles()
	_rebuild_work()
	changed.emit()


func build_blocker() -> String:
	## "ok" when a workbench can go up just in front of the spot, or else what
	## it needs: dry ground with nothing in the way. Uneven ground will do: the
	## legs reach down to it.
	if player == null or player.world == null:
		return "somewhere to build it"
	var why: String = player.world.bench_blocker(to_global(BUILD_AT), global_rotation.y, [player.get_rid()])
	return "ok" if why == "" else why


func _build(r: Dictionary) -> void:
	## Puts up what the recipe builds just in front of the spot, then you stand.
	if r.build is String and r.build != "workbench":
		_build_here(r)
		return
	used.clear()
	recipe = {}
	var world: Node = player.world if player else null
	var at := to_global(BUILD_AT)
	at.y = world.bench_height(at, global_rotation.y)
	if world and world.has_method("add_bench"):
		world.add_bench(at, global_rotation.y)
	Game.unlock_tier("bench")
	Sfx.play("craft", -4.0)
	Game.crafted.emit(r.out)
	Game.notify("You build a workbench. Kneel at it (C) to make things on it.")
	_rebuild_work()
	changed.emit()
	finished.emit(r.out)
	if world and world.has_method("close_work"):
		world.close_work.call_deferred()


func _build_here(r: Dictionary) -> void:
	## A charcoal clamp or a furnace's stone ring, built just in front of you.
	used.clear()
	recipe = {}
	_use_tools(r)
	var world: Node = player.world if player else null
	var at := to_global(Vector3(0, 0, -0.9))
	at.y = _ground_at(at)
	if world and world.has_method("add_" + String(r.build)):
		world.call("add_" + String(r.build), at, global_rotation.y + PI)
	Sfx.play("craft", -4.0)
	Game.crafted.emit(r.out)
	if r.build == "clamp":
		Game.notify("You build a charcoal clamp. Light it with an ember or a lit torch (E), and leave it to smoulder for a day.")
	else:
		Game.notify("You lay the furnace's stone ring. Build the rest on it (E): the clay shaft comes next.")
	_rebuild_work()
	changed.emit()
	finished.emit(r.out)
	if world and world.has_method("close_work"):
		world.close_work.call_deferred()


func _finish_sharpen(r: Dictionary) -> void:
	## A tool drawn along the whetstone: the most worn one of its kind.
	used.clear()
	recipe = {}
	var best := -1
	for i in Game.inventory.SIZE:
		var sl = Game.inventory.slots[i]
		if sl != null and sl.id == r.sharpen_tool and (best < 0 or Game.inventory.edge_left(i) < Game.inventory.edge_left(best)):
			best = i
	if best >= 0:
		Game.inventory.sharpen(best)
		Game.notify("The %s is sharp again." % Items.item_name(r.sharpen_tool).to_lower())
	Sfx.play("craft", -4.0)
	Game.crafted.emit("sharpened")
	_rebuild_work()
	changed.emit()
	finished.emit(r.sharpen_tool)


func _finish_shape(_r: Dictionary) -> void:
	## A stage of shaping the anvil stone done: the next one comes up.
	for u in used:
		var empty: String = Items.def(u.id).get("empty", "")
		if empty != "":
			_give(empty, u.n, 0.0)
	used.clear()
	recipe = {}
	if _station_ok():
		station.advance()
		station_kind = station.station_kind()
		Game.notify(["", "The boulder's face is pecked flat: a rough anvil, and lighter to carry. Grind it smooth with stone grit and a pot of water to work metal on it.",
				"The anvil's face is ground smooth: castings, bars and iron can be worked on it. Peck a seat into its corner for a whetstone.",
				"The seat is cut. Hold a whetstone and press E at the anvil to seat it."][station.stage])
	Sfx.play("craft", -4.0)
	Game.crafted.emit("anvil_shaped")
	_rebuild_work()
	changed.emit()
	finished.emit("anvil_stone")


func _finish(out := "") -> void:
	var r := recipe
	if r.has("build"):
		_build(r)
		return
	if r.has("sharpen_tool"):
		_finish_sharpen(r)
		return
	if r.has("shape_anvil"):
		_finish_shape(r)
		return
	_use_tools(r)
	for id in r.get("give", {}):
		_give(id, int(r.give[id]), 0.0)
	if r.get("cast", false) and not Game.copper_cast:
		Game.copper_cast = true
	if r.get("at", "") == "meteorite" and _station_ok() and station.has_method("chip"):
		var gone: bool = station.chip(Items.weight(r.out))
		if gone:
			station = null
			station_kind = ""
	if r.get("bait", false) is String:
		# A baited rod: the same rod, with its bait in the slot's data.
		used.clear()
		recipe = {}
		var rod: String = r.get("rod", "fishing_rod")
		var data := Items.bait_data(r.bait, rod)
		if Game.inventory.add(rod, 1, 0.0, true, data) > 0 and player and player.world:
			player.world.spawn_pickup(rod, 1, to_global(Vector3(0, 0.2, 0.3)), 0.0, true, data)
		Sfx.play("craft", -4.0)
		Game.crafted.emit("baited")
		Game.notify("You bait the rod with %s." % Items.item_name(r.bait).to_lower())
		_rebuild_work()
		changed.emit()
		finished.emit(rod)
		return
	if r.get("seal", false):
		# A pot of preserves sealed: what was in it goes into the sealed pot.
		var pots: Array = used.filter(func(u): return u.has("data"))
		var data: Dictionary = Preserves.sealed_data(pots[0].data) if not pots.is_empty() else {"items": [], "fluid": "", "w": Items.weight("pot")}
		used.clear()
		recipe = {}
		_give(r.out, 1, 0.0, data)
		Sfx.play("craft", -4.0)
		Game.crafted.emit(r.out)
		Game.notify("You seal the pot. Nothing in it will spoil now.")
		_rebuild_work()
		changed.emit()
		finished.emit(r.out)
		return
	var id: String = out if out != "" else r.out
	var n: int = r.n if id == r.out else 1
	for u in used:
		# A pot of water is used up; the pot comes back.
		var empty: String = Items.def(u.id).get("empty", "")
		if empty != "":
			_give(empty, u.n, 0.0)
	used.clear()
	recipe = {}
	var world: Node = player.world if player else null
	if Items.def(id).get("carry", false) and world and world.has_method("add_carried"):
		# Too big for the bag: it is left standing beside the bench (or the spot).
		for k in n:
			var at := bench.to_global(Vector3(Assets.BENCH_SIZE.x * 0.5 + 1.2, 0, 0.5 + k * 1.6)) if bench \
					else to_global(Vector3(1.4, 0, -0.6 - k * 1.6))
			at.y = _ground_at(at)
			world.add_carried(id, at, global_rotation.y)
	else:
		_give(id, n, 0.0)
	if r.has("guts") and player and player.world and player.world.has_method("add_guts"):
		player.world.add_guts(to_global(Vector3(0.35, 0, -0.3)), r.guts, true)
	Sfx.play("craft", -4.0)
	Game.crafted.emit(id)
	if r.get("read", false):
		Game.notify("You find %s." % Items.item_name(id))  # papers read through (papers.gd), not made
	else:
		Game.notify("Made %s%s." % [Items.item_name(id), " x%d" % n if n > 1 else ""])
	_rebuild_work()
	changed.emit()
	finished.emit(id)


func _bait_trap() -> void:
	## The click that sets the bait in the trap; then you stand up.
	if not _trap_ok() or used.is_empty():
		return
	var id: String = used[0].id
	if trap.bait != "":
		_give(trap.bait, 1, 0.0)
	trap.set_bait(id)
	used.clear()
	recipe = {}
	Sfx.play("rustle", -6.0)
	Game.crafted.emit("baited")
	Game.notify("You bait the %s with %s." % [trap.trap_name(), Items.item_name(id).to_lower()])
	_rebuild_work()
	changed.emit()
	finished.emit(trap.kind)
	if player and player.world and player.world.has_method("close_work"):
		player.world.close_work.call_deferred()


func _butcher_step() -> void:
	## One cut into the carcass. Gutting leaves a guts pile beside it, skinning
	## throws the skin on that pile (or gives the shell as chitin), and each
	## cut of meat comes straight off into your hands.
	if not _carcass_ok():
		return
	steps += 1
	_thump = 1.0
	Sfx.play("hit", -10.0, 0.25)
	var c := carcass
	if recipe.butcher == "cut":
		c.cuts_left -= 1
		var meat: String = c.def.get("meat", "raw_meat")
		_give(meat, 1, 0.0)
		Game.picked.emit(meat)
		c._show_stage()
	if steps < Items.recipe_steps(recipe):
		_rebuild_work()
		changed.emit()
		return
	if laid_tag("cut") == "":
		Game.inventory.use_tag("cut")
	var side: Vector3 = c.global_transform.basis.x.normalized() * (c.def.radius + 0.6)
	var pile_at: Vector3 = c.global_position + side
	match recipe.butcher:
		"gut":
			c.set_stage("gutted")
			if player and player.world and player.world.has_method("add_guts"):
				player.world.add_guts(pile_at, c.def.get("guts", 1))
			Game.notify("You gut the %s. The guts are left in a pile beside it." % c.def.name)
			Game.crafted.emit("gutted")
		"skin":
			c.set_stage("skinned")
			var shell: int = c.def.drops.get("chitin", 0)
			if shell > 0:
				_give("chitin", shell, 0.0)
				Game.notify("You prise off the shell: Chitin Plate x%d." % shell)
			else:
				if player and player.world and player.world.has_method("add_guts"):
					player.world.add_guts(pile_at, 0, true)
				Game.notify("You skin the %s and throw the skin on the guts pile." % c.def.name)
			Game.crafted.emit("skinned")
		"cut":
			Game.notify("You cut up the %s. Nothing is left but bones." % c.def.name)
			Game.crafted.emit("butchered")
			carcass = null
			c.queue_free()
			if player and player.world and player.world.has_method("close_work"):
				player.world.close_work.call_deferred()
	Sfx.play("craft", -4.0)
	used.clear()
	recipe = {}
	_rebuild_work()
	changed.emit()
	finished.emit("")


func _wood_step() -> void:
	## One axe stroke into the wood. The last one fells the tree, cuts the log
	## off the trunk, or finishes stripping, cutting, hewing or splitting it.
	var on := wood_on()
	if on == "":
		return
	steps += 1
	_thump = 1.0
	Sfx.play_at("chop", _marker.global_position, -4.0, 0.2)
	if steps < Items.recipe_steps(recipe):
		_rebuild_work()
		changed.emit()
		return
	var r := recipe
	used.clear()
	recipe = {}
	var world: Node = player.world if player else null
	var tag := "saw" if r.get("saw", false) else "chop"
	if laid_tag(tag) == "":
		Game.inventory.use_tag(tag)
	match r.wood:
		"fell":
			var t := tree
			tree = {}
			var away := -global_basis.z
			away.y = 0.0
			if world and world.has_method("close_work"):
				world.close_work()
			if world and world.has_method("fell_tree"):
				world.fell_tree(t, away.normalized())
			Game.notify("Timber! The %s comes down." % Chunk.TREES[t.kind].name)
			return
		"buck":
			var before: Vector3 = wood.cut_point()
			var last: bool = wood.logs_left() <= 1
			wood.cut_log()
			if last or not _wood_ok():
				wood = null
				Game.notify("You cut the last log off. The crown is left to rot.")
			else:
				# Shuffle along to where the next log comes off.
				var shift: Vector3 = wood.cut_point() - before
				shift.y = 0.0
				global_position += shift
				global_position.y = _ground_at(global_position)
				if player:
					# Onto the ground there: up a slope you would end up
					# inside the hill and drop through it.
					player.global_position += shift
					player.global_position.y = _ground_at(player.global_position) + 0.05
					player.velocity = Vector3.ZERO
		"strip":
			for id in r.give:
				_give(id, r.give[id], 0.0)
				Game.picked.emit(id)
			wood.set_id(r.out)
			Game.notify("You strip the log: %s." % r.label)
		"shorten":
			# Three cuts leave four short logs lying end to end where it was.
			var axis: Vector3 = wood.global_basis.x.normalized()
			var mid: Vector3 = wood.global_position
			var yaw: float = wood.rotation.y
			for i in 3:
				if world and world.has_method("add_log"):
					world.add_log("short_log", mid + axis * (i - 1.5) * Assets.SHORT_LOG_LEN * 1.1, yaw, wood.kind)
			wood.set_id("short_log")
			wood.global_position = mid + axis * 1.5 * Assets.SHORT_LOG_LEN * 1.1
			wood.lie_on_ground()
			wood = null
			Game.notify("You cut the log into four short logs.")
		"hew", "split", "poles", "saw":
			var got := []
			for id in r.give:
				# Boards are of the tree the log came from.
				var gid: String = id
				if id == "board" and Items.exists("board_" + String(wood.kind)):
					gid = "board_" + String(wood.kind)
				_give(gid, r.give[id], 0.0)
				Game.picked.emit(gid)
				got.append("%s x%d" % [Items.item_name(gid), r.give[id]])
			wood.queue_free()
			wood = null
			Game.notify("%s: %s." % [{"hew": "You hew the log into boards", "split": "You split the round", "poles": "You split the trunk into poles",
					"saw": "You saw the log into boards"}[r.wood], ", ".join(got)])
	Sfx.play("craft", -4.0)
	Game.crafted.emit(r.out if r.out != "" else r.wood)
	_rebuild_work()
	changed.emit()
	finished.emit(r.out)
	if wood == null and tree.is_empty() and piles.is_empty() and world and world.has_method("close_work"):
		world.close_work.call_deferred()  # nothing left to work here


func _begin_house(r: Dictionary) -> bool:
	## Starts building the house's next part: its materials come out of your
	## bag (a stilt's log is the one you carried here).
	for id in r.in:
		Game.inventory.remove(id, r.in[id])
		used.append({"id": id, "n": r.in[id], "age": 0.0})
	recipe = r
	steps = 0
	house.set_working(r.house, 0)
	Sfx.play("pickup", -8.0)
	_rebuild_work()
	changed.emit()
	return true


func _cancel_house() -> void:
	for u in used:
		_give(u.id, u.n, u.age)
	used.clear()
	if _house_ok():
		house.set_working("", 0)
	recipe = {}
	_rebuild_work()
	changed.emit()


func _house_step() -> void:
	if not _house_ok():
		return
	var id: String = recipe.house
	var snd: Array = house.step_sound(id, steps)
	Sfx.play_at(snd[0], house.marker(id, steps), snd[1], 0.2)
	steps += 1
	_thump = 1.0
	if steps < recipe.steps:
		house.set_working(id, steps)
		_rebuild_work()
		changed.emit()
		return
	var took := {}
	for u in used:
		took[u.id] = took.get(u.id, 0) + u.n
	if recipe.get("log", false) and house_log and is_instance_valid(house_log):
		took[house_log.item_id] = 1
		house_log.queue_free()
		house_log = null
	used.clear()
	recipe = {}
	Sfx.play("craft", -4.0)
	house.finish_part(id, took)
	Game.crafted.emit("house_" + id)
	_rebuild_work()
	changed.emit()
	finished.emit("")
	if player and player.world and player.world.has_method("close_work"):
		player.world.close_work.call_deferred()  # on to the next part from where it is built


func _ground_at(p: Vector3) -> float:
	var h: float = player.world.floor_height(p) if player and player.world else -INF
	return h if h > -INF else p.y


func _wood_mark(k: int, n: int) -> Vector3:
	## Where the glowing mark for stroke k sits on the wood (world space).
	var f := (k + 0.5) / float(n)
	match recipe.wood:
		"fell":
			# A notch in the near side of the trunk, knee high.
			var c: Vector3 = tree.at
			var side := global_basis.z
			side.y = 0.0
			side = side.normalized()
			var across := side.cross(Vector3.UP)
			return c + side * tree.r * 0.95 + across * tree.r * 0.35 * sin(k * 2.1) + Vector3(0, 0.45 + 0.05 * cos(k * 1.7), 0)
		"buck":
			return wood.cut_point() + Vector3(0, wood.radius(), 0)
	var axis: Vector3 = wood.global_basis.x.normalized()
	var top: Vector3 = wood.global_position + Vector3(0, Assets.LOG_R * 2.0, 0)
	match recipe.wood:
		"shorten":
			# Two strokes for each of three cuts.
			return top + axis * ((k / 2) - 1) * Assets.SHORT_LOG_LEN * 1.0
		"split":
			return top + axis * [0.0, -0.1, 0.1][mini(k, 2)]
	return top + axis * lerpf(-0.8, 0.8, f) * (wood.length() * 0.5)


func instructions() -> String:
	if house:
		if recipe.is_empty():
			var what: String = house.site_name().trim_suffix(" site") if house.has_method("site_name") else "house"
			return "Build the next part of the %s. Its materials come out of your bag." % what
		return "%s: %s  (%d / %d)" % [recipe.verb, house.step_how(recipe.house, steps), steps, recipe.steps]
	if recipe.is_empty():
		if Settings.touch:
			return "Tap items in the tray to lay them on the ground." if piles.is_empty() \
					else "Choose what to make from what you laid out, or add more. Tap a pile to pick one back up."
		if piles.is_empty():
			return "Click items in the tray to lay them on the ground. Right-click lays the whole stack."
		return "Choose what to make from what you laid out, or add more. Click a pile to pick one back up (right-click for all)."
	match recipe.act:
		"twist":
			if Settings.touch:
				return "%s: drag your finger back and forth.  %d%%" % [recipe.verb, roundi(progress * 100.0)]
			return "%s: hold the left mouse button and move the mouse back and forth.  %d%%" % [recipe.verb, roundi(progress * 100.0)]
		"peck":
			var left: int = station.high_spots() if _station_ok() else 0
			return "%s the high spots on the boulder's face to peck them down with the river stone.  %d strikes to go%s" % [
					"Tap" if Settings.touch else "Click", left, "  (that was flat already)" if _wasted else ""]
		"knap":
			return "%s the %s to strike flakes off. Leave only the outlined %s." % ["Tap" if Settings.touch else "Click", _knap_stuff(), Items.item_name(recipe.out).to_lower()]
	var how: String = recipe.how
	var each: Array = recipe.get("step_how", [])
	if not each.is_empty():
		how = each[mini(steps * each.size() / maxi(Items.recipe_steps(recipe), 1), each.size() - 1)]
	if recipe.has("sharpen") and steps in recipe.sharpen:
		how = recipe.get("wear_how", "Sharpen the %s with your blade (it wears one use off)." % Items.item_name(recipe.wear).to_lower())
	var heat := ""
	if recipe.has("melt") and _station_ok() and station.has_method("heat_name"):
		heat = "   Furnace: %s" % station.heat_name()
		if _cold_step:
			heat += " (not hot enough: blow faster)"
	return "%s: %s  (%d / %d)%s" % [recipe.verb, how, steps, Items.recipe_steps(recipe), heat]


# --- Hands-on work -------------------------------------------------------------------

func click(screen: Vector2, right := false) -> void:
	if recipe.is_empty():
		var p := pile_at(screen)
		if p >= 0:
			take_back(p, piles[p].n if right else 1)
		return
	if right:
		return
	match recipe.act:
		"steps":
			if _on_screen(_marker.global_position).distance_to(screen) < PICK_PX * 1.3:
				step()
		"knap":
			var k := cell_at(screen)
			if k >= 0:
				strike(k)
		"peck":
			peck_cell(_peck_cell_at(screen))


func drag(rel: Vector2) -> void:
	## Mouse motion with the left button held.
	if recipe.get("act", "") == "twist":
		_roll += rel.x * 0.02
		twist(absf(rel.x) * TWIST_PER_PX)


func hold(delta: float) -> void:
	## Gamepad: holding the work button twists.
	if recipe.get("act", "") == "twist":
		_roll += delta * 6.0
		twist(delta * 0.35)


func press() -> void:
	## Gamepad: the work button does the next step.
	if recipe.get("act", "") == "steps":
		step()


func step() -> void:
	if recipe.has("house"):
		_house_step()
		return
	if recipe.has("trap"):
		_bait_trap()
		return
	if recipe.has("plot"):
		_plot_step()
		return
	if recipe.has("butcher"):
		_butcher_step()
		return
	if recipe.has("wood"):
		_wood_step()
		return
	if recipe.has("at") and recipe.at != "water" and not _station_ok():
		return  # the anvil or meteorite was carried off
	if recipe.has("melt") and station and station.has_method("blow"):
		# Every click at the furnace is a breath down the blowpipes; while the
		# copper melts, a step only counts at full heat.
		var hot: bool = station.blow(player)
		_cold_step = steps >= recipe.melt[0] and steps < recipe.melt[1] and not hot
		if _cold_step:
			_thump = 0.5
			Sfx.play("rustle", -10.0, 0.3)
			_rebuild_work()
			changed.emit()
			return
	if recipe.get("hammer_wear", false):
		_hammer_wear()
	var sharpening: bool = recipe.has("wear") and steps in recipe.sharpen
	if sharpening:
		_wear()
	steps += 1
	_thump = 1.0
	match "sharpen" if sharpening else recipe.out:
		"sharpen":
			Sfx.play("rustle", -6.0, 0.3)
		"wax":
			Sfx.play("hit", -8.0, 0.2)
		"clay_pot":
			Sfx.play("step", -4.0, 0.2)
		_:
			Sfx.play("pickup", -6.0, 0.25)
	if steps >= Items.recipe_steps(recipe):
		_finish()
		return
	_rebuild_work()
	changed.emit()


func twist(amount: float) -> void:
	if amount <= 0.0:
		return
	progress = minf(progress + amount, 1.0)
	if progress >= 1.0:
		_finish()
		return
	# Rebuild often so the work visibly rolls under the hand, with a soft
	# rustle every few percent and a brighter tick every tenth.
	if progress - _shown >= 0.01 or absf(_roll - _roll_shown) >= 0.25:
		if int(progress * 10.0) != int(_shown * 10.0):
			Sfx.play("pickup", -10.0, 0.1)
		elif int(progress * 40.0) != int(_shown * 40.0):
			Sfx.play("rustle", -18.0, 0.3)
		_rebuild_work()
		changed.emit()


func strike(k: int) -> void:
	if recipe.get("act", "") != "knap" or k < 0 or not knap_grid[k]:
		return
	knap_grid[k] = false
	knap_struck = true
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = k % 5 + o.x
		var y: int = k / 5 + o.y
		if x >= 0 and x < 5 and y >= 0 and y < 5:
			knap_cortex[y * 5 + x] = false
	Sfx.play("knap", -4.0, 0.2)
	_flake(k)
	# Done when only the wanted head is left. Another head's shape only counts
	# once the wanted one can't be reached any more (a cell it needs is gone).
	var result := Items.knap_matches(knap_grid, Items.knap_material(recipe.knap))
	var wanted: Array = Items.knap_grid(recipe.knap)
	var reachable := true
	for m in [wanted, _mirror(wanted)]:
		reachable = true
		for c in 25:
			if m[c] and not knap_grid[c]:
				reachable = false
				break
		if reachable:
			break
	if result == recipe.knap or (result != "" and not reachable):
		_finish(result)
		return
	if not knap_grid.has(true):
		Game.notify("The %s shattered into useless flakes." % _knap_stuff())
		used.clear()
		recipe = {}
		_rebuild_work()
		changed.emit()
		return
	_rebuild_work()
	changed.emit()


func peck_cell(k: int) -> void:
	## A blow of the river stone on cell k of the boulder's face. A blow on a
	## flat cell is wasted; once the face is flat it is a rough anvil.
	if recipe.get("act", "") != "peck" or k < 0 or not _station_ok():
		return
	var hit: bool = station.strike_cell(k)
	_wasted = not hit
	steps += 1
	_thump = 1.0
	Sfx.play("knap" if hit else "hit", -4.0 if hit else -10.0, 0.2)
	if station.high_spots() == 0:
		_finish()
		return
	_rebuild_work()
	changed.emit()


func _peck_cell_at(screen: Vector2) -> int:
	## The cell of the boulder's face under the cursor, or -1.
	if not _station_ok() or not station.has_method("cell_point"):
		return -1
	var px := _on_screen(station.cell_point(12)).distance_to(_on_screen(station.cell_point(13)))
	var best := -1
	var best_d := INF
	for k in 25:
		var d := _on_screen(station.cell_point(k)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = k
	return best if best_d < maxf(px * 0.75, 12.0) else -1


func _knap_stuff() -> String:
	## What is being knapped, as words: "stone" (chert), or "chitin plate".
	var m := Items.knap_material(recipe.get("knap", ""))
	return "stone" if m == "flint" else Items.item_name(m).to_lower()


func _mirror(grid: Array) -> Array:
	var out := []
	for c in 25:
		out.append(grid[c / 5 * 5 + 4 - c % 5])
	return out


func cell_center(k: int) -> Vector3:
	var x := k % 5
	var y := k / 5
	return to_global(WORK + Vector3((x - 2) * KNAP_CELL, _floor(WORK) + 0.09, (y - 2) * KNAP_CELL))


func cell_at(screen: Vector2) -> int:
	## The stone cell under the cursor, or -1.
	var best := -1
	var best_d := INF
	var px := _on_screen(cell_center(12)).distance_to(_on_screen(cell_center(13)))
	for k in 25:
		if not knap_grid[k]:
			continue
		var d := _on_screen(cell_center(k)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = k
	return best if best_d < px * 0.75 else -1


func pile_at(screen: Vector2) -> int:
	var best := -1
	var best_d := PICK_PX
	for p in _piles.size():
		var d := _on_screen(_piles[p].global_position + Vector3(0, 0.04, 0)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = p
	return best


func eye_height() -> float:
	## How high the player's eyes are while working: kneeling on the ground,
	## stooped over a workbench, or standing to build one.
	if house and _house_ok():
		return house.eye_height(recipe.get("house", house.next_part().get("id", "")), player)
	return 1.5 if bench or recipe.get("build", false) else 0.95


func eye_back() -> float:
	## How far behind you the camera stands back, to take in a workbench
	## going up.
	return 0.8 if recipe.get("build", false) else 0.0


func view_points() -> Array:
	## What must stay in view, clear of the work UI's panels (work_ui.gd turns
	## the camera to fit them): the work and its animation, the glowing mark
	## to click and the laid-out piles to pick back up.
	var out := [look_point()]
	if _marker.visible:
		out.append(_marker.global_position)
	# The marks still to come, so none of them turns up under a panel.
	var n := Items.recipe_steps(recipe) if not recipe.is_empty() else 0
	for k in range(steps + 1, n):
		if recipe.has("wood") and wood_on() != "":
			out.append(_wood_mark(k, n))
		elif recipe.has("shape_anvil") and _station_ok():
			out.append(station.shape_mark(k, n))
		elif recipe.get("act", "") == "steps" and not recipe.has("butcher") and not recipe.has("house") and not recipe.has("trap") and not recipe.has("plot"):
			out.append(to_global(_work.transform * _target(recipe.out, k)))
	if recipe.get("act", "") == "peck" and _station_ok():
		for c in [0, 4, 20, 24]:
			out.append(station.cell_point(c))
	if recipe.is_empty():
		for p in _piles:
			out.append(p.global_position + Vector3(0, 0.04, 0))
	if _work.mesh and _work.visible and house == null:
		var box: AABB = _work.global_transform * _work.mesh.get_aabb()
		for i in 8:
			out.append(box.get_endpoint(i))
	return out


func look_point() -> Vector3:
	## What the kneeling player looks at: the work on the ground, or the cut
	## on a felled trunk, or the notch at the foot of a tree.
	if bench:
		return global_position + global_basis.z * -0.05
	if _trap_ok():
		return trap.bait_point()
	if _plot_ok():
		return plot.global_position
	if house and _house_ok():
		if not recipe.is_empty():
			return house.marker(recipe.house, steps)
		var p: Dictionary = house.next_part()
		return house.face_point(p) if not p.is_empty() else house.global_position
	if recipe.get("build", false):
		return to_global(BUILD_AT + Vector3(0, 0.6, 0))
	if (recipe.has("shape_anvil") or recipe.is_empty()) and station_kind in ["anvil", "boulder"] and _station_ok() and station.has_method("cell_point"):
		return station.to_global(Vector3(0, station.ANVIL.y, 0))
	if not tree.is_empty():
		return Vector3(tree.at.x, global_position.y + 0.35, tree.at.z)
	if wood and _wood_ok() and wood.has_method("cut_point"):
		return wood.cut_point()
	return global_position


func marker_position() -> Vector3:
	return _marker.global_position


func _on_screen(p: Vector3) -> Vector2:
	var cam: Camera3D = player.camera if player else get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(p):
		return Vector2(-1e6, -1e6)
	return cam.unproject_position(p)


func _floor(local: Vector3) -> float:
	## Height of the ground at a local point, relative to the spot (a
	## workbench top is flat).
	if bench:
		return 0.0
	var g := to_global(Vector3(local.x, 0, local.z))
	var h: float = player.world.floor_height(g) if player and player.world else -INF
	return clampf(h - global_position.y, -0.3, 0.3) if h > -INF else 0.0


func _fit_to_ground() -> void:
	## Tips the workpiece to the slope under it and lifts it clear of the
	## ground under its corners, so a long piece (a spear) never sinks into a
	## hillside. (A bench top is flat.)
	if bench or _work.mesh == null:
		return
	var box := _work.mesh.get_aabb()
	var s := _work.scale.x
	var mid := _work.position + box.get_center() * s
	var hx := maxf(box.size.x * 0.5 * s, 0.05)
	var hz := maxf(box.size.z * 0.5 * s, 0.05)
	var rise_x := _floor(mid + Vector3(hx, 0, 0)) - _floor(mid - Vector3(hx, 0, 0))
	var rise_z := _floor(mid + Vector3(0, 0, hz)) - _floor(mid - Vector3(0, 0, hz))
	_work.rotation = Vector3(-clampf(atan2(rise_z, 2.0 * hz), -0.4, 0.4), 0.0, clampf(atan2(rise_x, 2.0 * hx), -0.4, 0.4))
	var lift := 0.0
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3.ZERO]:
		var corner := box.get_center() + Vector3(c.x * box.size.x * 0.5, 0.0, c.z * box.size.z * 0.5)
		corner.y = box.position.y
		var at: Vector3 = _work.transform * corner
		lift = maxf(lift, _floor(at) - at.y)
	_work.position.y += lift


# --- Visuals ---------------------------------------------------------------------------

func _rebuild_piles() -> void:
	for n in _piles:
		n.queue_free()
	_piles.clear()
	var spots := piles_layout()
	for p in piles.size():
		var node := Node3D.new()
		add_child(node)
		var at: Vector3 = spots[p]
		node.position = Vector3(at.x, _floor(at), at.z)
		node.rotation.y = 0.4 + p * 0.7
		var mi := MeshInstance3D.new()
		mi.mesh = Assets.mesh("item_" + piles[p].id)
		var size := mi.mesh.get_aabb().size
		mi.scale = Vector3.ONE * minf(1.0, 0.3 / maxf(maxf(size.x, size.z), 0.01))
		node.add_child(mi)
		if piles[p].n > 1:
			var l := Label3D.new()
			l.text = str(piles[p].n)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.font_size = 40
			l.outline_size = 10
			l.pixel_size = 0.0018
			l.position = Vector3(0, 0.12, 0)
			node.add_child(l)
		_piles.append(node)


func _rebuild_work() -> void:
	_rng.seed = 11
	_shown = progress
	_roll_shown = _roll
	_marker.visible = false
	_hammer.visible = false
	_work.position = WORK + Vector3(0, _floor(WORK), 0)
	_work.rotation = Vector3.ZERO
	_work.scale = Vector3.ONE * float(ZOOM.get(recipe.get("out", ""), 1.0))
	if house:
		_work.mesh = null
		if not recipe.is_empty() and _house_ok():
			# Marks on the house itself, drawn over it so nothing hides them.
			_marker.visible = true
			_marker.material_override = _marker_on_top()
			_marker.global_position = house.marker(recipe.house, steps)
		return
	if plot:
		_work.mesh = null
		if _plot_ok():
			if recipe.is_empty():
				plot.show_planting("", false)  # put back, or not begun
			else:
				_marker.visible = true
				_marker.material_override = _marker_on_top()
				_marker.global_position = plot.global_position + Vector3(0, 0.08, 0)
				_marker_size = 2.5
		return
	if trap:
		_work.mesh = null
		if not recipe.is_empty() and _trap_ok():
			_marker.visible = true
			_marker.material_override = _marker_on_top()
			_marker.global_position = trap.bait_point() + Vector3(0, 0.05, 0)
			_marker_size = 2.5
		return
	if recipe.is_empty():
		_work.mesh = null
		return
	if recipe.has("shape_anvil"):
		# Worked on the stone itself: a glowing mark for each step there.
		_work.mesh = null
		if recipe.act == "steps" and _station_ok():
			_marker.visible = true
			_marker.material_override = _marker_on_top()
			_marker.global_position = station.shape_mark(steps, Items.recipe_steps(recipe))
			_marker_size = 1.5
		return
	var b := MeshBuilder.new()
	var k := steps
	var n := Items.recipe_steps(recipe)
	# Every small prey animal is dressed the same way, at its own size.
	match "dress" if recipe.get("dress", false) else recipe.out:
		"cordage", "fishing_line":
			# Three strands that wind tighter around each other (three strings,
			# finer and paler, for a fishing line).
			var line: bool = recipe.out == "fishing_line"
			var from: Color = Items.def("string").color if line else FIBER
			var to: Color = Items.def("fishing_line").color if line else Assets.CORD
			for s in 3:
				var pts := []
				var radii := []
				for i in 13:
					var t := i / 12.0
					var ang := s * TAU / 3.0 + t * TAU * 5.0 * progress + _roll
					var r := lerpf(0.03, 0.007, progress) * (0.6 if line else 1.0)
					pts.append(Vector3(lerpf(-0.22, 0.22, t), 0.02 + sin(ang) * r, cos(ang) * r))
					radii.append(0.003 if line else 0.006)
				b.tube(pts, radii, 3, [from.lerp(to, progress) * (0.9 + s * 0.06)], "fiber")
		"flint_blade", "axe_head", "spear_head", "mattock_head":
			b.blob(Vector3(0, 0.02, 0), Vector3(0.24, 0.035, 0.22), 2, 8, Color(0.5, 0.5, 0.47), _rng, 0.08, "stone")
			Assets.knapped(b, knap_grid, KNAP_CELL, 0.05, Assets.CHERT, _rng, Transform3D(Basis(), Vector3(0, 0.065, 0)), "stone", knap_cortex)
			_outline(b, Items.knap_grid(recipe.knap), 0.1)
		"chitin_hook":
			# A thin plate of shell on the flat stone, flaked down with a blade.
			b.blob(Vector3(0, 0.02, 0), Vector3(0.24, 0.035, 0.22), 2, 8, Color(0.5, 0.5, 0.47), _rng, 0.08, "stone")
			Assets.knapped(b, knap_grid, KNAP_CELL, 0.02, Items.def("chitin").color, _rng, Transform3D(Basis(), Vector3(0, 0.05, 0)), "organic")
			_outline(b, Items.knap_grid(recipe.knap), 0.075)
		"stone_axe":
			Assets.stick(b, _rng, Vector3(-0.3, 0.03, 0.05), Vector3(0.26, 0.03, 0.05), 0.022)
			Assets.knapped(b, Items.knap_grid("axe_head"), 0.036, 0.034, Assets.CHERT, _rng, Transform3D(Basis(), Vector3(0.24, 0.03, -0.025)))
			_wraps(b, Vector3(0.19, 0.03, 0.05), Vector3(0.29, 0.03, 0.05), 0.03, k, n)
		"mattock":
			Assets.stick(b, _rng, Vector3(-0.32, 0.03, 0.0), Vector3(0.28, 0.03, 0.0), 0.022)
			Assets.knapped(b, Items.knap_grid("mattock_head"), 0.04, 0.034, Assets.CHERT, _rng, Transform3D(Basis(), Vector3(0.27, 0.03, 0.0)))
			_wraps(b, Vector3(0.2, 0.03, 0.0), Vector3(0.31, 0.03, 0.0), 0.03, k, n)
		"torch":
			# The stick rolled through the wax picks up a thicker coat.
			Assets.stick(b, _rng, Vector3(-0.3, 0.025, 0), Vector3(0.22, 0.025, 0), 0.02)
			var wax: Color = Items.def("wax").color
			if progress > 0.0:
				b.blob(Vector3(0.18, 0.026, 0), Vector3(0.04 + 0.05 * progress, 0.022 + 0.014 * progress, 0.022 + 0.014 * progress), 3, 7, wax, _rng, 0.12, "organic")
			b.blob(Vector3(0.12, 0.012, 0.13), Vector3(0.08, 0.014, 0.06) * (1.0 - progress * 0.7), 2, 6, wax, _rng, 0.25, "organic")
		"wax":
			var crush := k / float(n)
			b.leaf(Vector3(-0.28, 0.012, 0), Vector3(1, 0, 0), 0.56, 0.24 * (1.0 - crush * 0.4), 0.0, 4, Items.def("frond").color.darkened(crush * 0.35))
			if k > 0:
				b.blob(Vector3(0.0, 0.016, 0.0), Vector3(0.03 + crush * 0.05, 0.012, 0.025 + crush * 0.04), 2, 7, Items.def("wax").color, _rng, 0.2, "organic")
			_hammer.mesh = Assets.mesh("item_stone")
			_hammer.scale = Vector3.ONE * 0.6
			_hammer_at = Vector3.ZERO
			_hammer.visible = true
		"smashed_native_copper", "stone_grit", "crushed_copper_ore":
			# The lump shrinks as it is beaten, the grit spreading round it
			# (bright copper threads in native copper's), and the striker
			# thumps down on each click: a river stone, or a hammer for ore.
			var crush := k / float(n)
			var lump: String = recipe.in.keys()[0]
			var col: Color = Items.def(lump).color
			var r := 0.08 * (1.0 - crush * 0.7)
			b.blob(Vector3(0, r * 0.8, 0), Vector3(r, r * 0.8, r * 0.9), 3, 8, col, _rng, 0.25, "solid")
			for i in k * 6:
				var a := _rng.randf() * TAU
				var d := _rng.randf_range(0.05, 0.08 + crush * 0.06)
				var g := _rng.randf_range(0.006, 0.012)
				var fleck: bool = recipe.out == "smashed_native_copper" and i % 3 == 0
				b.blob(Vector3(cos(a) * d, g * 0.5, sin(a) * d), Vector3(g, g * 0.6, g), 2, 5,
						COPPER.lightened(0.15) if fleck else col.darkened(_rng.randf_range(0.0, 0.2)), _rng, 0.3, "metal" if fleck else "solid")
			var hammer: bool = recipe.out == "crushed_copper_ore"
			_hammer.mesh = Assets.mesh("item_stone" if not hammer else
					("item_iron_hammer" if Game.inventory.count("iron_hammer") > 0 or laid("iron_hammer") > 0 else "item_copper_hammer"))
			_hammer.scale = Vector3.ONE * (1.0 if hammer else 0.45)
			# Its face (a hammer's head, at the end of the handle) on top of the lump.
			var box: AABB = _hammer.mesh.get_aabb()
			var face := Vector3(box.end.x - 0.03 if hammer else box.get_center().x, box.position.y, box.get_center().z) * _hammer.scale.x
			_hammer_at = Vector3(-face.x - 0.02, r * 1.6 - face.y - 0.03, -face.z)
			_hammer.visible = true
		"spear":
			Assets.stick(b, _rng, Vector3(-0.75, 0.026, 0), Vector3(0.05, 0.026, 0), 0.022)
			Assets.stick(b, _rng, Vector3(-0.01, 0.026, 0), Vector3(0.67, 0.026, 0), 0.02)
			Assets.knapped(b, Items.knap_grid("spear_head"), 0.036, 0.03, Assets.CHERT, _rng, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.75, 0.026, 0)))
			_wraps(b, Vector3(-0.04, 0.026, 0), Vector3(0.08, 0.026, 0), 0.027, mini(k, 3), 3)
			_wraps(b, Vector3(0.62, 0.026, 0), Vector3(0.7, 0.026, 0), 0.025, maxi(k - 3, 0), 3)
		"bow_drill":
			var bow := []
			for i in 7:
				var t := i / 6.0
				bow.append(Vector3(lerpf(-0.26, 0.26, t), 0.018, -sin(t * PI) * 0.07))
			b.tube(bow, [0.012, 0.014, 0.015, 0.015, 0.015, 0.014, 0.012], 5, [Assets.WOOD], "wood")
			var thread: Color = Items.def("string").color
			if k >= 2:
				b.cylinder(bow[0], bow[6], 0.003, 0.003, 3, thread, Color(-1, 0, 0), "fiber")
			elif k == 1:
				b.cylinder(bow[0], bow[0] + Vector3(0.12, -0.01, 0.1), 0.003, 0.003, 3, thread, Color(-1, 0, 0), "fiber")
			Assets.stick(b, _rng, Vector3(-0.1, 0.014, 0.12), Vector3(0.12, 0.014, 0.15), 0.013)
		"stick":
			# The branch snapped into shorter and shorter lengths.
			var cuts := [-0.3]
			for i in k:
				cuts.append(lerpf(-0.3, 0.3, (i + 1.0) / (n + 1.0)))
			cuts.append(0.3)
			for i in cuts.size() - 1:
				var gap := 0.015 * i
				Assets.stick(b, _rng, Vector3(cuts[i] + gap + 0.005, 0.02, 0.02 * (i % 2)), Vector3(cuts[i + 1] + gap - 0.005, 0.02, 0.02 * (i % 2)), 0.018)
		"campfire_kit":
			for i in mini(k, 5):
				var z := (i - 2) * 0.035
				Assets.stick(b, _rng, Vector3(-0.25, 0.025 + (i % 2) * 0.03, z), Vector3(0.25, 0.025 + (i % 2) * 0.03, z + 0.01), 0.022)
			if k > 5:
				b.blob(Vector3(0, 0.1, 0), Vector3(0.07, 0.03, 0.05), 2, 5, Color(0.70, 0.58, 0.38), _rng, 0.3, "wood")
			if k > 6:
				b.blob(Vector3(-0.1, 0.05, 0.16), Vector3(0.07, 0.05, 0.06), 2, 6, Color(0.55, 0.55, 0.52), _rng, 0.15, "stone")
		"clay_pot":
			var col: Color = Items.def("clay").color
			if k > 0:
				Assets.pot(b, col, 1.0, k / float(n))
			b.blob(Vector3(0.2, 0.04, 0.02), Vector3(0.1, 0.05, 0.08) * (1.0 - k / float(n) * 0.7), 2, 6, col, _rng, 0.12, "clay")
		"bandage":
			b.leaf(Vector3(-0.3, 0.012, 0), Vector3(1, 0, 0), 0.6, 0.26, 0.0, 4, Items.def("frond").color)
			for i in k:
				b.box(Vector3(-0.2 + i * 0.1, 0.02, 0), Vector3(0.018, 0.006, 0.24), FIBER * (0.95 + 0.08 * (i % 2)), Basis(), "fiber")
		"fiber_sack", "cloth_sack", "bedroll":
			# Rows woven across the warp: fiber over cordage, or string over
			# string (a cloth sack, or a bedroll's coarse sheet).
			var cloth: bool = recipe.out != "fiber_sack"
			var warp: Color = Items.def("string").color if cloth else Assets.CORD
			var weft: Color = Items.def(recipe.out).color if cloth else FIBER
			for i in 4:
				var x := -0.15 + i * 0.1
				b.cylinder(Vector3(x, 0.012, -0.18), Vector3(x, 0.012, 0.18), 0.004 if cloth else 0.006, 0.004 if cloth else 0.006, 4, warp, Color(-1, 0, 0), "fiber")
			for i in k:
				b.box(Vector3(0, 0.018, -0.16 + i * 0.045), Vector3(0.36, 0.008 if cloth else 0.01, 0.035), weft * (0.96 + 0.05 * (i % 2)) if cloth else weft * (0.92 + 0.1 * (i % 2)), Basis(), "fiber")
		"dress":
			# Slit along the belly, gutted, then skinned.
			var whole: String = recipe.in.keys()[0]
			var animal: String = Items.def(whole).get("animal", "")
			var sc: float = Items.def(whole).get("body_scale", 1.0)
			var col: Color = Items.def(whole if k < 3 else recipe.out).color
			Assets.small_prey(b, _rng, col, animal, k < 3, Vector3.ZERO, sc)
			if k >= 1 and k < 3:
				# The slit, as long as the body.
				var slit: float = Assets.prey_body(animal).x * 1.7
				b.box(Vector3(0.0, Assets.prey_top(animal) + 0.002, 0.0) * sc, Vector3(slit * minf(k, 2) / 2.0 * sc, 0.004, 0.012 * sc), Color(0.62, 0.22, 0.24), Basis(), "organic")
			if k >= 2:
				Assets.gut_coil(b, _rng, Vector3(0.05, 0, 0.17) * sc, Items.def("guts").color)
			if k >= 3:
				b.blob(Vector3(-0.12, 0.008, 0.18) * sc, Vector3(0.11 * sc, 0.008, 0.05 * sc), 2, 6, Items.def(whole).color.darkened(0.2), _rng, 0.3, "organic")
		"workbench":
			# It goes up full size in front of the spot, its legs reaching
			# down to the ground.
			var at := to_global(BUILD_AT)
			var y: float = player.world.bench_height(at, global_rotation.y)
			var drop := []
			for c in Assets.bench_legs():
				drop.append(maxf(y - _ground_at(at + global_basis * c), 0.0))
			Assets.workbench(b, _rng, k, drop)
		"vessel_open_unfired", "vessel_sealed_unfired":
			# Coiled up on the platter (the jar's lid pressed out last).
			var col: Color = Items.def("clay").color
			var sealed: bool = recipe.out.begins_with("vessel_sealed")
			Assets.platter(b, Items.def("clay_platter").color, 1.0, Vector3(0, 0, -0.05))
			var coils := mini(k, 5)
			if coils > 0:
				Assets.vessel(b, col, sealed, coils / 5.0 if k < n else 1.0, Vector3(0, 0.012, -0.05))
			if sealed and k >= 6 and k < n:
				b.lathe([Vector2(0.0, 0.03), Vector2(0.15, 0.03), Vector2(0.15, 0.0), Vector2(0.0, 0.0)], 12, col, "clay", Vector3(0.38, 0, 0.1))
		"fish_trap":
			# Hoops first, then the ribs lashed round them, then the funnel; the
			# sticks still to go in lie in front.
			if k > 0:
				Assets.fish_trap(b, _rng, k / float(n), Vector3.ZERO, FISH_TRAP_SIZE)
			for i in maxi(5 - k, 0):
				Assets.stick(b, _rng, Vector3(-0.25, 0.012 + 0.02 * (i % 2), 0.3 + 0.025 * i), Vector3(0.25, 0.012 + 0.02 * (i % 2), 0.31 + 0.025 * i), 0.01)
		"snare":
			Assets.snare_kit(b, _rng, k / float(n))
		"baitbox":
			# The board until it is sawn, then the base and the sides pinned
			# on, then the meat packed in.
			if k == 0:
				b.box(Vector3(0.0, 0.025, 0.0), Vector3(0.6, 0.05, 0.2), Items.def("board").color, Basis(), "wood")
			else:
				Assets.baitbox(b, _rng, Items.def("baitbox").color, k / float(n))
		"compost_basket":
			# Posts first, then the slats round the sides, course by course.
			if k > 0:
				Assets.compost_basket(b, _rng, k / float(n), Vector3.ZERO, 0.45)
			for i in maxi(4 - maxi(k - 2, 0), 0):
				b.box(Vector3(0.0, 0.02 + 0.03 * i, 0.3), Vector3(0.4, 0.025, 0.08), Items.def("board").color * (0.95 - i * 0.04), Basis(Vector3.UP, 0.1 * i), "wood")
		"canteen":
			# Sawn from the board, hollowed, sealed with wax, stopped and corded.
			var left := 1.0 - minf(k, 2) / 2.0
			if left > 0.0:
				b.box(Vector3(0.0, 0.025, 0.2), Vector3(0.6 * left + 0.1, 0.05, 0.2), Items.def("board").color, Basis(), "wood")
			if k >= 1:
				Assets.canteen(b, Items.def("canteen").color, Vector3(0, 0, -0.08), k / float(n))
			if k >= 2 and k < 4:
				b.blob(Vector3(0.18, 0.02, -0.05), Vector3(0.04, 0.02, 0.03), 2, 6, Items.def("wax").color, _rng, 0.2, "organic")
		"flask":
			# Two bars beaten flat, raised into bowls, seamed and necked,
			# waxed, then stoppered and corded (Assets.flask's stages).
			var bars := maxi(2 - k, 0)
			for i in bars:
				b.box(Vector3(0.12 - i * 0.24, 0.012, 0.12), Vector3(0.12, 0.024, 0.04), Items.def("copper_bar").color, Basis(), "metal")
			if k >= 1:
				Assets.flask(b, Items.def("wax").color if k >= 7 else Assets.FLASK_COPPER, Vector3(0, 0, -0.05),
						[0.0, 0.1, 0.3, 0.4, 0.5, 0.75, 0.8, 1.0][mini(k, 7)])
		"soup_pot_unfired":
			# Coiled up on the platter, then the tripod boards pinned together.
			var col: Color = Items.def("clay").color
			var coils := mini(k, 5)
			Assets.platter(b, Items.def("clay_platter").color, 1.0, Vector3(0, 0, -0.05))
			if coils > 0:
				Assets.pot(b, col, 1.9, coils / 5.0, Vector3(0, 0.012, -0.05))
			for i in 3:
				var z := 0.22 + i * 0.07
				if i < k - 5:
					b.box(Vector3(0.0, 0.02 + 0.012 * i, z), Vector3(1.2, 0.035, 0.11), Items.def("board").color * (0.95 - i * 0.04), Basis(Vector3.UP, 0.05 * (i - 1)), "wood")
				else:
					b.box(Vector3(0.0, 0.02, 0.35 + i * 0.02), Vector3(1.2, 0.035, 0.11), Items.def("board").color * 0.9, Basis(Vector3.UP, 0.3 + i * 0.1), "wood")
		"clay_platter_unfired":
			var col: Color = Items.def("clay").color
			if k > 0:
				Assets.platter(b, col, k / float(n))
			b.blob(Vector3(0.24, 0.04, 0.1), Vector3(0.09, 0.05, 0.07) * (1.0 - k / float(n) * 0.7), 2, 6, col, _rng, 0.12, "clay")
		"rod_blank":
			# A branch: its side shoots sawn off, then the rod scraped to a taper.
			var trimmed := mini(k, 2)
			Assets.stick(b, _rng, Vector3(-0.6, 0.02, 0), Vector3(0.6, 0.02, 0), 0.02 if k < 3 else 0.016)
			for i in 2 - trimmed:
				var x := -0.15 + i * 0.35
				Assets.stick(b, _rng, Vector3(x, 0.02, 0), Vector3(x + 0.14, 0.02, 0.14 * (1 if i == 0 else -1)), 0.01, true)
			if k >= 3:
				b.cylinder(Vector3(0.3, 0.02, 0), Vector3(0.6, 0.02, 0), 0.016, 0.008, 6, Assets.CUT_WOOD, Color(-1, 0, 0), "wood")
			for i in mini(k * 3, 10):
				b.box(Vector3(_rng.randf_range(-0.4, 0.4), 0.002, _rng.randf_range(0.05, 0.12)), Vector3(0.02, 0.002, 0.006),
						Assets.CUT_WOOD, Basis(Vector3.UP, _rng.randf() * PI), "wood")
		"fishing_rod":
			# The line tied on at the tip, run down the rod, then the hook (or,
			# baiting, the finished rod with the bait beside its hook).
			var baiting: bool = recipe.get("bait", false) is String
			if baiting:
				k = 3
				b.blob(Vector3(-0.2, 0.02, 0.12), Vector3(0.03, 0.02, 0.025), 1, 5, Items.def(recipe.bait).color, _rng, 0.3, "organic")
			var tip := Vector3(0.6, 0.02, 0)
			Assets.stick(b, _rng, Vector3(-0.6, 0.02, 0), Vector3(0.3, 0.02, 0), 0.016)
			b.cylinder(Vector3(0.3, 0.02, 0), tip, 0.016, 0.008, 6, Assets.CUT_WOOD, Color(-1, 0, 0), "wood")
			var line: Color = Items.def("fishing_line").color
			if k == 0:
				b.cylinder(Vector3(0.1, 0.008, 0.14), Vector3(0.1, 0.03, 0.14), 0.04, 0.04, 8, line, Color(-1, 0, 0), "fiber")
			else:
				b.cylinder(tip, tip + Vector3(-0.02, 0, 0.02), 0.012, 0.012, 5, line, Color(-1, 0, 0), "fiber")
				var end := Vector3(-0.3, 0.025, 0.012) if k >= 2 else Vector3(0.45, 0.01, 0.12)
				b.cylinder(tip, end, 0.002, 0.002, 3, line, Color(-1, 0, 0), "fiber")
			Assets.knapped(b, Items.knap_grid("chitin_hook"), 0.008, 0.004, Items.def("chitin_hook").color, _rng,
					Transform3D(Basis(), Vector3(-0.32, 0.01, 0.06)), "organic")
		"meat_bait":
			# The meat torn into smaller and smaller pieces.
			var left := 1.0 - k / float(n)
			var meat: Color = Items.def("raw_meat").color
			if left > 0.0:
				b.blob(Vector3(0, 0.04, 0), Vector3(0.12, 0.04, 0.09) * (0.4 + 0.6 * left), 2, 7, meat, _rng, 0.12, "organic")
			for i in k * 2:
				var a := TAU * i / 6.0 + 0.4
				b.blob(Vector3(cos(a) * 0.18, 0.015, sin(a) * 0.14), Vector3(0.025, 0.015, 0.02), 1, 5, Items.def("meat_bait").color, _rng, 0.3, "organic")
		"spindle_whorl_unfired":
			# A ball of clay, pressed into a disc, then pierced.
			var col: Color = Items.def("clay").color
			if k < 2:
				b.blob(Vector3(0, 0.03, 0), Vector3(0.035, 0.03, 0.035), 4, 7, col, _rng, 0.3 if k == 0 else 0.03, "clay")
			else:
				Assets.whorl(b, col, Vector3(0, 0.008, 0), Vector3.UP, false)
		"spindle":
			# The stick whittled smooth, then the whorl pushed onto it.
			Assets.stick(b, _rng, Vector3(-0.22, 0.016, 0), Vector3(0.22, 0.016, 0), 0.012 if k >= 1 else 0.015)
			if k >= 2:
				Assets.whorl(b, Items.def("spindle_whorl").color, Vector3(-0.13, 0.04, 0), Vector3.RIGHT, true)
			else:
				Assets.whorl(b, Items.def("spindle_whorl").color, Vector3(0.05, 0.008, 0.12), Vector3.UP, true)
			if k >= 1:
				for i in 6:
					b.box(Vector3(_rng.randf_range(-0.15, 0.15), 0.002, _rng.randf_range(0.04, 0.09)), Vector3(0.02, 0.002, 0.006),
							Assets.CUT_WOOD, Basis(Vector3.UP, _rng.randf() * PI), "wood")
		"string":
			# A spindle turning by the fiber: its thread draws out finer and
			# winds on above the whorl as the work goes.
			var sp_from := Vector3(-0.26, 0.04, 0.08)
			var sp_to := Vector3(0.12, 0.04, 0.08)
			var turn := Basis(Vector3.RIGHT, _roll * 3.0)
			Assets.stick(b, _rng, sp_from, sp_to, 0.009)
			Assets.whorl(b, Items.def("spindle_whorl").color, sp_from.lerp(sp_to, 0.25), Vector3.RIGHT, true)
			var thread: Color = FIBER.lerp(Items.def("string").color, progress)
			if progress > 0.0:
				b.cylinder(sp_from.lerp(sp_to, 0.35), sp_from.lerp(sp_to, 0.35 + 0.4 * progress), 0.012 + 0.012 * progress, 0.012 + 0.012 * progress, 6,
						thread, Color(-1, 0, 0), "fiber")
			var pts := []
			var radii := []
			for i in 9:
				var t := i / 8.0
				var w := turn * Vector3(0, sin(t * TAU * 3.0) * 0.004, cos(t * TAU * 3.0) * 0.004)
				pts.append(Vector3(lerpf(0.12, 0.3, t), 0.04 - t * 0.02, lerpf(0.08, -0.04, t)) + w)
				radii.append(lerpf(0.003, 0.012 * (1.0 - progress * 0.6), t))
			b.tube(pts, radii, 3, [thread], "fiber")
			b.blob(Vector3(0.3, 0.025, -0.06), Vector3(0.07, 0.025, 0.06) * (1.0 - progress * 0.75), 2, 6, FIBER, _rng, 0.35, "fiber")
		"clay_bowl_unfired":
			var col: Color = Items.def("clay").color
			Assets.bowl(b, col, Vector3.ZERO, 1.0, maxf(k / float(n), 0.15))
			b.blob(Vector3(0.22, 0.04, 0.08), Vector3(0.08, 0.045, 0.06) * (1.0 - k / float(n) * 0.7), 2, 6, col, _rng, 0.12, "clay")
		"woodworking_tools":
			Assets.chisel_saw(b, _rng, k)
		"papermaking_tools":
			Assets.paper_screen(b, _rng, Vector3(-0.1, 0, 0), k / float(n))
			Assets.bowl(b, Items.def("clay_bowl").color, Vector3(0.24, 0, 0.02), 0.9)
		"paper_wet":
			# Fiber mashed to pulp in the bowl, then a sheet lifted on the screen.
			var bowl_at := Vector3(0.2, 0, 0.02)
			var pulp: Color = Items.def("paper_wet").color
			var mashed := mini(k, 3) / 3.0
			Assets.bowl(b, Items.def("clay_bowl").color, bowl_at, 1.3)
			b.cylinder(bowl_at + Vector3(0, 0.014, 0), bowl_at + Vector3(0, 0.07, 0), 0.12, 0.15, 10, Color(0.36, 0.38, 0.28).lerp(pulp, mashed), Color(-1, 0, 0), "organic")
			if mashed < 1.0:
				b.blob(bowl_at + Vector3(0, 0.08, 0), Vector3(0.09, 0.03, 0.08) * (1.0 - mashed * 0.8), 2, 6, FIBER, _rng, 0.3, "fiber")
			Assets.paper_screen(b, _rng, Vector3(-0.18, 0, 0), 1.0)
			if k >= 3:
				Assets.paper(b, _rng, pulp, Vector3(-0.18, 0.022, 0), 0.0 if k == 3 else 1.0, 0.58)
		"pencil_core_unfired":
			# Ash kneaded into the clay, then rolled out into a thin rod.
			var clay: Color = Items.def("clay").color
			var mix: Color = Items.def("pencil_core_unfired").color
			match k:
				0:
					b.blob(Vector3(-0.07, 0.03, 0), Vector3(0.05, 0.03, 0.045), 2, 6, clay, _rng, 0.15, "clay")
					b.blob(Vector3(0.08, 0.015, 0), Vector3(0.05, 0.015, 0.05), 2, 6, Items.def("ash").color, _rng, 0.3, "organic")
				1:
					b.blob(Vector3(0, 0.03, 0), Vector3(0.05, 0.03, 0.045), 4, 10, mix, _rng, 0.06, "clay")
				_:
					b.cylinder(Vector3(-0.07, 0.014, 0), Vector3(0.07, 0.014, 0), 0.014, 0.014, 8, mix, Color(-1, 0, 0), "clay")
		"ash_pencil":
			Assets.pencil(b, _rng, k)
		"pot_sealed":
			# The open pot of preserves; the cap pressed into its mouth, then
			# the wax worked round the rim, half and then all the way.
			Assets.pot(b, Assets.FIRED, 1.0)
			b.lathe([Vector2(0.075, 0.17), Vector2(0.0, 0.17)], 10, Items.def("pot_preserves").color, "solid", Vector3.ZERO, false)
			var cap := Vector3.ZERO if k >= 1 else Vector3(0.24, -0.196, 0.04)
			b.cylinder(cap + Vector3(0, 0.196, 0), cap + Vector3(0, 0.212, 0), 0.08, 0.074, 10, Assets.CANTEEN_WOOD, Assets.CANTEEN_WOOD * 0.9, "wood")
			b.cylinder(cap + Vector3(0, 0.212, 0), cap + Vector3(0, 0.228, 0), 0.016, 0.013, 7, Assets.CANTEEN_WOOD * 0.92, Color(-1, 0, 0), "wood")
			var wax: Color = Items.def("wax").color
			if k >= 2:
				b.cylinder(Vector3(0, 0.183, 0), Vector3(0, 0.196, 0), 0.086, 0.086, 10, wax, Color(-1, 0, 0), "solid")
			else:
				b.blob(Vector3(-0.22, 0.02, 0.06), Vector3(0.04, 0.02, 0.035), 2, 6, wax, _rng, 0.2, "solid")
		"chart_map":
			# The pencil sharpened, then a border ruled round the sheet (two
			# sides at a time) and a compass rose in its corner.
			Assets.paper(b, _rng, Items.def("paper_sheet").color, BLUEPRINT_AT, 1.0, 0.85)
			var sides := [[Vector2(-0.2, -0.14), Vector2(0.2, -0.14)], [Vector2(0.2, -0.14), Vector2(0.2, 0.14)],
					[Vector2(0.2, 0.14), Vector2(-0.2, 0.14)], [Vector2(-0.2, 0.14), Vector2(-0.2, -0.14)]]
			for j in mini(maxi(k - 1, 0) * 2, 4):
				Assets.line_on(b, BLUEPRINT_AT, sides[j][0], sides[j][1])
			if k >= 4:
				var rose := Vector2(0.14, 0.08)
				Assets.line_on(b, BLUEPRINT_AT, rose + Vector2(0, -0.04), rose + Vector2(0, 0.04))
				Assets.line_on(b, BLUEPRINT_AT, rose + Vector2(-0.03, 0), rose + Vector2(0.03, 0))
			Assets.pencil(b, _rng)
			if k == 0:
				b.blob(Vector3(0.2, 0.012, 0.035), Vector3(0.05, 0.007, 0.022), 2, 6, Assets.CHERT, _rng, 0.1, "stone")
			for i in mini(k, 3):
				b.box(Vector3(0.17 + _rng.randf_range(0, 0.08), 0.002, _rng.randf_range(0.03, 0.09)), Vector3(0.012, 0.002, 0.006),
						Assets.CUT_WOOD, Basis(Vector3.UP, _rng.randf() * PI), "wood")
		"blueprint_softwood_house":
			# The house drawn a few lines at a time on the sheet, the pencil
			# beside it, sharpened with the blade at the start and halfway.
			Assets.paper(b, _rng, Items.def("paper_sheet").color, BLUEPRINT_AT, 1.0, 0.85)
			var drawn: int = k - recipe.sharpen.filter(func(s): return s < k).size()
			for g in drawn:
				for seg in Assets.blueprint_lines(g):
					Assets.line_on(b, BLUEPRINT_AT, seg[0], seg[1])
			Assets.pencil(b, _rng)
			if k in recipe.sharpen:
				b.blob(Vector3(0.2, 0.012, 0.035), Vector3(0.05, 0.007, 0.022), 2, 6, Assets.CHERT, _rng, 0.1, "stone")
			for i in mini(k, 6):
				b.box(Vector3(0.17 + _rng.randf_range(0, 0.08), 0.002, _rng.randf_range(0.03, 0.09)), Vector3(0.012, 0.002, 0.006),
						Assets.CUT_WOOD, Basis(Vector3.UP, _rng.randf() * PI), "wood")
		"keycard_jr":
			# The stack of papers on the left, those read turned over on the right.
			for i in n:
				var read := i < k
				var y := 0.002 + (i if read else n - 1 - i) * 0.004
				var at := Vector3(0.16 if read else -0.13, y, 0.0)
				var turn := _rng.randf_range(-0.12, 0.12)
				b.box(at, Vector3(0.21, 0.002, 0.28), Items.def("papers").color * _rng.randf_range(0.9, 1.0), Basis(Vector3.UP, turn), "fiber")
		"beam_segment":
			b.cylinder(Vector3(-0.35, 0.07, 0), Vector3(0.35, 0.07, 0), 0.06, 0.06, 8, STEEL, Color(-1, 0, 0), "metal")
			for i in 2:
				var x := -0.15 + i * 0.3
				if i < k:
					b.cylinder(Vector3(x - 0.05, 0.07, 0), Vector3(x + 0.05, 0.07, 0), 0.1, 0.1, 8, COPPER)
				else:
					b.cylinder(Vector3(x, 0.0, 0.25), Vector3(x, 0.1, 0.25), 0.1, 0.1, 8, COPPER)
		"injector":
			b.box(Vector3(0, 0.01, -0.05), Vector3(0.5, 0.02, 0.2), Color(0.4, 0.42, 0.45), Basis(), "metal")
			if k >= 1:
				b.box(Vector3(-0.1, 0.1, -0.05), Vector3(0.18, 0.18, 0.12), Color(0.25, 0.45, 0.85))
			else:
				b.box(Vector3(-0.3, 0.06, 0.2), Vector3(0.12, 0.18, 0.18), Color(0.25, 0.45, 0.85))
			if k >= 2:
				b.tube([Vector3(-0.1, 0.2, -0.05), Vector3(0.0, 0.24, -0.05), Vector3(0.12, 0.06, -0.05)], [0.01, 0.01, 0.01], 4, [COPPER])
			else:
				b.cylinder(Vector3(0.25, 0, 0.2), Vector3(0.25, 0.1, 0.2), 0.1, 0.1, 8, COPPER)
	_work.mesh = b.commit(Assets.materials) if not b.is_empty() else null
	_fit_to_ground()
	if recipe.out == "workbench":
		_work.position = BUILD_AT + Vector3(0, player.world.bench_height(to_global(BUILD_AT), global_rotation.y) - global_position.y, 0)
	if recipe.has("wood") and wood_on() != "":
		# Marks on the wood itself, drawn over it so nothing hides them.
		_marker.visible = true
		_marker.material_override = _marker_on_top()
		_marker.global_position = _wood_mark(k, n)
		_marker_size = 2.5
		if k > 0:
			# Chips of fresh wood scattered where you have been chopping.
			var chips := MeshBuilder.new()
			var at := _work.to_local(Vector3(_marker.global_position.x, global_position.y + _floor(WORK), _marker.global_position.z))
			for i in mini(k * 2, 14):
				var a := _rng.randf() * TAU
				var d := _rng.randf_range(0.1, 0.45)
				chips.box(at + Vector3(cos(a) * d, 0.006, sin(a) * d), Vector3(0.05, 0.01, 0.03), Assets.CUT_WOOD * _rng.randf_range(0.85, 1.05),
						Basis(Vector3.UP, _rng.randf() * TAU), "wood")
			_work.mesh = chips.commit(Assets.materials)
	elif recipe.has("butcher") and carcass:
		# Spots along the body, drawn over it so the carcass never hides them.
		_marker.visible = true
		_marker.material_override = _marker_on_top()
		var top: float = carcass.global_position.y - global_position.y + carcass.def.hit_h + 0.15
		var along := carcass.global_transform.basis.z.normalized()
		var span: float = clampf(carcass.def.radius * 0.5, 0.2, 0.7)
		var f: float = (k + 0.5) / float(n) * 2.0 - 1.0
		_marker.global_position = carcass.global_position + along * span * f
		_marker.position.y = top
		_marker_size = 2.5
	elif recipe.act == "steps":
		_marker.visible = true
		_marker.material_override = null
		_marker_size = 1.0
		_marker.position = _work.transform * _target(recipe.out, k) + Vector3(0, 0.03, 0)


var _on_top: StandardMaterial3D

func _marker_on_top() -> StandardMaterial3D:
	if _on_top == null:
		_on_top = StandardMaterial3D.new()
		_on_top.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_on_top.no_depth_test = true
		_on_top.albedo_color = Color(1.0, 0.78, 0.3)
		_on_top.render_priority = 1
	return _on_top


func _target(out: String, k: int) -> Vector3:
	## Where the marker for step k sits, relative to the workpiece.
	match "dress" if recipe.get("dress", false) else out:
		"stone_axe":
			return Vector3(lerpf(0.19, 0.29, (k + 0.5) / 5.0), 0.03, 0.05)
		"mattock":
			return Vector3(lerpf(0.2, 0.31, (k + 0.5) / 5.0), 0.03, 0.0)
		"wax":
			return Vector3(-0.1 + k * 0.06, 0.03, 0)
		"spear":
			return Vector3(lerpf(-0.04, 0.08, (k + 0.5) / 3.0), 0.026, 0) if k < 3 \
					else Vector3(lerpf(0.62, 0.7, (k - 2.5) / 3.0), 0.026, 0)
		"bow_drill":
			return [Vector3(-0.26, 0.02, 0), Vector3(0.26, 0.02, 0), Vector3(0.0, 0.015, 0.13)][mini(k, 2)]
		"campfire_kit":
			if k < 5:
				return Vector3(0, 0.03 + (k % 2) * 0.03, (k - 2) * 0.035)
			return Vector3(0, 0.1, 0) if k == 5 else Vector3(-0.1, 0.06, 0.16)
		"clay_pot":
			return Vector3(0, 0.19 * k / 5.0 + 0.01, 0.1)
		"bandage":
			return Vector3(-0.2 + k * 0.1, 0.02, 0.12)
		"stick":
			return Vector3(lerpf(-0.3, 0.3, (k + 1.0) / (Items.recipe_steps(recipe) + 1.0)) + 0.015 * k, 0.04, 0.0)
		"dress":
			# Along the body (heights and lengths set for a Hylonomus, fitted
			# to this animal's body), then the guts and the skin.
			var whole: Dictionary = Items.def(recipe.in.keys()[0])
			var animal: String = whole.get("animal", "")
			var fit := Vector3(Assets.prey_body(animal).x / 0.1, Assets.prey_top(animal) / 0.067, 1.0)
			return [Vector3(0.05, 0.07, 0.0), Vector3(-0.05, 0.07, 0.0), Vector3(0.0, 0.05, 0.04), Vector3(-0.15, 0.04, 0.0)][mini(k, 3)] \
					* fit * float(whole.get("body_scale", 1.0))
		"workbench":
			var hx: float = Assets.BENCH_SIZE.x * 0.5 - 0.08
			if k < 4:
				return Vector3(-hx if k % 2 == 0 else hx, 0.5, 0.32 if k < 2 else -0.34)
			if k == 4:
				return Vector3(-hx, 0.72, 0.3)
			return Vector3(0, Assets.BENCH_SIZE.y + 0.02, (k - 6) * 0.265)
		"clay_platter_unfired":
			var a := TAU * k / 5.0
			return Vector3(cos(a) * 0.17, 0.03, sin(a) * 0.17)
		"vessel_open_unfired", "vessel_sealed_unfired":
			if k < 5:
				var a := TAU * k / 5.0 + 0.3
				return Vector3(cos(a) * 0.26, Assets.VESSEL_H * (k + 1) / 5.0, -0.05 + sin(a) * 0.26)
			return Vector3(0.38, 0.05, 0.1)
		"fish_trap":
			if k < 3:
				var x: float = Assets.FISH_TRAP_HOOPS[k * 2]
				return Vector3(x, 0.24 + Assets.fish_trap_r(x), 0.0) * FISH_TRAP_SIZE
			return [Vector3(0.0, 0.48, 0.0), Vector3(-0.2, 0.24, 0.23), Vector3(0.42, 0.24, 0.0)][mini(k - 3, 2)] * FISH_TRAP_SIZE
		"snare":
			return [Vector3(0.4, 0.01, 0.0), Vector3(0.0, 0.035, 0.0), Vector3(0.28, 0.035, 0.0)][mini(k, 2)]
		"baitbox":
			# Saw the board, pin two sides, pin the other two, pack the meat.
			var hw := Assets.BAITBOX_W * 0.5
			return [Vector3(0.0, 0.05, 0.0), Vector3(0.0, Assets.BAITBOX_H, hw), Vector3(hw, Assets.BAITBOX_H, 0.0),
					Vector3(0.0, Assets.BAITBOX_H, 0.0)][mini(k, 3)]
		"compost_basket":
			var hw := Assets.COMPOST_W * 0.5 * 0.45
			if k < 2:
				return Vector3(-hw if k == 0 else hw, Assets.COMPOST_H * 0.45, hw)
			return Vector3(0.0, (0.08 + (k - 2) * 0.15) * 0.45, hw)
		"canteen":
			return [Vector3(0.0, 0.06, 0.2), Vector3(0.0, 0.22, -0.08), Vector3(0.0, 0.12, -0.04), Vector3(0.07, 0.12, -0.04),
					Vector3(0.0, 0.27, -0.08), Vector3(0.1, 0.3, -0.08)][mini(k, 5)]
		"flask":
			return [Vector3(0.12, 0.03, 0.12), Vector3(-0.12, 0.03, 0.12), Vector3(-0.1, 0.04, -0.05), Vector3(0.1, 0.04, -0.05),
					Vector3(0.0, 0.18, -0.05), Vector3(0.0, 0.19, -0.05), Vector3(0.05, 0.1, -0.02), Vector3(0.0, 0.22, -0.05)][mini(k, 7)]
		"soup_pot_unfired":
			if k < 5:
				var a := TAU * k / 5.0 + 0.3
				return Vector3(cos(a) * 0.2, 0.36 * (k + 1) / 5.0, -0.05 + sin(a) * 0.2)
			return Vector3(-0.5 + (k - 5) * 0.5, 0.06, 0.29)
		"clay_bowl_unfired":
			var a := TAU * k / 4.0 + 0.4
			return Vector3(cos(a) * 0.125, 0.08 * (k + 1) / 4.0, sin(a) * 0.125)
		"spindle_whorl_unfired":
			return [Vector3(0, 0.06, 0), Vector3(0, 0.03, 0), Vector3(0, 0.025, 0)][mini(k, 2)]
		"rod_blank":
			return [Vector3(-0.15, 0.03, 0.02), Vector3(0.2, 0.03, -0.02), Vector3(-0.3, 0.03, 0), Vector3(0.45, 0.03, 0)][mini(k, 3)]
		"fishing_rod":
			if recipe.get("bait", false) is String:
				return Vector3(-0.32, 0.03, 0.06)  # the hook
			return [Vector3(0.6, 0.03, 0), Vector3(0.1, 0.03, 0.01), Vector3(-0.3, 0.03, 0.03)][mini(k, 2)]
		"meat_bait":
			return Vector3(0, 0.07, 0)
		"spindle":
			return [Vector3(0.0, 0.03, 0), Vector3(0.05, 0.03, 0.12)][mini(k, 1)]
		"woodworking_tools":
			return [Vector3(-0.05, 0.02, -0.09), Vector3(0.1, 0.02, -0.09), Vector3(0.03, 0.02, 0.07),
					Vector3(0.125, 0.02, 0.07), Vector3(-0.11, 0.03, -0.06), Vector3(-0.07, 0.03, 0.07)][mini(k, 5)]
		"paper_wet":
			if k < 3:
				return Vector3(0.2, 0.08, 0.02) + [Vector3(0.03, 0, 0), Vector3(-0.03, 0, 0.03), Vector3(0, 0, -0.03)][k]
			return Vector3(-0.18, 0.04, 0)
		"pencil_core_unfired":
			return [Vector3(0, 0.05, 0), Vector3(0, 0.07, 0), Vector3(0.05, 0.03, 0)][mini(k, 2)]
		"ash_pencil":
			return [Vector3(0, 0.03, 0), Vector3(0, 0.03, 0.08), Vector3(0, 0.03, 0.03), Vector3(-0.07, 0.03, 0)][mini(k, 3)]
		"chart_map":
			if k == 0:
				return Vector3(0.15, 0.02, 0)
			return Assets.on_sheet(BLUEPRINT_AT, [Vector2(0.0, -0.14), Vector2(0.0, 0.14), Vector2(0.14, 0.08)][mini(k - 1, 2)]) + Vector3(0, 0.005, 0)
		"blueprint_softwood_house":
			if k in recipe.get("sharpen", []):
				return Vector3(0.15, 0.02, 0)
			var g: int = k - recipe.get("sharpen", []).filter(func(s): return s < k).size()
			var seg: Array = Assets.blueprint_lines(g)[0]
			return Assets.on_sheet(BLUEPRINT_AT, (seg[0] + seg[1]) * 0.5) + Vector3(0, 0.005, 0)
		"papermaking_tools":
			if k < 4:
				return Vector3(-0.1, 0.03, 0) + [Vector3(-0.17, 0, -0.17), Vector3(0.17, 0, -0.17), Vector3(0.17, 0, 0.17), Vector3(-0.17, 0, 0.17)][k]
			return Vector3(-0.1, 0.03, (k - 4.5) * 0.12)
		"fiber_sack", "cloth_sack", "bedroll":
			return Vector3(-0.19, 0.02, -0.16 + k * 0.045)
		"pot_sealed":
			return [Vector3(0.0, 0.23, 0.0), Vector3(0.086, 0.19, 0.0), Vector3(-0.086, 0.19, 0.0)][mini(k, 2)]
		"keycard_jr":
			return Vector3(-0.13, 0.004 * (Items.recipe_steps(recipe) - k), 0)
		"beam_segment":
			return Vector3(-0.15 + k * 0.3, 0.12, 0)
		"injector":
			return [Vector3(-0.1, 0.05, -0.05), Vector3(-0.1, 0.2, -0.05), Vector3(0.12, 0.06, -0.05)][mini(k, 2)]
		"smashed_native_copper", "stone_grit", "crushed_copper_ore":
			# On top of the lump, which shrinks as it is beaten.
			return Vector3(0, 0.08 * (1.0 - k / float(Items.recipe_steps(recipe)) * 0.7) * 1.6, 0)
	return Vector3(0, 0.05, 0)


func _wraps(b, from: Vector3, to: Vector3, r: float, done: int, total: int) -> void:
	## The first `done` of `total` turns of cord around a shaft.
	for i in done:
		var c := from.lerp(to, (i + 0.5) / total)
		var axis := (to - from).normalized() * 0.006
		b.cylinder(c - axis, c + axis, r, r, 6, Assets.CORD * (0.9 + 0.1 * (i % 2)), Color(-1, 0, 0), "fiber", false)


func _outline(b, pattern: Array, y: float) -> void:
	## The shape to leave, traced in amber on the stone.
	var c := KNAP_CELL
	var nb := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for k in 25:
		if not pattern[k]:
			continue
		var x := k % 5
		var z := k / 5
		for i in 4:
			var ox: int = x + nb[i].x
			var oz: int = z + nb[i].y
			if ox >= 0 and ox < 5 and oz >= 0 and oz < 5 and pattern[oz * 5 + ox]:
				continue
			var mid := Vector3((x - 2 + nb[i].x * 0.5) * c, y, (z - 2 + nb[i].y * 0.5) * c)
			var size := Vector3(c + 0.004, 0.004, 0.004) if nb[i].y != 0 else Vector3(0.004, 0.004, c + 0.004)
			b.box(mid, size, Color(1.0, 0.75, 0.25), Basis(), "glow")


func _flake(k: int) -> void:
	## A chip of stone flying off the struck cell.
	var chip := MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.tri(Vector3(-0.02, 0, -0.015), Vector3(0.02, 0, -0.01), Vector3(0, 0.004, 0.02), Assets.CHERT, "stone")
	mb.tri(Vector3(0, 0.004, 0.02), Vector3(0.02, 0, -0.01), Vector3(-0.02, 0, -0.015), Assets.CHERT * 0.8, "stone")
	chip.mesh = mb.commit(Assets.materials)
	add_child(chip)
	var from := to_local(cell_center(k))
	chip.position = from
	var out := Vector3(from.x - WORK.x, 0, from.z - WORK.z)
	out = out.normalized() if out.length() > 0.01 else Vector3(_rng.randf_range(-1, 1), 0, -1).normalized()
	var tw := chip.create_tween()
	tw.set_parallel(true)
	tw.tween_property(chip, "position", from + out * 0.25 + Vector3(0, -0.06, 0), 0.35)
	tw.tween_property(chip, "rotation", Vector3(_rng.randf() * 6.0, _rng.randf() * 6.0, 0), 0.35)
	tw.chain().tween_callback(chip.queue_free).set_delay(1.5)
