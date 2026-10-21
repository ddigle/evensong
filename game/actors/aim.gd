class_name Aim
extends RefCounted
## Mouse aim rules (pure functions). ● gameplay-design §2.1 (R12): aim type, mouse-direction skill
## shots. Everything below that is PROVISIONAL (README "임시값"):
## - the aim origin is the player's feet (the ground point the tiles are measured from);
## - the direction from the feet to the mouse falls into one of 8 sectors of 45°, centred on the
##   axes and diagonals (0 = east, clockwise on screen, y down);
## - the target tile is the tile next to the feet tile in that sector's direction (○ gameplay-design
##   §3.2 "마우스 방향의 인접 타일을 타격", said for mining);
## - the facing toward the mouse is 4-way: the larger axis wins, an exact diagonal faces north or
##   south (RigData.facing_toward's rule);
## - a mouse exactly on the feet keeps the previous sector and facing.
##
## The mouse reaches the world through the root window's stretch (● game-concept §7 R31: 480x270,
## viewport stretch, integer scale, aspect expand). In the game, CanvasItem.get_global_mouse_position
## does it; view_size / view_scale / window_to_view repeat Godot's arithmetic (Window::
## _update_viewport_size, in 32-bit floats like the engine) so tests can check the engine against it
## and compute where a window pixel lands.

enum Sector { EAST, SOUTH_EAST, SOUTH, SOUTH_WEST, WEST, NORTH_WEST, NORTH, NORTH_EAST }

const SECTOR_NAMES: PackedStringArray = ["east", "south-east", "south", "south-west", "west", "north-west", "north",
	"north-east"]
const SECTOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


## Sector of the direction `v` (feet -> mouse); `current` when v is zero.
static func sector(v: Vector2, current: int = Sector.SOUTH) -> int:
	if v == Vector2.ZERO:
		return current
	return posmod(roundi(atan2(v.y, v.x) / (PI / 4.0)), 8)


## The tile under a point (feet).
static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Config.TILE), floori(p.y / Config.TILE))


## The tile next to the feet tile in sector `s`.
static func target_cell(feet: Vector2, s: int) -> Vector2i:
	return cell_of(feet) + SECTOR_OFFSETS[posmod(s, 8)]


## 4-way facing toward direction `v`; `current` when v is zero.
static func facing(v: Vector2, current: int) -> int:
	if v == Vector2.ZERO:
		return current
	if absf(v.x) > absf(v.y):
		return RigData.Dir.EAST if v.x > 0.0 else RigData.Dir.WEST
	return RigData.Dir.SOUTH if v.y > 0.0 else RigData.Dir.NORTH


## Viewport size (px) the root window shows at `window` size: base height (or width) kept, the
## other side expanded to the window's aspect, floored.
static func view_size(window: Vector2i, base: Vector2i = Config.VIEW_SIZE) -> Vector2i:
	var video: Vector2 = Vector2(window)
	var desired: Vector2 = Vector2(base)
	var vp_aspect: float = _f32(desired.x / desired.y)
	var video_aspect: float = _f32(video.x / video.y)
	var size: Vector2 = desired
	if not is_equal_approx(vp_aspect, video_aspect):
		if vp_aspect < video_aspect:
			size = Vector2(_f32(desired.y * video_aspect), desired.y)
		else:
			size = Vector2(desired.x, _f32(desired.x / video_aspect))
	return Vector2i(size.floor())


## Integer scale of the viewport in the window (at least 1).
static func view_scale(window: Vector2i, base: Vector2i = Config.VIEW_SIZE) -> int:
	var view: Vector2i = view_size(window, base)
	return maxi(1, mini(window.x / view.x, window.y / view.y))


## Top-left of the scaled viewport in the window (the black bars' width and height).
static func view_margin(window: Vector2i, base: Vector2i = Config.VIEW_SIZE) -> Vector2:
	var screen: Vector2 = Vector2(view_size(window, base) * view_scale(window, base))
	var margin: Vector2 = Vector2.ZERO
	if screen.x < window.x:
		margin.x = roundf((window.x - screen.x) / 2.0)
	if screen.y < window.y:
		margin.y = roundf((window.y - screen.y) / 2.0)
	return margin


## Window pixel -> viewport pixel (may be outside the viewport over the black bars).
static func window_to_view(p: Vector2, window: Vector2i, base: Vector2i = Config.VIEW_SIZE) -> Vector2:
	return (p - view_margin(window, base)) / float(view_scale(window, base))


## Rounds to the nearest 32-bit float (the engine computes the stretch in 32-bit floats).
static func _f32(v: float) -> float:
	var a: PackedFloat32Array = [v]
	return a[0]
