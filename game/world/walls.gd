class_name Walls
extends RefCounted
## Breakable walls in a WorldData (M3a, the first dungeon; ● gameplay-design §3.1 layers: wall
## (breakable) and ore). Pure functions on the data, shared by the generator, movement, mining and
## the cave view.
##
## WALL layer byte = kind (bits 0-3) | hits taken so far (bits 4-7): 0 = no wall, ROCK, BEDROCK (the
## unbreakable ring around the dungeon). Keeping the hits in the same byte means a mining edit is one
## ordinary cell edit, and the late-join snapshot, the content hash and the edit log carry partly
## mined walls without anything new. ORE layer = the ore inside a wall (0 none, copper, iron).
##
## Faces (3/4 view): a wall's front face (24 px in the 04-env cliff tileset) hangs over the tile south
## of it. That tile is a "face" tile: floor in the data, but blocked for walking (Movement), because
## what is drawn there is the wall; aiming at it hits the wall above it (owner_of). So a wall's
## footprint seen and felt is the wall tile plus its face tile when the tile below is open.
##
## Render value of a vertex (the dual grid, world/cave_view.gd): WALL for a wall tile (and outside the
## map), FACE for a face tile, FLOOR otherwise. That is the 04-env tileset's own rule: "a cliff face
## occupies the map cell BELOW the terrain boundary" (tiles_dungeon_v01.json layout).

const KIND_NONE: int = 0
const KIND_ROCK: int = 1
const KIND_BEDROCK: int = 2
## M7b, built pieces (● gameplay-design §3.3 R37: a built wall is the same layer as the dungeon's walls, above the floor;
## stone only; items/building.gd): a stone wall and a door (closed / open: one cell edit opens or closes it). Built pieces
## carry no hits (mining does not break them: right-click takes them down).
## Kind 6 is retired: M7b's laid floor piece (KIND_FLOOR, a wall-byte kind that blocked nothing, so a tile held a wall or a
## floor piece). M7-rf (the human's decision of 2026-10-26, ● §3.1 / §3.3 R37) moved floor pieces to the floor side
## (WorldData.Layer.FLOOR_PIECE), under the wall layer: a wall or a door stands on one. No WALL byte holds 6 now; the other
## kinds keep their numbers, and a stray 6 (or 7..15) is no wall and nothing built (is_wall_kind lists the kinds).
const KIND_STONE: int = 3
const KIND_DOOR: int = 4
const KIND_DOOR_OPEN: int = 5
const KIND_NAMES: PackedStringArray = ["none", "rock", "bedrock", "stone", "door", "door_open"]
const KIND_MASK: int = 0x0f
const HITS_SHIFT: int = 4
const HITS_MAX: int = 15

const ORE_NONE: int = 0
const ORE_COPPER: int = 1
const ORE_IRON: int = 2
const ORE_NAMES: PackedStringArray = ["none", "copper", "iron"]
## Item a broken ore tile gives (items/item_db.gd), by ore value.
const ORE_ITEMS: Array[StringName] = [&"", &"ore_copper", &"ore_iron"]

## Hardness of a tile nothing can break (bedrock, and a wall right above a blocking placeable on its
## face, such as the rock above the exit stairs).
const UNBREAKABLE: int = 99

## Vertex render values (= corner values of the cliff tileset: lower, upper, transition).
const V_FLOOR: int = 0
const V_WALL: int = 1
const V_FACE: int = 2

const NO_CELL: Vector2i = Vector2i(-1, -1)


static func pack(kind: int, hits: int) -> int:
	return (kind & KIND_MASK) | (clampi(hits, 0, HITS_MAX) << HITS_SHIFT)


## Wall kind on tile `c` (KIND_NONE outside the map).
static func kind_at(data: WorldData, c: Vector2i) -> int:
	return data.get_value(WorldData.Layer.WALL, c) & KIND_MASK


## Hits tile `c` has taken (0 = untouched).
static func hits_at(data: WorldData, c: Vector2i) -> int:
	return data.get_value(WorldData.Layer.WALL, c) >> HITS_SHIFT


static func ore_at(data: WorldData, c: Vector2i) -> int:
	return data.get_value(WorldData.Layer.ORE, c)


## A wall on tile `c`: a dungeon wall (rock, bedrock) or (M7b) a built one (stone wall, door open or closed). It has a top
## and casts a face on the tile below when that one is no wall. A floor piece is no wall (M7-rf: not in this byte at all).
static func is_wall(data: WorldData, c: Vector2i) -> bool:
	return is_wall_kind(kind_at(data, c))


## M7-rf: the wall kinds by name (rock .. door_open); any other value (the retired 6, unused 7..15) is no wall.
static func is_wall_kind(kind: int) -> bool:
	return kind >= KIND_ROCK and kind <= KIND_DOOR_OPEN


## M7b: a dungeon wall (the generator's rock and bedrock: the cave view draws it, mining breaks it).
static func is_natural(data: WorldData, c: Vector2i) -> bool:
	var k: int = kind_at(data, c)
	return k == KIND_ROCK or k == KIND_BEDROCK


## M7b: a built wall piece on tile `c` (a stone wall or a door, open or closed; the build view draws it).
static func is_built(data: WorldData, c: Vector2i) -> bool:
	return is_built_kind(kind_at(data, c))


static func is_built_kind(kind: int) -> bool:
	return kind == KIND_STONE or kind == KIND_DOOR or kind == KIND_DOOR_OPEN


static func is_door(data: WorldData, c: Vector2i) -> bool:
	var k: int = kind_at(data, c)
	return k == KIND_DOOR or k == KIND_DOOR_OPEN


static func is_open_door(data: WorldData, c: Vector2i) -> bool:
	return kind_at(data, c) == KIND_DOOR_OPEN


## A floor tile with a wall right above it: the wall's front face is drawn here (blocked).
static func is_face(data: WorldData, c: Vector2i) -> bool:
	return data.in_bounds(c) and not is_wall(data, c) and is_wall(data, c + Vector2i(0, -1))


## Blocked for walking by a wall: the wall itself or its face. M7b: an open door and its face let everyone through (players,
## heretics, shots: what is drawn there is the open doorway); a closed door blocks like a wall.
static func blocks(data: WorldData, c: Vector2i) -> bool:
	if is_wall(data, c):
		return kind_at(data, c) != KIND_DOOR_OPEN
	return is_face(data, c) and kind_at(data, c + Vector2i(0, -1)) != KIND_DOOR_OPEN


## The wall a hit on tile `c` lands on: `c` itself if it is a wall, the wall above if `c` is a face,
## NO_CELL otherwise.
static func owner_of(data: WorldData, c: Vector2i) -> Vector2i:
	if is_wall(data, c):
		return c
	if is_face(data, c):
		return c + Vector2i(0, -1)
	return NO_CELL


## Hardness grade of wall tile `c`: UNBREAKABLE for bedrock and for a wall above a blocking placeable
## on its face (e.g. the exit stairs); 0 = no wall. A placeable on the wall tile itself (a wall torch)
## does not protect it: the torch falls with its wall (Mining.strike).
static func hardness(data: WorldData, c: Vector2i) -> int:
	var kind: int = kind_at(data, c)
	if not is_wall_kind(kind):
		return 0
	if kind == KIND_BEDROCK or is_built_kind(kind):
		return UNBREAKABLE  # M7b: a built piece is taken down with right-click, never mined (Building.demolish)
	var under: Vector2i = c + Vector2i(0, 1)
	if not is_wall(data, under) and WorldData.placeable_blocks(data.get_value(WorldData.Layer.PLACEABLE, under)):
		return UNBREAKABLE
	match ore_at(data, c):
		ORE_COPPER:
			return Config.HARDNESS_COPPER
		ORE_IRON:
			return Config.HARDNESS_IRON
	return Config.HARDNESS_ROCK


## Hits wall tile `c` takes before it breaks (0 for no wall or an unbreakable one).
static func max_hits(data: WorldData, c: Vector2i) -> int:
	if hardness(data, c) == UNBREAKABLE or not is_wall(data, c):
		return 0
	match ore_at(data, c):
		ORE_COPPER:
			return Config.WALL_HITS_COPPER
		ORE_IRON:
			return Config.WALL_HITS_IRON
	return Config.WALL_HITS_ROCK


## Crack stage shown for `hits` of `max_hits`: 0 = none, then 1..3 by thirds (PROVISIONAL: three
## stages because the 04-env crack art has three, wall_crack_top / wall_crack_face).
static func crack_stage(hits: int, max: int) -> int:
	if hits <= 0 or max <= 0:
		return 0
	return clampi(ceili(3.0 * float(hits) / float(max)), 1, 3)


## Render value of vertex `v` (= world tile v): WALL, FACE or FLOOR. Outside the map counts as wall.
## FACE is exactly is_face() (M3-fix: a floor tile in row 0 was drawn as a face of the wall outside the
## map but was open for walking; now it draws as floor, so what is drawn is what blocks. Generated
## dungeons never have it: their bedrock ring cannot be broken).
## M7b: only the dungeon's own walls count here (the cave view draws them); a built wall's tile reads as floor (the build
## view draws the piece over it). A built wall never stands on a dungeon wall's face tile (Building), so a natural face is
## never a built wall.
static func vertex(data: WorldData, v: Vector2i) -> int:
	if not data.in_bounds(v):
		return V_WALL
	if is_natural(data, v):
		return V_WALL
	if is_natural(data, v + Vector2i(0, -1)) and not is_wall(data, v):
		return V_FACE
	return V_FLOOR


## Wall tiles in the map, row by row.
static func wall_cells(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: PackedByteArray = data.layers[WorldData.Layer.WALL]
	for i: int in grid.size():
		if is_wall_kind(grid[i] & KIND_MASK):
			out.append(Vector2i(i % data.size.x, i / data.size.x))
	return out


## Walls with an ore, row by row.
static func ore_cells(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: PackedByteArray = data.layers[WorldData.Layer.ORE]
	for i: int in grid.size():
		if grid[i] != ORE_NONE:
			out.append(Vector2i(i % data.size.x, i / data.size.x))
	return out
