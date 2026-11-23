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
			var same: bool = px.size() >= 30 and py.size() >= 30 and px.slice(0, 8) == py.slice(0, 8) and px.slice(24, 30) == py.slice(24, 30)
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
	check(b.farms[Config.MAP_SURFACE].stat("grown") >= 0, "the farm ran")
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
	refused.append(_patched("a creature of no kind", sections, order, "HERD", 1 + 8 + 4 + 4 + 2 + 4 + 1, 0x5a))
	refused.append(_patched("a farm plot off the map", sections, order, "FRM0", 1 + 4 + 3, 0x7f))
	refused.append(_patched("a pillar past broken", sections, order, "BOSS", 1 + 8 + 4 + 1 + 4 + 4 + 1 + 1, 0x7f))
	refused.append(_patched("the shrine above its HP", sections, order, "ARN1", 1 + 8 + 4 + 4 + 3, 0x7f))
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
