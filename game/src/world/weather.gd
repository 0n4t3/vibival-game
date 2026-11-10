extends Node3D
## Rare weather. From day 3 on, each day has a 1-in-5 chance of one unusual
## event: dense fog, an aurora, a very bright moon, a meteor shower, a
## thunderstorm, high winds or wildfire smoke. The night-sky events last the
## whole night; the others 6-12 minutes at some time of the day. Ordinary rain
## is left to the swamp.
##
## The swamp calls update() every frame (and with long steps while you sleep)
## and apply_sky() after it has lit the scene, so an event only ever adjusts
## what the normal day/night cycle set up.

const KINDS := ["fog", "aurora", "bright_moon", "meteors", "thunderstorm", "wind", "smoke"]
const NIGHT_KINDS := ["aurora", "bright_moon", "meteors"]
const NAMES := {
	"fog": "Dense fog", "aurora": "Aurora", "bright_moon": "Bright moon", "meteors": "Meteor shower",
	"thunderstorm": "Thunderstorm", "wind": "High winds", "smoke": "Wildfire smoke",
}
const START_TEXT := {
	"fog": "A thick fog rolls in off the water.",
	"aurora": "Curtains of green light ripple across the sky.",
	"bright_moon": "The moon rises huge and bright.",
	"meteors": "Shooting stars streak across the sky.",
	"thunderstorm": "Thunder rumbles. A storm is coming.",
	"wind": "The wind picks up, roaring through the trees.",
	"smoke": "The air turns hazy and red. Somewhere, the forest is burning.",
}
# A night-sky event shows faintly from the start of dusk (DUSK_START), before
# it begins in the dark: a hint of what is coming.
const HINT_TEXT := {
	"aurora": "You see faint shimmers in the sky, and wonder if they'll get brighter after sunset.",
	"meteors": "You see faint streaks of light in the sky, and wonder if they'll be more visible after sunset.",
}
const END_TEXT := {
	"fog": "The fog thins and lifts.",
	"thunderstorm": "The storm moves on.",
	"wind": "The wind dies down.",
	"smoke": "The smoke clears.",
}
const FIRST_DAY := 2         # Game.day() is 0-based: day 3
const CHANCE := 0.2          # of an event on any one day
const LENGTH := [360.0, 720.0]
const FADE := 30.0           # seconds to come and go
const DUSK_START := 1140.0   # clock: dusk begins (solar 0.7), when HINT_TEXT shows
const NIGHT_START := 1260.0  # clock: full dark (solar 0.8), when night-sky events begin
const NIGHT_END := 180.0     # clock: dawn (solar 0.2), the next day
const WIND_SPEED := [11.0, 16.0]

var swamp: Node = null
var kind := ""          # the event under way, or ""
var left := 0.0         # seconds until it is over
var planned := ""       # today's event, still to come
var planned_at := 0.0   # Game.time it begins
var planned_len := 0.0
var hinted := false     # the dusk hint of tonight's night-sky event is given
var rolled_day := -1
var fade := 0.0         # 0..1: how far it has come in (or gone)
var flash := 0.0        # lightning, 0..1
var wind_dir := Vector3.FORWARD
var wind_speed := 0.0
var strikes := 0        # lightning strikes so far this storm

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _bolt_t := 0.0
var _meteor_t := 0.0
var _meteors := []      # [{a, b, t, life}]
var _radiant := 0.0     # azimuth the meteors come from
var _bolt := PackedVector3Array()
var _bolt_life := 0.0
var _bolt_total := 0.0
var _thunder := []      # [seconds until heard, volume]
var _aurora: MeshInstance3D
var _aurora_mat: ShaderMaterial
var _moon: MeshInstance3D
var _streaks: MeshInstance3D
var _streak_mesh: ImmediateMesh
var _wind_sound: AudioStreamPlayer
var _ash: CPUParticles3D
var _storm_rain: CPUParticles3D


func _ready() -> void:
	_rng.seed = Game.world_seed * 31 + 7
	_build_aurora()
	_build_moon()
	_streak_mesh = ImmediateMesh.new()
	_streaks = MeshInstance3D.new()
	_streaks.mesh = _streak_mesh
	_streaks.material_override = _glow_material()
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.top_level = true
	_streaks.extra_cull_margin = 16384.0
	add_child(_streaks)
	_wind_sound = AudioStreamPlayer.new()
	_wind_sound.stream = Sfx.stream("wind")
	_wind_sound.volume_db = -60.0
	add_child(_wind_sound)
	_ash = CPUParticles3D.new()
	_ash.amount = [80, 160, 260][Settings.quality]
	_ash.lifetime = 6.0
	_ash.emitting = false
	_ash.local_coords = false
	_ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ash.emission_box_extents = Vector3(18, 4, 18)
	_ash.direction = Vector3(0.3, -1, 0.1)
	_ash.spread = 30.0
	_ash.initial_velocity_min = 0.3
	_ash.initial_velocity_max = 0.8
	_ash.gravity = Vector3(0, -0.25, 0)
	var flake := QuadMesh.new()
	flake.size = Vector2(0.05, 0.05)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.32, 0.3, 0.28)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = fm
	_ash.mesh = flake
	add_child(_ash)


# --- Scheduling -------------------------------------------------------------------------

func roll_day(day: int) -> String:
	## Whether a day gets an event, and which: "" for an ordinary day.
	if day < FIRST_DAY or _rng.randf() >= CHANCE:
		return ""
	return KINDS[_rng.randi() % KINDS.size()]


func day_start(day: int) -> float:
	## Game.time at midnight starting that day.
	return day * Game.DAY_LENGTH - Game.ARRIVAL_CLOCK


func plan(k: String, day: int) -> void:
	## Picks when today's event happens: night-sky events from dusk until dawn,
	## the others for 6-12 minutes at a random time of the day still to come.
	planned = k
	hinted = false
	if k in NIGHT_KINDS:
		planned_at = day_start(day) + NIGHT_START
		planned_len = Game.DAY_LENGTH - NIGHT_START + NIGHT_END
	else:
		planned_len = _rng.randf_range(LENGTH[0], LENGTH[1])
		var lo := maxf(Game.time + 60.0, day_start(day))
		var hi := maxf(day_start(day + 1) - planned_len, lo)
		planned_at = _rng.randf_range(lo, hi)


func start(k: String, seconds := -1.0) -> void:
	## Begins an event now (the debug panel uses this too). Night-sky events
	## started by day still wait for the dark to show.
	if kind != "":
		_finish(true)
	kind = k
	if seconds < 0.0:
		if k in NIGHT_KINDS:
			var clock := Game.clock()
			seconds = (NIGHT_END + Game.DAY_LENGTH - clock) if clock > NIGHT_END else NIGHT_END - clock
		else:
			seconds = _rng.randf_range(LENGTH[0], LENGTH[1])
	left = seconds
	fade = 0.0
	strikes = 0
	_radiant = _rng.randf() * TAU
	_bolt_t = _rng.randf_range(4.0, 10.0)
	if k == "wind" or k == "thunderstorm":
		var a := _rng.randf() * TAU
		wind_dir = Vector3(cos(a), 0, sin(a))
		wind_speed = _rng.randf_range(WIND_SPEED[0], WIND_SPEED[1]) * (1.0 if k == "wind" else 0.45)
	if k == "wind":
		_wind_sound.play()
	Game.notify(START_TEXT[k])


func stop() -> void:
	## Ends the event at once (debug).
	if kind != "":
		_finish(true)


func _finish(now: bool) -> void:
	if END_TEXT.has(kind) and not now:
		Game.notify(END_TEXT[kind])
	kind = ""
	left = 0.0
	if now:
		fade = 0.0
	wind_speed = 0.0
	_meteors.clear()
	_bolt_life = 0.0


func update(delta: float) -> void:
	var day := Game.day()
	if day != rolled_day:
		rolled_day = day
		if planned == "" and kind == "":
			var k := roll_day(day)
			if k != "":
				plan(k, day)
	if planned in HINT_TEXT and not hinted and Game.time >= planned_at - (NIGHT_START - DUSK_START) and Game.time < planned_at:
		hinted = true
		Game.notify(HINT_TEXT[planned])
	if planned != "" and Game.time >= planned_at:
		var late := Game.time - planned_at
		var k := planned
		planned = ""
		if late < planned_len:
			start(k, planned_len - late)
	if kind != "":
		left -= delta
		fade = minf(fade + delta / FADE, minf(1.0, maxf(left, 0.0) / FADE))
		if left <= 0.0:
			_finish(false)
	else:
		fade = maxf(fade - delta / FADE, 0.0)
	_time += delta
	_update_wind(delta)
	if delta > 1.0:
		return  # asleep: nothing to see or hear
	_update_storm(delta)
	_update_meteors(delta)
	_update_visuals()


func storm() -> bool:
	return kind == "thunderstorm"


func wind() -> Vector3:
	## The wind's velocity, m/s, with gusts.
	if wind_speed <= 0.0:
		return Vector3.ZERO
	var gust := 0.75 + 0.2 * sin(_time * 0.7) + 0.15 * sin(_time * 2.3 + 1.0)
	return wind_dir * wind_speed * gust * fade


func _update_wind(delta: float) -> void:
	var w := wind()
	if swamp:
		swamp.wind = w
	# Trees and plants lean with it; a gale is about 1.
	var lean := w / WIND_SPEED[1]
	for m in [Assets.material("foliage"), Assets.material("bark")]:
		if m is ShaderMaterial:
			m.set_shader_parameter("wind", lean)
	var target := lerpf(-40.0, -4.0, clampf(w.length() / WIND_SPEED[1], 0.0, 1.0)) if kind == "wind" else -60.0
	_wind_sound.volume_db = move_toward(_wind_sound.volume_db, target, minf(delta, 1.0) * 20.0)
	if _wind_sound.playing and kind != "wind" and _wind_sound.volume_db <= -59.0:
		_wind_sound.stop()


# --- Thunderstorm -----------------------------------------------------------------------

func _update_storm(delta: float) -> void:
	flash = maxf(flash - delta * 6.0, 0.0)
	_bolt_life = maxf(_bolt_life - delta, 0.0)
	for t in _thunder.duplicate():
		t[0] -= delta
		if t[0] <= 0.0:
			Sfx.play("thunder", t[1], 0.15)
			_thunder.erase(t)
	if storm():
		if _storm_rain == null and swamp:
			_storm_rain = swamp._rain.duplicate()
			swamp.add_child(_storm_rain)
		_bolt_t -= delta
		if _bolt_t <= 0.0 and fade > 0.3:
			_bolt_t = _rng.randf_range(1.5, 7.0) / fade
			lightning()
	if _storm_rain:
		_storm_rain.emitting = storm()
		if swamp and swamp.player:
			_storm_rain.global_position = swamp.player.global_position + Vector3(0, 12, 0)
		var w := wind()
		_storm_rain.direction = Vector3(w.x * 0.04, -1, w.z * 0.04)
	if Game.player and is_instance_valid(Game.player):
		_ash.global_position = Game.player.global_position + Vector3(0, 4, 0)
	_ash.emitting = kind == "smoke" and fade > 0.2


func lightning() -> Vector3:
	## A flash and a distant bolt, with thunder a moment later. It never hits
	## the player or anything in the world (only the arrival's strike() does).
	strikes += 1
	flash = _rng.randf_range(0.7, 1.0)
	var cam := _camera_pos()
	var r := _sky_radius()
	var a := _rng.randf() * TAU
	var d := _rng.randf_range(0.35, 0.75) * r
	var ground := cam + Vector3(cos(a), 0, sin(a)) * d
	ground.y = swamp.ground_height(ground.x, ground.z) if swamp else 0.0
	ground.y = maxf(ground.y, 0.0)
	_make_bolt(ground, r * 0.55, 4.0)
	_bolt_life = 0.35
	_bolt_total = 0.35
	var secs := clampf(d / 343.0, 0.3, 5.0)
	_thunder.append([secs, lerpf(4.0, -6.0, d / r)])
	return ground


func strike(ground: Vector3, life := 0.5) -> void:
	## A bolt that hits right here, close by: a blinding flash and the thunder
	## at once (the arrival, intro.gd, where it sets a tree alight). Works in
	## any weather. It flickers for half a second, then fades over the rest
	## of its life.
	flash = 1.0
	_make_bolt(ground, 70.0, 2.5)
	_bolt_life = life
	_bolt_total = life
	Sfx.play("thunder", 6.0, 0.05)


func _make_bolt(ground: Vector3, height: float, wander: float) -> void:
	_bolt = PackedVector3Array()
	var top := ground + Vector3(_rng.randf_range(-15, 15) * wander / 4.0, height, _rng.randf_range(-15, 15) * wander / 4.0)
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		var p := top.lerp(ground, k)
		if i > 0 and i < n:
			p += Vector3(_rng.randf_range(-wander, wander), _rng.randf_range(-2, 2), _rng.randf_range(-wander, wander))
		_bolt.append(p)


# --- Night sky --------------------------------------------------------------------------

func _night() -> float:
	## 1 in full dark, 0 by day.
	var t := Game.time_of_day()
	var elev := sin((t - 0.25) * TAU)
	return 1.0 - smoothstep(-0.25, 0.02, elev)


func _update_meteors(delta: float) -> void:
	if kind == "meteors" and _night() > 0.3:
		_meteor_t -= delta
		if _meteor_t <= 0.0:
			# They streak out from one point in the sky (the radiant), high up.
			_meteor_t = _rng.randf_range(0.05, 0.5)
			var az := _radiant + _rng.randf_range(-1.4, 1.4)
			var el := _rng.randf_range(0.3, 1.2)
			var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
			var away := (dir - Vector3(cos(_radiant), 1.6, sin(_radiant)).normalized()).normalized()
			var b := (dir + away * _rng.randf_range(0.15, 0.4)).normalized()
			if b.y > 0.08:
				_meteors.append({"a": dir, "b": b, "t": 0.0, "life": _rng.randf_range(0.4, 1.0)})
	for m in _meteors.duplicate():
		m.t += delta
		if m.t >= m.life:
			_meteors.erase(m)


func _update_visuals() -> void:
	var cam := _camera_pos()
	var r := _sky_radius()
	var night := _night()
	_aurora.visible = kind == "aurora" and night > 0.01
	_aurora_mat.set_shader_parameter("amount", fade * night if kind == "aurora" else 0.0)
	_aurora.global_position = cam
	_aurora.scale = Vector3.ONE * r
	_moon.visible = kind == "bright_moon" and night > 0.05
	if _moon.visible:
		var dir := moon_dir()
		_moon.global_position = cam + dir * r * 0.9
		_moon.look_at(cam, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
		_moon.scale = Vector3.ONE * r * 0.025
		_moon.material_override.set_shader_parameter("amount", fade * night)

	_streak_mesh.clear_surfaces()
	var any := false
	var to_cam := func(p: Vector3) -> Vector3: return (cam - p).normalized()
	if not _meteors.is_empty():
		_streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for m in _meteors:
			var k: float = m.t / m.life
			var head: Vector3 = cam + (m.a as Vector3).slerp(m.b, k) * r * 0.95
			var tail: Vector3 = cam + (m.a as Vector3).slerp(m.b, maxf(k - 0.25, 0.0)) * r * 0.95
			var bright: float = sin(PI * k) * night * fade
			_ribbon(head, tail, to_cam.call(head), r * 0.006, Color(1.0, 0.95, 0.85) * bright * 1.6, Color(0, 0, 0))
		_streak_mesh.surface_end()
		any = true
	if _bolt_life > 0.0 and _bolt.size() > 1:
		# Flickering for half a second; a long one then fades out.
		var steady := _bolt_total - _bolt_life > 0.5
		var on: bool = steady or fmod(_bolt_life, 0.12) > 0.04
		if on:
			var c := Color(0.85, 0.85, 1.0) * 2.0 * (clampf(_bolt_life / maxf(_bolt_total - 0.5, 0.01), 0.0, 1.0) if steady else 1.0)
			_streak_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in _bolt.size() - 1:
				_ribbon(_bolt[i], _bolt[i + 1], to_cam.call(_bolt[i]), 1.2, c, c)
			_streak_mesh.surface_end()
			any = true
	_streaks.visible = any


func _ribbon(a: Vector3, b: Vector3, view: Vector3, w: float, ca: Color, cb: Color) -> void:
	var side := (b - a).cross(view).normalized() * w
	_streak_mesh.surface_set_color(ca)
	_streak_mesh.surface_add_vertex(a - side)
	_streak_mesh.surface_set_color(cb)
	_streak_mesh.surface_add_vertex(b - side)
	_streak_mesh.surface_set_color(cb)
	_streak_mesh.surface_add_vertex(b + side)
	_streak_mesh.surface_set_color(ca)
	_streak_mesh.surface_add_vertex(a - side)
	_streak_mesh.surface_set_color(cb)
	_streak_mesh.surface_add_vertex(b + side)
	_streak_mesh.surface_set_color(ca)
	_streak_mesh.surface_add_vertex(a + side)


func moon_dir() -> Vector3:
	## Where the moon hangs: opposite the sun, as the swamp's moonlight comes.
	var ang := (Game.time_of_day() - 0.25) * TAU
	var elev := sin(ang)
	return Vector3(-cos(ang), maxf(-elev, 0.25), -0.3).normalized()


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam else Vector3.ZERO


func _sky_radius() -> float:
	## Sky objects stay inside the camera's far plane.
	return Settings.view_distance * 0.85


# --- Lighting ---------------------------------------------------------------------------

func apply_sky(env: Environment, sky: ProceduralSkyMaterial, sun: DirectionalLight3D, day: float) -> void:
	## Adjusts the scene the swamp has just lit for the time of day.
	var f := fade
	match kind:
		"fog":
			var grey := Color(0.62, 0.66, 0.63) * lerpf(0.12, 1.0, day)
			env.fog_density = lerpf(env.fog_density, 7.0 / Settings.view_distance, f)
			env.fog_light_color = env.fog_light_color.lerp(grey, f)
			sky.sky_horizon_color = sky.sky_horizon_color.lerp(grey, f)
			sky.ground_horizon_color = sky.sky_horizon_color
			sky.sky_top_color = sky.sky_top_color.lerp(grey * 0.9, f * 0.8)
			sun.light_energy *= lerpf(1.0, 0.55, f)
		"smoke":
			var red := Color(0.52, 0.25, 0.15) * lerpf(0.15, 1.0, day)
			env.fog_density = lerpf(env.fog_density, 5.0 / Settings.view_distance, f)
			env.fog_light_color = env.fog_light_color.lerp(red, f)
			sky.sky_top_color = sky.sky_top_color.lerp(Color(0.34, 0.17, 0.12) * lerpf(0.15, 1.0, day), f)
			sky.sky_horizon_color = sky.sky_horizon_color.lerp(red, f)
			sky.ground_horizon_color = sky.sky_horizon_color
			sun.light_color = sun.light_color.lerp(Color(1.0, 0.45, 0.25), f)
			sun.light_energy *= lerpf(1.0, 0.5, f)
			env.ambient_light_energy *= lerpf(1.0, 0.8, f)
		"thunderstorm":
			var k := lerpf(1.0, 0.18, f)
			sun.light_energy *= k
			env.ambient_light_energy *= lerpf(1.0, 0.5, f)
			sky.sky_top_color = sky.sky_top_color.lerp(Color(0.1, 0.11, 0.12) * maxf(day, 0.2), f)
			sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color(0.16, 0.17, 0.17) * maxf(day, 0.2), f)
			sky.ground_horizon_color = sky.sky_horizon_color
			env.fog_density = lerpf(env.fog_density, 3.2 / Settings.view_distance, f)
			env.fog_light_color = env.fog_light_color.lerp(sky.sky_horizon_color, f)
		"bright_moon":
			var n := _night() * f
			sun.light_energy = lerpf(sun.light_energy, 0.65, n)
			sun.light_color = sun.light_color.lerp(Color(0.75, 0.82, 1.0), n)
			env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.6, n)
			sky.sky_top_color = sky.sky_top_color.lerp(Color(0.1, 0.14, 0.26), n)
			sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color(0.16, 0.2, 0.28), n)
			sky.ground_horizon_color = sky.sky_horizon_color
		"aurora":
			var n := _night() * f
			sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color(0.06, 0.2, 0.14), n * 0.6)
			env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.45, n * 0.5)
	if flash > 0.0:
		var white := Color(0.85, 0.85, 1.0)
		env.ambient_light_energy += flash * 1.6
		sun.light_energy += flash * 1.5
		sun.light_color = sun.light_color.lerp(white, flash)
		# Toward a bright white, so a flash by day lights the pale sky rather
		# than greying it.
		var glare := Color(0.97, 0.97, 1.0)
		sky.sky_top_color = sky.sky_top_color.lerp(glare, flash * 0.6)
		sky.sky_horizon_color = sky.sky_horizon_color.lerp(glare, flash * 0.6)
		env.fog_light_color = env.fog_light_color.lerp(glare, flash * 0.6)


# --- Saving -----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"kind": kind, "left": left, "planned": planned, "planned_at": planned_at,
		"planned_len": planned_len, "rolled_day": rolled_day, "hinted": hinted,
		"wind_dir": [wind_dir.x, wind_dir.z], "wind_speed": wind_speed,
	}


func from_dict(d: Dictionary) -> void:
	planned = String(d.get("planned", ""))
	planned_at = float(d.get("planned_at", 0.0))
	planned_len = float(d.get("planned_len", 0.0))
	hinted = bool(d.get("hinted", false))
	rolled_day = int(d.get("rolled_day", -1))
	var k := String(d.get("kind", ""))
	if k in KINDS:
		kind = k
		left = float(d.get("left", 0.0))
		fade = 1.0
		var wd: Array = d.get("wind_dir", [0.0, 1.0])
		wind_dir = Vector3(wd[0], 0, wd[1])
		wind_speed = float(d.get("wind_speed", 0.0))
		if kind == "wind":
			_wind_sound.play()


# --- Sky meshes -------------------------------------------------------------------------

const AURORA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float amount = 0.0;
void vertex() {
	float w = sin(UV.x * 18.0 + TIME * 0.25) * 0.03 + sin(UV.x * 47.0 - TIME * 0.4) * 0.012;
	VERTEX.xz += normalize(VERTEX.xz) * w;
}
void fragment() {
	float x = UV.x;
	float y = UV.y;
	float band = 0.5 + 0.5 * sin(x * 31.0 + TIME * 0.6 + sin(x * 11.0 - TIME * 0.35) * 2.5);
	float rays = pow(0.5 + 0.5 * sin(x * 340.0 + sin(x * 23.0 + TIME * 0.8) * 7.0), 3.0);
	float fall = smoothstep(0.0, 0.12, y) * pow(1.0 - y, 1.6);
	float ends = smoothstep(0.0, 0.12, x) * smoothstep(1.0, 0.88, x);
	vec3 col = mix(vec3(0.1, 1.0, 0.4), vec3(0.75, 0.2, 0.75), smoothstep(0.45, 1.0, y));
	ALBEDO = col * (0.35 + 0.65 * rays) * band * fall * ends * amount;
}
"""

const MOON_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float amount = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) * 3.0;  // the disk is the middle third of the quad
	float disk = 1.0 - smoothstep(0.96, 1.0, r);
	float mare = 0.82 + 0.18 * sin(p.x * 23.0 + 1.3) * sin(p.y * 19.0 - 0.7) + 0.08 * sin(p.x * 61.0) * sin(p.y * 53.0);
	float halo = pow(max(1.0 - length(p), 0.0), 2.5) * 0.7;
	vec3 c = vec3(0.8, 0.82, 0.86) * disk * mare + vec3(0.45, 0.55, 0.8) * halo * (1.0 - disk);
	ALBEDO = c * amount;
}
"""


func _build_aurora() -> void:
	## A broad curtain hung around the northern sky, on a unit sphere (scaled
	## to the sky radius each frame).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 64
	var az0 := -PI * 0.5 - 1.3
	var az1 := -PI * 0.5 + 1.3
	var el0 := deg_to_rad(10.0)
	var el1 := deg_to_rad(55.0)
	for i in segs:
		var u0 := float(i) / segs
		var u1 := float(i + 1) / segs
		var a0 := lerpf(az0, az1, u0)
		var a1 := lerpf(az0, az1, u1)
		var p := [
			_sphere(a0, el0), _sphere(a1, el0), _sphere(a1, el1), _sphere(a0, el1),
		]
		var uv := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.add_vertex(p[k])
	_aurora = MeshInstance3D.new()
	_aurora.mesh = st.commit()
	_aurora_mat = ShaderMaterial.new()
	_aurora_mat.shader = Shader.new()
	_aurora_mat.shader.code = AURORA_SHADER
	_aurora.material_override = _aurora_mat
	_aurora.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aurora.top_level = true
	_aurora.extra_cull_margin = 16384.0
	_aurora.visible = false
	add_child(_aurora)


func _sphere(az: float, el: float) -> Vector3:
	return Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))


func _build_moon() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(6, 6)  # the disk is a third of it
	_moon = MeshInstance3D.new()
	_moon.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = MOON_SHADER
	_moon.material_override = m
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_moon.top_level = true
	_moon.visible = false
	add_child(_moon)


func _glow_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""
	return m
