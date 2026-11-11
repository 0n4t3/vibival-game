extends "res://src/world/site.gd"
## A clay furnace (group "furnaces", metals.md): all the hot work with copper,
## smelting ore and casting it in moulds, is done kneeling at it (C, work_spot
## station "furnace"). Its stone ring is laid by hand (items.gd, `build`
## "furnace"); the rest goes up part by part like a house: a coiled clay
## shaft, the tuyere, a first firing to harden it and two blowpipes.
##
## Finished, it has a `heat` from 0 to 1, shown by its glow (dull red, cherry,
## orange). Every click while casting or smelting is a breath down the
## blowpipes (blow): it raises the heat, and while the copper melts a step
## only counts at full heat (HOT). Left alone the heat falls, faster in rain.
## The first finished furnace opens the "metal" recipes in the book.
##
## Local space: the origin is on the ground at the middle of the ring.

const HOT := 0.75         # full heat: orange, hot enough to melt copper
const BLOW := 0.17        # heat one breath adds
const COOL := 0.05        # heat lost a second
const WET := 1.6          # rain: it cools this much faster, and each breath does less
const RING_R := 0.48
const TOP := 1.05

const PARTS := [
	{"id": "ring", "verb": "Lay the stone ring", "in": {"stone": 8}, "steps": 4, "face": Vector3(0, 0.1, 0),
		"how": "Click to set the river stones round the hole."},
	{"id": "shaft", "verb": "Coil the clay shaft", "in": {"clay": 12, "ash": 2}, "steps": 8, "face": Vector3(0, 0.6, 0),
		"how": "Click round the ring to knead ash into the clay and coil it up, course by course, into a waist-high chimney."},
	{"id": "tuyere", "verb": "Set the tuyere", "in": {"tuyere": 1}, "steps": 2, "face": Vector3(RING_R, 0.2, 0),
		"how": "Click to cut a hole low in the shaft and seal the fired tuyere into it."},
	{"id": "firing", "verb": "Give it a first firing", "in": {"firewood": 4}, "steps": 3, "face": Vector3(0, TOP, 0),
		"how": "Click to drop firewood down the shaft and light it, drying and hardening the clay."},
	{"id": "blowpipes", "verb": "Fit the blowpipes", "in": {"blowpipe": 2}, "steps": 2, "face": Vector3(RING_R + 0.3, 0.2, 0),
		"how": "Click to seat each blowpipe in the mouth of the tuyere."},
]

var heat := 0.0
var _light: OmniLight3D
var _mouth: MeshInstance3D
var _mouth_mat: StandardMaterial3D


func parts() -> Array:
	return PARTS


func site_name() -> String:
	return "furnace" if complete() else "furnace site"


func _ready() -> void:
	super()
	if preview:
		return
	add_to_group("furnaces")
	_light = OmniLight3D.new()
	_light.position = Vector3(0, TOP + 0.2, 0)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)
	_mouth = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.22
	disc.bottom_radius = 0.22
	disc.height = 0.02
	_mouth.mesh = disc
	_mouth.position = Vector3(0, TOP - 0.05, 0)
	_mouth_mat = StandardMaterial3D.new()
	_mouth_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mouth_mat.albedo_color = Color(0.05, 0.04, 0.04)
	_mouth.material_override = _mouth_mat
	add_child(_mouth)
	_mouth.visible = complete()


func _on_complete(tell := true) -> void:
	Game.unlock_tier("metal")
	if _mouth:
		_mouth.visible = true
	if tell:
		Game.crafted.emit("furnace_built")
		Game.notify("Your furnace is finished. Kneel at it (C) with a mould, copper and charcoal laid out to cast, or sifted ore and charcoal to smelt.")


func _process(delta: float) -> void:
	if preview or not complete():
		return
	var wet: bool = world != null and bool(world.get("raining"))
	heat = maxf(heat - delta * COOL * (WET if wet else 1.0), 0.0)
	_light.light_energy = heat * 2.2
	_light.light_color = _glow(heat)
	_mouth_mat.albedo_color = Color(0.05, 0.04, 0.04).lerp(_glow(heat) * 1.6, clampf(heat * 1.4, 0.0, 1.0))


static func _glow(h: float) -> Color:
	if h < 0.5:
		return Color(0.55, 0.08, 0.03).lerp(Color(0.85, 0.15, 0.05), h * 2.0)
	return Color(0.85, 0.15, 0.05).lerp(Color(1.0, 0.55, 0.12), (h - 0.5) * 2.0)


func blow(player: Node) -> bool:
	## A breath down the blowpipes: hotter, at a little cost to you. Whether it
	## is at full heat now.
	if not complete():
		return false
	var wet: bool = world != null and bool(world.get("raining"))
	heat = minf(heat + BLOW / (WET if wet else 1.0), 1.0)
	if player and player.get("vitals"):
		player.vitals.stamina = maxf(player.vitals.stamina - 1.0, 0.0)
	Sfx.play_at("rustle", global_position, -8.0, 0.4)
	return heat >= HOT


func heat_name() -> String:
	if heat < 0.15:
		return "cold"
	if heat < 0.45:
		return "dull red"
	if heat < HOT:
		return "cherry red"
	return "orange (full heat)"


func station_kind() -> String:
	return "furnace"


# --- Interaction ----------------------------------------------------------------------------

func prompt(player: Node) -> String:
	if preview:
		return ""
	if complete():
		if player and player.hauling:
			return ""
		return "Clay furnace (%s): kneel to work at it [C]" % heat_name()
	return super(player)


func can_tear_down() -> bool:
	return not preview


func tear_down() -> void:
	## Broken up with an axe or a mattock: only the river stones are saved.
	var stones := 0
	for id in built:
		stones += int(built[id].get("stone", 0))
	if world and world.has_method("pile_item") and stones > 0:
		world.pile_item("stone", stones, drop_point() + Vector3(0, 0.3, 0))
	Sfx.play_at("hit", global_position, -2.0)
	Game.notify("You break the furnace up.%s" % (" The river stones are left beside you: River Stone x%d." % stones if stones > 0 else ""))
	queue_free()


# --- Looks ---------------------------------------------------------------------------------

func _pieces(id: String, _k: int) -> Array:
	var out := []
	var clay := Color(0.60, 0.46, 0.34)
	var fired := Color(0.66, 0.40, 0.26)
	var shaft_col: Color = fired if built.has("firing") else clay
	match id:
		"ring":
			for i in 8:
				var a := TAU * i / 8.0
				out.append(_blob(floori(i / 2.0), Vector3(cos(a), 0, sin(a)) * RING_R + Vector3(0, 0.08, 0), Vector3(0.13, 0.09, 0.11), Color(0.50, 0.50, 0.47) * _shade(i)))
		"shaft":
			for i in 8:
				var y0 := 0.12 + i * (TOP - 0.12) / 8.0
				var y1 := y0 + (TOP - 0.12) / 8.0
				var r0 := lerpf(0.44, 0.3, i / 8.0)
				var r1 := lerpf(0.44, 0.3, (i + 1) / 8.0)
				var p := _cyl(i, Vector3(0, y0, 0), Vector3(0, y1, 0), r0, shaft_col * _shade(i), "clay", r1, 12, i == 7)
				p.m = Vector3(r0, (y0 + y1) * 0.5, 0)
				out.append(p)
		"tuyere":
			out.append(_cyl(0, Vector3(RING_R - 0.15, 0.22, 0), Vector3(RING_R + 0.12, 0.22, 0), 0.06, fired, "clay", 0.05))
			out.append(_cyl(1, Vector3(RING_R - 0.1, 0.22, 0), Vector3(RING_R + 0.02, 0.22, 0), 0.075, clay, "clay"))
		"firing":
			for i in 3:
				var p := _blob(i, Vector3(0.05 * (i - 1), TOP - 0.02, 0.04 * i), Vector3(0.12, 0.03, 0.12), Color(0.12, 0.1, 0.09), "wood")
				out.append(p)
		"blowpipes":
			for i in 2:
				var side := (i * 2 - 1) * 0.1
				out.append(_cyl(i, Vector3(RING_R + 0.1, 0.22, side * 0.3), Vector3(RING_R + 0.9, 0.5, side * 3.0), 0.025, Color(0.62, 0.55, 0.32), "wood"))
	return out


func _shapes(id: String) -> Array:
	match id:
		"ring":
			return [_cyl_shape(RING_R + 0.1, Vector3(0, 0, 0), Vector3(0, 0.18, 0))]
		"shaft":
			return [_cyl_shape(0.44, Vector3(0, 0.1, 0), Vector3(0, TOP, 0))]
	return []


func _outline_shapes() -> Array:
	return [_cyl_shape(RING_R + 0.2, Vector3(0, 0, 0), Vector3(0, TOP + 0.1, 0))]


func step_sound(id: String, _k: int) -> Array:
	return ["step", -6.0] if id in ["shaft", "tuyere"] else ["hit", -8.0]


# --- Saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := super()
	d.heat = heat
	return d


func from_dict(d: Dictionary) -> void:
	super(d)
	heat = float(d.get("heat", 0.0))
	if _mouth:
		_mouth.visible = complete()
