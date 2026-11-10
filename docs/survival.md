# Survival

[Guide home](README.md)

## Health

There is no health bar. Several things can kill you, each on its own:
**blood loss**, **venom**, **infection** (once it turns to sepsis),
**starvation**, **thirst**, **drowning** and **alcohol poisoning**. The bottom left of the screen
says how you are in a couple of words ("Healthy", "Bleeding badly", "Broken
leg, feverish"...). The **Health** tab (Tab, then Health) has the full
picture: a summary, a bar for each condition that is hurting you, and what to
do about every problem.

The worse your worst condition gets, the more it costs you:

1. You can't sprint.
2. You are slow and can carry less.
3. Your sight goes dark.
4. Shortly after, you die.

| Condition | Comes from | Recovers with |
|---|---|---|
| Blood loss | Bleeding wounds, bites, an amphibian's jaws | Rest (sleeping, or standing still) while you are fed and watered |
| Venom | Scorpion stings | Rest: it wears off, faster asleep |
| Infection | Dirty, uncovered wounds | See [Infection](#infection) |
| Starving | Energy at 25% or less; much faster once it is empty | Eating |
| Thirst | Water at 25% or less; much faster once it is empty | Drinking |
| Drowning | Swimming with no stamina left | Getting out of deep water |
| Sickness | Raw or rotten food, swamp water | Rest and drink: it makes you thirsty; it won't kill you by itself |
| Alcohol | Drinking (see [Alcohol](#alcohol)) | Time: one drink an hour |

If you die, your last save is eased one step in whatever killed you, so a
save can never trap you dying of the same thing: a little more blood and
less bleeding, less venom, less starved or parched, or an infection one stage
less serious.

## Vitals

| Vital | Falls by itself | Refill it with | When it runs out |
|---|---|---|---|
| Energy | Full to empty in about 100 minutes | Food | You are dying of starvation |
| Water | Full to empty in about 30 minutes | Drinking | You are dying of thirst |
| Stamina | Sprinting, swimming, throwing | Resting a moment | You cannot sprint (in deep water, you start drowning) |

Energy holds twice as much food as it once did, so a full belly takes twice
as many meals and lasts twice as long. Being sick makes you thirsty almost
twice as fast, and so does a fever.

### Hunger and thirst

Stamina is a bar. Hunger and thirst are words in the bottom left instead,
by how full your energy and water are (nothing is shown above 75%):

| Full | Hunger | Thirst | What it does |
|---|---|---|---|
| 75–50% | Mildly Hungry | Mildly Thirsty | Nothing yet |
| 50–25% | Hungry | Thirsty | Hungry: stamina comes back 25% slower and you heal 25% slower. Thirsty: stamina comes back 25% slower and sprinting or swimming tires you 25% faster |
| 25–1% | Starving | Very Thirsty | Stamina comes back at half speed and is capped at 60. Starving: you heal at a quarter of the speed and lost blood doesn't come back. Very thirsty: sprinting or swimming tires you 50% faster and lost blood doesn't come back. **It starts to kill you** |
| 0% | Dying of Starvation | Dying of Thirst | As above, stamina capped at 40, no healing while starving, and it kills you much faster |

Starvation and thirst damage builds slowly while you are starving or very
thirsty, and fast once you are empty. Eat or drink back above 25% and it
wears off.

## Nutrients

Besides energy, food carries three nutrients. Each lasts about three days of
game time. Below 25 you start *craving* it.

- **Protein** (grubs and meat) heals wounds. Low protein caps your stamina at
  70%.
- **Greens** (fiddleheads) help fight infection.
- **Starch** (seeds) keeps your stamina up.

The **Health** tab (Tab, then Health) shows your current protein, greens and
starch, and how well you are recovering. Eating a mix of all three makes everything recover faster.

## Food

| Food | Where | Raw | Cooked |
|---|---|---|---|
| Seed Fern Seed | Seed ferns | Starch, a little energy | Roasted Seed: more of both |
| Young shoots | Tree ferns, Calamites and seed ferns while under a third grown (Farming) | Greens, a little energy | |
| Seed Fern Root | Dug up seed ferns | A little greens, almost no food | |
| Fiddlehead | Ferns | Greens, bitter, small chance of sickness | Cooked Fiddlehead: safe, more greens |
| Beetle Grub | Rotting logs | Protein | Roasted Grub: more protein |
| Raw Meat | Cut from medium and large kills | Protein, but a 50% chance of sickness | Cooked Meat: the best food in the game |
| Dressed small prey | A Hylonomus, Petrolacosaurus, Archaeothyris, Amphibamus, Tuditanus or Morganucodon kill, gutted and skinned by hand | Protein, a 50% chance of sickness | Roasted whole. An Archaeothyris is a bigger meal than cooked meat, an Amphibamus about half and a Morganucodon less; the others a little less than cooked meat |
| Meganeura Carcass | A dragonfly kill | A little protein, a 40% chance of sickness | Roast Meganeura: about half of cooked meat |
| Gnawed Meat | Snatched from an animal eating its kill | A little protein, a 50% chance of sickness | Cooked Scraps: about a third of cooked meat |
| Charred Remains | Food left on the fire too long | Next to nothing | Burn it as fuel instead |

Food spoils. A thin bar under an item's icon shows how fresh it is, and spoiled
food turns into Rotten Food, which almost always makes you sick. Cooked food
keeps longer than raw.

**Soup** made in a Soup Pot (see [Crafting](crafting.md#soup)) shares
everything put in it, counted as cooked, over up to 16 servings, and each
serving also quenches thirst. It keeps a day and a half after it last boiled,
and for as long as you keep it boiling.

## Water

Swamp water is everywhere, but it is risky in two ways:

1. **Sickness.** Drinking straight from the swamp (E at the water) can make
   you sick. Boil it first: fill a fired Clay Pot at the water, put it on a
   lit campfire, and drink the Pot of Boiled Water. A wooden canteen carries
   two servings, lighter than a pot (see [Crafting](crafting.md#canteens)).
2. **What lives in it.** The shallows are full of buried Uranocentrodon and
   the occasional Eogyrinus. Read [Creatures](creatures.md) before you
   drink. Filling a pot once gives you 35–40 water, so one careful trip to the
   water beats many quick sips. A Soup Pot fills with 16 servings at once
   and boils them all together.

You drown if you stay under water too long.

## Wounds

Bites, stings and claws leave wounds: a scratch, a cut, a deep wound or a
mauling. Each one has its own card in the Health tab, with what it needs and
buttons to treat it.

### Bleeding

| Bleeding | From | To stop it |
|---|---|---|
| Minor | Cuts | Nothing: it stops on its own in a minute or so (a bandage stops it at once) |
| Moderate | Deep wounds | **Apply pressure** |
| Major | Maulings | **Apply pressure**, then a **bandage** while the pressure holds it back (about a minute) |

**Apply pressure** (on the wound's card) closes the menu and you press on the
wound for about 8 seconds. Stand still: moving, or being hit, makes you let
go. You can't cover a wound that is still bleeding steadily or heavily, and
you can't sleep while it bleeds.

### Keeping wounds clean

An open wound gathers dirt, and dirt brings infection. **Wash** a dirty wound
with boiled water (a pot or canteen of it), then **cover** it with a fiber
bandage or waxy residue. A clean, covered wound can't get infected.

- **Swamp water** soaks into an open wound, and through a bandage. Wax keeps
  it out (but only goes on a wound that has stopped bleeding).
- **Another attack** tears a dressed wound open again: dirty and bleeding.

### Infection

| Stage | Effect | Treatment |
|---|---|---|
| Minor | None yet | Wash it and cover it. Left alone it usually clears in about half a day, but it may get worse (less likely if it is clean and covered) |
| Moderate | Fever: no sprinting, thirstier | Clean it with alcohol, then bandage it. Untreated, it turns major in about a day |
| Major | Fever | Only alcohol, twice: the first puts it into remission, the second makes it minor. Untreated, sepsis in about a day |
| Major (in remission) | Fever | Alcohol again, before it flares back up (about a day) |
| Sepsis | Slow and weak, then blind, then death within about 12 minutes | None |

Alcohol is brewed in a sealed fermentation vessel (see
[Crafting](crafting.md#fermentation)): start a brew early if you can. Keep
wounds clean and covered. Low greens make infection take hold and spread
faster.

### Broken bones and sprains

- A **hard bite or blow** (Arthropleura, the big amphibians) can break an arm
  or a leg.
- A **long fall** (more than about 3 m) can sprain an ankle or break a leg
  (one or the other). The higher the fall, the likelier.
- **Broken arm**: you carry half as much in your arms (a sack still holds its
  share), and carrying a log or a pot is very slow.
- **Broken leg** or **sprained ankle**: 40% slower, no sprinting.
- A sprain mends after one sleep, a break after two.

| Treatment | What it does | Where from |
|---|---|---|
| Boiled water | Washes dirt out of your wounds (a minor infection, washed and covered, clears) | A pot or canteen of boiled water |
| Fiber Bandage | Covers a wound; stops minor bleeding, or major bleeding held back by pressure | 3 plant fiber and 1 frond make 2 |
| Waxy Residue | Seals a wound that has stopped bleeding; keeps swamp water out | Crush it out of a frond |
| Alcohol | Cleans a wound and fights moderate and major infection; a measure each | Brewed in a sealed fermentation vessel and drawn off into a canteen |

Treat a wound from its card, or right-click a treatment in the inventory (or
select it and press Treat wound) to use it where it is needed most.

## Alcohol

A measure from a canteen of alcohol, or food preserved in alcohol, is a
drink. A measure also gives a little starch, and pickled or
alcohol-preserved food a little greens and starch on top of its own. One drink wears off each game hour, so a second within the hour makes
you tipsy.

| Drinks | Effect |
|---|---|
| 2–3 | Tipsy: you dry out a little faster and heal slowly |
| 4–5 | Drunk: drying out fast, slower, and no healing at all |
| 6–8 | Very drunk: as above, and the world sways |
| 9–12 | You keep vomiting up food and water |
| 13–15 | Your sight goes dark |
| 16 | Alcohol poisoning kills you |

## Sickness and chill

- **Sick**: from raw food, rotten food and swamp water. Thirst rises faster
  until it passes; rest helps.
- **Chilled**: sleeping in the rain. You tire faster and recover stamina
  slowly.

## How much you can carry

You can carry about **8 kg** in your arms. A **Woven Frond Sack** on you raises
that to **25 kg**, and a **Woven Cloth Sack** to **48 kg**. Only your best sack
counts: carrying two doesn't add them up, and the other is just weight. Up to one and a half times that you can still carry more, but
you are slow, cannot sprint and tire quickly. Past that, nothing more fits.

Only weight counts: a stack can hold as many of a thing as you can carry.
Things that are worn differently keep to their own slots, so a part-used
tool doesn't join a stack of fresh ones.

The weight you carry shows under the hotbar and at the top of the inventory.
To store more, set a sack down as a stash: see
[Stashes and waypoints](stashes-and-waypoints.md).

## Weather

Warm rain comes and goes every few minutes. It burns fuel and torches faster,
dims torches, and makes sleeping in the open chilly.

From the third day, each day has about a 1 in 5 chance of something rarer:

| Event | When and how long | What it does |
|---|---|---|
| Dense fog | 6–12 minutes, any time of day | You can see only a few metres. |
| High winds | 6–12 minutes | Trees sway and the wind howls. Thrown stones drift downwind. Giant dragonflies struggle and are sometimes blown away. |
| Wildfire smoke | 6–12 minutes | Thick, red-tinged haze with drifting ash. |
| Thunderstorm | 6–12 minutes | Heavy rain, a dark sky by day, and constant lightning. The lightning never strikes you. |
| Aurora | The whole night | Green and violet curtains across the sky. |
| Bright moon | The whole night | A huge moon lights the swamp. |
| Meteor shower | The whole night | Shooting stars from one point in the sky. |

An aurora or a meteor shower gives itself away at dusk: you see faint
shimmers, or faint streaks of light, in the sky, and once it is dark it
begins in earnest.
