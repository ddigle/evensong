extends Node2D
## Light spike demo (res://light/light_demo.tscn): an evening grass field, the 3x3-lamp altar whose
## PointLight2D draws the safe zone, emissive flames, a normal-mapped altar (CanvasTexture), a wall
## block with a LightOccluder2D, and characters inside, outside and walking across the edge.
##
## Keys: E edge mode, N normal maps, F flame material, C evening (CanvasModulate), S shadows,
##       L lantern, A actor light split, +/- safe radius, Space pause the walker, H HUD.
##       F10 = menu (SpikeCli).
##
## Light layers: world items (ground, altar, wall) use light_mask 1, characters use 2. With the
## actor split on, AltarLight lights layer 1 with the chosen edge and AltarLightActors lights layer 2
## with a hard edge, so a dithered ground edge never draws a checkerboard on a face.
##
## Everything generated (light textures, normal maps, flame mask, wall block, ground tile set) is
## built in code from our PNGs in res://art/light/ and kept in the *_image vars for the tests.

const LightGen := preload("res://light/light_gen.gd")

const TILE: int = 16
const ALTAR_LIT: Texture2D = preload("res://art/light/altar_v04.png")
const ALTAR_UNLIT: Texture2D = preload("res://art/light/altar_v04_unlit.png")
const GRASS: Texture2D = preload("res://art/light/tiles_grass_base_v02.png")

## Flames: pixels that change between altar_v04 and altar_v04_unlit and are at least this bright
## (0-255 luma). Keeps the 3 flame colours, drops the warm glow on the stone and the bowl rims.
const FLAME_MIN_LUMA: float = 148.0
## First row of the altar's vertical front face in altar_v04 (rows 40-46, outline 47).
const ALTAR_FRONT_FACE_TOP: int = 40
const WALL_FRONT_FACE_TOP: int = 16
## Ground filled with grass: tiles (-1..30, -1..17) cover the 480x270 base view.
const GROUND_RECT: Rect2i = Rect2i(-1, -1, 32, 19)
## CanvasItem.light_mask / Light2D.range_item_cull_mask bits.
const LIGHT_LAYER_WORLD: int = 1
const LIGHT_LAYER_ACTORS: int = 2

enum FlameMode { UNSHADED, SHADED }

## Safe-zone radius in tiles. The light texture is built from this, and is_in_safe_zone() uses it,
## so what you see is what the game rule uses.
@export var safe_radius_tiles: float = 7.0
@export var edge_mode: LightGen.Edge = LightGen.Edge.DITHER
## Width of the dithered/banded/smooth edge in base pixels.
@export var edge_band_px: int = 16
## Evening darkness. Multiplies the whole canvas. Warm grey: shadows stay brown, never blue (§10).
@export var evening_color: Color = Color(0.40, 0.34, 0.31)
@export var evening_enabled: bool = true
@export var altar_light_color: Color = Color(1.0, 0.97, 0.91)
## Light added inside the zone. evening + light ~ 1.0 keeps lit art at its painted colours.
@export var altar_light_energy: float = 0.65
## PointLight2D.height, used only by normal-mapped items (N.L).
@export var altar_light_height: float = 64.0
@export var altar_light_enabled: bool = true
@export var shadows_enabled: bool = true
## OccluderPolygon2D.cull_mode of the wall footprint. Decides whether the wall's own pixels are
## shadowed (CULL_DISABLED) or only the ground behind it (see notes/light.md).
@export var occluder_cull_mode: OccluderPolygon2D.CullMode = OccluderPolygon2D.CULL_COUNTER_CLOCKWISE
@export var normal_maps_enabled: bool = true
@export var flame_mode: FlameMode = FlameMode.UNSHADED
@export var lantern_enabled: bool = true
@export var lantern_radius_px: int = 40
## true: characters get their own hard-edged altar light (AltarLightActors) instead of the
## dithered/banded one. false: one light for everything.
@export var actor_light_split: bool = true
## false = frozen pose (captures, tests): no walking, no flicker.
@export var animate: bool = true
## Walker path parameter (radians around the altar). Captures set it for a fixed pose.
@export var walker_angle: float = 6.18

var light_image: Image
var actor_light_image: Image
var lantern_image: Image
var altar_lit_image: Image
var altar_unlit_image: Image
var flame_image: Image
var altar_normal_image: Image
var wall_image: Image
var wall_normal_image: Image

var altar_canvas_texture: CanvasTexture
var wall_canvas_texture: CanvasTexture
var wall_plain_texture: ImageTexture
var flame_material: CanvasItemMaterial
var grass_source_id: int = -1

var _time: float = 0.0
var _walk_frame_time: float = 0.0
var _built_light_key: String = ""
var _built_actor_key: String = ""
var _built_lantern_key: String = ""
var _texture_cache: Dictionary = {}  # key -> Image, and key + "#tex" -> ImageTexture

@onready var ground: TileMapLayer = $Ground
@onready var world: Node2D = $World
@onready var altar: Sprite2D = $World/Altar
@onready var flames: Sprite2D = $World/Altar/Flames
@onready var altar_light: PointLight2D = $World/Altar/AltarLight
@onready var altar_light_actors: PointLight2D = $World/Altar/AltarLightActors
@onready var wall: Sprite2D = $World/Wall
@onready var occluder: LightOccluder2D = $World/Wall/Occluder
@onready var hero_inside: Sprite2D = $World/HeroInside
@onready var lantern: PointLight2D = $World/HeroOutside/Lantern
@onready var hero_outside: Sprite2D = $World/HeroOutside
@onready var walker: Sprite2D = $World/Walker
@onready var evening: CanvasModulate = $Evening
@onready var hud: Label = $Hud/Label


func _ready() -> void:
	_build_ground()
	_build_altar()
	_build_wall()
	apply_settings()
	place_walker(walker_angle)
	hud.visible = animate


func _process(delta: float) -> void:
	if animate:
		_time += delta
		place_walker(fposmod(walker_angle + delta * 0.25, TAU))
		_walk_frame_time += delta
		walker.frame_coords.x = int(_walk_frame_time * 10.0) % walker.hframes
		altar_light.energy = altar_light_energy * (1.0 + 0.03 * sin(_time * 13.0) + 0.02 * sin(_time * 7.3))
		altar_light_actors.energy = altar_light.energy
	if hud.visible:
		hud.text = hud_text()


# --- public API (tests, capture) -------------------------------------------------------------

func safe_radius_px() -> int:
	return roundi(safe_radius_tiles * float(TILE))


## The gameplay rule and the picture share one number: inside = within the light's radius.
func is_in_safe_zone(world_pos: Vector2) -> bool:
	return world_pos.distance_to(altar_light.global_position) <= float(safe_radius_px())


## Effective reach of the altar light in pixels (texture half-size x texture_scale).
func light_reach_px() -> float:
	if altar_light.texture == null:
		return 0.0
	return float(altar_light.texture.get_width()) * altar_light.texture_scale * 0.5


## Pushes the exported settings to the nodes. Light textures are built once per setting and cached:
## in 4.7.2, giving a PointLight2D a new texture while the old one is freed in the same call logs
## "Parameter t is null" (texture_remove_from_decal_atlas), so old textures must stay referenced.
func apply_settings() -> void:
	var r: int = safe_radius_px()
	var origin: Vector2i = Vector2i(altar_light.global_position.round()) - Vector2i(r, r)
	var key: String = "%d/%d/%d/%s" % [r, edge_mode, edge_band_px, origin]
	if key != _built_light_key:
		if not _texture_cache.has(key):
			_texture_cache[key] = LightGen.safe_zone_light_image(r, edge_mode, edge_band_px, origin)
		light_image = _texture_cache[key]
		altar_light.texture = _light_texture(key, light_image)
		_built_light_key = key
	altar_light.texture_scale = 1.0
	altar_light.enabled = altar_light_enabled
	altar_light.color = altar_light_color
	altar_light.energy = altar_light_energy
	altar_light.height = altar_light_height
	altar_light.blend_mode = Light2D.BLEND_MODE_ADD
	altar_light.shadow_enabled = shadows_enabled
	altar_light.shadow_filter = Light2D.SHADOW_FILTER_NONE
	occluder.occluder.cull_mode = occluder_cull_mode

	# Characters (light_mask 2): their own hard-edged copy of the altar light, or the world light.
	var akey: String = "%d/%d/%d/%s" % [r, LightGen.Edge.HARD, 0, origin]
	if akey != _built_actor_key:
		if not _texture_cache.has(akey):
			_texture_cache[akey] = LightGen.safe_zone_light_image(r, LightGen.Edge.HARD, 0, origin)
		actor_light_image = _texture_cache[akey]
		altar_light_actors.texture = _light_texture(akey, actor_light_image)
		_built_actor_key = akey
	altar_light.range_item_cull_mask = LIGHT_LAYER_WORLD if actor_light_split else (LIGHT_LAYER_WORLD | LIGHT_LAYER_ACTORS)
	altar_light_actors.range_item_cull_mask = LIGHT_LAYER_ACTORS
	altar_light_actors.enabled = altar_light_enabled and actor_light_split
	altar_light_actors.texture_scale = 1.0
	altar_light_actors.color = altar_light_color
	altar_light_actors.energy = altar_light_energy
	altar_light_actors.height = altar_light_height
	altar_light_actors.blend_mode = Light2D.BLEND_MODE_ADD
	altar_light_actors.shadow_enabled = shadows_enabled
	altar_light_actors.shadow_filter = Light2D.SHADOW_FILTER_NONE
	lantern.range_item_cull_mask = LIGHT_LAYER_WORLD | LIGHT_LAYER_ACTORS

	var lkey: String = "lantern/%d/%d" % [lantern_radius_px, edge_mode]
	if lkey != _built_lantern_key:
		# The lantern moves, so its dither is anchored to the light, not the world (it swims; see notes).
		if not _texture_cache.has(lkey):
			_texture_cache[lkey] = LightGen.safe_zone_light_image(lantern_radius_px, edge_mode, 8)
		lantern_image = _texture_cache[lkey]
		lantern.texture = _light_texture(lkey, lantern_image)
		_built_lantern_key = lkey
	lantern.enabled = lantern_enabled

	evening.visible = evening_enabled
	evening.color = evening_color

	# Toggle by swapping textures; the CanvasTexture keeps its normal map (replacing normal_texture
	# at runtime logged "Attempted to free invalid ID" from RenderingDevice in 4.7.2).
	altar.texture = altar_canvas_texture if normal_maps_enabled else ALTAR_LIT
	wall.texture = wall_canvas_texture if normal_maps_enabled else wall_plain_texture
	flames.material = flame_material if flame_mode == FlameMode.UNSHADED else null


func _light_texture(key: String, img: Image) -> ImageTexture:
	var tex_key: String = key + "#tex"
	if not _texture_cache.has(tex_key):
		_texture_cache[tex_key] = ImageTexture.create_from_image(img)
	return _texture_cache[tex_key]


func hud_text() -> String:
	var fps: float = Engine.get_frames_per_second()
	return "light edge=%s R=%.1ft(%dpx) actors=%s normal=%s flame=%s eve=%s shadow=%s %d fps\nE edge A actors N normal F flame C eve S shadow L lantern +/- radius H hud" % [
		LightGen.EDGE_NAMES[edge_mode], safe_radius_tiles, safe_radius_px(),
		"split" if actor_light_split else "shared",
		"on" if normal_maps_enabled else "off", "unshaded" if flame_mode == FlameMode.UNSHADED else "shaded",
		"on" if evening_enabled else "off", "on" if shadows_enabled else "off", roundi(fps)]


# --- building ----------------------------------------------------------------------------------

func _build_ground() -> void:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = GRASS
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	grass_source_id = tile_set.add_source(source)
	ground.tile_set = tile_set
	for y: int in range(GROUND_RECT.position.y, GROUND_RECT.end.y):
		for x: int in range(GROUND_RECT.position.x, GROUND_RECT.end.x):
			ground.set_cell(Vector2i(x, y), grass_source_id, Vector2i.ZERO)


func _build_altar() -> void:
	altar_lit_image = LightGen.to_rgba8(ALTAR_LIT.get_image())
	altar_unlit_image = LightGen.to_rgba8(ALTAR_UNLIT.get_image())
	flame_image = LightGen.emissive_mask(altar_lit_image, altar_unlit_image, FLAME_MIN_LUMA)
	altar_normal_image = LightGen.normal_map(altar_lit_image, 2.0, 1.0, 1.5, ALTAR_FRONT_FACE_TOP, 1.0)
	altar_canvas_texture = CanvasTexture.new()
	altar_canvas_texture.diffuse_texture = ALTAR_LIT
	altar_canvas_texture.normal_texture = ImageTexture.create_from_image(altar_normal_image)
	altar.texture = altar_canvas_texture
	flames.texture = ImageTexture.create_from_image(flame_image)
	flame_material = CanvasItemMaterial.new()
	flame_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED


func _build_wall() -> void:
	wall_image = LightGen.wall_block_image()
	wall_normal_image = LightGen.normal_map(wall_image, 2.0, 1.0, 1.5, WALL_FRONT_FACE_TOP, 1.0)
	wall_canvas_texture = CanvasTexture.new()
	wall_plain_texture = ImageTexture.create_from_image(wall_image)
	wall_canvas_texture.diffuse_texture = wall_plain_texture
	wall_canvas_texture.normal_texture = ImageTexture.create_from_image(wall_normal_image)
	wall.texture = wall_canvas_texture


## Walker path: around the altar light, swinging 20 px in and out of the safe-zone edge.
func walker_path(angle: float) -> Vector2:
	var r: float = float(safe_radius_px()) + 20.0 * sin(angle * 3.0)
	var centre: Vector2 = altar_light.position + altar.position
	return centre + Vector2(cos(angle), sin(angle) * 0.8) * r


## Puts the walker on its path at `angle`, facing along the path, on a whole pixel.
func place_walker(angle: float) -> void:
	walker_angle = angle
	walker.position = walker_path(angle).round()
	_face(walker, walker_path(angle + 0.01) - walker_path(angle))


## Walk sheet rows: 0 south, 1 east (west = flipped), 2 north.
static func _face(sprite: Sprite2D, velocity: Vector2) -> void:
	if velocity.length_squared() < 0.0001:
		return
	if absf(velocity.x) > absf(velocity.y):
		sprite.frame_coords.y = 1
		sprite.flip_h = velocity.x < 0.0
	else:
		sprite.frame_coords.y = 0 if velocity.y > 0.0 else 2
		sprite.flip_h = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_E:
			edge_mode = ((edge_mode + 1) % LightGen.EDGE_NAMES.size()) as LightGen.Edge
		KEY_N:
			normal_maps_enabled = not normal_maps_enabled
		KEY_F:
			flame_mode = (FlameMode.SHADED if flame_mode == FlameMode.UNSHADED else FlameMode.UNSHADED)
		KEY_C:
			evening_enabled = not evening_enabled
		KEY_S:
			shadows_enabled = not shadows_enabled
		KEY_L:
			lantern_enabled = not lantern_enabled
		KEY_A:
			actor_light_split = not actor_light_split
		KEY_EQUAL, KEY_KP_ADD:
			safe_radius_tiles = minf(safe_radius_tiles + 0.5, 12.0)
		KEY_MINUS, KEY_KP_SUBTRACT:
			safe_radius_tiles = maxf(safe_radius_tiles - 0.5, 2.0)
		KEY_SPACE:
			animate = not animate
		KEY_H:
			hud.visible = not hud.visible
		_:
			return
	apply_settings()
	get_viewport().set_input_as_handled()
