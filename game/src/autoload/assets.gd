extends Node
## Shared materials and the procedural mesh library.
##
## Every mesh is requested by key through `mesh(key)`. Optional resource packs
## (.pck or .zip files placed in user://packs/) can replace any of them by
## shipping `res://pack/meshes/<key>.tres` (or .res), and can replace a
## material slot with `res://pack/materials/<slot>.tres`. That lets a pack
## raise texture and polygon detail without code changes. Packs live inside
## the app's sandboxed data directory, so no host file access is needed.
##
## Surface detail is generated too: the stone, wood, fiber, clay and organic
## slots carry small tiling textures (grain, weave, specks) made from noise at
## startup and mapped triplanar, so meshes need no UVs. Inventory icons are
## rendered from the item meshes once at startup (see render_icons).

const MeshBuilder := preload("res://src/core/mesh_builder.gd")
const PACK_DIR := "user://packs"

const ICON_CELL := 128
const ICON_COLS := 8

signal icons_ready

var materials := {}
var loaded_packs: PackedStringArray = []
var icon_atlas: Texture2D = null   # item icons rendered from their meshes
var icon_rects := {}               # item id -> Rect2 in icon_atlas
var _cache := {}
var _detail := {}                  # surface kind -> [albedo, normal] textures


func _ready() -> void:
	_load_packs()
	_build_materials()
	Settings.changed.connect(_on_settings_changed)
	if DisplayServer.get_name() != "headless":
		render_icons.call_deferred()


func _on_settings_changed() -> void:
	# Detail level is baked into cached meshes, so rebuild lazily.
	_cache.clear()
	_build_materials()


func _load_packs() -> void:
	DirAccess.make_dir_recursive_absolute(PACK_DIR)
	var dir := DirAccess.open(PACK_DIR)
	if dir == null:
		return
	var files := Array(dir.get_files())
	files.sort()
	for f in files:
		var ext: String = f.get_extension().to_lower()
		if ext == "pck" or ext == "zip":
			if ProjectSettings.load_resource_pack(PACK_DIR.path_join(f), true):
				loaded_packs.append(f)
				print("Loaded resource pack: ", f)


func _pack_resource(kind: String, key: String) -> Resource:
	if loaded_packs.is_empty():
		return null
	for ext in ["tres", "res"]:
		var path := "res://pack/%s/%s.%s" % [kind, key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


# --- Materials ---------------------------------------------------------------

## High winds bend plants and trees (weather sets `wind`, a gale is about 1):
## the higher up a vertex, the further it leans downwind, swaying in gusts.
const WIND_BEND := """
uniform vec3 wind = vec3(0.0);
void bend(inout vec3 v, mat4 model, float time) {
	if (dot(wind, wind) > 0.0001) {
		vec3 wp = model[3].xyz;
		vec3 local = (vec4(wind, 0.0) * model).xyz / dot(model[0].xyz, model[0].xyz);
		float h = max(v.y, 0.0) / 12.0;
		float gust = 0.75 + 0.25 * sin(time * 1.9 + wp.x * 0.13 + wp.z * 0.09);
		v.xz += local.xz * h * h * 1.6 * gust;
	}
}
"""

const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform float sway = 0.0;
""" + WIND_BEND + """
void vertex() {
	if (sway > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float t = TIME * 1.3 + wp.x * 0.11 + wp.z * 0.07;
		VERTEX.x += sin(t) * sway * h * 0.04;
		VERTEX.z += cos(t * 0.8) * sway * h * 0.03;
	}
	bend(VERTEX, MODEL_MATRIX, TIME);
}
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));  // authored in sRGB
	ALBEDO = c;
	ROUGHNESS = 1.0;
	BACKLIGHT = c * 0.3;
}
"""

## Tree trunks: the plain vertex-coloured look, bending in the wind with the crowns.
const BARK_SHADER := """
shader_type spatial;
render_mode diffuse_lambert;
""" + WIND_BEND + """
void vertex() {
	bend(VERTEX, MODEL_MATRIX, TIME);
}
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.15;
}
"""
const TREES := ["lepidodendron", "sigillaria", "calamites", "tree_fern"]

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_schlick_ggx, depth_draw_opaque;
uniform vec4 deep : source_color = vec4(0.10, 0.16, 0.10, 0.88);
uniform vec4 shallow : source_color = vec4(0.22, 0.30, 0.16, 0.80);
uniform float waves = 0.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (waves > 0.0) {
		VERTEX.y += (sin(wpos.x * 0.35 + TIME * 0.9) + cos(wpos.z * 0.29 + TIME * 0.7)) * 0.03 * waves;
	}
}
void fragment() {
	float n = sin(wpos.x * 0.8 + TIME * 0.6) * cos(wpos.z * 0.7 - TIME * 0.5);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, 0.5 + 0.2 * n) + vec3(fres * 0.12);
	ALPHA = mix(deep.a, 0.97, fres);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	NORMAL = normalize(NORMAL + vec3(n * 0.05 * waves, 0.0, n * 0.04 * waves));
}
"""


func _build_materials() -> void:
	var solid := StandardMaterial3D.new()
	solid.vertex_color_use_as_albedo = true
	solid.vertex_color_is_srgb = true
	solid.roughness = 1.0
	solid.metallic_specular = 0.15
	materials["solid"] = solid

	var terrain := solid.duplicate()
	materials["terrain"] = terrain

	var foliage := ShaderMaterial.new()
	foliage.shader = Shader.new()
	foliage.shader.code = FOLIAGE_SHADER
	foliage.set_shader_parameter("sway", 1.0 if Settings.quality == Settings.Quality.HIGH else 0.0)
	materials["foliage"] = foliage

	var bark := ShaderMaterial.new()
	bark.shader = Shader.new()
	bark.shader.code = BARK_SHADER
	materials["bark"] = bark

	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.vertex_color_is_srgb = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materials["glow"] = glow

	var metal := solid.duplicate()
	metal.roughness = 0.35
	metal.metallic = 0.7
	materials["metal"] = metal

	# Textured surfaces: [kind, tiles per metre]
	for t in [["stone", 5.0], ["wood", 6.0], ["fiber", 9.0], ["clay", 4.0], ["organic", 5.0]]:
		materials[t[0]] = _textured(solid, t[0], t[1])
	# Each tree's bark, for its logs (see log_piece).
	for kind in TREES:
		materials["bark_" + kind] = _textured(solid, "bark_" + kind, 2.0)

	var water := ShaderMaterial.new()
	water.shader = Shader.new()
	water.shader.code = WATER_SHADER
	water.set_shader_parameter("waves", 0.0 if Settings.quality == Settings.Quality.LOW else 1.0)
	materials["water"] = water

	for slot in materials.keys():
		var override := _pack_resource("materials", slot)
		if override is Material:
			materials[slot] = override


func _textured(base: StandardMaterial3D, kind: String, tiles: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = base.duplicate()
	var t := detail_textures(kind)
	m.albedo_texture = t[0]
	# albedo_color is sRGB, so pick the value whose linear form undoes the darkening.
	var k := Color(1.0 / t[2], 1.0 / t[2], 1.0 / t[2]).linear_to_srgb().r
	m.albedo_color = Color(k, k, k)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * tiles
	m.uv1_triplanar_sharpness = 2.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if Settings.quality > Settings.Quality.LOW:
		m.normal_enabled = true
		m.normal_texture = t[1]
		m.normal_scale = 0.8
	return m


func detail_textures(kind: String) -> Array:
	## [albedo, normal, mean] for a surface kind: grey tiling detail that the
	## vertex colour tints, a matching normal map and the albedo's mean linear
	## brightness. Generated once and kept.
	if _detail.has(kind):
		return _detail[kind]
	const N := 128
	var noise := FastNoiseLite.new()
	noise.seed = hash(kind)
	var fine := FastNoiseLite.new()
	fine.seed = hash(kind) + 1
	match kind:
		"stone":
			noise.frequency = 0.035
			noise.fractal_octaves = 4
			fine.noise_type = FastNoiseLite.TYPE_CELLULAR
			fine.frequency = 0.12
		"wood":
			noise.frequency = 0.02
			fine.frequency = 0.2
		"fiber":
			noise.frequency = 0.08
			fine.frequency = 0.3
		"clay":
			noise.frequency = 0.015
			noise.fractal_octaves = 2
			fine.frequency = 0.25
		"bark_tree_fern":
			noise.frequency = 0.05
			fine.frequency = 0.35
		_:
			noise.frequency = 0.03
			fine.frequency = 0.15
	var big := noise.get_seamless_image(N, N)
	var small := fine.get_seamless_image(N, N)
	var albedo := Image.create(N, N, false, Image.FORMAT_RGB8)
	var height := Image.create(N, N, false, Image.FORMAT_RGB8)
	var linear_sum := 0.0
	for y in N:
		for x in N:
			var a := big.get_pixel(x, y).r
			var f := small.get_pixel(x, y).r
			var v := 0.5
			var h := 0.5
			match kind:
				"stone":
					# Mottled grain with darker specks and pits.
					v = 0.55 + a * 0.35 + f * 0.1
					if f < 0.18:
						v -= 0.18
					h = a * 0.6 + f * 0.4
				"wood":
					# Grain running along X, wavering with the noise.
					var g := 0.5 + 0.5 * sin(TAU * 7.0 * x / N + a * 6.0)
					v = 0.62 + g * 0.22 + f * 0.12
					h = g * 0.8 + f * 0.2
				"fiber":
					# An over-under weave of strands.
					var wx := 0.5 + 0.5 * sin(TAU * 8.0 * x / N)
					var wy := 0.5 + 0.5 * sin(TAU * 8.0 * y / N)
					var over := wx if (int(8.0 * y / N) + int(8.0 * x / N)) % 2 == 0 else wy
					v = 0.55 + over * 0.3 + f * 0.15
					h = over
				"clay":
					# Smooth with fine grit and finger smears.
					v = 0.72 + a * 0.18 + f * 0.1
					if f > 0.85:
						v -= 0.12
					h = a * 0.5 + f * 0.5
				# Bark, for logs: texture X runs along the log, Y round it.
				"bark_lepidodendron":
					# Scale tree: a lattice of diamond leaf cushions, drawn out
					# along the trunk, each with a scar near its top.
					var p := fposmod(3.0 * x / N + 6.0 * y / N, 1.0)
					var q := fposmod(3.0 * x / N - 6.0 * y / N, 1.0)
					var groove := minf(minf(p, 1.0 - p), minf(q, 1.0 - q))
					var cushion := clampf(groove * 9.0, 0.0, 1.0)
					var scar := Vector2(p - 0.62, q - 0.62).length() < 0.09
					v = 0.42 + cushion * 0.42 + f * 0.1 - (0.22 if scar else 0.0)
					h = cushion * 0.85 + f * 0.15 - (0.3 if scar else 0.0)
				"bark_sigillaria":
					# Seal tree: deep ribs along the trunk, with a row of paired
					# leaf scars down the middle of each.
					var rib := 0.5 + 0.5 * cos(TAU * 8.0 * y / N)
					var cell := fposmod(8.0 * y / N, 1.0)
					var along := fposmod(5.0 * x / N + (0.5 if int(8.0 * y / N) % 2 == 1 else 0.0), 1.0)
					var scar := absf(cell - 0.5) < 0.16 and absf(along - 0.5) < 0.09
					v = 0.45 + rib * 0.38 + f * 0.1 - (0.25 if scar else 0.0)
					h = rib * 0.85 + f * 0.15 - (0.35 if scar else 0.0)
				"bark_calamites":
					# Giant horsetail: fine, close ribs running the length.
					var rib := pow(0.5 + 0.5 * cos(TAU * 16.0 * y / N + a * 0.6), 0.6)
					v = 0.5 + rib * 0.36 + f * 0.1
					h = rib * 0.9 + f * 0.1
				"bark_tree_fern":
					# Tree fern: a shaggy mantle of matted roots and fibres,
					# wavering along the trunk.
					var fibre := 0.5 + 0.5 * sin(TAU * 11.0 * y / N + a * 7.0 + sin(TAU * 2.0 * x / N) * 1.5)
					v = 0.38 + fibre * 0.34 + f * 0.24
					h = fibre * 0.6 + f * 0.4
				_:
					# Soft blotches.
					v = 0.64 + a * 0.26 + f * 0.1
					h = a * 0.7 + f * 0.3
			v = clampf(v, 0.0, 1.0)
			albedo.set_pixel(x, y, Color(v, v, v))
			linear_sum += Color(v, v, v).srgb_to_linear().r
			height.set_pixel(x, y, Color(h, h, h))
	albedo.generate_mipmaps()
	height.bump_map_to_normal_map(4.0)
	height.generate_mipmaps()
	# The third entry is the texture's mean brightness in linear space, which
	# the material divides back out so the vertex colour stays the average.
	_detail[kind] = [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(height), linear_sum / (N * N)]
	return _detail[kind]


func material(slot: String) -> Material:
	return materials.get(slot, materials["solid"])


# --- Mesh library -------------------------------------------------------------

func mesh(key: String) -> Mesh:
	if _cache.has(key):
		return _cache[key]
	var m: Mesh = _pack_resource("meshes", key) as Mesh
	if m == null:
		var b := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var fn := "_m_" + key
		if has_method(fn):
			call(fn, b, rng, Settings.detail())
		elif key.begins_with("item_"):
			_item_mesh(b, rng, key.substr(5))
		else:
			push_warning("No mesh builder for " + key)
			b.box(Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color.MAGENTA)
		if key in TREES:
			var mats := materials.duplicate()
			mats["solid"] = materials["bark"]
			m = b.commit(mats)
		else:
			m = b.commit(materials)
	_cache[key] = m
	return m


func builder() -> RefCounted:
	return MeshBuilder.new()


# Shared palette
const BARK := Color(0.32, 0.30, 0.22)
const BARK_LIGHT := Color(0.45, 0.43, 0.30)
const LEAF := Color(0.20, 0.42, 0.16)
const LEAF_LIGHT := Color(0.42, 0.58, 0.20)


# Tree meshes can be drawn in part: only what lies between _lo and _hi (in
# the tree's own units, along the trunk). A stump is the bottom of a tree, a
# felled trunk the rest; `_bare` leaves off the crown and branches (a rotten
# log) and `_tint` darkens the bark. Cut ends show pale wood.
var _lo := -INF
var _hi := INF
var _bare := false
var _tint := Color(1, 1, 1)
const CUT_WOOD := Color(0.74, 0.62, 0.42)


func tree_part(kind: String, lo: float, hi := INF, bare := false, tint := Color(1, 1, 1)) -> Mesh:
	## The piece of a tree between lo and hi up the trunk (tree units), cached.
	var key := "%s|%d|%d|%s|%s" % [kind, roundi(lo * 20.0) if lo > -INF else -9999, roundi(hi * 20.0) if hi < INF else 9999, bare, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	_lo = lo
	_hi = hi
	_bare = bare
	_tint = tint
	call("_m_" + kind, b, rng, Settings.detail())
	_lo = -INF
	_hi = INF
	_bare = false
	_tint = Color(1, 1, 1)
	var mats := materials.duplicate()
	if lo > 0.0:
		# Lying on the ground: the wind doesn't bend it (a still copy of the
		# foliage, which the weather never stirs).
		if not materials.has("foliage_still"):
			materials["foliage_still"] = materials["foliage"].duplicate()
			materials["foliage_still"].set_shader_parameter("sway", 0.0)
			materials["foliage_still"].set_shader_parameter("wind", Vector3.ZERO)
		mats["foliage"] = materials["foliage_still"]
	else:
		mats["solid"] = materials["bark"]
	var m: Mesh = b.commit(mats)
	_cache[key] = m
	return m


func _trunk(b, y0: float, y1: float, r0: float, r1: float, sides: int, c0: Color, c1: Color) -> void:
	## A straight, closed section of trunk from y0 up to y1, clipped to
	## [_lo, _hi]; a clipped end is a cut face of pale wood.
	if y1 <= _lo or y0 >= _hi or y1 <= y0:
		return
	var a := maxf(y0, _lo)
	var z := minf(y1, _hi)
	var ra := lerpf(r0, r1, (a - y0) / (y1 - y0))
	var rz := lerpf(r0, r1, (z - y0) / (y1 - y0))
	var ca := c0.lerp(c1, (a - y0) / (y1 - y0)) * _tint
	var cz := c0.lerp(c1, (z - y0) / (y1 - y0)) * _tint
	b.cylinder(Vector3(0, a, 0), Vector3(0, z, 0), ra, rz, sides, ca, cz, "solid", false)
	var f: Array = MeshBuilder.frame(Vector3.UP)
	for i in sides:
		var j := (i + 1) % sides
		var di: Vector3 = f[0] * cos(TAU * i / sides) + f[1] * sin(TAU * i / sides)
		var dj: Vector3 = f[0] * cos(TAU * j / sides) + f[1] * sin(TAU * j / sides)
		if rz > 0.001:
			var top := Vector3(0, z, 0)
			b.tri(top, top + di * rz, top + dj * rz, CUT_WOOD if z < y1 else cz, "solid")
			if z < y1 and rz > 0.12:
				# Growth rings on the cut face.
				b.tri(top + Vector3(0, 0.003, 0), top + di * rz * 0.55 + Vector3(0, 0.003, 0), top + dj * rz * 0.55 + Vector3(0, 0.003, 0), CUT_WOOD * 0.9, "solid")
		if ra > 0.001:
			var bot := Vector3(0, a, 0)
			b.tri(bot, bot + dj * ra, bot + di * ra, CUT_WOOD if a > y0 else ca, "solid")


func _above(y: float) -> bool:
	## Crown and branches at height y are part of this piece of the tree.
	return not _bare and y >= _lo and y <= _hi


func _m_lepidodendron(b, rng: RandomNumberGenerator, d: int) -> void:
	## Scale tree: a tall straight pole that forks into grassy tufts.
	var sides: int = [5, 6, 8][d]
	var h := 20.0
	var rings: int = [3, 5, 8][d]
	for i in rings:
		var y0 := h * i / rings
		var y1 := h * (i + 1) / rings
		var r0 := lerpf(0.55, 0.32, float(i) / rings)
		var r1 := lerpf(0.55, 0.32, float(i + 1) / rings)
		var col := BARK if i % 2 == 0 else BARK_LIGHT
		_trunk(b, y0, y1, r0, r1, sides, col, col)
	# Base flare
	_trunk(b, 0.0, 1.4, 0.9, 0.0, sides, BARK * 0.8, BARK * 0.8)
	if _above(h):
		_fork(b, rng, Vector3(0, h, 0), Vector3.UP, 3.2, 0.32, [2, 3, 3][d], sides)


func _fork(b, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float,
		radius: float, depth: int, sides: int) -> void:
	if depth == 0:
		# Grass-like leaf tuft at the tip.
		var n := 6 if sides > 5 else 4
		for i in n:
			var a := TAU * i / n + rng.randf() * 0.5
			var ld := (dir * 0.6 + Vector3(cos(a), 0.2, sin(a))).normalized()
			b.leaf(from, ld, 1.8, 0.35, 0.9, 2, LEAF, LEAF_LIGHT)
		b.blob(from, Vector3(0.45, 0.6, 0.45), 2, 5, LEAF * 0.9, null, 0.0, "foliage")
		return
	# A knuckle of bark where the branches part, so the joint has no gaps.
	b.blob(from, Vector3.ONE * radius * 1.12, 2, maxi(sides - 1, 5), BARK_LIGHT * _tint)
	for k in 2:
		var side := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU))
		var nd := (dir + side * (0.8 if k == 0 else -0.8)).normalized()
		nd = (nd + Vector3(0, 0.35, 0)).normalized()
		var to := from + nd * length
		b.cylinder(from, to, radius, radius * 0.7, maxi(sides - 2, 4), BARK_LIGHT, BARK_LIGHT, "solid", true)
		_fork(b, rng, to, nd, length * 0.72, radius * 0.7, depth - 1, sides)


func _m_sigillaria(b, rng: RandomNumberGenerator, d: int) -> void:
	## Thick ribbed trunk topped with a mop of long strap leaves.
	var sides: int = [6, 8, 10][d]
	var h := 14.0
	_trunk(b, 0.0, h, 0.75, 0.55, sides, BARK * 0.9, BARK_LIGHT)
	_trunk(b, 0.0, 1.0, 1.2, 0.0, sides, BARK * 0.7, BARK * 0.7)
	if not _above(h):
		return
	var n: int = [10, 16, 24][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.3
		var up := rng.randf_range(0.1, 1.2)
		var ld := Vector3(cos(a), up, sin(a))
		b.leaf(Vector3(0, h, 0), ld, rng.randf_range(2.5, 3.5), 0.3, 1.4, 3, LEAF, LEAF_LIGHT)
	b.blob(Vector3(0, h + 0.2, 0), Vector3(0.7, 0.5, 0.7), 2, 6, LEAF * 0.8, null, 0.0, "foliage")


func _m_calamites(b, rng: RandomNumberGenerator, d: int) -> void:
	## Giant horsetail: jointed trunk with whorls of thin branches.
	var sides: int = [5, 6, 7][d]
	var h := 10.0
	var nodes := 7
	for i in nodes:
		var y0 := h * i / nodes
		var y1 := h * (i + 1) / nodes
		var r := lerpf(0.32, 0.12, float(i) / nodes)
		var r_next := lerpf(0.32, 0.12, float(i + 1) / nodes)
		_trunk(b, y0, y1, r, r_next, sides, Color(0.38, 0.42, 0.24), Color(0.30, 0.34, 0.18))
		# The joint ring sits over the seam between sections.
		if y1 + 0.06 <= _hi and y1 - 0.06 >= _lo:
			_trunk(b, y1 - 0.06, y1 + 0.06, r_next * 1.18, r_next * 1.18, sides, Color(0.22, 0.24, 0.14), Color(0.22, 0.24, 0.14))
		if i >= 2:
			var whorl: int = [4, 6, 8][d]
			var blen := lerpf(2.2, 0.8, float(i) / nodes)
			for k in whorl:
				var a := TAU * k / whorl + i * 0.5
				if _above(y1):
					var bd := Vector3(cos(a), 0.45, sin(a))
					b.leaf(Vector3(0, y1, 0), bd, blen, 0.25, 0.6, 2, Color(0.28, 0.48, 0.18), LEAF_LIGHT)
	if _above(h):
		b.cone(Vector3(0, h, 0), Vector3(0, h + 0.8, 0), 0.14, sides, Color(0.35, 0.45, 0.2))


func _m_tree_fern(b, rng: RandomNumberGenerator, d: int) -> void:
	## Psaronius: shaggy trunk with a crown of arching fronds.
	var sides: int = [5, 6, 8][d]
	var h := 5.0
	_trunk(b, 0.0, h, 0.45, 0.28, sides, Color(0.26, 0.20, 0.14), Color(0.36, 0.28, 0.16))
	var n: int = [6, 9, 12][d]
	var segs: int = [3, 4, 6][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.3
		var fd := Vector3(cos(a), rng.randf_range(0.4, 0.9), sin(a))
		var length := rng.randf_range(3.0, 3.8)
		if _above(h):
			b.leaf(Vector3(0, h, 0), fd, length, 1.1, 1.5, segs, Color(0.18, 0.40, 0.14), Color(0.34, 0.55, 0.20))


func _m_tree_fern_crown(b, rng: RandomNumberGenerator, d: int) -> void:
	## A harvestable tree fern's fresh growth: a tuft of bright young fronds
	## standing up from the crown, with curled fiddleheads among them.
	var n: int = [5, 7, 9][d]
	var segs: int = [3, 4, 5][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		var fd := Vector3(cos(a) * 0.5, rng.randf_range(1.6, 2.4), sin(a) * 0.5)
		b.leaf(Vector3(0, -0.1, 0), fd, rng.randf_range(1.3, 1.9), 0.5, 0.6, segs, Color(0.40, 0.66, 0.16), Color(0.66, 0.86, 0.30))
	var sides: int = [3, 4, 5][d]
	for i in [3, 4, 6][d]:
		var a: float = TAU * (i + 0.5) / 6.0 + rng.randf() * 0.3
		_fiddlehead(b, Vector3(cos(a), 0, sin(a)), rng.randf_range(0.6, 0.9), 1.0, sides)


func _fiddlehead(b, out: Vector3, height: float, s: float, sides: int) -> void:
	## A fern's young shoot: a stem standing up, leaning `out`, with its head
	## coiled in a shrinking spiral back over it. `s` scales it.
	var stem_top := out * 0.25 * s + Vector3(0, height, 0)
	var pts := [out * 0.1 * s, out * 0.18 * s + Vector3(0, height * 0.5, 0), stem_top]
	for k in 6:
		var t := (k + 1) / 6.0
		var ang := t * TAU * 0.9
		var r := 0.13 * s * (1.0 - t * 0.6)
		pts.append(stem_top + out * sin(ang) * r + Vector3(0, (1.0 - cos(ang)) * r, 0))
	var radii := []
	for k in pts.size():
		radii.append(lerpf(0.035, 0.022, float(k) / pts.size()) * s)
	b.tube(pts, radii, sides, [Color(0.50, 0.70, 0.22), Color(0.72, 0.82, 0.38)], "foliage")


func _m_fern(b, rng: RandomNumberGenerator, d: int) -> void:
	## A ground fern (decoration: chunk.gd DECOR). The ones you can strip are
	## fern_ripe, which stands out from these.
	var n: int = [5, 7, 9][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		var fd := Vector3(cos(a), rng.randf_range(1.0, 1.8), sin(a))
		b.leaf(Vector3.ZERO, fd, rng.randf_range(0.9, 1.3), 0.4, 0.7, 3, Color(0.16, 0.34, 0.11), Color(0.32, 0.48, 0.16))


func _m_fern_ripe(b, rng: RandomNumberGenerator, d: int) -> void:
	## A fern you can strip (harvestable.gd "fern"), made to stand out among
	## the dark decoration ferns: bigger and a brighter, yellower green, with
	## curled fiddleheads standing up in the middle (the fiddleheads it gives)
	## and a few old fronds gone pale and stringy round its foot (the fiber).
	var n: int = [6, 8, 10][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		var fd := Vector3(cos(a), rng.randf_range(1.2, 2.0), sin(a))
		b.leaf(Vector3.ZERO, fd, rng.randf_range(1.2, 1.6), 0.5, 0.7, [3, 4, 4][d], Color(0.30, 0.52, 0.14), Color(0.58, 0.76, 0.24))
	# Old fronds lying out round the foot, dried to the straw of plant fiber.
	for i in [2, 3, 4][d]:
		var a: float = TAU * (i + 0.3) / 4.0 + rng.randf() * 0.5
		var fd := Vector3(cos(a), 0.25, sin(a))
		b.leaf(Vector3(0, 0.03, 0), fd, rng.randf_range(0.9, 1.2), 0.22, 0.35, 3, Color(0.62, 0.58, 0.32), Color(0.74, 0.68, 0.42))
	var sides: int = [3, 4, 5][d]
	for i in 3:
		var a: float = TAU * i / 3.0 + rng.randf() * 0.5
		_fiddlehead(b, Vector3(cos(a), 0, sin(a)), rng.randf_range(0.45, 0.65), 0.8, sides)


func _m_fern_stripped(b, rng: RandomNumberGenerator, d: int) -> void:
	## A fern that has been stripped (harvestable.gd "fern", picked): cut-back
	## stalks and a few short, dull fronds low down, until it grows back.
	var n: int = [4, 5, 6][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		var top := out * 0.12 + Vector3(0, rng.randf_range(0.18, 0.3), 0)
		b.cylinder(Vector3.ZERO, top, 0.018, 0.012, 3, Color(0.26, 0.30, 0.14), Color(0.48, 0.42, 0.24), "foliage", false)
	for i in [2, 3, 3][d]:
		var a: float = TAU * (i + 0.5) / 3.0 + rng.randf() * 0.5
		b.leaf(Vector3.ZERO, Vector3(cos(a), 0.5, sin(a)), rng.randf_range(0.4, 0.6), 0.25, 0.5, 2, Color(0.18, 0.30, 0.12), Color(0.30, 0.38, 0.16))


func _m_horsetail(b, rng: RandomNumberGenerator, d: int) -> void:
	var n: int = [3, 5, 7][d]
	for i in n:
		var p := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var top := p + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(1.0, 1.7), rng.randf_range(-0.1, 0.1))
		b.cylinder(p, top, 0.025, 0.015, 4, Color(0.30, 0.48, 0.20), Color(0.40, 0.55, 0.25), "foliage", false)
		b.cone(top, top + Vector3(0, 0.12, 0), 0.04, 4, Color(0.45, 0.38, 0.20), "foliage")


func _m_hole(b, rng: RandomNumberGenerator, _d: int) -> void:
	## A hole dug with a mattock (plot.gd): a dark pit inside a low ring of the
	## loose earth thrown up out of it, most of it heaped on one side. All of
	## it sits on the ground, which can't be cut into.
	var dark := Color(0.07, 0.05, 0.03)
	var soil := Color(0.36, 0.26, 0.16)
	var up := Vector3.UP
	var n := 12
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var e0 := Vector3(cos(a0), 0, sin(a0))
		var e1 := Vector3(cos(a1), 0, sin(a1))
		# Earth banked up outside, a wall falling inside to the dark bottom.
		b.quad(e0 * 0.44 + up * -0.04, e1 * 0.44 + up * -0.04, e1 * 0.31 + up * 0.08, e0 * 0.31 + up * 0.08, soil)
		b.quad(e0 * 0.31 + up * 0.08, e1 * 0.31 + up * 0.08, e1 * 0.2 + up * 0.035, e0 * 0.2 + up * 0.035, soil.darkened(0.45))
		b.tri(up * 0.03, e0 * 0.2 + up * 0.035, e1 * 0.2 + up * 0.035, dark)
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var r := rng.randf_range(0.36, 0.42)
		b.blob(Vector3(cos(a) * r, 0.06, sin(a) * r), Vector3(0.08, 0.05, 0.07), 2, 5, soil * rng.randf_range(0.85, 1.05), rng, 0.3)
	b.blob(Vector3(0.52, 0.05, 0.05), Vector3(0.2, 0.11, 0.16), 3, 6, soil, rng, 0.25)


func _m_mound(b, rng: RandomNumberGenerator, _d: int) -> void:
	## A hole filled in over what was planted or buried in it (plot.gd): a low
	## heap of fresh, loose earth, gone when the day is out.
	var soil := Color(0.36, 0.26, 0.16)
	b.blob(Vector3(0, 0.02, 0), Vector3(0.36, 0.11, 0.32), 3, 8, soil, rng, 0.2)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.5
		var r := rng.randf_range(0.22, 0.34)
		b.blob(Vector3(cos(a) * r, 0.03, sin(a) * r), Vector3(0.1, 0.06, 0.09), 2, 5, soil * rng.randf_range(0.8, 1.05), rng, 0.3)


func _m_seed_fern(b, rng: RandomNumberGenerator, d: int) -> void:
	## Medullosa bush with hanging seeds (harvestable).
	_m_seed_fern_bare(b, rng, d)
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * 0.6, 1.2, sin(a) * 0.6)
		b.blob(p, Vector3(0.09, 0.12, 0.09), 2, 5, Color(0.70, 0.55, 0.25))


func _m_seed_fern_bare(b, rng: RandomNumberGenerator, d: int) -> void:
	b.cylinder(Vector3.ZERO, Vector3(0, 1.6, 0), 0.12, 0.08, 5, Color(0.32, 0.26, 0.16))
	var n: int = [5, 7, 9][d]
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.4
		b.leaf(Vector3(0, 1.5, 0), Vector3(cos(a), 0.6, sin(a)), 1.6, 0.6, 1.2, 3, Color(0.25, 0.42, 0.20), Color(0.42, 0.52, 0.24))


func _m_rotting_log(b, rng: RandomNumberGenerator, d: int) -> void:
	var sides: int = [5, 6, 8][d]
	b.cylinder(Vector3(-2.2, 0.35, 0), Vector3(2.2, 0.3, 0), 0.4, 0.33, sides, Color(0.30, 0.24, 0.16), Color(0.36, 0.30, 0.20), "wood")
	for i in 4:
		b.blob(Vector3(rng.randf_range(-1.8, 1.8), 0.66, rng.randf_range(-0.15, 0.15)),
			Vector3(0.3, 0.1, 0.25), 2, 5, Color(0.25, 0.40, 0.15), rng, 0.2)


func _m_clay_bank(b, rng: RandomNumberGenerator, d: int) -> void:
	for i in 4:
		b.blob(Vector3(rng.randf_range(-0.8, 0.8), 0.05, rng.randf_range(-0.8, 0.8)),
			Vector3(0.7, 0.18, 0.6), 2, 6, Color(0.55, 0.53, 0.50), rng, 0.15, "clay")


func _m_rock_big(b, rng: RandomNumberGenerator, d: int) -> void:
	b.blob(Vector3(0, 0.4, 0), Vector3(1.6, 1.1, 1.3), [2, 3, 4][d], [5, 7, 9][d], Color(0.45, 0.45, 0.42), rng, 0.25, "stone")


func _m_stash(b, rng: RandomNumberGenerator, d: int) -> void:
	## A woven frond sack set down on the ground, stuffed full and tied at the neck.
	_stash(b, rng, d, Items.def("fiber_sack").color, 0.12, 1.0)


func _m_stash_cloth_sack(b, rng: RandomNumberGenerator, d: int) -> void:
	## A cloth sack set down: paler, smoother and fuller (it holds twice as much).
	_stash(b, rng, d, Items.def("cloth_sack").color, 0.05, 1.2)


func _stash(b, rng: RandomNumberGenerator, d: int, col: Color, lumpy: float, size: float) -> void:
	b.blob(Vector3(0, 0.27, 0) * size, Vector3(0.36, 0.29, 0.32) * size, [2, 3, 3][d], [6, 8, 10][d], col, rng, lumpy, "fiber")
	b.cylinder(Vector3(0, 0.48, 0) * size, Vector3(0, 0.48 * size + 0.18, 0), 0.13, 0.07, 6, col * 0.9, Color(-1, 0, 0), "fiber")
	b.cylinder(Vector3(0, 0.48 * size + 0.09, 0), Vector3(0, 0.48 * size + 0.13, 0), 0.115, 0.11, 6, Color(0.40, 0.32, 0.18))
	b.blob(Vector3(0, 0.48 * size + 0.2, 0), Vector3(0.1, 0.05, 0.1), 1, 6, col * 0.8)


func _m_compost_basket(b, rng: RandomNumberGenerator, _d: int) -> void:
	## A compost basket set down (compost.gd): a slatted board crate on four
	## stick posts, open at the top.
	compost_basket(b, rng, 1.0)


func _m_compost_fill(b, rng: RandomNumberGenerator, _d: int) -> void:
	## What has gone into a compost basket: scraps, greens and twigs, its top
	## at y = 1 (compost.gd scales it to the level).
	compost_heap(b, rng, Color(0.25, 0.19, 0.10), true)


func _m_compost_done(b, rng: RandomNumberGenerator, _d: int) -> void:
	## Finished compost: dark and crumbly, filling the basket to the brim.
	compost_heap(b, rng, Color(0.16, 0.11, 0.07), false)


func compost_basket(b, rng: RandomNumberGenerator, done := 1.0, at := Vector3.ZERO, size := 1.0) -> void:
	## `done` < 1 leaves it unfinished: the posts first, then the slats rising
	## round the sides, course by course.
	var h := COMPOST_H * size
	var hw := COMPOST_W * 0.5 * size
	var board: Color = Items.def("board").color
	for i in 4:
		var c := Vector3(hw if i % 2 == 0 else -hw, 0, hw if i < 2 else -hw)
		stick(b, rng, at + c, at + c + Vector3(0, h + 0.04 * size, 0), 0.025 * size)
	var courses := 4
	var built := roundi(clampf((done - 0.25) / 0.75, 0.0, 1.0) * courses)
	for k in built:
		var y := (0.08 + k * 0.15) * size
		for side in 4:
			var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
			var out := Vector3(0, 0, hw if side == 0 else -hw) if side < 2 else Vector3(hw if side == 2 else -hw, 0, 0)
			var tint := board * (0.9 + 0.08 * ((k + side) % 3)) * (0.85 if side >= 2 else 1.0)
			var bs := Vector3(COMPOST_W * size + 0.06 * size, 0.1 * size, 0.025 * size) if side < 2 else Vector3(0.025 * size, 0.1 * size, COMPOST_W * size)
			b.box(at + out + Vector3(0, y, 0), bs, tint, Basis(), "wood")
			if k == built - 1 and done >= 1.0:
				lashing(b, at + out + along * hw * 0.98 + Vector3(0, y - 0.05 * size, 0), at + out + along * hw * 0.98 + Vector3(0, y + 0.05 * size, 0), 0.032 * size, 2)


const BEDROLL_R := 0.13   # a rolled-up bedroll's radius; it is bedroll.gd's LENGTH long


func bedroll(b, col: Color) -> void:
	## A coarse burlap sleeping bag rolled up along X and tied with two cords,
	## lying on the ground: the rolled layers show at its ends and the loose
	## edge of the outer layer runs along the top.
	var hl: float = 0.75 * 0.5
	var r := BEDROLL_R
	b.cylinder(Vector3(-hl, r, 0), Vector3(hl, r, 0), r, r, 12, col, Color(-1, 0, 0), "fiber")
	# Coarse weave: faint bands along the roll.
	for i in 6:
		var x := lerpf(-hl + 0.05, hl - 0.05, i / 5.0)
		b.cylinder(Vector3(x - 0.008, r, 0), Vector3(x + 0.008, r, 0), r + 0.002, r + 0.002, 12, col * 0.9, Color(-1, 0, 0), "fiber", false)
	# The rolled layers at each end, darker toward the middle.
	for side in [-1.0, 1.0]:
		for k in 3:
			var rr := r * (0.78 - k * 0.24)
			var x0: float = side * (hl + 0.002 + k * 0.002)
			b.cylinder(Vector3(x0, r, 0), Vector3(x0 + side * 0.003, r, 0), rr, rr, 10, col * (0.8 - k * 0.12), Color(-1, 0, 0), "fiber")
	# The loose edge of the outer layer.
	b.box(Vector3(0, r * 1.9, r * 0.45), Vector3(hl * 1.9, 0.012, 0.05), col * 0.95, Basis(Vector3.RIGHT, 0.5), "fiber")
	# Two ties.
	for x in [-hl * 0.55, hl * 0.55]:
		lashing(b, Vector3(x - 0.012, r, 0), Vector3(x + 0.012, r, 0), r + 0.008, 2)


const BAITBOX_W := 0.24   # a baitbox's outside width and height
const BAITBOX_H := 0.14


func baitbox(b, rng: RandomNumberGenerator, wood: Color, done := 1.0, at := Vector3.ZERO, rotten := false) -> void:
	## A little wooden cage of board strips packed with raw meat, the meat
	## showing between the bars. `done` < 1 leaves it unfinished: the base,
	## then the corner posts and the bars going on side by side, then the meat
	## and the slatted lid tied down over it (last quarter).
	var hw := BAITBOX_W * 0.5
	var t := 0.014        # board thickness
	var post := 0.022     # corner posts, square
	var bar := 0.018      # the bars between them
	var h := BAITBOX_H
	b.box(at + Vector3(0, t * 0.5, 0), Vector3(BAITBOX_W, t, BAITBOX_W), wood * 0.9, Basis(), "wood")
	if done >= 1.0:
		# The meat inside, seen through the bars.
		var meat: Color = Color(0.42, 0.36, 0.22) if rotten else Items.def("raw_meat").color
		b.blob(at + Vector3(-0.03, t + 0.035, 0.02), Vector3(0.07, 0.035, 0.06), 2, 6, meat, rng, 0.2, "organic")
		b.blob(at + Vector3(0.035, t + 0.04, -0.03), Vector3(0.055, 0.04, 0.05), 2, 6, meat.lightened(0.12), rng, 0.2, "organic")
	if done <= 0.25:
		return
	var inner := hw - post * 0.5
	for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		b.box(at + Vector3(c.x * inner, h * 0.5, c.y * inner), Vector3(post, h, post), wood * 0.85, Basis(), "wood")
	# The bars, side by side: two upright ones between the posts on each side,
	# held by a rail round the top.
	var sides := roundi(clampf((done - 0.25) / 0.5, 0.0, 1.0) * 4)
	for i in sides:
		var tint := wood * (0.92 + 0.05 * (i % 2))
		var along_x := i < 2
		var off := (inner if i % 2 == 0 else -inner)
		for k in 2:
			var u := (k - 0.5) * BAITBOX_W * 0.36
			var c := Vector3(u, h * 0.5, off) if along_x else Vector3(off, h * 0.5, u)
			b.box(at + c, Vector3(bar, h - t, t), tint, Basis() if along_x else Basis(Vector3.UP, PI * 0.5), "wood")
		var rail := Vector3(0, h - t * 0.5, off) if along_x else Vector3(off, h - t * 0.5, 0)
		b.box(at + rail, Vector3(BAITBOX_W - post, t, t) if along_x else Vector3(t, t, BAITBOX_W - post), tint * 0.95, Basis(), "wood")
	if done < 1.0:
		return
	# The lid: slats across the top with gaps, tied down at two corners.
	for k in 3:
		var z := (k - 1) * BAITBOX_W * 0.33
		b.box(at + Vector3(0, h + t * 0.5, z), Vector3(BAITBOX_W, t, bar * 1.4), wood * (0.95 + 0.04 * k), Basis(), "wood")
	for c in [Vector2(1, 1), Vector2(-1, -1)]:
		b.box(at + Vector3(c.x * inner, h + t, c.y * inner), Vector3(0.03, 0.012, 0.03), CORD, Basis(Vector3.UP, 0.7), "fiber")


func compost_heap(b, rng: RandomNumberGenerator, col: Color, scraps: bool) -> void:
	var hw := COMPOST_W * 0.5 - 0.03
	b.box(Vector3(0, 0.5, 0), Vector3(hw * 2.0, 1.0, hw * 2.0), col * 0.85, Basis(), "organic")
	for i in 7:
		var p := Vector3(rng.randf_range(-hw, hw) * 0.7, 1.0, rng.randf_range(-hw, hw) * 0.7)
		b.blob(p, Vector3(0.12, 0.05, 0.1), 2, 5, col * rng.randf_range(0.85, 1.15), rng, 0.3, "organic")
	if scraps:
		for i in 4:
			var p := Vector3(rng.randf_range(-hw, hw) * 0.7, 1.02, rng.randf_range(-hw, hw) * 0.7)
			b.leaf(p, Vector3(rng.randf_range(-1, 1), 0.1, rng.randf_range(-1, 1)).normalized(), 0.16, 0.06, 0.0, 2, Color(0.30, 0.42, 0.18))
		for i in 2:
			var a := rng.randf() * TAU
			var c := Vector3(rng.randf_range(-0.1, 0.1), 1.02, rng.randf_range(-0.1, 0.1))
			stick(b, rng, c - Vector3(cos(a), 0, sin(a)) * 0.15, c + Vector3(cos(a), 0, sin(a)) * 0.15, 0.012)


func _m_fish_trap(b, rng: RandomNumberGenerator, _d: int) -> void:
	## A fish trap set down (trap.gd).
	fish_trap(b, rng, 1.0)


func _m_snare_set(b, rng: RandomNumberGenerator, _d: int) -> void:
	## A snare set on the ground (trap.gd).
	snare_set(b, rng)


const FISH_TRAP := [Vector2(-0.45, 0.07), Vector2(-0.3, 0.17), Vector2(-0.1, 0.23), Vector2(0.15, 0.24), Vector2(0.42, 0.22)]  # (x, radius), tail to mouth
const FISH_TRAP_HOOPS := [-0.38, -0.22, -0.05, 0.12, 0.28, 0.42]


static func fish_trap_r(x: float) -> float:
	## The fish trap's radius at x along it.
	for i in FISH_TRAP.size() - 1:
		var a: Vector2 = FISH_TRAP[i]
		var c: Vector2 = FISH_TRAP[i + 1]
		if x <= c.x:
			return lerpf(a.y, c.y, clampf((x - a.x) / (c.x - a.x), 0.0, 1.0))
	return FISH_TRAP[-1].y


func fish_trap(b, rng: RandomNumberGenerator, done := 1.0, at := Vector3.ZERO, size := 1.0) -> void:
	## A long open cage of stick ribs lashed round cordage hoops, lying along X
	## (its middle at x 0, resting on y 0) with a funnel mouth at +X that fish
	## swim in by. `done` < 1 leaves it unfinished: the hoops first, then the
	## ribs, then the funnel.
	var cy := 0.24
	var hoops := mini(FISH_TRAP_HOOPS.size(), roundi(done * 12.0))
	for h in hoops:
		var x: float = FISH_TRAP_HOOPS[h]
		var r := fish_trap_r(x)
		var pts := []
		var radii := []
		for k in 13:
			var a := TAU * k / 12.0
			pts.append(at + Vector3(x, cy + r * cos(a), r * sin(a)) * size)
			radii.append(0.011 * size)
		b.tube(pts, radii, 4, [CORD * (0.62 + 0.06 * (h % 2))], "fiber")
	var ribs := clampi(roundi((done - 0.5) / 0.34 * 16.0), 0, 16)
	for i in ribs:
		var a := TAU * (i + 0.5) / 16.0
		var pts := []
		for p in FISH_TRAP:
			pts.append(at + Vector3(p.x, cy + p.y * cos(a), p.y * sin(a)) * size)
		b.tube(pts, [0.012 * size, 0.012 * size, 0.011 * size, 0.01 * size, 0.01 * size], 4, [WOOD * rng.randf_range(0.95, 1.15)], "wood")
	if ribs > 0:
		# The ribs gathered and tied off at the tail.
		lashing(b, at + Vector3(-0.47, cy, 0) * size, at + Vector3(-0.42, cy, 0) * size, 0.06 * size, 3)
	if done >= 1.0:
		# The funnel: short ribs from the mouth narrowing inward to a small ring.
		var inner := []
		var radii := []
		for k in 9:
			var a := TAU * k / 8.0
			inner.append(at + Vector3(0.14, cy + 0.06 * cos(a), 0.06 * sin(a)) * size)
			radii.append(0.006 * size)
		b.tube(inner, radii, 4, [CORD], "fiber")
		for i in 8:
			var a := TAU * i / 8.0
			b.cylinder(at + Vector3(0.42, cy + 0.21 * cos(a), 0.21 * sin(a)) * size, at + Vector3(0.14, cy + 0.06 * cos(a), 0.06 * sin(a)) * size,
					0.007 * size, 0.005 * size, 4, CUT_WOOD * 0.9, Color(-1, 0, 0), "wood")


func snare_set(b, rng: RandomNumberGenerator) -> void:
	## A branch bent over and staked at its butt, a string hanging from its
	## tip to a running noose held open between two twigs; the bait goes on the
	## ground just past it (trap.bait_point).
	var line: Color = Items.def("string").color
	stick(b, rng, Vector3(-0.62, -0.04, 0.0), Vector3(-0.5, 0.2, 0.0), 0.018)  # the stake
	var arc := []
	for k in 7:
		var t := k / 6.0
		arc.append(Vector3(lerpf(-0.58, 0.06, t), 0.02 + sin(t * PI * 0.62) * 0.5, 0.0))
	b.tube(arc, [0.02, 0.019, 0.017, 0.015, 0.013, 0.011, 0.009], 5, [WOOD, WOOD * 0.92, WOOD * 1.05], "wood")
	lashing(b, Vector3(-0.56, 0.06, 0.0), Vector3(-0.53, 0.12, 0.0), 0.03, 2)
	var tip: Vector3 = arc[-1]
	b.cylinder(tip, Vector3(0.06, 0.26, 0.0), 0.003, 0.003, 3, line, Color(-1, 0, 0), "fiber")
	var loop := []
	var radii := []
	for k in 13:
		var a := TAU * k / 12.0
		loop.append(Vector3(0.06, 0.16 + 0.1 * cos(a), 0.1 * sin(a)))
		radii.append(0.004)
	b.tube(loop, radii, 3, [line], "fiber")
	for z in [-0.12, 0.12]:
		stick(b, rng, Vector3(0.06, -0.03, z), Vector3(0.06, 0.22, z * 1.1), 0.008)


func snare_kit(b, rng: RandomNumberGenerator, done := 1.0) -> void:
	## A snare made up, to carry: the stripped branch with the string knotted
	## to its tip and the noose coiled at the end. `done` < 1 is still being
	## made: a branch with its side shoot and a loose string, then the noose
	## tied, then the string knotted on.
	var line: Color = Items.def("string").color
	stick(b, rng, Vector3(-0.3, 0.02, 0.0), Vector3(0.3, 0.02, 0.0), 0.018, done < 0.6)
	if done < 0.3:
		b.blob(Vector3(0.0, 0.01, 0.13), Vector3(0.06, 0.01, 0.05), 1, 6, line, rng, 0.2, "fiber")
		return
	var loop := []
	var radii := []
	for k in 13:
		var a := TAU * k / 12.0
		loop.append(Vector3(0.4 + 0.06 * cos(a), 0.005, 0.06 * sin(a)))
		radii.append(0.004)
	b.tube(loop, radii, 3, [line], "fiber")
	if done >= 0.9:
		b.cylinder(Vector3(0.29, 0.03, 0.0), Vector3(0.34, 0.006, 0.0), 0.003, 0.003, 3, line, Color(-1, 0, 0), "fiber")
		lashing(b, Vector3(0.26, 0.02, 0.0), Vector3(0.3, 0.02, 0.0), 0.022, 2)
	else:
		b.cylinder(Vector3(0.34, 0.006, 0.0), Vector3(0.1, 0.006, 0.12), 0.003, 0.003, 3, line, Color(-1, 0, 0), "fiber")


func _m_moss(b, rng: RandomNumberGenerator, d: int) -> void:
	b.blob(Vector3(0, 0.0, 0), Vector3(0.7, 0.25, 0.6), 2, 5, Color(0.25, 0.38, 0.14), rng, 0.2, "foliage")


# --- World item meshes (dropped / pickup items) -------------------------------

const COMPOST_W := 0.8   # a compost basket's width and height (compost.gd)
const COMPOST_H := 0.6
const CHERT := Color(0.30, 0.30, 0.35)
const CORTEX := Color(0.50, 0.44, 0.34)
const WOOD := Color(0.52, 0.40, 0.25)
const CORD := Color(0.66, 0.60, 0.36)
const FIRED := Color(0.70, 0.42, 0.28)
const HEAD_SHAPES := {"blade": "flint_blade", "axe_head": "axe_head", "spear_head": "spear_head", "mattock_head": "mattock_head"}


func _item_mesh(b, rng: RandomNumberGenerator, id: String) -> void:
	var def := Items.def(id)
	var col: Color = def.get("color", Color(0.6, 0.6, 0.6))
	var shape: String = def.get("shape", "")
	match shape:
		"stick":
			stick(b, rng, Vector3(-0.4, 0.035, 0), Vector3(0.4, 0.035, 0.03), 0.032, true)
		"log", "short_log":
			# Lies along X. The item's own look (icons, the recipe book) is a
			# Calamites log; logs in the world look like their tree (log_mesh).
			_log_of(b, rng, id, LOG_KIND)
		"firewood":
			# A split quarter of a round: a wedge with bark on its curved back.
			var sec := [Vector2(0, 0)]
			for k in 4:
				var ang := PI * 0.5 * k / 3.0
				sec.append(Vector2(cos(ang) * LOG_R * 1.3 - LOG_R * 0.6, sin(ang) * LOG_R * 1.3))
			var cols := [col, Color(0.30, 0.25, 0.17), Color(0.32, 0.26, 0.18), Color(0.30, 0.25, 0.17), col * 0.95]
			prism(b, sec, 0.22, cols, CUT_WOOD, "wood")
		"bark":
			# A curled strip peeled off a log: bark outside, pale inner side.
			for k in 4:
				var a0 := -0.9 + k * 0.45
				var a1 := a0 + 0.45
				var p0 := Vector3(0, 0.12 - cos(a0) * 0.06, sin(a0) * 0.07)
				var p1 := Vector3(0, 0.12 - cos(a1) * 0.06, sin(a1) * 0.07)
				var out := Vector3(0, -cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5) * 0.5)
				var q := [Vector3(-0.28, p0.y, p0.z), Vector3(-0.28, p1.y, p1.z), Vector3(0.28, p1.y, p1.z), Vector3(0.28, p0.y, p0.z)]
				_face(b, q.duplicate(), out, col * (0.9 + 0.05 * k), "wood")
				_face(b, q.duplicate(), -out, CUT_WOOD * 0.85, "wood")
		"branch":
			stick(b, rng, Vector3(-0.55, 0.04, 0), Vector3(0.55, 0.04, 0.05), 0.045, true)
			for k in 2:
				var at := Vector3(-0.15 + k * 0.4, 0.04, 0.02)
				var tip := at + Vector3(0.18, 0.02, 0.16 * (1 if k == 0 else -1))
				b.cylinder(at, tip, 0.02, 0.01, 4, WOOD * 0.9, Color(-1, 0, 0), "wood")
				b.leaf(tip, Vector3(1, 0.1, 0.6 * (1 if k == 0 else -1)), 0.22, 0.08, 0.05, 2, Color(0.28, 0.48, 0.18), LEAF_LIGHT)
		"plank":
			b.box(Vector3(0, 0.025, 0), Vector3(1.9, 0.05, 0.2), col, Basis(), "wood")
			b.box(Vector3(0, 0.051, 0.04), Vector3(1.86, 0.002, 0.012), col * 0.85, Basis(), "wood")
		"rock":
			b.blob(Vector3(0, 0.075, 0), Vector3(0.14, 0.085, 0.12), 3, 7, Color(0.55, 0.55, 0.52), rng, 0.15, "stone")
		"flint":
			# A chalky nodule broken open on one side to show the dark chert.
			b.blob(Vector3(0, 0.07, 0), Vector3(0.12, 0.075, 0.1), 3, 6, CORTEX, rng, 0.2, "stone")
			b.blob(Vector3(0.06, 0.08, 0.01), Vector3(0.07, 0.06, 0.075), 2, 5, CHERT, rng, 0.2, "stone")
		"fiber":
			for i in 9:
				var z := (i - 4) * 0.012
				var pts := []
				for k in 5:
					var x := -0.22 + k * 0.11
					pts.append(Vector3(x, 0.008 + rng.randf() * 0.012, z + rng.randf_range(-0.012, 0.012)))
				b.tube(pts, [0.005, 0.006, 0.006, 0.005, 0.003], 3, [col * rng.randf_range(0.8, 1.1)], "fiber")
		"cord":
			# A coil of twisted cord with a loose end.
			var pts := []
			var radii := []
			for k in 29:
				var ang := k / 28.0 * TAU * 2.4
				var r := 0.075 - k * 0.0012
				pts.append(Vector3(cos(ang) * r, 0.01 + 0.004 * sin(ang * 0.5) + k * 0.0006, sin(ang) * r))
				radii.append(0.009)
			pts.append(pts[-1] + Vector3(0.09, -0.01, 0.03))
			radii.append(0.008)
			b.tube(pts, radii, 4, [col], "fiber")
		"frond":
			b.cylinder(Vector3(-0.55, 0.03, 0), Vector3(-0.3, 0.04, 0), 0.012, 0.01, 4, col.darkened(0.3), Color(-1, 0, 0), "organic")
			b.leaf(Vector3(-0.5, 0.05, 0), Vector3(1, 0.1, 0), 1.0, 0.4, 0.1, 3, col)
		"tinder":
			# Curls of shredded inner bark.
			for i in 7:
				var c := Vector3(rng.randf_range(-0.07, 0.07), 0.015 + i * 0.006, rng.randf_range(-0.05, 0.05))
				var basis := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
				b.box(c, Vector3(0.16, 0.006, 0.03), col * rng.randf_range(0.85, 1.1), basis, "wood")
		"clay":
			b.blob(Vector3(0, 0.055, 0), Vector3(0.13, 0.065, 0.11), 3, 7, col, rng, 0.12, "clay")
			b.blob(Vector3(0.04, 0.1, 0.02), Vector3(0.05, 0.03, 0.045), 2, 5, col * 0.95, rng, 0.1, "clay")
		"chitin":
			# A curved, ridged plate of shell.
			for k in 4:
				var x0 := -0.12 + k * 0.06
				var y0 := 0.02 + sin(k / 4.0 * PI) * 0.04
				var y1 := 0.02 + sin((k + 1) / 4.0 * PI) * 0.04
				var x1 := x0 + 0.06
				b.quad(Vector3(x0, y0, -0.08), Vector3(x1, y1, -0.08), Vector3(x1, y1, 0.08), Vector3(x0, y0, 0.08), col * (1.0 - k * 0.05), "organic")
				b.quad(Vector3(x0, y0 - 0.012, 0.08), Vector3(x1, y1 - 0.012, 0.08), Vector3(x1, y1 - 0.012, -0.08), Vector3(x0, y0 - 0.012, -0.08), col * 0.6, "organic")
				b.box(Vector3(x1, y1 + 0.004, 0), Vector3(0.012, 0.01, 0.15), col.darkened(0.35), Basis(), "organic")
		"seed":
			for i in 3:
				var c := Vector3((i - 1) * 0.055, 0.03, rng.randf_range(-0.02, 0.02))
				b.blob(c, Vector3(0.03, 0.028, 0.045), 4, 7, col * rng.randf_range(0.9, 1.05), rng, 0.08, "organic")
				b.box(c + Vector3(0, 0.026, 0), Vector3(0.006, 0.008, 0.07), col.darkened(0.25), Basis(), "organic")
		"sprout":
			# A fiddlehead: a tightly coiled shoot on a short stem.
			var pts := [Vector3(-0.12, 0.012, 0), Vector3(-0.04, 0.02, 0)]
			for k in 14:
				var ang := k / 13.0 * TAU * 1.3
				var r := 0.05 * (1.0 - k / 16.0)
				pts.append(Vector3(cos(ang) * r, 0.055 + sin(ang) * r, 0.0))
			var radii := []
			for k in pts.size():
				radii.append(lerpf(0.012, 0.006, float(k) / pts.size()))
			b.tube(pts, radii, 4, [col.darkened(0.15), col], "organic")
		"shoot":
			# A horsetail shoot: a jointed green spear, each joint ringed with
			# a dark collar of tiny leaves, and a pale cone at the tip.
			for k in 4:
				var x0 := -0.12 + k * 0.05
				b.cylinder(Vector3(x0, 0.018, 0), Vector3(x0 + 0.05, 0.018, 0), 0.016 - k * 0.002, 0.014 - k * 0.002, 6, col, Color(-1, 0, 0), "organic")
				b.cylinder(Vector3(x0 + 0.046, 0.018, 0), Vector3(x0 + 0.054, 0.018, 0), 0.02 - k * 0.002, 0.02 - k * 0.002, 6, col.darkened(0.4), Color(-1, 0, 0), "organic")
			b.cone(Vector3(0.08, 0.018, 0), Vector3(0.13, 0.018, 0), 0.012, 6, col.lightened(0.3), "organic")
		"grub":
			for k in 6:
				var ang := k / 5.0 * PI * 1.1
				var r := 0.024 - k * 0.002
				var c := Vector3(cos(ang) * 0.042, r, sin(ang) * 0.042)
				b.blob(c, Vector3(r * 1.3, r, r * 1.3), 4, 7, col.darkened(0.55) if k == 0 else col * (1.0 - k * 0.03), rng, 0.05, "organic")
		"meat":
			b.blob(Vector3(0, 0.045, 0), Vector3(0.14, 0.045, 0.1), 2, 7, col, rng, 0.12, "organic")
			b.blob(Vector3(-0.03, 0.08, -0.02), Vector3(0.08, 0.018, 0.06), 2, 6, col.lightened(0.35), rng, 0.1, "organic")
		"blob":
			b.blob(Vector3(0, 0.05, 0), Vector3(0.12, 0.05, 0.1), 2, 6, col, rng, 0.3, "organic")
		"whorl":
			whorl(b, col, Vector3(0, 0.008, 0), Vector3.UP)
		"rod":
			# A long tapered pole (lying along x like the spear).
			stick(b, rng, Vector3(-0.65, 0.02, 0), Vector3(0.3, 0.02, 0), 0.017)
			b.cylinder(Vector3(0.3, 0.02, 0), Vector3(0.7, 0.02, 0), 0.017, 0.008, 6, CUT_WOOD, Color(-1, 0, 0), "wood")
		"fishing_rod":
			stick(b, rng, Vector3(-0.65, 0.02, 0), Vector3(0.3, 0.02, 0), 0.017)
			b.cylinder(Vector3(0.3, 0.02, 0), Vector3(0.7, 0.02, 0), 0.017, 0.008, 6, CUT_WOOD, Color(-1, 0, 0), "wood")
			var line: Color = Items.def("fishing_line").color
			b.cylinder(Vector3(0.7, 0.02, 0), Vector3(-0.35, 0.026, 0.015), 0.002, 0.002, 3, line, Color(-1, 0, 0), "fiber")
			b.cylinder(Vector3(-0.42, 0.018, 0.0), Vector3(-0.42, 0.036, 0.0), 0.022, 0.022, 8, line, Color(-1, 0, 0), "fiber")
			knapped(b, Items.knap_grid("chitin_hook"), 0.008, 0.004, Items.def("chitin_hook").color, rng,
					Transform3D(Basis(), Vector3(-0.36, 0.005, 0.045)), "organic")
		"root":
			# A knobbly root with a few thin rootlets trailing off it.
			b.blob(Vector3(0, 0.025, 0), Vector3(0.06, 0.025, 0.035), 2, 6, col, rng, 0.3, "organic")
			b.blob(Vector3(0.045, 0.02, 0.01), Vector3(0.03, 0.02, 0.025), 1, 5, col.darkened(0.1), rng, 0.3, "organic")
			for i in 3:
				var a := -0.6 + i * 0.6
				b.cylinder(Vector3(-0.04, 0.015, 0), Vector3(-0.04 - cos(a) * 0.08, 0.008, sin(a) * 0.05), 0.006, 0.002, 3, col.darkened(0.25), Color(-1, 0, 0), "organic")
		"fish":
			# A small fish lying on its side: body, belly, eye and tail fin.
			b.blob(Vector3(0, 0.035, 0), Vector3(0.13, 0.035, 0.04), 2, 7, col, rng, 0.05, "organic")
			b.blob(Vector3(-0.02, 0.025, 0.012), Vector3(0.1, 0.022, 0.03), 2, 6, col.lightened(0.3), rng, 0.05, "organic")
			b.blob(Vector3(-0.1, 0.05, 0.03), Vector3(0.008, 0.008, 0.008), 1, 4, Color(0.1, 0.1, 0.08))
			b.leaf(Vector3(0.12, 0.035, 0), Vector3(1, 0, 0.5).normalized(), 0.07, 0.04, 0.0, 2, col.darkened(0.2))
			b.leaf(Vector3(0.12, 0.035, 0), Vector3(1, 0, -0.5).normalized(), 0.07, 0.04, 0.0, 2, col.darkened(0.2))
		"hook":
			knapped(b, Items.knap_grid("chitin_hook"), 0.014, 0.006, col, rng, Transform3D(Basis(), Vector3(0, 0.004, 0)), "organic")
		"spindle":
			stick(b, rng, Vector3(-0.22, 0.016, 0), Vector3(0.22, 0.016, 0), 0.012)
			whorl(b, Items.def("spindle_whorl").color, Vector3(-0.13, 0.036, 0), Vector3.RIGHT)
		"ember":
			# A lumpy coal, glowing (unshaded) orange with a darker crust.
			b.blob(Vector3(0, 0.035, 0), Vector3(0.06, 0.035, 0.05), 2, 6, col, rng, 0.35, "glow")
			b.blob(Vector3(0.025, 0.05, 0.01), Vector3(0.03, 0.02, 0.028), 1, 5, Color(0.25, 0.08, 0.04), rng, 0.3)
		"lizard":
			small_prey(b, rng, col, def.get("animal", ""), id.ends_with("_carcass"), Vector3.ZERO, def.get("body_scale", 1.0))
		"dragonfly":
			# Long thin abdomen, a stubby thorax and two pairs of wings.
			b.tube([Vector3(-0.3, 0.02, 0), Vector3(-0.1, 0.022, 0), Vector3(0.05, 0.025, 0)], [0.008, 0.012, 0.016], 4, [col], "organic")
			b.blob(Vector3(0.09, 0.028, 0), Vector3(0.045, 0.026, 0.028), 2, 6, col.darkened(0.15), rng, 0.05, "organic")
			b.blob(Vector3(0.14, 0.03, 0), Vector3(0.022, 0.022, 0.026), 2, 6, col.darkened(0.3), rng, 0.0, "organic")
			var wing := Color(0.75, 0.78, 0.72) if id == "dragonfly_carcass" else col.lightened(0.35)
			for side in [-1.0, 1.0]:
				for k in 2:
					b.leaf(Vector3(0.09 - k * 0.05, 0.035, 0), Vector3(-0.15 * k, 0.0, side).normalized(), 0.3, 0.06, 0.0, 3, wing)
		"guts":
			for i in 2:
				gut_coil(b, rng, Vector3((i - 0.5) * 0.08, 0, rng.randf_range(-0.03, 0.03)), col * rng.randf_range(0.9, 1.1))
		"blade", "axe_head", "spear_head", "mattock_head":
			knapped(b, Items.knap_grid(HEAD_SHAPES[shape]), 0.036, 0.03, CHERT, rng, Transform3D(Basis(), Vector3(0, 0.016, 0)))
		"axe":
			stick(b, rng, Vector3(-0.3, 0.03, 0), Vector3(0.26, 0.03, 0), 0.022)
			knapped(b, Items.knap_grid("axe_head"), 0.036, 0.034, CHERT, rng, Transform3D(Basis(), Vector3(0.24, 0.03, -0.075)))
			lashing(b, Vector3(0.19, 0.03, 0), Vector3(0.29, 0.03, 0), 0.03, 5)
		"mattock":
			# The head crosses the end of the handle like a T.
			stick(b, rng, Vector3(-0.32, 0.03, 0), Vector3(0.28, 0.03, 0), 0.022)
			knapped(b, Items.knap_grid("mattock_head"), 0.04, 0.034, CHERT, rng, Transform3D(Basis(), Vector3(0.27, 0.03, 0.0)))
			lashing(b, Vector3(0.2, 0.03, 0), Vector3(0.31, 0.03, 0), 0.03, 5)
		"torch", "torch_lit":
			stick(b, rng, Vector3(-0.32, 0.03, 0), Vector3(0.2, 0.03, 0), 0.022)
			var wax: Color = Items.def("wax").color
			if shape == "torch_lit":
				wax = Color(0.18, 0.13, 0.08)
			b.blob(Vector3(0.22, 0.032, 0), Vector3(0.075, 0.034, 0.034), 3, 7, wax, rng, 0.15, "organic")
			if shape == "torch_lit":
				# A few small tongues of flame licking off the waxed head.
				for k in 3:
					var o := Vector3(0.0, 0.0, (k - 1) * 0.018)
					var tip := Vector3(0.3 + 0.03 * float(k % 2), 0.075 + 0.02 * float(k == 1), o.z * 1.6)
					b.cone(Vector3(0.24, 0.04, 0) + o, tip, 0.018, 4, Color(1.0, 0.55, 0.12), "glow")
				b.cone(Vector3(0.245, 0.04, 0), Vector3(0.29, 0.06, 0), 0.014, 4, Color(1.0, 0.88, 0.45), "glow")
		"wax":
			for i in 4:
				var c := Vector3(rng.randf_range(-0.05, 0.05), 0.02, rng.randf_range(-0.04, 0.04))
				b.blob(c, Vector3(0.035, 0.02, 0.03), 2, 6, col * rng.randf_range(0.9, 1.08), rng, 0.25, "organic")
		"ash":
			b.cone(Vector3(0, 0, 0), Vector3(0, 0.05, 0), 0.11, 9, col)
			b.blob(Vector3(0.03, 0.012, 0.02), Vector3(0.06, 0.012, 0.05), 2, 6, col.darkened(0.25), rng, 0.3)
		"scraps":
			for i in 3:
				var c := Vector3((i - 1) * 0.06, 0.022, rng.randf_range(-0.03, 0.03))
				b.blob(c, Vector3(0.04, 0.022, 0.03), 2, 6, col * rng.randf_range(0.85, 1.05), rng, 0.25, "organic")
		"spear":
			stick(b, rng, Vector3(-0.8, 0.026, 0), Vector3(0.0, 0.026, 0), 0.022)
			stick(b, rng, Vector3(-0.06, 0.026, 0), Vector3(0.62, 0.026, 0), 0.02)
			lashing(b, Vector3(-0.09, 0.026, 0), Vector3(0.03, 0.026, 0), 0.027, 4)
			knapped(b, Items.knap_grid("spear_head"), 0.036, 0.03, CHERT, rng, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.7, 0.026, 0)))
			lashing(b, Vector3(0.57, 0.026, 0), Vector3(0.65, 0.026, 0), 0.025, 4)
		"drill":
			# Bow, string and spindle.
			var bow := []
			for k in 7:
				var t := k / 6.0
				bow.append(Vector3(lerpf(-0.26, 0.26, t), 0.018, -sin(t * PI) * 0.07))
			b.tube(bow, [0.012, 0.014, 0.015, 0.015, 0.015, 0.014, 0.012], 5, [WOOD], "wood")
			b.cylinder(bow[0], bow[6], 0.004, 0.004, 3, CORD, Color(-1, 0, 0), "fiber")
			stick(b, rng, Vector3(-0.1, 0.014, 0.09), Vector3(0.12, 0.014, 0.12), 0.013)
		"fire":
			for i in 5:
				var z := (i - 2) * 0.035
				stick(b, rng, Vector3(-0.25, 0.025 + (i % 2) * 0.03, z), Vector3(0.25, 0.025 + (i % 2) * 0.03, z + 0.01), 0.022)
			lashing(b, Vector3(-0.15, 0.04, 0), Vector3(-0.12, 0.04, 0), 0.1, 1)
			lashing(b, Vector3(0.12, 0.04, 0), Vector3(0.15, 0.04, 0), 0.1, 1)
			b.blob(Vector3(0, 0.1, 0), Vector3(0.07, 0.03, 0.05), 2, 5, Color(0.70, 0.58, 0.38), rng, 0.3, "wood")
			b.blob(Vector3(-0.1, 0.05, 0.16), Vector3(0.07, 0.05, 0.06), 2, 6, Color(0.55, 0.55, 0.52), rng, 0.15, "stone")
			b.blob(Vector3(0.1, 0.05, 0.16), Vector3(0.07, 0.05, 0.06), 2, 6, Color(0.5, 0.5, 0.48), rng, 0.15, "stone")
		"pot_capped":
			# A clay pot with a wooden cap pressed into its mouth, waxed round.
			pot(b, col, 1.0)
			b.cylinder(Vector3(0, 0.183, 0), Vector3(0, 0.196, 0), 0.086, 0.086, 10, Color(0.85, 0.78, 0.45), Color(-1, 0, 0), "solid")
			b.cylinder(Vector3(0, 0.196, 0), Vector3(0, 0.212, 0), 0.08, 0.074, 10, CANTEEN_WOOD, CANTEEN_WOOD * 0.9, "wood")
			b.cylinder(Vector3(0, 0.212, 0), Vector3(0, 0.228, 0), 0.016, 0.013, 7, CANTEEN_WOOD * 0.92, Color(-1, 0, 0), "wood")
		"pot_cap":
			# A round cap with a lip, lying knob up.
			b.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.014, 0), 0.08, 0.076, 10, col * 0.9, col, "wood")
			b.cylinder(Vector3(0, 0.014, 0), Vector3(0, 0.03, 0), 0.016, 0.013, 7, col * 0.92, Color(-1, 0, 0), "wood")
		"pot", "pot_water":
			pot(b, col if shape == "pot" else FIRED, 1.0)
			if shape == "pot_water":
				b.lathe([Vector2(0.092, 0.15), Vector2(0.0, 0.15)], 10, col, "solid", Vector3.ZERO, false)
		"bandage":
			b.cylinder(Vector3(0, 0.036, -0.04), Vector3(0, 0.036, 0.04), 0.036, 0.036, 8, col, Color(-1, 0, 0), "fiber")
			b.cylinder(Vector3(0, 0.036, -0.041), Vector3(0, 0.036, 0.041), 0.012, 0.012, 6, col.darkened(0.3), Color(-1, 0, 0), "fiber")
			b.box(Vector3(0.09, 0.003, 0), Vector3(0.12, 0.004, 0.08), col * 0.95, Basis(), "fiber")
		"basket":
			compost_basket(b, rng, 1.0, Vector3.ZERO, 0.45)
		"baitbox":
			baitbox(b, rng, col, 1.0, Vector3.ZERO, id == "baitbox_rotten")
		"bedroll":
			bedroll(b, col)
		"fish_trap":
			fish_trap(b, rng, 1.0, Vector3.ZERO, 0.6)
		"snare":
			snare_kit(b, rng, 1.0)
		"compost":
			# A dark, crumbly handful.
			b.blob(Vector3(0, 0.03, 0), Vector3(0.12, 0.04, 0.1), 2, 6, col, rng, 0.35, "organic")
			b.blob(Vector3(0.06, 0.05, 0.02), Vector3(0.05, 0.03, 0.05), 2, 5, col.lightened(0.12), rng, 0.3, "organic")
			b.blob(Vector3(-0.05, 0.045, -0.03), Vector3(0.05, 0.03, 0.04), 2, 5, col.darkened(0.15), rng, 0.3, "organic")
		"sack":
			# Folded up and tied, ready to carry.
			b.blob(Vector3(0, 0.05, 0), Vector3(0.2, 0.05, 0.16), 2, 8, col, rng, 0.15, "fiber")
			b.cylinder(Vector3(0.17, 0.05, 0), Vector3(0.27, 0.04, 0), 0.05, 0.03, 6, col * 0.9, Color(-1, 0, 0), "fiber")
			lashing(b, Vector3(0.2, 0.048, 0), Vector3(0.23, 0.046, 0), 0.05, 2)
		"salt":
			# A thin, cracked white crust broken off the bank.
			b.blob(Vector3(0, 0.012, 0), Vector3(0.13, 0.014, 0.1), 2, 8, col, rng, 0.2, "stone")
			b.blob(Vector3(0.05, 0.022, -0.02), Vector3(0.06, 0.012, 0.05), 2, 6, col.lightened(0.3), rng, 0.25, "stone")
			b.blob(Vector3(-0.06, 0.02, 0.03), Vector3(0.05, 0.01, 0.04), 2, 6, col * 0.92, rng, 0.25, "stone")
		"soup_pot":
			soup_pot(b, col)
		"canteen":
			canteen(b, col)
		"vessel":
			vessel(b, col, id.begins_with("vessel_sealed"))
		"platter":
			platter(b, col)
		"bowl":
			bowl(b, col)
		"chisel_saw":
			chisel_saw(b, rng)
		"paper":
			paper(b, rng, col)
		"pencil_core":
			b.cylinder(Vector3(-0.09, 0.006, 0), Vector3(0.09, 0.006, 0), 0.006, 0.006, 6, col, Color(-1, 0, 0), "clay")
		"pencil":
			pencil(b, rng)
		"blueprint":
			# A sheet rolled up and tied round the middle with a cord.
			b.cylinder(Vector3(-0.17, 0.03, 0), Vector3(0.17, 0.03, 0), 0.03, 0.03, 9, col, col * 0.85, "fiber")
			b.cylinder(Vector3(-0.172, 0.03, 0), Vector3(-0.17, 0.03, 0), 0.012, 0.012, 9, col * 0.7, Color(-1, 0, 0), "fiber")
			lashing(b, Vector3(-0.012, 0.03, 0), Vector3(0.012, 0.03, 0), 0.032, 3)
		"paper_tools":
			# The fiber screen in its stick frame, with the bowl beside it.
			paper_screen(b, rng, Vector3(-0.1, 0, 0), 1.0)
			bowl(b, col, Vector3(0.2, 0, 0), 0.9)
		"workbench":
			workbench(b, rng)
		"mug", "mug_full":
			coffee_mug(b, col, shape == "mug_full")
		"papers":
			for i in 6:
				b.box(Vector3(rng.randf_range(-0.01, 0.01), 0.002 + i * 0.004, rng.randf_range(-0.01, 0.01)), Vector3(0.21, 0.002, 0.28),
						col * rng.randf_range(0.9, 1.0), Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), "fiber")
		"keycard":
			b.box(Vector3(0, 0.002, 0), Vector3(0.086, 0.003, 0.054), col)
			b.box(Vector3(0, 0.004, -0.012), Vector3(0.086, 0.001, 0.01), Color(0.92, 0.92, 0.9))
			b.box(Vector3(-0.025, 0.004, 0.01), Vector3(0.022, 0.001, 0.026), Color(0.85, 0.7, 0.55))
			b.blob(Vector3(0.02, 0.005, 0.012), Vector3(0.022, 0.002, 0.014), 1, 5, Color(0.36, 0.28, 0.18), rng, 0.3, "organic")
		"pipe":
			b.cylinder(Vector3(-0.5, 0.08, 0), Vector3(0.5, 0.08, 0), 0.07, 0.07, 8, Color(0.75, 0.77, 0.80), Color(-1, 0, 0), "metal")
		"coil":
			b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.18, 0), 0.14, 0.14, 8, Color(0.80, 0.45, 0.20))
			b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.2, 0), 0.06, 0.06, 6, Color(0.3, 0.3, 0.32))
		"board":
			b.box(Vector3(0, 0.015, 0), Vector3(0.3, 0.03, 0.2), Color(0.15, 0.55, 0.25))
			b.box(Vector3(0.05, 0.05, 0), Vector3(0.08, 0.04, 0.08), Color(0.1, 0.1, 0.1))
		"wire":
			b.cylinder(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 0.12, 0.12, 8, Color(0.85, 0.55, 0.25))
		"cell":
			b.box(Vector3(0, 0.1, 0), Vector3(0.18, 0.2, 0.12), Color(0.25, 0.45, 0.85))
			b.box(Vector3(0, 0.21, 0), Vector3(0.06, 0.03, 0.04), Color(0.8, 0.8, 0.8))
		"segment", "injector":
			b.cylinder(Vector3(-0.4, 0.1, 0), Vector3(0.4, 0.1, 0), 0.08, 0.08, 8, Color(0.75, 0.77, 0.80), Color(-1, 0, 0), "metal")
			b.box(Vector3(0, 0.1, 0), Vector3(0.25, 0.25, 0.25), col)
		_:
			b.blob(Vector3(0, 0.08, 0), Vector3(0.12, 0.08, 0.12), 2, 5, col, rng, 0.1)


# --- Shared item parts (also used by the crafting work spot) -------------------

func coffee_mug(b, col: Color, full := false, at := Vector3.ZERO) -> void:
	## A breakroom mug, its handle out to the side; `full` of black coffee.
	b.lathe([Vector2(0.0, 0.0), Vector2(0.044, 0.0), Vector2(0.042, 0.1), Vector2(0.036, 0.1), Vector2(0.034, 0.012), Vector2(0.0, 0.012)], 12, col, "solid", at)
	b.tube([at + Vector3(0.04, 0.08, 0), at + Vector3(0.075, 0.075, 0), at + Vector3(0.078, 0.04, 0), at + Vector3(0.042, 0.025, 0)],
			[0.008, 0.008, 0.008, 0.008], 5, [col])
	if full:
		b.lathe([Vector2(0.036, 0.085), Vector2(0.0, 0.085)], 12, Color(0.18, 0.1, 0.05), "solid", at, false)


func gut_coil(b, rng: RandomNumberGenerator, at: Vector3, col: Color) -> void:
	## A loose heap of looped intestine.
	var pts := []
	var radii := []
	for k in 12:
		var ang := k * 1.1 + rng.randf() * 0.4
		var r := 0.05 + 0.03 * sin(k * 0.7)
		pts.append(at + Vector3(cos(ang) * r, 0.02 + k * 0.004, sin(ang) * r))
		radii.append(0.018)
	b.tube(pts, radii, 4, [col, col.lightened(0.15)], "organic")


func whorl(b, col: Color, at: Vector3, axis: Vector3, hole := true) -> void:
	## A spindle whorl: a fat clay disc around `axis`, with a dark hole through
	## the middle once it is pierced.
	var h := axis.normalized() * 0.008
	b.cylinder(at - h, at + h, 0.035, 0.035, 10, col, Color(-1, 0, 0), "clay")
	if hole:
		b.cylinder(at - h * 1.2, at + h * 1.2, 0.007, 0.007, 6, Color(0.15, 0.1, 0.08), Color(-1, 0, 0), "clay")


func stick(b, rng: RandomNumberGenerator, from: Vector3, to: Vector3, r: float, twig := false) -> void:
	## A slightly crooked branch, thinner toward `to`.
	var pts := []
	var side := (to - from).cross(Vector3.UP).normalized()
	for k in 4:
		var t := k / 3.0
		var bend := 0.0 if k == 0 or k == 3 else rng.randf_range(-0.6, 0.6) * r
		pts.append(from.lerp(to, t) + side * bend)
	b.tube(pts, [r, r * 0.92, r * 0.84, r * 0.75], 5, [WOOD, WOOD * 0.92, WOOD * 1.05], "wood")
	if twig:
		var at: Vector3 = pts[1]
		b.cylinder(at, at + (to - from).normalized() * 0.1 + side * 0.08 + Vector3(0, 0.01, 0), r * 0.45, r * 0.2, 4, WOOD * 0.9, Color(-1, 0, 0), "wood")


const LOG_LEN := 2.0
const SHORT_LOG_LEN := 0.5
const LOG_R := 0.16


func prism(b, sec: Array, half_len: float, cols: Array, end_col: Color, slot := "solid") -> void:
	## A cross-section (Vector2(z, y) points around a convex outline) drawn out
	## along X from -half_len to half_len. Side k runs from point k to k + 1
	## in colour cols[k]; the two ends are flat in end_col.
	var n := sec.size()
	var mid := Vector3.ZERO
	for p in sec:
		mid += Vector3(0, p.y, p.x)
	mid /= n
	for k in n:
		var p0: Vector2 = sec[k]
		var p1: Vector2 = sec[(k + 1) % n]
		var out := Vector3(0, (p0.y + p1.y) * 0.5, (p0.x + p1.x) * 0.5) - mid
		_face(b, [Vector3(-half_len, p0.y, p0.x), Vector3(-half_len, p1.y, p1.x), Vector3(half_len, p1.y, p1.x), Vector3(half_len, p0.y, p0.x)], out, cols[mini(k, cols.size() - 1)], slot)
	for e in [-1.0, 1.0]:
		for k in range(1, n - 1):
			var p0: Vector2 = sec[0]
			var p1: Vector2 = sec[k]
			var p2: Vector2 = sec[k + 1]
			_face(b, [Vector3(half_len * e, p0.y, p0.x), Vector3(half_len * e, p1.y, p1.x), Vector3(half_len * e, p2.y, p2.x)], Vector3(e, 0, 0), end_col, slot)


func _face(b, pts: Array, facing: Vector3, col: Color, slot: String) -> void:
	## A flat triangle or quad turned to face `facing`.
	var n: Vector3 = (pts[2] - pts[0]).cross(pts[1] - pts[0])
	if n.dot(facing) < 0.0:
		pts.reverse()
	if pts.size() == 4:
		b.quad(pts[0], pts[1], pts[2], pts[3], col, slot)
	else:
		b.tri(pts[0], pts[1], pts[2], col, slot)


## Each tree's logs: the bark colour (tinting its bark texture, see
## detail_textures), the colour of the wood under it (stripped), and how
## its bark is broken up: branch stubs (scale tree), joint rings (horsetail),
## old frond bases (tree fern) or none (seal tree, which never branches low).
const LOG_KIND := "calamites"   # a log whose tree isn't known (old saves, the item's icon)
const LOG_LOOKS := {
	"lepidodendron": {"bark": Color(0.36, 0.33, 0.24), "wood": Color(0.70, 0.60, 0.42), "detail": "stubs"},
	"sigillaria": {"bark": Color(0.30, 0.27, 0.20), "wood": Color(0.66, 0.55, 0.38), "detail": ""},
	"calamites": {"bark": Color(0.31, 0.34, 0.19), "wood": Color(0.70, 0.66, 0.46), "detail": "joints"},
	"tree_fern": {"bark": Color(0.28, 0.21, 0.14), "wood": Color(0.52, 0.38, 0.24), "detail": "frond_bases"},
}


func log_mesh(id: String, kind: String) -> Mesh:
	## A log, stripped log or short log from a tree of this kind, cached.
	if not LOG_LOOKS.has(kind):
		kind = LOG_KIND
	var key := "log|%s|%s" % [id, kind]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	_log_of(b, rng, id, kind)
	var m: Mesh = b.commit(materials)
	_cache[key] = m
	return m


func _log_of(b, rng: RandomNumberGenerator, id: String, kind: String) -> void:
	var look: Dictionary = LOG_LOOKS.get(kind, LOG_LOOKS[LOG_KIND])
	var length := SHORT_LOG_LEN if id == "short_log" else LOG_LEN
	if id == "log_stripped":
		log_piece(b, rng, length, LOG_R, look.wood, false, Vector3.ZERO, kind)
	else:
		log_piece(b, rng, length, LOG_R, look.bark, true, Vector3.ZERO, kind)


func log_piece(b, rng: RandomNumberGenerator, length: float, r: float, col: Color, bark: bool, at := Vector3.ZERO, kind := "") -> void:
	## A length of trunk lying along X with its centre at `at` (resting on
	## the ground at y = 0), with cut ends of pale wood and growth rings. With
	## a tree `kind` it has that tree's bark (or, stripped, its wood).
	var sides := 10
	var hl := length * 0.5
	var c := at + Vector3(0, r, 0)
	var detail: String = LOG_LOOKS[kind].detail if LOG_LOOKS.has(kind) else "stubs"
	var skin := "bark_" + kind if bark and materials.has("bark_" + kind) else ("solid" if bark else "wood")
	b.cylinder(c - Vector3(hl, 0, 0), c + Vector3(hl, 0, 0), r, r * 0.95, sides, col, col * 1.06, skin, false, 0.2)
	var f: Array = MeshBuilder.frame(Vector3.RIGHT)
	for e in [-1.0, 1.0]:
		var end := c + Vector3(hl * e, 0, 0)
		var rr := r if e < 0 else r * 0.95
		for i in sides:
			var j := (i + 1) % sides
			var di: Vector3 = f[0] * cos(TAU * i / sides + 0.2) + f[1] * sin(TAU * i / sides + 0.2)
			var dj: Vector3 = f[0] * cos(TAU * j / sides + 0.2) + f[1] * sin(TAU * j / sides + 0.2)
			var lift := Vector3(0.002 * e, 0, 0)
			_face(b, [end, end + di * rr, end + dj * rr], Vector3(e, 0, 0), CUT_WOOD, "wood")
			_face(b, [end + lift, end + lift + di * rr * 0.5, end + lift + dj * rr * 0.5], Vector3(e, 0, 0), CUT_WOOD * 0.88, "wood")
	if detail == "joints":
		# A horsetail's joints: a raised ring every half metre or so, still
		# there (paler) once the bark is off.
		var n := maxi(int(length / 0.55), 1)
		for k in n:
			var x := -hl + (k + 0.5) * length / n
			var ring := col * (0.6 if bark else 0.85)
			b.cylinder(c + Vector3(x - 0.025, 0, 0), c + Vector3(x + 0.025, 0, 0), r * 1.07, r * 1.07, sides, ring, Color(-1, 0, 0), "solid", false, 0.2)
	if not bark:
		return
	match detail:
		"stubs":
			# Lopped branch stubs.
			for k in int(length / 0.7):
				var x := -hl + 0.35 + k * 0.7 + rng.randf_range(-0.1, 0.1)
				var a := rng.randf() * TAU
				var d := Vector3(0, cos(a), sin(a))
				if d.y < -0.3:
					d.y = -d.y
				b.cylinder(c + Vector3(x, 0, 0) + d * r * 0.8, c + Vector3(x + 0.03, 0, 0) + d * (r + 0.05), r * 0.22, r * 0.18, 5, col * 0.9, CUT_WOOD, "solid")
		"joints":
			# A few snapped-off branchlets round each joint.
			for k in maxi(int(length / 0.55), 1):
				var x := -hl + (k + 0.5) * length / maxi(int(length / 0.55), 1)
				for i in 3:
					var a := TAU * i / 3.0 + k * 0.9
					var d := Vector3(0, cos(a), sin(a))
					if d.y < -0.2:
						continue
					b.cylinder(c + Vector3(x, 0, 0) + d * r, c + Vector3(x + 0.02, 0, 0) + d * (r + 0.06), r * 0.1, r * 0.06, 4, col * 0.8, Color(-1, 0, 0), "solid")
		"frond_bases":
			# The stubs of old fronds, scattered thick over the shaggy trunk.
			for k in int(length / 0.12):
				var x := -hl + 0.06 + k * 0.12 + rng.randf_range(-0.03, 0.03)
				var a := rng.randf() * TAU
				var d := Vector3(0, cos(a), sin(a))
				if d.y < -0.4:
					d.y = -d.y
				var out := c + Vector3(x, 0, 0) + d * r * 0.9
				b.cone(out, out + d * 0.06 + Vector3(0.04, 0, 0), r * 0.16, 4, col * rng.randf_range(0.75, 0.95), "solid")


func rotten_log(id: String) -> Mesh:
	## A log gone soft and black in the water, furred with moss.
	var key := "rotten_" + id
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var length := SHORT_LOG_LEN if id == "short_log" else LOG_LEN
	log_piece(b, rng, length, LOG_R * 0.95, Color(0.20, 0.16, 0.11), false)
	for i in maxi(int(length * 2.0), 1):
		b.blob(Vector3(rng.randf_range(-length * 0.4, length * 0.4), LOG_R * 1.85, rng.randf_range(-0.05, 0.05)),
				Vector3(0.14, 0.05, 0.11), 2, 5, Color(0.25, 0.40, 0.15), rng, 0.2, "foliage")
	var m: Mesh = b.commit(materials)
	_cache[key] = m
	return m


func lashing(b, from: Vector3, to: Vector3, r: float, turns: int) -> void:
	## Cord wound around a shaft between two points.
	for k in turns:
		var t := (k + 0.5) / turns
		var c := from.lerp(to, t)
		var axis := (to - from).normalized() * 0.006
		b.cylinder(c - axis, c + axis, r, r, 6, CORD * (0.9 + 0.1 * (k % 2)), Color(-1, 0, 0), "fiber", false)


func pot(b, col: Color, scale: float, height := 1.0, at := Vector3.ZERO) -> void:
	## A coil-built pot, revolved from its profile. `height` < 1 leaves it
	## unfinished (the top coils not yet pressed on).
	var outer := [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.1, 0.03), Vector2(0.115, 0.08),
			Vector2(0.1, 0.14), Vector2(0.075, 0.17), Vector2(0.082, 0.19)]
	var inner := [Vector2(0.07, 0.19), Vector2(0.064, 0.17), Vector2(0.09, 0.14), Vector2(0.103, 0.08),
			Vector2(0.088, 0.035), Vector2(0.05, 0.015), Vector2(0.0, 0.015)]
	var top := 0.19 * height
	var prof := []
	for p in outer:
		if p.y <= top + 0.001:
			prof.append(p * scale)
	for p in inner:
		if p.y <= top + 0.001:
			prof.append(p * scale)
	b.lathe(prof, 10 if scale < 1.5 else 16, col, "clay", at)


func lizard(b, rng: RandomNumberGenerator, col: Color, at := Vector3.ZERO, s := 1.0) -> void:
	## A small lizard lying on its side: body, head, tail and stubby legs
	## (skinned and roasted ones share the shape in their own colour). `s`
	## scales it: the small prey animals share this shape at their own size
	## (an item's `body_scale`).
	b.blob(at + Vector3(0, 0.035, 0) * s, Vector3(0.1, 0.032, 0.04) * s, 2, 7, col, rng, 0.08, "organic")
	b.blob(at + Vector3(0.13, 0.032, 0) * s, Vector3(0.045, 0.026, 0.03) * s, 2, 6, col.darkened(0.1), rng, 0.05, "organic")
	b.tube([at + Vector3(-0.09, 0.03, 0) * s, at + Vector3(-0.2, 0.022, 0.03) * s, at + Vector3(-0.3, 0.014, 0.0) * s],
			[0.022 * s, 0.012 * s, 0.004 * s], 4, [col], "organic")
	for i in 4:
		var x := 0.06 if i < 2 else -0.06
		var z := 0.04 if i % 2 == 0 else -0.04
		b.cylinder(at + Vector3(x, 0.025, z) * s, at + Vector3(x + 0.02, 0.008, z * 1.9) * s, 0.008 * s, 0.006 * s, 3,
				col.darkened(0.2), Color(-1, 0, 0), "organic")


## Small prey lying on their side, as items (lizard_carcass and friends: an
## item's `animal`), head toward +x. Proportions relative to the Hylonomus
## shape (`lizard`): `body` radii, the head's centre x and radii, where the
## tail ends and how thick it starts, and the legs' length and thickness.
const PREY_SHAPES := {
	"petrolacosaurus": {"body": Vector3(0.09, 0.026, 0.032), "head_x": 0.12, "head": Vector3(0.042, 0.02, 0.024),
		"tail": -0.44, "tail_r": 0.018, "leg": 2.4, "leg_r": 0.006},
	"archaeothyris": {"body": Vector3(0.11, 0.04, 0.05), "head_x": 0.15, "head": Vector3(0.055, 0.04, 0.038),
		"tail": -0.27, "tail_r": 0.026, "leg": 1.6, "leg_r": 0.011},
	"amphibamus": {"body": Vector3(0.07, 0.022, 0.042), "head_x": 0.095, "head": Vector3(0.042, 0.018, 0.046),
		"tail": -0.14, "tail_r": 0.016, "leg": 1.5, "leg_r": 0.007},
	"tuditanus": {"body": Vector3(0.075, 0.03, 0.038), "head_x": 0.1, "head": Vector3(0.032, 0.026, 0.03),
		"tail": -0.24, "tail_r": 0.02, "leg": 1.4, "leg_r": 0.007},
	"morganucodon": {"body": Vector3(0.075, 0.042, 0.046), "head_x": 0.1, "head": Vector3(0.036, 0.032, 0.032),
		"tail": -0.22, "tail_r": 0.006, "leg": 1.2, "leg_r": 0.007},
}


func prey_body(animal: String) -> Vector3:
	## The body radii of a small prey item's shape (unscaled; its centre is at
	## height y = radii.y + 0.004, a Hylonomus's at 0.035), so work on it can
	## sit on its back.
	return PREY_SHAPES[animal].body if PREY_SHAPES.has(animal) else Vector3(0.1, 0.032, 0.04)


func prey_top(animal: String) -> float:
	## How high the top of a small prey item's body is (unscaled).
	var r := prey_body(animal)
	return (r.y * 2.0 + 0.004) if PREY_SHAPES.has(animal) else 0.067


func small_prey(b, rng: RandomNumberGenerator, col: Color, animal: String, whole: bool, at := Vector3.ZERO, s := 1.0) -> void:
	## A small prey animal lying on its side, shaped like its species
	## (PREY_SHAPES; anything else is drawn as a Hylonomus, `lizard`).
	## `whole` (a carcass) shows its skin: stripes, spots, bands, ears and fur.
	## Skinned and roasted ones keep the shape in their own colour.
	if not PREY_SHAPES.has(animal):
		lizard(b, rng, col, at, s)
		return
	var p: Dictionary = PREY_SHAPES[animal]
	var body: Vector3 = p.body
	var head: Vector3 = p.head
	var hx: float = p.head_x
	var y := body.y + 0.004
	var fur := 0.18 if whole and animal == "morganucodon" else 0.08
	b.blob(at + Vector3(0, y, 0) * s, body * s, 2, 7, col, rng, fur, "organic")
	b.blob(at + Vector3(hx, y - 0.002, 0) * s, head * s, 2, 6, col.darkened(0.1), rng, 0.05, "organic")
	var tail_from := -body.x * 0.9
	b.tube([at + Vector3(tail_from, y - 0.004, 0) * s, at + Vector3(lerpf(tail_from, p.tail, 0.5), y * 0.65, 0.03) * s,
			at + Vector3(p.tail, 0.012, 0.0) * s], [p.tail_r * s, p.tail_r * 0.55 * s, 0.003 * s], 4, [col], "organic")
	var lx := body.x * 0.6
	var lz := body.z
	for i in 4:
		var x := lx if i < 2 else -lx
		var z := lz if i % 2 == 0 else -lz
		var reach: float = p.leg
		b.cylinder(at + Vector3(x, y * 0.7, z) * s, at + Vector3(x + 0.01 * reach, 0.006, z * (1.0 + 0.45 * reach)) * s,
				p.leg_r * s, p.leg_r * 0.75 * s, 3, col.darkened(0.2), Color(-1, 0, 0), "organic")
	var dark := Color(0.06, 0.05, 0.04)
	match animal:
		"petrolacosaurus":
			if whole:
				for i in 5:
					b.blob(at + Vector3(-0.07 + i * 0.035, y + body.y * 0.75, 0) * s, Vector3(0.014, 0.006, 0.012) * s, 1, 4, col * 0.6)
		"archaeothyris":
			# A deep lower jaw, and a pale belly on a whole one.
			b.blob(at + Vector3(hx + 0.012, y - head.y * 0.7, 0) * s, Vector3(0.045, 0.02, 0.03) * s, 2, 5, col.darkened(0.15), rng, 0.03, "organic")
			if whole:
				b.blob(at + Vector3(0, y - body.y * 0.55, 0) * s, Vector3(body.x * 0.8, body.y * 0.5, body.z * 0.85) * s, 2, 6, Color(0.56, 0.48, 0.36), null, 0.0, "organic")
		"amphibamus":
			# Big eyes on the flat head, and dark spots on a whole one.
			for z in [head.z * 0.6, -head.z * 0.6]:
				b.blob(at + Vector3(hx + head.x * 0.3, y + head.y * 0.8, z) * s, Vector3.ONE * 0.011 * s, 1, 4, dark)
			if whole:
				for q in [Vector3(-0.03, 0.8, 0.02), Vector3(0.01, 0.9, -0.015), Vector3(0.04, 0.75, 0.01), Vector3(-0.05, 0.7, -0.02)]:
					b.blob(at + Vector3(q.x, y + body.y * q.y, q.z) * s, Vector3(0.01, 0.006, 0.01) * s, 1, 4, Color(0.16, 0.18, 0.1))
		"tuditanus":
			if whole:
				for i in 3:
					b.blob(at + Vector3(-0.045 + i * 0.045, y + body.y * 0.6, 0) * s, Vector3(0.009, body.y * 0.5, body.z * 0.95) * s, 1, 5, Color(0.66, 0.58, 0.5))
		"morganucodon":
			# A pointed snout with a dark nose; round ears on a whole one.
			b.cone(at + Vector3(hx + head.x * 0.6, y - 0.004, 0) * s, at + Vector3(hx + head.x * 1.8, y - 0.01, 0) * s, 0.016 * s, 5, col.darkened(0.05), "organic")
			b.blob(at + Vector3(hx + head.x * 1.8, y - 0.01, 0) * s, Vector3.ONE * 0.006 * s, 1, 4, dark)
			if whole:
				for z in [0.018, -0.018]:
					b.blob(at + Vector3(hx - head.x * 0.3, y + head.y * 0.95, z) * s, Vector3(0.006, 0.012, 0.011) * s, 1, 5, Color(0.55, 0.42, 0.38))


func platter(b, col: Color, height := 1.0, at := Vector3.ZERO) -> void:
	## A flat round platter with a low lip. `height` < 1 is still being pressed out.
	var lip := 0.03 * height
	b.lathe([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.175, lip * 0.6), Vector2(0.18, lip),
			Vector2(0.166, lip), Vector2(0.15, 0.012), Vector2(0.0, 0.012)], 12, col, "clay", at)


func bowl(b, col: Color, at := Vector3.ZERO, scale := 1.0, height := 1.0) -> void:
	## A wide, shallow bowl. `height` < 1 is not yet pinched up all the way.
	var top := 0.08 * height
	var outer := [Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.105, 0.03), Vector2(0.13, 0.08)]
	var inner := [Vector2(0.118, 0.08), Vector2(0.094, 0.034), Vector2(0.05, 0.012), Vector2(0.0, 0.012)]
	var prof := []
	for p in outer + inner:
		prof.append(Vector2(p.x, minf(p.y, top)) * scale)
	b.lathe(prof, 12, col, "clay", at)


func chisel_saw(b, rng: RandomNumberGenerator, done := 99) -> void:
	## A chert saw with a toothed edge and a narrow chisel, each lashed into a
	## wooden handle, lying side by side. `done` < 6 shows them part made:
	## the saw's teeth flaked a few at a time, then the chisel, then the lashings.
	stick(b, rng, Vector3(-0.32, 0.022, -0.06), Vector3(-0.1, 0.022, -0.06), 0.02)
	b.box(Vector3(0.05, 0.012, -0.06), Vector3(0.32, 0.014, 0.05), CHERT, Basis(), "stone")
	var teeth := 10 if done >= 2 else done * 5
	for i in teeth:
		var x := -0.1 + i * 0.03
		for y: float in [0.019, 0.005]:
			var up := y > 0.01
			var a := Vector3(x, y, -0.085)
			var c := Vector3(x + 0.03, y, -0.085)
			var tip := Vector3(x + 0.015, y, -0.1)
			if up:
				b.tri(a, tip, c, CHERT * 0.9, "stone")
			else:
				b.tri(a, c, tip, CHERT * 0.8, "stone")
	stick(b, rng, Vector3(-0.28, 0.022, 0.07), Vector3(-0.06, 0.022, 0.07), 0.022)
	if done >= 3:
		b.box(Vector3(0.03, 0.014, 0.07), Vector3(0.18, 0.016, 0.034), CHERT, Basis(), "stone")
	if done >= 4:
		b.box(Vector3(0.125, 0.012, 0.07), Vector3(0.012, 0.008, 0.034), CHERT.lightened(0.25), Basis(), "stone")
	if done >= 5:
		lashing(b, Vector3(-0.14, 0.022, -0.06), Vector3(-0.08, 0.022, -0.06), 0.026, 4)
	if done >= 6:
		lashing(b, Vector3(-0.1, 0.022, 0.07), Vector3(-0.04, 0.022, 0.07), 0.028, 4)


func paper_screen(b, rng: RandomNumberGenerator, at: Vector3, done := 1.0) -> void:
	## A square frame of sticks with fine fiber woven across it. `done` 0..1
	## builds it up: the frame first, then the weave.
	var h := 0.15
	var corners := [Vector3(-h, 0.02, -h), Vector3(h, 0.02, -h), Vector3(h, 0.02, h), Vector3(-h, 0.02, h)]
	var sides := clampi(ceili(done * 8.0), 0, 4)
	for i in sides:
		stick(b, rng, at + corners[i] * 1.12, at + corners[(i + 1) % 4] * 1.12, 0.014)
	var rows := clampi(roundi((done - 0.5) * 2.0 * 9.0), 0, 9)
	var fiber := Color(0.55, 0.65, 0.30)
	for k in rows:
		var o := -h + (k + 0.5) * h * 2.0 / 9.0
		b.box(at + Vector3(0, 0.02, o), Vector3(h * 2.0, 0.003, 0.006), fiber * (0.9 + 0.1 * (k % 2)), Basis(), "fiber")
		b.box(at + Vector3(o, 0.021, 0), Vector3(0.006, 0.003, h * 2.0), fiber * 0.95, Basis(), "fiber")


func paper(b, rng: RandomNumberGenerator, col: Color, at := Vector3.ZERO, done := 1.0, scale := 1.0) -> void:
	## A big rough sheet of fiber paper lying flat, flecked with fiber, one
	## corner curling up. `done` < 1 is still being lifted on the screen.
	var size := Vector3(0.56 * scale, 0.003, 0.4 * scale * clampf(done, 0.2, 1.0))
	b.box(at + Vector3(0, 0.002, 0), size, col, Basis(), "fiber")
	b.box(at + Vector3(size.x * 0.5 - 0.035, 0.008, -size.z * 0.5 + 0.035), Vector3(0.06, 0.003, 0.06), col * 0.94,
			Basis(Vector3(1, 0, 1).normalized(), 0.35), "fiber")
	for k in 7:
		var p := Vector3(rng.randf_range(-0.45, 0.45) * size.x, 0.0036, rng.randf_range(-0.45, 0.45) * size.z)
		b.box(at + p, Vector3(0.04, 0.001, 0.003), col * 0.88, Basis(Vector3.UP, rng.randf() * PI), "fiber")


## A blueprint's drawing (see work_spot.gd), a group of lines at a time:
## the front of the house on the left of the sheet, its plan on the right.
## Each line is a pair of points on the sheet, x across it and y up it.
const BLUEPRINT := [
	# The ground and the four stilts.
	[[Vector2(-0.2, -0.11), Vector2(-0.02, -0.11)], [Vector2(-0.165, -0.11), Vector2(-0.165, -0.05)], [Vector2(-0.055, -0.11), Vector2(-0.055, -0.05)],
		[Vector2(-0.15, -0.11), Vector2(-0.15, -0.05)], [Vector2(-0.07, -0.11), Vector2(-0.07, -0.05)]],
	# The floor and the walls.
	[[Vector2(-0.175, -0.05), Vector2(-0.045, -0.05)], [Vector2(-0.17, -0.05), Vector2(-0.17, 0.027)], [Vector2(-0.05, -0.05), Vector2(-0.05, 0.027)],
		[Vector2(-0.17, 0.027), Vector2(-0.05, 0.027)]],
	# The doorway and the rope ladder down from the porch.
	[[Vector2(-0.126, -0.05), Vector2(-0.126, 0.017)], [Vector2(-0.094, -0.05), Vector2(-0.094, 0.017)], [Vector2(-0.126, 0.017), Vector2(-0.094, 0.017)],
		[Vector2(-0.12, -0.05), Vector2(-0.12, -0.11)], [Vector2(-0.1, -0.05), Vector2(-0.1, -0.11)], [Vector2(-0.12, -0.065), Vector2(-0.1, -0.065)],
		[Vector2(-0.12, -0.08), Vector2(-0.1, -0.08)], [Vector2(-0.12, -0.095), Vector2(-0.1, -0.095)]],
	# The roof, out past the walls.
	[[Vector2(-0.182, 0.02), Vector2(-0.11, 0.067)], [Vector2(-0.11, 0.067), Vector2(-0.038, 0.02)], [Vector2(-0.182, 0.02), Vector2(-0.038, 0.02)],
		[Vector2(-0.075, 0.044), Vector2(-0.075, 0.075)]],
	# The room, from above.
	[[Vector2(0.03, 0.1), Vector2(0.17, 0.1)], [Vector2(0.17, 0.1), Vector2(0.17, -0.04)], [Vector2(0.17, -0.04), Vector2(0.03, -0.04)],
		[Vector2(0.03, -0.04), Vector2(0.03, 0.1)]],
	# The porch and the top of the ladder.
	[[Vector2(0.03, -0.04), Vector2(0.03, -0.098)], [Vector2(0.17, -0.04), Vector2(0.17, -0.098)], [Vector2(0.03, -0.098), Vector2(0.17, -0.098)],
		[Vector2(0.087, -0.098), Vector2(0.087, -0.112)], [Vector2(0.113, -0.098), Vector2(0.113, -0.112)]],
	# The windows, the doorway and the fireplace in its corner.
	[[Vector2(0.024, 0.033), Vector2(0.036, 0.033)], [Vector2(0.024, 0.066), Vector2(0.036, 0.066)], [Vector2(0.164, 0.033), Vector2(0.176, 0.033)],
		[Vector2(0.164, 0.066), Vector2(0.176, 0.066)], [Vector2(0.082, -0.034), Vector2(0.118, -0.034)], [Vector2(0.125, 0.09), Vector2(0.155, 0.09)],
		[Vector2(0.125, 0.09), Vector2(0.125, 0.065)], [Vector2(0.155, 0.09), Vector2(0.155, 0.065)], [Vector2(0.125, 0.065), Vector2(0.155, 0.065)]],
	# The ridge of the roof, and the measurements.
	[[Vector2(0.1, 0.12), Vector2(0.1, -0.12)], [Vector2(0.03, 0.125), Vector2(0.17, 0.125)], [Vector2(0.03, 0.12), Vector2(0.03, 0.13)],
		[Vector2(0.17, 0.12), Vector2(0.17, 0.13)], [Vector2(0.185, 0.1), Vector2(0.185, -0.098)]],
]


func blueprint_lines(g: int) -> Array:
	return BLUEPRINT[clampi(g, 0, BLUEPRINT.size() - 1)]


func on_sheet(at: Vector3, p: Vector2) -> Vector3:
	## A point drawn on a sheet of paper lying at `at`.
	return at + Vector3(p.x, 0.0045, -p.y)


func line_on(b, at: Vector3, from: Vector2, to: Vector2) -> void:
	## A grey pencil line drawn on a sheet of paper lying at `at`.
	var d := to - from
	var c := on_sheet(at, (from + to) * 0.5)
	b.box(c, Vector3(d.length() + 0.003, 0.001, 0.003), Color(0.3, 0.3, 0.32), Basis(Vector3.UP, atan2(d.y, d.x)), "fiber")


func pencil(b, rng: RandomNumberGenerator, done := 99) -> void:
	## An ash pencil along X: a dark fired core bound between the halves of a
	## split stick. `done` < 4 shows it being made: the stick whole beside the
	## core, then split open, the core laid in, closed, and bound with cord.
	var r := 0.011
	var h := 0.12
	var core: Color = Items.def("pencil_core").color
	if done < 1:
		stick(b, rng, Vector3(-h, r, 0), Vector3(h, r, 0), r)
		b.cylinder(Vector3(-0.09, 0.006, 0.07), Vector3(0.09, 0.006, 0.07), 0.006, 0.006, 6, core, Color(-1, 0, 0), "clay")
		return
	if done < 3:
		# Split in two, flat faces up, a groove down the middle of each.
		for side in [-1.0, 1.0]:
			var z: float = side * 0.03
			var sec := []
			for k in 5:
				var a := PI * k / 4.0
				sec.append(Vector2(z + cos(a) * r, r - sin(a) * r))
			prism(b, sec, h, [WOOD, WOOD * 0.92, WOOD * 0.95, WOOD * 0.9], CUT_WOOD, "wood")
			b.box(Vector3(0, r + 0.0005, z), Vector3(h * 2.0, 0.001, r * 2.0), CUT_WOOD, Basis(), "wood")
			b.box(Vector3(0, r + 0.001, z), Vector3(h * 2.0, 0.001, 0.004), CUT_WOOD * 0.8, Basis(), "wood")
		if done >= 2:
			b.cylinder(Vector3(-0.09, r + 0.002, -0.03), Vector3(0.09, r + 0.002, -0.03), 0.004, 0.004, 6, core, Color(-1, 0, 0), "clay")
		else:
			b.cylinder(Vector3(-0.09, 0.006, 0.08), Vector3(0.09, 0.006, 0.08), 0.006, 0.006, 6, core, Color(-1, 0, 0), "clay")
		return
	# Closed: a round rod, sharpened to the core at one end.
	b.cylinder(Vector3(-h, r, 0), Vector3(h, r, 0), r, r, 7, WOOD, CUT_WOOD, "wood")
	b.cylinder(Vector3(h, r, 0), Vector3(h + 0.03, r, 0), r, 0.004, 7, CUT_WOOD, Color(-1, 0, 0), "wood")
	b.cylinder(Vector3(h + 0.03, r, 0), Vector3(h + 0.04, r, 0), 0.004, 0.0008, 6, core, Color(-1, 0, 0), "clay")
	b.cylinder(Vector3(-h - 0.001, r, 0), Vector3(-h, r, 0), 0.004, 0.004, 6, core, core, "clay")
	var binds := 2 if done >= 4 else 0
	for k in binds:
		var x := -0.07 + k * 0.1
		b.cylinder(Vector3(x - 0.008, r, 0), Vector3(x + 0.008, r, 0), r + 0.0015, r + 0.0015, 7, CORD, Color(-1, 0, 0), "fiber")


const VESSEL_H := 0.62  # height of a fermentation vessel's body


func vessel(b, col: Color, sealed: bool, height := 1.0, at := Vector3.ZERO) -> void:
	## A big coil-built fermentation vessel: an open, wide-mouthed crock, or a
	## jar with a narrow neck and a fitted lid. `height` < 1 is still being
	## coiled.
	var outer := [Vector2(0.0, 0.0), Vector2(0.16, 0.0), Vector2(0.25, 0.08), Vector2(0.29, 0.26), Vector2(0.27, 0.44)]
	var inner := []
	if sealed:
		outer.append_array([Vector2(0.16, 0.56), Vector2(0.13, 0.6), Vector2(0.145, 0.62)])
		inner = [Vector2(0.115, 0.62), Vector2(0.11, 0.58), Vector2(0.24, 0.44), Vector2(0.26, 0.26), Vector2(0.22, 0.09), Vector2(0.0, 0.04)]
	else:
		outer.append_array([Vector2(0.23, 0.56), Vector2(0.25, 0.62)])
		inner = [Vector2(0.215, 0.62), Vector2(0.2, 0.56), Vector2(0.24, 0.44), Vector2(0.26, 0.26), Vector2(0.22, 0.09), Vector2(0.0, 0.04)]
	var top := VESSEL_H * height
	var prof := []
	for p in outer + inner:
		if p.y <= top + 0.001:
			prof.append(p)
	b.lathe(prof, 16, col, "clay", at)
	if sealed and height >= 1.0:
		# The lid sits in the neck, a knob on top.
		b.lathe([Vector2(0.0, 0.66), Vector2(0.15, 0.66), Vector2(0.155, 0.63), Vector2(0.11, 0.6), Vector2(0.0, 0.6)], 12, col * 0.92, "clay", at)
		b.blob(at + Vector3(0, 0.68, 0), Vector3(0.035, 0.025, 0.035), 2, 6, col * 0.85, null, 0.0, "clay")


const CANTEEN_WOOD := Color(0.62, 0.47, 0.30)
const CANTEEN_STEM := Color(0.60, 0.58, 0.34)  # a dry, jointed horsetail stem


func canteen(b, stopper: Color, at := Vector3.ZERO, done := 1.0) -> void:
	## A length of hollow, jointed stem standing on end: closed at the bottom
	## by a joint, open at the top, with a carved wooden lid pushed in, a
	## thin seal the colour of what is in it showing under the lid's rim,
	## and a carrying cord. `done` < 1 is still being made: the length cut,
	## then hollowed, sealed, lidded and corded.
	var r := 0.055
	var h := 0.24
	var stem := CANTEEN_STEM
	b.cylinder(at, at + Vector3(0, h, 0), r, r * 0.96, 10, stem * 0.9, stem, "wood")
	# The joints: a swollen ring at the closed bottom and one part way up.
	for y in [0.012, h * 0.62]:
		b.cylinder(at + Vector3(0, y - 0.009, 0), at + Vector3(0, y + 0.009, 0), r + 0.006, r + 0.006, 10, stem * 0.72, Color(-1, 0, 0), "wood")
	if done < 0.3:
		return
	# Hollowed: the dark inside shows at the open top, inside a cut rim.
	b.cylinder(at + Vector3(0, h - 0.004, 0), at + Vector3(0, h + 0.002, 0), r * 0.8, r * 0.8, 10, Color(0.12, 0.09, 0.05), Color(-1, 0, 0), "wood")
	if done < 0.6:
		return
	if done >= 0.8:
		# The seal round the mouth, then the lid: a plug with a wider cap and a knob.
		b.cylinder(at + Vector3(0, h - 0.002, 0), at + Vector3(0, h + 0.006, 0), r + 0.003, r + 0.003, 10, stopper, Color(-1, 0, 0), "solid")
		b.cylinder(at + Vector3(0, h + 0.006, 0), at + Vector3(0, h + 0.024, 0), r + 0.008, r + 0.006, 10, CANTEEN_WOOD, CANTEEN_WOOD * 0.9, "wood")
		b.cylinder(at + Vector3(0, h + 0.024, 0), at + Vector3(0, h + 0.042, 0), 0.016, 0.013, 7, CANTEEN_WOOD * 0.92, Color(-1, 0, 0), "wood")
	if done >= 1.0:
		# A cord tied round under the upper joint, looped up over the lid.
		b.cylinder(at + Vector3(0, h * 0.8 - 0.004, 0), at + Vector3(0, h * 0.8 + 0.004, 0), r + 0.004, r + 0.004, 10, CORD, Color(-1, 0, 0), "fiber")
		var pts := []
		var radii := []
		for k in 9:
			var a := PI * k / 8.0
			pts.append(at + Vector3(-cos(a) * (r + 0.006), h * 0.8 + sin(a) * 0.15, 0))
			radii.append(0.005)
		b.tube(pts, radii, 4, [CORD], "fiber")


func hearth_pot(id: String) -> Mesh:
	## A soup pot as it hangs in a house's fireplace: from a stick wedged
	## across the mouth of the hood, no tripod (its legs would run up through
	## the hood).
	var key := "hearth_item_" + id
	if not _cache.has(key):
		var b := MeshBuilder.new()
		soup_pot(b, Items.def(id).get("color", Color(0.6, 0.6, 0.6)), true)
		_cache[key] = b.commit(materials)
	return _cache[key]


func soup_pot(b, col: Color, hearth := false) -> void:
	## A big pot hanging by two cords from the top of a tripod of boards, its
	## bottom clear of a campfire's flames. The tripod's feet stand outside the
	## fire's ring of stones. In a fireplace (hearth) the cords go up to a
	## stick across the hood's mouth instead (house.gd's flue starts 1.05 m
	## up, 0.39 m either side). See soup_pot.gd for the sizes.
	var scale := 2.8
	var hang := 0.6
	var top := 1.75
	var rim := hang + 0.19 * scale
	if hearth:
		var bar_y := 1.12
		b.cylinder(Vector3(-0.4, bar_y, 0), Vector3(0.4, bar_y, 0), 0.022, 0.022, 5, WOOD, Color(-1, 0, 0), "wood")
		for s in [-1.0, 1.0]:
			var lug := Vector3(0.082 * scale + 0.03, rim - 0.07, 0) * Vector3(s, 1, 1)
			b.blob(lug, Vector3(0.04, 0.03, 0.035), 2, 5, col, null, 0.0, "clay")
			b.cylinder(lug, Vector3(0.2 * s, bar_y - 0.02, 0), 0.008, 0.008, 3, CORD, Color(-1, 0, 0), "fiber")
		pot(b, col, scale, 1.0, Vector3(0, hang, 0))
		return
	var board: Color = Items.def("board").color * 0.85
	var apex := Vector3(0, top, 0)
	for i in 3:
		var a := TAU * i / 3.0 + PI / 6.0
		var foot := Vector3(cos(a), 0, sin(a)) * 1.0
		var along := (apex - foot).normalized()
		var side := along.cross(Vector3.UP).normalized()
		var face := side.cross(along).normalized()
		var basis := Basis(side, along, face)
		var mid := (foot + apex + along * 0.12) * 0.5
		b.box(mid, Vector3(0.12, foot.distance_to(apex) + 0.12, 0.035), board * (0.95 + 0.04 * i), basis, "wood")
	# The pin through the tripod's top, and the cords down to the pot's lugs.
	b.cylinder(apex + Vector3(-0.09, 0.02, 0), apex + Vector3(0.09, 0.02, 0), 0.025, 0.025, 5, WOOD, Color(-1, 0, 0), "wood")
	for s in [-1.0, 1.0]:
		var lug := Vector3(0.082 * scale + 0.03, rim - 0.07, 0) * Vector3(s, 1, 1)
		b.blob(lug, Vector3(0.04, 0.03, 0.035), 2, 5, col, null, 0.0, "clay")
		b.cylinder(lug, apex + Vector3(0.02 * s, -0.02, 0), 0.008, 0.008, 3, CORD, Color(-1, 0, 0), "fiber")
	pot(b, col, scale, 1.0, Vector3(0, hang, 0))


const BENCH_SIZE := Vector3(1.4, 0.8, 0.8)  # width, height of the top, depth
const BENCH_RACK := Vector3(0.0, 1.07, -0.34)  # where tools hang (y and z; x per slot)


func bench_legs() -> Array:
	## Where the workbench's legs stand, in its local space (front at +Z).
	var hx := BENCH_SIZE.x * 0.5 - 0.08
	return [Vector3(-hx, 0, 0.32), Vector3(hx, 0, 0.32), Vector3(-hx, 0, -0.34), Vector3(hx, 0, -0.34)]


func workbench(b, rng: RandomNumberGenerator, done := 99, drop := []) -> void:
	## A plain table of boards on stick legs, with a rack board along the back
	## held up by the back legs, and pegs to hang tools from. Front at +Z.
	## `done` < 8 is still being built: legs, lashings, top boards, rack.
	## `drop` makes each leg that much longer, down to lower ground.
	var board: Color = Items.def("board").color * 0.8
	var hx := BENCH_SIZE.x * 0.5 - 0.08
	var legs := bench_legs()
	for i in mini(done, 4):
		var tall := 1.42 if i >= 2 else 0.76
		var low: float = drop[i] if i < drop.size() else 0.0
		stick(b, rng, legs[i] - Vector3(0, low, 0), legs[i] + Vector3(0, tall, 0), 0.04)
	if done >= 5:
		for x in [-hx, hx]:
			stick(b, rng, Vector3(x, 0.22, 0.32), Vector3(x, 0.22, -0.34), 0.025)
			stick(b, rng, Vector3(x, 0.72, 0.36), Vector3(x, 0.72, -0.38), 0.03)
			lashing(b, Vector3(x, 0.69, 0.3), Vector3(x, 0.75, 0.3), 0.05, 3)
			lashing(b, Vector3(x, 0.69, -0.32), Vector3(x, 0.75, -0.32), 0.05, 3)
		stick(b, rng, Vector3(-hx, 0.22, -0.34), Vector3(hx, 0.22, -0.34), 0.025)
	for k in clampi(done - 5, 0, 3):
		var z := (k - 1) * 0.265
		b.box(Vector3(0, BENCH_SIZE.y - 0.022, z), Vector3(BENCH_SIZE.x, 0.045, 0.26), board * (0.94 + 0.05 * k), Basis(Vector3.UP, (k - 1) * 0.004), "wood")
		b.box(Vector3(0, BENCH_SIZE.y + 0.001, z + 0.05), Vector3(BENCH_SIZE.x - 0.04, 0.002, 0.01), board * 0.82, Basis(), "wood")
	if done >= 8:
		b.box(Vector3(0, 1.12, -0.39), Vector3(BENCH_SIZE.x - 0.04, 0.3, 0.04), board * 0.97, Basis(), "wood")
		stick(b, rng, Vector3(-hx - 0.06, 1.4, -0.36), Vector3(hx + 0.06, 1.4, -0.36), 0.03)
		for i in 4:
			var x := bench_slot_x(i)
			b.cylinder(Vector3(x, 1.22, -0.37), Vector3(x, 1.235, -0.3), 0.012, 0.011, 5, WOOD, Color(-1, 0, 0), "wood")


func bench_slot_x(i: int) -> float:
	## Across the rack, left to right as you face the bench.
	return (i - 1.5) * 0.3


func knapped(b, grid: Array, cell: float, thick: float, col: Color, rng: RandomNumberGenerator,
		xf := Transform3D.IDENTITY, slot := "stone", cortex: Array = []) -> void:
	## A knapped stone slab from a 5x5 grid of kept cells (row-major, row 0 at
	## -Z). Faceted on both faces and thinning to sharp edges where flakes came
	## off, so a tool head looks like its knapping pattern. Cells marked in
	## `cortex` keep the nodule's chalky rind on top.
	var hgt := {}
	for cy in 6:
		for cx in 6:
			var k := 0
			for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
				if _kept(grid, cx + o.x, cy + o.y):
					k += 1
			hgt[Vector2i(cx, cy)] = thick * 0.5 * k / 4.0
	for y in 5:
		for x in 5:
			if not grid[y * 5 + x]:
				continue
			var cs := [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1), Vector2i(x, y + 1)]
			var top := []
			var bot := []
			for c in cs:
				var p := Vector3((c.x - 2.5) * cell, 0, (c.y - 2.5) * cell)
				top.append(xf * (p + Vector3(0, hgt[c], 0)))
				bot.append(xf * (p - Vector3(0, hgt[c], 0)))
			var mid := Vector3((x - 2.0) * cell, 0, (y - 2.0) * cell)
			var ct: Vector3 = xf * (mid + Vector3(0, thick * rng.randf_range(0.42, 0.6), 0))
			var cb: Vector3 = xf * (mid - Vector3(0, thick * rng.randf_range(0.42, 0.6), 0))
			var rind: bool = not cortex.is_empty() and cortex[y * 5 + x]
			for i in 4:
				var j := (i + 1) % 4
				var shade := rng.randf_range(0.82, 1.12)
				b.tri(ct, top[i], top[j], (CORTEX if rind else col) * shade, slot)
				b.tri(cb, bot[j], bot[i], col * shade * 0.9, slot)
			# Walls along edges where the neighbouring cell is gone.
			var nb := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
			for i in 4:
				if _kept(grid, x + nb[i].x, y + nb[i].y):
					continue
				var j := (i + 1) % 4
				b.quad(top[j], top[i], bot[i], bot[j], col * rng.randf_range(0.7, 0.95), slot)


func _kept(grid: Array, x: int, y: int) -> bool:
	return x >= 0 and x < 5 and y >= 0 and y < 5 and grid[y * 5 + x]


# --- Icons -----------------------------------------------------------------------

func render_icons() -> void:
	## Renders every item's mesh into one atlas, lit and slightly from above,
	## for the inventory and hotbar. Icons fall back to vector drawings (see
	## icons.gd) until this is done, and always in headless runs.
	var ids: Array = Items.ITEMS.keys()
	var rows := ceili(ids.size() / float(ICON_COLS))
	var vp := SubViewport.new()
	vp.size = Vector2i(ICON_COLS * ICON_CELL, rows * ICON_CELL)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.58)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-30), 0)
	key.light_energy = 1.3
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(150), 0)
	fill.light_energy = 0.4
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows
	cam.position = Vector3(ICON_COLS * 0.5, -rows * 0.5, 20.0)
	vp.add_child(cam)
	cam.current = true
	# Tilted toward the camera and turned so long items lie corner to corner.
	var view := Basis.from_euler(Vector3(deg_to_rad(40), deg_to_rad(-45), 0))
	for i in ids.size():
		var m := mesh("item_" + ids[i])
		var box: AABB = Transform3D(view, Vector3.ZERO) * m.get_aabb()
		var k := 0.8 / maxf(maxf(box.size.x, box.size.y), 0.01)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		var cell := Vector3(i % ICON_COLS + 0.5, -(i / ICON_COLS + 0.5), 0)
		mi.transform = Transform3D(view.scaled(Vector3.ONE * k), cell - box.get_center() * k)
		vp.add_child(mi)
		icon_rects[ids[i]] = Rect2(i % ICON_COLS * ICON_CELL, i / ICON_COLS * ICON_CELL, ICON_CELL, ICON_CELL)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		icon_rects.clear()
		return
	if Game.dev.has("icons"):
		img.save_png(Game.dev["icons"])
	img.generate_mipmaps()
	icon_atlas = ImageTexture.create_from_image(img)
	icons_ready.emit()
