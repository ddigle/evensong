class_name TargetMarker
extends Node2D
## The aimed tile (M2a): four corner brackets on the 16 px tile the local player's tool would hit
## (Player.aim_cell, actors/aim.gd). Drawn in code in brief §4 colours: faith gold brackets with an
## ash black inner edge, no cool greys. Unshaded so the evening does not hide it (like the debug
## lines). Main puts it between the ground and the y-sorted entities, so characters cover it.
## Shown while the player aims and the tile is on the map (IMPL); while a body action plays it marks
## the action's tile (Player.action_cell), which the mouse no longer moves.

const GOLD: Color = Color8(0xf4, 0xc9, 0x5d)   # brief §4 faith
const EDGE: Color = Color8(0x1a, 0x17, 0x14)   # brief §4 base (ash black)
## Bracket arm length in px (corner pixel included).
const ARM: int = 4

var player: Player
var map_cells: Vector2i = Vector2i.ZERO


func _init() -> void:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	visible = false


func _process(_delta: float) -> void:
	refresh()


## Follows the player's aim now (Main also calls it after setting things up). While a body action
## plays it stays on the action's tile (the target is fixed when the action starts), not on the mouse.
func refresh() -> void:
	var on: bool = player != null and is_instance_valid(player) and player.controls and player.aim_active
	var cell: Vector2i = Vector2i.ZERO
	if on:
		cell = player.action_cell if player.action_anim >= 0 else player.aim_cell
	if on and map_cells != Vector2i.ZERO:
		on = cell.x >= 0 and cell.y >= 0 and cell.x < map_cells.x and cell.y < map_cells.y
	visible = on
	if on:
		position = Vector2(cell * Config.TILE)


## Pixels of the marker inside its 16x16 tile, as two lists: gold and edge (tests compare the
## drawing against these).
static func pixels() -> Array[Array]:
	var gold: Array[Vector2i] = []
	var edge: Array[Vector2i] = []
	var t: int = Config.TILE - 1
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var sx: int = 1 if corner.x == 0 else -1
		var sy: int = 1 if corner.y == 0 else -1
		var o: Vector2i = Vector2i(corner.x * t, corner.y * t)
		for i: int in ARM:
			_add_unique(gold, o + Vector2i(sx * i, 0))
			_add_unique(gold, o + Vector2i(0, sy * i))
		for i: int in range(1, ARM + 1):
			_add_unique(edge, o + Vector2i(sx * i, sy))
			_add_unique(edge, o + Vector2i(sx, sy * i))
	return [gold, edge]


static func _add_unique(list: Array[Vector2i], p: Vector2i) -> void:
	if not list.has(p):
		list.append(p)


func _draw() -> void:
	var px: Array[Array] = pixels()
	for p: Vector2i in px[1]:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), EDGE)
	for p: Vector2i in px[0]:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), GOLD)
