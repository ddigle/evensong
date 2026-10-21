class_name PlayerCamera
extends Camera2D
## Camera centred on one player (● gameplay-design §1: each player has an independent camera).
## It sits on whole pixels (the player node is already rounded) and stays inside `bounds` (the map),
## so no void shows at the edges; where the map is smaller than the view it centres on the map.
## It runs after the players' _process (process_priority 1), so it follows the position the target
## is drawn at this frame (Player draws between simulation ticks).

var target: Node2D
var bounds: Rect2 = Rect2()


func _ready() -> void:
	process_priority = 1
	position_smoothing_enabled = false
	follow()


func _process(_delta: float) -> void:
	follow()


func follow() -> void:
	if target == null or not is_instance_valid(target):
		return
	global_position = clamp_center(target.global_position.round(), bounds, get_viewport_rect().size / zoom).round()


## Closest view centre to `p` that keeps a `view`-sized view inside `area` (centred on an axis where
## the area is smaller than the view). An empty area does not clamp.
static func clamp_center(p: Vector2, area: Rect2, view: Vector2) -> Vector2:
	if area.size == Vector2.ZERO:
		return p
	var half: Vector2 = view / 2.0
	var lo: Vector2 = area.position + half
	var hi: Vector2 = area.end - half
	var out: Vector2 = p
	out.x = area.get_center().x if lo.x > hi.x else clampf(p.x, lo.x, hi.x)
	out.y = area.get_center().y if lo.y > hi.y else clampf(p.y, lo.y, hi.y)
	return out
