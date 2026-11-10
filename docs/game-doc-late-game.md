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
| `src/world/heavy_stone.gd` | Things hauled like a log: anvil stones (group "anvils", station "anvil") and meteorites (group "meteorites", station "meteorite") |
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
  `GUARD` (6 m) past its end and to each side. `Game.safe(pos)` (a finished
  house, a finished dock or an island) keeps water predators off you there.
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
  finished dock's berth ties it up there.
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

`ISLANDS` (5) at `ISLAND_RING` 530–600 m from the centre, radius
`ISLAND_R` 26–44 m, `ISLAND_TOP` 3–7 m high, their shelf meeting the floor
at `ISLAND_FOOT` (−3 m). `terrain.island_at(x, z, margin)` finds one.
`Game.island_safe(pos)`: within `ISLAND_SAFE` (25 m) of the shelf no water
predator comes. Each island's outcrops and anvil stones come from its seed;
an anvil stone stays where it was made until first picked up (then it is in
`Game.taken` and saved with the rest). On an island's shore `_shore_kind`
washes up gravel: stones, and `native_copper` (`SHORE_COPPER` 55%).

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
  `_fall` shows a fireball heading that way if you are awake, then a boom
  delayed by distance; `meteor_fall(dir)` puts it on dry land 60–300 m off
  roughly along `dir`, with a `crater.gd` round it.
- `day_meteors` (`DAY_KINDS`) joins the daily pool from `DAY_METEORS_FROM`
  (index 9, day 10): `FIREBALL_EVERY` 12–35 s, each `FIREBALL_LIFE` 3–5 s.
- A meteorite (`heavy_stone.gd`) is `buried` until `DIG_HITS` (3) mattock
  swings; then it can be hauled, or knelt at with `chisel` and `hammer` tools
  to chip `meteoric_iron` / `meteoric_iron_large`, wearing its `mass` down.
  Saved as `"stones"` (with anvil stones) and `"craters"`.

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

`test_boats`, `test_tool_wear`, `test_metals`, `test_meteor_weather` and
`test_copper_vessels` in `tests/run_tests.gd` (`--only=boats,tool_wear,metals,meteor_weather`).
