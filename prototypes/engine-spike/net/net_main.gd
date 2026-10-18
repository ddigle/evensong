extends Node2D
## Net spike entry scene (res://net/net.tscn). One script for every role.
##
##   (no --net-role)     interactive host on DEFAULT_PORT: arrows/WASD move, left click breaks.
##                       A second window joins with --net-role=client.
##   --net-role=host     host (the host is also a player, peer 1)
##   --net-role=client   client
##
## User args (after "--"):
##   --net-port=<24601..24620>     UDP port (Steam: virtual port, default 0)   default 24620
##   --net-address=<ip|steam id>   where a client connects             default 127.0.0.1
##   --net-transport=enet|steam    see transports.gd                    default enet
##   --net-compress=none|range|fastlz|zlib|zstd   ENet packet compression   default none
##   --net-sync=always|on_change   position replication mode            default always
##   --net-sync-hz=<n>             position updates per second, 0 = every frame   default 30
##   --net-relay=on|off            SceneMultiplayer.server_relay (off = like GodotSteam's
##                                 default: clients reach only the host)   default on
##   --net-map=<n>                host: map is n x n tiles             default 256
##   --net-seed=<n>                host: map seed                       default 7
##   --net-expect=<n>              host: clients that must finish their scripts before the
##                                 session ends (0 = run until closed)  default 0
##   --net-name=<name>             instance name (result file name)     default host / client
##   --net-out=<dir>               write <dir>/<name>.json at the end, and host markers
##   --net-timeout=<sec>           give up, write the result and exit 3 (0 = never)
##   --script-actions=<actions>    scripted player, see bot.gd
##
## End of a scripted session: every client reports "done" when its script ends; once the host's
## own script is done and --net-expect clients reported, the host waits SETTLE_TICKS, writes its
## result and broadcasts "finish"; clients write theirs and quit. Exit codes: 0 ok, 2 bad
## arguments or network setup, 3 timeout, 4 connection failed, 5 host went away.

const SpikeCli := preload("res://skeleton/spike_cli.gd")
const Transports := preload("res://net/transports.gd")
const NetTransport := preload("res://net/net_transport.gd")
const EnetTransport := preload("res://net/enet_transport.gd")
const TileWorld := preload("res://net/tile_world.gd")
const WorldSync := preload("res://net/world_sync.gd")
const Player := preload("res://net/player.gd")
const Bot := preload("res://net/bot.gd")

const DEFAULT_PORT: int = 24620
const PORT_MIN: int = 24601
const PORT_MAX: int = 24620
const MAX_PLAYERS: int = 9
const SETTLE_TICKS: int = 30
const FINISH_GRACE_MS: int = 3000
const CLIENT_FINISH_FRAMES: int = 5
const BURST_WINDOW_MS: int = 1000
## Traffic right after a snapshot went out is counted apart from the moving/idle buckets.
const SNAPSHOT_WINDOW_MS: int = 500

var opts: Dictionary = {}
var role: String = "host"
var interactive: bool = false
var instance_name: String = "host"
var out_dir: String = ""
var expect: int = 0
var port: int = DEFAULT_PORT
var sync_mode: int = SceneReplicationConfig.REPLICATION_MODE_ALWAYS
var sync_hz: int = 30
var relay: bool = true
var transport: NetTransport = null
var world_sync: WorldSync = null
var players_root: Node2D = null
var spawner: MultiplayerSpawner = null
var bot: Bot = null
var hud: Label = null
var camera: Camera2D = null
var status: String = ""

## Barrier names the host has released (on every instance).
var released: Dictionary = {}
var errors: PackedStringArray = []

var _started_msec: int = 0
var _deadline_msec: int = 0
var _timed_out: bool = false
var _bot_started: bool = false
var _host_bot_done: bool = false
var _arrivals: Dictionary = {}
var _host_arrived: Dictionary = {}
var _markers: Dictionary = {}
var _done_peers: Dictionary = {}
var _names: Dictionary = {}
var _joins: Dictionary = {}
var _next_spawn_index: int = 1
var _settle: int = -1
var _finishing: bool = false
var _host_quit_at: int = -1
var _client_finish_frames: int = -1
var _result_written: bool = false
var _quitting: bool = false

# traffic (bytes from the transport, ENet headers included)
var _bytes_sent: int = 0
var _bytes_received: int = 0
var _packets_sent: int = 0
var _buckets: Dictionary = {}
var _burst: Dictionary = {}
var _hud_accum: float = 0.0
var _hud_sent: int = 0


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	opts = SpikeCli.parse_user_args(OS.get_cmdline_user_args())
	interactive = not opts.has("net-role")
	role = str(opts.get("net-role", "host"))
	if DisplayServer.get_name() == "headless" and Engine.max_fps == 0:
		Engine.max_fps = 60  # headless would otherwise spin; the game runs at 60 fps
	_build_nodes()
	var problem: String = _read_options()
	if problem.is_empty():
		problem = _start_network()
	if not problem.is_empty():
		_fail(problem, 2)
		return
	_update_hud()


func _read_options() -> String:
	if role != "host" and role != "client":
		return "--net-role must be host or client, got %s" % role
	instance_name = str(opts.get("net-name", role))
	out_dir = str(opts.get("net-out", ""))
	if out_dir.begins_with("user://") or out_dir.begins_with("res://"):
		out_dir = ProjectSettings.globalize_path(out_dir)
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
	expect = clampi(_int_opt("net-expect", 0), 0, MAX_PLAYERS - 1)
	port = _int_opt("net-port", DEFAULT_PORT)
	var timeout_sec: int = _int_opt("net-timeout", 0 if interactive else 90)
	if timeout_sec > 0:
		_deadline_msec = _started_msec + timeout_sec * 1000
	match str(opts.get("net-sync", "always")):
		"always":
			sync_mode = SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		"on_change":
			sync_mode = SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		_:
			return "--net-sync must be always or on_change"
	sync_hz = maxi(_int_opt("net-sync-hz", 30), 0)
	match str(opts.get("net-relay", "on")):
		"on":
			relay = true
		"off":
			relay = false
		_:
			return "--net-relay must be on or off"
	if opts.has("script-actions"):
		bot = Bot.new()
		var err: String = bot.parse(str(opts["script-actions"]))
		if not err.is_empty():
			return "--script-actions: %s" % err
	return ""


func _int_opt(key: String, fallback: int) -> int:
	var text: String = str(opts.get(key, ""))
	return text.to_int() if text.is_valid_int() else fallback


func _build_nodes() -> void:
	world_sync = WorldSync.new()
	add_child(world_sync)
	players_root = Node2D.new()
	players_root.name = "Players"
	add_child(players_root)
	world_sync.players_root = players_root
	spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players_root)
	spawner.spawn_function = _spawn_player
	if DisplayServer.get_name() != "headless":
		camera = Camera2D.new()
		camera.name = "Camera"
		add_child(camera)
		camera.make_current()
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "Hud"
		add_child(layer)
		hud = Label.new()
		hud.position = Vector2(4.0, 2.0)
		hud.add_theme_font_size_override("font_size", 8)
		hud.add_theme_color_override("font_color", Color(0.93, 0.84, 0.62))
		hud.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.05))
		hud.add_theme_constant_override("outline_size", 2)
		layer.add_child(hud)


func _start_network() -> String:
	var kind: String = str(opts.get("net-transport", "enet"))
	transport = Transports.make(kind)
	if transport == null:
		return "--net-transport must be one of %s" % ", ".join(Transports.KINDS)
	if not transport.is_available():
		return "transport %s is not available in this build" % kind
	var enet: EnetTransport = transport as EnetTransport
	if enet != null:
		if port < PORT_MIN or port > PORT_MAX:
			return "--net-port must be %d..%d for this spike, got %d" % [PORT_MIN, PORT_MAX, port]
		var mode: int = Transports.enet_compression(str(opts.get("net-compress", "none")))
		if mode < 0:
			return "--net-compress must be none, range, fastlz, zlib or zstd"
		enet.compression = mode
	elif not opts.has("net-port"):
		port = 0  # Steam virtual port: GodotSteam expects 0 unless one pair needs several links
	# Before any peer is set: changing it while connected confuses SceneMultiplayer.
	var scene_mp: SceneMultiplayer = multiplayer as SceneMultiplayer
	if scene_mp != null:
		scene_mp.server_relay = relay
	if role == "host":
		var size: int = clampi(_int_opt("net-map", 256), TileWorld.MIN_SIZE, TileWorld.MAX_SIZE)
		world_sync.host_generate(size, _int_opt("net-seed", 7))
		var err: Error = transport.create_host(port, MAX_PLAYERS - 1)
		if err != OK:
			return "cannot host on port %d: %s" % [port, error_string(err)]
		multiplayer.multiplayer_peer = transport.get_peer()
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		spawner.spawn({"id": 1, "index": 0, "cell": world_sync.world.spawn_cell(0)})
		status = "hosting on port %d" % port
		_write_marker("ready")
		print("NET %s hosting port=%d map=%d transport=%s" % [instance_name, port, size, transport.kind()])
	else:
		var address: String = str(opts.get("net-address", "127.0.0.1"))
		var err: Error = transport.create_client(address, port)
		if err != OK:
			return "cannot connect to %s:%d: %s" % [address, port, error_string(err)]
		multiplayer.multiplayer_peer = transport.get_peer()
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		status = "connecting to %s:%d" % [address, port]
	return ""


func _spawn_player(data: Variant) -> Node:
	var d: Dictionary = data as Dictionary
	var player: Player = Player.new()
	player.setup(int(d["id"]), int(d["index"]), d["cell"] as Vector2i, sync_mode,
		0.0 if sync_hz <= 0 else 1.0 / sync_hz)
	player.world = world_sync.world
	player.simulate = role == "host"
	return player


func local_player() -> Player:
	if not multiplayer.has_multiplayer_peer():
		return null
	return players_root.get_node_or_null(str(multiplayer.get_unique_id())) as Player


# --- connection events -------------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if role != "host":
		return
	_joins[id] = int(world_sync.host_stats["edits"])
	world_sync.send_snapshot(id)
	var index: int = _next_spawn_index
	_next_spawn_index += 1
	spawner.spawn({"id": id, "index": index, "cell": world_sync.world.spawn_cell(index)})
	print("NET host: peer %d connected (edits so far %d)" % [id, _joins[id]])
	for barrier: String in _host_arrived:
		_check_barrier(barrier)


func _on_peer_disconnected(id: int) -> void:
	if role != "host":
		return
	var node: Node = players_root.get_node_or_null(str(id))
	if node != null:
		node.queue_free()
	if not _finishing:
		print("NET host: peer %d left" % id)


func _on_connected() -> void:
	status = "connected as peer %d" % multiplayer.get_unique_id()
	_rpc_hello.rpc_id(1, instance_name)


func _on_connection_failed() -> void:
	_fail("connection failed", 4)


func _on_server_disconnected() -> void:
	if _client_finish_frames < 0 and not _result_written:
		_fail("host went away", 5)


# --- session RPCs (channel 1, same ordered channel as the tile traffic) -------------------------

@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_hello(client_name: String) -> void:
	if role == "host":
		_names[multiplayer.get_remote_sender_id()] = client_name


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_barrier_arrive(barrier: String) -> void:
	if role != "host":
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if released.has(barrier):
		_rpc_barrier_release.rpc_id(sender, barrier)
		return
	var arrived: Dictionary = _arrivals.get_or_add(barrier, {})
	arrived[sender] = true
	_check_barrier(barrier)


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_barrier_release(barrier: String) -> void:
	released[barrier] = true


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_report_done() -> void:
	if role == "host":
		_done_peers[multiplayer.get_remote_sender_id()] = true


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_session_finish() -> void:
	if _client_finish_frames < 0:
		_client_finish_frames = CLIENT_FINISH_FRAMES


func _arrive(barrier: String) -> void:
	if role == "host":
		_host_arrived[barrier] = true
		_check_barrier(barrier)
	else:
		_rpc_barrier_arrive.rpc_id(1, barrier)


## Host: release when the host and every expected client arrived. When everyone connected so far
## is waiting but more clients are expected, drop a marker file (the test starts the late joiner).
func _check_barrier(barrier: String) -> void:
	if released.has(barrier) or not _host_arrived.has(barrier):
		return
	var arrived: Dictionary = _arrivals.get(barrier, {})
	var connected: PackedInt32Array = multiplayer.get_peers()
	var here: int = 0
	for peer: int in connected:
		if arrived.has(peer):
			here += 1
	var needed: int = expect if expect > 0 else connected.size()
	if here >= needed:
		released[barrier] = true
		_rpc_barrier_release.rpc(barrier)
		print("NET host: barrier %s released (%d clients)" % [barrier, here])
	elif here == connected.size():
		_write_marker("waiting_" + barrier)


# --- per tick ----------------------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _quitting:
		return
	if _deadline_msec > 0 and Time.get_ticks_msec() > _deadline_msec and not _timed_out:
		_timed_out = true
		_fail("timeout", 3)
		return
	var me: Player = local_player()
	if me != null:
		if bot != null:
			_drive_bot(me)
		elif interactive or role == "client":
			me.input.direction = _keyboard_direction()
	if role == "host":
		_host_session_tick()


func _drive_bot(me: Player) -> void:
	if bot.finished or not world_sync.ready_for_play:
		return
	if not _bot_started:
		_bot_started = true
		bot.origin = me.spawn_cell
	var out: Dictionary = bot.step(me.position, released)
	me.input.direction = out["direction"]
	for cell: Vector2i in out["breaks"]:
		world_sync.request_break(cell)
	for cell: Vector2i in out["forge"]:
		world_sync.forge_delta(cell)
	if not str(out["arrive"]).is_empty():
		_arrive(str(out["arrive"]))
	var burst: int = int(out["burst"])
	if burst > 0 and role == "host":
		var done: int = world_sync.host_burst(burst)
		_burst = {"cells": done, "start_msec": Time.get_ticks_msec(), "bytes": 0, "packets": 0, "active": true,
			"players": players_root.get_child_count()}
	if bot.finished:
		me.input.direction = Vector2.ZERO
		if role == "host":
			_host_bot_done = true
		else:
			_rpc_report_done.rpc_id(1)
		print("NET %s: script done%s" % [instance_name,
			"" if bot.notes.is_empty() else " (%s)" % "; ".join(bot.notes)])


func _host_session_tick() -> void:
	if expect <= 0 or _finishing:
		if _settle > 0:
			_settle -= 1
			if _settle == 0:
				_host_finish()
		return
	var own_done: bool = bot == null or _host_bot_done
	if own_done and _done_peers.size() >= expect:
		_finishing = true
		_settle = SETTLE_TICKS


func _host_finish() -> void:
	world_sync.flush()
	_write_result()
	_rpc_session_finish.rpc()
	_host_quit_at = Time.get_ticks_msec() + FINISH_GRACE_MS
	print("NET host: finished, tiles=%s" % world_sync.world.hash_hex().left(16))


func _process(delta: float) -> void:
	_measure(delta)
	if _quitting:
		return
	if _client_finish_frames > 0:
		_client_finish_frames -= 1
		if _client_finish_frames == 0:
			_write_result()
			_quit(0)
			return
	if _host_quit_at > 0 and (multiplayer.get_peers().is_empty() or Time.get_ticks_msec() >= _host_quit_at):
		_quit(0)
		return
	if camera != null:
		var me: Player = local_player()
		if me != null:
			camera.position = me.position
	if hud != null:
		_hud_accum += delta
		if _hud_accum >= 0.5:
			_update_hud()


func _measure(delta: float) -> void:
	if transport == null:
		return
	var sent: int = transport.pop_sent_bytes()
	var received: int = transport.pop_received_bytes()
	var packets: int = maxi(transport.pop_sent_packets(), 0)
	if sent < 0:
		return
	_bytes_sent += sent
	_bytes_received += received
	_packets_sent += packets
	_hud_sent += sent
	if role != "host":
		return
	var moving: int = 0
	var total: int = 0
	for child: Node in players_root.get_children():
		var player: Player = child as Player
		if player != null:
			total += 1
			if player.moved_last_tick:
				moving += 1
	# Bucket key: "<moving>/<players>", or the snapshot / burst phase whose traffic would
	# otherwise inflate it.
	var key: String = "%d/%d" % [moving, total]
	var since_snapshot: int = Time.get_ticks_msec() - world_sync.snapshot_sent_msec
	if world_sync.snapshot_sent_msec >= 0 and since_snapshot < SNAPSHOT_WINDOW_MS:
		key = "snapshot"
	elif bool(_burst.get("active", false)):
		key = "burst"
	var bucket: Dictionary = _buckets.get_or_add(key,
		{"bytes": 0, "packets": 0, "received": 0, "sec": 0.0, "frames": 0})
	bucket["bytes"] = int(bucket["bytes"]) + sent
	bucket["packets"] = int(bucket["packets"]) + packets
	bucket["received"] = int(bucket["received"]) + received
	bucket["sec"] = float(bucket["sec"]) + delta
	bucket["frames"] = int(bucket["frames"]) + 1
	if bool(_burst.get("active", false)):
		_burst["bytes"] = int(_burst["bytes"]) + sent
		_burst["packets"] = int(_burst["packets"]) + packets
		if Time.get_ticks_msec() - int(_burst["start_msec"]) >= BURST_WINDOW_MS:
			_burst["active"] = false
			_burst["window_ms"] = Time.get_ticks_msec() - int(_burst["start_msec"])


func _keyboard_direction() -> Vector2:
	if DisplayServer.get_name() == "headless":
		return Vector2.ZERO
	var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1.0
	return dir.limit_length(1.0)


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if world_sync.ready_for_play and multiplayer.has_multiplayer_peer():
		world_sync.request_break(TileWorld.cell_at(get_global_mouse_position()))
		get_viewport().set_input_as_handled()


func _update_hud() -> void:
	if hud == null:
		return
	var rate: float = _hud_sent / maxf(_hud_accum, 0.001)
	_hud_accum = 0.0
	_hud_sent = 0
	var lines: PackedStringArray = [
		"net spike  %s  [%s]  %s" % [role, instance_name, status],
		"players %d   edits %d   sent %.0f B/s" % [
			players_root.get_child_count(),
			int(world_sync.host_stats["edits"]) if role == "host" else int(world_sync.client_stats["delta_cells"]),
			rate],
		"arrows/WASD move   left click: break wall   F10 menu",
	]
	if role == "host" and interactive:
		lines.append("join: godot --path . res://net/net.tscn -- --net-role=client --net-port=%d" % port)
	hud.text = "\n".join(lines)


# --- results -----------------------------------------------------------------------------------

func players_snapshot() -> Array:
	var ids: Array[int] = []
	for child: Node in players_root.get_children():
		var player: Player = child as Player
		if player != null and not player.is_queued_for_deletion():
			ids.append(player.peer_id)
	ids.sort()
	var out: Array = []
	for id: int in ids:
		var player: Player = players_root.get_node(str(id)) as Player
		out.append({"id": id, "x": player.position.x, "y": player.position.y})
	return out


static func players_hash(players: Array) -> String:
	var lines: PackedStringArray = []
	for p: Dictionary in players:
		lines.append("%d:%.4f,%.4f" % [int(p["id"]), float(p["x"]), float(p["y"])])
	return ";".join(lines).sha256_text()


func build_result() -> Dictionary:
	var players: Array = players_snapshot()
	var world: TileWorld = world_sync.world
	var result: Dictionary = {
		"name": instance_name,
		"role": role,
		"peer_id": multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0,
		"transport": transport.kind() if transport != null else "none",
		"compress": str(opts.get("net-compress", "none")),
		"sync": "always" if sync_mode == SceneReplicationConfig.REPLICATION_MODE_ALWAYS else "on_change",
		"sync_hz": sync_hz,
		"relay": relay,
		"tiles_hash": world.hash_hex(),
		"players_hash": players_hash(players),
		"players": players,
		"player_count": players.size(),
		"view_mismatch": world_sync.view.first_mismatch(world),
		"map": [world.width, world.height],
		"walls": world.width * world.height - world.count_value(TileWorld.LAYER_WALL, TileWorld.WALL_NONE),
		"timeout": _timed_out,
		"errors": errors,
		"bot_finished": bot.finished if bot != null else true,
		"bot_notes": bot.notes if bot != null else PackedStringArray(),
		"seconds": (Time.get_ticks_msec() - _started_msec) / 1000.0,
		"bytes_sent": _bytes_sent,
		"bytes_received": _bytes_received,
		"packets_sent": _packets_sent,
	}
	if role == "host":
		var joins: Dictionary = {}
		for peer: int in _joins:
			joins[str(_names.get(peer, peer))] = _joins[peer]
		result["initial_hash"] = world_sync.initial_hash
		result["tiles"] = world_sync.host_stats
		result["joins"] = joins
		result["buckets"] = _buckets
		result["burst"] = _burst
		result["delta_seq"] = world_sync.delta_seq
	else:
		result["snapshot_hash"] = world_sync.snapshot_hash
		result["tiles"] = world_sync.client_stats
	return result


func _write_result() -> void:
	if _result_written:
		return
	_result_written = true
	var result: Dictionary = build_result()
	print("NET_RESULT %s tiles=%s players=%s count=%d" % [
		instance_name, str(result["tiles_hash"]).left(16), str(result["players_hash"]).left(16),
		int(result["player_count"])])
	if out_dir.is_empty():
		return
	var path: String = out_dir.path_join(instance_name + ".json")
	var tmp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		printerr("NET cannot write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)


func _write_marker(marker: String) -> void:
	if out_dir.is_empty() or _markers.has(marker):
		return
	_markers[marker] = true
	var file: FileAccess = FileAccess.open(out_dir.path_join(marker + ".marker"), FileAccess.WRITE)
	if file != null:
		file.store_string(str(Time.get_ticks_msec()))
		file.close()


func _fail(message: String, code: int) -> void:
	errors.append(message)
	printerr("NET %s: %s" % [instance_name, message])
	status = "ERROR: " + message
	if interactive:
		_update_hud()
		return
	_write_result()
	_quit(code)


func _quit(code: int) -> void:
	if _quitting:
		return
	_quitting = true
	if transport != null:
		multiplayer.multiplayer_peer = null
		transport.close()
	get_tree().quit(code)
