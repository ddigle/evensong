class_name Building
extends RefCounted
## M7b: building. Pure functions on WorldData + Inventory like items/world_items.gd: they check a request, change the
## inventory and return the world edits; the caller applies them (offline core/main.gd; M7c: the host, net/session_host.gd).
##
## ● decided: anyone builds walls, floors, doors and lights (gameplay-design §3.0 R11 engineer row "누구나 벽·바닥·문·작업대
## 건설"; §3.3 "벽·바닥·문·작업대·조명은 공용"); a built wall is a separate layer above the floor, the same layer as the
## dungeon's walls, and the slice's material is stone only (§3.3 R37; brief §5.7 build_stone_candA). So a stone wall and a
## door are WALL layer kinds (world/walls.gd: Walls.KIND_STONE, KIND_DOOR / KIND_DOOR_OPEN) that block players, heretics
## and shots exactly like a dungeon wall (Movement.is_blocked -> Walls.blocks: the wall tile and the face tile below it),
## and draw with the wall layer under the entities (world/build_view.gd: the top on the tile, the 16x24 face from the top
## of the tile below, the build sheet's own assembly rule). A laid floor piece blocks nothing; the lantern post is a
## placeable (WorldData.PLACEABLE_LANTERN) with a light (world/fixture_view.gd).
## M7-rf (the human's decision of 2026-10-26, ● §3.1 layers, ● §3.3 R37 "건설 벽은 바닥 위 별도 층"): a floor piece is the
## floor side's built byte (WorldData.Layer.FLOOR_PIECE, M7b had it in the WALL byte), so a stone wall or a door stands on a
## floor piece and the floor piece stays under it (drawn first: the wall's and the door's art, an open door's too, covers it
## while they stand; taking them down shows it again). Right-click takes the top piece first (built_at: the lantern, the
## wall or door, then the floor piece on a later click). M7-rf review: top first holds for what is never taken down too: a
## floor piece under a station, the chest, the altar, a torch or a death bag stays while that stands (WHY_ON_TOP; PROVISIONAL
## README "M7-rf 위에 선 것"), and in a session the host takes down only the piece the clicker saw on top (DEMOLISH carries
## it, piece_code; WHY_TOP_CHANGED: two clicks on one wall never take the floor piece under it unseen; IMPL README
## "M7-rf 철거 요청의 본 조각").
## ○ / not in the docs (PROVISIONAL, core/config.gd "M7b", README "임시값" M7b):
##   - the pieces are items made at the basic workbench (Config.BUILD_RECIPES); one is chosen in the hotbar and a click puts
##     one down on the target tile (grid-snapped: the M2 target tile, Config.REACH_TILES), at once;
##   - the cost (○ §3.3 "제단 반경 안은 건설 비용 감소"): Config.BUILD_COST_IN_LIGHT pieces on a tile inside the altar's
##     light (every corner, Farming.in_light), Config.BUILD_COST_OUTSIDE_LIGHT elsewhere (the dungeon included);
##   - where (refusal): on the map, in reach, never on another piece (M7-rf: but a wall, a door or a lantern on a floor piece;
##     a floor piece never under a built wall or door nor on its face tile / doorway, Config.BUILD_FLOOR_UNDER_WALL: lay the
##     floor first), a placeable (the altar, the entrance, the stairs, stations, trees, torches), a dungeon wall or its
##     face, a field, a plant; a blocking piece also never on a drop, a body
##     (players and heretics: `bodies`, the placer's own feet), a spot where players appear (WorldItems.reserved_feet) nor
##     so that one of those spots is walled in (seals: Config.BUILD_SEAL_REACH_TILES); a wall's face may not cover anything
##     but bare ground or a floor piece; a door needs open ground below it (its face is the door) and no wall may go right
##     below a door;
##   - right-click takes any built piece down (demolish: anyone's, the docs keep no owner), giving Config.BUILD_REFUND of
##     its piece back (M7-fix: what does not fit lies at the feet); dungeon walls are mined, never taken down (Mining: a
##     built piece is UNBREAKABLE for the pickaxe);
##   - F on a door (or on its face tile) opens or closes it (toggle_door, Config.DOOR_ANYONE); an open door and its face
##     let everyone through, a closed door is a wall; closing is refused while someone stands in the doorway;
##   - walls do not stop the altar's light (no occluders): the safe zone is the same rule (SafeZone) as before.

const STONE_WALL: StringName = &"stone_wall"
const DOOR: StringName = &"door"
const STONE_FLOOR: StringName = &"stone_floor"
const LANTERN: StringName = &"lantern"
## Piece item -> [the WALL layer kind it lays (Walls.KIND_NONE: none), the placeable it stands (PLACEABLE_NONE: none), the
## floor piece it lays (M7-rf: WorldData.FLOOR_PIECE_*, FLOOR_PIECE_NONE: none)].
const PIECES: Dictionary[StringName, Array] = {
	STONE_WALL: [Walls.KIND_STONE, WorldData.PLACEABLE_NONE, WorldData.FLOOR_PIECE_NONE],
	DOOR: [Walls.KIND_DOOR, WorldData.PLACEABLE_NONE, WorldData.FLOOR_PIECE_NONE],
	STONE_FLOOR: [Walls.KIND_NONE, WorldData.PLACEABLE_NONE, WorldData.FLOOR_PIECE_STONE],
	LANTERN: [Walls.KIND_NONE, WorldData.PLACEABLE_LANTERN, WorldData.FLOOR_PIECE_NONE],
}
const NO_PIECE: Array = [Walls.KIND_NONE, WorldData.PLACEABLE_NONE, WorldData.FLOOR_PIECE_NONE]
## M7-rf review (protocol v9): a DEMOLISH request's piece byte = the index here of the piece its sender saw on top of the
## tile (built_at; 0 = nothing).
const PIECE_CODES: Array[StringName] = [&"", STONE_WALL, DOOR, STONE_FLOOR, LANTERN]
## demolish()'s `seen` when nothing is checked (offline: what the player sees is the world itself).
const SEEN_ANY: int = -1
const UP: Vector2i = Vector2i(0, -1)
const DOWN: Vector2i = Vector2i(0, 1)

const WHY_NOT_PIECE: String = "not a build piece"
const WHY_DUNGEON: String = "no building in the dungeon"
const WHY_COST: String = "not enough pieces"
const WHY_PIECE_THERE: String = "a piece is there"
## M7-rf (PROVISIONAL Config.BUILD_FLOOR_UNDER_WALL off): a floor piece aimed at a built wall or door, or (review) at the
## tile below one (its face, a door's doorway).
const WHY_FLOOR_FIRST: String = "lay the floor first"
## M7-rf review (PROVISIONAL README "M7-rf 위에 선 것", from the decided "top piece first"): a right-click on a floor piece
## that something no right-click takes down stands on (a station, the chest, the altar, a torch, a death bag).
const WHY_ON_TOP: String = "something stands on it"
## M7-rf review (IMPL README "M7-rf 철거 요청의 본 조각"): a DEMOLISH whose sender saw another piece on top of the tile (the
## piece it saw already came down: another click got there first, or its own earlier one).
const WHY_TOP_CHANGED: String = "the top piece changed"
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

## M7-fix: the clearance clear_of_others uses (Config.BLOCK_CLEARANCE_PX; tests set it to 0 to show the rule is what keeps
## the prediction from being pulled back, and put it back).
static var clearance_px: float = Config.BLOCK_CLEARANCE_PX
## M7-rf review: the switch refusal reads (Config.BUILD_FLOOR_UNDER_WALL; tests turn it on to show the floor piece slid
## under a wall still comes up second, draws under it and travels, and put it back).
static var floor_under_wall: bool = Config.BUILD_FLOOR_UNDER_WALL


static func is_piece(id: StringName) -> bool:
	return PIECES.has(id)


## The piece in inventory slot `slot` (&"" for none).
static func piece_in(inv: Inventory, slot: int) -> StringName:
	if slot < 0 or slot >= inv.size() or inv.stack_at(slot) == null:
		return &""
	var id: StringName = inv.stack_at(slot).id
	return id if is_piece(id) else &""


static func wall_kind_of(id: StringName) -> int:
	var row: Array = PIECES.get(id, NO_PIECE)
	var k: int = row[0]
	return k


static func placeable_of(id: StringName) -> int:
	var row: Array = PIECES.get(id, NO_PIECE)
	var p: int = row[1]
	return p


## M7-rf: the floor piece (WorldData.FLOOR_PIECE_*) piece `id` lays (FLOOR_PIECE_NONE for the others).
static func floor_piece_of(id: StringName) -> int:
	var row: Array = PIECES.get(id, NO_PIECE)
	var f: int = row[2]
	return f


## M7-rf review: piece `id`'s code in a DEMOLISH request (PIECE_CODES; 0 for none or not a piece).
static func piece_code(id: StringName) -> int:
	return maxi(PIECE_CODES.find(id), 0)


## M7-rf review: the code of the piece a right-click on tile `c` of `data` would take down now (built_at).
static func top_code(data: WorldData, c: Vector2i) -> int:
	var what: Array = built_at(data, c)
	var piece: StringName = what[0]
	return piece_code(piece)


## The piece a built wall kind stands for (&"" for none).
static func piece_of_kind(kind: int) -> StringName:
	match kind:
		Walls.KIND_STONE:
			return STONE_WALL
		Walls.KIND_DOOR, Walls.KIND_DOOR_OPEN:
			return DOOR
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


## M7-rf: whether tile `c` belongs to a standing built wall or door (Walls.owner_of: its own tile, or the tile below it: a
## wall's face, a door's doorway, open or closed). A floor piece put there would lie under what is drawn there.
static func _under_built(data: WorldData, c: Vector2i) -> bool:
	var o: Vector2i = Walls.owner_of(data, c)
	return o != Walls.NO_CELL and Walls.is_built(data, o)


## Whether a field or a plant is on tile `c` (tilled soil, a crop or wet soil, a gatherable).
static func _growing(data: WorldData, c: Vector2i) -> bool:
	return data.get_value(WorldData.Layer.VEGETATION, c) != 0 or (data.map_id == Config.MAP_SURFACE
		and data.terrain_at(c) == Terrain.SOIL)


## Why piece `id` may not go down on tile `c` for feet at `feet` with `have` of it ("" = it may). `bodies` = other feet
## (players, heretics), `reserved_extra` = more spots where players appear (the host's carried-altar slots, M5-fix).
## M7c: `others` = the other players' feet (not the heretics'): none of them within Config.BLOCK_CLEARANCE_PX of a tile a
## blocking piece would block (clear_of_others; PROVISIONAL README "M7c 막기 여유"). M7-fix: and none of them walled in by
## it (seals walks from their feet too, PROVISIONAL README "M7-fix 다른 사람 가두기").
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
	var lays_floor: bool = floor_piece_of(id) != WorldData.FLOOR_PIECE_NONE
	if Walls.is_natural(data, c):
		return WorldItems.WHY_NOT_OPEN
	if lays_floor:
		# M7-rf: the floor side's own byte: one floor piece a tile, laid before the wall or door that stands on it.
		if data.has_floor_piece(c):
			return WHY_PIECE_THERE
		if not floor_under_wall and _under_built(data, c):
			return WHY_FLOOR_FIRST  # PROVISIONAL README "M7-rf 벽 아래 바닥"
	elif Walls.is_wall(data, c):
		return WHY_PIECE_THERE  # M7-rf: a wall, a door or a lantern may stand on a floor piece (the floor stays under it)
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
		return WorldItems.WHY_NOT_OPEN
	if Walls.is_face(data, c) and (Walls.is_natural(data, c + UP) or placeable_of(id) != WorldData.PLACEABLE_NONE):
		return WorldItems.WHY_NOT_OPEN  # a dungeon wall's face (cliff); the lantern stands on no face at all
	if _growing(data, c):
		return WHY_GROWING
	if not lays_floor and not data.drops_at(c).is_empty():
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
	if kind == Walls.KIND_DOOR:
		return ""  # a door never seals: anyone opens it
	# M7-fix: nor wall another player in (their feet walk like a spot where players appear; PROVISIONAL README
	# "M7-fix 다른 사람 가두기"): a ring around someone else needs a door.
	var walkers: Array[Vector2] = spots.duplicate()
	walkers.append_array(others)
	if seals(data, cells, walkers):
		return WHY_SEALS
	return ""


## M7c (PROVISIONAL Config.BLOCK_CLEARANCE_PX, README "M7c 막기 여유"): whether no feet box of `others` (the other players)
## comes within the clearance of any of `cells` (tiles that start blocking now). A player farther away cannot walk into
## them in the round trip before their edit reaches its machine, so its prediction and the host agree.
static func clear_of_others(cells: Array[Vector2i], others: Array[Vector2]) -> bool:
	var grow: float = clearance_px
	for cell: Vector2i in cells:
		var px: Rect2 = Rect2(Vector2(cell * Config.TILE), Vector2(Config.TILE, Config.TILE)).grow(grow)
		for o: Vector2 in others:
			if px.intersects(Movement.feet_box(o)):
				return false
	return true


## A click with the piece in hotbar slot `slot` on tile `c`: its cost (cost_at) leaves the inventory (that slot first) and
## the piece goes down (one WALL, PLACEABLE or, M7-rf, FLOOR_PIECE cell edit). `count` = the pieces used. M7c: `others` = the
## other players' feet (refusal).
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


## The world edit that puts piece `id` on tile `c` (M7-rf: a floor piece on the FLOOR_PIECE layer, under a wall's).
static func edit_for(id: StringName, c: Vector2i) -> EditLog.WorldEdit:
	var fp: int = floor_piece_of(id)
	if fp != WorldData.FLOOR_PIECE_NONE:
		return EditLog.WorldEdit.new(WorldData.Layer.FLOOR_PIECE, c, fp)
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
## lantern on the tile, else a built wall on it or the one whose face it is, else a floor piece on it. M7-rf: the top piece
## first: a wall or a door standing on a floor piece comes down before it (the floor piece on a later click). M7-rf review:
## a floor piece with any other placeable on it (a station, the chest, the altar, a torch, a death bag: none of them comes
## down with a right-click) is no top piece: nothing comes down (demolish says WHY_ON_TOP; PROVISIONAL README
## "M7-rf 위에 선 것").
static func built_at(data: WorldData, c: Vector2i) -> Array:
	var placed: int = data.get_value(WorldData.Layer.PLACEABLE, c)
	if placed == WorldData.PLACEABLE_LANTERN:
		return [LANTERN, c]
	if Walls.is_built(data, c):
		return [piece_of_kind(Walls.kind_at(data, c)), c]
	if Walls.is_face(data, c) and Walls.is_built(data, c + UP):
		return [piece_of_kind(Walls.kind_at(data, c + UP)), c + UP]
	if data.has_floor_piece(c) and placed == WorldData.PLACEABLE_NONE:
		return [STONE_FLOOR, c]
	return [&"", Walls.NO_CELL]


## Right-click on tile `c` for feet at `feet`: the built thing there comes down (any player's; built_at) and
## Config.BUILD_REFUND of its piece goes into `inv`. A dungeon wall is mined, not taken down (WHY_NATURAL).
## M7-fix (PROVISIONAL README "M7-fix 철거"): what does not fit lies on the feet tile as one drop (none when the map holds
## MAX_DROPS: lost), like the logs of a felled tree; M7b refused it ("inventory full"), so someone walled in with a full
## inventory could not get out. And an open door with a wall right above it leaves that wall's face on its tile, which
## blocks: it comes down only as a closing door would (nobody of `feet` / `bodies` and no placeable on that tile, no other
## player of `others` within Config.BLOCK_CLEARANCE_PX of it; toggle_door's rule), so nobody ends up inside a blocking tile.
## M7-rf review: `seen` = the code (piece_code) of the piece the clicker saw on top of the tile (a session's DEMOLISH carries
## it; SEEN_ANY offline): when another piece is on top now, nothing comes down (WHY_TOP_CHANGED).
static func demolish(data: WorldData, feet: Vector2, inv: Inventory, c: Vector2i, bodies: Array[Vector2] = [],
		others: Array[Vector2] = [], seen: int = SEEN_ANY) -> WorldItems.Outcome:
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
		if data.has_floor_piece(c):
			return WorldItems.Outcome.refused(WHY_ON_TOP)  # PROVISIONAL README "M7-rf 위에 선 것"
		return WorldItems.Outcome.refused(WHY_NOT_BUILT)
	if seen != SEEN_ANY and piece_code(piece) != seen:
		return WorldItems.Outcome.refused(WHY_TOP_CHANGED)  # IMPL README "M7-rf 철거 요청의 본 조각"
	if Walls.is_open_door(data, at) and Walls.is_wall(data, at + UP):
		var why: String = _doorway_refusal(data, [at] as Array[Vector2i], feet, bodies, others)
		if not why.is_empty():
			return WorldItems.Outcome.refused(why)
	var o: WorldItems.Outcome = WorldItems.Outcome.new()
	o.item = piece
	o.count = Config.BUILD_REFUND
	if piece == LANTERN:
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at, WorldData.PLACEABLE_NONE))
	elif piece == STONE_FLOOR:
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.FLOOR_PIECE, at, WorldData.FLOOR_PIECE_NONE))  # M7-rf
	else:
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, at, 0))  # a floor piece under it stays
	var left: int = inv.add(piece, Config.BUILD_REFUND)
	if left > 0 and data.drops.size() < Config.MAX_DROPS:
		var tile: Vector2i = Aim.feet_cell(feet)
		var centre: Vector2i = tile * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
		o.edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), piece, left,
			ItemDB.normalize_grade(piece), centre)))
	return o


## Why the tiles `cells` (a doorway) may not start blocking now ("" = they may): a placeable on one (a death bag), a body of
## `feet` / `bodies` on one (WHY_DOORWAY), another player of `others` within the clearance (WHY_NEAR, M7c).
static func _doorway_refusal(data: WorldData, cells: Array[Vector2i], feet: Vector2, bodies: Array[Vector2],
		others: Array[Vector2]) -> String:
	var all: Array[Vector2] = [feet]
	all.append_array(bodies)
	for cell: Vector2i in cells:
		if data.get_value(WorldData.Layer.PLACEABLE, cell) != WorldData.PLACEABLE_NONE:
			return WHY_DOORWAY
		var px: Rect2 = Rect2(Vector2(cell * Config.TILE), Vector2(Config.TILE, Config.TILE))
		for b: Vector2 in all:
			if px.intersects(Movement.feet_box(b)):
				return WHY_DOORWAY
	if not clear_of_others(cells, others):
		return WHY_NEAR  # M7c
	return ""


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
		var why: String = _doorway_refusal(data, [d, d + DOWN] as Array[Vector2i], feet, bodies, others)
		if not why.is_empty():
			return WorldItems.Outcome.refused(why)
		o.item = &"closed"
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, d, Walls.pack(Walls.KIND_DOOR, 0)))
	else:
		o.item = &"open"
		o.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, d, Walls.pack(Walls.KIND_DOOR_OPEN, 0)))
	o.count = 1
	return o


# --- sealing (PROVISIONAL Config.BUILD_SEAL_REACH_TILES) --------------------------------------------------------------

## Whether putting blocking things on `cells` would wall one of `spots` (feet points where players appear; M7-fix: and the
## other players' feet, refusal) in: from its tile a walk (4 ways, doors open, reaches) gets Config.BUILD_SEAL_REACH_TILES
## away now but would not after.
## M7-fix, the cost (README "M7-fix 봉쇄 검사 비용"; M7b walked every spot near the cells twice, about 16 ms near the altar's
## nine spawn slots, on every build request and build-ghost answer): the answer is the same, found with less walking.
##   - A spot is affected only when a cell is within the walk's reach of it (Chebyshev <= the reach: a farther tile is never
##     stepped on, so `cells` cannot change that walk).
##   - detours(): when the open tiles around `cells` (the ring one tile out) are one run, every walk that crossed `cells`
##     goes round them instead, so nothing that was reachable stops being reachable (but `cells` themselves). A spot then
##     keeps its answer unless it stands in `cells`, or one of them is exactly the reach away (it could be the only far
##     tile) and no open ring tile is that far (an open ring tile is reachable whenever a cell was): those are walked.
##   - reaches() walks deepest first, the step that goes farthest out first (the same answer as the breadth-first walk:
##     both search the whole region when there is no way out).
##   - The spots walked share: the first walks the reach plus the spread of the spots near it (SEAL_SHARE_TILES) away, so a
##     later spot near it that steps onto a tile of that walk gets out too (that walk's far tile is the reach from it); a
##     walk that found no way out tells every spot of its region the answer (its tiles' extent).
static func seals(data: WorldData, cells: Array[Vector2i], spots: Array[Vector2]) -> bool:
	if cells.is_empty():
		return false
	var extra: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in cells:
		extra[c] = true
	var r: int = Config.BUILD_SEAL_REACH_TILES
	var detour: int = -1  # -1 = not worked out yet, 0 = no, 1 = yes
	var ring_open: Array[Vector2i] = []  # the open tiles of the ring (when detour is 1)
	var walk: Array[Vector2i] = []  # the spots whose walk `cells` may change, each tile once
	var done: Dictionary[Vector2i, bool] = {}
	for s: Vector2 in spots:
		var start: Vector2i = Aim.feet_cell(s)
		if done.has(start):
			continue
		done[start] = true
		var nearest: int = r + 1
		var far: int = 0
		for c2: Vector2i in cells:
			var dc: int = _cheb(c2, start)
			nearest = mini(nearest, dc)
			far = maxi(far, dc)
		if nearest > r:
			continue  # no cell is on this spot's walk
		if not extra.has(start):
			if detour < 0:
				detour = 1 if _detour_ring(data, cells, ring_open) else 0
			if detour == 1 and (far < r or ring_open.is_empty() or _any_far(ring_open, start, r)):
				continue
		walk.append(start)
	if walk.is_empty():
		return false
	var spread: int = 0
	for w: Vector2i in walk:
		if _cheb(w, walk[0]) <= SEAL_SHARE_TILES:
			spread = maxi(spread, _cheb(w, walk[0]))
	var none: Dictionary[Vector2i, bool] = {}
	var shared: Dictionary[Vector2i, bool] = {}  # the tiles of walk[0]'s walk when it got r + spread away
	var shut: Dictionary[Vector2i, bool] = {}  # the tiles of a region walked without a way out (after the cells)
	var shut_box: Rect2i = Rect2i()
	for i: int in walk.size():
		var start2: Vector2i = walk[i]
		var after: bool
		if shut.has(start2):
			after = _far_in(shut_box, start2, r)
		else:
			var seen: Dictionary[Vector2i, bool] = {}
			if i == 0:
				after = reaches(data, start2, extra, seen, r + spread)
				if after:
					shared = seen
			else:
				after = reaches(data, start2, extra, seen, r, shared if _cheb(start2, walk[0]) <= SEAL_SHARE_TILES else none)
			if not after and not extra.has(start2):
				shut = seen  # the whole region: no tile r (+ spread) away, no shared tile
				shut_box = _box_of(seen)
				after = _far_in(shut_box, start2, r)
		if not after and reaches(data, start2, none):
			return true
	return false


## IMPL (M7-fix): how far apart (Chebyshev) spots may be to share the first one's walk (Building.seals). The altar's spawn
## slots lie within 3 tiles of each other; a farther spot (the arrival point) walks alone.
const SEAL_SHARE_TILES: int = 8


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Whether a region whose tiles span `box` holds a tile Config.BUILD_SEAL_REACH_TILES (`r`) or more from `start`.
static func _far_in(box: Rect2i, start: Vector2i, r: int) -> bool:
	return maxi(maxi(start.x - box.position.x, box.end.x - 1 - start.x), maxi(start.y - box.position.y,
		box.end.y - 1 - start.y)) >= r


static func _box_of(tiles: Dictionary[Vector2i, bool]) -> Rect2i:
	var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
	var hi: Vector2i = Vector2i(-(1 << 30), -(1 << 30))
	for t: Vector2i in tiles:
		lo = Vector2i(mini(lo.x, t.x), mini(lo.y, t.y))
		hi = Vector2i(maxi(hi.x, t.x), maxi(hi.y, t.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE) if not tiles.is_empty() else Rect2i()


## M7-fix: whether blocking `cells` (a filled rectangle: a wall and its face, a lantern, a station's footprint) leaves every
## walk a way round: the tiles of the ring one tile out from their rectangle that are open now (reaches' rule, doors open)
## form at most one unbroken run around it. Then two tiles that were connected stay connected (a walk that crossed the cells
## enters and leaves through that run and can follow it instead). False for any other shape (the caller walks).
static func detours(data: WorldData, cells: Array[Vector2i]) -> bool:
	var open_tiles: Array[Vector2i] = []
	return _detour_ring(data, cells, open_tiles)


## Whether any of `tiles` is `r` or more (Chebyshev) from `start`.
static func _any_far(tiles: Array[Vector2i], start: Vector2i, r: int) -> bool:
	for t: Vector2i in tiles:
		if _cheb(t, start) >= r:
			return true
	return false


## detours(), and the ring's open tiles into `open_tiles` (when it is true).
static func _detour_ring(data: WorldData, cells: Array[Vector2i], open_tiles: Array[Vector2i]) -> bool:
	open_tiles.clear()
	var lo: Vector2i = cells[0]
	var hi: Vector2i = cells[0]
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if (hi.x - lo.x + 1) * (hi.y - lo.y + 1) != cells.size():
		return false
	var none: Dictionary[Vector2i, bool] = {}
	var ring: Array[Vector2i] = []
	var a: Vector2i = lo - Vector2i.ONE
	var b: Vector2i = hi + Vector2i.ONE
	for x: int in range(a.x, b.x):
		ring.append(Vector2i(x, a.y))
	for y: int in range(a.y, b.y):
		ring.append(Vector2i(b.x, y))
	for x2: int in range(b.x, a.x, -1):
		ring.append(Vector2i(x2, b.y))
	for y2: int in range(b.y, a.y, -1):
		ring.append(Vector2i(a.x, y2))
	var open: Array[bool] = []
	for t: Vector2i in ring:
		open.append(_passable(data, t, none))
	var runs: int = 0
	for i: int in ring.size():
		if open[i] and not open[i - 1]:  # i - 1 = -1 wraps to the last: the ring is a cycle
			runs += 1
		if open[i]:
			open_tiles.append(ring[i])
	return runs <= 1


## Whether a walk from tile `start` (4 ways over tiles that do not block, `extra` blocking too; a door and its face are
## open: anyone opens them) gets Config.BUILD_SEAL_REACH_TILES (Chebyshev) away. False when `start` itself is blocked.
## M7-fix: deepest first, the step that goes farthest from `start` first (on open ground about the reach in steps; M7b's
## breadth-first walk stepped on every tile within the reach first). `seen` gets the tiles walked (all of the region when
## the answer is false). For seals(): `radius` instead of the reach (-1 = the reach), and true as soon as the walk steps
## onto a tile of `meet` (tiles known to lead that far).
static func reaches(data: WorldData, start: Vector2i, extra: Dictionary[Vector2i, bool],
		seen: Dictionary[Vector2i, bool] = {}, radius: int = -1, meet: Dictionary[Vector2i, bool] = {}) -> bool:
	var r: int = radius if radius >= 0 else Config.BUILD_SEAL_REACH_TILES
	seen.clear()
	if not _passable(data, start, extra):
		return false
	if meet.has(start):
		return true
	seen[start] = true
	var stack: Array[Vector2i] = [start]
	var order: Array[Vector2i] = []
	order.resize(4)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		_steps_outward(c - start, order)
		for d: Vector2i in order:
			var n: Vector2i = c + d
			if seen.has(n) or not _passable(data, n, extra):
				continue
			if _cheb(n, start) >= r or meet.has(n):
				return true
			seen[n] = true
			stack.append(n)
	return false


## The four steps in the order reaches() pushes them for a tile at offset `off` from the start: the one that goes farthest
## out last (it is walked first). Ties keep DungeonGen.STEPS' order, so the walk is the same every time.
static func _steps_outward(off: Vector2i, out: Array[Vector2i]) -> void:
	var sx: int = 1 if off.x >= 0 else -1
	var sy: int = 1 if off.y >= 0 else -1
	var out_x: Vector2i = Vector2i(sx, 0)
	var out_y: Vector2i = Vector2i(0, sy)
	# Farthest last: the outward step along the axis that is already farther out, then the other outward one, then back.
	if absi(off.x) >= absi(off.y):
		out[3] = out_x
		out[2] = out_y
	else:
		out[3] = out_y
		out[2] = out_x
	out[1] = -out[2]
	out[0] = -out[3]


static func _passable(data: WorldData, c: Vector2i, extra: Dictionary[Vector2i, bool]) -> bool:
	if not data.in_bounds(c) or extra.has(c):
		return false
	if Walls.is_door(data, c) or (not Walls.is_wall(data, c) and Walls.is_door(data, c + UP)):
		return true
	return not Movement.is_blocked(data, c)
