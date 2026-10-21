extends Node2D
## res://chars/scale.tscn: stage-4 assets on a 16 px grid for the screen scale check.
## Open it with: godot --path . -- --scene=res://chars/scale.tscn   (or the path directly)
##
## World 48x28 tiles of grass with a crop field (crops_v03_sheet: rows recovery/buff/poison,
## columns stage 0-4, harvest, withered), the altar (3x3 tiles), the alchemy table (3x2 tiles)
## and four layered characters. The camera is centred, so 480x270 and 640x360 show the same middle.
##
## Shots (needs a renderer, so no --headless; the window opens briefly):
##   godot --path . res://chars/scale.tscn -- --chars-scale-shots=shots
## For internal 480x270 and 640x360 and windows 1920x1080, 2560x1440, 3840x2160 (aspect "keep",
## the project setting) it sets the real root window, reads the stretch Godot applies
## (Window.get_final_transform()), reads the internal render target and compares it with a CPU
## picture of the world, and writes shots/scale_<internal>_internal.png and
## shots/scale_<internal>_<window>.png (the presented frame: the render target upscaled by the
## integer factor with nearest sampling, black borders, see notes/chars.md for why this is
## rebuilt and not read back from the swapchain). Then prints a table for more window sizes with
## aspect "keep" and "expand" (no files). Lines start with CHARS_SCALE.
##
## Desktop check (a person at the desktop, not over SSH):
##   godot --path . res://chars/scale.tscn -- --scale=4 --chars-present-check
## captures the window from the screen and compares it with the rebuilt presented frame.
## Windows 11 rounds the corners of a normal window, so mismatches inside the two bottom
## PRESENT_CORNER squares are counted apart and do not fail the check. On any mismatch the
## capture, the expected frame and a diff mask go to build/shots/present_*.png.

const Data := preload("res://chars/char_data.gd")
const Compose := preload("res://chars/compose.gd")
const Character := preload("res://chars/layered_character.gd")
const CharsScene := preload("res://chars/chars_scene.gd")
const SpikeCli := preload("res://skeleton/spike_cli.gd")

const TILE: int = 16
## Side of the bottom corner squares the present check sets apart (window corner rounding is
## 8 px at 100 % display scale and grows with it).
const PRESENT_CORNER: int = 32
const WORLD_TILES: Vector2i = Vector2i(48, 28)
const CAMERA_CENTER: Vector2i = Vector2i(384, 224)

const INTERNALS: Array[Vector2i] = [Vector2i(480, 270), Vector2i(640, 360)]
const WINDOWS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
## Extra window sizes for the printed table (laptops, Steam Deck, 16:10, ultrawide).
const TABLE_WINDOWS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(2560, 1440),
	Vector2i(2560, 1600), Vector2i(3440, 1440), Vector2i(3840, 2160),
]

const CROPS_SHEET: String = "res://art/chars/crops_v03_sheet.png"
const ALTAR: String = "res://art/chars/altar_v04.png"
const TABLE: String = "res://art/chars/alchemy_table_v05.png"

## Characters: [tile, direction, signature]. Feet at the bottom centre of the tile.
const CHARACTERS: Array = [
	[Vector2i(21, 15), Data.Dir.SOUTH, &"pickaxe"],
	[Vector2i(24, 15), Data.Dir.SOUTH, &"halo"],
	[Vector2i(27, 15), Data.Dir.EAST, &"pouch"],
	[Vector2i(30, 15), Data.Dir.WEST, &""],
]

var camera: Camera2D
var characters: Array[Character] = []


## Sprites in draw order: {"tex": path, "region": Rect2i, "pos": Vector2i (top-left, world px)}.
## Every item's top-left sits on the 16 px grid.
static func layout_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: int in 3:
		for col: int in 7:
			out.append({"tex": CROPS_SHEET, "region": Rect2i(col * TILE, row * TILE, TILE, TILE),
				"pos": Vector2i(15 + col, 11 + row) * TILE})
	out.append({"tex": ALTAR, "region": Rect2i(0, 0, 48, 57), "pos": Vector2i(23, 10) * TILE})
	out.append({"tex": TABLE, "region": Rect2i(0, 0, 48, 32), "pos": Vector2i(28, 11) * TILE})
	return out


static func character_feet(tile: Vector2i) -> Vector2i:
	return Vector2i(tile.x * TILE + TILE / 2, (tile.y + 1) * TILE)


## Integer stretch as the project uses it (viewport mode, aspect keep): the largest whole factor
## that fits, the scaled content and the black border on each side.
static func stretch_math(window: Vector2i, internal: Vector2i) -> Dictionary:
	var factor: int = maxi(1, mini(window.x / internal.x, window.y / internal.y))
	var content: Vector2i = internal * factor
	return {"scale": factor, "content": content, "border": (window - content) / 2}


## CPU picture of the whole world (grass, items, characters at their current frame).
func world_image() -> Image:
	var out: Image = CharsScene.ground_image(WORLD_TILES * TILE)
	for item: Dictionary in layout_items():
		var src: Image = Compose.load_image(item["tex"])
		out.blend_rect(src, item["region"], item["pos"])
	for c: Character in characters:
		CharsScene.paste_character(out, c, Vector2i(c.position))
	return out


## Like CharsScene.diff_images, but splits the mismatches into those inside the two bottom
## `corner` x `corner` squares and the rest, and returns their bounding box and a mask image.
static func present_diff(actual: Image, expected: Image, corner: int) -> Dictionary:
	var w: int = actual.get_width()
	var h: int = actual.get_height()
	if actual.get_size() != expected.get_size():
		return {"count": -1, "outside": -1, "first": "size %s vs %s" % [actual.get_size(), expected.get_size()]}
	var mask: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var count: int = 0
	var outside: int = 0
	var first: String = ""
	var lo: Vector2i = Vector2i(w, h)
	var hi: Vector2i = Vector2i(-1, -1)
	for y: int in h:
		for x: int in w:
			var a: int = actual.get_pixel(x, y).to_rgba32()
			var e: int = expected.get_pixel(x, y).to_rgba32()
			if a == e:
				continue
			if count == 0:
				first = "(%d,%d) got %08x want %08x" % [x, y, a, e]
			count += 1
			var in_corner: bool = y >= h - corner and (x < corner or x >= w - corner)
			if not in_corner:
				outside += 1
			mask.set_pixel(x, y, Color.YELLOW if in_corner else Color.MAGENTA)
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var bbox: String = "none" if count == 0 else "%d,%d-%d,%d" % [lo.x, lo.y, hi.x, hi.y]
	return {"count": count, "outside": outside, "first": first, "bbox": bbox, "mask": mask}


## The frame a viewport-mode window presents: render target upscaled by `factor` (nearest),
## placed at `offset` on black.
static func present(internal: Image, window: Vector2i, factor: int, offset: Vector2i) -> Image:
	var up: Image = internal.duplicate() as Image
	up.resize(internal.get_width() * factor, internal.get_height() * factor, Image.INTERPOLATE_NEAREST)
	var out: Image = Image.create_empty(window.x, window.y, false, Image.FORMAT_RGBA8)
	out.fill(Color.BLACK)
	out.blit_rect(up, Rect2i(Vector2i.ZERO, up.get_size()), offset)
	return out


func _ready() -> void:
	add_child(CharsScene.build_ground(WORLD_TILES))
	for item: Dictionary in layout_items():
		var s: Sprite2D = Sprite2D.new()
		s.texture = load(item["tex"]) as Texture2D
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(item["region"])
		s.position = Vector2(item["pos"])
		add_child(s)
	for spec: Array in CHARACTERS:
		var c: Character = Character.new()
		c.position = Vector2(character_feet(spec[0]))
		c.direction = spec[1]
		c.signature = spec[2]
		add_child(c)
		characters.append(c)
	camera = Camera2D.new()
	camera.position = Vector2(CAMERA_CENTER)
	add_child(camera)
	camera.make_current()
	var args: Dictionary = SpikeCli.parse_user_args(OS.get_cmdline_user_args())
	if args.has("chars-scale-shots"):
		_run_shots.call_deferred(str(args["chars-scale-shots"]))
	elif args.has("chars-present-check"):
		_run_present_check.call_deferred()


func _freeze() -> void:
	for c: Character in characters:
		c.walking = false
		c.frame = 0


func _settle(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _view_rect(internal: Vector2i) -> Rect2i:
	return Rect2i(Vector2i(camera.get_screen_center_position()) - internal / 2, internal)


func _run_shots(dir: String) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("chars: --chars-scale-shots needs a renderer. Run without --headless.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	_freeze()
	var root: Window = get_tree().root
	var world: Image = world_image()
	var failed: int = 0
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for internal: Vector2i in INTERNALS:
		root.content_scale_size = internal
		var tag: String = "%dx%d" % [internal.x, internal.y]
		for window: Vector2i in WINDOWS:
			root.size = window
			await _settle(4)
			var xf: Transform2D = root.get_final_transform()
			var shot: Image = root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			var d: Dictionary = CharsScene.diff_images(shot, world.get_region(_view_rect(internal)))
			var math: Dictionary = stretch_math(window, internal)
			var sx: float = xf.x.x
			var square: bool = sx == xf.y.y and xf.x.y == 0.0 and xf.y.x == 0.0
			var whole: bool = sx == floorf(sx) and xf.origin == xf.origin.floor()
			var as_math: bool = int(sx) == math["scale"] and Vector2i(xf.origin) == math["border"]
			var ok: bool = square and whole and as_math and root.size == window and int(d["count"]) == 0
			if not ok:
				failed += 1
			if window == WINDOWS[0]:
				shot.save_png(dir.path_join("scale_%s_internal.png" % tag))
			var presented: Image = present(shot, root.size, int(sx), Vector2i(xf.origin))
			presented.save_png(dir.path_join("scale_%s_%dx%d.png" % [tag, window.x, window.y]))
			print("CHARS_SCALE %s internal=%s window=%dx%d got=%dx%d scale=%s square=%s whole=%s border=%dx%d content=%dx%d tiles=%.2fx%.3f internal_mismatches=%d %s" % [
				"ok" if ok else "FAIL", tag, window.x, window.y, root.size.x, root.size.y, sx, square, whole,
				int(xf.origin.x), int(xf.origin.y), int(sx) * internal.x, int(sx) * internal.y,
				internal.x / float(TILE), internal.y / float(TILE), d["count"], d["first"]])
	# Table: more window sizes, aspect keep (project setting) and expand (fills the borders
	# with more world instead of black).
	for internal: Vector2i in INTERNALS:
		root.content_scale_size = internal
		for aspect: int in [Window.CONTENT_SCALE_ASPECT_KEEP, Window.CONTENT_SCALE_ASPECT_EXPAND]:
			root.content_scale_aspect = aspect as Window.ContentScaleAspect
			for window: Vector2i in TABLE_WINDOWS:
				root.size = window
				await _settle(2)
				var xf: Transform2D = root.get_final_transform()
				var visible: Vector2 = root.get_visible_rect().size
				var content: Vector2 = visible * xf.x.x
				# offset = where Godot puts the picture (its own transform); a fraction here means
				# the picture is not on whole screen pixels.
				print("CHARS_SCALE_TABLE internal=%dx%d aspect=%s window=%dx%d scale=%s visible=%dx%d tiles=%.2fx%.2f offset=%sx%s content=%dx%d spare=%dx%d" % [
					internal.x, internal.y, "keep" if aspect == Window.CONTENT_SCALE_ASPECT_KEEP else "expand",
					window.x, window.y, xf.x.x, int(visible.x), int(visible.y), visible.x / TILE, visible.y / TILE,
					xf.origin.x, xf.origin.y, int(content.x), int(content.y),
					window.x - int(content.x), window.y - int(content.y)])
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	print("CHARS_SCALE_DONE %s failed=%d" % ["ok" if failed == 0 else "FAIL", failed])
	get_tree().quit(0 if failed == 0 else 1)


func _run_present_check() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("chars: --chars-present-check needs a renderer and a desktop.")
		get_tree().quit(2)
		return
	_freeze()
	var root: Window = get_tree().root
	await _settle(20)
	var xf: Transform2D = root.get_final_transform()
	var shot: Image = root.get_texture().get_image()
	shot.convert(Image.FORMAT_RGBA8)
	var expected: Image = present(shot, root.size, int(xf.x.x), Vector2i(xf.origin))
	var rect: Rect2i = Rect2i(DisplayServer.window_get_position(), root.size)
	var cap: Image = DisplayServer.screen_get_image_rect(rect)
	if cap == null or cap.is_empty() or cap.is_invisible():
		print("CHARS_PRESENT unavailable: the screen capture is empty (SSH / session 0 has no desktop to read)")
		get_tree().quit(3)
		return
	cap.convert(Image.FORMAT_RGBA8)
	var d: Dictionary = present_diff(cap, expected, PRESENT_CORNER)
	var count: int = int(d["count"])
	var outside: int = int(d["outside"])
	var ok: bool = count >= 0 and outside == 0
	print("CHARS_PRESENT %s window=%dx%d scale=%s mismatches=%d outside_corners=%d corners=%d bbox=%s %s" % [
		"ok" if ok else "FAIL", root.size.x, root.size.y, xf.x.x, count, outside,
		maxi(count - outside, 0), d.get("bbox", "none"), d["first"]])
	if count != 0:
		var dir: String = ProjectSettings.globalize_path("res://build/shots")
		DirAccess.make_dir_recursive_absolute(dir)
		cap.save_png(dir.path_join("present_capture.png"))
		expected.save_png(dir.path_join("present_expected.png"))
		if d.has("mask"):
			(d["mask"] as Image).save_png(dir.path_join("present_diff.png"))
		print("CHARS_PRESENT_FILES %s (present_capture/expected/diff.png; diff: magenta = outside the corners, yellow = bottom corners)" % dir)
	get_tree().quit(0 if ok else 1)
