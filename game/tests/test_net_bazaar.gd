extends "res://tests/test_net_market.gd"
## M8b: the merchant and his shop in a real session, the second one (separate processes over localhost ENet, like
## tests/test_net_session.gd, whose helpers and checks this file uses; tests/test_net_market.gd runs `market`). Seed 1, spawns
## off, the host's shop restocks every BAZAAR_RESTOCK ticks (--test-shop-restock), the cleric starts at 10 HP.
##   bazaar  host (paladin) + c1 (miner) + c2 (cleric). c1 opens the shop and buys both holy waters (sold out). c2 walks out of
##           the light holding 101 money; the host brings a heretic, c2 goes down, gives up and dies: half its money (51) falls
##           in its bag on every machine; the host kills the heretic and c1 picks the bag up on its machine (51 money more,
##           the bag gone everywhere). The restock comes on the host's clock and every machine sees holy water back at 2.
##           c1 then lifts the altar, carries it 13 tiles west and puts it down: the merchant waits while it is carried and
##           then goes beside the new place on every machine; c2 walks to him there, opens his shop and buys a torch.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=bazaar).

## The restock period of this session (ticks of host time): the holy water is sold out and the death done well before it.
const BAZAAR_RESTOCK: int = 1800
const BAZAAR_HOST: String = ("select:8;waitat:63,58,1800;heretic:63,61;mark:heretic;waitdown:1,1500;wait:200;fight:1500,0,18;" +
	"mark:killed;walkto:63,53;waitstock:3,2,3000;mark:refilled;waitplaced:54,49,merchant,3000;mark:moved;wait:240")
const BAZAAR_C1_GIVE: String = "--give=money:100"
const BAZAAR_C1: String = ("walkto:66,50;aimat:67,50;wait:10;pick;wait:10;mark:open;buy:3;wait:20;buy:3;wait:20;tab;aim:off;" +
	"mark:bought;waitdown:1,1800;waitfoe:0,1800;walkto:63,57;aimat:63,58;wait:5;pick;wait:20;aim:off;mark:picked;" +
	"waitstock:3,2,3000;mark:refilled;walkto:63,49;aimat:63,48;hold:125;walkto:50,48;aimat:50,47;wait:6;use:1;wait:30;" +
	"aim:off;mark:placed;wait:120")
const BAZAAR_C2_GIVE: String = "--give=money:101"
const BAZAAR_C2: String = ("walkto:60,45;walkto:60,52;walkto:63,55;walkto:63,58;mark:out;waitlife:down,1500;hold:80;" +
	"waitlife:dead,300;waitlife:alive,900;mark:respawned;waitstock:3,2,3000;mark:refilled;waitplaced:54,49,merchant,3000;" +
	"walkto:59,49;walkto:59,51;walkto:55,51;walkto:55,49;aimat:54,49;wait:10;pick;wait:10;mark:open;buy:4;wait:30;tab;" +
	"aim:off;mark:bought;wait:60")


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("bazaar_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("bazaar"):
		await _session_bazaar()
	_check_logs()
	note("bazaar session took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


func _session_bazaar() -> void:
	var dir: String = _session_dir("bazaar")
	var port: int = _port()
	if not check(port > 0, "bazaar: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=2", "--net-expect=2", "--class=paladin",
		"--test-allow-give", "--test-start-hp=cleric:10", "--test-shop-restock=%d" % BAZAAR_RESTOCK, "--bot=" + BAZAAR_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "bazaar: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", BAZAAR_C1_GIVE, "--bot=" + BAZAAR_C1], 100)
	if not check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "bazaar: c1 joined"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", BAZAAR_C2_GIVE, "--bot=" + BAZAAR_C2], 100)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json")], 100.0),
		"bazaar: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2]):
		return
	_expect_codes("bazaar", {host: 0, c1: 0, c2: 0})
	_check_agreement("bazaar", host, [c1, c2], 3)
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check_eq(_count_lines(lines, "host shop slot=%d buy item=holy_water" % s1), 2, "bazaar: c1 bought both holy waters")
	# The death: half of c2's money in its bag, c1 picked it up.
	var died: String = _line_with(lines, "host died slot=%d" % s2)
	check(died.contains(" bag=") and not died.contains("bag=none"), "bazaar: c2 died, its bag on the surface (%s)" % died)
	var bag_line: String = _line_with(lines, "host edit drop+")
	check(bag_line.contains(" money x51 "), "bazaar: the bag holds 51 of c2's 101 money (%s)" % bag_line)
	check(_line_with(lines, "host pickup slot=%d item=money count=51" % s1).length() > 0,
		"bazaar: c1 picked the bag up: 51 money (%s)" % _line_with(lines, "host pickup slot="))
	for inst: Instance in [host, c1, c2]:
		var drops: Array = _map_of(inst.result, "0").get("drops", [])
		check(drops.is_empty(), "bazaar/%s: the bag gone on its machine (%s)" % [inst.name, drops])
	# The restock on the host's clock, seen everywhere.
	check(_line_with(lines, "host shop restock n=1 ").contains("holy_water=2/2"), "bazaar: the host restocked (%s)" %
		_line_with(lines, "host shop restock"))
	for inst2: Instance in [host, c1, c2]:
		check(_log_count(inst2, " edit shop holy_water=2 ") == 1, "bazaar/%s: the restock's shop stock edit reached its world" % inst2.name)
	# The altar moved by c1, the merchant followed.
	check(_line_with(lines, "host altar slot=%d map=0 picked_up" % s1).length() > 0 and _line_with(lines, "host merchant waits at=67,50").length() > 0,
		"bazaar: c1 lifted the altar, the merchant waited")
	check(_line_with(lines, "host altar slot=%d map=0 placed at=49,45" % s1).length() > 0, "bazaar: c1 put it down at (49, 45)")
	check(_line_with(lines, "host merchant at=54,49 from=67,50").length() > 0, "bazaar: the merchant went to (54, 49)")
	for inst3: Instance in [host, c1, c2]:
		check_eq(str(_map_of(inst3.result, "0").get("merchant", "")), "54,49", "bazaar/%s: the merchant at (54, 49)" % inst3.name)
		check_eq(str(_map_of(inst3.result, "0").get("altar", "")), "49,45", "bazaar/%s: the altar at (49, 45)" % inst3.name)
	check(_line_with(lines, "host shop slot=%d buy item=torch" % s2).length() > 0, "bazaar: c2 bought a torch at the new place")
	check(_log_count(c2, "EVENSONG_SHOP open at=54,49") == 1, "bazaar/c2: opened the shop at the new place on its machine")
	# Money, on the host and in each client's own inventory.
	var want: Dictionary[int, int] = {s1: 100 - 2 * Shop.price_of(&"holy_water") + 51, s2: 50 - Shop.price_of(&"torch")}
	for inst4: Instance in [c1, c2]:
		var slot: int = roundi(_num(inst4.result, "slot"))
		var on_host: int = _money(str(_player(host, slot).get("inventory", "")))
		var own: int = _money(str(_player(inst4, slot).get("inventory", "")))
		check(on_host == want[slot] and own == want[slot], "bazaar/%s: %d money on the host and on its own machine (%d, %d)" % [
			inst4.name, want[slot], on_host, own])
	var host_shop: String = str(_map_of(host.result, "0").get("shop", ""))
	check(host_shop.contains("holy_water=2/2"), "bazaar: the stock after the restock (%s)" % host_shop)
	for inst5: Instance in [c1, c2]:
		check_eq(str(_map_of(inst5.result, "0").get("shop", "")), host_shop, "bazaar/%s: the host's stock" % inst5.name)
	var hres: Dictionary = host.result.get("shop", {})
	check(roundi(_num(hres, "merchant_moves")) == 2 and roundi(_num(hres, "restocks")) >= 1, "bazaar: the host's shop results (%s)" % hres)
	_fight_traffic_notes("bazaar", host, c1)
