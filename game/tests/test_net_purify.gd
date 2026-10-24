extends "res://tests/test_net_session.gd"
## M5c: purification and moving the altar in real sessions (separate processes over localhost ENet, like
## tests/test_net_session.gd, whose helpers and checks this file uses):
##   purify  host (cleric) + c1 (paladin), seed 1, spawns off. c1 walks to the north zone's eastern edge and presses F
##           with nothing to pick up: its channel (a CHANNEL request) runs 3 s on the host, which purifies its disc and
##           works out the heretics' spawn ring again (the host's log: fewer spawn tiles); c1 then walks into the purified
##           disc and pours holy water on the ash beyond it. Every purified tile reaches c1 as edits and flashes there.
##   altar   host (herbalist, test fields on the M1 soil west and south of the altar) + c1 (archer, 12 HP: one cut downs
##           it) standing in the altar light 4 tiles south of it, a heretic placed outside the light 6 tiles south of c1 + a late c2
##           (cleric). The host holds F on the altar 2 s (ALTAR_LIFT), carries it 13 tiles west and puts it down
##           (ALTAR_PLACE). The heretic never cuts c1 while the light covers it; without it, it comes for c1, which goes
##           down, gives up and respawns at its slot around the moved altar (waiting while the altar is carried). The old
##           fields wither (edits); c2 joins after the move and gets the withered fields and the moved altar.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=purify or altar).

const PURIFY_HOST: String = "walkto:62,30;wait:900"
const PURIFY_C1_GIVE: String = "--give=holy_water:2"
const PURIFY_C1: String = ("walkto:66,16;walkto:60,15;aimat:59,15;pick;wait:200;mark:purified;walkto:57,15;select:1;" +
	"aimat:56,15;use:1;wait:40;mark:poured;wait:30")
const ALTAR_FIELDS: String = "--test-field=57,45:healing:3:wet/58,45:buff:4/59,46:poison:4:fast:wet/58,49:healing:2:wet"
## Six tiles south of c1: within its sight (Config.HERETIC_SIGHT_PX), outside the light.
const ALTAR_HERETIC: String = "--test-heretic=63,58"
const ALTAR_HOST: String = ("wait:120;walkto:63,49;aimat:63,48;hold:125;walkto:50,48;aimat:50,47;wait:6;use:1;wait:20;" +
	"mark:moved;wait:900")
const ALTAR_C1: String = "walkto:63,52;waitlife:down,1500;hold:70;waitlife:alive,1500;mark:respawned;wait:60"
const ALTAR_C2: String = "wait:30;mark:seen;wait:30"
## Where the host puts the altar (README "M5c"): footprint at (49, 45), its centre (808, 744) px.
const ALTAR_NEW: Vector2i = Vector2i(49, 45)


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("purify_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("purify"):
		await _session_purify()
	if only.is_empty() or only.has("altar"):
		await _session_altar()
	_check_logs()
	note("purify / altar sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_purify() -> void:
	var dir: String = _session_dir("purify")
	var port: int = _port()
	if not check(port > 0, "purify: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=1", "--class=cleric",
		"--test-allow-give", "--bot=" + PURIFY_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "purify: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=paladin", PURIFY_C1_GIVE, "--bot=" + PURIFY_C1],
		100)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json")], 90.0), "purify: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1]):
		return
	_expect_codes("purify", {host: 0, c1: 0})
	_check_agreement("purify", host, [c1], 2)
	var s1: int = roundi(_num(c1.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check_eq(_count_lines(lines, "host channel slot=%d map=0 start at=60,15" % s1), 1, "purify: the host started c1's channel at 60,15")
	var ch: String = _line_with(lines, "host purify slot=%d map=0 what=channel at=60,15" % s1)
	var ring: int = _int_after(ch, "spawn_tiles=")
	var tiles: int = _int_after(ch, "tiles=")
	check(tiles >= 5 and ring >= 0 and ring < 678, "purify: the channel purified %d tiles; the host's spawn ring shrank 678 -> %d (%s)" % [
		tiles, ring, ch])
	var hw: String = _line_with(lines, "host purify slot=%d map=0 what=holy_water at=56,15" % s1)
	var poured: int = _int_after(hw, "tiles=")
	check(poured >= 1 and _int_after(hw, "spawn_tiles=") <= ring, "purify: the holy water purified %d tiles (%s)" % [poured, hw])
	check_eq(_num(c1.result, "purify_flashes"), float(tiles + poured), "purify/c1: every purified tile flashed there (edits)")
	check(_count_lines(_log_lines(c1), "edit corruption ") == tiles + poured, "purify/c1: one corruption edit per tile")
	var ops: Dictionary = host.result.get("ops", {})
	var c1_ops: Dictionary = ops.get(str(s1), {})
	var refused: Dictionary = c1_ops.get("refused", {})
	check_eq(refused, {}, "purify: nothing of c1 refused")
	check_eq(_map_of(c1.result, "0").get("corrupted", -1), _map_of(host.result, "0").get("corrupted", -2),
		"purify/c1: the same corruption left as the host")
	_fight_traffic_notes("purify", host, c1)


func _session_altar() -> void:
	var dir: String = _session_dir("altar")
	var port: int = _port()
	if not check(port > 0, "altar: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=herbalist",
		ALTAR_FIELDS, ALTAR_HERETIC, "--test-start-hp=archer:12", "--bot=" + ALTAR_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "altar: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + ALTAR_C1], 100)
	if not check(await _wait_files([dir.path_join("host.moved.marker")], 60.0), "altar: the host moved the altar"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + ALTAR_C2], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 80.0),
		"altar: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("altar", {host: 0, c1: 0, c2: 0})
	_check_agreement("altar", host, [c1, c2], 3)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	var lifted: int = _first_line(lines, "host altar slot=%d map=0 picked_up from=62,46" % hs)
	var placed: int = _first_line(lines, "host altar slot=%d map=0 placed at=%d,%d" % [hs, ALTAR_NEW.x, ALTAR_NEW.y])
	check(lifted >= 0 and placed > lifted, "altar: the host picked it up at 62,46 and put it down at %d,%d" % [ALTAR_NEW.x, ALTAR_NEW.y])
	var first_hurt: int = _first_line(lines, "host hurt slot=%d " % s1)
	check(first_hurt > lifted and lifted >= 0, "altar: the heretic cut c1 only after the light left it (hurt line %d, lifted %d)" % [
		first_hurt, lifted])
	var centre: Vector2 = AltarMove.centre_px(Rect2i(ALTAR_NEW, Config.ALTAR_FOOTPRINT))
	var slot_feet: Vector2 = centre + Vector2(Config.SPAWN_SLOTS[s1])
	check_eq(_count_lines(lines, "host respawn slot=%d feet=%d,%d" % [s1, roundi(slot_feet.x), roundi(slot_feet.y)]), 1,
		"altar: c1 respawned at its slot around the moved altar (%s)" % _line_with(lines, "host respawn slot=%d" % s1))
	if _count_lines(lines, "host respawn_waits slot=%d" % s1) > 0:
		note("altar: c1 died while the altar was carried and waited for it (respawn_waits)")
	var welcome: String = _line_with(_log_lines(c2), " welcome slot=")
	check(welcome.contains(" altar=%d,%d " % [ALTAR_NEW.x, ALTAR_NEW.y]) and welcome.contains(" crops=4 ") and welcome.contains(" withered=4 "),
		"altar/c2 (late): its snapshot had the moved altar and the four withered crops (%s)" % welcome)
	for inst: Instance in [host, c1, c2]:
		var mr: Dictionary = _map_of(inst.result, "0")
		check_eq(mr.get("altar", ""), "%d,%d" % [ALTAR_NEW.x, ALTAR_NEW.y], "altar/%s: the altar where the host put it" % inst.name)
		check_eq(mr.get("fields", {}), _map_of(host.result, "0").get("fields", {}), "altar/%s: the same (withered) fields" % inst.name)
	var c1_lines: PackedStringArray = _log_lines(c1)
	check(_count_lines(c1_lines, "edit placeable 62,46=0 ") == 1 and _count_lines(c1_lines, "edit placeable %d,%d=%d " % [ALTAR_NEW.x,
		ALTAR_NEW.y, WorldData.PLACEABLE_ALTAR]) == 1, "altar/c1: saw it lifted and put down (edits)")
	_fight_traffic_notes("altar", host, c1)
