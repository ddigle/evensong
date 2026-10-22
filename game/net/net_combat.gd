class_name NetCombat
extends RefCounted
## M4b, a session client: the combat of the map this client is on, as the host sends it (the host owns it:
## net/session_host.gd steps one Arena per map). Kept as tracks and drawn through a mirror Arena
## (Arena.mirror, never stepped) that a CombatView draws like offline.
##
## - Enemy batches (NetProtocol.EnemyBatch: every heretic of the map and the shrine's HP at a host tick,
##   unreliable while anything changes, a reliable keyframe after, and one right after a welcome / map
##   entry) become a track per heretic. A heretic missing from a batch is gone from that tick on.
## - Shot events (reliable): a shot let go (where, when, weapon, aim) and where and when it stopped. The
##   client flies it itself between the two along the same aim vector at the weapon's speed.
##
## Drawing time (PROVISIONAL rule, README "M4b 적 그리기"): like the other players (net/interpolation.gd),
## positions are drawn Config.NET_INTERP_DELAY_MS behind the newest host time this client knows (t_fresh =
## RemoteClock.host_tick_at(now), t_draw = t_fresh - the delay): heretics' positions, HP, hurt and death
## frames, and the shots of other players. Two things are drawn at t_fresh instead, without the delay:
## a heretic's attack (the wind-up, the knife raised = the telegraph: Config.NET_ENEMY_WINDUP_FRESH, so a
## player sees it as early as the wire allows and can still dodge) and this client's own shots (they appear
## as soon as the host's event is here, not a buffer later). An attack the delayed sample is still in when
## it is over at t_fresh shows the heretic chasing (the state after an attack).

## One received heretic state at a host tick (its timed state's start as a whole host tick).
class FoeSnap:
	extends RefCounted
	var tick: int = 0
	var e: NetProtocol.EnemyState
	var since: int = 0


class FoeTrack:
	extends RefCounted
	var id: int = 0
	var snaps: Array[FoeSnap] = []
	## The host tick of the first batch it was missing from (-1 = still there).
	var gone_at: int = -1


class ShotTrack:
	extends RefCounted
	var id: int = 0
	var item: StringName = &""
	var kind: int = Combat.Kind.ARROW
	var owner: int = 255
	var tick: int = 0
	var origin: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 0.0
	var life: int = 0
	var end_tick: int = -1
	var end_pos: Vector2 = Vector2.ZERO

	## Where the shot is at host tick `t` (after tick t's step, like the host's), or Vector2.INF when it is
	## not in the air then (not let go yet, or stopped).
	func pos_at(t: float) -> Vector2:
		var steps: float = t - tick + 1.0
		if steps < 0.0:
			return Vector2.INF
		if end_tick >= 0:
			if t >= end_tick:
				return Vector2.INF
			if t > end_tick - 1:
				return raw(end_tick - tick).lerp(end_pos, t - (end_tick - 1))
		elif steps > life + 1:
			return Vector2.INF
		return raw(steps)

	func raw(steps: float) -> Vector2:
		return origin + dir * (speed / Config.NET_TICK_RATE) * clampf(steps, 0.0, float(life))

	## Gone for good by host tick `t`.
	func over(t: float) -> bool:
		return (end_tick >= 0 and t >= end_tick) or t - tick + 1.0 > life + 1


var map: int = -1
var data: WorldData
## What CombatView draws (filled by sample()).
var arena: Arena
var foes: Dictionary[int, FoeTrack] = {}
var shots: Dictionary[int, ShotTrack] = {}
## The shrine's HP by host tick ([tick, hp] pairs, oldest first) and the tick of its last drop.
var shrine: Array[Vector2i] = []
var shrine_hit_tick: int = -1000000
var local_slot: int = -1
var last_tick: int = -1
## The newest batch's body (without the tick): what the host's arena looked like then (tests hash it).
var last_body: PackedByteArray = PackedByteArray()
var last_batch: NetProtocol.EnemyBatch
## Counters (results): batches and keyframes taken, stale ones, ones for another map, shot events taken,
## and the HP each heretic was seen with, in order (consecutive repeats dropped; tests compare it with the
## host's hits).
var batches: int = 0
var keyframes: int = 0
var stale: int = 0
var other_map: int = 0
var shot_events: int = 0
var foe_hp: Dictionary[int, Array] = {}


## Starts over on map `p_map` (its data): no heretic, no shot until the host's keyframe.
func reset(p_map: int, p_data: WorldData) -> void:
	map = p_map
	data = p_data
	arena = Arena.mirror(p_data)
	foes.clear()
	shots.clear()
	shrine.clear()
	shrine_hit_tick = -1000000
	last_tick = -1
	last_body = PackedByteArray()
	last_batch = null


## A batch (or keyframe) from the host. False when it is for another map (it is skipped then: a batch
## sent before this client moved can come after its map entry on another channel).
func on_batch(b: NetProtocol.EnemyBatch, payload: PackedByteArray, keyframe: bool) -> bool:
	if b.map != map:
		other_map += 1
		return false
	if b.tick <= last_tick:
		stale += 1
		return true
	last_tick = b.tick
	last_body = payload.slice(4)
	last_batch = b
	if keyframe:
		keyframes += 1
	else:
		batches += 1
	var seen: Dictionary[int, bool] = {}
	for e: NetProtocol.EnemyState in b.enemies:
		seen[e.id] = true
		var tr: FoeTrack = foes.get(e.id, null)
		if tr == null:
			tr = FoeTrack.new()
			tr.id = e.id
			foes[e.id] = tr
		var s: FoeSnap = FoeSnap.new()
		s.tick = b.tick
		s.e = e
		s.since = b.tick - ((b.tick - e.since) & 0xFFFF) if NetProtocol.timed_state(e.state) else b.tick
		tr.snaps.append(s)
		while tr.snaps.size() > 64:
			tr.snaps.pop_front()
		_note_hp(e.id, e.hp)
	for id: int in foes:
		if not seen.has(id) and foes[id].gone_at < 0:
			foes[id].gone_at = b.tick
	if not shrine.is_empty():
		var before: Vector2i = shrine.back()
		if b.shrine_hp < before.y:
			shrine_hit_tick = b.tick
	shrine.append(Vector2i(b.tick, b.shrine_hp))
	while shrine.size() > 32:
		shrine.pop_front()
	return true


func _note_hp(id: int, hp: int) -> void:
	var seen: Array = foe_hp.get(id, [])
	var last: int = seen.back() if not seen.is_empty() else -1
	if last != hp:
		seen.append(hp)
	foe_hp[id] = seen
	if foe_hp.size() > 64:
		foe_hp.erase(foe_hp.keys()[0])


## The HP heretic `id` was seen with, in order (tests).
func hp_seen(id: int) -> Array:
	var seen: Array = foe_hp.get(id, [])
	return seen


## Shot events from the host. False when they are for another map.
func on_shots(s: NetProtocol.ShotEvents) -> bool:
	if s.map != map:
		other_map += 1
		return false
	for e: NetProtocol.ShotEvent in s.events:
		shot_events += 1
		if e.kind == NetProtocol.ShotEvent.Kind.SPAWN:
			var a: Combat.Attack = Combat.attack_for(e.item)
			var t: ShotTrack = ShotTrack.new()
			t.id = e.id
			t.item = e.item
			t.kind = a.kind
			t.owner = e.owner
			t.tick = e.tick
			t.origin = e.pos
			t.dir = Combat.aim_vector(e.aim)
			t.speed = a.speed
			t.life = a.life_ticks()
			shots[e.id] = t
		elif shots.has(e.id):
			shots[e.id].end_tick = e.tick
			shots[e.id].end_pos = e.pos
	return true


## Fills the mirror arena for drawing at host time `t_fresh` (the newest this client knows) with positions
## `delay` ticks behind it (see the class comment).
func sample(t_fresh: float, delay: float) -> void:
	if arena == null:
		return
	var t_draw: float = t_fresh - delay
	arena.heretics.clear()
	for id: int in foes.keys():
		var h: HereticSim = sample_foe(foes[id], t_draw, t_fresh)
		if h == null and foes[id].gone_at >= 0 and t_draw >= foes[id].gone_at:
			foes.erase(id)
		elif h != null:
			arena.heretics.append(h)
	arena.heretics.sort_custom(func(a: HereticSim, b: HereticSim) -> bool: return a.id < b.id)
	arena.shots.clear()
	for id: int in shots.keys():
		var tr: ShotTrack = shots[id]
		var t: float = t_fresh if tr.owner == local_slot else t_draw
		if tr.over(t):
			shots.erase(id)
			continue
		var p: Vector2 = tr.pos_at(t)
		if p == Vector2.INF:
			continue
		var s: Arena.Shot = Arena.Shot.new()
		s.id = tr.id
		s.kind = tr.kind
		s.dir = tr.dir
		s.pos = p
		s.item = tr.item
		arena.shots.append(s)
	arena.shrine_hp = shrine_hp_at(t_draw)
	arena.shrine_flash = maxi(Config.HIT_FLASH_TICKS - floori(t_draw - shrine_hit_tick), 0) if t_draw >= shrine_hit_tick else 0


func shrine_hp_at(t: float) -> int:
	if shrine.is_empty():
		return Config.SHRINE_HP if arena != null and arena.shrine_rect().has_area() else 0
	var hp: int = shrine[0].y
	for v: Vector2i in shrine:
		if v.x <= t:
			hp = v.y
	return hp


## One heretic as drawn at `t_draw` (its wind-up at `t_fresh`), or null (not there yet, or gone).
static func sample_foe(tr: FoeTrack, t_draw: float, t_fresh: float) -> HereticSim:
	if tr.snaps.is_empty() or (tr.gone_at >= 0 and t_draw >= tr.gone_at):
		return null
	while tr.snaps.size() >= 2 and tr.snaps[1].tick <= t_draw:
		tr.snaps.pop_front()
	var a: FoeSnap = tr.snaps[0]
	var b: FoeSnap = tr.snaps[1] if tr.snaps.size() > 1 else null
	var h: HereticSim = HereticSim.new()
	h.id = tr.id
	h.pos = a.e.pos
	if b != null and t_draw > a.tick:
		h.pos = a.e.pos.lerp(b.e.pos, clampf((t_draw - a.tick) / float(b.tick - a.tick), 0.0, 1.0))
	h.home = h.pos
	h.facing = a.e.facing
	h.walking = a.e.walking
	h.state = a.e.state
	h.hp = a.e.hp
	h.flash_ticks = maxi(a.e.flash - maxi(floori(t_draw - a.tick), 0), 0)
	h.state_ticks = maxi(floori(t_draw - a.since), 0) if NetProtocol.timed_state(a.e.state) else 0
	h.clock = maxi(floori(t_draw), 0)
	if Config.NET_ENEMY_WINDUP_FRESH:
		var n: FoeSnap = tr.snaps.back()
		var src: FoeSnap = null
		if n.e.state == HereticSim.State.ATTACK:
			src = n
		elif a.e.state == HereticSim.State.ATTACK:
			src = a
		if src != null:
			var st: int = floori(t_fresh - src.since)
			if st >= 0 and st < HereticSim.attack_ticks(RigData.sheet_row(src.e.facing)):
				h.state = HereticSim.State.ATTACK
				h.state_ticks = st
				h.facing = src.e.facing
				h.walking = false
			elif st >= 0 and a.e.state == HereticSim.State.ATTACK:
				h.state = HereticSim.State.CHASE
				h.state_ticks = 0
				h.walking = n.e.walking
	return h


## Anything fighting in the newest batch (a heretic not idle at home) or a shot in the air.
func fighting() -> bool:
	if not shots.is_empty():
		return true
	if last_batch == null:
		return false
	for e: NetProtocol.EnemyState in last_batch.enemies:
		if e.state != HereticSim.State.IDLE or e.walking:
			return true
	return false


## md5 of the newest batch's body (the host hashes its arena the same way, SessionHost.combat_hash).
func latest_hash() -> String:
	if last_body.is_empty():
		return ""
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(last_body)
	return ctx.finish().hex_encode()


## The live heretics' positions as drawn last (bots aim at them).
func foe_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if arena == null:
		return out
	for h: HereticSim in arena.heretics:
		if h.alive():
			out.append(h.pos)
	return out


func to_dict() -> Dictionary:
	var hp: Dictionary = {}
	for id: int in foe_hp:
		hp[str(id)] = foe_hp[id]
	return {"map": map, "batches": batches, "keyframes": keyframes, "stale": stale, "other_map": other_map,
		"shot_events": shot_events, "hash": latest_hash(), "foe_hp": hp,
		"heretics": last_batch.enemies.size() if last_batch != null else 0,
		"shrine_hp": last_batch.shrine_hp if last_batch != null else -1}
