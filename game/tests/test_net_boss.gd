extends "res://tests/test_net_combat.gd"
## M12c: the boss, the cracked pillars, the relic and the altar's tier in sessions, in one process: the real SessionHost and SessionClient flows on
## the rig of tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients' packets back). tests/test_net_leader.gd
## runs real sessions.
##   - the wire (protocol v14): the enemy batch's boss block, the six boss events, the world message, the progress block and the boss site in a
##     snapshot: round trips, sizes, every truncation, every field out of range; the generated hashes stay golden, the tier moves the surface's
##   - the host against a malicious client: a non-miner's blow on a pillar (the refused mark on every machine), an altar upgrade without a relic
##     (never seen, seen and gone, a GIVE in a release), far from the bench, at tier 1, naming the other map, a stale recipe index, while down,
##     spam past the request budget: refused with nothing spent
##   - flows: nothing sent while the boss rests; the three telegraphs drawn on every client where and when the host has them (the cleave's
##     wedge, the volley's lines and bolts, the burning circles and their eruption); a pillar broken by the miner, its dust and its debris
##     landing on every machine on the host's tick (12% of the boss's HP, the rubble walkable everywhere); a client's killing blow, one relic for
##     each player on the dungeon, the flag on every machine; a client's altar upgrade: candA, 9 tiles of light and the host's spawn tiles on every
##     machine; late joiners mid-fight (the attack, the bolts, the circles, a falling pillar), after the kill and after the upgrade; traffic
##     during a fight; a version 13 hello is refused
##   - M12c-fix (review): the relics at the kill go to the members on the dungeon at that moment: a member who left in the poll right before a
##     client's killing frame (its Player freed, the host on the surface) is skipped and every one still there gets its relic and its inventory;
##     members who took the stairs either way since the last step count where they are; a death on a tick that is a multiple of 65536 still
##     sends its start (not "lying already")

const MINER: String = "miner"
const PALADIN: String = "paladin"
const ARCHER: String = "archer"
const CLERIC: String = "cleric"
## IMPL (tests): how far a bolt drawn on a client may be from the host's (px: the wire's angle units over a bolt's range), how far its direction
## (radians).
const BOLT_BOUND_PX: float = 0.1
const ANGLE_BOUND: float = 0.001
## IMPL (tests, README "측정" M12c): the most enemy-batch bytes and boss-event bytes a second one client may get while two players fight the boss
## (no heretics: 20 batches of 8 + 17 B, and the events of an attack a second at most, five bolts and three circles included).
const FIGHT_ENEMY_MAX_BPS: float = 520.0
const FIGHT_EVENTS_MAX_BPS: float = 260.0


func run() -> Array[String]:
	_check_boss_codec()
	_check_event_codec()
	_check_world_codec()
	_check_site_snapshot()
	await _check_rest_is_quiet()
	await _check_reset_on_clients()
	await _check_pillar_blows()
	await _check_telegraphs_and_debris()
	await _check_stun_stops_telegraph()
	await _check_upgrade_refusals()
	await _check_upgrade_flow()
	await _check_boss_late_join()
	await _check_boss_traffic()
	await _check_v13_refused()
	_check_relics_at_a_leave()  # M12c-fix
	_check_relics_at_travel()  # M12c-fix
	_check_death_since()  # M12c-fix
	return failures


# --- helpers ------------------------------------------------------------------------------------------------------

## A rig with the host's own player (`host_class`) in the dungeon outside the boss's room (its arrival point), the fight's test HP `hp` (0 = its
## scaling).
func _boss_rig(host_class: String, hp: int = 0) -> Rig:
	var r: Rig = _rig(host_class)
	r.host.move_to_map(r.s.local, Config.MAP_DUNGEON)
	r.host.boss_fight().test_hp = hp
	return r


## Client `c` (joined on the surface) goes down to the dungeon and stands at `at` there; returns once its map entry came.
func _down(r: Rig, c: Client, at: Vector2) -> void:
	var m: NetMember = hm(r, c)
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	m.player.teleport(at)
	for i: int in 6 + r.delay:
		_tick(r)
		if c.s.local.map_id == Config.MAP_DUNGEON and not r.host.streams.has(c.peer):
			break


## The feet in the middle of the room's tile `home` + `off`.
static func room_feet(f: BossFight, off: Vector2i) -> Vector2:
	return Arena.spawn_feet(f.room.home_tile + off)


## The free tile just south of pillar `i` (the margin keeps a ring round it open).
static func below_pillar(f: BossFight, i: int) -> Vector2i:
	return f.pillars[i].tile + Vector2i(0, 1)


## Client `c`'s mirror fight drawn at the host's tick now (t_fresh = it: the rig delivers within the tick).
func _mirror(r: Rig, c: Client) -> BossFight:
	c.s.client.combat.sample(float(r.s.tick), SessionClient.interp_delay_ticks())
	return c.s.client.combat.arena.boss


## The pillars' picture states of fight `f` ("0123").
static func looks(f: BossFight) -> String:
	return SessionHost._looks(f)


static func craft_frame(map: int, recipe: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i.ZERO)
	f.op = NetProtocol.Op.CRAFT
	f.map = map
	f.recipe = recipe
	return f


## A relic bench on the host's surface whose footprint starts at `at` (cell edits: every client gets them).
static func put_bench(r: Rig, at: Vector2i) -> void:
	for x: int in Config.RELIC_BENCH_FOOTPRINT.x:
		r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at + Vector2i(x, 0), WorldData.PLACEABLE_RELIC),
			Config.MAP_SURFACE)


static func host_lines(r: Rig, prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in r.s.logged:
		if line.begins_with(prefix):
			out.append(line)
	return out


# --- the wire -----------------------------------------------------------------------------------------------------

func _boss_state() -> NetProtocol.BossState:
	var o: NetProtocol.BossState = NetProtocol.BossState.new()
	o.pos = Vector2(812.25, 610.5)
	o.facing = RigData.Dir.WEST
	o.state = BossSim.State.ATTACK
	o.attack = BossSim.Attack.VOLLEY
	o.phase = 2
	o.since = 40000
	o.hp = 1500
	o.hp_max = BossSim.hp_for(3)
	o.flash = 4
	o.stunned = false
	o.slowed = true
	o.taunted = true
	o.poisoned = true
	o.exposed = true
	return o


func _check_boss_codec() -> void:
	check_eq(NetProtocol.BOSS_SIZE, 17, "the boss block: 17 B")
	var e: NetProtocol.EnemyState = NetProtocol.EnemyState.new()
	e.id = 7
	e.pos = Vector2(100.5, 200.25)
	e.hp = 20
	var heretics: Array[NetProtocol.EnemyState] = [e]
	var o: NetProtocol.BossState = _boss_state()
	var bytes: PackedByteArray = NetProtocol.encode_enemies(70001, Config.MAP_DUNGEON, 0, heretics, o)
	check_eq(bytes.size(), NetProtocol.ENEMY_HEADER + NetProtocol.ENEMY_SIZE + NetProtocol.BOSS_SIZE, "a batch with one heretic and the boss")
	var b: NetProtocol.EnemyBatch = NetProtocol.decode_enemies(bytes)
	check(b.ok and b.enemies.size() == 1 and b.enemies[0].same_as(e) and b.boss != null and b.boss.same_as(o), "round trip")
	var plain: PackedByteArray = NetProtocol.encode_enemies(70001, Config.MAP_DUNGEON, 0, heretics)
	var pb: NetProtocol.EnemyBatch = NetProtocol.decode_enemies(plain)
	check(pb.ok and pb.boss == null and plain.size() == NetProtocol.ENEMY_HEADER + NetProtocol.ENEMY_SIZE, "without it: v13's bytes, no boss")
	for n: int in range(NetProtocol.ENEMY_HEADER + NetProtocol.ENEMY_SIZE + 1, bytes.size()):
		check(not NetProtocol.decode_enemies(bytes.slice(0, n)).ok, "cut at %d is refused" % n)
	var more: PackedByteArray = bytes.duplicate()
	more.append(0)
	check(not NetProtocol.decode_enemies(more).ok, "a byte more is refused")
	var surface: PackedByteArray = NetProtocol.encode_enemies(9, Config.MAP_SURFACE, 0, heretics, o)
	check(not NetProtocol.decode_enemies(surface).ok, "a boss block on the surface's batch is refused")
	var at: int = NetProtocol.ENEMY_HEADER + NetProtocol.ENEMY_SIZE
	var bad: Array[Array] = []
	var w: PackedByteArray = bytes.duplicate()
	w[at] = w[at] | 0x80
	bad.append([w, "the flags' reserved bit"])
	w = bytes.duplicate()
	w[at + 1] = w[at + 1] | 0x80
	bad.append([w, "the info's reserved bit"])
	w = bytes.duplicate()
	w[at] = (w[at] & 0xC7) | (5 << 3)
	bad.append([w, "a state past DEAD"])
	w = bytes.duplicate()
	w[at + 1] = w[at + 1] & 0xFC
	bad.append([w, "ATTACK without its attack"])
	w = bytes.duplicate()
	w[at] = (w[at] & 0xC7) | (BossSim.State.CHASE << 3)
	bad.append([w, "an attack outside ATTACK"])
	w = bytes.duplicate()
	w.encode_u16(at + 12, o.hp_max + 1)
	bad.append([w, "HP above its max"])
	w = bytes.duplicate()
	w.encode_u16(at + 14, BossSim.hp_for(BossSim.num_i("players_cap")) + 1)
	bad.append([w, "a max above the most it wakes with"])
	w = bytes.duplicate()
	w.encode_u16(at + 14, 0)
	w.encode_u16(at + 12, 0)
	bad.append([w, "a max of 0"])
	w = bytes.duplicate()
	w.encode_u16(at + 12, 0)
	bad.append([w, "alive at 0 HP"])
	w = bytes.duplicate()
	w.encode_u8(at + 16, Config.BOSS_FLASH_TICKS + 1)
	bad.append([w, "a flash past its time"])
	w = bytes.duplicate()
	w.encode_float(at + 2, NAN)
	bad.append([w, "a NaN"])
	var chase: NetProtocol.BossState = _boss_state()
	chase.state = BossSim.State.CHASE
	chase.attack = BossSim.Attack.NONE
	chase.since = 0
	w = NetProtocol.encode_enemies(5, Config.MAP_DUNGEON, 0, [] as Array[NetProtocol.EnemyState], chase)
	check(NetProtocol.decode_enemies(w).ok, "a chasing boss with no start (since 0 for an untimed state)")
	w = NetProtocol.encode_enemies(5, Config.MAP_DUNGEON, 0, [] as Array[NetProtocol.EnemyState], chase)
	w.encode_u16(NetProtocol.ENEMY_HEADER + 10, 5)
	bad.append([w, "a start for an untimed state"])
	var dead: NetProtocol.BossState = NetProtocol.BossState.new()
	dead.state = BossSim.State.DEAD
	dead.hp = 0
	dead.hp_max = 1200
	w = NetProtocol.encode_enemies(5, Config.MAP_DUNGEON, 0, [] as Array[NetProtocol.EnemyState], dead)
	check(NetProtocol.decode_enemies(w).ok, "a dead boss")
	var dead_hp: PackedByteArray = w.duplicate()
	dead_hp.encode_u16(NetProtocol.ENEMY_HEADER + 12, 1)
	bad.append([dead_hp, "a dead boss with HP"])
	var dead_mark: PackedByteArray = w.duplicate()
	dead_mark[NetProtocol.ENEMY_HEADER + 1] = NetProtocol.BOSS_MARK_STUNNED
	bad.append([dead_mark, "a dead boss with a mark"])
	for row: Array in bad:
		var bb: PackedByteArray = row[0]
		check(not NetProtocol.decode_enemies(bb).ok, "%s is refused" % str(row[1]))
	# boss_of: a real fight's boss; none while it rests.
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var a: Arena = Arena.new()
	a.setup(d, Config.DEFAULT_SEED)
	a.boss = BossFight.new()
	a.boss.setup(a, Config.DEFAULT_SEED)
	check(NetProtocol.boss_of(a.boss, 10) == null, "asleep: no block")
	var p: Player = Player.new()
	p.setup(d, PALADIN, a.boss.sim.home + Vector2(0, 20))
	var players: Array[Player] = [p]
	a.boss.wake(players)
	var awake: NetProtocol.BossState = NetProtocol.boss_of(a.boss, 10)
	check(awake != null and awake.state == BossSim.State.CHASE and awake.hp == BossSim.hp_for(1) and awake.since == 0, "awake: its block")
	a.boss.begin_attack(BossSim.Attack.CLEAVE, p, players)
	var att: NetProtocol.BossState = NetProtocol.boss_of(a.boss, 900)
	check(att.state == BossSim.State.ATTACK and att.attack == BossSim.Attack.CLEAVE and att.since == 900, "an attack: its start tick")
	a.boss.frozen = true
	a.boss.hit(a.boss.sim.hp_max, p.get_instance_id())
	var dying: NetProtocol.BossState = NetProtocol.boss_of(a.boss, 1000)
	check(dying != null and dying.state == BossSim.State.DEAD and dying.since == 1000 and dying.hp == 0, "dying: its death frames' start")
	a.boss.sim.state_ticks = NetProtocol.boss_death_ticks()
	check(NetProtocol.boss_of(a.boss, 1100) == null, "lying dead: no block")
	p.free()


func _event(kind: int) -> NetProtocol.ShotEvent:
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = kind
	e.tick = 123456
	e.pos = Vector2(400.5, 300.75)
	match kind:
		NetProtocol.ShotEvent.Kind.BOSS_ATTACK:
			e.sub = BossSim.Attack.VOLLEY
			e.face = RigData.Dir.NORTH
			e.angle = NetProtocol.wire_angle(NetProtocol.angle_code(-2.0))
			e.base = NetProtocol.wire_angle(NetProtocol.angle_code(1.25))
			e.count = 5
		NetProtocol.ShotEvent.Kind.BOSS_STOP:
			e.pos = Vector2.ZERO
			e.flags = NetProtocol.BOSS_STOP_ATTACK | NetProtocol.BOSS_STOP_FIRE
		NetProtocol.ShotEvent.Kind.BOLT:
			e.id = 77
			e.angle = NetProtocol.wire_angle(NetProtocol.angle_code(3.0))
		NetProtocol.ShotEvent.Kind.BOLT_END:
			e.id = 77
			e.why = 1
		NetProtocol.ShotEvent.Kind.CIRCLE:
			e.id = 78
			e.radius = 18.0
			e.ticks = 60
		NetProtocol.ShotEvent.Kind.PILLAR:
			e.pos = Vector2.ZERO
			e.id = 3
			e.hits = 9
			e.falling = -1
			e.flags = NetProtocol.PILLAR_FALLEN | NetProtocol.PILLAR_LANDED | NetProtocol.PILLAR_BOSS | (2 << NetProtocol.PILLAR_PLAYERS_SHIFT)
	return e


func _check_event_codec() -> void:
	var sizes: Dictionary[int, int] = {NetProtocol.ShotEvent.Kind.BOSS_ATTACK: 18, NetProtocol.ShotEvent.Kind.BOSS_STOP: 6,
		NetProtocol.ShotEvent.Kind.BOLT: 19, NetProtocol.ShotEvent.Kind.BOLT_END: 18, NetProtocol.ShotEvent.Kind.CIRCLE: 19,
		NetProtocol.ShotEvent.Kind.PILLAR: 9}
	var all: Array[NetProtocol.ShotEvent] = []
	for kind: int in sizes:
		var e: NetProtocol.ShotEvent = _event(kind)
		all.append(e)
		var bytes: PackedByteArray = NetProtocol.encode_shots(Config.MAP_DUNGEON, [e] as Array[NetProtocol.ShotEvent])
		check_eq(bytes.size(), 2 + sizes[kind], "event kind %d: %d B" % [kind, sizes[kind]])
		var s: NetProtocol.ShotEvents = NetProtocol.decode_shots(bytes)
		check(s.ok and s.events.size() == 1 and s.events[0].same_as(e), "event kind %d round trips" % kind)
		for n: int in range(2, bytes.size()):
			check(not NetProtocol.decode_shots(bytes.slice(0, n)).ok, "event kind %d cut at %d is refused" % [kind, n])
	var together: NetProtocol.ShotEvents = NetProtocol.decode_shots(NetProtocol.encode_shots(Config.MAP_DUNGEON, all))
	check(together.ok and together.events.size() == all.size(), "all six in one message")
	check_eq(NetProtocol.angle_code(PI), NetProtocol.angle_code(-PI), "an angle's code wraps round")
	check(absf(NetProtocol.wire_angle(NetProtocol.angle_code(0.7)) - 0.7) < TAU / NetProtocol.ANGLE_UNITS, "within one unit")
	var bad: Array[Array] = []
	var att: NetProtocol.ShotEvent = _event(NetProtocol.ShotEvent.Kind.BOSS_ATTACK)
	var raw: PackedByteArray = NetProtocol.encode_shots(Config.MAP_DUNGEON, [att] as Array[NetProtocol.ShotEvent])
	var w: PackedByteArray = raw.duplicate()
	w[2 + 5] = w[2 + 5] & 0xFC
	bad.append([w, "an attack of none"])
	w = raw.duplicate()
	w[2 + 5] = w[2 + 5] & 0x0F
	bad.append([w, "a volley without bolts"])
	w = raw.duplicate()
	w[2 + 5] = (w[2 + 5] & 0xFC) | BossSim.Attack.CLEAVE
	bad.append([w, "a cleave with bolts"])
	w = raw.duplicate()
	w.encode_float(2 + 6, INF)
	bad.append([w, "an attack at infinity"])
	var stop: PackedByteArray = NetProtocol.encode_shots(Config.MAP_DUNGEON, [_event(NetProtocol.ShotEvent.Kind.BOSS_STOP)] as Array[NetProtocol.ShotEvent])
	w = stop.duplicate()
	w[2 + 5] = 0
	bad.append([w, "a stop naming nothing"])
	w = stop.duplicate()
	w[2 + 5] = 4
	bad.append([w, "a stop's unknown bit"])
	var end: PackedByteArray = NetProtocol.encode_shots(Config.MAP_DUNGEON, [_event(NetProtocol.ShotEvent.Kind.BOLT_END)] as Array[NetProtocol.ShotEvent])
	w = end.duplicate()
	w[2 + 17] = NetProtocol.BOLT_STOPS.size()
	bad.append([w, "a bolt's why past the table"])
	var circ: PackedByteArray = NetProtocol.encode_shots(Config.MAP_DUNGEON, [_event(NetProtocol.ShotEvent.Kind.CIRCLE)] as Array[NetProtocol.ShotEvent])
	w = circ.duplicate()
	w[2 + 17] = 0
	bad.append([w, "a circle of radius 0"])
	w = circ.duplicate()
	w[2 + 18] = 0
	bad.append([w, "a circle with no telegraph"])
	var pil: PackedByteArray = NetProtocol.encode_shots(Config.MAP_DUNGEON, [_event(NetProtocol.ShotEvent.Kind.PILLAR)] as Array[NetProtocol.ShotEvent])
	w = pil.duplicate()
	w[2 + 1] = NetProtocol.PILLARS_MAX
	bad.append([w, "a pillar past the most a site names"])
	w = pil.duplicate()
	w[2 + 6] = BossFight.Pillar.hits_per_state() * 3 + 1
	bad.append([w, "hits past the broken state's"])
	w = pil.duplicate()
	w[2 + 6] = 5
	bad.append([w, "rubble that is not broken"])
	w = pil.duplicate()
	w[2 + 8] = 0
	w[2 + 7] = roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1
	bad.append([w, "dust past the telegraph"])
	w = pil.duplicate()
	w[2 + 8] = 0
	w[2 + 6] = 4
	w[2 + 7] = 10
	bad.append([w, "dust on a pillar not broken"])
	w = pil.duplicate()
	w[2 + 8] = NetProtocol.PILLAR_BOSS
	w[2 + 6] = 2
	bad.append([w, "the debris's boss bit without a landing"])
	w = pil.duplicate()
	w[2 + 8] = NetProtocol.PILLAR_LANDED
	bad.append([w, "a landing that left no rubble"])
	for row: Array in bad:
		var bb: PackedByteArray = row[0]
		check(not NetProtocol.decode_shots(bb).ok, "%s is refused" % str(row[1]))
	check_eq(NetProtocol.SHOT_STOPS.find("pillar"), 6, "a shot stopped by a pillar has its own why")
	check_eq(NetProtocol.SHOT_STOPS.find("boss"), 7, "and one stopped by the boss")


func _check_world_codec() -> void:
	check_eq(NetProtocol.WORLD_SIZE, 8, "the world message: 8 B")
	var col: Collection = Collection.new()
	col.put_test(3, 44)
	var progress: WorldProgress = WorldProgress.new()
	progress.raise_altar()
	progress.defeat_boss()
	var bytes: PackedByteArray = NetProtocol.encode_world(col, progress)
	check_eq(bytes.size(), NetProtocol.WORLD_SIZE, "its size")
	var w: NetProtocol.WorldState = NetProtocol.decode_world(bytes)
	check(w.ok and w.bits == 0b111 and w.kills == 44 and w.tier == 1 and w.defeated, "round trip")
	var none: NetProtocol.WorldState = NetProtocol.decode_world(NetProtocol.encode_world(null, null))
	check(none.ok and none.bits == 0 and none.tier == 0 and not none.defeated, "nothing yet")
	for n: int in bytes.size():
		check(not NetProtocol.decode_world(bytes.slice(0, n)).ok, "cut at %d is refused" % n)
	var more: PackedByteArray = bytes.duplicate()
	more.append(0)
	check(not NetProtocol.decode_world(more).ok, "a byte more is refused")
	var t: PackedByteArray = bytes.duplicate()
	t[NetProtocol.COLLECTION_SIZE] = Config.ALTAR_TIER_MAX + 1
	check(not NetProtocol.decode_world(t).ok, "a tier past the slice's maximum is refused")
	var f2: PackedByteArray = bytes.duplicate()
	f2[NetProtocol.COLLECTION_SIZE + 1] = 2
	check(not NetProtocol.decode_world(f2).ok, "a defeated flag of 2 is refused")
	var e: PackedByteArray = bytes.duplicate()
	e.encode_u16(0, 1 << Collection.total())
	check(not NetProtocol.decode_world(e).ok, "an entry the table does not have is refused")


func _check_site_snapshot() -> void:
	# The dungeon with the host's fight: its site comes with it, the content hash stays the generated one's.
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var bare: PackedByteArray = WorldSnapshot.raw_bytes(d)
	check_eq(bare.slice(bare.size() - 2), PackedByteArray([0, 0]), "a generated dungeon: no progress, no site (a 0 each)")
	var a: Arena = Arena.new()
	a.setup(d, Config.DEFAULT_SEED)
	a.boss = BossFight.new()
	a.boss.setup(a, Config.DEFAULT_SEED)
	d.progress = WorldProgress.new()
	a.boss.set_pillar_hits(0, 5)
	a.boss.set_pillar_hits(1, BossFight.Pillar.hits_per_state() * 3)
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(d)
	var n: int = a.boss.pillars.size()
	check_eq(raw.size(), bare.size() + WorldSnapshot.PROGRESS_BYTES + WorldSnapshot.SITE_BYTES + WorldSnapshot.SITE_PILLAR_BYTES * n,
		"the progress (2 B) and the site (11 B + 6 B a pillar) after their flags")
	check_eq(d.content_hash(), DungeonGen.GOLDEN_HASH, "the dungeon's hash stays golden with the fight, its pillars and the progress on it")
	var back: WorldData = WorldSnapshot.decode_raw(raw)
	check(back != null and back.boss_site != null and back.boss_site.describe() == a.boss.site().describe(), "the site comes across (%s)" % (
		back.boss_site.describe() if back != null and back.boss_site != null else "none"))
	check(back != null and back.progress != null and back.progress.altar_tier == 0 and not back.progress.boss_defeated, "the progress too")
	check(back != null and back.content_hash() == d.content_hash() and back.blockers.is_empty(), "the same hash; no blocker until a mirror")
	var arena2: Arena = Arena.mirror(back)
	var mirror: BossFight = BossFight.mirror(arena2, back.boss_site, false)
	check(looks(mirror) == looks(a.boss) and back.blockers.size() == d.blockers.size(), "a mirror: the same looks (%s) and blockers" % looks(mirror))
	# The surface: the tier in its hash once above 0 only.
	var s: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	s.progress = WorldProgress.new()
	check_eq(s.content_hash(), SurfaceGen.GOLDEN_HASH, "the surface at tier 0 hashes golden")
	s.progress.raise_altar()
	var raised: String = s.content_hash()
	check(raised != SurfaceGen.GOLDEN_HASH, "tier 1 moves the surface's hash")
	var sb: WorldData = WorldSnapshot.decode_raw(WorldSnapshot.raw_bytes(s))
	check(sb != null and sb.progress.altar_tier == 1 and sb.content_hash() == raised and sb.boss_site == null, "and comes across")
	d.progress.altar_tier = 1
	check_eq(d.content_hash(), DungeonGen.GOLDEN_HASH, "the dungeon's hash does not carry the tier")
	d.progress.altar_tier = 0
	# Every way it can be wrong.
	var site_at: int = bare.size() - 2 + 1 + WorldSnapshot.PROGRESS_BYTES  # bare ends with the progress and site flags
	check_eq(raw[site_at], 1, "the site's flag")
	var bad: Array[Array] = []
	var w: PackedByteArray = raw.duplicate()
	w[site_at] = 2
	bad.append([w, "a site flag of 2"])
	w = raw.duplicate()
	w[site_at - 1 - WorldSnapshot.PROGRESS_BYTES] = 2
	bad.append([w, "a progress flag of 2"])
	w = raw.duplicate()
	w[site_at - 2] = Config.ALTAR_TIER_MAX + 1
	bad.append([w, "a tier past the maximum"])
	w = raw.duplicate()
	w[site_at - 1] = 2
	bad.append([w, "a defeated flag of 2"])
	w = raw.duplicate()
	w.encode_u16(site_at + 1, d.size.x - 2)
	bad.append([w, "a room off the map"])
	w = raw.duplicate()
	w.encode_u8(site_at + 6, 1)
	bad.append([w, "a room with no walkable row"])
	w = raw.duplicate()
	w.encode_u16(site_at + 8, a.boss.room.room.position.y)
	bad.append([w, "the home on the face row"])
	var p0: int = site_at + 1 + WorldSnapshot.SITE_BYTES
	w = raw.duplicate()
	w.encode_u16(p0, a.boss.room.room.end.x)
	bad.append([w, "a pillar off the room"])
	w = raw.duplicate()
	w.encode_u16(p0, a.boss.room.home_tile.x)
	w.encode_u16(p0 + 2, a.boss.room.home_tile.y)
	bad.append([w, "a pillar on the home"])
	w = raw.duplicate()
	w.encode_u16(p0 + WorldSnapshot.SITE_PILLAR_BYTES, a.boss.pillars[0].tile.x)
	w.encode_u16(p0 + WorldSnapshot.SITE_PILLAR_BYTES + 2, a.boss.pillars[0].tile.y)
	bad.append([w, "a pillar twice"])
	w = raw.duplicate()
	w.encode_u8(p0 + 4, BossFight.Pillar.hits_per_state() * 3 + 1)
	bad.append([w, "hits past the broken state's"])
	w = raw.duplicate()
	w.encode_u8(p0 + 5, 1)
	bad.append([w, "rubble of a pillar with 5 hits"])
	w = raw.duplicate()
	w.encode_u8(p0 + 5, 2)
	bad.append([w, "a rubble flag of 2"])
	w = raw.duplicate()
	w.encode_u8(site_at + 11, NetProtocol.PILLARS_MAX + 1)
	bad.append([w, "more pillars than a site may name"])
	w = raw.duplicate()
	w.append(0)
	bad.append([w, "a byte after it"])
	bad.append([raw.slice(0, raw.size() - 1), "a byte short"])
	bad.append([raw.slice(0, site_at), "the site's flag cut off"])
	for row: Array in bad:
		var bb: PackedByteArray = row[0]
		check(WorldSnapshot.decode_raw(bb) == null, "%s is refused" % str(row[1]))
	var on_surface: PackedByteArray = WorldSnapshot.raw_bytes(s).slice(0, -1)
	on_surface.append_array(WorldSnapshot.site_bytes(a.boss.site()))
	check(WorldSnapshot.decode_raw(on_surface) == null, "a boss site on the surface's snapshot is refused")


# --- flows -----------------------------------------------------------------------------------------------------------

## A resting boss sends nothing: two players standing in the dungeon outside its room, 300 ticks: no enemy byte; the client draws it asleep
## at home from the snapshot's site, its pillars whole and blocking where the host's do.
func _check_rest_is_quiet() -> void:
	var r: Rig = _boss_rig(MINER)
	var f: BossFight = r.host.boss_fight()
	var c: Client = _join(r, 101, PALADIN)
	_down(r, c, r.dungeon.arrival_point())
	check_eq(c.s.local.map_id, Config.MAP_DUNGEON, "rest: the client is down")
	_tick(r, 30)
	var before: int = c.batches.size()
	var bytes0: int = r.bytes_by_kind.get("enemies", 0) + r.bytes_by_kind.get("enemy_key", 0) + r.bytes_by_kind.get("shots", 0)
	_tick(r, 300)
	var bytes1: int = r.bytes_by_kind.get("enemies", 0) + r.bytes_by_kind.get("enemy_key", 0) + r.bytes_by_kind.get("shots", 0)
	check(c.batches.size() == before and bytes1 == bytes0, "rest: 300 ticks of a sleeping boss, nothing sent (%d B)" % (bytes1 - bytes0))
	var nb: NetBoss = c.s.client.combat.boss
	check(nb != null and c.s.client.combat.arena.boss != null, "rest: the client has the mirror fight")
	var mf: BossFight = _mirror(r, c)
	check(mf.sim.state == BossSim.State.SLEEP and mf.sim.pos == f.sim.home and mf.room.room == f.room.room, "rest: asleep at home in the room")
	check(looks(mf) == "0".repeat(f.pillars.size()) and c.dungeon.data.blockers == r.dungeon.data.blockers,
		"rest: the pillars whole, blocking as the host's (%s)" % looks(mf))
	_free_rig(r)


## A fight left alone resets on every machine: the boss woken by the client, a pillar cracked, both players out of its room; after
## Config.BOSS reset_ticks it walks home and resets on the host, and the client draws it asleep at home (no block any more: it rests), the
## pillar whole and blocking again (its restoring event).
func _check_reset_on_clients() -> void:
	var r: Rig = _boss_rig(CLERIC)
	var f: BossFight = r.host.boss_fight()
	f.frozen = true
	var c: Client = _join(r, 101, PALADIN)
	_down(r, c, room_feet(f, Vector2i(-2, 1)))
	_tick(r, 4)
	check(f.sim.awake(), "reset: the client woke it")
	f.set_pillar_hits(0, BossFight.Pillar.hits_per_state() + 1)
	_tick(r, 2)
	check_eq(looks(_mirror(r, c)), looks(f), "reset: the cracked pillar on the client")
	hm(r, c).player.teleport(r.dungeon.arrival_point())
	var t: int = 0
	while f.sim.state != BossSim.State.SLEEP and t < BossSim.num_i("reset_ticks") + 600:
		_tick(r)
		t += 1
	_tick(r, 12)
	check(f.sim.state == BossSim.State.SLEEP and f.pillars[0].hits == 0, "reset: home and reset on the host after %d ticks" % t)
	var mf: BossFight = _mirror(r, c)
	check(mf.sim.state == BossSim.State.SLEEP and mf.sim.pos == f.sim.home and mf.sim.hp == f.sim.hp_max,
		"reset: the client draws it asleep at home, full (%s)" % BossSim.STATE_NAMES[mf.sim.state])
	check(looks(mf) == looks(f) and c.dungeon.data.blockers == r.dungeon.data.blockers, "reset: the pillar whole and blocking again")
	check(NetProtocol.boss_of(f, r.s.tick) == null, "reset: it rests (no block)")
	_free_rig(r)


## Blows on the pillars from clients: a paladin's sword is refused (no hit, the refused mark drawn on every client at the host's tick), an
## archer's arrow stops at it refused (its stop says why), the miner client's pick lands: the crack state on every machine.
func _check_pillar_blows() -> void:
	var r: Rig = _boss_rig(CLERIC)
	var f: BossFight = r.host.boss_fight()
	f.frozen = true  # it wakes when they come in; it stands (its attacks are the next checks')
	var pal: Client = _join(r, 101, PALADIN)
	var arch: Client = _join(r, 102, ARCHER)
	var mine: Client = _join(r, 103, MINER)
	var i: int = 0
	var below: Vector2i = below_pillar(f, i)
	_down(r, pal, Arena.spawn_feet(below))
	var toward: Vector2i = f.room.home_tile - f.pillars[i].tile  # two tiles from the pillar toward the home (inside the room, nothing between)
	var step: Vector2i = Vector2i(signi(toward.x), 0) if absi(toward.x) >= absi(toward.y) else Vector2i(0, signi(toward.y))
	_down(r, arch, Arena.spawn_feet(f.pillars[i].tile + step * 2))
	_down(r, mine, Arena.spawn_feet(below + Vector2i(1, 0)))
	_tick(r, 4)
	var centre: Vector2 = f.pillars[i].centre()
	pal.action = swing_at(centre)
	_tick(r, PlayerSim.action_ticks(RigData.Anim.SWORD) + 2)
	pal.action = null
	_tick(r, 2)
	check(f.pillars[i].hits == 0 and f.stat("pillar_refused") >= 1, "a client paladin's sword on a pillar: refused on the host (hits %d)" % f.pillars[i].hits)
	check(host_lines(r, "boss pillar %d refused by=paladin: miner only" % i).size() >= 1, "and logged")
	for c: Client in [pal, arch, mine]:
		check(c.s.client.combat.boss.refused_seen >= 1, "peer %d: the refused mark came" % c.peer)
	var tick_refused: int = r.s.tick
	var mf: BossFight = _mirror(r, arch)
	check(mf.pillars[i].refused_ticks > 0 and mf.pillars[i].hits == 0, "the archer draws it refused (%d ticks left)" % mf.pillars[i].refused_ticks)
	var refused_before: int = f.stat("pillar_refused")
	var feet: Vector2 = hm(r, arch).player.sim_position
	arch.action = swing_at(Vector2(centre.x, feet.y) + (Combat.body_centre(feet) - feet))  # level with its body: the arrow's line crosses the tile
	_tick(r, PlayerSim.action_ticks(RigData.Anim.BOW) + 30)
	arch.action = null
	check(f.stat("pillar_refused") > refused_before and f.pillars[i].hits == 0, "an arrow at it: refused too")
	var stops: Array[int] = []
	for e: NetProtocol.ShotEvent in arch.shot_events:
		if e.kind == NetProtocol.ShotEvent.Kind.END:
			stops.append(e.why)
	check(stops.has(NetProtocol.SHOT_STOPS.find("pillar")), "the arrow's stop says pillar (%s; host %s)" % [str(stops),
		str(r.host.arenas[Config.MAP_DUNGEON].stats)])
	# A pickaxe in the paladin's hands is still no miner's blow (● R11 class-only column: the class, not the tool).
	var pm: NetMember = hm(r, pal)
	pm.player.inventory.add(Mining.PICKAXE, 1)
	pm.inventory_dirty = true
	_tick(r, 3)
	var pick_slot: int = SessionHost.slot_with(pal.s.local.player.inventory, Mining.PICKAXE)
	check(pick_slot >= 0 and pick_slot < Config.HOTBAR_SLOTS, "the paladin client holds a pickaxe in its hotbar (slot %d)" % pick_slot)
	pal.action = _select(pick_slot)
	_tick(r, 2)
	var refused_pick: int = f.stat("pillar_refused")
	pal.action = swing_at(centre)
	_tick(r, PlayerSim.action_ticks(RigData.Anim.PICKAXE) + 2)
	pal.action = null
	_tick(r, 2)
	check(f.pillars[i].hits == 0 and f.stat("pillar_refused") > refused_pick, "a paladin's pickaxe on a pillar: refused (hits %d)" % f.pillars[i].hits)
	# The miner's pick: three blows, the first crack state on every machine.
	for k: int in 3:
		mine.action = swing_at(centre)
		_tick(r, PlayerSim.action_ticks(RigData.Anim.PICKAXE) + 1)
	mine.action = null
	_tick(r, 3)
	check_eq(f.pillars[i].hits, 3, "the miner client's pick: three hits on the host")
	for c2: Client in [pal, arch, mine]:
		check_eq(looks(_mirror(r, c2)), looks(f), "peer %d draws the host's crack states" % c2.peer)
	note("pillar blows: refused at %d, looks %s" % [tick_refused, looks(f)])
	_free_rig(r)


## The three attacks one after the other at three players in the room (the host's miner, two clients): every tick of each telegraph, both
## clients draw the attack the host has (its kind, its age, where the boss stands, its direction, a volley's lines), then the bolts where
## the host's fly and stop, the circles with the host's age and eruption. Then a pillar the miner breaks over the boss: its dust on every
## machine as the host counts it, the debris on the host's tick (12% of the boss's max HP) and the rubble walkable everywhere. Then the
## paladin client's killing blow: one relic for each of the three, the flag on every machine, the fire gone.
func _check_telegraphs_and_debris() -> void:
	var r: Rig = _boss_rig(MINER)
	var f: BossFight = r.host.boss_fight()
	var pal: Client = _join(r, 101, PALADIN)
	var arch: Client = _join(r, 102, ARCHER)
	var clients: Array[Client] = [pal, arch]
	_down(r, pal, r.dungeon.arrival_point())
	_down(r, arch, r.dungeon.arrival_point() + Vector2(16, 0))
	hm(r, pal).player.teleport(room_feet(f, Vector2i(-2, 1)))  # all three come in on one tick
	hm(r, arch).player.teleport(room_feet(f, Vector2i(3, 2)))
	r.s.local.player.teleport(room_feet(f, Vector2i(2, -1)))
	_tick(r, 2)
	check(f.sim.awake() and f.sim.woke_with == 3 and f.sim.hp_max == BossSim.hp_for(3), "it woke for the three (%d HP)" % f.sim.hp_max)
	for kind: int in [BossSim.Attack.CLEAVE, BossSim.Attack.VOLLEY, BossSim.Attack.BURN]:
		f.test_attack = kind
		var t: int = 0
		while not (f.sim.state == BossSim.State.ATTACK and f.sim.attack == kind and f.sim.state_ticks == 0) and t < 400:
			_tick(r)
			t += 1
		var name: String = BossSim.ATTACK_NAMES[kind]
		if not check(t < 400, "%s: it started" % name):
			continue
		var start: int = r.s.tick
		var mismatched: int = 0
		var bolts_checked: int = 0
		var circles_checked: int = 0
		var length: int = BossSim.attack_length(kind) + (BossSim.attack_int(kind, "telegraph") + BossSim.attack_int(kind, "show_ticks") \
			if kind == BossSim.Attack.BURN else 40)
		for k: int in length:
			for c: Client in clients:
				var mf: BossFight = _mirror(r, c)
				var mb: BossSim = mf.sim
				var hb: BossSim = f.sim
				if hb.state == BossSim.State.ATTACK and hb.attack == kind:
					if mb.state != BossSim.State.ATTACK or mb.attack != kind or mb.state_ticks != hb.state_ticks or mb.pos != hb.pos \
							or absf(angle_difference(mb.attack_dir.angle(), hb.attack_dir.angle())) > ANGLE_BOUND or mb.facing != hb.facing:
						mismatched += 1
					if kind == BossSim.Attack.VOLLEY:
						if mb.volley_dirs.size() != hb.volley_dirs.size():
							mismatched += 1
						for j: int in mini(mb.volley_dirs.size(), hb.volley_dirs.size()):
							if absf(angle_difference(mb.volley_dirs[j].angle(), hb.volley_dirs[j].angle())) > ANGLE_BOUND:
								mismatched += 1
				if mf.bolts.size() != f.bolts.size():
					mismatched += 1
				else:
					for j2: int in f.bolts.size():
						bolts_checked += 1
						if mf.bolts[j2].pos.distance_to(f.bolts[j2].pos) > BOLT_BOUND_PX:
							mismatched += 1
				if mf.circles.size() != f.circles.size():
					mismatched += 1
				else:
					for j3: int in f.circles.size():
						circles_checked += 1
						if mf.circles[j3].age != f.circles[j3].age or mf.circles[j3].erupted != f.circles[j3].erupted \
								or mf.circles[j3].pos != f.circles[j3].pos:
							mismatched += 1
			_tick(r)
		check_eq(mismatched, 0, "%s from tick %d: both clients drew the host's telegraph, bolts and circles every tick (%d bolt and %d circle samples)" % [
			name, start, bolts_checked, circles_checked])
		for c3: Client in clients:
			var ticks: Array = c3.s.client.combat.boss.attack_ticks.get(name, [])
			check(ticks.has(start), "peer %d: the %s's start event at the host's tick %d" % [c3.peer, name, start])
		if kind == BossSim.Attack.VOLLEY:
			check(bolts_checked > 0, "volley: bolts flew and were compared")
		if kind == BossSim.Attack.BURN:
			check(circles_checked > 0 and f.stat("eruptions") > 0, "burn: circles waited, erupted and were compared")
	f.test_attack = BossSim.Attack.NONE
	_tick(r, 60)
	# A pillar broken over the boss by the host's miner.
	f.frozen = true
	var i: int = 0
	f.set_pillar_hits(i, BossFight.Pillar.hits_per_state() * 3 - 1)
	var below: Vector2i = below_pillar(f, i)
	r.s.local.player.teleport(Arena.spawn_feet(below))
	pal.action = null
	_tick(r, BossFight.DEBRIS_SHOW_TICKS)  # the last swings' marks gone
	f.sim.pos = f.pillars[i].centre() + Vector2(10, -6)  # under it (the host's numbers: its feet within the fall circle)
	var hp_before: int = f.sim.hp
	r.action = swing_at(f.pillars[i].centre())
	var t2: int = 0
	while f.pillars[i].falling < 0 and t2 < 60:
		_tick(r)
		t2 += 1
	r.action = null
	r.s.local.player.teleport(Arena.spawn_feet(below + Vector2i(0, 3)))
	check(f.pillars[i].falling >= 0, "the miner's swing broke it (%d ticks)" % t2)
	var dust_off: int = 0
	var landed_at: int = -1
	for k2: int in 60:
		_tick(r)
		for c4: Client in clients:
			var mp: BossFight.Pillar = _mirror(r, c4).pillars[i]
			if mp.falling != f.pillars[i].falling or mp.fallen != f.pillars[i].fallen:
				dust_off += 1
		if f.pillars[i].fallen and landed_at < 0:
			landed_at = r.s.tick
	check_eq(dust_off, 0, "its dust counted down on both clients as on the host, tick by tick")
	var want: int = maxi(ceili(f.sim.hp_max * Config.BOSS["debris_damage_pct"] / 100.0), 1)
	check(landed_at > 0 and hp_before - f.sim.hp == want and f.sim.exposed(), "the debris landed at %d: %d of %d HP (12%%), exposed" % [
		landed_at, hp_before - f.sim.hp, f.sim.hp_max])
	for c5: Client in clients:
		var nb: NetBoss = c5.s.client.combat.boss
		check(nb.debris_ticks.has(landed_at) and nb.debris_on_boss >= 1, "peer %d: the debris on the host's tick %d (%s)" % [c5.peer, landed_at,
			str(nb.debris_ticks)])
		check(nb.last != null and nb.last.hp == f.sim.hp and nb.last.exposed, "peer %d: the boss's HP after it, exposed" % c5.peer)
		check(c5.dungeon.data.blockers == r.dungeon.data.blockers and not c5.dungeon.data.blockers.has(f.pillars[i].tile),
			"peer %d: the rubble walkable here as on the host" % c5.peer)
		check_eq(looks(_mirror(r, c5)), looks(f), "peer %d: the pillars' looks" % c5.peer)
	# The paladin client's killing blow.
	f.sim.hp = 20
	var pm: NetMember = hm(r, pal)
	var boss_at: Vector2 = f.sim.pos
	pm.player.teleport(boss_at + Vector2(-16, 0))
	_tick(r, 3)
	var t3: int = 0
	while f.sim.alive() and t3 < 300:
		pal.action = swing_at(f.aim_point())
		_tick(r)
		t3 += 1
	pal.action = null
	_tick(r, 12)  # past the drawing buffer
	check(not f.sim.alive() and host_lines(r, "boss killed by=paladin players=3").size() == 1, "the paladin client's blow killed it (%d ticks)" % t3)
	check_eq(r.s.local.player.inventory.count_of(Config.BOSS_RELIC), 1, "the host's miner has one relic")
	for c6: Client in clients:
		check_eq(c6.s.local.player.inventory.count_of(Config.BOSS_RELIC), 1, "peer %d: one relic in its inventory" % c6.peer)
		check(c6.s.client.progress.boss_defeated, "peer %d: the world's flag" % c6.peer)
		var mf2: BossFight = _mirror(r, c6)
		check(mf2.sim.state == BossSim.State.DEAD and mf2.bolts.is_empty() and mf2.circles.is_empty(), "peer %d: dead, the fire gone" % c6.peer)
	check_eq(host_lines(r, "relic slot=").size(), 3, "three relic lines on the host")
	_tick(r, NetProtocol.boss_death_ticks() + 10)
	check(NetProtocol.boss_of(f, r.s.tick) == null, "dead and lying: no block any more")
	var mf3: BossFight = _mirror(r, pal)
	check(mf3.sim.state == BossSim.State.DEAD and mf3.sim.frame() == HereticSim.FRAME_COUNTS[HereticSim.Anim.DEATH] - 1,
		"the paladin draws it lying (frame %d)" % mf3.sim.frame())
	_free_rig(r)


## A stun before the blow cancels the attack on the host (M9b's rule, the boss's too): the client stops drawing its telegraph on the host's tick
## (the stop event), the body's attack it may still hold a buffer behind walks on.
func _check_stun_stops_telegraph() -> void:
	var r: Rig = _boss_rig(CLERIC)
	var f: BossFight = r.host.boss_fight()
	var pal: Client = _join(r, 101, PALADIN)
	_down(r, pal, room_feet(f, Vector2i(-1, 1)))
	_tick(r, 2)
	f.test_attack = BossSim.Attack.CLEAVE
	var t: int = 0
	while not (f.sim.state == BossSim.State.ATTACK and f.sim.state_ticks == 10) and t < 400:
		_tick(r)
		t += 1
	check(t < 400 and _mirror(r, pal).sim.state == BossSim.State.ATTACK, "stun: the client draws the cleave's telegraph")
	f.test_attack = BossSim.Attack.NONE
	f.frozen = true
	check(f.stun(60), "stun: it took on the host")
	_tick(r)
	check(f.sim.state != BossSim.State.ATTACK and f.stat("attacks_stunned") == 1, "stun: the host's attack ended before its blow")
	var drawn: int = 0
	for k: int in BossSim.strike_tick(BossSim.Attack.CLEAVE):
		if _mirror(r, pal).sim.state == BossSim.State.ATTACK:
			drawn += 1
		_tick(r)
	check_eq(drawn, 0, "stun: the client drew no more of its telegraph (the stop event)")
	check_eq(pal.s.client.combat.boss.stops, 1, "stun: one stop event")
	_free_rig(r)


## The altar upgrade against a malicious client (run_frame with the host's own state): never seen a relic, seen and gone, a GIVE in a release,
## far from the bench, naming the dungeon, a stale recipe index, while down, at tier 1, spam past the budget: refused with nothing spent.
func _check_upgrade_refusals() -> void:
	var r: Rig = _rig(CLERIC)
	var data: WorldData = r.surface.data
	var bench: Vector2i = data.altar_rect.position + Vector2i(-1, 6)
	put_bench(r, bench)
	var c: Client = await _join_quiet(r, 101, PALADIN, Arena.spawn_feet(bench + Vector2i(1, 1)))
	var m: NetMember = hm(r, c)
	var up: int = Crafting.index_of(Config.ALTAR_UPGRADE)
	var progress: WorldProgress = r.host.world_progress()
	var why: Callable = func(f: NetProtocol.InputFrame, label: String, reason: String) -> void:
		var before: int = m.refused(reason)
		m.op_budget = NetMember.OP_BUDGET_MAX
		r.host.run_frame(m, f)
		check(m.refused(reason) == before + 1 and progress.altar_tier == 0, "%s: refused (%s), tier 0" % [label, reason])
	why.call(craft_frame(Config.MAP_SURFACE, up), "never seen a relic", Crafting.WHY_LOCKED)
	m.player.inventory.add(Config.BOSS_RELIC, 1)
	m.player.inventory.remove(SessionHost.slot_with(m.player.inventory, Config.BOSS_RELIC), 1)
	why.call(craft_frame(Config.MAP_SURFACE, up), "seen and gone", Crafting.WHY_MISSING)
	r.s.give_allowed = false
	var give: NetProtocol.InputFrame = _op(NetProtocol.Op.GIVE, Config.MAP_SURFACE, Vector2i.ZERO)
	give.item_index = ItemDB.index_of(Config.BOSS_RELIC)
	give.count = 1
	why.call(give, "a client's GIVE of a relic in a release", "give off")
	check_eq(m.player.inventory.count_of(Config.BOSS_RELIC), 0, "no relic came of it")
	r.s.give_allowed = true
	m.player.inventory.add(Config.BOSS_RELIC, 2)
	m.player.teleport(Arena.spawn_feet(bench + Vector2i(1, 8)))
	why.call(craft_frame(Config.MAP_SURFACE, up), "eight tiles from the bench", Crafting.WHY_NO_STATION)
	m.player.teleport(Arena.spawn_feet(bench + Vector2i(1, 1)))
	var wrong: int = m.refused(WorldItems.WHY_WRONG_MAP)
	m.op_budget = 0
	r.host.run_frame(m, craft_frame(Config.MAP_DUNGEON, up))
	check(m.refused(WorldItems.WHY_WRONG_MAP) == wrong + 1 and m.op_budget == 0 and progress.altar_tier == 0,
		"naming the dungeon from the surface: wrong map, no budget spent")
	why.call(craft_frame(Config.MAP_SURFACE, Crafting.recipes().size()), "a stale recipe index", Crafting.WHY_BAD_RECIPE)
	check_eq(m.player.inventory.count_of(Config.BOSS_RELIC), 2, "both relics kept so far")
	m.player.take_hit(Config.PLAYER_HP_MAX)
	why.call(craft_frame(Config.MAP_SURFACE, up), "while down", SessionHost.WHY_DOWN)
	m.player.revive_now()
	m.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(m, craft_frame(Config.MAP_SURFACE, up))
	check(progress.altar_tier == 1 and m.player.inventory.count_of(Config.BOSS_RELIC) == 1, "at the bench with a relic: tier 1, one relic spent")
	var tier_max: int = m.refused(Crafting.WHY_TIER_MAX)
	var rate: int = m.refused("rate")
	m.op_budget = NetMember.OP_BUDGET_MAX
	for k: int in 20:
		r.host.run_frame(m, craft_frame(Config.MAP_SURFACE, up))
	check(m.refused(Crafting.WHY_TIER_MAX) - tier_max == Config.NET_OP_BURST and m.refused("rate") - rate == 20 - Config.NET_OP_BURST
		and m.player.inventory.count_of(Config.BOSS_RELIC) == 1 and progress.altar_tier == 1,
		"twenty more in one burst: %d refused at tier 1, the rest past the budget, nothing spent" % Config.NET_OP_BURST)
	_free_rig(r)


## A client crafts the upgrade at a relic bench through its own input: the host raises the tier and every machine draws candA and the 9-tile
## light from the host's number; the host's numbers (its light rule, its spawn tiles, a field tile in the ring) follow; a second client's relic at
## tier 1 is refused and kept.
func _check_upgrade_flow() -> void:
	var r: Rig = _rig(CLERIC)
	var data: WorldData = r.surface.data
	var bench: Vector2i = data.altar_rect.position + Vector2i(-1, 6)
	put_bench(r, bench)
	var pal: Client = _join(r, 101, PALADIN, Arena.spawn_feet(bench + Vector2i(1, 1)))
	var arch: Client = _join(r, 102, ARCHER, Arena.spawn_feet(bench + Vector2i(3, 1)))
	var clients: Array[Client] = [pal, arch]
	var spawn_before: int = r.host.arenas[Config.MAP_SURFACE].spawn_cells.size()
	for c: Client in clients:
		hm(r, c).player.inventory.add(Config.BOSS_RELIC, 1)
		hm(r, c).inventory_dirty = true
	_tick(r, 4)
	check(Crafting.unlocked(Crafting.recipe(Config.ALTAR_UPGRADE), pal.s.local.player.inventory), "the paladin client sees the recipe unlocked")
	var ring: Vector2 = data.altar_center_px() + Vector2(8.0 * Config.TILE, 0)
	check(not SafeZone.for_world(data).is_in_safe_zone(ring), "8 tiles off: outside the light at tier 0")
	pal.action = NetBot.Action.new()
	pal.action.op = Main.craft_request(Crafting.index_of(Config.ALTAR_UPGRADE))
	_tick(r, 4)
	pal.action = null
	_tick(r, 2)
	var progress: WorldProgress = r.host.world_progress()
	check_eq(progress.altar_tier, 1, "the host raised the tier")
	check(host_lines(r, "altar tier=1 radius_tiles=9 radius_px=144").size() == 1, "logged with the host's numbers (%s)" % str(host_lines(r, "altar")))
	check_eq(hm(r, pal).player.inventory.count_of(Config.BOSS_RELIC), 0, "its relic spent on the host")
	check(r.surface.safe_zone.radius == 144.0 and r.surface.altar.tier == 1 and r.surface.altar.sprite.texture == Altar.LIT_UP1,
		"the host draws candA and the 9-tile light")
	check(SafeZone.for_world(data).is_in_safe_zone(ring) and Farming.in_light(data, Aim.feet_cell(ring)), "the host's light rule takes the ring")
	var spawn_after: int = r.host.arenas[Config.MAP_SURFACE].spawn_cells.size()
	check(spawn_after <= spawn_before, "the host's spawn tiles worked out again (%d -> %d)" % [spawn_before, spawn_after])
	var host_light: int = r.host._light_width()
	check_eq(host_light, 290, "the host's light texture 290 texels")
	for c2: Client in clients:
		var cs: SessionClient = c2.s.client
		check(cs.progress.altar_tier == 1 and cs.tier_changes == 1, "peer %d: tier 1 from the world message" % c2.peer)
		check(c2.surface.safe_zone.radius == 144.0 and c2.surface.altar.tier == 1 and c2.surface.altar.sprite.texture == Altar.LIT_UP1,
			"peer %d: candA and the 9-tile light" % c2.peer)
		check_eq(cs._light_width(), host_light, "peer %d: the light's texture = the host's" % c2.peer)
		check_eq(c2.surface.data.content_hash(), data.content_hash(), "peer %d: the surface = the host's (the tier in its hash)" % c2.peer)
		check(SafeZone.for_world(c2.surface.data).is_in_safe_zone(ring), "peer %d: the ring in its light too" % c2.peer)
	check_eq(pal.s.local.player.inventory.count_of(Config.BOSS_RELIC), 0, "the paladin's own inventory: the relic gone")
	arch.action = NetBot.Action.new()
	arch.action.op = Main.craft_request(Crafting.index_of(Config.ALTAR_UPGRADE))
	_tick(r, 4)
	arch.action = null
	_tick(r, 2)
	check(hm(r, arch).refused(Crafting.WHY_TIER_MAX) == 1 and arch.s.local.player.inventory.count_of(Config.BOSS_RELIC) == 1
		and progress.altar_tier == 1, "the archer's at tier 1: refused, its relic kept")
	_free_rig(r)


## Late joiners: one entering the dungeon mid-fight (an attack under way, bolts in the air, circles waiting, a pillar's dust coming down) draws
## them where the host has them; one joining after the kill and the upgrade has the tier and the flag on its welcome and the rubble and the
## lying boss when it goes down.
func _check_boss_late_join() -> void:
	var r: Rig = _boss_rig(MINER)
	var f: BossFight = r.host.boss_fight()
	var pal: Client = _join(r, 101, PALADIN)
	_down(r, pal, room_feet(f, Vector2i(-2, 1)))
	r.s.local.player.teleport(room_feet(f, Vector2i(2, -1)))
	_tick(r, 2)
	f.test_attack = BossSim.Attack.VOLLEY
	var t: int = 0
	while f.bolts.is_empty() and t < 400:
		_tick(r)
		t += 1
	var players: Array[Player] = r.host.players_on(Config.MAP_DUNGEON)
	f.begin_attack(BossSim.Attack.BURN, players[0], players)  # its circles now, the bolts still in the air (the host's to decide)
	f.test_attack = BossSim.Attack.NONE
	f.set_pillar_hits(1, BossFight.Pillar.hits_per_state() * 3 - 1)
	f.blow(1, r.s.local.player.get_instance_id(), true)
	_tick(r)
	check(not f.bolts.is_empty() and not f.circles.is_empty() and f.pillars[1].falling >= 0, "mid-fight: bolts, circles and dust (%d, %d, %d)" % [
		f.bolts.size(), f.circles.size(), f.pillars[1].falling])
	var late: Client = _join(r, 104, ARCHER)
	_down(r, late, room_feet(f, Vector2i(-3, 2)))
	var mf: BossFight = _mirror(r, late)
	var same: bool = mf.bolts.size() == f.bolts.size() and mf.circles.size() == f.circles.size()
	for j: int in mini(mf.bolts.size(), f.bolts.size()):
		same = same and mf.bolts[j].pos.distance_to(f.bolts[j].pos) <= BOLT_BOUND_PX
	for j2: int in mini(mf.circles.size(), f.circles.size()):
		same = same and mf.circles[j2].age == f.circles[j2].age
	check(same, "the late arrival draws the host's bolts (%d) and circles (%d)" % [f.bolts.size(), f.circles.size()])
	check(mf.pillars[1].falling == f.pillars[1].falling and looks(mf) == looks(f), "and the pillar's dust (%d) and looks" % f.pillars[1].falling)
	check(late.s.client.combat.boss.last != null and late.s.client.combat.boss.last.hp == f.sim.hp, "and the boss's body from the keyframe")
	if f.sim.state == BossSim.State.ATTACK:
		check(mf.sim.state == BossSim.State.ATTACK and mf.sim.state_ticks == f.sim.state_ticks, "and the attack under way")
	# Kill it, upgrade, then a joiner after both.
	f.test_attack = BossSim.Attack.NONE
	f.frozen = true
	_tick(r, 60)
	f.hit(f.sim.hp, r.s.local.player.get_instance_id())
	_tick(r, NetProtocol.boss_death_ticks() + 10)
	var relic_holder: NetMember = hm(r, pal)
	check_eq(relic_holder.player.inventory.count_of(Config.BOSS_RELIC), 1, "the paladin got its relic")
	var progress: WorldProgress = r.host.world_progress()
	progress.raise_altar()
	r.host._altar_raised(relic_holder, Crafting.recipe(Config.ALTAR_UPGRADE))
	_tick(r, 3)
	var after: Client = _join(r, 105, CLERIC)
	check(after.s.client.progress.altar_tier == 1 and after.s.client.progress.boss_defeated, "a joiner after both: tier 1 and the flag on its welcome")
	check(after.surface.safe_zone.radius == 144.0 and after.surface.altar.sprite.texture == Altar.LIT_UP1 and after.s.client._light_width() == 290,
		"candA and the 9-tile light from its snapshot")
	check_eq(after.surface.data.content_hash(), r.surface.data.content_hash(), "its surface = the host's")
	_down(r, after, r.dungeon.arrival_point())
	var mf2: BossFight = _mirror(r, after)
	check(mf2.sim.state == BossSim.State.DEAD and looks(mf2) == looks(f) and after.dungeon.data.blockers == r.dungeon.data.blockers,
		"going down: the boss lying dead, the pillars as the host's (%s), blocking as the host's" % looks(mf2))
	check(after.s.client.combat.boss.last == null, "no body sent: it rests")
	_free_rig(r)


## Traffic while two players fight the boss for 10 s (its own attacks, the client's sword): what one client gets per second, against the
## README's bound; and a boss lying dead sends nothing.
func _check_boss_traffic() -> void:
	var r: Rig = _boss_rig(MINER)
	var f: BossFight = r.host.boss_fight()
	var pal: Client = _join(r, 101, PALADIN)
	_down(r, pal, room_feet(f, Vector2i(-1, 1)))
	r.s.local.player.teleport(room_feet(f, Vector2i(2, 1)))
	_tick(r, 2)
	r.bytes_by_kind.clear()
	var ticks: int = 600
	for k: int in ticks:
		if k % 90 == 0:
			hm(r, pal).player.vitals.hp = Config.PLAYER_HP_MAX  # keep it up (the test's, not the fight's)
			r.s.local.player.vitals.hp = Config.PLAYER_HP_MAX
		pal.action = swing_at(f.aim_point())
		_tick(r)
	pal.action = null
	var sec: float = ticks * Config.NET_TICK
	var enemy_bps: float = (r.bytes_by_kind.get("enemies", 0) + r.bytes_by_kind.get("enemy_key", 0)) / sec / 2.0
	var shots_bps: float = r.bytes_by_kind.get("shots", 0) / sec / 2.0
	note("boss fight traffic, one client: enemies %.0f B/s, events %.0f B/s (attacks %d, bolts %d, circles %d over %.0f s)" % [enemy_bps,
		shots_bps, f.stat("attacks"), f.stat("bolts"), f.stat("eruptions"), sec])
	check(enemy_bps > 0.0 and enemy_bps <= FIGHT_ENEMY_MAX_BPS, "the boss's batches within %.0f B/s (%.0f)" % [FIGHT_ENEMY_MAX_BPS, enemy_bps])
	check(shots_bps <= FIGHT_EVENTS_MAX_BPS, "its events within %.0f B/s (%.0f)" % [FIGHT_EVENTS_MAX_BPS, shots_bps])
	f.frozen = true
	f.hit(f.sim.hp, hm(r, pal).player.get_instance_id())
	_tick(r, NetProtocol.boss_death_ticks() + 40)
	r.bytes_by_kind.clear()
	_tick(r, 300)
	check_eq(r.bytes_by_kind.get("enemies", 0) + r.bytes_by_kind.get("enemy_key", 0) + r.bytes_by_kind.get("shots", 0), 0,
		"a boss lying dead with two standing players: nothing sent in 300 ticks")
	_free_rig(r)


## A version 13 hello is refused (and a 15).
func _check_v13_refused() -> void:
	var r: Rig = _rig(CLERIC)
	for v: int in [13, 15]:
		var peer: int = 160 + v
		r.host.on_hello(peer, NetProtocol.encode_hello(NetProtocol.class_index(PALADIN), v))
		var msgs: Array[Array] = r.s.take_for(peer)
		var why: String = ""
		if msgs.size() == 1:
			var payload: PackedByteArray = msgs[0][2]
			why = NetProtocol.decode_refusal(payload)
		check(msgs.size() == 1 and str(msgs[0][1]) == "refused" and why == "version" and member_of_peer(r, peer) == null,
			"a version %d hello: refused (%s), no member" % [v, why])
	_free_rig(r)


# --- M12c-fix: the relics at a leave or a map change in the kill's tick ---------------------------------------------------------------

## The member's relics (slot order): [slot, map, count].
static func relics_by_slot(r: Rig) -> Array:
	var out: Array = []
	for slot: int in r.s.slots():
		out.append([slot, r.s.members[slot].map_id, r.s.members[slot].player.inventory.count_of(Config.BOSS_RELIC)])
	return out


## Whether `pl`'s action lands on the next frame it runs.
static func impact_next(pl: Player) -> bool:
	return pl.action_anim >= 0 and pl.action_tick + 1 == Player.impact_tick_of(pl.action_item, pl.action_anim)


## The review's probe P1b: the host (a cleric) on the surface; an archer (slot 1) and a paladin (slot 2) in the room. The archer leaves in the
## poll right before the tick the paladin's swing lands (SessionHost.tick runs the members' frames before the arenas' step, and the leaver's
## Player was freed in on_peer_disconnected): the paladin still gets its relic, on the host and in its own inventory.
func _check_relics_at_a_leave() -> void:
	var r: Rig = _rig(CLERIC)
	var f: BossFight = r.host.boss_fight()
	f.frozen = true
	var arch: Client = _join(r, 101, ARCHER)
	var pal: Client = _join(r, 102, PALADIN)
	_down(r, arch, room_feet(f, Vector2i(-2, 1)))
	_down(r, pal, room_feet(f, Vector2i(2, 1)))
	_tick(r, 3)
	var pm: NetMember = hm(r, pal)
	pm.player.teleport(f.sim.pos + Vector2(-16, 0))
	_tick(r, 3)
	check(f.sim.awake(), "leave: awake")
	f.sim.hp = 1
	pal.action = swing_at(f.aim_point())
	var t: int = 0
	while t < 60 and not impact_next(pm.player):
		_tick(r)
		t += 1
	check(f.sim.alive() and impact_next(pm.player), "leave: one tick before the paladin's blow (%d ticks)" % t)
	arch.ticking = false
	r.host.on_peer_disconnected(arch.peer)
	_tick(r, 1)
	pal.action = null
	_tick(r, 8)
	check(not f.sim.alive() and r.host.world_progress().boss_defeated, "leave: the paladin's frame killed it, the flag set")
	var rel: Array = relics_by_slot(r)
	var wrong: int = 0
	for row: Array in rel:
		var on_dungeon: bool = row[1] == Config.MAP_DUNGEON
		var n: int = row[2]
		if n != (1 if on_dungeon else 0):
			wrong += 1
	check_eq(wrong, 0, "leave: one relic for every member still on the dungeon, none on the surface (%s)" % str(rel))
	check_eq(f.stat("relics"), 1, "leave: one relic given (the leaver skipped)")
	check_eq(pal.s.local.player.inventory.count_of(Config.BOSS_RELIC), 1, "leave: the paladin's own inventory has it")
	check_eq(host_lines(r, "relic slot=").size(), 1, "leave: one relic line")
	_free_rig(r)


## The review's probe P2: between the last step and the host's killing blow, the archer (slot 1) goes up the stairs and a cleric (slot 3) comes
## down: the relics follow who is on the dungeon at the kill.
func _check_relics_at_travel() -> void:
	var r: Rig = _boss_rig(PALADIN)
	var f: BossFight = r.host.boss_fight()
	f.frozen = true
	var arch: Client = _join(r, 101, ARCHER)
	var miner: Client = _join(r, 102, MINER)
	var cleric: Client = _join(r, 103, CLERIC)
	_down(r, arch, room_feet(f, Vector2i(-2, 1)))
	_down(r, miner, room_feet(f, Vector2i(2, 1)))
	r.s.local.player.teleport(room_feet(f, Vector2i(0, 2)))
	_tick(r, 3)
	check(f.sim.awake(), "travel: awake")
	f.sim.hp = 5
	r.host.move_to_map(hm(r, arch), Config.MAP_SURFACE)
	r.host.move_to_map(hm(r, cleric), Config.MAP_DUNGEON)
	f.hit(50, r.s.local.player.get_instance_id())
	_tick(r, 8)
	var rel: Array = relics_by_slot(r)
	var wrong: int = 0
	for row: Array in rel:
		var on_dungeon: bool = row[1] == Config.MAP_DUNGEON
		var n: int = row[2]
		if n != (1 if on_dungeon else 0):
			wrong += 1
	check_eq(wrong, 0, "travel: the relics follow who was on the dungeon at the kill (%s)" % str(rel))
	check(host_lines(r, "boss killed by=paladin players=3").size() == 1, "travel: the kill counted the three on the dungeon then")
	check_eq(cleric.s.local.player.inventory.count_of(Config.BOSS_RELIC), 1, "travel: the cleric who came down has it in its inventory")
	check_eq(arch.s.local.player.inventory.count_of(Config.BOSS_RELIC), 0, "travel: the archer who went up has none")
	_free_rig(r)


## The boss block's start tick is 0 when untimed: a death on a tick that is a multiple of 65536 is sent one tick earlier, never as 0.
func _check_death_since() -> void:
	var d: WorldData = WorldData.new(Vector2i(48, 36))
	d.map_id = Config.MAP_DUNGEON
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	var room: BossRoom.Layout = BossRoom.Layout.new()
	room.room = Rect2i(8, 6, 26, 20)
	room.walk = BossRoom.walk_of(room.room)
	room.home_tile = room.walk.position + room.walk.size / 2
	a.boss = BossFight.new()
	a.boss.setup_with(a, room, 1)
	a.boss.sim.state = BossSim.State.DEAD
	a.boss.sim.hp = 0
	a.boss.sim.state_ticks = 4
	var o: NetProtocol.BossState = NetProtocol.boss_of(a.boss, 65536 + 4)
	check(o != null and o.since == 0xFFFF, "since: a death that started on tick 65536 goes as 65535, not 0 (%d)" % (o.since if o != null else -1))
	var o2: NetProtocol.BossState = NetProtocol.boss_of(a.boss, 70000)
	check(o2 != null and o2.since == (70000 - 4) & 0xFFFF, "since: any other start as it is")
