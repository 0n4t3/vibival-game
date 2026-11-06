extends CanvasLayer
## The opening of a new game with the tutorial (lab.gd): the hum of an
## elevator starting up in the dark, then a cut through the ground (in 3D,
## its own little world in a SubViewport, nothing but rock and soil in
## frame) with the lab's elevator shaft in it. The car drops past with a
## metallic whoosh, the title comes up
## ("Vibival", and who to blame), and it all fades to black. Then you are in
## the car yourself, first person, riding down; after a few seconds it
## stops, the bell dings and the doors open on the breakroom
## (breakroom.gd). Nothing waits for input and nothing skips it, so it plays
## the same with a keyboard, a controller or a touch screen.

const TITLE := "Vibival"
const TAGLINE := "Brought to you by Nate. Unless your CPU explodes. Then it was Claude, all Claude, and you should direct your complaints to Dario."

const DARK := 0.4          # seconds of black, the hum starting
const FADE_IN := 1.6       # black to the ground slice
const CAR_AT := 2.2        # the car comes down the shaft
const CAR_TIME := 1.0
const TITLE_AT := 3.4
const TITLE_FADE := 1.2
const OUT_AT := 9.0        # to black again
const OUT_TIME := 1.0
const INSIDE_AT := 10.2    # in the car, fading in from black
const INSIDE_FADE := 1.2
const OPEN_AT := 13.2      # about three seconds in the car, then the doors
const DONE_AT := 14.2      # you can move

# The cut, in metres: the cut face is the plane z = 0, the ground's surface
# y = 0 (always just above the frame), the shaft centred on x = 0.
const SHAFT_W := 1.2       # half the shaft's width inside its lining
const SHAFT_D := 2.6       # how far back the shaft goes behind the face
const LINING := 0.3
const DEPTH := 28.0        # how far down the cut is built
const SAUCER_AT := Vector3(6.2, -5.6, -0.4)
const CROC_AT := Vector3(-10.4, -12.9, 0.06)
const CAR_FROM := 3.0      # the car's floor, above the frame
const CAR_TO := -32.0      # and gone, below it
# The strata: [top, colour, material, how rough the face is]
const STRATA := [
	[0.0, Color(0.27, 0.19, 0.12), "organic", 0.14], [-2.3, Color(0.55, 0.36, 0.2), "clay", 0.1],
	[-4.8, Color(0.72, 0.6, 0.42), "clay", 0.07], [-7.8, Color(0.68, 0.66, 0.6), "stone", 0.12],
	[-11.2, Color(0.3, 0.29, 0.31), "stone", 0.05], [-15.0, Color(0.42, 0.38, 0.38), "stone", 0.2],
]

var lab: Node
var t := 0.0
var done := false

var _root: Control         # the cut and, over it, the title and the fades
var _view: Control
var _cam: Camera3D
var _car: Node3D
var _ghosts: Array[Node3D] = []   # see-through copies trailing the car: a motion blur
var _cables: MultiMesh
var _hum: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _passed := false
var _inside := false
var _opened := false


func setup(l: Node) -> CanvasLayer:
	lab = l
	return self


func _ready() -> void:
	layer = 20  # over the HUD and every panel
	_rng.seed = 2026
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if Settings.quality == Settings.Quality.LOW else Viewport.MSAA_4X
	box.add_child(vp)
	_build_cut(vp)
	_view = Control.new()
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_view)
	_root.add_child(_view)
	_hum = AudioStreamPlayer.new()
	_hum.stream = Sfx.stream("hum")
	_hum.volume_db = -40.0
	_hum.pitch_scale = 0.3
	add_child(_hum)
	_hum.play()
	lab.player.frozen = true


func _notification(what: int) -> void:
	# The pause menu is under this layer: out of its way while it is up.
	if what == NOTIFICATION_PAUSED and _root:
		_root.visible = false
	elif what == NOTIFICATION_UNPAUSED and _root:
		_root.visible = not _inside


func _process(delta: float) -> void:
	t += delta
	_sound()
	if not _passed and t >= CAR_AT:
		_passed = true
		Sfx.play("elevator_pass", -3.0, 0.0)  # loudest as the car crosses the middle of the frame
	if not _inside and t >= INSIDE_AT:
		_inside = true
		_root.visible = false
		lab.hud.set_fade(Color(0, 0, 0, 1))
		lab.hud.fade_to(Color(0, 0, 0, 0), INSIDE_FADE)
		Music.elevator(true)
	if _inside and not _opened:
		# The car shudders on its way down, and bumps to a stop.
		var p: Node = lab.player
		p._shake = maxf(p._shake, 0.06 if t < OPEN_AT - 0.4 else 0.0)
	if not _opened and t >= OPEN_AT:
		_opened = true
		lab.player._shake = 0.4
		lab.breakroom.open_elevator()
	if not done and t >= DONE_AT:
		done = true
		_hum.stop()
		lab.player.frozen = false
		lab.intro_done()
		queue_free()
		return
	if _root.visible:
		_move_cut()
		_view.queue_redraw()


func _sound() -> void:
	## The hum: winding up in the dark, louder as the car rushes past, steady
	## on the ride down, winding down as it stops.
	var pitch := 0.75
	var vol := -14.0
	if t < CAR_AT:
		var k := clampf(t / CAR_AT, 0.0, 1.0)
		pitch = lerpf(0.3, 0.75, k)
		vol = lerpf(-40.0, -14.0, sqrt(k))
	elif t < OUT_AT:
		var pass_k := 1.0 - clampf(absf(t - (CAR_AT + CAR_TIME * 0.5)) / 0.8, 0.0, 1.0)
		pitch = 0.75 + pass_k * 0.12
		vol = -14.0 + pass_k * 8.0
		vol = lerpf(vol, -22.0, clampf((t - CAR_AT - 1.5) / 2.0, 0.0, 1.0))
	elif t < INSIDE_AT:
		vol = lerpf(-22.0, -12.0, (t - OUT_AT) / (INSIDE_AT - OUT_AT))
	elif t < OPEN_AT - 1.0:
		vol = -12.0
	else:
		var k := clampf((t - (OPEN_AT - 1.0)) / 1.6, 0.0, 1.0)
		pitch = lerpf(0.75, 0.4, k)
		vol = lerpf(-12.0, -40.0, k)
	_hum.pitch_scale = pitch
	_hum.volume_db = vol


# --- The cut through the ground ---------------------------------------------------------

func _build_cut(vp: SubViewport) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.32, 0.38)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.75, 0.55, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = Settings.quality > Settings.Quality.LOW
	vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 80.0
	vp.add_child(_cam)

	var b = Assets.builder()
	_face(b)
	_shaft(b)
	_buried(b)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Assets.materials)
	vp.add_child(mi)
	vp.add_child(_saucer())
	var croc = Assets.builder()
	_crocodile(croc, Vector3.ZERO)
	var croc_mi := MeshInstance3D.new()
	croc_mi.mesh = croc.commit(Assets.materials)
	croc_mi.position = CROC_AT
	croc_mi.scale = Vector3.ONE * 1.7
	vp.add_child(croc_mi)

	_car = Node3D.new()
	vp.add_child(_car)
	var car_mesh := _car_mesh()
	var car_mi := MeshInstance3D.new()
	car_mi.mesh = car_mesh
	_car.add_child(car_mi)
	# Its light washes over the shaft as it goes by.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.4, 0.4)
	lamp.light_color = Color(1.0, 0.85, 0.6)
	lamp.light_energy = 2.0
	lamp.omni_range = 4.5
	lamp.light_specular = 0.1  # no hot spot on the car's own steel
	_car.add_child(lamp)
	# The shaft's own lamps, dim, so its depth shows.
	var at := -3.0
	while at > -DEPTH:
		var l := OmniLight3D.new()
		l.position = Vector3(0.6, at, -SHAFT_D + 0.4)
		l.light_color = Color(0.85, 0.92, 1.0)
		l.light_energy = 0.7
		l.omni_range = 3.2
		vp.add_child(l)
		at -= 5.0
	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(0.7, 0.72, 0.76, 0.16)
	for i in 4:
		var g := MeshInstance3D.new()
		g.mesh = car_mesh
		g.material_override = ghost_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vp.add_child(g)
		_ghosts.append(g)
	var cable := CylinderMesh.new()
	cable.top_radius = 0.025
	cable.bottom_radius = 0.025
	cable.height = 1.0
	cable.radial_segments = 6
	cable.rings = 1
	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.45, 0.45, 0.47)
	cable_mat.metallic = 0.8
	cable_mat.roughness = 0.4
	cable.material = cable_mat
	_cables = MultiMesh.new()
	_cables.transform_format = MultiMesh.TRANSFORM_3D
	_cables.mesh = cable
	_cables.instance_count = 3
	var cables := MultiMeshInstance3D.new()
	cables.multimesh = _cables
	vp.add_child(cables)
	_move_cut()


func _car_mesh() -> ArrayMesh:
	## The car, seen from the front (the face cuts the shaft open): steel,
	## doors with lit vision panels, the crosshead the cables hang from.
	var b = Assets.builder()
	var steel := Color(0.62, 0.64, 0.68)
	var trim := Color(0.4, 0.41, 0.44)
	var front := -0.22
	b.box(Vector3(0, 1.25, -1.35), Vector3(2.0, 2.5, 2.26), steel, Basis(), "metal")
	b.box(Vector3(0, 1.1, front + 0.005), Vector3(0.03, 2.0, 0.02), Color(0.2, 0.2, 0.22))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.94, 1.15, front + 0.01), Vector3(0.06, 2.3, 0.03), trim, Basis(), "metal")
		b.box(Vector3(sx * 0.42, 1.35, front + 0.012), Vector3(0.12, 0.9, 0.02), Color(1.0, 0.86, 0.55), Basis(), "glow")
	b.box(Vector3(0, 2.33, front + 0.01), Vector3(1.94, 0.06, 0.03), trim, Basis(), "metal")
	b.box(Vector3(0, 2.62, -1.35), Vector3(2.3, 0.16, 0.36), Color(0.22, 0.22, 0.24), Basis(), "metal")
	b.box(Vector3(0, -0.15, -1.35), Vector3(2.0, 0.3, 2.2), Color(0.25, 0.25, 0.27))
	for sx in [-1.0, 1.0]:  # guide shoes on the rails
		for sy in [-0.2, 2.62]:
			b.box(Vector3(sx * 1.08, sy, -1.35), Vector3(0.14, 0.22, 0.2), Color(0.18, 0.18, 0.2))
	return b.commit(Assets.materials)


func _move_cut() -> void:
	## A slow drift down the cut while the title is up, and the car dropping.
	var k := clampf(t / OUT_AT, 0.0, 1.0)
	var y := lerpf(-8.6, -9.6, k)
	_cam.position = Vector3(7.0, y + 0.8, 19.0)
	_cam.look_at(Vector3(0.4, y, 0.0))
	var fall := clampf((t - CAR_AT) / CAR_TIME, 0.0, 1.0)
	var car_y := lerpf(CAR_FROM, CAR_TO, fall * fall)
	_car.position = Vector3(0, car_y, 0)
	var speed := 2.0 * fall * (CAR_FROM - CAR_TO) / CAR_TIME  # metres a second, downwards
	for i in _ghosts.size():
		_ghosts[i].visible = fall > 0.0 and fall < 1.0
		_ghosts[i].position = Vector3(0, car_y + speed * 0.012 * (i + 1), 0)
	var top := 12.0
	var low := car_y + 2.7
	for i in 3:
		var basis := Basis().scaled(Vector3(1, maxf(top - low, 0.01), 1))
		_cables.set_instance_transform(i, Transform3D(basis, Vector3((i - 1) * 0.14, (top + low) * 0.5, -1.35)))


func _strata_at(x: float, y: float) -> int:
	## Which layer the point (x, y) of the face is in; the boundaries wander.
	for i in range(STRATA.size() - 1, -1, -1):
		var top: float = STRATA[i][0]
		if i > 0:
			top += sin(x * 0.31 + i * 1.7) * 0.35 + sin(x * 0.9 + i) * 0.12
		if y <= top:
			return i
	return 0


func _relief(x: float, y: float, layer: int) -> float:
	var rough: float = STRATA[layer][3]
	var z := (sin(x * 2.3 + y * 1.1) * 0.5 + sin(x * 5.1 - y * 3.7) * 0.3 + sin(y * 7.9 + x * 0.7) * 0.2) * rough
	if layer == 4:
		z += sin(y * 14.0) * 0.04  # shale: thin beds
	return z


func _face(b) -> void:
	## The cut face: a grid, broken for the shaft, pushed in and out a little
	## so the light picks out each layer.
	var cell := 0.25
	var nx := 192
	var ny := int(DEPTH / cell)
	var x0 := -24.0
	var pts := []
	for j in ny + 1:
		var row := []
		var y := -j * cell
		for i in nx + 1:
			var x := x0 + i * cell
			var z := 0.0 if absf(x) <= SHAFT_W + LINING + 0.01 else _relief(x, y, _strata_at(x, y))
			row.append(Vector3(x, y, z))
		pts.append(row)
	for j in ny:
		for i in nx:
			var cx := x0 + (i + 0.5) * cell
			if absf(cx) < SHAFT_W + LINING:
				continue
			var layer := _strata_at(cx, -(j + 0.5) * cell)
			var col: Color = STRATA[layer][1] * _rng.randf_range(0.92, 1.06)
			col.a = 1.0
			b.quad(pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i], col, STRATA[layer][2])


func _shaft(b) -> void:
	## Lined in concrete, with guide rails, a ladder and lamps down the back.
	var concrete := Color(0.58, 0.58, 0.55)
	var rust := Color(0.55, 0.45, 0.12)
	var mid := -DEPTH * 0.5 + 0.5
	var h := DEPTH + 1.0
	b.box(Vector3(0, mid, -SHAFT_D - 0.1), Vector3(2 * (SHAFT_W + LINING), h, 0.2), concrete * 0.75, Basis(), "stone")
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (SHAFT_W + LINING * 0.5), mid, -SHAFT_D * 0.5 + 0.02), Vector3(LINING, h, SHAFT_D + 0.04), concrete, Basis(), "stone")
		b.box(Vector3(sx * (SHAFT_W - 0.04), mid, -1.35), Vector3(0.08, h, 0.12), Color(0.3, 0.3, 0.33), Basis(), "metal")
		var y := -1.0
		while y > -DEPTH:
			b.box(Vector3(sx * (SHAFT_W - 0.08), y, -1.35), Vector3(0.16, 0.1, 0.3), Color(0.24, 0.24, 0.26), Basis(), "metal")
			y -= 2.2
	for sx in [-0.75, -0.35]:
		b.box(Vector3(sx, mid, -SHAFT_D + 0.08), Vector3(0.04, h, 0.04), rust, Basis(), "metal")
	var rung := -0.4
	while rung > -DEPTH:
		b.box(Vector3(-0.55, rung, -SHAFT_D + 0.08), Vector3(0.4, 0.03, 0.03), rust, Basis(), "metal")
		rung -= 0.35
	var lamp := -3.0
	while lamp > -DEPTH:
		b.box(Vector3(0.6, lamp, -SHAFT_D + 0.05), Vector3(0.18, 0.1, 0.08), Color(0.9, 0.95, 1.0), Basis(), "glow")
		lamp -= 5.0


func _buried(b) -> void:
	## Stones, boulders, roots and a couple of fossils, half out of the face.
	var clear := SHAFT_W + LINING
	for i in 220:
		var x := _rng.randf_range(-23.0, 23.0)
		var y := _rng.randf_range(-DEPTH + 0.5, -0.3)
		if absf(x) < clear + 0.3:
			continue
		var layer := _strata_at(x, y)
		var r := _rng.randf_range(0.04, 0.14) * (2.0 if layer == 5 else 1.0)
		var col: Color = STRATA[layer][1].lerp(Color(0.6, 0.58, 0.55), 0.5) * _rng.randf_range(0.7, 1.15)
		col.a = 1.0
		b.blob(Vector3(x, y, _relief(x, y, layer)), Vector3(r, r * 0.8, r), 3, 5, col, _rng, 0.25, "stone")
	for i in 14:
		var x := _rng.randf_range(-22.0, 22.0)
		var y := _rng.randf_range(-DEPTH + 1.0, -8.0)
		var spot := Vector3(x, y, 0.0)
		if absf(x) < clear + 1.0 or spot.distance_to(SAUCER_AT) < 3.0 or spot.distance_to(CROC_AT + Vector3(3.5, 0, 0)) < 5.0:
			continue
		var r := _rng.randf_range(0.35, 0.9)
		var col := Color(0.5, 0.48, 0.46) * _rng.randf_range(0.8, 1.1)
		col.a = 1.0
		b.blob(Vector3(x, y, 0.0), Vector3(r * 1.3, r, r * 0.7), 4, 7, col, _rng, 0.2, "stone")
	# Roots down from the topsoil.
	for i in 18:
		var at := Vector3(_rng.randf_range(-22.0, 22.0), 0.2, 0.05)
		if absf(at.x) < clear + 0.4:
			continue
		var pts := [at]
		var radii := [0.06]
		for k in 5:
			at += Vector3(_rng.randf_range(-0.35, 0.35), -_rng.randf_range(0.35, 0.6), 0.0)
			pts.append(at)
			radii.append(0.05 * (1.0 - (k + 1) / 6.0) + 0.008)
		b.tube(pts, radii, 4, [Color(0.36, 0.28, 0.2)])
	# An ammonite in the limestone and a fern in the shale, for the sharp-eyed.
	var bone := Color(0.82, 0.78, 0.68)
	var am := Vector3(-6.5, -9.4, 0.06)
	var spiral := []
	var widths := []
	for k in 30:
		var a := k * 0.42
		var rr := 0.02 + k * 0.016
		spiral.append(am + Vector3(cos(a) * rr, sin(a) * rr, 0.0))
		widths.append(0.015 + k * 0.004)
	b.tube(spiral, widths, 5, [bone])
	var leaf := Color(0.55, 0.52, 0.48)
	var fern := Vector3(7.5, -13.6, 0.06)
	var tip := fern + Vector3(0.6, 1.4, 0.0)
	b.tube([fern, fern.lerp(tip, 0.5) + Vector3(0.12, 0, 0), tip], [0.025, 0.02, 0.012], 4, [leaf])
	for k in 7:
		var on := fern.lerp(tip, (k + 1) / 8.0)
		var length := 0.45 * (1.0 - k / 9.0)
		b.box(on + Vector3(-length * 0.45, 0.04, 0), Vector3(length, 0.04, 0.03), leaf, Basis(Vector3.FORWARD, -0.35))
		b.box(on + Vector3(length * 0.45, 0.04, 0), Vector3(length, 0.04, 0.03), leaf, Basis(Vector3.FORWARD, 0.35))


func _saucer() -> MeshInstance3D:
	## A flying saucer that came down hard, long ago: nose first into the sand,
	## tilted, the back of it still inside the face, its dome faintly lit.
	var b = Assets.builder()
	var hull := Color(0.6, 0.62, 0.66)
	b.lathe([Vector2(0, -0.2), Vector2(0.7, -0.22), Vector2(1.45, -0.06), Vector2(1.65, 0.0),
			Vector2(1.45, 0.09), Vector2(0.72, 0.17), Vector2(0, 0.18)], 18, hull, "metal")
	b.lathe([Vector2(0.62, 0.16), Vector2(0.58, 0.38), Vector2(0.36, 0.56), Vector2(0, 0.62)], 14, Color(0.45, 0.9, 0.75), "glow")
	b.lathe([Vector2(0, -0.34), Vector2(0.38, -0.3), Vector2(0.45, -0.2)], 10, Color(0.3, 0.31, 0.34), "metal")
	for i in 10:
		var a := TAU * i / 10.0
		b.box(Vector3(cos(a) * 1.56, 0.02, sin(a) * 1.56), Vector3(0.1, 0.06, 0.1), Color(1.0, 0.55, 0.25) if i % 3 else Color(0.25, 0.1, 0.05), Basis(), "glow")
	# A dent and a torn plate where it hit.
	b.box(Vector3(-1.1, 0.04, 0.55), Vector3(0.5, 0.05, 0.3), hull * 0.6, Basis(Vector3.UP, 0.5).rotated(Vector3.FORWARD, 0.4), "metal")
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	for i in 9:  # bits that broke off, scattered in the sand around it
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.8, 2.6)
		b.box(Vector3(cos(a) * r, rng.randf_range(-0.3, 0.3), sin(a) * r), Vector3(0.18, 0.03, 0.12) * rng.randf_range(0.6, 1.4), hull * 0.8,
				Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU), "metal")
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Assets.materials)
	mi.position = SAUCER_AT
	mi.rotation = Vector3(0.8, 0.2, -0.45)
	mi.scale = Vector3.ONE * 1.3
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _crocodile(b, at: Vector3) -> void:
	## A crocodile's skeleton, laid out flat in the shale: skull and jaws to
	## the left, the spine running off into a long tail, ribs and splayed legs.
	var bone := Color(0.86, 0.82, 0.72)
	var spine := []
	for k in 34:
		var q := k / 33.0
		spine.append(at + Vector3(1.0 + q * 3.6, sin(q * 5.0) * 0.18 - q * 0.1, 0.0))
	for k in spine.size():
		var size := lerpf(0.11, 0.035, float(k) / spine.size())
		b.box(spine[k], Vector3(size * 0.8, size, 0.06), bone, Basis(Vector3.FORWARD, sin(k) * 0.1))
	# The skull, the jaw a little open, teeth and an eye socket.
	b.tube([at + Vector3(1.0, 0, 0), at + Vector3(0.7, 0.02, 0), at + Vector3(0.3, -0.01, 0), at + Vector3(-0.15, -0.02, 0)],
			[0.15, 0.12, 0.07, 0.05], 6, [bone])
	b.tube([at + Vector3(0.9, -0.12, 0), at + Vector3(0.4, -0.2, 0), at + Vector3(-0.1, -0.24, 0)], [0.05, 0.04, 0.03], 5, [bone])
	for k in 7:
		var x := at.x + 0.65 - k * 0.11
		b.cone(Vector3(x, at.y - 0.06, at.z), Vector3(x, at.y - 0.14, at.z), 0.018, 4, bone)
		b.cone(Vector3(x - 0.04, at.y - 0.2 + k * 0.006, at.z), Vector3(x - 0.04, at.y - 0.12 + k * 0.006, at.z), 0.015, 4, bone)
	b.blob(at + Vector3(0.72, 0.06, 0.06), Vector3(0.05, 0.04, 0.02), 3, 6, Color(0.12, 0.12, 0.13))
	# Ribs, down from the front of the spine.
	for k in range(3, 13):
		var p: Vector3 = spine[k]
		var length := 0.34 * (1.0 - absf(k - 7.0) / 9.0)
		b.tube([p, p + Vector3(0.04, -length * 0.55, 0), p + Vector3(0.12, -length, 0)], [0.02, 0.018, 0.012], 4, [bone])
	# Legs, splayed, with their toes.
	for leg in [[2, -0.25], [11, 0.3]]:
		var hip: Vector3 = spine[leg[0]]
		for side in [-1.0, 1.0]:
			var knee := hip + Vector3(side * 0.28 + leg[1] * 0.2, -0.22 * (1.0 if side < 0 else 0.6), 0)
			var foot := knee + Vector3(side * 0.12, -0.24, 0)
			b.tube([hip, knee, foot], [0.03, 0.025, 0.02], 4, [bone])
			for toe in 3:
				b.tube([foot, foot + Vector3(side * 0.04 + (toe - 1) * 0.06, -0.1, 0)], [0.012, 0.008], 3, [bone])


# --- The title and the fades, over the cut ------------------------------------------------

func _draw_view() -> void:
	var size := _view.size
	var w := size.x
	var h := size.y
	var font := ThemeDB.fallback_font
	var a := clampf((t - TITLE_AT) / TITLE_FADE, 0.0, 1.0)
	if a > 0.0:
		var band := Rect2(0, h * 0.38, w, h * 0.3)
		_view.draw_rect(band, Color(0, 0, 0, 0.55 * a))
		var title_size := int(minf(w * 0.14, h * 0.17))
		var title_font := FontVariation.new()
		title_font.base_font = font
		title_font.variation_embolden = 1.2
		var ty := band.position.y + band.size.y * 0.46
		_view.draw_string_outline(title_font, Vector2(0, ty), TITLE, HORIZONTAL_ALIGNMENT_CENTER, w, title_size, 8, Color(0, 0, 0, a))
		_view.draw_string(title_font, Vector2(0, ty), TITLE, HORIZONTAL_ALIGNMENT_CENTER, w, title_size, Color(0.96, 0.9, 0.72, a))
		var tag_size := maxi(int(minf(w * 0.022, h * 0.034)), 13)
		var tw := minf(w * 0.86, tag_size * 34.0)
		_view.draw_multiline_string(font, Vector2((w - tw) * 0.5, ty + tag_size * 2.0), TAGLINE, HORIZONTAL_ALIGNMENT_CENTER, tw, tag_size, -1,
				Color(0.9, 0.9, 0.86, a))
	# Fading in from black, and out to it.
	var black := 1.0 - clampf((t - DARK) / FADE_IN, 0.0, 1.0)
	black = maxf(black, clampf((t - OUT_AT) / OUT_TIME, 0.0, 1.0))
	if black > 0.0:
		_view.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, black))
