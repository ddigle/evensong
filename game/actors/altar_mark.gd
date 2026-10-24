class_name AltarMark
extends Sprite2D
## M5b: a small altar over the head of the player carrying the altar (PLACEHOLDER drawn in code from a character map:
## no art for a carried altar exists). A grey slab with three lit gold lamps in the ItemIcons palette (brief §4 colours).
## Unshaded so it reads in the dark (the carried altar gives no light). The node is a child of the Player (on the feet);
## the picture's top row is MARK_Y px above the feet, above the effect marks (EffectMarks.MARK_Y). Layout values are IMPL.

const MAP: PackedStringArray = [
	"..g.g.g..",
	".kgkgkgk.",
	"kkkkkkkkk",
	"khhhhhhhk",
	"kmmmmmmmk",
	"kkkkkkkkk",
]
const MARK_Y: int = -53

static var _texture: ImageTexture


func _init() -> void:
	name = &"AltarMark"
	texture = picture()
	centered = false
	position = Vector2(-image().get_width() / 2, MARK_Y)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	visible = false


## The mark's image (tests compare the screen with it).
static func image() -> Image:
	var w: int = MAP[0].length()
	var img: Image = Image.create_empty(w, MAP.size(), false, Image.FORMAT_RGBA8)
	for y: int in MAP.size():
		for x: int in w:
			var ch: String = MAP[y][x]
			if ItemIcons.PALETTE.has(ch):
				img.set_pixel(x, y, ItemIcons.PALETTE[ch])
	return img


static func picture() -> ImageTexture:
	if _texture == null:
		_texture = ImageTexture.create_from_image(image())
	return _texture
