extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (engine error that was not announced).


func run() -> Array[String]:
	var node: Node = Node.new()
	node.get_node("fixture_missing_child")
	node.free()
	return failures
