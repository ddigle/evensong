extends "res://tests/base_test.gd"
## Net pieces in one process (no other processes; tests/test_net_session.gd runs real sessions):
## wire format (round trips, every truncation, random garbage), roster (the real 9-player cap,
## slot reuse), host input gate (order, duplicates, rate limit, smoothing, a host hitch), the host
## deriving each client's facing, client prediction against a simulated host over a delayed lossy
## link, interpolation and the host clock estimate, the world snapshot (every layer, chunks, the
## joiner's checks) and its size and join time for 128x96 and synthetic 512x512 worlds, the edit
## log after a snapshot, the bot script, the CLI flags, the RPC table, and the transports (ENet host
## + join between two SceneMultiplayers, Steam unavailable).

const Runner := preload("res://tests/run_all.gd")

const RPC_CHANNELS: Dictionary[String, int] = {
	"_rpc_hello": NetProtocol.CH_CONTROL, "_rpc_world": NetProtocol.CH_CONTROL, "_rpc_welcome": NetProtocol.CH_CONTROL,
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
	_check_input_gate_hitch()
	_check_host_facing()
	_check_state_broadcast()
	_check_prediction_basics()
	_check_prediction_over_link()
	_check_interpolation()
	_check_snapshot()
	await _check_edit_log()
	await _check_snapshot_join()
	_check_bot()
	_check_cli()
	_check_rpc_table()
	await _check_transports()
	return failures


# --- wire format ---------------------------------------------------------------------------------

func _check_frame_codes() -> void:
	var seen: Dictionary[int, bool] = {}
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var code: int = NetProtocol.frame_code(Vector2i(dx, dy))
			seen[code] = true
			var f: NetProtocol.InputFrame = NetProtocol.frame_from_code(code, 7)
			check(f != null and f.dir == Vector2i(dx, dy) and f.seq == 7, "code %d round trip" % code)
	check_eq(seen.size(), NetProtocol.CODE_COUNT, "9 distinct codes (8 ways + none)")
	check_eq(NetProtocol.CODE_COUNT, 9, "a frame code is the direction only: no facing on the wire")
	check(not ("facing" in NetProtocol.InputFrame.new()), "input frames carry no facing (the host derives it)")
	var accepted: int = 0
	for code: int in range(NetProtocol.CODE_COUNT, 256):
		if NetProtocol.frame_from_code(code, 1) != null:
			accepted += 1
	check_eq(accepted, 0, "codes 9..255 are not frames (also the old facing codes)")
	check_eq(NetProtocol.frame_code(Vector2i(5, -9)), NetProtocol.frame_code(Vector2i(1, -1)),
		"a longer direction is clamped to -1..1")


func _check_inputs_codec() -> void:
	var frames: Array[NetProtocol.InputFrame] = []
	for i: int in 5:
		frames.append(NetProtocol.InputFrame.new(1000 + i, Vector2i(i % 3 - 1, 1 - i % 3)))
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 5, "input packet = 5 B header + 1 B per frame")
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 5 and p.bad_frames == 0, "input packet decodes")
	for i: int in mini(p.frames.size(), 5):
		check(p.frames[i].seq == 1000 + i and p.frames[i].dir == frames[i].dir, "input frame %d round trip" % i)
	var bad: PackedByteArray = bytes.duplicate()
	bad[NetProtocol.INPUT_HEADER + 2] = 200
	bad[NetProtocol.INPUT_HEADER + 3] = 9 + 4  # what "east, facing east" used to be
	p = NetProtocol.decode_inputs(bad)
	check(p.ok and p.frames.size() == 3 and p.bad_frames == 2 and p.frames[2].seq == 1004,
		"invalid codes drop those frames only (their seq stays used)")
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
	w.tick = 77
	w.bots_started = true
	w.edit_position = 2
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(SurfaceGen.generate(Config.DEFAULT_SEED))
	w.raw_size = packed.raw_size
	w.packed_size = packed.bytes.size()
	w.chunk_count = packed.chunk_count()
	w.packed_md5 = packed.packed_md5
	w.world_md5 = packed.world_md5
	w.world_seed = -9007199254740993
	w.generator_md5 = "00112233445566778899aabbccddeeff".hex_decode()
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
	check_eq(bytes.size(), NetProtocol.WELCOME_FIXED + 1 + 2 * NetProtocol.INFO_SIZE, "welcome = 81 B + players")
	var back: NetProtocol.Welcome = NetProtocol.decode_welcome(bytes)
	check(back.ok, "welcome decodes")
	check(back.slot == 3 and back.max_players == 4 and back.tick == 77 and back.bots_started and back.edit_position == 2,
		"welcome fields")
	check(back.raw_size == w.raw_size and back.packed_size == w.packed_size and back.chunk_count == w.chunk_count
		and back.packed_md5 == w.packed_md5 and back.world_md5 == w.world_md5, "welcome snapshot fields")
	check(back.world_seed == w.world_seed and back.generator_md5.hex_encode() == "00112233445566778899aabbccddeeff",
		"welcome diagnostic fields (seed, generator md5)")
	check(back.players.size() == 2 and back.players[1].state.same_as(w.players[1].state), "welcome players")
	var all_short_fail: bool = true
	for n: int in bytes.size():
		if NetProtocol.decode_welcome(bytes.slice(0, n)).ok:
			all_short_fail = false
	check(all_short_fail, "every truncation of a welcome is rejected (%d lengths)" % bytes.size())
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	check(not NetProtocol.decode_welcome(longer).ok, "a welcome with trailing bytes is rejected")
	var chunks: int = w.chunk_count
	w.chunk_count = 0
	check(not NetProtocol.decode_welcome(NetProtocol.encode_welcome(w)).ok, "no chunks")
	w.chunk_count = w.packed_size + 1
	check(not NetProtocol.decode_welcome(NetProtocol.encode_welcome(w)).ok, "more chunks than packed bytes")
	w.chunk_count = chunks
	w.packed_size = 0
	check(not NetProtocol.decode_welcome(NetProtocol.encode_welcome(w)).ok, "an empty snapshot")


## Random bytes into every decoder: never an engine error (the runner would fail the file), almost
## never accepted.
func _check_garbage() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261022
	var accepted: int = 0
	var worlds: int = 0
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
		EditLog.decode_one(bytes)
		if WorldSnapshot.decode_raw(bytes) != null:
			worlds += 1
		if WorldSnapshot.unpack(bytes, WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * rng.randi_range(1, 16)) != null:
			worlds += 1
		var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
		if rx.add(bytes) and rx.finish(1, n - WorldSnapshot.CHUNK_HEADER, PackedByteArray(), 100, PackedByteArray()) != null:
			worlds += 1
	check(accepted < 20, "random bytes almost never pass as input packets (%d of 2000)" % accepted)
	check_eq(worlds, 0, "random bytes never pass as a world")


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
		frames.append(NetProtocol.InputFrame.new(first + i, dirs[i]))
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
	# Real time is the limit, not the number of take() calls: catch-up ticks with no time between them
	# give no tokens, and a long gap gives at most MAX_REFILL_TICKS.
	var z: InputGate = InputGate.new()
	var zapplied: int = 0
	seq = 1
	for t: int in 60:
		var burst: Array[Vector2i] = []
		for i: int in 8:
			burst.append(Vector2i(1, 0))
		z.receive(_packet(seq, burst))
		seq += 8
		for k: int in 4:
			zapplied += z.take(0.25).size()  # four takes in one tick of real time
	check(zapplied <= 60 + Config.NET_INPUT_BURST, "takes without real time give no extra frames (%d in 60 ticks)" % zapplied)
	var idle: InputGate = InputGate.new()
	idle.tokens = 0.0
	idle.take(1000.0)
	check_eq(idle.tokens, float(Config.NET_INPUT_BURST), "a long gap with nothing waiting saves at most the burst")
	# Gaps, bad packets, unknown codes.
	var q: InputGate = InputGate.new()
	q.receive(_packet(5, [Vector2i(1, 0)] as Array[Vector2i]))
	q.take()
	check_eq(q.gaps, 1, "a gap in seq is counted (frames 1..4 never came)")
	q.receive(NetProtocol.decode_inputs(PackedByteArray([1, 2])))
	check_eq(q.bad_packets, 1, "a malformed packet is counted and dropped")
	check_eq(q.last_seq, 5, "a malformed packet changes nothing")


## Host hitch: the host misses a second of ticks (a long frame) while a client walks on, sending at
## real-time pace. Then Godot runs a few catch-up ticks at once. Tokens follow the elapsed real time
## (and frames that waited lift the saving cap), so the queue drains back to the jitter target
## instead of staying a second behind for as long as the client keeps walking.
func _check_input_gate_hitch() -> void:
	var g: InputGate = InputGate.new()
	var seq: int = 1
	var hitch_from: int = 120
	var hitch_ticks: int = 60
	var catch_up: int = 8  # Godot's default max physics steps per frame
	var waiting_peak: int = 0
	var waiting_late: int = 0
	var walk: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 0)]
	for t: int in 600:
		if t % 2 == 1:  # the client: a frame per tick of real time, sent every 2nd tick
			g.receive(_packet(seq, walk))
			seq += 2
		waiting_peak = maxi(waiting_peak, g.waiting.size())
		if t >= hitch_from and t < hitch_from + hitch_ticks:
			continue  # the host is stuck
		if t == hitch_from + hitch_ticks:
			g.take(float(hitch_ticks + 1))  # all the real time arrives with the first catch-up tick
			for i: int in catch_up - 1:
				g.take(0.0)
		else:
			g.take(1.0)
		if t > hitch_from + hitch_ticks + 30:
			waiting_late = maxi(waiting_late, g.waiting.size())
	check(waiting_peak >= hitch_ticks - 2, "the hitch really queued the client's frames (%d)" % waiting_peak)
	check(waiting_late <= Config.NET_INPUT_JITTER_FRAMES + 2,
		"after a %d-tick host hitch the queue drains back to the jitter target (at most %d waiting, target %d)" % [
		hitch_ticks, waiting_late, Config.NET_INPUT_JITTER_FRAMES])
	check(g.gaps == 0 and g.overflow == 0 and g.applied == seq - 1 - g.waiting.size(),
		"every frame applied once, in order (%d applied, %d waiting)" % [g.applied, g.waiting.size()])
	note("host hitch %d ticks + %d catch-up ticks: queue peak %d frames, afterwards at most %d" % [hitch_ticks, catch_up,
		waiting_peak, waiting_late])


## The host derives a client's facing from the directions alone (Player.apply_input, the rule the
## client's prediction uses): over diagonals, turns and stops both agree frame by frame, and a state
## whose facing differs from the prediction is counted.
func _check_host_facing() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[1])
	var client: Prediction = Prediction.new()
	client.setup(data, start, Config.SPAWN_FACING, 0)
	var host: Player = Player.new()
	host.local_input = false
	host.setup(data, "cleric", start, Config.SPAWN_FACING)
	var gate: InputGate = InputGate.new()
	var ways: Array[Vector2i] = [Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i.ZERO, Vector2i(-1, 1), Vector2i(1, -1), Vector2i(0, 1)]
	var frames: int = 0
	var disagree: int = 0
	var facings: Dictionary[int, bool] = {}
	for i: int in 240:
		var frame: NetProtocol.InputFrame = client.step(ways[(i / 7) % ways.size()])
		if frame == null:
			continue
		gate.receive(NetProtocol.decode_inputs(NetProtocol.encode_inputs([frame] as Array[NetProtocol.InputFrame])))
		for f: NetProtocol.InputFrame in gate.take():
			host.apply_input(f.dir, Config.NET_TICK)
			frames += 1
		facings[host.facing] = true
		if host.facing != client.facing or host.sim_position != client.pos:
			disagree += 1
	check(frames > 200 and facings.size() == 4, "the walk used every facing (%d frames)" % frames)
	check_eq(disagree, 0, "host facing (derived) = client facing (predicted) after every frame")
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.pos = host.sim_position
	s.facing = host.facing
	s.ack = gate.last_seq
	client.reconcile(s)
	check_eq(client.facing_corrections, 0, "reconciling with the host's state: no facing correction")
	s.facing = (host.facing + 1) % 4  # a host that turned the player some other way
	client.reconcile(s)
	check_eq(client.facing_corrections, 1, "a state whose facing differs from the prediction is counted")
	host.free()


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
	var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]) - Vector2(30, 0)
	var p: Prediction = Prediction.new()
	p.setup(data, start, RigData.Dir.SOUTH, 0)
	check(p.step(Vector2i.ZERO) == null, "standing still records nothing")
	var f: NetProtocol.InputFrame = p.step(Vector2i(1, 0))
	check(f != null and f.seq == 1 and p.facing == RigData.Dir.EAST, "a move records frame 1, facing east")
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
	check_eq(p.facing, RigData.Dir.EAST, "replay derives the facing like the host")
	check_eq(p.pending.size(), 2, "acknowledged frame dropped")
	# A host that disagrees (put the player 5 px south): the host wins, the error is measured.
	s.ack = 3
	s.pos = before + Vector2(0, 5)
	check_between(p.reconcile(s), 4.999, 5.001, "a disagreeing host shows as a 5 px error")
	check_eq(p.pos, before + Vector2(0, 5), "the client takes the host's position")
	check_eq(p.corrections, 1, "one correction")
	check_eq(p.facing_corrections, 0, "same facing on both sides")
	s.ack = 2
	check_eq(p.reconcile(s), -1.0, "an older state is ignored")


## Client and host in one loop, linked by queues with a delay and seeded loss both ways (the same
## shape as the session: frames repeated until acked, states every 3rd tick, the host stepping a
## Player with apply_input, which derives the facing). The client's prediction must never disagree
## with the host, in position or facing.
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
		var host: Player = Player.new()
		host.local_input = false
		host.setup(data, "archer", start, RigData.Dir.SOUTH)
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
				host.apply_input(f.dir, Config.NET_TICK)
			if t % 3 == 0:
				var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
				s.pos = host.sim_position
				s.facing = host.facing
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
		check_eq(client.facing_corrections, 0, "the host's derived facing never disagrees with the prediction (%s)" % label)
		check_eq(client.pos, host.sim_position, "client and host end on the same float32 position (%s)" % label)
		check_eq(client.facing, host.facing, "and the same facing (%s)" % label)
		check(not client.has_unacked() and gate.gaps == 0, "every frame reached the host (%s)" % label)
		check(client.reconciles > 50 and client.frames > 300, "the case really ran (%d reconciles)" % client.reconciles)
		note("prediction over a %s link: %d frames, %d reconciles, max error %.3f px, %d facing corrections, %d duplicate frames at the host" % [
			label, client.frames, client.reconciles, client.max_error_px, client.facing_corrections, gate.duplicates])
		host.free()


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


# --- world snapshot ------------------------------------------------------------------------------

## Every cell of every layer random (floor: random terrains): the incompressible upper bound. The
## bytes come from Crypto (native, not seeded): random data packs to the same size every run.
static func _random_world(size: Vector2i) -> WorldData:
	var data: WorldData = WorldData.new(size)
	var cells: int = size.x * size.y
	var crypto: Crypto = Crypto.new()
	for layer: int in WorldData.LAYER_COUNT:
		var grid: PackedByteArray = crypto.generate_random_bytes(cells)
		if layer == WorldData.Layer.FLOOR:
			for i: int in cells:
				grid[i] = grid[i] % Terrain.COUNT
		data.layers[layer] = grid
	data.altar_rect = Rect2i((size - Config.ALTAR_FOOTPRINT) / 2, Config.ALTAR_FOOTPRINT)
	return data


## A plausible bigger world: the generator's surface (altar, soil, ash zones) at `size`, plus walls
## in noise blobs away from the altar, ore in some wall cells, vegetation on some grass, i.e. all six
## layers in use the way later stages will use them.
static func _synthetic_world(size: Vector2i, world_seed: int) -> WorldData:
	var data: WorldData = SurfaceGen.generate(world_seed, size)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.05
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed
	var walls: PackedByteArray = data.layers[WorldData.Layer.WALL]
	var ore: PackedByteArray = data.layers[WorldData.Layer.ORE]
	var plants: PackedByteArray = data.layers[WorldData.Layer.VEGETATION]
	var floor_grid: PackedByteArray = data.layers[WorldData.Layer.FLOOR]
	var keep_clear: Rect2i = data.altar_rect.grow(12)
	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var n: float = noise.get_noise_2d(x, y)
			if n > 0.3 and not keep_clear.has_point(Vector2i(x, y)):
				walls[i] = 1 + int(n * 4.0)
				if rng.randf() < 0.04:
					ore[i] = rng.randi_range(1, 4)
			elif floor_grid[i] == Terrain.GRASS and n < -0.2 and rng.randf() < 0.3:
				plants[i] = rng.randi_range(1, 6)
	data.layers[WorldData.Layer.WALL] = walls
	data.layers[WorldData.Layer.ORE] = ore
	data.layers[WorldData.Layer.VEGETATION] = plants
	return data


## Feeds every chunk of `packed` to a new receiver and finishes it; returns the world or null.
static func _receive_all(packed: WorldSnapshot.Packed) -> WorldData:
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		if not rx.add(packed.chunk(i)):
			return null
	return rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, packed.world_md5)


## The world snapshot: all six layers round trip exactly, the chunks are bounded and in order, and
## the joiner refuses anything that does not add up (Receiver.finish, decode_raw).
func _check_snapshot() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6
	for layer: int in [WorldData.Layer.WALL, WorldData.Layer.ORE, WorldData.Layer.VEGETATION]:
		for i: int in 300:  # M1 leaves these empty: fill some so the round trip covers all six
			data.set_value(layer, Vector2i(rng.randi_range(0, data.size.x - 1), rng.randi_range(0, data.size.y - 1)),
				rng.randi_range(1, 255))
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(data)
	check_eq(raw.size(), WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * data.size.x * data.size.y,
		"raw snapshot = header + six layers")
	var back: WorldData = WorldSnapshot.decode_raw(raw)
	if check(back != null, "raw snapshot decodes"):
		var same: bool = back.size == data.size and back.world_seed == data.world_seed and back.altar_rect == data.altar_rect
		for layer: int in WorldData.LAYER_COUNT:
			same = same and back.layers[layer] == data.layers[layer]
		check(same, "size, seed, altar and all six layers round trip")
		check_eq(back.content_hash(), data.content_hash(), "same content hash")
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	check(packed.bytes.size() < raw.size() / 10, "zstd packs it (%d of %d bytes)" % [packed.bytes.size(), raw.size()])
	check_eq(packed.world_md5.hex_encode(), data.content_hash(), "packed world md5 = content hash")
	var got: WorldData = _receive_all(packed)
	check(got != null and got.content_hash() == data.content_hash(), "chunks -> the same world")
	# Several chunks: bounded, in order.
	var big: WorldSnapshot.Packed = WorldSnapshot.encode(_random_world(Vector2i(48, 40)))
	var largest: int = 0
	for i: int in big.chunk_count():
		largest = maxi(largest, big.chunk(i).size())
	check(big.chunk_count() >= 5, "a random world needs several chunks (%d)" % big.chunk_count())
	check_eq(largest, WorldSnapshot.CHUNK_HEADER + Config.NET_SNAPSHOT_CHUNK_BYTES, "chunks are at most %d B + index" %
		Config.NET_SNAPSHOT_CHUNK_BYTES)
	var big_world: WorldData = _receive_all(big)
	check(big_world != null and big_world.content_hash() == big.world_md5.hex_encode(), "a multi-chunk snapshot arrives whole")
	# The host's pacing (WorldSnapshot.Sender): every chunk once, in order, at most a tick's budget at a time.
	var sender: WorldSnapshot.Sender = WorldSnapshot.Sender.new(big)
	var per_tick: Array[int] = []
	var paced: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	var all_added: bool = true
	while not sender.done() and per_tick.size() < 100:
		var batch: Array[PackedByteArray] = sender.take(4)
		per_tick.append(batch.size())
		for c: PackedByteArray in batch:
			all_added = paced.add(c) and all_added
	var want_ticks: Array[int] = []
	for i: int in ceili(big.chunk_count() / 4.0):
		want_ticks.append(mini(4, big.chunk_count() - 4 * i))
	check_eq(per_tick, want_ticks, "sender: %d chunks at most 4 per tick" % big.chunk_count())
	check(all_added and sender.take(4).is_empty(), "sender: in order, then nothing more")
	var paced_world: WorldData = paced.finish(big.chunk_count(), big.bytes.size(), big.packed_md5, big.raw_size, big.world_md5)
	check(paced_world != null, "sender: the paced chunks make the world (%s)" % paced.error)
	# Smaller chunks (the test hook a session host can use): more of them, the same world.
	WorldSnapshot.chunk_bytes = 32
	var small: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	WorldSnapshot.chunk_bytes = Config.NET_SNAPSHOT_CHUNK_BYTES
	check(small.chunk_size == 32 and small.chunk_count() == ceili(small.bytes.size() / 32.0) and small.chunk_count() > 8,
		"32-byte chunks: %d of them" % small.chunk_count())
	var small_world: WorldData = _receive_all(small)
	check(small_world != null and small_world.content_hash() == data.content_hash(), "small chunks make the same world")
	# The joiner's checks.
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	check(not rx.add(big.chunk(1)) and rx.error.contains("expected 0"), "a chunk out of order is refused (%s)" % rx.error)
	check(not rx.add(PackedByteArray([0, 0, 0, 0])), "an empty chunk is refused")
	var oversized: PackedByteArray = big.chunk(0)
	oversized.append(0)
	check(not rx.add(oversized), "a chunk over the size bound is refused")
	rx = WorldSnapshot.Receiver.new()
	for i: int in big.chunk_count() - 1:
		rx.add(big.chunk(i))
	check(rx.finish(big.chunk_count(), big.bytes.size(), big.packed_md5, big.raw_size, big.world_md5) == null,
		"a missing chunk is noticed (%s)" % rx.error)
	rx = WorldSnapshot.Receiver.new()
	for i: int in big.chunk_count():
		var c: PackedByteArray = big.chunk(i)
		if i == 2:
			c[WorldSnapshot.CHUNK_HEADER + 10] ^= 0x40
		rx.add(c)
	check(rx.finish(big.chunk_count(), big.bytes.size(), big.packed_md5, big.raw_size, big.world_md5) == null
		and rx.error.contains("md5"), "a changed byte fails the md5 (%s)" % rx.error)
	rx = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	check(rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, big.world_md5) == null
		and rx.error.contains("world hash"), "a world that is not the one the host hashed is refused (%s)" % rx.error)
	check(rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size + 1, packed.world_md5) == null,
		"a wrong raw size is refused (%s)" % rx.error)
	# decode_raw refuses what is not a world.
	check(WorldSnapshot.decode_raw(raw.slice(0, raw.size() - 1)) == null, "truncated raw snapshot")
	var bad: PackedByteArray = raw.duplicate()
	bad.encode_u8(20, 5)
	check(WorldSnapshot.decode_raw(bad) == null, "wrong layer count")
	bad = raw.duplicate()
	bad.encode_u16(12, data.size.x - 1)
	check(WorldSnapshot.decode_raw(bad) == null, "altar outside the map")
	bad = raw.duplicate()
	bad[WorldSnapshot.HEADER_SIZE + 7] = Terrain.COUNT
	check(WorldSnapshot.decode_raw(bad) == null, "a floor value that is no terrain")
	bad = raw.duplicate()
	bad.encode_u16(0, 0)
	check(WorldSnapshot.decode_raw(bad) == null, "an empty map")


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
	# Host world with edits; a late joiner gets it as a snapshot (edits included) and the log position.
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
	var generated: String = joiner.data.content_hash()
	var received: WorldData = _receive_all(WorldSnapshot.encode(host.data))
	if not check(received != null, "snapshot of the edited host world arrives"):
		return
	joiner.load_data(received)
	var joiner_log: EditLog = EditLog.new()
	joiner_log.base = log.size()
	check_eq(joiner.data.content_hash(), host.data.content_hash(), "snapshot = the host's world")
	check_ne(joiner.data.content_hash(), generated, "the edits are in it")
	check(joiner_log.size() == 3 and joiner_log.edit_at(2) == null and log.edit_at(2) != null,
		"the joiner's log starts at the snapshot's position (3) and holds none of the old edits")
	# A live edit after the snapshot: index = the joiner's log position; applying twice is harmless.
	var later: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.FLOOR, grass_cell + Vector2i(0, 1), Terrain.SOIL)
	if check_eq(EditLog.check(host.data, later), "", "a later host edit is allowed"):
		host.apply_edit(later)
		log.append(later)
		var one: Array = EditLog.decode_one(EditLog.encode_one(later, log.size() - 1))
		var index: int = one[0]
		var edit: EditLog.WorldEdit = one[1]
		check_eq(index, joiner_log.size(), "the live edit's index is the joiner's next")
		joiner.apply_edit(edit)
		joiner.apply_edit(edit)  # absolute edits: the second time changes nothing
		joiner_log.append(edit)
	check_eq(joiner.data.content_hash(), host.data.content_hash(), "snapshot + live edit = the host's world")
	var v: Dictionary[String, int] = joiner.ground.verify()
	check(v["mismatches"] == 0 and v["missing"] == 0 and v["fallbacks"] == 0, "joiner's ground drawn from the received data %s" % v)
	check_eq(joiner.ground.view_hash(), host.ground.view_hash(), "same picture on both")
	check(joiner.altar != null and joiner.altar.footprint_px.position == data.altar_rect.position * Config.TILE,
		"the altar stands on the received footprint")
	# The test-only generator perturbation (--test-perturb-generator) really makes another world.
	SurfaceGen.test_perturb = true
	var perturbed: String = SurfaceGen.generate(Config.DEFAULT_SEED).content_hash()
	SurfaceGen.test_perturb = false
	check_ne(perturbed, SurfaceGen.generate(Config.DEFAULT_SEED).content_hash(), "the perturbed generator makes a different world")
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


## Snapshot size and join time for the M1 map, a synthetic 512x512 world and a random 512x512 one
## (upper bound): encode on the host, the chunks over a real ENet connection in this process paced
## like the host (NET_SNAPSHOT_CHUNKS_PER_TICK per physics tick), the joiner's checks + decode, and
## drawing the world (GameWorld.load_data). The random world's transfer is the pacing (ticks), not
## sent, to keep the test short.
func _check_snapshot_join() -> void:
	var port: int = Runner.free_port(Runner.port_first, Runner.port_last)
	if not check(port > 0, "a free test port for the snapshot transfer"):
		return
	var server: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var client: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var joined: Array[int] = []
	server.peer_connected.connect(func(id: int) -> void: joined.append(id))
	check_eq(server.create_server(port, 1), OK, "snapshot transfer: host on port %d" % port)
	check_eq(client.create_client("127.0.0.1", port), OK, "snapshot transfer: client")
	var t0: int = Time.get_ticks_msec()
	while (joined.is_empty() or client.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED) \
			and Time.get_ticks_msec() - t0 < 5000:
		server.poll()
		client.poll()
		await tree.physics_frame
	if not check(not joined.is_empty(), "snapshot transfer: connected"):
		server.close()
		client.close()
		return
	server.set_target_peer(joined[0])
	server.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var view: GameWorld = _new_world()
	var cases: Array[Array] = [
		["128x96 M1 map (seed 1)", SurfaceGen.generate(Config.DEFAULT_SEED), true],
		["512x512 synthetic (all six layers in use)", _synthetic_world(Vector2i(512, 512), 5), true],
		["512x512 random (upper bound)", _random_world(Vector2i(512, 512)), false],
	]
	for c: Array in cases:
		var label: String = c[0]
		var data: WorldData = c[1]
		var send: bool = c[2]
		var packed: WorldSnapshot.Packed = WorldSnapshot.encode(data)
		var ticks: int = ceili(float(packed.chunk_count()) / Config.NET_SNAPSHOT_CHUNKS_PER_TICK)
		var transfer_ms: float = ticks * 1000.0 / Config.NET_TICK_RATE
		var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
		if send:
			# Paced like the host: a batch of chunks at every tick of real time (1/60 s).
			var t_send: int = Time.get_ticks_usec()
			var next_tick_usec: int = t_send
			var next: int = 0
			while rx.chunks < packed.chunk_count() and Time.get_ticks_usec() - t_send < 10000000:
				if Time.get_ticks_usec() >= next_tick_usec:
					next_tick_usec += 1000000 / Config.NET_TICK_RATE
					for i: int in Config.NET_SNAPSHOT_CHUNKS_PER_TICK:
						if next < packed.chunk_count():
							server.put_packet(packed.chunk(next))
							next += 1
				server.poll()
				client.poll()
				while client.get_available_packet_count() > 0:
					rx.add(client.get_packet())
				if rx.chunks < packed.chunk_count():
					await tree.process_frame
			transfer_ms = (Time.get_ticks_usec() - t_send) / 1000.0
		else:
			for i: int in packed.chunk_count():
				rx.add(packed.chunk(i))
		var t_check: int = Time.get_ticks_usec()
		var got: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size,
			packed.world_md5)
		var check_ms: float = (Time.get_ticks_usec() - t_check) / 1000.0
		if not check(got != null and got.content_hash() == data.content_hash(), "%s: arrives whole (%s)" % [label, rx.error]):
			continue
		var t_draw: int = Time.get_ticks_usec()
		if send:
			view.load_data(got)
		var draw_ms: float = (Time.get_ticks_usec() - t_draw) / 1000.0
		if send:
			var v: Dictionary[String, int] = view.ground.verify()
			check(v["missing"] == 0 and v["mismatches"] == 0, "%s: drawn from the received data %s" % [label, v])
		check(packed.chunk_count() == ceili(float(packed.bytes.size()) / Config.NET_SNAPSHOT_CHUNK_BYTES)
			and packed.chunk_size == Config.NET_SNAPSHOT_CHUNK_BYTES,
			"%s: chunk count" % label)
		var join_ms: float = packed.encode_usec / 1000.0 + transfer_ms + check_ms + draw_ms
		note("snapshot %s: raw %d B -> packed %d B (%.1f%%) in %d chunks = %d ticks; encode %.1f ms, transfer %.0f ms%s, check + decode %.1f ms, draw %s; join about %.0f ms" % [
			label, packed.raw_size, packed.bytes.size(), 100.0 * packed.bytes.size() / packed.raw_size, packed.chunk_count(),
			ticks, packed.encode_usec / 1000.0, transfer_ms, " (ENet localhost)" if send else " (pacing only)", check_ms,
			"%.0f ms" % draw_ms if send else "(not drawn)", join_ms])
	server.close()
	client.close()


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
		"--net-expect-refused=1", "--net-timeout=30", "--net-lag=80", "--net-loss=12.5", "--keep-running",
		"--test-perturb-generator", "--test-snapshot-chunk-bytes=32"]))
	check_eq(o.errors.size(), 0, "session flags parse (%s)" % str(o.errors))
	check(o.host and o.port == 24625 and o.transport == "steam" and o.max_players == 4 and o.bot == "move:1,0,10",
		"session flags values")
	check(o.net_out == "C:/x" and o.net_name == "c1" and o.net_start == 2 and o.net_expect == 3
		and o.net_expect_refused == 1 and o.net_timeout == 30.0 and o.net_lag == 80 and o.net_loss == 12.5
		and o.keep_running and o.test_perturb_generator and o.test_snapshot_chunk_bytes == 32,
		"session test flag values")
	var defaults: CliOptions = CliOptions.parse(PackedStringArray([]))
	check(defaults.transport == "enet" and defaults.max_players == 9 and defaults.net_expect == -1
		and defaults.net_start == 0 and not defaults.test_perturb_generator, "session defaults")
	for argv: PackedStringArray in [PackedStringArray(["--transport=tcp"]), PackedStringArray(["--max-players=10"]),
			PackedStringArray(["--max-players=0"]), PackedStringArray(["--bot=fly:1"]), PackedStringArray(["--bot="]),
			PackedStringArray(["--net-name=a/b"]), PackedStringArray(["--net-expect=x"]),
			PackedStringArray(["--net-timeout=0"]), PackedStringArray(["--net-loss=101"]), PackedStringArray(["--net-lag=-5"]),
			PackedStringArray(["--test-snapshot-chunk-bytes=0"]), PackedStringArray(["--test-snapshot-chunk-bytes=1025"])]:
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
	var port: int = Runner.free_port(Runner.port_last, Runner.port_first)
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
	allow_error("Couldn't create an ENet host")
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
