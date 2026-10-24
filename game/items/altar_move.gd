class_name AltarMove
extends RefCounted
## Picking the altar up and putting it down (M5b, offline first). Pure functions on WorldData like items/farming.gd;
## the caller applies the edits (offline core/main.gd; M5c: the host, net/session_host.gd) and keeps who carries it
## (Player.carrying_altar; M5c: in the player's state).
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
##     set down at the nearest allowed place around it (set_down_rect; M5-fix: set_down_fallback, never over anything);
##   - M5-fix: its light may cover corruption (Config.ALTAR_LIGHT_MAY_COVER_CORRUPTION; false: light_corruption_refusal);
##     F held counts toward lifting only while the player is up, plays no action, does not channel and no downed player
##     lies within revive reach (hold_counts: F held there is a revive).

const WHY_NO_ALTAR: String = "no altar there"
const WHY_SURFACE: String = "the altar stays on the surface"
const WHY_CARRYING: String = "carrying the altar"
const WHY_PALADIN: String = "paladin only"
const WHY_NOT_OPEN: String = "not open ground"
const WHY_CORRUPTED: String = "corrupted ground"
const WHY_GROWING: String = "something grows there"
const WHY_SLOTS: String = "no room around it"
const WHY_HERETIC: String = "a heretic is in the light"
## M5-fix, only with Config.ALTAR_LIGHT_MAY_COVER_CORRUPTION off: a corrupted tile within its light (+ the M1 margin).
const WHY_LIGHT_CORRUPTED: String = "corruption in its light"
## M5c: the host counted fewer than Config.ALTAR_PICKUP_HOLD_TICKS frames of F held before an ALTAR_LIFT; an ALTAR_PLACE
## from a player who carries nothing.
const WHY_HOLD: String = "F not held long enough"
const WHY_NOT_CARRYING: String = "not carrying the altar"
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
	return _refusal(data, rect, bodies, heretics, WorldItems.reserved_feet(data))


## place_refusal with the spots where players appear given (`reserved`, WorldItems.reserved_feet: M5-fix, a search
## reads them once, not once a footprint; the reserved spots never depend on the footprint tried). Surface only.
static func _refusal(data: WorldData, rect: Rect2i, bodies: Array[Vector2], heretics: Array[Vector2],
		reserved: Array[Vector2]) -> String:
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
	for r: Vector2 in reserved:
		if px.intersects(Movement.feet_box(r)):
			return WorldItems.WHY_RESERVED
	for s: Vector2 in slot_feet(rect):
		if not Movement.can_stand(data, s) or px.intersects(Movement.feet_box(s)):
			return WHY_SLOTS
	if _lights_a_heretic(data, rect, heretics):
		return WHY_HERETIC
	if not Config.ALTAR_LIGHT_MAY_COVER_CORRUPTION:
		return light_corruption_refusal(data, rect)
	return ""


## M5-fix (used only with Config.ALTAR_LIGHT_MAY_COVER_CORRUPTION off; tests call it either way): WHY_LIGHT_CORRUPTED
## when a corrupted tile's centre lies within the safe radius + Config.ASH_CLEARANCE_TILES of footprint `rect`'s centre
## (the margin the M1 generator keeps between the light and the ash), else "".
static func light_corruption_refusal(data: WorldData, rect: Rect2i) -> String:
	var centre: Vector2 = centre_px(rect)
	var reach: float = Config.safe_radius_px() + Config.ASH_CLEARANCE_TILES * Config.TILE
	var lo: Vector2i = Vector2i(floori((centre.x - reach) / Config.TILE), floori((centre.y - reach) / Config.TILE))
	var hi: Vector2i = Vector2i(floori((centre.x + reach) / Config.TILE), floori((centre.y + reach) / Config.TILE))
	var layer: PackedByteArray = data.layers[WorldData.Layer.CORRUPTION]
	for y: int in range(maxi(lo.y, 0), mini(hi.y, data.size.y - 1) + 1):
		for x: int in range(maxi(lo.x, 0), mini(hi.x, data.size.x - 1) + 1):
			if layer[y * data.size.x + x] != 0 \
					and ((Vector2(x, y) + Vector2(0.5, 0.5)) * Config.TILE).distance_squared_to(centre) <= reach * reach:
				return WHY_LIGHT_CORRUPTED
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
	if data.map_id != Config.MAP_SURFACE:
		return Rect2i()
	var reserved: Array[Vector2] = WorldItems.reserved_feet(data)  # M5-fix: once a search, not once a footprint
	var f: Vector2i = Aim.feet_cell(feet)
	var half: Vector2i = Config.ALTAR_FOOTPRINT / 2
	for d: int in Config.ALTAR_SET_DOWN_SEARCH_TILES + 1:
		for y: int in range(f.y - d, f.y + d + 1):
			for x: int in range(f.x - d, f.x + d + 1):
				if maxi(absi(x - f.x), absi(y - f.y)) != d:
					continue
				var rect: Rect2i = Rect2i(Vector2i(x, y) - half, Config.ALTAR_FOOTPRINT)
				if not heretics.is_empty() and _lights_a_heretic(data, rect, heretics):
					continue  # M5-fix: the cheap check first (only allowed or not matters in a search)
				if _refusal(data, rect, bodies, heretics, reserved).is_empty():
					return rect
	return Rect2i()


## Whether an altar on `rect` would light one of `heretics` (place_refusal's WHY_HERETIC test alone).
static func _lights_a_heretic(data: WorldData, rect: Rect2i, heretics: Array[Vector2]) -> bool:
	var zone: SafeZone = SafeZone.new(centre_px(rect), Config.safe_radius_px())
	for h: Vector2 in heretics:
		if not Combat.box_outside_light(data, zone, h):
			return true
	return false


## M5-fix: where a carried altar comes down when it must (its carrier went down or left): set_down_rect around `feet`,
## then the same ignoring the heretics, then around `home` (where it was picked up: its own footprint first when it is
## still allowed) with and without them; `home_first` (a carrier leaving with Config.ALTAR_SET_DOWN_WHEN_CARRIER_LEAVES
## off) tries around `home` first. Every footprint returned passes place_refusal with `bodies` (and, unless that try
## ignores them, `heretics`), so nothing lying, standing or placed there is ever covered. An empty rect when none of
## them finds a place (the callers then keep the altar carried; with no home known, only `feet` is searched).
static func set_down_fallback(data: WorldData, feet: Vector2, home: Rect2i, bodies: Array[Vector2] = [],
		heretics: Array[Vector2] = [], home_first: bool = false) -> Rect2i:
	var around: Array[Vector2] = [feet]
	if home.has_area():
		var at_home: Vector2 = Arena.spawn_feet(home.get_center())  # its feet tile = the home's centre tile: ring 0 = home
		if home_first:
			around.push_front(at_home)
		else:
			around.append(at_home)
	var none: Array[Vector2] = []
	for point: Vector2 in around:
		for attempt: int in 2:
			var rect: Rect2i = set_down_rect(data, point, bodies, heretics if attempt == 0 else none)
			if rect.has_area():
				return rect
	return Rect2i()


## M5-fix: whether F held this frame by player `p` counts toward lifting the altar (offline Main.step_altar_hold, a
## session client's SessionHost.hold_altar, the host's own count NetMember.altar_hold): up, not carrying it, no body
## action playing, no purification channel running (the host refuses a lift while one runs, M5c), and no downed player
## among `players` (the players on its map) within Config.REVIVE_REACH_PX of its feet (F held there revives,
## Arena.reviver_for: PROVISIONAL README "M5b 키"). The aim (an altar tile in reach) is the caller's.
static func hold_counts(p: Player, players: Array[Player]) -> bool:
	if not p.vitals.alive() or p.carrying_altar or p.action_anim >= 0 or p.channel_tick > 0:
		return false
	for q: Player in players:
		if q != p and q.vitals.life == Vitals.Life.DOWN and q.sim_position.distance_to(p.sim_position) <= Config.REVIVE_REACH_PX:
			return false
	return true


## M5-fix (the host, which has the feet of every frame but not its aim): whether any altar tile is in reach of feet
## `feet` (WorldItems.in_reach). F held anywhere else does not count toward a lift.
static func altar_in_reach(data: WorldData, feet: Vector2) -> bool:
	var r: Rect2i = data.altar_rect
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			if WorldItems.in_reach(feet, Vector2i(x, y)):
				return true
	return false
