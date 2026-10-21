class_name DebugOverlay
extends Node2D
## Debug lines over the world (F3 / --overlay): map border, ground chunk borders, the altar
## footprint and the provisional safe radius. Hidden by default.

const CHUNK_COLOR: Color = Color(0.1, 0.1, 0.12, 0.45)
const BORDER_COLOR: Color = Color(0.9, 0.2, 0.15, 0.9)
const ALTAR_COLOR: Color = Color(0.96, 0.79, 0.36, 0.95)

var data: WorldData


func _ready() -> void:
	z_index = 100
	visible = false
	# Debug lines keep their colours under the evening darkness.
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func setup(p_data: WorldData) -> void:
	data = p_data
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if data == null:
		return
	var t: int = Config.TILE
	var map_px: Vector2 = Vector2(data.size * t)
	var step: int = Config.GROUND_CHUNK * t
	# Chunk borders sit half a tile off the world grid (display cells are shifted, GroundView).
	var x: int = t / 2
	while x < int(map_px.x):
		draw_line(Vector2(x, 0), Vector2(x, map_px.y), CHUNK_COLOR, 1.0)
		x += step
	var y: int = t / 2
	while y < int(map_px.y):
		draw_line(Vector2(0, y), Vector2(map_px.x, y), CHUNK_COLOR, 1.0)
		y += step
	draw_rect(Rect2(Vector2.ZERO, map_px), BORDER_COLOR, false, 1.0)
	if data.altar_rect.has_area():
		draw_rect(Rect2(Vector2(data.altar_rect.position * t), Vector2(data.altar_rect.size * t)), ALTAR_COLOR,
			false, 1.0)
		draw_arc(data.altar_center_px(), Config.safe_radius_px(), 0.0, TAU, 96, ALTAR_COLOR, 1.0)
