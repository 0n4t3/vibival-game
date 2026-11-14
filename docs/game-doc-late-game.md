# Vibival game doc: late game (boats and metals)

> **Late game.** This page covers what the `late-game` branch adds on top of
> the main game. Everything in [game-doc.md](game-doc.md) still applies;
> where the late game changes a main-game rule, the change is listed under
> [Changes to main-game rules](#changes-to-main-game-rules). The player's
> side is in [late-game.md](late-game.md), and the design notes are
> [boats.md](../boats.md) and [metals.md](../metals.md).

## Layout

| File | What it is |
|---|---|
| `src/world/site.gd` | Base for anything built in place part by part like a house: the outline of parts still to come, steps clicked on the thing itself (`work_spot` treats it as its `house`), `TEARDOWN_HITS` (3) axe or mattock blows tear an unfinished one down within `HIT_WINDOW` (4 s). Subclasses give `parts()`, `_pieces`, `_shapes`, and hook `_on_part` / `_on_complete` |
| `src/world/dock.gd` | A dock (group "docks", `Game.docks`) from a Dock Blueprint |
| `src/world/raft.gd` | A raft (group "rafts", `Game.rafts`) built on a finished dock's slipway |
| `src/world/furnace.gd` | The clay furnace (group "furnaces"): casting and smelting, station "furnace" |
| `src/world/clamp.gd` | The charcoal clamp (group "clamps") |
| `src/world/heavy_stone.gd` | Things hauled like a log: anvil stones (group "anvils", station "boulder" while rough, then "anvil"; shaped in `stage`s) and meteorites (group "meteorites", station "meteorite") |
| `src/world/crater.gd` | Where a meteorite came down (group "craters"), smoking for `LIFE` (a day) |
| `src/world/outcrop.gd` | A copper outcrop on an island |

`terrain.gd` makes the islands; `swamp.gd` places and saves all of the
above; `weather.gd` has the meteor changes; `inventory.gd` has tool wear;
`work_spot.gd` has the stations, casting, sharpening and the paced steps.

## Docks (`dock.gd`, `swamp.dock_spot`, `swamp.dock_blocker`)

Local space: y = 0 is the deck top, the land end at z = 0, the dock runs
out along −Z; the slipway and berth are on +X at the far end. `LEN` 9 m,
`HALF_W` 0.9, `DECK_H` 0.5 over the water, `SPACING` 14 m between docks.

- **Placement**: holding `blueprint_dock` (`blueprint` "dock"),
  `dock_spot(from)` runs the dock out the way you face with its land end at
  the water's edge just ahead. If that fails it slides the land end along
  `DOCK_SLIDE` (1, 2, 0, 3, 4, −1, 5, 6, 8 m) and turns it by `DOCK_TURN`
  (0, ±0.2, ±0.4 rad) until `dock_blocker` passes: land from −0.4 to +1.2 m
  round the water line at the land end, the far end between `SHALLOW`
  (0.2 m) and `DEEP` (4 m) of water, and the berth at least
  `Raft.DRAFT` + 0.1 deep. Right-click marks out the site.
- **Parts** (`PARTS`): `post` and `pile_0..3` (a Calamites log each,
  carried, and a river stone; the piles while standing in the water, 5 steps
  each), `spikes` (16 sticks, 8 cordage, a cut tool, 8), `stringers` (4
  `board_calamites`, 4 cordage, 6), `deck` (12 `board_tree_fern`, 6 cordage,
  9), `slipway` (2 branches, 4 `board_calamites`, 2 cordage, 6), `mooring`
  (a branch, 2 cordage, 3).
- **Safety**: `Game.dock_safe(pos)` is true on a finished dock and within
  `GUARD` (7 m) past its end and to each side. `Game.safe(pos)` (a finished
  house, a finished dock or an island) keeps water predators off you there.
  Water predators (lurker and ambusher, `Creature.WATER_PREDATORS`) also keep
  out of `Game.dock_keeps_out(pos)` (`dock.keeps_out`): the same water plus
  `LAND_GUARD` (30 m) behind the dock up the bank. They never strike you
  there, never move in (`creature._keep_off_docks`), and one caught inside
  when the dock is finished swims out by `dock.way_out` and moves its homes
  out. Lurkers are not spawned there either.
- Saved as `"docks"`.

## Rafts (`raft.gd`, `player._physics_riding`)

Local space: y = 0 is `RIDE` (0.1 m) above the waterline, the bow −Z.
`LOGS` 6, `HALF` (0.96, 1.0), `TOP` 0.24.

- **Parts**: `log_0..5` (a Calamites log each, 3 steps), `cross` (3
  `board_calamites`, 4), `lashing` (8 cordage, 4 string, 8), `line` (2
  cordage, 2), `launch` (3). Built at the dock's `BERTH`.
- **Riding**: E boards. With a `pole`-tagged item held, the move keys set
  `push`: `SPEED` 3 m/s, `ACCEL` 2, `DRAG` 0.5, `TURN` 0.9, `WIND_PUSH`
  0.035. It grounds where the water is shallower than `draft()` =
  `DRAFT` (0.1) + load / 2500. Stepping off within `TIE_REACH` (7 m) of a
  finished dock's berth ties it up there. It can't pass under a dock
  (`_hits_dock`: a move that would put a corner inside `dock.covers` is
  refused and it bounces back a little).
- **Poling animation** (`player._pole_pose`): while poling, `player.poling`
  is set and `pole_phase` runs at `POLE_RATE`; the pole is drawn `POLE_DRAW`
  (2.5x) longer, gripped at its top, planted ahead and pushed back, then
  lifted forward again, with a soft splash at each plant.
- **Cargo**: sacks set down on it (Use) go to the four `SPOTS`; one hauled
  thing from `CARGO_GROUPS` (logs, workbenches, soup pots, vessels, traps,
  anvils, meteorites) rides at `CARGO_AT`. `LOAD_REF` (150 kg) of cargo
  halves its acceleration; uneven loads list it.
- **Bites** (`creature.start_raft_bite`, state "raft_bite"): over water at
  least `BITE_DEPTH` (0.9 m) deep, outside `Game.safe`, never sooner than
  `BITE_GAP` (20 s) after the last, a chance a second of `BITE_RATE` (2% by
  day, 3.5% by night). `BITE_WARN` (2.5 s) of ripples, then the corner dips;
  `BITE_WINDOW` (3.5 s) to strike the biter, and `BITE_SECOND` (2 s) once
  the corner is under. Past `TIP` (0.5 rad) of tilt you are tipped in. Bites
  never damage the raft.
- Poles: `calamites_pole` (2 split from a `log_stripped` Calamites log, 4
  steps), `hardened_pole` (cooked in a campfire), `copper_shod_pole` and
  `iron_shod_pole` (a pole and a pole shoe, by hand).
- Saved as `"rafts"`, with their cargo.

## Islands (`terrain.gd`, `swamp._spawn_islands`)

`ISLANDS` (5) at `ISLAND_RING` 600–740 m from the centre (the marsh shore is
about 460 m out), radius
`ISLAND_R` 26–44 m, `ISLAND_TOP` 3–7 m high, their shelf meeting the floor
at `ISLAND_FOOT` (−3 m). `terrain.island_at(x, z, margin)` finds one.
`Game.island_safe(pos)`: within `ISLAND_SAFE` (25 m) of the shelf no water
predator comes. Each island's outcrops and anvil stones come from its seed;
an anvil stone stays where it was made until first picked up (then it is in
`Game.taken` and saved with the rest). On an island's shore `_shore_kind`
washes up gravel: stones, and `native_copper` (`SHORE_COPPER` 55%).
Every island also always has its own batch (`swamp._island_copper`, run from
`_update_shore`): within `SHORE_RANGE` of an island whose batch has expired
(or was never laid), `ISLAND_COPPER` (4) lumps go down at its waterline
(`island_shore_spot`: walking in from the foot of the shelf to ground
between −0.25 m and `SHORE_ITEM_TOP`), all with the same `SHORE_LIFE` expiry,
tagged `isle` in `_shore`. `_isle_copper[i]` holds that expiry, so picked
lumps aren't replaced until it passes. A lump dropped for distance before it
expires clears the island's entry, so the batch is laid again on return. The
copper hammer and its head use the `hammer` / `hammer_head` shapes
(`Assets`): a short handle and a square cast head.

## Copper

- **Clamp** (`charcoal_clamp`, `build` "clamp": 10 firewood, 4 clay, a `dig`
  tool): lit with an ember or a lit torch, it burns `BURN` (1440 s), then a
  mattock opens it for 8–12 charcoal (early: some charred sticks; unlit: the
  firewood back). Saved as `"clamps"`.
- **Furnace** (`furnace`, `build` "furnace": the 8-stone ring, a `dig`
  tool), then parts `shaft` (12 clay, 2 ash), `tuyere`, `firing` (4
  firewood), `blowpipes` (2). `heat` 0..1; each click while casting or
  smelting is a breath (`BLOW` 0.17); a step only counts at `HOT` (0.75) or
  more while the copper melts (`melt` [steps, …] on the recipe); it loses
  `COOL` (0.05) a second, `WET` (1.6×) faster in rain, where a breath also
  does less. The first finished furnace opens the `metal` tier. Saved as
  `"furnaces"`.
- **Recipes** (`at`: "furnace", "anvil", "water", "meteorite"):
  `work_spot.station_options` lists what can be made at the station you
  kneel at. `anvil_steps` overrides the steps at an anvil; `at` "water" is a
  washing pan knelt at the water. Moulds (`mould_*`, `uses` 5) are `wear`
  tools of `cast` recipes. `whetstone: true` recipes need the anvil's seated
  whetstone.
- **Shaping an anvil** (`heavy_stone.stage`): `ROUGH` (station "boulder",
  `ROUGH_KG` 42 kg), `PECKED` (a rough anvil: station "anvil", so
  `anvil_steps` apply, but `at` "anvil" recipes say they need a dressed
  anvil), `GROUND` (dressed: every `at` "anvil" recipe), `SEATED` (a
  whetstone can be seated). `work_spot.shape_option()` makes the next stage
  as a recipe with `shape_anvil` (river stone as a tool): `act` "peck"
  for `ROUGH`, a 5x5 grid of levels 0–3 (`heavy_stone.heights()`, from the
  uid's seed, kept in `peck` and saved) knocked down a level per click
  (`peck_cell`, a blow on a flat cell is wasted); "steps" with 2
  `stone_grit` and a `pot_dirty` (pot back) to grind; "steps" to peck the
  seat, marks on the stone (`shape_mark`). `_finish_shape` calls
  `advance()`. Stones saved before stages existed load as `SEATED`. Dev:
  `--anvil=STAGE` drops one in front of you and kneels at it;
  `--work-make=shape` starts its next stage.
- **Outcrops**: a `hammer` tool breaks out 3–5 `copper_ore` (wearing the
  hammer), then `_ready_time` days before more; kept in `Game.harvested` by
  uid.
- **Copper flask** (`flask`, `flask_<kind>_<1..4>` for kinds `dirty`,
  `clean`, `soup`, `soup_spoiled`, and `flask_alcohol`; shape `flask`,
  `Assets.flask`). Raised at the anvil (`tool_tag` "hammer"). It works like
  the canteen, item by item:
  - Weight: 1.4 kg, plus 1.5 kg per serving. `flask_alcohol` is a fixed
    4.4 kg.
  - `hold` fills it to `flask_dirty_4`.
  - `SoupPot.SCOOPS` chains it a serving at a time. `SoupPot.mix(a, b,
    had)` weights the new serving by `servings_in(held)`.
  - Soup `decay` is 4320 (twice the canteen's).
  - `FermentVessel.POURS` lists its water items.
  - `FermentVessel.DRAWS` and `_drawn_into` add `DRAW` (10) measures up to
    the container's `measures` (20 for the flask, 10 for the canteen). A
    full container is refused.
  - `measures`: player `_use_measure` drains to `def.drained` (default
    "canteen").
- **Copper soup pot** (`soup_pot_copper`, `carry`, never fired). `SoupPot`:
  - `COPPER_ID`.
  - `capacity()` is `SERVINGS` × `COPPER_SIZE` (1.25) = 20.
  - `max_food()` is 15.
  - `heat_time()` is `HEAT_TIME` / `COPPER_HEAT` (1.5) = 40 s.
  - `life()` is `LIFE` × `COPPER_LIFE` (1.2).
  - The constants are the clay pot's.
  - `scoop()` rescales soup's age to clay-pot terms (age × `LIFE` /
    `life()`), so a canteen or flask counts its keeping from what is left.
  - The pot's panel (`tooltip`) uses the item's own name.

## Tool wear (`inventory.gd`)

- `breaks` (stone axe, spear, mattock): a hidden `used` count in the slot's
  data; the first `STONE_SAFE` (50) uses are safe, then each has
  `STONE_BREAK` (2%) to snap the head off, leaving the haft.
- `edge` (copper 30, iron 45): `edge_left(i)` drops a use at a time; at 0
  the tool is `blunt` (half damage, `_paced` doubles the steps) until
  `sharpen(i)` at the anvil's whetstone (`_finish_sharpen`: the most worn of
  its kind).
- `use_tool(i)` returns "broke", "blunt" or ""; `tool_slot(tag)` picks the
  held tool if it will do, else the best carried (iron, copper, stone; sharp
  over blunt); `use_tag(tag)` wears the one a job used. A use is a landed hit
  (`player.used_tool`), a finished job (`work_spot._use_tools`, not tools
  laid on the ground) or a dig.
- The copper hammer has `uses` 60, worn a strike at a time on iron
  (`hammer_wear` recipes, `work_spot._hammer_wear`); worn out it gives 2
  `copper_grains`. An iron hammer never wears. `fast_tool` (an iron chisel or
  hammer) halves the steps.
- Worn tools carry data, so each keeps its own slot (main's unlimited
  stacks never merge them). Wear goes through `_wear_one(i, data)`: on a
  stack of fresh tools the one in use keeps the slot (in your hand) and the
  rest move to another, so the next use wears the same tool.

## Meteoric iron (`weather.gd`, `swamp.meteor_fall`)

- `SHOWERS` (`meteors`, `day_meteors`): `FALL_CHANCE` (50%) of a shower
  bringing a meteorite down, always the first after you have cast copper.
  `_fall` shows a fireball heading that way if you are awake and says how
  far off (`how_far`) and which way it hit; then, delayed by distance, the
  `impact` sound with a camera `shake` (stronger the nearer). Asleep, you
  just get the message. `meteor_fall(dir)` puts it on dry land 60–300 m off
  roughly along `dir`, never within `METEOR_CLEAR` (60 m) of anything in
  `PLAYER_MADE` (houses, docks, piles, stashes, kept drops, fires, benches
  and so on; `player_made_spots`, `clear_of`), with a `crater.gd` round it.
- The crater's smoke column (`COLUMN`, 34 × 120 m) is a camera-facing quad
  with a noise shader, thinning to nothing over `LIFE` (`column_strength`).
  Craters are usually past the camera's far plane, so beyond 0.8 ×
  `view_distance` it is pulled in along the line of sight and scaled down
  to match, shrinking a little less than true (`pow(d / reach, 0.4)`) so a
  far one still reads over the trees.
- `day_meteors` (`DAY_KINDS`) joins the daily pool from `DAY_METEORS_FROM`
  (index 9, day 10): `FIREBALL_EVERY` 12–35 s, each `FIREBALL_LIFE` 3–5 s.
  These burn up high: each is followed by a distant double boom (`sonic`,
  −12 to −6 dB, no shake). A real fall is the louder `impact` with a camera
  shake and a smoke column, so it can't be mistaken. `--meteor-fall=S`
  starts one that brings a meteorite down after S seconds; `--crater=M`
  puts a fresh crater M m ahead; `--dock=N` marks out a dock on the nearest
  shore with N parts built (`--dock-work` kneels at the next part,
  `--dock-steps=K` begins it and does K steps, `--dock-deep` picks a shore where the spikes
  are worked swimming).
- A meteorite (`heavy_stone.gd`) is `buried` until `DIG_HITS` (3) mattock
  swings; then it can be hauled, or knelt at with `chisel` and `hammer` tools
  to chip `meteoric_iron` / `meteoric_iron_large`, wearing its `mass` down.
  Saved as `"stones"` (with anvil stones) and `"craters"`.

## The charted map (`core/chart.gd`, `ui/map_view.gd`)

- **Data**: one chart per world, `Game.chart` (a `PackedByteArray`,
  `GRID` × `GRID` = 200 × 200 cells of `CELL` 8 m from −`HALF` to `HALF`
  (800 m) in x and z; 1 = drawn) and `Game.map_marks` [{x, z}] (up to
  `MAX_MARKS`, 40). Saved by `Game.save_game` through `Chart.to_save()`
  (the chart deflated and base64'd) and restored in `apply_save`
  (`from_save`); a new run clears both.
- **Item and recipe**: `chart_map` ("Map", `"chart": true`), bench tier,
  "Writing": a `paper_sheet`, `ash_pencil` as a tool, `tool_tag` cut,
  `wear` ash_pencil, `sharpen` [0], 4 steps (work_spot draws the border and
  the compass rose).
- **Charting**: `swamp._chart` (each second, with the inventory tick) calls
  `Chart.chart_round(inv, pos)`. With a `chart_map` in the bag, the cells
  within `REACH` (32 m) not yet drawn are marked, using the first ash pencil
  whose slot data `drawn` is under `SHARP` (400), and adding to it. With new
  ground and no usable pencil it returns "pencil" or "blunt", and `_chart`
  notifies at most every `CHART_NAG` (20 s).
- **Sharpening**: Use with an `ash_pencil` held calls `Chart.sharpen`: it
  needs a `cut` tool in the bag and a pencil with `drawn` > 0, and wears one
  use (`uses_data`, which drops `drawn`).
- **View**: Use with a `chart` item held calls `swamp.open_map()`, which
  makes the `MapView` once (on the UI layer) and sets `ui_open`. It paints
  newly charted cells into a `GRID` image (`cell_color`: terrain height and
  island rock) and draws the visible part of it on a square sheet
  (`zoom` 1–10, `center` world x, z), ruled lines every 100 m, the markers,
  and an arrow at the player along `-basis.z` (or a dot at the sheet's edge
  when off it). North is up (−z). Left click (no drag) adds a marker,
  right-click removes the nearest within 14 px, wheel zooms about the mouse,
  drag pans; "pause" or "inventory" closes it.
- Dev: `--chart=METRES` charts round the start, `--open-map` opens it.

## Changes to main-game rules

- **Rare weather**: `CHANCE` is 33% (main: 20%), and `day_meteors` joins
  `KINDS` from day 10 (`ALL_KINDS`).
- **Copper hook**: `player.copper_hook()`: on `fishing_rod_copper` every
  bite is a fish (no nibbles) and the bait stays on until a fish is landed
  or fights free, even when an amphibian tears one off.
- **Stone tools** can snap (above); main's never do.
- **Escape roll**: `player.ESCAPE_BONUS` adds a `metal` tier (0.45), between
  `stone` and `advanced`.
- **Floors**: `swamp`'s ground height includes a dock's deck and a raft's
  as well as house floors.
- `Game.can_sleep_in` ignores rounding errors (also on main).

## Tests

`test_boats`, `test_tool_wear`, `test_metals`, `test_meteor_weather`,
`test_copper_vessels` and `test_map` in `tests/run_tests.gd`
(`--only=boats,metals,map`).
