extends "res://tests/test_net_session.gd"
## M13b: four players (game-concept §12 "2인 접속 → 4인") on a saved world, in real processes over localhost ENet (tests/test_net_session.gd's
## helpers and checks). Seed 1, spawns off, creatures off; every instance its own save folder inside the run folder.
##   quartet  the test writes the world "quartet" (seed 1, a tilled tile, no creatures or heretics) and four characters; the host (the
##            cleric "hc", faith 60) opens the world, the paladin "pal", the archer "arc" and the miner "min" bring theirs. All four walk,
##            stand (the traffic of four), pray together at the altar (all four in the circle, every turn answered right), go down and kill
##            the boss together (it wakes for four; its HP set low): a relic each. Then a fifth player brings the archer "dup" and is
##            refused as class_taken (the four classes taken, herbalist free, its file untouched) and a sixth brings the herbalist "hb" and
##            joins (five, a late joiner into the loaded world). Every machine agrees with the host; the four characters are written with
##            their relic, the world with the boss dead.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=quartet).

const KeepTest := preload("res://tests/test_net_keep.gd")
const SaveWorldTest := preload("res://tests/test_save_world.gd")
const Q_WORLD: String = "quartet"
## Everyone stands 2.5 s on its spawn slot (four idle; four walk on the way down): the traffic of four. The slots are in the prayer's circle
## (a walk east and back first left the host outside it: the altar blocked the walk east).
const Q_START: String = "wait:150;"
const Q_DOWN: String = "walkto:70,52;walkto:73,48;aimat:73,47;pick;wait:20;"
const Q_HOST: String = (Q_START + "wait:20;pray;waitprayer:turns,600;mark:turns;answer:auto;waitprayer:idle,2400;mark:prayed;select:8;" + Q_DOWN +
	"waitmap:4,dungeon,1800;wait:30;walkpath:50,41;aimboss;bossfight:2400;waitboss:dead,2400;aim:off;mark:dead;aimfoe;fight:900,0;aim:off;" +
	"wait:600")
const Q_JOIN: String = (Q_START + "waitprayer:gather,900;wait:10;pray;waitprayer:turns,600;answer:auto;waitprayer:idle,2400;select:8;" + Q_DOWN +
	"waitmap:4,dungeon,1800;wait:60;")
const Q_C1: String = Q_JOIN + "walkpath:54,39;aimboss;bossfight:2400,14;waitboss:dead,2400;aim:off;fight:900,0,14;aim:off;mark:done;wait:120"
const Q_C2: String = Q_JOIN + "walkpath:52,41;aimboss;bossfight:2400;waitboss:dead,2400;aim:off;fight:900,0;aim:off;mark:done;wait:120"
const Q_C3: String = Q_JOIN + "walkpath:51,40;aimboss;bossfight:2400,14;waitboss:dead,2400;aim:off;fight:900,0,14;aim:off;mark:done;wait:120"
const Q_C6: String = "move:0,1,30;wait:30;mark:seen;wait:30"
const Q_BOSS_HP: int = 240


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("quartet_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("quartet"):
		await _session_quartet()
	_check_logs()
	note("quartet sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## The saved world the host opens: seed 1 as generated, one tile tilled below the altar (so a joiner's world is the file's, not its
## generator's), no creatures and no heretics (the session tests' quiet world), written as the game writes it. Returns its surface hash.
static func write_world(root: String) -> String:
	var rig: SaveWorldTest.Rig = SaveWorldTest.Rig.fresh(Config.DEFAULT_SEED)
	var s: WorldData = rig.maps[Config.MAP_SURFACE]
	SaveWorldTest.Rig.put(s, [EditLog.WorldEdit.new(WorldData.Layer.FLOOR, Vector2i(62, 50), Terrain.SOIL)])
	for m: int in rig.arenas:
		rig.arenas[m].heretics.clear()
	rig.arenas[Config.MAP_SURFACE].herd.list.clear()
	rig.arenas[Config.MAP_SURFACE].herd.waiting.clear()
	rig.quiesce()
	var err: String = SaveStore.write_atomic(SaveStore.new(root).world_path(Q_WORLD), rig.capture(), false)
	return s.content_hash() if err.is_empty() else ""


func _session_quartet() -> void:
	var dir: String = _session_dir("quartet")
	var port: int = _port()
	if not check(port > 0, "quartet: free port"):
		return
	var devs: Dictionary[String, String] = {}
	for n: String in ["host", "c1", "c2", "c3", "c5", "c6"]:
		devs[n] = dir.path_join("dev_" + n)
	var world_hash: String = write_world(devs["host"])
	var money: Array = [[&"money", 20, ItemDB.Grade.NONE, -1]]
	KeepTest.write_character(devs["host"], KeepTest.make_character("hc", "cleric", money))
	KeepTest.write_character(devs["c1"], KeepTest.make_character("pal", "paladin", money, 80))
	KeepTest.write_character(devs["c2"], KeepTest.make_character("arc", "archer", money))
	KeepTest.write_character(devs["c3"], KeepTest.make_character("min", "miner", money))
	var dup_path: String = KeepTest.write_character(devs["c5"], KeepTest.make_character("dup", "archer", money))
	KeepTest.write_character(devs["c6"], KeepTest.make_character("hb", "herbalist", money))
	var dup_md5: String = KeepTest.md5_of(dup_path)
	if not check(not world_hash.is_empty() and not dup_md5.is_empty(), "quartet: the test wrote the world and six characters"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=4", "--net-expect-refused=1",
		"--world=" + Q_WORLD, "--character=hc", "--save-dir=" + devs["host"], "--test-start-resource=cleric:60",
		"--test-boss-hp=%d" % Q_BOSS_HP, "--bot=" + Q_HOST], 118)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "quartet: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = []
	for row: Array in [["c1", "pal", Q_C1], ["c2", "arc", Q_C2], ["c3", "min", Q_C3]]:
		var name: String = row[0]
		cs.append(_launch(dir, name, ["--join=127.0.0.1:%d" % port, "--character=" + str(row[1]), "--save-dir=" + devs[name],
			"--bot=" + str(row[2])], 115))
		check(await _wait_files([dir.path_join(name + ".welcome.marker")], READY_WAIT_SEC), "quartet: %s joined" % name)
	if not check(await _wait_files([dir.path_join("host.dead.marker")], 95.0), "quartet: the boss died"):
		await _reap()
		return
	var c5: Instance = _launch(dir, "c5", ["--join=127.0.0.1:%d" % port, "--character=dup", "--save-dir=" + devs["c5"], "--bot=wait:10"], 40)
	if not check(await _wait_files([dir.path_join("c5.json")], READY_WAIT_SEC), "quartet: the fifth player (an archer) was answered"):
		await _reap()
		return
	var c6: Instance = _launch(dir, "c6", ["--join=127.0.0.1:%d" % port, "--character=hb", "--save-dir=" + devs["c6"], "--bot=" + Q_C6], 60)
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	everyone.append_array([c5, c6])
	var files: Array[String] = []
	for inst: Instance in everyone:
		files.append(dir.path_join(inst.name + ".json"))
	check(await _wait_files(files, 60.0), "quartet: every instance wrote its result")
	await _reap()
	if not _load_results(dir, everyone):
		return
	_expect_codes("quartet", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0, c5: NetSession.EXIT_REFUSED, c6: 0})
	var clients: Array[Instance] = []
	clients.append_array(cs)
	clients.append(c6)
	_check_agreement("quartet", host, clients, 5)
	var hl: PackedStringArray = _log_lines(host)
	var loaded: String = _line_with(hl, "EVENSONG_SAVE world loaded name=quartet")
	check(_word_after(loaded, " hash=") == world_hash, "quartet: the host opened the test's world (%s)" % loaded)
	var gen_tilled: int = SessionReport.fields_of(SurfaceGen.generate(Config.DEFAULT_SEED))["tilled"]
	for inst: Instance in clients:
		var welcome: String = _line_with(_log_lines(inst), "%s welcome slot=" % inst.name)
		check(_int_after(welcome, " tilled=") == gen_tilled + 1, "quartet/%s: its world is the saved one (the tilled tile): %s" % [inst.name,
			welcome.left(160)])
	check_eq(roundi(_num(host.result, "characters_in")), 5, "quartet: five characters came in (the host's own and four joiners')")
	# The prayer of four.
	var hp: Dictionary = host.result.get("prayer", {})
	var last: Dictionary = hp.get("last", {})
	check(_num(last, "participants") == 4.0 and str(last.get("lamps", "")) == "lllllllll",
		"quartet: four prayed, nine lamps lit (%s)" % str(last))
	# The boss of four.
	check(_line_with(hl, "host boss woke players=4").length() > 0, "quartet: the boss woke for four (%s)" % _line_with(hl, "host boss woke"))
	check(_line_with(hl, "host boss killed by=").contains("players=4"), "quartet: killed with four on the map (%s)" %
		_line_with(hl, "host boss killed by="))
	check_eq(_count_lines(hl, "host relic slot="), 4, "quartet: four relic lines")
	for inst: Instance in cs:
		check(KeepTest._own_inventory(inst).contains("boss_relic x1"), "quartet/%s: holds its relic (%s)" % [inst.name,
			KeepTest._own_inventory(inst)])
	# The class rule: the fifth (an archer) refused, the sixth (the free herbalist) in.
	check_eq(str(c5.result.get("refused", "")), "class_taken", "quartet/c5: a fifth player with a taken class is refused")
	check_eq(c5.result.get("refused_taken", []), ["paladin", "miner", "archer", "cleric"], "quartet/c5: the four classes taken")
	check(_log_has(c5, "free: herbalist"), "quartet/c5: its line says herbalist is free")
	check(KeepTest.md5_of(dup_path) == dup_md5 and not FileAccess.file_exists(dup_path + ".bak"), "quartet/c5: its file untouched")
	var w6: String = _line_with(_log_lines(c6), "c6 welcome slot=")
	check(w6.contains(" class=herbalist ") and w6.contains(" players=5 "), "quartet/c6: the herbalist joins as the fifth player (%s)" %
		w6.left(120))
	# What was written: the four characters with their relic, the world with the boss dead.
	for row2: Array in [["host", "hc"], ["c1", "pal"], ["c2", "arc"], ["c3", "min"]]:
		var c: CharacterSave.Sheet = KeepTest.read_character(devs[str(row2[0])], str(row2[1]))
		check(c != null and KeepTest.count_in(c, Config.BOSS_RELIC) == 1, "quartet: %s was written with its relic (%s)" % [row2[1],
			c.describe() if c != null else "none"])
	var w: WorldSave.Saved = WorldSave.load_from(SaveStore.new(devs["host"]).world_path(Q_WORLD))
	check(w.ok() and w.maps[Config.MAP_SURFACE].progress.boss_defeated, "quartet: the world was written with the boss dead (%s)" % w.error)
	_quartet_traffic(host, cs[1])


## The traffic of four (the README "M13b" compares it with the two-player numbers of "측정").
func _quartet_traffic(host: Instance, client: Instance) -> void:
	var hs: Dictionary = host.result.get("stats", {})
	var cs: Dictionary = client.result.get("stats", {})
	var four: Dictionary = hs.get("4/4", {})
	check(_num(four, "sec") >= 0.5, "quartet: the host measured four walking (%s s)" % four.get("sec", 0))
	for key: String in ["4/4", "0/4", "fight/4", "req/4", "joining", "entering", "4/5", "0/5"]:
		if hs.has(key):
			var b: Dictionary = hs[key]
			note("quartet host %s: sends %s B/s (%s B/s with UDP/IP) in %s pkt/s, receives %s B/s, over %s s" % [key, b.get("sent_bps"),
				b.get("wire_sent_bps"), b.get("packets_ps"), b.get("received_bps"), b.get("sec")])
		if cs.has(key):
			var c: Dictionary = cs[key]
			note("quartet client %s %s: sends %s B/s (%s B/s with UDP/IP), receives %s B/s" % [client.name, key, c.get("sent_bps"),
				c.get("wire_sent_bps"), c.get("received_bps")])
	for key2: String in hs:
		if str(key2).begins_with("act") or str(key2).contains("split"):
			var a: Dictionary = hs[key2]
			note("quartet host %s: sends %s B/s over %s s" % [key2, a.get("sent_bps"), a.get("sec")])
