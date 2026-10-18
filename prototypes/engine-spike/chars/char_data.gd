extends RefCounted
## Data for the layered character spike (res://chars/). No state, constants only.
##
## Sources (copied from assets/concept/03-pixel, see notes/chars.md):
## - base_body_v02_walk.png: 32x32 cells, rows south/east/north, 6 frames, feet on row y=31.
## - sig_*.png: 32x32 cells, columns south/east/north. Drawn on walk v01 frame 0, so they are
##   shifted down by the v01 -> v02 walk shift (south +4, east +3, north +4) when attached.
## - sig_cleric_halo_v01.png: 12x5, one image for every direction, floats above the head.
## West is east mirrored (brief §5.6, R19).

enum Dir { SOUTH, EAST, NORTH, WEST }

const DIR_NAMES: PackedStringArray = ["south", "east", "north", "west"]

const BODY_SHEET: String = "res://art/chars/base_body_v02_walk.png"
const FRAME_SIZE: Vector2i = Vector2i(32, 32)
const FRAME_COUNT: int = 6
## Seconds per walk frame (the stage-3 walk GIFs use 120 ms).
const FRAME_TIME: float = 0.12
## Character origin (feet) inside a 32x32 frame: the bottom edge, horizontally centred.
## Sprites are placed at -FRAME_ORIGIN so the node position is the point between the feet.
const FRAME_ORIGIN: Vector2i = Vector2i(16, 32)

## v01 -> v02 walk shift per sheet row (south, east, north). Signature layers drawn on v01
## frame 0 move down by this much (03-pixel/prompts.md "발 맞춤").
const LAYER_SHIFT: Array[int] = [4, 3, 4]

## Per-frame anchor offsets (sheet row -> 6 frames), measured on base_body_v02_walk.png with
## Compose.anchor_offsets(): the shift of frame f's band that matches the most frame-0 pixels
## (RGB distance < 60, search +/-4 px). Torso band = v01 rows 13..22, head band = v01 rows 0..11.
## tests/test_chars.gd recomputes them, so a changed sheet fails the test instead of drifting.
const TORSO_BAND: Vector2i = Vector2i(13, 22)
const HEAD_BAND: Vector2i = Vector2i(0, 11)
const ANCHOR_RADIUS: int = 4
const ANCHOR_TOLERANCE: int = 60
const TORSO_OFFSETS: Array = [
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
]
const HEAD_OFFSETS: Array = [
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1), Vector2i(0, -1)],
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
]

## Layer slots. A signature fills one slot; the body is the slot "body".
const SLOT_BODY: StringName = &"body"
const SLOT_BACK: StringName = &"back"     # carried on the back (pickaxe, bow)
const SLOT_WAIST: StringName = &"waist"   # hangs at the hip (pouch, twin swords, hammer)
const SLOT_FLOAT: StringName = &"float"   # floats outside the frame (halo, book, runes)
const SLOTS: Array[StringName] = [SLOT_BACK, SLOT_WAIST, SLOT_FLOAT]

## Draw order per sheet row, first = drawn first (furthest back). Brief §5.6: back gear behind
## the body for south/east, in front for north; waist and floating gear in front. West uses the
## east order (mirrored image, so a back item stays behind the body).
const DRAW_ORDER: Array = [
	[SLOT_BACK, SLOT_BODY, SLOT_WAIST, SLOT_FLOAT],
	[SLOT_BACK, SLOT_BODY, SLOT_WAIST, SLOT_FLOAT],
	[SLOT_BODY, SLOT_BACK, SLOT_WAIST, SLOT_FLOAT],
]

## Signature layers. "columns" sheets have one 32x32 cell per sheet row (south, east, north);
## "single" is one image for every direction placed at `pos` (v01 frame coordinates).
const SIGNATURES: Dictionary = {
	&"pouch": {"slot": SLOT_WAIST, "sheet": "res://art/chars/sig_herbalist_pouch_v02.png",
		"layout": &"columns", "anchor": &"torso"},
	&"pickaxe": {"slot": SLOT_BACK, "sheet": "res://art/chars/sig_miner_pickaxe_v01.png",
		"layout": &"columns", "anchor": &"torso"},
	&"halo": {"slot": SLOT_FLOAT, "sheet": "res://art/chars/sig_cleric_halo_v01.png",
		"layout": &"single", "anchor": &"head", "pos": Vector2i(10, -5)},
}
## The halo floats: frames 2-4 of the walk are 1 px higher (03-pixel/prompts.md 5차).
const FLOAT_BOB: Array[int] = [0, 0, -1, -1, -1, 0]

## Palette swap for the tunic. AI frames are not indexed, so the same beige is also used in the
## face and hair highlights: the swap only applies to frame rows TUNIC_BAND (frame-local y).
const TUNIC_SOURCE: PackedStringArray = [
	"f5d6ac", "eec58d", "e2b880", "dcb089", "d0a571", "c89a68", "ba895b", "e9d9ce", "bc7d4e", "b28156",
]
const TUNIC_BAND: Vector2i = Vector2i(17, 25)
## Palette name -> target hue (0..1). The source saturation and value are kept, so the shading
## ramp survives. "default" means no swap.
const PALETTES: Dictionary = {
	&"default": -1.0,
	&"moss": 0.29,
	&"wine": 0.97,
	&"sky": 0.58,
	&"teal": 0.47,
}
const PALETTE_SATURATION: float = 0.85


## Sheet row for a direction (west reuses east).
static func sheet_row(direction: int) -> int:
	return Dir.EAST if direction == Dir.WEST else direction


static func is_mirrored(direction: int) -> bool:
	return direction == Dir.WEST


static func source_colors() -> PackedColorArray:
	var out: PackedColorArray = []
	for hex: String in TUNIC_SOURCE:
		out.append(Color.html(hex))
	return out


## Target colours for a palette, quantised to 8 bits so the GPU and CPU paths agree exactly.
static func palette_colors(palette: StringName) -> PackedColorArray:
	var out: PackedColorArray = []
	var hue: float = float(PALETTES.get(palette, -1.0))
	if hue < 0.0:
		return out
	for src: Color in source_colors():
		var c: Color = Color.from_hsv(hue, clampf(src.s * PALETTE_SATURATION, 0.0, 1.0), src.v)
		out.append(Color8(c.r8, c.g8, c.b8))
	return out


## Top-left of a signature layer in frame coordinates (0..31, y down) for a frame.
static func layer_frame_pos(signature: StringName, row: int, frame: int) -> Vector2i:
	var info: Dictionary = SIGNATURES[signature]
	var base: Vector2i = info.get("pos", Vector2i.ZERO)
	base.y += LAYER_SHIFT[row]
	if info["anchor"] == &"head":
		base += HEAD_OFFSETS[row][frame] as Vector2i
	else:
		base += TORSO_OFFSETS[row][frame] as Vector2i
	if info["slot"] == SLOT_FLOAT:
		base.y += FLOAT_BOB[frame]
	return base
