extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (push_error after an await is still counted).


func run() -> Array[String]:
	await await_frames(2)
	push_error("fixture: error after await")
	return failures
