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
##         M2b: the host swings a pickaxe, walks to a wild herb, picks it (c1 sees it vanish) and drops
##         5 stones there; c1 asks for a sword (give request) and swings it. Each sees the other's held
##         item and actions. The late joiner (herbalist) arrives with the herb gone and the stones in
##         its snapshot, picks the stones up and then a herb of its own (FINE grade).
##   four  1 host + 3 clients (cap lowered to 4 with --max-players): all move, one leaves, a late
##         joiner takes the freed spawn slot and gets the edited world, a fifth player is refused
##         ("full"). M2b: before c1 leaves, the host drops 5 stones next to the three clients, who all
##         press F on that tile every tick for 1.5 s (a race, and request spam): exactly one gets them. The real cap (9) is unit-tested in test_net.gd; `-- --net-full` runs it here
##         with 10 processes. This host cuts its world snapshots into 32-byte chunks
##         (--test-snapshot-chunk-bytes), so every joiner gets its world in about 18 chunks over
##         three ticks (M2b world, about 570 B; 11 chunks over two ticks in M1), with the welcome
##         after the last one (the world is one 1 KB chunk otherwise).
##   lag   1 host + 1 client whose traffic is held back 120 ms round trip with 15% loss
##         (net/link_sim.gd): prediction must still match the host. Alongside it, "drop": a host
##         that goes away (its --net-timeout) under a client started like a human would (no
##         --net-out): the client must play on alone, without errors.
##   stall 1 host + 1 walking client: the host blocks 0.7 s outside its physics ticks (bot "stall"),
##         and the client's input queue must catch up afterwards (not stay rate limited behind). Then
##         the host edits the world every 4 ticks while a late joiner streams its world in 1-byte
##         chunks: the edits made meanwhile follow its welcome and its world equals the host's. M2b:
##         some of those edits are drops the host puts down while the joiner streams.
##   cave  (M3b) host (miner) + c1 (cleric) + a late c2 (herbalist), seed 1. The host goes down the
##         entrance, places a torch and cracks the rock west of the arrival room (one 3x3 swing) while
##         c1 stays on the surface: c1 gets none of those edits and does not draw the host. c1 goes
##         down and gets the dungeon as it is (map snapshot: the cracks, the torch). Both mine: the host
##         breaks its 3x3 and drops stones, c1 cracks the rock east of the room (4 swings) and places a
##         torch; each gets the other's edits live. c2 joins while both are below (draws nobody on the
##         surface), sees c1 come back up the stairs, goes down and gets every break, crack, torch
##         and drop. The bots wait for each other with "waitmap". Every map's hash is compared: the
##         surface of c1, the dungeon of c2 and of c1 when it left.
##   four  (M3b) after the M2b race c2 and c3 go down (the map in 32-byte chunks) and swing at the same
##         rock from two sides (c3 at its face) until it breaks: exactly one break, the stone to the
##         one whose hit broke it. The late c4 joins while both are below and draws neither.
##   fight (M4b, run by tests/test_net_fight.gd) host (paladin) + c1 (archer, 12 HP) + a late c2
##         (cleric), seed 1, three heretics placed on the surface south of the light, spawns off. c1's
##         arrows kill H2 from out of its sight; c1 walks up to H3 and is downed by one knife; the host
##         kills H3 and holds F next to c1 until it is up; the host strikes H1 once and stands in its reach
##         while c2 joins (mid-fight: H1 attacking the host, hurt); then all three kill H1. Everyone must
##         agree (positions, worlds, the heretics' HP as each saw it, the last enemy view).
##   fight4 (M4b, run by tests/test_net_fight.gd) host + 3 clients (archer, miner, cleric) kill two
##         heretics together: four players in one fight, the traffic of a fight of four.
##
## Checked: exit codes, positions hash (with each player's map), world hash and picture (view hash)
## of the map each client is on equal to the host's (M3b: per map), everyone knows every player,
## ground / cave view = data, items drawn = data (gatherables, drops),
## client prediction error <= PREDICTION_BOUND_PX and no facing or action correction, no malformed
## messages, input tokens refilled at the host's real-time pace, every snapshot sent at
## NET_SNAPSHOT_CHUNKS_PER_TICK per tick, late joiners' snapshot and log position, no "ERROR:" line in any child log, every process
## gone at the end (left-overs are killed and fail the test). Ports come from the runner's block
## (tests/run_all.gd). Traffic and late join sizes and times are printed as notes.
##
## Runner flags (after "--"): --net-exe=<path> starts the children from that executable instead of
## this editor build (e.g. build/evensong.console.exe, relative to game/), --net-full adds the
## 10-process cap test, --net-keep keeps the run folder (user://net_test/...) even when passing,
## --net-sessions=<a,b> runs only those sessions (pair, four, lag, stall, cave, full; fight, fight4 from
## tests/test_net_fight.gd).

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

## pair (M2b, seed 1): the host starts with a pickaxe and 20 stones (--give, its own), swings the
## pickaxe east (3 actions), walks next to the wild buff at PAIR_HERB, picks it, selects the stones
## and drops 5 on that tile, then edits. c1 asks for a sword (give request), flips through three
## hotbar slots back to it (predicted selects, one per frame: never refused as "rate"), swings it west
## (2), then stands still and aims south: the look alone turns it, and the host must see that facing
## (the frame is recorded for the turn, Prediction.step_frame; the positions hash carries the facing).
const PAIR_HERB: Vector2i = Vector2i(47, 51)
const PAIR_HOST_GIVE: String = "--give=pickaxe,stone_a:20"
const PAIR_HOST: String = ("move:1,0,90;move:0,1,60;move:-1,-1,60;wait:90;aim:20,0;use:80;aim:off;walkto:48,51;" +
	"aimat:47,51;pick;wait:6;select:2;wait:6;drop:5;wait:10;" + EDIT + ";mark:edited;wait:60")
const PAIR_C1: String = ("move:-1,0,90;move:0,-1,60;move:1,1,60;wait:90;move:0,1,30;wait:30;select:3;select:2;select:1;" +
	"wait:10;aim:-20,0;use:60;aim:off;wait:60;aim:0,20;wait:20;aim:off;wait:60")
## The late herbalist: picks up the host's 5 stones (a drop it got in its snapshot), then the wild buff
## at PAIR_FINE_HERB (FINE: the herbalist's).
const PAIR_FINE_HERB: Vector2i = Vector2i(44, 58)
const PAIR_LATE: String = "walkto:48,45;walkto:48,50;aimat:47,51;pick;wait:10;walkto:45,57;aimat:44,58;pick;wait:20"
const LATE: String = "move:0,1,40;move:1,0,20;wait:10"
## four: chunk size of the host's world snapshots (test hook), so a ~570 B world takes ~18 chunks.
const FOUR_CHUNK_BYTES: int = 32
## Everyone moves 150 ticks, then 3 s with nobody moving (the idle measurement). M2b race: the host
## (5 of its stones) walks above FOUR_DROP and drops them there; c1, c2, c3 stand on the other sides
## and press F on that tile every tick for 1.5 s from before the drop appears. Then the edit and c1
## leaving at about the same time.
const FOUR_DROP: Vector2i = Vector2i(63, 53)
const FOUR_HOST: String = ("move:1,0,90;move:0,1,60;wait:180;walkto:63,52;aimat:63,53;wait:150;drop:5;mark:dropped;" +
	"wait:150;" + EDIT + ";mark:edited;wait:60")
const FOUR_C1: String = "move:-1,0,90;move:0,-1,60;wait:180;walkto:66,50;walkto:64,53;aimat:63,53;wait:100;pick:90;wait:30;leave"
## M3b: after the race c2 and c3 (pickaxes from --give, hotbar slot 1) go down and swing at FOUR_ROCK, c2
## beside it, c3 at its face below, until well after it broke; they mark "down" once both are below
## (the late c4 is started after that) and "mined" at the end.
const FOUR_ROCK: Vector2i = Vector2i(42, 15)
const FOUR_DOWN: String = ";walkto:70,52;walkto:73,48;aimat:73,47;pick;wait:20;waitmap:2,dungeon;mark:down;select:1;"
const FOUR_C2: String = ("move:0,1,90;move:1,0,60;wait:180;walkto:66,50;walkto:62,53;aimat:63,53;wait:60;pick:90;wait:30" +
	FOUR_DOWN + "walkto:41,15;aimat:42,15;use:180;wait:60;mark:mined")
const FOUR_C3: String = ("move:1,1,60;move:-1,0,90;wait:180;walkto:63,54;aimat:63,53;wait:120;pick:90;wait:30" +
	FOUR_DOWN + "walkto:41,16;aimat:42,16;use:180;wait:60;mark:mined")
## cave (M3b, seed 1): the host (miner) goes down, places a torch south of the arrival point, cracks the
## rock west of the arrival room with one 3x3 swing (CAVE_WEST from the tile east of it), waits for c1,
## breaks it with two more swings, drops 3 of its stones; then waits for c2 to join, c1 to go up and c2
## to come down. c1 (cleric) waits on the surface until the host is below (and 5 s more: both idle on
## two maps), goes down, cracks the rock east of the room (CAVE_EAST, 4 swings), places a torch, waits
## for c2 to join, goes back up. c2 joins after the host's "mined": nobody else on the surface, then
## c1 comes up, then it goes down too.
const CAVE_WEST: Vector2i = Vector2i(33, 15)
const CAVE_EAST: Vector2i = Vector2i(42, 15)
const CAVE_DOWN: String = "walkto:70,49;walkto:73,48;aimat:73,47;pick;wait:20;"
const CAVE_HOST: String = (CAVE_DOWN + "mark:down;select:2;aim:0,24;use:2;wait:10;select:1;walkto:34,15;aimat:33,15;use:30;" +
	"wait:40;mark:cracked;waitmap:2,dungeon;wait:60;use:60;wait:40;select:3;aim:0,24;drop:3;wait:10;mark:mined;" +
	"waitmap:1,surface;waitmap:2,surface;waitmap:2,dungeon;wait:60")
const CAVE_C1: String = ("move:0,1,30;waitmap:1,dungeon;wait:300;mark:alone;" + CAVE_DOWN + "waitmap:2,dungeon;mark:down;" +
	"walkto:41,15;aimat:42,15;use:140;wait:30;select:2;aim:0,24;use:2;wait:10;mark:mined;waitmap:1,surface;wait:90;" +
	"walkto:38,15;aimat:38,14;pick;wait:30;mark:up;wait:120")
const CAVE_C2: String = "wait:20;mark:alone;waitmap:2,surface;wait:30;mark:sees;" + CAVE_DOWN + "waitmap:2,dungeon;wait:30;mark:down;wait:60"
const LAG_HOST: String = "move:1,0,60;move:0,1,30;wait:60"
const LAG_C1: String = "move:-1,-1,45;move:-1,0,30;move:1,1,40;move:0,-1,25;wait:30"
const FULL_BOT: String = "move:1,0,90;wait:120"
## fight (M4b, seed 1, surface tiles; the altar's light reaches about 7 tiles around 63,47): H1 (54,57),
## H2 (63,61), H3 (74,58), in that order (heretic ids 1, 2, 3). c1 shoots H2 from (63,53), inside the light
## (128 px: the nearest heretic, in the bow's reach, out of its sight) until two heretics are left, then
## walks toward (72,57): H3 sees it, comes and downs it with one knife (12 HP). The host waits for that,
## walks to c1 (H3 goes for it), kills H3, holds F next to c1 until it is up, closes in on H1, strikes it
## once and stands in its reach (marked "ath1": the test starts c2) until c2 is in; then all three kill H1
## (c1 starts shooting first, the host last, so that each of them hits it).
const FIGHT_HERETICS: String = "--test-heretic=54,57/63,61/74,58"
const FIGHT_HOST: String = ("select:8;wait:30;waitdown:1,3000;walkdown;fight:1200,1,20;walkdown;hold:330;mark:revived;" +
	"closein:18,900;fight:20,0,18;wait:40;mark:ath1;waitmap:3,surface,1800;wait:200;fight:1500,0,20;wait:240")
const FIGHT_C1: String = ("select:8;walkto:63,53;fight:1200,2;walkto:72,57;waitlife:down,900;waitlife:alive,2400;mark:up;wait:30;" +
	"walkto:58,57;waitmap:3,surface,1800;wait:60;fight:1500,0;wait:240")
const FIGHT_C2: String = "select:8;wait:30;mark:seen;walkto:58,55;fight:1500,0;wait:240"
## fight4: H1 (60,57) and H2 (66,57), just south of the light; the paladin and the miner close in on the
## nearest, the archer (63,52) and the cleric (62,52) shoot from the light's edge, until both are dead.
const FIGHT4_HERETICS: String = "--test-heretic=60,57/66,57"
const FIGHT4_HOST: String = "select:8;wait:60;fight:1500,0,20;wait:240"
const FIGHT4_C1: String = "select:8;walkto:63,52;wait:30;fight:1500,0;wait:240"
const FIGHT4_C2: String = "select:8;wait:60;fight:1500,0,18;wait:240"
const FIGHT4_C3: String = "select:8;walkto:62,52;wait:30;fight:1500,0;wait:240"
## fightlag (M4-fix): one heretic just south of the light; c1 (miner, a lagging and lossy link) walks next to
## it and stands still for 9 s while it is struck again and again (every hit lands on a client that stood
## still: its timers had run out), then walks back into the light. The host stands by.
const FIGHTLAG_HERETIC: String = "--test-heretic=63,61"
const FIGHTLAG_HOST: String = "wait:60"
const FIGHTLAG_C1: String = "walkto:63,60;wait:540;walkto:63,52;wait:120"
const FIGHTLAG_LINK: Array = ["--net-lag=120", "--net-loss=5"]
## stall: the host blocks this long in a process step (bot "stall") while c1 walks, then edits the
## world every STALL_EDIT_EVERY ticks, STALL_EDITS times, while the late joiner c2 streams its world
## in 1-byte chunks (about 567 chunks, 71 ticks; 341 and 43 in M1).
const STALL_MS: int = 700
const STALL_EDITS: int = 60
const STALL_EDIT_EVERY: int = 4
const STALL_CHUNK_BYTES: int = 1
const STALL_C1: String = "move:1,0,60;move:0,1,60;move:-1,0,60;move:0,-1,60;wait:30"
## M2b: every STALL_DROP_EVERY-th edit of the host's loop is followed by a drop of one stone (it starts
## with 99) on the tile south of its feet, while c2 streams.
const STALL_DROP_EVERY: int = 10
const STALL_DROPS: int = STALL_EDITS / STALL_DROP_EVERY
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
	# --net-sessions=cave,four runs only those (development); default: all but "full".
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("pair"):
		await _session_pair()
	if only.is_empty() or only.has("four"):
		await _session_four()
	if only.is_empty() or only.has("lag"):
		await _session_lag()
	if only.is_empty() or only.has("stall"):
		await _session_stall()
	if only.is_empty() or only.has("cave"):
		await _session_cave()
	if args.has("net-full") or only.has("full"):
		await _session_full()
	if only.has("fight"):
		await _session_fight()
	if only.has("fight4"):
		await _session_fight4()
	if not only.is_empty():
		note("only the sessions %s ran (--net-sessions)" % ", ".join(only))
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
	# c1 asks for its sword: a host from the editor build (debug) honours give requests by itself, an
	# exported release host only with --test-allow-give (NetSession.gives_allowed).
	var host_flags: Array = ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--bot=" + PAIR_HOST, PAIR_HOST_GIVE]
	if not _use_path:
		host_flags.append("--test-allow-give")
	var host: Instance = _launch(dir, "host", host_flags)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "pair: host listens"):
		await _reap()
		return
	var dead: Instance = _launch(dir, "nohost", ["--join=127.0.0.1:%d" % dead_port, "--class=miner", "--bot=wait:10"])
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + PAIR_C1,
		"--give=sword"])
	var t_late: int = Time.get_ticks_msec()
	if check(await _wait_files([dir.path_join("host.edited.marker")], STEP_WAIT_SEC), "pair: host edited the world"):
		var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=herbalist", "--bot=" + PAIR_LATE,
			"--test-perturb-generator"])
		note("pair: late joiner started %.1f s after the first client" % ((Time.get_ticks_msec() - t_late) / 1000.0))
		check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json"),
			dir.path_join("nohost.json")], STEP_WAIT_SEC), "pair: every instance wrote its result")
		await _reap()
		if not _load_results(dir, [host, c1, c2, dead]):
			return
		_expect_codes("pair", {host: 0, c1: 0, c2: 0, dead: NetSession.EXIT_FAILED})
		_check_agreement("pair", host, [c1, c2], 3)
		_check_late_joiner("pair", host, c2, true, 3)
		_check_pair_items(host, c1, c2)
		check(_flag(c1.result, "generator_match"), "pair/c1: an unperturbed joiner's generator matches the host's")
		check(str(dead.result.get("ended", "")).begins_with("failed: not admitted"),
			"pair: joining a port nobody listens on fails after the connect timeout (%s)" % dead.result.get("ended", ""))
		check(_log_has(c1, "edit floor 62,50=1 index=2"), "pair: the early client got the edit live")
		_traffic_notes("pair", host, c1, 2)
	else:
		await _reap()


func _session_four() -> void:
	var dir: String = _session_dir("four")
	var port: int = _port()
	if not check(port > 0, "four: free port"):
		return
	var host_flags: Array = ["--host=%d" % port, "--max-players=4", "--net-start=3",
		"--net-expect=4", "--net-expect-refused=1", "--bot=" + FOUR_HOST, "--test-snapshot-chunk-bytes=%d" % FOUR_CHUNK_BYTES,
		"--give=stone_a:5"]
	if not _use_path:
		host_flags.append("--test-allow-give")  # c2 and c3 ask for pickaxes (M3b)
	var host: Instance = _launch(dir, "host", host_flags)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "four: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + FOUR_C1])
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + FOUR_C2, "--give=pickaxe"])
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + FOUR_C3, "--give=pickaxe"])
	if not check(await _wait_files([dir.path_join("host.edited.marker"), dir.path_join("c1.json"),
			dir.path_join("c2.down.marker"), dir.path_join("c3.down.marker")], STEP_WAIT_SEC),
			"four: c1 left, the host edited the world, c2 and c3 went down"):
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
	_check_late_joiner("four", host, c4, false, 3)
	_check_four_race(host, [c1, c2, c3])
	_check_four_mining(dir, host, c2, c3, c4)
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
	var host_bot: String = "mark:editing;wait:5;stall:%d;%s;wait:30" % [STALL_MS, _edits_script(STALL_EDITS, STALL_EDIT_EVERY,
		STALL_DROP_EVERY)]
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2",
		"--test-snapshot-chunk-bytes=%d" % STALL_CHUNK_BYTES, "--bot=" + host_bot, "--give=stone_a:99"])
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
	# Edits while c2 streamed (floor edits and drops).
	var all_edits: int = STALL_EDITS + STALL_DROPS
	check_eq(_num(host.result, "edits"), float(all_edits), "stall: the host made %d edits (%d of them drops)" % [all_edits,
		STALL_DROPS])
	var host_drops: Array = host.result.get("drops", [])
	check_eq(host_drops.size(), STALL_DROPS, "stall: %d drops lie on the ground" % STALL_DROPS)
	for c: Instance in [c1, c2]:
		check_eq(_num(c.result, "edits"), float(all_edits), "stall/%s: log position %d (every edit)" % [c.name, all_edits])
		check_eq(c.result.get("drops", []), host_drops, "stall/%s: the same drops as the host" % c.name)
	var stream: Dictionary = _stream_for(host, c2)
	var catch_up: int = roundi(_num(stream, "catch_up_edits"))
	check(catch_up > 0, "stall/c2: edits made while its world streamed came after the welcome (%d catch-up edits)" % catch_up)
	var drops_in_snapshot: int = _log_int(c2, "drops=")
	check(drops_in_snapshot >= 0 and drops_in_snapshot < STALL_DROPS,
		"stall/c2: %d drops came in its snapshot, the other %d as edits while it streamed" % [drops_in_snapshot,
		STALL_DROPS - drops_in_snapshot])
	check(_num(stream, "chunks") > 300.0 and _num(c2.result, "snapshot_chunks") == _num(stream, "chunks"),
		"stall/c2: its world came in %s one-byte chunks" % stream.get("chunks"))
	note("stall/c2: world in %s chunks over %s ticks, snapshot at edit %s, %d edits after it sent after the welcome" % [
		stream.get("chunks"), stream.get("ticks"), stream.get("edit_position"), catch_up])


## A bot script of `count` floor edits (grass -> soil, each allowed by EditLog.check after the ones
## before it, on the seed-1 world), one every `every` ticks; after every `drop_every`-th (0 = none) one
## stone dropped (in place of a tick of waiting).
static func _edits_script(count: int, every: int, drop_every: int = 0) -> String:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var parts: PackedStringArray = []
	var origin: Vector2i = data.altar_rect.position + Vector2i(-10, data.altar_rect.size.y + 3)
	for y: int in range(origin.y, data.size.y):
		for x: int in range(origin.x, data.size.x):
			if parts.size() >= count:
				break
			var e: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.FLOOR, Vector2i(x, y), Terrain.SOIL)
			if EditLog.check(data, e).is_empty() and data.set_terrain(e.cell, e.value):
				if drop_every > 0 and (parts.size() + 1) % drop_every == 0:
					parts.append("edit:%d,%d,soil;drop:1;wait:%d" % [x, y, every - 2])
				else:
					parts.append("edit:%d,%d,soil;wait:%d" % [x, y, every - 1])
	return ";".join(parts)


## The host's record of the stream that sent `joiner` its world ({} if none). The last one for its
## slot: a late joiner can take the slot of a player who left (four). M3b: `kind` "join" (the world on
## joining) or "map" (a map it went to; `map` picks which, -1 any).
func _stream_for(host: Instance, joiner: Instance, kind: String = "join", map: int = -1) -> Dictionary:
	var slot: int = roundi(_num(joiner.result, "slot"))
	var streams: Array = host.result.get("streams", [])
	var found: Dictionary = {}
	for item: Variant in streams:
		var d: Dictionary = item
		if roundi(_num(d, "slot")) == slot and str(d.get("kind", "join")) == kind and (map < 0 or roundi(_num(d, "map")) == map):
			found = d
	return found


## M3b, see the file comment: two maps, travelling both ways, mining, late join while others are below.
func _session_cave() -> void:
	var dir: String = _session_dir("cave")
	var port: int = _port()
	if not check(port > 0, "cave: free port"):
		return
	var host_flags: Array = ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=miner", "--give=pickaxe,torch:5",
		"--bot=" + CAVE_HOST]
	if not _use_path:
		host_flags.append("--test-allow-give")
	var host: Instance = _launch(dir, "host", host_flags)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "cave: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--give=pickaxe,torch:3",
		"--bot=" + CAVE_C1])
	if not check(await _wait_files([dir.path_join("host.mined.marker"), dir.path_join("c1.mined.marker")], STEP_WAIT_SEC),
			"cave: both mined in the dungeon"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=herbalist", "--bot=" + CAVE_C2])
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], STEP_WAIT_SEC),
		"cave: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("cave", {host: 0, c1: 0, c2: 0})
	_check_agreement("cave", host, [c1, c2], 3)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	# Where everyone ended: the host and c2 below, c1 up.
	check(roundi(_num(host.result, "map")) == Config.MAP_DUNGEON and roundi(_num(c1.result, "map")) == Config.MAP_SURFACE
		and roundi(_num(c2.result, "map")) == Config.MAP_DUNGEON, "cave: the host and c2 end below, c1 on the surface")
	for inst: Instance in [host, c1, c2]:
		for slot: int in [hs, s1, s2]:
			var want: int = Config.MAP_SURFACE if slot == s1 else Config.MAP_DUNGEON
			check_eq(roundi(_num(_player(inst, slot), "map", -1.0)), want, "cave/%s: knows slot %d's map" % [inst.name, slot])
	# Drawn: each draws exactly the players on its own map.
	check(_flag(_player(host, s2), "drawn") and not _flag(_player(host, s1), "drawn"), "cave/host: draws c2, not c1 (up)")
	check(not _flag(_player(c1, hs), "drawn") and not _flag(_player(c1, s2), "drawn") and _flag(_player(c1, s1), "drawn"),
		"cave/c1: on the surface it draws only itself")
	check(_flag(_player(c2, hs), "drawn") and not _flag(_player(c2, s1), "drawn"), "cave/c2: draws the host below, not c1")
	# c1 alone on the surface while the host was below.
	var alone: Dictionary = _marker(dir, "c1", "alone")
	check(roundi(_num(alone, "map")) == Config.MAP_SURFACE and _seen_map(alone, hs) == Config.MAP_DUNGEON
		and not _seen_drawn(alone, hs), "cave/c1: while the host was below, c1 (surface) did not draw it %s" % alone)
	var host_down: Dictionary = _marker(dir, "host", "down")
	check(roundi(_num(host_down, "map")) == Config.MAP_DUNGEON and not _seen_drawn(host_down, s1),
		"cave/host: below, it did not draw c1 on the surface %s" % host_down)
	# c1 got none of the host's dungeon edits while up, and the dungeon as it was when it went down.
	var c1_log: PackedStringArray = _log_lines(c1)
	var entered_at: int = _first_line(c1_log, "map entered map=dungeon")
	var first_dungeon_edit: int = _first_line(c1_log, "map=1 world=")
	check(entered_at >= 0 and (first_dungeon_edit < 0 or first_dungeon_edit > entered_at),
		"cave/c1: no dungeon edit reached it before its map entry (entry line %d, first dungeon edit %d)" % [entered_at, first_dungeon_edit])
	var c1_entry: Dictionary = _stream_for(host, c1, "map", Config.MAP_DUNGEON)
	check(_num(c1_entry, "edit_position") >= 2.0, "cave/c1: its dungeon snapshot held the host's edits so far (%s)" % c1_entry.get("edit_position"))
	check(entered_at >= 0 and c1_log[entered_at].contains("torches=1") and _int_after(c1_log[entered_at], "cracked=") >= 6,
		"cave/c1: the snapshot had the host's torch and its six cracked tiles (%s)" % (c1_log[entered_at] if entered_at >= 0 else "?"))
	# Both mined; each saw the other's edits live.
	var host_log: PackedStringArray = _log_lines(host)
	check(_count_lines(host_log, "host mine slot=%d map=1" % hs) == 3 and _count_lines(host_log, "host mine slot=%d map=1" % s1) == 4,
		"cave: the host landed 3 swings (3x3), c1 4 (1x1)")
	check(_count_lines(c1_log, "edit wall %d,%d=0" % [CAVE_WEST.x, CAVE_WEST.y]) == 1, "cave/c1: saw the host break the rock west of the room live")
	check(_count_lines(host_log, "edit wall %d,%d=%d" % [CAVE_EAST.x, CAVE_EAST.y, Walls.pack(Walls.KIND_ROCK, 4)]) == 1
		and _count_lines(c1_log, "edit wall %d,%d=%d" % [CAVE_EAST.x, CAVE_EAST.y, Walls.pack(Walls.KIND_ROCK, 4)]) == 1,
		"cave: c1's fourth hit on the east rock (crack stage 2) on the host and back on c1")
	# c1's dungeon when it left = the host's after the same number of edits.
	var left: Array = c1.result.get("left_maps", [])
	var left_d: Dictionary = {}
	for item: Variant in left:
		var d: Dictionary = item
		if roundi(_num(d, "map")) == Config.MAP_DUNGEON:
			left_d = d
	check_eq(left.size(), 2, "cave/c1: left the surface (down) and the dungeon (up)")
	var at_edit: int = roundi(_num(left_d, "edits")) - 1
	var host_line: String = _line_with(host_log, "index=%d map=1 world=" % at_edit)
	check(not host_line.is_empty() and str(left_d.get("hash", "?")).left(12) == _word_after(host_line, "world="),
		"cave/c1: the dungeon it left (%d edits, %s) = the host's after edit %d (%s)" % [at_edit + 1, str(left_d.get("hash", "?")).left(12),
		at_edit, _word_after(host_line, "world=")])
	# c2: joined with both below, saw c1 come up, went down and got everything.
	check_eq(roundi(_num(c2.result, "others_on_welcome")), 2, "cave/c2: welcomed with two players below")
	var c2_alone: Dictionary = _marker(dir, "c2", "alone")
	check(not _seen_drawn(c2_alone, hs) and not _seen_drawn(c2_alone, s1) and _seen_map(c2_alone, s1) == Config.MAP_DUNGEON,
		"cave/c2: on the surface with both below it drew neither %s" % c2_alone)
	var c2_sees: Dictionary = _marker(dir, "c2", "sees")
	check(_seen_drawn(c2_sees, s1) and _seen_map(c2_sees, s1) == Config.MAP_SURFACE and not _seen_drawn(c2_sees, hs),
		"cave/c2: c1 came up the stairs and c2 draws it %s" % c2_sees)
	var c2_down: Dictionary = _marker(dir, "c2", "down")
	check(_seen_drawn(c2_down, hs) and not _seen_drawn(c2_down, s1), "cave/c2: below it draws the host, not c1 %s" % c2_down)
	var c2_entry: Dictionary = _stream_for(host, c2, "map", Config.MAP_DUNGEON)
	var host_d: Dictionary = _map_of(host.result, str(Config.MAP_DUNGEON))
	check(_num(c2_entry, "edit_position") >= _num(host_d, "edits") - 1.0 and _num(c2_entry, "edit_position") > 10.0,
		"cave/c2: its dungeon snapshot had every edit so far (%s of %s)" % [c2_entry.get("edit_position"), host_d.get("edits")])
	var c2_log: PackedStringArray = _log_lines(c2)
	var c2_entered: String = _line_with(c2_log, "map entered map=dungeon")
	check(c2_entered.contains("torches=2") and c2_entered.contains("drops=1") and _int_after(c2_entered, "cracked=") >= 1,
		"cave/c2: breaks, cracks, both torches and the drop came in its map snapshot (%s)" % c2_entered)
	check(_num(host.result, "travels") == 4.0 and _num(host.result, "map_entries") == 3.0,
		"cave: 4 travels (host down, c1 down and up, c2 down) and 3 map entries sent to clients (%s / %s)" % [
		host.result.get("travels"), host.result.get("map_entries")])
	var ops: Dictionary = host.result.get("ops", {})
	for slot: String in ops:
		var o: Dictionary = ops[slot]
		check_eq(o.get("refused", {"?": 1}), {}, "cave: no request of slot %s refused" % slot)
	_cave_traffic_notes(host, c1)


## M4b, see the file comment (run by tests/test_net_fight.gd).
func _session_fight() -> void:
	var dir: String = _session_dir("fight")
	var port: int = _port()
	if not check(port > 0, "fight: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=paladin",
		"--bot=" + FIGHT_HOST, FIGHT_HERETICS, "--test-start-hp=archer:12"], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "fight: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + FIGHT_C1], 100)
	if not check(await _wait_files([dir.path_join("host.ath1.marker")], 80.0), "fight: H2 and H3 down, c1 revived, the host at H1"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + FIGHT_C2], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 80.0),
		"fight: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("fight", {host: 0, c1: 0, c2: 0})
	_check_agreement("fight", host, [c1, c2], 3)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	var hits: Dictionary = _hits_by_heretic(lines)
	# H2: c1's arrows alone, from out of its sight.
	check(_hit_slots(hits, 2) == [s1] and _killed(lines, 2, s1), "fight: c1's arrows alone killed H2 (%s)" % [hits.get(2, [])])
	# c1 down by H3, the host kills H3, the host revives c1.
	check(_count_lines(lines, "host hurt slot=%d map=0 amount=%d hp=0 DOWN" % [s1, Config.HERETIC_DAMAGE]) == 1,
		"fight: one knife took c1 (12 HP) down")
	check(_killed(lines, 3, hs) and _count_lines(lines, "host revived slot=%d map=0 hp=%d" % [s1, Config.REVIVE_HP]) == 1,
		"fight: the host killed H3 and revived c1")
	# H1: everyone's, seen the same way.
	var h1_slots: Array = _hit_slots(hits, 1)
	check(h1_slots.has(hs) and h1_slots.has(s1) and _count_lines(lines, "heretic=1 ") > 0 and _killed_by_any(lines, 1),
		"fight: the host and c1 both hit H1 (%s) and it died" % [h1_slots])
	var h1_seq: Array = _hp_sequence(hits, 1)
	var c1_combat: Dictionary = c1.result.get("combat", {})
	var c2_combat: Dictionary = c2.result.get("combat", {})
	var c1_hp: Dictionary = c1_combat.get("foe_hp", {})
	var c2_hp: Dictionary = c2_combat.get("foe_hp", {})
	var c1_saw: Array = c1_hp.get("1", [])
	var c2_saw: Array = c2_hp.get("1", [])
	var c1_first: int = c1_saw[0] if not c1_saw.is_empty() else -1
	var c2_first: int = c2_saw[0] if not c2_saw.is_empty() else -1
	var c2_last: int = c2_saw.back() if not c2_saw.is_empty() else -1
	check(_follows_seq(c1_saw, h1_seq) and c1_saw.size() >= 3 and c1_first == Config.HERETIC_HP,
		"fight/c1: H1's HP as it saw it %s follows the host's %s" % [c1_saw, h1_seq])
	check(_follows_seq(c2_saw, h1_seq) and c2_first >= 0 and c2_first < Config.HERETIC_HP and c2_last == 0,
		"fight/c2 (late, mid-fight): it first saw H1 hurt (%s) and then the host's HP down to 0 (host %s)" % [c2_saw, h1_seq])
	var host_combat: Dictionary = host.result.get("combat", {})
	var host_maps: Dictionary = host_combat.get("maps", {})
	var host_surface: Dictionary = host_maps.get("0", {})
	for c: Instance in [c1, c2]:
		var cc: Dictionary = c.result.get("combat", {})
		check_eq(str(cc.get("hash", "")), str(host_surface.get("hash", "?")), "fight/%s: its last enemy view = the host's" % c.name)
		var msgs: Dictionary = cc.get("enemy_msgs", {})
		check(_num(msgs, "0") > 0.0 and _num(cc, "bad") == 0.0, "fight/%s: enemy batches came (%s), none malformed" % [c.name, msgs])
		var p: Dictionary = c.result.get("prediction", {})
		check_eq(_num(p, "vitals_corrections"), 0.0, "fight/%s: the prediction's own vitals never off the host's" % c.name)
	var p1: Dictionary = c1.result.get("prediction", {})
	check(_num(p1, "event_corrections") >= 2.0, "fight/c1: down and up were the host's events (%s)" % p1.get("event_corrections"))
	check(_log_has(c2, "c2 welcome slot=%d" % s2), "fight/c2: joined mid-fight")
	_fight_traffic_notes("fight", host, c1)


func _session_fight4() -> void:
	var dir: String = _session_dir("fight4")
	var port: int = _port()
	if not check(port > 0, "fight4: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=3", "--class=paladin",
		"--bot=" + FIGHT4_HOST, FIGHT4_HERETICS])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "fight4: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = [_launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + FIGHT4_C1]),
		_launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + FIGHT4_C2]),
		_launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + FIGHT4_C3])]
	var files: Array[String] = [dir.path_join("host.json")]
	for c: Instance in cs:
		files.append(dir.path_join(c.name + ".json"))
	check(await _wait_files(files, 80.0), "fight4: every instance wrote its result")
	await _reap()
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	if not _load_results(dir, everyone):
		return
	_expect_codes("fight4", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0})
	_check_agreement("fight4", host, cs, 4)
	var lines: PackedStringArray = _log_lines(host)
	check(_killed_by_any(lines, 1) and _killed_by_any(lines, 2), "fight4: both heretics died")
	var hits: Dictionary = _hits_by_heretic(lines)
	var slots: Dictionary = {}
	for id: int in [1, 2]:
		for s: Variant in _hit_slots(hits, id):
			slots[s] = true
	check(slots.size() >= 3, "fight4: at least three players landed hits (%s)" % [slots.keys()])
	var host_combat: Dictionary = host.result.get("combat", {})
	var host_maps: Dictionary = host_combat.get("maps", {})
	var host_surface: Dictionary = host_maps.get("0", {})
	for c: Instance in cs:
		var cc: Dictionary = c.result.get("combat", {})
		var seen: Dictionary = cc.get("foe_hp", {})
		for id: int in [1, 2]:
			var saw: Array = seen.get(str(id), [])
			check(_follows_seq(saw, _hp_sequence(hits, id)), "fight4/%s: heretic %d's HP %s follows the host's %s" % [c.name, id,
				saw, _hp_sequence(hits, id)])
		check_eq(str(cc.get("hash", "")), str(host_surface.get("hash", "?")), "fight4/%s: its last enemy view = the host's" % c.name)
		var p: Dictionary = c.result.get("prediction", {})
		check_eq(_num(p, "vitals_corrections"), 0.0, "fight4/%s: the prediction's own vitals never off the host's" % c.name)
	_fight_traffic_notes("fight4", host, cs[0])


## M4-fix (run by tests/test_net_fight.gd): a client with a lagging, lossy link (round trip 120 ms, 5 % loss)
## that stands still between the heretic's strikes. Every hit lands on a client whose timers had run out (it
## sent no frames): the host never steps it itself and its prediction takes each hit as the host's event
## only (no vitals correction). Before (M4b's quiet-client rule) such a hit started host steps at once.
func _session_fightlag() -> void:
	var dir: String = _session_dir("fightlag")
	var port: int = _port()
	if not check(port > 0, "fightlag: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=1", "--class=cleric",
		"--bot=" + FIGHTLAG_HOST, FIGHTLAG_HERETIC])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "fightlag: host listens"):
		await _reap()
		return
	var c1_flags: Array = ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + FIGHTLAG_C1]
	c1_flags.append_array(FIGHTLAG_LINK)
	var c1: Instance = _launch(dir, "c1", c1_flags)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json")], 80.0), "fightlag: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1]):
		return
	_expect_codes("fightlag", {host: 0, c1: 0})
	_check_agreement("fightlag", host, [c1], 2)
	var s1: int = roundi(_num(c1.result, "slot"))
	var hurt: int = _count_lines(_log_lines(host), "host hurt slot=%d map=0 amount=%d" % [s1, Config.HERETIC_DAMAGE])
	check(hurt >= 3, "fightlag: the heretic struck the standing c1 %d times" % hurt)
	var ops: Dictionary = host.result.get("ops", {})
	var o1: Dictionary = ops.get(str(s1), {})
	check_eq(_num(o1, "host_steps"), 0.0, "fightlag: the host never stepped the lagging client itself")
	var p: Dictionary = c1.result.get("prediction", {})
	check(_num(p, "vitals_corrections") == 0.0 and _num(p, "event_corrections") >= float(hurt),
		"fightlag/c1: each hit was the host's event only (events %s, vitals corrections %s)" % [p.get("event_corrections"),
		p.get("vitals_corrections")])
	var link: Dictionary = c1.result.get("link", {})
	note("fightlag: c1 hurt %d times standing still; link %s" % [hurt, link])


## Host log "hit slot=<s> map=<m> heretic=<id> amount=<n> hp=<hp>" lines: heretic id -> [[slot, hp], ...] in order.
static func _hits_by_heretic(lines: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for line: String in lines:
		if not line.contains("host hit slot="):
			continue
		var id: int = _int_after(line, "heretic=")
		var list: Array = out.get(id, [])
		list.append([_int_after(line, "slot="), _int_after(line, " hp=")])
		out[id] = list
	return out


## The slots that hit heretic `id` (each once, sorted).
static func _hit_slots(hits: Dictionary, id: int) -> Array:
	var seen: Dictionary = {}
	var list: Array = hits.get(id, [])
	for h: Variant in list:
		var pair: Array = h
		seen[pair[0]] = true
	var out: Array = seen.keys()
	out.sort()
	return out


## The host's HP of heretic `id` hit after hit, from its full HP.
static func _hp_sequence(hits: Dictionary, id: int) -> Array:
	var out: Array = [Config.HERETIC_HP]
	var list: Array = hits.get(id, [])
	for h: Variant in list:
		var pair: Array = h
		out.append(pair[1])
	return out


static func _killed(lines: PackedStringArray, id: int, slot: int) -> bool:
	for line: String in lines:
		if line.contains("host hit slot=%d " % slot) and line.contains("heretic=%d " % id) and line.contains("KILLED"):
			return true
	return false


static func _killed_by_any(lines: PackedStringArray, id: int) -> bool:
	for line: String in lines:
		if line.contains("host hit slot=") and line.contains("heretic=%d " % id) and line.contains("KILLED"):
			return true
	return false


## `seen` (a client's HP values in order, repeats dropped) is part of `all` (the host's) in the same order
## and ends where the host's does (a batch may miss a value between two hits, never invent or reorder one).
static func _follows_seq(seen: Array, all: Array) -> bool:
	if seen.is_empty() or all.is_empty() or seen.back() != all.back():
		return false
	var i: int = 0
	for v: Variant in seen:
		while i < all.size() and all[i] != v:
			i += 1
		if i >= all.size():
			return false
	return true


## M4b traffic: the fight buckets (and the idle one with heretics standing).
func _fight_traffic_notes(label: String, host: Instance, client: Instance) -> void:
	var hs: Dictionary = host.result.get("stats", {})
	var cs: Dictionary = client.result.get("stats", {})
	for key: String in hs:
		if key.begins_with("fight") or key.begins_with("0/") or key.begins_with("act"):
			var b: Dictionary = hs[key]
			var c: Dictionary = cs.get(key, {})
			note("%s host %s: sends %s B/s (%s with UDP/IP) in %s pkt/s over %s s; %s receives %s B/s there" % [label, key,
				b.get("sent_bps"), b.get("wire_sent_bps"), b.get("packets_ps"), b.get("sec"), client.name, c.get("received_bps", "-")])
	var hc: Dictionary = host.result.get("combat", {})
	note("%s host combat: enemy batches %s, enemy keyframes %s (urgent %s), shot messages %s" % [label, hc.get("enemy_batches_sent"),
		hc.get("enemy_keyframes_sent"), hc.get("enemy_urgent_sends"), hc.get("shot_messages_sent")])


## A result's entry for map `key` ({} if none).
static func _map_of(result: Dictionary, key: String) -> Dictionary:
	var maps: Dictionary = result.get("maps", {})
	var m: Dictionary = maps.get(key, {})
	return m


## Lines of an instance's log.
func _log_lines(inst: Instance) -> PackedStringArray:
	return FileAccess.get_file_as_string(inst.log_path).split("\n")


func _first_line(lines: PackedStringArray, text: String) -> int:
	for i: int in lines.size():
		if lines[i].contains(text):
			return i
	return -1


func _line_with(lines: PackedStringArray, text: String) -> String:
	var i: int = _first_line(lines, text)
	return lines[i] if i >= 0 else ""


func _count_lines(lines: PackedStringArray, text: String) -> int:
	var n: int = 0
	for line: String in lines:
		if line.contains(text):
			n += 1
	return n


static func _word_after(line: String, key: String) -> String:
	var at: int = line.find(key)
	if at < 0:
		return ""
	return line.substr(at + key.length()).get_slice(" ", 0).strip_edges()


static func _int_after(line: String, key: String) -> int:
	var w: String = _word_after(line, key)
	return w.to_int() if w.is_valid_int() else -1


## A marker file's JSON (what the instance saw then: SessionReport.seen), {} if none.
func _marker(dir: String, name: String, marker: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("%s.%s.marker" % [name, marker])))
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func _seen_player(seen: Dictionary, slot: int) -> Dictionary:
	var players: Dictionary = seen.get("players", {})
	var p: Dictionary = players.get(str(slot), {})
	return p


static func _seen_drawn(seen: Dictionary, slot: int) -> bool:
	return _flag(_seen_player(seen, slot), "drawn")


static func _seen_map(seen: Dictionary, slot: int) -> int:
	return roundi(_num(_seen_player(seen, slot), "map", -1.0))


## M3b traffic: idle on two maps, mining with the other player up (it gets the states, not the edits),
## both mining below, and the map entries.
func _cave_traffic_notes(host: Instance, c1: Instance) -> void:
	var hs: Dictionary = host.result.get("stats", {})
	var cs: Dictionary = c1.result.get("stats", {})
	for key: String in hs:
		if key.contains("split") or key.begins_with("act") or key == "entering" or key.begins_with("0/"):
			var b: Dictionary = hs[key]
			var c: Dictionary = cs.get(key, {})
			note("cave host %s: sends %s B/s (%s with UDP/IP) in %s pkt/s over %s s; c1 receives %s B/s there" % [key,
				b.get("sent_bps"), b.get("wire_sent_bps"), b.get("packets_ps"), b.get("sec"), c.get("received_bps", "-")])
	var idle_split: Dictionary = hs.get("0/2 split", {})
	var act_split: Dictionary = hs.get("act1/2 split", {})
	if check(not idle_split.is_empty() and _num(idle_split, "sec") >= 1.0, "cave: at least 1 s with both idle on two maps (%s s)" % idle_split.get("sec")):
		check(_num(idle_split, "sent_bps", 1e9) < 0.25 * _num(act_split, "sent_bps", 0.0),
			"cave: idle on two maps is quiet (%s B/s vs %s B/s while the host mines)" % [idle_split.get("sent_bps"), act_split.get("sent_bps")])


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

## M3b: per map. Every instance's maps (the host: all; a client: the one it is on) are drawn as their data
## says; each client's map equals the host's copy of it.
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
		var maps: Dictionary = r.get("maps", {})
		check(maps.has(str(roundi(_num(r, "map")))), "%s/%s: has the map it is on (%s)" % [label, inst.name, maps.keys()])
		for key: Variant in maps:
			var mr: Dictionary = maps[key]
			var dungeon: bool = str(key) == str(Config.MAP_DUNGEON)
			var view: Dictionary = mr.get("view", {})
			check(_num(view, "mismatches") == 0.0 and _num(view, "missing") == 0.0 and (dungeon or _num(view, "fallbacks") == 0.0)
				and _num(view, "overlay_mismatches", 0.0) == 0.0, "%s/%s: map %s drawn = data %s" % [label, inst.name, key, view])
			var items: Dictionary = mr.get("items_view", {})
			check(_num(items, "mismatches") == 0.0 and (dungeon or _num(items, "gatherables") > 0.0),
				"%s/%s: map %s gatherables and drops drawn = data %s" % [label, inst.name, key, items])
			var fx: Dictionary = mr.get("fixtures", {})
			check_eq(_num(fx, "mismatches"), 0.0, "%s/%s: map %s placeables drawn = data %s" % [label, inst.name, key, fx])
		check_eq(r.get("bad_messages", -1), 0, "%s/%s: no malformed messages" % [label, inst.name])
		check_eq(r.get("unknown_senders", -1), 0, "%s/%s: no input from strangers" % [label, inst.name])
	for c: Instance in clients:
		var r: Dictionary = c.result
		check_eq(r.get("ended", ""), "finished", "%s/%s: finished" % [label, c.name])
		check_eq(r.get("positions_hash", ""), h.get("positions_hash", "?"), "%s/%s: positions = host (%s vs %s)" % [
			label, c.name, JSON.stringify(r.get("players", [])), JSON.stringify(h.get("players", []))])
		var map_key: String = str(roundi(_num(r, "map")))
		var mine: Dictionary = _map_of(r, map_key)
		var hosts: Dictionary = _map_of(h, map_key)
		check(not mine.is_empty() and not hosts.is_empty(), "%s/%s: map %s in both results" % [label, c.name, map_key])
		check_eq(mine.get("hash", ""), hosts.get("hash", "?"), "%s/%s: map %s = host's" % [label, c.name, map_key])
		check_eq(mine.get("view_hash", ""), hosts.get("view_hash", "?"), "%s/%s: draws the host's map %s (view hash)" % [label, c.name, map_key])
		check_eq(mine.get("edits", -1), hosts.get("edits", -2), "%s/%s: map %s log position = host's" % [label, c.name, map_key])
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
		check_eq(_num(p, "action_corrections"), 0.0, "%s/%s: the host's body actions = the predicted ones" % [label, c.name])
		check_eq(mine.get("gatherables", -1), hosts.get("gatherables", -2), "%s/%s: the same gatherables left" % [label, c.name])
		check_eq(mine.get("drops", []), hosts.get("drops", []), "%s/%s: the same drops" % [label, c.name])
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
			"%s: slot %d's %s (map %d) went out at %d chunks per tick (%d chunks in %d ticks)" % [label, roundi(_num(st, "slot")),
			st.get("kind", "join"), roundi(_num(st, "map", 0.0)), Config.NET_SNAPSHOT_CHUNKS_PER_TICK, roundi(chunks), roundi(_num(st, "ticks"))])
	check(streams.size() >= clients.size(), "%s: the host recorded a stream for every joiner (%d)" % [label, streams.size()])


## A late joiner: its world is the host's edited world, received as a snapshot with the log
## position after the edit; its own generator only shows up in the diagnostic (`perturbed`: it makes
## another world, and that does not matter).
func _check_late_joiner(label: String, host: Instance, late: Instance, perturbed: bool, position: int) -> void:
	var r: Dictionary = late.result
	var h: Dictionary = host.result
	var who: String = "%s/%s" % [label, late.name]
	check_eq(_num(_stream_for(host, late), "edit_position"), float(position),
		"%s: its snapshot held the first %d edits (they came inside it)" % [who, position])
	var rs: Dictionary = _map_of(r, str(Config.MAP_SURFACE))
	var hs: Dictionary = _map_of(h, str(Config.MAP_SURFACE))
	check_eq(rs.get("edits", -1), hs.get("edits", -2), "%s: then every later edit (log position %s)" % [who, hs.get("edits")])
	check_eq(rs.get("hash", ""), hs.get("hash", "?"), "%s: the host's world" % who)
	check_ne(rs.get("hash", ""), h.get("generator_hash", "?"), "%s: the edited world, not the bare seed" % who)
	check_eq(r.get("host_generator_hash", ""), h.get("generator_hash", "?"), "%s: the welcome carried the host's generator hash" % who)
	if perturbed:
		var own: String = r.get("generator_hash", "")
		var hosts: String = h.get("generator_hash", "?")
		check(not _flag(r, "generator_match") and own != hosts,
			"%s: its own generator makes another world (perturbed) and it still has the host's" % who)
		check(_log_has(late, "generator=differs"), "%s: the diagnostic says the generators differ" % who)
	else:
		check(_flag(r, "generator_match"), "%s: its own generator matches the host's (same build, same machine)" % who)
	check(_log_has(late, "welcome slot=") and _log_has(late, "edits=%d" % position), "%s: welcome logged the edit position" % who)
	var join_ms: float = _num(r, "join_ms")
	check(join_ms > 0.0 and join_ms < 5000.0, "%s: world ready %.1f ms after connecting" % [who, join_ms])
	note("%s late join: world %s B packed (%s B raw) in %s chunk(s), ready %.1f ms after connecting (check + decode + draw %.1f ms)" % [
		who, r.get("snapshot_bytes"), r.get("snapshot_raw"), r.get("snapshot_chunks"), join_ms, _num(r, "world_build_ms")])


## pair (M2b): held items and actions seen across, the gatherable gone everywhere, the drop in the
## late joiner's snapshot, the herbalist's FINE herb, inventories as the host keeps them.
func _check_pair_items(host: Instance, c1: Instance, c2: Instance) -> void:
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	# Held items: everyone agrees on what each player holds.
	for inst: Instance in [host, c1, c2]:
		check_eq(_player(inst, hs).get("held", "?"), "stone_a", "pair/%s: the host holds the stones" % inst.name)
		check_eq(_player(inst, s1).get("held", "?"), "sword", "pair/%s: c1 holds the sword it asked for" % inst.name)
	# Actions: the host simulated c1's sword swings, c1 saw the host's pickaxe swings.
	var host_saw: Dictionary = _player(host, s1).get("actions", {})
	var c1_saw: Dictionary = _player(c1, hs).get("actions", {})
	var c1_own: Dictionary = _player(c1, s1).get("actions", {})
	var host_own: Dictionary = _player(host, hs).get("actions", {})
	check(_num(host_saw, "sword") >= 2.0 and _num(c1_own, "sword") == _num(host_saw, "sword"),
		"pair: c1's sword swings, predicted by c1 and run by the host (%s / %s)" % [c1_own, host_saw])
	check(_num(c1_saw, "pickaxe") >= 2.0 and _num(c1_saw, "pickaxe") == _num(host_own, "pickaxe"),
		"pair: c1 saw every pickaxe swing of the host (%s of %s)" % [c1_saw, host_own])
	check(_log_has(host, "host action slot=%d item=sword action=sword" % s1), "pair: the host logged c1's sword action")
	# c1 stood still and aimed south at the end: the look alone turned it, on c1 and on the host.
	for inst: Instance in [host, c1, c2]:
		check_eq(_num(_player(inst, s1), "facing", -1.0), float(RigData.Dir.SOUTH),
			"pair/%s: c1 faces south (turned by its look while standing)" % inst.name)
	var all_ops: Dictionary = host.result.get("ops", {})
	var c1_ops: Dictionary = all_ops.get(str(s1), {})
	var c1_done: Dictionary = c1_ops.get("done", {})
	check_eq(_num(c1_done, "select", 0.0), 3.0, "pair: the host handled c1's 3 hotbar selects (one per frame)")
	# The gatherable the host picked: gone on c1 live, gone in c2's snapshot, and everyone agrees.
	var herb: String = "at=%d,%d" % [PAIR_HERB.x, PAIR_HERB.y]
	check(_log_has(host, "host pickup slot=%d item=wild_buff count=1 grade=common %s" % [hs, herb]),
		"pair: the host (paladin) picked the wild buff, common grade")
	check(_log_has(c1, "edit vegetation %d,%d=0" % [PAIR_HERB.x, PAIR_HERB.y]), "pair/c1: saw the herb vanish (live edit)")
	check(_log_has(host, "host drop slot=%d item=stone_a count=5 grade=none %s" % [hs, herb]), "pair: the host dropped 5 stones")
	check(_log_has(c1, "edit drop+ "), "pair/c1: saw the drop appear (live edit)")
	var all: int = roundi(_num(host.result, "gatherables"))
	check(_log_has(c2, "gatherables=%d drops=1" % (all + 1)),
		"pair/c2: its snapshot already lacked the picked herb and held the drop (welcome: %d gatherables, 1 drop)" % (all + 1))
	# c2 picked the drop and a herb: the herbalist's herb is FINE.
	check(_log_has(host, "host pickup slot=%d item=stone_a count=5 grade=none %s" % [s2, herb]), "pair/c2: picked up the drop")
	check(_log_has(host, "host pickup slot=%d item=wild_buff count=1 grade=fine at=%d,%d" % [s2, PAIR_FINE_HERB.x,
		PAIR_FINE_HERB.y]), "pair/c2: the herbalist's herb is FINE (● gameplay-design §3.4)")
	check_eq(host.result.get("drops", ["?"]), [], "pair: no drop left")
	# Inventories: the host's copy = what each owner shows.
	for pair: Array in [[c1, s1], [c2, s2]]:
		var c: Instance = pair[0]
		var slot: int = pair[1]
		check_eq(_player(c, slot).get("inventory", "?"), _player(host, slot).get("inventory", "!"),
			"pair/%s: its inventory = the host's copy (%s)" % [c.name, _player(host, slot).get("inventory", "")])
		check(_num(c.result, "inventories") >= 1.0, "pair/%s: got its inventory from the host" % c.name)
	# M4b: and its class weapon in the last hotbar slot, which the host gave it when it joined.
	check_eq(_player(c2, s2).get("inventory", ""), "0:stone_a x5, 1:wild_buff x1 (fine), %d:sickle x1" % Config.START_WEAPON_SLOT,
		"pair/c2: what it picked up (and its start weapon)")
	var ops: Dictionary = host.result.get("ops", {})
	for slot: String in ops:
		var o: Dictionary = ops[slot]
		check_eq(o.get("refused", {"?": 1}), {}, "pair: no request of slot %s refused" % slot)
	note("pair items: host saw c1 %s, c1 saw the host %s; %d gatherables left" % [host_saw, c1_saw, all])


## four (M2b): three clients press F on the host's 5 stones every tick from before they land:
## exactly one gets them, the spam is refused as "rate", the misses as "nothing there".
func _check_four_race(host: Instance, clients: Array[Instance]) -> void:
	var drop: String = "at=%d,%d" % [FOUR_DROP.x, FOUR_DROP.y]
	check(_log_has(host, "host drop slot=0 item=stone_a count=5 grade=none %s" % drop), "four: the host dropped 5 stones")
	check_eq(_log_count(host, "item=stone_a count=5 grade=none %s" % drop) - 1, 1, "four: exactly one pickup of them")
	var winners: Array[String] = []
	var host_log: PackedStringArray = _log_lines(host)
	for c: Instance in clients:
		var slot: int = roundi(_num(c.result, "slot"))
		if _count_lines(host_log, "host pickup slot=%d item=stone_a count=5 grade=none %s" % [slot, drop]) == 1:
			winners.append(c.name)
	check(winners.size() == 1, "four: exactly one client got the 5 stones (%s)" % [winners])
	var ops: Dictionary = host.result.get("ops", {})
	var rate: int = 0
	var nothing: int = 0
	var done: int = 0
	for slot: String in ops:
		if slot == "0":
			continue
		var o: Dictionary = ops[slot]
		var refused: Dictionary = o.get("refused", {})
		var ok: Dictionary = o.get("done", {})
		rate += roundi(_num(refused, "rate", 0.0))
		nothing += roundi(_num(refused, WorldItems.WHY_NOTHING, 0.0))
		done += roundi(_num(ok, "pickup", 0.0))
	check(rate > 0 and nothing > 0 and done <= 1, "four: spammed F refused as rate (%d) and nothing there (%d), %d pickup(s) by the clients still in" % [
		rate, nothing, done])
	note("four race: %s got the stones; host refused %d requests as rate, %d as nothing there" % [winners, rate, nothing])


## four (M3b): c2 and c3 went down (the dungeon in 32-byte chunks over several ticks), swung at the same
## rock from two sides until it broke: exactly one break, the stone to the one whose hit broke it, both
## saw it; c4 joined while they were below and drew neither.
func _check_four_mining(dir: String, host: Instance, c2: Instance, c3: Instance, c4: Instance) -> void:
	var host_log: PackedStringArray = _log_lines(host)
	var s2: int = roundi(_num(c2.result, "slot"))
	var s3: int = roundi(_num(c3.result, "slot"))
	var rock: String = "edit wall %d,%d=0 " % [FOUR_ROCK.x, FOUR_ROCK.y]
	check_eq(_count_lines(host_log, rock), 1, "four: the rock both swung at broke exactly once")
	# The swing that broke it: the host logs a swing's edits, then the swing ("mine slot=..").
	var breaker: int = -1
	var broke_at: int = _first_line(host_log, rock)
	for i: int in range(maxi(broke_at, 0), host_log.size()):
		if broke_at >= 0 and host_log[i].contains("host mine slot="):
			breaker = _int_after(host_log[i], "slot=")
			break
	var landed: Dictionary[int, PackedInt32Array] = {s2: PackedInt32Array(), s3: PackedInt32Array()}
	var broken: Dictionary[int, int] = {s2: 0, s3: 0}
	for line: String in host_log:
		if not line.contains("host mine slot="):
			continue
		var slot: int = _int_after(line, "slot=")
		if landed.has(slot):
			landed[slot].append(_int_after(line, "tick="))
			if line.contains("broken=1"):
				broken[slot] += 1
	check(breaker == s2 or breaker == s3, "four: one of the two broke it (slot %d)" % breaker)
	check(landed[s2].size() >= 2 and landed[s3].size() >= 2, "four: both landed hits on it (c2 %d, c3 %d)" % [landed[s2].size(),
		landed[s3].size()])
	var same_tick: int = 0
	for t: int in landed[s2]:
		if landed[s3].has(t):
			same_tick += 1
	for c: Instance in [c2, c3]:
		var slot: int = roundi(_num(c.result, "slot"))
		var stones: int = _stones(str(_player(host, slot).get("inventory", "")))
		var won_race: bool = _count_lines(host_log, "host pickup slot=%d item=stone_a count=5" % slot) == 1
		check_eq(stones, (5 if won_race else 0) + broken[slot],
			"four/%s: its stones = the race's %d + one per tile it broke (%d)" % [c.name, 5 if won_race else 0, broken[slot]])
		check(_count_lines(_log_lines(c), rock) == 1, "four/%s: saw the break live" % c.name)
		var entry: Dictionary = _stream_for(host, c, "map", Config.MAP_DUNGEON)
		check(_num(entry, "chunks") > float(Config.NET_SNAPSHOT_CHUNKS_PER_TICK) and _num(entry, "ticks") >= 2.0,
			"four/%s: the dungeon came in %s chunks of %d B over %s ticks" % [c.name, entry.get("chunks"), FOUR_CHUNK_BYTES, entry.get("ticks")])
	check_eq(roundi(_num(c4.result, "others_on_welcome")), 2, "four/c4: welcomed while c2 and c3 were below")
	check(not _flag(_player(c4, s2), "drawn") and not _flag(_player(c4, s3), "drawn") and _flag(_player(c4, 0), "drawn"),
		"four/c4: draws the host, not the two below")
	note("four mining: slot %d broke the rock; c2 landed at ticks %s, c3 at %s (%d tick(s) with both)" % [breaker, landed[s2],
		landed[s3], same_tick])


static func _stones(inventory: String) -> int:
	var n: int = 0
	for part: String in inventory.split(", "):
		if part.contains("stone_a x"):
			n += part.get_slice(" x", 1).to_int()
	return n


## A player entry of an instance's result by slot ({} if none).
func _player(inst: Instance, slot: int) -> Dictionary:
	var players: Array = inst.result.get("players", [])
	for item: Variant in players:
		var d: Dictionary = item
		if roundi(_num(d, "slot")) == slot:
			return d
	return {}


## How many lines of the instance's log contain `text`.
func _log_count(inst: Instance, text: String) -> int:
	var n: int = 0
	for line: String in FileAccess.get_file_as_string(inst.log_path).split("\n"):
		if line.contains(text):
			n += 1
	return n


## The number right after `key` in the instance's welcome line (-1 if none).
func _log_int(inst: Instance, key: String) -> int:
	for line: String in FileAccess.get_file_as_string(inst.log_path).split("\n"):
		if line.contains(" welcome ") and line.contains(key):
			var rest: String = line.substr(line.find(key) + key.length())
			var digits: String = ""
			for ch: String in rest:
				if not ch.is_valid_int():
					break
				digits += ch
			return digits.to_int() if not digits.is_empty() else -1
	return -1


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
	# M2b: while someone plays a body action ("act<n>/<players>") and around requests ("req/<players>").
	for key: String in hs:
		if key.begins_with("act") or key.begins_with("req"):
			var a: Dictionary = hs[key]
			note("%s host %s: sends %s B/s (%s B/s with UDP/IP) in %s pkt/s, receives %s B/s, over %s s" % [label, key,
				a.get("sent_bps"), a.get("wire_sent_bps"), a.get("packets_ps"), a.get("received_bps"), a.get("sec")])
	for key: String in cs:
		if key.begins_with("act") or key.begins_with("req"):
			var a2: Dictionary = cs[key]
			note("%s client %s %s: sends %s B/s (%s B/s with UDP/IP), receives %s B/s, over %s s" % [label, client.name, key,
				a2.get("sent_bps"), a2.get("wire_sent_bps"), a2.get("received_bps"), a2.get("sec")])
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
## M4b: every instance runs without heretic spawns unless `spawns` (the M2b / M3b sessions test what they
## always tested; the combat sessions place their heretics with --test-heretic, or turn spawns on).
func _launch(dir: String, name: String, flags: Array, timeout_sec: int = INSTANCE_TIMEOUT_SEC, spawns: bool = false) -> Instance:
	var test_flags: Array = ["--net-out=" + dir, "--net-name=" + name, "--net-timeout=%d" % timeout_sec]
	if not spawns:
		test_flags.append("--test-no-spawns")
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
