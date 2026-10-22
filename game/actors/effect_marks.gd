class_name EffectMarks
extends Node2D
## M6a: small marks above a head for the effects on it (a player's buff and poison, a heretic's poison), and
## the same icons for the HUD. PLACEHOLDERS drawn in code from 7x7 character maps (no effect art exists):
## the buff an amber arrow up, the poison a poison-herb yellow drop with a rust spot (● brief §5.7 R29: the
## potion colours follow the crops; ItemIcons.PALETTE). Unshaded so they read in the dark. The node sits on
## the feet; the icons are centred in a row MARK_Y px above them. Layout values are IMPL.

enum Kind { BUFF, POISON }

const SIZE: int = 7
const GAP: int = 1
## Top row of the icons above the feet (clear of the cleric's halo and the heretic's HP bar).
const MARK_Y: int = -44
const MAPS: Array[Array] = [
	["...k...", "..kak..", ".kaaak.", "kkaaakk", "..kak..", "..kak..", "..kkk.."],
	["...k...", "..kyk..", ".kyyyk.", "kyyuyYk", "kyyyyYk", ".kYYYk.", "..kkk.."],
]

static var _textures: Array[ImageTexture] = []

## What is shown (tests read it).
var shown: Array[int] = []
var _sprites: Array[Sprite2D] = []


func _init() -> void:
	name = &"EffectMarks"


## The 7x7 image of effect `kind`.
static func image(kind: int) -> Image:
	var img: Image = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rows: Array = MAPS[kind]
	for y: int in SIZE:
		var row: String = rows[y]
		for x: int in SIZE:
			var ch: String = row[x]
			if ItemIcons.PALETTE.has(ch):
				img.set_pixel(x, y, ItemIcons.PALETTE[ch])
	return img


static func texture(kind: int) -> ImageTexture:
	if _textures.is_empty():
		for k: int in MAPS.size():
			_textures.append(ImageTexture.create_from_image(image(k)))
	return _textures[kind]


## The effects on vitals `v` (buff, poison), in Kind order.
static func kinds_of(v: Vitals) -> Array[int]:
	var out: Array[int] = []
	if v.buffed():
		out.append(Kind.BUFF)
	if v.poisoned():
		out.append(Kind.POISON)
	return out


## Top-left (relative to the feet) of icon `i` of `n` in the row.
static func icon_offset(i: int, n: int) -> Vector2i:
	var total: int = n * SIZE + (n - 1) * GAP
	return Vector2i(-total / 2 + i * (SIZE + GAP), MARK_Y)


## Shows these effects (Kind values; an empty list hides them all).
func show_kinds(kinds: Array[int]) -> void:
	if kinds == shown:
		return
	shown = kinds.duplicate()
	for s: Sprite2D in _sprites:
		remove_child(s)
		s.free()
	_sprites.clear()
	for i: int in kinds.size():
		var s: Sprite2D = Sprite2D.new()
		s.name = StringName("Mark_%d" % kinds[i])
		s.texture = texture(kinds[i])
		s.centered = false
		s.position = Vector2(icon_offset(i, kinds.size()))
		s.material = FixtureView.unshaded_material()
		s.light_mask = Config.LIGHT_LAYER_ACTORS
		add_child(s)
		_sprites.append(s)
