class_name WorldSnapshot
extends RefCounted
## A whole WorldData as bytes, for late join (game-concept §13 ○ "늦은 참가 스냅샷 스트리밍", spike
## RESULTS §5). The host sends the world itself instead of a seed for the joiner to regenerate: the
## generator uses FastNoiseLite (float math), so another architecture (the human's ARM64 Surface)
## might generate a different world from the same seed. The seed and the generator's hash travel in
## the welcome only as a diagnostic.
##
## Raw      header + the six layers in WorldData.Layer order, w x h bytes each (row-major) + the
##          drops (M2b: WorldData.drops_bytes(), u16 count + 11 B each, by id; gatherables are the
##          VEGETATION layer)
##   header u16 w, u16 h, i64 seed, u16 altar x, u16 altar y, u16 altar w, u16 altar h, u8 layers (6)
## Packed   raw compressed with zstd. Godot's zstd decoder returns nothing for bad input (deflate
##          logs an engine error), so a broken snapshot is counted, not logged.
## Chunks   packed split into chunk_bytes pieces (u32 index + bytes; Config.NET_SNAPSHOT_CHUNK_BYTES,
##          the most a joiner accepts); the host sends at most Config.NET_SNAPSHOT_CHUNKS_PER_TICK per
##          tick, reliable and in order, so a bigger map takes more ticks, never bigger messages.
## The welcome that follows the last chunk carries raw size, packed size, chunk count, the packed
## bytes' md5 and the world's content hash (WorldData.content_hash); the joiner checks every one of
## them before it uses the world (Receiver.finish).

const HEADER_SIZE: int = 2 + 2 + 8 + 2 + 2 + 2 + 2 + 1
const CHUNK_HEADER: int = 4
const COMPRESSION: FileAccess.CompressionMode = FileAccess.COMPRESSION_ZSTD
## Cells per axis a snapshot may claim (bounds what a joiner allocates; u16 on the wire). 4x the M1
## map's width: the biggest world the join flow can take. Even incompressible (MAX_PACKED, 1.6 MB)
## it streams in about 3.3 s at NET_SNAPSHOT_CHUNKS_PER_TICK, inside NET_CONNECT_TIMEOUT_SEC, and
## loads (GameWorld.load_data) in under a second here; 2048 would mean ~25 MB, minutes of streaming
## and ~13 s / 1.4 GB to load. Raise it together with those when maps grow.
const MAX_SIDE: int = 512
const MAX_RAW: int = HEADER_SIZE + WorldData.LAYER_COUNT * MAX_SIDE * MAX_SIDE + 2 + WorldData.DROP_BYTES * Config.MAX_DROPS
## zstd never grows data by more than a small fraction; a receiver refuses more than this.
const MAX_PACKED: int = MAX_RAW + MAX_RAW / 64 + 1024

## Chunk size the host cuts snapshots into (Packed remembers its own). Test only: a host started with
## --test-snapshot-chunk-bytes=<n> (set by the Cli autoload) uses smaller chunks, so the M1 world
## (one chunk normally) streams over several chunks and ticks in a real session.
static var chunk_bytes: int = Config.NET_SNAPSHOT_CHUNK_BYTES


## A world packed for sending (the host makes one per joiner, when it admits it).
class Packed:
	extends RefCounted
	var bytes: PackedByteArray = PackedByteArray()
	var raw_size: int = 0
	var packed_md5: PackedByteArray = PackedByteArray()
	## WorldData.content_hash() of the packed world, as 16 bytes.
	var world_md5: PackedByteArray = PackedByteArray()
	var encode_usec: int = 0
	var chunk_size: int = Config.NET_SNAPSHOT_CHUNK_BYTES

	func chunk_count() -> int:
		return WorldSnapshot.chunks_for(bytes.size(), chunk_size)

	## Chunk message i: u32 index + up to chunk_size bytes.
	func chunk(i: int) -> PackedByteArray:
		var start: int = i * chunk_size
		var out: PackedByteArray = PackedByteArray()
		out.resize(CHUNK_HEADER)
		out.encode_u32(0, i)
		out.append_array(bytes.slice(start, mini(start + chunk_size, bytes.size())))
		return out


## The host's side of one joiner's stream: the next chunk messages, at most `budget` per tick.
class Sender:
	extends RefCounted
	var packed: Packed
	var next_chunk: int = 0

	func _init(p_packed: Packed) -> void:
		packed = p_packed

	## The next chunk messages, in order, at most `budget` (one tick's worth).
	func take(budget: int) -> Array[PackedByteArray]:
		var out: Array[PackedByteArray] = []
		while next_chunk < packed.chunk_count() and out.size() < budget:
			out.append(packed.chunk(next_chunk))
			next_chunk += 1
		return out

	## Every chunk handed out (time for the welcome).
	func done() -> bool:
		return next_chunk >= packed.chunk_count()


## A joiner collecting chunks (in order, reliable) until the welcome says how many there were.
class Receiver:
	extends RefCounted
	var bytes: PackedByteArray = PackedByteArray()
	var chunks: int = 0
	## Why the last add() / finish() failed ("" = fine).
	var error: String = ""

	## Takes one chunk message. False (and `error`) for a malformed, out-of-order or oversized one.
	func add(message: PackedByteArray) -> bool:
		if message.size() <= CHUNK_HEADER or message.size() > CHUNK_HEADER + Config.NET_SNAPSHOT_CHUNK_BYTES:
			error = "chunk of %d bytes" % message.size()
			return false
		var index: int = message.decode_u32(0)
		if index != chunks:
			error = "chunk %d, expected %d" % [index, chunks]
			return false
		if bytes.size() + message.size() - CHUNK_HEADER > MAX_PACKED:
			error = "more than %d bytes" % MAX_PACKED
			return false
		bytes.append_array(message.slice(CHUNK_HEADER))
		chunks += 1
		return true

	## The world, once the welcome's numbers match what arrived; null (and `error`) otherwise.
	func finish(chunk_count: int, packed_size: int, packed_md5: PackedByteArray, raw_size: int,
			world_md5: PackedByteArray) -> WorldData:
		if chunks != chunk_count or bytes.size() != packed_size:
			error = "got %d chunks / %d bytes, the host sent %d / %d" % [chunks, bytes.size(), chunk_count, packed_size]
			return null
		if WorldSnapshot.md5(bytes) != packed_md5:
			error = "packed bytes md5 differs"
			return null
		var data: WorldData = WorldSnapshot.unpack(bytes, raw_size)
		if data == null:
			error = "cannot unpack %d bytes into %d" % [bytes.size(), raw_size]
			return null
		if data.content_hash() != world_md5.hex_encode():
			error = "world hash %s, the host's %s" % [data.content_hash(), world_md5.hex_encode()]
			return null
		return data


static func chunks_for(packed_size: int, size: int = chunk_bytes) -> int:
	return ceili(float(packed_size) / size)


static func md5(bytes: PackedByteArray) -> PackedByteArray:
	if bytes.is_empty():
		return PackedByteArray()  # HashingContext.update() refuses empty data with an engine error
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish()


## Header + layers + drops, uncompressed.
static func raw_bytes(data: WorldData) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(HEADER_SIZE)
	out.encode_u16(0, data.size.x)
	out.encode_u16(2, data.size.y)
	out.encode_s64(4, data.world_seed)
	out.encode_u16(12, data.altar_rect.position.x)
	out.encode_u16(14, data.altar_rect.position.y)
	out.encode_u16(16, data.altar_rect.size.x)
	out.encode_u16(18, data.altar_rect.size.y)
	out.encode_u8(20, WorldData.LAYER_COUNT)
	for grid: PackedByteArray in data.layers:
		out.append_array(grid)
	out.append_array(data.drops_bytes())
	return out


## The world from raw_bytes(), or null when the bytes do not describe a valid one (size, layer
## count, altar inside the map, floor values that are terrains, drops: at most Config.MAX_DROPS,
## each a valid item stack inside the map, ids unique, nothing after them).
static func decode_raw(raw: PackedByteArray) -> WorldData:
	if raw.size() < HEADER_SIZE:
		return null
	var size: Vector2i = Vector2i(raw.decode_u16(0), raw.decode_u16(2))
	if size.x < 1 or size.y < 1 or size.x > MAX_SIDE or size.y > MAX_SIDE:
		return null
	if raw.decode_u8(20) != WorldData.LAYER_COUNT:
		return null
	var cells: int = size.x * size.y
	var drops_at: int = HEADER_SIZE + WorldData.LAYER_COUNT * cells
	if raw.size() < drops_at + 2:
		return null
	var drop_count: int = raw.decode_u16(drops_at)
	if drop_count > Config.MAX_DROPS or raw.size() != drops_at + 2 + WorldData.DROP_BYTES * drop_count:
		return null
	var altar: Rect2i = Rect2i(raw.decode_u16(12), raw.decode_u16(14), raw.decode_u16(16), raw.decode_u16(18))
	if altar.has_area() and not Rect2i(Vector2i.ZERO, size).encloses(altar):
		return null
	var data: WorldData = WorldData.new(size)
	data.world_seed = raw.decode_s64(4)
	data.altar_rect = altar if altar.has_area() else Rect2i()
	for i: int in WorldData.LAYER_COUNT:
		var start: int = HEADER_SIZE + i * cells
		data.layers[i] = raw.slice(start, start + cells)
	var floor_grid: PackedByteArray = data.layers[WorldData.Layer.FLOOR]
	var terrains: int = 0
	for t: int in Terrain.COUNT:
		terrains += floor_grid.count(t)
	if terrains != cells:
		return null
	for i: int in drop_count:
		var d: WorldData.Drop = WorldData.read_drop(raw, drops_at + 2 + WorldData.DROP_BYTES * i, size)
		if d == null or data.drops.has(d.id):
			return null
		data.drops[d.id] = d
	return data


static func encode(data: WorldData) -> Packed:
	var t0: int = Time.get_ticks_usec()
	var p: Packed = Packed.new()
	var raw: PackedByteArray = raw_bytes(data)
	p.raw_size = raw.size()
	p.chunk_size = clampi(chunk_bytes, 1, Config.NET_SNAPSHOT_CHUNK_BYTES)
	p.bytes = raw.compress(COMPRESSION)
	p.packed_md5 = md5(p.bytes)
	p.world_md5 = data.content_hash().hex_decode()
	p.encode_usec = Time.get_ticks_usec() - t0
	return p


## The world from packed bytes and the raw size the welcome gave, or null.
static func unpack(packed: PackedByteArray, raw_size: int) -> WorldData:
	if packed.is_empty() or raw_size < HEADER_SIZE or raw_size > MAX_RAW:
		return null
	var raw: PackedByteArray = packed.decompress(raw_size, COMPRESSION)
	if raw.size() != raw_size:
		return null
	return decode_raw(raw)
