class_name Skills
extends RefCounted
## M9a: the skill kit (● gameplay-design §2.2 R42, the hybrid of four slots): which skill sits in which slot, when a skill may
## start (the common refusals), the near-cursor ally pick every heal and buff uses (● §2.1 R42), the class resources' caps and
## the signature's spend, and what each built skill does when it lands. Pure rules on Player / Arena; the offline game
## (core/main.gd) calls land() on a skill's impact frame, the player (actors/player.gd) calls prepare() when a skill key is
## pressed. M9a is offline: a session's players keep `skills_on` off (M9c), and the herbalist's M6 throw goes on there as it was.
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

enum Slot { IDENTITY, WEAPON, CHOICE, SIGNATURE }

const SLOT_NAMES: PackedStringArray = ["identity", "weapon", "choice", "signature"]
const SLOT_KEYS: PackedStringArray = ["1", "2", "3", "R"]

## The five identity skills (M9a).
const TAUNT: StringName = &"taunt"
const PIERCING_ARROW: StringName = &"piercing_arrow"
const HEAL: StringName = &"heal"
const GROUND_SLAM: StringName = &"ground_slam"
const POTION_THROW: StringName = &"potion_throw"

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

## Why player `p` may not start the skill of slot `slot` now ("" = it may): the choice slot is locked (not in the slice); no
## skill or not built yet (M9b); the weapon slot without the class weapon held; down, dead, carrying the altar, a panel open,
## mid-action (an action that will still play, a dash, a stagger), cooling down, not enough resource (the signature).
static func refusal(p: Player, slot: int) -> String:
	if slot == Slot.CHOICE:
		return WHY_LOCKED
	var class_id: String = p.class_id()
	if slot == Slot.WEAPON:
		var held: ItemStack = p.inventory.selected_stack()
		var weapon: StringName = Combat.class_weapon(class_id)
		if held == null or weapon.is_empty() or Gear.base(held.id) != weapon:
			return WHY_NO_WEAPON
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
	if p.ui_locked:
		return WHY_PANEL
	if busy(p):
		return WHY_BUSY
	if p.skills.cooldown(slot) > 0:
		return WHY_COOLDOWN
	if slot == Slot.SIGNATURE and not can_spend_signature(p):
		return WHY_RESOURCE
	return ""


## An action will still play on the next frame, or a dash or a stagger is under way (no action can start then).
static func busy(p: Player) -> bool:
	if p.action_anim >= 0 and p.action_tick + 1 < Player.action_ticks(p.action_anim):
		return true
	return p.vitals.dashing() or p.vitals.staggered()


# --- the near-cursor ally pick (● §2.1 R42) -----------------------------------------------------------------

## The ally a heal or buff of `caster` goes to (● §2.1 R42 "커서에서 가장 가까운 아군이 받는다"): among `party` (the players
## on the caster's map, in a fixed order: offline the local player first, then the allies), the one up (not down or dead) on
## the caster's map whose feet are nearest the cursor point `cursor`, within Config.SKILL_GRAB_RADIUS_PX of it and within
## `range_px` of the caster's feet; the caster itself counts. Ties: the first in `party`. Heretics are never in `party`, so
## never picked. null = nobody.
static func pick_ally(party: Array[Player], caster: Player, cursor: Vector2, range_px: float) -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in party:
		if p == null or not is_instance_valid(p) or not p.vitals.alive():
			continue
		if caster != null and p.data != caster.data:
			continue
		var d: float = p.sim_position.distance_to(cursor)
		if d > Config.SKILL_GRAB_RADIUS_PX:
			continue
		if caster != null and p.sim_position.distance_to(caster.sim_position) > range_px:
			continue
		if d < best_d:
			best = p
			best_d = d
	return best


## Potion `id` is a healing or buff potion (its throw goes to an ally, ● R42; poison stays aimed at the point).
static func throw_picks_ally(id: StringName) -> bool:
	var effect: int = Potions.effect_of(id)
	return effect == Potions.Effect.HEAL or effect == Potions.Effect.BUFF


## The ally player `p`'s heal or buff would go to now with the mouse at `cursor` (the highlight under that ally), or null: the
## cleric's heal while it is ready, the herbalist's throw while a healing or buff potion is selected.
static func aim_target(p: Player, party: Array[Player], cursor: Vector2) -> Player:
	if not p.vitals.alive():
		return null
	var id: StringName = kit_skill(p.class_id(), Slot.IDENTITY)
	if id == HEAL and built(HEAL) and p.skills.cooldown(Slot.IDENTITY) == 0:
		return pick_ally(party, p, cursor, num_f(HEAL, "range_px"))
	if id == POTION_THROW:
		var s: ItemStack = p.inventory.selected_stack()
		if s != null and throw_picks_ally(s.id):
			return pick_ally(party, p, cursor, Config.THROW_RANGE_PX)
	return null


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
	## The herbalist's throw: the potion, the point it is thrown at (whole px).
	var item: StringName = &""
	var throw_to: Vector2 = Vector2.ZERO

	func ok() -> bool:
		return why.is_empty()


## Player `p` pressed the key of slot `slot` with the mouse at `cursor`; `party` = the players on its map (pick_ally). The
## common refusals, then the skill's own: the heal needs an ally near the cursor (nobody = refused, nothing spent) who is not
## at full HP; the herbalist's throw needs a potion selected (Potions.throw_refusal) and, for a healing or buff potion, an ally
## near the cursor within the throw's range (● R42: it goes to that ally); a poison potion stays aimed at the cursor (M6).
static func prepare(p: Player, slot: int, cursor: Vector2, party: Array[Player]) -> Prepared:
	var r: Prepared = Prepared.new()
	r.slot = slot
	r.id = kit_skill(p.class_id(), slot)
	r.why = refusal(p, slot)
	if not r.ok():
		return r
	match r.id:
		HEAL:
			r.target = pick_ally(party, p, cursor, num_f(HEAL, "range_px"))
			if r.target == null:
				r.why = WHY_NO_ALLY
			elif r.target.vitals.hp >= Config.PLAYER_HP_MAX:
				r.why = WHY_FULL_HP
		POTION_THROW:
			var s: ItemStack = p.inventory.selected_stack()
			r.why = Potions.throw_refusal(p.class_id(), s)
			if not r.ok():
				return r
			r.item = s.id
			var origin: Vector2 = Combat.body_point(p.sim_position)
			if throw_picks_ally(s.id):
				r.target = pick_ally(party, p, cursor, Config.THROW_RANGE_PX)
				if r.target == null:
					r.why = WHY_NO_ALLY
					return r
				r.throw_to = Potions.throw_target(origin, Combat.body_point(r.target.sim_position)).round()
			else:
				r.throw_to = Potions.throw_target(origin, cursor).round()
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

	func ok() -> bool:
		return why.is_empty()


## Skill `id` of player `p` reaches its impact frame (Player.action_impact with the skill id): it works on `arena` (the map's)
## and `party` (the players on that map) and, when it worked, its slot's cooldown starts (Config.SKILLS "cooldown"). The
## taunt forces the heretics around the paladin onto him (Arena.taunt), the piercing arrow lets its shot go along the aim the
## action started with, the heal restores HP to the ally picked when the key was pressed (Player.action_skill_target; gone,
## down or dead now = it fizzles) and grows the cleric's faith, the ground slam hits, staggers and pushes the heretics around
## the miner (Arena.slam). The throw is not here: it lands through Potions.release (its potion), like M6.
static func land(p: Player, id: StringName, arena: Arena, party: Array[Player]) -> Landed:
	var r: Landed = Landed.new()
	r.id = id
	if arena == null:
		r.why = WHY_NO_ARENA
		return r
	match id:
		TAUNT:
			r.taunted = arena.taunt(p, num_f(TAUNT, "radius_px"), num_i(TAUNT, "taunt_ticks"))
		PIERCING_ARROW:
			r.shot = arena.skill_shot(p, PIERCING_ARROW, p.action_aim, num_i(PIERCING_ARROW, "damage"),
				num_f(PIERCING_ARROW, "reach_px"), num_f(PIERCING_ARROW, "speed"), true)
		HEAL:
			var t: Player = null
			for q: Player in party:
				if q != null and is_instance_valid(q) and q.get_instance_id() == p.action_skill_target:
					t = q
			if t == null or not t.vitals.alive() or t.data != p.data:
				r.why = WHY_NO_ALLY
				return r
			r.target = t
			r.healed = t.heal_hp(num_i(HEAL, "heal_hp"))
			p.skills.on_heal_done(p.class_id(), r.healed)
			arena.heal_threat(p.get_instance_id(), t, r.healed, party)
			arena.add_burst(Arena.BurstKind.HEAL, t.sim_position, Config.SKILL_HEAL_SHOW_RADIUS_PX, t.get_instance_id())
		GROUND_SLAM:
			r.hits = arena.slam(p, num_f(GROUND_SLAM, "radius_px"), num_i(GROUND_SLAM, "damage"),
				num_f(GROUND_SLAM, "push_px"))
		_:
			r.why = WHY_NO_SKILL
			return r
	var slot: int = p.action_skill_slot if p.action_skill_slot >= 0 else slot_of(p.class_id(), id)
	p.skills.start_cooldown(slot, cooldown_ticks(id))
	return r
