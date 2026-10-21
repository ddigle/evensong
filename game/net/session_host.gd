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
##
## M2b: each tick the host builds its own player's frame from its keys / mouse / bot (Player.make_frame)
## and runs it like a client's: run_frame() checks the frame's request at that frame's position and
## applies it before the frame is stepped (PlayerSim.step). Use: the slot must hold a tool, the target
## tile must be next to the feet, no action may still be playing ("busy"); a refused use is simply not
## started (the client's prediction is corrected by the next state). Select, pick up, drop and give
## also pass the request rate (NetMember tokens, "rate"); give from a client only in debug builds or
## with --test-allow-give ("give off"). World changes go out as numbered edits (apply_world_edit); a
## member whose inventory changed gets it after the tick (ack = its last handled frame). Members are
## handled in slot order, frames in seq order, edits applied at once: two players picking up the same
## thing in one tick -> the lower slot gets it, the other finds nothing.

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
	## Host ticks that sent chunks to this joiner.
	var ticks: int = 0


var s: NetSession
var roster: Roster
## Batch / keyframe / quiet decisions.
var broadcast: StateBroadcast = StateBroadcast.new()
var refusals: Dictionary[String, int] = {}
## Joiners still receiving their world, by peer.
var streams: Dictionary[int, Stream] = {}
var snapshots_sent: int = 0
var snapshot_bytes_sent: int = 0
## Every finished stream, for the test results: slot, chunks, ticks, edit position, catch-up edits.
var streams_done: Array[Dictionary] = []
## Ticks whose traffic still counts as joining (NetStats bucket "joining", not "<moving>/<players>"):
## the tick that sent chunks or a welcome and the next two, since ENet sends at the end of the frame
## and the bytes are counted on the next tick.
var joining_ticks: int = 0

var connected_ms: Dictionary[int, int] = {}
var refused_ms: Dictionary[int, int] = {}
## Gatherables picked and drops picked up (whole or in part) in this session, for the results.
var pickups: int = 0
var _last_take_usec: int = 0
## Something a request changed this tick (a selection shows in the state batch: not quiet).
var _changed: bool = false
## Remote frames handled this tick (each moves the acknowledgement in the next state batch).
var _frames: int = 0


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
		var chunks: Array[PackedByteArray] = st.sender.take(Config.NET_SNAPSHOT_CHUNKS_PER_TICK)
		for chunk: PackedByteArray in chunks:
			s.send_world(peer, chunk)
			snapshot_bytes_sent += chunk.size()
		if not chunks.is_empty():
			st.ticks += 1
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
	streams_done.append({"slot": st.slot, "chunks": st.snapshot.chunk_count(), "bytes": st.snapshot.bytes.size(),
		"ticks": st.ticks, "edit_position": st.edit_position, "catch_up_edits": catch_up})
	s.log_event("welcomed", "peer=%d slot=%d chunks=%d bytes=%d ticks=%d edit_position=%d catch_up_edits=%d stream_ms=%d" % [
		st.peer, st.slot, st.snapshot.chunk_count(), st.snapshot.bytes.size(), st.ticks, st.edit_position, catch_up,
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
	w.generator_md5 = s.generator_hash.hex_decode()
	for slot: int in s.slots():
		w.players.append(s.members[slot].info())
	return w


# --- world edits -----------------------------------------------------------------------------

## The debug floor edit (bot "edit"): checks (EditLog.check), applies, logs and sends. Returns "" or
## why it was refused.
func edit(world_edit: EditLog.WorldEdit) -> String:
	var why: String = EditLog.check(s.world.data, world_edit)
	if not why.is_empty():
		s.log_event("edit_refused", "%s: %s" % [world_edit.describe(), why])
		return why
	apply_world_edit(world_edit)
	return ""


## Applies, logs and sends an edit the rules already allowed (debug edit, or a request's outcome).
func apply_world_edit(world_edit: EditLog.WorldEdit) -> void:
	s.world.apply_edit(world_edit)
	var payload: PackedByteArray = EditLog.encode_one(world_edit, s.edit_log.size())
	s.edit_log.append(world_edit)
	for peer: int in remote_peers():
		s.send_edit(peer, payload)
	s.log_event("edit", "%s index=%d world=%s" % [world_edit.describe(), s.edit_log.size() - 1,
		s.world.data.content_hash().left(12)])


# --- requests (M2b) --------------------------------------------------------------------------

## Runs one input frame of member `m`: its request first (checked at this frame's position), then the
## step. The frame's `anim` is decided here, whatever the sender resolved.
func run_frame(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	frame.anim = -1
	frame.item = &""
	if m.gate != null:
		_frames += 1
	if frame.op != NetProtocol.Op.NONE:
		s.request_ticks = 3
	if frame.op == NetProtocol.Op.USE:
		var why: Array[String] = []
		var anim: int = WorldItems.use_action(p.sim_position, p.inventory, frame.slot, frame.cell, why)
		if anim >= 0 and p.to_sim().busy_next():
			anim = -1
			why.append("busy")
		if anim >= 0:
			frame.anim = anim
			frame.item = p.inventory.stack_at(frame.slot).id
			m.count_done("use")
		else:
			_refuse_op(m, frame, why[0])
	elif frame.op != NetProtocol.Op.NONE:
		_run_op(m, frame)
	p.step_frame(frame, Config.NET_TICK)
	if p.action_anim >= 0 and p.action_tick == 0:
		m.count_action(p.action_anim)
		s.log_event("action", "slot=%d item=%s action=%s target=%d,%d" % [m.slot, p.action_item,
			RigData.ANIM_NAMES[p.action_anim], p.action_cell.x, p.action_cell.y])


## Select, pick up, drop, give: rate, then the rules (items/world_items.gd).
func _run_op(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	if not m.take_op():
		_refuse_op(m, frame, "rate")
		return
	var p: Player = m.player
	var o: WorldItems.Outcome = null
	match frame.op:
		NetProtocol.Op.SELECT:
			if frame.slot < 0 or frame.slot >= p.inventory.hotbar_size:
				_refuse_op(m, frame, WorldItems.WHY_BAD_SLOT)
				return
			p.inventory.select(frame.slot)
			m.count_done("select")
			m.inventory_dirty = true
			_changed = true
			return
		NetProtocol.Op.PICKUP:
			o = WorldItems.pickup(s.world.data, p.sim_position, m.class_id, p.inventory, frame.cell)
		NetProtocol.Op.DROP:
			var slot: int = frame.slot if frame.slot >= 0 else p.inventory.selected
			o = WorldItems.drop(s.world.data, p.sim_position, p.inventory, slot, frame.count, frame.cell)
		NetProtocol.Op.GIVE:
			if m.peer_id != 1 and not s.give_allowed:
				_refuse_op(m, frame, "give off")
				return
			o = WorldItems.give(p.inventory, frame.item_index, frame.count, frame.grade)
	if o == null:
		_refuse_op(m, frame, "unknown request")
		return
	if not o.ok():
		_refuse_op(m, frame, o.why)
		return
	for e: EditLog.WorldEdit in o.edits:
		apply_world_edit(e)
	var op_name: String = NetProtocol.OP_NAMES[frame.op]
	m.count_done(op_name)
	m.inventory_dirty = true
	_changed = true
	if frame.op == NetProtocol.Op.PICKUP:
		pickups += 1
	s.log_event(op_name, "slot=%d item=%s count=%d grade=%s at=%d,%d" % [m.slot, o.item, o.count,
		ItemDB.GRADE_NAMES[clampi(o.grade, 0, 2)], frame.cell.x, frame.cell.y])


func _refuse_op(m: NetMember, frame: NetProtocol.InputFrame, why: String) -> void:
	m.count_refused(why)
	s.log_event("request_refused", "slot=%d %s: %s" % [m.slot, frame.describe_op(), why])


## The host's own frame for this tick (keys / mouse / bot) with one waiting local request attached.
func _local_frame(action: NetBot.Action) -> NetProtocol.InputFrame:
	var p: Player = s.local.player
	var f: NetProtocol.InputFrame = p.make_frame(action.dir, action.mouse, action.aiming, action.use_pressed,
		action.use_held)
	attach_local_op(s, p, f, action)
	return f


## Puts a request on frame `f` unless it already carries a use: the bot's request of this tick at
## once (a script that spams requests really sends them every frame), else the next waiting one from
## the keys, paced like the host's rate (NetSession.take_local_token) so key presses and --give are
## not refused as "rate". PICKUP / DROP aim at the target tile; a DROP without a slot drops the
## selected one. A client applies a hotbar selection at once (predicted).
static func attach_local_op(session: NetSession, p: Player, f: NetProtocol.InputFrame, action: NetBot.Action) -> void:
	var q: NetProtocol.InputFrame = null
	if action.op != null:
		if f.op != NetProtocol.Op.NONE:
			session.queue_op(action.op)
			return
		q = action.op
		if session.role == NetSession.Role.CLIENT and q.op == NetProtocol.Op.SELECT:
			p.inventory.select(q.slot)
	elif f.op == NetProtocol.Op.NONE and not session.local_ops.is_empty() and session.take_local_token():
		q = session.local_ops.pop_front()
	if q == null:
		return
	f.op = q.op
	f.slot = q.slot
	f.count = q.count
	f.item_index = q.item_index
	f.grade = q.grade
	f.cell = q.cell
	if q.op == NetProtocol.Op.PICKUP or q.op == NetProtocol.Op.DROP:
		f.cell = p.aim_cell
	if q.op == NetProtocol.Op.DROP and q.slot < 0:
		f.slot = p.inventory.selected


## Each member whose inventory changed gets it (its own only), with its last handled frame.
func _send_inventories() -> void:
	var peers: Array[int] = remote_peers()
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if not m.inventory_dirty or m.gate == null or not peers.has(m.peer_id):
			continue
		m.inventory_dirty = false
		s.send_inventory(m.peer_id, NetProtocol.encode_inventory(m.player.inventory, m.gate.last_seq))


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
	_changed = false
	for slot: int in s.slots():
		s.members[slot].refill_ops()
	# Every player runs the same frame rule (run_frame): the facing follows the look or the direction
	# (Movement.facing_for), requests are checked at the frame's position.
	run_frame(s.local, _local_frame(action))
	# Real time since the last tick refills the input gates (a hitch's lost ticks included).
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_ticks: float = InputGate.ticks_between(_last_take_usec, now_usec)
	_last_take_usec = now_usec
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if m.gate == null:
			continue
		for frame: NetProtocol.InputFrame in m.gate.take(elapsed_ticks):
			run_frame(m, frame)
	# A request's change, or any client frame handled (its acknowledgement goes out): not quiet.
	if _changed or _frames > 0:
		broadcast.note_activity(s.tick)
	_frames = 0
	for slot: int in s.members:
		var pl: Player = s.members[slot].player
		if pl.walking or pl.action_anim >= 0:
			broadcast.note_activity(s.tick)  # before this tick's batch decision
			break
	if action.edit != null:
		edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, action.edit.cell, action.edit.terrain))
	if not action.mark.is_empty():
		s.bots.mark(action.mark)
	if action.leave:
		s.log_event("bot", "leave is for clients; the host ignores it")
	if action.stall_ms > 0:
		s.stall_after_tick(action.stall_ms)
	_drop_silent_peers(now)
	_pump_streams()
	if s.tick % (Config.NET_TICK_RATE / Config.NET_STATE_HZ) == 0:
		_send_states()
	_send_inventories()
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
