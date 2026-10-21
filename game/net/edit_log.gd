class_name EditLog
extends RefCounted
## The world's edit log: every change the host made to the generated world, in order. The world
## of a session = SurfaceGen.generate(seed) + this log, which is what a late joiner gets (spike
## RESULTS §5 used a full snapshot; M1 worlds are small and barely edited, so seed + log is
## smaller and checks generation too: the joiner compares its world hash with the host's).
##
## An edit is absolute ("cell = value", not "toggle"), so applying it twice changes nothing.
## M1 has no gameplay edits; the only source is the host's debug edit (bot command "edit", floor
## grass <-> soil, i.e. tilling). Encoding: u32 count, then count x (u8 layer, u16 x, u16 y, u8 value).

const HEADER_SIZE: int = 4
const EDIT_SIZE: int = 6
## Floor terrains the debug edit may write (no ash: corruption zones are fixed in M1, §12).
const EDITABLE_TERRAINS: PackedInt32Array = [Terrain.GRASS, Terrain.SOIL]


class WorldEdit:
	extends RefCounted
	var layer: int = WorldData.Layer.FLOOR
	var cell: Vector2i = Vector2i.ZERO
	var value: int = 0

	func _init(p_layer: int = WorldData.Layer.FLOOR, p_cell: Vector2i = Vector2i.ZERO, p_value: int = 0) -> void:
		layer = p_layer
		cell = p_cell
		value = p_value

	func describe() -> String:
		return "%s %d,%d=%d" % [WorldData.LAYER_NAMES[layer] if layer < WorldData.LAYER_COUNT else "?", cell.x, cell.y,
			value]


var edits: Array[WorldEdit] = []


func size() -> int:
	return edits.size()


func append(edit: WorldEdit) -> void:
	edits.append(edit)


## Host-side check before an edit is applied and logged: inside the map, a floor terrain the debug
## edit may write, allowed by the terrain rules (WorldData.can_set_terrain: no soil next to ash),
## and an actual change. Returns "" or the reason.
static func check(data: WorldData, edit: WorldEdit) -> String:
	if edit.layer != WorldData.Layer.FLOOR:
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
## not fit the data (bad layer or cell).
static func apply_to_data(data: WorldData, edit: WorldEdit) -> bool:
	if edit.layer < 0 or edit.layer >= WorldData.LAYER_COUNT or not data.in_bounds(edit.cell):
		return false
	data.set_value(edit.layer, edit.cell, edit.value)
	return true


func encode() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(HEADER_SIZE + EDIT_SIZE * edits.size())
	out.encode_u32(0, edits.size())
	for i: int in edits.size():
		_write_edit(out, HEADER_SIZE + EDIT_SIZE * i, edits[i])
	return out


static func encode_one(edit: WorldEdit, index: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(HEADER_SIZE + EDIT_SIZE)
	out.encode_u32(0, index)
	_write_edit(out, HEADER_SIZE, edit)
	return out


## (index, edit) from encode_one(), or index -1 when malformed.
static func decode_one(bytes: PackedByteArray) -> Array:
	if bytes.size() != HEADER_SIZE + EDIT_SIZE:
		return [-1, null]
	return [bytes.decode_u32(0), _read_edit(bytes, HEADER_SIZE)]


## Bytes an encoded log starting at `at` takes, or -1 if `bytes` is too short for it.
static func encoded_size(bytes: PackedByteArray, at: int) -> int:
	if bytes.size() < at + HEADER_SIZE:
		return -1
	var count: int = bytes.decode_u32(at)
	var total: int = HEADER_SIZE + EDIT_SIZE * count
	if count > 1 << 20 or bytes.size() < at + total:
		return -1
	return total


## Log from encode(), or null when malformed.
static func decode(bytes: PackedByteArray) -> EditLog:
	if encoded_size(bytes, 0) != bytes.size():
		return null
	var log: EditLog = EditLog.new()
	var count: int = bytes.decode_u32(0)
	for i: int in count:
		log.edits.append(_read_edit(bytes, HEADER_SIZE + EDIT_SIZE * i))
	return log


static func _write_edit(out: PackedByteArray, at: int, edit: WorldEdit) -> void:
	out.encode_u8(at, edit.layer)
	out.encode_u16(at + 1, edit.cell.x)
	out.encode_u16(at + 3, edit.cell.y)
	out.encode_u8(at + 5, edit.value)


static func _read_edit(bytes: PackedByteArray, at: int) -> WorldEdit:
	return WorldEdit.new(bytes.decode_u8(at), Vector2i(bytes.decode_u16(at + 1), bytes.decode_u16(at + 3)),
		bytes.decode_u8(at + 5))
