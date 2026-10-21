class_name FreeCamera
extends Camera2D
## Free camera for world.tscn (map viewer without players): the move_* actions (WASD / arrows)
## pan it, and it stays inside `bounds` (the map) so no void shows at the edges. The run scene
## (main.tscn) uses PlayerCamera instead.

var bounds: Rect2 = Rect2()
var speed: float = Config.FREE_CAMERA_SPEED


func _process(delta: float) -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		position = clamp_to_bounds(position + dir * speed * delta)


## Closest camera centre to `p` that keeps the whole view inside `bounds` (centred on an axis
## where the map is smaller than the view).
func clamp_to_bounds(p: Vector2) -> Vector2:
	return PlayerCamera.clamp_center(p, bounds, get_viewport_rect().size / zoom)
