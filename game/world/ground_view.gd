class_name GroundView
extends Node2D
## Draws the floor terrain of a WorldData with the dual grid, split into chunk TileMapLayers.
##
## Display cell (dx, dy) covers world pixels [dx*16+8, dx*16+24) x [dy*16+8, dy*16+24): it is
## shifted by half a tile so its four corners are the vertices (= world cell centres) (dx, dy),
## (dx+1, dy), (dx, dy+1), (dx+1, dy+1). A W x H world has (W+1) x (H+1) display cells, -1..W-1
## and -1..H-1.
##
## Chunk (cx, cy) is one TileMapLayer holding display cells [cx*C, cx*C+C) x [cy*C, cy*C+C)
## (C = Config.GROUND_CHUNK) in local coordinates 0..C-1, positioned at (cx*C*16+8, cy*C*16+8).
## A TileMapLayer's cost per edit grows with its size, so many small layers keep edits cheap
## (spike RESULTS §3). set_terrain() redraws only the 4 display cells around the vertex.

const SURFACE_TILESET: String = TilesetBuilder.SURFACE_PATH

## Counters for tests and benchmarks.
var cells_written: int = 0
var last_redrawn: Array[Vector2i] = []

var data: WorldData
var table: WangTable
var _chunks: Dictionary[Vector2i, TileMapLayer] = {}

static var _surface_table: WangTable


## Loads the committed surface TileSet once and builds its lookup table.
static func surface_table() -> WangTable:
	if _surface_table == null:
		var ts: TileSet = load(SURFACE_TILESET) as TileSet
		if ts == null:
			push_error("GroundView: cannot load %s" % SURFACE_TILESET)
			return null
		_surface_table = WangTable.from_tile_set(ts)
	return _surface_table


static func chunk_of(d: Vector2i) -> Vector2i:
	return Vector2i(floori(float(d.x) / Config.GROUND_CHUNK), floori(float(d.y) / Config.GROUND_CHUNK))


## Display cells of a W x H world: Rect2i(-1, -1, W + 1, H + 1).
static func display_rect_for(world_size: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(-1, -1), world_size + Vector2i.ONE)


## World pixel position of the centre of display cell d.
static func display_center_px(d: Vector2i) -> Vector2:
	return Vector2(d * Config.TILE) + Vector2(Config.TILE, Config.TILE)


## Replaces what is drawn with `p_data` (all chunks are rebuilt).
func setup(p_data: WorldData, p_table: WangTable = null) -> void:
	data = p_data
	table = p_table if p_table != null else surface_table()
	for layer: TileMapLayer in _chunks.values():
		remove_child(layer)
		layer.queue_free()
	_chunks.clear()
	cells_written = 0
	last_redrawn.clear()
	var r: Rect2i = display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			_draw_cell(Vector2i(dx, dy))


func display_rect() -> Rect2i:
	return display_rect_for(data.size)


func chunk_count() -> int:
	return _chunks.size()


func chunk_keys() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	keys.assign(_chunks.keys())
	keys.sort()
	return keys


func chunk_layer(chunk: Vector2i) -> TileMapLayer:
	return _chunks.get(chunk, null)


## Sets the floor terrain at vertex v and redraws the 4 display cells that have v as a corner.
## Returns the redrawn display cells (empty if the edit was refused or changed nothing).
func set_terrain(v: Vector2i, terrain: int) -> Array[Vector2i]:
	last_redrawn.clear()
	if not data.set_terrain(v, terrain):
		return last_redrawn.duplicate()
	return redraw_vertex(v)


## Redraws the 4 display cells around vertex v (after a direct WorldData change).
func redraw_vertex(v: Vector2i) -> Array[Vector2i]:
	last_redrawn.clear()
	var r: Rect2i = display_rect()
	for d: Vector2i in [v + Vector2i(-1, -1), v + Vector2i(0, -1), v + Vector2i(-1, 0), v]:
		if r.has_point(d):
			_draw_cell(d)
			last_redrawn.append(d)
	return last_redrawn.duplicate()


## Source id and atlas coords drawn at display cell d: Vector3i(source, x, y); source -1 = empty.
func drawn_at(d: Vector2i) -> Vector3i:
	var layer: TileMapLayer = _chunks.get(chunk_of(d), null)
	if layer == null:
		return Vector3i(-1, -1, -1)
	var local: Vector2i = d - chunk_of(d) * Config.GROUND_CHUNK
	var atlas: Vector2i = layer.get_cell_atlas_coords(local)
	return Vector3i(layer.get_cell_source_id(local), atlas.x, atlas.y)


## Corners [NW, NE, SW, SE] of the tile drawn at display cell d (empty if nothing is drawn).
func drawn_corners(d: Vector2i) -> PackedByteArray:
	var layer: TileMapLayer = _chunks.get(chunk_of(d), null)
	if layer == null:
		return PackedByteArray()
	var td: TileData = layer.get_cell_tile_data(d - chunk_of(d) * Config.GROUND_CHUNK)
	if td == null:
		return PackedByteArray()
	return td.get_custom_data(TilesetBuilder.DATA_CORNERS)


## Checks every display cell against the data: the drawn tile's corners must equal the cell's
## vertices, except where the key has no art (counted as fallbacks).
func verify() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {"cells": 0, "mismatches": 0, "fallbacks": 0, "missing": 0}
	var r: Rect2i = display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			var d: Vector2i = Vector2i(dx, dy)
			result["cells"] += 1
			var drawn: PackedByteArray = drawn_corners(d)
			if drawn.is_empty():
				result["missing"] += 1
				continue
			var key: int = data.key_at_display(d)
			if not table.entries[key].exact:
				result["fallbacks"] += 1
			elif Terrain.key_of_corners(drawn) != key:
				result["mismatches"] += 1
	return result


## md5 over every drawn display cell (source, atlas). Equal = same picture.
func view_hash() -> String:
	var cells: PackedInt32Array = PackedInt32Array()
	var r: Rect2i = display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			var t: Vector3i = drawn_at(Vector2i(dx, dy))
			cells.append(t.x)
			cells.append(t.y)
			cells.append(t.z)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(cells.to_byte_array())
	return ctx.finish().hex_encode()


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
	return layer


func _draw_cell(d: Vector2i) -> void:
	if not display_rect().has_point(d):
		return
	var key: int = data.key_at_display(d)
	var e: WangTable.KeyEntry = table.entries[key]
	var i: int = table.pick(key, d)
	var chunk: Vector2i = chunk_of(d)
	_layer_for(chunk).set_cell(d - chunk * Config.GROUND_CHUNK, e.sources[i], e.coords[i], 0)
	cells_written += 1
