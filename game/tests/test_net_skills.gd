extends "res://tests/test_net_potions.gd"
## M9c: the class skills in sessions, in one process: the real SessionHost and SessionClient flows on the rig of
## tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients' packets back, an optional fixed
## one-way delay). tests/test_net_rites.gd runs real sessions.
##   - the wire (protocol v11): the SKILL request and THROW's cursor, the heretic's marks byte, the skill events (a skill's shot,
##     a burst, a strike, a zone, a zone's end, a ward), the owner's skills message: round trips, every truncation, every field
##     out of range
##   - the host against a malicious client: another class's skill (the slot names the sender's own kit), the cooldown bypassed
##     (pressed again and again), a signature without the resource, a cursor far out of range (a heal: refused; a point skill:
##     pulled in to its range from where the host has the caster), another map, while down, while carrying the altar, a tile out
##     of reach, the choice slot, the weapon skill without the class weapon selected on the host, spam past the request budget;
##     the herbalist's THROW of a healing potion with nobody near its cursor
##   - flows: a client's heal lands on the ally its cursor is near on every machine; a taunt pulls a heretic off a client; the
##     herbalist's healing throw lands on the ally nearest its cursor and follows it; cooldowns and meters match the host
##     (an archer standing still gains focus with no message, a miner's mining feeds his endurance on the host); a late joiner
##     during a healing mist and an arrow rain on its way (and a stunned heretic) draws them as the host has them; the stun,
##     slow, taunt and ward marks on every machine; four players with skills (a 3-tick delay) agree with the host; traffic of
##     four players using every skill; a version 10 hello is refused

const ARCHER: String = "archer"
const CLERIC: String = "cleric"
const PALADIN: String = "paladin"
const MINER: String = "miner"


func run() -> Array[String]:
	_check_skill_codec()
	_check_marks_codec()
	_check_events_codec()
	_check_skills_message_codec()
	await _check_skill_requests()
	await _check_heal_on_the_right_ally()
	await _check_taunt_pulls()
	await _check_throw_retarget()
	await _check_meters_match()
	await _check_late_join_skills()
	await _check_four_skills()
	await _check_v10_refused()
	return failures


# --- helpers -----------------------------------------------------------------------------------------------

## A SKILL request of slot `slot` with the cursor at `cursor` (aimed at tile `cell`, which only turns the player). M9 review: its
## hotbar slot (`hotbar`: the class weapon's in these tests) and the ally its sender picked (`pick`, a member slot).
static func _skill(map: int, cell: Vector2i, slot: int, cursor: Vector2, aim: int = 0, hotbar: int = WEAPON_SLOT,
		pick: int = NetProtocol.NO_SLOT) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.SKILL, map, cell, hotbar)
	f.skill_slot = slot
	f.cursor = cursor
	f.aim = aim
	f.pick = pick
	return f


## The skill key of slot `slot` pressed this tick with the mouse at `at` (the host's own player or a client).
static func key_at(slot: int, at: Vector2) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = at
	a.aiming = true
	if slot == Skills.Slot.IDENTITY:
		a.skill = true
	else:
		a.skill_slot = slot
	return a


## The tile next to member `m`'s feet (in reach: a request's target tile).
static func beside(m: NetMember) -> Vector2i:
	return Aim.feet_cell(m.player.sim_position) + Vector2i(1, 0)


## One host tick for member `m` alone (its skill clock, its frame `f`, its map's arena), like host_frame plus the skill clock.
func skill_frame(r: Rig, m: NetMember, f: NetProtocol.InputFrame) -> void:
	m.refill_ops()
	r.host._tick_skills()
	host_frame(r, m, f)


## Member `m` idles `n` host ticks (its skill clock and action run on).
func idle_ticks(r: Rig, m: NetMember, n: int) -> void:
	for i: int in n:
		skill_frame(r, m, NetProtocol.InputFrame.new())


## The skill events of kind `kind` client `c` got.
static func skill_events_of(c: Client, kind: int) -> Array[NetProtocol.ShotEvent]:
	var out: Array[NetProtocol.ShotEvent] = []
	for e: NetProtocol.ShotEvent in c.shot_events:
		if e.kind == kind:
			out.append(e)
	return out


## Every client draws at the rig's time (its players where the host had them a buffer ago, its combat view).
func draw_all(r: Rig) -> void:
	for c: Client in r.clients:
		if c.s.active and not c.s.over:
			draw_at_rig_time(r, c)


# --- the wire ----------------------------------------------------------------------------------------------

func _check_skill_codec() -> void:
	var frames: Array[NetProtocol.InputFrame] = [NetProtocol.InputFrame.new(30, Vector2i(1, 0)),
		NetProtocol.InputFrame.new(31, Vector2i.ZERO)]
	frames[0].op = NetProtocol.Op.SKILL
	frames[0].map = Config.MAP_DUNGEON
	frames[0].skill_slot = Skills.Slot.SIGNATURE
	frames[0].cell = Vector2i(40, -1)
	frames[0].aim = 201
	frames[0].slot = 5  # M9 review: the hotbar slot rides along (key 2 plays the class weapon there)
	frames[0].pick = 3  # M9 review: the ally the sender's machine picked
	frames[0].cursor = Vector2(700.4, -3.6)
	frames[1].op = NetProtocol.Op.THROW
	frames[1].slot = 2
	frames[1].pick = 6
	frames[1].cursor = Vector2(-12.5, 1300.49)
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 2 + 1 + (2 + 13) + (2 + 12),
		"a SKILL is 13 B (with the map, M9 review: the hotbar slot and the picked ally), a THROW 12 B (the picked ally)")
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 2 and p.frames[0].op == NetProtocol.Op.SKILL and p.frames[0].skill_slot == Skills.Slot.SIGNATURE
		and p.frames[0].cell == Vector2i(40, -1) and p.frames[0].aim == 201 and p.frames[0].map == Config.MAP_DUNGEON
		and p.frames[0].cursor == Vector2(700, -4) and p.frames[0].slot == 5 and p.frames[0].pick == 3
		and p.frames[0].same_request(frames[0]),
		"a SKILL round trips: its slot, hotbar slot, tile, aim, map, picked ally and cursor in whole px (%s)" % (
		p.frames[0].cursor if p.ok else Vector2.INF))
	check(p.ok and p.frames[1].cursor == Vector2(-13, 1300) and p.frames[1].throw_to == p.frames[1].cursor and p.frames[1].slot == 2
		and p.frames[1].pick == 6 and p.frames[1].same_request(frames[1]),
		"a THROW's point is its cursor (v11), whole px, with its picked ally (%s)" % (p.frames[1].cursor if p.ok else Vector2.INF))
	var other_pick: NetProtocol.InputFrame = _copy_frame(frames[0])
	other_pick.pick = 4
	var other_hotbar: NetProtocol.InputFrame = _copy_frame(frames[0])
	other_hotbar.slot = 6
	check(not frames[0].same_request(other_pick) and not frames[0].same_request(other_hotbar),
		"another picked ally or hotbar slot is another request")
	for n: int in range(NetProtocol.INPUT_HEADER + 3, bytes.size()):
		if NetProtocol.decode_inputs(bytes.slice(0, n)).ok:
			check(false, "a SKILL cut to %d B is refused" % n)
	var at: int = NetProtocol.INPUT_HEADER + 2 + 1 + 2  # the first op's fields: u8 map, then the slot byte
	for bad_slot: int in [SkillState.SLOT_COUNT, 255]:
		var b: PackedByteArray = bytes.duplicate()
		b.encode_u8(at + 1, bad_slot)
		check(not NetProtocol.decode_inputs(b).ok, "a SKILL naming slot %d is refused (the whole packet)" % bad_slot)
	for bad_hotbar: int in [Config.HOTBAR_SLOTS, 255]:
		var bh: PackedByteArray = bytes.duplicate()
		bh.encode_u8(at + 2, bad_hotbar)
		check(not NetProtocol.decode_inputs(bh).ok, "a SKILL naming hotbar slot %d is refused" % bad_hotbar)
	for bad_pick: int in [Config.MAX_PLAYERS, 254]:
		var bp: PackedByteArray = bytes.duplicate()
		bp.encode_u8(at + 12, bad_pick)
		check(not NetProtocol.decode_inputs(bp).ok, "a SKILL picking slot %d (no player's) is refused" % bad_pick)
		var bt: PackedByteArray = bytes.duplicate()
		bt.encode_u8(at + 13 + 2 + 11, bad_pick)  # the THROW's picked ally (its index and op, then its map and ten field bytes)
		check(not NetProtocol.decode_inputs(bt).ok, "a THROW picking slot %d is refused" % bad_pick)
	var none: PackedByteArray = bytes.duplicate()
	none.encode_u8(at + 12, NetProtocol.NO_SLOT)
	var pn: NetProtocol.InputPacket = NetProtocol.decode_inputs(none)
	check(pn.ok and pn.frames[0].pick == NetProtocol.NO_SLOT, "a SKILL picking nobody (255) is fine")
	var bm: PackedByteArray = bytes.duplicate()
	bm.encode_u8(at, Config.MAP_COUNT)
	check(not NetProtocol.decode_inputs(bm).ok, "a SKILL naming no map is refused")
	var far: NetProtocol.InputFrame = NetProtocol.InputFrame.new(40, Vector2i.ZERO)
	far.op = NetProtocol.Op.SKILL
	far.skill_slot = 0
	far.cursor = Vector2(100000, -100000)
	var fp: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([far] as Array[NetProtocol.InputFrame]))
	check(fp.ok and fp.frames[0].cursor == Vector2(32767, -32768), "a cursor beyond s16 is clamped on the wire (%s)" % (
		fp.frames[0].cursor if fp.ok else Vector2.INF))
	check_eq(NetProtocol.OP_NAMES[NetProtocol.Op.SKILL], "skill", "the op's name")
	check(frames[0].describe_op().contains("key=R") and frames[0].describe_op().contains("cursor=700,-4")
		and frames[0].describe_op().contains("slot=5") and frames[0].describe_op().contains("pick=3"), "its log line (%s)" % (
		frames[0].describe_op()))


## M9 review: a copy of request frame `f`'s fields (same_request checks).
static func _copy_frame(f: NetProtocol.InputFrame) -> NetProtocol.InputFrame:
	var c: NetProtocol.InputFrame = NetProtocol.InputFrame.new(f.seq, f.dir)
	c.op = f.op
	c.map = f.map
	c.skill_slot = f.skill_slot
	c.slot = f.slot
	c.cell = f.cell
	c.aim = f.aim
	c.cursor = f.cursor
	c.pick = f.pick
	return c


func _check_marks_codec() -> void:
	var h: HereticSim = HereticSim.new()
	h.id = 7
	h.pos = Vector2(100.5, 200.25)
	h.state = HereticSim.State.CHASE
	h.stun_ticks = 5
	h.slow_pct = 40
	h.slow_ticks = 9
	h.taunt_by = 12345
	h.taunt_ticks = 3
	var e: NetProtocol.EnemyState = NetProtocol.enemy_of(h, 500)
	check(e.stunned and e.slowed and e.taunted and e.marks() == NetProtocol.MARKS_ALL, "a stunned, slowed, taunted heretic's marks")
	var bytes: PackedByteArray = NetProtocol.encode_enemies(500, Config.MAP_SURFACE, 0, [e] as Array[NetProtocol.EnemyState])
	check_eq(bytes.size(), NetProtocol.ENEMY_HEADER + 18, "18 B a heretic (the marks byte)")
	var b: NetProtocol.EnemyBatch = NetProtocol.decode_enemies(bytes)
	check(b.ok and b.enemies.size() == 1 and b.enemies[0].same_as(e), "the marks round trip")
	var nc: NetCombat = NetCombat.new()
	nc.reset(Config.MAP_SURFACE, SurfaceGen.generate(SEED))
	nc.on_batch(b, bytes, true)
	nc.sample(500.0, 0.0)
	var shown: HereticSim = nc.arena.heretics[0] if nc.arena.heretics.size() == 1 else null
	check(shown != null and shown.stunned() and shown.slowed() and shown.taunted() and shown.anim() == HereticSim.Anim.HURT
		and shown.frame() == Config.SKILL_STUN_FRAME, "a client draws the marks (and the stunned pose)")
	check(nc.marks_seen["stunned"].has(7) and nc.marks_seen["slowed"].has(7) and nc.marks_seen["taunted"].has(7), "and counts them")
	var unknown: PackedByteArray = bytes.duplicate()
	unknown.encode_u8(NetProtocol.ENEMY_HEADER + 17, 0x08)
	check(not NetProtocol.decode_enemies(unknown).ok, "an unknown mark bit is refused")
	h.state = HereticSim.State.DEAD
	var dead: NetProtocol.EnemyState = NetProtocol.enemy_of(h, 500)
	check(not dead.stunned and not dead.slowed and not dead.taunted, "a dead heretic has no marks")
	var forged: PackedByteArray = NetProtocol.encode_enemies(500, Config.MAP_SURFACE, 0, [dead] as Array[NetProtocol.EnemyState])
	forged.encode_u8(NetProtocol.ENEMY_HEADER + 17, NetProtocol.MARK_STUNNED)
	check(not NetProtocol.decode_enemies(forged).ok, "a dead heretic with a mark is refused")
	check(not NetProtocol.decode_enemies(bytes.slice(0, bytes.size() - 1)).ok, "a batch one byte short (a v10 heretic) is refused")


func _check_events_codec() -> void:
	var events: Array[NetProtocol.ShotEvent] = []
	var shot: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	shot.kind = NetProtocol.ShotEvent.Kind.SKILL_SHOT
	shot.id = 70
	shot.item = Skills.PIERCING_ARROW
	shot.owner = 2
	shot.tick = 900
	shot.pos = Vector2(10.5, 20.25)
	shot.aim = 33
	events.append(shot)
	var burst: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	burst.kind = NetProtocol.ShotEvent.Kind.BURST
	burst.id = 71
	burst.sub = Arena.BurstKind.CRUSH
	burst.owner = 1
	burst.follow = NetProtocol.NO_SLOT
	burst.tick = 899
	burst.pos = Vector2(30.75, 40.5)
	burst.radius = 28.0
	burst.aim = 64
	burst.arc_deg = 120.0
	events.append(burst)
	var ring: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	ring.kind = NetProtocol.ShotEvent.Kind.BURST
	ring.id = 72
	ring.sub = Arena.BurstKind.HEAL
	ring.owner = 0
	ring.follow = 8
	ring.tick = 900
	ring.pos = Vector2(1.0, 2.0)
	ring.radius = 10.0
	events.append(ring)
	var strike: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	strike.kind = NetProtocol.ShotEvent.Kind.STRIKE
	strike.id = 73
	strike.sub = Arena.StrikeKind.ROCKS
	strike.owner = 3
	strike.tick = 880
	strike.pos = Vector2(50.0, 60.5)
	strike.radius = 28.0
	strike.ticks = 60
	events.append(strike)
	var zone: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	zone.kind = NetProtocol.ShotEvent.Kind.ZONE
	zone.id = 74
	zone.sub = Arena.ZoneKind.BLESSING
	zone.owner = 4
	zone.follow = 4
	zone.tick = 870
	zone.pos = Vector2(70.25, 80.0)
	zone.radius = 64.0
	zone.ticks = 300
	events.append(zone)
	var end: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	end.kind = NetProtocol.ShotEvent.Kind.ZONE_END
	end.id = 74
	end.tick = 950
	events.append(end)
	var ward: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	ward.kind = NetProtocol.ShotEvent.Kind.WARD
	ward.slots = (1 << 0) | (1 << 8)
	ward.tick = 901
	ward.ticks = Skills.max_ward_ticks()
	ward.pct = 50
	events.append(ward)
	var sizes: Array[int] = [NetProtocol.SKILL_SHOT_SIZE, NetProtocol.BURST_SIZE, NetProtocol.BURST_SIZE, NetProtocol.STRIKE_SIZE,
		NetProtocol.ZONE_SIZE, NetProtocol.ZONE_END_SIZE, NetProtocol.WARD_SIZE]
	var total: int = 2
	for n: int in sizes:
		total += n
	var bytes: PackedByteArray = NetProtocol.encode_shots(Config.MAP_SURFACE, events)
	check_eq(bytes.size(), total, "the skill events' sizes (20 / 23 / 21 / 23 / 9 / 10 B)")
	var got: NetProtocol.ShotEvents = NetProtocol.decode_shots(bytes)
	var same: bool = got.ok and got.events.size() == events.size()
	for i: int in mini(got.events.size(), events.size()):
		same = same and got.events[i].same_as(events[i])
	check(same, "every skill event round trips")
	for n: int in range(3, bytes.size()):
		if NetProtocol.decode_shots(bytes.slice(0, n)).ok:
			check(false, "skill events cut to %d B are refused" % n)
	# Fields out of range, one event alone each time.
	var bad: Array[Array] = []
	var taunt_shot: NetProtocol.ShotEvent = _copy_event(shot)
	taunt_shot.item = Skills.TAUNT
	bad.append([taunt_shot, "a skill shot of a skill that shoots nothing (the taunt)"])
	for row: Array in [["sub", Arena.BurstKind.size()], ["owner", Config.MAX_PLAYERS], ["follow", 200], ["radius", 0.0],
			["arc_deg", 0.0]]:
		var e: NetProtocol.ShotEvent = _copy_event(burst)
		var key: String = row[0]
		e.set(key, row[1])
		bad.append([e, "a burst with %s %s" % [row[0], row[1]]])
	for row2: Array in [["sub", Arena.StrikeKind.size()], ["ticks", 0], ["radius", 0.0], ["owner", 99]]:
		var e2: NetProtocol.ShotEvent = _copy_event(strike)
		var key2: String = row2[0]
		e2.set(key2, row2[1])
		bad.append([e2, "a strike with %s %s" % [row2[0], row2[1]]])
	for row3: Array in [["sub", Arena.ZoneKind.size()], ["ticks", 0], ["radius", 0.0], ["follow", 9]]:
		var e3: NetProtocol.ShotEvent = _copy_event(zone)
		var key3: String = row3[0]
		e3.set(key3, row3[1])
		bad.append([e3, "a zone with %s %s" % [row3[0], row3[1]]])
	for row4: Array in [["slots", 0], ["slots", 1 << Config.MAX_PLAYERS], ["ticks", 0], ["ticks", Skills.max_ward_ticks() + 1],
			["pct", 0], ["pct", 101]]:
		var e4: NetProtocol.ShotEvent = _copy_event(ward)
		var key4: String = row4[0]
		e4.set(key4, row4[1])
		bad.append([e4, "a ward with %s %s" % [row4[0], row4[1]]])
	for row5: Array in bad:
		var ev: NetProtocol.ShotEvent = row5[0]
		check(not NetProtocol.decode_shots(NetProtocol.encode_shots(Config.MAP_SURFACE, [ev] as Array[NetProtocol.ShotEvent])).ok,
			"refused: %s" % row5[1])
	var wide: PackedByteArray = NetProtocol.encode_shots(Config.MAP_SURFACE, [burst] as Array[NetProtocol.ShotEvent])
	wide.encode_u8(2 + 22, 181)
	check(not NetProtocol.decode_shots(wide).ok, "refused: a burst's half arc of 181 degrees")
	# A client draws them: the burst at its age, the strike until its delay, the zone until its end, the ward until its time.
	var nc: NetCombat = NetCombat.new()
	nc.reset(Config.MAP_SURFACE, SurfaceGen.generate(SEED))
	nc.local_slot = 6
	nc.on_shots(got)
	nc.sample(905.0, 0.0, {8: Vector2(400, 300), 4: Vector2(500, 300)} as Dictionary[int, Vector2])
	var heal_drawn: Arena.Burst = null
	for b: Arena.Burst in nc.arena.bursts:
		if b.id == 72:
			heal_drawn = b
	check(nc.arena.bursts.size() == 2 and heal_drawn != null and heal_drawn.age == 5 and heal_drawn.pos == Vector2(400, 300),
		"bursts drawn at their age, one following its player (%d)" % nc.arena.bursts.size())
	check(nc.arena.strikes.size() == 1 and nc.arena.strikes[0].age == 25 and nc.arena.strikes[0].delay == 60, "the strike on its way")
	check(nc.arena.zones.size() == 1 and nc.arena.zones[0].age == 35 and nc.arena.zones[0].pos == Vector2(500, 300),
		"the blessing following its cleric")
	check(nc.ward_at(0, 905.0) == Vector2i(50, Skills.max_ward_ticks() - 4) and nc.ward_at(8, 905.0).y > 0
		and nc.ward_at(3, 905.0) == Vector2i.ZERO, "the ward over slots 0 and 8, not 3")
	check(nc.shots.has(70) and nc.shots[70].pierce and is_equal_approx(nc.shots[70].speed, Skills.num_f(Skills.PIERCING_ARROW, "speed"))
		and nc.shots[70].life == Skills.shot_life(Skills.PIERCING_ARROW), "the piercing arrow flies at its skill's speed and reach")
	nc.sample(951.0, 0.0, {} as Dictionary[int, Vector2])
	check(nc.arena.zones.is_empty() and nc.arena.strikes.is_empty() and nc.arena.bursts.is_empty(),
		"the zone ended early, the strike landed, the bursts are over")
	check(nc.ward_at(0, 901.0 + Skills.max_ward_ticks()) == Vector2i.ZERO, "the ward over at its time")


static func _copy_event(e: NetProtocol.ShotEvent) -> NetProtocol.ShotEvent:
	var c: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	for prop: String in ["kind", "id", "item", "owner", "aim", "tick", "pos", "why", "target", "sub", "follow", "radius", "arc_deg",
			"ticks", "slots", "pct"]:
		c.set(prop, e.get(prop))
	return c


func _check_skills_message_codec() -> void:
	var st: SkillState = SkillState.new()
	st.resource = 77
	st.start_cooldown(Skills.Slot.IDENTITY, 12)
	st.start_cooldown(Skills.Slot.WEAPON, 345)
	st.start_cooldown(Skills.Slot.SIGNATURE, Skills.max_cooldown())
	st.since_hurt = 120
	st.decay_tick = 7
	st.focus_tick = 3
	st.was_moving = true
	var bytes: PackedByteArray = NetProtocol.encode_skills(4321, st, true, false)
	check_eq(bytes.size(), NetProtocol.SKILLS_SIZE, "the skills message is 16 B")
	var k: NetProtocol.SkillsState = NetProtocol.decode_skills(bytes)
	check(k.ok and k.tick == 4321 and k.state.same_clock(st) and k.moving and not k.alive, "the skills message round trips")
	for n: int in bytes.size():
		if NetProtocol.decode_skills(bytes.slice(0, n)).ok:
			check(false, "the skills message cut to %d B is refused" % n)
	var bad: Array[Array] = [[4, 1, Skills.max_resource() + 1, "a meter past the largest cap"],
		[5, 2, Skills.max_cooldown() + 1, "a cooldown past the longest skill's"],
		[11, 2, Config.PALADIN_CONVICTION_DECAY_DELAY_TICKS + 1, "a paladin waiting past the fade's delay"],
		[13, 1, Config.PALADIN_CONVICTION_DECAY_TICKS, "a fade rhythm past its rule"],
		[14, 1, maxi(Config.ARCHER_FOCUS_GAIN_TICKS, Config.ARCHER_FOCUS_DRAIN_TICKS) + 1, "a focus rhythm past its rule"],
		[15, 1, 0x08, "an unknown flag"]]
	for row: Array in bad:
		var b: PackedByteArray = bytes.duplicate()
		var at: int = row[0]
		var size: int = row[1]
		var v: int = row[2]
		if size == 1:
			b.encode_u8(at, v)
		else:
			b.encode_u16(at, v)
		check(not NetProtocol.decode_skills(b).ok, "skills message refused: %s" % row[3])
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	check(not NetProtocol.decode_skills(longer).ok, "a byte too many is refused")
	# The client's copy runs on by the rule: an archer standing still gains focus on both sides alike.
	var host_copy: SkillState = SkillState.new()
	host_copy.resource = 10
	var client_copy: SkillState = SkillState.new()
	client_copy.take_clock(NetProtocol.decode_skills(NetProtocol.encode_skills(1, host_copy, false, true)).state)
	for i: int in 300:
		host_copy.tick(ARCHER, false, true)
		client_copy.tick(ARCHER, false, true)
	check(host_copy.same_clock(client_copy) and client_copy.resource == 10 + 300 / Config.ARCHER_FOCUS_GAIN_TICKS,
		"an archer's copy standing still: %d focus on both, no message" % client_copy.resource)


# --- the host against a malicious client --------------------------------------------------------------------

## Requests handed straight to run_frame (no wire): the host judges from its own state.
func _check_skill_requests() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var ac: Client = await _join_quiet(r, 101, ARCHER, base + Vector2(-60, 0))
	var cc: Client = await _join_quiet(r, 102, CLERIC, base + Vector2(-20, 0))
	var am: NetMember = hm(r, ac)
	var cm: NetMember = hm(r, cc)
	am.player.inventory.select(WEAPON_SLOT)
	cm.player.inventory.select(WEAPON_SLOT)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	am.player.vitals.hp = 50  # wounded (the cleric's heal target)
	check(am.player.skills_on and am.player.skills_clock_external and cm.player.skills_on and arena.threat_on,
		"every member has the skill kit on the host's clock, every arena keeps threat")
	# Another class's skill: the slot names the sender's own kit. The archer's key 1 with the cursor on a wounded ally is his
	# piercing arrow, never a heal.
	var hp_before: int = am.player.vitals.hp
	skill_frame(r, am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.IDENTITY, cm.player.sim_position, 0))
	check(am.player.action_item == Skills.PIERCING_ARROW and am.player.action_anim == RigData.Anim.BOW,
		"an archer's key 1 plays his piercing arrow (%s)" % am.player.action_item)
	idle_ticks(r, am, PlayerSim.action_ticks(RigData.Anim.BOW))
	check(arena.stat("skill_shots") == 1 and cm.player.vitals.hp == Config.PLAYER_HP_MAX and am.player.vitals.hp == hp_before,
		"one piercing arrow let go, nobody healed: an archer cannot play the cleric's heal")
	skill_frame(r, am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.SIGNATURE, cm.player.sim_position))
	check_eq(am.refused(Skills.WHY_RESOURCE), 1, "his key R without the focus: not enough")
	skill_frame(r, am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.CHOICE, cm.player.sim_position))
	check_eq(am.refused(Skills.WHY_LOCKED), 1, "key 3: the choice slot is locked")
	skill_frame(r, am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.WEAPON, cm.player.sim_position, 0, 0))
	check_eq(am.refused(Skills.WHY_NO_WEAPON), 1, "key 2 naming a hotbar slot without the class weapon: refused (hold your class weapon)")
	# M9 review: the request's hotbar slot decides, not the host's selection (a SELECT queued behind the key on the sender's
	# machine reaches the host a frame later).
	am.player.inventory.select(0)
	skill_frame(r, am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.WEAPON, cm.player.sim_position, 0, WEAPON_SLOT))
	check(am.player.action_item == Skills.FAN_SHOT and am.player.action_slot == WEAPON_SLOT,
		"key 2 naming the bow's slot plays the fan shot with that bow, whatever the host has selected (%s, slot %d)" % [
		am.player.action_item, am.player.action_slot])
	idle_ticks(r, am, PlayerSim.action_ticks(RigData.Anim.BOW))
	am.player.skills.cooldowns = PackedInt32Array([0, 0, 0, 0])
	am.player.inventory.select(WEAPON_SLOT)
	# The cleric heals the archer; the cooldown cannot be cut short by pressing again.
	skill_frame(r, cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.IDENTITY, am.player.sim_position + Vector2(10, -6)))
	check(cm.player.action_item == Skills.HEAL, "the cleric's key 1 near the wounded archer: the heal starts")
	idle_ticks(r, cm, Skills.impact_tick(Skills.HEAL))
	var cd: int = Skills.cooldown_ticks(Skills.HEAL)
	check(am.player.vitals.hp == 50 + Skills.num_i(Skills.HEAL, "heal_hp") and cm.player.skills.cooldown(Skills.Slot.IDENTITY) > 0
		and cm.player.skills.resource == Skills.num_i(Skills.HEAL, "heal_hp"),
		"the heal landed on the archer on its impact frame (hp %d, faith %d, cooldown %d)" % [am.player.vitals.hp,
		cm.player.skills.resource, cm.player.skills.cooldown(Skills.Slot.IDENTITY)])
	idle_ticks(r, cm, PlayerSim.action_ticks(RigData.Anim.MAGIC))
	var tries: int = 0
	var refused_before: int = cm.refused(Skills.WHY_COOLDOWN)
	while cm.player.skills.cooldown(Skills.Slot.IDENTITY) > 1 and tries < 200:
		skill_frame(r, cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.IDENTITY, am.player.sim_position))
		tries += 1
		idle_ticks(r, cm, 9)
	check(tries > 10 and cm.refused(Skills.WHY_COOLDOWN) - refused_before == tries and am.player.vitals.hp == 75,
		"pressed %d times during the cooldown: every one refused (cooling down), no heal" % tries)
	idle_ticks(r, cm, 2)
	skill_frame(r, cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.IDENTITY, am.player.sim_position))
	check(cm.player.action_item == Skills.HEAL, "once cooled down (%d ticks) the next press starts" % cd)
	idle_ticks(r, cm, PlayerSim.action_ticks(RigData.Anim.MAGIC))
	# A cursor far out of range: a heal finds nobody (refused, nothing spent); a point skill is pulled in to its range from where
	# the host has the caster.
	am.player.vitals.hp = 40
	idle_ticks(r, cm, Skills.cooldown_ticks(Skills.HEAL))
	var faith: int = cm.player.skills.resource
	skill_frame(r, cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.IDENTITY, Vector2(5000, 5000)))
	check(cm.refused(Skills.WHY_NO_ALLY) == 1 and cm.player.action_anim < 0 and cm.player.skills.resource == faith,
		"a heal with the cursor 5000 px off: no ally near it, refused, nothing spent")
	var bursts_before: int = arena.bursts.size()
	skill_frame(r, cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.WEAPON, cm.player.sim_position + Vector2(2000, 0)))
	idle_ticks(r, cm, Skills.impact_tick(Skills.HOLY_BURST))
	var holy: Arena.Burst = arena.bursts.back() if arena.bursts.size() > bursts_before else null
	check(holy != null and holy.kind == Arena.BurstKind.HOLY
		and holy.pos.distance_to(cm.player.sim_position) <= Skills.num_f(Skills.HOLY_BURST, "range_px") + 0.5,
		"a holy burst aimed 2000 px off lands within its %.0f px of the host's cleric (%.1f px)" % [
		Skills.num_f(Skills.HOLY_BURST, "range_px"), holy.pos.distance_to(cm.player.sim_position) if holy != null else -1.0])
	idle_ticks(r, cm, PlayerSim.action_ticks(RigData.Anim.MAGIC))
	# Another map, down, carrying the altar, a tile out of reach.
	var budget: int = cm.op_budget
	r.host.run_frame(cm, _skill(Config.MAP_DUNGEON, beside(cm), Skills.Slot.IDENTITY, am.player.sim_position))
	check(cm.refused(WorldItems.WHY_WRONG_MAP) == 1 and cm.op_budget == budget, "a SKILL naming the dungeon: wrong map (no budget spent)")
	r.host.run_frame(cm, _skill(Config.MAP_SURFACE, beside(cm) + Vector2i(4, 0), Skills.Slot.IDENTITY, am.player.sim_position))
	check_eq(cm.refused(WorldItems.WHY_REACH), 1, "a SKILL aimed at a tile 5 tiles off: out of reach")
	cm.player.carrying_altar = true
	r.host.run_frame(cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.IDENTITY, am.player.sim_position))
	check_eq(cm.refused(AltarMove.WHY_CARRYING), 1, "a SKILL while carrying the altar: refused")
	cm.player.carrying_altar = false
	cm.player.take_hit(Config.PLAYER_HP_MAX)
	r.host.run_frame(cm, _skill(Config.MAP_SURFACE, beside(cm), Skills.Slot.IDENTITY, am.player.sim_position))
	check(cm.player.vitals.life == Vitals.Life.DOWN and cm.refused(SessionHost.WHY_DOWN) == 1, "a SKILL while down: refused (down)")
	# Spam past the request budget: ten SKILL frames in one host tick.
	am.player.skills.cooldowns = PackedInt32Array([0, 0, 0, 0])
	idle_ticks(r, am, PlayerSim.action_ticks(RigData.Anim.BOW))
	am.op_budget = NetMember.OP_BUDGET_MAX
	var shots_before: int = arena.stat("skill_shots")
	var rate_before: int = am.refused("rate")
	r.s.tick += 1
	for i: int in 10:
		r.host.run_frame(am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.IDENTITY, base + Vector2(0, 80)))
	check(am.refused("rate") - rate_before == 10 - Config.NET_OP_BURST and am.refused(Skills.WHY_BUSY) == Config.NET_OP_BURST - 1,
		"ten SKILL frames in one tick: %d within the budget (one starts, the rest mid-action), %d rate" % [Config.NET_OP_BURST,
		10 - Config.NET_OP_BURST])
	idle_ticks(r, am, PlayerSim.action_ticks(RigData.Anim.BOW))
	check_eq(arena.stat("skill_shots") - shots_before, 1, "so one piercing arrow")
	# The herbalist's THROW of a healing potion: nobody near its cursor = refused, nothing used; an ally near it = thrown at him.
	var hc: Client = await _join_quiet(r, 103, HERB, base + Vector2(20, 0))
	var hmm: NetMember = hm(r, hc)
	give(hmm, &"potion_healing", 2, ItemDB.Grade.FINE)
	var pslot: int = slot_of(hmm.player.inventory, &"potion_healing")
	hmm.player.inventory.select(pslot)
	skill_frame(r, hmm, _throw(Config.MAP_SURFACE, beside(hmm), pslot, Vector2(-3000, 40)))
	check(hmm.refused(Skills.WHY_NO_ALLY) == 1 and hmm.player.inventory.count_of(&"potion_healing") == 2,
		"a healing THROW with nobody near its cursor: refused (● R42), nothing used")
	var f: NetProtocol.InputFrame = _throw(Config.MAP_SURFACE, beside(hmm), pslot, am.player.sim_position + Vector2(12, 4))
	skill_frame(r, hmm, f)
	check(f.skill == Skills.POTION_THROW and f.skill_target == am.player.get_instance_id()
		and f.throw_to == Potions.throw_target(Combat.body_point(hmm.player.sim_position), Combat.body_point(am.player.sim_position)).round(),
		"a healing THROW near the archer: thrown at his body point (the host's pick)")
	note("requests: refused by the host %s (archer), %s (cleric), %s (herbalist)" % [am.ops_refused, cm.ops_refused, hmm.ops_refused])
	_free_rig(r)


# --- flows -------------------------------------------------------------------------------------------------

## A client cleric heals the ally its cursor is near (as it draws the players); every machine sees that ally healed.
func _check_heal_on_the_right_ally() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 2
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	r.s.local.player.teleport(base + Vector2(40, 0))
	var cl: Client = _join(r, 101, CLERIC, base)
	var ar: Client = _join(r, 102, ARCHER, base + Vector2(-48, 0))
	var hb: Client = _join(r, 103, HERB, base + Vector2(0, 40))
	var cm: NetMember = hm(r, cl)
	var am: NetMember = hm(r, ar)
	r.s.local.player.vitals.hp = 60
	am.player.vitals.hp = 40
	_tick(r, 12)
	draw_all(r)
	var target_on_c: Player = cl.s.members[am.slot].player
	press(r, null, cl, key_at(0, target_on_c.sim_position + Vector2(-6, 4)))
	check(cl.s.local.player.skill_aim_target == target_on_c or cl.s.local.player.action_anim == RigData.Anim.MAGIC,
		"the cleric's ring and its heal go to the archer as it draws him")
	_tick(r, Skills.impact_tick(Skills.HEAL) + 3 * r.delay + 6)
	draw_all(r)
	var heal_hp: int = Skills.num_i(Skills.HEAL, "heal_hp")
	check(am.player.vitals.hp == 40 + heal_hp and r.s.local.player.vitals.hp == 60,
		"the host healed the archer (%d), not the paladin (%d)" % [am.player.vitals.hp, r.s.local.player.vitals.hp])
	for c: Client in r.clients:
		var seen: Player = c.s.members[am.slot].player if c != ar else c.s.local.player
		var hp_seen: int = seen.vitals.hp if c != ar else c.s.client.prediction.sim.vit.hp
		check_eq(hp_seen, 40 + heal_hp, "peer %d sees the archer at %d HP" % [c.peer, 40 + heal_hp])
		var heals: Array[NetProtocol.ShotEvent] = skill_events_of(c, NetProtocol.ShotEvent.Kind.BURST)
		var on_archer: int = 0
		for e: NetProtocol.ShotEvent in heals:
			if e.sub == Arena.BurstKind.HEAL and e.follow == am.slot and e.owner == cm.slot:
				on_archer += 1
		check_eq(on_archer, 1, "peer %d got the heal's sparks following the archer, from the cleric" % c.peer)
	var mirror: SkillState = cl.s.local.player.skills
	check(cl.s.client.skills_msgs >= 1 and mirror.resource == cm.player.skills.resource and mirror.cooldown(0) > 0
		and absi(mirror.cooldown(0) - cm.player.skills.cooldown(0)) <= 2 * r.delay + 3,
		"the cleric's own HUD: faith %d (host %d), cooldown %d (host %d)" % [mirror.resource, cm.player.skills.resource,
		mirror.cooldown(0), cm.player.skills.cooldown(0)])
	check_prediction("heal/cleric", cl)
	_free_rig(r)


## A heretic chasing a client archer: the host's paladin taunts it; it turns to him on the host, every client sees it taunted.
func _check_taunt_pulls() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var f: Vector2 = spot(r)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(f)
	var ar: Client = _join(r, 101, ARCHER, f + Vector2(-70, 0))
	var am: NetMember = hm(r, ar)
	var host_p: Player = r.s.local.player
	host_p.teleport(f + Vector2(110, -30))  # farther than the archer: the heretic goes after the nearest first (M4)
	var ticks: int = tick_until(r, func() -> bool: return h.has_target and h.target_id == am.player.get_instance_id(), 120)
	check(ticks < 120, "the heretic goes after the archer first (%d ticks)" % ticks)
	# The archer's arrows build his threat.
	for i: int in 2:
		draw_all(r)
		press(r, null, ar, swing_at(_drawn_foe(r, ar, h.id, Combat.body_centre(h.pos))))
		_tick(r, PlayerSim.action_ticks(RigData.Anim.BOW))
	check(h.threat_of(am.player.get_instance_id()) > 0, "the archer's hits are his threat (%d)" % h.threat_of(am.player.get_instance_id()))
	host_p.teleport(h.pos + Vector2(40, -12))  # within the taunt's reach of it
	press(r, key_at(0, h.pos))
	_tick(r, Skills.impact_tick(Skills.TAUNT) + 2)
	check(h.taunted() and h.taunt_by == host_p.get_instance_id(), "taunted by the host's paladin (%s)" % h.describe())
	var turned: int = tick_until(r, func() -> bool: return h.target_id == host_p.get_instance_id(), 90)
	check(turned < 90 and h.taunted(), "the heretic turns to him once its swing is over (%d ticks)" % turned)
	_tick(r, 8)
	draw_all(r)
	check(ar.s.client.combat.marks_seen["taunted"].has(h.id), "the archer's machine saw it taunted")
	var drawn: HereticSim = null
	for dh: HereticSim in ar.s.client.combat.arena.heretics:
		if dh.id == h.id:
			drawn = dh
	check(drawn != null and drawn.taunted(), "and draws the taunt's mark over it")
	_tick(r, Skills.num_i(Skills.TAUNT, "taunt_ticks"))
	check(not h.taunted(), "the taunt runs out on the host's clock")
	_free_rig(r)


## The herbalist client throws a healing potion with its cursor near a wounded paladin client: the host lands it on him (and the
## bottle follows him on every machine's track: its landing point is his body point as the host had it).
func _check_throw_retarget() -> void:
	var r: Rig = _rig(ARCHER)
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var hb: Client = _join(r, 101, HERB, base, false)
	var pl: Client = _join(r, 102, PALADIN, base + Vector2(60, 0))
	var hbm: NetMember = hm(r, hb)
	var plm: NetMember = hm(r, pl)
	give(hbm, &"potion_healing", 1, ItemDB.Grade.FINE)
	plm.player.vitals.hp = 30
	_tick(r, 8)
	press(r, null, hb, _select(slot_of(hb.s.local.player.inventory, &"potion_healing")))
	_tick(r, 6)
	draw_all(r)
	var drawn_pal: Player = hb.s.members[plm.slot].player
	press(r, null, hb, throw_at(drawn_pal.sim_position + Vector2(-20, 14)))
	var thrown: int = tick_until(r, func() -> bool: return hbm.combat_count("throws") > 0, 120)
	var flask: Arena.Flask = r.host.arenas[Config.MAP_SURFACE].flasks.back() if not r.host.arenas[Config.MAP_SURFACE].flasks.is_empty() else null
	check(thrown < 120 and flask != null and flask.follow_id == plm.player.get_instance_id(),
		"the healing bottle goes to the paladin, the ally nearest the cursor (● R42)")
	_tick(r, 60)
	check_eq(plm.player.vitals.hp, 30 + Config.POTION_HEAL_HP[ItemDB.Grade.FINE], "it lands on him: healed")
	for c: Client in r.clients:
		var thrown_events: Array[NetProtocol.ShotEvent] = skill_events_of(c, NetProtocol.ShotEvent.Kind.THROW)
		var bt: Vector2 = Potions.throw_target(flask.origin, Combat.body_point(plm.player.sim_position)) if flask != null else Vector2.INF
		check(thrown_events.size() == 1 and thrown_events[0].target.distance_to(bt) < 0.01,
			"peer %d got the thrown event, aimed at the paladin's body point" % c.peer)
	_free_rig(r)


## Cooldowns and meters on the host and on each client's HUD: an archer standing still gains focus with no message (the client's
## copy runs by the same rule), moving drains it (a message when he starts), a hit grows a paladin's conviction, a miner's mining
## in the dungeon his endurance (on the host), a death loses a meter.
func _check_meters_match() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 2
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var ar: Client = _join(r, 101, ARCHER, base)
	var pl: Client = _join(r, 102, PALADIN, base + Vector2(40, 0))
	var am: NetMember = hm(r, ar)
	var pm: NetMember = hm(r, pl)
	_tick(r, 10)
	var msgs: int = ar.s.client.skills_msgs
	_tick(r, 300)
	var host_focus: int = am.player.skills.resource
	var mirror: int = ar.s.local.player.skills.resource
	check(host_focus >= 300 / Config.ARCHER_FOCUS_GAIN_TICKS and absi(host_focus - mirror) <= 1 + (2 * r.delay + 6) / Config.ARCHER_FOCUS_GAIN_TICKS
		and ar.s.client.skills_msgs == msgs, "an archer standing 5 s: focus %d on the host, %d on his HUD, no message (%d)" % [host_focus,
		mirror, ar.s.client.skills_msgs - msgs])
	var walk: NetBot.Action = NetBot.Action.new()
	walk.dir = Vector2i(-1, 0)
	ar.action = walk
	_tick(r, 30)
	ar.action = null
	_tick(r, 12)
	var walk_msgs: int = ar.s.client.skills_msgs - msgs
	check(am.player.skills.resource < host_focus and absi(ar.s.local.player.skills.resource - am.player.skills.resource) <= 1
		and walk_msgs >= 1 and walk_msgs <= 3, "walking drains it: %d on both (%d messages: when he starts and when he stops, not one a batch)" % [
		am.player.skills.resource, walk_msgs])
	pm.player.take_hit(12)
	_tick(r, 2 * r.delay + 6)
	check(pm.player.skills.resource > 0 and pl.s.local.player.skills.resource == pm.player.skills.resource,
		"a hit grows the paladin's conviction: %d on both" % pm.player.skills.resource)
	_tick(r, Config.HURT_INVULN_TICKS + 2)  # the hit's invulnerability over
	pm.player.take_hit(Config.PLAYER_HP_MAX)
	pm.player.vitals.life_ticks = Config.DOWN_TICKS - 4  # near the end of its down time (the rig need not wait 30 s)
	tick_until(r, func() -> bool: return pm.player.vitals.life == Vitals.Life.DEAD, 60)
	_tick(r, 2 * r.delay + 6)
	check(pm.player.skills.resource == 0 and pl.s.local.player.skills.resource == 0, "a death loses the meter on both")
	# A miner mining the dungeon's rock: his endurance grows on the host (Config.MINER_ENDURANCE_PER_BLOCK a block).
	var mc: Client = await _join_quiet(r, 103, MINER, base + Vector2(-40, 0))
	var mm: NetMember = hm(r, mc)
	r.host.move_to_map(mm, Config.MAP_DUNGEON)
	var d: WorldData = r.dungeon.data
	var rock: Vector2i = Vector2i(42, 15)  # the seed-1 dungeon's rock east of the arrival (tests/test_net_maps.gd EAST_ROCK)
	mm.player.teleport(_feet(rock - Vector2i(1, 0)))
	mm.player.inventory.select(WEAPON_SLOT)
	check(Walls.is_wall(d, rock), "the dungeon's rock east of the arrival is there")
	for i: int in 12:
		if not Walls.is_wall(d, rock):
			break
		mm.refill_ops()
		r.host.run_frame(mm, _use(Config.MAP_DUNGEON, rock, WEAPON_SLOT, 0))
		for k: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE):
			r.host.run_frame(mm, NetProtocol.InputFrame.new())
	check(not Walls.is_wall(d, rock) and mm.player.skills.resource > 0 and mm.player.skills.resource % Config.MINER_ENDURANCE_PER_BLOCK == 0,
		"the miner broke the dungeon's rock: his endurance grew on the host (%d)" % mm.player.skills.resource)
	_free_rig(r)


## A healing mist and an arrow rain on their way, a heretic stunned: a client joining then draws them as the host has them. The
## players stand in the light, the heretic idles at home just outside it (it targets nobody in the light, so it stays put).
func _check_late_join_skills() -> void:
	var r: Rig = _rig(MINER)
	await await_frames(1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var inside: Vector2 = Arena.spawn_feet(south_of_altar(r, 5))
	var h: HereticSim = arena.spawn_heretic(Arena.spawn_feet(south_of_altar(r, 9)))
	var host_p: Player = r.s.local.player
	host_p.teleport(inside)
	host_p.skills.resource = 80
	var hb: Client = _join(r, 101, HERB, inside + Vector2(-30, 0), false)
	var ar: Client = _join(r, 102, ARCHER, inside + Vector2(30, 0))
	give(hm(r, hb), Config.HERBALIST_MATERIAL_ITEM, 3)
	hm(r, ar).player.skills.resource = 80
	_tick(r, 8)
	press(r, key_at(3, h.pos))  # the host miner's rockfall on the heretic: a stun when it lands
	var stunned: int = tick_until(r, func() -> bool: return h.stunned(), 120)
	check(stunned < 120, "the rockfall landed on the heretic: stunned (%s)" % h.describe())
	draw_all(r)
	press(r, null, hb, key_at(3, hm(r, hb).player.sim_position + Vector2(0, -20)))  # the healing mist
	press(r, null, ar, key_at(3, _drawn_foe(r, ar, h.id, h.pos)))  # the archer's arrow rain on the heretic
	var t: int = tick_until(r, func() -> bool: return not arena.strikes.is_empty() and not arena.zones.is_empty(), 90)
	check(t < 90, "a mist and an arrow rain under way on the host (%d strikes, %d zones)" % [arena.strikes.size(), arena.zones.size()])
	var late: Client = _join(r, 103, CLERIC, Arena.spawn_feet(south_of_altar(r, 1)))
	var nc: NetCombat = late.s.client.combat
	nc.sample(float(r.s.tick), 0.0, {} as Dictionary[int, Vector2])
	var zone_ok: bool = false
	for z: Arena.Zone in nc.arena.zones:
		for hz: Arena.Zone in arena.zones:
			if hz.id == z.id and hz.age == z.age and hz.kind == z.kind:
				zone_ok = true
	var strike_ok: bool = arena.strikes.is_empty()
	for s: Arena.Strike in nc.arena.strikes:
		for hs: Arena.Strike in arena.strikes:
			if hs.id == s.id and hs.age == s.age and hs.delay == s.delay:
				strike_ok = true
	check(zone_ok, "the late joiner draws the mist at the host's age (%d zones there)" % nc.arena.zones.size())
	check(strike_ok, "and the arrow rain on its way at the host's age (%d strikes there)" % nc.arena.strikes.size())
	check(nc.marks_seen["stunned"].has(h.id), "its welcome keyframe has the heretic stunned")
	_tick(r, 90)
	check(not arena.strikes.is_empty() or arena.stat("strikes_landed") >= 1, "the rain landed (%d)" % arena.stat("strikes_landed"))
	var rains: int = 0
	for e: NetProtocol.ShotEvent in skill_events_of(late, NetProtocol.ShotEvent.Kind.BURST):
		if e.sub == Arena.BurstKind.RAIN:
			rains += 1
	check_eq(rains, 1, "the late joiner got the rain's landing ring")
	_free_rig(r)


## Four players (a 3-tick delay) use their skills on two heretics: the host decides, everyone agrees; the traffic of it.
func _check_four_skills() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 3
	await await_frames(1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var f: Vector2 = Arena.spawn_feet(south_of_altar(r, 13))
	var h1: HereticSim = arena.spawn_heretic(f)
	var h2: HereticSim = arena.spawn_heretic(f + Vector2(40, 0))
	var h3: HereticSim = arena.spawn_heretic(f + Vector2(16, 30))
	var host_p: Player = r.s.local.player
	host_p.teleport(f + Vector2(-40, -36))  # they come to him; his taunt reaches them on the way
	var ar: Client = _join(r, 101, ARCHER, f + Vector2(10, -70))
	var cl: Client = _join(r, 102, CLERIC, f + Vector2(-30, -60))
	var hb: Client = _join(r, 103, HERB, f + Vector2(50, -60))
	var cs: Array[Client] = [ar, cl, hb]
	give(hm(r, hb), Config.HERBALIST_MATERIAL_ITEM, 6)
	give(hm(r, hb), &"potion_poison", 4, ItemDB.Grade.FINE)
	host_p.skills.resource = 100
	hm(r, cl).player.skills.resource = 100
	_tick(r, 10)
	var local_refusals: Array[String] = []
	for c: Client in [ar, cl, hb]:
		var cc: Client = c
		cc.s.local.player.skill_refused.connect(func(sl: int, id: StringName, why: String) -> void:
			local_refusals.append("%d:%s:%s" % [cc.peer, Skills.SLOT_KEYS[sl], why]))
	r.bytes_by_kind.clear()
	var t: int = 0
	var start_tick: int = r.s.tick
	var slots: Array[int] = [Skills.Slot.IDENTITY, Skills.Slot.WEAPON, Skills.Slot.SIGNATURE]
	while (h1.alive() or h2.alive() or h3.alive()) and t < 1500:
		var target: HereticSim = h1 if h1.alive() else (h2 if h2.alive() else h3)
		draw_all(r)
		# Each player: a cycle of 120 ticks, its next skill key first (in its own order), aiming free while it plays, then one basic
		# attack and aiming free till the next (an attack still playing would refuse the key: mid-action); 8 ticks apart.
		var host_slot: int = slots[_turn(t, 0)]
		r.action = _cycle(t, 0, host_slot, target.pos, target.pos)
		var aim_ar: Vector2 = _drawn_foe(r, ar, target.id, Combat.body_centre(target.pos))
		ar.action = _cycle(t, 8, slots[_turn(t, 8)], aim_ar, aim_ar)
		var aim_cl: Vector2 = _drawn_foe(r, cl, target.id, Combat.body_centre(target.pos))
		var cl_slot: int = [Skills.Slot.WEAPON, Skills.Slot.SIGNATURE, Skills.Slot.IDENTITY][_turn(t, 16)]
		var host_on_cl: Vector2 = cl.s.members[r.s.local.slot].player.sim_position
		cl.action = _cycle(t, 16, cl_slot, host_on_cl if cl_slot == Skills.Slot.IDENTITY else aim_cl, aim_cl)
		var aim_hb: Vector2 = _drawn_foe(r, hb, target.id, Combat.body_centre(target.pos))
		var hb_slot: int = [Skills.Slot.SIGNATURE, Skills.Slot.WEAPON, Skills.Slot.IDENTITY][_turn(t, 24)]
		var hb_k: int = posmod(t - 24, 120)
		if hb_slot == Skills.Slot.IDENTITY and hb_k == 1:
			hb.s.local.player.inventory.select(slot_of(hb.s.local.player.inventory, &"potion_poison"))
		var hb_at: Vector2 = hb.s.local.player.sim_position + Vector2(0, 24) if hb_slot == Skills.Slot.SIGNATURE else aim_hb
		hb.action = _cycle(t, 24, hb_slot, hb_at, aim_hb)
		if hb_k == 58 and hb.s.local.player.inventory.selected != WEAPON_SLOT:
			hb.action = _select(WEAPON_SLOT)  # the sickle again for its basic attack and its sweep
		_tick(r)
		t += 1
	r.action = null
	for c: Client in cs:
		c.action = null
	var fight_ticks: int = r.s.tick - start_tick
	_tick(r, Config.HERETIC_CORPSE_TICKS + 60)
	check(not h1.alive() and not h2.alive() and not h3.alive(), "four players with skills killed three heretics in %d ticks" % t)
	var landed: Dictionary = r.host.skills_landed
	check(landed.size() >= 4, "they landed skills of %d kinds (%s; refused on their machines %s)" % [landed.size(), landed,
		local_refusals])
	for c: Client in cs:
		check_eq(hp_mismatches(r, c), 0, "four/peer %d: every batch = the host's HP at its tick" % c.peer)
		check(_follows(c.s.client.combat.hp_seen(h1.id), host_hp_seq(r, h1.id))
			and _follows(c.s.client.combat.hp_seen(h2.id), host_hp_seq(r, h2.id))
			and _follows(c.s.client.combat.hp_seen(h3.id), host_hp_seq(r, h3.id)), "four/peer %d: the heretics' HP the host's way" % c.peer)
		check_eq(c.s.client.combat.latest_hash(), r.host.combat_hash(Config.MAP_SURFACE), "four/peer %d: its last enemy view = the host's" % c.peer)
		var m: NetMember = hm(r, c)
		var mirror: SkillState = c.s.local.player.skills
		var cd_ok: bool = true
		for i: int in SkillState.SLOT_COUNT:
			cd_ok = cd_ok and absi(mirror.cooldown(i) - m.player.skills.cooldown(i)) <= 2 * r.delay + 3
		check(cd_ok and (absi(mirror.resource - m.player.skills.resource) <= 2 or m.class_id == ARCHER),
			"four/peer %d: its HUD's cooldowns %s and meter %d = the host's %s / %d" % [c.peer, mirror.cooldowns, mirror.resource,
			m.player.skills.cooldowns, m.player.skills.resource])
		check(c.s.client.combat.skill_events.size() >= 3, "four/peer %d: got skill events %s" % [c.peer, c.s.client.combat.skill_events])
		check_eq(c.s.local.player.sim_position, m.player.sim_position, "four/peer %d: where the host has it" % c.peer)
	# Traffic: ENet payload bytes to each client, per second of the fight.
	var secs: float = maxf(float(fight_ticks) / Config.NET_TICK_RATE, 0.001)
	var per: Dictionary = {}
	var total: int = 0
	for kind: String in r.bytes_by_kind:
		var b: int = r.bytes_by_kind[kind]
		per[kind] = roundi(b / secs / cs.size())
		total += b
	note("four with skills: %d ticks, %d B/s to each client %s; skills landed %s, skills messages %d (%d B)" % [fight_ticks,
		roundi(total / secs / cs.size()), per, landed, r.host.skills_msgs_sent, r.host.skills_bytes_sent])
	_free_rig(r)


## The four-player fight's input for a player whose cycle starts `offset` ticks late: the skill key of slot `slot` at `skill_at`
## on its tick 4, aim free at `foe` while it plays, a basic attack at `foe` started in ticks 60 to 65, aim free to 120.
static func _cycle(t: int, offset: int, slot: int, skill_at: Vector2, foe: Vector2) -> NetBot.Action:
	var k: int = posmod(t - offset, 120)
	if k == 4 and t >= offset:
		return key_at(slot, skill_at)
	if k >= 60 and k < 66:
		return swing_at(foe)
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = foe
	a.aiming = true
	return a


## Which turn of three a player whose cycle starts `offset` ticks late is in at tick `t`.
static func _turn(t: int, offset: int) -> int:
	return posmod(floori((t - offset) / 120.0), 3)


## A hello of version 10 (an M8 build) is refused with `version`; that client ends cleanly.
func _check_v10_refused() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	r.host.on_hello(170, NetProtocol.encode_hello(NetProtocol.class_index(MINER), 10))
	var to_peer: Array[Array] = r.s.take_for(170)
	var refusal: PackedByteArray = PackedByteArray()
	if to_peer.size() == 1:
		refusal = to_peer[0][2]
	check(to_peer.size() == 1 and str(to_peer[0][1]) == "refused" and NetProtocol.decode_refusal(refusal) == "version"
		and member_of_peer(r, 170) == null and not r.host.streams.has(170), "a version 10 hello: one refusal (version), no member, no world")
	var c: Client = Client.new()
	c.s = CaptureSession.new()
	add_node(c.s)
	c.s.set_physics_process(false)
	c.s.set_process(false)
	c.s.role = NetSession.Role.CLIENT
	c.s.options = CliOptions.new()
	c.s.client = SessionClient.new(c.s)
	var codes: Array[int] = []
	c.s.ended.connect(func(_reason: String, code: int) -> void: codes.append(code))
	c.s.client.on_refused(refusal)
	await await_frames(2)
	check(c.s.over and c.s.end_reason == "refused: version" and codes == ([NetSession.EXIT_REFUSED] as Array[int]),
		"the version 10 client ends cleanly: %s, code %s" % [c.s.end_reason, codes])
	_owned_nodes.erase(c.s)
	c.s.get_parent().remove_child(c.s)
	c.s.free()
	_free_rig(r)
