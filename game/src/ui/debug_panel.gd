extends Control
## Debug world panel (F1, or from the pause menu): set the time and day, start
## weather, give items, spawn creatures, pick the next fish to bite, give
## yourself health conditions,
## switch damage, needs and hostility off, and sleep or save on the spot. The
## game is paused while it is open.

signal closed

const Creature := preload("res://src/creatures/creature.gd")
const Weather := preload("res://src/world/weather.gd")
const Survival := preload("res://src/core/survival.gd")
const Fishing := preload("res://src/world/fishing.gd")

var world: Node = null
var _day: SpinBox
var _hour: HSlider
var _hour_label: Label
var _weather: OptionButton
var _item: OptionButton
var _count: SpinBox
var _creature: OptionButton
var _condition: OptionButton
var _fish: OptionButton
var _fishes: Array = []     # "" (random) then each fish species
var _note: Label
var _items: Array = []
var _species: Array = []
var _weathers: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.05, 0.96)
	sb.border_color = Color(0.55, 0.42, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(520, 0)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Debug"
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var t := _row(vb, "Time")
	t.add_child(_label("Day"))
	_day = SpinBox.new()
	_day.min_value = 1
	_day.max_value = 9999
	t.add_child(_day)
	_hour = HSlider.new()
	_hour.min_value = 0.0
	_hour.max_value = 23.75
	_hour.step = 0.25
	_hour.custom_minimum_size.x = 140
	_hour.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hour.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hour.value_changed.connect(func(_v): _hour_label.text = _clock_text(_hour.value))
	t.add_child(_hour)
	_hour_label = _label("")
	_hour_label.custom_minimum_size.x = 48
	t.add_child(_hour_label)
	_button(t, "Set", _set_time)

	var w := _row(vb, "Weather")
	_weather = OptionButton.new()
	_weathers = ["rain"] + Array(Weather.ALL_KINDS)
	for k in _weathers:
		_weather.add_item("Rain" if k == "rain" else Weather.NAMES[k])
	_weather.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.add_child(_weather)
	_button(w, "Start", _start_weather)
	_button(w, "Stop all", _stop_weather)

	var it := _row(vb, "Item")
	_item = OptionButton.new()
	_items = Items.ITEMS.keys()
	_items.sort_custom(func(a, b): return Items.item_name(a) < Items.item_name(b))
	for id in _items:
		_item.add_item(Items.item_name(id))
	_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	it.add_child(_item)
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 99
	it.add_child(_count)
	_button(it, "Give", _give)

	var cr := _row(vb, "Creature")
	_creature = OptionButton.new()
	_species = Creature.SPECIES.keys()
	for sp in _species:
		_creature.add_item(Creature.SPECIES[sp].name)
	_creature.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(_creature)
	_button(cr, "Spawn", _spawn)

	var fi := _row(vb, "Next fish")
	_fish = OptionButton.new()
	_fishes = [""] + Creature.SPECIES.keys().filter(func(sp): return Creature.SPECIES[sp].behavior == "fish")
	for sp in _fishes:
		_fish.add_item("Random" if sp == "" else Creature.SPECIES[sp].name)
	_fish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fi.add_child(_fish)
	_button(fi, "Set", _set_next_fish)

	var he := _row(vb, "Health")
	_condition = OptionButton.new()
	for c in Survival.DEBUG_CONDITIONS:
		_condition.add_item(c[1])
	_condition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	he.add_child(_condition)
	_button(he, "Give", _give_condition)
	_button(he, "Heal", _heal)

	var sw := _row(vb, "")
	_toggle(sw, "Damage", "damage")
	_toggle(sw, "Hunger, thirst, stamina", "needs")
	_toggle(sw, "Hostile animals", "hostile")

	var acts := _row(vb, "")
	_button(acts, "Sleep now", _sleep)
	_button(acts, "Save now", _save)
	_button(acts, "Close", close)

	_note = _label("Double-tap jump to fly: hold jump to rise, Ctrl to sink, Shift to go faster. F5 saves.")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.modulate = Color(1, 1, 1, 0.75)
	vb.add_child(_note)
	visible = false


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	if text != "":
		var l := _label(text)
		l.custom_minimum_size.x = 76
		h.add_child(l)
	return h


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _toggle(parent: Control, text: String, key: String) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = Game.cheats[key]
	c.toggled.connect(func(on): Game.set_cheat(key, on); _say("%s %s." % [text, "on" if on else "off"]))
	parent.add_child(c)


func _clock_text(h: float) -> String:
	return "%02d:%02d" % [int(h), int(fmod(h, 1.0) * 60.0)]


func _say(text: String) -> void:
	_note.text = text


func open() -> void:
	_day.value = Game.day() + 1
	_hour.value = snappedf(Game.clock() / 60.0, 0.25)
	_hour_label.text = _clock_text(_hour.value)
	visible = true
	get_tree().paused = true
	_day.get_line_edit().grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("debug_panel")):
		close()
		get_viewport().set_input_as_handled()


# --- Actions ---------------------------------------------------------------------

func _set_time() -> void:
	Game.time = (int(_day.value) - 1) * Game.DAY_LENGTH + _hour.value * 60.0 - Game.ARRIVAL_CLOCK
	_say("Day %d, %s." % [int(_day.value), _clock_text(_hour.value)])


func _start_weather() -> void:
	var k: String = _weathers[_weather.selected]
	if k == "rain":
		world.set_rain(true)
	else:
		world.weather.start(k)
	_say("%s started." % _weather.get_item_text(_weather.selected))


func _stop_weather() -> void:
	world.weather.stop()
	world.set_rain(false)
	_say("Weather cleared.")


func _give() -> void:
	var id: String = _items[_item.selected]
	var n := int(_count.value)
	if Items.def(id).get("carry", false) and world.has_method("add_carried"):
		# Too big for the bag (a soup pot, a fermentation vessel, a log): stood
		# in front of you, to carry (E) from there.
		var p: Node3D = world.player
		var fwd := -p.global_basis.z
		fwd.y = 0.0
		for i in n:
			var at: Vector3 = p.global_position + fwd.normalized() * (1.4 + 0.9 * i)
			world.add_carried(id, Vector3(at.x, world.floor_height(at + Vector3(0, 1, 0)), at.z), p.rotation.y)
		_say("Put %d %s in front of you." % [n, Items.item_name(id)])
		return
	var left: int = Game.inventory.add(id, n)
	if left > 0:
		world.spawn_pickup(id, left, world.player.global_position + Vector3(0, 0.5, 0))
	_say("Gave %d %s%s." % [n, Items.item_name(id), " (some on the ground)" if left > 0 else ""])


func _spawn() -> void:
	var sp: String = _species[_creature.selected]
	world.debug_spawn(sp)
	_say("Spawned a %s." % Creature.SPECIES[sp].name)


func _set_next_fish() -> void:
	## The next bite on any line will be this fish (not a nibble).
	var sp: String = _fishes[_fish.selected]
	Fishing.next_fish = sp
	_say("The next fish to bite will be a %s." % Creature.SPECIES[sp].name if sp != "" else "The next fish will be random.")


func _give_condition() -> void:
	var c: Array = Survival.DEBUG_CONDITIONS[_condition.selected]
	var v = world.player.vitals
	if not v.give_condition(c[0]):
		_say("You are dead.")
		return
	var notes := []
	if not Game.cheats.damage:
		notes.append("damage is off, so it can't kill you or drain your blood")
	if not Game.cheats.needs and c[0] in ["starving", "thirst", "low_protein", "low_greens", "low_starch"]:
		notes.append("needs are off, so it goes again at once")
	var note := "; ".join(notes)
	if note != "":
		note = " (%s%s.)" % [note.left(1).to_upper(), note.substr(1)]
	_say("%s given.%s" % [c[1], note])


func _sleep() -> void:
	close()
	world.sleep()


func _save() -> void:
	_say("Saved." if world.save_now() else "The game could not be saved!")


func _heal() -> void:
	world.player.vitals.cure_all()
	_say("Healed and fed.")
