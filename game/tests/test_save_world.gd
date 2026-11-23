extends "res://tests/base_test.gd"
## M13a without Main: the saves' folder (core/save_store.gd: names, the safe write and its backup, the files a load tries after a crash),
## the world file (core/world_save.gd): a rich world (both maps' tiles, built pieces, fields mid-growth, a chest, drops and the next drop id,
## a tree's axe hits and a stump's regrowth, purified ground, the collection, the altar's tier, the shop's stock and clock, the rare zone,
## the herd with a death waiting, heretics, the shrine's HP, a sleeping boss with cracked pillars, the random streams, the prayers and
## deaths) saved, read and set up again gives the same file and content hashes; played on, it stays the world that never stopped (the
## determinism claim: after the same "everyone left", README "M13a"); the "everyone left" rule at load (an attack stops, targets, threat and
## player ids gone, a snare's hold let go); a carried altar is written put back; corrupt, cut, wrong-version, random and hostile files
## (a good checksum around bad content) are refused whole without an engine error.

const SEED: int = 3
const PLAY_TICKS: int = 240
const PLAY_ON_TICKS: int = 420
const MAPS: Array[int] = [Config.MAP_SURFACE, Config.MAP_DUNGEON]
## M13 review: the rich world's healing crop reaches its next stage this many ticks into the play-on.
const GROW_INTO_PLAY_ON: int = 60
## M13 review: the committed fixture files (a world and a character this build wrote; _check_fixture). A run with the runner flag
## --write-save-fixtures writes them again (only when the format changes: FORMAT_VERSION goes up with a migration for the old ones).
const FIXTURE_WORLD: String = "res://tests/fixtures/saves/m13_world.evw"
const FIXTURE_CHARACTER: String = "res://tests/fixtures/saves/m13_character.json"
const Runner := preload("res://tests/run_all.gd")

var _dir: String = ""


## The sims of one world without Main, set up and stepped in Main's offline order (no players: the arenas step for nobody, as a map
## nobody is on would if it were stepped; the herd, the farms, the forests and the shop run on the game clock).
class Rig:
	extends RefCounted
	var maps: Dictionary[int, WorldData] = {}
	var arenas: Dictionary[int, Arena] = {}
	var farms: Dictionary[int, Farm] = {}
	var forests: Dictionary[int, Forest] = {}
	var last_altar: Dictionary[int, Rect2i] = {}
	var prayers: int = 0
	var deaths: int = 0
	var ticks: int = 0

	## Sims on `p_maps` as Main sets them up (ensure_combat, setup_farming, setup_forests, setup_shop): the collection and the progress
	## one object on both maps (the surface's).
	static func on_maps(p_maps: Dictionary[int, WorldData], seed: int) -> Rig:
		var r: Rig = Rig.new()
		r.maps = p_maps
		var s: WorldData = p_maps[Config.MAP_SURFACE]
		if s.collection == null:
			s.collection = Collection.new()
		if s.progress == null:
			s.progress = WorldProgress.new()
		if s.shop == null:
			s.shop = Shop.new()
		for m: int in MAPS:
			var d: WorldData = p_maps[m]
			d.collection = s.collection
			d.progress = s.progress
			var a: Arena = Arena.new()
			a.setup(d, seed)
			a.threat_on = true
			if m == Config.MAP_DUNGEON:
				a.boss = BossFight.new()
				a.boss.setup(a, d.world_seed)
			else:
				a.herd = Creatures.new()
				a.herd.setup(d, seed, true)
			r.arenas[m] = a
			r.farms[m] = Farm.new(d)
			r.forests[m] = Forest.new(d)
			r.last_altar[m] = d.altar_rect
		return r

	static func fresh(seed: int) -> Rig:
		var p_maps: Dictionary[int, WorldData] = {Config.MAP_SURFACE: SurfaceGen.generate(seed, Config.MAP_SIZE),
			Config.MAP_DUNGEON: DungeonGen.generate(seed)}
		return on_maps(p_maps, seed)

	## The rig a file gives (Main.open_world's way: the loaded maps, the sims set up on them, then the saved state).
	static func loaded(s: WorldSave.Saved, apply: bool = true) -> Rig:
		var r: Rig = on_maps(s.maps, s.world_seed)
		if not apply:
			return r
		for m: int in s.arenas:
			WorldSave.apply_arena(r.arenas[m], s.arenas[m])
		WorldSave.apply_herd(r.arenas[Config.MAP_SURFACE].herd, s.herd)
		WorldSave.apply_boss(r.arenas[Config.MAP_DUNGEON].boss, s.boss)
		for m: int in s.farms:
			WorldSave.apply_farm(r.farms[m], s.farms[m])
		for m: int in s.forests:
			WorldSave.apply_forest(r.forests[m], s.forests[m])
		var sh: Shop = r.maps[Config.MAP_SURFACE].shop
		sh.clock = s.shop_clock
		sh.restocks = s.shop_restocks
		r.prayers = s.prayers
		r.deaths = s.deaths
		r.ticks = s.ticks
		return r

	func live() -> WorldSave.Live:
		var l: WorldSave.Live = WorldSave.Live.new()
		l.name = "rig"
		l.maps = maps
		l.last_altar = last_altar
		l.arenas = arenas
		l.farms = farms
		l.forests = forests
		l.prayers = prayers
		l.deaths = deaths
		l.ticks = ticks
		return l

	func capture() -> PackedByteArray:
		return WorldSave.capture(live())

	static func put(d: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
		for e: EditLog.WorldEdit in edits:
			EditLog.apply_to_data(d, e)

	func step(n: int) -> void:
		var none: Array[Player] = []
		var s: WorldData = maps[Config.MAP_SURFACE]
		for i: int in n:
			for m: int in MAPS:
				put(maps[m], arenas[m].step(none))
			put(s, arenas[Config.MAP_SURFACE].herd.step(none))
			for m: int in MAPS:
				put(maps[m], farms[m].step())
				put(maps[m], forests[m].step())
			s.shop.step(s.collection)
			ticks += 1

	## Everyone left (the map emptied, Arena.on_emptied) and no player of this process is named anywhere (what a load does to the world).
	func quiesce() -> void:
		for m: int in MAPS:
			arenas[m].occupied = true
			arenas[m].idle_tick()
			for h: HereticSim in arenas[m].heretics:
				h.poison_by = 0
				h.threat.clear()
		for c: CreatureSim in arenas[Config.MAP_SURFACE].herd.list:
			c.hold_ticks = 0
			c.held_by = 0
			c.held_from = Vector2.ZERO
			c.poison_by = 0


func run() -> Array[String]:
	_dir = OS.get_temp_dir().path_join("evensong_test_save_world_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(_dir)
	_check_names()
	_check_reader()
	_check_store()
	var a: Rig = _rich()
	a.step(PLAY_TICKS)
	_stage_players(a)
	_check_emptied(a)
	a.quiesce()
	var bytes: PackedByteArray = a.capture()
	_check_round_trip(a, bytes)
	_check_play_on(a, bytes)
	_check_refusals(bytes)
	_check_fallbacks(bytes)
	_check_carried_altar()
	_check_fight_reset()
	_check_pillar_cap()
	_check_dead_pillars()
	_check_mined_spawns()
	_check_fitting(bytes)
	_check_character_file()
	_check_fixture(bytes)
	_check_golden()
	_remove_dir(_dir)
	return failures


# --- helpers -------------------------------------------------------------------------------------------------------

## The sections of a world file (tag -> payload), in file order in `order`; empty when it is not one.
static func sections_of(bytes: PackedByteArray, order: PackedStringArray = []) -> Dictionary[String, PackedByteArray]:
	var out: Dictionary[String, PackedByteArray] = {}
	var r: WorldSave.Reader = WorldSave.Reader.new(bytes.slice(0, bytes.size() - WorldSave.FOOTER_BYTES), 8)
	var n: int = r.u32()
	for i: int in n:
		var tag: String = r.take(4).get_string_from_ascii()
		var size: int = r.u32()
		out[tag] = r.take(size)
		order.append(tag)
	return out


## A world file of `sections` in `order` with a good header and checksum (a hostile file: only its content is wrong).
static func rebuild(sections: Dictionary[String, PackedByteArray], order: PackedStringArray, version: int = WorldSave.FORMAT_VERSION) \
		-> PackedByteArray:
	var w: WorldSave.Writer = WorldSave.Writer.new()
	w.put(WorldSave.MAGIC)
	w.u16(version)
	w.u16(0)
	w.u32(order.size())
	for tag: String in order:
		w.put(tag.to_ascii_buffer())
		var payload: PackedByteArray = sections.get(tag, PackedByteArray())
		w.u32(payload.size())
		w.put(payload)
	w.put(WorldSnapshot.md5(w.bytes))
	return w.bytes


## Every section of two files that differs (META compared without its save time, its name and its ticks: `with_ticks` keeps them).
static func differing(x: PackedByteArray, y: PackedByteArray, with_ticks: bool = true) -> PackedStringArray:
	var sx: Dictionary[String, PackedByteArray] = sections_of(x)
	var sy: Dictionary[String, PackedByteArray] = sections_of(y)
	var out: PackedStringArray = []
	for tag: String in WorldSave.TAGS:
		var px: PackedByteArray = sx.get(tag, PackedByteArray())
		var py: PackedByteArray = sy.get(tag, PackedByteArray())
		if tag == "META":
			# i64 seed, i64 saved (unix s: not compared), i64 ticks, u32 deaths, u32 prayers, u16 protocol, then the name (not compared).
			var same: bool = px.size() >= 34 and py.size() >= 34 and px.slice(0, 8) == py.slice(0, 8) and px.slice(24, 34) == py.slice(24, 34)
			if with_ticks:
				same = same and px.slice(16, 24) == py.slice(16, 24)
			if not same:
				out.append("META")
		elif px != py:
			out.append(tag)
	return out


static func _remove_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_dir(dir.path_join(sub))
	for file: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


static func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


static func _read(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## A walkable grass tile of the surface near `from` with nothing on it (for the test's pieces).
static func _free_tile(d: WorldData, from: Vector2i, taken: Array[Vector2i]) -> Vector2i:
	for r: int in range(3, 30):
		for y: int in range(from.y - r, from.y + r + 1):
			for x: int in range(from.x - r, from.x + r + 1):
				var c: Vector2i = Vector2i(x, y)
				if d.in_bounds(c) and not taken.has(c) and d.terrain_at(c) == Terrain.GRASS and d.get_value(WorldData.Layer.PLACEABLE, c) == 0 \
						and d.get_value(WorldData.Layer.VEGETATION, c) == 0 and d.get_value(WorldData.Layer.WALL, c) == 0 \
						and d.can_set_terrain(c, Terrain.SOIL) and not d.altar_rect.grow(1).has_point(c):
					taken.append(c)
					return c
	return Vector2i(-1, -1)


## A rig with something of every saved kind in it.
func _rich() -> Rig:
	var r: Rig = Rig.fresh(SEED)
	var s: WorldData = r.maps[Config.MAP_SURFACE]
	var dg: WorldData = r.maps[Config.MAP_DUNGEON]
	var taken: Array[Vector2i] = []
	var near: Vector2i = s.altar_rect.get_center()
	# Built pieces (a wall, a closed door, a floor piece under a lantern).
	Rig.put(s, [Building.edit_for(&"stone_wall", _free_tile(s, near, taken)), Building.edit_for(&"door", _free_tile(s, near, taken))])
	var floor_tile: Vector2i = _free_tile(s, near, taken)
	Rig.put(s, [Building.edit_for(&"stone_floor", floor_tile), Building.edit_for(&"lantern", floor_tile)])
	# Fields mid-growth: wet crops (they grow), a dry one, a bare wet tile.
	for entry: Array in [[Farming.KIND_HEALING, 1, true, false], [Farming.KIND_BUFF, 2, true, true], [Farming.KIND_POISON, 0, false, true],
			[Farming.KIND_NONE, 0, true, false]]:
		var c: Vector2i = _free_tile(s, near, taken)
		var kind: int = entry[0]
		var stage: int = entry[1]
		var is_wet: bool = entry[2]
		var fast: bool = entry[3]
		Rig.put(s, [EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c, Terrain.SOIL),
			EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, Farming.Field.new(kind, stage, is_wet, fast).value())])
		r.farms[Config.MAP_SURFACE].sync_cell(c)
		if kind == Farming.KIND_HEALING:
			# M13 review: this crop reaches its next stage GROW_INTO_PLAY_ON ticks into the play-on (after the save): the check sees a crop grow.
			var farm: Farm = r.farms[Config.MAP_SURFACE]
			var plot: Farm.Plot = farm.plots[s.index_of(c)]
			plot.progress = Farming.stage_ticks(fast, farm.stage_ticks_base) - PLAY_TICKS - GROW_INTO_PLAY_ON
			plot.water_left = maxi(plot.water_left, PLAY_TICKS + PLAY_ON_TICKS + 100)
	# A chest with three stacks (one worn).
	var chest_at: Vector2i = _free_tile(s, near + Vector2i(4, 4), taken)
	s.put_placeable(Rect2i(chest_at, Config.CHEST_FOOTPRINT), WorldData.PLACEABLE_CHEST)
	var chest: WorldData.Chest = s.chest_at(chest_at)
	chest.slots[0] = ItemStack.new(&"stone_a", 7, ItemDB.Grade.NONE)
	chest.slots[3] = ItemStack.new(&"wild_healing", 2, ItemDB.Grade.FINE)
	chest.slots[5] = ItemStack.new(&"sword_t1", 1, ItemDB.Grade.NONE, 17)
	# Drops: three put down, the last one taken (the next id goes on past it).
	for i: int in 3:
		var px: Vector2i = _free_tile(s, near + Vector2i(-6, 6), taken) * Config.TILE + Vector2i(8, 8)
		Rig.put(s, [EditLog.WorldEdit.drop_put(WorldData.Drop.new(s.new_drop_id(), &"log", 2 + i, ItemDB.Grade.NONE, px))])
	var last_drop: int = s.drop_ids().back()
	Rig.put(s, [EditLog.WorldEdit.drop_remove(last_drop)])
	# A tree with axe hits, a felled one regrowing.
	var trees: Array[Vector2i] = Forest.tree_cells(s)
	r.forests[Config.MAP_SURFACE].hits[trees[0]] = 3
	Rig.put(s, [EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, trees[1], WorldData.PLACEABLE_STUMP)])
	r.forests[Config.MAP_SURFACE].regrow[trees[1]] = PLAY_TICKS + 100  # grows back during the play-on
	Rig.put(s, [EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, trees[2], WorldData.PLACEABLE_STUMP)])
	r.forests[Config.MAP_SURFACE].regrow[trees[2]] = 50_000
	# Purified ground (two ash tiles back to grass).
	var purified: int = 0
	for i: int in s.layers[WorldData.Layer.CORRUPTION].size():
		if purified < 2 and s.layers[WorldData.Layer.CORRUPTION][i] != 0:
			var c: Vector2i = Vector2i(i % s.size.x, i / s.size.x)
			Rig.put(s, [EditLog.WorldEdit.new(WorldData.Layer.CORRUPTION, c, 0)])
			purified += 1
	# The world's collection, the altar's tier, the shop's stock.
	s.collection.put_test(3, 5)
	s.collection.take_fresh()
	check(s.progress.raise_altar(), "the rig's altar goes up a tier")
	check(s.shop.set_left(0, 1), "the rig's shop sold some")
	# The herd: one killed (its drops and its place waiting).
	var herd: Creatures = r.arenas[Config.MAP_SURFACE].herd
	check(herd.list.size() >= 4, "the herd filled up (%d)" % herd.list.size())
	herd.hit(herd.list[0], 9999, 0)
	Rig.put(s, herd.take_edits())
	# Heretics on the surface (one poisoned) and in the dungeon.
	var surface_arena: Arena = r.arenas[Config.MAP_SURFACE]
	for i: int in 3:
		surface_arena.spawn_heretic(Arena.spawn_feet(surface_arena.spawn_cells[i * 17 % surface_arena.spawn_cells.size()]))
	var poisoned: HereticSim = surface_arena.heretics[1]
	poisoned.poison_damage = 1
	poisoned.poison_ticks = PLAY_TICKS + PLAY_ON_TICKS + 100
	poisoned.poison_timer = 3
	poisoned.hp = Config.HERETIC_HP
	var dungeon_arena: Arena = r.arenas[Config.MAP_DUNGEON]
	dungeon_arena.spawn_heretic(Arena.spawn_feet(dungeon_arena.spawn_cells[0]))
	dungeon_arena.shrine_hp = maxi(Config.SHRINE_HP - 2, 1)
	surface_arena.rng.randi()  # every stream somewhere along
	dungeon_arena.rng.randi()
	# The dungeon: a torch, a drop; the boss asleep with cracked pillars, its stream along.
	var boss: BossFight = dungeon_arena.boss
	check(boss != null and boss.sim != null and boss.pillars.size() >= 2, "the rig's dungeon has the boss and its pillars")
	boss.set_pillar_hits(0, 4)
	boss.set_pillar_hits(1, 1)
	boss.rng.randi()
	# A rock wall cracked by mining (its hits in the WALL byte).
	var walls: PackedByteArray = dg.layers[WorldData.Layer.WALL]
	for i: int in walls.size():
		if walls[i] == Walls.pack(Walls.KIND_ROCK, 0):
			Rig.put(dg, [EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(i % dg.size.x, i / dg.size.x), Walls.pack(Walls.KIND_ROCK, 2))])
			break
	var arrival: Vector2i = Aim.feet_cell(DungeonGen.arrival_point(dg))
	Rig.put(dg, [EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, arrival + Vector2i(1, 0), WorldData.PLACEABLE_TORCH),
		EditLog.WorldEdit.drop_put(WorldData.Drop.new(dg.new_drop_id(), &"ore_copper", 2, ItemDB.Grade.NONE,
		(arrival + Vector2i(-1, 0)) * Config.TILE + Vector2i(8, 8)))])
	r.prayers = 4
	r.deaths = 2
	return r


## What players of this process leave in the sims while they play (node ids that die with it): a heretic attacking one (its target,
## threat, a taunt, a stun), a poison's thrower, a creature held by one's snare and another poisoned by one.
func _stage_players(r: Rig) -> void:
	var surface_arena: Arena = r.arenas[Config.MAP_SURFACE]
	var attacker: HereticSim = surface_arena.heretics[0]
	attacker.state = HereticSim.State.ATTACK
	attacker.state_ticks = 4
	attacker.target_id = 777
	attacker.has_target = true
	attacker.threat[777] = 40
	attacker.taunt_by = 778
	attacker.taunt_ticks = 90
	attacker.stun_ticks = 12
	surface_arena.heretics[1].poison_by = 779
	var herd: Creatures = surface_arena.herd
	herd.hold(herd.list[1], 600, herd.list[1].pos + Vector2(10, 0), 4242)
	herd.list[2].poison_damage = 1
	herd.list[2].poison_ticks = 30
	herd.list[2].poison_timer = 5
	herd.list[2].poison_by = 4343


# --- names, the reader, the store ----------------------------------------------------------------------------------

func _check_names() -> void:
	check_eq(SaveStore.normalize_name("World_1"), "world_1", "a name is lowercased")
	check_eq(SaveStore.normalize_name("a-b_9"), "a-b_9", "a-z 0-9 _ - are a name")
	for bad: String in ["", "con", "COM1", "nul", "lpt9", "a/b", "a\\b", "a.b", "..", "_x", "-x", "x".repeat(Config.SAVE_NAME_MAX + 1),
			"w orld", "ü"]:
		check_ne(SaveStore.name_refusal(bad), "", "'%s' is no save name" % bad)
		check_eq(SaveStore.normalize_name(bad), "", "and normalizes to nothing")
	check_eq(SaveStore.name_refusal("x".repeat(Config.SAVE_NAME_MAX)), "", "%d characters are a name" % Config.SAVE_NAME_MAX)
	var store: SaveStore = SaveStore.new(_dir)
	check_eq(store.world_path("Main"), _dir.path_join("worlds/main.evw"), "a world's file")
	check_eq(store.character_path("Bob"), _dir.path_join("characters/bob.json"), "a character's file")


func _check_reader() -> void:
	var r: WorldSave.Reader = WorldSave.Reader.new(PackedByteArray([1, 2, 3]))
	check_eq(r.u16(), 0x0201, "the reader reads little-endian")
	check(r.ok, "and is fine")
	check_eq(r.u32(), 0, "a read past the end gives 0")
	check(not r.ok, "and turns ok off (no engine error)")
	check_eq(r.u8(), 0, "and every read after it gives 0")
	var nan: PackedByteArray = PackedByteArray()
	nan.resize(8)
	nan.encode_double(0, NAN)
	var rn: WorldSave.Reader = WorldSave.Reader.new(nan)
	rn.f64()
	check(not rn.ok, "a NaN float is refused")
	var rt: WorldSave.Reader = WorldSave.Reader.new(PackedByteArray([2, 0x41, 0x0a]))
	rt.text()
	check(not rt.ok, "a control byte in a text is refused")


func _check_store() -> void:
	var path: String = _dir.path_join("store/worlds/s.evw")
	var v1: PackedByteArray = "one".to_ascii_buffer()
	var v2: PackedByteArray = "two".to_ascii_buffer()
	var v3: PackedByteArray = "three".to_ascii_buffer()
	check_eq(SaveStore.write_atomic(path, v1), "", "the first write (its folder made)")
	check_eq(_read(path), v1, "the file holds it")
	check(not FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path + ".tmp"), "no backup yet, no .tmp left")
	check_eq(SaveStore.write_atomic(path, v2), "", "the second write")
	check_eq(_read(path), v2, "the file holds the new bytes")
	check_eq(_read(path + ".bak"), v1, "the old file is the backup")
	check_eq(SaveStore.write_atomic(path, v3, false), "", "a write that keeps the backup (the file there did not load)")
	check_eq(_read(path), v3, "the file holds the newest")
	check_eq(_read(path + ".bak"), v1, "the backup is still the old good one")
	check(not FileAccess.file_exists(path + ".tmp"), "no .tmp left")
	_write(path + ".tmp", v2)
	var c: PackedStringArray = SaveStore.candidates(path)
	check_eq(c, PackedStringArray([path, path + ".tmp", path + ".bak"]), "a load tries the file, its .tmp, its .bak")
	check_eq(SaveStore.names_in(_dir.path_join("store/worlds"), ".evw"), PackedStringArray(["s"]), "the folder lists its world once")
	_write(_dir.path_join("store/worlds/only.evw.bak"), v1)
	_write(_dir.path_join("store/worlds/junk.txt"), v1)
	_write(_dir.path_join("store/worlds/Bad Name.evw"), v1)
	check_eq(SaveStore.names_in(_dir.path_join("store/worlds"), ".evw"), PackedStringArray(["only", "s"]),
		"a world with only its backup left is listed, junk and bad names are not")
	check_eq(SaveStore.read_bytes(path, 2), PackedByteArray(), "a file larger than the limit is not read")


# --- the world file ------------------------------------------------------------------------------------------------

## The "everyone left" rule at load on a world saved while players were in it.
func _check_emptied(a: Rig) -> void:
	var live_heretics: Array[HereticSim] = a.arenas[Config.MAP_SURFACE].heretics
	var attacker: HereticSim = null
	for h: HereticSim in live_heretics:
		if h.target_id == 777 or h.state == HereticSim.State.ATTACK:
			attacker = h
	var s: WorldSave.Saved = WorldSave.read(a.capture())
	if not check(s.ok(), "a world saved with players in it reads: %s" % s.error):
		return
	var b: Rig = Rig.loaded(s)
	check_eq(b.arenas[Config.MAP_SURFACE].heretics.size(), live_heretics.size(), "every heretic comes back")
	for h: HereticSim in b.arenas[Config.MAP_SURFACE].heretics:
		check(not h.has_target and h.target_id == 0 and h.threat.is_empty() and h.taunt_by == 0 and h.poison_by == 0,
			"heretic %d: no target, threat, taunt or poisoner (player ids die with the process)" % h.id)
		check(h.state != HereticSim.State.ATTACK and h.state != HereticSim.State.CHASE and h.stun_ticks == 0,
			"heretic %d: no attack, chase or stun under way (%s)" % [h.id, HereticSim.STATE_NAMES[h.state]])
	check(b.arenas[Config.MAP_SURFACE].heretics.any(func(h: HereticSim) -> bool: return h.poison_ticks > 0), "a poison running keeps running (nobody's now)")
	check_eq(b.arenas[Config.MAP_SURFACE].spawn_timer, 0, "the spawn timer starts over")
	check(not b.arenas[Config.MAP_SURFACE].occupied, "nobody is on the loaded map")
	if attacker != null and attacker.state == HereticSim.State.ATTACK:
		var back: HereticSim = null
		for h: HereticSim in b.arenas[Config.MAP_SURFACE].heretics:
			if h.id == attacker.id:
				back = h
		check(back != null and back.cooldown == Config.HERETIC_ATTACK_COOLDOWN_TICKS, "an attack under way stopped without its knife")
	for c: CreatureSim in b.arenas[Config.MAP_SURFACE].herd.list:
		check(c.hold_ticks == 0 and c.held_by == 0 and c.poison_by == 0, "creature %d: no snare holder or poisoner" % c.id)
	check(a.arenas[Config.MAP_SURFACE].herd.list.any(func(c: CreatureSim) -> bool: return c.held_by == 4242),
		"saving did not touch the live herd (its snare still holds)")


func _check_round_trip(a: Rig, bytes: PackedByteArray) -> void:
	var s: WorldSave.Saved = WorldSave.read(bytes)
	if not check(s.ok(), "the rich world reads back: %s" % s.error):
		return
	for m: int in MAPS:
		check_eq(s.hashes[m], a.maps[m].content_hash(), "map %d: the saved content hash is the live world's" % m)
		check_eq(s.maps[m].content_hash(), a.maps[m].content_hash(), "map %d: and the loaded world's" % m)
		check_eq(s.maps[m].drop_serial, a.maps[m].drop_serial, "map %d: the next drop id goes on" % m)
		check_eq(s.maps[m].layers, a.maps[m].layers, "map %d: every layer byte" % m)
	var surface: WorldData = s.maps[Config.MAP_SURFACE]
	check_eq(surface.progress.altar_tier, 1, "the altar's tier")
	check_eq(surface.collection.bits(), a.maps[Config.MAP_SURFACE].collection.bits(), "the collection's entries")
	check_eq(surface.collection.kills, a.maps[Config.MAP_SURFACE].collection.kills, "and its kills (the test's five and the herd's one)")
	check_eq(surface.collection.kills, 6, "six kills")
	check(surface.collection.take_fresh().is_empty(), "loading registers nothing new (no log line)")
	check_eq(surface.shop.stock_bytes(), a.maps[Config.MAP_SURFACE].shop.stock_bytes(), "the shop's stock")
	check_eq(surface.rare_zone.center, a.maps[Config.MAP_SURFACE].rare_zone.center, "the rare zone")
	check_eq(surface.chests_bytes(), a.maps[Config.MAP_SURFACE].chests_bytes(), "the chests' contents (durability too)")
	check_eq(s.shop_clock, a.maps[Config.MAP_SURFACE].shop.clock, "the shop's clock")
	check_eq(s.prayers, 4, "the prayers made")
	check_eq(s.deaths, 2, "the deaths")
	check_eq(s.ticks, PLAY_TICKS, "the world's age")
	check_eq(s.world_seed, SEED, "the seed")
	var b: Rig = Rig.loaded(s)
	check_eq(differing(b.capture(), bytes), PackedStringArray(), "the loaded world saves the same file (every section)")
	var ah: Creatures = a.arenas[Config.MAP_SURFACE].herd
	var bh: Creatures = b.arenas[Config.MAP_SURFACE].herd
	check_eq(bh.rng.state, ah.rng.state, "the herd's random stream")
	check_eq(bh.next_id, ah.next_id, "the herd's next id")
	check_eq(bh.waiting.size(), ah.waiting.size(), "the deaths waiting to respawn")
	check_eq(bh.list.size(), ah.list.size(), "every creature")
	for m: int in MAPS:
		check_eq(b.arenas[m].rng.state, a.arenas[m].rng.state, "map %d: the arena's random stream" % m)
		check_eq(b.arenas[m].next_id, a.arenas[m].next_id, "map %d: the next heretic id" % m)
		check_eq(b.arenas[m].shrine_hp, a.arenas[m].shrine_hp, "map %d: the shrine's HP" % m)
		check_eq(b.farms[m].plots.size(), a.farms[m].plots.size(), "map %d: every field's timer" % m)
		for i: int in a.farms[m].plots:
			check(b.farms[m].plots.has(i) and b.farms[m].plots[i].progress == a.farms[m].plots[i].progress
				and b.farms[m].plots[i].water_left == a.farms[m].plots[i].water_left, "map %d: field %d's growth and water" % [m, i])
		check_eq(b.forests[m].hits, a.forests[m].hits, "map %d: the trees' axe hits" % m)
		check_eq(b.forests[m].regrow, a.forests[m].regrow, "map %d: the stumps' regrowth" % m)
	var ab: BossFight = a.arenas[Config.MAP_DUNGEON].boss
	var bb: BossFight = b.arenas[Config.MAP_DUNGEON].boss
	check_eq(bb.rng.state, ab.rng.state, "the boss's random stream")
	check_eq(bb.site().describe(), ab.site().describe(), "the sleeping boss's pillars keep their cracks")
	check_eq(bb.sim.state, BossSim.State.SLEEP, "it sleeps")
	check_eq(BossFight.Pillar.hits_per_state() > 0 and bb.pillars[0].hits == 4, true, "pillar 1's four hits")


## The claim: a loaded world plays on exactly as the world that never stopped (after the same "everyone left"). A load whose herd
## stream is left as set up instead (the control) does not: the check sees a missing piece.
func _check_play_on(a: Rig, bytes: PackedByteArray) -> void:
	var s: WorldSave.Saved = WorldSave.read(bytes)
	var control: WorldSave.Saved = WorldSave.read(bytes)
	if not check(s.ok() and control.ok(), "the saved world reads twice"):
		return
	var b: Rig = Rig.loaded(s)
	var c: Rig = Rig.loaded(control)
	c.arenas[Config.MAP_SURFACE].herd.rng.seed = 12345  # the control: one stream not put back
	a.step(PLAY_ON_TICKS)
	b.step(PLAY_ON_TICKS)
	c.step(PLAY_ON_TICKS)
	var after_a: PackedByteArray = a.capture()
	check_eq(differing(b.capture(), after_a), PackedStringArray(),
		"%d ticks on, the loaded world is the world that never stopped (every section)" % PLAY_ON_TICKS)
	for m: int in MAPS:
		check_eq(b.maps[m].content_hash(), a.maps[m].content_hash(), "map %d: the same content hash" % m)
	check(b.forests[Config.MAP_SURFACE].stat("regrown") >= 1, "a stump grew back during the play-on")
	check(b.farms[Config.MAP_SURFACE].stat("grown") > 0, "a crop grew during the play-on (M13 review: a check that can fail)")
	check_ne(differing(c.capture(), after_a), PackedStringArray(), "the control (the herd's stream not put back) is another world")
	check_ne(differing(after_a, bytes, false), PackedStringArray(), "the world did change during the play-on (the check is not empty)")
	note("play-on: %d ticks saved, %d after; herd %d creatures, %d heretics on the surface; file %d bytes" % [PLAY_TICKS, PLAY_ON_TICKS,
		a.arenas[Config.MAP_SURFACE].herd.list.size(), a.arenas[Config.MAP_SURFACE].heretics.size(), bytes.size()])


func _check_refusals(bytes: PackedByteArray) -> void:
	var refused: Array[Array] = []  # [label, bytes]
	refused.append(["empty", PackedByteArray()])
	refused.append(["header only", bytes.slice(0, WorldSave.HEADER_BYTES)])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13
	for n: int in [20, 300, bytes.size()]:
		var junk: PackedByteArray = PackedByteArray()
		junk.resize(n)
		for i: int in n:
			junk[i] = rng.randi_range(0, 255)
		refused.append(["%d random bytes" % n, junk])
	var with_magic: PackedByteArray = bytes.duplicate()
	for i: int in range(4, with_magic.size()):
		with_magic[i] = rng.randi_range(0, 255)
	refused.append(["the mark and random bytes", with_magic])
	var magic: PackedByteArray = bytes.duplicate()
	magic[0] = 0x58
	refused.append(["another mark", magic])
	var newer: PackedByteArray = bytes.duplicate()
	newer.encode_u16(4, WorldSave.FORMAT_VERSION + 1)
	refused.append(["a newer format", newer])
	for cut: int in [1, 16, 17, 100, bytes.size() / 2, bytes.size() - 1]:
		refused.append(["cut short by %d" % cut, bytes.slice(0, bytes.size() - cut)])
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	refused.append(["a byte added", longer])
	for at: int in [6, 13, bytes.size() / 3, bytes.size() / 2, bytes.size() - 17]:
		var flipped: PackedByteArray = bytes.duplicate()
		flipped[at] = flipped[at] ^ 0x10
		refused.append(["a bit flipped at %d" % at, flipped])
	# Hostile: a good checksum around content that is wrong.
	var order: PackedStringArray = []
	var sections: Dictionary[String, PackedByteArray] = sections_of(bytes, order)
	check_eq(order, WorldSave.TAGS, "the file's sections in their order")
	check(WorldSave.read(rebuild(sections, order)).ok(), "a rebuilt file reads (the rebuild is right)")
	refused.append(["an older format with a good checksum", rebuild(sections, order, 0)])
	var missing: PackedStringArray = order.duplicate()
	missing.remove_at(missing.find("HERD"))
	refused.append(["a section missing", rebuild(sections, missing)])
	var twice: PackedStringArray = order.duplicate()
	twice[twice.find("HERD")] = "SHOP"
	refused.append(["a section twice", rebuild(sections, twice)])
	var unknown: PackedStringArray = order.duplicate()
	unknown[unknown.find("HERD")] = "XTRA"
	var with_unknown: Dictionary[String, PackedByteArray] = sections.duplicate()
	with_unknown["XTRA"] = sections["HERD"]
	refused.append(["an unknown section", rebuild(with_unknown, unknown)])
	refused.append(_patched("an item table that changed", sections, order, "ITEM", 3, 0x7a))
	refused.append(_patched("a map whose hash is another", sections, order, "MAP0", 6, 0xff, true))
	refused.append(_patched("the surface section holding map 1", sections, order, "MAP0", 0, 1))
	refused.append(_patched("a META byte left over", sections, order, "META", -1, 0))
	refused.append(_patched("a heretic off the map", sections, order, "ARN0", 1 + 8 + 4 + 4 + 4 + 2 + 4 + 7, 0x7f))
	refused.append(_patched("a heretic at NaN", sections, order, "ARN0", 1 + 8 + 4 + 4 + 4 + 2 + 4 + 6, 0xf8, false, 0xff))
	refused.append(_patched("a creature of no kind (its name's length 0)", sections, order, "HERD", 1 + 8 + 4 + 4 + 2 + 4, 0))
	refused.append(_patched("a farm plot off the map", sections, order, "FRM0", 1 + 4 + 3, 0x7f))
	refused.append(_patched("a negative shrine HP", sections, order, "ARN1", 1 + 8 + 4 + 4 + 3, 0x80))
	# M13 review: a pillar past broken, the shrine above its HP and a creature kind the table dropped are fitted now (_check_fitting).
	for row: Array in refused:
		var label: String = row[0]
		var b: PackedByteArray = row[1]
		var s: WorldSave.Saved = WorldSave.read(b)
		check(not s.ok() and s.maps.is_empty() and s.herd == null, "%s: refused whole (%s)" % [label, s.error])
	note("refusals: %d files, e.g. '%s'" % [refused.size(), WorldSave.read(newer).error])


## [label, the file with section `tag`'s byte `at` (-1: one byte appended) set to `value` (and the byte after it to `next` when >= 0),
## rebuilt with a good checksum]. `xor`: the byte is xored with `value` (sure to change).
static func _patched(label: String, sections: Dictionary[String, PackedByteArray], order: PackedStringArray, tag: String, at: int,
		value: int, xor: bool = false, next: int = -1) -> Array:
	var copy: Dictionary[String, PackedByteArray] = sections.duplicate()
	var payload: PackedByteArray = copy[tag].duplicate()
	if at < 0:
		payload.append(value)
	else:
		payload[at] = (payload[at] ^ value) if xor else value
		if next >= 0:
			payload[at + 1] = next
	copy[tag] = payload
	return [label, rebuild(copy, order)]


## The loads after a crash: the file, its .tmp (between the two renames of a save), its .bak.
func _check_fallbacks(bytes: PackedByteArray) -> void:
	var dir: String = _dir.path_join("fallback")
	var older: PackedByteArray = Rig.fresh(SEED).capture()
	var path: String = dir.path_join("w.evw")
	var broken: PackedByteArray = bytes.slice(0, bytes.size() / 2)
	check_eq(WorldSave.load_from(path).error, "missing", "no file: missing")
	_write(path + ".bak", older)
	var only_bak: WorldSave.Saved = WorldSave.load_from(path)
	check(only_bak.ok() and only_bak.path == path + ".bak", "only the backup left: it loads")
	_write(path, broken)
	var from_bak: WorldSave.Saved = WorldSave.load_from(path)
	check(from_bak.ok() and from_bak.path == path + ".bak" and from_bak.skipped.contains("w.evw:"),
		"a broken file and a good backup: the backup loads, the broken file's reason kept (%s)" % from_bak.skipped)
	DirAccess.remove_absolute(path)
	_write(path + ".tmp", bytes)
	var from_tmp: WorldSave.Saved = WorldSave.load_from(path)
	check(from_tmp.ok() and from_tmp.path == path + ".tmp" and from_tmp.ticks == PLAY_TICKS,
		"cut off between the renames (no file, a whole .tmp): the newer .tmp loads before the backup")
	_write(path + ".tmp", broken)
	_write(path, bytes)
	var stray: WorldSave.Saved = WorldSave.load_from(path)
	check(stray.ok() and stray.path == path, "a stray half .tmp next to a good file: the file loads")
	_write(path + ".bak", broken)
	_write(path, broken)
	var none: WorldSave.Saved = WorldSave.load_from(path)
	check(not none.ok() and none.error.contains("w.evw:") and none.error.contains("w.evw.tmp:") and none.error.contains("w.evw.bak:"),
		"nothing loads: refused, every file's reason (%s)" % none.error.left(120))
	# Saving after the backup loaded: the broken file is replaced, the good backup kept (rotate off), then saves rotate again.
	_write(path + ".bak", older)
	_write(path, broken)
	DirAccess.remove_absolute(path + ".tmp")
	var loaded: WorldSave.Saved = WorldSave.load_from(path)
	check_eq(SaveStore.write_atomic(path, bytes, loaded.path == path), "", "the next save writes")
	check_eq(_read(path), bytes, "the file is the new save")
	check_eq(_read(path + ".bak"), older, "the good backup was not replaced by the broken file")


## A carried altar (its tiles empty, the world's altar_rect empty) is written put back where it last stood; the live world keeps it carried.
func _check_carried_altar() -> void:
	var r: Rig = Rig.fresh(SEED)
	var s: WorldData = r.maps[Config.MAP_SURFACE]
	var home: Rect2i = s.altar_rect
	Rig.put(s, AltarMove.pickup_edits(s))
	check(not s.altar_rect.has_area(), "the rig's altar is carried")
	var hash_carried: String = s.content_hash()
	var saved: WorldSave.Saved = WorldSave.read(r.capture())
	if not check(saved.ok(), "a world with its altar carried saves: %s" % saved.error):
		return
	check_eq(saved.maps[Config.MAP_SURFACE].altar_rect, home, "the file has the altar where it last stood")
	check_eq(saved.last_altar[Config.MAP_SURFACE], home, "and that place as its last")
	check_ne(saved.hashes[Config.MAP_SURFACE], hash_carried, "the saved hash is the world with its altar")
	check_eq(saved.maps[Config.MAP_SURFACE].content_hash(), saved.hashes[Config.MAP_SURFACE], "and the loaded one has it")
	check(not s.altar_rect.has_area() and s.content_hash() == hash_carried, "the live world still has it carried")


## Saving changes no generated world (the golden hashes) and reads none differently.
func _check_golden() -> void:
	var r: Rig = Rig.fresh(Config.DEFAULT_SEED)
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED, Config.MAP_SIZE)
	check_eq(surface.content_hash(), SurfaceGen.GOLDEN_HASH, "the generated surface is still golden")
	check_eq(DungeonGen.generate(Config.DEFAULT_SEED).content_hash(), DungeonGen.GOLDEN_HASH, "the generated dungeon is still golden")
	var s: WorldSave.Saved = WorldSave.read(r.capture())
	check(s.ok() and s.maps[Config.MAP_DUNGEON].content_hash() == DungeonGen.GOLDEN_HASH,
		"a saved fresh dungeon loads golden (its boss on it)")
	var bare: Dictionary[int, WorldData] = {Config.MAP_SURFACE: surface, Config.MAP_DUNGEON: DungeonGen.generate(Config.DEFAULT_SEED)}
	var l: WorldSave.Live = WorldSave.Live.new()
	l.maps = bare
	var bare_saved: WorldSave.Saved = WorldSave.read(WorldSave.capture(l))
	check(bare_saved.ok() and bare_saved.maps[Config.MAP_SURFACE].content_hash() == SurfaceGen.GOLDEN_HASH,
		"a bare generated surface saves and loads golden: %s" % bare_saved.error)


## A fight under way when the world was saved comes back as the map emptying leaves it (BossFight.reset): the boss asleep at home with
## its full HP, its pillars whole, the heretics it called gone; the other heretics stay.
func _check_fight_reset() -> void:
	var r: Rig = Rig.fresh(SEED)
	var a: Arena = r.arenas[Config.MAP_DUNGEON]
	var f: BossFight = a.boss
	var plain: HereticSim = a.spawn_heretic(Arena.spawn_feet(a.spawn_cells[0]))
	f.wake([] as Array[Player])
	f.set_pillar_hits(0, 5)
	f.hit(10, 0)
	var add: HereticSim = a.spawn_heretic(f.sim.pos + Vector2(28, 0))
	f.sim.adds.append(add.id)
	check(f.sim.awake() and f.sim.hp < f.sim.hp_max, "the rig's boss is awake and hurt")
	var s: WorldSave.Saved = WorldSave.read(r.capture())
	if not check(s.ok(), "a world saved mid-fight reads: %s" % s.error):
		return
	var b: Rig = Rig.loaded(s)
	var g: BossFight = b.arenas[Config.MAP_DUNGEON].boss
	check_eq(g.sim.state, BossSim.State.SLEEP, "the boss is back asleep")
	check(g.sim.hp == g.sim.hp_max and g.sim.pos == g.sim.home, "at home with its full HP")
	check(g.pillars.all(func(p: BossFight.Pillar) -> bool: return p.hits == 0 and not p.fallen), "its pillars whole again")
	var ids: Array[int] = []
	for h: HereticSim in b.arenas[Config.MAP_DUNGEON].heretics:
		ids.append(h.id)
	check(not ids.has(add.id), "the heretic it called is gone")
	check(ids.has(plain.id), "the dungeon's own heretic stays")
	check(f.sim.awake() and f.pillars[0].hits == 5, "saving did not touch the live fight")


## A sleeping boss's pillar with more hits than its broken state (a test flag allows up to 99) is written cut to the broken state, as its
## snapshot site cuts it: the writer never writes what its reader refuses (review: --test-pillar-hits=1:20 made a world that did not load).
func _check_pillar_cap() -> void:
	var r: Rig = Rig.fresh(SEED)
	var f: BossFight = r.arenas[Config.MAP_DUNGEON].boss
	f.set_pillar_hits(0, 20)
	var s: WorldSave.Saved = WorldSave.read(r.capture())
	if not check(s.ok(), "a sleeping boss's pillar past broken saves and reads: %s" % s.error):
		return
	var g: BossFight = Rig.loaded(s).arenas[Config.MAP_DUNGEON].boss
	var broken: int = BossFight.Pillar.hits_per_state() * 3
	check(g.pillars[0].fallen and g.pillars[0].hits == broken, "it comes back as rubble at the broken state's hits")
	check_eq(f.pillars[0].hits, 20, "the live pillar keeps its hits")


## M13 review (● R54 "보스와 기둥" go on where they were): a boss killed in play lies dead with its pillars as the fight left them, whole,
## cracked or rubble, each blocking as it did (BossFight.setup alone lays every pillar of a dead boss down: right for a flag's dead boss).
func _check_dead_pillars() -> void:
	var r: Rig = Rig.fresh(SEED)
	var f: BossFight = r.arenas[Config.MAP_DUNGEON].boss
	var broken: int = BossFight.Pillar.hits_per_state() * 3
	f.set_pillar_hits(1, broken)
	f.set_pillar_hits(2, BossFight.Pillar.hits_per_state() + 1)
	f.wake([] as Array[Player])
	f.hit(f.sim.hp, 0)
	check(f.sim.state == BossSim.State.DEAD and r.maps[Config.MAP_DUNGEON].progress.boss_defeated, "the rig's boss is killed in play")
	var want: Array = []
	for p: BossFight.Pillar in f.pillars:
		want.append([p.hits, p.fallen, r.maps[Config.MAP_DUNGEON].blockers.has(p.tile)])
	var s: WorldSave.Saved = WorldSave.read(r.capture())
	if not check(s.ok() and s.fitted.is_empty(), "a world with a boss killed in play reads: %s" % s.error):
		return
	var b: Rig = Rig.loaded(s)
	var g: BossFight = b.arenas[Config.MAP_DUNGEON].boss
	var got: Array = []
	for p: BossFight.Pillar in g.pillars:
		got.append([p.hits, p.fallen, b.maps[Config.MAP_DUNGEON].blockers.has(p.tile)])
	check(g.sim.state == BossSim.State.DEAD, "it lies dead after the load")
	check_eq(got, want, "its pillars as the fight left them: whole and cracked ones standing (blocking), the broken one rubble")
	var shape: bool = str(want.slice(0, 2)) == str([[0, false, true], [broken, true, false]]) and str(want[2]).ends_with("true]")
	check(shape, "(whole blocks, rubble does not, cracked blocks: %s)" % str(want))
	check_eq(differing(b.capture(), r.capture()), PackedStringArray(), "and it saves again as it was")


## M13 review: the dungeon's spawn tiles follow mining (Arena._sync_dungeon_terrain). Before, the live arena kept the tiles of its setup
## while a loaded one worked them out on the mined map, so after the same "everyone left" the two spawned elsewhere (ARN1 differed) and the
## determinism claim did not hold where players had mined. Here: walls mined next to the far floor, the live arena's tiles = worked out on
## the mined map, and a loaded world spawns its heretics where the world that never stopped does (stand-in players: the Rig has none).
func _check_mined_spawns() -> void:
	var a: Rig = Rig.fresh(SEED)
	var dg: WorldData = a.maps[Config.MAP_DUNGEON]
	var arena: Arena = a.arenas[Config.MAP_DUNGEON]
	var before: Array[Vector2i] = arena.spawn_cells.duplicate()
	var dist: Dictionary[Vector2i, int] = Arena.arrival_distances(dg)
	var mined: Array[EditLog.WorldEdit] = []
	for c: Vector2i in dist:
		if dist[c] < Config.HERETIC_SPAWN_ARRIVAL_MIN_TILES + 6:
			continue
		for d: Vector2i in DungeonGen.STEPS:
			var w: Vector2i = c + d
			if mined.size() < 40 and dg.in_bounds(w) and Walls.kind_at(dg, w) == Walls.KIND_ROCK and w.x > 1 and w.y > 1 \
					and w.x < dg.size.x - 2 and w.y < dg.size.y - 2:
				mined.append(EditLog.WorldEdit.new(WorldData.Layer.WALL, w, 0))
	Rig.put(dg, mined)
	a.step(1)
	check(mined.size() >= 10, "%d rock walls mined next to the far floor" % mined.size())
	var fresh: Array[Vector2i] = Arena.dungeon_spawn_cells(dg)
	check(arena.spawn_cells == fresh, "the live arena's spawn tiles are worked out on the mined map (%d, fresh %d)" % [arena.spawn_cells.size(),
		fresh.size()])
	check(arena.spawn_cells != before, "and they changed (%d -> %d)" % [before.size(), arena.spawn_cells.size()])
	a.quiesce()
	var s: WorldSave.Saved = WorldSave.read(a.capture())
	if not check(s.ok(), "the mined world reads: %s" % s.error):
		return
	var b: Rig = Rig.loaded(s)
	var pa: Player = Player.new()
	pa.setup(dg, "paladin", DungeonGen.arrival_point(dg), Config.SPAWN_FACING)
	var pb: Player = Player.new()
	pb.setup(b.maps[Config.MAP_DUNGEON], "paladin", DungeonGen.arrival_point(b.maps[Config.MAP_DUNGEON]), Config.SPAWN_FACING)
	var spawned: int = 0
	var same: bool = true
	for i: int in 6:
		var ha: HereticSim = a.arenas[Config.MAP_DUNGEON].try_spawn([pa] as Array[Player])
		var hb: HereticSim = b.arenas[Config.MAP_DUNGEON].try_spawn([pb] as Array[Player])
		same = same and (ha == null) == (hb == null) and (ha == null or ha.pos == hb.pos)
		spawned += 1 if ha != null else 0
	check(spawned > 0 and same, "%d heretics spawned, each where the world that never stopped put its own" % spawned)
	check_eq(differing(b.capture(), a.capture()), PackedStringArray(), "every section the same after the spawns (ARN1 too)")
	pa.free()
	pb.free()


## M13 review: tuning a PROVISIONAL value (README 임시값) must not lock a world out. A file as a build with other values would write it: a
## chest of two slots more (a stack in one of them), a shop with an offer this game has not, a drop and a chest stack past their stack size,
## a sword past full durability, a collection entry past the table, the altar past its top tier, a pillar past broken, the shrine above its
## HP, a creature of a kind the table dropped. It loads, fitted to this build (each change noted), and plays.
func _check_fitting(bytes: PackedByteArray) -> void:
	var order: PackedStringArray = []
	var sections: Dictionary[String, PackedByteArray] = sections_of(bytes, order)
	var plain: WorldSave.Saved = WorldSave.read(bytes)
	if not check(plain.ok() and plain.fitted.is_empty(), "the rich world reads with nothing fitted"):
		return
	var parts: Dictionary = map_parts(sections["MAP0"])
	var raw: PackedByteArray = parts["raw"]
	var surface: WorldData = plain.maps[Config.MAP_SURFACE]
	var cells: int = surface.size.x * surface.size.y
	var at: int = WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * cells
	var drops: int = raw.decode_u16(at)
	check(drops >= 1, "the rich surface has drops (%d)" % drops)
	raw[at + 2 + 5] = 255  # the first drop's count, past any stack
	var chests_at: int = at + 2 + WorldData.DROP_BYTES * drops
	var chests: int = raw.decode_u16(chests_at)
	var old_chest: int = 4 + EditLog.STACK_BYTES * Config.CHEST_SLOTS
	var wider: PackedByteArray = raw.slice(0, chests_at + 2)
	var planks: PackedByteArray = PackedByteArray([ItemDB.index_of(&"planks") + 1, 3, ItemDB.Grade.NONE, 0, 0])
	for i: int in chests:
		var chest: PackedByteArray = raw.slice(chests_at + 2 + old_chest * i, chests_at + 2 + old_chest * (i + 1))
		for k: int in Config.CHEST_SLOTS:
			var st: int = 4 + EditLog.STACK_BYTES * k
			if chest[st] == ItemDB.index_of(&"stone_a") + 1:
				chest[st + 1] = 255  # past the stone's stack
			if chest[st] == ItemDB.index_of(&"sword_t1") + 1:
				chest.encode_u16(st + 3, 9999)  # past the sword's full durability
		wider.append_array(chest)
		wider.append_array(planks)  # two slots more: planks in the first, the second empty
		wider.append_array(PackedByteArray([0, 0, 0, 0, 0]))
	var shop_at: int = chests_at + 2 + old_chest * chests
	var offers: int = raw.decode_u8(shop_at)
	var stock: PackedByteArray = raw.slice(shop_at + 1, shop_at + 1 + offers)
	wider.append(offers + 1)
	wider.append(4)  # an offer this game has not, in front
	wider.append_array(stock)
	var tail: PackedByteArray = raw.slice(shop_at + 1 + offers)
	var zone_end: int = 1 + (WorldSnapshot.ZONE_BYTES if tail[0] == 1 else 0)
	if tail[zone_end] == 1:
		tail.encode_u16(zone_end + 1, tail.decode_u16(zone_end + 1) | (1 << Collection.total()))  # an entry past the table
	var progress_at: int = zone_end + 1 + (WorldSnapshot.COLLECTION_BYTES if tail[zone_end] == 1 else 0)
	if tail[progress_at] == 1:
		tail[progress_at + 1] = Config.ALTAR_TIER_MAX + 3
	wider.append_array(tail)
	var ids: Array[StringName] = [&"gone_offer"]
	var saved_ids: Array[StringName] = parts["offers"]
	ids.append_array(saved_ids)
	parts["raw"] = wider
	parts["chest_slots"] = Config.CHEST_SLOTS + 2
	parts["offers"] = ids
	var tuned: Dictionary[String, PackedByteArray] = sections.duplicate()
	tuned["MAP0"] = map_payload(parts)
	var boss: PackedByteArray = sections["BOSS"].duplicate()
	boss[1 + 8 + 4 + 1 + 4 + 4 + 1 + 1] = 0x7f  # pillar 0's hits past broken
	tuned["BOSS"] = boss
	var shrine: PackedByteArray = sections["ARN1"].duplicate()
	shrine[1 + 8 + 4 + 4 + 2] = 0x7f  # the shrine's HP far above Config.SHRINE_HP
	tuned["ARN1"] = shrine
	var herd: PackedByteArray = tuned["HERD"].duplicate()
	herd[1 + 8 + 4 + 4 + 2 + 4 + 1] = 0x5a  # the first creature's kind: a name the table has not
	tuned["HERD"] = herd
	var s: WorldSave.Saved = WorldSave.read(rebuild(tuned, order))
	if not check(s.ok(), "a file of other PROVISIONAL values loads: %s" % s.error):
		return
	var notes: String = " | ".join(s.fitted)
	for want: String in ["2 stacks cut to their stack size", "chests had %d slots, now %d" % [Config.CHEST_SLOTS + 2, Config.CHEST_SLOTS], "shop's stock matched",
			"collection entries past", "altar's tier", "durability cut to full", "pillar 0's hits",
			"shrine's HP", "kind 'Z"]:
		check(notes.contains(want), "fitted: %s (%s)" % [want, notes.left(300)])
	var fs: WorldData = s.maps[Config.MAP_SURFACE]
	var held: WorldData.Chest = fs.chests[fs.held_chests()[0]] if not fs.held_chests().is_empty() else null
	var found: Dictionary[StringName, ItemStack] = {}
	if held != null:
		for st: ItemStack in held.slots:
			if st != null:
				found[st.id] = st
	check(found.has(&"planks") and found[&"planks"].count == 3, "the stack from the extra slot moved into a free slot")
	check(found.has(&"stone_a") and found[&"stone_a"].count == ItemDB.get_def(&"stone_a").stack_max, "the stone stack cut to its size")
	check(found.has(&"sword_t1") and found[&"sword_t1"].durability == ItemDB.get_def(&"sword_t1").durability, "the sword cut to full")
	check_eq(fs.shop.stock_bytes(), surface.shop.stock_bytes(), "the shop's stock as saved, by item (the gone offer left out)")
	check_eq(fs.collection.count(), surface.collection.count(), "the collection's entries this game has")
	check_eq(fs.progress.altar_tier, Config.ALTAR_TIER_MAX, "the tier at this game's top")
	check(s.arenas[Config.MAP_DUNGEON].shrine_hp == Config.SHRINE_HP, "the shrine at its full HP")
	check_eq(s.herd.creatures.size(), plain.herd.creatures.size() - 1, "the creature of the dropped kind left out")
	var b: Rig = Rig.loaded(s)
	b.step(30)
	var again: WorldSave.Saved = WorldSave.read(b.capture())
	check(again.ok() and again.fitted.is_empty(), "it plays and saves again as this build's file (nothing to fit)")


## [map id, raw size, hash, serial, last place, chest slots, offers, raw] of a MAP section (its fields as WorldSave._read_map reads them).
static func map_parts(payload: PackedByteArray) -> Dictionary:
	var r: WorldSave.Reader = WorldSave.Reader.new(payload)
	var map: int = r.u8()
	var raw_size: int = r.u32()
	var out: Dictionary = {"map": map, "raw_size": raw_size, "hash": r.take(16), "serial": r.u32(), "last": r.take(8),
		"chest_slots": r.u8()}
	var ids: Array[StringName] = []
	var n: int = r.u8()
	for i: int in n:
		ids.append(StringName(r.text()))
	out["offers"] = ids
	var packed: PackedByteArray = r.take(r.u32())
	out["raw"] = packed.decompress(raw_size, WorldSnapshot.COMPRESSION)
	return out


static func map_payload(parts: Dictionary) -> PackedByteArray:
	var w: WorldSave.Writer = WorldSave.Writer.new()
	var raw: PackedByteArray = parts["raw"]
	var map: int = parts["map"]
	var hash: PackedByteArray = parts["hash"]
	var serial: int = parts["serial"]
	var last: PackedByteArray = parts["last"]
	var chest_slots: int = parts["chest_slots"]
	var ids: Array[StringName] = parts["offers"]
	w.u8(map)
	w.u32(raw.size())
	w.put(hash)
	w.u32(serial)
	w.put(last)
	w.u8(chest_slots)
	w.u8(ids.size())
	for id: StringName in ids:
		w.text(String(id))
	var packed: PackedByteArray = raw.compress(WorldSnapshot.COMPRESSION)
	w.u32(packed.size())
	w.put(packed)
	return w.bytes


## M13 review: the committed fixture files (FIXTURE_WORLD, FIXTURE_CHARACTER: what this build wrote) read exactly, nothing fitted. A change
## that would read them otherwise fails here: then FORMAT_VERSION goes up with a migration for the files people have (and the runner flag
## --write-save-fixtures writes new fixtures).
func _check_fixture(bytes: PackedByteArray) -> void:
	var args: Dictionary[String, String] = Runner.parse_args(OS.get_cmdline_user_args())
	if args.has("write-save-fixtures"):
		_write(ProjectSettings.globalize_path(FIXTURE_WORLD), bytes)
		_write(ProjectSettings.globalize_path(FIXTURE_CHARACTER), CharacterSave.encode(fixture_character()))
		note("wrote the save fixtures")
	var s: WorldSave.Saved = WorldSave.read(FileAccess.get_file_as_bytes(FIXTURE_WORLD))
	if not check(s.ok() and s.fitted.is_empty(), "the fixture world (%s) reads exactly: %s %s" % [FIXTURE_WORLD, s.error, " ".join(s.fitted)]):
		return
	var fs: WorldData = s.maps[Config.MAP_SURFACE]
	check(s.world_seed == SEED and s.ticks == PLAY_TICKS and s.prayers == 4 and s.deaths == 2, "its META (seed, age, prayers, deaths)")
	check(fs.progress.altar_tier == 1 and fs.collection.count() == 3 and fs.collection.kills >= 5, "its tier and collection")
	check(fs.held_chests().size() == 1 and fs.drops.size() >= 2 and fs.shop != null, "its chest, drops (%d) and shop" % fs.drops.size())
	check(s.herd != null and s.herd.creatures.size() >= 3 and not s.herd.waiting.is_empty(), "its herd and a death waiting")
	check(s.boss != null and s.boss.state == WorldSave.BOSS_ASLEEP and s.boss.hits.size() >= 2 and s.boss.hits[0] == 4, "its sleeping boss")
	var b: Rig = Rig.loaded(s)
	b.step(10)
	check(WorldSave.read(b.capture()).ok(), "it plays and saves")
	var c: CharacterSave.Result = CharacterSave.read(FileAccess.get_file_as_bytes(FIXTURE_CHARACTER))
	check(c.ok() and c.fitted.is_empty(), "the fixture character reads exactly: %s %s" % [c.error, " ".join(c.fitted)])
	if c.ok():
		check_eq(CharacterSave.encode(c.character).slice(0, 40), CharacterSave.encode(fixture_character()).slice(0, 40), "its head")
		check(c.character.describe() == fixture_character().describe() and str(c.character.stacks) == str(fixture_character().stacks),
			"its class, slots, money, armour and seen as written")


## The fixture's character: a miner with money, fine herbs, a worn sword, worn armour, the relic.
static func fixture_character() -> CharacterSave.Sheet:
	var c: CharacterSave.Sheet = CharacterSave.Sheet.new()
	c.name = "fixture"
	c.class_id = "miner"
	c.selected = 2
	c.stacks[0] = ItemStack.new(ItemDB.MONEY, 137, ItemDB.Grade.NONE)
	c.stacks[1] = ItemStack.new(&"wild_healing", 3, ItemDB.Grade.FINE)
	c.stacks[2] = ItemStack.new(&"sword_t1", 1, ItemDB.Grade.NONE, 41)
	c.stacks[5] = ItemStack.new(Config.BOSS_RELIC, 1, ItemDB.Grade.NONE)
	c.stacks[Config.START_WEAPON_SLOT] = ItemStack.new(Combat.class_weapon("miner"), 1, ItemDB.Grade.NONE)
	c.armor = ItemStack.new(&"armor_t1", 1, ItemDB.Grade.NONE, 23)
	c.seen.assign([Config.BOSS_RELIC, &"armor_t1", ItemDB.MONEY, &"sword_t1", &"wild_healing", Combat.class_weapon("miner")])
	return c


## The character file: what a hand may change (what is left out, a byte order mark, other keys, unknown ids in seen) and what is refused
## (broken text, the wrong header, impossible stacks, wrong types) without an engine error; the backup when the file does not load.
func _check_character_file() -> void:
	var good: Dictionary = {"format": "evensong-character", "version": 1, "name": "x", "class": "miner", "selected": 2,
		"slots": [{"item": "money", "count": 250, "grade": "none"}, null, {"item": "wild_healing", "count": 3, "grade": "fine"},
		{"item": "sword_t1", "count": 1, "grade": "none", "durability": 7}], "armor": {"item": "armor_t1", "count": 1, "durability": 12},
		"seen": ["money", "no_such_item", "sword_t1"], "note": "a friend's note"}
	var r: CharacterSave.Result = CharacterSave.read(JSON.stringify(good).to_ascii_buffer())
	if not check(r.ok(), "a hand-written character reads: %s" % r.error):
		return
	var c: CharacterSave.Sheet = r.character
	check(c.class_id == "miner" and c.selected == 2 and c.stacks.size() == Config.INVENTORY_SLOTS, "its class, selected slot, 24 slots")
	check(c.stacks[0] != null and c.stacks[0].id == ItemDB.MONEY and c.stacks[0].count == 250 and c.money() == 250, "a full stack of money")
	check(c.stacks[1] == null and c.stacks[4] == null and c.stacks[23] == null, "null and the slots not written are empty")
	check(c.stacks[2] != null and c.stacks[2].grade == ItemDB.Grade.FINE, "a fine herb")
	check(c.stacks[3] != null and c.stacks[3].durability == 7, "a worn sword")
	check(c.armor != null and c.armor.durability == 12, "the worn armour")
	var want_seen: Array[StringName] = [&"money", &"sword_t1"]
	check_eq(c.seen, want_seen, "seen: the unknown id skipped")
	var back: CharacterSave.Result = CharacterSave.read(CharacterSave.encode(c))
	check(back.ok() and back.character.describe() == c.describe() and str(back.character.stacks) == str(c.stacks), "it writes back the same")
	var lenient: Dictionary = {"format": "evensong-character", "version": 1, "class": "cleric",
		"slots": [{"item": "wild_buff", "count": 2}, {"item": "pickaxe_t1", "count": 1}]}
	var l: CharacterSave.Result = CharacterSave.read(JSON.stringify(lenient).to_ascii_buffer())
	check(l.ok() and l.character.stacks[0].grade == ItemDB.Grade.COMMON and l.character.selected == 0 and l.character.armor == null,
		"left out: the item's default grade, slot 0 selected, no armour: %s" % l.error)
	check(l.ok() and l.character.stacks[1].durability == ItemDB.get_def(&"pickaxe_t1").durability, "left out: full durability")
	var bom: PackedByteArray = PackedByteArray([0xEF, 0xBB, 0xBF])
	bom.append_array(JSON.stringify(good, "\t").to_ascii_buffer())
	check(CharacterSave.read(bom).ok(), "a UTF-8 byte order mark in front is skipped")
	var refused: Array[Array] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17
	var junk: PackedByteArray = PackedByteArray()
	for i: int in 64:
		junk.append(rng.randi_range(0, 255))
	var text: String = JSON.stringify(good)
	refused.append(["empty", PackedByteArray()])
	refused.append(["random bytes", junk])
	refused.append(["cut short", text.left(text.length() / 2).to_ascii_buffer()])
	refused.append(["a non-ASCII byte", text.replace("\"x\"", "\"é\"").to_utf8_buffer()])
	refused.append(["a list, not an object", "[1, 2]".to_ascii_buffer()])
	refused.append(["nested too deep", ("[".repeat(5000) + "]".repeat(5000)).to_ascii_buffer()])
	refused.append(["larger than the limit", (text.left(text.length() - 1) + "," + "\"pad\": \"%s\"}" % " ".repeat(Config.CHARACTER_FILE_MAX_BYTES)).to_ascii_buffer()])
	for row: Array in [["format", "evensong-world"], ["format", 1], ["version", 2], ["version", "1"], ["version", 1.5], ["class", "wizard"],
			["class", null], ["selected", 8], ["selected", -1], ["selected", "2"], ["slots", {}], ["slots", "x"], ["seen", "x"], ["armor", 5],
			["armor", {"item": "sword_t1", "count": 1}], ["armor", {"item": "armor_t1", "count": 1, "durability": -3}]]:
		var key: String = row[0]
		var d: Dictionary = good.duplicate(true)
		d[key] = row[1]
		refused.append(["%s = %s" % [key, JSON.stringify(row[1])], JSON.stringify(d).to_ascii_buffer()])
	var no_class: Dictionary = good.duplicate(true)
	no_class.erase("class")
	refused.append(["no class", JSON.stringify(no_class).to_ascii_buffer()])
	for row: Array in [["item", "no_such_item"], ["item", 7], ["count", 0], ["count", 1.5], ["count", "3"], ["count", -1],
			["grade", "fine"], ["grade", "epic"], ["grade", 1]]:
		var key: String = row[0]
		var d: Dictionary = good.duplicate(true)
		var slots: Array = d["slots"]
		var money: Dictionary = slots[0]
		money[key] = row[1]
		refused.append(["money's %s = %s" % [key, JSON.stringify(row[1])], JSON.stringify(d).to_ascii_buffer()])
	var huge: Dictionary = good.duplicate(true)
	var huge_slots: Array = huge["slots"]
	var huge_money: Dictionary = huge_slots[0]
	huge_money["count"] = 777777
	refused.append(["a count of 1e400 (infinite)", JSON.stringify(huge).replace("777777", "1e400").to_ascii_buffer()])
	for v: Variant in [-1, 2.5]:
		var d: Dictionary = good.duplicate(true)
		var slots: Array = d["slots"]
		var sword: Dictionary = slots[3]
		sword["durability"] = v
		refused.append(["the sword's durability = %s" % JSON.stringify(v), JSON.stringify(d).to_ascii_buffer()])
	var stack_not: Dictionary = good.duplicate(true)
	var stack_slots: Array = stack_not["slots"]
	stack_slots[1] = 5
	refused.append(["a slot that is no stack", JSON.stringify(stack_not).to_ascii_buffer()])
	var many: Dictionary = good.duplicate(true)
	var many_slots: Array = many["slots"]
	while many_slots.size() <= Config.INVENTORY_SLOTS:
		many_slots.append(null)
	refused.append(["%d slots" % many_slots.size(), JSON.stringify(many).to_ascii_buffer()])
	for row: Array in refused:
		var label: String = row[0]
		var b: PackedByteArray = row[1]
		var got: CharacterSave.Result = CharacterSave.read(b)
		check(not got.ok() and got.character == null, "character file %s: refused (%s)" % [label, got.error])
	var over: Dictionary = good.duplicate(true)
	var over_slots: Array = over["slots"]
	var over_money: Dictionary = over_slots[0]
	over_money["count"] = 0
	check(CharacterSave.read(JSON.stringify(over).to_ascii_buffer()).error.contains("count must be a whole number 1..250"),
		"the reason names the stack's limit (money 0: count must be a whole number 1..250)")
	_check_character_fitting(good)
	note("character file: %d refusals, e.g. '%s'" % [refused.size(), CharacterSave.read("[1, 2]".to_ascii_buffer()).error])
	# The backup when the file does not load.
	var path: String = _dir.path_join("characters/hand.json")
	_write(path, junk)
	_write(path + ".bak", CharacterSave.encode(c))
	var from_bak: CharacterSave.Result = CharacterSave.load_from(path)
	check(from_bak.ok() and from_bak.path == path + ".bak" and from_bak.skipped.contains("hand.json:"),
		"a broken character file and a good backup: the backup loads, the reason kept (%s)" % from_bak.skipped)
	_write(path + ".bak", junk)
	var none: CharacterSave.Result = CharacterSave.load_from(path)
	check(not none.ok() and none.error.contains("hand.json:") and none.error.contains("hand.json.bak:"), "nothing loads: every file's reason")
	check_eq(CharacterSave.load_from(_dir.path_join("characters/nobody.json")).error, "missing", "no file: missing")


## M13 review: what a tuned 임시값 (a stack's size, an item's durability) or a hand edit leaves past this build's limits is fitted, not refused:
## the count cut to its stack, the durability to full, each noted (Result.fitted); this build never writes such a file (Main's write guard).
## And the collection: a character's carried history (its `seen`, what it holds) registers nothing in a world (● game-concept §4).
func _check_character_fitting(good: Dictionary) -> void:
	var over: Dictionary = good.duplicate(true)
	var slots: Array = over["slots"]
	var money: Dictionary = slots[0]
	money["count"] = 251
	var sword: Dictionary = slots[3]
	sword["durability"] = 999
	var armor: Dictionary = over["armor"]
	armor["durability"] = 5000
	var r: CharacterSave.Result = CharacterSave.read(JSON.stringify(over).to_ascii_buffer())
	if not check(r.ok(), "a character past this build's limits loads: %s" % r.error):
		return
	check(r.character.stacks[0].count == 250 and r.character.stacks[3].durability == ItemDB.get_def(&"sword_t1").durability
		and r.character.armor.durability == ItemDB.get_def(&"armor_t1").durability, "cut: money to 250, the sword and the armour to full")
	var notes: String = " | ".join(r.fitted)
	check(r.fitted.size() == 3 and notes.contains("money count 251 cut to its stack's 250") and notes.contains("sword_t1 durability 999")
		and notes.contains("armor_t1 durability 5000"), "each cut noted (%s)" % notes)
	check(CharacterSave.read(CharacterSave.encode(r.character)).fitted.is_empty(), "written again it reads exactly")
	check(CharacterSave.read(JSON.stringify(good).to_ascii_buffer()).fitted.is_empty(), "a file within the limits: nothing fitted")
	# The collection reads what came into the inventory in its world, not the character's history.
	var vet: CharacterSave.Sheet = CharacterSave.Sheet.new()
	vet.class_id = "archer"
	vet.stacks[0] = ItemStack.new(&"hide_fine", 1, ItemDB.Grade.NONE)
	vet.seen.assign([&"hide_fine", Config.RARE_MATERIAL])
	var inv: Inventory = Inventory.new()
	vet.to_inventory(inv)
	var col: Collection = Collection.new()
	col.note_inventory(inv)
	check(col.count() == 0 and inv.has_seen(Config.RARE_MATERIAL), "a veteran's carried hide and seen history register nothing (its recipes stay)")
	inv.add(Config.RARE_MATERIAL, 1)
	col.note_inventory(inv)
	check(col.has(&"first_rare_essence") and col.count() == 1, "the rare material gained here registers its entry")
