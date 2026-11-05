extends RefCounted
## Player body. There is no single health bar: several conditions can each
## kill you, and the worst of them decides how bad you feel.
##
## Conditions, each a "harm" from 0 (fine) to 1 (dead):
##   blood      lost from bleeding wounds and jaws; rebuilt by rest while fed
##   venom      from stings; wears off, faster at rest
##   infection  the worst infected wound's stage; only sepsis gets serious
##   starving   time spent starving (energy at 25% or under), faster at 0
##   thirst     time spent very thirsty (water at 25% or under), faster at 0
##   drowning   time spent exhausted in deep water
##   sickness   food poisoning: miserable but not deadly by itself
## The worst harm sets a tier (TIERS): no sprinting, then slowness and less
## carrying, then blindness, then death at 1.
##
## Wounds bleed by level: minor bleeding stops on its own, moderate needs
## pressure (apply_pressure), major needs pressure and then a bandage while
## the pressure holds. A clean wound covered with a bandage or waxy residue
## can't get infected; an open or dirty one can. Infections go minor ->
## moderate -> major -> sepsis, each untreated stage turning into the next
## (see INF_*). Treatments: washing (boiled water, or alcohol) and covering.
##
## Fractured arms and legs and sprained ankles mend after sleeping (slept()).
##
## Energy, water and stamina, and the three nutrients, work as before:
## protein heals wounds, greens fight infection, starch keeps stamina up.
##
## Hunger and thirst are shown as words, not bars (HUNGER_NAMES, THIRST_NAMES),
## by how full energy and water are: over 75% nothing, then mildly, then
## hungry/thirsty, then starving/very thirsty at 25% and under, then dying at 0.
## From hungry/thirsty on they cost you (HUNGER_*, THIRST_*, NEED_STAMINA_CAP);
## from starving/very thirsty on they also harm you, faster once empty.

signal died
signal status(text: String)

const MAX_ENERGY := 200.0               # holds twice what it did; food gives what it always has
const ENERGY_DRAIN := 100.0 / 3000.0     # per second, unchanged: full to empty in ~4 days (100 min)
const WATER_DRAIN := 100.0 / 1800.0      # ~30 min
const NUTRIENT_DRAIN := 100.0 / 4500.0   # ~3 days
const LOW := 25.0                        # nutrient level that counts as deficient
const SLEEP_DRAIN := 0.6                 # energy and water drain while asleep

## How bad the worst condition is: harm at or over each of these is that tier.
## 1: no sprinting. 2: slow, carries less. 3: going blind. At 1.0, dead.
const TIERS := [0.25, 0.5, 0.75]
const SLOW := [1.0, 1.0, 0.7, 0.5]       # walking speed by tier
const CARRY := [1.0, 1.0, 0.7, 0.5]      # carrying capacity by tier

# Bleeding: blood lost per second by level (none, minor, moderate, major).
const BLEED_RATE := [0.0, 0.12, 0.18, 0.6]
const BLEED_NAMES := ["", "minor", "moderate", "major"]
const PRESSURE_TIME := 8.0      # seconds of pressure to stop moderate bleeding (or hold major)
const PRESSED_RATE := 0.25      # bleeding while you press, as a share
const HELD_TIME := 60.0         # major bleeding held back this long after pressure
const HELD_RATE := 0.05         # blood per second while it is held back
const BLOOD_REGEN := 0.03       # per second while fed and watered and not bleeding

const VENOM_PER := 2.5          # venom harm per point of a creature's venom
const VENOM_FADE := 0.08        # venom points per second (faster at rest)
const STARVE_TIME := 500.0      # seconds with no energy to starve
const THIRST_TIME := 360.0      # seconds with no water to die of thirst
const STARVE_BAND_TIME := 4000.0   # seconds starving (energy 25% and under, not empty) to starve
const THIRST_BAND_TIME := 1200.0   # seconds very thirsty (water 25% and under, not empty) to die of it

# Hunger and thirst levels, by how full energy and water are (need_level):
# 0 over 75%, 1 75-50%, 2 50-25%, 3 25% down to just over 0, 4 empty.
const HUNGER_NAMES := ["", "Mildly Hungry", "Hungry", "Starving", "Dying of Starvation"]
const THIRST_NAMES := ["", "Mildly Thirsty", "Thirsty", "Very Thirsty", "Dying of Thirst"]
const HUNGER_REGEN := [1.0, 1.0, 0.75, 0.5, 0.35]  # stamina regained, by hunger level
const HUNGER_HEAL := [1.0, 1.0, 0.75, 0.25, 0.0]   # blood and wounds healing, by hunger level
const THIRST_REGEN := [1.0, 1.0, 0.75, 0.5, 0.35]  # stamina regained, by thirst level
const THIRST_SPRINT := [1.0, 1.0, 1.25, 1.5, 1.5]  # stamina spent sprinting or swimming, by thirst level
const NEED_STAMINA_CAP := [100.0, 100.0, 100.0, 60.0, 40.0]  # most stamina, by the worse of the two
const DROWN_TIME := 17.0        # seconds exhausted in deep water to drown
const SICK_HARM := 0.3          # food poisoning keeps you off your sprint
# Alcohol, in drinks (a measure from a canteen, or a bite of food preserved in
# it). One wears off each game hour, so two within the hour make you tipsy.
# By drinks: 2-3 dry you out a little and slow healing; 4-5 dry you out more,
# slow you down and stop healing; 6-8 the world sways; 9-12 you throw up; 13-15
# your sight goes; 16 kills.
const ALCOHOL_FADE := 1.0 / 60.0   # drinks per second: one per game hour
const ALCOHOL_THIRST := [1.0, 1.0, 1.3, 1.3, 1.7]  # water drain by drinks (4 and over: the last)
const ALCOHOL_SLOW := 0.8        # walking speed from 4 drinks
const VOMIT_EVERY := [20.0, 40.0]  # seconds between bouts of vomiting from 9 drinks
const VOMIT_LOSS := {"water": 15.0, "energy": 12.0}

# Infection stages, from a wound's `inf`.
enum { INF_NONE, INF_MINOR, INF_MODERATE, INF_MAJOR, INF_REMISSION, INF_SEPSIS }
const INF_NAMES := ["", "Minor infection", "Moderate infection", "Major infection", "Major infection (in remission)", "Sepsis"]
const INF_HARM := [0.0, 0.0, 0.25, 0.4, 0.3, 0.5]
const MINOR_TIME := 720.0       # a minor infection clears or worsens after this
const MINOR_WORSEN := [0.1, 0.3]   # chance it worsens: clean and covered, otherwise
const MODERATE_TIME := 1440.0   # untreated, a moderate infection turns major after a day
const MAJOR_TIME := 1440.0      # and a major one septic after another
const REMISSION_TIME := 1440.0  # in remission it flares up again unless treated again
const SEPSIS_TIME := 720.0      # from the onset of sepsis to death
const INFECT_RATE := 0.002      # per second, times the wound's dirt, for an open wound
const EXPOSE_RATE := 0.0015     # dirt an open wound picks up from the air per second
const WET_DIRT := [0.03, 0.01, 0.0]  # dirt per second in swamp water: open, bandaged, waxed
const SEPSIS_TEXT := "You're currently experiencing sepsis, contact 911 immediately for emergency intravenous antibiotics."

# Broken bones and sprains: sleeps until they mend.
const MEND := {"arm": 2, "leg": 2, "ankle": 1}
const LIMB_NAMES := {"arm": "Broken arm", "leg": "Broken leg", "ankle": "Sprained ankle"}
const LEG_SLOW := 0.6           # a broken leg or sprained ankle: 40% slower, no sprinting
const ARM_HAUL := 0.5           # a broken arm: carrying something big is this slow

# Conditions a debug world's panel (and the dev --condition flag) can give you:
# [id, name]. See give_condition.
const DEBUG_CONDITIONS := [
	["bleed_minor", "Wound, bleeding a little"],
	["bleed_moderate", "Wound, bleeding steadily"],
	["bleed_major", "Wound, bleeding heavily"],
	["dirty_wound", "Dirty open wound"],
	["infection_minor", "Minor infection"],
	["infection_moderate", "Moderate infection"],
	["infection_major", "Major infection"],
	["infection_remission", "Major infection (in remission)"],
	["sepsis", "Sepsis"],
	["broken_arm", "Broken arm"],
	["broken_leg", "Broken leg"],
	["sprained_ankle", "Sprained ankle"],
	["blood_loss", "Blood loss (half your blood)"],
	["venom", "Venom (a bad sting)"],
	["food_poisoning", "Food poisoning"],
	["chilled", "Chilled"],
	["starving", "Dying of starvation"],
	["thirst", "Dying of thirst"],
	["tipsy", "Tipsy (2 drinks)"],
	["drunk", "Drunk (4 drinks)"],
	["very_drunk", "Very drunk (6 drinks)"],
	["vomiting_drunk", "Vomiting drunk (9 drinks)"],
	["blind_drunk", "Blind drunk (13 drinks)"],
	["low_protein", "Short of protein"],
	["low_greens", "Short of greens"],
	["low_starch", "Short of starch"],
]

var energy := MAX_ENERGY * 0.78  # a new run starts just fed enough not to feel hungry yet
var water := 70.0
var stamina := 100.0
var protein := 60.0
var greens := 60.0
var starch := 60.0
var blood := 100.0
var venom := 0.0    # 0..100
var starving := 0.0 # 0..1
var thirst := 0.0   # 0..1
var drowning := 0.0 # 0..1
var sick := 0.0     # seconds of food poisoning left
var alcohol := 0.0  # drinks in your blood; one wears off each game hour (drinks())
var _vomit_t := 0.0
var chill := 0.0    # seconds of being chilled left
## Each wound: {sev, bleed (level 0-3), bleed_t (minor: seconds left), held
## (major: seconds held back), dirt, cover ("", "bandage", "wax"), inf
## (stage), inf_t (seconds in that stage), sterile (cleaned with alcohol), src}
var wounds: Array = []
var limbs := {}     # "arm", "leg", "ankle" -> sleeps until it mends
var pressing := -1  # the wound you are pressing on, while you do
var cause := ""     # what killed you: blood, venom, infection, starving, thirst, drowning
var _hunger_was := 0  # hunger and thirst levels last tick, to say when they get worse
var _thirst_was := 0
var dead := false
var god := false        # takes no damage (dev --god, or a debug world's switch)
var no_needs := false   # never hungry, thirsty or out of breath (debug world)


# --- How you are -------------------------------------------------------------------

func max_stamina() -> float:
	var cap: float = NEED_STAMINA_CAP[maxi(hunger_level(), thirst_level())]
	return minf(70.0 if protein < LOW else 100.0, cap)


static func need_level(full: float) -> int:
	## 0..4 for energy or water this full (0..1): see HUNGER_NAMES.
	if full > 0.75:
		return 0
	if full > 0.5:
		return 1
	if full > 0.25:
		return 2
	if full > 0.0:
		return 3
	return 4


func hunger_level() -> int:
	return need_level(energy / MAX_ENERGY)


func thirst_level() -> int:
	return need_level(water / 100.0)


func hunger_words() -> Array:
	## The HUD's hunger line: [text, color] ("" when not hungry at all).
	var l := hunger_level()
	return [HUNGER_NAMES[l], NEED_COLORS[l]]


func thirst_words() -> Array:
	var l := thirst_level()
	return [THIRST_NAMES[l], NEED_COLORS[l]]


func nutrition() -> float:
	## 0.2..1, how well the last few days of eating support recovery.
	var f := 0.0
	for n in [protein, greens, starch]:
		f += clampf(n / 50.0, 0.2, 1.0)
	return f / 3.0


func infection() -> int:
	## The worst infection stage of any wound (remission counts below major).
	var worst := INF_NONE
	for w in wounds:
		if _inf_rank(w.inf) > _inf_rank(worst):
			worst = w.inf
	return worst


static func _inf_rank(stage: int) -> int:
	return [0, 1, 2, 4, 3, 5][stage]


func infection_harm() -> float:
	var worst := 0.0
	for w in wounds:
		var h: float = INF_HARM[w.inf]
		if w.inf == INF_SEPSIS:
			h = lerpf(0.5, 1.0, clampf(w.inf_t / SEPSIS_TIME, 0.0, 1.0))
		worst = maxf(worst, h)
	return worst


func fever() -> bool:
	return infection_harm() >= INF_HARM[INF_MODERATE]


func bleed_level() -> int:
	## The worst bleeding of any wound (0 none .. 3 major).
	var worst := 0
	for w in wounds:
		worst = maxi(worst, w.bleed)
	return worst


func bleeding() -> bool:
	return bleed_level() > 0


func harms() -> Dictionary:
	## Every condition's harm, 0 fine .. 1 dead.
	return {
		"blood": clampf(1.0 - blood / 100.0, 0.0, 1.0),
		"venom": clampf(venom / 100.0, 0.0, 1.0),
		"infection": infection_harm(),
		"starving": starving,
		"thirst": thirst,
		"drowning": drowning,
		"sickness": SICK_HARM if sick > 0.0 else 0.0,
		"alcohol": clampf(0.75 + (alcohol - 12.0) / 16.0, 0.0, 1.0) if alcohol > 12.0 else 0.0,
	}


func harm() -> float:
	var worst := 0.0
	for k in harms().values():
		worst = maxf(worst, k)
	return worst


func worst_condition() -> String:
	var h := harms()
	var best := ""
	for k in h:
		if h[k] > 0.0 and (best == "" or h[k] > h[best]):
			best = k
	return best


func tier() -> int:
	var h := harm()
	var t := 0
	for i in TIERS.size():
		if h >= TIERS[i]:
			t = i + 1
	return t


func leg_hurt() -> bool:
	return limbs.has("leg") or limbs.has("ankle")


func arm_broken() -> bool:
	return limbs.has("arm")


func can_sprint() -> bool:
	return tier() < 1 and not leg_hurt()


func speed_mult() -> float:
	return SLOW[tier()] * (LEG_SLOW if leg_hurt() else 1.0) * (ALCOHOL_SLOW if drinks() >= 4 else 1.0)


func drinks() -> int:
	## How many drinks are in you, rounded up (two within an hour make 2).
	return ceili(alcohol - 0.001) if alcohol > 0.001 else 0


func heal_mult() -> float:
	## Healing (blood and wounds) while drinking: slower from 2 drinks, none from 4.
	var d := drinks()
	return 1.0 if d < 2 else (0.5 if d < 4 else 0.0)


func drunk_sway() -> float:
	## How much the world sways: 0, then from 6 drinks more with each.
	return 0.0 if drinks() < 6 else clampf(0.4 + (alcohol - 6.0) * 0.12, 0.0, 1.0)


func drink_alcohol(n := 1.0) -> void:
	## A drink (or a bite of food preserved in alcohol).
	if dead:
		return
	var was := drinks()
	alcohol += n
	var now := drinks()
	if was < 2 and now >= 2:
		status.emit("The drink goes to your head.")
	elif was < 6 and now >= 6:
		status.emit("You are very drunk. The world sways.")
	elif was < 9 and now >= 9:
		status.emit("Your stomach heaves. You've had far too much.")
		_vomit_t = 3.0
	elif was < 13 and now >= 13:
		status.emit("Your sight swims and darkens. Any more could kill you.")
	_check_death()


func carry_mult() -> float:
	return CARRY[tier()]


func blindness() -> float:
	## How dark your sight has gone: 0 until the last tier, then closing in
	## (blind drunk at 13 drinks is the last tier of the alcohol condition).
	var h := harm()
	if h < TIERS[2]:
		return 0.0
	return lerpf(0.55, 0.97, clampf((h - TIERS[2]) / (1.0 - TIERS[2]), 0.0, 1.0))


# --- Time --------------------------------------------------------------------------

func tick(delta: float, sprinting: bool, swimming: bool, wading := false, sleeping := false, still := false) -> void:
	## `still`: standing still, which counts as half a rest.
	if dead:
		return
	if no_needs:
		energy = MAX_ENERGY
		water = 100.0
		protein = maxf(protein, 60.0)
		greens = maxf(greens, 60.0)
		starch = maxf(starch, 60.0)
		stamina = max_stamina()
		sprinting = false
		swimming = false
	var rest := 3.0 if sleeping else (1.5 if still else 1.0)
	var exertion := 1.6 if sprinting or swimming else 1.0
	if sleeping:
		exertion = SLEEP_DRAIN
	var energy_mult := (1.2 if starch < LOW else 1.0) * (1.4 if chill > 0.0 else 1.0)
	var water_mult: float = (1.8 if sick > 0.0 else 1.0) * (1.6 if fever() else 1.0) * ALCOHOL_THIRST[mini(drinks(), 4)]
	energy = maxf(energy - ENERGY_DRAIN * exertion * energy_mult * delta, 0.0)
	water = maxf(water - WATER_DRAIN * exertion * water_mult * delta, 0.0)
	var nd := NUTRIENT_DRAIN * (0.6 if sleeping else 1.0) * delta
	protein = maxf(protein - nd, 0.0)
	greens = maxf(greens - nd, 0.0)
	starch = maxf(starch - nd, 0.0)
	if no_needs:
		energy = MAX_ENERGY
		water = 100.0
	var hl := hunger_level()
	var tl := thirst_level()

	if sprinting or swimming:
		stamina = maxf(stamina - (14.0 if sprinting else 6.0) * THIRST_SPRINT[tl] * delta, 0.0)
	else:
		var regen: float = 14.0 * HUNGER_REGEN[hl] * THIRST_REGEN[tl]
		if starch < LOW:
			regen *= 0.6
		if chill > 0.0 or fever():
			regen *= 0.5
		if sleeping:
			regen = 100.0
		stamina = minf(stamina + regen * delta, max_stamina())
	stamina = minf(stamina, max_stamina())

	# Starving and very thirsty wear you down; empty, much faster. Above
	# that, it eases off.
	if hl >= 3:
		starving = minf(starving + delta / (STARVE_TIME if hl == 4 else STARVE_BAND_TIME), 1.0)
	else:
		starving = maxf(starving - delta / (STARVE_TIME * 0.6), 0.0)
	if tl >= 3:
		thirst = minf(thirst + delta / (THIRST_TIME if tl == 4 else THIRST_BAND_TIME), 1.0)
	else:
		thirst = maxf(thirst - delta / (THIRST_TIME * 0.6), 0.0)
	_say_needs(hl, tl)
	if not swimming or stamina > 0.0:
		drowning = maxf(drowning - delta * 0.25, 0.0)
	if sick > 0.0:
		sick = maxf(sick - delta * (0.6 if greens < LOW else 1.0) * rest, 0.0)
		if sick == 0.0:
			status.emit("Your stomach settles.")
	if venom > 0.0:
		venom = maxf(venom - VENOM_FADE * rest * delta, 0.0)
		if venom == 0.0:
			status.emit("The venom wears off.")
	if alcohol > 0.0:
		var was := drinks()
		alcohol = maxf(alcohol - ALCOHOL_FADE * delta, 0.0)
		if drinks() >= 9:
			_vomit_t -= delta
			if _vomit_t <= 0.0:
				_vomit_t = randf_range(VOMIT_EVERY[0], VOMIT_EVERY[1])
				water = maxf(water - VOMIT_LOSS.water, 0.0)
				energy = maxf(energy - VOMIT_LOSS.energy, 0.0)
				status.emit("You double over and vomit.")
		if was >= 2 and drinks() < 2:
			status.emit("Your head clears.")
	if chill > 0.0:
		chill = maxf(chill - delta * (3.0 if sleeping else 1.0), 0.0)
		if chill == 0.0:
			status.emit("You feel warm again.")
	var lost := _tick_wounds(delta, wading or swimming, sleeping)
	if lost > 0.0:
		lose_blood(lost, "blood")
	elif hl < 3 and tl < 3 and blood < 100.0:
		# Rest and food rebuild lost blood (not while starving or very thirsty).
		blood = minf(blood + BLOOD_REGEN * rest * nutrition() * heal_mult() * HUNGER_HEAL[hl] * delta, 100.0)
	_check_death()


func _say_needs(hl: int, tl: int) -> void:
	## Says when hunger or thirst gets bad enough to cost you something.
	if hl > _hunger_was and hl >= 2:
		status.emit(["", "", "You are hungry: you tire and heal more slowly.", "You are starving. Eat, or it will kill you.",
				"You are dying of starvation. Eat something now."][hl])
	if tl > _thirst_was and tl >= 2:
		status.emit(["", "", "You are thirsty: you tire more quickly.", "You are very thirsty. Drink, or it will kill you.",
				"You are dying of thirst. Drink something now."][tl])
	_hunger_was = hl
	_thirst_was = tl


func _tick_wounds(delta: float, wet: bool, sleeping: bool) -> float:
	## Advances bleeding, dirt, infection and healing. Returns blood lost.
	var lost := 0.0
	var resist := 2.0 if greens < LOW else 1.0
	var heal: float = 0.0006 * nutrition() * (0.4 if protein < LOW else 1.0) * (3.0 if sleeping else 1.0) * heal_mult() \
			* HUNGER_HEAL[hunger_level()]
	for i in wounds.size():
		var w: Dictionary = wounds[i]
		if w.bleed > 0:
			var rate: float = BLEED_RATE[w.bleed]
			if i == pressing:
				rate *= PRESSED_RATE
			elif w.bleed == 3 and w.held > 0.0:
				rate = HELD_RATE
			lost += rate * delta
			if w.held > 0.0:
				w.held = maxf(w.held - delta, 0.0)
				if w.held == 0.0 and w.bleed == 3:
					status.emit("The wound starts bleeding heavily again. Press on it and bandage it.")
			if w.bleed == 1:
				w.bleed_t = maxf(w.bleed_t - delta, 0.0)
				if w.bleed_t == 0.0:
					w.bleed = 0
					status.emit("A wound stops bleeding.")
		# Dirt: swamp water soaks into an open wound (or through a bandage),
		# and an open wound gathers dirt from the air.
		var cover_i := 0 if w.cover == "" else (1 if w.cover == "bandage" else 2)
		if wet:
			w.dirt = minf(w.dirt + WET_DIRT[cover_i] * delta, 1.0)
		elif w.cover == "":
			w.dirt = minf(w.dirt + EXPOSE_RATE * delta, 1.0)
		_tick_infection(w, delta, resist)
		if w.inf == INF_NONE and w.bleed == 0:
			# Dirty wounds barely close; a covering helps them knit.
			var rate: float = heal * (1.0 - 0.75 * w.dirt) * (1.3 if w.cover != "" else 1.0)
			w.sev = maxf(w.sev - rate * delta, 0.0)
	for w in wounds.duplicate():
		if w.sev <= 0.0 and w.inf == INF_NONE and w.bleed == 0:
			wounds.erase(w)
			status.emit("A wound has healed.")
	return lost


func _tick_infection(w: Dictionary, delta: float, resist: float) -> void:
	if w.inf == INF_NONE:
		# A clean, covered wound is safe. Open (or covered over dirt), dirt
		# brings infection.
		if w.dirt <= 0.05 and w.cover != "":
			return
		var chance: float = INFECT_RATE * w.dirt * resist * (0.5 if w.cover != "" else 1.0)
		if randf() < chance * delta:
			_set_inf(w, INF_MINOR)
			status.emit("A wound is red, hot and swollen: it is getting infected.")
		return
	w.inf_t += delta * (1.5 if greens < LOW and w.inf != INF_SEPSIS else 1.0)
	match w.inf:
		INF_MINOR:
			if w.inf_t >= MINOR_TIME:
				var good: bool = w.cover != "" and w.dirt < 0.1
				if randf() < MINOR_WORSEN[0 if good else 1]:
					_set_inf(w, INF_MODERATE)
					status.emit("The infection is getting worse. You feel feverish.")
				else:
					_set_inf(w, INF_NONE)
					status.emit("A minor infection has cleared up on its own.")
		INF_MODERATE:
			if w.inf_t >= MODERATE_TIME:
				_set_inf(w, INF_MAJOR)
				status.emit("The infection is spreading badly.")
		INF_MAJOR:
			if w.inf_t >= MAJOR_TIME:
				_set_inf(w, INF_SEPSIS)
				status.emit("The infection is in your blood. You are septic.")
		INF_REMISSION:
			if w.inf_t >= REMISSION_TIME:
				_set_inf(w, INF_MAJOR)
				status.emit("The infection flares up again.")


func _set_inf(w: Dictionary, stage: int) -> void:
	w.inf = stage
	w.inf_t = 0.0
	if stage != INF_MODERATE:
		w.sterile = false


func lose_blood(amount: float, why := "blood") -> void:
	if dead or god or amount <= 0.0:
		return
	blood = maxf(blood - amount, 0.0)
	if blood <= 0.0:
		_die(why)


func drown(delta: float) -> void:
	## Exhausted in deep water, swallowing it.
	if dead or god:
		return
	drowning = minf(drowning + delta / DROWN_TIME, 1.0)
	_check_death()


func _check_death() -> void:
	if dead or god:
		return
	var h := harms()
	for k in h:
		if h[k] >= 1.0:
			_die(k)
			return


func _die(why: String) -> void:
	if dead or god:
		return
	if why == "blood":
		blood = 0.0
	cause = why
	dead = true
	died.emit()


# --- Getting hurt -------------------------------------------------------------------

static func bleed_for(severity: float) -> int:
	if severity < 0.15:
		return 0
	if severity < 0.3:
		return 1
	if severity < 0.55:
		return 2
	return 3


func add_wound(severity: float, dirt: float, source: String) -> void:
	if dead or god:
		return
	var level: int = _new_wound(severity, dirt, source).bleed
	if level >= 2:
		status.emit("You are bleeding %s. Apply pressure (Health tab)." % ("heavily" if level == 3 else "steadily"))


func _new_wound(severity: float, dirt: float, source: String) -> Dictionary:
	severity = clampf(severity, 0.05, 1.0)
	var w := {
		"sev": severity, "bleed": bleed_for(severity), "bleed_t": 20.0 + 60.0 * severity, "held": 0.0,
		"dirt": clampf(dirt, 0.0, 1.0), "cover": "", "inf": INF_NONE, "inf_t": 0.0,
		"sterile": false, "src": source,
	}
	wounds.append(w)
	return w


func reopen() -> bool:
	## Another attack tears a covered wound open again: dirty and bleeding.
	for w in wounds:
		if w.cover != "":
			w.cover = ""
			w.dirt = minf(w.dirt + 0.4, 1.0)
			w.bleed = maxi(w.bleed, 1)
			w.bleed_t = 30.0
			status.emit("The blow tears a dressed wound open again.")
			return true
	return false


func break_limb(limb: String) -> void:
	if dead or god:
		return
	limbs[limb] = maxi(int(limbs.get(limb, 0)), MEND[limb])
	status.emit({"arm": "Your arm snaps. It is broken.", "leg": "Your leg gives way under you. It is broken.",
			"ankle": "You land badly and twist your ankle."}[limb])


func slept() -> void:
	## A night's (or nap's) sleep: sprains and fractures mend a step.
	for k in limbs.keys():
		limbs[k] -= 1
		if limbs[k] <= 0:
			limbs.erase(k)
			status.emit({"arm": "Your arm has mended.", "leg": "Your leg has mended.", "ankle": "Your ankle feels sound again."}[k])


func poison(amount: float) -> void:
	if dead or god:
		return
	venom = minf(venom + amount * VENOM_PER, 100.0)
	status.emit("Venom burns in your veins!")
	_check_death()


func give_condition(id: String) -> bool:
	## Debug: gives you one of DEBUG_CONDITIONS at once, even with damage
	## switched off (where it then can't kill you). False for an unknown id.
	if dead:
		return false
	match id:
		"bleed_minor", "bleed_moderate", "bleed_major":
			_new_wound({"bleed_minor": 0.22, "bleed_moderate": 0.42, "bleed_major": 0.7}[id], 0.2, "debug")
		"dirty_wound":
			var w := _new_wound(0.3, 0.6, "debug")
			w.bleed = 0
		"infection_minor", "infection_moderate", "infection_major", "infection_remission", "sepsis":
			var w := _new_wound(0.35, 0.5, "debug")
			w.bleed = 0
			w.inf = {"infection_minor": INF_MINOR, "infection_moderate": INF_MODERATE, "infection_major": INF_MAJOR,
				"infection_remission": INF_REMISSION, "sepsis": INF_SEPSIS}[id]
		"broken_arm", "broken_leg", "sprained_ankle":
			var limb: String = id.get_slice("_", 1)
			limbs[limb] = maxi(int(limbs.get(limb, 0)), MEND[limb])
		"blood_loss":
			blood = minf(blood, 50.0)
		"venom":
			venom = minf(venom + 40.0, 100.0)
		"food_poisoning":
			sick = maxf(sick, 90.0)
		"chilled":
			chill = maxf(chill, 240.0)
		"starving":
			energy = 0.0
			starving = maxf(starving, 0.3)
			_hunger_was = 4
		"thirst":
			water = 0.0
			thirst = maxf(thirst, 0.3)
			_thirst_was = 4
		"tipsy", "drunk", "very_drunk", "vomiting_drunk", "blind_drunk":
			alcohol = {"tipsy": 2.0, "drunk": 4.0, "very_drunk": 6.0, "vomiting_drunk": 9.0, "blind_drunk": 13.0}[id]
			_vomit_t = 3.0
		"low_protein", "low_greens", "low_starch":
			set(id.get_slice("_", 1), LOW * 0.5)
		_:
			return false
	return true


func cure_all() -> void:
	## Debug: every condition gone, and fed, watered and rested.
	blood = 100.0
	venom = 0.0
	starving = 0.0
	thirst = 0.0
	drowning = 0.0
	sick = 0.0
	chill = 0.0
	alcohol = 0.0
	wounds.clear()
	limbs.clear()
	pressing = -1
	energy = MAX_ENERGY
	water = 100.0
	_hunger_was = 0
	_thirst_was = 0
	protein = 100.0
	greens = 100.0
	starch = 100.0
	stamina = max_stamina()


# --- Treatment ----------------------------------------------------------------------

func _pick(i: int, want: Callable) -> int:
	## Wound i, or the one `want` scores highest (-1 if none scores above 0).
	if i >= 0:
		return i if i < wounds.size() and want.call(wounds[i]) > 0.0 else -1
	var best := -1
	var score := 0.0
	for k in wounds.size():
		var s: float = want.call(wounds[k])
		if s > score:
			best = k
			score = s
	return best


func apply_pressure(i := -1) -> bool:
	## Pressure held on wound i (or the worst bleeding one) for PRESSURE_TIME:
	## moderate bleeding stops, major bleeding is held back for HELD_TIME, in
	## which a bandage will stop it.
	var k := _pick(i, func(w): return float(w.bleed))
	if k < 0:
		return false
	var w: Dictionary = wounds[k]
	if w.bleed == 3:
		w.held = HELD_TIME
		status.emit("The bleeding slows under your hands. Bandage it now, before it starts again.")
	else:
		w.bleed = 0
		status.emit("The bleeding stops.")
	return true


func wash(i := -1, alcohol := false) -> bool:
	## Washes wound i, or every wound that is dirty or infected, with boiled
	## water (or alcohol). A covering comes off to do it. Alcohol also fights
	## infection: moderate is cleared once bandaged, major goes into
	## remission, remission becomes minor.
	var want := func(w): return 1.0 if w.dirt > 0.0 or w.inf != INF_NONE or (alcohol and not w.sterile) else 0.0
	var ks := []
	if i >= 0:
		if i < wounds.size():
			ks = [i]
	else:
		for k in wounds.size():
			if want.call(wounds[k]) > 0.0:
				ks.append(k)
	if ks.is_empty():
		return false
	for k in ks:
		var w: Dictionary = wounds[k]
		w.dirt = 0.0
		if w.cover != "" and (w.inf != INF_NONE or alcohol):
			w.cover = ""
		if alcohol:
			match w.inf:
				INF_MAJOR:
					_set_inf(w, INF_REMISSION)
					status.emit("The alcohol burns. The infection is beaten back, for now: treat it again.")
				INF_REMISSION:
					_set_inf(w, INF_MINOR)
					status.emit("The infection is down to a minor one. Keep it clean and covered.")
				_:
					w.sterile = true
	return true


func cover(i: int, with: String) -> String:
	## Covers wound i (or the open wound that needs it most) with a bandage or
	## waxy residue. Returns why it can't, or "". A bandage stops minor
	## bleeding, and major bleeding held back by pressure; nothing goes on a
	## wound still bleeding harder than that. Wax only seals a wound that has
	## stopped bleeding. Covering a clean wound with a minor infection clears
	## it; bandaging a moderate one cleaned with alcohol clears that.
	var k := _pick(i, func(w): return 0.0 if w.cover != "" else 1.0 + w.bleed + w.sev)
	if k < 0:
		return "All your wounds are already covered." if not wounds.is_empty() else "You have no wounds that need that."
	var w: Dictionary = wounds[k]
	if w.cover != "":
		return "That wound is already covered."
	if with == "wax" and w.bleed > 0:
		return "Wax won't stick to a bleeding wound."
	if w.bleed == 2 or (w.bleed == 3 and w.held <= 0.0):
		return "It soaks straight through. Press on the wound to stop the bleeding first."
	w.cover = with
	if w.bleed > 0:
		w.bleed = 0
		w.held = 0.0
		status.emit("The bandage stops the bleeding.")
	if w.inf == INF_MINOR and w.dirt < 0.1:
		_set_inf(w, INF_NONE)
		status.emit("Clean and covered, the minor infection clears up.")
	elif w.inf == INF_MODERATE and w.sterile and with == "bandage":
		_set_inf(w, INF_NONE)
		status.emit("Cleaned with alcohol and bandaged, the infection clears up.")
	return ""


static func wound_name(w: Dictionary) -> String:
	if w.sev > 0.6:
		return "Mauling"
	if w.sev > 0.35:
		return "Deep wound"
	if w.sev > 0.15:
		return "Cut"
	return "Scratch"


func consume(def: Dictionary, rng: RandomNumberGenerator) -> void:
	## Eating or drinking an item (its definition). Salted food has less (even
	## negative) water: it makes you thirsty. Alcohol, or food preserved in
	## it, is a drink.
	energy = minf(energy + def.get("energy", 0.0), MAX_ENERGY)
	water = clampf(water + def.get("water", 0.0), 0.0, 100.0)
	if def.get("alcohol", 0.0) > 0.0:
		drink_alcohol(def.alcohol)
	protein = minf(protein + def.get("protein", 0.0), 100.0)
	greens = minf(greens + def.get("greens", 0.0), 100.0)
	starch = minf(starch + def.get("starch", 0.0), 100.0)
	if rng.randf() < def.get("sick", 0.0):
		sick = maxf(sick, 90.0)
		status.emit("Your stomach turns. You are sick.")


# --- Telling the player -------------------------------------------------------------

const BAD := Color(1.0, 0.3, 0.25)
const WARN := Color(1.0, 0.65, 0.3)
const MILD := Color(0.95, 0.85, 0.5)
const GOOD := Color(0.7, 0.9, 0.6)
const NEED_COLORS := [GOOD, Color(0.95, 0.92, 0.75), MILD, WARN, BAD]  # by hunger or thirst level


func problems() -> Array:
	## Everything wrong, worst first: [{words, color, rank, say, advice}].
	## `words` is a couple of words for the HUD, `say` a sentence for the
	## Health tab and `advice` what to do about it.
	var out := []
	var bl := bleed_level()
	if bl == 3:
		var held := wounds.any(func(w): return w.bleed == 3 and w.held > 0.0)
		out.append({"words": "Bleeding badly", "color": BAD, "rank": 9.0,
			"say": "A wound is bleeding heavily%s." % (" (held back for now)" if held else ""),
			"advice": "Apply pressure, then bandage it while the pressure holds the bleeding back."})
	elif bl == 2:
		out.append({"words": "Bleeding", "color": WARN, "rank": 6.0, "say": "A wound is bleeding steadily. It won't stop by itself.",
			"advice": "Apply pressure to it until it stops."})
	elif bl == 1:
		out.append({"words": "Bleeding a little", "color": MILD, "rank": 1.5, "say": "A wound is bleeding a little.",
			"advice": "It will stop on its own. A bandage stops it at once."})
	var h := harms()
	if h.blood >= 0.1:
		out.append({"words": _graded(h.blood, ["Pale", "Weak from blood loss", "Faint from blood loss", "Dying of blood loss"]),
			"color": _color(h.blood), "rank": 10.0 * h.blood,
			"say": "You have lost %s blood." % ["some", "a lot of", "a dangerous amount of", "too much"][_grade(h.blood)],
			"advice": "Rest (sleep, or keep still) and keep fed and watered to rebuild it."})
	if venom > 0.0:
		out.append({"words": _graded(h.venom, ["Envenomed", "Envenomed", "Badly envenomed", "Dying of venom"]),
			"color": _color(h.venom), "rank": 10.0 * h.venom + 0.5,
			"say": "Venom is in your blood.", "advice": "Rest (sleep, or keep still) until it wears off. Avoid another sting."})
	var inf := infection()
	if inf != INF_NONE:
		var w: Dictionary = wounds.filter(func(x): return x.inf == inf)[0]
		var words: String = {INF_MINOR: "Infected wound", INF_MODERATE: "Feverish", INF_MAJOR: "Badly infected",
			INF_REMISSION: "Infection held back", INF_SEPSIS: "Septic"}[inf]
		var advice: String = {
			INF_MINOR: "Wash it with boiled water (or alcohol) and cover it with a bandage or waxy residue. Left alone it will probably clear, but it may get worse.",
			INF_MODERATE: "Clean it with alcohol, then bandage it. Untreated it turns major in about a day.",
			INF_MAJOR: "Only alcohol helps now, and more than once. Untreated, sepsis follows in about a day.",
			INF_REMISSION: "Clean it with alcohol again before it flares back up.",
			INF_SEPSIS: SEPSIS_TEXT,
		}[inf]
		var say: String = SEPSIS_TEXT if inf == INF_SEPSIS else "%s in your %s." % [INF_NAMES[inf], wound_name(w).to_lower()]
		out.append({"words": words, "color": BAD if inf == INF_SEPSIS else (WARN if inf != INF_MINOR else MILD),
			"rank": 9.5 if inf == INF_SEPSIS else 2.0 + _inf_rank(inf), "say": say, "advice": "" if inf == INF_SEPSIS else advice})
	for limb in ["leg", "ankle", "arm"]:
		if limbs.has(limb):
			var n: int = limbs[limb]
			var say: String = {"arm": "Your arm is broken: you can carry half as much (a sack still holds its share), and carrying anything big is slow.",
				"leg": "Your leg is broken: you move 40% slower and can't sprint.",
				"ankle": "Your ankle is sprained: you move 40% slower and can't sprint."}[limb]
			out.append({"words": LIMB_NAMES[limb], "color": WARN, "rank": 4.0, "say": say,
				"advice": "Sleep to let it mend: %d more sleep%s." % [n, "" if n == 1 else "s"]})
	# Hunger and thirst, from hungry/thirsty on (when they start to cost you).
	# `need`: the HUD shows these on their own lines, not in status_words.
	var hl := hunger_level()
	if hl >= 2:
		out.append({"words": HUNGER_NAMES[hl], "color": NEED_COLORS[hl], "need": true,
			"rank": [0.0, 0.0, 1.0, 3.0, 5.0][hl] + 10.0 * starving,
			"say": ["", "", "You are hungry: you tire and heal more slowly.",
				"You are starving: you tire quickly, barely heal, and it is wearing you down.",
				"You are dying of starvation."][hl],
			"advice": "Eat soon." if hl == 2 else "Eat something now."})
	elif starving > 0.0:
		out.append({"words": "Weak from hunger", "color": _color(starving), "rank": 10.0 * starving,
			"say": "You are still weak from starving.", "advice": "Keep eating; it passes."})
	var tl := thirst_level()
	if tl >= 2:
		out.append({"words": THIRST_NAMES[tl], "color": NEED_COLORS[tl], "need": true,
			"rank": [0.0, 0.0, 1.0, 3.0, 5.0][tl] + 10.0 * thirst,
			"say": ["", "", "You are thirsty: you tire more quickly.",
				"You are very thirsty: you tire quickly, and it is wearing you down.",
				"You are dying of thirst."][tl],
			"advice": "Drink soon." if tl == 2 else "Drink something now (boiled water is safest)."})
	elif thirst > 0.0:
		out.append({"words": "Weak from thirst", "color": _color(thirst), "rank": 10.0 * thirst,
			"say": "You are still weak from thirst.", "advice": "Keep drinking; it passes."})
	if drowning > 0.0:
		out.append({"words": "Drowning", "color": BAD, "rank": 10.0 * drowning + 2.0, "say": "You are swallowing water.",
			"advice": "Get out of the deep water and catch your breath."})
	var dr := drinks()
	if dr >= 2:
		var lvl := 0 if dr < 4 else (1 if dr < 6 else (2 if dr < 9 else (3 if dr < 13 else 4)))
		var says := ["You are tipsy: you dry out a little faster and heal slowly.",
			"You are drunk: slow, drying out fast, and not healing at all.",
			"You are very drunk: the world sways, and nothing heals.",
			"You are drunk enough to be sick: you keep vomiting up food and water.",
			"You are dangerously drunk: your sight is going. Any more could kill you."]
		out.append({"words": ["Tipsy", "Drunk", "Very drunk", "Vomiting drunk", "Blind drunk"][lvl],
			"color": [MILD, WARN, WARN, BAD, BAD][lvl], "rank": [1.6, 3.0, 4.5, 6.5, 9.0][lvl], "say": says[lvl],
			"advice": "Stop drinking and wait it out: one drink wears off each hour. Drink water, it dries you out."})
	if sick > 0.0:
		out.append({"words": "Sick", "color": MILD, "rank": 2.5, "say": "You have food poisoning.",
			"advice": "Rest and drink plenty: it drains your water."})
	if chill > 0.0:
		out.append({"words": "Chilled", "color": Color(0.6, 0.8, 1.0), "rank": 1.2, "say": "You are chilled to the bone.",
			"advice": "Get dry and warm by a fire; sleep warms you fastest."})
	var open := wounds.filter(func(w): return w.cover == "" and w.bleed == 0 and w.inf == INF_NONE)
	var dirty := wounds.filter(func(w): return w.dirt >= 0.3 and w.inf == INF_NONE)
	if not dirty.is_empty():
		out.append({"words": "Dirty wound", "color": MILD, "rank": 2.2, "say": "Dirt has got into a wound.",
			"advice": "Wash it with boiled water (or alcohol), then cover it with a bandage or waxy residue before it festers."})
	elif not open.is_empty():
		out.append({"words": "Open wound", "color": MILD, "rank": 1.8, "say": "A wound is open to the air.",
			"advice": "Wash it if it is dirty and cover it with a bandage or waxy residue. Keep it out of swamp water and away from animals: both open it up again."})
	if protein < LOW:
		out.append({"words": "Craving protein", "craving": "protein", "color": MILD, "rank": 0.5, "say": "You are short of protein: stamina is capped and wounds heal slowly.", "advice": "Eat grubs or meat."})
	if greens < LOW:
		out.append({"words": "Craving greens", "craving": "greens", "color": MILD, "rank": 0.5, "say": "You are short of greens: infections take hold more easily.", "advice": "Eat fiddleheads."})
	if starch < LOW:
		out.append({"words": "Craving starch", "craving": "starch", "color": MILD, "rank": 0.5, "say": "You are short of starch: you tire quickly.", "advice": "Eat seeds."})
	out.sort_custom(func(a, b): return a.rank > b.rank)
	return out


static func _grade(h: float) -> int:
	return clampi(int(h / 0.25), 0, 3)


static func _graded(h: float, words: Array) -> String:
	return words[_grade(h)]


static func _color(h: float) -> Color:
	return GOOD.lerp(MILD, clampf(h * 4.0, 0.0, 1.0)) if h < 0.25 else (WARN if h < 0.5 else BAD)


func status_words() -> Array:
	## A couple of words for the HUD: [text, color].
	if dead:
		return ["Dead", BAD]
	var all := problems()
	var p := all.filter(func(e): return not e.get("need", false))  # hunger and thirst have their own lines
	if p.is_empty():
		if all.size() > p.size():
			return ["", GOOD]  # hungry or thirsty, shown on those lines: not "Healthy"
		return ["Wounded, healing" if not wounds.is_empty() else "Healthy", GOOD]
	var words: String = p[0].words
	if p[0].has("craving"):
		# Cravings tie, so name them all ("Craving greens and starch"), not
		# just whichever sorted first.
		var what: Array = []
		for n in ["protein", "greens", "starch"]:  # in a fixed order (the sort isn't stable)
			if p.any(func(e): return e.get("craving", "") == n):
				what.append(n)
		words = "Craving " + (String(what[0]) if what.size() == 1 else ", ".join(what.slice(0, -1)) + " and " + String(what[-1]))
	elif p.size() > 1 and p[1].rank >= 1.5:
		words += ", " + String(p[1].words).to_lower()
	return [words, p[0].color]


func summary() -> String:
	## A paragraph for the Health tab.
	if infection() == INF_SEPSIS:
		return SEPSIS_TEXT
	var t := tier()
	var lead: String = ["You are in good health.", "You are hurt, but holding up: you can't sprint.",
		"You are in bad condition: slow, weak and carrying less.", "You are dying. Your sight is going dark."][t]
	if t == 0 and not problems().is_empty():
		lead = "You are holding up, but some things need looking after."
	return lead


func effects() -> Array:
	## Short status labels: [text, color], worst first.
	return problems().map(func(p): return [p.words, p.color])


# --- Saving -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"energy": energy, "energy_max": MAX_ENERGY, "water": water, "stamina": stamina,
		"protein": protein, "greens": greens, "starch": starch,
		"blood": blood, "venom": venom, "starving": starving, "thirst": thirst,
		"sick": sick, "chill": chill, "alcohol": alcohol, "wounds": wounds.duplicate(true), "limbs": limbs.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	for k in ["energy", "water", "stamina", "protein", "greens", "starch", "blood", "venom", "starving", "thirst", "sick", "chill", "alcohol"]:
		if d.has(k):
			set(k, float(d[k]))
	if d.has("energy"):
		# Saves from before energy held MAX_ENERGY: keep how full it was.
		energy = clampf(energy * MAX_ENERGY / float(d.get("energy_max", 100.0)), 0.0, MAX_ENERGY)
	_hunger_was = hunger_level()
	_thirst_was = thirst_level()
	if not d.has("blood") and d.has("venom") and float(d.venom) > 0.0:
		venom = minf(float(d.venom), 100.0)  # an old save's seconds of venom
	wounds.clear()
	for w in d.get("wounds", []):
		wounds.append(_wound_from(w))
	limbs.clear()
	var src: Dictionary = d.get("limbs", {})
	for k in src:
		if MEND.has(k):
			limbs[k] = int(src[k])
	drowning = 0.0
	pressing = -1
	cause = ""


static func _wound_from(w: Dictionary) -> Dictionary:
	## A saved wound, including one from before bleeding levels and infection
	## stages (bleed in seconds, inf 0..1, bandaged).
	var sev := float(w.get("sev", 0.2))
	var out := {"sev": sev, "bleed_t": float(w.get("bleed_t", 30.0)), "held": float(w.get("held", 0.0)),
		"dirt": float(w.get("dirt", 0.0)), "cover": String(w.get("cover", "")), "inf_t": float(w.get("inf_t", 0.0)),
		"sterile": bool(w.get("sterile", false)), "src": str(w.get("src", ""))}
	if w.has("cover"):
		out.bleed = clampi(int(w.get("bleed", 0)), 0, 3)
		out.inf = clampi(int(w.get("inf", 0)), INF_NONE, INF_SEPSIS)
	else:
		var bandaged := bool(w.get("bandaged", false))
		out.cover = "bandage" if bandaged else ""
		out.bleed = bleed_for(sev) if float(w.get("bleed", 0.0)) > 0.0 and not bandaged else 0
		var inf := float(w.get("inf", 0.0))
		out.inf = INF_MAJOR if inf >= 0.95 else (INF_MODERATE if inf > 0.45 else (INF_MINOR if inf > 0.0 else INF_NONE))
	return out


static func ease(d: Dictionary, why: String) -> Dictionary:
	## A saved body (to_dict) made one step better in whatever killed you, so
	## that a save is never stuck dying of the same thing: blood back up a
	## tier and each bleed a level less, venom a tier less, starving or
	## thirst a tier less (with a little to eat or drink), and the worst
	## infection a stage less (sepsis -> major -> major in remission ->
	## minor -> none).
	var out := d.duplicate(true)
	match why:
		"blood":
			out.blood = minf(float(out.get("blood", 100.0)) + 25.0, 100.0)
			for w in out.get("wounds", []):
				if w.has("cover"):
					w.bleed = maxi(int(w.get("bleed", 0)) - 1, 0)
					w.held = 0.0
				else:
					w.bleed = 0.0
		"venom":
			out.venom = maxf(float(out.get("venom", 0.0)) - 25.0, 0.0)
		"alcohol":
			out.alcohol = maxf(float(out.get("alcohol", 0.0)) - 4.0, 0.0)
		"starving":
			# Enough to eat to be only hungry: over 25%, where starving stops.
			out.starving = maxf(float(out.get("starving", 0.0)) - 0.25, 0.0)
			out.energy = maxf(float(out.get("energy", 0.0)), 0.3 * float(out.get("energy_max", 100.0)))
		"thirst":
			out.thirst = maxf(float(out.get("thirst", 0.0)) - 0.25, 0.0)
			out.water = maxf(float(out.get("water", 0.0)), 30.0)
		"infection":
			var ws: Array = []
			for w in out.get("wounds", []):
				ws.append(_wound_from(w))
			var worst := -1
			for k in ws.size():
				if ws[k].inf != INF_NONE and (worst < 0 or _inf_rank(ws[k].inf) > _inf_rank(ws[worst].inf)):
					worst = k
			if worst >= 0:
				var w: Dictionary = ws[worst]
				w.inf = {INF_SEPSIS: INF_MAJOR, INF_MAJOR: INF_REMISSION, INF_REMISSION: INF_MINOR,
					INF_MODERATE: INF_MINOR, INF_MINOR: INF_NONE}[w.inf]
				w.inf_t = 0.0
			out.wounds = ws
	return out
