extends Node2D
## A dungeon map built from several TileMapLayers (gameplay-design §3.1 layers, partly):
##   Floor      floor tiles with variants (display grid, i.e. shifted by half a tile like the walls)
##   Walls      Wang wall tiles: method "b" = dual grid (all-floor display cells left empty so the
##              floor layer shows), method "a" = Godot terrains (draws every cell)
##   Ore        ore overlays on wall cells (world grid, transparent outside the ore)
##   Collision  one invisible full-square collision tile per wall cell (world grid)
## break_wall() / place_wall() keep all four in step.

const Wang := preload("res://tiles/wang.gd")
const WangLookup := preload("res://tiles/wang_lookup.gd")
const DualGrid := preload("res://tiles/dual_grid.gd")
const TerrainGrid := preload("res://tiles/terrain_grid.gd")
const TileBench := preload("res://tiles/tile_bench.gd")
const Builder := preload("res://tiles/build_tilesets.gd")

var method: String = "b"
var width: int = 0
var height: int = 0
var tile_set: TileSet
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var ore_layer: TileMapLayer
var collision_layer: TileMapLayer
var walls: RefCounted  # DualGrid or TerrainGrid
var ores: Dictionary = {}  # Vector2i -> atlas coords in the overlay source


func setup(p_method: String, p_width: int, p_height: int, map: PackedByteArray, p_ores: Dictionary = {}) -> void:
	method = p_method
	width = p_width
	height = p_height
	tile_set = load(TileBench.DUNGEON_TILESET) as TileSet
	floor_layer = _layer("Floor", 0)
	wall_layer = _layer("Walls", 1)
	ore_layer = _layer("Ore", 2)
	collision_layer = _layer("Collision", 3)
	collision_layer.visible = false
	ore_layer.collision_enabled = false
	floor_layer.collision_enabled = false

	var floor_lookup: WangLookup = WangLookup.new(tile_set, TileBench.DUNGEON_DISTANCE)
	var all_floor: int = Wang.key_of(Wang.FLOOR, Wang.FLOOR, Wang.FLOOR, Wang.FLOOR)
	floor_layer.position = Vector2(Wang.TILE / 2.0, Wang.TILE / 2.0)
	for dy: int in range(-1, height):
		for dx: int in range(-1, width):
			var i: int = floor_lookup.pick_index(all_floor, dx, dy, Callable())
			floor_layer.set_cell(Vector2i(dx, dy), floor_lookup.sources[all_floor][i], floor_lookup.coords[all_floor][i], 0)

	if method == "b":
		walls = DualGrid.new(wall_layer, floor_lookup, width, height, Wang.WALL, true, all_floor)
	else:
		walls = TerrainGrid.new(wall_layer, width, height, Wang.WALL, true)
	walls.call("fill", map)
	for y: int in height:
		for x: int in width:
			if map[y * width + x] == Wang.WALL:
				collision_layer.set_cell(Vector2i(x, y), Builder.SRC_OVERLAY, Builder.OVERLAY_SOLID, 0)
	for c: Vector2i in p_ores:
		if is_wall(c.x, c.y):
			ores[c] = p_ores[c]
			ore_layer.set_cell(c, Builder.SRC_OVERLAY, p_ores[c], 0)


func is_wall(x: int, y: int) -> bool:
	return int(walls.call("get_terrain", x, y)) == Wang.WALL


## Mines a wall cell. Returns the wall-layer cells that were redrawn (empty: nothing to break).
func break_wall(x: int, y: int) -> Array[Vector2i]:
	if not is_wall(x, y) or x <= 0 or y <= 0 or x >= width - 1 or y >= height - 1:
		return [] as Array[Vector2i]
	var redrawn: Array[Vector2i] = walls.call("set_terrain", x, y, Wang.FLOOR)
	var c: Vector2i = Vector2i(x, y)
	collision_layer.erase_cell(c)
	if ores.has(c):
		ores.erase(c)
		ore_layer.erase_cell(c)
	return redrawn


## Builds a wall cell back (no ore).
func place_wall(x: int, y: int) -> Array[Vector2i]:
	if is_wall(x, y) or x < 0 or y < 0 or x >= width or y >= height:
		return [] as Array[Vector2i]
	var redrawn: Array[Vector2i] = walls.call("set_terrain", x, y, Wang.WALL)
	collision_layer.set_cell(Vector2i(x, y), Builder.SRC_OVERLAY, Builder.OVERLAY_SOLID, 0)
	return redrawn


## World cell under a position local to this node.
func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / Wang.TILE), floori(local_pos.y / Wang.TILE))


func _layer(layer_name: String, z: int) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = z
	add_child(layer)
	return layer
