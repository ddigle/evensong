extends "res://tests/test_net_session.gd"
## M11c: hunting and capture in real sessions (separate processes over localhost ENet, like tests/test_net_session.gd, whose helpers and
## checks this file uses; tests/test_net_wild.gd runs the one-process checks, tests/test_net_herd.gd the natural herd and the traffic). Seed
## 1, heretic spawns off, natural creatures off: the host's bot puts each creature down (bot `creature`).
##   hunt   host (paladin, a bow in hand) + c1 (archer, 40 HP): three deer south of the light. The first, at 20 HP: the host's arrow, then
##          c1 goes after it: its blow kills, the whole hide on every machine. The second, at 20 HP: c1's arrow, then the host hunts it
##          down: the damaged hide. The third, hurt and resting: c1's one arrow kills it on a known tile; it picks up the hide and
##          the meat, eats a meat (12 HP, the M6 path), walks to the merchant, sells a hide and buys the shop's 일반 가죽 and a meat.
##   snare  host (paladin, a bow, two entries registered) + c1 (archer, three snares) + c2 (cleric) + a late c3 (miner). A rare creature,
##          hurt and resting: the host's arrow does nothing (the refused mark on every machine); c1 walks up and clicks it with the
##          snare: the host takes it on the throw's impact frame: one snare, one material, the entry and its first-material entry on
##          every machine, the class benefit lit. c1's next arrow lands with the host's 13. c3 joins then and has the whole collection,
##          the zone and the deer in its view.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=hunt,snare).

const HUNT_DEER_AT: String = "63,60"
## The host: stands at (61,56) with c1 at (65,56), both outside the deer's alert radius and inside the bow's reach. Paced with marks of its
## own: every wait for c1 is `waitat` on the tile c1 goes back to.
const HUNT_HOST: String = ("select:1;walkto:60,51;walkto:61,56;waitat:65,56,900;wait:20;creature:deer," + HUNT_DEER_AT + ",67;wait:10;aimprey;wait:4;" +
	"use:1;wait:30;aim:off;mark:first;waitprey:0,1500;mark:one;walkto:61,56;waitat:65,56,900;wait:20;creature:deer," + HUNT_DEER_AT + ",67;" +
	"wait:80;hunt:1500,0,130;aim:off;mark:two;walkto:61,56;waitat:65,56,900;wait:20;creature:deer," + HUNT_DEER_AT + ",30;waitprey:0,600;" +
	"mark:three;wait:600")
const HUNT_C1_GIVE: String = "--give=money:50"
## c1: the first deer: its own arrows after the host's one (it waits for it); the second: one arrow; the third: one arrow, then the
## ground and the shop.
const HUNT_C1: String = ("select:8;walkto:66,52;walkto:65,56;waitseen:1,900;wait:120;hunt:1500,0,130;aim:off;walkto:65,56;waitseen:1,900;wait:10;" +
	"aimprey;wait:4;use:1;wait:30;aim:off;waitprey:0,1500;walkto:65,56;waitseen:1,900;wait:10;aimprey;wait:4;use:1;wait:30;aim:off;" +
	"waitprey:0,300;walkto:63,59;aimat:63,60;wait:10;pick;wait:20;pick;wait:20;aim:off;select:3;aimat:63,58;wait:4;use:1;wait:60;aim:off;" +
	"mark:ate;walkto:66,56;walkto:66,50;aimat:67,50;wait:10;pick;wait:10;mark:open;sell:2;wait:20;buy:12;wait:20;buy:13;wait:30;tab;" +
	"mark:closed;aim:off;wait:30")

const SNARE_FOX_AT: String = "63,60"
const SNARE_HOST_FLAGS: Array[String] = ["--give=bow:1", "--test-collection=2"]
## The host: its arrow at the fox, then a deer for c1's arrow, then a deer that stays for c3.
const SNARE_HOST: String = ("select:1;walkto:60,51;walkto:61,56;waitat:65,56,900;waitat:62,54,900;wait:20;creature:lamp_fox," + SNARE_FOX_AT + ",30;wait:10;aimprey;wait:4;use:1;" +
	"wait:40;aim:off;mark:refused;waitprey:0,900;mark:caught;wait:30;creature:deer,63,60,100;wait:150;creature:deer,58,57,100;mark:stay;wait:360;" +
	"wait:60")
const SNARE_C1_GIVE: String = "--give=snare:3"
## c1: waits for the host's arrow, walks up and clicks; then one arrow at the deer (its bow from slot 8).
const SNARE_C1: String = ("select:8;walkto:66,52;walkto:65,56;select:1;waitseen:1,900;wait:45;snare:900;aim:off;select:8;waitseen:1,900;wait:10;aimprey;" +
	"wait:4;use:1;wait:40;aim:off;mark:shot;wait:300")
## c2: watches, then opens its collection panel (K) once the fox is gone: this machine's copy of the host's.
const SNARE_C2: String = ("walkto:62,45;walkto:58,47;walkto:58,54;walkto:62,54;waitseen:1,1200;waitprey:0,1200;wait:20;collection;wait:30;collection;" +
	"mark:panel;wait:300")
const SNARE_C3: String = "walkto:61,53;wait:120;mark:seen;wait:60"


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("hunt_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("hunt"):
		await _session_hunt()
	if only.is_empty() or only.has("snare"):
		await _session_snare()
	_check_logs()
	note("hunt sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## The hits on creatures of slot `slot` in the host's log.
func _hits_by(lines: PackedStringArray, slot: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in lines:
		if line.contains(" hunt hit slot=%d " % slot):
			out.append(line)
	return out


func _session_hunt() -> void:
	var dir: String = _session_dir("hunt")
	var port: int = _port()
	if not check(port > 0, "hunt: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=1", "--net-expect=1", "--class=paladin", "--test-allow-give",
		"--give=bow:1", "--test-start-hp=archer:40", "--bot=" + HUNT_HOST], 105)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "hunt: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", HUNT_C1_GIVE, "--bot=" + HUNT_C1], 105)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json")], 100.0), "hunt: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1]):
		return
	_expect_codes("hunt", {host: 0, c1: 0})
	_check_agreement("hunt", host, [c1], 2)
	var lines: PackedStringArray = _log_lines(host)
	var kills: PackedStringArray = []
	for line: String in lines:
		if line.contains(" hunt killed "):
			kills.append(line)
	if not check_eq(kills.size(), 3, "hunt: three deer dead (%s)" % str(kills)):
		return
	check(kills[0].contains("slot=1 kind=deer by=archer") and kills[0].contains("drops=hide_fine:2+meat:2"), "hunt: the first: the archer's blow, the whole hide (%s)" % kills[0])
	check(kills[1].contains("slot=0 kind=deer by=paladin") and kills[1].contains("drops=hide_worn:1+meat:1"), "hunt: the second: the paladin's blow, the damaged hide (%s)" % kills[1])
	check(kills[2].contains("slot=1 kind=deer by=archer") and kills[2].contains("at=63,60"), "hunt: the third: on its tile (%s)" % kills[2])
	# Both hit the first two.
	var by0: PackedStringArray = _hits_by(lines, 0)
	var by1: PackedStringArray = _hits_by(lines, 1)
	check(by0.size() >= 2 and by1.size() >= 2, "hunt: both hit (%d and %d)" % [by0.size(), by1.size()])
	check(_line_with(lines, "hunt hit slot=0 kind=deer id=1 ").length() > 0 and _line_with(lines, "hunt hit slot=1 kind=deer id=1 ").length() > 0, "hunt: the same deer, the first")
	check(_line_with(lines, "hunt hit slot=0 kind=deer id=2 ").length() > 0 and _line_with(lines, "hunt hit slot=1 kind=deer id=2 ").length() > 0, "hunt: the same deer, the second")
	var hh: Dictionary = host.result.get("hunt", {})
	check_eq(_num(hh, "kills"), 3.0, "hunt: three kills in the results")
	check_eq(str(hh.get("collection", "")), "2/8 kills=3 hunt_deer,first_hide_fine", "hunt: the entries")
	# What c1 did with it, by the existing paths.
	check_eq(_count_lines(lines, "host pickup slot=1 item=hide_fine count=2"), 1, "hunt: c1 picked up the whole hides")
	check_eq(_count_lines(lines, "host pickup slot=1 item=meat count=2"), 1, "hunt: and the meat")
	check(_line_with(lines, "host drink slot=1 map=0 item=meat grade=none hp=52").length() > 0, "hunt: c1 ate a meat: 40 + 12")
	check(_line_with(lines, "shop slot=1 sell item=hide_fine count=1 got=7").length() > 0, "hunt: sold a whole hide for 7")
	check(_line_with(lines, "shop slot=1 buy item=hide_worn").contains(" price=10 "), "hunt: bought the shop's 일반 가죽 for 10")
	check(_line_with(lines, "shop slot=1 buy item=meat").length() > 0, "hunt: and a meat")
	var players: Array = c1.result.get("players", [])
	var inventory: String = ""
	for p: Dictionary in players:
		if roundi(_num(p, "slot")) == roundi(_num(c1.result, "slot")):
			inventory = str(p.get("inventory", ""))
	check(inventory.contains("hide_fine x1") and inventory.contains("hide_worn x1") and inventory.contains("meat x2"), "hunt: c1 ends with %s" % inventory)
	var seen: Dictionary = c1.result.get("combat", {})
	var kinds: Array = seen.get("creature_kinds", [])
	check(kinds.has("deer"), "hunt: c1 drew the deer")
	check(_num(seen, "creature_batches") > 10.0 and _num(seen, "creature_keyframes") >= 1.0, "hunt: batches and a keyframe (%s, %s)" % [seen.get("creature_batches"), seen.get("creature_keyframes")])
	var hps: Dictionary = seen.get("creature_hp", {})
	var first: Array = hps.get("1", [])
	check_eq(str(first), "[20.0, 8.0, 0.0]", "hunt: c1 saw the first deer's HP go, its corpse too")


func _session_snare() -> void:
	var dir: String = _session_dir("snare")
	var port: int = _port()
	if not check(port > 0, "snare: free port"):
		return
	var host_flags: Array = ["--host=%d" % port, "--net-start=2", "--net-expect=3", "--class=paladin", "--test-allow-give", "--bot=" + SNARE_HOST]
	host_flags.append_array(SNARE_HOST_FLAGS)
	var host: Instance = _launch(dir, "host", host_flags, 105)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "snare: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", SNARE_C1_GIVE, "--net-lag=90", "--net-loss=5",
		"--bot=" + SNARE_C1], 105)
	check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "snare: c1 joined (over a slow, lossy line)")
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + SNARE_C2], 105)
	if not check(await _wait_files([dir.path_join("host.stay.marker")], 75.0), "snare: the fox was caught and the deer put down"):
		await _reap()
		return
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + SNARE_C3], 60)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c1.json"), dir.path_join("c2.json"), dir.path_join("c3.json")], 60.0),
		"snare: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2, c3]):
		return
	_expect_codes("snare", {host: 0, c1: 0, c2: 0, c3: 0})
	_check_agreement("snare", host, [c1, c2, c3], 4)
	var lines: PackedStringArray = _log_lines(host)
	check(_line_with(lines, "hunt refused slot=0 kind=lamp_fox by=paladin: archer only").length() > 0, "snare: the paladin's arrow did nothing to the rare creature")
	check_eq(_count_lines(lines, "hunt hit slot=0 kind=lamp_fox"), 0, "snare: no hit of his on it")
	check_eq(_count_lines(lines, "host capture slot=1 caught kind=lamp_fox"), 1, "snare: c1's snare took it, once")
	check(_line_with(lines, "action slot=1 item=snare action=throw").length() > 0 or _line_with(lines, "slot=1 item=snare").length() > 0, "snare: the throw played on the host")
	check_eq(_count_lines(lines, "host hunt killed"), 0, "snare: a capture is no kill (nor did c1's arrow kill)")
	check(_line_with(lines, "host collection entry=take_lamp_fox unit=creature count=3/8").length() > 0, "snare: the entry, third")
	check(_line_with(lines, "host collection benefit=class at=3").length() > 0, "snare: the class benefit lit at three")
	check(_line_with(lines, "host collection entry=first_rare_essence unit=resource count=4/8").length() > 0, "snare: the first material, fourth")
	check(_line_with(lines, "hunt hit slot=1 kind=deer id=2 amount=13 hp=17").length() > 0, "snare: c1's next arrow: 13 with the class benefit, on the host's number")
	var want: String = "4/8 kills=0 hunt_hare,hunt_deer,take_lamp_fox,first_rare_essence"
	for inst: Instance in [host, c1, c2, c3]:
		var hunt: Dictionary = inst.result.get("hunt", {})
		check_eq(hunt.get("collection", ""), want, "snare/%s: the same collection" % inst.name)
		check_eq(hunt.get("zone", ""), "114,63/%d" % Config.RARE_ZONE_RADIUS_TILES, "snare/%s: the rare zone from the snapshot" % inst.name)
	var players: Array = host.result.get("players", [])
	for p: Dictionary in players:
		if roundi(_num(p, "slot")) == 1:
			var inventory: String = str(p.get("inventory", ""))
			check(inventory.contains("snare x2") and inventory.contains("rare_essence x1"), "snare: one snare spent, one material (%s)" % inventory)
	for inst: Instance in [c1, c2]:
		var seen: Dictionary = inst.result.get("combat", {})
		var marks: Dictionary = seen.get("creature_marks", {})
		check(_num(marks, "refused") >= 1.0, "snare/%s: the refused mark came with the batches (%s)" % [inst.name, marks])
		check(_num(marks, "held") >= 1.0, "snare/%s: the snare's hold too" % inst.name)
		var bursts: Dictionary = seen.get("bursts_seen", {})
		check_eq(_num(bursts, "CAPTURE"), 1.0, "snare/%s: the catch's burst" % inst.name)
	var panel: String = _line_with(_log_lines(c2), "EVENSONG_COLLECTION open")
	check(panel.contains("3/8") or panel.contains("4/8"), "snare: K opened c2's panel on its copy (%s)" % panel)
	var late: Dictionary = c3.result.get("combat", {})
	var kinds: Array = late.get("creature_kinds", [])
	check(kinds.has("deer"), "snare: the late joiner drew the deer in its view (%s)" % str(kinds))
	var late_hunt: Dictionary = c3.result.get("hunt", {})
	check(_num(late_hunt, "msgs") >= 1.0, "snare: the late joiner's collection message")
