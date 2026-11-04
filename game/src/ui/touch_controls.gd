extends Control
## On-screen controls for touch screens (Android, or --touch on the desktop):
## a move stick wherever the left thumb lands, drag anywhere else to look, and
## buttons that send the same input actions as the keyboard. Tapping a hotbar
## slot selects it. While a menu is open only a Back button (Esc) is shown.

const LOOK_SPEED := 0.006       # radians per pixel dragged
const STICK_RADIUS := 70.0
const STICK_ZONE := 0.4         # left share of the screen that starts the stick
const BUTTON_RADIUS := 40.0

var player: Node = null
var hud: Node = null
var pause_menu: Control = null

var _buttons: Array = []        # {action, label, pos (from the bottom right), r, toggle}
var _touch_button := {}         # touch index -> button
var _stick_index := -1
var _stick_center := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_index := -1
var _sprint_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # to hide itself under the pause menu
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Positions are offsets from the bottom-right corner (top-right for menus).
	_add("attack", "Hit", Vector2(-110, -150), 52.0)
	_add("use", "Use", Vector2(-230, -110))
	_add("jump", "Jump", Vector2(-90, -290))
	_add("interact", "Act", Vector2(-210, -240))
	_add("sprint", "Run", Vector2(-330, -70), BUTTON_RADIUS, true)
	_add("drop", "Drop", Vector2(-330, -190))
	_add("pause", "II", Vector2(-50, 90), 30.0, false, true)
	_add("inventory", "Bag", Vector2(-130, 90), 30.0, false, true)
	_add("craft", "Craft", Vector2(-210, 90), 30.0, false, true)
	_add("waypoint", "Mark", Vector2(-290, 90), 30.0, false, true)
	_add("sleep", "Sleep", Vector2(-370, 90), 30.0, false, true)


func _add(action: String, label: String, pos: Vector2, r := BUTTON_RADIUS, toggle := false, top := false) -> void:
	_buttons.append({"action": action, "label": label, "pos": pos, "r": r, "toggle": toggle, "top": top})


func _menu_open() -> bool:
	return player == null or player.ui_open or player.vitals.dead \
			or (pause_menu != null and pause_menu.visible)


func _center(b: Dictionary) -> Vector2:
	return Vector2(size.x + b.pos.x, (b.pos.y if b.top else size.y + b.pos.y))


func _button_at(p: Vector2) -> Variant:
	var menu := _menu_open()
	for b in _buttons:
		if menu and b.action != "pause":
			continue
		if p.distance_to(_center(b)) <= b.r + 10.0:
			return b
	return null


func _process(_delta: float) -> void:
	# A menu that opened mid-drag (or a death) lets go of everything held.
	var menu := _menu_open()
	if menu and (_stick_index >= 0 or _look_index >= 0 or not _touch_button.is_empty() or _sprint_on):
		_release_all()
	# The pause menu has its own Resume; nothing to show over it.
	visible = not (pause_menu != null and pause_menu.visible) and player != null and not player.vitals.dead
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event.index, event.position)
		else:
			_on_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_index:
			_set_stick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == _look_index:
			player._look(event.relative * LOOK_SPEED)
			get_viewport().set_input_as_handled()


func _on_press(index: int, p: Vector2) -> void:
	var b = _button_at(p)
	if b != null:
		if b.toggle:
			_sprint_on = not _sprint_on
			_send(b.action, _sprint_on)
		else:
			_touch_button[index] = b
			_send(b.action, true)
		get_viewport().set_input_as_handled()
		return
	if _menu_open():
		return  # menus take taps as clicks
	var slot: int = hud.hotbar_slot_at(p) if hud and hud.has_method("hotbar_slot_at") else -1
	if slot >= 0:
		Game.inventory.select(slot)
		get_viewport().set_input_as_handled()
		return
	if p.x < size.x * STICK_ZONE and _stick_index < 0:
		_stick_index = index
		_stick_center = p
		_set_stick(p)
	elif _look_index < 0:
		_look_index = index
	get_viewport().set_input_as_handled()


func _on_release(index: int) -> void:
	if _touch_button.has(index):
		_send(_touch_button[index].action, false)
		_touch_button.erase(index)
	if index == _stick_index:
		_stick_index = -1
		_set_stick(_stick_center)
		if _sprint_on:
			_sprint_on = false  # stopping ends a run
			_send("sprint", false)
	if index == _look_index:
		_look_index = -1


func _set_stick(p: Vector2) -> void:
	_stick_vec = ((p - _stick_center) / STICK_RADIUS).limit_length(1.0)
	_axis("move_left", "move_right", _stick_vec.x)
	_axis("move_forward", "move_back", _stick_vec.y)


func _axis(neg: String, pos: String, v: float) -> void:
	if v < -0.1:
		Input.action_press(neg, -v)
		Input.action_release(pos)
	elif v > 0.1:
		Input.action_press(pos, v)
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


func _send(action: String, pressed: bool) -> void:
	## As if the bound key went down or up: handlers see the event, and
	## Input.is_action_pressed() follows it.
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for i in _touch_button:
		_send(_touch_button[i].action, false)
	_touch_button.clear()
	if _sprint_on:
		_sprint_on = false
		_send("sprint", false)
	if _stick_index >= 0:
		_stick_index = -1
		_set_stick(_stick_center)
	_look_index = -1


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var menu := _menu_open()
	for b in _buttons:
		if menu and b.action != "pause":
			continue
		var c := _center(b)
		var held: bool = _touch_button.values().has(b) or (b.toggle and _sprint_on)
		draw_circle(c, b.r, Color(0.9, 0.85, 0.5, 0.35) if held else Color(0.05, 0.07, 0.05, 0.4))
		draw_arc(c, b.r, 0.0, TAU, 40, Color(0.9, 0.85, 0.6, 0.55), 2.0)
		var label: String = "Back" if menu and b.action == "pause" else b.label
		var fs := 16 if b.r >= BUTTON_RADIUS else 13
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	if _stick_index >= 0:
		draw_circle(_stick_center, STICK_RADIUS, Color(0.05, 0.07, 0.05, 0.3))
		draw_arc(_stick_center, STICK_RADIUS, 0.0, TAU, 48, Color(0.9, 0.85, 0.6, 0.4), 2.0)
		draw_circle(_stick_center + _stick_vec * STICK_RADIUS, 28.0, Color(0.9, 0.85, 0.6, 0.45))
