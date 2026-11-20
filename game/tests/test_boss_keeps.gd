extends "res://tests/base_test.gd"
## M12a: what the boss fight must not change (README "M12a", the task's "existing heretic/prayer/creature sequences unchanged").
## The digests below were taken on main (cde5717, before any M12 code) by this same file's scenarios, then written in here: the
## M12 code runs the same scenarios now, the dungeon ones with the boss fight in its arena the way the offline game has it (asleep:
## nobody enters its room), and must give the same bytes.
##   surface  a paladin walks between the altar's edge and the heretics for 6,000 ticks on seed 1 (spawning, threat on): every
##            heretic's id, position (quarter px), state and HP every 30 ticks and the arena's random state at the end
##   dungeon  seeds 1, 2, 3: a miner walks a square at the arrival point for 6,000 ticks (spawning, threat on): the same record
##   prayer   the nine directions of the first 20 prayers of seeds 1, 2, 3 (Prayer.directions_for)
##   herd     the surface's creatures of seed 1 for 6,000 ticks with a player walking out from the altar: every creature's id, kind,
##            position (quarter px), state and HP every 30 ticks and the herd's random state at the end
## The generated worlds' golden hashes are checked by test_dungeon / test_world and --smoke as before (unchanged by M12).

const TICK: float = 1.0 / 60.0
## Taken on main cde5717 (2026-11-20) with this file's scenarios (see the class comment).
const GOLDEN: Dictionary[String, String] = {
	"surface": "a53ceb2244eb6cbd",
	"dungeon": "c41b7f6a38dccce2",
	"prayer": "77d50cb3d06eb9fd",
	"herd": "5a0bfe4d7699d5ad",
}

var _nodes: Array[Node] = []
## What the runs did (the digests must cover real fights): spawns, knife swings, the boss fight on each dungeon arena.
var _surface_stats: Dictionary[String, int] = {}
var _dungeon_spawns: Array[int] = []
var _dungeon_bosses: int = 0


func run() -> Array[String]:
	var got: Dictionary[String, String] = {
		"surface": _surface(),
		"dungeon": _dungeon(),
		"prayer": _prayer(),
		"herd": _herd(),
	}
	for key: String in got:
		note("%s=%s" % [key, got[key]])
		if not GOLDEN[key].is_empty():
			check_eq(got[key], GOLDEN[key], "the %s sequence is main's, byte for byte" % key)
	var spawned: int = _surface_stats.get("spawned", 0)
	var swings: int = _surface_stats.get("knife_swings", 0)
	check(spawned >= 3 and swings >= 3, "the surface run fought (%s)" % _surface_stats)
	for n: int in _dungeon_spawns:
		check(n >= 1, "each dungeon run had heretics (%s)" % str(_dungeon_spawns))
	check_eq(_dungeon_bosses, 3, "each dungeon arena had the boss fight on it, asleep")
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


## One heretic's record (id, quarter-px position, state, HP).
static func heretic_line(h: HereticSim) -> String:
	return "%d:%d,%d:%d:%d" % [h.id, roundi(h.pos.x * 4.0), roundi(h.pos.y * 4.0), h.state, h.hp]


## The arena the offline game has on map data `d` (M12a: the dungeon's with its boss fight, as Main.ensure_combat makes it).
static func game_arena(d: WorldData, world_seed: int) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, world_seed)
	a.threat_on = true
	if d.map_id == Config.MAP_DUNGEON:
		a.boss = BossFight.new()
		a.boss.setup(a, world_seed)
	return a


## A walk toward `goal` (8 ways, a 2 px dead zone).
static func toward(from: Vector2, goal: Vector2) -> Vector2i:
	var d: Vector2 = goal - from
	return Vector2i(0 if absf(d.x) < 2.0 else (1 if d.x > 0.0 else -1), 0 if absf(d.y) < 2.0 else (1 if d.y > 0.0 else -1))


func _surface() -> String:
	var data: WorldData = SurfaceGen.generate(1)
	var a: Arena = game_arena(data, 1)
	var p: Player = player(data, "paladin", data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]))
	var players: Array[Player] = [p]
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var centre: Vector2 = data.altar_center_px()
	for t: int in 6000:
		var goal: Vector2 = centre + (p.sim_position - centre).normalized() * (Config.SAFE_RADIUS_TILES * Config.TILE - 12.0)
		if (t / 400) % 2 == 1 and not a.heretics.is_empty():
			goal = a.heretics[(t / 800) % a.heretics.size()].pos
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(0, toward(p.sim_position, goal)), TICK)
		a.step(players)
		if p.vitals.life != Vitals.Life.ALIVE:
			p.respawn_vitals()
		p.vitals.hp = Config.PLAYER_HP_MAX
		if t % 30 == 0:
			var parts: PackedStringArray = []
			for h: HereticSim in a.heretics:
				parts.append(heretic_line(h))
			ctx.update(("%d|%s\n" % [t, ";".join(parts)]).to_utf8_buffer())
	ctx.update(("rng=%d stats=%s" % [a.rng.state, str(a.stats)]).to_utf8_buffer())
	_surface_stats = a.stats.duplicate()
	return ctx.finish().hex_encode().left(16)


func _dungeon() -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for world_seed: int in [1, 2, 3]:
		var data: WorldData = DungeonGen.generate(world_seed)
		var a: Arena = game_arena(data, world_seed)
		var start: Vector2 = DungeonGen.arrival_point(data)
		var p: Player = player(data, "miner", start)
		var players: Array[Player] = [p]
		var corners: Array[Vector2] = [start, start + Vector2(32, 0), start + Vector2(32, 24), start + Vector2(0, 24)]
		for t: int in 6000:
			var goal: Vector2 = corners[(t / 120) % corners.size()]
			p.begin_tick()
			p.step_frame(NetProtocol.InputFrame.new(0, toward(p.sim_position, goal)), TICK)
			a.step(players)
			if p.vitals.life != Vitals.Life.ALIVE:
				p.respawn_vitals()
				p.teleport(start)
			p.vitals.hp = Config.PLAYER_HP_MAX
			if t % 30 == 0:
				var parts: PackedStringArray = []
				for h: HereticSim in a.heretics:
					parts.append(heretic_line(h))
				ctx.update(("%d/%d|%s\n" % [world_seed, t, ";".join(parts)]).to_utf8_buffer())
		ctx.update(("%d rng=%d stats=%s" % [world_seed, a.rng.state, str(a.stats)]).to_utf8_buffer())
		_dungeon_spawns.append(a.stat("spawned"))
		if a.boss != null and a.boss.sim != null and a.boss.sim.state == BossSim.State.SLEEP and not data.blockers.is_empty():
			_dungeon_bosses += 1
	return ctx.finish().hex_encode().left(16)


func _prayer() -> String:
	var parts: PackedStringArray = []
	for world_seed: int in [1, 2, 3]:
		for n: int in 20:
			parts.append(str(Prayer.directions_for(Prayer.seed_for(world_seed, n))))
	return "|".join(parts).md5_text().left(16)


func _herd() -> String:
	var data: WorldData = SurfaceGen.generate(1)
	var herd: Creatures = Creatures.new()
	herd.setup(data, 1, true)
	var centre: Vector2 = data.altar_center_px()
	var p: Player = player(data, "archer", centre + Vector2(Config.SPAWN_SLOTS[0]))
	var players: Array[Player] = [p]
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for t: int in 6000:
		var goal: Vector2 = centre + Vector2(400.0 * cos(t / 900.0), 300.0 * sin(t / 900.0))
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(0, toward(p.sim_position, goal)), TICK)
		for e: EditLog.WorldEdit in herd.step(players):
			EditLog.apply_to_data(data, e)
		if t % 30 == 0:
			var parts: PackedStringArray = []
			for c: CreatureSim in herd.list:
				parts.append("%d:%s:%d,%d:%d:%d" % [c.id, c.kind, roundi(c.pos.x * 4.0), roundi(c.pos.y * 4.0), c.state, c.hp])
			ctx.update(("%d|%s\n" % [t, ";".join(parts)]).to_utf8_buffer())
	ctx.update(("rng=%d" % herd.rng.state).to_utf8_buffer())
	return ctx.finish().hex_encode().left(16)
