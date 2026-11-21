extends "res://tests/base_test.gd"
## M12a, the boss fight (● game-concept §6, §11, §12 R49; every number PROVISIONAL, README "임시값" M12a): the arena's room chosen from the seed
## (deterministic, the farthest big room by walking, never the shrine's or the arrival room, the generated worlds' golden hashes untouched,
## the pillars' spots and their gaps), the boss's wake and HP scaling, the three attacks' telegraphs (no damage before the telegraph ends,
## a dash through a fire bolt, stepping out of a burning circle), every attack path of every class and skill on it (zeal, tier-1, the
## archer's collection benefit, the exposure), threat and the taunt, stun and slow shortened with the immunity, phase 2's two heretics once,
## the reset (no one in its room, dragged too far: HP, adds, pillars), death, the flag, the relics (1, 2, 4 players, a full inventory) and
## the pillars (the miner's alone, the refused mark, the debris on the boss and the players, the rubble, restored on a reset, broken for
## good after the kill), the boss beaten without a miner. M12c-fix (review): sight (walls hide a player outside its room), the reset's stun
## immunity, the adds at its death, the relics at a leave or a map change, at the drops' cap, no refused mark beside it, a dead site.

const TICK: float = 1.0 / 60.0
const WEAPONS: Dictionary[String, StringName] = {"paladin": &"sword", "miner": &"pickaxe", "herbalist": &"sickle", "archer": &"bow",
	"cleric": &"holy_light"}
## The test room: its rect (the face row 6), so the walkable rows are 7..25 and the home tile (21, 16).
const ROOM: Rect2i = Rect2i(8, 6, 26, 20)

var _nodes: Array[Node] = []
var _landed: Skills.Landed


func run() -> Array[String]:
	_check_rooms()
	_check_wake_and_scaling()
	_check_cleave()
	_check_volley()
	_check_burn()
	_check_choice()
	_check_attack_paths()
	_check_skills()
	_check_bonuses()
	_check_threat()
	_check_stun_slow()
	_check_phase2()
	_check_reset()
	_check_death()
	_check_pillars()
	_check_without_miner()
	_check_review()  # M12c-fix
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------------------

## An open dungeon-kind map (no walls) for a test room.
static func open_dungeon() -> WorldData:
	var d: WorldData = WorldData.new(Vector2i(48, 36))
	d.map_id = Config.MAP_DUNGEON
	d.world_seed = 1
	return d


## The test room with `pillars`.
static func test_room(pillars: Array[Vector2i] = []) -> BossRoom.Layout:
	var r: BossRoom.Layout = BossRoom.Layout.new()
	r.room = ROOM
	r.walk = BossRoom.walk_of(ROOM)
	r.room_index = 0
	r.home_tile = r.walk.position + r.walk.size / 2
	r.pillars = pillars
	return r


## An arena on `d` (threat on, no spawns) with the boss fight in `room`.
static func fight_on(d: WorldData, room: BossRoom.Layout) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	a.boss = BossFight.new()
	a.boss.setup_with(a, room, 1)
	return a


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.skills_on = true
	p.potions_on = true
	_nodes.append(p)
	return p


static func tick(p: Player, f: NetProtocol.InputFrame = null) -> int:
	p.begin_tick()
	return p.step_frame(f if f != null else NetProtocol.InputFrame.new(), TICK)


## `n` ticks: the players (no input), then the arena; edits into the data.
static func run_world(a: Arena, players: Array[Player], n: int) -> void:
	for i: int in n:
		for p: Player in players:
			tick(p)
		for e: EditLog.WorldEdit in a.step(players):
			EditLog.apply_to_data(a.data, e)


## The boss's home feet plus `off`.
static func near_home(a: Arena, off: Vector2) -> Vector2:
	return a.boss.sim.home + off


## Wakes the boss with `players` (one step) and freezes it (blows only).
static func wake_frozen(a: Arena, players: Array[Player]) -> void:
	a.boss.wake(players)
	a.boss.frozen = true


func wire(p: Player, a: Arena, party: Array[Player]) -> void:
	p.party_provider = func() -> Array[Player]: return party
	p.action_impact.connect(_impact.bind(p, a, party))


func _impact(item: StringName, anim: int, _cell: Vector2i, p: Player, a: Arena, party: Array[Player]) -> void:
	if Skills.is_skill(item):
		_landed = Skills.land(p, item, a, party)
	elif Potions.is_drink(item):
		Potions.release(p, item, anim, a, 255, null)


static func press(p: Player, slot: int, mouse: Vector2) -> NetProtocol.InputFrame:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, mouse, true, false, false, false, false,
		slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	p.step_frame(f, TICK)
	return f


static func ticks(p: Player, n: int) -> void:
	for i: int in n:
		tick(p)


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


static func hold(p: Player, id: StringName) -> int:
	if slot_of(p.inventory, id) < 0:
		p.inventory.add(id, 1)
	var s: int = slot_of(p.inventory, id)
	p.inventory.select(s)
	return s


## The aim code from `p`'s aim origin to the boss's middle.
static func aim_at_boss(p: Player, a: Arena) -> int:
	return Combat.aim_code(a.boss.aim_point() - Combat.aim_origin(p.sim_position))


static func boss_lost(a: Arena) -> int:
	return a.boss.sim.hp_max - a.boss.sim.hp


# --- the room ------------------------------------------------------------------------------------------------------------

func _check_rooms() -> void:
	var used: int = 0
	var fallbacks: int = 0
	var counts: Dictionary[int, int] = {}
	for s: int in range(1, 31):
		var built: Array = DungeonGen.build(s)
		var data: WorldData = built[0]
		var gen: DungeonGen.Layout = built[1]
		var r: BossRoom.Layout = BossRoom.for_seed(s)
		var again: BossRoom.Layout = BossRoom.for_seed(s)
		if not check(r.has_room(), "seed %d: a boss room" % s):
			continue
		used += 1
		check_eq(r.describe(), again.describe(), "seed %d: the same room and pillars twice (deterministic)" % s)
		check(r.room_index != gen.shrine_room, "seed %d: never the shrine's room" % s)
		check(r.room_index != gen.arrival_room, "seed %d: never the arrival room" % s)
		check_eq(r.room, gen.rooms[r.room_index], "seed %d: a generated room" % s)
		var dist: Dictionary[Vector2i, int] = Arena.arrival_distances(data)
		if r.fallback:
			fallbacks += 1
		for i: int in gen.rooms.size():
			if i == gen.arrival_room or i == gen.shrine_room or i == r.room_index:
				continue
			var other: Rect2i = gen.rooms[i]
			var big: bool = other.size.x >= Config.BOSS_ARENA_MIN_SIZE.x and other.size.y >= Config.BOSS_ARENA_MIN_SIZE.y
			if not r.fallback and big:
				check(BossRoom.room_distance(other, dist) <= r.distance, "seed %d: no big room farther (%d)" % [s, i])
			if r.fallback:
				check(not big, "seed %d: the fallback only when no room is big" % s)
		check(r.distance >= Config.HERETIC_SPAWN_ARRIVAL_MIN_TILES, "seed %d: far from the stairs (%d steps)" % [s, r.distance])
		var n: int = r.pillars.size()
		counts[n] = counts.get(n, 0) + 1
		check(n >= roundi(Config.BOSS_PILLARS["min_count"]) and n <= roundi(Config.BOSS_PILLARS["count"]), "seed %d: 3 or 4 pillars (%d)" % [s, n])
		for p: Vector2i in r.pillars:
			check(r.walk.grow(-1).has_point(p), "seed %d: pillar %s a tile inside the walls" % [s, p])
			check(BossRoom.cheb(p, r.home_tile) >= 2, "seed %d: pillar %s off the home" % [s, p])
			for q: Vector2i in r.pillars:
				if q != p:
					check(BossRoom.cheb(p, q) >= roundi(Config.BOSS_PILLARS["spacing_tiles"]), "seed %d: pillars apart" % s)
			for door: Vector2i in r.doors:
				check(BossRoom.cheb(p, door) >= 1, "seed %d: not on a doorway" % s)
		# With the pillars standing every floor tile of the room is still reached from its doorways, every pillar has a free tile beside
		# it, and the home is free.
		for p2: Vector2i in r.pillars:
			data.blockers[p2] = true
		var reach: Dictionary[Vector2i, bool] = {}
		var queue: Array[Vector2i] = []
		for door2: Vector2i in r.doors:
			if not data.blockers.has(door2):
				reach[door2] = true
				queue.append(door2)
		var k: int = 0
		while k < queue.size():
			var c: Vector2i = queue[k]
			k += 1
			for st: Vector2i in DungeonGen.STEPS:
				var nb: Vector2i = c + st
				if r.walk.has_point(nb) and not reach.has(nb) and not Movement.is_blocked(data, nb):
					reach[nb] = true
					queue.append(nb)
		var floor_tiles: int = 0
		for y: int in range(r.walk.position.y, r.walk.end.y):
			for x: int in range(r.walk.position.x, r.walk.end.x):
				if not Movement.is_blocked(data, Vector2i(x, y)):
					floor_tiles += 1
		check_eq(reach.size(), floor_tiles, "seed %d: the pillars cut nothing off" % s)
		check(reach.has(r.home_tile), "seed %d: the home is reached" % s)
		for p3: Vector2i in r.pillars:
			var beside: bool = false
			for st2: Vector2i in DungeonGen.STEPS:
				beside = beside or reach.has(p3 + st2)
			check(beside, "seed %d: a free tile beside pillar %s" % [s, p3])
	note("boss rooms on seeds 1..30: %d, fallbacks %d, pillar counts %s" % [used, fallbacks, counts])
	# No tile edit: the generated worlds are the goldens, also with the boss fight on the dungeon's arena (its blockers are not tiles).
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var a: Arena = Arena.new()
	a.setup(dungeon, Config.DEFAULT_SEED)
	a.boss = BossFight.new()
	a.boss.setup(a, Config.DEFAULT_SEED)
	check_eq(dungeon.content_hash(), DungeonGen.GOLDEN_HASH, "the dungeon's golden hash with the fight on it")
	check(not dungeon.blockers.is_empty(), "its pillars block (blockers, no tile)")
	check_eq(DungeonGen.seeds_digest(), DungeonGen.SEEDS_GOLDEN, "the dungeon seeds digest")
	check_eq(SurfaceGen.generate(Config.DEFAULT_SEED).content_hash(), SurfaceGen.GOLDEN_HASH, "the surface's golden hash")
	check_eq(DungeonGen.GOLDEN_HASH.left(12), "8dda0ad69ad9", "the dungeon golden (the task's)")
	check_eq(DungeonGen.SEEDS_GOLDEN.left(12), "acc0a9bc2359", "the seeds golden (the task's)")
	check_eq(SurfaceGen.GOLDEN_HASH.left(12), "0da8e0d26ded", "the surface golden (the task's)")
	# The pillars block walking and shots like a station.
	var p0: Vector2i = a.boss.pillars[0].tile
	check(Movement.is_blocked(dungeon, p0) and Combat.blocks_line(dungeon, p0), "a pillar blocks walking and a shot")


# --- wake, scaling -----------------------------------------------------------------------------------------------------------

func _check_wake_and_scaling() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var b: BossSim = a.boss.sim
	check_eq(b.state, BossSim.State.SLEEP, "it sleeps at home")
	check_eq(b.pos, a.boss.room.home_feet(), "at its home")
	var outside: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(21, 29)))
	var players: Array[Player] = [outside]
	run_world(a, players, 30)
	check_eq(b.state, BossSim.State.SLEEP, "a player outside its room does not wake it")
	outside.teleport(Arena.spawn_feet(Vector2i(21, 24)))
	run_world(a, players, 1)
	check_eq(b.state, BossSim.State.CHASE, "a living player in its room wakes it")
	check_eq(b.hp_max, roundi(Config.BOSS["hp_base"]), "alone: the base HP")
	check_eq(a.boss.stat("woke"), 1, "once")
	# A downed player does not wake it.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var down: Player = player(d2, "cleric", Arena.spawn_feet(Vector2i(21, 22)))
	down.take_hit(Config.PLAYER_HP_MAX)
	run_world(a2, [down] as Array[Player], 5)
	check_eq(a2.boss.sim.state, BossSim.State.SLEEP, "a downed player in its room does not wake it")
	# A blow wakes it (from outside its room: an arrow).
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room())
	var archer: Player = player(d3, "archer", near_home(a3, Vector2(0, 150)))
	check(not a3.boss.room.holds(archer.sim_position), "the archer stands outside")
	a3.player_attack(archer, &"bow", aim_at_boss(archer, a3), [archer] as Array[Player])
	run_world(a3, [archer] as Array[Player], 90)
	check(a3.boss.sim.awake(), "an arrow wakes it")
	check_eq(boss_lost(a3), Combat.attack_for(&"bow").damage, "and lands")
	# HP by the players on its map when it wakes: x (1 + 0.6 (n - 1)), n capped at 9.
	for n: int in [1, 2, 4, 9, 12]:
		var want: int = roundi(Config.BOSS["hp_base"] * (1.0 + Config.BOSS["hp_per_player_pct"] / 100.0 * (mini(n, 9) - 1)))
		check_eq(BossSim.hp_for(n), want, "%d players: %d HP" % [n, want])
		var dn: WorldData = open_dungeon()
		var an: Arena = fight_on(dn, test_room())
		var party: Array[Player] = []
		for i: int in n:
			party.append(player(dn, Config.CLASSES[i % Config.CLASSES.size()], Arena.spawn_feet(Vector2i(10 + i, 24))))
		run_world(an, party, 1)
		check_eq(an.boss.sim.hp_max, want, "%d on the map at the wake: %d" % [n, want])
		check_eq(an.boss.sim.hp, want, "full")
	check_eq(BossSim.hp_for(1), 1200, "1200 alone (the task's example)")
	check_eq(BossSim.hp_for(4), 3360, "3360 with four")


# --- the attacks -------------------------------------------------------------------------------------------------------------

func _check_cleave() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "paladin", near_home(a, Vector2(0, 20)))
	var players: Array[Player] = [p]
	a.boss.wake(players)
	a.boss.begin_attack(BossSim.Attack.CLEAVE, p, players)
	var tele: int = BossSim.attack_int(BossSim.Attack.CLEAVE, "telegraph")
	check(tele >= 30, "the cleave's telegraph is at least 0.5 s (%d ticks)" % tele)
	run_world(a, players, tele - 1)
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "no damage before the telegraph ends")
	check_eq(a.boss.sim.state, BossSim.State.ATTACK, "still its telegraph")
	check_eq(a.boss.sim.anim(), BossSim.Anim.ATTACK, "the raise shows (the cleave: its attack sheet)")
	run_world(a, players, 1)
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX - BossSim.attack_int(BossSim.Attack.CLEAVE, "damage"), "the cleave lands on its tick")
	check_eq(a.boss.stat("player_hits_cleave"), 1, "counted")
	# Behind it: no hit; a dash out of reach: no hit.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var front: Player = player(d2, "paladin", near_home(a2, Vector2(0, 20)))
	var back: Player = player(d2, "cleric", near_home(a2, Vector2(0, -20)))
	var two: Array[Player] = [front, back]
	a2.boss.wake(two)
	a2.boss.begin_attack(BossSim.Attack.CLEAVE, front, two)
	for t: int in tele:
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i(0, 1))
		f.dash = t == tele - 8
		tick(front, f if t >= tele - 8 else null)
		tick(back)
		a2.step(two)
	check_eq(back.vitals.hp, Config.PLAYER_HP_MAX, "behind it: untouched")
	check_eq(front.vitals.hp, Config.PLAYER_HP_MAX, "a dash away before the blow: untouched")


func _check_volley() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "archer", near_home(a, Vector2(70, 0)))
	var players: Array[Player] = [p]
	a.boss.wake(players)
	a.boss.begin_attack(BossSim.Attack.VOLLEY, p, players)
	var tele: int = BossSim.attack_int(BossSim.Attack.VOLLEY, "telegraph")
	check(tele >= 30, "the volley's telegraph is at least 0.5 s (%d ticks)" % tele)
	check_eq(a.boss.sim.volley_dirs.size(), BossSim.attack_int(BossSim.Attack.VOLLEY, "bolts"), "its bolts' ways are set at the start")
	run_world(a, players, tele - 1)
	check(a.boss.bolts.is_empty(), "no bolt before the telegraph ends")
	run_world(a, players, 1)
	check_eq(a.boss.bolts.size(), BossSim.attack_int(BossSim.Attack.VOLLEY, "bolts"), "the bolts fly on its tick")
	var hp_before: int = p.vitals.hp
	run_world(a, players, 60)
	check_eq(hp_before - p.vitals.hp, BossSim.attack_int(BossSim.Attack.VOLLEY, "damage"), "the middle bolt hits the archer")
	check_eq(a.boss.stat("bolt_player"), 1, "stopped at the player")
	# Dash through it: the bolt passes the dashing player and flies on.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var q: Player = player(d2, "paladin", near_home(a2, Vector2(90, 0)))
	var solo: Array[Player] = [q]
	a2.boss.wake(solo)
	a2.boss.frozen = true
	a2.boss.sim.state = BossSim.State.ATTACK
	a2.boss.sim.attack = BossSim.Attack.VOLLEY
	a2.boss.sim.volley_dirs = [Vector2.RIGHT] as Array[Vector2]
	a2.boss._strike(solo)
	a2.boss.sim.state = BossSim.State.CHASE
	var bolt: BossFight.Bolt = a2.boss.bolts[0]
	var dashed: bool = false
	for t: int in 120:
		var f: NetProtocol.InputFrame = null
		if not dashed and bolt.pos.distance_to(Combat.body_point(q.sim_position)) < 14.0:
			f = NetProtocol.InputFrame.new(0, Vector2i(-1, 0))
			f.dash = true
			dashed = true
		tick(q, f)
		a2.step(solo)
	check(dashed, "the paladin dashed into it")
	check_eq(q.vitals.hp, Config.PLAYER_HP_MAX, "a dash through a fire bolt: no damage")
	check(bolt.dodged.has(q.get_instance_id()), "it passed the dashing player")
	check(bolt.stopped_by != "player", "and flew on (%s)" % bolt.stopped_by)
	check(a2.boss.stat("player_dodged_bolt") >= 1, "the dodge counted")
	# A wall stops a bolt.
	var d3: WorldData = open_dungeon()
	d3.set_value(WorldData.Layer.WALL, Vector2i(26, 16), Walls.pack(Walls.KIND_ROCK, 0))
	var a3: Arena = fight_on(d3, test_room())
	var r: Player = player(d3, "cleric", near_home(a3, Vector2(120, 0)))
	a3.boss.wake([r] as Array[Player])
	a3.boss.frozen = true
	a3.boss.sim.volley_dirs = [Vector2.RIGHT] as Array[Vector2]
	a3.boss.sim.attack = BossSim.Attack.VOLLEY
	a3.boss._strike([r] as Array[Player])
	run_world(a3, [r] as Array[Player], 90)
	check_eq(r.vitals.hp, Config.PLAYER_HP_MAX, "behind a wall: untouched")
	check_eq(a3.boss.stat("bolt_wall"), 1, "the wall stopped it")
	# Phase 2's volley is bigger.
	var d4: WorldData = open_dungeon()
	var a4: Arena = fight_on(d4, test_room())
	var s: Player = player(d4, "archer", near_home(a4, Vector2(70, 0)))
	a4.boss.wake([s] as Array[Player])
	a4.boss.sim.phase = 2
	a4.boss.begin_attack(BossSim.Attack.VOLLEY, s, [s] as Array[Player])
	check_eq(a4.boss.sim.volley_dirs.size(), roundi(Config.BOSS["phase2_bolts"]), "phase 2: more bolts")


func _check_burn() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var stay: Player = player(d, "paladin", near_home(a, Vector2(-50, 30)))
	var leave: Player = player(d, "cleric", near_home(a, Vector2(50, 30)))
	var far_out: Player = player(d, "archer", near_home(a, Vector2(0, 60)))
	var fourth: Player = player(d, "miner", near_home(a, Vector2(60, -40)))
	var players: Array[Player] = [stay, leave, far_out, fourth]
	a.boss.wake(players)
	a.boss.begin_attack(BossSim.Attack.BURN, stay, players)
	var tele: int = BossSim.attack_int(BossSim.Attack.BURN, "telegraph")
	check(tele >= 30, "the burning ground's telegraph is at least 0.5 s (%d ticks)" % tele)
	check_eq(a.boss.circles.size(), BossSim.attack_int(BossSim.Attack.BURN, "circles"), "circles under up to three players")
	a.boss.frozen = true
	run_world(a, players, tele - 1)
	for q: Player in players:
		check_eq(q.vitals.hp, Config.PLAYER_HP_MAX, "%s: no damage before the circles erupt" % q.class_id())
	leave.teleport(leave.sim_position + Vector2(0, -40))
	run_world(a, players, 1)
	var burnt: int = 0
	for q2: Player in players:
		if q2.vitals.hp < Config.PLAYER_HP_MAX:
			burnt += 1
	check_eq(burnt, 2, "the two who stayed on theirs burn")
	check_eq(leave.vitals.hp, Config.PLAYER_HP_MAX, "the one who stepped out does not")
	check_eq(stay.vitals.hp, Config.PLAYER_HP_MAX - BossSim.attack_int(BossSim.Attack.BURN, "damage"), "its damage")
	run_world(a, players, BossSim.attack_int(BossSim.Attack.BURN, "show_ticks"))
	check(a.boss.circles.is_empty(), "the burning ends")
	# Every attack's telegraph is at least the heretic's 0.5 s.
	for id: StringName in Config.BOSS_ATTACKS:
		var tl: int = Config.BOSS_ATTACKS[id]["telegraph"]
		check(tl >= Config.HERETIC_TELEGRAPH_TICKS, "%s: telegraph %d >= %d" % [id, tl, Config.HERETIC_TELEGRAPH_TICKS])


## The fight left to itself: it picks attacks from its own stream (the same each time), never attacks before its recover, and its
## attacks' telegraphs hold.
func _check_choice() -> void:
	var seen: Dictionary[int, int] = {}
	var logs: Array[String] = []
	for round_i: int in 2:
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room())
		var p: Player = player(d, "paladin", near_home(a, Vector2(0, 24)))
		var q: Player = player(d, "archer", near_home(a, Vector2(80, 40)))
		var players: Array[Player] = [p, q]
		var trace: PackedStringArray = []
		for t: int in 1800:
			for pl: Player in players:
				tick(pl)
				pl.vitals.hp = Config.PLAYER_HP_MAX
			var was: int = a.boss.sim.attack
			a.step(players)
			if a.boss.sim.attack != was and a.boss.sim.attack != BossSim.Attack.NONE:
				trace.append("%d:%s" % [t, BossSim.ATTACK_NAMES[a.boss.sim.attack]])
				seen[a.boss.sim.attack] = seen.get(a.boss.sim.attack, 0) + 1
		logs.append(",".join(trace))
	check_eq(logs[0], logs[1], "the same fight twice (its own stream, the game clock)")
	check(seen.size() == 3, "all three attacks came up (%s)" % seen)
	note("30 s of a fight: %s" % logs[0].left(160))


# --- every attack path ---------------------------------------------------------------------------------------------------------

func _check_attack_paths() -> void:
	for class_id: String in WEAPONS:
		var item: StringName = WEAPONS[class_id]
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room())
		var p: Player = player(d, class_id, near_home(a, Vector2(0, 18)))
		var party: Array[Player] = [p]
		wake_frozen(a, party)
		var attack: Combat.Attack = Combat.attack_for(item)
		a.player_attack(p, item, aim_at_boss(p, a), party)
		run_world(a, party, 40)
		check_eq(boss_lost(a), attack.damage, "%s's %s lands its damage on the boss" % [class_id, item])
		check_eq(a.boss.stat("boss_hits"), 1, "%s: one hit" % class_id)
		check_eq(a.boss.sim.threat_of(p.get_instance_id()), attack.damage, "%s: threat = damage" % class_id)
	# A swing the other way misses; out of reach misses.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var q: Player = player(d2, "paladin", near_home(a2, Vector2(0, 18)))
	wake_frozen(a2, [q] as Array[Player])
	a2.player_attack(q, &"sword", Combat.aim_code(Vector2.DOWN), [q] as Array[Player])
	check_eq(boss_lost(a2), 0, "a swing away from it misses")
	q.teleport(near_home(a2, Vector2(0, Combat.attack_for(&"sword").reach + Config.BOSS["melee_bonus_px"] + 2.0)))
	a2.player_attack(q, &"sword", aim_at_boss(q, a2), [q] as Array[Player])
	check_eq(boss_lost(a2), 0, "out of its reach misses")
	q.teleport(near_home(a2, Vector2(0, Combat.attack_for(&"sword").reach + Config.BOSS["melee_bonus_px"] - 1.0)))
	a2.player_attack(q, &"sword", aim_at_boss(q, a2), [q] as Array[Player])
	check_eq(boss_lost(a2), Combat.attack_for(&"sword").damage, "its bigger body: a little more reach")
	# Tier 1: the damage Main passes (Gear.attack_damage).
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room())
	var t1: Player = player(d3, "paladin", near_home(a3, Vector2(0, 18)))
	wake_frozen(a3, [t1] as Array[Player])
	t1.inventory.add(&"sword_t1", 1)
	var st: ItemStack = t1.inventory.stack_at(slot_of(t1.inventory, &"sword_t1"))
	var t1_damage: int = Gear.attack_damage(st, Combat.attack_for(&"sword_t1").damage)
	a3.player_attack(t1, &"sword_t1", aim_at_boss(t1, a3), [t1] as Array[Player], 255, t1_damage)
	check_eq(boss_lost(a3), t1_damage, "a tier-1 sword's damage")
	check_eq(t1_damage, Combat.attack_for(&"sword").damage * Config.GEAR_T1_DAMAGE_PCT / 100, "150%")
	# The piercing arrow hits it once.
	var d4: WorldData = open_dungeon()
	var a4: Arena = fight_on(d4, test_room())
	var arch: Player = player(d4, "archer", near_home(a4, Vector2(-80, 0)))
	wake_frozen(a4, [arch] as Array[Player])
	a4.skill_shot(arch, Skills.PIERCING_ARROW, aim_at_boss(arch, a4), 16, 240.0, 260.0, true)
	run_world(a4, [arch] as Array[Player], 60)
	check_eq(boss_lost(a4), 16, "the piercing arrow hits it once")
	# A thrown poison.
	var d5: WorldData = open_dungeon()
	var a5: Arena = fight_on(d5, test_room())
	var herb: Player = player(d5, "herbalist", near_home(a5, Vector2(-60, 0)))
	wake_frozen(a5, [herb] as Array[Player])
	a5.throw_potion(herb, &"potion_poison", ItemDB.Grade.COMMON, Combat.body_point(a5.boss.sim.pos))
	run_world(a5, [herb] as Array[Player], 40)
	check(a5.boss.sim.poisoned(), "a thrown poison reaches it")
	check_eq(a5.stat("splash_boss"), 1, "counted")
	run_world(a5, [herb] as Array[Player], Config.POISON_TICKS[ItemDB.Grade.COMMON] + 10)
	check_eq(boss_lost(a5), Config.POISON_DAMAGE[ItemDB.Grade.COMMON] * (Config.POISON_TICKS[ItemDB.Grade.COMMON] / Config.POISON_INTERVAL_TICKS),
		"its poison ticks run out")


func _check_skills() -> void:
	var rows: Array[Array] = [
		["archer", Skills.Slot.IDENTITY, Skills.PIERCING_ARROW, &"", Vector2(60, 0)],
		["miner", Skills.Slot.IDENTITY, Skills.GROUND_SLAM, &"", Vector2(24, 0)],
		["paladin", Skills.Slot.WEAPON, Skills.CRUSHING_BLOW, &"sword", Vector2(18, 0)],
		["archer", Skills.Slot.WEAPON, Skills.FAN_SHOT, &"bow", Vector2(60, 0)],
		["cleric", Skills.Slot.WEAPON, Skills.HOLY_BURST, &"holy_light", Vector2(60, 0)],
		["miner", Skills.Slot.WEAPON, Skills.HEAVY_STRIKE, &"pickaxe", Vector2(18, 0)],
		["herbalist", Skills.Slot.WEAPON, Skills.SWEEP, &"sickle", Vector2(18, 0)],
		["archer", Skills.Slot.SIGNATURE, Skills.ARROW_RAIN, &"", Vector2(60, 0)],
		["miner", Skills.Slot.SIGNATURE, Skills.ROCKFALL, &"", Vector2(60, 0)],
	]
	for row: Array in rows:
		var class_id: String = row[0]
		var slot: int = row[1]
		var id: StringName = row[2]
		var weapon: StringName = row[3]
		var offset: Vector2 = row[4]
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room())
		var p: Player = player(d, class_id, a.boss.sim.home - offset)
		var party: Array[Player] = [p]
		wire(p, a, party)
		wake_frozen(a, party)
		if not weapon.is_empty():
			hold(p, weapon)
		p.skills.resource = Skills.resource_cap(class_id)
		_landed = null
		press(p, slot, a.boss.aim_point())
		check_eq(p.action_skill, id, "%s's %s starts" % [class_id, id])
		ticks(p, Skills.impact_tick(id))
		run_world(a, party, 90)
		check(_landed != null and _landed.ok(), "%s landed" % id)
		var want: int = Skills.num_i(id, "damage")
		if id == Skills.ARROW_RAIN and _landed != null and _landed.strike != null:
			want = _landed.strike.damage
		if id == Skills.FAN_SHOT:
			check(a.boss.stat("boss_hits") >= 2, "the fan: most of its arrows on the big boss (%d)" % a.boss.stat("boss_hits"))
			want = Skills.num_i(id, "damage") * a.boss.stat("boss_hits")
		check_eq(boss_lost(a), want, "%s lands %d on the boss" % [id, want])
		check(a.boss.stat("boss_hits") >= 1, "%s counted" % id)


## Zeal, the archer's collection benefit and the exposure all reach the boss's damage.
func _check_bonuses() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "paladin", near_home(a, Vector2(0, 18)))
	wake_frozen(a, [p] as Array[Player])
	p.skills.add_zeal(25, 600, true)
	var base: int = Combat.attack_for(&"sword").damage
	var want: int = Prayer.zeal_damage(base, p)
	check(want > base, "zeal raises it")
	a.player_attack(p, &"sword", aim_at_boss(p, a), [p] as Array[Player])
	check_eq(boss_lost(a), want, "a swing: zeal on the boss")
	# The archer's collection benefit (3 entries registered).
	var d2: WorldData = open_dungeon()
	d2.collection = Collection.new()
	for i: int in Config.COLLECTION_BENEFITS[&"class"]:
		var entry: Dictionary = Config.COLLECTION_ENTRIES[i]
		var entry_id: StringName = entry["id"]
		d2.collection.register(entry_id)
	var a2: Arena = fight_on(d2, test_room())
	var r: Player = player(d2, "archer", near_home(a2, Vector2(-70, 0)))
	wake_frozen(a2, [r] as Array[Player])
	var bow: int = Combat.attack_for(&"bow").damage
	var with_benefit: int = Collection.arrow_damage(bow, r)
	check(with_benefit > bow, "the class benefit is on")
	a2.player_attack(r, &"bow", aim_at_boss(r, a2), [r] as Array[Player])
	run_world(a2, [r] as Array[Player], 60)
	check_eq(boss_lost(a2), with_benefit, "an arrow with the archer's collection benefit")
	# Exposed (after a pillar's debris): Config.BOSS exposed_damage_pct.
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room())
	var q: Player = player(d3, "paladin", near_home(a3, Vector2(0, 18)))
	wake_frozen(a3, [q] as Array[Player])
	a3.boss.sim.exposed_ticks = 100
	a3.player_attack(q, &"sword", aim_at_boss(q, a3), [q] as Array[Player])
	check_eq(boss_lost(a3), ceili(base * Config.BOSS["exposed_damage_pct"] / 100.0), "exposed: 150%")


# --- threat, taunt, stun, slow --------------------------------------------------------------------------------------------

func _check_threat() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var pal: Player = player(d, "paladin", near_home(a, Vector2(0, 20)))
	var arch: Player = player(d, "archer", near_home(a, Vector2(-90, 30)))
	var cleric: Player = player(d, "cleric", near_home(a, Vector2(90, 30)))
	var party: Array[Player] = [pal, arch, cleric]
	a.boss.wake(party)
	check_eq(a.boss.pick_target(party), pal, "no threat yet: the nearest")
	a.boss.hit(40, arch.get_instance_id())
	check_eq(a.boss.pick_target(party), arch, "the archer's threat is the highest")
	# A heal on the boss's target is threat for the healer.
	a.boss.sim.target_id = arch.get_instance_id()
	arch.vitals.hp = 50
	var n: int = a.heal_threat(cleric.get_instance_id(), arch, 20, party)
	check(n >= 1 and a.boss.sim.threat_of(cleric.get_instance_id()) == 20 * Config.THREAT_HEAL_PCT / 100, "a heal is threat on the boss")
	# The taunt forces it onto the paladin and puts him on top.
	check_eq(a.taunt(pal, Skills.num_f(Skills.TAUNT, "radius_px"), 120), 1, "the taunt takes")
	check_eq(a.boss.pick_target(party), pal, "taunted: the paladin")
	check(a.boss.sim.threat_of(pal.get_instance_id()) > a.boss.sim.threat_of(arch.get_instance_id()), "his threat on top")
	check(a.boss.sim.taunted(), "it shows taunted")
	# Asleep it takes no taunt.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var p2: Player = player(d2, "paladin", near_home(a2, Vector2(0, 20)))
	check_eq(a2.boss.taunt(p2, 64.0, 60), 0, "asleep: no taunt")
	# The boss goes after its target in the run.
	a.boss.frozen = false
	a.boss.sim.taunt_ticks = 0
	a.boss.sim.threat.clear()
	a.boss.hit(80, cleric.get_instance_id())
	for t: int in 30:
		for q: Player in party:
			tick(q)
		a.step(party)
	check_eq(a.boss.sim.target_id, cleric.get_instance_id(), "it goes after the highest threat")


func _check_stun_slow() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "paladin", near_home(a, Vector2(0, 20)))
	var party: Array[Player] = [p]
	a.boss.wake(party)
	a.boss.begin_attack(BossSim.Attack.CLEAVE, p, party)
	run_world(a, party, 5)
	var base_stun: int = Skills.num_i(Skills.CRUSHING_BLOW, "stun_ticks")
	check(a.boss.stun(base_stun), "a stun takes")
	var want: int = maxi(roundi(base_stun * Config.BOSS["stun_pct"] / 100.0), 1)
	check_eq(a.boss.sim.stun_ticks, want, "shortened: %d%% of %d" % [roundi(Config.BOSS["stun_pct"]), base_stun])
	check_eq(a.boss.sim.state, BossSim.State.CHASE, "it cancels the cleave under way")
	check_eq(a.boss.stat("attacks_stunned"), 1, "counted")
	check(not a.boss.stun(base_stun), "right after: immune")
	run_world(a, party, want)
	check(not a.boss.sim.stunned(), "the stun is over")
	check(not a.boss.stun(base_stun), "still immune after it")
	run_world(a, party, roundi(Config.BOSS["stun_immune_ticks"]) - 1)
	check(not a.boss.stun(base_stun), "immune to the last tick")
	run_world(a, party, 1)
	check(a.boss.stun(base_stun), "then a stun takes again")
	check_eq(a.boss.stat("stuns_resisted"), 3, "three resisted")
	# The debris's stun ignores the immunity.
	a.boss.force_stun(roundi(Config.BOSS["debris_stun_ticks"]))
	check_eq(a.boss.sim.stun_ticks, roundi(Config.BOSS["debris_stun_ticks"]), "the debris: its whole stun, immune or not")
	# Slow: half its strength and time.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var h: Player = player(d2, "herbalist", near_home(a2, Vector2(0, 20)))
	a2.boss.wake([h] as Array[Player])
	check(a2.boss.slow(40, 180), "a slow takes")
	check_eq(a2.boss.sim.slow_pct, 20, "half the strength")
	check_eq(a2.boss.sim.slow_ticks, 90, "half the time")
	check_eq(a2.boss.sim.speed(), Config.BOSS["speed"] * float(100 - 20) / 100.0, "walking slower")
	# Skills' stuns reach it shortened (the rocks): through the arena's strike.
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room())
	var m: Player = player(d3, "miner", near_home(a3, Vector2(-60, 0)))
	wake_frozen(a3, [m] as Array[Player])
	a3.add_strike(Arena.StrikeKind.ROCKS, a3.boss.sim.pos, 28.0, 0, 24, 60, m.get_instance_id())
	check_eq(a3.boss.sim.stun_ticks, maxi(roundi(60 * Config.BOSS["stun_pct"] / 100.0), 1), "the rockfall's stun, shortened")
	# The slam does not push it (Config.BOSS_PUSHABLE off).
	var d4: WorldData = open_dungeon()
	var a4: Arena = fight_on(d4, test_room())
	var m4: Player = player(d4, "miner", near_home(a4, Vector2(-20, 0)))
	wake_frozen(a4, [m4] as Array[Player])
	var at: Vector2 = a4.boss.sim.pos
	a4.slam(m4, 40.0, 6, 16.0)
	check_eq(a4.boss.sim.pos, at, "the slam does not push the boss")
	check_eq(boss_lost(a4), 6, "but hurts it")


# --- phase 2, the reset ----------------------------------------------------------------------------------------------------

func _check_phase2() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "paladin", near_home(a, Vector2(0, 20)))
	var party: Array[Player] = [p]
	wake_frozen(a, party)
	var half: int = a.boss.sim.hp_max * roundi(Config.BOSS["phase2_hp_pct"]) / 100
	a.boss.hit(a.boss.sim.hp_max - half - 1, p.get_instance_id())
	check_eq(a.boss.sim.phase, 1, "above half: phase 1")
	check(a.heretics.is_empty(), "no heretic yet")
	a.boss.hit(1, p.get_instance_id())
	check_eq(a.boss.sim.phase, 2, "at half: phase 2")
	check_eq(a.heretics.size(), roundi(Config.BOSS["phase2_adds"]), "it calls two heretics")
	check_eq(a.alive_heretics(), 2, "alive")
	for h: HereticSim in a.heretics:
		check(a.boss.room.holds(h.pos) and Movement.can_stand(d, h.pos), "in its room where they can stand")
	a.boss.hit(50, p.get_instance_id())
	a.boss.hit(50, p.get_instance_id())
	check_eq(a.heretics.size(), 2, "exactly once")
	check(a.boss.cadence() < roundi(Config.BOSS["recover_ticks"]), "a faster cadence")
	# The reset removes them; the next fight calls them again (once).
	a.boss.reset("test")
	check(a.heretics.is_empty(), "the reset removes its heretics")
	check_eq(a.boss.sim.phase, 1, "back to phase 1")
	a.boss.wake(party)
	a.boss.hit(a.boss.sim.hp_max - half, p.get_instance_id())
	check_eq(a.heretics.size(), 2, "the next fight's phase 2 calls them again")


func _check_reset() -> void:
	var d: WorldData = open_dungeon()
	var pillars: Array[Vector2i] = [Vector2i(14, 12), Vector2i(28, 20)]
	var a: Arena = fight_on(d, test_room(pillars))
	var p: Player = player(d, "miner", near_home(a, Vector2(0, 24)))
	var party: Array[Player] = [p]
	run_world(a, party, 1)
	check(a.boss.sim.awake(), "awake")
	a.boss.hit(a.boss.sim.hp_max / 2 + 10, p.get_instance_id())
	check_eq(a.heretics.size(), 2, "phase 2's heretics")
	for i: int in BossFight.Pillar.hits_per_state() * 3:
		a.boss.blow(0, p.get_instance_id(), true)
	run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1)
	check(a.boss.pillars[0].fallen, "a pillar broke")
	check(not d.blockers.has(pillars[0]), "its rubble does not block")
	# The miner leaves the room: Config.BOSS reset_ticks later it walks home and resets.
	p.teleport(Arena.spawn_feet(Vector2i(21, 31)))
	a.boss.frozen = false
	for t: int in roundi(Config.BOSS["reset_ticks"]) - 1:
		tick(p)
		p.vitals.hp = Config.PLAYER_HP_MAX
		a.step(party)
	check(a.boss.sim.state != BossSim.State.RETURN and a.boss.sim.state != BossSim.State.SLEEP, "not yet")
	tick(p)
	a.step(party)
	check(a.boss.sim.state == BossSim.State.RETURN or a.boss.sim.state == BossSim.State.SLEEP, "nobody in its room that long: home")
	var hit_back: int = a.boss.hit(10, p.get_instance_id())
	check(hit_back == 0 or a.boss.sim.state == BossSim.State.SLEEP, "walking home, no blow lands")
	run_world(a, [] as Array[Player], 600)
	check_eq(a.boss.sim.state, BossSim.State.SLEEP, "home and asleep")
	check_eq(a.boss.sim.pos, a.boss.sim.home, "at home")
	check_eq(a.boss.sim.hp, a.boss.sim.hp_max, "full HP")
	check(a.heretics.is_empty(), "its heretics gone")
	check(not a.boss.pillars[0].fallen and a.boss.pillars[0].hits == 0, "the pillar restored")
	check(d.blockers.has(pillars[0]), "and blocking again")
	check(a.boss.sim.threat.is_empty(), "no threat left")
	# Dragged too far: home at once.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room())
	var q: Player = player(d2, "paladin", near_home(a2, Vector2(0, 24)))
	run_world(a2, [q] as Array[Player], 1)
	a2.boss.sim.pos = a2.boss.sim.home + Vector2(Config.BOSS["leash_px"] + 4.0, 0.0)
	run_world(a2, [q] as Array[Player], 1)
	check_eq(a2.boss.sim.state, BossSim.State.RETURN, "dragged too far: it walks home")
	check(a2.boss.stat("returns") == 1, "counted")
	# The map emptied (everyone left the dungeon): reset at once.
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room())
	var r: Player = player(d3, "archer", near_home(a3, Vector2(0, 24)))
	run_world(a3, [r] as Array[Player], 1)
	a3.boss.hit(100, r.get_instance_id())
	a3.idle_tick()
	check_eq(a3.boss.sim.state, BossSim.State.SLEEP, "the map emptied: reset at once")
	check_eq(a3.boss.sim.hp, a3.boss.sim.hp_max, "full again")


# --- death, the flag, the relics ---------------------------------------------------------------------------------------------

func _check_death() -> void:
	for n: int in [1, 2, 4]:
		var d: WorldData = open_dungeon()
		d.progress = WorldProgress.new()
		var a: Arena = fight_on(d, test_room())
		var party: Array[Player] = []
		for i: int in n:
			party.append(player(d, Config.CLASSES[i], near_home(a, Vector2(-30 + 20 * i, 26))))
		run_world(a, party, 1)
		check_eq(a.boss.sim.woke_with, n, "%d on the map" % n)
		a.boss.frozen = true
		a.boss.hit(a.boss.sim.hp_max, party[0].get_instance_id())
		check(not a.boss.sim.alive(), "%d: dead" % n)
		check(d.progress.boss_defeated, "%d: the world's flag" % n)
		var relics: int = 0
		for q: Player in party:
			relics += q.inventory.count_of(Config.BOSS_RELIC)
			check_eq(q.inventory.count_of(Config.BOSS_RELIC), Config.BOSS_RELICS_PER_PLAYER, "%d: one relic for %s" % [n, q.class_id()])
		check_eq(relics, n * Config.BOSS_RELICS_PER_PLAYER, "%d players: %d relics" % [n, n])
		check(a.heretics.is_empty() and a.boss.bolts.is_empty() and a.boss.circles.is_empty(), "%d: the arena goes quiet" % n)
	# A full inventory: the relic lies at that player's feet (a drop through the ground-item path).
	var d2: WorldData = open_dungeon()
	d2.progress = WorldProgress.new()
	var a2: Arena = fight_on(d2, test_room())
	var full: Player = player(d2, "paladin", near_home(a2, Vector2(0, 26)))
	var other: Player = player(d2, "cleric", near_home(a2, Vector2(30, 26)))
	for s: int in full.inventory.size():
		full.inventory.add(&"stone_a", Config.STACK_GATHERABLE)
	check_eq(full.inventory.room_for(Config.BOSS_RELIC, ItemDB.Grade.NONE), 0, "the paladin's inventory is full")
	var two: Array[Player] = [full, other]
	run_world(a2, two, 1)
	a2.boss.frozen = true
	a2.boss.hit(a2.boss.sim.hp_max, other.get_instance_id())
	check_eq(full.inventory.count_of(Config.BOSS_RELIC), 0, "a full inventory takes none")
	check_eq(other.inventory.count_of(Config.BOSS_RELIC), 1, "the other one has its relic")
	run_world(a2, two, 1)
	var at: Array[WorldData.Drop] = d2.drops_at(Aim.feet_cell(full.sim_position))
	check_eq(at.size(), 1, "the full one's relic lies at its feet")
	if not at.is_empty():
		check_eq(at[0].item, Config.BOSS_RELIC, "the relic")
		check_eq(at[0].count, 1, "one")
	check_eq(a2.boss.relics_dropped[full.get_instance_id()], 1, "counted as dropped")
	# No respawn: dead for good, also in a new fight on the same world.
	run_world(a2, two, 600)
	check(not a2.boss.sim.alive(), "it stays dead")
	var again: Arena = fight_on(d2, test_room())
	check(not again.boss.sim.alive(), "a fight made again on the world: dead (the flag)")
	run_world(again, two, 60)
	check(not again.boss.sim.awake(), "it never wakes again")
	check(again.boss.sim.anim() == BossSim.Anim.DEATH, "it lies there")


# --- the pillars ----------------------------------------------------------------------------------------------------------------

func _check_pillars() -> void:
	var d: WorldData = open_dungeon()
	var spot: Vector2i = Vector2i(16, 16)
	var a: Arena = fight_on(d, test_room([spot]))
	var f: BossFight = a.boss
	var miner: Player = player(d, "miner", Arena.spawn_feet(spot + Vector2i(-1, 0)))
	var pal: Player = player(d, "paladin", Arena.spawn_feet(spot + Vector2i(0, 1)))
	var party: Array[Player] = [miner, pal]
	check(Movement.is_blocked(d, spot), "a pillar blocks")
	check_eq(f.pillars[0].look(), 0, "intact")
	# Anyone else's blows: refused (the mark), nothing done.
	var toward_pillar: int = Combat.aim_code(f.pillars[0].centre() - Combat.body_point(pal.sim_position))
	a.player_attack(pal, &"sword", toward_pillar, party)
	check_eq(f.pillars[0].hits, 0, "a sword does nothing to it")
	check(f.pillars[0].refused_ticks > 0, "its refused mark shows")
	check_eq(f.stat("pillar_refused"), 1, "refused")
	pal.inventory.add(&"pickaxe", 1)
	a.player_attack(pal, &"pickaxe", toward_pillar, party)
	check_eq(f.pillars[0].hits, 0, "a pickaxe in a paladin's hands does nothing either (the miner's alone)")
	var archer: Player = player(d, "archer", Arena.spawn_feet(spot + Vector2i(-6, 0)))
	a.player_attack(archer, &"bow", Combat.aim_code(Vector2.RIGHT), party)  # its ground point along the pillar's row (the boss is beyond)
	run_world(a, party, 30)
	check_eq(f.pillars[0].hits, 0, "an arrow does nothing")
	check_eq(a.stat("shot_pillar"), 1, "it stops at the pillar")
	check(f.stat("pillar_refused") >= 3, "each refused")
	# The miner's pick: a hit a blow, a state every three.
	var aim: int = Combat.aim_code(f.pillars[0].centre() - Combat.body_point(miner.sim_position))
	var per: int = BossFight.Pillar.hits_per_state()
	for i: int in per:
		a.player_attack(miner, &"pickaxe", aim, party)
	check_eq(f.pillars[0].look(), 1, "cracked")
	for i: int in per:
		a.player_attack(miner, &"pickaxe_t1", aim, party)
	check_eq(f.pillars[0].look(), 2, "badly cracked (the tier-1 pick too)")
	check(f.pillars[0].whole(), "still whole")
	# The boss under its fall circle, both players too: the last blow, then the dust, then the debris.
	f.wake(party)
	f.frozen = true
	f.sim.pos = f.pillars[0].centre() + Vector2(10, 12)
	var hp: int = f.sim.hp
	for i: int in per - 1:
		a.player_attack(miner, &"pickaxe", aim, party)
	check(f.pillars[0].whole(), "a blow short")
	a.player_attack(miner, &"pickaxe", aim, party)
	check_eq(f.pillars[0].look(), 3, "broken")
	check_eq(f.pillars[0].falling, roundi(Config.BOSS_PILLARS["telegraph_ticks"]), "its dust: the telegraph")
	check(Movement.is_blocked(d, spot), "the stub stands while it comes down")
	run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]) - 1)
	check_eq(f.sim.hp, hp, "no damage during the telegraph")
	check_eq(miner.vitals.hp, Config.PLAYER_HP_MAX, "nor on the miner")
	run_world(a, party, 1)
	var debris: int = maxi(ceili(f.sim.hp_max * Config.BOSS["debris_damage_pct"] / 100.0), 1)
	check_eq(hp - f.sim.hp, debris, "the debris: 12% of its max HP")
	check_eq(f.sim.stun_ticks, roundi(Config.BOSS["debris_stun_ticks"]), "the long stun")
	check(f.sim.exposed(), "exposed")
	check_eq(miner.vitals.hp, Config.PLAYER_HP_MAX - roundi(Config.BOSS_PILLARS["player_damage"]), "the miner under it is hit too")
	check(miner.vitals.staggered(), "and staggered")
	check_eq(pal.vitals.hp, Config.PLAYER_HP_MAX - roundi(Config.BOSS_PILLARS["player_damage"]), "and the paladin")
	check(f.pillars[0].fallen and not Movement.is_blocked(d, spot), "rubble: walkable")
	check_eq(f.sim.threat_of(miner.get_instance_id()), debris, "the debris is the breaker's threat")
	# The miner's skills count; another class's weapon skill is refused.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room([spot]))
	var m2: Player = player(d2, "miner", Arena.spawn_feet(spot + Vector2i(-1, 0)))
	a2.slam(m2, 40.0, 6, 16.0)
	check_eq(a2.boss.pillars[0].hits, 1, "the miner's slam is a blow")
	var no_edits: Array[EditLog.WorldEdit] = []
	a2.melee_skill(m2, Combat.aim_code(a2.boss.pillars[0].centre() - Combat.body_point(m2.sim_position)), 22, 24.0, 90.0, 0, 0, 0,
		Arena.BurstKind.HEAVY, no_edits)
	check_eq(a2.boss.pillars[0].hits, 2, "his heavy strike too")
	a2.add_strike(Arena.StrikeKind.ROCKS, a2.boss.pillars[0].centre(), 28.0, 0, 24, 60, m2.get_instance_id())
	check_eq(a2.boss.pillars[0].hits, 3, "his rockfall too")
	var p2: Player = player(d2, "paladin", Arena.spawn_feet(spot + Vector2i(0, 1)))
	a2.melee_skill(p2, Combat.aim_code(a2.boss.pillars[0].centre() - Combat.body_point(p2.sim_position)), 20, 28.0, 120.0, 60, 0, 0,
		Arena.BurstKind.CRUSH, no_edits)
	check_eq(a2.boss.pillars[0].hits, 3, "the paladin's crushing blow: refused")
	a2.add_strike(Arena.StrikeKind.ARROWS, a2.boss.pillars[0].centre(), 32.0, 0, 6, 0, p2.get_instance_id())
	check_eq(a2.boss.pillars[0].hits, 3, "an arrow rain: nothing")
	# After the kill the pillars stay broken.
	var d3: WorldData = open_dungeon()
	d3.progress = WorldProgress.new()
	var a3: Arena = fight_on(d3, test_room([spot, Vector2i(26, 20)]))
	var m3: Player = player(d3, "miner", Arena.spawn_feet(spot + Vector2i(-1, 0)))
	run_world(a3, [m3] as Array[Player], 1)
	a3.boss.frozen = true
	for i: int in per * 3:
		a3.boss.blow(0, m3.get_instance_id(), true)
	run_world(a3, [m3] as Array[Player], roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1)
	a3.boss.hit(a3.boss.sim.hp_max, m3.get_instance_id())
	run_world(a3, [] as Array[Player], 1000)
	check(a3.boss.pillars[0].fallen, "after the kill: broken for good")
	check(a3.boss.pillars[1].whole(), "the other stands")
	a3.idle_tick()
	check(a3.boss.pillars[0].fallen, "the map emptying does not restore them after the kill")


## ● gameplay-design §3.0: without a miner the boss is still beaten (the ceiling lower, progress never blocked): four non-miners kill it
## with their basic attacks alone, every one gets a relic, and the altar upgrade takes the relic from any class.
func _check_without_miner() -> void:
	var d: WorldData = open_dungeon()
	d.progress = WorldProgress.new()
	var a: Arena = fight_on(d, test_room())
	var party: Array[Player] = []
	var classes: PackedStringArray = ["paladin", "archer", "cleric", "herbalist"]
	for i: int in classes.size():
		party.append(player(d, classes[i], near_home(a, Vector2(-30 + 20 * i, 22))))
	run_world(a, party, 1)
	a.boss.frozen = true
	var swings: int = 0
	while a.boss.sim.alive() and swings < 2000:
		for q: Player in party:
			a.player_attack(q, WEAPONS[q.class_id()], aim_at_boss(q, a), party)
		run_world(a, party, 1)
		swings += 1
	check(not a.boss.sim.alive(), "four classes without a miner beat it (%d rounds)" % swings)
	check_eq(a.boss.stat("pillar_hits"), 0, "with no pillar broken")
	for q2: Player in party:
		check_eq(q2.inventory.count_of(Config.BOSS_RELIC), 1, "%s: a relic" % q2.class_id())
	var r: Crafting.Recipe = Crafting.recipe(Config.ALTAR_UPGRADE)
	check(r != null and r.classes.is_empty(), "the altar upgrade is anyone's")
	check(d.progress.boss_defeated, "the flag")


# --- M12c-fix: the review's findings ---------------------------------------------------------------------------------------------

## M12c-fix (review): who it sees (a wall hides a player outside its room, nothing hides one inside, not a pillar; sight_px; the taunt needs
## a clear line), a reset clears its stun immunity, its adds leave at its death, the relics go to the players on its map at the kill (one
## freed or gone to another map since the last step gets none and nothing errs, one who came is counted: players_now), a relic takes the
## oldest drop's place at the map's cap, a non-miner's blow that hit the boss puts no refused mark on the pillar beside it, a dead boss's
## site and pillar events decode.
func _check_review() -> void:
	_check_sight()
	_check_reset_immunity()
	_check_adds_at_death()
	_check_relics_live()
	_check_relic_at_cap()
	_check_refused_beside_boss()
	_check_dead_site()


## Walls along the test room's south side (rows 26 and 27, a tile past each end).
static func wall_south(d: WorldData) -> void:
	for x: int in range(ROOM.position.x - 1, ROOM.end.x + 1):
		for y: int in [ROOM.end.y, ROOM.end.y + 1]:
			d.set_value(WorldData.Layer.WALL, Vector2i(x, y), Walls.pack(Walls.KIND_ROCK, 0))


func _check_sight() -> void:
	var d: WorldData = open_dungeon()
	wall_south(d)
	var pillar: Vector2i = Vector2i(21, 20)
	var a: Arena = fight_on(d, test_room([pillar]))
	var f: BossFight = a.boss
	var hidden: Player = player(d, "cleric", Arena.spawn_feet(Vector2i(21, 29)))
	var inside: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(21, 23)))
	var both: Array[Player] = [inside, hidden]
	f.wake(both)
	check(not f.room.holds(hidden.sim_position) and hidden.sim_position.distance_to(f.sim.pos) < BossSim.num("sight_px"),
		"sight: the one south of the wall is outside its room, within sight_px")
	check(not Combat.line_clear(d, Combat.body_point(f.sim.pos), Combat.body_point(hidden.sim_position)), "sight: a wall between")
	check(not f.can_target(hidden), "sight: a wall hides a player outside its room")
	check(not Combat.line_clear(d, Combat.body_point(f.sim.pos), Combat.body_point(inside.sim_position)), "sight: the pillar between")
	check(f.can_target(inside), "sight: inside its room nothing hides (not the pillar)")
	var burn: Array[Player] = f.burn_targets(both)
	check(burn.size() == 1 and burn[0] == inside, "sight: the burn's circles go under the one it sees only")
	check_eq(f.taunt(hidden, 400.0, 60), 0, "sight: a taunt through the wall does not take")
	# Only the hidden one on the map: no target, no circle under him, his HP whole (the review's probe: 6 circles, 0 HP in 600 ticks).
	var d2: WorldData = open_dungeon()
	wall_south(d2)
	var a2: Arena = fight_on(d2, test_room())
	var alone: Player = player(d2, "cleric", Arena.spawn_feet(Vector2i(21, 29)))
	var one: Array[Player] = [alone]
	a2.boss.wake(one)
	a2.boss.test_attack = BossSim.Attack.BURN
	var circles: int = 0
	for t: int in 400:
		run_world(a2, one, 1)
		circles += a2.boss.circles.size()
	check(a2.boss.sim.target_id == 0 and circles == 0 and alone.vitals.hp == Config.PLAYER_HP_MAX,
		"sight: behind the wall he is no target, no circle, full HP (target %d, circles %d, hp %d)" % [a2.boss.sim.target_id, circles,
		alone.vitals.hp])
	# Outside the room with a clear line: seen; beyond sight_px: not.
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room())
	var seen: Player = player(d3, "archer", Arena.spawn_feet(Vector2i(21, 29)))
	var far: Player = player(d3, "archer", a3.boss.sim.home + Vector2(BossSim.num("sight_px") + 8.0, 0.0))
	a3.boss.wake([seen, far] as Array[Player])
	check(a3.boss.can_target(seen), "sight: outside its room with nothing between: seen")
	check(Combat.line_clear(d3, Combat.body_point(a3.boss.sim.pos), Combat.body_point(far.sim_position)) and not a3.boss.can_target(far),
		"sight: beyond sight_px with nothing between: not a target")
	check_eq(a3.boss.taunt(seen, 400.0, 60), 1, "sight: a taunt with a clear line takes")


func _check_reset_immunity() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "paladin", near_home(a, Vector2(0, 20)))
	var party: Array[Player] = [p]
	a.boss.wake(party)
	check(a.boss.stun(60) and not a.boss.stun(60), "reset: a stun, then immune")
	a.boss.reset("test")
	check_eq(a.boss.sim.stun_immune, 0, "reset: the immunity cleared")
	a.boss.wake(party)
	check(a.boss.stun(60), "reset: the next fight's first stun takes at once")


func _check_adds_at_death() -> void:
	var d: WorldData = open_dungeon()
	d.progress = WorldProgress.new()
	var a: Arena = fight_on(d, test_room())
	var p: Player = player(d, "paladin", near_home(a, Vector2(0, 20)))
	var party: Array[Player] = [p]
	wake_frozen(a, party)
	a.boss.hit(a.boss.sim.hp_max / 2 + 1, p.get_instance_id())
	check_eq(a.alive_heretics(), roundi(Config.BOSS["phase2_adds"]), "adds: phase 2 called them")
	a.boss.hit(a.boss.sim.hp, p.get_instance_id())
	check(not a.boss.sim.alive(), "adds: it died")
	check_eq(a.alive_heretics(), 0 if Config.BOSS_ADDS_LEAVE_AT_DEATH else roundi(Config.BOSS["phase2_adds"]),
		"adds: the arena goes quiet (Config.BOSS_ADDS_LEAVE_AT_DEATH)")
	check_eq(a.boss.stat("adds_left"), roundi(Config.BOSS["phase2_adds"]) if Config.BOSS_ADDS_LEAVE_AT_DEATH else 0, "adds: counted")


func _check_relics_live() -> void:
	var d: WorldData = open_dungeon()
	d.progress = WorldProgress.new()
	var a: Arena = fight_on(d, test_room())
	var leaver: Player = player(d, "miner", near_home(a, Vector2(-20, 20)))
	var gone: Player = player(d, "archer", near_home(a, Vector2(0, 30)))
	var stayer: Player = player(d, "paladin", near_home(a, Vector2(20, 20)))
	var three: Array[Player] = [leaver, gone, stayer]
	run_world(a, three, 1)
	check(a.boss.sim.awake() and a.boss.sim.woke_with == 3, "relics: awake for three")
	a.boss.frozen = true
	_nodes.erase(leaver)
	leaver.free()  # a session member who left: NetMember.remove_player frees the Player at once (before the next tick's frames)
	var up: WorldData = open_dungeon()
	up.map_id = Config.MAP_SURFACE
	gone.set_world(up, Vector2(40.0, 40.0))  # one who took the stairs since the last step: on the other map's data now
	a.boss.hit(a.boss.sim.hp, stayer.get_instance_id())  # the killing blow lands from a member's frame, before the arena's step
	check(not a.boss.sim.alive(), "relics: killed")
	check_eq(stayer.inventory.count_of(Config.BOSS_RELIC), 1, "relics: the one still on the map has his (the freed one skipped)")
	check_eq(gone.inventory.count_of(Config.BOSS_RELIC), 0, "relics: the one gone up since the last step has none")
	check_eq(a.boss.stat("relics"), 1, "relics: one given")
	# players_now (the session host's members on the map now): one who came down since the last step is counted, at the wake too.
	var d2: WorldData = open_dungeon()
	d2.progress = WorldProgress.new()
	var a2: Arena = fight_on(d2, test_room())
	var first: Player = player(d2, "paladin", near_home(a2, Vector2(0, 20)))
	var came: Player = player(d2, "cleric", near_home(a2, Vector2(0, 40)))
	var now: Array[Player] = [first, came]
	a2.boss.players_now = func() -> Array[Player]: return now
	a2.boss.hit(10, first.get_instance_id())
	check_eq(a2.boss.sim.woke_with, 2, "relics: a blow that wakes it counts the players on its map now")
	a2.boss.frozen = true
	a2.boss.hit(a2.boss.sim.hp, first.get_instance_id())
	check(first.inventory.count_of(Config.BOSS_RELIC) == 1 and came.inventory.count_of(Config.BOSS_RELIC) == 1,
		"relics: both on its map at the kill")


func _check_relic_at_cap() -> void:
	var d: WorldData = open_dungeon()
	d.progress = WorldProgress.new()
	var a: Arena = fight_on(d, test_room())
	var full: Player = player(d, "paladin", near_home(a, Vector2(0, 26)))
	for s: int in full.inventory.size():
		full.inventory.add(&"stone_a", Config.STACK_GATHERABLE)
	var one: Array[Player] = [full]
	run_world(a, one, 1)
	a.boss.frozen = true
	for i: int in Config.MAX_DROPS:
		var c: Vector2i = Vector2i(ROOM.position.x + i % ROOM.size.x, ROOM.position.y + 1 + i / ROOM.size.x)
		EditLog.apply_to_data(d, EditLog.WorldEdit.drop_put(WorldData.Drop.new(d.new_drop_id(), &"stone_b", 1,
			ItemDB.normalize_grade(&"stone_b"), c * Config.TILE + Vector2i(8, 8))))
	check_eq(d.drops.size(), Config.MAX_DROPS, "cap: the map holds its most drops")
	var oldest: int = -1
	for id: int in d.drops:
		if oldest < 0 or id < oldest:
			oldest = id
	a.boss.hit(a.boss.sim.hp, full.get_instance_id())
	run_world(a, one, 1)
	check_eq(d.drops.size(), Config.MAX_DROPS, "cap: still the most")
	check(not d.drops.has(oldest), "cap: the oldest drop made room (Config.RELIC_DISPLACES_DROP)")
	var at: Array[WorldData.Drop] = d.drops_at(Aim.feet_cell(full.sim_position))
	var relic: bool = false
	for dr: WorldData.Drop in at:
		relic = relic or dr.item == Config.BOSS_RELIC
	check(relic, "cap: the relic lies at his feet")
	check_eq(a.boss.stat("drops_displaced"), 1, "cap: one drop displaced")


func _check_refused_beside_boss() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room([Vector2i(23, 16)]))
	var f: BossFight = a.boss
	var pal: Player = player(d, "paladin", near_home(a, Vector2(0, 18)))
	var party: Array[Player] = [pal]
	wake_frozen(a, party)
	check_eq(f.melee(pal, Vector2.UP, 64.0, 360.0, 10, false), 1, "beside: the paladin's blow hit the boss")
	check(f.pillars[0].refused_ticks == 0 and f.stat("pillar_refused") == 0, "beside: no refused mark on the pillar it also reached")
	f.sim.pos = f.sim.home + Vector2(0.0, -160.0)
	check_eq(f.melee(pal, Vector2.UP, 64.0, 360.0, 10, false), 0, "beside: away from the boss")
	check(f.pillars[0].refused_ticks > 0 and f.stat("pillar_refused") == 1, "beside: a blow at the pillar alone shows the mark")
	var m: Player = player(d, "miner", near_home(a, Vector2(0, 18)))
	f.sim.pos = f.sim.home
	var hits: int = f.stat("pillar_hits")
	check_eq(f.melee(m, Vector2.UP, 64.0, 360.0, 10, true), 1, "beside: the miner's pick hit the boss")
	check_eq(f.stat("pillar_hits"), hits + 1, "beside: and the pillar in the same swing")


func _check_dead_site() -> void:
	var d: WorldData = open_dungeon()
	d.progress = WorldProgress.new()
	d.progress.defeat_boss()
	var a: Arena = fight_on(d, test_room([Vector2i(14, 12), Vector2i(28, 20)]))
	check(not a.boss.sim.alive(), "dead site: lying there (the flag)")
	var end: Array[int] = [0]
	var bytes: PackedByteArray = WorldSnapshot.site_bytes(a.boss.site())
	var got: BossFight.Site = WorldSnapshot.read_site(bytes, 1, d.size, end)
	if check(got != null, "dead site: its site decodes (the rubble at the broken count)"):
		for i: int in got.pillars.size():
			check(got.fallen[i] and got.hits[i] == BossFight.Pillar.hits_per_state() * 3, "dead site: pillar %d rubble" % i)
	var ev: NetProtocol.ShotEvents = NetProtocol.decode_shots(NetProtocol.encode_shots(Config.MAP_DUNGEON,
		[a.boss.pillar_event(0)] as Array[NetProtocol.ShotEvent]))
	check(ev.ok and ev.events.size() == 1, "dead site: its pillar event decodes")
