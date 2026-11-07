extends "res://tests/base_test.gd"
## M11a, the creatures (combat/creature_sim.gd, combat/creatures.gd, actors/creature_view.gd; every number PROVISIONAL, README "임시값"
## M11a): the table (five kinds: two prey, three rare, the speeds, alert radii and drops the rules need), the code-drawn maps,
## spawning over many seeds (only on the surface, never in the light, on corruption or its margin, in walls, fixtures, doorways, soil
## or at the map's edge, never near a player on a respawn; the rare kinds wait for M11b), caps and respawns on the game clock,
## wander / bolt / rest (the burst beats a walking player, then walking catches it; every obstacle kind, corruption and the
## altar's light, a light that moves onto one), stuns, slows, a push, poison, determinism (same seed = same spawns and paths; the
## heretic streams and prayer directions pinned from main before M11 and unchanged with a herd running beside them; no world edit),
## heretics and creatures ignoring each other, and the picture.

const TICK: float = 1.0 / 60.0
## The heretic digests (Arena id / spawned count / rng state) and the prayer directions measured on main 86f0b9a BEFORE any M11 code
## (the scratch run is README "측정" M11a): what every determinism check of M1-M10 stands on must stay byte-identical.
const GOLDEN_SURFACE: Dictionary[int, String] = {
	1: "9ee2138cb9ec/5/4/-8311685836597912239",
	2: "5a7e15ebfd26/5/4/7553809108497716449",
	7: "4fe45b7e10df/5/4/8180974956267112888",
}
const GOLDEN_DUNGEON: Dictionary[int, String] = {
	1: "d1349cf7a2de/7/6/-4578117944051683751",
	2: "516a710ae5a1/7/6/-5529083627336360334",
	7: "a3ded08c3246/7/6/-5624742452435546544",
}
const GOLDEN_PRAYERS: String = "d,w,w,s,d,d,a,d,w,s,w,w,d,a,s,s,d,a,w,w,s,s,a,w,a,s,w,d,w,w,a,w,s,w,w,s,s,a,s,a,s,w,a,w,w,w,w,s,s,d,d,w,s,w,a,s,w,s,a,w,s,d,s,d,a,d,d,a,a,d,a,w,a,d,w,s,a,d,a,a,w"

var _nodes: Array[Node] = []


## M11b: the world's rare creatures, one of each kind, in its zone.
const RARE_KINDS: int = 3


func run() -> Array[String]:
	_check_table()
	_check_maps()
	_check_spawn_rules()
	_check_spawn_refusals()
	_check_caps_and_respawn()
	_check_wander()
	_check_bolt_and_rest()
	_check_chase()
	_check_obstacles()
	_check_light_and_corruption()
	_check_long_chase()
	_check_status()
	_check_determinism()
	_check_streams_unchanged()
	_check_ignored_by_heretics()
	_check_view()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------

## An open surface-kind map with no altar (so no light).
static func open_world(size: Vector2i = Vector2i(80, 60)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_SURFACE
	return d


static func herd_on(d: WorldData, world_seed: int = 1, spawning: bool = false) -> Creatures:
	var h: Creatures = Creatures.new()
	h.setup(d, world_seed, spawning)
	return h


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


static func no_players() -> Array[Player]:
	return []


static func steps(h: Creatures, players: Array[Player], n: int) -> void:
	for i: int in n:
		for e: EditLog.WorldEdit in h.step(players):
			EditLog.apply_to_data(h.data, e)


## Walls (a built stone wall) on every tile of `rect`.
static func wall(d: WorldData, rect: Rect2i, kind: int = Walls.KIND_STONE) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			d.set_value(WorldData.Layer.WALL, Vector2i(x, y), Walls.pack(kind, 0))


static func feet_at(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


## The rule, written out here: every tile under the feet box is clean of corruption.
static func on_corruption(d: WorldData, feet: Vector2) -> bool:
	for c: Vector2i in Arena.cells_under(Movement.feet_box(feet)):
		if d.get_value(WorldData.Layer.CORRUPTION, c) != 0:
			return true
	return false


## The rule, written out here: the five points of the feet box against the altar's light.
static func in_light(d: WorldData, feet: Vector2) -> bool:
	if not d.altar_rect.has_area():
		return false
	var r: float = Config.safe_radius_px()
	var box: Rect2 = Movement.feet_box(feet)
	for q: Vector2 in [feet, box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		if q.distance_to(d.altar_center_px()) <= r:
			return true
	return false


# --- the table -------------------------------------------------------------------------------------

func _check_table() -> void:
	var kinds: Array = Config.CREATURES.keys()
	check_eq(kinds, [&"hare", &"deer", &"lamp_fox", &"silver_stag", &"ash_owl"], "five kinds: the two prey, then the three rare")
	var prey: Array[StringName] = [&"hare", &"deer"]
	var rare: Array[StringName] = [&"lamp_fox", &"silver_stag", &"ash_owl"]
	var top_prey: int = 0
	var alert_prey: float = 0.0
	var bow: float = Combat.attack_for(&"bow").reach
	var sword: float = Combat.attack_for(&"sword").reach
	for k: StringName in Config.CREATURES:
		var c: CreatureSim = CreatureSim.new()
		c.kind = k
		check_eq(c.rare(), rare.has(k), "%s: rare or prey" % k)
		for key: String in ["hp", "cap", "respawn_ticks", "flee_ticks", "rest_ticks"]:
			check(c.num_i(key) > 0, "%s: %s above 0" % [k, key])
		check(c.num_f("walk_speed") < Config.WALK_SPEED, "%s: wanders slower than a player walks" % k)
		check(c.num_f("flee_speed") > Config.WALK_SPEED, "%s: its burst beats walking" % k)
		check(c.num_f("flee_speed") < Config.DASH_SPEED, "%s: a dash still beats it" % k)
		check(c.num_f("alert_px") > sword, "%s: it bolts before a sword reaches it (%.0f > %.0f)" % [k, c.num_f("alert_px"), sword])
		check(c.num_f("alert_px") < bow, "%s: a bow reaches it from outside its alert radius (%.0f < %.0f)" % [k, c.num_f("alert_px"), bow])
		check(c.num_f("wander_px") > 0.0, "%s: wanders" % k)
		check(Creatures.drops_for(k, Config.HUNTER_CLASS).size() <= 2 and Creatures.drops_for(k, "miner").size() <= 2,
			"%s: at most two rows (Config.CREATURE_DROP_SPREAD_PX keeps them on one tile)" % k)
		for item_row: Array in Creatures.drops_for(k, Config.HUNTER_CLASS):
			var item_id: StringName = item_row[0]
			check(ItemDB.has(item_id), "%s: its drop %s is an item" % [k, item_id])
		if prey.has(k):
			top_prey = maxi(top_prey, c.hp_max())
			alert_prey = maxf(alert_prey, c.num_f("alert_px"))
			check(not Creatures.is_rare(k), "%s is prey" % k)
		else:
			check(Creatures.is_rare(k), "%s lives in the rare zone (M11b: tests/test_rare_zone.gd)" % k)
	for k2: StringName in rare:
		var c2: CreatureSim = CreatureSim.new()
		c2.kind = k2
		check(c2.hp_max() > top_prey, "%s: more HP than any prey" % k2)
		check(c2.num_f("alert_px") > alert_prey, "%s: quicker to bolt than any prey" % k2)
	var hare: CreatureSim = CreatureSim.new()
	hare.kind = &"hare"
	var deer: CreatureSim = CreatureSim.new()
	deer.kind = &"deer"
	check(hare.hp_max() < deer.hp_max(), "the hare has the lower HP")
	check(hare.num_f("flee_speed") > deer.num_f("flee_speed"), "the hare is the quicker")
	check(hare.num_f("alert_px") > deer.num_f("alert_px"), "the hare flees earlier")
	check_eq(Creatures.describe_drops(Creatures.drops_for(&"deer", "archer")), "hide_fine:2+meat:2", "the deer's drops, the archer (● whole hide)")
	check_eq(Creatures.describe_drops(Creatures.drops_for(&"deer", "paladin")), "hide_worn:1+meat:1", "the deer's drops, anyone else")
	check_eq(Creatures.describe_drops(Creatures.drops_for(&"hare", "archer")), "hide_fine:1+meat:1", "the hare's drops, the archer")
	check_eq(Creatures.describe_drops(Creatures.drops_for(&"hare", "miner")), "hide_worn:1", "the hare's drops, anyone else")
	check_eq(Config.HUNTER_CLASS, "archer", "● the archer leaves the hide whole")


# --- the maps ---------------------------------------------------------------------------------------

func _check_maps() -> void:
	check_eq(CreatureView.MAPS.keys(), Config.CREATURES.keys(), "a picture for every kind, in the table's order")
	check_eq(CreatureView.STEPS.keys(), Config.CREATURES.keys(), "a second frame for every kind")
	for k: StringName in CreatureView.MAPS:
		var maps: Array = CreatureView.MAPS[k]
		var steps_of: Array = CreatureView.STEPS[k]
		check_eq(maps.size(), 3, "%s: south, east, north" % k)
		check_eq(steps_of.size(), 3, "%s: three second frames" % k)
		for r: int in 3:
			var rows: Array = maps[r]
			var first: String = rows[0]
			var last: String = rows[rows.size() - 1]
			check(last.contains("k"), "%s %d: the last row stands on the ground" % [k, r])
			for line: String in rows:
				check_eq(line.length(), first.length(), "%s %d: rows of one length" % [k, r])
				for i: int in line.length():
					var ch: String = line[i]
					if ch != "." and not CreatureView.PALETTE.has(ch):
						fail("%s %d: the colour %s has no palette row" % [k, r, ch])
			var legs: Array = steps_of[r]
			check(legs.size() < rows.size(), "%s %d: the second frame changes the legs only" % [k, r])
			for line2: String in legs:
				check(line2.length() <= first.length(), "%s %d: leg rows fit" % [k, r])
			var a: Image = CreatureView.image(k, r, 0)
			var b: Image = CreatureView.image(k, r, 1)
			check_eq(a.get_size(), b.get_size(), "%s %d: both frames one size" % [k, r])
			check(a.get_data() != b.get_data(), "%s %d: the second frame differs" % [k, r])
		# The hit box stands for the drawn figure (a shot inside what is drawn hits it).
		var c: CreatureSim = CreatureSim.new()
		c.kind = k
		var tall: int = CreatureView.height_of(k)
		check_between(c.num_f("hit_height_px"), tall - 2.0, tall + 2.0, "%s: the hit box's height is the picture's (%d)" % [k, tall])
		var wide: int = maxi(CreatureView.frame_size(k, 0).x, CreatureView.frame_size(k, 1).x)
		check(c.num_f("hit_radius_px") * 2.0 <= wide + 2.0, "%s: the hit box is no wider than the picture" % k)
	# Beside a player: every kind is shorter than a player or about as tall, the hare small, the deer large.
	check(CreatureView.height_of(&"hare") < 16, "the hare is small")
	check(CreatureView.height_of(&"deer") > 20, "the deer is large")


# --- spawning -----------------------------------------------------------------------------------------

func _check_spawn_rules() -> void:
	var want: int = Creatures.cap_of(&"hare") + Creatures.cap_of(&"deer")
	var bad: int = 0
	for s: int in 24:
		var d: WorldData = SurfaceGen.generate(s + 1)
		var hash_before: String = d.content_hash()
		var h: Creatures = herd_on(d, s + 1, true)
		check_eq(h.alive_count(&"hare") + h.alive_count(&"deer"), want, "seed %d: every prey kind at its cap at the start" % (s + 1))
		check_eq(h.alive_count(&"hare"), Creatures.cap_of(&"hare"), "seed %d: hares" % (s + 1))
		check_eq(h.alive_count(&"deer"), Creatures.cap_of(&"deer"), "seed %d: deer" % (s + 1))
		check_eq(d.content_hash(), hash_before, "seed %d: spawning edits no world" % (s + 1))
		for c: CreatureSim in h.list:
			var cell: Vector2i = Aim.feet_cell(c.pos)
			var far: float = Config.safe_radius_px() + Config.CREATURE_SPAWN_LIGHT_CLEARANCE_TILES * Config.TILE
			var edge: int = Config.CREATURE_SPAWN_EDGE_TILES
			var ok: bool = not in_light(d, c.pos) and not on_corruption(d, c.pos) and Movement.can_stand(d, c.pos) \
				and d.terrain_at(cell) == Terrain.GRASS and c.pos.distance_to(d.altar_center_px()) >= far \
				and cell.x >= edge and cell.y >= edge and cell.x < d.size.x - edge and cell.y < d.size.y - edge \
				and not Arena.in_doorway(d, c.pos)
			var r: int = Config.CREATURE_SPAWN_ASH_CLEARANCE_TILES
			for y: int in range(cell.y - r, cell.y + r + 1):
				for x: int in range(cell.x - r, cell.x + r + 1):
					if d.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
						ok = false
			if not ok:
				bad += 1
				fail("seed %d: %s stands where it may not" % [s + 1, c.describe()])
			check(not c.rare() or (d.rare_zone != null and d.rare_zone.holds(c.pos)), "seed %d: a rare kind only in the rare zone" % (s + 1))
	check_eq(bad, 0, "24 seeds: every creature on clean grass away from the light, corruption, walls and the edge")
	# Never in the dungeon.
	var dun: WorldData = DungeonGen.generate(1)
	var hd: Creatures = herd_on(dun, 1, true)
	check_eq(hd.alive_count(), 0, "the dungeon has no creatures")
	check(not hd.spawning, "and spawns none")
	check(not hd.spawn_ok(DungeonGen.arrival_point(dun), no_players()), "no spot in the dungeon is allowed")
	steps(hd, no_players(), 600)
	check_eq(hd.alive_count(), 0, "still none after ten seconds")
	# Natural spawning off: none, but a test creature still comes.
	var off: Creatures = herd_on(SurfaceGen.generate(1), 1, false)
	check_eq(off.alive_count(), 0, "spawning off: none")
	off.spawn(&"hare", feet_at(Vector2i(10, 10)))
	check_eq(off.alive_count(&"hare"), 1, "spawn() still puts one down")


func _check_spawn_refusals() -> void:
	var d: WorldData = SurfaceGen.generate(1)
	var h: Creatures = herd_on(d)
	# A clean spot to change, away from everything (found by the rule itself, then moved around by hand).
	var open: Vector2i = Vector2i(-1, -1)
	for y: int in range(4, d.size.y - 4):
		for x: int in range(4, d.size.x - 4):
			if open.x < 0 and h.spawn_ok(feet_at(Vector2i(x, y)), no_players()) and h.spawn_ok(feet_at(Vector2i(x + 1, y)), no_players()):
				open = Vector2i(x, y)
	if not check(open.x >= 0, "a clean spot exists"):
		return
	var feet: Vector2 = feet_at(open)
	check(h.spawn_ok(feet, no_players()), "the clean spot is allowed")
	var p: Player = player(d, "paladin", feet + Vector2(Config.CREATURE_SPAWN_MIN_PLAYER_PX - 1.0, 0.0))
	check(not h.spawn_ok(feet, [p] as Array[Player]), "not within the distance of a player")
	p.teleport(feet + Vector2(Config.CREATURE_SPAWN_MIN_PLAYER_PX, 0.0))
	check(h.spawn_ok(feet, [p] as Array[Player]), "at the distance it is allowed")
	# One thing at a time on a copy of the spot.
	var was: int = d.get_value(WorldData.Layer.WALL, open)
	d.set_value(WorldData.Layer.WALL, open, Walls.pack(Walls.KIND_STONE, 0))
	check(not h.spawn_ok(feet, no_players()), "not on a built wall")
	d.set_value(WorldData.Layer.WALL, open, Walls.pack(Walls.KIND_DOOR_OPEN, 0))
	check(not h.spawn_ok(feet, no_players()), "not in an open door's doorway")
	d.set_value(WorldData.Layer.WALL, open, was)
	var below: Vector2i = open + Vector2i(0, 1)
	d.set_value(WorldData.Layer.WALL, below, Walls.pack(Walls.KIND_DOOR, 0))
	check(not h.spawn_ok(feet_at(below), no_players()), "not in a closed door")
	d.set_value(WorldData.Layer.WALL, below, was)
	d.set_value(WorldData.Layer.PLACEABLE, open, WorldData.PLACEABLE_WORKBENCH)
	check(not h.spawn_ok(feet, no_players()), "not on a fixture")
	d.set_value(WorldData.Layer.PLACEABLE, open, WorldData.PLACEABLE_NONE)
	var clear: int = Config.CREATURE_SPAWN_ASH_CLEARANCE_TILES
	var ash: Vector2i = open + Vector2i(clear, -clear)
	d.set_value(WorldData.Layer.CORRUPTION, ash, 1)
	check(not h.spawn_ok(feet, no_players()), "not within the margin of a corrupted tile")
	d.set_value(WorldData.Layer.CORRUPTION, ash, 0)
	d.set_value(WorldData.Layer.CORRUPTION, ash + Vector2i(1, 0), 1)
	check(h.spawn_ok(feet, no_players()), "a tile past the margin is allowed")
	d.set_value(WorldData.Layer.CORRUPTION, ash + Vector2i(1, 0), 0)
	d.set_terrain(open, Terrain.SOIL)
	check(not h.spawn_ok(feet, no_players()), "not on soil (grass only)")
	d.set_terrain(open, Terrain.GRASS)
	check(h.spawn_ok(feet, no_players()), "the spot is clean again: the world was read live")
	var c0: Vector2 = d.altar_center_px()
	var r: float = Config.safe_radius_px() + Config.CREATURE_SPAWN_LIGHT_CLEARANCE_TILES * Config.TILE
	check(not h.spawn_ok(c0 + Vector2(0.0, Config.safe_radius_px() + 2.0), no_players()), "not in the margin around the light")
	check(not h.spawn_ok(c0 + Vector2(r - 1.0, 0.0), no_players()), "not one px inside the clearance")
	var e: int = Config.CREATURE_SPAWN_EDGE_TILES
	var inner: Vector2 = feet_at(Vector2i(e - 1, open.y))
	check(not h.spawn_ok(inner, no_players()), "not at the map's edge")


func _check_caps_and_respawn() -> void:
	var d: WorldData = SurfaceGen.generate(1)
	var h: Creatures = herd_on(d, 1, true)
	var cap: int = Creatures.cap_of(&"hare")
	var respawn: int = Config.CREATURES[&"hare"]["respawn_ticks"]
	var victim: CreatureSim = null
	for c: CreatureSim in h.list:
		if c.kind == &"hare":
			victim = c
			break
	h.hit(victim, victim.hp, 0)
	check_eq(h.alive_count(&"hare"), cap - 1, "a kill: one fewer alive")
	check_eq(h.waiting.size(), 1, "its place waits")
	check_eq(h.clock, 0, "no step, no game time: the herd counts its own steps, never the wall clock")
	steps(h, no_players(), Config.CREATURE_CORPSE_TICKS)
	check_eq(h.list.size(), Creatures.cap_of(&"hare") + Creatures.cap_of(&"deer") + RARE_KINDS - 1, "the corpse is gone after its time")
	steps(h, no_players(), respawn - Config.CREATURE_CORPSE_TICKS - 1)
	check_eq(h.alive_count(&"hare"), cap - 1, "one tick before its time: still none")
	steps(h, no_players(), 1)
	check_eq(h.alive_count(&"hare"), cap, "on its time: it is back")
	check_eq(h.waiting.size(), 0, "nothing waits")
	check_eq(h.try_spawn(&"hare", no_players()), null, "at its cap a spawn try puts nothing down")
	# Never past the cap: a test creature took the place meanwhile.
	h.hit(h.list[0], 1000, 0)
	var kind0: StringName = h.list[0].kind
	h.spawn(kind0, h.list[1].pos)
	var r0: int = Config.CREATURES[kind0]["respawn_ticks"]
	steps(h, no_players(), r0 + 1)
	check_eq(h.alive_count(kind0), Creatures.cap_of(kind0), "the place was taken: nobody past the cap")
	check_eq(h.waiting.size(), 0, "and the wait is over")
	# A respawn near a player waits for a spot away from it; with no spot at all it tries again later.
	var box: WorldData = open_world(Vector2i(24, 24))
	box.layers[WorldData.Layer.FLOOR].fill(Terrain.GRASS)
	var hb: Creatures = herd_on(box, 1, true)
	check_eq(hb.alive_count(&"hare") + hb.alive_count(&"deer"), Creatures.cap_of(&"hare") + Creatures.cap_of(&"deer"), "a small open map fills too")
	var everywhere: Player = player(box, "paladin", Vector2(190, 190))
	var c1: CreatureSim = hb.list[0]
	var k1: StringName = c1.kind
	var r1: int = Config.CREATURES[k1]["respawn_ticks"]
	hb.hit(c1, c1.hp, 0)
	var misses: int = hb.stat("spawn_misses")
	box.layers[WorldData.Layer.WALL].fill(Walls.pack(Walls.KIND_STONE, 0))
	var left_before: int = hb.alive_count(k1)
	steps(hb, [everywhere] as Array[Player], r1 + 2)
	check_eq(hb.alive_count(k1), left_before, "no tile to stand on: no respawn")
	check(hb.stat("spawn_misses") > misses, "a try missed")
	check_eq(hb.waiting.size(), 1, "and it waits for another try")
	var due: int = hb.waiting[0].due
	check(due > hb.clock and due <= hb.clock + Config.CREATURE_SPAWN_RETRY_TICKS, "the next try comes within the retry time")
	box.layers[WorldData.Layer.WALL].fill(0)
	steps(hb, [everywhere] as Array[Player], Config.CREATURE_SPAWN_RETRY_TICKS + 1)
	check_eq(hb.alive_count(k1), left_before + 1, "a tile free again: it comes")
	for c2: CreatureSim in hb.list:
		if c2.clock <= Config.CREATURE_SPAWN_RETRY_TICKS + 2:
			check(c2.pos.distance_to(everywhere.sim_position) >= Config.CREATURE_SPAWN_MIN_PLAYER_PX - 1.0, "a respawn comes away from players")


# --- wander, bolt, rest ---------------------------------------------------------------------------------

func _check_wander() -> void:
	var d: WorldData = open_world()
	var h: Creatures = herd_on(d)
	var c: CreatureSim = h.spawn(&"deer", Vector2(400, 300))
	var moved: bool = false
	var far: float = 0.0
	var fastest: float = 0.0
	var wanders: int = 0
	for t: int in 40000:
		var was: Vector2 = c.pos
		var state: int = c.state
		steps(h, no_players(), 1)
		far = maxf(far, c.pos.distance_to(c.home))
		fastest = maxf(fastest, c.pos.distance_to(was))
		moved = moved or c.pos != was
		if c.state == CreatureSim.State.WANDER and state != CreatureSim.State.WANDER:
			wanders += 1
	check(moved, "it wanders")
	check(wanders >= 40, "again and again (%d walks)" % wanders)
	check(far <= c.num_f("wander_px") + 1.5, "never past its wander radius from home (%.1f of %.0f)" % [far, c.num_f("wander_px")])
	check(far > c.num_f("wander_px") * 0.5, "it does use the room (%.1f)" % far)
	check_between(fastest, 0.1, c.num_f("walk_speed") / 60.0 + 0.01, "at its walking speed")
	check_eq(c.state != CreatureSim.State.FLEE and c.state != CreatureSim.State.REST, true, "nothing alarmed it")


func _check_bolt_and_rest() -> void:
	var d: WorldData = open_world()
	var h: Creatures = herd_on(d)
	var c: CreatureSim = h.spawn(&"hare", Vector2(400, 300))
	var alert: float = c.num_f("alert_px")
	var flee: float = c.num_f("flee_speed") / 60.0
	# A player just outside the radius: nothing. On it: it bolts, straight away.
	var p: Player = player(d, "paladin", c.pos + Vector2(alert + 1.0, 0.0))
	var party: Array[Player] = [p]
	c.state = CreatureSim.State.IDLE
	c.idle_ticks = 100000
	steps(h, party, 3)
	check_eq(c.state, CreatureSim.State.IDLE, "outside the alert radius it stays")
	p.teleport(c.pos + Vector2(alert, 0.0))
	steps(h, party, 1)
	check_eq(c.state, CreatureSim.State.FLEE, "on the radius it bolts")
	check_between(c.pos.x, 400.0 - flee - 0.01, 400.0 - flee + 0.01, "at once, away from the player, at its burst speed")
	check_eq(c.pos.y, 300.0, "straight away")
	check_eq(c.facing, RigData.Dir.WEST, "it looks where it runs")
	check(c.walking, "the walk frames run")
	var start: Vector2 = c.pos
	var burst: int = c.num_i("flee_ticks")
	steps(h, party, burst - 1)
	check_eq(c.state, CreatureSim.State.FLEE, "the burst lasts its time")
	steps(h, party, 1)
	check_eq(c.state, CreatureSim.State.REST, "then it stops")
	check_between(start.distance_to(c.pos), flee * (burst - 1) - 0.5, flee * burst + 0.5, "it ran the burst at its speed")
	var rest_at: Vector2 = c.pos
	# Resting: a player walking up does not move it.
	p.teleport(c.pos + Vector2(10.0, 0.0))
	steps(h, party, c.num_i("rest_ticks") - 1)
	check_eq(c.pos, rest_at, "resting it stands, a player beside it or not")
	check_eq(c.state, CreatureSim.State.REST, "for its whole rest")
	steps(h, party, 2)
	check_eq(c.state, CreatureSim.State.FLEE, "rested, a player beside it sets it off again")
	# A hit while resting moves it at once, away from the attacker.
	var c2: CreatureSim = h.spawn(&"deer", Vector2(200, 300))
	var attacker: Player = player(d, "archer", Vector2(100, 300))
	c2.state = CreatureSim.State.REST
	c2.state_ticks = 0
	h.hit(c2, 1, attacker.get_instance_id())
	check_eq(c2.state, CreatureSim.State.FLEE, "a hit moves a resting one")
	check_eq(c2.flee_from, attacker.sim_position, "from its attacker")
	check_eq(c2.flash_ticks, Config.HIT_FLASH_TICKS, "it flashes")
	steps(h, [] as Array[Player], 1)
	check(c2.pos.x > 200.0, "the far side of the attacker")
	# Down and dead players alarm nobody.
	var c3: CreatureSim = h.spawn(&"hare", Vector2(600, 200))
	c3.idle_ticks = 100000
	var down: Player = player(d, "paladin", c3.pos + Vector2(10.0, 0.0))
	down.take_hit(Config.PLAYER_HP_MAX)
	check(not down.vitals.alive(), "the player is down")
	steps(h, [down] as Array[Player], 5)
	check_eq(c3.state, CreatureSim.State.IDLE, "a downed player alarms nothing")
	# The nearest of two players is the one it runs from.
	var c4: CreatureSim = h.spawn(&"deer", Vector2(300, 100))
	c4.idle_ticks = 100000
	var near: Player = player(d, "paladin", c4.pos + Vector2(20.0, 0.0))
	var far: Player = player(d, "paladin", c4.pos + Vector2(-40.0, 0.0))
	steps(h, [far, near] as Array[Player], 1)
	check(c4.pos.x < 300.0, "away from the nearer player")


## ● the common tier (R11): a walking player falls behind the burst, then catches the creature resting: the bow's reach is the natural
## way, melee the slower one.
func _check_chase() -> void:
	for kind: StringName in [&"hare", &"deer"]:
		var d: WorldData = open_world(Vector2i(120, 80))
		var h: Creatures = herd_on(d)
		var c: CreatureSim = h.spawn(kind, Vector2(900, 640))
		var alert: float = c.num_f("alert_px")
		var p: Player = player(d, "paladin", c.pos + Vector2(alert - 2.0, 0.0))
		var party: Array[Player] = [p]
		var start_gap: float = p.sim_position.distance_to(c.pos)
		var gap_at_stop: float = -1.0
		var catch_tick: int = -1
		var reach: float = Combat.attack_for(&"sword").reach
		for t: int in 600:
			var d2: Vector2 = c.pos - p.sim_position
			var dir: Vector2i = Vector2i(signi(roundi(d2.x)), signi(roundi(d2.y)))
			p.begin_tick()
			p.step_frame(NetProtocol.InputFrame.new(0, dir), TICK)
			steps(h, party, 1)
			if c.state == CreatureSim.State.REST and gap_at_stop < 0.0:
				gap_at_stop = p.sim_position.distance_to(c.pos)
			if c.state == CreatureSim.State.REST and p.sim_position.distance_to(c.pos) <= reach:
				catch_tick = t
				break
		check(gap_at_stop > start_gap, "%s: the burst beats walking (%.0f -> %.0f)" % [kind, start_gap, gap_at_stop])
		check(catch_tick >= 0, "%s: a walking player catches it while it rests" % kind)
		check(catch_tick > c.num_i("flee_ticks"), "%s: not before the burst ends (%d)" % [kind, catch_tick])


func _check_obstacles() -> void:
	# A wall row between it and open ground: it never crosses, whatever it runs from.
	var d: WorldData = open_world()
	wall(d, Rect2i(20, 10, 1, 40))
	var kinds: Array[Array] = [["built wall", Walls.KIND_STONE], ["closed door", Walls.KIND_DOOR]]
	for row: Array in kinds:
		var label: String = row[0]
		var kind: int = row[1]
		wall(d, Rect2i(20, 10, 1, 40), kind)
		var h: Creatures = herd_on(d)
		var c: CreatureSim = h.spawn(&"hare", Vector2(20 * Config.TILE + 30, 30 * Config.TILE))
		var p: Player = player(d, "paladin", c.pos + Vector2(30.0, 0.0))
		var party: Array[Player] = [p]
		for t: int in c.num_i("flee_ticks") + 10:
			steps(h, party, 1)
			check(c.pos.x > (20 + 1) * Config.TILE, "the %s stops it (tick %d, %.1f)" % [label, t, c.pos.x])
			if c.pos.x <= (20 + 1) * Config.TILE:
				break
		check_eq(c.state, CreatureSim.State.REST, "%s: it stopped after a while, by it" % label)
		var slid: bool = absf(c.pos.y - 30.0 * Config.TILE) > 8.0 or c.pos.x < (20 + 1) * Config.TILE + 16.0
		check(slid, "%s: it ran along it or up to it" % label)
	# An open door is open ground: a wall row with an open door, and it runs north through it.
	var d2: WorldData = open_world()
	wall(d2, Rect2i(0, 20, 80, 1))
	d2.set_value(WorldData.Layer.WALL, Vector2i(30, 20), Walls.pack(Walls.KIND_DOOR_OPEN, 0))
	var h2: Creatures = herd_on(d2)
	var c2: CreatureSim = h2.spawn(&"deer", Vector2(30.5 * Config.TILE, 24 * Config.TILE))
	var p2: Player = player(d2, "paladin", c2.pos + Vector2(0.0, 20.0))
	var side: bool = false
	for t: int in 200:
		steps(h2, [p2] as Array[Player], 1)
		side = side or c2.pos.y < 20 * Config.TILE
	check(side, "it runs through an open door")
	# A blocking fixture (the merchant's kind of tile) and the map's edge.
	var d3: WorldData = open_world(Vector2i(20, 20))
	var h3: Creatures = herd_on(d3)
	var c3: CreatureSim = h3.spawn(&"hare", Vector2(40, 200))
	var p3: Player = player(d3, "paladin", c3.pos + Vector2(30.0, 0.0))
	steps(h3, [p3] as Array[Player], c3.num_i("flee_ticks"))
	check(c3.pos.x >= Config.FEET_HALF_WIDTH, "the map's edge holds it (%.1f)" % c3.pos.x)
	check(Movement.can_stand(d3, c3.pos), "it stands where it may")
	# Cornered: it stands (nothing to do), no error, and it still ends its burst.
	var d4: WorldData = open_world()
	wall(d4, Rect2i(8, 8, 5, 1))
	wall(d4, Rect2i(8, 13, 5, 1))
	wall(d4, Rect2i(8, 9, 1, 4))
	wall(d4, Rect2i(12, 9, 1, 4))
	var h4: Creatures = herd_on(d4)
	var c4: CreatureSim = h4.spawn(&"hare", Vector2(10.5 * Config.TILE, 11 * Config.TILE))
	h4.bolt(c4, c4.pos + Vector2(1.0, 0.0))
	steps(h4, no_players(), c4.num_i("flee_ticks") + 1)
	check_eq(c4.state, CreatureSim.State.REST, "boxed in it ends its burst")
	check(Rect2i(9, 10, 3, 3).has_point(Aim.feet_cell(c4.pos)), "and stays in its box (%s)" % Aim.feet_cell(c4.pos))


func _check_light_and_corruption() -> void:
	# The light: on a generated map, a creature set off toward the altar stops at its edge.
	var d: WorldData = SurfaceGen.generate(1)
	var h: Creatures = herd_on(d)
	var centre: Vector2 = d.altar_center_px()
	var r: float = Config.safe_radius_px()
	var at: Vector2 = centre + Vector2(-(r + 12.0), 0.0)
	var c: CreatureSim = h.spawn(&"deer", at)
	h.bolt(c, at + Vector2(-20.0, 0.0))
	var inside: int = 0
	for t: int in c.num_i("flee_ticks"):
		steps(h, no_players(), 1)
		if in_light(d, c.pos):
			inside += 1
	check_eq(inside, 0, "running at the altar it never enters the light")
	check(c.pos.distance_to(at) > 8.0, "it moved (along the edge or up to it)")
	# A wander never picks a spot in the light: home just outside it.
	var c2: CreatureSim = h.spawn(&"deer", centre + Vector2(0.0, r + 10.0))
	for t: int in 6000:
		steps(h, no_players(), 1)
		if in_light(d, c2.pos):
			inside += 1
	check_eq(inside, 0, "wandering beside the light it stays out")
	# The altar's new light lands on one: it walks out and stays out.
	var moved: WorldData = SurfaceGen.generate(1)
	var hm: Creatures = herd_on(moved)
	var near: Vector2 = moved.altar_center_px() + Vector2(0.0, Config.safe_radius_px() + 30.0)
	var c3: CreatureSim = hm.spawn(&"hare", near)
	var rect: Rect2i = moved.altar_rect
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			moved.set_value(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_NONE)
	var to: Rect2i = Rect2i(rect.position + Vector2i(0, 4), rect.size)
	for y2: int in range(to.position.y, to.end.y):
		for x2: int in range(to.position.x, to.end.x):
			moved.set_value(WorldData.Layer.PLACEABLE, Vector2i(x2, y2), WorldData.PLACEABLE_ALTAR)
	moved.refresh_altar_rect()
	check(in_light(moved, c3.pos), "the new light lies on it")
	steps(hm, no_players(), 120)
	check(not in_light(moved, c3.pos), "it walked out of the new light")
	check(not in_light(moved, c3.home), "and home is out of it")
	# The altar carried: no light, it may walk there (the light's rule follows the world).
	# Corruption: never steps on it, on a map with a zone beside it.
	var d2: WorldData = open_world()
	for y3: int in 60:
		for x3: int in range(0, 20):
			d2.set_value(WorldData.Layer.CORRUPTION, Vector2i(x3, y3), 1)
	var h2: Creatures = herd_on(d2)
	var c4: CreatureSim = h2.spawn(&"hare", Vector2(20 * Config.TILE + 20, 300))
	var p4: Player = player(d2, "paladin", c4.pos + Vector2(30.0, 0.0))
	var on_ash: int = 0
	for t: int in 300:
		steps(h2, [p4] as Array[Player], 1)
		if on_corruption(d2, c4.pos):
			on_ash += 1
	check_eq(on_ash, 0, "running at a corruption zone it never steps on it")
	var c5: CreatureSim = h2.spawn(&"deer", Vector2(20 * Config.TILE + 8, 500))
	for t: int in 6000:
		steps(h2, no_players(), 1)
		if on_corruption(d2, c5.pos):
			on_ash += 1
	check_eq(on_ash, 0, "wandering beside it neither")


## A long run on generated worlds: a player keeps appearing beside creatures, so they bolt in every direction, through a world of
## trees, the altar, the entrance and the corruption zones.
func _check_long_chase() -> void:
	for s: int in [1, 5]:
		var d: WorldData = SurfaceGen.generate(s)
		var h: Creatures = herd_on(d, s, true)
		var p: Player = player(d, "paladin", d.altar_center_px())
		var party: Array[Player] = [p]
		var bad: int = 0
		var bolts: int = 0
		for t: int in 3000:
			if t % 45 == 0 and not h.list.is_empty():
				var c: CreatureSim = h.list[(t / 45) % h.list.size()]
				var a: float = float(t) * 0.7
				p.teleport(c.pos + Vector2.from_angle(a) * 24.0)
			steps(h, party, 1)
			for c2: CreatureSim in h.list:
				if in_light(d, c2.pos) or on_corruption(d, c2.pos) or not Movement.can_stand(d, c2.pos):
					bad += 1
			bolts = h.stat("bolts")
		check_eq(bad, 0, "seed %d: 50 s of bolting: never in the light, on corruption or in anything" % s)
		check(bolts >= 20, "seed %d: they did bolt (%d)" % [s, bolts])


# --- status ---------------------------------------------------------------------------------------------

func _check_status() -> void:
	var d: WorldData = open_world()
	var h: Creatures = herd_on(d)
	# A stun holds it still for its time (and a second keeps the longer), then it goes on.
	var c: CreatureSim = h.spawn(&"deer", Vector2(400, 300))
	var from: Vector2 = c.pos + Vector2(10.0, 0.0)
	h.bolt(c, from)
	h.stun(c, 30)
	h.stun(c, 10)
	check_eq(c.stun_ticks, 30, "the longer stun is kept")
	var at: Vector2 = c.pos
	steps(h, no_players(), 30)
	check_eq(c.pos, at, "stunned it stands")
	check(c.stunned() == false, "for exactly its time")
	steps(h, no_players(), 1)
	check(c.pos != at, "then it runs")
	check_eq(c.state, CreatureSim.State.FLEE, "the burst waited for the stun")
	# A slow cuts its speed and ends; the stronger is kept.
	var c2: CreatureSim = h.spawn(&"hare", Vector2(200, 100))
	h.slow(c2, 40, 60)
	h.slow(c2, 20, 100)
	check_eq(c2.slow_pct, 40, "the stronger slow")
	check_eq(c2.slow_ticks, 100, "the longer time")
	h.bolt(c2, c2.pos + Vector2(10.0, 0.0))
	var x0: float = c2.pos.x
	steps(h, no_players(), 1)
	check_between(x0 - c2.pos.x, c2.num_f("flee_speed") * 0.6 / 60.0 - 0.01, c2.num_f("flee_speed") * 0.6 / 60.0 + 0.01, "slowed by its percent")
	check(c2.slowed(), "slowed")
	steps(h, no_players(), 100)
	check(not c2.slowed() and c2.slow_pct == 0, "the slow runs out")
	# A push moves it and stops at a wall.
	var d2: WorldData = open_world()
	wall(d2, Rect2i(30, 20, 1, 3))
	var h2: Creatures = herd_on(d2)
	var c3: CreatureSim = h2.spawn(&"hare", Vector2(30 * Config.TILE - 20, 21 * Config.TILE + 8))
	h2.push(c3, Vector2.RIGHT, 8.0)
	check_eq(c3.pos.x, 30.0 * Config.TILE - 12.0, "pushed its px")
	h2.push(c3, Vector2.RIGHT, 40.0)
	check_eq(c3.pos.x, 30.0 * Config.TILE - Config.FEET_HALF_WIDTH, "a wall stops the push flush")
	# Poison ticks like a heretic's, the longer and larger kept, and it ends.
	var c4: CreatureSim = h.spawn(&"deer", Vector2(600, 300))
	check(h.poison(c4, 2, 90, 0), "poisoned")
	check(h.poison(c4, 1, 30, 0), "a weaker one keeps the stronger")
	check_eq(c4.poison_damage, 2, "the larger damage")
	check_eq(c4.poison_ticks, 90, "the longer time")
	check(c4.poisoned(), "shows poisoned")
	steps(h, no_players(), Config.POISON_INTERVAL_TICKS - 1)
	check_eq(c4.hp, c4.hp_max(), "the first tick an interval later")
	steps(h, no_players(), 1)
	check_eq(c4.hp, c4.hp_max() - 2, "two")
	steps(h, no_players(), 60)
	check_eq(c4.hp, c4.hp_max() - 6, "every interval for its time")
	check(not c4.poisoned(), "and it ended")
	check(not h.poison(CreatureSim.new(), 0, 0, 0), "nothing to poison with")


# --- determinism ----------------------------------------------------------------------------------------

## The herd's digest after `ticks` with a fixed walker: positions, HP, ids and the stream's state.
func herd_digest(world_seed: int, ticks: int) -> String:
	var d: WorldData = SurfaceGen.generate(world_seed)
	var h: Creatures = herd_on(d, world_seed, true)
	var node: Player = player(d, "paladin", d.altar_center_px() + Vector2(0.0, 48.0))
	var party: Array[Player] = [node]
	var text: String = ""
	for t: int in ticks:
		if t % 200 == 0 and not h.list.is_empty():
			node.teleport(h.list[(t / 200) % h.list.size()].pos + Vector2(20.0, 0.0))
		steps(h, party, 1)
		if t % 240 == 0:
			for c: CreatureSim in h.list:
				text += "%d:%s:%d,%d:%d;" % [c.id, c.kind, roundi(c.pos.x * 16.0), roundi(c.pos.y * 16.0), c.state]
	return "%s/%d/%s" % [text.md5_text().left(12), h.next_id, str(h.rng.state)]


func _check_determinism() -> void:
	var a: String = herd_digest(1, 4000)
	var b: String = herd_digest(1, 4000)
	check_eq(a, b, "the same seed, the same creatures, the same paths")
	check_ne(herd_digest(2, 4000), a, "another seed, others")
	var s1: Creatures = herd_on(SurfaceGen.generate(1), 1, true)
	var s2: Creatures = herd_on(SurfaceGen.generate(1), 1, true)
	check_eq(s1.list.size(), s2.list.size(), "as many")
	for i: int in s1.list.size():
		check_eq([s1.list[i].kind, s1.list[i].pos], [s2.list[i].kind, s2.list[i].pos], "creature %d in the same place" % i)
	# Its stream is its own: another stream's use does not move it, and it moves no other.
	var world: WorldData = SurfaceGen.generate(1)
	var h3: Creatures = herd_on(world, 1, true)
	var hw: int = h3.rng.state
	var arena: Arena = Arena.new()
	arena.setup(world, 1)
	arena.rng.randi()
	check_eq(h3.rng.state, hw, "the arena's random numbers leave the herd's stream alone")
	var state: int = arena.rng.state
	h3.rng.randi()
	check_eq(arena.rng.state, state, "and the other way")
	check_ne(h3.rng.seed, arena.rng.seed, "its seed is not the arena's")
	check_eq(h3.rng.seed, herd_on(SurfaceGen.generate(1), 1).rng.seed, "and it comes from the world seed alone")
	check_ne(h3.rng.seed, herd_on(SurfaceGen.generate(2), 2).rng.seed, "another world, another stream")


## The heretic digest (scratch baseline, written the same way on main before M11).
func heretic_digest(world_seed: int, map_id: int, ticks: int, with_herd: bool) -> String:
	var data: WorldData = SurfaceGen.generate(world_seed)
	if map_id == Config.MAP_DUNGEON:
		data = DungeonGen.generate(world_seed)
	var a: Arena = Arena.new()
	a.setup(data, world_seed)
	if with_herd and map_id == Config.MAP_SURFACE:
		a.herd = herd_on(data, world_seed, true)
	var ps: Array[Player] = []
	var p: Player = player(data, "paladin", data.altar_center_px() + Vector2(0.0, 48.0) if map_id == Config.MAP_SURFACE else DungeonGen.arrival_point(data))
	ps.append(p)
	var text: String = ""
	for t: int in ticks:
		a.step(ps)
		if a.herd != null:
			# The herd runs beside it and takes hits, so a kill and a respawn are in the run too.
			for e: EditLog.WorldEdit in a.herd.step(ps):
				EditLog.apply_to_data(data, e)
			if t % 300 == 0 and a.herd.alive_count() > 0:
				for c: CreatureSim in a.herd.list:
					if c.alive():
						a.hit_creature(c, 1000, p.get_instance_id())
						break
		if t % 240 == 0:
			for h: HereticSim in a.heretics:
				text += "%d:%d,%d;" % [h.id, roundi(h.pos.x * 16.0), roundi(h.pos.y * 16.0)]
	return "%s/%d/%d/%s" % [text.md5_text().left(12), a.next_id, a.stat("spawned"), str(a.rng.state)]


func _check_streams_unchanged() -> void:
	for s: int in GOLDEN_SURFACE:
		check_eq(heretic_digest(s, Config.MAP_SURFACE, 12000, false), GOLDEN_SURFACE[s], "seed %d: the surface's heretics as on main before M11" % s)
		check_eq(heretic_digest(s, Config.MAP_SURFACE, 12000, true), GOLDEN_SURFACE[s], "seed %d: and with a herd hunted beside them" % s)
		check_eq(heretic_digest(s, Config.MAP_DUNGEON, 12000, false), GOLDEN_DUNGEON[s], "seed %d: the dungeon's heretics as on main before M11" % s)
	var p: Array[String] = []
	for s2: int in [1, 2, 7]:
		for n: int in [1, 2, 3]:
			p.append(Prayer.keys_of(Prayer.directions_for(Prayer.seed_for(s2, n))))
	check_eq(",".join(p), GOLDEN_PRAYERS, "the prayers' directions as on main before M11")
	# No world edit: creatures live and bolt for a minute and the world hashes as generated.
	var d: WorldData = SurfaceGen.generate(1)
	var h: Creatures = herd_on(d, 1, true)
	var q: Player = player(d, "paladin", d.altar_center_px())
	for t: int in 3600:
		if t % 120 == 0:
			q.teleport(h.list[(t / 120) % h.list.size()].pos + Vector2(20.0, 0.0))
		steps(h, [q] as Array[Player], 1)
	check_eq(d.content_hash(), SurfaceGen.GOLDEN_HASH, "the world's hash is the generated one after a minute of creatures")


# --- heretics and creatures ignore each other ---------------------------------------------------------------

func _check_ignored_by_heretics() -> void:
	var d: WorldData = open_world()
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	a.herd = herd_on(d)
	var c: CreatureSim = a.herd.spawn(&"deer", Vector2(400, 300))
	c.idle_ticks = 1000000
	var h: HereticSim = a.spawn_heretic(Vector2(410, 300))
	var nobody: Array[Player] = []
	for t: int in 300:
		a.step(nobody)
		a.herd.step(nobody)
	check_eq(h.state, HereticSim.State.IDLE, "a heretic beside a creature stands: it is no target")
	check_eq(h.target_id, 0, "no target")
	check_eq(a.stat("attacks"), 0, "and no attack")
	check_eq(c.state, CreatureSim.State.IDLE, "the creature beside a heretic stands too")
	check_eq(c.pos, Vector2(400, 300), "unmoved")
	check_eq(c.hp, c.hp_max(), "unhurt")
	# A knife swung at a player through it hurts it not.
	var p: Player = player(d, "paladin", Vector2(440, 300))
	var party: Array[Player] = [p]
	h.pos = Vector2(425, 300)
	h.home = h.pos
	c.pos = Vector2(435, 300)
	for t: int in 120:
		a.step(party)
		if a.stat("knife_swings") > 0:
			break
	check(a.stat("knife_swings") > 0, "the knife swung")
	check_eq(c.hp, c.hp_max(), "it never touches the creature")
	# Threat: hits on a creature and a taunt among creatures touch no table.
	var h2: HereticSim = a.spawn_heretic(Vector2(300, 400))
	a.add_threat(h2, p.get_instance_id(), 7)
	a.hit_creature(c, 1, p.get_instance_id())
	check_eq(h2.threat_of(p.get_instance_id()), 7, "a hit on a creature adds no threat anywhere")
	var tame: CreatureSim = a.herd.spawn(&"hare", p.sim_position + Vector2(10.0, 0.0))
	tame.idle_ticks = 1000000
	var hp_was: int = tame.hp
	a.taunt(p, 64.0, 60)
	check_eq(tame.hp, hp_was, "and does nothing to a creature")
	check_eq(tame.state, CreatureSim.State.IDLE, "not even a start")


# --- the picture ----------------------------------------------------------------------------------------

func _check_view() -> void:
	var c: CreatureSim = CreatureSim.new()
	c.kind = &"deer"
	c.id = 3
	c.hp = c.hp_max()
	c.pos = Vector2(100.4, 200.6)
	var v: CreatureView = CreatureView.new()
	_nodes.append(v)
	var rows: Dictionary[int, int] = {RigData.Dir.SOUTH: 0, RigData.Dir.EAST: 1, RigData.Dir.NORTH: 2, RigData.Dir.WEST: 1}
	for dir: int in rows:
		c.facing = dir
		v.show_sim(c)
		check_eq(v.row, rows[dir], "%s: its sheet row" % RigData.DIR_NAMES[dir])
		check_eq(v.position, Vector2(100, 201), "%s: on whole pixels at the feet" % RigData.DIR_NAMES[dir])
		check_eq(v.rig.scale.x, -1.0 if dir == RigData.Dir.WEST else 1.0, "%s: west = east mirrored" % RigData.DIR_NAMES[dir])
		check_eq(v.body.texture, CreatureView.texture(&"deer", rows[dir], 0), "%s: its picture" % RigData.DIR_NAMES[dir])
		var s: Vector2i = CreatureView.frame_size(&"deer", rows[dir])
		check_eq(v.body.position, Vector2(-s.x / 2, -s.y), "%s: bottom middle on the feet" % RigData.DIR_NAMES[dir])
	c.facing = RigData.Dir.EAST
	check(CreatureView.texture(&"deer", 1, 0) == CreatureView.texture(&"deer", 1, 0), "the texture is kept")
	check_eq(v.body.light_mask, Config.LIGHT_LAYER_ACTORS, "the actors' hard light, like a heretic")
	check(not v.bar.visible, "full HP: no bar")
	check_eq(v.body.modulate, Color.WHITE, "no flash")
	c.hp = 15
	c.flash_ticks = 2
	v.show_sim(c)
	check(v.bar.visible, "hurt: the bar")
	check_eq(v.hp_ratio, 0.5, "half")
	check_eq(v.body.modulate, Player.HIT_FLASH, "the heretic's flash")
	c.flash_ticks = 0
	# The walk: the second frame and a px of bob.
	c.walking = true
	c.clock = CreatureSim.WALK_FRAME_TICKS
	v.show_sim(c)
	check_eq(v.frame, 1, "walking: the second frame")
	check_eq(v.body.texture, CreatureView.texture(&"deer", 1, 1), "its picture")
	var s2: Vector2i = CreatureView.frame_size(&"deer", 1)
	check_eq(v.body.position, Vector2(-s2.x / 2, -s2.y - 1), "a px of bob")
	c.clock = CreatureSim.WALK_FRAME_TICKS * 2
	v.show_sim(c)
	check_eq(v.frame, 0, "and back")
	c.walking = false
	# The marks.
	c.poison_ticks = 10
	c.stun_ticks = 10
	c.slow_ticks = 10
	c.slow_pct = 10
	v.show_sim(c)
	check_eq(v.marks.shown, [EffectMarks.Kind.POISON, EffectMarks.Kind.STUN, EffectMarks.Kind.SLOW] as Array[int], "its marks")
	check(v.marks.position.y + EffectMarks.MARK_Y < -CreatureView.height_of(&"deer"), "above its picture")
	# Dead: the corpse, no bar, no marks.
	c.state = CreatureSim.State.DEAD
	c.hp = 0
	v.show_sim(c)
	check(v.body.flip_v, "dead: the picture on its back")
	check(not v.bar.visible, "no bar")
	check(v.marks.shown.is_empty(), "no marks")
	c.state = CreatureSim.State.IDLE
	c.hp = c.hp_max()
	v.show_sim(c)
	check(not v.body.flip_v, "alive again: right way up")
	# CombatView keeps one node per creature, under the entities, and frees it with the creature.
	var d: WorldData = open_world()
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.herd = herd_on(d)
	var ent: Node2D = Node2D.new()
	add_node(ent)
	var view: CombatView = CombatView.new()
	add_node(view)
	view.setup(a, ent)
	var hare: CreatureSim = a.herd.spawn(&"hare", Vector2(200, 200))
	a.herd.spawn(&"deer", Vector2(240, 200))
	view.sync_creatures()
	check_eq(view.creatures.size(), 2, "a node per creature")
	check_eq(ent.get_child_count(), 2, "under the entities")
	view.sync()
	check_eq(view.creatures.size(), 2, "sync keeps them")
	a.herd.hit(hare, 1000, 0)
	a.herd.step([] as Array[Player])
	view.sync_creatures()
	check_eq(view.creatures.size(), 2, "the corpse lies on")
	for t: int in Config.CREATURE_CORPSE_TICKS:
		a.herd.step([] as Array[Player])
	view.sync_creatures()
	check_eq(view.creatures.size(), 1, "then its node goes")
	view.clear()
	check(view.creatures.is_empty(), "clear frees them")
	# A mirror and a session's arena have no herd: sync does nothing.
	var bare: Arena = Arena.new()
	bare.setup(d, 1)
	check_eq(bare.herd, null, "an arena has no herd by itself (a session's: M11c)")
	check(bare.hunted().is_empty(), "so no attack path meets a creature")
	var mirror: Arena = Arena.mirror(d)
	check_eq(mirror.herd, null, "nor has a mirror")
