class_name CaveView
extends Node2D
## Draws a dungeon's walls (M3a) with the dual grid, like GroundView draws the surface floor: display
## cell (dx, dy) covers world px [dx*16+8, dx*16+24) x [dy*16+8, dy*16+24) and its corners are the
## vertices (= world tiles) (dx, dy) .. (dx+1, dy+1). A vertex's value is Walls.vertex(): wall, face
## (the floor tile under a wall, where its 24 px front face hangs) or floor. The tiles are the 04-env
## cliff set (TilesetBuilder.build_dungeon, CaveTable picks by corners + context). Chunks of
## Config.GROUND_CHUNK display cells, one TileMapLayer each.
##
## Over the tiles (still under the y-sorted entities):
##   Ores    the ore pixels of 04-env tiles_ore_<kind>_<a|b>_v02 (their difference from the plain wall
##           top they were painted on), on the wall tile (rows above the face only on a faced wall)
##   Cracks  a partly mined wall shows stage 1-3 (Walls.crack_stage) of 04-env wall_crack_top_v01 on its
##           top and, when its face shows, wall_crack_face_v01 on the face (offsets of the 04-env
##           dungeon mockup: face from FACE_TOP_PX below the wall's centre row, top crack just above it)

const ORE_TILES: Dictionary[int, Array] = {
	Walls.ORE_COPPER: ["res://art/tiles/tiles_ore_copper_a_v02.png", "res://art/tiles/tiles_ore_copper_b_v02.png"],
	Walls.ORE_IRON: ["res://art/tiles/tiles_ore_iron_a_v02.png", "res://art/tiles/tiles_ore_iron_b_v02.png"],
}
const CRACK_TOP: Texture2D = preload("res://art/tiles/wall_crack_top_v01.png")
const CRACK_FACE: Texture2D = preload("res://art/tiles/wall_crack_face_v01.png")
## The plain wall top the ore tiles were painted on (tiles_dungeon_v02.png, t1_5 at (0, 96)).
const PLAIN_TOP_AT: Vector2i = Vector2i(0, 96)

var data: WorldData
var table: CaveTable
var cells_written: int = 0
## Ore overlay and crack sprites by wall tile.
var ores: Dictionary[Vector2i, Sprite2D] = {}
var cracks: Dictionary[Vector2i, Array] = {}
var overlays: Node2D
var _chunks: Dictionary[Vector2i, TileMapLayer] = {}

static var _table: CaveTable
static var _ore_textures: Dictionary[String, Texture2D] = {}
static var _crack_textures: Dictionary[String, AtlasTexture] = {}


static func cave_table() -> CaveTable:
	if _table == null:
		var ts: TileSet = load(TilesetBuilder.DUNGEON_PATH) as TileSet
		if ts == null:
			push_error("CaveView: cannot load %s" % TilesetBuilder.DUNGEON_PATH)
			return null
		_table = CaveTable.from_tile_set(ts)
	return _table


func _init() -> void:
	overlays = Node2D.new()
	overlays.name = &"Overlays"
	add_child(overlays)


func setup(p_data: WorldData, p_table: CaveTable = null) -> void:
	data = p_data
	table = p_table if p_table != null else cave_table()
	for layer: TileMapLayer in _chunks.values():
		remove_child(layer)
		layer.queue_free()
	_chunks.clear()
	for c: Vector2i in ores.keys():
		_free(ores[c])
	ores.clear()
	for c: Vector2i in cracks.keys():
		for item: Variant in cracks[c]:
			var sprite: Sprite2D = item
			_free(sprite)
	cracks.clear()
	cells_written = 0
	var r: Rect2i = display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			_draw_cell(Vector2i(dx, dy))
	for c: Vector2i in Walls.wall_cells(data):
		_update_overlays(c)


func display_rect() -> Rect2i:
	return GroundView.display_rect_for(data.size)


## Corner key of display cell d.
func key_at(d: Vector2i) -> int:
	return CaveTable.key_of(Walls.vertex(data, d), Walls.vertex(data, d + Vector2i(1, 0)),
		Walls.vertex(data, d + Vector2i(0, 1)), Walls.vertex(data, d + Vector2i(1, 1)))


## [above NW, above NE, below SW, below SE] of display cell d.
func context_at(d: Vector2i) -> PackedByteArray:
	return PackedByteArray([Walls.vertex(data, d + Vector2i(0, -1)), Walls.vertex(data, d + Vector2i(1, -1)),
		Walls.vertex(data, d + Vector2i(0, 2)), Walls.vertex(data, d + Vector2i(1, 2))])


## Redraws what wall tile `c` changing can touch: the display cells whose corners or context include
## c or the tile below it, and the overlays of c and the tiles above and below it.
func redraw_wall(c: Vector2i) -> void:
	var r: Rect2i = display_rect()
	for dy: int in range(c.y - 2, c.y + 3):
		for dx: int in range(c.x - 1, c.x + 1):
			if r.has_point(Vector2i(dx, dy)):
				_draw_cell(Vector2i(dx, dy))
	for oy: int in range(-1, 2):
		_update_overlays(c + Vector2i(0, oy))


func chunk_layer(chunk: Vector2i) -> TileMapLayer:
	return _chunks.get(chunk, null)


func chunk_count() -> int:
	return _chunks.size()


## Vector3i(source, atlas x, atlas y) drawn at display cell d (source -1 = nothing).
func drawn_at(d: Vector2i) -> Vector3i:
	var layer: TileMapLayer = _chunks.get(GroundView.chunk_of(d), null)
	if layer == null:
		return Vector3i(-1, -1, -1)
	var local: Vector2i = d - GroundView.chunk_of(d) * Config.GROUND_CHUNK
	var atlas: Vector2i = layer.get_cell_atlas_coords(local)
	return Vector3i(layer.get_cell_source_id(local), atlas.x, atlas.y)


func drawn_corners(d: Vector2i) -> PackedByteArray:
	var layer: TileMapLayer = _chunks.get(GroundView.chunk_of(d), null)
	if layer == null:
		return PackedByteArray()
	var td: TileData = layer.get_cell_tile_data(d - GroundView.chunk_of(d) * Config.GROUND_CHUNK)
	if td == null:
		return PackedByteArray()
	return td.get_custom_data(TilesetBuilder.DATA_CORNERS)


## Every display cell against the data: the drawn tile's corners must be the cell's key (keys the set
## lacks are counted as fallbacks), every cell drawn; ore and crack sprites must match the data.
func verify() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {"cells": 0, "mismatches": 0, "fallbacks": 0, "missing": 0, "overlay_mismatches": 0}
	var r: Rect2i = display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			var d: Vector2i = Vector2i(dx, dy)
			result["cells"] += 1
			var drawn: PackedByteArray = drawn_corners(d)
			if drawn.is_empty():
				result["missing"] += 1
				continue
			var key: int = key_at(d)
			if not table.is_exact(key):
				result["fallbacks"] += 1
			elif CaveTable.key_of(drawn[0], drawn[1], drawn[2], drawn[3]) != key:
				result["mismatches"] += 1
	var bad: int = 0
	var ore_cells: Array[Vector2i] = Walls.ore_cells(data)
	for c: Vector2i in ore_cells:
		var s: Sprite2D = ores.get(c, null)
		if s == null or s.texture != ore_texture(Walls.ore_at(data, c), c) or s.position != Vector2(c * Config.TILE):
			bad += 1
	bad += maxi(ores.size() - ore_cells.size(), 0)
	var cracked: int = 0
	for c: Vector2i in Walls.wall_cells(data):
		var stage: int = Walls.crack_stage(Walls.hits_at(data, c), Walls.max_hits(data, c))
		if stage == 0:
			continue
		cracked += 1
		var want: int = 2 if Walls.is_face(data, c + Vector2i(0, 1)) else 1
		var have: Array = cracks.get(c, [])
		if have.size() != want:
			bad += 1
			continue
		var top: Sprite2D = have[0]
		if top.texture != crack_texture(false, stage) or top.position != crack_position(c, false, want == 2):
			bad += 1
		if want == 2:
			var face: Sprite2D = have[1]
			if face.texture != crack_texture(true, stage) or face.position != crack_position(c, true, true):
				bad += 1
	bad += maxi(cracks.size() - cracked, 0)
	result["overlay_mismatches"] = bad
	return result


## md5 over every drawn display cell and overlay. Equal = same picture.
func view_hash() -> String:
	var cells: PackedInt32Array = PackedInt32Array()
	var r: Rect2i = display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			var t: Vector3i = drawn_at(Vector2i(dx, dy))
			cells.append(t.x)
			cells.append(t.y)
			cells.append(t.z)
	for c: Vector2i in Walls.wall_cells(data):
		cells.append(Walls.ore_at(data, c))
		cells.append(Walls.crack_stage(Walls.hits_at(data, c), Walls.max_hits(data, c)))
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(cells.to_byte_array())
	return ctx.finish().hex_encode()


## Where a crack sprite of wall tile `c` goes (top-left, world px): the face crack from where the face
## starts (FACE_TOP_PX below the tile's centre row); the top crack on the tile, or, on a faced wall,
## just above where its face starts.
static func crack_position(c: Vector2i, face: bool, faced: bool) -> Vector2:
	var face_y: int = c.y * Config.TILE + Config.TILE / 2 + Config.FACE_TOP_PX
	if face:
		return Vector2(c.x * Config.TILE, face_y)
	return Vector2(c.x * Config.TILE, face_y - Config.TILE if faced else c.y * Config.TILE)


## Crack art for a stage (1..3): top (16x16) or face (16x24).
static func crack_texture(face: bool, stage: int) -> AtlasTexture:
	var key: String = "%s%d" % ["face" if face else "top", stage]
	if not _crack_textures.has(key):
		var a: AtlasTexture = AtlasTexture.new()
		a.atlas = CRACK_FACE if face else CRACK_TOP
		var h: int = Config.FACE_HEIGHT_PX if face else Config.TILE
		a.region = Rect2((stage - 1) * Config.TILE, 0, Config.TILE, h)
		_crack_textures[key] = a
	return _crack_textures[key]


## The ore pixels for ore `ore` on tile `c` (variant a or b by a stable tile hash).
static func ore_texture(ore: int, c: Vector2i) -> Texture2D:
	if not ORE_TILES.has(ore):
		return null
	var files: Array = ORE_TILES[ore]
	var path: String = files[0] if WangTable.hash01(c.x, c.y) < 0.5 else files[1]
	if not _ore_textures.has(path):
		_ore_textures[path] = ImageTexture.create_from_image(ore_image(path))
	return _ore_textures[path]


## An ore tile's pixels that differ from the plain wall top (the rest transparent).
static func ore_image(path: String) -> Image:
	var ore: Image = (load(path) as Texture2D).get_image()
	ore.convert(Image.FORMAT_RGBA8)
	var sheet: Image = (load(TilesetBuilder.ART_DIR + TilesetBuilder.DUNGEON_PNG) as Texture2D).get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	var out: Image = Image.create_empty(Config.TILE, Config.TILE, false, Image.FORMAT_RGBA8)
	for y: int in Config.TILE:
		for x: int in Config.TILE:
			var p: Color = ore.get_pixel(x, y)
			if p != sheet.get_pixel(PLAIN_TOP_AT.x + x, PLAIN_TOP_AT.y + y):
				out.set_pixel(x, y, p)
	return out


func _layer_for(chunk: Vector2i) -> TileMapLayer:
	var layer: TileMapLayer = _chunks.get(chunk, null)
	if layer != null:
		return layer
	layer = TileMapLayer.new()
	layer.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	layer.tile_set = table.tile_set
	layer.rendering_quadrant_size = Config.GROUND_QUADRANT
	layer.position = Vector2(chunk * Config.GROUND_CHUNK * Config.TILE) + Vector2(Config.TILE, Config.TILE) / 2.0
	_chunks[chunk] = layer
	add_child(layer)
	move_child(overlays, get_child_count() - 1)
	return layer


func _draw_cell(d: Vector2i) -> void:
	var c: CaveTable.Candidate = table.pick(key_at(d), context_at(d), d)
	if c == null:
		return
	var chunk: Vector2i = GroundView.chunk_of(d)
	_layer_for(chunk).set_cell(d - chunk * Config.GROUND_CHUNK, c.source, c.coords, 0)
	cells_written += 1


func _update_overlays(c: Vector2i) -> void:
	if ores.has(c):
		_free(ores[c])
		ores.erase(c)
	if cracks.has(c):
		for item: Variant in cracks[c]:
			var sprite: Sprite2D = item
			_free(sprite)
		cracks.erase(c)
	if not data.in_bounds(c) or not Walls.is_natural(data, c):
		return  # M7b: a built piece has no ore and no cracks (the build view draws it)
	var faced: bool = Walls.is_face(data, c + Vector2i(0, 1))
	var ore: int = Walls.ore_at(data, c)
	if ore != Walls.ORE_NONE:
		var s: Sprite2D = _sprite(ore_texture(ore, c), Vector2(c * Config.TILE), "Ore_%d_%d" % [c.x, c.y])
		if faced:
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, Config.TILE, Config.TILE / 2 + Config.FACE_TOP_PX)
		ores[c] = s
	var stage: int = Walls.crack_stage(Walls.hits_at(data, c), Walls.max_hits(data, c))
	if stage > 0:
		var list: Array[Sprite2D] = [_sprite(crack_texture(false, stage), crack_position(c, false, faced),
			"CrackTop_%d_%d" % [c.x, c.y])]
		if faced:
			list.append(_sprite(crack_texture(true, stage), crack_position(c, true, true), "CrackFace_%d_%d" % [c.x, c.y]))
		cracks[c] = list


func _sprite(tex: Texture2D, pos: Vector2, node_name: String) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.centered = false
	s.position = pos
	overlays.add_child(s)
	return s


func _free(s: Sprite2D) -> void:
	if is_instance_valid(s):
		s.get_parent().remove_child(s)
		s.free()
