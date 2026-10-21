class_name Prediction
extends RefCounted
## Client-side prediction of the local player (spike RESULTS §5: over Tailscale the client's own
## character lagged by a round trip when only the host moved it).
##
## Every tick the client steps its own player at once with the rule the host uses (PlayerSim.step:
## movement, the look, M2b body actions) and records the input frame. Frames are numbered (seq) only
## when they matter to the host: while moving and on the first idle tick after moving (the stop), a
## frame carrying a request (use, pick up, select ...), every frame while a body action plays (the
## action is timed in frames on both sides) and a frame whose look turned the player. Standing still
## records nothing, so an idle client sends nothing.
## When a host state for this player arrives (state after frame `ack`), reconcile() starts from it and
## replays the frames the host has not handled yet. Same code, same float32 numbers, same order: the
## replay lands where the prediction already was, and `max_error_px` stays 0. A frame the host never
## applied, or a host that disagrees for any other reason (it refused a use, say), shows up as an
## error or a correction count and the host's state wins. The facing is not sent unless the player
## aims (the look): the host derives it with the same rule (Movement.facing_for), and
## `facing_corrections` counts states whose facing differed from the prediction for that frame;
## `action_corrections` the same for the body action (0 when both sides agree).

class Pending:
	extends RefCounted
	var frame: NetProtocol.InputFrame
	var after: PlayerSim


var data: WorldData
## The predicted state now.
var sim: PlayerSim = PlayerSim.new()
var next_seq: int = 1
var pending: Array[Pending] = []

## Last host state for this player and its ack.
var base_seq: int = 0
var base: PlayerSim = PlayerSim.new()

var frames: int = 0
var reconciles: int = 0
var corrections: int = 0
var max_error_px: float = 0.0
var facing_corrections: int = 0
var action_corrections: int = 0
var stale: int = 0
var dropped_unsent: int = 0

var _last_dir: Vector2i = Vector2i.ZERO

var pos: Vector2:
	get:
		return sim.pos
var facing: int:
	get:
		return sim.facing
var walking: bool:
	get:
		return sim.walking


func setup(p_data: WorldData, p_pos: Vector2, p_facing: int, ack: int) -> void:
	data = p_data
	sim = PlayerSim.new()
	sim.pos = p_pos
	sim.facing = p_facing
	base = sim.copy()
	base_seq = ack
	next_seq = ack + 1
	pending.clear()


## One local tick with a direction only (M1). Returns the recorded frame, or null (idle).
func step(dir: Vector2i) -> NetProtocol.InputFrame:
	return step_frame(NetProtocol.InputFrame.new(0, dir))


## One local tick: `frame` (look, request; a USE resolved into `anim` by the caller) is stepped at
## once. Returns it numbered when it was recorded (see the class comment), or null.
func step_frame(frame: NetProtocol.InputFrame) -> NetProtocol.InputFrame:
	var was_acting: bool = sim.action >= 0
	var facing_before: int = sim.facing
	sim.step(data, frame.dir, frame.look, frame.anim, frame.cell, Config.NET_TICK)
	var recorded: bool = frame.dir != Vector2i.ZERO or _last_dir != Vector2i.ZERO or frame.op != NetProtocol.Op.NONE \
		or was_acting or sim.action >= 0 or sim.facing != facing_before
	_last_dir = frame.dir
	if not recorded:
		return null
	frame.seq = next_seq
	var p: Pending = Pending.new()
	p.frame = frame
	p.after = sim.copy()
	next_seq += 1
	pending.append(p)
	frames += 1
	# A host that stops acknowledging (gone, or far behind) must not grow this without end.
	while pending.size() > 4 * Config.NET_MAX_FRAMES_PER_PACKET:
		pending.pop_front()
		dropped_unsent += 1
	return frame


func has_unacked() -> bool:
	return not pending.is_empty()


## The newest unacknowledged frames (at most one packet), oldest first, consecutive.
func frames_to_send() -> Array[NetProtocol.InputFrame]:
	var out: Array[NetProtocol.InputFrame] = []
	var first: int = maxi(0, pending.size() - Config.NET_MAX_FRAMES_PER_PACKET)
	for i: int in range(first, pending.size()):
		out.append(pending[i].frame)
	return out


## Unacknowledged frames carrying a request of kind `op` with a seq above `after_seq`, oldest first
## (the client re-applies its pending hotbar selections on top of an inventory from the host).
func pending_ops(op: int, after_seq: int) -> Array[NetProtocol.InputFrame]:
	var out: Array[NetProtocol.InputFrame] = []
	for p: Pending in pending:
		if p.frame.op == op and p.frame.seq > after_seq:
			out.append(p.frame)
	return out


## Applies the host's state for this player. Returns the prediction error in px (how far the
## predicted position after frame `ack` was from the host's), or -1 for a stale state.
func reconcile(state: NetProtocol.PlayerState) -> float:
	if state.ack < base_seq:
		stale += 1
		return -1.0
	var host: PlayerSim = PlayerSim.new()
	host.pos = state.pos
	host.facing = state.facing
	host.walking = state.walking
	host.action = state.action
	host.action_tick = state.action_tick
	var predicted: PlayerSim = base
	if state.ack > base_seq:
		predicted = host  # a frame we no longer hold: nothing to compare
		for p: Pending in pending:
			if p.frame.seq == state.ack:
				predicted = p.after
				break
	var error: float = predicted.pos.distance_to(state.pos)
	reconciles += 1
	if error > 0.0:
		corrections += 1
	if predicted.facing != state.facing:
		facing_corrections += 1
	if predicted.action != state.action or predicted.action_tick != state.action_tick:
		action_corrections += 1
	# The target tile is not replicated: keep the predicted one for the same action.
	host.action_cell = predicted.action_cell if predicted.action == host.action else sim.action_cell
	max_error_px = maxf(max_error_px, error)
	base_seq = state.ack
	base = host
	while not pending.is_empty() and pending[0].frame.seq <= state.ack:
		pending.pop_front()
	# Replay what the host has not handled yet, from the host's state, with the rule the host applies
	# to each frame.
	sim = host.copy()
	for p: Pending in pending:
		sim.step(data, p.frame.dir, p.frame.look, p.frame.anim, p.frame.cell, Config.NET_TICK)
		p.after = sim.copy()
	return error


func to_dict() -> Dictionary:
	return {
		"frames": frames, "reconciles": reconciles, "corrections": corrections, "max_error_px": max_error_px,
		"facing_corrections": facing_corrections, "action_corrections": action_corrections,
		"stale": stale, "pending": pending.size(), "dropped_unsent": dropped_unsent, "next_seq": next_seq,
	}
