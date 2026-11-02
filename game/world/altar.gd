class_name Altar
extends Node2D
## The altar on its footprint (placeholder art: 04-env altar_v04, an adoption candidate, ○ R29).
##
## The node sits at the bottom centre of the footprint, so a y-sorted parent draws characters whose
## feet are south of the footprint in front of it and the others behind. The art (48x57, opaque
## rows 5-47) is placed with its top-left on the footprint's top-left: its bottom outline row lands
## on the footprint's last pixel row.
##   Sprite  altar_v04.png (lit), world light layer
##   Flames  emissive mask = pixels that differ from altar_v04_unlit.png and are bright
##           (Config.FLAME_MIN_LUMA), drawn again unshaded so the evening never darkens them
## M10a (● R45 "차례 하나 = 등잔 하나"): during a group prayer (and for Config.PRAYER_RESULT_SHOW_TICKS after it) each of the nine
## lamps (Config.PRAYER_LAMP_FLAMES, in the turns' order) shows its state instead (show_lamps; ○ R45 outside a prayer the altar keeps
## its own picture, all nine lit): a lamp not lit gets its box (Config.PRAYER_LAMP_BOX) of the unlit picture over it (LampCover,
## the world light like the sprite), a lit one its flame from the mask (LampFlames, unshaded); the lamp being answered shows an
## ember in its bowl, a failed one flickers out (Config.PRAYER_FLICKER_*: a low guttering flame on and off) and then shows a soot
## mark. Both pictures are the 04-env art already here: no new art file. The ember, the guttering flame and the soot are
## PLACEHOLDER pixels (IMPL).

const LIT: Texture2D = preload("res://art/env/altar_v04.png")
const UNLIT: Texture2D = preload("res://art/env/altar_v04_unlit.png")

## M10a: how a lamp looks (lamp_look): lit (its flame), unlit (not answered yet, or a flicker's off beat), the ember of the lamp
## being answered, out (soot), a failed one's guttering flame (a flicker's on beat).
enum Look { LIT, UNLIT, EMBER, SOOT, GUTTER }
## M10a (IMPL, placeholder pixels relative to a lamp's flame origin, on the unlit picture): the ember (a 2 x 2 copper light glow in the bowl
## under where the flame would be), the soot mark of a lamp gone out (ash black, a wisp above the bowl), and the guttering flame
## of one failing (low in the bowl: rust tips over a copper base).
const EMBER_PIXELS: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4)]
const EMBER: Color = Color8(0xdf, 0x90, 0x3f)
const SOOT_PIXELS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
const SOOT: Color = Color8(0x1a, 0x17, 0x14)
const GUTTER_TIP_PIXELS: Array[Vector2i] = [Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3)]
const GUTTER_TIP: Color = Color8(0xc4, 0x42, 0x1c)
const GUTTER_BASE_PIXELS: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 4)]
const GUTTER_BASE: Color = Color8(0xc0, 0x6a, 0x2e)
## M10a: a flame's size in the mask (2 x 5 px at each Config.PRAYER_LAMP_FLAMES spot).
const FLAME_SIZE: Vector2i = Vector2i(2, 5)

static var _flame_image: Image
static var _flame_texture: ImageTexture
static var _unshaded: CanvasItemMaterial

var footprint_px: Rect2i
var sprite: Sprite2D
var flames: Sprite2D
## M10a: the lamps' overlay (see the class comment) and what it shows (empty = the altar's own picture). Tests read `looks`.
var lamp_cover: Node2D
var lamp_flames: Node2D
var looks: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	sprite = Sprite2D.new()
	sprite.name = &"Sprite"
	sprite.texture = LIT
	sprite.centered = false
	sprite.light_mask = Config.LIGHT_LAYER_WORLD
	add_child(sprite)
	flames = Sprite2D.new()
	flames.name = &"Flames"
	flames.texture = flame_texture()
	flames.centered = false
	flames.material = unshaded_material()
	sprite.add_child(flames)
	lamp_cover = Node2D.new()
	lamp_cover.name = &"LampCover"
	lamp_cover.light_mask = Config.LIGHT_LAYER_WORLD
	lamp_cover.draw.connect(_draw_cover)
	sprite.add_child(lamp_cover)
	lamp_flames = Node2D.new()
	lamp_flames.name = &"LampFlames"
	lamp_flames.material = unshaded_material()
	lamp_flames.draw.connect(_draw_flames)
	sprite.add_child(lamp_flames)


## Places the altar on a footprint given in cells.
func setup(footprint_cells: Rect2i) -> void:
	footprint_px = Rect2i(footprint_cells.position * Config.TILE, footprint_cells.size * Config.TILE)
	position = Vector2(footprint_px.position.x + footprint_px.size.x / 2.0, footprint_px.end.y)
	sprite.position = Vector2(footprint_px.position) - position


## Top-left of the art in world pixels.
func art_origin() -> Vector2i:
	return footprint_px.position


static func flame_image() -> Image:
	if _flame_image == null:
		_flame_image = LightGen.emissive_mask(LIT.get_image(), UNLIT.get_image(), Config.FLAME_MIN_LUMA)
	return _flame_image


static func flame_texture() -> ImageTexture:
	if _flame_texture == null:
		_flame_texture = ImageTexture.create_from_image(flame_image())
	return _flame_texture


static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


# --- M10a: the lamps during a prayer ------------------------------------------------------------------------------

## How lamp state `state` (Prayer.Lamp) changed `age` ticks ago looks; `current` = it is being answered now.
static func lamp_look(state: int, age: int, current: bool) -> int:
	match state:
		Prayer.Lamp.LIT:
			return Look.LIT
		Prayer.Lamp.OUT:
			if age < Config.PRAYER_FLICKER_TICKS:
				return Look.GUTTER if (age / Config.PRAYER_FLICKER_STEP) % 2 == 0 else Look.UNLIT
			return Look.SOOT
	return Look.EMBER if current else Look.UNLIT


## Lamp `i`'s box in the picture (Config.PRAYER_LAMP_BOX around its flame).
static func lamp_box(i: int) -> Rect2i:
	return Rect2i(Config.PRAYER_LAMP_FLAMES[i] + Config.PRAYER_LAMP_BOX.position, Config.PRAYER_LAMP_BOX.size)


## Shows the lamps as `p_looks` (Look per lamp, in Config.PRAYER_LAMP_FLAMES order); empty = the altar's own picture again.
func show_lamps(p_looks: PackedInt32Array) -> void:
	if p_looks == looks:
		return
	looks = p_looks.duplicate()
	flames.visible = looks.is_empty()
	lamp_cover.queue_redraw()
	lamp_flames.queue_redraw()


func _draw_cover() -> void:
	for i: int in mini(looks.size(), Config.PRAYER_LAMP_FLAMES.size()):
		if looks[i] != Look.LIT:
			var b: Rect2 = Rect2(lamp_box(i))
			lamp_cover.draw_texture_rect_region(UNLIT, b, b)


func _draw_flames() -> void:
	for i: int in mini(looks.size(), Config.PRAYER_LAMP_FLAMES.size()):
		var f: Vector2i = Config.PRAYER_LAMP_FLAMES[i]
		match looks[i]:
			Look.LIT:
				var r: Rect2 = Rect2(Vector2(f), Vector2(FLAME_SIZE))
				lamp_flames.draw_texture_rect_region(flame_texture(), r, r)
			Look.EMBER:
				for q: Vector2i in EMBER_PIXELS:
					lamp_flames.draw_rect(Rect2(Vector2(f + q), Vector2.ONE), EMBER)
			Look.SOOT:
				for q: Vector2i in SOOT_PIXELS:
					lamp_flames.draw_rect(Rect2(Vector2(f + q), Vector2.ONE), SOOT)
			Look.GUTTER:
				for q: Vector2i in GUTTER_BASE_PIXELS:
					lamp_flames.draw_rect(Rect2(Vector2(f + q), Vector2.ONE), GUTTER_BASE)
				for q: Vector2i in GUTTER_TIP_PIXELS:
					lamp_flames.draw_rect(Rect2(Vector2(f + q), Vector2.ONE), GUTTER_TIP)
