extends RefCounted
## The charted map (see ui/map_view.gd). There is one chart per world
## (Game.chart): a GRID x GRID grid of CELL-metre squares over the whole
## swamp and its islands, each 1 once it has been drawn. Any Map you carry
## shows it. While you carry a Map and an ash pencil, the ground within REACH
## of you is drawn in as you go. A pencil draws SHARP cells, then it is blunt
## (its slot data's "drawn"); sharpening it with a blade (Use the pencil)
## wears one of its uses off. Markers you put on the map (Game.map_marks,
## [{x, z}]) show only on the map.

const CELL := 8.0
const HALF := 800.0           # the chart runs from -HALF to HALF in x and z
const GRID := 200             # 2 * HALF / CELL
const REACH := 32.0           # how far round you is drawn in
const SHARP := 400            # cells a sharp pencil draws before it is blunt
const MAX_MARKS := 40


static func ensure() -> void:
	if Game.chart.size() != GRID * GRID:
		Game.chart = PackedByteArray()
		Game.chart.resize(GRID * GRID)


static func cell_of(x: float, z: float) -> int:
	## The cell x, z is in, or -1 off the chart.
	var cx := floori((x + HALF) / CELL)
	var cz := floori((z + HALF) / CELL)
	if cx < 0 or cz < 0 or cx >= GRID or cz >= GRID:
		return -1
	return cz * GRID + cx


static func center(k: int) -> Vector2:
	## The middle of cell k, in world x, z.
	return Vector2((k % GRID + 0.5) * CELL - HALF, (k / GRID + 0.5) * CELL - HALF)


static func charted(x: float, z: float) -> bool:
	ensure()
	var k := cell_of(x, z)
	return k >= 0 and Game.chart[k] != 0


static func uncharted_near(p: Vector3) -> Array:
	## The cells within REACH of p not yet drawn.
	ensure()
	var out := []
	var n := ceili(REACH / CELL)
	var c := cell_of(p.x, p.z)
	if c < 0:
		return out
	var cx := c % GRID
	var cz := c / GRID
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= GRID or z >= GRID:
				continue
			var k := z * GRID + x
			if Game.chart[k] == 0 and center(k).distance_to(Vector2(p.x, p.z)) <= REACH:
				out.append(k)
	return out


static func drawn(s) -> int:
	## How many cells the pencil in slot s has drawn since it was sharpened.
	return int(s.get("data", {}).get("drawn", 0)) if s != null else 0


static func pencil_slot(inv) -> int:
	## The first sharp ash pencil in the bag, or -1.
	for i in inv.slots.size():
		var s = inv.slots[i]
		if s != null and s.id == "ash_pencil" and drawn(s) < SHARP:
			return i
	return -1


static func chart_round(inv, p: Vector3) -> String:
	## Draws in the ground round p if you carry a Map and a sharp pencil.
	## Returns why it couldn't when there was new ground to draw ("pencil":
	## none, "blunt": every pencil needs sharpening), else "".
	if inv.count("chart_map") < 1:
		return ""
	var cells := uncharted_near(p)
	if cells.is_empty():
		return ""
	var i := pencil_slot(inv)
	if i < 0:
		return "blunt" if inv.count("ash_pencil") > 0 else "pencil"
	for k in cells:
		Game.chart[k] = 1
	var s = inv.slots[i]
	var data: Dictionary = s.get("data", Items.uses_data("ash_pencil", inv.uses_left(i))).duplicate()
	data.drawn = drawn(s) + cells.size()
	inv.replace(i, "ash_pencil", s.age, data)
	return ""


static func sharpen(inv, i: int) -> String:
	## Sharpens the pencil in slot i with a blade from the bag, wearing one
	## use off it. Returns why not, or "".
	var s = inv.slots[i]
	if s == null or s.id != "ash_pencil":
		return "That isn't a pencil."
	if not inv.has_tag("cut"):
		return "You need a blade to sharpen the pencil."
	if drawn(s) == 0:
		return "The pencil is already sharp."
	var left: int = inv.uses_left(i) - 1
	if left <= 0:
		inv.take(i, 1)
		return ""
	inv.replace(i, "ash_pencil", s.age, Items.uses_data("ash_pencil", left))
	return ""


static func add_mark(x: float, z: float) -> bool:
	if Game.map_marks.size() >= MAX_MARKS or cell_of(x, z) < 0:
		return false
	Game.map_marks.append({"x": x, "z": z})
	return true


static func remove_mark_near(x: float, z: float, r: float) -> bool:
	## Removes the marker nearest x, z within r. Whether one went.
	var best := -1
	var bd := r
	for j in Game.map_marks.size():
		var m: Dictionary = Game.map_marks[j]
		var d := Vector2(float(m.x) - x, float(m.z) - z).length()
		if d <= bd:
			bd = d
			best = j
	if best < 0:
		return false
	Game.map_marks.remove_at(best)
	return true


static func to_save() -> Dictionary:
	ensure()
	return {"chart": Marshalls.raw_to_base64(Game.chart.compress(FileAccess.COMPRESSION_DEFLATE)), "map_marks": Game.map_marks.duplicate(true)}


static func from_save(data: Dictionary) -> void:
	Game.chart = PackedByteArray()
	if data.has("chart"):
		Game.chart = Marshalls.base64_to_raw(String(data.chart)).decompress(GRID * GRID, FileAccess.COMPRESSION_DEFLATE)
	ensure()
	Game.map_marks = []
	for m in data.get("map_marks", []):
		Game.map_marks.append({"x": float(m.x), "z": float(m.z)})
