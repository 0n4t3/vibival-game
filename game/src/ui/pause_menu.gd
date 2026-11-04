extends Control
## Pause overlay. The scene tree is paused while it is open.

signal resumed

const SettingsPanel := preload("res://src/ui/settings_panel.gd")

var _box: VBoxContainer
var _center: CenterContainer
var world: Node = null   # the scene it pauses
var _save_btns: Array[Button] = []
var _save_now_btn: Button
var _debug_btn: Button
var _quit_btn: Button
var _note: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(280, 0)
	_box.add_theme_constant_override("separation", 10)
	_center.add_child(_box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	_box.add_child(title)
	_add("Resume", resume)
	_add("Settings", _open_settings)
	_save_now_btn = _add("Save now (debug)", _save_now)
	_debug_btn = _add("Debug panel (F1)", func(): resume(); world.open_debug())
	_save_btns.append(_add("Save and quit to title", _save_and_quit.bind(false)))
	if not OS.has_feature("web"):
		_save_btns.append(_add("Save and quit game", _save_and_quit.bind(true)))
	_quit_btn = _add("Quit to title", func(): Game.goto("title"))
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 13)
	_note.modulate = Color(1, 1, 1, 0.7)
	_box.add_child(_note)
	visible = false


func _add(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _world() -> Node:
	return world if world and world.has_method("save_suspend") else null


func _refresh_save() -> void:
	## Saving on exit is offered in the swamp only, and not in the middle of danger.
	var w := _world()
	var blocker: String = w.suspend_blocker() if w else ""
	for b in _save_btns:
		b.visible = w != null
		b.disabled = blocker != ""
	_save_now_btn.visible = w != null and Game.debug
	_debug_btn.visible = w != null and Game.debug
	_save_now_btn.disabled = blocker != ""
	_quit_btn.text = "Quit to title without saving" if w else "Quit to title"
	_note.visible = w != null
	if blocker != "":
		_note.text = blocker
	elif Game.debug:
		_note.text = "Debug world: \"Save now\" overwrites your camp save with this moment (F5 does the same in game)."
	else:
		_note.text = "Saving here lets you continue from this spot once. Your camp save is kept: die later and you wake at your last camp."


func _save_and_quit(quit_game: bool) -> void:
	var w := _world()
	if w == null or not w.save_suspend():
		_note.text = "The game could not be saved!"
		return
	if quit_game:
		get_tree().quit()
	else:
		Game.goto("title")


func _save_now() -> void:
	var w := _world()
	if w and w.save_now():
		_note.text = "Saved. Your camp save is now this moment."
	else:
		_note.text = "The game could not be saved!"


func open() -> void:
	visible = true
	_box.visible = true
	_refresh_save()
	get_tree().paused = true
	_box.get_child(1).grab_focus()


func resume() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _open_settings() -> void:
	_box.visible = false
	var p := SettingsPanel.new()
	p.closed.connect(func(): _box.visible = true; _refresh_save(); _box.get_child(1).grab_focus())
	_center.add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and _box.visible:
		resume()
		get_viewport().set_input_as_handled()
