class_name Potions
extends RefCounted
## M6a: the three potions (● game-concept §12 R28: one per crop, healing / buff / status; the status is poison,
## the first of the herbalist's four in gameplay-design §2.4 ○) and how they work. Pure functions on
## PlayerSim / Vitals / Inventory; the offline game (core/main.gd) calls them on a drink's effect frame and a
## throw's release frame, the arena (combat/arena.gd) on a splash. In a session they stay off until M6b
## (Player.potions_on false, the host refuses a potion's USE as "not a tool").
##
## Drinking: "use" (left click, one drink per click) with a potion selected plays Config.DRINK_ANIM and the
## potion works on Config.DRINK_EFFECT_FRAME: healing restores Config.POTION_HEAL_HP (not past the maximum;
## refused at full HP while Config.DRINK_AT_FULL_HP is false), the buff potion raises walking speed
## (Config.BUFF_SPEED_PCT for Config.BUFF_TICKS), the poison potion poisons the drinker
## (Config.DRINK_POISON_HARMS; else refused). Nothing works while down or dead (no action starts then).
## Throwing: the herbalist's skill (Config.THROW_HERBALIST_ONLY; ○ gameplay-design §2.2 identity skill "약제
## 투척") throws the selected potion toward the mouse (base_body_v02_throw); it leaves the hand on
## Config.THROW_RELEASE_FRAME and splashes where it lands (Arena.throw_potion): healing heals and the buff
## buffs the players in the splash, poison poisons the heretics (players only with Config.FRIENDLY_FIRE).
## Values by grade (COMMON / FINE: the herbs' grade, ● gameplay-design §3.4) are PROVISIONAL rows of Config.

enum Effect { HEAL, BUFF, POISON }

const EFFECT_NAMES: PackedStringArray = ["heal", "buff", "poison"]
## Why a drink or a throw was refused (logs and tests count these).
const WHY_NOT_POTION: String = "not a potion"
const WHY_FULL_HP: String = "full hp"
const WHY_NOT_DRINKABLE: String = "not for drinking"
const WHY_NOT_UP: String = "not up"
const WHY_HERBALIST: String = "herbalist only"
const WHY_GONE: String = "the potion is gone"
## The class that throws (Config.THROW_HERBALIST_ONLY) and brews FINE and status potions (● §3.0).
const HERB_CLASS: String = "herbalist"


static func is_potion(id: StringName) -> bool:
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	return def != null and def.is_potion()


## The potion's effect (Effect), -1 for anything else.
static func effect_of(id: StringName) -> int:
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	return def.effect if def != null and def.is_potion() else -1


static func _g(grade: int) -> int:
	return clampi(grade, ItemDB.Grade.NONE, ItemDB.Grade.FINE)


static func heal_hp(grade: int) -> int:
	return Config.POTION_HEAL_HP[_g(grade)]


static func buff_pct(grade: int) -> int:
	return Config.BUFF_SPEED_PCT[_g(grade)]


static func buff_ticks(grade: int) -> int:
	return Config.BUFF_TICKS[_g(grade)]


static func poison_damage(grade: int) -> int:
	return Config.POISON_DAMAGE[_g(grade)]


static func poison_ticks(grade: int) -> int:
	return Config.POISON_TICKS[_g(grade)]


## The tick of body action `anim` a potion works on: the drink's effect frame, the throw's release frame.
static func impact_tick(anim: int) -> int:
	if anim == RigData.Anim.THROW:
		return Config.THROW_RELEASE_FRAME * Config.ACTION_FRAME_TICKS
	return Config.DRINK_EFFECT_FRAME * Config.ACTION_FRAME_TICKS


## Why drinking potion `id` at `grade` with vitals `vit` is refused now ("" = it may be drunk).
static func drink_refusal(id: StringName, _grade: int, vit: Vitals) -> String:
	var effect: int = effect_of(id)
	if effect < 0:
		return WHY_NOT_POTION
	if not vit.alive():
		return WHY_NOT_UP
	if effect == Effect.HEAL and vit.hp >= Config.PLAYER_HP_MAX and not Config.DRINK_AT_FULL_HP:
		return WHY_FULL_HP
	if effect == Effect.POISON and not Config.DRINK_POISON_HARMS:
		return WHY_NOT_DRINKABLE
	return ""


## Potion `id` at `grade` works on `sim` (drunk, or splashed on it): heal, buff or poison. Returns the
## PlayerSim event bits of what it did (PlayerSim.HEALED / BUFFED / POISONED; 0 = nothing, e.g. not up).
static func apply(sim: PlayerSim, id: StringName, grade: int) -> int:
	match effect_of(id):
		Effect.HEAL:
			return PlayerSim.HEALED if sim.heal(heal_hp(grade)) > 0 else 0
		Effect.BUFF:
			return PlayerSim.BUFFED if sim.add_buff(buff_pct(grade), buff_ticks(grade)) else 0
		Effect.POISON:
			return PlayerSim.POISONED if sim.add_poison(poison_damage(grade), poison_ticks(grade)) else 0
	return 0


## Why a player of `class_id` may not throw the stack `stack` ("" = it may).
static func throw_refusal(class_id: String, stack: ItemStack) -> String:
	if stack == null or not is_potion(stack.id):
		return WHY_NOT_POTION
	if Config.THROW_HERBALIST_ONLY and class_id != HERB_CLASS:
		return WHY_HERBALIST
	return ""


## Where a bottle thrown from ground point `origin` toward `mouse` lands at most (Config.THROW_RANGE_PX;
## walls may stop it sooner, Arena).
static func throw_target(origin: Vector2, mouse: Vector2) -> Vector2:
	var d: Vector2 = mouse - origin
	if d.length() > Config.THROW_RANGE_PX:
		d = d.normalized() * Config.THROW_RANGE_PX
	return origin + d


## Takes one potion `id` at `grade` out of `inv`: from `slot` when it still holds that, else from the first
## stack of it. False when there is none left (it was dropped or moved away meanwhile).
static func take_one(inv: Inventory, slot: int, id: StringName, grade: int) -> bool:
	var s: ItemStack = inv.stack_at(slot)
	if s != null and s.same_kind(id, grade):
		return inv.remove(slot, 1) == 1
	for i: int in inv.size():
		var t: ItemStack = inv.stack_at(i)
		if t != null and t.same_kind(id, grade):
			return inv.remove(i, 1) == 1
	return false
