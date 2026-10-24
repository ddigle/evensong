class_name Farming
extends RefCounted
## Farming (M5a, offline first): the rules for the hoe, the seeds, the watering can and the sickle, and how a field
## tile is stored. Pure functions on WorldData + Inventory like items/mining.gd and items/world_items.gd; the timers
## (growth, water) and the actions that change the world are world/farm.gd's (one Farm per map, stepped every tick),
## and the caller applies the edits (offline core/main.gd; M5c: the host, net/session_host.gd).
##
## ● decided (followed as written):
##   - three crops, healing herb / buff herb / poison herb (game-concept §12 R28), one potion each (M6);
##   - who plants what (game-concept §12 R37, gameplay-design §3.8's ● R37 slice line): the healing and buff herbs anyone
##     (COMMON grade), the poison herb's seeds the herbalist only.
## ○ implemented as the default (M5-fix: was listed above as ●; game-concept §9.7, gameplay-design §3.8 and the §1 key
## table are ○): the tools and their order: the hoe tills, a seed is planted, the watering can waters, the crop grows in
## stages, the sickle harvests (README "임시값" M5a rows); the fields stay where they are when the altar moves.
## ○ / not in the docs (PROVISIONAL, core/config.gd "M5a", README "임시값" M5a): fields only inside the altar light
## (TILL_ONLY_IN_LIGHT), what can be tilled (grass; the M1 soil patches already are tilled), no untilling or decay, seeds
## from wild herbs and from the harvest, water lasting WATER_TICKS, CROP_STAGE_TICKS per stage, the herbalist's
## CROP_HERBALIST_GROWTH_PCT, the grade by the harvester (CROP_GRADE_BY_HARVESTER), the harvest's herbs and seeds,
## withering outside the light or with corruption within CROP_CORRUPTION_REACH_TILES, the sickle rule below.
##
## A field tile = FLOOR soil (Terrain.SOIL; tilling is a floor edit like the M1 debug edit) + its VEGETATION value:
##   0                  dry bare soil
##   Field.value()      Config.FIELD_BASE + kind * FIELD_KIND_STEP + stage * FIELD_STAGE_STEP + flags
##                      (FLAG_WITHERED, FLAG_WET, FLAG_FAST = planted by the herbalist); a bare wet tile is kind 0 + wet.
## The gatherables keep 1..15, so a field value is never a gatherable (WorldItems.gatherable_for gives &"") and
## everything that reads VEGETATION != 0 as "something grows here" (torches, tables, bags, the debug drop) treats a
## crop and a wet tile the same way. The world's snapshot, hash and edit log carry the fields as they are.
##
## The sickle (the herbalist's weapon, M4a) aimed at a crop tile (any stage) harvests instead of attacking, like the
## pickaxe aimed at a wall mines instead (M4a): a ripe crop is cut, an unripe or withered one is refused ("not ripe",
## "withered") and nothing is attacked. Aimed anywhere else it is the weapon as before (is_harvest_swing).

const HOE: StringName = &"hoe"
const WATERING_CAN: StringName = &"watering_can"
const SICKLE: StringName = &"sickle"
## ● the class with the poison herb's seeds (game-concept §12 R37); ○ its faster growth and FINE harvest (§9.7).
const HERB_CLASS: String = "herbalist"

## Crop kinds (● game-concept §12 R28). KIND_NONE = no crop (bare soil).
const KIND_NONE: int = 0
const KIND_HEALING: int = 1
const KIND_BUFF: int = 2
const KIND_POISON: int = 3
const KIND_COUNT: int = 4
const CROP_NAMES: PackedStringArray = ["none", "healing", "buff", "poison"]
## Seed items and harvested herbs by crop kind (index 0 unused). The herbs are the wild herbs' items (M2b), so the
## M6 recipes brew the harvest as they brew picked herbs.
const SEEDS: Array[StringName] = [&"", &"seed_healing", &"seed_buff", &"seed_poison"]
const HERBS: Array[StringName] = [&"", &"wild_healing", &"wild_buff", &"wild_poison"]
## Stages 0..4 (04-env crops_v03_sheet columns 0..4); 4 = ripe, the one the sickle cuts.
const STAGES: int = 5
const RIPE_STAGE: int = 4
const FLAG_FAST: int = 1
const FLAG_WET: int = 2
const FLAG_WITHERED: int = 4

## Why a farming action was refused (names are what logs and test results count).
const WHY_NO_GROUND: String = "no ground to till"
const WHY_TILLED: String = "already tilled"
const WHY_ASH: String = "corrupted ground"
const WHY_GROWING: String = "something grows there"
const WHY_DARK: String = "outside the light"
const WHY_ASH_NEAR: String = "too close to corruption"
const WHY_NOT_TILLED: String = "not tilled"
const WHY_PLANTED: String = "already planted"
const WHY_NOT_SEED: String = "not a seed"
const WHY_HERBALIST: String = "herbalist only"
const WHY_NO_CROP: String = "no crop"
const WHY_NOT_RIPE: String = "not ripe"
const WHY_WITHERED: String = "withered"


## A field tile's state (its VEGETATION value, decoded).
class Field:
	extends RefCounted
	var kind: int = 0
	var stage: int = 0
	var withered: bool = false
	var wet: bool = false
	var fast: bool = false

	func _init(p_kind: int = 0, p_stage: int = 0, p_wet: bool = false, p_fast: bool = false, p_withered: bool = false) -> void:
		kind = p_kind
		stage = p_stage
		wet = p_wet
		fast = p_fast
		withered = p_withered

	## The VEGETATION value (0 = dry bare soil).
	func value() -> int:
		if kind == Farming.KIND_NONE:
			return Config.FIELD_BASE + Farming.FLAG_WET if wet else 0
		var flags: int = (Farming.FLAG_WITHERED if withered else 0) + (Farming.FLAG_WET if wet else 0) \
			+ (Farming.FLAG_FAST if fast else 0)
		return Config.FIELD_BASE + kind * Config.FIELD_KIND_STEP + stage * Config.FIELD_STAGE_STEP + flags

	func ripe() -> bool:
		return kind != Farming.KIND_NONE and stage >= Farming.RIPE_STAGE

	func copy() -> Field:
		return Field.new(kind, stage, wet, fast, withered)

	func describe() -> String:
		if kind == Farming.KIND_NONE:
			return "soil%s" % (" wet" if wet else "")
		return "%s stage=%d%s%s%s" % [Farming.CROP_NAMES[kind], stage, " wet" if wet else "", " withered" if withered else "",
			" fast" if fast else ""]

	## The field a VEGETATION value stands for, or null (0, a gatherable, a value no field has).
	static func of(v: int) -> Field:
		if v < Config.FIELD_BASE or v >= Config.FIELD_BASE + Farming.KIND_COUNT * Config.FIELD_KIND_STEP:
			return null
		var rest: int = v - Config.FIELD_BASE
		var kind_of: int = rest / Config.FIELD_KIND_STEP
		rest -= kind_of * Config.FIELD_KIND_STEP
		var stage_of: int = rest / Config.FIELD_STAGE_STEP
		var flags: int = rest - stage_of * Config.FIELD_STAGE_STEP
		if kind_of == Farming.KIND_NONE and (stage_of != 0 or flags != Farming.FLAG_WET):
			return null
		if stage_of >= Farming.STAGES:
			return null
		return Field.new(kind_of, stage_of, flags & Farming.FLAG_WET != 0, flags & Farming.FLAG_FAST != 0,
			flags & Farming.FLAG_WITHERED != 0)


## The field on tile `c` (null: no crop and not wet, or not a field value).
static func field_at(data: WorldData, c: Vector2i) -> Field:
	return Field.of(data.get_value(WorldData.Layer.VEGETATION, c))


## Whether tile `c` is tilled soil (the M1 soil patches included).
static func is_tilled(data: WorldData, c: Vector2i) -> bool:
	return data.in_bounds(c) and data.terrain_at(c) == Terrain.SOIL


## Whether tile `c` lies in the altar light: all four of its corners inside the safe zone (SafeZone, THE rule; the
## generator's M1 soil patches use the same corners). A map without an altar has no light.
static func in_light(data: WorldData, c: Vector2i, zone: SafeZone = null) -> bool:
	var z: SafeZone = zone if zone != null else SafeZone.for_world(data)
	var p: Vector2 = Vector2(c * Config.TILE)
	var t: float = float(Config.TILE)
	return z.is_in_safe_zone(p) and z.is_in_safe_zone(p + Vector2(t, 0.0)) and z.is_in_safe_zone(p + Vector2(0.0, t)) \
		and z.is_in_safe_zone(p + Vector2(t, t))


## Whether a corrupted tile (CORRUPTION layer) lies within Config.CROP_CORRUPTION_REACH_TILES of `c` (Chebyshev, `c`
## itself included).
static func near_corruption(data: WorldData, c: Vector2i) -> bool:
	var r: int = Config.CROP_CORRUPTION_REACH_TILES
	var grid: PackedByteArray = data.layers[WorldData.Layer.CORRUPTION]
	var w: int = data.size.x
	for y: int in range(maxi(c.y - r, 0), mini(c.y + r, data.size.y - 1) + 1):
		for x: int in range(maxi(c.x - r, 0), mini(c.x + r, w - 1) + 1):
			if grid[y * w + x] != 0:
				return true
	return false


## Why a crop on tile `c` withers (○ §9.7 "빛 밖에 남은 밭이나 오염에 닿은 작물은 시든다"): "" = it grows, WHY_DARK = outside
## the light, WHY_ASH_NEAR = corruption within reach. The light comes first.
static func withers_at(data: WorldData, c: Vector2i, zone: SafeZone = null) -> String:
	if not in_light(data, c, zone):
		return WHY_DARK
	if near_corruption(data, c):
		return WHY_ASH_NEAR
	return ""


## Ticks of growth per stage for a crop (the herbalist's: Config.CROP_HERBALIST_GROWTH_PCT faster). M5c: `base` > 0 stands
## for Config.CROP_STAGE_TICKS (the test flag --test-crop-ticks, Farm.stage_ticks_base: sessions see growth in seconds).
static func stage_ticks(fast: bool, base: int = 0) -> int:
	var common: int = base if base > 0 else Config.CROP_STAGE_TICKS
	if not fast:
		return common
	return maxi(1, common * 100 / maxi(1, Config.CROP_HERBALIST_GROWTH_PCT))


## M5c (the rule of M5a's Main.seed_from_wild, now shared with the host): a wild herb picked where it grew gives
## Config.SEEDS_PER_WILD_HERB seeds of its crop into `inv` (PROVISIONAL README "M5a 씨앗 얻기"). Returns how many went in
## (what does not fit is not given).
static func seeds_from_wild(inv: Inventory, herb: StringName) -> int:
	var kind: int = herb_kind(herb)
	if kind == KIND_NONE or Config.SEEDS_PER_WILD_HERB <= 0:
		return 0
	return Config.SEEDS_PER_WILD_HERB - inv.add(SEEDS[kind], Config.SEEDS_PER_WILD_HERB)


## The crop kind of seed item `id` (KIND_NONE: not a seed).
static func seed_kind(id: StringName) -> int:
	var k: int = SEEDS.find(id)
	return k if k > 0 else KIND_NONE


## The crop kind of the seed stack in inventory slot `slot` (KIND_NONE: none there).
static func seed_kind_in(inv: Inventory, slot: int) -> int:
	if slot < 0 or slot >= inv.size() or inv.stack_at(slot) == null:
		return KIND_NONE
	return seed_kind(inv.stack_at(slot).id)


## The crop kind a wild herb item belongs to (KIND_NONE: not one of the three).
static func herb_kind(id: StringName) -> int:
	var k: int = HERBS.find(id)
	return k if k > 0 else KIND_NONE


## ● game-concept §12 R37: the healing and buff herbs anyone plants; the poison herb's seeds only the herbalist.
static func may_plant(class_id: String, kind: int) -> bool:
	return kind != KIND_POISON or class_id == HERB_CLASS


## The grade a harvest gives (PROVISIONAL Config.CROP_GRADE_BY_HARVESTER): FINE for the herbalist's harvest, COMMON for
## anyone else's (● gameplay-design §3.0 "공용 수행 … 일반 등급 약초만"), or by the planter (the crop's FLAG_FAST).
static func harvest_grade(class_id: String, f: Field) -> int:
	var fine: bool = class_id == HERB_CLASS if Config.CROP_GRADE_BY_HARVESTER else f.fast
	return ItemDB.Grade.FINE if fine else ItemDB.Grade.COMMON


## The simulation tick of the hoe's / the watering can's action on which it lands (-1: not a farming tool). The sickle
## is a weapon: its harvest lands on its hit frame (Combat.impact_tick).
static func impact_tick(item: StringName) -> int:
	if item == HOE:
		return Config.HOE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS
	if item == WATERING_CAN:
		return Config.WATER_IMPACT_FRAME * Config.ACTION_FRAME_TICKS
	return -1


## The sickle swing on tile `c` harvests (a crop there, any stage) instead of attacking.
static func is_harvest_swing(data: WorldData, item: StringName, c: Vector2i) -> bool:
	if item != SICKLE:
		return false
	var f: Field = field_at(data, c)
	return f != null and f.kind != KIND_NONE


## Why the hoe may not till tile `c` for feet at `feet` ("" = it may): on the map and in reach (WorldItems.in_reach), the
## surface (a dungeon draws no floor), grass (soil is tilled already, ash is corrupted), nothing standing or growing there,
## in the light (Config.TILL_ONLY_IN_LIGHT), and never next to ash (no soil + ash art).
static func till_refusal(data: WorldData, feet: Vector2, c: Vector2i) -> String:
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if data.map_id != Config.MAP_SURFACE or Walls.blocks(data, c):
		return WHY_NO_GROUND
	var t: int = data.terrain_at(c)
	if t == Terrain.SOIL:
		return WHY_TILLED
	if t != Terrain.GRASS:
		return WHY_ASH
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
		return WorldItems.WHY_BLOCKED
	if data.get_value(WorldData.Layer.VEGETATION, c) != 0:
		return WHY_GROWING
	if Config.TILL_ONLY_IN_LIGHT and not in_light(data, c):
		return WHY_DARK
	if not data.can_set_terrain(c, Terrain.SOIL):
		return WHY_ASH_NEAR
	return ""


## Why a player of `class_id` may not plant crop `kind` on tile `c` ("" = it may): the class (● R37 first), then tilled
## soil with no crop and nothing standing on it, and (Config.PLANT_ONLY_WHERE_IT_GROWS) a tile where it would not wither.
static func plant_refusal(data: WorldData, feet: Vector2, class_id: String, kind: int, c: Vector2i) -> String:
	if kind == KIND_NONE:
		return WHY_NOT_SEED
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if not may_plant(class_id, kind):
		return WHY_HERBALIST
	if not is_tilled(data, c):
		return WHY_NOT_TILLED
	var v: int = data.get_value(WorldData.Layer.VEGETATION, c)
	var f: Field = Field.of(v)
	if v != 0 and f == null:
		return WHY_GROWING
	if f != null and f.kind != KIND_NONE:
		return WHY_PLANTED
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
		return WorldItems.WHY_BLOCKED
	if Config.PLANT_ONLY_WHERE_IT_GROWS:
		return withers_at(data, c)
	return ""


## Why the watering can may not water tile `c` ("" = it may): tilled soil in reach with nothing standing on it. Watering
## a wet tile is allowed (its water starts over).
static func water_refusal(data: WorldData, feet: Vector2, c: Vector2i) -> String:
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	if not is_tilled(data, c):
		return WHY_NOT_TILLED
	if data.get_value(WorldData.Layer.PLACEABLE, c) != WorldData.PLACEABLE_NONE:
		return WorldItems.WHY_BLOCKED
	if data.get_value(WorldData.Layer.VEGETATION, c) != 0 and field_at(data, c) == null:
		return WHY_GROWING
	return ""


## Why the sickle may not harvest tile `c` ("" = it may): a crop in reach, not withered, ripe.
static func harvest_refusal(data: WorldData, feet: Vector2, c: Vector2i) -> String:
	if not data.in_bounds(c):
		return WorldItems.WHY_OUTSIDE
	if not WorldItems.in_reach(feet, c):
		return WorldItems.WHY_REACH
	var f: Field = field_at(data, c)
	if f == null or f.kind == KIND_NONE:
		return WHY_NO_CROP
	if f.withered:
		return WHY_WITHERED
	if not f.ripe():
		return WHY_NOT_RIPE
	return ""


## Every field tile (a crop or a wet tile) of `data`, row by row.
static func field_cells(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var plants: PackedByteArray = data.layers[WorldData.Layer.VEGETATION]
	for i: int in plants.size():
		if plants[i] >= Config.FIELD_BASE and Field.of(plants[i]) != null:
			out.append(Vector2i(i % data.size.x, i / data.size.x))
	return out
