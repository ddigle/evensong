extends "res://tests/base_test.gd"
## Runner self-test fixture (tests/test_core.gd runs the runner on this folder). Not a game test. Expected: FAIL (leaves a node under the root without add_node()).
## The node logs an error on every frame from its 5th on. The runner frees it before that, so the
## error must never appear (otherwise it would also fail case_pass.gd, which runs next).

const NOISY_NODE: String = """extends Node

var frames: int = 0


func _process(_delta: float) -> void:
	frames += 1
	if frames >= 5:
		push_error("fixture: error from a node left under the root")
"""


func run() -> Array[String]:
	var script: GDScript = GDScript.new()
	script.source_code = NOISY_NODE
	check_eq(script.reload(), OK, "noisy node script compiles")
	var node: Node = Node.new()
	node.name = "ParkedNode"
	node.set_script(script)
	tree.root.add_child(node)
	return failures
