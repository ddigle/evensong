extends "res://tests/test_net_session.gd"
## M10b: the group prayer in a real session (separate processes over localhost ENet, like tests/test_net_session.gd, whose helpers
## and checks this file uses; tests/test_net_prayer.gd runs the one-process checks, tests/test_net_litany.gd the mixed one). Seed 1,
## spawns off.
##   vigil   host (cleric, faith 60) + c1 (paladin) + c2 (archer) + c3 (miner) on their spawn slots round the altar: the host taps
##           (it starts: the clients are in the circle), each client taps in the gather (it joins), every turn answered right by its
##           machine (bot answer:auto: 30 ticks into the window its machine shows). c4 (herbalist) joins during the turns: its
##           first prayer message (the snapshot) has the prayer under way (turns, four in it, the lamps so far = the host's). After
##           it: every machine has the host's lamps (nine lit), result (zeal 29 %, faith 30) and every player's zeal (the % and the
##           host tick it runs out); then two heretics south of the light: the paladin's sword hits with the zeal (14 -> 18) and c4's
##           sickle (no zeal) for its plain damage.
##   silent  host (cleric) + three clients join and nobody answers: nine lamps out, zeal 11 % (the floor of the formula is not
##           reached: 15 - 10 + 6) on every machine; no answer taken.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=vigil,silent).

const VIGIL_HERETICS_AT: String = "heretic:61,59;heretic:65,59"
const VIGIL_HOST: String = ("wait:20;pray;waitprayer:turns,600;mark:turns;answer:auto;waitprayer:idle,2400;mark:prayed;wait:60;" +
	VIGIL_HERETICS_AT + ";wait:900;waitfoe:0,1500;wait:120")
## A client: joins in the gather, answers every turn of its own right, then (the paladin) fights.
const VIGIL_JOIN: String = "waitprayer:gather,900;wait:10;pray;waitprayer:turns,600;answer:auto;waitprayer:idle,2400;"
const VIGIL_C1: String = VIGIL_JOIN + "select:8;wait:90;aimfoe;fight:1200,0,18;waitfoe:0,1500;aim:off;walkto:63,53;wait:120"
const VIGIL_C2: String = VIGIL_JOIN + "wait:60;move:1,0,20;move:-1,0,20;waitfoe:0,2400;wait:120"
const VIGIL_C3: String = VIGIL_JOIN + "wait:60;move:-1,0,20;move:1,0,20;waitfoe:0,2400;wait:120"
const VIGIL_C4: String = "mark:seen;select:8;wait:200;aimfoe;fight:1200,0,18;waitfoe:0,1500;aim:off;wait:120"
const SILENT_HOST: String = "wait:20;pray;waitprayer:turns,600;waitprayer:idle,2400;mark:prayed;wait:200"
const SILENT_JOIN: String = "waitprayer:gather,900;wait:10;pray;waitprayer:turns,600;waitprayer:idle,2400;move:1,0,25;move:-1,0,25;wait:60"


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("vigil_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("vigil"):
		await _session_vigil()
	_check_logs()
	note("vigil sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## The integer after ` key=` in `line` (-1 when it has none).
static func _field(line: String, key: String) -> int:
	var at: int = line.find(" " + key + "=")
	if at < 0:
		return -1
	return line.substr(at + key.length() + 2).get_slice(" ", 0).get_slice(",", 0).to_int()


## The word after ` key=` in `line` ("" when none).
static func _word(line: String, key: String) -> String:
	var at: int = line.find(" " + key + "=")
	if at < 0:
		return ""
	return line.substr(at + key.length() + 2).get_slice(" ", 0)


## The host's and every client's prayer results agree: the last result (lamps, lit, zeal, faith, stopped) and every zeal (% and the
## host tick it runs out) in `slots`.
func _check_prayer_agree(label: String, host: Instance, clients: Array[Instance], slots: Array[int]) -> void:
	var hp: Dictionary = host.result.get("prayer", {})
	var hl: Dictionary = hp.get("last", {})
	var hz: Dictionary = hp.get("zeal", {})
	for c: Instance in clients:
		var cp: Dictionary = c.result.get("prayer", {})
		var cl: Dictionary = cp.get("last", {})
		check(str(cl.get("lamps", "?")) == str(hl.get("lamps", "!")) and _num(cl, "lit") == _num(hl, "lit")
			and _num(cl, "zeal") == _num(hl, "zeal") and _num(cl, "faith") == _num(hl, "faith") and str(cl.get("stopped")) == str(hl.get("stopped")),
			"%s/%s: the prayer's result = the host's (%s / %s)" % [label, c.name, cl, hl])
		check_eq(_num(cp, "bad"), 0.0, "%s/%s: no malformed prayer message" % [label, c.name])
		var cz: Dictionary = cp.get("zeal", {})
		for slot: int in slots:
			var hv: Array = hz.get(str(slot), [])
			var cv: Array = cz.get(str(slot), [])
			check(hv.size() == 2 and cv.size() == 2 and str(hv) == str(cv),
				"%s/%s: player %d's zeal (%%, runs out at) = the host's (%s / %s)" % [
				label, c.name, slot, cv, hv])


func _session_vigil() -> void:
	var dir: String = _session_dir("vigil")
	var port: int = _port()
	if not check(port > 0, "vigil: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=4", "--class=cleric",
		"--test-start-resource=cleric:60", "--bot=" + VIGIL_HOST], 110)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "vigil: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = []
	for row: Array in [["c1", "paladin", VIGIL_C1], ["c2", "archer", VIGIL_C2], ["c3", "miner", VIGIL_C3]]:
		var name: String = row[0]
		cs.append(_launch(dir, name, ["--join=127.0.0.1:%d" % port, "--class=" + str(row[1]), "--bot=" + str(row[2])], 110))
		check(await _wait_files([dir.path_join(name + ".welcome.marker")], READY_WAIT_SEC), "vigil: %s joined" % name)
	if not check(await _wait_files([dir.path_join("host.turns.marker")], 40.0), "vigil: the turns began"):
		await _reap()
		return
	var c4: Instance = _launch(dir, "c4", ["--join=127.0.0.1:%d" % port, "--class=herbalist", "--bot=" + VIGIL_C4], 100)
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	everyone.append(c4)
	var files: Array[String] = []
	for inst: Instance in everyone:
		files.append(dir.path_join(inst.name + ".json"))
	check(await _wait_files(files, 100.0), "vigil: every instance wrote its result")
	await _reap()
	if not _load_results(dir, everyone):
		return
	_expect_codes("vigil", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0, c4: 0})
	var clients: Array[Instance] = []
	clients.append_array(cs)
	clients.append(c4)
	_check_agreement("vigil", host, clients, 5)
	var lines: PackedStringArray = _log_lines(host)
	var hp: Dictionary = host.result.get("prayer", {})
	var hl: Dictionary = hp.get("last", {})
	check(str(hl.get("lamps", "")) == "lllllllll" and _num(hl, "participants") == 4.0 and _num(hl, "zeal") == float(Prayer.zeal_pct(9, 4))
		and _num(hl, "faith") == float(Config.PRAYER_FAITH_COST), "vigil: nine lit, four, zeal %d%%, faith %d (%s)" % [
		Prayer.zeal_pct(9, 4), Config.PRAYER_FAITH_COST, hl])
	var answers: Array = hp.get("answers", [])
	check_eq(answers.size(), 9, "vigil: nine answers taken (%s, window ticks)" % [answers])
	check_eq(_count_lines(lines, " pray map=") + _count_lines(lines, " answer map="), 0,
		"vigil: no tap or answer refused")
	_check_prayer_agree("vigil", host, cs, [0, 1, 2, 3])
	# c4 joined during the turns: its first prayer message had the prayer under way.
	var c4_lines: PackedStringArray = _log_lines(c4)
	var first: String = _line_with(c4_lines, "c4 prayer events=")
	var final: String = str(hl.get("lamps", ""))
	var so_far: String = _word(first, "lamps")
	var prefix_ok: bool = so_far.length() == Config.PRAYER_TURNS
	var decided: int = 0
	for i: int in so_far.length():
		if so_far[i] != "u":
			decided += 1
			prefix_ok = prefix_ok and i < final.length() and so_far[i] == final[i]
	check(first.contains(" phase=turns ") and _field(first, "members") == 4 and first.contains("start") and prefix_ok and decided >= 1,
		"vigil/c4 (late): its snapshot had the turns, four in it, %d lamps decided as the host's (%s)" % [decided, first])
	var c4p: Dictionary = c4.result.get("prayer", {})
	var c4l: Dictionary = c4p.get("last", {})
	check_eq(str(c4l.get("lamps", "")), final, "vigil/c4: then the end's lamps")
	# The zeal in the fight: the paladin's sword with the zeal, c4's sickle without.
	var s1: int = roundi(_num(cs[0].result, "slot"))
	var s4: int = roundi(_num(c4.result, "slot"))
	var pct: int = roundi(_num(hl, "zeal"))
	var sword: int = Prayer.zeal_hit(Combat.attack_for(&"sword").damage, pct)
	var sickle: int = Combat.attack_for(&"sickle").damage
	var p_hits: PackedInt32Array = []
	var h_hits: PackedInt32Array = []
	for line: String in lines:
		if line.contains(" hit slot=%d map=0 " % s1):
			p_hits.append(_field(line, "amount"))
		elif line.contains(" hit slot=%d map=0 " % s4):
			h_hits.append(_field(line, "amount"))
	var p_ok: bool = not p_hits.is_empty()
	for a: int in p_hits:
		p_ok = p_ok and a == sword
	var h_ok: bool = true
	for a2: int in h_hits:
		h_ok = h_ok and a2 == sickle
	check(p_ok and h_ok, "vigil: the paladin's sword hits with %d%% zeal for %d %s, the late herbalist's sickle for %d %s" % [pct,
		sword, p_hits, sickle, h_hits])
	check(_killed_by_any(lines, 1) and _killed_by_any(lines, 2), "vigil: both heretics died")
	note("vigil: prayer messages %s (%s B) from the host; answers at window ticks %s; c4's snapshot line: %s" % [hp.get("msgs"),
		hp.get("bytes"), answers, first])


func _session_silent() -> void:
	var dir: String = _session_dir("silent")
	var port: int = _port()
	if not check(port > 0, "silent: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=3", "--class=cleric",
		"--test-start-resource=cleric:60", "--bot=" + SILENT_HOST], 90)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "silent: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = []
	for row: Array in [["c1", "paladin"], ["c2", "archer"], ["c3", "miner"]]:
		var name: String = row[0]
		cs.append(_launch(dir, name, ["--join=127.0.0.1:%d" % port, "--class=" + str(row[1]), "--bot=" + SILENT_JOIN], 90))
		check(await _wait_files([dir.path_join(name + ".welcome.marker")], READY_WAIT_SEC), "silent: %s joined" % name)
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	var files: Array[String] = []
	for inst: Instance in everyone:
		files.append(dir.path_join(inst.name + ".json"))
	check(await _wait_files(files, 85.0), "silent: every instance wrote its result")
	await _reap()
	if not _load_results(dir, everyone):
		return
	_expect_codes("silent", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0})
	_check_agreement("silent", host, cs, 4)
	var hp: Dictionary = host.result.get("prayer", {})
	var hl: Dictionary = hp.get("last", {})
	check(str(hl.get("lamps", "")) == "ooooooooo" and _num(hl, "zeal") == float(Prayer.zeal_pct(0, 4)) and _num(hl, "participants") == 4.0
		and str(hp.get("answers", [0])) == "[]", "silent: nobody answers: nine out, zeal %d%%, no answer taken (%s)" % [
		Prayer.zeal_pct(0, 4), hl])
	_check_prayer_agree("silent", host, cs, [0, 1, 2, 3])
	note("silent: prayer messages %s (%s B)" % [hp.get("msgs"), hp.get("bytes")])
