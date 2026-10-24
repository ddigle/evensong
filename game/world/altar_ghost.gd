class_name AltarGhost
extends Node2D
## M5b: where the carried altar would go down (AltarMove.place_rect of the carrier's aim): a 1 px outline of the
## footprint, faith gold when it may go there and deep red when it may not (AltarMove.place_refusal), and the edge of the
## light it would give as gold dots every DOT_STEP degrees (PLACEHOLDER drawn in code, brief §4 colours). Unshaded (the
## carried altar gives no light). Main shows it while the local player carries the altar, between the ground and the
## entities like the target marker.

const GOLD: Color = Color8(0xf4, 0xc9, 0x5d)   # brief §4 faith
const RED: Color = Color8(0x5c, 0x10, 0x10)    # brief §4 deep red
## Degrees between two dots of the light's edge.
const DOT_STEP: int = 6

var rect: Rect2i = Rect2i()
var allowed: bool = false


func _init() -> void:
	name = &"AltarGhost"
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	visible = false


## Shows footprint `p_rect` (allowed or not); an empty rect hides it.
func show_at(p_rect: Rect2i, p_allowed: bool) -> void:
	visible = p_rect.has_area()
	if rect == p_rect and allowed == p_allowed:
		return
	rect = p_rect
	allowed = p_allowed
	queue_redraw()


func _draw() -> void:
	if not rect.has_area():
		return
	var c: Color = GOLD if allowed else RED
	for p: Vector2i in outline_pixels(rect):
		draw_rect(Rect2(Vector2(p), Vector2.ONE), c)
	for p2: Vector2i in light_dots(rect):
		draw_rect(Rect2(Vector2(p2), Vector2.ONE), c)


## The outline's world pixels: the footprint's border pixels.
static func outline_pixels(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo: Vector2i = r.position * Config.TILE
	var hi: Vector2i = r.end * Config.TILE - Vector2i.ONE
	for x: int in range(lo.x, hi.x + 1):
		out.append(Vector2i(x, lo.y))
		out.append(Vector2i(x, hi.y))
	for y: int in range(lo.y + 1, hi.y):
		out.append(Vector2i(lo.x, y))
		out.append(Vector2i(hi.x, y))
	return out


## The light edge's dots (world pixels): every DOT_STEP degrees on the safe radius around the footprint's centre, the
## pixel whose centre is nearest inside the radius.
static func light_dots(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c: Vector2 = AltarMove.centre_px(r)
	var radius: float = Config.safe_radius_px() - 1.0
	for deg: int in range(0, 360, DOT_STEP):
		var a: float = deg_to_rad(float(deg))
		var p: Vector2i = Vector2i((c + Vector2(cos(a), sin(a)) * radius).floor())
		if not out.has(p):
			out.append(p)
	return out
