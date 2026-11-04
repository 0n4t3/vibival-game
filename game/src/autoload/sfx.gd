extends Node
## Procedurally synthesised sound effects (no audio files shipped).
## Sounds are generated on first use and cached as 16-bit mono WAV streams.

const RATE := 22050

var _cache := {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next2d := 0
var _next3d := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 60.0
		p.unit_size = 6.0
		add_child(p)
		_pool3d.append(p)


func play(sound: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	var p := _pool2d[_next2d]
	_next2d = (_next2d + 1) % _pool2d.size()
	p.stream = stream(sound)
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.play()


func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch_var := 0.1) -> void:
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = stream(sound)
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.play()


func stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		var fn := "_s_" + sound
		var samples: PackedFloat32Array = call(fn) if has_method(fn) else _s_click()
		var loop := sound in ["fire", "rain", "swamp", "buzz", "hum", "wind"]
		_cache[sound] = _to_wav(samples, loop)
	return _cache[sound]


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


# --- Synth helpers -------------------------------------------------------------

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func _noise(seconds: float, lp: float, decay: float, gain := 1.0) -> PackedFloat32Array:
	## Low-passed noise with exponential decay. lp in (0,1]: higher = brighter.
	var b := _buf(seconds)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += lp * (_rng.randf_range(-1.0, 1.0) - y)
		b[i] = y * exp(-decay * t) * gain
	return b


func _tone(seconds: float, f0: float, f1: float, decay: float, gain := 1.0, attack := 0.005) -> PackedFloat32Array:
	var b := _buf(seconds)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / seconds)
		phase += TAU * f / RATE
		b[i] = sin(phase) * exp(-decay * t) * minf(t / attack, 1.0) * gain
	return b


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0) -> PackedFloat32Array:
	if a.size() < b.size() + offset:
		a.resize(b.size() + offset)
	for i in b.size():
		a[i + offset] += b[i]
	return a


func _fade_loop(b: PackedFloat32Array, fade := 0.15) -> PackedFloat32Array:
	## Crossfades the tail into the head so the loop point is seamless.
	var n := int(fade * RATE)
	var out := b.slice(0, b.size() - n)
	for i in n:
		var k := float(i) / n
		out[i] = out[i] * k + b[b.size() - n + i] * (1.0 - k)
	return out


# --- Sounds -------------------------------------------------------------------

func _s_click() -> PackedFloat32Array:
	return _mix(_noise(0.03, 0.8, 120.0, 0.4), _tone(0.03, 1800, 1500, 90.0, 0.3))


func _s_step() -> PackedFloat32Array:
	return _noise(0.1, 0.12, 35.0, 0.6)


func _s_splash() -> PackedFloat32Array:
	var b := _noise(0.4, 0.35, 9.0, 0.5)
	for k in 3:
		b = _mix(b, _tone(0.08, 500 + k * 300, 1200 + k * 200, 30.0, 0.15), int(_rng.randf_range(0.02, 0.2) * RATE))
	return b


func _s_rustle() -> PackedFloat32Array:
	## Dry fibers rubbing together under the palm.
	var b := _noise(0.16, 0.55, 14.0, 0.35)
	for i in b.size():
		var t := float(i) / RATE
		b[i] *= minf(t / 0.03, 1.0) * (0.6 + 0.4 * sin(t * TAU * 38.0))
	return b


func _s_pickup() -> PackedFloat32Array:
	return _mix(_tone(0.08, 520, 700, 25.0, 0.35), _tone(0.1, 780, 1040, 20.0, 0.3), int(0.05 * RATE))


func _s_craft() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	for k in 3:
		b = _mix(b, _mix(_noise(0.05, 0.6, 70.0, 0.5), _tone(0.05, 900 - k * 150, 700, 60.0, 0.2)), int(k * 0.08 * RATE))
	return b


func _s_knap() -> PackedFloat32Array:
	return _mix(_noise(0.05, 0.95, 90.0, 0.6), _tone(0.06, 2600, 2100, 70.0, 0.35))


func _s_swing() -> PackedFloat32Array:
	var b := _buf(0.18)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var lp := lerpf(0.05, 0.4, sin(PI * t / 0.18))
		y += lp * (_rng.randf_range(-1.0, 1.0) - y)
		b[i] = y * sin(PI * t / 0.18) * 0.5
	return b


func _s_hit() -> PackedFloat32Array:
	return _mix(_tone(0.18, 160, 60, 18.0, 0.8), _noise(0.08, 0.5, 40.0, 0.5))


func _s_chop() -> PackedFloat32Array:
	## An axe biting into wood: a hollow knock and a splintery crack.
	return _mix(_mix(_tone(0.16, 420, 240, 26.0, 0.7), _tone(0.12, 900, 600, 40.0, 0.25)), _noise(0.1, 0.7, 50.0, 0.55))


func _s_creak() -> PackedFloat32Array:
	## A trunk giving way: a slow groaning creak, rising.
	var b := _buf(1.1)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 70.0 + t * 60.0 + sin(t * 31.0) * 12.0
		phase += TAU * f / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		b[i] = saw * 0.35 * minf(t / 0.2, 1.0) * clampf((1.1 - t) / 0.3, 0.0, 1.0) * (0.6 + 0.4 * sin(t * 47.0))
	return _mix(b, _noise(1.0, 0.2, 2.0, 0.15))


func _s_thud() -> PackedFloat32Array:
	## A heavy trunk hitting the ground, with leaves rattling after.
	var b := _mix(_tone(0.7, 70, 38, 6.0, 1.0), _noise(0.5, 0.25, 9.0, 0.7))
	return _mix(b, _noise(0.8, 0.8, 5.0, 0.18), int(0.05 * RATE))


func _s_hurt() -> PackedFloat32Array:
	var b := _mix(_tone(0.3, 110, 50, 9.0, 0.9), _noise(0.2, 0.25, 15.0, 0.6))
	for i in b.size():
		b[i] = tanh(b[i] * 2.0) * 0.7
	return b


func _s_eat() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	for k in 4:
		b = _mix(b, _noise(0.07, 0.7, 45.0, 0.45), int(k * 0.13 * RATE))
	return b


func _s_drink() -> PackedFloat32Array:
	var b := _tone(0.14, 320, 140, 12.0, 0.6, 0.02)
	return _mix(b, _tone(0.14, 300, 130, 12.0, 0.6, 0.02), int(0.3 * RATE))


func _s_hiss() -> PackedFloat32Array:
	var b := _buf(0.7)
	var lo := 0.0
	var hi := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1.0, 1.0)
		lo += 0.5 * (n - lo)
		hi += 0.08 * (lo - hi)
		b[i] = (lo - hi) * minf(t * 20.0, 1.0) * exp(-3.0 * t) * 0.8
	return b


func _s_croak() -> PackedFloat32Array:
	var b := _buf(0.7)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(70.0, 45.0, t / 0.7) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var am := 0.5 + 0.5 * sin(TAU * 16.0 * t)
		b[i] = tanh(saw * am * 1.6) * minf(t * 10.0, 1.0) * exp(-2.5 * t) * 0.7
	return b


func _s_roar() -> PackedFloat32Array:
	# A wet, bellowing hiss-growl with a splash at the start.
	var b := _buf(1.3)
	var phase := 0.0
	var lo := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(95.0, 38.0, t / 1.3) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		lo += 0.15 * (_rng.randf() * 2.0 - 1.0 - lo)
		var rough := 0.55 + 0.45 * sin(TAU * 23.0 * t + sin(TAU * 3.0 * t) * 2.0)
		b[i] = tanh((saw * rough * 1.8 + lo * 1.2)) * minf(t * 30.0, 1.0) * exp(-1.6 * t) * 0.9
	return _mix(b, _s_splash())


func _s_chitter() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	for k in 10:
		b = _mix(b, _mix(_noise(0.02, 0.9, 150.0, 0.3), _tone(0.02, 1400, 1100, 120.0, 0.15)), int(k * 0.045 * RATE))
	return b


func _s_buzz() -> PackedFloat32Array:
	var b := _buf(1.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * 38.0 / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		b[i] = saw * (0.55 + 0.45 * sin(TAU * 4.0 * t)) * 0.35
	return b


func _s_fire() -> PackedFloat32Array:
	var b := _noise(3.0, 0.03, 0.0, 0.5)
	for k in 40:
		var at := int(_rng.randf_range(0.0, 2.9) * RATE)
		b = _mix(b, _noise(0.02, 0.9, 200.0, _rng.randf_range(0.2, 0.7)), at)
	return _fade_loop(b)


func _s_rain() -> PackedFloat32Array:
	var b := _noise(3.0, 0.45, 0.0, 0.35)
	return _fade_loop(b, 0.3)


func _s_swamp() -> PackedFloat32Array:
	## Ambient bed: soft wind and water drips.
	var b := _buf(8.0)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += 0.01 * (_rng.randf_range(-1.0, 1.0) - y)
		b[i] = y * (0.6 + 0.4 * sin(TAU * t / 8.0)) * 1.8
	for k in 14:
		var at := int(_rng.randf_range(0.0, 7.6) * RATE)
		var f := _rng.randf_range(700.0, 1400.0)
		b = _mix(b, _tone(0.12, f, f * 1.6, 30.0, 0.12), at)
	return _fade_loop(b, 0.5)


func _s_wind() -> PackedFloat32Array:
	## A gale: rushing noise that swells and howls in gusts.
	var b := _buf(10.0)
	var y := 0.0
	var y2 := 0.0
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var gust := 0.55 + 0.3 * sin(TAU * t / 10.0) + 0.15 * sin(TAU * t * 3.0 / 10.0 + 1.0)
		var n := _rng.randf_range(-1.0, 1.0)
		y += (0.02 + 0.05 * gust) * (n - y)
		y2 += 0.004 * (n - y2)
		phase += TAU * (180.0 + 90.0 * gust) / RATE
		b[i] = (y * 1.6 + y2 * 3.0 + sin(phase) * y2 * 2.0) * gust
	return _fade_loop(b, 0.6)


func _s_thunder() -> PackedFloat32Array:
	## A crack, then a long rolling rumble.
	var b := _noise(5.0, 0.012, 0.5, 4.0)
	var roll := _buf(5.0)
	for i in roll.size():
		var t := float(i) / RATE
		roll[i] = 0.6 + 0.4 * sin(TAU * t * 1.3) * sin(TAU * t * 0.37 + 0.6)
	for i in b.size():
		b[i] *= roll[i]
	b = _mix(b, _noise(0.25, 0.6, 14.0, 0.7))
	for i in b.size():
		b[i] = tanh(b[i] * 1.4) * 0.85
	return b


func _s_hum() -> PackedFloat32Array:
	var b := _buf(2.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * 120.0 / RATE
		b[i] = (sin(phase) * 0.5 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.1) * 0.5
	return b


func _s_flash() -> PackedFloat32Array:
	var b := _noise(2.5, 0.8, 1.6, 0.9)
	b = _mix(b, _tone(2.5, 90, 30, 1.2, 0.9))
	for i in b.size():
		b[i] = tanh(b[i] * 1.5) * 0.8
	return b


func _s_fire_start() -> PackedFloat32Array:
	return _mix(_noise(0.8, 0.2, 3.0, 0.6), _noise(0.3, 0.9, 12.0, 0.4))
