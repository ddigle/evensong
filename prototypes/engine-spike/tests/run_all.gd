extends SceneTree
## Spike test runner.
##
##   godot --headless --path prototypes/engine-spike --script res://tests/run_all.gd
##   godot ... --script res://tests/run_all.gd -- --only=skeleton,tiles   (selected modules only)
##   godot ... --script res://tests/run_all.gd -- --timeout=300           (seconds per file, default 120)
##
## Finds res://tests/test_*.gd, instantiates each (they extend res://tests/spike_test.gd),
## awaits run() -> Array[String] (failure messages; empty = pass) and prints PASS/FAIL per file
## and per message. GDScript runtime errors logged while a file runs also count as failures.
## Exit code: 0 = every file passed, 1 = any failure, load error, timeout or no test files.

const TEST_DIR: String = "res://tests"
const DEFAULT_TIMEOUT_SEC: float = 120.0


## Collects GDScript runtime errors (OS logger, Godot 4.5+). Called from any thread.
class ScriptErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_SCRIPT:
			return
		var text: String = rationale if not rationale.is_empty() else code
		_mutex.lock()
		_errors.append("script error: %s (%s:%d in %s)" % [text, file, line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var out: Array[String] = _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return out


var _done: bool = false
var _result: Variant = null
var _log: ScriptErrorLog = ScriptErrorLog.new()


func _initialize() -> void:
	OS.add_logger(_log)
	_run_all()


static func discover(only: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for file: String in DirAccess.get_files_at(TEST_DIR):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var module: String = file.trim_prefix("test_").trim_suffix(".gd")
		if only.is_empty() or module in only:
			out.append(file)
	out.sort()
	return out


func _run_all() -> void:
	await process_frame  # autoloads and the root window are ready after the first frame
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var only: PackedStringArray = []
	if args.has("only"):
		only = str(args["only"]).split(",", false)
	var timeout_sec: float = float(str(args.get("timeout", str(DEFAULT_TIMEOUT_SEC))))

	var files: PackedStringArray = discover(only)
	print("SPIKE_TESTS start: %d file(s) in %s%s" % [
		files.size(), TEST_DIR, "" if only.is_empty() else " (only %s)" % ",".join(only)])
	if files.is_empty():
		print("FAIL no test files found")
		_finish(1)
		return

	var failed: int = 0
	var total_checks: int = 0
	var started: int = Time.get_ticks_msec()
	for file: String in files:
		var path: String = TEST_DIR.path_join(file)
		var t0: int = Time.get_ticks_msec()
		_log.take()  # drop anything logged before this file
		var report: Dictionary = await _run_file(path, timeout_sec)
		var messages: Array[String] = report["messages"]
		messages.append_array(_log.take())
		var checks: int = report["checks"]
		total_checks += checks
		var ms: int = Time.get_ticks_msec() - t0
		if messages.is_empty():
			print("PASS %s (%d checks, %d ms)" % [file, checks, ms])
		else:
			failed += 1
			print("FAIL %s (%d checks, %d failure(s), %d ms)" % [file, checks, messages.size(), ms])
			for message: String in messages:
				print("  - %s" % message)

	print("SPIKE_TESTS done: %d passed, %d failed, %d checks, %d ms" % [
		files.size() - failed, failed, total_checks, Time.get_ticks_msec() - started])
	_finish(1 if failed > 0 else 0)


func _run_file(path: String, timeout_sec: float) -> Dictionary:
	var messages: Array[String] = []
	var script: Script = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		messages.append("cannot load %s (parse error? see the log above)" % path)
		return {"messages": messages, "checks": 0}
	var test: Object = script.new()
	if not test.has_method("run"):
		messages.append("%s has no run() (extend res://tests/spike_test.gd)" % path)
		return {"messages": messages, "checks": 0}
	test.set("tree", self)

	_done = false
	_result = null
	_invoke(test)
	var deadline: int = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not _done and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _done:
		messages.append("timed out after %.0f s (raise with -- --timeout=<sec>)" % timeout_sec)
	elif _result == null:
		messages.append("run() returned null (script error? see the log above)")
	elif _result is Array:
		for item: Variant in _result:
			messages.append(str(item))
	else:
		messages.append("run() must return Array[String], got %s" % type_string(typeof(_result)))

	var checks: Variant = test.get("checks")
	if test.has_method("cleanup"):
		test.call("cleanup")
	await process_frame  # let queue_free() from cleanup run before the next file
	return {"messages": messages, "checks": checks if checks is int else 0}


## Runs test.run() and stores its result; awaiting also works when run() is not a coroutine.
func _invoke(test: Object) -> void:
	var value: Variant = await test.call("run")
	_result = value
	_done = true


func _finish(code: int) -> void:
	OS.remove_logger(_log)
	quit(code)


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
