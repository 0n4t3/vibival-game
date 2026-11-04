extends CharacterBody3D
## First-person survivor: movement, swimming, looking, interacting, attacking
## and using held items. Physics layer 1 = solid world, layer 2 = interactables,
## layer 3 (bit value 4) = blocks movement but not interaction rays.

signal hurt_flash(amount: float)
signal died
signal escape_rolled(chance: float, roll: float, freed: bool)

const Survival := preload("res://src/core/survival.gd")
const Inventory := preload("res://src/core/inventory.gd")
const ThrownRock := preload("res://src/world/thrown_rock.gd")
const Fishing := preload("res://src/world/fishing.gd")
const House := preload("res://src/world/house.gd")

const WALK := 3.6
const SPRINT := 6.2
const JUMP := 4.3
const GRAVITY := 11.0
const FLY_SPEED := 8.0
const FLY_TAP := 0.35       # seconds between the two jump presses that toggle flying
const INTERACT_RANGE := 3.0
const DROP_REACH := 1.0         # how far in front a dropped item lands
const DROP_CLEARANCE := 0.3     # and how far short of anything solid in the way
const FIST_DAMAGE := 2.0
const GRAB_DPS := 13.0          # default health lost per second in an amphibian's jaws
const GRAB_BITE := 25.0         # default damage of the initial bite (species override both)
const STAB_COOLDOWN := 0.3
const THROW_SPEED := 17.0
const THROW_COOLDOWN := 0.6
const SPINE_PRICK := 4.0   # punching a live Acanthodes bare-fisted: its spines prick you
const WAYPOINT_RANGE := 250.0
# Escaping a Uranocentrodon is a dice roll once it has you in deep water (or
# after ROLL_TIME): a 10% chance it drops you anyway, raised by the best strike
# you landed while held.
const ESCAPE_BASE := 0.10
const ESCAPE_BONUS := {"": 0.0, "bare": 0.15, "stone": 0.30, "advanced": 0.60}
const ROLL_TIME := 1.5
const MIN_ROLL_TIME := 0.8    # always time for a couple of strikes first
# Falls and nasty bites can break bones (see Survival.limbs).
const FALL_SAFE := 3.0          # falls up to this many metres are harmless
const FALL_RISK := 4.0          # the chance of an injury rises from 25% over this many more
const CLIMB := 1.6              # m/s up or down a rope ladder
const FRACTURE_FROM := 15.0     # a hit at least this hard may break an arm or a leg
const TRAUMA := 0.4             # blood lost at once per point of a hit

var world: Node = null          # scene root; may provide water_level()/place()/spawn_pickup()
var vitals := Survival.new()
var vitals_enabled := true
var ui_open := false
var frozen := false
var lie := 0.0  # 0 on your feet .. 1 flat on your back looking straight up (the arrival: intro.gd)
var fishing: Node = null  # the line you have cast (fishing.gd), if any
var rod_tug := 0.0        # 0..1: how hard the rod jerks in your hand (a bite, a fish fighting)

var head: Node3D
var camera: Camera3D
var hand: Node3D
var held_mesh: MeshInstance3D
var _torch_light: OmniLight3D    # a held light source (lit torch)
var _torch_flicker := 0.0

var work_spot: Node3D = null    # where you kneel crafting on the ground
var work_view := Vector3.ZERO   # camera yaw, pitch and extra fov that keep the work clear of the work UI's panels
var work_back := 0.0            # and how much further back the camera stands when that isn't enough
var hauling: Node3D = null      # a carcass or log carried (or a large carcass dragged) in front of you
var focus: Object = null        # interactable under the crosshair
var focus_water := false
var prompt := ""
var tooltip := ""               # a panel about what you look at (a soup pot's contents)
var _water_at := Vector3.INF    # where the view meets the water, while focus_water

var _pitch := 0.0
var _rng := RandomNumberGenerator.new()
var _attack_cd := 0.0
var _take_hold := 0.0          # how long E has been held on a pile
var _swing := 1.0
var _step_dist := 0.0
var _shake := 0.0
var _bob := 0.0
var _held_id := "~"
var _press_t := 0.0             # seconds you have held pressure on a wound
var _air_top := -INF            # highest point since you left the ground
var next_injury := -1.0         # tests: force the next fracture or fall roll (0..1)
var _drunk_t := 0.0
var flying := false         # debug worlds only
var climbing: Node3D = null     # the house whose rope ladder you are on
var _plan: Node3D = null        # the house a held blueprint shows, where it would go
var _plan_why := ""
var _last_jump := -1.0

var grabbed_by: Node3D = null    # creature holding the player in its jaws
var grip := 0.0                  # its grip, grip_max = locked on, 0 = lets go
var grip_max := 100.0
var _grab_t := 0.0
var strike_tier := ""            # best strike landed while held ("", bare, stone, advanced)
var escape_roll := -1.0          # the escape roll (0..1) once made this grab
var next_roll := -1.0            # tests: force the next escape roll


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.75
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.875
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = Settings.view_distance + 40.0
	camera.fov = Settings.fov
	camera.current = true
	head.add_child(camera)
	hand = Node3D.new()
	hand.position = Vector3(0.32, -0.28, -0.5)
	camera.add_child(hand)
	held_mesh = MeshInstance3D.new()
	held_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(held_mesh)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.6, 0.28)
	_torch_light.position = Vector3(0.0, 0.35, -0.15)
	_torch_light.visible = false
	hand.add_child(_torch_light)

	vitals.died.connect(_on_died)
	vitals.status.connect(Game.notify)
	apply_cheats()
	Settings.changed.connect(_on_settings)
	Game.player = self
	if Game.dev.has("yaw"):
		rotation.y = deg_to_rad(float(Game.dev["yaw"]))
	if Game.dev.has("pitch"):
		_pitch = deg_to_rad(float(Game.dev["pitch"]))
		head.rotation.x = _pitch


func apply_cheats() -> void:
	## A debug world's switches (and the dev --god flag).
	vitals.god = Game.dev.has("god") or (Game.debug and not Game.cheats.damage)
	vitals.no_needs = Game.debug and not Game.cheats.needs
	if not Game.debug:
		flying = false


func _on_settings() -> void:
	camera.fov = Settings.fov
	camera.far = Settings.view_distance + 40.0


func capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Settings.touch:
		on = false  # touch controls look by dragging; the pointer stays free
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if ui_open or frozen or vitals.dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * Settings.mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse(true)
		get_viewport().set_input_as_handled()
		return
	if grabbed_by:
		return
	if event.is_action_pressed("sleep"):
		if world and world.has_method("request_sleep"):
			world.request_sleep()
	elif event.is_action_pressed("waypoint"):
		if world and world.has_method("mark_waypoint"):
			world.mark_waypoint(look_point(WAYPOINT_RANGE))
	elif hauling and event.is_action_pressed("interact") and hauling.has_method("haul_interact") \
			and hauling.haul_interact(self):
		pass  # filled a soup pot at the water
	elif hauling and (event.is_action_pressed("interact") or event.is_action_pressed("drop")):
		put_down()
	elif hauling and event.is_action_pressed("use") and hauling.has_method("haul_use") and hauling.haul_use(self):
		pass  # set up a carried workbench
	elif hauling and (event.is_action_pressed("use") or event.is_action_pressed("attack")):
		Game.notify("Your hands are full. Put the %s down first (Q)." % hauling.haul_name())
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("use"):
		_use_held()
	elif event.is_action_pressed("drop"):
		_drop_held()
	elif event.is_action_pressed("slot_next"):
		Game.inventory.select(Game.inventory.selected + 1)
	elif event.is_action_pressed("slot_prev"):
		Game.inventory.select(Game.inventory.selected - 1)
	else:
		for i in 6:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				Game.inventory.select(i)


func _look(rel: Vector2) -> void:
	rotation.y -= rel.x
	_pitch = clampf(_pitch - rel.y, -1.5, 1.5)
	head.rotation.x = _pitch


func water_level() -> float:
	return world.water_level() if world and world.has_method("water_level") else -INF


func water_depth() -> float:
	return water_level() - global_position.y


func _physics_process(delta: float) -> void:
	if grabbed_by:
		_physics_grabbed(delta)
		return
	var active := not ui_open and not frozen and not vitals.dead
	var depth := water_depth()
	var swimming := depth > 1.25
	var wading := depth > 0.25

	var input := Vector2.ZERO
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var pad_look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if pad_look != Vector2.ZERO:
			_look(pad_look * 2.6 * delta)
	if vitals.pressing >= 0:
		_hold_pressure(delta, input)
		input = Vector2.ZERO
	# What your body allows: a broken arm halves what you carry (the sack's
	# share aside), and a worsening condition takes more.
	Game.inventory.arm_broken = vitals.arm_broken()
	Game.inventory.strength = vitals.carry_mult()
	var load: float = Game.inventory.load_ratio()
	var sprinting := active and Input.is_action_pressed("sprint") and input.y < 0.0 \
			and vitals.stamina > 1.0 and not wading and load <= 1.0 and hauling == null and vitals.can_sprint()
	var speed := SPRINT if sprinting else WALK
	speed *= vitals.speed_mult()
	if hauling and hauling.haul_mode() == "drag":
		speed *= 0.5
	if hauling and vitals.arm_broken():
		speed *= Survival.ARM_HAUL
	if load > 1.0:
		# Overloaded: slower, and walking costs stamina.
		speed *= lerpf(1.0, 0.5, clampf((load - 1.0) / (Inventory.OVERLOAD - 1.0), 0.0, 1.0))
		if input != Vector2.ZERO:
			vitals.stamina = maxf(vitals.stamina - 3.0 * delta, 0.0)
	if swimming:
		speed *= 0.5
	elif wading:
		speed *= lerpf(0.75, 0.5, clampf((depth - 0.25) / 1.0, 0.0, 1.0))

	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var accel := 10.0 if is_on_floor() or swimming else 2.5
	velocity.x = lerpf(velocity.x, dir.x * speed, minf(accel * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, minf(accel * delta, 1.0))

	if active and Game.debug and Input.is_action_just_pressed("jump"):
		# Debug worlds: a double tap of jump takes off or lands.
		var now := Time.get_ticks_msec() * 0.001
		if now - _last_jump < FLY_TAP:
			flying = not flying
			_last_jump = -1.0
			Game.notify("Flying." if flying else "Landed.")
		else:
			_last_jump = now
	climbing = _ladder(input if active else Vector2.ZERO) if not flying and not swimming else null
	if climbing:
		# On a rope ladder: up and down it, a little from side to side, held
		# out from the edge of the porch until you are up level with it.
		var l: Vector3 = climbing.to_local(global_position)
		var up := _ladder_dir(input if active else Vector2.ZERO)
		var v := Vector3(input.x * 1.0, up * CLIMB, (House.EDGE + 0.42 - l.z) * 4.0)
		if l.y > 0.06 and up > 0.0:
			v = Vector3(0, 0.4, -1.8)  # step off onto the porch
		velocity = climbing.global_basis * v
	elif flying:
		var up := 0.0
		if active:
			up = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("fly_down") else 0.0)
		var fast := FLY_SPEED * (2.5 if active and Input.is_action_pressed("sprint") else 1.0)
		velocity.x = lerpf(velocity.x, dir.x * fast, minf(8.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, dir.z * fast, minf(8.0 * delta, 1.0))
		velocity.y = lerpf(velocity.y, up * fast, minf(8.0 * delta, 1.0))
	elif swimming:
		# Float with the head just above the surface.
		var target := water_level() - 1.35
		velocity.y = lerpf(velocity.y, (target - global_position.y) * 3.0, minf(4.0 * delta, 1.0))
		if active and Input.is_action_pressed("jump"):
			velocity.y = 1.5
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif active and Input.is_action_just_pressed("jump") and vitals.stamina > 8.0:
			velocity.y = JUMP * (0.6 if wading else 1.0)
			vitals.stamina -= 8.0

	move_and_slide()
	if hauling:
		_hold_haul()
	_check_fall(swimming or wading)

	if vitals_enabled:
		var still := is_on_floor() and input == Vector2.ZERO and hauling == null
		vitals.tick(delta, sprinting, swimming, wading, false, still)
		if swimming and vitals.stamina <= 0.0:
			if vitals.drowning == 0.0:
				Game.notify("You are exhausted and swallowing water!")
			vitals.drown(delta)

	# Footsteps
	var moved := Vector2(velocity.x, velocity.z).length() * delta
	if is_on_floor() or swimming:
		_step_dist += moved
		_bob += moved * 2.2
	if _step_dist > (2.0 if sprinting else 1.6):
		_step_dist = 0.0
		Sfx.play("splash" if wading else "step", -14.0 if wading else -10.0, 0.15)


func _ladder(input: Vector2) -> Node3D:
	## The house whose rope ladder you climb this frame, or null: half way up
	## it, or at its foot heading up, or up on the porch heading down it.
	var h: Node3D = world.ladder_at(global_position) if world and world.has_method("ladder_at") else null
	if h == null:
		return null
	var l: Vector3 = h.to_local(global_position)
	var up := _ladder_dir(input)
	if is_on_floor():
		if l.y > -0.06:
			return h if up < 0.0 and climbing == null else (h if climbing and up != 0.0 else null)
		if up <= 0.0:
			return null  # at its foot, walking away
	return h


func _ladder_dir(input: Vector2) -> float:
	## Which way the move keys take you on a ladder: facing the house, forward
	## climbs (or down, looking down) and back comes down; facing away, the
	## other way round.
	var h: Node3D = climbing if climbing else (world.ladder_at(global_position) if world and world.has_method("ladder_at") else null)
	if h == null or absf(input.y) < 0.1:
		return 0.0
	var push := -input.y
	var facing: Vector3 = h.global_basis.inverse() * -global_transform.basis.z
	if facing.z < 0.0:
		return -1.0 if push < 0.0 or _pitch < -0.35 else 1.0
	return 1.0 if push < 0.0 else -1.0


func _process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_swing = minf(_swing + delta * 3.2, 1.0)
	_shake = maxf(_shake - delta * 2.5, 0.0)
	var held: String = Game.inventory.held_id()
	if held != _held_id:
		_held_id = held
		_update_held_mesh()
		Game.learn_tool(held)  # a rack tool in hand: its recipes go in the book
	_update_torch(delta)

	# View effects: bob, swing, shake
	var bob := sin(_bob) * 0.03
	camera.position = Vector3(cos(_bob * 0.5) * 0.015, bob, 0)
	if _shake > 0.0:
		camera.position += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.08
	var s := sin(_swing * PI)
	hand.rotation = Vector3(-s * 1.1, s * 0.4, 0)
	hand.position = Vector3(0.32 - s * 0.15, -0.28 + bob * 0.5, -0.5 - s * 0.2)
	if rod_tug > 0.0:
		# Something on the line: the rod jerks and bends toward it.
		var tt := Time.get_ticks_msec() * 0.001
		hand.rotation += Vector3(0.25 * rod_tug + sin(tt * 38.0) * 0.12 * rod_tug, 0, cos(tt * 31.0) * 0.08 * rod_tug)
		rod_tug = maxf(rod_tug - delta * 1.5, 0.0)

	if grabbed_by:
		_process_grabbed(delta)
		_update_focus()
		return
	# Kneeling over work on the ground, looking down at it.
	head.position.y = lerpf(head.position.y, work_spot.eye_height() if work_spot else 1.62, minf(delta * 3.0, 1.0))
	head.position.z = lerpf(head.position.z, work_spot.eye_back() + work_back if work_spot else 0.0, minf(delta * 3.0, 1.0))
	camera.fov = lerpf(camera.fov, 50.0 + work_view.z if work_spot else Settings.fov, minf(delta * 5.0, 1.0))
	camera.rotation.x = lerpf(camera.rotation.x, work_view.y if work_spot else 0.0, minf(delta * 5.0, 1.0))
	camera.rotation.y = lerpf(camera.rotation.y, work_view.x if work_spot else 0.0, minf(delta * 5.0, 1.0))
	held_mesh.visible = work_spot == null
	if work_spot and is_instance_valid(work_spot):
		var to: Vector3 = work_spot.look_point() - head.global_position
		var want := atan2(to.y, Vector2(to.x, to.z).length())
		_pitch = lerpf(_pitch, want, minf(delta * 5.0, 1.0))
		head.rotation.x = _pitch
		if work_spot.house:
			# Building a house you turn to face each step.
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(delta * 4.0, 1.0))
	camera.rotation.z = lerpf(camera.rotation.z, 0.0, minf(delta * 4.0, 1.0))
	if lie > 0.0:
		# Lying on your back: eyes near the ground, looking up at the sky.
		head.position.y = lerpf(1.62, 0.3, lie)
		_pitch = 1.45 * lie
		head.rotation.x = _pitch
	var sway: float = vitals.drunk_sway() if vitals_enabled else 0.0
	if sway > 0.0:
		# Very drunk: the world rolls and drifts.
		_drunk_t += delta
		camera.rotation.z += sin(_drunk_t * 1.3) * 0.09 * sway
		if not ui_open and not frozen and not vitals.dead and work_spot == null:
			_look(Vector2(sin(_drunk_t * 0.7) * 0.004, cos(_drunk_t * 0.9) * 0.002) * sway)
	if not ui_open and not frozen and not vitals.dead:
		var can_aim := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Settings.touch \
				or not Input.get_connected_joypads().is_empty()
		if can_aim and _attack_cd <= 0.0 and Input.is_action_pressed("attack") and hauling == null:
			_attack()
	_update_focus()
	_hold_take(delta)
	_update_plan()


func _update_plan() -> void:
	## Holding a blueprint shows the building where it would go: blue where
	## it can stand, red where it can't.
	var kind: String = Items.def(Game.inventory.held_id()).get("blueprint", "")
	var show := kind != "" and not ui_open and not vitals.dead and work_spot == null and hauling == null \
			and climbing == null and world != null and world.has_method("house_spot")
	if not show:
		if _plan:
			_plan.queue_free()
			_plan = null
		_plan_why = ""
		return
	var spot: Dictionary = world.house_spot(self)
	_plan_why = spot.why
	if _plan == null:
		_plan = House.new()
		_plan.preview = true
		_plan.world = world
		world.add_child(_plan)
	_plan.show_plan(spot.at, spot.yaw, spot.why == "")
	if focus == null:
		prompt = "Mark out the house site here [Right-click]" if _plan_why == "" else "Can't build here: " + _plan_why.trim_suffix(".").to_lower()


func _hold_take(delta: float) -> void:
	## Holding E on a pile keeps taking from it (one is taken on the press).
	if hauling or ui_open or focus == null or not focus.has_method("take_one") or focus.carried() \
			or not Input.is_action_pressed("interact"):
		_take_hold = 0.0
		return
	_take_hold += delta
	if _take_hold > 0.45:
		_take_hold -= 0.12
		if not focus.take_one(self):
			_take_hold = -INF


func _update_torch(delta: float) -> void:
	## A held light (lit torch) flickers; rain makes it very dim.
	var range_m: float = Items.def(_held_id).get("light", 0.0)
	_torch_light.visible = range_m > 0.0 and not vitals.dead
	if not _torch_light.visible:
		return
	var wet: bool = world != null and world.get("raining") == true
	_torch_flicker += delta * 11.0
	var f := 0.85 + 0.15 * sin(_torch_flicker) * sin(_torch_flicker * 1.9 + 0.7)
	_torch_light.omni_range = range_m * (0.4 if wet else 1.0)
	_torch_light.light_energy = (0.25 if wet else 0.9) * f


func _update_held_mesh() -> void:
	if _held_id == "":
		held_mesh.mesh = null
		return
	held_mesh.mesh = Assets.mesh("item_" + _held_id)
	var shape: String = Items.def(_held_id).get("shape", "")
	held_mesh.rotation = Vector3.ZERO
	held_mesh.position = Vector3.ZERO
	held_mesh.scale = Vector3.ONE
	match shape:
		"axe", "drill", "stick", "mattock", "torch", "torch_lit":
			# Long items lie along +X: stand them up, leaning away, gripped low.
			held_mesh.rotation = Vector3(-0.5, 0, PI * 0.5)
			held_mesh.position = held_mesh.basis * Vector3(0.18, 0, 0)
		"spear":
			held_mesh.rotation = Vector3(-1.15, 0, PI * 0.5)
			held_mesh.position = held_mesh.basis * Vector3(0.25, 0, 0)
		"rod", "fishing_rod":
			# Held by the butt, the tip out ahead and up.
			held_mesh.rotation = Vector3(-1.0, 0, PI * 0.5)
			held_mesh.position = held_mesh.basis * Vector3(0.5, 0, 0)
		"pipe", "segment", "injector":
			held_mesh.rotation = Vector3(0, PI * 0.5, 0)
			held_mesh.scale = Vector3.ONE * 0.6
		_:
			held_mesh.scale = Vector3.ONE * 0.9


# --- Interaction ----------------------------------------------------------------

func _ray(range_m: float, mask: int) -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * range_m
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	q.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(q)


func look_point(range_m: float) -> Vector3:
	## The solid ground (or tree, or boulder) under the crosshair, or INF.
	var hit := _ray(range_m, 1)
	return hit.position if hit else Vector3.INF


func _update_focus() -> void:
	focus = null
	focus_water = false
	_water_at = Vector3.INF
	prompt = ""
	tooltip = ""
	if ui_open or vitals.dead or grabbed_by:
		return
	if vitals.pressing >= 0:
		prompt = "Pressing on the wound: %d s more. Moving lets go." % ceili(pressure_left())
		return
	if hauling and climbing:
		return  # nothing to do with it until you are off the ladder
	if hauling:
		if hauling.has_method("haul_prompt"):
			_look_at_water(_ray(INTERACT_RANGE, 1 | 2))
			prompt = hauling.haul_prompt(self)
		else:
			prompt = "%s the %s [E]" % ["Drop" if hauling.haul_mode() == "drag" else "Put down", hauling.haul_name()]
		return
	var hit := _ray(INTERACT_RANGE, 1 | 2)
	if hit:
		var c: Object = hit.collider
		if not c.has_method("interact") and c.get_parent() and c.get_parent().has_method("interact"):
			c = c.get_parent()
		if c.has_method("interact"):
			focus = c
			prompt = c.prompt(self) if c.has_method("prompt") else "Interact [E]"
			tooltip = c.tooltip(self) if c.has_method("tooltip") else ""
			return
	if _look_at_water(hit):
		var held: String = Game.inventory.held_id()
		if Items.def(held).has("hold") and _water_at.is_finite():
			prompt = "Fill %s [E]" % Items.item_name(held)
		else:
			prompt = "Drink swamp water [E]"


func _look_at_water(hit: Dictionary) -> bool:
	## Whether the view meets the water within reach (or you stand in it);
	## sets focus_water, and where the view meets it (_water_at).
	var wl := water_level()
	if wl == -INF:
		return false
	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	if o.y > wl and d.y < -0.05:
		var t := (wl - o.y) / d.y
		var hit_dist: float = o.distance_to(hit.position) if hit else INF
		if t < INTERACT_RANGE + 0.5 and t < hit_dist + 0.05:
			focus_water = true
			_water_at = o + d * t
	elif o.y <= wl + 0.2:
		focus_water = true
	return focus_water


func water_point() -> Vector3:
	## The water you are looking at (or standing in).
	if _water_at.is_finite():
		return _water_at
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var p := global_position + fwd.normalized() * 1.5
	return Vector3(p.x, water_level(), p.z)


func _interact() -> void:
	if focus and is_instance_valid(focus):
		focus.interact(self)
		return
	if focus_water:
		var held: String = Game.inventory.held_id()
		var fill: String = Items.def(held).get("hold", "")
		if fill != "":
			Game.inventory.replace(Game.inventory.selected, fill)
			Sfx.play("splash", -6.0)
			Game.notify("Filled with murky swamp water.")
		else:
			vitals.consume({"water": 12.0, "sick": 0.25}, _rng)
			Sfx.play("drink", -4.0)


func _use_held() -> void:
	# Right-click on something with its own use (a fermentation vessel opens).
	if focus and is_instance_valid(focus) and focus.has_method("use_interact"):
		focus.use_interact(self)
		return
	var inv = Game.inventory
	var id: String = inv.held_id()
	if id == "":
		return
	var def := Items.def(id)
	if id == "compost":
		# Worked in round a growing plant, it hurries it on (plot.gd).
		if focus and is_instance_valid(focus) and focus.has_method("feed") and focus.feed(self):
			inv.take(inv.selected, 1)
		else:
			Game.notify("Right-click a growing plant to work the compost in, or set it in a hole with a seed or root.")
		return
	if "dig" in def.get("tags", []):
		dig_hole()
		return
	if def.get("fishing", false):
		if fishing and is_instance_valid(fishing):
			fishing.reel()
		else:
			cast_rod()
		return
	if def.has("blueprint"):
		if world and world.has_method("place_blueprint") and world.place_blueprint(def.blueprint, self):
			inv.take(inv.selected, 1)
		return
	if def.has("place"):
		if world and world.has_method("place"):
			var pos := global_position - transform.basis.z * 1.6
			if world.place(def.place, pos, id):
				inv.take(inv.selected, 1)
		return
	if Items.is_food(id):
		consume_slot(inv.selected)
		return
	if def.has("treat"):
		treat_slot(inv.selected)
		return
	if def.has("hold") and focus_water:
		_interact()
		return
	if def.get("throw", false):
		throw_held()


func dig_hole() -> void:
	## Dig a hole with the held mattock in the ground you are looking at.
	if _attack_cd > 0.0 or world == null or not world.has_method("dig_hole"):
		return
	var at := look_point(float(Items.def(Game.inventory.held_id()).get("reach", 2.3)) + 0.5)
	if not at.is_finite():
		Game.notify("Aim at the ground nearby to dig a hole.")
		return
	_attack_cd = THROW_COOLDOWN
	_swing = 0.0
	if world.dig_hole(at):
		vitals.stamina = maxf(vitals.stamina - 6.0, 0.0)


func throw_held() -> void:
	## Throw the held stone where you are looking.
	var inv = Game.inventory
	if _attack_cd > 0.0 or world == null or inv.held() == null:
		return
	var item: Dictionary = inv.take(inv.selected, 1)
	_attack_cd = THROW_COOLDOWN
	_swing = 0.0
	vitals.stamina = maxf(vitals.stamina - 3.0, 0.0)
	var dir := -camera.global_transform.basis.z
	var from := camera.global_position + dir * 0.4 + Vector3(0, -0.1, 0)
	var v := dir * THROW_SPEED + Vector3(0, 1.5, 0) + velocity * 0.5
	world.add_child(ThrownRock.new().setup(item.id, from, v, self, world))
	Sfx.play("swing", -6.0)


func cast_rod() -> void:
	## Casts the held fishing rod where you are looking, the hook flying like a
	## thrown stone. Not without bait on it.
	var inv = Game.inventory
	var s = inv.held()
	if s == null or world == null or _attack_cd > 0.0:
		return
	var bait: String = s.get("data", {}).get("bait", "")
	if bait == "":
		Game.notify("There's no bait on this rod. Press %s to kneel, lay out the rod and some bait, and bait it." % Settings.button_name("craft"))
		return
	_attack_cd = THROW_COOLDOWN
	_swing = 0.0
	var dir := -camera.global_transform.basis.z
	var from := camera.global_position + dir * 0.4 + Vector3(0, -0.1, 0)
	var v := dir * THROW_SPEED + Vector3(0, 1.5, 0) + velocity * 0.5
	fishing = Fishing.new().setup(self, world, from, v, bait)
	world.add_child(fishing)
	Sfx.play("swing", -6.0)


func consume_slot(i: int) -> void:
	var inv = Game.inventory
	var s = inv.slots[i]
	if s == null or not vitals_enabled:
		return
	var def: Dictionary = inv.def_of(i)
	if not Items.is_food(s.id):
		return
	vitals.consume(def, _rng)
	Sfx.play("drink" if def.get("water", 0.0) > def.get("energy", 0.0) else "eat", -4.0)
	if _use_measure(i, def):
		pass
	elif def.has("empty") and s.n == 1:
		# What is left keeps the slot: an emptied pot, or a canteen's other
		# serving (still the same soup, as old as it was).
		var rest := Items.is_food(def.empty)
		inv.replace(i, def.empty, s.age if rest else 0.0, s.get("data", {}) if rest else {})
	else:
		inv.take(i, 1)
		if def.has("empty"):
			inv.add(def.empty, 1, 0.0, true)
	Game.crafted.emit("ate_" + s.id)


func _use_measure(i: int, def: Dictionary) -> bool:
	## An item used a measure at a time (a canteen of alcohol): one less in it,
	## or the empty canteen once the last is gone. False for anything else.
	if not def.has("measures"):
		return false
	var inv = Game.inventory
	var s: Dictionary = inv.slots[i]
	var left := int(s.get("data", {}).get("left", def.measures)) - 1
	if left > 0:
		inv.replace(i, s.id, s.age, Items.measures_data(s.id, left))
	else:
		inv.replace(i, "canteen")
	return true


func treat_slot(i: int, wound := -1) -> bool:
	## Uses a treatment from slot i on wound index `wound` (or the wound that
	## needs it most): boiled water washes, alcohol cleans and fights
	## infection, a bandage or wax covers (see Survival).
	var inv = Game.inventory
	var s = inv.slots[i]
	if s == null or not vitals_enabled:
		return false
	var def := Items.def(s.id)
	var kind: String = def.get("treat", "")
	var why := ""
	match kind:
		"clean", "alcohol":
			if not vitals.wash(wound, kind == "alcohol"):
				why = "You have no wounds that need washing." if not vitals.wounds.is_empty() else "You have no wounds that need that."
			else:
				Game.notify("You wash out your wounds with boiled water." if kind == "clean" else "You clean the wound with alcohol. It burns.")
		"bandage", "wax":
			why = vitals.cover(wound, kind)
			if why == "":
				Game.notify("You bind the wound." if kind == "bandage" else "You seal the wound with wax.")
		_:
			why = "That won't help your wounds."
	if why != "":
		Game.notify(why)
		return false
	if _use_measure(i, def):
		pass
	elif def.has("empty") and s.n == 1:
		inv.replace(i, def.empty)
	else:
		inv.take(i, 1)
		if def.has("empty"):
			inv.add(def.empty, 1, 0.0, true)
	Sfx.play("craft", -10.0)
	Game.crafted.emit("treated_" + s.id)
	return true


func _drop_held() -> void:
	var inv = Game.inventory
	var s = inv.held()
	if s == null or world == null or not world.has_method("spawn_pickup"):
		return
	var item: Dictionary = inv.take(inv.selected, 1)
	var pos := drop_point()
	if Items.def(item.id).get("splat", false) and world.has_method("splat_guts"):
		world.splat_guts(pos)
		return
	if world.has_method("pile_item"):
		world.pile_item(item.id, 1, pos, item.age, item.get("data", {}))  # raw materials go on a pile there
		return
	world.spawn_pickup(item.id, 1, pos, item.age, true, item.get("data", {}))


func drop_point() -> Vector3:
	## Where a dropped item lands: a metre in front at chest height, or short
	## of a trunk, wall or anything else solid in the way, never inside it.
	var from := global_position + Vector3(0, 0.8, 0)
	var to := from - transform.basis.z * DROP_REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var back: float = maxf(from.distance_to(hit.position) - DROP_CLEARANCE, 0.0)
	return from + (to - from).normalized() * back


# --- Carrying and dragging ----------------------------------------------------------
# A medium carcass or a log is carried in front of you at walking pace; a large
# carcass is dragged at half that. Either way your hands are full: no sprinting,
# no using or picking things up, no bag and no crafting until you put it down
# (Q or E). What can be hauled has can_haul, haul_mode, haul_name, haul_radius,
# haul_yaw, haul_lift and set_hauled (creature.gd, wood_log.gd).

func start_haul(c: Node3D) -> void:
	if hauling or c == null or not c.can_haul():
		return
	hauling = c
	c.set_hauled(self)
	_hold_haul()
	Sfx.play("pickup", -4.0)
	if Game.hints_seen.get("haul", false) == false and not c.is_in_group("workbenches"):
		Game.hints_seen["haul"] = true
		Game.notify("%s it. Put it down with Q or E; kneel beside it (C) to %s it." % ["Dragging" if c.haul_mode() == "drag" else "Carrying",
				"butcher" if "species" in c else "work"])


func put_down() -> void:
	## Lays what you are carrying on the ground in front of you.
	var c := hauling
	if c and climbing:
		Game.notify("Climb off the ladder before you set the %s down." % c.haul_name())
		return
	if c and is_instance_valid(c) and c.has_method("can_put_down") and not c.can_put_down():
		return  # a workbench needs room to stand
	hauling = null
	if c == null or not is_instance_valid(c):
		return
	c.set_hauled(null)
	Sfx.play("step", -4.0)


func _hold_haul() -> void:
	## It rides in front of you: held up at chest height, or, a big carcass,
	## lying on the ground (or a house's floor), dragged along by the head. On
	## a rope ladder it is slung on your back, out from the house.
	var c := hauling
	if not is_instance_valid(c) or c.is_queued_for_deletion() or not c.can_haul():
		hauling = null
		return
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var r: float = c.haul_radius()
	var at: Vector3
	if climbing:
		var out: Vector3 = climbing.global_basis.z
		at = global_position + out * (r + 0.35) + Vector3(0, 0.5, 0)
		c.rotation.y = climbing.rotation.y + c.haul_yaw()
	elif c.haul_mode() == "drag":
		at = global_position + fwd * (r * 1.6 + 0.9)
		var g: float = world.floor_height(Vector3(at.x, global_position.y, at.z)) if world and world.has_method("floor_height") else global_position.y
		at.y = maxf(g, water_level() - 0.3)
		c.rotation.y = rotation.y
	else:
		at = global_position + fwd * (r + 0.55) + Vector3(0, c.haul_lift(), 0)
		c.rotation.y = rotation.y + c.haul_yaw()
	c.global_position = at


# --- Combat ---------------------------------------------------------------------

func _attack() -> void:
	var def := Items.def(Game.inventory.held_id())
	var dmg: float = def.get("damage", FIST_DAMAGE)
	var reach: float = def.get("reach", 1.8)
	_attack_cd = 0.75 if reach > 3.0 else 0.55
	if vitals.stamina < 5.0:
		_attack_cd += 0.5
		dmg *= 0.5
	vitals.stamina = maxf(vitals.stamina - 6.0, 0.0)
	_swing = 0.0
	Sfx.play("swing", -8.0)

	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	var best: Node3D = null
	var best_t := reach
	for c in Game.creatures:
		if not is_instance_valid(c) or c.dead or c.submerged:
			continue
		var to: Vector3 = c.hit_center() - o
		var t := to.dot(d)
		if t < 0.0 or t > best_t + c.hit_radius:
			continue
		var miss := (to - d * t).length()
		if miss < c.hit_radius:
			best = c
			best_t = t
	if best:
		var hit := _ray(best_t, 1)
		if hit and o.distance_to(hit.position) < best_t - 0.3:
			return  # a tree or wall is in the way
		best.take_damage(dmg, self)
		Sfx.play_at("hit", best.hit_center(), -2.0)
		if Game.inventory.held_id() == "" and best.def.get("fish", {}).get("spines", false):
			# Punching a live acanthodian bare-fisted: its fin spines jab back.
			hurt(SPINE_PRICK, best.global_position, 0.2, "spines")
			Game.notify("The %s's fin spines jab your hand." % best.def.name)
	elif "dig" in def.get("tags", []):
		# A mattock knocks a campfire apart (or a workbench loose), or digs out a stump.
		var hit := _ray(reach, 1 | 2)
		if hit:
			var c: Node = hit.collider
			for n in [c, c.get_parent()]:
				if n and n.has_method("break_apart"):
					n.break_apart()
					break
				if n and n.has_method("dig"):
					n.dig()
					break
	elif "chop" in def.get("tags", []):
		# An axe hacks at a house site to tear it down, or knocks a workbench loose.
		var hit := _ray(reach, 1 | 2)
		if hit:
			var c: Node = hit.collider
			for n in [c, c.get_parent()]:
				if n and n.has_method("axe_hit"):
					n.axe_hit()
					break


func hurt(amount: float, from: Vector3, dirt := 0.3, source := "") -> void:
	## A blow from a creature (from != ZERO): blood lost at once, a wound that
	## bleeds by how deep it is, a dressed wound torn open, and from a hard
	## enough hit perhaps a broken arm or leg. Otherwise just blood lost.
	if vitals.dead:
		return
	stop_pressure()
	if from != Vector3.ZERO and amount >= 3.0:
		vitals.reopen()
		vitals.add_wound(amount / 40.0, dirt, source)
		if amount >= FRACTURE_FROM and _injury_roll() < clampf((amount - 12.0) / 40.0, 0.0, 0.6):
			var limb := "arm" if _rng.randf() < 0.5 else "leg"
			if vitals.limbs.has(limb):
				limb = "leg" if limb == "arm" else "arm"
			vitals.break_limb(limb)
	vitals.lose_blood(amount * TRAUMA if from != Vector3.ZERO else amount)
	_shake = clampf(_shake + amount * 0.06, 0.0, 1.0)
	hurt_flash.emit(amount)
	Sfx.play("hurt", -2.0)
	if work_spot and world and world.has_method("close_work"):
		world.close_work()  # startled to your feet
	if from != Vector3.ZERO:
		var push := (global_position - from)
		push.y = 0.0
		velocity += push.normalized() * minf(amount * 0.4, 5.0) + Vector3(0, 1.5, 0)


func _injury_roll() -> float:
	var r := next_injury if next_injury >= 0.0 else _rng.randf()
	next_injury = -1.0
	return r


func _check_fall(wet: bool) -> void:
	## Coming down hard from a height may sprain an ankle or break a leg, one
	## or the other, as likely as each other.
	if flying or wet or grabbed_by or climbing:
		_air_top = -INF
		return
	if not is_on_floor():
		_air_top = maxf(_air_top, global_position.y)
		return
	if _air_top == -INF:
		return
	var drop := _air_top - global_position.y
	_air_top = -INF
	landed(drop)


func landed(drop: float) -> void:
	## Came down from `drop` metres.
	if drop <= FALL_SAFE or vitals.dead:
		return
	Sfx.play("hurt", -6.0)
	_shake = clampf(_shake + 0.5, 0.0, 1.0)
	if _injury_roll() < clampf(0.25 + (drop - FALL_SAFE) / FALL_RISK * 0.75, 0.0, 1.0):
		vitals.break_limb("ankle" if _rng.randf() < 0.5 else "leg")
		stop_pressure()


# --- Pressure on a wound ------------------------------------------------------------
# From the Health tab: you hold still and press on a bleeding wound for
# Survival.PRESSURE_TIME. Moving, being hit or seized lets go.

func start_pressure(wound := -1) -> bool:
	if vitals.dead or grabbed_by or hauling:
		if hauling:
			Game.notify("Put down what you're carrying first (Q).")
		return false
	if wound < 0:
		for k in vitals.wounds.size():
			if vitals.wounds[k].bleed > 0 and (wound < 0 or vitals.wounds[k].bleed > vitals.wounds[wound].bleed):
				wound = k
	if wound < 0 or wound >= vitals.wounds.size() or vitals.wounds[wound].bleed == 0:
		Game.notify("Nothing is bleeding.")
		return false
	vitals.pressing = wound
	_press_t = 0.0
	velocity = Vector3(0, velocity.y, 0)
	return true


func stop_pressure(say := false) -> void:
	if vitals.pressing >= 0 and say:
		Game.notify("You let go of the wound.")
	vitals.pressing = -1
	_press_t = 0.0


func pressure_left() -> float:
	return maxf(Survival.PRESSURE_TIME - _press_t, 0.0) if vitals.pressing >= 0 else 0.0


func _hold_pressure(delta: float, input: Vector2) -> void:
	if input != Vector2.ZERO or Input.is_action_just_pressed("jump") or vitals.pressing >= vitals.wounds.size() \
			or vitals.wounds[vitals.pressing].bleed == 0:
		stop_pressure(input != Vector2.ZERO)
		return
	_press_t += delta
	if _press_t >= Survival.PRESSURE_TIME:
		var k := vitals.pressing
		stop_pressure()
		vitals.apply_pressure(k)


func _on_died() -> void:
	stop_pressure()
	put_down()
	if work_spot and world and world.has_method("close_work"):
		world.close_work()
	capture_mouse(false)
	if grabbed_by and is_instance_valid(grabbed_by):
		grabbed_by.victim_died()
	died.emit()


# --- Seized by an amphibian -------------------------------------------------------
# The creature lunges and clamps its jaws on you. Your view is wrenched round to
# face it and you are pulled down toward the water. Stab it fast (attack) to
# break its grip before it drowns you; without good gear you rarely do.

func start_grab(creature: Node3D) -> void:
	if grabbed_by or vitals.dead:
		return
	stop_pressure()
	put_down()
	grabbed_by = creature
	grip_max = creature.def.get("grip", 100.0)
	grip = grip_max
	strike_tier = ""
	escape_roll = -1.0
	_grab_t = 0.0
	_attack_cd = 0.25
	velocity = Vector3.ZERO
	if ui_open and world and world.has_method("close_ui"):
		world.close_ui()
	# Wrench the view round to stare into its jaws.
	var to: Vector3 = creature.head_position() - global_position
	rotation.y = atan2(-to.x, -to.z)
	_pitch = -0.35
	head.rotation.x = _pitch
	camera.rotation.z = 0.5
	_shake = 1.0
	Sfx.play("roar", 2.0, 0.05)
	hurt(creature.def.get("bite", GRAB_BITE), creature.global_position, 0.85, "amphibian")
	Game.crafted.emit("grabbed")


func _physics_grabbed(delta: float) -> void:
	var c := grabbed_by
	if not is_instance_valid(c):
		release_grab()
		return
	# Held in front of the jaws and dragged along with them.
	var anchor: Vector3 = c.grab_anchor()
	global_position = global_position.lerp(anchor, minf(delta * 6.0, 1.0))
	velocity = Vector3.ZERO
	if vitals_enabled:
		vitals.tick(delta, false, false, water_depth() > 0.25)


func _process_grabbed(delta: float) -> void:
	var c := grabbed_by
	if not is_instance_valid(c):
		release_grab()
		return
	_grab_t += delta
	var depth := water_depth()
	var dps: float = c.def.get("grab_dps", GRAB_DPS)
	vitals.lose_blood(dps * (1.5 if depth > 1.0 else 1.0) * delta)
	hurt_flash.emit(dps * delta * 0.4)
	if vitals.dead:
		return
	if rolls_for_escape() and escape_roll < 0.0 and (_grab_t >= ROLL_TIME or (_grab_t >= MIN_ROLL_TIME and c.in_deep_water())):
		_roll_escape()
		if grabbed_by == null:
			return
	# Keep the head low and the view locked on the jaws, thrashing.
	head.position.y = lerpf(head.position.y, 0.7, minf(delta * 5.0, 1.0))
	var to: Vector3 = c.head_position() - camera.global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(delta * 6.0, 1.0))
	_pitch = lerpf(_pitch, clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 0.6), minf(delta * 6.0, 1.0))
	head.rotation.x = _pitch
	camera.rotation.z = 0.35 + sin(_grab_t * 9.0) * 0.12
	_shake = maxf(_shake, 0.35)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if not frozen and _attack_cd <= 0.0 and Input.is_action_just_pressed("attack"):
		stab()


func rolls_for_escape() -> bool:
	## Whether the creature holding you lets go on a dice roll rather than
	## when its grip is broken.
	return is_instance_valid(grabbed_by) and grabbed_by.def.get("escape", false)


func escape_chance() -> float:
	return ESCAPE_BASE + ESCAPE_BONUS[strike_tier]


func _roll_escape() -> void:
	var c := grabbed_by
	var chance := escape_chance()
	escape_roll = next_roll if next_roll >= 0.0 else randf()
	next_roll = -1.0
	var freed := escape_roll < chance
	escape_rolled.emit(chance, escape_roll, freed)
	if freed:
		c.release(true)
		release_grab()
		velocity = Vector3(0, 1.5, 0)
		Game.notify("It lets go! You are out in deep water. Swim for the bank!")
	else:
		Game.notify("Its jaws only clamp tighter...")


func stab_power() -> float:
	## How much grip one stab breaks, by what you hold.
	var def := Items.def(Game.inventory.held_id())
	var p := 2.5
	if def.has("damage"):
		p = 4.0 + def.damage * 0.5
		if def.get("reach", 0.0) > 3.0:
			p *= 0.6   # a spear is too long to use in the jaws
	if vitals.stamina < 5.0:
		p *= 0.5
	return p


func stab() -> void:
	var c := grabbed_by
	if not is_instance_valid(c):
		return
	_attack_cd = STAB_COOLDOWN
	_swing = 0.0
	vitals.stamina = maxf(vitals.stamina - 4.0, 0.0)
	var def := Items.def(Game.inventory.held_id())
	c.take_damage(def.get("damage", FIST_DAMAGE), self)
	Sfx.play("hit", -2.0, 0.2)
	if rolls_for_escape():
		var tier: String = def.get("tier", "bare")
		if ESCAPE_BONUS[tier] > ESCAPE_BONUS[strike_tier]:
			strike_tier = tier
		return
	grip -= stab_power()
	if grip <= 0.0:
		var away: Vector3 = global_position - c.global_position
		away.y = 0.0
		c.release(true)
		release_grab()
		velocity = away.normalized() * 4.0 + Vector3(0, 2.5, 0)
		Game.notify("It lets go! Get away from the water!")


func release_grab() -> void:
	grabbed_by = null
	grip = 0.0
	_pitch = clampf(_pitch, -1.2, 1.2)
