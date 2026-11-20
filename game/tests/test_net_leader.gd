extends "res://tests/test_net_session.gd"
## M12c: the boss, the cracked pillars, the relic and the altar's tier in real sessions (separate processes over localhost ENet, like
## tests/test_net_session.gd, whose helpers and checks this file uses; tests/test_net_boss.gd runs the one-process checks). Seed 1, heretic
## spawns off, creatures off.
##   leader  host (miner) + c1 (paladin) go down the entrance and walk into the boss's room (bot walkpath): it wakes for two, its HP set low
##           (--test-boss-hp) and its first pillar one blow from breaking (--test-pillar-hits). The miner breaks the pillar and steps out of
##           its fall circle; both fight the boss with its own attacks until it dies (and the heretics it called). Every attack the host
##           started is drawn on c1 from the host's tick, the debris lands there on the host's tick, both get one relic, the world's flag on
##           both. A late c2 (cleric) joins then and walks into the room: the boss lies dead and the pillars are as the host's.
##   altar   host (cleric) places a relic bench by the altar; c1 (paladin, a relic) crafts the altar upgrade at it (the crafting panel: a
##           CRAFT); c2 (archer) watches. Every machine draws candA and the 9-tile light from the host's tier; a late c3 (miner) has them
##           on its welcome.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=leader,altar).

const DOWN: String = "walkto:70,52;walkto:73,48;aimat:73,47;pick;wait:20;"
## IMPL (tests, README "측정" M12c): the most the host sends a second while it and one client fight the boss in the dungeon (the players'
## states with their vitals, the boss's batches and events, the relics' inventories): measured about 2.1 KB/s.
const FIGHT_HOST_MAX_BPS: float = 4000.0
## Seed 1's boss room (BossRoom.for_seed(1): (47,33) 11 x 9, home (52,38), pillars (49,39) (56,35) (56,40) (48,35)); the first pillar's
## open tile below it and a tile outside its fall circle.
const PILLAR: String = "49,39"
const BELOW_PILLAR: String = "49,40"
const CLEAR_OF_IT: String = "52,41"
const LEADER_HOST_FLAGS: Array[String] = ["--test-boss-hp=300", "--test-pillar-hits=1:8"]
const LEADER_HOST: String = ("select:8;" + DOWN + "waitmap:2,dungeon;wait:30;walkpath:" + BELOW_PILLAR + ";aimat:" + PILLAR + ";use:1;wait:4;" +
	"aim:off;walkpath:" + CLEAR_OF_IT + ";mark:broke;aimboss;bossfight:1500,14;waitboss:dead,1800;aim:off;mark:dead;fight:900,0,14;aim:off;" +
	"waitmap:3,dungeon,3000;wait:420")
const LEADER_C1: String = ("select:8;" + DOWN + "waitmap:2,dungeon;wait:60;walkpath:54,39;aimboss;bossfight:1800,14;waitboss:dead,1800;" +
	"aim:off;fight:900,0,14;aim:off;mark:done;wait:240")
const LEADER_C2: String = DOWN + "waitmap:3,dungeon;walkpath:51,36;wait:120;mark:seen;wait:60"

const ALTAR_HOST_GIVE: String = "--give=relic_bench"
const ALTAR_HOST: String = "wait:20;select:1;walkto:60,50;walkto:63,52;aimat:63,51;use:1;wait:20;mark:bench;aim:off;walkto:59,52;wait:900"
const ALTAR_C1_GIVE: String = "--give=boss_relic:1"
const ALTAR_C1: String = ("waitplaced:63,51,relic_bench;walkto:68,52;walkto:64,53;walkto:64,52;tab;wait:5;craft:1;wait:30;tab;mark:crafted;" +
	"wait:240")
const ALTAR_C2: String = "walkto:66,53;wait:600"
const ALTAR_C3: String = "move:0,1,30;move:1,0,20;wait:30;mark:seen;wait:30"


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("leader_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("leader"):
		await _session_leader()
	if only.is_empty() or only.has("altar"):
		await _session_altar()
	_check_logs()
	note("leader sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## The host tick at the end of a boss log line ("... tick=<n>"), -1 when none.
static func _tick_of(line: String) -> int:
	var at: int = line.rfind(" tick=")
	return line.substr(at + 6).to_int() if at >= 0 else -1


## The host's attack start ticks by kind ("boss attack <kind> at=... tick=<n>": the tick it started).
func _host_attacks(lines: PackedStringArray) -> Dictionary[String, Array]:
	var out: Dictionary[String, Array] = {}
	for line: String in lines:
		var at: int = line.find(" boss attack ")
		if at < 0:
			continue
		var kind: String = line.substr(at + 13).get_slice(" ", 0)
		var ticks: Array = out.get(kind, [])
		ticks.append(_tick_of(line))
		out[kind] = ticks
	return out


func _session_leader() -> void:
	var dir: String = _session_dir("leader")
	var port: int = _port()
	if not check(port > 0, "leader: free port"):
		return
	var host_flags: Array = ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=miner", "--bot=" + LEADER_HOST]
	host_flags.append_array(LEADER_HOST_FLAGS)
	var host: Instance = _launch(dir, "host", host_flags, 115)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "leader: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=paladin", "--bot=" + LEADER_C1], 115)
	if not check(await _wait_files([dir.path_join("host.dead.marker")], 85.0), "leader: the boss died"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + LEADER_C2], 70)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 70.0),
		"leader: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("leader", {host: 0, c1: 0, c2: 0})
	_check_agreement("leader", host, [c1, c2], 3)
	var lines: PackedStringArray = _log_lines(host)
	check(_line_with(lines, "host boss woke players=2 hp=%d" % BossSim.hp_for(2)).length() > 0, "leader: it woke for the two (x1.6 HP)")
	var broke: String = _line_with(lines, "host boss pillar 0 broken at=49,39")
	var debris: String = _line_with(lines, "host boss debris pillar=0 ")
	check(broke.length() > 0 and debris.length() > 0, "leader: the miner broke the first pillar and its debris fell (%s)" % debris)
	var killed: String = _line_with(lines, "host boss killed by=")
	check(killed.contains("players=2"), "leader: killed with two on the map (%s)" % killed)
	check_eq(_count_lines(lines, "host relic slot="), 2, "leader: two relic lines")
	check(_line_with(lines, "host relic slot=0 class=miner given=1").length() > 0 and _line_with(lines, "host relic slot=1 class=paladin given=1").length() > 0,
		"leader: one relic each")
	var host_attacks: Dictionary[String, Array] = _host_attacks(lines)
	var total: int = 0
	for kind: String in host_attacks:
		total += host_attacks[kind].size()
	check(total >= 1, "leader: the boss attacked (%s)" % str(host_attacks))
	var hb: Dictionary = host.result.get("boss", {})
	var c1b: Dictionary = c1.result.get("boss", {})
	var c2b: Dictionary = c2.result.get("boss", {})
	var seen: Dictionary = c1b.get("attack_ticks", {})
	var drawn_same: bool = true
	for kind2: String in host_attacks:
		var theirs: Array = seen.get(kind2, [])
		for t: int in host_attacks[kind2]:
			var tick: int = t
			drawn_same = drawn_same and (theirs.has(float(tick)) or theirs.has(tick))
	check(drawn_same, "leader: c1 drew every attack the host started, from the host's tick (host %s, c1 %s)" % [str(host_attacks), str(seen)])
	var debris_ticks: Array = c1b.get("debris_ticks", [])
	check(debris_ticks.has(float(_tick_of(debris))) or debris_ticks.has(_tick_of(debris)), "leader: c1 drew the debris on the host's tick %d (%s)" % [
		_tick_of(debris), str(debris_ticks)])
	for inst: Instance in [host, c1, c2]:
		var b: Dictionary = inst.result.get("boss", {})
		check_eq(str(b.get("progress", "")), "altar_tier=0 boss_defeated=true", "leader/%s: the world's flag" % inst.name)
	var players: Array = host.result.get("players", [])
	var relics: int = 0
	for p: Dictionary in players:
		if str(p.get("inventory", "")).contains("boss_relic x1"):
			relics += 1
	check_eq(relics, 2, "leader: two players hold a relic on the host")
	check_eq(str(c2b.get("drawn", "")), "dead", "leader: the late cleric draws the boss lying dead")
	check(str(c2b.get("looks", "?")) == str(hb.get("looks", "!")) and str(c1b.get("looks", "?")) == str(hb.get("looks", "!")),
		"leader: every machine draws the host's pillars (%s / %s / %s)" % [hb.get("looks"), c1b.get("looks"), c2b.get("looks")])
	var stats: Dictionary = host.result.get("stats", {})
	for key: Variant in stats:
		if str(key).begins_with("fight/"):
			var bucket: Dictionary = stats[key]
			note("leader: host %s sent %.0f B/s over %.1f s" % [key, _num(bucket, "sent_bps"), _num(bucket, "sec")])
	var fight: Dictionary = stats.get("fight/2", {})
	check(_num(fight, "sec") > 1.0 and _num(fight, "sent_bps") <= FIGHT_HOST_MAX_BPS, "leader: the host's fight traffic within %.0f B/s (%s)" % [
		FIGHT_HOST_MAX_BPS, fight.get("sent_bps")])
	note("leader: host attacks %s, c1 boss bodies %s, events: bolts %s circles %s pillars %s" % [str(host_attacks), c1b.get("bodies"),
		c1b.get("bolts"), c1b.get("circles"), c1b.get("pillar_events")])


func _session_altar() -> void:
	var dir: String = _session_dir("altar")
	var port: int = _port()
	if not check(port > 0, "altar: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=2", "--net-expect=3", "--class=cleric", "--test-allow-give",
		ALTAR_HOST_GIVE, "--bot=" + ALTAR_HOST], 90)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "altar: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=paladin", ALTAR_C1_GIVE, "--bot=" + ALTAR_C1], 90)
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + ALTAR_C2], 90)
	if not check(await _wait_files([dir.path_join("c1.crafted.marker")], 60.0), "altar: c1 crafted"):
		await _reap()
		return
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + ALTAR_C3], 60)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json"), dir.path_join("c3.json")], 60.0),
		"altar: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2, c3]):
		return
	_expect_codes("altar", {host: 0, c1: 0, c2: 0, c3: 0})
	_check_agreement("altar", host, [c1, c2, c3], 4)
	var lines: PackedStringArray = _log_lines(host)
	check(_line_with(lines, "host place slot=0 map=0 item=relic_bench").length() > 0, "altar: the host placed the relic bench")
	# M12c-fix (review): c1 and c2 start together, so either may join first: c1's slot is the one its own result names (1 or 2).
	var s1: int = roundi(_num(c1.result, "slot"))
	check(s1 == 1 or s1 == 2, "altar: c1's slot from its result (%d)" % s1)
	var raised: String = _line_with(lines, "host altar tier=1 radius_tiles=9 radius_px=144")
	check(raised.contains(" slot=%d recipe=altar_upgrade" % s1), "altar: c1's CRAFT raised the tier on the host (%s)" % raised)
	check(_line_with(lines, "host craft slot=%d map=0 recipe=altar_upgrade" % s1).length() > 0, "altar: logged as a craft")
	var hb: Dictionary = host.result.get("boss", {})
	for inst: Instance in [host, c1, c2, c3]:
		var b: Dictionary = inst.result.get("boss", {})
		check_eq(str(b.get("progress", "")), "altar_tier=1 boss_defeated=false", "altar/%s: tier 1" % inst.name)
		check_eq(_num(b, "radius_px"), 144.0, "altar/%s: the 9-tile safe radius" % inst.name)
		check_eq(_num(b, "light_px"), _num(hb, "light_px"), "altar/%s: the host's light (%s texels)" % [inst.name, hb.get("light_px")])
		check_eq(str(b.get("altar_picture", "")), "candA", "altar/%s: candA drawn" % inst.name)
		check(_flag(b, "ring_lit"), "altar/%s: the ring tier 1 adds is in its light (the host's field and spawn rule)" % inst.name)
	check_eq(_num(hb, "light_px"), 290.0, "altar: 290 texels")
	for c: Instance in [c1, c2]:
		var cb: Dictionary = c.result.get("boss", {})
		check_eq(_num(cb, "tier_changes"), 1.0, "altar/%s: the world message told it once" % c.name)
	var c3b: Dictionary = c3.result.get("boss", {})
	check_eq(_num(c3b, "tier_changes"), 0.0, "altar/c3: its welcome already had it")
	var players: Array = host.result.get("players", [])
	var c1_seen: int = 0
	for p: Dictionary in players:
		if roundi(_num(p, "slot")) == s1:
			c1_seen += 1
			check_eq(str(p.get("class", "")), "paladin", "altar: slot %d is c1's paladin" % s1)
			check(not str(p.get("inventory", "")).contains("boss_relic"), "altar: c1's relic spent (%s)" % p.get("inventory"))
	check_eq(c1_seen, 1, "altar: c1 in the host's players")
	note("altar: the host's spawn tiles after the upgrade %s; %s" % [hb.get("spawn_tiles"), raised])
