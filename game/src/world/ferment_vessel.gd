extends StaticBody3D
## A fermentation vessel (group "vessels"): a big clay crock, made at a
## workbench with the clay platter on its rack. Like the soup pot it is too
## big for the bag: carried in your arms (E or C), keeping what is in it, and
## put down by a campfire it sits in the middle of the fire (one pot or
## vessel to a fire), which fires it the first time and boils it after.
##
## Two kinds:
## - Unsealed ("vessel_open"): lacto fermentation. Food in clean water is
##   pickled after FERMENT_TIME.
## - Sealed ("vessel_sealed"): alcoholic fermentation, or salting once it has
##   salt in it. Brewing, food in clean water is preserved in alcohol after
##   FERMENT_TIME, and from then on a canteen draws alcohol from it. Salting,
##   food is salted the moment it goes in, while there is as much water and
##   as much salt as food.
##
## Up to CAP each of food, water (servings) and salt. More food than water
## (or, salting, than salt), or (pickling and brewing) any raw meat, or more
## than MEAT_SHARE of it uncured meat (meat already pickled or preserved
## doesn't count), and the mix goes rancid: everything in it rots, and nothing more
## goes in until it is washed out by filling it at the water. Washing out
## meat puts blood in the water, as with the soup pot.
##
## Water goes in poured from a pot or canteen (E while holding it), or the
## vessel is filled with swamp water at the water's edge (E while carrying it)
## and boiled in a fire. Food goes in only once the water is clean and has
## cooled. E with food, salt, water or a canteen adds or draws; right-click
## (or E with empty hands) opens it to see and take out what is inside.
## Nothing in a vessel spoils.

const SoupPot := preload("res://src/world/soup_pot.gd")

const CAP := 10
const FERMENT_TIME := 24.0 * 60.0   # a game day
const MEAT_SHARE := 0.3
const HEAT_TIME := 60.0
const COOL_TIME := 180.0
const COOL := 0.3                   # heat under this is cool enough for food
const FIRE_TIME := 150.0            # seconds in a lit fire to fire the clay
const HANG_R := 1.5                 # put down this close to a campfire, it sits in it
const DRAW := 10                    # measures of alcohol a canteen draws for one serving of water
const LIQUID_Y := [0.06, 0.52]      # liquid level in the body, empty to full

var item_id := "vessel_open"
var water := 0                      # servings of water
var dirty := false                  # swamp water, not yet boiled
var salt := 0
var items: Array = []               # [{id, t (seconds fermenting), age}]
var rancid := false
var brew_t := 0.0                   # brewing: seconds the brew has fermented
var heat := 0.0
var fired := 0.0
var fire: Node3D = null
var hauled_by: Node3D = null
var world: Node = null

var _shape: CollisionShape3D
var _mesh: MeshInstance3D
var _liquid: MeshInstance3D
var _liquid_mat: StandardMaterial3D
var _steam: CPUParticles3D
var _was_boiling := false


func setup(id: String, w: Node) -> Node3D:
	item_id = id
	world = w
	return self


func _ready() -> void:
	add_to_group("vessels")
	add_to_group("fire_pots")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.32
	cyl.height = Assets.VESSEL_H + 0.08
	_shape.shape = cyl
	_shape.position.y = cyl.height * 0.5
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
	_liquid_mat.roughness = 0.2
	disc.material = _liquid_mat
	_liquid.mesh = disc
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_liquid)
	_steam = CPUParticles3D.new()
	_steam.amount = 10
	_steam.lifetime = 2.0
	_steam.emitting = false
	_steam.local_coords = false
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = 0.12
	_steam.direction = Vector3.UP
	_steam.spread = 12.0
	_steam.gravity = Vector3(0, 0.25, 0)
	_steam.initial_velocity_min = 0.25
	_steam.initial_velocity_max = 0.5
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
	_steam.position.y = Assets.VESSEL_H + 0.05
	add_child(_steam)
	_rebuild()


# --- State --------------------------------------------------------------------------

func sealed() -> bool:
	return item_id.begins_with("vessel_sealed")


func fired_pot() -> bool:
	return not item_id.ends_with("_unfired")


func mode() -> String:
	## "lacto" (unsealed: pickling), "salt" (sealed, salted), "alcohol" (sealed).
	if not sealed():
		return "lacto"
	return "salt" if salt > 0 else "alcohol"


func is_empty() -> bool:
	return water == 0 and salt == 0 and items.is_empty() and not rancid


func boiling() -> bool:
	return heat >= 1.0 and water > 0


func cool() -> bool:
	return heat < COOL


func alcohol_ready() -> bool:
	return mode() == "alcohol" and not rancid and brew_t >= FERMENT_TIME and water > 0


static func is_meat(id: String) -> bool:
	return Items.def(Items.base_of(id)).get("protein", 0.0) > 0.0


static func is_raw_meat(id: String) -> bool:
	## Uncooked meat or fish (it cooks into something, and is risky raw):
	## it spoils a pickle or a brew. Grubs aren't meat enough to.
	var d: Dictionary = Items.def(id)
	return Items.cure_of(id) == "" and is_meat(id) and d.has("cook") and d.get("sick", 0.0) > 0.0


func meat_share() -> float:
	## The share of the food that is meat not yet cured: meat already pickled
	## or preserved in alcohol doesn't count against MEAT_SHARE.
	if items.is_empty():
		return 0.0
	return items.filter(func(it): return Items.cure_of(it.id) == "" and is_meat(it.id)).size() / float(items.size())


func spoil_reason() -> String:
	## Why the mix is (or would be) rancid, or "".
	var food := items.size()
	if food == 0:
		return ""
	if food > water:
		return "more food than water"
	if mode() == "salt" and food > salt:
		return "more food than salt"
	if mode() != "salt" and items.any(func(it): return is_raw_meat(it.id)):
		return "raw meat"
	if mode() != "salt" and meat_share() > MEAT_SHARE:
		return "too much meat"
	return ""


func would_spoil(extra_food: String = "", extra_salt := 0) -> String:
	## What adding this would do: the reason it would go rancid, or "".
	var keep := [items.duplicate(), salt]
	if extra_food != "":
		items.append({"id": extra_food, "t": 0.0, "age": 0.0})
	salt += extra_salt
	var why := spoil_reason()
	items = keep[0]
	salt = keep[1]
	return why


func _check() -> void:
	## Goes rancid if the mix is wrong; salting cures what is in it at once.
	if rancid:
		return
	var why := spoil_reason()
	if why != "":
		rancid = true
		brew_t = 0.0
		_had_meat = items.any(func(it): return is_meat(it.id))
		for it in items:
			it.id = "rotten"
			it.t = 0.0
		if _near_player():
			Game.notify("The mix has gone rancid (%s). Fill the vessel at the water to wash it out." % why)
		_refresh()
		return
	if mode() == "salt":
		for it in items:
			if Items.cure_of(it.id) == "":
				it.id = "salted:" + it.id
	_refresh()


func _near_player() -> bool:
	var p: Node3D = Game.player
	return p != null and is_instance_valid(p) and p.global_position.distance_to(global_position) < 25.0


# --- Putting things in and taking them out -------------------------------------------

func add_food(id: String, age := 0.0) -> String:
	## One food item into the mix. Returns why it can't go in, or "".
	if not fired_pot():
		return "Fire the vessel before you use it."
	if rancid:
		return "It has gone rancid. Fill it at the water to wash it out."
	if not Items.can_cure(id):
		return "Only fresh food goes in a fermentation vessel."
	if water > 0 and dirty:
		return "Boil the water first: swamp water would spoil it."
	if not cool():
		return "Let it cool down before you put food in."
	if items.size() >= CAP:
		return "The vessel holds no more food (%d)." % CAP
	items.append({"id": id, "t": 0.0, "age": age})
	_check()
	return ""


func add_salt() -> String:
	if not fired_pot():
		return "Fire the vessel before you use it."
	if not sealed():
		return "Salting needs the sealed vessel."
	if rancid:
		return "It has gone rancid. Fill it at the water to wash it out."
	if salt >= CAP:
		return "It holds no more salt (%d)." % CAP
	salt += 1
	_check()
	return ""


func pour(clean: bool) -> String:
	## A serving of water poured in from a pot or canteen.
	if not fired_pot():
		return "Fire the vessel before you use it."
	if rancid:
		return "It has gone rancid. Fill it at the water to wash it out."
	if water >= CAP:
		return "It holds no more water (%d)." % CAP
	if not clean and not items.is_empty():
		return "Swamp water would spoil the food in it."
	water += 1
	if not clean:
		dirty = true
	_check()
	return ""


func draw_alcohol() -> String:
	## A canteen draws alcohol: one serving of the brew. Returns why not, or "".
	if mode() != "alcohol" or items.is_empty() and brew_t <= 0.0:
		return "There is no brew in it."
	if not alcohol_ready():
		return "The brew isn't ready: %s more." % _hours(FERMENT_TIME - brew_t)
	if water - 1 < items.size():
		return "Drawing more would leave more food than liquid, and spoil the rest."
	water -= 1
	_refresh()
	return ""


func take(k: int) -> Dictionary:
	## Takes item k out: {id, age}. Salting, it takes a measure of salt with it.
	if k < 0 or k >= items.size():
		return {}
	var it: Dictionary = items[k]
	items.remove_at(k)
	if mode() == "salt":
		salt = maxi(salt - 1, 0)
	if items.is_empty() and rancid and water == 0:
		rancid = false
	_refresh()
	return {"id": it.id, "age": it.age if Items.cure_of(it.id) == "" else 0.0}


func fill_dirty() -> bool:
	## Washed out and filled with swamp water at the water's edge. True if
	## there was meat in it (blood in the water).
	var bloody := items.any(func(it): return it.id != "rotten" and is_meat(it.id)) or (rancid and _had_meat)
	items.clear()
	salt = 0
	rancid = false
	brew_t = 0.0
	water = CAP
	dirty = true
	heat = 0.0
	_had_meat = false
	_refresh()
	return bloody


var _had_meat := false   # rancid with meat in it: still bloody when washed out


# --- Heat and time ------------------------------------------------------------------

func hung() -> bool:
	return fire != null and is_instance_valid(fire) and not fire.is_queued_for_deletion()


func _process(delta: float) -> void:
	if fire != null and not hung():
		fire = null
	advance(delta, delta if hauled_by == null and hung() and fire.lit else 0.0)
	_steam.emitting = boiling() and hauled_by == null
	if boiling() != _was_boiling:
		_was_boiling = boiling()
		if _was_boiling and _near_player():
			Game.notify("The water in the fermentation vessel is boiling.")
		_refresh()


func advance(dt: float, lit_s: float) -> void:
	## Passes dt seconds, the first lit_s of them in a lit fire.
	lit_s = clampf(lit_s, 0.0, dt)
	if not fired_pot():
		if lit_s > 0.0:
			fired += lit_s
			if fired >= FIRE_TIME:
				item_id = item_id.trim_suffix("_unfired")
				_rebuild()
				if _near_player():
					Game.notify("The fermentation vessel is fired.")
		return
	if lit_s > 0.0:
		heat = minf(heat + lit_s / HEAT_TIME, 1.0)
		if heat >= 1.0 and water > 0 and dirty:
			dirty = false
			_refresh()
	if dt > lit_s:
		heat = maxf(heat - (dt - lit_s) / COOL_TIME, 0.0)
	# Fermenting: in clean, cool water, nothing spoiled.
	if rancid or items.is_empty() or water == 0 or dirty or not cool() or mode() == "salt":
		return
	var cure := "pickled" if mode() == "lacto" else "spirit"
	var changed := false
	for it in items:
		if Items.cure_of(it.id) == "":
			it.t += dt
			if it.t >= FERMENT_TIME:
				it.id = cure + ":" + it.id
				changed = true
	if mode() == "alcohol":
		var was := alcohol_ready()
		brew_t += dt
		if not was and alcohol_ready() and _near_player():
			Game.notify("The brew in the sealed vessel is ready. Draw it off with a canteen.")
	if changed:
		_refresh()


static func _hours(seconds: float) -> String:
	var h := ceili(seconds / 60.0)
	return "%d hour%s" % [h, "" if h == 1 else "s"]


# --- Looks --------------------------------------------------------------------------

func _rebuild() -> void:
	if _mesh == null:
		return
	_mesh.mesh = Assets.mesh("item_" + item_id)
	_refresh()


func liquid_color() -> Color:
	if rancid:
		return Color(0.36, 0.34, 0.16)
	if dirty:
		return Items.def("pot_dirty").color
	if mode() == "salt":
		return Color(0.82, 0.84, 0.78)
	if not items.is_empty():
		return Color(0.72, 0.62, 0.32) if mode() == "alcohol" else Color(0.66, 0.72, 0.42)
	return Items.def("pot_clean").color


func _refresh() -> void:
	if _liquid == null:
		return
	# The open crock shows its liquid; the sealed jar keeps its lid on.
	_liquid.visible = water > 0 and not sealed() and fired_pot()
	if not _liquid.visible:
		return
	var f := clampf(water / float(CAP), 0.0, 1.0)
	_liquid.position = Vector3(0, lerpf(LIQUID_Y[0], LIQUID_Y[1], f), 0)
	var r := lerpf(0.2, 0.25, sin(f * PI))
	_liquid.scale = Vector3(r, 1.0, r)
	_liquid_mat.albedo_color = liquid_color()


# --- Carrying ------------------------------------------------------------------------

func can_haul() -> bool:
	return true


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return Items.item_name(item_id).to_lower()


func haul_radius() -> float:
	return 0.5


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	return 0.55


func set_hauled(by: Node3D) -> void:
	## Picked up (or put down, by = null). Put down by a campfire with nothing
	## on it, it sits in the middle of the fire.
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
		Game.notify("You set the %s in the fire." % haul_name())
		return
	var g: float = world.floor_height(global_position) if world else -INF
	global_position.y = g if g > -INF else global_position.y - haul_lift()


func fire_near(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := HANG_R
	for f in Game.fires:
		if not is_instance_valid(f) or f.is_queued_for_deletion():
			continue
		var d := Vector2(f.global_position.x - pos.x, f.global_position.z - pos.z).length()
		if d < best_d and _taken(f) == null:
			best = f
			best_d = d
	return best


func _taken(f: Node3D) -> Node3D:
	for p in get_tree().get_nodes_in_group("fire_pots"):
		if p != self and p.fire == f and not p.is_queued_for_deletion():
			return p
	return null


func haul_prompt(player: Node) -> String:
	if player.focus_water and fired_pot():
		return ("Fill the vessel with swamp water [E]" if is_empty() else "Wash it out and fill it with swamp water [E]") + "   Put it down [Q]"
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	if fire_near(player.global_position + fwd.normalized() * (haul_radius() + 0.55)):
		return "Set the %s in the fire [E]" % haul_name()
	return "Put down the %s [E]" % haul_name()


func haul_interact(player: Node) -> bool:
	## E while carrying it at the water: wash it out and fill it.
	if not player.focus_water:
		return false
	if not fired_pot():
		Game.notify("The clay would soften. Fire the vessel in a campfire first.")
		return true
	var had := not is_empty()
	var bloody := fill_dirty()
	Sfx.play("splash", -4.0)
	Game.notify("You wash out the vessel and fill it with swamp water." if had else "You fill the vessel with swamp water.")
	if bloody and world and world.has_method("blood_in_water"):
		world.blood_in_water(player.water_point(), player)
	return true


# --- Interaction ---------------------------------------------------------------------

const POURS := {"pot_clean": true, "canteen_clean_1": true, "canteen_clean_2": true,
	"pot_dirty": false, "canteen_dirty_1": false, "canteen_dirty_2": false}


func status() -> String:
	if not fired_pot():
		return "unfired"
	if rancid:
		return "rancid"
	if boiling():
		return "boiling"
	if not cool():
		return "hot"
	if water > 0 and dirty:
		return "swamp water"
	match mode():
		"lacto":
			return "pickling" if not items.is_empty() else "ready for food"
		"salt":
			return "salting"
		_:
			if alcohol_ready():
				return "alcohol ready"
			return "brewing" if not items.is_empty() else "ready for food"


func tooltip(_player: Node) -> String:
	if hauled_by:
		return ""
	var name := Items.item_name(item_id)
	if not fired_pot():
		var pct := roundi(fired / FIRE_TIME * 100.0)
		return "%s\nSet it in a lit campfire to fire it%s" % [name, "  (%d%% fired)" % pct if pct > 0 else ""]
	var lines := ["%s: %s" % [name, status()]]
	var parts := ["Water %d/%d%s" % [water, CAP, " (swamp)" if dirty and water > 0 else ""], "Food %d/%d" % [items.size(), CAP]]
	if sealed():
		parts.append("Salt %d/%d" % [salt, CAP])
	lines.append("   ".join(parts))
	if rancid:
		lines.append("Rancid: wash it out at the water")
	elif not items.is_empty() and mode() != "salt":
		var done := items.filter(func(it): return Items.cure_of(it.id) != "").size()
		var next := FERMENT_TIME
		for it in items:
			if Items.cure_of(it.id) == "":
				next = minf(next, FERMENT_TIME - it.t)
		lines.append("%d of %d %s%s" % [done, items.size(), "pickled" if mode() == "lacto" else "preserved",
				"" if done == items.size() else ", next in %s" % _hours(next)])
		if mode() == "alcohol":
			lines.append("Alcohol: %s" % ("ready to draw (%d servings)" % (water - items.size()) if alcohol_ready() else "in %s" % _hours(FERMENT_TIME - brew_t)))
	return "\n".join(lines)


func prompt(player: Node) -> String:
	if hauled_by:
		return ""
	var held: String = Game.inventory.held_id()
	if hung() and SoupPot._for_fire(held):
		return fire.prompt(player)
	if not fired_pot():
		return "Pick up the %s [E]" % Items.item_name(item_id).to_lower()
	var more := "   Open [Right-click]   Carry [C]"
	if POURS.has(held):
		return "Pour in a serving of %s [E]" % ("boiled water" if POURS[held] else "swamp water") + more
	if (held == "canteen" or held == "canteen_alcohol") and mode() == "alcohol" and not items.is_empty():
		return ("Draw alcohol into the canteen [E]" if alcohol_ready() else "The brew isn't ready yet") + more
	if held == "salt" and sealed():
		var w := would_spoil("", 1)
		return "Add salt [E]%s" % ("   (it would go rancid: %s)" % w if w != "" and not rancid else "") + more
	if Items.can_cure(held):
		var w := would_spoil(held)
		return "Put %s in [E]%s" % [Items.item_name(held), "   (it would go rancid: %s)" % w if w != "" and not rancid else ""] + more
	if is_empty():
		return "Pick up the %s [E]" % Items.item_name(item_id).to_lower()
	return "Open the vessel [E]" + more.replace("   Open [Right-click]", "")


func interact(player: Node) -> void:
	if hauled_by:
		return
	var inv = Game.inventory
	var held: String = inv.held_id()
	if hung() and SoupPot._for_fire(held):
		fire.interact(player)
		return
	if not fired_pot() or (is_empty() and not POURS.has(held) and not Items.can_cure(held) and held != "salt"):
		player.start_haul(self)
		return
	var why := ""
	if POURS.has(held):
		why = pour(POURS[held])
		if why == "":
			var def := Items.def(held)
			inv.replace(inv.selected, def.get("empty", "pot"))
			Sfx.play("splash", -10.0, 0.2)
	elif (held == "canteen" or held == "canteen_alcohol") and mode() == "alcohol" and not items.is_empty():
		why = draw_alcohol()
		if why == "":
			inv.replace(inv.selected, "canteen_alcohol", 0.0, Items.measures_data("canteen_alcohol", DRAW))
			Sfx.play("splash", -10.0, 0.2)
			Game.notify("You draw off a canteen of alcohol (%d measures)." % DRAW)
	elif held == "salt":
		why = add_salt()
		if why == "":
			inv.take(inv.selected, 1)
			Sfx.play("pickup", -10.0)
	elif Items.can_cure(held):
		var age: float = inv.slots[inv.selected].age
		why = add_food(held, age)
		if why == "":
			inv.take(inv.selected, 1)
			Sfx.play("splash", -12.0, 0.3)
	else:
		use_interact(player)
		return
	if why != "":
		Game.notify(why)


func use_interact(player: Node) -> void:
	## Right-click: open it to see and take out what is inside.
	if not fired_pot():
		Game.notify("Fire it first.")
		return
	if player.world and player.world.has_method("open_vessel"):
		player.world.open_vessel(self)


func craft_interact(player: Node) -> void:
	player.start_haul(self)


func take_to_bag(k: int) -> bool:
	## From the vessel window: item k into your bag (or onto the ground).
	var got := take(k)
	if got.is_empty():
		return false
	var left: int = Game.inventory.add(got.id, 1, got.age, true)
	if left > 0 and world and world.has_method("spawn_pickup"):
		world.spawn_pickup(got.id, 1, global_position + Vector3(0, 0.3, 0.6), got.age)
	Game.picked.emit(got.id)
	return true


# --- Saving --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := global_position
	return {"id": item_id, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "water": water, "dirty": dirty, "salt": salt,
		"items": items.duplicate(true), "rancid": rancid, "brew_t": brew_t, "heat": heat, "fired": fired,
		"had_meat": _had_meat, "hung": hung()}


func from_dict(d: Dictionary) -> void:
	item_id = String(d.get("id", item_id))
	rotation.y = float(d.get("yaw", 0.0))
	water = clampi(int(d.get("water", 0)), 0, CAP)
	dirty = bool(d.get("dirty", false))
	salt = clampi(int(d.get("salt", 0)), 0, CAP)
	items.clear()
	for it in d.get("items", []):
		if Items.exists(String(it.get("id", ""))):
			items.append({"id": String(it.id), "t": float(it.get("t", 0.0)), "age": float(it.get("age", 0.0))})
	rancid = bool(d.get("rancid", false))
	brew_t = float(d.get("brew_t", 0.0))
	heat = float(d.get("heat", 0.0))
	fired = float(d.get("fired", 0.0))
	_had_meat = bool(d.get("had_meat", false))
	if is_inside_tree():
		_rebuild()
