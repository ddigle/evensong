class_name BuildView
extends Node2D
## M7b: draws a map's built pieces (items/building.gd) from its WALL layer: stone walls, doors (closed, open) and floor
## pieces. ● gameplay-design §3.3 R37: a built wall is the wall layer, so it draws like the dungeon's walls: under the
## y-sorted entities (Main and GameWorld put this node between the ground and them), its face hanging over the tile below,
## which blocks (collision = what is drawn, Walls.blocks). Lit by the world light (Config.LIGHT_LAYER_WORLD) like the ground.
##
## Art: 04-env build_stone_candA_v02 (● R37 the stone candidate; v02 = the touch-up: the door 12 px wide, the floor one step
## darker), 128x72, its own assembly rule (04-env/prompts.md "건설 벽·문·바닥 후보" 시트 배치·조립):
##   y 0-31   wall tops, 16 of 16x16, index = neighbour mask (N 1, E 2, S 4, W 8: built walls and doors), 8 a row
##   y 32-47  inner corner dots NE, NW, SE, SW (x 0-63: one pixel each) and floor pieces A, B, C (x 64-111)
##   y 48-71  faces 16x24: lone, left end, middle, right end (x 0-63), the door closed, open (x 64-95)
## A built wall tile shows its top by its mask; when the tile below is no wall, its face (16x24) is drawn from that tile's
## top (1.5 tiles: the tile below and half the next, like a dungeon wall's face), its kind by whether the west and east
## neighbours show a face too; a door's face is the door. Where two orthogonal neighbours are walls and the diagonal
## between them is not, the corner dot closes the outline. Rows are drawn from the north, so a wall further south covers
## the lower half of a face above it; floor pieces go down first (the faces cover them). A floor piece's variant is
## floor_variant(). Walls with their faces are drawn only for built pieces: the dungeon's walls are the CaveView's.

const SHEET: Texture2D = preload("res://art/env/build_stone_candA_v02.png")
const TOP_ROW_LEN: int = 8
const DOTS_Y: int = 32
const FLOORS_AT: Vector2i = Vector2i(64, 32)
const FLOOR_VARIANTS: int = 3
const FACES_Y: int = 48
const FACE_SIZE: Vector2i = Vector2i(16, 24)
const DOOR_CLOSED_X: int = 64
const DOOR_OPEN_X: int = 80
## Face kinds (sheet order at y 48).
enum Face { LONE, LEFT_END, MIDDLE, RIGHT_END }
## Inner corner dots (sheet order at y 32): [diagonal, the two orthogonals].
const DOTS: Array = [[Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 0)], [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0)],
	[Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, 0)], [Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, 0)]]

var data: WorldData
## Built tiles (walls, doors, floor pieces), by tile.
var cells: Dictionary[Vector2i, bool] = {}
var draws: int = 0


func _init() -> void:
	name = &"Builds"
	light_mask = Config.LIGHT_LAYER_WORLD


func setup(p_data: WorldData) -> void:
	data = p_data
	cells.clear()
	var grid: PackedByteArray = data.layers[WorldData.Layer.WALL]
	for i: int in grid.size():
		var k: int = grid[i] & Walls.KIND_MASK
		if Walls.is_built_kind(k) or k == Walls.KIND_FLOOR:
			cells[Vector2i(i % data.size.x, i / data.size.x)] = true
	queue_redraw()


## A WALL edit on tile `c` (built, taken down, a door opened or closed, a dungeon wall mined): what the data has now.
func update_cell(c: Vector2i) -> void:
	if data == null:
		return
	var k: int = Walls.kind_at(data, c)
	if Walls.is_built_kind(k) or k == Walls.KIND_FLOOR:
		cells[c] = true
	else:
		cells.erase(c)
	if not cells.is_empty() or k != Walls.KIND_NONE:
		queue_redraw()  # the neighbours' masks, faces and dots follow (one draw of every built tile)


func _draw() -> void:
	draws += 1
	if data == null:
		return
	var list: Array[Vector2i] = []
	list.assign(cells.keys())
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in list:
		if Walls.is_floor_piece(data, c):
			draw_texture_rect_region(SHEET, Rect2(Vector2(c * Config.TILE), Vector2(Config.TILE, Config.TILE)),
				Rect2(floor_rect(c)))
	for c2: Vector2i in list:
		if not Walls.is_built(data, c2):
			continue
		for part: Array in wall_parts(data, c2):
			var src: Rect2i = part[0]
			var at: Vector2i = part[1]
			draw_texture_rect_region(SHEET, Rect2(Vector2(at), Vector2(src.size)), Rect2(src))


## The sheet rect of floor piece tile `c`'s variant.
static func floor_rect(c: Vector2i) -> Rect2i:
	return Rect2i(FLOORS_AT + Vector2i(floor_variant(c) * Config.TILE, 0), Vector2i(Config.TILE, Config.TILE))


## IMPL: which of the three floor pieces tile `c` shows (a fixed mix by position: the same data, the same picture).
static func floor_variant(c: Vector2i) -> int:
	return posmod(c.x * 7 + c.y * 13 + (c.x / 3) * 5, FLOOR_VARIANTS)


## The neighbour mask of built wall `c` (N 1, E 2, S 4, W 8: built walls and doors).
static func mask_of(data: WorldData, c: Vector2i) -> int:
	var m: int = 0
	if Walls.is_built(data, c + Vector2i(0, -1)):
		m |= 1
	if Walls.is_built(data, c + Vector2i(1, 0)):
		m |= 2
	if Walls.is_built(data, c + Vector2i(0, 1)):
		m |= 4
	if Walls.is_built(data, c + Vector2i(-1, 0)):
		m |= 8
	return m


## Whether built wall `c` shows a face (the tile below on the map and no wall).
static func shows_face(data: WorldData, c: Vector2i) -> bool:
	return Walls.is_built(data, c) and data.in_bounds(c + Vector2i(0, 1)) and not Walls.is_wall(data, c + Vector2i(0, 1))


## The face kind of built wall `c` (Face) by its west and east neighbours' faces.
static func face_of(data: WorldData, c: Vector2i) -> int:
	var w: bool = shows_face(data, c + Vector2i(-1, 0))
	var e: bool = shows_face(data, c + Vector2i(1, 0))
	if w and e:
		return Face.MIDDLE
	if e:
		return Face.LEFT_END
	if w:
		return Face.RIGHT_END
	return Face.LONE


## What built wall `c` draws, in order: [sheet rect, world px top-left] pairs: its top, its corner dots, its face (or door).
static func wall_parts(data: WorldData, c: Vector2i) -> Array[Array]:
	var out: Array[Array] = []
	var t: int = Config.TILE
	var m: int = mask_of(data, c)
	out.append([Rect2i(Vector2i((m % TOP_ROW_LEN) * t, (m / TOP_ROW_LEN) * t), Vector2i(t, t)), c * t])
	for i: int in DOTS.size():
		var spec: Array = DOTS[i]
		var diag: Vector2i = spec[0]
		var a: Vector2i = spec[1]
		var b: Vector2i = spec[2]
		if Walls.is_built(data, c + a) and Walls.is_built(data, c + b) and not Walls.is_built(data, c + diag):
			out.append([Rect2i(Vector2i(i * t, DOTS_Y), Vector2i(t, t)), c * t])
	if shows_face(data, c):
		var src: Rect2i
		match Walls.kind_at(data, c):
			Walls.KIND_DOOR:
				src = Rect2i(Vector2i(DOOR_CLOSED_X, FACES_Y), FACE_SIZE)
			Walls.KIND_DOOR_OPEN:
				src = Rect2i(Vector2i(DOOR_OPEN_X, FACES_Y), FACE_SIZE)
			_:
				src = Rect2i(Vector2i(face_of(data, c) * t, FACES_Y), FACE_SIZE)
		out.append([src, (c + Vector2i(0, 1)) * t])
	return out


## The drawing against the data: every built tile listed, nothing else.
func verify() -> Dictionary[String, int]:
	var want: int = 0
	var bad: int = 0
	var grid: PackedByteArray = data.layers[WorldData.Layer.WALL]
	for i: int in grid.size():
		var k: int = grid[i] & Walls.KIND_MASK
		if Walls.is_built_kind(k) or k == Walls.KIND_FLOOR:
			want += 1
			if not cells.has(Vector2i(i % data.size.x, i / data.size.x)):
				bad += 1
	bad += maxi(cells.size() - want, 0)
	return {"built": cells.size(), "mismatches": bad}
