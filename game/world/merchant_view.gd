class_name MerchantView
extends Node2D
## M8: how the merchant looks: the 03-pixel pilgrim merchant sheet (art/npcs/merchant_v02_idle.png, a byte copy of
## assets/concept/03-pixel/merchant_v02_idle.png: PixelLab 15차, PR #71, an adoption candidate the human has not confirmed yet,
## README "M8a 그림 자리 표시"). 32 px cells, rows south / east / north, four breathing-idle frames each, feet on row 31: the
## base body's idle layout. West = the east row mirrored (Rig scale.x = -1, ● R19 as for the players and the heretics).
## The node stands at his feet (Merchant.feet_of: the y-sort sorts him like a character); the cell's feet row (y = 31) sits just
## above it, like Character. Light: the actors' layer (the hard-edged altar light), like the players.
## Which way he looks (PROVISIONAL, README "M8 상인이 보는 쪽"): Main sets `facing` every physics tick from this machine's own
## player (facing_for: toward it by the larger axis while its feet tile is within the open shop's reach of his tile, else south).
## Only a picture: nothing in the simulation, the world data or on the wire, so each machine shows him looking at its own player.
## Over his head a small prompt (an ivory bubble with an "F" and a coin, unshaded; a PLACEHOLDER drawn in code) shows while the
## local player stands next to him (show_prompt, Main): centred, its bottom row PROMPT_GAP px above the first opaque row of the
## cell shown (head_top: measured once from the sheet for every facing and frame and kept, so set_frame and set_facing never
## read a texture). tools/check_render.gd compares the screen with the sheet; tests/test_merchant.gd checks the rules.

const SHEET: Texture2D = preload("res://art/npcs/merchant_v02_idle.png")
const FRAMES: int = 4
## IMPL: the prompt (13 x 11: an ivory bubble with an ash-black "F" and a small coin; its tail points down at him), drawn with its
## bottom row PROMPT_GAP px above his head's top row, centred on him.
const PROMPT: Array = [
	".kkkkkkkkkkk.",
	"kbbbbbbbbbbbk",
	"kbkkkbbbkkbbk",
	"kbkbbbbkhhkbk",
	"kbkkbbbkhgkbk",
	"kbkbbbbkhhkbk",
	"kbkbbbbbkkbbk",
	"kbbbbbbbbbbbk",
	".kkkkkbkkkkk.",
	".....kbk.....",
	"......k......",
]
const PROMPT_SIZE: Vector2i = Vector2i(13, 11)
const PROMPT_COLORS: Dictionary[String, Color] = {
	"k": Color8(0x1a, 0x17, 0x14), "b": Color8(0xef, 0xe3, 0xc6), "h": Color8(0xd2, 0xcb, 0xb8), "g": Color8(0xf4, 0xc9, 0x5d),
}
const PROMPT_GAP: int = 2

static var _prompt: ImageTexture
## The first opaque row of every cell (index sheet row * FRAMES + frame), read once from SHEET (M8 review: an exported build's
## CompressedTexture2D.get_image() may read it back from the GPU, so it is never called while he breathes or turns).
static var _head_tops: PackedInt32Array = PackedInt32Array()

## Advance the breathing in _process (tests and the render check turn it off and set `frame`).
var animate: bool = true
var frame: int = 0:
	set = set_frame
## RigData.Dir: the way he looks (Main: facing_for).
var facing: int = RigData.Dir.SOUTH:
	set = set_facing
var rig: Node2D
var body: Sprite2D
var prompt: Sprite2D
var _time: float = 0.0


func _init() -> void:
	_measure_head_tops()
	light_mask = Config.LIGHT_LAYER_ACTORS
	rig = Node2D.new()
	rig.name = &"Rig"
	add_child(rig)
	body = Sprite2D.new()
	body.name = &"Body"
	body.texture = SHEET
	body.hframes = FRAMES
	body.vframes = RigData.ROWS
	body.centered = false
	body.position = Vector2(-RigData.FRAME_ORIGIN)
	body.light_mask = Config.LIGHT_LAYER_ACTORS
	rig.add_child(body)
	prompt = Sprite2D.new()
	prompt.name = &"Prompt"
	prompt.texture = prompt_texture()
	prompt.centered = false
	prompt.material = FixtureView.unshaded_material()
	prompt.light_mask = Config.LIGHT_LAYER_ACTORS
	prompt.visible = false
	add_child(prompt)
	_show()


func _process(delta: float) -> void:
	if not animate:
		return
	_time += delta
	while _time >= Config.IDLE_FRAME_TIME:
		_time -= Config.IDLE_FRAME_TIME
		frame = frame + 1


func set_frame(value: int) -> void:
	frame = posmod(value, FRAMES)
	_show()


func set_facing(value: int) -> void:
	var dir: int = posmod(value, RigData.DIR_NAMES.size())
	if dir == facing:
		return
	facing = dir
	_show()


## The cell for `facing` and `frame` (west: the east row mirrored) and the prompt over that cell's head.
func _show() -> void:
	if body == null:
		return
	body.frame = RigData.sheet_row(facing) * FRAMES + frame
	rig.scale = Vector2(-1.0 if RigData.is_mirrored(facing) else 1.0, 1.0)
	prompt.position = Vector2(prompt_at(facing, frame) - RigData.FRAME_ORIGIN)


## The prompt on or off (Main: the local player next to him, the shop not open).
func show_prompt(on: bool) -> void:
	if prompt.visible != on:
		prompt.visible = on


## The way he looks with this machine's player's feet at `feet` and he on tile `tile` (PROVISIONAL, README "M8 상인이 보는
## 쪽"): toward those feet by the larger axis (RigData.facing_toward: ties go north / south) while their feet tile is within the
## open shop's reach of his tile (Merchant.in_shop_reach: Config.STATION_REACH_TILES), else south.
static func facing_for(tile: Vector2i, feet: Vector2) -> int:
	var at: Vector2 = Merchant.feet_of(tile)
	if tile == Walls.NO_CELL or not Merchant.in_shop_reach(feet, tile) or feet.is_equal_approx(at):
		return RigData.Dir.SOUTH
	return RigData.facing_toward(at, feet)


## Top-left of the prompt in frame coordinates for facing `dir` and breathing frame `f`: centred, its bottom row PROMPT_GAP px
## above the head.
static func prompt_at(dir: int, f: int) -> Vector2i:
	return Vector2i((Config.CHAR_FRAME.x - PROMPT_SIZE.x) / 2, head_top(dir, f) - PROMPT_GAP - PROMPT_SIZE.y)


## The first opaque row (frame coordinates: the top of his hat or pack) of the cell shown facing `dir` on breathing frame `f`
## (west = east: mirroring keeps the rows). Measured once (_measure_head_tops).
static func head_top(dir: int, f: int) -> int:
	_measure_head_tops()
	return _head_tops[RigData.sheet_row(posmod(dir, RigData.DIR_NAMES.size())) * FRAMES + posmod(f, FRAMES)]


static func prompt_texture() -> ImageTexture:
	if _prompt == null:
		_prompt = ImageTexture.create_from_image(prompt_image())
	return _prompt


static func prompt_image() -> Image:
	var img: Image = Image.create_empty(PROMPT_SIZE.x, PROMPT_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in PROMPT.size():
		var row: String = PROMPT[y]
		for x: int in row.length():
			if PROMPT_COLORS.has(row[x]):
				img.set_pixel(x, y, PROMPT_COLORS[row[x]])
	return img


## Reads SHEET once and keeps every cell's first opaque row (a cell with none: 0).
static func _measure_head_tops() -> void:
	if not _head_tops.is_empty():
		return
	var sheet: Image = LightGen.to_rgba8(SHEET.get_image())
	var tops: PackedInt32Array = PackedInt32Array()
	for row: int in RigData.ROWS:
		for f: int in FRAMES:
			var cell: Image = sheet.get_region(Rect2i(Vector2i(f, row) * Config.CHAR_FRAME, Config.CHAR_FRAME))
			var top: int = 0
			for y: int in cell.get_height():
				if _row_opaque(cell, y):
					top = y
					break
			tops.append(top)
	_head_tops = tops


static func _row_opaque(img: Image, y: int) -> bool:
	for x: int in img.get_width():
		if img.get_pixel(x, y).a8 >= 128:
			return true
	return false
