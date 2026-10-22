class_name InputGate
extends RefCounted
## Host-side check of one client's input frames. Clients only send what they pressed; the host
## decides what happens (● host-authoritative, game-concept §13).
##
## - Frames are handled in seq order, once each. Older or repeated frames (every packet repeats
##   the unacknowledged ones) are ignored. `last_seq` is the ack the host sends back.
## - Directions are clamped to -1..1 per axis and Movement normalises diagonals, so no frame moves
##   faster than Config.WALK_SPEED. Codes outside the 9 valid ones never become frames. Frames
##   carry no facing: the host derives it (Player.apply_input -> Movement.facing_for).
## - Rate limit: a token per host tick of real time (take(elapsed_ticks), the session measures it
##   with ticks_between()), at most Config.NET_INPUT_BURST saved up beyond the frames waiting. A
##   frame without a token waits (it is not acknowledged, so the client keeps sending it); a client
##   cannot move more ticks than real time allows, only catch up a short burst after jitter. Tokens
##   only ever come from elapsed real time (at once or, below, a little later as hitch credit), so
##   that bound holds whatever the client sends.
## - Host hitch: when the host misses ticks (a long frame), the real time it lost still refills the
##   tokens (at most MAX_REFILL_TICKS per take), and the frames waiting lift the saving cap: they
##   really are that old. The frames a client sent during the hitch are usually not here yet, though:
##   Godot runs its catch-up physics ticks first and polls the network after them (SceneTree.process),
##   so the tick that measures the lost time sees an almost empty queue. The part of the refill the
##   cap cut off is therefore kept as hitch credit for HITCH_CREDIT_TICKS ticks of real time, and
##   frames that arrive in that time spend it. Either way a walking client's queue drains back to the
##   jitter target instead of staying behind for as long as it keeps walking.
## - Smoothing: one frame per tick while at most Config.NET_INPUT_JITTER_FRAMES wait; when it falls
##   behind, more, but at most Config.NET_INPUT_CATCH_UP_FRAMES per tick, so the other players see a
##   client walk at an even 60 Hz on the host and catch up at a few times walking speed, not jump.
## - Bounded: at most 2 * NET_MAX_FRAMES_PER_PACKET frames wait; packets beyond that are dropped.
## - M4-fix: while a member's timers run the host may hand frames back (put_back): its clock rule
##   (SessionHost.run_client_frames) keeps them from running ahead of host time, which the catch-up above
##   would otherwise allow with saved-up tokens.

## Most host ticks one take() refills: the queue holds at most this many frames anyway.
const MAX_REFILL_TICKS: int = 2 * Config.NET_MAX_FRAMES_PER_PACKET
## Ticks of real time a hitch credit lasts. The frames a hitch held up are in the host's socket when
## it wakes and Godot polls them one frame later; 0.5 s also covers a few in flight.
const HITCH_CREDIT_TICKS: float = 30.0

var last_seq: int = 0
var tokens: float = float(Config.NET_INPUT_BURST)
var waiting: Array[NetProtocol.InputFrame] = []
## Real time (ticks) a missed-tick refill could not add because of the cap (see the class comment).
var hitch_credit: float = 0.0

var packets: int = 0
var bad_packets: int = 0
var bad_frames: int = 0
var duplicates: int = 0
var applied: int = 0
var gaps: int = 0
var rate_limited_ticks: int = 0
var overflow: int = 0
## Most frames ever waiting at a take().
var waiting_peak: int = 0
## take() calls, and the real time (ticks) they refilled in all: on a steady host about one per take.
var takes: int = 0
var refilled: float = 0.0
## Hitch credit turned into tokens, in all.
var credit_used: float = 0.0
## M4-fix: frames handed back by put_back (the host's clock rule), in all.
var held: int = 0

var _credit_left: float = 0.0


## Host ticks of real time between two Time.get_ticks_usec() readings (never negative).
static func ticks_between(from_usec: int, to_usec: int) -> float:
	return maxf(0.0, float(to_usec - from_usec) * Config.NET_TICK_RATE / 1000000.0)


## Takes a decoded packet: new frames join the queue in seq order.
func receive(packet: NetProtocol.InputPacket) -> void:
	packets += 1
	if not packet.ok:
		bad_packets += 1
		return
	bad_frames += packet.bad_frames
	var newest: int = last_seq
	if not waiting.is_empty():
		var last_waiting: NetProtocol.InputFrame = waiting.back()
		newest = last_waiting.seq
	for frame: NetProtocol.InputFrame in packet.frames:
		if frame.seq <= newest:
			duplicates += 1
			continue
		if waiting.size() >= 2 * Config.NET_MAX_FRAMES_PER_PACKET:
			overflow += 1
			continue
		frame.dir = Vector2i(clampi(frame.dir.x, -1, 1), clampi(frame.dir.y, -1, 1))
		waiting.append(frame)
		newest = frame.seq


## One host tick: returns the frames to simulate now, in order. `elapsed_ticks` = host ticks of real
## time since the previous take() (the session measures it with ticks_between(); about 1 on a steady
## host, more after a hitch, about 0 for the catch-up ticks Godot runs right after one).
func take(elapsed_ticks: float = 1.0) -> Array[NetProtocol.InputFrame]:
	takes += 1
	waiting_peak = maxi(waiting_peak, waiting.size())
	_refill(clampf(elapsed_ticks, 0.0, float(MAX_REFILL_TICKS)))
	var out: Array[NetProtocol.InputFrame] = []
	var want: int = mini(waiting.size(), maxi(1, waiting.size() - Config.NET_INPUT_JITTER_FRAMES))
	want = mini(want, Config.NET_INPUT_CATCH_UP_FRAMES)
	while out.size() < want:
		if tokens < 1.0:
			rate_limited_ticks += 1
			break
		var frame: NetProtocol.InputFrame = waiting.pop_front()
		if frame.seq != last_seq + 1:
			gaps += 1
		last_seq = frame.seq
		tokens -= 1.0
		applied += 1
		out.append(frame)
	return out


## M4-fix: frames take() just handed out that the host did not run this tick (SessionHost.run_client_frames:
## they would have run a timed member ahead of host time) go back to the front of the queue, in order, their
## tokens refunded and the acknowledgement back to before them, so the next take() hands them out again.
func put_back(frames: Array[NetProtocol.InputFrame]) -> void:
	if frames.is_empty():
		return
	var back: Array[NetProtocol.InputFrame] = frames.duplicate()
	back.append_array(waiting)
	waiting = back
	last_seq = frames[0].seq - 1
	tokens += frames.size()
	applied -= frames.size()
	held += frames.size()


## Adds `refill` ticks of real time to the tokens, up to the saving cap (burst + frames waiting). Of a
## refill longer than one tick (missed host ticks), what the cap cut off becomes hitch credit; credit
## lifts the cap for frames that wait above it until HITCH_CREDIT_TICKS of real time have passed.
## Every token still comes from real time once: added now, or later from the credit, never both.
func _refill(refill: float) -> void:
	refilled += refill
	var cap: float = float(Config.NET_INPUT_BURST + waiting.size())
	var added: float = minf(refill, maxf(cap - tokens, 0.0))
	tokens = minf(tokens + added, cap)
	_credit_left -= refill
	if _credit_left <= 0.0:
		hitch_credit = 0.0
	# Only the missed ticks count (not this tick's own share), and a newer hitch replaces an older
	# credit instead of adding to it: many slightly late ticks never save up a large credit.
	var cut: float = minf(refill - added, refill - 1.0)
	if cut > hitch_credit:
		hitch_credit = cut
		_credit_left = HITCH_CREDIT_TICKS
	if hitch_credit > 0.0 and tokens < cap:
		var used: float = minf(hitch_credit, cap - tokens)
		tokens += used
		hitch_credit -= used
		credit_used += used


func to_dict() -> Dictionary:
	return {
		"packets": packets, "bad_packets": bad_packets, "bad_frames": bad_frames, "duplicates": duplicates,
		"applied": applied, "gaps": gaps, "rate_limited_ticks": rate_limited_ticks, "overflow": overflow,
		"last_seq": last_seq, "waiting_peak": waiting_peak, "takes": takes, "refilled": snappedf(refilled, 0.01),
		"credit_used": snappedf(credit_used, 0.01), "held": held,
	}
