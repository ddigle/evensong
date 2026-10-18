extends "res://tests/spike_test.gd"
## Skeleton checks: project settings are set and in effect on the root window, the menu scene
## lists modules, the CLI parser works, the Windows export preset is what the README promises.

const SpikeTest := preload("res://tests/spike_test.gd")
const Modules := preload("res://skeleton/modules.gd")
const SpikeCliScript := preload("res://skeleton/spike_cli.gd")
const MainScript := preload("res://skeleton/main.gd")


func run() -> Array[String]:
	_check_project_settings()
	_check_root_window()
	_check_harness_helpers()
	_check_cli_and_modules()
	_check_export_preset()
	await _check_main_scene()
	return failures


func _check_project_settings() -> void:
	check_eq(ProjectSettings.get_setting("application/config/name"), "Evensong engine spike", "app name")
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://main.tscn", "main scene setting")
	check(ResourceLoader.exists("res://main.tscn"), "res://main.tscn exists")
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 480, "base width")
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 270, "base height")
	check_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "stretch mode")
	check_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "stretch scale mode")
	check_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0,
		"default texture filter = Nearest")
	check_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), true, "snap transforms")
	check_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel"), true, "snap vertices")


## The settings above must actually reach the root window (also in --script / headless mode).
func _check_root_window() -> void:
	var root: Window = tree.root
	check_eq(root.content_scale_size, Vector2i(480, 270), "root content_scale_size")
	check_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT, "root content_scale_mode")
	check_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER, "root content_scale_stretch")
	check_eq(root.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"root default texture filter")
	check(root.snap_2d_transforms_to_pixel, "root snap_2d_transforms_to_pixel")
	check(root.snap_2d_vertices_to_pixel, "root snap_2d_vertices_to_pixel")
	check(root.has_node("SpikeCli"), "SpikeCli autoload is in the tree")


func _check_harness_helpers() -> void:
	var probe: SpikeTest = SpikeTest.new()
	probe.check_eq(1, 2, "probe")
	probe.check_eq(1, 1.0, "int/float compare as numbers")
	probe.check_eq(&"a", "a", "StringName/String compare as text")
	probe.check_eq(1, "1", "int/String never equal")
	probe.check_has("abc", "b", "substring")
	probe.check_has([1, 2], 3, "array item")
	check_eq(probe.failures.size(), 3, "helper failures recorded (got %s)" % str(probe.failures))
	check_eq(probe.checks, 6, "helper check count")


func _check_cli_and_modules() -> void:
	var parsed: Dictionary = SpikeCliScript.parse_user_args(
		PackedStringArray(["--smoke", "--scene=lights", "x", "--frames=30"]))
	check_eq(parsed, {"smoke": true, "scene": "lights", "frames": "30"}, "parse_user_args")
	check_eq(Modules.scene_path("lights"), "res://lights/lights.tscn", "module scene path")
	check_eq(Modules.resolve_scene("res://a/b.tscn"), "res://a/b.tscn", "res:// path passes through")
	check_eq(Modules.resolve_scene("tiles"), "res://tiles/tiles.tscn", "module name resolves")
	var found: PackedStringArray = Modules.list_modules()
	for reserved: String in Modules.RESERVED_DIRS:
		check(not (reserved in found), "reserved folder %s is not a module" % reserved)
	for module: String in found:
		check(ResourceLoader.exists(Modules.scene_path(module)), "module %s has an entry scene" % module)
	check(FileAccess.file_exists("res://build/.gdignore"), "build/.gdignore keeps exports out of the import scan")
	check_has(SpikeCliScript.smoke_line(tree), "SPIKE_SMOKE ok", "smoke line")


func _check_export_preset() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if not check_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg loads"):
		return
	var section: String = ""
	for s: String in cfg.get_sections():
		if s.begins_with("preset.") and s.count(".") == 1 and cfg.get_value(s, "name", "") == "Windows Desktop":
			section = s
	if not check(not section.is_empty(), "preset named 'Windows Desktop' exists"):
		return
	check_eq(cfg.get_value(section, "platform", ""), "Windows Desktop", "preset platform")
	check_eq(cfg.get_value(section, "export_path", ""), "build/evensong_spike.exe", "preset export path")
	var options: String = section + ".options"
	check_eq(cfg.get_value(options, "binary_format/architecture", ""), "x86_64", "preset architecture")
	check_eq(cfg.get_value(options, "binary_format/embed_pck", false), true, "preset embeds the pck")


func _check_main_scene() -> void:
	var packed: PackedScene = load("res://main.tscn") as PackedScene
	if not check_not_null(packed, "main.tscn loads"):
		return
	var main: Control = packed.instantiate() as Control
	if not check_not_null(main, "main.tscn root is a Control"):
		return
	add_node(main)
	await await_frames(1)
	var label: Label = main.get_node_or_null("Margin/Label") as Label
	if not check_not_null(label, "main scene has Margin/Label"):
		return
	check_has(label.text, MainScript.TITLE, "menu title")
	check_has(label.text, "Spike scenes:", "menu lists spike scenes")
	check_eq(label.text, MainScript.build_text(Modules.list_modules()), "menu text matches discovered modules")
	check(main.get_rect().size.x > 0.0, "menu has a size")
