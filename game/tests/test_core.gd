extends "res://tests/base_test.gd"
## Core: project settings (and that they reach the root window), GDScript warnings as errors,
## input map, export presets, CLI parsing, the smoke checks, every script compiles, and the test
## runner itself (run on tests/fixtures in child processes, each with a deadline: a hung child is
## killed and fails the check instead of hanging the run), and its test port block.

const Runner := preload("res://tests/run_all.gd")
const TestCase := preload("res://tests/base_test.gd")
const CliScript := preload("res://core/cli.gd")

const WARNING_SETTINGS: PackedStringArray = [
	"debug/gdscript/warnings/untyped_declaration",
	"debug/gdscript/warnings/unsafe_property_access",
	"debug/gdscript/warnings/unsafe_method_access",
	"debug/gdscript/warnings/unsafe_cast",
	"debug/gdscript/warnings/unsafe_call_argument",
]
## Expected result of each runner fixture (tests/fixtures/case_*.gd).
const FIXTURES: Dictionary[String, String] = {
	"case_allowed.gd": "PASS",
	"case_allowed_missing.gd": "FAIL",
	"case_check_fails.gd": "FAIL",
	"case_engine_error.gd": "FAIL",
	"case_error_after_await.gd": "FAIL",
	"case_not_a_test.gd": "FAIL",
	"case_parked_node.gd": "FAIL",
	"case_pass.gd": "PASS",
	"case_push_error.gd": "FAIL",
	"case_runtime_error.gd": "FAIL",
	"case_timeout.gd": "FAIL",
}
const SKIP_DIRS: PackedStringArray = ["res://.godot", "res://build", "res://shots"]
## How long a runner child may take (the fixtures need about 3 s) before it is killed.
const CHILD_DEADLINE_SEC: float = 60.0
## The hang check: a child that would run for 30 s (case_timeout.gd under a long --timeout) is
## killed after this.
const HANG_DEADLINE_SEC: float = 2.0


func run() -> Array[String]:
	_check_project_settings()
	_check_root_window()
	_check_input_map()
	_check_export_presets()
	_check_cli_options()
	_check_smoke()
	_check_scripts_compile()
	_check_warnings_are_errors()
	_check_runner_helpers()
	await _check_port_block()
	await _check_runner_fixtures()
	await _check_child_deadline()
	return failures


func _check_project_settings() -> void:
	check_eq(ProjectSettings.get_setting("application/config/name"), "Evensong", "app name")
	check_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn", "main scene")
	check(ResourceLoader.exists("res://scenes/main.tscn"), "main.tscn exists")
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 480, "viewport width")
	check_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 270, "viewport height")
	check_eq(ProjectSettings.get_setting("display/window/size/window_width_override"), 1920, "window width")
	check_eq(ProjectSettings.get_setting("display/window/size/window_height_override"), 1080, "window height")
	check_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "stretch mode")
	check_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch aspect")
	check_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "stretch scale mode")
	check_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0,
		"default texture filter = Nearest")
	check_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), true, "snap transforms")
	check_eq(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel"), true, "snap vertices")
	check_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "forward_plus", "renderer")
	check_eq(ProjectSettings.get_setting("autoload/Cli"), "*res://core/cli.gd", "Cli autoload")
	for setting: String in WARNING_SETTINGS:
		check_eq(ProjectSettings.get_setting(setting), 2, "%s = error" % setting)
	check(FileAccess.file_exists("res://build/.gdignore"), "build/.gdignore keeps exports out of the import scan")
	check(FileAccess.file_exists("res://shots/.gdignore"), "shots/.gdignore keeps screenshots out of the import scan")
	check(FileAccess.file_exists("res://.gitignore"), "game/.gitignore exists")
	var ignore: String = FileAccess.get_file_as_string("res://.gitignore")
	check_has(ignore, ".godot/", ".gitignore ignores .godot/")
	check_has(ignore, "build/*", ".gitignore ignores build/")
	check_has(ignore, "!build/.gdignore", ".gitignore keeps build/.gdignore")


## The settings above must reach the root window (also in --script / headless mode).
func _check_root_window() -> void:
	var root: Window = tree.root
	check_eq(root.content_scale_size, Vector2i(480, 270), "root content_scale_size")
	check_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT, "root content_scale_mode")
	check_eq(root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER, "root content_scale_stretch")
	check_eq(root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_EXPAND, "root content_scale_aspect")
	check_eq(root.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		"root default texture filter")
	check(root.snap_2d_transforms_to_pixel, "root snap_2d_transforms_to_pixel")
	check(root.snap_2d_vertices_to_pixel, "root snap_2d_vertices_to_pixel")
	check(root.has_node("Cli"), "Cli autoload is in the tree")


func _check_input_map() -> void:
	for action: String in Smoke.MOVE_KEYS:
		check(InputMap.has_action(action), "action %s exists" % action)
	check(InputMap.has_action("debug_overlay"), "action debug_overlay exists")
	var keys: Array[int] = []
	for event: InputEvent in InputMap.action_get_events("debug_overlay"):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			keys.append(key.physical_keycode)
	check_eq(keys, [KEY_F3] as Array[int], "debug_overlay key")
	check(InputMap.has_action("toggle_evening"), "action toggle_evening exists")
	keys.clear()
	for event: InputEvent in InputMap.action_get_events("toggle_evening"):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			keys.append(key.physical_keycode)
	check_eq(keys, [KEY_F4] as Array[int], "toggle_evening key")


func _check_export_presets() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if not check_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg loads"):
		return
	var expected: Dictionary[String, Array] = {
		"Windows Desktop": ["x86_64", "build/evensong.exe"],
		"Windows ARM64": ["arm64", "build/arm64/evensong.exe"],
	}
	var found: Dictionary[String, String] = {}
	for section: String in cfg.get_sections():
		if section.begins_with("preset.") and section.count(".") == 1:
			found[str(cfg.get_value(section, "name", ""))] = section
	for preset_name: String in expected:
		if not check(found.has(preset_name), "export preset '%s' exists" % preset_name):
			continue
		var section: String = found[preset_name]
		var options: String = section + ".options"
		var want: Array = expected[preset_name]
		check_eq(cfg.get_value(section, "platform", ""), "Windows Desktop", "%s platform" % preset_name)
		check_eq(cfg.get_value(section, "export_path", ""), want[1], "%s export path" % preset_name)
		check_eq(cfg.get_value(options, "binary_format/architecture", ""), want[0], "%s architecture" % preset_name)
		check_eq(cfg.get_value(options, "binary_format/embed_pck", false), true, "%s embeds the pck" % preset_name)
		check_eq(cfg.get_value(options, "debug/export_console_wrapper", 0), 2, "%s console wrapper" % preset_name)
		check_has(str(cfg.get_value(section, "exclude_filter", "")), "tests/*", "%s excludes tests/" % preset_name)


func _check_cli_options() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray([]))
	check(not o.smoke and not o.host and not o.join and not o.no_evening, "no flags: nothing on")
	check_eq(o.world_seed, Config.DEFAULT_SEED, "default seed")
	check_eq(o.frames, CliOptions.DEFAULT_FRAMES, "default frames")
	check_eq(o.errors.size(), 0, "no flags: no errors")

	o = CliOptions.parse(PackedStringArray(["--smoke", "--seed=-42", "--class=herbalist", "--screenshot=shots/a.png",
		"--frames=30", "--scale=3", "--overlay", "--no-evening", "positional", "--only=world"]))
	check(o.smoke, "--smoke")
	check_eq(o.world_seed, -42, "--seed")
	check_eq(o.class_id, "herbalist", "--class")
	check_eq(o.screenshot, "shots/a.png", "--screenshot")
	check_eq(o.frames, 30, "--frames")
	check_eq(o.scale, 3, "--scale")
	check(o.overlay, "--overlay")
	check(o.no_evening, "--no-evening")
	check_eq(o.unknown, PackedStringArray(["positional", "--only=world"]), "unknown args are kept, not errors")
	check_eq(o.errors.size(), 0, "valid flags: no errors (got %s)" % str(o.errors))

	o = CliOptions.parse(PackedStringArray(["--host"]))
	check(o.host and o.port == Config.DEFAULT_PORT, "--host uses the default port")
	o = CliOptions.parse(PackedStringArray(["--host=24625"]))
	check_eq(o.port, 24625, "--host=<port>")
	o = CliOptions.parse(PackedStringArray(["--join=192.168.0.7:24630"]))
	check(o.join, "--join")
	check_eq(o.join_address, "192.168.0.7", "--join address")
	check_eq(o.port, 24630, "--join port")
	o = CliOptions.parse(PackedStringArray(["--join=desktop.tailnet"]))
	check_eq([o.join_address, o.port], ["desktop.tailnet", Config.DEFAULT_PORT], "--join without port")
	o = CliOptions.parse(PackedStringArray(["--join=[::1]:24631"]))
	check_eq([o.join_address, o.port], ["::1", 24631], "--join IPv6 with port")

	var bad: Array[PackedStringArray] = [
		PackedStringArray(["--class=wizard"]), PackedStringArray(["--seed=abc"]),
		PackedStringArray(["--screenshot=a.jpg"]), PackedStringArray(["--frames=0"]),
		PackedStringArray(["--scale=x"]), PackedStringArray(["--host=70000"]), PackedStringArray(["--join="]),
		PackedStringArray(["--join=[::1"]), PackedStringArray(["--host", "--join=a"]),
	]
	for argv: PackedStringArray in bad:
		check_eq(CliOptions.parse(argv).errors.size(), 1, "%s is one error" % " ".join(argv))
	check_eq(CliOptions.current().errors.size(), 0, "this run's own flags parsed without errors")
	check(CliOptions.current() == CliOptions.current(), "current() is parsed once")
	# Screenshot window: largest integer multiple of 480x270 that fits the screen, 1..4.
	check_eq(CliScript.fitting_scale(Vector2i(1024, 768)), 2, "fitting scale on 1024x768")
	check_eq(CliScript.fitting_scale(Vector2i(1920, 1040)), 3, "fitting scale on a 1080p work area")
	check_eq(CliScript.fitting_scale(Vector2i(3840, 2160)), 4, "fitting scale capped at the default window")
	check_eq(CliScript.fitting_scale(Vector2i(300, 200)), 1, "fitting scale at least 1")
	var cli: Node = tree.root.get_node_or_null("Cli")
	var same_options: bool = cli != null and cli.get("options") == CliOptions.current()
	check(same_options, "Cli autoload holds the same options")


func _check_smoke() -> void:
	var t0: int = Time.get_ticks_usec()
	var report: Smoke.Report = Smoke.run(tree)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	check(report.ok(), "smoke checks pass in the editor build: %s" % "; ".join(report.failures))
	check(report.checks >= 30, "smoke makes real checks (%d)" % report.checks)
	check(report.line().begins_with("EVENSONG_SMOKE ok "), "smoke ok line")
	note("smoke: %d checks, %.0f ms" % [report.checks, ms])
	# The same checks fail on a window with other settings (they are not a fixed "ok").
	var broken: Smoke.Report = Smoke.Report.new()
	var window: Window = Window.new()
	Smoke._check_window(broken, window)
	window.free()
	check(not broken.ok(), "window checks fail on a default Window")
	check(broken.failures.size() >= 4, "several window settings flagged (%d)" % broken.failures.size())
	check(broken.line().begins_with("EVENSONG_SMOKE FAIL "), "smoke FAIL line")


func _check_scripts_compile() -> void:
	var paths: PackedStringArray = _scripts_under("res://")
	check(paths.size() >= 20, "found the project's scripts (%d)" % paths.size())
	for path: String in paths:
		var script: GDScript = load(path) as GDScript
		check(script != null and script.can_instantiate(), "%s compiles" % path)


## The project settings make these GDScript warnings errors: a script with one fails to compile.
func _check_warnings_are_errors() -> void:
	var cases: Dictionary[String, String] = {
		"untyped_declaration": "func f() -> void:\n\tvar x = 1\n\tprint(x)\n",
		"unsafe_method_access": "func f(v: Variant) -> void:\n\tv.foo()\n",
		"unsafe_property_access": "func f(r: RefCounted) -> void:\n\tprint(r.foo)\n",
		"unsafe_call_argument": "func f(v: Variant) -> int:\n\treturn absi(v)\n",
		"unsafe_cast": "func f(v: Variant) -> Node:\n\treturn v as Node\n",
	}
	for warning: String in cases:
		allow_error("Warning treated as error", 1)  # the compile error is logged once
		var script: GDScript = GDScript.new()
		script.source_code = "extends RefCounted\n\n" + cases[warning]
		var err: Error = script.reload()
		check_eq(err, ERR_PARSE_ERROR, "%s is a compile error" % warning)
	var typed: GDScript = GDScript.new()
	typed.source_code = "extends RefCounted\n\nfunc f(v: Variant) -> int:\n\tvar n: int = v\n\treturn absi(n)\n"
	check_eq(typed.reload(), OK, "typed version compiles")


func _check_runner_helpers() -> void:
	check_eq(Runner.parse_args(PackedStringArray(["--only=a,b", "--x", "y"])), {"only": "a,b", "x": ""} as Dictionary[String, String],
		"runner parse_args")
	var found: PackedStringArray = Runner.discover("res://tests", "test_", PackedStringArray())
	check_has(found, "test_core.gd", "runner finds test_core.gd")
	check_has(found, "test_world.gd", "runner finds test_world.gd")
	check_has(found, "test_actors.gd", "runner finds test_actors.gd")
	check_has(found, "test_light.gd", "runner finds test_light.gd")
	check_eq(Runner.discover("res://tests", "test_", PackedStringArray(["world"])), PackedStringArray(["test_world.gd"]),
		"--only filters by name")
	var errs: Array[String] = ["error: A happened", "error: B happened", "error: B happened", "error: C happened"]
	var allow: Array[TestCase.Allowance] = []
	for pair: Array in [["A happened", 1], ["B happened", 2]]:
		var a: TestCase.Allowance = TestCase.Allowance.new()
		a.pattern = pair[0]
		a.count = pair[1]
		allow.append(a)
	check_eq(Runner.match_errors(errs, allow), ["error: C happened"] as Array[String],
		"unannounced error fails, announced ones pass")
	allow[1].count = 3
	check_eq(Runner.match_errors(errs, allow).size(), 2, "announced count not met fails")
	allow[1].count = -1
	check_eq(Runner.match_errors(errs.slice(0, 1), allow).size(), 0, "count -1 accepts zero matches")


## The run's port block: chosen and held by the runner, every port free when it was chosen. A held
## block cannot be claimed again (the lock), a block with a busy port is skipped (also a port an
## IPv4-only socket holds), bad bases are refused, a runner given a held block runs nothing.
func _check_port_block() -> void:
	var count: int = Config.NET_TEST_PORT_COUNT
	check_eq(count, 20, "20 test ports")
	check_eq(Runner.port_last - Runner.port_first + 1, count, "the run's block has %d ports (%d-%d)" % [count,
		Runner.port_first, Runner.port_last])
	var env: String = OS.get_environment(Runner.PORT_ENV)
	var args: Dictionary[String, String] = Runner.parse_args(OS.get_cmdline_user_args())
	if not args.has("port-base") and not args.has("ports-from-parent") and env.is_empty():
		check_eq((Runner.port_first - Config.NET_TEST_PORT_FIRST) % count, 0,
			"default: 24621-24640 or a block above it (%d)" % Runner.port_first)
	note("test ports %d-%d (%s)" % [Runner.port_first, Runner.port_last, "--port-base" if args.has("port-base")
		else ("--ports-from-parent" if args.has("ports-from-parent") else (Runner.PORT_ENV if not env.is_empty() else "default"))])
	if not args.has("ports-from-parent"):
		check(Runner.claim_port_block(Runner.port_first, count) == null,
			"this run holds its block: claiming it again fails (another runner moves on)")
	check_eq(Runner.parse_port_base("25000", count), 25000, "port base 25000")
	for bad: String in ["0", "-3", "abc", "65530", ""]:
		check_eq(Runner.parse_port_base(bad, count), -1, "port base '%s' refused" % bad)
	# A block with one busy UDP port is not claimed; once it is free, it is.
	var base: int = _spare_block(count)
	if not check(base > 0, "a spare block for the claim check"):
		return
	var busy: UDPServer = UDPServer.new()
	busy.listen(base + 7)
	check(Runner.claim_port_block(base, count) == null, "a block with a busy UDP port is skipped")
	check_eq(Runner.free_port(base + 7, base + 9), base + 8, "free_port skips the busy port (no engine error)")
	busy.stop()
	# An IPv4-only holder (another program's socket on 0.0.0.0 or 127.0.0.1): Windows lets a dual-stack
	# "*" socket share its port, and the test clients' 127.0.0.1 traffic would go to the holder.
	for address: String in ["0.0.0.0", "127.0.0.1"]:
		var v4: PacketPeerUDP = PacketPeerUDP.new()
		if not check_eq(v4.bind(base + 7, address), OK, "an IPv4-only socket holds port %d on %s" % [base + 7, address]):
			continue
		check(not Runner.udp_ports_free(base + 7, 1), "a port held on %s only is busy" % address)
		check(Runner.claim_port_block(base, count) == null, "a block with a port held on %s is skipped" % address)
		check_eq(Runner.free_port(base + 7, base + 9), base + 8, "free_port skips a port held on %s" % address)
		v4.close()
	check(Runner.udp_ports_free(base + 7, 1), "the port is free again once the holders are gone")
	var lock: TCPServer = Runner.claim_port_block(base, count)
	check(lock != null and lock.is_listening(), "a free block is claimed")
	check(Runner.claim_port_block(base, count) == null, "and cannot be claimed twice")
	# A runner told to use that held block (--port-base) fails at startup and runs no file.
	var held: Array = await _run_runner(PackedStringArray(["--dir=res://tests/fixtures", "--prefix=case_", "--only=pass",
		"--timeout=2", "--port-base=%d" % base]), CHILD_DEADLINE_SEC, false)
	var held_code: int = held[0]
	var held_text: String = held[1]
	check_eq(held_code, 1, "a runner whose --port-base block is held exits 1")
	check_has(held_text, "no test ports claimed", "and says it claimed no ports")
	check_has(held_text, "FAIL (startup)", "with FAIL (startup)")
	check(not held_text.contains("PASS case_pass.gd") and held_text.contains("no file ran"),
		"and runs no test file (they would use ports it does not hold)")
	if lock != null:
		lock.stop()


## A block above the run's own, free right now (for the claim checks), or -1.
static func _spare_block(count: int) -> int:
	for i: int in range(1, 20):
		var base: int = Runner.port_last + 1 + i * count
		var lock: TCPServer = Runner.claim_port_block(base, count)
		if lock != null:
			lock.stop()
			return base
	return -1


## Runs the runner on tests/fixtures in a child process: every fixture must end as expected. A second
## child runs late_error.gd alone: an error after the last file must still fail the run.
func _check_runner_fixtures() -> void:
	var t0: int = Time.get_ticks_msec()
	var result: Array = await _run_runner(PackedStringArray(["--dir=res://tests/fixtures", "--prefix=case_", "--timeout=2"]),
		CHILD_DEADLINE_SEC)
	var code: int = result[0]
	var text: String = result[1]
	check_eq(code, 1, "runner exits 1 when fixtures fail")
	for file: String in FIXTURES:
		var want: String = FIXTURES[file]
		var hit: bool = false
		for line: String in text.split("\n"):
			if line.begins_with("%s %s " % [want, file]):
				hit = true
		check(hit, "fixture %s: expected %s" % [file, want])
	check_has(text, "EVENSONG_TESTS done: 2 passed, 9 failed", "runner summary")
	check_has(text, "left ParkedNode (Node) under the root", "a node left under the root is named")
	check(not text.contains("fixture: error from a node left under the root"),
		"the runner freed the left node before it could log into case_pass.gd")
	check_has(text, "ports %d-%d" % [Runner.port_first, Runner.port_last], "the child runner uses the block passed down")

	result = await _run_runner(PackedStringArray(["--dir=res://tests/fixtures", "--prefix=late_", "--timeout=2"]),
		CHILD_DEADLINE_SEC)
	code = result[0]
	text = result[1]
	check_eq(code, 1, "runner exits 1 on an error after the last file")
	check_has(text, "PASS late_error.gd ", "late_error.gd itself passes")
	check_has(text, "FAIL (after the last file) 1 error(s) logged after late_error.gd finished",
		"error after the last file is counted")
	check_has(text, "- error: fixture: error after the last file", "error after the last file is listed")
	check_has(text, "EVENSONG_TESTS done: 1 passed, 0 failed", "late run summary")
	check_has(text, "(+ errors after the last file)", "late run summary names the late errors")
	note("runner self-test: %d fixtures + late_error.gd in two child processes, %d ms" % [FIXTURES.size(),
		Time.get_ticks_msec() - t0])


## A child that does not finish is killed at its deadline and reported, and this run goes on: the
## runner on case_timeout.gd with a long --timeout would take 30 s.
func _check_child_deadline() -> void:
	var t0: int = Time.get_ticks_msec()
	var result: Array = await _run_runner(PackedStringArray(["--dir=res://tests/fixtures", "--prefix=case_",
		"--only=timeout", "--timeout=60"]), HANG_DEADLINE_SEC)
	var ms: int = Time.get_ticks_msec() - t0
	var timed_out: bool = result[2]
	var pid: int = result[3]
	check(timed_out, "a child past its deadline is reported as timed out (exit %d after %d ms)" % [result[0], ms])
	check(ms < int(HANG_DEADLINE_SEC * 1000.0) + 5000, "and the wait ends at the deadline (%d ms)" % ms)
	check(pid > 0 and not OS.is_process_running(pid), "the hung child was killed")
	note("hung child killed after %d ms (deadline %.0f s)" % [ms, HANG_DEADLINE_SEC])


## Runs tests/run_all.gd with `user_args` in a headless child process (output to a log file, the
## run's port block passed down unless `pass_ports` is false) and waits at most `deadline_sec`,
## polling so this runner keeps going. A child still running then is killed. Returns [exit code
## (-1 if killed or not started), output, timed out, pid].
func _run_runner(user_args: PackedStringArray, deadline_sec: float, pass_ports: bool = true) -> Array:
	var log_path: String = ProjectSettings.globalize_path("user://runner_child_%d_%d.log" % [OS.get_process_id(),
		Time.get_ticks_usec()])
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--log-file", log_path,
		"--script", "res://tests/run_all.gd", "--"]
	args.append_array(user_args)
	if pass_ports:
		args.append("--ports-from-parent=%d" % Runner.port_first)
	var pid: int = OS.create_process(OS.get_executable_path(), args, false)
	if not check(pid > 0, "runner child started"):
		return [-1, "", false, pid]
	var deadline: int = Time.get_ticks_msec() + int(deadline_sec * 1000.0)
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.05).timeout
	var timed_out: bool = OS.is_process_running(pid)
	var code: int = -1
	if timed_out:
		OS.kill(pid)
		var gone: int = Time.get_ticks_msec() + 5000
		while OS.is_process_running(pid) and Time.get_ticks_msec() < gone:
			await tree.create_timer(0.05).timeout
	else:
		code = OS.get_process_exit_code(pid)
	var text: String = FileAccess.get_file_as_string(log_path)
	DirAccess.remove_absolute(log_path)
	return [code, text, timed_out, pid]


static func _scripts_under(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if SKIP_DIRS.has(dir.trim_suffix("/")):
		return out
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(sub)))
	return out
