extends "res://tests/test_net_session.gd"
## M8b: the merchant's shop in a real session (separate processes over localhost ENet, like tests/test_net_session.gd, whose
## helpers and checks this file uses; tests/test_net_bazaar.gd runs the other one). Seed 1, spawns off, the merchant at
## (67, 50) beside the altar.
##   market  host (paladin) + c1 (miner) + c2 (cleric) + a late c3 (archer): four players. Each walks next to the merchant, opens
##           his shop with F (the panel on its own machine) and trades through it (bot buy / sell = the panel's clicks: BUY /
##           SELL requests): the host buys a healing potion and a holy water while c1 buys a torch and sells a stone and c2
##           sells a log and buys a buff potion (two and three players shopping at once; M8 review: c2's click on an empty slot
##           first sends nothing). One holy water is then left: c1 and
##           c2 both wait until their own machine shows 1 left and click it: exactly one gets it, the other is refused (sold
##           out) with its money untouched. c1 sells its stones (shift: the whole stack). c3 joins then: its snapshot has the
##           merchant where he stands and the stock as it is, and it buys a torch. Every machine ends with the host's world
##           (the stock is in its hash), every inventory as the host has it, the money only what the trades moved.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=market).

const MARKET_HOST_GIVE: String = "--give=money:100"
const MARKET_HOST: String = ("walkto:60,51;walkto:68,51;walkto:68,50;aimat:67,50;wait:10;pick;wait:10;mark:open;buy:1;wait:30;" +
	"waitat:66,50;waitat:67,49;wait:90;" +
	"buy:3;wait:30;mark:bought;waitstock:3,0,1800;wait:20;tab;mark:closed;aim:off;wait:240")
const MARKET_C1_GIVE: String = "--give=money:100,stone_a:20"
const MARKET_C1: String = ("walkto:66,50;aimat:67,50;wait:10;pick;wait:10;mark:open;buy:4;wait:20;sell:2;wait:20;" +
	"waitstock:3,1,1800;buy:3;wait:30;waitstock:3,0,1800;mark:raced;wait:20;sell:2,all;wait:30;tab;mark:closed;aim:off;wait:60")
const MARKET_C2_GIVE: String = "--give=money:100,log:4"
const MARKET_C2: String = ("walkto:67,45;walkto:67,49;aimat:67,50;wait:10;pick;wait:10;mark:open;sell:24;wait:10;sell:2;wait:20;" +
	"buy:2;wait:20;" +
	"waitstock:3,1,1800;buy:3;wait:30;waitstock:3,0,1800;mark:raced;wait:30;tab;mark:closed;aim:off;wait:60")
const MARKET_C3_GIVE: String = "--give=money:10"
const MARKET_C3: String = ("wait:20;mark:seen;walkto:61,51;walkto:68,51;aimat:67,50;wait:10;pick;wait:10;mark:open;buy:4;" +
	"wait:30;tab;mark:closed;aim:off;wait:30")


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("market_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("market"):
		await _session_market()
	_check_logs()
	note("market session took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## The money in an inventory line ("0:money x48, 1:...": every money stack summed).
static func _money(inventory: String) -> int:
	var n: int = 0
	for part: String in inventory.split(", "):
		if part.contains("money x"):
			n += part.get_slice("money x", 1).to_int()
	return n


func _session_market() -> void:
	var dir: String = _session_dir("market")
	var port: int = _port()
	if not check(port > 0, "market: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=2", "--net-expect=3", "--class=paladin",
		"--test-allow-give", MARKET_HOST_GIVE, "--bot=" + MARKET_HOST], 100)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "market: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=miner", MARKET_C1_GIVE, "--bot=" + MARKET_C1], 100)
	if not check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "market: c1 joined"):
		await _reap()
		return
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", MARKET_C2_GIVE, "--bot=" + MARKET_C2], 100)
	if not check(await _wait_files([dir.path_join("c1.closed.marker"), dir.path_join("c2.closed.marker"),
			dir.path_join("host.bought.marker")], 90.0), "market: three traded, raced for the last holy water, closed the shop"):
		await _reap()
		return
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=archer", MARKET_C3_GIVE, "--bot=" + MARKET_C3], 80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json"),
		dir.path_join("c3.json")], 80.0), "market: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2, c3]):
		return
	_expect_codes("market", {host: 0, c1: 0, c2: 0, c3: 0})
	_check_agreement("market", host, [c1, c2, c3], 4)
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	var s3: int = roundi(_num(c3.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	check(_line_with(lines, "host merchant at=67,50").length() > 0 and _line_with(lines, "host shop open stock=").length() > 0,
		"market: the host opened with the merchant at (67, 50) and the shop")
	# Every player's trades, as the host made them.
	check(_count_lines(lines, "host shop slot=0 buy item=potion_healing") == 1 and _count_lines(lines, "host shop slot=0 buy item=holy_water") == 1,
		"market: the host bought a healing potion and a holy water")
	check(_count_lines(lines, "host shop slot=%d buy item=torch" % s1) == 1 and _count_lines(lines, "host shop slot=%d sell item=stone_a count=1 " % s1) == 1
		and _count_lines(lines, "host shop slot=%d sell item=stone_a count=19 " % s1) == 1, "market: c1 bought a torch, sold a stone, then the other 19")
	check(_count_lines(lines, "host shop slot=%d sell item=log count=1 " % s2) == 1 and _count_lines(lines, "host shop slot=%d buy item=potion_buff" % s2) == 1,
		"market: c2 sold a log and bought a buff potion")
	check_eq(_count_lines(lines, "host shop slot=%d buy item=torch" % s3), 1, "market: c3 (late) bought a torch")
	# The race for the last holy water.
	var won: Array[int] = []
	for s: int in [s1, s2]:
		if _count_lines(lines, "host shop slot=%d buy item=holy_water" % s) == 1:
			won.append(s)
	check_eq(won.size(), 1, "market: exactly one of c1 and c2 got the last holy water (%s)" % [won])
	var loser: int = s2 if won.has(s1) else s1
	check(_line_with(lines, "host request_refused slot=%d buy map=0 at=67,50 offer=2 item=holy_water" % loser).contains(Shop.WHY_SOLD_OUT),
		"market: the other was refused, %s (%s)" % [Shop.WHY_SOLD_OUT, _line_with(lines, "request_refused slot=%d buy" % loser)])
	# Money: every player's inventory as the host has it, and only what the trades moved.
	var potion: int = Shop.price_of(&"potion_healing")
	var holy: int = Shop.price_of(&"holy_water")
	var torch: int = Shop.price_of(&"torch")
	var buff: int = Shop.price_of(&"potion_buff")
	var stone: int = Shop.pays_for(&"stone_a")
	var log_pay: int = Shop.pays_for(&"log")
	var want: Dictionary[int, int] = {
		0: 100 - potion - holy,
		s1: 100 - torch + 20 * stone - (holy if won.has(s1) else 0),
		s2: 100 + log_pay - buff - (holy if won.has(s2) else 0),
		s3: 10 - torch,
	}
	var total: int = 0
	for slot: int in [0, s1, s2, s3]:
		var inv: String = str(_player(host, slot).get("inventory", ""))
		var mine: int = _money(inv)
		total += mine
		check_eq(mine, want[slot], "market: slot %d holds %d money on the host (%s)" % [slot, want[slot], inv])
	for inst: Instance in [c1, c2, c3]:
		var slot2: int = roundi(_num(inst.result, "slot"))
		check_eq(str(_player(inst, slot2).get("inventory", "")), str(_player(host, slot2).get("inventory", "?")),
			"market/%s: its own inventory = the host's copy" % inst.name)
	var moved: int = potion + 2 * holy + 2 * torch + buff - 20 * stone - log_pay
	check_eq(total, 310 - moved, "market: %d money in all = the 310 given minus what the trades moved (%d)" % [310 - moved, moved])
	# The stock, the same on every machine (and in every world hash, _check_agreement).
	var host_shop: String = str(_map_of(host.result, "0").get("shop", ""))
	var expect_stock: String = "potion_healing=2/3 potion_buff=2/3 holy_water=0/2 torch=8/10 ore_copper=5/5"
	check(host_shop.begins_with(expect_stock), "market: the host's stock (%s)" % host_shop)
	for inst2: Instance in [c1, c2, c3]:
		check_eq(str(_map_of(inst2.result, "0").get("shop", "")), host_shop, "market/%s: the host's stock" % inst2.name)
		check_eq(str(_map_of(inst2.result, "0").get("merchant", "")), "67,50", "market/%s: the merchant at (67, 50)" % inst2.name)
	# The late joiner's snapshot: the merchant and the stock as they were when it came (before its own torch).
	var welcome: String = _line_with(_log_lines(c3), " welcome slot=")
	check(welcome.contains(" merchant=67,50 shop=2/2/0/9/5/1/1/1/1/1/1 "),
		"market/c3 (late): its snapshot had the merchant and the stock as they were (%s)" % welcome)
	for inst3: Instance in [host, c1, c2, c3]:
		check(_log_count(inst3, "EVENSONG_SHOP open at=67,50") >= 1, "market/%s: opened the shop panel on its own machine" % inst3.name)
	var hres: Dictionary = host.result.get("shop", {})
	check(roundi(_num(hres, "buys")) == 6 and roundi(_num(hres, "sales")) == 3, "market: the host counted 6 buys and 3 sales (%s)" % hres)
	# M8 review: a click on a slot that is empty on the clicker's machine sends nothing (a SELL names what the slot shows).
	var refused: Dictionary = hres.get("refused", {})
	check(_log_count(c2, "EVENSONG_SHOP sell not sent slot=23: %s" % Shop.WHY_EMPTY) == 1 and not refused.has(Shop.WHY_EMPTY),
		"market/c2: its click on an empty slot sent nothing (host refusals %s)" % refused)
	for key: String in host.result.get("stats", {}):
		if key.begins_with("req") or key.begins_with("act") or key.begins_with("0/") or key.begins_with("joining"):
			var b2: Dictionary = host.result["stats"][key]
			note("market host %s: sends %s B/s (%s with UDP/IP) in %s pkt/s over %s s" % [key, b2.get("sent_bps"),
				b2.get("wire_sent_bps"), b2.get("packets_ps"), b2.get("sec")])
