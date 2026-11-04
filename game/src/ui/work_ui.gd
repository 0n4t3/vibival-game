extends Control
## The overlay while crafting on the ground: a tray of your inventory along
## the bottom (click to lay an item down, right-click for the whole stack),
## what the laid-out items can make on the right, and instructions above the
## tray.
## Clicks and drags elsewhere go to the work spot in 3D.
## Gamepad: the right stick moves the cursor, A clicks, X does the next step
## (hold it to twist), B puts the work down.

const Icons := preload("res://src/ui/icons.gd")
const Inventory := preload("res://src/core/inventory.gd")

signal leave

const MAX_ALMOST := 3   # options still missing parts that are listed
const MAX_LIST := 380.0
const CLEAR_PAD := 30.0  # px kept between what you work on and a panel
const BASE_FOV := 50.0
const MAX_FOV := 75.0
const TOP := 40.0        # the clock and day line along the top
const MAX_BACK := 1.2    # m the camera may step back when the widest view isn't enough

var spot: Node3D = null
var _tray: Array[Button] = []
var _info: Label
var _bar: ProgressBar
var _make: VBoxContainer
var _make_scroll: ScrollContainer
var _make_title: Label
var _hover := -1
var _drag := false
var _side: PanelContainer
var _top: PanelContainer
var _hover_how := ""


class TraySlot extends Button:
	var index := 0
	var ui: Control

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.08, 0.11, 0.07, 0.9))
		draw_rect(r, Color(0.8, 0.85, 0.6) if ui._hover == index else Color(0.45, 0.5, 0.35, 0.7), false, 1.0)
		var s = Game.inventory.slots[index]
		if s == null:
			return
		Icons.draw_item(self, r.grow(-5), s.id)
		if s.n > 1:
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 18, size.y - 4), str(s.n), HORIZONTAL_ALIGNMENT_RIGHT, 16, 12)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	# Layout: what to make on the right, then the instructions and the tray
	# along the bottom (the top stays clear for the HUD's hints).
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 56)  # below the clock
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var mid := HBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(mid)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(gap)
	var side := _panel()
	side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(side)
	_side = side
	var sb := VBoxContainer.new()
	sb.add_theme_constant_override("separation", 6)
	sb.custom_minimum_size = Vector2(280, 0)
	side.add_child(sb)
	_make_title = Label.new()
	_make_title.add_theme_font_size_override("font_size", 18)
	sb.add_child(_make_title)
	_make_scroll = ScrollContainer.new()
	_make_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sb.add_child(_make_scroll)
	_make = VBoxContainer.new()
	_make.add_theme_constant_override("separation", 6)
	_make.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_scroll.add_child(_make)

	var info_row := CenterContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(info_row)
	var top := _panel()
	info_row.add_child(top)
	_top = top
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(620, 0)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 15)
	var tb := VBoxContainer.new()
	top.add_child(tb)
	tb.add_child(_info)
	# How far the twisting has got, so rolling shows at a glance.
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(620, 14)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.7, 0.4)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.4)
	bg.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.visible = false
	tb.add_child(_bar)

	var bottom_row := CenterContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom_row)
	var bottom := _panel()
	bottom_row.add_child(bottom)
	var bb := VBoxContainer.new()
	bottom.add_child(bb)
	var row := HBoxContainer.new()
	bb.add_child(row)
	var l := Label.new()
	l.text = "Your things (tap to lay one down)" if Settings.touch else "Your things (click: lay one down, right-click: the stack)"
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.6)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var done := Button.new()
	done.text = "Done [C]"
	done.pressed.connect(func(): leave.emit())
	row.add_child(done)
	var grid := GridContainer.new()
	grid.columns = 15
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	bb.add_child(grid)
	for i in Inventory.SIZE:
		var s := TraySlot.new()
		s.index = i
		s.ui = self
		s.flat = true
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(44, 44)
		s.gui_input.connect(_on_tray_input.bind(i))
		s.mouse_entered.connect(_set_hover.bind(i))
		s.mouse_exited.connect(_set_hover.bind(-1))
		grid.add_child(s)
		_tray.append(s)

	Game.inventory.changed.connect(_refresh)
	Assets.icons_ready.connect(_redraw_tray)


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.05, 0.86)
	sb.border_color = Color(0.4, 0.48, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


func open(work: Node3D) -> void:
	spot = work
	spot.changed.connect(_refresh)
	visible = true
	_drag = false
	_hover_how = ""
	if spot.player:
		spot.player.work_view = Vector3.ZERO
		spot.player.work_back = 0.0
	_refresh()


func close() -> void:
	if spot and is_instance_valid(spot) and spot.changed.is_connected(_refresh):
		spot.changed.disconnect(_refresh)
	if spot and is_instance_valid(spot) and spot.player:
		spot.player.work_view = Vector3.ZERO
		spot.player.work_back = 0.0
	spot = null
	visible = false


func _on_tray_input(ev: InputEvent, i: int) -> void:
	if spot == null or not (ev is InputEventMouseButton) or not ev.pressed:
		return
	if ev.button_index == MOUSE_BUTTON_LEFT:
		spot.lay(i, 1)
	elif ev.button_index == MOUSE_BUTTON_RIGHT:
		spot.lay(i, 1 << 20)
	accept_event()


func _gui_input(ev: InputEvent) -> void:
	if spot == null:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_drag = ev.pressed
		if ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			spot.click(ev.position, ev.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()
	elif ev is InputEventMouseMotion and _drag:
		spot.drag(ev.relative)
		accept_event()


func _process(delta: float) -> void:
	if not visible or spot == null:
		return
	_frame_work()
	if Input.get_connected_joypads().is_empty():
		return
	# Gamepad: the right stick drives the cursor.
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		var vp := get_viewport()
		vp.warp_mouse(vp.get_mouse_position() + stick * 700.0 * delta)
	if Input.is_action_pressed("interact"):
		spot.hold(delta)


func _unhandled_input(ev: InputEvent) -> void:
	if not visible or spot == null:
		return
	if ev.is_action_pressed("interact"):
		spot.press()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("jump"):
		# Gamepad A: click where the cursor is.
		var at := get_viewport().get_mouse_position()
		var hit := false
		for s in _tray:
			if s.get_global_rect().has_point(at):
				spot.lay(s.index, 1)
				hit = true
		if not hit:
			spot.click(at)
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("drop"):
		leave.emit()
		get_viewport().set_input_as_handled()


func clear_rect() -> Rect2:
	## The part of the screen the panels leave open: left of what-to-make,
	## above the instructions and below the clock line.
	var r := get_viewport_rect()
	var right := r.size.x - 12.0
	if _side and _side.is_visible_in_tree():
		right = _side.get_global_rect().position.x
	var bottom := r.size.y - 12.0
	if _top and _top.is_visible_in_tree():
		bottom = _top.get_global_rect().position.y
	return Rect2(Vector2(12.0, TOP), Vector2(right - 12.0, bottom - TOP)).grow(-CLEAR_PAD)


func _frame_work() -> void:
	## Turns the camera (and widens its view if need be) so the work, the mark
	## to click and the piles stay in the clear part of the screen, never
	## under a panel. It only moves when something would be covered, so a
	## mark you are about to click doesn't drift away.
	var player: Node = spot.player
	if player == null or player.camera == null:
		return
	var cam: Camera3D = player.camera
	var bb := Rect2()
	var any := false
	for p: Vector3 in spot.view_points():
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		bb = bb.expand(sp) if any else Rect2(sp, Vector2.ZERO)
		any = true
	if not any:
		return
	var clear := clear_rect()
	var view: Vector3 = player.work_view
	var f := get_viewport_rect().size.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	# Too big for the clear part: widen the view; well inside it: narrow
	# back toward the usual.
	var need := maxf(bb.size.x / maxf(clear.size.x, 1.0), bb.size.y / maxf(clear.size.y, 1.0))
	if need > 1.0 or (need < 0.7 and cam.fov > BASE_FOV + 0.5):
		var want := rad_to_deg(2.0 * atan(tan(deg_to_rad(cam.fov) * 0.5) * need / 0.9))
		view.z = clampf(want, BASE_FOV, MAX_FOV) - BASE_FOV
	# Still too big at the widest: step back a little at a time.
	if need > 1.0 and cam.fov >= MAX_FOV - 1.0:
		player.work_back = minf(player.work_back + 0.01, MAX_BACK)
	elif need < 0.75 and player.work_back > 0.0:
		player.work_back = maxf(player.work_back - 0.01, 0.0)
	# Shift just enough to bring it inside: content moves right as the
	# camera turns left, and down as it tilts up.
	var d := Vector2.ZERO
	for axis in 2:
		var lo: float = bb.position[axis] - clear.position[axis]
		var hi: float = bb.end[axis] - clear.end[axis]
		if bb.size[axis] > clear.size[axis]:
			d[axis] = clear.get_center()[axis] - bb.get_center()[axis]
		elif lo < 0.0:
			d[axis] = -lo
		elif hi > 0.0:
			d[axis] = -hi
	if d != Vector2.ZERO:
		view.x = cam.rotation.y + atan(d.x / f)
		view.y = cam.rotation.x + atan(d.y / f)
	player.work_view = Vector3(clampf(view.x, -0.6, 0.6), clampf(view.y, -0.6, 0.6), view.z)


func _set_hover(i: int) -> void:
	_hover = i
	_redraw_tray()


func _redraw_tray() -> void:
	for s in _tray:
		s.queue_redraw()


func _refresh() -> void:
	if not visible or spot == null:
		return
	_redraw_tray()
	_info.text = _hover_how if _hover_how != "" and spot.recipe.is_empty() else spot.instructions()
	_bar.visible = spot.recipe.get("act", "") == "twist"
	_bar.value = spot.progress
	for c in _make.get_children():
		_make.remove_child(c)
		c.queue_free()
	if not spot.recipe.is_empty():
		_hover_how = ""
		var r: Dictionary = spot.recipe
		_make_title.text = r.verb if r.has("butcher") or r.has("wood") or r.has("house") or r.has("trap") or r.has("plot") else "Making %s" % Items.item_name(r.out)
		var how := Label.new()
		how.text = r.how
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size = Vector2(260, 0)
		how.add_theme_font_size_override("font_size", 13)
		_make.add_child(how)
		var stop := Button.new()
		stop.text = "Stop"
		stop.pressed.connect(spot.cancel)
		_make.add_child(stop)
		_fit_make.call_deferred()
		return
	var opts: Array = _ranked(spot.options())
	var makeable := opts.filter(func(o): return o.missing.is_empty())
	var almost := opts.filter(func(o): return not o.missing.is_empty())
	opts = makeable + almost.slice(0, MAX_ALMOST)
	_make_title.text = "Make" if not opts.is_empty() else "Lay out materials"
	if opts.is_empty():
		var l := Label.new()
		l.text = "Lay things down to see what you could make with them. The recipe book (%s, Recipes) lists everything." % ("Bag" if Settings.touch else "Tab")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		l.add_theme_font_size_override("font_size", 13)
		l.modulate = Color(1, 1, 1, 0.7)
		_make.add_child(l)
	for o in opts:
		var r: Dictionary = o.recipe
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var out: String = r.get("label", Items.item_name(r.out) + (" x%d" % r.n if r.n > 1 else ""))
		b.text = "%s\n    %s" % [r.verb, out] if o.missing.is_empty() else "%s\n    needs %s" % [r.verb, ", ".join(o.missing)]
		b.disabled = not o.missing.is_empty()
		# How it is made shows in the instructions, not in a pop-up that would
		# cover the recipes below it.
		b.mouse_entered.connect(_show_how.bind(r.how))
		b.mouse_exited.connect(_show_how.bind(""))
		b.pressed.connect(spot.begin.bind(r))
		_make.add_child(b)
	if almost.size() > MAX_ALMOST:
		var more := Label.new()
		more.text = "...and %d more you have some parts for." % (almost.size() - MAX_ALMOST)
		more.add_theme_font_size_override("font_size", 12)
		more.modulate = Color(1, 1, 1, 0.6)
		_make.add_child(more)
	_fit_make.call_deferred()


func _ranked(opts: Array) -> Array:
	## The recipes that use more of what you laid out first (the chisel and
	## saw before a blade, when chert, sticks and cordage are laid out), in
	## book order otherwise.
	var keyed := []
	for i in opts.size():
		var r: Dictionary = opts[i].recipe
		var used: int = r.get("in", {}).keys().filter(func(id): return spot.laid(id) > 0).size()
		keyed.append([-used, i, opts[i]])
	keyed.sort()
	return keyed.map(func(k): return k[2])


func _show_how(how: String) -> void:
	_hover_how = how
	if spot and spot.recipe.is_empty():
		_info.text = how if how != "" else spot.instructions()


func _fit_make() -> void:
	## Grows the list with its contents up to MAX_LIST px, then scrolls.
	if _make_scroll:
		_make_scroll.custom_minimum_size.y = minf(_make.get_combined_minimum_size().y, MAX_LIST)
