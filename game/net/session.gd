class_name NetSession
extends Node
## The M1 network session: ● host-authoritative co-op (game-concept §13), 2 players first, built
## for ● 9 (Config.MAX_PLAYERS, counted by the host). Node "Net" in main.tscn, at the same path on
## every peer, carries every RPC (payloads: net/protocol.gd). Offline (no --host / --join) it
## does nothing.
##
## Host (--host[=port], player 1 = slot 0): listens, admits joiners (Roster: cap, lowest free spawn
## slot, class), owns the world (seed + EditLog) and every player's movement. It steps its own
## player from its keys each tick and each client's player from that client's input frames
## (InputGate: order, rate limit, smoothing), and sends all player states every 3rd tick (20 Hz,
## provisional) while anything changes, then one reliable keyframe, then nothing (quiet).
## Client (--join=addr[:port]): connects, says hello (class), gets the welcome (slot, seed, edit
## log, players), rebuilds the world and checks its hash against the host's. Its own player is
## predicted (Prediction: steps at once, replays unacknowledged frames on each host state); the
## other players are drawn 100 ms behind the host (Interpolation). The same Movement.step runs on
## both sides.
##
## Test hooks (CliOptions "session test flags"): --bot drives the local player, --net-out writes a
## result JSON and marker files and quits when the session ends, the host finishes the session
## when the expected clients are done. Machine-readable log lines start with "EVENSONG_NET".

signal local_player_ready(player: Player)
## The session is over: finished, left, refused, failed, lost the host, timed out. `code` is the
## exit code a test instance quits with (EXIT_*).
signal ended(reason: String, code: int)

enum Role { OFFLINE, HOST, CLIENT }
const ROLE_NAMES: PackedStringArray = ["offline", "host", "client"]

const EXIT_OK: int = 0
const EXIT_REFUSED: int = 3
const EXIT_FAILED: int = 4
const EXIT_WORLD_MISMATCH: int = 5
const EXIT_TIMEOUT: int = 6
## Ticks a client lets pass after "finish" before it writes its result (the other players' drawn
## positions reach the last state).
const FINISH_SETTLE_TICKS: int = 12
## Ticks a leaving client keeps its connection so its last reliable messages go out.
const LEAVE_FLUSH_TICKS: int = 10
const HOST_DRAIN_SEC: float = 5.0


var role: Role = Role.OFFLINE
var world: GameWorld
var options: CliOptions
var transport: NetTransport
var roster: Roster
## Players by slot.
var members: Dictionary[int, NetMember] = {}
var local: NetMember
var edit_log: EditLog = EditLog.new()
var tick: int = 0
var bot: NetBot
var bots_started: bool = false
var prediction: Prediction
var clock: Interpolation.RemoteClock = Interpolation.RemoteClock.new()
var link: LinkSim = LinkSim.new()
var stats: NetStats = NetStats.new()
## World hash of the seed alone (before any edit): a late joiner's world must differ from it.
var pristine_hash: String = ""
var active: bool = false
var over: bool = false
var end_reason: String = ""

## Host: batch / keyframe / quiet decisions.
var broadcast: StateBroadcast = StateBroadcast.new()
var bad_messages: int = 0
var stale_batches: int = 0
## Client: frames that drew a walking player, and how many of them had no newer state to move to.
var interp_samples: int = 0
var interp_starved: int = 0
var unknown_senders: int = 0
var refusals: Dictionary[String, int] = {}
var refused_reason: String = ""

var _start_ms: int = 0
var _connected_ms: Dictionary[int, int] = {}
var _refused_ms: Dictionary[int, int] = {}
var _done_peers: Array[int] = []
var _finishing: bool = false
var _drain_until_ms: int = 0
var _finish_wait: int = -1
var _leave_wait: int = -1
var _sent_done: bool = false
var _last_state_tick: int = -1


func instance_name() -> String:
	if options != null and not options.net_name.is_empty():
		return options.net_name
	return ROLE_NAMES[role]


func interp_delay_ticks() -> float:
	return Config.NET_INTERP_DELAY_MS * Config.NET_TICK_RATE / 1000.0


## Starts hosting or joining as `p_options` says (--host / --join).
func start(p_world: GameWorld, p_options: CliOptions) -> void:
	world = p_world
	options = p_options
	role = Role.HOST if options.host else Role.CLIENT
	_start_ms = Time.get_ticks_msec()
	pristine_hash = world.data.content_hash()
	if not options.bot.is_empty():
		bot = NetBot.new()
		bot.parse(options.bot)
	if role == Role.CLIENT:
		link = LinkSim.new(options.net_lag, options.net_loss, hash(instance_name()))
	transport = Transports.make(options.transport)
	var o: NetTransport.Options = NetTransport.Options.new()
	o.port = options.port
	o.address = options.join_address
	transport.configure(o)
	transport.opened.connect(_on_opened)
	transport.open_failed.connect(_on_open_failed)
	var scene_mp: SceneMultiplayer = multiplayer as SceneMultiplayer
	if scene_mp != null:
		scene_mp.server_relay = false  # clients only ever talk to the host (also the Steam default)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if role == Role.HOST:
		roster = Roster.new(options.max_players)
		_log("starting", "transport=%s port=%d max_players=%d seed=%d" % [transport.kind(), o.port,
			roster.max_players, world.data.world_seed])
		transport.host(multiplayer)
	else:
		_log("starting", "transport=%s address=%s port=%d lag_ms=%d loss=%s" % [transport.kind(), o.address,
			o.port, link.lag_ms, link.loss_percent])
		transport.join(multiplayer)


func is_host() -> bool:
	return role == Role.HOST


# --- connection ------------------------------------------------------------------------------

func _on_opened() -> void:
	if role == Role.HOST:
		var slot: int = roster.admit(1, local_class())
		local = _add_member(slot, 1, local_class(), world.spawn_point(slot), Config.SPAWN_FACING)
		active = true
		_log("hosting", "port=%d slot=%d class=%s" % [options.port, slot, local.class_id])
		local_player_ready.emit(local.player)
		_mark("ready")
		if options.net_start <= 0:
			_start_bots()
	else:
		_log("connected", "to=%s:%d" % [options.join_address, options.port])
		_rpc_hello.rpc_id(1, NetProtocol.encode_hello(NetProtocol.class_index(local_class())))


func _on_open_failed(reason: String) -> void:
	_end("failed: %s" % reason, EXIT_FAILED)


func _on_peer_connected(peer_id: int) -> void:
	if role == Role.HOST and not over:
		_connected_ms[peer_id] = Time.get_ticks_msec()


func _on_peer_disconnected(peer_id: int) -> void:
	if role != Role.HOST:
		return
	_connected_ms.erase(peer_id)
	_refused_ms.erase(peer_id)
	if not roster.has(peer_id):
		return
	var slot: int = roster.release(peer_id)
	broadcast.note_activity(tick)
	if not _done_peers.has(peer_id):
		_done_peers.append(peer_id)  # a player who left will not finish a bot any more
	_remove_member(slot)
	if not _finishing:  # after "finish" the clients' lists are frozen and they are leaving too
		var payload: PackedByteArray = PackedByteArray([slot])
		for peer: int in _remote_peers():
			_rpc_left.rpc_id(peer, payload)
	_log("left", "peer=%d slot=%d players=%d" % [peer_id, slot, roster.count()])


func _on_server_disconnected() -> void:
	if role != Role.CLIENT or over:
		return
	if _finish_wait >= 0 or _leave_wait >= 0:
		return
	_end("lost the host", EXIT_FAILED)


## Host: a joiner introduces itself.
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_hello(payload: PackedByteArray) -> void:
	if role != Role.HOST or not active or over:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if roster.has(peer_id) or _refused_ms.has(peer_id):
		bad_messages += 1
		return
	_connected_ms.erase(peer_id)
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
	var m: NetMember = _add_member(slot, peer_id, class_id, world.spawn_point(slot), Config.SPAWN_FACING)
	m.gate = InputGate.new()
	broadcast.note_activity(tick)
	_rpc_welcome.rpc_id(peer_id, NetProtocol.encode_welcome(_welcome_for(slot)))
	var joined: PackedByteArray = NetProtocol.encode_info(m.info())
	for peer: int in _remote_peers():
		if peer != peer_id:
			_rpc_joined.rpc_id(peer, joined)
	_log("joined", "peer=%d slot=%d class=%s players=%d" % [peer_id, slot, class_id, roster.count()])
	if not bots_started and options.net_start > 0 and _remote_peers().size() >= options.net_start:
		_start_bots()


func _refuse(peer_id: int, reason: NetProtocol.Refusal) -> void:
	var name: String = NetProtocol.REFUSAL_NAMES[reason]
	var seen: int = refusals.get(name, 0)
	refusals[name] = seen + 1
	_refused_ms[peer_id] = Time.get_ticks_msec()
	# The refused client disconnects itself after reading this (disconnect_peer() here would drop
	# the message unsent); the host only cuts it off after NET_REFUSE_GRACE_SEC.
	_rpc_refused.rpc_id(peer_id, NetProtocol.encode_refusal(reason))
	_log("refused", "peer=%d reason=%s players=%d" % [peer_id, name, roster.count()])


func _welcome_for(slot: int) -> NetProtocol.Welcome:
	var w: NetProtocol.Welcome = NetProtocol.Welcome.new()
	w.slot = slot
	w.max_players = roster.max_players
	w.world_seed = world.data.world_seed
	w.map_size = world.data.size
	w.world_md5 = world.data.content_hash().hex_decode()
	w.tick = tick
	w.bots_started = bots_started
	w.edits = edit_log
	for s: int in _slots():
		w.players.append(members[s].info())
	return w


## Client: admitted. Rebuild the world from seed + edit log, check it, create the players.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_welcome(payload: PackedByteArray) -> void:
	if role != Role.CLIENT or local != null or over:
		return
	var w: NetProtocol.Welcome = NetProtocol.decode_welcome(payload)
	if not w.ok or w.version != NetProtocol.VERSION:
		_end("failed: bad welcome", EXIT_FAILED)
		return
	var t0: int = Time.get_ticks_usec()
	if world.data.world_seed != w.world_seed or world.data.size != w.map_size:
		world.generate(w.world_seed, w.map_size)
	pristine_hash = world.data.content_hash()
	for edit: EditLog.WorldEdit in w.edits.edits:
		if world.apply_edit(edit):
			edit_log.append(edit)
	var world_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var got: String = world.data.content_hash()
	if got != w.world_md5.hex_encode():
		_log("world_mismatch", "got=%s host=%s" % [got, w.world_md5.hex_encode()])
		_end("world mismatch", EXIT_WORLD_MISMATCH)
		return
	for info: NetProtocol.PlayerInfo in w.players:
		var m: NetMember = _add_member(info.state.slot, 0, NetProtocol.class_name_of(info.class_index), info.state.pos,
			info.state.facing)
		if info.state.slot == w.slot:
			local = m
		else:
			m.interp = Interpolation.new()
			m.interp.push(w.tick, info.state)
	if local == null:
		_end("failed: welcome without my player", EXIT_FAILED)
		return
	prediction = Prediction.new()
	var me: NetProtocol.PlayerState = local.state()
	prediction.setup(world.data, me.pos, me.facing, 0)
	clock.observe(w.tick, Interpolation.RemoteClock.now_ticks())
	_last_state_tick = w.tick
	active = true
	_log("welcome", "slot=%d class=%s players=%d max=%d seed=%d edits=%d world=%s world_ms=%.1f" % [w.slot,
		local.class_id, members.size(), w.max_players, w.world_seed, edit_log.size(), got.left(12), world_ms])
	local_player_ready.emit(local.player)
	_mark("welcome")
	if w.bots_started:
		_start_bots()


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_refused(payload: PackedByteArray) -> void:
	if role != Role.CLIENT or over:
		return
	refused_reason = NetProtocol.decode_refusal(payload)
	_end("refused: %s" % refused_reason, EXIT_REFUSED)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_joined(payload: PackedByteArray) -> void:
	if role != Role.CLIENT or not active or _finish_wait >= 0:
		return
	var info: NetProtocol.PlayerInfo = NetProtocol.decode_info(payload)
	if info == null or payload.size() != NetProtocol.INFO_SIZE or members.has(info.state.slot):
		bad_messages += 1
		return
	var m: NetMember = _add_member(info.state.slot, 0, NetProtocol.class_name_of(info.class_index), info.state.pos,
		info.state.facing)
	m.interp = Interpolation.new()
	m.interp.push(maxi(_last_state_tick, 0), info.state)
	_log("joined", "slot=%d class=%s players=%d" % [m.slot, m.class_id, members.size()])


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_left(payload: PackedByteArray) -> void:
	# After "finish" the player list is frozen: clients that already left must stay in the result.
	if role != Role.CLIENT or not active or _finish_wait >= 0:
		return
	if payload.size() != 1 or not members.has(payload[0]) or members[payload[0]] == local:
		bad_messages += 1
		return
	_remove_member(payload[0])
	_log("left", "slot=%d players=%d" % [payload[0], members.size()])


# --- world edits -----------------------------------------------------------------------------

## Host: checks, applies, logs and sends a world edit. Returns "" or why it was refused.
func host_edit(edit: EditLog.WorldEdit) -> String:
	if role != Role.HOST:
		return "only the host edits the world"
	var why: String = EditLog.check(world.data, edit)
	if not why.is_empty():
		_log("edit_refused", "%s: %s" % [edit.describe(), why])
		return why
	world.apply_edit(edit)
	var payload: PackedByteArray = EditLog.encode_one(edit, edit_log.size())
	edit_log.append(edit)
	for peer: int in _remote_peers():
		_rpc_edit.rpc_id(peer, payload)
	_log("edit", "%s index=%d world=%s" % [edit.describe(), edit_log.size() - 1, world.data.content_hash().left(12)])
	return ""


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_edit(payload: PackedByteArray) -> void:
	if role != Role.CLIENT or not active:
		return
	var decoded: Array = EditLog.decode_one(payload)
	var index: int = decoded[0]
	if index < 0:
		bad_messages += 1
		return
	var edit: EditLog.WorldEdit = decoded[1]
	if index != edit_log.size():
		bad_messages += 1
	if world.apply_edit(edit):
		edit_log.append(edit)
	_log("edit", "%s index=%d world=%s" % [edit.describe(), index, world.data.content_hash().left(12)])


# --- movement --------------------------------------------------------------------------------

## Host: a client's input frames.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_input(payload: PackedByteArray) -> void:
	if role != Role.HOST or over:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	var slot: int = roster.slot_of(peer_id)
	if slot < 0 or not members.has(slot) or members[slot].gate == null:
		unknown_senders += 1
		return
	members[slot].gate.receive(NetProtocol.decode_inputs(payload))


## Client: a state batch (unreliable; may be late, lost or, through the link simulation, held back).
@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_state(payload: PackedByteArray) -> void:
	if role != Role.CLIENT or not active:
		return
	link.pass_through(_apply_states.bind(payload), Time.get_ticks_msec())


## Client: the reliable state after everything went quiet.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_keyframe(payload: PackedByteArray) -> void:
	if role != Role.CLIENT or not active:
		return
	_apply_states(payload)


func _apply_states(payload: PackedByteArray) -> void:
	if not active or over:
		return
	var batch: NetProtocol.StateBatch = NetProtocol.decode_states(payload)
	if not batch.ok:
		bad_messages += 1
		return
	if batch.tick <= _last_state_tick:
		stale_batches += 1
		return
	_last_state_tick = batch.tick
	clock.observe(batch.tick, Interpolation.RemoteClock.now_ticks())
	for s: NetProtocol.PlayerState in batch.states:
		if s.slot == local.slot:
			prediction.reconcile(s)
			local.player.show_state(prediction.pos, prediction.facing, prediction.walking)
		elif members.has(s.slot) and members[s.slot].interp != null:
			members[s.slot].interp.push(batch.tick, s)


func _send_input(payload: PackedByteArray) -> void:
	if active and not over:
		_rpc_input.rpc_id(1, payload)


func _physics_process(_delta: float) -> void:
	if role == Role.OFFLINE or over:
		return
	var now: int = Time.get_ticks_msec()
	if options.net_timeout > 0.0 and now - _start_ms > int(options.net_timeout * 1000.0):
		_end("timeout after %.0f s" % options.net_timeout, EXIT_TIMEOUT)
		return
	if role == Role.CLIENT:
		link.poll(now)
		if not active and now - _start_ms > int(Config.NET_CONNECT_TIMEOUT_SEC * 1000.0):
			_end("failed: not admitted within %.0f s" % Config.NET_CONNECT_TIMEOUT_SEC, EXIT_FAILED)
			return
	if not active:
		return
	tick += 1
	var action: NetBot.Action = _local_action()
	if role == Role.HOST:
		_host_tick(action, now)
	else:
		_client_tick(action)
	_count_traffic()


func _process(_delta: float) -> void:
	if role != Role.CLIENT or not active or over:
		return
	var t: float = clock.host_tick_at(Interpolation.RemoteClock.now_ticks()) - interp_delay_ticks()
	for slot: int in members:
		var m: NetMember = members[slot]
		if m.interp == null:
			continue
		var newest: Interpolation.Snap = m.interp.latest()
		if newest != null and newest.walking:
			interp_samples += 1
			if t > newest.tick:
				interp_starved += 1  # drawing past the newest state of a walking player: buffer ran dry
		var s: Interpolation.Snap = m.interp.sample(t)
		if s != null:
			m.player.show_state(s.pos, s.facing, s.walking)


func _local_action() -> NetBot.Action:
	if bot != null:
		if bots_started:
			return bot.step()
		return NetBot.Action.new()
	var a: NetBot.Action = NetBot.Action.new()
	a.dir = Player.read_input()
	return a


func _host_tick(action: NetBot.Action, now: int) -> void:
	local.player.apply_frame(action.dir, Movement.facing_for(action.dir, local.player.facing), Config.NET_TICK)
	for slot: int in _slots():
		var m: NetMember = members[slot]
		if m.gate == null:
			continue
		for frame: NetProtocol.InputFrame in m.gate.take():
			m.player.apply_frame(frame.dir, frame.facing, Config.NET_TICK)
	for slot: int in members:
		if members[slot].player.walking:
			broadcast.note_activity(tick)  # before this tick's batch decision
			break
	if action.edit != null:
		host_edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, action.edit.cell, action.edit.terrain))
	if not action.mark.is_empty():
		_mark(action.mark)
	if action.leave:
		_log("bot", "leave is for clients; the host ignores it")
	_drop_silent_peers(now)
	if tick % (Config.NET_TICK_RATE / Config.NET_STATE_HZ) == 0:
		_send_states()
	if _finishing:
		if roster.count() <= 1 or now >= _drain_until_ms:
			_end("finished", EXIT_OK)
	elif _ready_to_finish():
		_host_finish(now)


## Host: one state batch for everybody while something changed, a reliable keyframe once it stops.
func _send_states() -> void:
	var states: Array[NetProtocol.PlayerState] = []
	for slot: int in _slots():
		states.append(members[slot].state())
	match broadcast.decide(tick, states):
		StateBroadcast.Send.BATCH:
			for peer: int in _remote_peers():
				_rpc_state.rpc_id(peer, broadcast.payload)
		StateBroadcast.Send.KEYFRAME:
			for peer: int in _remote_peers():
				_rpc_keyframe.rpc_id(peer, broadcast.payload)


func _client_tick(action: NetBot.Action) -> void:
	var frame: NetProtocol.InputFrame = prediction.step(action.dir)
	local.player.show_state(prediction.pos, prediction.facing, prediction.walking)
	var interval: int = Config.NET_TICK_RATE / Config.NET_INPUT_HZ
	# Send every 2nd tick while frames are unacknowledged, and at once when a move starts.
	if prediction.has_unacked() and (tick % interval == 0 or (frame != null and prediction.pending.size() == 1)):
		link.pass_through(_send_input.bind(NetProtocol.encode_inputs(prediction.frames_to_send())),
			Time.get_ticks_msec())
	if action.edit != null:
		_log("bot", "edit ignored: only the host edits the world")
	if not action.mark.is_empty():
		_mark(action.mark)
	# Done = the bot finished and the host has handled every frame (its final state includes them).
	if bot != null and bots_started and bot.finished and not _sent_done and not prediction.has_unacked():
		_sent_done = true
		_rpc_done.rpc_id(1)
	if action.leave and _leave_wait < 0:
		_leave_wait = LEAVE_FLUSH_TICKS
		_log("leaving", "slot=%d" % local.slot)
	if _leave_wait >= 0:
		_leave_wait -= 1
		if _leave_wait < 0:
			_end("left", EXIT_OK)
			return
	if _finish_wait >= 0:
		_finish_wait -= 1
		if _finish_wait < 0:
			_end("finished", EXIT_OK)


func _count_traffic() -> void:
	var moving: int = 0
	for slot: int in members:
		if members[slot].player.walking:
			moving += 1
	stats.add("%d/%d" % [moving, members.size()], transport.pop_stats())


# --- bots and finishing (tests) --------------------------------------------------------------

func _start_bots() -> void:
	if bots_started:
		return
	bots_started = true
	if role == Role.HOST:
		for peer: int in _remote_peers():
			_rpc_go.rpc_id(peer)
	_log("go", "players=%d" % members.size())


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_go() -> void:
	if role == Role.CLIENT and active:
		_start_bots()


## Host: a client's bot finished its script.
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_done() -> void:
	if role != Role.HOST:
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if roster.has(peer_id) and not _done_peers.has(peer_id):
		_done_peers.append(peer_id)
		_log("done", "peer=%d slot=%d done=%d" % [peer_id, roster.slot_of(peer_id), _done_peers.size()])


func _ready_to_finish() -> bool:
	if options.net_expect < 0 or not bots_started or broadcast.dirty:
		return false
	if bot != null and not bot.finished:
		return false
	var refused_total: int = 0
	for key: String in refusals:
		refused_total += refusals[key]
	if _done_peers.size() < options.net_expect or refused_total < options.net_expect_refused:
		return false
	for slot: int in members:
		if members[slot].gate != null and not members[slot].gate.waiting.is_empty():
			return false
	return _connected_ms.is_empty() and _refused_ms.is_empty()


func _host_finish(now: int) -> void:
	_finishing = true
	_drain_until_ms = now + int(HOST_DRAIN_SEC * 1000.0)
	for peer: int in _remote_peers():
		_rpc_finish.rpc_id(peer)
	_log("finish", "players=%d edits=%d world=%s" % [members.size(), edit_log.size(),
		world.data.content_hash().left(12)])
	_write_result("finished")


## Client: the host is done; settle, write the result, leave.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_finish() -> void:
	if role == Role.CLIENT and active and _finish_wait < 0:
		_finish_wait = FINISH_SETTLE_TICKS


func _drop_silent_peers(now: int) -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	for id: int in _connected_ms.keys():
		if now - _connected_ms[id] > int(Config.NET_HELLO_TIMEOUT_SEC * 1000.0):
			_connected_ms.erase(id)
			_log("dropped", "peer=%d reason=no_hello" % id)
			peer.disconnect_peer(id)
	for id: int in _refused_ms.keys():
		if now - _refused_ms[id] > int(Config.NET_REFUSE_GRACE_SEC * 1000.0):
			_refused_ms.erase(id)
			_log("dropped", "peer=%d reason=refused_still_connected" % id)
			peer.disconnect_peer(id)


# --- ending ----------------------------------------------------------------------------------

func _end(reason: String, code: int) -> void:
	if over:
		return
	over = true
	end_reason = reason
	if role == Role.CLIENT or not _finishing:
		_write_result(reason)
	_log("ended", "reason=\"%s\" code=%d ticks=%d" % [reason, code, tick])
	# Not inside an RPC handler (SceneMultiplayer is polling then): close on the next idle step.
	_close_and_emit.call_deferred(reason, code)


func _close_and_emit(reason: String, code: int) -> void:
	close()
	ended.emit(reason, code)


## Closes the connection (offline afterwards). Players stay where they are.
func close() -> void:
	active = false
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if transport != null:
		transport.close()
	link.clear()


## After losing the host without --net-out: keep playing alone (own player on the local keys,
## the other players removed).
func continue_offline() -> void:
	for slot: int in _slots():
		if members[slot] != local:
			_remove_member(slot)
	if local != null:
		local.player.local_input = true
	_log("offline", "playing on alone")
	role = Role.OFFLINE


func _exit_tree() -> void:
	if role != Role.OFFLINE and not over:
		over = true
		close()


# --- players ---------------------------------------------------------------------------------

func _add_member(slot: int, peer_id: int, class_id: String, pos: Vector2, facing: int) -> NetMember:
	var m: NetMember = NetMember.create(world.data, world.entities, slot, peer_id, class_id, pos, facing)
	members[slot] = m
	return m


func _remove_member(slot: int) -> void:
	if not members.has(slot):
		return
	var m: NetMember = members[slot]
	members.erase(slot)
	m.remove_player()


func _slots() -> Array[int]:
	var out: Array[int] = []
	out.assign(members.keys())
	out.sort()
	return out


## Host: admitted clients (not the host itself) a message can still reach.
func _remote_peers() -> Array[int]:
	var out: Array[int] = []
	for peer: int in roster.peers():
		if peer != 1 and transport.can_send_to(peer):
			out.append(peer)
	return out


func local_class() -> String:
	return options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS


# --- results (tests) -------------------------------------------------------------------------

func positions_hash() -> String:
	return SessionReport.positions_hash(members)


func result(reason: String) -> Dictionary:
	return SessionReport.build(self, reason)


func seconds_running() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


## Host: clients that finished their bot or left.
func done_count() -> int:
	return _done_peers.size()


func _write_result(reason: String) -> void:
	if options == null or options.net_out.is_empty():
		return
	if not SessionReport.write_json(options.net_out, instance_name(), result(reason)):
		printerr("EVENSONG_NET cannot write %s" % options.net_out.path_join(instance_name() + ".json"))


func _mark(marker: String) -> void:
	_log("mark", marker)
	if options != null and not options.net_out.is_empty():
		SessionReport.write_marker(options.net_out, instance_name(), marker, str(tick))


func _log(event: String, text: String) -> void:
	print("EVENSONG_NET %s %s %s" % [instance_name(), event, text])
