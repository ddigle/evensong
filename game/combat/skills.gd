class_name Skills
extends RefCounted
## M9a: the skill kit (● gameplay-design §2.2 R42, the hybrid of four slots): which skill sits in which slot, when a skill may
## start (the common refusals), the near-cursor ally pick every heal and buff uses (● §2.1 R42), the class resources' caps and
## the signature's spend, and what each built skill does when it lands. Pure rules on Player / Arena; the offline game
## (core/main.gd) calls land() on a skill's impact frame, the player (actors/player.gd) calls prepare() when a skill key is
## pressed. M9a was offline; M9c: in sessions the host calls prepare() again on its own state for a SKILL / THROW request and
## land() on the impact frame (net/session_host.gd), every member keeps `skills_on`.
##
## Slots (● R42): 1 identity (fixed per class), 2 weapon (decided by the held class weapon: Config.SKILL_BY_WEAPON), 3 choice
## (an unlock pool: not in the slice count "5클래스 × 고정 2 + 무기군 5 = 15", so the slot stays locked), R signature (fixed,
## spends the class resource). Keys 1 2 3 R are ○ §1. The content of every skill is not designed (R42: "각 클래스의 스킬 내용은
## 층 3에서 정하고"): the five identity skills built here are PROVISIONAL placeholders fitted to the ● class roles (game-concept
## §3), one table of numbers each (Config.SKILLS), so the human can swap them cheaply. The weapon skills and the signatures are
## named (Config.SKILL_BY_WEAPON, SKILL_KITS) and come in M9b; a key whose skill has no table row is refused "not built yet".
##
## A skill plays a body action the slice already has (Config.SKILLS "anim": magic, bow, pickaxe, throw; no new art) and lands on
## its impact frame ("impact"). It is committed when it lands: the cooldown starts then (game ticks) and a signature spends
## its resource then; a hit before that cuts the action off and nothing is spent (the M6 drink rule).
##
## M9b builds the other ten, the same way (PROVISIONAL placeholders, one table of numbers each in Config.SKILLS): the weapon
## skills (key 2, the held class weapon decides: the paladin's crushing blow, the archer's fan shot, the cleric's holy burst, the
## miner's heavy strike, the herbalist's sweep; a tier-1 weapon lands its Config.GEAR_T1_DAMAGE_PCT and wears once per use, like
## its basic attack) and the signatures (key R, spending the class resource when they land: the guardian oath, the arrow rain,
## the blessing, the rockfall, the healing mist). The skills aimed at a point (POINT_SKILLS) take the cursor pulled in to their
## range and to the last point before a wall (reach_point) when the key is pressed.

enum Slot { IDENTITY, WEAPON, CHOICE, SIGNATURE }

const SLOT_NAMES: PackedStringArray = ["identity", "weapon", "choice", "signature"]
const SLOT_KEYS: PackedStringArray = ["1", "2", "3", "R"]

## The five identity skills (M9a).
const TAUNT: StringName = &"taunt"
const PIERCING_ARROW: StringName = &"piercing_arrow"
const HEAL: StringName = &"heal"
const GROUND_SLAM: StringName = &"ground_slam"
const POTION_THROW: StringName = &"potion_throw"
## M9b: the five weapon skills (key 2) and the five signatures (key R).
const CRUSHING_BLOW: StringName = &"crushing_blow"
const FAN_SHOT: StringName = &"fan_shot"
const HOLY_BURST: StringName = &"holy_burst"
const HEAVY_STRIKE: StringName = &"heavy_strike"
const SWEEP: StringName = &"sweep"
const GUARDIAN_OATH: StringName = &"guardian_oath"
const ARROW_RAIN: StringName = &"arrow_rain"
const BLESSING: StringName = &"blessing"
const ROCKFALL: StringName = &"rockfall"
const HEALING_MIST: StringName = &"healing_mist"
## M9b: the skills aimed at a point (prepare() puts the cursor, pulled in by reach_point, into Prepared.throw_to).
const POINT_SKILLS: Array[StringName] = [&"holy_burst", &"arrow_rain", &"rockfall", &"healing_mist"]
## M9c: every skill of the slice in a fixed order (its index names it on the wire: a skill's shot event, NetProtocol).
const ALL: Array[StringName] = [&"taunt", &"piercing_arrow", &"heal", &"ground_slam", &"potion_throw", &"crushing_blow",
	&"fan_shot", &"holy_burst", &"heavy_strike", &"sweep", &"guardian_oath", &"arrow_rain", &"blessing", &"rockfall",
	&"healing_mist"]

## Why a skill key was refused (logs, tests; the HUD shows a mark, it has no font).
const WHY_LOCKED: String = "the choice slot is not in the slice"
const WHY_LATER: String = "not built yet"
const WHY_NO_SKILL: String = "no skill in that slot"
const WHY_NO_WEAPON: String = "hold your class weapon"
const WHY_DOWN: String = "down"
const WHY_DEAD: String = "dead"
const WHY_CARRYING: String = "carrying the altar"
const WHY_PANEL: String = "a panel is open"
const WHY_BUSY: String = "mid-action"
const WHY_COOLDOWN: String = "cooling down"
const WHY_RESOURCE: String = "not enough"
const WHY_NO_ALLY: String = "no ally near the cursor"
const WHY_FULL_HP: String = "full hp"
const WHY_NO_ARENA: String = "no arena"
## M9b: the held class weapon is broken while Gear.broken_unusable (Config.GEAR_BROKEN_UNUSABLE, off: a broken weapon works as its
## base, so its skill does too).
const WHY_BROKEN: String = "broken"
## M10a: the player prays at the altar (Player.prayer_role: its move keys are answers, nothing else starts; README "M10a F").
const WHY_PRAYING: String = "praying"


## The skill in slot `slot` of class `class_id` (Config.SKILL_KITS; the weapon slot: the held class weapon's,
## Config.SKILL_BY_WEAPON), &"" for none.
static func kit_skill(class_id: String, slot: int) -> StringName:
	if slot == Slot.WEAPON:
		return Config.SKILL_BY_WEAPON.get(Combat.class_weapon(class_id), &"")
	var kit: Array = Config.SKILL_KITS.get(class_id, [])
	if slot < 0 or slot >= kit.size():
		return &""
	var id: StringName = kit[slot]
	return id


## The slot skill `id` sits in for class `class_id` (-1 = not in its kit).
static func slot_of(class_id: String, id: StringName) -> int:
	for slot: int in SkillState.SLOT_COUNT:
		if not id.is_empty() and kit_skill(class_id, slot) == id:
			return slot
	return -1


## Skill `id` has its numbers (Config.SKILLS) and so is built.
static func built(id: StringName) -> bool:
	return not id.is_empty() and Config.SKILLS.has(id)


## An action played with `item` is skill `id`'s (Player.action_item holds the skill id for a skill's action; the herbalist's
## throw keeps its potion there, it lands through Potions).
static func is_skill(item: StringName) -> bool:
	return built(item) and item != POTION_THROW


static func num_i(id: StringName, key: String) -> int:
	var row: Dictionary = Config.SKILLS.get(id, {})
	var v: int = row.get(key, 0)
	return v


static func num_f(id: StringName, key: String) -> float:
	var row: Dictionary = Config.SKILLS.get(id, {})
	var v: float = row.get(key, 0.0)
	return v


## The body action skill `id` plays (RigData.Anim).
static func anim(id: StringName) -> int:
	return num_i(id, "anim")


## The tick of its action on which skill `id` lands.
static func impact_tick(id: StringName) -> int:
	return num_i(id, "impact") * Config.ACTION_FRAME_TICKS


## Skill `id`'s cooldown (game ticks, from the tick it lands).
static func cooldown_ticks(id: StringName) -> int:
	return num_i(id, "cooldown")


## M9c: skill `id` lets shots go (its table has a speed and a reach: the piercing arrow, the fan shot).
static func shoots(id: StringName) -> bool:
	return built(id) and num_f(id, "speed") > 0.0 and num_f(id, "reach_px") > 0.0


## M9c: the ticks a shot of skill `id` flies at most (its reach at its speed; Arena.skill_shot / fan_shot and a client's track).
static func shot_life(id: StringName) -> int:
	var speed: float = num_f(id, "speed")
	return ceili(num_f(id, "reach_px") / speed * Config.NET_TICK_RATE) if speed > 0.0 else 0


## M9c: the longest cooldown of any skill (a skills message's limit), the largest class meter, the longest ward (a ward event's).
static func max_cooldown() -> int:
	var m: int = 0
	for id: StringName in Config.SKILLS:
		m = maxi(m, cooldown_ticks(id))
	return m


static func max_resource() -> int:
	var m: int = 0
	for class_id: String in Config.SKILL_RESOURCE_CAP:
		m = maxi(m, resource_cap(class_id))
	return m


static func max_ward_ticks() -> int:
	return num_i(GUARDIAN_OATH, "ward_ticks")


# --- class resources (Config "M9a 자원") ------------------------------------------------------------------

## The cap of class `class_id`'s meter (0 = no meter: the herbalist's material is items).
static func resource_cap(class_id: String) -> int:
	return Config.SKILL_RESOURCE_CAP.get(class_id, 0)


## What player `p` has of its class resource now: the meter, or (the herbalist) the healing herbs it carries, any grade.
static func resource_of(p: Player) -> int:
	if p.class_id() == "herbalist":
		return p.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM)
	return p.skills.resource


## What class `class_id`'s signature spends (the archer's is the least it needs: it spends all of its focus).
static func signature_cost(class_id: String) -> int:
	return Config.SKILL_SIGNATURE_COST.get(class_id, 0)


## Player `p` has enough of its resource for its signature.
static func can_spend_signature(p: Player) -> bool:
	var cost: int = signature_cost(p.class_id())
	return cost > 0 and resource_of(p) >= cost


## Spends player `p`'s signature cost, all or nothing (the archer: all of its focus, at least the cost; the herbalist: that
## many healing herbs out of its inventory, any grade, the last stacks first). Returns what was spent (0 = nothing: too
## little).
static func spend_signature(p: Player) -> int:
	if not can_spend_signature(p):
		return 0
	var class_id: String = p.class_id()
	var cost: int = signature_cost(class_id)
	if class_id == "herbalist":
		var left: int = cost
		for slot: int in range(p.inventory.size() - 1, -1, -1):
			var s: ItemStack = p.inventory.stack_at(slot)
			if left > 0 and s != null and s.id == Config.HERBALIST_MATERIAL_ITEM:
				left -= p.inventory.remove(slot, mini(left, s.count))
		return cost - left
	if class_id == "archer":
		cost = p.skills.resource
	p.skills.spend(cost)
	return cost


# --- when a skill may start ---------------------------------------------------------------------------------

## Why player `p` may not start the skill of slot `slot` now ("" = it may): the choice slot is locked (not in the slice); the
## weapon slot without the class weapon held (M9b: or with it broken while Gear.broken_unusable); no skill or not built; down,
## dead, carrying the altar, a panel open, mid-action (an action that will still play, a dash, a stagger), cooling down, not
## enough resource (the signature). M9 review: `hotbar_slot` = the hotbar slot the press holds (-1 = the selected one; the host
## passes a SKILL request's slot, the one its sender's machine had selected, NetProtocol SKILL).
static func refusal(p: Player, slot: int, hotbar_slot: int = -1) -> String:
	if slot == Slot.CHOICE:
		return WHY_LOCKED
	var class_id: String = p.class_id()
	if slot == Slot.WEAPON:
		var held: ItemStack = held_stack(p, hotbar_slot)
		var weapon: StringName = Combat.class_weapon(class_id)
		if held == null or weapon.is_empty() or Gear.base(held.id) != weapon:
			return WHY_NO_WEAPON
		if p.gear_on and Gear.unusable(held):
			return WHY_BROKEN  # M9b: like the basic attack (Config.GEAR_BROKEN_UNUSABLE)
	var id: StringName = kit_skill(class_id, slot)
	if id.is_empty():
		return WHY_NO_SKILL
	if not built(id):
		return WHY_LATER
	if p.vitals.life == Vitals.Life.DOWN:
		return WHY_DOWN
	if p.vitals.life == Vitals.Life.DEAD:
		return WHY_DEAD
	if p.carrying_altar:
		return WHY_CARRYING
	if p.prayer_role == Prayer.Role.PRAYING:
		return WHY_PRAYING  # M10a
	if p.ui_locked:
		return WHY_PANEL
	if busy(p):
		return WHY_BUSY
	if p.skills.cooldown(slot) > 0:
		return WHY_COOLDOWN
	if slot == Slot.SIGNATURE and not can_spend_signature(p):
		return WHY_RESOURCE
	return ""


## M9 review: the stack in hotbar slot `hotbar_slot` of player `p` (-1 = the selected one; a slot past the hotbar = none).
static func held_stack(p: Player, hotbar_slot: int = -1) -> ItemStack:
	if hotbar_slot < 0:
		return p.inventory.selected_stack()
	return p.inventory.stack_at(hotbar_slot) if hotbar_slot < p.inventory.hotbar_size else null


## An action will still play on the next frame, or a dash or a stagger is under way (no action can start then).
static func busy(p: Player) -> bool:
	if p.action_anim >= 0 and p.action_tick + 1 < Player.action_ticks(p.action_anim):
		return true
	return p.vitals.dashing() or p.vitals.staggered()


# --- M9b helpers ----------------------------------------------------------------------------------------------

## M9b (PROVISIONAL README "M9b 점 스킬"): the point a skill aimed at `cursor` lands on, cast from feet `feet` on `data`: the cursor
## pulled in to `range_px` of the feet, then (whole px) back along that line to the farthest point the line from the feet reaches
## with no tile that stops a shot on it (Combat.line_clear: walls, wall faces, blocking placeables, the map's edge). So a burst,
## a strike or a cloud never lands behind a wall the caster cannot see past.
static func reach_point(data: WorldData, feet: Vector2, cursor: Vector2, range_px: float) -> Vector2:
	var d: Vector2 = cursor - feet
	if d.length() > range_px:
		d = d.normalized() * range_px
	var target: Vector2 = (feet + d).round()
	if data == null or Combat.line_clear(data, feet, target):
		return target
	var dir: Vector2 = d.normalized() if d.length_squared() > 0.0 else Vector2.ZERO
	for k: int in range(floori(d.length()), -1, -1):
		var q: Vector2 = (feet + dir * float(k)).round()
		if Combat.line_clear(data, feet, q):
			return q
	return feet.round()


## M9b: a hit of `amount` on a player whose skill state is `s` (Player.take_hit, after the armour): less the oath's ward while it
## runs (rounded down), never below Config.SKILL_WARD_MIN_DAMAGE (nor above the hit).
static func after_ward(amount: int, s: SkillState) -> int:
	if s == null or not s.warded() or amount <= 0:
		return amount
	return maxi(amount * (100 - clampi(s.ward_pct, 0, 100)) / 100, mini(Config.SKILL_WARD_MIN_DAMAGE, amount))


## M9b: the class weapon stack player `p`'s weapon skill plays: the stack in the hotbar slot it was pressed with
## (Player.action_slot) while that is still its class weapon (base or tier-1), else null (it lands at the base damage and wears
## nothing, like an attack whose weapon left the slot).
static func weapon_stack(p: Player) -> ItemStack:
	var s: ItemStack = p.inventory.stack_at(p.action_slot)
	var weapon: StringName = Combat.class_weapon(p.class_id())
	if s == null or weapon.is_empty() or Gear.base(s.id) != weapon:
		return null
	return s


## M9b: the damage a weapon skill of base damage `base` lands for player `p`: a tier-1 weapon's Config.GEAR_T1_DAMAGE_PCT while it
## is not broken (Gear.attack_damage, the basic attack's rule; with `gear_on`, as offline Main's player), else `base`.
static func weapon_damage(p: Player, base: int) -> int:
	if not p.gear_on:
		return base
	return Gear.attack_damage(weapon_stack(p), base)


## M9b: a weapon skill's use wear (like an attack: Gear.wear_weapon once, with `gear_on`). Returns whether it wore.
static func wear_weapon(p: Player) -> bool:
	var s: ItemStack = weapon_stack(p)
	if not p.gear_on or s == null or s.max_durability() <= 0:
		return false
	return Gear.wear_weapon(p.inventory, p.action_slot, s.id) != null


# --- the near-cursor ally pick (● §2.1 R42) -----------------------------------------------------------------

## The ally a heal or buff of `caster` goes to (● §2.1 R42 "커서에서 가장 가까운 아군이 받는다"): among `party` (the players
## on the caster's map, in a fixed order: offline the local player first, then the allies), the one up (not down or dead) on
## the caster's map whose body's middle (cursor_distance: the figure the player points at; M9 review, the feet before) is
## nearest the cursor point `cursor`, within Config.SKILL_GRAB_RADIUS_PX of it and with its feet within `range_px` of the
## caster's; the caster itself counts. Ties: the first in `party`. Heretics are never in `party`, so never picked. null =
## nobody.
static func pick_ally(party: Array[Player], caster: Player, cursor: Vector2, range_px: float) -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in party:
		if not pick_ok(p, caster, cursor, range_px):
			continue
		var d: float = cursor_distance(p, cursor)
		if d < best_d:
			best = p
			best_d = d
	return best


## How far the cursor point `cursor` is from player `p` as the pick measures it: from the middle of its figure
## (Combat.body_centre, half Config.BODY_HIT_HEIGHT_PX above the feet).
static func cursor_distance(p: Player, cursor: Vector2) -> float:
	return Combat.body_centre(p.sim_position).distance_to(cursor)


## Player `p` may get a heal or buff of `caster` with the cursor at `cursor`: up, on the caster's map, within
## Config.SKILL_GRAB_RADIUS_PX + `slack` of the cursor (cursor_distance) and with its feet within `range_px` of the caster's.
static func pick_ok(p: Player, caster: Player, cursor: Vector2, range_px: float, slack: float = 0.0) -> bool:
	if p == null or not is_instance_valid(p) or not p.vitals.alive():
		return false
	if caster != null and p.data != caster.data:
		return false
	if cursor_distance(p, cursor) > Config.SKILL_GRAB_RADIUS_PX + slack:
		return false
	return caster == null or p.sim_position.distance_to(caster.sim_position) <= range_px


## M9 review (sessions, PROVISIONAL Config.SKILL_PICK_LAG_PX): the ally a heal or buff goes to on the host: `hint` (the ally the
## sender's machine picked, as it drew the players) while pick_ok allows it with the lag allowance, else the host's own pick.
static func pick_with_hint(party: Array[Player], caster: Player, cursor: Vector2, range_px: float, hint: Player) -> Player:
	if hint != null and party.has(hint) and pick_ok(hint, caster, cursor, range_px, Config.SKILL_PICK_LAG_PX):
		return hint
	return pick_ally(party, caster, cursor, range_px)


## Potion `id` is a healing or buff potion (its throw goes to an ally, ● R42; poison stays aimed at the point).
static func throw_picks_ally(id: StringName) -> bool:
	var effect: int = Potions.effect_of(id)
	return effect == Potions.Effect.HEAL or effect == Potions.Effect.BUFF


## The ally player `p`'s heal or buff would go to now with the mouse at `cursor` (the highlight under that ally), or null: the
## cleric's heal while it is ready, the herbalist's throw while a healing or buff potion is selected.
static func aim_target(p: Player, party: Array[Player], cursor: Vector2) -> Player:
	if not p.vitals.alive() or p.ui_locked or p.carrying_altar or p.prayer_role == Prayer.Role.PRAYING:
		return null  # M9 review: a panel open or the altar carried refuses the key, so no ring (M10a: nor praying)
	var id: StringName = kit_skill(p.class_id(), Slot.IDENTITY)
	if id == HEAL and built(HEAL) and p.skills.cooldown(Slot.IDENTITY) == 0:
		return pick_ally(party, p, cursor, num_f(HEAL, "range_px"))
	if id == POTION_THROW:
		var s: ItemStack = p.inventory.selected_stack()
		if s != null and throw_picks_ally(s.id):
			return pick_ally(party, p, cursor, Config.THROW_RANGE_PX)
	return null


## M9 review: the ring under `target` (aim_target's) shows a press that would be refused: the cleric's heal on an ally at full HP.
static func aim_refused(p: Player, target: Player) -> bool:
	return target != null and kit_skill(p.class_id(), Slot.IDENTITY) == HEAL and target.vitals.hp >= Config.PLAYER_HP_MAX


# --- starting a skill ----------------------------------------------------------------------------------------

## What a skill key press resolved to (prepare()).
class Prepared:
	extends RefCounted
	var id: StringName = &""
	var slot: int = -1
	## "" = it starts; else why not (nothing happens, the HUD marks the slot).
	var why: String = ""
	## The ally it goes to (the heal, a healing or buff throw), or null.
	var target: Player
	## The herbalist's throw: the potion, the point it is thrown at (whole px). M9b: a point skill's point (reach_point).
	var item: StringName = &""
	var throw_to: Vector2 = Vector2.ZERO

	func ok() -> bool:
		return why.is_empty()


## Player `p` pressed the key of slot `slot` with the mouse at `cursor`; `party` = the players on its map (pick_ally). The
## common refusals, then the skill's own: the heal needs an ally near the cursor (nobody = refused, nothing spent) who is not
## at full HP; the herbalist's throw needs a potion selected (Potions.throw_refusal) and, for a healing or buff potion, an ally
## near the cursor within the throw's range (● R42: it goes to that ally); a poison potion stays aimed at the cursor (M6).
## M9 review: `hotbar_slot` = the hotbar slot the press holds (refusal; -1 = the selected one), `hint` = the ally the sender's
## machine picked (the host's SKILL / THROW: pick_with_hint; null offline and on the client).
static func prepare(p: Player, slot: int, cursor: Vector2, party: Array[Player], hotbar_slot: int = -1,
		hint: Player = null) -> Prepared:
	var r: Prepared = Prepared.new()
	r.slot = slot
	r.id = kit_skill(p.class_id(), slot)
	r.why = refusal(p, slot, hotbar_slot)
	if not r.ok():
		return r
	match r.id:
		HEAL:
			r.target = pick_with_hint(party, p, cursor, num_f(HEAL, "range_px"), hint)
			if r.target == null:
				r.why = WHY_NO_ALLY
			elif r.target.vitals.hp >= Config.PLAYER_HP_MAX:
				r.why = WHY_FULL_HP
		POTION_THROW:
			var s: ItemStack = held_stack(p, hotbar_slot)
			r.why = Potions.throw_refusal(p.class_id(), s)
			if not r.ok():
				return r
			r.item = s.id
			var origin: Vector2 = Combat.body_point(p.sim_position)
			if throw_picks_ally(s.id):
				r.target = pick_with_hint(party, p, cursor, Config.THROW_RANGE_PX, hint)
				if r.target == null:
					r.why = WHY_NO_ALLY
					return r
				r.throw_to = Potions.throw_target(origin, Combat.body_point(r.target.sim_position)).round()
			else:
				r.throw_to = Potions.throw_target(origin, cursor).round()
	if POINT_SKILLS.has(r.id):
		r.throw_to = reach_point(p.data, p.sim_position, cursor, num_f(r.id, "range_px"))  # M9b
	return r


# --- landing ------------------------------------------------------------------------------------------------

## What a skill did when it landed (land()).
class Landed:
	extends RefCounted
	var id: StringName = &""
	## "" = it landed (the cooldown started); else why it fizzled (nothing spent, no cooldown).
	var why: String = ""
	## Heretics taunted / hit, HP healed and who.
	var taunted: int = 0
	var hits: int = 0
	var healed: int = 0
	var target: Player
	var shot: Arena.Shot
	## M9b: the fan's arrows, the resource a signature spent, players warded by the oath, the strike or zone it started, the
	## weapon skill's damage (after the tier-1 rule) and whether it wore the weapon, and the world edits it made (the shrine
	## breaking under a melee weapon skill: the caller applies them).
	var shots: Array[Arena.Shot] = []
	var spent: int = 0
	var warded: int = 0
	var strike: Arena.Strike
	var zone: Arena.Zone
	var damage: int = 0
	var wore: bool = false
	var edits: Array[EditLog.WorldEdit] = []

	func ok() -> bool:
		return why.is_empty()


## Skill `id` of player `p` reaches its impact frame (Player.action_impact with the skill id): it works on `arena` (the map's)
## and `party` (the players on that map) and, when it worked, its slot's cooldown starts (Config.SKILLS "cooldown"). The
## taunt forces the heretics around the paladin onto him (Arena.taunt), the piercing arrow lets its shot go along the aim the
## action started with, the heal restores HP to the ally picked when the key was pressed (Player.action_skill_target; gone,
## down, dead, on another map or (M9 review) at full HP now = it fizzles) and grows the cleric's faith, the ground slam hits,
## staggers and pushes the heretics around
## the miner (Arena.slam). The throw is not here: it lands through Potions.release (its potion), like M6.
## M9b: the weapon skills land along the action's aim (the melee arcs, the fan) or on its point (the holy burst) at the damage
## weapon_damage gives and wear the weapon once; a signature first spends its resource (spend_signature; too little now = it
## fizzles) and then wards, strikes or heals (_land_signature). `r.edits` = world edits for the caller (the shrine breaking).
## M9c: `owner_slot` = the caster's session slot (its shots' events name it; 255 offline).
## M10a: every damaging skill's damage is raised by the caster's zeal (Prayer.zeal_damage: the arrow and the strikes keep it).
## M11b: the archer's three arrow skills take the collection's class benefit first (Collection.arrow_damage, after the tier-1 rule).
static func land(p: Player, id: StringName, arena: Arena, party: Array[Player], owner_slot: int = 255) -> Landed:
	var r: Landed = Landed.new()
	r.id = id
	if arena == null:
		r.why = WHY_NO_ARENA
		return r
	match id:
		TAUNT:
			r.taunted = arena.taunt(p, num_f(TAUNT, "radius_px"), num_i(TAUNT, "taunt_ticks"))
		PIERCING_ARROW:
			r.shot = arena.skill_shot(p, PIERCING_ARROW, p.action_aim,
				Prayer.zeal_damage(Collection.arrow_damage(num_i(PIERCING_ARROW, "damage"), p), p),
				num_f(PIERCING_ARROW, "reach_px"), num_f(PIERCING_ARROW, "speed"), true, owner_slot)
		HEAL:
			var t: Player = null
			for q: Player in party:
				if q != null and is_instance_valid(q) and q.get_instance_id() == p.action_skill_target:
					t = q
			if t == null or not t.vitals.alive() or t.data != p.data:
				r.why = WHY_NO_ALLY
				return r
			if t.vitals.hp >= Config.PLAYER_HP_MAX:
				r.why = WHY_FULL_HP  # M9 review: full by now (another heal, a potion): nothing spent, no cooldown, as at the press
				return r
			r.target = t
			r.healed = t.heal_hp(num_i(HEAL, "heal_hp"))
			p.skills.on_heal_done(p.class_id(), r.healed)
			arena.heal_threat(p.get_instance_id(), t, r.healed, party)
			arena.add_burst(Arena.BurstKind.HEAL, t.sim_position, Config.SKILL_HEAL_SHOW_RADIUS_PX, t.get_instance_id(),
				p.get_instance_id())
		GROUND_SLAM:
			r.hits = arena.slam(p, num_f(GROUND_SLAM, "radius_px"), Prayer.zeal_damage(num_i(GROUND_SLAM, "damage"), p),
				num_f(GROUND_SLAM, "push_px"))
		CRUSHING_BLOW, HEAVY_STRIKE, SWEEP:
			# M9b: a melee arc along the aim the action started with (the sword, the pickaxe, the sickle); never mines or harvests.
			var kinds: Dictionary[StringName, int] = {CRUSHING_BLOW: Arena.BurstKind.CRUSH, HEAVY_STRIKE: Arena.BurstKind.HEAVY,
				SWEEP: Arena.BurstKind.SWEEP}
			r.damage = Prayer.zeal_damage(weapon_damage(p, num_i(id, "damage")), p)  # M10a: the zeal on top
			r.hits = arena.melee_skill(p, p.action_aim, r.damage, num_f(id, "reach_px"), num_f(id, "arc_deg"),
				num_i(id, "stun_ticks"), num_i(id, "slow_pct"), num_i(id, "slow_ticks"), kinds[id], r.edits)
			r.wore = wear_weapon(p)
		FAN_SHOT:
			r.damage = Prayer.zeal_damage(Collection.arrow_damage(weapon_damage(p, num_i(FAN_SHOT, "damage")), p), p)
			r.shots = arena.fan_shot(p, FAN_SHOT, p.action_aim, r.damage, num_i(FAN_SHOT, "arrows"),
				num_i(FAN_SHOT, "spread_aim"), num_f(FAN_SHOT, "reach_px"), num_f(FAN_SHOT, "speed"), owner_slot)
			r.wore = wear_weapon(p)
		HOLY_BURST:
			r.damage = Prayer.zeal_damage(weapon_damage(p, num_i(HOLY_BURST, "damage")), p)
			r.hits = arena.area_hit(p, p.action_target, num_f(HOLY_BURST, "radius_px"), r.damage, Arena.BurstKind.HOLY)
			r.wore = wear_weapon(p)
		GUARDIAN_OATH, ARROW_RAIN, BLESSING, ROCKFALL, HEALING_MIST:
			# M9b: the signature spends its resource now (all or nothing); too little now (an archer's focus, herbs dropped since
			# the press) = it fizzles: nothing spent, no cooldown.
			r.spent = spend_signature(p)
			if r.spent <= 0:
				r.why = WHY_RESOURCE
				return r
			_land_signature(p, id, arena, party, r)
		_:
			r.why = WHY_NO_SKILL
			return r
	var slot: int = p.action_skill_slot if p.action_skill_slot >= 0 else slot_of(p.class_id(), id)
	p.skills.start_cooldown(slot, cooldown_ticks(id))
	return r


## M9b: what signature `id` of player `p` does once its resource is spent (`r.spent`): the oath wards every player up around the
## paladin (himself too), the arrow rain and the rockfall start their strike on the point picked at the press
## (Player.action_target), the blessing starts its zone following the cleric, the healing mist its zone on the point.
static func _land_signature(p: Player, id: StringName, arena: Arena, party: Array[Player], r: Landed) -> void:
	var pid: int = p.get_instance_id()
	match id:
		GUARDIAN_OATH:
			var radius: float = num_f(GUARDIAN_OATH, "radius_px")
			var warded: Array[Player] = []
			for q: Player in party:
				if q == null or not is_instance_valid(q) or not q.vitals.alive() or q.data != p.data:
					continue
				if q.sim_position.distance_to(p.sim_position) <= radius \
						and q.skills.add_ward(num_i(GUARDIAN_OATH, "ward_pct"), num_i(GUARDIAN_OATH, "ward_ticks")):
					r.warded += 1
					warded.append(q)
			arena.add_burst(Arena.BurstKind.OATH, p.sim_position, radius, pid, pid)
			arena.note_ward(warded)  # M9c: a session's clients draw the shield over each of them
		ARROW_RAIN:
			r.damage = Prayer.zeal_damage(Collection.arrow_damage(num_i(ARROW_RAIN, "damage")
				+ r.spent * num_i(ARROW_RAIN, "damage_per_focus_pct") / 100, p), p)
			r.strike = arena.add_strike(Arena.StrikeKind.ARROWS, p.action_target, num_f(ARROW_RAIN, "radius_px"),
				num_i(ARROW_RAIN, "delay_ticks"), r.damage, 0, pid)
		ROCKFALL:
			r.damage = Prayer.zeal_damage(num_i(ROCKFALL, "damage"), p)
			r.strike = arena.add_strike(Arena.StrikeKind.ROCKS, p.action_target, num_f(ROCKFALL, "radius_px"),
				num_i(ROCKFALL, "delay_ticks"), r.damage, num_i(ROCKFALL, "stun_ticks"), pid)
		BLESSING:
			r.zone = arena.add_zone(Arena.ZoneKind.BLESSING, p.sim_position, num_f(BLESSING, "radius_px"),
				num_i(BLESSING, "duration_ticks"), num_i(BLESSING, "interval_ticks"), num_i(BLESSING, "heal_hp"), pid, pid)
		HEALING_MIST:
			r.zone = arena.add_zone(Arena.ZoneKind.MIST, p.action_target, num_f(HEALING_MIST, "radius_px"),
				num_i(HEALING_MIST, "duration_ticks"), num_i(HEALING_MIST, "interval_ticks"), num_i(HEALING_MIST, "heal_hp"), pid)
