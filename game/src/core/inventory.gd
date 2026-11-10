extends RefCounted
## Weight-limited inventory. Slots only organise items: what you can carry is
## limited by weight. Each slot is null or {"id": String, "n": int, "age": float},
## plus "data" (a Dictionary overriding the item's fields, see Items) for an item
## that is one of a kind, like a pot of soup; those never stack.
## The first HOTBAR slots double as the hotbar; the selected one is held in hand.
## Perishable items age while carried and turn into "rotten" when spoiled
## (or into their "spoil" item: a lit torch burns down to a charred stick; an
## empty "spoil", like an ember's, leaves nothing).
##
## Carrying more than capacity() slows you down; nothing can be added past
## OVERLOAD times the capacity.

signal changed

const SIZE := 30
const HOTBAR := 6
const BASE_CAPACITY := 8.0   # kg you can carry in your hands and arms
const SACK_CAPACITY := 25.0  # kg with a woven frond sack (its `carry` of 17 on top of BASE)
const OVERLOAD := 1.5

var slots: Array = []
var selected := 0
var capacity_override := 0.0  # > 0 replaces the normal limit (the lab tutorial, a stash)
var overload := OVERLOAD       # how far past capacity it can be filled (1 = not at all)
var arm_broken := false        # the player's arm is broken: half the carrying, but not the sack's share
var strength := 1.0            # the player's condition (Survival.carry_mult)


func _init() -> void:
	slots.resize(SIZE)


func weight() -> float:
	var total := 0.0
	for s in slots:
		if s != null:
			total += Items.slot_weight(s) * s.n
	return total


func capacity() -> float:
	if capacity_override > 0.0:
		return capacity_override
	var arms := BASE_CAPACITY * (0.5 if arm_broken else 1.0)
	return (arms + sack_bonus()) * strength


func sack_bonus() -> float:
	## The kg the best sack you carry adds (an item's `carry_kg`; not `carry`, which means too big for the bag). Sacks don't
	## add up: any others only weigh you down.
	var best := 0.0
	for s in slots:
		if s != null:
			best = maxf(best, float(Items.def(s.id).get("carry_kg", 0.0)))
	return best


func load_ratio() -> float:
	## 0 when empty, 1 at capacity, up to OVERLOAD when overloaded.
	return weight() / capacity()


func room_for(id: String, data := {}) -> int:
	## How many more of `id` (with slot `data`) fit under the overload limit.
	var w := Items.slot_weight({"id": id, "data": data})
	if w <= 0.0:
		return 1 << 20
	return maxi(floori((capacity() * overload - weight()) / w + 0.0001), 0)


func add(id: String, n := 1, age := 0.0, force := false, data := {}) -> int:
	## Adds items, filling existing stacks first. Returns how many did not fit
	## (because of weight or because every slot is taken). `force` ignores weight.
	## A stack keeps the age of its oldest item.
	## Items with `data` each take a slot of their own.
	var rejected := 0
	if not force:
		var fit := mini(n, room_for(id, data))
		rejected = n - fit
		n = fit
	var max_n := 1 if not data.is_empty() else Items.max_stack(id)
	for i in SIZE:
		var s = slots[i]
		if n > 0 and data.is_empty() and s != null and s.id == id and not s.has("data") and s.n < max_n:
			var k := mini(n, max_n - s.n)
			s.age = maxf(s.age, age)  # a stack is as far gone as its oldest: new ones never freshen it
			s.n += k
			n -= k
	for i in SIZE:
		if n > 0 and slots[i] == null:
			var k := mini(n, max_n)
			slots[i] = {"id": id, "n": k, "age": age}
			if not data.is_empty():
				slots[i].data = data.duplicate(true)
			n -= k
	changed.emit()
	return n + rejected


func count(id: String) -> int:
	var total := 0
	for s in slots:
		if s != null and s.id == id:
			total += s.n
	return total


func has_tag(tag: String) -> bool:
	for s in slots:
		if s != null and tag in Items.def(s.id).get("tags", []):
			return true
	return false


func find(id: String) -> int:
	for i in SIZE:
		if slots[i] != null and slots[i].id == id:
			return i
	return -1


func remove(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	for i in range(SIZE - 1, -1, -1):
		var s = slots[i]
		if n > 0 and s != null and s.id == id:
			var k := mini(n, s.n)
			s.n -= k
			n -= k
			if s.n <= 0:
				slots[i] = null
	changed.emit()
	return true


func take(i: int, n := 1) -> Dictionary:
	## Removes up to n items from slot i and returns them as a stack (or {}).
	var s = slots[i]
	if s == null:
		return {}
	var k := mini(n, s.n)
	s.n -= k
	if s.n <= 0:
		slots[i] = null
	changed.emit()
	var out := {"id": s.id, "n": k, "age": s.age}
	if s.has("data"):
		out.data = s.data
	return out


func replace(i: int, id: String, age := 0.0, data := {}) -> void:
	## Turns the one item in slot i into another in the same slot (a pot
	## filled, a canteen drunk from), so what you hold stays in your hand.
	## A stack only gives up one of its items, and the new one goes elsewhere.
	var s = slots[i]
	if s != null and s.n > 1:
		take(i, 1)
		add(id, 1, age, true, data)
		return
	slots[i] = {"id": id, "n": 1, "age": age}
	if not data.is_empty():
		slots[i].data = data.duplicate(true)
	changed.emit()


func def_of(i: int) -> Dictionary:
	## Slot i's item definition, with its own data (a soup's serving) over it.
	var s = slots[i]
	if s == null:
		return {}
	var d := Items.def(s.id)
	return d.merged(s.data, true) if s.has("data") else d


func held() -> Variant:
	return slots[selected]


func held_id() -> String:
	var s = slots[selected]
	return s.id if s != null else ""


func select(i: int) -> void:
	selected = posmod(i, HOTBAR)
	changed.emit()


func swap(a: int, b: int) -> void:
	var sa = slots[a]
	var sb = slots[b]
	if sa != null and sb != null and sa.id == sb.id and a != b and not sa.has("data") and not sb.has("data"):
		var max_n := Items.max_stack(sa.id)
		var k := mini(sa.n, max_n - sb.n)
		sb.n += k
		sa.n -= k
		if sa.n <= 0:
			slots[a] = null
	else:
		slots[a] = sb
		slots[b] = sa
	changed.emit()


func uses_left(i: int) -> int:
	## How many uses the tool in slot i has left (see Items.uses_data): a
	## fresh one has its item's full `uses`.
	var s = slots[i]
	if s == null:
		return 0
	if s.has("data") and s.data.has("uses_left"):
		return int(s.data.uses_left)
	return int(Items.def(s.id).get("uses", 0))


func most_uses(id: String) -> int:
	## The most uses left on any one `id` carried (0 with none).
	var best := 0
	for i in SIZE:
		if slots[i] != null and slots[i].id == id:
			best = maxi(best, uses_left(i))
	return best


func wear(id: String, need := 1) -> int:
	## Wears one use off an `id` with at least `need` uses left, the most worn
	## first. Returns how many it has left (0: worn down and gone), or -1 if
	## none would do.
	var best := -1
	for i in SIZE:
		if slots[i] != null and slots[i].id == id and uses_left(i) >= need and (best < 0 or uses_left(i) < uses_left(best)):
			best = i
	if best < 0:
		return -1
	var left := uses_left(best) - 1
	if left <= 0:
		take(best, 1)
	else:
		replace(best, id, slots[best].age, Items.uses_data(id, left))
	return left


func count_as(want: String) -> int:
	## How many will do in a recipe for `want` (see Items.counts_as).
	var total := 0
	for s in slots:
		if s != null and Items.counts_as(s.id, want):
			total += s.n
	return total


func can_craft(recipe: Dictionary) -> bool:
	for id in recipe.in:
		if count_as(id) < recipe.in[id]:
			return false
	return true


func craft(recipe: Dictionary) -> bool:
	## Crafting always succeeds when you have the parts, even if the result
	## leaves you overloaded.
	if not can_craft(recipe):
		return false
	for id in recipe.in:
		var n: int = recipe.in[id]
		# Exact items first, then anything that will do (any tree's board).
		var k := mini(count(id), n)
		remove(id, k)
		n -= k
		for i in range(SIZE - 1, -1, -1):
			var st = slots[i]
			if n > 0 and st != null and Items.counts_as(st.id, id):
				var t := mini(n, st.n)
				take(i, t)
				n -= t
	return add(recipe.out, recipe.n, 0.0, true) == 0


func tick(delta: float) -> void:
	## Ages perishables; emits `changed` only if something spoiled.
	var spoiled := false
	for i in SIZE:
		var s = slots[i]
		if s == null:
			continue
		var life: float = Items.def(s.id).get("decay", 0.0)
		if life <= 0.0:
			continue
		s.age += delta
		if s.age >= life:
			slots[i] = null
			var into: String = Items.def(s.id).get("spoil", "rotten")
			if into != "":
				add(into, s.n, 0.0, true)
			spoiled = true
	if spoiled:
		changed.emit()


func durability(i: int) -> float:
	## How much is left (0..1) of an item used a measure at a time (a canteen of
	## alcohol: Items `measures`, with what is left in the slot's data), or -1
	## for anything else.
	var s = slots[i]
	if s == null:
		return -1.0
	var total := int(Items.def(s.id).get("measures", 0))
	if total <= 0:
		return -1.0
	var left := int(s.get("data", {}).get("left", total))
	return clampf(float(left) / total, 0.0, 1.0)


func freshness(i: int) -> float:
	var s = slots[i]
	if s == null:
		return 1.0
	var life: float = Items.def(s.id).get("decay", 0.0)
	return 1.0 if life <= 0.0 else clampf(1.0 - s.age / life, 0.0, 1.0)


func clear() -> void:
	slots.clear()
	slots.resize(SIZE)
	changed.emit()


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "selected": selected}


func from_dict(d: Dictionary) -> void:
	clear()
	var src: Array = d.get("slots", [])
	for i in mini(src.size(), SIZE):
		var s = src[i]
		if s != null and Items.exists(s.id):
			slots[i] = {"id": s.id, "n": int(s.n), "age": float(s.age)}
			if s.get("data") is Dictionary and not s.data.is_empty():
				slots[i].data = s.data.duplicate(true)
	selected = int(d.get("selected", 0))
	changed.emit()
