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
const KIND_NAMES: PackedStringArray = ["none", "rock", "bedrock"]
const KIND_MASK: int = 0x0f
const HITS_SHIFT: int = 4
const HITS_MAX: int = 15

const ORE_NONE: int = 0
const ORE_COPPER: int = 1
const ORE_IRON: int = 2
const ORE_NAMES: PackedStringArray = ["none", "copper", "iron"]
## Item a broken ore tile gives (items/item_db.gd), by ore value.
const ORE_ITEMS: Array[StringName] = [&"", &"ore_copper", &"ore_iron"]

## Hardness of a tile nothing can break (bedrock, and anything under a placeable such as the exit).
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


static func is_wall(data: WorldData, c: Vector2i) -> bool:
	return kind_at(data, c) != KIND_NONE


## A floor tile with a wall right above it: the wall's front face is drawn here (blocked).
static func is_face(data: WorldData, c: Vector2i) -> bool:
	return data.in_bounds(c) and not is_wall(data, c) and is_wall(data, c + Vector2i(0, -1))


## Blocked for walking by a wall: the wall itself or its face.
static func blocks(data: WorldData, c: Vector2i) -> bool:
	return is_wall(data, c) or is_face(data, c)


## The wall a hit on tile `c` lands on: `c` itself if it is a wall, the wall above if `c` is a face,
## NO_CELL otherwise.
static func owner_of(data: WorldData, c: Vector2i) -> Vector2i:
	if is_wall(data, c):
		return c
	if is_face(data, c):
		return c + Vector2i(0, -1)
	return NO_CELL


## Hardness grade of wall tile `c` (UNBREAKABLE for bedrock, for a wall carrying a placeable and for a
## wall above a placeable on its face, e.g. the exit stairs; 0 = no wall).
static func hardness(data: WorldData, c: Vector2i) -> int:
	var kind: int = kind_at(data, c)
	if kind == KIND_NONE:
		return 0
	if kind == KIND_BEDROCK:
		return UNBREAKABLE
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
static func vertex(data: WorldData, v: Vector2i) -> int:
	if not data.in_bounds(v):
		return V_WALL
	if is_wall(data, v):
		return V_WALL
	var above: Vector2i = v + Vector2i(0, -1)
	if not data.in_bounds(above) or is_wall(data, above):
		return V_FACE
	return V_FLOOR


## Wall tiles in the map, row by row.
static func wall_cells(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: PackedByteArray = data.layers[WorldData.Layer.WALL]
	for i: int in grid.size():
		if grid[i] & KIND_MASK != KIND_NONE:
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
