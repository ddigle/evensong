class_name Mining
extends RefCounted
## Mining (M3a): what one pickaxe swing does to the walls (world/walls.gd). Pure functions on WorldData
## + Inventory, like items/world_items.gd: strike() changes the inventory and returns the world edits
## (the caller applies, logs and sends them: offline core/main.gd, the host net/session_host.gd).
##
## ● gameplay-design §3.0 (R11) miner row: anyone mines, "느리고 1×1, 경도 상한"; the miner "3×3 고속,
## 상위 경도". So a common player's swing hits the one tile, the miner's swing a 3x3 block, and each
## class breaks tiles up to its hardness cap. The numbers (hardness grades, hits per tile, hits per
## swing: the miner's counts double), whether the 3x3 reaches away from the player, and what a broken
## tile gives are PROVISIONAL (core/config.gd "M3a"). ○ §3.2: the target is the tile next to the feet
## toward the mouse (the M2 target tile), holding repeats (M2), "드롭은 인벤토리로 자동" (what does not
## fit lies on the broken tile).
##
## The swing lands on Config.MINING_IMPACT_FRAME of the pickaxe action (Mining.impact_tick()).
## A target that is a wall's face tile hits that wall (Walls.owner_of). Nothing breakable there (no
## wall, bedrock, the rock above the exit stairs, too hard for the class): nothing happens but the
## swing. That holds for the miner's 3x3 too: it only reaches around a tile the swing can break
## (M3-fix: a miner swinging at the exit stairs broke the rock beside and behind their bedrock cap).
##
## Hardness (PROVISIONAL): gameplay-design §3.1 (unmarked bullet) gates breaking by pickaxe grade
## ("곡괭이 등급이 경도 이상이어야 파괴", higher ores need a higher pickaxe). M3 has one pickaxe without a
## grade; the class cap (● R11 "경도 상한" / "상위 경도", hardness_cap) stands in for it. Pickaxe tiers
## are not modelled (README "임시값", for the human to confirm).

const PICKAXE: StringName = &"pickaxe"
## ● the class whose mining is 3x3, fast and reaches the higher hardness (gameplay-design §3.0 R11).
const MINER_CLASS: String = "miner"
const WHY_NO_WALL: String = "no wall"
const WHY_TOO_HARD: String = "too hard"


## What one swing did.
class Result:
	extends RefCounted
	var why: String = ""
	var edits: Array[EditLog.WorldEdit] = []
	## Tiles the swing hit (each took the swing's hits) and those of them that broke.
	var hit: Array[Vector2i] = []
	var broken: Array[Vector2i] = []
	## Items from broken tiles that went into the inventory, and those that did not fit (dropped on
	## their tile) or were lost (the ground already held Config.MAX_DROPS drops).
	var gained: Dictionary[StringName, int] = {}
	var dropped: Dictionary[StringName, int] = {}
	var lost: int = 0

	func ok() -> bool:
		return why.is_empty()

	func describe() -> String:
		return "hit=%d broken=%d gained=%s dropped=%s lost=%d" % [hit.size(), broken.size(), gained, dropped, lost]


## The simulation tick of the pickaxe action on which the swing lands.
static func impact_tick() -> int:
	return Config.MINING_IMPACT_FRAME * Config.ACTION_FRAME_TICKS


static func is_miner(class_id: String) -> bool:
	return class_id == MINER_CLASS


## Hits one swing deals (PROVISIONAL, the miner's "고속").
static func power(class_id: String) -> int:
	return Config.MINING_POWER_MINER if is_miner(class_id) else Config.MINING_POWER_COMMON


## Highest hardness grade the class breaks (PROVISIONAL, ● "경도 상한" / "상위 경도").
static func hardness_cap(class_id: String) -> int:
	return Config.HARDNESS_CAP_MINER if is_miner(class_id) else Config.HARDNESS_CAP_COMMON


## Tiles a swing on wall `owner` covers for a player whose feet tile is `feet_cell`: the tile alone,
## or for the miner 3x3 (● R11): starting at the tile and reaching away from the player, centred
## across the swing (Config.MINER_AREA_AWAY), or centred on the tile.
static func area(owner: Vector2i, feet_cell: Vector2i, class_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_miner(class_id):
		out.append(owner)
		return out
	var lo: Vector2i = Vector2i(-1, -1)
	if Config.MINER_AREA_AWAY:
		var d: Vector2i = Vector2i(signi(owner.x - feet_cell.x), signi(owner.y - feet_cell.y))
		lo = Vector2i(-1 if d.x == 0 else (0 if d.x > 0 else -2), -1 if d.y == 0 else (0 if d.y > 0 else -2))
	for y: int in range(lo.y, lo.y + 3):
		for x: int in range(lo.x, lo.x + 3):
			out.append(owner + Vector2i(x, y))
	return out


## One swing of a player of `class_id` with feet at `feet` on target tile `target`.
static func strike(data: WorldData, feet: Vector2, class_id: String, inv: Inventory, target: Vector2i) -> Result:
	var r: Result = Result.new()
	var owner: Vector2i = Walls.owner_of(data, target)
	if owner == Walls.NO_CELL:
		r.why = WHY_NO_WALL
		return r
	# Defensive: in play this cannot fail (the use was checked in reach when the action started and
	# Config.ACTION_LOCKS_MOVEMENT keeps the feet still until the swing lands); it matters only if
	# that provisional lock is turned off.
	if not WorldItems.in_reach(feet, target):
		r.why = WorldItems.WHY_REACH
		return r
	var cap: int = hardness_cap(class_id)
	if Walls.hardness(data, owner) > cap:
		r.why = WHY_TOO_HARD
		return r
	var hits: int = power(class_id)
	var drops_left: int = Config.MAX_DROPS - data.drops.size()
	for c: Vector2i in area(owner, Aim.feet_cell(feet), class_id):
		if not Walls.is_wall(data, c) or Walls.hardness(data, c) > cap:
			continue
		r.hit.append(c)
		var total: int = Walls.hits_at(data, c) + hits
		if total < Walls.max_hits(data, c):
			r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, c, Walls.pack(Walls.kind_at(data, c), total)))
			continue
		r.broken.append(c)
		var ore: int = Walls.ore_at(data, c)
		var item: StringName = Walls.ORE_ITEMS[ore] if ore != Walls.ORE_NONE else Config.MINED_ROCK_ITEM
		r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, c, 0))
		if ore != Walls.ORE_NONE:
			r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.ORE, c, 0))
		if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
			r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, c, 0))  # a wall torch falls with its wall
		if inv.add(item, 1) == 0:
			var got: int = r.gained.get(item, 0)
			r.gained[item] = got + 1
		elif drops_left > 0:
			drops_left -= 1
			var fell: int = r.dropped.get(item, 0)
			r.dropped[item] = fell + 1
			var center: Vector2i = c * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
			r.edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), item, 1,
				ItemDB.normalize_grade(item), center)))
		else:
			r.lost += 1
	if r.hit.is_empty():
		r.why = WHY_TOO_HARD
	return r
