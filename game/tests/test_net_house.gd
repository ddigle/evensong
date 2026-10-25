extends "res://tests/test_net_session.gd"
## M7c: building, doors and a heretic at the walls in a real session (separate processes over localhost ENet, like
## tests/test_net_session.gd, whose helpers and checks this file uses). Seed 1, spawns off.
##   house  host (paladin) + c1 (miner) + a late c2 (archer). The room south of the light (tests/test_net_build.gd's
##          ROOM_*) stands but for three walls and its door (--test-build, before anyone joins). The host builds the top
##          wall's gap from outside, c1 the two bottom-right walls through the wire, the host walks in through the gap and
##          puts the door in from inside, opens it and walks out; c1 walks in through the door, then the host. c1 walks
##          out next to the doorway: the host's F to close it is refused (someone is too close, M7c); c1 walks farther and
##          the door closes; c1 walks into it and is stopped where the host stops it; the host opens it once c1 stands
##          still, c1 comes in to the far corner and the host shuts it. A heretic brought in outside never reaches anyone in
##          the closed room. c2 joins then and gets the walls and the closed door in its snapshot.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=house).

## The room's pieces put down before anyone joins: every wall but the top's (63,57) and the bottom right two; no door.
const HOUSE_BUILD: String = ("--test-build=60,57:wall/61,57:wall/62,57:wall/64,57:wall/65,57:wall/60,58:wall/65,58:wall/" +
	"60,59:wall/65,59:wall/60,60:wall/65,60:wall/60,61:wall/62,61:wall/63,61:wall")
const HOUSE_HOST_GIVE: String = "--give=stone_wall:6,door:2"
const HOUSE_HOST: String = ("wait:20;select:1;walkto:60,50;walkto:63,52;walkto:63,56;aimat:63,57;use:1;wait:20;" +
	"walkto:58,56;walkto:58,63;walkto:61,63;waitwall:64,61,wall;waitwall:65,61,wall;waitat:68,66;" +
	"walkto:61,60;select:2;aimat:61,61;use:1;wait:20;mark:door;aimat:61,61;pick;wait:20;mark:open;aim:off;" +
	"walkto:61,63;walkto:63,64;waitat:64,59;walkto:61,63;walkto:61,60;walkto:62,60;mark:in;" +
	"waitat:61,63;wait:30;aimat:61,61;pick;wait:20;mark:refused;waitat:61,66;aimat:61,61;pick;wait:20;mark:closed;" +
	"waitat:61,63;wait:200;aimat:61,61;pick;wait:20;waitat:64,59;wait:10;aimat:61,61;pick;wait:20;mark:shut;aim:off;" +
	"heretic:67,63;wait:420;mark:watched;wait:30")
const HOUSE_C1_GIVE: String = "--give=stone_wall:6"
const HOUSE_C1: String = ("select:1;walkto:68,52;walkto:66,62;walkto:65,62;aimat:64,61;use:1;wait:20;walkto:66,62;" +
	"aimat:65,61;use:1;wait:20;aim:off;walkto:66,64;walkto:68,66;mark:built;" +
	"waitwall:61,61,open;walkto:65,63;walkto:61,63;walkto:61,60;walkto:64,59;mark:inside;" +
	"waitat:62,60;wait:30;walkto:61,60;walkto:61,63;mark:near;wait:150;walkto:61,66;mark:far;" +
	"waitwall:61,61,door;walkto:61,60,150;mark:blocked;waitwall:61,61,open;walkto:61,60;walkto:64,59;mark:back;wait:700")
const HOUSE_C2: String = "wait:30;mark:seen;move:1,0,20;move:-1,0,20;wait:30"
## Walls when the room is whole (14 put down + 3 built) and its door.
const HOUSE_WALLS: int = 17


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("house_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("house"):
		await _session_house()
	_check_logs()
	note("house session took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_house() -> void:
	var dir: String = _session_dir("house")
	var port: int = _port()
	if not check(port > 0, "house: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=paladin",
		"--test-allow-give", HOUSE_HOST_GIVE, HOUSE_BUILD, "--bot=" + HOUSE_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "house: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", HOUSE_C1_GIVE, "--bot=" + HOUSE_C1], 100)
	if not check(await _wait_files([dir.path_join("host.shut.marker"), dir.path_join("c1.back.marker")], 80.0),
			"house: the room built, walked through, the door shut with both inside"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + HOUSE_C2], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 80.0),
		"house: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("house", {host: 0, c1: 0, c2: 0})
	_check_agreement("house", host, [c1, c2], 3)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check_eq(_count_lines(lines, "host build slot=%d map=0 piece=stone_wall cost=2 at=63,57" % hs), 1, "house: the host built the top wall")
	check(_count_lines(lines, "host build slot=%d map=0 piece=stone_wall cost=2 at=64,61" % s1) == 1
		and _count_lines(lines, "host build slot=%d map=0 piece=stone_wall cost=2 at=65,61" % s1) == 1,
		"house: c1's two walls built by the host from c1's requests")
	check_eq(_count_lines(lines, "host build slot=%d map=0 piece=door cost=2 at=61,61" % hs), 1, "house: the host put the door in")
	check_eq(_count_lines(lines, "host door slot=%d map=0 open at=61,61" % hs), 2, "house: the door opened twice")
	check_eq(_count_lines(lines, "host door slot=%d map=0 closed at=61,61" % hs), 2, "house: and closed twice")
	check(_line_with(lines, "host request_refused slot=%d door map=0 at=61,61" % hs).contains(Building.WHY_NEAR),
		"house: closing it with c1 next to the doorway was refused (%s)" % _line_with(lines, "request_refused slot=%d door" % hs))
	for m: String in ["built", "inside", "near", "far", "blocked", "back"]:
		check(FileAccess.file_exists(dir.path_join("c1.%s.marker" % m)), "house/c1: reached %s" % m)
	# Where the closed door stopped c1 (its own machine's feet when it marked "blocked"): the door face's lower edge.
	var feet: PackedStringArray = str(_marker(dir, "c1", "blocked").get("feet", "")).split(",")
	var edge: float = (61 + 2) * Config.TILE + Config.FEET_HEIGHT
	check(feet.size() == 2 and absf(feet[0].to_float() - (61 * Config.TILE + Config.TILE / 2.0)) < 0.7
		and feet[1].to_float() >= edge - 0.01 and feet[1].to_float() <= edge + Config.WALK_SPEED / Config.NET_TICK_RATE + 0.01,
		"house/c1: the closed door stopped it at its face's lower edge, y %.0f (%s)" % [edge, feet])
	check(_count_lines(lines, "host heretic map=0 id=") == 1, "house: a heretic came in outside the room")
	var shut: int = _first_line(lines, "host mark shut")
	var hurt_after: int = 0
	for i: int in range(maxi(shut, 0), lines.size()):
		if lines[i].contains("host hurt slot="):
			hurt_after += 1
	check(shut >= 0 and hurt_after == 0, "house: nobody in the closed room was hurt after it shut (%d hurts)" % hurt_after)
	for inst: Instance in [host, c1, c2]:
		var mr: Dictionary = _map_of(inst.result, "0")
		var b: Dictionary = mr.get("builds", {})
		check(roundi(_num(b, "walls")) == HOUSE_WALLS and roundi(_num(b, "doors")) == 1 and roundi(_num(b, "open_doors")) == 0,
			"house/%s: %d walls and the closed door (%s)" % [inst.name, HOUSE_WALLS, b])
		var bv: Dictionary = mr.get("builds_view", {})
		check_eq(_num(bv, "mismatches", -1.0), 0.0, "house/%s: the walls drawn = data" % inst.name)
	var welcome: String = _line_with(_log_lines(c2), " welcome slot=")
	check(welcome.contains(" walls=%d doors=1 open_doors=0 " % HOUSE_WALLS), "house/c2 (late): its snapshot had the room and its closed door (%s)" % welcome)
	var p1: Dictionary = c1.result.get("prediction", {})
	check(_num(p1, "corrections", 99.0) == 0.0, "house/c1: never pulled back (walked through, into the closed door; %s)" % p1)
	# M7-fix: as shown (Prediction.replay_jumps: a pull-back caused by an edit does not show as a correction).
	check(_num(p1, "replay_jumps", 99.0) == 0.0, "house/c1: its shown position never jumped on a replay (%s)" % p1)
	_fight_traffic_notes("house", host, c1)
	for key: String in host.result.get("stats", {}):
		if key.begins_with("req") or key.begins_with("1/") or key.begins_with("2/"):
			var b2: Dictionary = host.result["stats"][key]
			note("house host %s: sends %s B/s in %s pkt/s over %s s" % [key, b2.get("sent_bps"), b2.get("packets_ps"), b2.get("sec")])
