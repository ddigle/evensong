class_name AltarMove
extends RefCounted
## Picking the altar up and putting it down (M5b, offline first). Pure functions on WorldData like items/farming.gd;
## the caller applies the edits (offline core/main.gd; the host in M5c) and keeps who carries it (Player.carrying_altar).
##
## ● decided: the altar's position is free and so is moving it (game-concept §9.3); respawning is at the altar
## (gameplay-design §2.6; §5 ○ "제단을 옮기면 부활 지점도 옮겨진다"). Everything that follows the altar reads it from the
## world: the light and the safe zone (SafeZone.for_world, GameWorld), the heretics' light rule and spawn tiles
## (Arena.sync_world), the spawn slots (GameWorld.spawn_point) and the spots placeables may not cover
## (WorldItems.reserved_feet), the side bands (Movement.side_bands), the fields' light (Farming.in_light).
## ○ / not in the docs (PROVISIONAL, core/config.gd "M5b", README "임시값" M5b):
##   - anyone (Config.ALTAR_MOVE_ANYONE; false = the paladin) holds F Config.ALTAR_PICKUP_HOLD_TICKS aimed at an altar
##     tile in reach: the footprint leaves the world (PLACEABLE cells -> none) and the player carries it. Surface only;
##   - while it is carried there is no altar: no light, no safe zone, no spawn suppression, no spawn slots (a dead player
##     waits to respawn until it is down again), every crop outside the (no) light withers;
##   - left click puts it down: the 3x3 footprint's near edge on the target tile (its centre two tiles from the feet
##     tile, place_rect) where place_refusal allows: on the map with its nine spawn slots standable, open ground (no
##     placeable: not over the entrance or a table; no corruption; nothing growing or lying there), nobody's feet under
##     it, not over a spot where players appear (the entrance's arrival point), and no live heretic inside its new light
##     (heretics never stand in the light, M4a);
##   - the carrier can not travel, channel, use items or throw (the click is the altar's); when it goes down the altar is
##     set down at the nearest allowed place around it (set_down_rect).

const WHY_NO_ALTAR: String = "no altar there"
const WHY_SURFACE: String = "the altar stays on the surface"
const WHY_CARRYING: String = "carrying the altar"
const WHY_PALADIN: String = "paladin only"
const WHY_NOT_OPEN: String = "not open ground"
const WHY_CORRUPTED: String = "corrupted ground"
const WHY_GROWING: String = "something grows there"
const WHY_SLOTS: String = "no room around it"
const WHY_HERETIC: String = "a heretic is in the light"
## M5b: a session (moving the altar offline only until M5c).
const WHY_OFFLINE: String = "moving the altar offline only"
## The class that may move it when Config.ALTAR_MOVE_ANYONE is off.
const PALADIN: String = "paladin"


## Whether tile `c` is part of the altar's footprint.
static func is_altar_cell(data: WorldData, c: Vector2i) -> bool:
	return data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_ALTAR


static func may_move(class_id: String) -> bool:
	return Config.ALTAR_MOVE_ANYONE or class_id == PALADIN


## Why a player of `class_id` with feet at `feet` may not pick the altar up by aiming at tile `c` ("" = it may): the
## surface, on the map, in reach (WorldItems.in_reach), an altar tile, the class. Being up and holding F long enough
## are the caller's.
static func pickup_refusal(data: WorldData, class_id: String, feet: Vector2, c: Vector2i) -> String:
	if data.map_id != Config.MAP_SURFACE:
		return WHY_SURFACE
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if not is_altar_cell(data, c):
		return WHY_NO_ALTAR
	if not may_move(class_id):
		return WHY_PALADIN
	return ""


## The edits that take the altar out of the world (every footprint tile -> no placeable), row by row.
static func pickup_edits(data: WorldData) -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = []
	var r: Rect2i = data.altar_rect
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			out.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_NONE))
	return out


## The footprint a carrier with feet at `feet` puts down aiming at tile `c` (next to the feet tile): its near edge on
## `c`, its centre two tiles from the feet tile in that direction (Config.ALTAR_FOOTPRINT, odd sizes). An empty rect
## when `c` is the feet tile.
static func place_rect(feet: Vector2, c: Vector2i) -> Rect2i:
	var f: Vector2i = Aim.feet_cell(feet)
	var d: Vector2i = Vector2i(clampi(c.x - f.x, -1, 1), clampi(c.y - f.y, -1, 1))
	if d == Vector2i.ZERO:
		return Rect2i()
	var half: Vector2i = Config.ALTAR_FOOTPRINT / 2
	var centre: Vector2i = f + Vector2i(d.x * (half.x + 1), d.y * (half.y + 1))
	return Rect2i(centre - half, Config.ALTAR_FOOTPRINT)


## The centre (px) of an altar on footprint `rect` (WorldData.altar_center_px's rule).
static func centre_px(rect: Rect2i) -> Vector2:
	return (Vector2(rect.position) + Vector2(rect.size) / 2.0) * Config.TILE


## The feet points of the spawn slots of an altar on `rect` (GameWorld.spawn_point's rule).
static func slot_feet(rect: Rect2i) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var centre: Vector2 = centre_px(rect)
	for o: Vector2i in Config.SPAWN_SLOTS:
		out.append(centre + Vector2(o))
	return out


## Why the altar may not go down on footprint `rect` ("" = it may), with `bodies` = the players' feet (the carrier's
## too) and `heretics` = the live heretics' feet on the map. See the class comment for the list.
static func place_refusal(data: WorldData, rect: Rect2i, bodies: Array[Vector2] = [], heretics: Array[Vector2] = []) -> String:
	if data.map_id != Config.MAP_SURFACE:
		return WHY_SURFACE
	if not rect.has_area() or not Rect2i(Vector2i.ZERO, data.size).encloses(rect):
		return WorldItems.WHY_OUTSIDE
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c: Vector2i = Vector2i(x, y)
			if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE or Walls.blocks(data, c) \
					or not data.drops_at(c).is_empty():
				return WHY_NOT_OPEN
			if data.get_value(WorldData.Layer.CORRUPTION, c) != 0 or data.terrain_at(c) == Terrain.ASH:
				return WHY_CORRUPTED
			if data.get_value(WorldData.Layer.VEGETATION, c) != 0:
				return WHY_GROWING
	var px: Rect2 = Rect2(Vector2(rect.position * Config.TILE), Vector2(rect.size * Config.TILE))
	for b: Vector2 in bodies:
		if px.intersects(Movement.feet_box(b)):
			return WorldItems.WHY_BODY
	for r: Vector2 in WorldItems.reserved_feet(data):
		if px.intersects(Movement.feet_box(r)):
			return WorldItems.WHY_RESERVED
	for s: Vector2 in slot_feet(rect):
		if not Movement.can_stand(data, s) or px.intersects(Movement.feet_box(s)):
			return WHY_SLOTS
	var zone: SafeZone = SafeZone.new(centre_px(rect), Config.safe_radius_px())
	for h: Vector2 in heretics:
		if not Combat.box_outside_light(data, zone, h):
			return WHY_HERETIC
	return ""


## The edits that put the altar on footprint `rect`, row by row.
static func place_edits(rect: Rect2i) -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			out.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_ALTAR))
	return out


## The footprint the altar is set down on when its carrier with feet at `feet` goes down: the nearest one place_refusal
## allows, by rings of growing Chebyshev distance of its centre from the feet tile (row by row in a ring), out to
## Config.ALTAR_SET_DOWN_SEARCH_TILES. An empty rect when there is none.
static func set_down_rect(data: WorldData, feet: Vector2, bodies: Array[Vector2] = [],
		heretics: Array[Vector2] = []) -> Rect2i:
	var f: Vector2i = Aim.feet_cell(feet)
	var half: Vector2i = Config.ALTAR_FOOTPRINT / 2
	for d: int in Config.ALTAR_SET_DOWN_SEARCH_TILES + 1:
		for y: int in range(f.y - d, f.y + d + 1):
			for x: int in range(f.x - d, f.x + d + 1):
				if maxi(absi(x - f.x), absi(y - f.y)) != d:
					continue
				var rect: Rect2i = Rect2i(Vector2i(x, y) - half, Config.ALTAR_FOOTPRINT)
				if place_refusal(data, rect, bodies, heretics).is_empty():
					return rect
	return Rect2i()
