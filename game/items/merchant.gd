class_name Merchant
extends RefCounted
## M8a: the merchant beside the altar (● gameplay-design §3.0 R11, the line after the table: "제단 곁 상인 NPC (순례 상인)", required
## in the slice as the substitute for the verbs of the four classes it leaves out, R23). Pure functions on WorldData like
## items/altar_move.gd: they say where he stands and return the edits that put him there; the caller applies them (offline
## core/main.gd; a session has no merchant until M8b). What he sells and buys is items/shop.gd.
##
## He is one tile of the surface's PLACEABLE layer (WorldData.PLACEABLE_MERCHANT), so the world's rules keep his tile free as
## they keep any fixture's: nothing is placed, built, tilled, dropped or set down on it (the altar, a death bag included), and
## while PROVISIONAL Config.MERCHANT_BLOCKS he blocks walking for players and heretics alike (Movement). Heretics never target
## him (they target players only, combat/arena.gd) and nothing hurts him (he has no hit points). He is not terrain: the
## heretics' spawn tiles leave him out (Arena.terrain_blocked) and spawn_ok checks the live world.
## ○ / not in the docs (PROVISIONAL, core/config.gd "M8a", README "임시값" M8a):
##   - where: spot_for(): Config.MERCHANT_OFFSET from the altar footprint's top-left tile, else the nearest allowed tile around
##     it (rings out to Config.MERCHANT_SEARCH_TILES, row by row in a ring); allowed = spot_refusal() "" (see there);
##   - when: the offline game puts him down when the world starts (settle_edits) and moves him by the same rule each time the
##     altar is put down (placed, set down, restored); while the altar is carried he waits where he stood, and when no tile
##     around the new altar allows him he stays where he is (both logged). M8 review: the altar may go down where his waiting
##     tile is all that keeps one of its new spawn slots from standing or walking out (AltarMove: he moves off them right
##     after), as long as he then has a tile to go to (would_move_off);
##   - he is always there ("순례" suggests visits; no schedule in the slice).

const WHY_SURFACE: String = "the merchant stays on the surface"
const WHY_NO_ALTAR: String = "no altar"
const WHY_DARK: String = "outside the light"
const WHY_ALTAR: String = "too close to the altar"
const WHY_NOT_OPEN: String = "not open ground"
const WHY_NOT_GRASS: String = "not grass"
const WHY_GROWING: String = "something grows there"
const WHY_DROP: String = "something lies there"
## M8 review: no tile beside his lets anyone walk Config.BUILD_SEAL_REACH_TILES away (a doorless built ring or pocket around
## it): nobody could stand next to him to open the shop.
const WHY_UNREACHABLE: String = "nobody could reach him"

## The one place the offline game looks for a merchant (the surface).
const MAP: int = Config.MAP_SURFACE


## The merchant's tile on `data` (Walls.NO_CELL: he is not on this map).
static func tile_of(data: WorldData) -> Vector2i:
	if data == null:
		return Walls.NO_CELL
	var i: int = data.layers[WorldData.Layer.PLACEABLE].find(WorldData.PLACEABLE_MERCHANT)
	return Walls.NO_CELL if i < 0 else Vector2i(i % data.size.x, i / data.size.x)


## The tile `data`'s altar would have him on first (Config.MERCHANT_OFFSET from its footprint's top-left tile); Walls.NO_CELL
## without an altar.
static func preferred_tile(data: WorldData) -> Vector2i:
	if data == null or not data.altar_rect.has_area():
		return Walls.NO_CELL
	return data.altar_rect.position + Config.MERCHANT_OFFSET


## Where he stands on tile `c` (px): its middle, Config.ARRIVAL_FEET_INSET_PX above its bottom edge (like a player's arrival
## point; the y-sort sorts him by it).
static func feet_of(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


## Why tile `c` of `data` may not hold the merchant ("" = it may), with `bodies` (players' and heretics' feet: none may stand
## on it) and `others` (the players' feet: none may be walled in, Building.seals). On the surface, with an altar: the whole tile
## in the light (four corners, Farming.in_light); more than Config.MERCHANT_ALTAR_GAP_TILES tiles from the altar's footprint;
## grass with nothing on it (no placeable, no built wall or door, no wall face or doorway, no corruption, no field, gatherable
## or crop, no drop; a floor piece is fine); no spot where players appear (WorldItems.reserved_feet: the altar's spawn slots,
## the arrival point below the entrance) and no body on it; and none of those spots nor `others` walled in by him.
## M8 review (PROVISIONAL README "M8a 상인 자리", "M8b 상인 막기 여유"): `predicted` = the feet of the players whose own machine
## walks them a round trip ahead of the host (a session's clients; offline the --test-ally players, M7c's rule): while he
## blocks, none within Config.BLOCK_CLEARANCE_PX of the tile (Building.clear_of_others, Building.WHY_NEAR: a blocking tile that
## appears beside a client never pulls its prediction back); and someone can stand next to him (reachable(), WHY_UNREACHABLE).
static func spot_refusal(data: WorldData, c: Vector2i, bodies: Array[Vector2] = [], others: Array[Vector2] = [],
		predicted: Array[Vector2] = []) -> String:
	if data == null or data.map_id != MAP:
		return WHY_SURFACE
	if not data.altar_rect.has_area():
		return WHY_NO_ALTAR
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not Farming.in_light(data, c):
		return WHY_DARK
	if Crafting.tiles_to(c, data.altar_rect) <= Config.MERCHANT_ALTAR_GAP_TILES:
		return WHY_ALTAR
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE or Walls.blocks(data, c) \
			or Walls.is_wall(data, c) or Walls.is_face(data, c) or Walls.kind_at(data, c) != Walls.KIND_NONE:
		return WHY_NOT_OPEN
	if data.terrain_at(c) != Terrain.GRASS or data.get_value(WorldData.Layer.CORRUPTION, c) != 0:
		return WHY_NOT_GRASS
	if data.get_value(WorldData.Layer.VEGETATION, c) != 0:
		return WHY_GROWING
	if not data.drops_at(c).is_empty():
		return WHY_DROP
	var px: Rect2 = Rect2(Vector2(c * Config.TILE), Vector2(Config.TILE, Config.TILE))
	for b: Vector2 in bodies:
		if px.intersects(Movement.feet_box(b)):
			return WorldItems.WHY_BODY
	var spots: Array[Vector2] = WorldItems.reserved_feet(data)
	for r: Vector2 in spots:
		if px.intersects(Movement.feet_box(r)):
			return WorldItems.WHY_RESERVED
	var cells: Array[Vector2i] = [c]
	if Config.MERCHANT_BLOCKS:
		if not Building.clear_of_others(cells, predicted):
			return Building.WHY_NEAR
		var walkers: Array[Vector2] = spots.duplicate()
		walkers.append_array(others)
		if Building.seals(data, cells, walkers):
			return Building.WHY_SEALS
	if not reachable(data, c):
		return WHY_UNREACHABLE
	return ""


## M8 review: whether someone can stand next to tile `c` (the merchant's): one of the four tiles beside it walks
## Config.BUILD_SEAL_REACH_TILES away (Building.reaches, the seal rule's walk: 4 ways, doors open; `c` itself blocks while
## Config.MERCHANT_BLOCKS).
static func reachable(data: WorldData, c: Vector2i) -> bool:
	var extra: Dictionary[Vector2i, bool] = {}
	if Config.MERCHANT_BLOCKS:
		extra[c] = true
	for d: Vector2i in DungeonGen.STEPS:
		if Building.reaches(data, c + d, extra):
			return true
	return false


## The tile the merchant stands on for `data`'s altar: preferred_tile() if spot_refusal allows it, else the nearest tile it
## allows in rings of growing Chebyshev distance around it (row by row in a ring) out to Config.MERCHANT_SEARCH_TILES;
## Walls.NO_CELL when none does (or no altar). Where he stands now counts as free (the rule is where he would stand if he were
## not there: his tile is cleared for the search and put back).
static func spot_for(data: WorldData, bodies: Array[Vector2] = [], others: Array[Vector2] = [],
		predicted: Array[Vector2] = []) -> Vector2i:
	var want: Vector2i = preferred_tile(data)
	if want == Walls.NO_CELL or data.map_id != MAP:
		return Walls.NO_CELL
	var now: Vector2i = tile_of(data)
	if now != Walls.NO_CELL:
		data.set_value(WorldData.Layer.PLACEABLE, now, WorldData.PLACEABLE_NONE)
	var found: Vector2i = Walls.NO_CELL
	for d: int in Config.MERCHANT_SEARCH_TILES + 1:
		for y: int in range(want.y - d, want.y + d + 1):
			for x: int in range(want.x - d, want.x + d + 1):
				if found != Walls.NO_CELL or maxi(absi(x - want.x), absi(y - want.y)) != d:
					continue
				if spot_refusal(data, Vector2i(x, y), bodies, others, predicted).is_empty():
					found = Vector2i(x, y)
		if found != Walls.NO_CELL:
			break
	if now != Walls.NO_CELL:
		data.set_value(WorldData.Layer.PLACEABLE, now, WorldData.PLACEABLE_MERCHANT)
	return found


## M8 review: where settle_edits puts him: spot_for with `predicted` (the clearance), else without it (the clearance is a
## preference: a tile within it beats staying on a spot the new altar needs); Walls.NO_CELL when neither finds one.
static func target(data: WorldData, bodies: Array[Vector2] = [], others: Array[Vector2] = [],
		predicted: Array[Vector2] = []) -> Vector2i:
	var to: Vector2i = spot_for(data, bodies, others, predicted)
	if to == Walls.NO_CELL and not predicted.is_empty():
		to = spot_for(data, bodies, others)
	return to


## The edits that put the merchant where target() says for `data` now: off his old tile (if any) and onto the new one. None
## when he already stands there, when no tile allows him (he stays where he is, or stays away when he was not there) and
## while the altar is carried (he waits).
static func settle_edits(data: WorldData, bodies: Array[Vector2] = [], others: Array[Vector2] = [],
		predicted: Array[Vector2] = []) -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = []
	var to: Vector2i = target(data, bodies, others, predicted)
	var now: Vector2i = tile_of(data)
	if to == Walls.NO_CELL or to == now:
		return out
	if now != Walls.NO_CELL:
		out.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, now, WorldData.PLACEABLE_NONE))
	out.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, to, WorldData.PLACEABLE_MERCHANT))
	return out


## M8 review (AltarMove's placing rule): whether, with the altar put down on footprint `rect` (`data` has none now: it is
## carried), the merchant would have a tile to go to (target() with `bodies` and `others`, as settle_edits will just after).
## The footprint is tried on `data` and taken off again (its cells and altar_rect as they were).
static func would_move_off(data: WorldData, rect: Rect2i, bodies: Array[Vector2] = [], others: Array[Vector2] = []) -> bool:
	var was_rect: Rect2i = data.altar_rect
	var was: PackedByteArray = PackedByteArray()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			was.append(data.get_value(WorldData.Layer.PLACEABLE, Vector2i(x, y)))
			data.set_value(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_ALTAR)
	data.altar_rect = rect
	var to: Vector2i = target(data, bodies, others)
	var i: int = 0
	for y2: int in range(rect.position.y, rect.end.y):
		for x2: int in range(rect.position.x, rect.end.x):
			data.set_value(WorldData.Layer.PLACEABLE, Vector2i(x2, y2), was[i])
			i += 1
	data.altar_rect = was_rect
	return to != Walls.NO_CELL


## Whether F on tile `c` by feet `feet` reaches the merchant (his tile, in reach: WorldItems.in_reach, the chest's rule).
static func at(data: WorldData, feet: Vector2, c: Vector2i) -> bool:
	return data != null and data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_MERCHANT \
		and WorldItems.in_reach(feet, c)


## Whether the merchant is still on tile `tile` of `data` and feet `feet` within Config.STATION_REACH_TILES of it (the open
## shop's rule, the chest's: Storage.still_at).
static func still_at(data: WorldData, feet: Vector2, tile: Vector2i) -> bool:
	if data == null or tile == Walls.NO_CELL or data.get_value(WorldData.Layer.PLACEABLE, tile) != WorldData.PLACEABLE_MERCHANT:
		return false
	return Crafting.tiles_to(Aim.feet_cell(feet), Rect2i(tile, Vector2i.ONE)) <= Config.STATION_REACH_TILES


## His tile when feet `feet` stand next to it (WorldItems.in_reach: the prompt shows), else Walls.NO_CELL.
static func near(data: WorldData, feet: Vector2) -> Vector2i:
	var t: Vector2i = tile_of(data)
	return t if t != Walls.NO_CELL and WorldItems.in_reach(feet, t) else Walls.NO_CELL
