extends "res://tests/base_test.gd"
## Body actions (M2a): the action sheets against the brief's numbers, foot alignment (a 64 cell's
## start picture placed by the feet rule is pixel for pixel walk frame 0; throw's feet on row 31), what
## a Character node draws for every class, direction, action and frame (a CPU render of its sprites)
## against a composite built here from the sheets and the documented rules, the held-signature rule
## (● R27), the player's action timing (frames, duration, movement and facing locked, target tile
## reported, repeat while held, non-tools do nothing), and in main.tscn: left click with a tool, F6.

const CheckRender := preload("res://tools/check_render.gd")
const E: int = RigData.Dir.EAST

## [sheet file, frames per direction, cell] per action, from brief §5.6 "슬라이스 몸 동작" and
## 03-pixel/prompts.md 8~12차 (written out here, not read from RigData).
const DOC: Dictionary[int, Array] = {
	RigData.Anim.PICKAXE: ["base_body_v02_pickaxe.png", 6, 64],
	RigData.Anim.HOE: ["base_body_v02_hoe.png", 6, 64],
	RigData.Anim.SICKLE: ["base_body_v02_sickle.png", 6, 64],
	RigData.Anim.WATERING: ["base_body_v02_watering.png", 8, 64],
	RigData.Anim.SWORD: ["base_body_v02_sword.png", 8, 64],
	RigData.Anim.BOW: ["base_body_v02_bow.png", 8, 64],
	RigData.Anim.MAGIC: ["base_body_v02_magic.png", 6, 64],
	RigData.Anim.THROW: ["base_body_v02_throw.png", 7, 32],
}
## v01 -> v02 re-pivot of each action's rows (south, east, north): the 64 cell actions were aligned on
## walk frame 0 (walk +4 +3 +4), throw re-pivoted on its own (+4 +4 +3).
const PIVOT: Dictionary[int, Array] = {
	RigData.Anim.PICKAXE: [4, 3, 4], RigData.Anim.HOE: [4, 3, 4], RigData.Anim.SICKLE: [4, 3, 4],
	RigData.Anim.WATERING: [4, 3, 4], RigData.Anim.SWORD: [4, 3, 4], RigData.Anim.BOW: [4, 3, 4],
	RigData.Anim.MAGIC: [4, 3, 4], RigData.Anim.THROW: [4, 4, 3],
}
## Render canvas and the feet point on it.
const CANVAS: Vector2i = Vector2i(128, 96)
const FEET: Vector2i = Vector2i(64, 72)

var _images: Dictionary[String, Image] = {}


func run() -> Array[String]:
	_check_tables()
	_check_foot_alignment()
	_check_node_render()
	_check_hide_rules()
	_check_player_timing()
	await _check_main_use()
	return failures


func _image(path: String) -> Image:
	if not _images.has(path):
		_images[path] = LightGen.to_rgba8((load(path) as Texture2D).get_image())
	return _images[path]


func _check_tables() -> void:
	check_eq(RigData.ACTION_ANIMS.size(), 8, "eight body actions")
	for anim: int in RigData.ACTION_ANIMS:
		var doc: Array = DOC[anim]
		var name: String = RigData.ANIM_NAMES[anim]
		var cell: int = doc[2]
		var frames: int = doc[1]
		var first: int = 1 if cell == 64 else 0
		check(RigData.is_action(anim), "%s is an action" % name)
		check_eq(RigData.SHEET_PATHS[anim], "res://art/chars/" + str(doc[0]), "%s sheet" % name)
		check_eq(RigData.frame_count(anim), frames, "%s frames" % name)
		check_eq(RigData.cell(anim), cell, "%s cell" % name)
		check_eq(RigData.body_offset(anim), Vector2i(16, 16) if cell == 64 else Vector2i.ZERO, "%s 32 frame inside the cell" % name)
		var sheet: Image = _image(RigData.SHEET_PATHS[anim])
		check_eq(sheet.get_size(), Vector2i(cell * (first + frames), cell * 3), "%s sheet size (start column %d + %d frames, 3 rows)" % [
			name, first, frames])
		for row: int in 3:
			check_eq(RigData.shift(anim, row), PIVOT[anim][row], "%s re-pivot %s" % [name, RigData.DIR_NAMES[row]])
			check_eq(RigData.body_rect(row, 0, anim), Rect2i(first * cell, row * cell, cell, cell), "%s %s first played frame" % [
				name, RigData.DIR_NAMES[row]])
			check_eq(RigData.body_rect(row, frames - 1, anim).end.x, sheet.get_width(), "%s last frame = last column" % name)
		check_eq(RigData.frame_time(anim), float(Config.ACTION_FRAME_TICKS) / Config.NET_TICK_RATE, "%s frame time" % name)
		check_eq(Player.action_ticks(anim), frames * Config.ACTION_FRAME_TICKS, "%s lasts frames x ACTION_FRAME_TICKS" % name)
	for anim: int in RigData.BASE_ANIMS:
		check(not RigData.is_action(anim), "%s is not an action" % RigData.ANIM_NAMES[anim])


## 64 cells: the start column, placed with its feet row (y=47) on the feet, is walk frame 0 placed
## with its feet row (y=31) on the feet, pixel for pixel (so every column shares those feet). Throw:
## each row's lowest opaque pixel over its frames is row 31 (re-pivoted to the frame bottom).
func _check_foot_alignment() -> void:
	var walk: Image = _image(RigData.SHEET_PATHS[RigData.Anim.WALK])
	for anim: int in RigData.ACTION_ANIMS:
		var name: String = RigData.ANIM_NAMES[anim]
		var sheet: Image = _image(RigData.SHEET_PATHS[anim])
		var cell: int = RigData.cell(anim)
		for row: int in 3:
			if cell == 64:
				var a: Image = Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
				a.blit_rect_mask(sheet, sheet, Rect2i(0, row * 64, 64, 64), FEET - Vector2i(32, 48))
				var b: Image = Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
				b.blit_rect_mask(walk, walk, Rect2i(0, row * 32, 32, 32), FEET - Vector2i(16, 32))
				check_eq(CheckRender.count_diff(a, b), 0, "%s %s start column on the feet = walk frame 0 on the feet" % [
					name, RigData.DIR_NAMES[row]])
				check_eq(RigData.body_rect(row, -1, anim), Rect2i(0, row * 64, 64, 64), "%s frame -1 = start column" % name)
				check_eq(sheet.get_region(Rect2i(0, row * 64, 64, 64)).get_used_rect().end.y, 48, "%s %s start feet row y=47" % [
					name, RigData.DIR_NAMES[row]])
			else:
				var lowest: int = -1
				for f: int in RigData.frame_count(anim):
					var used: Rect2i = sheet.get_region(Rect2i(f * 32, row * 32, 32, 32)).get_used_rect()
					lowest = maxi(lowest, used.end.y - 1)
				check_eq(lowest, 31, "%s %s feet on row 31" % [name, RigData.DIR_NAMES[row]])


## What the node draws: its visible rig sprites in tree order at their positions, mirrored with the
## rig. Canvas CANVAS with the character's feet at FEET.
func _render_node(c: Character) -> Image:
	var canvas: Image = Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
	for child: Node in c.rig.get_children():
		var s: Sprite2D = child as Sprite2D
		if s == null or not s.visible:
			continue
		var img: Image = _image(s.texture.resource_path)
		canvas.blit_rect_mask(img, img, Rect2i(s.region_rect), FEET + Vector2i(s.position))
	if c.rig.scale.x < 0.0:
		canvas.flip_x()
	return canvas


## The same frame built from the sheets and the rules: body cell with its feet on FEET (64 cell: the
## cell's (32, 48); 32 cell: (16, 32)), the signature layer at walk v01 position + re-pivot + the
## frame's anchor (torso, or head for the halo) unless the action holds it (miner pickaxe, archer
## bow), back gear behind the body except facing north, the others in front; west = east mirrored.
func _expected(class_id: String, dir: int, anim: int, f: int) -> Image:
	var canvas: Image = Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
	var row: int = 1 if dir == RigData.Dir.WEST else dir
	var doc: Array = DOC[anim]
	var cell: int = doc[2]
	var first: int = 1 if cell == 64 else 0
	var sheet: Image = _image("res://art/chars/" + str(doc[0]))
	var body_src: Rect2i = Rect2i((first + f) * cell, row * cell, cell, cell)
	var body_at: Vector2i = FEET - (Vector2i(32, 48) if cell == 64 else Vector2i(16, 32))
	var sig: RigData.Signature = RigData.signature_for(class_id)
	var held: bool = (class_id == "miner" and anim == RigData.Anim.PICKAXE) or (class_id == "archer" and anim == RigData.Anim.BOW)
	var table: Array[Array] = RigAnchors.HEAD if class_id == "cleric" else RigAnchors.TORSO
	var rows: Array = table[anim]
	var frames: Array = rows[row]
	var anchor: Vector2i = frames[f]
	var pivot: int = PIVOT[anim][row]
	var sig_at: Vector2i = FEET - Vector2i(16, 32) + sig.pos_v01 + Vector2i(0, pivot) + anchor
	var layer: Image = _image(sig.path)
	var sig_src: Rect2i = sig.source_rect(row)
	var back: bool = class_id == "miner" or class_id == "archer"
	var behind: bool = back and row != RigData.Dir.NORTH
	if not held and behind:
		canvas.blit_rect_mask(layer, layer, sig_src, sig_at)
	canvas.blit_rect_mask(sheet, sheet, body_src, body_at)
	if not held and not behind:
		canvas.blit_rect_mask(layer, layer, sig_src, sig_at)
	if dir == RigData.Dir.WEST:
		canvas.flip_x()
	return canvas


func _check_node_render() -> void:
	var t0: int = Time.get_ticks_msec()
	var frames: int = 0
	var bad: int = 0
	var first_bad: String = ""
	for class_id: String in Config.CLASSES:
		var c: Character = Character.new()
		c.animate = false
		c.class_id = class_id
		for dir: int in 4:
			c.direction = dir as RigData.Dir
			for anim: int in RigData.ACTION_ANIMS:
				for f: int in RigData.frame_count(anim):
					c.show_action(anim, f)
					frames += 1
					var got: Image = _render_node(c)
					if got.get_data() != _expected(class_id, dir, anim, f).get_data():
						bad += 1
						if first_bad.is_empty():
							first_bad = "%s %s %s frame %d" % [class_id, RigData.DIR_NAMES[dir], RigData.ANIM_NAMES[anim], f]
					# The node's own placement numbers, for a readable failure.
					if f == 0:
						var cell: int = RigData.cell(anim)
						check_eq(c.body.position, Vector2(-32, -48) if cell == 64 else Vector2(-16, -32), "%s %s body on the feet" % [
							class_id, RigData.ANIM_NAMES[anim]])
						check(not c.body.centered and c.body.offset == Vector2.ZERO and c.rig.position == Vector2.ZERO,
							"sprites drawn from their top-left")
		c.free()
	check_eq(frames, 5 * 4 * (6 + 6 + 6 + 8 + 8 + 8 + 6 + 7), "frames rendered (5 classes x 4 directions x 55)")
	check_eq(bad, 0, "node drawing = sheets + rules for every action frame (first difference: %s)" % first_bad)
	# The renders are not blank and the actions differ from walking.
	var c2: Character = Character.new()
	c2.animate = false
	c2.class_id = "paladin"
	var walk0: PackedByteArray = _render_node(c2).get_data()
	c2.show_action(RigData.Anim.SWORD, 4)
	check(_render_node(c2).get_data() != walk0, "a sword frame differs from idle")
	check(LightGen.count_opaque(_render_node(c2)) > 300, "a rendered frame has the body and the shield")
	c2.free()
	note("action frames: %d node renders compared with sheet composites in %d ms" % [frames, Time.get_ticks_msec() - t0])


## ● R27: the miner's pickaxe action and the archer's bow action hide the back signature (it is the
## tool in hand); every other class keeps its signature as a layer in every action (the paladin's
## shield while the sword swings, the herbalist's pouch while farming, the halo during magic).
func _check_hide_rules() -> void:
	var hidden: Array[String] = []
	for class_id: String in Config.CLASSES:
		var c: Character = Character.new()
		c.animate = false
		c.class_id = class_id
		for anim: int in RigData.ACTION_ANIMS:
			for dir: int in 4:
				c.direction = dir as RigData.Dir
				c.show_action(anim, 1)
				var shown: bool = c.signature_sprite().visible
				var want_hidden: bool = (class_id == "miner" and anim == RigData.Anim.PICKAXE) or \
					(class_id == "archer" and anim == RigData.Anim.BOW)
				check_eq(shown, not want_hidden, "%s %s %s: signature %s" % [class_id, RigData.ANIM_NAMES[anim],
					RigData.DIR_NAMES[dir], "hidden" if want_hidden else "shown"])
				check_eq(c.draw_order().size(), 1 if want_hidden else 2, "%s %s visible layers" % [class_id, RigData.ANIM_NAMES[anim]])
				if not shown and dir == 0:
					hidden.append("%s/%s" % [class_id, RigData.ANIM_NAMES[anim]])
				var other: int = 0
				for slot: StringName in RigData.SLOTS:
					if slot != c.signature.slot and c.slots[slot].visible:
						other += 1
				check_eq(other, 0, "no other slot shows")
		c.end_action()
		check(c.signature_sprite().visible and c.action == -1 and c.anim == RigData.Anim.IDLE, "%s: end_action returns to idle with the signature" % class_id)
		c.free()
	check_eq(hidden, ["miner/pickaxe", "archer/bow"] as Array[String], "exactly two (class, action) pairs hide the signature")
	check(RigData.hides_signature(RigData.signature_for("miner"), RigData.Anim.PICKAXE), "hides_signature(miner, pickaxe)")
	check(not RigData.hides_signature(RigData.signature_for("miner"), RigData.Anim.WALK), "walking shows it")
	# Character API edges.
	var c3: Character = Character.new()
	c3.animate = false
	c3.show_action(RigData.Anim.BOW, 99)
	check_eq(c3.frame, 7, "a frame past the end shows the last one")
	c3.walking = true
	check_eq(c3.anim, RigData.Anim.BOW, "walking does not cut an action")
	c3.advance(5.0)
	check_eq(c3.frame, 7, "advance() leaves an action alone (the player times it)")
	c3.end_action()
	check_eq([c3.anim, c3.frame], [RigData.Anim.WALK, 0], "end_action goes back to walking when walking")
	allow_error("is not a body action")
	c3.show_action(RigData.Anim.WALK, 0)
	check_eq(c3.action, -1, "walk is not an action")
	c3.free()


## Player.tick_controls: use with a tool starts its action toward the target tile; frames advance every
## ACTION_FRAME_TICKS; movement and facing are locked; it ends after frames x ACTION_FRAME_TICKS;
## holding use repeats; non-tools and an empty hand do nothing.
func _check_player_timing() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var p: Player = Player.new()
	var start: Vector2 = data.altar_center_px() + Vector2(-80, 60)
	p.setup(data, "miner", start)
	p.inventory.add(&"pickaxe", 1)
	p.inventory.add(&"sword", 1)
	p.inventory.add(&"stone_a", 5)
	var started: Array[Array] = []
	var finished: Array[int] = []
	p.action_started.connect(func(item: StringName, anim: int, target: Vector2i) -> void: started.append([item, anim, target]))
	p.action_finished.connect(func(anim: int) -> void: finished.append(anim))
	var east: Vector2 = start + Vector2(40, 2)
	var dt: float = Config.NET_TICK
	# A tick of aiming first: facing east, target the tile east of the feet.
	p.tick_controls(Vector2i.ZERO, east, true, false, false, dt)
	var target: Vector2i = Aim.feet_cell(start) + Vector2i(1, 0)
	check_eq(p.aim_cell, target, "aim cell east of the feet")
	p.tick_controls(Vector2i(0, 1), east, true, true, true, dt)
	check_eq(started, [[&"pickaxe", RigData.Anim.PICKAXE, target]], "use starts the pickaxe action and reports its target")
	check_eq(p.action_anim, RigData.Anim.PICKAXE, "acting")
	check_eq(p.sim_position, start, "the tick that starts an action does not move")
	check_eq(p.facing, E, "faces the target")
	check_eq([p.character.action, p.character.frame, p.character.direction], [RigData.Anim.PICKAXE, 0, E], "character shows frame 0")
	var ticks: int = Player.action_ticks(RigData.Anim.PICKAXE)
	var frames_seen: Array[int] = [0]
	for t: int in range(1, ticks):
		# Walking south-west and the mouse moving north: locked.
		p.tick_controls(Vector2i(-1, 1), start + Vector2(0, -60), true, false, true if t < 10 else false, dt)
		frames_seen.append(p.character.frame)
		if p.sim_position != start or p.facing != E or p.action_anim != RigData.Anim.PICKAXE:
			fail("tick %d: the action must lock position and facing (at %s facing %s)" % [t, p.sim_position, p.facing])
			break
	var want: Array[int] = []
	for t: int in ticks:
		want.append(t / Config.ACTION_FRAME_TICKS)
	check_eq(frames_seen, want, "frame = ticks / ACTION_FRAME_TICKS")
	check(finished.is_empty(), "not finished before %d ticks" % ticks)
	p.tick_controls(Vector2i.ZERO, east, true, false, false, dt)
	check_eq(finished, [RigData.Anim.PICKAXE] as Array[int], "finished after %d ticks" % ticks)
	check_eq([p.action_anim, p.character.action, p.character.anim], [-1, -1, RigData.Anim.IDLE], "back to idle")
	check_eq(started.size(), 1, "released: no repeat")
	# Held: repeats on the tick it ends; moving again after release.
	p.inventory.select(1)
	p.tick_controls(Vector2i.ZERO, east, true, true, true, dt)
	var sword_ticks: int = Player.action_ticks(RigData.Anim.SWORD)
	for t: int in sword_ticks:
		p.tick_controls(Vector2i.ZERO, east, true, false, true, dt)
	check_eq(started.size(), 3, "holding use: the sword again on the tick the first ends")
	check_eq([finished.size(), p.action_tick], [2, 0], "the repeat starts at tick 0")
	for t: int in sword_ticks:
		p.tick_controls(Vector2i.ZERO, east, true, false, false, dt)
	check_eq(p.action_anim, -1, "released: stops after the current one")
	p.tick_controls(Vector2i(1, 0), east, true, false, false, dt)
	check(p.sim_position.x > start.x, "moves again after the action")
	# Non-tools and an empty hand.
	p.inventory.select(2)
	p.tick_controls(Vector2i.ZERO, east, true, true, true, dt)
	check_eq(p.action_anim, -1, "a gatherable plays nothing")
	p.inventory.select(5)
	p.tick_controls(Vector2i.ZERO, east, true, true, true, dt)
	check_eq(p.action_anim, -1, "an empty slot plays nothing")
	check_eq(started.size(), 3, "no action started")
	# Any action can be started directly (F6, magic and throw).
	p.start_action(RigData.Anim.THROW, &"debug")
	for t: int in Player.action_ticks(RigData.Anim.THROW) - 1:
		p.tick_controls(Vector2i.ZERO, east, false, false, false, dt)
	check_eq([p.action_anim, p.character.frame], [RigData.Anim.THROW, 6], "throw on its last frame")
	p.tick_controls(Vector2i.ZERO, east, false, false, false, dt)
	check_eq(p.action_anim, -1, "throw over after 7 frames")
	p.start_action(RigData.Anim.WALK)
	check_eq(p.action_anim, -1, "walk cannot be started as an action")
	p.free()


## main.tscn: F5 kit, the pickaxe selected, the mouse east of the player, left click: the action plays
## and the marker shows its tile; after it, F6 plays the actions in order.
func _check_main_use() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var player: Player = main.player
	if not check(player != null, "main has a player"):
		return
	main.give_debug_kit()
	player.inventory.select(0)
	var started: Array[int] = []
	player.action_started.connect(func(_item: StringName, anim: int, _target: Vector2i) -> void: started.append(anim))
	var screen: Vector2 = player.get_global_transform_with_canvas().origin
	var window: Vector2 = Aim.view_margin(tree.root.size) + (screen + Vector2(40, 0)) * float(Aim.view_scale(tree.root.size))
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.position = window
	ev.global_position = window
	Input.parse_input_event(ev)
	Input.action_press(&"use_item")
	await tree.physics_frame
	await tree.physics_frame
	Input.action_release(&"use_item")
	await await_frames(1)
	check_eq(started, [RigData.Anim.PICKAXE] as Array[int], "left click with the pickaxe selected plays the pickaxe")
	check_eq(player.character.action, RigData.Anim.PICKAXE, "the character shows it")
	check_eq(player.facing, E, "facing the mouse")
	check(main.marker.visible and main.marker.position == Vector2(player.action_cell * Config.TILE), "marker on the target tile")
	check_eq(player.action_cell, Aim.feet_cell(player.sim_position) + Vector2i(1, 0), "target = the tile east of the feet")
	# The mouse goes west while the action plays: the aim follows it, the marker stays on the action's tile.
	var west: Vector2 = Aim.view_margin(tree.root.size) + (screen + Vector2(-40, 0)) * float(Aim.view_scale(tree.root.size))
	var ev_west: InputEventMouseMotion = InputEventMouseMotion.new()
	ev_west.position = west
	ev_west.global_position = west
	Input.parse_input_event(ev_west)
	await tree.physics_frame
	await tree.physics_frame
	await await_frames(1)
	check(player.action_anim == RigData.Anim.PICKAXE and player.aim_cell == Aim.feet_cell(player.sim_position) + Vector2i(-1, 0),
		"mid-action the aim follows the mouse west (%s)" % player.aim_cell)
	check(main.marker.visible and main.marker.position == Vector2(player.action_cell * Config.TILE),
		"but the marker stays on the tile being hit (%s)" % main.marker.position)
	for i: int in Player.action_ticks(RigData.Anim.PICKAXE) + 2:
		await tree.physics_frame
	check_eq(player.action_anim, -1, "the action ends")
	check_eq(started.size(), 1, "one click, one action")
	var press: InputEventAction = InputEventAction.new()
	press.action = &"debug_action"
	press.pressed = true
	Input.parse_input_event(press)
	await tree.physics_frame
	check_eq(player.action_anim, RigData.ACTION_ANIMS[0], "F6 plays the first action")
	for i: int in Player.action_ticks(player.action_anim) + 2:
		await tree.physics_frame
	Input.parse_input_event(press)
	await tree.physics_frame
	check_eq(player.action_anim, RigData.ACTION_ANIMS[1], "F6 again plays the next one")
	for i: int in Player.action_ticks(player.action_anim) + 2:
		await tree.physics_frame

