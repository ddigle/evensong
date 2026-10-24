extends "res://tests/test_net_session.gd"
## M5c: farming in real sessions (separate processes over localhost ENet, like tests/test_net_session.gd, whose helpers
## and checks this file uses). The hosts run --test-crop-ticks=60 (a crop stage in a second, the herbalist's in half).
##   farm   host (herbalist) + c1 (paladin) + a late c2 (archer), seed 1, spawns off. c1 tills a lit grass tile (62,49),
##          tries the poison herb there (refused: the herbalist's, ● R37), plants the healing herb (anyone) and waters
##          it; the host plants poison on the M1 soil (60,49) and waters it. Both crops grow on the host and every stage
##          reaches c1 as an edit; c2 joins while both grow and gets them in its snapshot. c1 cuts the host's ripe poison
##          crop (COMMON: the harvester decides), the host cuts c1's healing crop (FINE: the herbalist).
##   farm4  host (herbalist) + c1 (archer) + c2 (miner) + c3 (paladin), joining one after the other (slots 1, 2, 3: their
##          walks go around the altar from there): the host plants and waters poison, c1 tills and plants healing, c2
##          waters c1's tile once the crop is there, c3 walks to the north zone and channels; everyone agrees on the ripe
##          field and the purified ground.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=farm or farm4).

const CROP_TICKS: String = "--test-crop-ticks=60"
const FARM_HOST_GIVE: String = "--give=seed_poison:2,watering_can"
const FARM_HOST: String = ("wait:20;walkto:59,48;select:1;aimat:60,49;use:1;wait:10;select:2;use:2;wait:40;mark:planted;" +
	"waitfield:62,49,4,2400;walkto:63,50;select:8;aimat:62,49;use:2;wait:40;mark:harvested;wait:120")
## Four items at the start (the request budget's burst, Config.NET_OP_BURST); the sickle comes later (bot give).
const FARM_C1_GIVE: String = "--give=hoe,seed_healing:2,seed_poison:1,watering_can"
const FARM_C1: String = ("wait:60;walkto:61,49;select:1;aimat:62,49;use:2;wait:40;select:3;use:1;wait:8;select:2;use:1;wait:8;" +
	"select:4;use:2;wait:40;mark:planted;give:sickle;wait:300;waitfield:60,49,4,1800;select:5;aimat:60,49;use:2;wait:40;" +
	"mark:harvested;" +
	"wait:240")
const FARM_C2: String = "wait:30;mark:seen;wait:30"
const FARM4_HOST_GIVE: String = "--give=seed_poison:1,watering_can"
const FARM4_HOST: String = ("wait:20;walkto:59,48;select:1;aimat:60,49;use:1;wait:10;select:2;use:2;wait:40;" +
	"waitfield:60,49,4,1800;wait:60")
const FARM4_C1_GIVE: String = "--give=hoe,seed_healing:1"
const FARM4_C1: String = ("wait:60;walkto:66,51;walkto:61,51;walkto:61,49;select:1;aimat:62,49;use:2;wait:40;select:2;use:1;" +
	"wait:10;mark:planted;waitfield:62,49,4,1800;wait:60")
const FARM4_C2_GIVE: String = "--give=watering_can"
const FARM4_C2: String = ("wait:60;walkto:67,45;walkto:67,51;walkto:62,51;walkto:62,50;waitfield:62,49,0,1500;select:1;" +
	"aimat:62,49;use:2;wait:40;waitfield:62,49,4,1800;wait:60")
const FARM4_C3: String = "walkto:57,50;walkto:57,16;walkto:60,15;aimat:59,15;pick;wait:200;mark:purified;wait:60"
## The VEGETATION values a crop goes through (Farming.Field.value): planted dry, watered, then stages 1..4 wet.
const HEALING_VALUES: Array[int] = [104, 106, 114, 122, 130, 138]
const POISON_FAST_VALUES: Array[int] = [185, 187, 195, 203, 211, 219]


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("farm_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("farm"):
		await _session_farm()
	if only.is_empty() or only.has("farm4"):
		await _session_farm4()
	_check_logs()
	note("farm sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_farm() -> void:
	var dir: String = _session_dir("farm")
	var port: int = _port()
	if not check(port > 0, "farm: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=2", "--class=herbalist",
		"--test-allow-give", FARM_HOST_GIVE, CROP_TICKS, "--bot=" + FARM_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "farm: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=paladin", FARM_C1_GIVE, "--bot=" + FARM_C1], 100)
	if not check(await _wait_files([dir.path_join("c1.planted.marker"), dir.path_join("host.planted.marker")], 60.0),
			"farm: both planted"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + FARM_C2], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 80.0),
		"farm: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("farm", {host: 0, c1: 0, c2: 0})
	_check_agreement("farm", host, [c1, c2], 3)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check_eq(_count_lines(lines, "host farm slot=%d map=0 what=till at=62,49 class=paladin" % s1), 1, "farm: the host tilled for c1")
	check(_count_lines(lines, "host request_refused slot=%d use map=0 slot=2 at=62,49" % s1) == 1
		and _line_with(lines, "host request_refused slot=%d use map=0 slot=2" % s1).contains(Farming.WHY_HERBALIST),
		"farm: c1's poison herb refused, herbalist only (● R37: %s)" % _line_with(lines, "request_refused slot=%d" % s1))
	check_eq(_count_lines(lines, "host farm slot=%d map=0 what=plant at=62,49 class=paladin item=seed_healing" % s1), 1,
		"farm: the paladin planted the healing herb (anyone, ● R37)")
	check_eq(_count_lines(lines, "host farm slot=%d map=0 what=water at=62,49" % s1), 1, "farm: c1 watered it")
	check_eq(_count_lines(lines, "host farm slot=%d map=0 what=plant at=60,49 class=herbalist item=seed_poison" % hs), 1,
		"farm: the host planted poison")
	check(_count_lines(lines, "host field map=0 at=62,49 healing stage=4") == 1
		and _count_lines(lines, "host field map=0 at=60,49 poison stage=4") == 1, "farm: both crops ripened on the host")
	var c1_lines: PackedStringArray = _log_lines(c1)
	var missing: Array[String] = []
	for v: int in HEALING_VALUES:
		if _count_lines(c1_lines, "edit vegetation 62,49=%d " % v) != 1:
			missing.append("62,49=%d" % v)
	for v: int in POISON_FAST_VALUES:
		if _count_lines(c1_lines, "edit vegetation 60,49=%d " % v) != 1:
			missing.append("60,49=%d" % v)
	check(missing.is_empty(), "farm/c1: every stage of both crops reached it as an edit (missing %s)" % [missing])
	check(_line_with(lines, "host farm slot=%d map=0 what=harvest at=62,49" % hs).contains(
		"item=wild_healing count=%d grade=fine seeds=%d" % [Config.CROP_HARVEST_HERBS, Config.CROP_HARVEST_SEEDS]),
		"farm: the herbalist host cut c1's crop: FINE (%s)" % _line_with(lines, "what=harvest at=62,49"))
	check(_line_with(lines, "host farm slot=%d map=0 what=harvest at=60,49" % s1).contains(
		"item=wild_poison count=%d grade=common seeds=%d" % [Config.CROP_HARVEST_HERBS, Config.CROP_HARVEST_SEEDS]),
		"farm: the paladin cut the host's crop: COMMON (%s)" % _line_with(lines, "what=harvest at=60,49"))
	check_eq(_player(c1, s1).get("inventory", "?"), _player(host, s1).get("inventory", "!"), "farm/c1: its inventory = the host's copy")
	check(str(_player(c1, s1).get("inventory", "")).contains("wild_poison x%d" % Config.CROP_HARVEST_HERBS),
		"farm/c1: the poison herbs are in it (%s)" % _player(c1, s1).get("inventory", ""))
	var welcome: String = _line_with(_log_lines(c2), " welcome slot=")
	check(welcome.contains(" crops=2 ") and _int_after(welcome, "tilled=") >= 20,
		"farm/c2 (late): its snapshot had the field and both crops (%s)" % welcome)
	for inst: Instance in [host, c1, c2]:
		var mr: Dictionary = _map_of(inst.result, "0")
		var f: Dictionary = mr.get("fields", {})
		check_eq(f, _map_of(host.result, "0").get("fields", {}), "farm/%s: the same fields as the host" % inst.name)
	_fight_traffic_notes("farm", host, c1)


func _session_farm4() -> void:
	var dir: String = _session_dir("farm4")
	var port: int = _port()
	if not check(port > 0, "farm4: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=3", "--class=herbalist",
		"--test-allow-give", FARM4_HOST_GIVE, CROP_TICKS, "--bot=" + FARM4_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "farm4: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = []
	var setups: Array[Array] = [["c1", "archer", FARM4_C1_GIVE, FARM4_C1], ["c2", "miner", FARM4_C2_GIVE, FARM4_C2],
		["c3", "paladin", "", FARM4_C3]]
	for setup: Array in setups:
		var name: String = setup[0]
		var flags: Array = ["--join=127.0.0.1:%d" % port, "--class=" + str(setup[1]), "--bot=" + str(setup[3])]
		if not str(setup[2]).is_empty():
			flags.append(str(setup[2]))
		cs.append(_launch(dir, name, flags, 100))
		if not check(await _wait_files([dir.path_join(name + ".welcome.marker")], READY_WAIT_SEC), "farm4: %s joined" % name):
			await _reap()
			return
	var files: Array[String] = [dir.path_join("host.json")]
	for c: Instance in cs:
		files.append(dir.path_join(c.name + ".json"))
	check(await _wait_files(files, 90.0), "farm4: every instance wrote its result")
	await _reap()
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	if not _load_results(dir, everyone):
		return
	_expect_codes("farm4", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0})
	_check_agreement("farm4", host, cs, 4)
	var lines: PackedStringArray = _log_lines(host)
	var s1: int = roundi(_num(cs[0].result, "slot"))
	var s2: int = roundi(_num(cs[1].result, "slot"))
	var s3: int = roundi(_num(cs[2].result, "slot"))
	check_eq([s1, s2, s3], [1, 2, 3], "farm4: the slots the walks start from")
	check(_count_lines(lines, "host farm slot=%d map=0 what=till at=62,49 class=archer" % s1) == 1
		and _count_lines(lines, "host farm slot=%d map=0 what=plant at=62,49 class=archer item=seed_healing" % s1) == 1,
		"farm4: the archer tilled and planted healing")
	check_eq(_count_lines(lines, "host farm slot=%d map=0 what=water at=62,49 class=miner" % s2), 1, "farm4: the miner watered it")
	check(_count_lines(lines, "host purify slot=%d map=0 what=channel at=60,15" % s3) == 1, "farm4: the paladin's channel purified (%s)" % (
		_line_with(lines, "host purify slot=")))
	var host_fields: Dictionary = _map_of(host.result, "0").get("fields", {})
	var crops: Dictionary = host_fields.get("crops", {})
	check(str(crops.get("62,49", "")) == "healing stage=4 wet" and str(crops.get("60,49", "")) == "poison stage=4 wet fast",
		"farm4: both crops ripe and wet on the host (%s)" % [crops])
	for c: Instance in cs:
		check_eq(_map_of(c.result, "0").get("fields", {}), host_fields, "farm4/%s: the same fields" % c.name)
		check_eq(_map_of(c.result, "0").get("corrupted", -1), _map_of(host.result, "0").get("corrupted", -2),
			"farm4/%s: the same corruption left" % c.name)
	_fight_traffic_notes("farm4", host, cs[0])
