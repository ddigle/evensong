extends "res://tests/base_test.gd"
## M7a, tier-1 gear and durability (offline first; ● gameplay-design §3.5 / §3.0 R11 tier 1 anyone's at the anvil, ● §2.6
## R12 death = durability damage + some items dropped; the numbers and rules PROVISIONAL, README "임시값" M7a): the tier-1
## weapon of every class (its base's attack shape, Config.GEAR_T1_DAMAGE_PCT of its damage, written out here), the tier-1
## pickaxe mining exactly as the pickaxe (the same world after the same swings) and the tier-1 sickle harvesting, the
## armour (equip / swap / take off for all five classes, its defence on a heretic's knife, poison untouched), durability
## (use wear per attack, none for mining, armour wear per landed hit, the death wear of everything carried with the bag
## rule unchanged, broken = base stats, repair at the anvil restores the most worn, the debug drop keeps worn gear),
## main.tscn (an attack lands tier-1 damage and wears the weapon, a click puts armour on, the armour slot takes it off, a
## death wears the gear), a session (no tier-1 damage, no wear, no armour until M7c) and determinism.

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0

## Written out: class -> [basic weapon, tier-1 weapon, basic damage, tier-1 damage].
const CLASS_GEAR: Dictionary[String, Array] = {
	"paladin": [&"sword", &"sword_t1", 14, 21],
	"archer": [&"bow", &"bow_t1", 12, 18],
	"cleric": [&"holy_light", &"holy_light_t1", 10, 15],
	"miner": [&"pickaxe", &"pickaxe_t1", 10, 15],
	"herbalist": [&"sickle", &"sickle_t1", 8, 12],
}

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_tables()
	_check_damage()
	_check_mining_and_harvest()
	_check_equip()
	_check_defence()
	_check_wear()
	_check_death_wear()
	_check_repair()
	_check_broken()
	await _check_main()
	await _check_main_mining()
	_check_session()
	_check_determinism()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


static func open_world(size: Vector2i = Vector2i(40, 20)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_DUNGEON
	return d


func _check_tables() -> void:
	for c: String in CLASS_GEAR:
		var g: Array = CLASS_GEAR[c]
		var basic: StringName = g[0]
		var t1: StringName = g[1]
		var bd: int = g[2]
		var td: int = g[3]
		check_eq(Combat.class_weapon(c), basic, "%s's basic weapon" % c)
		check_eq(Gear.base(t1), basic, "%s's tier-1 weapon stands for its basic one" % c)
		check_eq(Gear.tier(t1), 1, "%s tier 1" % t1)
		check_eq(Gear.tier(basic), 0, "%s tier 0" % basic)
		check(Combat.attack_for(t1) == Combat.attack_for(basic), "%s attacks with its base's attack (shape, frame)" % t1)
		check_eq(Combat.impact_tick(t1), Combat.impact_tick(basic), "%s lands on its base's frame" % t1)
		check_eq(Player.impact_tick_of(t1, ItemDB.get_def(t1).action), Player.impact_tick_of(basic, ItemDB.get_def(basic).action),
			"%s: the player's impact tick too" % t1)
		check_eq(Combat.attack_for(basic).damage, bd, "%s basic damage %d" % [basic, bd])
		check_eq(Gear.attack_damage(ItemStack.new(t1, 1, 0), bd), td, "%s tier-1 damage %d (150%%)" % [t1, td])
		check_eq(Gear.attack_damage(ItemStack.new(basic, 1, 0), bd), bd, "%s keeps its damage" % basic)
		check_eq(Gear.max_durability(t1), 120, "%s 120 durability" % t1)
		check_eq(Gear.max_durability(basic), 0, "%s has no durability (the basic kit never wears)" % basic)
		check(Crafting.recipe(StringName("repair_%s" % t1)) != null, "%s can be repaired" % t1)
	check_eq(Gear.max_durability(&"armor_t1"), 100, "the armour 100")
	check(Gear.is_armor(&"armor_t1") and not Gear.is_armor(&"sword_t1"), "armour is armour")
	for id: StringName in [&"pickaxe", &"hoe", &"watering_can", &"torch", &"stone_a", &"potion_healing"]:
		check_eq(Gear.max_durability(id), 0, "%s has no durability" % id)
	check_eq(Gear.death_wear_points(&"sword_t1"), 24, "a death takes 20% of 120 = 24")
	check_eq(Gear.death_wear_points(&"armor_t1"), 20, "and 20 of the armour's 100")


## Each class with its tier-1 weapon in an arena: the heretic loses the tier-1 damage (melee at once, shots when they
## land); with the basic weapon the basic damage; the arena's own damage when none is passed (a session).
func _check_damage() -> void:
	for c: String in CLASS_GEAR:
		var g: Array = CLASS_GEAR[c]
		var want_basic: int = g[2]
		var want_t1: int = g[3]
		for k: int in 2:
			var t1_id: StringName = g[1]
			var basic_id: StringName = g[0]
			var item: StringName = t1_id if k == 1 else basic_id
			var d: WorldData = open_world()
			var arena: Arena = Arena.new()
			arena.setup(d, 1)
			arena.spawning = false
			var p: Player = player(d, c, Arena.spawn_feet(Vector2i(5, 10)))
			p.gear_on = true
			p.inventory.add(item, 1)
			var h: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(14, 0))
			var dmg: int = Gear.attack_damage(p.inventory.stack_at(0), Combat.attack_for(item).damage)
			arena.player_attack(p, item, Combat.aim_code(Vector2.RIGHT), [], 255, dmg)
			var none: Array[Player] = []
			for t: int in 40:
				if h.hp < Config.HERETIC_HP:
					break
				arena.step(none)
			var want: int = want_t1 if k == 1 else want_basic
			check_eq(Config.HERETIC_HP - h.hp, want, "%s with %s: %d damage" % [c, item, want])
	# No damage passed (the host in a session): the base damage.
	var d2: WorldData = open_world()
	var a2: Arena = Arena.new()
	a2.setup(d2, 1)
	a2.spawning = false
	var p2: Player = player(d2, "paladin", Arena.spawn_feet(Vector2i(5, 10)))
	var h2: HereticSim = a2.spawn_heretic(p2.sim_position + Vector2(14, 0))
	a2.player_attack(p2, &"sword_t1", Combat.aim_code(Vector2.RIGHT))
	check_eq(Config.HERETIC_HP - h2.hp, 14, "no damage passed: the base sword's 14")


## The tier-1 pickaxe is the pickaxe for mining (the same swing rule and frame), the tier-1 sickle the sickle for
## harvesting.
func _check_mining_and_harvest() -> void:
	var d: WorldData = open_world()
	d.set_value(WorldData.Layer.WALL, Vector2i(10, 5), Walls.pack(Walls.KIND_ROCK, 0))
	check(Combat.is_mining_swing(d, &"pickaxe_t1", Vector2i(10, 5)), "the tier-1 pickaxe at a wall: mining")
	check(not Combat.is_mining_swing(d, &"pickaxe_t1", Vector2i(12, 5)), "at open floor: an attack")
	check(not Combat.is_mining_swing(d, &"sword_t1", Vector2i(10, 5)), "a tier-1 sword never mines")
	check_eq(Combat.impact_tick(&"pickaxe_t1"), Mining.impact_tick(), "the mining frame")
	var farm: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var c: Vector2i = Vector2i(58, 49)
	farm.set_value(WorldData.Layer.FLOOR, c, Terrain.SOIL)
	farm.set_value(WorldData.Layer.VEGETATION, c, Farming.Field.new(Farming.KIND_HEALING, Farming.RIPE_STAGE).value())
	check(Farming.is_harvest_swing(farm, &"sickle_t1", c), "the tier-1 sickle at a crop: a harvest")
	check(not Farming.is_harvest_swing(farm, &"sword_t1", c), "a sword at a crop: no harvest")
	check(not Farming.is_harvest_swing(farm, &"sickle_t1", c + Vector2i(5, 5)), "the tier-1 sickle at grass: an attack")


## Equip rules (all five classes): armour selected in the hotbar goes on (its slot empties), a second piece swaps with
## the worn one, not armour / empty / outside the hotbar refused, take off into the first free slot, refused when full or
## nothing is worn.
func _check_equip() -> void:
	for c: String in Config.CLASSES:
		var inv: Inventory = Inventory.new()
		inv.add(&"armor_t1", 1)
		inv.add(&"sword_t1", 1)
		check_eq(Gear.equip(inv, 1), Gear.WHY_NOT_ARMOR, "%s: a sword is not armour" % c)
		check_eq(Gear.equip(inv, 5), Gear.WHY_EMPTY, "%s: an empty slot" % c)
		check_eq(Gear.equip(inv, 0), "", "%s puts the armour on" % c)
		check(inv.armor != null and inv.armor.id == &"armor_t1" and inv.stack_at(0) == null, "%s: worn, its slot empty" % c)
		inv.add(&"armor_t1", 1)
		inv.armor.durability = 40
		var second: int = 0
		for i: int in inv.hotbar_size:
			if inv.stack_at(i) != null and inv.stack_at(i).id == &"armor_t1":
				second = i
		check_eq(Gear.equip(inv, second), "", "%s: a second piece" % c)
		check(inv.armor.durability == 100 and inv.stack_at(second).durability == 40, "%s: swapped (the worn one in its slot)" % c)
		check_eq(Gear.unequip(inv), "", "%s takes it off" % c)
		check(inv.armor == null and inv.count_of(&"armor_t1") == 2, "%s: back in the inventory" % c)
		check_eq(Gear.unequip(inv), Gear.WHY_NO_ARMOR, "%s: nothing worn" % c)
		var bag: Inventory = Inventory.new()
		for i2: int in bag.size():
			bag.add(&"stone_a", 99)
		bag.slots[bag.hotbar_size + 2] = ItemStack.new(&"armor_t1", 1, 0)
		check_eq(Gear.equip(bag, bag.hotbar_size + 2), Gear.WHY_EMPTY, "%s: only from the hotbar" % c)
		bag.slots[0] = ItemStack.new(&"armor_t1", 1, 0)
		check_eq(Gear.equip(bag, 0), "", "%s: from the hotbar" % c)
		bag.slots[0] = ItemStack.new(&"stone_a", 1, 0)
		check_eq(Gear.unequip(bag), Gear.WHY_FULL, "%s: full inventory, stays on" % c)
		check(bag.armor != null, "%s: still worn" % c)
		check(Gear.equip_refusal(bag, 0) == Gear.WHY_NOT_ARMOR, "%s: a stone is not armour" % c)


## The armour on a heretic's knife (Player.take_hit with `armored`): every class takes 12 - 4 = 8 and it wears 1; without
## armour 12; broken armour 12 and no wear; a hit that does not land (invulnerable) no wear; gear_on off (a session) 12.
## In an arena: the knife lands 8 on the armoured player. Poison is not lessened.
func _check_defence() -> void:
	for c: String in Config.CLASSES:
		var d: WorldData = open_world()
		var p: Player = player(d, c, Arena.spawn_feet(Vector2i(5, 10)))
		p.gear_on = true
		p.take_hit(Config.HERETIC_DAMAGE, true)
		check_eq(p.vitals.hp, 100 - 12, "%s without armour: 12" % c)
		var q: Player = player(d, c, Arena.spawn_feet(Vector2i(7, 10)))
		q.gear_on = true
		q.inventory.wear(ItemStack.new(&"armor_t1", 1, 0))
		q.take_hit(Config.HERETIC_DAMAGE, true)
		check_eq(q.vitals.hp, 100 - 8, "%s with armour: 8" % c)
		check_eq(q.inventory.armor.durability, 99, "%s: the armour wore 1" % c)
		q.take_hit(Config.HERETIC_DAMAGE, true)
		check_eq([q.vitals.hp, q.inventory.armor.durability], [92, 99], "%s: an invulnerable moment takes nothing and wears nothing" % c)
		var b: Player = player(d, c, Arena.spawn_feet(Vector2i(9, 10)))
		b.gear_on = true
		b.inventory.wear(ItemStack.new(&"armor_t1", 1, 0, 0))
		b.take_hit(Config.HERETIC_DAMAGE, true)
		check_eq([b.vitals.hp, b.inventory.armor.durability], [88, 0], "%s: broken armour takes nothing off and stays at 0" % c)
		var s: Player = player(d, c, Arena.spawn_feet(Vector2i(11, 10)))
		s.inventory.wear(ItemStack.new(&"armor_t1", 1, 0))
		s.take_hit(Config.HERETIC_DAMAGE, true)
		check_eq([s.vitals.hp, s.inventory.armor.durability], [88, 100], "%s: gear off (a session): 12, no wear" % c)
	check_eq(Gear.after_armor(3, null), 3, "no inventory: unchanged")
	var inv: Inventory = Inventory.new()
	inv.wear(ItemStack.new(&"armor_t1", 1, 0))
	check_eq(Gear.after_armor(3, inv), Config.ARMOR_MIN_DAMAGE, "never below ARMOR_MIN_DAMAGE")
	check_eq(Gear.after_armor(0, inv), 0, "nothing stays nothing")
	# The arena: a heretic next to an armoured player outside any light lands its knife for 8.
	var d2: WorldData = open_world()
	var arena: Arena = Arena.new()
	arena.setup(d2, 1)
	arena.spawning = false
	var me: Player = player(d2, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	me.gear_on = true
	me.inventory.wear(ItemStack.new(&"armor_t1", 1, 0))
	arena.spawn_heretic(me.sim_position + Vector2(14, 0))
	var players: Array[Player] = [me]
	for t: int in 120:
		me.begin_tick()
		me.step_frame(NetProtocol.InputFrame.new(), TICK)
		arena.step(players)
		if me.vitals.hp < 100:
			break
	check_eq(me.vitals.hp, 92, "the heretic's knife on an armoured paladin: 8")
	check_eq(me.inventory.armor.durability, 99, "the armour wore 1")
	# Poison: not lessened (M6a: poison ignores defence).
	var pz: Player = player(d2, "cleric", Arena.spawn_feet(Vector2i(20, 10)))
	pz.gear_on = true
	pz.inventory.wear(ItemStack.new(&"armor_t1", 1, 0))
	pz.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	for t2: int in Config.POISON_INTERVAL_TICKS:
		pz.step_frame(NetProtocol.InputFrame.new(), TICK)
	check_eq(pz.vitals.hp, 100 - Config.POISON_DAMAGE[ItemDB.Grade.COMMON], "poison through armour: whole")
	check_eq(pz.inventory.armor.durability, 100, "poison does not wear the armour")


## Use wear (Gear.wear_weapon): one point per attack, not below 0; items without durability untouched; another item in
## the slot untouched.
func _check_wear() -> void:
	var inv: Inventory = Inventory.new()
	inv.add(&"sword_t1", 1)
	inv.add(&"sword", 1)
	for i: int in 5:
		Gear.wear_weapon(inv, 0, &"sword_t1")
	check_eq(inv.stack_at(0).durability, 115, "five attacks: 115")
	check(Gear.wear_weapon(inv, 1, &"sword") == null and inv.stack_at(1).durability == 0, "the basic sword never wears")
	check(Gear.wear_weapon(inv, 0, &"bow_t1") == null, "another item than the one that swung: nothing")
	inv.stack_at(0).durability = 1
	check(Gear.wear(inv.stack_at(0), 1), "the last point: it broke")
	check(not Gear.wear(inv.stack_at(0), 1) and inv.stack_at(0).durability == 0, "broken stays at 0")
	check(inv.stack_at(0).broken() and inv.stack_at(0).worn(), "broken and worn")
	var full: ItemStack = ItemStack.new(&"bow_t1", 1, 0)
	check(not full.worn() and not full.broken() and full.durability == 120, "a new bow: full")
	check_eq(full.copy().durability, 120, "a copy keeps it")
	var half: ItemStack = ItemStack.new(&"bow_t1", 1, 0, 60)
	check_eq(half.copy().durability, 60, "a copy of a worn one keeps it")
	check_eq(ItemStack.new(&"bow_t1", 1, 0, 999).durability, 120, "never above full")


## The death wear (● §2.6 "장착 장비는 유지하되 내구도 손상"): every item with durability carried, the worn armour included,
## loses 20% of its full durability (rounded up) and stays; the basic kit untouched; the bag takes no gear.
func _check_death_wear() -> void:
	var inv: Inventory = Inventory.new()
	inv.add(&"sword_t1", 1)
	inv.add(&"bow_t1", 1)
	inv.stack_at(1).durability = 10
	inv.add(&"sword", 1)
	inv.add(&"stone_a", 10)
	inv.slots[inv.hotbar_size + 1] = ItemStack.new(&"armor_t1", 1, 0, 60)  # a spare in the bag
	inv.wear(ItemStack.new(&"armor_t1", 1, 0))
	inv.add(&"pickaxe_t1", 1)
	inv.stack_at(4).durability = 0
	check_eq(Gear.wear_on_death(inv), 4, "four items wore (the broken pickaxe not)")
	check_eq(inv.stack_at(0).durability, 96, "sword 120 -> 96")
	check_eq(inv.stack_at(1).durability, 0, "bow 10 -> 0 (not below)")
	check_eq(inv.armor.durability, 80, "the worn armour 100 -> 80")
	check_eq(inv.stack_at(inv.hotbar_size + 1).durability, 40, "the spare armour 60 -> 40")
	check_eq(inv.stack_at(4).durability, 0, "the broken pickaxe stays at 0")
	check_eq(inv.count_of(&"sword"), 1, "the basic sword untouched")
	var want: Dictionary[int, int] = WorldItems.death_drop_counts(inv, Config.DEATH_DROP_HALF, 0)
	for slot: int in want:
		var st: ItemStack = inv.stack_at(slot)
		check(not st.def().is_tool() and not st.def().is_armor(), "the bag takes %s (no gear)" % st.id)
	check(want.has(3) and want[3] == 5, "the stones: half (the M4a rule unchanged)")
	check(not want.has(inv.hotbar_size + 1), "the spare armour stays (gear)")


## Repair at the anvil: one material gives the most worn one of the item (the worn armour included) its full durability;
## nothing worn = refused, nothing changes; missing material = refused; never seen = locked; the panel shows a repair row
## only while something is worn. M7-fix: all of it only with Gear.repair_on (Config.GEAR_REPAIR_AT_ANVIL, off: ● §2.6 R12
## repair is the engineer's work): off, no repair row ever shows and a repair is refused with nothing changed.
func _check_repair() -> void:
	var r: Crafting.Recipe = Crafting.recipe(&"repair_sword_t1")
	check_eq(Gear.repair_on, Config.GEAR_REPAIR_AT_ANVIL, "the repair switch starts as Config has it")
	check(not Config.GEAR_REPAIR_AT_ANVIL, "Config: nobody repairs in the slice (the engineer's work, ● §2.6 R12; README \"M7-fix 수리\")")
	var off: Inventory = Inventory.new()
	off.add(&"sword_t1", 1)
	off.add(&"ingot_iron", 3)
	off.stack_at(0).durability = 30
	Gear.repair_on = false
	var off_before: String = off.describe()
	check(not Crafting.shown_recipes(Crafting.ANVIL, off).has(r), "switch off: a worn sword shows no repair row")
	check_eq(Crafting.craft(r, "cleric", off).why, Crafting.WHY_NO_REPAIR, "switch off: the repair is refused (the engineer's work)")
	check_eq(off.describe(), off_before, "nothing changed")
	Gear.repair_on = true  # the rule itself, as M7a made it (put back below)
	_check_repair_on(r)
	Gear.repair_on = Config.GEAR_REPAIR_AT_ANVIL


func _check_repair_on(r: Crafting.Recipe) -> void:
	check(r != null and r.is_repair() and r.station == Crafting.ANVIL and r.repair == &"sword_t1", "the sword's repair at the anvil")
	check_eq(r.inputs[0].item, &"ingot_iron", "one iron ingot")
	check_eq(r.inputs[0].count, 1, "just one")
	for item: StringName in Config.GEAR_REPAIR_MATERIAL:
		var rr: Crafting.Recipe = Crafting.recipe(StringName("repair_%s" % item))
		var mat: StringName = Config.GEAR_REPAIR_MATERIAL[item]
		check(rr != null and rr.inputs[0].item == mat, "%s repairs with %s" % [item, mat])
	var inv: Inventory = Inventory.new()
	inv.add(&"sword_t1", 1)
	inv.add(&"sword_t1", 1)
	inv.add(&"ingot_iron", 3)
	inv.stack_at(0).durability = 60
	inv.stack_at(1).durability = 30
	check(Crafting.shown_recipes(Crafting.ANVIL, inv).has(r), "worn swords: the repair row shows")
	var o: Crafting.Outcome = Crafting.craft(r, "cleric", inv)
	check(o.ok(), "repaired (%s)" % o.why)
	check_eq([inv.stack_at(0).durability, inv.stack_at(1).durability], [60, 120], "the most worn one is full again")
	check_eq(inv.count_of(&"ingot_iron"), 2, "one ingot used")
	check(Crafting.craft(r, "cleric", inv).ok() and inv.stack_at(0).durability == 120, "the other one")
	check(not Crafting.shown_recipes(Crafting.ANVIL, inv).has(r), "nothing worn: no repair row")
	var before: String = inv.describe()
	check_eq(Crafting.craft(r, "cleric", inv).why, Crafting.WHY_NOTHING_TO_REPAIR, "nothing to repair")
	check_eq(inv.describe(), before, "nothing changed")
	inv.stack_at(0).durability = 5
	inv.remove(2, 1)
	check_eq(inv.count_of(&"ingot_iron"), 0, "out of ingots")
	check_eq(Crafting.craft(r, "cleric", inv).why, Crafting.WHY_MISSING, "no ingot: missing inputs")
	check_eq(inv.stack_at(0).durability, 5, "still worn")
	var armor: Inventory = Inventory.new()
	armor.add(&"ingot_iron", 1)
	armor.wear(ItemStack.new(&"armor_t1", 1, 0, 0))
	check(Crafting.craft(Crafting.recipe(&"repair_armor_t1"), "miner", armor).ok() and armor.armor.durability == 100,
		"the worn (broken) armour repaired")
	var fresh: Inventory = Crafting.copy_of(armor)
	fresh.seen.clear()
	fresh.add(&"ingot_iron", 1)
	fresh.armor.durability = 3
	if Config.RECIPES_UNLOCK_ON_FIRST_GET:
		check_eq(Crafting.craft(Crafting.recipe(&"repair_armor_t1"), "miner", fresh).why, Crafting.WHY_LOCKED,
			"never had the armour itself (only worn by a copy): locked")


## Broken = base stats (Config.GEAR_BROKEN_UNUSABLE off): a broken tier-1 sword hits like the basic sword and still
## plays its action; broken armour has no defence; the debug drop keeps worn gear (a drop keeps no durability).
func _check_broken() -> void:
	var broken: ItemStack = ItemStack.new(&"sword_t1", 1, 0, 0)
	check_eq(Gear.attack_damage(broken, 14), 14, "a broken sword_t1: the basic 14")
	check_eq(Gear.unusable(broken), Config.GEAR_BROKEN_UNUSABLE, "usable while GEAR_BROKEN_UNUSABLE is off")
	var inv: Inventory = Inventory.new()
	inv.slots[0] = broken
	check_eq(WorldItems.use_action(Arena.spawn_feet(Vector2i(5, 5)), inv, 0, Vector2i(6, 5)), RigData.Anim.SWORD,
		"a broken sword still swings")
	var worn: Inventory = Inventory.new()
	worn.wear(ItemStack.new(&"armor_t1", 1, 0, 0))
	check_eq(Gear.defence(worn), 0, "broken armour: no defence")
	worn.armor.durability = 1
	check_eq(Gear.defence(worn), Config.ARMOR_T1_DEFENCE, "one point left: the full defence")
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var feet: Vector2 = Arena.spawn_feet(Vector2i(63, 53))
	var dropper: Inventory = Inventory.new()
	dropper.add(&"bow_t1", 1)
	dropper.add(&"bow_t1", 1)
	dropper.stack_at(0).durability = 50
	check_eq(WorldItems.drop(d, feet, dropper, 0, 0, Vector2i(64, 53)).why, WorldItems.WHY_WORN, "a worn bow is not dropped")
	check(WorldItems.drop(d, feet, dropper, 1, 0, Vector2i(64, 53)).ok(), "a full one is")


## main.tscn offline: each class's tier-1 weapon held lands its tier-1 damage on a heretic and wears 1 per attack (a
## swing at nothing wears too); a click with armour selected puts it on; the armour slot click takes it off; a death
## wears everything and the bag holds no gear.
func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	for c: String in CLASS_GEAR:
		main.spawn(c)
		var p: Player = main.player
		if not check(p != null and p.gear_on, "%s: an offline player with gear on" % c):
			return
		p.local_input = false
		var g: Array = CLASS_GEAR[c]
		var t1w: StringName = g[1]
		var t1d: int = g[3]
		p.inventory.add(t1w, 1)
		var slot: int = -1
		for i: int in p.inventory.hotbar_size:
			if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == t1w:
				slot = i
		p.inventory.select(slot)
		var arena: Arena = main.arenas[Config.MAP_SURFACE]
		arena.spawning = false
		var out: Vector2 = main.world.data.altar_center_px() + Vector2(0, Config.safe_radius_px() + 40.0)
		p.teleport(out)
		# Ranged weapons from farther (the knife would land first and cut the bow's 36-tick draw).
		var gap: float = 14.0 if Combat.attack_for(t1w).kind == Combat.Kind.MELEE else 56.0
		var h: HereticSim = arena.spawn_heretic(out + Vector2(gap, 0))
		var east: Vector2 = Combat.body_centre(h.pos)
		var attacks: int = 0
		for t: int in 120:
			p.begin_tick()
			p.tick_controls(Vector2i.ZERO, east, true, t == 0, false, TICK)
			main.step_combat(TICK)
			if h.hp < Config.HERETIC_HP:
				break
		attacks = 120 - p.inventory.stack_at(slot).durability
		check_eq(Config.HERETIC_HP - h.hp, t1d, "%s in main: %s lands %d" % [c, t1w, t1d])
		check_eq(attacks, 1, "%s: one attack wore 1" % c)
		h.hp = 0
		arena.heretics.clear()
		# A swing at nothing still wears (hit or miss): one click once the last action is over.
		var clicked: bool = false
		for t2: int in 160:
			var click: bool = not clicked and p.action_anim < 0 and p.vitals.alive() and not p.vitals.staggered()
			clicked = clicked or click
			p.begin_tick()
			p.tick_controls(Vector2i.ZERO, p.sim_position + Vector2(0, 40), true, click, false, TICK)
			main.step_combat(TICK)
		check_eq(p.inventory.stack_at(slot).durability, 118, "%s: a miss wore 1 too" % c)
	# Armour: a click with it selected puts it on; the armour slot click takes it off.
	main.spawn("paladin")
	var q: Player = main.player
	q.local_input = false
	q.inventory.add(&"armor_t1", 1)
	var aslot: int = 0
	for i2: int in q.inventory.hotbar_size:
		if q.inventory.stack_at(i2) != null and q.inventory.stack_at(i2).id == &"armor_t1":
			aslot = i2
	q.inventory.select(aslot)
	q.begin_tick()
	q.tick_controls(Vector2i.ZERO, q.sim_position + Vector2(0, 16), true, true, true, TICK)
	check(q.inventory.armor != null and q.inventory.stack_at(aslot) == null, "a click with armour selected: worn")
	check_eq(q.action_anim, -1, "no action played")
	main.hud.set_open(true)
	main.hud.armor_clicked.emit()
	check(q.inventory.armor == null and q.inventory.count_of(&"armor_t1") == 1, "the armour slot click: taken off")
	main.hud.set_open(false)
	# A death: the gear wears, the bag takes none of it.
	q.inventory.add(&"sword_t1", 1)
	q.inventory.add(&"stone_a", 6)
	Gear.equip(q.inventory, aslot)
	main._on_died(q)
	check_eq(q.inventory.armor.durability, 80, "death: the worn armour 100 -> 80")
	check_eq(q.inventory.count_of(&"sword_t1"), 1, "the tier-1 sword stays")
	var sword: ItemStack = null
	for s: ItemStack in q.inventory.slots:
		if s != null and s.id == &"sword_t1":
			sword = s
	check(sword != null and sword.durability == 96, "and wore 120 -> 96")
	check_eq(q.inventory.count_of(&"stone_a"), 3, "the stones: half in the bag (M4a)")


## main.tscn offline, the dungeon: the tier-1 pickaxe mines exactly as the pickaxe (the same swings give the same world)
## and mining wears nothing.
func _check_main_mining() -> void:
	var hashes: Array[String] = []
	for item: StringName in [&"pickaxe", &"pickaxe_t1"]:
		var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
		add_node(main)
		await await_frames(2)
		main.spawn("miner")
		var p: Player = main.player
		p.local_input = false
		main.travel(Config.MAP_DUNGEON)
		main.arenas[Config.MAP_DUNGEON].spawning = false
		p.inventory.add(item, 1)
		var slot: int = 0
		for i: int in p.inventory.hotbar_size:
			if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == item:
				slot = i
		p.inventory.select(slot)
		var dun: WorldData = main.worlds[Config.MAP_DUNGEON].data
		var target: Vector2i = Walls.NO_CELL
		var feet: Vector2 = p.sim_position
		for dx: int in range(1, 20):
			var c: Vector2i = Aim.feet_cell(feet) + Vector2i(-dx, 0)
			if Walls.owner_of(dun, c) != Walls.NO_CELL:
				target = c
				break
		if not check(target != Walls.NO_CELL, "a wall west of the arrival"):
			main.free()
			return
		p.teleport(Arena.spawn_feet(target + Vector2i(1, 0)))
		for t: int in 240:
			var holding: bool = Walls.owner_of(dun, target) != Walls.NO_CELL  # stop once it broke (a swing at air attacks)
			p.begin_tick()
			p.tick_controls(Vector2i.ZERO, Vector2(target * Config.TILE) + Vector2(8, 8), true, false, holding, TICK)
			main.step_combat(TICK)
		check(Walls.owner_of(dun, target) == Walls.NO_CELL, "%s broke the wall" % item)
		hashes.append(dun.content_hash())
		check_eq(p.inventory.stack_at(slot).durability, Gear.max_durability(item), "%s: mining wore nothing" % item)
		main.get_parent().remove_child(main)
		main.free()
	check_eq(hashes[0], hashes[1], "the tier-1 pickaxe mines exactly as the pickaxe (same world after 240 ticks)")


## A session (M7c, changed on purpose: M7a's host swung a tier-1 sword as the basic one, wore nothing and left the armour
## off): a member the host equips (SessionHost._equip) has gear on; its tier-1 sword lands 21 and wears 1 (the owner's
## inventory goes out); the worn armour takes 4 off a knife and wears 1 (the inventory goes out again).
func _check_session() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"GearTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	host.arenas[Config.MAP_SURFACE] = Arena.new()
	host.arenas[Config.MAP_SURFACE].setup(world.data, 1)
	host.arenas[Config.MAP_SURFACE].spawning = false
	var out: Vector2 = world.data.altar_center_px() + Vector2(0, Config.safe_radius_px() + 40.0)
	var m: NetMember = s.add_member(2, 7, "paladin", out, RigData.Dir.EAST)
	m.gate = InputGate.new()
	check(not m.player.gear_on, "a bare member has gear off")
	host._equip(m)
	check(m.player.gear_on, "the host's member has gear on (M7c)")
	m.player.inventory.clear()
	m.player.inventory.add(&"sword_t1", 1)
	m.inventory_dirty = false
	var h: HereticSim = host.arenas[Config.MAP_SURFACE].spawn_heretic(out + Vector2(14, 0))
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	f.op = NetProtocol.Op.USE
	f.slot = 0
	f.cell = Aim.feet_cell(out) + Vector2i(1, 0)
	f.map = Config.MAP_SURFACE
	f.aim = Combat.aim_code(Vector2.RIGHT)
	for t: int in 40:
		m.player.begin_tick()
		host.run_frame(m, f)
		f = NetProtocol.InputFrame.new(t + 2, Vector2i.ZERO)
		f.map = Config.MAP_SURFACE
		if h.hp < Config.HERETIC_HP:
			break
	check_eq(Config.HERETIC_HP - h.hp, 21, "the host's tier-1 sword lands its tier-1 damage (M7c)")
	check_eq(m.player.inventory.stack_at(0).durability, 119, "and wears 1")
	check(m.inventory_dirty, "its owner gets the inventory with the durability")
	m.player.inventory.wear(ItemStack.new(&"armor_t1", 1, 0))
	m.inventory_dirty = false
	m.player.take_hit(Config.HERETIC_DAMAGE, true)
	check_eq(m.player.vitals.hp, 92, "a host player's armour takes 4 off a knife (M7c)")
	check_eq(m.player.inventory.armor.durability, 99, "and wears 1")
	check(m.inventory_dirty, "the owner gets its inventory again")


## The same armoured fight twice: the same HP, heretic HP and durabilities every 25 ticks.
func _check_determinism() -> void:
	var runs: Array[PackedStringArray] = []
	for run_i: int in 2:
		var out: PackedStringArray = []
		var d: WorldData = open_world()
		var arena: Arena = Arena.new()
		arena.setup(d, 7)
		arena.spawning = false
		var p: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
		p.gear_on = true
		p.inventory.add(&"sword_t1", 1)
		p.inventory.wear(ItemStack.new(&"armor_t1", 1, 0))
		arena.spawn_heretic(p.sim_position + Vector2(14, 0))
		arena.spawn_heretic(p.sim_position + Vector2(-14, 4))
		var players: Array[Player] = [p]
		for t: int in 600:
			p.begin_tick()
			p.step_frame(NetProtocol.InputFrame.new(), TICK)
			if t % 48 == 0 and p.vitals.alive():
				var dmg: int = Gear.attack_damage(p.inventory.stack_at(0), 14)
				arena.player_attack(p, &"sword_t1", Combat.aim_code(Vector2.RIGHT if t % 96 == 0 else Vector2.LEFT), players, 255, dmg)
				Gear.wear_weapon(p.inventory, 0, &"sword_t1")
			arena.step(players)
			if t % 25 == 0:
				var hs: PackedStringArray = []
				for h: HereticSim in arena.heretics:
					hs.append(str(h.hp))
				out.append("%d %d %d %s" % [p.vitals.hp, p.inventory.stack_at(0).durability, p.inventory.armor.durability, ",".join(hs)])
		runs.append(out)
	check_eq(runs[0], runs[1], "the same armoured fight twice: the same every 25 ticks")
	check(runs[0][runs[0].size() - 1] != runs[0][0], "something happened in it")
