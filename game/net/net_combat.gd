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
##
## M6b: thrown potions come like the shots (the host's thrown / broke events, reliable) and fly here on the
## host's own steps (Arena.flask_points from where it left the hand toward where it lands): drawn until the tick
## it broke, then its splash at the broke event's point for Config.SPLASH_SHOW_TICKS; this client's own bottles
## at t_fresh, the others' at t_draw (like the shots). A heretic's poison is a flag in the enemy batch (its mark).

## M6b: one thrown potion as the host's events tell it. `path` = where it is after each host tick from the tick it
## left the hand (Arena.flask_points, the host's own steps), up to the tick it lands on its target.
class FlaskTrack:
	extends RefCounted
	## IMPL (named in M6-fix): ticks of path beyond the ticks a whole range takes (float slack), and how long a
	## bottle without its broke event stays before the client forgets it (1 s).
	const FLASK_PATH_SPARE_TICKS: int = 2
	const FLASK_WAIT_BROKE_TICKS: int = Config.NET_TICK_RATE
	var id: int = 0
	var item: StringName = &""
	var owner: int = 255
	## Whether its thrown event came (a late client may get only the splash).
	var thrown: bool = false
	var tick: int = 0
	var origin: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2.ZERO
	var path: PackedVector2Array = PackedVector2Array()
	## The broke event: its host tick (-1 = not yet) and the splash point.
	var end_tick: int = -1
	var end_pos: Vector2 = Vector2.ZERO

	## The flight's points tick by tick, the host's steps without its walls (the broke event cuts it): at most the
	## ticks a whole range takes plus FLASK_PATH_SPARE_TICKS (it stops on the tick it lands).
	func build_path() -> void:
		path.clear()
		var at: Vector2 = origin
		for i: int in ceili(Config.THROW_RANGE_PX / (Config.THROW_SPEED / Config.NET_TICK_RATE)) + FLASK_PATH_SPARE_TICKS:
			var arrive: bool = Arena.flask_arrives(at, target)
			var points: PackedVector2Array = Arena.flask_points(at, target)
			at = points[points.size() - 1]
			path.append(at)
			if arrive:
				break

	## The last path index it is still in the air (the next tick it lands or breaks).
	func last_flying() -> int:
		var n: int = path.size() - 2
		if end_tick >= 0:
			n = mini(n, end_tick - tick - 1)
		return n

	## Where the bottle is at host time `t` (after tick floor(t)'s step, between ticks on the way), or Vector2.INF
	## when it is not in the air.
	func pos_at(t: float) -> Vector2:
		if not thrown or t < tick:
			return Vector2.INF
		var k: float = t - tick
		var i: int = floori(k)
		var last: int = last_flying()
		if i > last or path.is_empty():
			return Vector2.INF
		if i < last:
			return path[i].lerp(path[i + 1], k - i)
		return path[i]

	## The splash's age at host time `t` (-1 = no splash shown then).
	func splash_age(t: float) -> int:
		if end_tick < 0:
			return -1
		var age: int = floori(t) - end_tick
		return age if age >= 0 and age < Config.SPLASH_SHOW_TICKS else -1

	## Gone for good by host time `t`: its splash shown; without a broke event (it cannot be lost: reliable, but a
	## map change may cut it off), FLASK_WAIT_BROKE_TICKS after its flight and splash would have ended.
	func over(t: float) -> bool:
		if end_tick >= 0:
			return floori(t) - end_tick >= Config.SPLASH_SHOW_TICKS
		return t - tick > path.size() + Config.SPLASH_SHOW_TICKS + FLASK_WAIT_BROKE_TICKS

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
## M6b: thrown potions by id; flask events taken, the heretics seen poisoned (ids), for the results.
var flasks: Dictionary[int, FlaskTrack] = {}
var flask_events: int = 0
var poisoned_seen: Dictionary[int, bool] = {}
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
	flasks.clear()
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
		if e.poisoned:
			poisoned_seen[e.id] = true
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
		if e.kind == NetProtocol.ShotEvent.Kind.THROW or e.kind == NetProtocol.ShotEvent.Kind.SPLASH:
			_on_flask(e)
			continue
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


## M6b: a thrown potion's event: thrown (a track and its path), broke (its end; a track of its own when the
## thrown event never came here, a late client's).
func _on_flask(e: NetProtocol.ShotEvent) -> void:
	flask_events += 1
	var tr: FlaskTrack = flasks.get(e.id, null)
	if tr == null:
		tr = FlaskTrack.new()
		tr.id = e.id
		tr.item = e.item
		flasks[e.id] = tr
	if e.kind == NetProtocol.ShotEvent.Kind.THROW:
		tr.thrown = true
		tr.owner = e.owner
		tr.tick = e.tick
		tr.origin = e.pos
		tr.target = e.target
		tr.build_path()
	else:
		tr.end_tick = e.tick
		tr.end_pos = e.pos
		if not tr.thrown:
			tr.tick = e.tick


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
	# M6b: the thrown potions and their splashes (this client's own at t_fresh, the others' at t_draw).
	arena.flasks.clear()
	arena.splashes.clear()
	for id: int in flasks.keys():
		var ft: FlaskTrack = flasks[id]
		var tf: float = t_fresh if ft.owner == local_slot else t_draw
		if ft.over(tf):
			flasks.erase(id)
			continue
		var fp: Vector2 = ft.pos_at(tf)
		if fp != Vector2.INF:
			var f: Arena.Flask = Arena.Flask.new()
			f.id = ft.id
			f.item = ft.item
			f.origin = ft.origin
			f.target = ft.target
			f.pos = fp
			f.owner_slot = ft.owner
			arena.flasks.append(f)
		var age: int = ft.splash_age(tf)
		if age >= 0:
			var sp: Arena.Splash = Arena.Splash.new()
			sp.id = ft.id
			sp.item = ft.item
			sp.pos = ft.end_pos
			sp.age = age
			arena.splashes.append(sp)
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
	h.poison_ticks = 1 if a.e.poisoned else 0  # M6b: the mark (the poison's time and damage are the host's)
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
	if not shots.is_empty() or not flasks.is_empty():
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
	var poisoned: Array = poisoned_seen.keys()
	poisoned.sort()
	return {"map": map, "batches": batches, "keyframes": keyframes, "stale": stale, "other_map": other_map,
		"shot_events": shot_events, "hash": latest_hash(), "foe_hp": hp, "flask_events": flask_events,
		"poisoned_seen": poisoned,
		"heretics": last_batch.enemies.size() if last_batch != null else 0,
		"shrine_hp": last_batch.shrine_hp if last_batch != null else -1}
