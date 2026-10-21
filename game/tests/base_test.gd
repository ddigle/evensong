extends RefCounted
## Base class for tests. Every test file is res://tests/test_<name>.gd and starts with
##   extends "res://tests/base_test.gd"
## then overrides run(). run() may await (the runner always awaits it) and returns the failure
## messages; an empty array means pass. The check_* helpers append to `failures`, so the usual
## ending is `return failures`.
##
## Errors: every engine error, push_error() and GDScript runtime error logged while the file runs
## (including cleanup) fails the file, unless announced with allow_error() first. An announced
## error that is not logged the announced number of times also fails the file.
##
## The runner sets `tree` before run() and calls cleanup() afterwards, so nodes added with
## add_node() are freed even when the test fails. A node left under the root any other way fails
## the file (the runner frees it). note() lines are printed under the result.

## One announced error: logged errors whose text contains `pattern` are expected, `count` times
## (count < 0 = any number of times, including zero).
class Allowance:
	extends RefCounted
	var pattern: String = ""
	var count: int = 1
	var seen: int = 0


var tree: SceneTree
var failures: Array[String] = []
var checks: int = 0
var notes: Array[String] = []
var allowances: Array[Allowance] = []

var _owned_nodes: Array[Node] = []


## Override this. Return `failures` (or any Array[String]).
func run() -> Array[String]:
	fail("run() is not overridden")
	return failures


func fail(message: String) -> void:
	failures.append(message)


## A result line printed by the runner under PASS/FAIL (timings, counts).
func note(text: String) -> void:
	notes.append(text)


## Announces an error the test is about to cause on purpose (see the class comment).
func allow_error(pattern: String, count: int = 1) -> void:
	var a: Allowance = Allowance.new()
	a.pattern = pattern
	a.count = count
	allowances.append(a)


## Same type and ==, except int/float compare as numbers and String/StringName as text.
static func values_equal(a: Variant, b: Variant) -> bool:
	var ta: int = typeof(a)
	var tb: int = typeof(b)
	if ta == tb:
		var same: bool = a == b
		return same
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		var fa: float = a
		var fb: float = b
		return fa == fb
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
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


## Passes when `low <= actual <= high`.
func check_between(actual: float, low: float, high: float, message: String) -> bool:
	checks += 1
	var ok: bool = actual >= low and actual <= high
	if not ok:
		failures.append("%s: expected %s..%s, got %s" % [message, low, high, actual])
	return ok


func check_has(container: Variant, item: Variant, message: String) -> bool:
	checks += 1
	var ok: bool = false
	if container is String and item is String:
		var text: String = container
		var part: String = item
		ok = text.contains(part)
	elif container is Dictionary:
		var dict: Dictionary = container
		ok = dict.has(item)
	elif container is Array:
		var arr: Array = container
		ok = arr.has(item)
	elif container is PackedStringArray:
		var strings: PackedStringArray = container
		ok = item is String and strings.has(str(item))
	if not ok:
		failures.append("%s: %s not found in %s" % [message, var_to_str(item), str(container).left(200)])
	return ok


## Adds `node` under the root window and frees it in cleanup().
func add_node(node: Node) -> Node:
	_owned_nodes.append(node)
	tree.root.add_child(node)
	return node


## Lets the engine run `count` process frames (nodes get _ready / _process, deferred calls run).
func await_frames(count: int = 1) -> void:
	for i: int in count:
		await tree.process_frame


func cleanup() -> void:
	for node: Node in _owned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_owned_nodes.clear()
