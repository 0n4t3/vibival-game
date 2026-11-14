# Vibival game doc (for developers and AI agents)

[Guide home](README.md)

This page explains how the game works under the hood: every mechanic, the
numbers behind it, and the file that owns it. The other pages in `docs/` are
the player's guide. Read this one before changing the game, and update it in
the same change when a mechanic or number moves.

Paths are relative to `game/` unless they start with `tools/` or `docs/`.

## Ground rules

- **Engine**: Godot 4.7 (Flathub BaseApp), GL Compatibility renderer. Scripts
  only, no `class_name`: other scripts are pulled in with
  `const X := preload("res://...")`.
- **No imported assets.** Meshes, textures, icons and sounds are built in code
  at runtime (`Assets`, `Sfx`, `Icons`). The only shipped media are the music
  tracks in `game/music/`, loaded with `AudioStreamMP3.load_from_file`.
  `tools/pack.py` packs the project as a plain zip.
- **The flatpak stays sandboxed**: Wayland only (no X11 fallback), no network,
  no access to the user's files. Only `wayland`, `pulseaudio`, `dri` and
  `input` permissions. Don't add `--share=network`, `--socket=x11`,
  `--socket=fallback-x11` or any `--filesystem`.
- **Creative and dependency questions go to the maintainer** before you
  assume an answer: new creatures, items, art direction, libraries.
- **GDScript pitfalls seen in this project**:
  - `var x := f(a) if cond else 0.0` can crash the parser; split it or type
    the variable explicitly.
  - A lambda whose body spills onto a second line inside call arguments
    doesn't parse; make it a named function.
  - `:=` can't infer from untyped values (Dictionary reads, `intersect_ray`
    results, `rng.randf()` mixed with ints in some spots). Give the type.
  - Controls built in `_ready` need
    `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`, not just the anchors.
  - Before `queue_free` on a container's child you plan to replace in the same
    frame, `remove_child` it first, or the container still sizes for it.

## Layout

| Path | What it is |
|---|---|
| `project.godot` | Autoloads in order: Settings, Items, Assets, Sfx, Music, Game |
| `src/autoload/settings.gd` | Settings file, quality tiers, input bindings, volume and music options |
| `src/autoload/items.gd` | Every item, recipe, recipe category and knapping pattern |
| `src/autoload/assets.gd` | Procedural meshes (`mesh(key)`), materials, detail textures, item meshes |
| `src/autoload/sfx.gd` | Synthesised sound effects (`play`, `play_at`), cached as WAV |
| `src/autoload/music.gd` | Background music with random gaps |
| `src/autoload/game.gd` | Run state: clock, worlds and saves, creature and fire registries, dev flags |
| `src/core/inventory.gd` | Weight-limited slot inventory, spoilage, crafting checks |
| `src/core/survival.gd` | Vitals, nutrients, sickness, wounds and infection |
| `src/core/mesh_builder.gd` | Low-level mesh primitives (`cylinder`, `blob`, `leaf`, `tube`, `box`, `cone`, `lathe`) |
| `src/player/player.gd` | First-person controller, interacting, attacking, throwing, held items, torch light, grabs |
| `src/creatures/creature.gd` | All animals: species table, builders, behaviours, butchering |
| `src/world/scene_base.gd` | Shared scene setup: player, HUD, inventory UI, pause, death, `spawn_pickup` |
| `src/world/swamp.gd` | The swamp scene: chunks, sky, weather, spawning, sleep, saving, hints, torches |
| `src/world/lab.gd` | The tutorial: breakroom steps, then the lab |
| `src/world/breakroom.gd` | The breakroom and elevator car: coffee pot, table, keycard door |
| `src/world/elevator_intro.gd` | The tutorial opening: ground slice, title, elevator ride |
| `src/world/terrain.gd` | Deterministic height and rockiness |
| `src/world/chunk.gd` | One 32 m chunk: ground, trees, decor, generated pickups and harvestables |
| `src/world/harvestable.gd` | Plants, logs and clay banks you harvest with E |
| `src/world/pickup.gd` | An item lying on the ground |
| `src/world/guts.gd` | A guts pile: saved, lasts a day, draws scavengers |
| `src/world/stump.gd` | A felled tree's stump: regrows into the tree, dug out with a mattock; a lightning-struck one burns, glows, stays charred; a planted young tree; shoots |
| `src/world/plot.gd` | Farming: a hole dug with a mattock and a young seed fern growing in it |
| `src/world/compost.gd` | A compost basket: filled to 20, composts for 5–15 days, gives compost; meat draws pests |
| `src/world/trap.gd` | A fish trap (carried, set in water) or a snare (set on land): baited, catches while you sleep, holds a live medium animal |
| `src/world/intro.gd` | The arrival: the lightning strike and a white flash, lying on your back, the dragonfly flyover, getting up |
| `src/world/felled_tree.gd` | A felled trunk lying in one piece: falls, rots, is cut into logs |
| `src/world/wood_log.gd` | A loose log or short log: carried, worked, soaks and rots in water |
| `src/world/stack.gd` | A pile of one kind of raw material on the ground |
| `src/world/campfire.gd` | Placed campfire: fuel, light, cooking spots, ash, coals, embers, breaking |
| `src/world/stash.gd` | A sack set down as a container (50 kg frond, 100 kg cloth) |
| `src/world/thrown_rock.gd` | A thrown stone (or guts) in flight |
| `src/world/work_spot.gd` | Crafting by hand on the ground or on a workbench top |
| `src/world/workbench.gd` | A built workbench and the tools hanging on its rack |
| `src/world/soup_pot.gd` | A soup pot: carried, hangs over a fire, holds water or soup |
| `src/ui/hud.gd` | Bars, effects, hotbar, prompts, messages, waypoint marker |
| `src/ui/inventory_ui.gd` | The Tab menu: Inventory, Health and Recipes tabs, stash view, rest |
| `src/ui/work_ui.gd` | Overlay while crafting on the ground |
| `src/ui/papers.gd` | The breakroom papers, drawn page by page while reading them |
| `src/ui/icons.gd` | Inventory icons rendered from the item meshes |
| `src/ui/title.gd`, `pause_menu.gd`, `settings_panel.gd` | Menus |
| `src/ui/controls_panel.gd` | Rebinding keys, mouse buttons and the gamepad |
| `src/ui/touch_controls.gd` | On-screen stick and buttons for touch screens |
| `tests/check_scripts.gd` | Parses every script |
| `tests/run_tests.gd` | The headless gameplay suite |
| `tests/view_trees.gd` | Dev tool: renders each tree (or with `--parts` its stump and felled ends) to `.dev-out` |
| `tools/dev-run.sh`, `test.sh`, `pack.py`, `build-flatpak.sh` | Running, testing, packing and building |

## The tutorial (`lab.gd`, `breakroom.gd`, `elevator_intro.gd`)

The lab scene starts with the player in the elevator car (`Breakroom.CAR`,
facing west), east of the breakroom; the lab is north of the breakroom,
through `LabDoor` at x 3.5. `ElevatorIntro` (a CanvasLayer, layer 20) runs
on a 14 s timeline: black, a fade in on a cut through the ground with the
shaft (3D, in a SubViewport with its own world: strata, stones, roots,
fossils, a crashed flying saucer, a crocodile skeleton, a lined shaft with rails and a ladder; the camera only ever sees
the ground, never the surface), the car dropping past with its light and a
see-through trail, `Sfx` "elevator_pass" (air rung through a comb filter,
rumble, rail clanks), the title and tagline, a fade to black, then first
person in the car (`Music.elevator(true)` fades in the looping elevator
track over `ELEVATOR_IN`, a little shake) until
`OPEN_AT`, when `breakroom.open_elevator()` slides the doors, and
`DONE_AT`, when it calls `lab.intro_done()`. The hum is `Sfx` "hum" with
pitch and volume curves. Dev `--start=lab` skips it unless `--intro`.
No skipping.

`lab.step` goes ride → move → mug → pour → drink → pour2 → drink2 → papers
→ lay → read → door → enter → pickup (the lab's own steps follow). The
coffee pot (`CoffeePot`) turns a held `coffee_mug` into `mug_coffee` and
emits `Game.crafted("poured_coffee")`; drinking it (consume works with
vitals off, which the lab has) emits "ate_mug_coffee", counted in
`lab.coffees`. The table (`Table`) is in group "workbenches" and starts
bench work. The papers recipe (`keycard_jr`, 9 `steps`, `read`) shows
`work_ui._papers` over the work view; a click on the page calls
`spot.step()`, and the top page is `spot.steps`. Finishing it closes the
work. `LabDoor` opens only with `keycard_jr` carried. Walking through it
(`in_lab`) moves to "pickup". A keycard found early skips to "door".
The "move" hint is the only walking lesson: "Press [W] to step out of the
elevator..." (`Settings.hint` names `move_forward`'s binding for "[W]").
Once you are clear of the doorway (`breakroom.out_of_car`, x < `EAST` -
0.6) with the doors open, `breakroom.close_elevator()` shuts them (and a
blocker across the doorway at once, so you can't be shut in),
`Music.elevator(false)` fades the track out over `ELEVATOR_OUT` (0.8 s),
and the step goes to "mug".

## Time

`Game.time` counts game seconds since the run started. One game day is
`DAY_LENGTH` = 1440 s (24 real minutes): 3 min night, 2 min sunrise, 14 min
day, 2 min sunset, 3 min night (`PHASES`). You arrive at clock 330 s, just
after sunrise. `Game.day()`, `is_night()`, `time_of_day()` (solar fraction,
0.25 sunrise, 0.75 sunset) and `night_index()` derive from it.

**The arrival** (`intro.gd`). `Game.start_new_game` sets `intro_pending`
(dev `--start` runs only with `--intro`); `apply_save` clears it. The swamp's
`_ready` for a new run (no `restore`) adds an `Intro` node, which:
freezes the player with `player.lie` = 1 (eyes at 0.3 m, pitch 1.45 rad: on
your back looking up; `player._process` applies `lie` after the usual head
updates). `_ready` also sets the head and the HUD's white fade itself, so
the very first frame is already on your back under the flash, never a
glimpse of standing. First of all, at `STRIKE_AT` (0.05 s), sets the HUD fade to white
and fades it out over `WHITE_TIME` (3 s, easing in), calls `weather.strike`
at the treetop with a `BOLT_TIME` (2.2 s) life (a bolt that long stops
flickering after 0.5 s and fades out instead) and `swamp.strike_tree` on
the nearest soft tree within `STRIKE_RANGE` (30 m), falling away from you
(with none in range, the bolt hits the ground 40 m off); at `FLY_AT` (4 s),
with the tree down, flies a stand-in Meganeura (built here, not a
`Creature`: never hostile, not in `Game.creatures`, not saved) along a
bezier from one side, low over your face, and off the other side in
`FLY_TIME` (3.6 s), then frees it; from `RISE_AT` (8.5 s) over
`RISE_TIME` (1.8 s) eases `lie` back to 0 while turning you to face the
stump, then unfreezes you and says what to do. It takes no input, so it is
the same on desktop, Android and the web.

Sleeping (`swamp.sleep`) passes `SLEEP_LENGTH` = 480 s at once through
`_pass_time`, which ages the inventory, burns fires (on into their coals),
ages lit torches and
ticks vitals in big steps. You can sleep again `SLEEP_COOLDOWN` = 720 s after
waking.

## Survival (`src/core/survival.gd`)

There is no health. Energy (0–`MAX_ENERGY`, 200), water and stamina (0–100)
and the nutrients protein, greens and starch work as before: energy drains 100 per 3000 s
(so full to empty takes 6000 s; food gives the same `energy` as ever),
water 100 per 1800 s, each nutrient 100 per 4500 s; sleeping drains energy
and water at 0.6×; sickness and fever speed thirst up. A nutrient under `LOW`
(25) is a craving: low protein caps stamina at 70 and slows healing, low
greens doubles infection risk and speeds it 1.5×; `nutrition()` (0.2–1)
scales healing and blood regrowth.

Hunger and thirst are shown as words, not bars: `need_level(full)` gives 0
(over 75%), 1 (75–50%), 2 (50–25%), 3 (25% down to just over 0) or 4
(empty), named by `HUNGER_NAMES` ("Mildly Hungry", "Hungry", "Starving",
"Dying of Starvation") and `THIRST_NAMES` ("Mildly Thirsty", "Thirsty", "Very
Thirsty", "Dying of Thirst"); `hunger_words()` / `thirst_words()` give
[text, color] for the HUD. By level: `HUNGER_REGEN` and `THIRST_REGEN` scale
stamina regrowth, `HUNGER_HEAL` scales wound and blood healing,
`THIRST_SPRINT` scales stamina spent sprinting or swimming, and
`NEED_STAMINA_CAP` (by the worse of the two) caps `max_stamina()`. Blood only
regrows below level 3 in both. `_say_needs` posts a status line when either
gets worse into level 2 or more. Levels 2+ are in `problems()` with `need`
set, which `status_words()` leaves out (the HUD has their own lines). Saves
store `energy_max`; a save without it had energy out of 100, and `from_dict`
scales it to keep how full it was.

### Conditions

`harms()` gives each condition a harm, 0 fine to 1 dead; `_check_death`
kills at 1 and sets `cause`:

| Condition | Harm | Rises | Falls |
|---|---|---|---|
| `blood` | 1 − blood/100 | `lose_blood` (bleeding, hits, jaws) | `BLOOD_REGEN` 0.03/s × rest × nutrition × `HUNGER_HEAL` while energy and water are over 25% and nothing bleeds |
| `venom` | venom/100 | `poison(n)`: n × `VENOM_PER` (2.5); a scorpion sting is 35 | `VENOM_FADE` 0.08/s × rest |
| `infection` | `INF_HARM` by the worst stage; sepsis 0.5 → 1 over `SEPSIS_TIME` (720 s) | stages, below | treatment |
| `starving` | 0..1 | 1/`STARVE_BAND_TIME` (4000 s) while energy is 25% or under; 1/`STARVE_TIME` (500 s) at 0 | eating above 25% |
| `thirst` | 0..1 | 1/`THIRST_BAND_TIME` (1200 s) while water is 25 or under; 1/`THIRST_TIME` (360 s) at 0 | drinking above 25 |
| `drowning` | 0..1 | `drown(delta)`, 1/`DROWN_TIME` (17 s) exhausted in deep water | 0.25/s otherwise |
| `sickness` | `SICK_HARM` (0.3) while `sick` | food poisoning (seconds) | rest |

Rest: `tick(..., sleeping, still)` is 3× asleep, 1.5× standing still. The
worst harm is `harm()`; `tier()` is how many of `TIERS` [0.25, 0.5, 0.75] it
has passed. Tier 1: `can_sprint()` false. Tier 2: `speed_mult()` 0.7,
`carry_mult()` 0.7. Tier 3: 0.5 and 0.5, and `blindness()` (0.55 → 0.97),
which `hud._blind` draws under the HUD. The player copies `carry_mult()` and
`arm_broken()` into `Inventory.strength` and `arm_broken` every physics frame.

### Wounds

Each wound is `{sev, bleed, bleed_t, held, dirt, cover, inf, inf_t, sterile,
src}`. `add_wound(sev, dirt, source)` gives it a bleeding level
(`bleed_for`: under 0.15 none, under 0.3 minor, under 0.55 moderate, else
major) losing `BLEED_RATE` [0, 0.12, 0.18, 0.6] blood/s.

- Minor bleeding stops by itself after `bleed_t` (20 + 60 × sev s).
- `apply_pressure(i)` (after the player holds still for `PRESSURE_TIME`, 8 s,
  bleeding at `PRESSED_RATE` meanwhile) stops moderate bleeding, and holds
  major bleeding back for `HELD_TIME` (60 s) at `HELD_RATE` 0.05/s.
- `cover(i, "bandage" | "wax")` refuses a moderate bleed or an unheld major
  one; a bandage stops minor and held major bleeding; wax only goes on a
  wound that has stopped. Returns why not, or "".
- Dirt: `WET_DIRT` per second wading or swimming (open 0.03, bandaged 0.01,
  waxed 0), and `EXPOSE_RATE` 0.0015/s for an open wound out of the water.
- `reopen()`: another creature hit tears the first covered wound open (cover
  off, +0.4 dirt, minor bleeding).
- Healing: a wound with no infection and no bleeding loses severity
  (`0.0006 × nutrition`, ×0.4 low protein, ×3 asleep, less when dirty, ×1.3
  covered) and is removed at 0.
- `wound_name(w)`: Scratch, Cut (> 0.15), Deep wound (> 0.35), Mauling (> 0.6).

### Infection stages

`inf` is `INF_NONE`, `INF_MINOR`, `INF_MODERATE`, `INF_MAJOR`,
`INF_REMISSION` or `INF_SEPSIS`; `inf_t` counts seconds in the stage.

- Onset: never on a clean (dirt ≤ 0.05) covered wound; otherwise
  `INFECT_RATE` 0.002 × dirt per second (×0.5 covered over dirt, ×2 low greens).
- Minor: after `MINOR_TIME` (720 s) it clears, or worsens with chance
  `MINOR_WORSEN` (10% clean and covered, 30% otherwise). Covering it when
  clean (washed) clears it at once. One that set in while `Game.time` <
  `EARLY_TIME` (2880 s, the world's first two days) is marked `early` and
  always clears: washing needs a clay pot, which a new player may not have
  yet. `_set_inf` clears the mark, so only that minor stage is spared.
- Moderate → major after `MODERATE_TIME` (1440 s); major → sepsis after
  `MAJOR_TIME`; remission → major after `REMISSION_TIME`. Sepsis: no cure.
- `wash(i, alcohol)`: dirt to 0, the cover comes off an infected wound (or
  for alcohol). With alcohol: major → remission, remission → minor,
  otherwise `sterile`, and a sterile moderate wound clears when bandaged.
  Alcohol comes from a canteen of alcohol (`treat` "alcohol"), brewed in a
  sealed fermentation vessel.

### Limbs

`limbs` maps "arm", "leg", "ankle" to sleeps left (`MEND`: 2, 2, 1);
`break_limb`, and `slept()` (called by `swamp.sleep` on waking) counts them
down. A broken leg or sprained ankle: `LEG_SLOW` 0.6 and no sprinting. A
broken arm: `Inventory.capacity` is half the base 8 kg plus the sack's 17 kg,
and hauling is `ARM_HAUL` (0.5) speed. `player.hurt` from a creature: blood
−`TRAUMA` (0.4) × damage, a wound, `reopen`, and for damage ≥
`FRACTURE_FROM` (15) a chance `(damage − 12)/40` (max 60%) to break an arm or
a leg. `player.landed(drop)` (from `_check_fall`, not in water or flying):
over `FALL_SAFE` (3 m) a chance from 25% rising over `FALL_RISK` (4 m) of a
sprained ankle or broken leg, 50/50. `player.next_injury` forces a roll in
tests.

### Telling the player

`problems()` lists every problem worst first as `{words, color, rank, say,
advice}`; `status_words()` (the HUD corner) is the first one or two
`words`, leaving out hunger, thirst and cravings, which have their own HUD
lines (`hunger_words`, `thirst_words`, `craving_words`, the last naming every
nutrient you are short of, "Craving greens and starch") so a worse problem
like venom can't hide them; `summary()` heads the Health tab (sepsis says `SEPSIS_TEXT`). The
Health tab shows the condition bars, limbs, vitals and nutrients, then each
problem's `say` and `advice`, and a card per wound (bleeding, cover,
infection, depth, dirt, `wound_advice`) with Apply pressure, Wash, Alcohol,
Bandage and Seal with wax.

### Dying, and the save

`swamp._on_player_died` names the `cause` (`DEATHS`) and calls
`Game.ease_saves(cause)`, which rewrites this run's camp and suspend saves
with `Survival.ease(vitals, cause)`: blood +25 and each bleed a level less;
venom −25; starving or thirst −0.25 (with energy at least 30% of `energy_max`, or water at least 30, so just hungry or thirsty);
the worst infection a stage less (sepsis → major → remission → minor →
none). Old saves: `health` is ignored, old wounds become levels and stages
(`_wound_from`), old venom seconds become venom.

The player applies treatments with `player.treat_slot(slot, wound := -1)`,
and pressure with `start_pressure(wound)` (`stop_pressure`, `pressure_left`).

## Items (`src/autoload/items.gd`)

`ITEMS` maps an id to a dictionary; the header comment lists every field.
The important ones:

- `w` weight (kg), `shape` (mesh family in `Assets._item_mesh`), `color`.
  (`stack` is still on many items but no longer read: stacks have no size
  limit, see Inventory.)
- Food: `energy`, `protein`, `greens`, `starch`, `water`, `sick` (chance of
  sickness when eaten), `decay` (seconds before it spoils), `spoil` (what it
  turns into, `"rotten"` by default; `""` leaves nothing), `goes_out` (it
  ages on the ground too, and vanishes when spent: the ember).
- Fire: `fuel` (seconds of burn), `cook` (what the fire turns it into) and
  `cook_time`.
- Tools: `damage`, `reach`, `tags` (`cut` is a blade: needed to butcher
  medium and large carcasses, and strips more fiber, `chop` is an axe: fells
  soft trees and works logs, `fire` lights fires, `dig` marks a mattock: breaks
  campfires, digs out stumps and (Use) digs holes for planting, `sack` raises carrying
  capacity), `tier` (strike class for the escape roll).
- `pile` (dropped on land it goes on a `stack.gd` pile of its kind), `carry`
  (too big for the bag: lives in the world and is carried in your arms; the
  logs as `wood_log.gd`, `soup_pot` and `soup_pot_unfired` as `soup_pot.gd`).
  A recipe whose output has `carry` is left in the world beside the bench
  (`work_spot._finish` → `swamp.add_carried`).
- `place` (placeable kind), `throw`, `hold` / `empty` (water containers),
  `treat` (`clean`, `alcohol`, `bandage`, `wax`), `light` (a held light, range in m),
  `splat` (guts: thrown or dropped, it becomes a guts pile on land, or a
  splash lure in water), `frenzy` (a baitbox: seconds of feeding frenzy when
  thrown into water, see "Baitbox").
- `as` (counts as that item in recipes, `Items.counts_as`). Besides real
  items ("board", "pot_dirty"), it can name a group item that is never found
  and only stands in recipes: `small_fish` (any small fish) and
  `any_raw_meat` ("Raw Meat or Fish": `raw_meat` and `fish_meat`, for the
  baitbox).

`RECIPES` entries have `out`, `n`, `in` (consumed), `tools` (needed, kept),
`where` (lab or swamp), `tier` (hand, workbench, metal), `cat` (one of
`CATEGORIES`, the recipe book's order), `act` (twist, steps or knap), `verb`,
`how`, and for knapping `knap`. `recipe_steps(r)` says how many clicks a
steps recipe takes.

`KNAPPING` holds the 5×5 patterns (`#` keep, `.` strike off).
`knap_matches(grid)` returns the head a grid matches, mirrored or not.

### Inventory (`src/core/inventory.gd`)

30 slots, the first 6 are the hotbar. Each slot is null or
`{id, n, age}`, plus `data` for a one of a kind item (a Pot of Soup): a
Dictionary that overrides the item's fields for that item
(`inventory.def_of(i)`). Items with `data` never stack or merge, can't be
laid out to craft with, and keep it through `add`/`take` (extra `data`
argument), moves between bag and stash, drops (`pile_item` and
`spawn_pickup` take `data`; `pickup.gd` saves it) and saves. Stacks have
no size limit (`Items.max_stack` is `UNLIMITED`): weight alone limits what
you carry. Fresh tools stack; a worn one (`uses_data`) has data, so it
leaves the stack for a slot of its own (`replace` on a stack splits one off,
so an emptied pot or a worn pencil goes elsewhere). A stack keeps
the age of its oldest item: `add` and a merge in `inventory_ui` take the
larger age, and so do piles (`work_spot._add_pile`), so a fresh item added
never makes the rest look fresher. Weight, not slots, limits what you carry: 8 kg in your arms,
plus `sack_bonus()`: the best `carry_kg` of any item carried (frond sack 17, so
25 kg; cloth sack 40, so 48 kg). Sacks (`tags: ["sack"]`) don't add up. Nothing
past 1.5× that
(`OVERLOAD`). Over the limit you are slow and can't sprint. `add(id, n, age,
force)` returns how many didn't fit; `force` ignores weight. `tick(delta)`
ages perishables and turns spoiled ones into their `spoil` item (nothing,
for an empty `spoil`).

## Gathering (`src/world/harvestable.gd`, `chunk.gd`)

Chunks generate pickups (sticks, river stones, chert) and harvestables, all
with stable uids built from the chunk coordinates. A chunk comes out the
same at every graphics quality, so a world moved between desktop, web and
Android keeps its trees: the terrain's colour jitter rolls on its own
`shade` RNG and the main one skips the draws full-detail terrain would use;
trees and the ground cover's rolls use `WORLD_DENSITY` (0.75, Medium's);
`Settings.vegetation_density()` only thins the ground cover or adds more on
the separate `look` RNG. Picked-up generated items
are remembered in `Game.taken`; harvested ones in `Game.harvested` (uid →
game time when ready again).

| Kind | Yield | Regrow (game days, rolled per harvest) |
|---|---|---|
| fern | 2–3 fiber (+2 with a cut tool), 0–2 fiddleheads (dug up: 3 fern_spores, 1 if picked clean) | 30–50 (dug up: never) |
| planted_fern | 1–2 fiber (+2 with a cut tool), 0–1 fiddlehead (dug up: 1 fern_spores) | 5, or 2.5 fed within a day (dug up: never) |
| tree_fern | 1–2 fronds, 1–2 fiber | 3 |
| seed_fern | 2–4 seeds, 0–1 frond (dug up: 4 fern_root, + its seeds if ripe) | 5 (dug up: never) |
| planted_seed_fern | 1–2 seeds (dug up: 2 fern_root, + its seeds if ripe) | 5, or 2.5 fed within a day (dug up: never) |
| rotting_log | 1–3 grubs, 1–2 tinder, 0–2 sticks | 1.5–2.5 |
| clay_bank | 2–4 clay | 1.5–2.5 |

`regrow` in `KINDS` is a `[min, max]` range in days; `regrow_time()` rolls it.
A kind with `dig` (the seed fern, the fern) is dug up by a `dig` tool's swing
(`player._attack` → `dig()`), `dig_hits` swings (seed fern 2, fern 1): it
gives `dig` (seed fern: `fern_root` ×4; fern: `fern_spores` ×1) and, if
`is_ready()`, a roll of its `dig_ripe` yield (seed fern: seeds) and its
`dig_ready` items (fern: 2 more spores, so 3 unpicked, 1 picked clean), sets `Game.taken[uid]` (saved) and is freed; `chunk._add_harvestable`
skips a taken uid, after the chunk's rolls so nothing else moves.
`fern_root` (energy 0.5, greens 8, keeps 3 days) and `seed` have `plant`
"seed_fern" (see Farming); `fern_spores` (not food, don't spoil) have
`plant` "fern", growing for the same `GROW_DAYS` into a `planted_fern`,
which grows back like a planted seed fern (5 days, 2.5 fed).
The decorative ferns (`DECOR` "fern", ground cover with no collision) can
be torn out with a mattock for nothing: a swing whose ray meets the ground
(within 0.6 m of `ground_height`) and no dig or break target calls
`swamp.clear_fern(point)`. That checks the point's chunk then its neighbours
(`chunk.clear_fern(p, FERN_REACH)`, 0.8 m): the nearest fern in
`chunk.decor_ferns` is scaled to nothing and `Game.taken[Chunk.fern_key(x,
z)]` ("d" + its position in decimetres) is set. A rebuilt chunk skips a
taken fern only after rolling it, so no other plant moves, and the key goes
by position, so it stays gone at any graphics quality. A planted kind's uid is its planting's: `dig()`
erases `Game.plantings[uid]` instead of setting `Game.taken`.
Half the tree ferns are harvestable. Those carry a `tree_fern_crown` mesh
(bright young fronds and fiddleheads) at the top of the trunk, passed in by
`chunk.gd` as `crown` height and `crown_scale`; the mesh hides while the fern
regrows. The crown is out of reach, so its collider is a 2.2 m cylinder round
the foot of the trunk (`trunk_r` × `crown_scale` + 0.3), wider than the trunk's
own collider so the trunk never hides it. A strippable fern draws `fern_ripe`
(bigger and brighter than the decoration `fern`, with three fiddleheads,
`Assets._fiddlehead`, shared with the crown, and pale straw fronds round its
foot for the fiber), and `fern_stripped` (cut-back stalks) while it regrows.
Seed ferns swap to a bare mesh; logs and clay banks stay visible.

## Items on the ground (`pickup.gd`, `scene_base.spawn_pickup`)

`spawn_pickup(id, n, pos, age, keep := true)` drops items (guts make a guts
pile instead). Kept pickups join
the `drops` group and are saved with the world (`swamp._world_state` →
`"drops"`), so Q, Drop, overflow from a full inventory and whatever a broken
campfire leaves all survive a reload. The inventory's **Discard** and thrown
stones (`thrown_rock._land`) pass `keep = false`: the pickup exists until the
scene is reloaded. Generated world items are not in `drops`; they are
regenerated by their chunk unless `Game.taken` has their uid.

A pickup with a `decay` ages by the world clock (`_process`, so through
sleep too). An item that `goes_out` (an ember) is freed at its decay; any
other turns into its `spoil` (default "rotten") with age 0, as in the bag. A
generated world item that rots marks its uid taken and joins `drops`, so the
rotten one is what is saved. A `_carcass` item (`carcass()`) never spoils
on the ground: it keeps its age (the time since the kill, so picked up late
it spoils in the bag) and is freed once that reaches `DAY_LENGTH`.

**Shore stones** (`swamp._update_shore`, every 1.5 s): `SHORE_ITEMS` (18)
sticks (`_shore_kind`: `SHORE_STICK` 30%, anywhere), river stones and chert
(`SHORE_CHERT` 30%) and salt crusts are kept within `SHORE_RANGE`
(100 m) of the player, on ground between -0.25 and `SHORE_ITEM_TOP` (0.6 m)
within `SHORE_ITEM_REACH` (8 m) of swamp water (`shore_spot`, whose own
defaults, used by creatures, stay 0.3 m and 4 m). Each lies there for `SHORE_LIFE` 1–3 days and is then
freed; ones over 200 m away go too. A new one washes up about every
`DAY_LENGTH * 2 / SHORE_ITEMS` (randomised), or every 30 s while fewer than
half are left. A new world seeds the full set. They are saved in
`_world_state` → `"shore"` with their expiry. A picked-up one leaves the list
(and dropped again, it is an ordinary kept drop). Each wash-up
(`_wash_up`) is a salt crust `SHORE_SALT` (35%) of the time: it looks for a
spot on dry bank (`shore_spot(..., dry)`: at least 3 cm above `water_level()`,
within `SHORE_SALT_REACH` (6 m) of the edge)
with four times the tries, and if none turns up a stick or stone comes
instead. A crust sits on whichever is higher, the terrain or the ground as
drawn (`drawn_height`: the mesh is coarser than the height function at low
quality, and it covered crusts before). `_shore_kind` never gives salt.

## Crafting on the ground (`src/world/work_spot.gd`, `src/ui/work_ui.gd`)

C kneels and creates a `WorkSpot` in front of the player. You lay items from
the inventory onto it (`lay`), `options()` lists recipes the laid items can
make (with what is missing), and `begin(r)` consumes the inputs and starts the
hands-on act:

- **twist**: drag with the left button. `progress` rises by
  `|dx| × TWIST_PER_PX` (gamepad: hold, 0.35/s) and `_roll` follows the
  signed drag so the work visibly rolls. It rebuilds every 1% of progress or
  quarter turn, rustles every 2.5%, ticks every 10%, and the work UI shows a
  progress bar. Used by cordage and both torch recipes.
- **steps**: click the glowing marker (`_target(out, k)` places it) once per
  step. Each recipe has its own workpiece in `_rebuild_work` that builds up
  with the step count.
- **knap**: strike cells of a 5×5 slab (`strike(k)`). The work ends when the
  grid matches the chosen head (or its mirror). Another head only counts once
  a cell the chosen head needs has been struck off, so you can't finish on
  the wrong head by accident. A struck nodule is lost if you stop.

`tools` (a river stone for knapping and crushing wax) can be laid out or in
the inventory and are kept. Standing up returns all laid items. `missing_for(r)`
lists what a recipe still needs. Tiers: `hand` recipes are made anywhere,
`bench` ones only on a workbench; `Game.tiers` decides which tiers' recipes
the book shows ("bench" is unlocked when the first bench is built).

Small prey are gutted and skinned by recipes with `"dress": true` (four steps,
`Items.recipe_steps`). The work spot draws the animal with `Assets.small_prey`
at the carcass item's `body_scale`: slit, gutted (guts beside it) and skinned
as the steps go (`_rebuild_work` and `_target` match "dress" for all of them).
The slit and the click markers are fitted to the animal's body
(`Assets.prey_body` / `prey_top`).

Small prey items (`shape: "lizard"`) are drawn by `Assets.small_prey` from
their `animal`: a Hylonomus (no `animal`) is the original `lizard` shape; the
others use `PREY_SHAPES` (body and head size, tail length and thickness, leg
length) plus their own details: Petrolacosaurus's back stripe, Archaeothyris's
deep jaw and pale belly, Amphibamus's flat head, big eyes and spots,
Tuditanus's pale bands, Morganucodon's snout, nose, ears and rougher (furry)
body. Skin markings (stripes, spots, bands, belly, ears, fur) only show on the
`_carcass`; dressed and roast ones keep the shape in their own colour.

### Workbench (`src/world/workbench.gd`)

The `workbench` recipe (hand tier, 4 boards, 4 sticks, 2 cordage, 8 steps)
has `build`: `_finish` calls `_build`, which asks `swamp.add_bench(pos, yaw)`
for a bench at `BUILD_AT` (0.9 m beyond the spot, 1.65 m from you), unlocks
the "bench" tier and stands you up. While it is built you stand (eye height
1.5) and look at the frame (`look_point`); the frame (`Assets.workbench(b, rng,
done)`) goes up leg by leg. `eye_back()` steps your eye 0.8 m back while
building so the frame fits the view. The option is held back by
`build_blocker()`, which asks `scene_base.bench_blocker(at, yaw, exclude)`:
the ground under the legs must be above the water line, and a box the size of
the bench above the highest of it must hit nothing on layer 1 (trees,
boulders, another bench). Slope doesn't matter: `bench_height(at, yaw)` puts
the top so that every leg (`Assets.bench_legs()`) sinks no more than
`BENCH_SINK` (0.2 m) into the ground, and the frame's legs (the `drop` array
of `Assets.workbench`) and the built bench's feet (`workbench._add_feet()`,
cylinders down to `floor_height` under each leg) reach the ground. Houses
have no slope limit either: stilts and ladder reach down to the ground.

A bench (group "workbenches", layers 1|2, "hard") is `Assets.BENCH_SIZE`
(1.4 × 0.8 high × 0.8 m), its front at +Z. `scene_base.bench_ahead()` (looking
at it or a rack tool, or one within 1.3 m ahead) makes C call
`_start_bench_work`: you stand 1.05 m in front, and the `WorkSpot` sits on the
top with `bench` set, `tier` "bench", `_floor` 0 and eye height 1.5.
`options()` then lists hand and bench recipes but not `build` ones. A recipe
with `rack` (the soup pot needs the clay platter, the canteen the woodworking
tools) needs `bench.has_tool(rack)`. Such a recipe is only known
(`Game.knows_recipe`) once its tool is in `Game.tools_known` (saved as
`"tools_known"`; for older saves, worked out from the bag and the benches'
racks): `Game.learn_tool` is called for anything held (`player._process`,
when the held item changes) and anything made (`Game.crafted`), and says so
once. Unknown, it isn't in `options()` and isn't in the book. Known, the book
shows it on its own page, `Items.ADVANCED` ("Rack tools"), under a heading
per tool (`inventory_ui.book_rack_tools`), never in its own category, unless
it has `listed` (the soup pot), which keeps it in its own category instead
(`inventory_ui.on_rack_page`).

Two more knowledge fields. `known_by` (the bow drill's "spindle") makes a
recipe known only once that tool is in `tools_known`, without needing it on
the rack: it stays in its own category. `rack_or_bag` (string) lets the
`rack` tool be laid out or in the bag instead of on the rack (`missing_for`
says "a spindle (on the workbench rack or in your bag)"), and the book's
heading says "(or in your bag)". `learn_tool` names the pages the new
recipes are on. **Using a bench teaches**: `workbench.teach()` (from its E,
and from kneeling at it in `scene_base._start_bench_work`) unlocks the
"bench" tier and calls `learn_tool` for every tool on its rack.

**The spindle.** `spindle_whorl_unfired` (1 clay, 3 steps, bench) cooks into
`spindle_whorl` (40 s); `spindle` (whorl and a stick, 2 steps, bench) is a
rack tool. `string` (3 fiber, twist, bench, `rack` spindle, `rack_or_bag`)
is drawn as a spindle turning beside a strand that thins and winds on.
**Fishing gear** (category "Fishing"):
`rod_blank` (1 branch, 4 steps, bench, `rack` woodworking_tools, `listed`, so
it shows under Fishing once the tools are known), `fishing_line` (3 string,
twist, hand, `known_by` spindle; the cordage workpiece, finer and paler),
`chitin_hook` (1 chitin, knap pattern "chitin_hook", `tool_tag` cut, bench,
no rack) and `fishing_rod` (the three, 3 steps, bench, nothing else). Bait is
`tags: ["bait"]`: `meat_bait` (2 from any raw meat item by hand: raw_meat, fish_meat,
gnawed_meat, any dressed small prey (lizard_dressed, petrolacosaurus_dressed,
archaeothyris_dressed, amphibamus_dressed, tuditanus_dressed, morganucodon_dressed), or any small fish; decays like raw
meat into rotten food), `grub`, `rotten`, `guts`. Item shapes `rod`,
`fishing_rod` and `hook` (the knap grid at a small cell size) in
`Assets._item_mesh` and `icons.gd`.

**Baiting** (`work_spot.bait_options`): the static recipe with `bait: true`
(`in` names meat bait, for the book) is replaced in `options()` by one option
per bait-tagged pile laid beside a laid fishing rod (`in` the rod and that
bait, `bait` its id), or one missing "some bait". `_finish` gives the rod back
with `Items.bait_data(bait)` (`{"bait", "name": "Fishing Rod (…)"}`). A rod
with data can't be laid out, so a baited rod can't be baited again:
`work_spot.lay` says "This rod is already baited." (other data: "Keep the
… in your bag.").

**Fishing** (`src/world/fishing.gd`, `player.fishing`). Use with a held
`fishing` item: with a line out, `reel()`; otherwise `player.cast_rod()`,
which refuses without `data.bait` (naming the craft button with
`Settings.button_name`: keyboard, gamepad (`using_pad`, set by the last
input) or touch), else casts with a thrown stone's velocity. While the line is out the held
rod is drawn as the bare `rod_blank` (`player._held_cast`), since the line
draws its own hook and line from `rod_tip()`. The line
(top-level node) flies the hook with the same gravity, wind drag and steps as
`thrown_rock.gd`; into water it is "waiting" (a ripple, no lure), on land or
against a trunk "ground". `line_len` starts at the level distance; you can
step back up to `SLACK` (5 m) past it and the hook stays put (out of reach
of what is in the water); further, `_drag_hook` drags it after you, at
`line_len + SLACK`. Waiting with bait, every `BITE_EVERY` (5 s) rolls
`BITE_CHANCE` (15%) for `bite()`: the bait comes off the rod (`replace` with no
data) and `rod_tug` = 1; `NIBBLE_CHANCE` (30%) of bites end there. Otherwise
`pick_species` (by `fish.weight`: 70 / 24 / 6) makes a fish Creature with
`hooked_by` set, state "hooked". `_fight`: in water the fish swims away from
the player (weaving) at its `speed` where the water is deeper than -0.15, and
`line_len` grows by `fish.pull` m/s up to `MAX_LINE` (30 m); held there for
`ESCAPE_TIME` (3 s, `_slack_t`, with a warning and a hard tug) it gets away
(freed, ripple), unless a reel takes line back first. Each `reel()` takes `REEL_STEP` (1.2 m) off `line_len`
(down to `AT_FEET` × 0.8). The fish is held to `line_len` from the player
(dragged), at the surface in water or on the floor on land ("landed": no
swimming, no pull). Over a finished dock's or raft's deck (`deck_top`) it is
landed too, hauled up onto the deck rather than left in the water under it,
and it never swims in under one; a fish on a deck flops and suffocates as on
land, and dies where it lies (`creature._floor_below`). At `AT_FEET` (1.8 m) on land it says to strike it. Every
`PREDATOR_EVERY` (2 s), in hostile worlds, each ambusher or lurker within
`PREDATOR_RANGE` (12 m) has `PREDATOR_CHANCE` (20%) of `taken_by`: it
lunges (`lure`), the fish is freed. A landed fish out of `SHORE_REACH` (6 m) of
deep water is safe. The line ends (`end`) when reeled in empty, the fish
dies (`fish_died`, from `creature._die`), gets away or is taken, or the rod
is no longer held (a fish in the water is then lost, one on land left
flopping). `sleep_blocker` refuses with a line out. The line is drawn as a
line strip from `rod_tip()` (the held mesh's tip) to the hook or the fish's
mouth, sagging while it waits; the hook and a bead of the bait's colour show
until a fish is on. `player.rod_tug` (0..1, decaying) jerks the hand; the line
keeps it at 0.45 while a fish fights in the water.

**Fish** (creature.gd, behavior "fish", habitat "water", caps 0: never
spawned). Thirteen, by `fish.weight` (bites out of ~100): small ones (picked
up; each `carcass` item cooks to its roast and has `as` "small_fish", so the
meat bait recipe takes any) `haplolepis` 26, `elonichthys` 22,
`amphicentrum` 10, `acanthodes` 9, `bandringa` 3; medium ones (carried;
`drops` in `fish_meat`, `meat` "fish_meat", which the butcher's cut stage gives
instead of raw meat, and `cuts_left` counts) `rhabdoderma` 9 (3), `ctenodus`
7 (4), `sagenodus` 5 (4), `megalichthys` 4 (6), `xenacanthus` 3 (5),
`rhizodus` 1 (10), `strepsodus` 1 (10), `orthacanthus` 0.8 (14). Every fish
is built by `_build_fish` (in place of a `_build_<species>`) from `fish.len`,
`col` and its look keys: `depth` (body height), `slim`, `snout` (Bandringa's
paddle), `shark` (dorsal fin set back, long upper tail lobe), `head_spine`
(xenacanths), `spines` (acanthodian fin spines), `lobes` (coelacanth fins);
body, belly, eyes, fins and a tail pivot that beats. Behaviour keys: `air`
(lungfish: `suffocate_time()` is `SUFFOCATE` × `AIR_MULT`, 450 s), `bite` /
`bite_reach` / `snap_every` (landed, `_snap_at_player` calls `player.hurt` in
hostile worlds: Xenacanthus 6 within 1.5 m every 2.5 s, Orthacanthus 14
within 2.3 m every 2 s), `spines` (`player._attack`: a live one punched with
nothing in hand costs `SPINE_PRICK` 4 blood and a wound; blades and the
carcass are safe) and `lure` (Orthacanthus 2: `fishing._check_predators`
multiplies the amphibians' range and chance). `pull` sets how hard it takes
line (Megalichthys 1.0 against Ctenodus 0.6). The debug panel's **Next fish**
sets `Fishing.next_fish` (a static), which the next `bite()` uses, skipping
the nibble roll, then clears. `_think_fish`: in water the tail beats; on land
it lies on its side and flops in place, dying after `suffocate_time()`. Dead, it is an
ordinary carcass (lying on its side at the floor or the surface), so
scavengers eat it and it is saved like any other.

`cloth_sack` (8 string, 8 steps, hand, `known_by` spindle) shares the frond
sack's weaving workpiece in string colours. A stash (`stash.gd`) keeps its
`sack_id` (saved as `"sack"`, an older save's being `fiber_sack`):
`capacity()` is that item's `stash` (50 or 100 kg), its mesh `stash` or
`stash_<id>` (the cloth one paler, smoother and 1.2× the size), its prompt
and the stash panel's title name it, and picking it up gives it back.
`swamp.place(kind, pos, item)` passes the held sack. `bow_drill` (2 sticks,
1 string, 3 steps, bench, `known_by` spindle) replaced the hand recipe; the item itself is unchanged. `Assets.whorl()` draws the
whorl (the items, the workpieces and the spindle on the rack).

**Moving a bench.** `axe_hit` and `break_apart` (axe or mattock) call
`workbench._hit()`: `LOOSE_HITS` (3) blows within `HIT_WINDOW` (4 s) knock it
loose. Its rack tools go to the bag (or `spawn_pickup` when it's full) and
`player.start_haul(self)` picks it up. It has the hauling interface (`carry`,
`haul_name` "workbench", collision 0 while hauled) plus two optional hooks the
player calls: `haul_use(player)` on right-click (player "use") puts it down,
and `can_put_down()` refuses (and says why) when `bench_blocker` does. Set
down, it sits at `bench_height`, upright, and gets new feet. Saved while
carried, it is saved where it would be set down. `bench_ahead` skips a hauled
bench.

Two more recipe fields: `tool_tag` asks for any tool with that tag laid out
or in the bag (the ash pencil's "cut": a chert blade or a stone axe), named
by `Items.TAG_TOOLS` in `missing_for` and the book. An input whose item has
`empty` is used up and its empty container given back in `_finish` (a Pot
of Boiled Water has `as` "pot_dirty", so either pot will do where a recipe
wants `pot_dirty`). The wet sheet wants `any_water`, which `counts_as` takes
from any of `Items.ANY_WATER` (pots, canteens and flasks of swamp or boiled
water); one serving goes, and the canteen or flask comes back one serving
lighter. The paper items are `paper_wet` (cooks into `paper_sheet`),
`pencil_core_unfired` (cooks into `pencil_core`) and `ash_pencil`, in the
"Writing" category (`paper_wet` is `listed`, so the book shows it there rather
than on the Rack tools page); the papermaking tools themselves are made under
"Workbench" with the other rack tools. None of them has `energy`, so none chars in a fire.
Small work is drawn bigger at the spot (`work_spot.ZOOM`, the work mesh's
scale; marker targets are scaled with it).

The rack has `SLOTS` (4) pegs. Items with `rack` (clay platter, woodworking
tools, papermaking tools, spindle: exactly four, so they fill it) hang there: E at the bench while holding one calls
`hang(id)` (one of each kind). Each hanging tool is a `RackTool` child body
(layer 2) whose E calls `take_down(slot)`. Long tools hang upright by the
handle. Saved as `"workbenches"`: `{pos, yaw, tools}`. Dev: `--bench=tool,...`
puts one 1.6 m ahead with those tools (and teaches them), `--at-bench` works at it, and
`--make=item --work-steps=N` lays out that recipe and begins it.

### Pencil wear and blueprints

Items with `uses` (the ash pencil, 50) wear one use at a time: their slot
carries `data` from `Items.uses_data(id, left)` (`uses_left`, and a name
like "Ash Pencil (49/50)"). `Inventory.uses_left(i)`, `most_uses(id)` and
`wear(id, need)` (wears the most worn one with at least `need` uses left;
returns uses left, 0 when it is gone). A recipe with `wear` and `sharpen`
(step indices) wears its tool on those steps (`work_spot._wear`, from the
bag or its pile); `missing_for` asks for one with `sharpen.size()` uses left,
and the book says so. The blueprint item `blueprint_softwood_house` (shape
"blueprint", "Writing" category, bench tier, `tool_tag` "cut") has
`blueprint` "softwood_house". Its drawing is `Assets.BLUEPRINT`: line
groups drawn one a step on the sheet (`blueprint_lines`, `line_on`).

## Houses (`src/world/house.gd`)

A house is a `Node3D` (group "houses", `Game.houses`) whose origin is the
middle of the floor top, +Z out through the doorway to the porch. `PARTS`
lists its parts in build order, each with `in` (items from the bag), `tools`
(kept), `log` (a carried Calamites log or stripped log), `steps`, `from`
("ground" or "floor"), and `stand`/`face` (where you are put to build it).
`built` maps part id → the items it took; `build_to(n)` builds the first n
for dev and tests.

- **Holding a blueprint**: `player._update_plan` keeps a `preview` house
  (all outline, no collision) at `swamp.house_spot(player)` ({at, yaw, why}:
  `EDGE + 2.6` m ahead, floor `FLOOR_H` above the highest ground point),
  red with `why` from `house_blocker` when it can't go. Right-click
  (`_use_held`) calls `swamp.place_blueprint`, which calls `add_house`.
- **The outline** (`_ghost`, `holo()` material) shows every unbuilt part;
  `_outline` is a layer-2 body so E (`interact` → `scene_base.start_house_work`)
  and axe hits (`player._attack` → `axe_hit`) find it. `_body` (layer 1,
  "hard") is the built part's collision, rebuilt per part.
- **Building**: `start_house_work` puts you at `stand_point`, facing
  `face_point`, and opens a `WorkSpot` with `house` set (and `house_log`, the
  log from your arms). The spot delegates `options`/`missing_for`/`begin`/
  `cancel`/`step`/`instructions`/`look_point`/`eye_height` to the house
  (`recipe_for(part)`, `step_how`, `marker`); the marker is drawn on top at
  the next piece to place. Finishing calls `finish_part` and closes the
  spot; the last part emits `Game.crafted("house_built")`. A carried log at
  the site (`wood_log._stilt_site`) offers the stilt in its haul prompt.
- **Teardown**: `TEARDOWN_HITS` (3) within `HIT_WINDOW` (4 s) on an unfinished
  house: logs back via `add_log`, everything else as piles, and anything
  standing on its floor dropped to the ground.
- **Falling**: `swamp.floor_below(p)` is the highest floor, deck or ground
  under p however far above it p is; an animal killed in the air (or dropped
  from jaws) comes to rest on it (`creature._floor_below`), so a dragonfly
  struck over a dock lies on the deck.
- **Floor**: `swamp.floor_height(p)` is the max of the ground and any
  house's `floor_top(p)` below p (only when p is up at the floor: from
  0.8 m under it to `WALL_H` + 1 above). Stashes, piles, drops, the bench,
  work spots, `add_log`, `add_soup_pot`, `add_vessel` and `add_guts` all use
  it, so a pos passed at floor level (a saved position, a bench's spot, a
  log being cut) stays on the floor, and a reload puts things back there.
  `add_guts` only adds to a pile within 1 m of the same height. Kneeling at
  wood (`_start_wood_work`) stands you at `floor_height` at your own height,
  and kneels where you are if the usual spot is off the floor. Campfires are
  refused on a wooden floor.
- **Ladder**: `player._ladder` (close to `LADDER`, facing in or out) sets
  `climbing`; the climb runs in house space at `CLIMB` m/s and steps you
  onto the porch at the top. Anything hauled comes too: `_hold_haul` slings
  it on your back, out from the house, there is no prompt and `put_down`
  refuses. Hauled things set down (logs, carcasses, soup pots, vessels)
  stand at `floor_height`, so on a house's floor. Set down while you stand
  on a floor, `player._keep_on_floor` first draws one held out past a wall
  or the porch's edge back toward you until it is over the floor, and a dragged carcass
  follows the floor too; a log's `in_water` goes by the floor. The fireplace
  is in `Game.fires`, so a pot or vessel put down within `HANG_R` of it
  hangs over it (`--house=all --soup-pot` shows one there).
- **Shelter**: `Game.sheltered(pos)` (a finished house `covers` it: inside
  or on the porch, on the floor). Creatures drop you as quarry while it is
  true (`creature.gd`), `sleep_risk` zeroes the dangers, and spawns skip
  `house_at(pos, 6)`.
- **Fireplace**: a `Campfire` child with `hearth` (no stone ring, called
  "Fireplace", `break_apart` refused) at `HEARTH`. It is saved inside the
  house, not in "fires". A soup pot hung there drops its tripod and hangs by
  cords from a stick across the hood's mouth (`Assets.hearth_pot`), turned
  to the fireplace.
- **Saving**: `"houses"`: `to_dict` ({pos, yaw, built, fire}), restored
  before stashes so they land on the floor.

### Bedroll (`src/world/bedroll.gd`, `swamp._place_bedroll`)

`bedroll` (by hand, `known_by` spindle, Gear, 8 string, 8 steps woven like
the cloth sack) has `place` "bedroll". `swamp._place_bedroll` tries 1.0 m,
0.6 m and 0 m in front of the player. A spot counts only if it is in the
room of a finished house (`House.room_spot(p, inset)`: complete, on its
floor, inside the walls by half the roll's `LENGTH`, not the porch), and not
within 1 m of a built fireplace's `HEARTH`. It is never unrolled: set down on the floor
(`floor_top`) across the player's view, it is a `StaticBody3D` on layer 2
(group "bedrolls", saved as `_world_state` → `"bedrolls"`: pos, yaw). It
looks like `Assets.bedroll`: a burlap roll, rolled layers at its ends, two
cord ties.

Looking at it:
- **Sleep** (`player._unhandled_input` → `focus.sleep_on` →
  `swamp.sleep_on_bedroll`): lies down at once, with no confirming second
  press, if `sleep_blocker` allows (tired: `Game.can_sleep_in`, not hunted,
  not bleeding badly...). It calls `sleep(true)`, which sets
  `vitals.on_bedroll` for `_pass_time`. Asleep on a bedroll, the rest factor
  (blood, sickness, venom) and wound healing are `Survival.BEDROLL_HEAL`
  (1.5×) the usual sleep rate. Sprains and fractures still mend one step a
  sleep.
- **Interact** (`swamp.save_at_bedroll`): `save_now()` without sleeping,
  unless `suspend_blocker` says no (hunted, in jaws).
- **Right-click** (`use_interact`): back into the bag.

When a house is torn down (`_drop_what_stands_here`), a bedroll in it
becomes a dropped `bedroll` item on the ground. `Settings.hint` now turns
"[Z]" into the sleep button.

## Fire (`src/world/campfire.gd`)

A placed campfire holds `fuel` seconds (starts at 480 when placed, max 2400).
Burning uses 1 fuel/s, 1.8/s in rain. Fuel values (seconds): stick 160,
charred stick 80, frond 40, tinder 32, charred remains 20.

- **Lighting**: E with a `fire`-tagged item in the inventory (bow drill), or
  with a lit torch in hand, or by blowing (E) on an ember or live coals
  (`can_blow()`: unlit, `fuel` > 0, and `ember` or `coals` > 0). A lit fire
  lights torches. Lighting (`_set_lit(true)`) clears `coals` and `ember`.
- **Coals**: `burn_t` counts seconds burning since it was lit (fuel used ÷
  the rain rate). When the fuel runs out, `coals` = `burn_t` × `COAL_MULT`
  (3) seconds of glowing (`glowing()`), counted down by `_cool` (× 1.8 in
  rain); a long step (sleep's `f._process(seconds)`) carries on into the coals.
  Coals draw a bed of red `glow` blobs and a dim red light (range 3.5). They
  can't cook (`cook` needs `lit`). With no fuel in, E takes an ember
  (`take_ember()`). With fuel, E blows them back into flame.
- **Embers**: the `ember` item (`decay` 180 s = 3 game hours, `spoil` "", so
  nothing is left; `goes_out`: a `Pickup` of it ages by `Game.time` and frees
  itself, so it goes out on the ground and through sleep too). Held at an
  unlit fire with fuel and no coals, E sets it in the tinder: `ember` = the
  item's time left, drawn as the ember mesh with a faint light. E again
  (`can_blow`) lights the fire; left alone it goes out (`_cool`). The prompt
  guides each step: "Add fuel before you set the ember in it", "Set the
  ember in the tinder", "Blow on the ember/coals", "Take an ember". An unlit
  fire with none of these asks for "an ember, a bow drill or a lit torch".
- **Visuals**: a small fire: 9 ring stones at r 0.66, light range 7 m and
  energy 1.0, crackle at −15 dB out to 14 m. Flame height follows the fuel.
- **Cooking spots**: `SPOTS` = 6 places on a ring (r 0.44). Each is a
  `CookSpot` child body you can look at and take from (E). Each spot and each
  ring stone sits on the ground under it (`_lift`, clamped −0.3 to 0.4 m),
  not at the fire's own height, so on a slope nothing sinks out of sight. `cooking[i]` is
  null or `{id, t}`; `result(i)` gives the raw item, its `cook` item once
  `t ≥ cook_time`, or `charred` once food (anything with `energy`) reaches
  `BURN` × 4 its cook time. Pots never burn. Nothing leaves the fire by
  itself; the player is notified when something is ready or burning.
- **Cook times** (seconds): grub 16, fiddlehead 20, seed 24, gnawed meat 24,
  raw meat 40, pot of swamp water 48, unfired pot 100.
- **Ash**: `burned` counts seconds burned; `ash()` = one per `ASH_EVERY`
  (200 s). E with a `dig` tool scoops it out.
- **Breaking**: swinging a `dig` tool at the fire (`player._attack` falls back
  to a ray at interactables) calls `break_apart()`: 2 river stones back, plus
  the ash, cooking items dropped as pickups, fire removed.
- **Saving**: `to_dict()` / `from_dict()` keep position, fuel, lit, burned and
  the cooking spots.
- Predators flee a lit fire within 9 m and won't attack a player within 7 m
  of one; nothing spawns within 25 m of one.

## Canteens

`canteen` (1.2 kg, 80% of a `pot`) is made at a bench with
`woodworking_tools` on the rack: 1 board, 2 wax, 1 cordage, 6 steps. Its
contents are separate items, `canteen_<dirty|clean|soup|soup_spoiled>_<1|2>`,
each serving adding 1.5 kg; `empty` steps `_2` → `_1` → `canteen`. Drinking
(`player.consume_slot`) or washing wounds (`treat_slot`) puts what is left
back in the same slot (`inventory.replace`), keeping a soup's `data` and age
when what is left is still food. `hold` on `canteen` and `canteen_dirty_1`
fills them to `canteen_dirty_2` at the water (also in place). A soup pot
scoops into any container in `SoupPot.SCOOPS` (held id → contents kind →
result: `pot` takes one serving; a canteen two of the same kind); a second
serving of soup averages the two (`SoupPot.mix`) and keeps the older age.
Canteen soup `decay`s like a Pot of Soup into `canteen_soup_spoiled_*`.
Canteens have no `cook`: they never go on a fire.

## Fermentation (`src/world/ferment_vessel.gd`)

Recipes `vessel_open_unfired` (8 clay) and `vessel_sealed_unfired` (10 clay):
bench tier, `rack` "clay_platter". A vessel (groups "vessels" and
"fire_pots") is carried like the soup pot (`haul_*`, `haul_lift` 0.55) and,
put down within `HANG_R` of a campfire nothing else is on, sits in its
middle (`fire`); "fire_pots" (soup pots and vessels) keeps it one to a fire.
`advance(dt, lit_s)` fires it (`FIRE_TIME` 150 s), heats it (`HEAT_TIME` 60
s to the boil, which cleans `dirty` water; `COOL_TIME` 180 s to cool;
`cool()` under `COOL` 0.3) and ferments.

- State: `water` (servings), `dirty`, `salt` (sealed), `items` [{id, t
  seconds fermenting, age}], `rancid`, `brew_t`, `heat`. Each up to `CAP` (10).
- `mode()`: "lacto" (unsealed), "salt" (sealed, salt > 0), "alcohol" (sealed).
- `spoil_reason()`: food > water; salting, food > salt; otherwise any raw
  meat (`is_raw_meat`: uncured meat that has a `cook` and a `sick` chance,
  so not grubs), or uncured meat (`is_meat`: base food with protein; cured
  meat doesn't count) over `MEAT_SHARE` (30%) of the food. `_check()`
  turns the mix rancid (every item to `rotten`, `_had_meat` kept), or salts
  every uncured item at once ("salted:"). `would_spoil(id, salt)` previews it
  for the prompt and the window.
- `add_food` needs it fired, not rancid, `Items.can_cure`, clean water (or
  none) and cool. `pour(clean)` from `POURS` (pots and canteens of water; no
  swamp water onto food). `add_salt` (sealed only). `take(k)` gives {id, age}
  and, salting, a measure of salt. `fill_dirty()` (E carrying it at the water,
  `haul_interact`) empties it and fills 10 swamp water; meat in it (or rancid
  meat) calls `swamp.blood_in_water`.
- Fermenting (lacto and alcohol, clean cool water, not rancid): each uncured
  item's `t` runs to `FERMENT_TIME` (1440 s, a game day) and becomes
  "pickled:" or "spirit:"; brewing, `brew_t` too. `alcohol_ready()` from
  then: `draw_alcohol()` (E with a canteen) takes a serving of water, never
  leaving more food than water, and makes `canteen_alcohol` with `DRAW` (10)
  measures in its slot `data` (`Items.measures_data`).
- E: pour, draw, salt or food by what you hold, else open it; right-click
  (`use_interact`, which `player._use_held` calls first on its focus) opens
  it: `swamp.open_vessel` → the inventory UI's vessel page
  (`_refresh_vessel`, `_vessel_do`), which closes if you walk away. C carries.
- Saved as `"vessels"` with `hung`; `_pass_time` advances everything in
  "fire_pots". Dev: `--vessel=open|sealed|brew|salt|pickled`.

### Cured food (`Items.CURES`)

A cured item is "pickled:", "spirit:" or "salted:" before a food's id.
`Items.def` builds its definition from the food's (`_cured_def`, cached):
renamed, energy, protein, greens and starch × `boost` (1.1; salted 1.0),
then `extra` added (pickled and spirit: greens and starch +3), `decay` × 2,
tinted; "spirit" adds `alcohol` 1, "salted" takes `thirst` (6)
off its water. `Items.exists`, `cure_of`, `base_of` and `can_cure` (fresh
food: no drink containers (`is_drink_container`: `empty`, `measures`, or a
pot or canteen shape), nothing cured, not rotten or charred) go with it; code
that checks saved ids uses `Items.exists`. Icons are the food's own with a
coloured badge.

### Alcohol (`survival.gd`)

`alcohol` counts drinks; `drink_alcohol(n)` (from `consume` of anything with
`alcohol`: a canteen measure or "spirit:" food) adds, and it fades
`ALCOHOL_FADE` (1 per game hour). `drinks()` rounds up, so two within the hour
make 2. 2–3: water drain × 1.3, `heal_mult` 0.5. 4–5: drain × 1.7, healing 0,
speed × `ALCOHOL_SLOW` (0.8). 6–8: `drunk_sway()` rolls the camera and drifts
the view (`player._process`). 9–12: vomiting every `VOMIT_EVERY` (20–40 s),
losing `VOMIT_LOSS` water and energy. Over 12 the "alcohol" harm runs
0.75 → 1 at 16 (blind, then dead; `cause` "alcohol", eased by 4 drinks).
`canteen_alcohol` (`measures` 10, `treat` "alcohol") is used a measure at a
time by drinking or treating (`player._use_measure`). Its slot shows a
durability bar for the measures left (`Inventory.durability`, drawn by
`Icons.draw_durability` in the hotbar, bag and stash slots, above the
freshness bar).

### Preserving pots (`src/core/preserves.gd`)

- **Items**: `pot_preserves` ("Unsealed Pot of Preserves"; shape `pot_water`) and `pot_sealed`
  (shape `pot_capped`), both `preserves`. Everything is in the slot's
  `data`: `items` [{id, age}], `fluid`, `w` (weight: `Preserves.weight_of`,
  pot + `SERVING_W` 1.5 + food). An open pot's data also has `since`
  (Game.time it was filled), `name` and `desc` (`listing`). A sealed pot
  has none of those three, so it shows only the item's own name and
  description.
- **Filling**: holding a `pot`, E at a vessel with preserved food
  (`FermentVessel.interact`, refused with `fill_blocker()`) calls
  `world.open_vessel(v, "fill_pot")`. That is the vessel page with
  `inventory_ui.filling` set (`_fill_pot_page`, the "Put in" panel hidden),
  which picks 1–`MAX` (4) of `FermentVessel.preserved_indices()` into
  `_pot_pick`. "Fill the pot" calls `fill_pot_from` (the held pot, else the
  first in the bag) and closes the menu. It calls
  `FermentVessel.fill_pot(ks)`:
  - It takes the items (`take`, so salting takes a measure of salt each)
    and one serving of `water`.
  - It refuses a rancid or dirty vessel, unpreserved food, more than `MAX`,
    or a draw that would leave more food than liquid.
  - The fluid is `Preserves.FLUIDS[mode()]`.
- **Sealing**: the hand recipe `pot_sealed` (`pot_preserves`, `wooden_cap`,
  `wax`; `"seal": true`, 3 steps). A preserving pot can be laid at a work
  spot with its data: it gets its own pile (`{id, n, age, data}`, never
  merged), and `take_back`, `return_all`, `cancel` and `_take_pile` keep the
  data. `_finish` for a `seal` recipe gives `pot_sealed` with
  `Preserves.sealed_data(d)`: the food aged by the time since `since`, and no
  `since`, `name` or `desc`.
- **Opening**: `Preserves.open(inv, i)` (`player.use_preserves`, Use or the
  bag's Open button) leaves a `pot` in the slot. It adds the food with
  its ages brought up to now (`contents`), plus the cap from a sealed pot;
  what doesn't fit is spawned at `drop_point`.
- **Weight**: `Items.slot_weight(s)` is a slot's per-item weight, with
  `data.w` over the item's own. It's used by `Inventory.weight`,
  `room_for(id, data)` and the bag's swap and weight readouts.
- `wooden_cap`: 4 from a board at a bench (`woodworking_tools` rack).

## Soup pots (`src/world/soup_pot.gd`)

Recipe `soup_pot_unfired`: bench tier, `rack` "clay_platter", 10 clay and 3
boards, 8 steps. The pot is left standing beside the bench (`add_carried`).
A pot (group "soup_pots", layer 2) is a big `Assets.pot` (`SCALE` 2.8)
hanging `HANG_Y` (0.6 m) up from the top of a tripod of three boards
(`Assets.soup_pot`, 1.75 m tall, feet 1 m out, outside a fire's ring). Over
a house's fireplace it is `Assets.hearth_pot` instead (no tripod).

- **Carrying**: `can_haul`/`haul_*`/`set_hauled` like a log, held further
  out (`haul_radius` 0.9) and lower (`haul_lift` 0.15) so it doesn't fill the
  view.
  E picks up an empty or unfired pot; `craft_interact` (C, via
  `scene_base.start_work`) picks up any pot. Put down within `HANG_R` (1.5 m)
  of a campfire with no pot over it (`fire_near`), it snaps to the fire's
  centre and sets `fire`. While carried, `haul_prompt` and `haul_interact`
  (called by the player before putting down) offer filling at the water.
- **Firing**: `advance(dt, lit_s)` adds lit seconds to `fired`; at
  `FIRE_TIME` (200 s) `soup_pot_unfired` becomes `soup_pot`. Unfired pots
  refuse water.
- **Contents**: `water` (servings of liquid, up to `SERVINGS` 16), `dirty`,
  `food` (items' worth, up to `MAX_FOOD` 12), `nut` (energy, protein,
  greens, starch totals), `risk`/`raw` (raw food since it last boiled),
  `heat`, `fresh_at`.
- **Filling** (`haul_interact` with `player.focus_water`): `fill_dirty()`,
  16 dirty servings, everything else gone. If the pot held soup with protein
  (`has_meat`), `swamp.blood_in_water(player.water_point(), player)`.
- **Heat**: over a lit fire `heat` rises 1 per `HEAT_TIME` (60 s); off it
  falls 1 per `COOL_TIME` (180 s). At 1 with liquid it is `boiling()`: dirty
  water turns clean, `raw` and `risk` clear, and `fresh_at` follows
  `Game.time`. `_pass_time` (sleep) calls `advance(seconds, lit seconds)`
  using each fire's fuel before it burned.
- **Adding food** (`add_food`, E holding anything `accepts`: food without
  `empty`): needs clean water (or soup already), not spoiled, `food` under
  12. Adds the food's cooked form's values (`food_values`: the `cook`
  item's if it has energy), `food` +1, `water` + `PER_FOOD` (16/12) capped at
  16, `risk` = max with its `sick`, `raw` set, `heat` down to `RAW_HEAT`
  (0.75) so it must boil again.
- **A serving** (`take_serving`): `min(1, water)` of the liquid and that
  fraction of `food` and `nut`. Soup gives its nutrients plus `SOUP_WATER`
  (30) water, sick chance `risk` while `raw`, or half the nutrients and
  `SPOILED_SICK` (0.9) once spoiled. Water gives 40 (boiled) or 35 with a
  35% sick chance (swamp). E with empty hands consumes one; E with a `pot`
  (`scoop`) gives `pot_clean`/`pot_dirty`, or `pot_soup` with the serving as
  its slot `data` and age `Game.time - fresh_at` (it `decay`s at `LIFE`, to
  `pot_soup_spoiled`), or `pot_soup_spoiled`.
- **Spoiling**: `spoiled()` once soup has gone `LIFE` (2160 s, 36 game
  hours) since `fresh_at`. Boiling no longer helps; nothing more goes in.
- **Over a fire**: held fuel, torches and `dig` tools pass E and the prompt
  through to the fire under it (`_for_fire`).
- **Looks**: a liquid disc follows the level inside the pot, coloured by
  contents (`liquid_color`); steam while boiling.
- **HUD**: `tooltip()` is shown by `hud.set_tooltip` in a panel above the
  prompt (the player copies it from the focus each frame): state, meat,
  starch and greens per serving (percent of the 0-100 bars), and servings
  left (`servings()`, rounded).
- **Saving**: `"soup_pots"` in `_world_state`, with `hung`; a hung pot is
  re-attached to the fire within 0.3 m on restore.

### Blood in the water (`swamp.blood_in_water`, `creature.scent`)

Rings spread at the spot (`ThrownRock.ripple`, no lure). Each ambusher or
lurker within `SCENT_RADIUS` (45 m) of it gets `scent(at, player)` (hostile
worlds only): an ambusher buried (`mode` hide, state hide or return) further
from the player than `def.ambush`, or a lurker in the water (state lurk,
wander or idle, not on land) further than its trigger (`sense`), turns to
state `"approach"` for `APPROACH_TIME` (120 s): surfaced and visible, it
swims toward the player at 2× (ambusher) or 1.5× (lurker) its `speed`, only
while the way ahead (`_closing_in`) is water deeper than -0.3, otherwise it
waits facing the player. Its `home` (ambusher) or `water_home` (lurker)
moves with it. An ambusher strikes (`_strike`) once within `def.ambush` of a
player at the shore, or `strike` + 1 of one on low ground; a lurker
`_charge`s within its trigger. When time runs out, or the player is gone or
over 1.5 × `SCENT_RADIUS` away, an ambusher buries itself where it is and a
lurker lurks there. `"approach"` counts as hunting for `_hunted`. Those
already within striking reach are left alone: they strike as usual.

### Baitbox (`swamp.start_frenzy`, `creature.frenzy`, `baitbox.gd`)

`baitbox` (bench, rack `woodworking_tools`, Traps: 1 board + 2
`any_raw_meat`, 4 steps) is a `throw` item with `frenzy` 30 s. It has raw
meat's `decay` (900 s) and spoils into `baitbox_rotten` (`frenzy` 15 s). A
crafted one starts fresh, like meat bait; a thrown one keeps its age
(`ThrownRock.age`). It looks like a little wooden cage (`Assets.baitbox`,
`BAITBOX_W` 0.24 × `BAITBOX_H` 0.14 m): a base board, corner posts, two
upright bars and a rail a side, a slatted lid tied down at two corners, the
meat showing between the bars; `done` stages it for the bench (base, then
the posts and bars side by side, then the meat and lid).

Thrown (`thrown_rock.gd`), it hurts nothing it hits. If it comes down in
water (ground below `water_level()`) it makes rings (`ripple`, not a
`splash` lure) and calls `swamp.start_frenzy(at, frenzy, id)`. On land it is
a kept pickup. `start_frenzy` adds a `baitbox.gd` node that bobs and churns
the water (a ripple every 0.4–0.9 s) and sinks over 3 s when the frenzy ends.
It calls `frenzy(at, secs)` on every creature, and remembers the spot and
time left (`_frenzy_at`, `_frenzy_left`), so an amphibian that
`spawn_amphibian` makes while it lasts joins in. None of this is saved.

`frenzy()` takes any ambusher or lurker within `FRENZY_RADIUS` (65 m), except
one with hold of the player (`grab`) or an ambusher carrying a kill (`feed`).
It drops guts it was `drawn` to and any prey or blood scent. The ambusher's
`home` (mode `hide`) or the lurker's `water_home` and `home` move to the box,
and it enters state `"frenzy"` (surfaced, visible; 35% roar). It comes only
through the water: `_water_path(from, to)` is a breadth-first search over a
`PATH_CELL` (2 m) grid round the two (24 m margin) of cells whose ground is
under `water_level()` (`_wet`), straightened where a straight line stays wet
(`_water_line`, sampled every metre), and kept in `_frenzy_path`. One out of
the water, or cut off from the box by land, gets an empty path and takes no
notice. `_frenzy_goal` follows the waypoints, then the lunge spots, which
are only picked in the water; in `"frenzy"`, `_steer` never steps from
water onto land (it slides along the shore, trying turns of ±0.5, ±1 and
±1.5 rad). It races there (ambusher
0.8 × `run`, lurker `run`) until within `radius` + 6 m, then lunges at random
spots round the box (`_pick_frenzy_spot`: `radius` × 0.5 to `radius` + 3 m,
a new one every 0.5–1.5 s), rolling, snapping and now and then splashing
(`_thrash`). It ignores other animals. It still attacks the player as it
normally would, if not `_calm`: an ambusher `_strike`s within `strike` + 1
of a player on low ground (it is surfaced, so not the buried `ambush`
reach); a lurker `_charge`s within its trigger. A `retreat`/`return` (a failed
charge, a released grab) goes back to `"frenzy"` while time is left. When
the frenzy ends, an ambusher returns to the box and buries itself there, and
a lurker lurks there. `"frenzy"` is not hunting for `_hunted`, and `lure` and
`scent` ignore animals in it.

## Torches and wax

- **Waxy Residue**: 1 frond crushed with a river stone (steps recipe, 4
  clicks).
- **Torch**: 1 stick + 2 wax, twisted. **Re-dip**: 1 charred stick + 2 wax.
- A torch held at a lit fire becomes `torch_lit`: `decay` 840 s (14 min),
  `spoil` → `charred_stick`, `light` 9 m. `swamp._age_torches` adds an extra
  second of age per second in rain (so it burns twice as fast) and announces
  when one burns out.
- `player._update_torch` shows an `OmniLight3D` in the hand while the held
  item has `light`; in rain its range drops to 40% and its energy to 0.25.

## Food

At the time of writing (`items.gd` is the source of truth):

| Food | Energy | Protein | Greens | Starch | Water | Sickness | Spoils after (s) | Cooks into |
|---|---|---|---|---|---|---|---|---|
| Seed Fern Seed | 6 | | | 10 | | | 1800 | Roasted Seed (12 energy, 16 starch) |
| Fiddlehead | 3 | | 10 | | 2 | 10% | 900 | Cooked Fiddlehead (6 energy, 15 greens) |
| Beetle Grub | 5 | 9 | | | 1 | | 600 | Roasted Grub (9 energy, 13 protein) |
| Raw Meat | 8 | 14 | | | | 50% | 900 | Cooked Meat (24 energy, 26 protein) |
| Gnawed Meat | 3 | 5 | | | | 50% | 600 | Cooked Scraps (8 energy, 9 protein) |
| Charred Remains | 1 | | | | | | | (fuel, 20 s) |
| Rotten Food | 2 | | | | | 90% | | |
| Pot of Swamp Water | | | | | 35 | 35% | | Pot of Boiled Water (40 water) |

Cooked food keeps longer than raw (1200–2400 s).

## Creatures (`src/creatures/creature.gd`)

`SPECIES` defines each animal: `behavior`, `habitat` (land, amphibious,
air), hp, speeds, collision and hit radii, `sense`, attack numbers,
`drops` (`raw_meat` is the cuts of meat on the carcass, `chitin` what its
shell gives), `size` (small, medium, large: how its carcass is handled),
`carcass` (the bag item for a small kill), `guts` (handfuls left by gutting),
spawn caps by day and night (prey instead have `prey` weights [day, night]
in the shared prey pool), and flags such as `scavenger`.

Every species belongs to a category (see [Categories](#categories-for-adding-animals)
below). Categories are a design rule for now and are only in the code for
prey (the shared pool and `behavior == "prey"` checks).

| Species | Category | Behaviour | Notes |
|---|---|---|---|
| uranocentrodon | large | ambusher | Basks on banks or lies buried in shallows; strikes anything at the edge, drags it to deep water. Escape roll. |
| eogyrinus | large | lurker | Spawned by the swamp near water; charges and grabs. Stab to break the grip. |
| scorpion (Pulmonoscorpius) | hostile medium | hunter, scavenger | Night only, not in the first minutes (`_calm_until`). Venom. Flees fire. |
| arthropleura | neutral medium | defensive, scavenger | Leaves you alone until hit (`_anger` 25 s). |
| meganeura | predator insect | flyer | Circles, nips the player, snatches small prey and eats them where it lands. |
| hylonomus | prey | prey | Flees the player within `sense`. Food for other animals. The commonest prey by day. |
| petrolacosaurus | prey | prey | Long legs and tail: `run` 8, `sense` 12. Mostly by day. |
| archaeothyris | prey | prey | Biggest prey: hp 14, slower, 2 meat (`radius` 0.34, still under `ThrownRock.SMALL`). |
| amphibamus | prey | prey | `spawn` "shore": spawned by `shore_spot` on the bank, where the big amphibians take it. Small. |
| tuditanus | prey | prey | The commonest prey by night (`prey` [0.5, 2.5]). |
| morganucodon | prey | prey | A tiny furry early mammal (out of its time, like Uranocentrodon): `radius` 0.18, hp 4, the smallest meal. A thin tail (`tail_r`) and ears and snout from `_marks_morganucodon`. More at night (`prey` [1, 1.5]). |

A basking Uranocentrodon stalks the player from `STALK_RANGE` (30 m) while
the player is on low ground, but only moves while it stays within
`leash * 1.5` of its water. A buried one strikes from `def.ambush` (16 m)
when `swamp.player_at_shore` is set: the swamp checks every 0.2 s whether
there is water deeper than `WATER - 0.1` within `STRIKE_BAND` (6.5 m, about
twice the drinking reach). While striking, stalking or provoked its leash is
10 m longer.

`Game.hostile()` (false only in a debug world with hostility switched off)
gates the player as quarry for hunters, lurkers, ambushers and flyers, and
zeroes the animal parts of `sleep_risk`.

### Scavenging

Land animals with `"scavenger": true` run `_forage` while not angry:

1. Every second, look for a living small prey animal (`behavior` "prey") within `FORAGE_RANGE` (9 m) and
   `hunt` it (12 s limit). Failing that, the nearest guts pile or carcass it
   could eat (`_food_near`: guts, small carcasses, and medium ones for medium
   animals) and `scavenge` toward it (15 s limit).
2. In reach of its prey, `maul` it (wind-up, then damage).
3. Once it is dead (or at the food), `feed` (`_start_feeding`) for
   `FEED_TIME` (5 s; guts 1.6×, a medium carcass 4×). The food gets
   `eaten_by` (and a carcass `gnawed`), and its body shrinks as it is eaten.
   Then it is freed and the scavenger rests 40 s (`_cd`).

A hunter (the scorpion) only starts foraging when the player isn't within its
`sense`, and drops its meal to fight a player who comes within reach. While
something eats a carcass, the carcass prompt is *Snatch*. Taking it gives
`gnawed_meat` (half the species' raw meat, at least 1), frees the carcass and
calls `provoke()` on the eater (anger 25 s, chase, no cooldown). A small
carcass the eater has left half-eaten also only gives gnawed meat; a medium
one snatched from an eater loses half its `cuts_left`. Hitting a feeding
animal also makes it stop feeding.

### Carcasses and butchering

`_die` keeps the body as a carcass: `died_at`, `stage` (whole, gutted,
skinned) and `cuts_left` (from `drops.raw_meat`). `expired()` is true a day
(`DAY_LENGTH`) after death, and `swamp._spawn_creatures` frees expired
carcasses. Carcasses not being eaten are saved (`carcass_dict` →
`"carcasses"`, `restore_carcass`).

- **Small** (`size` small): E (`take_small`) puts `def.carcass` in the bag,
  aged by the time since death. `lizard_carcass` → recipe *Gut and skin*
  (by hand, recipe fields `dress: true` and `guts: 1`, which leaves a guts
  pile with the skin) → `lizard_dressed` → cooks to `roast_lizard`. The other
  prey follow the same pattern: `<species>_carcass` → `<species>_dressed` →
  `roast_<species>`. `dragonfly_carcass` cooks
  straight to `roast_dragonfly`. Kneeling (C) at a small kill picks it up and
  lays it out.
- **Medium / large**: E calls `player.start_haul`. `haul_mode()` is `carry`
  (held at chest height in front) or `drag` (on the ground in front, half
  walking speed). While `player.hauling` is set there is no sprinting, use,
  attack, pickup, bag, crafting or sleep; Q or E calls `put_down()`. It is
  dropped when grabbed or on death. Hauling adds no weight.
- **Butchering in place**: C at a medium or large carcass
  (`scene_base.carcass_ahead`) kneels with `work.carcass` set. The work spot
  then offers `butcher_option()`, the stage from `Items.BUTCHERING`; every
  stage needs a `cut` tool, laid out or in the bag. Steps put markers along
  the body, drawn on top. Gutting adds `def.guts` to a pile beside it;
  skinning gives `drops.chitin`, or throws the skin on the guts pile; cutting
  gives one `raw_meat` per step and frees the carcass after the last.

### Woodcutting

Trees are `chunk.trees` entries: `{uid, kind, at, s, yaw, r, i, shape, trunk,
crown, stump, xform, mm}`, the uid from the position so it is stable across
loads. `Chunk.TREES` gives each kind `height` (tree units) and `soft`:
Calamites and tree ferns are soft; Lepidodendron and Sigillaria need a metal
axe (none yet). Trees stand `SINK` (0.2 m) into the ground.

- **Felling**: C beside a standing tree (`swamp.tree_ahead`, 1.6 m) kneels
  with `work.tree` set; holding a `chop` tool there, `player._axe_prompt`
  shows "Kneel to fell the ... [C]" (or that a stone axe can't fell a hard
  one). `work_spot.wood_options()` offers the
  `Items.WOODWORK` entries `on` "tree": steps `clamp(round(r * 20), 5, 10)`,
  needs a `chop` tool (laid out or in the bag) and a soft tree. The last
  stroke calls `swamp.fell_tree(tree, away)` → `chunk.fell(t)`: the instance
  is scaled to zero, the collision disabled, `Game.felled[uid] = {at, regrow,
  kind}` with `regrow` 16–20 days on (`REGROW`), and a `Stump` added. Chunks hide felled
  trees and add their stumps when they load, keeping the same RNG calls so the
  rest of the chunk is unchanged.
- **Stumps** (`stump.gd`, layers 1|2, "hard"): the mesh is
  `Assets.tree_part(kind, -INF, (SINK + STUMP_H) / s)`. A sapling (the whole
  tree mesh scaled `lerp(0.04, 1, growth)`) grows out of it; at full growth
  `chunk.regrow(t)` restores the tree and erases `Game.felled[uid]`. A swing
  of a `dig` tool calls `dig()`; `DIG_HITS` (5) blows give 2–3 firewood and
  `chunk.clear_stump(t)` sets `cleared`, so nothing grows there again. It
  also gives one `<kind>_root` (`plant_tree` kind), piled if the bag is full.
- **Shoots**: a Calamites or tree fern stump (`Stump.SHOOTS`) under
  `SHOOT_UNTIL` (a third) grown, not burnt, offers "Pick the shoot": E gives
  `<kind>_shoot` and restarts the regrowth (`at` = now, `regrow` = now + the
  old span), setting `picked`: no new shoot until a `DAY_LENGTH` later
  (`shoot_wait`, shown in the prompt).
- **Struck stumps**: `swamp.strike_tree(tree, away)` (the arrival's lightning)
  is `fell_tree` without the "felled" signal, with `chunk.fell(t, true)`
  adding `burnt` = `Game.time` to the felled state. A burnt stump never
  regrows: `growth()` is 0, `_update` never calls `regrow`, and a loading
  chunk skips the regrow check. `phase()` comes from `Game.time − burnt`, so it
  is right through sleep and reloads: "burning" for `BURN_FOR` (a day), with
  flame cones, a light (range 8) and the fire loop; "cinders" for `GLOW_FOR`
  (three days), red glow blobs and a dim red light; then "burnt". It is
  drawn charred (`tree_part` tint `CHARRED`) from the strike on. While hot,
  E takes an ember (and while burning, lights a held torch). `dig()` refuses
  until it is cold. It is not in `Game.fires`, so predators don't avoid it
  and nothing cooks or hangs on it.
- **Nearest fellable tree**: `swamp.nearest_soft_tree(pos, within)` (the
  arrival, and `--woodwork=fell`).
- **Felled trunk** (`felled_tree.gd`, group "felled", layer 2): the part of
  the tree from `lo` (tree units) up, `Assets.tree_part(kind, lo)`, its origin
  at the cut end and local +Y along the trunk. It topples over `FALL_TIME`
  (2.4 s) away from you onto the ground. C at it (the player is moved beside
  `cut_point()`, 2 m along) offers *Cut off a log* (3 steps): `cut_log()`
  spawns a `log` and moves the cut end on 2 m; the last piece becomes a log
  (≥ 1 m) or short log (0.3–1 m), with fronds for a tree fern. `touched` is set
  by the first cut. Untouched, it is `rotten()` after `ROT_AFTER` (3 days),
  searchable once (`WoodLog.search_rotten`: grubs, tinder, sticks), and freed
  `GONE_AFTER` (3 days) later. Saved as `"felled_trees"`.
- **Log kinds**: every log, stripped log, short log and log pile has the
  `kind` of tree it came from (`FelledTree.kind` → `add_log(..., kind)`,
  kept by stripping and cutting, saved as `"kind"`; old saves and dev logs
  without one get `Assets.LOG_KIND`, calamites). `Assets.log_mesh(id, kind)`
  draws it from `LOG_LOOKS`: bark colour, stripped wood colour and detail
  (lepidodendron branch stubs, calamites joint rings and branchlets, tree
  fern frond bases, sigillaria none), with the bark in the material
  `"bark_<kind>"`: a triplanar detail texture from `detail_textures`
  (diamond leaf cushions, ribs with leaf scars, fine ribs, fibres; texture X
  runs along the log). `stack_near` and `settle_log` match the kind, so each
  tree's logs pile apart. The item meshes (`item_log`...) are calamites logs.
- **Logs** (`wood_log.gd`, group "logs", layer 2): E calls
  `player.start_haul(log)`. Hauling works for anything with `can_haul`,
  `haul_mode`, `haul_name`, `haul_radius`, `haul_yaw`, `haul_lift` and
  `set_hauled` (creatures and logs). A log lying with its top below the water
  line adds to `soak`; at `ROT_AFTER` it is rotten (searchable) and it goes
  `GONE_AFTER` later. On dry ground or carried it never rots. Saved as
  `"logs"`.
- **Working logs**: C beside a loose log (`swamp.wood_ahead`) offers the
  WOODWORK entries for its id. `strip` (4 steps) gives `bark` 6 and `branch` 3
  and `set_id("log_stripped")`; `shorten` (6, barked only: short logs keep their
  bark) leaves four `short_log`s end to end; `hew` (6, stripped only) gives 4 boards of the log's tree
(`board_<kind>`, each its wood's colour, with `as` "board" so any of them
does in a recipe: `Items.counts_as`, `work_spot.laid` and `_take_pile`,
`Inventory.count_as`; a plain `board` is from an old save); `split` (3, short log) gives
  `firewood` 4. Marks sit on the wood, drawn on top; chips gather on the
  ground. `branch` → 3 `stick` is an ordinary hand recipe.

### Farming (`plot.gd`)

`Game.plantings[uid]` (saved) holds each hole: `{x, y, z, dug}` (world
position, the `Game.time` dug), `item` `{id, age}`, `compost` and `buried`
(the `Game.time` it was filled in) once something is buried in it, then
`plant` (a Harvestable kind) or `tree` (a tree kind) and `sprout` (the
`Game.time` it came up), with `s`, `yaw` and `picked` (last shoot picked).

- **Digging**: a `dig`-tagged item's Use (`player._use_held` →
  `player.dig_hole()`, 0.6 s cooldown, 6 stamina) takes `look_point(reach +
  0.5)` and calls `swamp.dig_hole(pos)`: the point must be within 0.25 m of
  the ground (no floors), above `Terrain.WATER + 0.05`, rockiness ≤ 0.3, at
  least 0.9 m from another planting and trunk radius + 0.4 from a trunk.
  The uid is `pl<x*10>_<z*10>_<time>`.
- **Planting**: C at an `open_hole()` (`wants_craft`, `craft_interact`)
  calls `scene_base.start_plot_work(plot)`, which kneels you beside it like
  a trap (`_kneel_beside`) with `work.plot` set. `work_spot.plot_options()`
  offers one "steps" recipe per laid item (2 steps; "Plant the x" for a
  `plant`/`plant_tree` item, else "Bury the x") and, with compost laid out,
  "Plant the x with compost" (3 steps). `_plot_step` shows the item, then the
  compost, in the hole (`show_planting`), and on the last click calls
  `plot.bury(id, age, compost)`, then stands you up. Leaving midway puts it
  all back. E on a hole or mound does nothing.
- **`Plot.settle(uid)`** brings a record up to the clock and says what it is:
  "hole" (an open hole, or the mound once `buried`) until `FILL_AFTER`
  (1440 s) after `buried` (an empty hole: after `dug`, then erased; an old
  save with an item and no `buried` takes `dug`); then an item with `plant_tree`
  becomes a "tree" (and `Game.felled[uid] = {at, regrow, kind, planted:
  true}`, 14 days), one with `plant` a "herb" (a "grown" one after
  `GROW_DAYS`, 14), and anything else is erased (buried). `chunk.build` and
  `chunk.add_planting(uid)` put up a `Plot` for a hole or herb, a
  `Harvestable` "planted_<plant>" for a grown one, or `_add_planted_tree`.
- **The `Plot` node** (layer 2) draws the "hole" mesh (with what is being
  planted while you kneel), the "mound" mesh once buried, or the plant's
  bare mesh scaled `lerp(0.08, 1, growth)`. Each second it settles; when the
  stage changes it asks the chunk for the next node and frees itself. E on a
  herb under a third grown picks the `SHOOTS` shoot, sets `sprout` to now and
  `picked`, and there is no new shoot for a `DAY_LENGTH` (`shoot_wait`). A
  `dig` swing on a herb gives a `fern_root` and erases it.
- **Planted trees** are chunk tree dicts like the generated ones, with a
  MultiMesh of their own and a trunk collider on the chunk's trunk body.
  While `Game.felled` has them "planted" the stump draws no stump mesh,
  only the sapling (`Stump.planted()`), with a thin collider; two `dig`
  swings give its root back and `chunk.clear_stump` erases the planting and
  the tree. Grown, `chunk.regrow` shows it; felled, it is an ordinary stump
  that regrows; dug out, `clear_stump` erases it altogether.
- **Compost in a hole**: `rec.compost` (true) beside the item. On sprouting it
  sets `rec.fed` and `rec.days` = 7 (`GROW_DAYS` × 0.5; a tree's felled
  `regrow` too); a fed planted kind's `Harvestable.interact` doubles each
  yield roll. With nothing that grows, the compost is buried with the rest.
- **Feeding**: holding `compost`, Use (`player._use_held`) calls the focus's
  `feed(player)`, taking one compost if it returns true:
  `Plot.feed` (a young herb: `sprout` moved back), `Stump.feed` (not burnt,
  not grown: `regrow` moved in) and `Harvestable.feed` (`growing()`: not
  ready, not a rotting log or clay bank: `_ready_time` and
  `Game.harvested`), each cutting `Harvestable.FEED_CUT` (0.3) off the time
  left. A kind with `fed_regrow` (planted_seed_fern, 2.5) fed within
  `FED_WITHIN` (a game day) of its harvest (`rec.seeds_picked`, set by
  `interact`; once per picking, `rec.seeds_fed`) is instead ready
  `fed_regrow` days after the harvest. Their prompts show `Harvestable.feed_hint(left)` with compost held.

### Compost (`compost.gd`)

A `compost_basket` item (`place` "compost", made at a bench with the
woodworking tools racked) sets down a `Compost` node (layers 1|2, group
"composters", saved as `composters` in the world state: pos, yaw, level,
slow, meat, done_at). `Compost.worth(id)`: branch 4, log or stripped log 10,
grubs (raw, roasted or cured) 1, stick, guts and `*_carcass` 2, any item
with `energy` that isn't `Items.is_drink_container` 2, else 0. `add(id)` raises `level` (capped at `FULL`, 20), sets `slow` to the
largest `WOODY` factor (stick and branch 2, logs 3) and `meat` if
`is_meat(id)` (protein, guts or a carcass, not grubs). At `FULL`, `done_at` =
now + `DAYS` (5) × `slow` days: 5, 10 or 15. Done, E gives `YIELD` (5) compost (piled if
the bag is full) and resets it. E with an empty hand on an empty basket picks
it up. A carried log (`wood_log.haul_prompt` / `haul_interact`, within 2.2 m
via `swamp.compost_near`) goes in from your arms. After each sleep,
`swamp._compost_pests()` asks every basket's `pest_roll` (`PEST_CHANCE` 0.15
with meat in it) and adds a Scorpion or Arthropleura 2.5–5 m from it (the
spawner frees anything over 160 m from you).

### Traps (`trap.gd`)

A `Trap` node (layers 1|2, group "traps", saved as `traps` in the world
state: kind, pos, yaw, bait, caught) is either `kind` "fish_trap" or
"snare". The `fish_trap` item is `carry`: made at a bench (rack
`woodworking_tools`), `work_spot._finish` calls `swamp.add_carried`, which
makes a trap beside the bench. It is hauled like a log (`can_haul`,
`haul_prompt`; `can_put_down` refuses water deeper than `DEEP`, 1.1 m) and
set on the bottom (`floor_height`). The `snare` item has `place` "snare":
`swamp._place_snare` (dry ground only) adds one facing you.

Baiting: `craft_interact` (C at the trap, from `scene_base.start_work`) calls
`scene_base.start_trap_work`, which kneels you beside it with a work spot
whose `trap` is set. `work_spot.trap_options` offers one recipe per bait
pile (`{trap, out, in: {bait: 1}, act "steps", steps 1}`); its one step
(`_bait_trap`) calls `trap.set_bait`, gives back any bait already in it and
closes the work.

`swamp.sleep` calls `_check_traps`, which calls `catch(rng)` on every trap:
unbaited, nothing; a fish trap `in_water()` (over 0.1 m deep) adds 1–5
`{id, at}` from `FISH` and clears the bait; a snare holding nothing rolls
`SMALL` (0.7: a random `prey` species' `carcass`), `MEDIUM` (0.1: a random
medium land hunter or defensive species, `{species, at}`) or nothing (bait
kept). An entry is rotten once `Game.time` passes `at + KEEP` (two days);
`interact` gives each as its id, or `rotten`, and empties the trap. With
nothing caught, E hauls a fish trap or puts a snare (and its bait) in the bag.

A snared medium animal: while you are within `SPAWN_RANGE` (120 m),
`_process` keeps a live `Creature` of that species beside the snare with
`snared` set; `creature._hold_in_snare` keeps it within `LEASH` (0.9 m), so
it strains and fights from there. Freed (sleep frees every live creature, the
spawner those far off), it is made again when you come back. Killed, its
carcass stays and the snare is empty; past `KEEP` it is freed and the entry
becomes `ROTTEN_MEDIUM` (3) rotten food.

### Piles (`src/world/stack.gd`)

`swamp.pile_item(id, n, pos)` adds to a same-id pile within `REACH` (1.5 m) or
starts one; items without `pile`, or anything in water, fall back to
`spawn_pickup`. Q (`player._drop_held`) and inventory Drop use it.
`swamp.settle_log(log)` (on putting a log down) joins a pile or pairs it with
a loose log of its kind into a new pile. A pile has no limit; `layout()` draws
up to `SHOWN` (12): rounds in rows of 5, 4, 3, boards and bark laid flat,
everything else in a heap. E (`take_one`) gives one to the bag, or a log into
your arms; the player holds E to repeat every 0.12 s. Saved as `"stacks"`.

### Guts piles (`src/world/guts.gd`)

`swamp.add_guts(pos, n, skin)` adds to a pile within 1.2 m or starts one
(group `guts`, saved as `"guts"` with `n`, `skin`, `made` and `roll_t`). A
pile lasts `DAY_LENGTH`. E takes one `guts` item. `swamp.splat_guts` (Q) and
thrown guts (`thrown_rock`) make a pile on land; in water they call
`ThrownRock.splash` (lures amphibians) and are gone.

Every `ROLL_EVERY` (300 real seconds) a pile within `ROLL_RANGE` (160 m) of
the player rolls `ROLL_CHANCE` (25%) for `draw_to_guts(pile, "eogyrinus")`
and 25% for `"medium"` (Arthropleura by day or before `_calm_until`,
otherwise scorpion or Arthropleura 50/50). The animal spawns 30–50 m from the
pile and 25–150 m from the player, with `drawn`, `bait` and `home` at the
pile. `_think_drawn` runs before its behaviour:

- A player within `DRAWN_NOTICE` (20 m) of it or the pile is attacked: a
  lurker `_charge()`s (leashed to the pile), others get `_anger` and run at
  the player even from beyond `sense`.
- Otherwise it goes for the pile (scavengers through `_forage`'s
  `scavenge`/`feed`; a lurker through its own `seek` and `feed` states).
- Once the guts are gone it lingers `LINGER` (180 s) with `home` at the
  pile, then becomes an ordinary animal.

### Spawning (`swamp.gd`)

`_spawn_creatures` every 1.5 s keeps each species at its day or night cap
(small prey share one pool, below),
35–80 m from the player (air 25–55 m), never near a fire, and despawns the
living past 160 m. `_spawn_amphibians` keeps Uranocentrodon around the
player's shoreline (`BASKING` 5 by day, `HIDDEN_DAY` 16 / `HIDDEN_NIGHT` 20
buried) and now and then an Eogyrinus (`EOGYRINUS_MAX` 4, `EOGYRINUS_CHANCE`
1/37 per tick).

Small prey (`behavior` "prey") have no caps of their own. Together they are
kept at `Creature.PREY_DAY` (4) by day and `Creature.PREY_NIGHT` (2) by
night. While the pool has room, each tick `pick_prey(night)` picks one
species by its `prey` weights, and that species gets the first spawn attempt
(a species with `spawn: "shore"` is placed by `shore_spot`; if no spot turns
up that tick, nothing is spawned for the pool). Weights [day, night]:
Hylonomus 4/1, Petrolacosaurus 2/0.5, Archaeothyris 1.5/0.5, Amphibamus
1.5/1, Tuditanus 0.5/2.5, Morganucodon 1/1.5.

### Categories (for adding animals)

The plan is to add many more animals. Most will be variety: a new look on an
existing animal, like a shrew that behaves exactly like Hylonomus. A few will
differ more, the way Uranocentrodon and Eogyrinus differ in health, grip and
how they hunt, and fight each other. Every animal belongs to one category.
New animals are added to a category, and changes to a category's behaviour or
spawning apply to everything in it.

| Category | Now | Shared by members | May differ per species |
|---|---|---|---|
| **Large** | Uranocentrodon, Eogyrinus | Amphibious, spawned by `_spawn_amphibians` along the player's shoreline, grab the player (`grab_dps`, `grip`), drag prey to water, lured by splashes, worst sleep risk near water | hp, bite, grip and escape rules, ambush or lurk style, basking, rivalry (an Uranocentrodon may hunt an arriving Eogyrinus) |
| **Hostile medium** | Pulmonoscorpius | Land, hunts the player on sight, scavenges small prey, flees fire, the predator part of the sleep risk | Day or night, venom, damage, chitin drops |
| **Neutral medium** | Arthropleura | Land, ignores the player until hit (`_anger`), scavenges small prey | hp, damage, drops |
| **Predator insects** | Meganeura | Air, circles and nips the player, snatches small prey, knocked down by stones, blown about by high winds | Size, damage, what it can carry |
| **Passive insects** | none yet | (To decide when the first is added: harmless, perhaps food or bait, and never a sleep risk.) | |
| **Prey** | Hylonomus, Petrolacosaurus, Archaeothyris, Amphibamus, Tuditanus, Morganucodon | Land, flees the player, eaten by medium creatures and predator insects, stunned by stones, gutted by hand and roasted whole | Look and size, speed and `sense`, hp, meat (1, or 2 for Archaeothyris), day/night weight, where it spawns (`spawn`) |

**Spawn slots are shared within a category.** Adding an animal must not
raise the number of animals in its category. A shrew added to prey spawns in
the prey slots, so the prey total stays 4 by day and 2 at night, now split
between lizards and shrews. Today's totals are the budgets:

| Category | Day | Night | Where it is set |
|---|---|---|---|
| Large: Uranocentrodon | 5 basking, 16 buried | 20 buried | `BASKING`, `HIDDEN_DAY`, `HIDDEN_NIGHT` in `swamp.gd` |
| Large: Eogyrinus | up to 4, 1/37 chance per tick | same | `EOGYRINUS_MAX`, `EOGYRINUS_CHANCE` |
| Hostile medium | 0 | 2 | `cap_day` / `cap_night` of each species |
| Neutral medium | 1 | 1 | same |
| Predator insects | 2 | 1 | same |
| Passive insects | (none yet) | | needs its own budget |
| Prey | 4 | 2 | `PREY_DAY` / `PREY_NIGHT` in `creature.gd`, shared by every prey species by `prey` weight (done) |

The two large budgets are separate because buried ambushers and roaming
lurkers spawn differently. A new ambusher would share the Uranocentrodon
slots, and a new lurker the Eogyrinus slots.

Prey are already done this way (the `prey` weights and pool, and
`behavior == "prey"` in `_forage` and `_spot_lizard`). When the first animal
is added to another category, the code needs to change to match:

1. Give each `SPECIES` entry a `category`, and a `weight` for its share of
   the slots (equal by default).
2. Move the caps from the species into a per-category table, and have
   `_spawn_creatures` count living animals by category, then pick which
   species fills a free slot by weight (skipping any that can't spawn at
   that time or place). `_spawn_amphibians` does the same for the large
   slots.
3. Replace the checks by species name with checks by category, so a new
   member gets the shared behaviour for free:
   - ~~`species == "hylonomus"` in `_forage` and `_spot_lizard`~~: done,
     now `behavior == "prey"`.
   - `c.species == species` in `_look_for_quarry`: an ambusher ignores its
     own kind. Decide whether that means its own species or its category.
   - The Eogyrinus rival in `_spawn_eogyrinus`, the restored modes for
     `--spawn` in `_ready`, and `debug_spawn`: use the category or behaviour.
   - `sleep()` and `_wake_attack`: the night attacker is named
     `"uranocentrodon"` or `"scorpion"`. Pick a species from the large or
     hostile medium category instead.
   - Looks stay per species: the `_build_<species>` functions, `_animate`,
     and the list of flat bodies in `_die`.
4. Behaviour that already keys on `behavior`, `habitat` or flags
   (`scavenger`, `escape`) carries over to any new species that sets them.
   A look-alike can copy its template's entry and change only `name`, look
   and drops.

### Grabs and the escape roll (`player.gd`)

Amphibians grab the player (bite, then health per second in the jaws).
Their heads face −Z, so the lower jaw (`_jaw`) opens with a negative X
turn (`-_gape * 0.9`); a positive one swings it up through the skull.
Stabbing builds up a grip break for Eogyrinus. Uranocentrodon instead rolls
once it reaches deep water or after `ROLL_TIME`: `ESCAPE_BASE` 10% plus the
best strike landed while held (`ESCAPE_BONUS`: bare +15%, stone +30%,
advanced +60%).

### Thrown stones (`thrown_rock.gd`)

Right-click with a `throw` item (river stone, chert). It flies at 17 m/s
under gravity, with air drag toward `world.wind` (`WIND_DRAG`), and stops at
the first creature, trunk, boulder, ground or water. Small animals are stunned 2.5 s (a dragonfly drops its lizard); a big
amphibian hit directly comes for you; a splash lures amphibians within 12 m
that aren't already after the player. The stone becomes a pickup that is not saved.
A `frenzy` item (baitbox) is different: see "Baitbox".

## Sleep, weather and saving

- **Weather**: rain lasts 2–4 min, dry spells 4–8 min (`_update_weather`,
  `set_rain`). A new world's first day is dry until `DRY_UNTIL` (clock 1140,
  dusk) plus up to 2 min. Rain speeds fuel and torch burning, dims torches
  and makes sleeping chilly. The drops (`RAIN_SHADER`) are discarded under
  the roof of any house within 40 m (`_update_roofs`, up to `MAX_ROOFS`,
  each roof side only once built), so rain doesn't fall indoors or on the
  porch.
- **Rare weather** (`src/world/weather.gd`, `swamp.weather`): from
  `FIRST_DAY` (index 2, day three) `roll_day` gives each day a `CHANCE` (20%;
  33% in the late game, which adds `day_meteors` from day 10: see
  [game-doc-late-game.md](game-doc-late-game.md)) of one event from `KINDS`. Night kinds (`aurora`, `bright_moon`, `meteors`)
  last the night, from clock 1260 to 180. The others (`fog`, `wind`, `smoke`,
  `thunderstorm`) last `LENGTH` 6–12 min, starting at a random time of the day. Events
  fade in and out over `FADE` (30 s). `apply_sky` runs at the end of
  `_update_sky` and adjusts fog, light and sky colours per kind:
  - The thunderstorm forces rain, darkens the sun to 18% and throws a bolt
    every 1.5–7 s, with a flash and delayed thunder. `lightning()` never
    hurts anything; it returns the ground point for tree splintering later.
    `strike(point)` is a bolt to a chosen point with a full flash and the
    thunder at once, in any weather (the arrival's, intro.gd).
  - Wind (`WIND_SPEED` 11–16 m/s with gusts; 45% of that in a storm) sets
    `scene_base.wind`, the `wind` uniform of the `foliage` and `bark`
    shaders (trees sway), the wind loop, drag on thrown stones, and pushes
    dragonflies, sometimes blowing one away for a few seconds
    (`creature.blow_away`).
  - Meteors are additive streaks from a radiant; the aurora is a curtain
    mesh; the bright moon is a quad. Smoke adds drifting ash.
  - A planned `aurora` or `meteors` hints at itself at `DUSK_START` (clock
    1140, solar 0.7), `NIGHT_START` − `DUSK_START` before it begins: once
    (`hinted`, reset by `plan`, saved) it notifies `HINT_TEXT` ("You see
    faint shimmers in the sky…" / "faint streaks of light…"), then
    `START_TEXT` when it starts in the dark at `NIGHT_START`.
  - Saved in `_world_state` → `"events"` (`to_dict` / `from_dict`).
- **Sleep risk** (`swamp.sleep_risk`): amphibian attack chance by distance to
  water (95% within 10 m, none past 30 m), predators (higher at night, cut by
  fire, rocky ground and tree cover, doubled by blood: raw meat, bleeding or
  a carcass within 20 m), insect bites and leeches near water, chills in rain,
  floods on low wet ground. An attack wakes you early; surviving 30 s saves.
- **Camp save**: every sleep saves, a nap by day as well as a night's
  sleep (`Game.saved_night` records the night, -1 by day). A bedroll also
  saves without sleeping (see "Bedroll"). **Suspend save**: save and quit, used once by
  Continue. Each named world has its own folder under `user://worlds`.
- **Export and import**: `Game.export_world(id)` is one JSON text (`kind`
  "vibival-world", `version`, the world.json as `world`, and its camp and
  suspend saves under `saves`); `Game.import_world(text)` checks the kind and
  version and makes a new world from it, renamed "Name (2)" and so on if the
  name is taken, played now so it's listed first. On the title's Load world,
  `_pick_file` uses `DisplayServer.file_dialog_show` where there is a native
  picker (Linux: the xdg-desktop-portal FileChooser, which hands a flatpak
  only the chosen file through the document portal, so no filesystem
  permission is needed; Android: the Storage Access Framework, whose URIs
  FileAccess opens; no filters there, as Android has no MIME type for
  .vibival), else Godot's FileDialog. The web build downloads with
  `JavaScriptBridge.download_buffer` and uploads through an `<input
  type=file>` (`_web_upload`).
- **What is saved** (`Game.take_save` + `swamp._world_state`): seed, clock,
  inventory, taken and harvested uids, hints, tiers, player position and
  vitals, fires (with cooking and ash), soup pots, stashes, bedrolls, dropped items, carcasses,
  guts piles, shore stones, waypoint, rain and rare weather. Living
  creatures are not saved.
- **Debug worlds**: `Game.create_world(name, id, debug_world)` writes
  `"debug"` to `world.json`; `Game.debug` and `Game.cheats` (`damage`,
  `needs`, `hostile`, saved there by `set_cheat`) are read in `use_world`.
  In one, `sleep_blocker` and `suspend_blocker` allow sleeping and saving at
  any time, F5 is `save_now`, and the player flies after a double tap of jump
  (`FLY_TAP` 0.35 s). `player.apply_cheats` sets `vitals.god` and
  `vitals.no_needs`. F1 (`debug_panel` action) or the pause menu opens
  `src/ui/debug_panel.gd` through `swamp.open_debug`; it pauses the tree.
  Its Health row lists `Survival.DEBUG_CONDITIONS` ([id, name]) and gives
  one with `vitals.give_condition(id)`, which sets the fields directly (not
  through `add_wound` or `poison`), so it works with damage off; `god` then
  keeps it from killing you or draining blood. Infections come on a fresh
  non-bleeding wound at that stage. Heal is `vitals.cure_all()`. The dev
  `--condition=id,...` flag gives them at start.

## UI

- **HUD** (`hud.gd`): the stamina bar, the hunger and thirst lines above it
  (`vitals.hunger_words()`, `thirst_words()`, each left out at level 0), and
  the status words above those (`vitals.status_words()`), the blindness overlay, the hotbar and carried weight, the clock, the look prompt (through
  `Settings.hint`: `[E]`, `[C]`, `[Q]`, `[Right-click]` and "Q puts it
  down" name what is bound to interact, craft, drop and use on the device in
  use, e.g. `[X]` on a pad, `[Act]` on a touch screen),
  the look tooltip panel (`player.tooltip`, from the focus's `tooltip()`),
  messages, the sleep confirmation line, the waypoint marker. The swamp has
  no pop-up tips; instructions are only shown while crafting and in the lab.
  Messages, the hint line, the tooltip, the lab's objectives and the "Tired"
  line all go through `Settings.hint`, and the hint, tooltip and objectives
  are redone on `Settings.input_changed` (sent when `using_pad` flips).
- **Gamepad wording** (`Settings.pad_words`, from `hint` while `using_pad`
  and not touch): text written for the mouse and keyboard names the pad's
  bound buttons. A click becomes jump's button with "press ... on" (the work
  view clicks at the pad cursor with it), "click to"/"click:" keep their
  shape, right-click (-ing, -ed) becomes use's button, holding the left
  mouse button becomes holding interact (which twists), "press E", "(Q)",
  "Z to sleep" and the like name their actions' buttons (`KEY_ACTIONS`),
  "(keys 1-6)" the bumpers, and "[W]" walking forward. The work
  view's instructions and how-texts, the tray line, the inventory's hint,
  item descriptions and the recipe book use it too.
- **Tab menu** (`inventory_ui.gd`), three tabs:
  - *Inventory*: the grid, item info (the description label is a fixed
    `DESC_LINES` (8) tall and clips). The page isn't centred: `_layout` pins
    its top where the inventory page (`_ref_h`, measured once) would be
    centred, so nothing jumps as hovering, a stash or a tab changes its
    height. It is centred across, and refitted whenever its minimum size
    changes (a page never shrinks by itself, so a narrower tab or a closed
    stash would otherwise leave it wide with everything to the left); on a short screen the page is scaled down to fit, and the tall
    scrolling lists (`_fit`) shrink to the room left. The recipe book shows
    one entry for each `Items.BOOK_GROUPS` group (every way of tearing up
    meat bait, every small animal gutted and skinned). Eat/Drink, Treat wound, **Drop** (kept)
    and **Discard** (gone on reload), a short condition line, and Rest
    (sleep from here, with the spot's risk).
  - *Health*: the summary, condition bars, vitals and nutrients, what to do
    about each problem, and a card per wound with Apply pressure, Wash,
    Alcohol, Bandage and Seal with wax, plus Wash all dirty wounds (see
    [Telling the player](#telling-the-player)).
    It refreshes twice a second, but not while the mouse button or a pad's
    A is down.
  - *Recipes*: the read-only recipe book by category and tier.
  - Opened on a stash, only the inventory tab is available.
  - On a pad, A (Godot's `ui_accept`) presses the slot in focus (pick, then
    place) and use (LT) on a slot does what a right-click does
    (`_slot_use`: eat, drink or treat, or move the stack across a stash).
- **Work UI** (`work_ui.gd`): the Make list (`_side`), instructions
  (`_top`), the twist progress bar and the inventory tray. Recipe buttons have
  no tooltips: pointing at one shows its how-text in the instructions
  (`_show_how`) while no recipe is underway; the instructions are as tall as
  the longest how-text wraps to from the start (`info_height`), so pointing
  at one never grows them and pushes the Make list up. `_ranked` lists first the recipes
  that use the most kinds of laid-out items. Every frame `_frame_work()`
  projects `work_spot.view_points()` (the look point, the marker and the
  marks still to come, the piles, the work mesh's corners) and keeps their box
  inside `clear_rect()` (the screen left of `_side` and above `_top`, less
  `CLEAR_PAD`): it widens the FOV up to `MAX_FOV` (75), then steps the eye back
  (`player.work_back`, up to `MAX_BACK` 1.2 m), and turns the camera by
  `player.work_view` (x yaw, y pitch, z extra FOV) only when something is
  outside the rect. On a pad the look actions move a drawn cursor
  (`_cursor_mark`, `CURSOR_SPEED` 700 px/s; `warp_mouse` does nothing on the
  web or Android), which starts at the middle of `clear_rect()` and hides when
  the real mouse moves. `_pad_click`: jump (A) clicks at it (a tray slot lays
  one, a Done, Stop or recipe button presses, anything else is
  `spot.click`), and use from a pad (LT) right-clicks (a tray slot lays the
  stack). `_pad_hover` lights tray slots and shows a recipe's how-text. No
  button here takes focus (and `open` drops any focus), so A always reaches
  `_pad_click` rather than pressing a focused button.
- **Controls** (`controls_panel.gd`, from Settings → Controls...): a row per
  `Settings.BINDABLE` action with two keyboard/mouse slots and a gamepad
  slot. Picking one waits `WAIT_TIME` (6 s) and swallows every key, mouse
  button and pad event meanwhile: a key or mouse button (keyboard slots), a
  pad button, or an axis that has moved `AXIS_PRESS` (0.6) away from both 0
  and its value when waiting began (gamepad slot: so a trigger resting at -1
  isn't taken). Delete or Backspace clears, Esc cancels. Back saves.
- **Bindings** (`settings.gd`): `bindings` is action → [kb/mouse, kb/mouse,
  pad], each `{"key": physical keycode}`, `{"mouse": button}`,
  `{"button": joy button}`, `{"axis", "dir"}` or `{}`, from
  `DEFAULT_BINDINGS`; only actions that differ are saved, under
  `[bindings]`. `apply_bindings()` rebuilds the InputMap with `device = -1`
  on every event: browsers number pads by their slot, and Android gives each
  the lowest free number, so device 0 alone missed pads. Esc and Android's
  back key are always on pause. On Android a trigger-axis binding also adds
  joy buttons 15/16 (Godot's Android L2/R2). `set_binding()` takes the
  binding off any other action and returns it. The built-in `ui_*` pad
  events are switched to `device = -1` too, and since Godot gives `ui_accept`
  and `ui_cancel` no pad button, A and B are added to them: menus,
  the title screen and the inventory answer the pad. The title's New world
  panel starts the pad on its first button (it can't type a name). Godot's controller database maps
  the browser's "standard" pads to its own layout; Android buttons come
  pre-mapped, but its axes are numbered by sorting the device's axes, so
  sticks and triggers can differ from pad to pad (fix: rebind).
  `button_name(action)` reads the bindings (pad slot first when `using_pad`;
  touch has `TOUCH_NAMES`).
- **Touch controls** (`touch_controls.gd`): made by `scene_base` when
  `Settings.touch` is set: `touch_screen` (any `mobile` build, or `--touch`,
  which also turns mouse clicks into touches) and `touch_controls`, the
  Settings checkbox shown on a touch screen (saved as
  `controls/touch_controls`). `set_touch_controls` sends `input_changed`, and
  `scene_base._show_touch` adds or frees the overlay there and then, so a
  phone with a pad or keyboard can do without it; key names and wording
  follow. Thumb down on the left 40% of the screen is a
  floating stick (`Input.action_press` on the move actions, with strength);
  a drag anywhere else calls `player._look`. Buttons send `InputEventAction`s
  for the same actions as the keys, so nothing else needs to know about touch.
  Under a menu only the pause button is shown, labelled Back, and taps reach
  the menu as Godot's emulated mouse clicks. Under the pause menu or death
  screen the overlay hides (it processes while paused for that). The mouse is
  never captured, and `player.can_aim` is always on. Text that names keys
  (look prompts' `[E]`, lab hints, crafting and inventory hints, the sleep
  confirmation) has touch wording when `Settings.touch` is set.

## Audio

`Sfx` synthesises every effect from noise and tones (`_s_<name>` functions),
cached on first use. `Music` plays a random track from `game/music/`, then
waits a random gap by `Settings.music_frequency` (`GAPS`): Constant 4–12 s;
Common 0.7–1.3 and Rare 3–5 times the length of the track, so music fills
about 50% and 20% of the time, and never more than `MAX_SHARE` (60% and 30%).
The next track is scheduled when one starts (`wait` = its length + a gap),
not on the player's `finished` signal, which can go missing; and none may
start before `quiet_until()` (the last track's start + its length /
`MAX_SHARE`), however it ended or whatever scene came in between. Rare is
the default. Off plays
nothing. Music has its own bus and volume, `GAIN_DB` (+3 dB) above the
slider.

`Music.enter(scene, fresh)` is called by `Game.goto`. It stops the track, then:
the lab has no music (but `Music.elevator(on)` plays
`music/elevator.mp3`, looping, from when you are in the car until you
step out; `find_tracks` skips it); the title queues `TITLE_FIRST` ("Dusk") after
`TITLE_WAIT` (20 s), and on the title `next_gap` always uses the Constant gap
and `quiet_until` ignores `MAX_SHARE`, so tracks keep following it (unless
music is Off); a new world's
swamp (not Constant) queues `OPENING` ("Empty Basin") after `OPENING_WAIT`
(30 s); anything else waits a quarter of a normal gap.

## Art (`src/autoload/assets.gd`)

`Assets.mesh(key)` calls `_m_<key>(builder, rng, detail)` (or
`_item_mesh` for `item_<id>`) and caches the result. Materials come in slots
(`solid`, `foliage`, `wood`, `stone`, `fiber`, `organic`, `clay`, ...) with
procedural detail textures, compensated so their average stays the vertex
colour. Item meshes follow their real shape: knapped heads are built from
their knapping pattern with `Assets.knapped`, hafts use `stick` and
`lashing`. Inventory icons are rendered from these meshes.

## Testing and running

```bash
tools/test.sh
```

That parses every script (`tests/check_scripts.tscn`) and runs the gameplay
suite (`tests/run_tests.tscn`, about 13 minutes headless). Every new
mechanic gets checks in `run_tests.gd`. Useful dev flags (after `--`) are
listed at the top of `game.gd` and in the README: `--start`, `--seed`,
`--time`, `--give`, `--god`, `--spawn`, `--wound`,
`--open-inventory[=health|recipes]`, `--work`, `--weather`, `--debug`,
`--open-debug`, `--soup-pot`, `--house`, `--shot` and more. `--only=group,...` runs just those test
groups (the first word of each printed group name).

Web and Android builds: `tools/export.sh web|android` exports with the
official editor in `.tools/godot/`, using `game/export_presets.cfg`, from a
staged copy in `build/stage` (music gets a "keep" importer so it stays raw).
Web-only code: `Game._on_page_visibility` (suspend save on hide, mirrored to
localStorage, `_restore_web_pending` on start) and
`scene_base._physics_process` (pointer lock lost while playing → pause).
Android: a debug-signed APK (the script makes the keystore), no
permissions, landscape. `Game` turns `NOTIFICATION_APPLICATION_PAUSED` and
`RESUMED` into the same suspend save as a hidden web page (`_app_hidden` and
`_app_shown`). The back key is bound to the `pause` action as `KEY_BACK`, and
quit-on-go-back is off. The go-back notification is not used because it
arrives on both the press and the release. Phones always run full screen,
because windowed mode brings back the system bars.

Screenshots without a display:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" tools/dev-run.sh -- --start=swamp --time=0.45 --shot=$PWD/.dev-out/swamp.png --shot-delay=8
```

## Adding things

- **An item**: add it to `ITEMS` (and a recipe to `RECIPES` if it is made).
  If its `shape` is new, add a case in `Assets._item_mesh`. For a steps
  recipe, add its workpiece to `WorkSpot._rebuild_work`, its marker to
  `_target`, and its step count to `Items.recipe_steps`.
- **A knapped head**: add its pattern to `KNAPPING`, make sure it doesn't
  match another pattern, add it to `Assets.HEAD_SHAPES` and the knap case in
  `_rebuild_work`. One knapped from something other than chert (the chitin
  hook) also goes in `Items.KNAP_MATERIAL` (its input item): `knap_matches(grid,
  material)` then only matches patterns of that material, so a chitin plate
  can never come out as a chert head. Its recipe takes `tool_tag` "cut" (a
  blade) instead of `tools` stone, and the work spot's wording names the
  material (`_knap_stuff()`).
- **A land animal that should eat kills**: give it `"scavenger": true` and a
  `hunter` or `defensive` behaviour.
- **A harvestable**: add it to `harvestable.KINDS` with a `regrow` range in
  days and a mesh, and place it in `chunk.gd`.
- **Anything saved**: add it to `swamp._world_state` and `_apply_restore`
  (or to `Game.take_save` for run-wide state), and add a save test.
- Then update the player's guide in `docs/`, this page, and the README.

## Late game

Boats, the rocky islands, copper, tool wear and meteoric iron are on the
`late-game` branch, documented separately in
[game-doc-late-game.md](game-doc-late-game.md) until it is merged.
