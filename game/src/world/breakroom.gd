extends Node3D
## The breakroom outside Lab 4, where the tutorial starts (lab.gd): you come
## down in the elevator on its east wall and step out facing the far wall and
## its "ConCERNing Labs" sign. On your left are the fridge, the sink and the
## coffee pot with a mug beside it, in the middle a table with a stack of
## papers on it, and on your right the door to the lab, locked until you
## have a keycard.
##
## It sits outside the lab's +Z wall, sharing it: the lab door is a gap in
## that wall (lab.gd leaves it), closed by a door that swings into the lab.

const Pickup := preload("res://src/world/pickup.gd")

const WEST := -1.5          # the far wall, with the sign
const EAST := 6.0           # the elevator wall
const NORTH := 5.1          # the lab's wall
const SOUTH := 11.2         # the kitchen wall
const HEIGHT := 3.0
const MID_Z := 8.2          # the elevator and the table are on this line
const CAR := Vector3(6.95, 0.05, 8.2)  # where you stand in the elevator
const CAR_YAW := PI * 0.5   # facing the doors (-X)
const DOOR_X := 3.5         # the lab door, in the lab's wall
const TABLE := Vector3(2.2, 0.0, 8.2)
const COUNTER_Y := 0.9
const POT := Vector3(2.6, COUNTER_Y, 10.85)
const MUG := Vector3(3.2, COUNTER_Y, 10.8)
const DOORS_TIME := 1.4     # the elevator doors sliding open (or shut)

var lab: Node
var elevator_open := false
var lab_door: Node3D
var _doors: Array[Node3D] = []
var _open_t := 0.0
var _open_to := 0.0         # where the doors are sliding: 1 open, 0 shut
var _doorway: StaticBody3D  # shuts you out of the car the moment its doors start to close


class CoffeePot extends StaticBody3D:
	## The coffee maker on the counter: interact with the mug in your hand to
	## pour a coffee.
	var lab: Node

	func prompt(_player: Node) -> String:
		match Game.inventory.held_id():
			"coffee_mug":
				return "Pour a coffee [E]"
			"mug_coffee":
				return "Your mug is full. Drink it first [Right-click]"
		if Game.inventory.count("coffee_mug") > 0:
			return "Coffee pot  (hold your mug to pour: choose its hotbar slot)"
		return "Coffee pot  (you need a mug)"

	func interact(_player: Node) -> void:
		var inv = Game.inventory
		if inv.held_id() != "coffee_mug":
			return
		inv.replace(inv.selected, "mug_coffee")
		Sfx.play("drink", -6.0, 0.15)
		Game.notify("You pour yourself a coffee.")
		Game.crafted.emit("poured_coffee")


class Table extends StaticBody3D:
	## The breakroom table, worked at like a workbench (group "workbenches",
	## scene_base.bench_ahead): you lay the papers on it and read them through.
	var lab: Node
	var hauled_by: Node = null  # never carried, unlike a real workbench

	func _ready() -> void:
		add_to_group("workbenches")

	func prompt(_player: Node) -> String:
		return "Work at the table [C]"

	func interact(_player: Node) -> void:
		lab.start_work()

	func has_tool(_id: String) -> bool:
		return false


class LabDoor extends StaticBody3D:
	## The door into the lab: it opens for anyone carrying a keycard.
	var lab: Node
	var is_open := false
	var light_red: MeshInstance3D
	var light_green: MeshInstance3D
	var _t := 0.0

	func prompt(_player: Node) -> String:
		if is_open:
			return ""
		if Game.inventory.count("keycard_jr") > 0:
			return "Open the lab door with the keycard [E]"
		return "Lab 4  (locked: it needs a keycard)"

	func interact(_player: Node) -> void:
		if is_open:
			return
		if Game.inventory.count("keycard_jr") == 0:
			Sfx.play("click", -4.0)
			Game.notify("The card reader blinks red. You need a keycard.")
			return
		is_open = true
		light_red.visible = false
		light_green.visible = true
		Sfx.play("click", -2.0)
		Sfx.play("creak", -8.0)
		set_process(true)
		lab.check_steps()

	func _ready() -> void:
		set_process(false)

	func _process(delta: float) -> void:
		# Swings into the lab, away from you.
		_t = minf(_t + delta / 1.2, 1.0)
		rotation.y = PI * 0.5 * (1.0 - pow(1.0 - _t, 3.0))
		if _t >= 1.0:
			set_process(false)


func setup(l: Node) -> Node3D:
	lab = l
	return self


func _ready() -> void:
	_build_room()
	_build_elevator()
	_build_kitchen()
	_build_table()
	_build_lab_door()
	_build_sign()
	var mug := Pickup.new().setup("coffee_mug")
	mug.position = MUG
	add_child(mug)
	var papers := Pickup.new().setup("papers")
	papers.position = TABLE + Vector3(-0.1, 0.8, 0.25)
	papers.rotation.y = 0.3
	add_child(papers)


func in_car(p: Vector3) -> bool:
	return p.x > EAST


func out_of_car(p: Vector3) -> bool:
	## Clear of the doorway, so the doors can close behind you.
	return p.x < EAST - 0.6


func in_lab(p: Vector3) -> bool:
	return p.z < NORTH - 0.25


func open_elevator(at_once := false) -> void:
	## The elevator has arrived: a ding and the doors slide apart.
	_open_to = 1.0
	if at_once:
		_open_t = 1.0
		_place_doors()
		elevator_open = true
		return
	Sfx.play("ding", -4.0, 0.0)
	Sfx.play("doors", -6.0, 0.0)


func close_elevator() -> void:
	## You have stepped out: the doors slide shut behind you.
	_open_to = 0.0
	elevator_open = false
	_doorway.collision_layer = 1
	Sfx.play("doors", -8.0, 0.0)


func _process(delta: float) -> void:
	if _open_t == _open_to:
		return
	_open_t = move_toward(_open_t, _open_to, delta / DOORS_TIME)
	_place_doors()
	if _open_t >= 1.0:
		elevator_open = true


func _place_doors() -> void:
	var k := 0.5 - 0.5 * cos(PI * _open_t)
	for i in _doors.size():
		var side := -1.0 if i == 0 else 1.0
		_doors[i].position = Vector3(EAST + 0.15, 1.1, MID_Z + side * (0.4 + 0.82 * k))  # open, hidden in the car's walls


# --- Construction ----------------------------------------------------------------------

func _solid(spec: Array, layer := 1) -> StaticBody3D:
	## A static body of boxes: [[centre, size], ...].
	var body := StaticBody3D.new()
	body.collision_layer = layer
	for s in spec:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		cs.position = s[0]
		body.add_child(cs)
	add_child(body)
	return body


func _mesh(b) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Assets.materials)
	add_child(mi)
	return mi


func _light(at: Vector3, energy: float, reach: float, col := Color(1.0, 0.95, 0.85)) -> void:
	var l := OmniLight3D.new()
	l.position = at
	l.omni_range = reach
	l.light_energy = energy
	l.light_color = col
	l.shadow_enabled = Settings.quality == Settings.Quality.HIGH
	add_child(l)


func _build_room() -> void:
	var b = Assets.builder()
	var w := EAST - WEST
	var d := SOUTH - NORTH
	var cx := (EAST + WEST) * 0.5
	# Linoleum tiles.
	for x in range(int(floor(WEST)), int(ceil(EAST))):
		for z in range(int(floor(NORTH)), int(ceil(SOUTH))):
			var x0 := maxf(x, WEST + 0.1)
			var x1 := minf(x + 1, EAST - 0.1)
			var z0 := maxf(z, NORTH + 0.1)
			var z1 := minf(z + 1, SOUTH - 0.1)
			if x1 <= x0 or z1 <= z0:
				continue
			var c := Color(0.72, 0.68, 0.58) if (x + z) % 2 == 0 else Color(0.58, 0.6, 0.55)
			b.quad(Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1), c)
	var wall := Color(0.78, 0.74, 0.62)
	b.box(Vector3(WEST, HEIGHT * 0.5, MID_Z), Vector3(0.2, HEIGHT, d + 0.2), wall * 0.96)
	b.box(Vector3(cx, HEIGHT * 0.5, SOUTH), Vector3(w + 0.2, HEIGHT, 0.2), wall)
	# Paint on the lab's wall, around the doorway (lab.gd leaves the gap).
	var gap0 := DOOR_X - 0.5
	var gap1 := DOOR_X + 0.5
	b.box(Vector3((WEST + gap0) * 0.5, HEIGHT * 0.5, NORTH + 0.11), Vector3(gap0 - WEST, HEIGHT, 0.02), wall)
	b.box(Vector3((gap1 + EAST) * 0.5, HEIGHT * 0.5, NORTH + 0.11), Vector3(EAST - gap1, HEIGHT, 0.02), wall)
	b.box(Vector3(DOOR_X, (HEIGHT + 2.1) * 0.5, NORTH + 0.11), Vector3(1.0, HEIGHT - 2.1, 0.02), wall)
	# The elevator wall, with the doorway in it.
	b.box(Vector3(EAST, HEIGHT * 0.5, (NORTH + MID_Z - 0.8) * 0.5), Vector3(0.2, HEIGHT, MID_Z - 0.8 - NORTH), wall * 0.92)
	b.box(Vector3(EAST, HEIGHT * 0.5, (SOUTH + MID_Z + 0.8) * 0.5), Vector3(0.2, HEIGHT, SOUTH - MID_Z - 0.8), wall * 0.92)
	b.box(Vector3(EAST, (HEIGHT + 2.2) * 0.5, MID_Z), Vector3(0.2, HEIGHT - 2.2, 1.6), wall * 0.92)
	var steel := Color(0.62, 0.64, 0.66)
	b.box(Vector3(EAST - 0.11, 1.1, MID_Z - 0.84), Vector3(0.04, 2.2, 0.08), steel, Basis(), "metal")
	b.box(Vector3(EAST - 0.11, 1.1, MID_Z + 0.84), Vector3(0.04, 2.2, 0.08), steel, Basis(), "metal")
	b.box(Vector3(EAST - 0.11, 2.24, MID_Z), Vector3(0.04, 0.08, 1.76), steel, Basis(), "metal")
	b.box(Vector3(EAST - 0.11, 1.2, MID_Z + 1.1), Vector3(0.03, 0.22, 0.1), Color(0.3, 0.3, 0.32))  # call button
	# Skirting and ceiling.
	b.box(Vector3(WEST + 0.11, 0.06, MID_Z), Vector3(0.02, 0.12, d), Color(0.3, 0.27, 0.22))
	b.box(Vector3(cx, 0.06, SOUTH - 0.11), Vector3(w, 0.12, 0.02), Color(0.3, 0.27, 0.22))
	b.box(Vector3(cx, HEIGHT + 0.05, MID_Z), Vector3(w + 0.2, 0.1, d + 0.2), Color(0.85, 0.85, 0.82))
	# A notice board by the lab door, pinned with memos.
	b.box(Vector3(1.4, 1.6, NORTH + 0.13), Vector3(1.4, 0.9, 0.03), Color(0.6, 0.45, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in 6:
		var at := Vector3(0.9 + (i % 3) * 0.45 + rng.randf_range(-0.08, 0.08), 1.38 + (i / 3) * 0.42 + rng.randf_range(-0.05, 0.05), NORTH + 0.15)
		b.box(at, Vector3(0.24, 0.3, 0.005), Color(0.95, 0.94, 0.88) if i % 2 == 0 else Color(0.95, 0.9, 0.55), Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15)))
	_mesh(b)

	var g = Assets.builder()
	for x in [0.6, 4.2]:
		g.box(Vector3(x, HEIGHT - 0.02, MID_Z), Vector3(1.2, 0.03, 0.35), Color(1.0, 0.97, 0.9), Basis(), "glow")
	_mesh(g)
	_light(Vector3(0.6, HEIGHT - 0.4, MID_Z), 1.1, 7.0)
	_light(Vector3(4.2, HEIGHT - 0.4, MID_Z), 1.1, 7.0)

	_solid([
		[Vector3((WEST + EAST + 2.0) * 0.5, -0.1, MID_Z), Vector3(EAST + 2.0 - WEST, 0.2, d + 0.4)],
		[Vector3(cx, HEIGHT + 0.1, MID_Z), Vector3(w + 0.2, 0.2, d + 0.4)],
		[Vector3(WEST, HEIGHT * 0.5, MID_Z), Vector3(0.2, HEIGHT, d + 0.4)],
		[Vector3(cx, HEIGHT * 0.5, SOUTH), Vector3(w + 0.2, HEIGHT, 0.2)],
		[Vector3(EAST, HEIGHT * 0.5, (NORTH + MID_Z - 0.8) * 0.5), Vector3(0.2, HEIGHT, MID_Z - 0.8 - NORTH)],
		[Vector3(EAST, HEIGHT * 0.5, (SOUTH + MID_Z + 0.8) * 0.5), Vector3(0.2, HEIGHT, SOUTH - MID_Z - 0.8)],
		[Vector3(EAST, (HEIGHT + 2.2) * 0.5, MID_Z), Vector3(0.2, HEIGHT - 2.2, 1.6)],
	])


func _build_elevator() -> void:
	# The car: steel walls, a handrail, buttons and a light.
	var b = Assets.builder()
	var steel := Color(0.66, 0.68, 0.7)
	var back := EAST + 1.8
	b.box(Vector3(EAST + 0.9, 0.005, MID_Z), Vector3(1.6, 0.01, 1.6), Color(0.2, 0.2, 0.22))
	b.box(Vector3(back, 1.2, MID_Z), Vector3(0.2, 2.4, 1.8), steel, Basis(), "metal")
	b.box(Vector3(EAST + 0.95, 1.2, MID_Z - 0.9), Vector3(1.7, 2.4, 0.2), steel * 0.95, Basis(), "metal")
	b.box(Vector3(EAST + 0.95, 1.2, MID_Z + 0.9), Vector3(1.7, 2.4, 0.2), steel * 0.95, Basis(), "metal")
	b.box(Vector3(EAST + 0.9, 2.45, MID_Z), Vector3(1.8, 0.1, 1.8), Color(0.5, 0.5, 0.52))
	b.cylinder(Vector3(back - 0.16, 0.95, MID_Z - 0.6), Vector3(back - 0.16, 0.95, MID_Z + 0.6), 0.02, 0.02, 6, Color(0.8, 0.8, 0.82), Color(-1, 0, 0), "metal")
	b.box(Vector3(EAST + 0.4, 1.25, MID_Z + 0.79), Vector3(0.22, 0.5, 0.02), Color(0.25, 0.25, 0.27))
	var mi := _mesh(b)
	mi.name = "Car"
	var g = Assets.builder()
	g.box(Vector3(EAST + 0.9, 2.39, MID_Z), Vector3(1.0, 0.02, 1.0), Color(1.0, 0.96, 0.85), Basis(), "glow")
	for i in 5:
		var lit := i == 4
		g.box(Vector3(EAST + 0.4, 1.06 + i * 0.09, MID_Z + 0.775), Vector3(0.05, 0.05, 0.01),
				Color(1.0, 0.7, 0.25) if lit else Color(0.75, 0.75, 0.7), Basis(), "glow" if lit else "solid")
	_mesh(g)
	# Where the car is: down, to the lab level.
	var floor_sign := Label3D.new()
	floor_sign.text = "B4"
	floor_sign.font_size = 64
	floor_sign.pixel_size = 0.0012
	floor_sign.modulate = Color(1.0, 0.55, 0.2)
	floor_sign.position = Vector3(EAST + 0.13, 2.3, MID_Z)
	floor_sign.rotation.y = PI * 0.5
	add_child(floor_sign)
	_light(Vector3(EAST + 1.1, 2.3, MID_Z), 0.5, 3.0)
	_solid([
		[Vector3(back, 1.2, MID_Z), Vector3(0.2, 2.4, 1.8)],
		[Vector3(EAST + 0.95, 1.2, MID_Z - 0.9), Vector3(1.7, 2.4, 0.2)],
		[Vector3(EAST + 0.95, 1.2, MID_Z + 0.9), Vector3(1.7, 2.4, 0.2)],
		[Vector3(EAST + 0.9, 2.5, MID_Z), Vector3(1.8, 0.1, 1.8)],
	])
	_doorway = _solid([[Vector3(EAST + 0.15, 1.1, MID_Z), Vector3(0.1, 2.2, 1.7)]], 0)
	# The doors, sliding apart into the walls.
	for i in 2:
		var door := StaticBody3D.new()
		door.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.05, 2.2, 0.8)
		cs.shape = bs
		door.add_child(cs)
		var db = Assets.builder()
		db.box(Vector3.ZERO, Vector3(0.05, 2.2, 0.8), Color(0.62, 0.64, 0.66))  # matte: metal shows a hot spot from the car light
		db.box(Vector3(0, 0, 0.4 * (1 if i == 0 else -1)), Vector3(0.06, 2.2, 0.012), Color(0.35, 0.36, 0.38))
		var dm := MeshInstance3D.new()
		dm.mesh = db.commit(Assets.materials)
		door.add_child(dm)
		add_child(door)
		_doors.append(door)
	_place_doors()


func _build_kitchen() -> void:
	# Along the south wall, on your left out of the elevator: the fridge in
	# the corner, then a counter with the sink and the coffee pot.
	var b = Assets.builder()
	var counter_x0 := -0.3
	var counter_x1 := 4.2
	var cz := SOUTH - 0.4
	var cx := (counter_x0 + counter_x1) * 0.5
	b.box(Vector3(cx, COUNTER_Y * 0.5 - 0.02, cz), Vector3(counter_x1 - counter_x0, COUNTER_Y - 0.04, 0.6), Color(0.45, 0.5, 0.55))
	b.box(Vector3(cx, COUNTER_Y - 0.02, cz - 0.01), Vector3(counter_x1 - counter_x0 + 0.04, 0.04, 0.64), Color(0.82, 0.8, 0.76))
	for i in 5:
		var x := counter_x0 + 0.45 + i * 0.9
		b.box(Vector3(x, 0.5, cz - 0.305), Vector3(0.84, 0.72, 0.01), Color(0.5, 0.55, 0.6))
		b.box(Vector3(x + 0.3, 0.7, cz - 0.315), Vector3(0.12, 0.02, 0.02), Color(0.8, 0.8, 0.82), Basis(), "metal")
	# Wall cupboards.
	b.box(Vector3(cx, 2.15, SOUTH - 0.27), Vector3(counter_x1 - counter_x0, 0.7, 0.34), Color(0.5, 0.55, 0.6))
	# The sink: a steel basin let into the counter, with a tap.
	var sx := 1.0
	b.box(Vector3(sx, COUNTER_Y + 0.001, cz), Vector3(0.6, 0.002, 0.42), Color(0.6, 0.62, 0.64), Basis(), "metal")
	b.box(Vector3(sx, COUNTER_Y + 0.003, cz), Vector3(0.5, 0.002, 0.34), Color(0.3, 0.32, 0.34), Basis(), "metal")
	b.tube([Vector3(sx, COUNTER_Y, cz + 0.26), Vector3(sx, COUNTER_Y + 0.3, cz + 0.26), Vector3(sx, COUNTER_Y + 0.33, cz + 0.12), Vector3(sx, COUNTER_Y + 0.25, cz + 0.06)],
			[0.018, 0.018, 0.016, 0.014], 6, [Color(0.8, 0.8, 0.82)], "metal")
	# The fridge, a magnet holding a note to its door.
	var fx := -0.95
	b.box(Vector3(fx, 0.9, SOUTH - 0.42), Vector3(0.85, 1.8, 0.64), Color(0.9, 0.9, 0.87))
	b.box(Vector3(fx, 1.25, SOUTH - 0.745), Vector3(0.84, 0.01, 0.02), Color(0.6, 0.6, 0.6))
	b.box(Vector3(fx + 0.33, 1.5, SOUTH - 0.77), Vector3(0.03, 0.3, 0.04), Color(0.7, 0.7, 0.72), Basis(), "metal")
	b.box(Vector3(fx + 0.33, 0.8, SOUTH - 0.77), Vector3(0.03, 0.3, 0.04), Color(0.7, 0.7, 0.72), Basis(), "metal")
	b.box(Vector3(fx - 0.1, 1.55, SOUTH - 0.745), Vector3(0.2, 0.25, 0.004), Color(0.97, 0.95, 0.6), Basis(Vector3.BACK, 0.1))
	# The coffee maker: a black base and hood, a glass jug of coffee, a red light.
	var p := POT
	b.box(p + Vector3(0, 0.02, 0), Vector3(0.28, 0.04, 0.26), Color(0.1, 0.1, 0.11))
	b.box(p + Vector3(0, 0.2, 0.09), Vector3(0.28, 0.4, 0.08), Color(0.1, 0.1, 0.11))
	b.box(p + Vector3(0, 0.37, 0.0), Vector3(0.28, 0.06, 0.26), Color(0.12, 0.12, 0.13))
	b.cylinder(p + Vector3(0, 0.04, -0.02), p + Vector3(0, 0.14, -0.02), 0.085, 0.085, 12, Color(0.22, 0.12, 0.06))
	b.cylinder(p + Vector3(0, 0.14, -0.02), p + Vector3(0, 0.26, -0.02), 0.085, 0.06, 12, Color(0.55, 0.62, 0.66), Color(-1, 0, 0), "metal")
	b.tube([p + Vector3(0.085, 0.22, -0.02), p + Vector3(0.13, 0.2, -0.02), p + Vector3(0.12, 0.08, -0.02), p + Vector3(0.08, 0.07, -0.02)],
			[0.012, 0.012, 0.012, 0.012], 5, [Color(0.1, 0.1, 0.11)])
	_mesh(b)
	var g = Assets.builder()
	g.box(p + Vector3(0.1, 0.03, -0.131), Vector3(0.025, 0.015, 0.004), Color(1.0, 0.2, 0.1), Basis(), "glow")
	_mesh(g)
	_solid([
		[Vector3(cx, COUNTER_Y * 0.5, cz), Vector3(counter_x1 - counter_x0, COUNTER_Y, 0.6)],
		[Vector3(fx, 0.9, SOUTH - 0.42), Vector3(0.85, 1.8, 0.64)],
	])
	var pot := CoffeePot.new()
	pot.lab = lab
	pot.collision_layer = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.32, 0.42, 0.3)
	cs.shape = bs
	pot.add_child(cs)
	pot.position = p + Vector3(0, 0.21, 0)
	add_child(pot)


func _build_table() -> void:
	# The table, long along Z, worked at from its east side (its front: it
	# is turned so its local +Z faces east, toward the elevator).
	var b = Assets.builder()
	var top := 0.8
	var t := TABLE
	b.box(t + Vector3(0, top - 0.025, 0), Vector3(0.9, 0.05, 1.6), Color(0.6, 0.5, 0.38), Basis(), "wood")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(t + Vector3(sx * 0.38, (top - 0.05) * 0.5, sz * 0.72), Vector3(0.05, top - 0.05, 0.05), Color(0.3, 0.3, 0.32), Basis(), "metal")
	var chairs := [[t + Vector3(-0.75, 0, -0.4), 0.0], [t + Vector3(-0.75, 0, 0.4), 0.0], [t + Vector3(0, 0, -1.05), -PI * 0.5], [t + Vector3(0, 0, 1.05), PI * 0.5]]
	var spec := []
	for c in chairs:
		var at: Vector3 = c[0]
		var basis := Basis(Vector3.UP, c[1])
		b.box(at + Vector3(0, 0.45, 0), Vector3(0.44, 0.04, 0.44), Color(0.25, 0.4, 0.6), basis)
		b.box(at + basis * Vector3(-0.2, 0.72, 0), Vector3(0.04, 0.5, 0.42), Color(0.25, 0.4, 0.6), basis)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				b.box(at + basis * Vector3(sx * 0.19, 0.22, sz * 0.19), Vector3(0.03, 0.44, 0.03), Color(0.3, 0.3, 0.32), basis, "metal")
		spec.append([at + Vector3(0, 0.45, 0), Vector3(0.44, 0.9, 0.44)])
	_mesh(b)
	_solid(spec)
	var table := Table.new()
	table.lab = lab
	table.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, top, 0.9)
	cs.shape = bs
	cs.position = Vector3(0, top * 0.5, 0)
	table.add_child(cs)
	table.position = t
	table.rotation.y = PI * 0.5
	add_child(table)


func _build_lab_door() -> void:
	# Hinged at its west edge, in the gap lab.gd leaves in its wall.
	var door := LabDoor.new()
	door.lab = lab
	door.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 2.1, 0.08)
	cs.shape = bs
	cs.position = Vector3(0.5, 1.05, 0)
	door.add_child(cs)
	var b = Assets.builder()
	b.box(Vector3(0.5, 1.05, 0), Vector3(1.0, 2.1, 0.06), Color(0.35, 0.4, 0.5))
	b.box(Vector3(0.5, 1.5, 0.035), Vector3(0.62, 0.42, 0.01), Color(0.12, 0.16, 0.22))
	b.box(Vector3(0.88, 1.0, 0.06), Vector3(0.14, 0.03, 0.04), Color(0.75, 0.75, 0.78), Basis(), "metal")
	var dm := MeshInstance3D.new()
	dm.mesh = b.commit(Assets.materials)
	door.add_child(dm)
	door.position = Vector3(DOOR_X - 0.5, 0, NORTH)
	add_child(door)
	lab_door = door
	# A sign on it and a card reader beside it, red until it lets you in.
	for line in [["LAB 4", 1.6, 0.0032], ["AUTHORISED\nSTAFF ONLY", 1.42, 0.0017]]:
		var label := Label3D.new()
		label.text = line[0]
		label.font_size = 40
		label.pixel_size = line[2]
		label.modulate = Color(0.95, 0.95, 0.9)
		label.position = Vector3(0.5, line[1], 0.045)
		door.add_child(label)
	var r = Assets.builder()
	r.box(Vector3(DOOR_X + 0.75, 1.2, NORTH + 0.14), Vector3(0.12, 0.18, 0.04), Color(0.15, 0.15, 0.17))
	_mesh(r)
	var lights := []
	for col in [Color(1.0, 0.15, 0.1), Color(0.2, 1.0, 0.3)]:
		var lb = Assets.builder()
		lb.box(Vector3(DOOR_X + 0.75, 1.26, NORTH + 0.162), Vector3(0.04, 0.02, 0.005), col, Basis(), "glow")
		lights.append(_mesh(lb))
	door.light_red = lights[0]
	door.light_green = lights[1]
	door.light_green.visible = false
	# The frame around the doorway.
	var f = Assets.builder()
	var frame := Color(0.3, 0.32, 0.36)
	f.box(Vector3(DOOR_X - 0.54, 1.07, NORTH + 0.12), Vector3(0.08, 2.14, 0.04), frame)
	f.box(Vector3(DOOR_X + 0.54, 1.07, NORTH + 0.12), Vector3(0.08, 2.14, 0.04), frame)
	f.box(Vector3(DOOR_X, 2.14, NORTH + 0.12), Vector3(1.16, 0.08, 0.04), frame)
	_mesh(f)


func _build_sign() -> void:
	# On the far wall, the first thing you see as the elevator opens.
	var plaque = Assets.builder()
	plaque.box(Vector3(WEST + 0.13, 1.95, MID_Z), Vector3(0.04, 1.0, 4.6), Color(0.12, 0.16, 0.3))
	plaque.box(Vector3(WEST + 0.155, 1.95, MID_Z), Vector3(0.01, 0.86, 4.46), Color(0.16, 0.22, 0.4))
	_mesh(plaque)
	var ring = Assets.builder()
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		var c := Vector3(WEST + 0.17, 1.95, MID_Z - 1.8)
		ring.cylinder(c + Vector3(0, sin(a0), cos(a0)) * 0.28, c + Vector3(0, sin(a1), cos(a1)) * 0.28, 0.035, 0.035, 5,
				Color(0.5, 0.8, 1.0), Color(-1, 0, 0), "glow", false)
	_mesh(ring)
	var sign := Label3D.new()
	sign.text = "ConCERNing Labs"
	sign.font_size = 160
	sign.outline_size = 0
	sign.pixel_size = 0.0024
	sign.modulate = Color(0.92, 0.95, 1.0)
	sign.position = Vector3(WEST + 0.17, 1.95, MID_Z + 0.35)
	sign.rotation.y = PI * 0.5
	add_child(sign)
