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
## Edit message: u32 index, then u8 code:
##   0..5   cell edit on that layer: u16 x, u16 y, u8 value                         (10 B in all)
##   0x40   drop put: u32 id, u8 item index, u8 count, u8 grade, u16 x, u16 y (px)   (16 B)
##   0x41   drop removed: u32 id                                                     (9 B)

const HEADER_SIZE: int = 4
const EDIT_SIZE: int = 6
const CODE_DROP_PUT: int = 0x40
const CODE_DROP_REMOVE: int = 0x41
## Floor terrains the debug edit may write (no ash: corruption zones are fixed in M1, §12).
const EDITABLE_TERRAINS: PackedInt32Array = [Terrain.GRASS, Terrain.SOIL]

enum Kind { CELL, DROP_PUT, DROP_REMOVE }


class WorldEdit:
	extends RefCounted
	var kind: int = Kind.CELL
	var layer: int = WorldData.Layer.FLOOR
	var cell: Vector2i = Vector2i.ZERO
	var value: int = 0
	## DROP_PUT: the drop as it is now. DROP_REMOVE: drop_id only.
	var drop: WorldData.Drop
	var drop_id: int = 0

	func _init(p_layer: int = WorldData.Layer.FLOOR, p_cell: Vector2i = Vector2i.ZERO, p_value: int = 0) -> void:
		layer = p_layer
		cell = p_cell
		value = p_value

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
	if edit.layer < 0 or edit.layer >= WorldData.LAYER_COUNT or not data.in_bounds(edit.cell):
		return false
	data.set_value(edit.layer, edit.cell, edit.value)
	return true


static func encode_one(edit: WorldEdit, index: int) -> PackedByteArray:
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
		_:
			out.resize(HEADER_SIZE + EDIT_SIZE)
			_write_edit(out, HEADER_SIZE, edit)
	out.encode_u32(0, index)
	return out


## (index, edit) from encode_one(), or index -1 when malformed (wrong size for its code, a drop
## that is no valid item stack).
static func decode_one(bytes: PackedByteArray) -> Array:
	if bytes.size() < HEADER_SIZE + 1:
		return [-1, null]
	var code: int = bytes.decode_u8(HEADER_SIZE)
	if code == CODE_DROP_PUT:
		if bytes.size() != HEADER_SIZE + 1 + WorldData.DROP_BYTES:
			return [-1, null]
		# The map size is checked when the edit is applied (apply_to_data); here only the stack.
		var d: WorldData.Drop = WorldData.read_drop(bytes, HEADER_SIZE + 1, Vector2i(4096, 4096))
		if d == null:
			return [-1, null]
		return [bytes.decode_u32(0), WorldEdit.drop_put(d)]
	if code == CODE_DROP_REMOVE:
		if bytes.size() != HEADER_SIZE + 1 + 4:
			return [-1, null]
		return [bytes.decode_u32(0), WorldEdit.drop_remove(bytes.decode_u32(HEADER_SIZE + 1))]
	if bytes.size() != HEADER_SIZE + EDIT_SIZE:
		return [-1, null]
	return [bytes.decode_u32(0), _read_edit(bytes, HEADER_SIZE)]


static func _write_edit(out: PackedByteArray, at: int, edit: WorldEdit) -> void:
	out.encode_u8(at, edit.layer)
	out.encode_u16(at + 1, edit.cell.x)
	out.encode_u16(at + 3, edit.cell.y)
	out.encode_u8(at + 5, edit.value)


static func _read_edit(bytes: PackedByteArray, at: int) -> WorldEdit:
	return WorldEdit.new(bytes.decode_u8(at), Vector2i(bytes.decode_u16(at + 1), bytes.decode_u16(at + 3)),
		bytes.decode_u8(at + 5))
