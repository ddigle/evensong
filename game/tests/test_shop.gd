extends "res://tests/base_test.gd"
## M8a, money and the merchant's shop (items/shop.gd; ● gameplay-design §3.0 R11 tier 1 "대체 수단 … 성능 상한 … 지속 공급이 안
## 된다", the merchant "제단 곁 상인"; ● R41 the currency is money; every number PROVISIONAL, README "임시값" M8a): the tables (what
## he sells = the R11 column's entries whose item exists, written out here; caps, the shop grade, holy water the dearest
## consumable, the gear above its materials; what he buys and what he never buys), no profitable loop (every recipe and repair
## walked: a made thing never fetches more than its inputs; the shop-only cost of every item above what he pays; random walks of
## buying, crafting, wearing and selling never raise what a player's things are worth), the stock and its refill on the game
## clock (deterministic, not the wall clock), every buy path (not enough money, sold out, a full inventory, the last money spent,
## money from several stacks, the slot the price frees), every sell path (one, a whole stack, a partial stack, not bought, worn
## and broken gear, a full purse), and money as an item (the death bag takes half of every money stack, the chest, a drop, the
## inventory's wire).

## Written out here on purpose: the ● R11 대체 수단 column's entries whose item exists in the slice, in the panel's order
## (potions: 약초사 "상점 포션", 성직자 "상점 치유 포션"; 팔라딘 "상점의 성수"; 기술자 "기본 키트 (횃불 …)"; 광부 "상점의 저급 광석";
## 룬마스터 "상점 1티어 장비").
const SOLD: Array[StringName] = [&"potion_healing", &"potion_buff", &"holy_water", &"torch", &"ore_copper", &"sword_t1",
	&"bow_t1", &"holy_light_t1", &"pickaxe_t1", &"sickle_t1", &"armor_t1"]
const GEAR: Array[StringName] = [&"sword_t1", &"bow_t1", &"holy_light_t1", &"pickaxe_t1", &"sickle_t1", &"armor_t1"]
## Never bought (written out): money, the basic tools, seeds, placeables, build pieces, holy water, the debug-only items.
const NOT_BOUGHT: Array[StringName] = [&"money", &"pickaxe", &"hoe", &"sickle", &"watering_can", &"sword", &"bow",
	&"holy_light", &"axe", &"seed_healing", &"seed_buff", &"seed_poison", &"torch", &"alchemy_table", &"workbench", &"anvil",
	&"relic_bench", &"storage_chest", &"stone_wall", &"door", &"stone_floor", &"lantern", &"holy_water", &"stone_block",
	&"herb_clump"]
const BIG: int = 1 << 40


func run() -> Array[String]:
	_check_tables()
	_check_no_profit()
	await _check_stock()
	_check_buy()
	_check_sell()
	_check_money_item()
	_check_walks()
	return failures


static func money(n: int) -> Inventory:
	var inv: Inventory = Inventory.new()
	if n > 0:
		inv.add(ItemDB.MONEY, n)
	return inv


static func index_of(item: StringName) -> int:
	var all: Array[Shop.Offer] = Shop.offers()
	for i: int in all.size():
		if all[i].item == item:
			return i
	return -1


## What everything `inv` holds fetches at the merchant (money counts as itself; the armour slot is not sold).
static func worth(inv: Inventory) -> int:
	var v: int = 0
	for st: ItemStack in inv.slots:
		if st == null:
			continue
		v += st.count if st.id == ItemDB.MONEY else Shop.pays_for_stack(st) * st.count
	return v


func _check_tables() -> void:
	var all: Array[Shop.Offer] = Shop.offers()
	var items: Array[StringName] = []
	for o: Shop.Offer in all:
		items.append(o.item)
	check_eq(items, SOLD, "he sells exactly the R11 column's entries whose item exists, in this order")
	check_eq(index_of(&"potion_poison"), -1, "no poison potion (the herbalist's status potion; the column does not list it)")
	var dearest_other: int = 0
	var smallest_other: int = 1000
	for o2: Shop.Offer in all:
		check(ItemDB.has(o2.item) and o2.price > 0 and o2.cap > 0, "%s: a real item, a price, a stock" % o2.item)
		check(o2.cap <= 10, "%s: a small stock (%d), no sustained supply" % [o2.item, o2.cap])
		var def: ItemDB.ItemDef = ItemDB.get_def(o2.item)
		check_eq(o2.grade, ItemDB.Grade.COMMON if def.graded else ItemDB.Grade.NONE, "%s: the shop's grade (no high grade)" % o2.item)
		if GEAR.has(o2.item):
			check_eq(o2.cap, 1, "%s: one at a time (tier 1 is the cap)" % o2.item)
			check_eq(def.tier, 1, "%s is tier 1" % o2.item)
		elif o2.item != &"holy_water":
			dearest_other = maxi(dearest_other, o2.price)
			smallest_other = mini(smallest_other, o2.cap)
	var holy: Shop.Offer = Shop.offer_of(&"holy_water")
	check(holy.price >= 2 * dearest_other, "holy water (%d) clearly the dearest consumable (next %d)" % [holy.price, dearest_other])
	check(holy.cap < smallest_other, "holy water's stock (%d) the smallest (소량)" % holy.cap)
	check(Shop.offer_of(&"ore_copper").cap <= 5, "copper ore: a small stock (소량)")
	check(Shop.price_of(&"ore_copper") > 0 and Shop.price_of(&"ore_iron") < 0, "the lower ore only (copper), never iron")
	# The gear costs more than its materials: at what the materials fetch, and at the shop's prices for what the shop sells.
	for g: StringName in GEAR:
		var r: Crafting.Recipe = Crafting.recipe(g)
		if not check(r != null, "%s has a recipe" % g):
			continue
		var fetch: int = 0
		var via_shop: int = 0
		for ing: Crafting.Ingredient in r.inputs:
			fetch += ing.count * Shop.pays_for(ing.item)
			var p: int = Shop.price_of(ing.item)
			if ing.item == &"ingot_copper":
				p = Shop.price_of(&"ore_copper")  # smelted 1 : 1 from the shop's ore
			via_shop += ing.count * (p if p > 0 else Shop.pays_for(ing.item))
		check(Shop.price_of(g) > fetch and Shop.price_of(g) > via_shop,
			"%s: %d above its materials (%d fetched, %d through the shop)" % [g, Shop.price_of(g), fetch, via_shop])
	# What he buys: real items with a price; never these.
	for id: StringName in Config.SHOP_BUYS:
		check(ItemDB.has(id) and Shop.pays_for(id) > 0, "he buys %s for %d" % [id, Shop.pays_for(id)])
		var def2: ItemDB.ItemDef = ItemDB.get_def(id)
		check(not def2.is_money() and def2.kind != ItemDB.Kind.SEED and def2.kind != ItemDB.Kind.PLACEABLE
			and def2.kind != ItemDB.Kind.BUILD and def2.kind != ItemDB.Kind.CONSUMABLE and not (def2.is_tool() and def2.tier == 0),
			"%s is something gathered or made" % id)
	for id2: StringName in NOT_BOUGHT:
		check_eq(Shop.pays_for(id2), 0, "he never buys %s" % id2)
	for o3: Shop.Offer in all:
		var pays: int = Shop.pays_for(o3.item)
		check(pays < o3.price, "%s: he pays %d, less than he asks (%d)" % [o3.item, pays, o3.price])
	check_eq(Config.SHOP_GRADE, ItemDB.Grade.COMMON, "the shop's grade is COMMON")


## No profitable loop: (a) a made thing never fetches more than what it is made of (every recipe; a repair never adds more than
## its material fetches: from broken, worth 0, to full); (b) the cheapest way to get each item with money alone (buying, then any
## recipe on bought things) always costs more than he pays for it.
func _check_no_profit() -> void:
	var walked: int = 0
	var repairs: int = 0
	for r: Crafting.Recipe in Crafting.recipes():
		var inputs: int = 0
		for ing: Crafting.Ingredient in r.inputs:
			inputs += ing.count * Shop.pays_for(ing.item)
		if r.is_repair():
			repairs += 1
			check(Shop.pays_for(r.repair) <= inputs, "%s: a repair adds at most %d, its material fetches %d" % [r.id,
				Shop.pays_for(r.repair), inputs])
		else:
			check(r.out_count * Shop.pays_for(r.output) <= inputs, "%s: %d x %s fetch %d, at most its inputs' %d" % [r.id,
				r.out_count, r.output, r.out_count * Shop.pays_for(r.output), inputs])
		walked += 1
	check_eq(walked, Crafting.recipe_count(), "every recipe walked (%d, %d repairs)" % [walked, repairs])
	check(repairs == GEAR.size(), "every repair walked")
	# (b): the shop-only cost, relaxed over the recipes until it holds still.
	var cost: Dictionary[StringName, float] = {}
	for o: Shop.Offer in Shop.offers():
		cost[o.item] = float(o.price)
	var changed: bool = true
	var rounds: int = 0
	while changed and rounds < 64:
		changed = false
		rounds += 1
		for r2: Crafting.Recipe in Crafting.recipes():
			if r2.is_repair():
				continue
			var total: float = 0.0
			var ok: bool = true
			for ing2: Crafting.Ingredient in r2.inputs:
				if not cost.has(ing2.item):
					ok = false
					break
				total += ing2.count * cost[ing2.item]
			if ok and (not cost.has(r2.output) or total / r2.out_count < cost[r2.output] - 0.0001):
				cost[r2.output] = total / r2.out_count
				changed = true
	check(not changed, "the shop-only costs settle (%d rounds)" % rounds)
	for item: StringName in cost:
		check(float(Shop.pays_for(item)) < cost[item], "%s: costs %.2f with money alone, fetches %d" % [item, cost[item],
			Shop.pays_for(item)])
	check(cost.has(&"ingot_copper") and cost[&"ingot_copper"] == float(Shop.price_of(&"ore_copper")),
		"the one chain money alone can craft: the shop's copper ore smelted (%s)" % str(cost.keys()))
	note("no-profit: %d recipes (%d repairs) walked, %d items reachable with money alone" % [walked, repairs, cost.size()])


## The stock: full at the start, one less a buy, sold out refused, back to every cap after Config.SHOP_RESTOCK_TICKS of the
## shop's own ticks (never the wall clock), the same moves give the same stock.
func _check_stock() -> void:
	var s: Shop = Shop.new()
	for o: Shop.Offer in Shop.offers():
		check_eq(s.left_of(o.item), o.cap, "%s starts at its cap" % o.item)
	var inv: Inventory = money(250)
	var holy: int = index_of(&"holy_water")
	var cap: int = Shop.offer_of(&"holy_water").cap
	for k: int in cap:
		var d: Shop.Deal = s.buy(inv, holy)
		check(d.ok() and d.left == cap - 1 - k, "holy water bought, %d left" % d.left)
	var before: String = inv.describe()
	var sold_out: Shop.Deal = s.buy(inv, holy)
	check_eq(sold_out.why, Shop.WHY_SOLD_OUT, "the last one gone: 다 팔렸다")
	check_eq(inv.describe(), before, "nothing changed")
	check(Config.SHOP_RESTOCK_TICKS > 0, "a restock interval (PROVISIONAL default)")
	await await_frames(3)
	check_eq(s.clock, 0, "frames passing are not the shop's clock (only step() moves it)")
	var early: int = 0
	for t: int in Config.SHOP_RESTOCK_TICKS - 1:
		if s.step():
			early += 1
	check_eq(early, 0, "no restock before the interval (%d ticks)" % Config.SHOP_RESTOCK_TICKS)
	check_eq(s.left_of(&"holy_water"), 0, "still sold out one tick before")
	check(s.step(), "the restock tick")
	check(s.left_of(&"holy_water") == cap and s.restocks == 1 and s.clock == 0, "back to its cap, one restock, the clock starts over")
	for o2: Shop.Offer in Shop.offers():
		check_eq(s.left_of(o2.item), o2.cap, "%s at its cap again" % o2.item)
	# Determinism: the same buys and ticks twice, the same stock and inventory.
	var lines: Array[String] = []
	for run_i: int in 2:
		var s2: Shop = Shop.new()
		var inv2: Inventory = money(200)
		for step_i: int in 900:
			s2.step()
			if step_i % 97 == 3:
				s2.buy(inv2, step_i % Shop.offers().size())
		lines.append("%s|%s|%d" % [s2.describe(), inv2.describe(), s2.clock])
	check_eq(lines[0], lines[1], "the same moves twice: the same stock")


func _check_buy() -> void:
	var s: Shop = Shop.new()
	var potion: int = index_of(&"potion_healing")
	var inv: Inventory = money(30)
	var d: Shop.Deal = s.buy(inv, potion)
	check(d.ok() and d.money == 12 and Shop.money_in(inv) == 18, "a healing potion for 12 (30 -> 18)")
	check_eq(inv.count_of(&"potion_healing", ItemDB.Grade.COMMON), 1, "COMMON grade")
	check_eq(s.left_of(&"potion_healing"), Shop.offer_of(&"potion_healing").cap - 1, "the stock goes down")
	# Not enough money: refused, nothing changes.
	var poor: Inventory = money(39)
	var was: String = poor.describe()
	check_eq(s.buy(poor, index_of(&"holy_water")).why, Shop.WHY_MONEY, "39 for holy water at 40: 돈이 모자라다")
	check(poor.describe() == was and s.left_of(&"holy_water") == Shop.offer_of(&"holy_water").cap, "nothing changed")
	check_eq(s.buy(money(0), index_of(&"torch")).why, Shop.WHY_MONEY, "no money at all")
	# The last money spent: exactly the price, the money stack is gone.
	var exact: Inventory = money(40)
	var d2: Shop.Deal = s.buy(exact, index_of(&"holy_water"))
	check(d2.ok() and Shop.money_in(exact) == 0 and exact.count_of(&"holy_water") == 1, "40 for holy water: the last money spent")
	for st: ItemStack in exact.slots:
		check(st == null or st.id != ItemDB.MONEY, "no empty money stack left behind")
	# A full inventory: the item would not fit once the price is out: refused, the money kept.
	var full: Inventory = Inventory.new()
	full.slots[0] = ItemStack.new(ItemDB.MONEY, 50, 0)
	for i: int in range(1, full.size()):
		full.slots[i] = ItemStack.new(&"stone_a", 99, 0)
	var full_was: String = full.describe()
	check_eq(s.buy(full, index_of(&"torch")).why, Shop.WHY_FULL, "a full inventory: 가방이 찼다")
	check_eq(full.describe(), full_was, "the money kept, nothing changed")
	# The price frees its slot: exactly 3 money in a full inventory buys a torch into that slot.
	var freed: Inventory = Inventory.new()
	freed.slots[0] = ItemStack.new(ItemDB.MONEY, 3, 0)
	for i2: int in range(1, freed.size()):
		freed.slots[i2] = ItemStack.new(&"stone_a", 99, 0)
	var d3: Shop.Deal = s.buy(freed, index_of(&"torch"))
	check(d3.ok() and freed.stack_at(0) != null and freed.stack_at(0).id == &"torch", "the money's slot takes the torch")
	# Money from several stacks: the last slot first.
	var split: Inventory = Inventory.new()
	split.slots[0] = ItemStack.new(ItemDB.MONEY, 10, 0)
	split.slots[5] = ItemStack.new(ItemDB.MONEY, 10, 0)
	var d4: Shop.Deal = s.buy(split, potion)
	check(d4.ok() and split.stack_at(5) == null and split.stack_at(0).count == 8, "12 from 10 + 10: the last stack first (%s)"
		% split.describe())
	# A buy merges into a stack of the same item.
	var merge: Inventory = money(10)
	merge.add(&"torch", 4)
	s.buy(merge, index_of(&"torch"))
	check_eq(merge.count_of(&"torch"), 5, "a torch joins the torches")
	# Gear comes new: tier 1, full durability; one in stock.
	var rich: Inventory = money(200)
	var d5: Shop.Deal = s.buy(rich, index_of(&"armor_t1"))
	var armour: ItemStack = null
	for st2: ItemStack in rich.slots:
		if st2 != null and st2.id == &"armor_t1":
			armour = st2
	check(d5.ok() and armour != null and not armour.worn() and armour.durability == Config.GEAR_DURABILITY[&"armor_t1"],
		"the armour comes new (full durability)")
	check_eq(s.buy(rich, index_of(&"armor_t1")).why, Shop.WHY_SOLD_OUT, "one armour in stock")
	check_eq(s.buy(rich, -1).why, Shop.WHY_NOT_SOLD, "no such entry")
	check_eq(s.buy(rich, Shop.offers().size()).why, Shop.WHY_NOT_SOLD, "past the last entry")
	check_eq(s.buy_refusal(money(250), index_of(&"sword_t1")), "", "buy_refusal says yes when buy would go through")


func _check_sell() -> void:
	var s: Shop = Shop.new()
	var inv: Inventory = Inventory.new()
	inv.add(&"stone_a", 40)
	var d: Shop.Deal = s.sell(inv, 0, false)
	check(d.ok() and d.count == 1 and d.money == 1 and d.left == 39 and Shop.money_in(inv) == 1, "one stone sold for 1")
	var money_slot: int = -1
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == ItemDB.MONEY:
			money_slot = i
	check_eq(money_slot, 1, "the money in the first empty slot")
	var d2: Shop.Deal = s.sell(inv, 0, true)
	check(d2.ok() and d2.count == 39 and d2.left == 0 and inv.stack_at(0) == null and Shop.money_in(inv) == 40,
		"the whole stack: 39 more, the slot empty")
	check_eq(s.sell(inv, 0, false).why, Shop.WHY_EMPTY, "an empty slot: 빈 칸")
	# Any grade the same price.
	var herbs: Inventory = Inventory.new()
	herbs.add(&"wild_healing", 3, ItemDB.Grade.FINE)
	herbs.add(&"wild_healing", 3)
	check(s.sell(herbs, 0, true).money == 6 and s.sell(herbs, 1, true).money == 6, "FINE and COMMON herbs: 2 each")
	# Not bought: refused, nothing changes.
	for id: StringName in NOT_BOUGHT:
		var nb: Inventory = Inventory.new()
		nb.add(id, 1)
		var nb_was: String = nb.describe()
		check(s.sell(nb, 0, true).why == Shop.WHY_NOT_BOUGHT and nb.describe() == nb_was, "%s: 상인이 사지 않는 것" % id)
	# Worn gear: the price scaled by what is left; nothing left (broken, or 1 of 120) refused.
	var gear: Inventory = Inventory.new()
	gear.add(&"sword_t1", 1)
	gear.add(&"sword_t1", 1)
	gear.add(&"sword_t1", 1)
	gear.add(&"sword_t1", 1)
	gear.stack_at(1).durability = 60
	gear.stack_at(2).durability = 1
	gear.stack_at(3).durability = 0
	check_eq(Shop.pays_for_stack(gear.stack_at(0)), 8, "a new sword_t1: 8")
	check_eq(Shop.pays_for_stack(gear.stack_at(1)), 4, "worn to 60 / 120: 4")
	check(Config.SHOP_SELL_WORN_SCALED, "worn gear scaled (PROVISIONAL default)")
	check_eq(s.sell(gear, 2, false).why, Shop.WHY_WORN_OUT, "1 / 120 comes to 0: 다 닳아 값이 없다")
	check_eq(s.sell(gear, 3, false).why, Shop.WHY_WORN_OUT, "broken: 다 닳아 값이 없다")
	var d3: Shop.Deal = s.sell(gear, 1, false)
	check(d3.ok() and d3.money == 4 and Shop.money_in(gear) == 4, "the worn sword sold for 4")
	# A full purse: the money must fit; the slot a whole stack leaves counts.
	var purse: Inventory = Inventory.new()
	purse.slots[0] = ItemStack.new(ItemDB.MONEY, Config.STACK_MONEY - 1, 0)
	for i2: int in range(1, purse.size()):
		purse.slots[i2] = ItemStack.new(&"stone_a", 99, 0)
	check(s.sell(purse, 1, false).ok() and purse.stack_at(0).count == Config.STACK_MONEY, "one stone fills the purse to %d"
		% Config.STACK_MONEY)
	var purse_was: String = purse.describe()
	check_eq(s.sell(purse, 2, false).why, Shop.WHY_FULL, "a full purse, the stone stays: 가방이 찼다")
	check_eq(purse.describe(), purse_was, "nothing changed")
	var d4: Shop.Deal = s.sell(purse, 2, true)
	check(d4.ok() and d4.count == 99 and purse.stack_at(2) != null and purse.stack_at(2).id == ItemDB.MONEY
		and purse.stack_at(2).count == 99, "the whole stack goes and its slot takes the money")
	# A partial stack: 99 iron ore fetch 396, only 20 fit (no free slot, the stack's slot not freed by part of it): 5 sold.
	var part: Inventory = Inventory.new()
	part.slots[0] = ItemStack.new(ItemDB.MONEY, Config.STACK_MONEY - 20, 0)
	part.slots[1] = ItemStack.new(&"ore_iron", 99, 0)
	for i3: int in range(2, part.size()):
		part.slots[i3] = ItemStack.new(&"stone_a", 99, 0)
	var d5: Shop.Deal = s.sell(part, 1, true)
	check(d5.ok() and d5.count == 5 and d5.money == 20 and d5.left == 94 and part.stack_at(0).count == Config.STACK_MONEY,
		"a partial sale: 5 of 99 ore (the money that fits), 94 stay")
	# With room the money takes two stacks.
	var room: Inventory = Inventory.new()
	room.add(&"ore_iron", 99)
	var d6: Shop.Deal = s.sell(room, 0, true)
	check(d6.ok() and d6.money == 396 and Shop.money_in(room) == 396 and room.stack_at(0).count == Config.STACK_MONEY
		and room.stack_at(1).count == 396 - Config.STACK_MONEY, "396 money in two stacks (%s)" % room.describe())
	# Selling never touches the stock.
	check_eq(s.describe(), Shop.new().describe(), "what he buys never joins his stock")


## Money is an item: half of every money stack (rounded up) falls in the death bag; the chest keeps it; a drop and the inventory's
## wire carry a full stack (one byte each).
func _check_money_item() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var inv: Inventory = Inventory.new()
	inv.slots[0] = ItemStack.new(ItemDB.MONEY, 101, 0)
	inv.slots[1] = ItemStack.new(ItemDB.MONEY, Config.STACK_MONEY, 0)
	inv.slots[2] = ItemStack.new(&"stone_a", 10, 0)
	var feet: Vector2 = Arena.spawn_feet(Vector2i(70, 60))
	var o: WorldItems.Outcome = WorldItems.death_drop(d, feet, inv, Config.DEATH_DROP_HALF, 1)
	check(o.ok(), "a death bag (%s)" % o.why)
	check(inv.stack_at(0).count == 50 and inv.stack_at(1).count == 125 and inv.stack_at(2).count == 5,
		"half of every stack, rounded up, falls: money 101 -> 50, 250 -> 125 (%s)" % inv.describe())
	for e: EditLog.WorldEdit in o.edits:
		EditLog.apply_to_data(d, e)
	var in_bag: int = 0
	for id: int in d.drops:
		if d.drops[id].item == ItemDB.MONEY:
			in_bag += d.drops[id].count
	check_eq(in_bag, 51 + 125, "176 money in the bag")
	var bytes: PackedByteArray = d.drops_bytes()
	var round_trip: int = 0
	for k: int in bytes.decode_u16(0):
		var dr: WorldData.Drop = WorldData.read_drop(bytes, 2 + WorldData.DROP_BYTES * k, d.size)
		if dr != null and dr.item == ItemDB.MONEY:
			round_trip += dr.count
	check_eq(round_trip, 176, "the bag's money through the drop bytes")
	var bag: Vector2i = o.edits[0].cell
	var taker: Inventory = Inventory.new()
	var got: WorldItems.Outcome = WorldItems.pickup(d, Arena.spawn_feet(bag + Vector2i(0, 1)), "miner", taker, bag)
	check(got.ok() and Shop.money_in(taker) == 176, "F on the bag takes the money back (anyone's: %s)" % taker.describe())
	# The chest.
	var chest: WorldData.Chest = WorldData.Chest.new()
	var purse: Inventory = money(Config.STACK_MONEY)
	check(Storage.store(chest, purse, 0).ok() and chest.slots[0].count == Config.STACK_MONEY, "a full money stack in the chest")
	var cd: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	cd.put_placeable(Rect2i(62, 51, 3, 1), WorldData.PLACEABLE_CHEST)
	cd.chest_at(Vector2i(62, 51)).slots[0] = ItemStack.new(ItemDB.MONEY, Config.STACK_MONEY, 0)
	check_eq(cd.chests_bytes().decode_u8(4 + 1), Config.STACK_MONEY, "the chest's bytes carry it whole")
	check(Storage.take(chest, purse, 0).ok() and Shop.money_in(purse) == Config.STACK_MONEY, "and back")
	# The inventory's wire.
	var wire: Inventory = money(Config.STACK_MONEY)
	wire.add(ItemDB.MONEY, 7)
	var dec: NetProtocol.InventoryState = NetProtocol.decode_inventory(NetProtocol.encode_inventory(wire, 3))
	check(dec.ok and dec.stacks[0].id == ItemDB.MONEY and dec.stacks[0].count == Config.STACK_MONEY and dec.stacks[1].count == 7,
		"the inventory message carries money")


## Random walks: a herbalist with money and gathered things buys, crafts (every recipe, repairs too), wears its gear and sells in
## random order; what its things fetch (worth: money + every sellable stack at the merchant's price) never grows, and a buy always
## lowers it. Then a walk with money alone: whatever is bought, crafted and sold back, the money ends lower.
func _check_walks() -> void:
	var recipes: Array[Crafting.Recipe] = Crafting.recipes()
	var deals: int = 0
	var crafts: int = 0
	var grew: int = 0
	var buys_not_lower: int = 0
	var ended_above: int = 0
	for seed_value: int in 40:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7000 + seed_value
		var s: Shop = Shop.new()
		var inv: Inventory = money(200)
		inv.add(&"log", 12)
		inv.add(&"planks", 6)
		inv.add(&"stone_a", 30)
		inv.add(&"ore_iron", 8)
		inv.add(&"ore_copper", 4)
		inv.add(&"wild_healing", 6, ItemDB.Grade.FINE)
		inv.add(&"wild_buff", 4)
		inv.add(&"wild_poison", 4)
		var start: int = worth(inv)
		var v: int = start
		for step_i: int in 80:
			var kind: int = rng.randi_range(0, 3)
			if kind == 0:
				var d: Shop.Deal = s.buy(inv, rng.randi_range(0, Shop.offers().size() - 1))
				if d.ok():
					deals += 1
					if worth(inv) >= v:
						buys_not_lower += 1
			elif kind == 1:
				var r: Crafting.Recipe = recipes[rng.randi_range(0, recipes.size() - 1)]
				if Crafting.craft(r, "herbalist", inv).ok():
					crafts += 1
			elif kind == 2:
				var slot: int = rng.randi_range(0, inv.size() - 1)
				if s.sell(inv, slot, rng.randi_range(0, 1) == 1).ok():
					deals += 1
			else:
				var gs: int = rng.randi_range(0, inv.size() - 1)
				var g: ItemStack = inv.stack_at(gs)
				if g != null and g.max_durability() > 0:
					g.durability = rng.randi_range(0, g.durability)  # used: it wears
			var now: int = worth(inv)
			if now > v:
				grew += 1
			v = now
		for k: int in inv.size():
			s.sell(inv, k, true)
		if Shop.money_in(inv) > start:
			ended_above += 1
	check_eq(grew, 0, "no move ever raised what the things fetch (%d deals, %d crafts)" % [deals, crafts])
	check_eq(buys_not_lower, 0, "every buy lowered it")
	check_eq(ended_above, 0, "no walk ended with more money than its things fetched at the start")
	check(deals > 200 and crafts > 50, "the walks did trade and craft (%d deals, %d crafts)" % [deals, crafts])
	# Money alone: buy everything once, smelt the ore, sell all back.
	var s2: Shop = Shop.new()
	var only: Inventory = money(Config.STACK_MONEY)
	only.add(ItemDB.MONEY, Config.STACK_MONEY)
	var spent: int = 0
	for i: int in Shop.offers().size():
		var d2: Shop.Deal = s2.buy(only, i)
		spent += d2.money
	Crafting.craft(Crafting.recipe(&"ingot_copper"), "miner", only)
	for k2: int in only.size():
		s2.sell(only, k2, true)
	check(spent > 0 and Shop.money_in(only) < 2 * Config.STACK_MONEY, "money alone: %d in, %d back after selling everything"
		% [2 * Config.STACK_MONEY, Shop.money_in(only)])
	note("walks: 40 x 80 moves, %d deals, %d crafts; money alone %d -> %d" % [deals, crafts, 2 * Config.STACK_MONEY,
		Shop.money_in(only)])
