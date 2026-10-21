class_name Terrain
extends RefCounted
## Surface floor terrains and Wang (corner) keys.
##
## A Wang tile is described by the terrain at its four corners, in the order NW, NE, SW, SE.
## A corner key packs them in base 3: NW + 3*NE + 9*SW + 27*SE (0..80).
## Our art has two Wang sets (grass<->soil, grass<->ash) and none for soil+ash, so soil and ash
## must never be corners of the same display cell (see can_touch()).

const GRASS: int = 0
const SOIL: int = 1
const ASH: int = 2
const COUNT: int = 3
const NAMES: PackedStringArray = ["grass", "soil", "ash"]
const KEY_COUNT: int = 81


static func key_of(nw: int, ne: int, sw: int, se: int) -> int:
	return nw + 3 * ne + 9 * sw + 27 * se


static func key_of_corners(corners: PackedByteArray) -> int:
	return key_of(corners[0], corners[1], corners[2], corners[3])


static func corners_of_key(key: int) -> PackedByteArray:
	return PackedByteArray([key % 3, (key / 3) % 3, (key / 9) % 3, (key / 27) % 3])


## False for soil next to ash: there is no art for a tile with both on its corners.
static func can_touch(a: int, b: int) -> bool:
	return not ((a == SOIL and b == ASH) or (a == ASH and b == SOIL))


## True if the four corners of a key can all be drawn from one of our Wang sets.
static func key_has_art(key: int) -> bool:
	var c: PackedByteArray = corners_of_key(key)
	var soil: bool = c.has(SOIL)
	var ash: bool = c.has(ASH)
	return not (soil and ash)


## Cost of drawing terrain `have` where `want` was asked for (fallback tiles, WangTable).
static func distance(have: int, want: int) -> int:
	if have == want:
		return 0
	if have == GRASS or want == GRASS:
		return 1
	return 3
