extends "res://tests/base_test.gd"
## Actors: art copies, the anchor table (measured again from the sheets), the character rig (layer
## order per direction, west mirror, anchors and v01 -> v02 shift applied to every frame, animation),
## movement rules (speed, 8 ways, map bounds, altar footprint, sliding, determinism, facing), spawn
## slots, and the run scene main.tscn (local player from the keys, dummies, camera follow and clamp,
## y-sort parent, safe-zone rule, evening toggle).

## Our art in game/art and where it was copied from (repo-relative). Checked byte for byte when the
## repo's assets/ folder is next to game/ (it is not in an exported build or a bare game/ copy).
const ART_SOURCES: Dictionary[String, String] = {
	"res://art/chars/base_body_v02_walk.png": "assets/concept/03-pixel/base_body_v02_walk.png",
	"res://art/chars/base_body_v02_idle.png": "assets/concept/03-pixel/base_body_v02_idle.png",
	"res://art/chars/sig_paladin_shield_v01.png": "assets/concept/03-pixel/sig_paladin_shield_v01.png",
	"res://art/chars/sig_miner_pickaxe_v01.png": "assets/concept/03-pixel/sig_miner_pickaxe_v01.png",
	"res://art/chars/sig_archer_bow_v01.png": "assets/concept/03-pixel/sig_archer_bow_v01.png",
	"res://art/chars/sig_cleric_halo_v01.png": "assets/concept/03-pixel/sig_cleric_halo_v01.png",
	"res://art/chars/sig_herbalist_pouch_v02.png": "assets/concept/03-pixel/sig_herbalist_pouch_v02.png",
	"res://art/env/altar_v04.png": "assets/concept/04-env/altar_v04.png",
	"res://art/env/altar_v04_unlit.png": "assets/concept/04-env/altar_v04_unlit.png",
	"res://art/tiles/tiles_grass-soil_v03.png": "assets/concept/04-env/tiles_grass-soil_v03.png",
	"res://art/tiles/tiles_grass-soil_v01.json": "assets/concept/04-env/tiles_grass-soil_v01.json",
	"res://art/tiles/tiles_grass-corruption_v05.png": "assets/concept/04-env/tiles_grass-corruption_v05.png",
	"res://art/tiles/tiles_grass-corruption_v02.json": "assets/concept/03-pixel/tiles_grass-corruption_v02.json",
	"res://art/tiles/tiles_grass_var_1_v02.png": "assets/concept/04-env/tiles_grass_var_1_v02.png",
	"res://art/tiles/tiles_grass_var_2_v02.png": "assets/concept/04-env/tiles_grass_var_2_v02.png",
	"res://art/tiles/tiles_grass_var_3_v02.png": "assets/concept/04-env/tiles_grass_var_3_v02.png",
	"res://art/tiles/tiles_grass_var_4_v02.png": "assets/concept/04-env/tiles_grass_var_4_v02.png",
	"res://art/tiles/tiles_soil_var_1_v01.png": "assets/concept/04-env/tiles_soil_var_1_v01.png",
	"res://art/tiles/tiles_soil_var_2_v01.png": "assets/concept/04-env/tiles_soil_var_2_v01.png",
	"res://art/tiles/tiles_ash_var_1_v02.png": "assets/concept/04-env/tiles_ash_var_1_v02.png",
	"res://art/tiles/tiles_ash_var_2_v02.png": "assets/concept/04-env/tiles_ash_var_2_v02.png",
	"res://art/tiles/tiles_ash_var_3_v02.png": "assets/concept/04-env/tiles_ash_var_3_v02.png",
}
const SIZES: Dictionary[String, Vector2i] = {
	"res://art/chars/base_body_v02_walk.png": Vector2i(192, 96),
	"res://art/chars/base_body_v02_idle.png": Vector2i(128, 96),
	"res://art/chars/sig_paladin_shield_v01.png": Vector2i(192, 96),
	"res://art/chars/sig_miner_pickaxe_v01.png": Vector2i(96, 32),
	"res://art/chars/sig_archer_bow_v01.png": Vector2i(96, 32),
	"res://art/chars/sig_cleric_halo_v01.png": Vector2i(12, 5),
	"res://art/chars/sig_herbalist_pouch_v02.png": Vector2i(96, 32),
	"res://art/env/altar_v04.png": Vector2i(48, 57),
	"res://art/env/altar_v04_unlit.png": Vector2i(48, 57),
}

## Expected visible layers per class and direction (south, east, north, west), back to front.
## Written out here on purpose (brief §5.6): back gear behind the body facing south / east / west,
## in front facing north; shield, pouch and halo always in front.
const ORDER: Dictionary[String, Array] = {
	"paladin": [[&"body", &"arm"], [&"body", &"arm"], [&"body", &"arm"], [&"body", &"arm"]],
	"miner": [[&"back", &"body"], [&"back", &"body"], [&"body", &"back"], [&"back", &"body"]],
	"archer": [[&"back", &"body"], [&"back", &"body"], [&"body", &"back"], [&"back", &"body"]],
	"cleric": [[&"body", &"float"], [&"body", &"float"], [&"body", &"float"], [&"body", &"float"]],
	"herbalist": [[&"body", &"waist"], [&"body", &"waist"], [&"body", &"waist"], [&"body", &"waist"]],
}
## v01 -> v02 re-pivot from 03-pixel/prompts.md "발 맞춤" (walk, idle) x (south, east, north).
const PIVOT: Array[Array] = [[4, 3, 4], [5, 2, 3]]
const TICK: float = 1.0 / 60.0


func run() -> Array[String]:
	_check_art()
	_check_anchor_table()
	_check_layer_order()
	_check_mirror()
	_check_layers_follow_anchors()
	_check_animation()
	_check_movement_open_ground()
	_check_movement_bounds()
	_check_movement_altar()
	_check_movement_never_blocked()
	_check_facing()
	_check_spawn_slots()
	await _check_main_scene()
	return failures


func _check_art() -> void:
	for path: String in SIZES:
		var tex: Texture2D = load(path) as Texture2D
		if check(tex != null, "%s loads" % path):
			check_eq(Vector2i(tex.get_size()), SIZES[path], "%s size" % path)
	var repo: String = ProjectSettings.globalize_path("res://").path_join("..")
	var compared: int = 0
	for path: String in ART_SOURCES:
		var src: String = repo.path_join(ART_SOURCES[path])
		if not FileAccess.file_exists(src):
			continue
		compared += 1
		check_eq(FileAccess.get_md5(path), FileAccess.get_md5(src), "%s is a byte copy of %s" % [path, ART_SOURCES[path]])
	if compared == 0:
		note("art provenance: assets/ not found next to game/, byte comparison skipped")
	else:
		note("art provenance: %d/%d files byte-identical to assets/concept" % [compared, ART_SOURCES.size()])


## The committed table equals a fresh measurement of the sheets (R27 rule, actors/rig_measure.gd).
func _check_anchor_table() -> void:
	var t0: int = Time.get_ticks_msec()
	var torso: Array[Array] = RigMeasure.measure_all(RigData.ANCHOR_TORSO)
	var head: Array[Array] = RigMeasure.measure_all(RigData.ANCHOR_HEAD)
	var ms: int = Time.get_ticks_msec() - t0
	check_eq(str(RigAnchors.TORSO), str(torso), "rig_anchors.gd TORSO = measured (run tools/build_rig_anchors.gd)")
	check_eq(str(RigAnchors.HEAD), str(head), "rig_anchors.gd HEAD = measured (run tools/build_rig_anchors.gd)")
	var source: String = FileAccess.get_file_as_string("res://actors/rig_anchors.gd")
	check_eq(source, RigMeasure.anchors_source(torso, head), "rig_anchors.gd is exactly the tool's output")
	for anim: int in RigData.ANIM_NAMES.size():
		for row: int in RigData.ROWS:
			for f: int in RigData.frame_count(anim):
				var t: Vector2i = RigData.anchor(anim, RigData.ANCHOR_TORSO, row, f)
				var h: Vector2i = RigData.anchor(anim, RigData.ANCHOR_HEAD, row, f)
				check(absi(t.x) <= RigData.TORSO_RADIUS and absi(t.y) <= RigData.TORSO_RADIUS, "torso anchor in radius")
				check(absi(h.x) <= RigData.HEAD_RADIUS and absi(h.y) <= RigData.HEAD_RADIUS, "head anchor in radius")
			# Walk frame 0 is the reference itself.
			if anim == RigData.Anim.WALK:
				check_eq(RigData.anchor(anim, RigData.ANCHOR_TORSO, row, 0), Vector2i.ZERO, "walk frame 0 torso = 0")
				check_eq(RigData.anchor(anim, RigData.ANCHOR_HEAD, row, 0), Vector2i.ZERO, "walk frame 0 head = 0")
			check_eq(RigData.shift(anim, row), PIVOT[anim][row], "re-pivot %s %s" % [RigData.ANIM_NAMES[anim],
				RigData.DIR_NAMES[row]])
	# The spike measured the same walk anchors (prototypes/engine-spike/chars/char_data.gd).
	check_eq(str(torso[0]), "[[(0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)], [(0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)], [(0, 0), (0, 1), (0, 1), (0, 0), (0, 0), (0, 0)]]",
		"walk torso anchors = spike")
	check_eq(str(head[0]), "[[(0, 0), (0, 0), (0, -1), (0, -1), (0, -1), (0, -1)], [(0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)], [(0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)]]",
		"walk head anchors = spike")
	note("anchors measured again in %d ms: idle torso %s, idle head %s" % [ms, str(torso[1]), str(head[1])])


func _new_character(class_id: String, dir: int, walking: bool = false) -> Character:
	var c: Character = Character.new()
	c.animate = false
	c.class_id = class_id
	c.direction = dir as RigData.Dir
	c.walking = walking
	return c


func _check_layer_order() -> void:
	for class_id: String in Config.CLASSES:
		var c: Character = _new_character(class_id, RigData.Dir.SOUTH)
		var expected: Array = ORDER[class_id]
		for dir: int in 4:
			c.direction = dir as RigData.Dir
			for walking: bool in [false, true]:
				c.walking = walking
				var cell: Array = expected[dir]
				var want: Array[StringName] = []
				want.assign(cell)
				check_eq(c.draw_order(), want, "%s %s draw order" % [class_id, RigData.DIR_NAMES[dir]])
		c.free()
	# Direction changes after the first refresh re-order the rig (north -> south and back).
	var miner: Character = _new_character("miner", RigData.Dir.NORTH)
	miner.direction = RigData.Dir.SOUTH
	check_eq(miner.draw_order(), [&"back", &"body"] as Array[StringName], "north -> south puts the pickaxe back behind")
	miner.direction = RigData.Dir.NORTH
	check_eq(miner.draw_order(), [&"body", &"back"] as Array[StringName], "south -> north puts the pickaxe in front")
	check(miner.signature_sprite().visible, "signature layer visible")
	var hidden: int = 0
	for slot: StringName in RigData.SLOTS:
		if slot != miner.signature.slot and miner.slots[slot].visible:
			hidden += 1
	check_eq(hidden, 0, "only the class's own signature slot is visible")
	miner.free()
	allow_error("Character: unknown class 'wizard'")
	var bad: Character = _new_character("wizard", RigData.Dir.SOUTH)
	check_eq(bad.class_id, Config.DEFAULT_CLASS, "unknown class keeps the previous class")
	bad.free()


func _check_mirror() -> void:
	for class_id: String in Config.CLASSES:
		var east: Character = _new_character(class_id, RigData.Dir.EAST, true)
		var west: Character = _new_character(class_id, RigData.Dir.WEST, true)
		for f: int in RigData.frame_count(RigData.Anim.WALK):
			east.frame = f
			west.frame = f
			check_eq(west.rig.scale, Vector2(-1, 1), "%s west mirrors the rig" % class_id)
			check_eq(east.rig.scale, Vector2(1, 1), "%s east not mirrored" % class_id)
			check_eq(west.body.region_rect, east.body.region_rect, "%s west uses the east body frame %d" % [class_id, f])
			check_eq(west.signature_sprite().region_rect, east.signature_sprite().region_rect, "%s west layer = east" % class_id)
			check_eq(west.signature_sprite().position, east.signature_sprite().position, "%s west layer pos = east" % class_id)
		for dir: int in [RigData.Dir.SOUTH, RigData.Dir.NORTH]:
			east.direction = dir as RigData.Dir
			check_eq(east.rig.scale, Vector2(1, 1), "%s %s not mirrored" % [class_id, RigData.DIR_NAMES[dir]])
		east.free()
		west.free()
	# The frame is centred on the feet, so the mirror keeps whole pixels: body x -16..16 -> 16..-16.
	check_eq(RigData.FRAME_ORIGIN, Vector2i(16, 32), "frame origin = feet (bottom centre)")


## Every class, animation, direction and frame: body frame region and signature layer position =
## v01 position + re-pivot + anchor (+ halo bob), relative to the feet.
func _check_layers_follow_anchors() -> void:
	var checked: int = 0
	for class_id: String in Config.CLASSES:
		var c: Character = _new_character(class_id, RigData.Dir.SOUTH)
		var sig: RigData.Signature = c.signature
		for anim: int in RigData.ANIM_NAMES.size():
			c.walking = anim == RigData.Anim.WALK
			check_eq(c.anim, anim, "walking selects the %s animation" % RigData.ANIM_NAMES[anim])
			check(c.body.texture == RigData.sheet(anim), "%s uses the %s sheet" % [class_id, RigData.ANIM_NAMES[anim]])
			for dir: int in 4:
				c.direction = dir as RigData.Dir
				var row: int = 1 if dir == RigData.Dir.WEST else dir
				for f: int in RigData.frame_count(anim):
					c.frame = f
					check_eq(c.body.region_rect, Rect2(f * 32, row * 32, 32, 32), "body frame region")
					check_eq(c.body.position, Vector2(-16, -32), "body sits on the feet")
					var bob: int = 0
					if sig.slot == RigData.SLOT_FLOAT and anim == RigData.Anim.WALK and f >= 2 and f <= 4:
						bob = -1
					var anchor: Vector2i = RigData.anchor(anim, sig.anchor, row, f)
					var pivots: Array = PIVOT[anim]
					var pivot: int = pivots[row]
					var want: Vector2i = sig.pos_v01 + Vector2i(0, pivot + bob) + anchor - Vector2i(16, 32)
					check_eq(c.signature_sprite().position, Vector2(want), "%s %s %s frame %d layer position" % [
						class_id, RigData.ANIM_NAMES[anim], RigData.DIR_NAMES[dir], f])
					checked += 1
		# Layer source cell per layout.
		for dir: int in 3:
			c.direction = dir as RigData.Dir
			var region: Rect2 = c.signature_sprite().region_rect
			match class_id:
				"paladin":
					check_eq(region, Rect2(0, dir * 32, 32, 32), "shield: first cell of row %d" % dir)
				"cleric":
					check_eq(region, Rect2(0, 0, 12, 5), "halo: whole image")
				_:
					check_eq(region, Rect2(dir * 32, 0, 32, 32), "%s: column %d" % [class_id, dir])
		c.free()
	check_eq(checked, 5 * (6 + 4) * 4, "layer positions checked")
	# The halo sits right above the head top in walk frame 0 (v02 head top rows: S 4, E 3, N 4).
	var halo: RigData.Signature = RigData.signature_for("cleric")
	for row: int in 3:
		var bottom: int = RigData.layer_frame_pos(halo, RigData.Anim.WALK, row, 0).y + 4
		check_eq(bottom, [3, 2, 3][row], "halo bottom row just above the head (%s)" % RigData.DIR_NAMES[row])


func _check_animation() -> void:
	var c: Character = _new_character("cleric", RigData.Dir.SOUTH)
	check_eq(c.anim, RigData.Anim.IDLE, "starts idle")
	c.advance(Config.IDLE_FRAME_TIME * 0.99)
	check_eq(c.frame, 0, "idle frame holds")
	c.advance(Config.IDLE_FRAME_TIME * 0.02)
	check_eq(c.frame, 1, "idle frame advances after IDLE_FRAME_TIME")
	c.advance(Config.IDLE_FRAME_TIME * 3.0)
	check_eq(c.frame, 0, "idle wraps after 4 frames")
	c.walking = true
	check_eq([c.anim, c.frame], [RigData.Anim.WALK, 0], "walking restarts at walk frame 0")
	c.advance(Config.WALK_FRAME_TIME * 7.0 + 0.001)
	check_eq(c.frame, 1, "walk wraps after 6 frames")
	c.walking = true
	check_eq(c.frame, 1, "setting walking again does not restart")
	c.walking = false
	check_eq([c.anim, c.frame], [RigData.Anim.IDLE, 0], "stopping restarts idle")
	c.free()


func _open_world() -> WorldData:
	return SurfaceGen.generate(Config.DEFAULT_SEED)


func _run_ticks(data: WorldData, pos: Vector2, input: Vector2i, ticks: int) -> Vector2:
	var p: Vector2 = pos
	for i: int in ticks:
		p = Movement.step(data, p, input, TICK)
	return p


func _check_movement_open_ground() -> void:
	var data: WorldData = _open_world()
	var start: Vector2 = Vector2(400, 400)
	for input: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p: Vector2 = _run_ticks(data, start, input, 60)
		check_between(p.distance_to(start), Config.WALK_SPEED - 0.01, Config.WALK_SPEED + 0.01, "1 s straight %s = WALK_SPEED" % input)
		check(is_equal_approx((p - start).normalized().dot(Vector2(input)), 1.0), "moves along %s" % input)
	for input: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var p: Vector2 = _run_ticks(data, start, input, 60)
		check_between(p.distance_to(start), Config.WALK_SPEED - 0.01, Config.WALK_SPEED + 0.01, "1 s diagonal %s = WALK_SPEED" % input)
		check(is_equal_approx(absf(p.x - start.x), absf(p.y - start.y)), "diagonal %s is 45 degrees" % input)
	check_eq(Movement.step(data, start, Vector2i.ZERO, TICK), start, "no input, no move")
	check_eq(Movement.velocity(Vector2i(5, -9)), Movement.velocity(Vector2i(1, -1)), "input is clamped to -1..1")
	check_between(Config.WALK_SPEED, 64.0, 80.0, "walk speed in the M1 range")


func _check_movement_bounds() -> void:
	var data: WorldData = _open_world()
	var w: float = data.size.x * Config.TILE
	var h: float = data.size.y * Config.TILE
	check_eq(_run_ticks(data, Vector2(20, 400), Vector2i(-1, 0), 120).x, Config.FEET_HALF_WIDTH, "stops at the west edge")
	check_eq(_run_ticks(data, Vector2(w - 20, 400), Vector2i(1, 0), 120).x, w - Config.FEET_HALF_WIDTH, "stops at the east edge")
	check_eq(_run_ticks(data, Vector2(400, 60), Vector2i(0, -1), 120).y, Config.HEAD_ROOM_PX, "stops below the north edge (head room)")
	check_eq(_run_ticks(data, Vector2(400, h - 20), Vector2i(0, 1), 120).y, h, "stops at the south edge")
	var corner: Vector2 = _run_ticks(data, Vector2(30, 60), Vector2i(-1, -1), 240)
	check_eq(corner, Vector2(Config.FEET_HALF_WIDTH, Config.HEAD_ROOM_PX), "diagonal into the corner stops in the corner")
	check(Movement.can_stand(data, corner), "corner position is valid")
	check(not Movement.can_stand(data, Vector2(2, 400)), "feet box over the west edge is not valid")
	check(not Movement.can_stand(data, Vector2(400, h + 1)), "feet below the map are not valid")


func _check_movement_altar() -> void:
	var data: WorldData = _open_world()
	var fp: Rect2 = Rect2(Vector2(data.altar_rect.position * Config.TILE), Vector2(data.altar_rect.size * Config.TILE))
	check_eq(fp, Rect2(992, 736, 48, 48), "altar footprint px (3x3 at the map centre)")
	var c: Vector2 = fp.get_center()
	var hw: float = Config.FEET_HALF_WIDTH
	# From each side, walking at the altar stops flush against the footprint.
	check_eq(_run_ticks(data, Vector2(c.x, fp.end.y + 40), Vector2i(0, -1), 120), Vector2(c.x, fp.end.y + Config.FEET_HEIGHT),
		"from the south: feet box top touches the footprint bottom")
	check_eq(_run_ticks(data, Vector2(c.x, fp.position.y - 40), Vector2i(0, 1), 120), Vector2(c.x, fp.position.y),
		"from the north: feet touch the footprint top")
	check_eq(_run_ticks(data, Vector2(fp.position.x - 40, c.y), Vector2i(1, 0), 120), Vector2(fp.position.x - hw, c.y),
		"from the west: feet box touches the footprint")
	check_eq(_run_ticks(data, Vector2(fp.end.x + 40, c.y), Vector2i(-1, 0), 120), Vector2(fp.end.x + hw, c.y),
		"from the east: feet box touches the footprint")
	# Diagonal into the south face slides east along it, then passes the corner.
	var p: Vector2 = Vector2(fp.position.x + 6, fp.end.y + 10)
	var ys: PackedFloat32Array = []
	for i: int in 30:
		p = Movement.step(data, p, Vector2i(1, -1), TICK)
		ys.append(p.y)
	check_eq(p.y, fp.end.y + Config.FEET_HEIGHT, "diagonal slides along the south face")
	check(p.x > fp.position.x + 6 + 20, "and keeps moving east (%.1f)" % p.x)
	# Box edges: touching is allowed, one more pixel is not.
	check(Movement.can_stand(data, Vector2(fp.position.x - hw, c.y)), "touching the footprint is allowed")
	check(not Movement.can_stand(data, Vector2(fp.position.x - hw + 0.5, c.y)), "overlapping by half a pixel is blocked")
	check(not Movement.can_stand(data, c), "standing on the altar is blocked")
	check_eq(Movement.blocked_cells(data, fp).size(), 9, "all 9 footprint cells are blocked")
	# Already inside (bad data): moving out is allowed, not stuck.
	var out: Vector2 = _run_ticks(data, Vector2(fp.position.x + 2, c.y), Vector2i(-1, 0), 30)
	check(out.x < fp.position.x - hw + 0.01, "a player inside the footprint can walk out (%.1f)" % out.x)


## Random walks never end inside the altar or outside the map, and are deterministic.
func _check_movement_never_blocked() -> void:
	var data: WorldData = _open_world()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var inputs: Array[Vector2i] = []
	rng.seed = 7
	for i: int in 3000:
		if i % 20 == 0:
			inputs.append(Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)))
		else:
			inputs.append(inputs[i - 1])
	var runs: Array[PackedVector2Array] = []
	var bad: int = 0
	for run_index: int in 2:
		var p: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0])
		var trail: PackedVector2Array = []
		for input: Vector2i in inputs:
			p = Movement.step(data, p, input, TICK)
			trail.append(p)
			if not Movement.can_stand(data, p):
				bad += 1
		runs.append(trail)
	check_eq(bad, 0, "random walk (2 x 3000 ticks) never stands on the altar or off the map")
	check(runs[0] == runs[1], "same inputs -> same positions (deterministic)")


func _check_facing() -> void:
	var S: int = RigData.Dir.SOUTH
	var E: int = RigData.Dir.EAST
	var N: int = RigData.Dir.NORTH
	var W: int = RigData.Dir.WEST
	var cases: Array[Array] = [
		[Vector2i(0, 0), S, S], [Vector2i(0, 0), W, W],
		[Vector2i(1, 0), S, E], [Vector2i(-1, 0), S, W], [Vector2i(0, -1), E, N], [Vector2i(0, 1), N, S],
		[Vector2i(1, -1), N, N], [Vector2i(1, -1), E, E], [Vector2i(1, -1), S, E], [Vector2i(1, -1), W, E],
		[Vector2i(-1, 1), S, S], [Vector2i(-1, 1), N, W],
	]
	for case: Array in cases:
		var input: Vector2i = case[0]
		var current: int = case[1]
		var want: int = case[2]
		check_eq(Movement.facing_for(input, current), want, "facing for %s from %s" % [input, RigData.DIR_NAMES[current]])
	check_eq(RigData.facing_toward(Vector2(0, 0), Vector2(10, 3)), E, "facing toward east")
	check_eq(RigData.facing_toward(Vector2(0, 0), Vector2(-3, -10)), N, "facing toward north")


func _check_spawn_slots() -> void:
	var data: WorldData = _open_world()
	var zone: SafeZone = SafeZone.for_world(data)
	check_eq(Config.SPAWN_SLOTS.size(), Config.MAX_PLAYERS, "one spawn slot per player (9)")
	var boxes: Array[Rect2] = []
	for i: int in Config.SPAWN_SLOTS.size():
		var p: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[i])
		check(Movement.can_stand(data, p), "spawn slot %d is free ground" % i)
		check(zone.is_in_safe_zone(p), "spawn slot %d is inside the safe zone" % i)
		var box: Rect2 = Rect2(p - Vector2(12, 28), Vector2(24, 28))
		for other: Rect2 in boxes:
			check(not other.intersects(box), "spawn slot %d does not overlap an earlier one" % i)
		boxes.append(box)


func _check_main_scene() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if not check(packed != null, "main.tscn loads"):
		return
	var main: Main = packed.instantiate() as Main
	if not check(main != null, "main.tscn root is Main"):
		return
	add_node(main)
	await await_frames(2)
	var world: GameWorld = main.world
	if not check(world.data != null and main.player != null, "world generated and local player spawned"):
		return
	check(world.camera == null, "main.tscn drops the free camera")
	check(main.camera.is_current(), "player camera is current")
	check(world.entities.y_sort_enabled, "entities are y-sorted")
	check(world.altar != null and world.altar.get_parent() == world.entities, "altar is in the y-sorted entities")
	check_eq(world.altar.position.y, float(world.data.altar_rect.end.y * Config.TILE), "altar sorts by its footprint bottom")
	var player: Player = main.player
	var want_class: String = CliOptions.current().class_id if not CliOptions.current().class_id.is_empty() else Config.DEFAULT_CLASS
	check_eq(player.class_id(), want_class, "local player class from --class (default %s)" % Config.DEFAULT_CLASS)
	check(player.get_parent() == world.entities, "player is in the y-sorted entities")
	check_eq(player.sim_position, world.spawn_point(0), "player on spawn slot 0")
	check_eq(player.position, player.sim_position.round(), "player node on whole pixels")
	var classes: PackedStringArray = [player.class_id()]
	for i: int in main.dummies.size():
		var d: Character = main.dummies[i]
		classes.append(d.class_id)
		check(d.get_parent() == world.entities, "dummy %s is y-sorted" % d.class_id)
		check_eq(d.position, world.spawn_point(i + 1), "dummy %s on slot %d" % [d.class_id, i + 1])
		check_eq(int(d.direction), RigData.facing_toward(d.position, world.data.altar_center_px()), "dummy %s faces the altar" % d.class_id)
		check(not d.walking, "dummy %s stands (idle)" % d.class_id)
		check(world.is_in_safe_zone(d.position), "dummy %s stands in the light" % d.class_id)
	classes.sort()
	var all: PackedStringArray = Config.CLASSES.duplicate()
	all.sort()
	check_eq(classes, all, "all five slice classes are on screen")
	check(world.is_in_safe_zone(player.position), "spawn is safe")
	# Camera centred on the player, whole pixels.
	check_eq(main.camera.get_screen_center_position(), player.position, "camera centred on the player")

	# Keys: move_right for some physics ticks moves the player east, faces east, walks.
	check_eq(Player.read_input(), Vector2i.ZERO, "no keys -> no input")
	var x0: float = player.sim_position.x
	Input.action_press("move_right")
	Input.action_press("move_down")
	check_eq(Player.read_input(), Vector2i(1, 1), "move_right + move_down -> (1, 1)")
	Input.action_release("move_down")
	for i: int in 20:
		await tree.physics_frame
	check(player.character.walking, "walking while the key is held")
	Input.action_release("move_right")
	await tree.physics_frame
	await tree.physics_frame
	var moved: float = player.sim_position.x - x0
	var step: float = Config.WALK_SPEED * TICK
	check(moved > step * 10.0, "move_right moved the player east (%.2f px)" % moved)
	check(absf(moved / step - roundf(moved / step)) < 0.01, "moved a whole number of ticks (%.2f px)" % moved)
	check_eq(player.facing, RigData.Dir.EAST, "faces east")
	check(not player.character.walking, "idle after release")
	await await_frames(1)
	check_eq(main.camera.get_screen_center_position(), player.position, "camera follows the player")
	check_eq(main.camera.global_position, main.camera.global_position.round(), "camera on whole pixels")
	# Camera clamps at the map corners.
	player.local_input = false
	var view: Vector2 = main.camera.get_viewport_rect().size
	var map: Rect2 = world.map_rect_px()
	player.teleport(Vector2(10, 40))
	await await_frames(1)
	check_eq(main.camera.get_screen_center_position(), (view / 2.0).round(), "camera clamps at the north-west corner")
	player.teleport(map.end - Vector2(10, 0))
	await await_frames(1)
	check_eq(main.camera.get_screen_center_position(), (map.end - view / 2.0).round(), "camera clamps at the south-east corner")
	# Safe-zone rule for logic.
	check(not world.is_in_safe_zone(player.position), "far corner is not safe")
	var edge: Vector2 = world.safe_zone.center + Vector2(world.safe_zone.radius, 0)
	check(world.is_in_safe_zone(edge), "exactly on the radius is safe")
	check(not world.is_in_safe_zone(edge + Vector2(0.01, 0)), "just past the radius is not")
	# Evening toggle (F4 action).
	check(world.lighting.evening_on, "evening on by default")
	var press: InputEventAction = InputEventAction.new()
	press.action = &"toggle_evening"
	press.pressed = true
	Input.parse_input_event(press)
	await await_frames(2)
	check(not world.lighting.evening_on and not world.lighting.evening.visible, "toggle_evening turns the evening off")
	check(not world.lighting.altar_light.ground_light.enabled and not world.lighting.altar_light.actor_light.enabled,
		"and the altar light")
	Input.parse_input_event(press)
	await await_frames(2)
	check(world.lighting.evening_on and world.lighting.evening.visible and world.lighting.altar_light.is_lit(),
		"toggle_evening again turns both back on")
	# Respawn with another local class: the other four become dummies.
	main.spawn("cleric")
	check_eq(main.player.class_id(), "cleric", "respawn as cleric")
	var dummy_classes: PackedStringArray = []
	for d: Character in main.dummies:
		dummy_classes.append(d.class_id)
	check_eq(dummy_classes, PackedStringArray(["paladin", "miner", "archer", "herbalist"]), "dummies are the other classes")
	check_eq(world.entities.get_child_count(), 1 + 1 + 4, "entities: altar + player + 4 dummies (old ones freed)")
