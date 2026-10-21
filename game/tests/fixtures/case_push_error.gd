extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (push_error that was not announced).


func run() -> Array[String]:
	push_error("fixture: unannounced push_error")
	return failures
