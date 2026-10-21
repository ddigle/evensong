class_name SessionClient
extends RefCounted
## Client flow of the session (net/session.gd holds the shared state and the RPC table): hello,
## the world snapshot and the welcome, refusal, other players joining and leaving, live world
## edits, host states (own player: prediction; others: interpolation), the client tick that sends
## input frames, and drawing the other players each frame.
##
## Late join: the world comes from the host, not from this machine's generator. The chunks
## (WorldSnapshot.Receiver) are checked on the welcome (count, size, md5 of the packed bytes, then
## the world's content hash) and the world is built and drawn from them (GameWorld.load_data). Any
## failure there ends the session with EXIT_WORLD_MISMATCH. The seed and the host's generator hash
## only feed a diagnostic: whether this machine's generator would have made the same world
## (logged as generator=match|differs, never fatal).

var s: NetSession
var prediction: Prediction
var clock: Interpolation.RemoteClock = Interpolation.RemoteClock.new()
var receiver: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
var stale_batches: int = 0
## Frames that drew a walking player, and how many of them had no newer state to move to.
var interp_samples: int = 0
var interp_starved: int = 0
var refused_reason: String = ""
## Join: when the transport connected, how long until the world was ready, what came in.
var connected_usec: int = 0
var join_ms: float = -1.0
var world_build_ms: float = -1.0
var snapshot_bytes: int = 0
var snapshot_raw: int = 0
var snapshot_chunks: int = 0
## Diagnostic: the host's generator hash for its seed, and whether this machine's matches it.
var host_generator_hash: String = ""
var generator_match: bool = false

var _last_state_tick: int = -1


func _init(p_session: NetSession) -> void:
	s = p_session


func on_opened() -> void:
	connected_usec = Time.get_ticks_usec()
	s.log_event("connected", "to=%s:%d" % [s.options.join_address, s.options.port])
	s.send_hello(NetProtocol.encode_hello(NetProtocol.class_index(s.local_class())))


## Before a tick: the link simulation, and the connect timeout. False when the session ended.
func before_tick(now: int, start_ms: int) -> bool:
	s.link.poll(now)
	if not s.active and now - start_ms > int(Config.NET_CONNECT_TIMEOUT_SEC * 1000.0):
		if receiver.chunks == 0:
			s.end_session("failed: not admitted within %.0f s" % Config.NET_CONNECT_TIMEOUT_SEC, NetSession.EXIT_FAILED)
		else:  # admitted, but the world is too big or the link too slow for the timeout
			s.end_session("failed: world not complete within %.0f s (%d chunks, %d B so far)" % [
				Config.NET_CONNECT_TIMEOUT_SEC, receiver.chunks, receiver.bytes.size()], NetSession.EXIT_FAILED)
		return false
	return true


func on_server_disconnected() -> void:
	if s.bots.finish_wait >= 0 or s.bots.leave_wait >= 0:
		return
	s.end_session("lost the host", NetSession.EXIT_FAILED)


# --- joining ---------------------------------------------------------------------------------

func on_world_chunk(payload: PackedByteArray) -> void:
	if s.local != null or s.over:
		return
	if not receiver.add(payload):
		_world_failed("bad world chunk: %s" % receiver.error)


## Admitted: build the world from the snapshot, check it, create the players.
func on_welcome(payload: PackedByteArray) -> void:
	if s.local != null or s.over:
		return
	var w: NetProtocol.Welcome = NetProtocol.decode_welcome(payload)
	if not w.ok or w.version != NetProtocol.VERSION:
		s.end_session("failed: bad welcome", NetSession.EXIT_FAILED)
		return
	var t0: int = Time.get_ticks_usec()
	var data: WorldData = receiver.finish(w.chunk_count, w.packed_size, w.packed_md5, w.raw_size, w.world_md5)
	if data == null:
		_world_failed(receiver.error)
		return
	s.world.load_data(data)
	world_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	snapshot_bytes = w.packed_size
	snapshot_raw = w.raw_size
	snapshot_chunks = w.chunk_count
	receiver = WorldSnapshot.Receiver.new()
	s.edit_log = EditLog.new()
	s.edit_log.base = w.edit_position
	# Diagnostic only: would this machine's generator have made the host's seed world? (The seed
	# comes with the snapshot.)
	s.generator_hash = SurfaceGen.generate(data.world_seed, data.size).content_hash()
	host_generator_hash = w.generator_md5.hex_encode()
	generator_match = s.generator_hash == host_generator_hash
	for info: NetProtocol.PlayerInfo in w.players:
		var m: NetMember = s.add_member(info.state.slot, 0, NetProtocol.class_name_of(info.class_index), info.state.pos,
			info.state.facing)
		if info.state.slot == w.slot:
			s.local = m
		else:
			m.interp = Interpolation.new()
			m.interp.push(w.tick, info.state)
	if s.local == null:
		s.end_session("failed: welcome without my player", NetSession.EXIT_FAILED)
		return
	prediction = Prediction.new()
	var me: NetProtocol.PlayerState = s.local.state()
	prediction.setup(s.world.data, me.pos, me.facing, 0)
	clock.observe(w.tick, Interpolation.RemoteClock.now_ticks())
	_last_state_tick = w.tick
	s.active = true
	join_ms = (Time.get_ticks_usec() - connected_usec) / 1000.0
	s.log_event("welcome", ("slot=%d class=%s players=%d max=%d seed=%d edits=%d world=%s world_bytes=%d raw=%d " +
		"chunks=%d build_ms=%.1f join_ms=%.1f generator=%s") % [w.slot, s.local.class_id, s.members.size(),
		w.max_players, data.world_seed, s.edit_log.size(), data.content_hash().left(12), w.packed_size, w.raw_size,
		w.chunk_count, world_build_ms, join_ms, "match" if generator_match else "differs (local %s, host %s)" % [
		s.generator_hash.left(12), host_generator_hash.left(12)]])
	s.local_player_ready.emit(s.local.player)
	s.bots.mark("welcome")
	if w.bots_started:
		s.bots.start_bots()


func _world_failed(why: String) -> void:
	s.log_event("world_mismatch", why)
	s.end_session("world mismatch: %s" % why, NetSession.EXIT_WORLD_MISMATCH)


func on_refused(payload: PackedByteArray) -> void:
	if s.over:
		return
	refused_reason = NetProtocol.decode_refusal(payload)
	s.end_session("refused: %s" % refused_reason, NetSession.EXIT_REFUSED)


func on_joined(payload: PackedByteArray) -> void:
	if not s.active or s.bots.finish_wait >= 0:
		return
	var info: NetProtocol.PlayerInfo = NetProtocol.decode_info(payload)
	if info == null or payload.size() != NetProtocol.INFO_SIZE or s.members.has(info.state.slot):
		s.bad_messages += 1
		return
	var m: NetMember = s.add_member(info.state.slot, 0, NetProtocol.class_name_of(info.class_index), info.state.pos,
		info.state.facing)
	m.interp = Interpolation.new()
	m.interp.push(maxi(_last_state_tick, 0), info.state)
	s.log_event("joined", "slot=%d class=%s players=%d" % [m.slot, m.class_id, s.members.size()])


func on_left(payload: PackedByteArray) -> void:
	# After "finish" the player list is frozen: clients that already left must stay in the result.
	if not s.active or s.bots.finish_wait >= 0:
		return
	if payload.size() != 1 or not s.members.has(payload[0]) or s.members[payload[0]] == s.local:
		s.bad_messages += 1
		return
	s.remove_member(payload[0])
	s.log_event("left", "slot=%d players=%d" % [payload[0], s.members.size()])


func on_edit(payload: PackedByteArray) -> void:
	if not s.active:
		return
	var decoded: Array = EditLog.decode_one(payload)
	var index: int = decoded[0]
	if index < 0:
		s.bad_messages += 1
		return
	var edit: EditLog.WorldEdit = decoded[1]
	if index != s.edit_log.size():
		s.bad_messages += 1
	if s.world.apply_edit(edit):
		s.edit_log.append(edit)
	s.log_event("edit", "%s index=%d world=%s" % [edit.describe(), index, s.world.data.content_hash().left(12)])


# --- movement --------------------------------------------------------------------------------

func on_state(payload: PackedByteArray) -> void:
	if not s.active:
		return
	s.link.pass_through(_apply_states.bind(payload), Time.get_ticks_msec())


func on_keyframe(payload: PackedByteArray) -> void:
	if not s.active:
		return
	_apply_states(payload)


func _apply_states(payload: PackedByteArray) -> void:
	if not s.active or s.over:
		return
	var batch: NetProtocol.StateBatch = NetProtocol.decode_states(payload)
	if not batch.ok:
		s.bad_messages += 1
		return
	if batch.tick <= _last_state_tick:
		stale_batches += 1
		return
	_last_state_tick = batch.tick
	clock.observe(batch.tick, Interpolation.RemoteClock.now_ticks())
	for st: NetProtocol.PlayerState in batch.states:
		if st.slot == s.local.slot:
			prediction.reconcile(st)
			s.local.player.show_state(prediction.pos, prediction.facing, prediction.walking)
		elif s.members.has(st.slot) and s.members[st.slot].interp != null:
			s.members[st.slot].interp.push(batch.tick, st)


func tick(action: NetBot.Action) -> void:
	var frame: NetProtocol.InputFrame = prediction.step(action.dir)
	s.local.player.show_state(prediction.pos, prediction.facing, prediction.walking, true)
	var interval: int = Config.NET_TICK_RATE / Config.NET_INPUT_HZ
	# Send every 2nd tick while frames are unacknowledged, and at once when a move starts.
	if prediction.has_unacked() and (s.tick % interval == 0 or (frame != null and prediction.pending.size() == 1)):
		s.link.pass_through(s.send_input.bind(NetProtocol.encode_inputs(prediction.frames_to_send())),
			Time.get_ticks_msec())
	if action.edit != null:
		s.log_event("bot", "edit ignored: only the host edits the world")
	if not action.mark.is_empty():
		s.bots.mark(action.mark)
	if action.stall_ms > 0:
		s.stall_after_tick(action.stall_ms)
	s.bots.client_after_tick(action)


## Every frame: the other players 100 ms behind the host (Interpolation).
func draw_others() -> void:
	var t: float = clock.host_tick_at(Interpolation.RemoteClock.now_ticks()) - interp_delay_ticks()
	for slot: int in s.members:
		var m: NetMember = s.members[slot]
		if m.interp == null:
			continue
		var newest: Interpolation.Snap = m.interp.latest()
		if newest != null and newest.walking:
			interp_samples += 1
			if t > newest.tick:
				interp_starved += 1  # drawing past the newest state of a walking player: buffer ran dry
		var smp: Interpolation.Snap = m.interp.sample(t)
		if smp != null:
			m.player.show_state(smp.pos, smp.facing, smp.walking)


static func interp_delay_ticks() -> float:
	return Config.NET_INTERP_DELAY_MS * Config.NET_TICK_RATE / 1000.0
