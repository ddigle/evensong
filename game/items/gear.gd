class_name Gear
extends RefCounted
## M7a: tier-1 gear and durability (● gameplay-design §3.5 / §3.0 R11 "1티어는 누구나 모루에서", ● §2.6 R12 "장착 장비는
## 유지하되 내구도 손상"; every number and the rules below are PROVISIONAL, README "임시값" M7a). Pure functions on items,
## stacks and inventories, like items/crafting.gd, so offline Main and (M7c) the host share them.
##
## Tier-1 weapons (Config.GEAR_T1_BASE): each is a basic weapon made better. base() names the basic item it stands for:
## combat (Combat.attack_for, the hit frame), mining (the tier-1 pickaxe mines as the pickaxe does: mining power
## unchanged), harvesting (the tier-1 sickle harvests as the sickle) and the picture (the base weapon's action; ● R21: no
## new looks) all read the base. What differs: attack_damage() (Config.GEAR_T1_DAMAGE_PCT while not broken) and durability.
## Armour (one piece, armor_t1): worn in the inventory's armour slot (Inventory.armor), put on with a click while it is
## selected (equip_refusal / equip); while worn and not broken it takes Config.ARMOR_T1_DEFENCE off every heretic knife
## hit (after_armor), never below Config.ARMOR_MIN_DAMAGE.
## Durability (ItemStack.durability; only the tier-1 gear has it, Config.GEAR_DURABILITY): a weapon loses
## Config.GEAR_WEAR_PER_ATTACK on each attack it lands (wear_weapon: offline Main on the hit frame), the worn armour
## Config.GEAR_WEAR_PER_HIT on each knife hit it takes (Player.take_hit), every such item the player carries
## Config.GEAR_DEATH_WEAR_PCT of its full durability on death (wear_on_death). At 0 it is broken: it works as its base item
## (Config.GEAR_BROKEN_UNUSABLE off) or not at all (on). Repair: an anvil recipe per item (Crafting, Config.GEAR_REPAIR_MATERIAL).

const WHY_NOT_ARMOR: String = "not armour"
const WHY_EMPTY: String = "empty slot"
const WHY_NO_ARMOR: String = "no armour worn"
const WHY_FULL: String = "inventory full"
const WHY_BROKEN: String = "broken"
## M7a: a session refuses wearing armour until M7c (as M5a / M6a refused their new things).
const WHY_OFFLINE: String = "gear offline only"


## The basic item `item` stands for (a tier-1 weapon's base weapon; any other item itself).
static func base(item: StringName) -> StringName:
	var def: ItemDB.ItemDef = ItemDB.get_def(item)
	return def.base if def != null and not def.base.is_empty() else item


## The item's tier (0 = the basic items; the tier-1 gear 1).
static func tier(item: StringName) -> int:
	var def: ItemDB.ItemDef = ItemDB.get_def(item)
	return def.tier if def != null else 0


## Whether `item` has durability (its full value; 0 = none).
static func max_durability(item: StringName) -> int:
	var def: ItemDB.ItemDef = ItemDB.get_def(item)
	return def.durability if def != null else 0


static func is_armor(item: StringName) -> bool:
	var def: ItemDB.ItemDef = ItemDB.get_def(item)
	return def != null and def.is_armor()


## The damage an attack with `stack` (its item's base attack does `base_damage`) lands: a tier-1 weapon's
## Config.GEAR_T1_DAMAGE_PCT of it while not broken (rounded down), else `base_damage`.
static func attack_damage(stack: ItemStack, base_damage: int) -> int:
	if stack == null or tier(stack.id) < 1 or stack.broken():
		return base_damage
	return base_damage * Config.GEAR_T1_DAMAGE_PCT / 100


## The defence of the armour `inv` wears (0 without, or when it is broken).
static func defence(inv: Inventory) -> int:
	if inv == null or inv.armor == null or inv.armor.broken():
		return 0
	return Config.ARMOR_T1_DEFENCE


## A heretic's hit of `amount` on a player wearing `inv`'s armour: less the defence, never below Config.ARMOR_MIN_DAMAGE
## (an unarmoured hit is unchanged).
static func after_armor(amount: int, inv: Inventory) -> int:
	var d: int = defence(inv)
	if d <= 0:
		return amount
	return maxi(amount - d, mini(Config.ARMOR_MIN_DAMAGE, amount))


## Takes `points` of durability off `stack` (none below 0; items without durability are untouched). Returns whether it
## broke now.
static func wear(stack: ItemStack, points: int) -> bool:
	if stack == null or stack.max_durability() <= 0 or points <= 0 or stack.durability <= 0:
		return false
	stack.durability = maxi(stack.durability - points, 0)
	return stack.durability == 0


## A weapon's use wear: the stack in `slot` of `inv` (if it still holds `item`) loses Config.GEAR_WEAR_PER_ATTACK. Returns
## the stack worn (null = nothing wore: no durability, or the item left the slot).
static func wear_weapon(inv: Inventory, slot: int, item: StringName) -> ItemStack:
	var s: ItemStack = inv.stack_at(slot)
	if s == null or s.id != item or s.max_durability() <= 0:
		return null
	wear(s, Config.GEAR_WEAR_PER_ATTACK)
	inv.changed.emit()
	return s


## The worn armour's wear for a hit it took (Config.GEAR_WEAR_PER_HIT). Returns whether it wore.
static func wear_armor(inv: Inventory) -> bool:
	if inv == null or inv.armor == null or inv.armor.max_durability() <= 0 or inv.armor.durability <= 0:
		return false
	wear(inv.armor, Config.GEAR_WEAR_PER_HIT)
	inv.changed.emit()
	return true


## The death wear (● §2.6): every item with durability `inv` holds (the worn armour too) loses Config.GEAR_DEATH_WEAR_PCT
## of its full durability (rounded up) and stays where it is. Returns how many items wore.
static func wear_on_death(inv: Inventory) -> int:
	var n: int = 0
	var all: Array[ItemStack] = []
	all.append_array(inv.slots)
	all.append(inv.armor)
	for s: ItemStack in all:
		if s == null or s.max_durability() <= 0 or s.durability <= 0:
			continue
		wear(s, death_wear_points(s.id))
		n += 1
	if n > 0:
		inv.changed.emit()
	return n


## The points one death takes off item `item` (Config.GEAR_DEATH_WEAR_PCT of its full durability, rounded up).
static func death_wear_points(item: StringName) -> int:
	return ceili(float(max_durability(item) * Config.GEAR_DEATH_WEAR_PCT) / 100.0)


## Whether `stack` may not be used now (broken while Config.GEAR_BROKEN_UNUSABLE).
static func unusable(stack: ItemStack) -> bool:
	return Config.GEAR_BROKEN_UNUSABLE and stack != null and stack.broken()


## Why hotbar slot `slot` of `inv` cannot be put on ("" = it can): armour, in the hotbar.
static func equip_refusal(inv: Inventory, slot: int) -> String:
	var s: ItemStack = inv.stack_at(slot)
	if slot < 0 or slot >= inv.hotbar_size or s == null:
		return WHY_EMPTY
	if not is_armor(s.id):
		return WHY_NOT_ARMOR
	return ""


## Puts on the armour in `slot` (the piece worn before, if any, takes its place in that slot). Returns why not ("" = done).
static func equip(inv: Inventory, slot: int) -> String:
	var why: String = equip_refusal(inv, slot)
	if not why.is_empty():
		return why
	var s: ItemStack = inv.stack_at(slot)
	inv.slots[slot] = inv.armor  # the old piece (or nothing) where the new one was
	inv.wear(s)
	return ""


## Takes the worn armour off into the first empty slot. Returns why not ("" = done).
static func unequip(inv: Inventory) -> String:
	if inv.armor == null:
		return WHY_NO_ARMOR
	var to: int = inv.slots.find(null)
	if to < 0:
		return WHY_FULL
	inv.slots[to] = inv.armor
	inv.wear(null)
	return ""


## The most worn stack of `item` in `inv` (the worn armour included; the lowest durability, then the first slot), or
## null when none of it is worn. Repair restores it.
static func most_worn(inv: Inventory, item: StringName) -> ItemStack:
	var best: ItemStack = null
	var all: Array[ItemStack] = []
	all.append_array(inv.slots)
	all.append(inv.armor)
	for s: ItemStack in all:
		if s != null and s.id == item and s.worn() and (best == null or s.durability < best.durability):
			best = s
	return best


## One line for logs: "<item> <left>/<full>".
static func describe(stack: ItemStack) -> String:
	if stack == null:
		return "none"
	return "%s %d/%d" % [stack.id, stack.durability, stack.max_durability()]
