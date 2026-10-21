class_name WorldData
extends RefCounted
## The tile world as plain data: one byte per cell for each of the six layers of
## gameplay-design §3.1 (● floor / wall / ore / vegetation / corruption / placeables).
##
## Floor = vertex grid of the dual grid: the floor value of world cell (x, y) is the terrain at
## the vertex in the centre of that cell. The ground view draws display cells shifted by half a
## tile, so display cell (dx, dy) has the four vertices (dx, dy), (dx+1, dy), (dx, dy+1),
## (dx+1, dy+1) as its NW / NE / SW / SE corners (world/ground_view.gd). Vertices outside the map
## read OUTSIDE_TERRAIN.
##
## M1 uses FLOOR (grass / soil / ash), CORRUPTION (zone id 1.. per ash cell, 0 = clean) and
## PLACEABLE (PLACEABLE_ALTAR on the altar footprint). WALL, ORE and VEGETATION stay 0 until the
## features that use them exist.

enum Layer { FLOOR, WALL, ORE, VEGETATION, CORRUPTION, PLACEABLE }

const LAYER_COUNT: int = 6
const LAYER_NAMES: PackedStringArray = ["floor", "wall", "ore", "vegetation", "corruption", "placeable"]
const OUTSIDE_TERRAIN: int = Terrain.GRASS
const PLACEABLE_NONE: int = 0
const PLACEABLE_ALTAR: int = 1

var size: Vector2i = Vector2i.ZERO
var world_seed: int = 0
## Altar footprint in cells (PLACEABLE_ALTAR cells). Empty rect = no altar.
var altar_rect: Rect2i = Rect2i()
var layers: Array[PackedByteArray] = []


func _init(p_size: Vector2i = Vector2i.ZERO) -> void:
	size = p_size
	layers.clear()
	for i: int in LAYER_COUNT:
		var grid: PackedByteArray = PackedByteArray()
		grid.resize(size.x * size.y)
		grid.fill(0)
		layers.append(grid)
	layers[Layer.FLOOR].fill(OUTSIDE_TERRAIN)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func index_of(c: Vector2i) -> int:
	return c.y * size.x + c.x


## Layer value at a cell (0 outside the map; floor reads OUTSIDE_TERRAIN outside).
func get_value(layer: int, c: Vector2i) -> int:
	if not in_bounds(c):
		return OUTSIDE_TERRAIN if layer == Layer.FLOOR else 0
	return layers[layer][index_of(c)]


## Raw write without rules. Returns true if the value changed.
func set_value(layer: int, c: Vector2i, value: int) -> bool:
	if not in_bounds(c):
		return false
	var i: int = index_of(c)
	if layers[layer][i] == value:
		return false
	layers[layer][i] = value
	return true


## Floor terrain at vertex v (= world cell v).
func terrain_at(v: Vector2i) -> int:
	if v.x < 0 or v.y < 0 or v.x >= size.x or v.y >= size.y:
		return OUTSIDE_TERRAIN
	return layers[Layer.FLOOR][v.y * size.x + v.x]


## Corner key of display cell d (corners = vertices d, d+(1,0), d+(0,1), d+(1,1)).
func key_at_display(d: Vector2i) -> int:
	if d.x >= 0 and d.y >= 0 and d.x + 1 < size.x and d.y + 1 < size.y:
		var floor_grid: PackedByteArray = layers[Layer.FLOOR]
		var i: int = d.y * size.x + d.x
		return floor_grid[i] + 3 * floor_grid[i + 1] + 9 * floor_grid[i + size.x] + 27 * floor_grid[i + size.x + 1]
	return Terrain.key_of(terrain_at(d), terrain_at(d + Vector2i(1, 0)), terrain_at(d + Vector2i(0, 1)),
		terrain_at(d + Vector2i(1, 1)))


## Whether vertex v may become `terrain` (inside the map, and no soil next to ash: the 8
## neighbouring vertices share a display cell with v).
func can_set_terrain(v: Vector2i, terrain: int) -> bool:
	if not in_bounds(v) or terrain < 0 or terrain >= Terrain.COUNT:
		return false
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			if (ox != 0 or oy != 0) and not Terrain.can_touch(terrain, terrain_at(v + Vector2i(ox, oy))):
				return false
	return true


## Sets the floor terrain at vertex v if allowed. Returns true if the value changed.
func set_terrain(v: Vector2i, terrain: int) -> bool:
	if not can_set_terrain(v, terrain):
		return false
	return set_value(Layer.FLOOR, v, terrain)


func count_value(layer: int, value: int) -> int:
	return layers[layer].count(value)


## Display cells whose corners mix soil and ash (no art). 0 on a valid surface.
func soil_ash_contacts() -> int:
	var n: int = 0
	for dy: int in range(-1, size.y):
		for dx: int in range(-1, size.x):
			if not Terrain.key_has_art(key_at_display(Vector2i(dx, dy))):
				n += 1
	return n


func altar_center_px() -> Vector2:
	return (Vector2(altar_rect.position) + Vector2(altar_rect.size) / 2.0) * Config.TILE


## md5 of the size, seed, altar and every layer. Equal hashes = equal worlds.
func content_hash() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var header: PackedInt64Array = PackedInt64Array([size.x, size.y, world_seed, altar_rect.position.x,
		altar_rect.position.y, altar_rect.size.x, altar_rect.size.y, LAYER_COUNT])
	ctx.update(header.to_byte_array())
	for grid: PackedByteArray in layers:
		ctx.update(grid)
	return ctx.finish().hex_encode()
