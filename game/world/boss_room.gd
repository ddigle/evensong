class_name BossRoom
extends RefCounted
## M12a: where the heretic leader fights in the first dungeon (● game-concept §12 "보스 1개 (이단의 지도자)", the room and its pillars
## PROVISIONAL, Config "M12a" BOSS_ARENA_MIN_SIZE and BOSS_PILLARS): the room, its walkable tiles, the boss's home and the cracked support
## pillars' tiles, all worked out from the world seed alone (DungeonGen.build: the rooms as generated, before anyone mined) and the boss's
## own random stream (Config.BOSS_SALT), so every machine that generates the seed gets the same place and no older stream moves. No tile
## edit: the generated worlds' golden hashes stay; the pillars block through WorldData.blockers (combat/boss_fight.gd).
##
## The room: among the generated rooms but the arrival room and the shrine's, the one whose centre tile is farthest from the arrival tile
## by walking steps (Arena.arrival_distances on the generated terrain) among those at least Config.BOSS_ARENA_MIN_SIZE (tiles, the north
## wall's face row counted); when none is that big, the biggest other room by walkable area (ties: the farther, then the first). A dungeon
## with no room but those two has no boss room (has_room() false: no fight).
## The home: the middle tile of the walkable rows (the face row is the north wall's, not floor).
## The pillars: Config.BOSS_PILLARS "count" one-tile spots (see the Config comment for every gap); fewer than "min_count" fit, the door
## gap and then the home gap are cut by one and it tries again.

## A room's walkable part (the rows under its north wall's face row), in tiles.
static func walk_of(room: Rect2i) -> Rect2i:
	return Rect2i(room.position + Vector2i(0, 1), room.size - Vector2i(0, 1))


class Layout:
	extends RefCounted
	## The room as DungeonGen made it (its face row included; empty: none) and its walkable tiles.
	var room: Rect2i = Rect2i()
	var walk: Rect2i = Rect2i()
	## Its index in DungeonGen.Layout.rooms, its centre tile's walking steps from the arrival tile, and whether it is the fallback
	## (no room was Config.BOSS_ARENA_MIN_SIZE).
	var room_index: int = -1
	var distance: int = -1
	var fallback: bool = false
	var home_tile: Vector2i = Vector2i.ZERO
	## The pillars' tiles, in the order they were picked, and the doorway tiles of the floor (where corridors come in).
	var pillars: Array[Vector2i] = []
	var doors: Array[Vector2i] = []

	func has_room() -> bool:
		return room.has_area()

	## The boss's home feet (low in its tile, like an arrival or a heretic's spawn: Arena.spawn_feet).
	func home_feet() -> Vector2:
		return Arena.spawn_feet(home_tile)

	## The walkable tiles in px.
	func floor_px() -> Rect2:
		return Rect2(Vector2(walk.position * Config.TILE), Vector2(walk.size * Config.TILE))

	## Whether feet `feet` stand in the room (its walkable tiles).
	func holds(feet: Vector2) -> bool:
		return has_room() and floor_px().has_point(feet)

	func describe() -> String:
		if not has_room():
			return "no room"
		return "room=%d,%d %dx%d index=%d distance=%d%s home=%d,%d pillars=%s" % [room.position.x, room.position.y, room.size.x,
			room.size.y, room_index, distance, " (fallback)" if fallback else "", home_tile.x, home_tile.y, str(pillars)]


## The boss room of world seed `world_seed` (its dungeon generated again here: the rooms as generated).
static func for_seed(world_seed: int) -> Layout:
	var built: Array = DungeonGen.build(world_seed)
	var data: WorldData = built[0]
	var gen: DungeonGen.Layout = built[1]
	return choose(data, gen, world_seed)


## The boss room of generated dungeon `data` (with its generator's `gen`), pillars from `world_seed`'s stream.
static func choose(data: WorldData, gen: DungeonGen.Layout, world_seed: int) -> Layout:
	var out: Layout = Layout.new()
	var dist: Dictionary[Vector2i, int] = Arena.arrival_distances(data)
	var best: int = -1
	var best_d: int = -1
	var big: int = -1
	var big_area: int = -1
	var big_d: int = -1
	for i: int in gen.rooms.size():
		if i == gen.arrival_room or i == gen.shrine_room:
			continue
		var r: Rect2i = gen.rooms[i]
		var d: int = room_distance(r, dist)
		if r.size.x >= Config.BOSS_ARENA_MIN_SIZE.x and r.size.y >= Config.BOSS_ARENA_MIN_SIZE.y and d > best_d:
			best = i
			best_d = d
		var area: int = walk_of(r).get_area()
		if area > big_area or (area == big_area and d > big_d):
			big = i
			big_area = area
			big_d = d
	if best < 0:
		if big < 0:
			return out
		best = big
		best_d = big_d
		out.fallback = true
	out.room_index = best
	out.room = gen.rooms[best]
	out.walk = walk_of(out.room)
	out.distance = best_d
	out.home_tile = out.walk.position + Vector2i(out.walk.size.x / 2, out.walk.size.y / 2)
	out.doors = doorways(data, out.walk)
	out.pillars = pick_pillars(data, out, world_seed)
	return out


## Walking steps from the arrival tile to room `r`'s centre tile (its nearest reachable floor tile when the centre is not reachable; -1 = none).
static func room_distance(r: Rect2i, dist: Dictionary[Vector2i, int]) -> int:
	var f: Rect2i = walk_of(r)
	var centre: Vector2i = f.position + f.size / 2
	if dist.has(centre):
		return dist[centre]
	var near: int = -1
	for y: int in range(f.position.y, f.end.y):
		for x: int in range(f.position.x, f.end.x):
			var c: Vector2i = Vector2i(x, y)
			if dist.has(c) and (near < 0 or dist[c] < near):
				near = dist[c]
	return near


## The floor's doorway tiles: tiles of `floor` with an open tile (no wall, no blocking placeable) right outside it (4 ways).
static func doorways(data: WorldData, walk: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(walk.position.y, walk.end.y):
		for x: int in range(walk.position.x, walk.end.x):
			var c: Vector2i = Vector2i(x, y)
			for d: Vector2i in DungeonGen.STEPS:
				var n: Vector2i = c + d
				if not walk.has_point(n) and data.in_bounds(n) and not Arena.terrain_blocked(data, n):
					out.append(c)
					break
	return out


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The pillars of `room` (its floor, home and doorways set): see the class comment. The first from the stream, then each next the
## allowed tile farthest (the least squared distance to the home and the pillars picked so far, largest) from them; ties: the first in
## row order.
static func pick_pillars(data: WorldData, room: Layout, world_seed: int) -> Array[Vector2i]:
	var want: int = int(Config.BOSS_PILLARS["count"])
	var least: int = int(Config.BOSS_PILLARS["min_count"])
	var door_gap: int = int(Config.BOSS_PILLARS["door_gap_tiles"])
	var home_gap: int = int(Config.BOSS_PILLARS["home_gap_tiles"])
	var picked: Array[Vector2i] = []
	while true:
		picked = _pick(data, room, world_seed, want, door_gap, home_gap)
		if picked.size() >= least:
			break
		if door_gap > 1:
			door_gap -= 1
		elif home_gap > 2:
			home_gap -= 1
		else:
			break
	return picked


static func _pick(data: WorldData, room: Layout, world_seed: int, want: int, door_gap: int, home_gap: int) -> Array[Vector2i]:
	var margin: int = int(Config.BOSS_PILLARS["margin_tiles"])
	var spacing: int = int(Config.BOSS_PILLARS["spacing_tiles"])
	var f: Rect2i = room.walk
	var allowed: Array[Vector2i] = []
	for y: int in range(f.position.y + margin, f.end.y - margin):
		for x: int in range(f.position.x + margin, f.end.x - margin):
			var c: Vector2i = Vector2i(x, y)
			if cheb(c, room.home_tile) < home_gap:
				continue
			var ok: bool = true
			for d: Vector2i in room.doors:
				if cheb(c, d) < door_gap:
					ok = false
					break
			for oy: int in range(-margin, margin + 1):
				for ox: int in range(-margin, margin + 1):
					if Arena.terrain_blocked(data, c + Vector2i(ox, oy)):
						ok = false
			if ok:
				allowed.append(c)
	var out: Array[Vector2i] = []
	if allowed.is_empty() or want <= 0:
		return out
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([world_seed, Config.MAP_DUNGEON, Config.BOSS_SALT, 1])
	out.append(allowed[rng.randi_range(0, allowed.size() - 1)])
	while out.size() < want:
		var best: Vector2i = Walls.NO_CELL
		var best_score: int = -1
		for c: Vector2i in allowed:
			var near: bool = false
			var score: int = (c - room.home_tile).length_squared()
			for q: Vector2i in out:
				if cheb(c, q) < spacing:
					near = true
					break
				score = mini(score, (c - q).length_squared())
			if near:
				continue
			if score > best_score:
				best = c
				best_score = score
		if best_score < 0:
			break
		out.append(best)
	return out
