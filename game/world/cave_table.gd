class_name CaveTable
extends RefCounted
## Corner key -> tile table for the dungeon's dual grid (M3a), read from the custom data of the TileSet
## TilesetBuilder.build_dungeon() makes ("corners", "context", TileData.probability).
##
## A corner key packs the four corner values (Walls.V_FLOOR / V_WALL / V_FACE) like Terrain keys:
## NW + 3 NE + 9 SW + 27 SE (0..80). The 04-env cliff set has 21 of the 36 keys a dungeon can make.
## Per key the candidates are:
##   - tiles whose context (the corners above the top two and below the bottom two, CONTEXT_ANY =
##     any) matches the cell's surroundings; the most specific matching ones win (the set has two
##     tiles for four keys, e.g. a wall's west edge where its top ends (t1_10) and the plain one (t1_4))
##   - among those, the variants by TileData.probability with WangTable.hash01 of the cell (stable)
##   - a key with no tile (a face right above a wall top, a face next to a wall a row lower, ...) is
##     drawn with the nearest key that has tiles (distance per corner: face<->wall 1, face<->floor 1,
##     wall<->floor 2; ties: lowest key) and counted as a fallback.

const KEY_COUNT: int = 81


class Candidate:
	extends RefCounted
	var source: int = 0
	var coords: Vector2i = Vector2i.ZERO
	var weight: float = 1.0
	var context: PackedByteArray = PackedByteArray()
	var corners: PackedByteArray = PackedByteArray()

	func specificity() -> int:
		var n: int = 0
		for v: int in context:
			if v != TilesetBuilder.CONTEXT_ANY:
				n += 1
		return n

	func matches(ctx: PackedByteArray) -> bool:
		for i: int in mini(context.size(), ctx.size()):
			if context[i] != TilesetBuilder.CONTEXT_ANY and context[i] != ctx[i]:
				return false
		return true


var tile_set: TileSet
## Candidates by key (a fallback key holds its resolved key's candidates).
var entries: Array[Array] = []
var exact: PackedByteArray = PackedByteArray()
var resolved: PackedInt32Array = PackedInt32Array()
var exact_keys: int = 0


static func key_of(nw: int, ne: int, sw: int, se: int) -> int:
	return nw + 3 * ne + 9 * sw + 27 * se


static func corners_of_key(key: int) -> PackedByteArray:
	return PackedByteArray([key % 3, (key / 3) % 3, (key / 9) % 3, (key / 27) % 3])


## Cost of drawing corner value `have` where `want` is.
static func distance(have: int, want: int) -> int:
	if have == want:
		return 0
	if have == Walls.V_FACE or want == Walls.V_FACE:
		return 1
	return 2


static func from_tile_set(ts: TileSet) -> CaveTable:
	var t: CaveTable = CaveTable.new()
	t.tile_set = ts
	var found: Array[Array] = []
	for k: int in KEY_COUNT:
		found.append([])
	var source_ids: Array[int] = []
	for i: int in ts.get_source_count():
		source_ids.append(ts.get_source_id(i))
	source_ids.sort()
	for source_id: int in source_ids:
		var source: TileSetAtlasSource = ts.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for i: int in source.get_tiles_count():
			var atlas: Vector2i = source.get_tile_id(i)
			var td: TileData = source.get_tile_data(atlas, 0)
			var corners: PackedByteArray = td.get_custom_data(TilesetBuilder.DATA_CORNERS)
			if corners.size() != 4:
				continue
			var c: Candidate = Candidate.new()
			c.source = source_id
			c.coords = atlas
			c.weight = maxf(td.probability, 0.0001)
			c.corners = corners
			c.context = td.get_custom_data(TilesetBuilder.DATA_CONTEXT)
			found[key_of(corners[0], corners[1], corners[2], corners[3])].append(c)
	t.exact.resize(KEY_COUNT)
	t.resolved.resize(KEY_COUNT)
	for k: int in KEY_COUNT:
		t.exact[k] = 1 if not found[k].is_empty() else 0
		t.exact_keys += t.exact[k]
	for k: int in KEY_COUNT:
		var use: int = k if t.exact[k] == 1 else t._nearest(k)
		t.resolved[k] = use
		t.entries.append(found[use] if use >= 0 else [])
	return t


func _nearest(key: int) -> int:
	var want: PackedByteArray = corners_of_key(key)
	var best: int = -1
	var best_cost: int = 1000000
	for k: int in KEY_COUNT:
		if exact[k] == 0:
			continue
		var have: PackedByteArray = corners_of_key(k)
		var cost: int = 0
		for i: int in 4:
			cost += distance(have[i], want[i])
		if cost < best_cost:
			best_cost = cost
			best = k
	return best


func is_exact(key: int) -> bool:
	return exact[key] == 1


## The tile for a cell with corner key `key`, surroundings `ctx` ([above NW, above NE, below SW,
## below SE]) at display cell `d` (for the stable variant pick). Null when the set has nothing.
func pick(key: int, ctx: PackedByteArray, d: Vector2i) -> Candidate:
	var all: Array = entries[key]
	if all.is_empty():
		return null
	var best: Array[Candidate] = []
	var best_spec: int = -1
	for item: Variant in all:
		var c: Candidate = item
		if not c.matches(ctx):
			continue
		var spec: int = c.specificity()
		if spec > best_spec:
			best.clear()
			best_spec = spec
		if spec == best_spec:
			best.append(c)
	if best.is_empty():
		# No context fits (or a fallback key): the plainest candidates.
		var low: int = 1000
		for item: Variant in all:
			var c: Candidate = item
			low = mini(low, c.specificity())
		for item: Variant in all:
			var c: Candidate = item
			if c.specificity() == low:
				best.append(c)
	if best.size() == 1:
		return best[0]
	var total: float = 0.0
	for c: Candidate in best:
		total += c.weight
	var target: float = WangTable.hash01(d.x, d.y) * total
	var run: float = 0.0
	for c: Candidate in best:
		run += c.weight
		if target < run:
			return c
	return best[best.size() - 1]
