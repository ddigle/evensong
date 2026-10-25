extends "res://tests/base_test.gd"
## M6a, crafting (offline first): the recipes (inputs, grades, who may brew: ● gameplay-design §3.0 herbalist row),
## the craft rule (atomic, inputs from the last slots first, no room = refused), the unlock rule (○ §3.5 as
## Config.RECIPES_UNLOCK_ON_FIRST_GET), station reach for Tab (Config.STATION_REACH_TILES), the alchemy table
## (placement like a torch: footprint, open floor, bodies, never touching another; it blocks walking and shots;
## drawn on its footprint), and main.tscn (Tab at the table opens the panel and stands the player, keys and a
## click craft, walking away or Tab closes it, Tab elsewhere is the inventory; M6b: the table placed by the host in a
## session, a potion's USE a drink there; tests/test_net_potions.gd has the rest of the session's crafting).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_recipes()
	_check_craft_rules()
	_check_no_room()
	_check_unlock()
	_check_station_reach()
	_check_table_placement()
	_check_reserved_spots()
	_check_table_blocks()
	await _check_table_drawn()
	await _check_main_tab()
	await _check_session_table()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func inv_with(items: Array) -> Inventory:
	var inv: Inventory = Inventory.new()
	for e: Array in items:
		var id: StringName = e[0]
		var n: int = e[1]
		var g: int = e[2] if e.size() > 2 else -1
		inv.add(id, n, g)
	return inv


## The whole inventory as text (slots and selection) to see that a refused craft changed nothing.
static func inv_text(inv: Inventory) -> String:
	return "%s | sel %d" % [inv.describe(), inv.selected]


func _check_recipes() -> void:
	var all: Array[Crafting.Recipe] = Crafting.recipes().slice(0, 6)  # M7a: the workbench chain's come after (test_workbench.gd)
	check_eq(Crafting.recipes_for(Crafting.ALCHEMY).size(), 6, "six alchemy recipes: three potions x two grades")
	check_eq(Crafting.recipes().size(), 6 + Config.STATION_RECIPES.size() + Config.GEAR_REPAIR_MATERIAL.size()
		+ Config.BUILD_RECIPES.size(), "M7a: after them the chain's recipes and the repairs (M7b: then the build pieces, the axe)")
	var want: Dictionary[StringName, Array] = {  # id: [herb, potion, grade, herbalist only]
		&"potion_healing_common": [&"wild_healing", &"potion_healing", ItemDB.Grade.COMMON, not Config.COMMON_POTIONS_ANYONE],
		&"potion_healing_fine": [&"wild_healing", &"potion_healing", ItemDB.Grade.FINE, true],
		&"potion_buff_common": [&"wild_buff", &"potion_buff", ItemDB.Grade.COMMON, not Config.COMMON_POTIONS_ANYONE],
		&"potion_buff_fine": [&"wild_buff", &"potion_buff", ItemDB.Grade.FINE, true],
		&"potion_poison_common": [&"wild_poison", &"potion_poison", ItemDB.Grade.COMMON, true],
		&"potion_poison_fine": [&"wild_poison", &"potion_poison", ItemDB.Grade.FINE, true],
	}
	for r: Crafting.Recipe in all:
		if not check(want.has(r.id), "known recipe %s" % r.id):
			continue
		var w: Array = want[r.id]
		check_eq(r.station, Crafting.ALCHEMY, "%s at the alchemy table" % r.id)
		check_eq(r.inputs.size(), 1, "%s: one kind of input" % r.id)
		check_eq(r.inputs[0].item, w[0], "%s: from its herb" % r.id)
		check_eq(r.inputs[0].count, Config.POTION_HERBS, "%s: POTION_HERBS herbs" % r.id)
		check_eq(r.inputs[0].grade, w[2], "%s: herbs of that grade" % r.id)
		check_eq(r.output, w[1], "%s: makes its potion" % r.id)
		check_eq(r.out_count, 1, "%s: one potion" % r.id)
		check_eq(r.out_grade, w[2], "%s: the grade follows the herbs" % r.id)
		var only: bool = w[3]
		check_eq(r.classes.has("herbalist") and r.classes.size() == 1, only, "%s herbalist only (● §3.0)" % r.id)
		for c: String in Config.CLASSES:
			check_eq(r.allows(c), not only or c == "herbalist", "%s allowed for %s" % [r.id, c])
	check_eq(Crafting.recipes_for(Crafting.ALCHEMY).size(), 6, "the alchemy table has all six")
	check_eq(Crafting.recipes_for(&"alchemy").size(), 6, "M7a: no chain recipe at the alchemy table")
	check_eq(Crafting.station_kind(WorldData.PLACEABLE_ALCHEMY), Crafting.ALCHEMY, "the table is a station")
	for p: int in [WorldData.PLACEABLE_TORCH, WorldData.PLACEABLE_ALTAR, WorldData.PLACEABLE_SHRINE, WorldData.PLACEABLE_BAG]:
		check(Crafting.station_kind(p).is_empty(), "%s is no station" % WorldData.PLACEABLE_NAMES[p])


func _check_craft_rules() -> void:
	var r_heal: Crafting.Recipe = Crafting.recipe(&"potion_healing_common")
	var r_fine: Crafting.Recipe = Crafting.recipe(&"potion_healing_fine")
	var r_poison: Crafting.Recipe = Crafting.recipe(&"potion_poison_common")
	# Anyone: two COMMON herbs make one COMMON potion; they come from the last matching slot first.
	var inv: Inventory = inv_with([[&"sword", 1], [&"wild_healing", 3], [&"stone_a", 5]])
	inv.add(&"wild_healing", 99)  # tops up slot 1 to 99, the rest (3) to slot 3
	check_eq(inv.stack_at(3).count, 3, "setup: a second herb stack in slot 3")
	var o: Crafting.Outcome = Crafting.craft(r_heal, "miner", inv)
	check(o.ok(), "a miner brews a COMMON healing potion (%s)" % o.why)
	check_eq([o.item, o.count, o.grade], [&"potion_healing", 1, ItemDB.Grade.COMMON], "the outcome")
	check_eq(inv.count_of(&"wild_healing"), 100, "two herbs used")
	check_eq(inv.stack_at(3).count, 1, "taken from the last stack first (backpack before hotbar)")
	check_eq(inv.count_of(&"potion_healing", ItemDB.Grade.COMMON), 1, "one potion in")
	check_eq(inv.stack_at(4).id, &"potion_healing", "the potion went to the first empty slot (the hotbar)")
	# Missing inputs: nothing changes.
	var few: Inventory = inv_with([[&"wild_healing", 1]])
	var before: String = inv_text(few)
	check_eq(Crafting.craft(r_heal, "paladin", few).why, Crafting.WHY_MISSING, "one herb is not enough")
	check_eq(inv_text(few), before, "a refused craft changes nothing")
	# Grades are exact: FINE herbs are not COMMON herbs and the other way round.
	var fine: Inventory = inv_with([[&"wild_healing", 2, ItemDB.Grade.FINE]])
	check_eq(Crafting.refusal(r_heal, "herbalist", fine), Crafting.WHY_MISSING, "FINE herbs do not make a COMMON potion")
	check_eq(Crafting.refusal(r_fine, "herbalist", inv_with([[&"wild_healing", 4]])), Crafting.WHY_MISSING,
		"COMMON herbs do not make a FINE potion")
	# ● §3.0: FINE potions are the herbalist's even with FINE herbs in hand (given, dropped by a herbalist).
	before = inv_text(fine)
	check_eq(Crafting.craft(r_fine, "cleric", fine).why, Crafting.WHY_CLASS, "a cleric may not brew a FINE potion")
	check_eq(inv_text(fine), before, "nothing used")
	var made: Crafting.Outcome = Crafting.craft(r_fine, "herbalist", fine)
	check(made.ok() and made.grade == ItemDB.Grade.FINE and fine.count_of(&"wild_healing") == 0,
		"the herbalist brews the FINE one (%s)" % made.why)
	# ● §3.0: the status (poison) potion is the herbalist's at any grade.
	var tox: Inventory = inv_with([[&"wild_poison", 2]])
	check_eq(Crafting.craft(r_poison, "paladin", tox).why, Crafting.WHY_CLASS, "a paladin may not brew poison")
	check(Crafting.craft(r_poison, "herbalist", tox).ok(), "the herbalist brews COMMON poison")
	# PROVISIONAL Config.COMMON_POTIONS_ANYONE: the COMMON buff potion for anyone.
	var buff: Inventory = inv_with([[&"wild_buff", 2]])
	check_eq(Crafting.craft(Crafting.recipe(&"potion_buff_common"), "archer", buff).ok(), Config.COMMON_POTIONS_ANYONE,
		"an archer brews the COMMON buff potion (Config.COMMON_POTIONS_ANYONE)")
	check_eq(Crafting.craft(null, "herbalist", buff).why, Crafting.WHY_BAD_RECIPE, "no recipe")
	# Potions stack to Config.STACK_POTION.
	var many: Inventory = inv_with([[&"wild_healing", 2 * (Config.STACK_POTION + 1)]])
	for i: int in Config.STACK_POTION + 1:
		Crafting.craft(r_heal, "miner", many)
	check_eq(many.count_of(&"potion_healing"), Config.STACK_POTION + 1, "eleven potions")
	var biggest: int = 0
	for i2: int in many.size():
		if many.stack_at(i2) != null and many.stack_at(i2).id == &"potion_healing":
			biggest = maxi(biggest, many.stack_at(i2).count)
	check_eq(biggest, Config.STACK_POTION, "a full potion stack is STACK_POTION")


func _check_no_room() -> void:
	var r_heal: Crafting.Recipe = Crafting.recipe(&"potion_healing_common")
	# Every slot full, the herbs in a stack of 5: taking two frees no slot, so the potion has no room.
	var full: Inventory = Inventory.new()
	full.add(&"wild_healing", 5)
	for i: int in Config.INVENTORY_SLOTS - 1:
		full.add(&"sword" if i % 2 == 0 else &"bow", 1)
	check_eq(full.free_slots(), 0, "setup: full")
	var before: String = inv_text(full)
	check_eq(Crafting.craft(r_heal, "miner", full).why, Crafting.WHY_NO_ROOM, "no room for the potion: refused")
	check_eq(inv_text(full), before, "and nothing used (atomic)")
	# The same with a stack of exactly two herbs: using them frees the slot the potion goes into.
	var tight: Inventory = Inventory.new()
	tight.add(&"wild_healing", 2)
	for i2: int in Config.INVENTORY_SLOTS - 1:
		tight.add(&"sword", 1)
	var o: Crafting.Outcome = Crafting.craft(r_heal, "miner", tight)
	check(o.ok() and tight.stack_at(0) != null and tight.stack_at(0).id == &"potion_healing",
		"the slot the herbs leave takes the potion (%s)" % o.why)
	# A potion stack with room takes it even when no slot is free.
	var stacked: Inventory = Inventory.new()
	stacked.add(&"potion_healing", 1, ItemDB.Grade.COMMON)
	stacked.add(&"wild_healing", 5)
	for i3: int in Config.INVENTORY_SLOTS - 2:
		stacked.add(&"sword", 1)
	check(Crafting.craft(r_heal, "miner", stacked).ok() and stacked.count_of(&"potion_healing") == 2,
		"a full inventory with a potion stack that has room")


func _check_unlock() -> void:
	var inv: Inventory = Inventory.new()
	var shown: Array[Crafting.Recipe] = Crafting.shown_recipes(Crafting.ALCHEMY, inv)
	if Config.RECIPES_UNLOCK_ON_FIRST_GET:
		check_eq(shown.size(), 0, "an empty inventory has unlocked no recipe (○ §3.5)")
		inv.add(&"wild_buff", 1)
		shown = Crafting.shown_recipes(Crafting.ALCHEMY, inv)
		check_eq(shown.size(), 2, "one buff herb unlocks both buff recipes (any grade)")
		check(shown[0].output == &"potion_buff" and shown[1].output == &"potion_buff", "the buff ones")
		inv.remove(0, 1)
		check_eq(Crafting.shown_recipes(Crafting.ALCHEMY, inv).size(), 2, "still unlocked after the herb is gone")
		check_eq(Crafting.refusal(Crafting.recipe(&"potion_healing_common"), "miner", inv), Crafting.WHY_LOCKED,
			"a locked recipe is refused")
		inv.add(&"wild_healing", 1, ItemDB.Grade.FINE)
		inv.add(&"wild_poison", 1)
		var ids: Array[StringName] = []
		for r: Crafting.Recipe in Crafting.shown_recipes(Crafting.ALCHEMY, inv):
			ids.append(r.id)
		check_eq(ids, [&"potion_healing_common", &"potion_healing_fine", &"potion_buff_common", &"potion_buff_fine",
			&"potion_poison_common", &"potion_poison_fine"] as Array[StringName], "all six in panel order")
		check(not inv.has_seen(&"potion_healing"), "seen only what was added")
		check(Crafting.copy_of(inv).has_seen(&"wild_poison"), "a trial copy knows what was seen")
	else:
		check_eq(shown.size(), 6, "the unlock switch is off: every recipe shows")


func _check_station_reach() -> void:
	var d: WorldData = WorldData.new(Vector2i(30, 20))
	d.put_placeable(Rect2i(10, 10, 3, 1), WorldData.PLACEABLE_ALCHEMY)
	var reach: int = Config.STATION_REACH_TILES
	var near: int = 0
	var far: int = 0
	for y: int in range(4, 17):
		for x: int in range(3, 20):
			var c: Vector2i = Vector2i(x, y)
			if Movement.is_blocked(d, c):
				continue
			var at: Crafting.StationAt = Crafting.station_near(d, Arena.spawn_feet(c))
			var want: bool = Crafting.tiles_to(c, Rect2i(10, 10, 3, 1)) <= reach
			if want:
				near += 1
			else:
				far += 1
			if not check_eq(at != null, want, "tile %s at the table: %s" % [c, want]):
				return
			if at != null:
				check(at.kind == Crafting.ALCHEMY and at.rect == Rect2i(10, 10, 3, 1), "the table's footprint")
	check(near > 20 and far > 100, "tiles near / far (%d / %d)" % [near, far])
	# Two tables: the nearer one.
	d.put_placeable(Rect2i(16, 10, 3, 1), WorldData.PLACEABLE_ALCHEMY)
	var mid: Crafting.StationAt = Crafting.station_near(d, Arena.spawn_feet(Vector2i(15, 11)))
	check(mid != null and mid.rect.position == Vector2i(16, 10), "the nearer of two tables")
	check(Crafting.still_at(d, Arena.spawn_feet(Vector2i(15, 11)), mid), "still at it")
	check(not Crafting.still_at(d, Arena.spawn_feet(Vector2i(25, 11)), mid), "walked away")
	d.put_placeable(Rect2i(16, 10, 3, 1), WorldData.PLACEABLE_NONE)
	check(not Crafting.still_at(d, Arena.spawn_feet(Vector2i(15, 11)), mid), "that table gone")
	check(Crafting.station_near(null, Vector2.ZERO) == null, "no data")
	# M6-fix: a footprint of any size within reach counts (M6b's window was sized for 3 tiles and looked only at the
	# top-left tile: a 5-wide one 2 tiles off its east end was missed).
	var wide: WorldData = WorldData.new(Vector2i(30, 20))
	wide.put_placeable(Rect2i(10, 10, 5, 1), WorldData.PLACEABLE_ALCHEMY)
	var east: Vector2 = Arena.spawn_feet(Vector2i(16, 10))
	var w_at: Crafting.StationAt = Crafting.station_near(wide, east)
	check(w_at != null and w_at.rect == Rect2i(10, 10, 5, 1), "a 5-tile footprint, the feet 2 tiles off its east end: at it")
	check(Crafting.station_near(wide, Arena.spawn_feet(Vector2i(17, 10))) == null, "3 tiles off: not")
	# station_of_kind_near: only that kind (the host's CRAFT check: the recipe's station, whatever is nearer).
	check(Crafting.station_of_kind_near(wide, east, Crafting.ALCHEMY) != null, "of its kind: found")
	check(Crafting.station_of_kind_near(wide, east, &"anvil") == null, "of another kind: none")
	# Two as near: the first footprint row by row; still_at stays with the one the panel opened at.
	var two: WorldData = WorldData.new(Vector2i(30, 20))
	two.put_placeable(Rect2i(10, 10, 3, 1), WorldData.PLACEABLE_ALCHEMY)
	two.put_placeable(Rect2i(14, 10, 3, 1), WorldData.PLACEABLE_ALCHEMY)
	var between: Vector2 = Arena.spawn_feet(Vector2i(13, 11))
	var first: Crafting.StationAt = Crafting.station_near(two, between)
	check(first != null and first.rect.position == Vector2i(10, 10), "two tables as near: the first row by row")
	var opened: Crafting.StationAt = Crafting.station_near(two, Arena.spawn_feet(Vector2i(17, 11)))
	check(opened != null and opened.rect.position == Vector2i(14, 10), "the east one from its east side")
	check(Crafting.still_at(two, between, opened), "still at the east one where the west one is as near")
	check(not Crafting.still_at(two, Arena.spawn_feet(Vector2i(10, 12)), opened), "away from it (at the west one): not")
	var moved: Crafting.StationAt = Crafting.StationAt.new()
	moved.kind = opened.kind
	moved.rect = opened.rect
	moved.map = Config.MAP_DUNGEON
	check(not Crafting.still_at(two, between, moved), "another map: not")


func _check_table_placement() -> void:
	var d: WorldData = WorldData.new(Vector2i(30, 20))
	d.map_id = Config.MAP_DUNGEON
	var feet: Vector2 = Arena.spawn_feet(Vector2i(10, 10))
	var inv: Inventory = inv_with([[&"alchemy_table", 3]])
	check_eq(WorldItems.placeable_in(inv, 0), WorldData.PLACEABLE_ALCHEMY, "the item puts the table down")
	check_eq(WorldItems.place_rect(WorldData.PLACEABLE_ALCHEMY, Vector2i(10, 11)), Rect2i(9, 11, 3, 1),
		"the target tile is the middle of the footprint's bottom row")
	check_eq(WorldItems.place_rect(WorldData.PLACEABLE_TORCH, Vector2i(10, 11)), Rect2i(10, 11, 1, 1), "a torch: its tile")
	# Aimed east, the footprint would cover the placer's own feet tile.
	check_eq(WorldItems.place(d, feet, inv, 0, Vector2i(11, 10)).why, WorldItems.WHY_BODY, "not on the placer's feet")
	check_eq(WorldItems.place(d, feet, inv, 0, Vector2i(10, 13)).why, WorldItems.WHY_REACH, "out of reach")
	check_eq(WorldItems.place(d, Arena.spawn_feet(Vector2i(1, 10)), inv, 0, Vector2i(0, 11)).why, WorldItems.WHY_OUTSIDE,
		"a footprint off the map's edge")
	var wall_at: WorldData = WorldData.new(Vector2i(30, 20))
	wall_at.set_value(WorldData.Layer.WALL, Vector2i(11, 11), Walls.pack(Walls.KIND_ROCK, 0))
	check_eq(WorldItems.place(wall_at, feet, inv, 0, Vector2i(10, 11)).why, WorldItems.WHY_NOT_OPEN, "a wall in the footprint")
	var plant: WorldData = WorldData.new(Vector2i(30, 20))
	plant.set_value(WorldData.Layer.VEGETATION, Vector2i(9, 11), WorldItems.value_of(&"wild_buff"))
	check_eq(WorldItems.place(plant, feet, inv, 0, Vector2i(10, 11)).why, WorldItems.WHY_NOT_OPEN, "a gatherable in it")
	var dropped: WorldData = WorldData.new(Vector2i(30, 20))
	var dr: WorldData.Drop = WorldData.Drop.new(1, &"stone_a", 2, 0, Vector2i(11 * 16 + 8, 11 * 16 + 8))
	dropped.drops[dr.id] = dr
	check_eq(WorldItems.place(dropped, feet, inv, 0, Vector2i(10, 11)).why, WorldItems.WHY_NOT_OPEN,
		"a drop under it (it could not be picked up)")
	var other: Array[Vector2] = [Arena.spawn_feet(Vector2i(11, 11))]
	check_eq(WorldItems.place(d, feet, inv, 0, Vector2i(10, 11), other).why, WorldItems.WHY_BODY, "not on someone else")
	var aside: Array[Vector2] = [Arena.spawn_feet(Vector2i(13, 11))]
	var o: WorldItems.Outcome = WorldItems.place(d, feet, inv, 0, Vector2i(10, 11), aside)
	check(o.ok() and o.edits.size() == 3, "south of the feet, someone beside it: placed (%s)" % o.why)
	for e: EditLog.WorldEdit in o.edits:
		EditLog.apply_to_data(d, e)
	check_eq(d.footprints(WorldData.PLACEABLE_ALCHEMY), [Rect2i(9, 11, 3, 1)] as Array[Rect2i], "its footprint")
	check_eq(inv.count_of(&"alchemy_table"), 2, "one used")
	# Never touching another table (footprint_at would merge them): one tile between is needed.
	var near_feet: Vector2 = Arena.spawn_feet(Vector2i(13, 10))
	check_eq(WorldItems.place(d, near_feet, inv, 0, Vector2i(13, 11)).why, WorldItems.WHY_TOO_CLOSE, "right beside it")
	check_eq(WorldItems.place(d, Arena.spawn_feet(Vector2i(13, 11)), inv, 0, Vector2i(13, 12)).why, WorldItems.WHY_TOO_CLOSE,
		"diagonally touching")
	var two_off: Vector2 = Arena.spawn_feet(Vector2i(14, 10))
	var ok2: WorldItems.Outcome = WorldItems.place(d, two_off, inv, 0, Vector2i(14, 11))
	check(ok2.ok(), "one tile apart: placed (%s)" % ok2.why)
	check_eq(WorldItems.place(d, feet, inv, 0, Vector2i(10, 11)).why, WorldItems.WHY_NOT_OPEN, "not on a table")
	# The torch is unchanged by M6a: one tile, does not block, may stand next to a table.
	var t_inv: Inventory = inv_with([[&"torch", 2]])
	var t: WorldItems.Outcome = WorldItems.place(d, feet, t_inv, 0, Vector2i(11, 10))
	check(t.ok() and t.edits.size() == 1, "a torch beside the table and on the placer's side (%s)" % t.why)


## M6-fix: a table may not cover a feet point where players appear without walking there (WorldItems.reserved_feet,
## WHY_RESERVED): the arrival below the way in on each map (seed 1: the surface entrance, the dungeon's exit stairs)
## and the altar's nine spawn slots. For each point, every footprint that covers its feet box, tried by a placer on
## each free tile next to the target: some refused as reserved, none placed. Before, a table went down on the
## dungeon's arrival and on every spawn slot (the player who then arrived stood inside it).
func _check_reserved_spots() -> void:
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var on_surface: Array[Vector2] = WorldItems.reserved_feet(surface)
	var below: Array[Vector2] = WorldItems.reserved_feet(dungeon)
	check_eq(on_surface.size(), 1 + Config.SPAWN_SLOTS.size(), "surface: the arrival below the entrance and the spawn slots")
	check_eq(below.size(), 1, "dungeon: the arrival below the exit stairs")
	if on_surface.is_empty() or below.is_empty():
		return
	check_eq(on_surface[0], DungeonGen.arrival_below(SurfaceGen.entrance_rect(surface)), "the surface's arrival point")
	check_eq(on_surface[1], surface.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]), "spawn slot 0 (GameWorld.spawn_point)")
	check_eq(below[0], DungeonGen.arrival_point(dungeon), "the dungeon's arrival point")
	check(WorldItems.reserved_feet(WorldData.new(Vector2i(30, 20))).is_empty(), "a map with no way in and no altar: none")
	var inv: Inventory = inv_with([[&"alchemy_table", 1]])
	var bad: PackedStringArray = []
	var points: int = 0
	var refused: int = 0
	for d: WorldData in [surface, dungeon]:
		for r: Vector2 in WorldItems.reserved_feet(d):
			points += 1
			if not Movement.can_stand(d, r):
				bad.append("%s %s: cannot stand there" % [Config.MAP_NAMES[d.map_id], r])
				continue
			var box: Rect2 = Movement.feet_box(r)
			var f: Vector2i = Aim.feet_cell(r)
			var reserved: int = 0
			for ty: int in range(f.y - 1, f.y + 2):
				for tx: int in range(f.x - 2, f.x + 3):
					var t: Vector2i = Vector2i(tx, ty)
					var rect: Rect2i = WorldItems.place_rect(WorldData.PLACEABLE_ALCHEMY, t)
					var px: Rect2 = Rect2(Vector2(rect.position * Config.TILE), Vector2(rect.size * Config.TILE))
					if not px.intersects(box):
						continue
					for o: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1),
							Vector2i(-1, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
						var pf: Vector2 = Arena.spawn_feet(t + o)
						if px.intersects(Movement.feet_box(pf)) or not Movement.can_stand(d, pf):
							continue
						var why: String = WorldItems.place(d, pf, inv, 0, t).why
						if why == WorldItems.WHY_RESERVED:
							reserved += 1
						elif why.is_empty():
							bad.append("%s %s: placed on target %s" % [Config.MAP_NAMES[d.map_id], r, t])
			if reserved == 0:
				bad.append("%s %s: no try refused as reserved" % [Config.MAP_NAMES[d.map_id], r])
			refused += reserved
	check(bad.is_empty() and points == 11, "every point where players appear (%d) kept clear: %d tries refused as reserved, none placed %s" % [
		points, refused, bad])
	check_eq(inv.count_of(&"alchemy_table"), 1, "nothing used")
	# Two tiles south of the dungeon's arrival (its feet clear) the same table goes down.
	var arrive: Vector2i = Aim.feet_cell(below[0])
	var near_ok: WorldItems.Outcome = WorldItems.place(dungeon, Arena.spawn_feet(arrive + Vector2i(0, 1)), inv, 0, arrive + Vector2i(0, 2))
	check(near_ok.ok(), "two tiles south of the arrival: placed (%s)" % near_ok.why)


func _check_table_blocks() -> void:
	var d: WorldData = WorldData.new(Vector2i(30, 20))
	d.map_id = Config.MAP_DUNGEON
	d.put_placeable(Rect2i(9, 11, 3, 1), WorldData.PLACEABLE_ALCHEMY)
	check(WorldData.placeable_blocks(WorldData.PLACEABLE_ALCHEMY), "the table blocks")
	for x: int in range(9, 12):
		check(Movement.is_blocked(d, Vector2i(x, 11)) and Combat.blocks_line(d, Vector2i(x, 11)), "tile %d,11 blocks" % x)
	check(not Movement.is_blocked(d, Vector2i(10, 10)), "the tile behind it does not (its art stands over it)")
	# Walking south into it stops flush on its top edge; a shot stops on it.
	var p: PlayerSim = PlayerSim.new()
	p.pos = Arena.spawn_feet(Vector2i(10, 9))
	for t: int in 60:
		p.step(d, Vector2i(0, 1), -1, -1, Vector2i.ZERO, TICK)
	check_eq(p.pos.y, 11.0 * Config.TILE, "walking south stops flush against it")
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	var h: HereticSim = a.spawn_heretic(Arena.spawn_feet(Vector2i(10, 14)))
	var shooter: Player = Player.new()
	_nodes.append(shooter)
	shooter.setup(d, "archer", Arena.spawn_feet(Vector2i(10, 8)))
	a.player_attack(shooter, &"bow", Combat.aim_code(Vector2(0, 1)))
	var none: Array[Player] = []
	for t2: int in 60:
		a.step(none)
	check(a.stat("shot_wall") == 1 and h.hp == Config.HERETIC_HP, "an arrow stops on the table")


func _check_table_drawn() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var feet: Vector2 = world.data.altar_center_px() + Vector2(0, 80)
	var inv: Inventory = inv_with([[&"alchemy_table", 1]])
	var o: WorldItems.Outcome = WorldItems.place(world.data, feet, inv, 0, Aim.feet_cell(feet) + Vector2i(0, 1))
	if not check(o.ok(), "placed south of the altar (%s)" % o.why):
		return
	for e: EditLog.WorldEdit in o.edits:
		world.apply_edit(e)
	var rect: Rect2i = world.data.footprints(WorldData.PLACEABLE_ALCHEMY)[0]
	var node: Node2D = world.fixtures.nodes.get(rect.position, null)
	if not check(node != null, "the table is drawn"):
		return
	check_eq(node.position, FixtureView.foot_of(rect), "sorted at its footprint's bottom edge")
	var sprite: Sprite2D = node.get_node(^"Sprite") as Sprite2D
	check(sprite.texture == FixtureView.TABLE, "04-env alchemy_table_v05")
	var top_left: Vector2 = node.position + sprite.position
	check_eq(Vector2i(top_left), FixtureView.table_origin(rect), "its art centred on the footprint")
	check_eq(int(top_left.y) + FixtureView.TABLE_BOTTOM_ROW, rect.end.y * Config.TILE - 1, "its opaque bottom row on the footprint's bottom")
	check_eq(world.fixtures.verify()["mismatches"], 0, "fixture view = data")
	check(node.get_parent() == world.entities, "y-sorted with the characters")


## main.tscn offline: put the table down, Tab at it opens the panel, keys and a click craft, it closes.
func _check_main_tab() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null and p.potions_on, "main has an offline player with potions on"):
		return
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	# Tab away from any station: the inventory (M2a).
	main.toggle_tab()
	check(main.hud.open and not main.crafting_open(), "Tab with no station: the inventory")
	main.toggle_tab()
	check(not main.hud.open, "Tab again hides it")
	# The table goes down south of the player (a click with it selected).
	var feet: Vector2 = main.world.data.altar_center_px() + Vector2(0, 80)
	p.teleport(feet)
	p.inventory.add(&"alchemy_table", 1)
	var slot: int = 0
	for i: int in p.inventory.hotbar_size:
		if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == &"alchemy_table":
			slot = i
	p.inventory.select(slot)
	var south: Vector2 = feet + Vector2(0, 16)
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, south, true, true, true, TICK)
	var rects: Array[Rect2i] = main.world.data.footprints(WorldData.PLACEABLE_ALCHEMY)
	if not check_eq(rects.size(), 1, "a click put the table down"):
		return
	check(main.world.fixtures.nodes.has(rects[0].position), "and it is drawn")
	# Tab at it: the crafting panel (and the inventory), the player stands.
	main.toggle_tab()
	check(main.crafting_open() and main.hud.open and p.ui_locked, "Tab at the table: crafting panel open, the player stands")
	check_eq(main.hud.crafting.recipes.size(), 0 if Config.RECIPES_UNLOCK_ON_FIRST_GET else 6, "nothing unlocked yet")
	p.inventory.add(&"wild_healing", 5)
	p.inventory.add(&"wild_poison", 2)
	check_eq(main.hud.crafting.recipes.size(), 4, "the herbs unlocked four (the panel follows the inventory)")
	var before: Vector2 = p.sim_position
	for t: int in 20:
		p.begin_tick()
		p.tick_controls(Vector2i(1, 0), south, true, true, true, TICK, true, true, true)
		main.step_combat(TICK)
	check_eq(p.sim_position, before, "no walking, dashing or using while the panel is open")
	check_eq(p.action_anim, -1, "no action")
	# Keys: S moves down a row, F crafts the selected one (the paladin: COMMON healing only).
	main._crafting_input(_action_event(&"move_down"))
	check_eq(main.hud.crafting.selected, 1, "S: the next row")
	main._crafting_input(_action_event(&"move_up"))
	main._crafting_input(_action_event(&"interact"))
	check_eq(p.inventory.count_of(&"potion_healing", ItemDB.Grade.COMMON), 1, "F crafts the selected row")
	check_eq(p.inventory.count_of(&"wild_healing"), 3, "two herbs used")
	main.hud.crafting.selected = 2  # poison, the herbalist's
	main._crafting_input(_action_event(&"interact"))
	check_eq(p.inventory.count_of(&"potion_poison"), 0, "the paladin may not brew poison")
	check_eq(p.inventory.count_of(&"wild_poison"), 2, "nothing used")
	# A click on the first row crafts it.
	var row: Rect2i = main.hud.crafting.row_rect(0)
	check_eq(main.hud.crafting.click_at(Vector2(row.get_center())), 0, "a click on row 1")
	check_eq(p.inventory.count_of(&"potion_healing", ItemDB.Grade.COMMON), 2, "the click crafted it")
	check_eq(main.hud.crafting.click_at(Vector2(main.hud.crafting.panel_rect().position) - Vector2(10, 10)), -1,
		"a click outside the panel crafts nothing")
	# Tab closes it; the player walks again.
	main._crafting_input(_action_event(&"toggle_inventory"))
	check(not main.crafting_open() and not main.hud.open and not p.ui_locked, "Tab closes the panel")
	# Walking away (reach) closes it.
	main.toggle_tab()
	check(main.crafting_open(), "open again")
	p.teleport(feet + Vector2(0, -16 * (Config.STATION_REACH_TILES + 3)))
	main._physics_process(TICK)
	check(not main.crafting_open() and not p.ui_locked, "too far from the table: closed")
	main.toggle_tab()
	check(main.hud.open and not main.crafting_open(), "Tab there: the inventory")
	main.toggle_tab()
	# Going down closes it.
	p.teleport(feet)
	main.toggle_tab()
	p.take_hit(Config.PLAYER_HP_MAX)
	main._physics_process(TICK)
	check(not main.crafting_open(), "down: closed")


static func _action_event(action: StringName) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


## A session: M6a's host refused a client's alchemy table and took a potion's USE for "not a tool"; M6b places the
## table (an edit on the member's map) and takes the USE as a drink (refused at full HP, the drink action below it).
func _check_session_table() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"CraftTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var start: Vector2 = world.data.altar_center_px() + Vector2(0, 80)
	var m: NetMember = s.add_member(2, 7, "herbalist", start, RigData.Dir.SOUTH)
	m.gate = InputGate.new()
	m.player.inventory.add(&"alchemy_table", 1)
	m.player.inventory.add(&"potion_healing", 2)
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	f.op = NetProtocol.Op.USE
	f.slot = 0
	f.cell = Aim.feet_cell(start) + Vector2i(0, 1)
	f.map = Config.MAP_SURFACE
	m.player.begin_tick()
	host.run_frame(m, f)
	check_eq(m.ops_refused.size(), 0, "M6b: the host places the table in a session (%s)" % m.ops_refused)
	check_eq(world.data.footprints(WorldData.PLACEABLE_ALCHEMY).size(), 1, "M6b: the table stands on the host's map")
	check_eq(s.log_for(Config.MAP_SURFACE).size(), Config.ALCHEMY_FOOTPRINT.x * Config.ALCHEMY_FOOTPRINT.y,
		"one edit per footprint tile in the map's log")
	var drink: NetProtocol.InputFrame = NetProtocol.InputFrame.new(2, Vector2i.ZERO)
	drink.op = NetProtocol.Op.USE
	drink.slot = 1
	drink.cell = Aim.feet_cell(start) + Vector2i(0, 1)
	drink.map = Config.MAP_SURFACE
	m.player.begin_tick()
	host.run_frame(m, drink)
	check_eq(m.refused(Potions.WHY_FULL_HP), 1, "M6b: a potion's USE is a drink: at full HP refused")
	check_eq(m.player.action_anim, -1, "no action")
	m.player.vitals.hp = 40
	drink.seq = 3
	m.player.begin_tick()
	host.run_frame(m, drink)
	check_eq(m.player.action_anim, Config.DRINK_ANIM, "M6b: below full HP the host starts the drink")
