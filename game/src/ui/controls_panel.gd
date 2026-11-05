extends PanelContainer
## Rebinding: two keyboard/mouse slots and a gamepad slot for each action.
## Pick a slot, then press what it should be: a key or mouse button for the
## keyboard slots, a pad button or stick/trigger direction for the gamepad
## slot. Delete clears it, Esc cancels. Whatever a pad sends is recorded as
## it comes, so a pad whose buttons or axes are numbered oddly (each Android
## device numbers its axes its own way) can still be set up.

signal closed

const WAIT_TIME := 6.0   # s before a slot stops waiting
const AXIS_PRESS := 0.6  # how far a stick or trigger must move from rest

var _buttons := {}       # action -> [Button, Button, Button]
var _status: Label
var _wait_action := ""
var _wait_slot := -1
var _wait_left := 0.0
var _rest := {}          # Vector2i(device, axis) -> its value when waiting began


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.05, 0.96)
	sb.border_color = Color(0.4, 0.48, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(620, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(0, minf(420.0, get_viewport_rect().size.y - 240.0))
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gutter := MarginContainer.new()  # clear of the scroll bar
	gutter.add_theme_constant_override("margin_right", 14)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(grid)
	scroll.add_child(gutter)
	for head in ["", "Keyboard / mouse", "Alternate", "Gamepad"]:
		var l := Label.new()
		l.text = head
		l.modulate = Color(1, 1, 1, 0.6)
		l.add_theme_font_size_override("font_size", 13)
		grid.add_child(l)
	for entry in Settings.BINDABLE:
		var action: String = entry[0]
		var l := Label.new()
		l.text = entry[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var row: Array[Button] = []
		for slot in 3:
			var b := Button.new()
			b.custom_minimum_size = Vector2(140, 0)
			b.clip_text = true
			b.pressed.connect(_wait.bind(action, slot))
			grid.add_child(b)
			row.append(b)
		_buttons[action] = row

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.modulate = Color(1, 1, 1, 0.75)
	vb.add_child(_status)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	vb.add_child(bottom)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.pressed.connect(func():
		_stop()
		Settings.reset_bindings()
		_refresh()
		_status.text = "Back to the default controls.")
	bottom.add_child(reset)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gap)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_on_back)
	bottom.add_child(back)

	_refresh()
	_status.text = "Pick a slot, then press the key or button for it."
	set_process(false)
	_buttons[Settings.BINDABLE[0][0]][0].grab_focus.call_deferred()


func _refresh() -> void:
	for action in _buttons:
		var slots: Array = Settings.bindings[action]
		for slot in 3:
			_buttons[action][slot].text = Settings.binding_name(slots[slot])


func _wait(action: String, slot: int) -> void:
	_refresh()
	_wait_action = action
	_wait_slot = slot
	_wait_left = WAIT_TIME
	_buttons[action][slot].text = "Press..."
	_status.text = ("Press a pad button, or move a stick or trigger." if slot == 2 else "Press a key or mouse button.") \
			+ "   Delete clears it, Esc cancels."
	_rest.clear()
	for d in Input.get_connected_joypads():
		for a in JOY_AXIS_MAX:
			_rest[Vector2i(d, a)] = Input.get_joy_axis(d, a)
	set_process(true)


func _stop() -> void:
	_wait_action = ""
	_wait_slot = -1
	set_process(false)


func _process(delta: float) -> void:
	_wait_left -= delta
	if _wait_left <= 0.0:
		_stop()
		_refresh()
		_status.text = "Nothing pressed; left as it was."


func _input(ev: InputEvent) -> void:
	if _wait_action == "":
		return
	if not (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventJoypadMotion):
		return
	# While waiting, nothing else gets the press (not even the menu).
	get_viewport().set_input_as_handled()
	var pad := _wait_slot == 2
	if ev is InputEventKey:
		if not ev.pressed or ev.echo:
			return
		if ev.physical_keycode == KEY_ESCAPE:
			_stop()
			_refresh()
			_status.text = "Left as it was."
			return
		if ev.physical_keycode in [KEY_DELETE, KEY_BACKSPACE]:
			_bind({})
		elif not pad and ev.physical_keycode != KEY_NONE:
			_bind({"key": ev.physical_keycode})
	elif ev is InputEventMouseButton:
		if ev.pressed and not pad:
			_bind({"mouse": ev.button_index})
	elif ev is InputEventJoypadButton:
		if ev.pressed and pad:
			_bind({"button": ev.button_index})
	elif pad:
		var rest: float = _rest.get(Vector2i(ev.device, ev.axis), 0.0)
		if absf(ev.axis_value) > AXIS_PRESS and absf(ev.axis_value - rest) > AXIS_PRESS:
			_bind({"axis": ev.axis, "dir": 1 if ev.axis_value > 0.0 else -1})


func _bind(b: Dictionary) -> void:
	var action := _wait_action
	var slot := _wait_slot
	_stop()
	var taken := Settings.set_binding(action, slot, b)
	_refresh()
	_buttons[action][slot].grab_focus()
	if b.is_empty():
		_status.text = "Cleared."
	elif taken != "" and taken != action:
		_status.text = "%s is now %s (taken off %s)." % [Settings.binding_name(b), _label(action), _label(taken)]
	else:
		_status.text = "%s is now %s." % [Settings.binding_name(b), _label(action)]


func _label(action: String) -> String:
	for entry in Settings.BINDABLE:
		if entry[0] == action:
			return entry[1]
	return action.capitalize()


func _on_back() -> void:
	_stop()
	Settings.save_settings()
	closed.emit()
	queue_free()
