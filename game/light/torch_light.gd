class_name TorchLight
extends RefCounted
## Light of a torch (M3a): a PointLight2D at texture scale 1 whose texture is a disc of hard
## concentric steps (no dither, so a face on the edge does not get a checkerboard; the altar light
## needs a hard copy for characters for the same reason). It lights the ground and the actors.
## Light only: the safe zone stays the altar's (SafeZone), whether a torch counts as safety is not in
## the docs. Textures are built once per radius and kept (AltarLight's rule: never swap a light's
## texture while the old one is freed in 4.7.2).

## PROVISIONAL look (not in docs): light amount per step and where each step ends (fraction of the
## radius).
const STEP_AMOUNTS: PackedFloat32Array = [1.0, 0.7, 0.45, 0.22]
const STEP_ENDS: PackedFloat32Array = [0.45, 0.7, 0.88, 1.0]

static var _textures: Dictionary[int, ImageTexture] = {}


## Light amount at distance `d` px from the centre of a torch of `radius` px.
static func amount_at(d: float, radius: int) -> float:
	for i: int in STEP_ENDS.size():
		if d <= STEP_ENDS[i] * radius:
			return STEP_AMOUNTS[i]
	return 0.0


## White RGB, alpha = light amount; 2 * (radius + 1) texels, the centre between the middle texels.
static func image(radius: int) -> Image:
	var size: int = 2 * (radius + 1)
	var data: PackedByteArray = PackedByteArray()
	data.resize(size * size * 4)
	var i: int = 0
	var c: float = size / 2.0
	for y: int in size:
		for x: int in size:
			var a: float = amount_at(Vector2(x + 0.5 - c, y + 0.5 - c).length(), radius)
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
			data[i + 3] = roundi(a * 255.0)
			i += 4
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)


static func texture_for(radius: int) -> ImageTexture:
	if not _textures.has(radius):
		_textures[radius] = ImageTexture.create_from_image(image(radius))
	return _textures[radius]


## A torch light of `radius` px and `energy` at `pos` (world px), on the ground and actor light layers.
static func make(radius: int, energy: float, pos: Vector2) -> PointLight2D:
	var l: PointLight2D = PointLight2D.new()
	l.texture = texture_for(radius)
	l.texture_scale = 1.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.color = Config.TORCH_LIGHT_COLOR
	l.energy = energy
	l.range_item_cull_mask = Config.LIGHT_LAYER_WORLD | Config.LIGHT_LAYER_ACTORS
	l.shadow_enabled = false
	l.position = pos
	return l
