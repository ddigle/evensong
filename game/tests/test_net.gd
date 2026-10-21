extends "res://tests/base_test.gd"
## Net pieces in one process (no other processes; tests/test_net_session.gd runs real sessions):
## wire format (round trips, every truncation, random garbage), roster (the real 9-player cap,
## slot reuse), host input gate (order, duplicates, rate limit, smoothing), client prediction
## against a simulated host over a delayed lossy link, interpolation and the host clock estimate,
## the edit log (rules, late-join rebuild = host world), the bot script, the CLI flags, the RPC
## table, and the transports (ENet host + join between two SceneMultiplayers, Steam unavailable).

const RPC_CHANNELS: Dictionary[String, int] = {
	"_rpc_hello": NetProtocol.CH_CONTROL, "_rpc_welcome": NetProtocol.CH_CONTROL,
	"_rpc_refused": NetProtocol.CH_CONTROL, "_rpc_joined": NetProtocol.CH_CONTROL,
	"_rpc_left": NetProtocol.CH_CONTROL, "_rpc_edit": NetProtocol.CH_CONTROL,
	"_rpc_keyframe": NetProtocol.CH_CONTROL, "_rpc_go": NetProtocol.CH_CONTROL,
	"_rpc_done": NetProtocol.CH_CONTROL, "_rpc_finish": NetProtocol.CH_CONTROL,
	"_rpc_input": NetProtocol.CH_INPUT, "_rpc_state": NetProtocol.CH_STATE,
}
## Only these may be called by clients; everything else only by the host (authority).
const CLIENT_CALLABLE: PackedStringArray = ["_rpc_hello", "_rpc_input", "_rpc_done"]
const UNRELIABLE: PackedStringArray = ["_rpc_input", "_rpc_state"]


func run() -> Array[String]:
	_check_frame_codes()
	_check_inputs_codec()
	_check_states_codec()
	_check_welcome_codec()
	_check_garbage()
	_check_roster()
	_check_input_gate()
	_check_state_broadcast()
	_check_prediction_basics()
	_check_prediction_over_link()
	_check_interpolation()
	await _check_edit_log()
	_check_bot()
	_check_cli()
	_check_rpc_table()
	await _check_transports()
	return failures


# --- wire format ---------------------------------------------------------------------------------

func _check_frame_codes() -> void:
	var seen: Dictionary[int, bool] = {}
	for facing: int in 4:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var code: int = NetProtocol.frame_code(Vector2i(dx, dy), facing)
				seen[code] = true
				var f: NetProtocol.InputFrame = NetProtocol.frame_from_code(code, 7)
				check(f != null and f.dir == Vector2i(dx, dy) and f.facing == facing and f.seq == 7,
					"code %d round trip" % code)
	check_eq(seen.size(), NetProtocol.CODE_COUNT, "36 distinct codes (9 directions x 4 facings)")
	check(NetProtocol.frame_from_code(36, 1) == null and NetProtocol.frame_from_code(255, 1) == null,
		"codes 36..255 are not frames")
	check_eq(NetProtocol.frame_code(Vector2i(5, -9), 2), NetProtocol.frame_code(Vector2i(1, -1), 2),
		"a longer direction is clamped to -1..1")


func _check_inputs_codec() -> void:
	var frames: Array[NetProtocol.InputFrame] = []
	for i: int in 5:
		frames.append(NetProtocol.InputFrame.new(1000 + i, Vector2i(i % 3 - 1, 1 - i % 3), i % 4))
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 5, "input packet = 5 B header + 1 B per frame")
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 5 and p.bad_frames == 0, "input packet decodes")
	for i: int in mini(p.frames.size(), 5):
		check(p.frames[i].seq == 1000 + i and p.frames[i].dir == frames[i].dir and p.frames[i].facing == frames[i].facing,
			"input frame %d round trip" % i)
	var bad: PackedByteArray = bytes.duplicate()
	bad[NetProtocol.INPUT_HEADER + 2] = 200
	p = NetProtocol.decode_inputs(bad)
	check(p.ok and p.frames.size() == 4 and p.bad_frames == 1 and p.frames[2].seq == 1003,
		"an invalid code drops that frame only (its seq stays used)")
	check(not NetProtocol.decode_inputs(bytes.slice(0, bytes.size() - 1)).ok, "short input packet")
	var zero: PackedByteArray = bytes.slice(0, NetProtocol.INPUT_HEADER)
	zero[4] = 0
	check(not NetProtocol.decode_inputs(zero).ok, "input packet with no frames")
	var big: PackedByteArray = PackedByteArray()
	big.resize(NetProtocol.INPUT_HEADER + Config.NET_MAX_FRAMES_PER_PACKET + 1)
	big[4] = Config.NET_MAX_FRAMES_PER_PACKET + 1
	check(not NetProtocol.decode_inputs(big).ok, "input packet over the frame limit")


func _check_states_codec() -> void:
	var states: Array[NetProtocol.PlayerState] = []
	for i: int in Config.MAX_PLAYERS:
		var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
		s.slot = i
		s.pos = Vector2(987.0 + i * 0.1, 804.000366 - i)  # not exactly representable in decimal
		s.facing = i % 4
		s.walking = i % 2 == 0
		s.ack = 4000000000 - i
		states.append(s)
	var bytes: PackedByteArray = NetProtocol.encode_states(123456, states)
	check_eq(bytes.size(), NetProtocol.STATE_HEADER + NetProtocol.STATE_SIZE * Config.MAX_PLAYERS,
		"9-player batch = 5 + 9 x 14 B")
	var b: NetProtocol.StateBatch = NetProtocol.decode_states(bytes)
	check(b.ok and b.tick == 123456 and b.states.size() == Config.MAX_PLAYERS, "state batch decodes")
	var exact: bool = true
	for i: int in mini(b.states.size(), states.size()):
		exact = exact and b.states[i].same_as(states[i])
	check(exact, "every state round trips exactly (float32 positions bit for bit)")
	var bad_slot: PackedByteArray = bytes.duplicate()
	bad_slot[NetProtocol.STATE_HEADER] = Config.MAX_PLAYERS
	check(not NetProtocol.decode_states(bad_slot).ok, "slot >= 9 is rejected")
	var bad_flags: PackedByteArray = bytes.duplicate()
	bad_flags[NetProtocol.STATE_HEADER + 9] = 0x80
	check(not NetProtocol.decode_states(bad_flags).ok, "unknown flag bits are rejected")
	var nan: PackedByteArray = bytes.duplicate()
	nan.encode_float(NetProtocol.STATE_HEADER + 1, NAN)
	check(not NetProtocol.decode_states(nan).ok, "a NaN position is rejected")
	check(NetProtocol.decode_states(NetProtocol.encode_states(9, [] as Array[NetProtocol.PlayerState])).ok,
		"an empty batch is valid")
	var info: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
	info.class_index = 4
	info.state = states[3]
	var ib: PackedByteArray = NetProtocol.encode_info(info)
	var back: NetProtocol.PlayerInfo = NetProtocol.decode_info(ib)
	check(ib.size() == NetProtocol.INFO_SIZE and back != null and back.class_index == 4 and back.state.same_as(states[3]),
		"player info round trip")
	ib[0] = Config.CLASSES.size()
	check(NetProtocol.decode_info(ib) == null, "unknown class index is rejected")
	var h: NetProtocol.Hello = NetProtocol.decode_hello(NetProtocol.encode_hello(2))
	check(h.ok and h.version == NetProtocol.VERSION and h.class_index == 2, "hello round trip")
	check(not NetProtocol.decode_hello(PackedByteArray([1, 0])).ok, "short hello")
	for r: int in NetProtocol.REFUSAL_NAMES.size():
		check_eq(NetProtocol.decode_refusal(NetProtocol.encode_refusal(r as NetProtocol.Refusal)),
			NetProtocol.REFUSAL_NAMES[r], "refusal %d" % r)
	check_eq(NetProtocol.decode_refusal(PackedByteArray([99])), "bad_refusal", "unknown refusal")


func _welcome_sample() -> NetProtocol.Welcome:
	var w: NetProtocol.Welcome = NetProtocol.Welcome.new()
	w.slot = 3
	w.max_players = 4
	w.world_seed = -9007199254740993
	w.map_size = Config.MAP_SIZE
	w.world_md5 = "00112233445566778899aabbccddeeff".hex_decode()
	w.tick = 77
	w.bots_started = true
	w.edits.append(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, Vector2i(62, 50), Terrain.SOIL))
	w.edits.append(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, Vector2i(127, 95), Terrain.GRASS))
	for slot: int in [0, 3]:
		var info: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
		info.class_index = slot % 5
		info.state.slot = slot
		info.state.pos = Vector2(100.25 * slot, 7.5)
		w.players.append(info)
	return w


func _check_welcome_codec() -> void:
	var w: NetProtocol.Welcome = _welcome_sample()
	var bytes: PackedByteArray = NetProtocol.encode_welcome(w)
	var back: NetProtocol.Welcome = NetProtocol.decode_welcome(bytes)
	check(back.ok, "welcome decodes")
	check(back.slot == 3 and back.max_players == 4 and back.world_seed == w.world_seed and back.map_size == w.map_size
		and back.tick == 77 and back.bots_started, "welcome fields")
	check_eq(back.world_md5.hex_encode(), "00112233445566778899aabbccddeeff", "welcome world md5")
	check_eq(back.edits.size(), 2, "welcome edit log")
	if back.edits.size() == 2:
		check(back.edits.edits[1].cell == Vector2i(127, 95) and back.edits.edits[1].value == Terrain.GRASS, "welcome edit 2")
	check(back.players.size() == 2 and back.players[1].state.same_as(w.players[1].state), "welcome players")
	var all_short_fail: bool = true
	for n: int in bytes.size():
		if NetProtocol.decode_welcome(bytes.slice(0, n)).ok:
			all_short_fail = false
	check(all_short_fail, "every truncation of a welcome is rejected (%d lengths)" % bytes.size())
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	check(not NetProtocol.decode_welcome(longer).ok, "a welcome with trailing bytes is rejected")


## Random bytes into every decoder: never an engine error (the runner would fail the file), almost
## never accepted.
func _check_garbage() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261022
	var accepted: int = 0
	for i: int in 2000:
		var n: int = rng.randi_range(0, 80)
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(n)
		for j: int in n:
			bytes[j] = rng.randi_range(0, 255)
		if NetProtocol.decode_inputs(bytes).ok:
			accepted += 1
		NetProtocol.decode_states(bytes)
		NetProtocol.decode_welcome(bytes)
		NetProtocol.decode_info(bytes)
		NetProtocol.decode_hello(bytes)
		NetProtocol.decode_refusal(bytes)
		EditLog.decode(bytes)
		EditLog.decode_one(bytes)
	check(accepted < 20, "random bytes almost never pass as input packets (%d of 2000)" % accepted)


# --- host side -----------------------------------------------------------------------------------

func _check_roster() -> void:
	check_eq(Config.MAX_PLAYERS, 9, "● 9 players")
	check(Config.SPAWN_SLOTS.size() >= Config.MAX_PLAYERS, "a spawn slot for every player")
	var r: Roster = Roster.new()
	check_eq(r.max_players, 9, "default cap = Config.MAX_PLAYERS")
	check_eq(r.admit(1, "paladin"), 0, "host gets slot 0")
	for i: int in 8:
		check_eq(r.admit(100 + i, Config.CLASSES[i % Config.CLASSES.size()]), i + 1, "client %d gets slot %d" % [i, i + 1])
	check(r.is_full() and r.count() == 9, "nine players = full")
	check_eq(r.refusal_for("miner"), NetProtocol.Refusal.FULL, "a tenth player is refused as full")
	check_eq(r.admit(200, "miner"), -1, "a tenth player gets no slot")
	check_eq(r.count(), 9, "still nine")
	check_eq(r.release(103), 4, "leaving frees slot 4")
	check_eq(r.release(103), -1, "leaving twice frees nothing")
	check_eq(r.admit(201, "archer"), 4, "the next joiner reuses slot 4 (lowest free)")
	check_eq(r.peer_at(4), 201, "slot 4 -> new peer")
	check_eq(r.admit(201, "archer"), -1, "a peer cannot join twice")
	r.release(100)
	r.release(105)
	check_eq(r.admit(202, "cleric"), 1, "lowest free slot first (1 before 6)")
	check_eq(r.admit(203, "cleric"), 6, "then 6")
	var slots: Array[int] = []
	for peer: int in r.peers():
		slots.append(r.slot_of(peer))
	check_eq(slots, [0, 1, 2, 3, 4, 5, 6, 7, 8] as Array[int], "peers() by slot, all slots used once")
	check_eq(Roster.new(20).max_players, 9, "a cap above 9 is clamped to 9")
	check_eq(Roster.new(0).max_players, 1, "a cap below 1 is clamped to 1")
	var small: Roster = Roster.new(2)
	small.admit(1, "paladin")
	check_eq(small.refusal_for("wizard"), NetProtocol.Refusal.CLASS, "an unknown class is refused (wizard is not a slice class)")
	check_eq(small.admit(2, "paladin"), 1 if not Config.NET_UNIQUE_CLASSES else -1,
		"same class twice follows NET_UNIQUE_CLASSES (%s)" % Config.NET_UNIQUE_CLASSES)
	check_eq(small.refusal_for("miner"), NetProtocol.Refusal.FULL if not Config.NET_UNIQUE_CLASSES else NetProtocol.Refusal.NONE,
		"a small test cap refuses like the real one")


func _packet(first: int, dirs: Array[Vector2i]) -> NetProtocol.InputPacket:
	var frames: Array[NetProtocol.InputFrame] = []
	for i: int in dirs.size():
		frames.append(NetProtocol.InputFrame.new(first + i, dirs[i], RigData.Dir.EAST))
	return NetProtocol.decode_inputs(NetProtocol.encode_inputs(frames))


func _check_input_gate() -> void:
	var g: InputGate = InputGate.new()
	var right: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 0)]
	g.receive(_packet(1, right))
	g.receive(_packet(1, right))  # the same frames again (the client repeats unacknowledged ones)
	check_eq(g.duplicates, 2, "repeated frames are ignored")
	check_eq(g.take().size(), 1, "one frame per tick while the queue is short (smooth)")
	check_eq(g.take().size(), 1, "and the next")
	check_eq(g.take().size(), 0, "nothing left")
	check_eq(g.last_seq, 2, "ack = last handled frame")
	# Falling behind: more than NET_INPUT_JITTER_FRAMES waiting -> catch up in one tick.
	var many: Array[Vector2i] = []
	for i: int in 10:
		many.append(Vector2i(0, 1))
	g.receive(_packet(3, many))
	check_eq(g.take().size(), 10 - Config.NET_INPUT_JITTER_FRAMES, "catches up down to the jitter buffer")
	# Rate limit: a client sending far more frames than ticks.
	var r: InputGate = InputGate.new()
	var applied: int = 0
	var seq: int = 1
	for t: int in 120:
		var burst: Array[Vector2i] = []
		for i: int in 8:
			burst.append(Vector2i(1, 1))
		r.receive(_packet(seq, burst))
		seq += 8
		applied += r.take().size()
	check(applied <= 120 + Config.NET_INPUT_BURST, "rate limit: %d frames in 120 ticks (<= ticks + burst %d)" % [
		applied, 120 + Config.NET_INPUT_BURST])
	check(r.rate_limited_ticks > 0 and r.overflow > 0, "rate limiting and the queue bound kicked in (%d, %d)" % [
		r.rate_limited_ticks, r.overflow])
	# Gaps, bad packets, unknown codes.
	var q: InputGate = InputGate.new()
	q.receive(_packet(5, [Vector2i(1, 0)] as Array[Vector2i]))
	q.take()
	check_eq(q.gaps, 1, "a gap in seq is counted (frames 1..4 never came)")
	q.receive(NetProtocol.decode_inputs(PackedByteArray([1, 2])))
	check_eq(q.bad_packets, 1, "a malformed packet is counted and dropped")
	check_eq(q.last_seq, 5, "a malformed packet changes nothing")


## Batch while something changes, one reliable keyframe after, then nothing.
func _check_state_broadcast() -> void:
	var b: StateBroadcast = StateBroadcast.new()
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	var states: Array[NetProtocol.PlayerState] = [s]
	var sends: Array[int] = []
	for t: int in range(3, 60, 3):
		if t <= 15:
			s.pos.x += 1.2 * 3  # walking until tick 15
			s.walking = true
			b.note_activity(t)
		else:
			s.walking = false
		sends.append(b.decide(t, states))
	var want: Array[int] = [1, 1, 1, 1, 1, 1, 2]
	for i: int in range(7, sends.size()):
		want.append(0)
	check_eq(sends, want, "batches while moving + the stop, one keyframe, then quiet")
	check(b.batches == 6 and b.keyframes == 1 and b.quiet_violations == 0 and not b.dirty, "broadcast counters")
	check_eq(NetProtocol.decode_states(b.payload).states[0].pos, s.pos, "keyframe carries the last state")
	s.facing = RigData.Dir.NORTH  # a change long after anyone moved: sent, and counted
	check_eq(b.decide(99, states), StateBroadcast.Send.BATCH, "any change is sent")
	check_eq(b.quiet_violations, 1, "a change without activity is a quiet violation")


# --- client side ---------------------------------------------------------------------------------

func _check_prediction_basics() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0])
	var p: Prediction = Prediction.new()
	p.setup(data, start, RigData.Dir.SOUTH, 0)
	check(p.step(Vector2i.ZERO) == null, "standing still records nothing")
	var f: NetProtocol.InputFrame = p.step(Vector2i(1, 0))
	check(f != null and f.seq == 1 and f.facing == RigData.Dir.EAST, "a move records frame 1, facing east")
	check_eq(p.pos, Movement.step(data, start, Vector2i(1, 0), Config.NET_TICK), "moves at once (no round trip)")
	p.step(Vector2i(1, 0))
	var stop: NetProtocol.InputFrame = p.step(Vector2i.ZERO)
	check(stop != null and stop.dir == Vector2i.ZERO and stop.seq == 3, "the first idle tick records the stop")
	check(p.step(Vector2i.ZERO) == null, "later idle ticks record nothing")
	check_eq(p.frames_to_send().size(), 3, "three unacknowledged frames to send")
	# The host handled frame 1 exactly like the client: no error, frames 2-3 replayed.
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.pos = Movement.step(data, start, Vector2i(1, 0), Config.NET_TICK)
	s.facing = RigData.Dir.EAST
	s.ack = 1
	var before: Vector2 = p.pos
	check_eq(p.reconcile(s), 0.0, "agreeing host: error 0")
	check_eq(p.pos, before, "replay lands where the prediction was")
	check_eq(p.pending.size(), 2, "acknowledged frame dropped")
	# A host that disagrees (put the player 5 px south): the host wins, the error is measured.
	s.ack = 3
	s.pos = before + Vector2(0, 5)
	check_between(p.reconcile(s), 4.999, 5.001, "a disagreeing host shows as a 5 px error")
	check_eq(p.pos, before + Vector2(0, 5), "the client takes the host's position")
	check_eq(p.corrections, 1, "one correction")
	s.ack = 2
	check_eq(p.reconcile(s), -1.0, "an older state is ignored")


## Client and host in one loop, linked by queues with a delay and seeded loss both ways (the same
## shape as the session: frames repeated until acked, states every 3rd tick). The client's
## prediction must never disagree with the host.
func _check_prediction_over_link() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1])
	for link_case: Array in [[0, 0.0], [5, 0.0], [9, 0.25]]:
		var delay: int = link_case[0]
		var loss: float = link_case[1]
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7 + delay
		var client: Prediction = Prediction.new()
		client.setup(data, start, RigData.Dir.SOUTH, 0)
		var gate: InputGate = InputGate.new()
		var host_pos: Vector2 = start
		var host_facing: int = RigData.Dir.SOUTH
		var to_host: Array[Array] = []    # [due tick, bytes]
		var to_client: Array[Array] = []
		var script: Array[Vector2i] = []
		for i: int in 400:
			# Walks into the altar footprint and along the map: collisions and slides included.
			script.append([Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, -1), Vector2i.ZERO][(i / 37) % 5])
		for t: int in 600:
			var dir: Vector2i = script[t] if t < script.size() else Vector2i.ZERO
			var frame: NetProtocol.InputFrame = client.step(dir)
			if client.has_unacked() and (t % 2 == 0 or (frame != null and client.pending.size() == 1)):
				if rng.randf() >= loss:
					to_host.append([t + delay, NetProtocol.encode_inputs(client.frames_to_send())])
			while not to_host.is_empty() and _due(to_host) <= t:
				var item: Array = to_host.pop_front()
				var bytes: PackedByteArray = item[1]
				gate.receive(NetProtocol.decode_inputs(bytes))
			for f: NetProtocol.InputFrame in gate.take():
				host_pos = Movement.step(data, host_pos, f.dir, Config.NET_TICK)
				host_facing = f.facing
			if t % 3 == 0:
				var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
				s.pos = host_pos
				s.facing = host_facing
				s.ack = gate.last_seq
				var batch: PackedByteArray = NetProtocol.encode_states(t, [s] as Array[NetProtocol.PlayerState])
				if rng.randf() >= loss:
					to_client.append([t + delay, batch])
			while not to_client.is_empty() and _due(to_client) <= t:
				var item: Array = to_client.pop_front()
				var bytes: PackedByteArray = item[1]
				client.reconcile(NetProtocol.decode_states(bytes).states[0])
		var label: String = "delay %d ticks, loss %d%%" % [delay, roundi(loss * 100.0)]
		check_eq(client.max_error_px, 0.0, "prediction never disagrees with the host (%s)" % label)
		check_eq(client.pos, host_pos, "client and host end on the same float32 position (%s)" % label)
		check(not client.has_unacked() and gate.gaps == 0, "every frame reached the host (%s)" % label)
		check(client.reconciles > 50 and client.frames > 300, "the case really ran (%d reconciles)" % client.reconciles)
		note("prediction over a %s link: %d frames, %d reconciles, max error %.3f px, %d duplicate frames at the host" % [
			label, client.frames, client.reconciles, client.max_error_px, gate.duplicates])


static func _due(queue: Array[Array]) -> int:
	var due: int = queue[0][0]
	return due


func _check_interpolation() -> void:
	var it: Interpolation = Interpolation.new()
	check(it.sample(5.0) == null, "nothing before the first state")
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.pos = Vector2(100, 100)
	s.facing = RigData.Dir.EAST
	it.push(30, s)
	check_eq(it.sample(10.0).pos, Vector2(100, 100), "before the first state: hold it")
	s.pos = Vector2(130, 100)
	s.walking = true
	it.push(33, s)
	check_eq(it.sample(31.5).pos, Vector2(115, 100), "halfway between two states")
	check(not it.sample(31.5).walking, "facing / walking from the older state")
	check_eq(it.sample(99.0).pos, Vector2(130, 100), "after the last state: hold it (no guessing ahead)")
	# After a quiet spell the old state is repeated one interval before the new one.
	var q: Interpolation = Interpolation.new()
	s.pos = Vector2(0, 0)
	q.push(100, s)
	s.pos = Vector2(10, 0)
	q.push(400, s)
	check_eq(q.sample(300.0).pos, Vector2(0, 0), "still standing during the quiet spell")
	check_eq(q.sample(398.5).pos, Vector2(5, 0), "moves only in the last interval")
	s.pos = Vector2(99, 0)
	q.push(350, s)
	check_eq(q.latest().pos, Vector2(10, 0), "an older state does not overwrite a newer one")
	# Host clock estimate: the least delayed batch wins, and the estimate creeps down slowly.
	var c: Interpolation.RemoteClock = Interpolation.RemoteClock.new()
	c.observe(1000, 10.0)   # delayed 0 -> offset 990
	c.observe(1003, 14.0)   # delayed 1 tick -> 989, keep 990 (minus decay)
	check_between(c.host_tick_at(14.0), 1003.9, 1004.0, "clock keeps the least delayed estimate")
	c.observe(1100, 100.0)
	check_between(c.host_tick_at(100.0), 1089.0, 1100.0, "and follows a later one")


# --- world edits ---------------------------------------------------------------------------------

func _check_edit_log() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var center: Vector2i = data.altar_rect.get_center()
	var grass_cell: Vector2i = center + Vector2i(0, 5)
	if data.terrain_at(grass_cell) != Terrain.GRASS:
		grass_cell = center + Vector2i(5, 0)
	var ash_cell: Vector2i = Vector2i(-1, -1)
	for i: int in data.size.x * data.size.y:
		if data.layers[WorldData.Layer.FLOOR][i] == Terrain.ASH:
			ash_cell = Vector2i(i % data.size.x, i / data.size.x)
			break
	var till: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.FLOOR, grass_cell, Terrain.SOIL)
	check_eq(EditLog.check(data, till), "", "tilling grass by the altar is allowed")
	check_ne(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.FLOOR, Vector2i(-1, 3), Terrain.SOIL)), "",
		"outside the map is refused")
	check_ne(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.FLOOR, grass_cell, Terrain.ASH)), "",
		"writing ash is refused (fixed zones)")
	check_ne(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.FLOOR, ash_cell, Terrain.GRASS)), "",
		"clearing ash is refused (purifying is not M1)")
	check_ne(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.FLOOR, grass_cell, Terrain.GRASS)), "",
		"no change is refused")
	check_ne(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.WALL, grass_cell, 1)), "",
		"non-floor edits do not exist in M1")
	var beside_ash: Vector2i = Vector2i(-1, -1)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var c: Vector2i = ash_cell + Vector2i(dx, dy)
			if data.in_bounds(c) and data.terrain_at(c) == Terrain.GRASS:
				beside_ash = c
	if check(beside_ash.x >= 0, "a grass cell beside ash"):
		check_ne(EditLog.check(data, EditLog.WorldEdit.new(WorldData.Layer.FLOOR, beside_ash, Terrain.SOIL)), "",
			"soil next to ash is refused (no art for it)")
	# Host world with edits, a late joiner rebuilds it from seed + log.
	var host: GameWorld = _new_world()
	var joiner: GameWorld = _new_world()
	await await_frames(1)
	var log: EditLog = EditLog.new()
	var cells: Array[Vector2i] = [grass_cell, grass_cell + Vector2i(1, 0), grass_cell + Vector2i(1, 0)]
	var values: Array[int] = [Terrain.SOIL, Terrain.SOIL, Terrain.GRASS]
	for i: int in cells.size():
		var e: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.FLOOR, cells[i], values[i])
		if check_eq(EditLog.check(host.data, e), "", "host edit %d allowed" % i):
			host.apply_edit(e)
			log.append(e)
	var pristine: String = joiner.data.content_hash()
	var wire: EditLog = EditLog.decode(log.encode())
	check(wire != null and wire.size() == 3, "edit log round trip")
	if wire != null:
		for e: EditLog.WorldEdit in wire.edits:
			joiner.apply_edit(e)
		for e: EditLog.WorldEdit in wire.edits:
			joiner.apply_edit(e)  # twice: absolute edits change nothing the second time
	check_eq(joiner.data.content_hash(), host.data.content_hash(), "seed + edit log = the host's world")
	check_ne(joiner.data.content_hash(), pristine, "the edits are in it")
	var v: Dictionary[String, int] = joiner.ground.verify()
	check(v["mismatches"] == 0 and v["missing"] == 0 and v["fallbacks"] == 0, "joiner's ground drawn from the edited data %s" % v)
	check_eq(joiner.ground.view_hash(), host.ground.view_hash(), "same picture on both")
	var one: Array = EditLog.decode_one(EditLog.encode_one(log.edits[1], 1))
	var index: int = one[0]
	var edit: EditLog.WorldEdit = one[1]
	check(index == 1 and edit.cell == cells[1] and edit.value == Terrain.SOIL, "single edit message round trip")
	var short: Array = EditLog.decode_one(PackedByteArray([1, 2, 3]))
	var short_index: int = short[0]
	check_eq(short_index, -1, "malformed edit message")
	check(not joiner.apply_edit(EditLog.WorldEdit.new(9, grass_cell, 1)), "an edit on an unknown layer is not applied")


func _new_world() -> GameWorld:
	var packed: PackedScene = load("res://scenes/world.tscn") as PackedScene
	var w: GameWorld = packed.instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	return w


# --- bot, CLI, RPC table -------------------------------------------------------------------------

func _check_bot() -> void:
	var b: NetBot = NetBot.new()
	check_eq(b.parse("move:1,0,3;wait:2;edit:62,50,soil;mark:edited;move:-1,1,1;leave"), "", "bot script parses")
	check_eq(b.duration_ticks(), 6, "script duration")
	var dirs: Array[Vector2i] = []
	var edits: int = 0
	var marks: PackedStringArray = []
	var leaves: int = 0
	for i: int in 20:
		var a: NetBot.Action = b.step()
		dirs.append(a.dir)
		if a.edit != null:
			edits += 1
			check(a.edit.cell == Vector2i(62, 50) and a.edit.terrain == Terrain.SOIL, "edit command")
		if not a.mark.is_empty():
			marks.append(a.mark)
		if a.leave:
			leaves += 1
	check_eq(dirs.slice(0, 9), [Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i.ZERO, Vector2i.ZERO,
		Vector2i.ZERO, Vector2i.ZERO, Vector2i(-1, 1), Vector2i.ZERO] as Array[Vector2i], "ticks of the script")
	check(edits == 1 and marks == PackedStringArray(["edited"]) and leaves == 1 and b.finished, "one edit, mark, leave")
	for bad: String in ["move:2,0,5", "move:1,0", "wait:-1", "edit:1,2,ash", "edit:1,2", "mark:", "jump:1", "leave:1"]:
		check_ne(NetBot.new().parse(bad), "", "bad bot script '%s' is an error" % bad)


func _check_cli() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--host=24625", "--transport=steam", "--max-players=4",
		"--bot=move:1,0,10", "--net-out=C:/x", "--net-name=c1", "--net-start=2", "--net-expect=3",
		"--net-expect-refused=1", "--net-timeout=30", "--net-lag=80", "--net-loss=12.5", "--keep-running"]))
	check_eq(o.errors.size(), 0, "session flags parse (%s)" % str(o.errors))
	check(o.host and o.port == 24625 and o.transport == "steam" and o.max_players == 4 and o.bot == "move:1,0,10",
		"session flags values")
	check(o.net_out == "C:/x" and o.net_name == "c1" and o.net_start == 2 and o.net_expect == 3
		and o.net_expect_refused == 1 and o.net_timeout == 30.0 and o.net_lag == 80 and o.net_loss == 12.5
		and o.keep_running,
		"session test flag values")
	var defaults: CliOptions = CliOptions.parse(PackedStringArray([]))
	check(defaults.transport == "enet" and defaults.max_players == 9 and defaults.net_expect == -1
		and defaults.net_start == 0, "session defaults")
	for argv: PackedStringArray in [PackedStringArray(["--transport=tcp"]), PackedStringArray(["--max-players=10"]),
			PackedStringArray(["--max-players=0"]), PackedStringArray(["--bot=fly:1"]), PackedStringArray(["--bot="]),
			PackedStringArray(["--net-name=a/b"]), PackedStringArray(["--net-expect=x"]),
			PackedStringArray(["--net-timeout=0"]), PackedStringArray(["--net-loss=101"]), PackedStringArray(["--net-lag=-5"])]:
		check_eq(CliOptions.parse(argv).errors.size(), 1, "%s is one error" % " ".join(argv))


## Which RPCs clients may call (only hello, input, done), channel and reliability of each.
func _check_rpc_table() -> void:
	var script: GDScript = load("res://net/session.gd") as GDScript
	var config: Variant = script.get_rpc_config()
	if not check(config is Dictionary, "session has an RPC table"):
		return
	var table: Dictionary = config
	check_eq(table.size(), RPC_CHANNELS.size(), "number of RPCs")
	for method: String in RPC_CHANNELS:
		if not check(table.has(method), "RPC %s exists" % method):
			continue
		var c: Dictionary = table[method]
		var mode: int = c.get("rpc_mode", -1)
		var transfer: int = c.get("transfer_mode", -1)
		var channel: int = c.get("channel", -1)
		var call_local: bool = c.get("call_local", true)
		check_eq(mode, MultiplayerAPI.RPC_MODE_ANY_PEER if CLIENT_CALLABLE.has(method) else MultiplayerAPI.RPC_MODE_AUTHORITY,
			"%s: who may call it" % method)
		check_eq(transfer, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if UNRELIABLE.has(method)
			else MultiplayerPeer.TRANSFER_MODE_RELIABLE, "%s: reliability" % method)
		check_eq(channel, RPC_CHANNELS[method], "%s: channel" % method)
		check(not call_local, "%s: not called locally" % method)


# --- transports ----------------------------------------------------------------------------------

func _check_transports() -> void:
	check(Transports.make("tcp") == null, "unknown transport -> null")
	var enet: NetTransport = Transports.make("enet")
	check(enet is EnetTransport and enet.is_available(), "ENet transport available")
	# Steam placeholder: reports unavailable by signal, later, never inside the call.
	var steam: NetTransport = Transports.make("steam")
	check(steam is SteamTransport, "Steam transport exists")
	check_eq(steam.is_available(), ClassDB.class_exists(&"SteamMultiplayerPeer") and Engine.has_singleton("Steam"),
		"Steam availability follows GodotSteam")
	var reasons: PackedStringArray = []
	steam.open_failed.connect(func(r: String) -> void: reasons.append(r))
	var api0: SceneMultiplayer = SceneMultiplayer.new()
	steam.host(api0)
	check(reasons.is_empty(), "the result is not emitted inside host()")
	await await_frames(1)
	check(reasons.size() == 1 and reasons[0].begins_with("unavailable"), "Steam host -> open_failed unavailable (%s)" % str(reasons))
	steam.join(api0)
	await await_frames(2)
	check_eq(reasons.size(), 2, "each call reports once")

	# ENet host + join between two SceneMultiplayers in this process.
	allow_error("Couldn't create an ENet host", -1)  # free_port() probing a port in use
	var port: int = free_port(Config.NET_TEST_PORT_LAST, Config.NET_TEST_PORT_FIRST)
	if not check(port > 0, "a free test port"):
		return
	var host_api: SceneMultiplayer = SceneMultiplayer.new()
	var client_api: SceneMultiplayer = SceneMultiplayer.new()
	var host_t: NetTransport = Transports.make("enet")
	var client_t: NetTransport = Transports.make("enet")
	var events: PackedStringArray = []
	host_t.opened.connect(func() -> void: events.append("host opened"))
	host_t.open_failed.connect(func(r: String) -> void: events.append("host failed " + r))
	client_t.opened.connect(func() -> void: events.append("client opened"))
	client_t.open_failed.connect(func(r: String) -> void: events.append("client failed " + r))
	var ho: NetTransport.Options = NetTransport.Options.new()
	ho.port = port
	host_t.configure(ho)
	var co: NetTransport.Options = NetTransport.Options.new()
	co.address = "127.0.0.1"
	co.port = port
	client_t.configure(co)
	host_t.host(host_api)
	client_t.join(client_api)
	var t0: int = Time.get_ticks_msec()
	while events.size() < 2 and Time.get_ticks_msec() - t0 < 5000:
		host_api.poll()
		client_api.poll()
		await await_frames(1)
	check(events.has("host opened") and events.has("client opened"), "ENet host and join report opened (%s)" % str(events))
	check_eq(client_api.get_peers(), PackedInt32Array([1]), "client sees the host as peer 1")
	note("ENet localhost join: %d ms" % (Time.get_ticks_msec() - t0))
	var s: NetTransport.Stats = host_t.pop_stats()
	check(s.sent_bytes > 0 and s.sent_packets > 0 and s.received_bytes > 0, "ENet reports traffic")
	# A second host on the same port fails by signal (ENet logs an engine error for it too).
	# (announced above with count -1: the probe allowance also covers this one)
	var busy: NetTransport = Transports.make("enet")
	var busy_reasons: PackedStringArray = []
	busy.open_failed.connect(func(r: String) -> void: busy_reasons.append(r))
	busy.configure(ho)
	busy.host(SceneMultiplayer.new())
	await await_frames(1)
	check(busy_reasons.size() == 1 and busy_reasons[0].contains("%d" % port), "busy port -> open_failed (%s)" % str(busy_reasons))
	client_t.close()
	host_t.close()
	host_t.close()
	check(host_t.get_peer() == null and host_api.multiplayer_peer is OfflineMultiplayerPeer, "close() leaves an offline peer")
	var empty: NetTransport = Transports.make("enet")
	var empty_reasons: PackedStringArray = []
	empty.open_failed.connect(func(r: String) -> void: empty_reasons.append(r))
	empty.join(SceneMultiplayer.new())
	await await_frames(1)
	check_eq(empty_reasons.size(), 1, "join without an address fails by signal")


## A port in first..last (either order) nobody listens on, or -1.
static func free_port(first: int, last: int) -> int:
	var step: int = 1 if last >= first else -1
	var port: int = first
	while port != last + step:
		var probe: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
		var err: Error = probe.create_server(port, 1)
		probe.close()
		if err == OK:
			return port
		port += step
	return -1
