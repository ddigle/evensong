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
## M2b (items, actions, gatherables, drops): every player's input frame also carries its look (facing
## toward the mouse while aiming) and at most one request: use (start the held tool's body action
## toward the target tile), pick up (F), select a hotbar slot (Q / E), and the debug drop and give.
## The host checks each request when it handles that frame, at that frame's position (reach, target
## tile, item present, rate, net/session_host.gd + items/world_items.gd), and applies it: actions
## become part of the player's state (every batch carries each player's action and held item, so the
## others draw it), world changes (a gatherable picked, drops put down or picked up) go out as
## numbered edits like M1's, and the owner gets its inventory (it lives on the host, one per player;
## nobody else sees it). A client predicts its own action start and hotbar selection at once, like
## its movement, and the host's state wins. The world snapshot carries the gatherables (VEGETATION
## layer) and the drops, so a late joiner sees what was picked and what lies around.
##
## M3b (maps): the host has every map (`worlds`: the surface and the first dungeon, each a GameWorld
## with its own data and its own edit log, `log_for`) and every member is on one of them
## (NetMember.map_id). Going down or up is a TRAVEL request (F on the entrance / the exit stairs),
## checked like a pick up and applied by the host: the member moves to the other map's arrival point,
## and its client gets that map the way a joiner gets the world (the same chunked snapshot, then a map
## entry message, then the edits made meanwhile). A client keeps only the map it is on: edits go to
## the members on their map, nobody else. States carry each player's map; a client draws only the
## players on its own map. Requests aimed at a tile carry the map they were aimed on.
##
## M4b (combat): the host owns every fight. It keeps one Arena per map (combat/arena.gd: heretics, shots,
## the shrine, the spawner) and steps those with players on them after the players' frames; every
## player's HP, stamina, dash, stagger and down / dead state is part of its simulation (Vitals) and of its
## state in the batches. A frame now also says whether Space was pressed (dash) and F held (revive,
## give up), and a USE carries its aim. The host checks and resolves every attack, hit, revive, death (the
## bag: world edits) and respawn (on the surface: a map stream from the dungeon). A client predicts its
## own movement, dash and attack animation and timers (Prediction, PlayerSim.step) but never damage; it
## draws the heretics of its map from the host's enemy batches (sent per map, only to the players on it,
## unreliable while they change, a reliable keyframe after and on entering) and the shots from the host's
## shot events (net/net_combat.gd). The host's own arenas are drawn by a CombatView per map.
##
## M5c (farming, purification, the altar): the host keeps one Farm per map and steps it every tick; tilling, planting,
## watering, harvesting, holy water, the paladin's channel and moving the altar are requests on the frames the host checks
## and applies; fields, crops, purified ground and the altar's place are world edits (snapshots carry them), the channel
## and the carried altar ride in the states.
##
## M7c (stations, gear, the chest, building, doors, trees): placing a station, the chest or a build piece is a USE, taking a
## piece down DEMOLISH, F on a door DOOR, the armour ARMOR, a chest panel click CHEST, the axe a USE whose landing frame the
## host chops on; the host checks and applies every one (net/session_host.gd). Pieces, doors, trees, stumps and stations are
## cell edits, a chest's contents chest slot edits (snapshots carry them all); durability and the armour slot ride in the
## owner's inventory message. A client predicts its body actions (the axe swing too), never what they change.
##
## Files: this node holds what both roles share (connection, players, ending, logging) and the RPC
## table. Each @rpc receiver here only hands the payload to its flow, and the flows send through the
## send_* helpers here: net/session_host.gd = host flow, net/session_client.gd = client flow,
## net/session_bots.gd = bots and test hooks (--bot, --net-out results, go / done / finish).
## Machine-readable log lines start with "EVENSONG_NET".

signal local_player_ready(player: Player)
## M3b: the local player is now on map `map_id` (the host moved it; a client has that map loaded):
## show that map (core/main.gd).
signal local_map_changed(map_id: int)
## The session is over: finished, left, refused, failed, lost the host, timed out. `code` is the
## exit code a test instance quits with (EXIT_*).
signal ended(reason: String, code: int)
## M6b: a bot pressed Tab / asked for a crafting panel row this tick (session flow; Main opens the panel or sends
## the CRAFT request, before the tick's frame is built).
signal bot_ui(tab: bool, craft_row: int)
## M7c: F at a chest in reach (the local player's keys or bot, SessionHost.attach_local_op): Main opens its panel on this
## machine's world (footprint `rect`); a bot clicked a chest panel slot (store / take, -1 = none) or the armour slot this
## tick (Main sends the CHEST / ARMOR request).
signal chest_wanted(rect: Rect2i)
signal bot_gear(store_slot: int, take_slot: int, unequip: bool)

enum Role { OFFLINE, HOST, CLIENT }
const ROLE_NAMES: PackedStringArray = ["offline", "host", "client"]

const EXIT_OK: int = 0
const EXIT_REFUSED: int = 3
const EXIT_FAILED: int = 4
## The world received from the host failed its checks (sizes, md5 of the chunks, world hash).
const EXIT_WORLD_MISMATCH: int = 5
const EXIT_TIMEOUT: int = 6


var role: Role = Role.OFFLINE
## The surface's world (main.tscn's World). M3b: `worlds` has every map's GameWorld by map id (the host
## generates them all; a client has the surface and an empty dungeon world it fills on entering).
var world: GameWorld
var worlds: Dictionary[int, GameWorld] = {}
var options: CliOptions
var transport: NetTransport
## Players by slot.
var members: Dictionary[int, NetMember] = {}
var local: NetMember
## M3b: one edit log per map (log_for). A client has the log of the map it is on.
var edit_logs: Dictionary[int, EditLog] = {}
## The surface's log (M1 / M2 code and tests).
var edit_log: EditLog:
	get:
		return log_for(Config.MAP_SURFACE)
	set(value):
		edit_logs[Config.MAP_SURFACE] = value
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
## Requests from the local keys or bot (select, pick up, drop, give: frames with only an op) waiting
## for the next frame of the local player that has no request yet (one per frame).
var local_ops: Array[NetProtocol.InputFrame] = []
## Host: debug give and debug drop requests from clients are honoured (debug builds, or
## --test-allow-give).
var give_allowed: bool = false
## Ticks whose traffic counts as "req" (a request was handled or sent, _count_traffic).
var request_ticks: int = 0
## Pacing of local_ops: the host's request budget, kept here too (NetMember.op_budget).
var local_budget: int = NetMember.OP_BUDGET_MAX

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
	if not worlds.has(Config.MAP_SURFACE):
		worlds[Config.MAP_SURFACE] = world
	options = p_options
	role = Role.HOST if options.host else Role.CLIENT
	_start_ms = Time.get_ticks_msec()
	give_allowed = gives_allowed(OS.is_debug_build(), options.test_allow_give)
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


## M3b: the edit log of map `map_id` (a new one the first time).
func log_for(map_id: int) -> EditLog:
	if not edit_logs.has(map_id):
		edit_logs[map_id] = EditLog.new()
	return edit_logs[map_id]


## M3b: the GameWorld of map `map_id` (the surface's is `world`; null for a map this session has none of).
func world_of(map_id: int) -> GameWorld:
	if worlds.has(map_id):
		return worlds[map_id]
	return world if map_id == Config.MAP_SURFACE else null


## M3b: the map the local player is on (the surface before it exists).
func local_map() -> int:
	return local.map_id if local != null else Config.MAP_SURFACE


## M3b: the world this machine shows: the local player's map's.
func view_world() -> GameWorld:
	var w: GameWorld = world_of(local_map())
	return w if w != null else world


## Whether a host honours clients' debug give and debug drop requests: only in a debug build (the
## editor binary running the project, as the tests and a developer do) or with --test-allow-give; an
## exported release refuses them (refusals "give off", "drop off").
static func gives_allowed(debug_build: bool, flag: bool) -> bool:
	return debug_build or flag


## Pays for a waiting local request like the host will (false: not yet).
func take_local_token() -> bool:
	if local_budget < Config.NET_OP_INTERVAL_TICKS:
		return false
	local_budget -= Config.NET_OP_INTERVAL_TICKS
	return true


## Queues a request of the local player (a frame whose op and fields are set; PICKUP and DROP take
## the target tile when the frame is built). A client applies a hotbar selection at once (predicted);
## everything else waits for the host. At most Config.NET_LOCAL_OPS_MAX wait; one beyond that is
## dropped and logged ("request_dropped").
func queue_op(op_frame: NetProtocol.InputFrame) -> void:
	if role == Role.OFFLINE:
		return
	if local_ops.size() >= Config.NET_LOCAL_OPS_MAX:
		log_event("request_dropped", "%s: %d requests already waiting" % [op_frame.describe_op(), local_ops.size()])
		return
	if role == Role.CLIENT and op_frame.op == NetProtocol.Op.SELECT and local != null:
		local.player.inventory.select(op_frame.slot)
	local_ops.append(op_frame)


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
	local_budget = mini(local_budget + 1, NetMember.OP_BUDGET_MAX)
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


## Traffic by situation: "<moving>/<players>" (walking players), "act<acting>/<players>" while any
## player plays a body action (M2b), "req/<players>" around a request (M2b: the host handled one, or
## this client sent one; that tick and the next two), "joining" while the host sends a joiner its
## world. M3b: " split" is added while the players are on more than one map, and "entering" counts
## the ticks the host sends a player the map it went to.
func _count_traffic() -> void:
	var moving: int = 0
	var acting: int = 0
	var maps: Dictionary[int, bool] = {}
	for slot: int in members:
		if members[slot].player.walking:
			moving += 1
		if members[slot].player.action_anim >= 0:
			acting += 1
		maps[members[slot].map_id] = true
	var key: String = "%d/%d" % [moving, members.size()] if acting == 0 else "act%d/%d" % [acting, members.size()]
	# M4b: a fight (a heretic not idle at home or a shot in the air on a map with players) is its own bucket.
	var fighting: bool = host.fighting() if host != null else (client != null and client.combat != null and client.combat.fighting())
	if fighting:
		key = "fight/%d" % members.size()
	if request_ticks > 0:
		request_ticks -= 1
		if acting == 0 and not fighting:
			key = "req/%d" % members.size()
	if maps.size() > 1:
		key += " split"
	if host != null and host.entering_ticks > 0:
		host.entering_ticks -= 1
		key = "entering"
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


## Client (M3b): the map it went to is complete (its chunks came first); its edits follow.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_map(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_map_entry(payload)


## Client: its own inventory as the host has it (M2b).
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_inventory(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_inventory(payload)


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


## Client (M4b): an enemy batch of the map it is on (unreliable; may be late, lost or held back).
@rpc("authority", "call_remote", "unreliable_ordered", 3)
func _rpc_enemies(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_enemies(payload)


## Client (M4b): the reliable enemy batch (after they went quiet, after a welcome or a map entry).
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_enemy_keyframe(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_enemy_keyframe(payload)


## Client (M4b): shots let go and stopped on the map it is on.
@rpc("authority", "call_remote", "reliable", 0)
func _rpc_shots(payload: PackedByteArray) -> void:
	if role == Role.CLIENT:
		client.on_shots(payload)


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


func send_inventory(peer: int, payload: PackedByteArray) -> void:
	_rpc_inventory.rpc_id(peer, payload)


func send_map_entry(peer: int, payload: PackedByteArray) -> void:
	_rpc_map.rpc_id(peer, payload)


## Client -> host input (through the link simulation, so it may run later; dropped once over).
func send_input(payload: PackedByteArray) -> void:
	if active and not over:
		_rpc_input.rpc_id(1, payload)


func send_state(peer: int, payload: PackedByteArray) -> void:
	_rpc_state.rpc_id(peer, payload)


func send_keyframe(peer: int, payload: PackedByteArray) -> void:
	_rpc_keyframe.rpc_id(peer, payload)


func send_enemies(peer: int, payload: PackedByteArray) -> void:
	_rpc_enemies.rpc_id(peer, payload)


func send_enemy_keyframe(peer: int, payload: PackedByteArray) -> void:
	_rpc_enemy_keyframe.rpc_id(peer, payload)


func send_shots(peer: int, payload: PackedByteArray) -> void:
	_rpc_shots.rpc_id(peer, payload)


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
		local.player.controls = true
	local_ops.clear()
	if client != null:
		client.drop_combat()  # M4b: the heretics were the host's; Main sets up its own offline combat
	log_event("offline", "playing on alone")
	role = Role.OFFLINE


func _exit_tree() -> void:
	if role != Role.OFFLINE and not over:
		over = true
		close()


# --- players ---------------------------------------------------------------------------------

## A player on map `map_id`. The host puts it into that map's world (it steps there); a client into the
## world it shows, hidden unless it is on the client's own map (the client has no other map).
func add_member(slot: int, peer_id: int, class_id: String, pos: Vector2, facing: int,
		map_id: int = Config.MAP_SURFACE) -> NetMember:
	var w: GameWorld = view_world() if role == Role.CLIENT else world_of(map_id)
	if w == null:
		w = world
	var m: NetMember = NetMember.create(w.data, w.entities, slot, peer_id, class_id, pos, facing)
	m.map_id = map_id
	members[slot] = m
	if role == Role.CLIENT and local != null:
		m.player.visible = map_id == local.map_id
	return m


## M3b: puts member `m`'s Player node under world `w`'s entities (y-sorted with that map's things).
static func move_player_node(m: NetMember, w: GameWorld) -> void:
	var p: Player = m.player
	if p.get_parent() == w.entities:
		return
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	w.entities.add_child(p)


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
