extends "res://tests/test_net_session.gd"
## M7c: the workbench chain's anvil, tier-1 gear and its durability, the storage chest and a tree in a real session (separate
## processes over localhost ENet, like tests/test_net_session.gd, whose helpers and checks this file uses). Seed 1, spawns
## off, --test-start-hp=miner:20.
##   stock  host (paladin) + c1 (miner) + c2 (cleric) + a late c3 (archer): four players. The host places an anvil and a
##          storage chest (in the light). c1 crafts a tier-1 sword at the anvil (the crafting panel: a CRAFT), puts its
##          armour on (ARMOR), swings the sword at the air, walks out of the light where the host brings in a heretic,
##          is downed (the armour takes its part of each knife and wears), gives up and dies on its own machine (the death
##          wear), comes back at the altar. c2 walks to the tree east of the light and chops it to a stump (the axe's swings
##          predicted, the stump an edit everyone sees). Both then stand at the chest; the host stores iron ingots and
##          stones; c1 and c2 take the ingots' slot at once: exactly one gets them, the other finds the slot empty. c3
##          joins then and gets the stump, the anvil and the chest's stones in its snapshot.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=stock).

const STOCK_HOST_GIVE: String = "--give=anvil,storage_chest,ingot_iron:20,stone_a:30"
const STOCK_HOST: String = ("wait:20;select:1;walkto:60,50;walkto:63,52;aimat:63,51;use:1;wait:20;mark:anvil;" +
	"walkto:59,52;walkto:59,43;walkto:63,43;select:2;aimat:63,44;use:1;wait:20;mark:chest;aim:off;" +
	"waitat:63,58;wait:10;heretic:63,61;mark:heretic;waitat:61,43;waitat:65,43;wait:30;aimat:63,44;pick;wait:5;store:3;" +
	"wait:10;store:4;wait:20;tab;mark:stocked;aim:off;wait:240")
const STOCK_C1_GIVE: String = "--give=ingot_iron:2,planks:1,armor_t1"
const STOCK_C1: String = ("waitplaced:63,51,anvil;walkto:68,52;walkto:63,53;walkto:63,52;tab;wait:5;craft:1;wait:20;tab;" +
	"mark:crafted;select:3;use:1;wait:20;mark:armed;select:1;aim:20,0;use:60;aim:off;wait:20;mark:swung;walkto:63,58;" +
	"mark:out;waitlife:down,1500;hold:80;waitlife:dead,300;waitlife:alive,900;mark:respawned;walkto:66,43;walkto:61,43;" +
	"aimat:62,44;waitchest:63,44,ingot_iron,1800;pick;wait:3;take:1;wait:20;tab;mark:took;aim:off;wait:120")
const STOCK_C2_GIVE: String = "--give=axe"
const STOCK_C2: String = ("walkto:70,44;walkto:78,44;walkto:85,50;walkto:85,53;walkto:83,53;select:1;aimat:83,52;use:200;" +
	"wait:20;aim:off;mark:chopped;walkto:85,53;walkto:85,50;walkto:78,44;walkto:70,44;walkto:65,43;aimat:64,44;" +
	"waitchest:63,44,ingot_iron,1800;pick;wait:3;take:1;wait:20;tab;mark:took;aim:off;wait:120")
const STOCK_C3: String = "wait:30;mark:seen;move:-1,0,20;move:1,0,20;wait:30"
const TREE: Vector2i = Vector2i(83, 52)


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("stock_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("stock"):
		await _session_stock()
	_check_logs()
	note("stock session took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_stock() -> void:
	var dir: String = _session_dir("stock")
	var port: int = _port()
	if not check(port > 0, "stock: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=2", "--net-expect=3", "--class=paladin",
		"--test-allow-give", "--test-start-hp=miner:20", STOCK_HOST_GIVE, "--bot=" + STOCK_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "stock: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", STOCK_C1_GIVE, "--bot=" + STOCK_C1], 100)
	if not check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "stock: c1 joined"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", STOCK_C2_GIVE, "--bot=" + STOCK_C2], 100)
	if not check(await _wait_files([dir.path_join("c1.took.marker"), dir.path_join("c2.took.marker"),
			dir.path_join("host.stocked.marker")], 90.0), "stock: crafted, died, chopped, both at the chest"):
		await _reap()
		return
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + STOCK_C3], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json"),
		dir.path_join("c3.json")], 80.0), "stock: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2, c3]):
		return
	_expect_codes("stock", {host: 0, c1: 0, c2: 0, c3: 0})
	_check_agreement("stock", host, [c1, c2, c3], 4)
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check(_count_lines(lines, "host place slot=0 map=0 item=anvil at=63,51") == 1
		and _count_lines(lines, "host place slot=0 map=0 item=storage_chest at=63,44") == 1, "stock: the host placed the anvil and the chest")
	check(_line_with(lines, "host craft slot=%d map=0 recipe=sword_t1" % s1).contains("item=sword_t1 count=1"),
		"stock: c1 crafted a tier-1 sword at the anvil (%s)" % _line_with(lines, "host craft slot="))
	check(_line_with(lines, "host armor slot=%d on" % s1).contains("armor_t1 100/100"), "stock: c1 put its armour on")
	# Durability: the sword wore per attack, the armour per knife, then the death took 20 % of each, on the host and in c1's
	# own inventory alike.
	var ops: Dictionary = host.result.get("ops", {})
	var m1: Dictionary = ops.get(str(s1), {})
	var combat: Dictionary = m1.get("combat", {})
	var attacks: int = roundi(_num(combat, "attacks"))
	var hurt: int = roundi(_num(combat, "hurt"))
	var sword_left: int = Gear.max_durability(&"sword_t1") - attacks - Gear.death_wear_points(&"sword_t1")
	var armour_left: int = Gear.max_durability(&"armor_t1") - hurt - Gear.death_wear_points(&"armor_t1")
	check(attacks >= 2 and hurt >= 3 and roundi(_num(combat, "died")) == 1, "stock/c1: swung %d times, took %d knives, died once" % [
		attacks, hurt])
	var want: Array = ["0:sword_t1 %d/120" % sword_left, "armor:armor_t1 %d/100" % armour_left]
	check_eq(_player(host, s1).get("gear", []), want, "stock: the host's c1 holds the worn sword and armour")
	check_eq(_player(c1, s1).get("gear", []), want, "stock/c1: its own inventory holds the host's durability after its death")
	check(_line_with(lines, "host gear slot=%d death wear items=2" % s1).contains("sword_t1"), "stock: the host logged the death wear")
	# The tree.
	check_eq(_count_lines(lines, "host tree slot=%d map=0 felled at=83,52" % s2), 1, "stock: c2's axe felled the tree")
	check(_count_lines(lines, "host tree slot=%d map=0 chop at=83,52 hits=" % s2) == Config.TREE_CHOP_HITS - 1,
		"stock: after four chops")
	for inst: Instance in [host, c1, c2, c3]:
		var b: Dictionary = _map_of(inst.result, "0").get("builds", {})
		check(roundi(_num(b, "stumps")) == 1 and roundi(_num(b, "anvils")) == 1 and roundi(_num(b, "chest_count")) == 1,
			"stock/%s: the stump, the anvil and the chest (%s)" % [inst.name, b])
		var chests: Dictionary = b.get("chests", {})
		check_eq(str(chests.get("62,44", "")), "0:stone_a x30", "stock/%s: the chest's stones (stored after the ingots were taken: the first empty slot)" % inst.name)
	check(str(_player(c2, s2).get("inventory", "")).contains("log x%d" % Config.TREE_LOGS), "stock/c2: the logs (%s)" % _player(c2, s2).get("inventory", ""))
	# The chest at once: one of them took the ingots, the other found the slot empty.
	var took: Array[int] = []
	for s: int in [s1, s2]:
		if _line_with(lines, "host chest slot=%d map=0 take item=ingot_iron count=20" % s) != "":
			took.append(s)
	check_eq(took.size(), 1, "stock: exactly one of c1 and c2 took the 20 ingots (%s)" % [took])
	var loser: int = s2 if took.has(s1) else s1
	check(_line_with(lines, "host request_refused slot=%d chest map=0" % loser).contains(Storage.WHY_EMPTY),
		"stock: the other found the slot empty (%s)" % _line_with(lines, "request_refused slot=%d chest" % loser))
	var winner: Instance = c1 if took.has(s1) else c2
	check(str(_player(winner, took[0] if not took.is_empty() else -1).get("inventory", "")).contains("ingot_iron x20"),
		"stock/%s: the 20 ingots in its own inventory" % winner.name)
	var welcome: String = _line_with(_log_lines(c3), " welcome slot=")
	check(welcome.contains(" stumps=1 stations=1 chests=1 chest_items=30 "),
		"stock/c3 (late): its snapshot had the stump, the anvil and the chest's 30 stones (%s)" % welcome)
	_fight_traffic_notes("stock", host, c1)
	for key: String in host.result.get("stats", {}):
		if key.begins_with("req") or key.begins_with("act"):
			var b2: Dictionary = host.result["stats"][key]
			note("stock host %s: sends %s B/s in %s pkt/s over %s s" % [key, b2.get("sent_bps"), b2.get("packets_ps"), b2.get("sec")])
