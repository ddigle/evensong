extends "res://tests/test_net_session.gd"
## M4b: the real combat sessions (separate processes over localhost ENet, like tests/test_net_session.gd,
## whose helpers and checks this file uses): "fight" (two players and a late third against three heretics:
## an arrow kill, a down and a revive, a late joiner mid-fight), "fight4" (four players in one fight) and
## (M4-fix) "fightlag" (a lagging, lossy client struck while it stands still).
## Kept in a file of its own so each file stays inside the runner's time limit per file. The runner flags
## of test_net_session.gd apply (--net-exe, --net-keep; --net-sessions=fight or fight4 runs one of them).


func run() -> Array[String]:
	var args: Dictionary[String, String] = Runner.parse_args(OS.get_cmdline_user_args())
	_exe = OS.get_executable_path()
	if args.has("net-exe"):
		var path: String = args["net-exe"]
		_exe = path if path.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(path)
		_use_path = false
		note("children run %s" % _exe)
		if not check(FileAccess.file_exists(_exe), "--net-exe %s exists" % _exe):
			return failures
	_keep = args.has("net-keep")
	_run_dir = ProjectSettings.globalize_path("user://net_test").path_join("fight_%d_%d" % [OS.get_process_id(),
		Time.get_ticks_msec()])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	var t0: int = Time.get_ticks_msec()
	var only_arg: String = args.get("net-sessions", "")
	var only: PackedStringArray = only_arg.split(",", false)
	if only.is_empty() or only.has("fight"):
		await _session_fight()
	if only.is_empty() or only.has("fight4"):
		await _session_fight4()
	if only.is_empty() or only.has("fightlag"):
		await _session_fightlag()
	_check_logs()
	note("fight sessions took %.1f s; run folder %s" % [(Time.get_ticks_msec() - t0) / 1000.0,
		_run_dir if (_keep or not failures.is_empty()) else "(removed)"])
	if failures.is_empty() and not _keep:
		_remove_dir(_run_dir)
	return failures
