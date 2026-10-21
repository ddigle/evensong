extends SceneTree
## Test runner.
##
##   godot --headless --path game --script res://tests/run_all.gd
##   godot ... --script res://tests/run_all.gd -- --only=core,world     (test_core.gd, test_world.gd)
##   godot ... --script res://tests/run_all.gd -- --timeout=300         (seconds per file, default 120)
##   godot ... --script res://tests/run_all.gd -- --dir=res://tests/fixtures --prefix=case_
##                                                  (other folder / file prefix: the runner's self-test)
##
## Finds <dir>/<prefix>*.gd, instantiates each (they extend res://tests/base_test.gd), awaits
## run() -> Array[String] (failure messages; empty = pass) and prints one PASS / FAIL line per
## file plus its messages and notes.
##
## Errors count as failures: every message the engine logs as an error while a file runs (engine
## errors such as a null argument or a missing node, push_error(), GDScript runtime errors, shader
## errors), caught with an OS Logger, unless the test announced it with allow_error(). Errors
## logged before the first file (startup) fail the run too. Warnings are printed, not counted.
##
## Exit code: 0 = every file passed, 1 = any failure, load error, timeout or no test files.

const TestCase := preload("res://tests/base_test.gd")
const DEFAULT_DIR: String = "res://tests"
const DEFAULT_PREFIX: String = "test_"
const DEFAULT_TIMEOUT_SEC: float = 120.0


## Collects error and warning messages from every thread.
class ErrorLog:
	extends Logger
	var _mutex: Mutex = Mutex.new()
	var _errors: Array[String] = []
	var _warnings: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text: String = code if rationale.is_empty() else "%s (%s)" % [rationale, code]
		var kind: String = ["error", "warning", "script error", "shader error"][clampi(error_type, 0, 3)]
		var entry: String = "%s: %s [%s:%d %s]" % [kind, text, file, line, function]
		_mutex.lock()
		if error_type == ERROR_TYPE_WARNING:
			_warnings.append(entry)
		else:
			_errors.append(entry)
		_mutex.unlock()

	func take_errors() -> Array[String]:
		_mutex.lock()
		var out: Array[String] = _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return out

	func take_warnings() -> Array[String]:
		_mutex.lock()
		var out: Array[String] = _warnings.duplicate()
		_warnings.clear()
		_mutex.unlock()
		return out


## Outcome of one test file.
class FileReport:
	extends RefCounted
	var messages: Array[String] = []
	var notes: Array[String] = []
	var checks: int = 0


var _log: ErrorLog = ErrorLog.new()
var _done: bool = false
var _result: Variant = null
var _run_token: int = 0  # a timed-out run() that finishes later must not end the next file


func _initialize() -> void:
	OS.add_logger(_log)
	_run_all()


## Test files in `dir` named <prefix><name>.gd, sorted; `only` filters by <name>.
static func discover(dir: String, prefix: String, only: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if not (file.begins_with(prefix) and file.ends_with(".gd")):
			continue
		var name: String = file.trim_prefix(prefix).trim_suffix(".gd")
		if only.is_empty() or only.has(name):
			out.append(file)
	out.sort()
	return out


## Matches logged errors against a test's allowances. Returns the failure messages: every error
## no allowance covers, and every allowance with a fixed count that was not met. Each error uses
## up one match of the first allowance whose pattern it contains.
static func match_errors(errors: Array[String], allowances: Array[TestCase.Allowance]) -> Array[String]:
	var out: Array[String] = []
	for a: TestCase.Allowance in allowances:
		a.seen = 0
	for entry: String in errors:
		var matched: bool = false
		for a: TestCase.Allowance in allowances:
			if entry.contains(a.pattern) and (a.count < 0 or a.seen < a.count):
				a.seen += 1
				matched = true
				break
		if not matched:
			out.append(entry)
	for a: TestCase.Allowance in allowances:
		if a.count >= 0 and a.seen != a.count:
			out.append("expected error '%s' %d time(s), logged %d" % [a.pattern, a.count, a.seen])
	return out


func _run_all() -> void:
	await process_frame  # autoloads and the root window are ready after the first frame
	var args: Dictionary[String, String] = parse_args(OS.get_cmdline_user_args())
	var dir: String = args.get("dir", DEFAULT_DIR)
	var prefix: String = args.get("prefix", DEFAULT_PREFIX)
	var only_text: String = args.get("only", "")
	var only: PackedStringArray = only_text.split(",", false)
	var timeout_text: String = args.get("timeout", "")
	var timeout_sec: float = timeout_text.to_float() if timeout_text.is_valid_float() else DEFAULT_TIMEOUT_SEC

	var files: PackedStringArray = discover(dir, prefix, only)
	print("EVENSONG_TESTS start: %d file(s) in %s%s" % [files.size(), dir,
		"" if only.is_empty() else " (only %s)" % ",".join(only)])
	var failed: int = 0
	var startup: Array[String] = _log.take_errors()
	_print_warnings(_log.take_warnings())
	if not startup.is_empty():
		failed += 1
		print("FAIL (startup) %d error(s) before the first test" % startup.size())
		for message: String in startup:
			print("  - %s" % message)
	if files.is_empty():
		print("FAIL no test files found")
		_finish(1)
		return

	var total_checks: int = 0
	var file_failures: int = 0
	var started: int = Time.get_ticks_msec()
	for file: String in files:
		var t0: int = Time.get_ticks_msec()
		var report: FileReport = await _run_file(dir.path_join(file), timeout_sec)
		var messages: Array[String] = report.messages
		var notes: Array[String] = report.notes
		var checks: int = report.checks
		total_checks += checks
		var ms: int = Time.get_ticks_msec() - t0
		if messages.is_empty():
			print("PASS %s (%d checks, %d ms)" % [file, checks, ms])
		else:
			failed += 1
			file_failures += 1
			print("FAIL %s (%d checks, %d failure(s), %d ms)" % [file, checks, messages.size(), ms])
			for message: String in messages:
				print("  - %s" % message)
		for line: String in notes:
			print("  * %s" % line)
		_print_warnings(_log.take_warnings())

	print("EVENSONG_TESTS done: %d passed, %d failed, %d checks, %d ms%s" % [
		files.size() - file_failures, file_failures, total_checks, Time.get_ticks_msec() - started,
		"" if startup.is_empty() else " (+ startup errors)"])
	_finish(1 if failed > 0 else 0)


func _run_file(path: String, timeout_sec: float) -> FileReport:
	var report: FileReport = FileReport.new()
	var messages: Array[String] = report.messages
	# Errors logged between files (none expected) are counted against the next file.
	var pending: Array[String] = _log.take_errors()
	var script: GDScript = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
	if script == null or not script.can_instantiate():
		messages.append("cannot load %s (parse error? see the log above)" % path)
		messages.append_array(pending)
		messages.append_array(_log.take_errors())
		return report
	var instance: Object = script.new()
	var test: TestCase = instance as TestCase
	if test == null:
		messages.append("%s does not extend res://tests/base_test.gd" % path)
		messages.append_array(pending)
		return report
	test.tree = self

	_done = false
	_result = null
	_run_token += 1
	_invoke(test, _run_token)
	var deadline: int = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not _done and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _done:
		messages.append("timed out after %.0f s (raise with -- --timeout=<sec>)" % timeout_sec)
	elif _result == null:
		messages.append("run() returned null (runtime error? see the errors below)")
	elif _result is Array:
		var items: Array = _result
		for item: Variant in items:
			messages.append(str(item))
	else:
		messages.append("run() must return Array[String], got %s" % type_string(typeof(_result)))

	test.cleanup()
	await process_frame  # let queue_free() from cleanup run inside this file's error window
	var errors: Array[String] = pending
	errors.append_array(_log.take_errors())
	messages.append_array(match_errors(errors, test.allowances))
	report.notes.append_array(test.notes)
	report.checks = test.checks
	return report


## Runs test.run() and stores its result; awaiting also works when run() is not a coroutine.
func _invoke(test: TestCase, token: int) -> void:
	var value: Variant = await test.run()
	if token != _run_token:
		return
	_result = value
	_done = true


func _print_warnings(warnings: Array[String]) -> void:
	for w: String in warnings:
		print("  ! %s" % w)


func _finish(code: int) -> void:
	OS.remove_logger(_log)
	quit(code)


## ["--a", "--b=1", "x"] -> {"a": "", "b": "1"}.
static func parse_args(argv: PackedStringArray) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for raw: String in argv:
		if not raw.begins_with("--"):
			continue
		var body: String = raw.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			out[body] = ""
		else:
			out[body.substr(0, eq)] = body.substr(eq + 1)
	return out
