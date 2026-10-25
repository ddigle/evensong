extends "res://tests/base_test.gd"
## M7b, building (offline first; ● gameplay-design §3.0 R11 anyone builds, §3.3 R37 a built wall is the wall layer above the
## floor, stone only; the rest PROVISIONAL README "임시값" M7b): the WALL layer's built kinds (what blocks, what is a wall,
## the open door), the pieces and their recipes (written out here), the cost inside / outside the light (every tile around
## the altar against a "four corners in the radius" written out here), every placement rule (open ground, pieces, fixtures,
## the altar, the entrance, trees, fields, plants, drops, bodies, heretics, spots where players appear, faces that would cover
## something, doors' open ground below, the dungeon's walls and faces, vertical runs), sealing (a ring around the altar
## closed by a wall is refused, by a door allowed; the entrance's arrival; a station closing a ring; the altar put down in a
## closed ring), collision (walls, faces, doors, floors, slides) and the prediction against the host's walk among walls and
## doors, heretics (sight and the chase stop at walls, a closed door is a wall to them), shots, taking down (any piece, the
## refund, dungeon walls are mined, a full inventory), doors (F, the face tile, the doorway), mining (built pieces are not
## mined; the miner's 3x3 skips them), fields (no tilling a floor piece), the altar move, the build view (masks, faces,
## dots, doors, floors) and main.tscn (clicks, right-click, F, the ghost), a session (refused), determinism.

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0
const UP: Vector2i = Vector2i(0, -1)
const DOWN: Vector2i = Vector2i(0, 1)

## Written out here on purpose (README "임시값" M7b 건설 조각): output -> [station, count, {input: count}].
const RECIPES: Dictionary[StringName, Array] = {
	&"stone_wall": ["workbench", 2, {&"stone_a": 2}],
	&"door": ["workbench", 1, {&"planks": 3, &"stone_a": 2}],
	&"stone_floor": ["workbench", 4, {&"stone_a": 2}],
	&"lantern": ["workbench", 1, {&"planks": 2, &"stone_a": 1}],
	&"axe": ["hand", 1, {&"stone_a": 2}],
}

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_kinds()
	_check_recipes()
	_check_cost()
	_check_rules()
	_check_dungeon_rules()
	_check_sealing()
	_check_collision()
	_check_prediction()
	_check_heretics_and_shots()
	_check_demolish()
	_check_doors()
	_check_mining()
	_check_fields_and_altar()
	await _check_view()
	await _check_main()
	_check_session()
	_check_determinism()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


## A 24x20 surface with no altar, no entrance, all grass (pure rule checks).
static func _plain(size: Vector2i = Vector2i(24, 20)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_SURFACE
	return d


static func inv_with(items: Array) -> Inventory:
	var inv: Inventory = Inventory.new()
	for pair: Array in items:
		var id: StringName = pair[0]
		var n: int = pair[1]
		inv.add(id, n)
	return inv


static func apply(data: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(data, e)


static func put(data: WorldData, c: Vector2i, kind: int) -> void:
	data.set_value(WorldData.Layer.WALL, c, Walls.pack(kind, 0))


## Feet standing on tile `c` (low in the tile, like an arrival point).
static func on(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


## The seed's surface with its trees taken away (open ground to build on).
static func _seed_world() -> WorldData:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	for c: Vector2i in Forest.tree_cells(d):
		d.set_value(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_NONE)
	return d


# --- the kinds ---------------------------------------------------------------------------------------

func _check_kinds() -> void:
	var d: WorldData = _plain()
	put(d, Vector2i(2, 2), Walls.KIND_STONE)
	put(d, Vector2i(5, 2), Walls.KIND_DOOR)
	put(d, Vector2i(8, 2), Walls.KIND_DOOR_OPEN)
	put(d, Vector2i(11, 2), Walls.KIND_FLOOR)
	put(d, Vector2i(14, 2), Walls.KIND_ROCK)
	check_eq(Walls.KIND_NAMES, PackedStringArray(["none", "rock", "bedrock", "stone", "door", "door_open", "floor"]), "kind names")
	# [tile, is_wall, is_built, is_natural, blocks, face below blocks, hardness unbreakable]
	for row: Array in [[Vector2i(2, 2), true, true, false, true, true, true], [Vector2i(5, 2), true, true, false, true, true, true],
			[Vector2i(8, 2), true, true, false, false, false, true], [Vector2i(11, 2), false, false, false, false, false, false],
			[Vector2i(14, 2), true, false, true, true, true, false]]:
		var c: Vector2i = row[0]
		var name: String = Walls.KIND_NAMES[Walls.kind_at(d, c)]
		check_eq(Walls.is_wall(d, c), row[1], "%s is a wall" % name)
		check_eq(Walls.is_built(d, c), row[2], "%s is built" % name)
		check_eq(Walls.is_natural(d, c), row[3], "%s is natural" % name)
		check_eq(Walls.blocks(d, c), row[4], "%s blocks" % name)
		check_eq(Walls.is_face(d, c + DOWN), row[1], "%s casts a face" % name)
		check_eq(Walls.blocks(d, c + DOWN), row[5], "%s's face blocks" % name)
		check_eq(Walls.hardness(d, c) == Walls.UNBREAKABLE, row[6], "%s unbreakable for the pickaxe" % name)
		check_eq(Movement.is_blocked(d, c), row[4], "%s: Movement.is_blocked = Walls.blocks" % name)
	check(Walls.is_floor_piece(d, Vector2i(11, 2)) and not Walls.is_floor_piece(d, Vector2i(2, 2)), "a floor piece")
	check(Walls.is_door(d, Vector2i(5, 2)) and Walls.is_door(d, Vector2i(8, 2)) and Walls.is_open_door(d, Vector2i(8, 2))
		and not Walls.is_open_door(d, Vector2i(5, 2)), "doors: closed, open")
	check_eq(Walls.vertex(d, Vector2i(2, 2)), Walls.V_FLOOR, "the cave view's vertex ignores a built wall")
	check_eq(Walls.vertex(d, Vector2i(2, 3)), Walls.V_FLOOR, "and its face")
	check_eq(Walls.vertex(d, Vector2i(14, 2)), Walls.V_WALL, "a dungeon wall is a wall vertex")
	check_eq(Walls.vertex(d, Vector2i(14, 3)), Walls.V_FACE, "and its face")
	check_eq(Walls.wall_cells(d).size(), 4, "wall cells: stone, two doors, rock (no floor piece)")
	check_eq(Walls.max_hits(d, Vector2i(2, 2)), 0, "a built wall takes no hits")
	check(WorldData.placeable_blocks(WorldData.PLACEABLE_LANTERN) and WorldData.placeable_blocks(WorldData.PLACEABLE_TREE)
		and WorldData.placeable_blocks(WorldData.PLACEABLE_STUMP) == Config.TREE_STUMP_BLOCKS, "lantern, tree, stump block")


# --- recipes ---------------------------------------------------------------------------------------

func _check_recipes() -> void:
	for id: StringName in RECIPES:
		var want: Array = RECIPES[id]
		var r: Crafting.Recipe = Crafting.recipe(id)
		if not check(r != null, "%s has a recipe" % id):
			continue
		var want_station: String = want[0]
		check_eq(String(r.station), want_station, "%s station" % id)
		check_eq(r.out_count, want[1], "%s count" % id)
		var ins: Dictionary = want[2]
		check_eq(r.inputs.size(), ins.size(), "%s inputs" % id)
		for ing: Crafting.Ingredient in r.inputs:
			check_eq(ing.count, ins.get(ing.item, -1), "%s input %s" % [id, ing.item])
		check(r.classes.is_empty() and Crafting.is_m7(r), "%s anyone's, an M7 recipe (a session refuses it)" % id)
	check_eq(Crafting.index_of(&"potion_poison_fine"), 5, "the potions keep 0-5")
	check_eq(Crafting.index_of(&"torch"), 19, "the chain keeps 6-19")
	check_eq(Crafting.index_of(&"repair_sickle_t1"), 25, "the repairs keep 20-25")
	check_eq(Crafting.index_of(&"stone_wall"), 26, "the build pieces come after (26-30)")
	check_eq(Crafting.recipe_count(), 31, "31 recipes")
	# At a workbench with stones: the pieces; by hand: the workbench (logs) and the axe (stones).
	var inv: Inventory = inv_with([[&"stone_a", 20], [&"planks", 10], [&"log", 4]])
	var shown: Array[StringName] = []
	for r2: Crafting.Recipe in Crafting.shown_recipes(Crafting.WORKBENCH, inv):
		shown.append(r2.id)
	for id2: StringName in [&"stone_wall", &"door", &"stone_floor", &"lantern"]:
		check(shown.has(id2), "the workbench shows %s" % id2)
	var hand: Array[StringName] = []
	for r3: Crafting.Recipe in Crafting.shown_recipes(Crafting.HAND, inv):
		hand.append(r3.id)
	check_eq(hand, [&"workbench", &"axe"] as Array[StringName], "by hand: the workbench and the axe")
	var stones: Inventory = inv_with([[&"stone_a", 2]])
	check_eq(Crafting.shown_recipes(Crafting.HAND, stones).size(), 1, "stones only: the axe alone by hand")
	check(Crafting.craft(Crafting.recipe(&"axe"), "cleric", stones).ok() and stones.count_of(&"axe") == 1
		and stones.count_of(&"stone_a") == 0, "an axe from two stones, any class")
	var mats: Inventory = inv_with([[&"stone_a", 7], [&"planks", 5]])
	for id3: StringName in [&"stone_wall", &"door", &"stone_floor", &"lantern"]:
		check(Crafting.craft(Crafting.recipe(id3), "miner", mats).ok(), "%s crafted" % id3)
	check_eq([mats.count_of(&"stone_wall"), mats.count_of(&"door"), mats.count_of(&"stone_floor"), mats.count_of(&"lantern"),
		mats.count_of(&"stone_a"), mats.count_of(&"planks")], [2, 1, 4, 1, 0, 0], "every input used, every output in")


# --- cost ---------------------------------------------------------------------------------------------

func _check_cost() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var centre: Vector2 = d.altar_center_px()
	var radius: float = Config.SAFE_RADIUS_TILES * Config.TILE
	var inside: int = 0
	var bad: int = 0
	for y: int in range(d.altar_rect.position.y - 10, d.altar_rect.end.y + 10):
		for x: int in range(d.altar_rect.position.x - 10, d.altar_rect.end.x + 10):
			var p: Vector2 = Vector2(x * 16, y * 16)
			var lit: bool = true
			for corner: Vector2 in [p, p + Vector2(16, 0), p + Vector2(0, 16), p + Vector2(16, 16)]:
				lit = lit and corner.distance_to(centre) <= radius
			inside += 1 if lit else 0
			if Building.cost_at(d, Vector2i(x, y)) != (1 if lit else 2):
				bad += 1
	check_eq(bad, 0, "cost = 1 on every tile whose four corners are in the light, 2 elsewhere (23x23 tiles)")
	check_between(inside, 100, 200, "tiles in the light: %d" % inside)
	check_eq([Config.BUILD_COST_IN_LIGHT, Config.BUILD_COST_OUTSIDE_LIGHT], [1, 2], "the provisional costs")
	var carried: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(carried, AltarMove.pickup_edits(carried))
	check_eq(Building.cost_at(carried, Vector2i(63, 50)), 2, "no altar (carried): the full cost")
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check_eq(Building.cost_at(dun, Aim.feet_cell(DungeonGen.arrival_point(dun))), 2, "the dungeon: the full cost")
	# The cost leaves the inventory: one piece in the light, two outside; the selected slot first.
	var w: WorldData = _seed_world()
	var feet: Vector2 = on(Vector2i(65, 52))
	var inv: Inventory = inv_with([[&"stone_wall", 3]])
	inv.add(&"stone_wall", 1)
	var o: WorldItems.Outcome = Building.build(w, feet, inv, 0, Vector2i(66, 51))
	check(o.ok() and o.count == 1 and inv.count_of(&"stone_wall") == 3, "in the light: one piece (%s)" % o.why)
	var feet2: Vector2 = on(Vector2i(72, 55))
	var inv2: Inventory = inv_with([[&"stone_wall", 1]])
	check_eq(Building.build(w, feet2, inv2, 0, Vector2i(72, 56)).why, Building.WHY_COST, "outside with one piece: refused")
	check_eq(inv2.count_of(&"stone_wall"), 1, "nothing taken")
	inv2.add(&"stone_wall", 2)
	var o2: WorldItems.Outcome = Building.build(w, feet2, inv2, 0, Vector2i(72, 56))
	check(o2.ok() and o2.count == 2 and inv2.count_of(&"stone_wall") == 1, "outside: two pieces (%s)" % o2.why)


# --- placement rules ----------------------------------------------------------------------------------

func _check_rules() -> void:
	var d: WorldData = _plain()
	var feet: Vector2 = on(Vector2i(10, 10))
	# Reach and the map.
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(10, 8), 9), WorldItems.WHY_REACH, "two tiles away")
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(10, 10), 9), WorldItems.WHY_REACH, "the feet tile")
	check_eq(Building.refusal(d, feet, &"sword", Vector2i(11, 10), 9), Building.WHY_NOT_PIECE, "not a piece")
	check_eq(Building.refusal(d, on(Vector2i(0, 5)), &"stone_wall", Vector2i(-1, 5), 9), WorldItems.WHY_OUTSIDE, "outside the map")
	# Open ground: every piece, east of the feet (its face south-east, nobody there).
	for id: StringName in Building.PIECES:
		check_eq(Building.refusal(d, feet, id, Vector2i(11, 10), 9), "", "%s on open grass" % id)
	# A wall north of the placer: its face would cover the placer's feet.
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(10, 9), 9), WorldItems.WHY_BODY, "a wall right north: its face on my feet")
	check_eq(Building.refusal(d, feet, &"stone_floor", Vector2i(10, 9), 9), "", "a floor there is fine")
	check_eq(Building.refusal(d, feet, &"lantern", Vector2i(10, 9), 9), "", "a lantern too (no face)")
	# Bodies: a player or a heretic on the tile or on the face tile.
	var bodies: Array[Vector2] = [on(Vector2i(11, 11))]
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(11, 10), 9, bodies), WorldItems.WHY_BODY, "a body on the face tile")
	check_eq(Building.refusal(d, feet, &"lantern", Vector2i(11, 11), 9, bodies), WorldItems.WHY_BODY, "a body on the tile")
	check_eq(Building.refusal(d, feet, &"stone_floor", Vector2i(11, 11), 9, bodies), "", "a floor under a body")
	check_eq(Building.refusal(d, feet, &"lantern", Vector2i(11, 10), 9, bodies), "", "a lantern beside the body")
	# Pieces, placeables, plants, fields, drops.
	put(d, Vector2i(9, 11), Walls.KIND_FLOOR)
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(9, 11), 9), Building.WHY_PIECE_THERE, "a wall on a floor piece")
	check_eq(Building.refusal(d, feet, &"stone_floor", Vector2i(9, 11), 9), Building.WHY_PIECE_THERE, "a floor on a floor piece")
	check_eq(Building.refusal(d, feet, &"lantern", Vector2i(9, 11), 9), "", "a lantern on a floor piece")
	for p: int in [WorldData.PLACEABLE_TORCH, WorldData.PLACEABLE_TREE, WorldData.PLACEABLE_STUMP, WorldData.PLACEABLE_LANTERN,
			WorldData.PLACEABLE_WORKBENCH, WorldData.PLACEABLE_ENTRANCE, WorldData.PLACEABLE_ALTAR, WorldData.PLACEABLE_BAG]:
		d.set_value(WorldData.Layer.PLACEABLE, Vector2i(11, 9), p)
		for id2: StringName in Building.PIECES:
			check_eq(Building.refusal(d, feet, id2, Vector2i(11, 9), 9), WorldItems.WHY_NOT_OPEN,
				"%s on a %s" % [id2, WorldData.PLACEABLE_NAMES[p]])
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(11, 9), 0)
	d.set_value(WorldData.Layer.VEGETATION, Vector2i(11, 9), WorldItems.value_of(&"stone_a"))
	check_eq(Building.refusal(d, feet, &"stone_floor", Vector2i(11, 9), 9), Building.WHY_GROWING, "a floor on a gatherable")
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(11, 8) + DOWN * 0, 9), WorldItems.WHY_REACH, "(reach)")
	d.set_value(WorldData.Layer.VEGETATION, Vector2i(11, 9), 0)
	d.set_value(WorldData.Layer.FLOOR, Vector2i(11, 9), Terrain.SOIL)
	check_eq(Building.refusal(d, feet, &"lantern", Vector2i(11, 9), 9), Building.WHY_GROWING, "a lantern on tilled soil")
	d.set_value(WorldData.Layer.FLOOR, Vector2i(11, 9), Terrain.GRASS)
	d.set_value(WorldData.Layer.VEGETATION, Vector2i(11, 9), Farming.Field.new(Farming.KIND_HEALING, 2, true).value())
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(11, 9), 9), Building.WHY_GROWING, "a wall on a crop")
	d.set_value(WorldData.Layer.VEGETATION, Vector2i(11, 9), 0)
	d.drops[1] = WorldData.Drop.new(1, &"stone_a", 3, 0, Vector2i(11 * 16 + 8, 9 * 16 + 8))
	check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(11, 9), 9), WorldItems.WHY_NOT_OPEN, "a wall on a drop")
	check_eq(Building.refusal(d, feet, &"stone_floor", Vector2i(11, 9), 9), "", "a floor under a drop")
	d.drops.clear()
	# A wall's face may not cover anything: a drop, a gatherable, soil, a placeable below.
	var hides: Array[Array] = [[WorldData.Layer.VEGETATION, WorldItems.value_of(&"mushroom_a")], [WorldData.Layer.FLOOR, Terrain.SOIL],
		[WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TORCH]]
	for h: Array in hides:
		var layer: int = h[0]
		var value: int = h[1]
		d.set_value(layer, Vector2i(11, 11), value)
		check_eq(Building.refusal(d, feet, &"stone_wall", Vector2i(11, 10), 9), Building.WHY_HIDES,
			"the face would cover a %s" % WorldData.LAYER_NAMES[layer])
		check_eq(Building.refusal(d, feet, &"stone_floor", Vector2i(11, 10), 9), "", "a floor has no face")
		d.set_value(layer, Vector2i(11, 11), 0 if layer != WorldData.Layer.FLOOR else Terrain.GRASS)
	d.drops[2] = WorldData.Drop.new(2, &"stone_a", 3, 0, Vector2i(11 * 16 + 8, 11 * 16 + 8))
	check_eq(Building.refusal(d, feet, &"door", Vector2i(11, 10), 9), Building.WHY_HIDES, "the face would cover a drop")
	d.drops.clear()
	# Doors: open ground below; nothing right below a door.
	put(d, Vector2i(11, 12), Walls.KIND_STONE)
	check_eq(Building.refusal(d, on(Vector2i(10, 11)), &"door", Vector2i(11, 11), 9), Building.WHY_DOOR_BELOW,
		"a door with a wall below")
	check_eq(Building.refusal(d, on(Vector2i(10, 11)), &"stone_wall", Vector2i(11, 11), 9), "",
		"a wall on that tile: fine (its face is the wall below's top)")
	put(d, Vector2i(11, 12), Walls.KIND_NONE)
	put(d, Vector2i(11, 10), Walls.KIND_DOOR)
	check_eq(Building.refusal(d, on(Vector2i(10, 11)), &"stone_wall", Vector2i(11, 11), 9), Building.WHY_DOOR_BELOW,
		"a wall right below a door")
	check_eq(Building.refusal(d, on(Vector2i(10, 11)), &"stone_floor", Vector2i(11, 11), 9), "", "a floor below a door")
	check_eq(Building.refusal(d, on(Vector2i(10, 11)), &"lantern", Vector2i(11, 11), 9), WorldItems.WHY_NOT_OPEN,
		"no lantern in a doorway (a face tile)")
	put(d, Vector2i(11, 10), Walls.KIND_NONE)
	var bottom: WorldData = _plain(Vector2i(8, 6))
	check_eq(Building.refusal(bottom, on(Vector2i(3, 4)), &"door", Vector2i(3, 5), 9), Building.WHY_DOOR_BELOW,
		"a door on the bottom row (no tile below)")
	# A vertical run: a wall on the face tile of a built wall.
	put(d, Vector2i(14, 5), Walls.KIND_STONE)
	check(Walls.is_face(d, Vector2i(14, 6)), "the wall's face tile")
	check_eq(Building.refusal(d, on(Vector2i(13, 6)), &"stone_wall", Vector2i(14, 6), 9), "", "a wall on a built wall's face")
	put(d, Vector2i(14, 6), Walls.KIND_STONE)
	check(not Walls.is_face(d, Vector2i(14, 6)) and Walls.is_face(d, Vector2i(14, 7)), "the face moved down one tile")
	check_eq(Building.refusal(d, on(Vector2i(13, 7)), &"stone_floor", Vector2i(14, 7), 9), "", "a floor on the new face tile")
	# Spots where players appear: the seed's spawn slots and the entrance's arrival point.
	var w: WorldData = _seed_world()
	var slot: Vector2 = w.altar_center_px() + Vector2(Config.SPAWN_SLOTS[4])  # (36, 52): tile (65, 50)
	var st: Vector2i = Aim.feet_cell(slot)
	check_eq(Building.refusal(w, on(st + Vector2i(1, -2)), &"stone_wall", st + UP, 9), WorldItems.WHY_RESERVED,
		"a wall whose face covers a spawn slot")
	check_eq(Building.refusal(w, on(st + Vector2i(1, 0)), &"lantern", st, 9), WorldItems.WHY_RESERVED, "a lantern on a spawn slot")
	check_eq(Building.refusal(w, on(st + Vector2i(1, 0)), &"stone_floor", st, 9), "", "a floor on a spawn slot")
	var arrive: Vector2i = Aim.feet_cell(DungeonGen.arrival_below(SurfaceGen.entrance_rect(w)))
	check_eq(Building.refusal(w, on(arrive + Vector2i(1, 1)), &"stone_wall", arrive, 9), WorldItems.WHY_RESERVED,
		"a wall on the entrance's arrival point")
	check_eq(Building.refusal(w, on(arrive + Vector2i(1, 1)), &"stone_wall", SurfaceGen.entrance_rect(w).position, 9),
		WorldItems.WHY_REACH, "(the entrance is out of reach from there)")
	var ent: Vector2i = SurfaceGen.entrance_rect(w).position
	check_eq(Building.refusal(w, on(ent + Vector2i(-1, 0)), &"stone_floor", ent, 9), WorldItems.WHY_NOT_OPEN, "not on the entrance")
	check_eq(Building.refusal(w, on(Vector2i(61, 47)), &"stone_floor", Vector2i(62, 47), 9), WorldItems.WHY_NOT_OPEN, "not on the altar")
	# build(): the slot checks.
	var inv: Inventory = inv_with([[&"stone_wall", 2], [&"sword", 1]])
	check_eq(Building.build(d, feet, inv, 9, Vector2i(11, 10)).why, WorldItems.WHY_BAD_SLOT, "a slot outside the hotbar")
	check_eq(Building.build(d, feet, inv, 2, Vector2i(11, 10)).why, WorldItems.WHY_EMPTY, "an empty slot")
	check_eq(Building.build(d, feet, inv, 1, Vector2i(11, 10)).why, Building.WHY_NOT_PIECE, "a sword")
	var o: WorldItems.Outcome = Building.build(d, feet, inv, 0, Vector2i(11, 10))
	check(o.ok() and o.edits.size() == 1 and o.edits[0].layer == WorldData.Layer.WALL
		and o.edits[0].value == Walls.pack(Walls.KIND_STONE, 0) and o.count == 2, "one WALL edit, two pieces outside the light")
	var lo: WorldItems.Outcome = Building.build(d, feet, inv_with([[&"lantern", 2]]), 0, Vector2i(9, 10))
	check(lo.ok() and lo.edits[0].layer == WorldData.Layer.PLACEABLE and lo.edits[0].value == WorldData.PLACEABLE_LANTERN,
		"the lantern is a PLACEABLE edit")


func _check_dungeon_rules() -> void:
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var arrival: Vector2 = DungeonGen.arrival_point(d)
	var f: Vector2i = Aim.feet_cell(arrival)
	var exit: Rect2i = DungeonGen.exit_rect(d)
	# The exit stairs (a blocking placeable on a face tile) and the rock above them.
	check_eq(Building.refusal(d, on(exit.position + DOWN), &"stone_floor", exit.position, 9), WorldItems.WHY_NOT_OPEN, "not on the stairs")
	check_eq(Building.refusal(d, on(exit.position + DOWN), &"stone_wall", exit.position + UP + UP, 9), WorldItems.WHY_REACH,
		"(the rock above the stairs is out of reach)")
	# A natural wall and its face tile.
	var rock: Vector2i = Walls.NO_CELL
	for c: Vector2i in Walls.wall_cells(d):
		if Walls.kind_at(d, c) == Walls.KIND_ROCK and Walls.is_face(d, c + DOWN) and not Movement.is_blocked(d, c + DOWN + DOWN) \
				and d.get_value(WorldData.Layer.PLACEABLE, c + DOWN) == 0 and d.get_value(WorldData.Layer.PLACEABLE, c) == 0:
			rock = c
			break
	if check(rock != Walls.NO_CELL, "a rock with a face and open floor below"):
		var stand: Vector2 = on(rock + DOWN + DOWN)
		check_eq(Building.refusal(d, stand, &"stone_wall", rock + DOWN, 9), WorldItems.WHY_NOT_OPEN, "not on a dungeon wall's face")
		check_eq(Building.refusal(d, stand, &"stone_floor", rock + DOWN, 9), WorldItems.WHY_NOT_OPEN, "no floor on it either")
		var placer: Vector2 = on(rock + DOWN + DOWN + Vector2i(0, 1))
		check_eq(Building.refusal(d, placer, &"stone_floor", rock + DOWN + DOWN, 9), "", "a floor on the dungeon floor")
	check_eq(Building.cost_at(d, f + Vector2i(1, 0)), 2, "the dungeon costs two")
	var inv: Inventory = inv_with([[&"stone_wall", 4]])
	var o: WorldItems.Outcome = Building.build(d, arrival, inv, 0, f + Vector2i(1, 1))
	check(o.ok() and inv.count_of(&"stone_wall") == 2, "a wall in the arrival room (%s)" % o.why)


# --- sealing ------------------------------------------------------------------------------------------

## The rectangle ring x0..x1 / y0..y1 (perimeter tiles), as built walls, except the tiles in `gaps` and the tiles that hold a
## placeable (kept: they block anyway). A gap in a north or south side is a way out; in a west or east side a single gap
## is the face tile of the wall above it (blocked, like a dungeon wall's: a sideways way needs two tiles).
static func ring(d: WorldData, x0: int, y0: int, x1: int, y1: int, gaps: Array[Vector2i]) -> void:
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var c: Vector2i = Vector2i(x, y)
			if (x == x0 or x == x1 or y == y0 or y == y1) and not gaps.has(c) \
					and d.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_NONE:
				d.set_value(WorldData.Layer.VEGETATION, c, 0)
				put(d, c, Walls.KIND_STONE)


func _check_sealing() -> void:
	check_eq(Config.BUILD_SEAL_REACH_TILES, 12, "the provisional reach")
	# A ring around the altar (every spawn slot within 12 of every inside tile), one gap on the west side.
	var d: WorldData = _seed_world()
	var gap: Vector2i = Vector2i(56, 49)
	ring(d, 56, 39, 70, 57, [gap + UP, gap])
	var spots: Array[Vector2] = WorldItems.reserved_feet(d)
	for s: Vector2 in spots.slice(1):
		check(Building.reaches(d, Aim.feet_cell(s), {} as Dictionary[Vector2i, bool]), "slot %s walks out through the gap" % s)
	check(Movement.is_blocked(d, gap + UP) and not Movement.is_blocked(d, gap), "a two-tile gap on the west side: one way out")
	var feet: Vector2 = on(gap + Vector2i(-1, 1))
	check_eq(Building.refusal(d, feet, &"stone_wall", gap, 9), Building.WHY_SEALS, "the wall closing the ring: refused")
	check_eq(Building.refusal(d, feet, &"lantern", gap, 9), Building.WHY_SEALS, "a lantern closing it: refused")
	check_eq(Building.refusal(d, feet, &"stone_floor", gap, 9), "", "a floor (nothing blocks)")
	check_eq(Building.refusal(d, feet, &"door", gap, 9), Building.WHY_DOOR_BELOW, "(a door there: a wall below it)")
	# The gap on the north side, where a door has open ground below: the door is allowed (anyone opens it).
	var d2: WorldData = _seed_world()
	var gap2: Vector2i = Vector2i(63, 39)
	ring(d2, 56, 39, 70, 57, [gap2])
	for c: Vector2i in [gap2 + DOWN]:
		d2.set_value(WorldData.Layer.VEGETATION, c, 0)
	var feet2: Vector2 = on(gap2 + Vector2i(-1, -1))
	check_eq(Building.refusal(d2, feet2, &"stone_wall", gap2, 9), Building.WHY_SEALS, "a wall closing the north gap: refused")
	check_eq(Building.refusal(d2, feet2, &"door", gap2, 9), "", "a door there: allowed (doors count as open)")
	put(d2, gap2, Walls.KIND_DOOR)
	for s2: Vector2 in WorldItems.reserved_feet(d2).slice(1):
		check(Building.reaches(d2, Aim.feet_cell(s2), {} as Dictionary[Vector2i, bool]), "slot %s walks out through the door" % s2)
	# A bigger ring (13 tiles from the slots): no slot is walled in, so the last wall is allowed.
	var d3: WorldData = _seed_world()
	var gap3: Vector2i = Vector2i(50, 48)
	ring(d3, 50, 34, 77, 62, [gap3])
	check_eq(Building.refusal(d3, on(gap3 + Vector2i(-1, -1)), &"stone_wall", gap3, 9), "", "a big ring may close")
	# The entrance's arrival point: walls around it; the last one refused.
	var d4: WorldData = _seed_world()
	var arrive: Vector2i = Aim.feet_cell(DungeonGen.arrival_below(SurfaceGen.entrance_rect(d4)))
	var g4: Vector2i = arrive + Vector2i(0, 3)
	ring(d4, arrive.x - 3, arrive.y - 2, arrive.x + 3, arrive.y + 3, [g4])
	check(Building.reaches(d4, arrive, {} as Dictionary[Vector2i, bool]), "the arrival point walks out through the south gap")
	check_eq(Building.refusal(d4, on(g4 + Vector2i(1, 1)), &"stone_wall", g4, 9), Building.WHY_SEALS, "the arrival point walled in")
	# A station closing a ring (WorldItems.place uses the same rule).
	var d5: WorldData = _seed_world()
	var g5: Array[Vector2i] = [Vector2i(62, 57), Vector2i(63, 57), Vector2i(64, 57)]
	ring(d5, 56, 39, 70, 57, g5)
	for c5: Vector2i in g5:
		d5.set_value(WorldData.Layer.VEGETATION, c5, 0)
	var o5: WorldItems.Outcome = WorldItems.place(d5, on(Vector2i(63, 58)), inv_with([[&"workbench", 1]]), 0, Vector2i(63, 57))
	check_eq(o5.why, Building.WHY_SEALS, "a workbench closing the ring: refused")
	# The altar put down inside a closed ring: its spawn slots walled in.
	var d6: WorldData = _seed_world()
	ring(d6, 20, 20, 32, 32, [] as Array[Vector2i])
	apply(d6, AltarMove.pickup_edits(d6))
	var rect: Rect2i = Rect2i(25, 25, 3, 3)
	check_eq(AltarMove.place_refusal(d6, rect), AltarMove.WHY_WALLED_IN, "the altar in a closed ring: refused")
	ring(d6, 20, 20, 32, 32, [] as Array[Vector2i])
	put(d6, Vector2i(26, 20), Walls.KIND_DOOR)
	check_eq(AltarMove.place_refusal(d6, rect), "", "with a door in the ring: allowed")
	# reaches(): blocked start, extra cells.
	var p: WorldData = _plain(Vector2i(40, 40))
	check(Building.reaches(p, Vector2i(20, 20), {} as Dictionary[Vector2i, bool]), "open ground reaches")
	put(p, Vector2i(20, 20), Walls.KIND_STONE)
	check(not Building.reaches(p, Vector2i(20, 20), {} as Dictionary[Vector2i, bool]), "a blocked start reaches nothing")
	var box: Dictionary[Vector2i, bool] = {}
	for i: int in range(-2, 3):
		for c6: Vector2i in [Vector2i(5 + i, 3), Vector2i(5 + i, 7), Vector2i(3, 5 + i), Vector2i(7, 5 + i)]:
			box[c6] = true
	check(not Building.reaches(p, Vector2i(5, 5), box), "extra blocked cells around it: walled in")


# --- collision -----------------------------------------------------------------------------------------

static func walk(d: WorldData, from: Vector2, dir: Vector2i, ticks: int) -> Vector2:
	var p: Vector2 = from
	for i: int in ticks:
		p = Movement.step(d, p, dir, TICK)
	return p


func _check_collision() -> void:
	var d: WorldData = _plain()
	put(d, Vector2i(10, 10), Walls.KIND_STONE)
	put(d, Vector2i(12, 10), Walls.KIND_DOOR)
	put(d, Vector2i(14, 10), Walls.KIND_FLOOR)
	var from_s: Vector2 = Vector2(10.5 * 16, 15 * 16)
	check_eq(walk(d, from_s, Vector2i(0, -1), 180).y, 12 * 16 + Config.FEET_HEIGHT, "north into a wall: stops at its face's bottom")
	check_eq(walk(d, Vector2(10.5 * 16, 6 * 16), Vector2i(0, 1), 180).y, 10 * 16.0, "south into a wall: stops at its top")
	check_eq(walk(d, Vector2(12.5 * 16, 15 * 16), Vector2i(0, -1), 180).y, 12 * 16 + Config.FEET_HEIGHT, "a closed door stops it")
	put(d, Vector2i(12, 10), Walls.KIND_DOOR_OPEN)
	check(walk(d, Vector2(12.5 * 16, 15 * 16), Vector2i(0, -1), 180).y < 9 * 16, "an open door lets it through (and its face)")
	check(walk(d, Vector2(14.5 * 16, 15 * 16), Vector2i(0, -1), 180).y < 9 * 16, "a floor piece is walked over")
	var side: Vector2 = walk(d, Vector2(8 * 16, 10.5 * 16), Vector2i(1, 0), 120)
	check_eq(side.x, 10 * 16 - Config.FEET_HALF_WIDTH, "east into the wall's side: flush")
	var row: WorldData = _plain()
	for x: int in range(3, 19):
		put(row, Vector2i(x, 10), Walls.KIND_STONE)
	var slide: Vector2 = walk(row, Vector2(5 * 16, 13 * 16), Vector2i(1, -1), 60)
	check(slide.x > 5 * 16 + 40 and is_equal_approx(slide.y, 12 * 16 + Config.FEET_HEIGHT),
		"a diagonal slides east along a wall's face (%s)" % slide)
	check(Movement.can_stand(d, walk(d, from_s, Vector2i(-1, -1), 300)), "never inside a wall")


static func _due(queue: Array[Array]) -> int:
	var t: int = queue[0][0]
	return t


## The dungeon test's prediction walk among built walls and doors: the client's prediction never needs a correction.
func _check_prediction() -> void:
	var d: WorldData = _plain(Vector2i(30, 24))
	for x: int in range(6, 20):
		put(d, Vector2i(x, 6), Walls.KIND_STONE)
		put(d, Vector2i(x, 16), Walls.KIND_STONE)
	for y: int in range(6, 17):
		put(d, Vector2i(6, y), Walls.KIND_STONE)
		put(d, Vector2i(19, y), Walls.KIND_STONE)
	put(d, Vector2i(12, 16), Walls.KIND_DOOR_OPEN)
	put(d, Vector2i(15, 16), Walls.KIND_DOOR)
	put(d, Vector2i(10, 10), Walls.KIND_STONE)
	put(d, Vector2i(14, 12), Walls.KIND_FLOOR)
	var start: Vector2 = on(Vector2i(12, 12))
	var host: PlayerSim = PlayerSim.new()
	host.pos = start
	var client: Prediction = Prediction.new()
	client.setup(d, start, RigData.Dir.SOUTH, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var queue: Array[Array] = []
	var dir: Vector2i = Vector2i.ZERO
	var blocked: int = 0
	var outside: int = 0
	for t: int in 1500:
		if t % 30 == 0:
			dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var sent: NetProtocol.InputFrame = client.step_frame(NetProtocol.InputFrame.new(0, dir))
		if sent != null:
			var before: Vector2 = host.pos
			host.step(d, sent.dir, sent.look, -1, Vector2i.ZERO, Config.NET_TICK)
			if dir != Vector2i.ZERO and host.pos.distance_to(before) < 1.0:
				blocked += 1
			if host.pos.y > 17 * 16:
				outside += 1
			var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
			st.pos = host.pos
			st.facing = host.facing
			st.walking = host.walking
			st.ack = sent.seq
			st.map = Config.MAP_SURFACE
			queue.append([t + 6, st])
		while not queue.is_empty() and _due(queue) <= t:
			var item: Array = queue.pop_front()
			var state: NetProtocol.PlayerState = item[1]
			client.reconcile(state)
	check(blocked > 50, "the walk ran into built walls and the closed door (%d blocked steps)" % blocked)
	check_eq(client.max_error_px, 0.0, "prediction = host among built walls and doors (never corrected)")
	check(Movement.can_stand(d, host.pos), "never inside a wall")
	note("prediction walk: %d blocked steps, %d ticks south of the room (out through the open door)" % [blocked, outside])


# --- heretics and shots -------------------------------------------------------------------------------

func _check_heretics_and_shots() -> void:
	var d: WorldData = _plain(Vector2i(30, 24))
	for x: int in range(8, 17):
		put(d, Vector2i(x, 8), Walls.KIND_STONE)
		put(d, Vector2i(x, 14), Walls.KIND_STONE)
	for y: int in range(8, 15):
		put(d, Vector2i(8, y), Walls.KIND_STONE)
		put(d, Vector2i(16, y), Walls.KIND_STONE)
	put(d, Vector2i(12, 14), Walls.KIND_DOOR)
	var inside: Vector2 = on(Vector2i(12, 11))
	var out_south: Vector2 = on(Vector2i(12, 18))
	check(not Combat.line_clear(d, Combat.body_point(out_south), Combat.body_point(inside)), "a closed door hides the room")
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	var p: Player = Player.new()
	p.setup(d, "paladin", inside)
	_nodes.append(p)
	var h: HereticSim = a.spawn_heretic(out_south)
	var players: Array[Player] = [p]
	var never_inside: bool = true
	for t: int in 600:
		a.step(players)
		var c: Vector2i = Aim.feet_cell(h.pos)
		if c.y < 15 and c.y > 8 and c.x > 8 and c.x < 16:
			never_inside = false
	check(never_inside and not a.can_target(h, p), "the heretic never gets in nor targets the player behind walls")
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "the player behind the closed door is unhurt")
	put(d, Vector2i(12, 14), Walls.KIND_DOOR_OPEN)
	check(Combat.line_clear(d, Combat.body_point(out_south), Combat.body_point(on(Vector2i(12, 12)))), "through the open door: in sight")
	# A shot stops at a built wall (the arrow's grid walk, Combat.blocks_line).
	check(Combat.blocks_line(d, Vector2i(8, 10)) and Combat.blocks_line(d, Vector2i(9, 9)), "walls and faces stop shots")
	check(not Combat.blocks_line(d, Vector2i(12, 14)) and not Combat.blocks_line(d, Vector2i(12, 15)), "an open doorway does not")
	# The arena's spawn tiles follow building (Arena.sync_world: the built counts changed).
	var w: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var arena: Arena = Arena.new()
	arena.setup(w, 1)
	var spawn: Vector2i = arena.spawn_cells[arena.spawn_cells.size() / 2]
	check(not arena.sync_world(), "nothing changed: no sync")
	put(w, spawn, Walls.KIND_STONE)
	check(arena.sync_world() and not arena.spawn_cells.has(spawn), "a wall on a spawn tile: worked out again, the tile gone")
	put(w, spawn, Walls.KIND_NONE)
	check(arena.sync_world() and arena.spawn_cells.has(spawn), "taken down: the tile back")
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var dun_arena: Arena = Arena.new()
	dun_arena.setup(dun, 1)
	var before: int = dun_arena.spawn_cells.size()
	var f: Vector2i = Aim.feet_cell(DungeonGen.arrival_point(dun))
	var sealed: Array[Vector2i] = []
	for x: int in range(f.x - 12, f.x + 13):
		for y: int in range(f.y - 12, f.y + 13):
			var c: Vector2i = Vector2i(x, y)
			if maxi(absi(x - f.x), absi(y - f.y)) == 3 and dun.in_bounds(c) and not Walls.is_wall(dun, c):
				put(dun, c, Walls.KIND_STONE)
				sealed.append(c)
	check(dun_arena.sync_world() and dun_arena.spawn_cells.size() < before,
		"the dungeon's arrival walled in: its spawn tiles worked out again (%d -> %d)" % [before, dun_arena.spawn_cells.size()])


# --- taking down -------------------------------------------------------------------------------------

func _check_demolish() -> void:
	var d: WorldData = _plain()
	var feet: Vector2 = on(Vector2i(10, 10))
	put(d, Vector2i(11, 9), Walls.KIND_STONE)
	put(d, Vector2i(9, 9), Walls.KIND_DOOR_OPEN)
	put(d, Vector2i(9, 11), Walls.KIND_FLOOR)
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(11, 11), WorldData.PLACEABLE_LANTERN)
	put(d, Vector2i(10, 8), Walls.KIND_ROCK)
	var inv: Inventory = Inventory.new()
	check_eq(Building.demolish(d, feet, inv, Vector2i(10, 9)).why, Building.WHY_NATURAL, "a dungeon wall's face: mined, not taken down")
	put(d, Vector2i(10, 8), Walls.KIND_NONE)
	check_eq(Building.demolish(d, feet, inv, Vector2i(10, 11)).why, Building.WHY_NOT_BUILT, "nothing built")
	check_eq(Building.demolish(d, feet, inv, Vector2i(10, 12)).why, WorldItems.WHY_REACH, "out of reach")
	# [aimed tile, piece back, the tile that changes]
	for row: Array in [[Vector2i(11, 10), &"stone_wall", Vector2i(11, 9)], [Vector2i(9, 9), &"door", Vector2i(9, 9)],
			[Vector2i(9, 11), &"stone_floor", Vector2i(9, 11)], [Vector2i(11, 11), &"lantern", Vector2i(11, 11)]]:
		var at: Vector2i = row[0]
		var o: WorldItems.Outcome = Building.demolish(d, feet, inv, at)
		var where: Vector2i = row[2]
		var piece: StringName = row[1]
		check(o.ok() and o.item == piece and o.count == Config.BUILD_REFUND and o.edits.size() == 1 and o.edits[0].cell == where,
			"right-click on %s takes the %s down (%s)" % [at, row[1], o.why])
		apply(d, o.edits)
	check_eq([inv.count_of(&"stone_wall"), inv.count_of(&"door"), inv.count_of(&"stone_floor"), inv.count_of(&"lantern")],
		[1, 1, 1, 1], "one piece of each back")
	check(Walls.kind_at(d, Vector2i(11, 9)) == 0 and Walls.kind_at(d, Vector2i(9, 9)) == 0 and Walls.kind_at(d, Vector2i(9, 11)) == 0
		and d.get_value(WorldData.Layer.PLACEABLE, Vector2i(11, 11)) == 0, "all gone")
	# A full inventory refuses (nothing changes).
	put(d, Vector2i(11, 9), Walls.KIND_STONE)
	var full: Inventory = Inventory.new()
	for i: int in full.size():
		full.add(&"sword", 1)
	check_eq(Building.demolish(d, feet, full, Vector2i(11, 9)).why, WorldItems.WHY_FULL, "a full inventory")
	check_eq(Walls.kind_at(d, Vector2i(11, 9)), Walls.KIND_STONE, "the wall stays")
	# Anyone's: another class, the same wall.
	check(Building.demolish(d, on(Vector2i(12, 10)), Inventory.new(), Vector2i(11, 9)).ok(), "anyone takes any piece down")


# --- doors ---------------------------------------------------------------------------------------------

func _check_doors() -> void:
	var d: WorldData = _plain()
	put(d, Vector2i(10, 9), Walls.KIND_DOOR)
	var feet: Vector2 = on(Vector2i(11, 11))
	check_eq(Building.door_cell(d, Vector2i(10, 10)), Vector2i(10, 9), "its face tile reaches the door")
	check_eq(Building.door_cell(d, Vector2i(10, 9)), Vector2i(10, 9), "the door tile")
	check_eq(Building.door_cell(d, Vector2i(10, 11)), Walls.NO_CELL, "below the face: no door")
	var o: WorldItems.Outcome = Building.toggle_door(d, feet, Vector2i(10, 10))
	check(o.ok() and o.item == &"open", "F on the face opens it")
	apply(d, o.edits)
	check(Walls.is_open_door(d, Vector2i(10, 9)) and not Movement.is_blocked(d, Vector2i(10, 10)), "open: the doorway is free")
	# An open door is still a wall: nothing goes on it or its doorway (a torch, a debug drop, a death bag).
	for c0: Vector2i in [Vector2i(10, 9), Vector2i(10, 10)]:
		var near: Vector2 = on(c0 + Vector2i(1, 0))
		check_eq(WorldItems.place(d, near, inv_with([[&"torch", 1]]), 0, c0).why, WorldItems.WHY_NOT_OPEN, "no torch on %s" % c0)
		check_eq(WorldItems.drop(d, near, inv_with([[&"stone_a", 1]]), 0, 0, c0).why, WorldItems.WHY_BLOCKED, "no drop on %s" % c0)
		check(not WorldItems.bag_spot_ok(d, c0), "no death bag on %s" % c0)
	var bodies: Array[Vector2] = [on(Vector2i(10, 10))]
	check_eq(Building.toggle_door(d, feet, Vector2i(10, 10), bodies).why, Building.WHY_DOORWAY, "someone in the doorway: not closed")
	check_eq(Building.toggle_door(d, on(Vector2i(10, 10)), Vector2i(10, 9)).why, Building.WHY_DOORWAY,
		"the closer's own feet in the doorway: not closed")
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(10, 9), WorldData.PLACEABLE_BAG)
	check_eq(Building.toggle_door(d, feet, Vector2i(10, 10)).why, Building.WHY_DOORWAY, "a death bag in the doorway: not closed")
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(10, 9), 0)
	var c: WorldItems.Outcome = Building.toggle_door(d, on(Vector2i(9, 11)), Vector2i(10, 10))
	check(c.ok() and c.item == &"closed", "another player closes it (anyone, Config.DOOR_ANYONE)")
	apply(d, c.edits)
	check(Movement.is_blocked(d, Vector2i(10, 9)) and Movement.is_blocked(d, Vector2i(10, 10)), "closed: blocks again")
	check_eq(Building.toggle_door(d, feet, Vector2i(12, 10)).why, Building.WHY_NO_DOOR, "no door there")
	check_eq(Building.toggle_door(d, on(Vector2i(10, 13)), Vector2i(10, 10)).why, WorldItems.WHY_REACH, "out of reach")


# --- mining ----------------------------------------------------------------------------------------------

func _check_mining() -> void:
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var f: Vector2i = Aim.feet_cell(DungeonGen.arrival_point(d))
	# A built wall in the arrival room: a pickaxe swing at it or its face does nothing.
	var c: Vector2i = f + Vector2i(1, 1)
	put(d, c, Walls.KIND_STONE)
	var before: String = d.content_hash()
	var r: Mining.Result = Mining.strike(d, on(f), "paladin", Inventory.new(), c)
	check_eq(r.why, Mining.WHY_TOO_HARD, "a pickaxe at a built wall: too hard")
	var r2: Mining.Result = Mining.strike(d, on(f + Vector2i(1, 2) + Vector2i(1, 0)), "miner", Inventory.new(), c + DOWN)
	check_eq(r2.why, Mining.WHY_TOO_HARD, "the miner at its face: too hard")
	check_eq(d.content_hash(), before, "nothing changed")
	# The miner's 3x3 on rock next to a built wall skips the built one.
	var rock: Vector2i = Walls.NO_CELL
	for w: Vector2i in Walls.wall_cells(d):
		if Walls.kind_at(d, w) == Walls.KIND_ROCK and Walls.ore_at(d, w) == 0 and Walls.is_face(d, w + DOWN) \
				and not Movement.is_blocked(d, w + DOWN + DOWN) and Walls.kind_at(d, w + Vector2i(1, 0)) == Walls.KIND_ROCK \
				and Walls.hardness(d, w + Vector2i(1, 0)) == Config.HARDNESS_ROCK:
			rock = w
			break
	if check(rock != Walls.NO_CELL, "a rock to mine"):
		put(d, rock + Vector2i(1, 0), Walls.KIND_STONE)  # past the rules: a built wall inside the 3x3
		var r3: Mining.Result = Mining.strike(d, on(rock + DOWN + DOWN), "miner", Inventory.new(), rock + DOWN)
		check(r3.ok() and not r3.hit.has(rock + Vector2i(1, 0)), "the 3x3 skips the built wall")
		for e: EditLog.WorldEdit in r3.edits:
			check(e.cell != rock + Vector2i(1, 0), "no edit on the built wall")


# --- fields and the altar ----------------------------------------------------------------------------------

func _check_fields_and_altar() -> void:
	var d: WorldData = _seed_world()
	var c: Vector2i = Vector2i(66, 51)
	check_eq(Farming.till_refusal(d, on(Vector2i(66, 52)), c), "", "grass in the light: tillable")
	put(d, c, Walls.KIND_FLOOR)
	check_eq(Farming.till_refusal(d, on(Vector2i(66, 52)), c), Farming.WHY_NO_GROUND, "a floor piece: no tilling")
	put(d, c, Walls.KIND_NONE)
	# The altar may not go down on built walls or doors, nor leave a spawn slot walled in (above); on a floor piece it may.
	apply(d, AltarMove.pickup_edits(d))
	var rect: Rect2i = Rect2i(40, 40, 3, 3)
	check_eq(AltarMove.place_refusal(d, rect), "", "the bare spot")
	put(d, Vector2i(41, 41), Walls.KIND_DOOR_OPEN)
	check_eq(AltarMove.place_refusal(d, rect), AltarMove.WHY_NOT_OPEN, "not over an (open) door")
	put(d, Vector2i(41, 41), Walls.KIND_FLOOR)
	check_eq(AltarMove.place_refusal(d, rect), "", "over a floor piece")
	put(d, Vector2i(41, 39), Walls.KIND_STONE)
	check_eq(AltarMove.place_refusal(d, rect), AltarMove.WHY_NOT_OPEN, "not where a wall's face hangs (it blocks)")
	put(d, Vector2i(41, 39), Walls.KIND_NONE)
	# A spawn slot inside a wall: no room around it.
	var slot: Vector2i = Aim.feet_cell(AltarMove.slot_feet(rect)[0])
	put(d, slot, Walls.KIND_STONE)
	check_eq(AltarMove.place_refusal(d, rect), AltarMove.WHY_SLOTS, "a spawn slot on a wall: no room")
	put(d, slot, Walls.KIND_NONE)
	# The set-down search goes around built walls.
	for x: int in range(38, 46):
		for y: int in range(38, 46):
			put(d, Vector2i(x, y), Walls.KIND_STONE)
	var down: Rect2i = AltarMove.set_down_rect(d, on(Vector2i(41, 41)))
	var clear: bool = down.has_area()
	for y2: int in range(down.position.y, down.end.y):
		for x2: int in range(down.position.x, down.end.x):
			clear = clear and not Movement.is_blocked(d, Vector2i(x2, y2))
	check(clear, "the set-down search finds a footprint clear of the walls (%s)" % down)


# --- the build view -------------------------------------------------------------------------------------------

func _check_view() -> void:
	var d: WorldData = _plain()
	# A 5x4 room: walls round, a door south, a floor inside, an L of walls elsewhere.
	for x: int in range(2, 7):
		put(d, Vector2i(x, 2), Walls.KIND_STONE)
		put(d, Vector2i(x, 5), Walls.KIND_STONE)
	for y: int in range(3, 5):
		put(d, Vector2i(2, y), Walls.KIND_STONE)
		put(d, Vector2i(6, y), Walls.KIND_STONE)
	put(d, Vector2i(4, 5), Walls.KIND_DOOR)
	put(d, Vector2i(3, 4), Walls.KIND_FLOOR)
	put(d, Vector2i(10, 10), Walls.KIND_STONE)
	put(d, Vector2i(11, 10), Walls.KIND_STONE)
	put(d, Vector2i(10, 11), Walls.KIND_STONE)
	check_eq(BuildView.mask_of(d, Vector2i(2, 2)), 2 | 4, "the room's north-west corner: east and south")
	check_eq(BuildView.mask_of(d, Vector2i(4, 2)), 2 | 8, "the north wall's middle: east and west")
	check_eq(BuildView.mask_of(d, Vector2i(4, 5)), 2 | 8, "the door is in the south wall (east and west)")
	check_eq(BuildView.mask_of(d, Vector2i(10, 10)), 2 | 4, "the L's corner")
	check(not BuildView.shows_face(d, Vector2i(2, 2)) and BuildView.shows_face(d, Vector2i(3, 2)),
		"the corner has a wall below (no face); the north wall's next tile shows one")
	check_eq(BuildView.face_of(d, Vector2i(3, 2)), BuildView.Face.LEFT_END, "a face with a face east of it: the left end")
	check_eq(BuildView.face_of(d, Vector2i(4, 2)), BuildView.Face.MIDDLE, "in the middle")
	check_eq(BuildView.face_of(d, Vector2i(5, 2)), BuildView.Face.RIGHT_END, "the right end")
	check_eq(BuildView.face_of(d, Vector2i(11, 10)), BuildView.Face.LONE, "a lone face")
	# Parts: top by mask, the L's inner corner dot (south-east: east and south walls, no wall between), faces and doors.
	var l_parts: Array[Array] = BuildView.wall_parts(d, Vector2i(10, 10))
	check_eq(l_parts.size(), 2, "the L corner: its top and its SE dot (no face: a wall below)")
	check_eq(l_parts[1][0], Rect2i(32, 32, 16, 16), "the SE dot cell")
	var door_parts: Array[Array] = BuildView.wall_parts(d, Vector2i(4, 5))
	check_eq(door_parts[door_parts.size() - 1], [Rect2i(64, 48, 16, 24), Vector2i(4, 6) * 16], "the closed door's face below it")
	put(d, Vector2i(4, 5), Walls.KIND_DOOR_OPEN)
	var open_parts: Array[Array] = BuildView.wall_parts(d, Vector2i(4, 5))
	check_eq(open_parts[open_parts.size() - 1][0], Rect2i(80, 48, 16, 24), "the open door's face")
	check_eq(BuildView.wall_parts(d, Vector2i(4, 2))[0][0], Rect2i(((2 | 8) % 8) * 16, ((2 | 8) / 8) * 16, 16, 16), "top by mask")
	for c: Vector2i in [Vector2i(0, 0), Vector2i(5, 9), Vector2i(31, 17)]:
		check_eq(BuildView.floor_rect(c).position.y, 32, "floor variant row (%s)" % c)
	# GameWorld: the view follows the edits.
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	check(w.builds != null and w.builds.get_parent() == w and w.builds.get_index() < w.entities.get_index()
		and w.builds.get_index() > w.decals.get_index(), "the build view: above the decals, below the entities")
	check_eq(w.builds.light_mask, Config.LIGHT_LAYER_WORLD, "lit like the ground")
	var rev: int = w.revision
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(66, 51), Walls.pack(Walls.KIND_STONE, 0)))
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(67, 51), Walls.pack(Walls.KIND_FLOOR, 0)))
	check_eq(w.revision, rev + 2, "two edits counted")
	check_eq(w.builds.verify(), {"built": 2, "mismatches": 0} as Dictionary[String, int], "the view has both")
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(66, 51), 0))
	check_eq(w.builds.verify(), {"built": 1, "mismatches": 0} as Dictionary[String, int], "taken down: gone from the view")
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(66, 52), WorldData.PLACEABLE_LANTERN))
	var fx: Dictionary[String, int] = w.fixtures.verify()
	check(fx["mismatches"] == 0 and w.fixtures.light_nodes.has(Vector2i(66, 52)), "the lantern post drawn with its light")
	var post: Node2D = w.fixtures.nodes.get(Vector2i(66, 52), null)
	check(post != null and post.position == Vector2(66 * 16 + 8, 53 * 16) and post.get_parent() == w.entities,
		"the post's node at its tile's bottom edge, among the entities (y-sorted)")
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(66, 52), 0))
	check(not w.fixtures.light_nodes.has(Vector2i(66, 52)) and w.fixtures.verify()["mismatches"] == 0, "taken down: no light")


# --- main.tscn -----------------------------------------------------------------------------------------------

func _click(main: Main, p: Player, target: Vector2i) -> void:
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, Vector2(target * Config.TILE) + Vector2(8, 8), true, true, true, TICK)
	main.step_combat(TICK)


func _aim(main: Main, p: Player, target: Vector2i) -> void:
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, Vector2(target * Config.TILE) + Vector2(8, 8), true, false, false, TICK)
	main._show_build_ghost()


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null, "main has an offline player"):
		return
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	var data: WorldData = main.world.data
	p.inventory.clear()
	p.inventory.add(&"stone_wall", 6)
	p.inventory.add(&"door", 1)
	p.inventory.add(&"lantern", 1)
	p.inventory.add(&"stone_floor", 4)
	p.inventory.select(0)
	p.teleport(on(Vector2i(65, 52)))
	# The ghost: gold on open ground, red where it may not go (a stone there; the face on my own feet).
	_aim(main, p, Vector2i(66, 51))
	check(main.build_ghost.visible and main.build_ghost.allowed and main.build_ghost.piece == &"stone_wall"
		and main.build_ghost.position == Vector2(66 * 16, 51 * 16), "the ghost: the wall, allowed, on the aimed tile")
	data.set_value(WorldData.Layer.VEGETATION, Vector2i(66, 51), WorldItems.value_of(&"stone_a"))
	main.world.revision += 1
	_aim(main, p, Vector2i(66, 51))
	check(main.build_ghost.visible and not main.build_ghost.allowed, "on a stone: red")
	data.set_value(WorldData.Layer.VEGETATION, Vector2i(66, 51), 0)
	main.world.revision += 1
	_aim(main, p, Vector2i(65, 51))
	check(main.build_ghost.visible and not main.build_ghost.allowed, "right north: its face on my feet, red")
	# A click builds (one piece in the light).
	_click(main, p, Vector2i(66, 51))
	check_eq(Walls.kind_at(data, Vector2i(66, 51)), Walls.KIND_STONE, "a click put the wall down")
	check_eq(p.inventory.count_of(&"stone_wall"), 5, "one piece used (in the light)")
	check_eq(main.world.builds.verify()["built"], 1, "drawn")
	# The door east of it: F opens and closes it.
	p.inventory.select(1)
	p.teleport(on(Vector2i(68, 52)))
	_click(main, p, Vector2i(67, 51))
	check_eq(Walls.kind_at(data, Vector2i(67, 51)), Walls.KIND_DOOR, "the door down")
	p.teleport(on(Vector2i(68, 53)))
	p.aim_sector = Aim.sector(Vector2(67 * 16 + 8, 52 * 16 + 8) - p.sim_position, p.aim_sector)
	p.aim_cell = Aim.target_cell(p.sim_position, p.aim_sector)
	check_eq(p.aim_cell, Vector2i(67, 52), "aimed at the door's face")
	main.pick_up()
	check_eq(Walls.kind_at(data, Vector2i(67, 51)), Walls.KIND_DOOR_OPEN, "F opened it")
	main.pick_up()
	check_eq(Walls.kind_at(data, Vector2i(67, 51)), Walls.KIND_DOOR, "F again closed it")
	# Right-click takes the wall down (a piece back).
	p.teleport(on(Vector2i(65, 51)))
	p.aim_sector = Aim.sector(Vector2(66 * 16 + 8, 51 * 16 + 8) - p.sim_position, p.aim_sector)
	p.aim_cell = Aim.target_cell(p.sim_position, p.aim_sector)
	main.demolish()
	check_eq(Walls.kind_at(data, Vector2i(66, 51)), Walls.KIND_NONE, "right-click took the wall down")
	check_eq(p.inventory.count_of(&"stone_wall"), 6, "and gave the piece back")
	# A lantern post with its light; the ghost hides when no piece is selected.
	p.inventory.select(2)
	p.teleport(on(Vector2i(65, 52)))
	_click(main, p, Vector2i(66, 51))
	check(data.get_value(WorldData.Layer.PLACEABLE, Vector2i(66, 51)) == WorldData.PLACEABLE_LANTERN
		and main.world.fixtures.light_nodes.has(Vector2i(66, 51)), "the lantern post down, lit")
	p.inventory.add(&"sword", 1)
	p.inventory.select(4)
	_aim(main, p, Vector2i(66, 53))
	check(not main.build_ghost.visible, "a sword selected: no ghost")
	# The dungeon: the ghost goes with the map.
	main.travel(Config.MAP_DUNGEON)
	check(main.build_ghost.get_parent() == main.worlds[Config.MAP_DUNGEON], "the ghost moved to the dungeon")
	main.travel(Config.MAP_SURFACE)


# --- a session --------------------------------------------------------------------------------------------

func _check_session() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"BuildingTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var m: NetMember = s.add_member(2, 7, "miner", on(Vector2i(66, 50)), RigData.Dir.SOUTH)
	m.gate = InputGate.new()
	var seq: int = 1
	# M7c (changed on purpose: M7b's host refused every piece): the host builds each piece with the offline rules (one
	# edit each, cost 1 in the light), opens and closes the door (DOOR) and takes the wall down (DEMOLISH).
	var at: Dictionary[StringName, Vector2i] = {&"stone_wall": Vector2i(65, 51), &"door": Vector2i(67, 51),
		&"stone_floor": Vector2i(66, 51), &"lantern": Vector2i(67, 49)}
	for id: StringName in Building.PIECES:
		m.player.inventory.clear()
		m.player.inventory.add(id, 3)
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(seq, Vector2i.ZERO)
		seq += 1
		f.op = NetProtocol.Op.USE
		f.slot = 0
		f.cell = at[id]
		f.map = Config.MAP_SURFACE
		m.player.begin_tick()
		host.run_frame(m, f)
		check_eq(m.player.inventory.count_of(id), 2, "%s: built for 1 in the light (refusals %s)" % [id, m.ops_refused])
		for t: int in Config.NET_OP_INTERVAL_TICKS:
			m.refill_ops()
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 4, "one edit each on the host's map")
	check(Walls.kind_at(world.data, Vector2i(65, 51)) == Walls.KIND_STONE and Walls.is_door(world.data, Vector2i(67, 51))
		and Walls.is_floor_piece(world.data, Vector2i(66, 51))
		and world.data.get_value(WorldData.Layer.PLACEABLE, Vector2i(67, 49)) == WorldData.PLACEABLE_LANTERN,
		"the wall, the closed door, the floor and the lantern stand")
	for op: Array in [[NetProtocol.Op.DOOR, Vector2i(67, 51)], [NetProtocol.Op.DOOR, Vector2i(67, 51)],
			[NetProtocol.Op.DEMOLISH, Vector2i(65, 51)]]:
		var g: NetProtocol.InputFrame = NetProtocol.InputFrame.new(seq, Vector2i.ZERO)
		seq += 1
		g.op = op[0]
		g.cell = op[1]
		g.map = Config.MAP_SURFACE
		m.player.begin_tick()
		host.run_frame(m, g)
		for t: int in Config.NET_OP_INTERVAL_TICKS:
			m.refill_ops()
	check(Walls.is_door(world.data, Vector2i(67, 51)) and not Walls.is_open_door(world.data, Vector2i(67, 51)),
		"F on the door opened it, F again closed it (two DOOR requests)")
	check_eq(Walls.kind_at(world.data, Vector2i(65, 51)), Walls.KIND_NONE, "right-click on the wall took it down")
	check_eq(m.player.inventory.count_of(&"stone_wall"), Config.BUILD_REFUND, "one wall back")
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 7, "three more edits")
	check(m.ops_refused.is_empty(), "nothing refused (%s)" % m.ops_refused)


## The same building twice: the same edits and world hash.
func _check_determinism() -> void:
	var hashes: PackedStringArray = []
	for run_i: int in 2:
		var d: WorldData = _seed_world()
		var inv: Inventory = inv_with([[&"stone_wall", 20], [&"door", 2], [&"stone_floor", 8], [&"lantern", 2]])
		var steps: Array[Array] = [[Vector2i(66, 52), 0, Vector2i(66, 51)], [Vector2i(67, 52), 0, Vector2i(67, 51)],
			[Vector2i(68, 52), 1, Vector2i(68, 51)], [Vector2i(69, 53), 2, Vector2i(69, 52)], [Vector2i(70, 53), 3, Vector2i(70, 52)]]
		var out: PackedStringArray = []
		for st: Array in steps:
			var at: Vector2i = st[0]
			var slot: int = st[1]
			var target: Vector2i = st[2]
			var o: WorldItems.Outcome = Building.build(d, on(at), inv, slot, target)
			apply(d, o.edits)
			out.append("%s:%s" % [o.why, inv.describe()])
		out.append(d.content_hash())
		hashes.append("|".join(out))
	check_eq(hashes[0], hashes[1], "the same building twice: the same steps and world hash")
