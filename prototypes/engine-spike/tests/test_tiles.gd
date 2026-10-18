extends "res://tests/spike_test.gd"
## Tiles module (res://tiles/, results in res://notes/tiles.md):
##   - the TileSets are what build_tilesets.gd makes from our PixelLab PNG + JSON corners
##   - (b) dual grid: for every vertex pattern the drawn tile's corners equal the vertices
##   - (a) Godot terrains (Match Corners): painted centers kept, no seams on small two-terrain shapes
##   - breaking a wall cell redraws the neighbouring tiles (both methods); collision and ore follow
##   - floor / wall / ore overlay (+ collision) TileMapLayers coexist
##   - 512x512 fill + 2,000 random single-cell edits per method, printed as TILES_BENCH lines

const Wang := preload("res://tiles/wang.gd")
const WangLookup := preload("res://tiles/wang_lookup.gd")
const DualGrid := preload("res://tiles/dual_grid.gd")
const TerrainGrid := preload("res://tiles/terrain_grid.gd")
const Maps := preload("res://tiles/maps.gd")
const TileBench := preload("res://tiles/tile_bench.gd")
const Builder := preload("res://tiles/build_tilesets.gd")
const DungeonMapScript := preload("res://tiles/dungeon_map.gd")

const ART: String = "res://art/tiles/"
const BENCH_SIZE: int = 512
const BENCH_EDITS: int = 2000
const DEMO_W: int = 14
const DEMO_H: int = 17


func run() -> Array[String]:
	_check_tilesets()
	_check_dual_surface()
	_check_dual_dungeon()
	_check_terrain_method()
	await _check_break_wall("b")
	await _check_break_wall("a")
	await _check_layers()
	await _check_demo()
	await _check_performance()
	return failures


# --- TileSets -------------------------------------------------------------------------------

func _check_tilesets() -> void:
	DirAccess.make_dir_recursive_absolute("user://tiles_test")
	for spec: Array in [["surface", Builder.SURFACE_PATH, 11, 41], ["dungeon", Builder.DUNGEON_PATH, 3, 33]]:
		var name: String = spec[0]
		var saved: TileSet = load(spec[1]) as TileSet
		if not check_not_null(saved, "%s.tres loads" % name):
			continue
		check_eq(saved.tile_size, Vector2i(16, 16), "%s: 16px tiles" % name)
		check_eq(saved.get_terrain_sets_count(), 1, "%s: one terrain set" % name)
		check_eq(saved.get_terrain_set_mode(0), TileSet.TERRAIN_MODE_MATCH_CORNERS, "%s: Match Corners mode" % name)
		check_eq(saved.get_terrains_count(0), 3, "%s: three terrains" % name)
		var stats: Dictionary = Builder.describe(saved)
		check_eq(stats["sources"], spec[2], "%s: atlas sources" % name)
		check_eq(stats["tiles"], spec[3], "%s: atlas tiles" % name)
		for i: int in saved.get_source_count():
			var source: TileSetAtlasSource = saved.get_source(saved.get_source_id(i)) as TileSetAtlasSource
			check(source != null and not source.has_tiles_outside_texture(),
				"%s: source %d tiles lie inside the texture" % [name, saved.get_source_id(i)])
		# Reproducible: a fresh build saved now is the committed file (ext_resource ids aside, they
		# depend on the save path).
		var fresh: TileSet = Builder.build_surface() if name == "surface" else Builder.build_dungeon()
		var tmp: String = "user://tiles_test/%s.tres" % name
		if check_eq(ResourceSaver.save(fresh, tmp), OK, "%s: fresh build saves" % name):
			check(_normalized(FileAccess.get_file_as_string(tmp)) == _normalized(FileAccess.get_file_as_string(spec[1])),
				"%s.tres equals a fresh build_tilesets.gd run (rebuild: --script res://tiles/build_tilesets.gd)" % name)
			DirAccess.remove_absolute(tmp)

	var wang_sets: Array = [
		[Builder.SURFACE_PATH, Builder.SRC_GRASS_SOIL, "tiles_grass-soil_v01.json", {"lower": Wang.SOIL, "upper": Wang.GRASS}, 16],
		[Builder.SURFACE_PATH, Builder.SRC_GRASS_ASH, "tiles_grass-corruption_v02.json", {"lower": Wang.ASH, "upper": Wang.GRASS}, 16],
		[Builder.DUNGEON_PATH, Builder.SRC_DUNGEON, "tiles_dungeon_v01.json",
			{"lower": Wang.FLOOR, "transition": Wang.FACE, "upper": Wang.WALL}, 25],
	]
	for ws: Array in wang_sets:
		var ts: TileSet = load(ws[0]) as TileSet
		var source: TileSetAtlasSource = ts.get_source(ws[1]) as TileSetAtlasSource
		var tiles: Array[Dictionary] = Wang.read_pixellab(ART + ws[2], ws[3])
		check_eq(tiles.size(), ws[4], "%s: tile count" % ws[2])
		var bad: Array[String] = []
		for tile: Dictionary in tiles:
			var coords: Vector2i = (tile["rect"] as Rect2i).position / Wang.TILE
			if not source.has_tile(coords):
				bad.append("%s missing" % tile["name"])
				continue
			for a: int in source.get_alternative_tiles_count(coords):
				var td: TileData = source.get_tile_data(coords, source.get_alternative_tile_id(coords, a))
				if td.get_custom_data(Wang.DATA_CORNERS) != tile["corners"]:
					bad.append("%s custom corners" % tile["name"])
				if td.terrain_set == 0:
					for i: int in 4:
						if td.get_terrain_peering_bit(Wang.PEERING_BITS[i]) != int((tile["corners"] as PackedByteArray)[i]):
							bad.append("%s peering bit %s" % [tile["name"], Wang.CORNER_NAMES[i]])
		check(bad.is_empty(), "%s: atlas tiles carry the JSON corners: %s" % [ws[2], str(bad.slice(0, 5))])


## Drops ext_resource ids (they depend on the path the file was saved to).
static func _normalized(text: String) -> String:
	var re_id: RegEx = RegEx.create_from_string("(\\[ext_resource [^\\]]*?) id=\"[^\"]*\"")
	var re_ref: RegEx = RegEx.create_from_string("ExtResource\\(\"[^\"]*\"\\)")
	return re_ref.sub(re_id.sub(text, "$1", true), "ExtResource()", true)


# --- (b) dual grid ----------------------------------------------------------------------------

func _check_dual_surface() -> void:
	var lookup: WangLookup = TileBench.lookup_for("surface")
	check_eq(lookup.exact_keys, 31, "surface: corner keys with art (16 + 16 - the shared all-grass key)")
	check_eq(lookup.fallback_keys, 50, "surface: corner keys without art")
	var holder: Node2D = add_node(Node2D.new()) as Node2D
	var layer: TileMapLayer = _layer(holder, TileBench.SURFACE_TILESET)
	# World cells (0,0) (1,0) (0,1) (1,1) are the corners NW NE SW SE of display cell (0,0).
	var grid: DualGrid = DualGrid.new(layer, lookup, 2, 2, Wang.GRASS)
	var wrong: Array[String] = []
	for key: int in Wang.KEY_COUNT:
		var want: PackedByteArray = Wang.corners_of_key(key)
		grid.fill(want)
		var td: TileData = layer.get_cell_tile_data(Vector2i(0, 0))
		var have: PackedByteArray = td.get_custom_data(Wang.DATA_CORNERS) if td != null else PackedByteArray()
		if lookup.exact[key] == 1:
			if have != want:
				wrong.append("key %s drew %s" % [want, have])
		else:
			if not (Wang.SOIL in want and Wang.ASH in want):
				wrong.append("key %s has no art but is not a soil+ash mix" % want)
			if have != Wang.corners_of_key(lookup.resolved_key[key]):
				wrong.append("fallback key %s drew %s" % [want, have])
	check(wrong.is_empty(), "surface: all 81 vertex patterns draw their own tile (or the nearest one for soil+ash): %s"
		% str(wrong.slice(0, 5)))

	# Inner-tile variants: picked by a stable position hash with TileData.probability weights.
	var big_layer: TileMapLayer = _layer(holder, TileBench.SURFACE_TILESET)
	var big: DualGrid = DualGrid.new(big_layer, lookup, 32, 32, Wang.GRASS)
	big.fill(Maps.filled(32, 32, Wang.GRASS))
	var first: Dictionary = _snapshot(big_layer)
	var variants: int = 0
	for c: Vector2i in big_layer.get_used_cells():
		if big_layer.get_cell_source_id(c) >= Builder.SRC_GRASS_VARIANTS:
			variants += 1
	# 2 plain grass tiles (weight 1 each) + 4 variants (0.25 each) -> 1/3 variants expected.
	check_between(float(variants) / big_layer.get_used_cells().size(), 0.25, 0.42, "surface: share of grass variants")
	big.fill(Maps.filled(32, 32, Wang.GRASS))
	check(_snapshot(big_layer) == first, "surface: variant choice is stable when redrawn")


func _check_dual_dungeon() -> void:
	var lookup: WangLookup = TileBench.lookup_for("dungeon")
	check_eq(lookup.exact_keys, 21, "dungeon: corner keys with art (25 tiles, 4 keys have two)")
	check_eq(lookup.fallback_keys, 60, "dungeon: corner keys without art")
	check_eq([lookup.reach_left, lookup.reach_right, lookup.reach_up, lookup.reach_down], [0, 0, 1, 1],
		"dungeon: context tiles look one vertex row up and down")
	var holder: Node2D = add_node(Node2D.new()) as Node2D
	var layer: TileMapLayer = _layer(holder, TileBench.DUNGEON_TILESET)
	# Every floor/wall pattern of columns 1..2, rows 1..4 in a 4x6 floor world. Display cell (1,2)
	# has the corners (1,2) (2,2) (1,3) (2,3); rows 1 and 4 are the context rows above and below.
	var grid: DualGrid = DualGrid.new(layer, lookup, 4, 6, Wang.FLOOR, true)
	var keys_seen: Dictionary = {}
	var wrong: Array[String] = []
	var used: Dictionary = {}
	for bits: int in 256:
		var m: PackedByteArray = Maps.filled(4, 6, Wang.FLOOR)
		for i: int in 8:
			if bits & (1 << i):
				m[(1 + i / 2) * 4 + 1 + i % 2] = Wang.WALL
		grid.fill(m)
		var want: PackedByteArray = grid.display_corners(1, 2)
		var key: int = Wang.key_of_corners(want)
		keys_seen[key] = true
		var td: TileData = layer.get_cell_tile_data(Vector2i(1, 2))
		var have: PackedByteArray = td.get_custom_data(Wang.DATA_CORNERS)
		if lookup.exact[key] == 0:
			if not (Wang.FACE in want):
				wrong.append("pattern %d: key %s without art has no face vertex" % [bits, want])
			continue
		if have != want:
			wrong.append("pattern %d: key %s drew %s" % [bits, want, have])
			continue
		used[str(td.get_custom_data(Wang.DATA_NAME))] = true
		# Context tiles: the chosen tile breaks no more 4x4 pattern constraints than the best candidate.
		var best: int = 1000
		for pattern: PackedByteArray in lookup.patterns[key]:
			best = mini(best, _violations(pattern, grid, 1, 2))
		var chosen: int = _violations(td.get_custom_data(Wang.DATA_PATTERN), grid, 1, 2)
		if chosen != best:
			wrong.append("pattern %d: %s breaks %d constraints, best %d" % [bits, td.get_custom_data(Wang.DATA_NAME), chosen, best])
	check(wrong.is_empty(), "dungeon: 256 floor/wall patterns draw matching tiles: %s" % str(wrong.slice(0, 5)))
	check_eq(keys_seen.size(), 36, "dungeon: floor/wall maps give 36 corner keys (6 column kinds squared)")
	var with_art: int = 0
	for key: int in keys_seen:
		with_art += lookup.exact[key]
	check_eq(with_art, 21, "dungeon: 21 of the 36 have art")
	var unused: Array[String] = []
	var source: TileSetAtlasSource = layer.tile_set.get_source(Builder.SRC_DUNGEON) as TileSetAtlasSource
	for t: int in source.get_tiles_count():
		var tile_name: String = str(source.get_tile_data(source.get_tile_id(t), 0).get_custom_data(Wang.DATA_NAME))
		if not used.has(tile_name):
			unused.append(tile_name.trim_prefix("dungeon/"))
	print("  TILES_INFO dungeon tiles never chosen in the 256 patterns: %s" % ", ".join(unused))

	# Wall cap: a wall column whose top end is in this cell uses the context tile t1_10
	# (pattern row 0 = floor above), a wall that goes on upward uses the plain t1_4.
	var cap: PackedByteArray = Maps.filled(4, 6, Wang.FLOOR)
	cap[2 * 4 + 2] = Wang.WALL
	cap[3 * 4 + 2] = Wang.WALL
	grid.fill(cap)
	check_eq(layer.get_cell_tile_data(Vector2i(1, 2)).get_custom_data(Wang.DATA_NAME), "dungeon/t1_10_r3_c1",
		"dungeon: wall cap tile where the wall column starts")
	cap[1 * 4 + 2] = Wang.WALL
	grid.fill(cap)
	check_eq(layer.get_cell_tile_data(Vector2i(1, 2)).get_custom_data(Wang.DATA_NAME), "dungeon/t1_4_r4_c1",
		"dungeon: plain tile where the wall goes on upward")


## Outer 4x4 pattern entries of a tile that disagree with the vertices around display cell (dx, dy).
static func _violations(pattern: PackedByteArray, grid: DualGrid, dx: int, dy: int) -> int:
	if pattern.size() != 16:
		return 0
	var n: int = 0
	for row: int in 4:
		for col: int in 4:
			if (row == 1 or row == 2) and (col == 1 or col == 2):
				continue
			var want: int = pattern[row * 4 + col]
			if want != Wang.WILDCARD and grid.vertex(dx - 1 + col, dy - 1 + row) != want:
				n += 1
	return n


# --- (a) Godot terrains -----------------------------------------------------------------------

func _check_terrain_method() -> void:
	var holder: Node2D = add_node(Node2D.new()) as Node2D
	var lookup: WangLookup = TileBench.lookup_for("surface")
	var shapes: Dictionary = {
		"single": [Vector2i(3, 3)],
		"pair": [Vector2i(3, 3), Vector2i(4, 3)],
		"diagonal": [Vector2i(3, 3), Vector2i(4, 4)],
		"checker": [Vector2i(2, 2), Vector2i(4, 2), Vector2i(3, 3), Vector2i(2, 4), Vector2i(4, 4)],
		"block2x2": [Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4)],
	}
	var areas: Array[String] = []
	for shape_name: String in shapes:
		var m: PackedByteArray = Maps.filled(8, 8, Wang.GRASS)
		for c: Vector2i in shapes[shape_name]:
			m[c.y * 8 + c.x] = Wang.SOIL
		var a_layer: TileMapLayer = _layer(holder, TileBench.SURFACE_TILESET)
		var a: TerrainGrid = TerrainGrid.new(a_layer, 8, 8, Wang.GRASS)
		a.fill(m)
		var q: Dictionary = TileBench.terrain_quality(a)
		check_eq(q["seams"], 0, "terrains (a) %s: neighbouring tiles agree on shared corners" % shape_name)
		check_eq(q["bad_center"], 0, "terrains (a) %s: every cell keeps its painted terrain as tile center" % shape_name)
		var b_layer: TileMapLayer = _layer(holder, TileBench.SURFACE_TILESET)
		var b: DualGrid = DualGrid.new(b_layer, lookup, 8, 8, Wang.GRASS)
		b.fill(m)
		var b_area: int = _soil_vertices(b_layer)
		check_eq(b_area, (shapes[shape_name] as Array).size(), "dual grid (b) %s: one soil vertex per soil cell" % shape_name)
		areas.append("%s a=%d b=%d" % [shape_name, _soil_vertices(a_layer), b_area])
	print("  TILES_INFO soil area in vertices (16x16 blobs) per painted shape: %s" % ", ".join(areas))

	# Two-terrain noise maps: Godot's solver keeps every painted center but leaves a few seams.
	var seams: int = 0
	var edges: int = 0
	for other: int in [Wang.SOIL, Wang.ASH]:
		for s: int in 3:
			var m: PackedByteArray = _blobs(32, s, other)
			var layer: TileMapLayer = _layer(holder, TileBench.SURFACE_TILESET)
			var g: TerrainGrid = TerrainGrid.new(layer, 32, 32, Wang.GRASS)
			g.fill(m)
			var q: Dictionary = TileBench.terrain_quality(g)
			check_eq(q["bad_center"], 0, "terrains (a) noise %d/%d: centers kept" % [other, s])
			seams += int(q["seams"])
			edges += 2 * 32 * 31
			var dl: TileMapLayer = _layer(holder, TileBench.SURFACE_TILESET)
			var d: DualGrid = DualGrid.new(dl, lookup, 32, 32, Wang.GRASS)
			d.fill(m)
			check_eq(TileBench.dual_quality(d), {"inexact": 0, "wrong": 0}, "dual grid (b) noise %d/%d: exact" % [other, s])
	check_between(float(seams) / edges, 0.0, 0.01, "terrains (a): seams on two-terrain noise maps stay under 1%")
	print("  TILES_INFO terrains (a) two-terrain 32x32 noise maps: %d seams in %d cell edges" % [seams, edges])


static func _blobs(size: int, seed_value: int, terrain: int) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.15
	var m: PackedByteArray = Maps.filled(size, size, Wang.GRASS)
	for y: int in size:
		for x: int in size:
			if noise.get_noise_2d(x, y) > 0.1:
				m[y * size + x] = terrain
	return m


## Soil corners on the layer / 4 = soil vertices (all shapes are away from the border).
static func _soil_vertices(layer: TileMapLayer) -> int:
	var n: int = 0
	for c: Vector2i in layer.get_used_cells():
		var td: TileData = layer.get_cell_tile_data(c)
		var corners: PackedByteArray = td.get_custom_data(Wang.DATA_CORNERS)
		for v: int in corners:
			if v == Wang.SOIL:
				n += 1
	return n / 4


# --- breaking walls ---------------------------------------------------------------------------

func _check_break_wall(method: String) -> void:
	var tag: String = "break wall (%s)" % method
	var dm: Node2D = add_node(DungeonMapScript.new()) as Node2D
	dm.position = Vector2(1000, 0) if method == "a" else Vector2.ZERO  # keep the physics bodies apart
	dm.call("setup", method, DEMO_W, DEMO_H, Maps.demo_dungeon(DEMO_W, DEMO_H), {Vector2i(4, 2): Builder.OVERLAY_COPPER})
	var walls: TileMapLayer = dm.get("wall_layer")
	var collision: TileMapLayer = dm.get("collision_layer")
	var ore: TileMapLayer = dm.get("ore_layer")
	var before: Dictionary = _snapshot(walls)
	check(dm.call("is_wall", 5, 2), "%s: (5,2) is a wall in the room's top wall" % tag)
	check_eq((dm.call("break_wall", 0, 5) as Array).size(), 0, "%s: the map border cannot be broken" % tag)
	check_eq((dm.call("break_wall", 5, 5) as Array).size(), 0, "%s: breaking a floor cell does nothing" % tag)

	var redrawn: Array[Vector2i] = dm.call("break_wall", 5, 2)
	var changed: Array[Vector2i] = _changed(before, _snapshot(walls))
	check(not dm.call("is_wall", 5, 2), "%s: cell is floor now" % tag)
	check_eq(collision.get_cell_source_id(Vector2i(5, 2)), -1, "%s: collision tile removed" % tag)
	if method == "b":
		var grid: DualGrid = dm.get("walls")
		check_eq(grid.vertex(5, 2), Wang.FACE, "%s: the dug cell shows the front face of the wall above" % tag)
		check_eq(grid.vertex(5, 3), Wang.FLOOR, "%s: the old face vertex below is plain floor" % tag)
		for c: Vector2i in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2), Vector2i(4, 3), Vector2i(5, 3)]:
			check(c in changed, "%s: display cell %s around the two changed vertices got a new tile" % [tag, c])
		for c: Vector2i in changed:
			check(c in redrawn, "%s: changed cell %s was in the redraw list" % [tag, c])
		check_eq(TileBench.dual_quality(grid)["wrong"], 0, "%s: whole map still matches its vertices" % tag)
		dm.call("place_wall", 5, 2)
		check(_snapshot(walls) == before, "%s: building the wall back restores the same tiles" % tag)
	else:
		var grid: TerrainGrid = dm.get("walls")
		check_eq(grid.painted[2 * DEMO_W + 5], Wang.FACE, "%s: dug cell painted as face (wall above)" % tag)
		check_eq(grid.painted[3 * DEMO_W + 5], Wang.FLOOR, "%s: cell below repainted as floor" % tag)
		var neighbours: Array[Vector2i] = []
		for c: Vector2i in changed:
			if not (c in redrawn):
				neighbours.append(c)
		check(neighbours.size() > 0, "%s: Godot also changed neighbouring cells (%s)" % [tag, neighbours])
		var q: Dictionary = TileBench.terrain_quality(grid)
		check_eq(q["bad_center"], 0, "%s: centers kept" % tag)
		dm.call("place_wall", 5, 2)
		var restored: int = _changed(before, _snapshot(walls)).size()
		print("  TILES_INFO terrains (a) break (5,2): painted %s, Godot changed %s, seams in demo room %d, cells differing after building it back %d"
			% [redrawn, changed, q["seams"], restored])
	check_eq(collision.get_cell_source_id(Vector2i(5, 2)), Builder.SRC_OVERLAY, "%s: collision tile back" % tag)

	# Ore overlay and collision follow the wall.
	check_eq(ore.get_cell_atlas_coords(Vector2i(4, 2)), Builder.OVERLAY_COPPER, "%s: copper ore on (4,2)" % tag)
	dm.call("break_wall", 4, 2)
	check_eq(ore.get_cell_source_id(Vector2i(4, 2)), -1, "%s: ore removed with its wall" % tag)
	await await_physics_frames(2)
	check(_solid_at(dm, Vector2i(3, 2)), "%s: physics body on a wall cell" % tag)
	check(not _solid_at(dm, Vector2i(4, 2)), "%s: no physics body on the mined cell" % tag)
	check(not _solid_at(dm, Vector2i(5, 5)), "%s: no physics body on the floor" % tag)
	dm.queue_free()
	await await_frames(1)


static func _solid_at(node: Node2D, cell: Vector2i) -> bool:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = node.to_global(Vector2(cell) * Wang.TILE + Vector2(8, 8))
	return not node.get_world_2d().direct_space_state.intersect_point(query).is_empty()


# --- layers -----------------------------------------------------------------------------------

func _check_layers() -> void:
	var dm: Node2D = add_node(DungeonMapScript.new()) as Node2D
	var map: PackedByteArray = Maps.demo_dungeon(DEMO_W, DEMO_H)
	var ores: Dictionary = {Vector2i(4, 2): Builder.OVERLAY_COPPER, Vector2i(1, 13): Builder.OVERLAY_IRON,
		Vector2i(6, 5): Builder.OVERLAY_COPPER}  # (6,5) is floor: ignored
	dm.call("setup", "b", DEMO_W, DEMO_H, map, ores)
	var names: Array[String] = []
	for child: Node in dm.get_children():
		names.append(str(child.name))
	check_eq(names, ["Floor", "Walls", "Ore", "Collision"] as Array[String], "layers: four TileMapLayers in draw order")
	var floor_layer: TileMapLayer = dm.get("floor_layer")
	var walls: TileMapLayer = dm.get("wall_layer")
	var ore: TileMapLayer = dm.get("ore_layer")
	var collision: TileMapLayer = dm.get("collision_layer")
	check(floor_layer.tile_set == walls.tile_set and ore.tile_set == walls.tile_set and collision.tile_set == walls.tile_set,
		"layers: one TileSet for all")
	check(floor_layer.z_index < walls.z_index and walls.z_index < ore.z_index, "layers: floor < walls < ore")
	check(floor_layer.visible and walls.visible and ore.visible and not collision.visible, "layers: collision layer hidden")
	check_eq(floor_layer.position, Vector2(8, 8), "layers: floor on the display grid (half-tile offset)")
	check_eq(walls.position, Vector2(8, 8), "layers: walls on the display grid")
	check_eq(ore.position, Vector2.ZERO, "layers: ore on the world grid")
	var display_cells: int = (DEMO_W + 1) * (DEMO_H + 1)
	check_eq(floor_layer.get_used_cells().size(), display_cells, "layers: floor everywhere")
	var walls_used: int = walls.get_used_cells().size()
	check_between(walls_used, 1, display_cells - 1, "layers: wall layer leaves all-floor cells empty")
	var wall_cells: int = 0
	for v: int in map:
		if v == Wang.WALL:
			wall_cells += 1
	check_eq(collision.get_used_cells().size(), wall_cells, "layers: one collision tile per wall cell")
	check_eq(ore.get_used_cells().size(), 2, "layers: ore only on wall cells")
	for c: Vector2i in ore.get_used_cells():
		check(dm.call("is_wall", c.x, c.y), "layers: ore %s sits on a wall" % c)
		# The four display cells around the vertex of the ore cell all have a wall tile under the ore.
		for d: Vector2i in [c + Vector2i(-1, -1), c + Vector2i(0, -1), c + Vector2i(-1, 0), c]:
			check(walls.get_cell_source_id(d) != -1 and floor_layer.get_cell_source_id(d) != -1,
				"layers: floor and wall tiles under ore %s at display cell %s" % [c, d])
	var floor_before: Dictionary = _snapshot(floor_layer)
	var walls_before: Dictionary = _snapshot(walls)
	dm.call("break_wall", 4, 2)
	check(_snapshot(floor_layer) == floor_before, "layers: mining leaves the floor layer alone")
	check(_snapshot(walls) != walls_before, "layers: mining redraws the wall layer")
	check_eq(ore.get_used_cells().size(), 1, "layers: mined ore removed, the other stays")
	await await_frames(1)


# --- demo scene -------------------------------------------------------------------------------

func _check_demo() -> void:
	for path: String in ["res://tiles/tiles.tscn", "res://tiles/tiles_demo.tscn"]:
		var packed: PackedScene = load(path) as PackedScene
		if not check_not_null(packed, "%s loads" % path):
			continue
		var demo: Node2D = add_node(packed.instantiate()) as Node2D
		await await_frames(2)
		var field: Node2D = demo.get("surface")
		var dungeon: Node2D = demo.get("dungeon")
		if not (check_not_null(field, "%s: field built" % path) and check_not_null(dungeon, "%s: dungeon built" % path)):
			continue
		check_eq(field.call("get_terrain", 9, 4), Wang.SOIL, "%s: scripted hoe edit applied" % path)
		check(not dungeon.call("is_wall", 12, 10), "%s: scripted tunnel dug" % path)
		check_has(str((demo.get("label") as Label).text), "(b) dual grid", "%s: default method is (b)" % path)
	# The same demo with Godot terrains (key M in the demo).
	var demo_a: Node2D = add_node((load("res://tiles/tiles_demo.tscn") as PackedScene).instantiate()) as Node2D
	await await_frames(1)
	demo_a.set("method", "a")
	demo_a.call("_build")
	await await_frames(1)
	check_has(str((demo_a.get("label") as Label).text), "(a) Godot terrains", "demo: method (a) builds")
	check_eq((demo_a.get("surface") as Node2D).call("get_terrain", 9, 4), Wang.SOIL, "demo (a): hoe edit applied")


# --- performance ------------------------------------------------------------------------------

func _check_performance() -> void:
	var holder: Node2D = add_node(Node2D.new()) as Node2D
	var fill: Dictionary = {}
	for kind: String in ["surface", "dungeon"]:
		for method: String in ["b", "a"]:
			var r: Dictionary = TileBench.run(kind, method, BENCH_SIZE, BENCH_EDITS, 1, holder, true)
			print("  " + TileBench.format(r))
			var tag: String = "bench %s (%s)" % [kind, method]
			fill[kind + method] = float(r["fill_ms"])
			if method == "b":
				check_eq(r["wrong"], 0, "%s: every display cell matches its vertices after the edits" % tag)
				check_between(r["fill_ms"], 0.0, 5000.0, "%s: 512x512 fill ms" % tag)
				check_between(r["edits_ms"], 0.0, 2000.0, "%s: 2,000 edits batched ms" % tag)
				check_between(r["pf_ms"], 0.0, 5000.0, "%s: 2,000 edits with an update each ms" % tag)
				if kind == "surface":
					check_eq(r["used_cells"], (BENCH_SIZE + 1) * (BENCH_SIZE + 1), "%s: display cells" % tag)
			else:
				check_eq(r["bad_center"], 0, "%s: centers kept after the edits" % tag)
				check_between(r["fill_ms"], 0.0, 60000.0, "%s: 512x512 fill ms" % tag)
				check_eq(r["used_cells"], BENCH_SIZE * BENCH_SIZE, "%s: cells" % tag)
			await await_frames(1)
	check(fill["surfaceb"] < fill["surfacea"], "bench: dual grid fills the surface map faster than Godot terrains")
	check(fill["dungeonb"] < fill["dungeona"], "bench: dual grid fills the dungeon map faster than Godot terrains")


# --- helpers ----------------------------------------------------------------------------------

static func _layer(parent: Node, tile_set_path: String) -> TileMapLayer:
	var layer: TileMapLayer = TileMapLayer.new()
	layer.tile_set = load(tile_set_path) as TileSet
	parent.add_child(layer)
	return layer


## cell -> Vector4i(source, atlas x, atlas y, alternative)
static func _snapshot(layer: TileMapLayer) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector2i in layer.get_used_cells():
		var atlas: Vector2i = layer.get_cell_atlas_coords(c)
		out[c] = Vector4i(layer.get_cell_source_id(c), atlas.x, atlas.y, layer.get_cell_alternative_tile(c))
	return out


static func _changed(before: Dictionary, after: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in before:
		if not after.has(c) or after[c] != before[c]:
			out.append(c)
	for c: Vector2i in after:
		if not before.has(c):
			out.append(c)
	return out
