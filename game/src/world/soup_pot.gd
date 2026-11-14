extends StaticBody3D
## A soup pot (group "soup_pots"): a big clay pot hanging from a tripod of
## boards. It is too big for the bag: E or C picks it up to carry in your arms
## like a log (player.start_haul), and it keeps what is in it. Put down close
## to a campfire, it hangs over the middle of the fire instead of taking one of
## the cooking spots round its edge, one pot to a fire.
##
## It is made unfired at a workbench with the clay platter on its rack, and
## fired by hanging it over a lit fire for FIRE_TIME.
##
## What it holds:
## - Water: carried to the water and filled (E while carrying it and looking
##   at the water), it holds SERVINGS servings of swamp water. Boiled, the
##   water is clean. A clay pot (E while holding one) scoops out a pot of it.
## - Soup: food added to clean water (E while holding the food) makes soup.
##   The soup holds the sum of the energy, protein, greens and starch of
##   everything put in, each counted as its cooked form, shared out over the
##   servings. Every food item tops the liquid up by SERVINGS / MAX_FOOD
##   servings, so MAX_FOOD items always make a full pot; eating a serving takes
##   its share of the food out too. Food added has to be boiled again before
##   the soup is safe (`raw`). Soup keeps for LIFE after it last boiled.
## - E with empty hands eats a serving (or drinks the water) straight from the
##   pot; with a clay pot it scoops one serving out as a Pot of Soup.
## Filling it at the water throws out whatever was in it. Soup with meat in it
## leaves blood in the water, and that draws the amphibians lurking nearby
## (swamp.blood_in_water).
##
## Local space: the tripod stands on the ground at the origin, the pot hangs
## under its top with its bottom HANG_Y above the ground (over a fire's flames).

const SERVINGS := 16.0
const MAX_FOOD := 12.0
const PER_FOOD := SERVINGS / MAX_FOOD   # servings of liquid each food item adds
const LIFE := 36.0 * 60.0               # soup keeps 36 game hours after it last boiled
const HEAT_TIME := 60.0                 # seconds over a lit fire to come to the boil from cold
const COOL_TIME := 180.0                # seconds off the fire to go cold from the boil
const RAW_HEAT := 0.75                  # adding food knocks it off the boil to this
const FIRE_TIME := 200.0                # seconds over a lit fire to fire the clay
const HANG_R := 1.5                     # put down this close to a campfire, it hangs over it
const SOUP_WATER := 30.0                # water in a serving of soup
const CLEAN_WATER := 40.0               # a serving of boiled water (a pot of boiled water)
const DIRTY_WATER := 35.0
const DIRTY_SICK := 0.35
const SPOILED_SICK := 0.9
const NUTRIENTS := ["energy", "protein", "greens", "starch"]
## What a held container becomes with one more serving of each kind of
## contents (see contents()): a clay pot holds one serving, a canteen two of
## the same kind.
const SCOOPS := {
	"pot": {"dirty": "pot_dirty", "clean": "pot_clean", "soup": "pot_soup", "spoiled": "pot_soup_spoiled"},
	"canteen": {"dirty": "canteen_dirty_1", "clean": "canteen_clean_1", "soup": "canteen_soup_1", "spoiled": "canteen_soup_spoiled_1"},
	"canteen_dirty_1": {"dirty": "canteen_dirty_2"},
	"canteen_clean_1": {"clean": "canteen_clean_2"},
	"canteen_soup_1": {"soup": "canteen_soup_2", "spoiled": "canteen_soup_spoiled_2"},
	"canteen_soup_spoiled_1": {"soup": "canteen_soup_spoiled_2", "spoiled": "canteen_soup_spoiled_2"},
	"flask": {"dirty": "flask_dirty_1", "clean": "flask_clean_1", "soup": "flask_soup_1", "spoiled": "flask_soup_spoiled_1"},
	"flask_dirty_1": {"dirty": "flask_dirty_2"},
	"flask_clean_1": {"clean": "flask_clean_2"},
	"flask_soup_1": {"soup": "flask_soup_2", "spoiled": "flask_soup_spoiled_2"},
	"flask_soup_spoiled_1": {"soup": "flask_soup_spoiled_2", "spoiled": "flask_soup_spoiled_2"},
	"flask_dirty_2": {"dirty": "flask_dirty_3"},
	"flask_clean_2": {"clean": "flask_clean_3"},
	"flask_soup_2": {"soup": "flask_soup_3", "spoiled": "flask_soup_spoiled_3"},
	"flask_soup_spoiled_2": {"soup": "flask_soup_spoiled_3", "spoiled": "flask_soup_spoiled_3"},
	"flask_dirty_3": {"dirty": "flask_dirty_4"},
	"flask_clean_3": {"clean": "flask_clean_4"},
	"flask_soup_3": {"soup": "flask_soup_4", "spoiled": "flask_soup_spoiled_4"},
	"flask_soup_spoiled_3": {"soup": "flask_soup_spoiled_4", "spoiled": "flask_soup_spoiled_4"},
}
const SCALE := 2.8                      # the pot is Assets.pot this many times bigger
const HANG_Y := 0.6
const RADIUS := 0.115 * SCALE
const HEIGHT := 0.19 * SCALE

var item_id := "soup_pot"
var water := 0.0           # servings of liquid in it (up to SERVINGS)
var dirty := false         # swamp water, not yet boiled
var food := 0.0            # how many food items' worth are in it (up to MAX_FOOD)
var nut := {}              # NUTRIENTS -> total in the pot
var risk := 0.0            # chance a serving makes you sick until it boils (raw food)
var raw := false           # food added since it last boiled
var heat := 0.0            # 0 cold, 1 boiling
var fresh_at := 0.0        # Game.time the soup last boiled (or was started)
var fired := 0.0           # unfired: seconds over a lit fire so far
var fire: Node3D = null    # the campfire it hangs over
var hauled_by: Node3D = null
var world: Node = null

var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _liquid: MeshInstance3D
var _liquid_mat: StandardMaterial3D
var _steam: CPUParticles3D
var _shown := ""
var _was_boiling := false
var _on_hearth := false    # hung in a house's fireplace: no tripod
var _rng := RandomNumberGenerator.new()


func setup(id: String, w: Node) -> Node3D:
	item_id = id
	world = w
	return self


func _init() -> void:
	for k in NUTRIENTS:
		nut[k] = 0.0


func _ready() -> void:
	add_to_group("soup_pots")
	add_to_group("fire_pots")  # one pot or vessel to a fire
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS + 0.03
	cyl.height = HEIGHT + 0.05
	_shape.shape = cyl
	_shape.position.y = HANG_Y + HEIGHT * 0.5
	add_child(_shape)
	_mesh = MeshInstance3D.new()
	_mesh.visibility_range_end = 90.0
	add_child(_mesh)
	_liquid = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	disc.radial_segments = 12
	disc.rings = 1
	_liquid_mat = StandardMaterial3D.new()
	_liquid_mat.roughness = 0.15
	disc.material = _liquid_mat
	_liquid.mesh = disc
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_liquid.visibility_range_end = 60.0
	add_child(_liquid)
	_steam = CPUParticles3D.new()
	_steam.amount = 14
	_steam.lifetime = 2.2
	_steam.emitting = false
	_steam.local_coords = false
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = RADIUS * 0.6
	_steam.direction = Vector3.UP
	_steam.spread = 12.0
	_steam.gravity = Vector3(0, 0.25, 0)
	_steam.initial_velocity_min = 0.25
	_steam.initial_velocity_max = 0.5
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.4
	var puff := SphereMesh.new()
	puff.radius = 0.06
	puff.height = 0.1
	puff.radial_segments = 6
	puff.rings = 3
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = Color(0.92, 0.94, 0.95, 0.18)
	puff.material = pm
	_steam.mesh = puff
	_steam.position.y = HANG_Y + HEIGHT
	add_child(_steam)
	_was_boiling = boiling()
	_rebuild()


func fired_pot() -> bool:
	return item_id == "soup_pot" or item_id == COPPER_ID


# A copper soup pot (late game, raised on the anvil, never fired) holds a
# quarter more (servings and food alike, so a serving is as rich), comes to
# the boil in two thirds the time (50% faster), and its soup keeps a fifth
# longer after it last boiled. The clay pot's numbers are the constants.
const COPPER_ID := "soup_pot_copper"
const COPPER_SIZE := 1.25
const COPPER_HEAT := 1.5
const COPPER_LIFE := 1.2


func copper() -> bool:
	return item_id == COPPER_ID


func capacity() -> float:
	return SERVINGS * (COPPER_SIZE if copper() else 1.0)


func max_food() -> float:
	return MAX_FOOD * (COPPER_SIZE if copper() else 1.0)


func life() -> float:
	return LIFE * (COPPER_LIFE if copper() else 1.0)


func heat_time() -> float:
	return HEAT_TIME / (COPPER_HEAT if copper() else 1.0)


func set_id(id: String) -> void:
	item_id = id
	_rebuild()


func name_lower() -> String:
	return Items.item_name(item_id).to_lower()


# --- State --------------------------------------------------------------------------

func is_empty() -> bool:
	return water <= 0.001


func has_soup() -> bool:
	return food > 0.001 and not is_empty()


func boiling() -> bool:
	return heat >= 1.0 and not is_empty()


func spoiled() -> bool:
	return has_soup() and Game.time - fresh_at > life()


func safe() -> bool:
	## Boiled since anything raw went in (or the water was drawn).
	return not dirty and not raw


func servings() -> int:
	## Servings left, to the nearest one (at least one while anything is left).
	return maxi(roundi(water), 1) if not is_empty() else 0


func has_meat() -> bool:
	return has_soup() and nut.protein > 0.01


func per_serving(key: String) -> float:
	return nut.get(key, 0.0) / water if not is_empty() else 0.0


func hung() -> bool:
	return fire != null and is_instance_valid(fire) and not fire.is_queued_for_deletion()


func _over_lit_fire() -> bool:
	return hauled_by == null and hung() and fire.lit


func empty_out() -> void:
	water = 0.0
	dirty = false
	food = 0.0
	for k in NUTRIENTS:
		nut[k] = 0.0
	risk = 0.0
	raw = false


func fill_dirty() -> void:
	## Drawn full of swamp water: whatever was in it is gone.
	empty_out()
	water = capacity()
	dirty = true
	heat = 0.0
	fresh_at = Game.time
	_refresh()


static func food_values(id: String) -> Dictionary:
	## What a food adds to soup: its cooked form's energy, protein, greens and
	## starch (anything that cooks into food is boiled in the pot).
	var def := Items.def(id)
	var cooked := Items.def(def.get("cook", ""))
	var src: Dictionary = cooked if cooked.has("energy") else def
	var out := {}
	for k in NUTRIENTS:
		out[k] = float(src.get(k, 0.0))
	return out


static func accepts(id: String) -> bool:
	## Any food can go in the soup, but nothing that comes in a container:
	## not water or soup in a pot, canteen or flask (`empty`), nor a canteen
	## or flask of alcohol (`measures`), which would go in whole.
	var def := Items.def(id)
	return id != "" and Items.is_food(id) and not def.has("empty") and not def.has("measures")


func add_food(id: String) -> String:
	## Puts one `id` in the soup. Returns why it can't go in, or "".
	if not fired_pot():
		return "Fire the pot before you cook in it."
	if is_empty():
		return "Fill the pot with water and boil it first."
	if not has_soup() and dirty:
		return "Boil the water first. Soup needs clean water to start."
	if spoiled():
		return "The soup has gone off. Fill the pot at the water to tip it out."
	if food > max_food() - 0.001:
		return "The soup pot is full."
	if not has_soup():
		fresh_at = Game.time   # a new soup
	var v := food_values(id)
	for k in NUTRIENTS:
		nut[k] += v[k]
	food = minf(food + 1.0, max_food())
	water = minf(water + PER_FOOD, capacity())
	risk = maxf(risk, float(Items.def(id).get("sick", 0.0)))
	raw = true
	heat = minf(heat, RAW_HEAT)
	_refresh()
	return ""


func take_serving() -> Dictionary:
	## Ladles one serving out of the pot: what eating it does (energy, protein,
	## greens, starch, water, sick), or {} if the pot is empty.
	if is_empty():
		return {}
	var part := minf(1.0, water)
	var s := {}
	if has_soup():
		var k := part / water
		var off := spoiled()
		for key in NUTRIENTS:
			var amount: float = nut[key] * k
			nut[key] -= amount
			s[key] = amount * (0.5 if off else 1.0)
		food -= food * k
		s.water = SOUP_WATER * part
		s.sick = SPOILED_SICK if off else (risk if raw else 0.0)
	else:
		s.water = (DIRTY_WATER if dirty else CLEAN_WATER) * part
		s.sick = DIRTY_SICK if dirty else 0.0
	water -= part
	if is_empty():
		empty_out()
	_refresh()
	return s


func contents() -> String:
	## What a serving of it is: "dirty" or "clean" water, "soup", "spoiled"
	## soup, or "" when it is empty.
	if is_empty():
		return ""
	if not has_soup():
		return "dirty" if dirty else "clean"
	return "spoiled" if spoiled() else "soup"


static func scoop_into(held: String, kind: String) -> String:
	## What the held container becomes with a serving of `kind` scooped into
	## it, or "" if it can't take it.
	return SCOOPS.get(held, {}).get(kind, "")


func scoop() -> Dictionary:
	## Ladles one serving out to put in a container: {kind, age, data}, with
	## soup's serving as `data` and its age since it last boiled.
	var kind := contents()
	if kind == "":
		return {}
	# Its age as a clay pot's soup would be, as far through its life: what a
	# canteen's or flask's soup counts its keeping from.
	var age := clampf((Game.time - fresh_at) * LIFE / life(), 0.0, LIFE) if kind == "soup" else 0.0
	var s := take_serving()
	return {"kind": kind, "age": age, "data": s if kind == "soup" else {}}


static func mix(a: Dictionary, b: Dictionary, had := 1) -> Dictionary:
	## Soup `b` scooped onto `had` servings of soup `a` in a canteen or flask:
	## each serving is now their average, weighted by how many there were.
	var out := {}
	for k in a.keys() + b.keys():
		out[k] = (float(a.get(k, 0.0)) * had + float(b.get(k, 0.0))) / (had + 1.0)
	return out


static func servings_in(id: String) -> int:
	## How many servings a canteen or flask holds now: its "_1".."_4" suffix.
	var n := id.substr(id.rfind("_") + 1)
	return int(n) if n.is_valid_int() else 0


# --- Heat ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if fire != null and not hung():
		fire = null
	var on_hearth: bool = hung() and hauled_by == null and fire.hearth
	if on_hearth != _on_hearth:
		_on_hearth = on_hearth
		if on_hearth:
			global_rotation.y = fire.global_rotation.y  # the stick runs across the hood
		_rebuild()
	var lit_s := delta if _over_lit_fire() else 0.0
	advance(delta, lit_s)
	_steam.emitting = boiling() and hauled_by == null
	if boiling() != _was_boiling:
		_was_boiling = boiling()
		if _was_boiling and _near_player():
			Game.notify("The soup pot is boiling." if has_soup() else "The water in the soup pot is boiling.")
		_refresh()


func advance(dt: float, lit_s: float) -> void:
	## Passes dt seconds, the first lit_s of them over a lit fire (sleeping
	## passes them in one go).
	lit_s = clampf(lit_s, 0.0, dt)
	if not fired_pot():
		if lit_s > 0.0:
			fired += lit_s
			if fired >= FIRE_TIME:
				set_id("soup_pot")
				if _near_player():
					Game.notify("The soup pot is fired. Fill it at the water.")
		return
	var off := spoiled()
	if lit_s > 0.0:
		var to_boil := (1.0 - heat) * heat_time()
		heat = minf(heat + lit_s / heat_time(), 1.0)
		if heat >= 1.0 and not is_empty() and lit_s >= to_boil:
			if dirty or raw:
				dirty = false
				raw = false
				risk = 0.0
				_refresh()
			if not off:
				# Boiling until the fire stopped (or until now).
				fresh_at = maxf(fresh_at, Game.time - (dt - lit_s))
	if dt > lit_s:
		heat = maxf(heat - (dt - lit_s) / COOL_TIME, 0.0)


func _near_player() -> bool:
	var p: Node3D = Game.player
	return p != null and is_instance_valid(p) and p.global_position.distance_to(global_position) < 25.0


# --- Looks ------------------------------------------------------------------------------

func _rebuild() -> void:
	if _mesh == null:
		return
	_mesh.mesh = Assets.hearth_pot(item_id) if _on_hearth else Assets.mesh("item_" + item_id)
	_refresh()


func liquid_color() -> Color:
	if dirty:
		return Items.def("pot_dirty").color
	if not has_soup():
		return Items.def("pot_clean").color
	if spoiled():
		return Items.def("pot_soup_spoiled").color
	# Browner with meat, greener with greens, paler with starch.
	var total := maxf(nut.protein + nut.greens + nut.starch, 0.001)
	var c := Color(0.62, 0.45, 0.22)
	c = c.lerp(Color(0.52, 0.30, 0.18), nut.protein / total * 0.6)
	c = c.lerp(Color(0.38, 0.52, 0.22), nut.greens / total * 0.6)
	c = c.lerp(Color(0.80, 0.70, 0.45), nut.starch / total * 0.6)
	return c


func _refresh() -> void:
	## The liquid's level and colour.
	if _liquid == null:
		return
	_liquid.visible = not is_empty()
	if is_empty():
		return
	# Up the inside of the pot's profile (see Assets.pot), from a little in
	# the bottom to just under the shoulder.
	var f := clampf(water / capacity(), 0.0, 1.0)
	var y := lerpf(0.03, 0.135, f)
	var inner := [Vector2(0.05, 0.015), Vector2(0.088, 0.035), Vector2(0.103, 0.08), Vector2(0.09, 0.14)]
	var r: float = inner[0].x
	for i in inner.size() - 1:
		if y >= inner[i].y and y <= inner[i + 1].y:
			r = lerpf(inner[i].x, inner[i + 1].x, (y - inner[i].y) / (inner[i + 1].y - inner[i].y))
	_liquid.position = Vector3(0, HANG_Y + y * SCALE, 0)
	_liquid.scale = Vector3(r * SCALE, 1.0, r * SCALE)
	_liquid_mat.albedo_color = liquid_color()


# --- Carrying (see player.start_haul) ---------------------------------------------

func can_haul() -> bool:
	return true


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return name_lower()


func haul_radius() -> float:
	## Held out at arm's length, so it doesn't fill your view.
	return 0.9


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	## Lifted just off its feet.
	return 0.15


func set_hauled(by: Node3D) -> void:
	## Picked up (or put down, by = null). Put down by a campfire with no pot
	## over it yet, it hangs over the middle of the fire.
	hauled_by = by
	_shape.disabled = by != null
	if by != null:
		fire = null
		return
	rotation = Vector3(0, rotation.y, 0)
	var f := fire_near(global_position)
	if f:
		fire = f
		global_position = f.global_position
		Game.notify("You hang the %s over the fire." % name_lower())
		return
	var g: float = world.floor_height(global_position) if world else -INF
	global_position.y = g if g > -INF else global_position.y - haul_lift()


func fire_near(pos: Vector3) -> Node3D:
	## A campfire within HANG_R of pos with nothing hanging over it yet.
	var best: Node3D = null
	var best_d := HANG_R
	for f in Game.fires:
		if not is_instance_valid(f) or f.is_queued_for_deletion():
			continue
		var d := Vector2(f.global_position.x - pos.x, f.global_position.z - pos.z).length()
		if d < best_d and pot_over(f) == null:
			best = f
			best_d = d
	return best


func pot_over(f: Node3D) -> Node3D:
	## The soup pot or fermentation vessel on campfire f, other than this one.
	for p in get_tree().get_nodes_in_group("fire_pots"):
		if p != self and p.fire == f and not p.is_queued_for_deletion():
			return p
	return null


func haul_prompt(player: Node) -> String:
	## While you carry it: hang it over a fire, set it down, or fill it.
	if player.focus_water and fired_pot():
		if is_empty() or (not has_soup() and dirty):
			return "Fill the soup pot with swamp water [E]   Put it down [Q]"
		return "Tip it out and refill the soup pot with swamp water [E]   Put it down [Q]"
	if fire_near(_drop_point(player)):
		return "Hang the %s over the fire [E]" % name_lower()
	return "Put down the %s [E]" % name_lower()


func haul_interact(player: Node) -> bool:
	## E while carrying it: true if it did something (filled it), false to
	## put it down as usual.
	if not player.focus_water:
		return false
	if not fired_pot():
		Game.notify("The clay would soften. Fire the pot over a campfire first.")
		return true
	var bloody := has_meat()
	var had := has_soup()
	fill_dirty()
	Sfx.play("splash", -4.0)
	Game.notify("You tip out the soup and fill the pot with swamp water." if had else "You fill the soup pot with swamp water.")
	if bloody and world and world.has_method("blood_in_water"):
		world.blood_in_water(player.water_point(), player)
	return true


func _drop_point(player: Node3D) -> Vector3:
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	return player.global_position + fwd.normalized() * (haul_radius() + 0.55)


# --- Interaction ---------------------------------------------------------------------

static func _for_fire(id: String) -> bool:
	## Held items that are for the fire under the pot, not the pot.
	var def := Items.def(id)
	return id in ["torch", "torch_lit"] or "dig" in def.get("tags", []) or (def.has("fuel") and not accepts(id))


func status() -> String:
	if not fired_pot():
		return "unfired"
	if is_empty():
		return "empty"
	if spoiled():
		return "spoiled"
	if boiling():
		return "boiling"
	if not safe():
		return "needs boiling"
	return "hot" if heat > 0.5 else "cold"


func tooltip(_player: Node) -> String:
	## The panel shown while you look at it: what it holds, per serving.
	if hauled_by:
		return ""
	if not fired_pot():
		var pct := roundi(fired / FIRE_TIME * 100.0)
		return "Unfired Soup Pot\nHang it over a lit campfire to fire it" + ("  (%d%% fired)" % pct if pct > 0 else "")
	if is_empty():
		return Items.item_name(item_id) + ": " + "empty\nFill it at the water, then boil it"
	var n := servings()
	if not has_soup():
		return Items.item_name(item_id) + ": " + "%s water (%s)\n%d serving%s of water" % ["swamp" if dirty else "boiled", status(),
				n, "" if n == 1 else "s"]
	return Items.item_name(item_id) + ": " + "soup (%s)\nPer serving: Meat %d%%   Starch %d%%   Greens %d%%\n%d serving%s left" % [status(),
			roundi(per_serving("protein")), roundi(per_serving("starch")), roundi(per_serving("greens")),
			n, "" if n == 1 else "s"]


func prompt(player: Node) -> String:
	if hauled_by:
		return ""
	var held: String = Game.inventory.held_id()
	if hung() and _for_fire(held):
		return fire.prompt(player)
	if not fired_pot():
		return "Pick up the unfired soup pot [E]"
	var carry := "   Carry it [C]"
	if SCOOPS.has(held) and not is_empty():
		var what := Items.item_name(held).to_lower()
		if scoop_into(held, contents()) == "":
			return "The %s holds something else" % what + carry
		return ("Scoop a serving into the %s [E]" if has_soup() else "Fill the %s [E]") % what + carry
	if accepts(held):
		var why := _add_blocker()
		if why != "":
			return why + carry
		return "Add %s to the soup [E]" % Items.item_name(held) + carry
	if is_empty():
		return "Pick up the soup pot [E]"
	if has_soup():
		return "Eat a serving of soup [E]" + carry
	return ("Drink swamp water from the pot [E]" if dirty else "Drink boiled water from the pot [E]") + carry


func _add_blocker() -> String:
	## Why the held food can't go in right now (short), or "".
	if is_empty():
		return "Fill it with water and boil it first"
	if not has_soup() and dirty:
		return "Boil the water first"
	if spoiled():
		return "The soup has gone off"
	if food > max_food() - 0.001:
		return "The soup pot is full"
	return ""


func interact(player: Node) -> void:
	if hauled_by:
		return
	var inv = Game.inventory
	var held: String = inv.held_id()
	if hung() and _for_fire(held):
		fire.interact(player)
		return
	if not fired_pot() or (is_empty() and not accepts(held)):
		player.start_haul(self)
		return
	if SCOOPS.has(held):
		var into := scoop_into(held, contents())
		if into == "":
			Game.notify("The %s holds something else." % Items.item_name(held).to_lower())
			return
		var slot: Dictionary = inv.slots[inv.selected]
		var got := scoop()
		var data: Dictionary = got.data
		var age: float = got.age
		if not Items.def(into).has("decay"):
			data = {}  # water, or soup gone off
		elif slot.has("data"):
			# Another serving into a canteen or flask of soup: they mix.
			data = mix(slot.data, data, maxi(servings_in(held), 1))
			age = maxf(age, float(slot.age))
		inv.replace(inv.selected, into, age, data)
		Sfx.play("splash", -10.0, 0.2)
		Game.picked.emit(into)
		return
	if accepts(held):
		var why := add_food(held)
		if why != "":
			Game.notify(why)
			return
		inv.take(inv.selected, 1)
		Sfx.play("splash", -12.0, 0.3)
		Game.crafted.emit("soup_" + held)
		return
	if not player.vitals_enabled:
		return
	var had_soup := has_soup()
	var s := take_serving()
	if s.is_empty():
		return
	player.vitals.consume(s, _rng)
	Sfx.play("eat" if had_soup else "drink", -4.0)
	Game.crafted.emit("ate_soup" if had_soup else "drank_soup_pot")


func craft_interact(player: Node) -> void:
	## C: pick it up to carry.
	player.start_haul(self)


# --- Saving ------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := global_position
	return {"id": item_id, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "water": water, "dirty": dirty,
			"food": food, "nut": nut.duplicate(), "risk": risk, "raw": raw, "heat": heat,
			"fresh_at": fresh_at, "fired": fired, "hung": hung()}


func from_dict(d: Dictionary) -> void:
	item_id = String(d.get("id", item_id))
	rotation.y = float(d.get("yaw", 0.0))
	water = clampf(float(d.get("water", 0.0)), 0.0, capacity())
	dirty = bool(d.get("dirty", false))
	food = clampf(float(d.get("food", 0.0)), 0.0, max_food())
	var src: Dictionary = d.get("nut", {})
	for k in NUTRIENTS:
		nut[k] = float(src.get(k, 0.0))
	risk = float(d.get("risk", 0.0))
	raw = bool(d.get("raw", false))
	heat = float(d.get("heat", 0.0))
	fresh_at = float(d.get("fresh_at", 0.0))
	fired = float(d.get("fired", 0.0))
	_was_boiling = boiling()
	if is_inside_tree():
		_rebuild()
