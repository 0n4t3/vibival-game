extends Node
## Player settings, graphics quality tiers and input bindings.
## Bindings are created in code from DEFAULT_BINDINGS and whatever the player
## rebound (saved under [bindings]); touch controls feed the same actions.

signal changed

const PATH := "user://settings.cfg"

enum Quality { LOW, MEDIUM, HIGH }
const QUALITY_NAMES := ["Low", "Medium", "High"]
const VIEW_DISTANCES := [80.0, 128.0, 192.0, 256.0]
enum MusicFrequency { CONSTANT, COMMON, RARE, OFF }
const MUSIC_FREQUENCY_NAMES := ["Constant", "Common", "Rare", "Off"]

var quality: int = Quality.MEDIUM
var view_distance: float = 128.0
var mouse_sensitivity: float = 0.0025
var fov: float = 75.0
var volume: float = 0.8
var music_volume: float = 0.6
var music_frequency: int = MusicFrequency.RARE
var fullscreen: bool = false
var render_scale: float = 1.0
var touch := false  # on-screen touch controls (mobile, or --touch to try them)
var using_pad := false  # the last input came from a gamepad (for naming buttons)

## The actions the Controls screen lists, in its order, with their names
## there. (debug_panel and fly_down keep their keys.)
const BINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"],
	["move_left", "Move left"], ["move_right", "Move right"],
	["look_up", "Look up"], ["look_down", "Look down"],
	["look_left", "Look left"], ["look_right", "Look right"],
	["jump", "Jump"], ["sprint", "Sprint"],
	["attack", "Attack"], ["use", "Use"],
	["interact", "Interact"], ["drop", "Drop"],
	["craft", "Kneel / craft"], ["inventory", "Inventory"],
	["sleep", "Sleep"], ["waypoint", "Waypoint"],
	["slot_next", "Next slot"], ["slot_prev", "Previous slot"],
	["slot_1", "Slot 1"], ["slot_2", "Slot 2"], ["slot_3", "Slot 3"],
	["slot_4", "Slot 4"], ["slot_5", "Slot 5"], ["slot_6", "Slot 6"],
	["pause", "Pause (Esc always)"], ["quick_save", "Quick save (debug)"],
]
## Each action's two keyboard/mouse slots and its gamepad slot. A binding is
## {"key": physical keycode}, {"mouse": button}, {"button": joy button} or
## {"axis": joy axis, "dir": -1 or 1}; {} is unbound.
const DEFAULT_BINDINGS := {
	"move_forward": [{"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "dir": -1}],
	"move_back": [{"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "dir": 1}],
	"move_left": [{"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "dir": -1}],
	"move_right": [{"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "dir": 1}],
	"look_up": [{}, {}, {"axis": JOY_AXIS_RIGHT_Y, "dir": -1}],
	"look_down": [{}, {}, {"axis": JOY_AXIS_RIGHT_Y, "dir": 1}],
	"look_left": [{}, {}, {"axis": JOY_AXIS_RIGHT_X, "dir": -1}],
	"look_right": [{}, {}, {"axis": JOY_AXIS_RIGHT_X, "dir": 1}],
	"jump": [{"key": KEY_SPACE}, {}, {"button": JOY_BUTTON_A}],
	"sprint": [{"key": KEY_SHIFT}, {}, {"button": JOY_BUTTON_LEFT_STICK}],
	"attack": [{"mouse": MOUSE_BUTTON_LEFT}, {}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
	"use": [{"mouse": MOUSE_BUTTON_RIGHT}, {}, {"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
	"interact": [{"key": KEY_E}, {}, {"button": JOY_BUTTON_X}],
	"drop": [{"key": KEY_Q}, {}, {"button": JOY_BUTTON_B}],
	"craft": [{"key": KEY_C}, {}, {"button": JOY_BUTTON_DPAD_DOWN}],
	"inventory": [{"key": KEY_TAB}, {"key": KEY_I}, {"button": JOY_BUTTON_Y}],
	"sleep": [{"key": KEY_Z}, {}, {"button": JOY_BUTTON_BACK}],
	"waypoint": [{"key": KEY_M}, {}, {"button": JOY_BUTTON_DPAD_UP}],
	"slot_next": [{"mouse": MOUSE_BUTTON_WHEEL_DOWN}, {}, {"button": JOY_BUTTON_RIGHT_SHOULDER}],
	"slot_prev": [{"mouse": MOUSE_BUTTON_WHEEL_UP}, {}, {"button": JOY_BUTTON_LEFT_SHOULDER}],
	"slot_1": [{"key": KEY_1}, {}, {}],
	"slot_2": [{"key": KEY_2}, {}, {}],
	"slot_3": [{"key": KEY_3}, {}, {}],
	"slot_4": [{"key": KEY_4}, {}, {}],
	"slot_5": [{"key": KEY_5}, {}, {}],
	"slot_6": [{"key": KEY_6}, {}, {}],
	"pause": [{}, {}, {"button": JOY_BUTTON_START}],
	"quick_save": [{"key": KEY_F5}, {}, {}],
	"debug_panel": [{"key": KEY_F1}, {}, {}],
	"fly_down": [{"key": KEY_CTRL}, {}, {}],
}
const TOUCH_NAMES := {"craft": "Craft", "use": "Use", "interact": "Act", "attack": "Hit", "drop": "Drop",
		"jump": "Jump", "sprint": "Run", "inventory": "Bag", "pause": "II", "waypoint": "Mark", "sleep": "Sleep"}
const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "left stick click", JOY_BUTTON_RIGHT_STICK: "right stick click",
	JOY_BUTTON_LEFT_SHOULDER: "left bumper", JOY_BUTTON_RIGHT_SHOULDER: "right bumper",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const PAD_AXIS_NAMES := {
	JOY_AXIS_LEFT_X: ["left stick left", "left stick right"], JOY_AXIS_LEFT_Y: ["left stick up", "left stick down"],
	JOY_AXIS_RIGHT_X: ["right stick left", "right stick right"], JOY_AXIS_RIGHT_Y: ["right stick up", "right stick down"],
	JOY_AXIS_TRIGGER_LEFT: ["left trigger", "left trigger"], JOY_AXIS_TRIGGER_RIGHT: ["right trigger", "right trigger"],
}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "left-click", MOUSE_BUTTON_RIGHT: "right-click", MOUSE_BUTTON_MIDDLE: "middle-click",
		MOUSE_BUTTON_WHEEL_UP: "wheel up", MOUSE_BUTTON_WHEEL_DOWN: "wheel down"}

var bindings := {}  # action -> [keyboard/mouse, keyboard/mouse, gamepad], as in DEFAULT_BINDINGS

func _ready() -> void:
	touch = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
	if touch and not OS.has_feature("mobile"):
		Input.emulate_touch_from_mouse = true
	_setup_input()
	load_settings()
	apply()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


func button_name(action: String) -> String:
	## The button for an action on whatever is being used now: "C" on a
	## keyboard, "D-pad down" on a gamepad, "Craft" on a touch screen.
	if touch:
		return TOUCH_NAMES.get(action, action.capitalize())
	var slots: Array = bindings.get(action, [])
	for i in ([2, 0, 1] if using_pad else [0, 1, 2]):
		if i < slots.size() and not slots[i].is_empty():
			return binding_name(slots[i])
	return action.capitalize()


func hint(text: String) -> String:
	## A prompt's key hints ("[E]", "[C]", "[Q]", "[Right-click]") as the
	## buttons now bound on whatever is being used.
	for pair in [["[E]", "interact"], ["[C]", "craft"], ["[Q]", "drop"], ["[Right-click]", "use"]]:
		if text.contains(pair[0]):
			text = text.replace(pair[0], "[%s]" % _cap(button_name(pair[1])))
	if text.contains("Q puts it down"):
		text = text.replace("Q puts it down", "%s puts it down" % _cap(button_name("drop")))
	return text


func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


func binding_name(b: Dictionary) -> String:
	if b.is_empty():
		return "-"
	if b.has("key"):
		# Named as on a US layout: the web and headless display servers can't
		# map physical keys to the layout's.
		return OS.get_keycode_string(b.key)
	if b.has("mouse"):
		return MOUSE_NAMES.get(int(b.mouse), "mouse %d" % b.mouse)
	if b.has("button"):
		return PAD_BUTTON_NAMES.get(int(b.button), "button %d" % b.button)
	var names: Array = PAD_AXIS_NAMES.get(int(b.axis), ["axis %d -" % b.axis, "axis %d +" % b.axis])
	return names[1] if b.dir > 0 else names[0]

# --- Quality-derived values -------------------------------------------------

func detail() -> int:
	## Mesh detail level passed to procedural builders (0..2).
	return quality


func shadows() -> bool:
	return quality >= Quality.MEDIUM


func vegetation_density() -> float:
	return [0.45, 0.75, 1.0][quality]


func terrain_step() -> int:
	## Metres between terrain vertices.
	return 2 if quality == Quality.LOW else 1


# --- Persistence ------------------------------------------------------------

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		# First run: lighter defaults where the GPU is likely weaker.
		if OS.has_feature("mobile"):
			quality = Quality.LOW
			view_distance = 80.0
		elif OS.has_feature("web"):
			quality = Quality.LOW
			view_distance = 128.0
		return
	quality = clampi(cfg.get_value("graphics", "quality", quality), 0, 2)
	view_distance = cfg.get_value("graphics", "view_distance", view_distance)
	render_scale = clampf(cfg.get_value("graphics", "render_scale", render_scale), 0.5, 1.0)
	fullscreen = cfg.get_value("graphics", "fullscreen", fullscreen)
	fov = cfg.get_value("controls", "fov", fov)
	mouse_sensitivity = cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
	volume = cfg.get_value("audio", "volume", volume)
	music_volume = clampf(cfg.get_value("audio", "music_volume", music_volume), 0.0, 1.0)
	music_frequency = clampi(cfg.get_value("audio", "music_frequency", music_frequency), 0, MusicFrequency.OFF)
	for action in DEFAULT_BINDINGS:
		var saved = cfg.get_value("bindings", action, null)
		if saved is Array and saved.size() == 3 and saved.all(func(b): return b is Dictionary):
			bindings[action] = saved
	apply_bindings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "view_distance", view_distance)
	cfg.set_value("graphics", "render_scale", render_scale)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("controls", "fov", fov)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "music_frequency", music_frequency)
	for action in bindings:
		if bindings[action] != DEFAULT_BINDINGS[action]:
			cfg.set_value("bindings", action, bindings[action])
	cfg.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	var root := get_tree().root
	root.scaling_3d_scale = render_scale
	if DisplayServer.get_name() != "headless":
		# Phones always fill the screen: windowed mode would bring back the system bars.
		var full := fullscreen or OS.has_feature("mobile")
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


# --- Input ------------------------------------------------------------------

func _setup_input() -> void:
	bindings = DEFAULT_BINDINGS.duplicate(true)
	apply_bindings()
	# Menus answer every pad, whatever number it was given.
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			for ev in InputMap.action_get_events(action):
				if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
					InputMap.action_erase_event(action, ev)
					var all: InputEvent = ev.duplicate()
					all.device = -1
					InputMap.action_add_event(action, all)


func apply_bindings() -> void:
	## Rebuilds the input map from bindings. Every event matches any device:
	## pads are numbered differently on each platform (and a phone may give
	## the first pad a number other than 0).
	for action in DEFAULT_BINDINGS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for b: Dictionary in bindings.get(action, []):
			for ev in _events(b):
				InputMap.action_add_event(action, ev)
	# Esc always pauses (it cancels on the Controls screen, so it can't be
	# rebound), and Android's back button works as Esc. (Its go-back request
	# comes on both the press and the release, which would open and shut the
	# pause menu.)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.device = -1
	InputMap.action_add_event("pause", esc)
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	back.device = -1
	InputMap.action_add_event("pause", back)


func _events(b: Dictionary) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if b.has("key"):
		var ev := InputEventKey.new()
		ev.physical_keycode = b.key
		out.append(ev)
	elif b.has("mouse"):
		var ev := InputEventMouseButton.new()
		ev.button_index = b.mouse
		out.append(ev)
	elif b.has("button"):
		var ev := InputEventJoypadButton.new()
		ev.button_index = b.button
		out.append(ev)
	elif b.has("axis"):
		var ev := InputEventJoypadMotion.new()
		ev.axis = b.axis
		ev.axis_value = signf(b.dir)
		out.append(ev)
		# Android also sends the triggers as buttons (L2 15, R2 16), and
		# numbers the trigger axes differently from pad to pad.
		if OS.has_feature("android") and int(b.axis) in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			var btn := InputEventJoypadButton.new()
			btn.button_index = 15 if int(b.axis) == JOY_AXIS_TRIGGER_LEFT else 16
			out.append(btn)
	for ev in out:
		ev.device = -1
	return out


func set_binding(action: String, slot: int, b: Dictionary) -> String:
	## Binds an action's slot, taking the binding off any other action that
	## had it. Returns the name of that other action, or "".
	var taken := ""
	if not b.is_empty():
		for other in bindings:
			var slots: Array = bindings[other]
			for i in slots.size():
				if (other != action or i != slot) and slots[i] == b:
					slots[i] = {}
					taken = other
	bindings[action][slot] = b
	apply_bindings()
	return taken


func reset_bindings() -> void:
	bindings = DEFAULT_BINDINGS.duplicate(true)
	apply_bindings()
