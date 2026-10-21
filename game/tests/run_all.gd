extends SceneTree
## Test runner.
##
##   godot --headless --path game --script res://tests/run_all.gd
##   godot ... --script res://tests/run_all.gd -- --only=core,world     (test_core.gd, test_world.gd)
##   godot ... --script res://tests/run_all.gd -- --timeout=300         (seconds per file, default 120)
##   godot ... --script res://tests/run_all.gd -- --dir=res://tests/fixtures --prefix=case_
##                                                  (other folder / file prefix: the runner's self-test)
##   godot ... --script res://tests/run_all.gd -- --port-base=25000   (test port block, see below)
##
## Finds <dir>/<prefix>*.gd, instantiates each (they extend res://tests/base_test.gd), awaits
## run() -> Array[String] (failure messages; empty = pass) and prints one PASS / FAIL line per
## file plus its messages and notes.
##
## Errors count as failures: every message the engine logs as an error, from any thread (engine
## errors such as a null argument or a missing node, push_error(), GDScript runtime errors, shader
## errors), caught with an OS Logger, unless the test announced it with allow_error(). A file's
## window runs from its start until SETTLE_FRAMES frames after its cleanup(), so queue_free(),
## _exit_tree() and deferred calls it caused count against it. Also failures:
##   - errors logged before the first file (startup)
##   - errors logged between two files (only other threads can): charged to the next file, labelled
##     with the file that ran before; that file's allow_error() does not cover them
##   - a node a file left under the root after cleanup() (it should use add_node()). The runner
##     frees it, so it cannot log errors into the next file's window
##   - errors logged in the FINAL_SETTLE_FRAMES frames after the last file (timers, threads or
##     signal callbacks it left running), printed as "FAIL (after the last file)"
## Not caught: work a file leaves running that logs later than that (charged to whichever file is
## running then, or missed when it comes after the final frames). Warnings are printed, not counted.
##
## Test ports: the network tests use one block of Config.NET_TEST_PORT_COUNT UDP ports, chosen
## here once per run (port_first..port_last) and passed down (tests read Runner.port_first /
## port_last; child processes get explicit ports or --ports-from-parent). The base is --port-base=<n>,
## else the EVENSONG_TEST_PORT_BASE environment variable, else Config.NET_TEST_PORT_FIRST (24621) and,
## when that block is taken, the next blocks up (PORT_BLOCK_TRIES). A block is taken when another
## runner holds its lock (a TCP listener on 127.0.0.1:<base>, held for the whole run: binding it is
## atomic, and the OS frees it when that run ends or crashes) or when any of its UDP ports is in use
## (probed with UDPServer, which reports a busy port without an engine error). Remaining race: a
## program that is not this runner (or a runner without the lock) can still take a port of the
## block after the probe; the session tests then fail to host on it. An explicit base that is
## taken fails the run (FAIL (startup)) instead of moving on.
##
## Exit code: 0 = every file passed, 1 = any failure, load error, timeout, error outside the files
## or no test files.

const TestCase := preload("res://tests/base_test.gd")
const DEFAULT_DIR: String = "res://tests"
const DEFAULT_PREFIX: String = "test_"
const DEFAULT_TIMEOUT_SEC: float = 120.0
## Frames a file's error window stays open after cleanup() and after freeing nodes it left behind.
const SETTLE_FRAMES: int = 2
## Frames the runner waits after the last file before it takes the errors one last time.
const FINAL_SETTLE_FRAMES: int = 10
const PORT_ENV: String = "EVENSONG_TEST_PORT_BASE"
## Blocks tried from the default base when no base is given (24621, 24641, ... 24801).
const PORT_BLOCK_TRIES: int = 10

## The run's test port block (see the class comment). Static so test files reach it through their
## preload of this script.
static var port_first: int = Config.NET_TEST_PORT_FIRST
static var port_last: int = Config.NET_TEST_PORT_LAST


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
var _port_lock: TCPServer


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


## "<label>: <entry>" for every entry.
static func label_errors(errors: Array[String], label: String) -> Array[String]:
	var out: Array[String] = []
	for entry: String in errors:
		out.append("%s: %s" % [label, entry])
	return out


## Children of `parent` whose instance id is not in `before` (and that are not about to be freed).
static func new_children(parent: Node, before: Dictionary[int, bool]) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in parent.get_children():
		if not before.has(child.get_instance_id()) and not child.is_queued_for_deletion():
			out.append(child)
	return out


static func child_ids(parent: Node) -> Dictionary[int, bool]:
	var out: Dictionary[int, bool] = {}
	for child: Node in parent.get_children():
		out[child.get_instance_id()] = true
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
	var port_problem: String = _choose_ports(args)
	print("EVENSONG_TESTS start: %d file(s) in %s%s, ports %d-%d%s" % [files.size(), dir,
		"" if only.is_empty() else " (only %s)" % ",".join(only), port_first, port_last,
		"" if port_problem.is_empty() else " (not claimed)"])
	var failed: int = 0
	var startup: Array[String] = _log.take_errors()
	if not port_problem.is_empty():
		startup.append("test ports: %s" % port_problem)
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
	var previous: String = ""
	for file: String in files:
		var t0: int = Time.get_ticks_msec()
		var report: FileReport = await _run_file(dir.path_join(file), timeout_sec, previous)
		previous = file
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

	# Timers, threads or signal callbacks the last file left running: no next file would see them.
	for i: int in FINAL_SETTLE_FRAMES:
		await process_frame
	var late: Array[String] = _log.take_errors()
	_print_warnings(_log.take_warnings())
	if not late.is_empty():
		failed += 1
		print("FAIL (after the last file) %d error(s) logged after %s finished" % [late.size(), previous])
		for message: String in late:
			print("  - %s" % message)

	var extra: PackedStringArray = []
	if not startup.is_empty():
		extra.append("startup errors")
	if not late.is_empty():
		extra.append("errors after the last file")
	print("EVENSONG_TESTS done: %d passed, %d failed, %d checks, %d ms%s" % [
		files.size() - file_failures, file_failures, total_checks, Time.get_ticks_msec() - started,
		"" if extra.is_empty() else " (+ %s)" % ", ".join(extra)])
	_finish(1 if failed > 0 else 0)


func _run_file(path: String, timeout_sec: float, previous: String) -> FileReport:
	var report: FileReport = FileReport.new()
	var messages: Array[String] = report.messages
	# Errors logged between two files (none expected; only another thread can log there) fail this
	# file, labelled with the file that ran before. This file's allowances never cover them.
	var pending: Array[String] = label_errors(_log.take_errors(), "logged before this file started"
		if previous.is_empty() else "logged after %s finished, before this file started" % previous)
	var root_children: Dictionary[int, bool] = child_ids(root)
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
	for node: Node in new_children(root, root_children):
		messages.append("left %s (%s) under the root after cleanup(): use add_node() (the runner freed it)" % [
			node.name, node.get_class()])
		node.queue_free()
	for i: int in SETTLE_FRAMES:
		await process_frame  # _exit_tree() and deferred calls of what was freed still count here
	messages.append_array(pending)
	messages.append_array(match_errors(_log.take_errors(), test.allowances))
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
	if _port_lock != null:
		_port_lock.stop()
	OS.remove_logger(_log)
	quit(code)


## Sets port_first / port_last for this run. Returns "" or what went wrong.
func _choose_ports(args: Dictionary[String, String]) -> String:
	var count: int = Config.NET_TEST_PORT_COUNT
	if args.has("ports-from-parent"):
		var inherited: int = parse_port_base(args["ports-from-parent"], count)
		if inherited < 0:
			return "bad --ports-from-parent=%s" % args["ports-from-parent"]
		_set_ports(inherited)
		return ""  # the parent runner probed and holds this block
	var text: String = args.get("port-base", OS.get_environment(PORT_ENV))
	var bases: Array[int] = []
	if not text.is_empty():
		var base: int = parse_port_base(text, count)
		if base < 0:
			return "bad port base '%s' (--port-base or %s: 1..%d)" % [text, PORT_ENV, 65536 - count]
		bases.append(base)
	else:
		for i: int in PORT_BLOCK_TRIES:
			bases.append(Config.NET_TEST_PORT_FIRST + i * count)
	for base: int in bases:
		var lock: TCPServer = claim_port_block(base, count)
		if lock != null:
			_port_lock = lock
			_set_ports(base)
			return ""
	return "no free block of %d ports at %s (another run holds it, or a port is in use)" % [count,
		", ".join(PackedStringArray(bases.map(func(b: int) -> String: return str(b))))]


static func _set_ports(base: int) -> void:
	port_first = base
	port_last = base + Config.NET_TEST_PORT_COUNT - 1


## A port base from text, or -1 (the block must fit below 65536).
static func parse_port_base(text: String, count: int) -> int:
	if not text.is_valid_int() or text.to_int() < 1 or text.to_int() + count - 1 > 65535:
		return -1
	return text.to_int()


## Claims the block base..base+count-1: takes its lock (TCP 127.0.0.1:<base>) and checks every UDP
## port of it is free. Returns the held lock, or null (lock held by another run, or a port busy).
static func claim_port_block(base: int, count: int) -> TCPServer:
	var lock: TCPServer = TCPServer.new()
	if lock.listen(base, "127.0.0.1") != OK:
		return null
	if not udp_ports_free(base, count):
		lock.stop()
		return null
	return lock


## True if no UDP port in base..base+count-1 is in use (each bound and released once).
static func udp_ports_free(base: int, count: int) -> bool:
	for port: int in range(base, base + count):
		var probe: UDPServer = UDPServer.new()
		var err: Error = probe.listen(port)
		probe.stop()
		if err != OK:
			return false
	return true


## A UDP port in first..last (either order) nobody uses, or -1. No engine error for busy ports.
static func free_port(first: int, last: int) -> int:
	var step: int = 1 if last >= first else -1
	var port: int = first
	while port != last + step:
		if udp_ports_free(port, 1):
			return port
		port += step
	return -1


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
