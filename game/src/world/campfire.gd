extends StaticBody3D
## A placed campfire: burns fuel, cooks food, fires pottery, boils water,
## gives light and keeps predators away.
##
## Things put on the fire sit on one of SPOTS places around the edge and must
## be picked up once they are done. Food left on for BURN times its cooking
## time chars. Burning leaves ash (one per ASH_EVERY seconds of fuel burned),
## which a mattock scoops out; swinging a mattock knocks the fire apart.
##
## A house's fireplace (house.gd) is one too, with `hearth` set: it sits in
## the house's own stone ring, under its chimney, and can't be knocked apart.
##
## When the fuel runs out it doesn't go dark at once: it glows red with coals
## for COAL_MULT times as long as it burned (`coals`). Coals can't cook. Add
## fuel and blow on them (E) and it burns again; with no fuel in it, E takes an
## ember from them instead. An ember set in an unlit fire that has fuel
## (`ember`, seconds until it goes out) is blown on (E) to light it: the way to
## carry fire somewhere new before you have a bow drill.

const MAX_FUEL := 2400.0
const SPOTS := 6
const SPOT_R := 0.44
const BURN := 4.0
const ASH_EVERY := 200.0
const STONES := 2         # river stones in a campfire kit, given back when broken
const COAL_MULT := 3.0    # coals glow this many times as long as the fire burned

var lit := false
var fuel := 480.0
var burned := 0.0         # seconds of fuel burned since the ash was last taken
var cooking: Array = []   # SPOTS entries: null or {id (what was put on), t (seconds cooked)}
var hearth := false       # a house's fireplace
var burn_t := 0.0         # seconds this fire has burned since it was lit
var coals := 0.0          # seconds of glowing coals left once it has burned out
var ember := 0.0          # an ember set in the tinder: seconds until it goes out

var _coals: MeshInstance3D
var _ember: MeshInstance3D

var _light: OmniLight3D
var _flames: MeshInstance3D
var _sound: AudioStreamPlayer3D
var _spots: Array = []
var _flicker := 0.0
var _rng := RandomNumberGenerator.new()


class CookSpot extends StaticBody3D:
	## One place at the edge of the fire; looking at it picks up what is there.
	var fire: Node
	var index := 0
	var shape: CollisionShape3D
	var mesh: MeshInstance3D
	var shown := ""

	func prompt(_player: Node) -> String:
		return fire.spot_prompt(index)

	func interact(_player: Node) -> void:
		fire.take(index)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("fires")
	Game.fires.append(self)
	cooking.resize(SPOTS)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 0.5
	cs.shape = cyl
	cs.position.y = 0.25
	add_child(cs)

	var b = Assets.builder()
	for i in 0 if hearth else 9:
		var a := TAU * i / 9.0
		var at := Vector3(cos(a) * 0.66, 0.0, sin(a) * 0.66)
		b.blob(at + Vector3(0, 0.07 + _lift(at), 0), Vector3(0.13, 0.1, 0.12), 2, 5, Color(0.42, 0.42, 0.40), _rng, 0.2, "stone")
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		b.cylinder(Vector3(cos(a) * 0.3, 0.04, sin(a) * 0.3), Vector3(cos(a) * 0.04, 0.24, sin(a) * 0.04),
			0.045, 0.04, 5, Color(0.30, 0.22, 0.14), Color(0.10, 0.07, 0.05), "wood")
	var base := MeshInstance3D.new()
	base.mesh = b.commit(Assets.materials)
	add_child(base)

	var fb = Assets.builder()
	for i in 3:
		var a := TAU * i / 3.0
		fb.cone(Vector3(cos(a) * 0.07, 0.08, sin(a) * 0.07), Vector3(cos(a) * 0.03, 0.46, sin(a) * 0.03), 0.1, 5, Color(1.0, 0.55, 0.12), "glow")
	fb.cone(Vector3(0, 0.08, 0), Vector3(0, 0.34, 0), 0.08, 5, Color(1.0, 0.85, 0.35), "glow")
	_flames = MeshInstance3D.new()
	_flames.mesh = fb.commit(Assets.materials)
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flames)

	# A bed of red coals, and a single ember in the tinder.
	var cb = Assets.builder()
	for i in 7:
		var a := TAU * i / 7.0 + _rng.randf() * 0.5
		var r := 0.06 if i == 0 else _rng.randf_range(0.1, 0.22)
		var c := Color(0.85, 0.18, 0.05).lerp(Color(1.0, 0.45, 0.1), _rng.randf())
		cb.blob(Vector3(cos(a) * r, 0.04, sin(a) * r), Vector3(0.07, 0.035, 0.06), 1, 5, c, _rng, 0.3, "glow")
	_coals = MeshInstance3D.new()
	_coals.mesh = cb.commit(Assets.materials)
	_coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coals)
	_ember = MeshInstance3D.new()
	_ember.mesh = Assets.mesh("item_ember")
	_ember.position = Vector3(0, 0.1, 0)
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ember)

	_light = OmniLight3D.new()
	_light.position.y = 0.55
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 7.0
	_light.light_energy = 1.0
	add_child(_light)

	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.stream("fire")
	_sound.volume_db = -15.0
	_sound.max_distance = 14.0
	add_child(_sound)

	for i in SPOTS:
		var s := CookSpot.new()
		s.fire = self
		s.index = i
		s.collision_layer = 2
		s.collision_mask = 0
		var a := TAU * (i + 0.5) / SPOTS
		s.position = Vector3(cos(a) * SPOT_R, 0.0, sin(a) * SPOT_R)
		s.position.y = _lift(s.position)  # on the ground there, not sunk in a slope
		s.rotation.y = -a
		s.shape = CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.13
		s.shape.shape = sh
		s.shape.position.y = 0.08
		s.add_child(s.shape)
		s.mesh = MeshInstance3D.new()
		s.mesh.scale = Vector3.ONE * 0.55
		s.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(s.mesh)
		add_child(s)
		_spots.append(s)
	_refresh_spots()
	_set_lit(lit)


func _lift(local: Vector3) -> float:
	## How far the ground at a point of the ring (local, level) is above the
	## fire's own foot, so the stones and what is cooking sit on a slope rather
	## than sinking into it. A fireplace stands on its own level hearth.
	var w := get_parent()
	if hearth or w == null or not w.has_method("ground_height"):
		return 0.0
	var g: Vector3 = global_transform * local
	return clampf(w.ground_height(g.x, g.z) - global_position.y, -0.3, 0.4)


func _exit_tree() -> void:
	Game.fires.erase(self)


func _set_lit(on: bool) -> void:
	lit = on
	if on:
		coals = 0.0
		ember = 0.0
	if on and not _sound.playing:
		_sound.play()
	elif not on:
		_sound.stop()
	_update_look()


func _update_look() -> void:
	## Flames while it burns; red coals, or the one ember, while it doesn't.
	_flames.visible = lit
	_coals.visible = not lit and coals > 0.0
	_ember.visible = not lit and ember > 0.0
	_light.visible = lit or coals > 0.0 or ember > 0.0
	_light.light_color = Color(1.0, 0.62, 0.3) if lit else Color(1.0, 0.3, 0.12)
	_light.omni_range = 7.0 if lit else (3.5 if coals > 0.0 else 1.5)


func can_blow() -> bool:
	## Unlit, with fuel in it and an ember or live coals to blow into flame.
	return not lit and fuel > 0.0 and (ember > 0.0 or coals > 0.0)


func glowing() -> bool:
	## Unlit, but its coals still glow: you can take an ember from it.
	return not lit and coals > 0.0


func _process(delta: float) -> void:
	var rate := 1.8 if get_parent().get("raining") == true else 1.0
	if not lit:
		_cool(delta, rate)
		return
	var burn := minf(delta * rate, fuel)
	fuel -= burn
	burned += burn
	burn_t += burn / rate
	if fuel <= 0.0:
		fuel = 0.0
		_set_lit(false)
		coals = burn_t * COAL_MULT
		burn_t = 0.0
		_update_look()
		Game.notify("The %s has burned down to glowing coals." % _name().to_lower())
		_cool(maxf(delta - burn / rate, 0.0), rate)  # the rest of a long step (asleep)
		return
	_flicker += delta * 9.0
	var f := 0.85 + 0.15 * sin(_flicker) * sin(_flicker * 1.7 + 1.0)
	_light.light_energy = 1.0 * f
	_flames.scale = Vector3(1.0, f * minf(fuel / 240.0 + 0.4, 1.2), 1.0)
	cook(delta)


func _cool(delta: float, rate: float) -> void:
	## Unlit: the coals die down (faster in the rain), and an ember left in the
	## tinder goes out.
	if ember > 0.0:
		ember = maxf(ember - delta, 0.0)
		if ember == 0.0:
			_update_look()
			Game.notify("The ember in the %s has gone out." % _name().to_lower())
	if coals > 0.0:
		coals = maxf(coals - delta * rate, 0.0)
		if coals == 0.0:
			_update_look()
			return
		_flicker += delta * 2.0
		_light.light_energy = 0.5 + 0.12 * sin(_flicker) * sin(_flicker * 1.3 + 2.0)
	elif ember > 0.0:
		_light.light_energy = 0.3


func cook(delta: float) -> void:
	## Advances everything on the fire by delta seconds.
	for i in SPOTS:
		var c = cooking[i]
		if c == null:
			continue
		var was := result(i)
		c.t += delta
		var now := result(i)
		if now != was:
			if now == "charred":
				Game.notify("Something on the fire is burning!")
			else:
				Game.notify("%s is ready. Take it off the fire." % Items.item_name(now))
				Sfx.play("pickup", -8.0)
			_refresh_spots()


func result(i: int) -> String:
	## What you would get from spot i right now: the raw item, the cooked
	## one, or charred remains once food has cooked for BURN times too long.
	var c = cooking[i]
	if c == null:
		return ""
	var d := Items.def(c.id)
	var ct: float = d.get("cook_time", 8.0)
	if d.has("energy") and c.t >= ct * BURN:
		return "charred"
	return d.get("cook", c.id) if c.t >= ct else c.id


func free_spot() -> int:
	return cooking.find(null)


func ash() -> int:
	return floori(burned / ASH_EVERY)


func _refresh_spots() -> void:
	for i in _spots.size():
		var s: CookSpot = _spots[i]
		var id := result(i)
		s.shape.disabled = id == ""
		if id != s.shown:
			s.shown = id
			s.mesh.mesh = Assets.mesh("item_" + id) if id != "" else null


func spot_prompt(i: int) -> String:
	var c = cooking[i]
	if c == null:
		return prompt(null)
	var id := result(i)
	if id == c.id:
		var ct: float = Items.def(c.id).get("cook_time", 8.0)
		return "Take %s off the fire [E]   (%d%% done)" % [Items.item_name(id), roundi(c.t / ct * 100.0)]
	return "Take %s [E]" % Items.item_name(id)


func take(i: int) -> void:
	## Picks up whatever is on spot i, cooked or not.
	var id := result(i)
	if id == "":
		return
	cooking[i] = null
	_give(id, 1)
	Sfx.play("pickup", -8.0)
	Game.picked.emit(id)
	_refresh_spots()


func _give(id: String, n: int) -> void:
	var left: int = Game.inventory.add(id, n, 0.0, true)
	if left > 0 and get_parent().has_method("spawn_pickup"):
		get_parent().spawn_pickup(id, left, global_position + Vector3(0, 0.3, 0.9))


func prompt(_player: Node) -> String:
	var held: String = Game.inventory.held_id()
	var def := Items.def(held)
	var status := "burning, %ds of fuel" % int(fuel) if lit else ("glowing coals" if glowing() else ("an ember in the tinder" if ember > 0.0 else "unlit"))
	var n := SPOTS - cooking.count(null)
	if n > 0:
		status += ", %d by the fire" % n
	if held == "torch" and lit:
		return "Light the torch [E]   (%s)" % status
	if held == "torch_lit" and not lit and fuel > 0.0:
		return "Light the fire with the torch [E]   (%s)" % status
	if held == "ember" and not lit and coals <= 0.0:
		if fuel <= 0.0:
			return "Add fuel before you set the ember in it   (%s)" % status
		if ember <= 0.0:
			return "Set the ember in the tinder [E]   (%s)" % status
	if can_blow():
		return "Blow on the %s [E]   (%s)" % ["ember" if ember > 0.0 else "coals", status]
	if "dig" in def.get("tags", []):
		return ("Scoop out ash [E]   (%d ash)" % ash()) if ash() > 0 else "%s   (%s, no ash yet)" % [_name(), status]
	if def.has("fuel"):
		return "Add %s as fuel [E]   (%s)" % [def.name, status]
	if def.has("cook") and lit:
		if free_spot() < 0:
			return "%s   (%s, no room to cook more)" % [_name(), status]
		return "Set %s by the fire [E]   (%s)" % [def.name, status]
	if glowing():
		return "Take an ember [E]   (%s: too low to cook on; add fuel to blow them back to flame)" % status
	if not lit:
		return "Light fire [E]   (needs an ember, a bow drill or a lit torch)" if fuel > 0.0 else "Add fuel first   (unlit)"
	return "%s   (%s)" % [_name(), status]


func _name() -> String:
	return "Fireplace" if hearth else "Campfire"


func interact(_player: Node) -> void:
	var inv = Game.inventory
	var held: String = inv.held_id()
	var def := Items.def(held)
	if held == "torch" and lit:
		inv.take(inv.selected, 1)
		inv.add("torch_lit", 1, 0.0, true)
		Sfx.play("fire_start", -8.0)
		Game.notify("The torch catches.")
	elif held == "torch_lit" and not lit and fuel > 0.0:
		_light_up()
	elif held == "ember" and not lit and ember <= 0.0 and coals <= 0.0:
		if fuel <= 0.0:
			Game.notify("Add fuel first: sticks, fronds or tinder for the ember to catch.")
			return
		var slot: Dictionary = inv.slots[inv.selected]
		ember = maxf(float(Items.def("ember").decay) - float(slot.age), 1.0)
		inv.take(inv.selected, 1)
		_update_look()
		Sfx.play("craft", -10.0)
		Game.notify("You set the ember in the tinder. Blow on it before it goes out.")
	elif can_blow():
		_light_up()
	elif "dig" in def.get("tags", []):
		var n := ash()
		if n <= 0:
			Game.notify("There's no ash to scoop out yet.")
			return
		burned -= n * ASH_EVERY
		_give("ash", n)
		Sfx.play("step", -6.0, 0.2)
		Game.notify("Scooped out Ash x%d." % n)
	elif def.has("fuel"):
		if fuel >= MAX_FUEL:
			Game.notify("The fire can't take more fuel.")
			return
		inv.take(inv.selected, 1)
		fuel = minf(fuel + def.fuel, MAX_FUEL)
		Sfx.play("craft", -10.0)
	elif def.has("cook") and lit:
		var i := free_spot()
		if i < 0:
			Game.notify("There's no room left around the fire.")
			return
		inv.take(inv.selected, 1)
		cooking[i] = {"id": held, "t": 0.0}
		_refresh_spots()
		Game.notify("%s is by the fire. Pick it up when it's done." % def.name)
	elif glowing():
		take_ember()
	elif not lit:
		if fuel <= 0.0:
			Game.notify("The fire needs fuel: sticks, fronds or tinder.")
		elif not inv.has_tag("fire"):
			Game.notify("You need an ember to light a fire: take one from glowing coals or a burning stump. (A bow drill or a lit torch works too.)")
		else:
			_light_up()


func take_ember() -> bool:
	## An ember from the coals into your bag (false if there's no room).
	if Game.inventory.add("ember", 1) > 0:
		Game.notify("You have no room to carry an ember.")
		return false
	Sfx.play("pickup", -8.0)
	Game.picked.emit("ember")
	Game.notify("You take a glowing ember. It will go out in about three hours.")
	return true


func _light_up() -> void:
	_set_lit(true)
	Sfx.play("fire_start", -4.0)
	Game.notify("The tinder catches fast in the rich air.")
	Game.crafted.emit("fire_lit")


func break_apart() -> void:
	## A mattock knocks the fire apart: the ring stones and any ash come back,
	## and whatever was cooking is left on the ground. A fireplace is built
	## into its house.
	if hearth:
		Game.notify("The fireplace is built into the house. It won't come apart.")
		return
	var got := ["River Stone x%d" % STONES]
	_give("stone", STONES)
	var n := ash()
	if n > 0:
		_give("ash", n)
		got.append("Ash x%d" % n)
	for i in SPOTS:
		var id := result(i)
		if id != "" and get_parent().has_method("spawn_pickup"):
			get_parent().spawn_pickup(id, 1, to_global(_spots[i].position + Vector3(0, 0.2, 0)))
	cooking.fill(null)
	Sfx.play_at("hit", global_position, -2.0)
	Game.notify("You knock the campfire apart: " + ", ".join(got) + ".")
	Game.fires.erase(self)
	queue_free()


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "fuel": fuel, "lit": lit, "burned": burned, "cooking": cooking.duplicate(true),
		"burn_t": burn_t, "coals": coals, "ember": ember}


func from_dict(d: Dictionary) -> void:
	fuel = float(d.get("fuel", fuel))
	burned = float(d.get("burned", 0.0))
	var src: Array = d.get("cooking", [])
	for i in mini(src.size(), SPOTS):
		var c = src[i]
		cooking[i] = {"id": String(c.id), "t": float(c.t)} if c != null and Items.exists(c.get("id", "")) else null
	_refresh_spots()
	_set_lit(bool(d.get("lit", false)))
	burn_t = float(d.get("burn_t", 0.0))
	coals = float(d.get("coals", 0.0))
	ember = float(d.get("ember", 0.0))
	_update_look()
