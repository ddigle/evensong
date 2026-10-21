class_name InputGate
extends RefCounted
## Host-side check of one client's input frames. Clients only send what they pressed; the host
## decides what happens (● host-authoritative, game-concept §13).
##
## - Frames are handled in seq order, once each. Older or repeated frames (every packet repeats
##   the unacknowledged ones) are ignored. `last_seq` is the ack the host sends back.
## - Directions are clamped to -1..1 per axis and Movement normalises diagonals, so no frame moves
##   faster than Config.WALK_SPEED. Codes outside the 36 valid ones never become frames.
## - Rate limit: a token per host tick, at most Config.NET_INPUT_BURST saved up. A frame without a
##   token waits (it is not acknowledged, so the client keeps sending it); a client cannot move
##   more ticks than real time allows, only catch up a short burst after jitter.
## - Smoothing: one frame per tick while at most Config.NET_INPUT_JITTER_FRAMES wait, more when it
##   falls behind, so the other players see a client walk at an even 60 Hz on the host.
## - Bounded: at most 2 * NET_MAX_FRAMES_PER_PACKET frames wait; packets beyond that are dropped.

var last_seq: int = 0
var tokens: float = float(Config.NET_INPUT_BURST)
var waiting: Array[NetProtocol.InputFrame] = []

var packets: int = 0
var bad_packets: int = 0
var bad_frames: int = 0
var duplicates: int = 0
var applied: int = 0
var gaps: int = 0
var rate_limited_ticks: int = 0
var overflow: int = 0


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
		frame.facing = clampi(frame.facing, 0, 3)
		waiting.append(frame)
		newest = frame.seq


## One host tick: returns the frames to simulate now, in order.
func take() -> Array[NetProtocol.InputFrame]:
	tokens = minf(tokens + 1.0, float(Config.NET_INPUT_BURST))
	var out: Array[NetProtocol.InputFrame] = []
	var want: int = mini(waiting.size(), maxi(1, waiting.size() - Config.NET_INPUT_JITTER_FRAMES))
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


func to_dict() -> Dictionary:
	return {
		"packets": packets, "bad_packets": bad_packets, "bad_frames": bad_frames, "duplicates": duplicates,
		"applied": applied, "gaps": gaps, "rate_limited_ticks": rate_limited_ticks, "overflow": overflow,
		"last_seq": last_seq,
	}
