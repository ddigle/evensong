class_name TilesetBuilder
extends RefCounted
## Builds the surface TileSet from our PixelLab PNGs and their JSON corner data (res://art/tiles/).
## The result only depends on those inputs, so building twice gives the same .tres
## (tools/build_tileset.gd saves it, tests/test_world.gd compares a fresh build with the file).
##
## Each tile gets custom data:
##   "corners"  PackedByteArray [NW, NE, SW, SE] of Terrain ids (read by WangTable)
##   "name"     String, e.g. "grass_soil/wang_13" or "grass_var/1"
## and TileData.probability = weight among tiles with the same corners (variants).
##
## Sources:
##   0       grass<->soil Wang set   tiles_grass-soil_v03.png + tiles_grass-soil_v01.json
##   1       grass<->ash Wang set    tiles_grass-corruption_v05.png + tiles_grass-corruption_v02.json
##           (its all-grass tile is skipped: source 0 already has one, they differ by 2 pixels)
##   10..13  grass variants          tiles_grass_var_1..4_v02.png
##   20..21  soil variants           tiles_soil_var_1..2_v01.png
##   30..32  ash variants            tiles_ash_var_1..3_v02.png

const ART_DIR: String = "res://art/tiles/"
const SURFACE_PATH: String = "res://world/tilesets/surface.tres"
const DATA_CORNERS: String = "corners"
const DATA_NAME: String = "name"

const SRC_GRASS_SOIL: int = 0
const SRC_GRASS_ASH: int = 1
const SRC_GRASS_VARIANTS: int = 10
const SRC_SOIL_VARIANTS: int = 20
const SRC_ASH_VARIANTS: int = 30

const GRASS_SOIL_PNG: String = "tiles_grass-soil_v03.png"
const GRASS_SOIL_JSON: String = "tiles_grass-soil_v01.json"
const GRASS_ASH_PNG: String = "tiles_grass-corruption_v05.png"
const GRASS_ASH_JSON: String = "tiles_grass-corruption_v02.json"
const GRASS_VARIANTS: PackedStringArray = [
	"tiles_grass_var_1_v02.png", "tiles_grass_var_2_v02.png", "tiles_grass_var_3_v02.png",
	"tiles_grass_var_4_v02.png",
]
const SOIL_VARIANTS: PackedStringArray = ["tiles_soil_var_1_v01.png", "tiles_soil_var_2_v01.png"]
const ASH_VARIANTS: PackedStringArray = [
	"tiles_ash_var_1_v02.png", "tiles_ash_var_2_v02.png", "tiles_ash_var_3_v02.png",
]
const CORNER_NAMES: PackedStringArray = ["NW", "NE", "SW", "SE"]


## One tile of a PixelLab Wang set.
class WangTileInfo:
	extends RefCounted
	var name: String = ""
	var corners: PackedByteArray = PackedByteArray()
	var rect: Rect2i = Rect2i()


## Reads a PixelLab create_topdown_tileset JSON (tileset_data.tiles[].corners / bounding_box).
## terrain_map maps PixelLab terrain names ("lower", "upper") to Terrain ids.
## Returns an empty array (and logs an error) if the file is not what we expect.
static func read_pixellab(json_path: String, terrain_map: Dictionary[String, int]) -> Array[WangTileInfo]:
	var out: Array[WangTileInfo] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not (parsed is Dictionary):
		push_error("TilesetBuilder: cannot parse %s" % json_path)
		return out
	var data: Dictionary = parsed
	var tileset_data: Dictionary = data.get("tileset_data", {})
	var tiles: Array = tileset_data.get("tiles", [])
	for raw: Variant in tiles:
		if not (raw is Dictionary):
			push_error("TilesetBuilder: %s has a tile that is not an object" % json_path)
			return []
		var tile: Dictionary = raw
		var corners_in: Dictionary = tile.get("corners", {})
		var info: WangTileInfo = WangTileInfo.new()
		info.name = str(tile.get("name", ""))
		for corner_name: String in CORNER_NAMES:
			var terrain_name: String = str(corners_in.get(corner_name, ""))
			if not terrain_map.has(terrain_name):
				push_error("TilesetBuilder: %s tile %s has unknown terrain '%s'" % [json_path, info.name, terrain_name])
				return []
			info.corners.append(terrain_map[terrain_name])
		var bb: Dictionary = tile.get("bounding_box", {})
		info.rect = Rect2i(_int_of(bb.get("x", -1)), _int_of(bb.get("y", -1)), _int_of(bb.get("width", 0)),
			_int_of(bb.get("height", 0)))
		if info.rect.size != Vector2i(Config.TILE, Config.TILE) or info.rect.position.x % Config.TILE != 0 \
				or info.rect.position.y % Config.TILE != 0:
			push_error("TilesetBuilder: %s tile %s has bounding box %s" % [json_path, info.name, info.rect])
			return []
		out.append(info)
	return out


static func build_surface() -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(Config.TILE, Config.TILE)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, DATA_CORNERS)
	ts.set_custom_data_layer_type(0, TYPE_PACKED_BYTE_ARRAY)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(1, DATA_NAME)
	ts.set_custom_data_layer_type(1, TYPE_STRING)

	var soil_map: Dictionary[String, int] = {"lower": Terrain.SOIL, "upper": Terrain.GRASS}
	var ash_map: Dictionary[String, int] = {"lower": Terrain.ASH, "upper": Terrain.GRASS}
	var used_keys: Dictionary[int, bool] = {}
	var ok: bool = _add_wang_source(ts, SRC_GRASS_SOIL, "grass_soil", GRASS_SOIL_PNG, GRASS_SOIL_JSON, soil_map,
		used_keys)
	ok = ok and _add_wang_source(ts, SRC_GRASS_ASH, "grass_ash", GRASS_ASH_PNG, GRASS_ASH_JSON, ash_map, used_keys)
	for i: int in GRASS_VARIANTS.size():
		ok = ok and _add_variant_source(ts, SRC_GRASS_VARIANTS + i, "grass_var/%d" % (i + 1), GRASS_VARIANTS[i],
			Terrain.GRASS)
	for i: int in SOIL_VARIANTS.size():
		ok = ok and _add_variant_source(ts, SRC_SOIL_VARIANTS + i, "soil_var/%d" % (i + 1), SOIL_VARIANTS[i],
			Terrain.SOIL)
	for i: int in ASH_VARIANTS.size():
		ok = ok and _add_variant_source(ts, SRC_ASH_VARIANTS + i, "ash_var/%d" % (i + 1), ASH_VARIANTS[i],
			Terrain.ASH)
	return ts if ok else null


## Number of tiles over all atlas sources.
static func count_tiles(ts: TileSet) -> int:
	var n: int = 0
	for i: int in ts.get_source_count():
		var source: TileSetAtlasSource = ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
		if source != null:
			n += source.get_tiles_count()
	return n


static func _new_atlas(ts: TileSet, source_id: int, texture: Texture2D, unique_id: String) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(Config.TILE, Config.TILE)
	source.resource_name = unique_id
	# A fixed sub-resource id keeps the saved .tres identical between builds.
	source.resource_scene_unique_id = unique_id
	ts.add_source(source, source_id)
	return source


static func _load_texture(file: String) -> Texture2D:
	var texture: Texture2D = load(ART_DIR + file) as Texture2D
	if texture == null:
		push_error("TilesetBuilder: cannot load %s%s (run --import first)" % [ART_DIR, file])
	return texture


static func _add_wang_source(ts: TileSet, source_id: int, name: String, png: String, json: String,
		terrain_map: Dictionary[String, int], used_keys: Dictionary[int, bool]) -> bool:
	var texture: Texture2D = _load_texture(png)
	if texture == null:
		return false
	var tiles: Array[WangTileInfo] = read_pixellab(ART_DIR + json, terrain_map)
	if tiles.is_empty():
		return false
	var source: TileSetAtlasSource = _new_atlas(ts, source_id, texture, "wang_" + name)
	for info: WangTileInfo in tiles:
		var key: int = Terrain.key_of_corners(info.corners)
		if used_keys.has(key):
			continue  # an earlier Wang set already draws these corners (the all-grass tile)
		used_keys[key] = true
		var coords: Vector2i = info.rect.position / Config.TILE
		source.create_tile(coords)
		var td: TileData = source.get_tile_data(coords, 0)
		td.set_custom_data(DATA_CORNERS, info.corners)
		td.set_custom_data(DATA_NAME, "%s/%s" % [name, info.name])
	return true


static func _add_variant_source(ts: TileSet, source_id: int, name: String, png: String, terrain: int) -> bool:
	var texture: Texture2D = _load_texture(png)
	if texture == null:
		return false
	var source: TileSetAtlasSource = _new_atlas(ts, source_id, texture, "variant_" + name.replace("/", "_"))
	source.create_tile(Vector2i.ZERO)
	var td: TileData = source.get_tile_data(Vector2i.ZERO, 0)
	td.set_custom_data(DATA_CORNERS, PackedByteArray([terrain, terrain, terrain, terrain]))
	td.set_custom_data(DATA_NAME, name)
	td.probability = Config.VARIANT_WEIGHT
	return true


static func _int_of(value: Variant) -> int:
	if value is int:
		var i: int = value
		return i
	if value is float:
		var f: float = value
		return roundi(f)
	return -1
