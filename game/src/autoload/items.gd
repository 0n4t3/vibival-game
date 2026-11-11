extends Node
## Item, recipe and knapping definitions.
##
## Item fields (all optional except name):
##   desc, stack, color, shape (icon/world mesh family), w (weight in kg),
##   energy / protein / greens / starch / water (restored when consumed),
##   sick (chance of sickness),
##   decay (seconds until it rots), cook (item it turns into on a fire),
##   cook_time, fuel (seconds of burn), damage, reach, tags (tool abilities),
##   place (placeable kind), knap (can be knapped), hold (fills with water),
##   empty (container left after drinking), treat (how it treats wounds:
##   clean washes them, alcohol cleans and fights infection, bandage and wax
##   cover one, see survival.gd),
##   tier (strike class for escaping jaws: stone or advanced; bare otherwise),
##   throw (can be thrown with use), spoil (what it turns into when its decay
##   runs out, "rotten" if not given), light (a held light source: range in m),
##   splat (thrown or dropped, it becomes a guts pile on land, or is gone in water),
##   pile (dropped on land, it goes on a ground stack of its kind, see stack.gd),
##   carry (too big for the bag: carried in your arms as a log, see wood_log.gd),
##   rack (a workbench tool: hangs on a workbench's tool rack, see workbench.gd),
##   build (not an item you carry: what its recipe builds where you made it),
##   as (counts as that item in recipes: a Calamites Board is a "board")
##
## An inventory slot can also carry `data`, a Dictionary that overrides the
## item's own fields for that one item (a Pot of Soup's serving, see
## soup_pot.gd). Such items never stack.

const ITEMS := {
	# --- Lab (tutorial) -----------------------------------------------------
	"beam_pipe": {"name": "Beam Pipe", "desc": "A polished steel vacuum tube.", "stack": 4, "w": 1.0,
		"color": Color(0.72, 0.74, 0.78), "shape": "pipe"},
	"magnet_coil": {"name": "Magnet Coil", "desc": "A copper-wound focusing magnet.", "stack": 8, "w": 0.8,
		"color": Color(0.80, 0.45, 0.20), "shape": "coil"},
	"control_board": {"name": "Control Board", "desc": "Timing electronics for the injector.", "stack": 2, "w": 0.3,
		"color": Color(0.15, 0.55, 0.25), "shape": "board"},
	"copper_wire": {"name": "Copper Wire", "desc": "A spool of insulated wire.", "stack": 4, "w": 0.5,
		"color": Color(0.85, 0.55, 0.25), "shape": "wire"},
	"power_cell": {"name": "Power Cell", "desc": "High-discharge capacitor bank.", "stack": 2, "w": 1.2,
		"color": Color(0.25, 0.45, 0.85), "shape": "cell"},
	"beam_segment": {"name": "Beam Segment", "desc": "Beam pipe with focusing magnets. Install it on the accelerator ring.", "stack": 2, "w": 2.6,
		"color": Color(0.78, 0.62, 0.45), "shape": "segment"},
	"injector": {"name": "Particle Injector", "desc": "Feeds particles into the ring. Install it at the injector port.", "stack": 1, "w": 2.0,
		"color": Color(0.35, 0.60, 0.90), "shape": "injector"},
	# The breakroom before the lab (lab.gd, breakroom.gd).
	"coffee_mug": {"name": "Coffee Mug", "desc": "A chipped breakroom mug. Hold it and look at the coffee pot to pour a coffee.", "stack": 1, "w": 0.3,
		"color": Color(0.86, 0.84, 0.78), "shape": "mug"},
	"mug_coffee": {"name": "Mug of Coffee", "desc": "Hot, black and a little burnt. Drink it with [Right-click].", "stack": 1, "w": 0.6,
		"color": Color(0.86, 0.84, 0.78), "shape": "mug_full", "water": 4.0, "energy": 2.0, "empty": "coffee_mug"},
	"papers": {"name": "Papers", "desc": "A messy stack of papers someone left on the breakroom table.", "stack": 1, "w": 0.4,
		"color": Color(0.93, 0.92, 0.88), "shape": "papers"},
	"keycard_jr": {"name": "Jimbob Goober Jr's Keycard", "desc": "A lab access card, crusted with dried mud. It opens the lab door.", "stack": 1, "w": 0.05,
		"color": Color(0.25, 0.45, 0.80), "shape": "keycard"},

	# --- Raw materials --------------------------------------------------------
	"stick": {"name": "Stick", "desc": "A dry branch from a horsetail tree. Burns well.", "stack": 20, "w": 0.4,
		"color": Color(0.55, 0.42, 0.26), "shape": "stick", "fuel": 160.0, "pile": true},
	"stone": {"name": "River Stone", "desc": "A smooth, heavy stone. Good for hammering.", "stack": 10, "w": 0.8,
		"color": Color(0.55, 0.55, 0.52), "shape": "rock", "damage": 4.0, "tier": "stone", "throw": true, "pile": true},
	"flint": {"name": "Chert Nodule", "desc": "Fine-grained stone that flakes to a sharp edge. Knap it into tool heads.", "stack": 10, "w": 0.5,
		"color": Color(0.30, 0.30, 0.34), "shape": "flint", "knap": true, "tier": "stone", "throw": true, "pile": true},
	"plant_fiber": {"name": "Plant Fiber", "desc": "Stringy fiber stripped from ferns.", "stack": 30, "w": 0.05,
		"color": Color(0.55, 0.65, 0.30), "shape": "fiber", "pile": true},
	"frond": {"name": "Tree Fern Frond", "desc": "A huge waxy frond.", "stack": 10, "w": 0.3,
		"color": Color(0.25, 0.55, 0.22), "shape": "frond", "fuel": 40.0, "pile": true},
	"tinder": {"name": "Bark Tinder", "desc": "Dry inner bark of a scale tree. Catches a spark easily in this oxygen-rich air.", "stack": 10, "w": 0.1,
		"color": Color(0.70, 0.58, 0.38), "shape": "tinder", "fuel": 32.0, "pile": true},
	"clay": {"name": "Wet Clay", "desc": "Sticky grey clay from the banks.", "stack": 20, "w": 0.5,
		"color": Color(0.48, 0.46, 0.42), "shape": "clay", "pile": true},
	"wax": {"name": "Waxy Residue", "desc": "Wax crushed out of tree fern fronds. Roll a stick in it to make a torch, or seal a clean wound that has stopped bleeding with it (Treat): it keeps water out better than a bandage.", "stack": 20, "w": 0.05,
		"color": Color(0.78, 0.74, 0.42), "shape": "wax", "pile": true, "treat": "wax"},
	"ash": {"name": "Ash", "desc": "Fine grey wood ash, scooped from a campfire.", "stack": 30, "w": 0.05,
		"color": Color(0.56, 0.55, 0.52), "shape": "ash", "pile": true},
	"charred_stick": {"name": "Charred Stick", "desc": "What is left of a torch. Burns a little, or roll it in wax again.", "stack": 20, "w": 0.25,
		"color": Color(0.16, 0.13, 0.11), "shape": "stick", "fuel": 80.0, "pile": true},
	"salt": {"name": "Salt Crust", "desc": "A crust of salt left where swamp water dried on the bank. Not much use yet.", "stack": 20, "w": 0.1,
		"color": Color(0.90, 0.89, 0.84), "shape": "salt", "pile": true},
	"chitin": {"name": "Chitin Plate", "desc": "A tough plate of arthropod shell.", "stack": 10, "w": 0.4,
		"color": Color(0.35, 0.22, 0.15), "shape": "chitin", "pile": true},

	# Wood. Logs and short logs are carried in your arms, never in the bag.
	"log": {"name": "Log", "desc": "A 2 m length of trunk, still in its bark. Carry it in your arms (E). Kneel at it (C) with an axe to strip the bark or cut it into short logs.", "stack": 1, "w": 0.0,
		"color": Color(0.36, 0.30, 0.20), "shape": "log", "carry": true, "pile": true},
	"log_stripped": {"name": "Stripped Log", "desc": "A 2 m log with the bark off. Kneel at it (C) with an axe to hew it into boards or cut it into short logs.", "stack": 1, "w": 0.0,
		"color": Color(0.70, 0.58, 0.40), "shape": "log", "carry": true, "pile": true},
	"short_log": {"name": "Short Log", "desc": "A half-metre round of trunk. Kneel at it (C) with an axe to split it into firewood.", "stack": 1, "w": 0.0,
		"color": Color(0.62, 0.50, 0.34), "shape": "short_log", "carry": true, "pile": true},
	"firewood": {"name": "Firewood", "desc": "A split piece of log. Burns long and hot.", "stack": 12, "w": 0.8,
		"color": Color(0.66, 0.52, 0.34), "shape": "firewood", "fuel": 420.0, "pile": true},
	"bark": {"name": "Bark", "desc": "A strip of bark peeled off a log. Burns quickly.", "stack": 20, "w": 0.2,
		"color": Color(0.34, 0.28, 0.18), "shape": "bark", "fuel": 60.0, "pile": true},
	"branch": {"name": "Branch", "desc": "A side branch cut off a log. Snap it into sticks.", "stack": 10, "w": 0.6,
		"color": Color(0.46, 0.40, 0.24), "shape": "branch", "fuel": 220.0, "pile": true},
	"board": {"name": "Board", "desc": "A rough plank hewn from a stripped log. Four of them, with sticks and cordage, make a workbench.", "stack": 10, "w": 1.5,
		"color": Color(0.74, 0.60, 0.40), "shape": "plank", "fuel": 400.0, "pile": true},
	# Boards hewn from each tree, in the colour of its wood. Any of them is a
	# "board" to a recipe (`as`); a plain Board is from an old save.
	"board_lepidodendron": {"name": "Lepidodendron Board", "desc": "A rough plank of pale, close-grained scale tree wood.", "stack": 10, "w": 1.5,
		"color": Color(0.70, 0.60, 0.42), "shape": "plank", "fuel": 400.0, "pile": true, "as": "board"},
	"board_sigillaria": {"name": "Sigillaria Board", "desc": "A rough plank of tawny seal tree wood.", "stack": 10, "w": 1.5,
		"color": Color(0.62, 0.48, 0.30), "shape": "plank", "fuel": 400.0, "pile": true, "as": "board"},
	"board_calamites": {"name": "Calamites Board", "desc": "A rough plank of light, greenish horsetail wood.", "stack": 10, "w": 1.5,
		"color": Color(0.72, 0.70, 0.48), "shape": "plank", "fuel": 400.0, "pile": true, "as": "board"},
	"board_tree_fern": {"name": "Tree Fern Board", "desc": "A rough plank of dark, fibrous tree fern stem.", "stack": 10, "w": 1.5,
		"color": Color(0.46, 0.32, 0.20), "shape": "plank", "fuel": 400.0, "pile": true, "as": "board"},

	# --- Food -----------------------------------------------------------------
	# Planting (plot.gd): set in a hole, an item with `plant` grows into that
	# plant (a Harvestable kind), one with `plant_tree` into that tree.
	# Dug up with a seed fern (a mattock, harvestable.gd).
	"fern_root": {"name": "Seed Fern Root", "desc": "A knobbly root dug up with a seed fern. Edible raw: some greens, hardly any food. Set it in a hole to grow a seed fern.", "stack": 20, "w": 0.08,
		"color": Color(0.52, 0.40, 0.26), "shape": "root", "energy": 0.5, "greens": 8.0, "decay": 4320.0, "plant": "seed_fern"},
	"fern_spores": {"name": "Fern Spores", "desc": "A pinch of rusty spores shaken from the fronds of a fern dug up with a mattock. Set them in a hole to grow a fern.", "stack": 20, "w": 0.01,
		"color": Color(0.55, 0.36, 0.20), "shape": "seed", "plant": "fern"},
	"seed": {"name": "Seed Fern Seed", "desc": "A big oily seed from a Medullosa. Better roasted, or set it in a hole to grow a seed fern.", "stack": 20, "w": 0.05,
		"color": Color(0.62, 0.50, 0.28), "shape": "seed", "energy": 6.0, "starch": 10.0, "decay": 1800.0,
		"cook": "roast_seed", "cook_time": 24.0, "plant": "seed_fern"},
	# Dug out with a stump (stump.gd). Too woody to eat.
	"lepidodendron_root": {"name": "Lepidodendron Root", "desc": "A forked, scarred root dug out with a scale tree's stump. Set it in a hole to grow a new Lepidodendron.", "stack": 10, "w": 0.4,
		"color": Color(0.46, 0.40, 0.30), "shape": "root", "plant_tree": "lepidodendron"},
	"sigillaria_root": {"name": "Sigillaria Root", "desc": "A stout root dug out with a seal tree's stump. Set it in a hole to grow a new Sigillaria.", "stack": 10, "w": 0.4,
		"color": Color(0.50, 0.38, 0.24), "shape": "root", "plant_tree": "sigillaria"},
	"calamites_root": {"name": "Calamites Root", "desc": "A jointed runner dug out with a horsetail's stump. Set it in a hole to grow a new Calamites.", "stack": 10, "w": 0.3,
		"color": Color(0.58, 0.54, 0.36), "shape": "root", "plant_tree": "calamites"},
	"tree_fern_root": {"name": "Tree Fern Root", "desc": "A dark, matted root ball dug out with a tree fern's stump. Set it in a hole to grow a new tree fern.", "stack": 10, "w": 0.4,
		"color": Color(0.32, 0.22, 0.14), "shape": "root", "plant_tree": "tree_fern"},
	# Picked from a young plant (stump.gd, plot.gd), which then grows again
	# from its roots.
	"calamites_shoot": {"name": "Calamites Shoot", "desc": "A tender, jointed horsetail shoot. Crisp and green.", "stack": 20, "w": 0.05,
		"color": Color(0.50, 0.66, 0.32), "shape": "shoot", "energy": 2.0, "greens": 10.0, "water": 1.0, "decay": 900.0},
	"tree_fern_shoot": {"name": "Tree Fern Shoot", "desc": "The curled heart of a young tree fern. Green and a little slimy.", "stack": 20, "w": 0.05,
		"color": Color(0.46, 0.58, 0.26), "shape": "sprout", "energy": 2.0, "greens": 10.0, "water": 1.0, "decay": 900.0},
	"seed_fern_shoot": {"name": "Seed Fern Shoot", "desc": "A young seed fern's first fronds, still curled. Green and tender.", "stack": 20, "w": 0.05,
		"color": Color(0.38, 0.60, 0.30), "shape": "sprout", "energy": 2.0, "greens": 10.0, "water": 1.0, "decay": 900.0},
	"roast_seed": {"name": "Roasted Seed", "desc": "Nutty and filling.", "stack": 20, "w": 0.04,
		"color": Color(0.45, 0.30, 0.15), "shape": "seed", "energy": 12.0, "starch": 16.0, "decay": 2400.0},
	"fiddlehead": {"name": "Fiddlehead", "desc": "A curled young fern shoot. Bitter raw.", "stack": 20, "w": 0.05,
		"color": Color(0.40, 0.65, 0.25), "shape": "sprout", "energy": 3.0, "greens": 10.0, "water": 2.0, "sick": 0.1,
		"decay": 900.0, "cook": "cooked_fiddlehead", "cook_time": 20.0},
	"cooked_fiddlehead": {"name": "Cooked Fiddlehead", "desc": "Tender and safe.", "stack": 20, "w": 0.05,
		"color": Color(0.30, 0.45, 0.18), "shape": "sprout", "energy": 6.0, "greens": 15.0, "decay": 1200.0},
	"grub": {"name": "Beetle Grub", "desc": "A fat larva from rotting wood. Protein is protein.", "stack": 20, "w": 0.03,
		"color": Color(0.90, 0.85, 0.65), "shape": "grub", "energy": 5.0, "protein": 9.0, "water": 1.0, "decay": 600.0,
		"cook": "roast_grub", "cook_time": 16.0, "tags": ["bait"]},
	"roast_grub": {"name": "Roasted Grub", "desc": "Crunchy.", "stack": 20, "w": 0.03,
		"color": Color(0.70, 0.50, 0.25), "shape": "grub", "energy": 9.0, "protein": 13.0, "decay": 1500.0},
	"raw_meat": {"name": "Raw Meat", "desc": "Pale, fishy flesh. Cook it before eating.", "stack": 10, "w": 0.5,
		"color": Color(0.80, 0.40, 0.38), "shape": "meat", "energy": 8.0, "protein": 14.0, "sick": 0.5, "decay": 900.0,
		"cook": "cooked_meat", "cook_time": 40.0, "as": "any_raw_meat"},
	"cooked_meat": {"name": "Cooked Meat", "desc": "Hot and filling.", "stack": 10, "w": 0.4,
		"color": Color(0.55, 0.30, 0.18), "shape": "meat", "energy": 24.0, "protein": 26.0, "decay": 2400.0},
	"gnawed_meat": {"name": "Gnawed Meat", "desc": "Scraps torn from a half-eaten kill. Cook them.", "stack": 10, "w": 0.2,
		"color": Color(0.70, 0.36, 0.34), "shape": "scraps", "energy": 3.0, "protein": 5.0, "sick": 0.5, "decay": 600.0,
		"cook": "cooked_scraps", "cook_time": 24.0},
	# Bait (`tags` "bait"): meat bait, grubs, rotten food and guts. Meat bait is
	# raw meat (later fish too) torn up by hand. Fishing itself is still to come.
	"meat_bait": {"name": "Meat Bait", "desc": "Raw meat torn into small pieces, for baiting a hook. It goes off like raw meat (rotten food is bait too).", "stack": 20, "w": 0.1,
		"color": Color(0.84, 0.46, 0.46), "shape": "scraps", "decay": 900.0, "tags": ["bait"]},
	# Fish (creature.gd's fish species). A small one goes in the bag whole and
	# roasts as it is; a big one is carried and cut into fish meat.
	# `as` small_fish: any small fish will do where a recipe asks for one
	# (tearing it up for bait). "small_fish" itself is never found.
	"small_fish": {"name": "Small Fish", "desc": "Any small fish.", "stack": 5, "w": 0.3,
		"color": Color(0.55, 0.58, 0.52), "shape": "fish"},
	"elonichthys_carcass": {"name": "Elonichthys", "desc": "A small, bony ray-finned fish. Roast it whole, or tear it up for bait.", "stack": 5, "w": 0.3,
		"color": Color(0.55, 0.58, 0.52), "shape": "fish", "energy": 6.0, "protein": 10.0, "sick": 0.3, "decay": 900.0,
		"cook": "roast_elonichthys", "cook_time": 30.0, "as": "small_fish"},
	"haplolepis_carcass": {"name": "Haplolepis", "desc": "A tiny silvery fish, hardly a mouthful. Roast it whole, or tear it up for bait.", "stack": 10, "w": 0.12,
		"color": Color(0.62, 0.64, 0.56), "shape": "fish", "energy": 3.0, "protein": 6.0, "sick": 0.3, "decay": 900.0,
		"cook": "roast_haplolepis", "cook_time": 20.0, "as": "small_fish"},
	"roast_haplolepis": {"name": "Roast Haplolepis", "desc": "Crunchy, bones and all.", "stack": 10, "w": 0.1,
		"color": Color(0.64, 0.48, 0.27), "shape": "fish", "energy": 9.0, "protein": 11.0, "decay": 2400.0},
	"amphicentrum_carcass": {"name": "Amphicentrum", "desc": "A deep-bodied, almost round fish with crushing teeth. Roast it whole, or tear it up for bait.", "stack": 5, "w": 0.3,
		"color": Color(0.52, 0.46, 0.34), "shape": "fish", "energy": 5.0, "protein": 9.0, "sick": 0.3, "decay": 900.0,
		"cook": "roast_amphicentrum", "cook_time": 30.0, "as": "small_fish"},
	"roast_amphicentrum": {"name": "Roast Amphicentrum", "desc": "More meat on it than it looks.", "stack": 5, "w": 0.25,
		"color": Color(0.62, 0.45, 0.25), "shape": "fish", "energy": 14.0, "protein": 16.0, "decay": 2400.0},
	"acanthodes_carcass": {"name": "Acanthodes", "desc": "A slim 'spiny shark' with a stiff spine before every fin. Roast it whole, or tear it up for bait.", "stack": 5, "w": 0.3,
		"color": Color(0.46, 0.50, 0.55), "shape": "fish", "energy": 5.0, "protein": 9.0, "sick": 0.3, "decay": 900.0,
		"cook": "roast_acanthodes", "cook_time": 30.0, "as": "small_fish"},
	"roast_acanthodes": {"name": "Roast Acanthodes", "desc": "Mind the spines.", "stack": 5, "w": 0.25,
		"color": Color(0.62, 0.45, 0.25), "shape": "fish", "energy": 14.0, "protein": 16.0, "decay": 2400.0},
	"bandringa_carcass": {"name": "Bandringa", "desc": "A small shark with a long, flat, paddle-like snout. Roast it whole, or tear it up for bait.", "stack": 5, "w": 0.4,
		"color": Color(0.40, 0.38, 0.33), "shape": "fish", "energy": 7.0, "protein": 12.0, "sick": 0.3, "decay": 900.0,
		"cook": "roast_bandringa", "cook_time": 34.0, "as": "small_fish"},
	"roast_bandringa": {"name": "Roast Bandringa", "desc": "Firm, rich shark meat.", "stack": 5, "w": 0.35,
		"color": Color(0.60, 0.44, 0.25), "shape": "fish", "energy": 18.0, "protein": 20.0, "decay": 2400.0},
	"roast_elonichthys": {"name": "Roast Elonichthys", "desc": "Crisp skin, flaky flesh, mind the bones.", "stack": 5, "w": 0.25,
		"color": Color(0.62, 0.45, 0.25), "shape": "fish", "energy": 16.0, "protein": 18.0, "decay": 2400.0},
	"fish_meat": {"name": "Fish Meat", "desc": "A slab of raw fish. Cook it, or tear it up for bait.", "stack": 10, "w": 0.4,
		"color": Color(0.88, 0.62, 0.56), "shape": "meat", "energy": 7.0, "protein": 13.0, "sick": 0.3, "decay": 900.0,
		"cook": "cooked_fish", "cook_time": 32.0, "as": "any_raw_meat"},
	"cooked_fish": {"name": "Cooked Fish", "desc": "White, flaky and filling.", "stack": 10, "w": 0.35,
		"color": Color(0.85, 0.72, 0.52), "shape": "meat", "energy": 20.0, "protein": 22.0, "decay": 2400.0},
	"cooked_scraps": {"name": "Cooked Scraps", "desc": "Not much, but it's hot.", "stack": 10, "w": 0.15,
		"color": Color(0.50, 0.28, 0.17), "shape": "scraps", "energy": 8.0, "protein": 9.0, "decay": 1800.0},
	# Small kills go into the bag whole. A lizard is gutted and skinned by hand
	# before it is roasted; a dragonfly roasts as it is.
	"lizard_carcass": {"name": "Hylonomus Carcass", "desc": "A dead lizard. Gut and skin it by hand (lay it out with C) before you roast it.", "stack": 5, "w": 0.4,
		"color": Color(0.42, 0.40, 0.24), "shape": "lizard", "decay": 900.0},
	"lizard_dressed": {"name": "Dressed Hylonomus", "desc": "Gutted and skinned. Roast it on a fire.", "stack": 5, "w": 0.3,
		"color": Color(0.80, 0.48, 0.44), "shape": "lizard", "energy": 7.0, "protein": 13.0, "sick": 0.5, "decay": 900.0,
		"cook": "roast_lizard", "cook_time": 36.0},
	"roast_lizard": {"name": "Roast Hylonomus", "desc": "Crisp skinless lizard on the bone.", "stack": 5, "w": 0.25,
		"color": Color(0.55, 0.32, 0.17), "shape": "lizard", "energy": 20.0, "protein": 24.0, "decay": 2400.0},
	# The other small prey go the same way as a Hylonomus: gutted and skinned
	# by hand (a "dress" recipe), then roasted whole. `animal` picks their
	# shape (Assets.small_prey) and `body_scale` sizes it.
	"petrolacosaurus_carcass": {"name": "Petrolacosaurus Carcass", "desc": "A dead long-tailed reptile. Gut and skin it by hand (lay it out with C) before you roast it.", "stack": 5, "w": 0.35,
		"color": Color(0.50, 0.42, 0.27), "shape": "lizard", "animal": "petrolacosaurus", "body_scale": 1.05, "decay": 900.0},
	"petrolacosaurus_dressed": {"name": "Dressed Petrolacosaurus", "desc": "Gutted and skinned. Roast it on a fire.", "stack": 5, "w": 0.25,
		"color": Color(0.80, 0.50, 0.45), "shape": "lizard", "animal": "petrolacosaurus", "body_scale": 1.05, "energy": 6.0, "protein": 12.0, "sick": 0.5, "decay": 900.0,
		"cook": "roast_petrolacosaurus", "cook_time": 32.0},
	"roast_petrolacosaurus": {"name": "Roast Petrolacosaurus", "desc": "Lean and stringy, mostly tail.", "stack": 5, "w": 0.2,
		"color": Color(0.56, 0.33, 0.18), "shape": "lizard", "animal": "petrolacosaurus", "body_scale": 1.05, "energy": 18.0, "protein": 22.0, "decay": 2400.0},
	"archaeothyris_carcass": {"name": "Archaeothyris Carcass", "desc": "A dead heavy-headed reptile, a good meal. Gut and skin it by hand (lay it out with C) before you roast it.", "stack": 5, "w": 0.8,
		"color": Color(0.36, 0.29, 0.23), "shape": "lizard", "animal": "archaeothyris", "body_scale": 1.4, "decay": 900.0},
	"archaeothyris_dressed": {"name": "Dressed Archaeothyris", "desc": "Gutted and skinned. Roast it on a fire.", "stack": 5, "w": 0.6,
		"color": Color(0.78, 0.46, 0.42), "shape": "lizard", "animal": "archaeothyris", "body_scale": 1.4, "energy": 12.0, "protein": 22.0, "sick": 0.5, "decay": 900.0,
		"cook": "roast_archaeothyris", "cook_time": 48.0},
	"roast_archaeothyris": {"name": "Roast Archaeothyris", "desc": "Rich, dark meat on a thick-boned frame.", "stack": 5, "w": 0.5,
		"color": Color(0.50, 0.29, 0.15), "shape": "lizard", "animal": "archaeothyris", "body_scale": 1.4, "energy": 32.0, "protein": 40.0, "decay": 2400.0},
	"amphibamus_carcass": {"name": "Amphibamus Carcass", "desc": "A dead little amphibian from the water's edge. Gut and skin it by hand (lay it out with C) before you roast it.", "stack": 5, "w": 0.2,
		"color": Color(0.30, 0.36, 0.22), "shape": "lizard", "animal": "amphibamus", "body_scale": 0.7, "decay": 900.0},
	"amphibamus_dressed": {"name": "Dressed Amphibamus", "desc": "Gutted and skinned. Roast it on a fire.", "stack": 5, "w": 0.15,
		"color": Color(0.84, 0.58, 0.52), "shape": "lizard", "animal": "amphibamus", "body_scale": 0.7, "energy": 4.0, "protein": 8.0, "sick": 0.5, "decay": 900.0,
		"cook": "roast_amphibamus", "cook_time": 24.0},
	"roast_amphibamus": {"name": "Roast Amphibamus", "desc": "A mouthful of soft white meat, like frog.", "stack": 5, "w": 0.12,
		"color": Color(0.60, 0.40, 0.22), "shape": "lizard", "animal": "amphibamus", "body_scale": 0.7, "energy": 12.0, "protein": 15.0, "decay": 2400.0},
	"tuditanus_carcass": {"name": "Tuditanus Carcass", "desc": "A dead stubby night-crawler. Gut and skin it by hand (lay it out with C) before you roast it.", "stack": 5, "w": 0.35,
		"color": Color(0.42, 0.31, 0.29), "shape": "lizard", "animal": "tuditanus", "body_scale": 0.9, "decay": 900.0},
	"tuditanus_dressed": {"name": "Dressed Tuditanus", "desc": "Gutted and skinned. Roast it on a fire.", "stack": 5, "w": 0.25,
		"color": Color(0.80, 0.47, 0.44), "shape": "lizard", "animal": "tuditanus", "body_scale": 0.9, "energy": 6.0, "protein": 11.0, "sick": 0.5, "decay": 900.0,
		"cook": "roast_tuditanus", "cook_time": 32.0},
	"roast_tuditanus": {"name": "Roast Tuditanus", "desc": "Small, but tender.", "stack": 5, "w": 0.2,
		"color": Color(0.54, 0.31, 0.17), "shape": "lizard", "animal": "tuditanus", "body_scale": 0.9, "energy": 17.0, "protein": 21.0, "decay": 2400.0},
	"morganucodon_carcass": {"name": "Morganucodon Carcass", "desc": "A dead little furry creature, like a shrew. Gut and skin it by hand (lay it out with C) before you roast it.", "stack": 5, "w": 0.12,
		"color": Color(0.40, 0.34, 0.28), "shape": "lizard", "animal": "morganucodon", "body_scale": 0.55, "decay": 900.0},
	"morganucodon_dressed": {"name": "Dressed Morganucodon", "desc": "Gutted and skinned. Roast it on a fire.", "stack": 5, "w": 0.08,
		"color": Color(0.82, 0.52, 0.48), "shape": "lizard", "animal": "morganucodon", "body_scale": 0.55, "energy": 3.0, "protein": 6.0, "sick": 0.5, "decay": 900.0,
		"cook": "roast_morganucodon", "cook_time": 20.0},
	"roast_morganucodon": {"name": "Roast Morganucodon", "desc": "Hardly a mouthful, but rich.", "stack": 5, "w": 0.06,
		"color": Color(0.55, 0.33, 0.18), "shape": "lizard", "animal": "morganucodon", "body_scale": 0.55, "energy": 9.0, "protein": 11.0, "decay": 2400.0},
	"dragonfly_carcass": {"name": "Meganeura Carcass", "desc": "A dead giant dragonfly. Roast it whole on a fire.", "stack": 5, "w": 0.2,
		"color": Color(0.24, 0.34, 0.30), "shape": "dragonfly", "energy": 3.0, "protein": 7.0, "sick": 0.4, "decay": 900.0,
		"cook": "roast_dragonfly", "cook_time": 24.0},
	"roast_dragonfly": {"name": "Roast Meganeura", "desc": "Crunchy, a little like a prawn.", "stack": 5, "w": 0.15,
		"color": Color(0.52, 0.30, 0.16), "shape": "dragonfly", "energy": 12.0, "protein": 18.0, "decay": 2400.0},
	# `as` any_raw_meat: a piece of raw meat or of raw fish will do where a
	# recipe asks for either (a baitbox). "any_raw_meat" itself is never found.
	"any_raw_meat": {"name": "Raw Meat or Fish", "desc": "A piece of raw meat or raw fish.", "stack": 10, "w": 0.5,
		"color": Color(0.80, 0.40, 0.38), "shape": "meat"},
	# Thrown into the water, a baitbox sends every Uranocentrodon and Eogyrinus
	# within Creature.FRENZY_RADIUS into a feeding frenzy round it for `frenzy`
	# seconds (swamp.start_frenzy). On land it is just dropped.
	"baitbox": {"name": "Baitbox", "desc": "A little wooden cage of board strips packed with raw meat. Throw it (Use) into the water and every big amphibian for a long way round rushes to it and tears at it for half a minute, ignoring you unless you come too close. It goes off like raw meat.", "stack": 3, "w": 1.6,
		"color": Color(0.62, 0.48, 0.30), "shape": "baitbox", "throw": true, "frenzy": 30.0, "decay": 900.0, "spoil": "baitbox_rotten"},
	"baitbox_rotten": {"name": "Rotten Baitbox", "desc": "A baitbox whose meat has gone off. Thrown into the water it still draws the big amphibians, but they lose interest in half the time.", "stack": 3, "w": 1.5,
		"color": Color(0.45, 0.40, 0.28), "shape": "baitbox", "throw": true, "frenzy": 15.0},
	"guts": {"name": "Guts", "desc": "A slippery handful of offal. Scavengers smell it from far off. Throw it (Use) to lay a lure on land, or into the water to draw what lives there.", "stack": 10, "w": 0.4,
		"color": Color(0.62, 0.30, 0.36), "shape": "guts", "decay": 900.0, "throw": true, "splat": true, "tags": ["bait"]},
	"charred": {"name": "Charred Remains", "desc": "Left on the fire far too long.", "stack": 20, "w": 0.1,
		"color": Color(0.10, 0.09, 0.08), "shape": "blob", "energy": 1.0, "fuel": 20.0},
	"rotten": {"name": "Rotten Food", "desc": "It was food once. Still good as bait.", "stack": 20, "w": 0.2,
		"color": Color(0.30, 0.32, 0.18), "shape": "blob", "energy": 2.0, "sick": 0.9, "tags": ["bait"]},

	# --- Crafted --------------------------------------------------------------
	"flint_blade": {"name": "Chert Blade", "desc": "A sharp flake. Butchers carcasses fully and cuts fiber.", "stack": 1, "w": 0.2,
		"color": Color(0.32, 0.32, 0.38), "shape": "blade", "damage": 7.0, "tier": "stone", "reach": 2.2, "tags": ["cut"]},
	"axe_head": {"name": "Axe Head", "desc": "Knapped chert head. Haft it to make an axe.", "stack": 4, "w": 0.6,
		"color": Color(0.32, 0.32, 0.38), "shape": "axe_head"},
	"spear_head": {"name": "Spear Point", "desc": "A long knapped point. Haft it to make a spear.", "stack": 4, "w": 0.3,
		"color": Color(0.32, 0.32, 0.38), "shape": "spear_head"},
	"mattock_head": {"name": "Mattock Head", "desc": "A heavy knapped chert blade. Haft it crosswise to make a mattock.", "stack": 4, "w": 0.6,
		"color": Color(0.32, 0.32, 0.38), "shape": "mattock_head"},
	"cordage": {"name": "Cordage", "desc": "Twisted plant fiber.", "stack": 10, "w": 0.1,
		"color": Color(0.65, 0.60, 0.35), "shape": "cord", "pile": true},
	# Spun on a spindle at a workbench (the spindle on its rack or in your bag).
	"string": {"name": "String", "desc": "Fine, strong thread spun from plant fiber on a spindle: better than cordage, and what a bow drill needs.", "stack": 10, "w": 0.05,
		"color": Color(0.86, 0.80, 0.60), "shape": "cord", "pile": true},
	"stone_axe": {"name": "Stone Axe", "desc": "Heavy chopping tool and weapon.", "stack": 1, "w": 1.4,
		"color": Color(0.50, 0.40, 0.28), "shape": "axe", "damage": 12.0, "tier": "stone", "reach": 2.4, "tags": ["cut", "chop"], "breaks": "stick"},
	"spear": {"name": "Chert Spear", "desc": "Long reach keeps teeth and claws at a distance.", "stack": 1, "w": 1.6,
		"color": Color(0.55, 0.45, 0.30), "shape": "spear", "damage": 16.0, "tier": "stone", "reach": 3.4, "breaks": "stick"},
	"mattock": {"name": "Stone Mattock", "desc": "A digging tool. Use it on open ground to dig a hole for planting. Swing it at a campfire to knock it apart, a stump or seed fern to dig it up, or press E at a fire to scoop out the ash.", "stack": 1, "w": 1.5,
		"color": Color(0.50, 0.40, 0.28), "shape": "mattock", "damage": 9.0, "tier": "stone", "reach": 2.3, "tags": ["dig"], "breaks": "stick"},
	"torch": {"name": "Torch", "desc": "A stick coated in fern wax. Light it at a campfire (E).", "stack": 5, "w": 0.45,
		"color": Color(0.62, 0.50, 0.30), "shape": "torch"},
	"torch_lit": {"name": "Lit Torch", "desc": "Lights the way while you hold it, and can light a campfire. Burns for about 14 minutes, twice as fast in rain.", "stack": 1, "w": 0.45,
		"color": Color(1.0, 0.6, 0.2), "shape": "torch_lit", "decay": 840.0, "spoil": "charred_stick", "light": 9.0, "tags": ["fire"]},
	# A live coal taken from a fire's glowing coals or a burning stump. It goes
	# out (`spoil` "": nothing is left) after `decay` seconds, three game hours,
	# in the bag, a stash or on the ground (`goes_out`, see pickup.gd). Set in an
	# unlit campfire with fuel and blown on, it lights it (campfire.gd).
	"ember": {"name": "Ember", "desc": "A glowing coal from a fire. It goes out in about three hours, wherever it is. Set it in an unlit campfire that has fuel, then blow on it to bring it to flame.", "stack": 1, "w": 0.05,
		"color": Color(1.0, 0.42, 0.12), "shape": "ember", "decay": 180.0, "spoil": "", "goes_out": true},
	"bow_drill": {"name": "Bow Drill", "desc": "Lights campfires. Keep it in your inventory.", "stack": 1, "w": 0.6,
		"color": Color(0.60, 0.48, 0.30), "shape": "drill", "tags": ["fire"]},
	# Farming (compost.gd, plot.gd): a basket filled to level 20 composts for
	# 5 days (twice as long with sticks or branches in it, three times with a
	# log), then gives 5 compost. `compost` in an item: what it adds to the level.
	"compost_basket": {"name": "Compost Basket", "desc": "A slatted crate for rotting scraps down into compost. Set it down with Use, then fill it (E) with food, sticks, branches, guts or a carried log.", "stack": 1, "w": 6.0,
		"color": Color(0.62, 0.48, 0.30), "shape": "basket", "place": "compost"},
	"compost": {"name": "Compost", "desc": "Dark, rich, rotted-down earth. Set it in a hole with a seed or root to grow it in half the time, for twice the yield; or hold it and right-click a growing plant to speed it on.", "stack": 20, "w": 0.5,
		"color": Color(0.22, 0.15, 0.09), "shape": "compost"},
	"campfire_kit": {"name": "Campfire", "desc": "Place it with Use. Light it with an ember (or a bow drill, or a lit torch). Predators fear fire.", "stack": 2, "w": 3.5,
		"color": Color(0.85, 0.45, 0.15), "shape": "fire", "place": "campfire"},
	"clay_pot": {"name": "Unfired Pot", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 2.5,
		"color": Color(0.58, 0.56, 0.52), "shape": "pot", "cook": "pot", "cook_time": 100.0},
	"pot": {"name": "Clay Pot", "desc": "Use at water to fill it.", "stack": 1, "w": 1.5,
		"color": Color(0.70, 0.42, 0.28), "shape": "pot", "hold": "pot_dirty"},
	"pot_dirty": {"name": "Pot of Swamp Water", "desc": "Murky. Boil it on a fire, or risk drinking it.", "stack": 1, "w": 3.0,
		"color": Color(0.40, 0.42, 0.25), "shape": "pot_water", "water": 35.0, "sick": 0.35,
		"cook": "pot_clean", "cook_time": 48.0, "empty": "pot"},
	"pot_clean": {"name": "Pot of Boiled Water", "desc": "Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 3.0,
		"color": Color(0.45, 0.65, 0.80), "shape": "pot_water", "water": 40.0, "empty": "pot", "treat": "clean", "as": "pot_dirty"},
	# Preserving pots (see core/preserves.gd): a clay pot filled at a
	# fermentation vessel with 1-4 preserved items and a serving of its liquid,
	# the lot in the slot's data (and its weight, `w`). Sealed with a wooden
	# cap and wax, nothing in it ages, and it no longer shows what it holds.
	"pot_preserves": {"name": "Pot of Preserves", "desc": "An open clay pot of preserved food in its liquid.", "stack": 1, "w": 3.0,
		"color": Color(0.72, 0.70, 0.48), "shape": "pot_water", "preserves": true},
	"pot_sealed": {"name": "Sealed Pot", "desc": "A clay pot with a wooden cap waxed down over its mouth. You can't see what is inside. Nothing in it spoils while it stays sealed. Open it (Use) to take everything out: the cap comes back, the wax doesn't.", "stack": 1, "w": 3.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "pot_capped", "preserves": true},
	"wooden_cap": {"name": "Wooden Cap", "desc": "A round wooden cap carved to fit a clay pot's mouth. With a lump of wax it seals a pot of preserves, and comes back when the pot is opened.", "stack": 1, "w": 0.1,
		"color": Color(0.62, 0.47, 0.30), "shape": "pot_cap"},
	# Soup: a soup pot is carried and hangs over a fire (see soup_pot.gd); a
	# clay pot scoops one serving out of it. A Pot of Soup's values are its
	# serving's, kept in its slot's `data`; the ones here are a stand-in.
	"soup_pot_unfired": {"name": "Unfired Soup Pot", "desc": "A big coil-built pot hanging from a tripod of boards. Too big for the bag: carry it (E) and set it down over a lit campfire to fire it.", "stack": 1, "w": 0.0,
		"color": Color(0.58, 0.56, 0.52), "shape": "soup_pot", "carry": true},
	"soup_pot": {"name": "Soup Pot", "desc": "A big fired pot on a board tripod that hangs over a campfire. Carry it to the water to fill it, boil it, then add food (hold it and press E) to make soup. Holds 16 servings.", "stack": 1, "w": 0.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "soup_pot", "carry": true},
	"pot_soup": {"name": "Pot of Soup", "desc": "A serving of soup scooped from a soup pot. Keeps as long as the soup in the pot would have.", "stack": 1, "w": 3.0,
		"color": Color(0.62, 0.45, 0.22), "shape": "pot_water", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 2160.0, "spoil": "pot_soup_spoiled", "empty": "pot"},
	"pot_soup_spoiled": {"name": "Pot of Spoiled Soup", "desc": "It has gone off. Drinking it will very likely make you sick.", "stack": 1, "w": 3.0,
		"color": Color(0.42, 0.44, 0.24), "shape": "pot_water", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "pot"},
	# A wooden canteen holds two servings of water or soup, each kind its own
	# item: "_1" half full, "_2" full. Drinking one leaves the one below
	# (`empty`), keeping a soup's serving `data`. Weighs 80% of a clay pot
	# empty; each serving adds what a pot's does (1.5 kg).
	"canteen": {"name": "Wooden Canteen", "desc": "A hollowed, wax-sealed length of jointed stem with a carved wooden lid, on a cord. Holds two servings: fill it at the water, or with boiled water or soup from a soup pot (hold it and press E at the pot). Wood can't go on the fire, so boil water in a pot first.", "stack": 1, "w": 1.2,
		"color": Color(0.42, 0.30, 0.18), "shape": "canteen", "hold": "canteen_dirty_2"},
	"canteen_dirty_1": {"name": "Canteen of Swamp Water (1/2)", "desc": "Half full of murky swamp water. Risky to drink.", "stack": 1, "w": 2.7,
		"color": Color(0.40, 0.42, 0.25), "shape": "canteen", "water": 35.0, "sick": 0.35, "empty": "canteen", "hold": "canteen_dirty_2"},
	"canteen_dirty_2": {"name": "Canteen of Swamp Water (2/2)", "desc": "Full of murky swamp water. Risky to drink.", "stack": 1, "w": 4.2,
		"color": Color(0.40, 0.42, 0.25), "shape": "canteen", "water": 35.0, "sick": 0.35, "empty": "canteen_dirty_1"},
	"canteen_clean_1": {"name": "Canteen of Boiled Water (1/2)", "desc": "Half full of boiled water. Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 2.7,
		"color": Color(0.45, 0.65, 0.80), "shape": "canteen", "water": 40.0, "empty": "canteen", "treat": "clean"},
	"canteen_clean_2": {"name": "Canteen of Boiled Water (2/2)", "desc": "Full of boiled water. Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 4.2,
		"color": Color(0.45, 0.65, 0.80), "shape": "canteen", "water": 40.0, "empty": "canteen_clean_1", "treat": "clean"},
	"canteen_soup_1": {"name": "Canteen of Soup (1/2)", "desc": "One serving of soup from a soup pot. Keeps as long as the soup in the pot would have.", "stack": 1, "w": 2.7,
		"color": Color(0.62, 0.45, 0.22), "shape": "canteen", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 2160.0, "spoil": "canteen_soup_spoiled_1", "empty": "canteen"},
	"canteen_soup_2": {"name": "Canteen of Soup (2/2)", "desc": "Two servings of soup from a soup pot. Keeps as long as the soup in the pot would have.", "stack": 1, "w": 4.2,
		"color": Color(0.62, 0.45, 0.22), "shape": "canteen", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 2160.0, "spoil": "canteen_soup_spoiled_2", "empty": "canteen_soup_1"},
	"canteen_soup_spoiled_1": {"name": "Canteen of Spoiled Soup (1/2)", "desc": "It has gone off. Drinking it will very likely make you sick.", "stack": 1, "w": 2.7,
		"color": Color(0.42, 0.44, 0.24), "shape": "canteen", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "canteen"},
	"canteen_soup_spoiled_2": {"name": "Canteen of Spoiled Soup (2/2)", "desc": "It has gone off. Drinking it will very likely make you sick.", "stack": 1, "w": 4.2,
		"color": Color(0.42, 0.44, 0.24), "shape": "canteen", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "canteen_soup_spoiled_1"},
	# Alcohol drawn from a sealed fermentation vessel: ten measures, each a
	# drink or a wound cleaned. How many are left is in the slot's `data`
	# ("left", and the name that says so).
	"canteen_alcohol": {"name": "Canteen of Alcohol", "desc": "Strong, sour drink fermented in a sealed vessel. Drink a measure (a little food, starch and water, and it goes to your head) or clean a wound with it (Treat): it fights infection.", "stack": 1, "w": 2.7,
		"color": Color(0.85, 0.66, 0.30), "shape": "canteen", "energy": 1.0, "starch": 3.0, "water": 3.0, "alcohol": 1.0, "treat": "alcohol", "measures": 10},
	# A copper soup pot (late game; see soup_pot.gd COPPER_*): raised on the
	# anvil, so never fired.
	"soup_pot_copper": {"name": "Copper Soup Pot", "desc": "A big copper pot raised on the anvil, on a board tripod that hangs over a campfire. Holds 20 servings, comes to the boil half again as fast as clay, and its soup keeps a fifth longer after it last boiled. Carry it to the water to fill it, boil it, then add food (hold it and press E) to make soup.", "stack": 1, "w": 0.0,
		"color": Color(0.80, 0.47, 0.24), "shape": "soup_pot", "carry": true},
	# A copper flask (late game): four servings of water or soup, each kind its
	# own item like the wooden canteen ("_1" to "_4"), or twenty measures of
	# alcohol. Lighter than the two canteens it replaces, and soup keeps twice
	# as long in it (`decay`). Its `shape` is "flask".
	"flask": {"name": "Copper Flask", "desc": "A flat, round copper flask raised on the anvil, its seam hammered tight and waxed, with a wooden stopper on a cord. Holds four servings of water or soup, or twenty measures of alcohol, and weighs less than two wooden canteens. Soup keeps twice as long in it. Fill it at the water, at a soup pot, or draw alcohol into it from a sealed vessel.", "stack": 1, "w": 1.4,
		"color": Color(0.80, 0.47, 0.24), "shape": "flask", "hold": "flask_dirty_4"},
	"flask_dirty_1": {"name": "Flask of Swamp Water (1/4)", "desc": "A quarter full of murky swamp water. Risky to drink.", "stack": 1, "w": 2.9,
		"color": Color(0.40, 0.42, 0.25), "shape": "flask", "water": 35.0, "sick": 0.35, "empty": "flask", "hold": "flask_dirty_4"},
	"flask_dirty_2": {"name": "Flask of Swamp Water (2/4)", "desc": "Half full of murky swamp water. Risky to drink.", "stack": 1, "w": 4.4,
		"color": Color(0.40, 0.42, 0.25), "shape": "flask", "water": 35.0, "sick": 0.35, "empty": "flask_dirty_1", "hold": "flask_dirty_4"},
	"flask_dirty_3": {"name": "Flask of Swamp Water (3/4)", "desc": "Three quarters full of murky swamp water. Risky to drink.", "stack": 1, "w": 5.9,
		"color": Color(0.40, 0.42, 0.25), "shape": "flask", "water": 35.0, "sick": 0.35, "empty": "flask_dirty_2", "hold": "flask_dirty_4"},
	"flask_dirty_4": {"name": "Flask of Swamp Water (4/4)", "desc": "Full of murky swamp water. Risky to drink.", "stack": 1, "w": 7.4,
		"color": Color(0.40, 0.42, 0.25), "shape": "flask", "water": 35.0, "sick": 0.35, "empty": "flask_dirty_3"},
	"flask_clean_1": {"name": "Flask of Boiled Water (1/4)", "desc": "A quarter full of boiled water. Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 2.9,
		"color": Color(0.45, 0.65, 0.80), "shape": "flask", "water": 40.0, "empty": "flask", "treat": "clean"},
	"flask_clean_2": {"name": "Flask of Boiled Water (2/4)", "desc": "Half full of boiled water. Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 4.4,
		"color": Color(0.45, 0.65, 0.80), "shape": "flask", "water": 40.0, "empty": "flask_clean_1", "treat": "clean"},
	"flask_clean_3": {"name": "Flask of Boiled Water (3/4)", "desc": "Three quarters full of boiled water. Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 5.9,
		"color": Color(0.45, 0.65, 0.80), "shape": "flask", "water": 40.0, "empty": "flask_clean_2", "treat": "clean"},
	"flask_clean_4": {"name": "Flask of Boiled Water (4/4)", "desc": "Full of boiled water. Safe to drink, or to wash out wounds (Treat).", "stack": 1, "w": 7.4,
		"color": Color(0.45, 0.65, 0.80), "shape": "flask", "water": 40.0, "empty": "flask_clean_3", "treat": "clean"},
	"flask_soup_1": {"name": "Flask of Soup (1/4)", "desc": "A quarter full of soup from a soup pot. The copper keeps it twice as long as the soup in the pot would have kept.", "stack": 1, "w": 2.9,
		"color": Color(0.62, 0.45, 0.22), "shape": "flask", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 4320.0, "spoil": "flask_soup_spoiled_1", "empty": "flask"},
	"flask_soup_2": {"name": "Flask of Soup (2/4)", "desc": "Half full of soup from a soup pot. The copper keeps it twice as long as the soup in the pot would have kept.", "stack": 1, "w": 4.4,
		"color": Color(0.62, 0.45, 0.22), "shape": "flask", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 4320.0, "spoil": "flask_soup_spoiled_2", "empty": "flask_soup_1"},
	"flask_soup_3": {"name": "Flask of Soup (3/4)", "desc": "Three quarters full of soup from a soup pot. The copper keeps it twice as long as the soup in the pot would have kept.", "stack": 1, "w": 5.9,
		"color": Color(0.62, 0.45, 0.22), "shape": "flask", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 4320.0, "spoil": "flask_soup_spoiled_3", "empty": "flask_soup_2"},
	"flask_soup_4": {"name": "Flask of Soup (4/4)", "desc": "Full of soup from a soup pot. The copper keeps it twice as long as the soup in the pot would have kept.", "stack": 1, "w": 7.4,
		"color": Color(0.62, 0.45, 0.22), "shape": "flask", "energy": 6.0, "protein": 4.0, "greens": 4.0, "starch": 4.0, "water": 30.0,
		"decay": 4320.0, "spoil": "flask_soup_spoiled_4", "empty": "flask_soup_3"},
	"flask_soup_spoiled_1": {"name": "Flask of Spoiled Soup (1/4)", "desc": "A quarter full of spoiled soup. Drinking it will very likely make you sick.", "stack": 1, "w": 2.9,
		"color": Color(0.42, 0.44, 0.24), "shape": "flask", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "flask"},
	"flask_soup_spoiled_2": {"name": "Flask of Spoiled Soup (2/4)", "desc": "Half full of spoiled soup. Drinking it will very likely make you sick.", "stack": 1, "w": 4.4,
		"color": Color(0.42, 0.44, 0.24), "shape": "flask", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "flask_soup_spoiled_1"},
	"flask_soup_spoiled_3": {"name": "Flask of Spoiled Soup (3/4)", "desc": "Three quarters full of spoiled soup. Drinking it will very likely make you sick.", "stack": 1, "w": 5.9,
		"color": Color(0.42, 0.44, 0.24), "shape": "flask", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "flask_soup_spoiled_2"},
	"flask_soup_spoiled_4": {"name": "Flask of Spoiled Soup (4/4)", "desc": "Full of spoiled soup. Drinking it will very likely make you sick.", "stack": 1, "w": 7.4,
		"color": Color(0.42, 0.44, 0.24), "shape": "flask", "energy": 2.0, "water": 15.0, "sick": 0.9, "empty": "flask_soup_spoiled_3"},
	"flask_alcohol": {"name": "Flask of Alcohol", "desc": "Strong, sour drink fermented in a sealed vessel, twenty measures to a flask. Drink a measure (a little food, starch and water, and it goes to your head) or clean a wound with it (Treat): it fights infection.", "stack": 1, "w": 4.4,
		"color": Color(0.85, 0.66, 0.30), "shape": "flask", "energy": 1.0, "starch": 3.0, "water": 3.0, "alcohol": 1.0, "treat": "alcohol", "measures": 20, "drained": "flask"},
	# Fermentation vessels: carried like the soup pot, made at a bench with
	# the clay platter on its rack and fired by sitting them in a campfire
	# (see ferment_vessel.gd).
	"vessel_open_unfired": {"name": "Unfired Unsealed Fermentation Vessel", "desc": "A big open-mouthed crock. Too big for the bag: carry it (E) and set it down in a lit campfire to fire it.", "stack": 1, "w": 0.0,
		"color": Color(0.58, 0.56, 0.52), "shape": "vessel", "carry": true},
	"vessel_open": {"name": "Unsealed Fermentation Vessel", "desc": "An open crock for pickling (lacto fermentation): clean water, then up to 10 food items. After a day they are pickled.", "stack": 1, "w": 0.0,
		"color": Color(0.66, 0.42, 0.28), "shape": "vessel", "carry": true},
	"vessel_sealed_unfired": {"name": "Unfired Sealed Fermentation Vessel", "desc": "A big jar with a fitted lid. Too big for the bag: carry it (E) and set it down in a lit campfire to fire it.", "stack": 1, "w": 0.0,
		"color": Color(0.58, 0.56, 0.52), "shape": "vessel", "carry": true},
	"vessel_sealed": {"name": "Sealed Fermentation Vessel", "desc": "A lidded jar for brewing alcohol (food in clean water, a day to ferment) or, with salt in it, for salting food at once.", "stack": 1, "w": 0.0,
		"color": Color(0.70, 0.44, 0.28), "shape": "vessel", "carry": true},
	"bandage": {"name": "Fiber Bandage", "desc": "Woven fern fiber. Covers a wound to keep dirt out, and stops bleeding once pressure has slowed it (Treat).", "stack": 10, "w": 0.05,
		"color": Color(0.78, 0.74, 0.55), "shape": "bandage", "treat": "bandage"},
	# The workbench, and the tools that hang on its rack.
	"workbench": {"name": "Workbench", "desc": "A plain wooden table with a tool rack on its back. Kneel at it (C) to make things on it, including what only a bench allows. Hold a workbench tool and press E at the bench to hang it on the rack.", "stack": 1, "w": 30.0,
		"color": Color(0.70, 0.56, 0.37), "shape": "workbench", "build": "workbench"},
	"clay_platter_unfired": {"name": "Unfired Platter", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 2.0,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "clay_platter", "cook_time": 100.0},
	"clay_platter": {"name": "Clay Platter", "desc": "A flat fired platter for forming clay on. Hang it on a workbench rack (hold it and press E at the bench) to work finer clay there.", "stack": 1, "w": 1.2,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "rack": true},
	# The spindle: a clay whorl, fired, fitted on a stick at a workbench. It
	# hangs on the rack (or rides in the bag) to spin string.
	"spindle_whorl_unfired": {"name": "Unfired Spindle Whorl", "desc": "A small clay disc with a hole through it. Fire it in a campfire before use.", "stack": 2, "w": 0.15,
		"color": Color(0.58, 0.56, 0.52), "shape": "whorl", "cook": "spindle_whorl", "cook_time": 40.0},
	"spindle_whorl": {"name": "Spindle Whorl", "desc": "A fired clay disc with a hole through it. Fit it on a stick at a workbench to make a spindle.", "stack": 2, "w": 0.1,
		"color": Color(0.70, 0.42, 0.28), "shape": "whorl"},
	"spindle": {"name": "Spindle", "desc": "A stick weighted with a fired clay whorl, for spinning plant fiber into string at a workbench. Hang it on the rack (hold it and press E at the bench), or carry it.", "stack": 1, "w": 0.25,
		"color": Color(0.60, 0.48, 0.30), "shape": "spindle", "rack": true},
	"clay_bowl_unfired": {"name": "Unfired Bowl", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.4,
		"color": Color(0.58, 0.56, 0.52), "shape": "bowl", "cook": "clay_bowl", "cook_time": 80.0},
	"clay_bowl": {"name": "Clay Bowl", "desc": "A wide fired bowl. With a fiber screen it makes papermaking tools.", "stack": 2, "w": 0.8,
		"color": Color(0.70, 0.42, 0.28), "shape": "bowl"},
	"woodworking_tools": {"name": "Woodworking Tools", "desc": "A chert chisel and a toothed chert saw in wooden handles. Hang them on a workbench rack (hold them and press E at the bench) for finer woodwork there.", "stack": 1, "w": 1.0,
		"color": Color(0.32, 0.32, 0.38), "shape": "chisel_saw", "rack": true},
	"papermaking_tools": {"name": "Papermaking Tools", "desc": "A clay bowl for mashing wood or plants to pulp and a fiber screen to lift sheets of it. Hang them on a workbench rack (hold them and press E at the bench) to make paper there.", "stack": 1, "w": 1.4,
		"color": Color(0.70, 0.42, 0.28), "shape": "paper_tools", "rack": true},
	# Paper and the pencil: made at a workbench with the papermaking tools on
	# its rack. A blank sheet and a pencil are what a blueprint is drawn with.
	"paper_wet": {"name": "Wet Sheet", "desc": "A sheet of fiber pulp lifted on the screen, still sopping. Dry it in a campfire to make a Big Blank Sheet.", "stack": 4, "w": 0.4,
		"color": Color(0.62, 0.64, 0.50), "shape": "paper", "cook": "paper_sheet", "cook_time": 40.0},
	"paper_sheet": {"name": "Big Blank Sheet", "desc": "A big sheet of rough fiber paper. An ash pencil will draw a blueprint on it.", "stack": 10, "w": 0.1,
		"color": Color(0.86, 0.84, 0.72), "shape": "paper"},
	"pencil_core_unfired": {"name": "Unfired Pencil Core", "desc": "A thin rod rolled from ash and clay. Fire it in a campfire to harden it.", "stack": 10, "w": 0.05,
		"color": Color(0.50, 0.49, 0.46), "shape": "pencil_core", "cook": "pencil_core", "cook_time": 50.0},
	"pencil_core": {"name": "Pencil Core", "desc": "A hard, dark rod of fired ash and clay that leaves a grey line. Bind it between the halves of a split stick to make an ash pencil.", "stack": 10, "w": 0.03,
		"color": Color(0.24, 0.23, 0.22), "shape": "pencil_core"},
	"ash_pencil": {"name": "Ash Pencil", "desc": "A fired ash-and-clay core bound between the two halves of a split stick. It will draw blueprints on a Big Blank Sheet: it is good for 50 uses, and needs sharpening with a blade twice for each blueprint, which wears one use off each time.", "stack": 5, "w": 0.06,
		"color": Color(0.55, 0.42, 0.26), "shape": "pencil", "uses": 50},
	# Blueprints: drawn at a workbench, then held to show where the building
	# goes and right-clicked to mark out its site (see house.gd).
	"blueprint_softwood_house": {"name": "Softwood House Blueprint", "desc": "Plans for a small wooden house on stilts, with a porch, a fireplace and a rope ladder. Hold it to see where the house would go and right-click to mark out the site. Then bring, part by part: 4 Calamites logs (carried, for the stilts) and a river stone to pound them in, 30 tree fern boards, 8 Calamites boards, 28 cordage, 6 sticks, 8 river stones and 6 wet clay.", "stack": 5, "w": 0.1,
		"color": Color(0.86, 0.84, 0.72), "shape": "blueprint", "blueprint": "softwood_house"},
	# Sacks (`tags` "sack"): `carry_kg` kg more you can carry (only the best sack
	# you have counts: Inventory.sack_bonus), `stash` kg it holds set down.
	# Fishing: a rod (from a branch, with the woodworking tools), a line (three
	# strings braided), and a hook knapped from chitin, put together at a bench.
	"rod_blank": {"name": "Fishing Rod Blank", "desc": "A long, springy rod trimmed and tapered from a branch. With a fishing line and a hook it makes a fishing rod at a workbench.", "stack": 1, "w": 0.5,
		"color": Color(0.56, 0.44, 0.27), "shape": "rod"},
	"fishing_line": {"name": "Fishing Line", "desc": "Three strings braided into a long, thin, strong line. With a rod blank and a hook it makes a fishing rod at a workbench.", "stack": 5, "w": 0.05,
		"color": Color(0.80, 0.76, 0.58), "shape": "cord"},
	"chitin_hook": {"name": "Chitin Hook", "desc": "A small barbed hook knapped from a plate of arthropod shell. With a rod blank and a fishing line it makes a fishing rod at a workbench.", "stack": 10, "w": 0.02,
		"color": Color(0.42, 0.27, 0.18), "shape": "hook"},
	# `fishing`: held, Use casts it (fishing.gd). Its bait is in the slot's
	# data ("bait", and a name that says so: bait_data).
	"fishing_rod": {"name": "Fishing Rod", "desc": "A rod, a braided line and a chitin hook. Bait it by laying it out with bait (meat bait, grubs, rotten food or guts), then cast it into the water (Use) and wait for a bite. Use again reels in.", "stack": 1, "w": 0.6,
		"color": Color(0.56, 0.44, 0.27), "shape": "fishing_rod", "fishing": true},
	# Traps (trap.gd), baited by kneeling at them (C) with bait laid out. A
	# fish trap is carried in your arms and set down in the water; a snare is
	# set on the ground with Use.
	"fish_trap": {"name": "Fish Trap", "desc": "A long basket of sticks lashed with cordage, with a funnel mouth fish swim in by and can't find their way out of. Set it down in shallow water, bait it (C), and each night you sleep it catches a few small fish.", "stack": 1, "w": 3.0,
		"color": Color(0.58, 0.48, 0.30), "shape": "fish_trap", "carry": true},
	"snare": {"name": "Snare", "desc": "A running noose of string on a bent branch. Set it on the ground (Use) and bait it (C): most nights it catches a small animal, now and then something bigger that is still alive when you come.", "stack": 5, "w": 0.2,
		"color": Color(0.60, 0.48, 0.30), "shape": "snare", "place": "snare"},
	"fiber_sack": {"name": "Woven Frond Sack", "desc": "A shoulder sack of woven cordage. Lets you carry 17 kg more. Set it down with Use to leave a stash holding up to 50 kg. Only your best sack counts.", "stack": 1, "w": 0.6,
		"color": Color(0.62, 0.55, 0.32), "shape": "sack", "tags": ["sack"], "place": "sack", "carry_kg": 17.0, "stash": 50.0},
	"cloth_sack": {"name": "Woven Cloth Sack", "desc": "A light, finely woven sack of spun string. Lets you carry 40 kg more. Set it down with Use to leave a stash holding up to 100 kg. Only your best sack counts.", "stack": 1, "w": 0.5,
		"color": Color(0.86, 0.82, 0.68), "shape": "sack", "tags": ["sack"], "place": "sack", "carry_kg": 40.0, "stash": 100.0},
	# Set down (Use), still rolled up, only on the floor of a finished house (swamp._place_bedroll,
	# bedroll.gd): sleep on it, or save the game at it.
	"bedroll": {"name": "Bedroll", "desc": "A coarse, primitive sleeping bag of loosely woven string, rolled up and tied. Set it down (Use) on the floor of your house. Then look at it and press Z to sleep when you're tired, or E to save the game without sleeping. Right-click it to pick it up again.", "stack": 1, "w": 1.2,
		"color": Color(0.64, 0.54, 0.36), "shape": "bedroll", "place": "bedroll"},

	# --- Boats (boats.md) -------------------------------------------------------
	"blueprint_dock": {"name": "Dock Blueprint", "desc": "Plans for a dock on Calamites piles running out over the water, with a slipway for a raft and a mooring post. Hold it at the water's edge to see where the dock would go and right-click to mark out the site. Then bring, part by part: 5 Calamites logs (carried: a land post and four piles) and a river stone to pound them in, 16 sticks, a blade, 8 Calamites boards, 12 tree fern boards, 3 branches and 22 cordage. Driving the piles is done standing in the water with nothing to protect you: throw a baitbox along the shore first.", "stack": 5, "w": 0.1,
		"color": Color(0.86, 0.84, 0.72), "shape": "blueprint", "blueprint": "dock"},
	"calamites_pole": {"name": "Calamites Pole", "desc": "A long, light pole split from a Calamites trunk. Hold it on a raft and the movement keys pole the raft along. A weak jab at anything biting the raft, with a long reach. Char the tip in a campfire to harden it.", "stack": 1, "w": 1.2,
		"color": Color(0.70, 0.62, 0.40), "shape": "rod", "damage": 3.5, "reach": 3.6, "tags": ["pole"], "cook": "hardened_pole", "cook_time": 40.0},
	"hardened_pole": {"name": "Fire-Hardened Pole", "desc": "A Calamites pole with its tip charred hard in a fire. Poles a raft, and jabs a little harder.", "stack": 1, "w": 1.2,
		"color": Color(0.42, 0.34, 0.22), "shape": "rod", "damage": 5.0, "reach": 3.6, "tags": ["pole"], "as": "calamites_pole"},
	"copper_shod_pole": {"name": "Copper-Shod Pole", "desc": "A raft pole with a copper shoe on its tip: it bites hard into anything that grabs the raft.", "stack": 1, "w": 1.4,
		"color": Color(0.70, 0.62, 0.40), "shape": "rod", "damage": 9.0, "reach": 3.6, "tier": "metal", "tags": ["pole"]},
	"iron_shod_pole": {"name": "Iron-Shod Pole", "desc": "A raft pole tipped with a sharp iron shoe, the best there is.", "stack": 1, "w": 1.4,
		"color": Color(0.70, 0.62, 0.40), "shape": "rod", "damage": 12.0, "reach": 3.6, "tier": "advanced", "tags": ["pole"]},

	# --- Metals (metals.md) -----------------------------------------------------
	# Copper is gathered on the rocky islands, smashed, washed in a pan at the
	# water, smelted (ore only) and cast in fired clay moulds at the furnace
	# (furnace.gd). Castings are ground sharp at the anvil's whetstone (anvil.gd)
	# and hafted. `edge`: a metal tool's uses before it goes blunt (half damage,
	# twice the steps) until it is sharpened again. `breaks`: a stone tool's
	# head can snap off after STONE_SAFE uses, leaving this in your hand.
	# "copper" stands for anything castable (`as` "copper") in recipes.
	"charcoal_clamp": {"name": "Charcoal Clamp", "desc": "A pit of firewood sealed under clay, built where you kneel. Lit with an ember or a lit torch, it smoulders for a day into charcoal.", "stack": 1, "w": 1.0,
		"color": Color(0.50, 0.45, 0.38), "shape": "compost", "build": "clamp"},
	"furnace": {"name": "Clay Furnace", "desc": "A waist-high clay shaft on a ring of river stones, blown with blowpipes. All the hot work with copper is done at it: smelting and casting.", "stack": 1, "w": 1.0,
		"color": Color(0.62, 0.42, 0.30), "shape": "pot", "build": "furnace"},
	"copper": {"name": "Copper", "desc": "Copper grains or unrefined copper: what goes in a mould.", "stack": 20, "w": 0.4,
		"color": Color(0.80, 0.47, 0.24), "shape": "salt", "pile": true},
	"native_copper": {"name": "Native Copper", "desc": "A lump of rock with twisted threads of bright copper running through it, washed up in the gravel round the islands. Smash it with a river stone, then wash the copper out of the grit in a washing pan.", "stack": 20, "w": 0.4,
		"color": Color(0.62, 0.45, 0.32), "shape": "rock", "pile": true},
	"copper_ore": {"name": "Copper Ore", "desc": "Green-stained malachite broken off an island outcrop. Crush it with a copper hammer, wash it in a washing pan, then smelt it in the furnace.", "stack": 20, "w": 1.0,
		"color": Color(0.24, 0.56, 0.40), "shape": "rock", "pile": true},
	"smashed_native_copper": {"name": "Smashed Native Copper", "desc": "Native copper beaten to grit and flakes. Wash the copper out of the grit in a washing pan at the water.", "stack": 20, "w": 0.4,
		"color": Color(0.58, 0.48, 0.40), "shape": "salt", "pile": true},
	"crushed_copper_ore": {"name": "Crushed Copper Ore", "desc": "Malachite crushed to green grit. Wash it in a washing pan at the water: two make one sifted ore.", "stack": 20, "w": 1.0,
		"color": Color(0.36, 0.56, 0.44), "shape": "salt", "pile": true},
	"copper_grains": {"name": "Copper Grains", "desc": "Bright copper washed out of smashed native copper, ready to fill a mould.", "stack": 20, "w": 0.4,
		"color": Color(0.80, 0.47, 0.24), "shape": "salt", "pile": true, "as": "copper"},
	"sifted_copper_ore": {"name": "Sifted Copper Ore", "desc": "Heavy green ore washed clean of grit. Smelt it in the furnace with charcoal: two make one unrefined copper.", "stack": 20, "w": 0.5,
		"color": Color(0.20, 0.62, 0.42), "shape": "salt", "pile": true},
	"unrefined_copper": {"name": "Unrefined Copper", "desc": "Drops of copper picked out of the slag. Ready to fill a mould.", "stack": 20, "w": 0.5,
		"color": Color(0.70, 0.42, 0.24), "shape": "rock", "pile": true, "as": "copper"},
	"charcoal": {"name": "Charcoal", "desc": "Light, black and brittle, from a charcoal clamp. Burns hot and long: the furnace needs it, and in a campfire it lasts far longer than wood.", "stack": 30, "w": 0.2,
		"color": Color(0.12, 0.12, 0.13), "shape": "blob", "pile": true, "fuel": 900.0},
	"whetstone": {"name": "Whetstone", "desc": "A river stone ground flat and smooth. Hold it and press E at an anvil to seat it in the anvil's corner: then kneel at the anvil (C) to grind castings sharp and sharpen blunt metal tools.", "stack": 1, "w": 0.8,
		"color": Color(0.62, 0.62, 0.58), "shape": "rock"},
	"anvil_stone": {"name": "Anvil Stone", "desc": "A flat basalt slab from the islands. Too heavy for the bag: carry it and set it down where you want your anvil.", "stack": 1, "w": 30.0,
		"color": Color(0.28, 0.28, 0.30), "shape": "rock", "carry": true},
	"meteorite": {"name": "Meteorite", "desc": "A dark, pitted, rusty lump of iron that fell from the sky. Kneel at it with a copper chisel and hammer to chip lumps off.", "stack": 1, "w": 15.0,
		"color": Color(0.30, 0.24, 0.20), "shape": "rock", "carry": true},
	"washing_pan_unfired": {"name": "Unfired Washing Pan", "desc": "Fire it in a campfire before use.", "stack": 1, "w": 2.0,
		"color": Color(0.58, 0.56, 0.52), "shape": "bowl", "cook": "washing_pan", "cook_time": 90.0},
	"washing_pan": {"name": "Washing Pan", "desc": "A wide, shallow fired clay pan. Kneel (C) where you are looking at the water with it and smashed copper or crushed ore, and wash the light grit away until only the heavy copper is left.", "stack": 1, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "bowl"},
	"tuyere_unfired": {"name": "Unfired Tuyere", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.0,
		"color": Color(0.58, 0.56, 0.52), "shape": "pencil_core", "cook": "tuyere", "cook_time": 60.0},
	"tuyere": {"name": "Tuyere", "desc": "A fired clay nozzle: the furnace's blowpipes blow in through it.", "stack": 2, "w": 0.6,
		"color": Color(0.70, 0.42, 0.28), "shape": "pencil_core"},
	"blowpipe_unfired": {"name": "Unfired Blowpipe", "desc": "A hollow Calamites shoot with a clay tip. Fire it in a campfire to harden the tip.", "stack": 4, "w": 0.4,
		"color": Color(0.50, 0.60, 0.32), "shape": "rod", "cook": "blowpipe", "cook_time": 30.0},
	"blowpipe": {"name": "Blowpipe", "desc": "A hollow Calamites shoot with a fired clay tip. Two of them blow the furnace.", "stack": 4, "w": 0.3,
		"color": Color(0.62, 0.55, 0.32), "shape": "rod"},
	"mould_axe_unfired": {"name": "Unfired Axe Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_axe", "cook_time": 80.0},
	"mould_axe": {"name": "Axe Mould", "desc": "An open mould of fired clay for an axe head. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_knife_unfired": {"name": "Unfired Knife Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_knife", "cook_time": 80.0},
	"mould_knife": {"name": "Knife Mould", "desc": "An open mould of fired clay for a knife blade. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_spear_unfired": {"name": "Unfired Spear Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_spear", "cook_time": 80.0},
	"mould_spear": {"name": "Spear Mould", "desc": "An open mould of fired clay for a spear head. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_hammer_unfired": {"name": "Unfired Hammer Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_hammer", "cook_time": 80.0},
	"mould_hammer": {"name": "Hammer Mould", "desc": "An open mould of fired clay for a hammer head. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_saw_unfired": {"name": "Unfired Saw Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_saw", "cook_time": 80.0},
	"mould_saw": {"name": "Saw Mould", "desc": "An open mould of fired clay for a saw blade. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_bar_unfired": {"name": "Unfired Bar Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_bar", "cook_time": 80.0},
	"mould_bar": {"name": "Bar Mould", "desc": "An open mould of fired clay for a bar (for a chisel or a pole shoe). Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_hook_unfired": {"name": "Unfired Hook Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_hook", "cook_time": 80.0},
	"mould_hook": {"name": "Hook Mould", "desc": "An open mould of fired clay for three fishhooks. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"mould_beads_unfired": {"name": "Unfired Beads Mould", "desc": "Fire it in a campfire before use.", "stack": 2, "w": 1.6,
		"color": Color(0.58, 0.56, 0.52), "shape": "platter", "cook": "mould_beads", "cook_time": 80.0},
	"mould_beads": {"name": "Beads Mould", "desc": "An open mould of fired clay for a string of beads. Lay it out at the furnace with copper and charcoal to cast. It cracks after 5 castings.", "stack": 2, "w": 1.0,
		"color": Color(0.70, 0.42, 0.28), "shape": "platter", "uses": 5},
	"rough_copper_axe_head": {"name": "Rough Copper Axe Head", "desc": "A fresh casting. Grind it sharp at the anvil's whetstone, then haft it.", "stack": 4, "w": 0.7,
		"color": Color(0.55, 0.36, 0.22), "shape": "axe_head", "head": Color(0.55, 0.36, 0.22)},
	"rough_copper_knife_blade": {"name": "Rough Copper Knife Blade", "desc": "A fresh casting. Grind it sharp at the anvil's whetstone, then haft it.", "stack": 4, "w": 0.4,
		"color": Color(0.55, 0.36, 0.22), "shape": "blade", "head": Color(0.55, 0.36, 0.22)},
	"rough_copper_spear_head": {"name": "Rough Copper Spear Head", "desc": "A fresh casting. Grind it sharp at the anvil's whetstone, then haft it.", "stack": 4, "w": 0.4,
		"color": Color(0.55, 0.36, 0.22), "shape": "spear_head", "head": Color(0.55, 0.36, 0.22)},
	"rough_copper_saw_blade": {"name": "Rough Copper Saw Blade", "desc": "A fresh casting. Grind its teeth sharp at the anvil's whetstone, then haft it.", "stack": 4, "w": 0.7,
		"color": Color(0.55, 0.36, 0.22), "shape": "plank"},
	"copper_bar": {"name": "Copper Bar", "desc": "A short cast bar. Grind it at the anvil's whetstone into a chisel or a pole shoe.", "stack": 4, "w": 0.4,
		"color": Color(0.80, 0.47, 0.24), "shape": "pencil_core"},
	"copper_axe_head": {"name": "Copper Axe Head", "desc": "Ground sharp. Haft it to make a copper axe, or crosswise to make a copper mattock.", "stack": 4, "w": 0.7,
		"color": Color(0.80, 0.47, 0.24), "shape": "axe_head", "head": Color(0.80, 0.47, 0.24)},
	"copper_knife_blade": {"name": "Copper Knife Blade", "desc": "Ground sharp. Haft it to make a copper knife.", "stack": 4, "w": 0.4,
		"color": Color(0.80, 0.47, 0.24), "shape": "blade", "head": Color(0.80, 0.47, 0.24)},
	"copper_spear_head": {"name": "Copper Spear Head", "desc": "Ground sharp. Haft it to make a copper spear.", "stack": 4, "w": 0.4,
		"color": Color(0.80, 0.47, 0.24), "shape": "spear_head", "head": Color(0.80, 0.47, 0.24)},
	"copper_saw_blade": {"name": "Copper Saw Blade", "desc": "Its teeth ground sharp. Haft it to make a copper saw.", "stack": 4, "w": 0.7,
		"color": Color(0.80, 0.47, 0.24), "shape": "plank"},
	"copper_hammer_head": {"name": "Copper Hammer Head", "desc": "A heavy cast head. Haft it to make a copper hammer.", "stack": 4, "w": 0.8,
		"color": Color(0.80, 0.47, 0.24), "shape": "mattock_head", "head": Color(0.80, 0.47, 0.24)},
	"copper_pole_shoe": {"name": "Copper Pole Shoe", "desc": "A pointed copper cap for the tip of a raft pole.", "stack": 4, "w": 0.3,
		"color": Color(0.80, 0.47, 0.24), "shape": "pencil_core"},
	"copper_fishhook": {"name": "Copper Fishhook", "desc": "A sharp, barbed copper hook. Bait stays on it: rig a rod with it at a workbench, or swap it onto a rod by hand.", "stack": 10, "w": 0.02,
		"color": Color(0.80, 0.47, 0.24), "shape": "hook"},
	"copper_beads": {"name": "Copper Beads", "desc": "A string of little cast copper beads. Good for nothing but looking at: a first trophy from the islands.", "stack": 5, "w": 0.1,
		"color": Color(0.80, 0.47, 0.24), "shape": "cord"},
	"copper_axe": {"name": "Copper Axe", "desc": "Fells every tree, the hard Lepidodendron and Sigillaria too (slowly). Goes blunt with use: sharpen it at the anvil's whetstone.", "stack": 1, "w": 1.5,
		"color": Color(0.50, 0.40, 0.28), "shape": "axe", "damage": 14.0, "tier": "metal", "reach": 2.4, "tags": ["cut", "chop"], "edge": 30, "head": Color(0.80, 0.47, 0.24)},
	"copper_knife": {"name": "Copper Knife", "desc": "A keen copper blade: butchers faster than chert. Goes blunt with use: sharpen it at the anvil's whetstone.", "stack": 1, "w": 0.4,
		"color": Color(0.50, 0.40, 0.28), "shape": "blade", "damage": 9.0, "tier": "metal", "reach": 2.2, "tags": ["cut"], "edge": 30, "head": Color(0.80, 0.47, 0.24)},
	"copper_spear": {"name": "Copper Spear", "desc": "Long reach and a heavy copper point. Goes blunt with use: sharpen it at the anvil's whetstone.", "stack": 1, "w": 1.7,
		"color": Color(0.50, 0.40, 0.28), "shape": "spear", "damage": 19.0, "tier": "metal", "reach": 3.4, "edge": 30, "head": Color(0.80, 0.47, 0.24)},
	"copper_mattock": {"name": "Copper Mattock", "desc": "Digs faster than stone. Goes blunt with use: sharpen it at the anvil's whetstone.", "stack": 1, "w": 1.6,
		"color": Color(0.50, 0.40, 0.28), "shape": "mattock", "damage": 11.0, "tier": "metal", "reach": 2.3, "tags": ["dig"], "edge": 30, "head": Color(0.80, 0.47, 0.24)},
	"copper_saw": {"name": "Copper Saw", "desc": "Saws any log straight into boards, the hardwoods too: kneel at a log (C) with it. Goes blunt with use: sharpen it at the anvil's whetstone.", "stack": 1, "w": 0.8,
		"color": Color(0.50, 0.40, 0.28), "shape": "chisel_saw", "damage": 5.0, "tier": "metal", "reach": 2.0, "tags": ["saw"], "edge": 30},
	"copper_chisel": {"name": "Copper Chisel", "desc": "Hard enough to bite into meteoric iron. Goes blunt with use: sharpen it at the anvil's whetstone.", "stack": 1, "w": 0.4,
		"color": Color(0.50, 0.40, 0.28), "shape": "pencil_core", "damage": 4.0, "tier": "metal", "reach": 1.8, "tags": ["chisel"], "edge": 30, "color2": Color(0.80, 0.47, 0.24)},
	"copper_hammer": {"name": "Copper Hammer", "desc": "Breaks copper ore off the island outcrops and crushes it, and works meteoric iron cold. Its face mushrooms on iron: once worn out it is only good for melting down again.", "stack": 1, "w": 1.2,
		"color": Color(0.50, 0.40, 0.28), "shape": "mattock", "damage": 8.0, "tier": "metal", "reach": 2.2, "tags": ["hammer"], "head": Color(0.80, 0.47, 0.24), "uses": 60},
	"iron_axe": {"name": "Iron Axe", "desc": "The real metal axe: fells every tree as fast as a soft one. Holds its edge longer than copper.", "stack": 1, "w": 1.6,
		"color": Color(0.50, 0.40, 0.28), "shape": "axe", "damage": 18.0, "tier": "advanced", "reach": 2.4, "tags": ["cut", "chop"], "edge": 45, "head": Color(0.60, 0.61, 0.63)},
	"iron_knife": {"name": "Iron Knife", "desc": "The best blade there is.", "stack": 1, "w": 0.4,
		"color": Color(0.50, 0.40, 0.28), "shape": "blade", "damage": 11.0, "tier": "advanced", "reach": 2.2, "tags": ["cut"], "edge": 45, "head": Color(0.60, 0.61, 0.63)},
	"iron_spear": {"name": "Iron Spear", "desc": "A long spear with a sharp iron point: the best weapon there is.", "stack": 1, "w": 1.7,
		"color": Color(0.50, 0.40, 0.28), "shape": "spear", "damage": 24.0, "tier": "advanced", "reach": 3.4, "edge": 45, "head": Color(0.60, 0.61, 0.63)},
	"iron_mattock": {"name": "Iron Mattock", "desc": "Digs fastest of all.", "stack": 1, "w": 1.6,
		"color": Color(0.50, 0.40, 0.28), "shape": "mattock", "damage": 13.0, "tier": "advanced", "reach": 2.3, "tags": ["dig"], "edge": 45, "head": Color(0.60, 0.61, 0.63)},
	"iron_chisel": {"name": "Iron Chisel", "desc": "Chips meteoric iron twice as fast as copper.", "stack": 1, "w": 0.4,
		"color": Color(0.50, 0.40, 0.28), "shape": "pencil_core", "damage": 5.0, "tier": "advanced", "reach": 1.8, "tags": ["chisel"], "edge": 45},
	"iron_hammer": {"name": "Iron Hammer", "desc": "Breaks and crushes ore and works iron faster than copper, and never wears out.", "stack": 1, "w": 1.3,
		"color": Color(0.50, 0.40, 0.28), "shape": "mattock", "damage": 10.0, "tier": "advanced", "reach": 2.2, "tags": ["hammer"], "head": Color(0.60, 0.61, 0.63)},
	"fishing_rod_copper": {"name": "Fishing Rod (copper hook)", "desc": "A rod, a braided line and a barbed copper hook. Bait it by laying it out with bait, cast it (Use) and wait for a bite. Every bite is a fish, and the bait stays on the hook until you land one or one fights free: not even an amphibian tearing a fish off takes it.", "stack": 1, "w": 0.6,
		"color": Color(0.56, 0.44, 0.27), "shape": "fishing_rod", "fishing": true, "copper_hook": true},
	"meteoric_iron": {"name": "Meteoric Iron", "desc": "A small lump of rusty iron from a meteorite. Beat it clean on an anvil with a copper hammer into refined iron.", "stack": 10, "w": 0.5,
		"color": Color(0.36, 0.28, 0.22), "shape": "rock", "pile": true},
	"meteoric_iron_large": {"name": "Large Meteoric Iron", "desc": "A big lump of rusty iron from a meteorite, big enough for an axe or a spear. Beat it clean on an anvil with a copper hammer into a refined iron bar.", "stack": 10, "w": 1.0,
		"color": Color(0.34, 0.27, 0.21), "shape": "rock", "pile": true},
	"refined_iron": {"name": "Refined Iron", "desc": "Clean meteoric iron, beaten flat. Hammer it into a knife blade, a chisel or a pole shoe at the anvil.", "stack": 10, "w": 0.45,
		"color": Color(0.60, 0.61, 0.63), "shape": "pencil_core"},
	"refined_iron_bar": {"name": "Refined Iron Bar", "desc": "A bar of clean meteoric iron. Hammer it into an axe, spear, mattock or hammer head at the anvil.", "stack": 10, "w": 0.9,
		"color": Color(0.60, 0.61, 0.63), "shape": "plank"},
	"rough_iron_axe_head": {"name": "Rough Iron Axe Head", "desc": "Hammered to shape. Grind it sharp at the anvil's whetstone.", "stack": 4, "w": 0.8,
		"color": Color(0.36, 0.35, 0.34), "shape": "axe_head", "head": Color(0.36, 0.35, 0.34)},
	"rough_iron_knife_blade": {"name": "Rough Iron Knife Blade", "desc": "Hammered to shape. Grind it sharp at the anvil's whetstone.", "stack": 4, "w": 0.4,
		"color": Color(0.36, 0.35, 0.34), "shape": "blade", "head": Color(0.36, 0.35, 0.34)},
	"rough_iron_spear_head": {"name": "Rough Iron Spear Head", "desc": "Hammered to shape. Grind it sharp at the anvil's whetstone.", "stack": 4, "w": 0.5,
		"color": Color(0.36, 0.35, 0.34), "shape": "spear_head", "head": Color(0.36, 0.35, 0.34)},
	"rough_iron_mattock_head": {"name": "Rough Iron Mattock Head", "desc": "Hammered to shape. Grind it sharp at the anvil's whetstone.", "stack": 4, "w": 0.8,
		"color": Color(0.36, 0.35, 0.34), "shape": "mattock_head", "head": Color(0.36, 0.35, 0.34)},
	"rough_iron_chisel": {"name": "Rough Iron Chisel", "desc": "Hammered to shape. Grind it sharp at the anvil's whetstone.", "stack": 4, "w": 0.4,
		"color": Color(0.36, 0.35, 0.34), "shape": "pencil_core"},
	"rough_iron_pole_shoe": {"name": "Rough Iron Pole Shoe", "desc": "Hammered to shape. Grind it sharp at the anvil's whetstone.", "stack": 4, "w": 0.4,
		"color": Color(0.36, 0.35, 0.34), "shape": "pencil_core"},
	"iron_axe_head": {"name": "Iron Axe Head", "desc": "Ground sharp. Haft it with a stick and cordage.", "stack": 4, "w": 0.8,
		"color": Color(0.60, 0.61, 0.63), "shape": "axe_head", "head": Color(0.60, 0.61, 0.63)},
	"iron_knife_blade": {"name": "Iron Knife Blade", "desc": "Ground sharp. Haft it with a stick and cordage.", "stack": 4, "w": 0.4,
		"color": Color(0.60, 0.61, 0.63), "shape": "blade", "head": Color(0.60, 0.61, 0.63)},
	"iron_spear_head": {"name": "Iron Spear Head", "desc": "Ground sharp. Haft it with a stick and cordage.", "stack": 4, "w": 0.5,
		"color": Color(0.60, 0.61, 0.63), "shape": "spear_head", "head": Color(0.60, 0.61, 0.63)},
	"iron_mattock_head": {"name": "Iron Mattock Head", "desc": "Ground sharp. Haft it with a stick and cordage.", "stack": 4, "w": 0.8,
		"color": Color(0.60, 0.61, 0.63), "shape": "mattock_head", "head": Color(0.60, 0.61, 0.63)},
	"iron_pole_shoe": {"name": "Iron Pole Shoe", "desc": "Ground sharp. Haft it with a stick and cordage.", "stack": 4, "w": 0.4,
		"color": Color(0.60, 0.61, 0.63), "shape": "pencil_core"},
	"iron_hammer_head": {"name": "Iron Hammer Head", "desc": "A heavy iron head hammered cold. Haft it to make an iron hammer.", "stack": 4, "w": 0.9,
		"color": Color(0.60, 0.61, 0.63), "shape": "mattock_head", "head": Color(0.60, 0.61, 0.63)},
}

## Crafting tiers. Each tier is a place to work: by hand anywhere on the
## ground, then workbenches. A tier's recipes stay hidden in the recipe book
## until its workbench has been built (Game.tiers).
const TIERS := ["hand", "bench", "metal"]
const TIER_NAMES := {
	"hand": "By hand, on the ground",
	"bench": "At a workbench",
	"metal": "At the furnace, the anvil or a meteorite",
}

## Recipe book categories, in order.
const CATEGORIES := ["Accelerator", "Breakroom", "Stone tools", "Weapons", "Materials", "Fire", "Food", "Fishing", "Traps", "Containers", "Farming", "Medicine", "Gear", "Workbench", "Writing", "Blueprints", "Metal"]
## The recipe book's own page for recipes that need a tool on a workbench's
## rack, shown apart from their categories once you know the tool.
const ADVANCED := "Rack tools"
## What a recipe's `tool_tag` asks for, in words.
const TAG_TOOLS := {"cut": "blade", "chop": "axe", "dig": "digging tool", "saw": "saw", "hammer": "copper hammer", "chisel": "copper chisel", "pole": "raft pole"}

## Crafting recipes. `where` limits a recipe to the lab or the swamp, `tier`
## says where it is made, `cat` is its recipe book category, `act` the
## hands-on step (twist, steps, knap; see work_spot.gd) with `verb` and `how`
## describing it, and `tools` are needed but not used up. Knapping recipes
## name their 5x5 pattern in `knap`. `guts` leaves that many guts (and the
## skin) in a pile on the ground. `build` puts up what it makes right where
## you worked (a workbench) instead of giving you an item. "bench" tier
## recipes are made only at a workbench, and one with `rack` only at a bench
## with that tool hanging on its rack (see workbench.gd). Everything made by
## hand can be made at a bench too. `tool_tag` needs any tool with that tag
## (a blade for "cut"), kept like `tools`. An input with `empty` (a pot of
## water) is used up and its empty container given back.
const RECIPES := [
	{"out": "beam_segment", "n": 1, "in": {"beam_pipe": 1, "magnet_coil": 2}, "where": "lab", "tier": "hand",
		"cat": "Accelerator", "act": "steps", "verb": "Fit the coils",
		"how": "Click each coil mount on the pipe to clamp a magnet coil onto it."},
	{"out": "injector", "n": 1, "in": {"control_board": 1, "copper_wire": 1, "power_cell": 1}, "where": "lab", "tier": "hand",
		"cat": "Accelerator", "act": "steps", "verb": "Wire the injector",
		"how": "Click the glowing points to seat the cell, wire it up and plug in the board."},
	{"out": "keycard_jr", "n": 1, "in": {"papers": 1}, "where": "lab", "tier": "bench", "steps": 9, "read": true,
		"cat": "Breakroom", "act": "steps", "verb": "Read the papers",
		"how": "Click the page to turn it over and read the next one."},

	{"out": "flint_blade", "n": 1, "in": {"flint": 1}, "tools": {"stone": 1}, "where": "swamp", "tier": "hand",
		"cat": "Stone tools", "act": "knap", "knap": "flint_blade", "verb": "Knap a blade",
		"how": "Strike flakes off the nodule with a river stone until only the blade shape is left."},
	{"out": "axe_head", "n": 1, "in": {"flint": 1}, "tools": {"stone": 1}, "where": "swamp", "tier": "hand",
		"cat": "Stone tools", "act": "knap", "knap": "axe_head", "verb": "Knap an axe head",
		"how": "Strike flakes off the nodule with a river stone until only the axe head is left."},
	{"out": "spear_head", "n": 1, "in": {"flint": 1}, "tools": {"stone": 1}, "where": "swamp", "tier": "hand",
		"cat": "Stone tools", "act": "knap", "knap": "spear_head", "verb": "Knap a spear point",
		"how": "Strike flakes off the nodule with a river stone until only the point is left."},
	{"out": "mattock_head", "n": 1, "in": {"flint": 1}, "tools": {"stone": 1}, "where": "swamp", "tier": "hand",
		"cat": "Stone tools", "act": "knap", "knap": "mattock_head", "verb": "Knap a mattock head",
		"how": "Strike flakes off the nodule with a river stone until only the mattock head is left."},
	{"out": "mattock", "n": 1, "in": {"mattock_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Stone tools", "act": "steps", "verb": "Haft the mattock",
		"how": "Click the binding again and again to lash the head crosswise to the handle."},
	{"out": "stone_axe", "n": 1, "in": {"axe_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Weapons", "act": "steps", "verb": "Haft the axe",
		"how": "Click the binding again and again to lash the head to the handle."},
	{"out": "spear", "n": 1, "in": {"spear_head": 1, "stick": 2, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Weapons", "act": "steps", "verb": "Haft the spear",
		"how": "Click the joints to lash the two shafts together and bind the point on."},
	{"out": "cordage", "n": 1, "in": {"plant_fiber": 3}, "where": "swamp", "tier": "hand",
		"cat": "Materials", "act": "twist", "verb": "Twist cordage",
		"how": "Hold the left mouse button and roll the fibers back and forth until they twist into cord."},
	{"out": "stick", "n": 3, "in": {"branch": 1}, "where": "swamp", "tier": "hand",
		"cat": "Materials", "act": "steps", "steps": 2, "verb": "Snap into sticks",
		"how": "Click along the branch to snap it into sticks."},
	{"out": "wax", "n": 1, "in": {"frond": 1}, "tools": {"stone": 1}, "where": "swamp", "tier": "hand",
		"cat": "Materials", "act": "steps", "verb": "Crush out wax",
		"how": "Click the frond to pound it with a river stone until the wax comes out."},
	{"out": "torch", "n": 1, "in": {"stick": 1, "wax": 2}, "where": "swamp", "tier": "hand",
		"cat": "Fire", "act": "twist", "verb": "Roll a torch",
		"how": "Hold the left mouse button and roll the stick back and forth in the wax until it is coated."},
	{"out": "torch", "n": 1, "in": {"charred_stick": 1, "wax": 2}, "where": "swamp", "tier": "hand",
		"cat": "Fire", "act": "twist", "verb": "Re-dip a torch",
		"how": "Hold the left mouse button and roll the charred stick in the wax until it is coated again."},
	{"out": "campfire_kit", "n": 1, "in": {"stick": 5, "tinder": 1, "stone": 2}, "where": "swamp", "tier": "hand",
		"cat": "Fire", "act": "steps", "verb": "Bundle a campfire",
		"how": "Click the glowing spots to stack the sticks, tuck in the tinder and add the ring stones. Set the bundle down where you want the fire."},
	{"out": "clay_pot", "n": 1, "in": {"clay": 5}, "where": "swamp", "tier": "hand",
		"cat": "Containers", "act": "steps", "verb": "Coil a pot",
		"how": "Click the rim to press on coil after coil of clay, then fire the pot in a campfire."},
	# Small prey: gutted and skinned by hand ("dress": four steps, shown on
	# the work spot as the animal being opened up).
	{"out": "lizard_dressed", "n": 1, "in": {"lizard_carcass": 1}, "where": "swamp", "tier": "hand", "guts": 1, "dress": true,
		"cat": "Food", "act": "steps", "verb": "Gut and skin a Hylonomus",
		"how": "Click along the belly to open it, pull out the guts and peel off the skin. They are left in a pile on the ground."},
	{"out": "petrolacosaurus_dressed", "n": 1, "in": {"petrolacosaurus_carcass": 1}, "where": "swamp", "tier": "hand", "guts": 1, "dress": true,
		"cat": "Food", "act": "steps", "verb": "Gut and skin a Petrolacosaurus",
		"how": "Click along the belly to open it, pull out the guts and peel off the skin. They are left in a pile on the ground."},
	{"out": "archaeothyris_dressed", "n": 1, "in": {"archaeothyris_carcass": 1}, "where": "swamp", "tier": "hand", "guts": 1, "dress": true,
		"cat": "Food", "act": "steps", "verb": "Gut and skin a Archaeothyris",
		"how": "Click along the belly to open it, pull out the guts and peel off the skin. They are left in a pile on the ground."},
	{"out": "amphibamus_dressed", "n": 1, "in": {"amphibamus_carcass": 1}, "where": "swamp", "tier": "hand", "guts": 1, "dress": true,
		"cat": "Food", "act": "steps", "verb": "Gut and skin a Amphibamus",
		"how": "Click along the belly to open it, pull out the guts and peel off the skin. They are left in a pile on the ground."},
	{"out": "tuditanus_dressed", "n": 1, "in": {"tuditanus_carcass": 1}, "where": "swamp", "tier": "hand", "guts": 1, "dress": true,
		"cat": "Food", "act": "steps", "verb": "Gut and skin a Tuditanus",
		"how": "Click along the belly to open it, pull out the guts and peel off the skin. They are left in a pile on the ground."},
	{"out": "morganucodon_dressed", "n": 1, "in": {"morganucodon_carcass": 1}, "where": "swamp", "tier": "hand", "guts": 1, "dress": true,
		"cat": "Food", "act": "steps", "verb": "Gut and skin a Morganucodon",
		"how": "Click along the belly to open it, pull out the guts and peel off the furry skin. They are left in a pile on the ground."},
	{"out": "bandage", "n": 2, "in": {"plant_fiber": 3, "frond": 1}, "where": "swamp", "tier": "hand",
		"cat": "Medicine", "act": "steps", "verb": "Weave bandages",
		"how": "Click the edges to weave fiber over and under across the frond."},
	{"out": "fiber_sack", "n": 1, "in": {"cordage": 4, "plant_fiber": 8}, "where": "swamp", "tier": "hand",
		"cat": "Containers", "act": "steps", "verb": "Weave a sack",
		"how": "Click the edges to weave row after row, then tie the neck."},
	{"out": "bedroll", "n": 1, "in": {"string": 8}, "where": "swamp", "tier": "hand", "known_by": "spindle",
		"cat": "Gear", "act": "steps", "steps": 8, "verb": "Weave a bedroll",
		"how": "Click the edges to weave the string into a long, coarse sheet, row after row, then fold it over, roll it up and tie it. Set it down (Use) on the floor of your house."},
	{"out": "cloth_sack", "n": 1, "in": {"string": 8}, "where": "swamp", "tier": "hand", "known_by": "spindle",
		"cat": "Containers", "act": "steps", "verb": "Weave a cloth sack",
		"how": "Click the edges to weave the string tightly, row after row, then tie the neck."},
	# Meat bait: every raw meat item (a piece of meat or fish, gnawed meat, any
	# dressed small prey, any small fish) tears into two.
	{"out": "meat_bait", "n": 2, "in": {"raw_meat": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up meat bait",
		"how": "Click the meat to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"fish_meat": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up fish for bait",
		"how": "Click the fish to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"small_fish": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a small fish for bait",
		"how": "Click the fish to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"gnawed_meat": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up gnawed meat for bait",
		"how": "Click the scraps to tear them into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"lizard_dressed": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a dressed lizard for bait",
		"how": "Click the lizard to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"petrolacosaurus_dressed": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a dressed Petrolacosaurus for bait",
		"how": "Click the animal to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"archaeothyris_dressed": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a dressed Archaeothyris for bait",
		"how": "Click the animal to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"amphibamus_dressed": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a dressed Amphibamus for bait",
		"how": "Click the animal to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"tuditanus_dressed": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a dressed Tuditanus for bait",
		"how": "Click the animal to tear it into small pieces of bait."},
	{"out": "meat_bait", "n": 2, "in": {"morganucodon_dressed": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Tear up a dressed Morganucodon for bait",
		"how": "Click the animal to tear it into small pieces of bait."},
	{"out": "fishing_line", "n": 1, "in": {"string": 3}, "where": "swamp", "tier": "hand", "known_by": "spindle",
		"cat": "Fishing", "act": "twist", "verb": "Braid a fishing line",
		"how": "Hold the left mouse button and roll the three strings back and forth until they braid into one thin, strong line."},
	{"out": "snare", "n": 1, "in": {"string": 1, "branch": 1}, "where": "swamp", "tier": "hand", "known_by": "spindle",
		"cat": "Traps", "act": "steps", "steps": 3, "verb": "Make a snare",
		"how": "Click the glowing spots to tie a running noose in the string, strip the branch and knot the string to its tip. Set it on the ground (Use), then kneel at it (C) to bait it."},
	{"out": "workbench", "n": 1, "in": {"board": 4, "stick": 4, "cordage": 2}, "where": "swamp", "tier": "hand", "build": true,
		"cat": "Workbench", "act": "steps", "steps": 8, "verb": "Build a workbench",
		"how": "Click the glowing spots to stand the legs, lash them, lay the boards across the top and fix the rack board along the back. It stays where you build it."},

	# Made only at a workbench, even before any tools hang on its rack.
	{"out": "clay_platter_unfired", "n": 1, "in": {"clay": 4}, "where": "swamp", "tier": "bench",
		"cat": "Workbench", "act": "steps", "steps": 5, "verb": "Form a platter",
		"how": "Click around the rim to press the clay out flat and pinch up a low lip. Fire it in a campfire, then hang it on the rack."},
	{"out": "woodworking_tools", "n": 1, "in": {"flint": 2, "stick": 2, "cordage": 1}, "tools": {"stone": 1}, "where": "swamp", "tier": "bench",
		"cat": "Workbench", "act": "steps", "steps": 6, "verb": "Make a chisel and saw",
		"how": "Click the glowing spots to flake a row of teeth along one chert edge for the saw, grind the other to a straight chisel edge, and lash both into handles."},
	{"out": "clay_bowl_unfired", "n": 1, "in": {"clay": 3}, "where": "swamp", "tier": "bench",
		"cat": "Workbench", "act": "steps", "steps": 4, "verb": "Pinch a bowl",
		"how": "Click around the rim to pinch the clay up into a wide bowl. Fire it in a campfire."},
	{"out": "spindle_whorl_unfired", "n": 1, "in": {"clay": 1}, "where": "swamp", "tier": "bench",
		"cat": "Workbench", "act": "steps", "steps": 3, "verb": "Shape a spindle whorl",
		"how": "Click to roll the clay into a ball, press it flat into a disc and pierce a hole through the middle. Fire it in a campfire."},
	{"out": "spindle", "n": 1, "in": {"spindle_whorl": 1, "stick": 1}, "where": "swamp", "tier": "bench",
		"cat": "Workbench", "act": "steps", "steps": 2, "verb": "Make a spindle",
		"how": "Click to whittle the stick smooth, then push the fired whorl onto it a hand's width from the end. Hang it on the rack, or carry it, to spin string."},
	{"out": "chitin_hook", "n": 1, "in": {"chitin": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench",
		"cat": "Fishing", "act": "knap", "knap": "chitin_hook", "verb": "Knap a chitin hook",
		"how": "Flake bits off the chitin plate with a blade until only the hook is left."},
	{"out": "fishing_rod", "n": 1, "in": {"rod_blank": 1, "fishing_line": 1, "chitin_hook": 1}, "where": "swamp", "tier": "bench",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Rig a fishing rod",
		"how": "Click to tie the line to the tip of the rod, run it down the rod, then tie on the hook."},
	# `known_by`: only known (in the book, and made) once you have made or
	# held that tool, or used a bench with it on the rack; it needn't be there.
	{"out": "bow_drill", "n": 1, "in": {"stick": 2, "string": 1}, "where": "swamp", "tier": "bench", "known_by": "spindle",
		"cat": "Fire", "act": "steps", "verb": "String the bow drill",
		"how": "Click each end of the bow to tie the string, then loop it around the drill."},

	# Made at a workbench with a tool hanging on its rack.
	{"out": "soup_pot_unfired", "n": 1, "in": {"clay": 10, "board": 3}, "where": "swamp", "tier": "bench", "rack": "clay_platter", "listed": true,
		"cat": "Containers", "act": "steps", "steps": 8, "verb": "Build a soup pot",
		"how": "Click around the rim to coil the clay up into a big pot on the platter, then pin three boards together into a tripod to hang it from. It is left beside the bench: carry it to a lit campfire to fire it."},
	{"out": "vessel_open_unfired", "n": 1, "in": {"clay": 8}, "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Containers", "act": "steps", "steps": 6, "verb": "Coil an open vessel",
		"how": "Click around the rim to coil a big wide-mouthed crock up on the platter. It is left beside the bench: set it in a lit campfire to fire it."},
	{"out": "vessel_sealed_unfired", "n": 1, "in": {"clay": 10}, "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Containers", "act": "steps", "steps": 7, "verb": "Coil a sealed vessel",
		"how": "Click around the rim to coil a big jar with a narrow neck up on the platter, then press out a lid to fit it. It is left beside the bench: set it in a lit campfire to fire it."},
	{"out": "wooden_cap", "n": 4, "in": {"board": 1}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools",
		"cat": "Containers", "act": "steps", "steps": 4, "verb": "Carve wooden caps",
		"how": "Click the glowing spots to saw four rounds from the board and carve each into a cap with a lip that fits a clay pot's mouth."},
	{"out": "canteen", "n": 1, "in": {"board": 1, "wax": 2, "cordage": 1}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools",
		"cat": "Containers", "act": "steps", "steps": 6, "verb": "Carve a canteen",
		"how": "Click the glowing spots to cut a jointed length, hollow it out, seal the inside with wax, carve and fit a wooden lid, then tie on a cord."},
	# `rack_or_bag`: the rack tool may hang on the bench or be in your bag.
	{"out": "string", "n": 1, "in": {"plant_fiber": 3}, "where": "swamp", "tier": "bench", "rack": "spindle", "rack_or_bag": true,
		"cat": "Materials", "act": "twist", "verb": "Spin string",
		"how": "Hold the left mouse button and drag to keep the spindle turning as you draw the fiber out into a fine, even string."},
	{"out": "compost_basket", "n": 1, "in": {"board": 4, "stick": 6, "cordage": 2}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools", "listed": true,
		"cat": "Farming", "act": "steps", "steps": 6, "verb": "Build a compost basket",
		"how": "Click the glowing spots to set up four stick posts, then saw the boards into slats and lash them round, course by course."},
	{"out": "baitbox", "n": 1, "in": {"board": 1, "any_raw_meat": 2}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools", "listed": true,
		"cat": "Traps", "act": "steps", "steps": 4, "verb": "Make a baitbox",
		"how": "Click the glowing spots to saw the board into a base and four sides, pin them into a little open box, then pack the meat in. Throw it (Use) into the water to send the big amphibians nearby into a feeding frenzy."},
	{"out": "fish_trap", "n": 1, "in": {"stick": 10, "cordage": 3}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools", "listed": true,
		"cat": "Traps", "act": "steps", "steps": 6, "verb": "Make a fish trap",
		"how": "Click the glowing spots to saw the sticks to length, bend hoops, lash the long ribs round them and set the funnel in the mouth. It is left beside the bench: carry it to shallow water, set it down and bait it (C)."},
	{"out": "rod_blank", "n": 1, "in": {"branch": 1}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools", "listed": true,
		"cat": "Fishing", "act": "steps", "steps": 4, "verb": "Shape a rod blank",
		"how": "Click along the branch to saw off the side shoots, then chisel and scrape it into a long, even taper."},
	{"out": "papermaking_tools", "n": 1, "in": {"clay_bowl": 1, "stick": 4, "plant_fiber": 6, "cordage": 1}, "where": "swamp", "tier": "bench",
		"cat": "Workbench", "act": "steps", "steps": 6, "verb": "Make a papermaking screen",
		"how": "Click the corners to lash a frame of sticks, then weave fine fiber across it. The screen goes with the bowl, ready to hang on the rack."},
	{"out": "paper_wet", "n": 1, "in": {"plant_fiber": 6, "pot_dirty": 1}, "where": "swamp", "tier": "bench", "rack": "papermaking_tools",
		"cat": "Writing", "act": "steps", "steps": 5, "verb": "Make a sheet of paper",
		"how": "Click the bowl to mash the fiber with a pot of water (swamp or boiled) into a fine pulp, then dip the screen and lift a sheet. You keep the empty pot. Dry the wet sheet in a campfire."},
	{"out": "pencil_core_unfired", "n": 1, "in": {"ash": 1, "clay": 1}, "where": "swamp", "tier": "bench", "rack": "papermaking_tools",
		"cat": "Writing", "act": "steps", "steps": 3, "verb": "Roll a pencil core",
		"how": "Click to knead the ash into the clay and roll it out into a thin rod. Fire it in a campfire to harden it."},
	{"out": "ash_pencil", "n": 1, "in": {"pencil_core": 1, "stick": 1, "cordage": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "papermaking_tools",
		"cat": "Writing", "act": "steps", "steps": 4, "verb": "Make an ash pencil",
		"how": "Click the glowing spots to split the stick in half with a blade, lay the fired core in the groove, close the halves over it and bind them with cord."},
	# `wear`: the tool worn by one use at each of the `sharpen` steps.
	{"out": "blueprint_softwood_house", "n": 1, "in": {"paper_sheet": 1}, "tools": {"ash_pencil": 1}, "tool_tag": "cut", "wear": "ash_pencil", "sharpen": [0, 5],
		"where": "swamp", "tier": "bench", "cat": "Blueprints", "act": "steps", "steps": 10, "verb": "Draw a softwood house blueprint",
		"how": "Click the glowing spots to draw the house on the sheet: its stilts and floor, the walls with their windows and doorway, the porch, the fireplace and the roof. Sharpen the pencil with your blade before you start and again halfway (each wears one use off it)."},
	# `bait`: any bait will do, not just the meat bait named in `in` (for the
	# book). The work spot offers one of these per bait laid out beside an
	# unbaited rod (work_spot.bait_options), by hand or at a bench.
	{"out": "fishing_rod", "n": 1, "in": {"fishing_rod": 1, "meat_bait": 1}, "bait": true, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 1, "verb": "Bait the rod",
		"how": "Lay an unbaited fishing rod out with any bait (meat bait, beetle grubs, rotten food or guts), on the ground or at a workbench, and click the hook to bait it. A fish that bites takes the bait, whether you land it or not."},

	# --- Boats (boats.md) ---
	{"out": "blueprint_dock", "n": 1, "in": {"paper_sheet": 1}, "tools": {"ash_pencil": 1}, "tool_tag": "cut", "wear": "ash_pencil", "sharpen": [0, 5],
		"where": "swamp", "tier": "bench", "cat": "Blueprints", "act": "steps", "steps": 10, "verb": "Draw a dock blueprint",
		"how": "Click the glowing spots to draw the dock on the sheet: the land post and the piles, the spikes round them, the stringers and deck, the slipway and the mooring post. Sharpen the pencil with your blade before you start and again halfway (each wears one use off it)."},
	{"out": "copper_shod_pole", "n": 1, "in": {"calamites_pole": 1, "copper_pole_shoe": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 3, "verb": "Shoe the pole with copper",
		"how": "Click to pare the tip of the pole down, fit the copper shoe over it and pin it on."},
	{"out": "iron_shod_pole", "n": 1, "in": {"calamites_pole": 1, "iron_pole_shoe": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 3, "verb": "Shoe the pole with iron",
		"how": "Click to pare the tip of the pole down, fit the iron shoe over it and pin it on."},

	# --- Metals (metals.md) ---
	# `at`: made only where you kneel at that: a furnace, an anvil, a meteorite,
	# or looking at the water ("water"). `whetstone`: the anvil needs one seated.
	# `tool_tags`: tools with each of these tags, kept. `tool_why` replaces the
	# missing-tool text. `melt`: steps from..to (not including) only count with
	# the furnace at full heat. `step_how`: the how, step by step. `give`: given
	# back as well. `hammer_wear`: each step wears a copper hammer (not an iron
	# one). `fast_tool`: half the steps with that tool. `anvil_steps`: quicker
	# kneeling at an anvil. `cast`: copper has been cast (the next meteor shower
	# drops a meteorite).
	{"out": "charcoal_clamp", "n": 1, "in": {"firewood": 10, "clay": 4}, "tool_tag": "dig", "build": "clamp", "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 8, "verb": "Build a charcoal clamp",
		"label": "A charcoal clamp, built where you kneel",
		"how": "Click the glowing spots to dig a shallow pit, stack the firewood in it on end and cover it over with wet clay. Then light it with an ember or a lit torch: about a day later, break it open for charcoal."},
	{"out": "furnace", "n": 1, "in": {"stone": 8}, "tool_tag": "dig", "build": "furnace", "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Lay a furnace's stone ring",
		"label": "The stone ring of a clay furnace, built where you kneel",
		"how": "Click the glowing spots to dig a shallow hole and set the river stones round it. Then build the rest of the furnace on it (E): its clay shaft, tuyere, first firing and blowpipes."},
	{"out": "whetstone", "n": 1, "in": {"stone": 2, "pot_dirty": 1}, "give": {"stone": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 8, "verb": "Grind a whetstone",
		"label": "Whetstone (one river stone is kept, the pot left empty)",
		"how": "Click to grind one river stone flat against the other, pouring on water as you go."},
	{"out": "smashed_native_copper", "n": 1, "in": {"native_copper": 1}, "tools": {"stone": 1}, "anvil_steps": 2, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Smash native copper",
		"how": "Click to beat the lump to grit with a river stone, freeing the copper threads (quicker on an anvil)."},
	{"out": "crushed_copper_ore", "n": 1, "in": {"copper_ore": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (too hard for a river stone)", "anvil_steps": 2, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Crush copper ore",
		"how": "Click to crush the malachite to grit with the hammer (quicker on an anvil)."},
	{"out": "copper_grains", "n": 1, "in": {"smashed_native_copper": 1}, "tools": {"washing_pan": 1}, "at": "water", "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Wash out copper grains",
		"step_how": ["Click to scoop water into the pan over the grit.", "Click to swirl it round.", "Click to tip it and pour the light grit off.", "Click to swirl it again.", "Click to pick the copper grains out of the bottom."],
		"how": "At the water's edge, scoop water into the pan, swirl it and pour off the light grit until only the heavy copper is left."},
	{"out": "sifted_copper_ore", "n": 1, "in": {"crushed_copper_ore": 2}, "tools": {"washing_pan": 1}, "at": "water", "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 6, "verb": "Wash crushed ore",
		"step_how": ["Click to scoop water into the pan over the grit.", "Click to swirl it round.", "Click to tip it and pour the light grit off.", "Click to scoop more water in.", "Click to swirl and pour off again.", "Click to pick out the heavy green ore."],
		"how": "At the water's edge, scoop water into the pan, swirl it and pour off the light grit until only the heavy ore is left. It weighs half what went in."},
	{"out": "washing_pan_unfired", "n": 1, "in": {"clay": 4, "ash": 1}, "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Shape a washing pan",
		"how": "Click around the rim to knead the ash into the clay and press it out into a wide, shallow pan on the platter. Fire it in a campfire."},
	{"out": "tuyere_unfired", "n": 1, "in": {"clay": 2}, "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 3, "verb": "Roll a tuyere",
		"how": "Click to roll the clay round a stick into a thick tube, then draw the stick out. Fire it in a campfire."},
	{"out": "blowpipe_unfired", "n": 1, "in": {"calamites_shoot": 1, "clay": 1}, "where": "swamp", "tier": "bench", "rack": "woodworking_tools",
		"cat": "Metal", "act": "steps", "steps": 3, "verb": "Make a blowpipe",
		"how": "Click to saw the shoot square, push out the pith at its joints and mould a clay tip onto one end. Fire it in a campfire."},
	{"out": "fishing_rod_copper", "n": 1, "in": {"rod_blank": 1, "fishing_line": 1, "copper_fishhook": 1}, "where": "swamp", "tier": "bench",
		"cat": "Fishing", "act": "steps", "steps": 3, "verb": "Rig a rod with a copper hook",
		"how": "Click to tie the line to the tip of the rod, run it down the rod, then tie on the copper hook."},
	{"out": "fishing_rod_copper", "n": 1, "in": {"fishing_rod": 1, "copper_fishhook": 1}, "give": {"chitin_hook": 1}, "where": "swamp", "tier": "hand",
		"cat": "Fishing", "act": "steps", "steps": 2, "verb": "Swap on a copper hook",
		"label": "Fishing Rod (copper hook), and the chitin hook back",
		"how": "Click to cut the chitin hook off the line and tie on the copper one."},
	{"out": "mould_axe_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a axe mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for an axe head with your blade. Fire it in a campfire."},
	{"out": "rough_copper_axe_head", "n": 1, "in": {"copper": 3, "charcoal": 1}, "tools": {"mould_axe": 1}, "wear": "mould_axe", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast an axe head",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_knife_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a knife mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for a knife blade with your blade. Fire it in a campfire."},
	{"out": "rough_copper_knife_blade", "n": 1, "in": {"copper": 2, "charcoal": 1}, "tools": {"mould_knife": 1}, "wear": "mould_knife", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast a knife blade",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_spear_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a spear mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for a spear head with your blade. Fire it in a campfire."},
	{"out": "rough_copper_spear_head", "n": 1, "in": {"copper": 2, "charcoal": 1}, "tools": {"mould_spear": 1}, "wear": "mould_spear", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast a spear head",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_hammer_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a hammer mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for a hammer head with your blade. Fire it in a campfire."},
	{"out": "copper_hammer_head", "n": 1, "in": {"copper": 2, "charcoal": 1}, "tools": {"mould_hammer": 1}, "wear": "mould_hammer", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast a hammer head",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_saw_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a saw mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for a saw blade with your blade. Fire it in a campfire."},
	{"out": "rough_copper_saw_blade", "n": 1, "in": {"copper": 3, "charcoal": 1}, "tools": {"mould_saw": 1}, "wear": "mould_saw", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast a saw blade",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_bar_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a bar mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for a bar with your blade. Fire it in a campfire."},
	{"out": "copper_bar", "n": 1, "in": {"copper": 1, "charcoal": 1}, "tools": {"mould_bar": 1}, "wear": "mould_bar", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast a bar",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_hook_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a hook mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for three fishhooks with your blade. Fire it in a campfire."},
	{"out": "copper_fishhook", "n": 3, "in": {"copper": 1, "charcoal": 1}, "tools": {"mould_hook": 1}, "wear": "mould_hook", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast three fishhooks",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "mould_beads_unfired", "n": 1, "in": {"clay": 3, "ash": 1}, "tool_tag": "cut", "where": "swamp", "tier": "bench", "rack": "clay_platter",
		"cat": "Metal", "act": "steps", "steps": 4, "verb": "Press a beads mould",
		"how": "Click to knead the ash into the clay, press it into a thick slab on the platter and cut the hollow for beads with your blade. Fire it in a campfire."},
	{"out": "copper_beads", "n": 1, "in": {"copper": 1, "charcoal": 1}, "tools": {"mould_beads": 1}, "wear": "mould_beads", "sharpen": [0], "cast": true, "melt": [3, 8], "at": "furnace",
		"where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Cast beads",
		"wear_how": "Click to fill the mould with copper (each casting wears it: it cracks after 5).",
		"step_how": ["Click to fill the mould with copper.", "Click to bed the mould down in the charcoal.", "Click to blow the furnace up to heat.", "Blow: keep the furnace at full heat (orange) while the copper melts.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Blow: keep it at full heat.", "Click to rake the mould out with a stick and let it cool.", "Click to break the casting out."],
		"how": "Fill the mould with copper, bed it in the charcoal, blow the furnace up to full heat and hold it there until the copper melts into the shape, then rake it out and break the casting out."},
	{"out": "unrefined_copper", "n": 1, "in": {"sifted_copper_ore": 2, "charcoal": 2}, "melt": [2, 13], "at": "furnace", "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 15, "verb": "Smelt copper",
		"step_how": ["Click to load the furnace with ore and charcoal in layers.", "Click to blow it up to heat.", "Blow: hold it at full heat (orange) while the ore smelts.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Blow: hold it at full heat.", "Click to rake out the slag.", "Click to pick the drops of copper out of it."],
		"how": "Load the furnace with ore and charcoal, blow it at full heat for a long stretch, then rake out the slag and pick the copper out of it."},
	{"out": "copper_axe_head", "n": 1, "in": {"rough_copper_axe_head": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the axe head",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the axe head sharp on the anvil's whetstone."},
	{"out": "copper_knife_blade", "n": 1, "in": {"rough_copper_knife_blade": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the knife blade",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the knife blade sharp on the anvil's whetstone."},
	{"out": "copper_spear_head", "n": 1, "in": {"rough_copper_spear_head": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the spear head",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the spear head sharp on the anvil's whetstone."},
	{"out": "copper_saw_blade", "n": 1, "in": {"rough_copper_saw_blade": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the saw's teeth",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the saw's teeth sharp on the anvil's whetstone."},
	{"out": "copper_chisel", "n": 1, "in": {"copper_bar": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the bar into a chisel",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the bar into a chisel sharp on the anvil's whetstone."},
	{"out": "copper_pole_shoe", "n": 1, "in": {"copper_bar": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the bar into a pole shoe",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the bar into a pole shoe sharp on the anvil's whetstone."},
	{"out": "flask", "n": 1, "in": {"copper_bar": 2, "wax": 1, "cordage": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer to raise the copper",
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 8, "verb": "Raise a copper flask",
		"step_how": ["Click to beat the first bar out flat.", "Click to beat the second bar out flat.", "Click to raise the first sheet into a shallow bowl.", "Click to raise the second into its match.", "Click to fold and hammer the two rims together into a tight seam.", "Click to draw out a neck at the top.", "Click to wax the seam and the inside.", "Click to whittle a stopper and tie it on with the cord."],
		"how": "Beat two copper bars out into sheets on the anvil, raise each into a shallow bowl, hammer their rims together into a seam, draw out a neck, wax it watertight and tie on a stopper."},
	{"out": "soup_pot_copper", "n": 1, "in": {"copper_bar": 5, "board": 3, "cordage": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer to raise the copper",
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 12, "verb": "Raise a copper soup pot",
		"how": "Beat the copper bars out flat and rivet them into one big sheet, raise it round and round on the anvil into a deep pot, roll the rim over, then pin three boards into a tripod and hang the pot from it by the cord. It is left beside the anvil."},
	{"out": "iron_axe_head", "n": 1, "in": {"rough_iron_axe_head": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the axe head",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the axe head sharp on the anvil's whetstone."},
	{"out": "iron_knife_blade", "n": 1, "in": {"rough_iron_knife_blade": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the knife blade",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the knife blade sharp on the anvil's whetstone."},
	{"out": "iron_spear_head", "n": 1, "in": {"rough_iron_spear_head": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the spear head",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the spear head sharp on the anvil's whetstone."},
	{"out": "iron_mattock_head", "n": 1, "in": {"rough_iron_mattock_head": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the mattock head",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the mattock head sharp on the anvil's whetstone."},
	{"out": "iron_chisel", "n": 1, "in": {"rough_iron_chisel": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the chisel",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the chisel sharp on the anvil's whetstone."},
	{"out": "iron_pole_shoe", "n": 1, "in": {"rough_iron_pole_shoe": 1}, "at": "anvil", "whetstone": true, "where": "swamp", "tier": "metal",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Grind the pole shoe",
		"step_how": ["Click to wet the whetstone.", "Click to draw the edge along the stone.", "Click to draw it along again.", "Click to turn it and grind the other side.", "Click to hone the edge fine."],
		"how": "Grind the pole shoe sharp on the anvil's whetstone."},
	{"out": "copper_axe", "n": 1, "in": {"copper_axe_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the copper axe",
		"how": "Click the binding again and again to lash the head to the handle."},
	{"out": "copper_mattock", "n": 1, "in": {"copper_axe_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft a copper mattock",
		"how": "Click the binding again and again to lash the head crosswise to the handle."},
	{"out": "copper_knife", "n": 1, "in": {"copper_knife_blade": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the copper knife",
		"how": "Click the binding again and again to lash the blade into its handle."},
	{"out": "copper_spear", "n": 1, "in": {"copper_spear_head": 1, "stick": 2, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the copper spear",
		"how": "Click the binding again and again to lash the point to the shaft."},
	{"out": "copper_saw", "n": 1, "in": {"copper_saw_blade": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the copper saw",
		"how": "Click the binding again and again to lash the blade into its handle."},
	{"out": "copper_hammer", "n": 1, "in": {"copper_hammer_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the copper hammer",
		"how": "Click the binding again and again to lash the head to the handle."},
	{"out": "iron_axe", "n": 1, "in": {"iron_axe_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the iron axe",
		"how": "Click the binding again and again to lash the head to the handle."},
	{"out": "iron_knife", "n": 1, "in": {"iron_knife_blade": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the iron knife",
		"how": "Click the binding again and again to lash the blade into its handle."},
	{"out": "iron_spear", "n": 1, "in": {"iron_spear_head": 1, "stick": 2, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the iron spear",
		"how": "Click the binding again and again to lash the point to the shaft."},
	{"out": "iron_mattock", "n": 1, "in": {"iron_mattock_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the iron mattock",
		"how": "Click the binding again and again to lash the head crosswise to the handle."},
	{"out": "iron_hammer", "n": 1, "in": {"iron_hammer_head": 1, "stick": 1, "cordage": 1}, "where": "swamp", "tier": "hand",
		"cat": "Metal", "act": "steps", "steps": 5, "verb": "Haft the iron hammer",
		"how": "Click the binding again and again to lash the head to the handle."},
	{"out": "meteoric_iron", "n": 1, "in": {}, "tool_tags": ["chisel", "hammer"], "tool_why": "a copper chisel and a copper hammer (too hard to break with stone)", "fast_tool": "iron_chisel", "hammer_wear": true,
		"at": "meteorite", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 12, "verb": "Chip off a lump of iron",
		"how": "Click the glowing spots to set the chisel and strike it with the hammer, cutting a small lump off the meteorite."},
	{"out": "meteoric_iron_large", "n": 1, "in": {}, "tool_tags": ["chisel", "hammer"], "tool_why": "a copper chisel and a copper hammer (too hard to break with stone)", "fast_tool": "iron_chisel", "hammer_wear": true,
		"at": "meteorite", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 24, "verb": "Chip off a large lump of iron",
		"how": "Click the glowing spots to set the chisel and strike it with the hammer, cutting a big lump off the meteorite."},
	{"out": "refined_iron", "n": 1, "in": {"meteoric_iron": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Refine the iron",
		"how": "Click to beat the lump on the anvil, knocking off the rusty crust and the stone caught in it, and flatten it into clean iron."},
	{"out": "refined_iron_bar", "n": 1, "in": {"meteoric_iron_large": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 20, "verb": "Refine an iron bar",
		"how": "Click to beat the big lump on the anvil, knocking off the rusty crust and the stone caught in it, and draw it out into a clean bar."},
	{"out": "rough_iron_knife_blade", "n": 1, "in": {"refined_iron": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 15, "verb": "Hammer out a knife blade",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
	{"out": "rough_iron_chisel", "n": 1, "in": {"refined_iron": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 12, "verb": "Hammer out a chisel",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
	{"out": "rough_iron_pole_shoe", "n": 1, "in": {"refined_iron": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 10, "verb": "Hammer out a pole shoe",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
	{"out": "rough_iron_axe_head", "n": 1, "in": {"refined_iron_bar": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 30, "verb": "Hammer out an axe head",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
	{"out": "rough_iron_spear_head", "n": 1, "in": {"refined_iron_bar": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 24, "verb": "Hammer out a spear head",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
	{"out": "rough_iron_mattock_head", "n": 1, "in": {"refined_iron_bar": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 26, "verb": "Hammer out a mattock head",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
	{"out": "iron_hammer_head", "n": 1, "in": {"refined_iron_bar": 1}, "tool_tag": "hammer", "tool_why": "a copper hammer (stone just bounces off iron)", "fast_tool": "iron_hammer", "hammer_wear": true,
		"at": "anvil", "where": "swamp", "tier": "metal", "cat": "Metal", "act": "steps", "steps": 24, "verb": "Hammer out a hammer head",
		"how": "Click the glowing spots to strike the cold iron, moving round the piece: drawing out the edge, spreading the blade. Cold iron moves slowly."},
]

## Butchering a medium or large carcass where it lies (see work_spot.gd), one
## stage after another. Every stage needs a blade (a tool tagged "cut"). The
## guts and the skin go on a guts pile beside the carcass; an arthropod's
## shell comes off as chitin. Cutting takes one step per piece of raw meat.
const BUTCHERING := {
	"whole": {"butcher": "gut", "out": "guts", "n": 1, "in": {}, "act": "steps", "steps": 4,
		"verb": "Gut the carcass", "label": "Guts, left in a pile beside it",
		"how": "Click along the belly to slit it open and haul out the guts."},
	"gutted": {"butcher": "skin", "out": "chitin", "n": 1, "in": {}, "act": "steps", "steps": 4,
		"verb": "Skin the carcass", "label": "The skin, thrown on the guts pile",
		"how": "Click along the body to cut the skin away."},
	"skinned": {"butcher": "cut", "out": "raw_meat", "n": 1, "in": {}, "act": "steps",
		"verb": "Cut it into meat", "label": "Raw Meat",
		"how": "Click each glowing spot to cut off a piece of raw meat."},
}

## Woodcutting with an axe (a tool tagged "chop"), done where the wood lies
## (see work_spot.gd): felling a standing tree, cutting a felled one into 2 m
## logs, and working a log. `wood` names the job, `on` what it is done to
## ("tree", "felled" or a log's item id), and `give` what goes into the bag.
## Logs cut off and short logs are left lying beside the work.
const WOODWORK := [
	{"wood": "fell", "on": "tree", "out": "", "n": 0, "in": {}, "act": "steps",
		"verb": "Fell the tree", "label": "It falls in one piece, leaving a stump",
		"how": "Click the glowing notch again and again to chop into the trunk. It falls away from you."},
	{"wood": "buck", "on": "felled", "out": "log", "n": 1, "in": {}, "act": "steps", "steps": 3,
		"verb": "Cut off a log", "label": "Log (2 m), left lying beside the trunk",
		"how": "Click the glowing mark to chop through the trunk 2 m along."},
	{"wood": "strip", "on": "log", "out": "log_stripped", "n": 1, "in": {}, "act": "steps", "steps": 4,
		"give": {"bark": 6, "branch": 3}, "verb": "Strip the log", "label": "Bark x6, Branch x3",
		"how": "Click along the log to lop off the branch stubs and peel the bark away."},
	{"wood": "shorten", "on": "log", "out": "short_log", "n": 4, "in": {}, "act": "steps", "steps": 6,
		"verb": "Cut into short logs", "label": "Short Log x4, left lying beside it",
		"how": "Click each glowing mark to chop through the log."},
	{"wood": "hew", "on": "log_stripped", "out": "board", "n": 2, "in": {}, "act": "steps", "steps": 6,
		"give": {"board": 4}, "verb": "Hew into boards", "label": "Board x4, in the colour of the wood",
		"how": "Click along the log to split it down the middle and hew each half flat."},
	{"wood": "split", "on": "short_log", "out": "firewood", "n": 4, "in": {}, "act": "steps", "steps": 3,
		"give": {"firewood": 4}, "verb": "Split into firewood", "label": "Firewood x4",
		"how": "Click the top of the round to split it, then split the halves."},
	# Calamites is jointed and hollow like bamboo: a stripped trunk splits
	# into two poles (only Calamites: work_spot.wood_options).
	{"wood": "poles", "on": "log_stripped", "out": "calamites_pole", "n": 2, "in": {}, "act": "steps", "steps": 4,
		"give": {"calamites_pole": 2}, "verb": "Split into poles", "label": "Calamites Pole x2",
		"how": "Click along the trunk to split it down its length into two long poles."},
	# A saw (a tool tagged "saw") takes any log straight to boards, hardwood
	# too, with the bark and branches if it wasn't stripped.
	{"wood": "saw", "on": "log", "out": "board", "n": 5, "in": {}, "act": "steps", "steps": 8, "saw": true,
		"give": {"board": 5, "bark": 6, "branch": 3}, "verb": "Saw into boards", "label": "Board x5, in the colour of the wood, Bark x6, Branch x3",
		"how": "Click along the log to lop off the branches and saw it lengthwise into boards."},
	{"wood": "saw", "on": "log_stripped", "out": "board", "n": 5, "in": {}, "act": "steps", "steps": 6, "saw": true,
		"give": {"board": 5}, "verb": "Saw into boards", "label": "Board x5, in the colour of the wood",
		"how": "Click along the log to saw it lengthwise into boards."},
]

## Knapping: 5x5 grid, '#' = stone that must remain, '.' = stone to knock off.
## Patterns may also be matched mirrored left-to-right.
const KNAPPING := {
	"flint_blade": [
		"...#.",
		"..##.",
		".###.",
		".##..",
		".#...",
	],
	"axe_head": [
		".###.",
		"#####",
		"#####",
		".###.",
		"..#..",
	],
	"spear_head": [
		"..#..",
		".###.",
		".###.",
		".###.",
		"..#..",
	],
	"mattock_head": [
		"####.",
		".###.",
		"..##.",
		"..##.",
		"...#.",
	],
	# Knapped from chitin with a blade (KNAP_MATERIAL), not chert: a J with a
	# barb at the point.
	"chitin_hook": [
		"...#.",
		"...#.",
		"#..#.",
		"##.#.",
		".##..",
	],
}
## What each pattern is knapped from (chert, "flint", unless listed). Striking
## a chitin plate can only ever come out as a chitin pattern, and chert as chert.
const KNAP_MATERIAL := {"chitin_hook": "chitin"}


## Food cured in a fermentation vessel (ferment_vessel.gd) is that food with
## a prefix: "pickled:raw_meat", "spirit:roast_seed", "salted:cooked_meat".
## Its definition is the food's own, renamed, its nutrients times `boost`,
## keeping twice as long, with `alcohol` (a drink's worth when eaten) or less
## water (salt makes you thirsty). `extra` nutrients are added on top, after
## the boost (pickling and brewing add a little greens and starch).
const CURES := {
	"pickled": {"name": "Pickled %s", "boost": 1.1, "extra": {"greens": 3.0, "starch": 3.0}, "tint": Color(0.82, 0.95, 0.62),
		"note": "Pickled: a little more nourishing, with a little greens and starch, and keeps twice as long."},
	"spirit": {"name": "Alcohol-Preserved %s", "boost": 1.1, "extra": {"greens": 3.0, "starch": 3.0}, "tint": Color(1.0, 0.8, 0.55), "alcohol": 1.0,
		"note": "Preserved in alcohol: a little more nourishing, with a little greens and starch, keeps twice as long, and counts as a drink."},
	"salted": {"name": "Salted %s", "boost": 1.0, "tint": Color(1.08, 1.06, 1.0), "thirst": 6.0,
		"note": "Salted: keeps twice as long, but makes you thirsty."},
}

var _cured := {}


func def(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	return _cured_def(id)


func exists(id: String) -> bool:
	return ITEMS.has(id) or not _cured_def(id).is_empty()


func cure_of(id: String) -> String:
	## "pickled", "spirit", "salted", or "" for an item that isn't cured.
	var k := id.find(":")
	return id.substr(0, k) if k > 0 and CURES.has(id.substr(0, k)) else ""


func base_of(id: String) -> String:
	## The food a cured item was made from (or the item itself).
	return id.substr(id.find(":") + 1) if cure_of(id) != "" else id


func can_cure(id: String) -> bool:
	## Food that can go in a fermentation vessel: not a drink in a pot or
	## canteen (water, soup, alcohol), not already cured, not rotten.
	return ITEMS.has(id) and is_food(id) and not is_drink_container(id) and id != "rotten" and id != "charred"


func is_drink_container(id: String) -> bool:
	## A pot or canteen with something in it: drunk from, never food itself.
	var d: Dictionary = def(id)
	return d.has("empty") or d.has("measures") or d.get("shape", "") in ["pot_water", "canteen", "flask"]


func _cured_def(id: String) -> Dictionary:
	if _cured.has(id):
		return _cured[id]
	var cure := cure_of(id)
	var base := base_of(id)
	if cure == "" or not can_cure(base):
		return {}
	var c: Dictionary = CURES[cure]
	var d: Dictionary = ITEMS[base].duplicate()
	d.name = c.name % d.name
	d.desc = "%s %s" % [d.get("desc", ""), c.note]
	for k in ["energy", "protein", "greens", "starch"]:
		if d.has(k):
			d[k] = snappedf(d[k] * c.boost, 0.1)
	for k in c.get("extra", {}):
		d[k] = snappedf(d.get(k, 0.0) + c.extra[k], 0.1)
	if d.has("decay"):
		d.decay = d.decay * 2.0
	if c.has("alcohol"):
		d.alcohol = c.alcohol
	if c.has("thirst"):
		d.water = d.get("water", 0.0) - c.thirst
	d.color = (d.color as Color) * (c.tint as Color)
	d.cure = cure
	d.base = base
	_cured[id] = d
	return d


func measures_data(id: String, left: int) -> Dictionary:
	## Slot data for an item drunk a measure at a time (a canteen of alcohol).
	return {"left": left, "name": "%s (%d/%d)" % [ITEMS[id].name, left, ITEMS[id].measures]}


func bait_data(bait: String, rod := "fishing_rod") -> Dictionary:
	## Slot data for a fishing rod baited with `bait`.
	if rod == "fishing_rod_copper":
		return {"bait": bait, "name": "Fishing Rod (copper hook, %s)" % item_name(bait).to_lower()}
	return {"bait": bait, "name": "Fishing Rod (%s)" % item_name(bait)}


func edge_data(id: String, left: int, keep := {}) -> Dictionary:
	## Slot data for a metal tool with `left` uses on its edge (`edge`), over
	## what else its slot keeps: at 0 it is blunt, and says so.
	var d := keep.duplicate()
	d.edge_left = left
	if left <= 0:
		d.name = "%s (blunt)" % ITEMS[id].name
	else:
		d.erase("name")
	return d


func uses_data(id: String, left: int) -> Dictionary:
	## Slot data for a tool that wears out a use at a time (an ash pencil).
	return {"uses_left": left, "name": "%s (%d/%d)" % [ITEMS[id].name, left, ITEMS[id].uses]}


func item_name(id: String) -> String:
	return def(id).get("name", id)


const UNLIMITED := 1 << 30


func max_stack(_id: String) -> int:
	## Stacks have no size limit: what you can carry is governed by weight.
	## (An item's old "stack" field is no longer read.) Items with data of
	## their own, a worn tool or a pot of soup, still keep a slot each.
	return UNLIMITED


func weight(id: String) -> float:
	return def(id).get("w", 0.2)


func slot_weight(s: Dictionary) -> float:
	## One of a slot's items: its own data's weight (a filled preserving pot)
	## over the item's.
	var d: Dictionary = s.get("data", {})
	return float(d.w) if d.has("w") else weight(s.id)


func counts_as(id: String, want: String) -> bool:
	## Whether `id` will do in a recipe that wants `want` (itself, or an item
	## with `as` set to it, like any tree's board for "board").
	return id == want or def(id).get("as", "") == want


func woodwork(on: String) -> Array:
	## The woodcutting jobs that can be done to a tree, a felled tree or a log.
	return WOODWORK.filter(func(r): return r.on == on)


func is_food(id: String) -> bool:
	var d: Dictionary = def(id)
	return d.has("energy") or d.has("water")


func recipes_for(where: String, tiers: Array = TIERS) -> Array:
	return RECIPES.filter(func(r): return r.where == where and r.tier in tiers)


func recipe_for(out: String, where := "") -> Dictionary:
	for r in RECIPES:
		if r.out == out and (where == "" or r.where == where):
			return r
	return {}


func recipe_steps(r: Dictionary) -> int:
	## How many hands-on steps a "steps" recipe takes.
	if r.has("steps"):
		return r.steps
	match r.out:
		"beam_segment":
			return 2
		"injector":
			return 3
		"stone_axe", "mattock":
			return 5
		"wax":
			return 4
		"spear":
			return 6
		"bow_drill":
			return 3
		"campfire_kit":
			return 8
		"clay_pot":
			return 5
		"bandage":
			return 5
		"fiber_sack", "cloth_sack":
			return 8
	return 4 if r.get("dress", false) else 3


func knap_grid(id: String) -> Array:
	## A knapping pattern as 25 bools (row-major), or a full nodule for "".
	var rows: Array = KNAPPING.get(id, [])
	var grid := []
	for k in 25:
		grid.append(rows.is_empty() or rows[k / 5][k % 5] == "#")
	return grid


func knap_material(id: String) -> String:
	## The item a knapping pattern is struck from.
	return KNAP_MATERIAL.get(id, "flint")


func knap_matches(grid: Array, material := "") -> String:
	## Returns the knapping result id whose pattern exactly equals `grid`
	## (an Array of 25 bools, row-major), or "" when nothing matches. With a
	## `material`, only patterns knapped from it count.
	for id in KNAPPING:
		if material != "" and knap_material(id) != material:
			continue
		var rows: Array = KNAPPING[id]
		var plain := true
		var mirrored := true
		for y in 5:
			for x in 5:
				var cell: bool = grid[y * 5 + x]
				if (rows[y][x] == "#") != cell:
					plain = false
				if (rows[y][4 - x] == "#") != cell:
					mirrored = false
		if plain or mirrored:
			return id
	return ""
