extends "res://tests/base_test.gd"
## M7a, the workbench chain (offline first; ○ gameplay-design §3.5, the slice's "2~3단계" ● game-concept §12; PROVISIONAL
## README "임시값" M7a): the recipes (Config.STATION_RECIPES as written out here: stations, inputs, outputs, anyone may craft
## them), the chain (each station is made at the one before it, the workbench by hand; unlock on first get opens it step
## by step), every recipe atomic (all inputs or nothing; no room = refused; exact counts after), smelting (1 ore -> 1
## ingot), the stations' reach for Tab (each footprint size), their placement (like the alchemy table: footprint, open
## floor, nobody's feet, not where players appear, not on a growing field, not on the altar or walls; the dungeon is fine),
## their pictures (FixtureView: footprint bottom edge, centred, the relic bench's flame), main.tscn (stations placed with a
## click, Tab at each opens its panel, Tab away from every station opens the hand recipes once a log was had, crafting the
## whole chain from logs and ore), a session (the host refuses the stations and every M7 recipe until M7c) and determinism
## (the same chain twice = the same inventory and world hash).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0

## Written out here on purpose (README "임시값" M7a 작업대 체인): output -> [station, count, {input: count}].
const WANT: Dictionary[StringName, Array] = {
	&"workbench": ["hand", 1, {&"log": 4}],
	&"planks": ["workbench", 2, {&"log": 1}],
	&"anvil": ["workbench", 1, {&"stone_a": 10, &"ore_iron": 2, &"planks": 2}],
	&"storage_chest": ["workbench", 1, {&"planks": 8, &"ingot_iron": 1}],
	&"ingot_copper": ["anvil", 1, {&"ore_copper": 1}],
	&"ingot_iron": ["anvil", 1, {&"ore_iron": 1}],
	&"sword_t1": ["anvil", 1, {&"ingot_iron": 2, &"planks": 1}],
	&"bow_t1": ["anvil", 1, {&"planks": 3, &"ingot_copper": 1}],
	&"holy_light_t1": ["anvil", 1, {&"ingot_copper": 2, &"ingot_iron": 1}],
	&"pickaxe_t1": ["anvil", 1, {&"ingot_iron": 2, &"planks": 2}],
	&"sickle_t1": ["anvil", 1, {&"ingot_iron": 1, &"ingot_copper": 1, &"planks": 1}],
	&"armor_t1": ["anvil", 1, {&"ingot_iron": 3, &"ingot_copper": 1}],
	&"relic_bench": ["anvil", 1, {&"planks": 4, &"ingot_copper": 2, &"ingot_iron": 1}],
	&"torch": ["relic", 4, {&"ingot_copper": 1, &"planks": 1}],
}
## Station placeable -> footprint, written out.
const FOOTPRINTS: Dictionary[int, Vector2i] = {WorldData.PLACEABLE_WORKBENCH: Vector2i(3, 1),
	WorldData.PLACEABLE_ANVIL: Vector2i(2, 1), WorldData.PLACEABLE_RELIC: Vector2i(3, 1)}
const STATION_ITEM: Dictionary[int, StringName] = {WorldData.PLACEABLE_WORKBENCH: &"workbench",
	WorldData.PLACEABLE_ANVIL: &"anvil", WorldData.PLACEABLE_RELIC: &"relic_bench"}
const KIND_OF: Dictionary[int, StringName] = {WorldData.PLACEABLE_WORKBENCH: &"workbench",
	WorldData.PLACEABLE_ANVIL: &"anvil", WorldData.PLACEABLE_RELIC: &"relic"}

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_recipes()
	_check_chain_unlocks()
	_check_atomic()
	_check_smelting()
	_check_reach()
	_check_placement()
	await _check_drawn()
	await _check_main()
	_check_session()
	_check_determinism()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func inv_with(items: Array) -> Inventory:
	var inv: Inventory = Inventory.new()
	for e: Array in items:
		var id: StringName = e[0]
		var n: int = e[1]
		inv.add(id, n)
	return inv


static func inv_text(inv: Inventory) -> String:
	return "%s | sel %d | armor %s" % [inv.describe(), inv.selected, str(inv.armor)]


## Every input of `r` (its count) into a fresh inventory (seen, so unlocked).
static func inv_for(r: Crafting.Recipe, times: int = 1) -> Inventory:
	var inv: Inventory = Inventory.new()
	for i: Crafting.Ingredient in r.inputs:
		inv.add(i.item, i.count * times)
	return inv


func _check_recipes() -> void:
	var chain: Array[Crafting.Recipe] = []
	for r: Crafting.Recipe in Crafting.recipes():
		if r.station != Crafting.ALCHEMY and not r.is_repair() and not _is_m7b(r):  # M7b's rows: test_building.gd
			chain.append(r)
	check_eq(chain.size(), WANT.size(), "M7a: %d chain recipes" % WANT.size())
	for r: Crafting.Recipe in chain:
		if not check(WANT.has(r.id), "known chain recipe %s" % r.id):
			continue
		var w: Array = WANT[r.id]
		check_eq(String(r.station), str(w[0]), "%s made at the %s" % [r.id, w[0]])
		check_eq(r.output, r.id, "%s makes itself" % r.id)
		check_eq(r.out_count, w[1], "%s makes %d" % [r.id, w[1]])
		check_eq(r.out_grade, ItemDB.Grade.NONE, "%s no grade" % r.id)
		var ins: Dictionary = w[2]
		check_eq(r.inputs.size(), ins.size(), "%s: %d inputs" % [r.id, ins.size()])
		for i: Crafting.Ingredient in r.inputs:
			check_eq(i.count, ins.get(i.item, -1), "%s: %s x%d" % [r.id, i.item, ins.get(i.item, -1)])
			check_eq(i.grade, -1, "%s: any grade of %s" % [r.id, i.item])
		check(r.classes.is_empty(), "%s: anyone (● §3.5 tier 1 anyone's at the anvil)" % r.id)
		for c: String in Config.CLASSES:
			check(r.allows(c), "%s allowed for %s" % [r.id, c])
		check(Crafting.is_m7(r), "%s is an M7 recipe (a session refuses it)" % r.id)
		check(ItemDB.has(r.output), "%s output is an item" % r.id)
	# The chain: each station made at the one before it.
	check_eq(String(Crafting.recipe(&"workbench").station), "hand", "the workbench by hand")
	check_eq(String(Crafting.recipe(&"anvil").station), "workbench", "the anvil at the workbench")
	check_eq(String(Crafting.recipe(&"relic_bench").station), "anvil", "the relic bench at the anvil")
	for p: int in FOOTPRINTS:
		check_eq(Crafting.station_kind(p), KIND_OF[p], "%s is a station" % WorldData.PLACEABLE_NAMES[p])
		check_eq(WorldItems.footprint_of(p), FOOTPRINTS[p], "%s footprint" % WorldData.PLACEABLE_NAMES[p])
		check(WorldData.placeable_blocks(p), "%s blocks" % WorldData.PLACEABLE_NAMES[p])
		check_eq(ItemDB.get_def(STATION_ITEM[p]).place, p, "%s item puts it down" % STATION_ITEM[p])
	check(Crafting.station_kind(WorldData.PLACEABLE_CHEST).is_empty(), "the chest is no station")
	# Indices: the potions keep theirs (a CRAFT index of M6b).
	check_eq(Crafting.index_of(&"potion_poison_fine"), 5, "the potions keep their CRAFT indices")
	check_eq(Crafting.index_of(&"workbench"), 6, "the chain comes after them")
	check_eq(Crafting.recipes_for(Crafting.HAND).size(), 2, "two hand recipes (M7b: + the axe)")
	check(not Crafting.is_m7(Crafting.recipe(&"potion_healing_common")), "a potion is no M7 recipe")


## Unlock on first get (○ §3.5): nothing shows without its inputs; logs open the hand workbench, then planks; stone,
## iron ore and planks the anvil; the ingots the gear; so the chain opens step by step.
func _check_chain_unlocks() -> void:
	if not Config.RECIPES_UNLOCK_ON_FIRST_GET:
		note("RECIPES_UNLOCK_ON_FIRST_GET off: unlock steps not checked")
		return
	var inv: Inventory = Inventory.new()
	for k: StringName in [Crafting.HAND, Crafting.WORKBENCH, Crafting.ANVIL, Crafting.RELIC]:
		check_eq(Crafting.shown_recipes(k, inv).size(), 0, "empty inventory: nothing at %s" % k)
	inv.add(&"log", 1)
	check_eq(_ids(Crafting.shown_recipes(Crafting.HAND, inv)), [&"workbench"], "a log: the hand workbench")
	check_eq(_ids(Crafting.shown_recipes(Crafting.WORKBENCH, inv)), [&"planks"], "a log: planks at the workbench")
	inv.add(&"planks", 1)
	inv.add(&"stone_a", 1)
	check_eq(_ids(Crafting.shown_recipes(Crafting.WORKBENCH, inv)), [&"planks"], "no iron ore yet: no anvil")
	inv.add(&"ore_iron", 1)
	check_eq(_ids(Crafting.shown_recipes(Crafting.WORKBENCH, inv)), [&"planks", &"anvil"], "iron ore: the anvil")
	check_eq(_ids(Crafting.shown_recipes(Crafting.ANVIL, inv)), [&"ingot_iron"], "iron ore: smelting iron")
	inv.add(&"ingot_iron", 1)
	check_eq(_ids(Crafting.shown_recipes(Crafting.WORKBENCH, inv)), [&"planks", &"anvil", &"storage_chest"],
		"an iron ingot: the chest")
	check_eq(_ids(Crafting.shown_recipes(Crafting.ANVIL, inv)), [&"ingot_iron", &"sword_t1", &"pickaxe_t1"],
		"iron ingots + planks: the sword and the pickaxe")
	inv.add(&"ingot_copper", 1)
	check_eq(_ids(Crafting.shown_recipes(Crafting.ANVIL, inv)), [&"ingot_iron", &"sword_t1", &"bow_t1", &"holy_light_t1",
		&"pickaxe_t1", &"sickle_t1", &"armor_t1", &"relic_bench"], "copper ingots too: every anvil recipe but copper smelting")
	check_eq(_ids(Crafting.shown_recipes(Crafting.RELIC, inv)), [&"torch"], "the relic bench: the torch")
	inv.clear()
	check_eq(Crafting.shown_recipes(Crafting.ANVIL, inv).size(), 8, "the unlocks stay when the items are gone")


## The ids of `list` without the M7b build pieces and the axe (Config.BUILD_RECIPES: test_building.gd checks those): the
## M7a chain as this file wrote it out.
static func _ids(list: Array[Crafting.Recipe]) -> Array[StringName]:
	var out: Array[StringName] = []
	for r: Crafting.Recipe in list:
		if not _is_m7b(r):
			out.append(r.id)
	return out


static func _is_m7b(r: Crafting.Recipe) -> bool:
	for row: Array in Config.BUILD_RECIPES:
		var out_item: StringName = row[1]
		if r.id == out_item:
			return true
	return false


## Every chain recipe: with its inputs exactly, it makes its output and takes every input (nothing else changes); one
## input short of any one = missing inputs, nothing changes; a full inventory whose inputs free no slot = no room.
func _check_atomic() -> void:
	for r: Crafting.Recipe in Crafting.recipes():
		if not Crafting.is_m7(r) or r.is_repair():
			continue
		var inv: Inventory = inv_for(r)
		inv.add(&"mushroom_a", 3)  # something the recipe does not touch
		var o: Crafting.Outcome = Crafting.craft(r, "miner", inv)
		check(o.ok(), "%s crafts from its inputs (%s)" % [r.id, o.why])
		for i: Crafting.Ingredient in r.inputs:
			check_eq(inv.count_of(i.item), 0 if i.item != r.output else r.out_count, "%s used every %s" % [r.id, i.item])
		check_eq(inv.count_of(r.output), r.out_count, "%s: %d out" % [r.id, r.out_count])
		check_eq(inv.count_of(&"mushroom_a"), 3, "%s: nothing else touched" % r.id)
		var made: ItemStack = null
		for s: ItemStack in inv.slots:
			if s != null and s.id == r.output:
				made = s
		if made != null and made.max_durability() > 0:
			check_eq(made.durability, made.max_durability(), "%s comes out at full durability" % r.id)
		for short: Crafting.Ingredient in r.inputs:
			var inv2: Inventory = inv_for(r)
			for slot: int in range(inv2.size() - 1, -1, -1):
				var st: ItemStack = inv2.stack_at(slot)
				if st != null and st.id == short.item:
					inv2.remove(slot, 1)
					break
			var before: String = inv_text(inv2)
			var o2: Crafting.Outcome = Crafting.craft(r, "paladin", inv2)
			check_eq(o2.why, Crafting.WHY_MISSING, "%s one %s short: missing inputs" % [r.id, short.item])
			check_eq(inv_text(inv2), before, "%s one %s short: nothing changed" % [r.id, short.item])
		# No room: every slot full; the inputs in full stacks that stay non-empty after the craft (no slot frees).
		var full: Inventory = Inventory.new()
		for i2: Crafting.Ingredient in r.inputs:
			full.add(i2.item, ItemDB.get_def(i2.item).stack_max)
		while full.free_slots() > 0:
			full.add(&"herb_clump", Config.STACK_GATHERABLE)
		var out_room: int = full.room_for(r.output)
		var before_full: String = inv_text(full)
		var o3: Crafting.Outcome = Crafting.craft(r, "cleric", full)
		if out_room >= r.out_count:
			check(o3.ok(), "%s: room in an output stack (%s)" % [r.id, o3.why])
		else:
			check_eq(o3.why, Crafting.WHY_NO_ROOM, "%s in a full inventory: no room" % r.id)
			check_eq(inv_text(full), before_full, "%s in a full inventory: nothing changed" % r.id)
	# Locked: the inputs never seen (a copy without `seen`).
	var r2: Crafting.Recipe = Crafting.recipe(&"sword_t1")
	var locked: Inventory = Crafting.copy_of(inv_for(r2))
	locked.seen.clear()
	check_eq(Crafting.craft(r2, "paladin", locked).why, Crafting.WHY_LOCKED if Config.RECIPES_UNLOCK_ON_FIRST_GET else "",
		"never had the ingots: locked")


## Smelting: one ore -> one ingot at the anvil, each kind its own; a stack of ten smelts one at a time.
func _check_smelting() -> void:
	var inv: Inventory = inv_with([[&"ore_copper", 10], [&"ore_iron", 3]])
	var cu: Crafting.Recipe = Crafting.recipe(&"ingot_copper")
	var fe: Crafting.Recipe = Crafting.recipe(&"ingot_iron")
	check_eq(String(cu.station), "anvil", "copper smelts at the anvil (no furnace)")
	for i: int in 10:
		check(Crafting.craft(cu, "archer", inv).ok(), "copper smelt %d" % (i + 1))
	check_eq(Crafting.craft(cu, "archer", inv).why, Crafting.WHY_MISSING, "the eleventh: out of ore")
	check_eq(inv.count_of(&"ingot_copper"), 10, "ten copper ingots")
	check_eq(inv.count_of(&"ore_copper"), 0, "no copper ore left")
	check_eq(inv.count_of(&"ore_iron"), 3, "the iron ore untouched")
	check(Crafting.craft(fe, "herbalist", inv).ok(), "iron smelts")
	check_eq([inv.count_of(&"ingot_iron"), inv.count_of(&"ore_iron")], [1, 2], "1 iron ore -> 1 iron ingot")


## Tab reach for every station (its footprint size): feet tiles within Config.STATION_REACH_TILES of the footprint (here:
## a written-out Chebyshev distance) find it, one more do not; between two stations the nearest; the hand "station".
func _check_reach() -> void:
	for p: int in FOOTPRINTS:
		var d: WorldData = WorldData.new(Vector2i(24, 18))
		var rect: Rect2i = Rect2i(Vector2i(10, 8), FOOTPRINTS[p])
		d.put_placeable(rect, p)
		var wrong: int = 0
		for y: int in range(2, 16):
			for x: int in range(2, 22):
				var c: Vector2i = Vector2i(x, y)
				if rect.has_point(c):
					continue
				var dx: int = maxi(maxi(rect.position.x - x, x - (rect.end.x - 1)), 0)
				var dy: int = maxi(maxi(rect.position.y - y, y - (rect.end.y - 1)), 0)
				var want: bool = maxi(dx, dy) <= Config.STATION_REACH_TILES
				var at: Crafting.StationAt = Crafting.station_near(d, Arena.spawn_feet(c))
				if (at != null) != want or (at != null and (at.kind != KIND_OF[p] or at.rect != rect)):
					wrong += 1
		check_eq(wrong, 0, "%s: reach over 20x14 tiles" % WorldData.PLACEABLE_NAMES[p])
		check(Crafting.still_at(d, Arena.spawn_feet(Vector2i(10, 10)), Crafting.station_near(d, Arena.spawn_feet(Vector2i(10, 10)))),
			"%s: still at it" % WorldData.PLACEABLE_NAMES[p])
	# Three stations in a row (different kinds touch): the nearest opens; a kind is found even when another is nearer.
	var row: WorldData = WorldData.new(Vector2i(24, 18))
	row.put_placeable(Rect2i(5, 8, 3, 1), WorldData.PLACEABLE_WORKBENCH)
	row.put_placeable(Rect2i(8, 8, 2, 1), WorldData.PLACEABLE_ANVIL)
	row.put_placeable(Rect2i(10, 8, 3, 1), WorldData.PLACEABLE_RELIC)
	check_eq(row.footprint_at(Vector2i(8, 8)), Rect2i(8, 8, 2, 1), "touching stations of other kinds keep their footprints")
	var feet: Vector2 = Arena.spawn_feet(Vector2i(9, 9))
	check_eq(Crafting.station_near(row, feet).kind, Crafting.ANVIL, "south of the anvil: the anvil's panel")
	check_eq(Crafting.station_near(row, Arena.spawn_feet(Vector2i(8, 9))).kind, Crafting.WORKBENCH,
		"between two as near: the one whose footprint comes first")
	check_eq(Crafting.station_of_kind_near(row, feet, Crafting.WORKBENCH).rect, Rect2i(5, 8, 3, 1), "the workbench is in reach too")
	check_eq(Crafting.station_of_kind_near(row, feet, Crafting.RELIC).rect, Rect2i(10, 8, 3, 1), "and the relic bench")
	check(Crafting.station_of_kind_near(row, Arena.spawn_feet(Vector2i(20, 15)), Crafting.ANVIL) == null, "far: none")
	var hand: Crafting.StationAt = Crafting.station_of_kind_near(row, Arena.spawn_feet(Vector2i(20, 15)), Crafting.HAND)
	check(hand != null and hand.kind == Crafting.HAND and Crafting.still_at(row, Arena.spawn_feet(Vector2i(1, 1)), hand),
		"the hand station is wherever the player is")
	var other_map: WorldData = WorldData.new(Vector2i(8, 8))
	other_map.map_id = Config.MAP_DUNGEON
	check(not Crafting.still_at(other_map, Arena.spawn_feet(Vector2i(1, 1)), hand), "but not on another map")


## Placement of the stations (WorldItems.place, the alchemy table's rule): the footprint is the target tile's bottom
## row middle; on the map, open floor (no wall, placeable, growing thing, drop), nobody's feet, not where players appear
## (the altar's spawn slots, the arrival), not touching another of its kind (other kinds may touch); the dungeon is fine.
func _check_placement() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var centre: Vector2 = data.altar_center_px()
	for p: int in FOOTPRINTS:
		var id: StringName = STATION_ITEM[p]
		# South of the altar, row 51 (inside the light, clear of the spawn slots).
		var c: Vector2i = Vector2i(63, 51)
		var feet: Vector2 = Arena.spawn_feet(c + Vector2i(0, 1))
		var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		var inv: Inventory = inv_with([[id, 2]])
		var o: WorldItems.Outcome = WorldItems.place(d, feet, inv, 0, c)
		if not check(o.ok(), "%s placed south of the altar (%s)" % [id, o.why]):
			continue
		check_eq(o.edits.size(), FOOTPRINTS[p].x * FOOTPRINTS[p].y, "%s: one edit per footprint tile" % id)
		var rect: Rect2i = WorldItems.place_rect(p, c)
		check_eq(rect, Rect2i(Vector2i(c.x - FOOTPRINTS[p].x / 2, c.y), FOOTPRINTS[p]), "%s: the bottom row's middle is the target" % id)
		for e: EditLog.WorldEdit in o.edits:
			EditLog.apply_to_data(d, e)
		check_eq(inv.count_of(id), 1, "%s: one used" % id)
		check_eq(d.footprint_at(c), rect, "%s stands on its footprint" % id)
		# Touching another of its kind: refused; one tile apart: fine.
		var next_c: Vector2i = Vector2i(rect.end.x + FOOTPRINTS[p].x / 2, c.y)
		check_eq(WorldItems.place(d, Arena.spawn_feet(next_c + Vector2i(0, 1)), inv, 0, next_c).why, WorldItems.WHY_TOO_CLOSE,
			"%s touching another" % id)
		# On the altar, a wall (dungeon), a gatherable, a crop, a drop, someone's feet, a spawn slot.
		var on_altar: Vector2i = data.altar_rect.position + Vector2i(1, 2)
		check_eq(WorldItems.place(data, Arena.spawn_feet(on_altar + Vector2i(0, 1)), inv_with([[id, 1]]), 0, on_altar).why,
			WorldItems.WHY_NOT_OPEN, "%s on the altar" % id)
		var plants: Array[Vector2i] = WorldItems.gatherable_cells(data)
		var g: Vector2i = plants[0]
		check_eq(WorldItems.place(data, Arena.spawn_feet(g + Vector2i(0, 1)), inv_with([[id, 1]]), 0, g).why,
			WorldItems.WHY_NOT_OPEN, "%s on a gatherable" % id)
		var crop_d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		crop_d.set_value(WorldData.Layer.FLOOR, c, Terrain.SOIL)
		crop_d.set_value(WorldData.Layer.VEGETATION, c, Farming.Field.new(Farming.KIND_HEALING, 2).value())
		check_eq(WorldItems.place(crop_d, feet, inv_with([[id, 1]]), 0, c).why, WorldItems.WHY_NOT_OPEN, "%s on a crop" % id)
		var dry_d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		dry_d.set_value(WorldData.Layer.FLOOR, c, Terrain.SOIL)
		check(WorldItems.place(dry_d, feet, inv_with([[id, 1]]), 0, c).ok(), "%s on dry empty soil: fine (no crop)" % id)
		var drop_d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		drop_d.drops[1] = WorldData.Drop.new(1, &"stone_a", 1, 0, c * Config.TILE + Vector2i(8, 8))
		check_eq(WorldItems.place(drop_d, feet, inv_with([[id, 1]]), 0, c).why, WorldItems.WHY_NOT_OPEN, "%s on a drop" % id)
		var body: Array[Vector2] = [Arena.spawn_feet(c)]
		check_eq(WorldItems.place(data, feet, inv_with([[id, 1]]), 0, c, body).why, WorldItems.WHY_BODY, "%s on someone" % id)
		# Every spawn slot: the footprints that cover its feet box are refused.
		var refused: int = 0
		var placed: int = 0
		for o_slot: Vector2i in Config.SPAWN_SLOTS:
			var spot: Vector2 = centre + Vector2(o_slot)
			var t: Vector2i = Aim.feet_cell(spot)
			for dx: int in range(-FOOTPRINTS[p].x, FOOTPRINTS[p].x + 1):
				var tc: Vector2i = t + Vector2i(dx, 0)
				var r: Rect2i = WorldItems.place_rect(p, tc)
				var px: Rect2 = Rect2(Vector2(r.position * Config.TILE), Vector2(r.size * Config.TILE))
				if not px.intersects(Movement.feet_box(spot)):
					continue
				var placer: Vector2 = Arena.spawn_feet(tc + Vector2i(0, 1))
				var oo: WorldItems.Outcome = WorldItems.place(data, placer, inv_with([[id, 1]]), 0, tc)
				if oo.why == WorldItems.WHY_RESERVED:
					refused += 1
				elif oo.ok():
					placed += 1
		check(refused > 0 and placed == 0, "%s never covers a spawn slot (%d refused, %d placed)" % [id, refused, placed])
	# The dungeon: open floor near the arrival is fine (stations work anywhere; only the chest needs the light).
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var arrival: Vector2 = DungeonGen.arrival_below(DungeonGen.exit_rect(dun))
	var ok_any: bool = false
	for dy: int in range(1, 6):
		var t2: Vector2i = Aim.feet_cell(arrival) + Vector2i(0, dy)
		var placer2: Vector2 = Arena.spawn_feet(t2 + Vector2i(0, 1))
		if WorldItems.place(dun, placer2, inv_with([[&"anvil", 1]]), 0, t2).ok():
			ok_any = true
			break
	check(ok_any, "an anvil goes down in the dungeon")
	var wall: Vector2i = Vector2i(0, 0)
	check_eq(WorldItems.place(dun, Arena.spawn_feet(Vector2i(1, 2)), inv_with([[&"anvil", 1]]), 0, Vector2i(1, 1)).why,
		WorldItems.WHY_NOT_OPEN, "not into the dungeon's border wall (%s)" % wall)


## The pictures: each station on its footprint's bottom edge, centred, its opaque bottom row on the footprint's last
## pixel row (measured from the picture here, not FixtureView's constant), the relic bench's flame unshaded at (37, -4).
func _check_drawn() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var x: int = 59
	for p: int in [WorldData.PLACEABLE_WORKBENCH, WorldData.PLACEABLE_ANVIL, WorldData.PLACEABLE_RELIC]:
		var rect: Rect2i = Rect2i(Vector2i(x, 51), FOOTPRINTS[p])
		x += FOOTPRINTS[p].x
		for c: Vector2i in _tiles(rect):
			world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, p))
		var node: Node2D = world.fixtures.nodes.get(rect.position, null)
		if not check(node != null, "%s drawn" % WorldData.PLACEABLE_NAMES[p]):
			continue
		check_eq(node.position, FixtureView.foot_of(rect), "%s sorted at its footprint's bottom edge" % WorldData.PLACEABLE_NAMES[p])
		check(node.get_parent() == world.entities, "%s y-sorted with the characters" % WorldData.PLACEABLE_NAMES[p])
		var sprite: Sprite2D = node.get_node(^"Sprite") as Sprite2D
		var img: Image = LightGen.to_rgba8(sprite.texture.get_image())
		var bottom: int = -1
		for yy: int in img.get_height():
			for xx: int in img.get_width():
				if img.get_pixel(xx, yy).a8 >= 128:
					bottom = maxi(bottom, yy)
		var top_left: Vector2 = node.position + sprite.position
		check_eq(int(top_left.y) + bottom, rect.end.y * Config.TILE - 1, "%s: opaque bottom row on the footprint's last row" % WorldData.PLACEABLE_NAMES[p])
		check_eq(int(top_left.x) + img.get_width() / 2, rect.position.x * Config.TILE + rect.size.x * Config.TILE / 2,
			"%s: picture centred on the footprint" % WorldData.PLACEABLE_NAMES[p])
		var flame: Sprite2D = node.get_node_or_null(^"Flame") as Sprite2D
		if p == WorldData.PLACEABLE_RELIC:
			if check(flame != null, "the relic bench's candle burns"):
				check_eq(Vector2i(node.position + flame.position), Vector2i(top_left) + Vector2i(37, -4), "its flame at (37, -4) of the picture")
				check(flame.material != null and (flame.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED,
					"the flame unshaded")
				check_eq(flame.hframes, 5, "flame_small_v01: 5 frames")
		else:
			check(flame == null, "%s has no flame" % WorldData.PLACEABLE_NAMES[p])
	check_eq(world.fixtures.verify()["mismatches"], 0, "fixture view = data with three stations")
	check_eq(world.fixtures.verify()["fixtures"] - world.fixtures.verify()["trees"], 4, "three stations + the entrance (M7b: besides the trees)")


static func _tiles(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out


## main.tscn offline: from logs to the gear. Tab away from stations: the inventory until a log was had, then the hand
## panel; the workbench by hand, put down with a click; planks and the anvil there (Tab at it); ingots, a sword and the
## relic bench at the anvil; a torch at the relic bench.
func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null and p.gear_on, "main has an offline player with gear on"):
		return
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	main.toggle_tab()
	check(main.hud.open and not main.crafting_open(), "Tab with nothing: the inventory")
	main.toggle_tab()
	p.inventory.add(&"log", 9)
	p.inventory.add(&"stone_a", 10)
	p.inventory.add(&"ore_iron", 6)
	p.inventory.add(&"ore_copper", 4)
	main.toggle_tab()
	if not check(main.crafting_open() and main.hud.crafting.station.kind == Crafting.HAND and p.ui_locked,
			"Tab with logs had, away from stations: the hand recipes"):
		return
	check_eq(_ids(main.hud.crafting.recipes), [&"workbench"], "one hand row: the workbench")
	main.craft_row(0)
	check_eq(p.inventory.count_of(&"workbench"), 1, "crafted the workbench by hand")
	check_eq(p.inventory.count_of(&"log"), 5, "four logs used")
	main.toggle_tab()
	check(not main.crafting_open() and not p.ui_locked, "Tab closes the hand panel")
	# Put the workbench down south of the player at (60, 51).
	_place(main, p, &"workbench", Vector2i(60, 51))
	check_eq(main.world.data.footprints(WorldData.PLACEABLE_WORKBENCH).size(), 1, "a click put the workbench down")
	main.toggle_tab()
	if not check(main.crafting_open() and main.hud.crafting.station.kind == Crafting.WORKBENCH, "Tab at it: the workbench panel"):
		return
	check_eq(_ids(main.hud.crafting.recipes), [&"planks"], "planks only (the anvil needs planks had)")
	for i: int in 4:
		main.craft_row(0)
	check_eq(p.inventory.count_of(&"planks"), 8, "four logs -> eight planks")
	check_eq(_ids(main.hud.crafting.recipes), [&"planks", &"anvil"], "the anvil row (stone, iron ore, planks)")
	main.craft_row(1)
	check_eq(p.inventory.count_of(&"anvil"), 1, "the anvil made at the workbench")
	main.toggle_tab()
	_place(main, p, &"anvil", Vector2i(63, 51))
	check_eq(main.world.data.footprints(WorldData.PLACEABLE_ANVIL).size(), 1, "the anvil down next to the workbench")
	main.toggle_tab()
	if not check(main.crafting_open() and main.hud.crafting.station.kind == Crafting.ANVIL, "Tab nearer the anvil: its panel"):
		return
	# Smelt four iron, four copper.
	for i: int in 4:
		main.craft_row(_ids(main.hud.crafting.recipes).find(&"ingot_iron"))
	for i: int in 4:
		main.craft_row(_ids(main.hud.crafting.recipes).find(&"ingot_copper"))
	check_eq([p.inventory.count_of(&"ingot_iron"), p.inventory.count_of(&"ingot_copper")], [4, 4], "smelted at the anvil")
	main.craft_row(_ids(main.hud.crafting.recipes).find(&"sword_t1"))
	check_eq(p.inventory.count_of(&"sword_t1"), 1, "a tier-1 sword at the anvil (any class: a paladin here)")
	main.craft_row(_ids(main.hud.crafting.recipes).find(&"relic_bench"))
	check_eq(p.inventory.count_of(&"relic_bench"), 1, "the relic bench at the anvil")
	main.toggle_tab()
	_place(main, p, &"relic_bench", Vector2i(66, 51))
	check_eq(main.world.data.footprints(WorldData.PLACEABLE_RELIC).size(), 1, "the relic bench down: three stations in a row")
	main.toggle_tab()
	if check(main.crafting_open() and main.hud.crafting.station.kind == Crafting.RELIC, "Tab at the relic bench: its panel"):
		main.craft_row(0)
		check_eq(p.inventory.count_of(&"torch"), 4, "four torches at the relic bench")
	main.toggle_tab()
	check_eq(main.world.fixtures.verify()["mismatches"], 0, "the stations drawn = data")


## Selects `id` in the hotbar, walks the player to the tile south of `target` and clicks on `target`.
func _place(main: Main, p: Player, id: StringName, target: Vector2i) -> void:
	for i: int in p.inventory.hotbar_size:
		if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == id:
			p.inventory.select(i)
	p.teleport(Arena.spawn_feet(target + Vector2i(0, 1)))
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, Vector2(target * Config.TILE) + Vector2(8, 8), true, true, true, TICK)
	main.step_combat(TICK)


## A session (M7c, changed on purpose: M7a's host refused the stations, the chest and every M7 recipe): the host places the
## three stations and the chest with the offline rules (three edits each, the chest north of the altar in the light) and
## smelts at the anvil it placed (a CRAFT of the chain).
func _check_session() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"WorkbenchTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var start: Vector2 = Arena.spawn_feet(Vector2i(63, 52))
	var m: NetMember = s.add_member(2, 7, "miner", start, RigData.Dir.NORTH)
	m.gate = InputGate.new()
	var seq: int = 1
	var spots: Array[Array] = [[&"workbench", Vector2i(60, 51), Vector2i(60, 52)], [&"anvil", Vector2i(63, 51), Vector2i(63, 52)],
		[&"relic_bench", Vector2i(66, 51), Vector2i(66, 52)], [&"storage_chest", Vector2i(63, 44), Vector2i(63, 43)]]
	for spot: Array in spots:
		var id: StringName = spot[0]
		var at: Vector2i = spot[1]
		var feet: Vector2i = spot[2]
		m.player.teleport(Arena.spawn_feet(feet))
		m.player.inventory.clear()
		m.player.inventory.add(id, 1)
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(seq, Vector2i.ZERO)
		seq += 1
		f.op = NetProtocol.Op.USE
		f.slot = 0
		f.cell = at
		f.map = Config.MAP_SURFACE
		m.player.begin_tick()
		host.run_frame(m, f)
		check_eq(m.player.inventory.count_of(id), 0, "%s placed by the host (refusals %s)" % [id, m.ops_refused])
		for t: int in Config.NET_OP_INTERVAL_TICKS:
			m.refill_ops()  # the host's ticks between two requests
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 11, "one edit per footprint tile on the host's map (3 + 2 + 3 + 3)")
	check_eq(world.data.footprints(WorldData.PLACEABLE_CHEST).size(), 1, "the chest stands in the light")
	m.player.teleport(start)
	m.player.inventory.clear()
	m.player.inventory.add(&"ore_iron", 5)
	var c: NetProtocol.InputFrame = NetProtocol.InputFrame.new(seq, Vector2i.ZERO)
	seq += 1
	c.op = NetProtocol.Op.CRAFT
	c.recipe = Crafting.index_of(&"ingot_iron")
	c.map = Config.MAP_SURFACE
	for t: int in Config.NET_OP_INTERVAL_TICKS:
		m.refill_ops()
	m.player.begin_tick()
	c.seq = seq
	host.run_frame(m, c)
	check_eq(m.player.inventory.count_of(&"ingot_iron"), 1, "smelted at the anvil the host placed (M7c)")
	check_eq(m.player.inventory.count_of(&"ore_iron"), 4, "one ore used")
	check(m.inventory_dirty, "the owner gets its inventory")


## The same chain twice (fresh worlds and inventories): the same inventory text and world hash after each step.
func _check_determinism() -> void:
	var runs: Array[PackedStringArray] = []
	for run_i: int in 2:
		var out: PackedStringArray = []
		var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		var inv: Inventory = inv_with([[&"log", 12], [&"stone_a", 10], [&"ore_iron", 8], [&"ore_copper", 6]])
		for id: StringName in [&"workbench", &"planks", &"planks", &"planks", &"anvil", &"ingot_iron", &"ingot_iron",
				&"ingot_iron", &"ingot_copper", &"ingot_copper", &"sword_t1", &"bow_t1", &"relic_bench", &"torch"]:
			var o: Crafting.Outcome = Crafting.craft(Crafting.recipe(id), "archer", inv)
			out.append("%s:%s:%s" % [id, o.why, inv.describe()])
		var feet: Vector2 = Arena.spawn_feet(Vector2i(60, 52))
		var placed: WorldItems.Outcome = WorldItems.place(data, feet, inv_with([[&"workbench", 1]]), 0, Vector2i(60, 51))
		for e: EditLog.WorldEdit in placed.edits:
			EditLog.apply_to_data(data, e)
		out.append(data.content_hash())
		runs.append(out)
	check_eq(runs[0], runs[1], "the same chain twice: the same steps, inventories and world hash")
	check(runs[0][runs[0].size() - 1] != SurfaceGen.generate(Config.DEFAULT_SEED).content_hash(), "the placed workbench is in the hash")
