class_name Farm
extends RefCounted
## One map's farm (M5a): the timers of its fields and the four farming actions (till, plant, water, harvest). The rules
## are items/farming.gd's; the visible state of a field (crop, stage, wet, withered, planted by the herbalist) is the
## world's (FLOOR soil + VEGETATION value, Farming.Field), so the snapshot, the hash and the edit log carry it. Here only
## what changes every tick and nobody sees: a crop's growth ticks in its stage and a wet tile's water left (Plot).
## Every method returns world edits and never writes the data itself; the caller applies them to the map's GameWorld
## (GameWorld.apply_edit: data + views) before it calls anything here again (each call reads the tile from the data: a
## water() before the plant() edits are in would see bare soil), offline core/main.gd every physics tick, the host in M5c. Nothing here reads the clock or a
## random number: the same actions on the same ticks give the same world (offline == host, tests/test_farming.gd).
##
## One step (one simulation tick), field tiles in row order:
##   1. a crop withers the tick its tile is outside the light or corruption lies within reach (Farming.withers_at), and
##      revives the tick neither holds any more (its stage and growth kept: the light came back, M5b's purification);
##   2. a crop that is wet, not withered and not ripe grows one tick; Farming.stage_ticks of them make the next stage;
##   3. a wet tile's water runs down one tick (withered or not, crop or bare); at 0 it is dry.
## A ripe crop stays ripe (no rotting). A field never goes back to grass (no untilling, no decay: not in the docs).

## The timers of one field tile.
class Plot:
	extends RefCounted
	var progress: int = 0
	var water_left: int = 0


## What one action did (like Mining.Result): ok or why not, the edits, the item used or got, how many, its grade; a
## harvest's seeds, and what did not fit the inventory (dropped on the tile, or lost when the map had MAX_DROPS).
class Result:
	extends RefCounted
	var why: String = ""
	var edits: Array[EditLog.WorldEdit] = []
	var item: StringName = &""
	var count: int = 0
	var grade: int = ItemDB.Grade.NONE
	var seeds: int = 0
	var dropped: int = 0
	var lost: int = 0

	func ok() -> bool:
		return why.is_empty()

	static func refused(reason: String) -> Result:
		var r: Result = Result.new()
		r.why = reason
		return r


var data: WorldData
## Timers by tile index (y * width + x) of every field tile: a crop or a wet bare tile.
var plots: Dictionary[int, Plot] = {}
## Ticks stepped since setup.
var ticks: int = 0
## Counters: tilled, planted, watered, harvested, grown (stages), withered, revived, dried.
var stats: Dictionary[String, int] = {}
## M5c, tests only (--test-crop-ticks): ticks per stage in place of Config.CROP_STAGE_TICKS (0 = the Config value;
## Farming.stage_ticks), so a session sees a crop grow in seconds.
var stage_ticks_base: int = 0


func _init(p_data: WorldData = null) -> void:
	if p_data != null:
		setup(p_data)


## Timers for every field of `p_data` (a world generated, received or swapped in): growth from the start of the stage,
## a wet tile full of water (the timers are not part of the world; M5c's host keeps its own).
func setup(p_data: WorldData) -> void:
	data = p_data
	plots.clear()
	ticks = 0
	stats.clear()
	for c: Vector2i in Farming.field_cells(data):
		sync_cell(c)


## Takes tile `c` as the data has it now (a field edited from outside: test flags, a world edit): a timer for a field, none
## for anything else. An existing timer keeps its counts; a new wet tile is full of water.
func sync_cell(c: Vector2i) -> void:
	var i: int = data.index_of(c)
	var f: Farming.Field = Farming.field_at(data, c)
	if f == null:
		plots.erase(i)
		return
	if not plots.has(i):
		var p: Plot = Plot.new()
		p.water_left = Config.WATER_TICKS if f.wet else 0
		plots[i] = p


func stat(name: String) -> int:
	return stats.get(name, 0)


func _count(name: String, n: int = 1) -> void:
	var have: int = stats.get(name, 0)
	stats[name] = have + n


## One tick of every field (the class comment's three rules). Returns the VEGETATION edits of the tiles that changed.
func step() -> Array[EditLog.WorldEdit]:
	ticks += 1
	var out: Array[EditLog.WorldEdit] = []
	if plots.is_empty():
		return out
	var zone: SafeZone = SafeZone.for_world(data)
	var keys: Array[int] = []
	keys.assign(plots.keys())
	keys.sort()
	for i: int in keys:
		var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		var f: Farming.Field = Farming.field_at(data, c)
		if f == null:
			plots.erase(i)
			continue
		var plot: Plot = plots[i]
		var before: int = f.value()
		if f.kind != Farming.KIND_NONE:
			var cause: String = Farming.withers_at(data, c, zone)
			if not cause.is_empty() and not f.withered:
				f.withered = true
				_count("withered")
			elif cause.is_empty() and f.withered:
				f.withered = false
				_count("revived")
			if f.wet and not f.withered and not f.ripe():
				plot.progress += 1
				if plot.progress >= Farming.stage_ticks(f.fast, stage_ticks_base):
					f.stage += 1
					plot.progress = 0
					_count("grown")
		if f.wet:
			plot.water_left -= 1
			if plot.water_left <= 0:
				plot.water_left = 0
				f.wet = false
				_count("dried")
		var after: int = f.value()
		if after != before:
			out.append(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, after))
		if after == 0:
			plots.erase(i)
	return out


## The hoe lands on tile `c` (feet at `feet`): grass becomes soil (Farming.till_refusal).
func till(feet: Vector2, c: Vector2i) -> Result:
	var why: String = Farming.till_refusal(data, feet, c)
	if not why.is_empty():
		return Result.refused(why)
	var r: Result = Result.new()
	r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c, Terrain.SOIL))
	_count("tilled")
	return r


## A click with the seeds in hotbar slot `slot` on tile `c` by a player of `class_id`: one seed into the soil, a crop at
## stage 0 (wet if the tile was), FLAG_FAST when the herbalist planted it (Farming.plant_refusal: ● R37 first).
func plant(feet: Vector2, class_id: String, inv: Inventory, slot: int, c: Vector2i) -> Result:
	if slot < 0 or slot >= inv.hotbar_size:
		return Result.refused(WorldItems.WHY_BAD_SLOT)
	if inv.stack_at(slot) == null:
		return Result.refused(WorldItems.WHY_EMPTY)
	var kind: int = Farming.seed_kind_in(inv, slot)
	var why: String = Farming.plant_refusal(data, feet, class_id, kind, c)
	if not why.is_empty():
		return Result.refused(why)
	var was: Farming.Field = Farming.field_at(data, c)
	var crop: Farming.Field = Farming.Field.new(kind, 0, was != null and was.wet, class_id == Farming.HERB_CLASS)
	var r: Result = Result.new()
	r.item = inv.stack_at(slot).id
	r.count = 1
	inv.remove(slot, 1)
	r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, crop.value()))
	var i: int = data.index_of(c)
	var plot: Plot = plots.get(i, null)
	if plot == null:
		plot = Plot.new()
		plots[i] = plot
	plot.progress = 0
	_count("planted")
	return r


## The watering can lands on tile `c`: the tile is wet for Config.WATER_TICKS from now (Farming.water_refusal). A wet
## tile's water starts over (no edit: it was wet already).
func water(feet: Vector2, c: Vector2i) -> Result:
	var why: String = Farming.water_refusal(data, feet, c)
	if not why.is_empty():
		return Result.refused(why)
	var f: Farming.Field = Farming.field_at(data, c)
	if f == null:
		f = Farming.Field.new()
	var r: Result = Result.new()
	if not f.wet:
		f.wet = true
		r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, f.value()))
	var i: int = data.index_of(c)
	var plot: Plot = plots.get(i, null)
	if plot == null:
		plot = Plot.new()
		plots[i] = plot
	plot.water_left = Config.WATER_TICKS
	_count("watered")
	return r


## The sickle lands on the ripe crop on tile `c` (a player of `class_id`): Config.CROP_HARVEST_HERBS of its herb at
## Farming.harvest_grade and Config.CROP_HARVEST_SEEDS of its seed into `inv`; what does not fit lies on the tile (one
## drop per item, lost when the map holds Config.MAX_DROPS). The tile stays soil (wet if it was).
func harvest(feet: Vector2, class_id: String, inv: Inventory, c: Vector2i) -> Result:
	var why: String = Farming.harvest_refusal(data, feet, c)
	if not why.is_empty():
		return Result.refused(why)
	var f: Farming.Field = Farming.field_at(data, c)
	var r: Result = Result.new()
	r.item = Farming.HERBS[f.kind]
	r.grade = Farming.harvest_grade(class_id, f)
	var seed_id: StringName = Farming.SEEDS[f.kind]
	var herbs_left: int = inv.add(r.item, Config.CROP_HARVEST_HERBS, r.grade)
	var seeds_left: int = inv.add(seed_id, Config.CROP_HARVEST_SEEDS)
	r.count = Config.CROP_HARVEST_HERBS - herbs_left
	r.seeds = Config.CROP_HARVEST_SEEDS - seeds_left
	var centre: Vector2i = c * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
	var room: int = Config.MAX_DROPS - data.drops.size()
	for pair: Array in [[r.item, herbs_left, r.grade], [seed_id, seeds_left, ItemDB.Grade.NONE]]:
		var n: int = pair[1]
		if n <= 0:
			continue
		if room <= 0:
			r.lost += n
			continue
		room -= 1
		r.dropped += n
		var id: StringName = pair[0]
		var g: int = pair[2]
		r.edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), id, n, g, centre)))
	var rest: Farming.Field = Farming.Field.new(Farming.KIND_NONE, 0, f.wet)
	r.edits.append(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, rest.value()))
	var i: int = data.index_of(c)
	if rest.value() == 0:
		plots.erase(i)
	elif plots.has(i):
		plots[i].progress = 0
	_count("harvested")
	return r


## md5 of the timers (tile, growth, water) and the tick count: equal = the same farm (with the world's hash, the whole
## state; tests/test_farming.gd).
func state_hash() -> String:
	var keys: Array[int] = []
	keys.assign(plots.keys())
	keys.sort()
	var out: PackedInt64Array = PackedInt64Array([ticks, keys.size()])
	for i: int in keys:
		out.append(i)
		out.append(plots[i].progress)
		out.append(plots[i].water_left)
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(out.to_byte_array())
	return ctx.finish().hex_encode()
