extends "res://tests/base_test.gd"
## Real sessions: this project started as separate headless processes (main.tscn with --host /
## --join), driven by --bot scripts, talking ENet over localhost. Every instance writes a result
## (--net-out); all must agree with the host.
##
##   pair  1 host + 1 client moving together, then still; the host edits the world; a late joiner
##         gets the edited world. That joiner runs with --test-perturb-generator (its own generator
##         makes another world from the seed, like a machine whose float noise differs): it must
##         still end with the host's world, because the world comes from the host as a snapshot. In
##         parallel a client joins a port nobody listens on (must fail).
##   four  1 host + 3 clients (cap lowered to 4 with --max-players): all move, one leaves, a late
##         joiner takes the freed spawn slot and gets the edited world, a fifth player is refused
##         ("full"). The real cap (9) is unit-tested in test_net.gd; `-- --net-full` runs it here
##         with 10 processes. This host cuts its world snapshots into 32-byte chunks
##         (--test-snapshot-chunk-bytes), so every joiner gets its world in 11 chunks over two
##         ticks, with the welcome after the last one (the M1 world is one 1 KB chunk otherwise).
##   lag   1 host + 1 client whose traffic is held back 120 ms round trip with 15% loss
##         (net/link_sim.gd): prediction must still match the host. Alongside it, "drop": a host
##         that goes away (its --net-timeout) under a client started like a human would (no
##         --net-out): the client must play on alone, without errors.
##   stall 1 host + 1 walking client: the host blocks 0.7 s outside its physics ticks (bot "stall"),
##         and the client's input queue must catch up afterwards (not stay rate limited behind). Then
##         the host edits the world every 4 ticks while a late joiner streams its world in 1-byte
##         chunks: the edits made meanwhile follow its welcome and its world equals the host's.
##
## Checked: exit codes, positions hash, world hash and ground picture (view hash) equal to the
## host's, everyone sees every player, ground view = data, client prediction error <=
## PREDICTION_BOUND_PX and no facing correction (the host derives the facing), no malformed
## messages, input tokens refilled at the host's real-time pace, every snapshot sent at
## NET_SNAPSHOT_CHUNKS_PER_TICK per tick, late joiners' snapshot and log position, no "ERROR:" line in any child log, every process
## gone at the end (left-overs are killed and fail the test). Ports come from the runner's block
## (tests/run_all.gd). Traffic and late join sizes and times are printed as notes.
##
## Runner flags (after "--"): --net-exe=<path> starts the children from that executable instead of
## this editor build (e.g. build/evensong.console.exe, relative to game/), --net-full adds the
## 10-process cap test, --net-keep keeps the run folder (user://net_test/...) even when passing.

const Runner := preload("res://tests/run_all.gd")

const PREDICTION_BOUND_PX: float = 0.5
## Share of frames drawing a walking player past its newest state (100 ms buffer, localhost).
const INTERP_STARVED_MAX: float = 0.1
const READY_WAIT_SEC: float = 20.0
const STEP_WAIT_SEC: float = 40.0
const REAP_WAIT_SEC: float = 15.0
const INSTANCE_TIMEOUT_SEC: int = 70
## The debug edit: till one grass cell two rows below the altar (seed 1).
const EDIT: String = "edit:62,50,soil"

const PAIR_HOST: String = "move:1,0,90;move:0,1,60;move:-1,-1,60;wait:90;" + EDIT + ";mark:edited;wait:60"
const PAIR_C1: String = "move:-1,0,90;move:0,-1,60;move:1,1,60;wait:90;move:0,1,30;wait:30"
const LATE: String = "move:0,1,40;move:1,0,20;wait:10"
## four: chunk size of the host's world snapshots (test hook), so a 341 B world takes 11 chunks.
const FOUR_CHUNK_BYTES: int = 32
## Everyone moves 150 ticks, then 3 s with nobody moving (the idle measurement), then the edit and
## c1 leaving at about the same time.
const FOUR_HOST: String = "move:1,0,90;move:0,1,60;wait:180;" + EDIT + ";mark:edited;wait:60"
const FOUR_C1: String = "move:-1,0,90;move:0,-1,60;wait:180;leave"
const FOUR_C2: String = "move:0,1,90;move:1,0,60;wait:60"
const FOUR_C3: String = "move:1,1,60;move:-1,0,90;wait:60"
const LAG_HOST: String = "move:1,0,60;move:0,1,30;wait:60"
const LAG_C1: String = "move:-1,-1,45;move:-1,0,30;move:1,1,40;move:0,-1,25;wait:30"
const FULL_BOT: String = "move:1,0,90;wait:120"
## stall: the host blocks this long in a process step (bot "stall") while c1 walks, then edits the
## world every STALL_EDIT_EVERY ticks, STALL_EDITS times, while the late joiner c2 streams its world
## in 1-byte chunks (341 chunks, 43 ticks).
const STALL_MS: int = 700
const STALL_EDITS: int = 60
const STALL_EDIT_EVERY: int = 4
const STALL_CHUNK_BYTES: int = 1
const STALL_C1: String = "move:1,0,60;move:0,1,60;move:-1,0,60;move:0,-1,60;wait:30"
## drop: the host quits by its --net-timeout; the client (no --net-out) runs this many frames.
const DROP_HOST_SEC: int = 6
const DROP_CLIENT_FRAMES: int = 480


class Instance:
	extends RefCounted
	var name: String = ""
	var pid: int = -1
	var log_path: String = ""
	var code: int = -999
	var result: Dictionary = {}


var _exe: String = ""
var _use_path: bool = true
var _keep: bool = false
var _run_dir: String = ""
var _all: Array[Instance] = []


func run() -> Array[String]:
	var args: Dictionary[String, String] = Runner.parse_args(OS.get_cmdline_user_args())
	_exe = OS.get_executable_path()
	if args.has("net-exe"):
		var path: String = args["net-exe"]
		_exe = path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
		_use_path = false
		note("children run %s" % _exe)
		if not check(FileAccess.file_exists(_exe), "--net-exe %s exists" % _exe):
			return failures
	_keep = args.has("net-keep")
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("run_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	await _session_pair()
	await _session_four()
	await _session_lag()
	await _session_stall()
	if args.has("net-full"):
		await _session_full()
	_check_logs()
	note("sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


# --- sessions ------------------------------------------------------------------------------------

func _session_pair() -> void:
	var dir: String = _session_dir("pair")
	var port: int = _port()
	var dead_port: int = Runner.free_port(port + 1, Runner.port_last)
	if not check(port > 0 and dead_port > 0, "pair: free ports"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2",
		"--bot=" + PAIR_HOST])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "pair: host listens"):
		await _reap()
		return
	var dead: Instance = _launch(dir, "nohost", ["--join=127.0.0.1:%d" % dead_port, "--class=miner", "--bot=wait:10"])
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + PAIR_C1])
	var t_late: int = Time.get_ticks_msec()
	if check(await _wait_files([dir.path_join("host.edited.marker")], STEP_WAIT_SEC), "pair: host edited the world"):
		var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=herbalist", "--bot=" + LATE,
			"--test-perturb-generator"])
		note("pair: late joiner started %.1f s after the first client" % ((Time.get_ticks_msec() - t_late) / 1000.0))
		check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json"),
			dir.path_join("nohost.json")], STEP_WAIT_SEC), "pair: every instance wrote its result")
		await _reap()
		if not _load_results(dir, [host, c1, c2, dead]):
			return
		_expect_codes("pair", {host: 0, c1: 0, c2: 0, dead: NetSession.EXIT_FAILED})
		_check_agreement("pair", host, [c1, c2], 3)
		_check_late_joiner("pair", host, c2, true)
		check(_flag(c1.result, "generator_match"), "pair/c1: an unperturbed joiner's generator matches the host's")
		check(str(dead.result.get("ended", "")).begins_with("failed: not admitted"),
			"pair: joining a port nobody listens on fails after the connect timeout (%s)" % dead.result.get("ended", ""))
		check(_log_has(c1, "edit floor 62,50=1 index=0"), "pair: the early client got the edit live")
		_traffic_notes("pair", host, c1, 2)
	else:
		await _reap()


func _session_four() -> void:
	var dir: String = _session_dir("four")
	var port: int = _port()
	if not check(port > 0, "four: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--max-players=4", "--net-start=3",
		"--net-expect=4", "--net-expect-refused=1", "--bot=" + FOUR_HOST, "--test-snapshot-chunk-bytes=%d" % FOUR_CHUNK_BYTES])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "four: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + FOUR_C1])
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + FOUR_C2])
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + FOUR_C3])
	if not check(await _wait_files([dir.path_join("host.edited.marker"), dir.path_join("c1.json")], STEP_WAIT_SEC),
			"four: c1 left and the host edited the world"):
		await _reap()
		return
	var c4: Instance = _launch(dir, "c4", ["--join=127.0.0.1:%d" % port, "--class=herbalist", "--bot=" + LATE])
	if not check(await _wait_files([dir.path_join("c4.welcome.marker")], STEP_WAIT_SEC), "four: late joiner admitted"):
		await _reap()
		return
	var c5: Instance = _launch(dir, "c5", ["--join=127.0.0.1:%d" % port, "--class=paladin", "--bot=wait:10"])
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c2.json"), dir.path_join("c3.json"),
		dir.path_join("c4.json"), dir.path_join("c5.json")], STEP_WAIT_SEC), "four: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2, c3, c4, c5]):
		return
	_expect_codes("four", {host: 0, c1: 0, c2: 0, c3: 0, c4: 0, c5: NetSession.EXIT_REFUSED})
	check_eq(host.result.get("max_players", 0), 4, "four: test cap 4")
	_check_agreement("four", host, [c2, c3, c4], 4)
	_check_late_joiner("four", host, c4, false)
	var four_chunks: int = ceili(_num(c4.result, "snapshot_bytes") / FOUR_CHUNK_BYTES)
	check(four_chunks > Config.NET_SNAPSHOT_CHUNKS_PER_TICK and _num(c4.result, "snapshot_chunks") == float(four_chunks),
		"four/c4: its world came in %d chunks of %d B (more than one tick's %d)" % [four_chunks, FOUR_CHUNK_BYTES,
		Config.NET_SNAPSHOT_CHUNKS_PER_TICK])
	var c4_stream: Dictionary = _stream_for(host, c4)
	check_eq(_num(c4_stream, "ticks"), float(ceili(float(four_chunks) / Config.NET_SNAPSHOT_CHUNKS_PER_TICK)),
		"four/c4: the host sent those chunks over %d ticks" % ceili(float(four_chunks) / Config.NET_SNAPSHOT_CHUNKS_PER_TICK))
	check_eq(c1.result.get("ended", ""), "left", "four: c1 left")
	check_eq(c4.result.get("slot", -1), c1.result.get("slot", -2), "four: the late joiner reuses the slot c1 left")
	check_eq(c5.result.get("refused", ""), "full", "four: a fifth player is refused as full")
	var refusals: Dictionary = host.result.get("refusals", {})
	check(refusals.size() == 1 and roundi(_num(refusals, "full")) == 1, "four: the host refused exactly one join %s" % refusals)
	check(_log_has(host, "refused peer=") and _log_has(c5, "refused: full"), "four: refusal in both logs")
	_traffic_notes("four", host, c2, 4)


func _session_lag() -> void:
	var dir: String = _session_dir("lag")
	var port: int = _port()
	if not check(port > 0, "lag: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=1",
		"--bot=" + LAG_HOST])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "lag: host listens"):
		await _reap()
		return
	var drop_port: int = Runner.free_port(port + 1, Runner.port_last)
	var drop_host: Instance = null
	var drop_client: Instance = null
	if check(drop_port > 0, "drop: free port"):
		drop_host = _launch(dir, "drophost", ["--host=%d" % drop_port, "--bot=wait:30"], DROP_HOST_SEC)
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", "--net-lag=120",
		"--net-loss=15", "--bot=" + LAG_C1])
	if drop_host != null and await _wait_files([dir.path_join("drophost.ready.marker")], READY_WAIT_SEC):
		drop_client = _launch_plain(dir, "dropclient", ["--quit-after", str(DROP_CLIENT_FRAMES)],
			["--join=127.0.0.1:%d" % drop_port, "--class=cleric"])
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json")], STEP_WAIT_SEC),
		"lag: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1]):
		return
	_expect_codes("lag", {host: 0, c1: 0})
	if check(drop_client != null, "drop: client started"):
		_expect_codes("drop", {drop_host: NetSession.EXIT_TIMEOUT, drop_client: 0})
		check(_log_has(drop_client, "client welcome slot=1"), "drop: client was admitted")
		check(_log_has(drop_client, "reason=\"lost the host\"") and _log_has(drop_client, "client offline playing on alone"),
			"drop: after losing the host the client plays on alone")
	_check_agreement("lag", host, [c1], 2)
	var link: Dictionary = c1.result.get("link", {})
	var dropped: int = roundi(_num(link, "dropped"))
	var sent: int = roundi(_num(link, "sent"))
	check(dropped > 0 and sent > 50, "lag: the simulated link really dropped packets (%d of %d)" % [dropped, sent])
	var gates: Dictionary = host.result.get("gates", {})
	var gate: Dictionary = gates.get("1", {})
	var dupes: int = roundi(_num(gate, "duplicates"))
	check(dupes > 0, "lag: repeated frames reached the host (%d duplicates)" % dupes)
	var p: Dictionary = c1.result.get("prediction", {})
	note("lag 120 ms / 15%%: %d of %d client packets dropped, %d reconciles, max prediction error %s px, host drawn past its newest state in %d of %d frames" % [
		dropped, sent, p.get("reconciles", 0), p.get("max_error_px", "?"), roundi(_num(c1.result, "interp_starved")),
		roundi(_num(c1.result, "interp_samples"))])


## The host stalls (a 0.7 s frame outside the physics ticks, where Godot polls the network only
## after its catch-up ticks) while c1 walks: c1's frames must still catch up, not stay rate limited
## behind for the rest of the walk. Then the host edits the world every few ticks while a late
## joiner (c2) receives its world in 341 one-byte chunks: the edits made during the stream reach c2
## after its welcome (the catch-up edits) and its world ends equal to the host's.
func _session_stall() -> void:
	var dir: String = _session_dir("stall")
	var port: int = _port()
	if not check(port > 0, "stall: free port"):
		return
	var host_bot: String = "mark:editing;wait:5;stall:%d;%s;wait:30" % [STALL_MS, _edits_script(STALL_EDITS, STALL_EDIT_EVERY)]
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2",
		"--test-snapshot-chunk-bytes=%d" % STALL_CHUNK_BYTES, "--bot=" + host_bot])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "stall: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + STALL_C1])
	if not check(await _wait_files([dir.path_join("host.editing.marker")], STEP_WAIT_SEC), "stall: host bot started"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=herbalist", "--bot=wait:10"])
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")],
		STEP_WAIT_SEC), "stall: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("stall", {host: 0, c1: 0, c2: 0})
	_check_agreement("stall", host, [c1, c2], 3)
	check_eq(_num(host.result, "stalled_ms"), float(STALL_MS), "stall: the host really blocked %d ms" % STALL_MS)
	var gates: Dictionary = host.result.get("gates", {})
	var g: Dictionary = gates.get(str(roundi(_num(c1.result, "slot"))), {})
	check(_num(g, "waiting_peak") >= 0.6 * STALL_MS * Config.NET_TICK_RATE / 1000.0, "stall: c1's frames piled up during the stall (%s waiting)" % g.get("waiting_peak"))
	check(_num(g, "rate_limited_ticks") <= 2.0, "stall: c1's queue caught up after it, not rate limited behind (%s ticks)" %
		g.get("rate_limited_ticks"))
	check(_num(g, "credit_used") > 0.0, "stall: the lost time reached the frames polled after the catch-up ticks (credit %s)" %
		g.get("credit_used"))
	note("stall %d ms: c1's queue peak %s frames, rate limited %s ticks, hitch credit used %s ticks, refill %s ticks in %s takes" % [
		STALL_MS, g.get("waiting_peak"), g.get("rate_limited_ticks"), g.get("credit_used"), g.get("refilled"), g.get("takes")])
	# Edits while c2 streamed.
	check_eq(_num(host.result, "edits"), float(STALL_EDITS), "stall: the host made %d edits" % STALL_EDITS)
	for c: Instance in [c1, c2]:
		check_eq(_num(c.result, "edits"), float(STALL_EDITS), "stall/%s: log position %d (every edit)" % [c.name, STALL_EDITS])
	var stream: Dictionary = _stream_for(host, c2)
	var catch_up: int = roundi(_num(stream, "catch_up_edits"))
	check(catch_up > 0, "stall/c2: edits made while its world streamed came after the welcome (%d catch-up edits)" % catch_up)
	check(_num(stream, "chunks") > 300.0 and _num(c2.result, "snapshot_chunks") == _num(stream, "chunks"),
		"stall/c2: its world came in %s one-byte chunks" % stream.get("chunks"))
	note("stall/c2: world in %s chunks over %s ticks, snapshot at edit %s, %d edits after it sent after the welcome" % [
		stream.get("chunks"), stream.get("ticks"), stream.get("edit_position"), catch_up])


## A bot script of `count` floor edits (grass -> soil, each allowed by EditLog.check after the ones
## before it, on the seed-1 world), one every `every` ticks.
static func _edits_script(count: int, every: int) -> String:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var parts: PackedStringArray = []
	var origin: Vector2i = data.altar_rect.position + Vector2i(-10, data.altar_rect.size.y + 3)
	for y: int in range(origin.y, data.size.y):
		for x: int in range(origin.x, data.size.x):
			if parts.size() >= count:
				break
			var e: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.FLOOR, Vector2i(x, y), Terrain.SOIL)
			if EditLog.check(data, e).is_empty() and data.set_terrain(e.cell, e.value):
				parts.append("edit:%d,%d,soil;wait:%d" % [x, y, every - 1])
	return ";".join(parts)


## The host's record of the stream that sent `joiner` its world ({} if none).
func _stream_for(host: Instance, joiner: Instance) -> Dictionary:
	var slot: int = roundi(_num(joiner.result, "slot"))
	var streams: Array = host.result.get("streams", [])
	for item: Variant in streams:
		var d: Dictionary = item
		if roundi(_num(d, "slot")) == slot:
			return d
	return {}


## Opt-in (--net-full): the real cap. 1 host + 8 clients = 9 players, a tenth is refused.
func _session_full() -> void:
	var dir: String = _session_dir("full")
	var port: int = _port()
	if not check(port > 0, "full: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=8", "--net-expect=8",
		"--net-expect-refused=1", "--bot=" + FULL_BOT])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "full: host listens"):
		await _reap()
		return
	var clients: Array[Instance] = []
	var welcomes: Array[String] = []
	for i: int in 8:
		var name: String = "c%d" % (i + 1)
		clients.append(_launch(dir, name, ["--join=127.0.0.1:%d" % port, "--class=" + Config.CLASSES[i % 5],
			"--bot=" + FULL_BOT]))
		welcomes.append(dir.path_join(name + ".welcome.marker"))
	if not check(await _wait_files(welcomes, STEP_WAIT_SEC), "full: eight clients admitted"):
		await _reap()
		return
	var tenth: Instance = _launch(dir, "c9", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=wait:10"])
	var files: Array[String] = [dir.path_join("host.json"), dir.path_join("c9.json")]
	for c: Instance in clients:
		files.append(dir.path_join(c.name + ".json"))
	check(await _wait_files(files, STEP_WAIT_SEC), "full: every instance wrote its result")
	await _reap()
	var everyone: Array[Instance] = [host, tenth]
	everyone.append_array(clients)
	if not _load_results(dir, everyone):
		return
	var codes: Dictionary = {host: 0, tenth: NetSession.EXIT_REFUSED}
	for c: Instance in clients:
		codes[c] = 0
	_expect_codes("full", codes)
	check_eq(host.result.get("max_players", 0), Config.MAX_PLAYERS, "full: real cap")
	_check_agreement("full", host, clients, Config.MAX_PLAYERS)
	check_eq(tenth.result.get("refused", ""), "full", "full: the tenth player is refused")
	_traffic_notes("full", host, clients[0], Config.MAX_PLAYERS)


# --- checks --------------------------------------------------------------------------------------

func _check_agreement(label: String, host: Instance, clients: Array[Instance], players: int) -> void:
	var h: Dictionary = host.result
	check_eq(h.get("ended", ""), "finished", "%s: host finished" % label)
	# Physics ticks keep real time in a headless child (bandwidth per second relies on it). A test
	# stall (bot "stall") loses its time but the 8 catch-up ticks Godot runs after it.
	var sim_sec: float = _num(h, "ticks") * Config.NET_TICK
	var stalled_sec: float = maxf(_num(h, "stalled_ms"), 0.0) / 1000.0
	var wall_sec: float = _num(h, "wall_sec") - stalled_sec
	check(wall_sec > 1.0 and absf(sim_sec - wall_sec) <= 0.05 * wall_sec + 0.25,
		"%s: host ticks keep real time (%.2f s simulated, %.2f s wall since hosting, %.2f s stalled not counted)" % [label,
		sim_sec, wall_sec, stalled_sec])
	var host_players: Array = h.get("players", [])
	check_eq(host_players.size(), players, "%s: host has %d players" % [label, players])
	check(_flag(h, "bot_finished"), "%s: host bot finished" % label)
	for inst: Instance in [host] + clients:
		var r: Dictionary = inst.result
		var view: Dictionary = r.get("view", {})
		check(_num(view, "mismatches") == 0.0 and _num(view, "missing") == 0.0 and _num(view, "fallbacks") == 0.0,
			"%s/%s: ground view = data %s" % [label, inst.name, view])
		check_eq(r.get("bad_messages", -1), 0, "%s/%s: no malformed messages" % [label, inst.name])
		check_eq(r.get("unknown_senders", -1), 0, "%s/%s: no input from strangers" % [label, inst.name])
	for c: Instance in clients:
		var r: Dictionary = c.result
		check_eq(r.get("ended", ""), "finished", "%s/%s: finished" % [label, c.name])
		check_eq(r.get("positions_hash", ""), h.get("positions_hash", "?"), "%s/%s: positions = host (%s vs %s)" % [
			label, c.name, JSON.stringify(r.get("players", [])), JSON.stringify(h.get("players", []))])
		check_eq(r.get("world_hash", ""), h.get("world_hash", "?"), "%s/%s: world = host" % [label, c.name])
		check_eq(r.get("view_hash", ""), h.get("view_hash", "?"), "%s/%s: draws the host's ground (view hash)" % [label, c.name])
		check(_num(r, "snapshot_chunks") >= 1.0 and _num(r, "snapshot_bytes") > 0.0,
			"%s/%s: got its world as a snapshot (%s B in %s chunks)" % [label, c.name, r.get("snapshot_bytes"),
			r.get("snapshot_chunks")])
		var seen: Array = r.get("players", [])
		check_eq(seen.size(), players, "%s/%s: sees all %d players" % [label, c.name, players])
		var p: Dictionary = r.get("prediction", {})
		var err: float = _num(p, "max_error_px", 999.0)
		check(err <= PREDICTION_BOUND_PX, "%s/%s: prediction within %.1f px of the host (max %s px)" % [label, c.name,
			PREDICTION_BOUND_PX, err])
		check(_num(p, "reconciles") > 5, "%s/%s: prediction was reconciled (%s)" % [label, c.name, p.get("reconciles", 0)])
		check_eq(p.get("pending", -1), 0, "%s/%s: every input frame acknowledged" % [label, c.name])
		check_eq(_num(p, "facing_corrections"), 0.0, "%s/%s: the host's derived facing = the predicted one" % [label, c.name])
		check(_flag(r, "bot_finished"), "%s/%s: bot finished" % [label, c.name])
		var samples: float = _num(r, "interp_samples")
		var starved: float = _num(r, "interp_starved")
		if label != "lag":
			check(starved <= INTERP_STARVED_MAX * samples,
				"%s/%s: other players drawn from the buffer (%d of %d frames past the newest state)" % [label, c.name,
				starved, samples])
	check(_num(h, "snapshots_sent") >= float(clients.size()), "%s: the host sent a snapshot to every joiner (%s)" % [
		label, h.get("snapshots_sent")])
	var gates: Dictionary = h.get("gates", {})
	for slot: String in gates:
		var g: Dictionary = gates[slot]
		check(_num(g, "bad_packets") == 0.0 and _num(g, "bad_frames") == 0.0 and _num(g, "gaps") == 0.0
			and _num(g, "overflow") == 0.0, "%s: host input gate for slot %s clean %s" % [label, slot, g])
		# The rate limit runs on the host's real-time clock (InputGate.ticks_between): over the gate's
		# life its refill must be about one tick per host tick (plus what a test stall lost).
		var takes: float = _num(g, "takes")
		var refilled: float = _num(g, "refilled")
		check(takes > 30.0 and refilled >= 0.9 * takes - 5.0 and refilled <= 1.1 * takes + 10.0 + stalled_sec * Config.NET_TICK_RATE,
			"%s: slot %s's input tokens follow real time (refill %.1f ticks over %d host ticks)" % [label, slot, refilled,
			roundi(takes)])
	# Each joiner's world went out at NET_SNAPSHOT_CHUNKS_PER_TICK chunks per host tick.
	var streams: Array = h.get("streams", [])
	for item: Variant in streams:
		var st: Dictionary = item
		var chunks: float = _num(st, "chunks")
		check(_num(st, "ticks") == float(ceili(chunks / Config.NET_SNAPSHOT_CHUNKS_PER_TICK)),
			"%s: slot %d's world went out at %d chunks per tick (%d chunks in %d ticks)" % [label, roundi(_num(st, "slot")),
			Config.NET_SNAPSHOT_CHUNKS_PER_TICK, roundi(chunks), roundi(_num(st, "ticks"))])
	check(streams.size() >= clients.size(), "%s: the host recorded a stream for every joiner (%d)" % [label, streams.size()])


## A late joiner: its world is the host's edited world, received as a snapshot with the log
## position after the edit; its own generator only shows up in the diagnostic (`perturbed`: it makes
## another world, and that does not matter).
func _check_late_joiner(label: String, host: Instance, late: Instance, perturbed: bool) -> void:
	var r: Dictionary = late.result
	var h: Dictionary = host.result
	var who: String = "%s/%s" % [label, late.name]
	check_eq(r.get("edits", -1), 1, "%s: log position 1 (the edit came inside the snapshot)" % who)
	check_eq(r.get("world_hash", ""), h.get("world_hash", "?"), "%s: the host's world" % who)
	check_ne(r.get("world_hash", ""), h.get("generator_hash", "?"), "%s: the edited world, not the bare seed" % who)
	check_eq(r.get("host_generator_hash", ""), h.get("generator_hash", "?"), "%s: the welcome carried the host's generator hash" % who)
	if perturbed:
		var own: String = r.get("generator_hash", "")
		var hosts: String = h.get("generator_hash", "?")
		check(not _flag(r, "generator_match") and own != hosts,
			"%s: its own generator makes another world (perturbed) and it still has the host's" % who)
		check(_log_has(late, "generator=differs"), "%s: the diagnostic says the generators differ" % who)
	else:
		check(_flag(r, "generator_match"), "%s: its own generator matches the host's (same build, same machine)" % who)
	check(_log_has(late, "welcome slot=") and _log_has(late, "edits=1"), "%s: welcome logged the edit position" % who)
	var join_ms: float = _num(r, "join_ms")
	check(join_ms > 0.0 and join_ms < 5000.0, "%s: world ready %.1f ms after connecting" % [who, join_ms])
	note("%s late join: world %s B packed (%s B raw) in %s chunk(s), ready %.1f ms after connecting (check + decode + draw %.1f ms)" % [
		who, r.get("snapshot_bytes"), r.get("snapshot_raw"), r.get("snapshot_chunks"), join_ms, _num(r, "world_build_ms")])


func _expect_codes(label: String, codes: Dictionary) -> void:
	for key: Variant in codes:
		var inst: Instance = key
		var want: int = codes[key]
		check_eq(inst.code, want, "%s/%s exit code (ended: %s)" % [label, inst.name, inst.result.get("ended", "?")])


## No "ERROR:" line (also matches "SCRIPT ERROR:") in any child log; warnings are listed.
func _check_logs() -> void:
	var lines: int = 0
	for inst: Instance in _all:
		var text: String = FileAccess.get_file_as_string(inst.log_path)
		if not check(not text.is_empty(), "%s log exists" % inst.name):
			continue
		for line: String in text.split("\n"):
			lines += 1
			if line.contains("ERROR:"):
				fail("%s log: %s" % [inst.name, line.strip_edges()])
			elif line.contains("WARNING:"):
				note("%s log warning: %s" % [inst.name, line.strip_edges()])
	note("child logs: %d instances, %d lines scanned for ERROR:" % [_all.size(), lines])


func _traffic_notes(label: String, host: Instance, client: Instance, players: int) -> void:
	var hs: Dictionary = host.result.get("stats", {})
	var cs: Dictionary = client.result.get("stats", {})
	var moving: String = "%d/%d" % [players, players]
	var idle: String = "0/%d" % players
	check(_num(client.result, "interp_samples") > 30.0, "%s/%s: drew walking players from the buffer (%s frames)" % [
		label, client.name, client.result.get("interp_samples", 0)])
	note("%s client %s: walking players drawn past their newest state in %d of %d frames" % [label, client.name,
		roundi(_num(client.result, "interp_starved")), roundi(_num(client.result, "interp_samples"))])
	if check(hs.has(moving), "%s: host measured %s players moving %s" % [label, moving, hs.keys()]):
		var m: Dictionary = hs[moving]
		check(_num(m, "sec") >= 0.5, "%s: at least 0.5 s with everyone moving (%s s)" % [label, m.get("sec", 0)])
	if check(hs.has(idle), "%s: host measured everyone idle" % label):
		var i: Dictionary = hs[idle]
		var m2: Dictionary = hs.get(moving, {})
		check(_num(i, "sent_bps", 1e9) < 0.25 * _num(m2, "sent_bps", 0.0),
			"%s: idle traffic is quiet (%s B/s idle vs %s B/s moving)" % [label, i.get("sent_bps", "?"), m2.get("sent_bps", "?")])
	var ticks: int = roundi(_num(host.result, "ticks"))
	var batches: int = roundi(_num(host.result, "batches"))
	check_eq(_num(host.result, "quiet_violations"), 0.0,
		"%s: no state batch once nobody has moved for %d ticks (quiet)" % [label, StateBroadcast.QUIET_TICKS])
	check(batches < 0.9 * ticks / 3.0, "%s: fewer batches than every 3rd tick (%d in %d ticks)" % [label, batches, ticks])
	for key: String in [moving, idle]:
		if hs.has(key):
			var b: Dictionary = hs[key]
			note("%s host %s moving: sends %s B/s (%s B/s with UDP/IP) in %s pkt/s, receives %s B/s, over %s s" % [
				label, key, b.get("sent_bps"), b.get("wire_sent_bps"), b.get("packets_ps"), b.get("received_bps"),
				b.get("sec")])
		if cs.has(key):
			var c: Dictionary = cs[key]
			note("%s client %s %s moving: sends %s B/s (%s B/s with UDP/IP), receives %s B/s" % [label, client.name, key,
				c.get("sent_bps"), c.get("wire_sent_bps"), c.get("received_bps")])
	note("%s host: %d state batches + %d keyframes in %d ticks" % [label, batches, roundi(_num(host.result, "keyframes")), ticks])
	if hs.has("joining"):
		var j: Dictionary = hs["joining"]
		note("%s host while sending joiners their world: %s B in %s packets over %s s (counted apart from idle)" % [label,
			j.get("sent"), j.get("packets"), j.get("sec")])


# --- processes -----------------------------------------------------------------------------------

func _session_dir(label: String) -> String:
	var dir: String = _run_dir.path_join(label)
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


func _port() -> int:
	return Runner.free_port(Runner.port_first, Runner.port_last)


## A test instance: result and markers in `dir`, quits by itself after `timeout_sec`.
func _launch(dir: String, name: String, flags: Array, timeout_sec: int = INSTANCE_TIMEOUT_SEC) -> Instance:
	var test_flags: Array = ["--net-out=" + dir, "--net-name=" + name, "--net-timeout=%d" % timeout_sec]
	return _launch_plain(dir, name, [], test_flags + flags)


## An instance with only the given Godot arguments (before "--") and game flags (after it).
func _launch_plain(dir: String, name: String, engine_args: Array, flags: Array) -> Instance:
	var inst: Instance = Instance.new()
	inst.name = name
	inst.log_path = dir.path_join(name + ".log")
	var args: PackedStringArray = ["--headless", "--max-fps", "60"]
	if _use_path:
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", inst.log_path])
	for a: Variant in engine_args:
		args.append(str(a))
	args.append("--")
	for f: Variant in flags:
		args.append(str(f))
	inst.pid = OS.create_process(_exe, args, false)
	check(inst.pid > 0, "started %s" % name)
	_all.append(inst)
	return inst


## True once every file exists; false after `seconds`, or as soon as no child is running.
func _wait_files(paths: Array, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var missing: bool = false
		for path: Variant in paths:
			if not FileAccess.file_exists(str(path)):
				missing = true
				break
		if not missing:
			return true
		var alive: bool = false
		for inst: Instance in _all:
			if inst.code == -999 and OS.is_process_running(inst.pid):
				alive = true
		if not alive:
			return false
		await tree.create_timer(0.05).timeout
	return false


## Waits for every child to exit and records exit codes; kills (and fails on) any left over.
func _reap() -> void:
	var deadline: int = Time.get_ticks_msec() + int(REAP_WAIT_SEC * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var alive: bool = false
		for inst: Instance in _all:
			if inst.code == -999 and OS.is_process_running(inst.pid):
				alive = true
		if not alive:
			break
		await tree.create_timer(0.05).timeout
	for inst: Instance in _all:
		if inst.code != -999:
			continue
		if OS.is_process_running(inst.pid):
			OS.kill(inst.pid)
			fail("%s (pid %d) was still running and had to be killed" % [inst.name, inst.pid])
			inst.code = -1
		else:
			inst.code = OS.get_process_exit_code(inst.pid)


func _load_results(dir: String, instances: Array[Instance]) -> bool:
	var ok: bool = true
	for inst: Instance in instances:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(inst.name + ".json")))
		if parsed is Dictionary:
			inst.result = parsed
		else:
			ok = false
			fail("%s.json missing or unreadable (log %s)" % [inst.name, inst.log_path])
	return ok


## A JSON number (JSON gives floats) or `fallback`.
static func _num(d: Dictionary, key: String, fallback: float = -1.0) -> float:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		return f
	if typeof(v) == TYPE_INT:
		var i: int = v
		return float(i)
	return fallback


static func _flag(d: Dictionary, key: String) -> bool:
	var v: Variant = d.get(key, false)
	return typeof(v) == TYPE_BOOL and v == true


func _log_has(inst: Instance, text: String) -> bool:
	return FileAccess.get_file_as_string(inst.log_path).contains(text)


func cleanup() -> void:
	for inst: Instance in _all:
		if inst.pid > 0 and OS.is_process_running(inst.pid):
			OS.kill(inst.pid)
	super.cleanup()


static func _remove_dir(path: String) -> void:
	for sub: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
