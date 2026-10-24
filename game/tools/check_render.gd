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
##   heretic  (M4a) the heretic's five sheets, every frame, facing south / east / north / west, evening off:
##            the screen equals the background plus the CPU composite (the sheet cell for the row, the
##            feet on the node: a 32 cell's (16, 32), a 64 cell's (32, 48), west = east mirrored), pixel
##            for pixel; then a hurt heretic's HP bar (unshaded) on its exact pixels.
##   bars     (M4a) the HUD's HP and stamina bars and the respawn countdown digits for set vitals: their
##            exact pixels (frame, filled part, the rest). The rig part above covers the players' hurt
##            and death poses (shown like actions, the signature hidden on the death frames).
##   combat_net (M4b) what a session client draws of the host's combat: heretics in every state (a wind-up,
##            a hurt one with its HP bar and hit flash, a dying one, a walking one), an arrow and a bolt in the
##            air and a downed player with its bleed-out and revive bars, drawn by the host's CombatView from
##            its arena, then by a client's from what the wire carries (an enemy batch, shot events, the
##            player's state with its vitals block, decoded into a NetCombat and a Player, sampled at the
##            batch's tick): both screens must be the same pixels, and the heretics, shots and bars must be
##            there (the screen differs from the background).
##   crafting (M6a) the crafting panel open for a herbalist who may brew all six recipes, then for a paladin
##            (four rows dimmed): every opaque pixel it draws on its exact place (the frames, the station icon
##            and the underline, each row's input and output slot frames and icons, the arrows, the herbalist
##            marks, the selected row's gold frame); dimmed rows' icons darker than the icon colours.
##   potions  (M6a) evening off, on one screen: an alchemy table placed through the world's edits, a poisoned
##            heretic (its sheet frame and the poison mark), a thrown bottle half way (the potion icon on its
##            arc) and two splashes (frames 0 and 1): the screen equals the background plus their CPU
##            composites, pixel for pixel; (M6-fix) with the evening on, the bottle's and the splashes' pixels still
##            their own colours (unshaded) while the ground around them darkens; then a player's buff and poison
##            marks over its head and the HUD's effect icons and time-left bars on their exact pixels.
##   potions_net (M6b) what a session client draws of the host's potions: a real host arena (logging on) where a
##            herbalist threw two bottles (one broke a few ticks ago: its splash; one in the air) at a poisoned
##            heretic, and a player with a buff and a poison; drawn by the host's CombatView and Player, then by a
##            client from the wire (the enemy batch with the poison flag, the thrown / broke events, the player's
##            state with its effects block) sampled at the host's tick: the same pixels, with the bottle, the splash
##            and the marks there. Then the crafting panel a client opens at a table that came in a world snapshot,
##            for the inventory that came in an inventory message: the same pixels as the panel opened offline.
##   fields   (M5a) evening off, around the altar: lit grass tilled (floor edits) next to the M1 soil patches, the entities
##            hidden: the ground equals a CPU composite of the tile each display cell shows, read from the PNG files
##            (soil drawn as soil). Then crops of the three kinds at stages 0..4 and withered, some wet, and wet bare
##            soil: the screen equals that ground plus the wet quarters (each wet tile = the four quarters around its
##            vertex of the watered copies of the tiles those display cells show, read from the watered PNGs) and the
##            crops (their sheet cell on the tile, the mound recoloured to the dry / watered soil by a table written out
##            here), pixel for pixel. Then with the evening on: the wet and crop pixels well inside the light stay lit
##            (the wet patches on the ground's light layer, the crops on the actors').
##   purify   (M5b) evening off, at a corruption zone's edge, the entities hidden: a finished channel's tiles purified
##            through the world's edits; the ground equals the CPU composite of the tiles the display cells show, read from
##            the PNG files (the purified tiles drawn as grass, the zone's new edge from the grass <-> ash set). Then the
##            purification's first frame: that ground plus each purified tile's ash smear (the 04-env decal PNG, centred
##            in its tile, chosen by the rule written out here) and its gold outline (the tile's border pixels), pixel for
##            pixel; with the evening on the gold stays its colour (unshaded) and the smears darken (the ground's light).
##            Then a channel's motes at its last tick: 16 gold 2x2 motes (ivory top-left) on the ring at (radius + 0.5)
##            tiles, positions written out here, exactly those pixels changed, with the evening on.
##   altar    (M5b) the altar moved 13 tiles west through the world's edits: around its new place, every screen pixel lit
##            (evening on / off ratio) exactly where the new zone's ground light texel is lit (the old place, on screen,
##            dark); the flames there unshaded. Then a player carrying the altar: the mark over its head on its exact
##            pixels (the character map written out here) and unshaded; the place ghost's outline and light-edge dots in
##            gold (allowed) and deep red (refused) on their exact pixels. The altar goes back home afterwards.
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
		await _check_heretic()
		await _check_bars()
		await _check_combat_net()
		await _check_crafting()
		await _check_potions()
		await _check_potions_net()
		await _check_fields()
		await _check_items()
		await _check_ysort()
		await _check_cave_and_dark()
		await _check_purify()
		await _check_altar_move()
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
				if RigData.is_action(anim) or RigData.is_pose(anim):
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


## M4a: CPU composite of heretic animation `a` frame `f` facing `dir` (feet at COMPOSE_FEET). Written
## out from the 13차 hand-off, not from Heretic's own functions: rows south 0, east 1, north 2 (west =
## east, mirrored), the feet at a 32 cell's (16, 32) and a 64 cell's (32, 48).
const HERETIC_ROWS: Array[int] = [0, 1, 2, 1]

static func compose_heretic(dir: int, a: int, f: int) -> Image:
	var canvas: Image = Image.create_empty(COMPOSE_SIZE.x, COMPOSE_SIZE.y, false, Image.FORMAT_RGBA8)
	var sheet: Image = LightGen.to_rgba8(Heretic.SHEETS[a].get_image())
	var c: int = HereticSim.CELLS[a]
	var r: Rect2i = Rect2i((HereticSim.FIRST_COLUMN[a] + f) * c, HERETIC_ROWS[dir] * c, c, c)
	var feet_in_cell: Vector2i = Vector2i(16, 32) if c == 32 else Vector2i(32, 48)
	canvas.blit_rect_mask(sheet, sheet, r, COMPOSE_FEET - feet_in_cell)
	if RigData.is_mirrored(dir):
		canvas.flip_x()
	return canvas


## M4a: every heretic frame in 4 directions against the CPU composite, then the HP bar.
func _check_heretic() -> void:
	world.lighting.set_evening(false)
	var origin: Vector2i = _look_at(Vector2i(400, 400))
	var bg: Image = await _capture()
	var nodes: Array[Heretic] = []
	var feet_list: Array[Vector2i] = []
	var sims: Array[HereticSim] = []
	for dir: int in 4:
		for col: int in 8:
			var h: HereticSim = HereticSim.new()
			h.facing = dir
			var feet: Vector2i = Vector2i(28 + col * 56, 50 + dir * 64)
			h.pos = Vector2(origin + feet)
			var n: Heretic = Heretic.new()
			world.entities.add_child(n)
			nodes.append(n)
			sims.append(h)
			feet_list.append(feet)
	var screens: int = 0
	var total: int = 0
	for a: int in HereticSim.ANIM_NAMES.size():
		var expected: Image = bg.duplicate() as Image
		for i: int in nodes.size():
			var h: HereticSim = sims[i]
			var col: int = i % 8
			var f: int = col % HereticSim.FRAME_COUNTS[a]
			_pose_heretic(h, a, f)
			nodes[i].show_sim(h)
			paste(expected, compose_heretic(h.facing, a, nodes[i].frame), feet_list[i])
		var got: Image = await _capture()
		var n: int = count_diff(got, expected)
		screens += 1
		total += n
		if n > 0 or save_all:
			_save(got, "heretic_%s_got.png" % HereticSim.ANIM_NAMES[a])
			_save(expected, "heretic_%s_expected.png" % HereticSim.ANIM_NAMES[a])
	# The HP bar of a hurt heretic (one node, the rest hidden).
	for i: int in nodes.size():
		nodes[i].visible = i == 0
	var hurt: HereticSim = sims[0]
	_pose_heretic(hurt, HereticSim.Anim.IDLE, 0)
	hurt.hp = Config.HERETIC_HP / 2
	nodes[0].show_sim(hurt)
	var bar_expected: Image = bg.duplicate() as Image
	paste(bar_expected, compose_heretic(hurt.facing, HereticSim.Anim.IDLE, nodes[0].frame), feet_list[0])
	var left: Vector2i = feet_list[0] + Vector2i(-Heretic.BAR_SIZE.x / 2 - 1, Heretic.BAR_Y - 1)
	bar_expected.fill_rect(Rect2i(left, Heretic.BAR_SIZE + Vector2i(2, 2)), Heretic.BAR_BACK)
	bar_expected.fill_rect(Rect2i(left + Vector2i.ONE, Vector2i(Heretic.bar_fill(0.5), Heretic.BAR_SIZE.y)), Heretic.BAR_FILL)
	var bar_got: Image = await _capture()
	var bar_n: int = count_diff(bar_got, bar_expected)
	if bar_n > 0 or save_all:
		_save(bar_got, "heretic_bar_got.png")
		_save(bar_expected, "heretic_bar_expected.png")
	for n2: Heretic in nodes:
		world.entities.remove_child(n2)
		n2.free()
	var line: String = "heretics=%d screens=%d mismatches=%d bar_mismatches=%d" % [nodes.size(), screens, total, bar_n]
	if total == 0 and bar_n == 0:
		print("EVENSONG_RENDER heretic ok %s" % line)
	else:
		_fail("heretic", line)


## Sets `h` to show animation `a` at frame `f` (HereticSim.frame() picks the frame from its state).
static func _pose_heretic(h: HereticSim, a: int, f: int) -> void:
	h.hp = Config.HERETIC_HP
	h.walking = a == HereticSim.Anim.WALK
	h.clock = f * (HereticSim.WALK_FRAME_TICKS if a == HereticSim.Anim.WALK else HereticSim.IDLE_FRAME_TICKS)
	h.state_ticks = 0
	match a:
		HereticSim.Anim.ATTACK:
			h.state = HereticSim.State.ATTACK
			var pre: int = HereticSim.hit_frame(h.row())
			h.state_ticks = f * Config.HERETIC_ATTACK_FRAME_TICKS if f < pre else Config.HERETIC_TELEGRAPH_TICKS + (f - pre) * Config.HERETIC_ATTACK_FRAME_TICKS
		HereticSim.Anim.HURT:
			h.state = HereticSim.State.HURT
			h.state_ticks = f * Config.HERETIC_HURT_FRAME_TICKS
		HereticSim.Anim.DEATH:
			h.state = HereticSim.State.DEAD
			h.state_ticks = f * Config.HERETIC_DEATH_FRAME_TICKS
		_:
			h.state = HereticSim.State.CHASE if a == HereticSim.Anim.WALK else HereticSim.State.IDLE


## M4a: the HUD bars for set vitals: HP 60 / 100 and stamina 20 (below the dash cost), then dead with
## the countdown; their pixels exactly.
func _check_bars() -> void:
	world.lighting.set_evening(false)
	_look_at(Vector2i(400, 400))
	var hud: Hud = Hud.new()
	root.add_child(hud)
	var p: Player = Player.new()
	p.vitals.hp = 60
	p.vitals.stamina = 20
	hud.bind_player(p)
	var got: Image = await _capture()
	var want: Dictionary[Vector2i, Color] = {}
	var hp_rect: Rect2i = Rect2i(Hud.BAR_AT, Hud.HP_BAR)
	var hp_fill: int = ceili(0.6 * Hud.HP_BAR.x)
	for y: int in range(hp_rect.position.y - 1, hp_rect.end.y + 1):
		for x: int in range(hp_rect.position.x - 1, hp_rect.end.x + 1):
			var inside: bool = hp_rect.has_point(Vector2i(x, y))
			want[Vector2i(x, y)] = Hud.FRAME_DARK if not inside else (Hud.HP_FILL if x < hp_rect.position.x + hp_fill else Hud.HP_LOST)
	var st_at: Vector2i = Hud.BAR_AT + Vector2i(0, Hud.HP_BAR.y + 3)
	var st_fill: int = ceili(0.2 * Hud.STAMINA_BAR.x)
	for x: int in range(st_at.x, st_at.x + Hud.STAMINA_BAR.x):
		for y: int in range(st_at.y, st_at.y + Hud.STAMINA_BAR.y):
			if x < st_at.x + st_fill:
				want[Vector2i(x, y)] = Hud.STAMINA_LOW
	var bad: int = 0
	for at: Vector2i in want:
		var c: Color = got.get_pixelv(at)
		if c.to_rgba32() != want[at].to_rgba32():
			bad += 1
	# Dead: the countdown's digits (3x) at the centre, ivory, with their shadow.
	p.vitals.life = Vitals.Life.DEAD
	p.vitals.life_ticks = 61
	hud.canvas.queue_redraw()
	var dead: Image = await _capture()
	var secs: int = Hud.respawn_seconds(p.vitals)
	var digit_px: int = 0
	var w: int = (str(secs).length() * 4 - 1) * Hud.COUNT_SCALE
	var top: Vector2i = Vector2i((Config.VIEW_SIZE.x - w) / 2, Hud.COUNT_TOP)
	var rows: Array = Hud.DIGITS[str(secs)[0].to_int()]
	for dy: int in 5:
		for dx: int in 3:
			if str(rows[dy])[dx] == "1":
				for sy: int in Hud.COUNT_SCALE:
					for sx: int in Hud.COUNT_SCALE:
						digit_px += 1
						if dead.get_pixel(top.x + dx * Hud.COUNT_SCALE + sx, top.y + dy * Hud.COUNT_SCALE + sy).to_rgba32() != Hud.DIGIT.to_rgba32():
							bad += 1
	root.remove_child(hud)
	hud.free()
	p.free()
	var line: String = "bar_pixels=%d digit_pixels=%d (%d s) mismatches=%d" % [want.size(), digit_px, secs, bad]
	if bad == 0:
		print("EVENSONG_RENDER bars ok %s" % line)
	else:
		_fail("bars", line)
		_save(got, "bars_got.png")
		_save(dead, "bars_dead_got.png")


## M6a: the crafting panel's opaque pixels (see the header).
func _check_crafting() -> void:
	world.lighting.set_evening(false)
	_look_at(Vector2i(400, 400))
	var hud: Hud = Hud.new()
	root.add_child(hud)
	var inv: Inventory = Inventory.new()
	for herb: StringName in [&"wild_healing", &"wild_buff", &"wild_poison"]:
		inv.add(herb, 4, ItemDB.Grade.COMMON)
		inv.add(herb, 2, ItemDB.Grade.FINE)
	var at: Crafting.StationAt = Crafting.StationAt.new()
	at.kind = Crafting.ALCHEMY
	at.rect = Rect2i(10, 10, 3, 1)
	hud.crafting.open_for(at, inv, "herbalist")
	hud.crafting.selected = 2
	hud.crafting.queue_redraw()
	var got: Image = await _capture()
	var panel: CraftingPanel = hud.crafting
	var want: Dictionary[Vector2i, Color] = _panel_pixels(panel, true)
	var bad: int = _count_wrong(got, want)
	# A paladin: the FINE and poison rows are dimmed (darker than their icons), the others exact.
	panel.open_for(at, inv, "paladin")
	panel.selected = 1  # a dimmed row (its gold frame is not compared; row 0's would cover the header line)
	panel.queue_redraw()
	var dim_got: Image = await _capture()
	var want_free: Dictionary[Vector2i, Color] = {}
	var darker: int = 0
	var dim_px: int = 0
	var full: Dictionary[Vector2i, Color] = _panel_pixels(panel, false)
	for i: int in panel.recipes.size():
		var rect: Rect2i = panel.row_rect(i)
		var dimmed: bool = not Crafting.refusal(panel.recipes[i], "paladin", inv).is_empty()
		for p: Vector2i in full:
			if not rect.grow(1).has_point(p):
				continue
			if dimmed and _brightness(full[p]) > 0.6:  # the icons, arrows, digits (the dark frames barely change)
				dim_px += 1
				if _brightness(dim_got.get_pixelv(p)) < _brightness(full[p]) - 0.05:
					darker += 1
			elif not dimmed:
				want_free[p] = full[p]
	bad += _count_wrong(dim_got, want_free)
	if bad > 0 or save_all:
		_save(got, "crafting_got.png")
		_save(dim_got, "crafting_dim_got.png")
	var rows: int = panel.recipes.size()
	root.remove_child(hud)
	hud.free()
	var line: String = "rows=%d pixels=%d free_pixels=%d dimmed=%d/%d mismatches=%d" % [rows, want.size(),
		want_free.size(), darker, dim_px, bad]
	if bad == 0 and darker == dim_px and dim_px > 100 and rows == 6:
		print("EVENSONG_RENDER crafting ok %s" % line)
	else:
		_fail("crafting", line)


## The opaque pixels the crafting panel draws (viewport px -> colour): frames, the station icon, the
## underline, each row's slots, icons (not under a count or the FINE dot), arrow and mark, and (with
## `selected`) the selected row's gold frame.
static func _panel_pixels(panel: CraftingPanel, selected: bool) -> Dictionary[Vector2i, Color]:
	var want: Dictionary[Vector2i, Color] = {}
	var p: Rect2i = panel.panel_rect()
	_frame_pixels(want, p, Hud.FRAME_DARK)
	_frame_pixels(want, p.grow(-1), Hud.FRAME)
	_icon_pixels(want, &"alchemy_table", panel.header_icon_at(), Rect2i())
	for x: int in range(p.position.x + CraftingPanel.PAD, p.end.x - CraftingPanel.PAD):
		want[Vector2i(x, p.position.y + CraftingPanel.PAD + CraftingPanel.HEADER - 1)] = Hud.SELECT_INNER
	for i: int in panel.recipes.size():
		var r: Crafting.Recipe = panel.recipes[i]
		for slot: Array in [[panel.input_slot(i), r.inputs[0].item, r.inputs[0].count, r.inputs[0].grade],
				[panel.output_slot(i), r.output, r.out_count, r.out_grade]]:
			var o: Vector2i = slot[0]
			var item: StringName = slot[1]
			var n: int = slot[2]
			var g: int = slot[3]
			var sq: Rect2i = Rect2i(o, Vector2i(Hud.SLOT, Hud.SLOT))
			_frame_pixels(want, sq, Hud.FRAME_DARK)
			_frame_pixels(want, sq.grow(-1), Hud.FRAME)
			var skip: Rect2i = Rect2i(o + Vector2i(Hud.SLOT - 3 - 4 * str(n).length(), Hud.SLOT - 8), Vector2i(4 * str(n).length() + 2, 7)) \
				if n > 1 else Rect2i()
			_icon_pixels(want, item, o + Vector2i(1, 1), skip, Rect2i(o + Vector2i(2, 2), Vector2i(2, 2)) if g == ItemDB.Grade.FINE else Rect2i())
			for sy: int in range(skip.position.y, skip.end.y):
				for sx: int in range(skip.position.x, skip.end.x):
					want.erase(Vector2i(sx, sy))  # the count and its shadow cover the frame there too
			if g == ItemDB.Grade.FINE:
				for d: Vector2i in [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]:
					want[o + d] = Hud.FINE_MARK
		_rows_pixels(want, CraftingPanel.ARROW, panel.row_rect(i).position + Vector2i(Hud.SLOT + CraftingPanel.ARROW_GAP,
			(CraftingPanel.ROW - 5) / 2), Hud.DIGIT)
		if not r.classes.is_empty():
			_rows_pixels(want, CraftingPanel.MARK, panel.output_slot(i) + Vector2i(Hud.SLOT + 2, (CraftingPanel.ROW - 5) / 2),
				CraftingPanel.MARK_OK if r.allows(panel.class_id) else CraftingPanel.MARK_NO)
		if selected and i == panel.selected:
			_frame_pixels(want, panel.row_rect(i).grow(1), Hud.SELECT)
	return want


static func _frame_pixels(want: Dictionary[Vector2i, Color], r: Rect2i, c: Color) -> void:
	for x: int in range(r.position.x, r.end.x):
		want[Vector2i(x, r.position.y)] = c
		want[Vector2i(x, r.end.y - 1)] = c
	for y: int in range(r.position.y + 1, r.end.y - 1):
		want[Vector2i(r.position.x, y)] = c
		want[Vector2i(r.end.x - 1, y)] = c


static func _icon_pixels(want: Dictionary[Vector2i, Color], item: StringName, at: Vector2i, skip: Rect2i, skip2: Rect2i = Rect2i()) -> void:
	var img: Image = LightGen.to_rgba8(ItemIcons.texture_for(item).get_image())
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Vector2i = at + Vector2i(x, y)
			if img.get_pixel(x, y).a8 == 255 and not skip.has_point(p) and not skip2.has_point(p):
				want[p] = img.get_pixel(x, y)


static func _rows_pixels(want: Dictionary[Vector2i, Color], rows: Array, at: Vector2i, c: Color) -> void:
	for y: int in rows.size():
		var row: String = rows[y]
		for x: int in row.length():
			if row[x] == "1":
				want[at + Vector2i(x, y)] = c


static func _count_wrong(img: Image, want: Dictionary[Vector2i, Color]) -> int:
	var bad: int = 0
	for p: Vector2i in want:
		if img.get_pixelv(p).to_rgba32() != want[p].to_rgba32():
			bad += 1
	return bad


## M6a: the alchemy table, a poisoned heretic, a bottle in flight and two splashes against their CPU
## composites; a player's effect marks and the HUD's effect icons (see the header).
func _check_potions() -> void:
	world.lighting.set_evening(false)
	var origin: Vector2i = _look_at(Vector2i(400, 400))
	var bg: Image = await _capture()
	var table_at: Vector2i = Vector2i(origin.x / Config.TILE + 3, origin.y / Config.TILE + 4)
	var edits: Array[EditLog.WorldEdit] = []
	for x: int in range(table_at.x - 1, table_at.x + 2):
		edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x, table_at.y), WorldData.PLACEABLE_ALCHEMY))
	for e: EditLog.WorldEdit in edits:
		world.apply_edit(e)
	var rect: Rect2i = Rect2i(table_at - Vector2i(1, 0), Config.ALCHEMY_FOOTPRINT)
	var a: Arena = Arena.mirror(world.data)
	var h: HereticSim = HereticSim.new()
	h.id = 1
	h.pos = Vector2(origin + Vector2i(170, 120))
	h.poison_ticks = 100
	a.heretics.append(h)
	var f: Arena.Flask = Arena.Flask.new()
	f.id = 2
	f.item = &"potion_poison"
	f.origin = Vector2(origin + Vector2i(260, 120))
	f.target = f.origin + Vector2(80, 0)
	f.pos = f.origin + Vector2(40, 0)
	a.flasks.append(f)
	var splashes: Array[Arena.Splash] = []
	for k: int in 2:
		var s: Arena.Splash = Arena.Splash.new()
		s.id = 3 + k
		s.item = [&"potion_healing", &"potion_buff"][k]
		s.pos = Vector2(origin + Vector2i(120 + k * 90, 210))
		s.age = k * Config.SPLASH_SHOW_TICKS / CombatView.SPLASH_FRAMES
		a.splashes.append(s)
		splashes.append(s)
	var view: CombatView = CombatView.new()
	world.add_child(view)
	view.setup(a, world.entities)
	view.sync()
	var got: Image = await _capture()
	var expected: Image = bg.duplicate() as Image
	var table_img: Image = LightGen.to_rgba8(FixtureView.TABLE.get_image())
	# Written out here (not FixtureView.table_origin): the art centred on the 3 tiles, its last opaque row
	# (measured from the image) on the footprint's last pixel row.
	var bottom: int = 0
	for y: int in table_img.get_height():
		for x: int in table_img.get_width():
			if table_img.get_pixel(x, y).a8 > 0:
				bottom = y
	var table_top_left: Vector2i = Vector2i(rect.position.x * Config.TILE + (rect.size.x * Config.TILE - table_img.get_width()) / 2,
		rect.end.y * Config.TILE - 1 - bottom)
	_paste_at(expected, table_img, table_top_left - origin)
	var hfeet: Vector2i = Vector2i(h.pos.round()) - origin
	paste(expected, compose_heretic(h.facing, HereticSim.Anim.IDLE, 0), hfeet)
	_paste_at(expected, EffectMarks.image(EffectMarks.Kind.POISON), hfeet + EffectMarks.icon_offset(0, 1))
	var bottle: Image = LightGen.to_rgba8(ItemIcons.texture_for(&"potion_poison").get_image())
	_paste_at(expected, bottle, Vector2i(f.pos.round()) - origin + CombatView.flask_offset(f.progress()))
	for s2: Arena.Splash in splashes:
		_paste_at(expected, CombatView.splash_image(Potions.effect_of(s2.item), CombatView.splash_frame(s2.age)),
			Vector2i(s2.pos.round()) - origin - Vector2i(CombatView.SPLASH_HALF, CombatView.SPLASH_HALF))
	var n: int = count_diff(got, expected)
	var drawn: int = count_diff(got, bg)
	if n > 0 or save_all:
		_save(got, "potions_got.png")
		_save(expected, "potions_expected.png")
	# M6-fix: in the dark (the evening on, outside the light) the bottle and the splashes keep their own colours
	# (unshaded like the bolt and the marks; the bottle was shaded and all but vanished in the dark dungeon).
	world.lighting.set_evening(true)
	var dark: Image = await _capture()
	world.lighting.set_evening(false)
	var lit_want: Dictionary[Vector2i, Color] = {}
	_image_pixels(lit_want, bottle, Vector2i(f.pos.round()) - origin + CombatView.flask_offset(f.progress()))
	var bottle_pixels: int = lit_want.size()
	for s3: Arena.Splash in splashes:
		_image_pixels(lit_want, CombatView.splash_image(Potions.effect_of(s3.item), CombatView.splash_frame(s3.age)),
			Vector2i(s3.pos.round()) - origin - Vector2i(CombatView.SPLASH_HALF, CombatView.SPLASH_HALF))
	var dark_bad: int = _count_wrong(dark, lit_want)
	var darker: int = 0  # the background around them did darken (the evening is on)
	for y: int in range(0, dark.get_height(), 8):
		for x: int in range(0, dark.get_width(), 8):
			if not lit_want.has(Vector2i(x, y)) and _brightness(dark.get_pixel(x, y)) < _brightness(bg.get_pixel(x, y)) * LIT_RATIO:
				darker += 1
	if dark_bad > 0 or save_all:
		_save(dark, "potions_dark_got.png")
	view.clear()
	world.remove_child(view)
	view.free()
	for e2: EditLog.WorldEdit in edits:
		world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, e2.cell, WorldData.PLACEABLE_NONE))
	# A player with both effects: its marks over the head; the HUD's icons and time-left bars.
	var p: Player = Player.new()
	world.entities.add_child(p)
	p.local_input = false  # no ticks: the effects stay as set
	p.setup(world.data, "cleric", Vector2(origin + Vector2i(240, 150)))
	p.apply_potion(&"potion_buff", ItemDB.Grade.FINE)
	p.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	p.vitals.buff_ticks = Config.BUFF_TICKS[ItemDB.Grade.FINE] / 2
	var hud: Hud = Hud.new()
	root.add_child(hud)
	hud.bind_player(p)
	var marks_got: Image = await _capture()
	var want: Dictionary[Vector2i, Color] = {}
	var pfeet: Vector2i = Vector2i(p.sim_position.round()) - origin
	for i: int in 2:
		var img: Image = EffectMarks.image(i)
		_image_pixels(want, img, pfeet + EffectMarks.icon_offset(i, 2))
		_image_pixels(want, img, Hud.effect_icon_at(i))
		var fill: int = Hud.effect_fill(p.vitals.buff_ticks, Config.BUFF_TICKS) if i == EffectMarks.Kind.BUFF \
			else Hud.effect_fill(p.vitals.poison_ticks, Config.POISON_TICKS)
		for x: int in EffectMarks.SIZE:
			want[Hud.effect_icon_at(i) + Vector2i(x, EffectMarks.SIZE + 1)] = Hud.EFFECT_LEFT if x < fill else Hud.FRAME_DARK
	var mark_bad: int = _count_wrong(marks_got, want)
	if mark_bad > 0 or save_all:
		_save(marks_got, "potions_marks_got.png")
	root.remove_child(hud)
	hud.free()
	world.entities.remove_child(p)
	p.free()
	var line: String = "screen_mismatches=%d drawn=%d mark_pixels=%d mark_mismatches=%d dark_pixels=%d (bottle %d) dark_mismatches=%d darkened=%d" % [
		n, drawn, want.size(), mark_bad, lit_want.size(), bottle_pixels, dark_bad, darker]
	if n == 0 and drawn > 1000 and mark_bad == 0 and want.size() > 100 and dark_bad == 0 and bottle_pixels > 50 			and darker > 500:
		print("EVENSONG_RENDER potions ok %s" % line)
	else:
		_fail("potions", line)


func _check_potions_net() -> void:
	world.lighting.set_evening(false)
	var origin: Vector2i = _look_at(Vector2i(400, 400))
	var bg: Image = await _capture()
	var tick: int = 2000
	var a: Arena = Arena.new()
	a.setup(world.data, Config.DEFAULT_SEED)
	a.spawning = false
	a.logging = true
	a.now = tick
	var h: HereticSim = a.spawn_heretic(Vector2(origin + Vector2i(300, 130)) + Vector2(0.25, 0.25))
	a.poison_heretic(h, Config.POISON_DAMAGE[ItemDB.Grade.FINE], Config.POISON_TICKS[ItemDB.Grade.FINE])
	var thrower: Player = Player.new()
	thrower.local_input = false
	thrower.setup(world.data, "herbalist", Vector2(origin + Vector2i(90, 200)) + Vector2(0.4, 0.3))
	var events: Array[NetProtocol.ShotEvent] = []
	var no_players: Array[Player] = []
	var first: Arena.Flask = a.throw_potion(thrower, &"potion_healing", ItemDB.Grade.FINE, thrower.sim_position + Vector2(60, -40), 1)
	var second: Arena.Flask = null
	for t: int in 40:
		a.now = tick + t
		if first.done and second == null and a.splashes.size() == 1 and a.splashes[0].age == 3:
			second = a.throw_potion(thrower, &"potion_poison", ItemDB.Grade.FINE, Combat.body_centre(h.pos), 1)
		a.step(no_players)
		events.append_array(a.shot_events)
		a.shot_events.clear()
		if second != null and not second.done and second.progress() > 0.4:
			break
	var now: int = a.now
	var p: Player = Player.new()
	p.local_input = false
	p.setup(world.data, "cleric", Vector2(origin + Vector2i(200, 90)))
	p.apply_potion(&"potion_buff", ItemDB.Grade.FINE)
	p.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	world.entities.add_child(p)
	var host_v: CombatView = CombatView.new()
	host_v.name = &"HostPotions"
	world.add_child(host_v)
	host_v.setup(a, world.entities)
	host_v.sync([p] as Array[Player])
	var host_img: Image = await _capture()
	var host_flasks: int = a.flasks.size()
	var host_splashes: int = a.splashes.size()
	host_v.clear()
	world.remove_child(host_v)
	host_v.free()
	world.entities.remove_child(p)
	# The client: the wire, decoded.
	var payload: PackedByteArray = NetProtocol.encode_enemies(now, Config.MAP_SURFACE, 0, a.enemy_states(now))
	var nc: NetCombat = NetCombat.new()
	nc.reset(Config.MAP_SURFACE, world.data)
	nc.local_slot = 2
	nc.on_batch(NetProtocol.decode_enemies(payload), payload, true)
	nc.on_shots(NetProtocol.decode_shots(NetProtocol.encode_shots(Config.MAP_SURFACE, events)))
	nc.sample(float(now), 0.0)
	for hh: HereticSim in nc.arena.heretics:
		hh.clock = h.clock  # the idle cycle is the client's own clock; the same frame here
	var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	st.pos = p.sim_position
	st.facing = p.facing
	st.vitals = p.vitals.copy()
	var wire: NetProtocol.StateBatch = NetProtocol.decode_states(NetProtocol.encode_states(now, [st] as Array[NetProtocol.PlayerState]))
	var client_p: Player = Player.new()
	client_p.local_input = false
	client_p.setup(world.data, "cleric", p.sim_position)
	client_p.show_state(wire.states[0].pos, wire.states[0].facing, false, false, -1, 0, wire.states[0].vitals)
	world.entities.add_child(client_p)
	var client_v: CombatView = CombatView.new()
	client_v.name = &"ClientPotions"
	world.add_child(client_v)
	client_v.setup(nc.arena, world.entities)
	client_v.sync([client_p] as Array[Player])
	var client_img: Image = await _capture()
	var marks: Array[int] = client_p.effect_marks.shown.duplicate()
	var foe_marked: bool = false
	for hn2: Heretic in client_v.heretics.values():
		foe_marked = hn2.marks.shown == ([EffectMarks.Kind.POISON] as Array[int])
	client_v.clear()
	world.remove_child(client_v)
	client_v.free()
	world.entities.remove_child(client_p)
	client_p.free()
	p.free()
	thrower.free()
	var n: int = count_diff(client_img, host_img)
	var drawn: int = count_diff(host_img, bg)
	var ok_scene: bool = n == 0 and drawn > 1000 and host_flasks == 1 and host_splashes == 1 and nc.arena.flasks.size() == 1 \
		and nc.arena.splashes.size() == 1 and foe_marked and marks == ([EffectMarks.Kind.BUFF, EffectMarks.Kind.POISON] as Array[int])
	if n > 0 or save_all:
		_save(host_img, "potions_net_host.png")
		_save(client_img, "potions_net_client.png")
	# The client's crafting panel: a table that came in a world snapshot, the inventory in an inventory message.
	var table_at: Vector2i = Vector2i(origin.x / Config.TILE + 5, origin.y / Config.TILE + 6)
	var edits: Array[EditLog.WorldEdit] = []
	for x: int in range(table_at.x - 1, table_at.x + 2):
		edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x, table_at.y), WorldData.PLACEABLE_ALCHEMY))
	for e: EditLog.WorldEdit in edits:
		world.apply_edit(e)
	var feet: Vector2 = Vector2((table_at.x + 0.5) * Config.TILE, (table_at.y + 2) * Config.TILE - 2)
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(world.data)
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	var got_data: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size,
		packed.world_md5, Config.MAP_SURFACE)
	for e2: EditLog.WorldEdit in edits:
		world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, e2.cell, WorldData.PLACEABLE_NONE))
	var inv: Inventory = Inventory.new()
	inv.add(&"wild_healing", 4, ItemDB.Grade.FINE)
	inv.add(&"wild_poison", 2, ItemDB.Grade.COMMON)
	inv.add(&"potion_buff", 3, ItemDB.Grade.COMMON)
	var hud: Hud = Hud.new()
	root.add_child(hud)
	var at_off: Crafting.StationAt = Crafting.StationAt.new()
	at_off.kind = Crafting.ALCHEMY
	at_off.rect = Rect2i(table_at - Vector2i(1, 0), Config.ALCHEMY_FOOTPRINT)
	hud.crafting.open_for(at_off, inv, "herbalist")
	var panel_off: Image = await _capture()
	var rows_off: int = hud.crafting.recipes.size()
	var inv_c: Inventory = Inventory.new()
	SessionClient.take_inventory(inv_c, NetProtocol.decode_inventory(NetProtocol.encode_inventory(inv, 7)), inv.selected)
	var at_c: Crafting.StationAt = Crafting.station_near(got_data, feet) if got_data != null else null
	var panel_ok: bool = at_c != null and at_c.rect == at_off.rect
	if panel_ok:
		hud.crafting.open_for(at_c, inv_c, "herbalist")
	var panel_c: Image = await _capture()
	var rows_c: int = hud.crafting.recipes.size()
	root.remove_child(hud)
	hud.free()
	var pn: int = count_diff(panel_c, panel_off)
	var panel_drawn: int = count_diff(panel_off, bg)
	if pn > 0 or save_all:
		_save(panel_off, "potions_net_panel_offline.png")
		_save(panel_c, "potions_net_panel_client.png")
	panel_ok = panel_ok and pn == 0 and rows_c == rows_off and rows_off == 4 and panel_drawn > 1000
	var line: String = "client_vs_host=%d pixels_drawn=%d flasks=%d splashes=%d marks=%s foe_marked=%s panel_rows=%d/%d panel_vs_offline=%d panel_drawn=%d" % [
		n, drawn, nc.arena.flasks.size(), nc.arena.splashes.size(), marks, foe_marked, rows_c, rows_off, pn, panel_drawn]
	if ok_scene and panel_ok:
		print("EVENSONG_RENDER potions_net ok %s" % line)
	else:
		_fail("potions_net", line)


## Pastes the opaque pixels of `img` with its top-left at screen point `at`.
static func _paste_at(dst: Image, img: Image, at: Vector2i) -> void:
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var q: Vector2i = at + Vector2i(x, y)
			if c.a8 == 0 or q.x < 0 or q.y < 0 or q.x >= dst.get_width() or q.y >= dst.get_height():
				continue
			dst.set_pixelv(q, c)


static func _image_pixels(want: Dictionary[Vector2i, Color], img: Image, at: Vector2i) -> void:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 == 255:
				want[at + Vector2i(x, y)] = img.get_pixel(x, y)


## M4b: the host's combat as the host draws it and as a client draws it from the wire (see the header).
func _check_combat_net() -> void:
	world.lighting.set_evening(false)
	var origin: Vector2i = _look_at(Vector2i(400, 400))
	var bg: Image = await _capture()
	var tick: int = 1000
	var host_a: Arena = Arena.mirror(world.data)
	var poses: Array[Array] = [  # [state, state ticks, hp, flash, walking, facing]
		[HereticSim.State.ATTACK, 12, Config.HERETIC_HP, 0, false, RigData.Dir.EAST],
		[HereticSim.State.HURT, 7, 22, 4, false, RigData.Dir.WEST],
		[HereticSim.State.DEAD, 9, 0, 2, false, RigData.Dir.SOUTH],
		[HereticSim.State.CHASE, 0, 30, 0, true, RigData.Dir.NORTH],
		[HereticSim.State.EDGE, 40, 14, 0, false, RigData.Dir.SOUTH],
	]
	for i: int in poses.size():
		var pose: Array = poses[i]
		var h: HereticSim = host_a.spawn_heretic(Vector2(origin + Vector2i(60 + i * 80, 120)) + Vector2(0.25, 0.25))
		h.state = pose[0]
		h.state_ticks = pose[1]
		h.hp = pose[2]
		h.flash_ticks = pose[3]
		h.walking = pose[4]
		h.facing = pose[5]
		h.clock = tick
	var shots: Array[Array] = [[&"bow", 20, Vector2(origin + Vector2i(120, 200)) + Vector2(0.3, 0.2)],
		[&"holy_light", 150, Vector2(origin + Vector2i(300, 210)) + Vector2(0.2, 0.3)]]
	var events: Array[NetProtocol.ShotEvent] = []
	for s: Array in shots:
		var item: StringName = s[0]
		var aim: int = s[1]
		var at: Vector2 = s[2]
		var a: Combat.Attack = Combat.attack_for(item)
		var shot: Arena.Shot = Arena.Shot.new()
		shot.id = host_a.next_id
		host_a.next_id += 1
		shot.kind = a.kind
		shot.dir = Combat.aim_vector(aim)
		shot.aim = aim
		shot.item = item
		shot.pos = at
		host_a.shots.append(shot)
		var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
		e.id = shot.id
		e.item = item
		e.aim = aim
		e.owner = 3
		e.tick = tick
		e.pos = at - shot.dir * (a.speed / Config.NET_TICK_RATE)  # let go this tick: one step flown
		events.append(e)
	var down_feet: Vector2 = Vector2(origin + Vector2i(380, 200))
	var host_p: Player = Player.new()
	host_p.local_input = false
	host_p.setup(world.data, "archer", down_feet, RigData.Dir.EAST)
	host_p.take_hit(Config.PLAYER_HP_MAX)
	host_p.vitals.life_ticks = 200
	host_p.vitals.revive_ticks = 120
	host_p.vitals.flash_ticks = 0
	host_p.teleport(down_feet)  # its own vitals, drawn as the host has them
	world.entities.add_child(host_p)
	var host_v: CombatView = CombatView.new()
	host_v.name = &"HostCombat"
	world.add_child(host_v)
	host_v.setup(host_a, world.entities)
	host_v.sync([host_p] as Array[Player])
	var host_img: Image = await _capture()
	host_v.clear()
	world.remove_child(host_v)
	host_v.free()
	world.entities.remove_child(host_p)
	# The client: the wire, decoded.
	var payload: PackedByteArray = NetProtocol.encode_enemies(tick, Config.MAP_SURFACE, 0, host_a.enemy_states(tick))
	var nc: NetCombat = NetCombat.new()
	nc.reset(Config.MAP_SURFACE, world.data)
	nc.local_slot = 1
	nc.on_batch(NetProtocol.decode_enemies(payload), payload, true)
	nc.on_shots(NetProtocol.decode_shots(NetProtocol.encode_shots(Config.MAP_SURFACE, events)))
	nc.sample(float(tick), 0.0)
	for h: HereticSim in nc.arena.heretics:
		h.clock = tick  # the walk cycle is the client's own clock; the same frame here
	var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	st.pos = down_feet
	st.facing = host_p.facing
	st.vitals = host_p.vitals.copy()
	var wire: NetProtocol.StateBatch = NetProtocol.decode_states(NetProtocol.encode_states(tick, [st] as Array[NetProtocol.PlayerState]))
	var client_p: Player = Player.new()
	client_p.local_input = false
	client_p.setup(world.data, "archer", down_feet, RigData.Dir.EAST)
	client_p.show_state(wire.states[0].pos, wire.states[0].facing, false, false, -1, 0, wire.states[0].vitals)
	world.entities.add_child(client_p)
	var client_v: CombatView = CombatView.new()
	client_v.name = &"ClientCombat"
	world.add_child(client_v)
	client_v.setup(nc.arena, world.entities)
	client_v.sync([client_p] as Array[Player])
	var client_img: Image = await _capture()
	client_v.clear()
	world.remove_child(client_v)
	client_v.free()
	world.entities.remove_child(client_p)
	client_p.free()
	host_p.free()
	var n: int = count_diff(client_img, host_img)
	var drawn: int = count_diff(host_img, bg)
	var line: String = "heretics=%d shots=%d downed=1 client_vs_host=%d pixels_drawn=%d" % [nc.arena.heretics.size(),
		nc.arena.shots.size(), n, drawn]
	if n > 0 or save_all:
		_save(host_img, "combat_net_host.png")
		_save(client_img, "combat_net_client.png")
	if n == 0 and drawn > 2000 and nc.arena.heretics.size() == poses.size() and nc.arena.shots.size() == shots.size():
		print("EVENSONG_RENDER combat_net ok %s" % line)
	else:
		_fail("combat_net", line)


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


## M5a: the ground's PNG per TilesetBuilder source id, and the watered copies of the soil ones (written out here).
const GROUND_FILES: Dictionary[int, String] = {
	0: "tiles_grass-soil_v03.png", 1: "tiles_grass-corruption_v05.png",
	10: "tiles_grass_var_1_v02.png", 11: "tiles_grass_var_2_v02.png", 12: "tiles_grass_var_3_v02.png",
	13: "tiles_grass_var_4_v02.png", 20: "tiles_soil_var_1_v01.png", 21: "tiles_soil_var_2_v01.png",
	30: "tiles_ash_var_1_v02.png", 31: "tiles_ash_var_2_v02.png", 32: "tiles_ash_var_3_v02.png",
}
const WET_FILES: Dictionary[int, String] = {
	0: "tiles_grass-soil_v03_watered.png", 20: "tiles_soil_var_1_v01_watered.png", 21: "tiles_soil_var_2_v01_watered.png",
}
## The crops sheet's mound browns -> the dry / watered soil's (04-env prompts.md: the mound takes the soil's colours),
## the seed mound's two lighter browns only in column 0, the harvest column (5) never.
const MOUND_TO_DRY: Dictionary[int, int] = {0x5b2e15: 0x56321b, 0x723f0e: 0x6a4528, 0x83501c: 0x7f5531}
const MOUND_TO_WET: Dictionary[int, int] = {0x5b2e15: 0x331f16, 0x723f0e: 0x4b3021, 0x83501c: 0x5c3c27}
const SEED_TO_DRY: Dictionary[int, int] = {0x8c5a2c: 0x6a4528, 0xb0814e: 0x7f5531}
const SEED_TO_WET: Dictionary[int, int] = {0x8c5a2c: 0x4b3021, 0xb0814e: 0x84603f}


static func _png(file: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path("res://art/" + file))
	img.convert(Image.FORMAT_RGBA8)
	return img


## The crop sheet cell (col, row) with its mound in the dry or the watered soil's colours.
static func _crop_cell(sheet: Image, col: int, row: int, is_wet: bool) -> Image:
	var cell: Image = sheet.get_region(Rect2i(col * 16, row * 16, 16, 16))
	var mound: Dictionary[int, int] = MOUND_TO_WET if is_wet else MOUND_TO_DRY
	var seed_mound: Dictionary[int, int] = SEED_TO_WET if is_wet else SEED_TO_DRY
	for y: int in 16:
		for x: int in 16:
			var c: Color = cell.get_pixel(x, y)
			var rgb: int = (c.r8 << 16) | (c.g8 << 8) | c.b8
			var to: int = mound.get(rgb, -1)
			if to < 0 and col == 0:
				to = seed_mound.get(rgb, -1)
			if c.a8 > 0 and to >= 0 and col != 5:
				cell.set_pixel(x, y, Color8((to >> 16) & 0xff, (to >> 8) & 0xff, to & 0xff, c.a8))
	return cell


## M5a: tilled and watered soil and the crops (see the header).
func _check_fields() -> void:
	world.lighting.set_evening(false)
	var data: WorldData = world.data
	var centre: Vector2 = data.altar_center_px()
	var origin: Vector2i = _look_at(Vector2i(centre) + Vector2i(0, 8))
	var screen: Rect2i = Rect2i(origin, Config.VIEW_SIZE)
	# Field tiles: wholly lit, on the screen, nothing on them, soil allowed; grass ones get tilled first.
	var cells: Array[Vector2i] = []
	var tilled: Array[Vector2i] = []
	for y: int in range(data.altar_rect.position.y - 8, data.altar_rect.end.y + 8):
		for x: int in range(data.altar_rect.position.x - 8, data.altar_rect.end.x + 8):
			var c: Vector2i = Vector2i(x, y)
			if not screen.encloses(Rect2i(c * 16, Vector2i(16, 16))) or not Farming.in_light(data, c) \
					or data.get_value(WorldData.Layer.PLACEABLE, c) != 0 or data.get_value(WorldData.Layer.VEGETATION, c) != 0 \
					or not data.can_set_terrain(c, Terrain.SOIL):
				continue
			cells.append(c)
			if data.terrain_at(c) == Terrain.GRASS:
				tilled.append(c)
	for c: Vector2i in tilled:
		world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c, Terrain.SOIL))
	var hidden: Array[CanvasItem] = []
	for n: Node in world.entities.get_children():
		var ci: CanvasItem = n as CanvasItem
		if ci != null and ci.visible:
			ci.visible = false
			hidden.append(ci)
	world.decals.visible = false
	var ground_got: Image = await _capture()
	# The ground from the PNG files: every display cell on the screen, the tile it shows.
	var ground_want: Image = Image.create_empty(Config.VIEW_SIZE.x, Config.VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	var files: Dictionary[int, Image] = {}
	var unknown: int = 0
	for dy: int in range(origin.y / 16 - 2, (origin.y + Config.VIEW_SIZE.y) / 16 + 2):
		for dx: int in range(origin.x / 16 - 2, (origin.x + Config.VIEW_SIZE.x) / 16 + 2):
			var drawn: Vector3i = world.ground.drawn_at(Vector2i(dx, dy))
			if not GROUND_FILES.has(drawn.x):
				unknown += 1
				continue
			if not files.has(drawn.x):
				files[drawn.x] = _png("tiles/" + GROUND_FILES[drawn.x])
			ground_want.blit_rect(files[drawn.x], Rect2i(drawn.y * 16, drawn.z * 16, 16, 16), Vector2i(dx * 16 + 8, dy * 16 + 8) - origin)
	var ground_bad: int = count_diff(ground_got, ground_want)
	# The fields: 3 kinds x (stages 0..4, withered), every 4th wet; then wet bare soil; the rest dry bare soil.
	var sheet: Image = _png("env/crops_v03_sheet.png")
	var want: Image = ground_got.duplicate() as Image
	var wet_cells: Array[Vector2i] = []
	var crop_cells: Array[Vector2i] = []
	var crop_images: Array[Image] = []
	for i: int in cells.size():
		var c: Vector2i = cells[i]
		var f: Farming.Field = null
		if i < 18:
			f = Farming.Field.new(1 + i / 6, mini(i % 6, Farming.RIPE_STAGE), i % 4 == 0, false, i % 6 == 5)
		elif i < 24:
			f = Farming.Field.new(Farming.KIND_NONE, 0, true)
		if f == null:
			continue
		world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c, f.value()))
		if f.wet:
			wet_cells.append(c)
		if f.kind != Farming.KIND_NONE:
			crop_cells.append(c)
			crop_images.append(_crop_cell(sheet, 6 if f.withered else f.stage, f.kind - 1, f.wet))
	for c: Vector2i in wet_cells:
		for k: int in 4:
			var q: Vector2i = Vector2i(k % 2, k / 2)
			var drawn2: Vector3i = world.ground.drawn_at(c + q - Vector2i.ONE)
			if not WET_FILES.has(drawn2.x):
				unknown += 1
				continue
			if not files.has(100 + drawn2.x):
				files[100 + drawn2.x] = _png("tiles/" + WET_FILES[drawn2.x])
			want.blit_rect(files[100 + drawn2.x], Rect2i(drawn2.y * 16 + (1 - q.x) * 8, drawn2.z * 16 + (1 - q.y) * 8, 8, 8),
				c * 16 + q * 8 - origin)
	for i2: int in crop_cells.size():
		_paste_at(want, crop_images[i2], crop_cells[i2] * 16 - origin)
	var got: Image = await _capture()
	var fields_bad: int = count_diff(got, want)
	var drawn_px: int = count_diff(got, ground_got)
	# The evening on: wet and crop pixels well inside the light stay lit.
	world.lighting.set_evening(true)
	var eve: Image = await _capture()
	world.lighting.set_evening(false)
	var checked: int = 0
	var dark: int = 0
	for y2: int in Config.VIEW_SIZE.y:
		for x2: int in Config.VIEW_SIZE.x:
			var p: Vector2i = Vector2i(x2, y2)
			if want.get_pixelv(p) == ground_got.get_pixelv(p):
				continue  # not a field pixel (or one equal to the ground)
			if Vector2(origin + p).distance_to(centre) > Config.safe_radius_px() - Config.SAFE_EDGE_BAND_PX - 4:
				continue
			if _brightness(got.get_pixelv(p)) < MIN_BRIGHTNESS:
				continue
			checked += 1
			if _brightness(eve.get_pixelv(p)) < _brightness(got.get_pixelv(p)) * LIT_RATIO:
				dark += 1
	if ground_bad > 0 or fields_bad > 0 or dark > 0 or save_all:
		_save(ground_got, "fields_ground_got.png")
		_save(ground_want, "fields_ground_expected.png")
		_save(got, "fields_got.png")
		_save(want, "fields_expected.png")
		_save(eve, "fields_evening_got.png")
	# Back to the world as it was (the later parts use it).
	for c2: Vector2i in cells:
		world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, c2, 0))
	for c3: Vector2i in tilled:
		world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c3, Terrain.GRASS))
	for ci2: CanvasItem in hidden:
		ci2.visible = true
	world.decals.visible = true
	var line: String = "tiles=%d tilled=%d crops=%d wet=%d ground_mismatches=%d mismatches=%d drawn=%d unknown=%d lit_checked=%d dark=%d" % [
		cells.size(), tilled.size(), crop_cells.size(), wet_cells.size(), ground_bad, fields_bad, drawn_px, unknown, checked, dark]
	if ground_bad == 0 and fields_bad == 0 and unknown == 0 and dark == 0 and crop_cells.size() == 18 and wet_cells.size() >= 8 \
			and tilled.size() > 0 and drawn_px > 1000 and checked > 500:
		print("EVENSONG_RENDER fields ok %s" % line)
	else:
		_fail("fields", line)


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


# --- M5b: purification and the moved altar -------------------------------------------------------------------------

## The ground on the screen at `origin` from the PNG files: every display cell, the tile it shows (GROUND_FILES).
## Returns [image, unknown sources].
func _ground_png(origin: Vector2i) -> Array:
	var want: Image = Image.create_empty(Config.VIEW_SIZE.x, Config.VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	var files: Dictionary[int, Image] = {}
	var unknown: int = 0
	for dy: int in range(origin.y / 16 - 2, (origin.y + Config.VIEW_SIZE.y) / 16 + 2):
		for dx: int in range(origin.x / 16 - 2, (origin.x + Config.VIEW_SIZE.x) / 16 + 2):
			var drawn: Vector3i = world.ground.drawn_at(Vector2i(dx, dy))
			if not GROUND_FILES.has(drawn.x):
				unknown += 1
				continue
			if not files.has(drawn.x):
				files[drawn.x] = _png("tiles/" + GROUND_FILES[drawn.x])
			want.blit_rect(files[drawn.x], Rect2i(drawn.y * 16, drawn.z * 16, 16, 16), Vector2i(dx * 16 + 8, dy * 16 + 8) - origin)
	return [want, unknown]


func _hide_entities() -> Array[CanvasItem]:
	var hidden: Array[CanvasItem] = []
	for n: Node in world.entities.get_children():
		var ci: CanvasItem = n as CanvasItem
		if ci != null and ci.visible:
			ci.visible = false
			hidden.append(ci)
	return hidden


## M5b: the purified ground, the flash with its ash smears, the channel's motes (see the header).
func _check_purify() -> void:
	world.lighting.set_evening(false)
	var data: WorldData = world.data
	var pv: PurifyView = world.purify_view
	pv.auto_tick = false
	# A zone's southern edge tile with grass below it.
	var a: Vector2i = Vector2i(-1, -1)
	for y: int in range(8, data.size.y - 8):
		for x: int in range(16, data.size.x - 16):
			var c: Vector2i = Vector2i(x, y)
			if a.x < 0 and data.get_value(WorldData.Layer.CORRUPTION, c) != 0 and data.terrain_at(c + Vector2i(0, 1)) == Terrain.GRASS \
					and data.get_value(WorldData.Layer.CORRUPTION, c + Vector2i(0, -2)) != 0:
				a = c
	if a.x < 0:
		_fail("purify", "no zone edge found")
		return
	var centre_tile: Vector2i = a + Vector2i(0, 1)
	var origin: Vector2i = _look_at(centre_tile * 16 + Vector2i(8, 8))
	var hidden: Array[CanvasItem] = _hide_entities()
	world.decals.visible = false
	var r: Purify.Result = Purify.channel_done(data, centre_tile)
	var undo: Array[EditLog.WorldEdit] = []
	for c2: Vector2i in r.cells:
		undo.append(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, c2, data.terrain_at(c2)))
		undo.append(EditLog.WorldEdit.new(WorldData.Layer.CORRUPTION, c2, data.get_value(WorldData.Layer.CORRUPTION, c2)))
	for e: EditLog.WorldEdit in r.edits:
		world.apply_edit(e)
	var grass: int = 0
	for c3: Vector2i in r.cells:
		grass += int(data.terrain_at(c3) == Terrain.GRASS)
	var ground_got: Image = await _capture()
	var png: Array = _ground_png(origin)
	var ground_want: Image = png[0]
	var unknown: int = png[1]
	var ground_bad: int = count_diff(ground_got, ground_want)
	# The first frame: the smears (written out: decal (x * 7 + y * 13) mod 3, centred) and the gold borders.
	pv.flash(r.cells)
	var want: Image = ground_got.duplicate() as Image
	var gold_px: Dictionary[Vector2i, bool] = {}
	var ash_px: Dictionary[Vector2i, bool] = {}
	var decals: Array[Image] = [_png("env/decal_ashcreep_1_v01.png"), _png("env/decal_ashcreep_2_v01.png"),
		_png("env/decal_ashcreep_3_v01.png")]
	for c4: Vector2i in r.cells:
		var d: Image = decals[posmod(c4.x * 7 + c4.y * 13, 3)]
		var at: Vector2i = c4 * 16 + (Vector2i(16, 16) - d.get_size()) / 2 - origin
		for y2: int in d.get_height():
			for x2: int in d.get_width():
				var px: Color = d.get_pixel(x2, y2)
				if px.a8 == 255:
					want.set_pixelv(at + Vector2i(x2, y2), px)
					ash_px[at + Vector2i(x2, y2)] = true
				elif px.a8 != 0:
					unknown += 1  # the decals have no half-transparent pixels (04-env 손질 규칙)
	for c5: Vector2i in r.cells:
		for i: int in 16:
			for p: Vector2i in [Vector2i(i, 0), Vector2i(i, 15), Vector2i(0, i), Vector2i(15, i)]:
				var s: Vector2i = c5 * 16 + p - origin
				want.set_pixelv(s, PurifyView.GOLD)
				gold_px[s] = true
				ash_px.erase(s)
	var got: Image = await _capture()
	var flash_bad: int = count_diff(got, want)
	world.lighting.set_evening(true)
	var eve: Image = await _capture()
	var gold_wrong: int = 0
	for s2: Vector2i in gold_px:
		if eve.get_pixelv(s2) != PurifyView.GOLD:
			gold_wrong += 1
	var ash_lit: int = 0
	for s3: Vector2i in ash_px:
		if _brightness(eve.get_pixelv(s3)) > _brightness(got.get_pixelv(s3)) * LIT_RATIO:
			ash_lit += 1
	# The motes of a channel on its last tick, evening on (unshaded), over the purified ground with the flash gone.
	pv.advance(Config.PURIFY_ASH_TICKS)
	var bg: Image = await _capture()
	pv.show_channels([PurifyView.Channel.new(centre_tile, Config.PURIFY_CHANNEL_TICKS)] as Array[PurifyView.Channel])
	var motes: Image = await _capture()
	var mote_want: Image = bg.duplicate() as Image
	var ring_c: Vector2 = (Vector2(centre_tile) + Vector2(0.5, 0.5)) * 16.0
	var ring_r: float = (Config.PURIFY_RADIUS_TILES + 0.5) * 16.0
	for i2: int in Config.PURIFY_MOTES:
		var ang: float = TAU * float(i2) / float(Config.PURIFY_MOTES) - PI / 2.0
		var tl: Vector2i = Vector2i((ring_c + Vector2(cos(ang), sin(ang)) * ring_r).round()) - Vector2i.ONE - origin
		for k: int in 4:
			mote_want.set_pixelv(tl + Vector2i(k % 2, k / 2), PurifyView.GOLD)
		mote_want.set_pixelv(tl, PurifyView.IVORY)
	var mote_bad: int = count_diff(motes, mote_want)
	var mote_px: int = count_diff(motes, bg)
	pv.show_channels([] as Array[PurifyView.Channel])
	world.lighting.set_evening(false)
	if ground_bad > 0 or flash_bad > 0 or gold_wrong > 0 or ash_lit > 0 or mote_bad > 0 or save_all:
		_save(ground_got, "purify_ground_got.png")
		_save(ground_want, "purify_ground_expected.png")
		_save(got, "purify_flash_got.png")
		_save(want, "purify_flash_expected.png")
		_save(eve, "purify_flash_evening.png")
		_save(motes, "purify_motes_got.png")
		_save(mote_want, "purify_motes_expected.png")
	# Back as it was.
	for e2: EditLog.WorldEdit in undo:
		world.apply_edit(e2)
	for ci: CanvasItem in hidden:
		ci.visible = true
	world.decals.visible = true
	var line: String = "tiles=%d grass=%d ground_mismatches=%d flash_mismatches=%d gold=%d gold_wrong=%d ash=%d ash_lit=%d motes_px=%d mote_mismatches=%d unknown=%d" % [
		r.cells.size(), grass, ground_bad, flash_bad, gold_px.size(), gold_wrong, ash_px.size(), ash_lit, mote_px, mote_bad, unknown]
	if r.cells.size() > 3 and grass == r.cells.size() and ground_bad == 0 and flash_bad == 0 and gold_wrong == 0 and ash_lit == 0 \
			and ash_px.size() > 20 and mote_bad == 0 and mote_px == 4 * Config.PURIFY_MOTES and unknown == 0:
		print("EVENSONG_RENDER purify ok %s" % line)
	else:
		_fail("purify", line)


## M5b: the moved altar's light, the carried mark and the ghost (see the header).
func _check_altar_move() -> void:
	var data: WorldData = world.data
	var home: Rect2i = data.altar_rect
	var old_zone: SafeZone = world.safe_zone
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		world.apply_edit(e)
	var to: Rect2i = AltarMove.set_down_rect(data, (Vector2(home.position) + Vector2(-12, 1)) * Config.TILE)
	for e2: EditLog.WorldEdit in AltarMove.place_edits(to):
		world.apply_edit(e2)
	var z: SafeZone = world.safe_zone
	var origin: Vector2i = _look_at(Vector2i(z.center) + Vector2i(80, 0))
	# Only the altar among the entities (the gatherables take the actors' hard light, not the ground's dither).
	var hidden: Array[CanvasItem] = _hide_entities()
	world.altar.visible = true
	hidden.erase(world.altar)
	world.lighting.set_evening(true)
	var eve: Image = await _capture()
	world.lighting.set_evening(false)
	var day: Image = await _capture()
	var flame_px: Dictionary[Vector2i, bool] = {}
	var mask: Image = Altar.flame_image()
	var art: Vector2i = world.altar.art_origin()
	for y: int in mask.get_height():
		for x: int in mask.get_width():
			if mask.get_pixel(x, y).a8 > 0:
				flame_px[art + Vector2i(x, y) - origin] = true
	var band: int = Config.SAFE_EDGE_BAND_PX
	var mismatches: int = 0
	var checked: int = 0
	var old_lit: int = 0
	var old_seen: int = 0
	for sy: int in Config.VIEW_SIZE.y:
		for sx: int in Config.VIEW_SIZE.x:
			var s: Vector2i = Vector2i(sx, sy)
			if flame_px.has(s):
				continue
			var b: Color = day.get_pixelv(s)
			if _brightness(b) < MIN_BRIGHTNESS:
				continue
			var lit: bool = _brightness(eve.get_pixelv(s)) / _brightness(b) > LIT_RATIO
			var px: Vector2i = origin + s
			checked += 1
			if lit != (LightGen.light_at(z, LightGen.Edge.DITHER, band, px) > 0.5):
				mismatches += 1
			if old_zone.is_in_safe_zone(Vector2(px) + Vector2(0.5, 0.5)) and not z.is_in_safe_zone(Vector2(px) + Vector2(0.5, 0.5)):
				old_seen += 1
				old_lit += int(lit)
	var flames_wrong: int = 0
	var lit_art: Image = LightGen.to_rgba8(Altar.LIT.get_image())
	for f: Vector2i in flame_px:
		var a: Vector2i = f + origin - art
		if eve.get_pixelv(f) != lit_art.get_pixelv(a):
			flames_wrong += 1
	# A player carrying the altar: the mark over its head (written out: 9x6, top-left at the feet + (-4, -53)).
	var rows: PackedStringArray = ["..g.g.g..", ".kgkgkgk.", "kkkkkkkkk", "khhhhhhhk", "kmmmmmmmk", "kkkkkkkkk"]
	var feet: Vector2i = Vector2i(z.center) + Vector2i(150, 30)
	var p: Player = Player.new()
	p.local_input = false
	p.setup(data, "paladin", Vector2(feet))
	p.character.animate = false
	world.entities.add_child(p)
	world.lighting.set_evening(false)
	var before_mark: Image = await _capture()
	p.set_carrying_altar(true)
	world.lighting.set_evening(true)
	var mark_eve: Image = await _capture()
	world.lighting.set_evening(false)
	var mark_day: Image = await _capture()
	var mark_wrong: int = 0
	var mark_n: int = 0
	for my: int in rows.size():
		for mx: int in rows[my].length():
			var ch: String = rows[my][mx]
			if ch == ".":
				continue
			mark_n += 1
			var sp: Vector2i = feet + Vector2i(-4 + mx, -53 + my) - origin
			var want_c: Color = ItemIcons.PALETTE[ch]
			if mark_eve.get_pixelv(sp) != want_c or mark_day.get_pixelv(sp) != want_c:
				mark_wrong += 1
	var mark_changed: int = count_diff(mark_day, before_mark)
	world.entities.remove_child(p)
	p.free()
	# The ghost: outline and light-edge dots, gold then deep red (written out).
	var ghost: AltarGhost = AltarGhost.new()
	world.add_child(ghost)
	world.move_child(ghost, world.entities.get_index())
	var gr: Rect2i = Rect2i(Aim.feet_cell(Vector2(feet)) + Vector2i(-6, -2), Vector2i(3, 3))
	var ghost_px: Dictionary[Vector2i, bool] = {}
	var lo: Vector2i = gr.position * 16
	var hi: Vector2i = gr.end * 16 - Vector2i.ONE
	for gx: int in range(lo.x, hi.x + 1):
		ghost_px[Vector2i(gx, lo.y) - origin] = true
		ghost_px[Vector2i(gx, hi.y) - origin] = true
	for gy: int in range(lo.y, hi.y + 1):
		ghost_px[Vector2i(lo.x, gy) - origin] = true
		ghost_px[Vector2i(hi.x, gy) - origin] = true
	var gc: Vector2 = (Vector2(gr.position) + Vector2(1.5, 1.5)) * 16.0
	for deg: int in range(0, 360, 6):
		var ang: float = deg_to_rad(float(deg))
		ghost_px[Vector2i((gc + Vector2(cos(ang), sin(ang)) * (Config.safe_radius_px() - 1.0)).floor()) - origin] = true
	var ghost_wrong: int = 0
	var ghost_seen: int = 0
	world.lighting.set_evening(true)
	for allowed: bool in [true, false]:
		ghost.show_at(gr, allowed)
		var gimg: Image = await _capture()
		var col: Color = AltarGhost.GOLD if allowed else AltarGhost.RED
		for gp: Vector2i in ghost_px:
			if gp.x < 0 or gp.y < 0 or gp.x >= Config.VIEW_SIZE.x or gp.y >= Config.VIEW_SIZE.y:
				continue
			ghost_seen += 1
			if gimg.get_pixelv(gp) != col:
				ghost_wrong += 1
	world.remove_child(ghost)
	ghost.free()
	world.lighting.set_evening(false)
	if mismatches > 0 or old_lit > 0 or flames_wrong > 0 or mark_wrong > 0 or ghost_wrong > 0 or save_all:
		_save(eve, "altar_evening.png")
		_save(day, "altar_day.png")
		_save(mark_eve, "altar_mark_evening.png")
	# Home again.
	for ci: CanvasItem in hidden:
		ci.visible = true
	for e3: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		world.apply_edit(e3)
	for e4: EditLog.WorldEdit in AltarMove.place_edits(home):
		world.apply_edit(e4)
	var line: String = "moved_to=%d,%d checked=%d mismatches=%d old_zone_px=%d old_zone_lit=%d flames=%d wrong=%d mark=%d mark_wrong=%d mark_changed=%d ghost_px=%d ghost_wrong=%d home=%s" % [
		to.position.x, to.position.y, checked, mismatches, old_seen, old_lit, flame_px.size(), flames_wrong, mark_n, mark_wrong,
		mark_changed, ghost_seen, ghost_wrong, data.altar_rect == home]
	if to.has_area() and mismatches == 0 and checked > 50000 and old_seen > 1000 and old_lit == 0 and flame_px.size() == 81 \
			and flames_wrong == 0 and mark_wrong == 0 and mark_n == 46 and mark_changed == mark_n and ghost_wrong == 0 \
			and ghost_seen > 200 and data.altar_rect == home:
		print("EVENSONG_RENDER altar ok %s" % line)
	else:
		_fail("altar", line)
