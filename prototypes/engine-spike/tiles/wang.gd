extends RefCounted
## Wang (corner) tile helpers shared by the tileset builder, both placement methods and the tests.
##
## A Wang tile is described by the terrain at its four corners, in the order NW, NE, SW, SE.
## Terrain ids are small ints (0..2) local to one tileset:
##   surface: GRASS 0, SOIL 1, ASH 2
##   dungeon: FLOOR 0, FACE 1 (wall front face, PixelLab "transition"), WALL 2 (wall top)
## A corner key packs the four corners in base 3: NW + 3*NE + 9*SW + 27*SE (0..80).

const GRASS: int = 0
const SOIL: int = 1
const ASH: int = 2

const FLOOR: int = 0
const FACE: int = 1
const WALL: int = 2

const TERRAIN_COUNT: int = 3
const KEY_COUNT: int = 81
const WILDCARD: int = 255
const TILE: int = 16

const CORNER_NAMES: PackedStringArray = ["NW", "NE", "SW", "SE"]

## Godot corner peering bits, same order as CORNER_NAMES.
const PEERING_BITS: Array[int] = [
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
]

## Custom data layers written by the builder (read by the dual grid lookup and the tests).
const DATA_CORNERS: String = "wang_corners"   # PackedByteArray [NW, NE, SW, SE], empty = not a Wang tile
const DATA_PATTERN: String = "wang_pattern"   # PackedByteArray 16 (4x4 vertices, row-major), 255 = any
const DATA_NAME: String = "wang_name"         # String, e.g. "grass_soil/wang_13"
const DATA_ROLE: String = "role"              # String: wang, variant, ore, solid


static func key_of(nw: int, ne: int, sw: int, se: int) -> int:
	return nw + 3 * ne + 9 * sw + 27 * se


static func key_of_corners(corners: PackedByteArray) -> int:
	return key_of(corners[0], corners[1], corners[2], corners[3])


static func corners_of_key(key: int) -> PackedByteArray:
	return PackedByteArray([key % 3, (key / 3) % 3, (key / 9) % 3, (key / 27) % 3])


## Reads a PixelLab create_topdown_tileset JSON (tileset_data.tiles[].corners / bounding_box / pattern_4x4).
## terrain_map maps PixelLab terrain names ("lower", "upper", "transition") to our terrain ids.
## Returns [{name, corners: PackedByteArray(4), rect: Rect2i, pattern: PackedByteArray(16), constraints: int}]
## where pattern holds our terrain ids (WILDCARD = any) and constraints counts the non-wildcard
## vertices outside the 2x2 corner block (context the tile wants beyond its own corners).
static func read_pixellab(json_path: String, terrain_map: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var text: String = FileAccess.get_file_as_string(json_path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("wang: cannot parse %s" % json_path)
		return out
	var data: Dictionary = parsed
	var encoding: Dictionary = {"lower": 0, "upper": 1, "transition": 2, "wildcard": WILDCARD}
	var pattern_system: Dictionary = data.get("pattern_system", {})
	if pattern_system.has("terrain_encoding"):
		encoding = pattern_system["terrain_encoding"]
	# pattern code (0/1/2) -> our terrain id
	var code_to_terrain: Dictionary = {}
	for terrain_name: String in terrain_map:
		if encoding.has(terrain_name):
			code_to_terrain[int(encoding[terrain_name])] = int(terrain_map[terrain_name])
	var wildcard: int = int(encoding.get("wildcard", WILDCARD))

	var tiles: Array = (data["tileset_data"] as Dictionary)["tiles"]
	for raw: Variant in tiles:
		var tile: Dictionary = raw
		var corners_in: Dictionary = tile["corners"]
		var corners: PackedByteArray = []
		for corner_name: String in CORNER_NAMES:
			var terrain_name: String = corners_in[corner_name]
			if not terrain_map.has(terrain_name):
				push_error("wang: %s has unknown terrain %s" % [json_path, terrain_name])
				return []
			corners.append(int(terrain_map[terrain_name]))
		var bb: Dictionary = tile["bounding_box"]
		var rect: Rect2i = Rect2i(int(bb["x"]), int(bb["y"]), int(bb["width"]), int(bb["height"]))
		var pattern: PackedByteArray = []
		var constraints: int = 0
		var rows: Dictionary = tile.get("pattern_4x4", {})
		for row: int in 4:
			var values: Array = rows.get("row_%d" % row, [wildcard, wildcard, wildcard, wildcard])
			for col: int in 4:
				var code: int = int(values[col])
				var inner: bool = (row == 1 or row == 2) and (col == 1 or col == 2)
				if code == wildcard or not code_to_terrain.has(code):
					pattern.append(WILDCARD)
				else:
					pattern.append(int(code_to_terrain[code]))
					if not inner:
						constraints += 1
		out.append({
			"name": str(tile["name"]),
			"corners": corners,
			"rect": rect,
			"pattern": pattern,
			"constraints": constraints,
		})
	return out


## Corner terrains a dungeon vertex grid gets from a wall map: a floor vertex directly under a
## wall vertex becomes FACE (the wall's front face is drawn on the floor row below the wall top).
static func derive_dungeon(wall_above: bool, is_wall: bool) -> int:
	if is_wall:
		return WALL
	return FACE if wall_above else FLOOR
