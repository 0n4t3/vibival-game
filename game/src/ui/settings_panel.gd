extends PanelContainer
## Settings editor shared by the title screen and the pause menu.

signal closed

const SOURCE_URL := "https://github.com/0n4t3/vibival-game"


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.05, 0.96)
	sb.border_color = Color(0.4, 0.48, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(460, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)

	var q := OptionButton.new()
	for n in Settings.QUALITY_NAMES:
		q.add_item(n)
	q.selected = Settings.quality
	q.item_selected.connect(func(i): Settings.quality = i)
	_row(grid, "Graphics quality", q)

	var vd := OptionButton.new()
	for d in Settings.VIEW_DISTANCES:
		vd.add_item("%d m" % d)
	vd.selected = maxi(Settings.VIEW_DISTANCES.find(Settings.view_distance), 0)
	vd.item_selected.connect(func(i): Settings.view_distance = Settings.VIEW_DISTANCES[i])
	_row(grid, "View distance", vd)

	_row(grid, "Render scale", _slider(0.5, 1.0, 0.05, Settings.render_scale, func(v): Settings.render_scale = v))
	_row(grid, "Field of view", _slider(60.0, 100.0, 1.0, Settings.fov, func(v): Settings.fov = v))
	_row(grid, "Mouse sensitivity", _slider(0.0005, 0.006, 0.0001, Settings.mouse_sensitivity, func(v): Settings.mouse_sensitivity = v))
	_row(grid, "Master volume", _slider(0.0, 1.0, 0.05, Settings.volume, func(v): Settings.volume = v; Settings.apply()))
	_row(grid, "Music volume", _slider(0.0, 1.0, 0.05, Settings.music_volume, func(v): Settings.music_volume = v; Settings.apply()))

	var mf := OptionButton.new()
	for n in Settings.MUSIC_FREQUENCY_NAMES:
		mf.add_item(n)
	mf.selected = Settings.music_frequency
	mf.item_selected.connect(func(i): Settings.music_frequency = i; Settings.apply())
	_row(grid, "Music", mf)

	if not OS.has_feature("mobile"):
		var fs := CheckBox.new()
		fs.button_pressed = Settings.fullscreen
		fs.toggled.connect(func(on): Settings.fullscreen = on)
		_row(grid, "Fullscreen", fs)

	var note := Label.new()
	note.text = "Quality and view distance changes apply fully to newly loaded areas."
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(note)

	var packs := Label.new()
	packs.text = "Resource packs: %s" % (", ".join(Assets.loaded_packs) if not Assets.loaded_packs.is_empty() else "none")
	packs.add_theme_font_size_override("font_size", 12)
	packs.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(packs)

	var source := LinkButton.new()
	source.text = "Source code"
	source.uri = SOURCE_URL
	source.add_theme_font_size_override("font_size", 12)
	vb.add_child(source)

	var done := Button.new()
	done.text = "Done"
	done.pressed.connect(_on_done)
	vb.add_child(done)
	q.grab_focus.call_deferred()


func _row(grid: GridContainer, label: String, control: Control) -> void:
	var l := Label.new()
	l.text = label
	grid.add_child(l)
	control.custom_minimum_size.x = 200
	grid.add_child(control)


func _slider(lo: float, hi: float, step: float, value: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.value_changed.connect(cb)
	return s


func _on_done() -> void:
	Settings.save_settings()
	Settings.apply()
	closed.emit()
	queue_free()
