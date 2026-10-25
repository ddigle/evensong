class_name BuildGhost
extends Node2D
## M7b: where the selected build piece would go (items/building.gd; ○ gameplay-design §3.3 "그리드 스냅 배치"): the piece's
## own picture on the aimed tile (grid-snapped: the target tile), every other pixel only (a checkerboard on the world's
## pixel grid, so it reads as not yet built and every drawn pixel is exact), and a 1 px outline of the tiles it would block
## (a wall or a door: its tile and its face tile; a lantern post: its tile; a floor piece: its tile). Faith gold when it may
## go there, deep red (the checkerboard too) when not (Building.refusal). PLACEHOLDER drawn in code (brief §4 colours, like
## the M5b AltarGhost); unshaded so the evening does not hide it. Main shows it while the local player has a piece
## selected and aims, between the ground and the entities like the target marker.

const GOLD: Color = Color8(0xf4, 0xc9, 0x5d)   # brief §4 faith
const RED: Color = Color8(0x5c, 0x10, 0x10)    # brief §4 deep red

var cell: Vector2i = Vector2i.ZERO
var piece: StringName = &""
var allowed: bool = false
## Main's cache: what the last answer was worked out for (cell, piece, world revision, pieces held, tick bucket).
var key: Array = []

static var _images: Dictionary[String, ImageTexture] = {}


func _init() -> void:
	name = &"BuildGhost"
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	visible = false


## Shows piece `p_piece` on tile `p_cell` (allowed or not); an empty piece hides it.
func show_at(p_piece: StringName, p_cell: Vector2i, p_allowed: bool) -> void:
	visible = not p_piece.is_empty()
	position = Vector2(p_cell * Config.TILE)
	if piece == p_piece and cell == p_cell and allowed == p_allowed:
		return
	piece = p_piece
	cell = p_cell
	allowed = p_allowed
	queue_redraw()


func hide_ghost() -> void:
	visible = false
	key = []


func _draw() -> void:
	if piece.is_empty():
		return
	draw_texture(texture_for(piece, allowed), Vector2(art_offset(piece)))
	var c: Color = GOLD if allowed else RED
	for p: Vector2i in outline_pixels(piece):
		draw_rect(Rect2(Vector2(p), Vector2.ONE), c)


## Where the piece's picture's top-left sits from the tile's top-left (px).
static func art_offset(p_piece: StringName) -> Vector2i:
	if p_piece == Building.LANTERN:
		return FixtureView.post_origin(Vector2i.ZERO)
	return Vector2i.ZERO


## The piece's picture as built alone (no neighbours): a wall = the lone top + the lone face below it, a door = the lone top
## + the closed door, a floor = floor piece A, a lantern = the post (RGBA8).
static func piece_image(p_piece: StringName) -> Image:
	var sheet: Image = LightGen.to_rgba8(BuildView.SHEET.get_image())
	var t: int = Config.TILE
	match p_piece:
		Building.STONE_WALL, Building.DOOR:
			var img: Image = Image.create_empty(t, t + BuildView.FACE_SIZE.y, false, Image.FORMAT_RGBA8)
			img.blit_rect(sheet, Rect2i(0, 0, t, t), Vector2i.ZERO)
			var face_x: int = BuildView.DOOR_CLOSED_X if p_piece == Building.DOOR else 0
			img.blend_rect(sheet, Rect2i(Vector2i(face_x, BuildView.FACES_Y), BuildView.FACE_SIZE), Vector2i(0, t))
			return img
		Building.STONE_FLOOR:
			return sheet.get_region(Rect2i(BuildView.FLOORS_AT, Vector2i(t, t)))
		Building.LANTERN:
			return LightGen.to_rgba8(FixtureView.POST.get_image())
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


## The ghost picture: piece_image's opaque pixels on the world's even checkerboard squares ((x + y) even in world px, the
## tile's top-left being even), in their own colours when `p_allowed`, else all RED.
static func ghost_image(p_piece: StringName, p_allowed: bool) -> Image:
	var src: Image = piece_image(p_piece)
	var off: Vector2i = art_offset(p_piece)
	var out: Image = Image.create_empty(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y: int in src.get_height():
		for x: int in src.get_width():
			var px: Color = src.get_pixel(x, y)
			if px.a8 < 128 or posmod(x + off.x + y + off.y, 2) != 0:
				continue
			out.set_pixel(x, y, Color(px.r, px.g, px.b, 1.0) if p_allowed else RED)
	return out


static func texture_for(p_piece: StringName, p_allowed: bool) -> ImageTexture:
	var k: String = "%s/%s" % [p_piece, p_allowed]
	if not _images.has(k):
		_images[k] = ImageTexture.create_from_image(ghost_image(p_piece, p_allowed))
	return _images[k]


## The tiles the piece would block, from its tile (a wall or a door: it and the tile below; else the tile alone).
static func outline_rect(p_piece: StringName) -> Rect2i:
	if Walls.is_wall_kind(Building.wall_kind_of(p_piece)):
		return Rect2i(0, 0, Config.TILE, 2 * Config.TILE)
	return Rect2i(0, 0, Config.TILE, Config.TILE)


## The outline's pixels (from the tile's top-left): the border of outline_rect.
static func outline_pixels(p_piece: StringName) -> Array[Vector2i]:
	var r: Rect2i = outline_rect(p_piece)
	var out: Array[Vector2i] = []
	var hi: Vector2i = r.end - Vector2i.ONE
	for x: int in range(r.position.x, hi.x + 1):
		out.append(Vector2i(x, r.position.y))
		out.append(Vector2i(x, hi.y))
	for y: int in range(r.position.y + 1, hi.y):
		out.append(Vector2i(r.position.x, y))
		out.append(Vector2i(hi.x, y))
	return out
