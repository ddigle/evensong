extends "res://tests/base_test.gd"
## M3a mining and torches: the wall byte (kind + hits), faces and who a hit lands on, crack stages,
## a common player (1x1, slow, hardness cap) against the miner (3x3, double hits, higher hardness:
## ● gameplay-design §3.0 R11; the numbers PROVISIONAL), the 3x3 shapes (reaching away / centred),
## hits accumulating until a tile breaks, what a broken tile gives (stone / ore into the inventory, a
## drop when it does not fit, lost past MAX_DROPS), bedrock and the exit's rock unbreakable, a wall
## torch falling with its wall, the pickaxe on the surface (no effect), the crack overlays, torch
## placement (rules, no blocking, its light, not the safe zone), the host running both (run_frame:
## a torch USE, a pickaxe swing landing on its impact tick) and offline main.tscn (a bot mining in
## the dungeon: hits, breaks, the view follows).

func run() -> Array[String]:
	_check_walls()
	_check_crack_stage()
	_check_area_shapes()
	_check_common()
	_check_miner()
	_check_items_and_full()
	_check_unbreakable_and_surface()
	_check_crack_view()
	_check_torch_rules()
	await _check_torch_view()
	await _check_host()
	await _check_offline_main()
	return failures


## A cave: bedrock ring, rock inside, `open` rects carved (tests/test_dungeon.gd has the same).
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


static func _feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * Config.TILE + Config.TILE / 2, cell.y * Config.TILE + Config.TILE - 2)


static func _apply(d: WorldData, r: Mining.Result) -> void:
	for e: EditLog.WorldEdit in r.edits:
		EditLog.apply_to_data(d, e)


func _check_walls() -> void:
	check_eq(Walls.pack(Walls.KIND_ROCK, 5), 1 | (5 << 4), "wall byte = kind | hits << 4")
	var d: WorldData = _cave(Vector2i(10, 10), [Rect2i(3, 3, 4, 4)])
	d.set_value(WorldData.Layer.WALL, Vector2i(2, 4), Walls.pack(Walls.KIND_ROCK, 3))
	check(Walls.kind_at(d, Vector2i(2, 4)) == Walls.KIND_ROCK and Walls.hits_at(d, Vector2i(2, 4)) == 3, "kind and hits read back")
	check(Walls.is_face(d, Vector2i(4, 3)) and not Walls.is_face(d, Vector2i(4, 4)), "the room's top row is the north wall's face")
	check_eq(Walls.owner_of(d, Vector2i(4, 3)), Vector2i(4, 2), "a hit on a face lands on the wall above it")
	check_eq(Walls.owner_of(d, Vector2i(2, 4)), Vector2i(2, 4), "a hit on a wall lands on it")
	check_eq(Walls.owner_of(d, Vector2i(4, 5)), Walls.NO_CELL, "open floor: nothing")
	check_eq(Walls.vertex(d, Vector2i(4, 3)), Walls.V_FACE, "render value of a face")
	check_eq(Walls.vertex(d, Vector2i(-1, 4)), Walls.V_WALL, "outside the map draws as wall")
	d.set_value(WorldData.Layer.ORE, Vector2i(6, 2), Walls.ORE_IRON)
	d.set_value(WorldData.Layer.ORE, Vector2i(2, 5), Walls.ORE_COPPER)
	check_eq([Walls.hardness(d, Vector2i(2, 6)), Walls.hardness(d, Vector2i(2, 5)), Walls.hardness(d, Vector2i(6, 2)),
		Walls.hardness(d, Vector2i(0, 0))], [Config.HARDNESS_ROCK, Config.HARDNESS_COPPER, Config.HARDNESS_IRON, Walls.UNBREAKABLE],
		"hardness: rock, copper, iron, bedrock")
	check_eq([Walls.max_hits(d, Vector2i(2, 6)), Walls.max_hits(d, Vector2i(2, 5)), Walls.max_hits(d, Vector2i(6, 2)),
		Walls.max_hits(d, Vector2i(0, 0))], [Config.WALL_HITS_ROCK, Config.WALL_HITS_COPPER, Config.WALL_HITS_IRON, 0],
		"hits to break: rock, copper, iron, bedrock (never)")
	# A blocking placeable on a face (the exit stairs) makes the rock above it unbreakable by itself,
	# whatever the rock is (the generator also turns it into bedrock).
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(5, 3), WorldData.PLACEABLE_EXIT)
	check_eq(Walls.hardness(d, Vector2i(5, 2)), Walls.UNBREAKABLE, "rock over the exit stairs cannot be broken")
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(5, 3), WorldData.PLACEABLE_TORCH)
	check_eq(Walls.hardness(d, Vector2i(5, 2)), Config.HARDNESS_ROCK, "a torch below does not protect the rock")
	d.set_value(WorldData.Layer.PLACEABLE, Vector2i(5, 3), 0)


func _check_crack_stage() -> void:
	var got: Array[int] = []
	for h: int in range(0, 7):
		got.append(Walls.crack_stage(h, 6))
	check_eq(got, [0, 1, 1, 2, 2, 3, 3] as Array[int], "crack stage by thirds of 6 hits")
	check_eq([Walls.crack_stage(1, 10), Walls.crack_stage(4, 10), Walls.crack_stage(7, 10), Walls.crack_stage(9, 10)],
		[1, 2, 3, 3], "and of 10")
	check_eq(Walls.crack_stage(3, 0), 0, "an unbreakable wall shows no crack")


func _check_area_shapes() -> void:
	var o: Vector2i = Vector2i(10, 10)
	check_eq(Mining.area(o, Vector2i(9, 10), "paladin"), [o] as Array[Vector2i], "a common player hits the one tile")
	var east: Array[Vector2i] = Mining.area(o, Vector2i(9, 10), Mining.MINER_CLASS)
	check_eq(east.size(), 9, "the miner hits 3x3")
	if Config.MINER_AREA_AWAY:
		check(east.has(Vector2i(12, 9)) and east.has(Vector2i(10, 11)) and not east.has(Vector2i(9, 10)),
			"aiming east: x 10..12, y 9..11 (away from the player, centred across)")
		var ne: Array[Vector2i] = Mining.area(o, Vector2i(9, 11), Mining.MINER_CLASS)
		check(ne.has(Vector2i(12, 8)) and ne.has(Vector2i(10, 10)) and not ne.has(Vector2i(9, 10)), "diagonal north-east: x 10..12, y 8..10")
		var north: Array[Vector2i] = Mining.area(o, Vector2i(10, 12), Mining.MINER_CLASS)
		check(north.has(Vector2i(9, 8)) and north.has(Vector2i(11, 10)) and not north.has(Vector2i(10, 11)),
			"two tiles north (through a face): x 9..11, y 8..10")
	else:
		check(east.has(Vector2i(9, 9)) and east.has(Vector2i(11, 11)), "centred on the hit tile")


func _check_common() -> void:
	# Room x 3..8, y 3..8; the player stands at (3, 5) and swings west at the wall (2, 5).
	var d: WorldData = _cave(Vector2i(12, 12), [Rect2i(3, 3, 6, 6)])
	var inv: Inventory = Inventory.new()
	var feet: Vector2 = _feet(Vector2i(3, 5))
	var target: Vector2i = Vector2i(2, 5)
	var swings: int = 0
	var stages: Array[int] = []
	while Walls.is_wall(d, target) and swings < 20:
		var r: Mining.Result = Mining.strike(d, feet, "paladin", inv, target)
		_apply(d, r)
		swings += 1
		check_eq(r.hit, [target] as Array[Vector2i], "swing %d hits the one tile" % swings)
		stages.append(Walls.crack_stage(Walls.hits_at(d, target), Walls.max_hits(d, target)))
	check_eq(swings, Config.WALL_HITS_ROCK / Config.MINING_POWER_COMMON, "a common player breaks rock in %d swings" % swings)
	check_eq(stages, [1, 1, 2, 2, 3, 0] as Array[int], "the crack grows by stages, gone when broken")
	check(Walls.is_wall(d, Vector2i(2, 4)) and Walls.is_wall(d, Vector2i(2, 6)) and Walls.hits_at(d, Vector2i(2, 4)) == 0,
		"only the target took hits")
	check_eq(inv.count_of(Config.MINED_ROCK_ITEM), 1, "the broken rock gives a stone into the inventory")
	# Iron is above a common player's cap: the swing does nothing.
	d.set_value(WorldData.Layer.ORE, Vector2i(2, 6), Walls.ORE_IRON)
	var r2: Mining.Result = Mining.strike(d, _feet(Vector2i(3, 6)), "archer", inv, Vector2i(2, 6))
	check(r2.why == Mining.WHY_TOO_HARD and r2.edits.is_empty(), "iron is too hard for a common player")
	# Out of reach (two tiles away) does nothing.
	var r3: Mining.Result = Mining.strike(d, _feet(Vector2i(4, 6)), "archer", inv, Vector2i(2, 6))
	check(not r3.ok() and r3.edits.is_empty(), "a wall two tiles away cannot be hit")


func _check_miner() -> void:
	var d: WorldData = _cave(Vector2i(14, 12), [Rect2i(2, 3, 3, 6)])
	var inv: Inventory = Inventory.new()
	var feet: Vector2 = _feet(Vector2i(4, 5))
	d.set_value(WorldData.Layer.ORE, Vector2i(6, 4), Walls.ORE_IRON)
	var swings: int = 0
	var hit_sizes: Array[int] = []
	while Walls.is_wall(d, Vector2i(5, 5)) and swings < 20:
		var r: Mining.Result = Mining.strike(d, feet, Mining.MINER_CLASS, inv, Vector2i(5, 5))
		_apply(d, r)
		swings += 1
		hit_sizes.append(r.hit.size())
	check_eq(hit_sizes, [9, 9, 9] as Array[int], "every swing of the miner hits the whole 3x3 (iron included)")
	check_eq(swings, ceili(float(Config.WALL_HITS_ROCK) / Config.MINING_POWER_MINER), "the miner breaks rock in %d swings" % swings)
	var open: int = 0
	for y: int in range(4, 7):
		for x: int in range(5, 8):
			if not Walls.is_wall(d, Vector2i(x, y)):
				open += 1
	check_eq(open, 8, "a 3x3 hole east of the miner, but the iron tile (harder) still stands")
	check(Walls.is_wall(d, Vector2i(6, 4)) and Walls.hits_at(d, Vector2i(6, 4)) == swings * Config.MINING_POWER_MINER,
		"the iron took the same hits (miner's cap is higher)")
	check(Walls.is_wall(d, Vector2i(8, 5)) and Walls.is_wall(d, Vector2i(5, 3)) and Walls.is_wall(d, Vector2i(5, 7)),
		"nothing outside the 3x3")
	check_eq(inv.count_of(Config.MINED_ROCK_ITEM), 8, "8 stones")
	while Walls.is_wall(d, Vector2i(6, 4)):
		_apply(d, Mining.strike(d, _feet(Vector2i(5, 5)), Mining.MINER_CLASS, inv, Vector2i(6, 4)))
	check_eq(inv.count_of(&"ore_iron"), 1, "the iron tile gives iron ore")
	check_eq(Walls.ore_at(d, Vector2i(6, 4)), Walls.ORE_NONE, "and its ore is gone from the layer")


func _check_items_and_full() -> void:
	var d: WorldData = _cave(Vector2i(12, 12), [Rect2i(3, 3, 6, 6)])
	d.set_value(WorldData.Layer.WALL, Vector2i(2, 5), Walls.pack(Walls.KIND_ROCK, Config.WALL_HITS_COPPER - 1))
	d.set_value(WorldData.Layer.ORE, Vector2i(2, 5), Walls.ORE_COPPER)
	var full: Inventory = Inventory.new()
	for i: int in Config.INVENTORY_SLOTS:
		full.add(&"sword", 1)
	var r: Mining.Result = Mining.strike(d, _feet(Vector2i(3, 5)), "cleric", full, Vector2i(2, 5))
	_apply(d, r)
	var dropped_copper: int = r.dropped.get(&"ore_copper", 0)
	check(r.broken.size() == 1 and dropped_copper == 1 and r.gained.is_empty(),
		"a full inventory: the copper ore is dropped (%s)" % r.describe())
	var here: Array[WorldData.Drop] = d.drops_at(Vector2i(2, 5))
	check(here.size() == 1 and here[0].item == &"ore_copper" and here[0].count == 1, "on the broken tile")
	# At MAX_DROPS the ground takes no more: the item is lost.
	var d2: WorldData = _cave(Vector2i(12, 12), [Rect2i(3, 3, 6, 6)])
	for i: int in Config.MAX_DROPS:
		d2.drops[i + 1] = WorldData.Drop.new(i + 1, &"stone_a", 1, ItemDB.Grade.NONE, Vector2i(80, 80))
	d2.set_value(WorldData.Layer.WALL, Vector2i(2, 5), Walls.pack(Walls.KIND_ROCK, Config.WALL_HITS_ROCK - 1))
	var r2: Mining.Result = Mining.strike(d2, _feet(Vector2i(3, 5)), "cleric", full, Vector2i(2, 5))
	check(r2.lost == 1 and r2.dropped.is_empty(), "past MAX_DROPS the item is lost")
	# A wall torch falls with its wall.
	var d3: WorldData = _cave(Vector2i(12, 12), [Rect2i(3, 3, 6, 6)])
	d3.set_value(WorldData.Layer.PLACEABLE, Vector2i(5, 2), WorldData.PLACEABLE_WALL_TORCH)
	d3.set_value(WorldData.Layer.WALL, Vector2i(5, 2), Walls.pack(Walls.KIND_ROCK, Config.WALL_HITS_ROCK - 1))
	_apply(d3, Mining.strike(d3, _feet(Vector2i(5, 4)), "cleric", Inventory.new(), Vector2i(5, 3)))
	check(not Walls.is_wall(d3, Vector2i(5, 2)) and d3.get_value(WorldData.Layer.PLACEABLE, Vector2i(5, 2)) == 0,
		"breaking a wall through its face (from two tiles south) takes its wall torch down")


func _check_unbreakable_and_surface() -> void:
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var exit: Rect2i = DungeonGen.exit_rect(d)
	var feet: Vector2 = DungeonGen.arrival_point(d)
	var inv: Inventory = Inventory.new()
	var r: Mining.Result = Mining.strike(d, feet, Mining.MINER_CLASS, inv, exit.position)
	var touched_exit_rock: bool = false
	for c: Vector2i in r.hit:
		if c.y == exit.position.y - 1 and c.x >= exit.position.x and c.x < exit.end.x:
			touched_exit_rock = true
	check(not touched_exit_rock, "the rock over the exit stairs cannot be mined")
	var b: WorldData = _cave(Vector2i(8, 8), [Rect2i(1, 1, 6, 6)])
	var rb: Mining.Result = Mining.strike(b, _feet(Vector2i(1, 3)), Mining.MINER_CLASS, inv, Vector2i(0, 3))
	check(rb.why == Mining.WHY_TOO_HARD and rb.edits.is_empty(), "the bedrock border: nothing but the swing")
	var s: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var spawn: Vector2 = s.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0])
	var rs: Mining.Result = Mining.strike(s, spawn, Mining.MINER_CLASS, inv, Aim.feet_cell(spawn) + Vector2i(-1, 0))
	check(rs.why == Mining.WHY_NO_WALL and rs.edits.is_empty(), "the pickaxe on the surface does nothing (M2 behaviour)")


func _check_crack_view() -> void:
	var d: WorldData = _cave(Vector2i(12, 12), [Rect2i(3, 3, 6, 6)])
	var view: CaveView = add_node(CaveView.new()) as CaveView
	view.setup(d)
	# Hit the face (5, 3) from (5, 4): the wall (5, 2) shows both cracks; hit the side wall (2, 5) from
	# (3, 5): a top crack only (rock below it, no face).
	for strike: Array in [[Vector2i(5, 4), Vector2i(5, 3)], [Vector2i(3, 5), Vector2i(2, 5)]]:
		var at: Vector2i = strike[0]
		var target: Vector2i = strike[1]
		var r: Mining.Result = Mining.strike(d, _feet(at), "paladin", Inventory.new(), target)
		for e: EditLog.WorldEdit in r.edits:
			EditLog.apply_to_data(d, e)
			view.redraw_wall(e.cell)
	var faced: Array = view.cracks.get(Vector2i(5, 2), [])
	var side: Array = view.cracks.get(Vector2i(2, 5), [])
	check_eq(faced.size(), 2, "a faced wall shows a top and a face crack")
	check_eq(side.size(), 1, "a side wall shows a top crack")
	if faced.size() == 2:
		var face: Sprite2D = faced[1]
		check_eq(face.position, Vector2(5 * 16, 2 * 16 + 8 + Config.FACE_TOP_PX), "the face crack starts where the face does")
		check_eq((face.texture as AtlasTexture).region, Rect2(0, 0, 16, Config.FACE_HEIGHT_PX), "stage 1 of the face art")
	if side.size() == 1:
		var top: Sprite2D = side[0]
		check_eq(top.position, Vector2(2 * 16, 5 * 16), "the top crack on the tile")
	check_eq(view.verify()["overlay_mismatches"], 0, "overlays = data")


func _check_torch_rules() -> void:
	var d: WorldData = _cave(Vector2i(12, 12), [Rect2i(3, 3, 6, 6)])
	d.set_value(WorldData.Layer.VEGETATION, Vector2i(6, 6), WorldItems.value_of(&"mushroom_a"))
	var inv: Inventory = Inventory.new()
	inv.add(&"torch", 3)
	inv.add(&"pickaxe", 1)
	var feet: Vector2 = _feet(Vector2i(5, 5))
	var o: WorldItems.Outcome = WorldItems.place(d, feet, inv, 0, Vector2i(6, 5))
	check(o.ok() and inv.count_of(&"torch") == 2 and o.edits.size() == 1 and o.edits[0].layer == WorldData.Layer.PLACEABLE
		and o.edits[0].value == WorldData.PLACEABLE_TORCH, "a torch goes on open floor next to the feet")
	for e: EditLog.WorldEdit in o.edits:
		EditLog.apply_to_data(d, e)
	check(not Movement.is_blocked(d, Vector2i(6, 5)), "and does not block")
	var cases: Array[Array] = [
		[_feet(Vector2i(5, 5)), 0, Vector2i(6, 5), WorldItems.WHY_NOT_OPEN, "on a torch"],
		[_feet(Vector2i(5, 4)), 0, Vector2i(5, 3), WorldItems.WHY_NOT_OPEN, "on a wall face"],
		[_feet(Vector2i(3, 4)), 0, Vector2i(2, 4), WorldItems.WHY_NOT_OPEN, "on a wall"],
		[_feet(Vector2i(5, 5)), 0, Vector2i(6, 6), WorldItems.WHY_NOT_OPEN, "on a gatherable"],
		[_feet(Vector2i(5, 5)), 0, Vector2i(7, 5), WorldItems.WHY_REACH, "two tiles away"],
		[_feet(Vector2i(5, 5)), 1, Vector2i(4, 5), WorldItems.WHY_NOT_PLACEABLE, "with a pickaxe"],
		[_feet(Vector2i(5, 5)), 2, Vector2i(4, 5), WorldItems.WHY_EMPTY, "from an empty slot"],
	]
	for c: Array in cases:
		var f: Vector2 = c[0]
		var slot: int = c[1]
		var cell: Vector2i = c[2]
		var why: String = c[3]
		var label: String = c[4]
		check_eq(WorldItems.place(d, f, inv, slot, cell).why, why, "no torch %s" % label)
	check_eq(inv.count_of(&"torch"), 2, "refused placements keep the torches")
	var player: Player = Player.new()
	player.local_input = false
	player.setup(d, "cleric", feet, RigData.Dir.SOUTH)
	add_node(player)
	player.inventory.add(&"torch", 1)
	var f1: NetProtocol.InputFrame = player.make_frame(Vector2i.ZERO, feet + Vector2(16, 0), true, true, true)
	check(f1.op == NetProtocol.Op.USE and f1.anim == -1 and f1.cell == Vector2i(6, 5), "a click with a torch: a USE without an action")
	var f2: NetProtocol.InputFrame = player.make_frame(Vector2i.ZERO, feet + Vector2(16, 0), true, false, true)
	check_eq(f2.op, NetProtocol.Op.NONE, "holding does not place again")


func _check_torch_view() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = Config.MAP_DUNGEON
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	await await_frames(1)
	var feet: Vector2 = w.arrival_point()
	var cell: Vector2i = Aim.feet_cell(feet) + Vector2i(0, 1)
	var lights_before: int = w.lighting.torches.get_child_count()
	var inv: Inventory = Inventory.new()
	inv.add(&"torch", 1)
	var o: WorldItems.Outcome = WorldItems.place(w.data, feet, inv, 0, cell)
	check(o.ok(), "a torch south of the arrival point (%s)" % o.why)
	for e: EditLog.WorldEdit in o.edits:
		w.apply_edit(e)
	check(w.fixtures.nodes.has(cell) and w.lighting.torches.get_child_count() == lights_before + 1, "it is drawn with its light")
	check_eq(w.fixtures.verify()["mismatches"], 0, "fixtures = data")
	var light: PointLight2D = w.fixtures.light_nodes.get(cell, null)
	check(light != null and light.texture == TorchLight.texture_for(Config.TORCH_LIGHT_RADIUS_PX)
		and light.range_item_cull_mask == (Config.LIGHT_LAYER_WORLD | Config.LIGHT_LAYER_ACTORS), "a torch light on ground and actors")
	check(not w.is_in_safe_zone(Vector2(cell * Config.TILE)), "a torch is light, not the safe zone")
	var img: Image = TorchLight.image(Config.TORCH_LIGHT_RADIUS_PX)
	var c0: int = img.get_width() / 2
	check(img.get_pixel(c0, c0).a8 == 255 and img.get_pixel(c0 + Config.TORCH_LIGHT_RADIUS_PX, c0).a8 == 0,
		"the torch light is full in the middle and ends at its radius")


## The host: a torch USE places it; a pickaxe swing lands on its impact tick and mines the target.
func _check_host() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = Config.MAP_DUNGEON
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"TestNet"
	add_node(s)
	s.worlds = {Config.MAP_DUNGEON: w}
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHost.new(s)
	s.host = host
	var log: EditLog = s.log_for(Config.MAP_DUNGEON)
	var exit: Rect2i = DungeonGen.exit_rect(w.data)
	var feet: Vector2 = w.arrival_point()
	var m: NetMember = s.add_member(1, 9, Mining.MINER_CLASS, feet, RigData.Dir.NORTH, Config.MAP_DUNGEON)
	m.gate = InputGate.new()
	m.player.inventory.add(&"torch", 2)
	m.player.inventory.add(&"pickaxe", 1)
	var place: NetProtocol.InputFrame = NetProtocol.InputFrame.new(1, Vector2i.ZERO)
	place.op = NetProtocol.Op.USE
	place.map = Config.MAP_DUNGEON
	place.slot = 0
	place.cell = Aim.feet_cell(feet) + Vector2i(0, 1)
	host.run_frame(m, place)
	check(w.data.get_value(WorldData.Layer.PLACEABLE, place.cell) == WorldData.PLACEABLE_TORCH and log.size() == 1
		and m.player.inventory.count_of(&"torch") == 1 and m.inventory_dirty, "the host places a client's torch (edit + inventory)")
	# Walk the miner to a rock wall it can swing at: the tile west of the arrival room's west face row.
	var target: Vector2i = Vector2i(-1, -1)
	var stand: Vector2i = Vector2i(-1, -1)
	var standing: Dictionary[Vector2i, bool] = DungeonGen.reachable(w.data, Aim.feet_cell(feet))
	for c: Vector2i in standing:
		var west: Vector2i = c + Vector2i(-1, 0)
		if Walls.kind_at(w.data, west) == Walls.KIND_ROCK and Walls.hardness(w.data, west) <= Config.HARDNESS_CAP_MINER \
				and Walls.ore_at(w.data, west) == Walls.ORE_NONE:
			target = west
			stand = c
			break
	if not check(target.x >= 0, "a rock wall to swing at"):
		return
	m.player.teleport(Vector2(stand.x * 16 + 8, stand.y * 16 + 14))
	var edits_before: int = log.size()
	var use: NetProtocol.InputFrame = NetProtocol.InputFrame.new(2, Vector2i.ZERO)
	use.op = NetProtocol.Op.USE
	use.map = Config.MAP_DUNGEON
	use.slot = 1
	use.cell = target
	use.look = RigData.Dir.WEST
	host.run_frame(m, use)
	check_eq(m.player.action_anim, RigData.Anim.PICKAXE, "the swing starts")
	# Step frame by frame until the swing lands: it must be the first tick of the action's frame
	# Config.MINING_IMPACT_FRAME (frame 0 is the tick the swing starts).
	var landed_at: int = -1
	for t: int in range(1, PlayerSim.action_ticks(RigData.Anim.PICKAXE)):
		host.run_frame(m, NetProtocol.InputFrame.new(2 + t, Vector2i.ZERO))
		if log.size() > edits_before:
			landed_at = t
			break
	check_eq(landed_at, Config.MINING_IMPACT_FRAME * Config.ACTION_FRAME_TICKS,
		"the swing lands on the first tick of pickaxe frame %d" % (Config.MINING_IMPACT_FRAME + 1))
	check(log.size() > edits_before and Walls.hits_at(w.data, target) == Config.MINING_POWER_MINER,
		"the 3x3 takes the miner's hits (%d edits)" % (log.size() - edits_before))
	check_eq(s.edit_log.size(), 0, "M3b: the dungeon's edits are in the dungeon's log, not the surface's")
	var v: Dictionary[String, int] = w.cave.verify()
	check(v["mismatches"] == 0 and v["overlay_mismatches"] == 0, "the host's view follows its edits %s" % v)


## main.tscn offline: the miner goes down, a bot swings at a wall, it cracks and breaks.
func _check_offline_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn(Mining.MINER_CLASS)
	main.player.inventory.add(&"pickaxe", 1)
	main.player.inventory.select(0)
	main.travel(Config.MAP_DUNGEON)
	var w: GameWorld = main.current_world()
	var d: WorldData = w.data
	var exit: Rect2i = DungeonGen.exit_rect(d)
	# The rock east of the exit stairs' rock, over the arrival room's face: aim at the face tile two to the
	# right of the stairs (its wall is breakable rock).
	var face: Vector2i = Vector2i(exit.end.x + 1, exit.position.y)
	var feet_cell: Vector2i = face + Vector2i(0, 1)
	check(Walls.is_face(d, face) and not Movement.is_blocked(d, feet_cell), "a face to mine from the arrival room")
	main.player.teleport(Vector2(feet_cell.x * 16 + 8, feet_cell.y * 16 + 14))
	main.bot = NetBot.new()
	main.bot.parse("aimat:%d,%d;use:%d" % [face.x, face.y, PlayerSim.action_ticks(RigData.Anim.PICKAXE) * 4])
	main.player.local_input = false
	var owner: Vector2i = face + Vector2i(0, -1)
	await _physics(PlayerSim.action_ticks(RigData.Anim.PICKAXE) * 4 + 4)
	check(not Walls.is_wall(d, owner), "four swings of the miner break the rock over the face (%s)" % Walls.hits_at(d, owner))
	check(main.player.inventory.count_of(Config.MINED_ROCK_ITEM) >= 1, "stones in the miner's inventory")
	var v: Dictionary[String, int] = w.cave.verify()
	check(v["mismatches"] == 0 and v["overlay_mismatches"] == 0 and v["missing"] == 0, "the cave view follows %s" % v)


func _physics(n: int) -> void:
	for i: int in n:
		await tree.physics_frame
