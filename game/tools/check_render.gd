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
##   items    (M2b) the gatherables and a drop on screen, evening off: the screen equals the screen
##            without them plus each one's art (world picture / icon) on its tile, pixel for pixel.
##   ysort    overlapping characters and a character behind / in front of the altar: the one with
##            the lower feet (and the altar by its footprint bottom) is drawn on top. Two more walk
##            into the altar's west and east faces (Movement, side clearance) and stand behind it:
##            none of their pixels may fall on the altar art (nothing of them hidden).
##   cave     (M3a) the seed-1 dungeon around its arrival room, darkness off, its entities hidden,
##            walls partly mined (crack stages 1-3 on faced and side walls, a broken tile): the screen
##            equals a CPU composite of the cliff tiles each display cell has (CaveView.drawn_at) plus
##            the ore and crack overlays, pixel for pixel. The surface world is hidden meanwhile.
##   dark     (M3a) the dungeon's darkness with one placed torch (the other lights off, the other
##            entities hidden): pixels farther than the torch radius stay dark (darkness on / off ratio),
##            pixels in its inner step are lit; the torch's spot is not the safe zone (light only).
##   cave_net (M3b) the dungeon as a session client gets it: the host's seed-1 dungeon mined with the
##            real rules (Mining.strike: a miner's 3x3 cracked and another broken, a common player's
##            cracks at stages 2 and 3), applied edit by edit to the host's view; a client world built
##            from a map snapshot taken half way (WorldSnapshot, Receiver.finish for the dungeon) gets the
##            rest as live edits. Both screens (darkness off, entities hidden) must be the same pixels,
##            and equal the CPU composite of the client's data (tiles + ore and crack overlays).
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
		await _check_items()
		await _check_ysort()
		await _check_cave_and_dark()
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


## M2b: gatherables (ItemView, world pictures) and a drop (its icon) drawn exactly on their tiles.
func _check_items() -> void:
	world.lighting.set_evening(false)
	var data: WorldData = world.data
	var cells: Array[Vector2i] = WorldItems.gatherable_cells(data)
	if cells.is_empty():
		_fail("items", "no gatherables in the world")
		return
	# Centre on the gatherable with the most others on its screen (but its screen inside the map).
	var c0: Vector2i = cells[0]
	var best: int = -1
	var half: Vector2i = Config.VIEW_SIZE / 2 / Config.TILE
	for c: Vector2i in cells:
		if c.x < half.x or c.y < half.y or c.x >= data.size.x - half.x or c.y >= data.size.y - half.y:
			continue
		var around: int = 0
		for o: Vector2i in cells:
			if absi(o.x - c.x) < half.x and absi(o.y - c.y) < half.y:
				around += 1
		if around > best:
			best = around
			c0 = c
	var drop_cell: Vector2i = c0 + Vector2i(2, 1)
	var drop: WorldData.Drop = WorldData.Drop.new(data.new_drop_id(), &"pickaxe", 1, ItemDB.Grade.NONE,
		drop_cell * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2))
	world.apply_edit(EditLog.WorldEdit.drop_put(drop))
	var origin: Vector2i = _look_at(c0 * Config.TILE + Vector2i(8, 8))
	var sprites: Array[Sprite2D] = []
	sprites.append_array(world.items.plants.values())
	sprites.append_array(world.items.drops.values())
	for sp: Sprite2D in sprites:
		sp.visible = false
	var bg: Image = await _capture()
	for sp: Sprite2D in sprites:
		sp.visible = true
	var got: Image = await _capture()
	var expected: Image = bg.duplicate() as Image
	var screen: Rect2i = Rect2i(origin, Config.VIEW_SIZE)
	var shown: int = 0
	for c: Vector2i in cells:
		var top_left: Vector2i = c * Config.TILE
		if screen.intersects(Rect2i(top_left, Vector2i(Config.TILE, Config.TILE))):
			_blend(expected, ItemView.world_picture(WorldItems.gatherable_at(data, c)), top_left - origin)
			shown += 1
	_blend(expected, ItemIcons.texture_for(drop.item), drop.pos - Vector2i(8, 8) - origin)
	var n: int = count_diff(got, expected)
	world.apply_edit(EditLog.WorldEdit.drop_remove(drop.id))
	var line: String = "gatherables_on_screen=%d drops=1 pixels=%d mismatches=%d" % [shown, Config.VIEW_SIZE.x *
		Config.VIEW_SIZE.y, n]
	if n > 0 or save_all:
		_save(got, "items_got.png")
		_save(expected, "items_expected.png")
	if n == 0 and shown > 0:
		print("EVENSONG_RENDER items ok %s" % line)
	else:
		_fail("items", line)


static func _blend(dst: Image, tex: Texture2D, at: Vector2i) -> void:
	var img: Image = tex.get_image()
	img.convert(Image.FORMAT_RGBA8)
	dst.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)


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


# --- M3a: the dungeon --------------------------------------------------------------------------

func _check_cave_and_dark() -> void:
	var dun: GameWorld = (load(WORLD_SCENE) as PackedScene).instantiate() as GameWorld
	dun.auto_generate = false
	dun.map_id = Config.MAP_DUNGEON
	root.add_child(dun)
	dun.generate(Config.DEFAULT_SEED)
	dun.overlay.visible = false
	dun.camera.set_process(false)
	world.visible = false
	dun.visible = true
	dun.camera.make_current()
	await _check_cave(dun)
	await _check_dark(dun)
	root.remove_child(dun)
	dun.free()
	await _check_cave_net()
	world.visible = true
	world.camera.make_current()


func _cave_look_at(dun: GameWorld, center: Vector2i) -> Vector2i:
	dun.camera.position = Vector2(center)
	dun.camera.reset_smoothing()
	return center - Config.VIEW_SIZE / 2


## Walls around the seed-1 arrival room mined to show every crack stage on faced and side walls and
## a broken tile (direct edits, the kind mining makes). Returns the tiles touched.
static func mine_for_show(dun: GameWorld) -> Array[Vector2i]:
	var d: WorldData = dun.data
	var exit: Rect2i = DungeonGen.exit_rect(d)
	var room_top: int = exit.position.y
	var done: Array[Vector2i] = []
	var faced: Array[Vector2i] = []
	var side: Array[Vector2i] = []
	for x: int in range(exit.position.x - 8, exit.end.x + 8):
		var c: Vector2i = Vector2i(x, room_top - 1)
		if Walls.kind_at(d, c) == Walls.KIND_ROCK and Walls.is_face(d, c + Vector2i(0, 1)) \
				and d.get_value(WorldData.Layer.PLACEABLE, c) == 0 and Walls.max_hits(d, c) > 0:
			faced.append(c)
	for y: int in range(room_top + 1, room_top + 6):
		for x: int in range(exit.position.x - 8, exit.end.x + 8):
			var c: Vector2i = Vector2i(x, y)
			if Walls.kind_at(d, c) == Walls.KIND_ROCK and not Walls.is_face(d, c + Vector2i(0, 1)) \
					and not Movement.is_blocked(d, c + Vector2i(1, 0)) and Walls.max_hits(d, c) > 0:
				side.append(c)
				break
	var stage_hits: Array[int] = [1, Config.WALL_HITS_ROCK / 2, Config.WALL_HITS_ROCK - 1]
	for i: int in mini(3, faced.size()):
		dun.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, faced[i], Walls.pack(Walls.KIND_ROCK, stage_hits[i])))
		done.append(faced[i])
	for i: int in mini(3, side.size()):
		dun.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, side[i], Walls.pack(Walls.KIND_ROCK, stage_hits[i])))
		done.append(side[i])
	if faced.size() > 3:
		var gone: Vector2i = faced[faced.size() - 1]
		dun.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, gone, 0))
		done.append(gone)
	return done


func _check_cave(dun: GameWorld) -> void:
	dun.lighting.set_evening(false)
	dun.entities.visible = false
	var mined: Array[Vector2i] = mine_for_show(dun)
	var exit: Rect2i = DungeonGen.exit_rect(dun.data)
	var origin: Vector2i = _cave_look_at(dun, exit.position * Config.TILE + Vector2i(16, 60))
	var got: Image = await _capture()
	var composite: Array = cave_composite(dun, origin)
	var expected: Image = composite[0]
	var overlays: int = composite[1]
	var stages: Dictionary[int, bool] = {}
	var faced_cracks: int = 0
	for c: Vector2i in mined:
		var stage: int = Walls.crack_stage(Walls.hits_at(dun.data, c), Walls.max_hits(dun.data, c))
		if stage > 0:
			stages[stage] = true
			if Walls.is_face(dun.data, c + Vector2i(0, 1)):
				faced_cracks += 1
	var n: int = count_diff(got, expected)
	var line: String = "cliff tiles + %d overlays on screen, crack stages %s (%d on faced walls), mined tiles %d, mismatches=%d" % [
		overlays, stages.keys(), faced_cracks, mined.size(), n]
	if n > 0 or save_all:
		_save(got, "cave_got.png")
		_save(expected, "cave_expected.png")
	if n == 0 and stages.size() == 3 and faced_cracks > 0 and overlays > 3:
		print("EVENSONG_RENDER cave ok %s" % line)
	else:
		_fail("cave", line)
	dun.entities.visible = true


## What the screen with world pixel `origin` at (0, 0) must show of dungeon world `dun` (darkness off,
## entities hidden): each display cell's cliff tile (CaveView.drawn_at) and the ore and crack overlays
## from the data, with the positions written out here. [image, overlays drawn].
static func cave_composite(dun: GameWorld, origin: Vector2i) -> Array:
	var expected: Image = Image.create_empty(Config.VIEW_SIZE.x, Config.VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	expected.fill(Color(0, 0, 0, 1))
	var view: CaveView = dun.cave
	var atlases: Dictionary[int, Image] = {}
	var r: Rect2i = view.display_rect()
	for dy: int in range(r.position.y, r.end.y):
		for dx: int in range(r.position.x, r.end.x):
			var at: Vector2i = Vector2i(dx, dy) * Config.TILE + Vector2i(8, 8) - origin
			if at.x <= -Config.TILE or at.y <= -Config.TILE or at.x >= Config.VIEW_SIZE.x or at.y >= Config.VIEW_SIZE.y:
				continue
			var t: Vector3i = view.drawn_at(Vector2i(dx, dy))
			if t.x < 0:
				continue
			if not atlases.has(t.x):
				var src: TileSetAtlasSource = view.table.tile_set.get_source(t.x) as TileSetAtlasSource
				atlases[t.x] = LightGen.to_rgba8(src.texture.get_image())
			expected.blend_rect(atlases[t.x], Rect2i(t.y * Config.TILE, t.z * Config.TILE, Config.TILE, Config.TILE), at)
	# Overlays from the data with the art files and the positions written out here (not the sprites'):
	# ore pixels on the wall tile (rows above the face only on a faced wall), then per cracked wall the
	# top crack (on the tile; on a faced wall just above where the face starts, 8 + FACE_TOP_PX - 16)
	# and, when faced, the face crack (16x24 from 8 + FACE_TOP_PX below the tile's top).
	var overlays: int = 0
	var top_art: Image = LightGen.to_rgba8(CaveView.CRACK_TOP.get_image())
	var face_art: Image = LightGen.to_rgba8(CaveView.CRACK_FACE.get_image())
	var screen: Rect2i = Rect2i(origin - Vector2i(32, 32), Config.VIEW_SIZE + Vector2i(64, 64))
	for c: Vector2i in Walls.wall_cells(dun.data):
		if not screen.has_point(c * Config.TILE):
			continue
		var faced: bool = Walls.is_face(dun.data, c + Vector2i(0, 1))
		var tile_px: Vector2i = c * Config.TILE - origin
		var ore: int = Walls.ore_at(dun.data, c)
		if ore != Walls.ORE_NONE:
			var ore_img: Image = LightGen.to_rgba8(CaveView.ore_texture(ore, c).get_image())
			var rows: int = Config.TILE / 2 + Config.FACE_TOP_PX if faced else Config.TILE
			expected.blend_rect(ore_img, Rect2i(0, 0, Config.TILE, rows), tile_px)
			overlays += 1
		var stage: int = Walls.crack_stage(Walls.hits_at(dun.data, c), Walls.max_hits(dun.data, c))
		if stage == 0:
			continue
		var top_y: int = Config.TILE / 2 + Config.FACE_TOP_PX - Config.TILE if faced else 0
		expected.blend_rect(top_art, Rect2i((stage - 1) * Config.TILE, 0, Config.TILE, Config.TILE), tile_px + Vector2i(0, top_y))
		overlays += 1
		if faced:
			expected.blend_rect(face_art, Rect2i((stage - 1) * Config.TILE, 0, Config.TILE, Config.FACE_HEIGHT_PX),
				tile_px + Vector2i(0, Config.TILE / 2 + Config.FACE_TOP_PX))
			overlays += 1
	return [expected, overlays]


## M3b: the host's dungeon mined with the real rules, edit by edit; a client's built from a map snapshot
## half way plus the rest as live edits; both drawn the same, and as the composite says.
func _check_cave_net() -> void:
	var host_w: GameWorld = _dungeon_world()
	var client_w: GameWorld = _dungeon_world(false)
	var d: WorldData = host_w.data
	# (swinger class, feet tile, target tile, swings) on the seed-1 arrival room (README M3b).
	var plan: Array[Array] = [
		[Mining.MINER_CLASS, Vector2i(34, 15), Vector2i(33, 15), 1],   # 3x3 west: 6 rock tiles at stage 1
		["cleric", Vector2i(34, 15), Vector2i(34, 14), 3],             # the face north-west: its rock at stage 2
		["cleric", Vector2i(36, 15), Vector2i(36, 14), 5],             # the face north: its rock at stage 3
		[Mining.MINER_CLASS, Vector2i(41, 15), Vector2i(42, 15), 3],   # 3x3 east: broken
	]
	var edits: Array[EditLog.WorldEdit] = []
	var inv: Inventory = Inventory.new()
	for step_index: int in plan.size():
		var step: Array = plan[step_index]
		var class_id: String = step[0]
		var feet_cell: Vector2i = step[1]
		var target: Vector2i = step[2]
		var swings: int = step[3]
		var feet: Vector2 = Vector2(feet_cell.x * Config.TILE + Config.TILE / 2.0, feet_cell.y * Config.TILE + Config.TILE - 2)
		for i: int in swings:
			var res: Mining.Result = Mining.strike(d, feet, class_id, inv, target)
			for e: EditLog.WorldEdit in res.edits:
				host_w.apply_edit(e)  # as SessionHost.apply_world_edit
				edits.append(e)
		if step_index == 1:
			# Half way the client enters the map: a map snapshot of the host's dungeon as it is now.
			_load_snapshot(host_w, client_w)
			snapshot_edits = edits.size()
	if client_w.data == null:
		return
	# The rest reaches the client as live edits (GameWorld.apply_edit, as SessionClient.on_edit).
	for i: int in range(snapshot_edits, edits.size()):
		client_w.apply_edit(edits[i])
	var same_data: bool = client_w.data.content_hash() == host_w.data.content_hash()
	var stages: Dictionary[int, bool] = {}
	var broken: int = 0
	for c: Vector2i in Walls.wall_cells(DungeonGen.generate(Config.DEFAULT_SEED)):
		if not Walls.is_wall(d, c):
			broken += 1
		else:
			var stage: int = Walls.crack_stage(Walls.hits_at(d, c), Walls.max_hits(d, c))
			if stage > 0:
				stages[stage] = true
	var shots: Array[Image] = []
	var origin: Vector2i = Vector2i.ZERO
	for w: GameWorld in [host_w, client_w]:
		host_w.visible = w == host_w
		client_w.visible = w == client_w
		w.camera.make_current()
		origin = _cave_look_at(w, Vector2i(38 * Config.TILE, 15 * Config.TILE))
		shots.append(await _capture())
	var composite: Array = cave_composite(client_w, origin)
	var expected: Image = composite[0]
	var overlays: int = composite[1]
	var n_expected: int = count_diff(shots[1], expected)
	var n_host: int = count_diff(shots[0], shots[1])
	var line: String = "%d edits (%d after the client's snapshot of %d B), crack stages %s, %d broken, %d overlays, same data %s, client vs composite %d, host vs client %d" % [
		edits.size(), edits.size() - snapshot_edits, snapshot_bytes, stages.keys(), broken, overlays, same_data, n_expected, n_host]
	if n_expected > 0 or n_host > 0 or save_all:
		_save(shots[0], "cave_net_host.png")
		_save(shots[1], "cave_net_client.png")
		_save(expected, "cave_net_expected.png")
	if same_data and n_expected == 0 and n_host == 0 and stages.size() == 3 and broken >= 6 and snapshot_edits > 0 \
			and snapshot_edits < edits.size():
		print("EVENSONG_RENDER cave_net ok %s" % line)
	else:
		_fail("cave_net", line)
	for w: GameWorld in [host_w, client_w]:
		root.remove_child(w)
		w.free()


var snapshot_edits: int = 0
var snapshot_bytes: int = 0


## A dungeon world for the check (darkness off, entities hidden). `generate` false: empty (a client's).
func _dungeon_world(generate: bool = true) -> GameWorld:
	var w: GameWorld = (load(WORLD_SCENE) as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.map_id = Config.MAP_DUNGEON
	root.add_child(w)
	if generate:
		w.generate(Config.DEFAULT_SEED)
	w.overlay.visible = false
	w.camera.set_process(false)
	w.visible = false
	w.lighting.set_evening(false)
	w.entities.visible = false
	return w


## The client's world from a map snapshot of the host's world now (the join path, checked for the dungeon).
func _load_snapshot(host_w: GameWorld, client_w: GameWorld) -> void:
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(host_w.data)
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	var got: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, packed.world_md5,
		Config.MAP_DUNGEON)
	if got == null:
		_fail("cave_net", "map snapshot refused: %s" % rx.error)
		return
	client_w.load_data(got)
	snapshot_bytes = packed.bytes.size()


func _check_dark(dun: GameWorld) -> void:
	var feet: Vector2 = dun.arrival_point()
	var cell: Vector2i = Aim.feet_cell(feet) + Vector2i(0, 2)
	dun.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, cell, WorldData.PLACEABLE_TORCH))
	var light: PointLight2D = dun.fixtures.light_nodes[cell]
	for child: Node in dun.lighting.torches.get_children():
		var l: PointLight2D = child as PointLight2D
		if l != null and l != light:
			l.enabled = false
	var torch_node: Node2D = dun.fixtures.nodes[cell]
	for child: Node in dun.entities.get_children():
		var ci: CanvasItem = child as CanvasItem
		if ci != null:
			ci.visible = child == torch_node
	var center: Vector2i = Vector2i(light.position)
	var origin: Vector2i = _cave_look_at(dun, center)
	dun.lighting.set_evening(true)
	var dark: Image = await _capture()
	dun.lighting.set_evening(false)
	var bright: Image = await _capture()
	if save_all:
		_save(dark, "dark_on.png")
		_save(bright, "dark_off.png")
	var sprite_rect: Rect2i = Rect2i(FixtureView.torch_origin(cell) - origin, FixtureView.LANTERN.get_size())
	var r: float = float(Config.TORCH_LIGHT_RADIUS_PX)
	var far_lit: int = 0
	var near_dark: int = 0
	var far: int = 0
	var near: int = 0
	for y: int in Config.VIEW_SIZE.y:
		for x: int in Config.VIEW_SIZE.x:
			if sprite_rect.has_point(Vector2i(x, y)):
				continue
			var off: Color = bright.get_pixel(x, y)
			if _brightness(off) < MIN_BRIGHTNESS:
				continue
			var ratio: float = _brightness(dark.get_pixel(x, y)) / _brightness(off)
			var dist: float = (Vector2(origin + Vector2i(x, y)) + Vector2(0.5, 0.5)).distance_to(light.position)
			if dist > r + 2.0:
				far += 1
				if ratio > 0.3:
					far_lit += 1
			elif dist < TorchLight.STEP_ENDS[0] * r - 2.0:
				near += 1
				if ratio < 0.75:
					near_dark += 1
	for child: Node in dun.entities.get_children():
		var ci: CanvasItem = child as CanvasItem
		if ci != null:
			ci.visible = true
	var safe: bool = dun.is_in_safe_zone(light.position)
	var line: String = "far pixels %d (lit %d), inner-step pixels %d (dark %d), safe zone at the torch: %s" % [far, far_lit,
		near, near_dark, safe]
	if far > 1000 and near > 500 and far_lit == 0 and near_dark == 0 and not safe:
		print("EVENSONG_RENDER dark ok %s" % line)
	else:
		_fail("dark", line)
		_save(dark, "dark_on.png")
		_save(bright, "dark_off.png")
