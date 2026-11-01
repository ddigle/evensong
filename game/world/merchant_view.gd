class_name MerchantView
extends Node2D
## M8a: how the merchant looks (PLACEHOLDER drawn in code: there is no merchant art and no approved generation; README "상인 그림:
## 임시, PixelLab 비용 승인 뒤 교체"). The shared base body standing (base_body_v02_idle, the south row, its four breathing frames)
## with its tunic recoloured to an olive travelling cloak, a wide-brimmed pilgrim's hat ("순례 상인") over the head and a pack
## with a bedroll and a copper pot on the back: no class signature, so he reads apart from the players (the base body + one
## class's marker gear, ● R21) and from the heretics (grey robed sheets). He always faces south.
## The node stands at his feet (Merchant.feet_of: the y-sort sorts him like a character); the frame's feet row (y = 31) sits
## just above it, like Character. Light: the actors' layer (the hard-edged altar light), like the players. Over his hat a small
## prompt (an ivory bubble with an "F" and a coin, unshaded) shows while the local player stands next to him (show_prompt,
## Main). The pictures are built once from the idle PNG (sheet_image(), prompt_image(); tools/check_render.gd compares the
## screen with them, tests/test_merchant.gd checks their rules).

## IMPL: the tunic's colours in base_body_v02_idle (measured: the beige and tan tunic of the shared body, rows TUNIC_FROM_ROW
## down; the face, hands, hair and trousers keep theirs) and the olive cloak colour each becomes (lightest to darkest).
const TUNIC: Dictionary[String, String] = {
	"f0d39c": "a9a35a", "eec58d": "a9a35a", "e2b880": "8d8a47", "d0a571": "8d8a47", "c89a68": "737236",
	"ba895b": "737236", "bc7d4e": "5a5a2b", "b28156": "5a5a2b", "a0724c": "42431f",
}
const TUNIC_FROM_ROW: int = 19
## IMPL: the hat (rows from the frame's first opaque row - 2; columns from HAT_LEFT) and the pack (frame rows / columns as they
## are), drawn in these colours: k outline (§4 ash black), f felt, F felt light, d felt dark, g band (§4 faith gold), w
## leather, W leather light, b bedroll (§4 ivory), B bedroll shade, c copper (04-env copper), C copper light.
const PALETTE: Dictionary[String, Color] = {
	"k": Color8(0x1a, 0x17, 0x14), "f": Color8(0x6f, 0x4a, 0x2a), "F": Color8(0x8a, 0x5e, 0x34), "d": Color8(0x4a, 0x30, 0x1c),
	"g": Color8(0xc9, 0x93, 0x2b), "w": Color8(0x6b, 0x40, 0x22), "W": Color8(0x8c, 0x58, 0x30), "b": Color8(0xef, 0xe3, 0xc6),
	"B": Color8(0xc9, 0xb8, 0x96), "c": Color8(0xc0, 0x6a, 0x2e), "C": Color8(0xdf, 0x90, 0x3f),
}
const HAT_LEFT: int = 5
const HAT_ABOVE: int = 2
const HAT: Array = [
	"........kkkkkk........",
	".......kfFFFffk.......",
	"......kfFfffffdk......",
	"......kffffffffk......",
	"......kggggggggk......",
	"..kkkkkddddddddkkkkk..",
	".kFFFFFFFFFFFFFFFFFFk.",
	"..kkkkkkkkkkkkkkkkkk..",
]
## The pack behind the body (frame coordinates, top-left PACK_AT): the bedroll across the shoulders, the pack below it, the pot
## hanging at its right. The body covers its middle.
const PACK_AT: Vector2i = Vector2i(3, 14)
const PACK: Array = [
	".kkkkkkkkkkkkkkkkkkkkkkkk.",
	"kbbbbbbbbbbbbbbbbbbbbbbbbk",
	"kbBBkBBBBBBBBBBBBBBBBkBBbk",
	"kBBBkBBBBBBBBBBBBBBBBkBBBk",
	".kkkkkkkkkkkkkkkkkkkkkkkk.",
	"...kWWwwwwwwwwwwwwwwwWk...",
	"...kWwwwwwwwwwwwwwwwwwk...",
	"...kWwwwwwwwwwwwwwwwwwkkk.",
	"...kWwwwwwwwwwwwwwwwwwkCk.",
	"...kWwwwwwwwwwwwwwwwwkCck.",
	"...kWwwwwwwwwwwwwwwwwkcck.",
	"...kwwwwwwwwwwwwwwwwwwkkk.",
	"...kkkkkkkkkkkkkkkkkkkk...",
]
## IMPL: the prompt (13 x 11: an ivory bubble with an ash-black "F" and a small coin; its tail points down at him), drawn with its
## bottom row PROMPT_GAP px above the hat's top row, centred on him.
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
const FRAMES: int = 4

static var _sheet: ImageTexture
static var _sheet_image: Image
static var _prompt: ImageTexture
## M8 review: the idle sheet read once (an exported build's CompressedTexture2D.get_image() reads it back from the GPU) and the
## hat's top row per breathing frame from it, so set_frame never reads a texture.
static var _idle_sheet: Image
static var _hat_tops: PackedInt32Array = PackedInt32Array()

## Advance the breathing in _process (tests and the render check turn it off and set `frame`).
var animate: bool = true
var frame: int = 0:
	set = set_frame
var body: Sprite2D
var prompt: Sprite2D
var _time: float = 0.0


func _init() -> void:
	light_mask = Config.LIGHT_LAYER_ACTORS
	body = Sprite2D.new()
	body.name = &"Body"
	body.texture = sheet()
	body.hframes = FRAMES
	body.centered = false
	body.position = Vector2(-RigData.FRAME_ORIGIN)
	body.light_mask = Config.LIGHT_LAYER_ACTORS
	add_child(body)
	prompt = Sprite2D.new()
	prompt.name = &"Prompt"
	prompt.texture = prompt_texture()
	prompt.centered = false
	prompt.position = Vector2(prompt_at(0) - RigData.FRAME_ORIGIN)
	prompt.material = FixtureView.unshaded_material()
	prompt.light_mask = Config.LIGHT_LAYER_ACTORS
	prompt.visible = false
	add_child(prompt)


func _process(delta: float) -> void:
	if not animate:
		return
	_time += delta
	while _time >= Config.IDLE_FRAME_TIME:
		_time -= Config.IDLE_FRAME_TIME
		frame = frame + 1


func set_frame(value: int) -> void:
	frame = posmod(value, FRAMES)
	if body != null:
		body.frame = frame
	if prompt != null:
		prompt.position = Vector2(prompt_at(frame) - RigData.FRAME_ORIGIN)


## The prompt on or off (Main: the local player next to him, the shop not open).
func show_prompt(on: bool) -> void:
	if prompt.visible != on:
		prompt.visible = on


## Top-left of the prompt in frame coordinates for breathing frame `f`: centred, its bottom row PROMPT_GAP px above the hat.
static func prompt_at(f: int) -> Vector2i:
	return Vector2i((Config.CHAR_FRAME.x - PROMPT_SIZE.x) / 2, hat_top(f) - PROMPT_GAP - PROMPT_SIZE.y)


## The hat's top row in frame `f` (frame coordinates): HAT_ABOVE rows over the frame's first opaque row of the base body
## (worked out once for the FRAMES frames).
static func hat_top(f: int) -> int:
	if _hat_tops.is_empty():
		for i: int in FRAMES:
			_hat_tops.append(_head_top(_idle_frame(i)) - HAT_ABOVE)
	return _hat_tops[posmod(f, FRAMES)]


## The merchant's four frames side by side (FRAMES x 32 by 32).
static func sheet() -> ImageTexture:
	if _sheet == null:
		_sheet = ImageTexture.create_from_image(sheet_image())
	return _sheet


static func sheet_image() -> Image:
	if _sheet_image == null:
		var out: Image = Image.create_empty(Config.CHAR_FRAME.x * FRAMES, Config.CHAR_FRAME.y, false, Image.FORMAT_RGBA8)
		for f: int in FRAMES:
			out.blit_rect(frame_image(f), Rect2i(Vector2i.ZERO, Config.CHAR_FRAME), Vector2i(f * Config.CHAR_FRAME.x, 0))
		_sheet_image = out
	return _sheet_image


## Frame `f` of the merchant (32 x 32): the pack, the recoloured body over it, the hat over that.
static func frame_image(f: int) -> Image:
	var src: Image = _idle_frame(f)
	var out: Image = Image.create_empty(Config.CHAR_FRAME.x, Config.CHAR_FRAME.y, false, Image.FORMAT_RGBA8)
	_draw_map(out, PACK, PACK_AT, PALETTE)
	for y: int in src.get_height():
		for x: int in src.get_width():
			var c: Color = src.get_pixel(x, y)
			if c.a8 < 128:
				continue
			out.set_pixel(x, y, recolour(c, y))
	_draw_map(out, HAT, Vector2i(HAT_LEFT, hat_top(f)), PALETTE)
	return out


## The base body's pixel `c` on frame row `y` as the merchant wears it: a tunic colour on the tunic's rows becomes its cloak
## colour (TUNIC), everything else stays (opaque).
static func recolour(c: Color, y: int) -> Color:
	var key: String = c.to_html(false)
	if y >= TUNIC_FROM_ROW and TUNIC.has(key):
		return Color.html(TUNIC[key])
	return Color(c.r, c.g, c.b, 1.0)


static func prompt_texture() -> ImageTexture:
	if _prompt == null:
		_prompt = ImageTexture.create_from_image(prompt_image())
	return _prompt


static func prompt_image() -> Image:
	var img: Image = Image.create_empty(PROMPT_SIZE.x, PROMPT_SIZE.y, false, Image.FORMAT_RGBA8)
	_draw_map(img, PROMPT, Vector2i.ZERO, PROMPT_COLORS)
	return img


## Frame `f` of the shared body's idle sheet, south row (RGBA8, 32 x 32).
static func _idle_frame(f: int) -> Image:
	if _idle_sheet == null:
		_idle_sheet = LightGen.to_rgba8(RigData.IDLE_SHEET.get_image())
	var rect: Rect2i = RigData.body_rect(RigData.sheet_row(RigData.Dir.SOUTH), posmod(f, FRAMES), RigData.Anim.IDLE)
	return _idle_sheet.get_region(rect)


## The first row of `img` with an opaque pixel (the top of the hair).
static func _head_top(img: Image) -> int:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				return y
	return 0


## Character map `rows` onto `img` at `at` (characters not in `colors` stay as they are).
static func _draw_map(img: Image, rows: Array, at: Vector2i, colors: Dictionary[String, Color]) -> void:
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			var ch: String = row[x]
			var p: Vector2i = at + Vector2i(x, y)
			if colors.has(ch) and p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(p.x, p.y, colors[ch])
