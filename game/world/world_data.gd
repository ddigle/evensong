class_name WorldData
extends RefCounted
## The tile world as plain data: one byte per cell for each of the six layers of
## gameplay-design §3.1 (● floor / wall / ore / vegetation / corruption / placeables), and (M7-rf) a seventh byte for the
## floor layer's built half, the laid floor pieces (FLOOR_PIECE, below).
##
## Floor = vertex grid of the dual grid: the floor value of world cell (x, y) is the terrain at
## the vertex in the centre of that cell. The ground view draws display cells shifted by half a
## tile, so display cell (dx, dy) has the four vertices (dx, dy), (dx+1, dy), (dx, dy+1),
## (dx+1, dy+1) as its NW / NE / SW / SE corners (world/ground_view.gd). Vertices outside the map
## read OUTSIDE_TERRAIN.
##
## M1 uses FLOOR (grass / soil / ash), CORRUPTION (zone id 1.. per ash cell, 0 = clean) and
## PLACEABLE (PLACEABLE_ALTAR on the altar footprint). M2b puts the gatherables in VEGETATION (the
## thing growing or lying on a tile that F picks: 1 + its index in WorldItems.GATHERABLES, 0 =
## none; items/world_items.gd). WALL and ORE stay 0 until the features that use them exist.
##
## Drops (M2b): items lying on the ground are not tiles but a list (`drops`, by id): item, count,
## grade and a pixel position. They are part of the world like the layers: the content hash covers
## them, the late-join snapshot carries them and edits add, change and remove them (net/edit_log.gd).
##
## M3a: a game holds one WorldData per map (`map_id`: Config.MAP_SURFACE, MAP_DUNGEON). The dungeon
## uses WALL (kind + hits taken) and ORE (world/walls.gd); its FLOOR layer is unused (0). PLACEABLE
## gains the dungeon entrance (surface), a placed torch, the exit stairs, the heretic shrine and the
## decorative wall torches. The map id is not part of the content hash (each map has its own data).
##
## M5b: purified corruption is FLOOR grass + CORRUPTION 0 (items/purify.gd). The altar can move (items/altar_move.gd):
## picking it up and putting it down are PLACEABLE cell edits, and altar_rect follows them (refresh_altar_rect, called by
## EditLog.apply_to_data): empty while the altar is carried.
##
## M7-rf (the human's decision of 2026-10-26; ● gameplay-design §3.1 "바닥 / 벽 / ...", ● §3.3 R37 "건설 벽은 바닥 위 별도 층"):
## FLOOR_PIECE is the built half of §3.1's floor layer: a laid floor piece (FLOOR_PIECE_STONE; 0 = none) on a tile, under
## whatever stands there (a built wall, a door, a lantern, a station, the altar). It is a byte of its own so the FLOOR byte
## stays the ground's dual-grid terrain (grass / soil / ash: the corner keys, the ground view, the fields, purification,
## corruption and the snapshot's terrain check read it as before). M7b kept the floor piece in the WALL byte (Walls kind 6,
## retired), so a tile held a wall or a floor piece, never both. Edits on it are ordinary cell edits (net/edit_log.gd), the
## snapshot carries it like the other layers (net/world_snapshot.gd); the content hash covers it only when it holds a piece
## (content_hash: a world without floor pieces hashes as before, so the generators' golden hashes stay).

enum Layer { FLOOR, WALL, ORE, VEGETATION, CORRUPTION, PLACEABLE, FLOOR_PIECE }

const LAYER_COUNT: int = 7
const LAYER_NAMES: PackedStringArray = ["floor", "wall", "ore", "vegetation", "corruption", "placeable", "floor_piece"]
## M7-rf: the layers the content hash always covers (M1-M7's six: its header counts them); FLOOR_PIECE only when it holds a
## piece (content_hash).
const HASH_LAYERS: int = 6
## M7-rf: FLOOR_PIECE values (the slice's material is stone only, ● §3.3 R37).
const FLOOR_PIECE_NONE: int = 0
const FLOOR_PIECE_STONE: int = 1
const FLOOR_PIECE_NAMES: PackedStringArray = ["none", "stone"]
const OUTSIDE_TERRAIN: int = Terrain.GRASS
const PLACEABLE_NONE: int = 0
const PLACEABLE_ALTAR: int = 1
## M3a: the surface's way down (footprint Config.ENTRANCE_FOOTPRINT), a torch a player placed, the
## dungeon's way up (Config.EXIT_FOOTPRINT, on wall face tiles), the heretic shrine (Config.
## SHRINE_FOOTPRINT, fire off), a decorative wall torch (on a wall tile with a face).
const PLACEABLE_ENTRANCE: int = 2
const PLACEABLE_TORCH: int = 3
const PLACEABLE_EXIT: int = 4
const PLACEABLE_SHRINE: int = 5
const PLACEABLE_WALL_TORCH: int = 6
## M4a: a death bag lies on this tile (its contents are the drops on the tile; F takes them all; it does
## not block), and the heretic shrine once broken by combat (Config.SHRINE_HP; it still blocks).
const PLACEABLE_BAG: int = 7
const PLACEABLE_SHRINE_BROKEN: int = 8
## M6a: the alchemy table (Config.ALCHEMY_FOOTPRINT, a crafting station, items/crafting.gd; it blocks).
const PLACEABLE_ALCHEMY: int = 9
## M7a: the workbench chain's stations (Config.WORKBENCH_FOOTPRINT, ANVIL_FOOTPRINT, RELIC_BENCH_FOOTPRINT; items/crafting.gd)
## and the storage chest (Config.CHEST_FOOTPRINT, items/storage.gd: its contents are `chests`). All block.
const PLACEABLE_WORKBENCH: int = 10
const PLACEABLE_ANVIL: int = 11
const PLACEABLE_RELIC: int = 12
const PLACEABLE_CHEST: int = 13
## M7b: a tree (the trunk's one tile; SurfaceGen step 6, world/forest.gd), the stump a felled tree leaves (it grows back,
## Config.TREE_REGROW_TICKS) and a built lantern post (the light piece of building, items/building.gd). All three block.
const PLACEABLE_TREE: int = 14
const PLACEABLE_STUMP: int = 15
const PLACEABLE_LANTERN: int = 16
const PLACEABLE_NAMES: PackedStringArray = ["none", "altar", "entrance", "torch", "exit", "shrine", "wall_torch", "bag",
	"shrine_broken", "alchemy", "workbench", "anvil", "relic_bench", "chest", "tree", "stump", "lantern"]

var size: Vector2i = Vector2i.ZERO
var world_seed: int = 0
## Which map this is (M3a). Not in the content hash or the snapshot.
var map_id: int = Config.MAP_SURFACE
## Altar footprint in cells (PLACEABLE_ALTAR cells). Empty rect = no altar.
var altar_rect: Rect2i = Rect2i()
var layers: Array[PackedByteArray] = []
## Items on the ground by id (M2b).
var drops: Dictionary[int, Drop] = {}
## Next id new_drop_id() hands out (not part of the world's content: only the host makes drops).
var drop_serial: int = 1
## M7a: what each storage chest holds, by its footprint's top-left tile (items/storage.gd). A chest without an entry is
## empty. The world's, not a player's (○ gameplay-design §5 "공유 창고"): the content hash covers the chests that hold
## something (none on a generated map, so the golden hashes stay). M7c: the late-join snapshot carries them and a chest
## slot edit changes one slot (net/edit_log.gd), so a session's clients hold the host's chests.
var chests: Dictionary[Vector2i, Chest] = {}


## M7a: one storage chest's slots (Config.CHEST_SLOTS; null = empty). Stacks keep their durability.
class Chest:
	extends RefCounted
	var slots: Array[ItemStack] = []

	func _init(n: int = Config.CHEST_SLOTS) -> void:
		slots.resize(maxi(n, 1))

	func is_empty() -> bool:
		for st: ItemStack in slots:
			if st != null:
				return false
		return true

	func describe() -> String:
		var parts: PackedStringArray = []
		for i: int in slots.size():
			if slots[i] != null:
				parts.append("%d:%s" % [i, str(slots[i])])
		return ", ".join(parts)


## An item lying on the ground (M2b, debug drop). Whoever picks it up first gets it
## (PROVISIONAL, ○ gameplay-design §5 "드롭은 주운 사람 것").
class Drop:
	extends RefCounted
	var id: int = 0
	var item: StringName = &""
	var count: int = 0
	var grade: int = 0
	## World px (whole pixels): the centre of the tile it was dropped on.
	var pos: Vector2i = Vector2i.ZERO

	func _init(p_id: int = 0, p_item: StringName = &"", p_count: int = 0, p_grade: int = 0,
			p_pos: Vector2i = Vector2i.ZERO) -> void:
		id = p_id
		item = p_item
		count = p_count
		grade = p_grade
		pos = p_pos

	## The tile it lies on.
	func cell() -> Vector2i:
		return Vector2i(floori(pos.x / float(Config.TILE)), floori(pos.y / float(Config.TILE)))

	func copy() -> Drop:
		return Drop.new(id, item, count, grade, pos)

	func same_as(o: Drop) -> bool:
		return o != null and id == o.id and item == o.item and count == o.count and grade == o.grade and pos == o.pos

	func describe() -> String:
		return "drop %d %s x%d g%d at %d,%d" % [id, item, count, grade, pos.x, pos.y]


## Bytes per drop in drops_bytes(): u32 id, u8 item index, u8 count, u8 grade, u16 x, u16 y.
const DROP_BYTES: int = 11


func _init(p_size: Vector2i = Vector2i.ZERO) -> void:
	size = p_size
	layers.clear()
	for i: int in LAYER_COUNT:
		var grid: PackedByteArray = PackedByteArray()
		grid.resize(size.x * size.y)
		grid.fill(0)
		layers.append(grid)
	layers[Layer.FLOOR].fill(OUTSIDE_TERRAIN)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func index_of(c: Vector2i) -> int:
	return c.y * size.x + c.x


## Layer value at a cell (0 outside the map; floor reads OUTSIDE_TERRAIN outside).
func get_value(layer: int, c: Vector2i) -> int:
	if not in_bounds(c):
		return OUTSIDE_TERRAIN if layer == Layer.FLOOR else 0
	return layers[layer][index_of(c)]


## Raw write without rules. Returns true if the value changed.
func set_value(layer: int, c: Vector2i, value: int) -> bool:
	if not in_bounds(c):
		return false
	var i: int = index_of(c)
	if layers[layer][i] == value:
		return false
	layers[layer][i] = value
	return true


## Floor terrain at vertex v (= world cell v).
func terrain_at(v: Vector2i) -> int:
	if v.x < 0 or v.y < 0 or v.x >= size.x or v.y >= size.y:
		return OUTSIDE_TERRAIN
	return layers[Layer.FLOOR][v.y * size.x + v.x]


## Corner key of display cell d (corners = vertices d, d+(1,0), d+(0,1), d+(1,1)).
func key_at_display(d: Vector2i) -> int:
	if d.x >= 0 and d.y >= 0 and d.x + 1 < size.x and d.y + 1 < size.y:
		var floor_grid: PackedByteArray = layers[Layer.FLOOR]
		var i: int = d.y * size.x + d.x
		return floor_grid[i] + 3 * floor_grid[i + 1] + 9 * floor_grid[i + size.x] + 27 * floor_grid[i + size.x + 1]
	return Terrain.key_of(terrain_at(d), terrain_at(d + Vector2i(1, 0)), terrain_at(d + Vector2i(0, 1)),
		terrain_at(d + Vector2i(1, 1)))


## Whether vertex v may become `terrain` (inside the map, and no soil next to ash: the 8
## neighbouring vertices share a display cell with v).
func can_set_terrain(v: Vector2i, terrain: int) -> bool:
	if not in_bounds(v) or terrain < 0 or terrain >= Terrain.COUNT:
		return false
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			if (ox != 0 or oy != 0) and not Terrain.can_touch(terrain, terrain_at(v + Vector2i(ox, oy))):
				return false
	return true


## Sets the floor terrain at vertex v if allowed. Returns true if the value changed.
func set_terrain(v: Vector2i, terrain: int) -> bool:
	if not can_set_terrain(v, terrain):
		return false
	return set_value(Layer.FLOOR, v, terrain)


func count_value(layer: int, value: int) -> int:
	return layers[layer].count(value)


## M7-rf: whether a floor piece is laid on tile `c` (FLOOR_PIECE; none outside the map).
func has_floor_piece(c: Vector2i) -> bool:
	return get_value(Layer.FLOOR_PIECE, c) != FLOOR_PIECE_NONE


## M7-rf: how many tiles hold a floor piece.
func floor_piece_count() -> int:
	return layers[Layer.FLOOR_PIECE].size() - layers[Layer.FLOOR_PIECE].count(FLOOR_PIECE_NONE)


## M7-rf: whether `v` is a FLOOR_PIECE value (the snapshot refuses any other).
static func valid_floor_piece(v: int) -> bool:
	return v >= FLOOR_PIECE_NONE and v < FLOOR_PIECE_NAMES.size()


## Display cells whose corners mix soil and ash (no art). 0 on a valid surface.
func soil_ash_contacts() -> int:
	var n: int = 0
	for dy: int in range(-1, size.y):
		for dx: int in range(-1, size.x):
			if not Terrain.key_has_art(key_at_display(Vector2i(dx, dy))):
				n += 1
	return n


## Whether placeable value `p` blocks walking (M3a: everything but a torch; a wall torch sits on a
## wall, which blocks anyway). PROVISIONAL for the torch (Config "torch ... does not block"). M4a: a
## death bag does not block; the broken shrine does (PROVISIONAL, README "임시값" M4a). M6a: the alchemy table
## blocks, like the other fixtures; M7a: so do the three stations and the storage chest. M7b: the tree's trunk and the
## lantern post block; the stump while Config.TREE_STUMP_BLOCKS (PROVISIONAL).
static func placeable_blocks(p: int) -> bool:
	if p == PLACEABLE_STUMP:
		return Config.TREE_STUMP_BLOCKS
	return p != PLACEABLE_NONE and p != PLACEABLE_TORCH and p != PLACEABLE_WALL_TORCH and p != PLACEABLE_BAG


## The footprint (cells) of the placeable covering tile `c`: the rectangle of equal values that
## contains it (an empty rect when `c` has none). Placeables of one kind never touch each other.
func footprint_at(c: Vector2i) -> Rect2i:
	var p: int = get_value(Layer.PLACEABLE, c)
	if p == PLACEABLE_NONE:
		return Rect2i()
	var lo: Vector2i = c
	while get_value(Layer.PLACEABLE, lo + Vector2i(-1, 0)) == p:
		lo.x -= 1
	while get_value(Layer.PLACEABLE, lo + Vector2i(0, -1)) == p:
		lo.y -= 1
	var hi: Vector2i = lo
	while get_value(Layer.PLACEABLE, hi + Vector2i(1, 0)) == p:
		hi.x += 1
	while get_value(Layer.PLACEABLE, hi + Vector2i(0, 1)) == p:
		hi.y += 1
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Every footprint of placeable value `p`, by its top-left cell, row by row.
func footprints(p: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var grid: PackedByteArray = layers[Layer.PLACEABLE]
	for i: int in grid.size():
		if grid[i] != p:
			continue
		var c: Vector2i = Vector2i(i % size.x, i / size.x)
		if get_value(Layer.PLACEABLE, c + Vector2i(-1, 0)) == p or get_value(Layer.PLACEABLE, c + Vector2i(0, -1)) == p:
			continue
		out.append(footprint_at(c))
	return out


## Fills footprint `rect` with placeable `p`.
func put_placeable(rect: Rect2i, p: int) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			set_value(Layer.PLACEABLE, Vector2i(x, y), p)


func altar_center_px() -> Vector2:
	return (Vector2(altar_rect.position) + Vector2(altar_rect.size) / 2.0) * Config.TILE


## M5b: the altar's footprint read back from the PLACEABLE layer (picking the altar up and putting it down are cell
## edits, items/altar_move.gd): the rectangle of PLACEABLE_ALTAR cells when they form one whole Config.ALTAR_FOOTPRINT,
## else empty (no altar: carried, or half way through the edits that move it). Returns whether altar_rect changed.
func refresh_altar_rect() -> bool:
	var was: Rect2i = altar_rect
	var grid: PackedByteArray = layers[Layer.PLACEABLE]
	var first: int = grid.find(PLACEABLE_ALTAR)
	altar_rect = Rect2i()
	if first >= 0:
		var r: Rect2i = footprint_at(Vector2i(first % size.x, first / size.x))
		if r.size == Config.ALTAR_FOOTPRINT and grid.count(PLACEABLE_ALTAR) == r.size.x * r.size.y:
			altar_rect = r
	return altar_rect != was


## md5 of the size, seed, altar, every layer and the drops. Equal hashes = equal worlds.
## M7-rf: the header counts HASH_LAYERS (M1-M7's six layers, hashed as before); the floor pieces (FLOOR_PIECE) come last, after
## a tag of their own (the layer's index and how many tiles hold one), and only when a tile holds one, like M7a's chests: a
## world without floor pieces (every generated one) hashes as before, so SurfaceGen.GOLDEN_HASH, DungeonGen.GOLDEN_HASH /
## SEEDS_GOLDEN and the smoke's hashes stay.
func content_hash() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var header: PackedInt64Array = PackedInt64Array([size.x, size.y, world_seed, altar_rect.position.x,
		altar_rect.position.y, altar_rect.size.x, altar_rect.size.y, HASH_LAYERS])
	ctx.update(header.to_byte_array())
	for i: int in HASH_LAYERS:
		ctx.update(layers[i])
	ctx.update(drops_bytes())
	var held: PackedByteArray = chests_bytes()
	if not held.is_empty():
		ctx.update(held)  # M7a: only when a chest holds something (a world without one hashes as before)
	var floors: int = floor_piece_count()
	if floors > 0:
		ctx.update(PackedInt64Array([Layer.FLOOR_PIECE, floors]).to_byte_array())
		ctx.update(layers[Layer.FLOOR_PIECE])
	return ctx.finish().hex_encode()


# --- storage chests (M7a) ----------------------------------------------------------------------

## The chest whose footprint holds tile `c` (made empty the first time), or null when `c` is no chest tile.
func chest_at(c: Vector2i) -> Chest:
	if get_value(Layer.PLACEABLE, c) != PLACEABLE_CHEST:
		return null
	var key: Vector2i = footprint_at(c).position
	if not chests.has(key):
		chests[key] = Chest.new()
	return chests[key]


## M7c: the keys (footprint top-left tiles) of the chests that hold something, row by row.
func held_chests() -> Array[Vector2i]:
	var keys: Array[Vector2i] = []
	for k: Vector2i in chests:
		if not chests[k].is_empty():
			keys.append(k)
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return keys


## Every chest that holds something, by its key row by row: u16 x, u16 y, then per slot u8 item index + 1 (0 = empty),
## u8 count, u8 grade, u16 durability (EditLog.write_stack's form). Empty when no chest holds anything. M7c: the snapshot
## carries these after a u16 count (net/world_snapshot.gd).
func chests_bytes() -> PackedByteArray:
	var keys: Array[Vector2i] = held_chests()
	var out: PackedByteArray = PackedByteArray()
	if keys.is_empty():
		return out
	for k: Vector2i in keys:
		var at: int = out.size()
		var slots: Array[ItemStack] = chests[k].slots
		out.resize(at + 4 + 5 * slots.size())
		out.encode_u16(at, k.x)
		out.encode_u16(at + 2, k.y)
		for i: int in slots.size():
			var st: ItemStack = slots[i]
			var o: int = at + 4 + 5 * i
			if st == null:
				continue
			out.encode_u8(o, ItemDB.index_of(st.id) + 1)
			out.encode_u8(o + 1, st.count)
			out.encode_u8(o + 2, st.grade)
			out.encode_u16(o + 3, maxi(st.durability, 0))
	return out


# --- drops (M2b) -----------------------------------------------------------------------------

## Drop ids in ascending order.
func drop_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(drops.keys())
	ids.sort()
	return ids


## A new drop id (larger than any drop's).
func new_drop_id() -> int:
	for id: int in drops:
		drop_serial = maxi(drop_serial, id + 1)
	drop_serial += 1
	return drop_serial - 1


## Drops lying on tile `c`, lowest id first.
func drops_at(c: Vector2i) -> Array[Drop]:
	var out: Array[Drop] = []
	for id: int in drop_ids():
		if drops[id].cell() == c:
			out.append(drops[id])
	return out


## Every drop as bytes, by id: u16 count, then DROP_BYTES per drop (the snapshot and the content
## hash use it).
func drops_bytes() -> PackedByteArray:
	var ids: Array[int] = drop_ids()
	var out: PackedByteArray = PackedByteArray()
	out.resize(2 + DROP_BYTES * ids.size())
	out.encode_u16(0, ids.size())
	for i: int in ids.size():
		write_drop(out, 2 + DROP_BYTES * i, drops[ids[i]])
	return out


static func write_drop(out: PackedByteArray, at: int, d: Drop) -> void:
	out.encode_u32(at, d.id)
	out.encode_u8(at + 4, maxi(ItemDB.index_of(d.item), 0))
	out.encode_u8(at + 5, d.count)
	out.encode_u8(at + 6, d.grade)
	out.encode_u16(at + 7, d.pos.x)
	out.encode_u16(at + 9, d.pos.y)


## The drop at `at`, or null when it is not a valid one in a world of `world_size` cells (unknown
## item, count outside 1..stack size, a grade the item cannot have, outside the map).
static func read_drop(bytes: PackedByteArray, at: int, world_size: Vector2i) -> Drop:
	if at < 0 or bytes.size() < at + DROP_BYTES:
		return null
	var d: Drop = Drop.new(bytes.decode_u32(at), ItemDB.id_at(bytes.decode_u8(at + 4)), bytes.decode_u8(at + 5),
		bytes.decode_u8(at + 6), Vector2i(bytes.decode_u16(at + 7), bytes.decode_u16(at + 9)))
	if not valid_drop(d, world_size):
		return null
	return d


static func valid_drop(d: Drop, world_size: Vector2i) -> bool:
	var def: ItemDB.ItemDef = ItemDB.get_def(d.item)
	if def == null or d.count < 1 or d.count > def.stack_max or not ItemDB.valid_grade(d.item, d.grade):
		return false
	return d.pos.x >= 0 and d.pos.y >= 0 and d.pos.x < world_size.x * Config.TILE and d.pos.y < world_size.y * Config.TILE
