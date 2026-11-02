extends "res://tests/test_net_skills.gd"
## M10b: the group prayer and meditation in sessions, in one process: the real SessionHost and SessionClient flows on the rig of
## tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients' packets back, an optional fixed
## one-way delay). tests/test_net_vigil.gd and tests/test_net_litany.gd run real sessions.
##   - the wire (protocol v12): PRAY and ANSWER round trips, sizes, every truncation and field out of range; every prayer event
##     kind round trip, sizes, truncations, fields out of range
##   - the host against a malicious client: a non-cleric's "start" (it meditates), a tap outside the circle, an answer to another's
##     turn, to a past and a future turn, to another prayer, two answers to one turn, spam past the request budget, quitting twice,
##     a client hit on the host that answers on as if it were not (its answers and its rejoin refused), every other request while
##     praying, the altar's lift while a prayer is under way, faith short, combat
##   - flows: four (a host cleric and three clients) complete a prayer with every answer right, mixed and all late: every machine has
##     the host's lamps, result, zeal (%, the tick it runs out) and the zeal on every player; the participants' predictions are never
##     corrected; a participant hit mid-prayer leaves alone (its turns go to the others), the cleric quitting stops it (no zeal, no
##     faith spent) on every machine; a late joiner and a player entering the surface get the prayer under way and draw what the
##     host draws (lamps, circle, marks); answers late in a client's window over a 4-tick delay are taken (the lag allowance), one
##     past it is refused as over; meditation in a session; the zeal's damage in a session fight and a death taking it on every
##     machine; the prayer's traffic; a version 11 hello is refused
##   - M10-fix (the review): a client cleric (start, quit, a full prayer: its faith on the host and its own meter); the host's own
##     key counts only in the window its HUD shows; ten PRAYs in a tick; a late joiner gets a meditation under way; a joiner reusing
##     the slot of a participant who left is not that participant; a gather that ends with the cleric alone (it stops, he
##     meditates); a join just after the gather inside the host's allowance; a meditation's zeal is one on every machine

const HERBALIST: String = "herbalist"


func run() -> Array[String]:
	_check_ops_codec()
	_check_events_codec()
	await _check_malicious_prayer()
	await _check_four_pray("all right", {0: "c", 1: "c", 2: "c", 3: "c"})
	await _check_four_pray("mixed", {0: "c", 1: "w", 2: "l", 3: "cwl"})
	await _check_four_pray("all late", {0: "l", 1: "l", 2: "l", 3: "l"})
	await _check_hit_and_quit()
	await _check_late_and_entry()
	await _check_lag_window()
	await _check_meditation_net()
	await _check_zeal_fight()
	await _check_v11_refused()
	await _check_client_cleric()
	await _check_host_window()
	await _check_meditation_late()
	await _check_slot_reuse()
	await _check_alone_net()
	await _check_late_join_net()
	return failures


# --- helpers -----------------------------------------------------------------------------------------------

## The int under `key` in `d` (0 when none).
static func _n(d: Dictionary, key: Variant) -> int:
	var v: int = d.get(key, 0)
	return v


## M10-fix: whether slot `slot`'s zeal is a prayer's on mirror `np` (`default` when it has none).
static func _zp(np: NetPrayer, slot: int, default: bool) -> bool:
	var v: bool = np.zeal_prayer.get(slot, default)
	return v


## Every member's request budget full (the malicious checks hand frames to run_frame faster than any client could).
static func _full(r: Rig) -> void:
	for slot: int in r.s.members:
		r.s.members[slot].op_budget = NetMember.OP_BUDGET_MAX


## Ticks the rig until `done` says so, at most `limit` ticks. Returns whether it did.
func _tick_until(r: Rig, done: Callable, limit: int) -> bool:
	for i: int in limit:
		var met: bool = done.call()
		if met:
			return true
		_tick(r)
	var last: bool = done.call()
	return last


static func _pray_action() -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.op = Main.request(NetProtocol.Op.PRAY)
	return a


static func _answer(n: int, t: int, dir: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.ANSWER, Config.MAP_SURFACE, Vector2i.ZERO)
	f.prayer_no = n
	f.turn = t
	f.answer = dir
	return f


static func _pray_frame(map: int = Config.MAP_SURFACE) -> NetProtocol.InputFrame:
	return _op(NetProtocol.Op.PRAY, map, Vector2i.ZERO)


## A rig whose host is a cleric with `faith` and three clients (paladin, archer, miner) on their spawn slots round the altar.
func _four(delay: int = 2, faith: int = 60) -> Rig:
	var r: Rig = _rig(CLERIC)
	r.delay = delay
	r.s.local.player.skills.resource = faith
	await await_frames(1)
	_join(r, 101, PALADIN)
	_join(r, 102, ARCHER)
	_join(r, 103, MINER)
	return r


## Every client has the welcome and goes idle.
func _settle(r: Rig) -> void:
	for c: Client in r.clients:
		c.action = null
	r.action = null
	_tick(r, 2 * r.delay + 4)


## The host and every client in it tap to pray (the host starts it, the clients join in the gather a few ticks apart); returns
## once the turns began.
func _start_four(r: Rig) -> void:
	r.action = _pray_action()
	_tick(r)
	r.action = null
	for c: Client in r.clients:
		c.action = _pray_action()
		_tick(r)
		c.action = null
	var guard: int = 0
	while r.host.prayer.phase != Prayer.Phase.TURNS and guard < Config.PRAYER_GATHER_TICKS + 60:
		_tick(r)
		guard += 1


## The slot of machine `c` (null: the host).
static func _slot_of(r: Rig, c: Client) -> int:
	return r.s.local.slot if c == null else c.s.local.slot


## This tick's answers: each machine whose turn's window is open on it presses its key `at` ticks into its window by its script
## (`scripts`: slot -> letters, its k-th turn's letter, the last one past the end: c right, w the opposite, l none). `turns_of`
## counts each slot's turns seen (host turns).
func _set_answers(r: Rig, scripts: Dictionary, at: int, counted: Dictionary) -> void:
	var pr: Prayer = r.host.prayer
	if pr.phase == Prayer.Phase.TURNS and pr.turn >= 0 and not counted.has(pr.turn):
		counted[pr.turn] = r.host._slot_by_id.get(pr.turn_owner, -1)
	var machines: Array = [null]
	machines.append_array(r.clients)
	for mc: Variant in machines:
		var c: Client = mc
		var slot: int = _slot_of(r, c)
		var dir: int = -1
		var k: int = 0
		for t: int in counted:
			if counted[t] == slot and t < pr.turn:
				k += 1
		var script: String = scripts.get(slot, "l")
		var letter: String = script[mini(k, script.length() - 1)]
		if c == null:
			var id: int = r.s.local.player.get_instance_id()
			if pr.prompt_for(id) >= 0 and pr.turn_ticks + 1 == at:
				dir = pr.directions[pr.turn]
		elif c.s.active and not c.s.over:
			var np: NetPrayer = c.s.client.prayer_net
			if np.window_open(c.s.tick + 1) and c.s.tick + 1 - np.seen_at == at:
				dir = np.mirror.directions[np.my_turn]
		var a: NetBot.Action = NetBot.Action.new()
		if dir >= 0 and letter != "l":
			a.dir = Prayer.DIR_VECTORS[dir if letter == "c" else (dir + 2) % 4]
		if c == null:
			r.action = a
		else:
			c.action = a


## Ticks the rig with the scripted answers until the host's prayer is over (and a little after, so the last messages arrive).
func _run_prayer(r: Rig, scripts: Dictionary, at: int = Config.PRAYER_TEST_ANSWER_TICK) -> void:
	var counted: Dictionary = {}
	var guard: int = 0
	while r.host.prayer.running() and guard < 5000:
		_set_answers(r, scripts, at, counted)
		_tick(r)
		guard += 1
	r.action = null
	for c: Client in r.clients:
		c.action = null
	_tick(r, 2 * r.delay + r.prayer_extra + 4)


## The lamps word, result and zeals every client has against the host's (`label` in the messages).
func _check_agree(r: Rig, label: String) -> void:
	var pr: Prayer = r.host.prayer
	var want_lamps: String = NetPrayer.lamps_word(pr.lamps)
	for c: Client in r.clients:
		if not c.s.active or c.s.over:
			continue
		var np: NetPrayer = c.s.client.prayer_net
		var name: String = "%s/c%d" % [label, c.s.local.slot]
		check_eq(NetPrayer.lamps_word(np.mirror.lamps), want_lamps, "%s: the lamps = the host's" % name)
		if pr.last != null and np.mirror.last != null:
			check(np.mirror.last.lit == pr.last.lit and np.mirror.last.zeal_pct == pr.last.zeal_pct and np.mirror.last.stopped
				== pr.last.stopped and np.mirror.last.faith == pr.last.faith,
				"%s: the result = the host's (lit %d/%d, zeal %d/%d, stopped %s/%s, faith %d/%d)" % [name, np.mirror.last.lit,
				pr.last.lit, np.mirror.last.zeal_pct, pr.last.zeal_pct, np.mirror.last.stopped, pr.last.stopped, np.mirror.last.faith,
				pr.last.faith])
		else:
			check(pr.last == null and np.mirror.last == null, "%s: neither has a result" % name)
		for slot: int in r.s.slots():
			var sk: SkillState = r.s.members[slot].player.skills
			var want: Vector2i = Vector2i(sk.zeal_pct, r.s.tick + sk.zeal_ticks) if sk.zealous() else Vector2i.ZERO
			var got: Vector2i = np.zeal.get(slot, Vector2i.ZERO)
			check_eq(got, want, "%s: player %d's zeal (%%, the tick it runs out) = the host's" % [name, slot])
			var q: Player = c.s.members[slot].player if c.s.members.has(slot) else null
			if q != null:
				check_eq(q.skills.zealous(), sk.zealous(), "%s: player %d shows zeal as the host has it" % [name, slot])


# --- the wire ----------------------------------------------------------------------------------------------

func _check_ops_codec() -> void:
	var frames: Array[NetProtocol.InputFrame] = [NetProtocol.InputFrame.new(70, Vector2i.ZERO), NetProtocol.InputFrame.new(71,
		Vector2i.ZERO)]
	frames[0].op = NetProtocol.Op.PRAY
	frames[0].map = Config.MAP_SURFACE
	frames[1].op = NetProtocol.Op.ANSWER
	frames[1].map = Config.MAP_SURFACE
	frames[1].prayer_no = 300
	frames[1].turn = 8
	frames[1].answer = Prayer.WIRE_SEVERAL
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 2 and p.frames[0].op == NetProtocol.Op.PRAY and p.frames[0].same_request(frames[0])
		and p.frames[1].op == NetProtocol.Op.ANSWER and p.frames[1].prayer_no == 300 % 256 and p.frames[1].turn == 8
		and p.frames[1].answer == Prayer.WIRE_SEVERAL, "PRAY and ANSWER round trip (the prayer's low byte)")
	check_eq(NetProtocol.OP_SIZES[NetProtocol.Op.PRAY], 1, "PRAY = its map (1 B)")
	check_eq(NetProtocol.OP_SIZES[NetProtocol.Op.ANSWER], 4, "ANSWER = map, prayer, turn, answer (4 B)")
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 2 + 1 + (2 + 1) + (2 + 4), "the packet: header, two codes, op count, PRAY, ANSWER")
	check(NetProtocol.op_has_map(NetProtocol.Op.PRAY) and NetProtocol.op_has_map(NetProtocol.Op.ANSWER), "both name the map")
	for cut: int in range(NetProtocol.INPUT_HEADER + 3, bytes.size()):
		check(not NetProtocol.decode_inputs(bytes.slice(0, cut)).ok, "a packet cut to %d B is refused" % cut)
	var at: int = bytes.size() - 4  # the ANSWER's map byte
	for bad: Array in [[at, Config.MAP_COUNT, "no map"], [at + 2, Config.PRAYER_TURNS, "turn 9"], [at + 3, Prayer.WIRE_SEVERAL + 1,
			"answer 5"], [at + 3, 255, "answer 255"], [NetProtocol.INPUT_HEADER + 3, Config.MAP_COUNT, "a PRAY on no map"]]:
		var b: PackedByteArray = bytes.duplicate()
		var where: int = bad[0]
		var v: int = bad[1]
		b.encode_u8(where, v)
		check(not NetProtocol.decode_inputs(b).ok, "an ANSWER / PRAY with %s is refused (the whole packet)" % str(bad[2]))
	var other: NetProtocol.InputFrame = _answer(4, 8, Prayer.WIRE_SEVERAL)
	check(not other.same_request(p.frames[1]) and _answer(44, 8, Prayer.WIRE_SEVERAL).same_request(p.frames[1]),
		"same_request compares an ANSWER's prayer, turn and answer")
	check(p.frames[1].describe_op().contains("answer map=0 prayer=44 turn=8 dir=several"), "an ANSWER describes itself (%s)" %
		p.frames[1].describe_op())
	check_eq(NetProtocol.VERSION, 12, "protocol version 12 (M10b: the prayer)")


static func _event(kind: int, tick: int = 1000) -> NetProtocol.PrayerEvent:
	var e: NetProtocol.PrayerEvent = NetProtocol.PrayerEvent.new()
	e.kind = kind
	e.tick = tick
	return e


func _check_events_codec() -> void:
	var K: Dictionary = {"start": NetProtocol.PrayerEvent.Kind.START}
	var all: Array[NetProtocol.PrayerEvent] = []
	var e0: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.START, 4000000000)
	e0.number = 7
	e0.slot = 8
	e0.face = RigData.Dir.WEST
	all.append(e0)
	var e1: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.JOIN)
	e1.slot = 3
	e1.face = RigData.Dir.NORTH
	all.append(e1)
	var e2: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.LEAVE)
	e2.slot = 2
	e2.why = Prayer.LEAVE_WHYS.find("hit")
	all.append(e2)
	var e3: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.STOP)
	e3.why = Prayer.STOP_WHYS.size() - 1
	all.append(e3)
	var e4: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.TURN)
	e4.turn = 8
	e4.slot = 1
	e4.dir = Prayer.Dir.RIGHT
	all.append(e4)
	var e5: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.RESULT)
	e5.turn = 8
	e5.why = Prayer.ANSWER_WHYS.find("left")
	all.append(e5)
	var e6: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.END)
	e6.lit = 9
	e6.participants = 9
	e6.pct = 31
	e6.faith = Config.PRAYER_FAITH_COST
	all.append(e6)
	var e7: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.MEDITATE)
	e7.slot = 4
	e7.face = RigData.Dir.SOUTH
	all.append(e7)
	var e8: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.MEDITATED)
	e8.slot = 4
	all.append(e8)
	var e9: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.BROKEN)
	e9.slot = 5
	e9.why = Prayer.LEAVE_WHYS.find("a prayer began")
	all.append(e9)
	var e10: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.ZEAL)
	e10.slot = 6
	e10.pct = 29
	e10.ticks = Config.PRAYER_ZEAL_TICKS
	e10.prayer_zeal = true
	all.append(e10)
	var e12: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.ZEAL)
	e12.slot = 5
	e12.pct = Config.MEDITATE_ZEAL_PCT
	e12.ticks = Config.MEDITATE_ZEAL_TICKS
	all.append(e12)
	var e11: NetProtocol.PrayerEvent = _event(NetProtocol.PrayerEvent.Kind.ZEAL)
	e11.slot = 6
	all.append(e11)
	var bytes: PackedByteArray = NetProtocol.encode_prayer(all)
	var d: NetProtocol.PrayerEvents = NetProtocol.decode_prayer(bytes)
	var same: bool = d.ok and d.events.size() == all.size()
	for i: int in mini(d.events.size(), all.size()):
		same = same and d.events[i].describe() == all[i].describe()
	check(same, "every prayer event kind round trips (%d events)" % all.size())
	var want_size: int = 1
	for e: NetProtocol.PrayerEvent in all:
		want_size += NetProtocol.PRAYER_EVENT_SIZES[e.kind]
	check_eq(bytes.size(), want_size, "the message is its count and its events' sizes")
	check_eq(NetProtocol.PRAYER_EVENT_SIZES, PackedInt32Array([8, 7, 7, 6, 8, 7, 9, 7, 6, 7, 10]),
		"event sizes: start 8, join 7, leave 7, stop 6, turn 8, result 7, end 9, meditate 7, meditated 6, broken 7, zeal 10 (B; " +
		"M10-fix: whose zeal, a prayer's or a meditation's)")
	var cuts: int = 0
	for cut: int in range(0, bytes.size()):
		if not NetProtocol.decode_prayer(bytes.slice(0, cut)).ok:
			cuts += 1
	check_eq(cuts, bytes.size(), "every cut message is refused")
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	check(not NetProtocol.decode_prayer(longer).ok, "one byte more is refused")
	check(NetProtocol.decode_prayer(PackedByteArray([0])).ok, "an empty list is a message")
	# Fields out of range, one event each (its kind, the field's offset after the kind and the tick, the bad value).
	var bad: Array[Array] = [
		[e0, 1, Config.MAX_PLAYERS, "a START's slot 9"], [e0, 2, 4, "a START's facing 4"], [e1, 0, 200, "a JOIN's slot 200"],
		[e1, 1, 9, "a JOIN's facing 9"], [e2, 1, Prayer.LEAVE_WHYS.size(), "a LEAVE's why past the list"],
		[e3, 0, Prayer.STOP_WHYS.size(), "a STOP's why past the list"], [e4, 0, Config.PRAYER_TURNS, "a TURN's turn 9"],
		[e4, 1, Config.MAX_PLAYERS, "a TURN's slot 9"], [e4, 2, 4, "a TURN's direction 4"],
		[e5, 0, Config.PRAYER_TURNS, "a RESULT's turn 9"], [e5, 1, Prayer.ANSWER_WHYS.size(), "a RESULT's how past the list"],
		[e6, 0, Config.PRAYER_TURNS + 1, "an END's 10 lamps"], [e6, 1, 0, "an END with nobody"],
		[e6, 1, Config.MAX_PLAYERS + 1, "an END with ten"], [e6, 2, 101, "an END's 101 %"], [e6, 3, Skills.max_resource() + 1,
		"an END spending past the largest meter"], [e7, 0, Config.MAX_PLAYERS, "a MEDITATE's slot 9"],
		[e8, 0, 255, "a MEDITATED's slot 255"], [e9, 1, 255, "a BROKEN's why 255"], [e10, 1, 101, "a ZEAL's 101 %"],
		[e10, 1, 0, "a ZEAL of 0 % with time left"], [e10, 4, 2, "a ZEAL's whose-zeal byte 2"],
		[e11, 4, 1, "an ended ZEAL (0 %) saying a prayer's"]]
	for row: Array in bad:
		var ev: NetProtocol.PrayerEvent = row[0]
		var at: int = row[1]
		var v: int = row[2]
		var one: PackedByteArray = NetProtocol.encode_prayer([ev] as Array[NetProtocol.PrayerEvent])
		check(NetProtocol.decode_prayer(one).ok, "%s: the event itself is fine" % str(row[3]))
		one.encode_u8(1 + 5 + at, v)
		check(not NetProtocol.decode_prayer(one).ok, "%s is refused" % str(row[3]))
	var zt: PackedByteArray = NetProtocol.encode_prayer([e10] as Array[NetProtocol.PrayerEvent])
	zt.encode_u16(1 + 5 + 2, maxi(Config.PRAYER_ZEAL_TICKS, Config.MEDITATE_ZEAL_TICKS) + 1)
	check(not NetProtocol.decode_prayer(zt).ok, "a ZEAL longer than any zeal is refused")
	var z0: PackedByteArray = NetProtocol.encode_prayer([e10] as Array[NetProtocol.PrayerEvent])
	z0.encode_u16(1 + 5 + 2, 0)
	check(not NetProtocol.decode_prayer(z0).ok, "a ZEAL with a % and no time is refused")
	var unknown: PackedByteArray = PackedByteArray([1, NetProtocol.PRAYER_EVENT_SIZES.size(), 0, 0, 0, 0, 0, 0, 0, 0])
	check(not NetProtocol.decode_prayer(unknown).ok, "an unknown kind is refused")
	check(K.size() == 1 and NetProtocol.PRAYER_KIND_NAMES.size() == NetProtocol.PRAYER_EVENT_SIZES.size(), "a name per kind")
	# M10-fix: a mirror off the surface skips the prayer's events (counted), keeps the zeal; the local window's edges (1..90 ticks
	# after its turn's event came).
	var np: NetPrayer = NetPrayer.new()
	np.setup(SurfaceGen.generate(Config.DEFAULT_SEED))
	np.apply(null, [e0, e1, e10] as Array[NetProtocol.PrayerEvent], 0, false)
	check(not np.mirror.running() and np.off_map == 2 and np.zeal.has(6), "off the surface: the start and the join skipped, the zeal kept")
	np.my_turn = 0
	np.seen_at = 100
	check(not np.window_open(100) and np.window_open(101) and np.window_open(100 + Config.PRAYER_ANSWER_WINDOW_TICKS)
		and not np.window_open(101 + Config.PRAYER_ANSWER_WINDOW_TICKS), "the local window: from the tick after its event, 90 ticks")
	np.sent_dir = Prayer.Dir.UP
	check(not np.window_open(101), "answered: closed")


# --- the host against a malicious client --------------------------------------------------------------------

func _check_malicious_prayer() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var cl: Client = _join(r, 111, CLERIC)
	var ar: Client = _join(r, 112, ARCHER)
	var mi: Client = _join(r, 113, MINER)
	var centre: Vector2 = r.surface.data.altar_center_px()
	var far: Client = _join(r, 114, HERBALIST, centre + Vector2(0, 120))
	_settle(r)
	var pr: Prayer = r.host.prayer
	var mc: NetMember = hm(r, cl)
	var ma: NetMember = hm(r, ar)
	var mm: NetMember = hm(r, mi)
	var mf: NetMember = hm(r, far)
	for m: NetMember in [r.s.local, mc, ma, mm]:
		check(Prayer.in_circle(r.surface.data, m.player.sim_position), "slot %d's spawn slot is in the prayer circle" % m.slot)
	check(not Prayer.in_circle(r.surface.data, mf.player.sim_position), "the herbalist stands outside it")
	# A non-cleric's tap with no prayer: it meditates (only a cleric starts one); its second tap stops that.
	r.host.run_frame(ma, _pray_frame())
	check(not pr.running() and pr.is_meditating(ma.player.get_instance_id()), "an archer's tap meditates: no prayer starts")
	_full(r)
	r.host.run_frame(ma, _pray_frame())
	check(not pr.is_meditating(ma.player.get_instance_id()), "its second tap stops the meditation")
	# M10-fix: ten PRAYs in one tick: the request budget takes NET_OP_BURST of them (a meditation, its stop, ...), the rest `rate`.
	var rate_p: int = _n(r.host.prayer_refusals, "rate")
	ma.op_budget = NetMember.OP_BUDGET_MAX
	for i: int in 10:
		r.host.run_frame(ma, _pray_frame())
	check_eq(_n(r.host.prayer_refusals, "rate") - rate_p, 10 - Config.NET_OP_BURST, "ten PRAYs in one tick: %d over the budget (`rate`)" %
		(10 - Config.NET_OP_BURST))
	check_eq(pr.is_meditating(ma.player.get_instance_id()), Config.NET_OP_BURST % 2 == 1, "the ones taken toggled the meditation")
	if pr.is_meditating(ma.player.get_instance_id()):
		pr.break_meditation(ma.player.get_instance_id(), "test")
	_full(r)
	# Outside the circle: refused, nothing changes.
	r.host.run_frame(mf, _pray_frame())
	check_eq(_n(r.host.prayer_refusals, Prayer.WHY_OUTSIDE), 1, "a tap outside the circle is refused (%s)" %
		r.host.prayer_refusals)
	# Another map's PRAY (a forged map): `wrong map`, before the budget.
	r.host.run_frame(mf, _pray_frame(Config.MAP_DUNGEON))
	check_eq(mf.refused(WorldItems.WHY_WRONG_MAP), 1, "a PRAY naming the dungeon: wrong map")
	# Faith short: no start; in combat: no start.
	mc.player.skills.resource = Config.PRAYER_FAITH_COST - 1
	_full(r)
	r.host.run_frame(mc, _pray_frame())
	check(not pr.running() and _n(r.host.prayer_refusals, Prayer.WHY_FAITH) == 1, "faith %d: no start" %
		(Config.PRAYER_FAITH_COST - 1))
	mc.player.skills.resource = 60
	mc.player.take_hit(1)
	var stagger: int = 0
	while Skills.busy(mc.player) and stagger < 120:
		_tick(r)
		stagger += 1
	_full(r)
	r.host.run_frame(mc, _pray_frame())
	check(not pr.running() and stagger < Config.PRAYER_COMBAT_HURT_TICKS and _n(r.host.prayer_refusals, Prayer.WHY_COMBAT) == 1,
		"hit %d ticks ago (the stagger over): in combat, no start (%s)" % [stagger, r.host.prayer_refusals])
	r.host.prayer.hurt_at.clear()
	_tick(r, 2)
	# The cleric starts; the archer and the miner join; the herbalist's join from outside the circle is refused.
	_full(r)
	r.host.run_frame(mc, _pray_frame())
	check(pr.running() and pr.cleric_id == mc.player.get_instance_id(), "the cleric's tap starts it")
	for m2: NetMember in [ma, mm]:
		_full(r)
		r.host.run_frame(m2, _pray_frame())
	_full(r)
	r.host.run_frame(mf, _pray_frame())
	check(pr.members.size() == 3 and not pr.is_member(mf.player.get_instance_id())
		and _n(r.host.prayer_refusals, Prayer.WHY_OUTSIDE) == 2, "two join, the herbalist outside the circle does not")
	# An answer in the gather: not this turn yet.
	_full(r)
	r.host.run_frame(ma, _answer(pr.number(), 0, Prayer.Dir.UP))
	check_eq(_n(r.host.prayer_refusals, Prayer.WHY_NOT_YET), 1, "an answer in the gather: not this turn yet")
	# Praying, every other request is refused (a use, a skill, a pick up); Q / E is not.
	var use: NetProtocol.InputFrame = _use(Config.MAP_SURFACE, beside(mm), WEAPON_SLOT, 0)
	r.host.run_frame(mm, use)
	r.host.run_frame(mm, _skill(Config.MAP_SURFACE, beside(mm), Skills.Slot.IDENTITY, mm.player.sim_position))
	r.host.run_frame(mm, _op(NetProtocol.Op.PICKUP, Config.MAP_SURFACE, beside(mm)))
	check(mm.refused(Skills.WHY_PRAYING) == 3 and mm.player.action_anim < 0, "praying: a use, a skill and a pick up are refused")
	var sel: NetProtocol.InputFrame = _op(NetProtocol.Op.SELECT, 0, Vector2i.ZERO, 2)
	r.host.run_frame(mm, sel)
	check_eq(mm.player.inventory.selected, 2, "Q / E still select while praying")
	# Nobody lifts the altar while a prayer is under way (the host's own player, not in it).
	var beside_altar: Vector2i = r.surface.data.altar_rect.position + Vector2i(-1, 1)
	r.s.local.player.teleport(_feet(beside_altar))
	var lift: NetProtocol.InputFrame = _op(NetProtocol.Op.ALTAR_LIFT, Config.MAP_SURFACE, beside_altar + Vector2i(1, 0))
	lift.interact = true
	r.s.local.altar_hold = Config.ALTAR_PICKUP_HOLD_TICKS - 1
	r.host.run_frame(r.s.local, lift)
	check(r.surface.data.altar_rect.has_area() and r.s.local.refused(Prayer.WHY_RUNNING) == 1,
		"the altar's lift while a prayer is under way: refused (`%s`; %s)" % [Prayer.WHY_RUNNING, r.s.local.ops_refused])
	# Run to the turns.
	_tick_until(r, func() -> bool: return pr.phase == Prayer.Phase.TURNS or not pr.running(), 600)
	var owner0: NetMember = r.host.member_of(pr.turn_owner)
	var other: NetMember = mm if owner0 != mm else ma
	_full(r)
	r.host.run_frame(other, _answer(pr.number(), 0, pr.directions[0]))
	check_eq(_n(r.host.prayer_refusals, Prayer.WHY_NOT_YOURS), 1, "an answer to another's turn: not your turn")
	_full(r)
	r.host.run_frame(owner0, _answer(pr.number() + 1, 0, pr.directions[0]))
	check_eq(_n(r.host.prayer_refusals, Prayer.WHY_OTHER_PRAYER), 1, "an answer naming another prayer is refused")
	_full(r)
	r.host.run_frame(owner0, _answer(pr.number(), 1, pr.directions[1]))
	check_eq(_n(r.host.prayer_refusals, Prayer.WHY_NOT_YET), 2, "an answer to the next turn: not this turn yet")
	# Two answers to one turn: the first right is taken, the second (the wrong key) refused; the lamp is lit once.
	_full(r)
	r.host.run_frame(owner0, _answer(pr.number(), 0, pr.directions[0]))
	r.host.run_frame(owner0, _answer(pr.number(), 0, (pr.directions[0] + 2) % 4))
	_tick(r)
	check(pr.lamps[0] == Prayer.Lamp.LIT and _n(r.host.prayer_refusals, Prayer.WHY_ANSWERED) == 1,
		"two answers to one turn: the first lights the lamp, the second is refused (%s)" % r.host.prayer_refusals)
	_full(r)
	r.host.run_frame(owner0, _answer(pr.number(), 0, pr.directions[0]))
	check_eq(_n(r.host.prayer_refusals, Prayer.WHY_ANSWERED), 2, "and once more in the gap: already answered")
	# Turn 1: its owner spams ten answers in one tick: four are within the budget (one taken), the rest `rate`.
	_tick_until(r, func() -> bool: return pr.turn >= 1 or not pr.running(), 600)
	var owner1: NetMember = r.host.member_of(pr.turn_owner)
	var rate0: int = owner1.refused("rate")
	owner1.op_budget = NetMember.OP_BUDGET_MAX
	for i: int in 10:
		r.host.run_frame(owner1, _answer(pr.number(), 1, pr.directions[1]))
	check(owner1.refused("rate") - rate0 == 10 - Config.NET_OP_BURST, "ten answers in one tick: %d over the budget (`rate`)" % (
		owner1.refused("rate") - rate0))
	_tick(r)
	check_eq(pr.lamps[1], Prayer.Lamp.LIT, "the spam's first answer counted, once")
	# A past turn: the owner of turn 0 answers it again during turn 2.
	_tick_until(r, func() -> bool: return pr.turn >= 2 or not pr.running(), 600)
	_full(r)
	r.host.run_frame(owner0, _answer(pr.number(), 0, pr.directions[0]))
	check(_n(r.host.prayer_refusals, Prayer.WHY_TURN_OVER) == 1, "an answer to a past turn: that turn is over")
	# A participant hit on the host leaves; its machine answering on as if it were not changes nothing (its answers: not
	# praying; its tap: the turns have begun).
	var hit_one: NetMember = ma if pr.turn_owner != ma.player.get_instance_id() else mm
	hit_one.player.take_hit(1)
	check(not pr.is_member(hit_one.player.get_instance_id()) and hit_one.player.prayer_role == Prayer.Role.NONE,
		"a hit takes the participant out on the host")
	_full(r)
	r.host.run_frame(hit_one, _answer(pr.number(), pr.turn, Prayer.Dir.UP))
	_tick_until(r, func() -> bool: return not Skills.busy(hit_one.player), 120)  # its stagger over
	_full(r)
	r.host.run_frame(hit_one, _pray_frame())
	check(_n(r.host.prayer_refusals, Prayer.WHY_NOT_PRAYING) == 1 and _n(r.host.prayer_refusals, Prayer.WHY_CLOSED)
		== 1 and not pr.is_member(hit_one.player.get_instance_id()), "after the hit its answers (`not praying`) and its rejoin " +
		"(`the turns have begun`) are refused")
	# Quitting twice: the other one taps (leaves), taps again: the turns have begun, nothing else.
	var quitter: NetMember = mm if hit_one == ma else ma
	_full(r)
	r.host.run_frame(quitter, _pray_frame())
	var left_events: int = 0
	_full(r)
	r.host.run_frame(quitter, _pray_frame())
	_tick(r, 2 * r.delay + 2)
	for e: NetProtocol.PrayerEvent in ar.prayer_events:
		if e.kind == NetProtocol.PrayerEvent.Kind.LEAVE and e.slot == quitter.slot:
			left_events += 1
	check(not pr.is_member(quitter.player.get_instance_id()) and pr.running() and left_events == 1
		and _n(r.host.prayer_refusals, Prayer.WHY_CLOSED) == 2, "quitting twice: it left once (one LEAVE), the second " +
		"tap is refused, the prayer goes on")
	# The machines heard it: the hit one and the quitter are free on their own machines.
	check(hm(r, ar).player.prayer_role == Prayer.Role.NONE and ar.s.local.player.prayer_role == Prayer.Role.NONE
		and mi.s.local.player.prayer_role == Prayer.Role.NONE, "both are out of it on their machines too")
	_free_rig(r)


# --- flows ---------------------------------------------------------------------------------------------------

## Four complete a prayer with the answers of `scripts` (slot -> letters): every machine agrees with the host.
func _check_four_pray(label: String, scripts: Dictionary) -> void:
	var r: Rig = await _four(2)
	_settle(r)
	var bytes0: int = r.bytes_by_kind.get("prayer", 0)
	_start_four(r)
	var pr: Prayer = r.host.prayer
	check_eq(pr.members.size(), 4, "%s: four pray" % label)
	var order: Array[int] = []
	for id: int in pr.order:
		var sl: int = r.host._slot_by_id.get(id, -1)
		order.append(sl)
	check_eq(order, [0, 1, 2, 3] as Array[int], "%s: the turns go round in the order they joined" % label)
	_run_prayer(r, scripts)
	var lit: int = 0
	var counts: Dictionary = {}
	for t: int in Config.PRAYER_TURNS:
		var slot: int = order[t % 4]
		var k: int = counts.get(slot, 0)
		counts[slot] = k + 1
		var script: String = scripts[slot]
		if script[mini(k, script.length() - 1)] == "c":
			lit += 1
	check(pr.last != null and not pr.last.stopped and pr.last.lit == lit and pr.last.participants == 4
		and pr.last.zeal_pct == Prayer.zeal_pct(lit, 4) and pr.last.faith == Config.PRAYER_FAITH_COST,
		"%s: the host's result: %d lit of 9, four, zeal %d%%, faith %d spent (%s)" % [label, lit, Prayer.zeal_pct(lit, 4),
		Config.PRAYER_FAITH_COST, NetPrayer.lamps_word(pr.lamps)])
	check_eq(r.s.local.player.skills.resource, 60 - Config.PRAYER_FAITH_COST, "%s: the cleric's faith after" % label)
	_check_agree(r, label)
	for c: Client in r.clients:
		check_prediction("%s/c%d" % [label, c.s.local.slot], c)
		check_eq(c.s.client.prayer_net.answers_sent, _n(c.s.client.prayer_net.my_results, "ok")
			+ _n(c.s.client.prayer_net.my_results, "wrong"), "%s/c%d: each answer it sent came back judged" % [label,
			c.s.local.slot])
	var answered: int = 0
	for slot2: int in scripts:
		for ch: String in scripts[slot2]:
			if ch != "l":
				answered += 1
	check(r.host.answer_ticks.size() >= mini(answered, 1) or answered == 0, "%s: answers taken %s" % [label, r.host.answer_ticks])
	var bytes1: int = r.bytes_by_kind.get("prayer", 0)
	var per_client: int = (bytes1 - bytes0) / r.clients.size()
	note("%s: lamps %s, zeal %d%%, answers taken at window ticks %s, prayer bytes a client %d (one prayer of four)" % [label,
		NetPrayer.lamps_word(pr.lamps), pr.last.zeal_pct if pr.last != null else -1, r.host.answer_ticks, per_client])
	if label == "all right":
		check(per_client > 0 and per_client <= 400, "%s: one prayer of four costs a client %d B (README)" % [label, per_client])
	_free_rig(r)


## A participant hit mid-prayer leaves alone (its later turns go to the others) on every machine; then the cleric quits: the
## prayer stops on every machine, nobody gets zeal, no faith is spent.
func _check_hit_and_quit() -> void:
	var r: Rig = await _four(2)
	_settle(r)
	_start_four(r)
	var pr: Prayer = r.host.prayer
	var counted: Dictionary = {}
	var scripts: Dictionary = {0: "c", 1: "c", 2: "c", 3: "c"}
	while (pr.turn < 1 or pr.turn_ticks < 5) and pr.running():
		_set_answers(r, scripts, Config.PRAYER_TEST_ANSWER_TICK, counted)
		_tick(r)
	var archer: NetMember = r.s.members[2]
	archer.player.take_hit(1)  # turn 1 is the paladin's; the archer (turn 2's) is hit
	var owners: Array[int] = []
	while pr.running() and pr.turn < 4:
		_set_answers(r, scripts, Config.PRAYER_TEST_ANSWER_TICK, counted)
		_tick(r)
		var o: int = r.host._slot_by_id.get(pr.turn_owner, -1)
		if pr.turn >= 2 and (owners.size() < pr.turn - 1):
			owners.append(o)
	check_eq(owners, [3, 0, 1] as Array[int], "the hit archer's turn 2 went to the miner, turn 3 to the cleric, 4 to the paladin (%s)" % [owners])
	_tick(r, 2 * r.delay + 2)
	for c: Client in r.clients:
		var np: NetPrayer = c.s.client.prayer_net
		check(np.mirror.members.size() == 3 and np.mirror.running(), "c%d: three still pray" % c.s.local.slot)
	var ac: Client = r.clients[1]
	check(ac.s.local.player.prayer_role == Prayer.Role.NONE and ac.s.client.prayer_net.my_turn < 0,
		"the archer's machine: it is out (it may move again)")
	# It walks away (its prediction moves it, the host does too).
	var before: Vector2 = ac.s.local.player.sim_position
	ac.action = NetBot.Action.new()
	ac.action.dir = Vector2i(1, 0)
	_tick(r, 10)
	ac.action = null
	_tick(r, 2 * r.delay + 4)
	check(ac.s.local.player.sim_position.x > before.x + 5.0 and absf(archer.player.sim_position.x - ac.s.local.player.sim_position.x)
		< 0.001, "out of it the archer walks, on its machine and the host alike")
	check_prediction("hit/archer", ac)
	# The miner's client leaves the session mid-prayer: its Player is freed on the host; the next step lets it go ("gone"), no
	# engine error (the runner counts them), the others hear it; two still pray.
	var mc3: Client = r.clients[2]
	var miner_slot: int = mc3.s.local.slot
	r.host.on_peer_disconnected(mc3.peer)
	mc3.s.over = true
	_tick(r, 2 * r.delay + 4)
	var gone_events: int = 0
	for e: NetProtocol.PrayerEvent in r.clients[0].prayer_events:
		if e.kind == NetProtocol.PrayerEvent.Kind.LEAVE and e.slot == miner_slot and e.why == Prayer.LEAVE_WHYS.find("gone"):
			gone_events += 1
	check(pr.running() and pr.members.size() == 2 and gone_events == 1 and r.clients[0].s.client.prayer_net.mirror.members.size() == 2,
		"the miner's client left the session: it is gone from the prayer (one LEAVE gone), two pray on, the paladin's machine too")
	# The cleric (the host) taps: it stops.
	r.action = _pray_action()
	_tick(r)
	r.action = null
	_tick(r, 2 * r.delay + 4)
	check(not pr.running() and pr.last.stopped and pr.last.why == "the cleric: quit" and r.s.local.player.skills.resource == 60,
		"the cleric quits: it stops, no faith spent (%s)" % (pr.last.why if pr.last != null else "?"))
	for slot: int in r.s.slots():
		check(not r.s.members[slot].player.skills.zealous(), "nobody has zeal after a stop (player %d)" % slot)
	_check_agree(r, "quit")
	for c2: Client in r.clients:
		if c2.s.over:
			continue  # the miner left
		var np2: NetPrayer = c2.s.client.prayer_net
		check(not np2.mirror.running() and np2.mirror.last != null and np2.mirror.last.stopped and np2.mirror.last.why ==
			"the cleric: quit" and c2.s.local.player.prayer_role == Prayer.Role.NONE, "c%d: stopped there too, free" % c2.s.local.slot)
	_free_rig(r)


## What machine `c` (null: the host) draws of its prayer now (show_prayer_from on its world): the altar's lamp looks, the circle
## (shown, its shift) and each player's mark by slot (kind/direction/bar), the slots in `skip` left out.
func _drawn(r: Rig, c: Client, view: PrayerView, skip: Array[int]) -> String:
	var s: NetSession = r.s if c == null else c.s
	var pr: Prayer = r.host.prayer if c == null else c.s.client.prayer_net.mirror
	var w: GameWorld = r.surface if c == null else c.surface
	var everyone: Array[Player] = []
	for slot: int in s.slots():
		everyone.append(s.members[slot].player)
	Main.show_prayer_from(pr, true, w, view, everyone, s.local.player, null, -1, 0, -1)
	var parts: PackedStringArray = ["lamps=%s" % w.altar.looks, "circle=%s/%d" % [view.shown, view.shift]]
	for slot2: int in s.slots():
		if skip.has(slot2):
			continue
		var pm: PrayerMark = s.members[slot2].player.prayer_mark
		parts.append("%d:%d/%d/%d" % [slot2, pm.kind, pm.dir, pm.fill])
	return " ".join(parts)


## A late joiner during the turns and a player who comes back to the surface get the prayer under way: the same lamps, members,
## turn and owner as the host, and they draw what the host draws (no delay: the same host tick).
func _check_late_and_entry() -> void:
	var r: Rig = _rig(CLERIC)
	r.s.local.player.skills.resource = 60
	await await_frames(1)
	_join(r, 121, PALADIN)
	_join(r, 122, ARCHER)
	_settle(r)
	r.action = _pray_action()
	_tick(r)
	r.action = null
	r.clients[0].action = _pray_action()
	_tick(r)
	r.clients[0].action = null
	var pr: Prayer = r.host.prayer
	var counted: Dictionary = {}
	var scripts: Dictionary = {0: "cw", 1: "c"}
	while (pr.turn < 3 or pr.turn_ticks < 12) and pr.running():
		_set_answers(r, scripts, 10, counted)
		_tick(r)
	r.action = null
	r.clients[0].action = null
	var late: Client = _join(r, 123, MINER, null, false)
	var np: NetPrayer = late.s.client.prayer_net
	check(np.mirror.running() and np.mirror.phase == Prayer.Phase.TURNS and np.mirror.members.size() == 2
		and np.mirror.turn == pr.turn and late.s.client.prayer_net.mirror.prayers == pr.number(),
		"the late joiner has the prayer under way: turns, two in it, turn %d (%s)" % [np.mirror.turn,
		NetPrayer.lamps_word(np.mirror.lamps)])
	check_eq(NetPrayer.lamps_word(np.mirror.lamps), NetPrayer.lamps_word(pr.lamps), "its lamps so far = the host's")
	var owner_slot: int = r.host._slot_by_id.get(pr.turn_owner, -1)
	var owner_here: Player = late.s.members[owner_slot].player
	check(np.mirror.turn_owner == owner_here.get_instance_id() and np.mirror.current_lamp() == pr.current_lamp(),
		"the turn under way and its owner (slot %d) = the host's" % owner_slot)
	# The same picture (delay 0: the client's host tick is the host's).
	var hv: PrayerView = PrayerView.new()
	add_node(hv)
	var cv: PrayerView = PrayerView.new()
	add_node(cv)
	var same: int = 0
	var frames: int = 0
	var first_diff: String = ""
	for i: int in 200:
		_tick(r)
		for c: Client in [r.clients[0], r.clients[1], late]:
			c.s.client.prayer_net.tick(c.s, r.s.tick)
			var skip: Array[int] = [r.s.local.slot, c.s.local.slot]
			var host_pic: String = _drawn(r, null, hv, skip)
			var client_pic: String = _drawn(r, c, cv, skip)
			frames += 1
			if host_pic == client_pic:
				same += 1
			elif first_diff.is_empty():
				first_diff = "tick %d c%d: host %s / client %s" % [r.s.tick, c.s.local.slot, host_pic, client_pic]
	check_eq(same, frames, "every machine draws the host's lamps, circle and marks at the same tick (%s)" % first_diff)
	late.action = _pray_action()
	_tick(r)
	late.action = null
	check(_n(r.host.prayer_refusals, Prayer.WHY_CLOSED) == 1, "the late joiner's tap: the turns have begun")
	# The archer (not in it) goes down to the dungeon and comes back while it runs: its entry has the prayer again.
	var am: NetMember = hm(r, r.clients[1])
	r.host.move_to_map(am, Config.MAP_DUNGEON)
	_tick(r, 12)
	check(not r.clients[1].s.client.prayer_net.mirror.running(), "in the dungeon the archer shows no prayer")
	r.host.move_to_map(am, Config.MAP_SURFACE)
	_tick(r, 12)
	var anp: NetPrayer = r.clients[1].s.client.prayer_net
	check(anp.mirror.running() and NetPrayer.lamps_word(anp.mirror.lamps) == NetPrayer.lamps_word(pr.lamps)
		and anp.mirror.members.size() == 2, "back on the surface its entry has the prayer: %s" % NetPrayer.lamps_word(anp.mirror.lamps))
	_run_prayer(r, scripts, 10)
	_check_agree(r, "late")
	check(late.s.local.player.skills.zealous() == false and late.s.members[0].player.skills.zealous(),
		"the late joiner: no zeal of its own, the cleric's zeal drawn")
	hv.queue_free()
	cv.queue_free()
	_free_rig(r)


## Over a 4-tick and a 12-tick delay each way: a client answering 88 ticks into the window its machine shows is taken by the host
## (the lag allowance: it arrives past the host's own 90; at 12 ticks, 24 past it, inside the allowance's 30), and the lamp lights
## on every machine. Over a 20-tick delay (a round trip past the allowance) the same answer comes after the host gave the turn up
## (late): `that turn is over`. M10-fix: a turn's event that comes a resend late (a lost reliable message: ENet sends it again
## about a round trip and a margin later) shifts that client's window by it: over a 4-tick delay with every prayer message 18 ticks
## more on the way down (a resend at a ~130 ms round trip) the answers still come inside the allowance (at 114 of 120); 26 more
## (two round trips' worth) and they come past it (122): the allowance holds a round trip plus one resend only on a short link
## (README "M10b 답 판정").
func _check_lag_window() -> void:
	for pair: Vector2i in [Vector2i(4, 0), Vector2i(12, 0), Vector2i(20, 0), Vector2i(4, 18), Vector2i(4, 26)]:
		var delay: int = pair.x
		var r: Rig = _rig(CLERIC)
		r.delay = delay
		r.prayer_extra = pair.y
		r.s.local.player.skills.resource = 60
		await await_frames(1)
		_join(r, 131, PALADIN)
		_settle(r)
		r.action = _pray_action()
		_tick(r)
		r.action = null
		r.clients[0].action = _pray_action()
		_tick(r)
		r.clients[0].action = null
		_run_prayer(r, {0: "c", 1: "c"}, Config.PRAYER_ANSWER_WINDOW_TICKS - 2)
		var pr: Prayer = r.host.prayer
		var c: Client = r.clients[0]
		var ok: int = _n(c.s.client.prayer_net.my_results, "ok")
		var over: int = _n(r.host.prayer_refusals, Prayer.WHY_TURN_OVER)
		var late_taken: int = 0
		for at: int in r.host.answer_ticks:
			if at > Config.PRAYER_ANSWER_WINDOW_TICKS:
				late_taken += 1
		var label: String = "delay %d%s" % [delay, " + resend %d" % pair.y if pair.y > 0 else ""]
		if 2 * delay + pair.y + Config.PRAYER_ANSWER_WINDOW_TICKS - 2 <= Config.PRAYER_ANSWER_WINDOW_TICKS + Config.PRAYER_ANSWER_LAG_TICKS:
			check(ok == 4 and late_taken == 4 and pr.last.lit == 9,
				"%s: the client's four answers at tick 88 of its window are taken (at host window ticks %s), nine lit" %
				[label, r.host.answer_ticks])
		else:
			check(ok == 0 and over == 4 and _n(c.s.client.prayer_net.my_results, "late") == 4 and pr.last.lit == 5,
				"%s: its answers come after the turn was given up: refused as over (%d), its four lamps out (late)" % [label, over])
		_check_agree(r, label)
		check_prediction("lag %s" % label, c)
		_free_rig(r)


## Meditation in a session: a non-cleric's tap meditates; every machine shows its ring and bar; after MEDITATE_TICKS its zeal on
## every machine; another walking off breaks its own (every machine).
func _check_meditation_net() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	_join(r, 141, ARCHER)
	_join(r, 142, MINER)
	_settle(r)
	var a: Client = r.clients[0]
	var m: Client = r.clients[1]
	a.action = _pray_action()
	m.action = _pray_action()
	_tick(r)
	a.action = null
	m.action = null
	_tick(r, 30)
	var pr: Prayer = r.host.prayer
	var aid: int = hm(r, a).player.get_instance_id()
	check(pr.is_meditating(aid) and pr.is_meditating(hm(r, m).player.get_instance_id()), "two meditate on the host")
	for c: Client in r.clients:
		var np: NetPrayer = c.s.client.prayer_net
		check(np.meditating.size() == 2, "c%d: two meditate there" % c.s.local.slot)
	m.action = NetBot.Action.new()
	m.action.dir = Vector2i(0, 1)
	_tick(r, 4)
	m.action = null
	_tick(r, Config.MEDITATE_TICKS)
	check(a.s.local.player.skills.zeal_pct == Config.MEDITATE_ZEAL_PCT and hm(r, a).player.skills.zealous()
		and not hm(r, m).player.skills.zealous(), "the archer's meditation gave its zeal (%d%%), the miner's broke (it walked)" %
		Config.MEDITATE_ZEAL_PCT)
	var aslot: int = a.s.local.slot
	check(not hm(r, a).player.skills.zeal_from_prayer and not a.s.local.player.skills.zeal_from_prayer
		and not _zp(a.s.client.prayer_net, aslot, true) and not m.s.members[aslot].player.skills.zeal_from_prayer,
		"M10-fix: a meditation's zeal on every machine (it does not block a prayer)")
	_check_agree(r, "meditation")
	for c2: Client in r.clients:
		check(c2.s.client.prayer_net.meditating.is_empty(), "c%d: no meditation left" % c2.s.local.slot)
	_free_rig(r)


## The zeal in a session fight: after an all-right prayer of four, the paladin client's sword hits a heretic for its damage with
## the zeal (the host's arena), the late joiner without zeal for the plain damage; every machine sees the heretic's HP as the host;
## the archer gives up while down and dies: its zeal is gone on every machine.
func _check_zeal_fight() -> void:
	var r: Rig = await _four(2)
	_settle(r)
	_start_four(r)
	_run_prayer(r, {0: "c", 1: "c", 2: "c", 3: "c"})
	var pct: int = r.host.prayer.last.zeal_pct
	check_eq(pct, Prayer.zeal_pct(9, 4), "four, nine lit: zeal %d%%" % Prayer.zeal_pct(9, 4))
	var late: Client = _join(r, 154, HERBALIST)
	_tick(r, 2 * r.delay + 4)
	check(late.s.client.prayer_net.zeal.size() == 4, "the late joiner got the four zeals in its welcome (%s)" %
		late.s.client.prayer_net.zeal)
	for slot0: int in 4:
		check(_zp(late.s.client.prayer_net, slot0, false) and late.s.members[slot0].player.skills.zeal_from_prayer,
			"M10-fix: player %d's zeal there is a prayer's (it blocks a new prayer)" % slot0)
	var pal: NetMember = r.s.members[1]
	var a: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = a.spawn_heretic(pal.player.sim_position + Vector2(18, 0))
	var base: int = Combat.attack_for(&"sword").damage
	var c1: Client = r.clients[0]
	c1.action = swing_at(h.pos)
	var hp0: int = h.hp
	var guard: int = 0
	while h.hp == hp0 and guard < 60:
		_tick(r)
		guard += 1
	c1.action = null
	check_eq(hp0 - h.hp, Prayer.zeal_hit(base, pct), "the paladin client's sword with %d%% zeal: %d (not %d)" % [pct,
		Prayer.zeal_hit(base, pct), base])
	_tick(r, 2 * r.delay + 6)
	check_eq(hp_mismatches(r, c1), 0, "the paladin's machine has the heretic's HP the host had")
	# The archer goes down and gives up: dead, its zeal gone on every machine.
	var arc: NetMember = r.s.members[2]
	arc.player.take_hit(Config.PLAYER_HP_MAX * 2)
	var ac: Client = r.clients[1]
	ac.action = holding_f()
	guard = 0
	while arc.player.vitals.life != Vitals.Life.DEAD and guard < Config.GIVE_UP_HOLD_TICKS + 120:
		_tick(r)
		guard += 1
	ac.action = null
	_tick(r, 2 * r.delay + 4)
	check(arc.player.vitals.life == Vitals.Life.DEAD and not arc.player.skills.zealous(), "the archer died: its zeal is gone")
	for c: Client in r.clients:
		check(not c.s.client.prayer_net.zeal.has(2) and c.s.client.prayer_net.zeal.has(1),
			"c%d: the archer's zeal gone, the paladin's kept" % c.s.local.slot)
	# M10-fix: a client shows no zeal on a dead player even with a zeal still listed for it (the host's 0 event not come yet).
	var np0: NetPrayer = ac.s.client.prayer_net
	var dead: Player = ac.s.local.player
	np0.zeal[2] = Vector2i(20, r.s.tick + 1000)
	np0.tick(ac.s, r.s.tick)
	check(dead.vitals.life == Vitals.Life.DEAD and not dead.skills.zealous(),
		"a dead player shows no zeal on a client (its own machine: life %d)" % dead.vitals.life)
	np0.zeal.erase(2)
	a.heretics.clear()
	_free_rig(r)


# --- M10-fix (the review) --------------------------------------------------------------------------------------

## The host and clients tap in turn: the host (`host_taps`), then each client of `who`, a tick apart.
func _taps(r: Rig, host_taps: bool, who: Array[Client]) -> void:
	if host_taps:
		r.action = _pray_action()
		_tick(r)
		r.action = null
	for c: Client in who:
		c.action = _pray_action()
		_tick(r)
		c.action = null


## A client is the cleric: its tap starts the host's prayer; it quits after two turns: it stops everywhere, no faith spent (on the
## host and its own meter); a second prayer it leads to the end spends its faith there and on its meter; every machine agrees.
func _check_client_cleric() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 2
	await await_frames(1)
	var cl: Client = _join(r, 181, CLERIC)
	var ar: Client = _join(r, 182, ARCHER)
	_settle(r)
	var mc: NetMember = hm(r, cl)
	mc.player.skills.resource = 60
	_tick(r, 2 * r.delay + 6)
	check_eq(cl.s.local.player.skills.resource, 60, "client cleric: its meter on its machine")
	var pr: Prayer = r.host.prayer
	_taps(r, false, [cl] as Array[Client])
	_tick(r, 2 * r.delay + 2)
	check(pr.running() and pr.cleric_id == mc.player.get_instance_id(), "a client cleric's tap starts the host's prayer")
	_taps(r, true, [ar] as Array[Client])
	_tick_until(r, func() -> bool: return pr.phase == Prayer.Phase.TURNS or not pr.running(), Config.PRAYER_GATHER_TICKS + 60)
	check_eq(pr.members.size(), 3, "client cleric: three pray")
	var counted: Dictionary = {}
	var scripts: Dictionary = {0: "c", 1: "c", 2: "c"}
	while pr.running() and pr.turn < 2:
		_set_answers(r, scripts, Config.PRAYER_TEST_ANSWER_TICK, counted)
		_tick(r)
	r.action = null
	for c: Client in r.clients:
		c.action = null
	_taps(r, false, [cl] as Array[Client])
	_tick(r, 2 * r.delay + 4)
	check(not pr.running() and pr.last != null and pr.last.stopped and pr.last.why == "the cleric: quit",
		"the client cleric taps again: it stops (%s)" % (pr.last.why if pr.last != null else "?"))
	check(mc.player.skills.resource == 60 and cl.s.local.player.skills.resource == 60, "no faith spent (host %d, its meter %d)" % [
		mc.player.skills.resource, cl.s.local.player.skills.resource])
	_check_agree(r, "client cleric quit")
	for c2: Client in r.clients:
		check(not c2.s.client.prayer_net.mirror.running() and c2.s.local.player.prayer_role == Prayer.Role.NONE,
			"c%d: stopped there, free" % c2.s.local.slot)
	_tick(r, Config.PRAYER_RESULT_SHOW_TICKS)
	_taps(r, false, [cl] as Array[Client])
	_tick(r, 2 * r.delay + 2)
	_taps(r, true, [ar] as Array[Client])
	_run_prayer(r, scripts)
	check(pr.last != null and not pr.last.stopped and pr.last.lit == 9 and pr.last.participants == 3
		and pr.last.faith == Config.PRAYER_FAITH_COST, "the client cleric's second prayer: nine lit, three, faith spent")
	_tick(r, 2 * r.delay + 6)
	check(mc.player.skills.resource == 60 - Config.PRAYER_FAITH_COST and cl.s.local.player.skills.resource
		== 60 - Config.PRAYER_FAITH_COST, "its faith %d on the host and on its own meter (%d)" % [mc.player.skills.resource,
		cl.s.local.player.skills.resource])
	_check_agree(r, "client cleric")
	check_prediction("client cleric", cl)
	_free_rig(r)


## The host's own player answers only in the window its HUD shows (PRAYER_ANSWER_WINDOW_TICKS: the lag allowance after it is the
## remote clients'): its key on the window's last tick is taken, five ticks later it is no answer (its lamps go out late).
func _check_host_window() -> void:
	for at: int in [Config.PRAYER_ANSWER_WINDOW_TICKS, Config.PRAYER_ANSWER_WINDOW_TICKS + 5]:
		var r: Rig = _rig(CLERIC)
		r.s.local.player.skills.resource = 60
		await await_frames(1)
		_join(r, 191, PALADIN)
		_settle(r)
		_taps(r, true, r.clients)
		_run_prayer(r, {0: "c", 1: "l"}, at)
		var pr: Prayer = r.host.prayer
		var lit: int = 0
		for t: int in [0, 2, 4, 6, 8]:
			if pr.last != null and pr.last.lamps[t] == Prayer.Lamp.LIT:
				lit += 1
		if at <= Config.PRAYER_ANSWER_WINDOW_TICKS:
			check(lit == 5 and r.host.answer_ticks.size() == 5, "the host's key %d ticks into its turns: taken (%d lit, at %s)" % [at, lit,
				r.host.answer_ticks])
		else:
			check(lit == 0 and r.host.answer_ticks.is_empty(), "the host's key %d ticks into its turns (past its HUD's window): " % at +
				"no answer, its five lamps out (%d lit, at %s)" % [lit, r.host.answer_ticks])
		_free_rig(r)


## A meditation under way reaches a late joiner (send_prayer_snapshot's meditations): its spark and bar as the host draws them.
func _check_meditation_late() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var a: Client = _join(r, 201, ARCHER)
	_settle(r)
	_taps(r, false, [a] as Array[Client])
	_tick(r, 40)
	var aslot: int = a.s.local.slot
	check(r.host.prayer.is_meditating(hm(r, a).player.get_instance_id()), "the archer meditates")
	var late: Client = _join(r, 202, MINER, null, false)
	var np: NetPrayer = late.s.client.prayer_net
	check(np.meditating.has(aslot), "the late joiner has the archer's meditation under way")
	var hv: PrayerView = PrayerView.new()
	add_node(hv)
	var cv: PrayerView = PrayerView.new()
	add_node(cv)
	_tick(r)
	np.tick(late.s, r.s.tick)
	var skip: Array[int] = [r.s.local.slot, late.s.local.slot]
	var host_pic: String = _drawn(r, null, hv, skip)
	var client_pic: String = _drawn(r, late, cv, skip)
	check(host_pic.contains("%d:%d/" % [aslot, PrayerMark.Kind.MEDITATE]), "the host draws the archer meditating (%s)" % host_pic)
	check_eq(client_pic, host_pic, "the late joiner draws its spark and bar as the host does")
	hv.queue_free()
	cv.queue_free()
	_free_rig(r)


## A joiner gets the slot of a participant who left the session mid-prayer: on its machine the snapshot's events of that slot from
## before its welcome are the former player's (no left mark over the newcomer, no turn or result of its), the members, the lamps and
## every mark as the host draws them.
func _check_slot_reuse() -> void:
	var r: Rig = _rig(CLERIC)
	r.s.local.player.skills.resource = 60
	await await_frames(1)
	_join(r, 211, PALADIN)
	var ac: Client = _join(r, 212, ARCHER)
	_settle(r)
	_taps(r, true, r.clients)
	var pr: Prayer = r.host.prayer
	var counted: Dictionary = {}
	var scripts: Dictionary = {0: "c", 1: "c", 2: "c"}
	while pr.running() and (pr.turn < 2 or pr.turn_ticks < 5):
		_set_answers(r, scripts, Config.PRAYER_TEST_ANSWER_TICK, counted)
		_tick(r)
	r.action = null
	for c: Client in r.clients:
		c.action = null
	var slot: int = ac.s.local.slot
	var old_id: int = hm(r, ac).player.get_instance_id()
	r.host.on_peer_disconnected(ac.peer)
	ac.s.over = true
	_tick(r, 2)
	check(pr.running() and not pr.is_member(old_id) and pr.left_at.has(old_id), "the archer left the session: gone from the prayer")
	var late: Client = _join(r, 213, HERBALIST, null, false)
	check_eq(late.s.local.slot, slot, "the newcomer gets its slot (%d)" % slot)
	var np: NetPrayer = late.s.client.prayer_net
	var hv: PrayerView = PrayerView.new()
	add_node(hv)
	var cv: PrayerView = PrayerView.new()
	add_node(cv)
	_tick(r)
	np.tick(late.s, r.s.tick)
	var me: int = late.s.local.player.get_instance_id()
	check(not np.mirror.left_at.has(me) and not np.mirror.is_member(me) and np.my_turn < 0 and np.my_results.is_empty(),
		"the newcomer is not the one who left: no left mark, no turn, no result of its")
	check(np.mirror.members.size() == pr.members.size() and NetPrayer.lamps_word(np.mirror.lamps) == NetPrayer.lamps_word(pr.lamps),
		"the members and the lamps = the host's (%s)" % NetPrayer.lamps_word(np.mirror.lamps))
	var skip: Array[int] = [r.s.local.slot]
	check_eq(_drawn(r, late, cv, skip), _drawn(r, null, hv, skip), "it draws every mark as the host does (its own: none)")
	hv.queue_free()
	cv.queue_free()
	_free_rig(r)


## A session gather that ends with the cleric alone (a paladin beside him never joins): it stops (`nobody joined`) on every machine,
## no faith spent, and the cleric meditates instead; its zeal is a meditation's on every machine.
func _check_alone_net() -> void:
	var r: Rig = _rig(CLERIC)
	r.delay = 2
	r.s.local.player.skills.resource = 60
	await await_frames(1)
	var c: Client = _join(r, 221, PALADIN)
	_settle(r)
	_taps(r, true, [] as Array[Client])
	var pr: Prayer = r.host.prayer
	check(pr.running(), "alone: the cleric starts (the paladin in the circle is company)")
	_tick_until(r, func() -> bool: return not pr.running(), Config.PRAYER_GATHER_TICKS + 10)
	_tick(r, 2 * r.delay + 4)
	var hid: int = r.s.local.player.get_instance_id()
	check(pr.last != null and pr.last.stopped and pr.last.why == Prayer.WHY_NOBODY and r.s.local.player.skills.resource == 60,
		"nobody joined: it stops at the gather's end, no faith spent")
	check(pr.is_meditating(hid), "the cleric meditates instead")
	var np: NetPrayer = c.s.client.prayer_net
	check(np.mirror.last != null and np.mirror.last.why == Prayer.WHY_NOBODY and np.meditating.has(r.s.local.slot),
		"the paladin's machine: stopped (nobody joined), the cleric meditating")
	_tick(r, Config.MEDITATE_TICKS + 2 * r.delay + 4)
	var sk: SkillState = r.s.local.player.skills
	check(sk.zeal_pct == Config.MEDITATE_ZEAL_PCT and not sk.zeal_from_prayer, "his meditation's zeal (%d%%)" % sk.zeal_pct)
	check(not _zp(np, r.s.local.slot, true) and c.s.members[r.s.local.slot].player.skills.zealous()
		and not c.s.members[r.s.local.slot].player.skills.zeal_from_prayer, "a meditation's zeal on the paladin's machine too")
	_check_agree(r, "alone")
	_free_rig(r)


## A join that reaches the host just after the gather (inside PRAYER_JOIN_LAG_TICKS of turn 0: its machine still showed the gather)
## is taken and goes last in the turn order; one that comes past it is refused (`the turns have begun`); every machine agrees.
func _check_late_join_net() -> void:
	var r: Rig = _rig(CLERIC)
	r.delay = 8
	r.s.local.player.skills.resource = 60
	await await_frames(1)
	var a: Client = _join(r, 231, PALADIN)
	var b: Client = _join(r, 232, ARCHER)
	var m: Client = _join(r, 233, MINER)
	_settle(r)
	_taps(r, true, [a] as Array[Client])
	var pr: Prayer = r.host.prayer
	_tick_until(r, func() -> bool: return pr.phase_ticks >= Config.PRAYER_GATHER_TICKS - 1 or not pr.running(),
		Config.PRAYER_GATHER_TICKS + 10)
	check(b.s.client.prayer_net.mirror.phase == Prayer.Phase.GATHER, "the archer's machine still shows the gather")
	_taps(r, false, [b] as Array[Client])
	_tick_until(r, func() -> bool: return pr.turn_ticks >= Config.PRAYER_JOIN_LAG_TICKS - r.delay + 2, 120)
	var bid: int = hm(r, b).player.get_instance_id()
	check(pr.is_member(bid) and pr.order[pr.order.size() - 1] == bid and pr.turn == 0,
		"its tap came %d ticks into turn 0 (its window: %d): it joins, last in the order" % [r.delay, Config.PRAYER_JOIN_LAG_TICKS])
	_taps(r, false, [m] as Array[Client])
	_tick(r, r.delay + 2)
	check(not pr.is_member(hm(r, m).player.get_instance_id()) and _n(r.host.prayer_refusals, Prayer.WHY_CLOSED) == 1,
		"the miner's, past it: the turns have begun")
	_run_prayer(r, {0: "c", 1: "c", 2: "c"})
	check(pr.last != null and pr.last.participants == 3 and hm(r, b).player.skills.zealous(), "three to the end, the archer's zeal")
	_check_agree(r, "late join")
	_free_rig(r)


## A hello of version 11 (an M9 build) is refused with `version`.
func _check_v11_refused() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	r.host.on_hello(171, NetProtocol.encode_hello(NetProtocol.class_index(MINER), 11))
	var to_peer: Array[Array] = r.s.take_for(171)
	var refusal: PackedByteArray = PackedByteArray()
	if to_peer.size() == 1:
		refusal = to_peer[0][2]
	check(to_peer.size() == 1 and str(to_peer[0][1]) == "refused" and NetProtocol.decode_refusal(refusal) == "version"
		and member_of_peer(r, 171) == null and not r.host.streams.has(171), "a version 11 hello: one refusal (version), no member")
	_free_rig(r)
