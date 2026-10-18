extends SceneTree
## Light spike capture: renders res://light/light_demo.tscn with the real renderer, saves PNGs and
## measured numbers, then a frame-time benchmark. Opens a window for a few seconds; never --headless.
##
##   GODOT="C:/dev/tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe"
##   timeout 300 "$GODOT" --path prototypes/engine-spike --script res://light/capture_light.gd < /dev/null
##   ... -- --out=shots         output folder, relative to the project folder (default: shots)
##   ... -- --no-bench          skip the benchmark
##   ... -- --bench-frames=600  frames per benchmark run
##   ... -- --no-images         numbers only (nothing saved except light_metrics<tag>.json)
##   ... -- --tag=_gl           file-name suffix, e.g. with --rendering-method gl_compatibility
##
## Files (in <out>/): light_<variant><tag>.png at the 480x270 base size, light_<variant>_1080<tag>.png
## (= 4x integer scale, exactly what a 1920x1080 screen shows with the project's viewport stretch),
## light_dither_1080_native<tag>.png (2D drawn at 1920x1080 instead, for comparison),
## light_edges<tag>.png, light_altar_normals<tag>.png, light_actor_split<tag>.png, light_metrics<tag>.json.
## stdout: SPIKE_LIGHT_SHOT / SPIKE_LIGHT_METRIC / SPIKE_LIGHT_BENCH lines, exit code 0 when done.

const LightGen := preload("res://light/light_gen.gd")
const DemoScript := preload("res://light/light_demo.gd")
const DEMO: PackedScene = preload("res://light/light_demo.tscn")
const GRASS: Texture2D = preload("res://art/light/tiles_grass_base_v02.png")

const BIG: Vector2i = Vector2i(1920, 1080)
## Settings every variant starts from (read from a fresh demo instance).
const KEYS: PackedStringArray = [
	"edge_mode", "evening_enabled", "altar_light_enabled", "lantern_enabled", "normal_maps_enabled",
	"flame_mode", "shadows_enabled", "occluder_cull_mode", "safe_radius_tiles", "edge_band_px",
	"actor_light_split",
]

## Sample points in base pixels (see light_demo.tscn): light centre (240,124), R = 112, band 16.
const P_INSIDE: Vector2i = Vector2i(240, 200)     # grass, light core
const P_OUTSIDE: Vector2i = Vector2i(16, 200)     # same grass texel, outside the zone
const P_SHADOW: Vector2i = Vector2i(150, 136)     # ground behind the wall (from the light)
const P_SHADOW_REF: Vector2i = Vector2i(150, 110) # ground beside the shadow, same distance
const R_WALL_FRONT: Rect2i = Rect2i(178, 129, 28, 13)
const R_WALL_TOP: Rect2i = Rect2i(178, 114, 28, 13)
const R_ALTAR_TOP: Rect2i = Rect2i(220, 112, 40, 26)
const R_ALTAR_NORTH: Rect2i = Rect2i(220, 110, 40, 3)
const R_ALTAR_FRONT: Rect2i = Rect2i(218, 145, 44, 6)
const ALTAR_ORIGIN: Vector2i = Vector2i(216, 104)  # world position of altar image pixel (0,0)

var out_dir: String = ""
var tag: String = ""
var save_images: bool = true
var metrics: Dictionary = {}
var demo: DemoScript
var defaults: Dictionary = {}
var shots: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	if DisplayServer.get_name() == "headless":
		printerr("capture_light: needs a renderer. Run without --headless in a desktop session.")
		quit(2)
		return
	tag = str(args.get("tag", ""))
	save_images = not args.has("no-images")
	out_dir = str(args.get("out", "shots"))
	if out_dir.is_relative_path():
		out_dir = ProjectSettings.globalize_path("res://").path_join(out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	metrics["renderer"] = "%s / %s / %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()]
	metrics["godot"] = Engine.get_version_info().string
	print("SPIKE_LIGHT renderer=%s" % metrics["renderer"])

	demo = DEMO.instantiate() as DemoScript
	demo.animate = false
	root.add_child(demo)
	await _frames(2)
	for key: String in KEYS:
		defaults[key] = demo.get(key)

	await _capture_variants()
	await _capture_native_1080()
	demo.queue_free()
	await _frames(2)
	await _light_limit_probe()
	if not args.has("no-bench"):
		await _benchmark(int(str(args.get("bench-frames", "600"))))

	var f: FileAccess = FileAccess.open(out_dir.path_join("light_metrics%s.json" % tag), FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics, "  ", false) + "\n")
	f.close()
	print("SPIKE_LIGHT done out=%s" % out_dir)
	quit(0)


# --- variants ------------------------------------------------------------------------------------

func _render(overrides: Dictionary) -> Image:
	for key: String in defaults:
		demo.set(key, defaults[key])
	for key: String in overrides:
		demo.set(key, overrides[key])
	demo.apply_settings()
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _capture_variants() -> void:
	var dither: int = LightGen.Edge.DITHER
	var day: Image = await _render({"evening_enabled": false, "altar_light_enabled": false, "lantern_enabled": false})
	_save(day, "day", false)
	var images: Dictionary = {}
	for edge_name: String in LightGen.EDGE_NAMES:
		var edge: int = LightGen.edge_from_name(edge_name)
		var img: Image = await _render({"edge_mode": edge})
		images[edge_name] = img
		_save(img, edge_name, edge == dither or edge == LightGen.Edge.HARD)
		_edge_metrics(edge_name, img, day)
	var main: Image = images["dither"]

	# light inside / outside, flames, shadow, wall, altar
	metrics["inside_rgb_factor"] = _rgb_factor(main, day, P_INSIDE)
	metrics["outside_rgb_factor"] = _rgb_factor(main, day, P_OUTSIDE)
	metrics["flame_unshaded"] = _flame_metrics(main)
	metrics["shadow_factor"] = _ratio(main, day, P_SHADOW)
	metrics["shadow_ref_factor"] = _ratio(main, day, P_SHADOW_REF)
	metrics["altar_top_factor_normals_on"] = _mean_ratio(main, day, R_ALTAR_TOP)
	metrics["altar_front_factor_normals_on"] = _mean_ratio(main, day, R_ALTAR_FRONT)
	var plain_hard: Image = await _render({"edge_mode": LightGen.Edge.HARD, "shadows_enabled": false,
		"lantern_enabled": false})
	metrics["safe_zone_rule_matches_picture"] = _zone_rule_check(plain_hard, day)

	var flat: Image = await _render({"normal_maps_enabled": false})
	metrics["altar_top_factor_normals_off"] = _mean_ratio(flat, day, R_ALTAR_TOP)
	metrics["altar_front_factor_normals_off"] = _mean_ratio(flat, day, R_ALTAR_FRONT)
	_save_altar_normals(flat, main)

	# flames with only the evening darkness (no altar light): unshaded must keep the painted colours
	var dark_unshaded: Image = await _render({"altar_light_enabled": false, "lantern_enabled": false})
	metrics["flame_unshaded_no_light"] = _flame_metrics(dark_unshaded)
	var dark_shaded: Image = await _render({"altar_light_enabled": false, "lantern_enabled": false,
		"flame_mode": DemoScript.FlameMode.SHADED})
	metrics["flame_shaded_no_light"] = _flame_metrics(dark_shaded)

	var culls: Dictionary = {}
	for cull: int in [OccluderPolygon2D.CULL_DISABLED, OccluderPolygon2D.CULL_CLOCKWISE,
			OccluderPolygon2D.CULL_COUNTER_CLOCKWISE]:
		var img: Image = await _render({"occluder_cull_mode": cull})
		culls[str(cull)] = {
			"wall_front_factor": _mean_ratio(img, day, R_WALL_FRONT),
			"wall_top_factor": _mean_ratio(img, day, R_WALL_TOP),
			"ground_behind_factor": _ratio(img, day, P_SHADOW),
		}
	metrics["occluder_cull_0_disabled_1_cw_2_ccw"] = culls
	var no_shadow: Image = await _render({"shadows_enabled": false})
	metrics["wall_front_factor_shadows_off"] = _mean_ratio(no_shadow, day, R_WALL_FRONT)

	# characters on the dithered edge: own hard-edged light (split, default) vs the world light
	var shared: Image = await _render({"actor_light_split": false})
	var split_flips: Dictionary = _walker_flips(main, day)
	var shared_flips: Dictionary = _walker_flips(shared, day)
	metrics["walker_on_dither_edge"] = {"split": split_flips, "shared": shared_flips}
	print("SPIKE_LIGHT_METRIC walker_on_dither_edge split=%s shared=%s" % [JSON.stringify(split_flips), JSON.stringify(shared_flips)])
	_save_actor_split(shared, main)

	await _normal_orientation_probe(day)
	_save_edges(images)


func _edge_metrics(edge_name: String, img: Image, day: Image) -> void:
	var r: int = demo.safe_radius_px()
	var band: int = demo.edge_band_px
	var c: Vector2i = Vector2i(demo.altar_light.global_position.round())
	var profile: Array[float] = []
	for x: int in range(c.x + r - band - 2, c.x + r + 3):
		profile.append(snappedf(_ratio(img, day, Vector2i(x, c.y)), 0.01))
	var outside: float = _ratio(img, day, P_OUTSIDE)
	var last_lit: int = -1
	for x: int in range(c.x, c.x + r + 8):
		if _ratio(img, day, Vector2i(x, c.y)) > outside * 1.15:
			last_lit = x
	# distinct light levels on the ground within the edge band (east half, grass only)
	var levels: Dictionary = {}
	for y: int in range(c.y - 40, c.y + 41):
		for x: int in range(c.x + r - band - 1, c.x + r + 2):
			var p: Vector2i = Vector2i(x, y)
			var d: float = Vector2(p).distance_to(Vector2(c))
			if d < float(r - band) - 0.5 or d > float(r) + 1.5:
				continue
			if LightGen.luma(day.get_pixelv(p)) < 0.25:
				continue  # dark pixels: 8-bit rounding makes the ratio noisy
			levels[snappedf(_ratio(img, day, p), 0.05)] = true
	var keys: Array = levels.keys()
	keys.sort()
	metrics["edge_%s" % edge_name] = {
		"profile_east_from_r_minus_band_minus_2": profile,
		"last_lit_px_east": last_lit - c.x + 1,
		"levels_in_band": keys,
	}
	print("SPIKE_LIGHT_METRIC edge=%s radius_px=%d last_lit=%d levels=%d profile=%s" % [
		edge_name, r, last_lit - c.x + 1, keys.size(), str(profile)])


## Pixels the hard-edge picture lights must be the pixels is_in_safe_zone() accepts (centre row/column).
func _zone_rule_check(hard: Image, day: Image) -> Dictionary:
	var c: Vector2i = Vector2i(demo.altar_light.global_position.round())
	var outside: float = _ratio(hard, day, P_OUTSIDE)
	var mismatches: int = 0
	var checked: int = 0
	var where: Array[String] = []
	for i: int in range(-130, 131):
		for p: Vector2i in [Vector2i(c.x + i, c.y + 30), Vector2i(c.x + 60, c.y + i)]:
			if p.x < 0 or p.y < 0 or p.x >= hard.get_width() or p.y >= hard.get_height():
				continue
			if LightGen.luma(day.get_pixelv(p)) < 0.25:
				continue  # outlines/hair: 8-bit rounding makes the ratio noisy
			var lit: bool = _ratio(hard, day, p) > outside * 1.15
			var rule: bool = demo.is_in_safe_zone(Vector2(p) + Vector2(0.5, 0.5))
			checked += 1
			if lit != rule:
				mismatches += 1
				where.append("%s d=%.2f lit=%s" % [p, (Vector2(p) + Vector2(0.5, 0.5)).distance_to(Vector2(c)), lit])
	print("SPIKE_LIGHT_METRIC zone_rule checked=%d mismatches=%d %s" % [checked, mismatches, str(where)])
	return {"checked": checked, "mismatches": mismatches, "where": where}


func _flame_metrics(img: Image) -> Dictionary:
	var flame: Image = demo.flame_image
	var max_diff: int = 0
	var min_luma: float = 999.0
	var n: int = 0
	for y: int in flame.get_height():
		for x: int in flame.get_width():
			var src: Color = flame.get_pixel(x, y)
			if src.a < 0.5:
				continue
			var got: Color = img.get_pixel(ALTAR_ORIGIN.x + x, ALTAR_ORIGIN.y + y)
			n += 1
			max_diff = maxi(max_diff, maxi(absi(got.r8 - src.r8), maxi(absi(got.g8 - src.g8), absi(got.b8 - src.b8))))
			min_luma = minf(min_luma, LightGen.luma(got) * 255.0)
	print("SPIKE_LIGHT_METRIC flames n=%d max_channel_diff=%d min_luma=%.0f" % [n, max_diff, min_luma])
	return {"pixels": n, "max_channel_diff_vs_source": max_diff, "min_luma": snappedf(min_luma, 0.1)}


## Lit/unlit flips between neighbouring opaque walker pixels along each row. A dithered light on a
## sprite shows up as many flips (checkerboard on the face), a hard edge as at most one per row.
func _walker_flips(img: Image, day: Image) -> Dictionary:
	var w: Sprite2D = demo.walker
	var sheet: Image = LightGen.to_rgba8(w.texture.get_image())
	var fw: int = sheet.get_width() / w.hframes
	var fh: int = sheet.get_height() / w.vframes
	var top_left: Vector2i = Vector2i((w.global_position + w.offset).round())
	var flips: int = 0
	var lit: int = 0
	var counted: int = 0
	for y: int in fh:
		var prev: int = -1
		for x: int in fw:
			var sx: int = (fw - 1 - x) if w.flip_h else x
			if sheet.get_pixel(w.frame_coords.x * fw + sx, w.frame_coords.y * fh + y).a < 0.5:
				continue
			var p: Vector2i = top_left + Vector2i(x, y)
			if LightGen.luma(day.get_pixelv(p)) < 0.15:
				continue  # outline pixels: 8-bit rounding makes the ratio noisy
			var on: int = 1 if _ratio(img, day, p) > 0.6 else 0
			counted += 1
			lit += on
			if prev >= 0 and on != prev:
				flips += 1
			prev = on
	return {"pixels": counted, "lit": lit, "row_flips": flips,
		"distance_px": snappedf(w.global_position.distance_to(demo.altar_light.global_position), 0.1)}


## A small white light north, then south of the altar (altar light, lantern off). With correct
## normals the north probe lights the north rim more than the front face and the south probe the reverse.
func _normal_orientation_probe(day: Image) -> void:
	var probe: PointLight2D = PointLight2D.new()
	probe.texture = ImageTexture.create_from_image(LightGen.safe_zone_light_image(72, LightGen.Edge.HARD, 0))
	probe.height = 12.0
	probe.energy = 0.6
	demo.world.add_child(probe)
	var result: Dictionary = {}
	for side: String in ["north", "south"]:
		probe.position = Vector2(240, 98) if side == "north" else Vector2(240, 166)
		for normals: bool in [true, false]:
			var img: Image = await _render({"altar_light_enabled": false, "lantern_enabled": false,
				"normal_maps_enabled": normals})
			result["%s_normals_%s" % [side, "on" if normals else "off"]] = {
				"north_rim": _mean_ratio(img, day, R_ALTAR_NORTH),
				"front_face": _mean_ratio(img, day, R_ALTAR_FRONT),
			}
	probe.queue_free()
	metrics["normal_probe"] = result
	print("SPIKE_LIGHT_METRIC normal_probe %s" % JSON.stringify(result))


# --- 1080p drawn natively (SubViewport, like stretch mode canvas_items) ----------------------------

func _capture_native_1080() -> void:
	var sv: SubViewport = SubViewport.new()
	sv.size = BIG
	sv.size_2d_override = Vector2i(480, 270)
	sv.size_2d_override_stretch = true
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sv.snap_2d_transforms_to_pixel = true
	sv.snap_2d_vertices_to_pixel = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var second: DemoScript = DEMO.instantiate() as DemoScript
	second.animate = false
	sv.add_child(second)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img: Image = sv.get_texture().get_image()
	if save_images:
		_write(img, "light_dither_1080_native%s.png" % tag)
	sv.queue_free()


# --- how many lights reach one canvas item ---------------------------------------------------------

func _light_limit_probe() -> void:
	var result: Dictionary = {}
	# sprite: one 480x270 Sprite2D. tilemap: TileMapLayer, default rendering_quadrant_size 16
	# (one canvas item per 16x16 tiles). tilemap_q4: quadrant size 4 (64x64 px items).
	# sprites_per_light: a 16x16 sprite under each light (30 separate items).
	for kind: String in ["sprite", "tilemap", "tilemap_q4", "sprites_per_light"]:
		var holder: Node2D = Node2D.new()
		root.add_child(holder)
		var cm: CanvasModulate = CanvasModulate.new()
		cm.color = Color(0.2, 0.2, 0.2)
		holder.add_child(cm)
		if kind == "sprite":
			var s: Sprite2D = Sprite2D.new()
			s.texture = GRASS
			s.centered = false
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, 480, 270)
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			holder.add_child(s)
		elif kind == "sprites_per_light":
			for j: int in 5:
				for i: int in 6:
					var small: Sprite2D = Sprite2D.new()
					small.texture = GRASS
					small.position = Vector2(24 + i * 40, 24 + j * 48)
					holder.add_child(small)
		else:
			var layer: TileMapLayer = TileMapLayer.new()
			var ts: TileSet = TileSet.new()
			var src: TileSetAtlasSource = TileSetAtlasSource.new()
			src.texture = GRASS
			src.texture_region_size = Vector2i(16, 16)
			src.create_tile(Vector2i.ZERO)
			var sid: int = ts.add_source(src)
			layer.tile_set = ts
			if kind == "tilemap_q4":
				layer.rendering_quadrant_size = 4
			for y: int in 17:
				for x: int in 30:
					layer.set_cell(Vector2i(x, y), sid, Vector2i.ZERO)
			holder.add_child(layer)
		await _frames(2)
		await RenderingServer.frame_post_draw
		var dark: Image = root.get_texture().get_image()
		var tex: ImageTexture = ImageTexture.create_from_image(LightGen.safe_zone_light_image(6, LightGen.Edge.HARD, 0))
		var spots: Array[Vector2i] = []
		# 30 lights inside one 256x256 area = one TileMapLayer rendering quadrant (16x16 tiles)
		for j: int in 5:
			for i: int in 6:
				var p: Vector2i = Vector2i(24 + i * 40, 24 + j * 48)
				spots.append(p)
				var l: PointLight2D = PointLight2D.new()
				l.texture = tex
				l.position = Vector2(p)
				l.energy = 1.0
				holder.add_child(l)
		await _frames(3)
		await RenderingServer.frame_post_draw
		var lit_img: Image = root.get_texture().get_image()
		var lit: int = 0
		for p: Vector2i in spots:
			if LightGen.luma(lit_img.get_pixelv(p)) > LightGen.luma(dark.get_pixelv(p)) * 2.0:
				lit += 1
		result[kind] = {"lights": spots.size(), "lit": lit}
		print("SPIKE_LIGHT_METRIC light_limit item=%s lights=%d lit=%d" % [kind, spots.size(), lit])
		if save_images and kind == "tilemap":
			_save(lit_img, "limit_probe", false)
		holder.queue_free()
		await _frames(2)
	metrics["light_limit_one_item"] = result


# --- benchmark -----------------------------------------------------------------------------------

func _benchmark(frames: int) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var bench_demo: DemoScript = DEMO.instantiate() as DemoScript
	bench_demo.animate = true
	root.add_child(bench_demo)
	var results: Dictionary = {}
	results["scene"] = await _bench_run(frames, vp)
	var extra: Node2D = Node2D.new()
	bench_demo.world.add_child(extra)
	var torch_tex: ImageTexture = ImageTexture.create_from_image(LightGen.safe_zone_light_image(48, LightGen.Edge.DITHER, 8))
	var block_tex: ImageTexture = ImageTexture.create_from_image(LightGen.wall_block_image())
	for i: int in 30:
		var block: Sprite2D = Sprite2D.new()
		block.texture = block_tex
		block.centered = false
		block.offset = Vector2(-16, -32)
		block.position = Vector2(24 + (i % 10) * 48, 60 + (i / 10) * 80)
		var occ: LightOccluder2D = LightOccluder2D.new()
		var poly: OccluderPolygon2D = OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 0), Vector2(-16, 0)])
		occ.occluder = poly
		block.add_child(occ)
		extra.add_child(block)
	var lights: Array[PointLight2D] = []
	for i: int in 64:
		var l: PointLight2D = PointLight2D.new()
		l.texture = torch_tex
		l.energy = 0.5
		l.shadow_enabled = true
		l.enabled = i < 9
		extra.add_child(l)
		lights.append(l)
	var mover: Callable = func() -> void:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		for i: int in lights.size():
			var a: float = t * 0.7 + float(i) * 0.37
			lights[i].position = Vector2(240, 135) + Vector2(cos(a) * (60.0 + float(i % 8) * 20.0), sin(a * 1.3) * (40.0 + float(i % 5) * 18.0))
	process_frame.connect(mover)
	results["torches9_shadows_30occluders"] = await _bench_run(frames, vp)
	for l: PointLight2D in lights:
		l.enabled = true
	results["lights64_shadows_30occluders"] = await _bench_run(frames, vp)
	for l: PointLight2D in lights:
		l.shadow_enabled = false
	results["lights64_no_shadows"] = await _bench_run(frames, vp)
	process_frame.disconnect(mover)
	bench_demo.queue_free()
	metrics["bench"] = results
	metrics["bench_window"] = "%s (base 480x270, viewport stretch), vsync off" % str(root.size)


func _bench_run(frames: int, vp: RID) -> Dictionary:
	await _frames(60)
	var times: PackedFloat64Array = PackedFloat64Array()
	var gpu: float = 0.0
	var cpu: float = 0.0
	var last: int = Time.get_ticks_usec()
	for i: int in frames:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	times.sort()
	var total: float = 0.0
	for t: float in times:
		total += t
	var avg: float = total / float(frames)
	var res: Dictionary = {
		"frames": frames,
		"avg_frame_ms": snappedf(avg, 0.001),
		"p99_frame_ms": snappedf(times[int(float(frames) * 0.99) - 1], 0.001),
		"fps": roundi(1000.0 / avg),
		"avg_gpu_render_ms": snappedf(gpu / float(frames), 0.001),
		"avg_cpu_render_ms": snappedf(cpu / float(frames), 0.001),
	}
	print("SPIKE_LIGHT_BENCH %s" % JSON.stringify(res))
	return res


# --- images & helpers ----------------------------------------------------------------------------

func _save(img: Image, variant: String, big: bool) -> void:
	if not save_images:
		return
	_write(img, "light_%s%s.png" % [variant, tag])
	if big:
		var up: Image = img.duplicate() as Image
		up.resize(BIG.x, BIG.y, Image.INTERPOLATE_NEAREST)
		_write(up, "light_%s_1080%s.png" % [variant, tag])


func _write(img: Image, file_name: String) -> void:
	var path: String = out_dir.path_join(file_name)
	var err: Error = img.save_png(path)
	print("SPIKE_LIGHT_SHOT %s %dx%d error=%d" % [path, img.get_width(), img.get_height(), err])
	shots[file_name] = "%dx%d" % [img.get_width(), img.get_height()]
	metrics["shots"] = shots


## East edge of the zone for each edge mode side by side (hard, dither, banded, smooth), 3x.
func _save_edges(images: Dictionary) -> void:
	if not save_images:
		return
	var crop: Rect2i = Rect2i(296, 64, 72, 120)
	var sheet: Image = Image.create_empty(crop.size.x * 4 + 3, crop.size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(LightGen.OUTLINE)
	var i: int = 0
	for edge_name: String in LightGen.EDGE_NAMES:
		sheet.blit_rect(images[edge_name], crop, Vector2i(i * (crop.size.x + 1), 0))
		i += 1
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_write(sheet, "light_edges%s.png" % tag)


## Walker on the dithered edge: one shared light | own hard-edged actor light, 4x.
func _save_actor_split(shared: Image, split: Image) -> void:
	if not save_images:
		return
	var c: Vector2i = Vector2i(demo.walker.global_position.round())
	var crop: Rect2i = Rect2i(c.x - 32, c.y - 48, 64, 64)
	var sheet: Image = Image.create_empty(crop.size.x * 2 + 1, crop.size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(LightGen.OUTLINE)
	sheet.blit_rect(shared, crop, Vector2i.ZERO)
	sheet.blit_rect(split, crop, Vector2i(crop.size.x + 1, 0))
	sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
	_write(sheet, "light_actor_split%s.png" % tag)


## Altar with normal maps off | on | the generated normal map, 3x.
func _save_altar_normals(flat: Image, normal_on: Image) -> void:
	if not save_images:
		return
	var crop: Rect2i = Rect2i(168, 92, 112, 100)
	var sheet: Image = Image.create_empty(crop.size.x * 3 + 2, crop.size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(LightGen.OUTLINE)
	sheet.blit_rect(flat, crop, Vector2i.ZERO)
	sheet.blit_rect(normal_on, crop, Vector2i(crop.size.x + 1, 0))
	var nm: Image = demo.altar_normal_image
	var at: Vector2i = Vector2i((crop.size.x + 1) * 2 + (crop.size.x - nm.get_width()) / 2, (crop.size.y - nm.get_height()) / 2)
	sheet.blit_rect(nm, Rect2i(Vector2i.ZERO, nm.get_size()), at)
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	_write(sheet, "light_altar_normals%s.png" % tag)


func _ratio(img: Image, ref: Image, p: Vector2i) -> float:
	return snappedf(LightGen.luma(img.get_pixelv(p)) / maxf(LightGen.luma(ref.get_pixelv(p)), 0.001), 0.001)


func _mean_ratio(img: Image, ref: Image, rect: Rect2i) -> float:
	var a: float = 0.0
	var b: float = 0.0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			a += LightGen.luma(img.get_pixel(x, y))
			b += LightGen.luma(ref.get_pixel(x, y))
	return snappedf(a / maxf(b, 0.001), 0.001)


func _rgb_factor(img: Image, ref: Image, p: Vector2i) -> Array[float]:
	var c: Color = img.get_pixelv(p)
	var r: Color = ref.get_pixelv(p)
	var out: Array[float] = [snappedf(c.r / maxf(r.r, 0.001), 0.01), snappedf(c.g / maxf(r.g, 0.001), 0.01),
		snappedf(c.b / maxf(r.b, 0.001), 0.01)]
	return out


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


static func _parse_args(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for raw: String in argv:
		if not raw.begins_with("--"):
			continue
		var body: String = raw.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = true
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
