extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (GDScript runtime error: index out of range).


func run() -> Array[String]:
	var values: Array[int] = [1, 2]
	var i: int = values.size() + 1
	check_eq(values[i], 0, "never reached")
	return failures
