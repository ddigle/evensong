class_name EditLog
extends RefCounted
## The world's edit log: every change the host made to the world, in order, numbered from 0. The
## host keeps all of them. A late joiner gets the world itself (net/world_snapshot.gd) plus the log
## position the snapshot was taken at (`base`); edits from that index on reach it as single edit
## messages, in order (the index tells it whether one is missing).
##
## An edit is absolute ("cell = value", "drop 7 = 3 stones at x, y", "drop 7 gone", never "toggle"),
## so applying it twice changes nothing. Sources: the host's debug floor edit (bot command "edit",
## grass <-> soil, M1) and, M2b, gameplay: a gatherable picked up (VEGETATION cell = 0) and drops put
## down, changed (picked in part) or removed (net/session_host.gd, items/world_items.gd).
## M3a/M3b: mining (WALL / ORE cells), torches (PLACEABLE cells) and their drops. M5a: tilling (FLOOR) and fields
## (VEGETATION). M5b (M5c: in sessions too, the host's): purification (CORRUPTION -> 0, FLOOR ash -> grass) and the altar picked up / put
## down (PLACEABLE altar cells; apply_to_data reads the altar's rect back, WorldData.refresh_altar_rect). Each map has its own
## log (NetSession.log_for): indices count per map, and a client gets the edits of the map it is on.
## M7c: building (WALL / PLACEABLE cells), doors (WALL cells), trees felled and grown back (PLACEABLE cells), stations (PLACEABLE
## cells) and the storage chest's slots: a chest slot edit sets one slot of the chest whose footprint starts at its tile
## ("chest 62,51 slot 3 = stone_a x40", absolute like the rest; WorldData.chests).
## Edit message: u32 index, u8 map (M3b), then u8 code:
##   0..5   cell edit on that layer: u16 x, u16 y, u8 value                         (11 B in all)
##   0x40   drop put: u32 id, u8 item index, u8 count, u8 grade, u16 x, u16 y (px)   (17 B)
##   0x41   drop removed: u32 id                                                     (10 B)
##   0x42   chest slot (M7c): u16 x, u16 y (the chest's top-left tile), u8 slot, u8 item index + 1 (0 = empty), u8 count,
##          u8 grade, u16 durability left                                            (16 B)

const HEADER_SIZE: int = 5
const EDIT_SIZE: int = 6
const CODE_DROP_PUT: int = 0x40
const CODE_DROP_REMOVE: int = 0x41
const CODE_CHEST: int = 0x42
## M7c: a chest slot edit's bytes after its code.
const CHEST_EDIT_SIZE: int = 10
## Floor terrains the debug edit may write (no ash: corruption zones are fixed in M1, §12).
const EDITABLE_TERRAINS: PackedInt32Array = [Terrain.GRASS, Terrain.SOIL]

enum Kind { CELL, DROP_PUT, DROP_REMOVE, CHEST }


class WorldEdit:
	extends RefCounted
	var kind: int = Kind.CELL
	var layer: int = WorldData.Layer.FLOOR
	var cell: Vector2i = Vector2i.ZERO
	var value: int = 0
	## DROP_PUT: the drop as it is now. DROP_REMOVE: drop_id only.
	var drop: WorldData.Drop
	var drop_id: int = 0
	## M7c, CHEST: the chest's top-left tile is `cell`, the slot `value`, what it holds now `stack` (null = empty).
	var stack: ItemStack

	func _init(p_layer: int = WorldData.Layer.FLOOR, p_cell: Vector2i = Vector2i.ZERO, p_value: int = 0) -> void:
		layer = p_layer
		cell = p_cell
		value = p_value

	## M7c: slot `slot` of the chest whose footprint starts at tile `key` holds `st` (a copy; null = empty).
	static func chest_slot(key: Vector2i, slot: int, st: ItemStack) -> WorldEdit:
		var e: WorldEdit = WorldEdit.new()
		e.kind = Kind.CHEST
		e.cell = key
		e.value = slot
		e.stack = st.copy() if st != null else null
		return e

	static func drop_put(d: WorldData.Drop) -> WorldEdit:
		var e: WorldEdit = WorldEdit.new()
		e.kind = Kind.DROP_PUT
		e.drop = d.copy()
		e.drop_id = d.id
		return e

	static func drop_remove(id: int) -> WorldEdit:
		var e: WorldEdit = WorldEdit.new()
		e.kind = Kind.DROP_REMOVE
		e.drop_id = id
		return e

	func describe() -> String:
		match kind:
			Kind.DROP_PUT:
				return "drop+ %d %s x%d g%d at %d,%d" % [drop.id, drop.item, drop.count, drop.grade, drop.pos.x, drop.pos.y]
			Kind.DROP_REMOVE:
				return "drop- %d" % drop_id
			Kind.CHEST:
				return "chest %d,%d[%d]=%s" % [cell.x, cell.y, value, str(stack).replace(" ", "_") if stack != null else "empty"]
		return "%s %d,%d=%d" % [WorldData.LAYER_NAMES[layer] if layer >= 0 and layer < WorldData.LAYER_COUNT else "?",
			cell.x, cell.y, value]


## Edits that were already in the world this log started from (a joiner's snapshot); 0 on the host.
var base: int = 0
## The edits from index `base` on.
var edits: Array[WorldEdit] = []


## Log position: how many edits the world contains (= the index of the next edit).
func size() -> int:
	return base + edits.size()


func append(edit: WorldEdit) -> void:
	edits.append(edit)


## Edit number `index` (base <= index < size()), or null.
func edit_at(index: int) -> WorldEdit:
	if index < base or index >= size():
		return null
	return edits[index - base]


## Host-side check before an edit is applied and logged: inside the map, a floor terrain the debug
## edit may write, allowed by the terrain rules (WorldData.can_set_terrain: no soil next to ash),
## and an actual change. Returns "" or the reason.
static func check(data: WorldData, edit: WorldEdit) -> String:
	if edit.kind != Kind.CELL or edit.layer != WorldData.Layer.FLOOR:
		return "only floor edits exist in M1"
	if not data.in_bounds(edit.cell):
		return "outside the map"
	if not EDITABLE_TERRAINS.has(edit.value):
		return "terrain %d is not editable" % edit.value
	if data.terrain_at(edit.cell) == Terrain.ASH:
		return "ash is a fixed corruption zone"
	if data.terrain_at(edit.cell) == edit.value:
		return "no change"
	if not data.can_set_terrain(edit.cell, edit.value):
		return "terrain rules (soil next to ash)"
	if edit.value != Terrain.SOIL and Farming.field_at(data, edit.cell) != null:
		return "a field lies there"  # M5a: a crop or wet soil stays on soil (no untilling)
	return ""


## Writes the edit into the data without rules (the host already checked it). False when it does
## not fit the data (bad layer or cell, a drop outside the map). Removing a drop that is not there
## is fine (absolute: afterwards it is not there).
static func apply_to_data(data: WorldData, edit: WorldEdit) -> bool:
	match edit.kind:
		Kind.DROP_PUT:
			if edit.drop == null or not WorldData.valid_drop(edit.drop, data.size):
				return false
			data.drops[edit.drop.id] = edit.drop.copy()
			return true
		Kind.DROP_REMOVE:
			data.drops.erase(edit.drop_id)
			return true
		Kind.CHEST:
			# M7c: a slot of a chest standing there (its footprint's top-left tile), a valid stack or nothing.
			if data.get_value(WorldData.Layer.PLACEABLE, edit.cell) != WorldData.PLACEABLE_CHEST \
					or data.footprint_at(edit.cell).position != edit.cell or edit.value < 0 or edit.value >= Config.CHEST_SLOTS \
					or not valid_stack(edit.stack):
				return false
			data.chest_at(edit.cell).slots[edit.value] = edit.stack.copy() if edit.stack != null else null
			return true
	if edit.layer < 0 or edit.layer >= WorldData.LAYER_COUNT or not data.in_bounds(edit.cell):
		return false
	var was: int = data.get_value(edit.layer, edit.cell)
	data.set_value(edit.layer, edit.cell, edit.value)
	if edit.layer == WorldData.Layer.PLACEABLE and (was == WorldData.PLACEABLE_ALTAR or edit.value == WorldData.PLACEABLE_ALTAR):
		data.refresh_altar_rect()  # M5b: the altar is picked up / put down with cell edits (items/altar_move.gd)
	return true


## Edit number `index` of map `map`'s log as a message.
static func encode_one(edit: WorldEdit, index: int, map: int = Config.MAP_SURFACE) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	match edit.kind:
		Kind.DROP_PUT:
			out.resize(HEADER_SIZE + 1 + WorldData.DROP_BYTES)
			out.encode_u8(HEADER_SIZE, CODE_DROP_PUT)
			WorldData.write_drop(out, HEADER_SIZE + 1, edit.drop)
		Kind.DROP_REMOVE:
			out.resize(HEADER_SIZE + 1 + 4)
			out.encode_u8(HEADER_SIZE, CODE_DROP_REMOVE)
			out.encode_u32(HEADER_SIZE + 1, edit.drop_id)
		Kind.CHEST:
			out.resize(HEADER_SIZE + 1 + CHEST_EDIT_SIZE)
			out.encode_u8(HEADER_SIZE, CODE_CHEST)
			out.encode_u16(HEADER_SIZE + 1, edit.cell.x)
			out.encode_u16(HEADER_SIZE + 3, edit.cell.y)
			out.encode_u8(HEADER_SIZE + 5, edit.value)
			write_stack(out, HEADER_SIZE + 6, edit.stack)
		_:
			out.resize(HEADER_SIZE + EDIT_SIZE)
			_write_edit(out, HEADER_SIZE, edit)
	out.encode_u32(0, index)
	out.encode_u8(4, map)
	return out


## (index, edit, map) from encode_one(), or index -1 when malformed (wrong size for its code, an
## unknown map, a drop that is no valid item stack).
static func decode_one(bytes: PackedByteArray) -> Array:
	if bytes.size() < HEADER_SIZE + 1:
		return [-1, null, -1]
	var map: int = bytes.decode_u8(4)
	if not NetProtocol.valid_map(map):
		return [-1, null, -1]
	var code: int = bytes.decode_u8(HEADER_SIZE)
	if code == CODE_DROP_PUT:
		if bytes.size() != HEADER_SIZE + 1 + WorldData.DROP_BYTES:
			return [-1, null, -1]
		# The map size is checked when the edit is applied (apply_to_data); here only the stack.
		var d: WorldData.Drop = WorldData.read_drop(bytes, HEADER_SIZE + 1, Vector2i(4096, 4096))
		if d == null:
			return [-1, null, -1]
		return [bytes.decode_u32(0), WorldEdit.drop_put(d), map]
	if code == CODE_DROP_REMOVE:
		if bytes.size() != HEADER_SIZE + 1 + 4:
			return [-1, null, -1]
		return [bytes.decode_u32(0), WorldEdit.drop_remove(bytes.decode_u32(HEADER_SIZE + 1)), map]
	if code == CODE_CHEST:
		# M7c: a chest slot (the chest's tile is checked when the edit is applied, apply_to_data).
		if bytes.size() != HEADER_SIZE + 1 + CHEST_EDIT_SIZE:
			return [-1, null, -1]
		var slot: int = bytes.decode_u8(HEADER_SIZE + 5)
		var got: Array = read_stack(bytes, HEADER_SIZE + 6)
		if slot >= Config.CHEST_SLOTS or not got[1]:
			return [-1, null, -1]
		var st: ItemStack = got[0]
		return [bytes.decode_u32(0), WorldEdit.chest_slot(Vector2i(bytes.decode_u16(HEADER_SIZE + 1),
			bytes.decode_u16(HEADER_SIZE + 3)), slot, st), map]
	if bytes.size() != HEADER_SIZE + EDIT_SIZE:
		return [-1, null, -1]
	return [bytes.decode_u32(0), _read_edit(bytes, HEADER_SIZE), map]


## M7c: the bytes of one chest slot (also the snapshot's, net/world_snapshot.gd).
const STACK_BYTES: int = 5


## M7c: a chest slot's stack at `at` (STACK_BYTES): u8 item index + 1 (0 = empty), u8 count, u8 grade, u16 durability left.
static func write_stack(out: PackedByteArray, at: int, st: ItemStack) -> void:
	if st == null:
		for i: int in STACK_BYTES:
			out.encode_u8(at + i, 0)
		return
	out.encode_u8(at, ItemDB.index_of(st.id) + 1)
	out.encode_u8(at + 1, st.count)
	out.encode_u8(at + 2, st.grade)
	out.encode_u16(at + 3, maxi(st.durability, 0))


## M7c: [the stack at `at` (null = empty), whether it is a valid one] (write_stack's form; valid_stack's rules).
static func read_stack(bytes: PackedByteArray, at: int) -> Array:
	if at < 0 or bytes.size() < at + STACK_BYTES:
		return [null, false]
	var item: int = bytes.decode_u8(at)
	var count: int = bytes.decode_u8(at + 1)
	var grade: int = bytes.decode_u8(at + 2)
	var left: int = bytes.decode_u16(at + 3)
	if item == 0:
		return [null, count == 0 and grade == 0 and left == 0]
	var id: StringName = ItemDB.id_at(item - 1)
	var def: ItemDB.ItemDef = ItemDB.get_def(id)
	if def == null or left > def.durability:
		return [null, false]
	var st: ItemStack = ItemStack.new(id, count, grade, left)
	return [st, valid_stack(st)]


## M7c: whether `st` may lie in a chest slot (null = an empty slot): a known item, a count within its stack size, a grade
## it can have, durability within its full value.
static func valid_stack(st: ItemStack) -> bool:
	if st == null:
		return true
	var def: ItemDB.ItemDef = ItemDB.get_def(st.id)
	return def != null and st.count >= 1 and st.count <= def.stack_max and ItemDB.valid_grade(st.id, st.grade) \
		and st.durability >= 0 and st.durability <= def.durability


static func _write_edit(out: PackedByteArray, at: int, edit: WorldEdit) -> void:
	out.encode_u8(at, edit.layer)
	out.encode_u16(at + 1, edit.cell.x)
	out.encode_u16(at + 3, edit.cell.y)
	out.encode_u8(at + 5, edit.value)


static func _read_edit(bytes: PackedByteArray, at: int) -> WorldEdit:
	return WorldEdit.new(bytes.decode_u8(at), Vector2i(bytes.decode_u16(at + 1), bytes.decode_u16(at + 3)),
		bytes.decode_u8(at + 5))
