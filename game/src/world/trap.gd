extends StaticBody3D
## A trap left out in the world (group "traps", saved with the world): a fish
## trap ("fish_trap"), a woven basket made at a workbench, carried in your
## arms (player.start_haul) and set down in the water; or a snare ("snare"),
## set on the ground with Use. Bait it by kneeling at it (C) with any bait laid
## out (work_spot.trap_options). Each time you sleep (swamp.sleep → catch) a
## baited trap may catch something:
##   fish trap  1 to 5 small fish, every time, eating the bait (in the water only)
##   snare      a small animal (SMALL), nothing (the bait left), or a medium
##              one (MEDIUM), held there alive until you kill it
## What is caught keeps KEEP (two days) in the trap, then it is rotten food.
## E takes out what is caught (carcasses, butchered like any you killed), or
## picks up an empty trap.

const Creature := preload("res://src/creatures/creature.gd")

const KEEP := 2.0 * 1440.0
const FISH := ["elonichthys_carcass", "haplolepis_carcass", "amphicentrum_carcass", "acanthodes_carcass", "bandringa_carcass"]
const SMALL := 0.7
const MEDIUM := 0.1
const ROTTEN_MEDIUM := 3   # rotten food left of a medium animal
const LEASH := 0.9         # how far a snared animal can pull from the snare
const SPAWN_RANGE := 120.0 # a snared animal is there while you are this close
const DEEP := 1.1          # a fish trap won't go down in water deeper than this
const FISH_R := 0.24       # the fish trap's radius, lying along X

var kind := "fish_trap"
var bait := ""
var caught: Array = []     # [{id, at}] carcasses (or {species, at}: a live medium animal)
var hauled_by: Node3D = null
var world: Node = null

var _shape: CollisionShape3D
var _bits: Node3D          # the bait and what is caught, shown in the trap
var _beast: Node3D = null  # the snared animal, while it is about
var _tick := 0.0


func setup(k: String, w: Node) -> Node3D:
	kind = k
	world = w
	return self


func _ready() -> void:
	add_to_group("traps")
	collision_layer = 3
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	if kind == "fish_trap":
		box.size = Vector3(0.95, FISH_R * 2.0, FISH_R * 2.0)
		_shape.position.y = FISH_R
	else:
		box.size = Vector3(0.6, 0.4, 0.4)
		_shape.position = Vector3(0.0, 0.2, 0.0)
	_shape.shape = box
	add_child(_shape)
	var m := MeshInstance3D.new()
	m.mesh = Assets.mesh("fish_trap" if kind == "fish_trap" else "snare_set")
	m.visibility_range_end = 80.0
	add_child(m)
	_bits = Node3D.new()
	add_child(_bits)
	_refresh()


func trap_name() -> String:
	return Items.item_name(kind).to_lower()


func bait_point() -> Vector3:
	## Where the bait goes (world space): inside the basket, or on the ground
	## just past the noose.
	return to_global(Vector3(-0.15, FISH_R * 0.6, 0.0) if kind == "fish_trap" else Vector3(0.24, 0.03, 0.0))


func depth() -> float:
	## How deep the water is where it lies (0 on dry land).
	if world == null or not world.has_method("water_level"):
		return 0.0
	return maxf(world.water_level() - world.floor_height(global_position), 0.0)


func in_water() -> bool:
	return depth() > 0.1


func live_beast() -> bool:
	## A medium animal is caught in it, still alive.
	return not caught.is_empty() and caught[0].has("species")


func rotten(e: Dictionary) -> bool:
	return Game.time >= float(e.at) + KEEP


# --- Catching ------------------------------------------------------------------------

func catch(rng: RandomNumberGenerator) -> int:
	## On waking: what the night brought. Returns how many animals it caught.
	if bait == "":
		return 0
	if kind == "fish_trap":
		if not in_water():
			return 0
		var n := rng.randi_range(1, 5)
		for i in n:
			caught.append({"id": FISH[rng.randi() % FISH.size()], "at": Game.time})
		bait = ""
		_refresh()
		return n
	if not caught.is_empty():
		return 0  # the noose is already round something
	var r := rng.randf()
	if r < SMALL:
		var prey: Array = Creature.SPECIES.keys().filter(func(k): return Creature.SPECIES[k].behavior == "prey" and Creature.SPECIES[k].has("carcass"))
		caught.append({"id": Creature.SPECIES[prey[rng.randi() % prey.size()]].carcass, "at": Game.time})
	elif r >= 1.0 - MEDIUM:
		var big: Array = Creature.SPECIES.keys().filter(func(k): return Creature.SPECIES[k].get("size", "") == "medium" \
				and Creature.SPECIES[k].habitat == "land" and Creature.SPECIES[k].behavior in ["hunter", "defensive"])
		caught.append({"species": big[rng.randi() % big.size()], "at": Game.time})
	else:
		return 0  # nothing came: the bait is still there
	bait = ""
	_refresh()
	return 1


func _process(delta: float) -> void:
	if hauled_by or kind != "snare":
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	if not live_beast():
		return
	var alive := _beast != null and is_instance_valid(_beast) and not _beast.is_queued_for_deletion()
	if alive and _beast.dead:
		# Killed: the carcass lies where it fell, the snare is empty again.
		_beast.snared = null
		_beast = null
		caught.clear()
		_refresh()
		return
	if rotten(caught[0]):
		# Two days in the noose: it is dead and gone bad.
		if alive:
			_beast.queue_free()
		_beast = null
		caught[0] = {"id": "rotten", "n": ROTTEN_MEDIUM, "at": caught[0].at}
		_refresh()
		return
	var p: Node3D = Game.player
	if not alive and p and p.global_position.distance_to(global_position) < SPAWN_RANGE and world:
		# Still there in the noose whenever you come back.
		_beast = Creature.new().setup(caught[0].species, global_position + global_basis.x * 0.3, world)
		_beast.snared = self
		world.add_child(_beast)


func leash_point() -> Vector3:
	return global_position


# --- Interaction ---------------------------------------------------------------------

func prompt(_player: Node) -> String:
	if hauled_by:
		return ""
	if live_beast():
		return "%s: a %s is caught in it. Kill it." % [Items.item_name(kind), Creature.SPECIES[caught[0].species].name]
	if not caught.is_empty():
		return "Take out the %s [E]" % _caught_text()
	var state := "baited with %s" % Items.item_name(bait).to_lower() if bait != "" else "not baited"
	if kind == "fish_trap" and not in_water():
		state += "; set it in the water to catch fish"
	return "Pick up the %s [E]   or bait it [C]   (%s)" % [trap_name(), state]


func _caught_text() -> String:
	var n := {}
	for e in caught:
		var id: String = "rotten" if rotten(e) else e.id
		n[id] = n.get(id, 0) + int(e.get("n", 1))
	var out := []
	for id in n:
		out.append("%s x%d" % [Items.item_name(id), n[id]] if n[id] > 1 else Items.item_name(id))
	return ", ".join(out)


func interact(player: Node) -> void:
	if hauled_by:
		return
	if live_beast():
		Game.notify("The %s is still alive in the %s. Kill it first." % [Creature.SPECIES[caught[0].species].name, trap_name()])
		return
	if not caught.is_empty():
		var got := _caught_text()
		for e in caught:
			var id: String = "rotten" if rotten(e) else e.id
			var left: int = Game.inventory.add(id, int(e.get("n", 1)))
			if left > 0 and world and world.has_method("spawn_pickup"):
				world.spawn_pickup(id, left, global_position + Vector3(0, 0.4, 0))
			Game.picked.emit(id)
		caught.clear()
		Sfx.play("pickup", -6.0)
		Game.notify("You take %s out of the %s." % [got, trap_name()])
		_refresh()
		return
	if kind == "fish_trap":
		player.start_haul(self)
		return
	if Game.inventory.add("snare", 1) > 0:
		Game.notify("No room in your bag for the snare.")
		return
	if bait != "" and Game.inventory.add(bait, 1) > 0 and world:
		world.spawn_pickup(bait, 1, global_position + Vector3(0, 0.3, 0))
	Sfx.play("pickup", -8.0)
	queue_free()


func craft_interact(player: Node) -> void:
	## C: kneel to bait it.
	if live_beast():
		Game.notify("The %s is still alive in the %s. Kill it first." % [Creature.SPECIES[caught[0].species].name, trap_name()])
		return
	if world and world.has_method("start_trap_work"):
		world.start_trap_work(self)


func set_bait(id: String) -> void:
	bait = id
	_refresh()


# --- Carrying a fish trap (see player.start_haul) -----------------------------------------

func can_haul() -> bool:
	return kind == "fish_trap"


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return trap_name()


func haul_radius() -> float:
	return FISH_R


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	return 0.9


func _put_point(player: Node) -> Vector3:
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	return player.global_position + fwd.normalized() * (FISH_R + 0.55)


func _depth_at(p: Vector3) -> float:
	if world == null or not world.has_method("water_level"):
		return 0.0
	return maxf(world.water_level() - world.floor_height(p), 0.0)


func haul_prompt(player: Node) -> String:
	var d := _depth_at(_put_point(player))
	if d > DEEP:
		return "Too deep to set the %s here: wade in shallower water" % trap_name()
	if d > 0.1:
		return "Set the %s down in the water [E]" % trap_name()
	return "Put down the %s [E]   (it only catches set in the water)" % trap_name()


func can_put_down() -> bool:
	var p: Node = hauled_by
	if p and _depth_at(_put_point(p)) > DEEP:
		Game.notify("The water is too deep here: the %s would be lost. Set it down in the shallows." % trap_name())
		return false
	return true


func set_hauled(by: Node3D) -> void:
	hauled_by = by
	_shape.disabled = by != null
	if by == null:
		var g: float = world.floor_height(global_position) if world else global_position.y
		global_position.y = g
		rotation = Vector3(0, rotation.y, 0)
		if in_water():
			Sfx.play("splash", -8.0)


# --- Looks -------------------------------------------------------------------------

func _refresh() -> void:
	## The bait, and what is caught (the fish, or a small animal in the noose).
	if _bits == null:
		return
	for c in _bits.get_children():
		c.queue_free()
	if bait != "":
		_show(bait, to_local(bait_point()), 0.12, 0.0)
	if kind == "fish_trap":
		for i in mini(caught.size(), 4):
			var e: Dictionary = caught[i]
			_show("rotten" if rotten(e) else e.id, Vector3(lerpf(-0.25, 0.2, i / 3.0), 0.06 + 0.04 * (i % 2), 0.07 * (1 - 2 * (i % 2))), 0.3, 0.3 * i)
	elif not caught.is_empty() and not live_beast():
		_show("rotten" if rotten(caught[0]) else caught[0].id, Vector3(0.12, 0.0, 0.0), 0.35, 0.4)


func _show(id: String, at: Vector3, size: float, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Assets.mesh("item_" + id)
	var s := mi.mesh.get_aabb().size
	mi.scale = Vector3.ONE * minf(1.0, size / maxf(maxf(s.x, s.z), 0.01))
	mi.position = at
	mi.rotation.y = yaw
	mi.visibility_range_end = 40.0
	_bits.add_child(mi)


# --- Saving ------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var p := global_position
	return {"kind": kind, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "bait": bait, "caught": caught.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	var b := String(d.get("bait", ""))
	bait = b if Items.exists(b) else ""
	caught.clear()
	for e in d.get("caught", []):
		if e.has("species") and Creature.SPECIES.has(e.species):
			caught.append({"species": e.species, "at": float(e.get("at", Game.time))})
		elif Items.exists(String(e.get("id", ""))):
			var c := {"id": e.id, "at": float(e.get("at", Game.time))}
			if e.has("n"):
				c.n = int(e.n)
			caught.append(c)
	_refresh()
