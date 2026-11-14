extends RefCounted
## Preserving pots. Holding an empty clay pot, E at a fermentation vessel
## opens a menu to pick 1 to MAX of its preserved items (pickled, alcohol-
## preserved or salted); they go in with one serving of its liquid, however
## many items. That makes an Unsealed Pot of Preserves ("pot_preserves"),
## showing what it holds, its food ageing as it would in the bag. The hand
## recipe "pot_sealed" seals it with a wooden cap and a lump of wax
## (work_spot.gd carries the contents over, sealed_data): nothing in it ages
## while sealed, and it shows nothing of what is inside. Opening either (Use)
## puts all the food in your bag and leaves the empty clay pot; a sealed pot
## gives the cap back, never the wax, and the liquid is poured away.
##
## Everything is in the pot's slot data: {"items": [{id, age}], "fluid",
## "w" (its weight), and while it is open "since" (Game.time it was filled,
## which its food ages from), "name" and "desc"}.

const MAX := 4
const SERVING_W := 1.5                 # a serving of liquid, as in a pot of water
const FLUIDS := {"lacto": "pickling brine", "salt": "salt brine", "alcohol": "alcohol"}


static func weight_of(items: Array) -> float:
	var w: float = Items.weight("pot") + SERVING_W
	for it in items:
		w += Items.weight(String(it.id))
	return w


static func filled_data(items: Array, fluid: String) -> Dictionary:
	## An open pot's data, filled now.
	var kept := []
	for it in items:
		kept.append({"id": String(it.id), "age": float(it.get("age", 0.0))})
	return {"items": kept, "fluid": fluid, "since": Game.time, "w": weight_of(kept),
		"name": "Unsealed Pot of Preserves (%d)" % kept.size(),
		"desc": "An open clay pot of %s holding %s. Seal it with a wooden cap and a lump of wax (Craft) and nothing in it spoils; or open it (Use) to take the food out." % [fluid, listing(kept)]}


static func listing(items: Array) -> String:
	## "Pickled Fiddlehead x2, Salted Meat".
	var n := {}
	var order := []
	for it in items:
		if not n.has(it.id):
			order.append(it.id)
		n[it.id] = n.get(it.id, 0) + 1
	return ", ".join(order.map(func(id): return Items.item_name(id) + (" x%d" % n[id] if n[id] > 1 else "")))


static func contents(data: Dictionary) -> Array:
	## The food in it as it is now: an open pot's has aged since it was filled.
	var aged: float = maxf(Game.time - float(data.since), 0.0) if data.has("since") else 0.0
	var out := []
	for it in data.get("items", []):
		out.append({"id": String(it.id), "age": float(it.age) + aged})
	return out


static func sealed_data(d: Dictionary) -> Dictionary:
	## A sealed pot's data from an open pot's: its food as old as it is now,
	## and nothing to show what it is.
	var items := contents(d)
	return {"items": items, "fluid": String(d.get("fluid", "")), "w": float(d.get("w", weight_of(items)))}


static func open(inv, i: int) -> Array:
	## Empties the pot in slot i into the bag, leaving the clay pot there (and
	## a sealed pot's cap). Returns what didn't fit: [{id, age}].
	var s = inv.slots[i]
	if s == null or not Items.def(s.id).get("preserves", false):
		return []
	var was_sealed: bool = s.id == "pot_sealed"
	var items := contents(s.get("data", {}))
	inv.replace(i, "pot")
	var spilled := []
	for it in items:
		if inv.add(it.id, 1, it.age, true) > 0:
			spilled.append(it)
	if was_sealed and inv.add("wooden_cap", 1, 0.0, true) > 0:
		spilled.append({"id": "wooden_cap", "age": 0.0})
	return spilled
