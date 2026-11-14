extends Control
## The charted map (core/chart.gd), opened by Using a Map: the world's chart
## drawn in pencil on a sheet, blank where you haven't been, with an arrow
## for where you are and which way you face, and the markers you have put
## on it. Click to put a marker down, right-click one to rub it out, scroll
## to zoom, drag to move about; Esc or Tab puts the map away. Markers show
## only here, never out in the world.

signal closed

const Chart := preload("res://src/core/chart.gd")

const PAPER := Color(0.87, 0.83, 0.70)
const EDGE := Color(0.62, 0.56, 0.42)
const PENCIL := Color(0.25, 0.25, 0.28)
const MARK := Color(0.62, 0.16, 0.12)
const DEEP := Color(0.56, 0.62, 0.68)
const SHALLOW := Color(0.67, 0.72, 0.73)
const MARSH := Color(0.75, 0.75, 0.61)
const LAND := Color(0.71, 0.67, 0.53)
const HIGH := Color(0.55, 0.50, 0.40)
const ROCK := Color(0.60, 0.59, 0.56)
const ZOOM_MAX := 10.0
const GRID_LINES := 100.0     # metres between the faint ruled lines

var world: Node = null
var zoom := 3.0               # 1: the whole chart on the sheet
var center := Vector2.ZERO    # the world x, z in the middle of the sheet

var _img: Image
var _tex: ImageTexture
var _drawn := PackedByteArray()   # cells already painted into _img
var _press := Vector2.INF         # where the left button went down
var _dragged := false
var _font: Font


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = ThemeDB.fallback_font
	_img = Image.create(Chart.GRID, Chart.GRID, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 0))
	_tex = ImageTexture.create_from_image(_img)
	_drawn.resize(Chart.GRID * Chart.GRID)


func open() -> void:
	paint()
	if world and world.player:
		center = Vector2(world.player.global_position.x, world.player.global_position.z)
	zoom = 3.0
	_clamp()
	visible = true
	queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_press = Vector2.INF
	closed.emit()


func paint() -> void:
	## Paints the newly charted cells into the map image.
	Chart.ensure()
	var any := false
	for k in Chart.GRID * Chart.GRID:
		if Game.chart[k] != 0 and _drawn[k] == 0:
			_drawn[k] = 1
			_img.set_pixel(k % Chart.GRID, k / Chart.GRID, cell_color(k))
			any = true
	if any:
		_tex.update(_img)


func cell_color(k: int) -> Color:
	## A charted cell in pencil: water shaded by depth, marsh, higher ground
	## darker the higher it is, and the bare rock of the islands.
	var c := Chart.center(k)
	var t = world.terrain if world else null
	if t == null:
		return LAND
	var h: float = t.height(c.x, c.y)
	if h < -1.5:
		return DEEP
	if h < 0.0:
		return SHALLOW
	if not t.island_at(c.x, c.y).is_empty() and t.rockiness(c.x, c.y) > 0.5:
		return ROCK
	if h < 1.5:
		return MARSH
	return LAND.lerp(HIGH, clampf((h - 1.5) / 8.0, 0.0, 1.0))


# --- Where things are on the sheet ---------------------------------------------------------

func sheet() -> Rect2:
	## The square sheet, as big as fits under the key and above the hotbar.
	var s := minf(size.x - 40.0, size.y - 130.0)
	return Rect2(Vector2((size.x - s) * 0.5, 48.0), Vector2(s, s))


func span() -> float:
	return 2.0 * Chart.HALF / zoom


func to_screen(w: Vector2) -> Vector2:
	var r := sheet()
	return r.position + (w - center + Vector2.ONE * span() * 0.5) / span() * r.size.x


func to_world(p: Vector2) -> Vector2:
	var r := sheet()
	return center - Vector2.ONE * span() * 0.5 + (p - r.position) / r.size.x * span()


func _clamp() -> void:
	zoom = clampf(zoom, 1.0, ZOOM_MAX)
	var m := Chart.HALF - span() * 0.5
	center = Vector2(clampf(center.x, -m, m), clampf(center.y, -m, m))


# --- Input -------------------------------------------------------------------------------------

func _input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("pause") or ev.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(mb.position, 1.25 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_dragged = false
			else:
				if _press.is_finite() and not _dragged and sheet().has_point(mb.position):
					var w := to_world(mb.position)
					if Chart.add_mark(w.x, w.y):
						Sfx.play("rustle", -12.0, 0.3)
					else:
						Game.notify("There's no room for more markers. Right-click one to rub it out.")
				_press = Vector2.INF
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var w := to_world(mb.position)
			if Chart.remove_mark_near(w.x, w.y, 14.0 / sheet().size.x * span()):
				Sfx.play("rustle", -12.0, 0.3)
		accept_event()
		queue_redraw()
	elif ev is InputEventMouseMotion and _press.is_finite():
		var mm := ev as InputEventMouseMotion
		if mm.position.distance_to(_press) > 5.0:
			_dragged = true
		if _dragged:
			center -= mm.relative / sheet().size.x * span()
			_clamp()
			queue_redraw()
		accept_event()


func zoom_at(p: Vector2, f: float) -> void:
	## Zooms by f, keeping the point under p where it is.
	var before := to_world(p)
	zoom *= f
	_clamp()
	center += before - to_world(p)
	_clamp()
	queue_redraw()


# --- Drawing -----------------------------------------------------------------------------------

func _process(_dt: float) -> void:
	if visible:
		queue_redraw()  # the arrow follows you as you turn


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var r := sheet()
	draw_rect(r.grow(8.0), EDGE)
	draw_rect(r, PAPER)
	# The chart: the part of the image under the sheet.
	var cells := span() / Chart.CELL
	var src_pos := (center - Vector2.ONE * span() * 0.5 + Vector2.ONE * Chart.HALF) / Chart.CELL
	draw_texture_rect_region(_tex, r, Rect2(src_pos, Vector2(cells, cells)))
	# Faint ruled lines every GRID_LINES metres.
	var line := Color(PENCIL, 0.12)
	var w0 := to_world(r.position)
	var x := ceilf(w0.x / GRID_LINES) * GRID_LINES
	while x < w0.x + span():
		var sx := to_screen(Vector2(x, 0)).x
		draw_line(Vector2(sx, r.position.y), Vector2(sx, r.end.y), line, 1.0)
		x += GRID_LINES
	var z := ceilf(w0.y / GRID_LINES) * GRID_LINES
	while z < w0.y + span():
		var sy := to_screen(Vector2(0, z)).y
		draw_line(Vector2(r.position.x, sy), Vector2(r.end.x, sy), line, 1.0)
		z += GRID_LINES
	# Markers.
	for j in Game.map_marks.size():
		var m: Dictionary = Game.map_marks[j]
		var p := to_screen(Vector2(float(m.x), float(m.z)))
		if r.has_point(p):
			draw_line(p + Vector2(-6, -6), p + Vector2(6, 6), MARK, 2.5)
			draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), MARK, 2.5)
			draw_string(_font, p + Vector2(8, -6), str(j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MARK)
	# You: an arrow pointing the way you face.
	if world and world.player:
		var pl: Node3D = world.player
		var at := to_screen(Vector2(pl.global_position.x, pl.global_position.z))
		var f := -pl.global_transform.basis.z
		var d := Vector2(f.x, f.z)
		d = d.normalized() if d.length() > 0.01 else Vector2(0, -1)
		var side := Vector2(-d.y, d.x)
		if r.grow(-4.0).has_point(at):
			var tri := PackedVector2Array([at + d * 13.0, at - d * 7.0 + side * 7.0, at - d * 3.0, at - d * 7.0 - side * 7.0])
			draw_colored_polygon(tri, Color(0.12, 0.2, 0.45))
			tri.append(tri[0])
			draw_polyline(tri, Color(0.95, 0.93, 0.85), 1.5)
		else:
			# Off the sheet: a small arrow at the edge showing which way you are.
			var to := (at - r.get_center()).normalized()
			var edge := r.get_center() + to * (r.size.x * 0.5 - 12.0)
			draw_circle(edge, 5.0, Color(0.12, 0.2, 0.45))
	# North, and the key.
	draw_string(_font, Vector2(r.end.x - 22, r.position.y + 22), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PENCIL)
	draw_line(Vector2(r.end.x - 16, r.position.y + 28), Vector2(r.end.x - 16, r.position.y + 48), PENCIL, 2.0)
	var key := Settings.hint("Click: marker    Right-click: rub out    Scroll: zoom    Drag: move    Esc/Tab: close")
	draw_string(_font, Vector2(0, 30), key, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1, 0.9))
