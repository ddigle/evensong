extends Node
## Autoload "Cli": command-line switches so agents can drive the game headless.
## Flags (after "--") are parsed by CliOptions; see core/cli_options.gd for the list.
##
##   godot --headless --path game -- --smoke
##   godot --path game res://scenes/world.tscn -- --seed=7 --screenshot=shots/world.png --frames=30
##
## Exit codes: 0 ok, 1 smoke check failed / screenshot not saved, 2 bad flags or --screenshot
## with --headless.

var options: CliOptions = CliOptions.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	options = CliOptions.current()
	if not options.errors.is_empty():
		for message: String in options.errors:
			printerr("EVENSONG_CLI error: %s" % message)
		get_tree().quit(2)
		return
	if options.smoke:
		var report: Smoke.Report = Smoke.run(get_tree())
		print(report.line())
		get_tree().quit(0 if report.ok() else 1)
		return
	if options.scale > 0:
		_apply_scale(options.scale)
	elif not options.screenshot.is_empty():
		# With aspect expand a window that is not 16:9 (e.g. shrunk to fit a small screen) widens
		# the viewport; an exact multiple of 480x270 keeps the capture at 480x270.
		_apply_scale(fitting_scale(DisplayServer.screen_get_usable_rect().size))
	if not options.screenshot.is_empty():
		_take_screenshot.call_deferred(options.screenshot, options.frames)


## Largest integer scale of Config.VIEW_SIZE whose window fits `screen` (at least 1), capped at
## the default window (4x).
static func fitting_scale(screen: Vector2i) -> int:
	var fit: int = mini(screen.x / Config.VIEW_SIZE.x, screen.y / Config.VIEW_SIZE.y)
	return clampi(fit, 1, Config.WINDOW_SIZE.x / Config.VIEW_SIZE.x)


func _apply_scale(factor: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var root: Window = get_tree().root
	root.size = Config.VIEW_SIZE * factor
	root.move_to_center()


func _take_screenshot(path: String, frames: int) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("EVENSONG_CLI error: --screenshot needs a renderer; run without --headless in a desktop session")
		get_tree().quit(2)
		return
	for i: int in maxi(frames, 1):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var dir: String = path.get_base_dir()
	if not dir.is_empty():
		DirAccess.make_dir_recursive_absolute(dir)
	var err: Error = img.save_png(path)
	var window: Vector2i = get_tree().root.size
	print("EVENSONG_SCREENSHOT %s %dx%d window=%dx%d error=%d" % [path, img.get_width(), img.get_height(), window.x,
		window.y, err])
	get_tree().quit(0 if err == OK else 1)
