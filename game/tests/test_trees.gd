extends "res://tests/base_test.gd"
## M7b, the tree and the axe (offline first; ● game-concept §12 R37 one species, anyone chops; ○ the axe and every number
## PROVISIONAL README "임시값" M7b): the generator's step 6 over 40 seeds (count, grass, spacing, away from the light, the
## ash, the edges, the entrance, nothing in the crown's tiles) with the rules written out here, the same seed = the same
## trees, seed 1's golden hash and that the trees are all it added (taking them away gives the M3a hash; the gatherables
## and the heretics' spawn tiles are as they were), trunks and stumps block (walking, shots), chopping (only the axe, any
## class, reach, Config.TREE_CHOP_HITS swings, the logs, a full inventory, MAX_DROPS, the stump, regrowth), the axe's
## action (frames, the landing tick, one impact a swing), the pictures (FixtureView: the tile's bottom edge, the trunk on
## the tile's centre, the stump on the same canvas, measured from the art here), main.tscn (an axe held at a tree fells it),
## the interplay (no tilling, building or altar on a trunk), a session (the axe swings, nothing is chopped), determinism.

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0
## Written out here on purpose (README "임시값" M7b 나무): count, spacing, distance from the altar's centre, ash, edges.
const COUNT: int = 30
const SPACING: int = 4
const MIN_TILES_FROM_ALTAR: float = 20.0
const ASH_TILES: int = 3
const SIDE_TILES: int = 3
const TOP_TILES: int = 6
## The M3a surface hash (before the trees, README "월드 데이터").
const M3A_HASH: String = "1d9f92c7b5ef2a715f95cc32d7424b36"

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_generation()
	_check_blocking()
	_check_chop()
	_check_regrowth()
	_check_axe_action()
	await _check_view()
	await _check_main()
	_check_interplay()
	_check_session()
	_check_determinism()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


static func on(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


static func apply(data: WorldData, edits: Array[EditLog.WorldEdit]) -> void:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(data, e)


static func stripped(data: WorldData) -> WorldData:
	for c: Vector2i in Forest.tree_cells(data):
		data.set_value(WorldData.Layer.PLACEABLE, c, WorldData.PLACEABLE_NONE)
	return data


# --- generation --------------------------------------------------------------------------------------

func _check_generation() -> void:
	var bad: Array[String] = []
	for s: int in range(1, 41):
		var d: WorldData = SurfaceGen.generate(s)
		var trees: Array[Vector2i] = Forest.tree_cells(d)
		if trees.size() != COUNT:
			bad.append("seed %d: %d trees" % [s, trees.size()])
		var centre: Vector2 = d.altar_center_px() / Config.TILE
		var way: Rect2i = SurfaceGen.entrance_rect(d)
		for t: Vector2i in trees:
			var why: String = ""
			if d.terrain_at(t) != Terrain.GRASS:
				why = "not grass"
			elif (Vector2(t) + Vector2(0.5, 0.5)).distance_to(centre) < MIN_TILES_FROM_ALTAR:
				why = "too near the altar"
			elif t.x < SIDE_TILES or t.x >= d.size.x - SIDE_TILES or t.y < TOP_TILES or t.y >= d.size.y - SIDE_TILES:
				why = "too near the edge"
			elif way.grow(3).has_point(t):
				why = "too near the entrance"
			for y: int in range(t.y - ASH_TILES, t.y + ASH_TILES + 1):
				for x: int in range(t.x - ASH_TILES, t.x + ASH_TILES + 1):
					if d.terrain_at(Vector2i(x, y)) == Terrain.ASH:
						why = "ash within %d" % ASH_TILES
			for y2: int in range(t.y - 4, t.y + 2):
				for x2: int in range(t.x - 2, t.x + 3):
					var c: Vector2i = Vector2i(x2, y2)
					if d.get_value(WorldData.Layer.VEGETATION, c) != 0 or d.terrain_at(c) == Terrain.SOIL:
						why = "something grows under the crown"
					if c != t and d.get_value(WorldData.Layer.PLACEABLE, c) != 0:
						why = "a placeable under the crown"
			for o: Vector2i in trees:
				if o != t and maxi(absi(o.x - t.x), absi(o.y - t.y)) <= SPACING:
					why = "another tree within %d" % SPACING
			if not why.is_empty():
				bad.append("seed %d tree %s: %s" % [s, t, why])
	check(bad.is_empty(), "step 6 rules hold on 40 seeds (%s)" % ", ".join(bad.slice(0, 5)))
	var a: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var b: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	check_eq(Forest.tree_cells(a), Forest.tree_cells(b), "the same seed: the same trees")
	check_eq(a.content_hash(), SurfaceGen.GOLDEN_HASH, "seed 1: the golden hash")
	check_ne(Forest.tree_cells(SurfaceGen.generate(2)), Forest.tree_cells(a), "another seed: other trees")
	var spawn_with: Array[Vector2i] = Arena.surface_spawn_cells(a, SafeZone.for_world(a))
	stripped(a)
	check_eq(a.content_hash(), M3A_HASH, "the trees are all step 6 added (without them: the M3a hash)")
	check_eq(WorldItems.gatherable_cells(a).size(), 74, "the gatherables as in M2b")
	check_eq(spawn_with, Arena.surface_spawn_cells(a, SafeZone.for_world(a)), "the heretics' spawn tiles as before (no tree there)")
	check_eq([Config.TREE_COUNT, Config.TREE_SPACING_TILES, Config.SAFE_RADIUS_TILES + Config.TREE_LIGHT_CLEARANCE_TILES,
		Config.TREE_ASH_CLEARANCE_TILES, Config.TREE_EDGE_TILES, Config.TREE_TOP_TILES], [COUNT, SPACING, 20, ASH_TILES, SIDE_TILES,
		TOP_TILES], "the provisional numbers")
	var dun: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	check_eq(Forest.tree_cells(dun).size(), 0, "no tree in the dungeon")
	check_eq(dun.content_hash(), DungeonGen.GOLDEN_HASH, "the dungeon as it was")


# --- blocking -------------------------------------------------------------------------------------------

func _check_blocking() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var t: Vector2i = Forest.tree_cells(d)[0]
	check(Movement.is_blocked(d, t), "the trunk blocks")
	var around: bool = true
	for c: Vector2i in [t + Vector2i(-1, 0), t + Vector2i(1, 0), t + Vector2i(0, -1), t + Vector2i(0, -2), t + Vector2i(0, 1)]:
		around = around and not Movement.is_blocked(d, c)
	check(around, "the crown and the roots block nothing")
	var from_s: Vector2 = Vector2((t.x + 0.5) * 16, (t.y + 4) * 16)
	var p: Vector2 = from_s
	for i: int in 180:
		p = Movement.step(d, p, Vector2i(0, -1), TICK)
	check_eq(p.y, (t.y + 1) * 16 + Config.FEET_HEIGHT, "walking north into the trunk stops at its bottom edge")
	check(not Combat.line_clear(d, Vector2((t.x + 0.5) * 16, (t.y + 3) * 16), Vector2((t.x + 0.5) * 16, (t.y - 3) * 16)),
		"a shot through the trunk is stopped")
	d.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_STUMP)
	check_eq(Movement.is_blocked(d, t), Config.TREE_STUMP_BLOCKS, "the stump blocks (Config.TREE_STUMP_BLOCKS)")


# --- chopping -----------------------------------------------------------------------------------------------

func _check_chop() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var t: Vector2i = Forest.tree_cells(d)[3]
	var feet: Vector2 = on(t + Vector2i(0, 1))
	check_eq(Forest.chop_refusal(d, feet, &"axe", t), "", "the axe at a trunk in reach")
	for item: StringName in [&"pickaxe", &"sickle", &"sword", &"hoe", &"pickaxe_t1", &""]:
		check_eq(Forest.chop_refusal(d, feet, item, t), Forest.WHY_NOT_AXE, "%s does not chop" % item)
	check_eq(Forest.chop_refusal(d, on(t + Vector2i(0, 3)), &"axe", t), WorldItems.WHY_REACH, "out of reach")
	check_eq(Forest.chop_refusal(d, feet, &"axe", t + Vector2i(1, 1)), Forest.WHY_NO_TREE, "no tree there")
	check_eq(Forest.impact_tick(), Config.AXE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS, "the axe lands on its frame 3")
	check_eq(Forest.impact_tick(), 18, "tick 18 (like the pickaxe and the hoe)")
	# Every class chops alike (● R37 anyone): five swings, the fifth fells it.
	for class_id: String in Config.CLASSES:
		var w: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		var forest: Forest = Forest.new(w)
		var inv: Inventory = Inventory.new()
		inv.add(&"axe", 1)
		var hits: Array[int] = []
		var felled: Array[bool] = []
		for i: int in Config.TREE_CHOP_HITS:
			var r: Forest.Result = forest.chop(on(t + Vector2i(1, 1)), inv, &"axe", t)
			hits.append(r.hits)
			felled.append(r.felled)
			if i < Config.TREE_CHOP_HITS - 1:
				check(r.ok() and r.edits.is_empty(), "%s swing %d: no edit yet" % [class_id, i + 1])
			apply(w, r.edits)
		check_eq(hits, [1, 2, 3, 4, 5] as Array[int], "%s: five swings counted" % class_id)
		check_eq(felled, [false, false, false, false, true] as Array[bool], "%s: the fifth fells it" % class_id)
		check_eq(w.get_value(WorldData.Layer.PLACEABLE, t), WorldData.PLACEABLE_STUMP, "%s: a stump" % class_id)
		check_eq(inv.count_of(&"log"), Config.TREE_LOGS, "%s: %d logs" % [class_id, Config.TREE_LOGS])
		check_eq(Forest.chop_refusal(w, on(t + Vector2i(1, 1)), &"axe", t), Forest.WHY_NO_TREE, "%s: a stump is no tree" % class_id)
	check_eq([Config.TREE_CHOP_HITS, Config.TREE_LOGS], [5, 4], "the provisional numbers")
	# A full inventory: the logs lie on the trunk tile; at MAX_DROPS they are lost.
	var full: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var forest2: Forest = Forest.new(full)
	var stuffed: Inventory = Inventory.new()
	stuffed.add(&"axe", 1)
	for i2: int in stuffed.size() - 1:
		stuffed.add(&"sword", 1)
	var r2: Forest.Result = null
	for i3: int in Config.TREE_CHOP_HITS:
		r2 = forest2.chop(feet, stuffed, &"axe", t)
		apply(full, r2.edits)
	check(r2.felled and r2.logs == 0 and r2.dropped == Config.TREE_LOGS, "a full inventory: the logs dropped (%s)" % r2.describe())
	var logs: Array[WorldData.Drop] = full.drops_at(t)
	check(logs.size() == 1 and logs[0].item == &"log" and logs[0].count == Config.TREE_LOGS, "one drop of logs on the stump's tile")
	var crowded: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	for k: int in Config.MAX_DROPS:
		crowded.drops[k + 1] = WorldData.Drop.new(k + 1, &"stone_a", 1, 0, Vector2i(8, 8))
	var forest3: Forest = Forest.new(crowded)
	var r3: Forest.Result = null
	for i4: int in Config.TREE_CHOP_HITS:
		r3 = forest3.chop(feet, stuffed, &"axe", t)
	check(r3.felled and r3.lost == Config.TREE_LOGS and r3.dropped == 0, "the map at MAX_DROPS: the logs lost")
	# The swings a tree took are its own (two trees).
	var two: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var f4: Forest = Forest.new(two)
	var t2: Vector2i = Forest.tree_cells(two)[4]
	var inv4: Inventory = Inventory.new()
	f4.chop(feet, inv4, &"axe", t)
	f4.chop(feet, inv4, &"axe", t)
	var other: Forest.Result = f4.chop(on(t2 + Vector2i(0, 1)), inv4, &"axe", t2)
	check_eq([f4.hits.get(t, 0), other.hits], [2, 1], "each tree counts its own swings")


func _check_regrowth() -> void:
	check_eq(Config.TREE_REGROW_TICKS, 5 * 60 * 60, "the provisional regrowth: five minutes")
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var t: Vector2i = Forest.tree_cells(d)[5]
	var forest: Forest = Forest.new(d)
	forest.regrow_ticks = 40
	var inv: Inventory = Inventory.new()
	for i: int in Config.TREE_CHOP_HITS:
		apply(d, forest.chop(on(t + Vector2i(0, 1)), inv, &"axe", t).edits)
	var grown_at: int = -1
	for tick: int in 60:
		var edits: Array[EditLog.WorldEdit] = forest.step()
		if not edits.is_empty():
			grown_at = tick + 1
			check(edits.size() == 1 and edits[0].cell == t and edits[0].value == WorldData.PLACEABLE_TREE, "one edit: the tree back")
			apply(d, edits)
	check_eq(grown_at, 40, "the stump grew back after 40 ticks")
	check_eq(d.get_value(WorldData.Layer.PLACEABLE, t), WorldData.PLACEABLE_TREE, "a tree again")
	check_eq(forest.stat("regrown"), 1, "counted")
	# A stump in a world loaded later (setup) waits the whole time; a stump taken away by another edit is forgotten.
	var d2: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	d2.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_STUMP)
	var f2: Forest = Forest.new()
	f2.regrow_ticks = 5
	f2.setup(d2)
	check_eq(f2.regrow.get(t, -1), 5, "setup: the stump waits")
	d2.set_value(WorldData.Layer.PLACEABLE, t, WorldData.PLACEABLE_NONE)
	check(f2.step().is_empty() and not f2.regrow.has(t), "gone: forgotten, nothing grows")
	# Regrowth 0 (Forest.regrow_ticks): the stump stays.
	var d3: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var f3: Forest = Forest.new(d3)
	f3.regrow_ticks = 0
	for i2: int in Config.TREE_CHOP_HITS:
		apply(d3, f3.chop(on(t + Vector2i(0, 1)), inv, &"axe", t).edits)
	var none: bool = true
	for tick2: int in 100:
		none = none and f3.step().is_empty()
	check(none, "no regrowth with 0")
	check_eq(d3.get_value(WorldData.Layer.PLACEABLE, t), WorldData.PLACEABLE_STUMP, "the stump stays")


# --- the axe's action ------------------------------------------------------------------------------------------

func _check_axe_action() -> void:
	check(RigData.is_action(RigData.Anim.AXE) and RigData.ACTION_ANIMS.has(RigData.Anim.AXE), "the axe is a body action")
	check(not RigData.is_pose(RigData.Anim.AXE), "not a pose")
	check_eq(RigData.ANIM_NAMES[RigData.Anim.AXE], "axe", "its name")
	check_eq(ItemDB.get_def(&"axe").action, RigData.Anim.AXE, "the axe item plays it")
	check_eq(Player.action_ticks(RigData.Anim.AXE), 6 * Config.ACTION_FRAME_TICKS, "six frames of ACTION_FRAME_TICKS")
	check_eq(Player.impact_tick_of(&"axe", RigData.Anim.AXE), 18, "the axe lands on tick 18")
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var t: Vector2i = Forest.tree_cells(d)[0]
	var p: Player = Player.new()
	p.setup(d, "archer", on(t + Vector2i(0, 1)), RigData.Dir.NORTH)
	_nodes.append(p)
	p.inventory.add(&"axe", 1)
	p.inventory.select(0)
	var impacts: Array[int] = []
	var tick: Array[int] = [0]
	p.action_impact.connect(func(item: StringName, anim: int, cell: Vector2i) -> void:
		if item == &"axe" and anim == RigData.Anim.AXE and cell == t:
			impacts.append(tick[0]))
	var started: Array[int] = []
	var started_at: Array[int] = []
	p.action_started.connect(func(_i: StringName, anim: int, _c: Vector2i) -> void:
		started.append(anim)
		started_at.append(tick[0]))
	for i: int in 2 * Player.action_ticks(RigData.Anim.AXE):
		tick[0] = i
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, Vector2(t * 16) + Vector2(8, 8), true, i == 0, true, TICK)
	check_eq(started, [RigData.Anim.AXE, RigData.Anim.AXE] as Array[int], "held: two swings in two action lengths")
	check(impacts.size() == 2 and started_at.size() == 2 and impacts[0] == started_at[0] + 18 and impacts[1] == started_at[1] + 18,
		"one impact a swing, on its tick 18 (started %s, landed %s)" % [started_at, impacts])
	check_eq(p.facing, RigData.Dir.NORTH, "facing the tree")


# --- the pictures -----------------------------------------------------------------------------------------------

static func _box(tex: Texture2D) -> Rect2i:
	var img: Image = LightGen.to_rgba8(tex.get_image())
	var lo: Vector2i = Vector2i(img.get_width(), img.get_height())
	var hi: Vector2i = Vector2i(-1, -1)
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 >= 128:
				lo = lo.min(Vector2i(x, y))
				hi = hi.max(Vector2i(x, y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


func _check_view() -> void:
	var tree_box: Rect2i = _box(FixtureView.TREE)
	var stump_box: Rect2i = _box(FixtureView.STUMP)
	check_eq(FixtureView.TREE.get_size(), Vector2(64, 80), "the tree canvas 64x80")
	check_eq(FixtureView.STUMP.get_size(), Vector2(64, 80), "the stump on the same canvas")
	check_eq(tree_box.end.y - 1, 72, "the tree's opaque bottom row: 72")
	check_eq(stump_box.end.y - 1, 72, "the stump's: 72")
	check_eq(tree_box, Rect2i(6, 2, 53, 71), "the tree's opaque box (the art notes: x 6-58, y 2-72)")
	check(stump_box.position.x <= 32 and stump_box.end.x > 33, "the stump stands on the trunk's columns")
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var trees: Array[Vector2i] = Forest.tree_cells(w.data)
	var bad: int = 0
	for t: Vector2i in trees:
		var n: Node2D = w.fixtures.nodes.get(t, null)
		if n == null or n.get_parent() != w.entities or n.position != Vector2(t.x * 16 + 8, (t.y + 1) * 16):
			bad += 1
			continue
		var s: Sprite2D = n.get_node(^"Sprite") as Sprite2D
		var want_origin: Vector2 = Vector2(t.x * 16 + 8 - 32, (t.y + 1) * 16 - 1 - 72)
		if s.texture != FixtureView.TREE or s.global_position != want_origin or s.centered or s.light_mask != Config.LIGHT_LAYER_WORLD:
			bad += 1
	check_eq(bad, 0, "every tree: a node at its tile's bottom edge among the entities, its picture at (x*16+8-32, (y+1)*16-1-72)")
	var fx: Dictionary[String, int] = w.fixtures.verify()
	check(fx["trees"] == trees.size() and fx["mismatches"] == 0, "the fixture view has every tree (%s)" % fx)
	var t0: Vector2i = trees[0]
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, t0, WorldData.PLACEABLE_STUMP))
	var s2: Sprite2D = (w.fixtures.nodes[t0] as Node2D).get_node(^"Sprite") as Sprite2D
	check(s2.texture == FixtureView.STUMP and s2.global_position == Vector2(t0.x * 16 + 8 - 32, (t0.y + 1) * 16 - 1 - 72),
		"felled: the stump's picture in the same place")
	check_eq(w.fixtures.verify()["mismatches"], 0, "the view follows")
	# The shake (PLACEHOLDER): the picture moves 1 px aside for a moment, then stands again.
	w.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, t0, WorldData.PLACEABLE_TREE))
	var s3: Sprite2D = (w.fixtures.nodes[t0] as Node2D).get_node(^"Sprite") as Sprite2D
	var rest: float = s3.position.x
	w.fixtures.shake(t0)
	w.fixtures._process(0.0)
	check_eq(s3.position.x, rest + 1.0, "a chop: the tree moves 1 px")
	w.fixtures._shakes[t0] = Time.get_ticks_msec() - 1000
	w.fixtures._process(0.0)
	check_eq(s3.position.x, rest, "then stands again")


# --- main.tscn -------------------------------------------------------------------------------------------------

func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null and main.trees_on, "main has an offline player and forests"):
		return
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	var data: WorldData = main.world.data
	var t: Vector2i = Forest.tree_cells(data)[0]
	p.inventory.clear()
	p.inventory.add(&"axe", 1)
	p.inventory.select(0)
	p.teleport(on(t + Vector2i(0, 1)))
	var swings: int = Config.TREE_CHOP_HITS * Player.action_ticks(RigData.Anim.AXE) + 4
	for i: int in swings:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, Vector2(t * 16) + Vector2(8, 8), true, i == 0, true, TICK)
		main.step_combat(TICK)
		main.step_forests()
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, t), WorldData.PLACEABLE_STUMP, "an axe held at a tree fells it")
	check_eq(p.inventory.count_of(&"log"), Config.TREE_LOGS, "the logs in the inventory")
	check_eq(main.world.fixtures.verify()["mismatches"], 0, "the stump drawn")
	check_eq(main.forests[Config.MAP_SURFACE].stat("felled"), 1, "one felled")
	# The stump grows back (the forest steps every physics tick; shortened here).
	main.forests[Config.MAP_SURFACE].regrow[t] = 2
	main.step_forests()
	main.step_forests()
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, t), WorldData.PLACEABLE_TREE, "and grows back")


# --- interplay ---------------------------------------------------------------------------------------------------

func _check_interplay() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var t: Vector2i = Forest.tree_cells(d)[0]
	check(not Farming.till_refusal(d, on(t + Vector2i(0, 1)), t).is_empty(), "no tilling a trunk")
	var inv: Inventory = Inventory.new()
	inv.add(&"stone_wall", 4)
	check_eq(Building.refusal(d, on(t + Vector2i(1, 1)), &"stone_wall", t, 4), WorldItems.WHY_NOT_OPEN, "no wall on a trunk")
	check_eq(WorldItems.place(d, on(t + Vector2i(0, 1)), inv_torch(), 0, t).why, WorldItems.WHY_NOT_OPEN, "no torch on a trunk")
	apply(d, AltarMove.pickup_edits(d))
	check_eq(AltarMove.place_refusal(d, Rect2i(t - Vector2i(1, 1), Vector2i(3, 3))), AltarMove.WHY_NOT_OPEN, "no altar on a trunk")
	check_eq(Mining.strike(d, on(t + Vector2i(0, 1)), "miner", Inventory.new(), t).why, Mining.WHY_NO_WALL, "a pickaxe at a tree: no wall")


static func inv_torch() -> Inventory:
	var inv: Inventory = Inventory.new()
	inv.add(&"torch", 1)
	return inv


# --- a session --------------------------------------------------------------------------------------------------

func _check_session() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"TreesTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var t: Vector2i = Forest.tree_cells(world.data)[0]
	var m: NetMember = s.add_member(2, 7, "herbalist", on(t + Vector2i(0, 1)), RigData.Dir.NORTH)
	m.gate = InputGate.new()
	m.player.inventory.clear()
	m.player.inventory.add(&"axe", 1)
	var seq: int = 1
	var anims: Array[int] = []
	for i: int in Config.TREE_CHOP_HITS * Player.action_ticks(RigData.Anim.AXE) + 2:
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(seq, Vector2i.ZERO)
		seq += 1
		if m.player.action_anim < 0:
			f.op = NetProtocol.Op.USE
			f.slot = 0
			f.cell = t
			f.map = Config.MAP_SURFACE
		m.player.begin_tick()
		host.run_frame(m, f)
		m.refill_ops()
		if m.player.action_anim >= 0 and m.player.action_tick == 0:
			anims.append(m.player.action_anim)
	check(anims.size() >= Config.TREE_CHOP_HITS and anims.has(RigData.Anim.AXE), "the host plays the axe's swings (%d)" % anims.size())
	check_eq(world.data.get_value(WorldData.Layer.PLACEABLE, t), WorldData.PLACEABLE_TREE, "the tree stands")
	check(m.refused(Forest.WHY_OFFLINE) >= Config.TREE_CHOP_HITS, "each swing counted: chopping offline only")
	check_eq(s.log_for(Config.MAP_SURFACE).size(), 0, "no edit on the host's map")
	check_eq(m.player.inventory.count_of(&"log"), 0, "no log")


## The same chopping twice: the same world hash and inventory.
func _check_determinism() -> void:
	var out: PackedStringArray = []
	for run_i: int in 2:
		var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
		var forest: Forest = Forest.new(d)
		forest.regrow_ticks = 30
		var inv: Inventory = Inventory.new()
		var line: PackedStringArray = []
		for t: Vector2i in Forest.tree_cells(d).slice(0, 3):
			for i: int in Config.TREE_CHOP_HITS:
				apply(d, forest.chop(on(t + Vector2i(0, 1)), inv, &"axe", t).edits)
			for k: int in 10:
				apply(d, forest.step())
			line.append(d.content_hash())
		for k2: int in 40:
			apply(d, forest.step())
		line.append(d.content_hash())
		line.append(inv.describe())
		out.append("|".join(line))
	check_eq(out[0], out[1], "the same chopping twice: the same worlds and logs")
