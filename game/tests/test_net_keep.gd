extends "res://tests/test_net_session.gd"
## M13b: saving in real sessions (separate processes over localhost ENet, like tests/test_net_session.gd, whose helpers and checks this file
## uses; tests/test_net_saves.gd runs the one-process checks, tests/test_net_quartet.gd four players). Seed 1, spawns off, creatures off.
## Every instance has its own save folder (--save-dir: each one is "a device"), all inside the run folder: nothing is written to the
## person's %APPDATA%\Evensong\saves.
##   keep  phase 1: the host (paladin) makes the world "keepw" and its character "hostc". c1 brings the saved archer "bob" (a file the test
##         writes: money, fine herbs, a worn bow, worn armour) and c2 makes the new cleric "cara". The host drops 5 stones beside c1, who picks
##         them up and leaves (bob is written from the host's inventory message, the host writes the world as it leaves); c3 tries to join
##         with the archer "dup" while bob is in and is refused as class_taken (the classes taken in its line, its file untouched); bob joins
##         again (c1b, the archer's class free again) with the 5 stones, picks the wild herb at 47,51; the host drops 3 stones nobody takes,
##         tills a tile (debug edit) and finishes (the world and hostc written once more).
##         phase 2: the host restarts with --world=keepw --character=hostc (no --class: hostc's) and opens the world as phase 1 left it (the
##         same content hash); bob (c1c) and cara (c2b) rejoin a loaded world with what they had; bob leaves, the host quits by its own
##         timeout while cara is in: cara loses the host and writes herself (host_lost), the host writes the world (ended).
## The runner flags of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=keep).

const KEEP_WORLD: String = "keepw"
## Where the host drops the stones c1 picks up (c1 stands east of it), and the 3 that stay (west).
const KEEP_DROP: Vector2i = Vector2i(63, 53)
const KEEP_STAY: Vector2i = Vector2i(60, 53)
const KEEP_HOST: String = ("wait:20;walkto:63,52;aimat:63,53;wait:30;drop:5;mark:dropped;wait:60;walkto:60,52;aimat:60,53;drop:3;" +
	"mark:stays;wait:10;" + EDIT + ";mark:edited;wait:120")
const KEEP_C1: String = "walkto:66,50;walkto:64,53;aimat:63,53;pick:420;wait:30;mark:picked;wait:10;leave"
const KEEP_C1B: String = "walkto:48,50;aimat:47,51;pick;wait:30;mark:herb;wait:30"
const KEEP_C2: String = "move:-1,0,30;wait:30;move:1,0,30;wait:60"


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
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("keep_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("keep"):
		await _session_keep()
	if only.is_empty() or only.has("close"):
		await _session_close()
	_check_logs()
	note("keep sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures


## A character written into `root` as its game would (CharacterSave's file).
static func write_character(root: String, c: CharacterSave.Sheet) -> String:
	var store: SaveStore = SaveStore.new(root)
	var path: String = store.character_path(c.name)
	var err: String = SaveStore.write_atomic(path, CharacterSave.encode(c), false)
	return err if not err.is_empty() else path


## The character `name` of the folder `root` as the game reads it (null: none reads).
static func read_character(root: String, name: String) -> CharacterSave.Sheet:
	var r: CharacterSave.Result = CharacterSave.load_from(SaveStore.new(root).character_path(name))
	return r.character if r.ok() else null


## A character of `class_id` named `name` holding its class weapon in the start slot (as a new one does), plus `extra` ([id, count, grade,
## durability] rows into the first slots) and worn armour with `armor_left` points (-1 = none).
static func make_character(name: String, class_id: String, extra: Array = [], armor_left: int = -1) -> CharacterSave.Sheet:
	var c: CharacterSave.Sheet = CharacterSave.Sheet.new()
	c.name = name
	c.class_id = class_id
	var weapon: StringName = Combat.class_weapon(class_id)
	c.stacks[Config.START_WEAPON_SLOT] = ItemStack.new(weapon, 1, ItemDB.Grade.NONE)
	var seen: Array[StringName] = [weapon]
	for i: int in extra.size():
		var row: Array = extra[i]
		var id: StringName = row[0]
		var n: int = row[1]
		var grade: int = row[2]
		var left: int = row[3]
		c.stacks[i] = ItemStack.new(id, n, grade, left)
		if not seen.has(id):
			seen.append(id)
	if armor_left >= 0:
		c.armor = ItemStack.new(&"armor_t1", 1, ItemDB.Grade.NONE, armor_left)
		seen.append(&"armor_t1")
	c.seen = seen
	return c


## How many of `id` character `c` holds in its slots.
static func count_in(c: CharacterSave.Sheet, id: StringName) -> int:
	var n: int = 0
	if c == null:
		return 0
	for st: ItemStack in c.stacks:
		if st != null and st.id == id:
			n += st.count
	return n


static func md5_of(path: String) -> String:
	return FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""


func _session_keep() -> void:
	var dir: String = _session_dir("keep")
	var port: int = _port()
	if not check(port > 0, "keep: free port"):
		return
	var dev_host: String = dir.path_join("dev_host")
	var dev_c1: String = dir.path_join("dev_c1")
	var dev_c2: String = dir.path_join("dev_c2")
	var dev_c3: String = dir.path_join("dev_c3")
	var bob: CharacterSave.Sheet = make_character("bob", "archer", [[&"money", 37, ItemDB.Grade.NONE, -1],
		[&"wild_healing", 3, ItemDB.Grade.FINE, -1]], 40)
	bob.stacks[Config.START_WEAPON_SLOT] = ItemStack.new(&"bow_t1", 1, ItemDB.Grade.NONE, 50)  # a worn tier-1 bow in place of the bow
	bob.seen.append(&"bow_t1")
	var bob_path: String = write_character(dev_c1, bob)
	var dup_path: String = write_character(dev_c3, make_character("dup", "archer", [[&"money", 9, ItemDB.Grade.NONE, -1]]))
	var dup_md5: String = md5_of(dup_path)
	if not check(FileAccess.file_exists(bob_path) and not dup_md5.is_empty(), "keep: the test wrote bob and dup (%s)" % bob_path):
		return
	var original_bob: String = md5_of(bob_path)
	var host_flags: Array = ["--host=%d" % port, "--net-start=2", "--net-expect=3", "--net-expect-refused=1", "--class=paladin",
		"--world=" + KEEP_WORLD, "--character=hostc", "--save-dir=" + dev_host, "--give=stone_a:20", "--bot=" + KEEP_HOST]
	if not _use_path:
		host_flags.append("--test-allow-give")  # the debug drop of an exported (release) host's own player stays its own; kept as pair does
	var host: Instance = _launch(dir, "host", host_flags, 110)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "keep: host listens"):
		await _reap()
		return
	var c1: Instance = _launch(dir, "c1", ["--join=127.0.0.1:%d" % port, "--character=bob", "--save-dir=" + dev_c1, "--bot=" + KEEP_C1], 100)
	var c2: Instance = _launch(dir, "c2", ["--join=127.0.0.1:%d" % port, "--character=cara", "--class=cleric", "--save-dir=" + dev_c2,
		"--bot=" + KEEP_C2], 100)
	if not check(await _wait_files([dir.path_join("c1.welcome.marker"), dir.path_join("c2.welcome.marker")], READY_WAIT_SEC),
			"keep: bob and cara joined"):
		await _reap()
		return
	var c3: Instance = _launch(dir, "c3", ["--join=127.0.0.1:%d" % port, "--character=dup", "--save-dir=" + dev_c3, "--bot=wait:10"], 40)
	if not check(await _wait_files([dir.path_join("c1.json"), dir.path_join("c3.json")], STEP_WAIT_SEC), "keep: bob left, dup was refused"):
		await _reap()
		return
	var c1b: Instance = _launch(dir, "c1b", ["--join=127.0.0.1:%d" % port, "--character=bob", "--save-dir=" + dev_c1, "--bot=" + KEEP_C1B],
		80)
	check(await _wait_files([dir.path_join("host.json"), dir.path_join("c2.json"), dir.path_join("c1b.json")], 70.0),
		"keep: phase 1: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host, c1, c2, c3, c1b]):
		return
	_expect_codes("keep", {host: 0, c1: 0, c2: 0, c3: NetSession.EXIT_REFUSED, c1b: 0})
	_check_agreement("keep", host, [c2, c1b], 3)
	var hl: PackedStringArray = _log_lines(host)
	check(_count_lines(hl, " class=archer ") >= 2 and _count_lines(hl, " character=bob ") == 2,
		"keep: the host took bob twice (%d)" % _count_lines(hl, " character=bob "))
	check(_line_with(hl, "class=cleric").contains("character=new"), "keep: cara came as a new character")
	check(_line_with(hl, "EVENSONG_SAVE world new name=keepw").length() > 0 and _line_with(hl, "world saved name=keepw why=new").length() > 0,
		"keep: the host made the world and wrote it at once")
	check(_line_with(hl, "world saved name=keepw why=left").length() > 0, "keep: the host wrote the world when bob left")
	check(_line_with(hl, "world saved name=keepw why=ended").length() > 0 and _line_with(hl, "character saved name=hostc why=ended").length() > 0,
		"keep: and at the end, with its own character")
	# c3: the class rule, its file untouched.
	check_eq(str(c3.result.get("refused", "")), "class_taken", "keep/c3: dup (an archer) refused while bob is in")
	check_eq(c3.result.get("refused_taken", []), ["paladin", "archer", "cleric"], "keep/c3: the classes taken")
	check(_log_has(c3, "pick a character of a free class: miner, herbalist"), "keep/c3: its console names the free classes")
	check(md5_of(dup_path) == dup_md5 and not FileAccess.file_exists(dup_path + ".bak"), "keep/c3: dup's file is untouched")
	check(_line_with(hl, "refused peer=").contains("class=archer taken=paladin,archer,cleric"), "keep: the host's log says why")
	# c1: bob as written when it left, the file before kept as the backup.
	var bob1: CharacterSave.Sheet = read_character(dev_c1, "bob")
	check(_log_has(c1, "EVENSONG_SAVE character saved name=bob why=left"), "keep/c1: bob written as it left")
	check_eq(str(c1.result.get("ended", "")), "left", "keep/c1: left")
	var bak: CharacterSave.Result = CharacterSave.read(SaveStore.read_bytes(bob_path + ".bak", Config.CHARACTER_FILE_MAX_BYTES))
	check(original_bob != md5_of(bob_path) and bak.ok() and count_in(bak.character, &"stone_a") == 5
		and count_in(bak.character, &"wild_buff") == 0, "keep: the write before the last is kept as the backup (bob as it left)")
	check(not _log_has(c1, "character saved name=bob why=new"), "keep/c1: a loaded character is not written as new")
	# c1b: bob again, with the stones (the archer's class free again: bob left).
	check(_line_with(_log_lines(c1b), "c1b welcome slot=").length() > 0, "keep/c1b: bob rejoined (the class freed by its leaving)")
	var c1b_inv: String = _own_inventory(c1b)
	check(c1b_inv.contains("stone_a x5") and c1b_inv.contains("money x37") and c1b_inv.contains("wild_healing x3 (fine)"),
		"keep/c1b: bob kept what it had (%s)" % c1b_inv)
	var bob2: CharacterSave.Sheet = read_character(dev_c1, "bob")
	check(bob1 != null and count_in(bob1, &"stone_a") == 5 and count_in(bob1, &"money") == 37 and bob1.armor != null
		and bob1.armor.durability == 40, "keep: bob's file after leaving: 5 stones, 37 money, armour 40")
	check(bob2 != null and count_in(bob2, &"stone_a") == 5 and count_in(bob2, &"wild_buff") == 1 and bob2.seen.has(&"stone_a"),
		"keep: bob's file after phase 1: the stones and the herb it picked (%s)" % (bob2.describe() if bob2 != null else "none"))
	var bow: ItemStack = bob2.stacks[Config.START_WEAPON_SLOT] if bob2 != null else null
	check(bow != null and bow.id == &"bow_t1" and bow.durability == 50, "keep: the worn bow kept its durability")
	# c2: cara, new: written once the host's first inventory came (its start kit), and at the end.
	var cara: CharacterSave.Sheet = read_character(dev_c2, "cara")
	check(_log_has(c2, "EVENSONG_SAVE character saved name=cara why=new") and cara != null and cara.class_id == "cleric"
		and cara.stacks[Config.START_WEAPON_SLOT] != null and cara.stacks[Config.START_WEAPON_SLOT].id == Combat.class_weapon("cleric"),
		"keep/c2: cara written as new with the cleric's start weapon")
	# The world file the host left.
	var wfile: WorldSave.Saved = WorldSave.load_from(SaveStore.new(dev_host).world_path(KEEP_WORLD))
	var phase1_hash: String = str(host.result.get("world_hash", ""))
	check(wfile.ok() and wfile.hashes[Config.MAP_SURFACE] == phase1_hash, "keep: the world file = the host's surface at the end (%s, %s)" % [
		wfile.error, phase1_hash.left(12)])
	if wfile.ok():
		var s: WorldData = wfile.maps[Config.MAP_SURFACE]
		check(s.drops.size() == 1 and s.terrain_at(Vector2i(62, 50)) == Terrain.SOIL, "keep: in it the 3 stones that stayed and the tilled tile")
		check(WorldItems.gatherable_cells(s).size() == WorldItems.gatherable_cells(SurfaceGen.generate(1)).size() - 1,
			"keep: and the herb bob picked is gone from it")
	await _keep_phase_two(dir, dev_host, dev_c1, dev_c2, phase1_hash)


## Phase 2: the host opens the world again (its character too); bob and cara rejoin; the host quits under cara.
func _keep_phase_two(dir: String, dev_host: String, dev_c1: String, dev_c2: String, phase1_hash: String) -> void:
	var port: int = _port()
	if not check(port > 0, "keep2: free port"):
		return
	var host2: Instance = _launch(dir, "host2", ["--host=%d" % port, "--net-start=2", "--world=" + KEEP_WORLD, "--character=hostc",
		"--save-dir=" + dev_host, "--bot=wait:30;mark:idle;wait:3000"], 24)
	if not check(await _wait_files([dir.path_join("host2.ready.marker")], READY_WAIT_SEC), "keep2: the host listens again"):
		await _reap()
		return
	var c1c: Instance = _launch(dir, "c1c", ["--join=127.0.0.1:%d" % port, "--character=bob", "--save-dir=" + dev_c1,
		"--bot=wait:40;mark:in;wait:20;leave"], 60)
	var c2b: Instance = _launch(dir, "c2b", ["--join=127.0.0.1:%d" % port, "--character=cara", "--save-dir=" + dev_c2, "--bot=wait:3000"], 60)
	check(await _wait_files([dir.path_join("host2.json"), dir.path_join("c1c.json"), dir.path_join("c2b.json")], 60.0),
		"keep2: every instance wrote its result")
	await _reap()
	if not _load_results(dir, [host2, c1c, c2b]):
		return
	_expect_codes("keep2", {host2: NetSession.EXIT_TIMEOUT, c1c: 0, c2b: NetSession.EXIT_FAILED})
	var h2: PackedStringArray = _log_lines(host2)
	var loaded: String = _line_with(h2, "EVENSONG_SAVE world loaded name=keepw")
	check(loaded.length() > 0 and _word_after(loaded, " hash=") == phase1_hash, "keep2: the host opened the world as phase 1 left it (%s)" %
		loaded)
	check(_line_with(h2, "EVENSONG_SAVE character loaded name=hostc").contains("class=paladin"), "keep2: and its own character (paladin)")
	check(_line_with(h2, "host2 hosting").contains("class=paladin"), "keep2: the host plays hostc's class without --class")
	var w1: String = _line_with(_log_lines(c1c), "c1c welcome slot=")
	check(_word_after(w1, " world=") == phase1_hash.left(12) and w1.contains(" drops=1 ") and w1.contains(" class=archer "),
		"keep2/c1c: bob joined the loaded world (the world as saved: the 3 stones lie there): %s" % w1)
	var inv: String = _own_inventory(c1c)
	check(inv.contains("stone_a x5") and inv.contains("wild_buff x1") and inv.contains("money x37"), "keep2/c1c: bob has what it had (%s)" % inv)
	check(_line_with(h2, "class=cleric").contains("character=cara"), "keep2: cara came back as herself")
	check(_log_has(c2b, "EVENSONG_SAVE character saved name=cara why=host_lost"), "keep2/c2b: cara wrote herself when the host went")
	check_eq(str(c2b.result.get("ended", "")), "lost the host", "keep2/c2b: lost the host")
	check(_line_with(h2, "world saved name=keepw why=ended").length() > 0, "keep2: the host wrote the world as it quit")
	check(_line_with(h2, "world saved name=keepw why=left").length() > 0, "keep2: and when bob left")
	var cara: CharacterSave.Sheet = read_character(dev_c2, "cara")
	check(cara != null and cara.class_id == "cleric", "keep2: cara's file reads after the host loss")


## close: what a person does (README "넷이 하기": close the window), with processes started like a person's (no --net-out, no bot: they
## quit by Godot's --quit-after, the window closing; the session never "finishes"), and the autosave in a session (--test-autosave-ticks).
## The host (world "closew", character "hc") and two clients: c1 ("cc", archer) closes its window while the host is up (its character
## written on quit); then the host closes its window (world and character written on quit); c2 ("cd", cleric), started like a person, loses
## the host, writes its character (host_lost), plays on alone and closes its window later (quit). Everyone autosaves meanwhile.
func _session_close() -> void:
	var dir: String = _session_dir("close")
	var port: int = _port()
	if not check(port > 0, "close: free port"):
		return
	var dev_host: String = dir.path_join("dev_host")
	var dev_c1: String = dir.path_join("dev_c1")
	var dev_c2: String = dir.path_join("dev_c2")
	var quiet: Array = ["--test-no-spawns", "--test-no-creatures", "--test-autosave-ticks=60"]
	# The host writes its marker files (--net-out: "ready"; it changes nothing of how it quits): an exported (release) child flushes its log
	# only at exit, so its log cannot say when it listens.
	var host: Instance = _launch_plain(dir, "host", ["--quit-after", "720"], ["--host=%d" % port, "--world=closew", "--character=hc",
		"--class=paladin", "--save-dir=" + dev_host, "--net-out=" + dir, "--net-name=host"] + quiet)
	if not check(await _wait_files([dir.path_join("host.ready.marker")], READY_WAIT_SEC), "close: host listens"):
		await _reap()
		return
	var c1: Instance = _launch_plain(dir, "c1", ["--quit-after", "300"], ["--join=127.0.0.1:%d" % port, "--character=cc", "--class=archer",
		"--save-dir=" + dev_c1] + quiet)
	var c2: Instance = _launch_plain(dir, "c2", ["--quit-after", "1260"], ["--join=127.0.0.1:%d" % port, "--character=cd", "--class=cleric",
		"--save-dir=" + dev_c2] + quiet)
	await _reap_after(60.0)
	_expect_codes("close", {host: 0, c1: 0, c2: 0})
	var hl: PackedStringArray = _log_lines(host)
	var l1: PackedStringArray = _log_lines(c1)
	var l2: PackedStringArray = _log_lines(c2)
	check(_line_with(hl, "world saved name=closew why=autosave").length() > 0 and _line_with(hl, "character saved name=hc why=autosave").length() > 0,
		"close: the host autosaves in a session (world and character)")
	check(_line_with(hl, "world saved name=closew why=left").length() > 0, "close: the host wrote the world when c1's window closed")
	check(_line_with(hl, "world saved name=closew why=quit").length() > 0 and _line_with(hl, "character saved name=hc why=quit").length() > 0,
		"close: the host's window closing writes the world and its character")
	check(_line_with(l1, "character saved name=cc why=new").length() > 0 and _line_with(l1, "character saved name=cc why=autosave").length() > 0
		and _line_with(l1, "character saved name=cc why=quit").length() > 0, "close/c1: new, autosave, and on closing its window")
	var lost: int = _first_line(l2, "character saved name=cd why=host_lost")
	var alone: int = _first_line(l2, "offline playing on alone")
	var quit: int = _first_line(l2, "character saved name=cd why=quit")
	check(lost >= 0 and alone > lost and quit > alone, "close/c2: host_lost, then it plays on alone, then quit (%d, %d, %d)" % [lost, alone, quit])
	check(not _log_has(c2, "world saved"), "close/c2: a client never writes a world")
	var w: WorldSave.Saved = WorldSave.load_from(SaveStore.new(dev_host).world_path("closew"))
	var cc: CharacterSave.Sheet = read_character(dev_c1, "cc")
	var cd: CharacterSave.Sheet = read_character(dev_c2, "cd")
	check(w.ok() and cc != null and cc.class_id == "archer" and cd != null and cd.class_id == "cleric", "close: every file reads (%s)" % w.error)


## Waits up to `seconds` for every child to exit by itself, then reaps (left-overs are killed and fail).
func _reap_after(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var alive: bool = false
		for inst: Instance in _all:
			if inst.code == -999 and OS.is_process_running(inst.pid):
				alive = true
		if not alive:
			break
		await tree.create_timer(0.1).timeout
	await _reap()


## The inventory line of an instance's own player in its result ("" when none).
static func _own_inventory(inst: Instance) -> String:
	var slot: int = roundi(_num(inst.result, "slot"))
	for p: Dictionary in inst.result.get("players", []):
		if roundi(_num(p, "slot")) == slot:
			return str(p.get("inventory", ""))
	return ""
