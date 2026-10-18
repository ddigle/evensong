extends SceneTree
## Tile placement benchmark (both methods, surface and dungeon maps).
##
##   godot --headless --path prototypes/engine-spike --script res://tiles/bench_tiles.gd
##   ... --script res://tiles/bench_tiles.gd -- --size=512 --edits=2000 --seed=1 --quality
##   godot --path prototypes/engine-spike --script res://tiles/bench_tiles.gd -- --render   (window, real renderer)
##
## Prints one TILES_BENCH line per kind and method (fill, then the same number of edits batched and
## one per update, see tile_bench.gd), then TILES_UPDATE lines (one set_cell + update_internals on
## layers of growing size). --quality adds seam / fallback counts (slower).
## --render (needs the real renderer, no --headless): fills each map and draws FRAMES frames with
## vsync off, first without edits, then with one edit per frame inside the visible 30x17 cells,
## and prints TILES_RENDER lines with the average and worst frame time.

const TileBench := preload("res://tiles/tile_bench.gd")
const Wang := preload("res://tiles/wang.gd")

const FRAMES: int = 300


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var args: Dictionary = {}
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with("--"):
			var parts: PackedStringArray = raw.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var size: int = int(args.get("size", "512"))
	var edits: int = int(args.get("edits", "2000"))
	var seed_value: int = int(args.get("seed", "1"))
	var quality: bool = args.has("quality")
	var kinds: PackedStringArray = str(args.get("kinds", "surface,dungeon")).split(",")
	var methods: PackedStringArray = str(args.get("methods", "b,a")).split(",")
	if args.has("render"):
		await _render(kinds, methods, size, seed_value)
		quit(0)
		return
	for kind: String in kinds:
		for method: String in methods:
			var r: Dictionary = TileBench.run(kind, method, size, edits, seed_value, root, quality)
			print(TileBench.format(r))
			await process_frame
	for layer_size: int in [64, 128, 256, 512]:
		print("TILES_UPDATE layer=%dx%d set_cell+update_internals_us=%.1f" % [
			layer_size, layer_size, TileBench.update_cost("surface", layer_size, 400, root)])
		await process_frame
	quit(0)


func _render(kinds: PackedStringArray, methods: PackedStringArray, size: int, seed_value: int) -> void:
	if DisplayServer.get_name() == "headless":
		print("TILES_RENDER skipped: needs the real renderer (run without --headless)")
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("TILES_RENDER renderer=%s adapter=%s" % [
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	for kind: String in kinds:
		for method: String in methods:
			var grid: RefCounted = TileBench.make_grid(kind, method, size, size, root)
			var layer: TileMapLayer = grid.get("layer")
			grid.call("fill", TileBench.noise_map(kind, size, seed_value))
			for i: int in 10:
				await process_frame
			var idle: Array[int] = await _frames(grid, kind, false)
			var edit: Array[int] = await _frames(grid, kind, true)
			print("TILES_RENDER kind=%s method=%s size=%d frames=%d idle_avg_ms=%.3f idle_max_ms=%.3f edit_avg_ms=%.3f edit_max_ms=%.3f" % [
				kind, method, size, FRAMES, idle[0] / 1000.0 / FRAMES, idle[1] / 1000.0,
				edit[0] / 1000.0 / FRAMES, edit[1] / 1000.0])
			layer.queue_free()
			await process_frame


## Returns [total_us, max_us] over FRAMES frames (wall time between frames).
func _frames(grid: RefCounted, kind: String, with_edits: bool) -> Array[int]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var total: int = 0
	var worst: int = 0
	var last: int = Time.get_ticks_usec()
	for i: int in FRAMES:
		if with_edits:
			var c: Vector2i = Vector2i(rng.randi_range(1, 29), rng.randi_range(1, 16))
			var current: int = int(grid.call("get_terrain", c.x, c.y))
			var next: int
			if kind == "dungeon":
				next = Wang.FLOOR if current == Wang.WALL else Wang.WALL
			else:
				next = Wang.SOIL if current == Wang.GRASS else Wang.GRASS
			grid.call("set_terrain", c.x, c.y, next)
		await process_frame
		var now: int = Time.get_ticks_usec()
		total += now - last
		worst = maxi(worst, now - last)
		last = now
	return [total, worst]
