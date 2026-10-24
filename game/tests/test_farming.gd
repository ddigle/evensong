extends "res://tests/base_test.gd"
## M5a, farming (offline first): the field encoding (VEGETATION values), the light and corruption rules, tilling (the
## light, which tiles, placeables, gatherables, reach, the dungeon, the spots where players appear), the seeds and who
## may plant what (5 classes x 3 seeds, ● R37), watering and drying, growth timing (the herbalist's speed), the harvest
## (herbs, seeds, grades, a full inventory, the M6 recipe), the sickle rule, withering and reviving (outside the light,
## next to corruption), a long deterministic run, the world's edits / snapshot / hash, the view (wet patches, crop
## sprites, the recoloured mounds), main.tscn offline (hoe, can, seeds, sickle, a wild herb's seed, test fields) and a
## session (farming refused / inert until M5c).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0
const CLASSES: PackedStringArray = ["paladin", "miner", "archer", "cleric", "herbalist"]


func run() -> Array[String]:
	_check_encoding()
	_check_light_and_corruption()
	_check_till()
	_check_plant_who()
	_check_plant_rules()
	_check_water()
	_check_growth()
	_check_harvest()
	_check_sickle_rule()
	_check_wither()
	_check_determinism()
	_check_world_edits()
	await _check_view()
	await _check_main()
	await _check_session()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------

static func world() -> WorldData:
	return SurfaceGen.generate(Config.DEFAULT_SEED)


## A feet point one tile south of tile `c` (low in that tile: the target `c` is in reach, north of the feet tile).
static func feet_for(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c + Vector2i(0, 1))


static func apply(data: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(data, e)


## Written out here (not Farming.in_light): every corner of tile `c` within the safe radius of the altar centre.
static func corners_lit(data: WorldData, c: Vector2i) -> bool:
	if not data.altar_rect.has_area():
		return false
	var centre: Vector2 = data.altar_center_px()
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		if Vector2((c + o) * Config.TILE).distance_to(centre) > Config.safe_radius_px():
			return false
	return true


## Lit grass tiles with nothing on them and grass all around (tilling one touches nothing else), row by row.
static func lit_grass(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in data.size.y:
		for x: int in data.size.x:
			var c: Vector2i = Vector2i(x, y)
			if not corners_lit(data, c) or data.get_value(WorldData.Layer.PLACEABLE, c) != 0 \
					or data.get_value(WorldData.Layer.VEGETATION, c) != 0:
				continue
			var all_grass: bool = true
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					if data.terrain_at(c + Vector2i(ox, oy)) != Terrain.GRASS:
						all_grass = false
			if all_grass:
				out.append(c)
	return out


## A grass tile well outside the light with nothing on it that may become soil (no ash next to it).
static func dark_grass(data: WorldData) -> Vector2i:
	for y: int in range(4, data.size.y - 4):
		for x: int in range(4, data.size.x - 4):
			var c: Vector2i = Vector2i(x, y)
			if data.terrain_at(c) == Terrain.GRASS and data.get_value(WorldData.Layer.VEGETATION, c) == 0 					and data.get_value(WorldData.Layer.PLACEABLE, c) == 0 and data.can_set_terrain(c, Terrain.SOIL) 					and not Farming.near_corruption(data, c) 					and Vector2(c * Config.TILE).distance_to(data.altar_center_px()) > Config.safe_radius_px() + 64.0:
				return c
	return Vector2i(-1, -1)


## Tilled soil tiles with nothing on them (the M1 patches), row by row.
static func soil_cells(data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in data.size.y:
		for x: int in data.size.x:
			var c: Vector2i = Vector2i(x, y)
			if data.terrain_at(c) == Terrain.SOIL and data.get_value(WorldData.Layer.VEGETATION, c) == 0 \
					and data.get_value(WorldData.Layer.PLACEABLE, c) == 0:
				out.append(c)
	return out


static func inv_with(items: Array) -> Inventory:
	var inv: Inventory = Inventory.new()
	for e: Array in items:
		var id: StringName = e[0]
		var n: int = e[1]
		var g: int = e[2] if e.size() > 2 else -1
		inv.add(id, n, g)
	return inv


## Plants crop `kind` on tile `c` for `class_id` (a seed given for it) and returns the result.
static func plant(data: WorldData, farm: Farm, class_id: String, kind: int, c: Vector2i) -> Farm.Result:
	var inv: Inventory = inv_with([[Farming.SEEDS[kind], 1]])
	var r: Farm.Result = farm.plant(feet_for(c), class_id, inv, 0, c)
	apply(data, r.edits)
	return r


## Puts a crop straight into the data (past the rules) and tells the farm.
static func put_crop(data: WorldData, farm: Farm, c: Vector2i, f: Farming.Field) -> void:
	data.set_value(WorldData.Layer.FLOOR, c, Terrain.SOIL)
	data.set_value(WorldData.Layer.VEGETATION, c, f.value())
	farm.sync_cell(c)


## Steps the farm `n` ticks, applying its edits; returns how many edits it made.
static func steps(data: WorldData, farm: Farm, n: int) -> int:
	var made: int = 0
	for i: int in n:
		var e: Array[EditLog.WorldEdit] = farm.step()
		made += e.size()
		apply(data, e)
	return made


# --- the encoding -----------------------------------------------------------------------------------------

func _check_encoding() -> void:
	var seen: Dictionary[int, bool] = {}
	var round_trips: int = 0
	for kind: int in range(1, Farming.KIND_COUNT):
		for stage: int in Farming.STAGES:
			for flags: int in 8:
				var f: Farming.Field = Farming.Field.new(kind, stage, flags & 2 != 0, flags & 1 != 0, flags & 4 != 0)
				var v: int = f.value()
				check(v >= Config.FIELD_BASE and v <= 255 and not seen.has(v), "field value %d in a byte and new" % v)
				seen[v] = true
				var back: Farming.Field = Farming.Field.of(v)
				if back != null and back.kind == kind and back.stage == stage and back.wet == f.wet and back.fast == f.fast \
						and back.withered == f.withered:
					round_trips += 1
				check_eq(String(WorldItems.gatherable_for(v)), "", "a field value is no gatherable (%d)" % v)
	check_eq(round_trips, 3 * Farming.STAGES * 8, "every crop / stage / flags value decodes back")
	var bare: Farming.Field = Farming.Field.new(Farming.KIND_NONE, 0, true)
	check_eq(bare.value(), Config.FIELD_BASE + Farming.FLAG_WET, "wet bare soil")
	check(Farming.Field.of(bare.value()) != null and Farming.Field.of(bare.value()).wet, "wet bare soil decodes")
	check_eq(Farming.Field.new().value(), 0, "dry bare soil is VEGETATION 0")
	for v: int in [0, 1, 15, Config.FIELD_BASE, Config.FIELD_BASE + 1, Config.FIELD_BASE + 3, 224, 255]:
		check(Farming.Field.of(v) == null, "%d is no field" % v)
	for i: int in WorldItems.GATHERABLES.size():
		check(Farming.Field.of(i + 1) == null, "gatherable value %d is no field" % (i + 1))
	check_eq(Farming.seed_kind(&"seed_poison"), Farming.KIND_POISON, "the poison seed")
	check_eq(Farming.seed_kind(&"wild_poison"), Farming.KIND_NONE, "a herb is no seed")
	check_eq(Farming.herb_kind(&"wild_buff"), Farming.KIND_BUFF, "the buff herb's crop")
	check_eq(String(Farming.HERBS[Farming.KIND_HEALING]), "wild_healing", "the healing crop gives the wild herb item")


# --- light and corruption ----------------------------------------------------------------------------------

func _check_light_and_corruption() -> void:
	var data: WorldData = world()
	var lit: int = 0
	var differ: int = 0
	var r: Rect2i = data.altar_rect.grow(Config.SAFE_RADIUS_TILES + 2)
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			var c: Vector2i = Vector2i(x, y)
			if Farming.in_light(data, c) != corners_lit(data, c):
				differ += 1
			if corners_lit(data, c):
				lit += 1
	check_eq(differ, 0, "in_light = all four corners within the safe radius, %d tiles around the altar" % r.get_area())
	check(lit > 100, "lit tiles: %d" % lit)
	note("tiles wholly in the light (fields may be tilled there): %d (altar 9 of them)" % lit)
	for c: Vector2i in soil_cells(data):
		check(Farming.in_light(data, c), "M1 soil patch tile %s is in the light (the generator's rule)" % c)
	var dark: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check(not Farming.in_light(dark, Vector2i(30, 20)), "a map without an altar has no light")
	# Corruption within reach (Chebyshev 2, own tile included), not 3.
	var a: WorldData = WorldData.new(Vector2i(24, 24))
	a.set_value(WorldData.Layer.CORRUPTION, Vector2i(10, 10), 1)
	check(Farming.near_corruption(a, Vector2i(10, 10)), "on the corrupted tile")
	check(Farming.near_corruption(a, Vector2i(12, 10)), "2 east")
	check(Farming.near_corruption(a, Vector2i(8, 12)), "2 diagonal")
	check(not Farming.near_corruption(a, Vector2i(13, 10)), "3 east: no")
	check(not Farming.near_corruption(a, Vector2i(10, 13)), "3 south: no")
	check_eq(Config.CROP_CORRUPTION_REACH_TILES, 2, "the reach these checks were written for")
	# The nearest soil may lie to ash (no soil + ash art) is exactly that reach.
	var b: WorldData = WorldData.new(Vector2i(24, 24))
	b.set_terrain(Vector2i(10, 10), Terrain.ASH)
	check(not b.can_set_terrain(Vector2i(11, 10), Terrain.SOIL), "no soil next to ash")
	check(b.can_set_terrain(Vector2i(12, 10), Terrain.SOIL), "soil 2 from ash: allowed, and that is within reach")
	# withers_at: the light first.
	var lit_c: Vector2i = soil_cells(data)[0]
	check_eq(Farming.withers_at(data, lit_c), "", "a lit soil tile far from the ash: grows")
	data.set_value(WorldData.Layer.CORRUPTION, lit_c + Vector2i(2, 0), 1)
	check_eq(Farming.withers_at(data, lit_c), Farming.WHY_ASH_NEAR, "corruption 2 away: withers")


# --- tilling ------------------------------------------------------------------------------------------------

func _check_till() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var grass: Array[Vector2i] = lit_grass(data)
	if not check(grass.size() > 20, "lit grass tiles to till: %d" % grass.size()):
		return
	var g: Vector2i = grass[0]
	var r: Farm.Result = farm.till(feet_for(g), g)
	check(r.ok() and r.edits.size() == 1, "the hoe tills lit grass (%s)" % r.why)
	if r.ok():
		check(r.edits[0].layer == WorldData.Layer.FLOOR and r.edits[0].value == Terrain.SOIL and r.edits[0].cell == g,
			"one floor edit: soil")
		check_eq(EditLog.check(data, r.edits[0]), "", "the edit passes the world's floor rules")
	apply(data, r.edits)
	check_eq(data.terrain_at(g), Terrain.SOIL, "tilled")
	check(not Movement.is_blocked(data, g), "soil does not block walking")
	check_eq(farm.till(feet_for(g), g).why, Farming.WHY_TILLED, "soil again: already tilled")
	check_eq(farm.till(feet_for(soil_cells(data)[0]), soil_cells(data)[0]).why, Farming.WHY_TILLED,
		"an M1 soil patch tile is tilled already (plantable as it is)")
	# Things on the tile.
	var altar_cell: Vector2i = data.altar_rect.position + Vector2i(1, 2)
	check_eq(farm.till(feet_for(altar_cell), altar_cell).why, WorldItems.WHY_BLOCKED, "the altar: blocked")
	var t: Vector2i = grass[1]
	data.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_TORCH)
	check_eq(farm.till(feet_for(t), t).why, WorldItems.WHY_BLOCKED, "a torch: blocked")
	data.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_ALCHEMY)
	check_eq(farm.till(feet_for(t), t).why, WorldItems.WHY_BLOCKED, "the alchemy table: blocked")
	data.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_BAG)
	check_eq(farm.till(feet_for(t), t).why, WorldItems.WHY_BLOCKED, "a death bag: blocked")
	data.set_value(WorldData.Layer.PLACEABLE, t, 0)
	data.set_value(WorldData.Layer.VEGETATION, t, WorldItems.value_of(&"mushroom_a"))
	check_eq(farm.till(feet_for(t), t).why, Farming.WHY_GROWING, "a gatherable: something grows there")
	data.set_value(WorldData.Layer.VEGETATION, t, 0)
	# Reach and the map.
	check_eq(farm.till(feet_for(t) + Vector2(0, 16), t).why, WorldItems.WHY_REACH, "two tiles away: out of reach")
	check_eq(farm.till(feet_for(t), t + Vector2i(0, 1)).why, WorldItems.WHY_REACH, "the feet tile: out of reach")
	check_eq(farm.till(Vector2(4, 4), Vector2i(-1, 0)).why, WorldItems.WHY_OUTSIDE, "outside the map")
	# The light: lit / not lit exactly by the four corners.
	var dark_grass: Vector2i = Vector2i(-1, -1)
	var edge_lit: Vector2i = Vector2i(-1, -1)
	for y: int in range(data.altar_rect.position.y - 9, data.altar_rect.end.y + 9):
		for x: int in range(data.altar_rect.position.x - 9, data.altar_rect.end.x + 9):
			var c: Vector2i = Vector2i(x, y)
			if data.terrain_at(c) != Terrain.GRASS or data.get_value(WorldData.Layer.VEGETATION, c) != 0 \
					or data.get_value(WorldData.Layer.PLACEABLE, c) != 0:
				continue
			var centre_in: bool = (Vector2(c) + Vector2(0.5, 0.5)).distance_to(data.altar_center_px() / Config.TILE) \
				<= Config.SAFE_RADIUS_TILES
			if centre_in and not corners_lit(data, c) and dark_grass.x < 0:
				dark_grass = c  # its middle is lit, a corner is not: not "in the light"
			if corners_lit(data, c) and not corners_lit(data, c + Vector2i(1, 0)) and edge_lit.x < 0:
				edge_lit = c
	if check(dark_grass.x >= 0 and edge_lit.x >= 0, "a half-lit and an edge tile around the altar"):
		check_eq(farm.till(feet_for(dark_grass), dark_grass).why, Farming.WHY_DARK, "a corner outside the light: refused")
		check(farm.till(feet_for(edge_lit), edge_lit).ok(), "the last wholly lit tile of a row: tilled")
	var ash: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.FLOOR].size():
		if data.layers[WorldData.Layer.FLOOR][i] == Terrain.ASH:
			ash = Vector2i(i % data.size.x, i / data.size.x)
			break
	check_eq(farm.till(feet_for(ash), ash).why, Farming.WHY_ASH, "ash: corrupted ground")
	var far: Vector2i = Vector2i(10, 10)
	if data.terrain_at(far) == Terrain.GRASS and data.get_value(WorldData.Layer.VEGETATION, far) == 0:
		check_eq(farm.till(feet_for(far), far).why, Farming.WHY_DARK, "grass far from the altar: outside the light")
	# The dungeon has no ground to till.
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var arrive: Vector2 = DungeonGen.arrival_point(dun)
	var below: Vector2i = Aim.feet_cell(arrive) + Vector2i(0, 1)
	check_eq(Farm.new(dun).till(arrive, below).why, Farming.WHY_NO_GROUND, "the dungeon: no ground to till")
	# The spots where players appear (arrival, the altar's spawn slots): soil does not block, so they may be tilled.
	var tilled_spots: int = 0
	for spot: Vector2 in WorldItems.reserved_feet(data):
		var c: Vector2i = Aim.feet_cell(spot)
		if not corners_lit(data, c):
			continue
		var why: String = Farming.till_refusal(data, feet_for(c), c)
		check(why.is_empty() or why == Farming.WHY_TILLED, "a spawn spot %s: tilled or soil already (%s)" % [c, why])
		if why.is_empty():
			apply(data, farm.till(feet_for(c), c).edits)
			tilled_spots += 1
		check(not Movement.feet_box(spot).intersects(Rect2(Vector2(c * Config.TILE), Vector2(16, 16))) \
			or not Movement.is_blocked(data, c), "a player still stands on the spot's soil %s" % c)
	check(tilled_spots >= 1, "spawn spots tilled: %d" % tilled_spots)
	check_eq(farm.stat("tilled"), 2 + tilled_spots, "the farm counted the tilled tiles")


# --- seeds: who plants what ----------------------------------------------------------------------------------

func _check_plant_who() -> void:
	var data: WorldData = world()
	var soil: Array[Vector2i] = soil_cells(data)
	var c: Vector2i = soil[0]
	var allowed: int = 0
	for class_id: String in CLASSES:
		for kind: int in range(1, Farming.KIND_COUNT):
			var want_ok: bool = kind != Farming.KIND_POISON or class_id == "herbalist"  # ● R37, written out
			var why: String = Farming.plant_refusal(data, feet_for(c), class_id, kind, c)
			check_eq(why, "" if want_ok else Farming.WHY_HERBALIST, "%s plants %s" % [class_id, Farming.CROP_NAMES[kind]])
			var farm: Farm = Farm.new(data)
			var inv: Inventory = inv_with([[Farming.SEEDS[kind], 3]])
			var r: Farm.Result = farm.plant(feet_for(c), class_id, inv, 0, c)
			check_eq(r.why, "" if want_ok else Farming.WHY_HERBALIST, "%s / %s through the farm" % [class_id, Farming.CROP_NAMES[kind]])
			check_eq(inv.count_of(Farming.SEEDS[kind]), 2 if want_ok else 3, "a seed used only when planted")
			if want_ok:
				allowed += 1
				var f: Farming.Field = Farming.Field.of(r.edits[0].value)
				check(f != null and f.kind == kind and f.stage == 0 and not f.wet and f.fast == (class_id == "herbalist"),
					"%s's %s: stage 0, fast only for the herbalist" % [class_id, Farming.CROP_NAMES[kind]])
	check_eq(allowed, 11, "11 of 15: everyone the healing and buff herbs, the herbalist the poison herb too")


# --- planting rules -----------------------------------------------------------------------------------------

func _check_plant_rules() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var soil: Array[Vector2i] = soil_cells(data)
	var grass: Array[Vector2i] = lit_grass(data)
	var c: Vector2i = soil[0]
	var inv: Inventory = inv_with([[&"seed_buff", 5], [&"wild_buff", 2]])
	check_eq(farm.plant(feet_for(grass[0]), "paladin", inv, 0, grass[0]).why, Farming.WHY_NOT_TILLED, "grass: not tilled")
	check_eq(farm.plant(feet_for(c), "paladin", inv, 1, c).why, Farming.WHY_NOT_SEED, "a herb is not a seed")
	check_eq(farm.plant(feet_for(c), "paladin", inv, 2, c).why, WorldItems.WHY_EMPTY, "an empty slot")
	check_eq(farm.plant(feet_for(c), "paladin", inv, 30, c).why, WorldItems.WHY_BAD_SLOT, "no such slot")
	check_eq(farm.plant(feet_for(c) + Vector2(0, 32), "paladin", inv, 0, c).why, WorldItems.WHY_REACH, "out of reach")
	var r: Farm.Result = farm.plant(feet_for(c), "paladin", inv, 0, c)
	check(r.ok(), "planted (%s)" % r.why)
	apply(data, r.edits)
	check_eq(farm.plant(feet_for(c), "herbalist", inv, 0, c).why, Farming.WHY_PLANTED, "a crop there: already planted")
	check_eq(inv.count_of(&"seed_buff"), 4, "one seed for one crop")
	# A torch on soil blocks it; a wet bare tile takes the seed and stays wet.
	var t: Vector2i = soil[1]
	data.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_TORCH)
	check_eq(farm.plant(feet_for(t), "paladin", inv, 0, t).why, WorldItems.WHY_BLOCKED, "a torch on the soil")
	data.set_value(WorldData.Layer.PLACEABLE, t, 0)
	apply(data, farm.water(feet_for(t), t).edits)
	steps(data, farm, 100)
	var left: int = farm.plots[data.index_of(t)].water_left
	apply(data, farm.plant(feet_for(t), "paladin", inv, 0, t).edits)
	var f: Farming.Field = Farming.field_at(data, t)
	check(f != null and f.kind == Farming.KIND_BUFF and f.wet, "planted into wet soil: a wet crop")
	check_eq(farm.plots[data.index_of(t)].water_left, left, "its water runs on")
	# Where the crop would wither (Config.PLANT_ONLY_WHERE_IT_GROWS): outside the light, next to corruption.
	var dark: Vector2i = dark_grass(data)
	if check(dark.x >= 0, "a dark grass tile"):
		data.set_terrain(dark, Terrain.SOIL)
		check_eq(farm.plant(feet_for(dark), "paladin", inv, 0, dark).why,
			Farming.WHY_DARK if Config.PLANT_ONLY_WHERE_IT_GROWS else "", "soil outside the light")
	var near: Vector2i = soil[2]
	data.set_value(WorldData.Layer.CORRUPTION, near + Vector2i(0, -2), 3)
	check_eq(farm.plant(feet_for(near), "paladin", inv, 0, near).why,
		Farming.WHY_ASH_NEAR if Config.PLANT_ONLY_WHERE_IT_GROWS else "", "corruption 2 north")
	check_eq(farm.stat("planted"), 2, "two planted")


# --- watering ------------------------------------------------------------------------------------------------

func _check_water() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var soil: Array[Vector2i] = soil_cells(data)
	var c: Vector2i = soil[0]
	var r: Farm.Result = farm.water(feet_for(c), c)
	check(r.ok() and r.edits.size() == 1, "water bare soil (%s)" % r.why)
	apply(data, r.edits)
	check_eq(data.get_value(WorldData.Layer.VEGETATION, c), Config.FIELD_BASE + Farming.FLAG_WET, "wet bare soil")
	var dried_at: int = -1
	for t: int in range(1, Config.WATER_TICKS + 10):
		var e: Array[EditLog.WorldEdit] = farm.step()
		apply(data, e)
		if not e.is_empty() and dried_at < 0:
			dried_at = t
	check_eq(dried_at, Config.WATER_TICKS, "dry exactly WATER_TICKS after watering")
	check_eq(data.get_value(WorldData.Layer.VEGETATION, c), 0, "dry bare soil again")
	check(not farm.plots.has(data.index_of(c)), "and nothing to time there")
	# Watering again half way starts the count over (no edit: it was wet).
	apply(data, farm.water(feet_for(c), c).edits)
	steps(data, farm, Config.WATER_TICKS / 2)
	var again: Farm.Result = farm.water(feet_for(c), c)
	check(again.ok() and again.edits.is_empty(), "a wet tile watered again: no edit")
	var made: int = steps(data, farm, Config.WATER_TICKS - 1)
	check(made == 0 and Farming.field_at(data, c).wet, "still wet WATER_TICKS - 1 after the second watering")
	check_eq(steps(data, farm, 1), 1, "dry on the next tick")
	# Not on grass, not out of reach, a crop takes water too.
	var grass: Vector2i = lit_grass(data)[0]
	check_eq(farm.water(feet_for(grass), grass).why, Farming.WHY_NOT_TILLED, "grass: not tilled")
	check_eq(farm.water(feet_for(c) + Vector2(0, 32), c).why, WorldItems.WHY_REACH, "out of reach")
	plant(data, farm, "paladin", Farming.KIND_HEALING, soil[1])
	apply(data, farm.water(feet_for(soil[1]), soil[1]).edits)
	var crop: Farming.Field = Farming.field_at(data, soil[1])
	check(crop != null and crop.wet and crop.kind == Farming.KIND_HEALING, "a watered crop")


# --- growth ---------------------------------------------------------------------------------------------------

func _check_growth() -> void:
	var last: Dictionary[bool, int] = {}
	for fast: bool in [false, true]:
		var data: WorldData = world()
		var farm: Farm = Farm.new(data)
		var c: Vector2i = soil_cells(data)[0]
		plant(data, farm, "herbalist" if fast else "paladin", Farming.KIND_HEALING, c)
		var per_stage: int = Config.CROP_STAGE_TICKS * 100 / Config.CROP_HERBALIST_GROWTH_PCT if fast else Config.CROP_STAGE_TICKS
		var stage_at: Array[int] = []
		for t: int in range(1, 5 * Config.CROP_STAGE_TICKS):
			apply(data, farm.water(feet_for(c), c).edits)  # kept wet every tick
			var before: int = Farming.field_at(data, c).stage
			apply(data, farm.step())
			if Farming.field_at(data, c).stage != before:
				stage_at.append(t)
		check_eq(stage_at, [per_stage, 2 * per_stage, 3 * per_stage, 4 * per_stage] as Array[int],
			"%s crop: a stage every %d wet ticks, ripe at stage 4" % ["the herbalist's" if fast else "a common", per_stage])
		check(Farming.field_at(data, c).ripe(), "ripe and stays ripe (no rotting)")
		var lb: int = -1
		if not stage_at.is_empty():
			lb = stage_at[stage_at.size() - 1]
		last[fast] = lb
	check_eq(last[true] * Config.CROP_HERBALIST_GROWTH_PCT, last[false] * 100, "the herbalist's crop: CROP_HERBALIST_GROWTH_PCT faster")
	# No water: no growth.
	var dry: WorldData = world()
	var dry_farm: Farm = Farm.new(dry)
	var d: Vector2i = soil_cells(dry)[0]
	plant(dry, dry_farm, "paladin", Farming.KIND_BUFF, d)
	check_eq(steps(dry, dry_farm, 3 * Config.CROP_STAGE_TICKS), 0, "a dry crop: no edit in 3 stages' time")
	check_eq(Farming.field_at(dry, d).stage, 0, "still a seed")
	# Water once: it grows while wet, stops when dry, goes on from there when watered again.
	apply(dry, dry_farm.water(feet_for(d), d).edits)
	var w: int = Config.WATER_TICKS
	var s: int = Config.CROP_STAGE_TICKS
	steps(dry, dry_farm, w)
	check(not Farming.field_at(dry, d).wet, "dried")
	check_eq(Farming.field_at(dry, d).stage, w / s, "grew %d wet ticks' worth" % w)
	check_eq(steps(dry, dry_farm, 5000), 0, "dry: nothing for 5000 ticks")
	apply(dry, dry_farm.water(feet_for(d), d).edits)
	var next_stage: int = w / s + 1
	var need: int = next_stage * s - w
	var grew_at: int = -1
	for t: int in range(1, need + 10):
		var before2: int = Farming.field_at(dry, d).stage
		apply(dry, dry_farm.step())
		if Farming.field_at(dry, d).stage != before2 and grew_at < 0:
			grew_at = t
	check_eq(grew_at, need, "watered again: the next stage after the wet ticks it still lacked (%d)" % need)


# --- harvest ----------------------------------------------------------------------------------------------------

func _check_harvest() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var soil: Array[Vector2i] = soil_cells(data)
	var c: Vector2i = soil[0]
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_POISON, Farming.RIPE_STAGE, false, true))
	var inv: Inventory = Inventory.new()
	var r: Farm.Result = farm.harvest(feet_for(c), "herbalist", inv, c)
	check(r.ok(), "the herbalist harvests a ripe poison herb (%s)" % r.why)
	apply(data, r.edits)
	check_eq(inv.count_of(&"wild_poison", ItemDB.Grade.FINE), Config.CROP_HARVEST_HERBS, "herbs at FINE")
	check_eq(inv.count_of(&"seed_poison"), Config.CROP_HARVEST_SEEDS, "seeds back")
	check_eq(data.get_value(WorldData.Layer.VEGETATION, c), 0, "the tile is bare soil")
	check_eq(data.terrain_at(c), Terrain.SOIL, "and stays soil")
	check_eq(r.count, Config.CROP_HARVEST_HERBS, "result: herbs")
	check_eq(r.grade, ItemDB.Grade.FINE, "result: grade")
	# Anyone else: COMMON, whoever planted it (Config.CROP_GRADE_BY_HARVESTER).
	for class_id: String in ["paladin", "miner", "archer", "cleric"]:
		put_crop(data, farm, c, Farming.Field.new(Farming.KIND_HEALING, Farming.RIPE_STAGE, true, true))
		var inv2: Inventory = Inventory.new()
		var r2: Farm.Result = farm.harvest(feet_for(c), class_id, inv2, c)
		apply(data, r2.edits)
		var want: int = ItemDB.Grade.COMMON if Config.CROP_GRADE_BY_HARVESTER else ItemDB.Grade.FINE
		check_eq(inv2.count_of(&"wild_healing", want), Config.CROP_HARVEST_HERBS, "%s harvests the herbalist's crop" % class_id)
		check_eq(Farming.field_at(data, c).wet, true, "a wet crop leaves wet soil")
		check(farm.plots.has(data.index_of(c)), "whose water runs on")
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_BUFF, Farming.RIPE_STAGE))
	var inv3: Inventory = Inventory.new()
	apply(data, farm.harvest(feet_for(c), "herbalist", inv3, c).edits)
	check_eq(inv3.count_of(&"wild_buff", ItemDB.Grade.FINE), Config.CROP_HARVEST_HERBS, "a paladin's crop harvested by the herbalist: FINE")
	# Refusals.
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_BUFF, Farming.RIPE_STAGE - 1))
	var inv4: Inventory = Inventory.new()
	check_eq(farm.harvest(feet_for(c), "herbalist", inv4, c).why, Farming.WHY_NOT_RIPE, "stage 3: not ripe")
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_BUFF, Farming.RIPE_STAGE, false, false, true))
	check_eq(farm.harvest(feet_for(c), "herbalist", inv4, c).why, Farming.WHY_WITHERED, "withered")
	check_eq(farm.harvest(feet_for(soil[1]), "herbalist", inv4, soil[1]).why, Farming.WHY_NO_CROP, "bare soil: no crop")
	check(inv4.free_slots() == inv4.size(), "nothing given on a refusal")
	# A full inventory: what does not fit lies on the tile; with MAX_DROPS on the ground it is lost.
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_HEALING, Farming.RIPE_STAGE))
	var full: Inventory = Inventory.new()
	for i: int in full.size():
		full.add(&"stone_a", Config.STACK_GATHERABLE)
	var drops_before: int = data.drops.size()
	var r5: Farm.Result = farm.harvest(feet_for(c), "paladin", full, c)
	apply(data, r5.edits)
	check(r5.ok() and r5.count == 0 and r5.seeds == 0, "a full inventory takes nothing")
	check_eq(data.drops.size(), drops_before + 2, "herbs and seeds lie on the tile: two drops")
	var on_tile: int = 0
	for d: WorldData.Drop in data.drops_at(c):
		on_tile += d.count
	check_eq(on_tile, Config.CROP_HARVEST_HERBS + Config.CROP_HARVEST_SEEDS, "all of the harvest is there")
	while data.drops.size() < Config.MAX_DROPS:
		var id: int = data.new_drop_id()
		data.drops[id] = WorldData.Drop.new(id, &"stone_a", 1, ItemDB.Grade.NONE, Vector2i(8, 8))
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_HEALING, Farming.RIPE_STAGE))
	var r6: Farm.Result = farm.harvest(feet_for(c), "paladin", full, c)
	check(r6.ok() and r6.lost == Config.CROP_HARVEST_HERBS + Config.CROP_HARVEST_SEEDS and r6.dropped == 0,
		"MAX_DROPS on the ground: the harvest is lost (%d)" % r6.lost)
	# The harvest brews (M6): two COMMON healing herbs make a COMMON healing potion.
	var brew: Inventory = Inventory.new()
	put_crop(data, farm, soil[2], Farming.Field.new(Farming.KIND_HEALING, Farming.RIPE_STAGE))
	apply(data, farm.harvest(feet_for(soil[2]), "paladin", brew, soil[2]).edits)
	var made: bool = false
	for recipe: Crafting.Recipe in Crafting.recipes():
		if recipe.id == &"potion_healing_common":
			made = Crafting.craft(recipe, "paladin", brew).ok()
	check(made and brew.count_of(&"potion_healing", ItemDB.Grade.COMMON) == 1, "the harvest brews a healing potion")


# --- the sickle --------------------------------------------------------------------------------------------------

func _check_sickle_rule() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var c: Vector2i = soil_cells(data)[0]
	check(not Farming.is_harvest_swing(data, &"sickle", c), "bare soil: the sickle attacks")
	apply(data, farm.water(feet_for(c), c).edits)
	check(not Farming.is_harvest_swing(data, &"sickle", c), "wet bare soil: attacks")
	for stage: int in Farming.STAGES:
		put_crop(data, farm, c, Farming.Field.new(Farming.KIND_BUFF, stage))
		check(Farming.is_harvest_swing(data, &"sickle", c), "a crop at stage %d: a harvest swing" % stage)
	put_crop(data, farm, c, Farming.Field.new(Farming.KIND_BUFF, 2, false, false, true))
	check(Farming.is_harvest_swing(data, &"sickle", c), "a withered crop: a harvest swing (refused, no attack)")
	check(not Farming.is_harvest_swing(data, &"sword", c), "the sword attacks")
	check(not Farming.is_harvest_swing(data, &"sickle", lit_grass(data)[0]), "grass: attacks")
	check_eq(Player.impact_tick_of(&"hoe", RigData.Anim.HOE), Config.HOE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS, "hoe lands")
	check_eq(Player.impact_tick_of(&"watering_can", RigData.Anim.WATERING), Config.WATER_IMPACT_FRAME * Config.ACTION_FRAME_TICKS,
		"the can waters")
	check_eq(Player.impact_tick_of(&"sickle", RigData.Anim.SICKLE), Combat.impact_tick(&"sickle"), "the sickle on its hit frame")
	check(Config.WATER_IMPACT_FRAME < RigData.frame_count(RigData.Anim.WATERING) and Config.HOE_IMPACT_FRAME < RigData.frame_count(RigData.Anim.HOE),
		"the impact frames are frames of their actions")


# --- withering ----------------------------------------------------------------------------------------------------

func _check_wither() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var c: Vector2i = soil_cells(data)[0]
	plant(data, farm, "paladin", Farming.KIND_HEALING, c)
	apply(data, farm.water(feet_for(c), c).edits)
	steps(data, farm, 100)
	var progress: int = farm.plots[data.index_of(c)].progress
	check_eq(progress, 100, "growing")
	# Corruption 3 away: nothing; 2 away: withers on the next tick, stops growing; gone: revives, grows on.
	data.set_value(WorldData.Layer.CORRUPTION, c + Vector2i(3, 0), 1)
	steps(data, farm, 1)
	check(not Farming.field_at(data, c).withered, "corruption 3 away: no withering")
	data.set_value(WorldData.Layer.CORRUPTION, c + Vector2i(3, 0), 0)
	data.set_value(WorldData.Layer.CORRUPTION, c + Vector2i(2, -2), 1)
	var e: Array[EditLog.WorldEdit] = farm.step()
	apply(data, e)
	check(e.size() == 1 and Farming.field_at(data, c).withered, "corruption 2 away: withered on the next tick")
	steps(data, farm, 500)
	check_eq(farm.plots[data.index_of(c)].progress, 101, "withered: no growth (the tick it withered counts none)")
	check(Farming.field_at(data, c).wet, "the water runs on meanwhile")
	data.set_value(WorldData.Layer.CORRUPTION, c + Vector2i(2, -2), 0)  # what M5b's purification will do
	steps(data, farm, 1)
	check(not Farming.field_at(data, c).withered, "the corruption gone: revived on the next tick")
	check_eq(farm.plots[data.index_of(c)].progress, 102, "and grows on from where it was")
	check_eq(farm.stat("withered"), 1, "withered once")
	check_eq(farm.stat("revived"), 1, "revived once")
	# Outside the light: the altar moves away (as it may, game-concept §9.3; M5b), the field stays and withers.
	var home: Rect2i = data.altar_rect
	data.altar_rect = Rect2i(home.position + Vector2i(30, 0), home.size)
	steps(data, farm, 1)
	var f: Farming.Field = Farming.field_at(data, c)
	check(f != null and f.withered and f.stage == 0, "the light gone: withered, the crop stays")
	check_eq(data.terrain_at(c), Terrain.SOIL, "the field stays soil")
	check_eq(Farming.withers_at(data, c), Farming.WHY_DARK, "outside the light")
	data.altar_rect = home
	steps(data, farm, 1)
	check(not Farming.field_at(data, c).withered, "the light back: revived")
	# A crop put down outside the light next to the ash (the screenshot's): withered at once, every stage.
	var near_ash: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.FLOOR].size():
		var a: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.terrain_at(a) == Terrain.ASH and data.can_set_terrain(a + Vector2i(0, 2), Terrain.SOIL) \
				and data.get_value(WorldData.Layer.VEGETATION, a + Vector2i(0, 2)) == 0:
			near_ash = a + Vector2i(0, 2)
			break
	if check(near_ash.x >= 0, "a tile 2 south of the ash"):
		put_crop(data, farm, near_ash, Farming.Field.new(Farming.KIND_POISON, 3, true))
		steps(data, farm, 1)
		check(Farming.field_at(data, near_ash).withered, "by the ash, outside the light: withered on the first tick")


# --- determinism -----------------------------------------------------------------------------------------------

## The same farming script on a world: tills, plants (all classes), waters, harvests the ripe ones and plants again,
## corruption near a crop and gone again, the altar away and back. Returns the world and farm hashes every 500 ticks.
static func scripted_run(ticks: int) -> PackedStringArray:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var grass: Array[Vector2i] = lit_grass(data)
	var soil: Array[Vector2i] = soil_cells(data)
	var cells: Array[Vector2i] = []
	cells.append_array(soil.slice(0, 6))
	cells.append_array(grass.slice(0, 6))
	var inv: Inventory = inv_with([[&"seed_healing", 50], [&"seed_buff", 50], [&"seed_poison", 50]])
	var out: PackedStringArray = []
	var home: Rect2i = data.altar_rect
	for t: int in range(1, ticks + 1):
		for i: int in cells.size():
			var c: Vector2i = cells[i]
			var class_id: String = CLASSES[(i + t / 3000) % CLASSES.size()]
			if t == 1 + i:
				apply(data, farm.till(feet_for(c), c).edits)
			var f: Farming.Field = Farming.field_at(data, c)
			if (f == null or f.kind == Farming.KIND_NONE) and t % 97 == i:
				for slot: int in 3:
					var r: Farm.Result = farm.plant(feet_for(c), class_id, inv, (i + slot) % 3, c)
					if r.ok():
						apply(data, r.edits)
						break
			if t % (700 + 37 * i) == 0 and (i % 2 == 0 or t < 12000):  # the odd ones dry out after 12,000
				apply(data, farm.water(feet_for(c), c).edits)
			if f != null and f.ripe() and t % 50 == i:
				var gain: Inventory = Inventory.new()
				apply(data, farm.harvest(feet_for(c), class_id, gain, c).edits)
		if t == 8000:
			data.set_value(WorldData.Layer.CORRUPTION, cells[0] + Vector2i(1, 1), 2)
		if t == 11000:
			data.set_value(WorldData.Layer.CORRUPTION, cells[0] + Vector2i(1, 1), 0)
		if t == 14000:
			data.altar_rect = Rect2i(home.position + Vector2i(0, 20), home.size)
		if t == 16000:
			data.altar_rect = home
		apply(data, farm.step())
		if t % 500 == 0:
			out.append("%d %s %s %s" % [t, data.content_hash(), farm.state_hash(), farm.stats])
	return out


func _check_determinism() -> void:
	var t0: int = Time.get_ticks_msec()
	var a: PackedStringArray = scripted_run(20000)
	var ms: int = Time.get_ticks_msec() - t0
	var b: PackedStringArray = scripted_run(20000)
	check_eq(a.size(), 40, "40 samples")
	var same: int = 0
	for i: int in mini(a.size(), b.size()):
		if a[i] == b[i]:
			same += 1
	check_eq(same, a.size(), "two runs of the same 20,000-tick script: the same world and timers every 500 ticks")
	var last: String = a[a.size() - 1] if not a.is_empty() else ""
	for key: String in ["tilled", "planted", "watered", "harvested", "grown", "withered", "revived", "dried"]:
		check(last.contains(key), "the script did %s" % key)
	note("farm: 20,000 ticks of 12 fields with the script in %d ms (%.1f us a tick); last sample %s" % [ms,
		ms * 1000.0 / 20000.0, last.substr(last.find("{"))])
	# The cost of a step: 120 wet crops (the light holds 129 tiles), most growing, the ones outside the light withered.
	var big: WorldData = world()
	var big_farm: Farm = Farm.new(big)
	var n: int = 0
	for y: int in range(big.altar_rect.position.y - 7, big.altar_rect.end.y + 7):
		for x: int in range(big.altar_rect.position.x - 7, big.altar_rect.end.x + 7):
			var c2: Vector2i = Vector2i(x, y)
			if n < 120 and big.get_value(WorldData.Layer.PLACEABLE, c2) == 0 and big.can_set_terrain(c2, Terrain.SOIL):
				put_crop(big, big_farm, c2, Farming.Field.new(1 + n % 3, n % 4, true))
				n += 1
	steps(big, big_farm, 30)
	var t1: int = Time.get_ticks_usec()
	steps(big, big_farm, 600)
	var per_tick: float = (Time.get_ticks_usec() - t1) / 600.0
	check(per_tick < 2000.0, "a step of %d crops under 2 ms (%.0f us)" % [n, per_tick])
	note("farm step: %d wet crops, %.0f us a tick (600 ticks; %d of them withered: outside the light)" % [n, per_tick,
		big_farm.stat("withered")])
	# A world loaded from its own snapshot takes the fields (the timers start over: Farm.setup).
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var c: Vector2i = soil_cells(data)[0]
	plant(data, farm, "herbalist", Farming.KIND_BUFF, c)
	apply(data, farm.water(feet_for(c), c).edits)
	var copy: WorldData = WorldSnapshot.decode_raw(WorldSnapshot.raw_bytes(data))
	if check(copy != null, "snapshot round trip"):
		check_eq(copy.content_hash(), data.content_hash(), "the snapshot carries the fields")
		var farm2: Farm = Farm.new(copy)
		check_eq(farm2.plots.size(), 1, "a farm set up from it has the crop")
		check_eq(farm2.plots[copy.index_of(c)].water_left, Config.WATER_TICKS, "wet: full water (timers are not world)")


# --- edits, the world's rules ---------------------------------------------------------------------------------

func _check_world_edits() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var g: Vector2i = lit_grass(data)[0]
	var all: Array[EditLog.WorldEdit] = []
	all.append_array(farm.till(feet_for(g), g).edits)
	apply(data, all)
	var r: Farm.Result = plant(data, farm, "herbalist", Farming.KIND_POISON, g)
	all.append_array(r.edits)
	for e: EditLog.WorldEdit in all:
		var back: Array = EditLog.decode_one(EditLog.encode_one(e, 7))
		var be: EditLog.WorldEdit = back[1]
		check(be != null and be.layer == e.layer and be.cell == e.cell and be.value == e.value, "edit %s on the wire" % e.describe())
	check_eq(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.FLOOR, g, Terrain.GRASS)), "a field lies there",
		"the debug floor edit cannot turn a crop's soil to grass")
	var before: String = data.content_hash()
	farm.step()
	check_eq(data.content_hash(), before, "a step changes the world only through the edits it returns")


# --- the view -------------------------------------------------------------------------------------------------

func _check_view() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var data: WorldData = w.data
	var farm: Farm = Farm.new(data)
	check(w.fields != null and w.fields.get_index() == w.ground.get_index() + 1, "the fields draw right above the ground")
	var grass: Array[Vector2i] = lit_grass(data)
	var soil: Array[Vector2i] = soil_cells(data)
	# Till three tiles in a row (soil next to soil), water, plant, grow through the world's edits.
	var row: Array[Vector2i] = [grass[0], grass[0] + Vector2i(1, 0)]
	for c: Vector2i in row:
		for e: EditLog.WorldEdit in farm.till(feet_for(c), c).edits:
			w.apply_edit(e)
	for i: int in 3:
		var c: Vector2i = soil[i]
		var inv: Inventory = inv_with([[Farming.SEEDS[i + 1], 1]])
		for e: EditLog.WorldEdit in farm.plant(feet_for(c), "herbalist", inv, 0, c).edits:
			w.apply_edit(e)
	for c: Vector2i in [row[0], soil[0], soil[3]]:
		for e: EditLog.WorldEdit in farm.water(feet_for(c), c).edits:
			w.apply_edit(e)
	var v: Dictionary[String, int] = w.fields.verify()
	check_eq(v, {"wet": 3, "crops": 3, "missing_quads": 0, "mismatches": 0} as Dictionary[String, int], "the fields drawn = data")
	check_eq(w.ground.verify()["mismatches"], 0, "the tilled ground drawn = data")
	# Each wet quarter is the watered copy of the tile its display cell shows, at that quarter (written out here).
	var bad_quads: int = 0
	for c: Vector2i in [row[0], soil[0], soil[3]]:
		var patch: FieldView.WetPatch = w.fields.wet[c]
		for k: int in 4:
			var q: Vector2i = Vector2i(k % 2, k / 2)
			var drawn: Vector3i = w.ground.drawn_at(c + q - Vector2i.ONE)
			var want_src: Rect2 = Rect2(drawn.y * 16 + (1 - q.x) * 8, drawn.z * 16 + (1 - q.y) * 8, 8, 8)
			var path: String = FieldView.WET_PATHS.get(drawn.x, "")
			if k >= patch.sources.size() or patch.sources[k] != want_src or patch.targets[k] != Vector2(q * 8) \
					or patch.textures[k].resource_path != path:
				bad_quads += 1
	check_eq(bad_quads, 0, "every wet quarter: the watered tile's quarter at its corner")
	# Tilling next to a wet tile redraws its quarters (its display cells show other tiles now).
	var next: Vector2i = row[0] + Vector2i(0, 1)
	if data.terrain_at(next) == Terrain.GRASS and Farming.till_refusal(data, feet_for(next), next).is_empty():
		var before: Rect2 = w.fields.wet[row[0]].sources[2]
		for e: EditLog.WorldEdit in farm.till(feet_for(next), next).edits:
			w.apply_edit(e)
		check(w.fields.wet[row[0]].sources[2] != before, "the tile south tilled: the wet tile's SW quarter follows")
		check_eq(w.fields.verify()["mismatches"], 0, "still = data")
	# Crops: sheet cell by stage, withered column, the wet / dry sheet, y-sorted on the tile's bottom edge.
	var s0: Sprite2D = w.fields.crops[soil[0]]
	check(s0.get_parent() == w.entities and s0.texture == FieldView.crop_sheet(true), "a wet crop: the wet sheet, among the entities")
	check_eq(s0.region_rect, Rect2(0, 0, 16, 16), "the healing herb at stage 0")
	check_eq(s0.position, Vector2(soil[0].x * 16 + 8, (soil[0].y + 1) * 16), "on the tile's bottom edge")
	check_eq(w.fields.crops[soil[2]].region_rect, Rect2(0, 32, 16, 16), "the poison herb's row")
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, soil[1],
		Farming.Field.new(Farming.KIND_BUFF, 3, false, true, true).value()))
	check_eq(w.fields.crops[soil[1]].region_rect, Rect2(96, 16, 16, 16), "withered: the withered column")
	check(w.fields.crops[soil[1]].texture == FieldView.crop_sheet(false), "dry: the dry sheet")
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, soil[1], 0))
	check(not w.fields.crops.has(soil[1]), "harvested: gone")
	check_eq(w.fields.verify()["mismatches"], 0, "still = data")
	check(w.items.verify()["mismatches"] == 0, "the gatherables' view ignores the fields")
	# The recoloured sheets: only the mound's browns change, to colours of the soil tiles; the harvest column not.
	var src: Image = LightGen.to_rgba8((load(FieldView.CROPS_PATH) as Texture2D).get_image())
	check_eq(src.get_size(), Vector2i(112, 48), "crops_v03: 7 columns x 3 rows of 16")
	for is_wet: bool in [false, true]:
		var sheet: Image = LightGen.to_rgba8(FieldView.crop_sheet(is_wet).get_image())
		var soil_img: Image = LightGen.to_rgba8((load("res://art/tiles/tiles_grass-soil_v03%s.png" % ("_watered" if is_wet else ""))
			as Texture2D).get_image())
		var soil_colours: Dictionary[int, bool] = {}
		for y: int in soil_img.get_height():
			for x: int in soil_img.get_width():
				soil_colours[soil_img.get_pixel(x, y).to_rgba32()] = true
		var changed: int = 0
		var off_palette: int = 0
		var harvest_changed: int = 0
		for y: int in 48:
			for x: int in 112:
				var a: Color = src.get_pixel(x, y)
				var b2: Color = sheet.get_pixel(x, y)
				if a == b2:
					continue
				changed += 1
				if x / 16 == FieldView.COLUMN_HARVEST:
					harvest_changed += 1
				if a.a8 != b2.a8 or not soil_colours.has(b2.to_rgba32()):
					off_palette += 1
		check(changed > 150, "%s sheet: %d mound pixels recoloured" % ["wet" if is_wet else "dry", changed])
		check_eq(off_palette, 0, "every recoloured pixel is a colour of the %s soil tile" % ("watered" if is_wet else "dry"))
		check_eq(harvest_changed, 0, "the harvest column untouched")


# --- main.tscn offline ----------------------------------------------------------------------------------------

## Steps the local player `n` ticks with `frame_fn`'s input (the first tick presses use if `press`).
func _tick(main: Main, p: Player, mouse: Vector2, n: int, press: bool) -> void:
	for i: int in n:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, mouse, true, press and i == 0, false, TICK)
		main.step_farms()


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn("herbalist")
	var p: Player = main.player
	if not check(p != null and p.farming_on and main.farming_on and main.farms.size() == 2, "offline: farming on, a farm per map"):
		return
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	var data: WorldData = main.world.data
	var g: Vector2i = lit_grass(data)[0]
	var feet: Vector2 = feet_for(g)
	p.teleport(feet)
	var aim: Vector2 = Vector2(g * 16) + Vector2(8, 8)
	for id: StringName in [&"hoe", &"watering_can", &"seed_poison", &"seed_buff"]:
		p.inventory.add(id, 3)
	var slot_of: Dictionary[StringName, int] = {}
	for i: int in p.inventory.hotbar_size:
		var st: ItemStack = p.inventory.stack_at(i)
		if st != null:
			slot_of[st.id] = i
	# The hoe: the action plays, the tile is tilled on its landing frame.
	p.inventory.select(slot_of[&"hoe"])
	_tick(main, p, aim, Config.HOE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS, true)
	check_eq(data.terrain_at(g), Terrain.GRASS, "not yet before the landing frame")
	_tick(main, p, aim, 1, false)
	check_eq(data.terrain_at(g), Terrain.SOIL, "the hoe tilled the aimed tile on its frame")
	check_eq(main.world.ground.verify()["mismatches"], 0, "drawn")
	_tick(main, p, aim, 40, false)
	# The seeds: a click plants (the poison herb: the herbalist's).
	p.inventory.select(slot_of[&"seed_poison"])
	_tick(main, p, aim, 1, true)
	var f: Farming.Field = Farming.field_at(data, g)
	check(f != null and f.kind == Farming.KIND_POISON and f.fast, "a click with poison seeds: the herbalist planted it")
	check_eq(p.inventory.count_of(&"seed_poison"), 2, "one seed used")
	check(main.world.fields.crops.has(g), "and it is drawn")
	# The can.
	p.inventory.select(slot_of[&"watering_can"])
	_tick(main, p, aim, Config.WATER_IMPACT_FRAME * Config.ACTION_FRAME_TICKS + 1, true)
	check(Farming.field_at(data, g).wet, "the can watered it on its frame")
	check(main.world.fields.wet.has(g), "the wet patch is drawn")
	_tick(main, p, aim, 60, false)
	check_eq(main.farms[Config.MAP_SURFACE].plots[data.index_of(g)].progress, 1 + 60,
		"Main steps the farm every tick while it is wet (the watering tick and 60 more)")
	# The sickle on an unripe crop: refused, no attack (a heretic stands on the crop's tile).
	var sickle_slot: int = Config.START_WEAPON_SLOT
	check_eq(String(p.inventory.stack_at(sickle_slot).id), "sickle", "the herbalist's start weapon is the sickle")
	p.inventory.select(sickle_slot)
	var h: HereticSim = main.arenas[Config.MAP_SURFACE].spawn_heretic(Arena.spawn_feet(g))
	var hp: int = h.hp
	_tick(main, p, aim, Combat.impact_tick(&"sickle") + 1, true)
	check_eq(h.hp, hp, "the sickle aimed at a crop does not attack")
	check(Farming.field_at(data, g).kind == Farming.KIND_POISON, "and an unripe crop stays")
	_tick(main, p, aim, 40, false)
	# Ripe: harvested on the hit frame, FINE (the herbalist).
	data.set_value(WorldData.Layer.VEGETATION, g, Farming.Field.new(Farming.KIND_POISON, Farming.RIPE_STAGE, true, true).value())
	main.world.fields.update_cell(g)
	_tick(main, p, aim, Combat.impact_tick(&"sickle") + 1, true)
	check_eq(p.inventory.count_of(&"wild_poison", ItemDB.Grade.FINE), Config.CROP_HARVEST_HERBS, "harvested: FINE poison herbs")
	check_eq(p.inventory.count_of(&"seed_poison"), 2 + Config.CROP_HARVEST_SEEDS, "and a seed back")
	check_eq(h.hp, hp, "still no attack")
	check(not main.world.fields.crops.has(g), "the crop is gone from the view")
	_tick(main, p, aim, 40, false)
	# The same sickle on grass hits the heretic standing there.
	var g2: Vector2i = g + Vector2i(1, 0)
	h.pos = Arena.spawn_feet(g2)
	p.teleport(feet_for(g2))
	if data.terrain_at(g2) == Terrain.GRASS and data.get_value(WorldData.Layer.VEGETATION, g2) == 0:
		_tick(main, p, Vector2(g2 * 16) + Vector2(8, 8), Combat.impact_tick(&"sickle") + 1, true)
		check(h.hp < hp, "aimed at grass the sickle is the weapon (%d -> %d)" % [hp, h.hp])
	main.arenas[Config.MAP_SURFACE].heretics.clear()
	_tick(main, p, aim, 40, false)
	# A wild herb picked where it grew gives a seed of its crop; a dropped one does not.
	var herb: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in WorldItems.gatherable_cells(data):
		if WorldItems.gatherable_at(data, c) == &"wild_buff":
			herb = c
			break
	if check(herb.x >= 0, "a wild buff herb on the map"):
		p.teleport(feet_for(herb))
		p.aim_sector = Aim.Sector.NORTH
		var seeds: int = p.inventory.count_of(&"seed_buff")
		main.pick_up()
		check_eq(p.inventory.count_of(&"wild_buff", ItemDB.Grade.FINE), 1, "picked")
		check_eq(p.inventory.count_of(&"seed_buff"), seeds + Config.SEEDS_PER_WILD_HERB, "a seed of its crop with it")
		p.inventory.select(0)
		var bslot: int = -1
		for i: int in p.inventory.size():
			if p.inventory.stack_at(i) != null and p.inventory.stack_at(i).id == &"wild_buff":
				bslot = i
		var drop_cell: Vector2i = herb
		main._apply_offline(WorldItems.drop(data, p.sim_position, p.inventory, bslot, 0, drop_cell), "drop", drop_cell)
		main.pick_up()
		check_eq(p.inventory.count_of(&"seed_buff"), seeds + Config.SEEDS_PER_WILD_HERB, "a dropped herb picked up again: no seed")
	# --test-field puts a withered crop by the ash (outside the light) and a ripe one in it.
	var near_ash: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.FLOOR].size():
		var a: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.terrain_at(a) == Terrain.ASH and data.can_set_terrain(a + Vector2i(0, 2), Terrain.SOIL) \
				and data.get_value(WorldData.Layer.VEGETATION, a + Vector2i(0, 2)) == 0:
			near_ash = a + Vector2i(0, 2)
			break
	var lit_soil: Vector2i = soil_cells(data)[0]
	var opts: CliOptions = CliOptions.parse(PackedStringArray(["--test-field=%d,%d:buff:4:wet/%d,%d:healing:2:fast" % [
		near_ash.x, near_ash.y, lit_soil.x, lit_soil.y]]))
	check_eq(opts.errors.size(), 0, "--test-field parses (%s)" % ", ".join(opts.errors))
	check_eq(opts.test_fields.size(), 2, "two fields")
	main.apply_test_fields(opts.test_fields)
	var put: Farming.Field = Farming.field_at(data, lit_soil)
	check(put != null and put.kind == Farming.KIND_HEALING and put.stage == 2 and put.fast and not put.wet, "a test field as asked")
	main.step_farms()
	check(Farming.field_at(data, near_ash).withered, "the crop by the ash withered on the first farm tick")
	check(not Farming.field_at(data, lit_soil).withered, "the lit one grows")
	check_eq(main.world.fields.verify()["mismatches"], 0, "all drawn = data")
	for bad: String in ["--test-field=3,3", "--test-field=3,3:wheat", "--test-field=3,3:soil:2", "--test-field=3,3:buff:5",
			"--test-field=3,3:none", "--test-field=3:buff"]:
		check(not CliOptions.parse(PackedStringArray([bad])).errors.is_empty(), "%s is refused" % bad)


# --- a session (M5a: farming off until M5c) -----------------------------------------------------------------

func _check_session() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"FarmTestNet"
	add_node(s)
	s.world = w
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var data: WorldData = w.data
	var soil: Vector2i = soil_cells(data)[0]
	var m: NetMember = s.add_member(2, 7, "herbalist", feet_for(soil), RigData.Dir.NORTH)
	m.gate = InputGate.new()
	check(not m.player.farming_on, "a session's player: farming off")
	m.player.inventory.add(&"seed_healing", 3)
	m.player.inventory.add(&"hoe", 1)
	var hash0: String = data.content_hash()
	# Its own controls make no frame of a seed click.
	var made: NetProtocol.InputFrame = m.player.make_frame(Vector2i.ZERO, Vector2(soil * 16) + Vector2(8, 8), true, true, true)
	check_eq(made.op, NetProtocol.Op.NONE, "a seed click in a session: no request")
	# A forged USE of the seeds: refused.
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	f.op = NetProtocol.Op.USE
	f.slot = 0
	f.cell = soil
	f.map = Config.MAP_SURFACE
	m.player.begin_tick()
	host.run_frame(m, f)
	check_eq(m.refused(Farming.WHY_OFFLINE), 1, "the host refuses it: farming offline only")
	check_eq(m.player.inventory.count_of(&"seed_healing"), 3, "no seed used")
	# The hoe plays its action and changes nothing.
	var g: Vector2i = lit_grass(data)[0]
	m.player.teleport(feet_for(g))
	var hoe: NetProtocol.InputFrame = NetProtocol.InputFrame.new(2, Vector2i.ZERO)
	hoe.op = NetProtocol.Op.USE
	hoe.slot = 1
	hoe.cell = g
	hoe.map = Config.MAP_SURFACE
	m.player.begin_tick()
	host.run_frame(m, hoe)
	check_eq(m.player.action_anim, RigData.Anim.HOE, "the hoe's action plays")
	for i: int in 40:
		m.player.begin_tick()
		host.run_frame(m, NetProtocol.InputFrame.new(3 + i, Vector2i.ZERO))
	check_eq(data.terrain_at(g), Terrain.GRASS, "and tills nothing in a session")
	check_eq(data.content_hash(), hash0, "the host's world unchanged")
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 0, "no edit")
