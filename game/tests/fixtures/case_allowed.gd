extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: PASS (both errors are announced).


func run() -> Array[String]:
	allow_error("fixture: announced push_error")
	allow_error("fixture_missing_child")
	push_error("fixture: announced push_error")
	var node: Node = Node.new()
	node.get_node("fixture_missing_child")
	node.free()
	return failures
