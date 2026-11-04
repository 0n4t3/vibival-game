extends Node
## Player settings, graphics quality tiers and input bindings.
## Bindings are created in code so they can be rebound later and so touch
## controls on Android can feed the same actions.

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

## What each device calls an action's button, for messages (button_name).
const KEY_NAMES := {"craft": "C", "use": "right-click", "interact": "E", "attack": "left-click", "drop": "Q"}
const PAD_NAMES := {"craft": "D-pad down", "use": "the left trigger", "interact": "X", "attack": "the right trigger", "drop": "B"}
const TOUCH_NAMES := {"craft": "Craft", "use": "Use", "interact": "Act", "attack": "Hit", "drop": "Drop"}


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
	if using_pad:
		return PAD_NAMES.get(action, action.capitalize())
	return KEY_NAMES.get(action, action.capitalize())


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
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"inventory": [KEY_TAB, KEY_I],
		"pause": [KEY_ESCAPE],
		"drop": [KEY_Q],
		"sleep": [KEY_Z],
		"waypoint": [KEY_M],
		"craft": [KEY_C],
		"quick_save": [KEY_F5],
		"debug_panel": [KEY_F1],
		"fly_down": [KEY_CTRL],
		"slot_1": [KEY_1], "slot_2": [KEY_2], "slot_3": [KEY_3],
		"slot_4": [KEY_4], "slot_5": [KEY_5], "slot_6": [KEY_6],
	}
	for action in keys:
		_ensure(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Android's back button works as Esc. (Its go-back request comes on both
	# the press and the release, which would open and shut the pause menu.)
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	InputMap.action_add_event("pause", back)

	var mouse := {
		"attack": MOUSE_BUTTON_LEFT,
		"use": MOUSE_BUTTON_RIGHT,
		"slot_next": MOUSE_BUTTON_WHEEL_DOWN,
		"slot_prev": MOUSE_BUTTON_WHEEL_UP,
	}
	for action in mouse:
		_ensure(action)
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse[action]
		InputMap.action_add_event(action, ev)

	var pad_buttons := {
		"jump": JOY_BUTTON_A,
		"interact": JOY_BUTTON_X,
		"inventory": JOY_BUTTON_Y,
		"pause": JOY_BUTTON_START,
		"sprint": JOY_BUTTON_LEFT_STICK,
		"slot_next": JOY_BUTTON_RIGHT_SHOULDER,
		"slot_prev": JOY_BUTTON_LEFT_SHOULDER,
		"drop": JOY_BUTTON_B,
		"sleep": JOY_BUTTON_BACK,
		"craft": JOY_BUTTON_DPAD_DOWN,
	}
	for action in pad_buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pad_buttons[action]
		InputMap.action_add_event(action, ev)

	var pad_axes := {
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
		"move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
		"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0],
		"look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"attack": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
		"use": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	for action in pad_axes:
		_ensure(action)
		var ev := InputEventJoypadMotion.new()
		ev.axis = pad_axes[action][0]
		ev.axis_value = pad_axes[action][1]
		InputMap.action_add_event(action, ev)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
