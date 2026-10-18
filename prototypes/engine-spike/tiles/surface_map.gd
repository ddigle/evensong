extends Node2D
## A surface map: one ground layer of grass / tilled soil / ash Wang tiles.
## method "b" = dual grid, "a" = Godot terrains. Soil and ash come from two different Wang sets
## (grass<->soil, grass<->ash), so a tile where soil touches ash has no art: the dual grid draws the
## nearest tile (WangLookup fallback) and Godot's solver leaves a seam.

const Wang := preload("res://tiles/wang.gd")
const WangLookup := preload("res://tiles/wang_lookup.gd")
const DualGrid := preload("res://tiles/dual_grid.gd")
const TerrainGrid := preload("res://tiles/terrain_grid.gd")
const TileBench := preload("res://tiles/tile_bench.gd")

var method: String = "b"
var width: int = 0
var height: int = 0
var ground_layer: TileMapLayer
var ground: RefCounted  # DualGrid or TerrainGrid


func setup(p_method: String, p_width: int, p_height: int, map: PackedByteArray) -> void:
	method = p_method
	width = p_width
	height = p_height
	var tile_set: TileSet = load(TileBench.SURFACE_TILESET) as TileSet
	ground_layer = TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.tile_set = tile_set
	add_child(ground_layer)
	if method == "b":
		ground = DualGrid.new(ground_layer, WangLookup.new(tile_set, TileBench.SURFACE_DISTANCE),
			width, height, Wang.GRASS)
	else:
		ground = TerrainGrid.new(ground_layer, width, height, Wang.GRASS)
	ground.call("fill", map)


func get_terrain(x: int, y: int) -> int:
	return int(ground.call("get_terrain", x, y))


func set_terrain(x: int, y: int, terrain: int) -> Array[Vector2i]:
	return ground.call("set_terrain", x, y, terrain)


func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / Wang.TILE), floori(local_pos.y / Wang.TILE))
