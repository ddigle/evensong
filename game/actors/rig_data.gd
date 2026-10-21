class_name RigData
extends RefCounted
## Tables for the layered character (actors/character.gd). Constants and pure functions only.
##
## Art (copied byte-identical from assets/concept/03-pixel, README "그림 출처"):
## - base_body_v02_walk.png (6 frames) and base_body_v02_idle.png (4 frames): 32x32 cells, rows
##   south / east / north, feet on frame row y=31 (● R26). West = east mirrored (● R19).
## - sig_*.png: one signature layer per class (● R21), drawn on walk v01 frame 0. v02 moved the
##   body down to put the feet on y=31 (walk S+4 E+3 N+4, idle S+5 E+2 N+3, 03-pixel/prompts.md
##   "발 맞춤"), so a layer moves down by the same shift, plus the per-frame torso or head anchor
##   (● R27, actors/rig_anchors.gd, measured by tools/build_rig_anchors.gd).
##
## Layer position in frame coordinates (0..31, y down) for animation `anim`, sheet row, frame:
##   pos_v01 + (0, SHIFT[anim][row]) + anchor(anim, torso|head, row, frame) + (0, bob)  [layer_frame_pos]

enum Dir { SOUTH, EAST, NORTH, WEST }
enum Anim { WALK, IDLE }

const DIR_NAMES: PackedStringArray = ["south", "east", "north", "west"]
const ANIM_NAMES: PackedStringArray = ["walk", "idle"]
## Sheet rows (south, east, north); west uses the east row mirrored.
const ROWS: int = 3

const WALK_SHEET: Texture2D = preload("res://art/chars/base_body_v02_walk.png")
const IDLE_SHEET: Texture2D = preload("res://art/chars/base_body_v02_idle.png")
const SHEET_PATHS: PackedStringArray = ["res://art/chars/base_body_v02_walk.png", "res://art/chars/base_body_v02_idle.png"]
const FRAME_COUNTS: PackedInt32Array = [6, 4]
## Character origin (between the feet) inside a frame: bottom edge, horizontally centred. Sprites
## sit at -FRAME_ORIGIN, so the node position is the feet and y-sort sorts by the feet.
const FRAME_ORIGIN: Vector2i = Vector2i(16, 32)

## v01 -> v02 re-pivot per animation and sheet row (03-pixel/prompts.md "발 맞춤", R25-R26).
const SHIFT: Array[Array] = [[4, 3, 4], [5, 2, 3]]

## Anchor bands in v01 frame rows and search radius (brief §5.6 R27: torso +/-4 px, head +/-8 px,
## most colour-matching pixels against walk frame 0). Tolerance = sum of RGB differences.
const TORSO_BAND: Vector2i = Vector2i(13, 22)
const HEAD_BAND: Vector2i = Vector2i(0, 11)
const TORSO_RADIUS: int = 4
const HEAD_RADIUS: int = 8
const ANCHOR_TOLERANCE: int = 60

## Layer slots. Back = carried on the back (pickaxe, bow), arm = strapped to the arm (shield),
## waist = at the hip (pouch), float = floating outside the frame (halo).
const SLOT_BODY: StringName = &"body"
const SLOT_BACK: StringName = &"back"
const SLOT_ARM: StringName = &"arm"
const SLOT_WAIST: StringName = &"waist"
const SLOT_FLOAT: StringName = &"float"
const SLOTS: Array[StringName] = [SLOT_BACK, SLOT_ARM, SLOT_WAIST, SLOT_FLOAT]

## Draw order per sheet row, first = furthest back (brief §5.6: back gear behind the body facing
## south / east, in front facing north; shield, pouch and halo in front). West uses the east order
## on the mirrored image, so a back item stays behind the body.
const DRAW_ORDER: Array[Array] = [
	[SLOT_BACK, SLOT_BODY, SLOT_ARM, SLOT_WAIST, SLOT_FLOAT],
	[SLOT_BACK, SLOT_BODY, SLOT_ARM, SLOT_WAIST, SLOT_FLOAT],
	[SLOT_BODY, SLOT_BACK, SLOT_ARM, SLOT_WAIST, SLOT_FLOAT],
]

## Sheet layouts of signature layers.
const LAYOUT_COLUMNS: StringName = &"columns"    # 3 cells in a row: south, east, north
const LAYOUT_ROW_FIRST: StringName = &"row_first" # rows south, east, north; first cell of each row
const LAYOUT_SINGLE: StringName = &"single"      # one image for every direction

const ANCHOR_TORSO: StringName = &"torso"
const ANCHOR_HEAD: StringName = &"head"

## Floating layers bob up 1 px on walk frames 2-4 (03-pixel/prompts.md 5차, halo). Idle: no bob.
const FLOAT_BOB: Array[Array] = [[0, 0, -1, -1, -1, 0], [0, 0, 0, 0]]


## One class's signature layer.
class Signature:
	extends RefCounted
	var id: StringName
	var slot: StringName
	var texture: Texture2D
	var path: String
	var layout: StringName
	var anchor: StringName
	## Top-left of the layer image in v01 walk-frame-0 coordinates (cell sheets: (0, 0)).
	var pos_v01: Vector2i

	func _init(p_id: StringName, p_slot: StringName, p_path: String, p_layout: StringName, p_anchor: StringName,
			p_pos: Vector2i = Vector2i.ZERO) -> void:
		id = p_id
		slot = p_slot
		path = p_path
		texture = load(p_path) as Texture2D
		layout = p_layout
		anchor = p_anchor
		pos_v01 = p_pos

	## Source rect in the sheet for a sheet row.
	func source_rect(row: int) -> Rect2i:
		match layout:
			LAYOUT_COLUMNS:
				return Rect2i(Vector2i(row * Config.CHAR_FRAME.x, 0), Config.CHAR_FRAME)
			LAYOUT_ROW_FIRST:
				return Rect2i(Vector2i(0, row * Config.CHAR_FRAME.y), Config.CHAR_FRAME)
		return Rect2i(Vector2i.ZERO, Vector2i(texture.get_size()))

	func floats() -> bool:
		return slot == SLOT_FLOAT


static var _signatures: Dictionary[String, Signature] = {}


## Class -> signature layer (● R21, brief §5.6). The shield sheet holds per-frame cuts of walk
## south/east, but a hard part is one image per direction on anchors (● R27), so the first cell
## of each row is used (the same cell the R27 action test used).
static func signature_for(class_id: String) -> Signature:
	if _signatures.is_empty():
		_signatures["paladin"] = Signature.new(&"shield", SLOT_ARM, "res://art/chars/sig_paladin_shield_v01.png",
			LAYOUT_ROW_FIRST, ANCHOR_TORSO)
		_signatures["miner"] = Signature.new(&"pickaxe", SLOT_BACK, "res://art/chars/sig_miner_pickaxe_v01.png",
			LAYOUT_COLUMNS, ANCHOR_TORSO)
		_signatures["archer"] = Signature.new(&"bow", SLOT_BACK, "res://art/chars/sig_archer_bow_v01.png",
			LAYOUT_COLUMNS, ANCHOR_TORSO)
		_signatures["cleric"] = Signature.new(&"halo", SLOT_FLOAT, "res://art/chars/sig_cleric_halo_v01.png",
			LAYOUT_SINGLE, ANCHOR_HEAD, Vector2i(10, -5))
		_signatures["herbalist"] = Signature.new(&"pouch", SLOT_WAIST, "res://art/chars/sig_herbalist_pouch_v02.png",
			LAYOUT_COLUMNS, ANCHOR_TORSO)
	return _signatures.get(class_id, null)


static func sheet(anim: int) -> Texture2D:
	return IDLE_SHEET if anim == Anim.IDLE else WALK_SHEET


static func frame_count(anim: int) -> int:
	return FRAME_COUNTS[anim]


static func frame_time(anim: int) -> float:
	return Config.IDLE_FRAME_TIME if anim == Anim.IDLE else Config.WALK_FRAME_TIME


## Sheet row for a direction (west reuses east).
static func sheet_row(direction: int) -> int:
	return Dir.EAST if direction == Dir.WEST else direction


static func is_mirrored(direction: int) -> bool:
	return direction == Dir.WEST


## Source rect of a body frame.
static func body_rect(row: int, frame: int) -> Rect2i:
	return Rect2i(Vector2i(frame * Config.CHAR_FRAME.x, row * Config.CHAR_FRAME.y), Config.CHAR_FRAME)


static func draw_order(row: int) -> Array[StringName]:
	var out: Array[StringName] = []
	out.assign(DRAW_ORDER[row])
	return out


## Anchor offset (torso or head) of a frame against walk frame 0 (actors/rig_anchors.gd).
static func anchor(anim: int, part: StringName, row: int, frame: int) -> Vector2i:
	var table: Array[Array] = RigAnchors.HEAD if part == ANCHOR_HEAD else RigAnchors.TORSO
	var rows: Array = table[anim]
	var frames: Array = rows[row]
	var offset: Vector2i = frames[frame]
	return offset


## v01 -> v02 re-pivot (px down) of an animation's sheet row.
static func shift(anim: int, row: int) -> int:
	var rows: Array = SHIFT[anim]
	var value: int = rows[row]
	return value


## Extra vertical bob of floating layers on a frame.
static func bob(anim: int, frame: int) -> int:
	var frames: Array = FLOAT_BOB[anim]
	var value: int = frames[frame]
	return value


## Top-left of a signature layer in frame coordinates for a frame (see the class comment).
static func layer_frame_pos(sig: Signature, anim: int, row: int, frame: int) -> Vector2i:
	var pos: Vector2i = sig.pos_v01
	pos.y += shift(anim, row)
	pos += anchor(anim, sig.anchor, row, frame)
	if sig.floats():
		pos.y += bob(anim, frame)
	return pos


## 4-way facing from `from` towards `to` (the larger axis wins, ties go north/south).
static func facing_toward(from: Vector2, to: Vector2) -> int:
	var d: Vector2 = to - from
	if absf(d.x) > absf(d.y):
		return Dir.EAST if d.x > 0.0 else Dir.WEST
	return Dir.SOUTH if d.y > 0.0 else Dir.NORTH
