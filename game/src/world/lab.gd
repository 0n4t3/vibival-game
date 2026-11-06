extends "res://src/world/scene_base.gd"
## Tutorial: a physics lab at night. It opens with the ride down in the
## elevator (elevator_intro.gd) to the breakroom outside the lab
## (breakroom.gd): two coffees teach picking things up, holding them, using
## them on something and drinking, and reading through a stack of papers at
## the table (laying them out, then "crafting" a page at a time) turns up a
## keycard for the lab door. In the lab the scientist gathers parts, crafts
## the final accelerator components, installs them and switches the machine
## on. Teaches movement, pickup, inventory, crafting and the hotbar.

const Breakroom := preload("res://src/world/breakroom.gd")
const ElevatorIntro := preload("res://src/world/elevator_intro.gd")

const RING_R := 2.6
const RING_Y := 1.15
const RING_CENTER := Vector3(0, 0, -1.5)
const RING_STEPS := 24

const REQUIRED := {"beam_pipe": 2, "magnet_coil": 4, "control_board": 1, "copper_wire": 1, "power_cell": 1}

var step := "ride"
var breakroom: Node3D
var coffees := 0          # drunk in the breakroom
var _intro: CanvasLayer = null
var _riding := true       # still in the elevator (its music plays)
var installed := {}       # mount name -> true
var _start_pos := Vector3.ZERO
var _lights: Array[OmniLight3D] = []
var _ring_glow: MeshInstance3D
var _hum: AudioStreamPlayer
var _sequence := false
var _seq_t := 0.0


class Mount extends StaticBody3D:
	## A gap on the accelerator that accepts one specific part.
	var lab: Node
	var mount_name := ""
	var needs := ""
	var filled: MeshInstance3D
	var marker: MeshInstance3D

	func prompt(_player: Node) -> String:
		if lab.installed.has(mount_name):
			return ""
		if Game.inventory.held_id() == needs:
			return "Install %s [E]" % Items.item_name(needs)
		return "Needs: %s  (hold it in your hotbar)" % Items.item_name(needs)

	func interact(_player: Node) -> void:
		if lab.installed.has(mount_name) or Game.inventory.held_id() != needs:
			return
		Game.inventory.take(Game.inventory.selected, 1)
		lab.installed[mount_name] = true
		filled.visible = true
		marker.visible = false
		Sfx.play("craft", -2.0)
		Game.notify("Installed %s." % Items.item_name(needs))
		lab.check_steps()


class Console extends StaticBody3D:
	var lab: Node

	func prompt(_player: Node) -> String:
		if lab.installed.size() < 3:
			return "Accelerator control  (%d/3 components installed)" % lab.installed.size()
		return "" if lab._sequence else "Start the accelerator [E]"

	func interact(_player: Node) -> void:
		if lab.installed.size() >= 3 and not lab._sequence:
			lab.start_sequence()


func _ready() -> void:
	where = "lab"
	Game.inventory.capacity_override = 100.0  # lab parts are carried on a trolley
	_build_room()
	_build_accelerator()
	_place_parts()
	breakroom = Breakroom.new().setup(self)
	add_child(breakroom)
	_start_pos = Breakroom.CAR
	setup_common(_start_pos, false)
	player.rotation.y = Breakroom.CAR_YAW
	Game.picked.connect(func(_id): check_steps())
	Game.crafted.connect(_on_crafted)
	Game.inventory.changed.connect(_update_objectives)
	hud.set_fade(Color(0, 0, 0, 1))
	_set_step("ride")
	if not Game.dev.has("start") or Game.dev.has("intro"):
		_intro = ElevatorIntro.new().setup(self)
		add_child(_intro)
	else:
		# Dev starts skip the ride (unless --intro): the doors are open.
		hud.fade_to(Color(0, 0, 0, 0), 1.0)
		breakroom.open_elevator(true)
		Music.elevator(true)
		intro_done()


func ground_height(_x: float, _z: float) -> float:
	return 0.0


# --- Construction -------------------------------------------------------------------

func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.6)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var b = Assets.builder()
	# Tiled floor
	for x in range(-6, 6):
		for z in range(-7, 5):
			var c := Color(0.42, 0.44, 0.46) if (x + z) % 2 == 0 else Color(0.36, 0.38, 0.40)
			b.quad(Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, 0, z + 1), Vector3(x, 0, z + 1), c)
	var wall := Color(0.62, 0.64, 0.6)
	b.box(Vector3(0, 1.8, -7.1), Vector3(12.4, 3.6, 0.2), wall)
	for spec in _door_wall():
		b.box(spec[0], spec[1], wall)
	b.box(Vector3(-6.1, 1.8, -1), Vector3(0.2, 3.6, 12.4), wall * 0.95)
	b.box(Vector3(6.1, 1.8, -1), Vector3(0.2, 3.6, 12.4), wall * 0.95)
	b.box(Vector3(0, 3.65, -1), Vector3(12.4, 0.1, 12.4), Color(0.5, 0.5, 0.5))
	b.box(Vector3(0, 0.08, -7.0), Vector3(12, 0.16, 0.05), Color(0.2, 0.2, 0.22))
	# Window to the night
	b.box(Vector3(-6.0, 1.9, 1.5), Vector3(0.05, 1.2, 2.2), Color(0.04, 0.06, 0.14))
	# Benches
	for spec in [[Vector3(-4.6, 0, 2.0), Vector3(1.2, 0.9, 3.0)], [Vector3(4.6, 0, 2.0), Vector3(1.2, 0.9, 3.0)], [Vector3(4.6, 0, -4.8), Vector3(1.2, 0.9, 2.6)]]:
		_bench(b, spec[0], spec[1])
	# Shelves on the back wall
	for i in 3:
		b.box(Vector3(-4.0, 0.6 + i * 0.7, -6.75), Vector3(2.6, 0.05, 0.5), Color(0.55, 0.5, 0.42))
	b.box(Vector3(-5.3, 1.3, -6.75), Vector3(0.05, 2.6, 0.5), Color(0.4, 0.4, 0.42))
	b.box(Vector3(-2.7, 1.3, -6.75), Vector3(0.05, 2.6, 0.5), Color(0.4, 0.4, 0.42))
	# Cabinet and whiteboard
	b.box(Vector3(-5.6, 0.9, -4.0), Vector3(0.8, 1.8, 1.2), Color(0.45, 0.5, 0.55))
	b.box(Vector3(6.0, 1.7, -1.5), Vector3(0.05, 1.2, 2.6), Color(0.92, 0.92, 0.9))
	for i in 6:
		b.box(Vector3(5.97, 1.4 + (i % 3) * 0.3, -2.5 + i * 0.35), Vector3(0.01, 0.03, 0.25), Color(0.15, 0.2, 0.6))
	# Console desk
	b.box(Vector3(2.4, 0.45, 2.6), Vector3(1.6, 0.9, 0.8), Color(0.3, 0.32, 0.36))
	b.box(Vector3(2.4, 1.25, 2.85), Vector3(1.2, 0.7, 0.08), Color(0.1, 0.1, 0.12))
	var mesh := MeshInstance3D.new()
	mesh.mesh = b.commit(Assets.materials)
	add_child(mesh)

	var g = Assets.builder()
	g.box(Vector3(2.4, 1.25, 2.8), Vector3(1.05, 0.55, 0.02), Color(0.2, 0.55, 0.85), Basis(), "glow")
	for p in [Vector3(-2.5, 3.58, -1.0), Vector3(2.5, 3.58, -1.0), Vector3(0.0, 3.58, 3.5)]:
		g.box(p, Vector3(1.2, 0.04, 0.4), Color(0.95, 0.97, 1.0), Basis(), "glow")
	var glow := MeshInstance3D.new()
	glow.mesh = g.commit(Assets.materials)
	add_child(glow)

	for p in [Vector3(-2.5, 3.2, -1.0), Vector3(2.5, 3.2, -1.0), Vector3(0.0, 3.2, 3.5)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 10.0
		l.light_energy = 1.3
		l.light_color = Color(0.92, 0.96, 1.0)
		l.shadow_enabled = Settings.quality == Settings.Quality.HIGH
		add_child(l)
		_lights.append(l)

	# Collision: floor, walls, furniture, the ring dais.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	for spec in [
		[Vector3(0, -0.1, -1), Vector3(12.4, 0.2, 12.4)],
		[Vector3(0, 1.8, -7.1), Vector3(12.4, 3.6, 0.2)],
		[Vector3(-6.1, 1.8, -1), Vector3(0.2, 3.6, 12.4)], [Vector3(6.1, 1.8, -1), Vector3(0.2, 3.6, 12.4)],
		[Vector3(0, 3.7, -1), Vector3(12.4, 0.2, 12.4)],
		[Vector3(-4.6, 0.45, 2.0), Vector3(1.2, 0.9, 3.0)], [Vector3(4.6, 0.45, 2.0), Vector3(1.2, 0.9, 3.0)],
		[Vector3(4.6, 0.45, -4.8), Vector3(1.2, 0.9, 2.6)], [Vector3(-4.0, 1.3, -6.75), Vector3(2.6, 2.6, 0.5)],
		[Vector3(-5.6, 0.9, -4.0), Vector3(0.8, 1.8, 1.2)], [Vector3(2.4, 0.45, 2.6), Vector3(1.6, 0.9, 0.8)],
	] + _door_wall():
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[1]
		cs.shape = bs
		cs.position = spec[0]
		body.add_child(cs)
	# The ring dais blocks walking (layer 3) but not interaction rays, so the
	# mounts on the ring stay reachable.
	var dais_body := StaticBody3D.new()
	dais_body.collision_layer = 4
	add_child(dais_body)
	var dais := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RING_R + 0.45
	cyl.height = 2.0
	dais.shape = cyl
	dais.position = RING_CENTER + Vector3(0, 1.0, 0)
	dais_body.add_child(dais)

	var console := Console.new()
	console.lab = self
	console.collision_layer = 2
	var ccs := CollisionShape3D.new()
	var cbs := BoxShape3D.new()
	cbs.size = Vector3(1.3, 0.8, 0.3)
	ccs.shape = cbs
	console.add_child(ccs)
	console.position = Vector3(2.4, 1.25, 2.75)
	add_child(console)


func _door_wall() -> Array:
	## The wall onto the breakroom, either side of and over the lab door
	## (breakroom.gd hangs the door in the gap): [[centre, size], ...].
	var x0 := Breakroom.DOOR_X - 0.5
	var x1 := Breakroom.DOOR_X + 0.5
	return [
		[Vector3((-6.2 + x0) * 0.5, 1.8, 5.1), Vector3(x0 + 6.2, 3.6, 0.2)],
		[Vector3((x1 + 6.2) * 0.5, 1.8, 5.1), Vector3(6.2 - x1, 3.6, 0.2)],
		[Vector3(Breakroom.DOOR_X, 2.85, 5.1), Vector3(1.0, 1.5, 0.2)],
	]


func _bench(b, base: Vector3, size: Vector3) -> void:
	b.box(base + Vector3(0, size.y - 0.04, 0), Vector3(size.x, 0.08, size.z), Color(0.5, 0.44, 0.36))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			b.box(base + Vector3(sx * (size.x * 0.5 - 0.08), (size.y - 0.08) * 0.5, sz * (size.z * 0.5 - 0.08)),
				Vector3(0.06, size.y - 0.08, 0.06), Color(0.3, 0.3, 0.32))


func _build_accelerator() -> void:
	var b = Assets.builder()
	var steel := Color(0.72, 0.74, 0.78)
	var c := RING_CENTER
	b.cylinder(c, c + Vector3(0, 0.3, 0), RING_R + 0.4, RING_R + 0.4, 24, Color(0.5, 0.52, 0.55))
	var n := RING_STEPS
	var gaps := [8, 16]  # beam segment mounts (left and back-right of the ring)
	# The pipe bends round in one tube between each pair of mounts, with a
	# flange where it meets a beam segment, so its joints have no seams.
	for gi in gaps.size():
		var from: int = gaps[gi] + 2
		var to: int = gaps[(gi + 1) % gaps.size()]
		if to < from:
			to += n
		var arc := _ring_arc(from, to)
		b.tube(arc, _radii(arc, 0.12), 8, [steel], "metal")
		for step_at in [from, to]:
			var a: float = TAU * step_at / n
			var along := Vector3(-sin(a), 0, cos(a)) * 0.04
			var at := c + Vector3(cos(a) * RING_R, RING_Y, sin(a) * RING_R)
			b.cylinder(at - along, at + along, 0.17, 0.17, 12, Color(0.55, 0.57, 0.6), Color(-1, 0, 0), "metal")
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector3(cos(a0) * RING_R, RING_Y, sin(a0) * RING_R)
		var p1 := c + Vector3(cos(a1) * RING_R, RING_Y, sin(a1) * RING_R)
		if i in gaps or i - 1 in gaps:
			continue
		if i % 3 == 0:
			var mid := (p0 + p1) * 0.5
			b.box(mid, Vector3(0.45, 0.45, 0.45), Color(0.8, 0.45, 0.2), Basis(Vector3.UP, -a0))
		if i % 4 == 0:
			b.cylinder(Vector3(p0.x, 0.3, p0.z), p0, 0.06, 0.06, 6, Color(0.35, 0.35, 0.38))
	# Injector line running out to the port on the +X side.
	b.cylinder(c + Vector3(RING_R, RING_Y, 0), c + Vector3(RING_R + 1.1, RING_Y, 0), 0.1, 0.1, 8, steel, steel, "metal")
	b.box(c + Vector3(RING_R + 1.35, RING_Y * 0.5, 0), Vector3(0.6, RING_Y - 0.3, 0.6), Color(0.3, 0.32, 0.35))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Assets.materials)
	add_child(mi)

	# Ring glow for the activation sequence.
	var gb = Assets.builder()
	var loop := _ring_arc(0, n)
	gb.tube(loop, _radii(loop, 0.15), 6, [Color(0.6, 0.85, 1.0)], "glow")
	_ring_glow = MeshInstance3D.new()
	_ring_glow.mesh = gb.commit(Assets.materials)
	_ring_glow.visible = false
	add_child(_ring_glow)

	for gi in gaps.size():
		var a: float = TAU * (gaps[gi] + 1) / n
		var pos := c + Vector3(cos(a) * RING_R, RING_Y, sin(a) * RING_R)
		_mount("beam_%d" % gi, "beam_segment", pos, Basis(Vector3.UP, -a))
	_mount("injector", "injector", c + Vector3(RING_R + 1.35, RING_Y + 0.15, 0), Basis(Vector3.UP, PI * 0.5))


func _ring_arc(from_step: float, to_step: float) -> Array:
	## Points along the beam pipe's centre line, four to a ring step.
	var pts := []
	var count := int(round((to_step - from_step) * 4.0))
	for k in count + 1:
		var a := TAU * lerpf(from_step, to_step, float(k) / count) / RING_STEPS
		pts.append(RING_CENTER + Vector3(cos(a) * RING_R, RING_Y, sin(a) * RING_R))
	return pts


func _radii(pts: Array, r: float) -> Array:
	var out := []
	out.resize(pts.size())
	out.fill(r)
	return out


func _mount(mount_name: String, needs: String, pos: Vector3, basis: Basis) -> void:
	var m := Mount.new()
	m.lab = self
	m.mount_name = mount_name
	m.needs = needs
	m.collision_layer = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.8, 0.8, 0.8)
	cs.shape = bs
	m.add_child(cs)
	var fb = Assets.builder()
	if needs == "beam_segment":
		# Bent to the ring, filling the gap between its two flanges.
		var mid := atan2(pos.z - RING_CENTER.z, pos.x - RING_CENTER.x) / TAU * RING_STEPS
		var inv := basis.inverse()
		var arc := _ring_arc(mid - 1.0, mid + 1.0).map(func(p): return inv * (p - pos))
		fb.tube(arc, _radii(arc, 0.12), 8, [Color(0.72, 0.74, 0.78)], "metal")
		fb.box(Vector3.ZERO, Vector3(0.45, 0.45, 0.45), Color(0.8, 0.5, 0.25))
	else:
		fb.box(Vector3.ZERO, Vector3(0.5, 0.6, 0.5), Color(0.35, 0.6, 0.9))
		fb.cylinder(Vector3(0, 0, -0.3), Vector3(0, 0, -0.5), 0.1, 0.1, 8, Color(0.72, 0.74, 0.78))
	m.filled = MeshInstance3D.new()
	m.filled.mesh = fb.commit(Assets.materials)
	m.filled.visible = false
	m.add_child(m.filled)
	var mb = Assets.builder()
	mb.box(Vector3.ZERO, Vector3(0.12, 0.12, 0.12), Color(1.0, 0.85, 0.2), Basis(Vector3(1, 1, 0).normalized(), 0.8), "glow")
	m.marker = MeshInstance3D.new()
	m.marker.mesh = mb.commit(Assets.materials)
	m.add_child(m.marker)
	m.position = pos
	m.basis = basis
	add_child(m)


func _place_parts() -> void:
	var spots := [
		["beam_pipe", Vector3(-4.6, 0.9, 1.2)], ["beam_pipe", Vector3(-4.6, 0.9, 2.6)],
		["magnet_coil", Vector3(-4.6, 1.31, -6.7)], ["magnet_coil", Vector3(-3.6, 1.31, -6.7)],
		["magnet_coil", Vector3(4.4, 0.9, -5.3)], ["magnet_coil", Vector3(4.8, 0.9, -4.4)],
		["copper_wire", Vector3(-4.2, 0.61, -6.7)],
		["control_board", Vector3(4.6, 0.9, 2.2)],
		["power_cell", Vector3(-5.5, 0.0, -2.9)],
	]
	for s in spots:
		var p := Pickup.new().setup(s[0])
		p.position = s[1]
		p.rotation.y = randf() * TAU
		add_child(p)


# --- Tutorial flow -------------------------------------------------------------------

const HINTS := {
	"ride": "",
	"move": "Press [W] to step out of the elevator, before your ears start to bleed.",
	"mug": "First, coffee. The coffee pot is on the counter to your left: look at the mug beside it and pick it up [E].",
	"pour": "Hold the mug (choose its hotbar slot, keys 1-6), look at the coffee pot and pour yourself a coffee [E].",
	"drink": "Now drink it [Right-click]. Anything you can eat or drink is used the same way.",
	"pour2": "It's second shift, pour yourself another for good measure.",
	"drink2": "Drink up [Right-click].",
	"papers": "Your keycard is gone. You must have dropped it somewhere, and the lab door won't open without one. Maybe somebody else left theirs lying around? Have a look through the papers on the table: pick them up [E].",
	"lay": "Look at the table and press C to work at it. Click the Papers in the tray to lay them on the table, then choose Read the papers.",
	"read": "Read through the stack: click the page to turn it over.",
	"door": "\"Wait, that's the head engineer's handwriting. I hope he didn't get mud on any of the accelerator parts, that could go badly. At least I can get into the lab now.\"\nOpen the lab door, on your right, with the keycard [E].",
	"enter": "Go into the lab.",
	"pickup": "Parts for the particle accelerator are scattered around the lab.\nLook at one and press E to pick it up.",
	"collect": "Collect every part on the list (top right).",
	"craft": "Press C to kneel and work on the floor. Click parts in the tray to lay them down (a Beam Pipe and two Magnet Coils), choose Fit the coils, then click the glowing marks. Build two Beam Segments and the Particle Injector.",
	"install": "Press C to stand up. Put a part in your hand by choosing its hotbar slot (1-6 or mouse wheel), then look at a glowing marker on the ring and press E.",
	"activate": "Everything is installed. Start the accelerator at the console by the door.",
	"go": "",
}
# The same steps for the on-screen touch controls.
const TOUCH_HINTS := {
	"pour": "Hold the mug (tap its hotbar slot), look at the coffee pot and pour yourself a coffee [E].",
	"lay": "Look at the table and tap Craft to work at it. Tap the Papers in the tray to lay them on the table, then choose Read the papers.",
	"read": "Read through the stack: tap the page to turn it over.",
	"move": "Put your thumb down on the left of the screen and slide it up to step out of the elevator, before your ears start to bleed.",
	"pickup": "Parts for the particle accelerator are scattered around the lab.\nLook at one and tap Act to pick it up.",
	"craft": "Tap Craft to kneel and work on the floor. Tap parts in the tray to lay them down (a Beam Pipe and two Magnet Coils), choose Fit the coils, then tap the glowing marks. Build two Beam Segments and the Particle Injector.",
	"install": "Tap Craft to stand up. Put a part in your hand by tapping its hotbar slot, then look at a glowing marker on the ring and tap Act.",
}


func _set_step(s: String) -> void:
	step = s
	hud.set_hint(TOUCH_HINTS.get(s, HINTS[s]) if Settings.touch else HINTS[s])
	_update_objectives()


## The breakroom's steps, before the lab's own.
const BREAKROOM_STEPS := ["ride", "move", "mug", "pour", "drink", "pour2", "drink2", "papers", "lay", "read", "door", "enter"]


func intro_done() -> void:
	## The elevator doors are open (elevator_intro.gd): you can step out.
	_intro = null
	_set_step("move")


func _process(delta: float) -> void:
	var at := player.global_position
	if _riding and breakroom.elevator_open and breakroom.out_of_car(at):
		# Out of the elevator: its doors shut behind you and the music goes.
		_riding = false
		breakroom.close_elevator()
		Music.elevator(false)
		if step == "move":
			_set_step("mug")
	if step in ["lay", "read"]:
		var reading: bool = work != null and work.recipe.get("read", false)
		if step == "lay" and reading:
			_set_step("read")
		elif step == "read" and not reading and Game.inventory.count("keycard_jr") == 0:
			_set_step("lay")
	if step in BREAKROOM_STEPS and step != "ride" and breakroom.in_lab(at):
		_enter_lab()
	if _sequence:
		_run_sequence(delta)


func _have(id: String) -> int:
	var n: int = Game.inventory.count(id)
	match id:
		"beam_pipe":
			n += _crafted_or_installed("beam_segment")
		"magnet_coil":
			n += _crafted_or_installed("beam_segment") * 2
		"control_board", "copper_wire", "power_cell":
			n += _crafted_or_installed("injector")
	return n


func _crafted_or_installed(id: String) -> int:
	var n: int = Game.inventory.count(id)
	for k in installed:
		if (id == "beam_segment" and k.begins_with("beam")) or (id == "injector" and k == "injector"):
			n += 1
	return n


func _on_crafted(id: String) -> void:
	match id:
		"ate_mug_coffee":
			coffees += 1
		"keycard_jr":
			close_work.call_deferred()  # stand up from the table
	check_steps()


func _enter_lab() -> void:
	_set_step("pickup")
	hud.show_message("Night shift, Lab 4.")
	check_steps()


func check_steps() -> void:
	if step in ["mug", "pour", "drink", "pour2", "drink2", "papers", "lay", "read"] and Game.inventory.count("keycard_jr") > 0:
		_set_step("door")  # found it early
	match step:
		"mug":
			if Game.inventory.count("coffee_mug") + Game.inventory.count("mug_coffee") > 0:
				_set_step("pour")
				check_steps()
				return
		"pour", "pour2":
			if Game.inventory.count("mug_coffee") > 0:
				_set_step("drink" if step == "pour" else "drink2")
		"drink":
			if coffees >= 1:
				_set_step("pour2")
		"drink2":
			if coffees >= 2:
				_set_step("papers")
				check_steps()
				return
		"papers":
			if Game.inventory.count("papers") > 0 or (work != null and work.laid("papers") > 0):
				_set_step("lay")
		"door":
			if breakroom.lab_door.is_open:
				_set_step("enter")
		"pickup":
			if REQUIRED.keys().any(func(id): return Game.inventory.count(id) > 0):
				_set_step("collect")
				check_steps()
				return
		"collect":
			if REQUIRED.keys().all(func(id): return _have(id) >= REQUIRED[id]):
				_set_step("craft")
		"craft":
			if _crafted_or_installed("beam_segment") >= 2 and _crafted_or_installed("injector") >= 1:
				_set_step("install")
		"install":
			if installed.size() >= 3:
				_set_step("activate")
	_update_objectives()


func _update_objectives() -> void:
	if hud == null:
		return
	var lines := PackedStringArray()
	if step in BREAKROOM_STEPS and step != "ride":
		lines.append("Before the shift:")
		lines.append("%s Pour a coffee" % _tick(coffees >= 1))
		lines.append("%s Pour another" % _tick(coffees >= 2))
		lines.append("%s Find a keycard" % _tick(Game.inventory.count("keycard_jr") > 0 or breakroom.lab_door.is_open))
		lines.append("[ ] Get into the lab")
	elif step in ["pickup", "collect"]:
		lines.append("Accelerator parts:")
		for id in REQUIRED:
			var have := mini(_have(id), REQUIRED[id])
			lines.append("%s %s  %d/%d" % ["[x]" if have >= REQUIRED[id] else "[ ]", Items.item_name(id), have, REQUIRED[id]])
	elif step in ["craft", "install"]:
		lines.append("Components:")
		lines.append("Beam Segment  %d/2" % mini(_crafted_or_installed("beam_segment"), 2))
		lines.append("Particle Injector  %d/1" % mini(_crafted_or_installed("injector"), 1))
		lines.append("Installed  %d/3" % installed.size())
	hud.set_objectives(lines)


func _tick(done: bool) -> String:
	return "[x]" if done else "[ ]"


func start_sequence() -> void:
	_sequence = true
	_seq_t = 0.0
	_set_step("go")
	hud.set_objectives(PackedStringArray())
	player.frozen = true
	_ring_glow.visible = true
	_hum = AudioStreamPlayer.new()
	_hum.stream = Sfx.stream("hum")
	_hum.volume_db = -12.0
	_hum.pitch_scale = 0.5
	add_child(_hum)
	_hum.play()
	hud.show_message("Beam injection... ramping magnets.")


func _run_sequence(delta: float) -> void:
	_seq_t += delta
	var k := clampf(_seq_t / 6.0, 0.0, 1.0)
	_hum.pitch_scale = lerpf(0.5, 3.5, k * k)
	_hum.volume_db = lerpf(-12.0, 0.0, k)
	player._shake = k * 0.6
	_ring_glow.scale = Vector3.ONE * (1.0 + sin(_seq_t * 30.0) * 0.01 * k)
	for l in _lights:
		l.light_energy = 1.3 * (1.0 - k * 0.5) * (0.3 if randf() < k * 0.3 else 1.0)
	if _seq_t > 3.0 and _seq_t - delta <= 3.0:
		hud.show_message("Field readings are off the scale!")
	if _seq_t > 6.0 and _seq_t - delta <= 6.0:
		Sfx.play("flash", 2.0)
		hud.fade_to(Color(1, 1, 1, 1), 0.12)
		_hum.stop()
	if _seq_t > 8.0:
		_sequence = false
		Game.inventory.clear()
		Game.hints_seen["arrived"] = false
		Game.goto("swamp")
