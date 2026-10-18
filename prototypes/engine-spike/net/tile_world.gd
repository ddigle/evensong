extends RefCounted
## Authoritative tile map data for the net spike. Pure data (no nodes), so the host, every
## client and the unit test share it.
##
## Three byte layers on a width x height grid (16px tiles): floor, wall (destructible), ore.
## They live in one PackedByteArray `cells`, layer-major (index = layer * width * height +
## y * width + x), so every write is in place.
## Snapshots go out in CHUNK x CHUNK chunks, zstd-compressed. Deltas are absolute
## "set cell to value" records of DELTA_SIZE bytes, so applying one twice is harmless
## (a late joiner may get a delta that its snapshot already contains).

const LAYER_FLOOR: int = 0
const LAYER_WALL: int = 1
const LAYER_ORE: int = 2
const LAYER_COUNT: int = 3
const LAYER_NAMES: PackedStringArray = ["floor", "wall", "ore"]

const WALL_NONE: int = 0
const WALL_DIRT: int = 1
const WALL_STONE: int = 2
const WALL_BEDROCK: int = 255

const TILE_PX: int = 16
const CHUNK: int = 32
## layer u8, x u16, y u16, value u8
const DELTA_SIZE: int = 6
## Host check for "break wall": distance from the player to the cell centre.
const REACH_PX: float = 56.0
const MIN_SIZE: int = 64
const MAX_SIZE: int = 4096

## Reasons returned by validate_break(). "" means the request is accepted.
const REJECT_BOUNDS: String = "out_of_bounds"
const REJECT_REACH: String = "out_of_reach"
const REJECT_NO_WALL: String = "no_wall"
const REJECT_UNBREAKABLE: String = "unbreakable"

var width: int = 0
var height: int = 0
var cells: PackedByteArray = PackedByteArray()


func _init(w: int = 0, h: int = 0) -> void:
	resize(w, h)


func resize(w: int, h: int) -> void:
	width = w
	height = h
	cells = PackedByteArray()
	cells.resize(w * h * LAYER_COUNT)  # zero-filled


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index_of(layer: int, c: Vector2i) -> int:
	return layer * width * height + c.y * width + c.x


func get_cell(layer: int, c: Vector2i) -> int:
	if not in_bounds(c):
		return WALL_BEDROCK if layer == LAYER_WALL else 0
	return cells[index_of(layer, c)]


## Returns true when the value changed.
func set_cell(layer: int, c: Vector2i, value: int) -> bool:
	if layer < 0 or layer >= LAYER_COUNT or not in_bounds(c):
		return false
	var i: int = index_of(layer, c)
	if cells[i] == value:
		return false
	cells[i] = value
	return true


static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE_PX + Vector2(TILE_PX, TILE_PX) * 0.5


static func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE_PX), floori(pos.y / TILE_PX))


# --- layout used by the scripted test ---------------------------------------------------------

## Open area in the middle of the map where players spawn.
func arena_rect() -> Rect2i:
	return Rect2i(width / 2 - 28, height / 2 - 10, 56, 20)


## Spawn cell of the index-th player (0 = host). Columns are 5 tiles apart, up to 10 players.
func spawn_cell(index: int) -> Vector2i:
	var a: Rect2i = arena_rect()
	return Vector2i(a.position.x + 4 + 5 * posmod(index, 10), a.position.y + 9)


## Region the host's "burst" action edits (far from the arena).
func burst_rect(count: int) -> Rect2i:
	return Rect2i(16, 16, 20, clampi(ceili(count / 20.0), 1, 20))


## Fills the map from a seed: biome floor, noise caves of dirt/stone, sparse ore, a bedrock
## border, and the arena: cleared, with a wall row 5 tiles above the spawn row (stone, bedrock
## straight above every spawn column) and a stone row 6 tiles below it.
func generate(seed_value: int) -> void:
	var cave: FastNoiseLite = FastNoiseLite.new()
	cave.seed = seed_value
	cave.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave.frequency = 0.045
	var biome: FastNoiseLite = FastNoiseLite.new()
	biome.seed = seed_value + 1
	biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome.frequency = 0.012
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var plane: int = width * height
	for y: int in height:
		for x: int in width:
			var i: int = y * width + x
			cells[i] = 1 + clampi(int((biome.get_noise_2d(x, y) + 1.0) * 2.0), 0, 3)
			var n: float = cave.get_noise_2d(x, y)
			var wall: int = WALL_NONE
			if n > 0.05:
				wall = WALL_STONE if n > 0.3 else WALL_DIRT
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				wall = WALL_BEDROCK
			cells[plane + i] = wall
			cells[2 * plane + i] = 1 if wall == WALL_STONE and rng.randi_range(0, 11) == 0 else 0
	var arena: Rect2i = arena_rect()
	for y: int in range(arena.position.y, arena.end.y):
		for x: int in range(arena.position.x, arena.end.x):
			cells[plane + y * width + x] = WALL_NONE
			cells[2 * plane + y * width + x] = 0
	var spawn_row: int = spawn_cell(0).y
	var first_col: int = spawn_cell(0).x
	for x: int in range(arena.position.x + 2, arena.end.x - 2):
		var top: int = WALL_BEDROCK if posmod(x - first_col, 5) == 0 else WALL_STONE
		cells[plane + (spawn_row - 5) * width + x] = top
		cells[plane + (spawn_row + 6) * width + x] = WALL_STONE


# --- rules -------------------------------------------------------------------------------------

func is_solid(c: Vector2i) -> bool:
	return get_cell(LAYER_WALL, c) != WALL_NONE


## True when an axis-aligned box (centre, half size) overlaps a wall cell.
func box_hits_wall(center: Vector2, half: Vector2) -> bool:
	var x0: int = floori((center.x - half.x) / TILE_PX)
	var x1: int = floori((center.x + half.x - 0.001) / TILE_PX)
	var y0: int = floori((center.y - half.y) / TILE_PX)
	var y1: int = floori((center.y + half.y - 0.001) / TILE_PX)
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			if is_solid(Vector2i(x, y)):
				return true
	return false


## Host-side check of a client's "break wall at cell" request. "" = accept.
func validate_break(c: Vector2i, player_pos: Vector2) -> String:
	if not in_bounds(c):
		return REJECT_BOUNDS
	if cell_center(c).distance_to(player_pos) > REACH_PX:
		return REJECT_REACH
	var wall: int = get_cell(LAYER_WALL, c)
	if wall == WALL_NONE:
		return REJECT_NO_WALL
	if wall == WALL_BEDROCK:
		return REJECT_UNBREAKABLE
	return ""


# --- deltas ------------------------------------------------------------------------------------

static func append_delta(buf: PackedByteArray, layer: int, c: Vector2i, value: int) -> PackedByteArray:
	var n: int = buf.size()
	buf.resize(n + DELTA_SIZE)
	buf.encode_u8(n, layer)
	buf.encode_u16(n + 1, c.x)
	buf.encode_u16(n + 3, c.y)
	buf.encode_u8(n + 5, value)
	return buf


## Applies a packed delta buffer. Returns the cells it named as [layer, Vector2i, value]
## triples (changed or not), or an empty array when the buffer is malformed.
func apply_deltas(buf: PackedByteArray) -> Array:
	var out: Array = []
	if buf.size() % DELTA_SIZE != 0:
		return out
	for n: int in range(0, buf.size(), DELTA_SIZE):
		var layer: int = buf.decode_u8(n)
		var c: Vector2i = Vector2i(buf.decode_u16(n + 1), buf.decode_u16(n + 3))
		var value: int = buf.decode_u8(n + 5)
		if layer >= LAYER_COUNT or not in_bounds(c):
			continue
		set_cell(layer, c, value)
		out.append([layer, c, value])
	return out


# --- snapshots ---------------------------------------------------------------------------------

func chunks_x() -> int:
	return ceili(width / float(CHUNK))


func chunks_y() -> int:
	return ceili(height / float(CHUNK))


func chunk_rect(cx: int, cy: int) -> Rect2i:
	var r: Rect2i = Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
	return r.intersection(Rect2i(0, 0, width, height))


## Raw chunk bytes: every layer, row by row inside the chunk rect.
func encode_chunk(cx: int, cy: int) -> PackedByteArray:
	var r: Rect2i = chunk_rect(cx, cy)
	var out: PackedByteArray = PackedByteArray()
	for layer: int in LAYER_COUNT:
		for y: int in range(r.position.y, r.end.y):
			var start: int = index_of(layer, Vector2i(r.position.x, y))
			out.append_array(cells.slice(start, start + r.size.x))
	return out


func decode_chunk(cx: int, cy: int, raw: PackedByteArray) -> bool:
	var r: Rect2i = chunk_rect(cx, cy)
	if r.size.x <= 0 or raw.size() != r.size.x * r.size.y * LAYER_COUNT:
		return false
	var n: int = 0
	for layer: int in LAYER_COUNT:
		for y: int in range(r.position.y, r.end.y):
			var start: int = index_of(layer, Vector2i(r.position.x, y))
			for x: int in r.size.x:
				cells[start + x] = raw[n]
				n += 1
	return true


func compress_chunk(cx: int, cy: int) -> PackedByteArray:
	return encode_chunk(cx, cy).compress(FileAccess.COMPRESSION_ZSTD)


func apply_compressed_chunk(cx: int, cy: int, data: PackedByteArray, raw_size: int) -> bool:
	if raw_size <= 0 or raw_size > CHUNK * CHUNK * LAYER_COUNT:
		return false
	var raw: PackedByteArray = data.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return false
	return decode_chunk(cx, cy, raw)


# --- hashing -----------------------------------------------------------------------------------

func hash_hex() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var header: PackedByteArray = PackedByteArray()
	header.resize(8)
	header.encode_u32(0, width)
	header.encode_u32(4, height)
	ctx.update(header)
	if not cells.is_empty():  # update() refuses an empty array (engine error)
		ctx.update(cells)
	return ctx.finish().hex_encode()


func count_value(layer: int, value: int) -> int:
	var plane: int = width * height
	return cells.slice(layer * plane, (layer + 1) * plane).count(value)
