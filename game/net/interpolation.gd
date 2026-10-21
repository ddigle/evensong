class_name Interpolation
extends RefCounted
## Another player's states as received from the host, drawn a little in the past so there is
## always a newer state to move towards (Config.NET_INTERP_DELAY_MS, 2 batch intervals at 20 Hz:
## one lost batch does not stop anybody).
##
## Times are host ticks (float). sample(t) interpolates the position linearly between the states
## around t and takes facing and walking from the older one; before the first state it holds the
## first, after the last it holds the last (no guessing ahead, so a stop is exact).
## After a quiet spell (no batches while nobody moved) the first new state would otherwise be
## stretched over the whole quiet time; push() inserts the previous state again one batch interval
## earlier, so the player starts moving when they really did.

const MAX_SNAPS: int = 64

class Snap:
	extends RefCounted
	var tick: float = 0.0
	var pos: Vector2 = Vector2.ZERO
	var facing: int = RigData.Dir.SOUTH
	var walking: bool = false

	func copy_at(t: float) -> Snap:
		var s: Snap = Snap.new()
		s.tick = t
		s.pos = pos
		s.facing = facing
		s.walking = walking
		return s


var snaps: Array[Snap] = []
var interval_ticks: float = float(Config.NET_TICK_RATE) / Config.NET_STATE_HZ


func push(tick: int, state: NetProtocol.PlayerState) -> void:
	var s: Snap = Snap.new()
	s.tick = float(tick)
	s.pos = state.pos
	s.facing = state.facing
	s.walking = state.walking
	if not snaps.is_empty():
		var last: Snap = snaps.back()
		if s.tick <= last.tick:
			return
		if s.tick - last.tick > 1.5 * interval_ticks:
			snaps.append(last.copy_at(s.tick - interval_ticks))
	snaps.append(s)
	while snaps.size() > MAX_SNAPS:
		snaps.pop_front()


func latest() -> Snap:
	return snaps.back() if not snaps.is_empty() else null


## State at host tick `t` (null before anything arrived). Drops states it will not need again.
func sample(t: float) -> Snap:
	if snaps.is_empty():
		return null
	while snaps.size() >= 2 and snaps[1].tick <= t:
		snaps.pop_front()
	var a: Snap = snaps[0]
	if snaps.size() == 1 or t <= a.tick:
		return a.copy_at(t)
	var b: Snap = snaps[1]
	var w: float = clampf((t - a.tick) / (b.tick - a.tick), 0.0, 1.0)
	var out: Snap = a.copy_at(t)
	out.pos = a.pos.lerp(b.pos, w)
	return out


## Estimate of the host's tick from the client's clock, from the batch stamps. The local side is
## wall time in ticks (now_ticks), not the client's physics tick count: a client process that
## stalls and then catches up several physics ticks at once would otherwise push the estimate ahead
## and draw past the newest state (seen with 10 processes on one machine).
## offset = host tick - local time when a batch arrives = true offset - network delay; the largest
## recent value is the least delayed. It decays very slowly so a clock drift or a route change
## cannot pin it, and the next batch above it resets it.
class RemoteClock:
	extends RefCounted
	const DECAY_PER_TICK: float = 0.002
	var offset: float = 0.0
	var known: bool = false
	var _last_local: float = 0.0

	func observe(host_tick: int, local_tick: float) -> void:
		var sample: float = float(host_tick) - local_tick
		if not known:
			offset = sample
			known = true
		else:
			offset = maxf(sample, offset - DECAY_PER_TICK * maxf(local_tick - _last_local, 0.0))
		_last_local = local_tick

	func host_tick_at(local_tick: float) -> float:
		return local_tick + offset

	## This machine's monotonic clock in ticks.
	static func now_ticks() -> float:
		return Time.get_ticks_usec() * Config.NET_TICK_RATE / 1000000.0
