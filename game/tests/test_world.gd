extends "res://tests/base_test.gd"
## World: tileset build = committed resource, Wang table, generator rules over many seeds,
## determinism, ground view corners / fallbacks / chunks, edits redraw exactly the expected cells,
## world.tscn (free camera), timings.

## Pinned seed-1 world hash (lives in the game code so --smoke can compare it too).
const GOLDEN_HASH: String = SurfaceGen.GOLDEN_HASH
const SEEDS: int = 40
const TIMING_RUNS: int = 3


func run() -> Array[String]:
	_check_tileset_is_reproducible()
	var table: WangTable = _check_wang_table()
	if table == null:
		return failures
	_check_generator_rules()
	_check_determinism(table)
	await _check_view(table)
	_check_fallbacks_are_counted(table)
	_check_edits(table)
	_check_chunk_boundary_edits(table)
	await _check_world_scene()
	_check_timings(table)
	return failures


func _check_tileset_is_reproducible() -> void:
	var built: TileSet = TilesetBuilder.build_surface()
	if not check(built != null, "tileset builds from art/tiles"):
		return
	var tmp: String = "user://surface_rebuild_check.tres"
	check_eq(ResourceSaver.save(built, tmp), OK, "fresh build saves")
	# ext_resource ids depend on the file the resource is saved to, so ids are replaced by paths.
	var fresh: String = normalize_ext_ids(FileAccess.get_file_as_string(tmp))
	var committed: String = normalize_ext_ids(FileAccess.get_file_as_string(TilesetBuilder.SURFACE_PATH))
	check(committed.length() > 1000, "committed %s is readable" % TilesetBuilder.SURFACE_PATH)
	if not check_eq(fresh.md5_text(), committed.md5_text(),
			"fresh build = committed %s (run tools/build_tileset.gd and commit)" % TilesetBuilder.SURFACE_PATH):
		var a: PackedStringArray = fresh.split("\n")
		var b: PackedStringArray = committed.split("\n")
		for i: int in mini(a.size(), b.size()):
			if a[i] != b[i]:
				fail("first difference at line %d: fresh '%s' vs committed '%s'" % [i + 1, a[i], b[i]])
				break
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	# Every Wang tile of both JSON files is in the committed set at its bounding box, with its corners
	# (except the all-grass tile of the second set, which the first set already has).
	var ts: TileSet = load(TilesetBuilder.SURFACE_PATH) as TileSet
	var sets: Array[Array] = [
		[TilesetBuilder.SRC_GRASS_SOIL, TilesetBuilder.GRASS_SOIL_JSON, Terrain.SOIL],
		[TilesetBuilder.SRC_GRASS_ASH, TilesetBuilder.GRASS_ASH_JSON, Terrain.ASH],
	]
	var all_grass: int = Terrain.key_of(Terrain.GRASS, Terrain.GRASS, Terrain.GRASS, Terrain.GRASS)
	for item: Array in sets:
		var source_id: int = item[0]
		var json: String = item[1]
		var lower: int = item[2]
		var map: Dictionary[String, int] = {"lower": lower, "upper": Terrain.GRASS}
		var tiles: Array[TilesetBuilder.WangTileInfo] = TilesetBuilder.read_pixellab(TilesetBuilder.ART_DIR + json, map)
		check_eq(tiles.size(), 16, "%s has 16 Wang tiles" % json)
		var source: TileSetAtlasSource = ts.get_source(source_id) as TileSetAtlasSource
		if not check(source != null, "source %d exists" % source_id):
			continue
		var keys: Dictionary[int, bool] = {}
		for info: TilesetBuilder.WangTileInfo in tiles:
			var key: int = Terrain.key_of_corners(info.corners)
			keys[key] = true
			var coords: Vector2i = info.rect.position / Config.TILE
			if source_id == TilesetBuilder.SRC_GRASS_ASH and key == all_grass:
				check(not source.has_tile(coords), "second all-grass tile is skipped")
				continue
			if not check(source.has_tile(coords), "%s %s at %s" % [json, info.name, coords]):
				continue
			check_eq(source.get_tile_data(coords, 0).get_custom_data(TilesetBuilder.DATA_CORNERS), info.corners,
				"%s %s corners" % [json, info.name])
		check_eq(keys.size(), 16, "%s covers all 16 two-terrain corner keys" % json)


func _check_wang_table() -> WangTable:
	var table: WangTable = GroundView.surface_table()
	if not check(table != null, "surface table loads"):
		return null
	check_eq(table.exact_keys, 31, "corner keys with art")
	check_eq(table.fallback_keys, 50, "corner keys without art (soil + ash mixes)")
	var expected_candidates: Dictionary[int, int] = {
		Terrain.key_of(0, 0, 0, 0): 1 + TilesetBuilder.GRASS_VARIANTS.size(),
		Terrain.key_of(1, 1, 1, 1): 1 + TilesetBuilder.SOIL_VARIANTS.size(),
		Terrain.key_of(2, 2, 2, 2): 1 + TilesetBuilder.ASH_VARIANTS.size(),
	}
	for key: int in Terrain.KEY_COUNT:
		var e: WangTable.KeyEntry = table.entries[key]
		check_eq(e.exact, Terrain.key_has_art(key), "key %d exact = has art" % key)
		if e.exact:
			check_eq(e.sources.size(), expected_candidates.get(key, 1), "key %d candidates" % key)
			for i: int in e.sources.size():
				var source: TileSetAtlasSource = table.tile_set.get_source(e.sources[i]) as TileSetAtlasSource
				var corners: PackedByteArray = source.get_tile_data(e.coords[i], 0).get_custom_data(
					TilesetBuilder.DATA_CORNERS)
				check_eq(Terrain.key_of_corners(corners), key, "key %d candidate %d corners" % [key, i])
		else:
			check(Terrain.key_has_art(e.resolved_key), "key %d falls back to a key with art" % key)
	# Variant pick: stable per cell, weighted (plain tile weight 1, each variant VARIANT_WEIGHT).
	var grass: int = Terrain.key_of(0, 0, 0, 0)
	var plain: int = 0
	var n: int = 0
	var unstable: int = 0
	for y: int in 100:
		for x: int in 100:
			var i: int = table.pick(grass, Vector2i(x, y))
			if i != table.pick(grass, Vector2i(x, y)):
				unstable += 1
			if i == 0:
				plain += 1
			n += 1
	check_eq(unstable, 0, "pick is stable per cell")
	var expected_plain: float = 1.0 / (1.0 + Config.VARIANT_WEIGHT * TilesetBuilder.GRASS_VARIANTS.size())
	check_between(float(plain) / n, expected_plain - 0.03, expected_plain + 0.03, "share of plain grass tiles")
	return table


## Generator rules over SEEDS seeds.
func _check_generator_rules() -> void:
	var radius: float = Config.safe_radius_px()
	var ash_min_px: float = radius + Config.ASH_CLEARANCE_TILES * Config.TILE
	var expected_altar: Rect2i = Rect2i((Config.MAP_SIZE - Config.ALTAR_FOOTPRINT) / 2, Config.ALTAR_FOOTPRINT)
	var soil_range: Vector2i = Vector2i(1 << 30, 0)
	var ash_range: Vector2i = Vector2i(1 << 30, 0)
	var bad: Dictionary[String, int] = {}
	for s: int in SEEDS:
		var data: WorldData = SurfaceGen.generate(s * 7919 + 3)
		var altar: Vector2 = data.altar_center_px()
		_count_if(bad, "size", data.size != Config.MAP_SIZE)
		_count_if(bad, "altar footprint", data.altar_rect != expected_altar)
		var soil: int = 0
		var ash: int = 0
		var zones: Dictionary[int, bool] = {}
		var gathered: Dictionary[StringName, int] = {}
		for y: int in data.size.y:
			for x: int in data.size.x:
				var c: Vector2i = Vector2i(x, y)
				var t: int = data.terrain_at(c)
				var zone: int = data.get_value(WorldData.Layer.CORRUPTION, c)
				var on_altar: bool = data.altar_rect.has_point(c)
				_count_if(bad, "placeable = altar exactly on the footprint",
					(data.get_value(WorldData.Layer.PLACEABLE, c) == WorldData.PLACEABLE_ALTAR) != on_altar)
				_count_if(bad, "altar footprint is grass", on_altar and t != Terrain.GRASS)
				_count_if(bad, "unused layers stay 0", data.get_value(WorldData.Layer.WALL, c) != 0
					or data.get_value(WorldData.Layer.ORE, c) != 0)
				# M2b gatherables (VEGETATION): the generator's spots only (SurfaceGen.gatherable_spot_ok
				# rules, checked here from scratch).
				var plant: StringName = WorldItems.gatherable_at(data, c)
				if not plant.is_empty():
					var seen: int = gathered.get(plant, 0)
					gathered[plant] = seen + 1
					var on_ash: bool = Config.GATHER_ON_ASH.has(plant)
					_count_if(bad, "gatherable on its ground (grass / ash)", t != (Terrain.ASH if on_ash else Terrain.GRASS))
					_count_if(bad, "gatherable not on the altar", on_altar)
					_count_if(bad, "gatherable outside the light + clearance", ((Vector2(c) + Vector2(0.5, 0.5)) *
						Config.TILE).distance_to(altar) < radius + Config.GATHER_CLEARANCE_TILES * Config.TILE)
					_count_if(bad, "gatherable at least 2 cells from the map edge", c.x < 2 or c.y < 2
						or c.x >= data.size.x - 2 or c.y >= data.size.y - 2)
					for oy: int in range(-1, 2):
						for ox: int in range(-1, 2):
							_count_if(bad, "no gatherable next to another", (ox != 0 or oy != 0)
								and data.get_value(WorldData.Layer.VEGETATION, c + Vector2i(ox, oy)) != 0)
				else:
					_count_if(bad, "VEGETATION holds gatherables only", data.get_value(WorldData.Layer.VEGETATION, c) != 0)
				_count_if(bad, "corruption zone <=> ash", (zone != 0) != (t == Terrain.ASH))
				if t == Terrain.SOIL:
					soil += 1
					_count_if(bad, "soil cell completely inside the safe radius",
						not SurfaceGen.rect_inside_radius(Rect2i(c, Vector2i.ONE), altar, radius))
					_count_if(bad, "soil off the altar walkway", data.altar_rect.grow(1).has_point(c))
					for oy: int in range(-1, 2):
						for ox: int in range(-1, 2):
							_count_if(bad, "soil vertex next to an ash vertex",
								data.terrain_at(c + Vector2i(ox, oy)) == Terrain.ASH)
				elif t == Terrain.ASH:
					ash += 1
					zones[zone] = true
					_count_if(bad, "ash cell outside safe radius + clearance",
						((Vector2(c) + Vector2(0.5, 0.5)) * Config.TILE).distance_to(altar) < ash_min_px)
					_count_if(bad, "zone id in 1..ASH_ZONE_COUNT", zone < 1 or zone > Config.ASH_ZONE_COUNT)
		_count_if(bad, "SOIL_PATCH_COUNT separate soil patches", count_regions(data, Terrain.SOIL) != Config.SOIL_PATCH_COUNT)
		_count_if(bad, "zone count = ASH_ZONE_COUNT (within 2..3)", zones.size() != Config.ASH_ZONE_COUNT)
		_count_if(bad, "soil_ash_contacts() = 0", data.soil_ash_contacts() != 0)
		for id: StringName in Config.GATHER_ON_GRASS:
			var n: int = gathered.get(id, 0)
			_count_if(bad, "every GATHER_ON_GRASS gatherable placed", n != Config.GATHER_ON_GRASS[id])
		for id: StringName in Config.GATHER_ON_ASH:
			var n2: int = gathered.get(id, 0)
			_count_if(bad, "every GATHER_ON_ASH gatherable placed", n2 != Config.GATHER_ON_ASH[id])
		_count_if(bad, "no other gatherable kinds", gathered.size() != Config.GATHER_ON_GRASS.size() + Config.GATHER_ON_ASH.size())
		soil_range = Vector2i(mini(soil_range.x, soil), maxi(soil_range.y, soil))
		ash_range = Vector2i(mini(ash_range.x, ash), maxi(ash_range.y, ash))
	check(Config.ASH_ZONE_COUNT >= 2 and Config.ASH_ZONE_COUNT <= 3, "ASH_ZONE_COUNT within the proposed 2..3 (○ game-concept §12)")
	for rule: String in bad:
		fail("generator rule broken in %d case(s): %s" % [bad[rule], rule])
	checks += 1
	note("generator over %d seeds: soil cells %d..%d, ash cells %d..%d, 0 rule violations expected (got %d kinds)" % [
		SEEDS, soil_range.x, soil_range.y, ash_range.x, ash_range.y, bad.size()])


## Number of 4-connected regions of `terrain` (soil patches never touch, so regions = patches).
static func count_regions(data: WorldData, terrain: int) -> int:
	var seen: Dictionary[Vector2i, bool] = {}
	var regions: int = 0
	for y: int in data.size.y:
		for x: int in data.size.x:
			var start: Vector2i = Vector2i(x, y)
			if seen.has(start) or data.terrain_at(start) != terrain:
				continue
			regions += 1
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + step
					if data.in_bounds(n) and not seen.has(n) and data.terrain_at(n) == terrain:
						seen[n] = true
						stack.append(n)
	return regions


## Replaces ext_resource ids with their paths: [ext_resource ... path="P" id="X"] -> ExtResource("P").
static func normalize_ext_ids(text: String) -> String:
	var re: RegEx = RegEx.create_from_string(r'\[ext_resource ([^\]]*)path="([^"]+)" id="([^"]+)"\]')
	var out: String = text
	for m: RegExMatch in re.search_all(text):
		out = out.replace(m.get_string(0), '[ext_resource %spath="%s"]' % [m.get_string(1), m.get_string(2)])
		out = out.replace('ExtResource("%s")' % m.get_string(3), 'ExtResource("%s")' % m.get_string(2))
	return out


func _count_if(bad: Dictionary[String, int], rule: String, broken: bool) -> void:
	if broken:
		bad[rule] = bad.get(rule, 0) + 1


func _check_determinism(table: WangTable) -> void:
	var a: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var b: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var c: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED + 1)
	check_eq(a.content_hash(), b.content_hash(), "same seed -> same world hash")
	check_ne(a.content_hash(), c.content_hash(), "different seed -> different world hash")
	for layer: int in WorldData.LAYER_COUNT:
		check_eq(a.layers[layer], b.layers[layer], "same seed -> same %s layer" % WorldData.LAYER_NAMES[layer])
	var differing: int = 0
	for s: int in range(1, 11):
		if SurfaceGen.generate(s).content_hash() != SurfaceGen.generate(s + 1000).content_hash():
			differing += 1
	check_eq(differing, 10, "10 seed pairs give 10 different worlds")
	var va: GroundView = GroundView.new()
	var vb: GroundView = GroundView.new()
	va.setup(a, table)
	vb.setup(b, table)
	check_eq(va.view_hash(), vb.view_hash(), "same seed -> same drawn tiles")
	va.free()
	vb.free()
	if GOLDEN_HASH.is_empty():
		note("golden hash for seed %d: %s (not pinned yet)" % [Config.DEFAULT_SEED, a.content_hash()])
	else:
		check_eq(a.content_hash(), GOLDEN_HASH, "seed %d world unchanged (update SurfaceGen.GOLDEN_HASH on purpose)" %
			Config.DEFAULT_SEED)


func _check_view(table: WangTable) -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var view: GroundView = add_node(GroundView.new()) as GroundView
	view.setup(data, table)
	await await_frames(1)
	var v: Dictionary[String, int] = view.verify()
	var cells: int = (data.size.x + 1) * (data.size.y + 1)
	check_eq(v["cells"], cells, "display cells = (W+1)(H+1)")
	check_eq(v["missing"], 0, "every display cell drawn")
	check_eq(v["mismatches"], 0, "every drawn cell's corners = its vertices")
	check_eq(v["fallbacks"], 0, "no fallback tiles on a generated map")
	check_eq(view.cells_written, cells, "setup draws each display cell once")

	# Chunks: the expected set, positions, local coordinates, and each tile at its world position.
	var r: Rect2i = view.display_rect()
	var c0: Vector2i = GroundView.chunk_of(r.position)
	var c1: Vector2i = GroundView.chunk_of(r.end - Vector2i.ONE)
	var expected: Array[Vector2i] = []
	for cy: int in range(c0.y, c1.y + 1):
		for cx: int in range(c0.x, c1.x + 1):
			expected.append(Vector2i(cx, cy))
	expected.sort()
	check_eq(view.chunk_keys(), expected, "chunk set covers the display rect")
	check_eq(GroundView.chunk_of(Vector2i(-1, -1)), Vector2i(-1, -1), "chunk_of floors negatives")
	check_eq(GroundView.chunk_of(Vector2i(31, 32)), Vector2i(0, 1), "chunk_of at a boundary")
	var used: int = 0
	var misplaced: int = 0
	for chunk: Vector2i in view.chunk_keys():
		var layer: TileMapLayer = view.chunk_layer(chunk)
		check_eq(layer.position, Vector2(chunk * Config.GROUND_CHUNK * Config.TILE) + Vector2(8, 8),
			"chunk %s position" % chunk)
		check_eq(layer.rendering_quadrant_size, Config.GROUND_QUADRANT, "chunk %s quadrant" % chunk)
		for local: Vector2i in layer.get_used_cells():
			used += 1
			var d: Vector2i = chunk * Config.GROUND_CHUNK + local
			var inside: bool = local.x >= 0 and local.y >= 0 and local.x < Config.GROUND_CHUNK \
				and local.y < Config.GROUND_CHUNK and r.has_point(d)
			var world_px: Vector2 = layer.position + layer.map_to_local(local)
			if not inside or world_px != GroundView.display_center_px(d):
				misplaced += 1
	check_eq(used, cells, "cells over all chunk layers = display cells (no duplicates)")
	check_eq(misplaced, 0, "every tile sits at its display cell's world position")
	check_eq(GroundView.display_center_px(Vector2i(-1, -1)), Vector2(0, 0), "display cell (-1,-1) centred on (0,0)")
	note("view: %d display cells in %d chunks of %dx%d" % [cells, view.chunk_count(), Config.GROUND_CHUNK,
		Config.GROUND_CHUNK])


## A world where soil touches ash (written past the rules): the view draws fallbacks and counts them.
func _check_fallbacks_are_counted(table: WangTable) -> void:
	var data: WorldData = WorldData.new(Vector2i(8, 6))
	data.set_value(WorldData.Layer.FLOOR, Vector2i(3, 2), Terrain.SOIL)
	data.set_value(WorldData.Layer.FLOOR, Vector2i(4, 2), Terrain.ASH)
	check(not data.can_set_terrain(Vector2i(5, 3), Terrain.SOIL), "rules refuse soil next to ash")
	var view: GroundView = GroundView.new()
	view.setup(data, table)
	var v: Dictionary[String, int] = view.verify()
	# Display cells having both (3,2) and (4,2) as corners: (3,1) and (3,2).
	check_eq(v["fallbacks"], 2, "known fallback cells counted")
	check_eq(data.soil_ash_contacts(), 2, "soil_ash_contacts agrees")
	check_eq(v["mismatches"], 0, "no other mismatches")
	view.free()


func _check_edits(table: WangTable) -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var view: GroundView = GroundView.new()
	view.setup(data, table)
	var before_hash: String = view.view_hash()
	# A grass vertex with only grass around it, outside the altar.
	var v: Vector2i = _find_open_grass(data, data.altar_rect.position + Vector2i(-6, 0))
	if not check(v.x >= 0, "found an open grass vertex"):
		view.free()
		return
	var snapshot: Dictionary[Vector2i, Vector3i] = _snapshot(view)
	var written: int = view.cells_written
	var redrawn: Array[Vector2i] = view.set_terrain(v, Terrain.SOIL)
	var expected: Array[Vector2i] = [v + Vector2i(-1, -1), v + Vector2i(0, -1), v + Vector2i(-1, 0), v]
	check_eq(_sorted(redrawn), _sorted(expected), "edit redraws the 4 display cells around the vertex")
	check_eq(view.cells_written - written, 4, "edit writes exactly 4 cells")
	var changed: Array[Vector2i] = _changed(snapshot, view)
	check_eq(_sorted(changed), _sorted(expected), "exactly those 4 cells changed")
	check_eq(data.terrain_at(v), Terrain.SOIL, "data changed")
	var verify: Dictionary[String, int] = view.verify()
	check_eq(verify["mismatches"] + verify["fallbacks"], 0, "corners still right after the edit")
	view.set_terrain(v, Terrain.GRASS)
	check_eq(view.view_hash(), before_hash, "undoing the edit restores the same picture")

	# Refused edits change nothing.
	written = view.cells_written
	var ash_cell: Vector2i = _find_terrain(data, Terrain.ASH)
	var refused: Array[Vector2i] = view.set_terrain(ash_cell + Vector2i(1, 0), Terrain.SOIL) if ash_cell.x >= 0 \
		else [Vector2i.ZERO]
	check_eq(refused.size(), 0, "soil next to ash is refused")
	check_eq(view.set_terrain(Vector2i(-1, 0), Terrain.SOIL).size(), 0, "vertex outside the map is refused")
	check_eq(view.set_terrain(v, Terrain.GRASS).size(), 0, "no change -> nothing redrawn")
	check_eq(view.cells_written, written, "refused edits draw nothing")
	check_eq(view.view_hash(), before_hash, "refused edits leave the picture")
	view.free()


## Edits on chunk corners and map corners land in the right chunk layers.
func _check_chunk_boundary_edits(table: WangTable) -> void:
	var size: Vector2i = Vector2i(Config.GROUND_CHUNK * 2 + 5, Config.GROUND_CHUNK * 2 + 3)
	var data: WorldData = WorldData.new(size)
	var view: GroundView = GroundView.new()
	view.setup(data, table)
	var n: int = Config.GROUND_CHUNK
	var cases: Array[Vector2i] = [Vector2i(n, n), Vector2i(0, 0), Vector2i(size.x - 1, size.y - 1), Vector2i(n, 5),
		Vector2i(2 * n, 2 * n)]
	for v: Vector2i in cases:
		var snapshot: Dictionary[Vector2i, Vector3i] = _snapshot(view)
		var redrawn: Array[Vector2i] = view.set_terrain(v, Terrain.SOIL)
		var changed: Array[Vector2i] = _changed(snapshot, view)
		check_eq(_sorted(changed), _sorted(redrawn), "vertex %s: changed cells = redrawn cells" % v)
		check_eq(redrawn.size(), 4, "vertex %s: 4 cells" % v)
		var chunks: Dictionary[Vector2i, bool] = {}
		for d: Vector2i in redrawn:
			chunks[GroundView.chunk_of(d)] = true
			var layer: TileMapLayer = view.chunk_layer(GroundView.chunk_of(d))
			var local: Vector2i = d - GroundView.chunk_of(d) * n
			check(layer != null and layer.get_cell_source_id(local) >= 0, "vertex %s: cell %s drawn in its chunk" % [v, d])
			check_eq(view.drawn_corners(d), PackedByteArray([data.terrain_at(d), data.terrain_at(d + Vector2i(1, 0)),
				data.terrain_at(d + Vector2i(0, 1)), data.terrain_at(d + Vector2i(1, 1))]),
				"vertex %s: cell %s corners" % [v, d])
		if v == Vector2i(n, n) or v == Vector2i(2 * n, 2 * n) or v == Vector2i(0, 0):
			check_eq(chunks.size(), 4, "vertex %s on a chunk corner touches 4 chunks" % v)
		view.set_terrain(v, Terrain.GRASS)
	var verify: Dictionary[String, int] = view.verify()
	check_eq(verify["mismatches"] + verify["fallbacks"] + verify["missing"], 0, "all corners right after the edits")
	view.free()


func _check_world_scene() -> void:
	var main: PackedScene = load("res://scenes/main.tscn") as PackedScene
	check(main != null and main.can_instantiate(), "main.tscn loads")
	var packed: PackedScene = load("res://scenes/world.tscn") as PackedScene
	if not check(packed != null, "world.tscn loads"):
		return
	var world: GameWorld = packed.instantiate() as GameWorld
	if not check(world != null, "world.tscn root is a GameWorld"):
		return
	add_node(world)
	await await_frames(2)
	if not check(world.data != null, "world generated in _ready"):
		return
	check_eq(world.data.world_seed, CliOptions.current().world_seed, "seed from the command line (default without --seed)")
	check_eq(world.data.size, Config.MAP_SIZE, "world size")
	check(not world.overlay.visible, "debug overlay hidden by default")
	var cam: FreeCamera = world.camera
	check(cam.is_current(), "free camera is the current camera")
	check_eq(cam.position, cam.clamp_to_bounds(world.data.altar_center_px()), "camera starts on the altar")
	var verify: Dictionary[String, int] = world.ground.verify()
	check_eq(verify["mismatches"] + verify["fallbacks"] + verify["missing"], 0, "scene's ground drawn right")
	# WASD pan (move_right) moves the camera; it stays inside the map.
	var x0: float = cam.position.x
	Input.action_press("move_right")
	await await_frames(5)
	Input.action_release("move_right")
	check(cam.position.x > x0, "move_right pans the camera (%.1f -> %.1f)" % [x0, cam.position.x])
	var half: Vector2 = cam.get_viewport_rect().size / 2.0
	var far: Vector2 = cam.clamp_to_bounds(Vector2(-5000, 99999))
	check_eq(far, Vector2(half.x, world.map_rect_px().end.y - half.y), "camera clamps to the map")
	check_eq(world.set_terrain(Vector2i(-3, -3), Terrain.SOIL).size(), 0, "GameWorld.set_terrain refuses outside")


func _check_timings(table: WangTable) -> void:
	var gen: PackedFloat64Array = []
	var draw: PackedFloat64Array = []
	for i: int in TIMING_RUNS + 1:  # first run = warm-up, not reported
		var t0: int = Time.get_ticks_usec()
		var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED + i)
		var t1: int = Time.get_ticks_usec()
		var view: GroundView = GroundView.new()
		view.setup(data, table)
		var t2: int = Time.get_ticks_usec()
		view.free()
		if i > 0:
			gen.append((t1 - t0) / 1000.0)
			draw.append((t2 - t1) / 1000.0)
	var data2: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var view2: GroundView = GroundView.new()
	view2.setup(data2, table)
	var edits: int = 0
	var t3: int = Time.get_ticks_usec()
	for y: int in range(2, data2.size.y - 2, 3):
		for x: int in range(2, data2.size.x - 2, 3):
			if data2.terrain_at(Vector2i(x, y)) == Terrain.GRASS:
				edits += view2.set_terrain(Vector2i(x, y), Terrain.SOIL).size()
	var edit_us: float = (Time.get_ticks_usec() - t3) / maxf(edits / 4.0, 1.0)
	view2.free()
	check_between(_max(gen), 0.0, 2000.0, "generation time (ms, generous bound)")
	check_between(_max(draw), 0.0, 4000.0, "view build time (ms, generous bound)")
	note("generate %dx%d: %.1f..%.1f ms, draw %d cells into chunks: %.1f..%.1f ms (%d runs after a warm-up, headless)" % [
		Config.MAP_SIZE.x, Config.MAP_SIZE.y, _min(gen), _max(gen), (Config.MAP_SIZE.x + 1) * (Config.MAP_SIZE.y + 1),
		_min(draw), _max(draw), TIMING_RUNS])
	note("edit: %.1f us per set_terrain (%d edits, 4 cells each, no frame in between)" % [edit_us, edits / 4])


func _find_open_grass(data: WorldData, near: Vector2i) -> Vector2i:
	for r: int in 20:
		for y: int in range(near.y - r, near.y + r + 1):
			for x: int in range(near.x - r, near.x + r + 1):
				var v: Vector2i = Vector2i(x, y)
				if not data.in_bounds(v) or data.altar_rect.grow(1).has_point(v):
					continue
				var open: bool = true
				for oy: int in range(-2, 3):
					for ox: int in range(-2, 3):
						open = open and data.terrain_at(v + Vector2i(ox, oy)) == Terrain.GRASS
				if open:
					return v
	return Vector2i(-1, -1)


func _find_terrain(data: WorldData, terrain: int) -> Vector2i:
	for y: int in data.size.y:
		for x: int in data.size.x:
			if data.terrain_at(Vector2i(x, y)) == terrain and data.terrain_at(Vector2i(x + 1, y)) == Terrain.GRASS:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _snapshot(view: GroundView) -> Dictionary[Vector2i, Vector3i]:
	var out: Dictionary[Vector2i, Vector3i] = {}
	var r: Rect2i = view.display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			out[Vector2i(dx, dy)] = view.drawn_at(Vector2i(dx, dy))
	return out


func _changed(snapshot: Dictionary[Vector2i, Vector3i], view: GroundView) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in snapshot:
		if view.drawn_at(d) != snapshot[d]:
			out.append(d)
	return out


static func _sorted(cells: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = cells.duplicate()
	out.sort()
	return out


static func _min(values: PackedFloat64Array) -> float:
	var m: float = INF
	for v: float in values:
		m = minf(m, v)
	return m


static func _max(values: PackedFloat64Array) -> float:
	var m: float = -INF
	for v: float in values:
		m = maxf(m, v)
	return m
