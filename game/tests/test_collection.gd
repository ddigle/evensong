extends "res://tests/base_test.gd"
## M11b, the world's collection (● game-concept §2, §4: 월드마다 독립, 자원·생물·업적, 클래스 / 전체 / 월드; which entries, thresholds and effects are
## PROVISIONAL, README "임시값" M11b): the table (5~10 entries, every unit, every scope); each entry's trigger and nothing else's; thresholds on
## the exact entry; the benefits in exact numbers (arrows with and without the tier-1 bow and the zeal, on basic attacks and each archer
## skill, nobody else's; defence with and without armour, broken, the minimum, not on poison; the restock time, a restock already running,
## the flag M12 reads); that it stays with the world (death, the maps, the respawn) and that two worlds are two collections; the recipes
## (the archer's snare with any of its inputs, the first-acquire unlock, the rare armour, its defence, durability, wear and repair); the
## panel (open and close, the input gate, a prayer, another panel, going down, no pause, the layout); the whole loop in main.tscn.

const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_table()
	_check_triggers()
	_check_thresholds()
	_check_arrows()
	_check_arrow_skills()
	_check_defence()
	_check_restock()
	_check_two_worlds()
	_check_recipes()
	_check_rare_armour()
	_check_panel_layout()
	await _check_ally_bag()
	await _check_main()
	await _check_panel()
	await _check_loop()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func open_world(size: Vector2i = Vector2i(60, 40)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_SURFACE
	d.collection = Collection.new()
	return d


static func arena_for(d: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	a.herd = Creatures.new()
	a.herd.setup(d, 1, false)
	return a


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.skills_on = true
	p.gear_on = true
	_nodes.append(p)
	return p


## Registers the first `n` entries of the table.
static func fill(c: Collection, n: int) -> void:
	for i: int in n:
		var row: Dictionary = Config.COLLECTION_ENTRIES[i]
		var id: StringName = row["id"]
		c.register(id)


func _check_table() -> void:
	var rows: Array = Config.COLLECTION_ENTRIES
	check_eq(rows.size(), 8, "8 entries")
	check(rows.size() >= 5 and rows.size() <= 10, "game-concept §12 항목 5~10개")
	var ids: Array[StringName] = []
	var units: Dictionary[String, int] = {}
	for row: Dictionary in rows:
		var id: StringName = row["id"]
		check(not ids.has(id), "%s once" % id)
		ids.append(id)
		var unit: String = row["unit"]
		var had: int = units.get(unit, 0)
		units[unit] = had + 1
		var what: StringName = row["what"]
		match row["how"]:
			"hunt":
				check(Config.CREATURES.has(what) and not Creatures.is_rare(what), "%s: a prey kind" % id)
			"capture":
				check(Config.CREATURES.has(what) and Creatures.is_rare(what), "%s: a rare kind" % id)
			"item":
				check(ItemDB.has(what), "%s: an item" % id)
			"kills":
				var need: int = row["count"]
				check(need > 1, "%s: a count" % id)
			_:
				fail("%s: an unknown rule" % id)
	check_eq(units, {"creature": 5, "resource": 2, "achievement": 1} as Dictionary[String, int], "● the units 생물, 자원, 업적")
	check_eq(ids, [&"hunt_hare", &"hunt_deer", &"take_lamp_fox", &"take_silver_stag", &"take_ash_owl", &"first_hide_fine", &"first_rare_essence",
		&"hunted_ten"] as Array[StringName], "the table")
	check_eq(Config.COLLECTION_BENEFITS, {&"class": 3, &"all": 5, &"world": 8} as Dictionary[StringName, int], "● the three scopes and their counts")
	check_eq(Config.COLLECTION_BENEFITS[&"world"], rows.size(), "the world's benefit takes every entry")
	check_eq(Config.COLLECTION_CLASS, Config.HUNTER_CLASS, "the class benefit is the archer's")
	check_eq(Collection.row_of(&"nothing"), {}, "no such entry")


func _check_triggers() -> void:
	# Prey: a kill, anyone's, its own entry only.
	var c: Collection = Collection.new()
	c.note_kill(&"hare")
	check(c.has(&"hunt_hare"), "a hare killed")
	check_eq(c.count(), 1, "that entry only")
	check_eq(c.kills, 1, "one kill")
	c.note_kill(&"hare")
	check_eq(c.count(), 1, "again: no second entry")
	check_eq(c.kills, 2, "two kills")
	check_eq(c.take_fresh(), [&"hunt_hare"] as Array[StringName], "new once")
	check(c.take_fresh().is_empty(), "taken")
	c.note_kill(&"deer")
	check(c.has(&"hunt_deer"), "a deer killed")
	# Rare: a kill registers nothing of its own, a capture does.
	c.note_kill(&"lamp_fox")
	check(not c.has(&"take_lamp_fox"), "a rare kill is no entry")
	check_eq(c.kills, 4, "but a kill")
	var kills_now: int = c.kills
	c.note_capture(&"lamp_fox")
	check(c.has(&"take_lamp_fox"), "a capture is")
	check_eq(c.kills, kills_now, "a capture is no kill")
	c.note_capture(&"hare")
	check_eq(c.count(), 3, "a capture of prey would register nothing")
	# Ten kills.
	var k: Collection = Collection.new()
	for i: int in 9:
		k.note_kill(&"lamp_fox")
	check_eq(k.progress_of(&"hunted_ten"), 9, "nine of ten")
	check(not k.has(&"hunted_ten"), "not yet")
	k.note_kill(&"lamp_fox")
	check(k.has(&"hunted_ten"), "the tenth")
	check_eq(k.progress_of(&"hunted_ten"), 10, "full")
	k.note_kill(&"lamp_fox")
	check_eq(k.progress_of(&"hunted_ten"), 10, "stays full")
	check_eq(k.progress_of(&"hunt_hare"), 0, "another entry: none")
	check_eq(k.progress_of(&"nothing"), 0, "no such entry")
	var flag: Collection = Collection.new()
	flag.kills = 12
	check_eq(flag.progress_of(&"hunted_ten"), 10, "kills past the count stop at its pips (--test-collection)")
	# Items: seen by an inventory, any way in, only the two named.
	var i2: Collection = Collection.new()
	var inv: Inventory = Inventory.new()
	inv.add(&"hide_worn", 3)
	inv.add(&"meat", 3)
	i2.note_inventory(inv)
	check_eq(i2.count(), 0, "a worn hide and meat register nothing")
	inv.add(&"hide_fine", 1)
	i2.note_inventory(inv)
	check(i2.has(&"first_hide_fine"), "the first whole hide")
	inv.remove(inv.slots.size() - 1, 1)
	inv.add(Config.RARE_MATERIAL, 1)
	i2.note_inventory(inv)
	check(i2.has(&"first_rare_essence"), "the first rare material")
	check_eq(i2.count(), 2, "those two")
	# Sold or spent, the entry stays: it is the world's.
	var i3: Collection = Collection.new()
	var inv2: Inventory = Inventory.new()
	inv2.add(&"hide_fine", 1)
	inv2.remove(0, 1)
	i3.note_inventory(inv2)
	check(i3.has(&"first_hide_fine"), "held once counts")
	# An item from another way in: the chest's path, add_stack.
	var i4: Collection = Collection.new()
	var inv3: Inventory = Inventory.new()
	inv3.add_stack(ItemStack.new(&"hide_fine", 1, ItemDB.Grade.NONE))
	i4.note_inventory(inv3)
	check(i4.has(&"first_hide_fine"), "from a chest as well")
	check(not Collection.new().register(&"nothing"), "an unknown entry is no entry")
	# Through the herd: anyone's kill counts, the world's collection hears.
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var m: Player = player(d, "miner", Vector2(100, 100))
	var hare: CreatureSim = a.herd.spawn(&"hare", Vector2(118, 100))
	hare.idle_ticks = 1000000
	a.hit_creature(hare, hare.hp, m.get_instance_id())
	check(d.collection.has(&"hunt_hare"), "the miner's kill registers it for the world")
	var deer: CreatureSim = a.herd.spawn(&"deer", Vector2(118, 100))
	check(a.herd.poison(deer, deer.hp, Config.POISON_INTERVAL_TICKS * 2, m.get_instance_id()), "poisoned")
	for t: int in Config.POISON_INTERVAL_TICKS + 1:
		a.herd.step([] as Array[Player])
	check(d.collection.has(&"hunt_deer"), "a death by poison is a kill")
	# No collection on a bare world: no error, nothing.
	var bare: WorldData = WorldData.new(Vector2i(40, 30))
	bare.map_id = Config.MAP_SURFACE
	var a2: Arena = arena_for(bare)
	var hare2: CreatureSim = a2.herd.spawn(&"hare", Vector2(100, 100))
	a2.hit_creature(hare2, hare2.hp, m.get_instance_id())
	check_eq(Collection.of(bare), null, "no collection")
	check_eq(Collection.of(null), null, "no world")


func _check_thresholds() -> void:
	var c: Collection = Collection.new()
	var lit: Array[String] = []
	for n: int in range(0, 9):
		check_eq(c.count(), n, "%d registered" % n)
		lit.append("%d:%s%s%s" % [n, "c" if c.benefit(&"class") else "", "a" if c.benefit(&"all") else "", "w" if c.benefit(&"world") else ""])
		check_eq(c.world_benefit(), n >= 8, "%d: the flag M12 reads" % n)
		if n < 8:
			var row: Dictionary = Config.COLLECTION_ENTRIES[n]
			var id: StringName = row["id"]
			check(c.register(id), "registering %s" % id)
	check_eq(",".join(lit), "0:,1:,2:,3:c,4:c,5:ca,6:ca,7:ca,8:caw", "each benefit on its exact entry")
	check_eq(c.describe().get_slice(" ", 0), "8/8", "the log's count")


# --- the class benefit, in numbers -------------------------------------------------------------------------

## The damage of the shot `a` let go last.
static func shot_damage(a: Arena) -> int:
	return a.shots[a.shots.size() - 1].damage


func _check_arrows() -> void:
	check_eq(Collection.arrow_hit(12), 13, "12: 1.2 rounds to 1")
	check_eq(Collection.arrow_hit(16), 18, "16: 1.6 rounds to 2")
	check_eq(Collection.arrow_hit(18), 20, "18")
	check_eq(Collection.arrow_hit(8), 9, "8")
	check_eq(Collection.arrow_hit(3), 4, "at least 1")
	check_eq(Collection.arrow_hit(0), 0, "nothing stays nothing")
	check_eq(Collection.arrow_hit(15), 17, "1.5 rounds up")
	# Basic attacks: [item, entries, zeal, want].
	for row: Array in [[&"bow", 0, -1, 12], [&"bow", 2, -1, 12], [&"bow", 3, -1, 13], [&"bow", 8, -1, 13], [&"bow_t1", 0, -1, 18], [&"bow_t1", 3, -1, 20],
			[&"bow", 0, 20, 14], [&"bow", 3, 20, 16], [&"bow_t1", 0, 20, 22], [&"bow_t1", 3, 20, 24]]:
		var item: StringName = row[0]
		var entries: int = row[1]
		var pct: int = row[2]
		var want: int = row[3]
		var d: WorldData = open_world()
		fill(d.collection, entries)
		var a: Arena = arena_for(d)
		var p: Player = player(d, "archer", Vector2(100, 100))
		if pct > 0:
			p.skills.zeal_pct = pct
			p.skills.zeal_ticks = 600
		var stack: ItemStack = ItemStack.new(item, 1, ItemDB.Grade.NONE, Gear.max_durability(item)) if Gear.tier(item) > 0 else ItemStack.new(item, 1, ItemDB.Grade.NONE)
		a.player_attack(p, item, 0, [p] as Array[Player], 255, Gear.attack_damage(stack, Combat.attack_for(item).damage))
		check_eq(shot_damage(a), want, "%s, %d entries, zeal %d: %d" % [item, entries, pct, want])
	# Nobody else's arrows, and only arrows.
	var d2: WorldData = open_world()
	fill(d2.collection, 8)
	var a2: Arena = arena_for(d2)
	var m: Player = player(d2, "miner", Vector2(100, 100))
	a2.player_attack(m, &"bow", 0, [m] as Array[Player])
	check_eq(shot_damage(a2), 12, "a miner's arrow: the class benefit is the archer's")
	var r: Player = player(d2, "archer", Vector2(100, 100))
	a2.player_attack(r, &"holy_light", 0, [r] as Array[Player])
	check_eq(shot_damage(a2), Combat.attack_for(&"holy_light").damage, "an archer's bolt is no arrow")
	# A melee swing: the creature's HP says.
	var h: HereticSim = a2.spawn_heretic(Vector2(118, 100))
	var hp: int = h.hp
	a2.player_attack(r, &"sword", 0, [r] as Array[Player])
	check_eq(hp - h.hp, Combat.attack_for(&"sword").damage, "an archer's sword is no arrow")
	# On a creature too (the same arrow).
	var d3: WorldData = open_world()
	fill(d3.collection, 3)
	var a3: Arena = arena_for(d3)
	var q: Player = player(d3, "archer", Vector2(100, 100))
	var stag: CreatureSim = a3.herd.spawn(&"silver_stag", Vector2(200, 100))
	stag.idle_ticks = 1000000
	a3.player_attack(q, &"bow", Combat.aim_code(Creatures.aim_point(stag) - Combat.aim_origin(q.sim_position)), [q] as Array[Player])
	var party: Array[Player] = [q]
	for t: int in 60:
		a3.step(party)
	check_eq(stag.hp, stag.hp_max() - 13, "the raised arrow on a rare creature")
	# No collection: as before.
	var bare: WorldData = WorldData.new(Vector2i(40, 30))
	bare.map_id = Config.MAP_SURFACE
	var a4: Arena = arena_for(bare)
	var b: Player = player(bare, "archer", Vector2(100, 100))
	a4.player_attack(b, &"bow", 0, [b] as Array[Player])
	check_eq(shot_damage(a4), 12, "no collection: 12")


func _landed_skill(a: Arena, p: Player, id: StringName) -> Skills.Landed:
	var party: Array[Player] = [p]
	p.action_aim = 0
	p.action_slot = 0
	p.action_target = Vector2(160, 100)
	p.action_skill_slot = Skills.slot_of(p.class_id(), id)
	return Skills.land(p, id, a, party)


func _check_arrow_skills() -> void:
	# [skill, entries, zeal, tier-1, want]: base 16, 8; the rain's own table.
	var rain: int = Skills.num_i(Skills.ARROW_RAIN, "damage") + 40 * Skills.num_i(Skills.ARROW_RAIN, "damage_per_focus_pct") / 100
	for row: Array in [[Skills.PIERCING_ARROW, 0, 0, false, 16], [Skills.PIERCING_ARROW, 3, 0, false, 18], [Skills.PIERCING_ARROW, 3, 20, false, 22],
			[Skills.FAN_SHOT, 0, 0, false, 8], [Skills.FAN_SHOT, 3, 0, false, 9], [Skills.FAN_SHOT, 0, 0, true, 12], [Skills.FAN_SHOT, 3, 0, true, 13],
			[Skills.FAN_SHOT, 3, 20, true, 16], [Skills.ARROW_RAIN, 0, 0, false, rain], [Skills.ARROW_RAIN, 3, 0, false, Collection.arrow_hit(rain)]]:
		var id: StringName = row[0]
		var entries: int = row[1]
		var pct: int = row[2]
		var t1: bool = row[3]
		var want: int = row[4]
		var d: WorldData = open_world()
		fill(d.collection, entries)
		var a: Arena = arena_for(d)
		var p: Player = player(d, "archer", Vector2(100, 100))
		if pct > 0:
			p.skills.zeal_pct = pct
			p.skills.zeal_ticks = 600
		p.inventory.add(&"bow_t1" if t1 else &"bow", 1)
		p.skills.resource = 40
		var r: Skills.Landed = _landed_skill(a, p, id)
		if not check(r.ok(), "%s lands: %s" % [id, r.why]):
			continue
		var got: int = r.damage
		if id == Skills.PIERCING_ARROW:
			got = r.shot.damage
		check_eq(got, want, "%s, %d entries, zeal %d, tier-1 %s" % [id, entries, pct, t1])
		for s: Arena.Shot in r.shots:
			check_eq(s.damage, want, "%s: every arrow" % id)
		if r.strike != null:
			check_eq(r.strike.damage, want, "%s: the strike's" % id)
	# The holy burst and the others are no arrows, for a cleric nor anyone.
	var d2: WorldData = open_world()
	fill(d2.collection, 8)
	var a2: Arena = arena_for(d2)
	var c: Player = player(d2, "cleric", Vector2(100, 100))
	c.inventory.add(&"holy_light", 1)
	check_eq(_landed_skill(a2, c, Skills.HOLY_BURST).damage, Skills.num_i(Skills.HOLY_BURST, "damage"), "the holy burst: as before")


# --- the all-classes benefit -----------------------------------------------------------------------------------

## What a knife of Config.HERETIC_DAMAGE takes off a player of `class_id` on a world with `entries` entries, wearing `armor` (&"" = none,
## `left` its durability).
func _knife(class_id: String, entries: int, armor: StringName, left: int = -1) -> int:
	var d: WorldData = open_world()
	fill(d.collection, entries)
	var p: Player = player(d, class_id, Vector2(100, 100))
	if not armor.is_empty():
		p.inventory.wear(ItemStack.new(armor, 1, ItemDB.Grade.NONE, left if left >= 0 else Gear.max_durability(armor)))
	p.take_hit(Config.HERETIC_DAMAGE, true)
	return Config.PLAYER_HP_MAX - p.vitals.hp


func _check_defence() -> void:
	check_eq(Config.HERETIC_DAMAGE, 12, "the knife")
	for class_id: String in Config.CLASSES:
		check_eq(_knife(class_id, 4, &""), 12, "%s, 4 entries, no armour" % class_id)
		check_eq(_knife(class_id, 5, &""), 11, "%s, 5 entries, no armour: 1 off" % class_id)
		check_eq(_knife(class_id, 5, &"armor_t1"), 7, "%s, 5 entries, tier-1: 4 + 1" % class_id)
	check_eq(_knife("archer", 4, &"armor_t1"), 8, "4 entries, tier-1: 4")
	check_eq(_knife("archer", 4, &"armor_rare"), 6, "4 entries, rare: 6")
	check_eq(_knife("archer", 5, &"armor_rare"), 5, "5 entries, rare: 6 + 1")
	check_eq(_knife("archer", 8, &"armor_rare"), 5, "8 entries: the same")
	check_eq(_knife("paladin", 5, &"armor_t1", 0), 11, "broken armour: only the world's")
	check_eq(Gear.after_armor(2, null, 1), 1, "the minimum: Config.ARMOR_MIN_DAMAGE")
	check_eq(Gear.after_armor(1, null, 1), 1, "the minimum holds")
	check_eq(Gear.after_armor(0, null, 1), 0, "nothing stays nothing")
	check_eq(Gear.after_armor(12, null), 12, "no extra: as before")
	# Not a knife (armored false: poison, the fall): nothing off, as the armour's.
	var d: WorldData = open_world()
	fill(d.collection, 5)
	var p: Player = player(d, "archer", Vector2(100, 100))
	p.take_hit(12)
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX - 12, "an unarmoured kind of hit: whole")
	# The worn piece wears as before, none worn wears nothing.
	var q: Player = player(d, "archer", Vector2(100, 100))
	q.inventory.wear(ItemStack.new(&"armor_t1", 1, ItemDB.Grade.NONE, 100))
	q.take_hit(12, true)
	check_eq(q.inventory.armor.durability, 100 - Config.GEAR_WEAR_PER_HIT, "the armour's wear as before")
	check_eq(Collection.defence_bonus(d), 1, "the world's defence")
	check_eq(Collection.defence_bonus(null), 0, "no world")
	# gear_on off (M7's rule): no armour rule at all.
	var off: Player = player(d, "archer", Vector2(100, 100))
	off.gear_on = false
	off.take_hit(12, true)
	check_eq(off.vitals.hp, Config.PLAYER_HP_MAX - 12, "gear off: whole")


# --- the world benefit --------------------------------------------------------------------------------------------

func _check_restock() -> void:
	check_eq(Config.SHOP_RESTOCK_TICKS, 10 * 60 * 60, "10 game minutes")
	check_eq(Config.COLLECTION_RESTOCK_TICKS, 7 * 60 * 60, "7 game minutes")
	var seven: int = 7 * 60 * 60
	var ten: int = 10 * 60 * 60
	var lit: Collection = Collection.new()
	fill(lit, 8)
	var dark: Collection = Collection.new()
	fill(dark, 7)
	check_eq(lit.restock_ticks(ten), seven, "lit: 7 minutes")
	check_eq(dark.restock_ticks(ten), ten, "not lit: 10")
	check_eq(lit.restock_ticks(100), 100, "a test's shorter period stays")
	check_eq(lit.restock_ticks(0), 0, "a shop that does not restock still does not")
	# The whole period, tick by tick.
	var s: Shop = Shop.new()
	for t: int in seven - 1:
		if s.step(lit):
			fail("restocked before 7 minutes (tick %d)" % t)
			break
	check_eq(s.restocks, 0, "none one tick before")
	check(s.step(lit), "on the tick")
	check(s.restocks == 1 and s.clock == 0, "the clock starts over")
	# Not lit: the old period.
	var s2: Shop = Shop.new()
	for t2: int in seven:
		if s2.step(dark):
			fail("restocked before 10 minutes")
			break
	check_eq(s2.restocks, 0, "7 minutes with 7 entries: none")
	s2.clock = ten - 1
	check(s2.step(dark), "10 minutes: restock")
	# No collection: as before.
	var s3: Shop = Shop.new()
	s3.clock = ten - 2
	check(not s3.step() and s3.step(), "no collection: 10 minutes")
	# A restock already running when it lights: the clock is kept. Before the new time: at 7 minutes.
	var s4: Shop = Shop.new()
	s4.clock = 5 * 60 * 60
	check(not s4.step(lit), "5 minutes in: not yet")
	s4.clock = seven - 1
	check(s4.step(lit), "at 7 minutes")
	# Past it already: the next tick, once, and then 7 minutes from there.
	var s5: Shop = Shop.new()
	s5.stock[&"holy_water"] = 0
	s5.clock = 8 * 60 * 60
	check(s5.step(lit), "8 minutes in when it lights: the next tick")
	check_eq(s5.restocks, 1, "one restock")
	check_eq(s5.left_of(&"holy_water"), Shop.offer_of(&"holy_water").cap, "the stock is back")
	check_eq(s5.clock, 0, "and the clock starts over")
	check(not s5.step(lit), "not again on the next")
	# The test hook's zero stays "never" (Shop.restock_ticks).
	var hook: int = Shop.restock_ticks
	Shop.restock_ticks = 0
	check(not Shop.new().step(lit), "never stays never")
	Shop.restock_ticks = hook


func _check_two_worlds() -> void:
	var a: WorldData = open_world()
	var b: WorldData = open_world()
	fill(a.collection, 5)
	check_eq(b.collection.count(), 0, "월드마다 독립: another world's starts empty")
	check_ne(a.collection, b.collection, "two objects")
	var p: Player = player(a, "archer", Vector2(100, 100))
	var q: Player = player(b, "archer", Vector2(100, 100))
	check_eq(Collection.arrow_damage(12, p), 13, "this world's benefit")
	check_eq(Collection.arrow_damage(12, q), 12, "not the other's")


# --- recipes and the rare armour ------------------------------------------------------------------------------------

static func recipe_inputs(r: Crafting.Recipe) -> String:
	var parts: PackedStringArray = []
	for i: Crafting.Ingredient in r.inputs:
		parts.append("%s x%d" % ["/".join(i.items()), i.count])
	return ", ".join(parts)


func _check_recipes() -> void:
	var snare: Crafting.Recipe = Crafting.recipe(Capture.SNARE)
	if not check(snare != null, "the snare has a recipe"):
		return
	check_eq(snare.station, Crafting.WORKBENCH, "at the basic workbench")
	check_eq(snare.out_count, 2, "two snares")
	check_eq(recipe_inputs(snare), "planks/log x1, hide_worn/hide_fine x1", "wood and any hide")
	check_eq(snare.classes, PackedStringArray(["archer"]), "the archer's")
	var armor: Crafting.Recipe = Crafting.recipe(&"armor_rare")
	if not check(armor != null, "the armour has a recipe"):
		return
	check_eq(armor.station, Crafting.ANVIL, "at the anvil")
	check_eq(armor.out_count, 1, "one")
	check_eq(recipe_inputs(armor), "rare_essence x3, hide_fine x2", "● the rare material is required")
	check(armor.classes.is_empty(), "anyone's")
	# Appended: the indices before them keep their meaning.
	var n: int = Crafting.recipe_count()
	check_eq(Crafting.index_of(Capture.SNARE), n - 3, "appended")
	check_eq(Crafting.index_of(&"armor_rare"), n - 2, "appended")
	check_eq(Crafting.index_of(&"repair_armor_rare"), n - 1, "its repair last")
	check_eq(Crafting.index_of(&"stone_wall"), 26 + Config.GEAR_REPAIR_MATERIAL.size() - 6, "M7b's rows where they were")
	# Every mix of the snare's inputs, the archer's; the class rule.
	for wood: StringName in [&"planks", &"log"]:
		for hide: StringName in [&"hide_worn", &"hide_fine"]:
			var inv: Inventory = Inventory.new()
			inv.add(wood, 1)
			inv.add(hide, 1)
			check(Crafting.unlocked(snare, inv), "%s + %s unlocks it" % [wood, hide])
			for class_id: String in Config.CLASSES:
				if class_id != "archer":
					check_eq(Crafting.refusal(snare, class_id, inv), "archer only", "%s: not %s's" % [wood, class_id])
			check_eq(Crafting.refusal(snare, "archer", inv), "", "%s + %s: the archer's" % [wood, hide])
			var o: Crafting.Outcome = Crafting.craft(snare, "archer", inv)
			check(o.ok() and o.item == Capture.SNARE and o.count == 2, "made")
			check_eq(inv.count_of(Capture.SNARE), 2, "two snares")
			check_eq(inv.count_of(wood) + inv.count_of(hide), 0, "the inputs are gone")
	# With both kinds of hide the worn one goes, the whole one stays for the armour.
	var both: Inventory = Inventory.new()
	both.add(&"planks", 2)
	both.add(&"log", 2)
	both.add(&"hide_fine", 1)
	both.add(&"hide_worn", 1)
	check(Crafting.craft(snare, "archer", both).ok(), "made")
	check_eq(both.count_of(&"hide_fine"), 1, "the whole hide stays")
	check_eq(both.count_of(&"hide_worn"), 0, "the worn one went")
	check_eq(both.count_of(&"planks"), 1, "a plank went")
	check_eq(both.count_of(&"log"), 2, "the logs stay")
	check_eq(Crafting.shown_input(both, snare.inputs[0]), &"planks", "the panel shows what is held")
	check_eq(Crafting.shown_input(both, snare.inputs[1]), &"hide_fine", "the second of them too")
	check_eq(Crafting.shown_input(Inventory.new(), snare.inputs[1]), &"hide_worn", "none held: the first")
	# Missing, and locked.
	var part: Inventory = Inventory.new()
	check_eq(Crafting.refusal(snare, "archer", part), Crafting.WHY_LOCKED, "nothing seen: locked")
	part.add(&"log", 1)
	check(not Crafting.unlocked(snare, part), "wood alone: locked")
	part.add(&"hide_worn", 1)
	check(Crafting.unlocked(snare, part), "both seen: unlocked")
	part.remove(1, 1)
	check_eq(Crafting.refusal(snare, "archer", part), Crafting.WHY_MISSING, "seen, not held: missing")
	# armor_rare: the first-acquire rule (M6), both inputs.
	var inv2: Inventory = Inventory.new()
	check(not Crafting.unlocked(armor, inv2), "nothing seen: locked")
	inv2.add(&"hide_fine", 2)
	check(not Crafting.unlocked(armor, inv2), "the hide alone: locked")
	inv2.add(Config.RARE_MATERIAL, 2)
	check(Crafting.unlocked(armor, inv2), "the first rare material unlocks it")
	check(Crafting.shown_recipes(Crafting.ANVIL, inv2).has(armor), "the anvil shows it")
	check_eq(Crafting.refusal(armor, "paladin", inv2), Crafting.WHY_MISSING, "two of three: missing")
	inv2.add(Config.RARE_MATERIAL, 1)
	for class_id2: String in Config.CLASSES:
		var copy: Inventory = Crafting.copy_of(inv2)
		var o2: Crafting.Outcome = Crafting.craft(armor, class_id2, copy)
		check(o2.ok(), "%s may make it (any class)" % class_id2)
		check_eq(copy.count_of(&"armor_rare"), 1, "%s: one armour" % class_id2)
		check_eq(copy.count_of(Config.RARE_MATERIAL) + copy.count_of(&"hide_fine"), 0, "%s: its inputs gone" % class_id2)
		var made: ItemStack = copy.stack_at(0)
		check_eq(made.durability, Config.GEAR_DURABILITY[&"armor_rare"], "%s: at full durability" % class_id2)


func _check_rare_armour() -> void:
	check_eq(Config.ARMOR_DEFENCE[&"armor_rare"], 6, "defence 6")
	check_eq(Config.ARMOR_DEFENCE[&"armor_t1"], Config.ARMOR_T1_DEFENCE, "the tier-1's stays")
	check(Config.GEAR_DURABILITY[&"armor_rare"] >= Config.GEAR_DURABILITY[&"armor_t1"], "at least the tier-1's durability")
	check_eq(Config.GEAR_DURABILITY[&"armor_rare"], 140, "140")
	check(Gear.is_armor(&"armor_rare"), "it goes in the armour slot")
	var inv: Inventory = Inventory.new()
	inv.add(&"armor_rare", 1)
	inv.select(0)
	check_eq(Gear.equip_refusal(inv, 0), "", "it can be put on")
	check_eq(Gear.equip(inv, 0), "", "put on")
	check_eq(Gear.defence(inv), 6, "its defence")
	# Wear: a knife, a death.
	check(Gear.wear_armor(inv), "a knife wears it")
	check_eq(inv.armor.durability, 139, "by the rule's point")
	check_eq(Gear.wear_on_death(inv), 1, "a death wears it")
	check_eq(inv.armor.durability, 139 - ceili(140.0 * Config.GEAR_DEATH_WEAR_PCT / 100.0), "by the rule's share")
	# Broken: no defence, repaired with whole hides at the anvil.
	inv.armor.durability = 0
	check_eq(Gear.defence(inv), 0, "broken: none")
	var repair: Crafting.Recipe = Crafting.recipe(&"repair_armor_rare")
	if not check(repair != null, "it has a repair"):
		return
	check(repair.is_repair() and repair.repair == &"armor_rare" and repair.station == Crafting.ANVIL, "at the anvil")
	check_eq(repair.inputs[0].item, Config.GEAR_REPAIR_RARE[&"armor_rare"], "its material")
	check_eq(repair.inputs[0].count, Config.GEAR_REPAIR_COST_ANYONE, "anyone's cost")
	inv.add(&"hide_fine", 2)
	inv.seen[&"armor_rare"] = true
	var o: Crafting.Outcome = Crafting.craft(repair, "miner", inv)
	check(o.ok(), "repaired: %s" % o.why)
	check_eq(inv.armor.durability, 140, "full again")
	check_eq(inv.count_of(&"hide_fine"), 0, "the hides went")
	# The shop neither sells it nor buys it, and the wire's slot carries it.
	check_eq(Shop.pays_for(&"armor_rare"), 0, "he does not buy it")
	check_eq(Shop.price_of(&"armor_rare"), -1, "he does not sell it")
	check_eq(Shop.price_of(Config.RARE_MATERIAL), -1, "nor the material")
	check_eq(Shop.price_of(Capture.SNARE), -1, "nor the snare")
	check_eq(Shop.pays_for(Capture.SNARE), 0, "he does not buy a snare")
	check(Shop.pays_for(Config.RARE_MATERIAL) > Shop.pays_for(&"hide_fine"), "the material is worth more than a hide")


# --- the panel ---------------------------------------------------------------------------------------------------------

func _check_panel_layout() -> void:
	var view: Vector2i = Config.VIEW_SIZE
	var p: Rect2i = CollectionPanel.panel_rect_for(view)
	check(Rect2i(Vector2i.ZERO, view).encloses(p), "the panel fits the view (%s)" % p)
	var hotbar_top: int = Hud.slot_origin(0, Config.HOTBAR_SLOTS, view).y
	check(p.end.y < hotbar_top, "above the hotbar")
	check(not p.has_point(view / 2) and not p.has_point(view / 2 - Vector2i(0, 24)), "clear of the player in the view's middle (nothing pauses behind it)")
	check_eq(CollectionPanel.rows(), 2, "two rows")
	var seen: Array[Rect2i] = []
	var rows: Array = Config.COLLECTION_ENTRIES
	for i: int in rows.size():
		var r: Rect2i = CollectionPanel.cell_rect(i, view)
		check(p.encloses(r), "cell %d inside the panel" % i)
		for o: Rect2i in seen:
			check(not r.intersects(o), "cell %d overlaps none" % i)
		seen.append(r)
		var row: Dictionary = rows[i]
		var img: Image = CollectionPanel.picture_of(row)
		check(img != null and img.get_width() <= CollectionPanel.CELL - 2 and img.get_height() <= CollectionPanel.CELL - 2,
			"%s's picture fits its cell (%s)" % [row["id"], img.get_size()])
		var shadow: Image = CollectionPanel.shadow_of(img)
		var drawn: int = 0
		var wrong: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				if img.get_pixel(x, y).a8 >= 128:
					drawn += 1
					if shadow.get_pixel(x, y) != CollectionPanel.SILHOUETTE:
						wrong += 1
		check(drawn > 20, "%s draws something" % row["id"])
		check_eq(wrong, 0, "%s: its silhouette is one dark colour" % row["id"])
	var kills: int = rows.size() - 1
	var cell: Rect2i = CollectionPanel.cell_rect(kills, view)
	for k: int in 10:
		var pip: Rect2i = CollectionPanel.pip_rect(kills, k, 10, view)
		check(cell.encloses(pip), "pip %d inside its cell" % k)
		for k2: int in k:
			check(not pip.intersects(CollectionPanel.pip_rect(kills, k2, 10, view)), "pips %d and %d apart" % [k, k2])
	for j: int in CollectionPanel.BENEFITS.size():
		var b: Rect2i = CollectionPanel.benefit_rect(j, view)
		check(p.encloses(b), "benefit %d inside the panel" % j)
		check(b.position.y >= CollectionPanel.cell_rect(rows.size() - 1, view).end.y, "benefit %d under the cells" % j)
		check(ItemIcons.image_from_map(CollectionPanel.BENEFIT_MAPS[CollectionPanel.BENEFITS[j]]) != null, "benefit %d's picture" % j)
		check(b.size.x >= 28, "room for the mark and its count")


func _main() -> Main:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	main.arenas[Config.MAP_DUNGEON].spawning = false
	main.spawn("archer")
	main.player.local_input = false
	return main


## A key pressed (an InputEventAction, the way Main reads it).
static func press(main: Main, action: StringName) -> void:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	main._unhandled_input(e)


## M11 review: what an ally holds counts too.
func _check_ally_bag() -> void:
	var main: Main = await _main()
	var col: Collection = main.world_collection()
	var ally: Player = main.add_ally("miner", false)
	ally.inventory.add(Config.RARE_MATERIAL, 1)
	check(not col.has(&"first_rare_essence"), "main: not yet")
	main.step_creatures()
	check(col.has(&"first_rare_essence"), "main: the first material, in an ally's bag")


func _check_main() -> void:
	var main: Main = await _main()
	var col: Collection = main.world_collection()
	check(col != null, "main: a collection")
	check_eq(col.count(), 0, "main: it starts empty")
	check_eq(main.worlds[Config.MAP_DUNGEON].data.collection, col, "main: the same object on the dungeon's data")
	check_eq(main.arenas[Config.MAP_SURFACE].herd.data.collection, col, "main: the herd reaches it")
	# Death: the collection stays.
	var p: Player = main.player
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	var hare: CreatureSim = herd.spawn(&"hare", main.world.data.altar_center_px() + Vector2(0.0, Config.safe_radius_px() + 60.0))
	herd.hit(hare, hare.hp, p.get_instance_id())
	main.step_creatures()
	check(col.has(&"hunt_hare"), "main: registered")
	check(col.take_fresh().is_empty(), "main: taken for the log")
	p.inventory.add(&"hide_fine", 4)
	main.step_creatures()
	check(col.has(&"first_hide_fine"), "main: the first whole hide in the local player's bag")
	p.take_hit(Config.PLAYER_HP_MAX)
	for t: int in Config.DOWN_TICKS + Config.RESPAWN_TICKS + 4:
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(), TICK)
		if p.vitals.alive():
			break
	check(p.vitals.alive(), "main: dead and back")
	check_eq(col.count(), 2, "main: a death loses nothing")
	check_eq(main.world_collection(), col, "main: the same collection")
	# The dungeon: the benefits reach a player there.
	fill(col, 8)
	main.step_creatures()
	main.travel(Config.MAP_DUNGEON)
	check_eq(Collection.of(p.data), col, "main: below, the same collection")
	check_eq(Collection.arrow_damage(12, p), 13, "main: the arrows below")
	check_eq(Collection.defence_bonus(p.data), 1, "main: the defence below")
	main.travel(Config.MAP_SURFACE)
	check_eq(col.count(), 8, "main: back up, all of it")
	# The world benefit through Main's clock.
	var sh: Shop = main.world_shop()
	sh.clock = Config.COLLECTION_RESTOCK_TICKS - 1
	var before: int = sh.restocks
	main.step_shop()
	check_eq(sh.restocks, before + 1, "main: the shop's clock reads the world benefit")
	# A world swapped in (tests, a client gone offline) gets its own collection with its arena.
	var other: WorldData = SurfaceGen.generate(2)
	main.world.load_data(other)
	check(main.ensure_combat(Config.MAP_SURFACE), "main: the arena of the new data")
	check(other.collection != null and other.collection != col, "main: another world, another collection")
	check_eq(other.collection.count(), 0, "main: empty")
	check(other.rare_zone != null, "main: and its own zone")
	main.get_parent().remove_child(main)
	main.free()


func _check_panel() -> void:
	var main: Main = await _main()
	var p: Player = main.player
	var panel: CollectionPanel = main.hud.collection
	check(not main.collection_open(), "closed at the start")
	check(InputMap.has_action(&"collection"), "the key's action")
	var keys: Array[InputEvent] = InputMap.action_get_events(&"collection")
	var key: InputEventKey = keys[0] as InputEventKey
	check_eq(key.physical_keycode, KEY_K, "K")
	press(main, &"collection")
	check(main.collection_open() and panel.visible, "K opens it")
	check(p.ui_locked, "the player stands")
	check(not main.hud.open, "no inventory with it")
	# The input gate: move keys, a use and a skill key do nothing; the game goes on.
	var from: Vector2 = p.sim_position
	p.begin_tick()
	p.tick_controls(Vector2i(1, 0), p.sim_position + Vector2(30, 0), true, true, true, TICK)
	check_eq(p.sim_position, from, "the gate: no move")
	check_eq(p.action_anim, -1, "the gate: no use")
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK, false, false, true)
	check_eq(p.skills.refused_why, Skills.WHY_PANEL, "the gate: a skill key is refused")
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	var clock: int = herd.clock
	main.step_creatures()
	check_eq(herd.clock, clock + 1, "no pause: the world's clock runs")
	press(main, &"toggle_inventory")
	check(not main.collection_open() and not p.ui_locked, "Tab closes it")
	press(main, &"collection")
	check(main.collection_open(), "open")
	press(main, &"collection")
	check(not main.collection_open(), "K closes it")
	press(main, &"collection")
	press(main, &"ui_cancel")
	check(not main.collection_open(), "Esc closes it")
	check(not p.ui_locked, "the player is free")
	# While it is open no other panel opens.
	press(main, &"collection")
	press(main, &"craft_hand")
	check(not main.crafting_open(), "C does nothing")
	main.open_shop(Vector2i(10, 10))
	check(not main.shop_open(), "the shop stays shut")
	press(main, &"ui_cancel")
	# Another panel open: K does nothing.
	p.inventory.add(&"log", 4)
	main.toggle_hand()
	check(main.crafting_open(), "the hand panel")
	main.toggle_collection()
	check(not main.collection_open(), "another panel open: refused")
	main.close_crafting()
	# Down closes it, and refuses it.
	press(main, &"collection")
	check(main.collection_open(), "open again")
	p.take_hit(Config.PLAYER_HP_MAX)
	main._check_crafting()
	check(not main.collection_open(), "down: closed")
	check(not p.ui_locked, "down: the keys are its own")
	main.toggle_collection()
	check(not main.collection_open(), "down: refused")
	main.get_parent().remove_child(main)
	main.free()
	# While praying: refused.
	var m2: Main = await _main()
	m2.spawn("cleric")
	var c: Player = m2.player
	c.local_input = false
	c.prayer_role = Prayer.Role.PRAYING
	m2.toggle_collection()
	check(not m2.collection_open(), "praying: refused")
	c.prayer_role = Prayer.Role.NONE
	m2.toggle_collection()
	check(m2.collection_open(), "after the prayer it opens")
	# The panel follows the world while it is open.
	var seen: int = m2.hud.collection._seen
	m2.world_collection().register(&"hunt_hare")
	await await_frames(2)
	check_ne(m2.hud.collection._seen, seen, "it redraws what changed")
	m2.close_collection()
	check_eq(m2.hud.collection.collection, null, "closed: it holds nothing")
	# A bot's K.
	check_eq(NetBot.new().parse("collection;wait:2;collection"), "", "the bot's K")
	m2.bot = NetBot.new()
	m2.bot.parse("collection")
	m2._bot_tick(TICK)
	check(m2.collection_open(), "the bot opens it")
	m2.bot = null
	m2.get_parent().remove_child(m2)
	m2.free()


## The whole loop on the real world, through the real rules and Main: hunt with arrows, pick up, craft snares at a workbench, wound and
## snare the three rare creatures, make the armour at an anvil, ten kills: all eight entries, all three benefits.
func _check_loop() -> void:
	var main: Main = await _main()
	var p: Player = main.player
	var w: GameWorld = main.world
	var col: Collection = main.world_collection()
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	herd.spawning = false
	var z: RareZone = w.data.rare_zone
	check(z != null, "loop: the zone")
	p.teleport(z.center_px())
	# Prey in the zone's middle, one at a time, shot with the bow.
	var bow: int = -1
	for i: int in p.inventory.size():
		var s: ItemStack = p.inventory.stack_at(i)
		if s != null and s.id == &"bow":
			bow = i
	check(bow >= 0, "loop: the archer's bow")
	p.inventory.select(bow)
	for kind: StringName in [&"hare", &"deer"]:
		var c: CreatureSim = herd.spawn(kind, p.sim_position + Vector2(90, 0))
		c.idle_ticks = 1000000
		c.hp = 1
		var aim: Vector2 = Creatures.aim_point(c)
		for t: int in 120:
			p.begin_tick()
			p.tick_controls(Vector2i.ZERO, aim, true, t == 0, t == 0, TICK)
			main.step_combat(TICK)
			main.step_creatures()
			if not c.alive():
				break
		check(not c.alive(), "loop: the arrow killed the %s" % kind)
		check(col.has(StringName("hunt_%s" % kind)), "loop: %s's entry" % kind)
		# Its drops, picked up with F from the next tile.
		var cell: Vector2i = Aim.feet_cell(c.pos)
		for dr: WorldData.Drop in w.data.drops_at(cell):
			var got: WorldItems.Outcome = WorldItems.pickup(w.data, Arena.spawn_feet(cell + Vector2i(-1, 0)), "archer", p.inventory, cell)
			for e: EditLog.WorldEdit in got.edits:
				w.apply_edit(e)
			check(got.ok(), "loop: %s picked up" % dr.item)
		for t2: int in Config.CREATURE_CORPSE_TICKS + 1:
			main.step_creatures()
	check(col.has(&"first_hide_fine"), "loop: the first whole hide")
	check_eq(p.inventory.count_of(&"hide_fine"), 3, "loop: a hare's and a deer's")
	check_eq(p.inventory.count_of(&"meat"), 3, "loop: and their meat")
	check_eq(col.count(), 3, "loop: three entries")
	check(col.benefit(&"class"), "loop: the class benefit lit")
	# A workbench, snares.
	var inv: Inventory = p.inventory
	inv.add(&"planks", 1)
	var snare: Crafting.Recipe = Crafting.recipe(Capture.SNARE)
	check(Crafting.craft(snare, p.class_id(), inv).ok(), "loop: snares made")
	inv.add(&"planks", 1)
	check(Crafting.craft(snare, p.class_id(), inv).ok(), "loop: more snares")
	check_eq(inv.count_of(Capture.SNARE), 4, "loop: four snares")
	check_eq(inv.count_of(&"hide_fine"), 1, "loop: two whole hides went (no worn one)")
	# The three rare creatures, wounded by real arrows from close by, then the snare.
	for kind2: StringName in [&"lamp_fox", &"silver_stag", &"ash_owl"]:
		var r: CreatureSim = null
		for c2: CreatureSim in herd.list:
			if c2.kind == kind2:
				r = c2
		if not check(r != null and r.bound, "loop: %s is there" % kind2):
			continue
		herd.rest(r)
		r.state_ticks = -100000  # it rests: the walk up is not this test's
		p.teleport(r.pos + Vector2(-Config.CAPTURE_TEST_NEAR_PX, 0.0))
		p.inventory.select(bow)
		var mouse: Vector2 = Creatures.aim_point(r)
		var shots: int = 0
		while not r.can_be_taken() and shots < 12:
			shots += 1
			var hp: int = r.hp
			for t3: int in 120:
				p.begin_tick()
				p.tick_controls(Vector2i.ZERO, mouse, true, t3 == 0, t3 == 0, TICK)
				main.step_combat(TICK)
				main.step_creatures()
				if r.hp != hp or not r.alive():
					break
			# It bolted: back to rest, in reach.
			herd.rest(r)
			r.state_ticks = -100000
			p.teleport(r.pos + Vector2(-Config.CAPTURE_TEST_NEAR_PX, 0.0))
			mouse = Creatures.aim_point(r)
			for t4: int in Player.action_ticks(RigData.Anim.BOW):
				p.begin_tick()
				p.tick_controls(Vector2i.ZERO, mouse, true, false, false, TICK)
		if not check(r.can_be_taken(), "loop: %s wounded down to its threshold in %d arrows (%d HP)" % [kind2, shots, r.hp]):
			continue
		var slot: int = -1
		for i2: int in inv.size():
			var st: ItemStack = inv.stack_at(i2)
			if st != null and st.id == Capture.SNARE:
				slot = i2
		inv.select(slot)
		var snares: int = inv.count_of(Capture.SNARE)
		for t5: int in Capture.impact_tick() + 1:
			p.begin_tick()
			p.tick_controls(Vector2i.ZERO, mouse, true, t5 == 0, t5 == 0, TICK)
			main.step_combat(TICK)
			main.step_creatures()
		check_eq(inv.count_of(Capture.SNARE), snares - 1, "loop: %s: one snare" % kind2)
		check(col.has(StringName("take_%s" % kind2)), "loop: %s's entry" % kind2)
		for t6: int in Player.action_ticks(Config.CAPTURE_ANIM):
			p.begin_tick()
			p.tick_controls(Vector2i.ZERO, mouse, true, false, false, TICK)
	check_eq(inv.count_of(Config.RARE_MATERIAL), 3, "loop: three of the material")
	check(col.has(&"first_rare_essence"), "loop: the first material")
	check_eq(col.count(), 7, "loop: seven entries")
	check(col.benefit(&"all"), "loop: the all-classes benefit lit")
	check(not col.world_benefit(), "loop: not the world's yet")
	# The anvil's recipe shows itself by the first-acquire rule.
	inv.add(&"hide_fine", 1)
	var armor: Crafting.Recipe = Crafting.recipe(&"armor_rare")
	check(Crafting.shown_recipes(Crafting.ANVIL, inv).has(armor), "loop: the rare armour unlocked")
	check(Crafting.craft(armor, p.class_id(), inv).ok(), "loop: the rare armour made")
	check_eq(inv.count_of(Config.RARE_MATERIAL), 0, "loop: the material spent")
	var at: int = -1
	for i3: int in inv.size():
		var st2: ItemStack = inv.stack_at(i3)
		if st2 != null and st2.id == &"armor_rare":
			at = i3
	inv.select(at if at < inv.hotbar_size else 0)
	if at >= inv.hotbar_size:
		inv.move(at, 0)
	check_eq(Gear.equip(inv, inv.selected), "", "loop: put on")
	# Ten kills: eight more prey by any means.
	while col.kills < 10:
		var c3: CreatureSim = herd.spawn(&"hare", z.center_px() + Vector2(40, 0))
		herd.hit(c3, c3.hp, p.get_instance_id())
		main.step_creatures()
	check_eq(col.count(), 8, "loop: all eight")
	check(col.world_benefit(), "loop: the world benefit lit")
	# The end state, in numbers.
	check_eq(Collection.arrow_damage(12, p), 13, "loop: arrows")
	p.vitals.hp = Config.PLAYER_HP_MAX
	p.vitals.invuln_ticks = 0
	var hp2: int = p.vitals.hp
	p.take_hit(Config.HERETIC_DAMAGE, true)
	check_eq(hp2 - p.vitals.hp, Config.HERETIC_DAMAGE - 7, "loop: the knife, 6 + 1 off")
	check_eq(col.restock_ticks(Config.SHOP_RESTOCK_TICKS), Config.COLLECTION_RESTOCK_TICKS, "loop: the merchant's 7 minutes")
	note("loop: %s" % col.describe())
