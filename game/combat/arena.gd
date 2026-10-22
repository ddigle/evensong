class_name Arena
extends RefCounted
## One map's combat (M4a): its heretics, the shots in flight, the heretic shrine's hit points and the
## heretic spawner. step() runs one tick after the players on that map have stepped; player_attack()
## resolves a weapon's hit frame (Player.action_impact). Pure data and rules (no nodes of its own): the
## offline game (core/main.gd) keeps one per map and steps the one the local player is on; tests drive
## it directly. Heretics never leave their map. A map nobody is on does not tick (its heretics wait).
##
## Order inside step(): revives (a downed player, someone up holding F next to it), the heretics (target,
## move, attack: their knife lands on its hit tick), the shots (move, stop at a blocking tile, an enemy
## or the shrine), corpses gone, then the spawner. World changes (the shrine breaking) come back as edits
## (net/edit_log.gd) for the caller to apply, like the other world rules, so M4b can send them.
## Values PROVISIONAL (Config "M4a"); the rules: combat/combat.gd.
##
## M4b (sessions): the host keeps one arena per map (net/session_host.gd) and steps the ones with players
## on them; `now` is the host tick (set by the host each tick) and, with `logging` on, every shot let go or
## stopped and every hit on a heretic is recorded (shot_events, hits) for the host to send and log. A client
## draws a mirror arena (Arena.mirror: data only, never stepped) filled from the host's enemy batches and
## shot events (net/net_combat.gd).
##
## M4-fix: the caller calls idle_tick() on a tick it does not step an arena (nobody on its map). The first
## such tick after the arena was stepped empties it (on_emptied, PROVISIONAL README "M4-fix 빈 지도"): an
## attack under way stops without its knife (as if it had ended: the attack cooldown follows), a stagger
## ends, every heretic forgets its target, the shots in the air are gone and the spawn timer starts over.
## So nothing that waits on a map nobody is on lands on the next player to arrive (at the stairs, where a
## fleeing player left), no shot flies on unseen, and the first spawn comes one interval after arriving.

## A shot in flight (an arrow or a holy-light bolt).
class Shot:
	extends RefCounted
	var id: int = 0
	var kind: int = Combat.Kind.ARROW
	## Ground position (the body-point height; drawn Config.SHOT_DRAW_LIFT_PX higher) and unit direction.
	var pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var speed: float = 0.0
	var left: int = 0
	var damage: int = 0
	## The shooter (node instance id; friendly fire off: it never hits a player).
	var owner_id: int = 0
	var done: bool = false
	## What stopped it: "", "wall", "heretic", "shrine", "player", "spent".
	var stopped_by: String = ""
	## M4b: the aim code it flies along, its weapon and the shooter's session slot (255 = none / offline),
	## the tick it was let go and where (a late client gets it as a let-go event).
	var born: int = 0
	var origin: Vector2 = Vector2.ZERO
	var aim: int = 0
	var item: StringName = &""
	var owner_slot: int = 255


## M6a: a thrown potion in flight (the herbalist's skill, items/potions.gd): lobbed over bodies along the
## ground from `origin` to `target`, stopped sooner by what stops a shot (Combat.blocks_line).
class Flask:
	extends RefCounted
	var id: int = 0
	var item: StringName = &""
	var grade: int = 0
	## Ground point now, where it left the hand and where it lands at most.
	var pos: Vector2 = Vector2.ZERO
	var origin: Vector2 = Vector2.ZERO
	var target: Vector2 = Vector2.ZERO
	var owner_id: int = 0
	var done: bool = false
	## What ended it: "", "landed", "wall", "emptied".
	var stopped_by: String = ""
	## M6b: the thrower's session slot (255 = none / offline) and the tick it left the hand (a late client gets
	## it as a thrown event).
	var owner_slot: int = 255
	var born: int = 0

	## 0..1 of the way (for the arc it is drawn on).
	func progress() -> float:
		var total: float = origin.distance_to(target)
		return clampf(origin.distance_to(pos) / total, 0.0, 1.0) if total > 0.0 else 1.0


## M6a: where a thrown potion broke (shown Config.SPLASH_SHOW_TICKS; its effect is applied when it lands).
class Splash:
	extends RefCounted
	var id: int = 0
	var item: StringName = &""
	var pos: Vector2 = Vector2.ZERO
	var age: int = 0
	## Who it reached (counts for logs and tests).
	var players: int = 0
	var heretics: int = 0
	## M6b: why its potion broke ("landed", "wall"; NetProtocol.FLASK_STOPS) and the host tick it did.
	var why: String = "landed"
	var born: int = 0


## M4b: a hit on a heretic (logging on): which, how much, its HP after, who (the attacker's node instance
## id, 0 = unknown) and whether it died. M6-fix: `poison` = a poison tick (the thrower's), not a weapon hit (the
## host counts it apart, "poison_hits", and tags its log line).
class Hit:
	extends RefCounted
	var heretic_id: int = 0
	var amount: int = 0
	var hp_after: int = 0
	var by_id: int = 0
	var killed: bool = false
	var poison: bool = false

var data: WorldData
var safe: SafeZone
var map_id: int = Config.MAP_SURFACE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var heretics: Array[HereticSim] = []
var shots: Array[Shot] = []
## M6a: thrown potions in flight and splashes being shown.
var flasks: Array[Flask] = []
var splashes: Array[Splash] = []
var next_id: int = 1
var spawn_timer: int = 0
## The shrine (dungeon): its footprint while it stands, hit points, display flash.
var shrine_hp: int = 0
var shrine_flash: int = 0
## Tiles the spawner may put a heretic on (Config "M4a" spawning rows), computed once.
var spawn_cells: Array[Vector2i] = []
## Counters for logs and tests.
var stats: Dictionary[String, int] = {}
## Spawning on / off (tests; the offline game keeps it on).
var spawning: bool = true
## M4b: the host tick (the session sets it), recording on, the records since the session last took them,
## and how many heretics started an attack in the last step (the host sends that map's batch at once).
var now: int = 0
var logging: bool = false
var shot_events: Array[NetProtocol.ShotEvent] = []
var hits: Array[Hit] = []
var attacks_started: int = 0
## M4-fix: stepped on the last tick (someone on the map); idle_tick() empties it once when that ends.
var occupied: bool = false
## M4-fix: the standing shrine's footprint, found once (WorldData.footprints scans the whole map) and kept
## while its tiles are still the shrine (checked per call, six tiles); `_shrine_data` = the data it is for.
var _shrine: Rect2i = Rect2i()
var _shrine_data: WorldData = null


## M4b: a client's arena for drawing (CombatView): the map's data and the shrine, never stepped; the
## session fills its heretics, shots and shrine HP from what the host sends.
static func mirror(p_data: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.data = p_data
	a.map_id = p_data.map_id
	a.safe = SafeZone.for_world(p_data)
	a.spawning = false
	a.shrine_hp = Config.SHRINE_HP if a.shrine_rect().has_area() else 0
	return a


## For `p_data` (its map id says which spawn rule). `world_seed` makes the spawns repeatable.
func setup(p_data: WorldData, world_seed: int) -> void:
	data = p_data
	map_id = data.map_id
	safe = SafeZone.for_world(data)
	rng.seed = hash([world_seed, map_id, 0xC0BA7])
	heretics.clear()
	shots.clear()
	flasks.clear()
	splashes.clear()
	next_id = 1
	spawn_timer = 0
	occupied = false
	stats.clear()
	_shrine_data = null
	shrine_hp = Config.SHRINE_HP if shrine_rect().has_area() else 0
	shrine_flash = 0
	spawn_cells = surface_spawn_cells(data, safe) if map_id == Config.MAP_SURFACE else dungeon_spawn_cells(data)


## Counter `key` (0 when it never counted).
func stat(key: String) -> int:
	var v: int = stats.get(key, 0)
	return v


func count(key: String, n: int = 1) -> void:
	var v: int = stats.get(key, 0)
	stats[key] = v + n


## The standing shrine's footprint (empty when there is none or it is broken). M4-fix: cached (it was a
## whole-map scan on every call, twice per shot step); the cache holds while its tiles are still the
## shrine, and once the shrine is gone it stays gone (no rule puts one back on the same data).
func shrine_rect() -> Rect2i:
	if _shrine_data != data:
		_shrine_data = data
		_shrine = DungeonGen.shrine_rect(data) if data != null else Rect2i()
	elif _shrine.has_area() and not _shrine_intact():
		_shrine = DungeonGen.shrine_rect(data)  # a partly broken one (edits arrive one tile at a time) or none
	return _shrine


func _shrine_intact() -> bool:
	for y: int in range(_shrine.position.y, _shrine.end.y):
		for x: int in range(_shrine.position.x, _shrine.end.x):
			if data.get_value(WorldData.Layer.PLACEABLE, Vector2i(x, y)) != WorldData.PLACEABLE_SHRINE:
				return false
	return true


## Edge wait in ticks (Config.HERETIC_LIGHT_EDGE_WAIT_SEC).
static func edge_wait_ticks() -> int:
	return roundi(Config.HERETIC_LIGHT_EDGE_WAIT_SEC * Config.NET_TICK_RATE)


func alive_heretics() -> int:
	var n: int = 0
	for h: HereticSim in heretics:
		if h.alive():
			n += 1
	return n


## The enemies' light rule at a point (combat/combat.gd).
func in_light(pos: Vector2) -> bool:
	return Combat.in_safe_light(data, safe, pos)


# --- one tick ------------------------------------------------------------------------------------

## One tick after `players` (the players on this map, in a fixed order) have stepped. Returns the world
## edits it made (the caller applies them before anything else reads the world).
func step(players: Array[Player]) -> Array[EditLog.WorldEdit]:
	var edits: Array[EditLog.WorldEdit] = []
	attacks_started = 0
	occupied = not players.is_empty()
	if shrine_flash > 0:
		shrine_flash -= 1
	_revive(players)
	for h: HereticSim in heretics:
		_step_heretic(h, players)
	for s: Shot in shots:
		edits.append_array(_step_shot(s, players))
	var flying: Array[Shot] = []
	for s: Shot in shots:
		if not s.done:
			flying.append(s)
	shots = flying
	# M6a: splashes age (display), thrown potions fly and splash.
	var showing: Array[Splash] = []
	for sp: Splash in splashes:
		sp.age += 1
		if sp.age < Config.SPLASH_SHOW_TICKS:
			showing.append(sp)
	splashes = showing
	for f: Flask in flasks:
		_step_flask(f, players)
	var in_air: Array[Flask] = []
	for f: Flask in flasks:
		if not f.done:
			in_air.append(f)
	flasks = in_air
	var staying: Array[HereticSim] = []
	for h: HereticSim in heretics:
		if not h.finished():
			staying.append(h)
	heretics = staying
	if spawning and not players.is_empty():
		spawn_timer += 1
		if spawn_timer >= Config.HERETIC_SPAWN_INTERVAL_TICKS:
			spawn_timer = 0
			try_spawn(players)
	return edits


## M4-fix: a tick this arena is not stepped (nobody on its map). The first one after it was stepped
## empties it (on_emptied); later ones do nothing (the map waits as before).
func idle_tick() -> void:
	if occupied:
		occupied = false
		on_emptied()


## M4-fix (PROVISIONAL README "M4-fix 빈 지도"): the map's last player left. Attacks under way stop
## without their knife (the attack cooldown follows, as after a swing), staggers end, every heretic forgets
## its target and its watch at the light's edge, flashes end, the shots in the air are gone (no stop event:
## nobody is there to see one), the spawn timer starts over (the first try one interval after someone
## arrives, Config.HERETIC_SPAWN_INTERVAL_TICKS) and nothing counts as a fresh attack. Dead heretics lie on
## (their corpse time runs when the map is stepped again).
func on_emptied() -> void:
	for h: HereticSim in heretics:
		h.flash_ticks = 0
		h.walking = false
		if not h.alive():
			continue
		if h.state == HereticSim.State.ATTACK:
			h.cooldown = Config.HERETIC_ATTACK_COOLDOWN_TICKS
			count("attacks_cancelled")
		h.has_target = false
		h.target_id = 0
		h.watch_ticks = 0
		if h.state != HereticSim.State.RETURN:
			h.state = HereticSim.State.IDLE
			h.state_ticks = 0
	for s: Shot in shots:
		s.done = true
		s.stopped_by = "emptied"
	shots.clear()
	shot_events.clear()
	for f: Flask in flasks:
		f.done = true
		f.stopped_by = "emptied"
	flasks.clear()
	splashes.clear()
	spawn_timer = 0
	attacks_started = 0
	shrine_flash = 0
	count("emptied")


# --- revive --------------------------------------------------------------------------------------

## A downed player's revive (● gameplay-design §2.6 flow; Config REVIVE_*): while anyone up within
## Config.REVIVE_REACH_PX holds F (not acting, dashing or staggered) the progress adds a tick; it is done
## after the fastest such reviver's time: a cleric at once, anyone else Config.REVIVE_TICKS (M4-fix: the
## fastest, not the first in the players' order, so a cleric holding F is instant whoever else holds F
## too). Nobody holding: the progress resets.
func _revive(players: Array[Player]) -> void:
	for p: Player in players:
		if p.vitals.life != Vitals.Life.DOWN:
			continue
		var reviver: Player = reviver_for(p, players)
		if reviver == null:
			p.vitals.revive_ticks = 0
			continue
		p.vitals.revive_ticks += 1
		if p.vitals.revive_ticks >= revive_needed(reviver):
			p.revive_now()
			count("revived")


static func revive_needed(reviver: Player) -> int:
	return Config.REVIVE_TICKS_CLERIC if reviver.class_id() == "cleric" else Config.REVIVE_TICKS


## The fastest reviver of downed player `p` (least revive_needed; the first in `players` among equals), or
## null when nobody revives it now. CombatView's revive bar uses the same choice.
static func reviver_for(p: Player, players: Array[Player]) -> Player:
	var best: Player = null
	for r: Player in players:
		if r == p or not r.vitals.alive() or not r.interact_held or r.action_anim >= 0 or r.vitals.dashing() \
				or r.vitals.staggered():
			continue
		if r.sim_position.distance_to(p.sim_position) <= Config.REVIVE_REACH_PX \
				and (best == null or revive_needed(r) < revive_needed(best)):
			best = r
	return best


# --- the heretics --------------------------------------------------------------------------------

## Puts a heretic at feet `feet` (its home). Returns it.
func spawn_heretic(feet: Vector2) -> HereticSim:
	var h: HereticSim = HereticSim.new()
	h.id = next_id
	next_id += 1
	h.pos = feet
	h.home = feet
	h.facing = RigData.Dir.SOUTH
	heretics.append(h)
	count("spawned")
	return h


func _step_heretic(h: HereticSim, players: Array[Player]) -> void:
	h.clock += 1
	if h.flash_ticks > 0:
		h.flash_ticks -= 1
	if h.alive() and h.poison_ticks > 0:
		_tick_poison(h)  # M6a
	match h.state:
		HereticSim.State.DEAD:
			h.state_ticks += 1
			return
		HereticSim.State.HURT:
			h.walking = false
			h.state_ticks += 1
			if h.watch_ticks > 0:
				h.watch_ticks += 1  # M4-fix: a hit while it watches the light's edge does not stop its wait
			if h.state_ticks >= HereticSim.hurt_ticks():
				h.state = HereticSim.State.CHASE if h.has_target else HereticSim.State.IDLE
				h.state_ticks = 0
			return
		HereticSim.State.ATTACK:
			h.walking = false
			h.state_ticks += 1
			if h.state_ticks == Config.HERETIC_TELEGRAPH_TICKS:
				_knife(h, players)
			if h.state_ticks >= HereticSim.attack_ticks(h.row()):
				h.state = HereticSim.State.CHASE
				h.state_ticks = 0
				h.cooldown = Config.HERETIC_ATTACK_COOLDOWN_TICKS
			return
	if h.cooldown > 0:
		h.cooldown -= 1
	h.walking = false
	if h.state == HereticSim.State.RETURN:
		_go_home(h)
		return
	if h.pos.distance_to(h.home) > Config.HERETIC_LEASH_PX:
		_set_state(h, HereticSim.State.RETURN)
		h.has_target = false
		h.watch_ticks = 0
		_go_home(h)
		return
	var t: Player = pick_target(h, players)
	if t == null:
		var watched: Player = _watched_in_light(h, players)
		if watched != null and edge_wait_ticks() > 0:
			if h.state != HereticSim.State.EDGE:
				_set_state(h, HereticSim.State.EDGE)
				if h.watch_ticks == 0:
					count("edge_waits")
			h.state_ticks += 1
			# M4-fix: the wait counts from when it started watching, through hits (HURT counts on too), so a
			# player shooting it from inside the light cannot keep it at the edge for good.
			h.watch_ticks += 1
			h.facing = RigData.facing_toward(h.pos, watched.sim_position)
			if h.watch_ticks >= edge_wait_ticks():
				_set_state(h, HereticSim.State.RETURN)
				h.has_target = false
				h.watch_ticks = 0
			return
		h.has_target = false
		h.watch_ticks = 0
		if h.pos.distance_to(h.home) > Config.HERETIC_HOME_IDLE_PX:
			_set_state(h, HereticSim.State.RETURN)
			_go_home(h)
		else:
			_set_state(h, HereticSim.State.IDLE)
		return
	h.has_target = true
	h.watch_ticks = 0
	h.target_id = t.get_instance_id()
	_set_state(h, HereticSim.State.CHASE)
	var d: Vector2 = t.sim_position - h.pos
	if d.length() <= Config.HERETIC_ATTACK_RANGE_PX:
		h.facing = RigData.facing_toward(h.pos, t.sim_position)
		if h.cooldown == 0:
			h.state = HereticSim.State.ATTACK
			h.state_ticks = 0
			h.attack_dir = d.normalized() if d != Vector2.ZERO else Vector2(PlayerSim.facing_vector(h.facing))
			count("attacks")
			attacks_started += 1
		return
	_move_toward(h, t.sim_position)


func _set_state(h: HereticSim, s: int) -> void:
	if h.state != s:
		h.state = s
		h.state_ticks = 0
		h.stuck = 0


## The nearest player on this map that is up, in sight (Config.HERETIC_SIGHT_PX, no wall between) and,
## unless Config.HERETIC_ENTERS_LIGHT, outside the light (§2.3 ○ aggro = PROVISIONAL "nearest").
func pick_target(h: HereticSim, players: Array[Player]) -> Player:
	var best: Player = null
	var best_d: float = INF
	for p: Player in players:
		if not can_target(h, p):
			continue
		var d: float = h.pos.distance_to(p.sim_position)
		if d < best_d:
			best = p
			best_d = d
	return best


func can_target(h: HereticSim, p: Player) -> bool:
	if not p.vitals.alive() or not _in_sight(h, p):
		return false
	return Config.HERETIC_ENTERS_LIGHT or not in_light(p.sim_position)


func _in_sight(h: HereticSim, p: Player) -> bool:
	return h.pos.distance_to(p.sim_position) <= Config.HERETIC_SIGHT_PX \
		and Combat.line_clear(data, Combat.body_point(h.pos), Combat.body_point(p.sim_position))


## Its target, up and in sight but inside the light (the edge wait), or null.
func _watched_in_light(h: HereticSim, players: Array[Player]) -> Player:
	if not h.has_target or Config.HERETIC_ENTERS_LIGHT:
		return null
	for p: Player in players:
		if p.get_instance_id() == h.target_id and p.vitals.alive() and in_light(p.sim_position) and _in_sight(h, p):
			return p
	return null


## The knife lands (the hit tick): every player up within the hit reach and arc along the attack's
## direction, no wall between, and (unless Config.HERETIC_ENTERS_LIGHT) not in the light.
func _knife(h: HereticSim, players: Array[Player]) -> void:
	count("knife_swings")
	for p: Player in players:
		if not p.vitals.alive():
			continue
		if not Config.HERETIC_ENTERS_LIGHT and in_light(p.sim_position):
			continue
		if Combat.melee_hits(data, h.pos, h.attack_dir, p.sim_position, Config.HERETIC_HIT_REACH_PX, Config.HERETIC_HIT_ARC_DEG):
			var ev: int = p.take_hit(Config.HERETIC_DAMAGE)
			if ev & PlayerSim.HURT:
				count("player_hits")
			else:
				count("player_hits_dodged")
			if ev & PlayerSim.DOWNED:
				count("downed")


## One step toward `to` (8 ways, Config.HERETIC_SPEED, walking's collision). Never into the light
## (unless Config.HERETIC_ENTERS_LIGHT): the step is cut to one axis, or not taken. Returns whether it moved.
func _move_toward(h: HereticSim, to: Vector2) -> bool:
	var d: Vector2 = to - h.pos
	var dz: float = Config.HERETIC_AXIS_DEAD_ZONE_PX
	var dir: Vector2i = Vector2i(0 if absf(d.x) < dz else (1 if d.x > 0.0 else -1), 0 if absf(d.y) < dz else (1 if d.y > 0.0 else -1))
	if dir == Vector2i.ZERO:
		return false
	var tries: Array[Vector2i] = [dir]
	if dir.x != 0 and dir.y != 0:
		tries.append(Vector2i(dir.x, 0))
		tries.append(Vector2i(0, dir.y))
	for t: Vector2i in tries:
		var next: Vector2 = Movement.step(data, h.pos, t, Config.NET_TICK, Config.HERETIC_SPEED)
		if next == h.pos:
			continue
		if not Config.HERETIC_ENTERS_LIGHT and not Combat.box_outside_light(data, safe, next):
			continue
		h.pos = next
		h.walking = true
		h.facing = Movement.facing_for(t, h.facing)
		return true
	return false


## Back toward home; there (or stuck a second) it idles and that spot is home.
func _go_home(h: HereticSim) -> void:
	var before: float = h.pos.distance_to(h.home)
	if before <= Config.HERETIC_HOME_ARRIVE_PX or not _move_toward(h, h.home) or h.pos.distance_to(h.home) >= before - 0.01:
		h.stuck += 1
	else:
		h.stuck = 0
	if h.pos.distance_to(h.home) <= Config.HERETIC_HOME_ARRIVE_PX or h.stuck >= Config.HERETIC_HOME_STUCK_TICKS:
		h.home = h.pos
		_set_state(h, HereticSim.State.IDLE)
		h.walking = false


## Damage on heretic `h`: staggered (an attack it started goes on unless
## Config.HERETIC_HURT_INTERRUPTS_ATTACK), or dead at 0. `by` (M4b): the attacker's node instance id.
func hit_heretic(h: HereticSim, amount: int, by: int = 0) -> void:
	if not h.alive():
		return
	h.hp = maxi(h.hp - amount, 0)
	h.flash_ticks = Config.HIT_FLASH_TICKS
	count("heretic_hits")
	if logging:
		var r: Hit = Hit.new()
		r.heretic_id = h.id
		r.amount = amount
		r.hp_after = h.hp
		r.by_id = by
		r.killed = h.hp == 0
		hits.append(r)
	if h.hp == 0:
		h.state = HereticSim.State.DEAD
		h.state_ticks = 0
		h.walking = false
		_end_poison(h)  # M6-fix: a heretic killed while poisoned is no longer poisoned
		count("killed")
		return
	if h.state == HereticSim.State.ATTACK and not Config.HERETIC_HURT_INTERRUPTS_ATTACK:
		return
	h.state = HereticSim.State.HURT
	h.state_ticks = 0


## M6a: poison on heretic `h` (a splash of the poison potion): `damage` every Config.POISON_INTERVAL_TICKS for
## `ticks` (the first one an interval later). One already poisoned keeps the longer time and the larger damage
## (Config.EFFECT_REFRESH_KEEPS_STRONGER) and takes the new thrower as the one a death counts for. `by`: the
## thrower's node instance id. False when it is dead.
func poison_heretic(h: HereticSim, damage: int, ticks: int, by: int = 0) -> bool:
	if not h.alive() or damage <= 0 or ticks <= 0:
		return false
	if h.poison_ticks > 0 and Config.EFFECT_REFRESH_KEEPS_STRONGER:
		h.poison_damage = maxi(h.poison_damage, damage)
		h.poison_ticks = maxi(h.poison_ticks, ticks)
	else:
		h.poison_damage = damage
		h.poison_ticks = ticks
		h.poison_timer = Config.POISON_INTERVAL_TICKS
	h.poison_by = by
	count("poisoned")
	return true


## M6a: one tick of a heretic's poison (step(), alive heretics): a poison tick takes HP without a stagger and
## does not stop an attack (Config "M6a"); at 0 it dies like any other kill (counted "killed", a Hit record
## for the thrower with logging on: the host counts it as that player's kill, M6b). A dead heretic's poison
## ends (M6-fix: whatever killed it, hit_heretic too).
func _tick_poison(h: HereticSim) -> void:
	h.poison_ticks -= 1
	h.poison_timer -= 1
	if h.poison_timer <= 0:
		h.poison_timer = Config.POISON_INTERVAL_TICKS
		_poison_damage(h, h.poison_damage)
	if h.poison_ticks <= 0 or not h.alive():
		_end_poison(h)


static func _end_poison(h: HereticSim) -> void:
	h.poison_ticks = 0
	h.poison_damage = 0
	h.poison_timer = 0


func _poison_damage(h: HereticSim, amount: int) -> void:
	h.hp = maxi(h.hp - amount, 0)
	h.flash_ticks = Config.HIT_FLASH_TICKS
	count("poison_hits")
	if logging:
		var r: Hit = Hit.new()
		r.heretic_id = h.id
		r.amount = amount
		r.hp_after = h.hp
		r.by_id = h.poison_by
		r.killed = h.hp == 0
		r.poison = true
		hits.append(r)
	if h.hp == 0:
		h.state = HereticSim.State.DEAD
		h.state_ticks = 0
		h.walking = false
		count("killed")
		count("poison_kills")


## IMPL (M6a): a thrown potion this close (px) past a whole tick's flight lands this tick.
const FLASK_ARRIVE_PX: float = 0.001


## M6a: player `p` throws potion `item` at `grade` (its release frame) toward ground point `target` (already
## clamped to Config.THROW_RANGE_PX, Potions.throw_target). The bottle leaves from its body point. Returns it.
## M6b: `owner_slot` = the thrower's session slot; with logging on, a thrown event goes to the map's clients.
func throw_potion(p: Player, item: StringName, grade: int, target: Vector2, owner_slot: int = 255) -> Flask:
	var f: Flask = Flask.new()
	f.id = next_id
	next_id += 1
	f.item = item
	f.grade = grade
	f.origin = Combat.body_point(p.sim_position)
	f.pos = f.origin
	f.target = Potions.throw_target(f.origin, target)
	f.owner_id = p.get_instance_id()
	f.owner_slot = owner_slot
	f.born = now
	flasks.append(f)
	count("throws")
	if logging:
		shot_events.append(flask_event(f))
	return f


## M6b: the thrown event of flask `f` (also what a late client gets for one in the air).
static func flask_event(f: Flask) -> NetProtocol.ShotEvent:
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.THROW
	e.id = f.id
	e.item = f.item
	e.owner = f.owner_slot
	e.tick = f.born
	e.pos = f.origin
	e.target = f.target
	return e


## M6b: the broke event of splash `s` (also what a late client gets for one still shown).
static func splash_event(s: Splash) -> NetProtocol.ShotEvent:
	var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	e.kind = NetProtocol.ShotEvent.Kind.SPLASH
	e.id = s.id
	e.item = s.item
	e.tick = s.born
	e.pos = s.pos
	e.why = maxi(NetProtocol.FLASK_STOPS.find(s.why), 0)
	return e


## One tick of a thrown potion: Config.THROW_SPEED along the ground toward its target in steps of at most
## Config.SHOT_STEP_PX (flask_points); a tile that stops a shot (walls, faces, blocking placeables, the map's
## edge; every tile between two steps counts, like a shot) stops it at the step before; bodies do not (it is
## lobbed). Landed or stopped, it splashes (_splash).
func _step_flask(f: Flask, players: Array[Player]) -> void:
	if f.done:
		return
	var arrive: bool = flask_arrives(f.pos, f.target)  # this tick it lands (float slack: no extra tick)
	for to: Vector2 in flask_points(f.pos, f.target):
		var from: Vector2 = f.pos
		var blocked: bool = false
		for c: Vector2i in Combat.cells_on_line(from, to):
			if Combat.blocks_line(data, c):
				blocked = true
				break
		if blocked:
			f.stopped_by = "wall"
			_splash(f, from, players)
			return
		f.pos = to
	if arrive:
		f.stopped_by = "landed"
		_splash(f, f.target, players)


## M6b: whether a thrown potion at ground point `pos` lands on `target` this tick (within a tick's flight).
static func flask_arrives(pos: Vector2, target: Vector2) -> bool:
	return pos.distance_to(target) <= Config.THROW_SPEED / Config.NET_TICK_RATE + FLASK_ARRIVE_PX


## M6b: the points one tick of a thrown potion's flight from `pos` toward `target` passes (the last = where the
## tick leaves it; `target` itself on the tick it lands). The host's flight (_step_flask, which stops it at a
## wall) and a client's drawing (net/net_combat.gd) both step with this, so a client draws the host's points.
static func flask_points(pos: Vector2, target: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var left: float = pos.distance_to(target)
	var arrive: bool = flask_arrives(pos, target)
	var dist: float = left if arrive else Config.THROW_SPEED / Config.NET_TICK_RATE
	var dir: Vector2 = (target - pos).normalized() if left > 0.0 else Vector2.ZERO
	var steps: int = maxi(ceili(dist / Config.SHOT_STEP_PX), 1)
	var at: Vector2 = pos
	for i: int in steps:
		var to: Vector2 = target if arrive and i == steps - 1 else at + dir * (dist / steps)
		out.append(to)
		at = to
	return out


## M6a: the potion breaks at ground point `at`: everyone it reaches (Potions: within
## Config.THROW_SPLASH_RADIUS_PX of `at`, measured to their body point, no wall between) gets it. Healing and
## the buff work on the players up (the thrower too); poison on the heretics alive (and on players only with
## Config.FRIENDLY_FIRE).
func _splash(f: Flask, at: Vector2, players: Array[Player]) -> void:
	f.done = true
	f.pos = at
	var s: Splash = Splash.new()
	s.id = f.id
	s.item = f.item
	s.pos = at
	s.why = f.stopped_by
	s.born = now
	splashes.append(s)
	count("splashes")
	if logging:
		shot_events.append(splash_event(s))
	var effect: int = Potions.effect_of(f.item)
	if effect == Potions.Effect.POISON:
		for h: HereticSim in heretics:
			if h.alive() and in_splash(at, h.pos) \
					and poison_heretic(h, Potions.poison_damage(f.grade), Potions.poison_ticks(f.grade), f.owner_id):
				s.heretics += 1
	if effect != Potions.Effect.POISON or Config.FRIENDLY_FIRE:
		for p: Player in players:
			if not in_splash(at, p.sim_position):
				continue
			if splash_revives(effect) and p.vitals.life == Vitals.Life.DOWN:
				p.revive_now()  # M6b, PROVISIONAL Config.THROW_HEAL_REVIVES (off: F revives, a splash does not)
				count("splash_revives")
			if p.vitals.alive() and p.apply_potion(f.item, f.grade) != 0:
				s.players += 1
	count("splash_players", s.players)
	count("splash_heretics", s.heretics)


## M6b: whether a splash of a potion with effect `effect` (Potions.Effect) gets a downed player up
## (Config.THROW_HEAL_REVIVES, PROVISIONAL: off, a thrown healing potion heals only players who are up).
static func splash_revives(effect: int) -> bool:
	return Config.THROW_HEAL_REVIVES and effect == Potions.Effect.HEAL


## M6a: a splash at ground point `at` reaches the body standing at `feet` (its body point within
## Config.THROW_SPLASH_RADIUS_PX, no blocking tile between).
func in_splash(at: Vector2, feet: Vector2) -> bool:
	var body: Vector2 = Combat.body_point(feet)
	return body.distance_to(at) <= Config.THROW_SPLASH_RADIUS_PX and Combat.line_clear(data, at, body)


## The heretic a shot at ground point `point` hits (Combat.shot_hits_body: the drawn shot inside its
## drawn figure; M4-fix, was a radius around the feet box), the first in the list, or null.
func heretic_at(point: Vector2) -> HereticSim:
	for h: HereticSim in heretics:
		if h.alive() and Combat.shot_hits_body(point, h.pos):
			return h
	return null


# --- players' attacks ------------------------------------------------------------------------------

## Player `p`'s weapon `item` lands (its hit frame) along aim code `aim`: a melee arc hits every heretic
## (and the standing shrine) in it, a bow or holy light lets a shot go. Returns world edits (the shrine
## breaking). `owner_slot` (M4b): the attacker's session slot, for the shot events.
func player_attack(p: Player, item: StringName, aim: int, players: Array[Player] = [], owner_slot: int = 255) -> Array[EditLog.WorldEdit]:
	var edits: Array[EditLog.WorldEdit] = []
	var a: Combat.Attack = Combat.attack_for(item)
	if a == null:
		return edits
	var dir: Vector2 = Combat.aim_vector(aim)
	count("player_attacks")
	if a.kind == Combat.Kind.MELEE:
		for h: HereticSim in heretics:
			if h.alive() and Combat.melee_hits(data, p.sim_position, dir, h.pos, a.reach, a.arc_deg):
				hit_heretic(h, a.damage, p.get_instance_id())
		if Config.FRIENDLY_FIRE:
			for o: Player in players:
				if o != p and Combat.melee_hits(data, p.sim_position, dir, o.sim_position, a.reach, a.arc_deg):
					o.take_hit(a.damage)
		var rect: Rect2i = shrine_rect()
		if rect.has_area() and Combat.melee_hits_rect(data, p.sim_position, dir, rect, a.reach, a.arc_deg):
			edits.append_array(damage_shrine(a.damage))
		return edits
	var s: Shot = Shot.new()
	s.id = next_id
	next_id += 1
	s.kind = a.kind
	s.dir = dir
	s.pos = Combat.body_point(p.sim_position)
	s.speed = a.speed
	s.left = a.life_ticks()
	s.damage = a.damage
	s.owner_id = p.get_instance_id()
	s.aim = posmod(aim, Combat.AIM_STEPS)
	s.item = item
	s.owner_slot = owner_slot
	s.born = now
	s.origin = s.pos
	shots.append(s)
	count("shots")
	if logging:
		var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
		e.kind = NetProtocol.ShotEvent.Kind.SPAWN
		e.id = s.id
		e.item = item
		e.owner = owner_slot
		e.aim = s.aim
		e.tick = now
		e.pos = s.pos
		shot_events.append(e)
	return edits


func _step_shot(s: Shot, players: Array[Player]) -> Array[EditLog.WorldEdit]:
	var edits: Array[EditLog.WorldEdit] = []
	if s.done:
		return edits
	var dist: float = s.speed / Config.NET_TICK_RATE
	var steps: int = maxi(ceili(dist / Config.SHOT_STEP_PX), 1)
	var rect: Rect2i = shrine_rect()
	for i: int in steps:
		var from: Vector2 = s.pos
		s.pos += s.dir * (dist / steps)
		var c: Vector2i = Aim.cell_of(s.pos)
		# M4-fix: every tile the step passes through counts (an exact grid walk, like line of sight), not
		# just the tile under the new point: a shot no longer slips between two walls touching at a corner.
		var cells: Array[Vector2i] = [c]
		if c != Aim.cell_of(from):
			cells = Combat.cells_on_line(from, s.pos)
		var why: String = ""
		for cc: Vector2i in cells:
			if rect.has_area() and rect.has_point(cc):
				why = "shrine"
			elif Combat.blocks_line(data, cc):
				why = "wall"
			if not why.is_empty():
				if cc != c:
					s.pos = from  # a tile the step crossed between its two points: it stops before it
				break
		if why == "shrine":
			edits.append_array(damage_shrine(s.damage))
			_stop(s, "shrine")
			return edits
		if why == "wall":
			_stop(s, "wall")
			return edits
		var h: HereticSim = heretic_at(s.pos)
		if h != null:
			hit_heretic(h, s.damage, s.owner_id)
			_stop(s, "heretic")
			return edits
		if Config.FRIENDLY_FIRE:
			for o: Player in players:
				if o.get_instance_id() != s.owner_id and o.vitals.alive() and Combat.shot_hits_body(s.pos, o.sim_position):
					o.take_hit(s.damage)
					_stop(s, "player")
					return edits
	s.left -= 1
	if s.left <= 0:
		_stop(s, "spent")
	return edits


func _stop(s: Shot, why: String) -> void:
	s.done = true
	s.stopped_by = why
	count("shot_" + why)
	if logging:
		var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
		e.kind = NetProtocol.ShotEvent.Kind.END
		e.id = s.id
		e.tick = now
		e.pos = s.pos
		e.why = maxi(NetProtocol.SHOT_STOPS.find(why), 0)
		shot_events.append(e)


## M4b: the heretics as the host sends them at tick `tick` (lowest id first, NetProtocol.enemy_of).
func enemy_states(tick: int) -> Array[NetProtocol.EnemyState]:
	var out: Array[NetProtocol.EnemyState] = []
	for h: HereticSim in heretics:
		out.append(NetProtocol.enemy_of(h, tick))
	out.sort_custom(func(a: NetProtocol.EnemyState, b: NetProtocol.EnemyState) -> bool: return a.id < b.id)
	return out


## M4b: the standing shrine's hit points as sent (0 when none stands).
func shrine_hp_now() -> int:
	return shrine_hp if shrine_rect().has_area() else 0


## M4b: anything fighting on this map (a heretic not idle at home, a shot in flight): the traffic counts
## it as a fight.
func fighting() -> bool:
	if not shots.is_empty() or not flasks.is_empty() or not splashes.is_empty():
		return true
	for h: HereticSim in heretics:
		if h.state != HereticSim.State.IDLE or h.walking:
			return true
	return false


# --- the shrine ----------------------------------------------------------------------------------

## Damage on the standing shrine (● §3.0: anyone destroys a corruption source by combat). At 0 it
## breaks: its footprint becomes WorldData.PLACEABLE_SHRINE_BROKEN (edits).
func damage_shrine(amount: int) -> Array[EditLog.WorldEdit]:
	var edits: Array[EditLog.WorldEdit] = []
	var rect: Rect2i = shrine_rect()
	if not rect.has_area() or shrine_hp <= 0:
		return edits
	shrine_hp = maxi(shrine_hp - amount, 0)
	shrine_flash = Config.HIT_FLASH_TICKS
	count("shrine_hits")
	if shrine_hp > 0:
		return edits
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			edits.append(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x, y), WorldData.PLACEABLE_SHRINE_BROKEN))
	count("shrine_broken")
	return edits


# --- spawning ------------------------------------------------------------------------------------

## Whether this map spawns at all now: the dungeon stops once its shrine is broken
## (Config.SHRINE_STOPS_SPAWNS).
func spawns_now() -> bool:
	if map_id == Config.MAP_DUNGEON and Config.SHRINE_STOPS_SPAWNS and not shrine_rect().has_area():
		return false
	return not spawn_cells.is_empty()


func cap() -> int:
	return Config.HERETIC_CAP_DUNGEON if map_id == Config.MAP_DUNGEON else Config.HERETIC_CAP_SURFACE


## One spawn try: below the cap, a random spawn tile whose feet point (Arena.spawn_feet) can stand,
## lies wholly outside the light (game-concept §9.3: the safe radius suppresses spawns) and is at least
## Config.HERETIC_SPAWN_MIN_PLAYER_PX from every player. Returns the heretic or null.
func try_spawn(players: Array[Player]) -> HereticSim:
	if not spawns_now() or alive_heretics() >= cap():
		return null
	for attempt: int in Config.HERETIC_SPAWN_TRIES:
		var c: Vector2i = spawn_cells[rng.randi_range(0, spawn_cells.size() - 1)]
		var feet: Vector2 = spawn_feet(c)
		if spawn_ok(feet, players):
			return spawn_heretic(feet)
	count("spawn_misses")
	return null


func spawn_ok(feet: Vector2, players: Array[Player]) -> bool:
	if not Movement.can_stand(data, feet) or not Combat.box_outside_light(data, safe, feet):
		return false
	for p: Player in players:
		if p.sim_position.distance_to(feet) < Config.HERETIC_SPAWN_MIN_PLAYER_PX:
			return false
	return true


## The feet point a heretic spawns at on tile `c` (low in the tile, like an arrival point).
static func spawn_feet(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * Config.TILE, (c.y + 1) * Config.TILE - Config.ARRIVAL_FEET_INSET_PX)


## Surface spawn tiles: in and around the corruption zones (ash and Config.HERETIC_SPAWN_ASH_REACH_TILES
## beyond), standable and wholly outside the light.
static func surface_spawn_cells(p_data: WorldData, p_safe: SafeZone) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var reach: int = Config.HERETIC_SPAWN_ASH_REACH_TILES
	var near: Dictionary[Vector2i, bool] = {}
	var corruption: PackedByteArray = p_data.layers[WorldData.Layer.CORRUPTION]
	for i: int in corruption.size():
		if corruption[i] == 0:
			continue
		var c: Vector2i = Vector2i(i % p_data.size.x, i / p_data.size.x)
		for y: int in range(c.y - reach, c.y + reach + 1):
			for x: int in range(c.x - reach, c.x + reach + 1):
				near[Vector2i(x, y)] = true
	for c: Vector2i in near:
		if not p_data.in_bounds(c):
			continue
		var feet: Vector2 = spawn_feet(c)
		if Movement.can_stand(p_data, feet) and Combat.box_outside_light(p_data, p_safe, feet):
			out.append(c)
	out.sort()
	return out


## Dungeon spawn tiles: standable floor at least Config.HERETIC_SPAWN_ARRIVAL_MIN_TILES walking steps
## (4-neighbour) from the arrival point's tile, so heretics come from rooms away from the arrival room.
static func dungeon_spawn_cells(p_data: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var exit: Rect2i = DungeonGen.exit_rect(p_data)
	if not exit.has_area():
		return out
	var start: Vector2i = Aim.feet_cell(DungeonGen.arrival_point(p_data))
	var dist: Dictionary[Vector2i, int] = {start: 0}
	var queue: Array[Vector2i] = [start]
	var i: int = 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in DungeonGen.STEPS:
			var n: Vector2i = c + d
			if dist.has(n) or not p_data.in_bounds(n) or Movement.is_blocked(p_data, n):
				continue
			dist[n] = dist[c] + 1
			queue.append(n)
	for c: Vector2i in queue:
		if dist[c] >= Config.HERETIC_SPAWN_ARRIVAL_MIN_TILES and Movement.can_stand(p_data, spawn_feet(c)):
			out.append(c)
	out.sort()
	return out


## Walking steps from the dungeon's arrival tile to every reachable tile (tests).
static func arrival_distances(p_data: WorldData) -> Dictionary[Vector2i, int]:
	var start: Vector2i = Aim.feet_cell(DungeonGen.arrival_point(p_data))
	var dist: Dictionary[Vector2i, int] = {start: 0}
	var queue: Array[Vector2i] = [start]
	var i: int = 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in DungeonGen.STEPS:
			var n: Vector2i = c + d
			if dist.has(n) or not p_data.in_bounds(n) or Movement.is_blocked(p_data, n):
				continue
			dist[n] = dist[c] + 1
			queue.append(n)
	return dist
