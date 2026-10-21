extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (never finishes within the runner's --timeout).


func run() -> Array[String]:
	await tree.create_timer(30.0).timeout
	return failures
