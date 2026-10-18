extends SceneTree
## Builds the module's TileSet resources from our PixelLab PNGs and their JSON corner data.
##
##   godot --headless --path prototypes/engine-spike --import
##   godot --headless --path prototypes/engine-spike --script res://tiles/build_tilesets.gd
##
## Writes res://tiles/tilesets/surface.tres and res://tiles/tilesets/dungeon.tres and prints one
## "TILES_BUILD <name> ..." line per file. Exit code 0 = both saved. The output only depends on the
## inputs (PNG + JSON in res://art/tiles/), so running it again gives the same files.
##
## One TileSet serves both placement methods:
##   (a) Godot terrains: terrain set 0 in Match Corners mode, corner peering bits from the JSON.
##       Godot also needs a center terrain per tile. A corner tile has none, so the base tile gets the
##       majority corner terrain and an alternative tile is added for every other terrain on its
##       corners (center = that terrain), which gives the solver every legal choice.
##       When several tiles have the same corners (dungeon set), only the one with the fewest
##       context constraints gets terrain bits, otherwise Godot would pick between them at random.
##   (b) dual grid: custom data "wang_corners" / "wang_pattern" (see wang.gd), read by wang_lookup.gd.
## Inner-tile variants are extra sources with the same corners and probability VARIANT_PROBABILITY.

const Wang := preload("res://tiles/wang.gd")

const ART: String = "res://art/tiles/"
const OUT_DIR: String = "res://tiles/tilesets/"
const SURFACE_PATH: String = "res://tiles/tilesets/surface.tres"
const DUNGEON_PATH: String = "res://tiles/tilesets/dungeon.tres"

const VARIANT_PROBABILITY: float = 0.25

# Surface source ids
const SRC_GRASS_SOIL: int = 0
const SRC_GRASS_ASH: int = 1
const SRC_GRASS_VARIANTS: int = 10
const SRC_SOIL_VARIANTS: int = 20
const SRC_ASH_VARIANTS: int = 30

# Dungeon source ids
const SRC_DUNGEON: int = 0
const SRC_DUNGEON_VARIANTS: int = 1
const SRC_OVERLAY: int = 2
const OVERLAY_COPPER: Vector2i = Vector2i(0, 0)
const OVERLAY_IRON: Vector2i = Vector2i(1, 0)
const OVERLAY_SOLID: Vector2i = Vector2i(2, 0)

const SURFACE_TERRAINS: PackedStringArray = ["grass", "soil", "ash"]
const SURFACE_COLORS: Array[Color] = [Color(0.45, 0.7, 0.3), Color(0.45, 0.28, 0.15), Color(0.5, 0.48, 0.45)]
const DUNGEON_TERRAINS: PackedStringArray = ["floor", "face", "wall"]
const DUNGEON_COLORS: Array[Color] = [Color(0.55, 0.5, 0.45), Color(0.3, 0.27, 0.25), Color(0.15, 0.14, 0.13)]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var failed: int = 0
	for item: Array in [["surface", SURFACE_PATH], ["dungeon", DUNGEON_PATH]]:
		var name: String = item[0]
		var path: String = item[1]
		var t0: int = Time.get_ticks_usec()
		var tile_set: TileSet = build_surface() if name == "surface" else build_dungeon()
		var err: Error = ResourceSaver.save(tile_set, path) if tile_set != null else ERR_CANT_CREATE
		var stats: Dictionary = describe(tile_set) if tile_set != null else {}
		print("TILES_BUILD %s %s error=%d sources=%d tiles=%d alternatives=%d terrain_tiles=%d ms=%.1f" % [
			name, path, err, stats.get("sources", 0), stats.get("tiles", 0), stats.get("alternatives", 0),
			stats.get("terrain_tiles", 0), (Time.get_ticks_usec() - t0) / 1000.0])
		if err != OK:
			failed += 1
	quit(1 if failed > 0 else 0)


static func build_surface() -> TileSet:
	var ts: TileSet = _new_tileset(SURFACE_TERRAINS, SURFACE_COLORS)
	var ok: bool = true
	ok = ok and _add_wang_source(ts, SRC_GRASS_SOIL, "grass_soil", ART + "tiles_grass-soil_v03.png",
		ART + "tiles_grass-soil_v01.json", {"lower": Wang.SOIL, "upper": Wang.GRASS})
	ok = ok and _add_wang_source(ts, SRC_GRASS_ASH, "grass_ash", ART + "tiles_grass-corruption_v05.png",
		ART + "tiles_grass-corruption_v02.json", {"lower": Wang.ASH, "upper": Wang.GRASS})
	for i: int in 4:
		ok = ok and _add_variant_source(ts, SRC_GRASS_VARIANTS + i, "grass_var_%d" % (i + 1),
			ART + "tiles_grass_var_%d_v02.png" % (i + 1), [Wang.GRASS])
	for i: int in 2:
		ok = ok and _add_variant_source(ts, SRC_SOIL_VARIANTS + i, "soil_var_%d" % (i + 1),
			ART + "tiles_soil_var_%d_v01.png" % (i + 1), [Wang.SOIL])
	for i: int in 3:
		ok = ok and _add_variant_source(ts, SRC_ASH_VARIANTS + i, "ash_plain_%d" % (i + 1),
			ART + "tiles_ash_plain_%d_v01.png" % (i + 1), [Wang.ASH])
	return ts if ok else null


static func build_dungeon() -> TileSet:
	var ts: TileSet = _new_tileset(DUNGEON_TERRAINS, DUNGEON_COLORS)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var ok: bool = _add_wang_source(ts, SRC_DUNGEON, "dungeon", ART + "tiles_dungeon_v02.png",
		ART + "tiles_dungeon_v01.json", {"lower": Wang.FLOOR, "transition": Wang.FACE, "upper": Wang.WALL})
	# tiles_dungeon_v02_var.png: three floor variants, then two wall-top variants.
	ok = ok and _add_variant_source(ts, SRC_DUNGEON_VARIANTS, "dungeon_var", ART + "tiles_dungeon_v02_var.png",
		[Wang.FLOOR, Wang.FLOOR, Wang.FLOOR, Wang.WALL, Wang.WALL])
	ok = ok and _add_overlay_source(ts)
	return ts if ok else null


## Source/tile/alternative counts, used by the build line and the tests.
static func describe(ts: TileSet) -> Dictionary:
	var tiles: int = 0
	var alternatives: int = 0
	var terrain_tiles: int = 0
	for i: int in ts.get_source_count():
		var source: TileSetAtlasSource = ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
		if source == null:
			continue
		for t: int in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(t)
			tiles += 1
			for a: int in source.get_alternative_tiles_count(coords):
				var alt: int = source.get_alternative_tile_id(coords, a)
				if alt != 0:
					alternatives += 1
				if source.get_tile_data(coords, alt).terrain_set == 0:
					terrain_tiles += 1
	return {"sources": ts.get_source_count(), "tiles": tiles, "alternatives": alternatives,
		"terrain_tiles": terrain_tiles}


static func _new_tileset(terrains: PackedStringArray, colors: Array[Color]) -> TileSet:
	var ts: TileSet = TileSet.new()
	ts.tile_size = Vector2i(Wang.TILE, Wang.TILE)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for i: int in terrains.size():
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, terrains[i])
		ts.set_terrain_color(0, i, colors[i])
	var layers: Array[Array] = [
		[Wang.DATA_CORNERS, TYPE_PACKED_BYTE_ARRAY],
		[Wang.DATA_PATTERN, TYPE_PACKED_BYTE_ARRAY],
		[Wang.DATA_NAME, TYPE_STRING],
		[Wang.DATA_ROLE, TYPE_STRING],
	]
	for i: int in layers.size():
		ts.add_custom_data_layer()
		ts.set_custom_data_layer_name(i, layers[i][0])
		ts.set_custom_data_layer_type(i, layers[i][1])
	return ts


static func _new_atlas(ts: TileSet, source_id: int, texture: Texture2D, unique_id: String) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(Wang.TILE, Wang.TILE)
	source.resource_name = unique_id
	# Fixed sub-resource ids keep the saved .tres identical between runs.
	source.resource_scene_unique_id = unique_id
	ts.add_source(source, source_id)
	return source


static func _add_wang_source(ts: TileSet, source_id: int, name: String, png: String, json: String,
		terrain_map: Dictionary) -> bool:
	var texture: Texture2D = load(png) as Texture2D
	if texture == null:
		push_error("build_tilesets: cannot load %s (run --import first)" % png)
		return false
	var tiles: Array[Dictionary] = Wang.read_pixellab(json, terrain_map)
	if tiles.is_empty():
		return false
	# Several tiles with the same corners: the one with the fewest context constraints is the
	# general tile and the only one Godot terrains may use (first in JSON order wins a tie).
	var general_for_key: Dictionary = {}
	for tile: Dictionary in tiles:
		var key: int = Wang.key_of_corners(tile["corners"])
		if not general_for_key.has(key) or int(tile["constraints"]) < int((general_for_key[key] as Dictionary)["constraints"]):
			general_for_key[key] = tile
	var source: TileSetAtlasSource = _new_atlas(ts, source_id, texture, "wang_" + name)
	for tile: Dictionary in tiles:
		var rect: Rect2i = tile["rect"]
		var coords: Vector2i = rect.position / Wang.TILE
		source.create_tile(coords)
		var corners: PackedByteArray = tile["corners"]
		var is_general: bool = general_for_key[Wang.key_of_corners(corners)] == tile
		var centers: Array[int] = _center_terrains(corners)
		for i: int in centers.size():
			var alt: int = 0 if i == 0 else source.create_alternative_tile(coords)
			var td: TileData = source.get_tile_data(coords, alt)
			_set_wang_data(td, corners, tile["pattern"], "%s/%s" % [name, tile["name"]], "wang")
			if is_general:
				_set_terrain(td, corners, centers[i])
	return true


static func _add_variant_source(ts: TileSet, source_id: int, name: String, png: String,
		terrains: Array[int]) -> bool:
	var texture: Texture2D = load(png) as Texture2D
	if texture == null:
		push_error("build_tilesets: cannot load %s (run --import first)" % png)
		return false
	var source: TileSetAtlasSource = _new_atlas(ts, source_id, texture, "variant_" + name)
	for i: int in terrains.size():
		var coords: Vector2i = Vector2i(i, 0)
		source.create_tile(coords)
		var terrain: int = terrains[i]
		var corners: PackedByteArray = PackedByteArray([terrain, terrain, terrain, terrain])
		var pattern: PackedByteArray = _inner_pattern(corners)
		var td: TileData = source.get_tile_data(coords, 0)
		_set_wang_data(td, corners, pattern, "%s/%d" % [name, i], "variant")
		_set_terrain(td, corners, terrain)
		td.probability = VARIANT_PROBABILITY
	return true


## Ore overlays (ore pixels of tiles_ore_*_v02.png that differ from the plain wall-top tile, the
## rest transparent) and a "solid" tile with a full-square collision polygon for the wall
## collision layer. The 48x16 image is generated here and embedded (lossless) in the .tres.
static func _add_overlay_source(ts: TileSet) -> bool:
	var dungeon: Texture2D = load(ART + "tiles_dungeon_v02.png") as Texture2D
	if dungeon == null:
		return false
	var wall_rect: Rect2i = Rect2i()
	for tile: Dictionary in Wang.read_pixellab(ART + "tiles_dungeon_v01.json",
			{"lower": Wang.FLOOR, "transition": Wang.FACE, "upper": Wang.WALL}):
		if Wang.key_of_corners(tile["corners"]) == Wang.key_of(Wang.WALL, Wang.WALL, Wang.WALL, Wang.WALL):
			wall_rect = tile["rect"]
	var wall_top: Image = dungeon.get_image().get_region(wall_rect)
	wall_top.convert(Image.FORMAT_RGBA8)
	var image: Image = Image.create_empty(Wang.TILE * 3, Wang.TILE, false, Image.FORMAT_RGBA8)
	var ores: PackedStringArray = ["tiles_ore_copper_a_v02.png", "tiles_ore_iron_a_v02.png"]
	for i: int in ores.size():
		var ore_texture: Texture2D = load(ART + ores[i]) as Texture2D
		if ore_texture == null:
			push_error("build_tilesets: cannot load %s" % ores[i])
			return false
		var ore: Image = ore_texture.get_image()
		ore.convert(Image.FORMAT_RGBA8)
		for y: int in Wang.TILE:
			for x: int in Wang.TILE:
				var c: Color = ore.get_pixel(x, y)
				if not c.is_equal_approx(wall_top.get_pixel(x, y)):
					image.set_pixel(i * Wang.TILE + x, y, c)
	# The solid tile is normally hidden (collision layer); when shown it is a faint red square.
	for y: int in Wang.TILE:
		for x: int in Wang.TILE:
			var edge: bool = x == 0 or y == 0 or x == Wang.TILE - 1 or y == Wang.TILE - 1
			image.set_pixel(2 * Wang.TILE + x, y, Color(0.9, 0.2, 0.15, 0.6 if edge else 0.25))
	var texture: PortableCompressedTexture2D = PortableCompressedTexture2D.new()
	texture.keep_compressed_buffer = true  # otherwise the data is dropped outside the editor and not saved
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	texture.resource_name = "overlay"
	texture.resource_scene_unique_id = "overlay_texture"
	var source: TileSetAtlasSource = _new_atlas(ts, SRC_OVERLAY, texture, "overlay")
	var names: Array[String] = ["ore_copper", "ore_iron", "solid"]
	for i: int in names.size():
		var coords: Vector2i = Vector2i(i, 0)
		source.create_tile(coords)
		var td: TileData = source.get_tile_data(coords, 0)
		td.set_custom_data(Wang.DATA_NAME, names[i])
		td.set_custom_data(Wang.DATA_ROLE, "solid" if names[i] == "solid" else "ore")
	var solid: TileData = source.get_tile_data(OVERLAY_SOLID, 0)
	var h: float = Wang.TILE / 2.0
	solid.add_collision_polygon(0)
	solid.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]))
	return true


## Majority corner terrain first (tie: higher terrain id, i.e. soil/ash over grass, wall over
## floor), then every other terrain that appears on a corner.
static func _center_terrains(corners: PackedByteArray) -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for c: int in corners:
		counts[c] += 1
	var order: Array[int] = []
	for t: int in Wang.TERRAIN_COUNT:
		if counts[t] > 0:
			order.append(t)
	order.sort_custom(func(a: int, b: int) -> bool:
		return counts[a] > counts[b] or (counts[a] == counts[b] and a > b))
	return order


static func _set_terrain(td: TileData, corners: PackedByteArray, center: int) -> void:
	td.terrain_set = 0
	td.terrain = center
	for i: int in 4:
		td.set_terrain_peering_bit(Wang.PEERING_BITS[i], corners[i])


static func _set_wang_data(td: TileData, corners: PackedByteArray, pattern: PackedByteArray, name: String,
		role: String) -> void:
	td.set_custom_data(Wang.DATA_CORNERS, corners)
	td.set_custom_data(Wang.DATA_PATTERN, pattern)
	td.set_custom_data(Wang.DATA_NAME, name)
	td.set_custom_data(Wang.DATA_ROLE, role)


static func _inner_pattern(corners: PackedByteArray) -> PackedByteArray:
	var pattern: PackedByteArray = []
	pattern.resize(16)
	pattern.fill(Wang.WILDCARD)
	pattern[5] = corners[0]
	pattern[6] = corners[1]
	pattern[9] = corners[2]
	pattern[10] = corners[3]
	return pattern
