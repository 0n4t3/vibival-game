extends CanvasLayer
## In-game overlay: vitals, hotbar, crosshair, prompts, messages, tutorial
## hints, objective list, damage flash, screen fades and the death screen.

signal title_requested
signal load_requested

const Icons := preload("res://src/ui/icons.gd")
const Inventory := preload("res://src/core/inventory.gd")

var player: Node = null
var show_vitals := true
var objective_lines: PackedStringArray = []

var _canvas: Control
var _prompt: Label
var _tip_panel: PanelContainer
var _tip: Label
var _messages: VBoxContainer
var _hint_panel: PanelContainer
var _hint: Label
var _objectives: Label
var _clock: Label
var _flash: ColorRect
var _blind: ColorRect     # your sight going dark at the last stage of any condition
var _fade: ColorRect
var _death: Control
var _flash_a := 0.0


func _ready() -> void:
	layer = 1
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)

	_flash = ColorRect.new()
	_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_blind = ColorRect.new()
	_blind.color = Color(0, 0, 0, 0)
	_blind.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blind)
	move_child(_blind, 0)  # under the HUD: the world goes dark, not the bars

	_prompt = _label(18, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -150
	_prompt.offset_bottom = -120
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	add_child(_prompt)

	# A small panel above the prompt about what you look at (a soup pot's contents).
	_tip_panel = PanelContainer.new()
	_tip_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tip_panel.offset_left = 0
	_tip_panel.offset_right = 0
	_tip_panel.offset_bottom = -156
	_tip_panel.offset_top = -156
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.05, 0.06, 0.04, 0.72)
	tsb.border_color = Color(0.70, 0.55, 0.32, 0.8)
	tsb.set_border_width_all(1)
	tsb.set_corner_radius_all(4)
	tsb.set_content_margin_all(8)
	_tip_panel.add_theme_stylebox_override("panel", tsb)
	_tip = _label(16, HORIZONTAL_ALIGNMENT_CENTER)
	_tip_panel.add_child(_tip)
	_tip_panel.visible = false
	add_child(_tip_panel)

	_messages = VBoxContainer.new()
	_messages.position = Vector2(20, 20)
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_messages)

	_hint_panel = PanelContainer.new()
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint_panel.offset_top = 16
	_hint_panel.offset_left = -330
	_hint_panel.offset_right = 330
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.05, 0.78)
	sb.border_color = Color(0.55, 0.65, 0.35, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	_hint_panel.add_theme_stylebox_override("panel", sb)
	_hint = _label(17, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint)
	_hint_panel.visible = false
	add_child(_hint_panel)

	_objectives = _label(15, HORIZONTAL_ALIGNMENT_RIGHT)
	_objectives.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_objectives.offset_left = -360
	_objectives.offset_right = -20
	_objectives.offset_top = 50
	add_child(_objectives)

	_clock = _label(15, HORIZONTAL_ALIGNMENT_RIGHT)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_clock.offset_left = -300
	_clock.offset_right = -20
	_clock.offset_top = 16
	add_child(_clock)

	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	Game.message.connect(show_message)
	Game.inventory.changed.connect(_canvas.queue_redraw)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func bind_player(p: Node) -> void:
	player = p
	p.hurt_flash.connect(func(amount): _flash_a = clampf(_flash_a + amount * 0.03, 0.0, 0.55))


func show_message(text: String) -> void:
	var l := _label(16, HORIZONTAL_ALIGNMENT_LEFT)
	l.text = text
	_messages.add_child(l)
	if _messages.get_child_count() > 6:
		_messages.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func set_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = text != ""


func set_tooltip(text: String) -> void:
	if _tip.text != text:
		_tip.text = text
		# Shrink back round the new text; it grows from the middle and upward.
		_tip_panel.offset_left = 0
		_tip_panel.offset_right = 0
		_tip_panel.offset_top = -156
	_tip_panel.visible = text != ""


func set_objectives(lines: PackedStringArray) -> void:
	_objectives.text = "\n".join(lines)


func fade_to(color: Color, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade, "color", color, seconds)
	return tw


func set_fade(color: Color) -> void:
	_fade.color = color


func _process(delta: float) -> void:
	_flash_a = maxf(_flash_a - delta * 0.8, 0.0)
	var venom: bool = player != null and player.vitals.venom > 0.0
	_flash.color = Color(0.25, 0.5, 0.05, 0.12 + 0.05 * sin(Time.get_ticks_msec() * 0.006)) if venom and _flash_a < 0.05 \
			else Color(0.6, 0.0, 0.0, _flash_a)
	if player:
		var dark: float = player.vitals.blindness() if player.vitals_enabled and not player.vitals.dead else 0.0
		_blind.color.a = lerpf(_blind.color.a, dark, minf(delta * 2.0, 1.0))
		# Touch screens have an Act button where keyboards have E.
		_prompt.text = player.prompt.replace("[E]", "[Act]") if Settings.touch else player.prompt
		if Settings.touch:
			_prompt.text = _prompt.text.replace("[C]", "[Craft]").replace("[Q]", "[Drop]")
		set_tooltip(player.tooltip)
	if show_vitals:
		var tod := Game.time_of_day()
		var phase := "Night"
		if tod >= 0.2 and tod < 0.3:
			phase = "Dawn"
		elif tod >= 0.3 and tod < 0.7:
			phase = "Day"
		elif tod >= 0.7 and tod < 0.8:
			phase = "Dusk"
		_clock.text = "Day %d  -  %s" % [Game.day() + 1, phase]
		if Game.can_sleep_in() <= 0.0:
			_clock.text += "\nTired (Z to sleep)"
	else:
		_clock.text = ""
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var size := _canvas.size
	var c := size * 0.5
	if player and not player.ui_open and not player.vitals.dead:
		var col := Color(1, 1, 1, 0.85) if player.focus or player.focus_water else Color(1, 1, 1, 0.45)
		_canvas.draw_circle(c, 2.5, col)

	var font := ThemeDB.fallback_font
	# Hotbar (the crafting tray replaces it while working on the ground)
	if player == null or player.work_spot == null:
		_draw_hotbar(c, size)

	# Vitals
	if show_vitals and player:
		var v = player.vitals
		# Stamina is a bar; hunger and thirst are words (Survival.HUNGER_NAMES,
		# THIRST_NAMES), each line left out while you are neither.
		var r := Rect2(20, size.y - 40.0, 180, 12)
		_canvas.draw_rect(r.grow(2), Color(0, 0, 0, 0.55))
		_canvas.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v.stamina / 100.0, 0.0, 1.0), r.size.y)), Color(0.92, 0.9, 0.62))
		if v.max_stamina() < 100.0:
			var cap_x: float = r.position.x + r.size.x * v.max_stamina() / 100.0
			_canvas.draw_rect(Rect2(cap_x, r.position.y, r.end.x - cap_x, r.size.y), Color(0.3, 0.1, 0.1, 0.6))
		_canvas.draw_string(font, r.position + Vector2(r.size.x + 8, 11), "Stamina", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.75))
		var by := r.position.y - 4.0  # baseline of the next line up
		for need in [v.thirst_words(), v.hunger_words()]:
			if need[0] != "":
				_canvas.draw_string(font, Vector2(20, by), need[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, need[1])
				by -= 19.0
		# How you are, in a couple of words, above those (there is no health
		# bar: see the Health tab).
		if player.vitals_enabled:
			var sw: Array = v.status_words()
			_canvas.draw_string(font, Vector2(20, by - 4.0), sw[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, sw[1])

	# The waypoint: a marker over it with the distance, held at the screen edge
	# when it is off to the side or behind you.
	var wp: Vector3 = player.world.waypoint if player and player.world and "waypoint" in player.world else Vector3.INF
	if wp.is_finite() and not player.vitals.dead:
		var cam: Camera3D = player.camera
		var target := wp + Vector3(0, 1.6, 0)
		var sp := cam.unproject_position(target)
		var behind := cam.is_position_behind(target)
		var margin := 34.0
		var d := sp - c
		if behind:
			d = -d
		var k := minf((size.x * 0.5 - margin) / maxf(absf(d.x), 0.001), (size.y * 0.5 - margin) / maxf(absf(d.y), 0.001))
		if behind or k < 1.0:
			if d.length() < 1.0:
				d = Vector2(0, 1)
				k = (size.y * 0.5 - margin)
			sp = c + d * k
		var amber := Color(1.0, 0.78, 0.3, 0.9)
		var dm := PackedVector2Array([sp + Vector2(0, -9), sp + Vector2(7, 0), sp + Vector2(0, 9), sp + Vector2(-7, 0)])
		_canvas.draw_colored_polygon(dm, amber)
		_canvas.draw_polyline(dm + PackedVector2Array([dm[0]]), Color(0, 0, 0, 0.6), 1.0)
		var dist := Vector2(wp.x - player.global_position.x, wp.z - player.global_position.z).length()
		_canvas.draw_string(font, sp + Vector2(-40, 26), "%d m" % roundi(dist), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, amber)

	# Caught in an amphibian's jaws
	if player and player.grabbed_by and not player.vitals.dead and not (player.rolls_for_escape() and player.escape_roll >= 0.0):
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
		var key := "Left mouse / RT"
		_canvas.draw_string(font, Vector2(c.x - 200, c.y + 70), "STAB!  [%s]" % key, HORIZONTAL_ALIGNMENT_CENTER, 400, 30, Color(1.0, 0.3, 0.2, pulse))
		if player.rolls_for_escape():
			# No grip to break: the best strike you land sets your odds.
			var how: String = {"": "no strike yet", "bare": "bare-handed strike", "stone": "stone weapon strike",
					"advanced": "advanced weapon strike"}[player.strike_tier]
			var odds := "Chance it lets go: %d%%  (%s)" % [roundi(player.escape_chance() * 100.0), how]
			_canvas.draw_string(font, Vector2(c.x - 220, c.y + 98), odds, HORIZONTAL_ALIGNMENT_CENTER, 440, 15, Color(1, 1, 1, 0.8))
		else:
			var gr := Rect2(c.x - 120, c.y + 86, 240, 10)
			_canvas.draw_rect(gr.grow(2), Color(0, 0, 0, 0.6))
			_canvas.draw_rect(Rect2(gr.position, Vector2(gr.size.x * clampf(player.grip / player.grip_max, 0.0, 1.0), gr.size.y)), Color(0.75, 0.15, 0.1))
			_canvas.draw_string(font, Vector2(c.x - 120, c.y + 114), "Its grip", HORIZONTAL_ALIGNMENT_CENTER, 240, 13, Color(1, 1, 1, 0.7))


func show_death(text: String, can_load := false) -> void:
	_death = PanelContainer.new()
	_death.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death.custom_minimum_size = Vector2(420, 0)
	_death.offset_left = -210
	_death.offset_right = 210
	_death.offset_top = -110
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_death.add_child(vb)
	var title := _label(32, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "You did not survive"
	vb.add_child(title)
	var info := _label(16, HORIZONTAL_ALIGNMENT_CENTER)
	info.text = text
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	if can_load:
		var wake := Button.new()
		wake.text = "Wake at last camp (Day %d)" % Game.day_of(Game.read_save())
		wake.pressed.connect(func(): load_requested.emit())
		vb.add_child(wake)
		wake.grab_focus.call_deferred()
	var quit := Button.new()
	quit.text = "Title screen"
	quit.pressed.connect(func(): title_requested.emit())
	vb.add_child(quit)
	add_child(_death)
	if not can_load:
		quit.grab_focus.call_deferred()


func _hotbar_rect(i: int, size: Vector2) -> Rect2:
	var slot := 54.0
	var gap := 6.0
	var total := Inventory.HOTBAR * slot + (Inventory.HOTBAR - 1) * gap
	return Rect2(size.x * 0.5 - total * 0.5 + i * (slot + gap), size.y - slot - 16.0, slot, slot)


func hotbar_slot_at(p: Vector2) -> int:
	## The hotbar slot under a screen point (for touch), or -1.
	for i in Inventory.HOTBAR:
		if _hotbar_rect(i, _canvas.size).grow(4.0).has_point(p):
			return i
	return -1


func _draw_hotbar(_c: Vector2, size: Vector2) -> void:
	var inv = Game.inventory
	var slot := 54.0
	var x0 := _hotbar_rect(0, size).position.x
	var y0 := _hotbar_rect(0, size).position.y
	var total := _hotbar_rect(Inventory.HOTBAR - 1, size).end.x - x0
	for i in Inventory.HOTBAR:
		var r := _hotbar_rect(i, size)
		_canvas.draw_rect(r, Color(0.05, 0.07, 0.05, 0.7))
		var sel: bool = i == inv.selected
		_canvas.draw_rect(r, Color(0.9, 0.85, 0.5) if sel else Color(0.5, 0.55, 0.4, 0.6), false, 2.0 if sel else 1.0)
		var s = inv.slots[i]
		if s != null:
			Icons.draw_item(_canvas, r.grow(-6), s.id)
			if s.n > 1:
				_canvas.draw_string(ThemeDB.fallback_font, r.position + Vector2(slot - 20, slot - 6), str(s.n), HORIZONTAL_ALIGNMENT_RIGHT, 16, 14)
			var fresh: float = inv.freshness(i)
			if fresh < 1.0:
				_canvas.draw_rect(Rect2(r.position + Vector2(4, slot - 5), Vector2((slot - 8) * fresh, 2)), Color(0.4, 0.8, 0.3).lerp(Color(0.8, 0.3, 0.2), 1.0 - fresh))
			var dur: float = inv.durability(i)
			if dur >= 0.0:
				Icons.draw_durability(_canvas, Rect2(r.position + Vector2(4, slot - 10), Vector2(slot - 8, 3)), dur)
		_canvas.draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
	var held: String = inv.held_id()
	if held != "":
		_canvas.draw_string(ThemeDB.fallback_font, Vector2(x0, y0 - 8), Items.item_name(held), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.8))

	# Carried weight
	var font := ThemeDB.fallback_font
	var w: float = inv.weight()
	var cap: float = inv.capacity()
	_canvas.draw_string(font, Vector2(x0 + total - 120, y0 - 8), "%.1f / %.0f kg" % [w, cap], HORIZONTAL_ALIGNMENT_RIGHT, 120, 14,
			Color(1.0, 0.4, 0.3) if w > cap else Color(1, 1, 1, 0.6))
