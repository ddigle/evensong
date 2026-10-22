class_name DungeonGen
extends RefCounted
## Seeded first dungeon (M3a; ○ game-concept §12 "첫 던전 1개 (= 첫 오염 원천)", ○ gameplay-design
## §3.1 "던전 = 나가는 층. 별도 맵"). Same seed + size -> same WorldData on every machine: only
## RandomNumberGenerator (PCG32) and integer cell math, no float noise (unlike SurfaceGen's ash edges).
## Every number is PROVISIONAL (core/config.gd "M3a").
##
##   1. Rock everywhere (WALL = ROCK), an unbreakable BEDROCK ring Config.DUNGEON_BORDER_TILES wide.
##   2. Rooms: up to Config.DUNGEON_ROOM_COUNT rectangles (DUNGEON_ROOM_MIN..MAX), at least
##      DUNGEON_ROOM_GAP rock tiles from each other and from the bedrock. Room 0 is the arrival room.
##   3. Corridors: every room joins the nearest room already joined (by centre) with an L-shaped
##      corridor DUNGEON_CORRIDOR_WIDTH wide from centre to centre. So every room is reachable.
##   4. Exit stairs: EXIT_FOOTPRINT tiles of a room's top row (wall faces) under rock (one more rock
##      tile on each side), nearest the room's middle; the rock above them becomes bedrock (the stairs
##      cannot be dug out). That room is the arrival room: the first room (in placing order) with such a
##      spot left after the corridors. The arrival point is just south of the stairs.
##   5. Shrine spot: SHRINE_FOOTPRINT in the middle of the room whose centre is farthest from the
##      arrival room's (PLACEABLE_SHRINE; the heretic shrine with its fire off, not destroyable yet).
##   6. Ore veins: Config.DUNGEON_VEINS per kind, each grown from a rock tile next to open floor
##      (so it can be mined from the rooms and corridors) by a random walk through rock,
##      DUNGEON_VEIN_SIZE_MIN..MAX tiles (ORE = copper / iron).
##   7. Wall torches (decoration): on every room's north wall above a face, one every
##      DUNGEON_WALL_TORCH_SPACING tiles (two beside the exit in the arrival room), not on ore.

const MAX_ATTEMPTS: int = 200
## IMPL: WorldData.content_hash() of generate(Config.DEFAULT_SEED) with the current constants. It pins
## the output (tests/test_dungeon.gd, --smoke); whether the rules hold is checked over many seeds.
## Update it when the generator or its constants change on purpose (the failure prints the new value).
const GOLDEN_HASH: String = "009e7147ad7969ac9098fc6cd2afcd4a"
## Mixed into the seed so the dungeon's random numbers do not repeat the surface's.
const SEED_SALT: int = 0x5D0E5
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## A generated dungeon and where things are (also derivable from the data: see find_layout()).
class Layout:
	extends RefCounted
	var rooms: Array[Rect2i] = []
	var exit_rect: Rect2i = Rect2i()
	var shrine_rect: Rect2i = Rect2i()
	var arrival_room: int = 0
	var shrine_room: int = -1


static func generate(world_seed: int, size: Vector2i = Config.DUNGEON_SIZE) -> WorldData:
	return build(world_seed, size)[0]


## [WorldData, Layout].
static func build(world_seed: int, size: Vector2i = Config.DUNGEON_SIZE) -> Array:
	var data: WorldData = WorldData.new(size)
	data.world_seed = world_seed
	data.map_id = Config.MAP_DUNGEON
	data.layers[WorldData.Layer.FLOOR].fill(0)
	var layout: Layout = Layout.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (world_seed * 2654435761 + SEED_SALT) & 0x7fffffffffffffff
	_fill_rock(data)
	_place_rooms(data, rng, layout)
	_join_rooms(data, rng, layout)
	_place_exit(data, layout)
	_place_shrine(data, layout)
	_place_veins(data, rng)
	_place_wall_torches(data, layout)
	return [data, layout]


static func _fill_rock(data: WorldData) -> void:
	var b: int = Config.DUNGEON_BORDER_TILES
	for y: int in data.size.y:
		for x: int in data.size.x:
			var edge: bool = x < b or y < b or x >= data.size.x - b or y >= data.size.y - b
			data.set_value(WorldData.Layer.WALL, Vector2i(x, y), Walls.pack(Walls.KIND_BEDROCK if edge else Walls.KIND_ROCK, 0))


static func _carve(data: WorldData, rect: Rect2i) -> void:
	var b: int = Config.DUNGEON_BORDER_TILES
	var inner: Rect2i = Rect2i(Vector2i(b, b), data.size - Vector2i(2 * b, 2 * b))
	var r: Rect2i = rect.intersection(inner)
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			data.set_value(WorldData.Layer.WALL, Vector2i(x, y), 0)


static func _place_rooms(data: WorldData, rng: RandomNumberGenerator, layout: Layout) -> void:
	var lo: int = Config.DUNGEON_BORDER_TILES + Config.DUNGEON_ROOM_GAP
	for n: int in Config.DUNGEON_ROOM_COUNT:
		for attempt: int in MAX_ATTEMPTS:
			var w: int = rng.randi_range(Config.DUNGEON_ROOM_MIN.x, Config.DUNGEON_ROOM_MAX.x)
			var h: int = rng.randi_range(Config.DUNGEON_ROOM_MIN.y, Config.DUNGEON_ROOM_MAX.y)
			if data.size.x - 2 * lo < w or data.size.y - 2 * lo < h:
				break
			var r: Rect2i = Rect2i(rng.randi_range(lo, data.size.x - lo - w), rng.randi_range(lo, data.size.y - lo - h), w, h)
			var clear: bool = true
			for other: Rect2i in layout.rooms:
				if other.grow(Config.DUNGEON_ROOM_GAP).intersects(r):
					clear = false
					break
			if clear:
				layout.rooms.append(r)
				_carve(data, r)
				break


static func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


static func _join_rooms(data: WorldData, rng: RandomNumberGenerator, layout: Layout) -> void:
	var half: int = Config.DUNGEON_CORRIDOR_WIDTH / 2
	var w: int = Config.DUNGEON_CORRIDOR_WIDTH
	for i: int in range(1, layout.rooms.size()):
		var a: Vector2i = _center(layout.rooms[i])
		var best: int = 0
		for j: int in i:
			if (_center(layout.rooms[j]) - a).length_squared() < (_center(layout.rooms[best]) - a).length_squared():
				best = j
		var b: Vector2i = _center(layout.rooms[best])
		var horizontal_first: bool = rng.randi_range(0, 1) == 0
		var corner: Vector2i = Vector2i(b.x, a.y) if horizontal_first else Vector2i(a.x, b.y)
		var points: Array[Vector2i] = [a, corner, b]
		for k: int in 2:
			var p: Vector2i = points[k]
			var q: Vector2i = points[k + 1]
			var top_left: Vector2i = Vector2i(mini(p.x, q.x) - half, mini(p.y, q.y) - half)
			var size: Vector2i = Vector2i(absi(p.x - q.x) + w, absi(p.y - q.y) + w)
			_carve(data, Rect2i(top_left, size))


## Exit stairs: two tiles of the arrival room's top row whose tiles above are rock (wall faces),
## nearest the room's middle.
static func _place_exit(data: WorldData, layout: Layout) -> void:
	var w: int = Config.EXIT_FOOTPRINT.x
	var best: int = -1
	var room: Rect2i = Rect2i()
	for r: int in layout.rooms.size():
		room = layout.rooms[r]
		var mid: int = room.position.x + (room.size.x - w) / 2
		for x: int in range(room.position.x + 1, room.end.x - w):
			var ok: bool = true
			for i: int in range(-1, w + 1):
				if not Walls.is_wall(data, Vector2i(x + i, room.position.y - 1)):
					ok = false
			if ok and (best < 0 or absi(x - mid) < absi(best - mid)):
				best = x
		if best >= 0:
			layout.arrival_room = r
			break
	if best < 0:
		return
	layout.exit_rect = Rect2i(Vector2i(best, room.position.y), Config.EXIT_FOOTPRINT)
	data.put_placeable(layout.exit_rect, WorldData.PLACEABLE_EXIT)
	for i: int in w:
		data.set_value(WorldData.Layer.WALL, Vector2i(best + i, room.position.y - 1), Walls.pack(Walls.KIND_BEDROCK, 0))


static func _place_shrine(data: WorldData, layout: Layout) -> void:
	var far: int = -1
	var a: Vector2i = _center(layout.rooms[layout.arrival_room]) if not layout.rooms.is_empty() else Vector2i.ZERO
	for i: int in layout.rooms.size():
		if i == layout.arrival_room:
			continue
		if far < 0 or (_center(layout.rooms[i]) - a).length_squared() > (_center(layout.rooms[far]) - a).length_squared():
			far = i
	if far < 0:
		return
	var room: Rect2i = layout.rooms[far]
	var fp: Vector2i = Config.SHRINE_FOOTPRINT
	# The room's top row is the north wall's face: centre the shrine in the rows below it.
	var pos: Vector2i = Vector2i(room.position.x + (room.size.x - fp.x) / 2, room.position.y + 1 + (room.size.y - 1 - fp.y) / 2)
	layout.shrine_room = far
	layout.shrine_rect = Rect2i(pos, fp)
	data.put_placeable(layout.shrine_rect, WorldData.PLACEABLE_SHRINE)


## A rock tile a vein may start from: breakable rock without ore with open floor beside it (or its
## face below it with open floor beyond), so it can be mined from where players walk.
static func _vein_seed_ok(data: WorldData, c: Vector2i) -> bool:
	if Walls.kind_at(data, c) != Walls.KIND_ROCK or Walls.ore_at(data, c) != Walls.ORE_NONE:
		return false
	if Walls.hardness(data, c) == Walls.UNBREAKABLE:
		return false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if _open(data, c + d):
			return true
	var below: Vector2i = c + Vector2i(0, 1)
	return _open(data, below) or (Walls.is_face(data, below) and _open(data, below + Vector2i(0, 1)))


## Floor a player can stand on (no wall, no face, no blocking placeable).
static func _open(data: WorldData, c: Vector2i) -> bool:
	return data.in_bounds(c) and not Movement.is_blocked(data, c)


static func _place_veins(data: WorldData, rng: RandomNumberGenerator) -> void:
	var seeds: Array[Vector2i] = []
	for c: Vector2i in Walls.wall_cells(data):
		if _vein_seed_ok(data, c):
			seeds.append(c)
	if seeds.is_empty():
		return
	for kind: StringName in Config.DUNGEON_VEINS:
		var ore: int = Walls.ORE_NAMES.find(String(kind))
		for n: int in Config.DUNGEON_VEINS[kind]:
			for attempt: int in MAX_ATTEMPTS:
				var c: Vector2i = seeds[rng.randi_range(0, seeds.size() - 1)]
				if not _vein_seed_ok(data, c):
					continue
				var size: int = rng.randi_range(Config.DUNGEON_VEIN_SIZE_MIN, Config.DUNGEON_VEIN_SIZE_MAX)
				var vein: Array[Vector2i] = [c]
				data.set_value(WorldData.Layer.ORE, c, ore)
				for step: int in size * 4:
					if vein.size() >= size:
						break
					var from: Vector2i = vein[rng.randi_range(0, vein.size() - 1)]
					var next: Vector2i = from + STEPS[rng.randi_range(0, 3)]
					if Walls.kind_at(data, next) == Walls.KIND_ROCK and Walls.ore_at(data, next) == Walls.ORE_NONE \
							and Walls.hardness(data, next) != Walls.UNBREAKABLE:
						data.set_value(WorldData.Layer.ORE, next, ore)
						vein.append(next)
				break


static func _place_wall_torches(data: WorldData, layout: Layout) -> void:
	for i: int in layout.rooms.size():
		var room: Rect2i = layout.rooms[i]
		var y: int = room.position.y - 1
		var xs: Array[int] = []
		if i == layout.arrival_room and layout.exit_rect.has_area():
			xs = [layout.exit_rect.position.x - 2, layout.exit_rect.end.x + 1]
		else:
			var x: int = room.position.x + 2
			while x < room.end.x - 1:
				xs.append(x)
				x += Config.DUNGEON_WALL_TORCH_SPACING
		for x: int in xs:
			var c: Vector2i = Vector2i(x, y)
			if Walls.kind_at(data, c) == Walls.KIND_ROCK and Walls.ore_at(data, c) == Walls.ORE_NONE \
					and Walls.is_face(data, c + Vector2i(0, 1)) \
					and data.get_value(WorldData.Layer.PLACEABLE, c + Vector2i(0, 1)) == WorldData.PLACEABLE_NONE:
				data.set_value(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_WALL_TORCH)


# --- reading a dungeon back ------------------------------------------------------------------

## The exit stairs' footprint (empty rect when there is none).
static func exit_rect(data: WorldData) -> Rect2i:
	var all: Array[Rect2i] = data.footprints(WorldData.PLACEABLE_EXIT)
	return all[0] if not all.is_empty() else Rect2i()


static func shrine_rect(data: WorldData) -> Rect2i:
	var all: Array[Rect2i] = data.footprints(WorldData.PLACEABLE_SHRINE)
	return all[0] if not all.is_empty() else Rect2i()


## Where a player arrives (feet, px): the middle of the tiles just south of `portal`, low in the tile.
static func arrival_below(portal: Rect2i) -> Vector2:
	return Vector2(portal.position.x * Config.TILE + portal.size.x * Config.TILE / 2.0,
		portal.end.y * Config.TILE + Config.TILE - 4)


## The dungeon's arrival point (feet, px), next to the exit stairs.
static func arrival_point(data: WorldData) -> Vector2:
	return arrival_below(exit_rect(data))


## Tiles a player can stand on that are reachable from tile `start` (4-neighbour steps over open
## floor), as a set.
static func reachable(data: WorldData, start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {}
	if not _open(data, start):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var i: int = 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in STEPS:
			var n: Vector2i = c + d
			if not seen.has(n) and _open(data, n):
				seen[n] = true
				queue.append(n)
	return seen


## Whether a pickaxe can hit wall tile `c` from a tile in `standing` (a target tile in reach whose
## hit lands on `c`: `c` itself or its face).
static func minable_from(data: WorldData, c: Vector2i, standing: Dictionary[Vector2i, bool]) -> bool:
	var targets: Array[Vector2i] = [c]
	if Walls.is_face(data, c + Vector2i(0, 1)):
		targets.append(c + Vector2i(0, 1))
	for t: Vector2i in targets:
		for oy: int in range(-Config.REACH_TILES, Config.REACH_TILES + 1):
			for ox: int in range(-Config.REACH_TILES, Config.REACH_TILES + 1):
				if (ox != 0 or oy != 0) and standing.has(t + Vector2i(ox, oy)):
					return true
	return false
