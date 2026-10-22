extends "res://tests/test_net_session.gd"
## M6b: potions and crafting in real sessions (separate processes over localhost ENet, like
## tests/test_net_session.gd, whose helpers and checks this file uses):
##   brew   host (herbalist, starts hurt like c1: --test-start-hp=herbalist:40) + c1 (herbalist) + a late c2
##          (cleric), seed 1, one heretic placed south of the light, spawns off. The host clicks the alchemy table
##          down east of the altar (a host-checked edit); c1 walks up, opens the panel (Tab) and brews two FINE
##          poison potions from its FINE herbs (CRAFT requests: the host checks the station, the recipe, the class,
##          the inputs, the room); c1 stands at the light's edge, the host throws a FINE healing potion at it (40 ->
##          90 HP) and then the buff; c1 throws its poison at the heretic outside the light (the bottle flies on
##          every machine; the heretic is poisoned); c2 joins while the heretic is poisoned and c1 buffed; c1's
##          second poison kills the heretic: a poison kill the host counts for c1, seen by everyone.
##   brew4  host (herbalist) + c1 (herbalist) + c2 (archer) + c3 (paladin) against two heretics: the herbalists throw
##          poison from the light's edge while the others fight; everyone agrees.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=brew or brew4).

## brew (seed 1): the table's footprint is (64..66, 50) (the host clicks the tile south of (65, 49)); c1 brews
## at (67, 49), throws from (63, 53) (inside the light, 5 tiles north of the heretic); the host throws from
## (61, 52), in the light, 36 px from c1 (outside the splash's reach).
const BREW_HERETIC: String = "--test-heretic=63,58"
const BREW_HOST_GIVE: String = "--give=alchemy_table,potion_healing:2:fine,potion_buff:2:fine"
const BREW_HOST: String = ("select:1;walkto:65,49;aim:0,16;use:1;wait:10;aim:off;mark:table;select:2;walkto:62,49;" +
	"walkto:61,52;wait:180;aimat:63,53;wait:4;throw;wait:60;select:3;wait:4;throw;wait:60;aim:off;mark:healed;wait:1000")
const BREW_C1_GIVE: String = "--give=wild_poison:4:fine"
const BREW_C1: String = ("wait:120;walkto:67,49;tab;wait:10;craft:2;wait:10;craft:2;wait:10;tab;select:2;walkto:67,52;" +
	"walkto:63,53;mark:edge;wait:240;aimfoe;wait:4;throw;wait:60;mark:poisoned;wait:330;aimfoe;wait:4;throw;" +
	"waitfoe:0,900;wait:60")
const BREW_C2: String = "wait:60;mark:seen;wait:60"
## brew4: two heretics south of the light (fight4's), the herbalists at its edge.
const BREW4_HERETICS: String = "--test-heretic=60,57/66,57"
const BREW4_HERB_GIVE: String = "--give=potion_poison:4:fine"
const BREW4_HOST: String = ("select:1;walkto:61,53;wait:40;aimfoe;wait:4;throw;wait:70;throw;wait:70;throw;wait:70;throw;" +
	"waitfoe:0,1500;wait:240")
const BREW4_C1: String = ("select:1;walkto:65,53;wait:80;aimfoe;wait:4;throw;wait:70;throw;wait:70;throw;wait:70;throw;" +
	"waitfoe:0,1500;wait:240")
const BREW4_C2: String = "select:8;walkto:63,52;wait:30;fight:1500,0;wait:240"
const BREW4_C3: String = "select:8;wait:60;fight:1500,0,18;wait:240"


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("brew_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("brew"):
		await _session_brew()
	if only.is_empty() or only.has("brew4"):
		await _session_brew4()
	_check_logs()
	note("brew sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_brew() -> void:
	var dir: String = _session_dir("brew")
	var port: int = _port()
	if not check(port > 0, "brew: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=herbalist",
		"--test-allow-give", BREW_HOST_GIVE, "--bot=" + BREW_HOST, BREW_HERETIC, "--test-start-hp=herbalist:40"], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "brew: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=herbalist", BREW_C1_GIVE, "--bot=" + BREW_C1],
		100)
	if not check(await _wait_files([dir.path_join("c1.poisoned.marker")], 60.0), "brew: c1 brewed, was healed and buffed, threw poison"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + BREW_C2], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 80.0),
		"brew: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("brew", {host: 0, c1: 0, c2: 0})
	_check_agreement("brew", host, [c1, c2], 3)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check_eq(_count_lines(lines, "host place slot=%d map=0 item=alchemy_table" % hs), 1, "brew: the host placed the table (host-checked edit)")
	check_eq(_count_lines(lines, "host craft slot=%d map=0 recipe=potion_poison_fine item=potion_poison count=1 grade=fine" % s1), 2,
		"brew: c1 brewed two FINE poison potions at the host's table (CRAFT requests)")
	check_eq(_count_lines(lines, "host request_refused slot=%d craft" % s1), 0, "brew: no craft of c1 refused")
	check(_count_lines(lines, "item=potion_healing at=") >= 1 and _line_with(lines, "item=potion_healing at=").contains("players=1"),
		"brew: the host's healing splash reached c1 (%s)" % _line_with(lines, "item=potion_healing at="))
	check(_line_with(lines, "item=potion_buff at=").contains("players=1"), "brew: the buff splash reached c1 (%s)" % _line_with(lines,
		"item=potion_buff at="))
	var p1: Dictionary = _player(host, s1)
	check_eq(_num(p1, "hp"), float(40 + Config.POTION_HEAL_HP[ItemDB.Grade.FINE]), "brew: c1 healed from 40 to 90 by the host's bottle")
	check_eq(_count_lines(lines, "host throw slot=%d map=0 item=potion_poison grade=fine" % s1), 2, "brew: c1 threw two poison potions")
	var hits: Dictionary = _hits_by_heretic(lines)
	check(_hit_slots(hits, 1) == [s1] and _killed(lines, 1, s1), "brew: the poison alone killed the heretic, a kill counted for c1 (%s)" % [
		hits.get(1, [])])
	check(_line_with(lines, "KILLED").contains("amount=%d" % Config.POISON_DAMAGE[ItemDB.Grade.FINE]), "brew: the last blow was a poison tick (%s)" % (
		_line_with(lines, "KILLED")))
	var h1_seq: Array = _hp_sequence(hits, 1)
	var host_combat: Dictionary = host.result.get("combat", {})
	var host_maps: Dictionary = host_combat.get("maps", {})
	var host_surface: Dictionary = host_maps.get("0", {})
	var host_stats: Dictionary = host_surface.get("stats", {})
	check(_num(host_stats, "poison_kills") == 1.0 and _num(host_stats, "splashes") >= 4.0, "brew: host arena: one poison kill, four splashes (%s)" % [
		host_stats])
	for c: Instance in [c1, c2]:
		var cc: Dictionary = c.result.get("combat", {})
		var seen_hp: Dictionary = cc.get("foe_hp", {})
		var saw: Array = seen_hp.get("1", [])
		check(_follows_seq(saw, h1_seq), "brew/%s: the heretic's HP as it saw it %s follows the host's %s down to 0" % [c.name, saw, h1_seq])
		var poisoned: Array = cc.get("poisoned_seen", [])
		check(poisoned.has(1.0) or poisoned.has(1), "brew/%s: it saw the heretic poisoned (%s)" % [c.name, poisoned])
		check_eq(str(cc.get("hash", "")), str(host_surface.get("hash", "?")), "brew/%s: its last enemy view = the host's" % c.name)
		var p: Dictionary = c.result.get("prediction", {})
		check_eq(_num(p, "vitals_corrections"), 0.0, "brew/%s: the prediction's own vitals and effects never off the host's" % c.name)
	var c1c: Dictionary = c1.result.get("combat", {})
	check(_num(c1c, "flask_events") >= 8.0, "brew/c1: the bottles' events reached it (%s: the host's two, its own two)" % c1c.get("flask_events"))
	var c1p: Dictionary = c1.result.get("prediction", {})
	check(_num(c1p, "event_corrections") >= 2.0, "brew/c1: the heal and the buff were the host's events (%s)" % c1p.get("event_corrections"))
	var welcome: Dictionary = c2.result.get("effects_on_welcome", {})
	var on_c1: String = welcome.get(str(s1), "")
	check(on_c1.contains("buff=%d/" % Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE]), "brew/c2 (late): its welcome had c1 buffed (%s)" % [welcome])
	var c2c: Dictionary = c2.result.get("combat", {})
	var c2_hp: Dictionary = c2c.get("foe_hp", {})
	var c2_saw: Array = c2_hp.get("1", [])
	var c2_first: int = c2_saw[0] if not c2_saw.is_empty() else -1
	check(c2_first > 0 and c2_first <= Config.HERETIC_HP, "brew/c2: joined while the heretic was alive and poisoned (first HP %d)" % c2_first)
	check(_log_has(c2, "c2 welcome slot=%d" % s2), "brew/c2: joined late")
	_fight_traffic_notes("brew", host, c1)


func _session_brew4() -> void:
	var dir: String = _session_dir("brew4")
	var port: int = _port()
	if not check(port > 0, "brew4: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=3", "--class=herbalist",
		"--test-allow-give", BREW4_HERB_GIVE, "--bot=" + BREW4_HOST, BREW4_HERETICS])
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "brew4: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = [_launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=herbalist", BREW4_HERB_GIVE,
		"--bot=" + BREW4_C1]),
		_launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + BREW4_C2]),
		_launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=paladin", "--bot=" + BREW4_C3])]
	var files: Array[String] = [dir.path_join("host.json")]
	for c: Instance in cs:
		files.append(dir.path_join(c.name + ".json"))
	check(await _wait_files(files, 80.0), "brew4: every instance wrote its result")
	await _reap()
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	if not _load_results(dir, everyone):
		return
	_expect_codes("brew4", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0})
	_check_agreement("brew4", host, cs, 4)
	var lines: PackedStringArray = _log_lines(host)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(cs[0].result, "slot"))
	check(_killed_by_any(lines, 1) and _killed_by_any(lines, 2), "brew4: both heretics died")
	var host_throws: int = _count_lines(lines, "host throw slot=%d map=0 item=potion_poison" % hs)
	var c1_throws: int = _count_lines(lines, "host throw slot=%d map=0 item=potion_poison" % s1)
	check(host_throws >= 2 and c1_throws >= 2, "brew4: both herbalists threw (host %d, c1 %d)" % [host_throws, c1_throws])
	var poison_hits: int = _count_lines(lines, "amount=%d hp=" % Config.POISON_DAMAGE[ItemDB.Grade.FINE])
	check(poison_hits >= 3, "brew4: poison ticks hit the heretics (%d)" % poison_hits)
	var hits: Dictionary = _hits_by_heretic(lines)
	var host_combat: Dictionary = host.result.get("combat", {})
	var host_maps: Dictionary = host_combat.get("maps", {})
	var host_surface: Dictionary = host_maps.get("0", {})
	for c: Instance in cs:
		var cc: Dictionary = c.result.get("combat", {})
		var seen: Dictionary = cc.get("foe_hp", {})
		for id: int in [1, 2]:
			var saw: Array = seen.get(str(id), [])
			check(_follows_seq(saw, _hp_sequence(hits, id)), "brew4/%s: heretic %d's HP %s follows the host's %s" % [c.name, id,
				saw, _hp_sequence(hits, id)])
		check_eq(str(cc.get("hash", "")), str(host_surface.get("hash", "?")), "brew4/%s: its last enemy view = the host's" % c.name)
		check(_num(cc, "flask_events") >= 4.0, "brew4/%s: the bottles' events reached it (%s)" % [c.name, cc.get("flask_events")])
		var p: Dictionary = c.result.get("prediction", {})
		check_eq(_num(p, "vitals_corrections"), 0.0, "brew4/%s: the prediction's own vitals never off the host's" % c.name)
	_fight_traffic_notes("brew4", host, cs[0])
