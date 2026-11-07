extends "res://tests/base_test.gd"
## M11b, the rare zone (game-concept §12 "컬렉션은 아처 구역 1개"; every number PROVISIONAL, README "임시값" M11b): exactly one disc, from the seed
## (the same seed the same zone, seeds differ), on open land, far from the altar, clear of the corruption and the map's edge, written out
## here rule by rule over many seeds and one refusal at a time; no tile changes (the golden hash stays); the last-resort walk over the map;
## the rare kinds spawn only inside it, respawn inside it and never leave it, whatever chases, pushes or lights them; the picture (the
## tint, the boundary stones) on the view only; main.tscn.

const SEEDS: int = 32
const RARE: Array[StringName] = [&"lamp_fox", &"silver_stag", &"ash_owl"]
const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_table()
	_check_placement()
	_check_site_refusals()
	_check_last_resort()
	_check_geometry()
	_check_spawns()
	_check_stays_inside()
	_check_light_on_zone()
	_check_test_creatures()
	_check_view()
	await _check_main()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func open_world(size: Vector2i = Vector2i(100, 60)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_SURFACE
	return d


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


## The rare creature of `kind` of herd `h`, or null.
static func rare_of(h: Creatures, kind: StringName) -> CreatureSim:
	for c: CreatureSim in h.list:
		if c.kind == kind:
			return c
	return null


func _check_table() -> void:
	check_eq(Config.RARE_ZONE_RADIUS_TILES, 9, "radius 9 (the design's 8-10)")
	check(Config.RARE_ZONE_RADIUS_TILES > Config.SAFE_RADIUS_TILES, "an altar's light never covers the whole zone")
	check_eq(Config.RARE_ZONE_MIN_ALTAR_TILES, 30, "30 tiles from the altar")
	check_eq(Config.RARE_ZONE_MIN_OPEN_PCT, 85, "85 percent open")


# --- where it goes -------------------------------------------------------------------------------------

func _check_placement() -> void:
	var sites: Dictionary[Vector2i, bool] = {}
	for s: int in SEEDS:
		var seed_id: int = s + 1
		var d: WorldData = SurfaceGen.generate(seed_id)
		var before: String = d.content_hash()
		var z: RareZone = RareZone.place(d, seed_id)
		if not check(z != null, "seed %d: a zone" % seed_id):
			continue
		sites[z.center] = true
		check_eq(d.content_hash(), before, "seed %d: placing it changes nothing in the world" % seed_id)
		check_eq(RareZone.place(d, seed_id).center, z.center, "seed %d: the same world, the same zone" % seed_id)
		check_eq(z.radius, Config.RARE_ZONE_RADIUS_TILES, "seed %d: its radius" % seed_id)
		var far: float = z.center_px().distance_to(d.altar_center_px())
		check(far >= Config.RARE_ZONE_MIN_ALTAR_TILES * Config.TILE, "seed %d: %.0f px from the altar" % [seed_id, far])
		var tiles: Array[Vector2i] = z.tiles()
		var open: int = 0
		for t: Vector2i in tiles:
			check(t.x >= 2 and t.y >= 2 and t.x < d.size.x - 2 and t.y < d.size.y - 2, "seed %d: %s two tiles inside the map" % [seed_id, t])
			if d.terrain_at(t) == Terrain.GRASS and not Movement.is_blocked(d, t):
				open += 1
		check(open * 100 >= tiles.size() * 85, "seed %d: %d of %d tiles open" % [seed_id, open, tiles.size()])
		var ash: int = 0
		var reach: int = z.radius + 3
		for y: int in range(z.center.y - reach, z.center.y + reach + 1):
			for x: int in range(z.center.x - reach, z.center.x + reach + 1):
				if d.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
					ash += 1
		check_eq(ash, 0, "seed %d: no corruption in or near it" % seed_id)
	check(sites.size() >= SEEDS / 2, "the seeds choose different places (%d of %d)" % [sites.size(), SEEDS])
	# Regenerated, the same (not a state of one data object).
	check_eq(RareZone.place(SurfaceGen.generate(5), 5).center, RareZone.place(SurfaceGen.generate(5), 5).center, "a seed's zone repeats")
	var one: WorldData = SurfaceGen.generate(1)
	check_ne(RareZone.place(one, 1).center, RareZone.place(one, 2).center, "the seed picks: one map, two seeds, two places")
	# A minute of the herd, rare creatures and all: the generated world's golden hash stays.
	var gold: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var herd: Creatures = Creatures.new()
	herd.setup(gold, Config.DEFAULT_SEED)
	for t: int in 3600:
		herd.step([] as Array[Player])
	gold.rare_zone = null  # M11c: the hash covers the zone; no tile or drop changed
	check_eq(gold.content_hash(), SurfaceGen.GOLDEN_HASH, "a minute later the world's hash is the golden one")
	note("rare zone: %d different sites in %d seeds" % [sites.size(), SEEDS])


## One rule at a time on an open map with an altar: each site just allowed and just refused.
func _check_site_refusals() -> void:
	var r: int = Config.RARE_ZONE_RADIUS_TILES
	var d: WorldData = open_world()
	d.altar_rect = Rect2i(38, 28, 3, 3)
	check(RareZone.site_ok(d, Vector2i(69, 29), r), "30 tiles east of the altar's middle: allowed")
	check(not RareZone.site_ok(d, Vector2i(68, 29), r), "29 tiles: too near")
	var bare: WorldData = open_world()
	check(RareZone.site_ok(bare, Vector2i(11, 30), r), "11 tiles from the west edge (radius + 2)")
	check(not RareZone.site_ok(bare, Vector2i(10, 30), r), "10: too near the edge")
	check(RareZone.site_ok(bare, Vector2i(bare.size.x - 12, 30), r), "the east edge's last")
	check(not RareZone.site_ok(bare, Vector2i(bare.size.x - 11, 30), r), "the east edge's next")
	check(RareZone.site_ok(bare, Vector2i(50, 11), r), "the north edge's last")
	check(not RareZone.site_ok(bare, Vector2i(50, 10), r), "the north edge's next")
	check(RareZone.site_ok(bare, Vector2i(50, bare.size.y - 12), r), "the south edge's last")
	check(not RareZone.site_ok(bare, Vector2i(50, bare.size.y - 11), r), "the south edge's next")
	# Corruption: in the square around the disc grown by 3.
	var ash: WorldData = open_world()
	ash.set_value(WorldData.Layer.CORRUPTION, Vector2i(50 + r + 4, 30), 1)
	check(RareZone.site_ok(ash, Vector2i(50, 30), r), "corruption 4 tiles past the rim: allowed")
	ash.set_value(WorldData.Layer.CORRUPTION, Vector2i(50 + r + 3, 30), 1)
	check(not RareZone.site_ok(ash, Vector2i(50, 30), r), "3 tiles past the rim: refused")
	# Open land: exactly the percent, then a tile less.
	var open: WorldData = open_world()
	var z: RareZone = RareZone.new(Vector2i(50, 30), r)
	var tiles: Array[Vector2i] = z.tiles()
	var may_block: int = tiles.size() - ceili(tiles.size() * 0.85)
	for i: int in may_block:
		open.set_value(WorldData.Layer.PLACEABLE, tiles[i], WorldData.PLACEABLE_TREE)
	check(RareZone.site_ok(open, z.center, r), "%d of %d tiles blocked: still open enough" % [may_block, tiles.size()])
	open.set_value(WorldData.Layer.PLACEABLE, tiles[may_block], WorldData.PLACEABLE_TREE)
	check(not RareZone.site_ok(open, z.center, r), "one more: refused")
	var soil: WorldData = open_world()
	for i2: int in may_block + 1:
		soil.set_value(WorldData.Layer.FLOOR, tiles[i2], Terrain.SOIL)
	check(not RareZone.site_ok(soil, z.center, r), "soil is no open land")
	# No zone at all.
	var cave: WorldData = open_world()
	cave.map_id = Config.MAP_DUNGEON
	check(not RareZone.site_ok(cave, Vector2i(50, 30), r), "not on the dungeon")
	check_eq(RareZone.place(cave, 1), null, "the dungeon has none")
	check_eq(RareZone.place(open_world(Vector2i(20, 20)), 1), null, "a map too small has none")
	check_eq(RareZone.place(null, 1), null, "no map, no zone")


## One site on the whole map: the random tries nearly always miss it, the walk over the map finds it.
func _check_last_resort() -> void:
	var d: WorldData = open_world(Vector2i(60, 40))
	var keep: int = Config.RARE_ZONE_RADIUS_TILES + Config.RARE_ZONE_ASH_CLEARANCE_TILES
	for y: int in d.size.y:
		for x: int in d.size.x:
			if absi(x - 30) > keep or absi(y - 20) > keep:
				d.set_value(WorldData.Layer.CORRUPTION, Vector2i(x, y), 1)
	for s: int in 12:
		var z: RareZone = RareZone.place(d, s + 1)
		if check(z != null, "seed %d: the one site is found" % (s + 1)):
			check_eq(z.center, Vector2i(30, 20), "seed %d: and it is that one" % (s + 1))


func _check_geometry() -> void:
	var z: RareZone = RareZone.new(Vector2i(30, 20), 9)
	check_eq(z.center_px(), Vector2(488, 328), "the middle tile's centre")
	check_eq(z.radius_px(), 144.0, "9 tiles in px")
	var mid: Vector2 = z.center_px()
	for p: Vector2 in [mid, mid + Vector2(120, 0), mid + Vector2(0, -139), mid + Vector2(138, 2), mid + Vector2(139, 2), mid + Vector2(-139, 2),
			mid + Vector2(-100, 100), mid + Vector2(100, 103), mid + Vector2(160, 0)]:
		var box: Rect2 = Movement.feet_box(p)
		var inside: bool = true
		var inside16: bool = true
		for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
			inside = inside and corner.distance_to(mid) <= 144.0
			inside16 = inside16 and corner.distance_to(mid) <= 128.0
		check_eq(z.holds(p), inside, "holds %s" % p)
		check_eq(z.holds(p, 16.0), inside16, "holds %s inset" % p)
	check(z.has_tile(z.center) and z.has_tile(Vector2i(39, 20)) and z.has_tile(Vector2i(21, 20)), "the row's ends")
	check(not z.has_tile(Vector2i(40, 20)) and not z.has_tile(Vector2i(39, 29)), "past the rim, the bounding square's corner")
	var tiles: Array[Vector2i] = z.tiles()
	check_between(tiles.size(), 240, 270, "about pi r^2 tiles")
	for t: Vector2i in tiles:
		check(z.has_tile(t), "%s in" % t)
	check_eq(z.describe(), "30,20/9", "the log's form")


# --- who lives there ------------------------------------------------------------------------------------

func _check_spawns() -> void:
	for s: int in 8:
		var seed_id: int = s + 1
		var d: WorldData = SurfaceGen.generate(seed_id)
		var h: Creatures = Creatures.new()
		h.setup(d, seed_id)
		if not check(d.rare_zone != null, "seed %d: the herd placed the zone" % seed_id):
			continue
		check_eq(d.rare_zone.center, RareZone.place(d, seed_id).center, "seed %d: the zone of the seed" % seed_id)
		for kind: StringName in RARE:
			check_eq(h.alive_count(kind), 1, "seed %d: one %s (its cap)" % [seed_id, kind])
			check(h.spawns_now(kind), "%s spawns" % kind)
			var c: CreatureSim = rare_of(h, kind)
			if c == null:
				continue
			check(c.bound, "seed %d: %s is bound to the zone" % [seed_id, kind])
			check(d.rare_zone.holds(c.pos, Config.RARE_SPAWN_INSET_PX), "seed %d: %s a tile inside the rim" % [seed_id, kind])
			check(Movement.can_stand(d, c.pos) and d.terrain_at(Aim.feet_cell(c.pos)) == Terrain.GRASS, "seed %d: %s on grass" % [seed_id, kind])
			check_eq(c.home, c.pos, "its home is where it came down")
		for c2: CreatureSim in h.list:
			check_eq(c2.bound, c2.rare(), "seed %d: only the rare are bound" % seed_id)
		# The same seed, the same creatures in the same places.
		var again: Creatures = Creatures.new()
		again.setup(d, seed_id)
		for kind2: StringName in RARE:
			check_eq(rare_of(again, kind2).pos, rare_of(h, kind2).pos, "seed %d: %s repeats" % [seed_id, kind2])
	# The rules one at a time.
	var d2: WorldData = open_world()
	d2.rare_zone = RareZone.new(Vector2i(50, 30), 9)
	var h2: Creatures = Creatures.new()
	h2.setup(d2, 1, false)
	check_eq(d2.rare_zone.center, Vector2i(50, 30), "a zone already there is kept")
	var mid: Vector2 = d2.rare_zone.center_px()
	var none: Array[Player] = []
	check(h2.spawn_ok(mid, none, true), "the middle")
	check(h2.spawn_ok(mid + Vector2(122, 0), none, true), "just inside the inset")
	check(not h2.spawn_ok(mid + Vector2(126, 0), none, true), "inside the zone but within the inset")
	check(h2.spawn_ok(mid + Vector2(126, 0), none), "the same spot for a prey")
	check(not h2.spawn_ok(mid + Vector2(200, 0), none, true), "outside")
	check(h2.spawn_ok(mid + Vector2(200, 0), none), "a prey there")
	var p: Player = player(d2, "archer", mid + Vector2(100, 0))
	check(not h2.spawn_ok(mid, [p] as Array[Player], true), "a player within 160 px of the spot: no respawn there")
	# Natural spawning off (--test-no-creatures): the zone is there all the same, its picture shows.
	var off: WorldData = open_world()
	var h_off: Creatures = Creatures.new()
	h_off.setup(off, 1, false)
	check(off.rare_zone != null, "spawning off: the zone is placed")
	check_eq(h_off.alive_count(), 0, "spawning off: nobody in it")
	# A world with no zone has no rare creatures, and a rare place is dropped.
	var d3: WorldData = open_world(Vector2i(20, 20))
	var h3: Creatures = Creatures.new()
	h3.setup(d3, 1)
	check_eq(d3.rare_zone, null, "no site")
	for kind3: StringName in RARE:
		check(not h3.spawns_now(kind3), "%s: nowhere to spawn" % kind3)
		check_eq(h3.alive_count(kind3), 0, "%s: none" % kind3)
		check_eq(h3.try_spawn(kind3, none), null, "%s: try_spawn refuses" % kind3)
	check(h3.spawns_now(&"hare"), "the prey do not need it")
	h3.spawn(&"lamp_fox", Vector2(150, 150))
	h3.waiting.clear()
	var dropped: Creatures.Respawn = Creatures.Respawn.new()
	dropped.kind = &"ash_owl"
	dropped.due = 0
	h3.waiting.append(dropped)
	h3.step(none)
	check(h3.waiting.is_empty() and h3.alive_count(&"ash_owl") == 0, "a rare place with no zone is dropped")
	# Dead, then back: only after its time, inside the zone. Hit by an archer, as nobody else may.
	var d4: WorldData = SurfaceGen.generate(3)
	var h4: Creatures = Creatures.new()
	h4.setup(d4, 3)
	var fox: CreatureSim = rare_of(h4, &"lamp_fox")
	var hunter: Player = player(d4, "archer", d4.altar_center_px())
	h4.take_edits()
	h4.hit(fox, fox.hp, hunter.get_instance_id())
	check_eq(h4.waiting.size(), 1, "its place waits")
	check_eq(h4.waiting[0].due, h4.clock + fox.num_i("respawn_ticks"), "its respawn time")
	h4.waiting[0].due = h4.clock + 2
	h4.spawning = true
	h4.step(none)
	check_eq(h4.alive_count(&"lamp_fox"), 0, "not before its tick")
	h4.step(none)
	var back: CreatureSim = null
	for c3: CreatureSim in h4.list:
		if c3.kind == &"lamp_fox" and c3.alive():
			back = c3
	if check(back != null, "back on its tick"):
		check(d4.rare_zone.holds(back.pos, Config.RARE_SPAWN_INSET_PX) and back.bound, "back inside the zone, bound")


## A long chase on a generated map: every rare creature, every tick, inside the zone. Also the wander, the flee into the rim, the push.
func _check_stays_inside() -> void:
	for seed_id: int in [1, 2, 7]:
		var d: WorldData = SurfaceGen.generate(seed_id)
		var h: Creatures = Creatures.new()
		h.setup(d, seed_id)
		var z: RareZone = d.rare_zone
		var chaser: Player = player(d, "archer", z.center_px())
		var crowd: Array[Player] = [chaser]
		var left: int = 0
		for t: int in 3000:
			if t % 40 == 0:
				var c: CreatureSim = h.list[h.list.size() - 1 - (t / 40) % 3]
				chaser.teleport(c.pos + Vector2.from_angle(t * 0.7) * 30.0)  # the rim from every side
			h.step(crowd)
			for r: CreatureSim in h.list:
				if r.rare() and not z.holds(r.pos):
					left += 1
		check_eq(left, 0, "seed %d: never out of the zone" % seed_id)
		var moved: int = h.stat("bolts")
		check(moved > 20, "seed %d: it really ran (%d bolts)" % [seed_id, moved])
		for r2: CreatureSim in h.list:
			if r2.rare():
				check(z.has_tile(Aim.feet_cell(r2.pos)) or z.holds(r2.pos), "seed %d: %s home" % [seed_id, r2.kind])
	# It runs at the rim and stops there.
	var d2: WorldData = open_world()
	d2.rare_zone = RareZone.new(Vector2i(50, 30), 9)
	var h2: Creatures = Creatures.new()
	h2.setup(d2, 1, false)
	var mid: Vector2 = d2.rare_zone.center_px()
	var c2: CreatureSim = h2.spawn(&"lamp_fox", mid + Vector2(120, 0))
	c2.bound = true
	var pusher: Player = player(d2, "archer", mid)
	h2.bolt(c2, pusher.sim_position)
	for t2: int in c2.num_i("flee_ticks"):
		h2.step([] as Array[Player])
		check(d2.rare_zone.holds(c2.pos), "fleeing tick %d inside" % t2)
	check(c2.pos.distance_to(mid) > 125.0, "it did reach the rim (%.0f px)" % c2.pos.distance_to(mid))
	# The wander keeps inside: a spot outside is no spot.
	var c3: CreatureSim = h2.spawn(&"ash_owl", mid + Vector2(-120, 0))
	c3.bound = true
	for t3: int in 3000:
		h2.step([] as Array[Player])
		if not d2.rare_zone.holds(c3.pos):
			fail("wandered out at tick %d" % t3)
			break
	check(c3.pos != mid + Vector2(-120, 0), "it did wander")
	# The slam's push stops at the rim.
	var c4: CreatureSim = h2.spawn(&"silver_stag", mid + Vector2(0, 120))
	c4.bound = true
	h2.push(c4, Vector2.DOWN, 60.0)
	check(d2.rare_zone.holds(c4.pos), "pushed: still inside")
	check(c4.pos.y > mid.y + 125.0, "pushed as far as the rim allows (%.0f)" % (c4.pos.y - mid.y))
	check(h2.can_walk(mid, c4) and not h2.can_walk(mid + Vector2(200, 0), c4), "can_walk: the zone's rule for a bound one")
	check(h2.can_walk(mid + Vector2(200, 0)), "and none for nobody in particular")


## The altar can be carried here: the rule "never in the light" and the zone's rule meet.
func _check_light_on_zone() -> void:
	var d: WorldData = open_world()
	d.rare_zone = RareZone.new(Vector2i(50, 30), 9)
	var h: Creatures = Creatures.new()
	h.setup(d, 1, false)
	var mid: Vector2 = d.rare_zone.center_px()
	var c: CreatureSim = h.spawn(&"lamp_fox", mid + Vector2(10, 4))
	c.bound = true
	c.idle_ticks = 1000000
	d.altar_rect = Rect2i(d.rare_zone.center - Vector2i(1, 1), Config.ALTAR_FOOTPRINT)
	for t: int in 300:
		h.step([] as Array[Player])
		if not d.rare_zone.holds(c.pos):
			fail("the light drove it out of the zone at tick %d" % t)
			break
	var safe: SafeZone = SafeZone.for_world(d)
	check(Combat.box_outside_light(d, safe, c.pos), "it walked out of the light, into the ring the zone keeps (%s)" % c.pos)
	check(d.rare_zone.holds(c.pos), "and stayed in the zone")
	check_eq(c.home, c.pos, "its home is there now")
	# A spawn keeps out of that light too.
	check(not h.spawn_ok(mid, [] as Array[Player], true), "no spawn in the light")
	# A light reaching past the rim: the way straight out of it leaves the zone. It stays in, along the rim.
	var d2: WorldData = open_world()
	d2.rare_zone = RareZone.new(Vector2i(50, 30), 9)
	var h2: Creatures = Creatures.new()
	h2.setup(d2, 1, false)
	var c2: CreatureSim = h2.spawn(&"ash_owl", d2.rare_zone.center_px() + Vector2(130, 0))
	c2.bound = true
	c2.idle_ticks = 1000000
	d2.altar_rect = Rect2i(Vector2i(54, 29), Config.ALTAR_FOOTPRINT)
	var from: Vector2 = c2.pos
	for t2: int in 600:
		h2.step([] as Array[Player])
		if not d2.rare_zone.holds(c2.pos):
			fail("a light past the rim drove it out at tick %d" % t2)
			break
	check(c2.pos != from, "it did move")


## A test flag's rare creature (past the rules) is no zone creature: M11a's --test-creature stays what it was.
func _check_test_creatures() -> void:
	var d: WorldData = open_world()
	d.rare_zone = RareZone.new(Vector2i(50, 30), 9)
	var h: Creatures = Creatures.new()
	h.setup(d, 1, false)
	var c: CreatureSim = h.spawn(&"lamp_fox", d.rare_zone.center_px() + Vector2(-400, 0))
	check(not c.bound, "spawn() binds nobody")
	var p: Player = player(d, "archer", c.pos + Vector2(40, 0))
	var from: Vector2 = c.pos
	h.step([p] as Array[Player])
	h.step([p] as Array[Player])
	check(c.pos != from, "it runs where it stands")


# --- the picture -----------------------------------------------------------------------------------------

func _check_view() -> void:
	# The stone and its flame.
	var whole: Image = RareZoneView.image()
	var flame: Image = RareZoneView.image(true)
	var first: String = RareZoneView.STONE[0]
	check_eq(whole.get_size(), Vector2i(first.length(), RareZoneView.STONE.size()), "the stone's size")
	var lit: int = 0
	for y: int in whole.get_height():
		var row: String = RareZoneView.STONE[y]
		check_eq(row.length(), first.length(), "row %d's length" % y)
		for x: int in whole.get_width():
			var ch: String = row[x]
			check_eq(whole.get_pixel(x, y).a8, 0 if ch == "." else 255, "stone pixel %d,%d" % [x, y])
			if flame.get_pixel(x, y).a8 > 0:
				lit += 1
				check_eq(y, RareZoneView.FLAME_ROW, "the flame's row")
				check(ch == "g" or ch == "s", "the flame's colours")
	check_eq(lit, 3, "three flame pixels")
	check_eq(RareZoneView.stone_at(Vector2i(10, 20)), Vector2(10 * 16 + 8 - 4, 21 * 16 - 9), "bottom middle on the tile's bottom middle")
	# The tint: a disc, faint, thinning out over its last EDGE_PX.
	var half: int = 144
	var tint: Image = RareZoneView.tint_image(half)
	check_eq(tint.get_size(), Vector2i(289, 289), "the tint's size")
	check_between(tint.get_pixel(half, half).a8, RareZoneView.TINT.a8 - 1, RareZoneView.TINT.a8, "the middle")
	check(RareZoneView.TINT.a <= 0.15, "faint")
	check_between(tint.get_pixel(half + 127, half).a8, RareZoneView.TINT.a8 - 1, RareZoneView.TINT.a8, "inside the band: all of it")
	check_eq(tint.get_pixel(half + 145 - 1 + 0, half + 40).a8, 0, "past the rim: nothing")
	check_eq(tint.get_pixel(0, 0).a8, 0, "the corner: nothing")
	var band: Array[int] = [0, 0]
	for x2: int in range(half + 130, half + 143):
		for y2: int in range(half - 8, half + 8):
			band[0] += 1
			if tint.get_pixel(x2, y2).a8 > 0:
				band[1] += 1
	check(band[1] > 0 and band[1] < band[0], "the band is dithered (%d of %d)" % [band[1], band[0]])
	# The stones on generated maps: on open tiles near the rim, inside the zone, nothing edited.
	for seed_id: int in [1, 2, 3, 4]:
		var d: WorldData = SurfaceGen.generate(seed_id)
		var z: RareZone = RareZone.place(d, seed_id)
		var spots: Array[Vector2i] = RareZoneView.marker_spots(d, z)
		check(spots.size() >= Config.RARE_ZONE_MARKERS - 3, "seed %d: %d stones" % [seed_id, spots.size()])
		for c: Vector2i in spots:
			check(z.has_tile(c), "seed %d: stone %s inside" % [seed_id, c])
			check(RareZone.open_tile(d, c), "seed %d: stone %s on open land" % [seed_id, c])
			check_eq(d.get_value(WorldData.Layer.VEGETATION, c), 0, "seed %d: on no gatherable" % seed_id)
			check((Vector2(c) + Vector2(0.5, 0.5)).distance_to(Vector2(z.center) + Vector2(0.5, 0.5)) > z.radius - 4.5, "seed %d: near the rim" % seed_id)
	# A blocked rim point moves the stone in; a tile with no room leaves it out.
	var d2: WorldData = open_world()
	var z2: RareZone = RareZone.new(Vector2i(50, 30), 9)
	var east: Vector2i = Aim.cell_of(z2.center_px() + Vector2(z2.radius_px() - Config.TILE * 0.5, 0.0))
	check(RareZoneView.marker_spots(d2, z2).has(east), "the first stone on the rim")
	d2.set_value(WorldData.Layer.PLACEABLE, east, WorldData.PLACEABLE_TREE)
	var moved: Array[Vector2i] = RareZoneView.marker_spots(d2, z2)
	check(not moved.has(east) and moved.has(east - Vector2i(1, 0)), "a tree on the spot: a tile nearer the middle")
	d2.set_value(WorldData.Layer.PLACEABLE, east - Vector2i(1, 0), WorldData.PLACEABLE_TREE)
	d2.set_value(WorldData.Layer.PLACEABLE, east - Vector2i(2, 0), WorldData.PLACEABLE_TREE)
	check_eq(RareZoneView.marker_spots(d2, z2).size(), Config.RARE_ZONE_MARKERS - 1, "none free: left out")
	# Soil is no open land either: the stone moves in.
	var d3: WorldData = open_world()
	d3.set_value(WorldData.Layer.FLOOR, east, Terrain.SOIL)
	var on_soil: Array[Vector2i] = RareZoneView.marker_spots(d3, z2)
	check(not on_soil.has(east) and on_soil.has(east - Vector2i(1, 0)), "soil on the spot: a tile nearer the middle")
	# The node.
	var v: RareZoneView = RareZoneView.new()
	_nodes.append(v)
	var none: WorldData = open_world()
	v.setup(none)
	check(not v.visible and v.spots.is_empty(), "no zone: nothing shows")
	none.rare_zone = z2
	v.setup(none)
	check(v.visible, "a zone shows")
	check_eq(v.tint.position, z2.center_px() - Vector2(144, 144), "the tint on the disc")
	check(v.flames.material != null and v.stones.material == null, "the flames unshaded, the stones lit like the ground")
	check_eq(v.spots.size(), Config.RARE_ZONE_MARKERS, "every stone on open land")


# --- main.tscn --------------------------------------------------------------------------------------------

func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var w: GameWorld = main.world
	var z: RareZone = w.data.rare_zone
	if not check(z != null, "main: the surface has its zone"):
		return
	var fresh: WorldData = SurfaceGen.generate(w.data.world_seed)
	for layer: int in [WorldData.Layer.FLOOR, WorldData.Layer.WALL, WorldData.Layer.ORE, WorldData.Layer.VEGETATION, WorldData.Layer.CORRUPTION]:
		check(w.data.layers[layer] == fresh.layers[layer], "main: layer %s as generated: the zone edits no tile" % WorldData.LAYER_NAMES[layer])
	check(w.rare_view != null and w.rare_view.visible, "main: its picture shows")
	check_eq(w.rare_view.zone, z, "main: this zone")
	check(w.rare_view.get_index() > w.ground.get_index() and w.rare_view.get_index() < w.entities.get_index(), "main: above the ground, below the entities")
	check_eq(main.worlds[Config.MAP_DUNGEON].rare_view, null, "main: the dungeon has none")
	check_eq(main.worlds[Config.MAP_DUNGEON].data.rare_zone, null, "main: nor a zone")
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	var kinds: int = 0
	for kind: StringName in RARE:
		kinds += herd.alive_count(kind)
	check_eq(kinds, 3, "main: the three rare creatures")
	# --test-at-zone and friends parse.
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--test-at-zone=2,-3", "--test-near-creature=ash_owl:25", "--test-collection=4,7"]))
	check(o.errors.is_empty(), "main: the flags parse")
	check_eq(o.test_at_zone, Vector2i(2, -3), "main: --test-at-zone")
	check_eq(o.test_near_creature, [&"ash_owl", 25], "main: --test-near-creature")
	check(o.test_collection == 4 and o.test_collection_kills == 7, "main: --test-collection")
	for bad: String in ["--test-at-zone=1", "--test-near-creature=hare", "--test-near-creature=bat:5", "--test-near-creature=hare:0", "--test-collection=9",
			"--test-collection=-1", "--test-collection=1,x"]:
		check(not CliOptions.parse(PackedStringArray([bad])).errors.is_empty(), "main: %s refused" % bad)
