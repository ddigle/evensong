class_name LinkSim
extends RefCounted
## Test-only bad link on a client (--net-lag=<ms> round trip, --net-loss=<percent>). ENet has no
## lag or loss switch (spike notes/net.md), so the client holds its unreliable traffic back itself:
## outgoing input packets and incoming state batches each wait lag/2 and are dropped with the given
## chance. Reliable control messages pass unchanged (they never get lost, only late, on a real link).
## Seeded, so a run drops the same packets every time. Off (pass-through) when both are 0.
## M10-fix: the reliable messages that go through delay() (the prayer's) are late like on a real lossy link: with the loss chance
## the first send is lost and ENet sends it again after its retransmission timeout (about a round trip plus RESEND_MARGIN_MS,
## doubling each time), and a reliable channel keeps its order (one held back holds back those after it).

class Delayed:
	extends RefCounted
	var due_ms: int = 0
	var call: Callable


## IMPL (M10-fix, test only): what ENet's retransmission timeout adds to the round trip (its 4 x the round trip's variance and a
## service tick; the first resend of a reliable message lost once comes a round trip plus this late).
const RESEND_MARGIN_MS: int = 50
## IMPL (M10-fix, test only): the most resends one message gets (a real ENet peer would time out; even at 100 % loss it arrives).
const RESEND_MAX: int = 8

var lag_ms: int = 0
var loss_percent: float = 0.0
var sent: int = 0
var dropped: int = 0
## M10-fix: reliable messages sent again (lost once or more on the simulated link) and the longest one held back (ms past lag / 2).
var resent: int = 0
var held_max_ms: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## M10-fix: its own generator, so the unreliable traffic drops the same packets as before.
var _resend_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _queue: Array[Delayed] = []
var _reliable: Array[Delayed] = []


func _init(p_lag_ms: int = 0, p_loss_percent: float = 0.0, p_seed: int = 1) -> void:
	lag_ms = maxi(p_lag_ms, 0)
	loss_percent = clampf(p_loss_percent, 0.0, 100.0)
	_rng.seed = p_seed
	_resend_rng.seed = p_seed + 7919


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


## M10b: runs `call` after half the round trip, never dropped (a reliable message is late on a bad link, never lost; the prayer
## messages go this way so a test's round trip has both halves: the turn's event down, the answer up). Pass-through when inactive.
## M10-fix: lost with the loss chance, it comes a retransmission timeout later (lag + RESEND_MARGIN_MS, doubling each time it is
## lost again), and never before one sent earlier (a reliable channel's order).
func delay(call: Callable, now_ms: int) -> void:
	sent += 1
	if not is_active():
		call.call()
		return
	var due: int = now_ms + lag_ms / 2
	var timeout: int = lag_ms + RESEND_MARGIN_MS
	var tries: int = 0
	while tries < RESEND_MAX and loss_percent > 0.0 and _resend_rng.randf() * 100.0 < loss_percent:
		tries += 1
		resent += 1
		due += timeout
		timeout *= 2
	if not _reliable.is_empty():
		due = maxi(due, _reliable[_reliable.size() - 1].due_ms)
	held_max_ms = maxi(held_max_ms, due - now_ms - lag_ms / 2)
	var d: Delayed = Delayed.new()
	d.due_ms = due
	d.call = call
	_reliable.append(d)


## Runs everything that is due, in order (the unreliable queue, then the reliable one).
func poll(now_ms: int) -> void:
	while not _queue.is_empty() and _queue[0].due_ms <= now_ms:
		var d: Delayed = _queue.pop_front()
		d.call.call()
	while not _reliable.is_empty() and _reliable[0].due_ms <= now_ms:
		var r: Delayed = _reliable.pop_front()
		r.call.call()


func clear() -> void:
	_queue.clear()
	_reliable.clear()


func to_dict() -> Dictionary:
	return {"lag_ms": lag_ms, "loss_percent": loss_percent, "sent": sent, "dropped": dropped, "resent": resent,
		"held_max_ms": held_max_ms}
