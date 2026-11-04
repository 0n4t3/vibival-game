extends StaticBody3D
## A compost basket set down on the ground (group "composters", saved with
## the world). Fill it (E) with food, sticks, branches, guts or a carried log
## (wood_log.gd) up to level FULL: most things add 2, a grub 1, a branch 4,
## a log 10.
## Full, it composts for DAYS game days: twice as long if a stick or branch
## went in, four times with a log (the slowest one counts, they don't add up).
## Then E takes out YIELD compost and it is empty again. Meat in it may draw a
## pest beside it each time you sleep (swamp.sleep → pest_roll).

const FULL := 20
const DAYS := 15.0
const YIELD := 5
const PEST_CHANCE := 0.15
const PESTS := ["scorpion", "arthropleura"]
const WOODY := {"stick": 2.0, "branch": 2.0, "log": 4.0, "log_stripped": 4.0}

var level := 0
var slow := 1.0       # how many times longer than DAYS it takes (WOODY)
var meat := false     # meat went in: pests may come (cleared when emptied)
var done_at := -1.0   # the Game.time it is compost, once full

var _fill: MeshInstance3D


static func worth(id: String) -> int:
	## How much one of the item adds to the level, or 0 if it can't go in.
	var d: Dictionary = Items.def(id)
	if d.is_empty():
		return 0
	if id == "branch":
		return 4
	if id in ["log", "log_stripped"]:
		return 10
	if Items.base_of(id) in ["grub", "roast_grub"]:
		return 1  # a grub is small
	if id in ["stick", "guts"] or id.ends_with("_carcass"):
		return 2
	if d.has("energy") and not Items.is_drink_container(id):
		return 2  # any food (not a drink in its pot or canteen)
	return 0


static func is_meat(id: String) -> bool:
	if id in ["grub", "roast_grub"]:
		return false
	return id == "guts" or id.ends_with("_carcass") or float(Items.def(id).get("protein", 0.0)) > 0.0


func _ready() -> void:
	add_to_group("composters")
	collision_layer = 3
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Assets.COMPOST_W, Assets.COMPOST_H, Assets.COMPOST_W)
	cs.shape = box
	cs.position.y = Assets.COMPOST_H * 0.5
	add_child(cs)
	var m := MeshInstance3D.new()
	m.mesh = Assets.mesh("compost_basket")
	m.visibility_range_end = 80.0
	add_child(m)
	_fill = MeshInstance3D.new()
	_fill.visibility_range_end = 60.0
	add_child(_fill)
	_refresh()


func full() -> bool:
	return done_at >= 0.0


func is_done() -> bool:
	return full() and Game.time >= done_at


func days() -> float:
	return DAYS * slow


func _refresh() -> void:
	if _fill == null:
		return
	_fill.visible = level > 0
	_fill.mesh = Assets.mesh("compost_done" if is_done() else "compost_fill")
	_fill.scale = Vector3(1.0, maxf(Assets.COMPOST_H * 0.92 * level / float(FULL), 0.02), 1.0)


func _process(_delta: float) -> void:
	if full() and _fill.mesh != Assets.mesh("compost_done") and is_done():
		_refresh()


func prompt(_player: Node) -> String:
	if is_done():
		return "Take the compost [E]   (%d)" % YIELD
	if full():
		var left := (done_at - Game.time) / Game.DAY_LENGTH
		return "Compost Basket: composting, %s left" % _days_text(left)
	var id: String = Game.inventory.held_id()
	var w := worth(id)
	if w > 0:
		var note := ""
		if WOODY.get(id, 1.0) > slow:
			note = ", slows it to %d days" % roundi(DAYS * WOODY[id])
		return "Put the %s in the compost [E]   (+%d: %d / %d%s)" % [Items.item_name(id), w, mini(level + w, FULL), FULL, note]
	if level == 0 and id == "":
		return "Pick up the compost basket [E]"
	if id != "":
		return "Compost Basket (%d / %d): the %s won't rot down" % [level, FULL, Items.item_name(id).to_lower()]
	return "Compost Basket (%d / %d): fill it with food, sticks, branches, guts or logs" % [level, FULL]


func _days_text(d: float) -> String:
	if d >= 1.0:
		return "%d days" % ceili(d)
	return "%d min" % maxi(ceili(d * Game.DAY_LENGTH / 60.0), 1)


func interact(player: Node) -> void:
	var inv = Game.inventory
	if is_done():
		var left: int = inv.add("compost", YIELD)
		if left > 0 and player.world and player.world.has_method("pile_item"):
			player.world.pile_item("compost", left, global_position + global_basis.x * 0.7 + Vector3(0, 0.3, 0))
		Game.picked.emit("compost")
		Sfx.play("pickup", -6.0)
		Game.notify("You dig out the compost: Compost x%d." % YIELD)
		level = 0
		slow = 1.0
		meat = false
		done_at = -1.0
		_refresh()
		return
	if full():
		return
	var id: String = inv.held_id()
	if worth(id) > 0:
		inv.take(inv.selected, 1)
		add(id)
		return
	if level == 0 and id == "" and inv.add("compost_basket", 1) == 0:
		Sfx.play("pickup", -8.0)
		queue_free()


func add(id: String) -> void:
	## One of the item goes in (a carried log too: wood_log.gd).
	level = mini(level + worth(id), FULL)
	slow = maxf(slow, WOODY.get(id, 1.0))
	meat = meat or is_meat(id)
	Sfx.play("rustle", -6.0)
	if level >= FULL:
		done_at = Game.time + days() * Game.DAY_LENGTH
		Game.notify("The compost basket is full. It will be compost in %d days." % roundi(days()))
	_refresh()


func pest_roll(rng: RandomNumberGenerator) -> String:
	## On waking: meat in it may have drawn a pest. Returns its species, or "".
	if not meat or level == 0 or rng.randf() >= PEST_CHANCE:
		return ""
	return PESTS[rng.randi() % PESTS.size()]


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "level": level, "slow": slow, "meat": meat, "done_at": done_at}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	level = int(d.get("level", 0))
	slow = float(d.get("slow", 1.0))
	meat = bool(d.get("meat", false))
	done_at = float(d.get("done_at", -1.0))
	_refresh()
