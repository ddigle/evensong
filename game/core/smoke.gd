class_name Smoke
extends RefCounted
## Smoke checks for --smoke (also in the exported exe): the engine version, the display settings
## that reached the root window, the input map, the committed surface TileSet, and one generated
## world drawn with the ground view (corners, fallbacks, soil/ash, its hash = SurfaceGen.GOLDEN_HASH,
## the x86_64 result), the character art and rig tables, the body action sheets, item icons and M2a
## input actions, the safe-zone light texture against the rule, the flame mask, and the run scene.
## M3a: the surface world's dungeon entrance, the committed dungeon TileSet, the seed-1 dungeon (its
## hash = DungeonGen.GOLDEN_HASH, exit stairs, arrival point, shrine) drawn with the cave view.
## M3b: the dungeons of seeds 1..8 (DungeonGen.SEEDS_GOLDEN, printed as dungeon_seeds= for comparing
## another machine), wire v4 (a state with its map, a request aimed on a map, an edit naming its map,
## the map entry) and a mined dungeon (cracks, a break, a torch, a drop) through the map snapshot path
## into a cave view that draws it exactly.
## M6a: the recipes (six: three potions x two grades, who may brew them), a craft, the alchemy table art and
## its placement, a drink, a poison tick to down, a thrown poison potion that splashes a heretic. Printed as
## potions=<recipes>/<splash heretics>.
## M6b: wire v6: a THROW and a CRAFT on frames, a state with its effects block, a host arena's thrown potion as
## its thrown / broke events flown by a client's NetCombat on the host's points, the heretic's poison flag drawn
## on the client. Printed as potion_wire=<a state with effects>B/<a throw's two events>B.
## M5a: the seed items, the crops sheet and the watered soil art, and a crop on the seed-1 world's first lit soil tile:
## planted by the herbalist, kept wet, ripe after four stages at the herbalist's speed, harvested for FINE herbs and a
## seed. Printed as farm=<ticks to ripe>/<herbs>.
## M5b: holy water and the ash smear art; on the seed-1 world a finished channel at the first corrupted tile purifies
## its disc (the tiles turn to grass, no soil next to ash, the corruption count and the spawn tiles shrink), holy water
## purifies its 3x3; the altar picked up (no altar, no safe zone) and put down elsewhere (the light, the spawn slots and
## the reserved spots follow). Printed as purify=<channel tiles>+<holy water tiles>/<spawn tiles after> altar=<x>,<y>.
## M5c: wire v7: the CHANNEL, ALTAR_LIFT and ALTAR_PLACE requests on frames, a state with the channel and the carried altar,
## and a farm's growth on a host world reaching a client world as encoded edits (the same world). Printed as
## fields_wire=<a channelling carrier's state>B/<a crop's stage edit>B.
## Any mismatch -> exit code 1.
##
## Output: "EVENSONG_SMOKE ok key=value ..." or "EVENSONG_SMOKE FAIL <n> failure(s): a; b; ...".

const EXPECTED_VERSION: Vector3i = Vector3i(4, 7, 2)
const EXPECTED_SOURCES: int = 11       # 2 Wang sets + 4 grass + 2 soil + 3 ash variants
const EXPECTED_TILES: int = 40         # 16 + 15 (shared all-grass skipped) + 9 variants
const EXPECTED_EXACT_KEYS: int = 31    # 16 grass/soil + 16 grass/ash - 1 shared all-grass
const MOVE_KEYS: Dictionary[String, Array] = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
}


class Report:
	extends RefCounted
	var checks: int = 0
	var failures: PackedStringArray = []
	var fields: PackedStringArray = []

	func ok() -> bool:
		return failures.is_empty()

	func expect(condition: bool, message: String) -> bool:
		checks += 1
		if not condition:
			failures.append(message)
		return condition

	func expect_eq(actual: Variant, expected: Variant, what: String) -> bool:
		var same: bool = typeof(actual) == typeof(expected) and actual == expected
		return expect(same, "%s: expected %s, got %s" % [what, var_to_str(expected), var_to_str(actual)])

	func line() -> String:
		if ok():
			return "EVENSONG_SMOKE ok %s checks=%d" % [" ".join(fields), checks]
		return "EVENSONG_SMOKE FAIL %d failure(s) of %d checks: %s" % [failures.size(), checks, "; ".join(failures)]


static func run(tree: SceneTree) -> Report:
	var r: Report = Report.new()
	_check_engine(r)
	_check_window(r, tree.root)
	_check_input(r)
	var table: WangTable = _check_tileset(r)
	if table != null:
		_check_world(r, table)
	_check_dungeon(r)
	_check_actors(r)
	_check_items(r)
	_check_combat(r)
	_check_potions(r)
	_check_farm(r)
	_check_purify(r)
	_check_light(r)
	_check_net(r)
	r.fields.insert(0, "exported=%s" % str(OS.has_feature("template")))
	return r


static func _check_engine(r: Report) -> void:
	var info: Dictionary = Engine.get_version_info()
	var major: int = info.get("major", 0)
	var minor: int = info.get("minor", 0)
	var patch: int = info.get("patch", 0)
	r.expect_eq(Vector3i(major, minor, patch), EXPECTED_VERSION, "engine version")
	r.fields.append("godot=%s" % str(info.get("string", "?")))
	r.fields.append("display=%s" % DisplayServer.get_name())
	r.expect_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "forward_plus", "renderer")


static func _check_window(r: Report, root: Window) -> void:
	r.expect_eq(root.content_scale_size, Config.VIEW_SIZE, "root content_scale_size")
	r.expect_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT, "root content_scale_mode")
	r.expect_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER, "root content_scale_stretch")
	r.expect_eq(root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND, "root content_scale_aspect")
	r.expect_eq(root.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"root default texture filter")
	r.expect(root.snap_2d_transforms_to_pixel, "root snap_2d_transforms_to_pixel is off")
	r.expect(root.snap_2d_vertices_to_pixel, "root snap_2d_vertices_to_pixel is off")
	var window_w: int = ProjectSettings.get_setting("display/window/size/window_width_override", 0)
	var window_h: int = ProjectSettings.get_setting("display/window/size/window_height_override", 0)
	r.expect_eq(Vector2i(window_w, window_h), Config.WINDOW_SIZE, "default window size")
	r.fields.append("base=%dx%d" % [root.content_scale_size.x, root.content_scale_size.y])


static func _check_input(r: Report) -> void:
	for action: String in MOVE_KEYS:
		if not r.expect(InputMap.has_action(action), "input action %s missing" % action):
			continue
		var keys: Array[int] = []
		for event: InputEvent in InputMap.action_get_events(action):
			var key: InputEventKey = event as InputEventKey
			if key != null:
				keys.append(key.physical_keycode)
		var want: Array[int] = []
		want.assign(MOVE_KEYS[action])
		r.expect_eq(keys, want, "keys of %s" % action)


static func _check_tileset(r: Report) -> WangTable:
	var ts: TileSet = load(TilesetBuilder.SURFACE_PATH) as TileSet
	if not r.expect(ts != null, "cannot load %s" % TilesetBuilder.SURFACE_PATH):
		return null
	r.expect_eq(ts.get_source_count(), EXPECTED_SOURCES, "tileset sources")
	r.expect_eq(TilesetBuilder.count_tiles(ts), EXPECTED_TILES, "tileset tiles")
	for i: int in ts.get_source_count():
		var source: TileSetAtlasSource = ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
		r.expect(source != null and source.texture != null, "tileset source %d has no texture" % ts.get_source_id(i))
	var table: WangTable = WangTable.from_tile_set(ts)
	if not r.expect(table != null, "no Wang table from the tileset"):
		return null
	r.expect_eq(table.exact_keys, EXPECTED_EXACT_KEYS, "corner keys with art")
	for key: int in Terrain.KEY_COUNT:
		if table.entries[key].exact != Terrain.key_has_art(key):
			r.expect(false, "corner key %d: art=%s but table exact=%s" % [key, Terrain.key_has_art(key),
				table.entries[key].exact])
	return table


static func _check_world(r: Report, table: WangTable) -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	r.expect_eq(data.size, Config.MAP_SIZE, "world size")
	r.expect_eq(data.altar_rect, Rect2i((Config.MAP_SIZE - Config.ALTAR_FOOTPRINT) / 2, Config.ALTAR_FOOTPRINT),
		"altar footprint")
	r.expect(data.count_value(WorldData.Layer.FLOOR, Terrain.SOIL) > 0, "no tilled soil generated")
	r.expect(data.count_value(WorldData.Layer.FLOOR, Terrain.ASH) > 0, "no ash generated")
	r.expect_eq(data.soil_ash_contacts(), 0, "display cells mixing soil and ash")
	var gatherables: int = WorldItems.gatherable_cells(data).size()
	var wanted: int = 0
	for counts: Dictionary[StringName, int] in [Config.GATHER_ON_GRASS, Config.GATHER_ON_ASH]:
		for id: StringName in counts:
			wanted += counts[id]
	r.expect_eq(gatherables, wanted, "gatherables placed (M2b)")
	# Same world as the x86_64 desktop? A different hash here means this machine's generator makes
	# another world from the same seed (late join still works: the host sends its world), or the
	# generator changed without updating GOLDEN_HASH.
	r.expect_eq(data.content_hash(), SurfaceGen.GOLDEN_HASH, "seed %d world hash (SurfaceGen.GOLDEN_HASH)" %
		Config.DEFAULT_SEED)
	var view: GroundView = GroundView.new()
	view.setup(data, table)
	var v: Dictionary[String, int] = view.verify()
	var cells: int = (data.size.x + 1) * (data.size.y + 1)
	r.expect_eq(v["cells"], cells, "display cells checked")
	r.expect_eq(v["missing"], 0, "display cells not drawn")
	r.expect_eq(v["mismatches"], 0, "display cells whose drawn corners differ from the data")
	r.expect_eq(v["fallbacks"], 0, "display cells drawn with a fallback tile")
	r.fields.append("seed=%d world=%dx%d hash=%s cells=%d chunks=%d gatherables=%d" % [data.world_seed, data.size.x,
		data.size.y, data.content_hash().left(12), cells, view.chunk_count(), gatherables])
	view.free()


## M3a: the dungeon TileSet (2 sources, 30 tiles, 21 corner keys), the seed-1 dungeon (hash, exit
## stairs, arrival point open, shrine) drawn with the cave view (every display cell by the rule), and
## the surface's entrance.
static func _check_dungeon(r: Report) -> void:
	var ts: TileSet = load(TilesetBuilder.DUNGEON_PATH) as TileSet
	if not r.expect(ts != null, "dungeon tileset missing"):
		return
	r.expect_eq(ts.get_source_count(), 2, "dungeon tileset sources")
	r.expect_eq(TilesetBuilder.count_tiles(ts), 30, "dungeon tileset tiles")
	var table: CaveTable = CaveTable.from_tile_set(ts)
	r.expect_eq(table.exact_keys, 21, "dungeon corner keys with art")
	var data: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	r.expect_eq(data.size, Config.DUNGEON_SIZE, "dungeon size")
	r.expect_eq(data.content_hash(), DungeonGen.GOLDEN_HASH, "seed %d dungeon hash (DungeonGen.GOLDEN_HASH)" % Config.DEFAULT_SEED)
	r.expect_eq(DungeonGen.exit_rect(data).size, Config.EXIT_FOOTPRINT, "dungeon exit stairs")
	r.expect_eq(DungeonGen.shrine_rect(data).size, Config.SHRINE_FOOTPRINT, "dungeon shrine spot")
	r.expect(Movement.can_stand(data, DungeonGen.arrival_point(data)), "dungeon arrival point open")
	var view: CaveView = CaveView.new()
	view.setup(data, table)
	var v: Dictionary[String, int] = view.verify()
	r.expect_eq(v["missing"] + v["mismatches"] + v["overlay_mismatches"], 0, "dungeon display cells / overlays against the data")
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	r.expect_eq(SurfaceGen.entrance_rect(surface).size, Config.ENTRANCE_FOOTPRINT, "surface dungeon entrance")
	r.fields.append("dungeon=%dx%d hash=%s ores=%d" % [data.size.x, data.size.y, data.content_hash().left(12),
		Walls.ore_cells(data).size()])
	# M3b: more seeds, for comparing machines (the generator is integer math only).
	var digest: String = DungeonGen.seeds_digest()
	r.expect_eq(digest, DungeonGen.SEEDS_GOLDEN, "dungeons of seeds 1..%d (DungeonGen.SEEDS_GOLDEN)" % DungeonGen.SEEDS_DIGEST_COUNT)
	r.fields.append("dungeon_seeds=%s" % digest.left(12))
	# M3b: a mined dungeon through the map snapshot path, drawn by a fresh cave view.
	var mined: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var feet: Vector2 = DungeonGen.arrival_point(mined) + Vector2(3 * Config.TILE, 0)
	var inv: Inventory = Inventory.new()
	var hits: int = 0
	for i: int in 3:
		var res: Mining.Result = Mining.strike(mined, feet, Mining.MINER_CLASS, inv, Aim.feet_cell(feet) + Vector2i(1, 0))
		for e: EditLog.WorldEdit in res.edits:
			EditLog.apply_to_data(mined, e)
		hits += res.hit.size()
	mined.set_value(WorldData.Layer.PLACEABLE, Aim.feet_cell(feet) + Vector2i(0, 1), WorldData.PLACEABLE_TORCH)
	mined.drops[1] = WorldData.Drop.new(1, &"ore_copper", 2, ItemDB.Grade.NONE, Vector2i(feet))
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(mined)
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	var got: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, packed.world_md5,
		Config.MAP_DUNGEON)
	if r.expect(got != null and got.content_hash() == mined.content_hash() and got.map_id == Config.MAP_DUNGEON and hits > 0,
			"mined dungeon map snapshot round trip: %s" % rx.error):
		view.setup(got, table)
		var mv: Dictionary[String, int] = view.verify()
		r.expect_eq(mv["missing"] + mv["mismatches"] + mv["overlay_mismatches"], 0, "mined dungeon drawn = data")
		r.fields.append("dungeon_map=%dB" % packed.bytes.size())
	view.free()


## Character sheets, one signature layer per slice class, anchor table shape, a rig per class.
static func _check_actors(r: Report) -> void:
	r.expect_eq(Vector2i(RigData.WALK_SHEET.get_size()), Vector2i(192, 96), "walk sheet size")
	r.expect_eq(Vector2i(RigData.IDLE_SHEET.get_size()), Vector2i(128, 96), "idle sheet size")
	for class_id: String in Config.CLASSES:
		var sig: RigData.Signature = RigData.signature_for(class_id)
		if not r.expect(sig != null and sig.texture != null, "no signature layer for %s" % class_id):
			continue
		var c: Character = Character.new()
		c.class_id = class_id
		r.expect(c.signature_sprite() != null and c.signature_sprite().visible, "%s signature not shown" % class_id)
		c.free()
	for table: Array[Array] in [RigAnchors.TORSO, RigAnchors.HEAD]:
		for anim: int in RigData.ANIM_NAMES.size():
			var rows: Array = table[anim]
			r.expect_eq(rows.size(), RigData.ROWS, "anchor rows")
			for frames: Variant in rows:
				var list: Array = frames
				r.expect_eq(list.size(), RigData.frame_count(anim), "anchor frames of %s" % RigData.ANIM_NAMES[anim])
	r.expect(ResourceLoader.exists("res://scenes/main.tscn"), "main.tscn missing")
	var main: PackedScene = load("res://scenes/main.tscn") as PackedScene
	r.expect(main != null and main.can_instantiate(), "main.tscn does not load")


## M2a: the body action sheets (sizes from their cells and frames), every item's icon (16x16; art or
## drawn in code) and world picture, each tool's action, and the M2a input actions.
static func _check_items(r: Report) -> void:
	for anim: int in RigData.ACTION_ANIMS:
		var tex: Texture2D = RigData.sheet(anim)
		var c: int = RigData.cell(anim)
		var want: Vector2i = Vector2i(c * (RigData.FIRST_COLUMN[anim] + RigData.frame_count(anim)), c * RigData.ROWS)
		r.expect(tex != null and Vector2i(tex.get_size()) == want, "%s sheet missing or not %s" % [RigData.ANIM_NAMES[anim], want])
	var tools: int = 0
	for id: StringName in ItemDB.ids():
		var icon: Texture2D = ItemIcons.texture_for(id)
		r.expect(icon != null and Vector2i(icon.get_size()) == Vector2i(16, 16), "icon of %s missing or not 16x16" % id)
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		if not def.world_path.is_empty():
			r.expect(ResourceLoader.exists(def.world_path), "world picture of %s missing" % id)
		if def.is_tool():
			tools += 1
			r.expect(RigData.is_action(def.action), "tool %s has no body action" % id)
	r.expect_eq(tools, 7, "tools (M4a: + holy_light)")
	for action: String in ["use_item", "hotbar_prev", "hotbar_next", "toggle_inventory", "debug_give", "debug_action",
			"interact", "debug_drop", "dash", "skill_1"]:
		r.expect(InputMap.has_action(action), "input action %s missing" % action)
	# M2b: every gatherable's world picture (the gatherable count is checked with the world).
	for id: StringName in WorldItems.GATHERABLES:
		r.expect(ItemView.world_picture(id) != null, "world picture of gatherable %s" % id)
	r.fields.append("items=%d actions=%d" % [ItemDB.ids().size(), RigData.ACTION_ANIMS.size()])


## M4a: the hurt / death and heretic sheets (sizes from their cells and frames), every class weapon's
## attack, the surface spawn tiles all outside the light, and a short fight in the seed's dungeon: a
## heretic next to a player outside any light attacks after its telegraph and the hit lands; a sword
## kills it; the dungeon spawns stop when the shrine breaks.
static func _check_combat(r: Report) -> void:
	for anim: int in RigData.POSE_ANIMS:
		var tex: Texture2D = RigData.sheet(anim)
		var want: Vector2i = Vector2i(32 * RigData.frame_count(anim), 32 * RigData.ROWS)
		r.expect(tex != null and Vector2i(tex.get_size()) == want, "%s sheet missing or not %s" % [RigData.ANIM_NAMES[anim], want])
	for a: int in HereticSim.ANIM_NAMES.size():
		var tex2: Texture2D = Heretic.SHEETS[a]
		var c: int = HereticSim.CELLS[a]
		var want2: Vector2i = Vector2i(c * (HereticSim.FIRST_COLUMN[a] + HereticSim.FRAME_COUNTS[a]), c * RigData.ROWS)
		r.expect(tex2 != null and Vector2i(tex2.get_size()) == want2, "heretic %s sheet not %s" % [HereticSim.ANIM_NAMES[a], want2])
	for class_id: String in Config.CLASSES:
		var weapon: StringName = Combat.class_weapon(class_id)
		r.expect(ItemDB.has(weapon) and Combat.attack_for(weapon) != null, "class weapon of %s" % class_id)
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var zone: SafeZone = SafeZone.for_world(surface)
	var cells: Array[Vector2i] = Arena.surface_spawn_cells(surface, zone)
	var inside: int = 0
	for c2: Vector2i in cells:
		if zone.is_in_safe_zone(Arena.spawn_feet(c2)):
			inside += 1
	r.expect(not cells.is_empty() and inside == 0, "surface spawn tiles outside the light (%d, %d inside)" % [cells.size(), inside])
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var arena: Arena = Arena.new()
	arena.setup(dungeon, Config.DEFAULT_SEED)
	arena.spawning = false
	var p: Player = Player.new()
	p.setup(dungeon, "paladin", DungeonGen.arrival_point(dungeon))
	var players: Array[Player] = [p]
	var h: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(14, 0))
	var hit_at: int = -1
	for t: int in 120:
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(), Config.NET_TICK)
		arena.step(players)
		if hit_at < 0 and p.vitals.hp < Config.PLAYER_HP_MAX:
			hit_at = t
	r.expect_eq(p.vitals.hp, Config.PLAYER_HP_MAX - Config.HERETIC_DAMAGE, "the heretic's knife lands once")
	r.expect(hit_at == Config.HERETIC_TELEGRAPH_TICKS, "the knife lands after the telegraph (tick %d)" % hit_at)
	var swings: int = 0
	while h.alive() and swings < 10:
		arena.player_attack(p, &"sword", Combat.aim_code(h.pos - p.sim_position))
		swings += 1
	r.expect(not h.alive() and swings == ceili(float(Config.HERETIC_HP) / Combat.attack_for(&"sword").damage),
		"a sword kills the heretic (%d swings)" % swings)
	r.expect(arena.spawns_now(), "the dungeon spawns while the shrine stands")
	for e: EditLog.WorldEdit in arena.damage_shrine(Config.SHRINE_HP):
		EditLog.apply_to_data(dungeon, e)
	r.expect(not arena.spawns_now() and dungeon.footprints(WorldData.PLACEABLE_SHRINE_BROKEN).size() == 1,
		"the broken shrine stops the dungeon spawns")
	p.free()
	r.fields.append("combat=%d/%d spawn_tiles=%d" % [hit_at, swings, cells.size()])


## M6a: recipes, a craft, the table art and placement, a drink, a poison down, a thrown poison potion.
static func _check_potions(r: Report) -> void:
	var all: Array[Crafting.Recipe] = Crafting.recipes()
	r.expect_eq(all.size(), 6, "recipes (3 potions x 2 grades)")
	var inv: Inventory = Inventory.new()
	inv.add(&"wild_healing", 2)
	var miner_fine: Crafting.Recipe = Crafting.recipe(&"potion_healing_fine")
	var common: Crafting.Recipe = Crafting.recipe(&"potion_healing_common")
	r.expect(miner_fine != null and not miner_fine.allows("miner") and miner_fine.allows("herbalist"), "FINE potions are the herbalist's")
	var o: Crafting.Outcome = Crafting.craft(common, "miner", inv)
	r.expect(o.ok() and inv.count_of(&"potion_healing", ItemDB.Grade.COMMON) == 1 and inv.count_of(&"wild_healing") == 0,
		"a COMMON healing potion from two herbs (%s)" % o.why)
	var tex: Texture2D = load("res://art/env/alchemy_table_v05.png") as Texture2D
	r.expect(tex != null and Vector2i(tex.get_size()) == Vector2i(48, 32), "alchemy table art 48x32")
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var feet: Vector2 = Vector2(surface.altar_center_px()) + Vector2(0, 80)
	var kit: Inventory = Inventory.new()
	kit.add(&"alchemy_table", 1)
	var put: WorldItems.Outcome = WorldItems.place(surface, feet, kit, 0, Aim.feet_cell(feet) + Vector2i(0, 1))
	for e: EditLog.WorldEdit in put.edits:
		EditLog.apply_to_data(surface, e)
	r.expect(put.ok() and put.edits.size() == 3 and Crafting.station_near(surface, feet) != null,
		"the alchemy table goes down south of the feet and is a station (%s)" % put.why)
	var sim: PlayerSim = PlayerSim.new()
	sim.vit.hp = 50
	r.expect(Potions.apply(sim, &"potion_healing", ItemDB.Grade.COMMON) == PlayerSim.HEALED
		and sim.vit.hp == 50 + Config.POTION_HEAL_HP[ItemDB.Grade.COMMON], "a healing potion heals")
	sim.vit.hp = 1
	Potions.apply(sim, &"potion_poison", ItemDB.Grade.COMMON)
	var downed: bool = false
	for t: int in Config.POISON_INTERVAL_TICKS:
		downed = downed or sim.step(surface, Vector2i.ZERO, -1, -1, Vector2i.ZERO, Config.NET_TICK) & PlayerSim.DOWNED != 0
	r.expect(downed and sim.vit.life == Vitals.Life.DOWN and not sim.vit.poisoned(), "a poison tick takes a player down")
	var arena: Arena = Arena.new()
	arena.setup(surface, Config.DEFAULT_SEED)
	arena.spawning = false
	var at: Vector2 = Arena.spawn_feet(Vector2i(40, 30))
	var h: HereticSim = arena.spawn_heretic(at)
	var thrower: Player = Player.new()
	thrower.setup(surface, "herbalist", at + Vector2(-60, 0))
	arena.throw_potion(thrower, &"potion_poison", ItemDB.Grade.FINE, Combat.body_centre(at))
	var no_players: Array[Player] = []
	for t2: int in 60:
		arena.step(no_players)
	r.expect(arena.stat("splash_heretics") == 1 and h.poisoned(), "a thrown poison potion splashes the heretic")
	thrower.free()
	r.fields.append("potions=%d/%d" % [all.size(), arena.stat("splash_heretics")])


## The actor light texture of the default world's zone equals is_in_safe_zone() at every texel,
## and the flame mask has the 81 lamp pixels.
## M5a: the farming art and one crop from seed to harvest (see the header).
static func _check_farm(r: Report) -> void:
	for id: StringName in Farming.SEEDS.slice(1):
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		r.expect(def != null and def.kind == ItemDB.Kind.SEED, "seed item %s" % id)
	var sheet: Texture2D = FieldView.crop_sheet(false)
	r.expect(sheet != null and Vector2i(sheet.get_size()) == Vector2i(112, 48), "crops sheet 112x48")
	for source: int in FieldView.WET_PATHS:
		r.expect(FieldView.wet_texture(source) != null, "watered soil art for ground source %d" % source)
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var farm: Farm = Farm.new(data)
	var c: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.FLOOR].size():
		var t: Vector2i = Vector2i(i % data.size.x, i / data.size.x)
		if data.terrain_at(t) == Terrain.SOIL and Farming.in_light(data, t):
			c = t
			break
	if not r.expect(c.x >= 0, "a lit soil tile in the seed-1 world"):
		return
	var feet: Vector2 = Arena.spawn_feet(c + Vector2i(0, 1))
	var inv: Inventory = Inventory.new()
	inv.add(&"seed_healing", 1)
	var ripe_at: int = -1
	var edits: Array[EditLog.WorldEdit] = farm.plant(feet, "herbalist", inv, 0, c).edits
	for tick: int in range(1, 6 * Config.CROP_STAGE_TICKS):
		# Every result's edits go into the data before the next call reads it (as GameWorld.apply_edit does).
		for e: EditLog.WorldEdit in edits:
			EditLog.apply_to_data(data, e)
		for e: EditLog.WorldEdit in farm.water(feet, c).edits:
			EditLog.apply_to_data(data, e)
		edits = farm.step()
		for e: EditLog.WorldEdit in edits:
			EditLog.apply_to_data(data, e)
		edits = []
		var f: Farming.Field = Farming.field_at(data, c)
		if f != null and f.ripe():
			ripe_at = tick
			break
	# Written out (not Farming.stage_ticks): four stages at the herbalist's percent of the common speed.
	r.expect_eq(ripe_at, 4 * Config.CROP_STAGE_TICKS * 100 / Config.CROP_HERBALIST_GROWTH_PCT, "the herbalist's crop ripe after four stages")
	var got: Farm.Result = farm.harvest(feet, "herbalist", inv, c)
	r.expect(got.ok() and inv.count_of(&"wild_healing", ItemDB.Grade.FINE) == Config.CROP_HARVEST_HERBS
		and inv.count_of(&"seed_healing") == Config.CROP_HARVEST_SEEDS, "harvest: FINE herbs and a seed (%s)" % got.why)
	r.fields.append("farm=%d/%d" % [ripe_at, got.count])


## M5b: purification and moving the altar (see the header).
static func _check_purify(r: Report) -> void:
	var def: ItemDB.ItemDef = ItemDB.get_def(Purify.HOLY_WATER)
	r.expect(def != null and def.kind == ItemDB.Kind.CONSUMABLE and ItemIcons.texture_for(Purify.HOLY_WATER) != null,
		"holy water item and icon")
	for i: int in PurifyView.ASH_PATHS.size():
		r.expect(PurifyView.ash_texture(i) != null, "ash smear %d" % (i + 1))
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var before: int = Purify.corrupted_count(data)
	var spawn_before: int = Arena.surface_spawn_cells(data, SafeZone.for_world(data)).size()
	var c: Vector2i = Vector2i(-1, -1)
	for i: int in data.layers[WorldData.Layer.CORRUPTION].size():
		if data.layers[WorldData.Layer.CORRUPTION][i] != 0:
			c = Vector2i(i % data.size.x, i / data.size.x)
			break
	if not r.expect(c.x >= 0 and before > 0, "corruption on the seed-1 world"):
		return
	# Written out (not Purify.channel_area): corrupted tiles whose centre lies within the radius of c's centre.
	var want: int = 0
	var rad: int = Config.PURIFY_RADIUS_TILES
	for y: int in range(c.y - rad, c.y + rad + 1):
		for x: int in range(c.x - rad, c.x + rad + 1):
			if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= rad * rad and data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				want += 1
	var done: Purify.Result = Purify.channel_done(data, c)
	for e: EditLog.WorldEdit in done.edits:
		EditLog.apply_to_data(data, e)
	r.expect(done.ok() and done.cells.size() == want and want > 0, "a channel purifies its disc (%d of %d)" % [done.cells.size(), want])
	var grass: bool = true
	for t: Vector2i in done.cells:
		grass = grass and data.terrain_at(t) == Terrain.GRASS and data.get_value(WorldData.Layer.CORRUPTION, t) == 0
	r.expect(grass, "purified tiles are clean grass")
	r.expect_eq(data.soil_ash_contacts(), 0, "no soil next to ash after purifying")
	var c2: Vector2i = Vector2i(-1, -1)
	for i2: int in data.layers[WorldData.Layer.CORRUPTION].size():
		if data.layers[WorldData.Layer.CORRUPTION][i2] != 0:
			c2 = Vector2i(i2 % data.size.x, i2 / data.size.x)
			break
	var inv: Inventory = Inventory.new()
	inv.add(Purify.HOLY_WATER, 2)
	var poured: Purify.Result = Purify.pour(data, Arena.spawn_feet(c2 + Vector2i(0, 1)), inv, 0, c2)
	for e2: EditLog.WorldEdit in poured.edits:
		EditLog.apply_to_data(data, e2)
	r.expect(poured.ok() and poured.cells.size() >= 1 and poured.cells.size() <= 9 and inv.count_of(Purify.HOLY_WATER) == 1,
		"holy water purifies a few tiles and is used (%s)" % poured.why)
	r.expect_eq(Purify.corrupted_count(data), before - done.cells.size() - poured.cells.size(), "the corruption count")
	var spawn_after: int = Arena.surface_spawn_cells(data, SafeZone.for_world(data)).size()
	r.expect(spawn_after < spawn_before, "fewer spawn tiles around the zones (%d -> %d)" % [spawn_before, spawn_after])
	r.fields.append("purify=%d+%d/%d" % [done.cells.size(), poured.cells.size(), spawn_after])
	# The altar: picked up (no altar, no light), put down elsewhere (everything that reads it follows).
	var old_rect: Rect2i = data.altar_rect
	for e3: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		EditLog.apply_to_data(data, e3)
	r.expect(not data.altar_rect.has_area() and SafeZone.for_world(data).radius == 0.0, "picked up: no altar, no safe zone")
	var to: Rect2i = AltarMove.set_down_rect(data, (Vector2(old_rect.position) + Vector2(-12, 1)) * Config.TILE)
	if not r.expect(to.has_area() and to != old_rect, "a place to put it down"):
		return
	for e4: EditLog.WorldEdit in AltarMove.place_edits(to):
		EditLog.apply_to_data(data, e4)
	var centre: Vector2 = (Vector2(to.position) + Vector2(1.5, 1.5)) * Config.TILE
	r.expect(data.altar_rect == to and SafeZone.for_world(data).center == centre, "put down: the altar and its light there")
	r.expect(WorldItems.reserved_feet(data).has(centre + Vector2(Config.SPAWN_SLOTS[0])), "the spawn slots follow it")
	r.fields.append("altar=%d,%d" % [to.position.x, to.position.y])


static func _check_light(r: Report) -> void:
	var zone: SafeZone = SafeZone.for_world(SurfaceGen.generate(Config.DEFAULT_SEED))
	var img: Image = LightGen.zone_light_image(zone, LightGen.Edge.HARD, 0)
	var size: int = LightGen.texture_size(zone)
	var origin: Vector2i = LightGen.texture_origin(zone)
	var data: PackedByteArray = img.get_data()
	var mismatches: int = 0
	for y: int in size:
		for x: int in size:
			var inside: bool = zone.is_in_safe_zone(Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5))
			if inside != (data[(y * size + x) * 4 + 3] == 255):
				mismatches += 1
	r.expect_eq(mismatches, 0, "light texels different from the safe-zone rule")
	r.expect_eq(LightGen.count_opaque(Altar.flame_image()), 81, "flame mask pixels")
	r.fields.append("zone=%s/%d light=%dx%d" % [zone.center, roundi(zone.radius), size, size])


## Session pieces: the physics tick the net code assumes, the transports (ENet works in this build:
## a host on a free loopback port opens and closes; Steam follows GodotSteam), the wire format,
## the late join world snapshot (zstd in this build: packed, chunked, received, same world), the
## real player cap, and the Net node in main.tscn.
static func _check_net(r: Report) -> void:
	r.expect_eq(int(Engine.physics_ticks_per_second), Config.NET_TICK_RATE, "physics ticks per second")
	r.expect_eq(Config.NET_TICK_RATE % Config.NET_STATE_HZ, 0, "state batches on whole ticks")
	var enet: NetTransport = Transports.make("enet")
	r.expect(enet != null and enet.is_available(), "ENet transport unavailable")
	var steam: NetTransport = Transports.make("steam")
	r.expect(steam != null and steam.is_available() == (ClassDB.class_exists(&"SteamMultiplayerPeer")
		and Engine.has_singleton("Steam")), "Steam transport availability")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.set_bind_ip("127.0.0.1")  # loopback only: no firewall prompt
	var err: Error = peer.create_server(0, 1)
	r.expect_eq(err, OK, "ENet host on a free loopback port")
	if err == OK:
		r.fields.append("enet_port=%d" % peer.host.get_local_port())
	peer.close()
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.slot = 8
	s.pos = Vector2(987.0, 804.000366)
	s.facing = RigData.Dir.WEST
	s.walking = true
	s.ack = 123456
	var batch: NetProtocol.StateBatch = NetProtocol.decode_states(NetProtocol.encode_states(77,
		[s] as Array[NetProtocol.PlayerState]))
	r.expect(batch.ok and batch.tick == 77 and batch.states.size() == 1 and batch.states[0].same_as(s),
		"state batch round trip")
	var world: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	world.drops[1] = WorldData.Drop.new(1, &"stone_a", 5, ItemDB.Grade.NONE, Vector2i(808, 840))  # M2b: drops travel too
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(world)
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	var received: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size,
		packed.world_md5)
	r.expect(received != null and received.content_hash() == world.content_hash() and received.drops.size() == 1,
		"world snapshot round trip (with a drop): %s" % rx.error)
	var frame: NetProtocol.InputFrame = NetProtocol.InputFrame.new(9, Vector2i(1, -1))
	frame.look = RigData.Dir.EAST
	frame.op = NetProtocol.Op.PICKUP
	frame.cell = Vector2i(61, 50)
	var inputs: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([frame] as Array[NetProtocol.InputFrame]))
	r.expect(inputs.ok and inputs.frames.size() == 1 and inputs.frames[0].same_request(frame) and inputs.frames[0].look == frame.look,
		"input frame with a request round trip (M2b)")
	# M3b: maps on the wire.
	s.map = Config.MAP_DUNGEON
	var dbatch: NetProtocol.StateBatch = NetProtocol.decode_states(NetProtocol.encode_states(78, [s] as Array[NetProtocol.PlayerState]))
	r.expect(dbatch.ok and dbatch.states[0].map == Config.MAP_DUNGEON, "state with its map round trip (M3b)")
	var travel: NetProtocol.InputFrame = NetProtocol.InputFrame.new(10, Vector2i.ZERO)
	travel.op = NetProtocol.Op.TRAVEL
	travel.map = Config.MAP_DUNGEON
	travel.cell = Vector2i(37, 14)
	var tp: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([travel] as Array[NetProtocol.InputFrame]))
	r.expect(tp.ok and tp.frames[0].same_request(travel) and tp.frames[0].map == Config.MAP_DUNGEON, "travel request round trip (M3b)")
	var edit: Array = EditLog.decode_one(EditLog.encode_one(EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(42, 15), 0), 9,
		Config.MAP_DUNGEON))
	var edit_map: int = edit[2]
	r.expect_eq(edit_map, Config.MAP_DUNGEON, "edit names its map (M3b)")
	var entry: NetProtocol.MapEntry = NetProtocol.MapEntry.new()
	entry.map = Config.MAP_DUNGEON
	entry.packed_size = 300
	entry.chunk_count = 1
	entry.state = s
	var eb: NetProtocol.MapEntry = NetProtocol.decode_map_entry(NetProtocol.encode_map_entry(entry))
	r.expect(eb.ok and eb.map == Config.MAP_DUNGEON and eb.state.same_as(s), "map entry round trip (M3b)")
	r.fields.append("snapshot=%dB/%dB" % [packed.bytes.size(), packed.raw_size])
	var roster: Roster = Roster.new()
	for i: int in Config.MAX_PLAYERS:
		roster.admit(i + 1, Config.CLASSES[i % Config.CLASSES.size()])
	r.expect(roster.is_full() and roster.admit(100, "miner") == -1, "a tenth player is refused")
	var main: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var has_net: bool = false
	if main != null:
		var state: SceneState = main.get_state()
		for i: int in state.get_node_count():
			if state.get_node_name(i) == &"Net":
				has_net = true
	r.expect(has_net, "main.tscn has no Net node")
	_check_net_combat(r, s)
	_check_net_potions(r, s)
	_check_net_fields(r)
	r.fields.append("net=v%d" % NetProtocol.VERSION)


## M4b: combat on the wire: a frame's dash, F held and a USE's aim, a state's vitals block, a map's enemy
## batch from a real arena drawn by a client's NetCombat where the host has it, shot events.
static func _check_net_combat(r: Report, s: NetProtocol.PlayerState) -> void:
	var use: NetProtocol.InputFrame = NetProtocol.InputFrame.new(11, Vector2i(-1, 0))
	use.dash = true
	use.interact = true
	use.op = NetProtocol.Op.USE
	use.slot = Config.START_WEAPON_SLOT
	use.cell = Vector2i(40, 30)
	use.aim = 173
	var up: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([use] as Array[NetProtocol.InputFrame]))
	r.expect(up.ok and up.frames[0].same_request(use) and up.frames[0].dash and up.frames[0].interact and up.frames[0].aim == 173,
		"a frame's dash, F held and a USE's aim round trip (M4b)")
	var v: Vitals = Vitals.new()
	v.hp = 30
	v.life = Vitals.Life.DOWN
	v.life_ticks = 77
	v.revive_ticks = 12
	s.vitals = v
	var vb: NetProtocol.StateBatch = NetProtocol.decode_states(NetProtocol.encode_states(79, [s] as Array[NetProtocol.PlayerState]))
	r.expect(vb.ok and vb.states[0].same_as(s) and vb.states[0].vitals != null and vb.states[0].vitals.life == Vitals.Life.DOWN,
		"a state's vitals block round trip (M4b)")
	s.vitals = null
	var d: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var arena: Arena = Arena.new()
	arena.setup(d, Config.DEFAULT_SEED)
	var feet: Vector2 = DungeonGen.arrival_point(d) + Vector2(40, 16)
	var h: HereticSim = arena.spawn_heretic(feet)
	h.state = HereticSim.State.ATTACK
	h.state_ticks = 12
	h.hp = 26
	var payload: PackedByteArray = NetProtocol.encode_enemies(500, Config.MAP_DUNGEON, arena.shrine_hp_now(), arena.enemy_states(500))
	var nc: NetCombat = NetCombat.new()
	nc.reset(Config.MAP_DUNGEON, d)
	var b: NetProtocol.EnemyBatch = NetProtocol.decode_enemies(payload)
	nc.on_batch(b, payload, true)
	nc.sample(500.0, 6.0)
	var shown: HereticSim = nc.arena.heretics[0] if nc.arena.heretics.size() == 1 else null
	r.expect(b.ok and shown != null and shown.pos == feet and shown.hp == 26 and shown.state == HereticSim.State.ATTACK
		and shown.state_ticks == 12 and nc.arena.shrine_hp == Config.SHRINE_HP,
		"an enemy batch drawn by a client where the host has it, its wind-up at once (M4b)")
	var shot: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	shot.id = 9
	shot.item = &"bow"
	shot.owner = 1
	shot.tick = 499
	shot.pos = feet
	shot.aim = 0
	var se: NetProtocol.ShotEvents = NetProtocol.decode_shots(NetProtocol.encode_shots(Config.MAP_DUNGEON, [shot] as Array[NetProtocol.ShotEvent]))
	r.expect(se.ok and se.events.size() == 1 and se.events[0].same_as(shot), "shot events round trip (M4b)")
	r.fields.append("combat_wire=%dB" % payload.size())


## M6b: potions on the wire: THROW and CRAFT frames, a state's effects block, a host's thrown potion (its events
## flown by a client where the host has it), a poisoned heretic drawn with its flag.
static func _check_net_potions(r: Report, s: NetProtocol.PlayerState) -> void:
	var throw: NetProtocol.InputFrame = NetProtocol.InputFrame.new(21, Vector2i.ZERO)
	throw.op = NetProtocol.Op.THROW
	throw.slot = 1
	throw.cell = Vector2i(40, 31)
	throw.aim = 64
	throw.throw_to = Vector2(648, 520)
	var craft: NetProtocol.InputFrame = NetProtocol.InputFrame.new(22, Vector2i.ZERO)
	craft.op = NetProtocol.Op.CRAFT
	craft.recipe = Crafting.index_of(&"potion_poison_fine")
	var up: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([throw, craft] as Array[NetProtocol.InputFrame]))
	r.expect(up.ok and up.frames.size() == 2 and up.frames[0].same_request(throw) and up.frames[1].same_request(craft),
		"a THROW and a CRAFT round trip (M6b)")
	var v: Vitals = Vitals.new()
	v.buff_pct = Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE]
	v.buff_ticks = 100
	v.poison_damage = Config.POISON_DAMAGE[ItemDB.Grade.COMMON]
	v.poison_ticks = 50
	v.poison_timer = 7
	s.vitals = v
	var state_bytes: int = NetProtocol.state_size(s)
	var vb: NetProtocol.StateBatch = NetProtocol.decode_states(NetProtocol.encode_states(80, [s] as Array[NetProtocol.PlayerState]))
	r.expect(vb.ok and vb.states[0].same_as(s) and state_bytes == NetProtocol.STATE_SIZE + NetProtocol.VITALS_SIZE + NetProtocol.EFFECTS_SIZE,
		"a state's effects block round trip (M6b)")
	s.vitals = null
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var arena: Arena = Arena.new()
	arena.setup(surface, Config.DEFAULT_SEED)
	arena.spawning = false
	arena.logging = true
	var at: Vector2 = Arena.spawn_feet(Vector2i(40, 30))
	var h: HereticSim = arena.spawn_heretic(at)
	var thrower: Player = Player.new()
	thrower.setup(surface, "herbalist", at + Vector2(-60, 0))
	var nc: NetCombat = NetCombat.new()
	nc.reset(Config.MAP_SURFACE, surface)
	var no_players: Array[Player] = []
	var off: int = 0
	var flying: int = 0
	var wire: int = 0
	arena.now = 1000
	var f: Arena.Flask = arena.throw_potion(thrower, &"potion_poison", ItemDB.Grade.FINE, Combat.body_centre(at), 3)
	for t: int in 40:
		arena.now = 1000 + t
		arena.step(no_players)
		if not arena.shot_events.is_empty():
			var bytes: PackedByteArray = NetProtocol.encode_shots(Config.MAP_SURFACE, arena.shot_events)
			wire += bytes.size() - 2
			nc.on_shots(NetProtocol.decode_shots(bytes))
			arena.shot_events.clear()
		if not f.done:
			flying += 1
			var tr: NetCombat.FlaskTrack = nc.flasks.get(f.id, null)
			if tr == null or tr.pos_at(float(arena.now)) != f.pos:
				off += 1
	r.expect(flying > 5 and off == 0 and h.poisoned() and nc.flask_events == 2,
		"a thrown potion's events: the client flies it on the host's points (%d ticks, %d off), it breaks on the heretic (M6b)" % [
		flying, off])
	var payload: PackedByteArray = NetProtocol.encode_enemies(1040, Config.MAP_SURFACE, 0, arena.enemy_states(1040))
	nc.on_batch(NetProtocol.decode_enemies(payload), payload, true)
	nc.sample(1040.0, 6.0)
	r.expect(nc.arena.heretics.size() == 1 and nc.arena.heretics[0].poisoned() and nc.poisoned_seen.has(h.id),
		"a poisoned heretic is drawn poisoned by a client (M6b)")
	thrower.free()
	r.fields.append("potion_wire=%dB/%dB" % [state_bytes, wire])


## M5c: farming, purification and the altar on the wire: the three new requests on frames, a state with the channel in
## its action bits and the carrier bit, a host farm's edits (a crop growing and withering after the altar left) applied to
## a client's copy of the world through the edit encoding.
static func _check_net_fields(r: Report) -> void:
	var ch: NetProtocol.InputFrame = NetProtocol.InputFrame.new(31, Vector2i.ZERO)
	ch.op = NetProtocol.Op.CHANNEL
	var lift: NetProtocol.InputFrame = NetProtocol.InputFrame.new(32, Vector2i.ZERO)
	lift.op = NetProtocol.Op.ALTAR_LIFT
	lift.cell = Vector2i(62, 47)
	lift.interact = true
	var put: NetProtocol.InputFrame = NetProtocol.InputFrame.new(33, Vector2i.ZERO)
	put.op = NetProtocol.Op.ALTAR_PLACE
	put.cell = Vector2i(50, 47)
	var up: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([ch, lift, put] as Array[NetProtocol.InputFrame]))
	r.expect(up.ok and up.frames.size() == 3 and up.frames[0].channel and up.frames[1].same_request(lift)
		and up.frames[2].same_request(put), "CHANNEL, ALTAR_LIFT and ALTAR_PLACE round trip (M5c)")
	var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	st.slot = 2
	st.pos = Vector2(968.0, 254.0)
	st.channel = 77
	st.carrying = true
	var bytes: PackedByteArray = NetProtocol.encode_states(90, [st] as Array[NetProtocol.PlayerState])
	var back: NetProtocol.StateBatch = NetProtocol.decode_states(bytes)
	var state_bytes: int = bytes.size() - NetProtocol.STATE_HEADER
	r.expect(back.ok and back.states[0].same_as(st) and state_bytes == NetProtocol.STATE_SIZE,
		"a channelling carrier's state round trips in %d B (M5c)" % state_bytes)
	var host: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var client: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var farm: Farm = Farm.new(host)
	farm.stage_ticks_base = 2
	var soil: Vector2i = Vector2i(-1, -1)
	for y: int in host.size.y:
		for x: int in host.size.x:
			if soil.x < 0 and Farming.is_tilled(host, Vector2i(x, y)) and Farming.in_light(host, Vector2i(x, y)):
				soil = Vector2i(x, y)
	var edit_bytes: int = 0
	var index: int = 0
	var crop: Farming.Field = Farming.Field.new(Farming.KIND_HEALING, 0, true, false)
	var seed_edit: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, soil, crop.value())
	var all: Array[EditLog.WorldEdit] = [seed_edit]
	EditLog.apply_to_data(host, seed_edit)
	farm.sync_cell(soil)
	for t: int in 12:
		all.append_array(_applied(host, farm.step()))
	all.append_array(_applied(host, AltarMove.pickup_edits(host)))
	all.append_array(_applied(host, farm.step()))
	for e: EditLog.WorldEdit in all:
		var wire: PackedByteArray = EditLog.encode_one(e, index, Config.MAP_SURFACE)
		edit_bytes = wire.size()
		var decoded: Array = EditLog.decode_one(wire)
		var got: EditLog.WorldEdit = decoded[1]
		EditLog.apply_to_data(client, got)
		index += 1
	var f: Farming.Field = Farming.field_at(client, soil)
	r.expect(f != null and f.ripe() and f.withered and client.content_hash() == host.content_hash() and not client.altar_rect.has_area(),
		"a farm's growth and its withering once the altar left reach a client's world as edits (M5c: %s)" % (
		f.describe() if f != null else "none"))
	r.fields.append("fields_wire=%dB/%dB" % [state_bytes, edit_bytes])


## Applies `edits` to `data` and returns them.
static func _applied(data: WorldData, edits: Array[EditLog.WorldEdit]) -> Array[EditLog.WorldEdit]:
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(data, e)
	return edits
