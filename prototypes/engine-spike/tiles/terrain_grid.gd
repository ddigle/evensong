extends RefCounted
## Method (a): Godot's built-in terrains (terrain set 0, Match Corners) via
## TileMapLayer.set_cells_terrain_connect().
##
## The TileMapLayer cell IS the world cell (no offset). Godot treats the cell's terrain as the tile's
## center bit and solves the corner bits between neighbours; a corner only gets the painted terrain
## when all four cells around it have it. Dungeon mode paints FACE on a floor cell under a wall,
## the same rule as the dual grid uses for vertices, so one edit can repaint two cells.

const Wang := preload("res://tiles/wang.gd")

var layer: TileMapLayer
var width: int = 0
var height: int = 0
var logical: PackedByteArray = []   # world terrain per cell, as set by the game
var painted: PackedByteArray = []   # terrain painted into Godot (= logical, or FACE derived)
var dungeon: bool = false
var outside: int = 0
var terrain_calls: int = 0          # set_cells_terrain_connect calls so far
var cells_painted: int = 0          # cells passed to those calls


func _init(p_layer: TileMapLayer, p_width: int, p_height: int, p_outside: int, p_dungeon: bool = false) -> void:
	layer = p_layer
	width = p_width
	height = p_height
	outside = p_outside
	dungeon = p_dungeon
	layer.position = Vector2.ZERO
	logical.resize(width * height)
	logical.fill(outside)
	painted.resize(width * height)
	painted.fill(outside)


## Sets every world cell from `values` (width * height, row-major).
## base_fill = true: first set_cell() every cell to a pure tile of the most common terrain, then let
## Godot paint only the other terrains (much less solver work). false: paint every terrain.
func fill(values: PackedByteArray, base_fill: bool = true) -> void:
	assert(values.size() == width * height)
	logical = values.duplicate()
	var groups: Array[Array] = [[], [], []]
	for y: int in height:
		for x: int in width:
			var t: int = _derive(x, y)
			painted[y * width + x] = t
			groups[t].append(Vector2i(x, y))
	var order: Array[int] = [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return groups[a].size() > groups[b].size())
	var start: int = 0
	if base_fill:
		var base: int = order[0]
		var pure: Array = pure_tile(layer.tile_set, base)
		for y: int in height:
			for x: int in width:
				layer.set_cell(Vector2i(x, y), pure[0], pure[1], pure[2])
		start = 1
	for i: int in range(start, order.size()):
		var t: int = order[i]
		if groups[t].is_empty():
			continue
		var cells: Array[Vector2i] = []
		cells.assign(groups[t])
		_paint(cells, t)


func get_terrain(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return outside
	return logical[y * width + x]


## Sets one world cell. Returns the cells passed to Godot (empty if nothing changed).
func set_terrain(x: int, y: int, terrain: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if x < 0 or y < 0 or x >= width or y >= height or logical[y * width + x] == terrain:
		return cells
	logical[y * width + x] = terrain
	var by_terrain: Dictionary = {}
	for c: Vector2i in [Vector2i(x, y), Vector2i(x, y + 1)]:
		if c.y >= height or (c.y != y and not dungeon):
			continue
		var t: int = _derive(c.x, c.y)
		if c.y != y and painted[c.y * width + c.x] == t:
			continue
		painted[c.y * width + c.x] = t
		if not by_terrain.has(t):
			by_terrain[t] = [] as Array[Vector2i]
		(by_terrain[t] as Array[Vector2i]).append(c)
		cells.append(c)
	for t: int in by_terrain:
		_paint(by_terrain[t], t)
	return cells


## [source_id, atlas_coords, alternative] of a tile whose center and four corners are `terrain`.
static func pure_tile(tile_set: TileSet, terrain: int) -> Array:
	for i: int in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(i)
		var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for t: int in source.get_tiles_count():
			var atlas: Vector2i = source.get_tile_id(t)
			for a: int in source.get_alternative_tiles_count(atlas):
				var alt: int = source.get_alternative_tile_id(atlas, a)
				var td: TileData = source.get_tile_data(atlas, alt)
				if td.terrain_set != 0 or td.terrain != terrain:
					continue
				var pure: bool = true
				for bit: int in Wang.PEERING_BITS:
					if td.get_terrain_peering_bit(bit) != terrain:
						pure = false
				if pure:
					return [source_id, atlas, alt]
	return [-1, Vector2i(-1, -1), 0]


## Corner terrains [NW, NE, SW, SE] of the tile Godot placed in cell c (-1 = empty / no terrain).
func cell_corners(c: Vector2i) -> PackedInt32Array:
	var td: TileData = layer.get_cell_tile_data(c)
	if td == null or td.terrain_set != 0:
		return PackedInt32Array([-1, -1, -1, -1])
	return PackedInt32Array([td.get_terrain_peering_bit(Wang.PEERING_BITS[0]), td.get_terrain_peering_bit(Wang.PEERING_BITS[1]),
		td.get_terrain_peering_bit(Wang.PEERING_BITS[2]), td.get_terrain_peering_bit(Wang.PEERING_BITS[3])])


func cell_center(c: Vector2i) -> int:
	var td: TileData = layer.get_cell_tile_data(c)
	return td.terrain if td != null and td.terrain_set == 0 else -1


func _paint(cells: Array[Vector2i], terrain: int) -> void:
	terrain_calls += 1
	cells_painted += cells.size()
	layer.set_cells_terrain_connect(cells, 0, terrain, true)


func _derive(x: int, y: int) -> int:
	var t: int = logical[y * width + x]
	if not dungeon:
		return t
	var above: int = logical[(y - 1) * width + x] if y > 0 else outside
	return Wang.derive_dungeon(above == Wang.WALL, t == Wang.WALL)
