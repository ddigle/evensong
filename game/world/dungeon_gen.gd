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
##      spot left after the corridors that also leaves a wall torch spot beside the stairs (M3-fix; if
##      no room has one, the first room with a spot). The arrival point is just south of the stairs.
##   5. Shrine spot: SHRINE_FOOTPRINT in the middle of the room whose centre is farthest from the
##      arrival room's (PLACEABLE_SHRINE; the heretic shrine with its fire off, not destroyable yet).
##   6. The arrival room's two wall torches, one on each side of the exit stairs (step 8).
##   7. Ore veins: Config.DUNGEON_VEINS per kind, each grown from a rock tile next to open floor
##      (so it can be mined from the rooms and corridors) by a random walk through rock,
##      DUNGEON_VEIN_SIZE_MIN..MAX tiles (ORE = copper / iron). Not into the arrival room's wall
##      torches (M3-fix; the candidate list and the random numbers are as before, so a dungeon whose
##      veins never reached those tiles keeps its veins).
##   8. Wall torches (decoration) on every other room's north wall above a face, one every
##      DUNGEON_WALL_TORCH_SPACING tiles, not on ore. M3-fix: a spot that is not plain rock with a
##      face below moves to the nearest one on the same wall, and every room whose north wall has such
##      a spot gets at least one; the arrival room always gets one (before, a bad spot was just
##      skipped, and about one arrival room in five had no wall torch).

const MAX_ATTEMPTS: int = 200
## IMPL: WorldData.content_hash() of generate(Config.DEFAULT_SEED) with the current constants. It pins
## the output (tests/test_dungeon.gd, --smoke); whether the rules hold is checked over many seeds.
## Update it when the generator or its constants change on purpose (the failure prints the new value).
const GOLDEN_HASH: String = "8dda0ad69ad9747c3eadf30abde6524c"
## IMPL (M3b): seeds_digest() with the current constants: md5 over the content hashes of the dungeons of
## seeds 1..SEEDS_DIGEST_COUNT. --smoke prints and checks it so the human can see that another machine
## (the ARM64 Surface) makes the same dungeons (integer math only: it should).
const SEEDS_DIGEST_COUNT: int = 8
const SEEDS_GOLDEN: String = "acc0a9bc23599abfd4babd317207231c"
## IMPL: mixed into the seed so the dungeon's random numbers do not repeat the surface's (seed *
## SEED_MULTIPLIER + SEED_SALT; the multiplier is Knuth's multiplicative hash constant).
const SEED_SALT: int = 0x5D0E5
const SEED_MULTIPLIER: int = 2654435761
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
	rng.seed = (world_seed * SEED_MULTIPLIER + SEED_SALT) & 0x7fffffffffffffff
	_fill_rock(data)
	_place_rooms(data, rng, layout)
	_join_rooms(data, rng, layout)
	_place_exit(data, layout)
	_place_shrine(data, layout)
	_place_wall_torches(data, layout, true)
	_place_veins(data, rng)
	_place_wall_torches(data, layout, false)
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
## nearest the room's middle. M3-fix: a spot that leaves a wall torch spot on the same north wall
## (beside the arch, wall_torch_spot_ok) comes first, so the arrival room gets a wall torch: the first
## room (in placing order) with such a spot; only if no room has one, the first room with any spot.
static func _place_exit(data: WorldData, layout: Layout) -> void:
	var w: int = Config.EXIT_FOOTPRINT.x
	var pick: Vector2i = Vector2i(-1, -1)  # (room, x)
	var fallback: Vector2i = Vector2i(-1, -1)
	for r: int in layout.rooms.size():
		var room: Rect2i = layout.rooms[r]
		var y: int = room.position.y - 1
		var mid: int = room.position.x + (room.size.x - w) / 2
		var best: int = -1
		var best_lit: int = -1
		for x: int in range(room.position.x + 1, room.end.x - w):
			var ok: bool = true
			for i: int in range(-1, w + 1):
				if not Walls.is_wall(data, Vector2i(x + i, y)):
					ok = false
			if not ok:
				continue
			if best < 0 or absi(x - mid) < absi(best - mid):
				best = x
			if _torch_spot_beside(data, room, x) and (best_lit < 0 or absi(x - mid) < absi(best_lit - mid)):
				best_lit = x
		if best_lit >= 0:
			pick = Vector2i(r, best_lit)
			break
		if best >= 0 and fallback.x < 0:
			fallback = Vector2i(r, best)
	if pick.x < 0:
		pick = fallback
	if pick.x < 0:
		return
	layout.arrival_room = pick.x
	var room: Rect2i = layout.rooms[pick.x]
	var best: int = pick.y
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


## Rock a vein may take: breakable, without ore, without a wall torch (the arrival room's, placed
## before the veins).
static func _vein_rock(data: WorldData, c: Vector2i) -> bool:
	return Walls.kind_at(data, c) == Walls.KIND_ROCK and Walls.ore_at(data, c) == Walls.ORE_NONE \
		and data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_NONE \
		and Walls.hardness(data, c) != Walls.UNBREAKABLE


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
				if not _vein_seed_ok(data, c) or not _vein_rock(data, c):
					continue
				var size: int = rng.randi_range(Config.DUNGEON_VEIN_SIZE_MIN, Config.DUNGEON_VEIN_SIZE_MAX)
				var vein: Array[Vector2i] = [c]
				data.set_value(WorldData.Layer.ORE, c, ore)
				for step: int in size * 4:
					if vein.size() >= size:
						break
					var from: Vector2i = vein[rng.randi_range(0, vein.size() - 1)]
					var next: Vector2i = from + STEPS[rng.randi_range(0, 3)]
					if _vein_rock(data, next):
						data.set_value(WorldData.Layer.ORE, next, ore)
						vein.append(next)
				break


## Wall torches on every room's north wall (the row above the room's top row). A spot is wanted every
## Config.DUNGEON_WALL_TORCH_SPACING tiles, or in the arrival room one on each side of the exit stairs
## (clear of the arch, which is wider than the stairs). A wanted spot that is not a torch spot
## (wall_torch_spot_ok: a corridor opening, ore, no face below) moves to the nearest torch spot on the
## same wall: within (SPACING - 1) / 2 tiles for the spaced ones; for the two beside the stairs the
## nearest on that side of the stairs, else the nearest anywhere on the wall. Torches keep one tile
## between them. A room that got none this way gets one at the spot nearest its middle, if its wall
## has any spot at all. `arrival` true: the arrival room only (before the veins); false: the others.
static func _place_wall_torches(data: WorldData, layout: Layout, arrival: bool) -> void:
	for i: int in layout.rooms.size():
		if (i == layout.arrival_room) != arrival:
			continue
		var room: Rect2i = layout.rooms[i]
		var y: int = room.position.y - 1
		var whole: Vector2i = Vector2i(room.position.x, room.end.x - 1)  # columns (inclusive)
		var arch: Vector2i = Vector2i(1, 0)  # columns no torch may take: none by default
		var taken: Array[int] = []
		if i == layout.arrival_room and layout.exit_rect.has_area():
			arch = Vector2i(layout.exit_rect.position.x - 1, layout.exit_rect.end.x)
			var sides: Array[Vector2i] = [Vector2i(whole.x, arch.x - 1), Vector2i(arch.y + 1, whole.y)]
			for k: int in 2:
				var from: int = arch.x - 1 if k == 0 else arch.y + 1
				var away: int = -1 if k == 0 else 1
				var x: int = _torch_spot_near(data, y, from, away, room.size.x, sides[k], arch, taken)
				if x < 0:
					x = _torch_spot_near(data, y, from, away, room.size.x, whole, arch, taken)
				if x >= 0:
					taken.append(x)
		else:
			var x: int = room.position.x + 2
			while x < room.end.x - 1:
				var spot: int = _torch_spot_near(data, y, x, 1, (Config.DUNGEON_WALL_TORCH_SPACING - 1) / 2, whole, arch, taken)
				if spot >= 0:
					taken.append(spot)
				x += Config.DUNGEON_WALL_TORCH_SPACING
		if taken.is_empty():
			var mid: int = _torch_spot_near(data, y, room.position.x + room.size.x / 2, 1, room.size.x, whole, arch, taken)
			if mid >= 0:
				taken.append(mid)
		for x: int in taken:
			data.set_value(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_WALL_TORCH)


## Whether the north wall of `room` has a wall torch spot outside the exit arch of stairs at `x`.
static func _torch_spot_beside(data: WorldData, room: Rect2i, x: int) -> bool:
	for tx: int in range(room.position.x, room.end.x):
		if (tx < x - 1 or tx > x + Config.EXIT_FOOTPRINT.x) and wall_torch_spot_ok(data, Vector2i(tx, room.position.y - 1)):
			return true
	return false


## Whether wall tile `c` may carry a wall torch: plain rock (no ore, no placeable) whose face below is
## open floor without a placeable (not the exit stairs), so the torch hangs on a face players see.
static func wall_torch_spot_ok(data: WorldData, c: Vector2i) -> bool:
	var below: Vector2i = c + Vector2i(0, 1)
	return Walls.kind_at(data, c) == Walls.KIND_ROCK and Walls.ore_at(data, c) == Walls.ORE_NONE \
		and data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_NONE \
		and Walls.is_face(data, below) \
		and data.get_value(WorldData.Layer.PLACEABLE, below) == WorldData.PLACEABLE_NONE


## The torch spot on row `y` nearest column `from` (within `reach`, the side `away` first on a tie),
## inside columns `span` (inclusive), outside `arch` and not next to a `taken` one; -1 if none.
static func _torch_spot_near(data: WorldData, y: int, from: int, away: int, reach: int, span: Vector2i,
		arch: Vector2i, taken: Array[int]) -> int:
	for d: int in reach + 1:
		for x: int in ([from] if d == 0 else [from + away * d, from - away * d]):
			if x < span.x or x > span.y or (x >= arch.x and x <= arch.y):
				continue
			var near_taken: bool = false
			for t: int in taken:
				if absi(x - t) < 2:
					near_taken = true
			if not near_taken and wall_torch_spot_ok(data, Vector2i(x, y)):
				return x
	return -1


## md5 over the content hashes of the dungeons of seeds 1..count (see SEEDS_GOLDEN).
static func seeds_digest(count: int = SEEDS_DIGEST_COUNT) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for i: int in count:
		ctx.update(generate(i + 1).content_hash().to_ascii_buffer())
	return ctx.finish().hex_encode()


# --- reading a dungeon back ------------------------------------------------------------------

## The exit stairs' footprint (empty rect when there is none).
static func exit_rect(data: WorldData) -> Rect2i:
	var all: Array[Rect2i] = data.footprints(WorldData.PLACEABLE_EXIT)
	return all[0] if not all.is_empty() else Rect2i()


static func shrine_rect(data: WorldData) -> Rect2i:
	var all: Array[Rect2i] = data.footprints(WorldData.PLACEABLE_SHRINE)
	return all[0] if not all.is_empty() else Rect2i()


## Where a player arrives (feet, px): the middle of the tiles just south of `portal`, low in the tile
## (Config.ARRIVAL_FEET_INSET_PX above its bottom edge).
static func arrival_below(portal: Rect2i) -> Vector2:
	return Vector2(portal.position.x * Config.TILE + portal.size.x * Config.TILE / 2.0,
		portal.end.y * Config.TILE + Config.TILE - Config.ARRIVAL_FEET_INSET_PX)


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
