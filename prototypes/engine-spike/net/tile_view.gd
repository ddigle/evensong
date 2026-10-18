extends Node2D
## Draws a TileWorld with one TileMapLayer per data layer (floor, wall, ore). The TileSet is
## built at runtime from flat colours (the net module needs no art). Every instance (host and
## clients) keeps its view in step with its data, and matches() proves they agree.

const TileWorld := preload("res://net/tile_world.gd")

const SOURCE_ID: int = 0
## Atlas columns: floor 1..4 -> 0..3, dirt 4, stone 5, bedrock 6, ore 7.
const ATLAS_COLORS: Array[Color] = [
	Color(0.18, 0.15, 0.13), Color(0.22, 0.18, 0.14), Color(0.20, 0.20, 0.17), Color(0.16, 0.17, 0.15),
	Color(0.45, 0.33, 0.22), Color(0.42, 0.40, 0.38), Color(0.10, 0.08, 0.10), Color(0.85, 0.68, 0.30),
]
const COL_DIRT: int = 4
const COL_STONE: int = 5
const COL_BEDROCK: int = 6
const COL_ORE: int = 7

var map_layers: Array[TileMapLayer] = []


func _init() -> void:
	name = "TileView"
	var tile_set: TileSet = make_tile_set()
	for i: int in TileWorld.LAYER_COUNT:
		var layer: TileMapLayer = TileMapLayer.new()
		layer.name = TileWorld.LAYER_NAMES[i].capitalize()
		layer.tile_set = tile_set
		add_child(layer)
		map_layers.append(layer)


static func make_tile_set() -> TileSet:
	var px: int = TileWorld.TILE_PX
	var img: Image = Image.create_empty(px * ATLAS_COLORS.size(), px, false, Image.FORMAT_RGBA8)
	for i: int in ATLAS_COLORS.size():
		var base: Color = ATLAS_COLORS[i]
		if i == COL_ORE:
			img.fill_rect(Rect2i(i * px + 5, 5, 6, 6), base)
			continue
		img.fill_rect(Rect2i(i * px, 0, px, px), base)
		if i >= COL_DIRT:
			img.fill_rect(Rect2i(i * px, px - 3, px, 3), base.darkened(0.35))
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(img)
	source.texture_region_size = Vector2i(px, px)
	for i: int in ATLAS_COLORS.size():
		source.create_tile(Vector2i(i, 0))
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(px, px)
	tile_set.add_source(source, SOURCE_ID)
	return tile_set


## Atlas coords for a data value, (-1, -1) = no tile.
static func atlas_for(layer: int, value: int) -> Vector2i:
	if value == 0:
		return Vector2i(-1, -1)
	match layer:
		TileWorld.LAYER_FLOOR:
			return Vector2i(clampi(value - 1, 0, 3), 0)
		TileWorld.LAYER_WALL:
			if value == TileWorld.WALL_BEDROCK:
				return Vector2i(COL_BEDROCK, 0)
			return Vector2i(COL_STONE if value == TileWorld.WALL_STONE else COL_DIRT, 0)
		TileWorld.LAYER_ORE:
			return Vector2i(COL_ORE, 0)
	return Vector2i(-1, -1)


func set_world_cell(layer: int, c: Vector2i, value: int) -> void:
	var atlas: Vector2i = atlas_for(layer, value)
	if atlas.x < 0:
		map_layers[layer].erase_cell(c)
	else:
		map_layers[layer].set_cell(c, SOURCE_ID, atlas)


func rebuild_rect(world: TileWorld, rect: Rect2i) -> void:
	for layer: int in TileWorld.LAYER_COUNT:
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var c: Vector2i = Vector2i(x, y)
				set_world_cell(layer, c, world.get_cell(layer, c))


func rebuild(world: TileWorld) -> void:
	for layer: TileMapLayer in map_layers:
		layer.clear()
	rebuild_rect(world, Rect2i(0, 0, world.width, world.height))


## Every TileMapLayer cell shows what the data says. Returns the first mismatch or "".
func first_mismatch(world: TileWorld) -> String:
	for layer: int in TileWorld.LAYER_COUNT:
		var map_layer: TileMapLayer = map_layers[layer]
		for y: int in world.height:
			for x: int in world.width:
				var c: Vector2i = Vector2i(x, y)
				var want: Vector2i = atlas_for(layer, world.get_cell(layer, c))
				if map_layer.get_cell_atlas_coords(c) != want:
					return "%s %s: view %s, data %s" % [
						TileWorld.LAYER_NAMES[layer], c, map_layer.get_cell_atlas_coords(c), want]
	return ""
