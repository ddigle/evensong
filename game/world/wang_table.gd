class_name WangTable
extends RefCounted
## Corner key -> tile table for the dual grid, read from the custom data of a TileSet built by
## TilesetBuilder ("corners" + TileData.probability).
##
## For each of the 81 corner keys it keeps the candidate tiles:
##   - several with the same corners = variants, picked by a stable position hash weighted by
##     TileData.probability (the same display cell always gets the same variant)
##   - none = no art for that mix (soil + ash). The nearest key that has tiles is used instead
##     (sum of Terrain.distance over the corners) and the key is counted in `fallback_keys`.

class KeyEntry:
	extends RefCounted
	var sources: PackedInt32Array = PackedInt32Array()
	var coords: Array[Vector2i] = []
	var cumulative: PackedFloat32Array = PackedFloat32Array()
	var exact: bool = false
	var resolved_key: int = -1


var tile_set: TileSet
var entries: Array[KeyEntry] = []
var exact_keys: int = 0
var fallback_keys: int = 0


static func from_tile_set(ts: TileSet) -> WangTable:
	var table: WangTable = WangTable.new()
	table.tile_set = ts
	var found: Array[KeyEntry] = []
	for k: int in Terrain.KEY_COUNT:
		found.append(KeyEntry.new())
	var source_ids: Array[int] = []
	for i: int in ts.get_source_count():
		source_ids.append(ts.get_source_id(i))
	source_ids.sort()
	for source_id: int in source_ids:
		var source: TileSetAtlasSource = ts.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for t: int in source.get_tiles_count():
			var atlas: Vector2i = source.get_tile_id(t)
			var td: TileData = source.get_tile_data(atlas, 0)
			var corners: PackedByteArray = td.get_custom_data(TilesetBuilder.DATA_CORNERS)
			if corners.size() != 4:
				continue
			var e: KeyEntry = found[Terrain.key_of_corners(corners)]
			var total: float = e.cumulative[e.cumulative.size() - 1] if not e.cumulative.is_empty() else 0.0
			e.sources.append(source_id)
			e.coords.append(atlas)
			e.cumulative.append(total + maxf(td.probability, 0.0001))
	for e: KeyEntry in found:
		e.exact = not e.sources.is_empty()
		if e.exact:
			table.exact_keys += 1
	if table.exact_keys == 0:
		push_error("WangTable: the TileSet has no tiles with '%s' custom data" % TilesetBuilder.DATA_CORNERS)
		return null
	for k: int in Terrain.KEY_COUNT:
		var e: KeyEntry = found[k]
		if e.exact:
			e.resolved_key = k
		else:
			var use: int = _nearest_key(k, found)
			var src: KeyEntry = found[use]
			e.sources = src.sources
			e.coords = src.coords
			e.cumulative = src.cumulative
			e.exact = false
			e.resolved_key = use
			table.fallback_keys += 1
		table.entries.append(e)
	return table


## Candidate index for display cell d of corner key `key`.
func pick(key: int, d: Vector2i) -> int:
	var w: PackedFloat32Array = entries[key].cumulative
	var n: int = w.size()
	if n == 1:
		return 0
	var target: float = hash01(d.x, d.y) * w[n - 1]
	for i: int in n:
		if target < w[i]:
			return i
	return n - 1


## Stable pseudo-random value in [0, 1) for a cell (integer hash, same on every machine).
static func hash01(x: int, y: int) -> float:
	var h: int = (x * 374761393 + y * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffffff) / 16777216.0


static func _nearest_key(key: int, found: Array[KeyEntry]) -> int:
	var want: PackedByteArray = Terrain.corners_of_key(key)
	var best_key: int = -1
	var best_cost: int = 1000000
	for k: int in Terrain.KEY_COUNT:
		if not found[k].exact:
			continue  # only keys with their own art (not other fallbacks)
		var have: PackedByteArray = Terrain.corners_of_key(k)
		var cost: int = 0
		for i: int in 4:
			cost += Terrain.distance(have[i], want[i])
		if cost < best_cost:
			best_cost = cost
			best_key = k
	return best_key
