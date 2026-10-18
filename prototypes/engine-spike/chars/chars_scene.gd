extends Node2D
## Entry scene res://chars/chars.tscn: layered characters on grass, all walking.
##
## Left grid (default tunic): rows = no signature, pouch, pickaxe, halo; columns = S, E, W, N.
## Right grid: the same rows with a recoloured tunic (teal, moss, wine, sky).
##
## Shots + GPU check (needs a renderer, so no --headless; the window opens briefly):
##   godot --path . res://chars/chars.tscn -- --chars-shots=shots
## For each walk frame 0-5 it freezes the animation, reads the 480x270 render target and compares
## it pixel by pixel with the CPU reference (compose.gd: same layer order, offsets, mirror and
## palette rule). Prints "CHARS_VERIFY ..." and quits 0 when every pixel matches, else 1.
## Writes shots/chars_layers.png (480x270, frame 0), chars_layers_x3.png and chars_walk_x2.png.

const Data := preload("res://chars/char_data.gd")
const Compose := preload("res://chars/compose.gd")
const Character := preload("res://chars/layered_character.gd")
const SpikeCli := preload("res://skeleton/spike_cli.gd")

const GRASS_TILE: String = "res://art/chars/tiles_grass_base_v02.png"
const TILE: int = 16
const VIEW: Vector2i = Vector2i(480, 270)

## Feet of the top-left character and the grid step.
const LEFT_ORIGIN: Vector2i = Vector2i(32, 60)
const RIGHT_ORIGIN: Vector2i = Vector2i(272, 60)
const STEP: Vector2i = Vector2i(40, 56)
const ROW_SIGNATURES: Array[StringName] = [&"", &"pouch", &"pickaxe", &"halo"]
const ROW_PALETTES: Array[StringName] = [&"teal", &"moss", &"wine", &"sky"]
const COLUMN_DIRS: Array[int] = [Data.Dir.SOUTH, Data.Dir.EAST, Data.Dir.WEST, Data.Dir.NORTH]
## Region of the left grid used for the walk strip.
const LEFT_BLOCK: Rect2i = Rect2i(8, 16, 168, 220)

var characters: Array[Character] = []
var ground: TileMapLayer


func _ready() -> void:
	ground = build_ground(Vector2i(ceili(VIEW.x / float(TILE)), ceili(VIEW.y / float(TILE))))
	add_child(ground)
	for row: int in ROW_SIGNATURES.size():
		for col: int in COLUMN_DIRS.size():
			_add_character(LEFT_ORIGIN + STEP * Vector2i(col, row), COLUMN_DIRS[col], ROW_SIGNATURES[row], &"default")
			_add_character(RIGHT_ORIGIN + STEP * Vector2i(col, row), COLUMN_DIRS[col], ROW_SIGNATURES[row], ROW_PALETTES[row])
	var args: Dictionary = SpikeCli.parse_user_args(OS.get_cmdline_user_args())
	if args.has("chars-shots"):
		_run_shots.call_deferred(str(args["chars-shots"]))


## Grass TileMapLayer of `size` tiles from our 16x16 grass tile (one atlas tile).
static func build_ground(size: Vector2i) -> TileMapLayer:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = load(GRASS_TILE) as Texture2D
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)
	var source_id: int = tile_set.add_source(source)
	var layer: TileMapLayer = TileMapLayer.new()
	layer.name = &"Ground"
	layer.tile_set = tile_set
	for y: int in size.y:
		for x: int in size.x:
			layer.set_cell(Vector2i(x, y), source_id, Vector2i.ZERO)
	return layer


## CPU picture of the grass ground (top-left at 0,0).
static func ground_image(size_px: Vector2i) -> Image:
	var tile: Image = Compose.load_image(GRASS_TILE)
	var out: Image = Image.create_empty(size_px.x, size_px.y, false, Image.FORMAT_RGBA8)
	for y: int in range(0, size_px.y, TILE):
		for x: int in range(0, size_px.x, TILE):
			out.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(x, y))
	return out


## Pastes a character's CPU composite (opaque pixels) with its feet at `feet`.
static func paste_character(dst: Image, c: Character, feet: Vector2i) -> void:
	var img: Image = Compose.compose(c.direction, c.signature, c.palette, c.frame)
	var top_left: Vector2i = feet + Compose.CANVAS.position
	for y: int in img.get_height():
		for x: int in img.get_width():
			var px: Color = img.get_pixel(x, y)
			if px.a8 == 0:
				continue
			var p: Vector2i = top_left + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < dst.get_width() and p.y < dst.get_height():
				dst.set_pixel(p.x, p.y, px)


## Number of pixels that differ (RGBA8), and the first difference as text.
static func diff_images(actual: Image, expected: Image) -> Dictionary:
	if actual.get_size() != expected.get_size():
		return {"count": -1, "first": "size %s vs %s" % [actual.get_size(), expected.get_size()]}
	if actual.get_format() == expected.get_format() and actual.get_data() == expected.get_data():
		return {"count": 0, "first": ""}
	var count: int = 0
	var first: String = ""
	for y: int in actual.get_height():
		for x: int in actual.get_width():
			var a: int = actual.get_pixel(x, y).to_rgba32()
			var e: int = expected.get_pixel(x, y).to_rgba32()
			if a != e:
				if count == 0:
					first = "(%d,%d) got %08x want %08x" % [x, y, a, e]
				count += 1
	return {"count": count, "first": first}


func _add_character(feet: Vector2i, direction: int, signature: StringName, palette: StringName) -> void:
	var c: Character = Character.new()
	c.position = Vector2(feet)
	c.direction = direction
	c.signature = signature
	c.palette = palette
	add_child(c)
	characters.append(c)


func expected_frame() -> Image:
	var out: Image = ground_image(VIEW)
	for c: Character in characters:
		paste_character(out, c, Vector2i(c.position))
	return out


func _run_shots(dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("chars: --chars-shots needs a renderer. Run without --headless.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	for c: Character in characters:
		c.walking = false
	var total: int = 0
	var bad: int = 0
	var strip: Image = Image.create_empty(LEFT_BLOCK.size.x * Data.FRAME_COUNT, LEFT_BLOCK.size.y, false, Image.FORMAT_RGBA8)
	for f: int in Data.FRAME_COUNT:
		for c: Character in characters:
			c.frame = f
		for i: int in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = get_viewport().get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var expected: Image = expected_frame()
		var d: Dictionary = diff_images(shot, expected)
		total += shot.get_width() * shot.get_height()
		var n: int = d["count"]
		bad += n if n >= 0 else 1
		print("CHARS_FRAME %d size=%dx%d mismatches=%d %s" % [f, shot.get_width(), shot.get_height(), d["count"], d["first"]])
		if int(d["count"]) != 0:
			expected.save_png(dir.path_join("chars_expected_f%d.png" % f))
			shot.save_png(dir.path_join("chars_actual_f%d.png" % f))
		if f == 0:
			shot.save_png(dir.path_join("chars_layers.png"))
			var x3: Image = shot.duplicate() as Image
			x3.resize(shot.get_width() * 3, shot.get_height() * 3, Image.INTERPOLATE_NEAREST)
			x3.save_png(dir.path_join("chars_layers_x3.png"))
		strip.blit_rect(shot, LEFT_BLOCK, Vector2i(f * LEFT_BLOCK.size.x, 0))
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	strip.save_png(dir.path_join("chars_walk_x2.png"))
	print("CHARS_VERIFY %s frames=%d characters=%d pixels=%d mismatches=%d" % [
		"ok" if bad == 0 else "FAIL", Data.FRAME_COUNT, characters.size(), total, bad])
	get_tree().quit(0 if bad == 0 else 1)
