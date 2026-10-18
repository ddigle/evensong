extends "res://tests/spike_test.gd"
## chars module (headless): layer order per direction, per-frame offsets, west mirror, walk
## animation, palette swap shader parameters, the CPU palette rule, scale math and layout.
## The GPU side (the drawn pixels equal the CPU reference, integer scale on real windows) needs a
## renderer: chars.tscn -- --chars-shots and scale.tscn -- --chars-scale-shots (notes/chars.md).

const Data := preload("res://chars/char_data.gd")
const Compose := preload("res://chars/compose.gd")
const Character := preload("res://chars/layered_character.gd")
const CharsScene := preload("res://chars/chars_scene.gd")
const ScaleScene := preload("res://chars/scale_scene.gd")

const ORIGIN: Vector2 = Vector2(-16, -32)


func run() -> Array[String]:
	_check_art()
	_check_draw_order()
	_check_frame_offsets()
	_check_anchor_tables()
	_check_mirror()
	_check_animation()
	_check_palette_shader()
	_check_cpu_palette()
	_check_scale_math()
	_check_layout()
	await _check_scenes()
	return failures


func _new_char(direction: int, signature: StringName, palette: StringName = &"default") -> Character:
	var c: Character = Character.new()
	c.direction = direction
	c.signature = signature
	c.palette = palette
	c.walking = false
	return c


func _check_art() -> void:
	var sizes: Dictionary = {
		Data.BODY_SHEET: Vector2i(192, 96),
		"res://art/chars/sig_herbalist_pouch_v02.png": Vector2i(96, 32),
		"res://art/chars/sig_miner_pickaxe_v01.png": Vector2i(96, 32),
		"res://art/chars/sig_cleric_halo_v01.png": Vector2i(12, 5),
		"res://art/chars/tiles_grass_base_v02.png": Vector2i(16, 16),
		"res://art/chars/altar_v04.png": Vector2i(48, 57),
		"res://art/chars/alchemy_table_v05.png": Vector2i(48, 32),
		"res://art/chars/crops_v03_sheet.png": Vector2i(112, 48),
	}
	for path: String in sizes:
		var img: Image = Compose.load_image(path)
		if not check_not_null(img, "load %s" % path):
			continue
		check_eq(img.get_size(), sizes[path], "size of %s" % path)
		check(ResourceLoader.exists(path), "%s is imported as a texture" % path)
	# Feet on row 31 in every walk frame (base_body_v02 = v01 moved down, brief §5.6 발 맞춤).
	var body: Image = Compose.load_image(Data.BODY_SHEET)
	for row: int in 3:
		for f: int in Data.FRAME_COUNT:
			var used: Rect2i = body.get_region(Compose.body_rect(row, f)).get_used_rect()
			check_eq(used.end.y, 32, "walk row %d frame %d: lowest pixel on y=31" % [row, f])


func _check_draw_order() -> void:
	var expected: Dictionary = {
		&"pickaxe": [[&"back", &"body"], [&"back", &"body"], [&"body", &"back"], [&"back", &"body"]],
		&"pouch": [[&"body", &"waist"], [&"body", &"waist"], [&"body", &"waist"], [&"body", &"waist"]],
		&"halo": [[&"body", &"float"], [&"body", &"float"], [&"body", &"float"], [&"body", &"float"]],
		&"": [[&"body"], [&"body"], [&"body"], [&"body"]],
	}
	for sig: StringName in expected:
		var c: Character = _new_char(Data.Dir.SOUTH, sig)
		for dir: int in 4:
			c.direction = dir  # changing direction on a live node re-orders the layers
			var got: Array[StringName] = c.draw_order()
			check_eq(got, expected[sig][dir] as Array, "draw order %s %s" % [sig, Data.DIR_NAMES[dir]])
			# Hidden slots are ordered too, so the full child list follows DRAW_ORDER.
			var names: Array[StringName] = []
			for child: Node in c.rig.get_children():
				names.append(Character.SLOT_NODE_NAMES.find_key(child.name) as StringName)
			check_eq(names, Data.DRAW_ORDER[Data.sheet_row(dir)] as Array,
				"rig children follow DRAW_ORDER (%s %s)" % [sig, Data.DIR_NAMES[dir]])
		c.free()
	check_eq(Data.DRAW_ORDER.size(), 3, "draw order table has south/east/north (west reuses east)")


func _check_frame_offsets() -> void:
	# Literal expectations (v01 layer position + walk shift + anchor offset + halo bob).
	var cases: Array = [
		# [signature, direction, frame, expected sprite position]
		[&"pouch", Data.Dir.SOUTH, 0, ORIGIN + Vector2(0, 4)],
		[&"pouch", Data.Dir.EAST, 3, ORIGIN + Vector2(0, 3)],
		[&"pouch", Data.Dir.NORTH, 1, ORIGIN + Vector2(0, 5)],   # torso drops 1 px on frames 1-2
		[&"pickaxe", Data.Dir.NORTH, 2, ORIGIN + Vector2(0, 5)],
		[&"pickaxe", Data.Dir.NORTH, 3, ORIGIN + Vector2(0, 4)],
		[&"pickaxe", Data.Dir.WEST, 4, ORIGIN + Vector2(0, 3)],  # west uses the east numbers
		[&"halo", Data.Dir.SOUTH, 0, ORIGIN + Vector2(10, -1)],  # 4 - 5
		[&"halo", Data.Dir.SOUTH, 1, ORIGIN + Vector2(10, -1)],
		[&"halo", Data.Dir.SOUTH, 2, ORIGIN + Vector2(10, -3)],  # head -1, bob -1
		[&"halo", Data.Dir.SOUTH, 5, ORIGIN + Vector2(10, -2)],  # head -1
		[&"halo", Data.Dir.EAST, 0, ORIGIN + Vector2(10, -2)],   # 3 - 5
		[&"halo", Data.Dir.EAST, 3, ORIGIN + Vector2(10, -3)],   # bob -1
		[&"halo", Data.Dir.NORTH, 4, ORIGIN + Vector2(10, -2)],
	]
	for case: Array in cases:
		var c: Character = _new_char(case[1], case[0])
		c.frame = case[2]
		var slot: StringName = Data.SIGNATURES[case[0]]["slot"]
		var s: Sprite2D = c.slots[slot]
		check_eq(s.position, case[3] as Vector2, "%s %s frame %d position" % [case[0], Data.DIR_NAMES[case[1]], case[2]])
		check(s.visible, "%s layer visible" % case[0])
		c.free()
	# Every frame: body cell, layer cell, whole-pixel positions, matches the table.
	for sig: StringName in [&"pouch", &"pickaxe", &"halo"]:
		var c: Character = _new_char(Data.Dir.SOUTH, sig)
		var s: Sprite2D = c.slots[Data.SIGNATURES[sig]["slot"]]
		for dir: int in 4:
			c.direction = dir
			var row: int = Data.sheet_row(dir)
			for f: int in Data.FRAME_COUNT:
				c.frame = f
				check_eq(c.body.frame, row * Data.FRAME_COUNT + f, "body cell %s %s f%d" % [sig, Data.DIR_NAMES[dir], f])
				check_eq(c.body.position, ORIGIN, "body stays at the frame origin")
				check_eq(s.frame, row if Data.SIGNATURES[sig]["layout"] == &"columns" else 0, "layer cell %s %s" % [sig, Data.DIR_NAMES[dir]])
				check_eq(s.position, ORIGIN + Vector2(Data.layer_frame_pos(sig, row, f)), "layer offset %s %s f%d" % [sig, Data.DIR_NAMES[dir], f])
				check(s.position == s.position.round(), "layer on whole pixels")
		c.free()


## The stored anchor tables are what the measuring rule gives on the current sheet.
func _check_anchor_tables() -> void:
	var t0: int = Time.get_ticks_msec()
	for row: int in 3:
		var torso: Array[Vector2i] = Compose.anchor_offsets(row, Data.TORSO_BAND, Data.ANCHOR_RADIUS, Data.ANCHOR_TOLERANCE)
		var head: Array[Vector2i] = Compose.anchor_offsets(row, Data.HEAD_BAND, Data.ANCHOR_RADIUS, Data.ANCHOR_TOLERANCE)
		check_eq(torso, Data.TORSO_OFFSETS[row] as Array, "torso anchors row %d match the measured ones" % row)
		check_eq(head, Data.HEAD_OFFSETS[row] as Array, "head anchors row %d match the measured ones" % row)
		check_eq(torso[0], Vector2i.ZERO, "frame 0 is its own reference")
	check_between(Time.get_ticks_msec() - t0, 0, 20000, "anchor measuring time (ms)")


func _check_mirror() -> void:
	var east: Character = _new_char(Data.Dir.EAST, &"pickaxe")
	var west: Character = _new_char(Data.Dir.WEST, &"pickaxe")
	add_node(east)
	add_node(west)
	for f: int in Data.FRAME_COUNT:
		east.frame = f
		west.frame = f
		check_eq(west.rig.scale, Vector2(-1, 1), "west rig is mirrored")
		check_eq(east.rig.scale, Vector2(1, 1), "east rig is not mirrored")
		check_eq(west.body.frame, east.body.frame, "west draws the east body cell f%d" % f)
		var ws: Sprite2D = west.slots[Data.SLOT_BACK]
		var es: Sprite2D = east.slots[Data.SLOT_BACK]
		check_eq(ws.frame, es.frame, "west draws the east pickaxe cell")
		check_eq(ws.position, es.position, "same local layer offset f%d" % f)
		# Global mapping: a point x pixels right of the feet lands x pixels left of them.
		var p: Vector2 = Vector2(5, -10)
		check_eq(west.body.get_global_transform() * (p - ORIGIN), Vector2(-5, -10), "west maps +x to -x")
		check_eq(east.body.get_global_transform() * (p - ORIGIN), Vector2(5, -10), "east maps +x to +x")
	# The 32 px frame is centred on the feet, so the halo (x 10..21 in the frame) stays centred.
	var halo: Character = _new_char(Data.Dir.WEST, &"halo")
	add_node(halo)
	var hs: Sprite2D = halo.slots[Data.SLOT_FLOAT]
	var left: Vector2 = hs.get_global_transform() * Vector2(0, 0)
	var right: Vector2 = hs.get_global_transform() * Vector2(12, 0)
	check_eq(Vector2(minf(left.x, right.x), maxf(left.x, right.x)), Vector2(-6, 6), "mirrored halo spans x -6..6")
	# CPU reference: west is the east picture flipped (what chars_scene compares the GPU with).
	var e_img: Image = Compose.compose(Data.Dir.EAST, &"pickaxe", &"default", 2)
	var w_img: Image = Compose.compose(Data.Dir.WEST, &"pickaxe", &"default", 2)
	e_img.flip_x()
	check(w_img.get_data() == e_img.get_data(), "CPU west = flipped east")


func _check_animation() -> void:
	var c: Character = _new_char(Data.Dir.SOUTH, &"halo")
	add_node(c)
	c.walking = true
	c.frame = 0
	c.advance(Data.FRAME_TIME * 7.0 + 0.001)
	check_eq(c.frame, 1, "7 frame times later the 6-frame walk is on frame 1")
	check_eq(c.body.frame, 1, "body cell follows")
	c.frame = 13
	check_eq(c.frame, 1, "frame wraps")
	c.walking = false
	c._process(1.0)
	check_eq(c.frame, 1, "no walking, no frame change")


func _check_palette_shader() -> void:
	var c: Character = _new_char(Data.Dir.SOUTH, &"pouch")
	var mat: ShaderMaterial = c.body.material as ShaderMaterial
	if not check_not_null(mat, "body has a ShaderMaterial"):
		c.free()
		return
	check_eq(mat.shader.resource_path, "res://chars/palette_swap.gdshader", "palette shader")
	check_has(mat.shader.code, "uniform vec4 dst_colors[16]", "shader declares the colour arrays")
	check_eq(mat.get_shader_parameter("swap_count"), 0, "default palette swaps nothing")
	check_eq(mat.get_shader_parameter("band"), Vector2(17, 25), "tunic row band")
	check_eq(mat.get_shader_parameter("frame_grid"), Vector2(6, 3), "frame grid of the walk sheet")
	check_eq(mat.get_shader_parameter("frame_height"), 32.0, "frame height")
	for slot: StringName in Data.SLOTS:
		check((c.slots[slot] as Sprite2D).material == null, "signature layer %s is not recoloured" % slot)
	c.palette = &"moss"
	var src: PackedColorArray = Data.source_colors()
	var dst: PackedColorArray = Data.palette_colors(&"moss")
	check_eq(mat.get_shader_parameter("swap_count"), src.size(), "moss swaps every tunic colour")
	check_eq(mat.get_shader_parameter("src_colors"), src, "source colours")
	check_eq(mat.get_shader_parameter("dst_colors"), dst, "target colours")
	for i: int in dst.size():
		check_near(dst[i].h, 0.29, 0.02, "moss hue %d" % i)
		check_near(dst[i].v, src[i].v, 2.0 / 255.0, "moss keeps the shade %d" % i)
		check_eq(dst[i], Color8(dst[i].r8, dst[i].g8, dst[i].b8), "target colour %d is 8-bit exact" % i)
	var other: Character = _new_char(Data.Dir.SOUTH, &"", &"wine")
	check(other.body.material != mat, "each character has its own material")
	check_eq((other.body.material as ShaderMaterial).get_shader_parameter("dst_colors"), Data.palette_colors(&"wine"), "wine colours")
	c.palette = &"default"
	check_eq(mat.get_shader_parameter("swap_count"), 0, "back to default")
	c.free()
	other.free()


## The CPU rule (same as the shader): only tunic rows change, the face and hair keep their beige.
func _check_cpu_palette() -> void:
	var sheet: Image = Compose.load_image(Data.BODY_SHEET).duplicate() as Image
	var before: Image = sheet.duplicate() as Image
	var changed: int = Compose.apply_palette(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), &"sky")
	check_between(changed, 300, 2000, "tunic pixels recoloured on the walk sheet")
	var outside: int = 0
	var rows_hit: Array[int] = [0, 0, 0]
	for y: int in sheet.get_height():
		for x: int in sheet.get_width():
			if sheet.get_pixel(x, y) != before.get_pixel(x, y):
				var local_y: int = y % 32
				if local_y < Data.TUNIC_BAND.x or local_y > Data.TUNIC_BAND.y:
					outside += 1
				rows_hit[y / 32] += 1
	check_eq(outside, 0, "no change outside the tunic band")
	for row: int in 3:
		check(rows_hit[row] > 40, "tunic recoloured in sheet row %d (%d px)" % [row, rows_hit[row]])
	check_eq(Compose.apply_palette(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), &"default"), 0, "default changes nothing")


func _check_scale_math() -> void:
	var cases: Array = [
		# [window, internal, scale, border]
		[Vector2i(1920, 1080), Vector2i(480, 270), 4, Vector2i(0, 0)],
		[Vector2i(2560, 1440), Vector2i(480, 270), 5, Vector2i(80, 45)],
		[Vector2i(3840, 2160), Vector2i(480, 270), 8, Vector2i(0, 0)],
		[Vector2i(1366, 768), Vector2i(480, 270), 2, Vector2i(203, 114)],
		[Vector2i(1920, 1080), Vector2i(640, 360), 3, Vector2i(0, 0)],
		[Vector2i(2560, 1440), Vector2i(640, 360), 4, Vector2i(0, 0)],
		[Vector2i(3840, 2160), Vector2i(640, 360), 6, Vector2i(0, 0)],
		[Vector2i(1280, 800), Vector2i(640, 360), 2, Vector2i(0, 40)],
	]
	for case: Array in cases:
		var m: Dictionary = ScaleScene.stretch_math(case[0], case[1])
		check_eq(m["scale"], case[2], "scale for %s at %s" % [case[0], case[1]])
		check_eq(m["border"], case[3], "border for %s at %s" % [case[0], case[1]])
	# Presenting = whole-number nearest upscale: every internal pixel becomes an s x s square.
	var tiny: Image = Image.create_empty(3, 2, false, Image.FORMAT_RGBA8)
	tiny.set_pixel(0, 0, Color.RED)
	tiny.set_pixel(2, 1, Color.BLUE)
	var shown: Image = ScaleScene.present(tiny, Vector2i(16, 10), 4, Vector2i(2, 1))
	check_eq(shown.get_pixel(0, 0), Color.BLACK, "border is black")
	check_eq(shown.get_pixel(2, 1), Color.RED, "first block starts at the border")
	check_eq(shown.get_pixel(5, 4), Color.RED, "4x4 block")
	check_eq(shown.get_pixel(6, 4), Color(0, 0, 0, 0), "next block")
	check_eq(shown.get_pixel(13, 8), Color.BLUE, "last block")


func _check_layout() -> void:
	var world: Rect2i = Rect2i(Vector2i.ZERO, ScaleScene.WORLD_TILES * ScaleScene.TILE)
	var char_rects: Array[Rect2i] = []
	for spec: Array in ScaleScene.CHARACTERS:
		var feet: Vector2i = ScaleScene.character_feet(spec[0])
		check_eq(Vector2i(feet.x - 8, feet.y) % 16, Vector2i.ZERO, "character feet at a tile's bottom centre")
		var used_char: Rect2i = Compose.compose(spec[1], spec[2], &"default", 0).get_used_rect()
		char_rects.append(Rect2i(feet + Compose.CANVAS.position + used_char.position, used_char.size))
	for item: Dictionary in ScaleScene.layout_items():
		var pos: Vector2i = item["pos"]
		check_eq(pos % 16, Vector2i.ZERO, "%s on the 16 px grid" % item["tex"])
		var r: Rect2i = Rect2i(pos, (item["region"] as Rect2i).size)
		check(world.encloses(r), "%s inside the world" % item["tex"])
		var used: Rect2i = Compose.load_image(item["tex"]).get_region(item["region"]).get_used_rect()
		for cr: Rect2i in char_rects:
			check(not Rect2i(pos + used.position, used.size).intersects(cr), "%s does not overlap a character" % item["tex"])
	for internal: Vector2i in ScaleScene.INTERNALS:
		var view: Rect2i = Rect2i(ScaleScene.CAMERA_CENTER - internal / 2, internal)
		check(world.encloses(view), "camera view %s inside the world" % internal)


func _check_scenes() -> void:
	var chars: Node2D = (load("res://chars/chars.tscn") as PackedScene).instantiate() as Node2D
	add_node(chars)
	await await_frames(2)
	check_eq(chars.get("characters").size(), 32, "chars scene: 2 grids of 4x4 characters")
	var ground: TileMapLayer = chars.get_node_or_null("Ground") as TileMapLayer
	if check_not_null(ground, "chars scene has a Ground TileMapLayer"):
		check_eq(ground.get_used_cells().size(), 30 * 17, "ground covers 480x270 with 16 px tiles")
	var first: Character = chars.get("characters")[0] as Character
	check(first.walking, "characters walk in the scene")
	var t0: float = first._time + first.frame * first.frame_time
	await await_frames(10)
	var t1: float = first._time + first.frame * first.frame_time
	check(t1 != t0, "the walk clock runs in the tree (%s -> %s)" % [t0, t1])
	var scale: Node2D = (load("res://chars/scale.tscn") as PackedScene).instantiate() as Node2D
	add_node(scale)
	await await_frames(2)
	check_eq(scale.get("characters").size(), ScaleScene.CHARACTERS.size(), "scale scene characters")
	var cam: Camera2D = scale.get("camera") as Camera2D
	if check_not_null(cam, "scale scene camera"):
		check_eq(cam.position, Vector2(ScaleScene.CAMERA_CENTER), "camera at the world centre")
	scale.queue_free()
