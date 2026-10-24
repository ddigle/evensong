class_name AltarLight
extends Node2D
## The altar's light = the safe zone (game-concept §9.3, §12 "2D 조명 (제단 빛 = 안전 반경)").
## Two PointLight2D at the zone centre with texture_scale 1 (one texel = one world pixel):
##   GroundLight  dithered edge (provisional), lights Config.LIGHT_LAYER_WORLD (ground, altar)
##   ActorLight   hard edge copy, lights Config.LIGHT_LAYER_ACTORS (characters), so a dithered
##                edge never draws a checkerboard on a face (spike RESULTS §4)
## Both textures come from LightGen.zone_light_image() of the same SafeZone. Textures are built once
## per zone shape and kept in a static cache: in 4.7.2, giving a PointLight2D a new texture while the
## old one is freed logs "Parameter t is null" (spike RESULTS §4), so no texture is ever released.
## M5-fix: the image depends on the centre only through its phase (cache_key), and the node stands at the
## centre, so one pair serves every place the altar is put down (the altar's centre is always 16n + 8).

static var _images: Dictionary[String, Image] = {}
static var _textures: Dictionary[String, ImageTexture] = {}

var zone: SafeZone
var ground_light: PointLight2D
var actor_light: PointLight2D


func _init() -> void:
	ground_light = _new_light(&"GroundLight", Config.LIGHT_LAYER_WORLD)
	actor_light = _new_light(&"ActorLight", Config.LIGHT_LAYER_ACTORS)


func _new_light(node_name: StringName, mask: int) -> PointLight2D:
	var l: PointLight2D = PointLight2D.new()
	l.name = node_name
	l.range_item_cull_mask = mask
	l.texture_scale = 1.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.color = Config.ALTAR_LIGHT_COLOR
	l.energy = Config.ALTAR_LIGHT_ENERGY
	l.shadow_enabled = false
	l.enabled = false
	add_child(l)
	return l


func setup(p_zone: SafeZone) -> void:
	zone = p_zone
	position = zone.center.round()
	if zone.radius <= 0.0:
		ground_light.enabled = false
		actor_light.enabled = false
		return
	ground_light.texture = texture_for(zone, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX)
	actor_light.texture = texture_for(zone, LightGen.Edge.HARD, 0)
	set_lit(true)


func set_lit(on: bool) -> void:
	var ok: bool = zone != null and zone.radius > 0.0
	ground_light.enabled = on and ok
	actor_light.enabled = on and ok


func is_lit() -> bool:
	return ground_light.enabled


## M5-fix: the image of a zone (LightGen.zone_light_image) reads the centre only through the 4x4 Bayer phase of its
## texels (the origin is round(centre) minus a half size fixed by the radius, and the dither threshold is posmod(px, 4):
## so round(centre) mod 4) and the centre's fraction (the disc test is relative to the centre). Two zones with the same
## edge, band, radius, phase and fraction give the same texels, so they share one cached image and texture
## (tests/test_light.gd compares the bytes). Before, the key was the whole centre and every new altar place built two more.
static func cache_key(p_zone: SafeZone, edge: LightGen.Edge, band: int) -> String:
	var whole: Vector2i = Vector2i(roundi(p_zone.center.x), roundi(p_zone.center.y))
	var phase: Vector2i = Vector2i(posmod(whole.x, 4), posmod(whole.y, 4))
	var fraction: Vector2 = p_zone.center - Vector2(whole)
	return "%d/%d/%s/%s/%s" % [edge, band, p_zone.radius, phase, fraction]


## Cached light image of a zone (built on first use).
static func image_for(p_zone: SafeZone, edge: LightGen.Edge, band: int) -> Image:
	var key: String = cache_key(p_zone, edge, band)
	if not _images.has(key):
		_images[key] = LightGen.zone_light_image(p_zone, edge, band)
	return _images[key]


## Cached texture of a zone (the same object every time for the same zone and edge).
static func texture_for(p_zone: SafeZone, edge: LightGen.Edge, band: int) -> ImageTexture:
	var key: String = cache_key(p_zone, edge, band)
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(image_for(p_zone, edge, band))
	return _textures[key]


static func cached_texture_count() -> int:
	return _textures.size()
