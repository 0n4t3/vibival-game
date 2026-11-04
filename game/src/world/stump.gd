extends StaticBody3D
## The stump a felled tree leaves (see chunk.gd). A new tree grows up out of
## it over about 18 days and takes the old one's place once it is full grown
## and can be felled again. Swinging a mattock at it DIG_HITS times digs it
## out, roots and all, for some firewood; then nothing grows there again.
##
## A stump struck by lightning (`state.burnt`: the Game.time it was struck,
## see swamp.strike_tree) never grows back. It burns for BURN_FOR, glows with
## hot cinders for GLOW_FOR after that, and then stays a charred stump. While
## it burns or glows you can take an ember from it (E), and while it burns
## light a torch at it. It is too hot to dig out until it has gone cold.
##
## Digging one out gives its root, which can be planted (plot.gd). A tree
## grown from a planted root comes up as a stump with no stump to see
## (`state.planted`), just the young tree. While a Calamites or tree fern is
## young (SHOOT_UNTIL of its growth) its shoot can be picked to eat, and it
## starts growing again from its roots, with no new shoot to pick for a day
## (`state.picked`).

const DIG_HITS := 5
const ROOT_WOOD := [2, 3]   # firewood from the roots
const BURN_FOR := 1440.0    # a struck stump burns for a day
const GLOW_FOR := 3.0 * 1440.0  # then glows with hot cinders for three
const CHARRED := Color(0.22, 0.18, 0.15)
const Harvestable := preload("res://src/world/harvestable.gd")
const SHOOT_UNTIL := 1.0 / 3.0
const SHOOTS := {"calamites": "calamites_shoot", "tree_fern": "tree_fern_shoot"}

var chunk: Node3D
var tree: Dictionary
var state: Dictionary
var hits := 0

var _sapling: MeshInstance3D
var _grown := -1.0
var _tick := 0.0
var _stump_mesh: MeshInstance3D
var _fire: Node3D          # flames, cinders, light and sound while it burns or glows
var _flames: MeshInstance3D
var _cinders: MeshInstance3D
var _light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _shown := "-"          # the phase the looks were last built for
var _flicker := 0.0


func setup(c: Node3D, t: Dictionary, st: Dictionary) -> Node3D:
	chunk = c
	tree = t
	state = st
	return self


func _ready() -> void:
	collision_layer = 1 | 2
	collision_mask = 0
	set_meta("hard", true)
	var s: float = tree.s
	var top: float = chunk.SINK + chunk.STUMP_H
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = tree.r if not planted() else 0.15
	cyl.height = top if not planted() else top + 0.6
	cs.shape = cyl
	cs.position.y = cyl.height * 0.5
	add_child(cs)
	_stump_mesh = MeshInstance3D.new()
	_stump_mesh.scale = Vector3.ONE * s
	_stump_mesh.visibility_range_end = 80.0
	add_child(_stump_mesh)
	_sapling = MeshInstance3D.new()
	_sapling.mesh = Assets.mesh(tree.kind)
	_sapling.visibility_range_end = Settings.view_distance
	add_child(_sapling)
	_update()


func burnt() -> bool:
	return state.has("burnt")


func planted() -> bool:
	## Growing from a planted root: no stump, just the young tree.
	return state.get("planted", false)


func can_pick() -> bool:
	## Young enough that its shoot can be picked, and not picked in the last day.
	return shoot_young() and shoot_wait() <= 0.0


func shoot_young() -> bool:
	var g := growth()
	return SHOOTS.has(tree.kind) and not burnt() and (g > 0.01 or planted()) and g < SHOOT_UNTIL


func shoot_wait() -> float:
	## Seconds until a picked shoot has grown again (a day after it was picked), or 0.
	return maxf(float(state.get("picked", -INF)) + Game.DAY_LENGTH - Game.time, 0.0)


func phase() -> String:
	## "" (an ordinary stump), or for a struck one "burning", "cinders" or "burnt".
	if not burnt():
		return ""
	var t: float = Game.time - float(state.burnt)
	return "burning" if t < BURN_FOR else ("cinders" if t < BURN_FOR + GLOW_FOR else "burnt")


func hot() -> bool:
	return phase() in ["burning", "cinders"]


func growth() -> float:
	## How far the new tree has grown back, 0..1 (a burnt stump never does).
	if burnt():
		return 0.0
	var span: float = float(state.regrow) - float(state.at)
	return clampf((Game.time - float(state.at)) / span, 0.0, 1.0) if span > 0.0 else 1.0


func _process(delta: float) -> void:
	if _light and _light.visible:
		_flicker += delta * (9.0 if _flames.visible else 2.0)
		var f := 0.85 + 0.15 * sin(_flicker) * sin(_flicker * 1.7 + 1.0)
		_light.light_energy = (1.2 if _flames.visible else 0.5) * f
		if _flames.visible:
			_flames.scale = Vector3(1.0, f, 1.0)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 5.0
	_update()


func _update() -> void:
	var ph := phase()
	if ph != _shown:
		_show(ph)
	if burnt():
		return
	var g := growth()
	if g >= 1.0:
		chunk.regrow(tree)
		return
	# The new shoot starts small and spindly out of the stump.
	if absf(g - _grown) < 0.002:
		return
	_grown = g
	var k: float = lerpf(0.04, 1.0, g) * tree.s
	_sapling.visible = g > 0.01 or planted()  # a planted one shows as soon as it sprouts
	_sapling.scale = Vector3.ONE * k
	_sapling.position.y = chunk.SINK * (1.0 - k / tree.s)


func _show(ph: String) -> void:
	## Builds the looks for this phase: charred once struck, with flames or
	## cinders on top while it is hot.
	_shown = ph
	var s: float = tree.s
	var top: float = chunk.SINK + chunk.STUMP_H
	_stump_mesh.mesh = null if planted() else Assets.tree_part(tree.kind, -INF, top / s, false, CHARRED if ph != "" else Color(1, 1, 1))
	_sapling.visible = _sapling.visible and ph == ""
	if ph in ["burning", "cinders"] and _fire == null:
		_build_fire(top)
	if _fire:
		_fire.visible = ph in ["burning", "cinders"]
		_flames.visible = ph == "burning"
		_cinders.visible = ph != ""
		_light.visible = _fire.visible
		_light.light_color = Color(1.0, 0.6, 0.28) if ph == "burning" else Color(1.0, 0.3, 0.12)
		_light.omni_range = 8.0 if ph == "burning" else 3.5
		if ph == "burning" and not _sound.playing:
			_sound.play()
		elif ph != "burning":
			_sound.stop()


func _build_fire(top: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tree.uid)
	var r: float = tree.r
	_fire = Node3D.new()
	_fire.position.y = top
	add_child(_fire)
	var cb = Assets.builder()
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.6
		var d := rng.randf_range(0.1, 0.6) * r
		cb.blob(Vector3(cos(a) * d, 0.02, sin(a) * d), Vector3(0.09, 0.04, 0.08) * clampf(r / 0.4, 0.6, 1.4), 1, 5,
			Color(0.85, 0.18, 0.05).lerp(Color(1.0, 0.45, 0.1), rng.randf()), rng, 0.3, "glow")
	_cinders = MeshInstance3D.new()
	_cinders.mesh = cb.commit(Assets.materials)
	_cinders.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire.add_child(_cinders)
	var fb = Assets.builder()
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		var d := r * 0.45
		fb.cone(Vector3(cos(a) * d, 0.0, sin(a) * d), Vector3(cos(a) * d * 0.4, rng.randf_range(0.5, 0.8), sin(a) * d * 0.4),
			r * 0.35, 5, Color(1.0, 0.55, 0.12), "glow")
	fb.cone(Vector3.ZERO, Vector3(0, 0.55, 0), r * 0.3, 5, Color(1.0, 0.85, 0.35), "glow")
	_flames = MeshInstance3D.new()
	_flames.mesh = fb.commit(Assets.materials)
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire.add_child(_flames)
	_light = OmniLight3D.new()
	_light.position.y = 0.6
	_fire.add_child(_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.stream("fire")
	_sound.volume_db = -12.0
	_sound.max_distance = 16.0
	_fire.add_child(_sound)


func kind_name() -> String:
	return chunk.TREES[tree.kind].name


func prompt(player: Node) -> String:
	var held: String = Game.inventory.held_id()
	match phase():
		"burning":
			if held == "torch":
				return "Light the torch [E]   (burning %s stump)" % kind_name()
			return "Take an ember [E]   (burning %s stump)" % kind_name()
		"cinders":
			return "Take an ember [E]   (%s stump, glowing with cinders)" % kind_name()
	var g := growth()
	var what := "%s stump" % kind_name() if not burnt() else "Burnt %s stump" % kind_name()
	if planted():
		what = "Young %s, growing (%d%%)" % [kind_name(), roundi(g * 100.0)]
	elif g > 0.05:
		what += ", growing back (%d%%)" % roundi(g * 100.0)
	if held == "compost" and not burnt() and g < 1.0:
		return what + Harvestable.feed_hint(float(state.regrow) - Game.time)
	if "dig" in Items.def(held).get("tags", []):
		return "%s: swing the mattock to dig it %s" % [what, "up" if planted() else "out"]
	if can_pick():
		return "Pick the shoot [E]   (%s)" % what
	if shoot_young():
		return "%s; a new shoot in %d min" % [what, ceili(shoot_wait() / 60.0)]
	return what


func interact(_player: Node) -> void:
	var held: String = Game.inventory.held_id()
	match phase():
		"burning", "cinders":
			if held == "torch" and phase() == "burning":
				var inv = Game.inventory
				inv.take(inv.selected, 1)
				inv.add("torch_lit", 1, 0.0, true)
				Sfx.play("fire_start", -8.0)
				Game.notify("The torch catches.")
				return
			if Game.inventory.add("ember", 1) > 0:
				Game.notify("You have no room to carry an ember.")
				return
			Sfx.play("pickup", -8.0)
			Game.picked.emit("ember")
			Game.notify("You take a glowing ember. It will go out in about three hours: set it in a campfire with fuel and blow on it.")
			return
	if can_pick():
		var shoot: String = SHOOTS[tree.kind]
		if Game.inventory.add(shoot, 1) > 0:
			Game.notify("You have no room to carry it.")
			return
		# It starts again from its roots, taking as long as before.
		var span: float = float(state.regrow) - float(state.at)
		state.at = Game.time
		state.regrow = Game.time + span
		state.picked = Game.time  # and has no new shoot to pick for a day
		_grown = -1.0
		_update()
		Sfx.play("pickup", -8.0)
		Game.picked.emit(shoot)
		Game.notify("You pick the %s. It will sprout again from its roots, with a new shoot in a day." % Items.item_name(shoot).to_lower())
		return
	if planted():
		return
	Game.notify("Swing a mattock at the stump to dig it out." if growth() < 1.0 else "")


func feed(_player: Node) -> bool:
	## Compost worked in round the roots of the tree growing back.
	if burnt() or growth() >= 1.0:
		return false
	state.regrow = float(state.regrow) - (float(state.regrow) - Game.time) * Harvestable.FEED_CUT
	Harvestable.fed_note(float(state.regrow) - Game.time)
	_grown = -1.0
	_update()
	return true


func dig() -> void:
	## A mattock swing into the roots.
	if hot():
		Game.notify("The stump is still too hot to dig out.")
		return
	hits += 1
	Sfx.play_at("chop", global_position, -2.0, 0.2)
	var need := DIG_HITS if not planted() else 2
	if hits < need:
		Game.notify("You hack at the roots (%d / %d)." % [hits, need])
		return
	var root := "%s_root" % tree.kind
	var world: Node = Game.player.world if Game.player else null
	if Game.inventory.add(root, 1) > 0 and world and world.has_method("pile_item"):
		world.pile_item(root, 1, global_position + Vector3(0.6, 0.3, 0))
	Game.picked.emit(root)
	Sfx.play_at("thud", global_position, -6.0)
	if planted():
		Game.notify("You dig up the young %s: %s x1." % [kind_name(), Items.item_name(root)])
		chunk.clear_stump(tree)
		return
	var n := randi_range(ROOT_WOOD[0], ROOT_WOOD[1])
	var left: int = Game.inventory.add("firewood", n)
	if left > 0 and world and world.has_method("pile_item"):
		world.pile_item("firewood", left, global_position + Vector3(0.8, 0.3, 0))
	Game.picked.emit("firewood")
	Game.notify("You dig out the stump: %s x1, and root wood: Firewood x%d." % [Items.item_name(root), n])
	chunk.clear_stump(tree)
