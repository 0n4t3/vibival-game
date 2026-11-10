extends Node3D
## Carboniferous fauna. One script drives every species through a behaviour
## type; bodies are assembled from procedural parts and animated in code.
## Creatures are not physics bodies: they follow the terrain heightfield,
## which keeps dozens of them very cheap.

const LURE_RADIUS := 12.0  # how far a splash draws an amphibian
const STALK_RANGE := 30.0  # a basking Uranocentrodon creeps toward a player this close
const SNATCH_RANGE := 12.0 # a Meganeura spots small prey this far away
const FORAGE_RANGE := 9.0  # a scavenger goes after small prey this close
const FEED_TIME := 5.0     # seconds a scavenger takes to eat small prey whole
const DRAWN_NOTICE := 20.0 # an animal drawn by guts goes for a player this close to it or the guts
const LINGER := 180.0      # seconds it hangs about where the guts were once they are eaten
const SCENT_RADIUS := 45.0 # blood in the water (meaty soup tipped out) draws amphibians this far
const APPROACH_TIME := 120.0  # seconds one drawn by blood keeps coming before it gives up
const FRENZY_RADIUS := 65.0   # a baitbox in the water draws big amphibians this far (frenzy)
const SUFFOCATE := 90.0    # seconds a fish lives out of the water
const AIR_MULT := 5.0      # a lungfish, which breathes air, lasts this many times as long

## Kills leave carcasses by size: "small" ones go into the bag as the species'
## `carcass` item; "medium" ones are carried and "large" ones dragged, and
## butchered where they lie: gutted (leaving `guts` on a pile), skinned, then
## cut into `drops.raw_meat` pieces of meat (or the species' `meat`: fish
## meat for a fish), and `drops.chitin` from the shell.
##
## Fish (behavior "fish") only exist on a line: one is made when it bites
## (fishing.gd), which moves it. On land it flops where it is and dies after
## SUFFOCATE seconds out of the water; struck dead it is an ordinary carcass.
## `fish` gives its share of bites (`weight`), body length and how hard it
## pulls line out (`pull`, m/s). Optional `fish` keys: its look (`depth`,
## `slim`, `snout`, `shark`, `head_spine`, `spines`, `lobes`), `air` (a
## lungfish: lives AIR_MULT times as long out of the water), `bite` (landed,
## it snaps at a player within `bite_reach` every `snap_every` s), `spines`
## (punched bare-fisted, it pricks: player._attack) and `lure` (its thrashing
## draws amphibians from further, and more surely: fishing.gd).

## Small prey (behavior "prey") share one population: at most PREY_DAY of
## them about at once by day and PREY_NIGHT by night, whatever the species.
## Each new one is picked by its `prey` weights [day, night]. `spawn` "shore"
## puts it on the bank by open water instead of anywhere on land. They all
## act alike: flee the player, are hunted by Meganeura and the land
## scavengers, are dazed by a thrown stone (radius up to ThrownRock.SMALL)
## and go into the bag as their `carcass`, to be gutted by hand and roasted.
const PREY_DAY := 4
const PREY_NIGHT := 2

const SPECIES := {
	"hylonomus": {
		"name": "Hylonomus", "behavior": "prey", "habitat": "land",
		"hp": 8.0, "speed": 1.6, "run": 6.4, "radius": 0.3, "hit_r": 0.45, "hit_h": 0.15,
		"sense": 9.0, "drops": {"raw_meat": 1}, "prey": [4.0, 1.0],
		"size": "small", "carcass": "lizard_carcass",
	},
	# A slender early diapsid with long legs and a long tail: quick to see
	# you and quicker to get away.
	"petrolacosaurus": {
		"name": "Petrolacosaurus", "behavior": "prey", "habitat": "land",
		"hp": 7.0, "speed": 1.9, "run": 8.0, "radius": 0.28, "hit_r": 0.42, "hit_h": 0.16,
		"sense": 12.0, "drops": {"raw_meat": 1}, "prey": [2.0, 0.5],
		"size": "small", "carcass": "petrolacosaurus_carcass",
	},
	# A heavy-headed early synapsid, the biggest of the small prey: slower,
	# tougher, and twice the meat.
	"archaeothyris": {
		"name": "Archaeothyris", "behavior": "prey", "habitat": "land",
		"hp": 14.0, "speed": 1.2, "run": 5.2, "radius": 0.34, "hit_r": 0.5, "hit_h": 0.2,
		"sense": 8.0, "drops": {"raw_meat": 2}, "prey": [1.5, 0.5],
		"size": "small", "carcass": "archaeothyris_carcass",
	},
	# A little frog-headed temnospondyl that keeps to the banks, where the
	# big amphibians take it too.
	"amphibamus": {
		"name": "Amphibamus", "behavior": "prey", "habitat": "land", "spawn": "shore",
		"hp": 5.0, "speed": 1.3, "run": 5.0, "radius": 0.24, "hit_r": 0.38, "hit_h": 0.12,
		"sense": 7.0, "drops": {"raw_meat": 1}, "prey": [1.5, 1.0],
		"size": "small", "carcass": "amphibamus_carcass",
	},
	# A short-bodied microsaur, out mostly at night.
	"tuditanus": {
		"name": "Tuditanus", "behavior": "prey", "habitat": "land",
		"hp": 7.0, "speed": 1.4, "run": 5.6, "radius": 0.28, "hit_r": 0.42, "hit_h": 0.14,
		"sense": 8.0, "drops": {"raw_meat": 1}, "prey": [0.5, 2.5],
		"size": "small", "carcass": "tuditanus_carcass",
	},
	# A tiny furry shrew-like early mammal, out of its time like
	# Uranocentrodon (Late Triassic to Early Jurassic). Mostly at night.
	"morganucodon": {
		"name": "Morganucodon", "behavior": "prey", "habitat": "land",
		"hp": 4.0, "speed": 1.5, "run": 6.0, "radius": 0.18, "hit_r": 0.32, "hit_h": 0.1,
		"sense": 8.0, "drops": {"raw_meat": 1}, "prey": [1.0, 1.5],
		"size": "small", "carcass": "morganucodon_carcass",
	},
	"scorpion": {
		"name": "Pulmonoscorpius", "behavior": "hunter", "habitat": "land",
		"hp": 40.0, "speed": 1.4, "run": 5.0, "radius": 0.6, "hit_r": 0.75, "hit_h": 0.3,
		"sense": 13.0, "damage": 9.0, "venom": 14.0, "venom_chance": 0.45, "reach": 1.7, "windup": 0.45,
		"cooldown": 1.4, "sound": "hiss", "drops": {"raw_meat": 2, "chitin": 1}, "cap_day": 0, "cap_night": 2,
		"scavenger": true, "size": "medium", "guts": 1,
	},
	"arthropleura": {
		"name": "Arthropleura", "behavior": "defensive", "habitat": "land",
		"hp": 160.0, "speed": 0.9, "run": 2.6, "radius": 0.9, "hit_r": 1.0, "hit_h": 0.3,
		"sense": 6.0, "damage": 18.0, "reach": 2.3, "windup": 0.7, "cooldown": 2.0, "sound": "chitter",
		"drops": {"raw_meat": 5, "chitin": 4}, "cap_day": 1, "cap_night": 1,
		"scavenger": true, "size": "medium", "guts": 2,
	},
	# Large carnivorous amphibian, a rare wanderer on land. Spawned by the swamp
	# itself, not by the generic spawner (caps 0).
	"eogyrinus": {
		"name": "Eogyrinus", "behavior": "lurker", "habitat": "amphibious",
		"hp": 320.0, "speed": 0.7, "run": 6.6, "radius": 1.0, "hit_r": 1.0, "hit_h": 0.25,
		"sense": 7.0, "leash": 16.0, "sound": "roar", "bite": 25.0, "grab_dps": 13.0, "grip": 100.0,
		"drops": {"raw_meat": 8}, "cap_day": 0, "cap_night": 0, "size": "large", "guts": 3,
	},
	# A huge, flat-headed amphibian (about 7 m). Basks on the bank by day, and
	# otherwise lies buried in the mud under shallow water, given away only by
	# faint ripples. Strikes anything that comes to the water's edge in reach:
	# the player or other animals. Buried, it comes much further ("ambush") for
	# a player near enough the edge to reach the water.
	"uranocentrodon": {
		"name": "Uranocentrodon", "behavior": "ambusher", "habitat": "amphibious",
		"hp": 650.0, "speed": 0.5, "run": 10.5, "radius": 1.5, "hit_r": 1.6, "hit_h": 0.35,
		"strike": 6.0, "ambush": 16.0, "grab_dist": 3.0, "leash": 14.0, "sound": "roar", "anchor": 1.25,
		"bite": 40.0, "grab_dps": 22.0, "grip": 170.0, "kill": 500.0, "drag": 7.0, "escape": true,
		"drops": {"raw_meat": 14}, "cap_day": 0, "cap_night": 0, "size": "large", "guts": 4,
	},
	"meganeura": {
		"name": "Meganeura", "behavior": "flyer", "habitat": "air",
		"hp": 6.0, "speed": 3.0, "run": 8.5, "radius": 0.3, "hit_r": 0.7, "hit_h": 0.0,
		"sense": 14.0, "damage": 4.0, "reach": 1.1, "cooldown": 6.0,
		"drops": {"raw_meat": 1}, "cap_day": 2, "cap_night": 1,
		"size": "small", "carcass": "dragonfly_carcass",
	},
	# Fish: never spawned (caps 0), only hooked (fishing.gd).
	"elonichthys": {
		"name": "Elonichthys", "behavior": "fish", "habitat": "water",
		"hp": 2.0, "speed": 1.4, "run": 1.4, "radius": 0.15, "hit_r": 0.35, "hit_h": -0.1,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 1}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "small", "carcass": "elonichthys_carcass",
		"fish": {"weight": 22, "len": 0.3, "pull": 0.3, "col": Color(0.55, 0.58, 0.52)},
	},
	"ctenodus": {
		"name": "Ctenodus", "behavior": "fish", "habitat": "water",
		"hp": 8.0, "speed": 1.6, "run": 1.6, "radius": 0.3, "hit_r": 0.55, "hit_h": -0.05,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 4}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 1,
		"fish": {"weight": 7, "len": 0.9, "pull": 0.6, "air": true, "col": Color(0.42, 0.40, 0.30)},
	},
	"rhizodus": {
		"name": "Rhizodus", "behavior": "fish", "habitat": "water",
		"hp": 22.0, "speed": 2.0, "run": 2.0, "radius": 0.55, "hit_r": 0.8, "hit_h": 0.0,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 10}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 2,
		"fish": {"weight": 1, "len": 1.7, "pull": 1.0, "col": Color(0.30, 0.34, 0.30)},
	},
	"haplolepis": {
		"name": "Haplolepis", "behavior": "fish", "habitat": "water",
		"hp": 1.0, "speed": 1.0, "run": 1.0, "radius": 0.1, "hit_r": 0.3, "hit_h": -0.12,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 1}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "small", "carcass": "haplolepis_carcass",
		"fish": {"weight": 26, "len": 0.16, "pull": 0.2, "col": Color(0.62, 0.64, 0.56)},
	},
	"amphicentrum": {
		"name": "Amphicentrum", "behavior": "fish", "habitat": "water",
		"hp": 2.0, "speed": 1.0, "run": 1.0, "radius": 0.15, "hit_r": 0.35, "hit_h": -0.1,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 1}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "small", "carcass": "amphicentrum_carcass",
		"fish": {"weight": 10, "len": 0.3, "pull": 0.3, "depth": 2.2, "col": Color(0.52, 0.46, 0.34)},
	},
	"acanthodes": {
		"name": "Acanthodes", "behavior": "fish", "habitat": "water",
		"hp": 2.0, "speed": 1.2, "run": 1.2, "radius": 0.15, "hit_r": 0.35, "hit_h": -0.1,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 1}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "small", "carcass": "acanthodes_carcass",
		"fish": {"weight": 9, "len": 0.36, "pull": 0.35, "slim": 0.7, "spines": true, "col": Color(0.46, 0.50, 0.55)},
	},
	"bandringa": {
		"name": "Bandringa", "behavior": "fish", "habitat": "water",
		"hp": 3.0, "speed": 1.2, "run": 1.2, "radius": 0.15, "hit_r": 0.4, "hit_h": -0.1,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 1}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "small", "carcass": "bandringa_carcass",
		"fish": {"weight": 3, "len": 0.4, "pull": 0.4, "snout": 0.6, "shark": true, "col": Color(0.40, 0.38, 0.33)},
	},
	"rhabdoderma": {
		"name": "Rhabdoderma", "behavior": "fish", "habitat": "water",
		"hp": 6.0, "speed": 1.2, "run": 1.2, "radius": 0.25, "hit_r": 0.5, "hit_h": -0.05,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 3}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 1,
		"fish": {"weight": 9, "len": 0.6, "pull": 0.5, "lobes": true, "col": Color(0.34, 0.42, 0.48)},
	},
	"sagenodus": {
		"name": "Sagenodus", "behavior": "fish", "habitat": "water",
		"hp": 9.0, "speed": 1.4, "run": 1.4, "radius": 0.3, "hit_r": 0.55, "hit_h": -0.05,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 4}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 1,
		"fish": {"weight": 5, "len": 1.0, "pull": 0.6, "air": true, "col": Color(0.38, 0.36, 0.26)},
	},
	"megalichthys": {
		"name": "Megalichthys", "behavior": "fish", "habitat": "water",
		"hp": 14.0, "speed": 2.0, "run": 2.0, "radius": 0.4, "hit_r": 0.65, "hit_h": 0.0,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 6}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 1,
		"fish": {"weight": 4, "len": 1.3, "pull": 1.0, "col": Color(0.47, 0.38, 0.20)},
	},
	"xenacanthus": {
		"name": "Xenacanthus", "behavior": "fish", "habitat": "water",
		"hp": 12.0, "speed": 1.8, "run": 1.8, "radius": 0.3, "hit_r": 0.55, "hit_h": 0.0,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 5}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 1,
		"fish": {"weight": 3, "len": 1.0, "pull": 0.8, "slim": 0.7, "shark": true, "head_spine": true, "bite": 6.0, "bite_reach": 1.5, "snap_every": 2.5, "col": Color(0.36, 0.38, 0.40)},
	},
	"strepsodus": {
		"name": "Strepsodus", "behavior": "fish", "habitat": "water",
		"hp": 22.0, "speed": 2.0, "run": 2.0, "radius": 0.55, "hit_r": 0.8, "hit_h": 0.0,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 10}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 2,
		"fish": {"weight": 1, "len": 1.8, "pull": 1.0, "col": Color(0.33, 0.31, 0.26)},
	},
	"orthacanthus": {
		"name": "Orthacanthus", "behavior": "fish", "habitat": "water",
		"hp": 30.0, "speed": 2.4, "run": 2.4, "radius": 0.6, "hit_r": 0.9, "hit_h": 0.0,
		"sense": 0.0, "damage": 0.0, "reach": 0.0, "cooldown": 0.0,
		"drops": {"fish_meat": 14}, "meat": "fish_meat", "cap_day": 0, "cap_night": 0,
		"size": "medium", "guts": 3,
		"fish": {"weight": 0.8, "len": 2.6, "pull": 1.3, "slim": 0.75, "shark": true, "head_spine": true, "bite": 14.0, "bite_reach": 2.3, "snap_every": 2.0, "lure": 2.0, "col": Color(0.30, 0.32, 0.34)},
	},
}

var species := ""
var def: Dictionary
var world: Node = null
var hp := 1.0
var dead := false
var hit_radius := 0.5
var state := "wander"

var heading := 0.0
var home := Vector3.ZERO
var _target := Vector3.ZERO
var _state_t := 0.0
var _cd := 0.0
var _windup := 0.0
var _anger := 0.0
var _phase := 0.0
var _far_acc := 0.0
var _frame := 0
var _altitude := 4.0
var _rng := RandomNumberGenerator.new()

var _body: Node3D
var _legs: Array[Node3D] = []
var _segs: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _carcass: StaticBody3D
var _buzz: AudioStreamPlayer3D

# Lurker / ambusher (amphibian) state
var mode := "lurk"               # "bask" on the bank, "lurk" in water, "land" roaming,
								 # or "hide" buried in the mud (ambusher)
var water_home := Vector3.ZERO   # deep water it returns to
var submerged := false
var _jaw: Node3D
var _head: Node3D
var _victim: Node3D = null
var _prey: Node3D = null         # ambusher: animal it is striking at or eating
var _strike_t := 0.0
var _lure := Vector3.ZERO        # amphibians: where a splash drew it
var _provoked := 0.0             # ambusher: seconds it will chase further after being hit
var _approach := 0.0             # amphibians: seconds left closing in on the scent of blood
var _frenzy := 0.0               # amphibians: seconds left tearing at a baitbox (see frenzy)
var _frenzy_at := Vector3.ZERO   # where the baitbox is
var _frenzy_spot := Vector3.ZERO # where it is thrashing toward next, round the box
var _stun := 0.0                 # small animals: seconds left dazed by a thrown rock
var blown := 0.0                 # flyers: seconds left tumbling helplessly in a gale
var carried_by: Node3D = null    # a lizard: the Meganeura flying off with it
var eaten_by: Node3D = null      # a dead lizard: the scavenger eating it
var gnawed := false              # a dead animal something has started to eat
var stage := "whole"             # a carcass: "whole", "gutted" or "skinned"
var cuts_left := 0               # a carcass: pieces of meat still on it
var died_at := 0.0               # Game.time it died; the carcass lasts a day
var hauled_by: Node3D = null     # a carcass: the player carrying or dragging it
var drawn := false               # came for a guts pile (see _think_drawn)
var bait: Node3D = null          # the guts pile it came for
var _bait_pos := Vector3.ZERO
var _linger := 0.0
var _scan_t := 0.0
var _calm := 0.0
var _gape := 0.0
var _ripples: Array[MeshInstance3D] = []
var _ripple_age: Array[float] = []
var _ripple_t := 0.0
var hooked_by: Node = null       # a fish: the line it is on (fishing.gd)
var out_of_water := 0.0          # a fish: seconds it has been on land
var _raft: Node3D = null         # big amphibians: the raft whose corner it has in its jaws (raft.gd)
var _raft_corner := 0
var snared: Node3D = null        # caught in a snare (trap.gd): it can't get away

static var _part_cache := {}
static var _ripple_mesh: Mesh


func setup(sp: String, pos: Vector3, owner_world: Node) -> Node3D:
	species = sp
	def = SPECIES[sp]
	world = owner_world
	hp = def.hp
	hit_radius = def.hit_r
	home = pos
	position = pos
	_rng.randomize()
	heading = _rng.randf() * TAU
	return self


func _ready() -> void:
	Game.creatures.append(self)
	_body = Node3D.new()
	add_child(_body)
	if def.behavior == "fish":
		_build_fish()
	else:
		call("_build_" + species)
	for n in _body.find_children("*", "MeshInstance3D", true, false):
		n.visibility_range_end = 90.0
		if Settings.quality == 0:
			n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_altitude = _rng.randf_range(2.5, 6.0)
	_pick_wander()


func _exit_tree() -> void:
	Game.creatures.erase(self)


func hit_center() -> Vector3:
	return global_position + Vector3(0, def.hit_h + 0.2, 0)


# --- Body construction ------------------------------------------------------------

func _part(key: String, build: Callable) -> Mesh:
	var k := "%s_%d" % [key, Settings.detail()]
	if not _part_cache.has(k):
		var b = Assets.builder()
		build.call(b)
		_part_cache[k] = b.commit(Assets.materials)
	return _part_cache[k]


func _add(mesh: Mesh, parent: Node3D, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p


func _build_hylonomus() -> void:
	var col := Color(0.42, 0.36, 0.22)
	_add(_part("hyl_body", func(b):
		b.blob(Vector3(0, 0.1, 0), Vector3(0.08, 0.06, 0.18), 2, 6, col)
		b.blob(Vector3(0, 0.12, -0.2), Vector3(0.05, 0.045, 0.08), 2, 5, col * 1.1)
		b.cone(Vector3(0, 0.09, 0.15), Vector3(0, 0.05, 0.5), 0.045, 4, col * 0.9)
		b.blob(Vector3(0.035, 0.14, -0.24), Vector3(0.015, 0.015, 0.015), 1, 4, Color(0.05, 0.05, 0.03))
		b.blob(Vector3(-0.035, 0.14, -0.24), Vector3(0.015, 0.015, 0.015), 1, 4, Color(0.05, 0.05, 0.03))), _body, Vector3.ZERO)
	var leg := _part("hyl_leg", func(b): b.cylinder(Vector3.ZERO, Vector3(0.09, -0.08, 0), 0.015, 0.012, 4, col * 0.8))
	for p in [Vector3(0.06, 0.09, -0.1), Vector3(-0.06, 0.09, -0.1), Vector3(0.06, 0.09, 0.1), Vector3(-0.06, 0.09, 0.1)]:
		var piv := _pivot(_body, p)
		var mi := _add(leg, piv, Vector3.ZERO)
		if p.x < 0:
			mi.scale.x = -1.0
		_legs.append(piv)
	_body.scale = Vector3.ONE * 1.4


func _build_small_prey(key: String, col: Color, o: Dictionary) -> void:
	## A small four-legged prey animal on Hylonomus's plan: the head toward -z,
	## a tapering tail behind and four walking legs (_legs). `o` sets the
	## proportions: `body` and `head` radii, `tail` length and `tail_r`, `leg` drop, `leg_r`,
	## `eye` size, a `belly` colour, `extra` (a Callable(b, y, head_pos, col)
	## adding markings) and the overall `scale`. With the defaults it is a Hylonomus.
	var body: Vector3 = o.get("body", Vector3(0.08, 0.06, 0.18))
	var head: Vector3 = o.get("head", Vector3(0.05, 0.045, 0.08))
	var leg: float = o.get("leg", 0.08)
	var y := leg + 0.02
	var head_at := Vector3(0, y + body.y * 0.33, -(body.z + head.z * 0.25))
	_add(_part(key + "_body", func(b):
		b.blob(Vector3(0, y, 0), body, 2, 6, col)
		if o.has("belly"):
			b.blob(Vector3(0, y - body.y * 0.35, 0), Vector3(body.x * 0.85, body.y * 0.6, body.z * 0.9), 2, 6, o.belly)
		b.blob(head_at, head, 2, 5, col * 1.1)
		b.cone(Vector3(0, y - 0.01, body.z * 0.83), Vector3(0, y - 0.05, body.z * 0.83 + o.get("tail", 0.35)),
				o.get("tail_r", body.x * 0.56), 4, col * 0.9)
		var eye: float = o.get("eye", 0.015)
		for sx in [head.x * 0.7, -head.x * 0.7]:
			b.blob(head_at + Vector3(sx, head.y * 0.45, -head.z * 0.5), Vector3.ONE * eye, 1, 4, Color(0.05, 0.05, 0.03))
		if o.has("extra"):
			o.extra.call(b, y, head_at, col)), _body, Vector3.ZERO)
	var r: float = o.get("leg_r", 0.015)
	var leg_mesh := _part(key + "_leg", func(b): b.cylinder(Vector3.ZERO, Vector3(leg * 1.12, -leg, 0), r, r * 0.8, 4, col * 0.8))
	var lx := body.x * 0.75
	var lz := body.z * 0.55
	for p in [Vector3(lx, y - 0.01, -lz), Vector3(-lx, y - 0.01, -lz), Vector3(lx, y - 0.01, lz), Vector3(-lx, y - 0.01, lz)]:
		var piv := _pivot(_body, p)
		var mi := _add(leg_mesh, piv, Vector3.ZERO)
		if p.x < 0:
			mi.scale.x = -1.0
		_legs.append(piv)
	_body.scale = Vector3.ONE * o.get("scale", 1.4)


func _build_petrolacosaurus() -> void:
	# Slim and long-legged, sandy with a darker stripe down the back, and a
	# tail longer than the rest of it.
	_build_small_prey("petro", Color(0.50, 0.42, 0.27), {"body": Vector3(0.055, 0.045, 0.16),
		"head": Vector3(0.035, 0.032, 0.07), "tail": 0.6, "leg": 0.11, "leg_r": 0.011, "scale": 1.45,
		"belly": Color(0.62, 0.55, 0.38), "extra": _marks_petrolacosaurus})


func _marks_petrolacosaurus(b, y: float, _head: Vector3, col: Color) -> void:
	for i in 5:
		var z := -0.12 + i * 0.06
		b.blob(Vector3(0, y + _on_back(Vector3(0.055, 0.045, 0.16), 0.0, z) - 0.004, z), Vector3(0.018, 0.01, 0.026), 1, 4, col * 0.6)


func _build_archaeothyris() -> void:
	# Heavier and dark brown, with a deep head and jaw and a pale belly.
	_build_small_prey("archaeo", Color(0.36, 0.29, 0.23), {"body": Vector3(0.1, 0.075, 0.2),
		"head": Vector3(0.06, 0.065, 0.1), "tail": 0.32, "leg": 0.08, "leg_r": 0.02, "eye": 0.017, "scale": 1.5,
		"belly": Color(0.56, 0.48, 0.36), "extra": _marks_archaeothyris})


func _marks_archaeothyris(b, _y: float, head: Vector3, col: Color) -> void:
	b.blob(head + Vector3(0, -0.04, -0.03), Vector3(0.045, 0.03, 0.075), 2, 5, col * 0.95)


func _build_amphibamus() -> void:
	# Small, olive and spotted, with a broad flat frog-like head, big eyes and
	# a stubby tail.
	_build_small_prey("amphib", Color(0.30, 0.36, 0.22), {"body": Vector3(0.06, 0.04, 0.1),
		"head": Vector3(0.06, 0.03, 0.06), "tail": 0.12, "leg": 0.06, "leg_r": 0.012, "eye": 0.022, "scale": 1.3,
		"belly": Color(0.70, 0.66, 0.42), "extra": _marks_amphibamus})


func _marks_amphibamus(b, y: float, _head: Vector3, _col: Color) -> void:
	for s in [Vector3(0.03, 0.03, -0.04), Vector3(-0.025, 0.032, 0.0), Vector3(0.02, 0.03, 0.05), Vector3(-0.03, 0.028, 0.06)]:
		b.blob(Vector3(s.x, y + _on_back(Vector3(0.06, 0.04, 0.1), s.x, s.z) - 0.002, s.z), Vector3(0.012, 0.008, 0.012), 1, 4, Color(0.16, 0.18, 0.1))


func _build_tuditanus() -> void:
	# Short-bodied and short-snouted, reddish grey with pale bands.
	_build_small_prey("tudi", Color(0.42, 0.31, 0.29), {"body": Vector3(0.065, 0.05, 0.12),
		"head": Vector3(0.042, 0.036, 0.05), "tail": 0.28, "leg": 0.06, "leg_r": 0.013, "scale": 1.4,
		"extra": _marks_tuditanus})


func _marks_tuditanus(b, y: float, _head: Vector3, _col: Color) -> void:
	# Each band a thin ring just proud of the body where it crosses it.
	var body := Vector3(0.065, 0.05, 0.12)
	for i in 3:
		var z := -0.07 + i * 0.07
		var f := 1.0 - absf(z) / body.z
		b.blob(Vector3(0, y, z), Vector3(body.x * f + 0.005, body.y * f + 0.005, 0.012), 2, 6, Color(0.66, 0.58, 0.5))


func _on_back(body: Vector3, x: float, z: float) -> float:
	## How far above its middle the top of a small prey's body (a low-poly
	## blob of these radii) is at x, z: where markings sit on it.
	return body.y * maxf(1.0 - absf(x) / body.x - absf(z) / body.z, 0.0)


func _build_morganucodon() -> void:
	# A round, furry grey-brown body on short legs, a pointed snout, small
	# round ears and a thin bare tail.
	_build_small_prey("morgan", Color(0.40, 0.34, 0.28), {"body": Vector3(0.05, 0.042, 0.085),
		"head": Vector3(0.032, 0.03, 0.045), "tail": 0.17, "tail_r": 0.007, "leg": 0.035, "leg_r": 0.009,
		"eye": 0.008, "scale": 1.25, "belly": Color(0.58, 0.52, 0.44), "extra": _marks_morganucodon})


func _marks_morganucodon(b, _y: float, head: Vector3, col: Color) -> void:
	# The snout, with a dark nose at its tip, and two ears.
	b.cone(head + Vector3(0, -0.006, -0.03), head + Vector3(0, -0.012, -0.075), 0.016, 5, col * 1.05)
	b.blob(head + Vector3(0, -0.012, -0.076), Vector3(0.006, 0.006, 0.006), 1, 4, Color(0.12, 0.08, 0.08))
	for sx in [0.02, -0.02]:
		b.blob(head + Vector3(sx, 0.03, 0.01), Vector3(0.012, 0.013, 0.005), 1, 5, Color(0.55, 0.42, 0.38))


func _build_scorpion() -> void:
	var col := Color(0.24, 0.17, 0.10)
	var light := Color(0.36, 0.26, 0.15)
	_add(_part("sco_body", func(b):
		for i in 5:
			b.blob(Vector3(0, 0.22, -0.25 + i * 0.13), Vector3(0.2 - i * 0.015, 0.09, 0.09), 2, 6, col if i % 2 == 0 else light)
		b.blob(Vector3(0, 0.22, -0.38), Vector3(0.15, 0.08, 0.1), 2, 6, col)), _body, Vector3.ZERO)
	var leg := _part("sco_leg", func(b):
		b.cylinder(Vector3.ZERO, Vector3(0.22, 0.08, 0), 0.025, 0.02, 4, light)
		b.cylinder(Vector3(0.22, 0.08, 0), Vector3(0.36, -0.2, 0), 0.02, 0.012, 4, col))
	for i in 4:
		for s in [1.0, -1.0]:
			var piv := _pivot(_body, Vector3(0.12 * s, 0.2, -0.2 + i * 0.1))
			var mi := _add(leg, piv, Vector3.ZERO)
			mi.scale.x = s
			piv.rotation.y = s * (0.5 - i * 0.3)
			_legs.append(piv)
	var claw := _part("sco_claw", func(b):
		b.cylinder(Vector3.ZERO, Vector3(0.05, 0.02, -0.25), 0.03, 0.03, 4, light)
		b.blob(Vector3(0.05, 0.02, -0.33), Vector3(0.06, 0.04, 0.1), 2, 5, col)
		b.cone(Vector3(0.03, 0.02, -0.4), Vector3(0.02, 0.02, -0.5), 0.025, 4, col))
	for s in [1.0, -1.0]:
		var piv := _pivot(_body, Vector3(0.12 * s, 0.22, -0.42))
		var mi := _add(claw, piv, Vector3.ZERO)
		mi.scale.x = s
		piv.rotation.y = s * -0.25
		_tail.append(piv)  # claws snap with the tail animation
	var seg := _part("sco_tail", func(b): b.blob(Vector3(0, 0, 0.06), Vector3(0.06, 0.055, 0.08), 2, 5, light))
	var sting := _part("sco_sting", func(b):
		b.blob(Vector3(0, 0, 0.05), Vector3(0.06, 0.06, 0.07), 2, 5, Color(0.5, 0.25, 0.1))
		b.cone(Vector3(0, 0, 0.0), Vector3(0, -0.04, -0.12), 0.025, 4, Color(0.1, 0.06, 0.03)))
	var parent: Node3D = _pivot(_body, Vector3(0, 0.24, 0.32))
	for i in 5:
		_add(sting if i == 4 else seg, parent, Vector3.ZERO)
		parent.rotation.x = -0.55
		_segs.append(parent)
		parent = _pivot(parent, Vector3(0, 0, 0.13))
	_body.scale = Vector3.ONE * 1.5


func _build_arthropleura() -> void:
	var dark := Color(0.13, 0.10, 0.08)
	var band := Color(0.34, 0.24, 0.14)
	var plate := _part("art_seg", func(b):
		b.box(Vector3(0, 0.18, 0), Vector3(0.66, 0.14, 0.15), band)
		b.box(Vector3(0, 0.27, 0), Vector3(0.5, 0.08, 0.14), dark)
		b.box(Vector3(0, 0.33, 0), Vector3(0.12, 0.04, 0.12), dark * 1.3)
		for s in [1.0, -1.0]:
			b.cylinder(Vector3(0.25 * s, 0.14, 0), Vector3(0.38 * s, 0.0, 0), 0.02, 0.015, 4, dark))
	var n := 14 if Settings.quality > 0 else 9
	for i in n:
		var piv := _pivot(_body, Vector3(0, 0, -1.2 + i * 2.5 / n))
		_add(plate, piv, Vector3.ZERO)
		piv.scale = Vector3.ONE * (1.0 - absf(i - n * 0.4) / n * 0.5)
		_segs.append(piv)
	_add(_part("art_head", func(b):
		b.blob(Vector3(0, 0.16, 0), Vector3(0.22, 0.1, 0.14), 2, 6, dark)
		b.cylinder(Vector3(0.1, 0.2, -0.1), Vector3(0.3, 0.35, -0.5), 0.015, 0.008, 4, dark)
		b.cylinder(Vector3(-0.1, 0.2, -0.1), Vector3(-0.3, 0.35, -0.5), 0.015, 0.008, 4, dark)), _segs[0], Vector3(0, 0, -0.18))


func _build_eogyrinus() -> void:
	# A 4.5 m, crocodile-shaped amphibian: flat skull, sprawling legs, long
	# flattened tail. The lower jaw is its own pivot so it can gape and bite.
	var col := Color(0.22, 0.24, 0.13)
	var dark := Color(0.11, 0.13, 0.07)
	var belly := Color(0.50, 0.46, 0.30)
	var mouth := Color(0.55, 0.27, 0.25)
	var tooth := Color(0.92, 0.9, 0.8)
	var widths := [0.36, 0.42, 0.40, 0.34, 0.27, 0.2, 0.15, 0.11, 0.08, 0.05]
	for i in widths.size():
		var w: float = widths[i]
		var tail := i >= 5
		var piv := _pivot(_body if i == 0 else _segs[i - 1], Vector3(0, 0, 0.0 if i == 0 else 0.38))
		_add(_part("eog_seg%d" % i, func(b):
			if tail:
				b.blob(Vector3(0, 0.3, 0.19), Vector3(w * 0.7, w * 1.1, 0.24), 2, 6, col)
			else:
				b.blob(Vector3(0, 0.3, 0.19), Vector3(w, 0.2, 0.26), 2, 7, col)
				b.blob(Vector3(0, 0.22, 0.19), Vector3(w * 0.9, 0.12, 0.24), 2, 6, belly)
				b.box(Vector3(0, 0.49, 0.19), Vector3(w * 0.35, 0.05, 0.3), dark)), piv, Vector3.ZERO)
		_segs.append(piv)
	_head = _pivot(_body, Vector3(0, 0, -0.05))
	_add(_part("eog_skull", func(b):
		b.blob(Vector3(0, 0.34, -0.42), Vector3(0.3, 0.11, 0.45), 2, 8, col)
		b.blob(Vector3(0, 0.4, -0.2), Vector3(0.22, 0.08, 0.2), 2, 6, dark)
		for sx in [1.0, -1.0]:
			b.blob(Vector3(0.15 * sx, 0.45, -0.38), Vector3(0.06, 0.05, 0.06), 1, 5, dark)
			b.blob(Vector3(0.16 * sx, 0.48, -0.4), Vector3(0.035, 0.03, 0.035), 1, 4, Color(0.85, 0.72, 0.15))
			for k in 8:
				var z := -0.1 - k * 0.085
				var x: float = (0.27 - k * 0.012) * sx
				b.cone(Vector3(x, 0.26, z), Vector3(x, 0.17, z), 0.022, 3, tooth)
		b.box(Vector3(0, 0.27, -0.4), Vector3(0.44, 0.03, 0.62), mouth)), _head, Vector3.ZERO)
	_jaw = _pivot(_head, Vector3(0, 0.24, 0.0))
	_add(_part("eog_jaw", func(b):
		b.blob(Vector3(0, -0.05, -0.42), Vector3(0.28, 0.07, 0.44), 2, 7, belly)
		b.box(Vector3(0, 0.0, -0.4), Vector3(0.42, 0.03, 0.6), mouth)
		for sx in [1.0, -1.0]:
			for k in 8:
				var z := -0.12 - k * 0.085
				var x: float = (0.25 - k * 0.012) * sx
				b.cone(Vector3(x, 0.0, z), Vector3(x, 0.09, z), 0.02, 3, tooth)), _jaw, Vector3.ZERO)
	var leg := _part("eog_leg", func(b):
		b.cylinder(Vector3.ZERO, Vector3(0.32, -0.08, 0), 0.07, 0.06, 5, col)
		b.cylinder(Vector3(0.32, -0.08, 0), Vector3(0.38, -0.26, -0.05), 0.06, 0.05, 5, col)
		b.blob(Vector3(0.42, -0.28, -0.1), Vector3(0.1, 0.03, 0.12), 1, 5, dark))
	for spec in [[0, 0.1], [3, 0.2]]:
		for sx in [1.0, -1.0]:
			var piv := _pivot(_segs[spec[0]], Vector3(0.28 * sx, 0.28, spec[1]))
			var mi := _add(leg, piv, Vector3.ZERO)
			mi.scale.x = sx
			_legs.append(piv)


func _build_uranocentrodon() -> void:
	# A ~7 m rhinesuchid: a broad, flat, parabolic skull with small raised eyes
	# set well back, a wide flattened body on short sprawling legs and a long,
	# laterally flattened tail with a low crest. Muddy olive above, paler below,
	# with darker blotches and lateral-line grooves, so it vanishes on the bank.
	var col := Color(0.25, 0.23, 0.13)
	var dark := Color(0.13, 0.12, 0.07)
	var belly := Color(0.5, 0.45, 0.3)
	var mouth := Color(0.48, 0.25, 0.22)
	var tooth := Color(0.9, 0.88, 0.78)
	var eye := Color(0.78, 0.6, 0.12)
	# Half width and half height of each segment, flowing from body into tail.
	var widths := [0.8, 0.9, 0.9, 0.84, 0.72, 0.54, 0.4, 0.29, 0.2, 0.12]
	var heights := [0.27, 0.29, 0.29, 0.28, 0.27, 0.26, 0.23, 0.2, 0.16, 0.11]
	for i in widths.size():
		var w: float = widths[i]
		var h: float = heights[i]
		var tail := i >= 5
		var piv := _pivot(_body if i == 0 else _segs[i - 1], Vector3(0, 0, 0.0 if i == 0 else 0.56))
		_add(_part("ura_seg%d" % i, func(b):
			var y := 0.38 - (0.03 if tail else 0.0)
			b.blob(Vector3(0, y, 0.28), Vector3(w, h, 0.56), 3, 10, col)
			b.blob(Vector3(0, y - h * 0.45, 0.28), Vector3(w * 0.9, h * 0.55, 0.52), 2, 8, belly)
			# Lateral line along the flank and blotches pressed into the back.
			for sx in [1.0, -1.0]:
				b.blob(Vector3(w * 0.93 * sx, y + h * 0.15, 0.28), Vector3(0.02, 0.025, 0.3), 1, 4, dark)
				b.blob(Vector3(w * (0.3 + 0.15 * ((i + int(sx)) % 2)) * sx, y + h * 0.82, 0.18 + 0.16 * sx),
						Vector3(w * 0.22, 0.05, 0.13 + 0.04 * (i % 3)), 1, 5, dark)
			if tail:
				# A low crest above and below the flattened tail.
				b.blob(Vector3(0, y + h * 0.95, 0.28), Vector3(0.035, h * 0.5, 0.4), 1, 6, dark)
				b.blob(Vector3(0, y - h * 0.9, 0.28), Vector3(0.03, h * 0.35, 0.38), 1, 6, col)
			else:
				b.blob(Vector3(0, y + h * 0.95, 0.28), Vector3(w * 0.12, 0.04, 0.38), 1, 5, dark)), piv, Vector3.ZERO)
		_segs.append(piv)
	_head = _pivot(_body, Vector3(0, 0, -0.05))
	_add(_part("ura_skull", func(b):
		# Parabolic outline: widest at the back, tapering to a broad round snout.
		for k in 6:
			var u := k / 5.0
			b.blob(Vector3(0, 0.45 - 0.04 * u, -0.3 - u * 1.25), Vector3(0.84 * sqrt(1.0 - u * 0.86), 0.18 - 0.06 * u, 0.4), 3, 10, col)
		b.blob(Vector3(0, 0.36, -0.9), Vector3(0.7, 0.07, 0.8), 2, 8, belly)
		# Flat skull table with dark sculpturing.
		b.blob(Vector3(0, 0.56, -0.5), Vector3(0.5, 0.06, 0.48), 2, 7, dark.lerp(col, 0.5))
		for sx in [1.0, -1.0]:
			# Raised orbits and small upward eyes, set behind the middle.
			b.blob(Vector3(0.27 * sx, 0.59, -0.66), Vector3(0.12, 0.07, 0.13), 1, 6, col)
			b.blob(Vector3(0.27 * sx, 0.64, -0.66), Vector3(0.06, 0.04, 0.065), 1, 5, eye)
			b.blob(Vector3(0.27 * sx, 0.675, -0.66), Vector3(0.012, 0.01, 0.045), 1, 4, Color(0.03, 0.03, 0.02))
			b.blob(Vector3(0.16 * sx, 0.52, -1.58), Vector3(0.035, 0.02, 0.035), 1, 4, Color(0.05, 0.05, 0.03))
			# Lateral-line grooves running from the eye toward the snout.
			for k in 5:
				var t := k / 4.0
				b.blob(Vector3((0.36 + 0.06 * t) * sx - 0.1 * t * t * sx, 0.55 - 0.03 * t, -0.8 - 0.62 * t),
						Vector3(0.02, 0.015, 0.1), 1, 4, dark)
			for k in 14:
				var u := k / 13.0 * 0.94
				var z := -0.2 - u * 1.4
				var x: float = 0.72 * sqrt(1.0 - u) * sx
				b.cone(Vector3(x, 0.33, z), Vector3(x, 0.2, z), 0.03, 3, tooth)
		# Mouth lining, kept inside the jaw line.
		for k in 4:
			var u := (k + 0.5) / 4.0 * 0.9
			b.blob(Vector3(0, 0.32, -0.2 - u * 1.4), Vector3(0.66 * sqrt(1.0 - u), 0.02, 0.22), 1, 6, mouth)), _head, Vector3.ZERO)
	_jaw = _pivot(_head, Vector3(0, 0.3, -0.05))
	_add(_part("ura_jaw", func(b):
		b.blob(Vector3(0, -0.07, -0.55), Vector3(0.76, 0.1, 0.55), 2, 8, belly)
		b.blob(Vector3(0, -0.06, -1.15), Vector3(0.56, 0.09, 0.48), 2, 8, belly)
		for k in 4:
			var u := (k + 0.5) / 4.0 * 0.9
			b.blob(Vector3(0, 0.01, -0.2 - u * 1.35), Vector3(0.62 * sqrt(1.0 - u), 0.02, 0.22), 1, 6, mouth)
		for sx in [1.0, -1.0]:
			for k in 13:
				var u := k / 12.0 * 0.92
				var z := -0.2 - u * 1.35
				var x: float = 0.66 * sqrt(1.0 - u) * sx
				b.cone(Vector3(x, 0.0, z), Vector3(x, 0.12, z), 0.028, 3, tooth)), _jaw, Vector3.ZERO)
	# Short sprawling legs: upper limb out to the side, forearm down, a broad
	# foot with spread toes.
	var leg := _part("ura_leg", func(b):
		b.blob(Vector3(0.1, -0.02, 0), Vector3(0.2, 0.15, 0.17), 1, 6, col)
		b.cylinder(Vector3(0.1, -0.02, 0), Vector3(0.48, -0.08, 0.02), 0.14, 0.11, 6, col)
		b.blob(Vector3(0.48, -0.09, 0.02), Vector3(0.11, 0.1, 0.11), 1, 5, col)
		b.cylinder(Vector3(0.48, -0.09, 0.02), Vector3(0.56, -0.34, -0.04), 0.1, 0.08, 6, col)
		b.blob(Vector3(0.6, -0.37, -0.1), Vector3(0.15, 0.04, 0.15), 1, 6, dark.lerp(col, 0.4))
		for t in 4:
			var a := -0.7 + t * 0.45
			var base := Vector3(0.6, -0.37, -0.12)
			b.cone(base, base + Vector3(sin(a) * 0.22, -0.02, -cos(a) * 0.22), 0.035, 4, dark.lerp(col, 0.4)))
	for spec in [[0, 0.2], [3, 0.32]]:
		for sx in [1.0, -1.0]:
			var piv := _pivot(_segs[spec[0]], Vector3(0.62 * sx, 0.36, spec[1]))
			var mi := _add(leg, piv, Vector3.ZERO)
			mi.scale.x = sx
			_legs.append(piv)


func _build_fish() -> void:
	## A fish of `fish.len` metres, head at -Z: a body, a tail that beats, a
	## dorsal fin and two pectoral fins, shaped by its `fish` keys (see the
	## top). Its origin is at its middle.
	var f: Dictionary = def.fish
	var L: float = f.len
	var col: Color = f.col
	var deep: float = f.get("depth", 1.0)
	var slim: float = f.get("slim", 1.0)
	var shark: bool = f.get("shark", false)
	var dark := col.darkened(0.2)
	_add(_part("fish_body_" + species, func(b):
		b.blob(Vector3(0, 0, 0), Vector3(L * 0.12 * slim, L * 0.15 * deep * slim, L * 0.38), 2, 7, col)
		b.blob(Vector3(0, -L * 0.04 * deep, -L * 0.05), Vector3(L * 0.1 * slim, L * 0.09 * deep * slim, L * 0.3), 2, 6, col.lightened(0.35))
		for sx in [1.0, -1.0]:
			b.blob(Vector3(L * 0.07 * slim * sx, L * 0.04, -L * 0.3), Vector3(L * 0.025, L * 0.025, L * 0.025), 1, 5, Color(0.1, 0.1, 0.08))
		# Dorsal fin: a shark's sits further back.
		var dz := L * (0.08 if shark else -0.05)
		b.leaf(Vector3(0, L * 0.12 * deep * slim, dz), Vector3(0, 0.6 * deep, 1).normalized(), L * 0.25, L * 0.08, 0.0, 2, dark)
		# Pectoral fins: fleshy lobes on a coelacanth, plain fins otherwise.
		for sx in [1.0, -1.0]:
			if f.get("lobes", false):
				b.blob(Vector3(L * 0.12 * sx, -L * 0.06, -L * 0.15), Vector3(L * 0.05, L * 0.03, L * 0.08), 1, 5, dark)
			else:
				b.leaf(Vector3(L * 0.09 * slim * sx, -L * 0.06, -L * 0.18), Vector3(sx, -0.4, 0.6).normalized(), L * 0.16, L * 0.06, 0.0, 2, col.darkened(0.1))
		if f.has("snout"):
			# Bandringa's long, flat, paddle-like snout.
			b.blob(Vector3(0, L * 0.02, -L * (0.38 + f.snout * 0.5)), Vector3(L * 0.07, L * 0.02, L * f.snout * 0.5), 1, 6, dark)
		if f.get("head_spine", false):
			# A xenacanth's long spine, sweeping back from behind the head.
			b.cone(Vector3(0, L * 0.12 * slim, -L * 0.22), Vector3(0, L * 0.3 * slim, L * 0.05), L * 0.025, 4, Color(0.75, 0.72, 0.62))
		if f.get("spines", false):
			# An acanthodian's stiff spines in front of each fin.
			b.cone(Vector3(0, L * 0.1 * slim, -L * 0.08), Vector3(0, L * 0.24 * slim, -L * 0.02), L * 0.015, 4, Color(0.8, 0.78, 0.7))
			for sx in [1.0, -1.0]:
				b.cone(Vector3(L * 0.08 * slim * sx, -L * 0.07, -L * 0.2), Vector3(L * 0.2 * sx, -L * 0.12, -L * 0.12), L * 0.012, 4, Color(0.8, 0.78, 0.7))), _body, Vector3.ZERO)
	var tail := _pivot(_body, Vector3(0, 0, L * 0.32))
	_add(_part("fish_tail_" + species, func(b):
		b.blob(Vector3(0, 0, L * 0.08), Vector3(L * 0.06 * slim, L * 0.08 * slim, L * 0.12), 2, 6, col)
		# A shark's tail has a long upper lobe.
		b.leaf(Vector3(0, 0, L * 0.16), Vector3(0, 0.5, 1).normalized(), L * (0.3 if shark else 0.2), L * 0.1, 0.0, 2, col.darkened(0.25))
		b.leaf(Vector3(0, 0, L * 0.16), Vector3(0, -0.5, 1).normalized(), L * (0.12 if shark else 0.2), L * 0.1, 0.0, 2, col.darkened(0.25))), tail, Vector3.ZERO)
	_tail.append(tail)


func _think_fish(delta: float) -> void:
	## Swimming, its tail beats (the line moves it). On land it flops about
	## on its side without going anywhere, and dies after SUFFOCATE seconds.
	var on_land: bool = world != null and _ground(position.x, position.z) >= world.water_level() - 0.05
	_phase += delta * (16.0 if on_land else 9.0)
	for t in _tail:
		t.rotation.y = sin(_phase) * (0.7 if on_land else 0.35)
	if not on_land:
		out_of_water = 0.0
		_body.rotation = Vector3.ZERO
		_body.position = Vector3.ZERO
		return
	out_of_water += delta
	var hop := absf(sin(_phase * 0.4))
	_body.rotation = Vector3(sin(_phase * 0.4) * 0.35, 0, PI * 0.5 + sin(_phase * 0.8) * 0.25)
	_body.position = Vector3(0, def.radius * 0.6 + hop * def.fish.len * 0.12, 0)
	_snap_at_player()
	if out_of_water >= suffocate_time():
		_die(null)


func suffocate_time() -> float:
	## How long this fish lives out of the water (a lungfish breathes air).
	return SUFFOCATE * (AIR_MULT if def.get("fish", {}).get("air", false) else 1.0)


func _snap_at_player() -> void:
	## A landed shark snaps at a player in reach.
	var bite: float = def.fish.get("bite", 0.0)
	var player: Node3D = Game.player
	if bite <= 0.0 or _cd > 0.0 or player == null or not Game.hostile() or player.vitals.dead:
		return
	if global_position.distance_to(player.global_position) > float(def.fish.get("bite_reach", 1.5)):
		return
	_cd = float(def.fish.get("snap_every", 2.5))
	Sfx.play_at("hiss", global_position, 0.0, 0.2)
	player.hurt(bite, global_position, 0.4, "fish")
	Game.notify("The %s snaps at you!" % def.name)


func _build_meganeura() -> void:
	var col := Color(0.15, 0.32, 0.30)
	_add(_part("meg_body", func(b):
		b.blob(Vector3(0, 0, -0.12), Vector3(0.05, 0.05, 0.08), 2, 5, col)
		b.blob(Vector3(0.04, 0.02, -0.2), Vector3(0.035, 0.035, 0.035), 1, 5, Color(0.5, 0.15, 0.1))
		b.blob(Vector3(-0.04, 0.02, -0.2), Vector3(0.035, 0.035, 0.035), 1, 5, Color(0.5, 0.15, 0.1))
		b.cylinder(Vector3(0, 0, -0.05), Vector3(0, 0, 0.45), 0.025, 0.015, 5, col.lerp(Color(0.5, 0.4, 0.1), 0.5))), _body, Vector3.ZERO)
	var wing := _part("meg_wing", func(b): b.leaf(Vector3.ZERO, Vector3(1, 0, 0), 0.38, 0.11, 0.0, 3, Color(0.75, 0.80, 0.70), Color(0.55, 0.60, 0.50)))
	for z in [-0.1, -0.02]:
		for s in [1.0, -1.0]:
			var piv := _pivot(_body, Vector3(0.03 * s, 0.03, z))
			var mi := _add(wing, piv, Vector3.ZERO)
			mi.scale.x = s
			_wings.append(piv)
	_body.scale = Vector3.ONE * 1.3
	_buzz = AudioStreamPlayer3D.new()
	_buzz.stream = Sfx.stream("buzz")
	_buzz.volume_db = -14.0
	_buzz.max_distance = 18.0
	_buzz.unit_size = 3.0
	add_child(_buzz)
	_buzz.play.call_deferred()


# --- Behaviour ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if dead:
		return
	if carried_by:
		_carried(delta)
		return
	var player: Node3D = Game.player
	var dist := 1e9
	if player:
		dist = global_position.distance_to(player.global_position)
	# Far creatures think a quarter as often.
	_frame += 1
	if dist > 60.0:
		_far_acc += delta
		if _frame % 4 != 0:
			return
		delta = _far_acc
		_far_acc = 0.0
	_cd = maxf(_cd - delta, 0.0)
	_state_t -= delta
	_anger = maxf(_anger - delta, 0.0)
	_frenzy = maxf(_frenzy - delta, 0.0)
	if _stun > 0.0:
		_stunned(delta)
		return
	if blown > 0.0:
		_blown_away(delta)
		return

	if state == "raft_bite":
		_hold_raft_bite(delta)
		return
	# A debug world can make every animal leave the player alone. Nothing
	# comes for you in a house, on a finished dock or in an island's safe
	# water; out on a raft the danger is a bite on its corner (raft.gd).
	var quarry: Node3D = player if player and Game.hostile() and not Game.safe(player.global_position) \
			and player.get("riding") == null else null
	if drawn and _think_drawn(quarry, dist, delta):
		return
	match def.behavior:
		"fish":
			_think_fish(delta)
			return
		"prey":
			_think_prey(player, dist)
		"hunter", "defensive":
			_think_hunter(quarry, dist, delta)
		"lurker":
			_think_lurker(quarry, dist, delta)
			return
		"ambusher":
			_think_ambusher(quarry, dist, delta)
			return
		"flyer":
			_think_flyer(quarry, dist, delta)
			return
	var spd: float = def.run if state in ["flee", "chase", "hunt"] else (def.speed * 2.0 if state == "scavenge" \
			else (def.speed if state == "wander" else 0.0))
	if state == "wander" and global_position.distance_to(_target) < 1.0:
		state = "idle"
		_state_t = _rng.randf_range(2.0, 6.0)
	if state == "idle" and _state_t <= 0.0:
		_pick_wander()
	_steer(_target, spd, delta)
	if snared:
		_hold_in_snare()
	if dist < 70.0:
		_animate(spd, delta)


func _hold_in_snare() -> void:
	## Caught in a snare: it strains at the noose but gets no further.
	if not is_instance_valid(snared):
		snared = null
		return
	var a: Vector3 = snared.leash_point()
	var off := global_position - a
	off.y = 0.0
	if off.length() > snared.LEASH:
		off = off.normalized() * snared.LEASH
		global_position = Vector3(a.x + off.x, _ground(a.x + off.x, a.z + off.z), a.z + off.z)


func _pick_wander() -> void:
	state = "wander"
	var a := _rng.randf() * TAU
	_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 14.0)


func _sense(dist: float) -> float:
	return def.sense * (1.3 if Game.is_night() else 1.0)


func _think_prey(player: Node3D, dist: float) -> void:
	if player and dist < _sense(dist):
		state = "flee"
		_target = global_position + (global_position - player.global_position).normalized() * 10.0
	elif state == "flee" and dist > _sense(dist) * 1.8:
		_pick_wander()


func _think_hunter(player: Node3D, dist: float, delta: float) -> void:
	var fire: Node3D = Game.nearest_fire(global_position, 9.0)
	if fire and def.behavior == "hunter":
		state = "flee"
		_target = global_position + (global_position - fire.global_position).normalized() * 8.0
		return
	# Land scavengers (def.scavenger) hunt small prey while left alone. A hunter
	# drops its meal to fight a player who walks right up to it.
	if def.get("scavenger", false) and _anger <= 0.0:
		var busy: bool = state in ["hunt", "maul", "scavenge", "feed"]
		var close: bool = player != null and not player.vitals.dead and dist < def.reach + 0.8
		var noticed: bool = player != null and not player.vitals.dead and dist < _sense(dist)
		if def.behavior == "hunter" and (close or (noticed and not busy)):
			_stop_feeding()
		elif _forage(delta):
			return
	if player == null or player.vitals.dead:
		if state in ["chase", "attack"]:
			_pick_wander()
		return
	var aggressive: bool = def.behavior == "hunter" or _anger > 0.0
	var player_in_water: bool = player.water_depth() > 0.6
	if state == "attack":
		_windup -= delta
		_face(player.global_position, delta)
		if _windup <= 0.0:
			if dist < def.reach + 0.6:
				player.hurt(def.damage, global_position)
				if def.has("venom") and _rng.randf() < def.venom_chance:
					player.vitals.poison(def.venom)
			_cd = def.cooldown
			state = "chase"
		return
	if aggressive and dist < _sense(dist) * (2.2 if state == "chase" else 1.0) and not player_in_water \
			and Game.nearest_fire(player.global_position, 7.0) == null:
		if state != "chase":
			Sfx.play_at(def.get("sound", "hiss"), global_position, -2.0)
		state = "chase"
		_target = player.global_position
		if dist < def.reach and _cd <= 0.0:
			state = "attack"
			_windup = def.windup
			Sfx.play_at(def.get("sound", "hiss"), global_position, 0.0, 0.2)
	elif state in ["chase", "flee"]:
		_pick_wander()


func _forage(delta: float) -> bool:
	## Land scavengers (Arthropleura, Pulmonoscorpius): run down a small prey animal
	## that strays close, kill it and eat the whole body in FEED_TIME seconds.
	## Guts piles and dead animals up to their own size close by are eaten too
	## (a carcass takes longer). The player can snatch a half-eaten carcass,
	## which provokes the eater. True while it is busy with one.
	match state:
		"scavenge":
			if not _food_ok(_prey) or _state_t <= 0.0:
				_prey = null
				_pick_wander()
				return false
			_target = _prey.global_position
			if _prey.global_position.distance_to(global_position) < def.reach * 0.7 + 0.6:
				_start_feeding(_prey)
			return true
		"hunt":
			if not _small_prey_ok(_prey) or _state_t <= 0.0 \
					or _prey.global_position.distance_to(global_position) > FORAGE_RANGE * 1.6:
				_prey = null
				_pick_wander()
				return false
			_target = _prey.global_position
			if _prey.global_position.distance_to(global_position) < def.reach * 0.7 + _prey.hit_radius:
				state = "maul"
				_windup = def.windup
				Sfx.play_at(def.get("sound", "hiss"), global_position, -4.0, 0.2)
			return true
		"maul":
			_windup -= delta
			if not _small_prey_ok(_prey):
				_prey = null
				_pick_wander()
				return false
			_face(_prey.global_position, delta)
			if _windup <= 0.0:
				if _prey.global_position.distance_to(global_position) < def.reach + _prey.hit_radius:
					_prey.take_damage(def.damage, self)
				if _prey.dead:
					_start_feeding(_prey)
				else:
					state = "hunt"
			return true
		"feed":
			if _prey == null or not is_instance_valid(_prey) or _prey.eaten_by != self:
				_prey = null
				_pick_wander()
				return false
			_face(_prey.global_position, delta)
			# The body shrinks away as it is eaten.
			if _prey._body:
				_prey._body.scale = Vector3.ONE * clampf(_state_t / _feed_time(_prey), 0.15, 1.0)
			if _state_t <= 0.0:
				_prey.queue_free()
				_prey = null
				_cd = 40.0
				_pick_wander()
			return true
	if _cd > 0.0 or not state in ["wander", "idle"]:
		return false
	_scan_t -= delta
	if _scan_t > 0.0:
		return false
	_scan_t = 1.0
	for c in Game.creatures:
		if c != self and is_instance_valid(c) and c.def.behavior == "prey" and _small_prey_ok(c) \
				and c.global_position.distance_to(global_position) < FORAGE_RANGE:
			_prey = c
			state = "hunt"
			_state_t = 12.0
			return true
	var food := _food_near(FORAGE_RANGE)
	if food:
		_prey = food
		state = "scavenge"
		_state_t = 15.0
		return true
	return false


func _food_near(r: float) -> Node3D:
	## The nearest guts pile or carcass within r that it could eat.
	var best: Node3D = null
	var best_d := r
	for g in get_tree().get_nodes_in_group("guts"):
		if _food_ok(g) and g.global_position.distance_to(global_position) < best_d:
			best = g
			best_d = g.global_position.distance_to(global_position)
	for c in Game.creatures:
		if c != self and _food_ok(c) and c.global_position.distance_to(global_position) < best_d:
			best = c
			best_d = c.global_position.distance_to(global_position)
	return best


func _food_ok(f: Node3D) -> bool:
	## Guts, or a carcass no bigger than itself that is left lying about.
	if f == null or not is_instance_valid(f) or f.is_queued_for_deletion():
		return false
	if f.eaten_by != null and is_instance_valid(f.eaten_by) and f.eaten_by != self:
		return false
	if not "species" in f:
		return true
	return f.dead and f.hauled_by == null and not f.in_jaws() \
			and (f.def.size == "small" or (f.def.size == "medium" and def.size != "small"))


static func _feed_time(f: Node3D) -> float:
	if not "species" in f:
		return FEED_TIME * 1.6
	return FEED_TIME * (4.0 if f.def.size == "medium" else 1.0)


func _start_feeding(f: Node3D) -> void:
	state = "feed"
	_prey = f
	_state_t = _feed_time(f)
	f.eaten_by = self
	if "gnawed" in f:
		f.gnawed = true


func _stop_feeding() -> void:
	## Leaves the lizard it was after (what is left of it stays on the ground).
	if state in ["hunt", "maul", "scavenge", "feed"]:
		if _prey and is_instance_valid(_prey) and _prey.eaten_by == self:
			_prey.eaten_by = null
		_prey = null
		state = "idle"
		_state_t = 0.0


func provoke() -> void:
	## Someone took its food: it turns on the player.
	_stop_feeding()
	_anger = 25.0
	_cd = 0.0
	state = "chase"
	Sfx.play_at(def.get("sound", "hiss"), global_position, 2.0, 0.2)


func _small_prey_ok(c: Node3D) -> bool:
	## A lizard still on the ground for the taking.
	return c != null and is_instance_valid(c) and not c.dead and c.carried_by == null


func _carried(delta: float) -> void:
	## A lizard in a dragonfly's legs: it wriggles while the Meganeura holds
	## it in place. If the dragonfly is gone, it drops.
	if not is_instance_valid(carried_by) or carried_by.dead or carried_by._prey != self:
		carried_by = null
		stun(1.5)
		return
	_phase += delta * 22.0
	for i in _legs.size():
		_legs[i].rotation.z = sin(_phase + i * 1.3) * 0.5
	_body.rotation.z = sin(_phase * 0.4) * 0.3


func _drop_prey() -> void:
	## A dragonfly lets go of the lizard it carries.
	if _prey and is_instance_valid(_prey) and _prey.carried_by == self:
		_prey.carried_by = null
		if not _prey.dead:
			_prey.stun(1.5)
	_prey = null


# --- Lurker (amphibian) ---------------------------------------------------------------

func set_mode(m: String, water: Vector3) -> void:
	## Where it lives: "bask" on the bank (home) or, for the Eogyrinus, "lurk"
	## around `water` or "land" roaming near home; for the Uranocentrodon,
	## "hide" buried at home. `water` is the deep water it drags prey into.
	mode = m
	water_home = water
	state = "wander" if m == "land" else m
	if m == "hide":
		submerged = true
		position.y = _ground(position.x, position.z) - 1.3
		_body.visible = false


func in_deep_water() -> bool:
	## Whether it has hauled a victim out to its deep water.
	return _ground(global_position.x, global_position.z) < -0.9 \
			or Vector2(global_position.x - water_home.x, global_position.z - water_home.z).length() < 1.5


func head_position() -> Vector3:
	return _jaw.global_position if _jaw else global_position + Vector3(0, 0.4, 0)


func grab_anchor() -> Vector3:
	## Where a seized player is held: just in front of the jaws.
	var fwd := Vector3(sin(heading), 0, cos(heading))
	var p := head_position() + fwd * float(def.get("anchor", 0.75))
	p.y = maxf(_ground(p.x, p.z), -1.6)
	return p


func _leash_ok(p: Vector3) -> bool:
	## Amphibians never chase far from the water they live in (or, roaming on
	## land, from their home ground).
	if mode == "land":
		return Vector2(p.x - home.x, p.z - home.z).length() < def.leash * 1.5
	if def.behavior == "ambusher":
		# It follows prey (or whoever hit it) a little further than it would
		# strike from its spot.
		return Vector2(p.x - home.x, p.z - home.z).length() < def.leash \
				+ (10.0 if _prey or _provoked > 0.0 or state in ["strike", "stalk"] else 0.0)
	return _ground(p.x, p.z) < 1.2 and Vector2(p.x - water_home.x, p.z - water_home.z).length() < def.leash


func start_raft_bite(raft: Node3D, corner: int) -> void:
	## Jaws clamped on a corner of a raft: it holds on there, up at the
	## surface, until it is struck or the raft goes over.
	_raft = raft
	_raft_corner = corner
	_stop_feeding_guts()
	_prey = null
	state = "raft_bite"
	submerged = false
	_body.visible = true
	_hold_raft_bite(1.0)


func end_raft_bite(struck: bool) -> void:
	_raft = null
	if state != "raft_bite":
		return
	state = "retreat" if def.behavior == "lurker" else "return"
	if mode != "land":
		mode = "hide" if def.behavior == "ambusher" else "lurk"
	if def.behavior == "ambusher":
		home = Vector3(global_position.x, _ground(global_position.x, global_position.z), global_position.z)
	_calm = 90.0 if struck else 30.0
	if struck:
		Sfx.play_at("croak", global_position, 4.0)


func _hold_raft_bite(delta: float) -> void:
	if _raft == null or not is_instance_valid(_raft) or _raft.is_queued_for_deletion():
		end_raft_bite(false)
		return
	var c: Vector3 = _raft.corner_global(_raft_corner)
	var out := c - _raft.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var at := c + out * (hit_radius + 0.6)
	global_position = Vector3(at.x, c.y - 0.3, at.z)
	_face(c, 1.0)
	_body.rotation.z = sin(Time.get_ticks_msec() * 0.016) * 0.12
	_gape = 0.2
	if _jaw:
		_jaw.rotation.x = _gape * 0.9
	_animate(0.0, delta)
	_update_ripples(delta)


func attack_now(player: Node3D) -> void:
	## Seize the player immediately (an attack while they sleep).
	_face(player.global_position, 1.0)
	_grab(player)


func _grab(player: Node3D) -> void:
	state = "grab"
	_victim = player
	submerged = false
	_body.visible = true
	player.start_grab(self)


func release(stabbed: bool) -> void:
	_victim = null
	state = "retreat"
	if mode != "land":
		mode = "hide" if def.behavior == "ambusher" else "lurk"
	_calm = 120.0
	if stabbed:
		Sfx.play_at("croak", global_position, 4.0)


func victim_died() -> void:
	_victim = null
	state = "retreat"
	if mode != "land":
		mode = "hide" if def.behavior == "ambusher" else "lurk"
	_calm = 60.0


func flee_from(threat: Node3D) -> void:
	## Leave the water for dry land, away from a bigger predator, and stay
	## there as a land wanderer.
	if state == "grab":
		return
	var away := global_position - threat.global_position
	var base := atan2(away.x, away.z) if Vector2(away.x, away.z).length() > 0.1 else _rng.randf() * TAU
	var spot := global_position + Vector3(sin(base), 0, cos(base)) * 20.0
	var found := false
	for r in [8.0, 14.0, 20.0, 28.0]:
		for off in [0.0, 0.5, -0.5, 1.0, -1.0]:
			var a: float = base + off
			var q: Vector3 = global_position + Vector3(sin(a), 0, cos(a)) * r
			if _ground(q.x, q.z) > 0.4:
				spot = q
				found = true
				break
		if found:
			break
	mode = "land"
	home = spot
	state = "retreat"
	submerged = false
	_calm = 30.0


func _think_lurker(player: Node3D, dist: float, delta: float) -> void:
	_calm = maxf(_calm - delta, 0.0)
	var alive: bool = player != null and not player.vitals.dead and player.grabbed_by == null
	var p_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var trigger: float = def.sense * (1.3 if Game.is_night() else 1.0)
	if mode == "bask":
		trigger += 1.5
	if player and player.water_depth() > 0.3:
		trigger += 3.0
	var spd := 0.0
	var goal := global_position
	match state:
		"grab":
			if _victim == null or not is_instance_valid(_victim):
				state = "retreat"
			else:
				_face(_victim.global_position, delta)
				# Back away toward deep water, dragging the victim.
				if mode != "land" and _ground(global_position.x, global_position.z) > -1.0:
					var back := (water_home - global_position)
					back.y = 0.0
					if back.length() > 0.5:
						position += back.normalized() * 0.7 * delta
				_body.rotation.z = sin(Time.get_ticks_msec() * 0.014) * 0.1
				_gape = lerpf(_gape, 0.12, minf(delta * 10.0, 1.0))
		"retreat":
			goal = home if mode == "land" else water_home
			spd = 3.2
			if _frenzy > 0.0:
				state = "frenzy"  # back to the baitbox, if it is still there
			elif Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 1.5:
				state = "wander" if mode == "land" else "lurk"
		"lunge":
			# Snapping at a splash, then lurking there.
			_strike_t -= delta
			goal = _lure
			spd = def.run
			if _strike_t <= 0.0 or Vector2(global_position.x - _lure.x, global_position.z - _lure.z).length() < 1.5:
				_gape = 0.9
				Sfx.play_at("splash", global_position, 2.0)
				state = "lurk"
		"charge":
			if not alive or not _leash_ok(p_pos):
				state = "retreat"
			else:
				goal = p_pos
				spd = def.run
				if dist < 2.2:
					_grab(player)
		"approach":
			# Drawn by blood in the water: up at the surface, slowly closing in on
			# you, and charging as usual once you are near enough.
			_approach -= delta
			water_home = Vector3(global_position.x, 0.0, global_position.z)  # it moves house as it comes
			if not alive or _approach <= 0.0 or dist > SCENT_RADIUS * 1.5:
				state = "lurk"
			elif dist < trigger and _leash_ok(p_pos):
				_charge()
			else:
				var at := _closing_in(p_pos, delta)
				if at != global_position:
					goal = at
					spd = def.speed * 1.5
		"seek":
			# Hurrying to guts it smelled (see _think_drawn).
			goal = _target
			spd = def.speed * 2.5
		"feed":
			# Tearing at the guts it was drawn to.
			if _prey == null or not is_instance_valid(_prey) or _prey.eaten_by != self:
				_prey = null
				state = "wander"
			else:
				_face(_prey.global_position, delta)
				_gape = 0.45 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
				if _state_t <= 0.0:
					_prey.queue_free()
					_prey = null
					state = "wander"
		"frenzy":
			# Tearing at a baitbox; a player as close as would always set it
			# off is charged as usual.
			if _frenzy <= 0.0:
				state = "lurk"
			elif alive and _calm <= 0.0 and dist < trigger and _leash_ok(p_pos):
				_charge()
			else:
				goal = _frenzy_goal()
				spd = def.run if _far_from_frenzy() else def.speed * 3.0
		"bask":
			if Game.is_night():
				mode = "lurk"
				state = "retreat"
			elif alive and _calm <= 0.0 and dist < trigger and _leash_ok(p_pos):
				_charge()
			elif _rng.randf() < delta * 0.05:
				_gape = 0.6   # basking with the mouth open
		_:  # "lurk", "wander", "idle": cruise slowly around the water home
			if alive and _calm <= 0.0 and dist < trigger and _leash_ok(p_pos):
				_charge()
			else:
				if state != "wander" or global_position.distance_to(_target) < 1.0:
					state = "wander"
					var a := _rng.randf() * TAU
					if mode == "land":
						_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(3.0, 14.0)
					else:
						_target = water_home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, 6.0)
				goal = _target
				spd = def.speed
	if state == "frenzy":
		_steer(goal, spd, delta)
		_thrash(delta)
	elif state != "grab":
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, minf(delta * 4.0, 1.0))
		_steer(goal, spd, delta)
		if state == "charge" or state == "lunge":
			_gape = lerpf(_gape, 0.75, minf(delta * 6.0, 1.0))
		elif state == "feed":
			pass
		elif state != "bask":
			_gape = lerpf(_gape, 0.0, minf(delta * 3.0, 1.0))
		else:
			_gape = maxf(_gape - delta * 0.08, 0.0)

	# Height: lie on the bank, swim at the surface, or sink out of sight.
	var h := _ground(global_position.x, global_position.z)
	submerged = state in ["lurk", "wander", "idle"] and h < -0.9
	var want_y := maxf(h, -0.35)
	if submerged:
		want_y = maxf(h + 0.05, -0.95)
	position.y = lerpf(position.y, want_y, minf(delta * 3.0, 1.0))
	_body.visible = not submerged
	if _jaw:
		_jaw.rotation.x = _gape * 0.9
	if dist < 70.0:
		_animate(spd, delta)
		_update_ripples(delta)


func _think_drawn(player: Node3D, dist: float, delta: float) -> bool:
	## An animal drawn by the smell of a guts pile (swamp.draw_to_guts). It
	## turns on a player near it or near the guts; otherwise it eats them and
	## then hangs about there for LINGER seconds. True when it has moved this
	## frame itself (the usual behaviour is skipped).
	var near: bool = player != null and not player.vitals.dead and player.grabbed_by == null \
			and (dist < DRAWN_NOTICE or player.global_position.distance_to(_bait_pos) < DRAWN_NOTICE)
	if bait != null and not is_instance_valid(bait):
		bait = null
	if bait == null and _linger <= 0.0 and not state in ["feed", "scavenge"]:
		# Eaten (or taken away): it stays around where they were.
		_linger = LINGER
		home = _bait_pos
		if def.behavior != "lurker":
			_pick_wander()
	if _linger > 0.0:
		_linger -= delta
		if _linger <= 0.0:
			drawn = false
	if near:
		if def.behavior == "lurker":
			if not state in ["charge", "grab", "retreat"] and _leash_ok(player.global_position):
				_stop_feeding_guts()
				_charge()
			return false
		if state == "feed" or state == "scavenge":
			_stop_feeding()
		if _anger < 1.0:
			Sfx.play_at(def.get("sound", "hiss"), global_position, 0.0, 0.2)
		_anger = maxf(_anger, 3.0)
		if dist > _sense(dist) * (2.2 if state == "chase" else 1.0) and state != "attack" \
				and Game.nearest_fire(player.global_position, 7.0) == null:
			# Too far for it to have noticed by itself: it comes on anyway.
			state = "chase"
			_target = player.global_position
			_steer(_target, def.run, delta)
			if dist < 70.0:
				_animate(def.run, delta)
			return true
		return false
	if bait == null:
		return false
	if def.behavior == "lurker":
		if state in ["feed", "charge", "grab", "retreat"]:
			return false
		if bait.global_position.distance_to(global_position) < def.radius + 1.4:
			_stop_feeding_guts()
			state = "feed"
			_prey = bait
			_state_t = FEED_TIME * 1.6
			bait.eaten_by = self
		else:
			state = "seek"
			_target = bait.global_position
		return false
	if not state in ["scavenge", "feed", "chase", "attack"] and _food_ok(bait):
		_anger = 0.0
		_prey = bait
		state = "scavenge"
		_state_t = 120.0
	return false


func _stop_feeding_guts() -> void:
	## A lurker leaves the guts it was eating.
	if state == "feed" and _prey and is_instance_valid(_prey) and _prey.eaten_by == self:
		_prey.eaten_by = null
	_prey = null


func _charge() -> void:
	state = "charge"
	submerged = false
	Sfx.play_at("roar", global_position, 0.0, 0.1)


func _think_ambusher(player: Node3D, dist: float, delta: float) -> void:
	## Uranocentrodon. Lies still, basking or buried; strikes whatever comes to
	## the water's edge within reach, drags it into deep water, then returns to
	## its spot and buries itself again.
	_calm = maxf(_calm - delta, 0.0)
	_provoked = maxf(_provoked - delta, 0.0)
	var spd := 0.0
	var goal := global_position
	match state:
		"lunge":
			# Erupts at a splash and snaps at it, then buries itself there.
			_strike_t -= delta
			var to := _lure - global_position
			to.y = 0.0
			heading = atan2(to.x, to.z)
			rotation.y = heading + PI
			if _strike_t <= 0.0 or to.length() < 1.2:
				_gape = 1.0
				Sfx.play_at("splash", global_position, 4.0)
				Sfx.play_at("roar", global_position, 0.0, 0.1)
				state = "return"
			else:
				position += to.normalized() * minf(def.run * 0.8 * delta, to.length())
		"bask", "hide":
			if state == "bask" and Game.is_night():
				mode = "hide"
				home = water_home
				state = "return"
			elif _calm <= 0.0:
				_look_for_quarry(player, dist, delta)
				if state == "bask" and player != null and dist < STALK_RANGE and player.grabbed_by == null and not player.vitals.dead \
						and _ground(player.global_position.x, player.global_position.z) < 1.2:
					state = "stalk"
			if state == "bask" and _rng.randf() < delta * 0.05:
				_gape = 0.6
		"frenzy":
			# Tearing at a baitbox, up at the surface; a player as close as
			# would always set off one up out of the mud is struck as usual.
			if _frenzy <= 0.0:
				state = "return"  # buries itself where the box was
			elif _calm <= 0.0 and player != null and not player.vitals.dead and player.grabbed_by == null \
					and dist < def.strike + 1.0 and _leash_ok(player.global_position) \
					and _ground(player.global_position.x, player.global_position.z) < 0.6:
				_strike(null)
			else:
				goal = _frenzy_goal()
				spd = def.run * 0.8 if _far_from_frenzy() else def.speed * 4.0
		"approach":
			# Drawn by blood in the water: risen to the surface, it swims slowly
			# in toward you, and strikes just as a buried one would once you
			# are within its reach.
			_approach -= delta
			home = Vector3(global_position.x, _ground(global_position.x, global_position.z), global_position.z)
			if player == null or player.vitals.dead or player.grabbed_by != null or _approach <= 0.0 \
					or dist > SCENT_RADIUS * 1.5:
				mode = "hide"
				state = "return"
			elif (dist < def.get("ambush", 0.0) and world and world.get("player_at_shore") == true) \
					or (dist < def.strike + 1.0 and _ground(player.global_position.x, player.global_position.z) < 0.6):
				_strike(null)
				_strike_t = 1.5 + dist / def.run * 1.5
			else:
				var at := _closing_in(player.global_position, delta)
				if at != global_position:
					goal = at
					spd = def.speed * 2.0
		"stalk":
			# Basking, it has noticed you and creeps nearer, low and slow, until
			# you are in reach. It will not climb onto high ground or stray far
			# from its water.
			if Game.is_night() or player == null or player.vitals.dead or player.grabbed_by != null \
					or dist > STALK_RANGE * 1.3:
				state = "return"
			else:
				_look_for_quarry(player, dist, delta)
				if state == "stalk":
					var ahead := global_position + (player.global_position - global_position).normalized() * 1.2
					if _ground(ahead.x, ahead.z) < 1.2 \
							and Vector2(ahead.x - water_home.x, ahead.z - water_home.z).length() < def.leash * 1.5:
						goal = player.global_position
						spd = def.speed * 1.4
					else:
						_face(player.global_position, delta)
		"strike":
			_strike_t -= delta
			var q: Node3D = _prey if _prey else player
			if q == null or not is_instance_valid(q) or _strike_t <= 0.0 or not _leash_ok(q.global_position) \
					or (q == player and (player.vitals.dead or player.grabbed_by != null)) or (q != player and q.dead):
				_prey = null
				state = "return"
			else:
				var to := q.global_position - global_position
				to.y = 0.0
				heading = atan2(to.x, to.z)
				rotation.y = heading + PI
				var reach: float = def.grab_dist + (q.hit_radius if q != player else 0.0)
				if to.length() < reach:
					if q == player:
						_grab(player)
					else:
						q.take_damage(def.kill, self)
						Sfx.play_at("roar", global_position, 2.0, 0.1)
						state = "feed" if q.dead else "return"
						if q.dead:
							q.carried_by = self
						else:
							_prey = null
				else:
					position += to.normalized() * minf(def.run * delta, to.length())
		"grab":
			if _victim == null or not is_instance_valid(_victim):
				state = "return"
			else:
				_face(_victim.global_position, delta)
				# Haul the victim into deep water fast, thrashing.
				var back := water_home - global_position
				back.y = 0.0
				if back.length() > 0.5:
					position += back.normalized() * minf(def.get("drag", 1.1) * delta, back.length())
				_body.rotation.z = sin(Time.get_ticks_msec() * 0.018) * 0.12
				_gape = lerpf(_gape, 0.15, minf(delta * 10.0, 1.0))
		"feed":
			# Haul the kill into deep water and take it under.
			if _prey == null or not is_instance_valid(_prey):
				_prey = null
				state = "return"
			else:
				goal = water_home
				spd = 2.4
				_prey.global_position = grab_anchor()
				if Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 1.5:
					_prey.queue_free()
					_prey = null
					mode = "hide"
					home = water_home
					state = "return"
		"pursue":
			# Chasing a rival through the shallows until it is out on dry land.
			_strike_t -= delta
			var q: Node3D = _prey
			if q == null or not is_instance_valid(q) or q.dead or _strike_t <= 0.0 \
					or _ground(q.global_position.x, q.global_position.z) > 0.3 or not _leash_ok(q.global_position):
				_prey = null
				state = "return"
			elif Vector2(q.global_position.x - global_position.x, q.global_position.z - global_position.z).length() < def.strike:
				_strike(q)
			else:
				goal = q.global_position
				spd = 3.6
		_:  # "retreat", "return": go back to its spot
			state = "return"
			goal = home
			spd = 2.2
			if _frenzy > 0.0:
				state = "frenzy"  # back to the baitbox, if it is still there
			elif Vector2(global_position.x - goal.x, global_position.z - goal.z).length() < 1.2:
				state = "bask" if mode == "bask" else "hide"
				mode = state
	if state == "frenzy":
		_steer(goal, spd, delta)
		_thrash(delta)
	elif state != "grab":
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, minf(delta * 4.0, 1.0))
		if spd > 0.0:
			_steer(goal, spd, delta)
		if state in ["strike", "lunge", "feed"]:
			_gape = lerpf(_gape, 0.8 if state == "strike" else 0.2, minf(delta * 12.0, 1.0))
		elif state != "bask":
			_gape = lerpf(_gape, 0.0, minf(delta * 3.0, 1.0))
		else:
			_gape = maxf(_gape - delta * 0.08, 0.0)

	# Buried in the mud it sits well below the ground, out of sight; anything
	# else lies on the bank or swims at the surface. It erupts out fast.
	var h := _ground(global_position.x, global_position.z)
	if state == "hide":
		position.y = lerpf(position.y, h - 1.3, minf(delta * 0.8, 1.0))
	else:
		position.y = lerpf(position.y, maxf(h, -0.4), minf(delta * (14.0 if state in ["strike", "lunge"] else 4.0), 1.0))
	submerged = state == "hide" and position.y < h - 0.25
	_body.visible = position.y > h - 1.0
	if _jaw:
		_jaw.rotation.x = _gape * 0.9
	if dist < 70.0:
		_animate(spd if not state in ["strike", "lunge"] else 2.0, delta)
		_update_ripples(delta)


func _look_for_quarry(player: Node3D, dist: float, delta: float) -> void:
	## Strike at the player or another animal that is within reach and down at
	## the water's edge (not up on dry ground).
	var reach: float = def.strike + (1.0 if state in ["bask", "stalk"] else 0.0)
	if player and not player.vitals.dead and player.grabbed_by == null:
		# Within reach of the water (or close to it) is far too close to one buried nearby.
		if state == "hide" and dist < def.get("ambush", 0.0) and world and world.get("player_at_shore") == true:
			_strike(null)
			_strike_t = 1.5 + dist / def.run * 1.5
			return
		if dist < reach and _leash_ok(player.global_position) \
				and (state == "stalk" or _ground(player.global_position.x, player.global_position.z) < 0.6):
			_strike(null)
			return
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = 0.3
	for c in Game.creatures:
		if c == self or not is_instance_valid(c) or c.dead or c.species == species or c.def.habitat == "air":
			continue
		var p: Vector3 = c.global_position
		if p.distance_to(global_position) < reach and _ground(p.x, p.z) < 0.6 and _leash_ok(p):
			_strike(c)
			return


func lure(p: Vector3) -> bool:
	## A splash nearby: an amphibian that is not busy with the player lunges
	## at it and settles there, away from wherever it was. False if it ignores it.
	if dead or Vector2(p.x - global_position.x, p.z - global_position.z).length() > LURE_RADIUS:
		return false
	match def.behavior:
		"ambusher":
			if not state in ["bask", "hide", "return"]:
				return false
			home = Vector3(p.x, _ground(p.x, p.z), p.z)
			mode = "hide"
			_prey = null
		"lurker":
			if mode == "land" or not state in ["lurk", "wander", "idle"]:
				return false
			water_home = p
		_:
			return false
	_lure = p
	state = "lunge"
	_strike_t = 2.5
	submerged = false
	_body.visible = true
	return true


func frenzy(at: Vector3, secs: float) -> bool:
	## A baitbox in the water at `at` (swamp.start_frenzy): a Uranocentrodon or
	## Eogyrinus within FRENZY_RADIUS drops whatever it was doing (unless it
	## has hold of the player or a kill), rushes to it and tears at it for
	## `secs`, then settles there. While it lasts it leaves the player alone,
	## unless they come as close as would always set it off. False if it
	## takes no notice.
	if dead or not def.behavior in ["ambusher", "lurker"] \
			or Vector2(at.x - global_position.x, at.z - global_position.z).length() > FRENZY_RADIUS:
		return false
	if state == "grab" or (def.behavior == "ambusher" and state == "feed"):
		return false
	if drawn:
		_stop_feeding_guts()
		drawn = false
		bait = null
		_linger = 0.0
	_prey = null
	_approach = 0.0
	_frenzy = secs
	_frenzy_at = at
	if def.behavior == "ambusher":
		mode = "hide"
		home = Vector3(at.x, _ground(at.x, at.z), at.z)
	else:
		# One roaming on land stays a land animal (free to cross any ground),
		# now at home round the box.
		home = at
		water_home = at
	state = "frenzy"
	submerged = false
	_body.visible = true
	_pick_frenzy_spot()
	if _rng.randf() < 0.35:
		Sfx.play_at("roar", global_position, 0.0, 0.15)
	return true


func _pick_frenzy_spot() -> void:
	## Somewhere close round the baitbox to lunge at next.
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(float(def.radius) * 0.5, float(def.radius) + 3.0)
	_frenzy_spot = _frenzy_at + Vector3(cos(a), 0.0, sin(a)) * r
	_state_t = _rng.randf_range(0.5, 1.5)


func _far_from_frenzy() -> bool:
	return Vector2(global_position.x - _frenzy_at.x, global_position.z - _frenzy_at.z).length() > float(def.radius) + 6.0


func _frenzy_goal() -> Vector3:
	## The spot it is lunging at round the baitbox (a new one now and then).
	if _state_t <= 0.0 or Vector2(global_position.x - _frenzy_spot.x, global_position.z - _frenzy_spot.z).length() < 0.8:
		_pick_frenzy_spot()
	return _frenzy_spot


func _thrash(delta: float) -> void:
	## Rolling, snapping and splashing over the baitbox (or racing to it).
	if _far_from_frenzy():
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, minf(delta * 4.0, 1.0))
		_gape = lerpf(_gape, 0.4, minf(delta * 6.0, 1.0))
		return
	var t := Time.get_ticks_msec() * 0.001 + float(get_instance_id() % 997) * 0.1  # each out of step
	_body.rotation.z = sin(t * 9.0) * 0.18
	_gape = 0.45 + 0.45 * sin(t * 11.0)
	if _rng.randf() < delta * 0.5:
		Sfx.play_at("splash", global_position, -2.0, 0.3)


func scent(at: Vector3, player: Node3D) -> bool:
	## Blood in the water at `at`, from soup with meat in it tipped out by the
	## player. An amphibian lurking in the water within SCENT_RADIUS that is
	## further from the player than it would strike from comes up to the
	## surface and slowly closes in ("approach"); one already in reach strikes
	## as it always would. False if it takes no notice.
	if dead or player == null or not Game.hostile() \
			or Vector2(at.x - global_position.x, at.z - global_position.z).length() > SCENT_RADIUS:
		return false
	var dist := global_position.distance_to(player.global_position)
	match def.behavior:
		"ambusher":
			if mode != "hide" or not state in ["hide", "return"]:
				return false
			if dist < def.get("ambush", 0.0):
				return false  # near enough to strike from where it lies
		"lurker":
			if mode == "land" or not state in ["lurk", "wander", "idle"]:
				return false
			if dist < def.sense * (1.3 if Game.is_night() else 1.0):
				return false
		_:
			return false
	state = "approach"
	_approach = APPROACH_TIME
	_prey = null
	submerged = false
	_body.visible = true
	Sfx.play_at("splash", global_position, -2.0, 0.2)
	return true


func _closing_in(target: Vector3, delta: float) -> Vector3:
	## Where to swim to close in on target without leaving the water: the
	## target itself while the way ahead is still water, or else here (facing
	## it, waiting at the edge).
	var to := target - global_position
	to.y = 0.0
	var ahead: Vector3 = global_position + to.normalized() * (float(def.radius) + 1.0)
	if to.length() > 0.5 and _ground(ahead.x, ahead.z) < -0.3:
		return target
	_face(target, delta)
	return global_position


func stun(secs: float) -> void:
	## Dazed by a thrown rock: it stops where it is (a flyer drops to the ground).
	_stun = secs
	_victim = null
	if def.behavior == "flyer":
		_drop_prey()
	Sfx.play_at(def.get("sound", "hiss"), global_position, -4.0, 0.3)


func _stunned(delta: float) -> void:
	_stun -= delta
	var g := _ground(global_position.x, global_position.z)
	position.y = move_toward(position.y, (maxf(g, 0.0) if def.habitat == "air" else g) + 0.05, delta * 6.0)
	_body.rotation.z = sin(Time.get_ticks_msec() * 0.012) * 0.5 if _stun > 0.0 else 0.0
	if _stun <= 0.0:
		if def.behavior == "flyer":
			state = "wander"
			_altitude = 6.0
		else:
			_pick_wander()


func hunt(rival: Node3D, secs: float) -> void:
	## Drive a rival out of its water: chase it for a while, and take it if it
	## comes within striking reach.
	_prey = rival
	state = "pursue"
	_strike_t = secs
	submerged = false
	_body.visible = true
	Sfx.play_at("roar", global_position, 2.0, 0.1)
	if rival.has_method("flee_from"):
		rival.flee_from(self)


func _strike(quarry: Node3D) -> void:
	_prey = quarry
	state = "strike"
	_strike_t = 2.5
	submerged = false
	_body.visible = true
	Sfx.play_at("roar", global_position, 3.0, 0.05)


func _update_ripples(delta: float) -> void:
	## Expanding rings on the surface are the only sign of a submerged lurker.
	if _ripples.is_empty():
		if _ripple_mesh == null:
			var t := TorusMesh.new()
			t.inner_radius = 0.9
			t.outer_radius = 1.0
			t.rings = 20
			t.ring_segments = 3
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.72, 0.78, 0.66, 0.5)
			t.material = m
			_ripple_mesh = t
		for i in 3:
			var r := MeshInstance3D.new()
			r.mesh = _ripple_mesh
			r.top_level = true
			r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r.visible = false
			add_child(r)
			_ripples.append(r)
			_ripple_age.append(9.0)
	# A buried Uranocentrodon only breathes now and then: small, faint rings
	# that are easy to miss. A submerged Eogyrinus stirs the water constantly.
	var faint: bool = def.behavior == "ambusher"
	var under_water := _ground(global_position.x, global_position.z) < -0.05
	_ripple_t -= delta
	if submerged and under_water and _ripple_t <= 0.0:
		_ripple_t = _rng.randf_range(5.0, 11.0) if faint else _rng.randf_range(1.2, 2.6)
		var i := _ripple_age.find(_ripple_age.max())
		_ripple_age[i] = 0.0
		var fwd := Vector3(sin(heading), 0, cos(heading))
		var back := _rng.randf_range(-1.6, -1.1) if faint else _rng.randf_range(0.6, 1.4)  # nostrils, or the tail
		_ripples[i].global_position = Vector3(global_position.x, 0.02, global_position.z) - fwd * back
	for i in _ripples.size():
		_ripple_age[i] += delta
		var k: float = _ripple_age[i] / (3.2 if faint else 2.6)
		var r := _ripples[i]
		r.visible = k < 1.0
		if r.visible:
			var sc := lerpf(0.15, 1.1, k) if faint else lerpf(0.3, 2.4, k)
			r.scale = Vector3(sc, 0.03 if faint else 0.04, sc)
			r.transparency = lerpf(0.62, 1.0, k) if faint else k


func _think_flyer(player: Node3D, dist: float, delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var ground := maxf(_ground(global_position.x, global_position.z), 0.0)
	var goal: Vector3
	var spd: float = def.speed
	if state == "dive":
		# Swooping on a lizard.
		_strike_t -= delta
		if not _small_prey_ok(_prey) or _strike_t <= 0.0:
			_prey = null
			state = "wander"
			goal = global_position + Vector3(0, 3, 0)
		else:
			goal = _prey.hit_center()
			spd = def.run
			if global_position.distance_to(goal) < 0.5:
				_prey.carried_by = self
				state = "carry"
				_strike_t = _rng.randf_range(10.0, 16.0)
				var a := _rng.randf() * TAU
				_target = global_position + Vector3(cos(a), 0, sin(a)) * 60.0
				_altitude = _rng.randf_range(6.0, 9.0)
	elif state == "carry":
		# Flying off with it, then eating it somewhere else.
		_strike_t -= delta
		if _prey == null or not is_instance_valid(_prey) or _prey.dead or _prey.carried_by != self:
			_drop_prey()
			state = "wander"
			goal = global_position
		elif _strike_t <= 0.0:
			_prey.queue_free()
			_prey = null
			state = "wander"
			home = global_position
			_cd = 30.0
			goal = global_position
		else:
			# Climbs steeply off the ground first, then heads away.
			goal = Vector3(_target.x, ground + _altitude, _target.z)
			if position.y < ground + _altitude - 1.0:
				var flat := Vector3(goal.x - position.x, 0, goal.z - position.z).normalized()
				goal = Vector3(position.x + flat.x, ground + _altitude, position.z + flat.z)
			spd = def.speed * 1.5
	elif state == "chase" and player and not player.vitals.dead:
		goal = player.global_position + Vector3(0, 1.5, 0)
		spd = def.run
		if global_position.distance_to(goal) < def.reach:
			player.hurt(def.damage, global_position)
			_cd = def.cooldown
			state = "wander"
			_altitude = _rng.randf_range(4.0, 7.0)
		elif dist > def.sense * 2.0 or Game.nearest_fire(global_position, 8.0):
			state = "wander"
	else:
		var a := t * 0.6 + home.x
		goal = home + Vector3(cos(a) * 7.0, 0, sin(a * 1.3) * 7.0)
		goal.y = ground + _altitude + sin(t * 1.7) * 0.8
		if player and dist < def.sense and _cd <= 0.0 and _rng.randf() < delta * 0.25 and not Game.nearest_fire(player.global_position, 7.0):
			state = "chase"
		elif _cd <= 0.0 and _rng.randf() < delta * 0.2:
			_spot_lizard()
	var to := goal - global_position
	var dir := to.normalized()
	position += dir * minf(spd * delta, to.length())
	position.y = maxf(position.y, ground + (0.2 if state == "dive" else 0.6))
	heading = lerp_angle(heading, atan2(dir.x, dir.z), minf(delta * 5.0, 1.0))
	rotation.y = heading + PI
	if state == "carry":
		_prey.global_position = global_position + Vector3(0, -0.3, 0)
		_prey.rotation.y = rotation.y
	var w: Vector3 = world.wind if world else Vector3.ZERO
	if w != Vector3.ZERO:
		# Fighting a gale: pushed off course, and now and then it loses the fight.
		position += w * 0.35 * delta
		if w.length() > 8.0 and _rng.randf() < delta * 0.05 * w.length() / 12.0:
			blow_away(_rng.randf_range(3.0, 6.0))
	if dist < 70.0:
		_phase += delta * 38.0
		for i in _wings.size():
			_wings[i].rotation.z = sin(_phase + (i / 2) * 1.5) * 0.6 * (1.0 if i % 2 == 0 else -1.0)


func blow_away(secs: float) -> void:
	## Caught by a gust it can't fly against: it lets go of anything it carries.
	blown = secs
	_drop_prey()
	state = "wander"


func _blown_away(delta: float) -> void:
	blown -= delta
	var t := Time.get_ticks_msec() * 0.001
	var w: Vector3 = world.wind if world else Vector3.ZERO
	position += (w * 1.1 + Vector3(0, sin(t * 2.7 + home.x) * 2.5, 0)) * delta
	var ground := maxf(_ground(global_position.x, global_position.z), 0.0)
	position.y = clampf(position.y, ground + 1.0, ground + 18.0)
	heading += delta * 5.0
	rotation.y = heading + PI
	_body.rotation.z = sin(t * 7.0) * 1.1
	_phase += delta * 50.0
	for i in _wings.size():
		_wings[i].rotation.z = sin(_phase + i) * 0.9
	if blown <= 0.0:
		_body.rotation.z = 0.0
		home = global_position
		_altitude = _rng.randf_range(4.0, 7.0)


func _spot_lizard() -> void:
	## A Meganeura looks for small prey (any "prey" species) out in the open to snatch.
	for c in Game.creatures:
		if c != self and is_instance_valid(c) and c.def.behavior == "prey" and _small_prey_ok(c) and c._stun <= 0.0:
			var off: Vector3 = c.global_position - global_position
			if Vector2(off.x, off.z).length() < SNATCH_RANGE:
				_prey = c
				state = "dive"
				_strike_t = 5.0
				return


# --- Movement --------------------------------------------------------------------

func _ground(x: float, z: float) -> float:
	return world.ground_height(x, z) if world else 0.0


func _ok(habitat: String, h: float) -> bool:
	match habitat:
		"land":
			return h > -0.45
		"water":
			return h < -0.9
		"amphibious":
			return h < 1.3
	return true


func _face(p: Vector3, delta: float) -> void:
	var d := p - global_position
	heading = lerp_angle(heading, atan2(d.x, d.z), minf(delta * 8.0, 1.0))
	rotation.y = heading + PI


func _steer(goal: Vector3, spd: float, delta: float) -> void:
	if spd <= 0.0:
		return
	var d := goal - global_position
	d.y = 0.0
	if d.length() < 0.2:
		return
	heading = lerp_angle(heading, atan2(d.x, d.z), minf(delta * 4.0, 1.0))
	var fwd := Vector3(sin(heading), 0, cos(heading))
	var next := global_position + fwd * spd * delta
	var h := _ground(next.x, next.z)
	if mode != "land" and not _ok(def.habitat, h):
		# Blocked by shore or water: turn away and pick a new goal.
		heading += PI * 0.5 * (1.0 if _rng.randf() < 0.5 else -1.0)
		if state != "chase" and state != "charge" and state != "strike":
			_target = global_position + Vector3(sin(heading), 0, cos(heading)) * 8.0
		return
	if world:
		for t in world.trunks_near(next):
			var off := Vector2(next.x - t.x, next.z - t.y)
			var min_d: float = t.z + def.radius
			if off.length() < min_d and off.length() > 0.001:
				off = off.normalized() * min_d
				next.x = t.x + off.x
				next.z = t.y + off.y
	if def.habitat == "land":
		next.y = _ground(next.x, next.z)
	else:
		next.y = position.y
	position = next
	rotation.y = heading + PI


func _animate(spd: float, delta: float) -> void:
	_phase += delta * (4.0 + spd * 5.0) * (1.0 if spd > 0.0 else 0.15)
	for i in _legs.size():
		_legs[i].rotation.z = sin(_phase + i * 1.3) * 0.35 * minf(spd, 1.0)
		_legs[i].rotation.x = cos(_phase + i * 1.3) * 0.2 * minf(spd, 1.0)
	match species:
		"scorpion":
			var curl := 0.9 if state in ["chase", "attack"] else 0.55
			if state == "attack":
				curl = 1.1 - _windup
			for s in _segs:
				s.rotation.x = lerpf(s.rotation.x, -curl, minf(delta * 6.0, 1.0))
			for c in _tail:
				c.rotation.x = sin(_phase * 2.0) * 0.15
		"arthropleura":
			for i in _segs.size():
				_segs[i].position.x = sin(_phase * 0.6 - i * 0.7) * 0.05 * (0.3 + i * 0.15)
				_segs[i].rotation.y = cos(_phase * 0.6 - i * 0.7) * 0.04
		"eogyrinus", "uranocentrodon":
			# Segments are chained, so small per-joint bends make a body wave.
			for i in _segs.size():
				_segs[i].rotation.y = sin(_phase * 0.5 - i * 0.8) * (0.03 + 0.1 * minf(spd, 1.0)) * (0.5 + i * 0.12)


# --- Damage & carcass -----------------------------------------------------------

func take_damage(amount: float, attacker: Node3D) -> void:
	if dead:
		return
	hp -= amount
	_anger = 25.0
	var let_go := false
	if state == "raft_bite" and _raft and is_instance_valid(_raft):
		let_go = true
		_raft.bite_hit(self)  # struck in time: it lets go
	if hp <= 0.0:
		_die(attacker)
		return
	if let_go:
		return  # it sinks away rather than turning on you
	match def.behavior:
		"prey":
			state = "flee"
		"hunter", "defensive":
			_stop_feeding()
			state = "chase"
			_cd = minf(_cd, 0.4)
		"lurker":
			if state != "grab" and state != "retreat":
				state = "charge"
		"ambusher":
			if state in ["bask", "stalk", "hide", "return", "lunge", "pursue", "frenzy"] and attacker != null and attacker == Game.player:
				_provoked = 6.0
				_strike(null)
				_strike_t = 4.0
		"flyer":
			state = "wander"
			_altitude = 7.0
	if def.behavior != "prey":
		Sfx.play_at(def.get("sound", "hiss"), global_position, 0.0, 0.2)


func _die(killer: Node3D = null) -> void:
	dead = true
	state = "dead"
	died_at = Game.time
	cuts_left = def.drops.get(def.get("meat", "raw_meat"), 1)
	drawn = false
	if _victim and is_instance_valid(_victim):
		_victim.release_grab()
		_victim = null
	if def.behavior == "flyer":
		_drop_prey()
	_prey = null
	if carried_by:
		carried_by = null
		position.y = maxf(_ground(position.x, position.z), 0.0)
	for r in _ripples:
		r.visible = false
	if _body:
		_body.visible = true
	if _buzz:
		_buzz.stop()
	if def.habitat == "air":
		position.y = maxf(_ground(position.x, position.z), 0.0) + 0.05
	elif def.habitat == "amphibious":
		position.y = maxf(_ground(position.x, position.z), -0.3)
	elif def.habitat == "water" and world:
		# A fish: on the ground, or floating at the surface.
		position.y = maxf(_ground(position.x, position.z), world.water_level() - 0.05)
		_body.position = Vector3(0, def.radius * 0.6, 0)
		_body.rotation = Vector3.ZERO
		if hooked_by and is_instance_valid(hooked_by) and hooked_by.has_method("fish_died"):
			hooked_by.fish_died()
		hooked_by = null
	var flat: bool = species in ["arthropleura", "eogyrinus", "uranocentrodon"]
	_body.rotation.z = PI if flat else PI * 0.5
	if flat:
		_body.position.y = 0.75 if species == "uranocentrodon" else 0.6
	_carcass = StaticBody3D.new()
	_carcass.collision_layer = 2
	_carcass.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = maxf(def.hit_r, 0.5)
	cs.shape = sh
	cs.position.y = 0.2
	_carcass.add_child(cs)
	add_child(_carcass)
	if killer != null and killer == Game.player:
		Game.notify("You killed a %s." % def.name)


func expired() -> bool:
	## A carcass rots away a day after the kill.
	return dead and Game.time > died_at + Game.DAY_LENGTH


func carcass_dict() -> Dictionary:
	var p := global_position
	return {"species": species, "pos": [p.x, p.y, p.z], "heading": rotation.y, "stage": stage,
			"cuts": cuts_left, "gnawed": gnawed, "died": died_at}


func restore_carcass(d: Dictionary) -> void:
	## A saved carcass, lying where it was left (call once it is in the tree).
	_die(null)
	global_position = Vector3(d.pos[0], d.pos[1], d.pos[2])
	rotation.y = float(d.get("heading", 0.0))
	stage = String(d.get("stage", "whole"))
	cuts_left = int(d.get("cuts", cuts_left))
	gnawed = bool(d.get("gnawed", false))
	died_at = float(d.get("died", Game.time))
	set_hauled(null)
	_show_stage()


func set_stage(s: String) -> void:
	stage = s
	_show_stage()


func _show_stage() -> void:
	## A skinned carcass looks raw; one being cut up shrinks with the meat.
	if _body == null:
		return
	var full: float = maxf(def.drops.get(def.get("meat", "raw_meat"), 1), 1)
	_body.scale = Vector3.ONE * (lerpf(0.55, 1.0, cuts_left / full) if stage == "skinned" else 1.0)
	var tint: Variant = null
	if stage == "skinned":
		tint = Color(0.78, 0.38, 0.36)
	for n in _body.find_children("*", "MeshInstance3D", true, false):
		if tint == null:
			n.material_override = null
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = tint
			m.roughness = 0.6
			n.material_override = m


func haul_mode() -> String:
	## How the player moves this carcass: "carry", "drag", or "" (into the bag).
	match def.size:
		"medium":
			return "carry"
		"large":
			return "drag"
	return ""


func can_haul() -> bool:
	return dead


func haul_name() -> String:
	return "%s carcass" % def.name


func haul_radius() -> float:
	return def.radius


func haul_yaw() -> float:
	## Carried across your arms, head to one side.
	return PI * 0.5


func haul_lift() -> float:
	return 0.55


func set_hauled(by: Node3D) -> void:
	## Picked up (or put down, by = null) by the player.
	hauled_by = by
	if _carcass:
		_carcass.collision_layer = 0 if by else 2
	if by == null:
		var g: float = world.floor_height(global_position) if world and world.has_method("floor_height") else _ground(position.x, position.z)
		position.y = maxf(g, -0.3 if def.habitat == "amphibious" else 0.0)
		home = position


func _eater() -> Node3D:
	## The live scavenger eating this carcass, if any.
	if eaten_by != null and is_instance_valid(eaten_by) and not eaten_by.dead and eaten_by._prey == self:
		return eaten_by
	return null


func in_jaws() -> bool:
	## A carcass being taken off by the animal that killed it.
	return dead and carried_by != null and is_instance_valid(carried_by) and not carried_by.dead \
			and carried_by._prey == self


func prompt(_player: Node) -> String:
	if not dead:
		return ""
	if in_jaws():
		return "The %s has the %s" % [carried_by.def.name, def.name]
	var eater := _eater()
	if eater:
		return "Snatch the %s from the %s [E]   (it will attack)" % [def.name, eater.def.name]
	if gnawed and def.size == "small":
		return "Take the gnawed %s [E]" % def.name
	var what := "%s carcass" % def.name
	match haul_mode():
		"carry":
			return "Pick up the %s [E]   or kneel to butcher it [C]" % what
		"drag":
			return "Drag the %s [E]   or kneel to butcher it [C]" % what
	return "Pick up the %s [E]" % what


func interact(player: Node) -> void:
	if not dead or in_jaws():
		return
	var eater := _eater()
	if eater:
		eater.provoke()
		Game.notify("The %s turns on you!" % eater.def.name)
	if gnawed and def.size == "small":
		# Half eaten: only gnawed meat is left, and the eater wants it back.
		var n: int = maxi(1, def.drops.get("raw_meat", 1) / 2)
		var left: int = Game.inventory.add("gnawed_meat", n)
		if left > 0 and player.world and player.world.has_method("spawn_pickup"):
			player.world.spawn_pickup("gnawed_meat", left, global_position + Vector3(0, 0.5, 0))
		Game.picked.emit("gnawed_meat")
		Sfx.play("eat", -6.0)
		Game.notify("Took Gnawed Meat x%d." % n)
		queue_free()
		return
	if eater and def.size == "medium":
		# What it had eaten of the meat is gone.
		cuts_left = maxi(1, cuts_left / 2)
		_show_stage()
	if haul_mode() != "":
		player.start_haul(self)
		return
	take_small(player)


func take_small(player: Node) -> bool:
	## A small carcass goes into the bag whole.
	var id: String = def.carcass
	if Game.inventory.add(id, 1, Game.time - died_at) > 0:
		Game.notify("Too heavy to carry any more.")
		return false
	Sfx.play("pickup", -8.0)
	Game.picked.emit(id)
	Game.notify("Picked up a %s." % Items.item_name(id))
	queue_free()
	return true
