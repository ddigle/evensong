class_name StateBroadcast
extends RefCounted
## Host: what to send on a batch tick (every NET_TICK_RATE / NET_STATE_HZ ticks). Spike RESULTS §5:
## MultiplayerSynchronizer "always" keeps sending while everyone stands, "on_change" costs more
## while moving, so the session batches all players into one packet itself:
##   - something changed since the last batch (position, facing, walking, ack, who is in) -> BATCH,
##     unreliable, to every client
##   - nothing changed, but the last batch was not followed by a keyframe -> KEYFRAME: the same
##     states once more, reliable, so a lost last batch cannot leave a client with an old position
##   - otherwise NOTHING: the session is quiet until someone moves again
## `quiet_violations` counts batches sent although nobody had walked and nobody had joined or left
## for QUIET_TICKS (the session tells it with note_activity()); it must stay 0.

enum Send { NOTHING, BATCH, KEYFRAME }

const QUIET_TICKS: int = 12

var batches: int = 0
var keyframes: int = 0
var quiet_violations: int = 0
## A batch went out and no keyframe after it yet.
var dirty: bool = false
## Encoded batch for the last decide() that returned BATCH or KEYFRAME.
var payload: PackedByteArray = PackedByteArray()

var _last_body: PackedByteArray = PackedByteArray()
var _last_activity_tick: int = 0


## Someone walked, joined or left at `tick`.
func note_activity(tick: int) -> void:
	_last_activity_tick = tick


func decide(tick: int, states: Array[NetProtocol.PlayerState]) -> Send:
	var encoded: PackedByteArray = NetProtocol.encode_states(tick, states)
	var body: PackedByteArray = encoded.slice(4)  # without the tick
	if body != _last_body:
		if tick - _last_activity_tick > QUIET_TICKS:
			quiet_violations += 1
		_last_body = body
		dirty = true
		batches += 1
		payload = encoded
		return Send.BATCH
	if dirty:
		dirty = false
		keyframes += 1
		payload = encoded
		return Send.KEYFRAME
	return Send.NOTHING
