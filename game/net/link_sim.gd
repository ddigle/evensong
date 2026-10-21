class_name LinkSim
extends RefCounted
## Test-only bad link on a client (--net-lag=<ms> round trip, --net-loss=<percent>). ENet has no
## lag or loss switch (spike notes/net.md), so the client holds its unreliable traffic back itself:
## outgoing input packets and incoming state batches each wait lag/2 and are dropped with the given
## chance. Reliable control messages pass unchanged (they never get lost, only late, on a real link).
## Seeded, so a run drops the same packets every time. Off (pass-through) when both are 0.

class Delayed:
	extends RefCounted
	var due_ms: int = 0
	var call: Callable


var lag_ms: int = 0
var loss_percent: float = 0.0
var sent: int = 0
var dropped: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _queue: Array[Delayed] = []


func _init(p_lag_ms: int = 0, p_loss_percent: float = 0.0, p_seed: int = 1) -> void:
	lag_ms = maxi(p_lag_ms, 0)
	loss_percent = clampf(p_loss_percent, 0.0, 100.0)
	_rng.seed = p_seed


func is_active() -> bool:
	return lag_ms > 0 or loss_percent > 0.0


## Runs `call` after half the round trip, or never (loss). Pass-through when inactive.
func pass_through(call: Callable, now_ms: int) -> void:
	sent += 1
	if not is_active():
		call.call()
		return
	if loss_percent > 0.0 and _rng.randf() * 100.0 < loss_percent:
		dropped += 1
		return
	var d: Delayed = Delayed.new()
	d.due_ms = now_ms + lag_ms / 2
	d.call = call
	_queue.append(d)


## Runs everything that is due, in order.
func poll(now_ms: int) -> void:
	while not _queue.is_empty() and _queue[0].due_ms <= now_ms:
		var d: Delayed = _queue.pop_front()
		d.call.call()


func clear() -> void:
	_queue.clear()


func to_dict() -> Dictionary:
	return {"lag_ms": lag_ms, "loss_percent": loss_percent, "sent": sent, "dropped": dropped}
