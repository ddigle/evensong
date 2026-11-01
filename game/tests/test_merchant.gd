extends "res://tests/base_test.gd"
## M8a, the merchant beside the altar (items/merchant.gd; ● gameplay-design §3.0 R11 "제단 곁 상인 NPC", required in the slice;
## where and how PROVISIONAL, README "임시값" M8a): the placement rule (seed 1's preferred tile; every altar position the altar
## may take across the map against a rule written out here: lit, a tile from the altar, open grass, no spot where players appear,
## the nearest such tile by rings around the preferred one; blocked neighbourhoods: fields, crops, gatherables, corruption,
## drops, built walls and faces, the chest, stations, torches, trees, a death bag, a body, the arrival point; a floor piece is
## fine), lifting and putting the altar down (he waits, then moves by the same rule), his tile kept free (walking, building every
## piece, placing a torch, a table or the chest, tilling, dropping, the altar, a death bag), heretics (never targeted, never walked
## into, never spawned on him; the spawn tiles do not see him), and main.tscn: he stands there when the world starts, F in reach
## opens the shop panel (not from further, not aimed elsewhere), the panel's place and clicks (buy, sell one, shift sells the
## stack), Tab / F / Esc close it, walking out of reach, going down and another map close it, the prompt over him, the shop's
## clock on the physics ticks.

const TICK: float = 1.0 / 60.0
## Seed 1: the altar's footprint and the merchant's tile (MERCHANT_OFFSET from its top-left), written out.
const ALTAR_AT: Vector2i = Vector2i(62, 46)
const SPOT: Vector2i = Vector2i(67, 50)

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_seed_one()
	_check_many_altars()
	_check_blocked()
	_check_settle()
	_check_seal()
	_check_reach_and_clearance()
	_check_altar_beside_him()
	_check_tile_kept()
	_check_heretics()
	await _check_test_flags()
	await _check_main()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func apply(d: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(d, e)


static func move_altar(d: WorldData, rect: Rect2i) -> void:
	if d.altar_rect.has_area():
		apply(d, AltarMove.pickup_edits(d))
	apply(d, AltarMove.place_edits(rect))


## Written out here: tile `c` may hold the merchant for `d`'s altar (no seal, clearance or reach test: none of the worlds
## here can seal, has a client or walls him in; _check_seal and _check_reach_and_clearance check those rules).
static func allowed(d: WorldData, c: Vector2i) -> bool:
	if not d.in_bounds(c) or not d.altar_rect.has_area():
		return false
	var centre: Vector2 = (Vector2(d.altar_rect.position) + Vector2(1.5, 1.5)) * Config.TILE
	for corner: Vector2i in [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(1, 1)]:
		if Vector2(corner * Config.TILE).distance_to(centre) > Config.safe_radius_px():
			return false
	var r: Rect2i = d.altar_rect
	var gap: int = maxi(maxi(r.position.x - c.x, c.x - (r.end.x - 1)), maxi(r.position.y - c.y, c.y - (r.end.y - 1)))
	if gap < 2:
		return false
	if d.terrain_at(c) != Terrain.GRASS or d.get_value(WorldData.Layer.CORRUPTION, c) != 0 \
			or d.get_value(WorldData.Layer.VEGETATION, c) != 0 or d.get_value(WorldData.Layer.PLACEABLE, c) != 0 \
			or d.get_value(WorldData.Layer.WALL, c) != 0 or d.get_value(WorldData.Layer.WALL, c + Vector2i(0, -1)) != 0 \
			or not d.drops_at(c).is_empty():
		return false
	var px: Rect2 = Rect2(Vector2(c * Config.TILE), Vector2(16, 16))
	var feet: Array[Vector2] = []
	for o: Vector2i in Config.SPAWN_SLOTS:
		feet.append(centre + Vector2(o))
	var way: Rect2i = SurfaceGen.entrance_rect(d)
	if way.has_area():
		feet.append(Vector2((way.position.x + way.size.x / 2.0) * Config.TILE, way.end.y * Config.TILE + Config.TILE
			- Config.ARRIVAL_FEET_INSET_PX))
	for f: Vector2 in feet:
		if px.intersects(Rect2(f.x - 5.0, f.y - 4.0, 10.0, 4.0)):
			return false
	return true


## Written out here: the first allowed tile by rings around `want` (Chebyshev, out to Config.MERCHANT_SEARCH_TILES), row by row
## in a ring; Walls.NO_CELL for none.
static func first_allowed(d: WorldData, want: Vector2i) -> Vector2i:
	for ring: int in Config.MERCHANT_SEARCH_TILES + 1:
		for y: int in range(want.y - ring, want.y + ring + 1):
			for x: int in range(want.x - ring, want.x + ring + 1):
				if maxi(absi(x - want.x), absi(y - want.y)) == ring and allowed(d, Vector2i(x, y)):
					return Vector2i(x, y)
	return Walls.NO_CELL


func _check_seed_one() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	check_eq(d.altar_rect.position, ALTAR_AT, "seed 1's altar")
	check_eq(Config.MERCHANT_OFFSET, SPOT - ALTAR_AT, "the preferred tile = MERCHANT_OFFSET from the altar's top-left")
	check_eq(Merchant.preferred_tile(d), SPOT, "preferred tile")
	check_eq(Merchant.spot_refusal(d, SPOT), "", "seed 1: the preferred tile is allowed")
	check(allowed(d, SPOT), "and by the written-out rule")
	check_eq(Merchant.spot_for(d), SPOT, "so he stands there")
	check_eq(Merchant.tile_of(d), Walls.NO_CELL, "the generator puts no merchant down (golden hash unchanged)")
	check_eq(d.content_hash(), SurfaceGen.GOLDEN_HASH, "the generated world's hash is the golden one")
	check(Farming.in_light(d, SPOT), "in the light")
	check_eq(Merchant.feet_of(SPOT), Vector2(SPOT.x * 16 + 8, (SPOT.y + 1) * 16 - Config.ARRIVAL_FEET_INSET_PX),
		"he stands in the middle of his tile, low (an arrival point's place)")
	check(Config.MERCHANT_BLOCKS and WorldData.placeable_blocks(WorldData.PLACEABLE_MERCHANT), "he blocks (PROVISIONAL default)")


## Every altar footprint the placing rule allows on a 4-tile grid over seed 1's map: the merchant's tile is the first allowed
## one by the written-out rule (the preferred tile when it is allowed).
func _check_many_altars() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var home: Rect2i = d.altar_rect
	var tried: int = 0
	var preferred: int = 0
	var fallback: int = 0
	var none: int = 0
	var wrong: int = 0
	var bad_spot: int = 0
	for y: int in range(4, d.size.y - 6, 4):
		for x: int in range(4, d.size.x - 6, 4):
			var rect: Rect2i = Rect2i(Vector2i(x, y), Config.ALTAR_FOOTPRINT)
			apply(d, AltarMove.pickup_edits(d))
			if not AltarMove.place_refusal(d, rect).is_empty():
				apply(d, AltarMove.place_edits(home))
				continue
			apply(d, AltarMove.place_edits(rect))
			tried += 1
			var got: Vector2i = Merchant.spot_for(d)
			var want: Vector2i = first_allowed(d, Merchant.preferred_tile(d))
			if got != want:
				wrong += 1
				if wrong <= 3:
					fail("altar at %s: the merchant on %s, the written-out rule says %s" % [rect.position, got, want])
			if got == Walls.NO_CELL:
				none += 1
			elif got == Merchant.preferred_tile(d):
				preferred += 1
			else:
				fallback += 1
			if got != Walls.NO_CELL and not Merchant.spot_refusal(d, got).is_empty():
				bad_spot += 1
			apply(d, AltarMove.pickup_edits(d))
			apply(d, AltarMove.place_edits(home))
	check_eq(wrong, 0, "every altar position: the first allowed tile by rings (%d positions)" % tried)
	check_eq(bad_spot, 0, "never a tile his own rule refuses")
	check(tried > 300 and preferred > 0 and fallback > 0, "positions tried %d: preferred %d, fallback %d, none %d" % [tried,
		preferred, fallback, none])
	note("many altars: %d positions, preferred tile %d, a fallback %d, none %d" % [tried, preferred, fallback, none])


## Seed 1's preferred tile made unfit in every way the rule names: he goes to the next tile the written-out rule allows; a floor
## piece does not move him.
func _check_blocked() -> void:
	var cases: Array[Array] = [
		["tilled soil (a field)", WorldData.Layer.FLOOR, Terrain.SOIL],
		["a crop", WorldData.Layer.VEGETATION, Farming.Field.new(Farming.KIND_HEALING, 2).value()],
		["a gatherable", WorldData.Layer.VEGETATION, WorldItems.value_of(&"stone_b")],
		["corruption", WorldData.Layer.CORRUPTION, 1],
		["a built stone wall", WorldData.Layer.WALL, Walls.pack(Walls.KIND_STONE, 0)],
		["a closed door", WorldData.Layer.WALL, Walls.pack(Walls.KIND_DOOR, 0)],
		["a torch", WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TORCH],
		["a lantern post", WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_LANTERN],
		["a tree", WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TREE],
		["a death bag", WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_BAG],
	]
	for case: Array in cases:
		var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		var layer: int = case[0 + 1]
		var value: int = case[2]
		d.set_value(layer, SPOT, value)
		var got: Vector2i = Merchant.spot_for(d)
		check(got != SPOT and got != Walls.NO_CELL and got == first_allowed(d, SPOT), "%s on his tile: he goes to %s" % [case[0], got])
	# A wall north of it: its face covers the tile.
	var faced: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	faced.set_value(WorldData.Layer.WALL, SPOT + Vector2i(0, -1), Walls.pack(Walls.KIND_STONE, 0))
	check(Merchant.spot_for(faced) != SPOT, "a built wall's face over the tile")
	# Footprints: the chest, an anvil, a workbench covering it.
	for row: Array in [[WorldData.PLACEABLE_CHEST, Vector2i(3, 1)], [WorldData.PLACEABLE_ANVIL, Vector2i(2, 1)],
			[WorldData.PLACEABLE_WORKBENCH, Vector2i(3, 1)], [WorldData.PLACEABLE_ALCHEMY, Vector2i(3, 1)]]:
		var d2: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		var p: int = row[0]
		var size: Vector2i = row[1]
		d2.put_placeable(Rect2i(SPOT - Vector2i(size.x / 2, 0), size), p)
		var got2: Vector2i = Merchant.spot_for(d2)
		check(got2 != SPOT and got2 == first_allowed(d2, SPOT), "%s on it: he goes to %s" % [WorldData.PLACEABLE_NAMES[p], got2])
	# A drop on it.
	var dropped: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	dropped.drops[1] = WorldData.Drop.new(1, &"stone_a", 3, 0, SPOT * 16 + Vector2i(8, 8))
	check(Merchant.spot_for(dropped) != SPOT, "a drop on it")
	# A body on it (a player or a heretic standing there when he comes).
	var free: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var body: Array[Vector2] = [Arena.spawn_feet(SPOT)]
	check_eq(Merchant.spot_refusal(free, SPOT, body), WorldItems.WHY_BODY, "someone stands there: refused")
	check(Merchant.spot_for(free, body) != SPOT, "so he goes beside")
	# A floor piece is fine to stand on.
	var floored: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	floored.set_value(WorldData.Layer.FLOOR_PIECE, SPOT, WorldData.FLOOR_PIECE_STONE)
	check_eq(Merchant.spot_for(floored), SPOT, "a floor piece: he stands on it")
	# The spots where players appear: the altar placed so that the preferred tile is the entrance's arrival point.
	var arrival: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var way_feet: Vector2 = DungeonGen.arrival_below(SurfaceGen.entrance_rect(arrival))
	var at: Rect2i = Rect2i(Aim.feet_cell(way_feet) - Config.MERCHANT_OFFSET, Config.ALTAR_FOOTPRINT)
	move_altar(arrival, at)
	check_eq(Merchant.preferred_tile(arrival), Aim.feet_cell(way_feet), "the preferred tile on the arrival point")
	check_eq(Merchant.spot_refusal(arrival, Aim.feet_cell(way_feet)), WorldItems.WHY_RESERVED, "refused: players appear there")
	var got3: Vector2i = Merchant.spot_for(arrival)
	check(got3 != Walls.NO_CELL and got3 == first_allowed(arrival, Merchant.preferred_tile(arrival)),
		"he goes to the next allowed tile (%s)" % got3)
	# Never next to the altar, never outside the light, never on a spawn slot (the rule's own words).
	var d3: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	check_eq(Merchant.spot_refusal(d3, ALTAR_AT + Vector2i(3, 1)), Merchant.WHY_ALTAR, "beside the altar's face: too close")
	check_eq(Merchant.spot_refusal(d3, ALTAR_AT + Vector2i(11, 1)), Merchant.WHY_DARK, "out of the light")
	var slot1: Vector2i = Aim.feet_cell(d3.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1]))
	check_eq(Merchant.spot_refusal(d3, slot1), WorldItems.WHY_RESERVED, "a spawn slot")
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check(Merchant.spot_refusal(dun, Vector2i(30, 20)) == Merchant.WHY_SURFACE and Merchant.spot_for(dun) == Walls.NO_CELL,
		"never in the dungeon")


## settle_edits: from nothing, one edit; again, none; the altar carried: none (he waits); put down elsewhere: off the old tile
## onto the new one; his own tile counts as free while he looks.
func _check_settle() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var first: Array[EditLog.WorldEdit] = Merchant.settle_edits(d)
	check(first.size() == 1 and first[0].cell == SPOT and first[0].value == WorldData.PLACEABLE_MERCHANT, "he comes down on %s"
		% SPOT)
	apply(d, first)
	check_eq(Merchant.tile_of(d), SPOT, "tile_of finds him")
	check_eq(Merchant.spot_for(d), SPOT, "his own tile counts as free: he stays")
	check_eq(d.get_value(WorldData.Layer.PLACEABLE, SPOT), WorldData.PLACEABLE_MERCHANT, "and the search put him back")
	check(Merchant.settle_edits(d).is_empty(), "settling again: nothing")
	apply(d, AltarMove.pickup_edits(d))
	check(Merchant.settle_edits(d).is_empty() and Merchant.tile_of(d) == SPOT, "the altar carried: he waits where he stood")
	var west: Rect2i = Rect2i(ALTAR_AT + Vector2i(-13, -1), Config.ALTAR_FOOTPRINT)
	check_eq(AltarMove.place_refusal(d, west), "", "the altar goes down 13 tiles west")
	apply(d, AltarMove.place_edits(west))
	var moved: Array[EditLog.WorldEdit] = Merchant.settle_edits(d)
	var to: Vector2i = first_allowed(d, west.position + Config.MERCHANT_OFFSET)
	check(moved.size() == 2 and moved[0].cell == SPOT and moved[0].value == WorldData.PLACEABLE_NONE and moved[1].cell == to
		and moved[1].value == WorldData.PLACEABLE_MERCHANT, "off his old tile, onto %s" % to)
	apply(d, moved)
	check(d.layers[WorldData.Layer.PLACEABLE].count(WorldData.PLACEABLE_MERCHANT) == 1 and Merchant.tile_of(d) == to,
		"one merchant, beside the new altar")
	# The altar never goes down on him.
	apply(d, AltarMove.pickup_edits(d))
	check_eq(AltarMove.place_refusal(d, Rect2i(to - Vector2i(1, 1), Config.ALTAR_FOOTPRINT)), AltarMove.WHY_NOT_OPEN,
		"the altar over the merchant: not open ground")
	# No tile around the new altar allows him: he stays where he is.
	var crowded: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(crowded, Merchant.settle_edits(crowded))
	apply(crowded, AltarMove.pickup_edits(crowded))
	var east: Rect2i = Rect2i(ALTAR_AT + Vector2i(-13, -1), Config.ALTAR_FOOTPRINT)
	apply(crowded, AltarMove.place_edits(east))
	var centre: Vector2i = east.position + Vector2i(1, 1)
	for y: int in range(centre.y - 9, centre.y + 10):
		for x: int in range(centre.x - 9, centre.x + 10):
			if crowded.get_value(WorldData.Layer.PLACEABLE, Vector2i(x, y)) == WorldData.PLACEABLE_NONE:
				crowded.set_value(WorldData.Layer.CORRUPTION, Vector2i(x, y), 1)
	check(Merchant.spot_for(crowded) == Walls.NO_CELL and Merchant.settle_edits(crowded).is_empty()
		and Merchant.tile_of(crowded) == SPOT, "no tile allows him there: he stays on %s" % SPOT)


## M8 review: the seal rule (Building.seals with the spots where players appear and `others`). A built ring round the altar
## whose one gap is right south of his tile: on it he would close the ring, so he takes another tile (the reserved feet do not
## touch his tile: only the walk sees it). A player boxed in on three sides with his tile as the only way out: refused while
## that player is in `others`, allowed without (so `others` is what keeps them free).
func _check_seal() -> void:
	var stone: int = Walls.pack(Walls.KIND_STONE, 0)
	var ringed: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var gap: Vector2i = SPOT + Vector2i(0, 1)
	for x: int in range(55, 73):
		for y: int in [41, 51]:
			if Vector2i(x, y) != gap:
				ringed.set_value(WorldData.Layer.WALL, Vector2i(x, y), stone)
	for y2: int in range(42, 51):
		ringed.set_value(WorldData.Layer.WALL, Vector2i(55, y2), stone)
		ringed.set_value(WorldData.Layer.WALL, Vector2i(72, y2), stone)
	var spots: Array[Vector2] = WorldItems.reserved_feet(ringed)
	var touching: int = 0
	for r: Vector2 in spots:
		if Rect2(Vector2(SPOT * 16), Vector2(16, 16)).intersects(Movement.feet_box(r)):
			touching += 1
	check(touching == 0 and not Building.seals(ringed, [] as Array[Vector2i], spots), "the ring with its gap seals nothing yet")
	check_eq(Merchant.spot_refusal(ringed, SPOT), Building.WHY_SEALS, "on the tile inside the gap he would wall the spawn slots in")
	var got: Vector2i = Merchant.spot_for(ringed)
	check(got != SPOT and got != Walls.NO_CELL and Merchant.spot_refusal(ringed, got).is_empty()
		and not Building.seals(ringed, [got] as Array[Vector2i], spots), "so he takes %s, which walls nobody in" % got)
	# A player boxed in on three sides, his tile its only way out.
	var boxed: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	for c: Vector2i in [SPOT + Vector2i(-1, 1), SPOT + Vector2i(1, 1), SPOT + Vector2i(0, 2)]:
		boxed.set_value(WorldData.Layer.WALL, c, stone)
	var p: Array[Vector2] = [Arena.spawn_feet(SPOT + Vector2i(0, 1))]
	var none: Array[Vector2] = []
	check_eq(Merchant.spot_refusal(boxed, SPOT, p, p), Building.WHY_SEALS, "a player whose only way out is his tile: refused")
	check_eq(Merchant.spot_refusal(boxed, SPOT, p, none), "", "the same player left out of `others`: allowed (others is the rule)")
	var got2: Vector2i = Merchant.spot_for(boxed, p, p)
	check(got2 != SPOT and got2 != Walls.NO_CELL and not Building.seals(boxed, [got2] as Array[Vector2i], p),
		"so he takes %s and the player still walks out" % got2)


## M8 review: someone must be able to stand next to him (Merchant.reachable: a tile beside his walks
## Config.BUILD_SEAL_REACH_TILES away). A doorless built ring (66, 49)-(71, 54) round his tile: inside it nobody could reach him,
## so he stands outside it; a door in the ring makes the inside fine again (doors count as open). A one-tile pocket (walls west,
## east and south, a lantern post north): refused. And the clearance (`predicted`, PROVISIONAL README "M8b 상인 막기 여유"):
## a client's feet within Config.BLOCK_CLEARANCE_PX of his tile move him on (Building.WHY_NEAR) where the same feet as a plain
## body beside him do not; when only tiles within it are left he still goes (Merchant.target: the clearance is a preference).
func _check_reach_and_clearance() -> void:
	var stone: int = Walls.pack(Walls.KIND_STONE, 0)
	var ringed: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var inside: Rect2i = Rect2i(Vector2i(67, 50), Vector2i(4, 4))
	for x: int in range(66, 72):
		ringed.set_value(WorldData.Layer.WALL, Vector2i(x, 49), stone)
		ringed.set_value(WorldData.Layer.WALL, Vector2i(x, 54), stone)
	for y: int in range(50, 54):
		ringed.set_value(WorldData.Layer.WALL, Vector2i(66, y), stone)
		ringed.set_value(WorldData.Layer.WALL, Vector2i(71, y), stone)
	check(not Merchant.reachable(ringed, Vector2i(67, 51)) and not Merchant.reachable(ringed, Vector2i(68, 52)),
		"inside a doorless ring nobody could stand next to him")
	var got: Vector2i = Merchant.spot_for(ringed)
	check(got != Walls.NO_CELL and not inside.has_point(got) and Merchant.reachable(ringed, got),
		"so he stands outside it (%s)" % got)
	ringed.set_value(WorldData.Layer.WALL, Vector2i(66, 51), Walls.pack(Walls.KIND_DOOR, 0))
	check(Merchant.reachable(ringed, Vector2i(67, 51)), "with a door in the ring the inside is reachable (a door counts as open)")
	var pocket: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	for c: Vector2i in [SPOT + Vector2i(-1, 0), SPOT + Vector2i(1, 0), SPOT + Vector2i(0, 1)]:
		pocket.set_value(WorldData.Layer.WALL, c, stone)
	pocket.set_value(WorldData.Layer.PLACEABLE, SPOT + Vector2i(0, -1), WorldData.PLACEABLE_LANTERN)
	check_eq(Merchant.spot_refusal(pocket, SPOT), Merchant.WHY_UNREACHABLE, "a one-tile pocket: refused")
	check(Merchant.spot_for(pocket) != SPOT, "he stands elsewhere")
	# The clearance: a client one tile east of his tile.
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var f: Array[Vector2] = [Arena.spawn_feet(SPOT + Vector2i(1, 0))]
	check_eq(Merchant.spot_refusal(d, SPOT, f, f, f), Building.WHY_NEAR, "a client's feet within the clearance: refused")
	check_eq(Merchant.spot_refusal(d, SPOT, f, f), "", "the same feet as a body beside him (no client): allowed")
	var got2: Vector2i = Merchant.spot_for(d, f, f, f)
	check(got2 != SPOT and got2 != Walls.NO_CELL and Building.clear_of_others([got2] as Array[Vector2i], f),
		"so he takes %s, clear of the client" % got2)
	check_eq(Merchant.target(d, f, f, f), got2, "target = that tile")
	var only: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var centre: Vector2i = only.altar_rect.position + Vector2i(1, 1)
	for y2: int in range(centre.y - 10, centre.y + 11):
		for x2: int in range(centre.x - 10, centre.x + 11):
			var c2: Vector2i = Vector2i(x2, y2)
			if c2 != SPOT and only.get_value(WorldData.Layer.PLACEABLE, c2) == WorldData.PLACEABLE_NONE:
				only.set_value(WorldData.Layer.CORRUPTION, c2, 1)
	check(Merchant.spot_for(only, f, f, f) == Walls.NO_CELL and Merchant.target(only, f, f, f) == SPOT,
		"only his tile is left and it is within the clearance: he still goes there")
	var edits: Array[EditLog.WorldEdit] = Merchant.settle_edits(only, f, f, f)
	check(edits.size() == 1 and edits[0].cell == SPOT, "settle_edits puts him there")


## M8 review: the altar may go down where his waiting tile is all that keeps a new spawn slot from standing (seed 1, the altar
## lifted and put down one tile east: spawn slot 4's feet on his tile): allowed, and he steps beside the new place at once,
## every slot standable. The four other footprints near home the review found refused only because of him go too. Trying a
## footprint leaves the world as it was. With nowhere for him to go (everything around grown over), refused as before.
func _check_altar_beside_him() -> void:
	var d: WorldData = _lifted_with_merchant()
	var east: Rect2i = Rect2i(ALTAR_AT + Vector2i(1, 0), Config.ALTAR_FOOTPRINT)
	var tile_px: Rect2 = Rect2(Vector2(SPOT * 16), Vector2(16, 16))
	check(tile_px.intersects(Movement.feet_box(AltarMove.slot_feet(east)[4])) and not Movement.can_stand(d, AltarMove.slot_feet(east)[4]),
		"one tile east: spawn slot 4 stands on his tile")
	var before: String = d.content_hash()
	check_eq(AltarMove.place_refusal(d, east), "", "allowed: he steps off it right after")
	check(d.content_hash() == before and not d.altar_rect.has_area() and Merchant.tile_of(d) == SPOT,
		"trying it left the world as it was (no altar, he on %s)" % SPOT)
	check(AltarMove.set_down_rect(d, Arena.spawn_feet(east.get_center())) == east, "the set-down search finds it too")
	apply(d, AltarMove.place_edits(east))
	var moved: Array[EditLog.WorldEdit] = Merchant.settle_edits(d)
	d.set_value(WorldData.Layer.PLACEABLE, SPOT, WorldData.PLACEABLE_NONE)  # the written-out rule sees the world without him
	var expect: Vector2i = first_allowed(d, Merchant.preferred_tile(d))
	d.set_value(WorldData.Layer.PLACEABLE, SPOT, WorldData.PLACEABLE_MERCHANT)
	apply(d, moved)
	var to: Vector2i = Merchant.tile_of(d)
	check(moved.size() == 2 and to != SPOT and to == expect, "he goes to %s (the written-out rule: %s)" % [to, expect])
	var standing: int = 0
	for s: Vector2 in AltarMove.slot_feet(east):
		if Movement.can_stand(d, s):
			standing += 1
	check_eq(standing, Config.SPAWN_SLOTS.size(), "every new spawn slot can be stood on")
	for off: Vector2i in [Vector2i(2, 0), Vector2i(-1, 1), Vector2i(0, 3), Vector2i(1, 3)]:
		var d2: WorldData = _lifted_with_merchant()
		check_eq(AltarMove.place_refusal(d2, Rect2i(ALTAR_AT + off, Config.ALTAR_FOOTPRINT)), "",
			"moved by %s: allowed too" % off)
	# Nowhere for him to go: every tile he could take grown over.
	var stuck: WorldData = _lifted_with_merchant()
	var want: Vector2i = east.position + Config.MERCHANT_OFFSET
	for y: int in range(want.y - Config.MERCHANT_SEARCH_TILES, want.y + Config.MERCHANT_SEARCH_TILES + 1):
		for x: int in range(want.x - Config.MERCHANT_SEARCH_TILES, want.x + Config.MERCHANT_SEARCH_TILES + 1):
			var c: Vector2i = Vector2i(x, y)
			if not east.has_point(c) and stuck.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_NONE:
				stuck.set_value(WorldData.Layer.VEGETATION, c, WorldItems.value_of(&"stone_b"))
	check_eq(AltarMove.place_refusal(stuck, east), AltarMove.WHY_SLOTS, "with nowhere for him to go: no room around it, as before")
	stuck.set_value(WorldData.Layer.PLACEABLE, SPOT, WorldData.PLACEABLE_NONE)
	check_eq(AltarMove.place_refusal(stuck, east), "", "(and without him there it is allowed)")


## Seed 1 with the merchant settled (on SPOT) and the altar lifted (carried).
static func _lifted_with_merchant() -> WorldData:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(d, Merchant.settle_edits(d))
	apply(d, AltarMove.pickup_edits(d))
	return d


## His tile stays free: nothing is placed, built, tilled, dropped or set down on it; walking stops at him.
func _check_tile_kept() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	apply(d, Merchant.settle_edits(d))
	var south: Vector2 = Arena.spawn_feet(SPOT + Vector2i(0, 1))
	var inv: Inventory = Inventory.new()
	inv.add(&"torch", 5)
	check_eq(WorldItems.place(d, south, inv, 0, SPOT).why, WorldItems.WHY_NOT_OPEN, "a torch on him: refused")
	for big: StringName in [&"alchemy_table", &"storage_chest", &"workbench", &"anvil"]:
		var bi: Inventory = Inventory.new()
		bi.add(big, 1)
		var o: WorldItems.Outcome = WorldItems.place(d, south, bi, 0, SPOT)
		check(not o.ok(), "%s over him: refused (%s)" % [big, o.why])
	for piece: StringName in [Building.STONE_WALL, &"door", &"stone_floor", &"lantern"]:
		var pi: Inventory = Inventory.new()
		pi.add(piece, 10)
		check(not Building.build(d, south, pi, 0, SPOT).ok(), "%s on his tile: refused" % piece)
	var north_wall: String = Building.refusal(d, Arena.spawn_feet(SPOT + Vector2i(0, -2)), Building.STONE_WALL,
		SPOT + Vector2i(0, -1), 10)
	check(not north_wall.is_empty(), "a wall right north of him (its face would cover him): refused (%s)" % north_wall)
	check_eq(Farming.till_refusal(d, south, SPOT), WorldItems.WHY_BLOCKED, "tilling his tile: refused")
	var di: Inventory = Inventory.new()
	di.add(&"stone_a", 3)
	check_eq(WorldItems.drop(d, south, di, 0, 0, SPOT).why, WorldItems.WHY_BLOCKED, "dropping on him: refused")
	check(not WorldItems.bag_spot_ok(d, SPOT), "a death bag never lands on him")
	check_eq(WorldItems.bag_cell(d, Merchant.feet_of(SPOT)), SPOT + Vector2i(-1, -1), "a bag of someone dying there goes beside")
	check(Movement.is_blocked(d, SPOT) and not Movement.can_stand(d, Merchant.feet_of(SPOT)), "walking: he blocks")
	# F reaches him from the tiles around his (WorldItems.in_reach, the chest's rule); the open shop stays while the feet are within
	# Config.STATION_REACH_TILES of his tile (the chest's).
	check(Merchant.at(d, south, SPOT) and Merchant.at(d, Arena.spawn_feet(SPOT + Vector2i(1, 1)), SPOT), "F next to him (and diagonal)")
	check(not Merchant.at(d, Arena.spawn_feet(SPOT + Vector2i(0, 2)), SPOT), "F two tiles off: no")
	check(not Merchant.at(d, south, SPOT + Vector2i(1, 0)), "F on another tile: no")
	check(Merchant.still_at(d, Arena.spawn_feet(SPOT + Vector2i(0, Config.STATION_REACH_TILES)), SPOT), "the shop stays open %d tiles off"
		% Config.STATION_REACH_TILES)
	check(not Merchant.still_at(d, Arena.spawn_feet(SPOT + Vector2i(0, Config.STATION_REACH_TILES + 1)), SPOT), "and closes one more off")
	check_eq(Merchant.near(d, south), SPOT, "the prompt's rule: next to him")
	check_eq(Merchant.near(d, Arena.spawn_feet(SPOT + Vector2i(0, 2))), Walls.NO_CELL, "two tiles off: none")
	var feet: Vector2 = Arena.spawn_feet(SPOT + Vector2i(-2, 0))
	var hit: int = 0
	for t: int in 120:
		feet = Movement.step(d, feet, Vector2i(1, 0), TICK)
		if Rect2(Vector2(SPOT * 16), Vector2(16, 16)).intersects(Movement.feet_box(feet)):
			hit += 1
	check(hit == 0 and feet.x <= SPOT.x * 16 - Config.FEET_HALF_WIDTH, "walking into him stops at his tile (x %.1f)" % feet.x)


## Heretics: with the altar carried (no light: they may come near), one between him and a player chases the player and never
## walks into his tile; one alone beside him never attacks; none is ever spawned on him; the spawn tiles do not see him.
func _check_heretics() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var bare_cells: Array[Vector2i] = Arena.surface_spawn_cells(d, SafeZone.for_world(d))
	apply(d, Merchant.settle_edits(d))
	check_eq(Arena.surface_spawn_cells(d, SafeZone.for_world(d)), bare_cells, "the heretics' spawn tiles are as without him")
	check(not Arena.terrain_blocked(d, SPOT), "he is not terrain (he moves)")
	apply(d, AltarMove.pickup_edits(d))
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	check(not a.spawn_ok(Merchant.feet_of(SPOT), [] as Array[Player]), "never spawned on him")
	var p: Player = Player.new()
	p.setup(d, "paladin", Arena.spawn_feet(SPOT + Vector2i(2, -2)))
	_nodes.append(p)
	var h: HereticSim = a.spawn_heretic(Arena.spawn_feet(SPOT + Vector2i(-3, 0)))
	var tile_px: Rect2 = Rect2(Vector2(SPOT * 16), Vector2(16, 16))
	var into: int = 0
	var targeted_player: int = 0
	for t: int in 360:
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(), TICK)
		a.step([p] as Array[Player])
		if tile_px.intersects(Movement.feet_box(h.pos)):
			into += 1
		if h.has_target and h.target_id == p.get_instance_id():
			targeted_player += 1
	check_eq(into, 0, "chasing the player past him, the heretic never walks into his tile (360 ticks)")
	check(targeted_player > 0, "it goes for the player (%d ticks), never for him" % targeted_player)
	check_eq(Combat.line_clear(d, Combat.body_point(Arena.spawn_feet(SPOT + Vector2i(-2, 0))),
		Combat.body_point(Arena.spawn_feet(SPOT + Vector2i(2, 0)))), false, "he stands in the line of sight like a fixture")
	# Walking home through him: it stops at his side and never steps onto his tile.
	var a3: Arena = Arena.new()
	a3.setup(d, 1)
	a3.spawning = false
	var h3: HereticSim = a3.spawn_heretic(Arena.spawn_feet(SPOT + Vector2i(-2, 0)))
	h3.home = Arena.spawn_feet(SPOT + Vector2i(2, 0))
	var into3: int = 0
	for t3: int in 300:
		a3.step([] as Array[Player])
		if tile_px.intersects(Movement.feet_box(h3.pos)):
			into3 += 1
	check(into3 == 0 and h3.pos.x < SPOT.x * 16, "walking home through him: blocked at his west side (x %.1f)" % h3.pos.x)
	# One alone beside him, nobody else on the map: no target, no attack, ever.
	var a2: Arena = Arena.new()
	a2.setup(d, 1)
	a2.spawning = false
	var h2: HereticSim = a2.spawn_heretic(Arena.spawn_feet(SPOT + Vector2i(-1, 0)))
	for t2: int in 300:
		a2.step([] as Array[Player])
	check(not h2.has_target and a2.stat("attacks") == 0 and a2.stat("knife_swings") == 0, "beside him alone: it never attacks")
	check(not tile_px.intersects(Movement.feet_box(h2.pos)), "and is not on his tile")


## main.tscn offline: he stands there from the start; F in reach opens the shop (the panel, the inventory, the player stands);
## clicks buy and sell; Tab, F, Esc close it; out of reach, down and another map close it; the prompt; the shop's clock.
func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	check(main.shop_on and main.shop != null, "the shop is on offline")
	check_eq(Merchant.tile_of(main.world.data), SPOT, "the merchant stands on %s when the world starts" % SPOT)
	var view: MerchantView = main.world.fixtures.merchant_at(SPOT)
	check(view != null and view.position == Merchant.feet_of(SPOT) and view.get_parent() == main.world.entities,
		"drawn at his feet among the y-sorted entities")
	check_eq(main.world.fixtures.verify()["mismatches"], 0, "fixture view = data")
	check_eq(main.world.fixtures.verify()["merchants"], 1, "one merchant drawn")
	var clock: int = main.shop.clock
	main._physics_process(TICK)
	main._physics_process(TICK)
	check_eq(main.shop.clock, clock + 2, "the shop's clock runs on the physics ticks")
	# The prompt: next to him, yes; two tiles off, no.
	p.teleport(Arena.spawn_feet(SPOT + Vector2i(0, 1)))
	main._physics_process(TICK)
	check(view.prompt.visible, "next to him: the prompt over him")
	p.teleport(Arena.spawn_feet(SPOT + Vector2i(0, 2)))
	main._physics_process(TICK)
	check(not view.prompt.visible, "two tiles off: no prompt")
	# F from two tiles off, aimed at him: nothing (not in reach).
	p.aim_sector = Aim.Sector.NORTH
	main.pick_up()
	check(not main.shop_open(), "F from two tiles off: no shop")
	# F next to him but aimed away: nothing.
	p.teleport(Arena.spawn_feet(SPOT + Vector2i(0, 1)))
	p.aim_sector = Aim.Sector.EAST
	main.pick_up()
	check(not main.shop_open(), "F aimed elsewhere: no shop")
	p.aim_sector = Aim.Sector.NORTH
	p.inventory.add(ItemDB.MONEY, 30)
	p.inventory.add(&"stone_a", 20)
	main.pick_up()
	if not check(main.shop_open() and main.hud.open and p.ui_locked, "F at him: the shop panel and the inventory, the player stands"):
		return
	main._physics_process(TICK)
	check(not view.prompt.visible, "no prompt while the shop is open")
	var panel: ShopPanel = main.hud.shop
	var hud_view: Vector2i = main.hud.view_size()
	var top_inv: Vector2i = Hud.slot_origin(p.inventory.size() - 1, p.inventory.hotbar_size, hud_view)
	check(panel.panel_rect().end.y <= top_inv.y and panel.panel_rect().position.y >= 0, "the panel above the inventory grid, inside the view")
	check_eq(panel.panel_rect().size.x, main.hud.chest.panel_rect_for(hud_view).size.x, "as wide as the chest panel")
	# A click on the healing potion's entry buys one.
	var potion: int = 0
	check(panel.click_at(Vector2(panel.entry_rect(potion).position + Vector2i(9, 9))), "a click on the first entry")
	check(p.inventory.count_of(&"potion_healing") == 1 and Shop.money_in(p.inventory) == 18, "a potion bought (30 -> 18)")
	# Holy water: 40 > 18: refused, flashed.
	var holy: int = 2
	panel.click_at(Vector2(panel.entry_rect(holy).position + Vector2i(9, 9)))
	check(p.inventory.count_of(&"holy_water") == 0 and panel.refused_why == Shop.WHY_MONEY and panel.flash_entry == holy,
		"holy water refused: 돈이 모자라다 (flashed on its entry)")
	# A click on the stones' slot sells one; shift-click the rest.
	var stones: int = -1
	for i: int in p.inventory.size():
		if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == &"stone_a":
			stones = i
	var at: Vector2 = Vector2(Hud.slot_origin(stones, p.inventory.hotbar_size, hud_view) + Vector2i(9, 9))
	check(panel.click_at(at), "a click on the stones")
	check(p.inventory.count_of(&"stone_a") == 19 and Shop.money_in(p.inventory) == 19, "one stone sold")
	check(panel.click_at(at, true), "a shift-click on them")
	check(p.inventory.count_of(&"stone_a") == 0 and Shop.money_in(p.inventory) == 38, "the rest sold")
	var weapon: int = Config.START_WEAPON_SLOT
	panel.click_at(Vector2(Hud.slot_origin(weapon, p.inventory.hotbar_size, hud_view) + Vector2i(9, 9)))
	check(panel.refused_why == Shop.WHY_NOT_BOUGHT and panel.flash_slot == weapon and p.inventory.stack_at(weapon) != null,
		"the start weapon: 상인이 사지 않는 것 (flashed on its slot)")
	check(not panel.click_at(Vector2(panel.panel_rect().position) - Vector2(5, 5)), "a click elsewhere: nothing")
	# The keyboard: move to the torch, Enter buys it.
	panel.selected = 0
	main._shop_input(_action_event(&"move_right"))
	main._shop_input(_action_event(&"move_right"))
	main._shop_input(_action_event(&"move_right"))
	check_eq(panel.selected, 3, "the move keys pick the torch")
	var enter: InputEventKey = InputEventKey.new()
	enter.pressed = true
	enter.physical_keycode = KEY_ENTER
	main._shop_input(enter)
	check_eq(p.inventory.count_of(&"torch"), 1, "Enter buys it")
	# While open the player stands.
	var before: Vector2 = p.sim_position
	for t: int in 10:
		p.begin_tick()
		p.tick_controls(Vector2i(1, 0), p.sim_position + Vector2(30, 0), true, true, true, TICK, true, true)
	check_eq(p.sim_position, before, "no walking while the shop is open")
	main._shop_input(_action_event(&"toggle_inventory"))
	check(not main.shop_open() and not main.hud.open and not p.ui_locked, "Tab closes it")
	p.aim_sector = Aim.Sector.NORTH
	main.pick_up()
	main._shop_input(_action_event(&"interact"))
	check(not main.shop_open(), "F closes it")
	main.pick_up()
	main._shop_input(_action_event(&"ui_cancel"))
	check(not main.shop_open(), "Esc closes it")
	# M8 review, Main's session side (the role switched for the check, nothing is sent: no peer): a SELL names what this machine
	# shows in the slot, a slot that is empty here sends nothing, an entry or slot past the panel does nothing, and closing
	# drops the BUY / SELL requests still waiting to go (the others stay).
	main.pick_up()
	check(main.shop_open(), "open for the session checks")
	main.net.role = NetSession.Role.CLIENT
	main.net.local_ops.clear()
	p.inventory.add(&"wild_healing", 2, 2)
	var herb: int = -1
	var empty_slot: int = -1
	for i2: int in p.inventory.size():
		var st: ItemStack = p.inventory.stack_at(i2)
		if st != null and st.id == &"wild_healing":
			herb = i2
		elif st == null and empty_slot < 0:
			empty_slot = i2
	main.shop_sell(empty_slot, false)
	main.shop_buy(Shop.offers().size())
	main.shop_sell(p.inventory.size(), false)
	var nothing_sent: bool = main.net.local_ops.is_empty()
	main.shop_sell(herb, true)
	var sold: NetProtocol.InputFrame = main.net.local_ops[0] if main.net.local_ops.size() == 1 else null
	check(nothing_sent and sold != null and sold.op == NetProtocol.Op.SELL and sold.sell_all and sold.slot == herb
		and sold.item_index == ItemDB.index_of(&"wild_healing") and sold.grade == 2 and sold.cell == SPOT,
		"session: an empty slot, entry %d and slot %d send nothing; the herbs' SELL names wild_healing, fine" % [
		Shop.offers().size(), p.inventory.size()])
	main.net.local_ops.clear()
	for op: int in [NetProtocol.Op.BUY, NetProtocol.Op.PICKUP, NetProtocol.Op.SELL, NetProtocol.Op.BUY]:
		main.net.local_ops.append(Main.request(op, 0))
	main.close_shop()
	var kept: Array[NetProtocol.InputFrame] = main.net.local_ops.duplicate()
	main.net.local_ops.clear()
	main.net.role = NetSession.Role.OFFLINE
	check(not main.shop_open() and kept.size() == 1 and kept[0].op == NetProtocol.Op.PICKUP,
		"session: closing dropped the waiting BUY and SELL requests, kept the pick-up (%d left)" % kept.size())
	p.inventory.remove(herb, 2)
	# Out of reach: closed.
	main.pick_up()
	p.teleport(Arena.spawn_feet(SPOT + Vector2i(0, 4)))
	main._physics_process(TICK)
	check(not main.shop_open() and not p.ui_locked, "out of reach: closed")
	# Another map: closed.
	p.teleport(Arena.spawn_feet(SPOT + Vector2i(0, 1)))
	main.pick_up()
	check(main.shop_open(), "open again")
	main.travel(Config.MAP_DUNGEON)
	main._physics_process(TICK)
	check(not main.shop_open(), "another map: closed")
	main.travel(Config.MAP_SURFACE)
	# Down: closed.
	p.teleport(Arena.spawn_feet(SPOT + Vector2i(0, 1)))
	p.aim_sector = Aim.Sector.NORTH
	main.pick_up()
	check(main.shop_open(), "open once more")
	p.take_hit(Config.PLAYER_HP_MAX)
	main._physics_process(TICK)
	check(not main.shop_open() and not p.ui_locked, "down: closed")
	main.pick_up()
	check(not main.shop_open(), "and F while down opens nothing")
	# The altar lifted: he waits; put down 13 tiles west: he moves by the rule; the fixture view follows.
	var w: GameWorld = main.world
	var helper: Player = main.add_ally("miner", false)
	main.pick_up_altar(helper)
	check(helper.carrying_altar and Merchant.tile_of(w.data) == SPOT, "the altar carried: he waits on %s" % SPOT)
	var west: Rect2i = Rect2i(ALTAR_AT + Vector2i(-13, -1), Config.ALTAR_FOOTPRINT)
	helper.teleport(Arena.spawn_feet(west.position + Vector2i(1, 3)))
	var why: String = main.place_altar(helper, west.position + Vector2i(1, 2))
	check(why.is_empty() and w.data.altar_rect == west, "the altar put down 13 tiles west (%s)" % why)
	var now: Vector2i = Merchant.tile_of(w.data)
	w.data.set_value(WorldData.Layer.PLACEABLE, now, WorldData.PLACEABLE_NONE)  # the written-out rule, without him there
	var want: Vector2i = first_allowed(w.data, west.position + Config.MERCHANT_OFFSET)
	w.data.set_value(WorldData.Layer.PLACEABLE, now, WorldData.PLACEABLE_MERCHANT)
	check(now == want and want == west.position + Config.MERCHANT_OFFSET
		and w.data.get_value(WorldData.Layer.PLACEABLE, SPOT) == WorldData.PLACEABLE_NONE,
		"he moved beside it, to %s (the old tile empty; he is on %s)" % [want, now])
	check(w.fixtures.merchant_at(want) != null and w.fixtures.merchant_at(SPOT) == null and w.fixtures.verify()["mismatches"] == 0,
		"drawn there, not here")
	check_eq(main.merchant_moves, 2, "two moves: the start and this one")


## M8 review: offline the merchant comes down after the test options, as a host's does (SessionHost._setup_shop after the test
## pieces): --test-build's wall on his preferred tile and --test-field's crop on the next keep him off both (before, they were
## put down under him).
func _check_test_flags() -> void:
	var saved: CliOptions = CliOptions._current
	CliOptions._current = CliOptions.parse(PackedStringArray(["--test-build=%d,%d:wall" % [SPOT.x, SPOT.y],
		"--test-field=%d,%d:healing:2" % [SPOT.x - 1, SPOT.y - 1]]))
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	CliOptions._current = saved
	var data: WorldData = main.world.data
	var at: Vector2i = Merchant.tile_of(data)
	check(Walls.is_wall(data, SPOT) and Farming.field_at(data, SPOT + Vector2i(-1, -1)) != null and at != Walls.NO_CELL
		and at != SPOT and at != SPOT + Vector2i(-1, -1) and Merchant.spot_for(data) == at,
		"--test-build and --test-field come first: the merchant keeps off their tiles (he stands on %s)" % at)
	main.queue_free()
	await await_frames(1)


static func _action_event(action: StringName) -> InputEventAction:
	var e: InputEventAction = InputEventAction.new()
	e.action = action
	e.pressed = true
	return e
