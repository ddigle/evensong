extends "res://tests/test_net_session.gd"
## M9c: the class skills in a real session (separate processes over localhost ENet, like tests/test_net_session.gd, whose helpers
## and checks this file uses; tests/test_net_skills.gd runs the one-process checks). Seed 1, spawns off.
##   rites   host (paladin, conviction 60) + c1 (archer, 40 HP) + c2 (cleric, faith 60) + c3 (herbalist: a FINE healing potion,
##           three healing herbs, two FINE poisons) + a late c4 (miner) = five players, one per class, against two heretics placed
##           south of the light. c1 steps out of the light and the heretics go for him; the host walks out beside him and
##           taunts: they turn to the host (c1 steps back in). The host fights with his crushing blow (a stun) and his oath (a
##           ward on him and the players near); c2 heals c1 with its cursor on him (key 1: the heal lands on c1, not on the
##           others standing near), bursts holy light on a heretic (key 2) and blesses (key R); c3 throws the healing potion with
##           its cursor beside c1 (● R42: it lands on c1, the ally nearest the cursor) and spreads its healing mist (key R);
##           c4 joins during the mist: its welcome has the cloud; c1 shoots its piercing arrow, its fan and (after standing
##           still for focus) its arrow rain. Every machine agrees with the host: the heretics' HP, the players' HP, each
##           client's own cooldowns and meter (its skills message), the skill events and marks drawn.
##   chant   traffic: host (paladin) + c1 (archer) + c2 (cleric) + c3 (miner), every meter full, pressing their skill keys over
##           and over (1, 2, R and again) at two heretics for 8 seconds: the bytes against the README's numbers.
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=rites,chant).

const RITES_HERETICS: String = "--test-heretic=61,58/65,58"
const RITES_HOST_FLAGS: Array[String] = ["--test-start-resource=paladin:60,cleric:60", "--test-start-hp=archer:40"]
## The clients join one after another, so their spawn slots are known (Config.SPAWN_SLOTS around the altar (63, 47)): the host
## slot 0 (60, 48), c1 slot 1 (66, 48), c2 slot 2 (63, 45: north of the altar, it walks round its west side), c3 slot 3
## (61, 50), c4 slot 4. A key a heretic's hit could cut off (the host's in the fight) is pressed three times 8 ticks apart: a
## press refused on its own machine (mid-action, cooling down) sends nothing.
## The host: inside the light until c1 is out, then out beside him, the taunt, then the fight (the crushing blow, the oath).
const RITES_HOST: String = ("select:8;walkto:60,52;walkto:63,52;waitat:63,55,900;walkto:62,55;aimfoe;wait:2;skill:1;wait:50;" +
	"mark:taunted;closein:20,240;aimfoe;skill:2;wait:8;skill:2;wait:8;skill:2;wait:8;skill:2;wait:60;skill:r;wait:8;skill:r;" +
	"wait:8;skill:r;wait:8;skill:r;wait:60;mark:oath;fight:1500,0,18;waitfoe:0,1500;walkto:62,53;wait:240")
## c1 (archer, 40 HP): out of the light to draw them, back in once the host is out; healed there; then its skills.
const RITES_C1: String = ("select:8;walkto:66,52;walkto:63,55;waitat:62,55,900;walkto:63,53;mark:back;wait:300;aimfoe;wait:2;" +
	"skill:1;wait:60;aimfoe;skill:2;wait:60;aim:off;wait:240;aimfoe;skill:r;wait:60;fight:900,0;waitfoe:0,1500;aim:off;wait:240")
## c2 (cleric, faith 60): beside c1 in the light; the heal on c1 (its cursor on him), the holy burst, the blessing.
const RITES_C2: String = ("select:8;walkto:59,45;walkto:59,52;walkto:62,53;waitat:63,53,900;wait:40;aimat:63,53;wait:4;skill:1;" +
	"wait:60;mark:healed;aimfoe;wait:2;skill:2;wait:60;skill:r;wait:60;aimfoe;fight:900,0;waitfoe:0,1500;aim:off;wait:240")
const RITES_C3_GIVE: String = "--give=potion_healing:1:fine,wild_healing:3,potion_poison:2:fine"
## c3 (herbalist): beside c1; the healing potion with its cursor one tile north of c1 (the ally nearest it), the mist, poison.
const RITES_C3: String = ("walkto:61,52;walkto:64,53;waitat:63,53,900;wait:160;select:1;aimat:63,52;wait:4;throw;wait:60;" +
	"mark:thrown;aimat:63,52;wait:4;skill:r;wait:10;mark:mist;wait:60;select:3;aimfoe;wait:4;throw;wait:60;select:8;aim:off;" +
	"waitfoe:0,1500;wait:240")
const RITES_C4: String = "wait:30;mark:seen;wait:60"
## chant: everyone presses its keys again and again (the scripts' "skill" lines); every meter full (the herbalist is not in it).
const CHANT_HERETICS: String = "--test-heretic=61,57/65,57"
const CHANT_HOST: String = ("select:8;walkto:60,52;walkto:63,55;aimfoe;wait:30;mark:start;skill:1;wait:45;skill:2;wait:45;skill:r;wait:45;" +
	"skill:1;wait:45;skill:2;wait:45;skill:1;wait:45;skill:2;wait:45;skill:1;wait:45;skill:2;wait:45;skill:1;wait:45;mark:stop;" +
	"fight:900,0,18;waitfoe:0,1200;walkto:63,52;wait:240")
const CHANT_C1: String = ("select:8;walkto:66,52;walkto:62,53;aimfoe;wait:30;skill:1;wait:45;skill:2;wait:45;skill:r;wait:45;skill:1;wait:45;" +
	"skill:2;wait:45;skill:1;wait:45;skill:2;wait:45;skill:1;wait:45;skill:2;wait:45;skill:1;wait:45;fight:900,0;waitfoe:0,1200;" +
	"aim:off;wait:240")
const CHANT_C2: String = ("select:8;walkto:59,45;walkto:59,52;walkto:64,53;aimfoe;wait:30;skill:2;wait:45;skill:r;wait:45;skill:2;wait:45;skill:2;wait:45;" +
	"skill:2;wait:45;skill:2;wait:45;skill:2;wait:45;skill:2;wait:45;fight:900,0;waitfoe:0,1200;aim:off;wait:240")
const CHANT_C3: String = ("select:8;walkto:61,52;walkto:64,55;aimfoe;wait:30;skill:1;wait:45;skill:2;wait:45;skill:r;wait:45;skill:1;wait:45;" +
	"skill:2;wait:45;skill:1;wait:45;skill:2;wait:45;skill:1;wait:45;skill:2;wait:45;fight:900,0,18;waitfoe:0,1200;aim:off;" +
	"walkto:64,52;wait:240")
const CHANT_RESOURCES: String = "--test-start-resource=paladin:100,archer:100,cleric:100,miner:100"
## IMPL (tests): the most bytes a second the host may send each client while four players press their keys (README "측정" M9c).
const CHANT_MAX_BPS: float = 6000.0


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("rites_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("rites"):
		await _session_rites()
	if only.is_empty() or only.has("chant"):
		await _session_chant()
	_check_logs()
	note("rites sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## The host's skill lines of slot `slot` and skill `id` ("<host> skill slot=<s> map=0 skill=<id> ...").
func _skill_lines(lines: PackedStringArray, slot: int, id: StringName) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in lines:
		if line.contains(" skill slot=%d map=0 skill=%s " % [slot, id]):
			out.append(line)
	return out


## The integer after `key=` in `line` (-1 when it has none).
static func _field(line: String, key: String) -> int:
	var at: int = line.find(" " + key + "=")
	if at < 0:
		return -1
	return line.substr(at + key.length() + 2).get_slice(" ", 0).get_slice(",", 0).to_int()


func _session_rites() -> void:
	var dir: String = _session_dir("rites")
	var port: int = _port()
	if not check(port > 0, "rites: free port"):
		return
	var host_flags: Array = ["--host=%d" % port, "--net-start=3", "--net-expect=4", "--class=paladin", "--test-allow-give",
		"--bot=" + RITES_HOST, RITES_HERETICS]
	host_flags.append_array(RITES_HOST_FLAGS)
	var host: Instance = _launch(dir, "host", host_flags, 110)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "rites: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--class=archer", "--bot=" + RITES_C1], 110)
	check(await _wait_files([dir.path_join("c1.welcome.marker")], READY_WAIT_SEC), "rites: c1 joined (slot 1)")
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--class=cleric", "--bot=" + RITES_C2], 110)
	check(await _wait_files([dir.path_join("c2.welcome.marker")], READY_WAIT_SEC), "rites: c2 joined (slot 2)")
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--class=herbalist", RITES_C3_GIVE, "--bot=" + RITES_C3],
		110)
	if not check(await _wait_files([dir.path_join("c3.mist.marker")], 70.0), "rites: the herbalist's mist is out"):
		await _reap()
		return
	var c4: Instance = _launch(dir, "c4", ["--join=127.0.0.1:%d" % port, "--class=miner", "--bot=" + RITES_C4], 80)
	var everyone: Array[Instance] = [host, c1, c2, c3, c4]
	var files: Array[String] = []
	for inst: Instance in everyone:
		files.append(dir.path_join(inst.name + ".json"))
	check(await _wait_files(files, 90.0), "rites: every instance wrote its result")
	await _reap()
	if not _load_results(dir, everyone):
		return
	_expect_codes("rites", {host: 0, c1: 0, c2: 0, c3: 0, c4: 0})
	_check_agreement("rites", host, [c1, c2, c3, c4], 5)
	var hs: int = roundi(_num(host.result, "slot"))
	var s1: int = roundi(_num(c1.result, "slot"))
	var s2: int = roundi(_num(c2.result, "slot"))
	var s3: int = roundi(_num(c3.result, "slot"))
	var lines: PackedStringArray = _log_lines(host)
	# The taunt pulled the heretics off c1.
	var taunt: PackedStringArray = _skill_lines(lines, hs, Skills.TAUNT)
	check(taunt.size() == 1 and _field(taunt[0], "taunted") >= 1, "rites: the host's taunt caught a heretic (%s)" % ";".join(taunt))
	var taunt_at: int = _first_line(lines, " skill slot=%d map=0 skill=taunt " % hs)
	var on_c1_before: int = 0
	var on_host_after: int = 0
	for i: int in lines.size():
		if lines[i].contains(" heretic_attack map=0 ") and lines[i].contains(" slot=%d " % s1) and i < taunt_at:
			on_c1_before += 1
		if lines[i].contains(" heretic_attack map=0 ") and lines[i].contains(" slot=%d " % hs) and i > taunt_at:
			on_host_after += 1
	check(on_host_after >= 1, "rites: after the taunt the heretics attack the host (%d; %d on c1 before it)" % [on_host_after,
		on_c1_before])
	# The heal went to c1 (the ally the cleric's cursor was on).
	var heals: PackedStringArray = _skill_lines(lines, s2, Skills.HEAL)
	check(heals.size() >= 1 and _field(heals[0], "to") == s1 and _field(heals[0], "healed") == Skills.num_i(Skills.HEAL, "heal_hp"),
		"rites: the cleric's heal landed on c1 (%s)" % ";".join(heals))
	# The herbalist's healing potion went to c1 (● R42: the ally nearest its cursor), and landed on him.
	var throw_line: String = _line_with(lines, "host throw slot=%d map=0 item=potion_healing" % s3)
	var splash: String = _line_with(lines, "item=potion_healing at=")
	var p1: Dictionary = _player(host, s1)
	var c1_body: Vector2 = Combat.body_point(Vector2(_num(p1, "x"), _num(p1, "y")))
	var at_text: String = splash.get_slice(" at=", 1).get_slice(" ", 0)
	var splash_at: Vector2 = Vector2(at_text.get_slice(",", 0).to_float(), at_text.get_slice(",", 1).to_float())
	check(not throw_line.is_empty() and splash.contains("players=") and _field(splash, "players") >= 1
		and splash_at.distance_to(c1_body) <= 2.0, "rites: the healing bottle went to c1 and broke on him (%s; %s; c1 body %s)" % [
		throw_line, splash, c1_body])
	check_eq(_count_lines(lines, "host request_refused slot=%d throw" % s3), 0, "rites: no throw of the herbalist refused")
	# Skills landed by every class; the mist, the oath, the crushing blow.
	var hk0: Dictionary = host.result.get("skills", {})
	var landed: Dictionary = hk0.get("landed", {})
	for id: StringName in [Skills.TAUNT, Skills.CRUSHING_BLOW, Skills.GUARDIAN_OATH, Skills.HEAL, Skills.HOLY_BURST, Skills.BLESSING,
			Skills.HEALING_MIST, Skills.PIERCING_ARROW, Skills.FAN_SHOT, Skills.ARROW_RAIN]:
		check(_num(landed, String(id)) >= 1.0, "rites: %s landed on the host (%s)" % [id, landed])
	check(_killed_by_any(lines, 1) and _killed_by_any(lines, 2), "rites: both heretics died")
	# Every machine: the same HP for every player as the host, its own cooldowns and meter as the host has them, the skill events.
	var host_skills: Dictionary = hk0.get("members", {})
	for c: Instance in [c1, c2, c3, c4]:
		for slot: int in [hs, s1, s2, s3]:
			check_eq(_num(_player(c, slot), "hp"), _num(_player(host, slot), "hp"), "rites/%s: player %d's HP = the host's" % [c.name, slot])
		var mine: Dictionary = c.result.get("skills", {})
		var hm: Dictionary = host_skills.get(str(roundi(_num(c.result, "slot"))), {})
		check(_num(mine, "msgs") >= 1.0 and _num(mine, "bad") == 0.0, "rites/%s: got its skills messages (%s)" % [c.name, mine])
		# The results are written at different host ticks (the host's first, the clients' after "finish"): the client's copy stands
		# for host tick copy_tick, the host's state for its result tick. A cooldown counts down one a tick on both.
		var dt: int = roundi(_num(mine, "copy_tick")) - roundi(_num(host.result, "ticks"))
		var mcd: Array = mine.get("cd", [])
		var hcd: Array = hm.get("cd", [])
		var cd_ok: bool = mcd.size() == SkillState.SLOT_COUNT and hcd.size() == SkillState.SLOT_COUNT
		for i: int in mini(mcd.size(), hcd.size()):
			var hv: float = hcd[i]
			var mv: float = mcd[i]
			var h_cd: int = roundi(hv)
			cd_ok = cd_ok and roundi(mv) == (maxi(h_cd - dt, 0) if h_cd > 0 else 0)
		var slack: float = 0.0
		if c == c1:
			slack = 1.0 + ceilf(absf(dt) / Config.ARCHER_FOCUS_GAIN_TICKS)  # focus grows standing
		check(cd_ok and absf(_num(mine, "meter") - _num(hm, "meter")) <= slack,
			"rites/%s: its HUD's meter %s and cooldowns %s = the host's %s / %s (%d ticks apart)" % [c.name, mine.get("meter"), mcd,
			hm.get("meter"), hcd, dt])
	for c5: Instance in [c1, c2, c3]:
		var cc: Dictionary = c5.result.get("combat", {})
		var ev: Dictionary = cc.get("skill_events", {})
		check(_num(ev, "burst") >= 3.0 and _num(ev, "ward") >= 1.0, "rites/%s: drew the skills' bursts and the ward (%s)" % [c5.name, ev])
		var marks: Dictionary = cc.get("marks_seen", {})
		var stunned: Array = marks.get("stunned", [])
		var taunted: Array = marks.get("taunted", [])
		check(not stunned.is_empty() and not taunted.is_empty(), "rites/%s: saw a heretic stunned and taunted (%s)" % [c5.name, marks])
	# The late joiner: the mist was in its welcome (the cloud drawn from the snapshot's events).
	var c4c: Dictionary = c4.result.get("combat", {})
	var c4ev: Dictionary = c4c.get("skill_events", {})
	check(_num(c4ev, "zone") >= 1.0, "rites/c4 (late): its welcome had the healing mist (%s)" % c4ev)
	check(_log_has(c4, "c4 welcome slot="), "rites/c4: joined late")
	_fight_traffic_notes("rites", host, c1)
	var hk: Dictionary = host.result.get("skills", {})
	note("rites skills: landed %s, fizzled %s, skills messages %s (%s B)" % [hk.get("landed"), hk.get("fizzled"), hk.get("msgs"),
		hk.get("bytes")])


func _session_chant() -> void:
	var dir: String = _session_dir("chant")
	var port: int = _port()
	if not check(port > 0, "chant: free port"):
		return
	var host: Instance = _launch(dir, "host", ["--host=%d" % port, "--net-start=3", "--net-expect=3", "--class=paladin",
		"--bot=" + CHANT_HOST, CHANT_HERETICS, CHANT_RESOURCES], 90)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "chant: host listens"):
		await _reap()
		return
	var cs: Array[Instance] = []
	for row: Array in [["c1", "archer", CHANT_C1], ["c2", "cleric", CHANT_C2], ["c3", "miner", CHANT_C3]]:
		var name: String = row[0]
		cs.append(_launch(dir, name, ["--join=127.0.0.1:%d" % port, "--class=" + str(row[1]), "--bot=" + str(row[2])], 90))
		check(await _wait_files([dir.path_join(name + ".welcome.marker")], READY_WAIT_SEC), "chant: %s joined" % name)
	var files: Array[String] = [dir.path_join("host.json")]
	for c: Instance in cs:
		files.append(dir.path_join(c.name + ".json"))
	check(await _wait_files(files, 85.0), "chant: every instance wrote its result")
	await _reap()
	var everyone: Array[Instance] = [host]
	everyone.append_array(cs)
	if not _load_results(dir, everyone):
		return
	_expect_codes("chant", {host: 0, cs[0]: 0, cs[1]: 0, cs[2]: 0})
	_check_agreement("chant", host, cs, 4)
	var lines: PackedStringArray = _log_lines(host)
	var hk: Dictionary = host.result.get("skills", {})
	var landed: Dictionary = hk.get("landed", {})
	var total: float = 0.0
	for id: Variant in landed:
		total += _num(landed, str(id))
	check(total >= 10.0, "chant: the four landed %d skills (%s)" % [roundi(total), landed])
	check(_killed_by_any(lines, 1) and _killed_by_any(lines, 2), "chant: both heretics died")
	var stats: Dictionary = host.result.get("stats", {})
	var fight: Dictionary = {}
	for key: String in stats:
		if key.begins_with("fight"):
			var b: Dictionary = stats[key]
			if _num(b, "sec") > _num(fight, "sec", 0.0):
				fight = b
	var per_client: float = _num(fight, "sent_bps") / float(cs.size())
	check(not fight.is_empty() and per_client <= CHANT_MAX_BPS,
		"chant: the host sends %.0f B/s a client while four press their keys (at most %.0f, README)" % [per_client, CHANT_MAX_BPS])
	_fight_traffic_notes("chant", host, cs[0])
	var got: Array[float] = []
	for c: Instance in cs:
		var ck: Dictionary = c.result.get("skills", {})
		got.append(_num(ck, "msgs"))
	note("chant skills: landed %s, skills messages %s (%s B), each client got %s" % [landed, hk.get("msgs"), hk.get("bytes"), got])
