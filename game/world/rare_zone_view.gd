class_name RareZoneView
extends Node2D
## M11b: the rare zone's picture (world/rare_zone.gd). PLACEHOLDER drawn in code, on the view only (no tile changes: the ground stays
## what the generator made): a faint gold tint over the disc, dithered away over its last EDGE_PX, and Config.RARE_ZONE_MARKERS boundary
## stones around the rim, each a small grey stone with a lamp on top. The tint and the stones are shaded like the ground (the
## evening darkens them); the lamp flames are unshaded, so the rim reads at dusk. It sits above the ground and below the entities. A real
## picture replaces image() and tint_image() alone.

## IMPL: the tint (§4 faith gold, faint), the rim's dithered band.
const TINT: Color = Color(0.957, 0.788, 0.365, 0.10)
const EDGE_PX: int = 16
## The stone (bottom middle on its spot); FLAME_ROW holds the flame's pixels ("g" faith gold, "s" faith ivory: ItemIcons.PALETTE). A
## plain Array like ItemIcons.MAPS.
const STONE: Array = [
	"...kkk...",
	"..kgsgk..",
	"..kkkkk..",
	"...kmk...",
	"..kmhmk..",
	".kmmhmmk.",
	".kmmmmdk.",
	"kmmmmmddk",
	"kkkkkkkkk",
]
const FLAME_ROW: int = 1
const FLAME: String = "gs"
## Bayer 4x4 (the altar light's dither).
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

static var _tints: Dictionary[int, ImageTexture] = {}
static var _stone: ImageTexture = null
static var _flame: ImageTexture = null

var zone: RareZone
## Tiles a boundary stone stands on (bottom middle on the tile's bottom middle).
var spots: Array[Vector2i] = []
var tint: Sprite2D
var stones: Node2D
var flames: Node2D


func _init() -> void:
	name = &"RareZone"
	tint = Sprite2D.new()
	tint.name = &"Tint"
	tint.centered = false
	add_child(tint)
	stones = Node2D.new()
	stones.name = &"Stones"
	stones.draw.connect(_draw_stones)
	add_child(stones)
	flames = Node2D.new()
	flames.name = &"Flames"
	flames.material = FixtureView.unshaded_material()
	flames.draw.connect(_draw_flames)
	add_child(flames)


## Shows `data`'s zone (none: nothing shows).
func setup(data: WorldData) -> void:
	zone = data.rare_zone if data != null else null
	visible = zone != null
	spots.clear()
	if zone == null:
		return
	spots = marker_spots(data, zone)
	var half: int = roundi(zone.radius_px())
	tint.texture = tint_texture(half)
	tint.position = zone.center_px() - Vector2(half, half)
	stones.queue_redraw()
	flames.queue_redraw()


## The tiles the boundary stones stand on: Config.RARE_ZONE_MARKERS spaced around the rim, each the first of the tile under the rim
## point and the next two nearer the middle that is open and holds nothing; none free: that stone is left out.
static func marker_spots(data: WorldData, z: RareZone) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var mid: Vector2 = z.center_px()
	for i: int in Config.RARE_ZONE_MARKERS:
		var dir: Vector2 = Vector2.from_angle(TAU * i / Config.RARE_ZONE_MARKERS)
		for back: int in 3:
			var c: Vector2i = Aim.cell_of(mid + dir * (z.radius_px() - Config.TILE * (back + 0.5)))
			if RareZone.open_tile(data, c) and data.get_value(WorldData.Layer.VEGETATION, c) == 0 \
					and data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_NONE:
				out.append(c)
				break
	return out


## Whether the tint covers picture point (`x`, `y`), `d` px from the middle of a disc of `half` px: nothing outside, all of it inside
## half - EDGE_PX, the Bayer pattern thinning it out across the band.
static func tint_on(x: int, y: int, d: float, half: float) -> bool:
	if d > half:
		return false
	if d <= half - EDGE_PX:
		return true
	return BAYER[posmod(y, 4) * 4 + posmod(x, 4)] + 0.5 < 16.0 * (half - d) / EDGE_PX


## The tint picture of a disc of `half` px (2 * half + 1 square, the disc's middle at its middle).
static func tint_image(half: int) -> Image:
	var size: int = half * 2 + 1
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y: int in size:
		for x: int in size:
			if tint_on(x, y, Vector2(x - half, y - half).length(), float(half)):
				img.set_pixel(x, y, TINT)
	return img


static func tint_texture(half: int) -> ImageTexture:
	if not _tints.has(half):
		_tints[half] = ImageTexture.create_from_image(tint_image(half))
	return _tints[half]


## The boundary stone: every pixel of STONE, or only the flame's (`flame_only`).
static func image(flame_only: bool = false) -> Image:
	var first: String = STONE[0]
	var img: Image = Image.create_empty(first.length(), STONE.size(), false, Image.FORMAT_RGBA8)
	for y: int in STONE.size():
		var row: String = STONE[y]
		for x: int in row.length():
			var ch: String = row[x]
			if ItemIcons.PALETTE.has(ch) and (not flame_only or (y == FLAME_ROW and FLAME.contains(ch))):
				img.set_pixel(x, y, ItemIcons.PALETTE[ch])
	return img


## Where the stone's picture's top-left goes for spot `c`.
static func stone_at(c: Vector2i) -> Vector2:
	var first: String = STONE[0]
	return Vector2((c.x + 0.5) * Config.TILE - first.length() / 2, (c.y + 1) * Config.TILE - STONE.size())


func _draw_stones() -> void:
	if _stone == null:
		_stone = ImageTexture.create_from_image(image())
	for c: Vector2i in spots:
		stones.draw_texture(_stone, stone_at(c))


func _draw_flames() -> void:
	if _flame == null:
		_flame = ImageTexture.create_from_image(image(true))
	for c: Vector2i in spots:
		flames.draw_texture(_flame, stone_at(c))
