extends RefCounted
## Deterministic height and ground colour for the swamp. Water sits at y = 0,
## and heights are squashed toward it so most of the land is low, wet marsh.

const WATER := 0.0
const WORLD_RADIUS := 520.0

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


func height(x: float, z: float) -> float:
	var h := _cont.get_noise_2d(x, z) * 9.0 + 0.8
	# Squash heights near the waterline into broad, shallow marsh.
	h *= 0.3 + 0.7 * smoothstep(0.8, 5.0, absf(h))
	h += _detail.get_noise_2d(x, z) * 0.35
	var r := rockiness(x, z)
	if r > 0.0:
		h += r * r * 14.0
	var d := Vector2(x, z).length()
	if d > WORLD_RADIUS - 80.0:
		h -= (d - (WORLD_RADIUS - 80.0)) * 0.06
	return h


func rockiness(x: float, z: float) -> float:
	## 0 on ordinary ground, rising toward 1 on rocky knolls.
	return maxf(_ridge.get_noise_2d(x, z) - 0.32, 0.0) * 2.2


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
