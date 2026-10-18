extends RefCounted
## CPU reference for the layered character (static helpers, no state).
##
## The node (layered_character.gd) and these helpers read the same tables in char_data.gd.
## compose() builds the expected image of one character frame on the CPU; chars_scene.gd
## compares it pixel by pixel with what the GPU actually drew (--chars-shots). The tests use
## it headless (the dummy renderer draws nothing).
##
## Images are read from the source PNGs (res://art/chars/*.png) with Image.load(), which works
## in the project folder but not in an exported build (only the imported textures are packed).

const Data := preload("res://chars/char_data.gd")

## Composite canvas in character-local coordinates (origin = feet): room for the halo above and
## for layers that hang below the feet line (the north pouch drops 1 px on frames 1-2).
const CANVAS: Rect2i = Rect2i(-16, -40, 32, 48)

static var _cache: Dictionary = {}


static func load_image(path: String) -> Image:
	if _cache.has(path):
		return _cache[path]
	var img: Image = Image.new()
	var err: Error = img.load(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("compose: cannot load %s (%d)" % [path, err])
		return null
	img.convert(Image.FORMAT_RGBA8)
	_cache[path] = img
	return img


## Source rect of a body frame in the body sheet.
static func body_rect(row: int, frame: int) -> Rect2i:
	return Rect2i(Vector2i(frame * Data.FRAME_SIZE.x, row * Data.FRAME_SIZE.y), Data.FRAME_SIZE)


## Source rect of a signature layer for a sheet row.
static func layer_rect(signature: StringName, row: int) -> Rect2i:
	var info: Dictionary = Data.SIGNATURES[signature]
	if info["layout"] == &"single":
		var img: Image = load_image(info["sheet"])
		return Rect2i(Vector2i.ZERO, img.get_size())
	return Rect2i(Vector2i(row * Data.FRAME_SIZE.x, 0), Data.FRAME_SIZE)


## Applies the tunic palette swap to `img` in place, the same rule as palette_swap.gdshader:
## an opaque texel inside the frame-local row band whose RGB equals src[i] becomes dst[i].
## Returns the number of changed pixels.
static func apply_palette(img: Image, rect: Rect2i, palette: StringName) -> int:
	var src: PackedColorArray = Data.source_colors()
	var dst: PackedColorArray = Data.palette_colors(palette)
	if dst.is_empty():
		return 0
	var lookup: Dictionary = {}
	for i: int in src.size():
		lookup[src[i].to_rgba32() | 0xff] = dst[i]
	var changed: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		var local_y: int = posmod(y, Data.FRAME_SIZE.y)
		if local_y < Data.TUNIC_BAND.x or local_y > Data.TUNIC_BAND.y:
			continue
		for x: int in range(rect.position.x, rect.end.x):
			var c: Color = img.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var key: int = c.to_rgba32() | 0xff
			if lookup.has(key):
				var d: Color = lookup[key]
				img.set_pixel(x, y, Color(d.r, d.g, d.b, c.a))
				changed += 1
	return changed


## Expected pixels of one character frame on CANVAS (transparent where nothing is drawn).
## Layers are pasted in the draw order of the sheet row; west is the east result mirrored.
static func compose(direction: int, signature: StringName, palette: StringName, frame: int) -> Image:
	var row: int = Data.sheet_row(direction)
	var out: Image = Image.create_empty(CANVAS.size.x, CANVAS.size.y, false, Image.FORMAT_RGBA8)
	var frame_origin: Vector2i = -Data.FRAME_ORIGIN - CANVAS.position  # frame (0,0) on the canvas
	for slot: StringName in Data.DRAW_ORDER[row]:
		if slot == Data.SLOT_BODY:
			var body: Image = load_image(Data.BODY_SHEET).duplicate() as Image
			apply_palette(body, body_rect(row, frame), palette)
			_paste(out, body, body_rect(row, frame), frame_origin)
		elif not signature.is_empty() and Data.SIGNATURES[signature]["slot"] == slot:
			var sheet: Image = load_image(Data.SIGNATURES[signature]["sheet"])
			var pos: Vector2i = frame_origin + Data.layer_frame_pos(signature, row, frame)
			_paste(out, sheet, layer_rect(signature, row), pos)
	if Data.is_mirrored(direction):
		# The canvas is centred on the origin, so a left-right flip mirrors around x = 0.
		out.flip_x()
	return out


## Pastes opaque pixels of src_rect at dst_pos (all our art has 1-bit alpha).
static func _paste(dst: Image, src: Image, src_rect: Rect2i, dst_pos: Vector2i) -> void:
	for y: int in src_rect.size.y:
		for x: int in src_rect.size.x:
			var c: Color = src.get_pixel(src_rect.position.x + x, src_rect.position.y + y)
			if c.a8 == 0:
				continue
			var p: Vector2i = dst_pos + Vector2i(x, y)
			if p.x >= 0 and p.y >= 0 and p.x < dst.get_width() and p.y < dst.get_height():
				dst.set_pixel(p.x, p.y, c)


## Anchor offsets of a body band (rows band.x..band.y in v01 frame coordinates) for every frame
## of a sheet row: the (dx, dy) within +/-radius where the most frame-0 band pixels find a pixel
## of similar colour (sum of RGB differences < tolerance) in frame f. Ties prefer the smaller
## move. This is the "몸통 줄 정렬" rule from 03-pixel/prompts.md, run on the v02 sheet.
static func anchor_offsets(row: int, band: Vector2i, radius: int, tolerance: int) -> Array[Vector2i]:
	var sheet: Image = load_image(Data.BODY_SHEET)
	var shift: int = Data.LAYER_SHIFT[row]
	var w: int = Data.FRAME_SIZE.x
	var h: int = Data.FRAME_SIZE.y
	# Opaque frame-0 pixels inside the band: [x, y, r, g, b]
	var ref: Array[PackedInt32Array] = []
	for y: int in range(band.x + shift, band.y + shift + 1):
		for x: int in w:
			var c: Color = sheet.get_pixel(x, row * h + y)
			if c.a8 > 0:
				ref.append(PackedInt32Array([x, y, c.r8, c.g8, c.b8]))
	var out: Array[Vector2i] = []
	for f: int in Data.FRAME_COUNT:
		# Frame f as a flat RGB(A) lookup for speed.
		var data: PackedByteArray = sheet.get_region(body_rect(row, f)).get_data()
		var best: Vector2i = Vector2i.ZERO
		var best_score: int = -1
		var best_dist: int = 1 << 20
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var score: int = 0
				for p: PackedInt32Array in ref:
					var x: int = p[0] + dx
					var y: int = p[1] + dy
					if x < 0 or y < 0 or x >= w or y >= h:
						continue
					var i: int = (y * w + x) * 4
					if data[i + 3] == 0:
						continue
					if absi(data[i] - p[2]) + absi(data[i + 1] - p[3]) + absi(data[i + 2] - p[4]) < tolerance:
						score += 1
				var dist: int = absi(dx) + absi(dy)
				if score > best_score or (score == best_score and dist < best_dist):
					best_score = score
					best_dist = dist
					best = Vector2i(dx, dy)
		out.append(best)
	return out
