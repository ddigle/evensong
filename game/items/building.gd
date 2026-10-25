class_name Building
extends RefCounted
## M7b: building (offline first; a session refuses it until M7c). Pure functions on WorldData + Inventory like
## items/world_items.gd: they check a request, change the inventory and return the world edits; the caller applies them
## (offline core/main.gd; M7c: the host).
##
## ● decided: anyone builds walls, floors, doors and lights (gameplay-design §3.0 R11 engineer row "누구나 벽·바닥·문·작업대
## 건설"; §3.3 "벽·바닥·문·작업대·조명은 공용"); a built wall is a separate layer above the floor, the same layer as the
## dungeon's walls, and the slice's material is stone only (§3.3 R37; brief §5.7 build_stone_candA). So a stone wall and a
## door are WALL layer kinds (world/walls.gd: Walls.KIND_STONE, KIND_DOOR / KIND_DOOR_OPEN) that block players, heretics
## and shots exactly like a dungeon wall (Movement.is_blocked -> Walls.blocks: the wall tile and the face tile below it),
## and draw with the wall layer under the entities (world/build_view.gd: the top on the tile, the 16x24 face from the top
## of the tile below, the build sheet's own assembly rule). A laid floor piece is the WALL byte's KIND_FLOOR (no wall: it
## blocks nothing; IMPL, see Walls); the lantern post is a placeable (WorldData.PLACEABLE_LANTERN) with a light
## (world/fixture_view.gd).
## ○ / not in the docs (PROVISIONAL, core/config.gd "M7b", README "임시값" M7b):
##   - the pieces are items made at the basic workbench (Config.BUILD_RECIPES); one is chosen in the hotbar and a click puts
##     one down on the target tile (grid-snapped: the M2 target tile, Config.REACH_TILES), at once;
##   - the cost (○ §3.3 "제단 반경 안은 건설 비용 감소"): Config.BUILD_COST_IN_LIGHT pieces on a tile inside the altar's
##     light (every corner, Farming.in_light), Config.BUILD_COST_OUTSIDE_LIGHT elsewhere (the dungeon included);
##   - where (refusal): on the map, in reach, never on another piece, a placeable (the altar, the entrance, the stairs,
##     stations, trees, torches), a dungeon wall or its face, a field, a plant; a blocking piece also never on a drop, a body
##     (players and heretics: `bodies`, the placer's own feet), a spot where players appear (WorldItems.reserved_feet) nor
##     so that one of those spots is walled in (seals: Config.BUILD_SEAL_REACH_TILES); a wall's face may not cover anything
##     but bare ground or a floor piece; a door needs open ground below it (its face is the door) and no wall may go right
##     below a door;
##   - right-click takes any built piece down (demolish: anyone's, the docs keep no owner), giving Config.BUILD_REFUND of
##     its piece back; dungeon walls are mined, never taken down (Mining: a built piece is UNBREAKABLE for the pickaxe);
##   - F on a door (or on its face tile) opens or closes it (toggle_door, Config.DOOR_ANYONE); an open door and its face
##     let everyone through, a closed door is a wall; closing is refused while someone stands in the doorway;
##   - walls do not stop the altar's light (no occluders): the safe zone is the same rule (SafeZone) as before.

const STONE_WALL: StringName = &"stone_wall"
const DOOR: StringName = &"door"
const STONE_FLOOR: StringName = &"stone_floor"
const LANTERN: StringName = &"lantern"
## Piece item -> [the WALL layer kind it lays (Walls.KIND_NONE: none), the placeable it stands (PLACEABLE_NONE: none)].
const PIECES: Dictionary[StringName, Array] = {
	STONE_WALL: [Walls.KIND_STONE, WorldData.PLACEABLE_NONE],
	DOOR: [Walls.KIND_DOOR, WorldData.PLACEABLE_NONE],
	STONE_FLOOR: [Walls.KIND_FLOOR, WorldData.PLACEABLE_NONE],
	LANTERN: [Walls.KIND_NONE, WorldData.PLACEABLE_LANTERN],
}
const UP: Vector2i = Vector2i(0, -1)
const DOWN: Vector2i = Vector2i(0, 1)

const WHY_NOT_PIECE: String = "not a build piece"
const WHY_DUNGEON: String = "no building in the dungeon"
const WHY_COST: String = "not enough pieces"
const WHY_PIECE_THERE: String = "a piece is there"
const WHY_GROWING: String = "a field or a plant is there"
const WHY_DOOR_BELOW: String = "a door needs open ground below"
const WHY_HIDES: String = "its face would cover something"
const WHY_SEALS: String = "it would wall in where players appear"
const WHY_NOT_BUILT: String = "nothing built there"
const WHY_NATURAL: String = "a dungeon wall is mined"
const WHY_NO_DOOR: String = "no door there"
const WHY_DOORWAY: String = "someone stands in the doorway"
const WHY_DOOR_ANYONE: String = "not your door"
## M7c: another player's feet are within Config.BLOCK_CLEARANCE_PX of the tiles a new piece or a closing door would block.
const WHY_NEAR: String = "someone is too close"
## M7b: a session refused building, taking down, doors (no longer used: M7c's host builds with the same rules).
const WHY_OFFLINE: String = "building offline only"


static func is_piece(id: StringName) -> bool:
	return PIECES.has(id)


## The piece in inventory slot `slot` (&"" for none).
static func piece_in(inv: Inventory, slot: int) -> StringName:
	if slot < 0 or slot >= inv.size() or inv.stack_at(slot) == null:
		return &""
	var id: StringName = inv.stack_at(slot).id
	return id if is_piece(id) else &""


static func wall_kind_of(id: StringName) -> int:
	var row: Array = PIECES.get(id, [Walls.KIND_NONE, WorldData.PLACEABLE_NONE])
	var k: int = row[0]
	return k


static func placeable_of(id: StringName) -> int:
	var row: Array = PIECES.get(id, [Walls.KIND_NONE, WorldData.PLACEABLE_NONE])
	var p: int = row[1]
	return p


## The piece a built thing on a tile stands for: a WALL kind, else a placeable (&"" for none).
static func piece_of_kind(kind: int) -> StringName:
	match kind:
		Walls.KIND_STONE:
			return STONE_WALL
		Walls.KIND_DOOR, Walls.KIND_DOOR_OPEN:
			return DOOR
		Walls.KIND_FLOOR:
			return STONE_FLOOR
	return &""


## How many of a piece one goes down for on tile `c` (PROVISIONAL Config.BUILD_COST_*: cheaper inside the altar's light).
static func cost_at(data: WorldData, c: Vector2i) -> int:
	if data.map_id == Config.MAP_SURFACE and data.altar_rect.has_area() and Farming.in_light(data, c):
		return Config.BUILD_COST_IN_LIGHT
	return Config.BUILD_COST_OUTSIDE_LIGHT


## The tiles that block once piece `id` stands on tile `c`: a wall's tile and its face tile (the tile below, unless that
## is a wall), the lantern's tile; none for a floor piece. A door counts as closed (it goes down closed).
static func blocked_cells(data: WorldData, id: StringName, c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if Walls.is_wall_kind(wall_kind_of(id)):
		out.append(c)
		if data.in_bounds(c + DOWN) and not Walls.is_wall(data, c + DOWN):
			out.append(c + DOWN)
	elif placeable_of(id) != WorldData.PLACEABLE_NONE:
		out.append(c)
	return out


## Whether a field or a plant is on tile `c` (tilled soil, a crop or wet soil, a gatherable).
static func _growing(data: WorldData, c: Vector2i) -> bool:
	return data.get_value(WorldData.Layer.VEGETATION, c) != 0 or (data.map_id == Config.MAP_SURFACE
		and data.terrain_at(c) == Terrain.SOIL)


## Why piece `id` may not go down on tile `c` for feet at `feet` with `have` of it ("" = it may). `bodies` = other feet
## (players, heretics), `reserved_extra` = more spots where players appear (the host's carried-altar slots, M5-fix).
## M7c: `others` = the other players' feet (not the heretics'): none of them within Config.BLOCK_CLEARANCE_PX of a tile a
## blocking piece would block (clear_of_others; PROVISIONAL README "M7c 막기 여유").
static func refusal(data: WorldData, feet: Vector2, id: StringName, c: Vector2i, have: int,
		bodies: Array[Vector2] = [], reserved_extra: Array[Vector2] = [], others: Array[Vector2] = []) -> String:
	if not is_piece(id):
		return WHY_NOT_PIECE
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if data.map_id != Config.MAP_SURFACE and not Config.BUILD_IN_DUNGEON:
		return WHY_DUNGEON
	if have < cost_at(data, c):
		return WHY_COST
	var kind: int = wall_kind_of(id)
	var here: int = Walls.kind_at(data, c)
	if Walls.is_natural(data, c):
		return WorldItems.WHY_NOT_OPEN
	if Walls.is_wall(data, c) or (here == Walls.KIND_FLOOR and kind != Walls.KIND_NONE):
		return WHY_PIECE_THERE  # a lantern may stand on a floor piece
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
		return WorldItems.WHY_NOT_OPEN
	if Walls.is_face(data, c) and (Walls.is_natural(data, c + UP) or kind == Walls.KIND_NONE):
		return WorldItems.WHY_NOT_OPEN  # a dungeon wall's face (cliff); the lantern stands on no face at all
	if _growing(data, c):
		return WHY_GROWING
	if kind != Walls.KIND_FLOOR and not data.drops_at(c).is_empty():
		return WorldItems.WHY_NOT_OPEN
	if Walls.is_wall_kind(kind):
		if Walls.is_door(data, c + UP):
			return WHY_DOOR_BELOW  # the tile below a door is its face: no wall may hide it
		var below: Vector2i = c + DOWN
		if kind == Walls.KIND_DOOR and (not data.in_bounds(below) or Walls.is_wall(data, below)):
			return WHY_DOOR_BELOW
		if data.in_bounds(below) and not Walls.is_wall(data, below):
			if data.get_value(WorldData.Layer.PLACEABLE, below) != WorldData.PLACEABLE_NONE or _growing(data, below) \
					or not data.drops_at(below).is_empty():
				return WHY_HIDES
	var cells: Array[Vector2i] = blocked_cells(data, id, c)
	if cells.is_empty():
		return ""
	var all: Array[Vector2] = [feet]
	all.append_array(bodies)
	var spots: Array[Vector2] = WorldItems.reserved_feet(data)
	spots.append_array(reserved_extra)
	for cell: Vector2i in cells:
		var px: Rect2 = Rect2(Vector2(cell * Config.TILE), Vector2(Config.TILE, Config.TILE))
		for b: Vector2 in all:
			if px.intersects(Movement.feet_box(b)):
				return WorldItems.WHY_BODY
		for r: Vector2 in spots:
			if px.intersects(Movement.feet_box(r)):
				return WorldItems.WHY_RESERVED
	if not clear_of_others(cells, others):
		return WHY_NEAR  # M7c: no other player's prediction may walk into it before the edit reaches it
	if kind != Walls.KIND_DOOR and seals(data, cells, spots):
		return WHY_SEALS  # a door never seals: anyone opens it
	return ""


## M7c (PROVISIONAL Config.BLOCK_CLEARANCE_PX, README "M7c 막기 여유"): whether no feet box of `others` (the other players)
## comes within the clearance of any of `cells` (tiles that start blocking now). A player farther away cannot walk into
## them in the round trip before their edit reaches its machine, so its prediction and the host agree.
static func clear_of_others(cells: Array[Vector2i], others: Array[Vector2]) -> bool:
	var grow: float = Config.BLOCK_CLEARANCE_PX
	for cell: Vector2i in cells:
		var px: Rect2 = Rect2(Vector2(cell * Config.TILE), Vector2(Config.TILE, Config.TILE)).grow(grow)
		for o: Vector2 in others:
			if px.intersects(Movement.feet_box(o)):
				return false
	return true


## A click with the piece in hotbar slot `slot` on tile `c`: its cost (cost_at) leaves the inventory (that slot first) and
## the piece goes down (one WALL or PLACEABLE cell edit). `count` = the pieces used. M7c: `others` = the other players' feet
## (refusal).
static func build(data: WorldData, feet: Vector2, inv: Inventory, slot: int, c: Vector2i,
		bodies: Array[Vector2] = [], reserved_extra: Array[Vector2] = [], others: Array[Vector2] = []) -> WorldItems.Outcome:
	if slot < 0 or slot >= inv.hotbar_size:
		return WorldItems.Outcome.refused(WorldItems.WHY_BAD_SLOT)
	if inv.stack_at(slot) == null:
		return WorldItems.Outcome.refused(WorldItems.WHY_EMPTY)
	var id: StringName = piece_in(inv, slot)
	if id.is_empty():
		return WorldItems.Outcome.refused(WHY_NOT_PIECE)
	var why: String = refusal(data, feet, id, c, inv.count_of(id), bodies, reserved_extra, others)
	if not why.is_empty():
		return WorldItems.Outcome.refused(why)
	var cost: int = cost_at(data, c)
	_take(inv, slot, id, cost)
	var o: WorldItems.Outcome = WorldItems.Outcome.new()
	o.item = id
	o.count = cost
	o.edits.append(edit_for(id, c))
	return o


## The world edit that puts piece `id` on tile `c`.
static func edit_for(id: StringName, c: Vector2i) -> EditLog.WorldEdit:
	var kind: int = wall_kind_of(id)
	if kind != Walls.KIND_NONE:
		return EditLog.WorldEdit.new(WorldData.Layer.WALL, c, Walls.pack(kind, 0))
	return EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, placeable_of(id))


## Takes `n` of `id` out of `inv`: slot `slot` first, then the other slots from the last.
static func _take(inv: Inventory, slot: int, id: StringName, n: int) -> void:
	var need: int = n
	if inv.stack_at(slot) != null and inv.stack_at(slot).id == id:
		need -= inv.remove(slot, mini(need, inv.stack_at(slot).count))
	for s: int in range(inv.size() - 1, -1, -1):
		if need <= 0:
			break
		var st: ItemStack = inv.stack_at(s)
		if st != null and st.id == id:
			need -= inv.remove(s, mini(need, st.count))


## The built thing a right-click on tile `c` takes down: [its piece, the tile it stands on] ([&"", NO_CELL] for none). The
## lantern on the tile, else a built wall on it or the one whose face it is, else a floor piece on it.
static func built_at(data: WorldData, c: Vector2i) -> Array:
	if data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_LANTERN:
		return [LANTERN, c]
	if Walls.is_built(data, c):
		return [piece_of_kind(Walls.kind_at(data, c)), c]
	if Walls.is_face(data, c) and Walls.is_built(data, c + UP):
		return [piece_of_kind(Walls.kind_at(data, c + UP)), c + UP]
	if Walls.is_floor_piece(data, c):
		return [STONE_FLOOR, c]
	return [&"", Walls.NO_CELL]


## Right-click on tile `c` for feet at `feet`: the built thing there comes down (any player's; built_at) and
## Config.BUILD_REFUND of its piece goes into `inv` (refused when it does not fit: nothing changes). A dungeon wall is mined,
## not taken down (WHY_NATURAL).
static func demolish(data: WorldData, feet: Vector2, inv: Inventory, c: Vector2i) -> WorldItems.Outcome:
	if not data.in_bounds(c):
		return WorldItems.Outcome.refused(WorldItems.WHY_OUTSIDE)
	if not WorldItems.in_reach(feet, c):
		return WorldItems.Outcome.refused(WorldItems.WHY_REACH)
	var what: Array = built_at(data, c)
	var piece: StringName = what[0]
	var at: Vector2i = what[1]
	if piece.is_empty():
		if Walls.owner_of(data, c) != Walls.NO_CELL:
			return WorldItems.Outcome.refused(WHY_NATURAL)
		return WorldItems.Outcome.refused(WHY_NOT_BUILT)
	if inv.room_for(piece) < Config.BUILD_REFUND:
		return WorldItems.Outcome.refused(WorldItems.WHY_FULL)
	inv.add(piece, Config.BUILD_REFUND)
	var o: WorldItems.Outcome = WorldItems.Outcome.new()
	o.item = piece
	o.count = Config.BUILD_REFUND
	if piece == LANTERN:
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at, WorldData.PLACEABLE_NONE))
	else:
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, at, 0))
	return o


## The door F on tile `c` reaches: `c` itself, or the door above when `c` is its face tile (Walls.NO_CELL for none).
static func door_cell(data: WorldData, c: Vector2i) -> Vector2i:
	if Walls.is_door(data, c):
		return c
	if data.in_bounds(c) and not Walls.is_wall(data, c) and Walls.is_door(data, c + UP):
		return c + UP
	return Walls.NO_CELL


## F on tile `c` (a door or its face) for feet at `feet`: opens a closed door, closes an open one (one WALL cell edit).
## Closing is refused while a body (`feet` and `bodies`) or a placeable (a death bag) is in the doorway (the door tile and
## its face tile). `item` of the outcome = "open" / "closed". M7c: closing is also refused while another player (`others`)
## is within Config.BLOCK_CLEARANCE_PX of the doorway (clear_of_others: a door never closes on someone a round trip away
## from it; opening has no such rule).
static func toggle_door(data: WorldData, feet: Vector2, c: Vector2i, bodies: Array[Vector2] = [],
		others: Array[Vector2] = []) -> WorldItems.Outcome:
	if not data.in_bounds(c):
		return WorldItems.Outcome.refused(WorldItems.WHY_OUTSIDE)
	if not WorldItems.in_reach(feet, c):
		return WorldItems.Outcome.refused(WorldItems.WHY_REACH)
	var d: Vector2i = door_cell(data, c)
	if d == Walls.NO_CELL:
		return WorldItems.Outcome.refused(WHY_NO_DOOR)
	if not Config.DOOR_ANYONE:
		return WorldItems.Outcome.refused(WHY_DOOR_ANYONE)
	var o: WorldItems.Outcome = WorldItems.Outcome.new()
	if Walls.is_open_door(data, d):
		var all: Array[Vector2] = [feet]
		all.append_array(bodies)
		for cell: Vector2i in [d, d + DOWN]:
			if data.get_value(WorldData.Layer.PLACEABLE, cell) != WorldData.PLACEABLE_NONE:
				return WorldItems.Outcome.refused(WHY_DOORWAY)
			var px: Rect2 = Rect2(Vector2(cell * Config.TILE), Vector2(Config.TILE, Config.TILE))
			for b: Vector2 in all:
				if px.intersects(Movement.feet_box(b)):
					return WorldItems.Outcome.refused(WHY_DOORWAY)
		if not clear_of_others([d, d + DOWN] as Array[Vector2i], others):
			return WorldItems.Outcome.refused(WHY_NEAR)  # M7c
		o.item = &"closed"
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, d, Walls.pack(Walls.KIND_DOOR, 0)))
	else:
		o.item = &"open"
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, d, Walls.pack(Walls.KIND_DOOR_OPEN, 0)))
	o.count = 1
	return o


# --- sealing (PROVISIONAL Config.BUILD_SEAL_REACH_TILES) --------------------------------------------------------------

## Whether putting blocking things on `cells` would wall one of `spots` (feet points where players appear) in: from its
## tile a walk (4 ways, doors open, reaches) gets Config.BUILD_SEAL_REACH_TILES away now but would not after. A spot more
## than that (+ 1) from every cell is not affected and not walked.
static func seals(data: WorldData, cells: Array[Vector2i], spots: Array[Vector2]) -> bool:
	if cells.is_empty():
		return false
	var extra: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in cells:
		extra[c] = true
	var none: Dictionary[Vector2i, bool] = {}
	var r: int = Config.BUILD_SEAL_REACH_TILES
	for s: Vector2 in spots:
		var start: Vector2i = Aim.feet_cell(s)
		var near: bool = false
		for c2: Vector2i in cells:
			if maxi(absi(c2.x - start.x), absi(c2.y - start.y)) <= r + 1:
				near = true
				break
		if near and not reaches(data, start, extra) and reaches(data, start, none):
			return true
	return false


## Whether a walk from tile `start` (4 ways over tiles that do not block, `extra` blocking too; a door and its face are
## open: anyone opens them) gets Config.BUILD_SEAL_REACH_TILES (Chebyshev) away. False when `start` itself is blocked.
static func reaches(data: WorldData, start: Vector2i, extra: Dictionary[Vector2i, bool]) -> bool:
	var r: int = Config.BUILD_SEAL_REACH_TILES
	if not _passable(data, start, extra):
		return false
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	var i: int = 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in DungeonGen.STEPS:
			var n: Vector2i = c + d
			if seen.has(n) or not _passable(data, n, extra):
				continue
			if maxi(absi(n.x - start.x), absi(n.y - start.y)) >= r:
				return true
			seen[n] = true
			queue.append(n)
	return false


static func _passable(data: WorldData, c: Vector2i, extra: Dictionary[Vector2i, bool]) -> bool:
	if not data.in_bounds(c) or extra.has(c):
		return false
	if Walls.is_door(data, c) or (not Walls.is_wall(data, c) and Walls.is_door(data, c + UP)):
		return true
	return not Movement.is_blocked(data, c)
