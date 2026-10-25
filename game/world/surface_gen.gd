class_name SurfaceGen
extends RefCounted
## Seeded surface start area (M1). Same seed + size -> same WorldData on one machine
## (RandomNumberGenerator = PCG32 and integer cell math, but FastNoiseLite is float math, so another
## architecture may differ). Checked on x86_64 only: GOLDEN_HASH below is the x86_64 result and
## --smoke compares the running build with it. Late join does not depend on it: the host sends its
## world (net/world_snapshot.gd) and a joiner only reports whether its own generator agrees.
##
##   1. Altar site: Config.ALTAR_FOOTPRINT cells at the map centre (PLACEABLE_ALTAR).
##   2. Tilled soil: Config.SOIL_PATCH_COUNT rectangles, every cell completely inside the altar
##      safe radius (corners included), not on the altar or the 1-cell walkway around it, and not
##      touching each other.
##   3. Ash: Config.ASH_ZONE_COUNT fixed corruption zones (noise-ragged discs) whose cells all lie
##      at least ASH_CLEARANCE_TILES outside the safe radius. CORRUPTION = zone id (1..).
##   4. Gatherables (M2b, VEGETATION = WorldItems value): Config.GATHER_ON_GRASS on clean grass and
##      Config.GATHER_ON_ASH on ash, in that order and count, every one with its cell centre at least
##      GATHER_CLEARANCE_TILES beyond the safe radius, at least 2 cells from the map edge (so every
##      side can be reached), and none in the 8 cells around another (PROVISIONAL counts and places).
##   5. Dungeon entrance (M3a, PLACEABLE_ENTRANCE): Config.ENTRANCE_FOOTPRINT at Config.
##      ENTRANCE_OFFSET_TILES from the altar footprint's top-left cell, or, if that spot is not clear,
##      the nearest clear one (rings of growing distance around it, row by row): every footprint cell
##      centre beyond the safe radius + 1 tile, the footprint and the tiles around it inside the map
##      (2 tiles from the edge) with no gatherable, no placeable and no soil. Placed after step 4 and
##      without random numbers, so the gatherables are where they were in M2b.
##   6. Trees (M7b, PLACEABLE_TREE, ● game-concept §12 R37 one species; the rest PROVISIONAL Config "M7b"): Config.TREE_COUNT
##      trunk tiles on clean grass (tree_spot_ok: away from the light, the ash, the edges, the entrance, every gatherable and
##      placeable around the crown, and each other), from their own random stream (Config.TREE_SALT), after step 5, so
##      steps 1-5 are as they were (the gatherables, the entrance).
##   Everything else is grass. Soil and ash never share a display cell (WorldData.set_terrain
##   refuses it, and the distances keep them far apart anyway).

const MAX_ATTEMPTS: int = 200
## IMPL: WorldData.content_hash() of generate(Config.DEFAULT_SEED) with the current constants, as
## generated on the x86_64 desktop. It pins the output (an unintended change fails test_world.gd,
## and --smoke on another machine shows whether that machine generates the same world); whether
## the rules hold is checked separately over many seeds. When the generator or its constants
## change on purpose, update it (the failure prints the new value). M3a changed it on purpose: step 5
## puts the dungeon entrance into the PLACEABLE layer (the gatherables did not move). M7b changed it on purpose: step 6 puts
## the trees into the PLACEABLE layer (1d9f92c7b5ef2a715f95cc32d7424b36 before; nothing else moved).
const GOLDEN_HASH: String = "0da8e0d26ded851fff02fabdaa33c3ad"
## Cells kept free between a gatherable and the map edge (PROVISIONAL, Config).
const GATHER_EDGE: int = Config.GATHER_EDGE_TILES

## Test only (--test-perturb-generator, set by the Cli autoload before the world is generated):
## shifts the ash edge noise seed, so this process generates a different world from the same seed,
## like a machine whose float noise came out differently. tests/test_net_session.gd gives it to a
## late joiner, which must still end with the host's world.
static var test_perturb: bool = false


static func generate(world_seed: int, size: Vector2i = Config.MAP_SIZE) -> WorldData:
	var data: WorldData = WorldData.new(size)
	data.world_seed = world_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed
	_place_altar(data)
	_place_soil(data, rng)
	_place_ash(data, rng)
	_place_gatherables(data, rng, Config.GATHER_ON_GRASS, Terrain.GRASS)
	_place_gatherables(data, rng, Config.GATHER_ON_ASH, Terrain.ASH)
	_place_entrance(data)
	_place_trees(data)
	return data


static func _place_altar(data: WorldData) -> void:
	var origin: Vector2i = (data.size - Config.ALTAR_FOOTPRINT) / 2
	data.altar_rect = Rect2i(origin, Config.ALTAR_FOOTPRINT)
	for y: int in range(data.altar_rect.position.y, data.altar_rect.end.y):
		for x: int in range(data.altar_rect.position.x, data.altar_rect.end.x):
			data.set_value(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_ALTAR)


## True if every point of the cell rect (pixel corners) lies within `radius` px of `center`.
static func rect_inside_radius(rect: Rect2i, center: Vector2, radius: float) -> bool:
	var p0: Vector2 = Vector2(rect.position * Config.TILE)
	var p1: Vector2 = Vector2(rect.end * Config.TILE)
	for corner: Vector2 in [p0, Vector2(p1.x, p0.y), Vector2(p0.x, p1.y), p1]:
		if corner.distance_to(center) > radius:
			return false
	return true


static func _place_soil(data: WorldData, rng: RandomNumberGenerator) -> void:
	var center: Vector2 = data.altar_center_px()
	var radius: float = Config.safe_radius_px()
	var keep_out: Rect2i = data.altar_rect.grow(1)
	var lo: Vector2i = Vector2i(floori((center.x - radius) / Config.TILE), floori((center.y - radius) / Config.TILE))
	var hi: Vector2i = Vector2i(ceili((center.x + radius) / Config.TILE), ceili((center.y + radius) / Config.TILE))
	var placed: Array[Rect2i] = []
	for p: int in Config.SOIL_PATCH_COUNT:
		for attempt: int in MAX_ATTEMPTS:
			var w: int = rng.randi_range(Config.SOIL_PATCH_MIN.x, Config.SOIL_PATCH_MAX.x)
			var h: int = rng.randi_range(Config.SOIL_PATCH_MIN.y, Config.SOIL_PATCH_MAX.y)
			var rect: Rect2i = Rect2i(rng.randi_range(lo.x, hi.x - w), rng.randi_range(lo.y, hi.y - h), w, h)
			if not rect_inside_radius(rect, center, radius) or rect.intersects(keep_out):
				continue
			if not Rect2i(Vector2i.ZERO, data.size).encloses(rect):
				continue
			var clear: bool = true
			for other: Rect2i in placed:
				if other.grow(1).intersects(rect):
					clear = false
					break
			if not clear:
				continue
			placed.append(rect)
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					data.set_terrain(Vector2i(x, y), Terrain.SOIL)
			break


static func _place_ash(data: WorldData, rng: RandomNumberGenerator) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = (data.world_seed & 0x7fffffff) ^ (1 if test_perturb else 0)
	noise.frequency = Config.ASH_EDGE_NOISE_FREQUENCY
	var altar: Vector2 = data.altar_center_px()
	var min_dist_px: float = Config.safe_radius_px() + Config.ASH_CLEARANCE_TILES * Config.TILE
	var amp: float = Config.ASH_EDGE_NOISE_TILES
	var zones: Array[Vector3i] = []  # x, y = centre cell, z = reach in cells
	for z: int in Config.ASH_ZONE_COUNT:
		for attempt: int in MAX_ATTEMPTS:
			var radius: int = rng.randi_range(Config.ASH_ZONE_RADIUS_MIN, Config.ASH_ZONE_RADIUS_MAX)
			var reach: int = radius + ceili(amp) + 1
			if data.size.x <= 2 * reach + 4 or data.size.y <= 2 * reach + 4:
				break
			var c: Vector2i = Vector2i(rng.randi_range(reach + 1, data.size.x - reach - 2),
				rng.randi_range(reach + 1, data.size.y - reach - 2))
			var c_px: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE
			if c_px.distance_to(altar) - reach * Config.TILE < min_dist_px:
				continue
			var clear: bool = true
			for other: Vector3i in zones:
				if Vector2(c).distance_to(Vector2(other.x, other.y)) < reach + other.z + 2:
					clear = false
					break
			if not clear:
				continue
			zones.append(Vector3i(c.x, c.y, reach))
			_fill_zone(data, noise, c, radius, reach, z + 1, altar, min_dist_px)
			break


static func _fill_zone(data: WorldData, noise: FastNoiseLite, c: Vector2i, radius: int, reach: int, zone_id: int,
		altar: Vector2, min_dist_px: float) -> void:
	for y: int in range(c.y - reach, c.y + reach + 1):
		for x: int in range(c.x - reach, c.x + reach + 1):
			var cell: Vector2i = Vector2i(x, y)
			var d: float = Vector2(cell).distance_to(Vector2(c))
			if d + noise.get_noise_2d(x, y) * Config.ASH_EDGE_NOISE_TILES > radius:
				continue
			var cell_px: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * Config.TILE
			if cell_px.distance_to(altar) < min_dist_px:
				continue
			if data.set_terrain(cell, Terrain.ASH):
				data.set_value(WorldData.Layer.CORRUPTION, cell, zone_id)


## Whether a gatherable may lie on cell `c` of ground `terrain` (step 4 of the class comment).
static func gatherable_spot_ok(data: WorldData, c: Vector2i, terrain: int) -> bool:
	if c.x < GATHER_EDGE or c.y < GATHER_EDGE or c.x >= data.size.x - GATHER_EDGE or c.y >= data.size.y - GATHER_EDGE:
		return false
	if data.terrain_at(c) != terrain or data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
		return false
	var min_px: float = Config.safe_radius_px() + Config.GATHER_CLEARANCE_TILES * Config.TILE
	if ((Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE).distance_to(data.altar_center_px()) < min_px:
		return false
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			if data.get_value(WorldData.Layer.VEGETATION, c + Vector2i(ox, oy)) != 0:
				return false
	return true


static func _place_gatherables(data: WorldData, rng: RandomNumberGenerator, counts: Dictionary[StringName, int],
		terrain: int) -> void:
	if data.size.x <= 2 * GATHER_EDGE or data.size.y <= 2 * GATHER_EDGE:
		return
	# Grass is most of the map: random cells. Ash is a few hundred cells: random picks from a list of
	# them (random map cells would mostly miss).
	var candidates: Array[Vector2i] = []
	if terrain != Terrain.GRASS:
		var floor_grid: PackedByteArray = data.layers[WorldData.Layer.FLOOR]
		for i: int in floor_grid.size():
			if floor_grid[i] == terrain:
				candidates.append(Vector2i(i % data.size.x, i / data.size.x))
		if candidates.is_empty():
			return
	for id: StringName in counts:
		var value: int = WorldItems.value_of(id)
		for n: int in counts[id]:
			for attempt: int in MAX_ATTEMPTS:
				var c: Vector2i = Vector2i.ZERO
				if candidates.is_empty():
					c = Vector2i(rng.randi_range(GATHER_EDGE, data.size.x - GATHER_EDGE - 1),
						rng.randi_range(GATHER_EDGE, data.size.y - GATHER_EDGE - 1))
				else:
					c = candidates[rng.randi_range(0, candidates.size() - 1)]
				if gatherable_spot_ok(data, c, terrain):
					data.set_value(WorldData.Layer.VEGETATION, c, value)
					break


## Whether the dungeon entrance may take footprint `rect` (step 5).
static func entrance_spot_ok(data: WorldData, rect: Rect2i) -> bool:
	var area: Rect2i = rect.grow(1)
	if not Rect2i(Vector2i(GATHER_EDGE, GATHER_EDGE), data.size - Vector2i(2 * GATHER_EDGE, 2 * GATHER_EDGE)).encloses(area):
		return false
	var min_px: float = Config.safe_radius_px() + Config.TILE
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var c: Vector2i = Vector2i(x, y)
			if data.get_value(WorldData.Layer.VEGETATION, c) != 0 or data.get_value(WorldData.Layer.PLACEABLE, c) != 0:
				return false
			if data.terrain_at(c) == Terrain.SOIL:
				return false
			if rect.has_point(c) and ((Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE).distance_to(data.altar_center_px()) < min_px:
				return false
	return true


static func _place_entrance(data: WorldData) -> void:
	var want: Vector2i = data.altar_rect.position + Config.ENTRANCE_OFFSET_TILES
	var reach: int = maxi(data.size.x, data.size.y)
	for d: int in reach:
		for y: int in range(want.y - d, want.y + d + 1):
			for x: int in range(want.x - d, want.x + d + 1):
				if maxi(absi(x - want.x), absi(y - want.y)) != d:
					continue
				var rect: Rect2i = Rect2i(Vector2i(x, y), Config.ENTRANCE_FOOTPRINT)
				if entrance_spot_ok(data, rect):
					data.put_placeable(rect, WorldData.PLACEABLE_ENTRANCE)
					return


## The dungeon entrance's footprint (empty rect when there is none).
static func entrance_rect(data: WorldData) -> Rect2i:
	var all: Array[Rect2i] = data.footprints(WorldData.PLACEABLE_ENTRANCE)
	return all[0] if not all.is_empty() else Rect2i()


## M7b: whether a tree's trunk may take tile `c` (step 6): clean grass at least Config.TREE_EDGE_TILES from the map's sides
## and bottom and Config.TREE_TOP_TILES from its top (the crown rises about 4.4 tiles), its centre at least
## Config.TREE_LIGHT_CLEARANCE_TILES beyond the safe radius, no ash within Config.TREE_ASH_CLEARANCE_TILES, nothing growing
## (a gatherable, soil) and no placeable in the crown's and the trunk's surroundings (Config.TREE_CLEAR_SIDE_TILES to either
## side, from Config.TREE_CLEAR_ABOVE_TILES above to Config.TREE_CLEAR_BELOW_TILES below), not within
## Config.TREE_ENTRANCE_CLEARANCE_TILES of the entrance, and no other tree within Config.TREE_SPACING_TILES.
static func tree_spot_ok(data: WorldData, c: Vector2i) -> bool:
	if c.x < Config.TREE_EDGE_TILES or c.x >= data.size.x - Config.TREE_EDGE_TILES or c.y < Config.TREE_TOP_TILES \
			or c.y >= data.size.y - Config.TREE_EDGE_TILES:
		return false
	if data.terrain_at(c) != Terrain.GRASS:
		return false
	var min_px: float = Config.safe_radius_px() + Config.TREE_LIGHT_CLEARANCE_TILES * Config.TILE
	if data.altar_rect.has_area() and ((Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE).distance_to(data.altar_center_px()) < min_px:
		return false
	var ash: int = Config.TREE_ASH_CLEARANCE_TILES
	for y: int in range(c.y - ash, c.y + ash + 1):
		for x: int in range(c.x - ash, c.x + ash + 1):
			if data.terrain_at(Vector2i(x, y)) == Terrain.ASH or data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				return false
	for y2: int in range(c.y - Config.TREE_CLEAR_ABOVE_TILES, c.y + Config.TREE_CLEAR_BELOW_TILES + 1):
		for x2: int in range(c.x - Config.TREE_CLEAR_SIDE_TILES, c.x + Config.TREE_CLEAR_SIDE_TILES + 1):
			var t: Vector2i = Vector2i(x2, y2)
			if data.get_value(WorldData.Layer.VEGETATION, t) != 0 or data.terrain_at(t) == Terrain.SOIL:
				return false
			if data.get_value(WorldData.Layer.PLACEABLE, t) != WorldData.PLACEABLE_NONE:
				return false
	var way: Rect2i = entrance_rect(data)
	if way.has_area() and way.grow(Config.TREE_ENTRANCE_CLEARANCE_TILES).has_point(c):
		return false
	var gap: int = Config.TREE_SPACING_TILES
	for y3: int in range(c.y - gap, c.y + gap + 1):
		for x3: int in range(c.x - gap, c.x + gap + 1):
			if data.get_value(WorldData.Layer.PLACEABLE, Vector2i(x3, y3)) == WorldData.PLACEABLE_TREE:
				return false
	return true


## M7b, step 6: Config.TREE_COUNT trees (random grass tiles from the trees' own stream, Config.TREE_SALT; a tree that finds
## no spot in MAX_ATTEMPTS tries is left out).
static func _place_trees(data: WorldData) -> void:
	if data.size.x <= 2 * Config.TREE_EDGE_TILES or data.size.y <= Config.TREE_TOP_TILES + Config.TREE_EDGE_TILES:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([data.world_seed, Config.TREE_SALT])
	for n: int in Config.TREE_COUNT:
		for attempt: int in MAX_ATTEMPTS:
			var c: Vector2i = Vector2i(rng.randi_range(Config.TREE_EDGE_TILES, data.size.x - Config.TREE_EDGE_TILES - 1),
				rng.randi_range(Config.TREE_TOP_TILES, data.size.y - Config.TREE_EDGE_TILES - 1))
			if tree_spot_ok(data, c):
				data.set_value(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_TREE)
				break
