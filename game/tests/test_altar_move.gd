extends "res://tests/base_test.gd"
## M5b, placing and moving the altar (offline first): the rules (who picks it up from where, where it goes down and every
## reason it may not), the footprint read back from the world (WorldData.refresh_altar_rect), everything that follows it
## (the light and its textures, the safe zone, the altar's node, the side bands, the spawn slots and the reserved spots,
## the fields' light: old fields wither and stay, new ones grow; the arena's light rule and spawn tiles, a heretic waiting
## at the new light's edge), main.tscn offline (F held picks it up, a click puts it down, the ghost and the mark, no travel
## or tool use meanwhile, the dummies, a respawn waiting for it, the carrier going down), determinism and the world's
## records (edits on the wire, the snapshot) and a session (off until M5c).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0
const CLASSES: PackedStringArray = ["paladin", "miner", "archer", "cleric", "herbalist"]


func run() -> Array[String]:
	_check_pickup_rules()
	_check_place_rect()
	_check_place_rules()
	_check_refresh()
	await _check_world_follows()
	_check_fields_follow()
	_check_arena_follows()
	_check_determinism()
	await _check_main()
	await _check_session()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------

static func world() -> WorldData:
	return SurfaceGen.generate(Config.DEFAULT_SEED)


static func apply(data: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(data, e)


## Feet low in tile `c` (the feet tile is `c`).
static func feet_in(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


## Feet just south of the altar's footprint (its middle column): the tile north of them is an altar tile.
static func below_altar(data: WorldData) -> Vector2:
	return feet_in(Vector2i(data.altar_rect.position.x + 1, data.altar_rect.end.y))


## The seed-1 world with its altar picked up, and the footprint it had.
static func carried() -> Array:
	var data: WorldData = world()
	var was: Rect2i = data.altar_rect
	apply(data, AltarMove.pickup_edits(data))
	return [data, was]


## Open grass 13 tiles west of the old altar (found by the rules from there; the smoke uses the same spot).
static func west_rect(data: WorldData, was: Rect2i) -> Rect2i:
	return AltarMove.set_down_rect(data, (Vector2(was.position) + Vector2(-12, 1)) * Config.TILE)


static func centre_of(c: Vector2i) -> Vector2:
	return Vector2(c * 16) + Vector2(8, 8)


# --- picking it up ---------------------------------------------------------------------------------------------

func _check_pickup_rules() -> void:
	var data: WorldData = world()
	var feet: Vector2 = below_altar(data)
	var cell: Vector2i = Vector2i(data.altar_rect.position.x + 1, data.altar_rect.end.y - 1)
	for k: String in CLASSES:
		check_eq(AltarMove.pickup_refusal(data, k, feet, cell), "", "%s may pick the altar up (Config.ALTAR_MOVE_ANYONE)" % k)
	check_eq(AltarMove.pickup_refusal(data, "miner", feet, cell + Vector2i(0, -1)), WorldItems.WHY_REACH, "two tiles away")
	check_eq(AltarMove.pickup_refusal(data, "miner", feet, cell + Vector2i(0, 1)), WorldItems.WHY_REACH, "the feet tile")
	check_eq(AltarMove.pickup_refusal(data, "miner", feet_in(Vector2i(5, 5)), Vector2i(5, 4)), AltarMove.WHY_NO_ALTAR, "grass")
	check_eq(AltarMove.pickup_refusal(data, "miner", feet_in(Vector2i(0, 0)), Vector2i(-1, 0)), WorldItems.WHY_OUTSIDE, "off the map")
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check_eq(AltarMove.pickup_refusal(dun, "miner", feet, cell), AltarMove.WHY_SURFACE, "not in the dungeon")
	check(AltarMove.may_move("paladin") and AltarMove.may_move("herbalist"), "anyone")
	var edits: Array[EditLog.WorldEdit] = AltarMove.pickup_edits(data)
	check_eq(edits.size(), 9, "nine tile edits")
	var all_none: bool = true
	for e: EditLog.WorldEdit in edits:
		all_none = all_none and e.layer == WorldData.Layer.PLACEABLE and e.value == WorldData.PLACEABLE_NONE \
			and data.altar_rect.has_point(e.cell)
	check(all_none, "each clears an altar tile")
	apply(data, edits)
	check(not data.altar_rect.has_area() and data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_ALTAR) == 0,
		"picked up: no altar in the world")
	check_eq(SafeZone.for_world(data).radius, 0.0, "no safe zone")
	check(not SafeZone.for_world(data).is_in_safe_zone(Vector2(1016, 760)), "nothing is safe")
	check(Movement.side_bands(data).is_empty(), "no side bands")


func _check_place_rect() -> void:
	var feet: Vector2 = feet_in(Vector2i(40, 30))
	# Written out: the 3x3's near edge on the target tile, its centre two tiles from the feet tile.
	check_eq(AltarMove.place_rect(feet, Vector2i(41, 30)), Rect2i(41, 29, 3, 3), "east")
	check_eq(AltarMove.place_rect(feet, Vector2i(39, 30)), Rect2i(37, 29, 3, 3), "west")
	check_eq(AltarMove.place_rect(feet, Vector2i(40, 29)), Rect2i(39, 27, 3, 3), "north")
	check_eq(AltarMove.place_rect(feet, Vector2i(40, 31)), Rect2i(39, 31, 3, 3), "south")
	check_eq(AltarMove.place_rect(feet, Vector2i(41, 31)), Rect2i(41, 31, 3, 3), "south-east")
	check_eq(AltarMove.place_rect(feet, Vector2i(39, 29)), Rect2i(37, 27, 3, 3), "north-west")
	check_eq(AltarMove.place_rect(feet, Vector2i(40, 30)), Rect2i(), "the feet tile: none")
	check(not AltarMove.place_rect(feet, Vector2i(41, 30)).has_point(Aim.feet_cell(feet)), "never over the carrier's feet tile")
	check_eq(AltarMove.centre_px(Rect2i(41, 29, 3, 3)), Vector2(42.5 * 16, 30.5 * 16), "its centre")


func _check_place_rules() -> void:
	var pair: Array = carried()
	var data: WorldData = pair[0]
	var was: Rect2i = pair[1]
	check_eq(AltarMove.place_refusal(data, was), "", "back on its old place")
	var r: Rect2i = west_rect(data, was)
	if not check(r.has_area(), "open grass west of the old place"):
		return
	check_eq(AltarMove.place_refusal(data, r), "", "open grass")
	# Not open: a placeable (a torch), a drop. Growing: a gatherable, a crop, wet soil.
	var t: Vector2i = r.position + Vector2i(1, 1)
	data.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_TORCH)
	check_eq(AltarMove.place_refusal(data, r), AltarMove.WHY_NOT_OPEN, "a torch under it")
	data.set_value(WorldData.Layer.PLACEABLE, t, 0)
	data.drops[77] = WorldData.Drop.new(77, &"stone_a", 1, 0, t * 16 + Vector2i(8, 8))
	check_eq(AltarMove.place_refusal(data, r), AltarMove.WHY_NOT_OPEN, "a drop under it")
	data.drops.erase(77)
	for v: int in [1, Farming.Field.new(Farming.KIND_BUFF, 1).value(), Farming.Field.new(Farming.KIND_NONE, 0, true).value()]:
		data.set_value(WorldData.Layer.VEGETATION, t, v)
		check_eq(AltarMove.place_refusal(data, r), AltarMove.WHY_GROWING, "something grows there (vegetation %d)" % v)
	data.set_value(WorldData.Layer.VEGETATION, t, 0)
	check_eq(AltarMove.place_refusal(data, r), "", "clear again")
	# Dry tilled soil is ground (allowed).
	data.set_terrain(t, Terrain.SOIL)
	check_eq(AltarMove.place_refusal(data, r), "", "dry bare soil is open ground")
	data.set_terrain(t, Terrain.GRASS)
	# Corrupted: a 3x3 inside a zone with nothing lying on it.
	var deep: Rect2i = Rect2i()
	for i: int in data.layers[WorldData.Layer.CORRUPTION].size():
		var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		var rr: Rect2i = Rect2i(c - Vector2i.ONE, Vector2i(3, 3))
		var ok: bool = Rect2i(Vector2i.ZERO, data.size).encloses(rr)
		for y: int in range(rr.position.y, rr.end.y):
			for x: int in range(rr.position.x, rr.end.x):
				ok = ok and data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0 \
					and data.get_value(WorldData.Layer.VEGETATION, Vector2i(x, y)) == 0
		if ok:
			deep = rr
			break
	if check(deep.has_area(), "a 3x3 of bare ash"):
		check_eq(AltarMove.place_refusal(data, deep), AltarMove.WHY_CORRUPTED, "on corruption")
	# Over the entrance (a placeable), over its arrival point (where players appear).
	var ent: Rect2i = SurfaceGen.entrance_rect(data)
	check_eq(AltarMove.place_refusal(data, Rect2i(ent.position, Vector2i(3, 3))), AltarMove.WHY_NOT_OPEN, "over the entrance")
	var under: Rect2i = Rect2i(ent.position + Vector2i(-1, 1), Vector2i(3, 3))
	check_eq(AltarMove.place_refusal(data, under), WorldItems.WHY_RESERVED, "over the entrance's arrival point")
	# Bodies: a player's feet under it (any of them, the carrier too); just outside is fine.
	var inside: Vector2 = AltarMove.centre_px(r)
	var outside: Vector2 = Vector2(r.position.x * 16 - 6, inside.y)
	check_eq(AltarMove.place_refusal(data, r, [inside] as Array[Vector2]), WorldItems.WHY_BODY, "someone's feet under it")
	check_eq(AltarMove.place_refusal(data, r, [outside] as Array[Vector2]), "", "feet beside it")
	# The spawn slots: a table on slot 0, a rect whose slots leave the map.
	var slot0: Vector2i = Aim.feet_cell(AltarMove.slot_feet(r)[0])
	data.put_placeable(Rect2i(slot0 - Vector2i(1, 0), Vector2i(3, 1)), WorldData.PLACEABLE_ALCHEMY)
	check_eq(AltarMove.place_refusal(data, r), AltarMove.WHY_SLOTS, "a table where a spawn slot is")
	data.put_placeable(Rect2i(slot0 - Vector2i(1, 0), Vector2i(3, 1)), WorldData.PLACEABLE_NONE)
	var edge: Rect2i = Rect2i(Vector2i(2, 40), Vector2i(3, 3))
	var edge_ok: bool = true
	for y2: int in range(40, 43):
		for x2: int in range(2, 5):
			edge_ok = edge_ok and data.terrain_at(Vector2i(x2, y2)) == Terrain.GRASS and data.get_value(WorldData.Layer.VEGETATION, Vector2i(x2, y2)) == 0
	if edge_ok:
		check_eq(AltarMove.place_refusal(data, edge), AltarMove.WHY_SLOTS, "by the map's edge: slots off the map")
	check_eq(AltarMove.place_refusal(data, Rect2i(Vector2i(-1, 40), Vector2i(3, 3))), WorldItems.WHY_OUTSIDE, "off the map")
	check_eq(AltarMove.place_refusal(data, Rect2i()), WorldItems.WHY_OUTSIDE, "no footprint")
	# A live heretic in its new light: refused; just outside the light: fine.
	var c0: Vector2 = AltarMove.centre_px(r)
	var radius: float = Config.safe_radius_px()
	var none: Array[Vector2] = []
	check_eq(AltarMove.place_refusal(data, r, none, [c0 + Vector2(radius - 8.0, 0)] as Array[Vector2]), AltarMove.WHY_HERETIC,
		"a heretic in the light it would give")
	check_eq(AltarMove.place_refusal(data, r, none, [c0 + Vector2(radius + 8.0, 0)] as Array[Vector2]), "", "a heretic just outside it")
	# The dungeon: never.
	check_eq(AltarMove.place_refusal(DungeonGen.generate(Config.DEFAULT_SEED), Rect2i(10, 10, 3, 3)), AltarMove.WHY_SURFACE,
		"not in the dungeon")
	# set_down_rect: the nearest allowed footprint (written out: no allowed one closer in Chebyshev rings).
	var hint: Vector2 = feet_in(r.position + Vector2i(1, 5))
	var got: Rect2i = AltarMove.set_down_rect(data, hint)
	var f: Vector2i = Aim.feet_cell(hint)
	var got_d: int = maxi(absi(got.get_center().x - f.x), absi(got.get_center().y - f.y))
	var closer: int = 0
	for d: int in got_d:
		for y3: int in range(f.y - d, f.y + d + 1):
			for x3: int in range(f.x - d, f.x + d + 1):
				if AltarMove.place_refusal(data, Rect2i(Vector2i(x3, y3) - Vector2i.ONE, Vector2i(3, 3))).is_empty():
					closer += 1
	check(got.has_area() and closer == 0 and AltarMove.place_refusal(data, got).is_empty(),
		"set down at the nearest allowed place (%d rings out)" % got_d)


func _check_refresh() -> void:
	var pair: Array = carried()
	var data: WorldData = pair[0]
	var was: Rect2i = pair[1]
	var r: Rect2i = west_rect(data, was)
	var edits: Array[EditLog.WorldEdit] = AltarMove.place_edits(r)
	check_eq(edits.size(), 9, "nine tile edits put it down")
	for i: int in edits.size():
		EditLog.apply_to_data(data, edits[i])
		if i < 8:
			check(not data.altar_rect.has_area(), "half way (%d of 9): no altar yet" % (i + 1))
	check_eq(data.altar_rect, r, "the ninth: the altar is there")
	check_eq(data.altar_center_px(), AltarMove.centre_px(r), "its centre")
	check(not data.refresh_altar_rect(), "refresh again: unchanged")
	data.set_value(WorldData.Layer.PLACEABLE, r.position, WorldData.PLACEABLE_NONE)
	check(data.refresh_altar_rect() and not data.altar_rect.has_area(), "a tile missing: no altar")


# --- the world's view follows ------------------------------------------------------------------------------------

func _check_world_follows() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var data: WorldData = w.data
	var was: Rect2i = data.altar_rect
	var old_centre: Vector2 = data.altar_center_px()
	var moved: Array[int] = [0]
	w.altar_moved.connect(func() -> void: moved[0] += 1)
	var tex_count: int = AltarLight.cached_texture_count()
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		w.apply_edit(e)
	check_eq(moved[0], 1, "altar_moved once when the footprint left")
	check(w.altar == null and w.safe_zone.radius == 0.0 and not w.is_in_safe_zone(old_centre), "no altar, no safe zone")
	check(not w.lighting.altar_light.ground_light.enabled and not w.lighting.altar_light.actor_light.enabled, "no light")
	var r: Rect2i = west_rect(data, was)
	var t0: int = Time.get_ticks_usec()
	for e2: EditLog.WorldEdit in AltarMove.place_edits(r):
		w.apply_edit(e2)
	note("put down at a new place (nine edits, the altar's node, two new light textures): %.1f ms" % [
		(Time.get_ticks_usec() - t0) / 1000.0])
	check_eq(moved[0], 2, "and once when it came down")
	var centre: Vector2 = AltarMove.centre_px(r)
	check(w.altar != null and w.altar.footprint_px == Rect2i(r.position * 16, r.size * 16), "the altar's node on the new footprint")
	check_eq(w.altar.position, Vector2(r.position.x * 16 + 24, r.end.y * 16), "at its bottom centre (y-sort)")
	check(w.is_in_safe_zone(centre) and not w.is_in_safe_zone(old_centre), "the safe zone moved")
	var light: AltarLight = w.lighting.altar_light
	check(light.position == centre and light.ground_light.enabled and light.actor_light.enabled, "the light at the new centre, on")
	check(light.ground_light.texture == AltarLight.texture_for(w.safe_zone, LightGen.Edge.DITHER, Config.SAFE_EDGE_BAND_PX)
		and light.actor_light.texture == AltarLight.texture_for(w.safe_zone, LightGen.Edge.HARD, 0), "its textures for the new zone")
	check_eq(AltarLight.cached_texture_count(), tex_count + 2, "a new place: two new cached textures")
	for i: int in Config.SPAWN_SLOTS.size():
		if w.spawn_point(i) != centre + Vector2(Config.SPAWN_SLOTS[i]):
			fail("spawn slot %d did not follow" % i)
	checks += 1
	var want_res: Array[Vector2] = [DungeonGen.arrival_below(SurfaceGen.entrance_rect(data))]
	want_res.append_array(AltarMove.slot_feet(r))
	check_eq(WorldItems.reserved_feet(data), want_res, "the reserved spots: the arrival point and the new spawn slots")
	var bands: Array[Rect2] = Movement.side_bands(data)
	check(bands.size() == 2 and bands[0].end.x == r.position.x * 16 and bands[1].position.x == r.end.x * 16, "the side bands moved")
	check(Movement.can_stand(data, old_centre) and not Movement.can_stand(data, centre), "walking: the old place free, the new blocked")
	var walker: Vector2 = Vector2(centre.x, r.end.y * 16 + 20)
	for t: int in 60:
		walker = Movement.step(data, walker, Vector2i(0, -1), TICK)
	check_eq(walker.y, float(r.end.y * 16) + Config.FEET_HEIGHT, "a player walking north stops flush at its south face")
	# The evening off: putting it down keeps the light off; back on, on.
	w.lighting.set_evening(false)
	for e3: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		w.apply_edit(e3)
	for e4: EditLog.WorldEdit in AltarMove.place_edits(was):
		w.apply_edit(e4)
	check(not light.ground_light.enabled, "back home with the evening off: the light stays off")
	w.lighting.set_evening(true)
	check(light.ground_light.enabled and light.position == old_centre, "evening on: lit at home")
	check_eq(AltarLight.cached_texture_count(), tex_count + 2, "home again: its old textures, none new")
	check_eq(w.ground.verify()["mismatches"], 0, "the ground untouched")


func _check_fields_follow() -> void:
	var data: WorldData = world()
	var farm: Farm = Farm.new(data)
	# Crops on the M1 soil (lit), then the altar goes far west: they wither and stay; a new field there grows.
	var soil: Array[Vector2i] = []
	for i: int in data.layers[WorldData.Layer.FLOOR].size():
		var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.terrain_at(c) == Terrain.SOIL:
			soil.append(c)
	for c2: Vector2i in soil.slice(0, 4):
		data.set_value(WorldData.Layer.VEGETATION, c2, Farming.Field.new(Farming.KIND_HEALING, 1, true).value())
		farm.sync_cell(c2)
	apply(data, farm.step())
	check(not Farming.field_at(data, soil[0]).withered, "lit: growing")
	var was: Rect2i = data.altar_rect
	apply(data, AltarMove.pickup_edits(data))
	apply(data, farm.step())
	var all_withered: bool = true
	for c3: Vector2i in soil.slice(0, 4):
		all_withered = all_withered and Farming.field_at(data, c3).withered
	check(all_withered, "carried away (no light): they wither the next tick")
	var r: Rect2i = west_rect(data, was)
	apply(data, AltarMove.place_edits(r))
	apply(data, farm.step())
	var still: bool = true
	for c4: Vector2i in soil.slice(0, 4):
		var f: Farming.Field = Farming.field_at(data, c4)
		still = still and f.withered and data.terrain_at(c4) == Terrain.SOIL and f.kind == Farming.KIND_HEALING
	check(still, "put down far away: still withered, the fields stay (● §9.7)")
	# A new field in the new light grows.
	var g: Vector2i = Vector2i(-1, -1)
	for y: int in range(r.position.y - 6, r.end.y + 6):
		for x: int in range(r.position.x - 6, r.end.x + 6):
			var t: Vector2i = Vector2i(x, y)
			if g.x < 0 and Farming.till_refusal(data, feet_in(t + Vector2i(0, 1)), t).is_empty():
				g = t
	if check(g.x >= 0, "a tillable tile in the new light"):
		apply(data, farm.till(feet_in(g + Vector2i(0, 1)), g).edits)
		var inv: Inventory = Inventory.new()
		inv.add(&"seed_buff", 1)
		apply(data, farm.plant(feet_in(g + Vector2i(0, 1)), "miner", inv, 0, g).edits)
		apply(data, farm.water(feet_in(g + Vector2i(0, 1)), g).edits)
		for i2: int in 10:
			apply(data, farm.step())
		var nf: Farming.Field = Farming.field_at(data, g)
		check(nf != null and nf.kind == Farming.KIND_BUFF and not nf.withered and farm.plots[data.index_of(g)].progress == 10,
			"the new field grows")
		var walkway: Vector2i = Vector2i(was.position.x + 1, was.end.y)
		check_eq(Farming.till_refusal(data, feet_in(walkway + Vector2i(0, 1)), walkway), Farming.WHY_DARK,
			"the grass by the old place is outside the light now")
	# Back home: the old ones revive.
	apply(data, AltarMove.pickup_edits(data))
	apply(data, AltarMove.place_edits(was))
	apply(data, farm.step())
	var revived: bool = true
	for c5: Vector2i in soil.slice(0, 4):
		revived = revived and not Farming.field_at(data, c5).withered
	check(revived, "the altar back: the old fields revive")


# --- the arena follows ---------------------------------------------------------------------------------------------

func _check_arena_follows() -> void:
	var data: WorldData = world()
	var arena: Arena = Arena.new()
	arena.setup(data, Config.DEFAULT_SEED)
	var old_centre: Vector2 = data.altar_center_px()
	check(arena.in_light(old_centre), "the light at home")
	var was: Rect2i = data.altar_rect
	apply(data, AltarMove.pickup_edits(data))
	check(arena.sync_world() and not arena.in_light(old_centre), "carried: no light for the heretics")
	var nobody: Array[Player] = []
	check(arena.spawn_ok(Arena.spawn_feet(Vector2i(was.position.x + 1, was.end.y + 2)), nobody), "nothing stops a spawn by the old place")
	# Put it down by a zone's edge so its light covers part of the zone's spawn ring.
	var near: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.CORRUPTION].size():
		var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.get_value(WorldData.Layer.CORRUPTION, c) != 0 and data.terrain_at(c + Vector2i(0, 1)) == Terrain.GRASS:
			near = c
			break
	var carried_cells: int = arena.spawn_cells.size()
	var r: Rect2i = AltarMove.set_down_rect(data, feet_in(near + Vector2i(0, 4)))
	if not check(r.has_area(), "a place by the zone"):
		return
	apply(data, AltarMove.place_edits(r))
	arena.sync_world()
	var zone: SafeZone = SafeZone.for_world(data)
	var lit_spawn: int = 0
	for c2: Vector2i in arena.spawn_cells:
		if not Combat.box_outside_light(data, zone, Arena.spawn_feet(c2)):
			lit_spawn += 1
	check_eq(lit_spawn, 0, "no spawn tile in the new light")
	check(arena.spawn_cells.size() < carried_cells, "the new light took spawn tiles (%d -> %d)" % [carried_cells, arena.spawn_cells.size()])
	check(not arena.spawn_ok(zone.center + Vector2(0, 40), nobody), "no spawn in the new light")
	# A heretic chasing a player into the new light waits at its edge and never enters.
	var p: Player = Player.new()
	p.setup(data, "archer", zone.center + Vector2(zone.radius - 12.0, 0))
	var h: HereticSim = arena.spawn_heretic(zone.center + Vector2(zone.radius + 40.0, 0))
	h.has_target = true
	h.target_id = p.get_instance_id()
	var ps: Array[Player] = [p]
	arena.spawning = false
	var entered: int = 0
	var waited: bool = false
	for t: int in 300:
		arena.step(ps)
		if not Combat.box_outside_light(data, zone, h.pos):
			entered += 1
		waited = waited or h.state == HereticSim.State.EDGE
	check_eq(entered, 0, "the heretic never stepped into the new light")
	check(waited, "it waited at the edge")
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "the player in the new light was not hit")
	p.free()


# --- determinism and the world's records --------------------------------------------------------------------------

static func moved_twice() -> String:
	var data: WorldData = world()
	var was: Rect2i = data.altar_rect
	apply(data, AltarMove.pickup_edits(data))
	var r: Rect2i = west_rect(data, was)
	apply(data, AltarMove.place_edits(r))
	apply(data, AltarMove.pickup_edits(data))
	var r2: Rect2i = AltarMove.set_down_rect(data, feet_in(r.position + Vector2i(1, 12)))
	apply(data, AltarMove.place_edits(r2))
	return "%s %s" % [data.content_hash(), data.altar_rect]


func _check_determinism() -> void:
	check_eq(moved_twice(), moved_twice(), "the same moves twice: the same world and altar")
	var data: WorldData = world()
	var copy: WorldData = world()
	var was: Rect2i = data.altar_rect
	var edits: Array[EditLog.WorldEdit] = AltarMove.pickup_edits(data)
	apply(data, edits)
	edits.append_array(AltarMove.place_edits(west_rect(data, was)))
	apply(data, AltarMove.place_edits(west_rect(data, was)))
	for i: int in edits.size():
		var back: Array = EditLog.decode_one(EditLog.encode_one(edits[i], i))
		var e: EditLog.WorldEdit = back[1]
		if e != null:
			EditLog.apply_to_data(copy, e)
	check(copy.altar_rect == data.altar_rect and copy.content_hash() == data.content_hash(),
		"the moves as edits on the wire: the same altar and world")
	var recv: WorldData = WorldSnapshot.decode_raw(WorldSnapshot.raw_bytes(data))
	check(recv != null and recv.altar_rect == data.altar_rect and recv.content_hash() == data.content_hash(),
		"the snapshot carries the moved altar")
	check(data.content_hash() != world().content_hash(), "and the world differs from the generated one")


# --- main.tscn offline -------------------------------------------------------------------------------------------

func _tick(main: Main, p: Player, mouse: Vector2, n: int, press: bool, hold: bool = false, dir: Vector2i = Vector2i.ZERO) -> void:
	for i: int in n:
		p.begin_tick()
		p.tick_controls(dir, mouse, true, press and i == 0, false, TICK, false, hold)
		main.step_altar_hold(p)
		main.step_farms()


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn("paladin")
	var p: Player = main.player
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	var data: WorldData = main.world.data
	var was: Rect2i = data.altar_rect
	p.teleport(below_altar(data))
	var at: Vector2 = centre_of(Vector2i(was.position.x + 1, was.end.y - 1))
	# F held: not yet before its time, a let-go starts over.
	_tick(main, p, at, Config.ALTAR_PICKUP_HOLD_TICKS - 1, false, true)
	check(data.altar_rect == was and p.altar_hold_ticks == Config.ALTAR_PICKUP_HOLD_TICKS - 1, "held a tick short: still there")
	_tick(main, p, at, 1, false, false)
	check_eq(p.altar_hold_ticks, 0, "let go: the count starts over")
	_tick(main, p, at, Config.ALTAR_PICKUP_HOLD_TICKS - 1, false, true)
	check(data.altar_rect.has_area(), "still there")
	_tick(main, p, at, 1, false, true)
	check(not data.altar_rect.has_area() and p.carrying_altar, "held long enough: picked up, carried")
	check(main.world.altar == null and not main.world.lighting.altar_light.ground_light.enabled, "no altar node, no light")
	check(p.altar_mark.visible, "the carried altar shows over the head")
	var ghost: AltarGhost = main.ghost
	check(ghost.visible and ghost.rect == AltarMove.place_rect(p.sim_position, p.aim_cell), "the ghost shows where it would go")
	# Meanwhile: the click is the altar's (no tool), no channel, no travel.
	p.inventory.select(Config.START_WEAPON_SLOT)
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, at, true, true, true)
	check(f.altar_place and f.op == NetProtocol.Op.NONE and f.anim < 0, "a click while carrying: put down, no sword swing")
	var ent: Rect2i = SurfaceGen.entrance_rect(data)
	p.teleport(DungeonGen.arrival_below(ent))
	_tick(main, p, centre_of(ent.position), 1, false)
	main.pick_up()
	check_eq(main.current_map, Config.MAP_SURFACE, "no travel while carrying")
	# A respawn waits for it: an ally dead and due.
	var ally: Player = main.add_ally("archer", false)
	ally.vitals.life = Vitals.Life.DEAD
	ally.vitals.life_ticks = Config.RESPAWN_TICKS
	main.step_combat(TICK)
	check(ally.vitals.life == Vitals.Life.DEAD, "no altar: the ally's respawn waits")
	# Refused: aimed into a zone.
	var a: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.CORRUPTION].size():
		var c: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.get_value(WorldData.Layer.CORRUPTION, c) != 0 and data.get_value(WorldData.Layer.CORRUPTION, c + Vector2i(0, -1)) != 0 \
				and data.terrain_at(c + Vector2i(0, 1)) == Terrain.GRASS:
			a = c
			break
	p.teleport(feet_in(a + Vector2i(0, 1)))
	_tick(main, p, centre_of(a), 1, true)
	check(p.carrying_altar and not data.altar_rect.has_area(), "aimed into the ash: refused, still carried")
	check(ghost.visible and not ghost.allowed, "the ghost says no")
	# The paladin's F next to the ash while carrying: no channel.
	main.pick_up()
	_tick(main, p, centre_of(a), 2, false)
	check_eq(p.channel_tick, 0, "no channel while carrying")
	# Put down west: the light, the dummies, the ally's respawn follow.
	var r: Rect2i = west_rect(data, was)
	var stand: Vector2i = Vector2i(r.position.x + 1, r.end.y)
	p.teleport(feet_in(stand))
	_tick(main, p, centre_of(stand + Vector2i(0, -1)), 1, true)
	check(data.altar_rect == r and not p.carrying_altar and not p.altar_mark.visible, "a click put it down there")
	check(not ghost.visible, "the ghost is gone")
	check(main.world.altar != null and main.world.lighting.altar_light.position == AltarMove.centre_px(r), "its node and light there")
	check_eq(main.altar_moves, 1, "one move")
	var dummies_ok: int = 0
	for d: Character in main.dummies:
		for s: int in range(1, Config.SPAWN_SLOTS.size()):
			if d.position == main.world.spawn_point(s):
				dummies_ok += 1
	check_eq(dummies_ok, main.dummies.size(), "the dummies stand on the new spawn slots")
	main.step_combat(TICK)
	check(ally.vitals.alive() and ally.sim_position == main.world.spawn_point(1), "the waiting ally respawned at the new altar")
	check(main.arenas[Config.MAP_SURFACE].in_light(AltarMove.centre_px(r)), "the arena's light follows")
	# The local player dies and respawns at the new altar.
	p.take_hit(Config.PLAYER_HP_MAX)
	p.vitals.life = Vitals.Life.DEAD
	p.vitals.life_ticks = Config.RESPAWN_TICKS
	_tick(main, p, at, 1, false)
	check(p.vitals.alive() and p.sim_position == main.world.spawn_point(0), "respawn at the new altar's slot 0")
	# The carrier going down sets it down nearby.
	p.teleport(feet_in(Vector2i(r.position.x + 1, r.end.y)))
	_tick(main, p, centre_of(Vector2i(r.position.x + 1, r.end.y - 1)), Config.ALTAR_PICKUP_HOLD_TICKS, false, true)
	check(p.carrying_altar, "picked up again")
	var feet_cell: Vector2i = Aim.feet_cell(p.sim_position)
	p.teleport(feet_in(feet_cell + Vector2i(0, 6)))
	p.take_hit(Config.PLAYER_HP_MAX)
	var down_rect: Rect2i = data.altar_rect
	check(down_rect.has_area() and not p.carrying_altar, "down: the altar came down")
	var dc: Vector2i = Aim.feet_cell(p.sim_position)
	check(maxi(absi(down_rect.get_center().x - dc.x), absi(down_rect.get_center().y - dc.y)) <= 3, "near the carrier (%s)" % down_rect)
	check(not Rect2(Vector2(down_rect.position * 16), Vector2(down_rect.size * 16)).intersects(Movement.feet_box(p.sim_position)),
		"not on the carrier")
	check_eq(main.altar_moves, 2, "two moves")


# --- a session: off until M5c ------------------------------------------------------------------------------------------

func _check_session() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"AltarTestNet"
	add_node(s)
	s.world = w
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var data: WorldData = w.data
	var was: Rect2i = data.altar_rect
	var m: NetMember = s.add_member(2, 7, "paladin", below_altar(data), RigData.Dir.NORTH)
	m.gate = InputGate.new()
	for i: int in Config.ALTAR_PICKUP_HOLD_TICKS + 20:
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1 + i, Vector2i.ZERO)
		f.interact = true
		f.look = RigData.Dir.NORTH
		m.player.begin_tick()
		host.run_frame(m, f)
	check(data.altar_rect == was and not m.player.carrying_altar, "F held at the altar in a session: it stays (off until M5c)")
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 0, "no edit")
