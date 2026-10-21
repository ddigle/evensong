extends SceneTree
## Windowed render check: what the GPU actually draws (needs a renderer, so not part of the
## headless tests). Run from the repo root in a desktop session (a window opens for a few seconds):
##
##   godot --path game --script res://tools/check_render.gd [-- --out=build/render_check] [--save]
##
## Parts (each prints "EVENSONG_RENDER <part> ok|FAIL ..."):
##   ground   every screen pixel around the altar (480x270, the whole safe-zone disc and its
##            surroundings): lit (evening on / off colour ratio) exactly where the ground light
##            texel is lit (LightGen.light_at = texture, which test_light.gd checks against
##            is_in_safe_zone() texel by texel). Reports the ring of pixels within the edge band
##            +/- 8 px separately. Nothing lit outside the radius, the inner disc fully lit.
##   flames   the 81 flame pixels show the lit art colours exactly with the evening on (unshaded).
##   actor    a character standing on the radius: each of its pixels is lit exactly where
##            is_in_safe_zone(pixel centre) (hard actor light, no dither on the body).
##   rig      5 classes x 4 directions x (walk 6 + idle 4 frames + the 8 body actions' 55 frames, M2a),
##            evening off: the screen equals the background plus a CPU composite of the sheets (layer
##            order, re-pivot + anchors, west mirror, 64 action cells on the feet, the held signature
##            hidden), pixel for pixel.
##   ysort    overlapping characters and a character behind / in front of the altar: the one with
##            the lower feet (and the altar by its footprint bottom) is drawn on top. Two more walk
##            into the altar's west and east faces (Movement, side clearance) and stand behind it:
##            none of their pixels may fall on the altar art (nothing of them hidden).
## Exit 0 = all ok, 1 = a mismatch (images saved to --out), 2 = run with --headless.

const CliScript := preload("res://core/cli.gd")
const WORLD_SCENE: String = "res://scenes/world.tscn"
## Screen pixels whose evening-off brightness (r+g+b, 0..3) is below this are too dark to classify.
const MIN_BRIGHTNESS: float = 0.3
## Ratio (evening on / off) above this counts as lit. Lit ~ 0.97, dark ~ 0.35 (Config colours).
const LIT_RATIO: float = 0.66

var out_dir: String = "build/render_check"
## --save: keep every capture in out_dir (for a human look), not only the failing ones.
var save_all: bool = false
var failed: int = 0
var world: GameWorld
var zone: SafeZone


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg == "--save":
			save_all = true
	if DisplayServer.get_name() == "headless":
		printerr("EVENSONG_RENDER error: needs a renderer; run without --headless in a desktop session")
		quit(2)
		return
	root.size = Config.VIEW_SIZE * CliScript.fitting_scale(DisplayServer.screen_get_usable_rect().size)
	root.move_to_center()
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	world = packed.instantiate() as GameWorld
	world.auto_generate = false
	root.add_child(world)
	world.generate(Config.DEFAULT_SEED)
	world.overlay.visible = false
	world.camera.set_process(false)
	world.camera.make_current()
	zone = world.safe_zone
	await _frames(3)
	var view: Vector2i = Vector2i(root.get_visible_rect().size)
	if view != Config.VIEW_SIZE:
		_fail("setup", "viewport is %s, expected %s (window %s)" % [view, Config.VIEW_SIZE, root.size])
	else:
		await _check_ground_and_flames()
		await _check_actor_light()
		await _check_rig()
		await _check_ysort()
	print("EVENSONG_RENDER done %s failed_parts=%d window=%dx%d" % ["ok" if failed == 0 else "FAIL", failed,
		root.size.x, root.size.y])
	quit(0 if failed == 0 else 1)


func _fail(part: String, message: String) -> void:
	failed += 1
	print("EVENSONG_RENDER %s FAIL %s" % [part, message])


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _capture() -> Image:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, file_name: String) -> void:
	var dir: String = out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(file_name))


## Camera centred on a whole pixel; returns the world pixel at screen (0, 0).
func _look_at(center: Vector2i) -> Vector2i:
	world.camera.position = Vector2(center)
	world.camera.reset_smoothing()
	return center - Config.VIEW_SIZE / 2


static func _brightness(c: Color) -> float:
	return c.r + c.g + c.b


func _check_ground_and_flames() -> void:
	var origin: Vector2i = _look_at(Vector2i(zone.center))
	world.lighting.set_evening(true)
	var eve: Image = await _capture()
	world.lighting.set_evening(false)
	var day: Image = await _capture()
	if save_all:
		_save(eve, "ground_evening.png")
		_save(day, "ground_day.png")
	var band: int = Config.SAFE_EDGE_BAND_PX
	var mismatches: int = 0
	var checked: int = 0
	var skipped: int = 0
	var ring: int = 0
	var ring_lit: int = 0
	var ring_dark: int = 0
	var lit_outside: int = 0
	var flame_px: Dictionary[Vector2i, bool] = {}
	var mask: Image = Altar.flame_image()
	var art: Vector2i = world.altar.art_origin()
	for y: int in mask.get_height():
		for x: int in mask.get_width():
			if mask.get_pixel(x, y).a8 > 0:
				flame_px[art + Vector2i(x, y) - origin] = true
	var diff: Image = Image.create_empty(Config.VIEW_SIZE.x, Config.VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	for sy: int in Config.VIEW_SIZE.y:
		for sx: int in Config.VIEW_SIZE.x:
			var s: Vector2i = Vector2i(sx, sy)
			if flame_px.has(s):
				continue  # unshaded: same colour both ways, checked below
			var b: Color = day.get_pixel(sx, sy)
			if _brightness(b) < MIN_BRIGHTNESS:
				skipped += 1
				continue
			var a: Color = eve.get_pixel(sx, sy)
			var lit: bool = _brightness(a) / _brightness(b) > LIT_RATIO
			var px: Vector2i = origin + s
			var want: bool = LightGen.light_at(zone, LightGen.Edge.DITHER, band, px) > 0.5
			checked += 1
			var d: float = (Vector2(px) + Vector2(0.5, 0.5)).distance_to(zone.center)
			if lit and not zone.is_in_safe_zone(Vector2(px) + Vector2(0.5, 0.5)):
				lit_outside += 1
			if d >= zone.radius - band - 8.0 and d <= zone.radius + 8.0:
				ring += 1
				if lit:
					ring_lit += 1
				else:
					ring_dark += 1
			if lit != want:
				mismatches += 1
				diff.set_pixel(sx, sy, Color.MAGENTA)
	var line: String = "screen=%d checked=%d skipped_dark=%d mismatches=%d ring_px=%d (lit %d, dark %d) lit_outside_zone=%d" % [
		Config.VIEW_SIZE.x * Config.VIEW_SIZE.y, checked, skipped, mismatches, ring, ring_lit, ring_dark, lit_outside]
	if mismatches == 0 and lit_outside == 0 and ring_lit > 0 and ring_dark > 0:
		print("EVENSONG_RENDER ground ok %s" % line)
	else:
		_fail("ground", line)
		_save(eve, "ground_evening.png")
		_save(day, "ground_day.png")
		_save(diff, "ground_diff.png")
	# Flames: lit art colours exactly, with and without the evening.
	var lit_art: Image = LightGen.to_rgba8(Altar.LIT.get_image())
	var wrong: int = 0
	var max_diff: int = 0
	for s: Vector2i in flame_px:
		var art_px: Vector2i = s + origin - art
		var want: Color = lit_art.get_pixel(art_px.x, art_px.y)
		for img: Image in [eve, day]:
			var got: Color = img.get_pixel(s.x, s.y)
			var dmax: int = maxi(absi(got.r8 - want.r8), maxi(absi(got.g8 - want.g8), absi(got.b8 - want.b8)))
			max_diff = maxi(max_diff, dmax)
			if dmax > 0:
				wrong += 1
	var fline: String = "pixels=%d wrong=%d max_channel_diff=%d" % [flame_px.size(), wrong, max_diff]
	if flame_px.size() == 81 and wrong == 0:
		print("EVENSONG_RENDER flames ok %s" % fline)
	else:
		_fail("flames", fline)


func _check_actor_light() -> void:
	# A paladin facing south whose body the radius line crosses (east edge of the zone).
	var feet: Vector2i = Vector2i(zone.center) + Vector2i(int(zone.radius) - 2, 20)
	var origin: Vector2i = _look_at(Vector2i(zone.center) + Vector2i(int(zone.radius) - 40, 0))
	world.lighting.set_evening(false)
	var bg: Image = await _capture()
	var c: Character = Character.new()
	c.animate = false
	c.class_id = "paladin"
	c.position = Vector2(feet)
	world.entities.add_child(c)
	var day: Image = await _capture()
	world.lighting.set_evening(true)
	var eve: Image = await _capture()
	var pixels: int = 0
	var lit_count: int = 0
	var mismatches: int = 0
	var skipped: int = 0
	var flips: int = 0
	for sy: int in Config.VIEW_SIZE.y:
		var prev: int = -1
		for sx: int in Config.VIEW_SIZE.x:
			var b: Color = day.get_pixel(sx, sy)
			if b == bg.get_pixel(sx, sy):
				continue  # not a character pixel (or one identical to the ground behind it)
			if _brightness(b) < MIN_BRIGHTNESS:
				skipped += 1
				continue
			pixels += 1
			var lit: bool = _brightness(eve.get_pixel(sx, sy)) / _brightness(b) > LIT_RATIO
			var want: bool = zone.is_in_safe_zone(Vector2(origin + Vector2i(sx, sy)) + Vector2(0.5, 0.5))
			lit_count += int(lit)
			if lit != want:
				mismatches += 1
			if prev >= 0 and prev != int(lit):
				flips += 1
			prev = int(lit)
	world.entities.remove_child(c)
	c.free()
	var line: String = "feet=%s pixels=%d lit=%d dark=%d skipped_dark=%d mismatches=%d lit_dark_switches_in_rows=%d" % [
		feet, pixels, lit_count, pixels - lit_count, skipped, mismatches, flips]
	if pixels > 100 and mismatches == 0 and lit_count > 0 and lit_count < pixels:
		print("EVENSONG_RENDER actor ok %s" % line)
	else:
		_fail("actor", line)
		_save(eve, "actor_evening.png")
		_save(day, "actor_day.png")


## compose() canvas: 64 wide (a 64 action cell fits exactly) and tall enough for an action cell
## (48 px above the feet, 16 below) and the halo; the feet point.
const COMPOSE_SIZE: Vector2i = Vector2i(64, 72)
const COMPOSE_FEET: Vector2i = Vector2i(32, 56)


## CPU composite of one character frame (walk, idle or a body action) on a COMPOSE_SIZE canvas
## whose feet point is COMPOSE_FEET.
static func compose(class_id: String, dir: int, anim: int, frame: int) -> Image:
	var canvas: Image = Image.create_empty(COMPOSE_SIZE.x, COMPOSE_SIZE.y, false, Image.FORMAT_RGBA8)
	var feet: Vector2i = COMPOSE_FEET
	var row: int = RigData.sheet_row(dir)
	var sig: RigData.Signature = RigData.signature_for(class_id)
	var frame_origin: Vector2i = feet - RigData.FRAME_ORIGIN
	for slot: StringName in RigData.draw_order(row):
		if slot == RigData.SLOT_BODY:
			var sheet: Image = LightGen.to_rgba8(RigData.sheet(anim).get_image())
			var r: Rect2i = RigData.body_rect(row, frame, anim)
			canvas.blit_rect_mask(sheet, sheet, r, frame_origin - RigData.body_offset(anim))
		elif slot == sig.slot and not RigData.hides_signature(sig, anim):
			var layer: Image = LightGen.to_rgba8(sig.texture.get_image())
			var r: Rect2i = sig.source_rect(row)
			canvas.blit_rect_mask(layer, layer, r, frame_origin + RigData.layer_frame_pos(sig, anim, row, frame))
	if RigData.is_mirrored(dir):
		canvas.flip_x()  # centred on the feet: local x -> -x
	return canvas


## Pastes a composite (feet at COMPOSE_FEET) onto `dst` with the feet at screen point `feet`,
## except where `keep` (same size as dst, may be null) is opaque.
static func paste(dst: Image, comp: Image, feet: Vector2i, keep: Image = null) -> void:
	var o: Vector2i = feet - COMPOSE_FEET
	for y: int in comp.get_height():
		for x: int in comp.get_width():
			var c: Color = comp.get_pixel(x, y)
			var p: Vector2i = o + Vector2i(x, y)
			if c.a8 == 0 or p.x < 0 or p.y < 0 or p.x >= dst.get_width() or p.y >= dst.get_height():
				continue
			if keep != null and keep.get_pixel(p.x, p.y).a8 > 0:
				continue
			dst.set_pixel(p.x, p.y, c)


static func count_diff(a: Image, b: Image) -> int:
	if a.get_data() == b.get_data():
		return 0
	var n: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _check_rig() -> void:
	world.lighting.set_evening(false)
	var origin: Vector2i = _look_at(Vector2i(400, 400))
	var bg: Image = await _capture()
	var chars: Array[Character] = []
	var feet_list: Array[Vector2i] = []
	for ci: int in Config.CLASSES.size():
		for dir: int in 4:
			var c: Character = Character.new()
			c.animate = false
			c.class_id = Config.CLASSES[ci]
			c.direction = dir as RigData.Dir
			var feet: Vector2i = Vector2i(60 + ci * 80, 60 + dir * 60)
			c.position = Vector2(origin + feet)
			world.entities.add_child(c)
			chars.append(c)
			feet_list.append(feet)
	var frames_checked: int = 0
	var action_frames: int = 0
	var total_mismatch: int = 0
	# Within a class column the rows go down the screen, so pasting in list order = the y-sort order
	# where an action cell (16 px below the feet) reaches the next row's cell (48 px above its feet).
	for anim: int in RigData.ANIM_NAMES.size():
		for f: int in RigData.frame_count(anim):
			var expected: Image = bg.duplicate() as Image
			for i: int in chars.size():
				var c: Character = chars[i]
				if RigData.is_action(anim):
					c.show_action(anim, f)
				else:
					c.end_action()
					c.walking = anim == RigData.Anim.WALK
					c.frame = f
				paste(expected, compose(c.class_id, c.direction, anim, f), feet_list[i])
			var got: Image = await _capture()
			var n: int = count_diff(got, expected)
			frames_checked += 1
			if RigData.is_action(anim):
				action_frames += 1
			total_mismatch += n
			if n > 0 or save_all:
				_save(got, "rig_%s_%d_got.png" % [RigData.ANIM_NAMES[anim], f])
				_save(expected, "rig_%s_%d_expected.png" % [RigData.ANIM_NAMES[anim], f])
	for c: Character in chars:
		world.entities.remove_child(c)
		c.free()
	var line: String = "characters=%d frames=%d (actions %d) screens=%d pixels=%d mismatches=%d" % [chars.size(),
		frames_checked, action_frames, frames_checked, frames_checked * Config.VIEW_SIZE.x * Config.VIEW_SIZE.y,
		total_mismatch]
	if total_mismatch == 0:
		print("EVENSONG_RENDER rig ok %s" % line)
	else:
		_fail("rig", line)


## Feet position after walking `dir` from `start` until something stops it (Movement rules).
func _pressed(start: Vector2, dir: Vector2i) -> Vector2i:
	var p: Vector2 = start
	for i: int in 240:
		p = Movement.step(world.data, p, dir, Config.NET_TICK)
	return Vector2i(p.round())


## Opaque pixels of `comp` (feet at COMPOSE_FEET) pasted with the feet at `feet` that land on an
## opaque pixel of `mask`.
static func _hidden_by(comp: Image, feet: Vector2i, mask: Image) -> int:
	var o: Vector2i = feet - COMPOSE_FEET
	var n: int = 0
	for y: int in comp.get_height():
		for x: int in comp.get_width():
			var p: Vector2i = o + Vector2i(x, y)
			if comp.get_pixel(x, y).a8 > 0 and p.x >= 0 and p.y >= 0 and p.x < mask.get_width() and p.y < mask.get_height() \
					and mask.get_pixel(p.x, p.y).a8 > 0:
				n += 1
	return n


func _check_ysort() -> void:
	world.lighting.set_evening(false)
	var origin: Vector2i = _look_at(Vector2i(zone.center))
	var bg: Image = await _capture()
	var fp: Rect2i = Rect2i(world.data.altar_rect.position * Config.TILE, world.data.altar_rect.size * Config.TILE)
	# Altar alpha on screen (the altar is in front of characters whose feet are above its bottom).
	var altar_alpha: Image = Image.create_empty(Config.VIEW_SIZE.x, Config.VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	var art: Image = LightGen.to_rgba8(Altar.LIT.get_image())
	altar_alpha.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), world.altar.art_origin() - origin)
	# [class, dir, feet (world)], added in this order; y-sort must draw by feet y.
	var setups: Array[Array] = [
		["miner", RigData.Dir.SOUTH, Vector2i(fp.position.x - 60, fp.end.y + 30)],   # front of the pair
		["paladin", RigData.Dir.EAST, Vector2i(fp.position.x - 66, fp.end.y + 24)],  # behind it (added later)
		["archer", RigData.Dir.SOUTH, Vector2i(fp.position.x + 12, fp.end.y - 3)],   # behind the altar
		["cleric", RigData.Dir.NORTH, Vector2i(fp.position.x + 34, fp.end.y + 6)],   # in front of the altar
		["miner", RigData.Dir.EAST, _pressed(Vector2(fp.position.x - 40, fp.position.y + 30), Vector2i(1, 0))],  # at the west face
		["archer", RigData.Dir.WEST, _pressed(Vector2(fp.end.x + 40, fp.position.y + 20), Vector2i(-1, 0))],   # at the east face
	]
	var chars: Array[Character] = []
	for s: Array in setups:
		var c: Character = Character.new()
		c.animate = false
		c.class_id = s[0]
		c.direction = s[1]
		var feet: Vector2i = s[2]
		c.position = Vector2(feet)
		world.entities.add_child(c)
		chars.append(c)
	var got: Image = await _capture()
	if save_all:
		_save(got, "ysort.png")
	# Expected: background, then characters by feet y (the altar is already in the background:
	# characters above its bottom row keep the altar's pixels).
	var order: Array[int] = [0, 1, 2, 3, 4, 5]
	order.sort_custom(func(a: int, b: int) -> bool: return chars[a].position.y < chars[b].position.y)
	var expected: Image = bg.duplicate() as Image
	var altar_y: float = world.altar.position.y
	var side_hidden: int = 0
	for i: int in order:
		var c: Character = chars[i]
		var keep: Image = altar_alpha if c.position.y < altar_y else null
		var comp: Image = compose(c.class_id, c.direction, c.anim, c.frame)
		if i >= 4:
			side_hidden += _hidden_by(comp, Vector2i(c.position) - origin, altar_alpha)
		paste(expected, comp, Vector2i(c.position) - origin, keep)
	var n: int = count_diff(got, expected)
	# The setups must actually overlap something, or the check proves nothing.
	var naive: Image = bg.duplicate() as Image
	for i: int in chars.size():
		var c: Character = chars[i]
		paste(naive, compose(c.class_id, c.direction, c.anim, c.frame), Vector2i(c.position) - origin)
	var naive_diff: int = count_diff(naive, expected)
	for c: Character in chars:
		world.entities.remove_child(c)
		c.free()
	var line: String = "characters=%d mismatches=%d pixels_that_tree_order_would_get_wrong=%d side_pixels_hidden=%d" % [
		chars.size(), n, naive_diff, side_hidden]
	if n == 0 and naive_diff > 0 and side_hidden == 0:
		print("EVENSONG_RENDER ysort ok %s" % line)
	else:
		_fail("ysort", line)
		_save(got, "ysort_got.png")
		_save(expected, "ysort_expected.png")
