extends Control
## The overlay while crafting on the ground: a tray of your inventory along
## the bottom (click to lay an item down, right-click for the whole stack),
## what the laid-out items can make on the right, and instructions above the
## tray.
## Clicks and drags elsewhere go to the work spot in 3D.
## Gamepad: the look stick moves a drawn cursor (pads can't move the mouse
## on the web or Android), A clicks, the use trigger clicks as a right-click,
## X does the next step (hold it to twist), B puts the work down.
## Reading papers through (a "read" recipe, the breakroom's) shows the page
## on top over the work (papers.gd); a click turns it.

const Icons := preload("res://src/ui/icons.gd")
const Papers := preload("res://src/ui/papers.gd")
const Inventory := preload("res://src/core/inventory.gd")

signal leave

const MAX_ALMOST := 3   # options still missing parts that are listed
const MAX_LIST := 380.0
const CLEAR_PAD := 30.0  # px kept between what you work on and a panel
const BASE_FOV := 50.0
const MAX_FOV := 75.0
const TOP := 40.0        # the clock and day line along the top
const MAX_BACK := 1.2    # m the camera may step back when the widest view isn't enough
const CURSOR_SPEED := 700.0  # px a second at full stick

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
var _done: Button
var _tray_label: Label
var _cursor := Vector2.ZERO  # the gamepad cursor, shown once the stick moves it
var _cursor_mark: Control
var _papers: Control         # the page on top, while reading papers through (a "read" recipe)


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
	_tray_label = Label.new()
	_tray_label.add_theme_font_size_override("font_size", 12)
	_tray_label.modulate = Color(1, 1, 1, 0.6)
	_tray_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tray_label)
	# Everything here is clicked (on a gamepad, with the cursor), so no
	# button takes focus and eats the pad's click.
	_done = Button.new()
	_done.focus_mode = Control.FOCUS_NONE
	_done.pressed.connect(func(): leave.emit())
	row.add_child(_done)
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

	_papers = Papers.new()
	_papers.visible = false
	_papers.turned.connect(_turn_page)
	add_child(_papers)

	_cursor_mark = Control.new()
	_cursor_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_mark.visible = false
	_cursor_mark.draw.connect(func():
		_cursor_mark.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.3))
		_cursor_mark.draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color(1.0, 0.95, 0.75), 2.0)
		_cursor_mark.draw_circle(Vector2.ZERO, 1.5, Color(1.0, 0.95, 0.75)))
	add_child(_cursor_mark)

	Game.inventory.changed.connect(_refresh)
	Settings.input_changed.connect(_refresh)
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
	get_viewport().gui_release_focus()  # the pad's click goes to the cursor
	_drag = false
	_hover_how = ""
	_cursor_mark.visible = false
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
	_papers.visible = false
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
	if _papers.visible:
		var c := clear_rect()
		_papers.position = c.position
		_papers.size = c.size
		_papers.show_page(spot.steps)
	if Input.get_connected_joypads().is_empty():
		return
	# Gamepad: the look stick drives the cursor.
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick != Vector2.ZERO:
		if not _cursor_mark.visible:
			_cursor = clear_rect().get_center()
			_cursor_mark.visible = true
		_cursor = (_cursor + stick * CURSOR_SPEED * delta).clamp(Vector2.ZERO, get_viewport_rect().size)
		_cursor_mark.position = _cursor
		_pad_hover()
	if Input.is_action_pressed("interact"):
		spot.hold(delta)


func _input(ev: InputEvent) -> void:
	# The real mouse takes over from the gamepad cursor.
	if _cursor_mark and _cursor_mark.visible and ev is InputEventMouseMotion and ev.relative.length() > 2.0:
		_cursor_mark.visible = false


func _pad_hover() -> void:
	## What the gamepad cursor is over lights up as the mouse would.
	var slot := -1
	for s in _tray:
		if s.get_global_rect().has_point(_cursor):
			slot = s.index
	if slot != _hover:
		_set_hover(slot)
	var how := ""
	for b in _make.get_children():
		if b is Button and b.has_meta("how") and b.get_global_rect().has_point(_cursor) \
				and _make_scroll.get_global_rect().has_point(_cursor):
			how = b.get_meta("how")
	if how != _hover_how:
		_show_how(how)


func _pad_click(right: bool) -> void:
	## A gamepad click at the cursor (or at the mouse if it hasn't moved):
	## a tray slot lays an item (the stack for a right-click), a button
	## presses, anything else goes to the work.
	var at := _cursor if _cursor_mark.visible else get_viewport().get_mouse_position()
	for s in _tray:
		if s.get_global_rect().has_point(at):
			spot.lay(s.index, 1 << 20 if right else 1)
			return
	var buttons: Array = [_done]
	if _make_scroll.get_global_rect().has_point(at):
		buttons += _make.get_children()
	for b in buttons:
		if b is Button and not b.disabled and b.is_visible_in_tree() and b.get_global_rect().has_point(at):
			if not right:
				b.pressed.emit()
			return
	if _papers.visible:
		if not right:
			spot.step()  # the page turns wherever the cursor is
		return
	spot.click(at, right)


func _unhandled_input(ev: InputEvent) -> void:
	if not visible or spot == null:
		return
	if ev.is_action_pressed("interact"):
		spot.press()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("jump"):
		# Gamepad A: click where the cursor is.
		_pad_click(false)
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("use") and (ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
		_pad_click(true)
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


func _turn_page() -> void:
	if spot:
		spot.step()


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
	_done.text = "Done [%s]" % Settings.button_name("craft")
	if Settings.touch:
		_tray_label.text = "Your things (tap to lay one down)"
	elif Settings.using_pad:
		_tray_label.text = "Your things (%s moves the cursor, %s: lay one down, %s: the stack)" \
				% ["right stick", Settings.button_name("jump"), Settings.button_name("use")]
	else:
		_tray_label.text = "Your things (click: lay one down, right-click: the stack)"
	_info.text = Settings.hint(_hover_how if _hover_how != "" and spot.recipe.is_empty() else spot.instructions())
	_bar.visible = spot.recipe.get("act", "") == "twist"
	_papers.visible = spot.recipe.get("read", false)
	_bar.value = spot.progress
	for c in _make.get_children():
		_make.remove_child(c)
		c.queue_free()
	if not spot.recipe.is_empty():
		_hover_how = ""
		var r: Dictionary = spot.recipe
		_make_title.text = r.verb if r.has("butcher") or r.has("wood") or r.has("house") or r.has("trap") or r.has("plot") else "Making %s" % Items.item_name(r.out)
		var how := Label.new()
		how.text = Settings.hint(r.how)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.custom_minimum_size = Vector2(260, 0)
		how.add_theme_font_size_override("font_size", 13)
		_make.add_child(how)
		var stop := Button.new()
		stop.text = "Stop"
		stop.focus_mode = Control.FOCUS_NONE
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
		var bag := Settings.button_name("inventory")
		l.text = "Lay things down to see what you could make with them. The recipe book (%s, Recipes) lists everything." % (bag.left(1).to_upper() + bag.substr(1))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(260, 0)
		l.add_theme_font_size_override("font_size", 13)
		l.modulate = Color(1, 1, 1, 0.7)
		_make.add_child(l)
	for o in opts:
		var r: Dictionary = o.recipe
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var out: String = r.get("label", Items.item_name(r.out) + (" x%d" % r.n if r.n > 1 else ""))
		b.text = "%s\n    %s" % [r.verb, out] if o.missing.is_empty() else "%s\n    needs %s" % [r.verb, ", ".join(o.missing)]
		b.disabled = not o.missing.is_empty()
		# How it is made shows in the instructions, not in a pop-up that would
		# cover the recipes below it.
		b.set_meta("how", r.how)
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
		_info.text = Settings.hint(how if how != "" else spot.instructions())


func _fit_make() -> void:
	## Grows the list with its contents up to MAX_LIST px, then scrolls.
	if _make_scroll:
		_make_scroll.custom_minimum_size.y = minf(_make.get_combined_minimum_size().y, MAX_LIST)
