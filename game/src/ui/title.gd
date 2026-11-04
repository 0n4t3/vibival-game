extends Control
## Title screen with drifting spores over a dark swamp gradient. Worlds are
## named: start a new one, continue the last one played, or pick one to load.
## Load world also exports a world to a .vibival file and imports one, through
## the system's file picker (on Linux the desktop portal, which hands the game
## only the file chosen, so the flatpak needs no access to your files; on
## Android the Storage Access Framework; on the web a download or upload).

const SettingsPanel := preload("res://src/ui/settings_panel.gd")

var _box: VBoxContainer
var _center: CenterContainer
var _panel: Control = null     # the new-world, load-world or settings panel on show
var _spores: Array = []
var _rng := RandomNumberGenerator.new()
var _status: Label = null      # what exporting or importing did, on the load-world panel
var _web_pick: JavaScriptObject = null  # keeps the web upload's callback alive


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 70:
		_spores.append([Vector2(_rng.randf(), _rng.randf()), _rng.randf_range(0.004, 0.02), _rng.randf_range(1.0, 3.0), _rng.randf() * TAU])

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(340, 0)
	_box.add_theme_constant_override("separation", 10)
	_center.add_child(_box)

	var title := Label.new()
	title.text = "VIBIVAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.78, 0.85, 0.55))
	_box.add_child(title)
	var sub := Label.new()
	sub.text = "Survive the coal swamps, 307 million years ago"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.7)
	_box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 24
	_box.add_child(spacer)

	_build_menu()
	_focus_first.call_deferred()
	if Game.dev.has("load-worlds"):
		_open_load_world.call_deferred()

	var ver := Label.new()
	ver.text = "Prototype  |  Godot %s" % Engine.get_version_info().string
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 12
	ver.offset_top = -28
	ver.modulate = Color(1, 1, 1, 0.4)
	add_child(ver)


func _build_menu() -> void:
	for i in range(_box.get_child_count() - 1, 2, -1):
		_box.get_child(i).free()
	var latest := Game.latest_world()
	if not latest.is_empty():
		_add("Continue: %s (Day %d)" % [latest.name, latest.day], func(): Game.load_game(latest.id))
	_add("New world", _open_new_world)
	_add("Load world", _open_load_world)
	_add("Settings", _open_settings)
	if not OS.has_feature("web"):
		_add("Quit", func(): get_tree().quit())


func _add(text: String, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(cb)
	(parent if parent else _box).add_child(b)
	return b


func _show_panel(p: Control) -> void:
	_box.visible = false
	_panel = p
	_center.add_child(p)


func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	_box.visible = true
	_focus_first()


func _framed(title_text: String) -> Array:
	## A titled panel; returns [panel, its content box].
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.05, 0.96)
	sb.border_color = Color(0.4, 0.48, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(460, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	p.add_child(vb)
	var l := Label.new()
	l.text = title_text
	l.add_theme_font_size_override("font_size", 24)
	vb.add_child(l)
	return [p, vb]


# --- New world -------------------------------------------------------------------

func _open_new_world() -> void:
	var f := _framed("New world")
	var vb: VBoxContainer = f[1]
	var l := Label.new()
	l.text = "Name your world"
	vb.add_child(l)
	var name_edit := LineEdit.new()
	name_edit.text = "World %d" % (Game.list_worlds().size() + 1)
	name_edit.max_length = 40
	name_edit.select_all_on_focus = true
	vb.add_child(name_edit)
	var debug := CheckBox.new()
	debug.text = "Debug world"
	debug.tooltip_text = "Sleep and save at any time, fly (double-tap jump), and F1 opens a panel to set the time,\nstart weather, spawn items and creatures, and switch off damage, needs or hostile animals."
	vb.add_child(debug)
	var start := func(tutorial: bool): Game.new_world(name_edit.text, tutorial, debug.button_pressed)
	_add("Start in the lab (tutorial)", start.bind(true), vb)
	_add("Start in the swamp (skip tutorial)", start.bind(false), vb)
	name_edit.text_submitted.connect(func(_t): start.call(true))
	_add("Back", _close_panel, vb)
	_show_panel(f[0])
	name_edit.grab_focus.call_deferred()


# --- Load world ------------------------------------------------------------------

func _open_load_world() -> void:
	var f := _framed("Load world")
	var vb: VBoxContainer = f[1]
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var first: Button = null
	for w in Game.list_worlds():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var when := Time.get_datetime_string_from_unix_time(int(w.played) + _tz_offset(), true)
		info.text = "%s%s\n%s  -  last played %s" % [w.name, "  [debug]" if w.get("debug", false) else "",
				"Day %d" % w.day if w.saved else "No save yet", when.substr(0, 16)]
		info.clip_text = true
		row.add_child(info)
		var play := Button.new()
		play.text = "Load" if w.saved else "Start"
		play.tooltip_text = "Continue from this world's save." if w.saved else "Nothing saved yet: start this world from the beginning."
		play.custom_minimum_size = Vector2(80, 40)
		play.pressed.connect(_play_world.bind(w))
		row.add_child(play)
		var del := Button.new()
		del.text = "Delete"
		del.custom_minimum_size = Vector2(80, 40)
		del.pressed.connect(_delete_world.bind(w, del))
		var exp := Button.new()
		exp.text = "Export"
		exp.custom_minimum_size = Vector2(80, 40)
		exp.pressed.connect(_export_world.bind(w))
		row.add_child(exp)
		row.add_child(del)
		if first == null:
			first = play
	if first == null:
		var none := Label.new()
		none.text = "No worlds yet."
		list.add_child(none)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(1, 1, 1, 0.8)
	_status.visible = false
	vb.add_child(_status)
	_add("Import world", _import_world, vb)
	var back := _add("Back", _close_panel, vb)
	_show_panel(f[0])
	(first if first else back).grab_focus.call_deferred()


func _say(text: String) -> void:
	if is_instance_valid(_status):
		_status.text = text
		_status.visible = true


func _export_world(w: Dictionary) -> void:
	var text := Game.export_world(w.id)
	if text == "":
		_say("Couldn't read that world.")
		return
	var file := "%s.vibival" % w.id
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file, "application/json")
		_say("%s is downloading as %s." % [w.name, file])
		return
	_pick_file(true, file, func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			_say("Couldn't write %s." % path.get_file())
			return
		f.store_string(text)
		f.close()
		_say("Exported %s." % w.name))


func _import_world() -> void:
	if OS.has_feature("web"):
		_web_upload(_imported)
		return
	_pick_file(false, "", func(path: String):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_say("Couldn't open that file.")
			return
		_imported(f.get_as_text()))


func _imported(text: String) -> void:
	var got := Game.import_world(text)
	if got.has("error"):
		_say(got.error)
		return
	_panel.queue_free()
	_panel = null
	_build_menu()
	_open_load_world()
	_say("Imported %s." % got.name)


func _pick_file(save: bool, file: String, done: Callable) -> void:
	## The system's file picker, calling done(path) with the file chosen. Where
	## there is none, Godot's own file dialog.
	var title := "Export world" if save else "Import world"
	# Android matches filters by MIME type, and has none for .vibival.
	var filters := PackedStringArray() if OS.has_feature("android") else PackedStringArray(["*.vibival;Vibival world"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		var mode := DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if save else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
		DisplayServer.file_dialog_show(title, "", file, false, mode, filters, func(ok: bool, paths: PackedStringArray, _filter: int):
			if ok and not paths.is_empty():
				done.call_deferred(paths[0]))
		return
	var fd := FileDialog.new()
	fd.title = title
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = filters
	fd.current_file = file
	fd.file_selected.connect(func(path: String): done.call(path); fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.7)


func _web_upload(done: Callable) -> void:
	## Web: the browser's file upload, calling done(text) with the file's text.
	JavaScriptBridge.eval("""
		window.vibivalPick = function (cb) {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.vibival,application/json';
			input.onchange = function () {
				if (input.files.length) input.files[0].text().then(function (t) { cb(t); });
			};
			input.click();
		};
	""", true)
	_web_pick = JavaScriptBridge.create_callback(func(args: Array): done.call(String(args[0])))
	JavaScriptBridge.get_interface("window").vibivalPick(_web_pick)


func _play_world(w: Dictionary) -> void:
	if w.saved:
		Game.load_game(w.id)
	else:
		Game.use_world(w.id)
		Game.start_new_game(false)


func _delete_world(w: Dictionary, btn: Button) -> void:
	## Deleting asks twice: the first press only arms the button.
	if btn.text != "Sure?":
		btn.text = "Sure?"
		btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		return
	Game.delete_world(w.id)
	# Rebuild the menu too: Continue may have pointed at the deleted world.
	_panel.queue_free()
	_panel = null
	_build_menu()
	_open_load_world()


func _tz_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# --- Settings --------------------------------------------------------------------

func _open_settings() -> void:
	var p := SettingsPanel.new()
	p.closed.connect(func(): _panel = null; _box.visible = true; _focus_first())
	_show_panel(p)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s := size
	var bands := 24
	for i in bands:
		var t := float(i) / bands
		var c := Color(0.02, 0.04, 0.03).lerp(Color(0.10, 0.16, 0.08), pow(t, 1.5))
		draw_rect(Rect2(0, s.y * t, s.x, s.y / bands + 1), c)
	# Silhouetted scale-tree trunks.
	for i in 9:
		var x := s.x * (0.05 + i * 0.115) + sin(i * 7.3) * 30.0
		var w := 10.0 + (i % 3) * 6.0
		draw_rect(Rect2(x, 0, w, s.y), Color(0.01, 0.02, 0.015, 0.75))
	var t := Time.get_ticks_msec() * 0.001
	for sp in _spores:
		var p: Vector2 = sp[0]
		var pos := Vector2(fposmod(p.x + sin(t * 0.3 + sp[3]) * 0.02, 1.0), fposmod(p.y - t * sp[1], 1.0)) * s
		draw_circle(pos, sp[2], Color(0.85, 0.9, 0.55, 0.35))


func _focus_first() -> void:
	if is_inside_tree() and _box.visible:
		_box.get_child(3).grab_focus()
