extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: PASS.


func run() -> Array[String]:
	check_eq(1 + 1, 2, "addition")
	return failures
