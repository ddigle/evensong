class_name Forest
extends RefCounted
## M7b: one map's trees (offline Main and, M7c, the host: one Forest per map). ● game-concept §12 R37: one
## tree species is the wood source and anyone chops it; ○ the tool is the axe. The tree is a placeable (WorldData.
## PLACEABLE_TREE, the trunk's one tile, blocking; SurfaceGen step 6 puts them down); a felled tree leaves its stump
## (PLACEABLE_STUMP, the same picture's trunk base, world/fixture_view.gd).
## PROVISIONAL (core/config.gd "M7b", README "임시값" M7b): only the axe chops (Config: any other tool aimed at a trunk does
## what it always did), every class alike; a swing lands on the axe action's Config.AXE_IMPACT_FRAME; Config.TREE_CHOP_HITS
## swings that land fell the tree: Config.TREE_LOGS logs go into the inventory (what does not fit lies on the trunk tile),
## the tile becomes a stump; a stump grows back into a tree after Config.TREE_REGROW_TICKS (0 = never).
## Like world/farm.gd: what everyone sees (tree or stump) is the world's (one PLACEABLE cell edit), what nobody sees (the
## swings a tree took, a stump's time left) is kept here per map; every method returns edits and never writes the data
## (the caller applies them before it calls anything here again). No clock, no random numbers: the same swings on the same
## ticks give the same world.

const AXE: StringName = &"axe"
const WHY_NO_TREE: String = "no tree there"
const WHY_NOT_AXE: String = "the axe chops"


## What one swing did: ok or why not, the edits (the stump, a drop of what did not fit), the swings the tree has taken, and
## whether it fell; the logs that went into the inventory and those that did not fit (dropped) or were lost (MAX_DROPS).
class Result:
	extends RefCounted
	var why: String = ""
	var edits: Array[EditLog.WorldEdit] = []
	var hits: int = 0
	var felled: bool = false
	var logs: int = 0
	var dropped: int = 0
	var lost: int = 0

	func ok() -> bool:
		return why.is_empty()

	func describe() -> String:
		return "hits=%d felled=%s logs=%d dropped=%d lost=%d" % [hits, felled, logs, dropped, lost]

	static func refused(reason: String) -> Result:
		var r: Result = Result.new()
		r.why = reason
		return r


var data: WorldData
## Swings each standing tree has taken (by tile; a tree with none is not listed).
var hits: Dictionary[Vector2i, int] = {}
## Ticks left before each stump grows back (by tile).
var regrow: Dictionary[Vector2i, int] = {}
## Ticks a stump takes (Config.TREE_REGROW_TICKS; tests may shorten it).
var regrow_ticks: int = Config.TREE_REGROW_TICKS
## Counters: swings, felled, regrown.
var stats: Dictionary[String, int] = {}


func _init(p_data: WorldData = null) -> void:
	if p_data != null:
		setup(p_data)


## Timers for `p_data` (generated, received or swapped in): no tree has taken a swing, every stump waits the whole time
## (the timers are not part of the world). M7-fix: with regrowth off (regrow_on false) no stump is timed (M7b timed them
## with 0 ticks: every stump grew back on the next tick).
func setup(p_data: WorldData) -> void:
	data = p_data
	hits.clear()
	regrow.clear()
	stats.clear()
	if not regrow_on():
		return
	var grid: PackedByteArray = data.layers[WorldData.Layer.PLACEABLE]
	for i: int in grid.size():
		if grid[i] == WorldData.PLACEABLE_STUMP:
			regrow[Vector2i(i % data.size.x, i / data.size.x)] = regrow_ticks


## The simulation tick of the axe action on which its swing lands.
static func impact_tick() -> int:
	return Config.AXE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS


static func is_tree(data: WorldData, c: Vector2i) -> bool:
	return data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_TREE


## Why a swing of `item` from feet `feet` at tile `c` chops nothing ("" = it chops): the axe (Gear.base: an axe), on the
## map, in reach, a standing tree there.
static func chop_refusal(data: WorldData, feet: Vector2, item: StringName, c: Vector2i) -> String:
	if Gear.base(item) != AXE:
		return WHY_NOT_AXE
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if not is_tree(data, c):
		return WHY_NO_TREE
	return ""


## One axe swing landing on tile `c` from feet `feet` into `inv` (any class: ● R37). The tree's swings go up; at
## Config.TREE_CHOP_HITS it falls: the stump edit, Config.TREE_LOGS logs into `inv` (the rest one drop on the tile; none
## when the map holds MAX_DROPS), the stump's regrowth timer starts.
func chop(feet: Vector2, inv: Inventory, item: StringName, c: Vector2i) -> Result:
	var why: String = chop_refusal(data, feet, item, c)
	if not why.is_empty():
		return Result.refused(why)
	var r: Result = Result.new()
	var n: int = hits.get(c, 0) + 1
	_count("swings")
	r.hits = n
	if n < Config.TREE_CHOP_HITS:
		hits[c] = n
		return r
	hits.erase(c)
	r.felled = true
	_count("felled")
	r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_STUMP))
	var left: int = inv.add(&"log", Config.TREE_LOGS)
	r.logs = Config.TREE_LOGS - left
	if left > 0:
		if data.drops.size() < Config.MAX_DROPS:
			r.dropped = left
			var centre: Vector2i = c * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
			r.edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), &"log", left,
				ItemDB.normalize_grade(&"log"), centre)))
		else:
			r.lost = left
	if regrow_on():
		regrow[c] = regrow_ticks
	return r


## Whether stumps grow back (Config.TREE_REGROW_TICKS and regrow_ticks above 0; 0 = never).
func regrow_on() -> bool:
	return Config.TREE_REGROW_TICKS > 0 and regrow_ticks > 0


## One tick: every stump's time runs down (row by row); a stump at 0 grows back (its edit). A tile that is no stump any
## more (changed by an edit from elsewhere) is forgotten. Nothing while regrowth is off (regrow_on). PROVISIONAL
## Config.TREE_STUMP_BLOCKS: the trunk comes back without looking for bodies or spots where players appear on the tile; that
## is safe only while a stump blocks too (nobody stands on one; README "M7b 그루터기").
func step() -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = []
	if data == null or regrow.is_empty() or not regrow_on():
		return out
	var keys: Array[Vector2i] = []
	keys.assign(regrow.keys())
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c: Vector2i in keys:
		if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_STUMP:
			regrow.erase(c)
			continue
		var t: int = regrow[c] - 1
		if t > 0:
			regrow[c] = t
			continue
		regrow.erase(c)
		_count("regrown")
		out.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_TREE))
	return out


func stat(key: String) -> int:
	var v: int = stats.get(key, 0)
	return v


func _count(key: String) -> void:
	stats[key] = stat(key) + 1


## Every tree tile of `p_data`, row by row.
static func tree_cells(p_data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var grid: PackedByteArray = p_data.layers[WorldData.Layer.PLACEABLE]
	for i: int in grid.size():
		if grid[i] == WorldData.PLACEABLE_TREE:
			out.append(Vector2i(i % p_data.size.x, i / p_data.size.x))
	return out
