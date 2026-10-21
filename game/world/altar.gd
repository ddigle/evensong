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

const LIT: Texture2D = preload("res://art/env/altar_v04.png")
const UNLIT: Texture2D = preload("res://art/env/altar_v04_unlit.png")

static var _flame_image: Image
static var _flame_texture: ImageTexture
static var _unshaded: CanvasItemMaterial

var footprint_px: Rect2i
var sprite: Sprite2D
var flames: Sprite2D


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
