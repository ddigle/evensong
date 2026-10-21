extends "res://tests/base_test.gd"
## Aim (M2a): sectors (all 8, the 22.5° boundaries), the target tile next to the feet tile (tile
## edges included), the 4-way facing toward the mouse, the root window stretch (480x270 viewport,
## integer scale, aspect expand: view size, scale, black bars, window -> viewport) against the engine,
## and in main.tscn: the mouse at the viewport edges and corners (and over the black bars) of several
## window sizes, with the camera centred and clamped at a map corner, gives the aim point, sector,
## target tile, facing and marker the rules say. Walking without aim input keeps the M1 facing.

const S: int = RigData.Dir.SOUTH
const E: int = RigData.Dir.EAST
const N: int = RigData.Dir.NORTH
const W: int = RigData.Dir.WEST
## Window sizes: 16:9 at 4x and 2x, narrower (taller view), a hair wider than 16:9 (black bars at
## scale 2), an odd view height, portrait.
const WINDOWS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1000, 700), Vector2i(1366, 768),
	Vector2i(1000, 703), Vector2i(500, 1000)]


func run() -> Array[String]:
	_check_sectors()
	_check_target_cells()
	_check_facing()
	_check_marker_pixels()
	await _check_stretch()
	await _check_main_aim()
	_check_walk_facing_without_aim()
	return failures


func _check_sectors() -> void:
	var names: PackedStringArray = []
	for i: int in 8:
		var a: float = i * PI / 4.0
		var v: Vector2 = Vector2(cos(a), sin(a)) * 50.0
		check_eq(Aim.sector(v), i, "%d° is %s" % [i * 45, Aim.SECTOR_NAMES[i]])
		# Just inside both boundaries of the sector (+/-22.4°) and just outside (+/-22.6°).
		for side: float in [-1.0, 1.0]:
			var inside: Vector2 = Vector2.from_angle(a + side * deg_to_rad(22.4)) * 50.0
			var outside: Vector2 = Vector2.from_angle(a + side * deg_to_rad(22.6)) * 50.0
			check_eq(Aim.sector(inside), i, "%d° %+.1f° stays %s" % [i * 45, side * 22.4, Aim.SECTOR_NAMES[i]])
			check_eq(Aim.sector(outside), posmod(i + int(side), 8), "%d° %+.1f° leaves %s" % [i * 45, side * 22.6,
				Aim.SECTOR_NAMES[i]])
		names.append(Aim.SECTOR_NAMES[i])
	check_eq(names, PackedStringArray(["east", "south-east", "south", "south-west", "west", "north-west", "north",
		"north-east"]), "sector order: east, then clockwise on screen (y down)")
	check_eq(Aim.SECTOR_OFFSETS, [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)] as Array[Vector2i], "sector -> neighbour tile")
	check_eq(Aim.sector(Vector2.ZERO, Aim.Sector.NORTH_WEST), Aim.Sector.NORTH_WEST, "mouse on the feet keeps the sector")
	check_eq(Aim.sector(Vector2(0.001, 0.0)), Aim.Sector.EAST, "a tiny offset still aims")
	check_eq(Aim.sector(Vector2(-300, 1)), Aim.Sector.WEST, "far west, a pixel low")


func _check_target_cells() -> void:
	var feet_list: Array[Vector2] = [Vector2(100.5, 200.25), Vector2(16.0, 32.0), Vector2(15.999, 31.999), Vector2(0.5, 0.5)]
	var cells: Array[Vector2i] = [Vector2i(6, 12), Vector2i(1, 2), Vector2i(0, 1), Vector2i(0, 0)]
	for i: int in feet_list.size():
		check_eq(Aim.cell_of(feet_list[i]), cells[i], "feet %s stand on tile %s" % [feet_list[i], cells[i]])
		for s: int in 8:
			check_eq(Aim.target_cell(feet_list[i], s), cells[i] + Aim.SECTOR_OFFSETS[s], "target %s of feet %s" % [
				Aim.SECTOR_NAMES[s], feet_list[i]])
	check_eq(Aim.target_cell(Vector2(8, 8), Aim.Sector.NORTH_WEST), Vector2i(-1, -1), "off the map is reported as is")


func _check_facing() -> void:
	var cases: Array[Array] = [
		[Vector2(10, 0), N, E], [Vector2(-10, 0), N, W], [Vector2(0, 10), N, S], [Vector2(0, -10), S, N],
		[Vector2(10, 9), N, E], [Vector2(9, 10), N, S], [Vector2(-10, -9), S, W], [Vector2(-9, -10), S, N],
		[Vector2(10, 10), E, S], [Vector2(-10, -10), E, N], [Vector2.ZERO, W, W],
	]
	for c: Array in cases:
		var v: Vector2 = c[0]
		var current: int = c[1]
		var want: int = c[2]
		check_eq(Aim.facing(v, current), want, "facing toward %s (from %s)" % [v, RigData.DIR_NAMES[current]])
	# Facing and sector agree on the axes.
	for s: int in [Aim.Sector.EAST, Aim.Sector.SOUTH, Aim.Sector.WEST, Aim.Sector.NORTH]:
		var v: Vector2 = Vector2(Aim.SECTOR_OFFSETS[s])
		check_eq(Aim.facing(v, S), [E, -1, S, -1, W, -1, N][s], "axis sector %s faces that way" % Aim.SECTOR_NAMES[s])


func _check_marker_pixels() -> void:
	var px: Array[Array] = TargetMarker.pixels()
	var gold: Array = px[0]
	var edge: Array = px[1]
	check_eq(gold.size(), 4 * (2 * TargetMarker.ARM - 1), "gold: four L brackets of arm %d" % TargetMarker.ARM)
	check_eq(edge.size(), 4 * (2 * TargetMarker.ARM - 1), "dark inner edge of the same size")
	for p: Vector2i in gold:
		check(p.x >= 0 and p.y >= 0 and p.x < Config.TILE and p.y < Config.TILE, "gold pixel %s inside the tile" % p)
		check(not edge.has(p), "gold and edge do not overlap at %s" % p)
	for p: Vector2i in edge:
		check(p.x >= 1 and p.y >= 1 and p.x < Config.TILE - 1 and p.y < Config.TILE - 1, "edge pixel %s inside the gold" % p)
	check_has(gold, Vector2i(0, 0), "corner pixel")
	check_has(gold, Vector2i(15, 15), "opposite corner pixel")
	for c: Color in [TargetMarker.GOLD, TargetMarker.EDGE]:
		check(c.r8 >= c.b8 and c.r8 >= c.g8, "marker colour %s is warm (no cool grey)" % c.to_html(false))


## The engine's stretch of the root window equals Aim's arithmetic: viewport size, scale and black
## bars, and a mouse event's window position -> viewport position.
func _check_stretch() -> void:
	var root: Window = tree.root
	var old: Vector2i = root.size
	var probe: Node2D = add_node(Node2D.new()) as Node2D
	for win: Vector2i in WINDOWS:
		root.size = win
		await await_frames(2)
		var view: Vector2i = Aim.view_size(win)
		check_eq(Vector2i(root.get_visible_rect().size), view, "window %s: viewport size" % win)
		var xf: Transform2D = root.get_final_transform()
		check_eq(xf.x.x, float(Aim.view_scale(win)), "window %s: integer scale" % win)
		check_eq(xf.origin, Aim.view_margin(win), "window %s: black bars" % win)
		check_eq(Aim.view_scale(win), maxi(1, mini(win.x / view.x, win.y / view.y)), "scale is the largest whole fit")
		check(view.y == Config.VIEW_SIZE.y or view.x == Config.VIEW_SIZE.x, "expand keeps one base side (%s)" % view)
		check(view.x >= Config.VIEW_SIZE.x and view.y >= Config.VIEW_SIZE.y, "expand never shrinks the view (%s)" % view)
		for p: Vector2 in [Vector2.ZERO, Aim.view_margin(win), Vector2(win) - Vector2.ONE, Vector2(win) / 2.0, Vector2(3, 7)]:
			_move_mouse(p)
			await await_frames(1)
			check_eq(root.get_mouse_position(), Aim.window_to_view(p, win), "window %s: mouse at %s -> viewport" % [win, p])
			check_eq(probe.get_global_mouse_position(), root.canvas_transform.affine_inverse() * Aim.window_to_view(p, win),
				"window %s: mouse at %s -> world (no camera)" % [win, p])
	# Known values (the probes in README "측정"): 1000x700 -> 480x336 at 2x with bars (20, 14).
	check_eq(Aim.view_size(Vector2i(1000, 700)), Vector2i(480, 336), "1000x700 -> 480x336")
	check_eq(Aim.view_margin(Vector2i(1000, 700)), Vector2(20, 14), "1000x700 bars")
	check_eq(Aim.view_size(Vector2i(1366, 768)), Vector2i(480, 270), "1366x768 -> 480x270")
	check_eq(Aim.view_margin(Vector2i(1366, 768)), Vector2(203, 114), "1366x768 bars")
	check_eq(Aim.window_to_view(Vector2(1919, 1079), Vector2i(1920, 1080)), Vector2(479.75, 269.75), "4x: last window pixel")
	root.size = old
	await await_frames(2)
	check_eq(Vector2i(root.get_visible_rect().size), Aim.view_size(old), "window size restored")


## main.tscn: for each window size, with the player where the camera centres it and near the map's
## north-west corner (camera clamped), the mouse at the 8 edge points and corners of the viewport and
## over a black bar: aim point = the engine's canvas transform of the viewport point, sector / tile /
## facing = the rules, the marker on the tile. All 8 sectors are seen at the edges of a centred view.
func _check_main_aim() -> void:
	var root: Window = tree.root
	var old: Vector2i = root.size
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var player: Player = main.player
	if not check(player != null and player.controls, "main has a local player with controls"):
		return
	var spawn: Vector2 = player.sim_position
	var checked: int = 0
	for win: Vector2i in WINDOWS:
		root.size = win
		for place: int in 2:
			player.teleport(spawn if place == 0 else Vector2(40, 60))
			await await_frames(2)
			var view: Vector2i = Aim.view_size(win)
			var margin: Vector2 = Aim.view_margin(win)
			var scale: float = float(Aim.view_scale(win))
			var last: Vector2 = Vector2(view) - Vector2.ONE / scale  # the last viewport pixel's window corner
			var seen: Dictionary[int, bool] = {}
			var points: Array[Vector2] = []
			for vy: float in [0.0, last.y / 2.0, last.y]:
				for vx: float in [0.0, last.x / 2.0, last.x]:
					if vx != last.x / 2.0 or vy != last.y / 2.0:
						points.append(margin + Vector2(vx, vy) * scale)
			points.append(Vector2(1, 1))  # over the top-left black bar (or the corner when there is none)
			for wp: Vector2 in points:
				_move_mouse(wp)
				await tree.physics_frame
				await tree.physics_frame
				var vp: Vector2 = Aim.window_to_view(wp, win)
				var want_world: Vector2 = main.get_viewport().canvas_transform.affine_inverse() * vp
				var cam_center: Vector2 = main.camera.get_screen_center_position()
				var naive: Vector2 = cam_center - Vector2(view) / 2.0 + vp
				var label: String = "window %s, player %s, mouse %s" % [win, "centred" if place == 0 else "at the NW corner", wp]
				check(want_world.distance_to(naive) <= 0.5, "%s: camera view = centre - view / 2 (%s vs %s)" % [label, want_world, naive])
				check_eq(player.aim_point, want_world, "%s: aim point" % label)
				var to_mouse: Vector2 = player.aim_point - player.sim_position
				var sector: int = Aim.sector(to_mouse)
				check_eq(player.aim_sector, sector, "%s: sector" % label)
				check_eq(player.aim_cell, Aim.cell_of(player.sim_position) + Aim.SECTOR_OFFSETS[sector], "%s: target tile" % label)
				check_eq(player.facing, Aim.facing(to_mouse, player.facing), "%s: faces the mouse" % label)
				check(player.aim_active, "%s: aiming after the mouse moved" % label)
				check(main.marker.visible and main.marker.position == Vector2(player.aim_cell * Config.TILE), "%s: marker on the tile" % label)
				if place == 0:
					seen[sector] = true
				checked += 1
			if place == 0 and _centred(main, player):
				check_eq(seen.size(), 8, "window %s: the viewport edges reach all 8 sectors" % win)
	note("main aim: %d mouse positions over %d window sizes (view sizes %s)" % [checked, WINDOWS.size(), str(WINDOWS.map(
		func(w: Vector2i) -> Vector2i: return Aim.view_size(w)))])
	# Off the map: the marker hides.
	root.size = old
	player.teleport(Vector2(6, 60))
	player.test_aim = Vector2(-20, 0)
	await tree.physics_frame
	await tree.physics_frame
	await await_frames(1)
	check_eq(player.aim_cell, Vector2i(-1, 3), "aiming west off the map")
	check(not main.marker.visible, "no marker off the map")
	player.test_aim = null
	await await_frames(2)


func _centred(main: Main, player: Player) -> bool:
	return main.camera.get_screen_center_position() == player.position


## Without aim input the controls tick walks and faces exactly like apply_input (M1); with aim input
## the facing follows the mouse while walking the other way.
func _check_walk_facing_without_aim() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var a: Player = Player.new()
	var b: Player = Player.new()
	var start: Vector2 = data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0])
	a.setup(data, "miner", start)
	b.setup(data, "miner", start)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var input: Vector2i = Vector2i.ZERO
	var same: int = 0
	for t: int in 600:
		if t % 15 == 0:
			input = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		a.apply_input(input, Config.NET_TICK)
		b.tick_controls(input, start + Vector2(-500, -500), false, false, false, Config.NET_TICK)
		if a.sim_position == b.sim_position and a.facing == b.facing and a.walking == b.walking:
			same += 1
	check_eq(same, 600, "600 ticks without aim input: same position, facing and walking as M1 apply_input")
	b.tick_controls(Vector2i(1, 0), b.sim_position + Vector2(-50, 3), true, false, false, Config.NET_TICK)
	check_eq(b.facing, W, "aiming west while walking east faces west")
	check(b.walking, "and walks")
	b.tick_controls(Vector2i(1, 0), b.sim_position + Vector2(-50, 3), false, false, false, Config.NET_TICK)
	check_eq(b.facing, E, "aim input gone: faces the walking direction again")
	b.tick_controls(Vector2i.ZERO, b.sim_position + Vector2(0, -40), false, true, true, Config.NET_TICK)
	check_eq(b.facing, N, "holding use aims even without mouse movement")
	a.free()
	b.free()


static func _move_mouse(window_pos: Vector2) -> void:
	var ev: InputEventMouseMotion = InputEventMouseMotion.new()
	ev.position = window_pos
	ev.global_position = window_pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
