extends RefCounted
## Fill + random single-cell edit benchmark for both placement methods (used by the tests and by
## res://tiles/bench_tiles.gd). Times include TileMapLayer.update_internals(), i.e. the work Godot
## would otherwise do at the end of the frame (in headless runs the renderer is a dummy, so the
## draw side of that work is not measured; bench_tiles.gd --render measures real frames).

const Wang := preload("res://tiles/wang.gd")
const WangLookup := preload("res://tiles/wang_lookup.gd")
const DualGrid := preload("res://tiles/dual_grid.gd")
const TerrainGrid := preload("res://tiles/terrain_grid.gd")
const Maps := preload("res://tiles/maps.gd")

const SURFACE_TILESET: String = "res://tiles/tilesets/surface.tres"
const DUNGEON_TILESET: String = "res://tiles/tilesets/dungeon.tres"
## Fallback cost between terrains (see WangLookup). Surface: soil and ash never share a tile.
const SURFACE_DISTANCE: Array = [[0, 1, 1], [1, 0, 2], [1, 2, 0]]
const DUNGEON_DISTANCE: Array = [[0, 1, 2], [1, 0, 1], [2, 1, 0]]


static func lookup_for(kind: String) -> WangLookup:
	var ts: TileSet = load(SURFACE_TILESET if kind == "surface" else DUNGEON_TILESET) as TileSet
	return WangLookup.new(ts, SURFACE_DISTANCE if kind == "surface" else DUNGEON_DISTANCE)


## Makes the layer + grid for `kind` ("surface" | "dungeon") and `method` ("a" Godot terrains |
## "b" dual grid) under `parent`. The dungeon dual grid leaves all-floor cells empty (a floor layer
## would show through), the other three draw every cell.
static func make_grid(kind: String, method: String, width: int, height: int, parent: Node) -> RefCounted:
	var ts: TileSet = load(SURFACE_TILESET if kind == "surface" else DUNGEON_TILESET) as TileSet
	var dungeon: bool = kind == "dungeon"
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = ts
	parent.add_child(layer)
	var outside: int = Wang.WALL if dungeon else Wang.GRASS
	if method == "b":
		var lookup: WangLookup = WangLookup.new(ts, DUNGEON_DISTANCE if dungeon else SURFACE_DISTANCE)
		var empty: int = Wang.key_of(Wang.FLOOR, Wang.FLOOR, Wang.FLOOR, Wang.FLOOR) if dungeon else -1
		return DualGrid.new(layer, lookup, width, height, outside, dungeon, empty)
	return TerrainGrid.new(layer, width, height, outside, dungeon)


static func noise_map(kind: String, size: int, seed_value: int) -> PackedByteArray:
	if kind == "dungeon":
		return Maps.dungeon_caves(size, size, seed_value)
	return Maps.surface_noise(size, size, seed_value)


## Fills a size x size map, then applies `edits` random single-cell edits twice:
##   batched    all edits, then one update_internals() (a bulk change, e.g. loading a saved chunk)
##   per frame  update_internals() after every edit (one edit per frame, the usual case in play)
## An edit toggles grass<->soil (surface) or wall<->floor (dungeon) on a random inner cell.
## quality = true also counts seams / fallback tiles at the end (slow on big maps).
static func run(kind: String, method: String, size: int, edits: int, seed_value: int, parent: Node,
		quality: bool = false) -> Dictionary:
	var map: PackedByteArray = noise_map(kind, size, seed_value)
	var mem0: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var t0: int = Time.get_ticks_usec()
	var grid: RefCounted = make_grid(kind, method, size, size, parent)
	var layer: TileMapLayer = grid.get("layer")
	grid.call("fill", map)
	layer.update_internals()
	var fill_us: int = Time.get_ticks_usec() - t0
	var mem1: float = Performance.get_monitor(Performance.MEMORY_STATIC)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 1
	var batched: Dictionary = _edit_pass(grid, layer, kind == "dungeon", _random_cells(rng, size, edits), false)
	var per_frame: Dictionary = _edit_pass(grid, layer, kind == "dungeon", _random_cells(rng, size, edits), true)

	var out: Dictionary = {
		"kind": kind, "method": method, "size": size, "edits": edits,
		"fill_ms": fill_us / 1000.0, "mem_mb": (mem1 - mem0) / 1048576.0,
		"edits_ms": batched["total_us"] / 1000.0,
		"edit_avg_us": float(batched["total_us"]) / maxf(edits, 1),
		"pf_ms": per_frame["total_us"] / 1000.0,
		"pf_avg_us": float(per_frame["total_us"]) / maxf(edits, 1),
		"pf_p99_us": per_frame["p99_us"], "pf_max_us": per_frame["max_us"],
		"touched": int(batched["touched"]) + int(per_frame["touched"]),
		"used_cells": layer.get_used_cells().size(),
	}
	if quality:
		if method == "a":
			out.merge(terrain_quality(grid))
		else:
			out.merge(dual_quality(grid))
	layer.queue_free()
	return out


static func _random_cells(rng: RandomNumberGenerator, size: int, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i: int in count:
		cells.append(Vector2i(rng.randi_range(1, size - 2), rng.randi_range(1, size - 2)))
	return cells


## Applies the edits. total_us covers the whole pass including the final (or per-edit) update.
static func _edit_pass(grid: RefCounted, layer: TileMapLayer, dungeon: bool, cells: Array[Vector2i],
		per_frame: bool) -> Dictionary:
	var times: PackedInt32Array = []
	var touched: int = 0
	var t0: int = Time.get_ticks_usec()
	for c: Vector2i in cells:
		var e0: int = Time.get_ticks_usec()
		var current: int = int(grid.call("get_terrain", c.x, c.y))
		var next: int
		if dungeon:
			next = Wang.FLOOR if current == Wang.WALL else Wang.WALL
		else:
			next = Wang.SOIL if current == Wang.GRASS else Wang.GRASS
		var changed: Array[Vector2i] = grid.call("set_terrain", c.x, c.y, next)
		touched += changed.size()
		if per_frame:
			layer.update_internals()
		times.append(Time.get_ticks_usec() - e0)
	if not per_frame:
		layer.update_internals()
	var total_us: int = Time.get_ticks_usec() - t0
	times.sort()
	var n: int = times.size()
	return {
		"total_us": total_us, "touched": touched,
		"p99_us": times[mini(n - 1, int(n * 0.99))] if n > 0 else 0,
		"max_us": times[n - 1] if n > 0 else 0,
	}


## Method (a): shared corners that disagree between neighbouring cells (visible seams) and cells
## whose tile center is not the painted terrain.
static func terrain_quality(grid: TerrainGrid) -> Dictionary:
	var seams: int = 0
	var bad_center: int = 0
	var w: int = grid.width
	var h: int = grid.height
	var corners: Array[PackedInt32Array] = []
	corners.resize(w * h)
	for y: int in h:
		for x: int in w:
			corners[y * w + x] = grid.cell_corners(Vector2i(x, y))
			if grid.cell_center(Vector2i(x, y)) != grid.painted[y * w + x]:
				bad_center += 1
	for y: int in h:
		for x: int in w:
			var c: PackedInt32Array = corners[y * w + x]
			if x + 1 < w:
				var r: PackedInt32Array = corners[y * w + x + 1]
				if c[1] != r[0] or c[3] != r[2]:
					seams += 1
			if y + 1 < h:
				var b: PackedInt32Array = corners[(y + 1) * w + x]
				if c[2] != b[0] or c[3] != b[1]:
					seams += 1
	return {"seams": seams, "bad_center": bad_center}


## Method (b): display cells whose corner key has no tile of its own (drawn with the nearest key,
## e.g. soil touching ash) and display cells whose tile corners differ from their vertices although
## the key has a tile (that would be a bug).
static func dual_quality(grid: DualGrid) -> Dictionary:
	var inexact: int = 0
	var wrong: int = 0
	for dy: int in range(-1, grid.height):
		for dx: int in range(-1, grid.width):
			var want: PackedByteArray = grid.display_corners(dx, dy)
			var key: int = Wang.key_of_corners(want)
			if grid.lookup.exact[key] == 0:
				inexact += 1
			var td: TileData = grid.layer.get_cell_tile_data(Vector2i(dx, dy))
			if key == grid.empty_key:
				if td != null:
					wrong += 1
				continue
			var have: PackedByteArray = td.get_custom_data(Wang.DATA_CORNERS) if td != null else PackedByteArray()
			if have != want and grid.lookup.exact[key] == 1:
				wrong += 1
	return {"inexact": inexact, "wrong": wrong}


static func format(r: Dictionary) -> String:
	var extra: String = ""
	for k: String in ["seams", "bad_center", "inexact", "wrong"]:
		if r.has(k):
			extra += " %s=%d" % [k, r[k]]
	return ("TILES_BENCH kind=%s method=%s size=%d fill_ms=%.1f mem_mb=%.1f edits=%d batched_ms=%.1f "
		+ "batched_avg_us=%.1f per_frame_ms=%.1f per_frame_avg_us=%.1f p99_us=%d max_us=%d touched=%d used=%d%s") % [
		r["kind"], r["method"], r["size"], r["fill_ms"], r["mem_mb"], r["edits"], r["edits_ms"],
		r["edit_avg_us"], r["pf_ms"], r["pf_avg_us"], r["pf_p99_us"], r["pf_max_us"], r["touched"],
		r["used_cells"], extra]


## Average microseconds for one set_cell() + update_internals() on a layer already holding
## size x size cells (the per-frame cost of a single tile change, as a function of layer size).
static func update_cost(kind: String, size: int, samples: int, parent: Node) -> float:
	var ts: TileSet = load(SURFACE_TILESET if kind == "surface" else DUNGEON_TILESET) as TileSet
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = ts
	parent.add_child(layer)
	for y: int in size:
		for x: int in size:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 3), 0)
	layer.update_internals()
	var t0: int = Time.get_ticks_usec()
	for i: int in samples:
		layer.set_cell(Vector2i(i % size, (i * 7) % size), 0, Vector2i(1, 0) if i % 2 == 0 else Vector2i(0, 3), 0)
		layer.update_internals()
	var us: float = float(Time.get_ticks_usec() - t0) / maxf(samples, 1)
	layer.queue_free()
	return us
