class_name SkillState
extends RefCounted
## M9a: one player's skill kit state (offline in M9a; M9c brings it to sessions): the cooldown of each slot (game ticks, the
## game clock: they run down every tick the player is stepped, down or dead too), the class resource (● gameplay-design §2.2
## R42 "시그니처 — 클래스 자원 소모"; the resources themselves are ○ there: 신념 / 집중 / 신앙 / 지구력 / 재료) with what makes it
## grow and fade, and the HUD's refusal mark (the slot that was refused and for how long it shows: the HUD has no font, so a
## refusal is a mark, not text). Pure data and rules; combat/skills.gd decides when a skill may start and what it does, the
## player (actors/player.gd) steps this every tick (tick()) and feeds it what happened (on_hurt, on_heal_done, on_mined). All
## numbers are PROVISIONAL (core/config.gd "M9a", README "임시값" M9a 자원).
##
## Resources (Config "M9a 자원"): the paladin's conviction grows with the damage he takes (no block exists in the slice: the
## right-click secondary action, gameplay-design §1 ○ "방패 들기", is not built) and fades slowly once he has taken none for a
## while; the archer's focus grows while he stands still and drains while he moves (○ §2.5); the cleric's faith grows with the
## HP his skills heal (prayer is M10); the miner's endurance grows with every block he breaks; the herbalist has no meter: his
## material is the healing herbs in his inventory (Skills.resource_of reads them). Every meter stops at its cap and is lost on
## death (Config.SKILL_RESOURCE_LOST_ON_DEATH).
##
## M9b: the ward a paladin's guardian oath gives (ward_pct off every hit for ward_ticks: Player.take_hit applies it, Skills.after_ward).

## The four slots (● R42: identity, weapon, choice, signature; keys 1 2 3 R, ○ §1).
const SLOT_COUNT: int = 4

var cooldowns: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## The class meter (0..Skills.resource_cap(class)); unused by the herbalist (his material is items).
var resource: int = 0
## Paladin: ticks since he last took damage (counts up to the decay delay) and the decay rhythm.
var since_hurt: int = 0
var decay_tick: int = 0
## Archer: the rhythm of the focus (ticks since the last point gained or lost) and whether he moved on the last tick (the
## rhythm starts over when that changes).
var focus_tick: int = 0
var was_moving: bool = false
## The HUD's refusal mark: the slot last refused (-1 = none), ticks it still shows, and why (logs, tests).
var refused_slot: int = -1
var refused_ticks: int = 0
var refused_why: String = ""
## M9b: a ward (the paladin's guardian oath, given to every player up around him): percent off each hit, ticks left
## (Skills.after_ward, Player.take_hit; Config.SKILL_WARD_MIN_DAMAGE).
var ward_pct: int = 0
var ward_ticks: int = 0


func copy() -> SkillState:
	var c: SkillState = SkillState.new()
	c.cooldowns = cooldowns.duplicate()
	c.resource = resource
	c.since_hurt = since_hurt
	c.decay_tick = decay_tick
	c.focus_tick = focus_tick
	c.was_moving = was_moving
	c.refused_slot = refused_slot
	c.refused_ticks = refused_ticks
	c.refused_why = refused_why
	c.ward_pct = ward_pct
	c.ward_ticks = ward_ticks
	return c


## The same simulation state (the refusal mark is display only and not compared).
func same_as(o: SkillState) -> bool:
	return o != null and cooldowns == o.cooldowns and resource == o.resource and since_hurt == o.since_hurt \
		and decay_tick == o.decay_tick and focus_tick == o.focus_tick and was_moving == o.was_moving \
		and ward_pct == o.ward_pct and ward_ticks == o.ward_ticks


## Ticks left before slot `slot` may be used again (0 = ready).
func cooldown(slot: int) -> int:
	return cooldowns[slot] if slot >= 0 and slot < SLOT_COUNT else 0


func start_cooldown(slot: int, ticks: int) -> void:
	if slot >= 0 and slot < SLOT_COUNT:
		cooldowns[slot] = maxi(ticks, 0)


## Marks slot `slot` refused (`why`) for Config.SKILL_REFUSED_SHOW_TICKS.
func refuse(slot: int, why: String) -> void:
	refused_slot = slot
	refused_ticks = Config.SKILL_REFUSED_SHOW_TICKS
	refused_why = why


## Slot `slot` shows the refusal mark now.
func shows_refusal(slot: int) -> bool:
	return refused_ticks > 0 and refused_slot == slot


## One tick of the game clock for a player of `class_id`: the cooldowns and the refusal mark run down (always, down or dead
## too); while `alive` the class meter grows or fades by its rule (`moving`: the player walked or dashed this tick).
func tick(class_id: String, moving: bool, alive: bool) -> void:
	for i: int in SLOT_COUNT:
		if cooldowns[i] > 0:
			cooldowns[i] -= 1
	if refused_ticks > 0:
		refused_ticks -= 1
		if refused_ticks == 0:
			refused_slot = -1
	if ward_ticks > 0:
		ward_ticks -= 1  # M9b: the oath's ward runs out (on the game clock, down too)
		if ward_ticks == 0:
			ward_pct = 0
	if not alive:
		return
	match class_id:
		"paladin":
			if since_hurt < Config.PALADIN_CONVICTION_DECAY_DELAY_TICKS:
				since_hurt += 1
				decay_tick = 0
			elif resource > 0:
				decay_tick += 1
				if decay_tick >= Config.PALADIN_CONVICTION_DECAY_TICKS:
					decay_tick = 0
					resource -= 1
		"archer":
			if moving != was_moving:
				was_moving = moving
				focus_tick = 0
			focus_tick += 1
			if moving:
				if focus_tick >= Config.ARCHER_FOCUS_DRAIN_TICKS:
					focus_tick = 0
					resource = maxi(resource - 1, 0)
			elif focus_tick >= Config.ARCHER_FOCUS_GAIN_TICKS:
				focus_tick = 0
				gain(class_id, 1)


## Adds `n` to the class meter, not past its cap (Skills.resource_cap). Returns what was added.
func gain(class_id: String, n: int) -> int:
	var cap: int = Skills.resource_cap(class_id)
	if n <= 0 or cap <= 0:
		return 0
	var before: int = resource
	resource = mini(resource + n, cap)
	return resource - before


## Spends `n` of the class meter: all or nothing. False when there is not enough (nothing spent).
func spend(n: int) -> bool:
	if n < 0 or resource < n:
		return false
	resource -= n
	return true


## The player of `class_id` took `amount` HP of damage (a hit that landed, a poison tick): the paladin's conviction grows
## (Config.PALADIN_CONVICTION_PER_HP) and its fading waits again.
func on_hurt(class_id: String, amount: int) -> int:
	if class_id != "paladin" or amount <= 0:
		return 0
	since_hurt = 0
	decay_tick = 0
	return gain(class_id, amount * Config.PALADIN_CONVICTION_PER_HP)


## The player of `class_id` healed `amount` HP with a skill: the cleric's faith grows (Config.CLERIC_FAITH_PER_HP).
func on_heal_done(class_id: String, amount: int) -> int:
	if class_id != "cleric" or amount <= 0:
		return 0
	return gain(class_id, amount * Config.CLERIC_FAITH_PER_HP)


## The player of `class_id` broke `blocks` blocks mining: the miner's endurance grows (Config.MINER_ENDURANCE_PER_BLOCK).
func on_mined(class_id: String, blocks: int) -> int:
	if class_id != "miner" or blocks <= 0:
		return 0
	return gain(class_id, blocks * Config.MINER_ENDURANCE_PER_BLOCK)


## Death (Config.SKILL_RESOURCE_LOST_ON_DEATH): the meter is lost; the cooldowns run on (the game clock). M9b: a ward ends.
func on_death() -> void:
	if Config.SKILL_RESOURCE_LOST_ON_DEATH:
		resource = 0
	since_hurt = 0
	decay_tick = 0
	focus_tick = 0
	was_moving = false
	ward_pct = 0
	ward_ticks = 0


## M9b: a ward of `pct` percent for `ticks` (the guardian oath). A running one keeps the stronger percent and the longer time
## (Config.EFFECT_REFRESH_KEEPS_STRONGER, else the new one replaces it). False when it gives nothing.
func add_ward(pct: int, ticks: int) -> bool:
	if pct <= 0 or ticks <= 0:
		return false
	if ward_ticks > 0 and Config.EFFECT_REFRESH_KEEPS_STRONGER:
		ward_pct = maxi(ward_pct, pct)
		ward_ticks = maxi(ward_ticks, ticks)
	else:
		ward_pct = clampi(pct, 0, 100)
		ward_ticks = ticks
	return true


## M9b: warded now.
func warded() -> bool:
	return ward_ticks > 0 and ward_pct > 0


func describe() -> String:
	return "cd=%s res=%d ward=%d/%d" % [cooldowns, resource, ward_pct, ward_ticks]
