extends RefCounted
## Corner-key -> tile table for the dual grid (method b), built from a TileSet's custom data
## (wang_corners / wang_pattern / probability, written by build_tilesets.gd).
##
## For each of the 81 corner keys (3 terrains ^ 4 corners) it keeps the candidate tiles:
##   - one candidate: used as is (fast path)
##   - several with the same corners: inner-tile variants (weighted by TileData.probability, picked
##     by a position hash so the result is stable) and/or context tiles (the dungeon set has tiles
##     whose JSON pattern_4x4 also constrains the vertices above/below the tile, e.g. a wall cap)
##   - none: the nearest key that has tiles (sum of per-corner terrain distances), counted in
##     `fallback_keys`. Tilesets made of two-terrain Wang sets cannot draw every 3-terrain mix.

const Wang := preload("res://tiles/wang.gd")

## Per key (index 0..80).
var sources: Array[PackedInt32Array] = []
var coords: Array[Array] = []                  # Array[Vector2i] per key
var cumulative: Array[PackedFloat32Array] = []  # running sum of weights per key
var patterns: Array[Array] = []                # Array[PackedByteArray] per key (16 entries, 255 = any)
var has_context: PackedByteArray = []          # 1 if any candidate of the key constrains outer vertices
var exact: PackedByteArray = []                # 1 if the key has its own tiles, 0 if it uses a fallback
var resolved_key: PackedInt32Array = []        # key whose tiles are used (== key when exact)
## Fast path: source id when the key has exactly one candidate, else -1.
var single_source: PackedInt32Array = []
var single_coords: Array[Vector2i] = []
var fallback_keys: int = 0
var exact_keys: int = 0
## How far the context patterns reach beyond the tile's own 2x2 corners (0 or 1 each).
var reach_left: int = 0
var reach_right: int = 0
var reach_up: int = 0
var reach_down: int = 0


## distance[a][b] is the cost of drawing terrain a where terrain b was asked for (fallbacks).
func _init(tile_set: TileSet, distance: Array) -> void:
	var found: Array[Array] = []
	found.resize(Wang.KEY_COUNT)
	for k: int in Wang.KEY_COUNT:
		found[k] = []
	var source_ids: Array[int] = []
	for i: int in tile_set.get_source_count():
		source_ids.append(tile_set.get_source_id(i))
	source_ids.sort()
	for source_id: int in source_ids:
		var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for t: int in source.get_tiles_count():
			var atlas: Vector2i = source.get_tile_id(t)
			var td: TileData = source.get_tile_data(atlas, 0)
			var corners: PackedByteArray = td.get_custom_data(Wang.DATA_CORNERS)
			if corners.size() != 4:
				continue
			var pattern: PackedByteArray = td.get_custom_data(Wang.DATA_PATTERN)
			if pattern.size() != 16:
				pattern = PackedByteArray()
			found[Wang.key_of_corners(corners)].append([source_id, atlas, td.probability, pattern])

	for k: int in Wang.KEY_COUNT:
		var use: int = k
		if found[k].is_empty():
			use = _nearest_key(k, found, distance)
			fallback_keys += 1
			exact.append(0)
		else:
			exact_keys += 1
			exact.append(1)
		resolved_key.append(use)
		var s: PackedInt32Array = []
		var c: Array[Vector2i] = []
		var w: PackedFloat32Array = []
		var p: Array[PackedByteArray] = []
		var context: int = 0
		var total: float = 0.0
		for cand: Array in found[use]:
			s.append(cand[0])
			c.append(cand[1])
			total += maxf(float(cand[2]), 0.0001)
			w.append(total)
			var pattern: PackedByteArray = cand[3]
			p.append(pattern)
			if _outer_constraints(pattern) > 0:
				context = 1
		sources.append(s)
		coords.append(c)
		cumulative.append(w)
		patterns.append(p)
		has_context.append(context)
		single_source.append(s[0] if s.size() == 1 else -1)
		single_coords.append(c[0] if s.size() == 1 else Vector2i(-1, -1))


## Picks the candidate index for display cell (dx, dy) of key `key` (index into sources[key] /
## coords[key]). vertex(x, y) -> terrain is only called for keys with context tiles.
func pick_index(key: int, dx: int, dy: int, vertex: Callable) -> int:
	var w: PackedFloat32Array = cumulative[key]
	var n: int = w.size()
	if n == 1:
		return 0
	if has_context[key] == 0:
		# Variants only: weighted choice by a stable position hash.
		var target: float = hash01(dx, dy) * w[n - 1]
		for i: int in n:
			if target < w[i]:
				return i
		return n - 1
	# Context tiles: best pattern score first, then the weighted hash among the tied ones.
	var pats: Array = patterns[key]
	var best: int = -1000000
	var allowed: Array[int] = []
	for i: int in n:
		var score: int = _context_score(pats[i], dx, dy, vertex)
		if score > best:
			best = score
			allowed.clear()
		if score == best:
			allowed.append(i)
	if allowed.size() == 1:
		return allowed[0]
	var total: float = 0.0
	for i: int in allowed:
		total += w[i] - (w[i - 1] if i > 0 else 0.0)
	var target2: float = hash01(dx, dy) * total
	var run: float = 0.0
	for i: int in allowed:
		run += w[i] - (w[i - 1] if i > 0 else 0.0)
		if target2 < run:
			return i
	return allowed[allowed.size() - 1]


## Stable pseudo-random value in [0, 1) for a cell.
static func hash01(x: int, y: int) -> float:
	var h: int = (x * 374761393 + y * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffffff) / 16777216.0


func _context_score(pattern: PackedByteArray, dx: int, dy: int, vertex: Callable) -> int:
	if pattern.is_empty():
		return 0
	var score: int = 0
	for row: int in 4:
		for col: int in 4:
			if (row == 1 or row == 2) and (col == 1 or col == 2):
				continue
			var want: int = pattern[row * 4 + col]
			if want == Wang.WILDCARD:
				continue
			if int(vertex.call(dx - 1 + col, dy - 1 + row)) == want:
				score += 1
			else:
				score -= 100
	return score


func _outer_constraints(pattern: PackedByteArray) -> int:
	if pattern.is_empty():
		return 0
	var n: int = 0
	for row: int in 4:
		for col: int in 4:
			if (row == 1 or row == 2) and (col == 1 or col == 2):
				continue
			if pattern[row * 4 + col] != Wang.WILDCARD:
				n += 1
				if row == 0:
					reach_up = 1
				if row == 3:
					reach_down = 1
				if col == 0:
					reach_left = 1
				if col == 3:
					reach_right = 1
	return n


static func _nearest_key(key: int, found: Array[Array], distance: Array) -> int:
	var want: PackedByteArray = Wang.corners_of_key(key)
	var best_key: int = -1
	var best_cost: int = 1000000
	for k: int in Wang.KEY_COUNT:
		if found[k].is_empty():
			continue
		var have: PackedByteArray = Wang.corners_of_key(k)
		var cost: int = 0
		for i: int in 4:
			cost += int((distance[have[i]] as Array)[want[i]])
		if cost < best_cost:
			best_cost = cost
			best_key = k
	return best_key
