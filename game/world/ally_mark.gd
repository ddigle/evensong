class_name AllyMark
extends Node2D
## M9a: the small ring under the ally a heal or buff would go to now (● gameplay-design §2.1 R42 "커서에서 가장 가까운 아군이
## 받는다"; Skills.aim_target: the cleric's heal while it is ready, the herbalist's throw while a healing or buff potion is
## selected). A PLACEHOLDER drawn in code (no art): a faith-gold ellipse around the feet, unshaded so it reads in the evening
## and the dungeon. Main puts it between the ground and the entities (like the TargetMarker) and moves it to the ally's feet
## every physics tick (offline; M9c in sessions). Layout values are IMPL. M9 review: the ring is ash grey (DIM) while a press
## would be refused on that ally (the cleric's heal on an ally at full HP, Skills.aim_refused); no ring while a panel is open.

## The ring, centred on the feet: MAP_ORIGIN is the feet's place in the map (the ellipse's middle row one px above the feet).
const MAP: Array = [
	"....ggggggg....",
	"..gg.......gg..",
	".g...........g.",
	"..gg.......gg..",
	"....ggggggg....",
]
const MAP_ORIGIN: Vector2i = Vector2i(7, 3)
const GOLD: Color = Color8(0xf4, 0xc9, 0x5d)
## M9 review (IMPL): the refused ring's colour (the HUD's ash grey family).
const DIM: Color = Color8(0x8a, 0x86, 0x7c)

static var _texture: ImageTexture
static var _dim_texture: ImageTexture

var sprite: Sprite2D
## The player it is under (null = hidden) and whether it shows dim. Tests read them.
var target: Player
var dim: bool = false


func _init() -> void:
	name = &"AllyMark"
	sprite = Sprite2D.new()
	sprite.name = &"Ring"
	sprite.texture = texture()
	sprite.centered = false
	sprite.position = -Vector2(MAP_ORIGIN)
	sprite.material = FixtureView.unshaded_material()
	sprite.light_mask = Config.LIGHT_LAYER_ACTORS
	add_child(sprite)
	visible = false


static func image(colour: Color = GOLD) -> Image:
	var first: String = MAP[0]
	var img: Image = Image.create_empty(first.length(), MAP.size(), false, Image.FORMAT_RGBA8)
	for y: int in MAP.size():
		var row: String = MAP[y]
		for x: int in row.length():
			if row[x] == "g":
				img.set_pixel(x, y, colour)
	return img


static func texture(p_dim: bool = false) -> ImageTexture:
	if p_dim:
		if _dim_texture == null:
			_dim_texture = ImageTexture.create_from_image(image(DIM))
		return _dim_texture
	if _texture == null:
		_texture = ImageTexture.create_from_image(image())
	return _texture


## Shows the ring under `p` (its drawn feet), or hides it (null). M9 review: `p_dim` = the press would be refused (ash grey).
func show_for(p: Player, p_dim: bool = false) -> void:
	target = p if p != null and is_instance_valid(p) else null
	visible = target != null
	dim = p_dim and target != null
	sprite.texture = texture(dim)
	if target != null:
		position = target.position
