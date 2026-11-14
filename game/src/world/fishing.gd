extends Node3D
## A cast fishing line (`player.fishing`). Use with a baited rod in hand casts
## the hook, which flies like a thrown stone (thrown_rock.gd's arc). In the
## water it waits (you can step back up to SLACK from where you cast without
## drawing it in, out of reach of what lurks at the edge); every BITE_EVERY seconds there is a BITE_CHANCE of a bite,
## which always takes the bait. NIBBLE_CHANCE of bites only take the bait.
## Otherwise a fish is on (a Creature of a fish species, picked by `fish.weight`;
## the bait makes no difference), and Use reels in a pull at a time while it
## swims away from you, taking line out. Once it is dragged onto land it flops
## where it lies; the line still drags it when you reel or walk away. At your
## feet, strike it with a weapon: dead, it is an ordinary carcass. A fish that
## takes all MAX_LINE out and keeps pulling for ESCAPE_TIME, with no pull
## from you to take some back, gets away. Amphibians near a hooked fish, in the
## water or just ashore, may take it. Use on an empty line reels it in; putting
## the rod away (or dying) ends the line, and a fish in the water is lost.
## A fish's `lure` widens and sharpens the amphibians' chance; the debug panel
## can force the next fish (`next_fish`).

const Creature := preload("res://src/creatures/creature.gd")
const ThrownRock := preload("res://src/world/thrown_rock.gd")

const GRAVITY := 9.8
const WIND_DRAG := 0.3
const STEPS := 3
const BITE_EVERY := 5.0      # seconds between rolls for a bite
const BITE_CHANCE := 0.15
const NIBBLE_CHANCE := 0.3   # of bites, the share that only take the bait
const REEL_STEP := 1.2       # metres of line each pull takes in
const MAX_LINE := 30.0       # all the line there is
const ESCAPE_TIME := 3.0     # seconds a fish pulls on all of it before it is gone, with the bait
const AT_FEET := 1.8         # a landed fish this close can be struck
const SLACK := 5.0           # metres you can back off a cast hook before it drags after you
const PREDATOR_EVERY := 2.0
const PREDATOR_RANGE := 12.0 # an amphibian this close to a hooked fish may take it
const PREDATOR_CHANCE := 0.2 # each check, for each amphibian in range
const SHORE_REACH := 6.0     # a fish on land this close to the water can still be taken

## Debug panel: the species the next bite will be (never a nibble), then "".
static var next_fish := ""

var player: Node3D
var world: Node
var state := "flying"        # flying, waiting (in the water), ground (on land), hooked, landed
var hook := Vector3.ZERO
var vel := Vector3.ZERO
var line_len := 0.0          # the most line out: reeling shortens it, a fish lengthens it
var fish: Node3D = null
var bait := ""               # still on the hook ("" once taken)
var slot := -1               # the hotbar slot of the rod it was cast from
var rod := "fishing_rod"     # the rod it was cast from (a copper-hook one keeps its bait)
var _bite_t := BITE_EVERY
var _pred_t := PREDATOR_EVERY
var _wobble := 0.0
var _t := 0.0
var _told_strike := false
var _slack_t := 0.0          # how long a fish has been pulling on all the line
var _hook_mesh: MeshInstance3D
var _bait_mesh: MeshInstance3D
var _line: MeshInstance3D
var _im: ImmediateMesh
var _rng := RandomNumberGenerator.new()


func setup(p: Node3D, w: Node, from: Vector3, velocity: Vector3, with_bait: String) -> Node3D:
	player = p
	world = w
	hook = from
	vel = velocity
	bait = with_bait
	slot = Game.inventory.selected
	if Items.def(Game.inventory.held_id()).get("fishing", false):
		rod = Game.inventory.held_id()
	top_level = true
	_rng.randomize()
	return self


func _ready() -> void:
	_hook_mesh = MeshInstance3D.new()
	_hook_mesh.mesh = Assets.mesh("item_chitin_hook")
	_hook_mesh.top_level = true
	add_child(_hook_mesh)
	_bait_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.04
	sm.radial_segments = 6
	sm.rings = 3
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Items.def(bait).get("color", Color(0.8, 0.4, 0.4))
	sm.material = bm
	_bait_mesh.mesh = sm
	_bait_mesh.top_level = true
	add_child(_bait_mesh)
	_im = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _im
	_line.top_level = true
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lm := StandardMaterial3D.new()  # lit like the ground, so it is dark at night
	lm.roughness = 1.0
	lm.albedo_color = Items.def("fishing_line").color
	_line.material_override = lm
	add_child(_line)
	_place_hook()


func _process(delta: float) -> void:
	_t += delta
	if not _rod_in_hand():
		var on: bool = fish != null and is_instance_valid(fish) and not fish.dead
		end(_lost_line_text() if on else "The line goes slack as you put the rod away.")
		return
	match state:
		"flying":
			_fly(delta)
		"waiting":
			_drag_hook()
			if bait != "":
				_bite_t -= delta
				if _bite_t <= 0.0:
					_bite_t = BITE_EVERY
					if _rng.randf() < BITE_CHANCE:
						bite()
		"ground":
			_drag_hook()
		"hooked", "landed":
			_fight(delta)
			if not is_inside_tree() or state == "":
				return
			_pred_t -= delta
			if _pred_t <= 0.0:
				_pred_t = PREDATOR_EVERY
				_check_predators()
	if is_inside_tree():
		_place_hook()
		_draw_line()


func _rod_in_hand() -> bool:
	return is_instance_valid(player) and player.fishing == self and not player.vitals.dead \
			and Game.inventory.selected == slot and Game.inventory.held_id() == rod  # not another rod


# --- The cast -----------------------------------------------------------------------

func _fly(delta: float) -> void:
	## Like a thrown stone: gravity, and air drag toward the wind.
	var dt := delta / STEPS
	for i in STEPS:
		var prev := hook
		vel.y -= GRAVITY * dt
		if world.wind != Vector3.ZERO:
			var flat := Vector3(vel.x, 0, vel.z)
			vel += (world.wind - flat) * WIND_DRAG * dt
		var next := prev + vel * dt
		var g: float = world.ground_height(next.x, next.z)
		var water: float = world.water_level()
		if g < water and prev.y >= water and next.y < water:
			hook = Vector3(next.x, water, next.z)
			ThrownRock.ripple(world, hook)
			_settle("waiting")
			return
		var hit := _solid_on(prev, next)
		if not hit.is_empty():
			hook = hit.position + hit.normal * 0.05
			_settle("ground")
			return
		if next.y <= g:
			hook = Vector3(next.x, g, next.z)
			_settle("ground")
			return
		hook = next
	if _t > 6.0:
		_settle("ground")


func _settle(s: String) -> void:
	state = s
	line_len = _flat_to_player(hook).length()
	if s == "ground":
		hook.y = world.floor_height(hook) if world.has_method("floor_height") else world.ground_height(hook.x, hook.z)
		Sfx.play_at("step", hook, -10.0, 0.3)


func _solid_on(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	if player is CollisionObject3D:
		q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func _drag_hook() -> void:
	## Step back and the hook stays put, the line paying out up to SLACK
	## more; walk further and it comes after you.
	var flat := _flat_to_player(hook)
	var reach := line_len + SLACK
	if flat.length() <= reach:
		if state == "waiting":
			hook.y = world.water_level() + sin(_t * 2.0) * 0.015
		return
	var p := player.global_position
	var to := p + flat.normalized() * reach
	var g: float = world.ground_height(to.x, to.z)
	var water: float = world.water_level()
	if g < water - 0.05:
		hook = Vector3(to.x, water, to.z)
		state = "waiting"
	else:
		hook = Vector3(to.x, g, to.z)
		state = "ground"


func _flat_to_player(p: Vector3) -> Vector3:
	## From the player to p, level.
	var me := player.global_position
	return Vector3(p.x - me.x, 0, p.z - me.z)


# --- Bites -------------------------------------------------------------------------

func copper_hook() -> bool:
	## A barbed copper hook holds the bait fast (metals.md): no fish steals it,
	## and an amphibian tearing a hooked fish off leaves it on.
	return Items.def(rod).get("copper_hook", false)


func bite() -> void:
	## Something takes the bait. Now and then that is all it does; otherwise
	## a fish is on. On a copper hook every bite is a fish, and the bait stays
	## on until one is landed or fights free.
	if not copper_hook():
		_take_bait()
	player.rod_tug = 1.0
	var sp := next_fish
	next_fish = ""
	if sp == "" and not copper_hook() and _rng.randf() < NIBBLE_CHANCE:
		Game.notify("Something takes the bait and is gone. Reel in and bait the hook again.")
		return
	if sp == "" or not Creature.SPECIES.has(sp):
		sp = pick_species(_rng.randf())
	fish = Creature.new().setup(sp, Vector3(hook.x, world.water_level() - 0.12, hook.z), world)
	fish.hooked_by = self
	world.add_child(fish)
	var away := _flat_to_player(hook).normalized()
	fish.heading = atan2(away.x, away.z)
	fish.rotation.y = fish.heading + PI
	state = "hooked"
	line_len = _flat_to_player(hook).length()
	Sfx.play_at("splash", hook, -2.0, 0.2)
	Game.notify("A fish bites! Reel it in (%s)." % Settings.button_name("use"))


static func pick_species(roll: float) -> String:
	## A fish species by its share of bites (`fish.weight`), for a roll in 0..1.
	var total := 0.0
	for sp in Creature.SPECIES:
		total += float(Creature.SPECIES[sp].get("fish", {}).get("weight", 0.0))
	var at := roll * total
	for sp in Creature.SPECIES:
		var w := float(Creature.SPECIES[sp].get("fish", {}).get("weight", 0.0))
		if w <= 0.0:
			continue
		if at < w:
			return sp
		at -= w
	return "elonichthys"


func _take_bait() -> void:
	## The bait is gone from the hook, and from the rod in your hand.
	bait = ""
	var inv = Game.inventory
	var s = inv.held()
	if s != null and s.id == rod:
		inv.replace(inv.selected, rod, s.age)


# --- Reeling in --------------------------------------------------------------------

func reel() -> void:
	## Use while the line is out: an empty line comes in; a fish is pulled in
	## a stretch closer.
	match state:
		"waiting", "ground":
			end("You reel in the line." if bait != "" else "You reel in the bare hook. Bait it again (%s) before you cast." % Settings.button_name("craft"))
		"hooked", "landed":
			line_len = maxf(line_len - REEL_STEP, AT_FEET * 0.8)
			player.rod_tug = maxf(player.rod_tug, 0.6)
			Sfx.play("rustle", -10.0, 0.2)


func _fight(delta: float) -> void:
	if fish == null or not is_instance_valid(fish) or fish.dead:
		end()
		return
	var p: Vector3 = player.global_position
	var f: Vector3 = fish.global_position
	var water: float = world.water_level()
	var away := _flat_to_player(f).normalized()
	if world.ground_height(f.x, f.z) < water - 0.05 and deck_top(f) == -INF:
		# In the water it swims away from you, weaving, and takes line out.
		state = "hooked"
		player.rod_tug = maxf(player.rod_tug, 0.45)
		_wobble += delta * 0.8
		var dir := (away + away.cross(Vector3.UP) * sin(_wobble) * 0.8).normalized()
		var to: Vector3 = f + dir * float(fish.def.speed) * delta
		if world.ground_height(to.x, to.z) < water - 0.15 and deck_top(to) == -INF:
			f = to  # (never in under a dock or a raft)
		fish.heading = atan2(dir.x, dir.z)
		fish.rotation.y = fish.heading + PI
		line_len += float(fish.def.fish.pull) * delta
		if line_len >= MAX_LINE:  # the fish is held to line_len below
			# All the line is out: reel some back in time or it breaks free.
			line_len = MAX_LINE
			if _slack_t == 0.0:
				Game.notify("The line is all out! Reel in (%s) or the %s gets away." % [Settings.button_name("use"), fish.def.name])
			_slack_t += delta
			player.rod_tug = 1.0
			if _slack_t >= ESCAPE_TIME:
				if copper_hook():
					_take_bait()
				_got_away()
				return
		else:
			_slack_t = 0.0
	else:
		if state != "landed" and copper_hook():
			_take_bait()  # the fish has it in its mouth
		state = "landed"
	# The line is never longer than line_len: reeling, or walking off, drags it.
	var flat := _flat_to_player(f)
	if flat.length() > line_len:
		f = Vector3(p.x, 0, p.z) + flat.normalized() * line_len
	var g: float = world.ground_height(f.x, f.z)
	var deck := deck_top(f)
	if deck > -INF:
		f.y = deck  # reeled in at a dock or raft: hauled up onto its deck
	else:
		f.y = water - 0.12 if g < water - 0.05 else (world.floor_height(Vector3(f.x, g, f.z)) if world.has_method("floor_height") else g)
	fish.global_position = f
	if state == "landed" and _flat_to_player(f).length() <= AT_FEET and not _told_strike:
		_told_strike = true
		Game.notify("The %s flops at your feet. Strike it with a weapon (%s)." % [fish.def.name, Settings.button_name("attack")])


func deck_top(at: Vector3) -> float:
	## The deck of a finished dock or raft over the water at `at`, or -INF: a
	## fish reeled in to one is hauled up onto it rather than left under it.
	var top := -INF
	for d in Game.docks + Game.rafts:
		if is_instance_valid(d):
			top = maxf(top, d.floor_top(Vector3(at.x, d.global_position.y, at.z)))
	return top if top > world.water_level() else -INF


func _got_away() -> void:
	ThrownRock.ripple(world, fish.global_position)
	Game.notify("The line goes slack: the %s got away with the bait." % fish.def.name)
	fish.queue_free()
	fish = null
	end()


func _lost_line_text() -> String:
	return "You let the line go, and the %s with it." % fish.def.name if state == "hooked" else ""


func fish_died() -> void:
	## Struck dead (or suffocated) on the line: it is just a carcass now.
	fish = null
	end()


# --- Water predators ---------------------------------------------------------------

func _check_predators() -> void:
	## An amphibian near a hooked fish, in the water or just ashore, may take it.
	if not Game.hostile() or fish == null:
		return
	var f: Vector3 = fish.global_position
	if state == "landed" and not world.water_point(f, SHORE_REACH).is_finite():
		return  # dragged well up the bank: out of their reach
	var lure: float = fish.def.fish.get("lure", 1.0)  # a big thrashing shark draws them from further
	for c in Game.creatures:
		if not is_instance_valid(c) or c.dead or c == fish or not c.def.behavior in ["ambusher", "lurker"]:
			continue
		if c.global_position.distance_to(f) > PREDATOR_RANGE * lure:
			continue
		if _rng.randf() < PREDATOR_CHANCE * lure:
			taken_by(c)
			return


func taken_by(c: Node3D) -> void:
	## The amphibian lunges and the fish is gone, bait and all.
	var f: Vector3 = fish.global_position
	if c.has_method("lure"):
		c.lure(f)
	if state == "hooked":
		ThrownRock.ripple(world, f)
	Sfx.play_at(c.def.get("sound", "hiss"), f, 2.0, 0.1)
	player.rod_tug = 1.0
	Game.notify("A %s snatches your %s off the line!%s" % [c.def.name, fish.def.name, " The bait stays on the copper hook." if copper_hook() else ""])
	fish.queue_free()
	fish = null
	end()


# --- Ending, and drawing ------------------------------------------------------------

func end(msg := "") -> void:
	## The line is in (or gone). A live fish still in the water swims off; one
	## on land is left flopping there.
	if fish and is_instance_valid(fish) and not fish.dead:
		fish.hooked_by = null
		if state == "hooked":
			ThrownRock.ripple(world, fish.global_position)
			fish.queue_free()
	fish = null
	state = ""
	if msg != "":
		Game.notify(msg)
	if is_instance_valid(player) and player.fishing == self:
		player.fishing = null
	queue_free()


func rod_tip() -> Vector3:
	if is_instance_valid(player) and player.held_mesh:
		return player.held_mesh.to_global(Vector3(0.7, 0.02, 0))
	return hook


func _place_hook() -> void:
	var on_fish := fish != null and is_instance_valid(fish)
	_hook_mesh.visible = not on_fish
	_bait_mesh.visible = not on_fish and bait != ""
	var at := hook
	if on_fish:
		at = fish.global_position
	_hook_mesh.global_position = at
	_bait_mesh.global_position = at + Vector3(0, 0.02, 0)


func _draw_line() -> void:
	## From the rod tip to the hook (or the fish's mouth): slack and sagging
	## while it waits, drawn tight with a fish on.
	var a := rod_tip()
	var b := hook
	if fish != null and is_instance_valid(fish):
		b = fish.global_position - fish.global_basis.z * float(fish.def.fish.len) * 0.4
	var sag := 0.02 if state in ["hooked", "landed"] else clampf(a.distance_to(b) * 0.06, 0.05, 1.5)
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var t := i / 12.0
		_im.surface_set_normal(Vector3.UP)
		_im.surface_add_vertex(a.lerp(b, t) - Vector3(0, sin(t * PI) * sag, 0))
	_im.surface_end()
