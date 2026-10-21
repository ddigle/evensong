extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (an announced error is never logged).


func run() -> Array[String]:
	allow_error("fixture: never logged")
	return failures
