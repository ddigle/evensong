class_name NetBoss
extends RefCounted
## M12c, a session client: the boss fight of the dungeon as the host sends it (the host owns it: combat/boss_fight.gd on its dungeon arena).
## Kept as tracks and drawn through a mirror fight (BossFight.mirror, never stepped) that the dungeon's CombatView draws like offline
## (combat/boss_fight_view.gd); NetCombat owns it on the map whose snapshot brought a boss site.
##
## - The body: the enemy batch's boss block (NetProtocol.BossState) at its host tick, a track like a heretic's: drawn at t_draw (the buffer
##   behind the newest host time, M4b's rule), its HP, phase and marks the host's.
## - The fight's events (reliable, on the shot events message): an attack's start (BOSS_ATTACK: its tick, kind, where it stands, its direction,
##   a volley's bolts), an early stop (BOSS_STOP), a fire bolt let go and stopped (BOLT, BOLT_END), a burning circle (CIRCLE), a pillar's state
##   (PILLAR: its hits, its dust, rubble, and a refused blow, a landed blow or its debris landing at that tick).
##
## Drawing time (PROVISIONAL rule, README "M12c 보스 그리기"): the warnings are drawn at t_fresh, the newest host time this client knows, without
## the buffer's delay, like a heretic's wind-up (Config.NET_ENEMY_WINDUP_FRESH): the attack's telegraph (the boss stands where the event says,
## facing its way, its cleave's wedge and its volley's aim lines), the bolts, the burning circles, a pillar's dust and its debris. A player
## sees them as early as the wire allows and dodges on the host's clock; the body walks a buffer behind as the heretics do.

## One received body at a host tick (its timed state's start as a whole host tick).
class BodySnap:
	extends RefCounted
	var tick: int = 0
	var e: NetProtocol.BossState
	var since: int = 0


## An attack the host started (BOSS_ATTACK) and the tick it stopped early (-1 = it ran its length).
class AttackTrack:
	extends RefCounted
	var tick: int = 0
	var attack: int = BossSim.Attack.NONE
	var face: int = RigData.Dir.SOUTH
	var pos: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	var base: float = 0.0
	var count: int = 0
	var stop: int = -1


## A fire bolt: let go at `tick` from `origin` along `dir` (it is there after that tick's step), stopped at `end_tick` on `end_pos` (-1 = not
## yet heard).
class BoltTrack:
	extends RefCounted
	var id: int = 0
	var tick: int = 0
	var origin: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var end_tick: int = -1
	var end_pos: Vector2 = Vector2.ZERO

	## Where it is at host time `t`, or Vector2.INF (not let go yet, stopped, past its range).
	func pos_at(t: float) -> Vector2:
		var steps: float = t - tick
		if steps < 0.0:
			return Vector2.INF
		if end_tick >= 0:
			if t >= end_tick:
				return Vector2.INF
			if t > end_tick - 1:
				return raw(end_tick - 1 - tick).lerp(end_pos, t - (end_tick - 1))
		elif steps > NetBoss.bolt_life():
			return Vector2.INF
		return raw(steps)

	func raw(steps: float) -> Vector2:
		return origin + dir * (BossSim.attack_num(BossSim.Attack.VOLLEY, "speed") / Config.NET_TICK_RATE) \
			* clampf(steps, 0.0, float(NetBoss.bolt_life()))

	func over(t: float) -> bool:
		return (end_tick >= 0 and t >= end_tick) or t - tick > NetBoss.bolt_life() + 1


## A burning circle put down at `tick` (age 0), erupting at tick + telegraph; `stop` = the fire went out early (-1 = it burns its time).
class CircleTrack:
	extends RefCounted
	var id: int = 0
	var tick: int = 0
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	var telegraph: int = 0
	var stop: int = -1


## A pillar's state as its last event said (its dust ticks left at that tick) and until when its marks show.
class PillarTrack:
	extends RefCounted
	var tick: int = 0
	var hits: int = 0
	var falling: int = -1
	var fallen: bool = false
	var refused_until: int = -1000000
	var flash_until: int = -1000000
	var landed_at: int = -1000000


## The mirror the views draw (Arena.boss of NetCombat's mirror arena).
var fight: BossFight
var snaps: Array[BodySnap] = []
var attacks: Array[AttackTrack] = []
var bolts: Dictionary[int, BoltTrack] = {}
var circles: Dictionary[int, CircleTrack] = {}
var pillars: Array[PillarTrack] = []
## The newest body taken and its host tick.
var last: NetProtocol.BossState = null
var last_tick: int = -1
## Counters (results, tests): bodies taken, the HP seen in order (consecutive repeats dropped), the states seen, the attacks' start ticks by
## kind, the bolts let go and how they stopped, the circles, the stops, the pillar events (and the refused, the landed blows), the debris
## landings (their ticks; the ones that hit the boss), malformed events (a pillar this site does not have).
var bodies: int = 0
var hp_seen: Array[int] = []
var states_seen: Dictionary[String, bool] = {}
var attack_ticks: Dictionary[String, Array] = {}
var bolts_seen: int = 0
var bolt_stops: Dictionary[String, int] = {}
var circles_seen: int = 0
var stops: int = 0
var pillar_events: int = 0
var refused_seen: int = 0
var blows_seen: int = 0
var debris_ticks: Array[int] = []
var debris_on_boss: int = 0
var bad: int = 0


## For mirror fight `p_fight` (NetCombat.reset made it from the dungeon's boss site).
func _init(p_fight: BossFight) -> void:
	fight = p_fight
	for p: BossFight.Pillar in fight.pillars:
		var t: PillarTrack = PillarTrack.new()
		t.hits = p.hits
		t.fallen = p.fallen
		pillars.append(t)


## Ticks a fire bolt flies at most (its range at its speed, the host's rule).
static func bolt_life() -> int:
	return ceili(BossSim.attack_num(BossSim.Attack.VOLLEY, "range_px") / BossSim.attack_num(BossSim.Attack.VOLLEY, "speed")
		* Config.NET_TICK_RATE)


## The boss block of a batch at host tick `tick` (one older than the newest is skipped by NetCombat already).
func on_body(tick: int, e: NetProtocol.BossState) -> void:
	bodies += 1
	var s: BodySnap = BodySnap.new()
	s.tick = tick
	s.e = e
	s.since = tick - ((tick - e.since) & 0xFFFF) if e.since != 0 or e.state == BossSim.State.ATTACK else tick
	snaps.append(s)
	while snaps.size() > 64:
		snaps.pop_front()
	last = e
	last_tick = tick
	if hp_seen.is_empty() or hp_seen.back() != e.hp:
		hp_seen.append(e.hp)
		if hp_seen.size() > 256:
			hp_seen.pop_front()
	states_seen[BossSim.STATE_NAMES[e.state] + ("2" if e.phase >= 2 and e.state != BossSim.State.DEAD else "")] = true


## A batch at host tick `tick` without the boss block: it rests (NetProtocol.boss_at_rest). After an awake body: asleep at home (its reset; full
## HP); after a dead one: lying there. Before any body nothing changes (the snapshot's mirror is the resting boss).
func on_rest(tick: int) -> void:
	if last == null or (last.state == BossSim.State.SLEEP) or (last.state == BossSim.State.DEAD and last.since == 0):
		return
	var e: NetProtocol.BossState = NetProtocol.BossState.new()
	if last.state == BossSim.State.DEAD:
		e.state = BossSim.State.DEAD
		e.pos = last.pos
		e.facing = last.facing
		e.hp = 0
		e.hp_max = last.hp_max
	else:
		e.state = BossSim.State.SLEEP
		e.pos = fight.sim.home
		e.hp = last.hp_max
		e.hp_max = last.hp_max
	on_body(tick, e)


## One of the fight's events (an event already known, say a late join's snapshot and the same tick's live event, sets the same track again).
func on_event(e: NetProtocol.ShotEvent) -> void:
	match e.kind:
		NetProtocol.ShotEvent.Kind.BOSS_ATTACK:
			for a: AttackTrack in attacks:
				if a.tick == e.tick and a.attack == e.sub:
					return
			var t: AttackTrack = AttackTrack.new()
			t.tick = e.tick
			t.attack = e.sub
			t.face = e.face
			t.pos = e.pos
			t.angle = e.angle
			t.base = e.base
			t.count = e.count
			attacks.append(t)
			while attacks.size() > 8:
				attacks.pop_front()
			var name: String = BossSim.ATTACK_NAMES[e.sub]
			var ticks: Array = attack_ticks.get(name, [])
			ticks.append(e.tick)
			attack_ticks[name] = ticks
		NetProtocol.ShotEvent.Kind.BOSS_STOP:
			stops += 1
			if e.flags & NetProtocol.BOSS_STOP_ATTACK:
				for i: int in range(attacks.size() - 1, -1, -1):
					if attacks[i].tick <= e.tick:
						if attacks[i].stop < 0:
							attacks[i].stop = e.tick
						break
			if e.flags & NetProtocol.BOSS_STOP_FIRE:
				for id: int in bolts:
					if bolts[id].end_tick < 0 and bolts[id].tick <= e.tick:
						bolts[id].end_tick = e.tick
						bolts[id].end_pos = bolts[id].raw(e.tick - bolts[id].tick)
				for id: int in circles:
					if circles[id].stop < 0 and circles[id].tick <= e.tick:
						circles[id].stop = e.tick
		NetProtocol.ShotEvent.Kind.BOLT:
			if not bolts.has(e.id):
				bolts_seen += 1
				var b: BoltTrack = BoltTrack.new()
				b.id = e.id
				bolts[e.id] = b
			var bt: BoltTrack = bolts[e.id]
			bt.tick = e.tick
			bt.origin = e.pos
			bt.dir = Vector2.from_angle(e.angle)
		NetProtocol.ShotEvent.Kind.BOLT_END:
			var why: String = NetProtocol.BOLT_STOPS[e.why]
			var n: int = bolt_stops.get(why, 0)
			bolt_stops[why] = n + 1
			if bolts.has(e.id):
				bolts[e.id].end_tick = e.tick
				bolts[e.id].end_pos = e.pos
		NetProtocol.ShotEvent.Kind.CIRCLE:
			if not circles.has(e.id):
				circles_seen += 1
			var c: CircleTrack = circles.get(e.id, CircleTrack.new())
			c.id = e.id
			c.tick = e.tick
			c.pos = e.pos
			c.radius = e.radius
			c.telegraph = e.ticks
			circles[e.id] = c
		NetProtocol.ShotEvent.Kind.PILLAR:
			if e.id >= pillars.size():
				bad += 1
				return
			pillar_events += 1
			var p: PillarTrack = pillars[e.id]
			p.tick = e.tick
			p.hits = e.hits
			p.falling = e.falling
			p.fallen = (e.flags & NetProtocol.PILLAR_FALLEN) != 0
			if e.flags & NetProtocol.PILLAR_REFUSED:
				refused_seen += 1
				p.refused_until = e.tick + Config.PILLAR_REFUSED_SHOW_TICKS
			if e.flags & NetProtocol.PILLAR_HIT:
				blows_seen += 1
				p.flash_until = e.tick + Config.HIT_FLASH_TICKS
			if e.flags & NetProtocol.PILLAR_LANDED:
				p.landed_at = e.tick
				if not debris_ticks.has(e.tick):
					debris_ticks.append(e.tick)
				if e.flags & NetProtocol.PILLAR_BOSS:
					debris_on_boss += 1
			if not p.fallen:
				p.landed_at = -1000000  # standing again (a reset): no debris to show
			fight.set_pillar_state(e.id, p.hits, p.falling, p.fallen)  # blocks where it stands, as on the host


## Fills the mirror for drawing: the body at `t_draw`, the warnings at `t_fresh` (see the class comment).
func sample(t_fresh: float, t_draw: float) -> void:
	var b: BossSim = fight.sim
	if b == null:
		return
	_sample_body(b, t_draw)
	_sample_attack(b, t_fresh)
	_sample_fire(t_fresh)
	_sample_pillars(t_fresh)


func _sample_body(b: BossSim, t_draw: float) -> void:
	b.clock = maxi(floori(t_draw), 0)
	if snaps.is_empty():
		return
	while snaps.size() >= 2 and snaps[1].tick <= t_draw:
		snaps.pop_front()
	var a: BodySnap = snaps[0]
	var n: BodySnap = snaps[1] if snaps.size() > 1 else null
	var e: NetProtocol.BossState = a.e
	b.pos = e.pos
	if n != null and t_draw > a.tick:
		b.pos = e.pos.lerp(n.e.pos, clampf((t_draw - a.tick) / float(n.tick - a.tick), 0.0, 1.0))
	b.facing = e.facing
	b.walking = e.walking
	b.state = e.state
	b.attack = e.attack
	b.phase = e.phase
	b.hp = e.hp
	b.hp_max = e.hp_max
	b.flash_ticks = maxi(e.flash - maxi(floori(t_draw - a.tick), 0), 0)
	if e.state == BossSim.State.DEAD:
		b.state_ticks = maxi(floori(t_draw - a.since), 0) if e.since != 0 else NetProtocol.boss_death_ticks()
	elif e.state == BossSim.State.ATTACK:
		b.state_ticks = maxi(floori(t_draw - a.since), 0)
	else:
		b.state_ticks = 0
	# The marks (their times are the host's): a stunned boss holds its hurt pose (BossSim.anim), an exposed one its ember shadow.
	b.stun_ticks = 1 if e.stunned else 0
	b.slow_pct = 1 if e.slowed else 0
	b.slow_ticks = b.slow_pct
	b.taunt_by = -1 if e.taunted else 0
	b.taunt_ticks = 1 if e.taunted else 0
	b.poison_ticks = 1 if e.poisoned else 0
	b.exposed_ticks = 1 if e.exposed else 0


## The attack under way at `t_fresh` (its event): it stands where the host had it, facing its way, the telegraph's age the host's. A body
## still in an attack the events say is over walks on (CHASE).
func _sample_attack(b: BossSim, t_fresh: float) -> void:
	var live: AttackTrack = null
	for i: int in range(attacks.size() - 1, -1, -1):
		if attacks[i].tick <= t_fresh:
			live = attacks[i]
			break
	if live != null:
		var k: int = floori(t_fresh) - live.tick
		if k >= BossSim.attack_length(live.attack) or (live.stop >= 0 and t_fresh >= live.stop) or not b.alive():
			live = null
	if live == null:
		if b.state == BossSim.State.ATTACK:
			b.state = BossSim.State.CHASE
			b.attack = BossSim.Attack.NONE
			b.state_ticks = 0
		b.volley_dirs.clear()
		return
	var ticks: int = floori(t_fresh) - live.tick
	b.state = BossSim.State.ATTACK
	b.attack = live.attack
	b.state_ticks = ticks
	b.pos = live.pos
	b.facing = live.face
	b.walking = false
	b.attack_dir = Vector2.from_angle(live.angle)
	b.volley_base = live.base
	b.volley_dirs.clear()
	if live.attack == BossSim.Attack.VOLLEY:
		b.volley_dirs = BossSim.volley_dirs_for(live.base, live.count)
	if ticks < BossSim.strike_tick(live.attack):
		b.stun_ticks = 0  # a stun before the blow would have stopped it (its stop event)


## The bolts and the burning circles at `t_fresh`; the gone ones forgotten.
func _sample_fire(t_fresh: float) -> void:
	fight.bolts.clear()
	for id: int in bolts.keys():
		var tr: BoltTrack = bolts[id]
		if tr.over(t_fresh):
			bolts.erase(id)
			continue
		var at: Vector2 = tr.pos_at(t_fresh)
		if at == Vector2.INF:
			continue
		var bolt: BossFight.Bolt = BossFight.Bolt.new()
		bolt.id = tr.id
		bolt.pos = at
		bolt.dir = tr.dir
		fight.bolts.append(bolt)
	fight.circles.clear()
	var show: int = BossSim.attack_int(BossSim.Attack.BURN, "show_ticks")
	for id: int in circles.keys():
		var c: CircleTrack = circles[id]
		var age: int = floori(t_fresh) - c.tick
		if age >= c.telegraph + show or (c.stop >= 0 and t_fresh >= c.stop):
			circles.erase(id)
			continue
		if age < 0:
			continue
		var fc: BossFight.Circle = BossFight.Circle.new()
		fc.id = c.id
		fc.pos = c.pos
		fc.radius = c.radius
		fc.telegraph = c.telegraph
		fc.show = show
		fc.age = age
		fc.erupted = age >= c.telegraph
		fc.born = c.tick
		fight.circles.append(fc)


## The pillars' dust left, marks and debris at `t_fresh` (their hits and rubble as the last event set them).
func _sample_pillars(t_fresh: float) -> void:
	var now: int = floori(t_fresh)
	fight.debris.clear()
	for i: int in pillars.size():
		var t: PillarTrack = pillars[i]
		var p: BossFight.Pillar = fight.pillars[i]
		p.falling = maxi(t.falling - (now - t.tick), 0) if t.falling >= 0 and not t.fallen else -1
		p.refused_ticks = maxi(t.refused_until - now, 0)
		p.flash_ticks = maxi(t.flash_until - now, 0)
		var age: int = now - t.landed_at
		if t.fallen and age >= 0 and age < BossFight.DEBRIS_SHOW_TICKS:
			var d: BossFight.Debris = BossFight.Debris.new()
			d.id = i
			d.pos = p.centre()
			d.radius = Config.BOSS_PILLARS["fall_radius_px"]
			d.age = age
			fight.debris.append(d)


## Anything fighting in what came last (an awake boss, a bolt or a circle).
func fighting() -> bool:
	return not bolts.is_empty() or not circles.is_empty() or (last != null and last.state != BossSim.State.SLEEP
		and last.state != BossSim.State.DEAD)


## The pillars' picture states as drawn last ("0123").
func looks() -> String:
	var out: String = ""
	for p: BossFight.Pillar in fight.pillars:
		out += str(p.look())
	return out


func to_dict() -> Dictionary:
	var states: Array = states_seen.keys()
	states.sort()
	var ticks: Dictionary = {}
	for k: String in attack_ticks:
		ticks[k] = attack_ticks[k]
	return {"bodies": bodies, "hp_seen": hp_seen, "states": states, "attack_ticks": ticks, "bolts": bolts_seen, "bolt_stops": bolt_stops,
		"circles": circles_seen, "stops": stops, "pillar_events": pillar_events, "refused": refused_seen, "blows": blows_seen,
		"debris_ticks": debris_ticks, "debris_on_boss": debris_on_boss, "looks": looks(), "bad": bad,
		"drawn": BossSim.STATE_NAMES[fight.sim.state] if fight.sim != null else "none",
		"boss": last.describe() if last != null else "none", "hp": last.hp if last != null else -1,
		"hp_max": last.hp_max if last != null else -1, "state": BossSim.STATE_NAMES[last.state] if last != null else "none"}
