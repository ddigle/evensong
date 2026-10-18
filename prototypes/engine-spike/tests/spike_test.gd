extends RefCounted
## Base class for spike tests. Every test file is res://tests/test_<module>.gd and starts with
##   extends "res://tests/spike_test.gd"
## then overrides run(). run() may await (it is always awaited by the runner) and returns the
## failure messages; an empty array means pass. The check_* helpers append to `failures`, so
## the usual ending is `return failures`.
##
## The runner sets `tree` before run() and calls cleanup() afterwards, so nodes added with
## add_node() are freed even when the test fails.

var tree: SceneTree
var failures: Array[String] = []
var checks: int = 0

var _owned_nodes: Array[Node] = []


## Override this. Return `failures` (or any Array[String]).
func run() -> Array[String]:
	fail("run() is not overridden")
	return failures


func fail(message: String) -> void:
	failures.append(message)


## Same type and ==, except int/float compare as numbers and String/StringName as text.
static func values_equal(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta == tb:
		return a == b
	var numeric: Array[int] = [TYPE_INT, TYPE_FLOAT]
	if ta in numeric and tb in numeric:
		return float(a) == float(b)
	var text: Array[int] = [TYPE_STRING, TYPE_STRING_NAME]
	if ta in text and tb in text:
		return str(a) == str(b)
	return false


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	checks += 1
	var same: bool = values_equal(actual, expected)
	if not same:
		failures.append("%s: expected %s (%s), got %s (%s)" % [
			message, var_to_str(expected), type_string(typeof(expected)),
			var_to_str(actual), type_string(typeof(actual))])
	return same


func check_ne(actual: Variant, unexpected: Variant, message: String) -> bool:
	checks += 1
	var differs: bool = not values_equal(actual, unexpected)
	if not differs:
		failures.append("%s: did not expect %s" % [message, var_to_str(actual)])
	return differs


func check_near(actual: float, expected: float, tolerance: float, message: String) -> bool:
	checks += 1
	var ok: bool = absf(actual - expected) <= tolerance
	if not ok:
		failures.append("%s: expected %s +/- %s, got %s" % [message, expected, tolerance, actual])
	return ok


## Passes when `low <= actual <= high`. Handy for timings and budgets.
func check_between(actual: float, low: float, high: float, message: String) -> bool:
	checks += 1
	var ok: bool = actual >= low and actual <= high
	if not ok:
		failures.append("%s: expected %s..%s, got %s" % [message, low, high, actual])
	return ok


func check_not_null(value: Variant, message: String) -> bool:
	checks += 1
	var ok: bool = value != null
	if not ok:
		failures.append("%s: got null" % message)
	return ok


func check_has(container: Variant, item: Variant, message: String) -> bool:
	checks += 1
	var ok: bool = false
	if container is String and item is String:
		ok = (container as String).contains(item as String)
	elif container is Dictionary:
		ok = (container as Dictionary).has(item)
	elif typeof(container) >= TYPE_ARRAY:
		ok = item in container
	if not ok:
		failures.append("%s: %s not found in %s" % [message, var_to_str(item), str(container).left(200)])
	return ok


## Adds `node` under the root window and frees it in cleanup().
func add_node(node: Node) -> Node:
	_owned_nodes.append(node)
	tree.root.add_child(node)
	return node


## Lets the engine run `count` process frames (nodes get _ready/_process, deferred calls run).
func await_frames(count: int = 1) -> void:
	for i: int in count:
		await tree.process_frame


func await_physics_frames(count: int = 1) -> void:
	for i: int in count:
		await tree.physics_frame


func cleanup() -> void:
	for node: Node in _owned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_owned_nodes.clear()
