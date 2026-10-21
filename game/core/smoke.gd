class_name Smoke
extends RefCounted
## Smoke checks for --smoke (also in the exported exe): the engine version, the display settings
## that reached the root window, the input map, the committed surface TileSet, and one generated
## world drawn with the ground view (corners, fallbacks, soil/ash), the character art and rig
## tables, the safe-zone light texture against the rule, the flame mask, and the run scene.
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
	_check_actors(r)
	_check_light(r)
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
	var view: GroundView = GroundView.new()
	view.setup(data, table)
	var v: Dictionary[String, int] = view.verify()
	var cells: int = (data.size.x + 1) * (data.size.y + 1)
	r.expect_eq(v["cells"], cells, "display cells checked")
	r.expect_eq(v["missing"], 0, "display cells not drawn")
	r.expect_eq(v["mismatches"], 0, "display cells whose drawn corners differ from the data")
	r.expect_eq(v["fallbacks"], 0, "display cells drawn with a fallback tile")
	r.fields.append("seed=%d world=%dx%d hash=%s cells=%d chunks=%d" % [data.world_seed, data.size.x, data.size.y,
		data.content_hash().left(12), cells, view.chunk_count()])
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


## The actor light texture of the default world's zone equals is_in_safe_zone() at every texel,
## and the flame mask has the 81 lamp pixels.
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
