extends "res://tests/test_net_vigil.gd"
## M10b: the group prayer in a real session with a bad link, mixed answers, a hit and a quit (separate processes over localhost
## ENet; tests/test_net_vigil.gd's helpers, tests/test_net_session.gd's checks). Seed 1, spawns off.
##   litany  host (cleric, faith 60) + c1 (paladin, --net-lag=120 --net-loss=5) + c2 (archer) + c3 (miner) round the altar.
##           First prayer: everyone joins, the host (the cleric) taps again during turn 1: it stops on every machine, nobody gets
##           zeal, no faith is spent. Second prayer: the host never answers (late), c1 answers 85 ticks into the window its
##           machine shows (from its turn's event's arrival: on the host past its own 90, inside the lag allowance: taken), c2
##           answers every turn with the opposite key (wrong), c3 answers its turn right and is then hit on the host (bot "hurt"):
##           it leaves alone, its later turn goes to the others. The lamps o l o l o l o o l, three participants, zeal 17 %, faith
##           30 spent, on every machine the same; c3 has none.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=litany).

const LITANY_HOST: String = ("wait:20;pray;waitprayer:turns,600;mark:first;wait:200;pray;waitprayer:idle,600;mark:stopped;wait:150;" +
	"pray;waitprayer:turns,600;mark:second;wait:580;hurt:3,1;waitprayer:idle,2400;mark:prayed;wait:200")
## A client: joins both prayers in their gathers, answers its turns `mode` (answer:auto,85 / answer:wrong / answer:auto).
static func litany_client(mode: String) -> String:
	var join: String = "waitprayer:gather,900;wait:10;pray;waitprayer:turns,600;%s;" % mode
	return join + join + "waitprayer:idle,2400;move:1,0,25;move:-1,0,25;wait:60"


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("litany_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("litany"):
		await _session_litany()
	if only.is_empty() or only.has("silent"):
		await _session_silent()  # tests/test_net_vigil.gd's (here: its file stays well under the runner's 120 s)
	_check_logs()
	note("litany sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_litany() -> void:
	var dir: String = _session_dir("litany")
	var port: int = _port()
	if not check(port > 0, "litany: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=3", "--class=cleric",
		"--test-start-resource=cleric:60", "--bot=" + LITANY_HOST], 110)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "litany: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = []
	for row: Array in [["c1", "paladin", "answer:auto,85", ["--net-lag=120", "--net-loss=5"]], ["c2", "archer", "answer:wrong", []],
			["c3", "miner", "answer:auto", []]]:
		var name: String = row[0]
		var flags: Array = ["--join=127.0.0.1:%d" % port, "--class=" + str(row[1]), "--bot=" + litany_client(str(row[2]))]
		var extra: Array = row[3]
		flags.append_array(extra)
		cs.append(_launch(dir, name, flags, 110))
		check(await _wait_files([dir.path_join(name + ".welcome.marker")], READY_WAIT_SEC), "litany: %s joined" % name)
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	var files: Array[String] = []
	for inst: Instance in everyone:
		files.append(dir.path_join(inst.name + ".json"))
	check(await _wait_files(files, 105.0), "litany: every instance wrote its result")
	await _reap()
	if not _load_results(dir, everyone):
		return
	_expect_codes("litany", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0})
	_check_agreement("litany", host, cs, 4)
	var lines: PackedStringArray = _log_lines(host)
	var s1: int = roundi(_num(cs[0].result, "slot"))
	var s3: int = roundi(_num(cs[2].result, "slot"))
	# The first prayer: the cleric's second tap stopped it; nothing given.
	var stop: String = _line_with(lines, " prayer stop ")
	var stop_at: int = _first_line(lines, " prayer stop ")
	var zeal_before: int = 0
	for i: int in range(0, maxi(stop_at, 0)):
		if lines[i].contains(" prayer zeal "):
			zeal_before += 1
	check(not stop.is_empty() and _field(stop, "why") == Prayer.STOP_WHYS.find("the cleric: quit") and zeal_before == 0
		and _line_with(lines, "host pray slot=0 stop").length() > 0, "litany: the cleric's second tap stopped the first prayer, no zeal (%s)" %
		stop)
	for c: Instance in cs:
		check(_log_has(c, "%s prayer events=stop phase=idle" % c.name), "litany/%s: heard the stop" % c.name)
	# The second prayer. Its turn order is the order the joins reached the host (c1's goes through the lag): read from the log, the
	# lamps follow from each owner's mode (the host late, c1 right, c2 wrong, c3 right while it is in).
	var s2: int = roundi(_num(cs[1].result, "slot"))
	var owners: PackedInt32Array = []
	var results_by: Dictionary = {}  # slot -> [ok, wrong, late, left] counts over both prayers
	var last_owner: int = -1
	for line: String in lines:
		if line.contains(" prayer turn tick="):
			last_owner = _field(line, "slot")
			owners.append(last_owner)
		elif line.contains(" prayer result tick="):
			var counts: Array = results_by.get(last_owner, [0, 0, 0, 0])
			var how: int = _field(line, "why")
			var cur: int = counts[how]
			counts[how] = cur + 1
			results_by[last_owner] = counts
	var second: PackedInt32Array = owners.slice(owners.size() - Config.PRAYER_TURNS) if owners.size() >= Config.PRAYER_TURNS else owners
	var want_lamps: String = ""
	for o: int in second:
		want_lamps += "l" if o == s1 or o == s3 else "o"
	var lit: int = want_lamps.count("l")
	var want_zeal: int = Prayer.zeal_pct(lit, 3)
	var hp: Dictionary = host.result.get("prayer", {})
	var hl: Dictionary = hp.get("last", {})
	check(second.size() == Config.PRAYER_TURNS and str(hl.get("lamps", "")) == want_lamps and _num(hl, "participants") == 3.0
		and _num(hl, "zeal") == float(want_zeal) and _num(hl, "faith") == float(Config.PRAYER_FAITH_COST) and str(hl.get("stopped")) == "false",
		"litany: turns %s -> lamps %s (the host late, c1 right through the lag, c2 wrong, c3 right then gone), three, zeal %d%% (%s)" % [
		second, want_lamps, want_zeal, hl])
	var hk: Dictionary = host.result.get("skills", {})
	var members: Dictionary = hk.get("members", {})
	var cleric: Dictionary = members.get("0", {})
	check_eq(_num(cleric, "meter"), float(60 - Config.PRAYER_FAITH_COST), "litany: the cleric spent its faith once (the stopped one spent none)")
	# c3 was hit after its turn: it left alone, owns no turn after that, the order goes on without it.
	var left: String = _line_with(lines, " prayer leave ")
	var left_at: int = _first_line(lines, " prayer leave ")
	var after: int = 0
	var before: int = 0
	var second_start: int = _first_line(lines, " pray slot=0 start")
	for i2: int in lines.size():
		if lines[i2].contains(" prayer turn tick=") and _field(lines[i2], "slot") == s3 and i2 > second_start:
			if i2 > left_at:
				after += 1
			else:
				before += 1
	check(_field(left, "slot") == s3 and _field(left, "why") == Prayer.LEAVE_WHYS.find("hit") and before >= 1 and after == 0,
		"litany: c3 had %d turn(s), was hit, left alone and owned none after (%s; turns %s)" % [before, left, second])
	# c1's answers through the lag: pressed 85 ticks into its own window, taken on the host past its own window.
	var c1_at: PackedInt32Array = []
	for line2: String in lines:
		if line2.contains(" answer slot=%d " % s1):
			c1_at.append(_field(line2, "at"))
	var past: int = 0
	for a: int in c1_at:
		if a > Config.PRAYER_ANSWER_WINDOW_TICKS:
			past += 1
	var c1_turns: int = second.count(s1)
	var c1p: Dictionary = cs[0].result.get("prayer", {})
	var c1r: Dictionary = c1p.get("my_results", {})
	check(c1_turns >= 1 and c1_at.size() == c1_turns and past >= 1 and _num(c1r, "ok") == float(c1_turns) and _num(c1r, "late", 0.0) == 0.0,
		"litany/c1 (120 ms, 5 %%): its %d answers at tick 85 of its window were taken at host window ticks %s (%d past the host's %d)" % [
		c1_turns, c1_at, past, Config.PRAYER_ANSWER_WINDOW_TICKS])
	var c2p: Dictionary = cs[1].result.get("prayer", {})
	var c2r: Dictionary = c2p.get("my_results", {})
	var c2_counts: Array = results_by.get(s2, [0, 0, 0, 0])
	var c2_wrong: int = c2_counts[1]
	check(_num(c2r, "wrong") == float(c2_wrong) and c2_wrong >= 2 and _num(c2r, "ok", 0.0) == 0.0,
		"litany/c2: every answer of its was wrong (the opposite key): %s here, %s on the host" % [c2r, c2_counts])
	_check_prayer_agree("litany", host, cs, [0, 1, 2])
	for c2: Instance in cs:
		var c2pr: Dictionary = c2.result.get("prayer", {})
		var cz: Dictionary = c2pr.get("zeal", {})
		check(not cz.has(str(s3)), "litany/%s: c3 has no zeal" % c2.name)
	note("litany: c1's answers at host window ticks %s; prayer messages %s (%s B)" % [c1_at, hp.get("msgs"), hp.get("bytes")])
