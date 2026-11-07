extends "res://tests/test_net_session.gd"
## M11c: the natural herd in real sessions (separate processes over localhost ENet, like tests/test_net_session.gd, whose helpers and checks
## this file uses; tests/test_net_hunt.gd runs the scripted ones). Seed 1, heretic spawns off.
##   wilds  host (cleric, at the altar) + c1 (archer, two snares) + c2 (paladin, a bow): natural creatures. Both walk to the rare zone,
##          which every machine has from the snapshot (114, 63). c2's arrows at the zone's rare creatures do nothing (the zone's rule: anyone
##          may walk in, only the archer hunts or captures there); c1 hurts one with its arrows and snares it (a second try: an arrow already
##          in the air can kill what is nearly caught, M11b's known issue, the more so on a client that sees the HP a moment late). The
##          collection is the same everywhere; the herd lives on the host alone.
##   herd   traffic: host (paladin) + c1 (archer) + c2 (cleric) among every creature of the caps (13, past their natural places: all near
##          the players), walking through them for 12 seconds, so they keep bolting and moving: the bytes against the README's numbers.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=wilds,herd).

const WILDS_C1_GIVE: String = "--give=snare:2"
const WILDS_C1: String = ("walkto:97,63,900;walkto:112,63,600;mark:there;select:8;huntrare:2400,130;select:1;snare:900;select:8;huntrare:900,130;select:1;" +
	"snare:300;aim:off;mark:caught;wait:120")
const WILDS_C2_GIVE: String = "--give=bow:1"
const WILDS_C2: String = "select:1;walkto:97,63,900;walkto:109,64,600;waitseen:1,300;huntrare:700,110;aim:off;wait:60"
const WILDS_HOST: String = "wait:60;mark:waited;wait:1800"
## Every creature of the caps around the host's player (a ring, as near as the light allows).
const HERD_CREATURES: String = "--test-creature=hare:6,deer:4,lamp_fox:1,silver_stag:1,ash_owl:1"
const HERD_HOST: String = ("walkto:60,56;walkto:68,56;walkto:68,62;walkto:60,62;walkto:60,56;walkto:68,56;walkto:68,62;walkto:60,62;mark:done;wait:30")
const HERD_C1: String = ("walkto:66,56;walkto:58,56;walkto:58,62;walkto:66,62;walkto:66,56;walkto:58,56;walkto:58,62;walkto:66,62;wait:30")
const HERD_C2: String = ("walkto:59,45;walkto:59,58;walkto:67,58;walkto:67,54;walkto:59,54;walkto:59,58;walkto:67,58;walkto:67,54;wait:30")
## IMPL (tests): the most creature bytes a second the host may send one client on the wire's own count (README "측정" M11c): 20 batches of
## 5 + 10 x 13 B, the keyframes on top.
const HERD_MAX_BPS: float = 2900.0


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("herd_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("wilds"):
		await _session_wilds()
	if only.is_empty() or only.has("herd"):
		await _session_herd()
	_check_logs()
	note("herd sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_wilds() -> void:
	var dir: String = _session_dir("wilds")
	var port: int = _port()
	if not check(port > 0, "wilds: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=2", "--net-expect=2", "--class=cleric", "--test-allow-give",
		"--bot=" + WILDS_HOST], 95, false, true)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "wilds: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", WILDS_C1_GIVE, "--bot=" + WILDS_C1], 95, false, true)
	check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "wilds: c1 joined")
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=paladin", WILDS_C2_GIVE, "--bot=" + WILDS_C2], 95, false, true)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 90.0),
		"wilds: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("wilds", {host: 0, c1: 0, c2: 0})
	_check_agreement("wilds", host, [c1, c2], 3)
	var lines: PackedStringArray = _log_lines(host)
	check(_line_with(lines, "host capture slot=1 caught kind=").length() > 0, "wilds: c1 caught a natural rare creature")
	var refused: int = _count_lines(lines, "host hunt refused slot=2 kind=")
	check(refused >= 1, "wilds: c2's arrows did nothing to the zone's creatures (%d refused)" % refused)
	var hurt: int = 0
	for line: String in lines:
		if line.contains("hunt hit slot=2 kind=lamp_fox") or line.contains("hunt hit slot=2 kind=silver_stag") or line.contains("hunt hit slot=2 kind=ash_owl"):
			hurt += 1
	check_eq(hurt, 0, "wilds: not one of them hurt")
	var hh: Dictionary = host.result.get("hunt", {})
	var caught: int = roundi(_num(hh, "captures"))
	check(caught >= 1, "wilds: a capture")
	check_eq(roundi(_num(hh, "alive")), 13 - caught - roundi(_num(hh, "kills")), "wilds: the herd stands at thirteen less those caught and killed")
	check_eq(hh.get("zone", ""), "114,63/%d" % Config.RARE_ZONE_RADIUS_TILES, "wilds: the zone of seed 1")
	check(_num(hh, "batches") > 10.0, "wilds: batches went out (%s, %s B)" % [hh.get("batches"), hh.get("bytes")])
	for inst: Instance in [c1, c2]:
		var seen: Dictionary = inst.result.get("combat", {})
		var kinds: Array = seen.get("creature_kinds", [])
		var rare: bool = kinds.has("lamp_fox") or kinds.has("silver_stag") or kinds.has("ash_owl")
		check(rare, "wilds/%s: drew the zone's creatures (%s)" % [inst.name, str(kinds)])
	var c1_combat: Dictionary = c1.result.get("combat", {})
	var marks: Dictionary = c1_combat.get("creature_marks", {})
	check(_num(marks, "refused") >= 1.0, "wilds: c1 saw the refused mark c2 caused (%s)" % marks)


func _session_herd() -> void:
	var dir: String = _session_dir("herd")
	var port: int = _port()
	if not check(port > 0, "herd: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=2", "--net-expect=2", "--class=paladin", HERD_CREATURES,
		"--bot=" + HERD_HOST], 70)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "herd: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + HERD_C1], 70)
	check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "herd: c1 joined")
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + HERD_C2], 70)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 65.0),
		"herd: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("herd", {host: 0, c1: 0, c2: 0})
	_check_agreement("herd", host, [c1, c2], 3)
	var hh: Dictionary = host.result.get("hunt", {})
	check_eq(_num(hh, "alive"), 13.0, "herd: all thirteen alive")
	var wall: float = _num(host.result, "wall_sec")
	var per_client: float = _num(hh, "bytes") / wall / 2.0
	check(per_client > 100.0 and per_client <= HERD_MAX_BPS, "herd: %.0f B/s of creature batches a client over %.1f s (at most %.0f, README)" % [per_client,
		wall, HERD_MAX_BPS])
	var c1_seen: Dictionary = c1.result.get("combat", {})
	note("herd: %s B over %.1f s, %s batches, %s keyframes; c1 took %s and %s; the moving bucket: %s" % [hh.get("bytes"), wall, hh.get("batches"),
		hh.get("keyframes"), c1_seen.get("creature_batches"), c1_seen.get("creature_keyframes"), JSON.stringify(host.result.get("stats", {}))])
