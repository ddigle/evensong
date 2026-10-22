class_name Movement
extends RefCounted
## Movement rules shared by every player (pure functions, deterministic: G3 runs the same step on
## the host and for client prediction).
##
## - Input is a Vector2i with -1/0/1 per axis (8 ways). Speed is Config.WALK_SPEED in every
##   direction (diagonals normalised).
## - Collision: the feet box (feet_box) must stay inside move_bounds (the map, with head room at the
##   top) and off obstacles: blocked cells (is_blocked: the altar footprint in M1; M3a: the other
##   blocking placeables, walls and wall faces) and the altar's two side bands (side_bands:
##   Config.ALTAR_SIDE_CLEARANCE px beside its west and east faces while the feet are level with it,
##   so a character beside the altar is not drawn half behind it; its north and south faces stop the
##   feet box flush as before). The step moves x first, then y, and stops flush against what it
##   hits, so a diagonal slides along a wall. Obstacles the box already overlaps before a move are
##   ignored, so nothing gets stuck inside.
## - Facing is 4-way (facing_for).


static func velocity(input: Vector2i, speed: float = Config.WALK_SPEED) -> Vector2:
	var v: Vector2 = Vector2(clampi(input.x, -1, 1), clampi(input.y, -1, 1))
	if v == Vector2.ZERO:
		return v
	return v.normalized() * speed


## Feet collision box for a feet position.
static func feet_box(pos: Vector2) -> Rect2:
	return Rect2(pos.x - Config.FEET_HALF_WIDTH, pos.y - Config.FEET_HEIGHT, 2.0 * Config.FEET_HALF_WIDTH,
		Config.FEET_HEIGHT)


## Area the feet box must stay inside: the map, minus Config.HEAD_ROOM_PX at the top.
static func move_bounds(data: WorldData) -> Rect2:
	var map: Vector2 = Vector2(data.size * Config.TILE)
	var top: float = Config.HEAD_ROOM_PX - Config.FEET_HEIGHT
	return Rect2(0.0, top, map.x, map.y - top)


## Blocked for walking: a placeable that blocks (the altar footprint in M1; M3a: the dungeon entrance,
## the exit stairs and the shrine, not a torch, WorldData.placeable_blocks) and a wall or the face
## tile below it (M3a, world/walls.gd: collision = what is drawn).
static func is_blocked(data: WorldData, cell: Vector2i) -> bool:
	if WorldData.placeable_blocks(data.get_value(WorldData.Layer.PLACEABLE, cell)):
		return true
	return Walls.blocks(data, cell)


## Blocked cells the box overlaps (half-open: touching an edge is not overlapping).
static func blocked_cells(data: WorldData, box: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var t: float = float(Config.TILE)
	var x0: int = floori(box.position.x / t)
	var x1: int = ceili(box.end.x / t) - 1
	var y0: int = floori(box.position.y / t)
	var y1: int = ceili(box.end.y / t) - 1
	for cy: int in range(y0, y1 + 1):
		for cx: int in range(x0, x1 + 1):
			if is_blocked(data, Vector2i(cx, cy)):
				out.append(Vector2i(cx, cy))
	return out


## The altar's side bands in px (empty without an altar): beside the footprint's west and east
## faces, Config.ALTAR_SIDE_CLEARANCE wide, from its top edge down to FEET_HEIGHT above its bottom
## edge. A feet box overlaps a band exactly while the feet are strictly between the footprint's top
## and bottom edges (drawn behind the altar); south of that the character is drawn in front.
static func side_bands(data: WorldData) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not data.altar_rect.has_area():
		return out
	var fp: Rect2 = Rect2(Vector2(data.altar_rect.position * Config.TILE), Vector2(data.altar_rect.size * Config.TILE))
	var h: float = fp.size.y - Config.FEET_HEIGHT
	var west: float = float(Config.ALTAR_SIDE_CLEARANCE.x)
	var east: float = float(Config.ALTAR_SIDE_CLEARANCE.y)
	if west > 0.0:
		out.append(Rect2(fp.position.x - west, fp.position.y, west, h))
	if east > 0.0:
		out.append(Rect2(fp.end.x, fp.position.y, east, h))
	return out


## Obstacles the box overlaps (positive area; touching an edge is not overlapping): blocked cells
## and side bands, in px.
static func obstacles(data: WorldData, box: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var t: float = float(Config.TILE)
	for cell: Vector2i in blocked_cells(data, box):
		out.append(Rect2(Vector2(cell) * t, Vector2(t, t)))
	for band: Rect2 in side_bands(data):
		if band.intersects(box):
			out.append(band)
	return out


## True if a character may stand at `pos` (feet box inside the bounds, on no obstacle).
static func can_stand(data: WorldData, pos: Vector2) -> bool:
	var box: Rect2 = feet_box(pos)
	return move_bounds(data).encloses(box) and obstacles(data, box).is_empty()


## One movement step: new feet position after `delta` seconds of `input` at `speed` px/s (walking;
## M4a: a dash and a heretic use the same collision at their own speed).
static func step(data: WorldData, pos: Vector2, input: Vector2i, delta: float, speed: float = Config.WALK_SPEED) -> Vector2:
	var d: Vector2 = velocity(input, speed) * delta
	var p: Vector2 = pos
	if d.x != 0.0:
		p.x = _move_axis(data, p, d.x, 0)
	if d.y != 0.0:
		p.y = _move_axis(data, p, d.y, 1)
	return p


static func _move_axis(data: WorldData, pos: Vector2, amount: float, axis: int) -> float:
	var before: Array[Rect2] = obstacles(data, feet_box(pos))
	var target: Vector2 = pos
	target[axis] += amount
	# Map bounds.
	var bounds: Rect2 = move_bounds(data)
	var lo: float = bounds.position[axis] + (Config.FEET_HALF_WIDTH if axis == 0 else Config.FEET_HEIGHT)
	var hi: float = bounds.end[axis] - (Config.FEET_HALF_WIDTH if axis == 0 else 0.0)
	target[axis] = clampf(target[axis], minf(lo, pos[axis]), maxf(hi, pos[axis]))
	# Obstacles: stop flush against the nearest one in the direction of travel.
	for r: Rect2 in obstacles(data, feet_box(target)):
		if before.has(r):
			continue
		if amount > 0.0:
			var reach: float = Config.FEET_HALF_WIDTH if axis == 0 else 0.0
			target[axis] = minf(target[axis], r.position[axis] - reach)
		else:
			var reach: float = Config.FEET_HALF_WIDTH if axis == 0 else Config.FEET_HEIGHT
			target[axis] = maxf(target[axis], r.end[axis] + reach)
	return target[axis]


## 4-way facing for an 8-way input: a single axis faces that way; on a diagonal the current facing
## is kept if it is one of the two axes, otherwise the horizontal one wins. No input keeps it.
static func facing_for(input: Vector2i, current: int) -> int:
	if input == Vector2i.ZERO:
		return current
	var horizontal: int = RigData.Dir.EAST if input.x > 0 else RigData.Dir.WEST
	var vertical: int = RigData.Dir.SOUTH if input.y > 0 else RigData.Dir.NORTH
	if input.x == 0:
		return vertical
	if input.y == 0:
		return horizontal
	if current == horizontal or current == vertical:
		return current
	return horizontal
