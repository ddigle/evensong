class_name PillarArt
extends RefCounted
## M12a: the cracked support pillar's four pictures (● game-concept §12 R49, brief §5.7 R49 "상태 4단계"; the pictures PLACEHOLDERS derived in
## code from our 04-env boss_pillar_candA_v02, copied to art/env): 0 intact = the picture as it is; 1 cracked = CRACKS_1 cut into it (1 px
## ash-black cracks joined only through the four sides, the side the light comes from lit a step: the a3 hand-drawn wall cracks' rule);
## 2 badly cracked = CRACKS_1 and CRACKS_2 and the CHIPS knocked out of its edges (the hole's rim outlined again); 3 broken = the stub: only
## the rows from its jagged break (STUB_TOP per column) down, the fresh break face a row of BREAK_FACE under a new outline. The rubble round a
## broken pillar is drawn by combat/boss_fight_view.gd (code pebbles in the picture's own colours). Same input, same pixels (no randomness).
## The picture stands with its opaque bottom row (BOTTOM_ROW) on its tile's bottom row of pixels, its column (CENTRE_X) on the tile's middle.

const PICTURE: Texture2D = preload("res://art/env/boss_pillar_candA_v02.png")
## Measured on boss_pillar_candA_v02 (32x64): opaque rows 1..61, the base 6..26 wide (its middle 16), the column 10..22.
const BOTTOM_ROW: int = 61
const CENTRE_X: int = 16
## IMPL colours (the picture's and brief §4's): the crack (#1a1714 outline), the lit ledge (the picture's lightest stone), the fresh break.
const CRACK: Color = Color8(0x1a, 0x17, 0x14)
const LEDGE: Color = Color8(0xb6, 0xaa, 0x9d)
const BREAK_FACE: Color = Color8(0x6b, 0x5e, 0x4f)
## IMPL: crack paths (picture px, joined 4-way), state 1 and the more of state 2. M12b: state 1's third crack (the lower shaft), so the first
## state reads at 1x beside an intact pillar (M12a's two thin cracks were hard to tell from the stone's own joints).
const CRACKS_1: Array[Array] = [
	[Vector2i(18, 15), Vector2i(17, 19), Vector2i(19, 23), Vector2i(17, 28), Vector2i(18, 33)],
	[Vector2i(13, 6), Vector2i(15, 9), Vector2i(14, 12)],
	[Vector2i(14, 37), Vector2i(12, 41), Vector2i(14, 45), Vector2i(13, 48)],
]
const CRACKS_2: Array[Array] = [
	[Vector2i(12, 20), Vector2i(14, 25), Vector2i(13, 31), Vector2i(15, 37), Vector2i(13, 43), Vector2i(15, 48)],
	[Vector2i(20, 36), Vector2i(18, 41), Vector2i(20, 46)],
	[Vector2i(9, 54), Vector2i(12, 56)],
]
## IMPL: the chips of state 2: [top-left, size] of pixels knocked out (transparent; their rim outlined again).
const CHIPS: Array[Array] = [[Vector2i(10, 24), Vector2i(2, 3)], [Vector2i(21, 31), Vector2i(2, 2)], [Vector2i(9, 7), Vector2i(2, 2)],
	[Vector2i(22, 44), Vector2i(1, 3)]]
## IMPL: state 3's break line: the first kept row of each column 6..26 (the stub's jagged top; the base below row 51 always stays).
const STUB_TOP: PackedInt32Array = [52, 52, 51, 50, 46, 43, 41, 44, 42, 40, 43, 45, 42, 41, 44, 47, 43, 44, 48, 50, 51]
const STUB_FIRST_X: int = 6

static var _textures: Dictionary[int, ImageTexture] = {}


## The picture of state `look` (0..3).
static func texture(look: int) -> ImageTexture:
	var k: int = clampi(look, 0, 3)
	if not _textures.has(k):
		_textures[k] = ImageTexture.create_from_image(image(k))
	return _textures[k]


static func image(look: int) -> Image:
	var img: Image = LightGen.to_rgba8(PICTURE.get_image())
	if look >= 1:
		for path: Array in CRACKS_1:
			_crack(img, path)
	if look >= 2:
		for path: Array in CRACKS_2:
			_crack(img, path)
		for chip: Array in CHIPS:
			var at: Vector2i = chip[0]
			var size: Vector2i = chip[1]
			_chip(img, Rect2i(at, size))
	if look >= 3:
		_stub(img)
	return img


## The top-left (world px) of the picture standing on tile `c`.
static func origin(c: Vector2i) -> Vector2i:
	return Vector2i(c.x * Config.TILE + Config.TILE / 2 - CENTRE_X, (c.y + 1) * Config.TILE - 1 - BOTTOM_ROW)


## A crack along `path` (4-way steps between its points, x first then y in single steps), only over stone (opaque, not outline); the pixel
## right of each crack pixel and the one below it lit a step (LEDGE) where it is stone and not cracked.
static func _crack(img: Image, path: Array) -> void:
	var cells: Array[Vector2i] = []
	for i: int in range(1, path.size()):
		var a: Vector2i = path[i - 1]
		var b: Vector2i = path[i]
		var p: Vector2i = a
		cells.append(p)
		while p != b:
			if p.x != b.x and (absi(b.x - p.x) >= absi(b.y - p.y) or p.y == b.y):
				p.x += signi(b.x - p.x)
			else:
				p.y += signi(b.y - p.y)
			cells.append(p)
	for c: Vector2i in cells:
		if _stone(img, c):
			img.set_pixelv(c, CRACK)
	for c: Vector2i in cells:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = c + d
			if not cells.has(q) and _stone(img, q) and (c.x + c.y) % 3 != 0:
				img.set_pixelv(q, LEDGE)


## Knocks the pixels of `r` out (transparent) and outlines what is left round the hole.
static func _chip(img: Image, r: Rect2i) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y: int in range(r.position.y - 1, r.end.y + 1):
		for x: int in range(r.position.x - 1, r.end.x + 1):
			var c: Vector2i = Vector2i(x, y)
			if r.has_point(c) or not _in(img, c) or img.get_pixelv(c).a8 == 0:
				continue
			img.set_pixelv(c, CRACK)


## Keeps only the stub: every pixel above STUB_TOP of its column goes, the new top pixel of each column is outline, the one under it the
## fresh break face.
static func _stub(img: Image) -> void:
	for x: int in img.get_width():
		var i: int = x - STUB_FIRST_X
		var top: int = STUB_TOP[i] if i >= 0 and i < STUB_TOP.size() else img.get_height()
		for y: int in mini(top, img.get_height()):
			img.set_pixel(x, y, Color(0, 0, 0, 0))
		if top < img.get_height() and img.get_pixel(x, top).a8 > 0:
			img.set_pixel(x, top, CRACK)
			if top + 1 < img.get_height() and _stone(img, Vector2i(x, top + 1)):
				img.set_pixel(x, top + 1, BREAK_FACE)


static func _in(img: Image, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < img.get_width() and c.y < img.get_height()


## An opaque pixel that is not the outline colour.
static func _stone(img: Image, c: Vector2i) -> bool:
	if not _in(img, c):
		return false
	var p: Color = img.get_pixelv(c)
	return p.a8 > 0 and not (p.r8 == 0x1a and p.g8 == 0x17 and p.b8 == 0x14)
