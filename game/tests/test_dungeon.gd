extends "res://tests/base_test.gd"
## M3a maps and the first dungeon: the dungeon TileSet (fresh build = committed, every cliff tile with
## its corners and context), DungeonGen rules over many seeds (bedrock border, exit stairs on wall
## faces under bedrock, arrival point open next to them, the shrine spot reachable, every ore vein
## minable from where players walk, all floor connected, wall torches on faced rock), determinism and
## the golden hash, the surface entrance (step 5: clear spot outside the light, gatherables as in
## M2b), the cave view (every display cell = the rule, incremental redraws = a fresh view), wall
## collision (walls and faces block, a torch does not; prediction replays the host exactly in the
## dungeon), the darkness, and travelling between maps in main.tscn (F on the entrance / exit) plus
## (M3b) a session host taking a member down and up (the full map checks are in test_net_maps.gd).

const TestWorld := preload("res://tests/test_world.gd")
const SEEDS: int = 40


func run() -> Array[String]:
	_check_tileset()
	_check_generator_rules()
	_check_determinism()
	_check_surface_entrance()
	_check_cave_view()
	_check_collision()
	_check_prediction_in_dungeon()
	await _check_world_scene()
	await _check_travel_in_main()
	_check_session_travel()
	return failures


# --- tileset ---------------------------------------------------------------------------------

func _check_tileset() -> void:
	var built: TileSet = TilesetBuilder.build_dungeon()
	if not check(built != null, "dungeon tileset builds from art/tiles"):
		return
	var tmp: String = "user://dungeon_rebuild_check.tres"
	check_eq(ResourceSaver.save(built, tmp), OK, "fresh build saves")
	var fresh: String = TestWorld.normalize_ext_ids(FileAccess.get_file_as_string(tmp))
	var committed: String = TestWorld.normalize_ext_ids(FileAccess.get_file_as_string(TilesetBuilder.DUNGEON_PATH))
	check(committed.length() > 1000, "committed %s is readable" % TilesetBuilder.DUNGEON_PATH)
	check_eq(fresh.md5_text(), committed.md5_text(), "fresh build = committed %s (run tools/build_tileset.gd and commit)" %
		TilesetBuilder.DUNGEON_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	var table: CaveTable = CaveView.cave_table()
	check_eq(table.exact_keys, 21, "the cliff set covers 21 corner keys")
	var map: Dictionary[String, int] = {"lower": Walls.V_FLOOR, "upper": Walls.V_WALL, "transition": Walls.V_FACE}
	var infos: Array[TilesetBuilder.WangTileInfo] = TilesetBuilder.read_pixellab(TilesetBuilder.ART_DIR + TilesetBuilder.DUNGEON_JSON, map)
	check_eq(infos.size(), 25, "25 cliff tiles in the JSON")
	var ts: TileSet = load(TilesetBuilder.DUNGEON_PATH) as TileSet
	var source: TileSetAtlasSource = ts.get_source(TilesetBuilder.SRC_DUNGEON) as TileSetAtlasSource
	var ok: int = 0
	var with_context: int = 0
	for info: TilesetBuilder.WangTileInfo in infos:
		var td: TileData = source.get_tile_data(info.rect.position / Config.TILE, 0)
		if td != null and td.get_custom_data(TilesetBuilder.DATA_CORNERS) == info.corners \
				and td.get_custom_data(TilesetBuilder.DATA_CONTEXT) == info.context:
			ok += 1
		for v: int in info.context:
			if v != TilesetBuilder.CONTEXT_ANY:
				with_context += 1
				break
	check_eq(ok, 25, "every cliff tile is in the set at its box with its corners and context")
	check(with_context >= 8, "the JSON's pattern context was read (%d tiles have some)" % with_context)
	# The two tiles of key LULU (floor west, wall east): t1_10 where the wall's top ends above, t1_4 else.
	var lulu: int = CaveTable.key_of(Walls.V_FLOOR, Walls.V_WALL, Walls.V_FLOOR, Walls.V_WALL)
	var top_end: CaveTable.Candidate = table.pick(lulu, PackedByteArray([0, 0, 1, 1]), Vector2i(3, 3))
	var plain: CaveTable.Candidate = table.pick(lulu, PackedByteArray([1, 1, 1, 1]), Vector2i(3, 3))
	check(top_end != null and plain != null and top_end.coords == Vector2i(3, 3) and plain.coords == Vector2i(3, 4),
		"context picks t1_10 at a wall's top end, t1_4 along it")
	# A key the set lacks (a face right above a wall top) is drawn with a near key.
	var gap: int = CaveTable.key_of(Walls.V_FACE, Walls.V_FACE, Walls.V_WALL, Walls.V_WALL)
	check(not table.is_exact(gap) and table.pick(gap, PackedByteArray([1, 1, 1, 1]), Vector2i.ZERO) != null,
		"a missing key falls back to a near one")


# --- generator -------------------------------------------------------------------------------

func _check_generator_rules() -> void:
	var bad: Dictionary[String, int] = {}
	var fallbacks: int = 0
	var notes_kept: PackedStringArray = []
	var view: CaveView = add_node(CaveView.new()) as CaveView
	for seed: int in range(1, SEEDS + 1):
		var built: Array = DungeonGen.build(seed)
		var d: WorldData = built[0]
		var lay: DungeonGen.Layout = built[1]
		_count(bad, "size / map id", d.size != Config.DUNGEON_SIZE or d.map_id != Config.MAP_DUNGEON)
		_count(bad, "rooms", lay.rooms.size() < 4)
		var b: int = Config.DUNGEON_BORDER_TILES
		var border_ok: bool = true
		for y: int in d.size.y:
			for x: int in d.size.x:
				var edge: bool = x < b or y < b or x >= d.size.x - b or y >= d.size.y - b
				if edge and (Walls.kind_at(d, Vector2i(x, y)) != Walls.KIND_BEDROCK or Walls.hardness(d, Vector2i(x, y)) != Walls.UNBREAKABLE):
					border_ok = false
		_count(bad, "bedrock border", not border_ok)
		var exit: Rect2i = DungeonGen.exit_rect(d)
		var exit_ok: bool = exit.size == Config.EXIT_FOOTPRINT
		for x: int in range(exit.position.x, exit.end.x):
			var c: Vector2i = Vector2i(x, exit.position.y)
			exit_ok = exit_ok and Walls.is_face(d, c) and Walls.hardness(d, c + Vector2i(0, -1)) == Walls.UNBREAKABLE
		_count(bad, "exit on faces under unbreakable rock", not exit_ok)
		var arrival: Vector2 = DungeonGen.arrival_point(d)
		var a_cell: Vector2i = Aim.feet_cell(arrival)
		_count(bad, "arrival open", not Movement.can_stand(d, arrival) or Walls.blocks(d, a_cell))
		_count(bad, "arrival next to the exit", a_cell.y != exit.end.y or not (a_cell.x >= exit.position.x - 1 and a_cell.x <= exit.end.x))
		var standing: Dictionary[Vector2i, bool] = DungeonGen.reachable(d, a_cell)
		var shrine: Rect2i = DungeonGen.shrine_rect(d)
		var shrine_ok: bool = shrine.size == Config.SHRINE_FOOTPRINT
		var shrine_reached: bool = false
		for y: int in range(shrine.position.y, shrine.end.y):
			for x: int in range(shrine.position.x, shrine.end.x):
				shrine_ok = shrine_ok and not Walls.blocks(d, Vector2i(x, y))
		for c: Vector2i in standing:
			if shrine.grow(1).has_point(c):
				shrine_reached = true
		_count(bad, "shrine spot on open floor", not shrine_ok)
		_count(bad, "shrine reachable from the arrival", not shrine_reached)
		# Every open floor tile is reachable (no sealed pockets).
		var open_tiles: int = 0
		for y: int in d.size.y:
			for x: int in d.size.x:
				if not Movement.is_blocked(d, Vector2i(x, y)):
					open_tiles += 1
		_count(bad, "all open floor connected", open_tiles != standing.size())
		# Ore veins: in breakable rock, every vein minable from where players walk, both kinds present.
		var veins: Array[Array] = _veins(d)
		var kinds: Dictionary[int, bool] = {}
		var vein_ok: bool = true
		for vein: Array in veins:
			var reachable_vein: bool = false
			for item: Variant in vein:
				var c: Vector2i = item
				kinds[Walls.ore_at(d, c)] = true
				vein_ok = vein_ok and Walls.kind_at(d, c) == Walls.KIND_ROCK and Walls.max_hits(d, c) > 0
				if DungeonGen.minable_from(d, c, standing):
					reachable_vein = true
			vein_ok = vein_ok and reachable_vein
		_count(bad, "ore veins in rock, each minable from reachable floor", not vein_ok)
		_count(bad, "both ore kinds", not (kinds.has(Walls.ORE_COPPER) and kinds.has(Walls.ORE_IRON)))
		var torch_ok: bool = true
		var torches: int = 0
		var grid: PackedByteArray = d.layers[WorldData.Layer.PLACEABLE]
		for i: int in grid.size():
			if grid[i] == WorldData.PLACEABLE_WALL_TORCH:
				torches += 1
				var c: Vector2i = Vector2i(i % d.size.x, i / d.size.x)
				torch_ok = torch_ok and Walls.kind_at(d, c) == Walls.KIND_ROCK and Walls.is_face(d, c + Vector2i(0, 1)) \
					and Walls.ore_at(d, c) == Walls.ORE_NONE
		_count(bad, "wall torches on faced rock (at least 2)", not torch_ok or torches < 2)
		_count(bad, "floor layer unused", d.count_value(WorldData.Layer.FLOOR, 0) != d.size.x * d.size.y)
		view.setup(d)
		var v: Dictionary[String, int] = view.verify()
		_count(bad, "cave view = rule (no mismatch, nothing missing, overlays)", v["mismatches"] + v["missing"] + v["overlay_mismatches"] != 0)
		fallbacks += v["fallbacks"]
		if seed <= 3:
			notes_kept.append("seed %d: %d rooms, %d ore tiles, %d wall torches, %d open tiles" % [seed, lay.rooms.size(),
				Walls.ore_cells(d).size(), torches, standing.size()])
	for rule: String in ["size / map id", "rooms", "bedrock border", "exit on faces under unbreakable rock", "arrival open",
			"arrival next to the exit", "shrine spot on open floor", "shrine reachable from the arrival", "all open floor connected",
			"ore veins in rock, each minable from reachable floor", "both ore kinds", "wall torches on faced rock (at least 2)",
			"floor layer unused", "cave view = rule (no mismatch, nothing missing, overlays)"]:
		check_eq(bad.get(rule, 0), 0, "%d seeds: %s" % [SEEDS, rule])
	check(fallbacks <= SEEDS, "generated dungeons rarely need a fallback tile (%d display cells in %d seeds)" % [fallbacks, SEEDS])
	note("dungeon rules over %d seeds; fallback display cells in all: %d" % [SEEDS, fallbacks])
	for line: String in notes_kept:
		note(line)


static func _count(bad: Dictionary[String, int], rule: String, broken: bool) -> void:
	var n: int = bad.get(rule, 0)
	bad[rule] = n + (1 if broken else 0)


## Ore tiles grouped into veins (4-neighbour runs of the same ore).
static func _veins(d: WorldData) -> Array[Array]:
	var seen: Dictionary[Vector2i, bool] = {}
	var out: Array[Array] = []
	for c: Vector2i in Walls.ore_cells(d):
		if seen.has(c):
			continue
		var vein: Array[Vector2i] = [c]
		seen[c] = true
		var i: int = 0
		while i < vein.size():
			for step: Vector2i in DungeonGen.STEPS:
				var n: Vector2i = vein[i] + step
				if not seen.has(n) and Walls.ore_at(d, n) == Walls.ore_at(d, c):
					seen[n] = true
					vein.append(n)
			i += 1
		out.append(vein)
	return out


func _check_determinism() -> void:
	var a: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var b: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check_eq(a.content_hash(), b.content_hash(), "same seed, same dungeon")
	check_ne(a.content_hash(), DungeonGen.generate(Config.DEFAULT_SEED + 1).content_hash(), "another seed, another dungeon")
	check_eq(a.content_hash(), DungeonGen.GOLDEN_HASH, "seed %d dungeon unchanged (update DungeonGen.GOLDEN_HASH on purpose)" %
		Config.DEFAULT_SEED)
	check_ne(a.content_hash(), SurfaceGen.generate(Config.DEFAULT_SEED).content_hash(), "the dungeon is not the surface")
	check_eq(DungeonGen.seeds_digest(), DungeonGen.SEEDS_GOLDEN, "M3b: the dungeons of seeds 1..%d unchanged (DungeonGen.SEEDS_GOLDEN, --smoke)" %
		DungeonGen.SEEDS_DIGEST_COUNT)


func _check_surface_entrance() -> void:
	var bad: int = 0
	for seed: int in range(1, SEEDS + 1):
		var s: WorldData = SurfaceGen.generate(seed)
		var e: Rect2i = SurfaceGen.entrance_rect(s)
		if e.size != Config.ENTRANCE_FOOTPRINT or s.footprints(WorldData.PLACEABLE_ENTRANCE).size() != 1:
			bad += 1
			continue
		var return_point: Vector2 = DungeonGen.arrival_below(e)
		if not Movement.can_stand(s, return_point) or SafeZone.for_world(s).is_in_safe_zone(Vector2(e.get_center() * Config.TILE)):
			bad += 1
		for y: int in range(e.position.y, e.end.y):
			for x: int in range(e.position.x, e.end.x):
				if not Movement.is_blocked(s, Vector2i(x, y)):
					bad += 1
	check_eq(bad, 0, "%d seeds: one entrance, blocked, outside the light, open ground south of it" % SEEDS)
	var s1: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	check_eq(SurfaceGen.entrance_rect(s1).position, s1.altar_rect.position + Config.ENTRANCE_OFFSET_TILES,
		"seed 1: the entrance is at its preferred spot")
	check_eq(WorldItems.gatherable_cells(s1).size(), 74, "seed 1: the gatherables are as in M2b (74)")
	check(not WorldItems.in_reach(Vector2(1016, 760), SurfaceGen.entrance_rect(s1).position), "not next to the altar")


# --- cave view -------------------------------------------------------------------------------

func _check_cave_view() -> void:
	DungeonGen.generate(Config.DEFAULT_SEED)  # warm-up
	var t0: int = Time.get_ticks_usec()
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var gen_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var view: CaveView = add_node(CaveView.new()) as CaveView
	var t1: int = Time.get_ticks_usec()
	view.setup(d)
	var view_ms: float = (Time.get_ticks_usec() - t1) / 1000.0
	note("seed 1 dungeon: generate %.1f ms, cave view setup %.1f ms (headless)" % [gen_ms, view_ms])
	var v: Dictionary[String, int] = view.verify()
	check(v["missing"] == 0 and v["mismatches"] == 0 and v["overlay_mismatches"] == 0 and v["cells"] == 65 * 49,
		"seed 1 cave: every display cell drawn by the rule %s" % v)
	check_eq(view.ores.size(), Walls.ore_cells(d).size(), "an ore overlay per ore tile")
	# Random edits (breaking and damaging walls next to open floor), each redrawn in place: the view
	# must equal a fresh one of the same data.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 33
	var walls: Array[Vector2i] = []
	for c: Vector2i in Walls.wall_cells(d):
		if Walls.kind_at(d, c) == Walls.KIND_ROCK:
			walls.append(c)
	for i: int in 120:
		var c: Vector2i = walls[rng.randi_range(0, walls.size() - 1)]
		if not Walls.is_wall(d, c):
			continue
		if rng.randf() < 0.5:
			d.set_value(WorldData.Layer.WALL, c, 0)
			d.set_value(WorldData.Layer.ORE, c, 0)
		else:
			d.set_value(WorldData.Layer.WALL, c, Walls.pack(Walls.KIND_ROCK, rng.randi_range(1, Config.WALL_HITS_ROCK - 1)))
		view.redraw_wall(c)
	var fresh: CaveView = add_node(CaveView.new()) as CaveView
	fresh.setup(d)
	check_eq(view.view_hash(), fresh.view_hash(), "120 edits redrawn in place = a fresh view")
	var v2: Dictionary[String, int] = view.verify()
	check(v2["mismatches"] == 0 and v2["missing"] == 0 and v2["overlay_mismatches"] == 0, "after the edits %s" % v2)
	note("cave view seed 1: %d display cells, %d ore overlays; after 120 random edits %d fallback cells" % [v["cells"],
		view.ores.size(), v2["fallbacks"]])
	# Dense edits on a small cave (walls broken, damaged and put back, every shape the context-picked
	# tiles care about): every 25 edits redrawn in place must equal a fresh view.
	var small: WorldData = _cave(Vector2i(16, 14), [Rect2i(3, 3, 10, 8)])
	var sv: CaveView = add_node(CaveView.new()) as CaveView
	sv.setup(small)
	var differ: int = 0
	for i: int in 800:
		var c: Vector2i = Vector2i(rng.randi_range(2, 13), rng.randi_range(2, 11))
		var roll: float = rng.randf()
		if roll < 0.4:
			small.set_value(WorldData.Layer.WALL, c, 0)
		elif roll < 0.7:
			small.set_value(WorldData.Layer.WALL, c, Walls.pack(Walls.KIND_ROCK, 0))
		else:
			small.set_value(WorldData.Layer.WALL, c, Walls.pack(Walls.KIND_ROCK, rng.randi_range(1, Config.WALL_HITS_ROCK - 1)))
		sv.redraw_wall(c)
		if i % 25 == 24:
			var again: CaveView = CaveView.new()
			add_node(again)
			again.setup(small)
			if again.view_hash() != sv.view_hash():
				differ += 1
			again.get_parent().remove_child(again)
			again.free()
	check_eq(differ, 0, "800 dense edits on a small cave: redrawn in place = fresh, at all 32 checkpoints")


# --- collision -------------------------------------------------------------------------------

## A small hand-made cave: bedrock ring, rock inside, `open` rects carved.
static func _cave(size: Vector2i, open: Array[Rect2i]) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_DUNGEON
	for y: int in size.y:
		for x: int in size.x:
			var edge: bool = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			d.set_value(WorldData.Layer.WALL, Vector2i(x, y), Walls.pack(Walls.KIND_BEDROCK if edge else Walls.KIND_ROCK, 0))
	for r: Rect2i in open:
		for y: int in range(r.position.y, r.end.y):
			for x: int in range(r.position.x, r.end.x):
				d.set_value(WorldData.Layer.WALL, Vector2i(x, y), 0)
	return d


func _check_collision() -> void:
	# Room x 3..10, y 3..8: its top row (y 3) is the north wall's face.
	var d: WorldData = _cave(Vector2i(14, 12), [Rect2i(3, 3, 8, 6)])
	check(Movement.is_blocked(d, Vector2i(2, 5)) and Movement.is_blocked(d, Vector2i(5, 2)), "walls block")
	check(Movement.is_blocked(d, Vector2i(5, 3)) and Walls.is_face(d, Vector2i(5, 3)), "the face tile under a wall blocks")
	check(not Movement.is_blocked(d, Vector2i(5, 4)), "the tile below the face is open")
	var start: Vector2 = Vector2(5.5 * 16, 6.5 * 16)
	var p: Vector2 = start
	for i: int in 200:
		p = Movement.step(d, p, Vector2i(0, -1), Config.NET_TICK)
	check_eq(p.y, 4.0 * 16 + Config.FEET_HEIGHT, "walking north stops flush below the face (feet box top on the face's bottom edge)")
	p = start
	for i: int in 200:
		p = Movement.step(d, p, Vector2i(-1, 0), Config.NET_TICK)
	check_eq(p.x, 3.0 * 16 + Config.FEET_HALF_WIDTH, "walking west stops flush at the wall")
	p = start
	for i: int in 200:
		p = Movement.step(d, p, Vector2i(1, 1), Config.NET_TICK)
	check(p.x == 11.0 * 16 - Config.FEET_HALF_WIDTH and p.y == 9.0 * 16, "a diagonal slides into the corner (%s)" % p)
	# A torch does not block; breaking the wall above the face opens the face tile (it is a plain floor
	# tile again once nothing hangs over it).
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(6, 6), WorldData.PLACEABLE_TORCH)
	check(not Movement.is_blocked(d, Vector2i(6, 6)), "a placed torch does not block")
	d.set_value(WorldData.Layer.WALL, Vector2i(5, 2), 0)
	check(Walls.is_face(d, Vector2i(5, 2)) and not Walls.is_face(d, Vector2i(5, 3)) and not Movement.is_blocked(d, Vector2i(5, 3)),
		"mining the wall above a face moves the face up a tile")


## The client's prediction against the host's PlayerSim in the dungeon: random walking into walls and
## faces, replayed from host states with a delay: no correction ever.
func _check_prediction_in_dungeon() -> void:
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var start: Vector2 = DungeonGen.arrival_point(d)
	var host: PlayerSim = PlayerSim.new()
	host.pos = start
	var client: Prediction = Prediction.new()
	client.setup(d, start, RigData.Dir.SOUTH, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var queue: Array[Array] = []
	var dir: Vector2i = Vector2i.ZERO
	var blocked_steps: int = 0
	var seq: int = 0
	for t: int in 1500:
		if t % 30 == 0:
			dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, dir)
		var sent: NetProtocol.InputFrame = client.step_frame(f)
		if sent != null:
			seq = sent.seq
			var before: Vector2 = host.pos
			host.step(d, sent.dir, sent.look, -1, Vector2i.ZERO, Config.NET_TICK)
			if dir != Vector2i.ZERO and host.pos.distance_to(before) < 1.0:
				blocked_steps += 1
			var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
			st.pos = host.pos
			st.facing = host.facing
			st.walking = host.walking
			st.ack = seq
			st.map = Config.MAP_DUNGEON
			queue.append([t + 6, st])
		while not queue.is_empty() and _due(queue) <= t:
			var item: Array = queue.pop_front()
			var state: NetProtocol.PlayerState = item[1]
			client.reconcile(state)
	check(blocked_steps > 50, "the walk ran into walls and faces (%d blocked steps)" % blocked_steps)
	check_eq(client.max_error_px, 0.0, "prediction = host in the dungeon (never corrected)")
	check(Movement.can_stand(d, host.pos), "the host's player never stood in a wall")


# --- scenes ----------------------------------------------------------------------------------

func _check_world_scene() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = Config.MAP_DUNGEON
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	check(w.cave != null and w.data.map_id == Config.MAP_DUNGEON and w.altar == null, "a dungeon world: cave view, no altar")
	check_eq(w.lighting.evening.color, Config.DUNGEON_DARK_COLOR, "the dungeon is dark")
	check(not w.lighting.altar_light.is_lit(), "no altar light in the dungeon")
	check(not w.is_in_safe_zone(w.arrival_point()), "nowhere in the dungeon is the safe zone")
	var fx: Dictionary[String, int] = w.fixtures.verify()
	check(fx["mismatches"] == 0 and fx["lights"] == fx["torches"] and fx["torches"] >= 2, "exit, shrine and wall torches drawn %s" % fx)
	check(w.fixtures.nodes.has(DungeonGen.exit_rect(w.data).position) and w.fixtures.nodes.has(DungeonGen.shrine_rect(w.data).position),
		"the exit stairs and the shrine are in the entities")
	check_eq(w.lighting.torches.get_child_count(), fx["torches"], "a light per wall torch under Lighting/Torches")
	w.lighting.set_evening(false)
	check(not w.lighting.torches.visible, "F4 turns the torch lights off with the darkness")
	w.lighting.set_evening(true)
	var s: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	s.auto_generate = false
	s.free_camera = false
	add_node(s)
	s.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	check(s.cave == null and s.fixtures.nodes.has(SurfaceGen.entrance_rect(s.data).position), "the surface draws its entrance")
	check_eq(s.decals.get_child_count(), 1, "and the entrance's debris as a ground decal")
	check(s.decals.get_index() < s.entities.get_index(), "decals under the entities")


func _check_travel_in_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	check(main.worlds.size() == 2 and main.worlds[Config.MAP_DUNGEON].visible == false, "offline: two maps, the dungeon hidden")
	var player: Player = main.player
	var surface: GameWorld = main.world
	var dungeon: GameWorld = main.worlds[Config.MAP_DUNGEON]
	var entrance: Rect2i = SurfaceGen.entrance_rect(surface.data)
	player.teleport(DungeonGen.arrival_below(entrance))
	player.test_aim = Vector2(0, -16)
	await _physics(2)
	check(WorldItems.is_portal(surface.data, player.aim_cell), "aiming at the entrance")
	_press(&"interact")
	await _physics(2)
	check_eq(main.current_map, Config.MAP_DUNGEON, "F on the entrance goes down")
	check(player.get_parent() == dungeon.entities and player.data == dungeon.data, "the player is in the dungeon's world")
	check_eq(player.sim_position, dungeon.arrival_point(), "at the arrival point")
	check(dungeon.visible and not surface.visible, "the dungeon shown, the surface hidden")
	check(main.marker.get_parent() == dungeon and main.marker.map_cells == dungeon.data.size, "the marker moved along")
	check_eq(main.camera.bounds, dungeon.map_rect_px(), "the camera keeps to the dungeon")
	check(main.dummies.size() == 4 and main.dummies[0].get_parent() == surface.entities, "the dummies stay on the surface")
	var p: Vector2 = player.sim_position
	await _physics(2)
	check(WorldItems.is_portal(dungeon.data, player.aim_cell), "the exit stairs are right north of the arrival point")
	_press(&"interact")
	await _physics(2)
	check_eq(main.current_map, Config.MAP_SURFACE, "F on the exit stairs goes up")
	check(player.get_parent() == surface.entities and player.data == surface.data and surface.visible and not dungeon.visible,
		"back in the surface's world")
	check_eq(player.sim_position, DungeonGen.arrival_below(entrance), "just south of the entrance")
	check_ne(p, player.sim_position, "moved")


## M3b: a session host takes a member down the entrance (TRAVEL) and back up the stairs; a PICKUP on
## the entrance is no travel ("a way to another map").
func _check_session_travel() -> void:
	var surface: GameWorld = _world_node(Config.MAP_SURFACE)
	var dungeon: GameWorld = _world_node(Config.MAP_DUNGEON)
	var s: NetSession = NetSession.new()
	s.name = &"TestNet"
	add_node(s)
	s.world = surface
	s.worlds = {Config.MAP_SURFACE: surface, Config.MAP_DUNGEON: dungeon}
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHost.new(s)
	s.host = host
	var e: Rect2i = SurfaceGen.entrance_rect(surface.data)
	var m: NetMember = s.add_member(1, 7, "miner", DungeonGen.arrival_below(e), RigData.Dir.NORTH)
	m.gate = InputGate.new()
	var pick: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	pick.op = NetProtocol.Op.PICKUP
	pick.cell = e.position
	host.run_frame(m, pick)
	check_eq(m.ops_refused.get(WorldItems.WHY_PORTAL, 0), 1, "a PICKUP on the entrance is no travel (%s)" % m.ops_refused)
	var down: NetProtocol.InputFrame = NetProtocol.InputFrame.new(2, Vector2i.ZERO)
	down.op = NetProtocol.Op.TRAVEL
	down.cell = e.position
	host.run_frame(m, down)
	check(m.map_id == Config.MAP_DUNGEON and m.player.data == dungeon.data and m.player.get_parent() == dungeon.entities
		and m.player.sim_position == dungeon.arrival_point(), "TRAVEL on the entrance: the member is at the dungeon's arrival point")
	check(host.streams.has(7) and host.streams[7].entry and host.streams[7].map == Config.MAP_DUNGEON,
		"and its client is being sent the dungeon")
	host.streams.clear()
	for t: int in Config.NET_OP_INTERVAL_TICKS:
		m.refill_ops()
	var up: NetProtocol.InputFrame = NetProtocol.InputFrame.new(3, Vector2i.ZERO)
	up.op = NetProtocol.Op.TRAVEL
	up.map = Config.MAP_DUNGEON
	up.cell = DungeonGen.exit_rect(dungeon.data).position
	host.run_frame(m, up)
	check(m.map_id == Config.MAP_SURFACE and m.player.sim_position == surface.arrival_point(), "TRAVEL on the stairs: back south of the entrance")
	check_eq(s.edit_log.size() + s.log_for(Config.MAP_DUNGEON).size(), 0, "travelling edits no map")


func _world_node(map: int) -> GameWorld:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = map
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	return w


static func _due(queue: Array[Array]) -> int:
	var t: int = queue[0][0]
	return t


func _physics(n: int) -> void:
	for i: int in n:
		await tree.physics_frame


static func _press(action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
