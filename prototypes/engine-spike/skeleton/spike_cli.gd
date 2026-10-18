extends Node
## Autoload "SpikeCli": command-line switches so agents can drive the spike headless.
##
## User args go after "--" on the Godot command line, e.g.
##   godot --headless --path . -- --smoke
##   godot --path . -- --scene=lights --screenshot=build/shots/lights.png
##
##   --smoke                    print one "SPIKE_SMOKE ok ..." line and quit with exit code 0
##   --scene=<module|res://..>  open res://<module>/<module>.tscn (or a res:// scene) at startup
##   --screenshot=<file.png>    save the root viewport (480x270) after --frames frames, then quit
##   --frames=<n>               frames to wait before the screenshot (default 10)
##   --scale=<n>                window size = base size x n (no effect with --headless)
##
## F10 returns to the menu (res://main.tscn) from any scene.

const Modules := preload("res://skeleton/modules.gd")
const MAIN_SCENE: String = "res://main.tscn"
const DEFAULT_SCREENSHOT_FRAMES: int = 10

var user_args: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	user_args = parse_user_args(OS.get_cmdline_user_args())
	if user_args.has("smoke"):
		_run_smoke()
		return
	if user_args.has("scale"):
		_apply_scale(int(str(user_args["scale"])))
	if user_args.has("scene") or user_args.has("screenshot"):
		_run_startup.call_deferred()


## ["--a", "--b=1", "x"] -> {"a": true, "b": "1"}. Values stay strings.
static func parse_user_args(argv: PackedStringArray) -> Dictionary:
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


static func smoke_line(tree: SceneTree) -> String:
	var root: Window = tree.root
	return "SPIKE_SMOKE ok godot=%s display=%s base=%dx%d stretch=%d/%d exported=%s modules=%d" % [
		Engine.get_version_info().string,
		DisplayServer.get_name(),
		root.content_scale_size.x,
		root.content_scale_size.y,
		root.content_scale_mode,
		root.content_scale_stretch,
		str(OS.has_feature("template")),
		Modules.list_modules().size(),
	]


func _run_smoke() -> void:
	print(smoke_line(get_tree()))
	get_tree().quit(0)


func _apply_scale(factor: int) -> void:
	if factor < 1 or DisplayServer.get_name() == "headless":
		return
	var root: Window = get_tree().root
	root.size = root.content_scale_size * factor
	root.move_to_center()


func _run_startup() -> void:
	if user_args.has("scene"):
		var path: String = Modules.resolve_scene(str(user_args["scene"]))
		if not ResourceLoader.exists(path):
			printerr("SpikeCli: scene not found: %s" % path)
			get_tree().quit(2)
			return
		var err: Error = get_tree().change_scene_to_file(path)
		if err != OK:
			printerr("SpikeCli: cannot open %s (error %d)" % [path, err])
			get_tree().quit(2)
			return
		print("SPIKE_SCENE %s" % path)
	if user_args.has("screenshot"):
		var frames: int = int(str(user_args.get("frames", str(DEFAULT_SCREENSHOT_FRAMES))))
		await _take_screenshot(str(user_args["screenshot"]), frames)


func _take_screenshot(path: String, frames: int) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SpikeCli: --screenshot needs a renderer. Run without --headless in a desktop session.")
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
	print("SPIKE_SCREENSHOT %s %dx%d error=%d" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F10:
		var current: Node = get_tree().current_scene
		if current == null or current.scene_file_path != MAIN_SCENE:
			get_tree().change_scene_to_file(MAIN_SCENE)
			get_viewport().set_input_as_handled()
