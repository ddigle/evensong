extends "res://tests/base_test.gd"
## M13a through main.tscn offline and real processes: the new flags' parsing (and their refusal in a session), a world and a character made,
## quit (written on _exit_tree) and opened again (the content hash saved = loaded; the altar's tier and its light, the boss defeated with its
## pillars as rubble, the collection, a chest, a built piece, the character's class, items, money, worn armour's durability and the relic it
## carries), a character carried from world A into world B (its inventory comes, A's chest does not), several characters (each its class;
## a conflicting --class and a character made without one refused), --no-save, the autosave and F9, the list flags, the play-on claim through
## two Mains (a loaded world == the world that never stopped, after the same "everyone left"), and the real game: made, quit by
## --quit-after, opened again, a broken file refused with code 3 (its backup loads), the class conflict code 2, the lists.

const TICK: float = 1.0 / 60.0
const SaveWorldTest := preload("res://tests/test_save_world.gd")
## Real processes: each one's deadline (s) and the frames it runs.
const PROCESS_DEADLINE_SEC: float = 60.0
const PROCESS_FRAMES: int = 90

var _dir: String = ""


func run() -> Array[String]:
	_dir = OS.get_temp_dir().path_join("evensong_test_save_main_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_dir)
	_check_cli()
	await _check_restart()
	await _check_carry()
	await _check_several()
	await _check_no_save()
	await _check_autosave_and_key()
	await _check_play_on()
	await _check_altar_restore()
	await _check_guard()
	await _check_processes()
	SaveWorldTest._remove_dir(_dir)
	return failures


# --- helpers -------------------------------------------------------------------------------------------------------

func _flags(args: Array) -> CliOptions:
	var all: PackedStringArray = ["--save-dir=" + _dir]
	for a: Variant in args:
		all.append(str(a))
	var o: CliOptions = CliOptions.parse(all)
	check(o.errors.is_empty(), "flags %s parse: %s" % [str(args), ", ".join(o.errors)])
	return o


## A Main (main.tscn) opened with `args` (save flags in this test's folder), in the tree, ready.
func _open(args: Array) -> Main:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	main.save_flags = _flags(args)
	add_node(main)
	main.set_physics_process(false)  # stepped here only (deterministic: no real-time frame steps it, from its first frame on)
	await await_frames(1)
	if main.player != null:
		main.player.local_input = false
	return main


## Quits `main` the way the game does (it leaves the tree: _exit_tree writes) and frees it.
func _quit(main: Main) -> void:
	main.get_parent().remove_child(main)
	main.free()


static func _step(main: Main, n: int) -> void:
	for i: int in n:
		main._physics_process(TICK)


func _world_file(name: String) -> String:
	return SaveStore.new(_dir).world_path(name)


func _character_file(name: String) -> String:
	return SaveStore.new(_dir).character_path(name)


# --- flags ---------------------------------------------------------------------------------------------------------

func _check_cli() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--world=Home", "--character=Bob_2", "--save-dir=/tmp/x", "--no-save",
		"--list-worlds", "--list-characters", "--test-autosave-ticks=30", "--seed=4"]))
	check(o.errors.is_empty(), "the M13a flags parse: %s" % ", ".join(o.errors))
	check_eq(o.world_name, "home", "--world (lowercased)")
	check_eq(o.character_name, "bob_2", "--character")
	check_eq(o.save_root(), "/tmp/x", "--save-dir")
	check(o.no_save and o.list_worlds and o.list_characters, "--no-save, --list-worlds, --list-characters")
	check_eq(o.test_autosave_ticks, 30, "--test-autosave-ticks")
	check(o.seed_given, "--seed given")
	var plain: CliOptions = CliOptions.parse(PackedStringArray([]))
	check(plain.world_name.is_empty() and plain.character_name.is_empty() and not plain.seed_given and not plain.no_save,
		"no flags: nothing open (today's unsaved start)")
	check_eq(plain.save_root(), Config.SAVE_DIR_DEFAULT, "the default folder")
	for bad: String in ["--world=", "--world=con", "--world=a/b", "--world=a.b", "--character=..", "--character=_x", "--save-dir=",
			"--test-autosave-ticks=0", "--world=" + "w".repeat(Config.SAVE_NAME_MAX + 1)]:
		check(not CliOptions.parse(PackedStringArray([bad])).errors.is_empty(), "%s is refused" % bad)
	for session: Array in [["--host", "--world=a"], ["--join=127.0.0.1", "--character=b"]]:
		var s: CliOptions = CliOptions.parse(PackedStringArray(session))
		check(not s.errors.is_empty() and s.errors[0].contains("M13b"), "%s: saving in a session is refused until M13b" % str(session))


# --- a world and a character over a restart ------------------------------------------------------------------------

func _check_restart() -> void:
	var args: Array = ["--world=keep", "--character=hero", "--class=paladin"]
	var a: Main = await _open(args)
	check(a.loaded == null and FileAccess.file_exists(_world_file("keep")) and FileAccess.file_exists(_character_file("hero")),
		"a new world and character are written at once")
	var p: Player = a.player
	# The world: tier 1, the boss killed (its relic carried), the collection, a chest's contents, a built wall.
	var f: BossFight = a.boss_fight()
	f.wake([] as Array[Player])
	f.hit(f.sim.hp, p.get_instance_id())
	check(a.world_progress().boss_defeated, "the boss is dead (the world's flag)")
	check(a.world_progress().raise_altar(), "the altar goes up a tier")
	a.world.altar_tier_changed()
	a.world_collection().put_test(4, 3)
	a.prayer.prayers = 3  # prayers made (the next one's directions)
	a.note_collection()
	var spot: Vector2i = a.world.data.altar_rect.position + Vector2i(-6, 6)
	a.world.apply_edit(Building.edit_for(&"stone_wall", spot))
	var chest_at: Vector2i = a.world.data.altar_rect.position + Vector2i(-6, 8)
	for x: int in Config.CHEST_FOOTPRINT.x:
		a.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, chest_at + Vector2i(x, 0), WorldData.PLACEABLE_CHEST))
	a.world.data.chest_at(chest_at).slots[2] = ItemStack.new(&"planks", 9, ItemDB.Grade.NONE)
	# A death: its bag lies in the world (half the stones), the death counter (the next bag's draw) goes up.
	p.inventory.add(&"stone_a", 6)
	p.sim_position = a.world.spawn_point(0) + Vector2(0, 90)
	a._on_died(p)
	p.sim_position = a.world.spawn_point(0)
	var bags: int = a.world.data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_BAG)
	check(bags == 1 and a.deaths == 1 and p.inventory.count_of(&"stone_a") == 3, "a death bag lies in the world")
	# The character: money, a worn armour, the relic.
	p.inventory.add(ItemDB.MONEY, 37)
	p.inventory.add(Config.BOSS_RELIC, 1)
	p.inventory.wear(ItemStack.new(&"armor_t1", 1, ItemDB.Grade.NONE, 55))
	_step(a, 30)
	var merchant: Vector2i = Merchant.tile_of(a.world.data)
	var shop_clock: int = a.world_shop().clock
	var drops: int = a.world.data.drops.size()
	var saved_hash: String = a.world.data.content_hash()
	var dungeon_hash: String = a.worlds[Config.MAP_DUNGEON].data.content_hash()
	var inv_before: String = p.inventory.describe()
	_quit(a)
	var on_disk: WorldSave.Saved = WorldSave.load_from(_world_file("keep"))
	check(on_disk.ok() and on_disk.hashes[Config.MAP_SURFACE] == saved_hash, "quitting wrote the world as it was")
	check_eq(on_disk.ticks, 30, "with its 30 ticks of play")
	var b: Main = await _open(["--world=keep", "--character=hero"])
	if not check(b.loaded != null and b.player != null, "the world and the character open again"):
		_quit(b)
		return
	check_eq(b.loaded.hashes[Config.MAP_SURFACE], saved_hash, "the saved hash")
	check_eq(b.world.data.content_hash(), saved_hash, "the loaded surface's content hash is the saved one")
	check_eq(b.worlds[Config.MAP_DUNGEON].data.content_hash(), dungeon_hash, "the dungeon's too")
	check_eq(b.world_progress().altar_tier, 1, "the altar's tier survived the restart")
	check_eq(b.world.safe_zone.radius, Config.safe_radius_px_at(1), "its light is tier 1's")
	check(b.world_progress() == b.worlds[Config.MAP_DUNGEON].data.progress, "one progress on both maps again")
	var fb: BossFight = b.boss_fight()
	check(b.world_progress().boss_defeated and fb != null and fb.sim.state == BossSim.State.DEAD, "the boss stays dead")
	check(fb != null and fb.pillars.all(func(q: BossFight.Pillar) -> bool: return q.fallen), "its pillars lie as rubble")
	check_eq(b.world_collection().count(), 4, "the collection's entries")
	check_eq(b.world_collection().kills, 3, "and its kills")
	check(b.world_collection() == b.worlds[Config.MAP_DUNGEON].data.collection, "one collection on both maps again")
	check_eq(b.world.data.get_value(WorldData.Layer.WALL, spot), Building.edit_for(&"stone_wall", spot).value, "the built wall")
	var chest: WorldData.Chest = b.world.data.chest_at(chest_at)
	check(chest != null and chest.slots[2] != null and chest.slots[2].id == &"planks" and chest.slots[2].count == 9, "the chest's planks")
	var q: Player = b.player
	check_eq(q.class_id(), "paladin", "the character's class")
	check_eq(q.inventory.describe(), inv_before, "every slot as it was")
	check_eq(q.inventory.count_of(ItemDB.MONEY), 37, "its money")
	check_eq(q.inventory.count_of(Config.BOSS_RELIC), 1, "the relic it carries")
	check(q.inventory.armor != null and q.inventory.armor.id == &"armor_t1" and q.inventory.armor.durability == 55,
		"the worn armour and its durability")
	check(q.inventory.has_seen(Config.BOSS_RELIC), "what it has held (recipes stay unlocked)")
	check_eq(q.inventory.count_of(Combat.class_weapon("paladin")), 1, "no second start weapon on loading")
	check(q.vitals.hp == Config.PLAYER_HP_MAX and q.vitals.alive(), "it comes in up and full")
	check(q.sim_position.distance_to(b.world.spawn_point(0)) < 1.0, "at the altar")
	check_eq(b.world.data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_BAG), 1, "the death bag still lies there")
	check_eq(b.world.data.drops.size(), drops, "with every drop")
	check_eq(b.deaths, 1, "the deaths counted (the next bag's draw goes on)")
	check_eq(Merchant.tile_of(b.world.data), merchant, "the merchant stands where he stood")
	check_eq(b.world_shop().clock, shop_clock, "the shop's restock clock goes on")
	check_eq(b.prayer.prayers, 3, "the prayers made (the next prayer's directions go on)")
	for m: int in [Config.MAP_SURFACE, Config.MAP_DUNGEON]:
		var shown: Dictionary[String, int] = b.worlds[m].view_check()
		check(shown["mismatches"] == 0 and shown["missing"] == 0 and shown["cells"] > 0, "map %d: the loaded world is drawn as its data (%s)" % [m, str(shown)])
	_quit(b)


## A character carried from world A into world B: its inventory comes along, A's chest does not.
func _check_carry() -> void:
	var a: Main = await _open(["--world=alpha", "--character=wanderer", "--class=archer"])
	var chest_at: Vector2i = a.world.data.altar_rect.position + Vector2i(-6, 8)
	for x: int in Config.CHEST_FOOTPRINT.x:
		a.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, chest_at + Vector2i(x, 0), WorldData.PLACEABLE_CHEST))
	a.world.data.chest_at(chest_at).slots[0] = ItemStack.new(&"stone_a", 12, ItemDB.Grade.NONE)
	a.player.inventory.add(&"log", 5)
	_quit(a)
	var b: Main = await _open(["--world=beta", "--seed=2", "--character=wanderer"])
	check(b.loaded == null and b.world.data.world_seed == 2, "world B is a new world of its own seed")
	check_eq(b.player.class_id(), "archer", "the character's class came along")
	check_eq(b.player.inventory.count_of(&"log"), 5, "its inventory came along")
	check_eq(b.player.inventory.count_of(&"stone_a"), 0, "world A's chest did not")
	check(b.world.data.held_chests().is_empty(), "world B's chests hold nothing")
	_quit(b)
	var alpha: WorldSave.Saved = WorldSave.load_from(_world_file("alpha"))
	var held: WorldData.Chest = alpha.maps[Config.MAP_SURFACE].chest_at(chest_at) if alpha.ok() else null
	check(held != null and held.slots[0] != null and held.slots[0].count == 12, "world A's chest still holds its stones")
	var c: CharacterSave.Result = CharacterSave.load_from(_character_file("wanderer"))
	check(c.ok() and c.character.class_id == "archer", "the character file is one (its class)")


## Several characters on one device, each its class for good; a --class against the file, or none for a new one, is refused.
func _check_several() -> void:
	_quit(await _open(["--character=digger", "--class=miner"]))
	_quit(await _open(["--character=healer", "--class=cleric"]))
	var cli: GDScript = load("res://core/cli.gd") as GDScript
	var lines: PackedStringArray = cli.call("list_saves", _flags(["--list-characters", "--list-worlds"]))
	var text: String = "\n".join(lines)
	check(text.contains("character name=digger class=miner") and text.contains("character name=healer class=cleric"),
		"--list-characters lists both with their classes")
	check(text.contains("characters=%d" % SaveStore.new(_dir).character_names().size()), "and counts every character")
	check(text.contains("world name=keep seed=") and text.contains("tier=1 boss=defeated"), "--list-worlds says what each world holds")
	var d: Main = await _open(["--character=digger"])
	check_eq(d.player.class_id(), "miner", "digger plays its miner")
	_quit(d)
	var h: Main = await _open(["--character=healer"])
	check_eq(h.player.class_id(), "cleric", "healer plays its cleric")
	_quit(h)
	var before: PackedByteArray = FileAccess.get_file_as_bytes(_character_file("digger"))
	var refused: Main = await _open(["--character=digger", "--class=paladin"])
	check(refused.player == null and not refused.save_now("key"), "--class against the file: refused, nothing set up or written")
	_quit(refused)
	check_eq(FileAccess.get_file_as_bytes(_character_file("digger")), before, "the character file is untouched")
	var unnamed: Main = await _open(["--character=nobody"])
	check(unnamed.player == null, "a new character without --class: refused")
	_quit(unnamed)
	check(not SaveStore.exists(_character_file("nobody")), "and no file made")
	var seeded: Main = await _open(["--world=keep", "--seed=99"])
	check(seeded.player == null, "a --seed against an existing world: refused")
	_quit(seeded)


func _check_no_save() -> void:
	var m: Main = await _open(["--world=ghost", "--character=shade", "--class=herbalist", "--no-save"])
	check(m.player != null and m.player.class_id() == "herbalist", "--no-save: the world and the character open")
	_step(m, 5)
	check(not m.save_now("key"), "and the key writes nothing")
	_quit(m)
	check(not SaveStore.exists(_world_file("ghost")) and not SaveStore.exists(_character_file("shade")), "nor does quitting")


func _check_autosave_and_key() -> void:
	var m: Main = await _open(["--world=tick", "--character=clock", "--class=miner", "--test-autosave-ticks=20"])
	check_eq(WorldSave.load_from(_world_file("tick")).ticks, 0, "a new world is written at tick 0")
	_step(m, 25)
	var auto: WorldSave.Saved = WorldSave.load_from(_world_file("tick"))
	check(auto.ok() and auto.ticks == 20, "the autosave wrote at 20 ticks (%d)" % auto.ticks)
	check(FileAccess.file_exists(_world_file("tick") + ".bak"), "keeping the save before it as the backup")
	m.player.inventory.add(&"stone_a", 3)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"save_now"
	press.pressed = true
	m._unhandled_input(press)
	check_eq(WorldSave.load_from(_world_file("tick")).ticks, 25, "F9 wrote the world at once")
	var c: CharacterSave.Result = CharacterSave.load_from(_character_file("clock"))
	check(c.ok() and c.character.stacks.any(func(st: ItemStack) -> bool: return st != null and st.id == &"stone_a" and st.count == 3),
		"and the character")
	_quit(m)


## The claim through two Mains in step: a world saved after everyone left and loaded plays on exactly as the world that never stopped,
## with the same player standing at the altar in both.
func _check_play_on() -> void:
	var a: Main = await _open(["--world=same", "--seed=5"])
	var s: WorldData = a.world.data
	var at: Vector2i = s.altar_rect.position
	var fields: Array[Array] = [[at + Vector2i(-2, 4), Farming.KIND_HEALING, 1, true, false], [at + Vector2i(-1, 4), Farming.KIND_BUFF, 0,
		true, true]]
	Main.put_test_fields(a.world, a.farms[Config.MAP_SURFACE], fields)
	var trees: Array[Vector2i] = Forest.tree_cells(s)
	a.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, trees[0], WorldData.PLACEABLE_STUMP))
	a.forests[Config.MAP_SURFACE].regrow[trees[0]] = 300
	a.forests[Config.MAP_SURFACE].hits[trees[1]] = 2
	a.world_collection().put_test(2, 1)
	_step(a, 120)
	for id: int in a.arenas:
		a.arenas[id].occupied = true
		a.arenas[id].idle_tick()  # everyone left: the same rule a load applies
	var bytes: PackedByteArray = a.capture_world()
	check_eq(SaveStore.write_atomic(_world_file("same2"), bytes), "", "the world written as another")
	var b: Main = await _open(["--world=same2"])
	check(b.loaded != null and b.player.sim_position == a.player.sim_position, "loaded, its player where the other's stands")
	check_eq(SaveWorldTest.differing(b.capture_world(), bytes), PackedStringArray(), "the loaded Main saves the same world")
	for i: int in 600:
		a._physics_process(TICK)
		b._physics_process(TICK)
	var after: PackedByteArray = a.capture_world()
	check_eq(SaveWorldTest.differing(b.capture_world(), after), PackedStringArray(),
		"600 ticks on, the loaded world is the world that never stopped (every section)")
	check_eq(b.world.data.content_hash(), a.world.data.content_hash(), "the same surface hash")
	check_ne(SaveWorldTest.differing(after, bytes, false), PackedStringArray(), "and the world did change meanwhile")
	check(a.forests[Config.MAP_SURFACE].stat("regrown") >= 1 and b.forests[Config.MAP_SURFACE].stat("regrown") >= 1,
		"the stump grew back in both")
	note("play-on through two Mains: %d heretics, %d creatures on the surface after 600 ticks" % [a.arenas[Config.MAP_SURFACE].heretics.size(),
		a.arenas[Config.MAP_SURFACE].herd.list.size()])
	_quit(b)
	_quit(a)


# --- the real game -------------------------------------------------------------------------------------------------

## Runs the game headless with `flags` (after "--"; `frames`: --quit-after, 0 = none) and waits for it. Returns [exit code (-1 killed),
## log text].
func _game(flags: Array, frames: int = PROCESS_FRAMES) -> Array:
	var log_path: String = _dir.path_join("game_%d.log" % Time.get_ticks_usec())
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", log_path]
	if frames > 0:
		args.append_array(["--quit-after", str(frames)])
	args.append("--")
	for f: Variant in flags:
		args.append(str(f))
	var pid: int = OS.create_process(OS.get_executable_path(), args, false)
	if not check(pid > 0, "the game started"):
		return [-1, ""]
	var deadline: int = Time.get_ticks_msec() + int(PROCESS_DEADLINE_SEC * 1000.0)
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.05).timeout
	var code: int = -1
	if OS.is_process_running(pid):
		OS.kill(pid)
		fail("the game did not quit within %.0f s: %s" % [PROCESS_DEADLINE_SEC, str(flags)])
	else:
		code = OS.get_process_exit_code(pid)
	var text: String = FileAccess.get_file_as_string(log_path)
	check(not text.contains("ERROR:"), "no engine error in the game's log (%s)" % str(flags))
	return [code, text]


func _check_processes() -> void:
	var dir: String = _dir.path_join("real")
	var store: SaveStore = SaveStore.new(dir)
	var base: Array = ["--save-dir=" + dir, "--test-no-spawns"]
	var first: Array = await _game(base + ["--world=real", "--character=runner", "--class=cleric", "--give=money:12"])
	var log1: String = first[1]
	check_eq(first[0], 0, "made and quit: exit 0")
	check(log1.contains("EVENSONG_SAVE world new name=real") and log1.contains("EVENSONG_SAVE character new name=runner class=cleric"),
		"the log says it made them")
	check(log1.contains("EVENSONG_SAVE world saved name=real why=quit") and log1.contains("EVENSONG_SAVE character saved name=runner why=quit"),
		"--quit-after wrote both on the way out")
	check(FileAccess.file_exists(store.world_path("real")) and FileAccess.file_exists(store.character_path("runner")), "both files are there")
	var second: Array = await _game(base + ["--world=real", "--character=runner"])
	var log2: String = second[1]
	check_eq(second[0], 0, "opened again: exit 0")
	check(log2.contains("EVENSONG_SAVE world loaded name=real file=real.evw seed=1"), "the world loaded from its file")
	check(log2.contains("EVENSONG_SAVE character loaded name=runner file=runner.json class=cleric") and log2.contains("money=12"),
		"the character loaded with its class and money")
	var good: PackedByteArray = FileAccess.get_file_as_bytes(store.world_path("real"))
	var junk: PackedByteArray = good.slice(0, good.size() / 3)
	SaveWorldTest._write(store.world_path("real"), junk)
	var third: Array = await _game(base + ["--world=real"])
	var log3: String = third[1]
	check_eq(third[0], 0, "a broken file: exit 0")
	check(log3.contains("file=real.evw.bak") and log3.contains("skipped real.evw:"), "its backup loaded, the reason logged")
	check(WorldSave.load_from(store.world_path("real")).path == store.world_path("real"), "and the quit wrote a good file again")
	SaveWorldTest._write(store.world_path("real"), junk)
	SaveWorldTest._write(store.world_path("real") + ".bak", junk)
	var fourth: Array = await _game(base + ["--world=real"])
	var log4: String = fourth[1]
	check_eq(fourth[0], Config.EXIT_SAVE_REFUSED, "nothing loads: exit %d" % Config.EXIT_SAVE_REFUSED)
	check(log4.contains("EVENSONG_SAVE error: world real does not load"), "the refusal is logged")
	check_eq(FileAccess.get_file_as_bytes(store.world_path("real")), junk, "and the broken files are left as they are")
	var fifth: Array = await _game(base + ["--character=runner", "--class=miner"])
	check_eq(fifth[0], 2, "a --class against the character: exit 2")
	check(str(fifth[1]).contains("character runner is a cleric"), "with the reason")
	var broken_character: PackedByteArray = "{\"format\": \"evensong-character\", \"version\": 1, \"class\": \"cleric\", \"slots\": [{\"item\": \"money\", \"count\": 251}]}".to_ascii_buffer()
	SaveWorldTest._write(store.character_path("runner"), broken_character)
	SaveWorldTest._write(store.character_path("runner") + ".bak", broken_character)
	var sixth: Array = await _game(base + ["--character=runner"])
	check_eq(sixth[0], Config.EXIT_SAVE_REFUSED, "a character file that does not load: exit %d" % Config.EXIT_SAVE_REFUSED)
	check(str(sixth[1]).contains("character runner does not load") and str(sixth[1]).contains("count must be 1..250"), "with the reason")
	check_eq(FileAccess.get_file_as_bytes(store.character_path("runner")), broken_character, "and the file left as it is")
	var listed: Array = await _game(["--save-dir=" + dir, "--list-worlds", "--list-characters"], 0)
	var log6: String = listed[1]
	check_eq(listed[0], 0, "the lists: exit 0")
	check(log6.contains("EVENSONG_SAVE world name=real does not load") and log6.contains("EVENSONG_SAVE character name=runner does not load"),
		"they list every save and what it is")


## A file whose surface has no altar (it was carried and no place was known to put it back) opens with the altar put back before the
## player comes: the player stands at it, not at the map's corner.
func _check_altar_restore() -> void:
	var a: Main = await _open(["--world=noaltar"])
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(a.world.data):
		a.world.apply_edit(e)
	a.world.last_altar_rect = Rect2i()  # nowhere known: the file cannot put it back
	var bytes: PackedByteArray = a.capture_world()
	var s: WorldSave.Saved = WorldSave.read(bytes)
	check(s.ok() and not s.maps[Config.MAP_SURFACE].altar_rect.has_area(), "a file whose altar no place could take: %s" % s.error)
	check_eq(SaveStore.write_atomic(_world_file("noaltar2"), bytes), "", "written")
	_quit(a)
	var b: Main = await _open(["--world=noaltar2"])
	check(b.world.data.altar_rect.has_area(), "opened: the altar is back")
	check(b.player.sim_position.distance_to(b.world.data.altar_center_px()) < 64.0, "and the player stands at it")
	check(b.world.safe_zone != null and b.world.is_in_safe_zone(b.world.data.altar_center_px()), "with its light")
	_quit(b)


## Never a file its own reader refuses: a sim in a state the world file cannot hold (a heretic at NaN) or a stack no character file may
## have (money past its stack) is not written, the files there are kept (not rotated into the backup), the error logged.
func _check_guard() -> void:
	var a: Main = await _open(["--world=guard", "--character=guardian", "--class=paladin"])
	var world_before: PackedByteArray = FileAccess.get_file_as_bytes(_world_file("guard"))
	var surface: Arena = a.arenas[Config.MAP_SURFACE]
	var h: HereticSim = surface.spawn_heretic(Arena.spawn_feet(surface.spawn_cells[0]))
	h.pos = Vector2(NAN, 0.0)
	check(not a.save_now("key"), "a world its reader would refuse is not written")
	check_eq(FileAccess.get_file_as_bytes(_world_file("guard")), world_before, "the world file there is kept")
	check(not FileAccess.file_exists(_world_file("guard") + ".bak"), "and not rotated into the backup")
	surface.heretics.erase(h)
	var character_before: PackedByteArray = FileAccess.get_file_as_bytes(_character_file("guardian"))
	a.player.inventory.slots[5] = ItemStack.new(ItemDB.MONEY, Config.STACK_MONEY + 1, ItemDB.Grade.NONE)
	check(not a.save_now("key"), "a character its reader would refuse is not written")
	check_eq(FileAccess.get_file_as_bytes(_character_file("guardian")), character_before, "the character file there is kept")
	check(WorldSave.load_from(_world_file("guard")).ticks == 0 and FileAccess.file_exists(_world_file("guard") + ".bak"),
		"the world (now whole) was written beside it, the good file kept as the backup")
	a.player.inventory.slots[5] = null
	_quit(a)
	check(CharacterSave.load_from(_character_file("guardian")).ok(), "once it is whole again the quit writes it")
