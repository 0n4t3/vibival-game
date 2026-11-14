extends Control
## Inventory grid with rest and condition, or (opened on a stash) your
## inventory beside the stash's contents. Its own tabs hold your health
## (vitals and injuries, with treatment) and the recipe book.
## Crafting itself happens in the world (C: work on the ground).
## Click a slot to select it, click another to move/swap/merge, in either grid.
## Right-click a slot to eat, drink or use it on your wounds; beside a stash,
## right-click moves the whole stack to the other side.

const Icons := preload("res://src/ui/icons.gd")
const Inventory := preload("res://src/core/inventory.gd")
const Survival := preload("res://src/core/survival.gd")
const Preserves := preload("res://src/core/preserves.gd")

var where := "swamp"       # which recipe set the book shows
var player: Node = null
var stash: Node = null     # the stash open beside your inventory, if any
var vessel: Node = null    # the fermentation vessel open, if any (its own page)
var _vessel_page: Control
var _vessel_box: VBoxContainer
var _vessel_add: VBoxContainer
var filling := false         # the vessel page is the menu to fill a clay pot of preserves
var _pot_pick: Array = []    # vessel items picked to go in a preserving pot
var _pot_vessel: Node = null # the vessel they were picked from

var _sel := -1
var _sel_store := false    # the selection is in the stash grid
var _hover := -1
var _hover_store := false
var _slots: Array[Button] = []
var _hint: Label
var _rest_panel: PanelContainer
var _stash_panel: PanelContainer
var _stash_slots: Array[Button] = []
var _stash_weight: Label
var _pickup_btn: Button
var _name: Label
var _desc: Label
const DESC_W := 300.0  # the item description's width, beside the grid
const DESC_STATS := "Energy +10  Protein +10  Greens +10  Starch +10  Water +10  0.25 kg (2.5 kg)  Risky to eat"
## The page is pinned at the top rather than centred, so nothing jumps as its
## height changes (hovering items, opening containers, switching tabs): its
## top sits where the inventory page (`_ref_h`, measured once) is centred, and
## on a screen too short for that the whole page is scaled down to fit. The
## tall scrolling lists of the other pages shrink to the room left (_fits).
var _page: VBoxContainer
var _ref_h := 0.0
var _tab_row: HBoxContainer
var _fits: Array = []      # [[ScrollContainer, tallest, height taken up round it]]
var _use_btn: Button
var _treat_btn: Button
var _drop_btn: Button
var _discard_btn: Button
var _open_btn: Button
var _weight: Label
var _condition: Label
var _rest: VBoxContainer
var _sleep_info: Label
var _sleep_btn: Button
var _tabs: Array[Button] = []
var _inv_page: Control
var _book_page: Control
var _health_page: Control
var _vitals_box: VBoxContainer
var _wound_box: VBoxContainer
var _supplies: Label
var _wash_btn: Button
var _cats: VBoxContainer
var _book: VBoxContainer
var _cat := ""


class Slot extends Button:
	var index := 0
	var store := false     # a slot of the stash, not of your inventory
	var ui: Control

	func _draw() -> void:
		if store and ui.stash == null:
			return
		var inv = ui.stash.inv if store else Game.inventory
		var r := Rect2(Vector2.ZERO, size)
		var hot := index < 6 and not store
		draw_rect(r, Color(0.08, 0.11, 0.07, 0.9) if not hot else Color(0.1, 0.13, 0.08, 0.95))
		var border := Color(0.45, 0.5, 0.35, 0.7)
		var selected: bool = ui._sel == index and ui._sel_store == store
		if selected:
			border = Color(1.0, 0.9, 0.4)
		elif has_focus() or (ui._hover == index and ui._hover_store == store):
			border = Color(0.8, 0.85, 0.6)
		draw_rect(r, border, false, 2.0 if selected else 1.0)
		var s = inv.slots[index]
		if s == null:
			return
		Icons.draw_item(self, r.grow(-8), s.id)
		if s.n > 1:
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 22, size.y - 6), str(s.n), HORIZONTAL_ALIGNMENT_RIGHT, 18, 14)
		var fresh: float = inv.freshness(index)
		if fresh < 1.0:
			draw_rect(Rect2(4, size.y - 5, (size.x - 8) * fresh, 2), Color(0.4, 0.8, 0.3).lerp(Color(0.8, 0.3, 0.2), 1.0 - fresh))
		var dur: float = inv.durability(index)
		if dur >= 0.0:
			Icons.draw_durability(self, Rect2(4, size.y - 10, size.x - 8, 3), dur)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	add_child(page)
	_page = page
	page.resized.connect(_layout)
	resized.connect(_layout)
	# A page never shrinks by itself: when it gets narrower (another tab, a
	# container closed, a shorter description) fit it again, or it stays as
	# wide as before with everything pushed to its left.
	page.minimum_size_changed.connect(func(): _layout.call_deferred())
	visibility_changed.connect(func(): _layout.call_deferred())
	var tab_row := HBoxContainer.new()
	page.add_child(tab_row)
	_tab_row = tab_row
	for t in ["Inventory", "Health", "Recipes"]:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, 0)
		b.pressed.connect(show_page.bind(t.to_lower()))
		tab_row.add_child(b)
		_tabs.append(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	page.add_child(row)
	_inv_page = row
	_build_health(page)
	_build_book(page)
	_build_vessel(page)

	# Inventory panel
	var inv_panel := _panel("Inventory")
	row.add_child(inv_panel)
	var inv_box: VBoxContainer = inv_panel.get_child(0)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.modulate = Color(1, 1, 1, 0.6)
	inv_box.add_child(_hint)
	_weight = Label.new()
	_weight.add_theme_font_size_override("font_size", 14)
	inv_box.add_child(_weight)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	# The hovered item's name and description sit beside the grid, in the room
	# the hint above leaves there, rather than under it making the menu tall.
	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 16)
	inv_box.add_child(grid_row)
	grid_row.add_child(grid)
	_fill_grid(grid, _slots, false)
	var about := VBoxContainer.new()
	about.add_theme_constant_override("separation", 4)
	grid_row.add_child(about)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 18)
	about.add_child(_name)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("font_size", 14)
	# A fixed size, room for the longest description and its stats, so nothing
	# moves as you hover over items.
	_desc.clip_text = true
	var font: Font = _desc.get_theme_font("font")
	var spacing: int = _desc.get_theme_constant("line_spacing")
	_desc.custom_minimum_size = Vector2(DESC_W, (font.get_height(14) + spacing) * desc_lines(font, 14))
	about.add_child(_desc)
	var btns := HBoxContainer.new()
	inv_box.add_child(btns)
	_use_btn = _button("Eat / Drink", _on_use)
	_treat_btn = _button("Treat wound", _on_treat)
	_drop_btn = _button("Drop", _on_drop)
	_drop_btn.tooltip_text = "Put it on the ground. It stays there."
	_discard_btn = _button("Discard", _on_discard)
	_discard_btn.tooltip_text = "Throw it away. It is gone once you leave or reload."
	_open_btn = _button("Open", _on_open)
	_open_btn.tooltip_text = "Take all the food out into your bag."
	for b in [_use_btn, _treat_btn, _open_btn, _drop_btn, _discard_btn]:
		btns.add_child(b)
	_condition = Label.new()
	_condition.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_condition.custom_minimum_size = Vector2(390, 0)
	_condition.add_theme_font_size_override("font_size", 13)
	inv_box.add_child(_condition)

	# Resting: sleep from here, with a read on how safe the spot is.
	_rest_panel = _panel("Rest")
	row.add_child(_rest_panel)
	_rest = VBoxContainer.new()
	_rest.add_theme_constant_override("separation", 6)
	_rest_panel.get_child(0).add_child(_rest)
	_sleep_info = Label.new()
	_sleep_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sleep_info.custom_minimum_size = Vector2(340, 0)
	_sleep_info.add_theme_font_size_override("font_size", 13)
	_rest.add_child(_sleep_info)
	_sleep_btn = _button("Sleep here", _on_sleep)
	_rest.add_child(_sleep_btn)

	# Stash panel, in place of resting while a stash is open
	_stash_panel = _panel("Sack")  # titled with the stash's sack when opened
	_stash_panel.visible = false
	row.add_child(_stash_panel)
	var sb: VBoxContainer = _stash_panel.get_child(0)
	_stash_weight = Label.new()
	_stash_weight.add_theme_font_size_override("font_size", 14)
	sb.add_child(_stash_weight)
	var sgrid := GridContainer.new()
	sgrid.columns = 6
	sgrid.add_theme_constant_override("h_separation", 6)
	sgrid.add_theme_constant_override("v_separation", 6)
	sb.add_child(sgrid)
	_fill_grid(sgrid, _stash_slots, true)
	var sbtns := HBoxContainer.new()
	sb.add_child(sbtns)
	sbtns.add_child(_button("Take all", _take_all))
	sbtns.add_child(_button("Store all but hotbar", _store_all))
	_pickup_btn = _button("Pick up sack", _pick_up_stash)
	sbtns.add_child(_pickup_btn)

	Game.inventory.changed.connect(_refresh)
	Settings.input_changed.connect(_input_changed)
	Assets.icons_ready.connect(_refresh)


static func desc_lines(font: Font, size: int) -> int:
	## Lines enough for the longest item description, with a full line of
	## stats under it, at DESC_W.
	var most := 1
	for id in Items.ITEMS:
		var n := 0
		for para in [str(Items.ITEMS[id].get("desc", "")), DESC_STATS]:
			n += maxi(1, ceili(font.get_multiline_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, DESC_W, size).y / font.get_height(size) - 0.01))
		most = maxi(most, n)
	return most


func _layout() -> void:
	## Pins the page's top edge and fits the scrolling lists to the screen.
	if _page == null or size.y <= 0.0:
		return
	if _ref_h <= 0.0:
		_ref_h = _tab_row.get_combined_minimum_size().y + 8.0 + _inv_page.get_combined_minimum_size().y
	var k := clampf((size.y - 24.0) / _ref_h, 0.6, 1.0)
	var top := maxf(12.0, roundf((size.y - _ref_h * k) * 0.5))
	var room := (size.y - top - 12.0) / k
	for f in _fits:
		var want := clampf(room - float(f[2]), 160.0, float(f[1]))
		if absf(f[0].custom_minimum_size.y - want) > 0.5:
			f[0].custom_minimum_size.y = want
	_page.scale = Vector2(k, k)
	_page.reset_size()
	_page.position = Vector2(roundf((size.x - _page.size.x * k) * 0.5), top)


func _fit(scroll: ScrollContainer, tallest: float, around: float) -> void:
	_fits.append([scroll, tallest, around])


func _fill_grid(grid: GridContainer, into: Array[Button], store: bool) -> void:
	for i in Inventory.SIZE:
		var s := Slot.new()
		s.index = i
		s.store = store
		s.ui = self
		s.custom_minimum_size = Vector2(60, 60)
		s.flat = true
		s.pressed.connect(_on_slot.bind(i, store))
		s.gui_input.connect(_on_slot_input.bind(i, store))
		s.mouse_entered.connect(_set_hover.bind(i, store))
		s.mouse_exited.connect(_clear_hover.bind(i, store))
		s.focus_entered.connect(_set_hover.bind(i, store))
		grid.add_child(s)
		into.append(s)


func _set_hover(i: int, store := false) -> void:
	_hover = i
	_hover_store = store
	_refresh_info()


func _clear_hover(i: int, store := false) -> void:
	if _hover == i and _hover_store == store:
		_hover = -1


func _panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.05, 0.94)
	sb.border_color = Color(0.4, 0.48, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 22)
	vb.add_child(l)
	return p


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func open(with_stash: Node = null, page := "inventory") -> void:
	stash = with_stash
	if stash:
		stash.inv.changed.connect(_refresh)
	_stash_panel.visible = stash != null
	if stash:
		(_stash_panel.get_child(0).get_child(0) as Label).text = Items.item_name(stash.sack_id)
	visible = true
	_set_hint()
	_sel = -1
	_hover = -1
	show_page(page if stash == null else "inventory")
	if vessel == null and page in ["vessel", "fill_pot"]:
		show_page("inventory")
	_slots[Game.inventory.selected].grab_focus()


func _set_hint() -> void:
	if Settings.touch:
		_hint.text = "Tap an item, then a slot on the other side to move it." if stash \
				else "Top row is your hotbar. Tap an item to eat, drink or treat wounds with it. Craft on the ground with Craft."
	else:
		_hint.text = Settings.hint("Click an item, then a slot on the other side to move it. Right-click moves a whole stack across." if stash \
				else "Top row is your hotbar (keys 1-6). Right-click to eat, drink or treat wounds. Craft on the ground with [C].")


func _input_changed() -> void:
	if visible:
		_set_hint()
		_refresh()


func show_page(page: String) -> void:
	filling = page == "fill_pot"
	if filling:
		page = "vessel"
	if page != "vessel":
		vessel = null
	_inv_page.visible = page == "inventory"
	_health_page.visible = page == "health"
	_book_page.visible = page == "recipes"
	_vessel_page.visible = page == "vessel"
	for i in _tabs.size():
		_tabs[i].button_pressed = _tabs[i].text.to_lower() == page
		if i > 0:
			_tabs[i].disabled = stash != null
	_refresh()


func close() -> void:
	if stash and is_instance_valid(stash) and stash.inv.changed.is_connected(_refresh):
		stash.inv.changed.disconnect(_refresh)
	stash = null
	vessel = null
	visible = false
	_sel = -1


# --- Slots -------------------------------------------------------------------------

func _inv(store: bool) -> RefCounted:
	return stash.inv if store else Game.inventory


func _on_slot(i: int, store := false) -> void:
	if _sel == -1:
		if _inv(store).slots[i] != null:
			_sel = i
			_sel_store = store
	elif _sel == i and _sel_store == store:
		_sel = -1
	elif _sel_store == store:
		_inv(store).swap(_sel, i)
		_sel = -1
		Sfx.play("click", -12.0)
	else:
		_move(_inv(_sel_store), _sel, _inv(store), i)
		_sel = -1
	_refresh()


func _on_slot_input(ev: InputEvent, i: int, store := false) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_slot_use(i, store)
		accept_event()


func _slot_use(i: int, store: bool) -> void:
	## A right-click on a slot: beside a stash, the stack goes across;
	## otherwise eat, drink or treat with it.
	if stash:
		_move_across(_inv(store), i, _inv(not store))
	else:
		_consume(i)


func _focus_slot() -> int:
	## The slot of your own inventory in focus (-1 if none, or if it is the stash's).
	if _sel != -1:
		return -1 if _sel_store else _sel
	return -1 if _hover_store else _hover


func _focus_stack() -> Variant:
	## The stack in focus in either grid, or null.
	var i := _sel if _sel != -1 else _hover
	var store := _sel_store if _sel != -1 else _hover_store
	if i < 0 or (store and stash == null):
		return null
	return _inv(store).slots[i]


# --- Stash ---------------------------------------------------------------------------

func _move(src: RefCounted, si: int, dst: RefCounted, di: int) -> bool:
	## Moves the stack in src slot si to dst slot di: into an empty slot or onto
	## the same item as far as weight and stack size allow, otherwise a swap
	## if each side can take the other's load.
	var s = src.slots[si]
	var d = dst.slots[di]
	if s == null:
		return false
	if d != null and (d.id != s.id or s.has("data") or d.has("data")):
		var ws: float = Items.slot_weight(s) * s.n
		var wd: float = Items.slot_weight(d) * d.n
		if dst.weight() - wd + ws > dst.capacity() * dst.overload + 0.001 \
				or src.weight() - ws + wd > src.capacity() * src.overload + 0.001:
			Game.notify("Too heavy to swap those.")
			return false
		src.slots[si] = d
		dst.slots[di] = s
		src.changed.emit()
		dst.changed.emit()
		Sfx.play("click", -12.0)
		return true
	var n: int = mini(s.n, dst.room_for(s.id))
	if d != null:
		n = mini(n, Items.max_stack(s.id) - d.n)
	if n <= 0:
		_full(dst)
		return false
	var moved: Dictionary = src.take(si, n)
	if d == null:
		dst.slots[di] = {"id": moved.id, "n": moved.n, "age": moved.age}
		if moved.has("data"):
			dst.slots[di].data = moved.data
	else:
		d.age = maxf(d.age, moved.age)
		d.n += moved.n
	dst.changed.emit()
	Sfx.play("click", -12.0)
	return true


func _move_across(src: RefCounted, i: int, dst: RefCounted) -> int:
	## Moves as much of a stack as fits to the other side. Returns how many.
	var s = src.slots[i]
	if s == null:
		return 0
	var moved: int = s.n - dst.add(s.id, s.n, s.age, false, s.get("data", {}))
	if moved > 0:
		src.take(i, moved)
		Sfx.play("click", -12.0)
	else:
		_full(dst)
	return moved


func _full(dst: RefCounted) -> void:
	Game.notify("The sack is full (50 kg)." if dst != Game.inventory else "Too heavy to carry any more.")


func _take_all() -> void:
	for i in Inventory.SIZE:
		if stash.inv.slots[i] != null:
			_move_across(stash.inv, i, Game.inventory)
	_refresh()


func _store_all() -> void:
	for i in range(Inventory.HOTBAR, Inventory.SIZE):
		if Game.inventory.slots[i] != null:
			_move_across(Game.inventory, i, stash.inv)
	_refresh()


func _pick_up_stash() -> void:
	if stash and stash.pick_up():
		player.world.toggle_inventory()


func _consume(i: int) -> void:
	## Right-click: eat or drink food, otherwise use a treatment on your wounds.
	if i < 0 or player == null or Game.inventory.slots[i] == null:
		return
	if Items.is_food(Game.inventory.slots[i].id):
		player.consume_slot(i)
	elif Items.def(Game.inventory.slots[i].id).get("preserves", false):
		player.use_preserves(i)
	else:
		player.treat_slot(i)
	_refresh()


func _on_treat() -> void:
	var i := _focus_slot()
	if i >= 0 and player != null and Game.inventory.slots[i] != null:
		player.treat_slot(i)
		_refresh()


func _on_use() -> void:
	_consume(_focus_slot())


func _on_drop(keep := true) -> void:
	var i := _focus_slot()
	if i < 0 or Game.inventory.slots[i] == null or player == null or player.world == null:
		return
	var s: Dictionary = Game.inventory.take(i, Game.inventory.slots[i].n)
	var pos: Vector3 = player.global_position - player.transform.basis.z * 1.0 + Vector3(0, 0.8, 0)
	if keep and player.world.has_method("pile_item"):
		player.world.pile_item(s.id, s.n, pos, s.age, s.get("data", {}))  # raw materials go on a pile there
	else:
		player.world.spawn_pickup(s.id, s.n, pos, s.age, keep, s.get("data", {}))
	_sel = -1
	_refresh()


func _on_discard() -> void:
	_on_drop(false)


func _refresh() -> void:
	if not visible:
		return
	for s in _slots:
		s.queue_redraw()
	if stash:
		for s in _stash_slots:
			s.queue_redraw()
		_stash_weight.text = "Holding %.1f / %d kg" % [stash.inv.weight(), stash.capacity()]
		_pickup_btn.disabled = not stash.is_empty()
		_pickup_btn.tooltip_text = "" if stash.is_empty() else "Empty it first."
	_refresh_info()
	_refresh_condition()
	_refresh_rest()
	if _book_page.visible:
		_refresh_book()
	if _health_page.visible:
		_refresh_health()
	if _vessel_page.visible:
		_refresh_vessel()


func _refresh_info() -> void:
	var s = _focus_stack()
	if s == null:
		_name.text = ""
		_desc.text = ""
		_use_btn.disabled = true
		_treat_btn.disabled = true
		_drop_btn.disabled = true
		_discard_btn.disabled = true
		_open_btn.visible = false
		_use_btn.visible = true
		return
	var def := Items.def(s.id)
	if s.has("data"):
		def = def.merged(s.data, true)
	_name.text = "%s%s" % [def.name, "  x%d" % s.n if s.n > 1 else ""]
	var lines := [def.get("desc", "")]
	var stats := []
	for k in ["energy", "protein", "greens", "starch", "water"]:
		if def.has(k):
			stats.append("%s +%d" % [k.capitalize(), def[k]])
	match def.get("treat", ""):
		"clean":
			stats.append("Washes your wounds")
		"bandage":
			stats.append("Covers a wound")
		"wax":
			stats.append("Seals a wound")
		"alcohol":
			stats.append("Cleans a wound, fights infection")
	var kg: float = Items.slot_weight(s)
	stats.append("%.2f kg" % kg if s.n == 1 else "%.2f kg (%.1f kg)" % [kg, kg * s.n])
	if def.has("damage"):
		stats.append("Damage %d" % def.damage)
	if def.has("uses"):
		stats.append("%d / %d uses left" % [int(def.get("uses_left", def.uses)), def.uses])
	if def.has("fuel"):
		stats.append("Fuel %ds" % def.fuel)
	if def.has("cook"):
		stats.append("Fire turns it into %s" % Items.item_name(def.cook))
	if def.get("sick", 0.0) > 0.0:
		stats.append("Risky to eat")
	if not stats.is_empty():
		lines.append("  ".join(stats))
	_desc.text = Settings.hint("\n".join(lines))
	var mine := _focus_slot() >= 0
	_use_btn.disabled = not mine or not Items.is_food(s.id)
	_treat_btn.disabled = not mine or not def.has("treat") or not player.vitals_enabled
	_drop_btn.disabled = not mine
	_discard_btn.disabled = not mine
	_open_btn.visible = def.get("preserves", false)
	_open_btn.disabled = not mine
	_use_btn.visible = not _open_btn.visible
	for b in _slots:
		b.queue_redraw()
	for b in _stash_slots:
		b.queue_redraw()


func _refresh_condition() -> void:
	var inv = Game.inventory
	var w: float = inv.weight()
	var cap: float = inv.capacity()
	_weight.text = "Carrying %.1f / %.0f kg%s" % [w, cap, "  (overloaded: slow, no sprinting)" if w > cap else ""]
	_weight.modulate = Color(1.0, 0.5, 0.4) if w > cap else Color(1, 1, 1, 0.8)
	if player == null or not player.vitals_enabled:
		_condition.text = ""
		return
	var v = player.vitals
	var lines := ["Condition:  protein %d  greens %d  starch %d" % [v.protein, v.greens, v.starch]]
	if not v.wounds.is_empty():
		var hurt := "%d injur%s" % [v.wounds.size(), "y" if v.wounds.size() == 1 else "ies"]
		if v.bleeding():
			hurt += ", bleeding"
		if v.infection() > 0.0:
			hurt += ", infected"
		lines.append("%s. See the Health tab to treat them." % hurt.capitalize())
	_condition.text = "\n".join(lines)


func _process(delta: float) -> void:
	# The gamepad's use button on a slot does what a right-click does.
	if visible and _inv_page.visible and Settings.using_pad and Input.is_action_just_pressed("use"):
		var f := get_viewport().gui_get_focus_owner()
		if f in _slots:
			_slot_use(_slots.find(f), false)
		elif f in _stash_slots:
			_slot_use(_stash_slots.find(f), true)
	# Keep the rest section current while the menu is open (time keeps passing).
	if visible and _rest.visible and Engine.get_process_frames() % 30 == 0:
		_refresh_rest()
	# Not while a button is held down, so a rebuild can't swallow the click.
	if visible and _health_page.visible and Engine.get_process_frames() % 30 == 0 \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_action_pressed("ui_accept"):
		_refresh_health()
	if visible and _vessel_page.visible and Engine.get_process_frames() % 30 == 0 \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if vessel == null or not is_instance_valid(vessel) or vessel.hauled_by != null \
				or (player and player.global_position.distance_to(vessel.global_position) > 4.0):
			if player and player.world:
				player.world.toggle_inventory()  # walked away from it
		else:
			_refresh_vessel()
	# Walked away from the stash (or something carried it off): close.
	if visible and stash != null and (not is_instance_valid(stash) or stash.is_queued_for_deletion() \
			or stash.global_position.distance_to(player.global_position) > 4.0):
		player.world.toggle_inventory()


func _refresh_rest() -> void:
	var world: Node = player.world if player else null
	_rest.visible = world != null and world.has_method("sleep_blocker") and player.vitals_enabled and stash == null
	_rest_panel.visible = _rest.visible
	if not _rest.visible:
		return
	var why: String = world.sleep_blocker()
	_sleep_btn.disabled = why != ""
	_sleep_info.text = why if why != "" else world.sleep_preview()


func _on_sleep() -> void:
	var world: Node = player.world
	if world.sleep_blocker() != "":
		_refresh_rest()
		return
	world.toggle_inventory()
	world.sleep()


# --- Health ------------------------------------------------------------------------------
# How you are: a summary, each condition that could kill you, what to do about
# every problem (Survival.problems), and a card per wound with buttons to
# treat it with what you carry: pressure, washing, alcohol, a bandage or wax.

func _build_health(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.visible = false
	parent.add_child(row)
	_health_page = row
	var cond := _panel("Condition")
	cond.custom_minimum_size = Vector2(360, 0)
	row.add_child(cond)
	var cscroll := ScrollContainer.new()
	cscroll.custom_minimum_size = Vector2(360, 470)
	_fit(cscroll, 470.0, 110.0)
	cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cond.get_child(0).add_child(cscroll)
	_vitals_box = VBoxContainer.new()
	_vitals_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vitals_box.add_theme_constant_override("separation", 4)
	cscroll.add_child(_vitals_box)
	var inj := _panel("Injuries")
	row.add_child(inj)
	var ib: VBoxContainer = inj.get_child(0)
	_supplies = Label.new()
	_supplies.add_theme_font_size_override("font_size", 13)
	_supplies.modulate = Color(1, 1, 1, 0.75)
	_supplies.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_supplies.custom_minimum_size = Vector2(440, 0)
	ib.add_child(_supplies)
	_wash_btn = _button("Wash all dirty wounds (boiled water)", func(): _treat_with("clean", -1))
	ib.add_child(_wash_btn)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 400)
	_fit(scroll, 400.0, 180.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ib.add_child(scroll)
	_wound_box = VBoxContainer.new()
	_wound_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wound_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_wound_box)


func _treat_slot(kind: String) -> int:
	## The first inventory slot holding a treatment of this kind, or -1.
	for i in Inventory.SIZE:
		var s = Game.inventory.slots[i]
		if s != null and Items.def(s.id).get("treat", "") == kind:
			return i
	return -1


func _treat_with(kind: String, wound: int) -> void:
	var i := _treat_slot(kind)
	if i >= 0 and player != null:
		player.treat_slot(i, wound)
	_refresh()


func _press(wound: int) -> void:
	## Pressure takes both hands and holding still: the menu closes first.
	if player == null:
		return
	if player.world and player.world.has_method("toggle_inventory"):
		player.world.toggle_inventory()
	player.start_pressure(wound)


func _bar(value: float, col: Color, width := 150.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(width, 10)
	b.show_percentage = false
	b.max_value = 1.0
	b.step = 0.0
	b.value = value
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	return b


func _stat_row(parent: Control, label: String, value: float, col: Color, text := "") -> void:
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_font_size_override("font_size", 13)
	r.add_child(l)
	var b := _bar(value, col)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(b)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 12)
	t.modulate = Color(1, 1, 1, 0.7)
	r.add_child(t)
	parent.add_child(r)


func _text_row(parent: Control, label: String, text: String, col: Color) -> void:
	## A _stat_row with words where the bar would be.
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	l.add_theme_font_size_override("font_size", 13)
	r.add_child(l)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", col)
	r.add_child(t)
	parent.add_child(r)


func _small(text: String, col := Color(1, 1, 1, 0.8), size := 13) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	l.add_theme_font_size_override("font_size", size)
	l.modulate = col
	return l


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func wound_advice(w: Dictionary) -> String:
	## What a wound needs most right now.
	if w.bleed == 3:
		return "Bleeding heavily. Apply pressure, then bandage it while the pressure holds." if w.held <= 0.0 \
				else "Held back by pressure for %d s: bandage it now." % w.held
	if w.bleed == 2:
		return "Bleeding steadily. Apply pressure until it stops."
	match w.inf:
		Survival.INF_SEPSIS:
			return Survival.SEPSIS_TEXT
		Survival.INF_MAJOR:
			return "Major infection. Only alcohol helps, and it takes more than one treatment."
		Survival.INF_REMISSION:
			return "In remission. Treat it with alcohol again, or it flares back up."
		Survival.INF_MODERATE:
			return "Moderate infection. Clean it with alcohol%s, then bandage it." % (" (done)" if w.sterile else "")
		Survival.INF_MINOR:
			if w.get("early", false):
				return "Minor infection. Keep it clean and covered: it will clear by itself."
			return "Minor infection. Wash it with boiled water and cover it. It may clear by itself, or get worse."
	if w.bleed == 1:
		return "Bleeding a little. It will stop on its own."
	if w.dirt > 0.05:
		return "Dirty. Wash it with boiled water, then cover it before it festers."
	if w.cover == "":
		return "Clean but open. Cover it with a bandage or waxy residue to keep infection out."
	return "Clean and covered (%s). Keep it out of swamp water%s and away from animals." % [w.cover, " (a bandage soaks it up)" if w.cover == "bandage" else ""]


func _refresh_health() -> void:
	if player == null:
		return
	var v = player.vitals
	_clear(_vitals_box)
	if not player.vitals_enabled:
		_vitals_box.add_child(_small("Your body needs no looking after here."))
	else:
		_vitals_box.add_child(_small(v.summary(), Color(1.0, 0.45, 0.4) if v.tier() >= 2 or v.infection() == Survival.INF_SEPSIS else Color(1, 1, 1, 0.9), 15))
		var h: Dictionary = v.harms()
		var inf: int = v.infection()
		_stat_row(_vitals_box, "Blood", v.blood / 100.0, Color(0.8, 0.15, 0.15), "%d%%" % roundi(v.blood))
		if v.venom > 0.0:
			_stat_row(_vitals_box, "Venom", h.venom, Color(0.55, 0.85, 0.25), "%d%%" % roundi(v.venom))
		if inf != Survival.INF_NONE:
			_stat_row(_vitals_box, "Infection", maxf(h.infection, 0.1), Color(0.95, 0.65, 0.25), Survival.INF_NAMES[inf])
		if v.starving > 0.0:
			_stat_row(_vitals_box, "Starvation", v.starving, Color(0.85, 0.55, 0.2))
		if v.thirst > 0.0:
			_stat_row(_vitals_box, "Dehydration", v.thirst, Color(0.3, 0.5, 0.9))
		for limb in v.limbs:
			_vitals_box.add_child(_small("%s: mends after %d more sleep%s" % [Survival.LIMB_NAMES[limb], v.limbs[limb], "" if v.limbs[limb] == 1 else "s"], Color(0.95, 0.75, 0.5)))
		_vitals_box.add_child(HSeparator.new())
		# Hunger and thirst are words, not bars (Survival.HUNGER_NAMES).
		var hw: Array = v.hunger_words()
		var tw: Array = v.thirst_words()
		_text_row(_vitals_box, "Hunger", hw[0] if hw[0] != "" else "Well fed", hw[1])
		_text_row(_vitals_box, "Thirst", tw[0] if tw[0] != "" else "Not thirsty", tw[1])
		_stat_row(_vitals_box, "Stamina", v.stamina / 100.0, Color(0.9, 0.9, 0.6), "%d" % v.stamina)
		_stat_row(_vitals_box, "Protein", v.protein / 100.0, Color(0.8, 0.5, 0.45), "low" if v.protein < Survival.LOW else "")
		_stat_row(_vitals_box, "Greens", v.greens / 100.0, Color(0.45, 0.75, 0.35), "low" if v.greens < Survival.LOW else "")
		_stat_row(_vitals_box, "Starch", v.starch / 100.0, Color(0.85, 0.75, 0.45), "low" if v.starch < Survival.LOW else "")
		var p: Array = v.problems()
		if not p.is_empty():
			_vitals_box.add_child(HSeparator.new())
			_vitals_box.add_child(_small("What to do", Color(0.9, 0.85, 0.6), 14))
			for e in p:
				_vitals_box.add_child(_small(e.say, e.color))
				if e.advice != "":
					_vitals_box.add_child(_small("  " + e.advice, Color(1, 1, 1, 0.7), 12))
	_clear(_wound_box)
	var have := {}
	for kind in ["bandage", "wax", "clean", "alcohol"]:
		var c := 0
		for s in Game.inventory.slots:
			if s != null and Items.def(s.id).get("treat", "") == kind:
				c += s.n
		have[kind] = c
	_supplies.text = "You carry: %d bandage%s, %d waxy residue, %d serving%s of boiled water, %s" % [
		have.bandage, "" if have.bandage == 1 else "s", have.wax, have.clean, "" if have.clean == 1 else "s",
		"no alcohol" if have.alcohol == 0 else "%d alcohol" % have.alcohol]
	_wash_btn.disabled = have.clean == 0 or not v.wounds.any(func(w): return w.dirt > 0.0 or w.inf != Survival.INF_NONE) \
			or not player.vitals_enabled
	if v.wounds.is_empty():
		_wound_box.add_child(_small("No wounds."))
		return
	for i in v.wounds.size():
		var w: Dictionary = v.wounds[i]
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.04)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", sb)
		_wound_box.add_child(card)
		var cb := VBoxContainer.new()
		cb.add_theme_constant_override("separation", 3)
		card.add_child(cb)
		var title := Label.new()
		title.text = "%s  (%s)" % [Survival.wound_name(w), w.src if w.src != "" else "injury"]
		title.add_theme_font_size_override("font_size", 16)
		cb.add_child(title)
		var notes := []
		if w.bleed > 0:
			notes.append("%s bleeding%s" % [Survival.BLEED_NAMES[w.bleed], ", held back" if w.held > 0.0 else ""])
		notes.append("covered with %s" % ("a bandage" if w.cover == "bandage" else "wax") if w.cover != "" else "open")
		if w.inf != Survival.INF_NONE:
			notes.append(Survival.INF_NAMES[w.inf].to_lower())
		cb.add_child(_small(", ".join(notes)))
		_stat_row(cb, "Depth", w.sev, Color(0.85, 0.4, 0.3))
		_stat_row(cb, "Dirt", w.dirt, Color(0.6, 0.5, 0.35))
		cb.add_child(_small(wound_advice(w), Color(0.95, 0.9, 0.7)))
		var br := HFlowContainer.new()
		cb.add_child(br)
		var press := _button("Apply pressure", _press.bind(i))
		press.disabled = w.bleed == 0 or player.hauling != null
		br.add_child(press)
		var wash := _button("Wash", _treat_with.bind("clean", i))
		wash.disabled = have.clean == 0
		br.add_child(wash)
		var alc := _button("Alcohol", _treat_with.bind("alcohol", i))
		alc.disabled = have.alcohol == 0
		alc.tooltip_text = "You have no alcohol: brew some in a sealed fermentation vessel and draw it into a canteen." if have.alcohol == 0 else ""
		br.add_child(alc)
		var bandage := _button("Bandage", _treat_with.bind("bandage", i))
		bandage.disabled = w.cover != "" or have.bandage == 0
		br.add_child(bandage)
		var wax := _button("Seal with wax", _treat_with.bind("wax", i))
		wax.disabled = w.cover != "" or have.wax == 0 or w.bleed > 0
		br.add_child(wax)


# --- Fermentation vessel ----------------------------------------------------------------
# What is in a vessel (take any of it out), and what you carry that can go in:
# food, salt (a sealed vessel), and water to pour in.

func _build_vessel(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.visible = false
	parent.add_child(row)
	_vessel_page = row
	var inside := _panel("Vessel")
	inside.custom_minimum_size = Vector2(420, 0)
	row.add_child(inside)
	var s1 := ScrollContainer.new()
	s1.custom_minimum_size = Vector2(420, 460)
	_fit(s1, 460.0, 110.0)
	s1.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inside.get_child(0).add_child(s1)
	_vessel_box = VBoxContainer.new()
	_vessel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s1.add_child(_vessel_box)
	var yours := _panel("Put in")
	yours.custom_minimum_size = Vector2(360, 0)
	row.add_child(yours)
	var s2 := ScrollContainer.new()
	s2.custom_minimum_size = Vector2(360, 460)
	_fit(s2, 460.0, 110.0)
	s2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	yours.get_child(0).add_child(s2)
	_vessel_add = VBoxContainer.new()
	_vessel_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s2.add_child(_vessel_add)


func _item_row(id: String, text: String, button: String, cb: Callable, disabled := false) -> Control:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var icon := ItemIcon.new()
	icon.id = id
	icon.custom_minimum_size = Vector2(36, 36)
	r.add_child(icon)
	var l := _small(text, Color(1, 1, 1, 0.9))
	l.custom_minimum_size = Vector2(200, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var b := _button(button, cb)
	b.disabled = disabled
	r.add_child(b)
	return r


func _vessel_do(what: String, arg = null) -> void:
	## A button in the vessel window: take item k out, or put something in
	## from your bag (the first slot holding it).
	var v := vessel
	if v == null or not is_instance_valid(v):
		return
	var inv = Game.inventory
	var why := ""
	match what:
		"take":
			v.take_to_bag(int(arg))
		"pick":
			var k := int(arg)
			if k in _pot_pick:
				_pot_pick.erase(k)
			elif _pot_pick.size() < Preserves.MAX:
				_pot_pick.append(k)
		"fill_pot":
			why = fill_pot_from(v)
			if why == "" and visible and player and player.world and player.world.has_method("toggle_inventory"):
				player.world.toggle_inventory()  # done: back to the world
				return
		"food":
			var i: int = inv.find(String(arg))
			if i >= 0:
				why = v.add_food(String(arg), inv.slots[i].age)
				if why == "":
					inv.take(i, 1)
		"salt":
			why = v.add_salt()
			if why == "":
				inv.remove("salt", 1)
		"pour":
			var i: int = inv.find(String(arg))
			if i >= 0:
				why = v.pour(v.POURS[String(arg)])
				if why == "":
					inv.replace(i, Items.def(String(arg)).get("empty", "pot"))
	if why != "":
		Game.notify(why)
	Sfx.play("click", -12.0)
	_refresh()


func _refresh_vessel() -> void:
	var v := vessel
	if v == null or not is_instance_valid(v):
		return
	_clear(_vessel_box)
	_clear(_vessel_add)
	if _pot_vessel != v:
		_pot_vessel = v
		_pot_pick.clear()
	var title: Label = (_vessel_page.get_child(0).get_child(0) as VBoxContainer).get_child(0)
	_vessel_page.get_child(1).visible = not filling  # what you can put in
	if filling:
		title.text = "Fill a Clay Pot"
		_fill_pot_page(v)
		return
	title.text = Items.item_name(v.item_id)
	for line in v.tooltip(player).split("\n").slice(1):
		_vessel_box.add_child(_small(line, Color(0.95, 0.9, 0.7)))
	var how: String = {"lacto": "Pickling: food in clean water is pickled after a day. Keep no more food than water, no raw meat, and no more than 30% of it meat not yet pickled.",
		"alcohol": "Brewing: food in clean water ferments in a day, preserving it in alcohol; then a canteen draws alcohol off (a serving of water each). Keep no more food than water, no raw meat, and no more than 30% of it meat not yet preserved. Add salt to salt instead.",
		"salt": "Salting: food is salted the moment it goes in, while there is at least as much water and as much salt as food. Taking food out takes a measure of salt with it."}[v.mode()]
	_vessel_box.add_child(_small(how, Color(1, 1, 1, 0.6), 12))
	_vessel_box.add_child(HSeparator.new())
	if v.items.is_empty():
		_vessel_box.add_child(_small("No food in it."))
	for k in v.items.size():
		var it: Dictionary = v.items[k]
		var note := ""
		if Items.cure_of(it.id) == "" and it.id != "rotten" and v.mode() != "salt":
			note = "  (%s to go)" % v._hours(v.FERMENT_TIME - it.t)
		_vessel_box.add_child(_item_row(it.id, Items.item_name(it.id) + note, "Take", _vessel_do.bind("take", k)))
	# What you can put in.
	var seen := {}
	for s in Game.inventory.slots:
		if s == null or seen.has(s.id):
			continue
		seen[s.id] = true
		var n: int = Game.inventory.count(s.id)
		if v.POURS.has(s.id):
			_vessel_add.add_child(_item_row(s.id, "%s (%d)" % [Items.item_name(s.id), n], "Pour in", _vessel_do.bind("pour", s.id)))
		elif s.id == "salt" and v.sealed():
			_vessel_add.add_child(_item_row(s.id, "Salt (%d)" % n, "Add", _vessel_do.bind("salt")))
		elif Items.can_cure(s.id):
			var w: String = v.would_spoil(s.id)
			_vessel_add.add_child(_item_row(s.id, "%s (%d)%s" % [Items.item_name(s.id), n, "\nWould go rancid: " + w if w != "" else ""],
					"Put in", _vessel_do.bind("food", s.id)))
	if _vessel_add.get_child_count() == 0:
		_vessel_add.add_child(_small("You carry nothing that goes in it: fresh food, boiled water in a pot or canteen%s." % (", or salt" if v.sealed() else "")))


func _fill_pot_page(v: Node) -> void:
	## Holding an empty clay pot at the vessel (E): pick 1-4 of its preserved
	## items to draw into the pot with one serving of the liquid.
	var ready: Array = v.preserved_indices()
	_pot_pick = _pot_pick.filter(func(k): return k in ready)
	var why: String = v.fill_blocker()
	if why == "" and Game.inventory.count("pot") < 1:
		why = "You have no empty clay pot."
	if why != "":
		_vessel_box.add_child(_small(why))
		return
	_vessel_box.add_child(_small("Pick 1 to %d preserved items from the %s. They go in with one serving of the %s." \
			% [Preserves.MAX, Items.item_name(v.item_id).to_lower(), Preserves.FLUIDS[v.mode()]], Color(0.95, 0.9, 0.7)))
	_vessel_box.add_child(HSeparator.new())
	for k in ready:
		var picked: bool = k in _pot_pick
		_vessel_box.add_child(_item_row(v.items[k].id, Items.item_name(v.items[k].id), "Picked" if picked else "Pick",
				_vessel_do.bind("pick", k), not picked and _pot_pick.size() >= Preserves.MAX))
	_vessel_box.add_child(HSeparator.new())
	var fill := _button("Fill the pot (%d)" % _pot_pick.size(), _vessel_do.bind("fill_pot"))
	fill.disabled = _pot_pick.is_empty()
	_vessel_box.add_child(fill)


func fill_pot_from(v: Node) -> String:
	## Draws the picked items and a serving of liquid into an empty clay pot
	## from the bag. Returns why not, or "".
	var inv = Game.inventory
	var i: int = inv.selected if inv.held_id() == "pot" else inv.find("pot")
	if i < 0:
		return "You have no empty clay pot."
	var got: Dictionary = v.fill_pot(_pot_pick)
	if got.has("why"):
		return got.why
	_pot_pick.clear()
	inv.replace(i, "pot_preserves", 0.0, Preserves.filled_data(got.items, got.fluid))
	Sfx.play("splash", -10.0, 0.2)
	Game.notify("You fill the clay pot: %s. Seal it with a wooden cap and wax (Craft) to keep it." % Preserves.listing(got.items))
	return ""


func _on_open() -> void:
	var i := _focus_slot()
	if i >= 0 and player != null:
		player.use_preserves(i)
		_refresh()


# --- Recipe book -----------------------------------------------------------------------
# Read-only: what you know how to make, by category. Recipes of tiers whose
# workbench you have not built yet stay hidden (Game.tiers). Recipes that need
# a tool on a workbench's rack have a page of their own (Items.ADVANCED),
# grouped by tool, and only once you have made or held it (Game.tools_known).
# One with `listed` (the soup pot) is listed in its own category instead,
# also only once you know the tool.

static func on_rack_page(r: Dictionary) -> bool:
	return r.has("rack") and not r.get("listed", false)


func _build_book(parent: Control) -> void:
	var p := _panel("Recipe book")
	p.visible = false
	parent.add_child(p)
	_book_page = p
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.get_child(0).add_child(row)
	var cscroll := ScrollContainer.new()
	cscroll.custom_minimum_size = Vector2(186, 470)
	cscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(cscroll)
	_fit(cscroll, 470.0, 110.0)
	_cats = VBoxContainer.new()
	_cats.custom_minimum_size = Vector2(170, 0)
	cscroll.add_child(_cats)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 470)
	_fit(scroll, 470.0, 110.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_book = VBoxContainer.new()
	_book.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book.add_theme_constant_override("separation", 10)
	scroll.add_child(_book)


func book_categories() -> Array:
	## Categories with at least one recipe you can see, then the rack tools page.
	var known: Array = Items.recipes_for(where, Game.tiers).filter(func(r): return not on_rack_page(r) and Game.knows_recipe(r))
	var cats: Array = Items.CATEGORIES.filter(func(c): return known.any(func(r): return r.cat == c))
	if not book_rack_tools().is_empty():
		cats.append(Items.ADVANCED)
	return cats


func book_rack_tools() -> Array:
	## The rack tools you know that have recipes, in the order they come up.
	var out := []
	for r in Items.recipes_for(where, Game.tiers):
		if on_rack_page(r) and Game.knows_recipe(r) and not r.rack in out:
			out.append(r.rack)
	return out


func _refresh_book() -> void:
	var cats := book_categories()
	if not _cat in cats:
		_cat = cats[0] if not cats.is_empty() else ""
	for c in _cats.get_children():
		c.queue_free()
	for c in cats:
		var b := Button.new()
		b.text = c
		b.toggle_mode = true
		b.button_pressed = c == _cat
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_set_cat.bind(c))
		_cats.add_child(b)
	var note := Label.new()
	note.text = "\nCraft by pressing C to kneel and work on the ground in front of you, or at a workbench."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(170, 0)
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color(1, 1, 1, 0.6)
	_cats.add_child(note)
	for c in _book.get_children():
		c.queue_free()
	if _cat == Items.ADVANCED:
		for tool in book_rack_tools():
			var head := Label.new()
			var carried: bool = Items.RECIPES.any(func(r): return r.get("rack", "") == tool and r.get("rack_or_bag", false))
			head.text = "At a workbench with the %s on its rack%s" % [Items.item_name(tool), " (or in your bag)" if carried else ""]
			head.add_theme_font_size_override("font_size", 14)
			head.modulate = Color(0.9, 0.85, 0.6)
			_book.add_child(head)
			for r in Items.recipes_for(where, Game.tiers):
				if r.get("rack", "") == tool and on_rack_page(r):
					_book.add_child(_book_entry(r))
		return
	for tier in Items.TIERS:
		var list: Array = Items.recipes_for(where, [tier]).filter(func(r): return r.cat == _cat and not on_rack_page(r) and Game.knows_recipe(r))
		if list.is_empty() or not tier in Game.tiers:
			continue
		var head := Label.new()
		head.text = Items.TIER_NAMES[tier]
		head.add_theme_font_size_override("font_size", 14)
		head.modulate = Color(0.9, 0.85, 0.6)
		_book.add_child(head)
		var shown := {}
		for r in list:
			var g := Items.book_group(r)
			if g != "":
				if shown.has(g):
					continue  # one entry for every way of making it
				shown[g] = true
			_book.add_child(_book_entry(r))


func _set_cat(c: String) -> void:
	_cat = c
	_refresh_book()


func _book_entry(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var g: Dictionary = Items.BOOK_GROUPS.get(Items.book_group(r), {})
	var icon := ItemIcon.new()
	icon.id = g.get("icon", r.out)
	icon.custom_minimum_size = Vector2(56, 56)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title := Label.new()
	title.text = g.get("title", Items.item_name(r.out) + (" x%d" % r.n if r.n > 1 else ""))
	title.add_theme_font_size_override("font_size", 17)
	col.add_child(title)
	var parts := []
	for id in r.in:
		parts.append("%d %s" % [r.in[id], Items.item_name(id)])
	var lines := ["Needs: " + ", ".join(parts)]
	if not g.is_empty():
		var needs: String = g.needs
		if "%s" in needs:
			var kinds := []
			for o in Items.RECIPES:
				if Items.book_group(o) == Items.book_group(r):
					kinds.append(Items.item_name(o.in.keys()[0]).trim_suffix(" Carcass"))
			needs = needs % ", ".join(kinds)
		lines = ["Needs: " + needs]
	for id in r.get("tools", {}):
		lines.append("Tool (kept): " + Items.item_name(id))
	if r.has("tool_tag"):
		lines.append("Tool (kept): any %s" % Items.TAG_TOOLS.get(r.tool_tag, r.tool_tag))
	if r.has("wear"):
		lines.append("Sharpening wears the %s: %d use%s off it" % [Items.item_name(r.wear).to_lower(), r.sharpen.size(), "" if r.sharpen.size() == 1 else "s"])
	if r.has("rack"):
		lines.append("On the workbench rack: " + Items.item_name(r.rack) + (" (or in your bag)" if r.get("rack_or_bag", false) else ""))
	lines.append("%s: %s" % [g.get("verb", r.verb), Settings.hint(g.get("how", r.how))])
	var body := Label.new()
	body.text = "\n".join(lines)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(380, 0)
	body.add_theme_font_size_override("font_size", 13)
	col.add_child(body)
	if r.act == "knap":
		var pat := KnapPattern.new()
		pat.pattern = Items.knap_grid(r.knap)
		pat.custom_minimum_size = Vector2(56, 56)
		row.add_child(pat)
	return row


class ItemIcon extends Control:
	var id := ""

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.11, 0.07, 0.9))
		Icons.draw_item(self, Rect2(Vector2.ZERO, size).grow(-4), id)


class KnapPattern extends Control:
	## The shape to leave when knapping, as a small 5x5 grid.
	var pattern: Array = []

	func _draw() -> void:
		var c := size.x / 5.0
		for k in 25:
			var r := Rect2((k % 5) * c, (k / 5) * c, c - 1, c - 1)
			draw_rect(r, Color(0.46, 0.48, 0.42) if pattern[k] else Color(0.1, 0.12, 0.09))
