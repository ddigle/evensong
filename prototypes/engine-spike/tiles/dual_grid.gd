extends RefCounted
## Method (b): vertex grid ("dual grid") placement of Wang corner tiles.
##
## The game sets one terrain per world cell. That value is a *vertex* of the display grid: the
## display TileMapLayer is shifted by half a tile, so display cell (dx, dy) has its NW corner at the
## centre of world cell (dx, dy) and its four corners are world cells (dx, dy), (dx+1, dy),
## (dx, dy+1), (dx+1, dy+1). The tile is looked up from those four values (wang_lookup.gd).
## A W x H world uses (W+1) x (H+1) display cells, -1..W-1 / -1..H-1; vertices outside the map
## read `outside`. Changing one world cell redraws the 4 display cells around it (more when the
## tileset has context tiles, see WangLookup.reach_*).
##
## Dungeon mode: the world sets FLOOR or WALL; a floor vertex directly under a wall vertex becomes
## FACE (wall front face), so one edit can change two vertices.

const Wang := preload("res://tiles/wang.gd")
const WangLookup := preload("res://tiles/wang_lookup.gd")

var layer: TileMapLayer
var lookup: WangLookup
var width: int = 0
var height: int = 0
var logical: PackedByteArray = []   # world terrain per cell, as set by the game
var vertices: PackedByteArray = []  # corner terrains (= logical, or with FACE derived in dungeon mode)
var outside: int = 0                # logical terrain outside the map
var dungeon: bool = false
var empty_key: int = -1             # corner key drawn as an empty cell (e.g. all-floor on a wall layer)
var cells_written: int = 0          # set_cell / erase_cell calls so far (stats)
var _outside_vertex: int = 0
var _vertex_callable: Callable


func _init(p_layer: TileMapLayer, p_lookup: WangLookup, p_width: int, p_height: int, p_outside: int,
		p_dungeon: bool = false, p_empty_key: int = -1) -> void:
	layer = p_layer
	lookup = p_lookup
	width = p_width
	height = p_height
	outside = p_outside
	dungeon = p_dungeon
	empty_key = p_empty_key
	_outside_vertex = Wang.derive_dungeon(outside == Wang.WALL, outside == Wang.WALL) if dungeon else outside
	_vertex_callable = vertex
	layer.position = Vector2(Wang.TILE / 2.0, Wang.TILE / 2.0)
	logical.resize(width * height)
	logical.fill(outside)
	vertices.resize(width * height)
	vertices.fill(_outside_vertex)


## Sets every world cell from `values` (width * height, row-major) and redraws the whole map.
func fill(values: PackedByteArray) -> void:
	assert(values.size() == width * height)
	logical = values.duplicate()
	for y: int in height:
		for x: int in width:
			vertices[y * width + x] = _derive(x, y)
	for dy: int in range(-1, height):
		for dx: int in range(-1, width):
			_draw(dx, dy)


func get_terrain(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return outside
	return logical[y * width + x]


## Corner terrain of vertex (x, y) (= world cell). Outside the map: the outside terrain.
func vertex(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return _outside_vertex
	return vertices[y * width + x]


## The four corner terrains [NW, NE, SW, SE] of display cell (dx, dy).
func display_corners(dx: int, dy: int) -> PackedByteArray:
	return PackedByteArray([vertex(dx, dy), vertex(dx + 1, dy), vertex(dx, dy + 1), vertex(dx + 1, dy + 1)])


## Sets one world cell. Returns the display cells that were redrawn (empty if nothing changed).
func set_terrain(x: int, y: int, terrain: int) -> Array[Vector2i]:
	var redrawn: Array[Vector2i] = []
	if x < 0 or y < 0 or x >= width or y >= height or logical[y * width + x] == terrain:
		return redrawn
	logical[y * width + x] = terrain
	var changed: Array[Vector2i] = []
	for v: Vector2i in [Vector2i(x, y), Vector2i(x, y + 1)]:
		if v.y >= height or (v.y != y and not dungeon):
			continue
		var value: int = _derive(v.x, v.y)
		if vertices[v.y * width + v.x] != value:
			vertices[v.y * width + v.x] = value
			changed.append(v)
	var seen: Dictionary = {}
	for v: Vector2i in changed:
		for dy: int in range(v.y - 1 - lookup.reach_down, v.y + lookup.reach_up + 1):
			for dx: int in range(v.x - 1 - lookup.reach_right, v.x + lookup.reach_left + 1):
				if dx < -1 or dy < -1 or dx >= width or dy >= height:
					continue
				var d: Vector2i = Vector2i(dx, dy)
				if seen.has(d):
					continue
				seen[d] = true
				_draw(dx, dy)
				redrawn.append(d)
	return redrawn


func _derive(x: int, y: int) -> int:
	var t: int = logical[y * width + x]
	if not dungeon:
		return t
	var above: int = logical[(y - 1) * width + x] if y > 0 else outside
	return Wang.derive_dungeon(above == Wang.WALL, t == Wang.WALL)


func _draw(dx: int, dy: int) -> void:
	var key: int
	if dx >= 0 and dy >= 0 and dx + 1 < width and dy + 1 < height:
		var i: int = dy * width + dx
		key = vertices[i] + 3 * vertices[i + 1] + 9 * vertices[i + width] + 27 * vertices[i + width + 1]
	else:
		key = vertex(dx, dy) + 3 * vertex(dx + 1, dy) + 9 * vertex(dx, dy + 1) + 27 * vertex(dx + 1, dy + 1)
	cells_written += 1
	var cell: Vector2i = Vector2i(dx, dy)
	if key == empty_key:
		layer.erase_cell(cell)
		return
	var source: int = lookup.single_source[key]
	if source >= 0:
		layer.set_cell(cell, source, lookup.single_coords[key], 0)
		return
	var i: int = lookup.pick_index(key, dx, dy, _vertex_callable)
	layer.set_cell(cell, lookup.sources[key][i], lookup.coords[key][i], 0)
