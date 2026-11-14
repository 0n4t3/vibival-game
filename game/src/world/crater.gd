extends Node3D
## Where a meteorite came down (group "craters", metals.md): a scorched hollow
## with a raised rim, smoking for a day (LIFE). The meteorite itself
## (heavy_stone.gd) lies half buried in the middle. A tall dark column of
## smoke stands over it, thinning through the day, so you can find it from
## far off: it is drawn pulled in within the camera's range and scaled to look
## the right size (like the sky effects in weather.gd), since the crater is
## usually beyond the far plane.

const MeshBuilder := preload("res://src/core/mesh_builder.gd")

const LIFE := 1440.0
const R := 2.2
const COLUMN := Vector2(34.0, 120.0)   # the smoke column's width (at the top) and height, m

var made_at := 0.0
var _smoke: CPUParticles3D
var _column: MeshInstance3D
var _column_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("craters")
	var m := MeshInstance3D.new()
	m.visibility_range_end = 200.0
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	b.blob(Vector3(0, -0.02, 0), Vector3(R, 0.06, R), 1, 9, Color(0.10, 0.09, 0.08), rng, 0.15, "clay")
	for i in 12:
		var a := TAU * i / 12.0 + rng.randf_range(-0.15, 0.15)
		b.blob(Vector3(cos(a), 0, sin(a)) * R * 1.05, Vector3(0.6, 0.22, 0.45), 1, 5, Color(0.28, 0.22, 0.17) * rng.randf_range(0.8, 1.1), rng, 0.25, "clay")
	m.mesh = b.commit(Assets.materials)
	add_child(m)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 40
	_smoke.lifetime = 8.0
	_smoke.position = Vector3(0, 0.3, 0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.8
	_smoke.initial_velocity_max = 1.6
	_smoke.gravity = Vector3(0.1, 0.25, 0)
	_smoke.scale_amount_min = 1.0
	_smoke.scale_amount_max = 3.0
	var puff := QuadMesh.new()
	puff.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.29, 0.28, 0.35)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	puff.material = mat
	_smoke.mesh = puff
	add_child(_smoke)
	_smoke.emitting = smoking()
	_column = MeshInstance3D.new()
	_column.top_level = true
	var q := QuadMesh.new()
	q.center_offset = Vector3(0, 0.5, 0)
	_column.mesh = q
	_column_mat = ShaderMaterial.new()
	_column_mat.shader = _column_shader()
	_column_mat.set_shader_parameter("seed", rng.randf() * 100.0)
	_column.material_override = _column_mat
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_column.extra_cull_margin = 200.0
	add_child(_column)
	_place_column()


func smoking() -> bool:
	return Game.time - made_at < LIFE


func _process(_delta: float) -> void:
	if _smoke.emitting and not smoking():
		_smoke.emitting = false
	_place_column()


func column_strength() -> float:
	## 1 when fresh, thinning to 0 by the end of LIFE.
	return pow(clampf(1.0 - (Game.time - made_at) / LIFE, 0.0, 1.0), 0.7)


func _place_column() -> void:
	var k := column_strength()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	_column.visible = k > 0.0 and cam != null
	if not _column.visible:
		return
	var c := cam.global_position
	var at := global_position
	var flat := Vector2(at.x - c.x, at.z - c.z)
	var d := flat.length()
	# Within reach it stands where it is; beyond, it is pulled in along the
	# line of sight and shrunk to match, so it looks the same size.
	var reach := Settings.view_distance * 0.8
	var s := 1.0 if d <= reach else reach / d
	var base := c + (at - c) * s
	_column.global_position = base
	_column.rotation = Vector3(0, atan2(c.x - base.x, c.z - base.z), 0)
	# Far off it shrinks a little less than it truly would, so a distant
	# column still reads over the trees.
	var g := s if d <= reach else s * pow(d / reach, 0.4)
	_column.scale = Vector3(COLUMN.x * g, COLUMN.y * g, 1.0)
	# Close by, the crater's own smoke shows it; far off, a little hazier.
	var alpha := k * smoothstep(12.0, 40.0, d) * lerpf(1.0, 0.8, clampf(d / 300.0, 0.0, 1.0))
	_column_mat.set_shader_parameter("amount", alpha)


static var _shader: Shader


static func _column_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float amount = 1.0;
uniform float seed = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15; }
void fragment() {
	float y = 1.0 - UV.y;   // 0 at the ground, 1 at the top
	float t = TIME * 0.05 + seed;
	// Narrow at the ground, spreading and leaning with height, edges wavering.
	float lean = 0.18 * y * y;
	float half_w = 0.06 + 0.4 * pow(y, 0.8);
	float wob = (fbm(vec2(y * 3.0 - t * 2.0, seed)) - 0.5) * 0.25 * y;
	float x = abs(UV.x - 0.5 - lean - wob) / half_w;
	float body = 1.0 - smoothstep(0.35, 1.0, x);
	float billow = fbm(vec2(UV.x * 4.0, y * 6.0 - t * 6.0));
	float a = body * mix(0.55, 1.0, billow);
	a *= smoothstep(0.0, 0.03, y) * pow(1.0 - y, 0.5);
	a *= mix(1.0, 0.7, y) * amount * 1.25;
	ALBEDO = mix(vec3(0.10, 0.09, 0.085), vec3(0.32, 0.31, 0.30), y) * mix(0.8, 1.15, billow);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""
	return _shader


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "made_at": made_at}


func from_dict(d: Dictionary) -> void:
	made_at = float(d.get("made_at", 0.0))
	if _smoke:
		_smoke.emitting = smoking()
