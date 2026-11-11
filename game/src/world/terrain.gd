extends RefCounted
## Deterministic height and ground colour for the swamp. Water sits at y = 0,
## and heights are squashed toward it so most of the land is low, wet marsh.

const WATER := 0.0
const WORLD_RADIUS := 520.0
# Rocky islands out in the deep water past the edge of the marsh (metals.md):
# bare bedrock humps where native copper washes up and copper ore weathers
# out. Placed from the world seed, so they are where they were on every load.
const ISLANDS := 5
const ISLAND_RING := [530.0, 600.0]  # how far out their centres lie
const ISLAND_R := [26.0, 44.0]       # their radius, out to the foot of the shelf
const ISLAND_TOP := [3.0, 7.0]       # how high they stand
const ISLAND_FOOT := -3.0            # the shelf meets the sea floor this deep
const ISLAND_SAFE := 25.0            # no water predator comes this near an island's shelf

var islands: Array = []  # [{x, z, r, top, outcrops: [Vector2], anvils: [Vector2]}]

var _cont := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _moist := FastNoiseLite.new()


func _init(seed_value: int) -> void:
	_cont.seed = seed_value
	_cont.frequency = 0.0045
	_cont.fractal_octaves = 3
	_detail.seed = seed_value + 1
	_detail.frequency = 0.05
	_detail.fractal_octaves = 1
	_ridge.seed = seed_value + 2
	_ridge.frequency = 0.009
	_ridge.fractal_octaves = 2
	_moist.seed = seed_value + 3
	_moist.frequency = 0.012
	_moist.fractal_octaves = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 77
	var turn := rng.randf() * TAU
	for i in ISLANDS:
		var a := turn + TAU * (i + rng.randf_range(-0.25, 0.25)) / ISLANDS
		var d := rng.randf_range(ISLAND_RING[0], ISLAND_RING[1])
		var isl := {"x": cos(a) * d, "z": sin(a) * d, "r": rng.randf_range(ISLAND_R[0], ISLAND_R[1]),
				"top": rng.randf_range(ISLAND_TOP[0], ISLAND_TOP[1]), "outcrops": [], "anvils": []}
		# Ore outcrops and anvil stones stand up on the rock, well inside the shore.
		for k in 3:
			var oa := rng.randf() * TAU
			isl.outcrops.append(Vector2(isl.x, isl.z) + Vector2(cos(oa), sin(oa)) * isl.r * rng.randf_range(0.12, 0.3))
		for k in 2:
			var oa := rng.randf() * TAU
			isl.anvils.append(Vector2(isl.x, isl.z) + Vector2(cos(oa), sin(oa)) * isl.r * rng.randf_range(0.05, 0.25))
		islands.append(isl)


func island_at(x: float, z: float, margin := 0.0) -> Dictionary:
	## The island whose shelf (plus `margin`) x, z is within, or {}.
	if absf(x) + absf(z) < ISLAND_RING[0] - ISLAND_R[1] - margin:
		return {}
	for isl in islands:
		if Vector2(x - isl.x, z - isl.z).length() < isl.r + margin:
			return isl
	return {}


func _island_k(isl: Dictionary, x: float, z: float) -> float:
	## 0 at the foot of an island's shelf, 1 up on its top.
	return smoothstep(isl.r, isl.r * 0.3, Vector2(x - isl.x, z - isl.z).length())


func height(x: float, z: float) -> float:
	var h := _cont.get_noise_2d(x, z) * 9.0 + 0.8
	# Squash heights near the waterline into broad, shallow marsh.
	h *= 0.3 + 0.7 * smoothstep(0.8, 5.0, absf(h))
	h += _detail.get_noise_2d(x, z) * 0.35
	var r := _knoll(x, z)
	if r > 0.0:
		h += r * r * 14.0
	var d := Vector2(x, z).length()
	if d > WORLD_RADIUS - 80.0:
		h -= (d - (WORLD_RADIUS - 80.0)) * 0.06
		var isl := island_at(x, z)
		if not isl.is_empty():
			h = maxf(h, lerpf(ISLAND_FOOT, isl.top, _island_k(isl, x, z)) + _detail.get_noise_2d(x, z) * 0.25)
	return h


func _knoll(x: float, z: float) -> float:
	return maxf(_ridge.get_noise_2d(x, z) - 0.32, 0.0) * 2.2


func rockiness(x: float, z: float) -> float:
	## 0 on ordinary ground, rising toward 1 on rocky knolls and on the bare
	## rock of an island.
	var r := _knoll(x, z)
	var isl := island_at(x, z)
	if not isl.is_empty():
		r = maxf(r, clampf(_island_k(isl, x, z) * 4.0, 0.0, 1.0))
	return r


func moisture(x: float, z: float) -> float:
	return _moist.get_noise_2d(x, z)


func ground_color(x: float, z: float, h: float, slope: float) -> Color:
	var m := moisture(x, z)
	var c: Color
	if h < -0.8:
		c = Color(0.16, 0.15, 0.09)
	elif h < 0.25:
		c = Color(0.27, 0.23, 0.14).lerp(Color(0.20, 0.19, 0.11), clampf(-h, 0.0, 1.0))
	else:
		var moss := Color(0.14, 0.21, 0.08)
		var litter := Color(0.27, 0.21, 0.12)
		c = moss.lerp(litter, clampf(m * 0.8 + 0.45, 0.0, 1.0) * 0.7)
		c = c.lerp(Color(0.17, 0.24, 0.09), clampf((h - 2.0) * 0.2, 0.0, 0.4))
	var r := rockiness(x, z)
	if r > 0.15 or slope > 0.9:
		c = c.lerp(Color(0.42, 0.41, 0.37), clampf(maxf(r * 1.6, slope - 0.6), 0.0, 1.0))
	return c


func find_spawn() -> Vector3:
	## Spiral out from the origin to find dry, gently sloped ground.
	for i in 400:
		var a := i * 0.7
		var rad := 4.0 + i * 1.2
		var x := cos(a) * rad
		var z := sin(a) * rad
		var h := height(x, z)
		if h > 0.7 and h < 3.5 and absf(height(x + 2, z) - h) < 0.8 and absf(height(x, z + 2) - h) < 0.8:
			return Vector3(x, h, z)
	return Vector3(0, maxf(height(0, 0), 0.5), 0)
