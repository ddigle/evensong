class_name NetSession
extends Node
## The M1 network session: ● host-authoritative co-op (game-concept §13), 2 players first, built
## for ● 9 (Config.MAX_PLAYERS, counted by the host). Node "Net" in main.tscn, at the same path on
## every peer, carries every RPC (payloads: net/protocol.gd). Offline (no --host / --join) it
## does nothing.
##
## Host (--host[=port], player 1 = slot 0): listens, admits joiners (Roster: cap, lowest free spawn
## slot, class), owns the world (WorldData + EditLog) and every player's movement. A joiner gets the
## world itself (WorldSnapshot: all six layers, compressed, in bounded reliable chunks over as many
## ticks as it takes), then the welcome (slot, players, edit log position), then the edits made
## since the snapshot. The host steps its own player from its keys each tick and each client's
## player from that client's input frames (InputGate: order, rate limit by real time, smoothing;
## the facing is derived from the direction), and sends all player states every 3rd tick (20 Hz,
## provisional) while anything changes, then one reliable keyframe, then nothing (quiet).
## Client (--join=addr[:port]): connects, says hello (class), collects the world chunks and on the
## welcome builds its world from them (not from its own generator: the seed and the generator hash
## are only compared and printed), checks the received world's hash, creates the players. Its own
## player is predicted (Prediction: steps at once, replays unacknowledged frames on each host
## state); the other players are drawn 100 ms behind the host (Interpolation). The same Movement
## rules run on both sides.
##
## Files: this node holds what both roles share (connection, players, ending, logging) and the RPC
## table. Each @rpc receiver here only hands the payload to its flow, and the flows send through the
## send_* helpers here: net/session_host.gd = host flow, net/session_client.gd = client flow,
## net/session_bots.gd = bots and test hooks (--bot, --net-out results, go / done / finish).
## Machine-readable log lines start with "EVENSONG_NET".

signal local_player_ready(player: Player)
## The session is over: finished, left, refused, failed, lost the host, timed out. `code` is the
## exit code a test instance quits with (EXIT_*).
signal ended(reason: String, code: int)

enum Role { OFFLINE, HOST, CLIENT }
const ROLE_NAMES: PackedStringArray = ["offline", "host", "client"]

const EXIT_OK: int = 0
const EXIT_REFUSED: int = 3
const EXIT_FAILED: int = 4
## The world received from the host failed its checks (sizes, md5 of the chunks, world hash).
const EXIT_WORLD_MISMATCH: int = 5
const EXIT_TIMEOUT: int = 6


var role: Role = Role.OFFLINE
var world: GameWorld
var options: CliOptions
var transport: NetTransport
## Players by slot.
var members: Dictionary[int, NetMember] = {}
var local: NetMember
var edit_log: EditLog = EditLog.new()
var tick: int = 0
var link: LinkSim = LinkSim.new()
var stats: NetStats = NetStats.new()
## Hash of the world this machine's generator makes from the session seed (no edits). The host sets
## it at start (its world is still the bare seed world then); a client only on the welcome, for the
## diagnostic (SessionClient compares it with the host's), and "" before that.
var generator_hash: String = ""
var active: bool = false
var over: bool = false
var end_reason: String = ""
var bad_messages: int = 0
var unknown_senders: int = 0
## Test only (bot "stall:<ms>"): milliseconds this process was blocked on purpose, in all.
var stalled_ms: int = 0

## The flows (net/session_host.gd, net/session_client.gd, net/session_bots.gd). host or client is
## null for the other role.
var host: SessionHost
var client: SessionClient
var bots: SessionBots

var _start_ms: int = 0
var _stall_ms: int = 0


func _init() -> void:
	bots = SessionBots.new(self)


func instance_name() -> String:
	if options != null and not options.net_name.is_empty():
		return options.net_name
	return ROLE_NAMES[role]


## Starts hosting or joining as `p_options` says (--host / --join).
func start(p_world: GameWorld, p_options: CliOptions) -> void:
	world = p_world
	options = p_options
	role = Role.HOST if options.host else Role.CLIENT
	_start_ms = Time.get_ticks_msec()
	generator_hash = world.data.content_hash() if role == Role.HOST else ""
	bots.setup(options.bot)
	if role == Role.CLIENT:
		link = LinkSim.new(options.net_lag, options.net_loss, hash(instance_name()))
		client = SessionClient.new(self)
	else:
		host = SessionHost.new(self)
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
		log_event("starting", "transport=%s port=%d max_players=%d seed=%d" % [transport.kind(), o.port,
			host.roster.max_players, world.data.world_seed])
		transport.host(multiplayer)
	else:
		log_event("starting", "transport=%s address=%s port=%d lag_ms=%d loss=%s" % [transport.kind(), o.address,
			o.port, link.lag_ms, link.loss_percent])
		transport.join(multiplayer)


func is_host() -> bool:
	return role == Role.HOST


func seconds_running() -> float:
	return (Time.get_ticks_msec() - _start_ms) / 1000.0


func local_class() -> String:
	return options.class_id if not options.class_id.is_empty() else Config.DEFAULT_CLASS


# --- connection ------------------------------------------------------------------------------

func _on_opened() -> void:
	if role == Role.HOST:
		host.on_opened()
	else:
		client.on_opened()


func _on_open_failed(reason: String) -> void:
	end_session("failed: %s" % reason, EXIT_FAILED)


func _on_peer_connected(peer_id: int) -> void:
	if role == Role.HOST and not over:
		host.on_peer_connected(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if role == Role.HOST:
		host.on_peer_disconnected(peer_id)


func _on_server_disconnected() -> void:
	if role == Role.CLIENT and not over:
		client.on_server_disconnected()


# --- ticks -----------------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if role == Role.OFFLINE or over:
		return
	var now: int = Time.get_ticks_msec()
	if options.net_timeout > 0.0 and now - _start_ms > int(options.net_timeout * 1000.0):
		end_session("timeout after %.0f s" % options.net_timeout, EXIT_TIMEOUT)
		return
	if role == Role.CLIENT and not client.before_tick(now, _start_ms):
		return
	if not active:
		return
	tick += 1
	var action: NetBot.Action = bots.local_action()
	if role == Role.HOST:
		host.tick(action, now)
	else:
		client.tick(action)
	_count_traffic()


func _process(_delta: float) -> void:
	if role == Role.CLIENT and active and not over:
		client.draw_others()
	if _stall_ms > 0:
		# Test only: a long frame outside the physics ticks. Godot then runs its catch-up physics ticks
		# first and polls the network after them (SceneTree.process), so the input frames a client
		# sent meanwhile reach the host's gates only after the tick that measured the lost time.
		var ms: int = _stall_ms
		_stall_ms = 0
		OS.delay_msec(ms)
		stalled_ms += ms


## Test only (bot "stall:<ms>"): block the process for `ms` in this frame's process step.
func stall_after_tick(ms: int) -> void:
	log_event("stall", "ms=%d tick=%d" % [ms, tick])
	_stall_ms += ms


## Traffic by situation: "<moving>/<players>", or "joining" while the host sends a joiner its world.
func _count_traffic() -> void:
	var moving: int = 0
	for slot: int in members:
		if members[slot].player.walking:
			moving += 1
	var key: String = "%d/%d" % [moving, members.size()]
	if host != null and host.joining_ticks > 0:
		host.joining_ticks -= 1
		key = "joining"
	stats.add(key, transport.pop_stats())


# --- RPC receivers (each hands over to its flow) ----------------------------------------------

## Host: a joiner introduces itself.
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_hello(payload: PackedByteArray) -> void:
	if role == Role.HOST:
		host.on_hello(multiplayer.get_remote_sender_id(), payload)


## Client: one chunk of the world snapshot (before the welcome).
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_world(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_world_chunk(payload)


## Client: admitted; the world is complete.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_welcome(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_welcome(payload)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_refused(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_refused(payload)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_joined(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_joined(payload)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_left(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_left(payload)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_edit(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_edit(payload)


## Host: a client's input frames.
@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_input(payload: PackedByteArray) -> void:
	if role == Role.HOST:
		host.on_input(multiplayer.get_remote_sender_id(), payload)


## Client: a state batch (unreliable; may be late, lost or, through the link simulation, held back).
@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_state(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_state(payload)


## Client: the reliable state after everything went quiet.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_keyframe(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_keyframe(payload)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_go() -> void:
	if role == Role.CLIENT:
		bots.on_go()


## Host: a client's bot finished its script.
@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_done() -> void:
	if role == Role.HOST:
		bots.on_done(multiplayer.get_remote_sender_id())


## Client: the host is done; settle, write the result, leave.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_finish() -> void:
	if role == Role.CLIENT:
		bots.on_finish()


# --- RPC senders (the flows call these) --------------------------------------------------------

func send_hello(payload: PackedByteArray) -> void:
	_rpc_hello.rpc_id(1, payload)


func send_world(peer: int, payload: PackedByteArray) -> void:
	_rpc_world.rpc_id(peer, payload)


func send_welcome(peer: int, payload: PackedByteArray) -> void:
	_rpc_welcome.rpc_id(peer, payload)


func send_refused(peer: int, payload: PackedByteArray) -> void:
	_rpc_refused.rpc_id(peer, payload)


func send_joined(peer: int, payload: PackedByteArray) -> void:
	_rpc_joined.rpc_id(peer, payload)


func send_left(peer: int, payload: PackedByteArray) -> void:
	_rpc_left.rpc_id(peer, payload)


func send_edit(peer: int, payload: PackedByteArray) -> void:
	_rpc_edit.rpc_id(peer, payload)


## Client -> host input (through the link simulation, so it may run later; dropped once over).
func send_input(payload: PackedByteArray) -> void:
	if active and not over:
		_rpc_input.rpc_id(1, payload)


func send_state(peer: int, payload: PackedByteArray) -> void:
	_rpc_state.rpc_id(peer, payload)


func send_keyframe(peer: int, payload: PackedByteArray) -> void:
	_rpc_keyframe.rpc_id(peer, payload)


func send_go(peer: int) -> void:
	_rpc_go.rpc_id(peer)


func send_done() -> void:
	_rpc_done.rpc_id(1)


func send_finish(peer: int) -> void:
	_rpc_finish.rpc_id(peer)


# --- ending ----------------------------------------------------------------------------------

func end_session(reason: String, code: int) -> void:
	if over:
		return
	over = true
	end_reason = reason
	if role == Role.CLIENT or not bots.finishing:
		bots.write_result(reason)
	log_event("ended", "reason=\"%s\" code=%d ticks=%d" % [reason, code, tick])
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
	for slot: int in slots():
		if members[slot] != local:
			remove_member(slot)
	if local != null:
		local.player.local_input = true
	log_event("offline", "playing on alone")
	role = Role.OFFLINE


func _exit_tree() -> void:
	if role != Role.OFFLINE and not over:
		over = true
		close()


# --- players ---------------------------------------------------------------------------------

func add_member(slot: int, peer_id: int, class_id: String, pos: Vector2, facing: int) -> NetMember:
	var m: NetMember = NetMember.create(world.data, world.entities, slot, peer_id, class_id, pos, facing)
	members[slot] = m
	return m


func remove_member(slot: int) -> void:
	if not members.has(slot):
		return
	var m: NetMember = members[slot]
	members.erase(slot)
	m.remove_player()


func slots() -> Array[int]:
	var out: Array[int] = []
	out.assign(members.keys())
	out.sort()
	return out


# --- results and logs ------------------------------------------------------------------------

func positions_hash() -> String:
	return SessionReport.positions_hash(members)


func result(reason: String) -> Dictionary:
	return SessionReport.build(self, reason)


func log_event(event: String, text: String) -> void:
	print("EVENSONG_NET %s %s %s" % [instance_name(), event, text])
