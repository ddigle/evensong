class_name SurfaceGen
extends RefCounted
## Seeded surface start area (M1). Same seed + size -> same WorldData. Late join relies on this on
## every machine (RandomNumberGenerator = PCG32 and integer cell math, but FastNoiseLite is float
## math). Checked on x86_64 only: GOLDEN_HASH below is the x86_64 result, --smoke compares the
## running build with it, and a joining client compares its world md5 with the host's.
##
##   1. Altar site: Config.ALTAR_FOOTPRINT cells at the map centre (PLACEABLE_ALTAR).
##   2. Tilled soil: Config.SOIL_PATCH_COUNT rectangles, every cell completely inside the altar
##      safe radius (corners included), not on the altar or the 1-cell walkway around it, and not
##      touching each other.
##   3. Ash: Config.ASH_ZONE_COUNT fixed corruption zones (noise-ragged discs) whose cells all lie
##      at least ASH_CLEARANCE_TILES outside the safe radius. CORRUPTION = zone id (1..).
##   Everything else is grass. Soil and ash never share a display cell (WorldData.set_terrain
##   refuses it, and the distances keep them far apart anyway).

const MAX_ATTEMPTS: int = 200
## IMPL: WorldData.content_hash() of generate(Config.DEFAULT_SEED) with the current constants, as
## generated on the x86_64 desktop. It pins the output (an unintended change fails test_world.gd,
## and --smoke on another machine shows whether that machine generates the same world); whether
## the rules hold is checked separately over many seeds. When the generator or its constants
## change on purpose, update it (the failure prints the new value).
const GOLDEN_HASH: String = "e04258e54b02b0ed09ce02c9a92c11a8"


static func generate(world_seed: int, size: Vector2i = Config.MAP_SIZE) -> WorldData:
	var data: WorldData = WorldData.new(size)
	data.world_seed = world_seed
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed
	_place_altar(data)
	_place_soil(data, rng)
	_place_ash(data, rng)
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
	noise.seed = data.world_seed & 0x7fffffff
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
