extends "res://tests/base_test.gd"
## M5b, purification (offline first): the rules (holy water's 3x3 and its refusals, the channel's disc, who may start it
## and where, what purified ground becomes), the channel in the shared simulation (start, length, what breaks it), the
## heretics' spawn tiles following the corruption (Arena.sync_world), withered crops reviving when the corruption near
## them is purified (the M5a rule), a deterministic run, the world's edits / snapshot / hash, the view (ground drawn =
## data, the ash smears and the flash, the channel's motes), main.tscn offline (F starts the paladin's channel, holy water
## poured with a click) and a session (refused until M5c).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0
const CLASSES: PackedStringArray = ["paladin", "miner", "archer", "cleric", "herbalist"]


func run() -> Array[String]:
	_check_areas()
	_check_holy_water_rules()
	_check_channel_rules()
	_check_channel_sim()
	_check_spawn_tiles()
	_check_crop_revival()
	_check_determinism()
	await _check_view()
	await _check_main()
	await _check_session()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------

static func world() -> WorldData:
	return SurfaceGen.generate(Config.DEFAULT_SEED)


static func apply(data: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(data, e)


## An ash tile on a zone's southern edge (grass below it, nothing lying on either), row by row: the paladin stands on
## the grass below it (next to corruption).
static func edge_ash(data: WorldData, skip: int = 0) -> Vector2i:
	var n: int = 0
	for y: int in range(2, data.size.y - 3):
		for x: int in range(2, data.size.x - 2):
			var c: Vector2i = Vector2i(x, y)
			if data.get_value(WorldData.Layer.CORRUPTION, c) == 0 or data.terrain_at(c + Vector2i(0, 1)) != Terrain.GRASS:
				continue
			if data.get_value(WorldData.Layer.VEGETATION, c) != 0 or data.get_value(WorldData.Layer.VEGETATION, c + Vector2i(0, 1)) != 0 \
					or data.get_value(WorldData.Layer.VEGETATION, c + Vector2i(0, 2)) != 0:
				continue
			if n == skip:
				return c
			n += 1
	return Vector2i(-1, -1)


## Feet low in tile `c` (Arena.spawn_feet: the feet tile is `c`).
static func feet_in(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


## Written out here (not Purify): corrupted tiles whose centre lies within `r` tiles of tile `centre`'s centre.
static func disc_corrupted(data: WorldData, centre: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(centre.y - r, centre.y + r + 1):
		for x: int in range(centre.x - r, centre.x + r + 1):
			var d: Vector2i = Vector2i(x, y) - centre
			if d.length_squared() <= r * r and data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				out.append(Vector2i(x, y))
	return out


## A grass tile far from the ash and the altar with nothing on it.
static func clean_grass(data: WorldData) -> Vector2i:
	for y: int in range(6, data.size.y - 6):
		for x: int in range(6, data.size.x - 6):
			var c: Vector2i = Vector2i(x, y)
			if data.terrain_at(c) == Terrain.GRASS and not Farming.near_corruption(data, c) \
					and Purify.corrupted_in(data, Purify.holy_water_area(c)).is_empty() \
					and data.get_value(WorldData.Layer.VEGETATION, c) == 0 and data.get_value(WorldData.Layer.PLACEABLE, c) == 0 \
					and Vector2(c * 16).distance_to(data.altar_center_px()) > 200.0:
				var far: bool = true
				for oy: int in range(-3, 4):
					for ox: int in range(-3, 4):
						if data.get_value(WorldData.Layer.CORRUPTION, c + Vector2i(ox, oy)) != 0:
							far = false
				if far:
					return c
	return Vector2i(-1, -1)


# --- the areas ---------------------------------------------------------------------------------------------

func _check_areas() -> void:
	var c: Vector2i = Vector2i(20, 30)
	var hw: Array[Vector2i] = Purify.holy_water_area(c)
	var want: Array[Vector2i] = []
	for y: int in range(29, 32):
		for x: int in range(19, 22):
			want.append(Vector2i(x, y))
	check_eq(hw, want, "holy water reaches the 3x3 around its tile (Config.HOLY_WATER_RADIUS_TILES 1)")
	var disc: Array[Vector2i] = Purify.channel_area(c)
	var r: int = Config.PURIFY_RADIUS_TILES
	var n: int = 0
	var wrong: int = 0
	for y2: int in range(c.y - r - 2, c.y + r + 3):
		for x2: int in range(c.x - r - 2, c.x + r + 3):
			var d: Vector2i = Vector2i(x2 - c.x, y2 - c.y)
			var inside: bool = d.x * d.x + d.y * d.y <= r * r
			n += int(inside)
			if inside != disc.has(Vector2i(x2, y2)):
				wrong += 1
	check_eq(wrong, 0, "the channel's disc: tile centres within the radius")
	check_eq(disc.size(), n, "and nothing else (%d tiles)" % n)
	check_eq(disc.size(), 29, "radius 3: 29 tiles")
	check(disc.has(c) and disc.has(c + Vector2i(3, 0)) and not disc.has(c + Vector2i(3, 1)) and not disc.has(c + Vector2i(2, 3)),
		"its edge")


# --- holy water ----------------------------------------------------------------------------------------------

func _check_holy_water_rules() -> void:
	var data: WorldData = world()
	var a: Vector2i = edge_ash(data)
	if not check(a.x >= 0, "an ash tile on a zone edge"):
		return
	var feet: Vector2 = feet_in(a + Vector2i(0, 1))
	check(Purify.is_corrupted(data, a) and data.terrain_at(a) == Terrain.ASH, "the zone: ash floor and a zone id")
	check_eq(Purify.holy_water_refusal(data, feet, a), "", "holy water on the zone edge from next to it")
	check_eq(Purify.holy_water_refusal(data, feet, a + Vector2i(0, -1)), WorldItems.WHY_REACH, "two tiles away: out of reach")
	check_eq(Purify.holy_water_refusal(data, feet, Vector2i(-1, 5)), WorldItems.WHY_OUTSIDE, "outside the map")
	var g: Vector2i = clean_grass(data)
	check_eq(Purify.holy_water_refusal(data, feet_in(g + Vector2i(0, 1)), g), Purify.WHY_NOTHING, "clean grass: nothing to purify")
	# Pour: one used, the corrupted tiles of the 3x3 (written out) purified to grass; nothing else changes.
	var inv: Inventory = Inventory.new()
	inv.add(Purify.HOLY_WATER, 3)
	inv.add(&"stone_a", 5)
	var want: Array[Vector2i] = []
	for y: int in range(a.y - 1, a.y + 2):
		for x: int in range(a.x - 1, a.x + 2):
			if data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				want.append(Vector2i(x, y))
	var gath: Dictionary[Vector2i, int] = {}
	for c: Vector2i in want:
		if data.get_value(WorldData.Layer.VEGETATION, c) != 0:
			gath[c] = data.get_value(WorldData.Layer.VEGETATION, c)
	var before: int = Purify.corrupted_count(data)
	var hash0: String = data.content_hash()
	var r: Purify.Result = Purify.pour(data, feet, inv, 0, a)
	check(r.ok(), "poured (%s)" % r.why)
	check_eq(data.content_hash(), hash0, "pour() writes nothing itself (edits only)")
	check_eq(r.cells, want, "it purifies the 3x3's corrupted tiles")
	check_eq(r.edits.size(), 2 * want.size(), "two edits a tile: the corruption, the ash floor")
	apply(data, r.edits)
	check_eq(inv.count_of(Purify.HOLY_WATER), 2, "one holy water used")
	check_eq(Purify.corrupted_count(data), before - want.size(), "the corruption count")
	var clean: bool = true
	for c2: Vector2i in want:
		clean = clean and data.terrain_at(c2) == Terrain.GRASS and data.get_value(WorldData.Layer.CORRUPTION, c2) == 0
	check(clean, "purified tiles are grass with no corruption (grass at once)")
	var kept: bool = true
	for c3: Vector2i in gath:
		kept = kept and data.get_value(WorldData.Layer.VEGETATION, c3) == gath[c3]
	check(kept, "what lay on them stays (%d gatherables)" % gath.size())
	check_eq(data.soil_ash_contacts(), 0, "no soil next to ash")
	# Refused: nothing used.
	var r2: Purify.Result = Purify.pour(data, feet_in(g + Vector2i(0, 1)), inv, 0, g)
	check(not r2.ok() and r2.why == Purify.WHY_NOTHING and inv.count_of(Purify.HOLY_WATER) == 2, "refused: nothing used")
	# None left (dropped or moved meanwhile): the effect frame finds it gone.
	var empty: Inventory = Inventory.new()
	var a2: Vector2i = edge_ash(data)
	var r3: Purify.Result = Purify.pour(data, feet_in(a2 + Vector2i(0, 1)), empty, 0, a2)
	check(not r3.ok() and r3.why == Purify.WHY_GONE and r3.edits.is_empty(), "no holy water left: %s" % r3.why)
	# From the first stack of it when the slot holds something else.
	var inv2: Inventory = Inventory.new()
	inv2.add(&"stone_a", 5)
	inv2.add(Purify.HOLY_WATER, 1)
	var r4: Purify.Result = Purify.pour(data, feet_in(a2 + Vector2i(0, 1)), inv2, 0, a2)
	check(r4.ok() and inv2.count_of(Purify.HOLY_WATER) == 0 and inv2.count_of(&"stone_a") == 5, "taken from its own stack")
	check_eq(Purify.impact_tick(), Config.HOLY_WATER_EFFECT_FRAME * Config.ACTION_FRAME_TICKS, "it works on its effect frame")


# --- the channel's rules -------------------------------------------------------------------------------------

func _check_channel_rules() -> void:
	var data: WorldData = world()
	var a: Vector2i = edge_ash(data)
	var on: Vector2 = feet_in(a)
	var next: Vector2 = feet_in(a + Vector2i(0, 1))
	var two: Vector2 = feet_in(a + Vector2i(0, 2))
	# Two tiles below the edge tile there may be other ash on the sides: find the nearest tile by the written-out rule.
	var two_near: bool = false
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			two_near = two_near or data.get_value(WorldData.Layer.CORRUPTION, a + Vector2i(ox, 2 + oy)) != 0
	for k: String in CLASSES:
		var want_on: String = "" if k == "paladin" else Purify.WHY_PALADIN
		check_eq(Purify.channel_refusal(data, k, on), want_on, "%s standing on corruption" % k)
		check_eq(Purify.channel_refusal(data, k, next), want_on, "%s next to it" % k)
		var want_two: String = Purify.WHY_PALADIN if k != "paladin" else ("" if two_near else Purify.WHY_NOTHING)
		check_eq(Purify.channel_refusal(data, k, two), want_two, "%s two tiles away" % k)
	check_eq(Purify.channel_refusal(data, "paladin", feet_in(clean_grass(data))), Purify.WHY_NOTHING, "the paladin on clean grass")
	check_eq(Purify.channel_centre(next), a + Vector2i(0, 1), "the channel's tile is the feet tile")
	# Done: the disc's corrupted tiles (written out); again at once: nothing left.
	var centre: Vector2i = a + Vector2i(0, 1)
	var want: Array[Vector2i] = disc_corrupted(data, centre, Config.PURIFY_RADIUS_TILES)
	var r: Purify.Result = Purify.channel_done(data, centre)
	check(r.ok() and r.cells == want and want.size() > 2, "a channel purifies its disc's corrupted tiles (%d)" % want.size())
	apply(data, r.edits)
	check(disc_corrupted(data, centre, Config.PURIFY_RADIUS_TILES).is_empty(), "none left in the disc")
	var again: Purify.Result = Purify.channel_done(data, centre)
	check(not again.ok() and again.why == Purify.WHY_NOTHING, "a second channel there: nothing to purify")
	check_eq(data.soil_ash_contacts(), 0, "the ground keeps its art rules")
	# The dungeon has no corruption: nothing to purify there.
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check_eq(Purify.corrupted_count(dun), 0, "the dungeon: no corrupted tile")
	check_eq(Purify.channel_refusal(dun, "paladin", DungeonGen.arrival_point(dun)), Purify.WHY_NOTHING, "no channel in the dungeon")


# --- the channel in the simulation ---------------------------------------------------------------------------

static func sim_at(feet: Vector2) -> PlayerSim:
	var s: PlayerSim = PlayerSim.new()
	s.pos = feet
	return s


static func step(s: PlayerSim, data: WorldData, dir: Vector2i = Vector2i.ZERO, anim: int = -1, dash: bool = false,
		channel: bool = false) -> int:
	return s.step(data, dir, -1, anim, Aim.feet_cell(s.pos) + Vector2i(0, -1), TICK, dash, false, -1, channel)


func _check_channel_sim() -> void:
	var data: WorldData = world()
	var a: Vector2i = edge_ash(data)
	var feet: Vector2 = feet_in(a + Vector2i(0, 1))
	var s: PlayerSim = sim_at(feet)
	var ev: int = step(s, data, Vector2i.ZERO, -1, false, true)
	check(ev & PlayerSim.CHANNEL_STARTED != 0 and s.channel_tick == 1 and s.channel_cell == a + Vector2i(0, 1),
		"a channel frame starts it (tick 1, the feet tile)")
	var done_at: int = -1
	for t: int in range(2, Config.PURIFY_CHANNEL_TICKS + 5):
		ev = step(s, data)
		if ev & PlayerSim.CHANNEL_DONE:
			done_at = t
			break
		if s.pos != feet or s.walking:
			fail("the channel moved the player at tick %d" % t)
			break
	check_eq(done_at, Config.PURIFY_CHANNEL_TICKS, "it runs Config.PURIFY_CHANNEL_TICKS frames, the start one included")
	check_eq(s.channel_tick, 0, "and is over then")
	# What breaks it: a move (and the player moves that frame), a dash (it dashes), a use (its action starts).
	for what: String in ["move", "dash", "use"]:
		var b: PlayerSim = sim_at(feet)
		step(b, data, Vector2i.ZERO, -1, false, true)
		for i: int in 30:
			step(b, data)
		var e2: int = 0
		if what == "move":
			e2 = step(b, data, Vector2i(1, 0))
			check(e2 & PlayerSim.CHANNEL_BROKEN != 0 and b.channel_tick == 0 and b.pos.x > feet.x, "a move breaks it and moves")
		elif what == "dash":
			e2 = step(b, data, Vector2i.ZERO, -1, true)
			check(e2 & PlayerSim.CHANNEL_BROKEN != 0 and e2 & PlayerSim.DASHED != 0, "a dash breaks it and dashes")
		else:
			e2 = step(b, data, Vector2i.ZERO, RigData.Anim.SWORD)
			check(e2 & PlayerSim.CHANNEL_BROKEN != 0 and e2 & PlayerSim.STARTED != 0 and b.action == RigData.Anim.SWORD,
				"a use breaks it and its action starts")
	# A hit breaks it; going down (a poison tick too) breaks it.
	var h: PlayerSim = sim_at(feet)
	step(h, data, Vector2i.ZERO, -1, false, true)
	step(h, data)
	check(h.hurt(10) & PlayerSim.HURT != 0 and h.channel_tick == 0, "a hit breaks it")
	var p2: PlayerSim = sim_at(feet)
	p2.vit.hp = 1
	p2.add_poison(5, 300)
	step(p2, data, Vector2i.ZERO, -1, false, true)
	var downed: bool = false
	for i2: int in Config.POISON_INTERVAL_TICKS + 2:
		downed = downed or step(p2, data) & PlayerSim.DOWNED != 0
	check(downed and p2.channel_tick == 0 and p2.vit.life == Vitals.Life.DOWN, "a poison tick that takes it down breaks it")
	# It does not start: moving that frame, an action playing, staggered, down.
	var m: PlayerSim = sim_at(feet)
	check(step(m, data, Vector2i(0, 1), -1, false, true) & PlayerSim.CHANNEL_STARTED == 0 and m.channel_tick == 0,
		"not while moving")
	var act: PlayerSim = sim_at(feet)
	step(act, data, Vector2i.ZERO, RigData.Anim.SWORD)
	check(step(act, data, Vector2i.ZERO, -1, false, true) & PlayerSim.CHANNEL_STARTED == 0, "not while an action plays")
	var st: PlayerSim = sim_at(feet)
	st.hurt(5)
	check(step(st, data, Vector2i.ZERO, -1, false, true) & PlayerSim.CHANNEL_STARTED == 0, "not while staggered")
	var dn: PlayerSim = sim_at(feet)
	dn.hurt(Config.PLAYER_HP_MAX)
	check(step(dn, data, Vector2i.ZERO, -1, false, true) & PlayerSim.CHANNEL_STARTED == 0, "not while down")
	# The copy and the full comparison carry it.
	var c: PlayerSim = sim_at(feet)
	step(c, data, Vector2i.ZERO, -1, false, true)
	var cp: PlayerSim = c.copy()
	check(cp.channel_tick == 1 and cp.channel_cell == c.channel_cell and cp.same_all(c), "copy() keeps the channel")
	step(cp, data)
	check(not cp.same_all(c) and cp.same_as(c), "same_all sees the channel (same_as, the wire's, does not: offline until M5c)")


# --- the heretics' spawn tiles -------------------------------------------------------------------------------

func _check_spawn_tiles() -> void:
	var data: WorldData = world()
	var arena: Arena = Arena.new()
	arena.setup(data, Config.DEFAULT_SEED)
	var start: int = arena.spawn_cells.size()
	check_eq(start, 678, "the generated world's spawn tiles (the smoke's spawn_tiles)")
	check(not arena.sync_world(), "nothing changed: no sync")
	# Purify zone 1 whole.
	var zone1: Array[Vector2i] = []
	var grid: PackedByteArray = data.layers[WorldData.Layer.CORRUPTION]
	for i: int in grid.size():
		if grid[i] == 1:
			zone1.append(Vector2i(i % data.size.x, i / data.size.x))
	apply(data, Purify.edits_for(data, zone1))
	check(arena.sync_world(), "purified: the arena syncs")
	var fresh: Array[Vector2i] = Arena.surface_spawn_cells(data, SafeZone.for_world(data))
	check_eq(arena.spawn_cells, fresh, "its spawn tiles = the rule worked out again on the purified world")
	check(arena.spawn_cells.size() < start, "fewer of them (%d -> %d)" % [start, arena.spawn_cells.size()])
	# Written out: every spawn tile lies within Config.HERETIC_SPAWN_ASH_REACH_TILES of a corrupted tile.
	var r: int = Config.HERETIC_SPAWN_ASH_REACH_TILES
	var stray: int = 0
	for c: Vector2i in arena.spawn_cells:
		var near: bool = false
		for oy: int in range(-r, r + 1):
			for ox: int in range(-r, r + 1):
				near = near or data.get_value(WorldData.Layer.CORRUPTION, c + Vector2i(ox, oy)) != 0
		if not near:
			stray += 1
	check_eq(stray, 0, "no spawn tile around the purified zone any more")
	check_eq(arena.stat("world_synced"), 1, "synced once")
	# step() syncs by itself.
	var zone2: Array[Vector2i] = []
	for i2: int in grid.size():
		if data.layers[WorldData.Layer.CORRUPTION][i2] == 2:
			zone2.append(Vector2i(i2 % data.size.x, i2 / data.size.x))
	apply(data, Purify.edits_for(data, zone2))
	var none: Array[Player] = []
	arena.step(none)
	check_eq(arena.spawn_cells, Arena.surface_spawn_cells(data, SafeZone.for_world(data)), "step() syncs first")
	# All corruption gone: no spawn tile, no spawn.
	var rest: Array[Vector2i] = []
	for i3: int in grid.size():
		if data.layers[WorldData.Layer.CORRUPTION][i3] != 0:
			rest.append(Vector2i(i3 % data.size.x, i3 / data.size.x))
	var h: HereticSim = arena.spawn_heretic(Arena.spawn_feet(rest[0]))
	apply(data, Purify.edits_for(data, rest))
	arena.sync_world()
	check(arena.spawn_cells.is_empty() and not arena.spawns_now(), "no corruption left: nowhere to spawn")
	var p: Player = Player.new()
	p.setup(data, "paladin", data.altar_center_px() + Vector2(0, 200))
	var ps: Array[Player] = [p]
	arena.spawn_timer = Config.HERETIC_SPAWN_INTERVAL_TICKS - 1
	var spawned: int = arena.stat("spawned")
	arena.step(ps)
	check_eq(arena.stat("spawned"), spawned, "and no spawn")
	check(h.alive() and arena.heretics.has(h), "a heretic already there stays")
	p.free()
	check_eq(Purify.corrupted_count(data), 0, "every tile purified")
	check_eq(data.count_value(WorldData.Layer.FLOOR, Terrain.ASH), 0, "no ash floor left")


# --- withered crops revive -------------------------------------------------------------------------------------

func _check_crop_revival() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	# A lit soil tile; ash two tiles from it (the nearest the art allows), then a crop there withers.
	var soil: Vector2i = Vector2i(-1, -1)
	var ash: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.FLOOR].size():
		var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.terrain_at(c) != Terrain.SOIL or not Farming.in_light(data, c):
			continue
		for d: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
			var t: Vector2i = c + d
			if data.terrain_at(t) == Terrain.GRASS and data.get_value(WorldData.Layer.PLACEABLE, t) == 0 \
					and data.can_set_terrain(t, Terrain.ASH):
				soil = c
				ash = t
				break
		if soil.x >= 0:
			break
	if not check(soil.x >= 0, "a lit soil tile with room for ash two tiles away"):
		return
	data.set_terrain(ash, Terrain.ASH)
	data.set_value(WorldData.Layer.CORRUPTION, ash, 9)
	data.set_value(WorldData.Layer.VEGETATION, soil, Farming.Field.new(Farming.KIND_HEALING, 2, true).value())
	farm.sync_cell(soil)
	apply(data, farm.step())
	var f: Farming.Field = Farming.field_at(data, soil)
	check(f.withered and f.stage == 2, "corruption two tiles away: the crop withers (M5a rule)")
	var progress: int = farm.plots[data.index_of(soil)].progress
	for i2: int in 30:
		apply(data, farm.step())
	check_eq(farm.plots[data.index_of(soil)].progress, progress, "and does not grow")
	# Holy water on the ash: the next farm tick revives it, its stage and growth kept.
	var inv: Inventory = Inventory.new()
	inv.add(Purify.HOLY_WATER, 1)
	var r: Purify.Result = Purify.pour(data, feet_in(ash + Vector2i(0, 1)) if ash.y < soil.y else feet_in(ash + Vector2i(0, -1)),
		inv, 0, ash)
	check(r.ok() and r.cells.has(ash), "the ash purified (%s)" % r.why)
	apply(data, r.edits)
	apply(data, farm.step())
	var g: Farming.Field = Farming.field_at(data, soil)
	check(not g.withered and g.stage == 2, "the next tick it revives, at its stage")
	check(farm.plots[data.index_of(soil)].progress > progress, "and grows on")
	check_eq(farm.stats.get("revived", 0), 1, "one revival counted")


# --- determinism and the world's records ------------------------------------------------------------------------

## A scripted run on the seed-1 world: holy water and channels at fixed ticks (pure rules + the farm), the world hash
## every 50 ticks.
static func scripted(n: int) -> PackedStringArray:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	var out: PackedStringArray = []
	var inv: Inventory = Inventory.new()
	inv.add(Purify.HOLY_WATER, 10)
	var sim: PlayerSim = PlayerSim.new()
	var a: Vector2i = edge_ash(data, 0)
	sim.pos = feet_in(a + Vector2i(0, 1))
	for t: int in n:
		var channel: bool = t % 400 == 10
		if t % 400 == 300:
			var target: Vector2i = edge_ash(data, 0)
			if target.x >= 0:
				sim.pos = feet_in(target + Vector2i(0, 1))
				apply(data, Purify.pour(data, sim.pos, inv, 0, target).edits)
		if channel:
			var at: Vector2i = edge_ash(data, 1)
			if at.x >= 0:
				sim.pos = feet_in(at + Vector2i(0, 1))
		var ev: int = sim.step(data, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK, false, false, -1,
			channel and Purify.channel_refusal(data, "paladin", sim.pos).is_empty())
		if ev & PlayerSim.CHANNEL_DONE:
			apply(data, Purify.channel_done(data, sim.channel_cell).edits)
		apply(data, farm.step())
		if t % 50 == 49:
			out.append("%s/%d" % [data.content_hash(), Purify.corrupted_count(data)])
	return out


func _check_determinism() -> void:
	var a: PackedStringArray = scripted(2000)
	var b: PackedStringArray = scripted(2000)
	check_eq(a, b, "the same script twice: the same world every 50 ticks")
	check(a[0] != a[a.size() - 1], "and it purified something (%s -> %s)" % [a[0].get_slice("/", 1), a[a.size() - 1].get_slice("/", 1)])
	# The edits travel as ordinary cell edits (corruption and floor layers) and the snapshot carries the result.
	var data: WorldData = world()
	var copy: WorldData = world()
	var r: Purify.Result = Purify.channel_done(data, edge_ash(data))
	var bytes_ok: bool = true
	for i: int in r.edits.size():
		var msg: PackedByteArray = EditLog.encode_one(r.edits[i], i)
		var back: Array = EditLog.decode_one(msg)
		var idx: int = back[0]
		var e: EditLog.WorldEdit = back[1]
		bytes_ok = bytes_ok and idx == i and e != null and e.layer == r.edits[i].layer and e.cell == r.edits[i].cell \
			and e.value == r.edits[i].value
		if e != null:
			EditLog.apply_to_data(copy, e)
	apply(data, r.edits)
	check(bytes_ok, "the purify edits round-trip the wire format")
	check_eq(copy.content_hash(), data.content_hash(), "applied from the wire: the same world")
	var recv: WorldData = WorldSnapshot.decode_raw(WorldSnapshot.raw_bytes(data))
	check(recv != null and recv.content_hash() == data.content_hash(), "the snapshot of a purified world")


# --- the view ---------------------------------------------------------------------------------------------------

func _check_view() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var pv: PurifyView = w.purify_view
	check(pv != null and pv.get_index() < w.entities.get_index() and pv.get_index() > w.decals.get_index(),
		"the purify view draws above the decals, below the entities")
	pv.auto_tick = false
	var a: Vector2i = edge_ash(w.data)
	var r: Purify.Result = Purify.channel_done(w.data, a + Vector2i(0, 1))
	for e: EditLog.WorldEdit in r.edits:
		w.apply_edit(e)
	pv.flash(r.cells)
	var v: Dictionary[String, int] = w.ground.verify()
	check(v["mismatches"] == 0 and v["fallbacks"] == 0, "the purified ground drawn = data (%s)" % v)
	check_eq(pv.ash_layer.get_child_count(), r.cells.size(), "an ash smear on each purified tile")
	var placed: int = 0
	for f: PurifyView.Flash in pv.flashes:
		var tex: Texture2D = f.ash.texture
		var size: Vector2i = Vector2i(tex.get_size())
		# Written out: the smear centred in its tile, whole pixels.
		if f.ash.position == Vector2(f.cell * 16 + (Vector2i(16, 16) - size) / 2) and f.ash.light_mask == Config.LIGHT_LAYER_WORLD:
			placed += 1
	check_eq(placed, r.cells.size(), "each centred on its tile, on the ground's light layer")
	var mat: CanvasItemMaterial = pv.glow.material as CanvasItemMaterial
	check(mat != null and mat.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "the glow is unshaded")
	# The flash: a 1 px square outline, 60 pixels at first, shrinking a pixel per PURIFY_FLASH_TICKS / 8 (written out).
	check_eq(PurifyView.flash_pixels(0).size(), 60, "the first flash: the tile's 60 border pixels")
	var k7: int = 7 * Config.PURIFY_FLASH_TICKS / 8 + 1
	var last: Array[Vector2i] = PurifyView.flash_pixels(k7)
	last.sort()
	check_eq(last, [Vector2i(7, 7), Vector2i(7, 8), Vector2i(8, 7), Vector2i(8, 8)] as Array[Vector2i], "the last: the 2x2 middle")
	check(PurifyView.flash_pixels(Config.PURIFY_FLASH_TICKS).is_empty(), "then none")
	pv.advance(Config.PURIFY_ASH_TICKS - 1)
	check_eq(pv.ash_layer.get_child_count(), r.cells.size(), "the ash stays Config.PURIFY_ASH_TICKS")
	pv.advance(1)
	check(pv.ash_layer.get_child_count() == 0 and pv.flashes.is_empty(), "then the ash is gone")
	# The channel's motes: on the ring at (radius + 0.5) tiles, one lit at the start, all at the end.
	var pts: Array[Vector2i] = PurifyView.mote_points(a)
	var centre: Vector2 = (Vector2(a) + Vector2(0.5, 0.5)) * 16.0
	var off: int = 0
	for p: Vector2i in pts:
		if absf((Vector2(p) + Vector2.ONE).distance_to(centre) - (Config.PURIFY_RADIUS_TILES + 0.5) * 16.0) > 1.0:
			off += 1
	check(pts.size() == Config.PURIFY_MOTES and off == 0, "motes on the ring (%d off)" % off)
	check(pts[0].x + 1 == roundi(centre.x) and pts[0].y < centre.y, "the first at the top")
	check_eq(PurifyView.motes_lit(1), 1, "one mote at the channel's start")
	check_eq(PurifyView.motes_lit(Config.PURIFY_CHANNEL_TICKS), Config.PURIFY_MOTES, "all of them on its last tick")
	check(PurifyView.motes_lit(Config.PURIFY_CHANNEL_TICKS / 2) > 1 and PurifyView.motes_lit(Config.PURIFY_CHANNEL_TICKS / 2) < Config.PURIFY_MOTES,
		"some half way")
	# A reload of the world clears the view.
	pv.flash(r.cells)
	w.load_data(w.data)
	check(pv.flashes.is_empty() and pv.ash_layer.get_child_count() == 0, "load_data clears it")


# --- main.tscn offline -------------------------------------------------------------------------------------------

func _tick(main: Main, p: Player, mouse: Vector2, n: int, press: bool, dir: Vector2i = Vector2i.ZERO) -> void:
	for i: int in n:
		p.begin_tick()
		p.tick_controls(dir, mouse, true, press and i == 0, false, TICK)
		main.step_altar_hold(p)
		main.step_farms()
		main._show_purify()


static func centre_of(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn("paladin")
	var p: Player = main.player
	if not check(p != null and p.purify_on and main.purify_on, "offline: purification on"):
		return
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	var data: WorldData = main.world.data
	var a: Vector2i = edge_ash(data)
	p.teleport(feet_in(a + Vector2i(0, 1)))
	var mouse: Vector2 = centre_of(a)
	_tick(main, p, mouse, 1, false)
	# F with nothing on the target tile: the channel starts on the next frame.
	var before: int = Purify.corrupted_count(data)
	var spawn_before: int = main.arenas[Config.MAP_SURFACE].spawn_cells.size()
	main.pick_up()
	check_eq(p.channel_tick, 0, "F asks for the channel (the next frame starts it)")
	_tick(main, p, mouse, 1, false)
	check(p.channel_tick == 1 and p.channel_cell == a + Vector2i(0, 1), "the channel started at the feet tile")
	check_eq(p.character.action, Config.PURIFY_ANIM, "showing the channel pose (the magic action)")
	check_eq(main.world.purify_view.channels.size(), 1, "and its motes")
	var want: Array[Vector2i] = disc_corrupted(data, a + Vector2i(0, 1), Config.PURIFY_RADIUS_TILES)
	_tick(main, p, mouse, Config.PURIFY_CHANNEL_TICKS - 2, false)
	check_eq(Purify.corrupted_count(data), before, "nothing purified before its last tick")
	_tick(main, p, mouse, 1, false)
	check_eq(Purify.corrupted_count(data), before - want.size(), "its last tick purified the disc (%d tiles)" % want.size())
	check(main.world.purify_view.flashes.size() == want.size() and main.world.purify_view.channels.is_empty(),
		"the purified tiles flash, the motes are gone")
	check(main.arenas[Config.MAP_SURFACE].spawn_cells.size() < spawn_before, "the arena's spawn tiles followed")
	check_eq(main.world.ground.verify()["mismatches"], 0, "drawn = data")
	check_eq(main.purified, want.size(), "Main counted them")
	# A move breaks the next one.
	var a2: Vector2i = edge_ash(data)
	p.teleport(feet_in(a2 + Vector2i(0, 1)))
	_tick(main, p, centre_of(a2), 1, false)
	var b2: int = Purify.corrupted_count(data)
	main.pick_up()
	_tick(main, p, centre_of(a2), 10, false)
	check_eq(p.channel_tick, 10, "a second channel runs")
	_tick(main, p, centre_of(a2), 1, false, Vector2i(1, 0))
	check_eq(p.channel_tick, 0, "a step breaks it")
	_tick(main, p, centre_of(a2), Config.PURIFY_CHANNEL_TICKS, false)
	check_eq(Purify.corrupted_count(data), b2, "nothing purified")
	# F on a gatherable picks it up (no channel).
	var gat: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in WorldItems.gatherable_cells(data):
		if data.terrain_at(c) == Terrain.ASH and data.get_value(WorldData.Layer.VEGETATION, c + Vector2i(0, 1)) == 0 \
				and data.get_value(WorldData.Layer.PLACEABLE, c + Vector2i(0, 1)) == 0:
			gat = c
			break
	if check(gat.x >= 0, "a gatherable on the ash"):
		p.teleport(feet_in(gat + Vector2i(0, 1)))
		_tick(main, p, centre_of(gat), 1, false)
		var item: StringName = WorldItems.gatherable_at(data, gat)
		main.pick_up()
		_tick(main, p, centre_of(gat), 1, false)
		check(p.inventory.count_of(item) == 1 and p.channel_tick == 0, "F on a gatherable on the ash picks it up, no channel")
	# Holy water: a click plays the pour; its effect frame purifies the 3x3; one used.
	var a3: Vector2i = edge_ash(data)
	p.teleport(feet_in(a3 + Vector2i(0, 1)))
	p.inventory.add(Purify.HOLY_WATER, 2)
	for i: int in p.inventory.hotbar_size:
		var s: ItemStack = p.inventory.stack_at(i)
		if s != null and s.id == Purify.HOLY_WATER:
			p.inventory.select(i)
	var hw: Array[Vector2i] = []
	for y: int in range(a3.y - 1, a3.y + 2):
		for x: int in range(a3.x - 1, a3.x + 2):
			if data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				hw.append(Vector2i(x, y))
	var b3: int = Purify.corrupted_count(data)
	_tick(main, p, centre_of(a3), 1, true)
	check_eq(p.action_anim, Config.HOLY_WATER_ANIM, "a click with holy water plays the pour")
	_tick(main, p, centre_of(a3), Purify.impact_tick() - 1, false)
	check_eq(Purify.corrupted_count(data), b3, "not before its effect frame")
	_tick(main, p, centre_of(a3), 1, false)
	check_eq(Purify.corrupted_count(data), b3 - hw.size(), "its effect frame purified the 3x3 (%d)" % hw.size())
	check_eq(p.inventory.count_of(Purify.HOLY_WATER), 1, "one holy water used")
	_tick(main, p, centre_of(a3), 40, false)
	# On clean grass: refused, nothing plays.
	var g: Vector2i = clean_grass(data)
	p.teleport(feet_in(g + Vector2i(0, 1)))
	_tick(main, p, centre_of(g), 1, true)
	check(p.action_anim < 0 and p.inventory.count_of(Purify.HOLY_WATER) == 1, "nothing to purify: no pour, nothing used")
	# Another class: F next to the ash does not channel.
	main.spawn("cleric")
	var q: Player = main.player
	q.local_input = false
	var a4: Vector2i = edge_ash(data)
	q.teleport(feet_in(a4 + Vector2i(0, 1)))
	_tick(main, q, centre_of(a4), 1, false)
	main.pick_up()
	_tick(main, q, centre_of(a4), 2, false)
	check_eq(q.channel_tick, 0, "a cleric's F next to the ash starts no channel (paladin only)")


# --- a session: refused until M5c -----------------------------------------------------------------------------------

func _check_session() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"PurifyTestNet"
	add_node(s)
	s.world = w
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var data: WorldData = w.data
	var a: Vector2i = edge_ash(data)
	var m: NetMember = s.add_member(2, 7, "paladin", feet_in(a + Vector2i(0, 1)), RigData.Dir.NORTH)
	m.gate = InputGate.new()
	check(not m.player.purify_on and not m.player.carrying_altar, "a session's player: purification off")
	m.player.inventory.add(Purify.HOLY_WATER, 3)
	var hash0: String = data.content_hash()
	var made: NetProtocol.InputFrame = m.player.make_frame(Vector2i.ZERO, centre_of(a), true, true, true)
	check_eq(made.op, NetProtocol.Op.NONE, "a holy water click in a session: no request")
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	f.op = NetProtocol.Op.USE
	f.slot = 0
	f.cell = a
	f.map = Config.MAP_SURFACE
	m.player.begin_tick()
	host.run_frame(m, f)
	check_eq(m.refused(Purify.WHY_OFFLINE), 1, "a forged holy water USE: refused, purification offline only")
	check_eq(m.player.inventory.count_of(Purify.HOLY_WATER), 3, "none used")
	# The paladin's F (a pickup request) next to the ash: no channel in a session.
	m.player.request_channel()
	for i: int in 30:
		m.player.begin_tick()
		host.run_frame(m, NetProtocol.InputFrame.new(2 + i, Vector2i.ZERO))
	check_eq(m.player.channel_tick, 0, "no channel in a session (purify_on off)")
	check_eq(data.content_hash(), hash0, "the host's world unchanged")
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 0, "no edit")
