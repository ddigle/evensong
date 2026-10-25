extends "res://tests/base_test.gd"
## M7a, the shared storage chest (offline first; ○ gameplay-design §5 "공유 창고: 제단 옆"; PROVISIONAL README "임시값" M7a 공유
## 창고): placement (the alchemy table's rule, plus the whole footprint in the altar's light with Config.CHEST_ONLY_IN_LIGHT:
## outside, half lit, the altar carried and the dungeon refused; spawn slots, crops, gatherables, the altar, another chest
## refused; a station may touch it), the transfer rules (whole stacks, merging, a full chest, a partial move both ways,
## grades and durability kept), the chest in the world (one per footprint, the map's, the content hash covers what it
## holds and nothing else changes for an empty one), the altar moving (the chest stays with its contents and still opens;
## the altar never lands on it; a new chest follows the new light), main.tscn (a click puts it down, F at it opens the
## panel with the inventory and stands the player, clicks move stacks, Tab / F close it, going down closes it) and
## determinism.

const TICK: float = 1.0 / 60.0
## Seed 1: a chest footprint south of the altar wholly in its light, clear of the spawn slots (row 51).
const LIT: Vector2i = Vector2i(63, 51)

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_placement()
	_check_transfer()
	_check_world()
	_check_altar_moves()
	await _check_main()
	_check_determinism()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func chest_inv(n: int = 1) -> Inventory:
	var inv: Inventory = Inventory.new()
	inv.add(&"storage_chest", n)
	return inv


static func place(d: WorldData, c: Vector2i, inv: Inventory = null, bodies: Array[Vector2] = []) -> WorldItems.Outcome:
	var i: Inventory = inv if inv != null else chest_inv()
	return WorldItems.place(d, Arena.spawn_feet(c + Vector2i(0, 1)), i, 0, c, bodies)


static func apply(d: WorldData, o: WorldItems.Outcome) -> void:
	for e: EditLog.WorldEdit in o.edits:
		EditLog.apply_to_data(d, e)


## Written out here: every corner of every tile of `rect` within the safe radius of the altar centre.
static func lit(d: WorldData, rect: Rect2i) -> bool:
	if not d.altar_rect.has_area():
		return false
	var centre: Vector2 = d.altar_center_px()
	for y: int in range(rect.position.y, rect.end.y + 1):
		for x: int in range(rect.position.x, rect.end.x + 1):
			if Vector2(x * Config.TILE, y * Config.TILE).distance_to(centre) > Config.safe_radius_px():
				return false
	return true


func _check_placement() -> void:
	check(Config.CHEST_ONLY_IN_LIGHT, "CHEST_ONLY_IN_LIGHT on (PROVISIONAL default)")
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var o: WorldItems.Outcome = place(d, LIT)
	check(o.ok(), "a chest south of the altar, in its light (%s)" % o.why)
	var rect: Rect2i = WorldItems.place_rect(WorldData.PLACEABLE_CHEST, LIT)
	check_eq(rect.size, Vector2i(3, 1), "3x1 footprint")
	check(lit(d, rect), "that footprint is lit (written-out rule)")
	check_eq(o.edits.size(), 3, "three edits")
	apply(d, o)
	check(WorldData.placeable_blocks(WorldData.PLACEABLE_CHEST), "it blocks")
	check(Movement.is_blocked(d, LIT), "walking stops at it")
	# Every footprint whose tiles are all in reach of a placer: lit (written-out rule) = allowed, else refused.
	var fresh: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var centre: Vector2i = Aim.cell_of(fresh.altar_center_px())
	var mismatched: int = 0
	var lit_ok: int = 0
	var dark_refused: int = 0
	for y: int in range(centre.y - 10, centre.y + 11):
		for x: int in range(centre.x - 10, centre.x + 11):
			var c: Vector2i = Vector2i(x, y)
			var r: Rect2i = WorldItems.place_rect(WorldData.PLACEABLE_CHEST, c)
			var oo: WorldItems.Outcome = place(fresh, c)
			if lit(fresh, r):
				if oo.ok():
					lit_ok += 1
			elif oo.ok():
				mismatched += 1
			elif oo.why == Storage.WHY_LIGHT:
				dark_refused += 1
	check_eq(mismatched, 0, "no chest anywhere outside the light (21x21 targets around the altar)")
	check(lit_ok > 10 and dark_refused > 100, "lit spots take it (%d), dark ones say outside the light (%d)" % [lit_ok, dark_refused])
	# Half lit: a footprint with one corner out.
	var half: Vector2i = Vector2i(-1, -1)
	for x2: int in range(centre.x - 9, centre.x + 9):
		var r2: Rect2i = WorldItems.place_rect(WorldData.PLACEABLE_CHEST, Vector2i(x2, LIT.y + 1))
		var some: bool = false
		for t: int in 3:
			if lit(fresh, Rect2i(r2.position + Vector2i(t, 0), Vector2i.ONE)):
				some = true
		if some and not lit(fresh, r2):
			half = Vector2i(x2, LIT.y + 1)
			break
	if check(half.x >= 0, "a half-lit footprint exists"):
		check_eq(place(fresh, half).why, Storage.WHY_LIGHT, "half lit: outside the light")
	# The altar carried: no light at all.
	var carried: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply_edits(carried, AltarMove.pickup_edits(carried))
	check(not carried.altar_rect.has_area(), "the altar picked up")
	check_eq(place(carried, LIT).why, Storage.WHY_LIGHT, "the altar carried: no light, no chest")
	# The dungeon: no altar there.
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var arrival: Vector2i = Aim.feet_cell(DungeonGen.arrival_below(DungeonGen.exit_rect(dun)))
	check_eq(place(dun, arrival + Vector2i(0, 2)).why, Storage.WHY_LIGHT, "the dungeon: outside the light")
	# Spawn slots, crops, gatherables, the altar, someone, another chest.
	var refused: int = 0
	var placed: int = 0
	for o_slot: Vector2i in Config.SPAWN_SLOTS:
		var spot: Vector2 = fresh.altar_center_px() + Vector2(o_slot)
		for dx: int in range(-3, 4):
			var tc: Vector2i = Aim.feet_cell(spot) + Vector2i(dx, 0)
			var r3: Rect2i = WorldItems.place_rect(WorldData.PLACEABLE_CHEST, tc)
			if not Rect2(Vector2(r3.position * Config.TILE), Vector2(r3.size * Config.TILE)).intersects(Movement.feet_box(spot)):
				continue
			var oo2: WorldItems.Outcome = place(fresh, tc)
			if oo2.ok():
				placed += 1
			elif oo2.why == WorldItems.WHY_RESERVED or oo2.why == Storage.WHY_LIGHT:
				refused += 1
	check(placed == 0 and refused > 0, "never on a spawn slot (%d refused)" % refused)
	var crop: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	crop.set_value(WorldData.Layer.FLOOR, LIT, Terrain.SOIL)
	crop.set_value(WorldData.Layer.VEGETATION, LIT, Farming.Field.new(Farming.KIND_BUFF, 1).value())
	check_eq(place(crop, LIT).why, WorldItems.WHY_NOT_OPEN, "not on a crop")
	var wet: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	wet.set_value(WorldData.Layer.FLOOR, LIT, Terrain.SOIL)
	wet.set_value(WorldData.Layer.VEGETATION, LIT, Farming.Field.new(Farming.KIND_NONE, 0, true).value())
	check_eq(place(wet, LIT).why, WorldItems.WHY_NOT_OPEN, "not on wet soil")
	var on_altar: Vector2i = fresh.altar_rect.position + Vector2i(1, 2)
	check_eq(place(fresh, on_altar).why, WorldItems.WHY_NOT_OPEN, "not on the altar")
	check_eq(place(fresh, LIT, null, [Arena.spawn_feet(LIT)] as Array[Vector2]).why, WorldItems.WHY_BODY, "not on someone")
	var next_to: Vector2i = LIT + Vector2i(3, 0)
	check_eq(place(d, next_to).why, WorldItems.WHY_TOO_CLOSE, "not touching another chest")
	var station: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	station.put_placeable(Rect2i(LIT.x + 2, LIT.y, 2, 1), WorldData.PLACEABLE_ANVIL)
	check(place(station, LIT).ok(), "touching an anvil is fine (another kind)")
	check_eq(Crafting.station_near(d, Arena.spawn_feet(LIT + Vector2i(0, 1))), null, "a chest is no crafting station")


static func apply_edits(d: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(d, e)


func _check_transfer() -> void:
	var chest: WorldData.Chest = WorldData.Chest.new()
	check_eq(chest.slots.size(), Config.CHEST_SLOTS, "%d slots" % Config.CHEST_SLOTS)
	check(chest.is_empty(), "a new chest is empty")
	var inv: Inventory = Inventory.new()
	inv.add(&"stone_a", 99)
	inv.add(&"stone_a", 40)
	inv.add(&"wild_healing", 5, ItemDB.Grade.FINE)
	inv.add(&"wild_healing", 7)
	inv.add(&"sword_t1", 1)
	inv.stack_at(4).durability = 33
	var m: Storage.Moved = Storage.store(chest, inv, 0)
	check(m.ok() and m.count == 99 and m.left == 0 and inv.stack_at(0) == null, "a full stack goes in whole")
	check_eq(str(chest.slots[0]), "stone_a x99", "into the first slot")
	m = Storage.store(chest, inv, 1)
	check(m.ok() and m.count == 40 and inv.stack_at(1) == null, "40 more")
	check_eq(str(chest.slots[1]), "stone_a x40", "a full stack does not take more: a new slot")
	m = Storage.store(chest, inv, 2)
	m = Storage.store(chest, inv, 3)
	check(str(chest.slots[2]) == "wild_healing x5 (fine)" and str(chest.slots[3]) == "wild_healing x7 (common)",
		"grades kept apart")
	m = Storage.store(chest, inv, 4)
	check(m.ok() and chest.slots[4].id == &"sword_t1" and chest.slots[4].durability == 33, "a worn sword keeps its durability in")
	check_eq(Storage.store(chest, inv, 4).why, Storage.WHY_EMPTY, "an empty slot: nothing")
	# Merging: 30 stones top up the 40.
	inv.add(&"stone_a", 30)
	m = Storage.store(chest, inv, 0)
	check(m.ok() and m.count == 30 and str(chest.slots[1]) == "stone_a x70", "merged into the stack with room")
	# Take back: the sword with its durability, into the first empty slot.
	m = Storage.take(chest, inv, 4)
	var back: ItemStack = null
	for s: ItemStack in inv.slots:
		if s != null and s.id == &"sword_t1":
			back = s
	check(m.ok() and back != null and back.durability == 33 and chest.slots[4] == null, "taken back worn (33)")
	check_eq(Storage.take(chest, inv, 4).why, Storage.WHY_EMPTY, "an empty chest slot: nothing")
	check_eq(Storage.take(chest, inv, 99).why, Storage.WHY_EMPTY, "outside the chest: nothing")
	# A full chest refuses, nothing changes.
	var full: WorldData.Chest = WorldData.Chest.new()
	for i: int in full.slots.size():
		full.slots[i] = ItemStack.new(&"mushroom_a", 99, 0)
	var inv2: Inventory = Inventory.new()
	inv2.add(&"stone_b", 10)
	var before: String = inv2.describe()
	check_eq(Storage.store(full, inv2, 0).why, Storage.WHY_CHEST_FULL, "a full chest: refused")
	check_eq(inv2.describe(), before, "nothing changed")
	# Partial in: one slot with 69 stones, the rest full of mushrooms: a 99 stack moves 30, 69 stay.
	full.slots[5] = ItemStack.new(&"stone_b", 69, 0)
	inv2.add(&"stone_b", 89)
	m = Storage.store(full, inv2, 0)
	check(m.ok() and m.count == 30 and m.left == 69 and inv2.count_of(&"stone_b") == 69 and full.slots[5].count == 99,
		"partial: 30 in, 69 stay")
	# Partial out: an inventory with room for 20 takes 20 of a 99 stack.
	var tight: Inventory = Inventory.new()
	for k: int in tight.size():
		tight.add(&"herb_clump", 99)
	tight.slots[3] = ItemStack.new(&"mushroom_a", 79, 0)
	m = Storage.take(full, tight, 0)
	check(m.ok() and m.count == 20 and full.slots[0].count == 79 and tight.slots[3].count == 99, "partial out: 20 taken, 79 stay")
	check_eq(Storage.take(full, tight, 1).why, Storage.WHY_FULL, "a full inventory: refused")
	# Gear into a chest with one free slot: one at a time.
	var one: WorldData.Chest = WorldData.Chest.new(2)
	one.slots[0] = ItemStack.new(&"stone_a", 1, 0)
	var g: Inventory = Inventory.new()
	g.add(&"bow_t1", 1)
	g.add(&"bow_t1", 1)
	check(Storage.store(one, g, 0).ok() and Storage.store(one, g, 1).why == Storage.WHY_CHEST_FULL, "two bows, one slot: one goes")
	check(Storage.store(null, g, 1).why == Storage.WHY_NO_CHEST, "no chest: refused")


func _check_world() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var empty_hash: String = d.content_hash()
	check_eq(empty_hash, SurfaceGen.GOLDEN_HASH, "the generated world's hash is the golden one (no chest, unchanged)")
	check(d.chest_at(LIT) == null, "no chest there yet")
	apply(d, place(d, LIT))
	var placed_hash: String = d.content_hash()
	var c1: WorldData.Chest = d.chest_at(LIT)
	check(c1 != null and c1 == d.chest_at(LIT + Vector2i(-1, 0)) and c1 == d.chest_at(LIT + Vector2i(1, 0)),
		"every tile of its footprint names the one chest")
	check_eq(d.content_hash(), placed_hash, "an empty chest adds nothing to the hash")
	check(d.chests_bytes().is_empty(), "no bytes for an empty chest")
	var inv: Inventory = Inventory.new()
	inv.add(&"ore_iron", 5)
	Storage.store(c1, inv, 0)
	var held_hash: String = d.content_hash()
	check(held_hash != placed_hash, "what it holds is in the hash")
	var copy: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(copy, place(copy, LIT))
	var inv2: Inventory = Inventory.new()
	inv2.add(&"ore_iron", 5)
	Storage.store(copy.chest_at(LIT), inv2, 0)
	check_eq(copy.content_hash(), held_hash, "the same contents: the same hash")
	inv2.add(&"ore_iron", 1)
	Storage.store(copy.chest_at(LIT), inv2, 0)
	check(copy.content_hash() != held_hash, "one more ore: another hash")
	var worn: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(worn, place(worn, LIT))
	var s1: Inventory = Inventory.new()
	s1.add(&"sword_t1", 1)
	Storage.store(worn.chest_at(LIT), s1, 0)
	var full_sword: String = worn.content_hash()
	worn.chest_at(LIT).slots[0].durability = 50
	check(worn.content_hash() != full_sword, "durability is in the hash")
	# A second chest has its own contents.
	var other: Vector2i = Vector2i(63, 44)  # north of the altar, lit
	var o2: WorldItems.Outcome = place(d, other)
	if check(o2.ok(), "a second chest (%s)" % o2.why):
		apply(d, o2)
		check(d.chest_at(other) != c1 and d.chest_at(other).is_empty(), "with its own (empty) contents")


## The altar moves (M5b): the chest stays with its contents and still opens out of the light; the altar never lands on it
## and needs its spawn slots clear of it; the old spot takes no new chest, the new light does.
func _check_altar_moves() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(d, place(d, LIT))
	var inv: Inventory = Inventory.new()
	inv.add(&"planks", 12)
	Storage.store(d.chest_at(LIT), inv, 0)
	var home: Rect2i = d.altar_rect
	apply_edits(d, AltarMove.pickup_edits(d))
	var west: Rect2i = Rect2i(home.position + Vector2i(-13, -1), home.size)
	check_eq(AltarMove.place_refusal(d, west), "", "the altar goes down 13 tiles west")
	apply_edits(d, AltarMove.place_edits(west))
	check_eq(d.altar_rect, west, "moved")
	var rect: Rect2i = WorldItems.place_rect(WorldData.PLACEABLE_CHEST, LIT)
	check_eq(d.footprint_at(LIT), rect, "the chest stayed")
	check(not lit(d, rect), "now out of the light")
	check_eq(str(d.chest_at(LIT).slots[0]), "planks x12", "its contents with it")
	check_eq(Storage.chest_for(d, Arena.spawn_feet(LIT + Vector2i(0, 1)), LIT), rect, "F still opens it")
	check_eq(place(d, LIT + Vector2i(0, 3)).why, Storage.WHY_LIGHT, "a new chest at the old light: refused")
	var new_lit: Vector2i = Vector2i(west.position.x + 1, west.end.y + 3)
	check(place(d, new_lit).ok(), "the new light takes one")
	# Bring the altar back next to the chest: never on it; not where its spawn slots hit the chest.
	apply_edits(d, AltarMove.pickup_edits(d))
	var on_chest: Rect2i = Rect2i(rect.position + Vector2i(0, -2), Vector2i(3, 3))
	check_eq(AltarMove.place_refusal(d, on_chest), AltarMove.WHY_NOT_OPEN, "the altar on the chest: not open ground")
	var near: Rect2i = Rect2i(rect.position + Vector2i(0, -4), Vector2i(3, 3))
	var why: String = AltarMove.place_refusal(d, near)
	check(why == AltarMove.WHY_SLOTS or why == "", "just north: refused only when a spawn slot hits the chest (%s)" % why)
	var fallback: Rect2i = AltarMove.set_down_rect(d, Arena.spawn_feet(LIT + Vector2i(0, 1)))
	check(fallback.has_area() and not fallback.intersects(rect), "a carrier going down next to it sets the altar down clear of it")


## main.tscn offline: put a chest down with a click, F opens it (the inventory too, the player stands), clicks move
## stacks both ways (the panel's geometry), Tab and F close it, going down closes it.
func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	p.inventory.add(&"storage_chest", 1)
	p.inventory.add(&"stone_a", 50)
	p.inventory.add(&"sword_t1", 1)
	var cslot: int = 0
	var sword_slot: int = 0
	for i: int in p.inventory.size():
		var st: ItemStack = p.inventory.stack_at(i)
		if st != null and st.id == &"storage_chest":
			cslot = i
		if st != null and st.id == &"sword_t1":
			sword_slot = i
	p.inventory.stack_at(sword_slot).durability = 70
	p.inventory.select(cslot)
	p.teleport(Arena.spawn_feet(LIT + Vector2i(0, 1)))
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, Vector2(LIT * Config.TILE) + Vector2(8, 8), true, true, true, TICK)
	check_eq(main.world.data.footprints(WorldData.PLACEABLE_CHEST).size(), 1, "a click put the chest down")
	check(main.world.fixtures.nodes.has(LIT + Vector2i(-1, 0)), "and it is drawn")
	check_eq(main.world.fixtures.verify()["mismatches"], 0, "fixture view = data")
	p.aim_sector = Aim.Sector.NORTH
	main.pick_up()
	if not check(main.chest_open() and main.hud.open and p.ui_locked, "F at the chest: its panel and the inventory, the player stands"):
		return
	var panel: ChestPanel = main.hud.chest
	# Click an inventory slot (the stones): stored.
	var stone_slot: int = -1
	for i2: int in p.inventory.size():
		if p.inventory.stack_at(i2) != null and p.inventory.stack_at(i2).id == &"stone_a":
			stone_slot = i2
	var view: Vector2i = main.hud.view_size()
	check(panel.click_at(Vector2(Hud.slot_origin(stone_slot, p.inventory.hotbar_size, view) + Vector2i(9, 9))), "a click on the stones")
	check_eq(p.inventory.count_of(&"stone_a"), 0, "the stones left the inventory")
	check_eq(str(panel.chest.slots[0]), "stone_a x50", "into the chest")
	check(panel.click_at(Vector2(Hud.slot_origin(sword_slot, p.inventory.hotbar_size, view) + Vector2i(9, 9))), "a click on the sword")
	check(panel.chest.slots[1] != null and panel.chest.slots[1].durability == 70, "the worn sword in, worn")
	check(panel.click_at(Vector2(panel.slot_origin(0) + Vector2i(9, 9))), "a click on the chest's first slot")
	check_eq(p.inventory.count_of(&"stone_a"), 50, "the stones back")
	check(not panel.click_at(Vector2(panel.panel_rect().position) - Vector2(5, 5)), "a click elsewhere: nothing")
	var top_inv: Vector2i = Hud.slot_origin(p.inventory.size() - 1, p.inventory.hotbar_size, view)
	check(panel.panel_rect().end.y <= top_inv.y, "the panel sits above the inventory grid")
	check(panel.panel_rect().position.y >= 0, "and inside the view")
	# While open the player stands.
	var before: Vector2 = p.sim_position
	for t: int in 10:
		p.begin_tick()
		p.tick_controls(Vector2i(1, 0), p.sim_position + Vector2(30, 0), true, true, true, TICK, true, true)
	check_eq(p.sim_position, before, "no walking while the chest is open")
	main._chest_input(_action_event(&"toggle_inventory"))
	check(not main.chest_open() and not main.hud.open and not p.ui_locked, "Tab closes it")
	p.aim_sector = Aim.Sector.NORTH  # the locked frames above still turned the aim east
	main.pick_up()
	check(main.chest_open(), "F opens it again")
	main._chest_input(_action_event(&"interact"))
	check(not main.chest_open(), "F closes it")
	main.pick_up()
	p.take_hit(Config.PLAYER_HP_MAX)
	main._physics_process(TICK)
	check(not main.chest_open() and not p.ui_locked, "down: closed")
	# The contents belong to the world: another player (a fresh inventory) sees them.
	check(main.world.data.chest_at(LIT).slots[1].id == &"sword_t1", "the chest's contents are the map's")


static func _action_event(action: StringName) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


## The same chest moves twice: the same chest bytes and hash.
func _check_determinism() -> void:
	var out: Array[String] = []
	for run_i: int in 2:
		var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		apply(d, place(d, LIT))
		var inv: Inventory = Inventory.new()
		inv.add(&"stone_a", 120)
		inv.add(&"ore_copper", 7)
		inv.add(&"armor_t1", 1)
		inv.stack_at(3).durability = 12
		var c: WorldData.Chest = d.chest_at(LIT)
		for slot: int in [0, 1, 2, 3, 0]:
			Storage.store(c, inv, slot)
		Storage.take(c, inv, 1)
		Storage.take(c, inv, 3)
		out.append("%s|%s|%s" % [d.content_hash(), c.describe(), inv.describe()])
	check_eq(out[0], out[1], "the same moves twice: the same chest and hash")
