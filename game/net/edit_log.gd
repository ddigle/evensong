class_name EditLog
extends RefCounted
## The world's edit log: every change the host made to the world, in order, numbered from 0. The
## host keeps all of them. A late joiner gets the world itself (net/world_snapshot.gd) plus the log
## position the snapshot was taken at (`base`); edits from that index on reach it as single edit
## messages, in order (the index tells it whether one is missing).
##
## An edit is absolute ("cell = value", not "toggle"), so applying it twice changes nothing.
## M1 has no gameplay edits; the only source is the host's debug edit (bot command "edit", floor
## grass <-> soil, i.e. tilling). Edit message: u32 index, then u8 layer, u16 x, u16 y, u8 value.

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


static func _write_edit(out: PackedByteArray, at: int, edit: WorldEdit) -> void:
	out.encode_u8(at, edit.layer)
	out.encode_u16(at + 1, edit.cell.x)
	out.encode_u16(at + 3, edit.cell.y)
	out.encode_u8(at + 5, edit.value)


static func _read_edit(bytes: PackedByteArray, at: int) -> WorldEdit:
	return WorldEdit.new(bytes.decode_u8(at), Vector2i(bytes.decode_u16(at + 1), bytes.decode_u16(at + 3)),
		bytes.decode_u8(at + 5))
