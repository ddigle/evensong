extends "res://tests/base_test.gd"
## Runner self-test fixture, run alone (tests/test_core.gd: --prefix=late_). Not a game test.
## Expected: the file itself PASSES, then "FAIL (after the last file)" and exit code 1. It leaves a
## process_frame callback that logs one error on the 6th frame, after this file's window (cleanup +
## SETTLE_FRAMES) but inside the runner's FINAL_SETTLE_FRAMES.

const ERROR_FRAME: int = 6


func run() -> Array[String]:
	check_eq(1 + 1, 2, "addition")
	tree.process_frame.connect(_error_on_call(ERROR_FRAME))
	return failures


## A callable that logs one error on its n-th call. Made in a static function so it does not hold
## this test instance.
static func _error_on_call(n: int) -> Callable:
	var calls: Array[int] = [0]
	return func() -> void:
		calls[0] += 1
		if calls[0] == n:
			push_error("fixture: error after the last file")
