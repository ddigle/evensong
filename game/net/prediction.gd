class_name Prediction
extends RefCounted
## Client-side prediction of the local player (spike RESULTS §5: over Tailscale the client's own
## character lagged by a round trip when only the host moved it).
##
## Every tick the client steps its own player at once with the same Movement.step the host uses and
## records the input frame. Frames are numbered (seq) only when they matter: while moving and on
## the first idle tick after moving (the stop). Standing still records nothing, so an idle client
## sends nothing.
## When a host state for this player arrives (pos after frame `ack`), reconcile() starts from it
## and replays the frames the host has not handled yet. Same code, same float32 numbers, same
## order: the replay lands where the prediction already was, and `max_error_px` stays 0. A frame the
## host never applied, or a host that disagrees for any other reason, shows up as an error and the
## host's position wins.

class Pending:
	extends RefCounted
	var frame: NetProtocol.InputFrame
	var pos_after: Vector2 = Vector2.ZERO


var data: WorldData
var pos: Vector2 = Vector2.ZERO
var facing: int = RigData.Dir.SOUTH
var walking: bool = false
var next_seq: int = 1
var pending: Array[Pending] = []

## Last host state for this player: its ack and position.
var base_seq: int = 0
var base_pos: Vector2 = Vector2.ZERO

var frames: int = 0
var reconciles: int = 0
var corrections: int = 0
var max_error_px: float = 0.0
var stale: int = 0
var dropped_unsent: int = 0

var _last_dir: Vector2i = Vector2i.ZERO


func setup(p_data: WorldData, p_pos: Vector2, p_facing: int, ack: int) -> void:
	data = p_data
	pos = p_pos
	facing = p_facing
	base_pos = p_pos
	base_seq = ack
	next_seq = ack + 1
	pending.clear()


## One local tick. Returns the recorded frame, or null when nothing was recorded (idle).
func step(dir: Vector2i) -> NetProtocol.InputFrame:
	facing = Movement.facing_for(dir, facing)
	pos = Movement.step(data, pos, dir, Config.NET_TICK)
	walking = dir != Vector2i.ZERO
	var recorded: bool = dir != Vector2i.ZERO or _last_dir != Vector2i.ZERO
	_last_dir = dir
	if not recorded:
		return null
	var p: Pending = Pending.new()
	p.frame = NetProtocol.InputFrame.new(next_seq, dir, facing)
	p.pos_after = pos
	next_seq += 1
	pending.append(p)
	frames += 1
	# A host that stops acknowledging (gone, or far behind) must not grow this without end.
	while pending.size() > 4 * Config.NET_MAX_FRAMES_PER_PACKET:
		pending.pop_front()
		dropped_unsent += 1
	return p.frame


func has_unacked() -> bool:
	return not pending.is_empty()


## The newest unacknowledged frames (at most one packet), oldest first, consecutive.
func frames_to_send() -> Array[NetProtocol.InputFrame]:
	var out: Array[NetProtocol.InputFrame] = []
	var first: int = maxi(0, pending.size() - Config.NET_MAX_FRAMES_PER_PACKET)
	for i: int in range(first, pending.size()):
		out.append(pending[i].frame)
	return out


## Applies the host's state for this player. Returns the prediction error in px (how far the
## predicted position after frame `ack` was from the host's), or -1 for a stale state.
func reconcile(state: NetProtocol.PlayerState) -> float:
	if state.ack < base_seq:
		stale += 1
		return -1.0
	var predicted: Vector2 = base_pos
	if state.ack > base_seq:
		predicted = state.pos  # a frame we no longer hold: nothing to compare
		for p: Pending in pending:
			if p.frame.seq == state.ack:
				predicted = p.pos_after
				break
	var error: float = predicted.distance_to(state.pos)
	reconciles += 1
	if error > 0.0:
		corrections += 1
	max_error_px = maxf(max_error_px, error)
	base_seq = state.ack
	base_pos = state.pos
	while not pending.is_empty() and pending[0].frame.seq <= state.ack:
		pending.pop_front()
	# Replay what the host has not handled yet, from the host's position.
	pos = state.pos
	facing = state.facing
	for p: Pending in pending:
		pos = Movement.step(data, pos, p.frame.dir, Config.NET_TICK)
		facing = p.frame.facing
		p.pos_after = pos
	return error


func to_dict() -> Dictionary:
	return {
		"frames": frames, "reconciles": reconciles, "corrections": corrections, "max_error_px": max_error_px,
		"stale": stale, "pending": pending.size(), "dropped_unsent": dropped_unsent, "next_seq": next_seq,
	}
