class_name SessionHost
extends RefCounted
## Host flow of the session (net/session.gd holds the shared state and the RPC table): admitting
## or refusing joiners, streaming each joiner its world snapshot and then welcoming it, world edits,
## input frames, the host tick and the state batches, dropping silent connections.
##
## A joiner's way in: hello -> admitted (roster slot, a member at its spawn slot, the other players
## hear "joined") -> the world packed at that moment (WorldSnapshot) goes out in chunks, at most
## Config.NET_SNAPSHOT_CHUNKS_PER_TICK per tick -> after the last chunk, in the same tick: welcome
## (players as they are now, the snapshot's edit log position) + every edit made since the snapshot.
## Only then does it count as a remote peer (state batches, edits, joined / left, go): everything
## on the reliable channel reaches it after the world, in order.

## A joiner whose world is still being sent.
class Stream:
	extends RefCounted
	var peer: int = 0
	var slot: int = 0
	var snapshot: WorldSnapshot.Packed
	var sender: WorldSnapshot.Sender
	## Edit log position when the snapshot was taken.
	var edit_position: int = 0
	var started_ms: int = 0


var s: NetSession
var roster: Roster
## Batch / keyframe / quiet decisions.
var broadcast: StateBroadcast = StateBroadcast.new()
var refusals: Dictionary[String, int] = {}
## Joiners still receiving their world, by peer.
var streams: Dictionary[int, Stream] = {}
var snapshots_sent: int = 0
var snapshot_bytes_sent: int = 0
## Ticks whose traffic still counts as joining (NetStats bucket "joining", not "<moving>/<players>"):
## the tick that sent chunks or a welcome and the next two, since ENet sends at the end of the frame
## and the bytes are counted on the next tick.
var joining_ticks: int = 0

var connected_ms: Dictionary[int, int] = {}
var refused_ms: Dictionary[int, int] = {}
var _last_take_usec: int = 0


func _init(p_session: NetSession) -> void:
	s = p_session
	roster = Roster.new(s.options.max_players)


func on_opened() -> void:
	var slot: int = roster.admit(1, s.local_class())
	s.local = s.add_member(slot, 1, s.local_class(), s.world.spawn_point(slot), Config.SPAWN_FACING)
	s.active = true
	_last_take_usec = Time.get_ticks_usec()
	s.log_event("hosting", "port=%d slot=%d class=%s" % [s.options.port, slot, s.local.class_id])
	s.local_player_ready.emit(s.local.player)
	s.bots.mark("ready")
	if s.options.net_start <= 0:
		s.bots.start_bots()


func on_peer_connected(peer_id: int) -> void:
	connected_ms[peer_id] = Time.get_ticks_msec()


func on_peer_disconnected(peer_id: int) -> void:
	connected_ms.erase(peer_id)
	refused_ms.erase(peer_id)
	streams.erase(peer_id)
	if not roster.has(peer_id):
		return
	var slot: int = roster.release(peer_id)
	broadcast.note_activity(s.tick)
	s.bots.note_gone(peer_id)  # a player who left will not finish a bot any more
	s.remove_member(slot)
	if not s.bots.finishing:  # after "finish" the clients' lists are frozen and they are leaving too
		var payload: PackedByteArray = PackedByteArray([slot])
		for peer: int in remote_peers():
			s.send_left(peer, payload)
	s.log_event("left", "peer=%d slot=%d players=%d" % [peer_id, slot, roster.count()])


## A joiner introduces itself.
func on_hello(peer_id: int, payload: PackedByteArray) -> void:
	if not s.active or s.over:
		return
	if roster.has(peer_id) or refused_ms.has(peer_id):
		s.bad_messages += 1
		return
	connected_ms.erase(peer_id)
	var hello: NetProtocol.Hello = NetProtocol.decode_hello(payload)
	var class_id: String = NetProtocol.class_name_of(hello.class_index)
	var reason: NetProtocol.Refusal = NetProtocol.Refusal.NONE
	if not hello.ok:
		reason = NetProtocol.Refusal.BAD_HELLO
	elif hello.version != NetProtocol.VERSION:
		reason = NetProtocol.Refusal.VERSION
	else:
		reason = roster.refusal_for(class_id)
	if reason != NetProtocol.Refusal.NONE:
		_refuse(peer_id, reason)
		return
	var slot: int = roster.admit(peer_id, class_id)
	var m: NetMember = s.add_member(slot, peer_id, class_id, s.world.spawn_point(slot), Config.SPAWN_FACING)
	m.gate = InputGate.new()
	broadcast.note_activity(s.tick)
	var stream: Stream = Stream.new()
	stream.peer = peer_id
	stream.slot = slot
	stream.snapshot = WorldSnapshot.encode(s.world.data)
	stream.sender = WorldSnapshot.Sender.new(stream.snapshot)
	stream.edit_position = s.edit_log.size()
	stream.started_ms = Time.get_ticks_msec()
	streams[peer_id] = stream
	var joined: PackedByteArray = NetProtocol.encode_info(m.info())
	for peer: int in remote_peers():
		s.send_joined(peer, joined)
	s.log_event("joined", "peer=%d slot=%d class=%s players=%d world_bytes=%d raw=%d chunks=%d encode_us=%d" % [
		peer_id, slot, class_id, roster.count(), stream.snapshot.bytes.size(), stream.snapshot.raw_size,
		stream.snapshot.chunk_count(), stream.snapshot.encode_usec])


func _refuse(peer_id: int, reason: NetProtocol.Refusal) -> void:
	var name: String = NetProtocol.REFUSAL_NAMES[reason]
	var seen: int = refusals.get(name, 0)
	refusals[name] = seen + 1
	refused_ms[peer_id] = Time.get_ticks_msec()
	# The refused client disconnects itself after reading this (disconnect_peer() here would drop
	# the message unsent); the host only cuts it off after NET_REFUSE_GRACE_SEC.
	s.send_refused(peer_id, NetProtocol.encode_refusal(reason))
	s.log_event("refused", "peer=%d reason=%s players=%d" % [peer_id, name, roster.count()])


## Sends every joiner its next chunks; a joiner whose last chunk went out is welcomed.
func _pump_streams() -> void:
	for peer: int in streams.keys():
		var st: Stream = streams[peer]
		if not s.transport.can_send_to(peer):
			continue
		for chunk: PackedByteArray in st.sender.take(Config.NET_SNAPSHOT_CHUNKS_PER_TICK):
			s.send_world(peer, chunk)
			snapshot_bytes_sent += chunk.size()
		joining_ticks = 3
		if st.sender.done():
			streams.erase(peer)
			_welcome(st)


func _welcome(st: Stream) -> void:
	s.send_welcome(st.peer, NetProtocol.encode_welcome(_welcome_for(st)))
	var catch_up: int = 0
	for index: int in range(st.edit_position, s.edit_log.size()):
		s.send_edit(st.peer, EditLog.encode_one(s.edit_log.edit_at(index), index))
		catch_up += 1
	snapshots_sent += 1
	s.log_event("welcomed", "peer=%d slot=%d chunks=%d bytes=%d edit_position=%d catch_up_edits=%d stream_ms=%d" % [
		st.peer, st.slot, st.snapshot.chunk_count(), st.snapshot.bytes.size(), st.edit_position, catch_up,
		Time.get_ticks_msec() - st.started_ms])
	if not s.bots.bots_started and s.options.net_start > 0 and remote_peers().size() >= s.options.net_start:
		s.bots.start_bots()


func _welcome_for(st: Stream) -> NetProtocol.Welcome:
	var w: NetProtocol.Welcome = NetProtocol.Welcome.new()
	w.slot = st.slot
	w.max_players = roster.max_players
	w.tick = s.tick
	w.bots_started = s.bots.bots_started
	w.edit_position = st.edit_position
	w.raw_size = st.snapshot.raw_size
	w.packed_size = st.snapshot.bytes.size()
	w.chunk_count = st.snapshot.chunk_count()
	w.packed_md5 = st.snapshot.packed_md5
	w.world_md5 = st.snapshot.world_md5
	w.world_seed = s.world.data.world_seed
	w.generator_md5 = s.generator_hash.hex_decode()
	for slot: int in s.slots():
		w.players.append(s.members[slot].info())
	return w


# --- world edits -----------------------------------------------------------------------------

## Checks, applies, logs and sends a world edit. Returns "" or why it was refused.
func edit(world_edit: EditLog.WorldEdit) -> String:
	var why: String = EditLog.check(s.world.data, world_edit)
	if not why.is_empty():
		s.log_event("edit_refused", "%s: %s" % [world_edit.describe(), why])
		return why
	s.world.apply_edit(world_edit)
	var payload: PackedByteArray = EditLog.encode_one(world_edit, s.edit_log.size())
	s.edit_log.append(world_edit)
	for peer: int in remote_peers():
		s.send_edit(peer, payload)
	s.log_event("edit", "%s index=%d world=%s" % [world_edit.describe(), s.edit_log.size() - 1,
		s.world.data.content_hash().left(12)])
	return ""


# --- movement --------------------------------------------------------------------------------

## A client's input frames.
func on_input(peer_id: int, payload: PackedByteArray) -> void:
	if s.over:
		return
	var slot: int = roster.slot_of(peer_id)
	if slot < 0 or not s.members.has(slot) or s.members[slot].gate == null:
		s.unknown_senders += 1
		return
	s.members[slot].gate.receive(NetProtocol.decode_inputs(payload))


func tick(action: NetBot.Action, now: int) -> void:
	# The facing of every player follows its input (Player.apply_input -> Movement.facing_for):
	# clients send directions only.
	s.local.player.apply_input(action.dir, Config.NET_TICK)
	# Real time since the last tick refills the input gates (a hitch's lost ticks included).
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_ticks: float = (now_usec - _last_take_usec) * Config.NET_TICK_RATE / 1000000.0
	_last_take_usec = now_usec
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if m.gate == null:
			continue
		for frame: NetProtocol.InputFrame in m.gate.take(elapsed_ticks):
			m.player.apply_input(frame.dir, Config.NET_TICK)
	for slot: int in s.members:
		if s.members[slot].player.walking:
			broadcast.note_activity(s.tick)  # before this tick's batch decision
			break
	if action.edit != null:
		edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, action.edit.cell, action.edit.terrain))
	if not action.mark.is_empty():
		s.bots.mark(action.mark)
	if action.leave:
		s.log_event("bot", "leave is for clients; the host ignores it")
	_drop_silent_peers(now)
	_pump_streams()
	if s.tick % (Config.NET_TICK_RATE / Config.NET_STATE_HZ) == 0:
		_send_states()
	s.bots.host_after_tick(now)


## One state batch for everybody while something changed, a reliable keyframe once it stops.
func _send_states() -> void:
	var states: Array[NetProtocol.PlayerState] = []
	for slot: int in s.slots():
		states.append(s.members[slot].state())
	match broadcast.decide(s.tick, states):
		StateBroadcast.Send.BATCH:
			for peer: int in remote_peers():
				s.send_state(peer, broadcast.payload)
		StateBroadcast.Send.KEYFRAME:
			for peer: int in remote_peers():
				s.send_keyframe(peer, broadcast.payload)


func _drop_silent_peers(now: int) -> void:
	var peer: MultiplayerPeer = s.multiplayer.multiplayer_peer
	for id: int in connected_ms.keys():
		if now - connected_ms[id] > int(Config.NET_HELLO_TIMEOUT_SEC * 1000.0):
			connected_ms.erase(id)
			s.log_event("dropped", "peer=%d reason=no_hello" % id)
			peer.disconnect_peer(id)
	for id: int in refused_ms.keys():
		if now - refused_ms[id] > int(Config.NET_REFUSE_GRACE_SEC * 1000.0):
			refused_ms.erase(id)
			s.log_event("dropped", "peer=%d reason=refused_still_connected" % id)
			peer.disconnect_peer(id)


## Welcomed clients (not the host itself, not a joiner still loading its world) a message can
## still reach.
func remote_peers() -> Array[int]:
	var out: Array[int] = []
	for peer: int in roster.peers():
		if peer != 1 and not streams.has(peer) and s.transport.can_send_to(peer):
			out.append(peer)
	return out


## Nobody is half-way in: no connection without hello, no refused one still there, no world still
## being sent.
func settled() -> bool:
	return connected_ms.is_empty() and refused_ms.is_empty() and streams.is_empty()
