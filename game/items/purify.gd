class_name Purify
extends RefCounted
## Purification (M5b, offline first): taking corrupted ground back. Pure functions on WorldData + Inventory like
## items/farming.gd; the caller applies the edits (offline core/main.gd; the host in M5c).
##
## ● decided (gameplay-design §3.0 R11, paladin row): anyone purifies a few tiles with holy water (공용 수행); the wide
## purification channel is the paladin's (클래스 전용 "광역 정화 채널링"). The shop's holy water (대체 수단) is the merchant's,
## M8. Corruption sources and re-corruption are not here: the slice has no spread (○ §3.7, game-concept §5).
## ○ / not in the docs (PROVISIONAL, core/config.gd "M5b", README "임시값" M5b):
##   - holy water: a click with it on a target tile in reach plays Config.HOLY_WATER_ANIM; on its effect frame one is used
##     and every corrupted tile within Config.HOLY_WATER_RADIUS_TILES (Chebyshev) of the target is purified. Nothing
##     corrupted there: refused, nothing used;
##   - the channel: F with nothing to pick up on the target tile starts it (○ §1 "F … 정화 시작") while a corrupted tile
##     lies within Config.PURIFY_START_REACH_TILES of the feet tile; it runs Config.PURIFY_CHANNEL_TICKS standing (the
##     shared simulation, actors/player_sim.gd: moving, dashing, a use, a hit or going down break it) and then purifies
##     every corrupted tile within Config.PURIFY_RADIUS_TILES of the feet tile (a disc of tile centres);
##   - what purified ground becomes: grass at once (FLOOR ash -> grass, CORRUPTION -> 0; the grass <-> ash tiles of the
##     corruption v05 set draw the zone's new edge). The ash going away is only shown (world/purify_view.gd: an ash
##     smear and a gold flash for a moment), never stored. What lies on a purified tile (the ash-side gatherables) stays.
## Purified tiles are ordinary world edits, so the snapshot, the hash and the edit log carry them; the heretics' spawn
## tiles around the zones (Arena.sync_world) and the crops next to them (Farm.step: Farming.withers_at) follow the data.

const HOLY_WATER: StringName = &"holy_water"
## ● the class that channels the wide purification (gameplay-design §3.0 R11).
const PALADIN: String = "paladin"

## Why holy water or the channel was refused (logs and tests count these).
const WHY_NOTHING: String = "nothing to purify"
const WHY_PALADIN: String = "paladin only"
const WHY_NOT_HOLY: String = "not holy water"
const WHY_GONE: String = "the holy water is gone"
## M5b: a session (purification offline only until M5c; the host refuses a holy water USE).
const WHY_OFFLINE: String = "purification offline only"


## What a pour or a finished channel did: ok or why not, the tiles purified (row order of the area) and their edits.
class Result:
	extends RefCounted
	var why: String = ""
	var cells: Array[Vector2i] = []
	var edits: Array[EditLog.WorldEdit] = []

	func ok() -> bool:
		return why.is_empty()

	static func refused(reason: String) -> Result:
		var r: Result = Result.new()
		r.why = reason
		return r


static func is_holy_water(id: StringName) -> bool:
	return id == HOLY_WATER


## Whether tile `c` is corrupted (the CORRUPTION layer: a zone id; the generator keeps it with the ash floor).
static func is_corrupted(data: WorldData, c: Vector2i) -> bool:
	return data.in_bounds(c) and data.get_value(WorldData.Layer.CORRUPTION, c) != 0


## The tick of the pouring action on which holy water works (Config.HOLY_WATER_EFFECT_FRAME).
static func impact_tick() -> int:
	return Config.HOLY_WATER_EFFECT_FRAME * Config.ACTION_FRAME_TICKS


## The tiles one holy water reaches around target `c`: Chebyshev Config.HOLY_WATER_RADIUS_TILES, row by row.
static func holy_water_area(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = Config.HOLY_WATER_RADIUS_TILES
	for y: int in range(c.y - r, c.y + r + 1):
		for x: int in range(c.x - r, c.x + r + 1):
			out.append(Vector2i(x, y))
	return out


## The tiles a finished channel reaches around its centre tile: every tile whose centre lies within
## Config.PURIFY_RADIUS_TILES tiles of the centre tile's centre, row by row.
static func channel_area(centre: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = Config.PURIFY_RADIUS_TILES
	for y: int in range(centre.y - r, centre.y + r + 1):
		for x: int in range(centre.x - r, centre.x + r + 1):
			var d: Vector2i = Vector2i(x, y) - centre
			if d.x * d.x + d.y * d.y <= r * r:
				out.append(Vector2i(x, y))
	return out


## The corrupted tiles among `cells` (in their order).
static func corrupted_in(data: WorldData, cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in cells:
		if is_corrupted(data, c):
			out.append(c)
	return out


## The edits that purify `cells` (each corrupted one: CORRUPTION 0, then an ash floor becomes grass).
static func edits_for(data: WorldData, cells: Array[Vector2i]) -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = []
	for c: Vector2i in cells:
		if not is_corrupted(data, c):
			continue
		out.append(EditLog.WorldEdit.new(WorldData.Layer.CORRUPTION, c, 0))
		if data.terrain_at(c) == Terrain.ASH:
			out.append(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c, Terrain.GRASS))
	return out


## Why holy water may not be poured on tile `c` from feet `feet` ("" = it may): on the map, in reach
## (WorldItems.in_reach), something corrupted within its area.
static func holy_water_refusal(data: WorldData, feet: Vector2, c: Vector2i) -> String:
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if corrupted_in(data, holy_water_area(c)).is_empty():
		return WHY_NOTHING
	return ""


## The holy water's effect frame (one rule for offline Main and M5c's host): checked again, one taken out of `inv`
## (the action's `slot` when it still holds holy water, else the first stack of it), the area purified.
static func pour(data: WorldData, feet: Vector2, inv: Inventory, slot: int, c: Vector2i) -> Result:
	var why: String = holy_water_refusal(data, feet, c)
	if not why.is_empty():
		return Result.refused(why)
	if not Potions.take_one(inv, slot, HOLY_WATER, ItemDB.Grade.NONE):
		return Result.refused(WHY_GONE)
	var r: Result = Result.new()
	r.cells = corrupted_in(data, holy_water_area(c))
	r.edits = edits_for(data, r.cells)
	return r


## The tile a channel started from feet `feet` purifies around (the feet tile, Aim.feet_cell).
static func channel_centre(feet: Vector2) -> Vector2i:
	return Aim.feet_cell(feet)


## Why a player of `class_id` with feet at `feet` may not start the channel ("" = it may): ● the paladin, and a corrupted
## tile within Config.PURIFY_START_REACH_TILES of the feet tile (on it or next to it). Being up and free (no action, dash
## or stagger) is the simulation's (PlayerSim.step).
static func channel_refusal(data: WorldData, class_id: String, feet: Vector2) -> String:
	if class_id != PALADIN:
		return WHY_PALADIN
	var f: Vector2i = channel_centre(feet)
	var r: int = Config.PURIFY_START_REACH_TILES
	for y: int in range(f.y - r, f.y + r + 1):
		for x: int in range(f.x - r, f.x + r + 1):
			if is_corrupted(data, Vector2i(x, y)):
				return ""
	return WHY_NOTHING


## A channel completed around tile `centre`: the corrupted tiles of its area and their edits (none left: refused,
## WHY_NOTHING; another player or holy water may have purified them meanwhile).
static func channel_done(data: WorldData, centre: Vector2i) -> Result:
	var cells: Array[Vector2i] = corrupted_in(data, channel_area(centre))
	if cells.is_empty():
		return Result.refused(WHY_NOTHING)
	var r: Result = Result.new()
	r.cells = cells
	r.edits = edits_for(data, cells)
	return r


## Corrupted tiles of `data` (tests, the smoke).
static func corrupted_count(data: WorldData) -> int:
	return data.layers[WorldData.Layer.CORRUPTION].size() - data.layers[WorldData.Layer.CORRUPTION].count(0)
