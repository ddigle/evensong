extends "res://tests/spike_test.gd"
## net module: host-authoritative co-op over Godot high-level multiplayer (ENet on localhost).
##
## 1. In-process checks of the pieces (tile data, snapshot round trip, deltas, host validation,
##    TileMapLayer view, bot script parser, transport factory).
## 2. A real session: 1 host + N headless clients of this project as separate processes
##    (OS.create_process). Every instance runs a scripted player (move, break walls, patrol);
##    the last client joins late, after the others have already changed the map. At the end
##    every instance writes its tile hash and player positions; all must match.
##
## Extra runner args (after "--", next to --only/--timeout):
##   --net-clients=<1..8>   clients in the session (default 3; 8 = nine players)
##   --net-sync=always|on_change   --net-sync-hz=<n>   --net-compress=<mode>   --net-map=<n>
##   --net-relay=on|off   (off = no client-to-client relay, like GodotSteam's peer default)
## The numbers (bytes per second etc.) are printed as NET_STATS lines.

const SpikeCli := preload("res://skeleton/spike_cli.gd")
const TileWorld := preload("res://net/tile_world.gd")
const TileView := preload("res://net/tile_view.gd")
const Bot := preload("res://net/bot.gd")
const Transports := preload("res://net/transports.gd")
const NetTransport := preload("res://net/net_transport.gd")

const PORT_FIRST: int = 24601
const PORT_LAST: int = 24619  # 24620 is the interactive default
# Worst case 15 + 30 + 60 + 10 s stays under the runner's 120 s per file.
const READY_WAIT_SEC: float = 15.0
const LATE_WAIT_SEC: float = 30.0
const SESSION_WAIT_SEC: float = 60.0
const REAP_WAIT_SEC: float = 10.0
const INSTANCE_TIMEOUT_SEC: int = 75
const BURST: int = 200
## IPv4 + UDP header per datagram, not in ENet's byte statistics.
const UDP_IP_HEADER: int = 28

## Each player: walk up 3 tiles, break the two stone walls beside the bedrock above it, then
## three requests the host must reject (bedrock, empty cell, far away), meet everyone (the late
## joiner arrives here), patrol 3 s together, meet again, stand still 1 s (idle traffic), host
## bursts 200 edits while everyone stands 1.5 s more, walk down, break two walls of the lower
## row, walk back to the spawn cell. c1 also forges one host delta (must be refused everywhere).
const PRE: String = "move:0,-3;break:-1,-5;break:1,-5;break:0,-5;break:0,-4;break:0,-30;barrier:all;patrol:3;barrier:burst;wait:60;"
const POST: String = "move:0,3;break:0,6;break:1,6;move:0,0"
const HOST_SCRIPT: String = PRE + "burst:%d;wait:90;" % BURST + POST
const CLIENT_SCRIPT: String = PRE + "wait:90;" + POST
const FORGER_SCRIPT: String = "forge:0,-1;" + CLIENT_SCRIPT
const OK_BREAKS_PER_PLAYER: int = 4
const REJECTS_PER_PLAYER: Array[String] = [
	TileWorld.REJECT_UNBREAKABLE, TileWorld.REJECT_NO_WALL, TileWorld.REJECT_REACH]

var _pids: Array[int] = []


func run() -> Array[String]:
	_check_tile_world()
	await _check_view()
	_check_bot()
	_check_transports()
	await _check_session()
	return failures


# --- pieces ------------------------------------------------------------------------------------

func _check_tile_world() -> void:
	var a: TileWorld = TileWorld.new(256, 256)
	var t0: int = Time.get_ticks_usec()
	a.generate(7)
	var gen_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var b: TileWorld = TileWorld.new(256, 256)
	b.generate(7)
	check_eq(a.hash_hex(), b.hash_hex(), "same seed -> same map")
	var c: TileWorld = TileWorld.new(256, 256)
	c.generate(8)
	check_ne(a.hash_hex(), c.hash_hex(), "other seed -> other map")
	check(a.count_value(TileWorld.LAYER_WALL, TileWorld.WALL_NONE) > 10000, "map has open floor")
	check(a.count_value(TileWorld.LAYER_WALL, TileWorld.WALL_STONE) > 2000, "map has stone")

	# arena layout the scripts rely on
	for i: int in 9:
		var s: Vector2i = a.spawn_cell(i)
		check(not a.is_solid(s), "spawn %d is open" % i)
		check_eq(a.get_cell(TileWorld.LAYER_WALL, s + Vector2i(0, -5)), TileWorld.WALL_BEDROCK, "bedrock above spawn %d" % i)
		check_eq(a.get_cell(TileWorld.LAYER_WALL, s + Vector2i(-1, -5)), TileWorld.WALL_STONE, "stone left-above %d" % i)
		check_eq(a.get_cell(TileWorld.LAYER_WALL, s + Vector2i(1, -5)), TileWorld.WALL_STONE, "stone right-above %d" % i)
		check_eq(a.get_cell(TileWorld.LAYER_WALL, s + Vector2i(1, 6)), TileWorld.WALL_STONE, "stone below %d" % i)

	# host validation
	var s0: Vector2i = a.spawn_cell(0)
	var stand: Vector2 = TileWorld.cell_center(s0 + Vector2i(0, -3))
	check_eq(a.validate_break(s0 + Vector2i(-1, -5), stand), "", "stone in reach is accepted")
	check_eq(a.validate_break(s0 + Vector2i(0, -5), stand), TileWorld.REJECT_UNBREAKABLE, "bedrock")
	check_eq(a.validate_break(s0 + Vector2i(0, -4), stand), TileWorld.REJECT_NO_WALL, "empty cell")
	check_eq(a.validate_break(s0 + Vector2i(0, -30), stand), TileWorld.REJECT_REACH, "far cell")
	check_eq(a.validate_break(Vector2i(-1, 3), stand), TileWorld.REJECT_BOUNDS, "outside the map")
	check(a.box_hits_wall(TileWorld.cell_center(s0 + Vector2i(0, -5)), Vector2(5, 5)), "bedrock blocks movement")
	check(not a.box_hits_wall(stand, Vector2(5, 5)), "standing cell is free")

	# deltas: absolute, idempotent, malformed buffers rejected
	var buf: PackedByteArray = PackedByteArray()
	buf = TileWorld.append_delta(buf, TileWorld.LAYER_WALL, Vector2i(44, 5), TileWorld.WALL_NONE)
	buf = TileWorld.append_delta(buf, TileWorld.LAYER_ORE, Vector2i(255, 255), 1)
	check_eq(buf.size(), 2 * TileWorld.DELTA_SIZE, "delta size")
	var before: String = b.hash_hex()
	check_eq(b.apply_deltas(buf).size(), 2, "two deltas applied")
	var once: String = b.hash_hex()
	b.apply_deltas(buf)
	check_eq(b.hash_hex(), once, "applying a delta twice changes nothing")
	check_ne(once, before, "deltas changed the map")
	check_eq(b.apply_deltas(buf.slice(0, 7)).size(), 0, "malformed delta buffer is ignored")
	b.set_cell(TileWorld.LAYER_WALL, Vector2i(3, 3), 2)
	check_eq(b.get_cell(TileWorld.LAYER_WALL, Vector2i(3, 3)), 2, "set_cell writes in place")

	# compressed chunk snapshot round trip, also for a size that is not a chunk multiple
	for size: Vector2i in [Vector2i(256, 256), Vector2i(100, 70)]:
		var src: TileWorld = TileWorld.new(size.x, size.y)
		src.generate(3)
		var dst: TileWorld = TileWorld.new(size.x, size.y)
		var raw: int = 0
		var packed: int = 0
		var ok: bool = true
		for cy: int in src.chunks_y():
			for cx: int in src.chunks_x():
				var r: Rect2i = src.chunk_rect(cx, cy)
				var raw_size: int = r.size.x * r.size.y * TileWorld.LAYER_COUNT
				var data: PackedByteArray = src.compress_chunk(cx, cy)
				ok = dst.apply_compressed_chunk(cx, cy, data, raw_size) and ok
				raw += raw_size
				packed += data.size()
		check(ok, "all chunks decode (%s)" % size)
		check_eq(dst.hash_hex(), src.hash_hex(), "snapshot round trip %s" % size)
		check_eq(raw, size.x * size.y * TileWorld.LAYER_COUNT, "chunks cover the map %s" % size)
		if size.x == 256:
			print("NET_STATS unit: generate 256x256 %.1f ms, snapshot %d chunks %d -> %d bytes (zstd)" % [
				gen_ms, src.chunks_x() * src.chunks_y(), raw, packed])
	check(not TileWorld.new(64, 64).apply_compressed_chunk(0, 0, PackedByteArray([1, 2, 3]), 3072),
		"garbage chunk is rejected")


func _check_view() -> void:
	var world: TileWorld = TileWorld.new(64, 64)
	world.generate(5)
	var view: TileView = add_node(TileView.new()) as TileView
	view.rebuild(world)
	await await_frames(1)
	check_eq(view.map_layers.size(), TileWorld.LAYER_COUNT, "one TileMapLayer per layer")
	check_eq(view.first_mismatch(world), "", "view matches data")
	var c: Vector2i = world.spawn_cell(0) + Vector2i(1, -5)
	world.set_cell(TileWorld.LAYER_WALL, c, TileWorld.WALL_NONE)
	check_ne(view.first_mismatch(world), "", "a data change the view missed is detected")
	view.set_world_cell(TileWorld.LAYER_WALL, c, TileWorld.WALL_NONE)
	check_eq(view.first_mismatch(world), "", "view matches after set_world_cell")


func _check_bot() -> void:
	var bad: Bot = Bot.new()
	check_ne(bad.parse("move:1"), "", "bad move is rejected")
	check_ne(bad.parse("jump:1,2"), "", "unknown action is rejected")
	check_ne(bad.parse("barrier:"), "", "nameless barrier is rejected")
	check_eq(bad.parse(HOST_SCRIPT), "", "host script parses")
	check_eq(bad.parse(CLIENT_SCRIPT), "", "client script parses")
	check_eq(bad.parse(FORGER_SCRIPT), "", "forger script parses")
	check_eq(bad.barrier_names(), PackedStringArray(["all", "burst"]), "barrier names")

	var bot: Bot = Bot.new()
	check_eq(bot.parse("move:0,-1;break:1,-2;break:0,-2;wait:2;barrier:b;burst:5"), "", "parse")
	bot.origin = Vector2i(10, 10)
	var pos: Vector2 = TileWorld.cell_center(Vector2i(10, 10))
	var released: Dictionary = {}
	var out: Dictionary = {}
	var ticks: int = 0
	var breaks: Array[Vector2i] = []
	var arrivals: int = 0
	var burst: int = 0
	while not bot.finished and ticks < 400:
		out = bot.step(pos, released)
		pos += (out["direction"] as Vector2) * 1.0  # 60 px/s at 60 ticks
		for cell: Vector2i in out["breaks"]:
			breaks.append(cell)
		if not str(out["arrive"]).is_empty():
			arrivals += 1
			released[str(out["arrive"])] = true
		burst += int(out["burst"])
		ticks += 1
	check(bot.finished, "bot script finishes")
	check_eq(breaks, [Vector2i(11, 8), Vector2i(10, 8)] as Array[Vector2i], "breaks are relative to the spawn cell")
	check_eq(arrivals, 1, "barrier arrival reported once")
	check_eq(burst, 5, "burst count")
	check(pos.distance_to(TileWorld.cell_center(Vector2i(10, 9))) <= Bot.ARRIVE_PX, "move reached its cell")
	check(bot.notes.is_empty(), "no move timeouts (%s)" % "; ".join(bot.notes))


func _check_transports() -> void:
	check(Transports.make("nope") == null, "unknown transport -> null")
	var enet: NetTransport = Transports.make("enet")
	check(enet != null and enet.is_available(), "ENet transport is available")
	var steam: NetTransport = Transports.make("steam")
	check(steam != null, "Steam transport class exists")
	if steam != null:
		var has_steam: bool = ClassDB.class_exists(&"SteamMultiplayerPeer")
		check_eq(steam.is_available(), has_steam and Engine.has_singleton("Steam"), "Steam availability follows GodotSteam")
		if not has_steam:
			check_eq(steam.create_host(0, 8), ERR_UNAVAILABLE, "Steam host without GodotSteam -> ERR_UNAVAILABLE")
			check_eq(steam.create_client("76561197960287930", 0), ERR_UNAVAILABLE, "Steam client without GodotSteam")
			check(steam.get_peer() == null, "no Steam peer created")
	check_eq(Transports.enet_compression("zstd"), ENetConnection.COMPRESS_ZSTD, "compression name")
	check_eq(Transports.enet_compression("lz4"), -1, "unknown compression")
	var port: int = _free_port()
	if check(port > 0, "a free port in %d..%d" % [PORT_FIRST, PORT_LAST]) and enet != null:
		check_eq(enet.create_host(port, 8), OK, "ENet host on %d" % port)
		check(enet.pop_sent_bytes() >= 0, "ENet reports sent bytes")
		check(enet.pop_sent_packets() >= 0, "ENet reports sent packets")
		enet.close()
		check(enet.get_peer() == null, "closed")


# --- multi-process session ---------------------------------------------------------------------

func _check_session() -> void:
	var args: Dictionary = SpikeCli.parse_user_args(OS.get_cmdline_user_args())
	var clients: int = clampi(str(args.get("net-clients", "3")).to_int(), 1, 8)
	var players: int = clients + 1
	var passthrough: PackedStringArray = []
	for key: String in ["net-sync", "net-sync-hz", "net-compress", "net-map", "net-relay"]:
		if args.has(key):
			passthrough.append("--%s=%s" % [key, args[key]])
	var port: int = _free_port()
	if not check(port > 0, "free port for the session"):
		return
	var run_dir: String = ProjectSettings.globalize_path("user://net_test").path_join(
		"run_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(run_dir)
	var names: PackedStringArray = ["host"]
	for i: int in clients:
		names.append("c%d" % (i + 1))
	var late: String = names[clients]
	var t0: int = Time.get_ticks_msec()

	_pids.clear()
	_launch(run_dir, "host", "host", port, HOST_SCRIPT,
		PackedStringArray(["--net-expect=%d" % clients]) + passthrough)
	var ok: bool = check(await _wait_file(run_dir.path_join("ready.marker"), READY_WAIT_SEC),
		"host is listening (logs: %s)" % run_dir)
	if ok:
		for i: int in range(1, clients):
			_launch(run_dir, names[i], "client", port, FORGER_SCRIPT if i == 1 else CLIENT_SCRIPT, passthrough)
		ok = check(await _wait_file(run_dir.path_join("waiting_all.marker"), LATE_WAIT_SEC),
			"early clients finished their first part (logs: %s)" % run_dir)
	var late_msec: int = Time.get_ticks_msec() - t0
	if ok:
		_launch(run_dir, late, "client", port, FORGER_SCRIPT if clients == 1 else CLIENT_SCRIPT, passthrough)
		var files: PackedStringArray = []
		for n: String in names:
			files.append(run_dir.path_join(n + ".json"))
		ok = check(await _wait_files(files, SESSION_WAIT_SEC), "every instance wrote its result (logs: %s)" % run_dir)
	var codes: Array[int] = await _reap_processes(REAP_WAIT_SEC)
	var session_sec: float = (Time.get_ticks_msec() - t0) / 1000.0
	if not ok:
		return

	for i: int in codes.size():
		check_eq(codes[i], 0, "exit code of %s" % names[i])
	var results: Dictionary = {}
	for n: String in names:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(run_dir.path_join(n + ".json")))
		if not check(parsed is Dictionary, "%s.json parses" % n):
			return
		results[n] = parsed
	var host: Dictionary = results["host"]
	for n: String in names:
		var r: Dictionary = results[n]
		check(not bool(r["timeout"]), "%s did not time out" % n)
		check_eq((r["errors"] as Array).size(), 0, "%s errors %s" % [n, r["errors"]])
		check_eq(r["tiles_hash"], host["tiles_hash"], "%s tile hash = host" % n)
		check_eq(r["players_hash"], host["players_hash"], "%s player positions = host (%s vs %s)" % [
			n, JSON.stringify(r["players"]), JSON.stringify(host["players"])])
		check_eq(r["player_count"], players, "%s sees every player" % n)
		check_eq(r["view_mismatch"], "", "%s TileMapLayer view = data" % n)
		check(bool(r["bot_finished"]), "%s finished its script" % n)
		check_eq((r["bot_notes"] as Array).size(), 0, "%s bot notes %s" % [n, r["bot_notes"]])
		if n != "host":
			var tiles: Dictionary = r["tiles"]
			check_eq(tiles["seq_gaps"], 0, "%s delta sequence has no gaps" % n)
			check_eq(tiles["snapshot_bad_chunks"], 0, "%s snapshot chunks all decoded" % n)

	check_eq((results["c1"]["tiles"] as Dictionary)["forged_sent"], 1, "c1 sent its forged delta")
	var refusals: int = _count_in_logs(run_dir, names, "_rpc_apply_deltas")
	check(refusals > 0, "the forged delta was refused and logged (%d log lines)" % refusals)
	var host_tiles: Dictionary = host["tiles"]
	check_eq(host_tiles["requests_ok"], OK_BREAKS_PER_PLAYER * players, "accepted break requests")
	var rejected: Dictionary = host_tiles["rejected"]
	for reason: String in REJECTS_PER_PLAYER:
		check_eq(rejected.get(reason, 0), players, "rejected as %s" % reason)
	check_eq(host_tiles["requests_rejected"], REJECTS_PER_PLAYER.size() * players, "rejected total")
	check_eq(host_tiles["burst_cells"], BURST, "burst edits")
	check_eq(host_tiles["burst_payload_bytes"], BURST * TileWorld.DELTA_SIZE, "burst went out as one batch")
	check_eq(host_tiles["edits"], OK_BREAKS_PER_PLAYER * players + BURST, "edits total")
	var joins: Dictionary = host["joins"]
	check(int(joins.get(late, 0)) > 0, "late joiner %s came after edits (%s)" % [late, joins])
	var late_result: Dictionary = results[late]
	check_ne(late_result["snapshot_hash"], host["initial_hash"], "late joiner's snapshot already had the edits")
	var buckets: Dictionary = host["buckets"]
	var all_moving: String = "%d/%d" % [players, players]
	var idle: String = "0/%d" % players
	check(buckets.has(all_moving) and float((buckets[all_moving] as Dictionary)["sec"]) >= 1.0,
		"measured %d players moving together (%s)" % [players, buckets.keys()])
	_print_stats(results, names, players, session_sec, late_msec, all_moving, idle)
	if failures.is_empty():
		_remove_dir(run_dir)


func _launch(run_dir: String, instance: String, role: String, port: int, script: String,
		extra: PackedStringArray) -> void:
	var args: PackedStringArray = [
		"--headless", "--max-fps", "60",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", run_dir.path_join(instance + ".log"),
		"res://net/net.tscn", "--",
		"--net-role=" + role, "--net-port=%d" % port, "--net-name=" + instance,
		"--net-out=" + run_dir, "--net-timeout=%d" % INSTANCE_TIMEOUT_SEC,
		"--script-actions=" + script,
	]
	args.append_array(extra)
	var pid: int = OS.create_process(OS.get_executable_path(), args, false)
	check(pid > 0, "started %s" % instance)
	_pids.append(pid)


func _wait_file(path: String, seconds: float) -> bool:
	return await _wait_files(PackedStringArray([path]), seconds)


func _wait_files(paths: PackedStringArray, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var all_there: bool = true
		for path: String in paths:
			if not FileAccess.file_exists(path):
				all_there = false
				break
		if all_there:
			return true
		var alive: int = 0
		for pid: int in _pids:
			if OS.is_process_running(pid):
				alive += 1
		if alive == 0:
			return false  # everyone exited without writing
		await tree.create_timer(0.1).timeout
	return false


## Waits for every started process to exit, kills the rest. Returns exit codes (-1 = killed).
func _reap_processes(seconds: float) -> Array[int]:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var alive: bool = false
		for pid: int in _pids:
			if OS.is_process_running(pid):
				alive = true
		if not alive:
			break
		await tree.create_timer(0.1).timeout
	var codes: Array[int] = []
	for pid: int in _pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
			fail("process %d had to be killed" % pid)
			codes.append(-1)
		else:
			codes.append(OS.get_process_exit_code(pid))
	_pids.clear()
	return codes


func cleanup() -> void:
	for pid: int in _pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_pids.clear()
	super.cleanup()


func _free_port() -> int:
	for port: int in range(PORT_FIRST, PORT_LAST + 1):
		var probe: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
		var err: Error = probe.create_server(port, 1)
		probe.close()
		if err == OK:
			return port
	return -1


func _print_stats(results: Dictionary, names: PackedStringArray, players: int, session_sec: float,
		late_msec: int, all_moving: String, idle: String) -> void:
	var host: Dictionary = results["host"]
	var buckets: Dictionary = host["buckets"]
	print("NET_STATS session: %d players (1 host + %d clients), sync=%s %dHz, compress=%s, relay=%s, %.1f s, late join at %.1f s" % [
		players, players - 1, host["sync"], int(host["sync_hz"]), host["compress"],
		"on" if bool(host["relay"]) else "off", session_sec, late_msec / 1000.0])
	for key: String in buckets:
		var b: Dictionary = buckets[key]
		var sec: float = maxf(float(b["sec"]), 0.001)
		if sec < 0.2 and key != "snapshot":
			continue
		var bytes: int = int(b["bytes"])
		var packets: int = int(b.get("packets", 0))
		print("NET_STATS host bucket %s%s: sent %.0f B/s in %.0f pkt/s (~%.0f B/s with UDP/IPv4 headers), received %.0f B/s (%d B in %.2f s)" % [
			key, " moving" if key.contains("/") else "", bytes / sec, packets / sec,
			(bytes + UDP_IP_HEADER * packets) / sec, int(b["received"]) / sec, bytes, sec])
	var burst: Dictionary = host["burst"]
	var idle_rate: float = 0.0
	var idle_wire_rate: float = 0.0
	if buckets.has(idle):
		var ib: Dictionary = buckets[idle]
		var idle_sec: float = maxf(float(ib["sec"]), 0.001)
		idle_rate = int(ib["bytes"]) / idle_sec
		idle_wire_rate = (int(ib["bytes"]) + UDP_IP_HEADER * int(ib.get("packets", 0))) / idle_sec
	var window_sec: float = int(burst.get("window_ms", 1000)) / 1000.0
	var burst_bytes: int = int(burst.get("bytes", 0))
	var burst_wire: int = burst_bytes + UDP_IP_HEADER * int(burst.get("packets", 0))
	print("NET_STATS burst: %d edits, payload %d B per client, host sent %d B (~%d B with UDP/IPv4) in %.2f s window, idle baseline %.0f B (~%.0f B) -> extra ~%.0f B (~%.0f B)" % [
		int(burst.get("cells", 0)), int((host["tiles"] as Dictionary)["burst_payload_bytes"]),
		burst_bytes, burst_wire, window_sec, idle_rate * window_sec, idle_wire_rate * window_sec,
		burst_bytes - idle_rate * window_sec, burst_wire - idle_wire_rate * window_sec])
	var tiles: Dictionary = host["tiles"]
	print("NET_STATS snapshot: %d chunks, %d -> %d bytes, build %.1f ms; host generate %.1f ms" % [
		int(tiles["snapshot_chunks"]), int(tiles["snapshot_raw_bytes"]), int(tiles["snapshot_compressed_bytes"]),
		float(tiles["snapshot_build_ms"]), float(tiles["generate_ms"])])
	for n: String in names:
		var r: Dictionary = results[n]
		var sec: float = maxf(float(r["seconds"]), 0.001)
		var line: String = "NET_STATS %s: sent %d B in %d packets, received %d B in %.1f s (%.0f / %.0f B/s)" % [
			n, int(r["bytes_sent"]), int(r.get("packets_sent", 0)), int(r["bytes_received"]), sec,
			int(r["bytes_sent"]) / sec, int(r["bytes_received"]) / sec]
		if n != "host":
			var t: Dictionary = r["tiles"]
			line += ", snapshot apply %.1f ms (decode %.1f, TileMapLayer %.1f), %d delta batches" % [
				float(t["snapshot_apply_ms"]), float(t["snapshot_decode_ms"]), float(t["snapshot_view_ms"]),
				int(t["delta_batches"])]
		print(line)


## Lines that mention `needle` in the instances' log files (Godot logs refused RPCs there).
func _count_in_logs(run_dir: String, names: PackedStringArray, needle: String) -> int:
	var count: int = 0
	for n: String in names:
		var text: String = FileAccess.get_file_as_string(run_dir.path_join(n + ".log"))
		for line: String in text.split("\n"):
			if line.contains(needle):
				count += 1
	return count


func _remove_dir(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
