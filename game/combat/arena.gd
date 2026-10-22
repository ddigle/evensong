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

var data: WorldData
var safe: SafeZone
var map_id: int = Config.MAP_SURFACE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var heretics: Array[HereticSim] = []
var shots: Array[Shot] = []
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


## For `p_data` (its map id says which spawn rule). `world_seed` makes the spawns repeatable.
func setup(p_data: WorldData, world_seed: int) -> void:
	data = p_data
	map_id = data.map_id
	safe = SafeZone.for_world(data)
	rng.seed = hash([world_seed, map_id, 0xC0BA7])
	heretics.clear()
	shots.clear()
	next_id = 1
	spawn_timer = 0
	stats.clear()
	shrine_hp = Config.SHRINE_HP if shrine_rect().has_area() else 0
	shrine_flash = 0
	spawn_cells = surface_spawn_cells(data, safe) if map_id == Config.MAP_SURFACE else dungeon_spawn_cells(data)


func count(key: String, n: int = 1) -> void:
	var v: int = stats.get(key, 0)
	stats[key] = v + n


## The standing shrine's footprint (empty when there is none or it is broken).
func shrine_rect() -> Rect2i:
	return DungeonGen.shrine_rect(data)


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


# --- revive --------------------------------------------------------------------------------------

## A downed player's revive (● gameplay-design §2.6 flow; Config REVIVE_*): the first player up within
## Config.REVIVE_REACH_PX holding F (not acting, dashing or staggered) adds a tick; a cleric revives at
## once, anyone else after Config.REVIVE_TICKS. Nobody holding: the progress resets.
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


static func reviver_for(p: Player, players: Array[Player]) -> Player:
	for r: Player in players:
		if r == p or not r.vitals.alive() or not r.interact_held or r.action_anim >= 0 or r.vitals.dashing() \
				or r.vitals.staggered():
			continue
		if r.sim_position.distance_to(p.sim_position) <= Config.REVIVE_REACH_PX:
			return r
	return null


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
	match h.state:
		HereticSim.State.DEAD:
			h.state_ticks += 1
			return
		HereticSim.State.HURT:
			h.walking = false
			h.state_ticks += 1
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
		_go_home(h)
		return
	var t: Player = pick_target(h, players)
	if t == null:
		var watched: Player = _watched_in_light(h, players)
		if watched != null and edge_wait_ticks() > 0:
			if h.state != HereticSim.State.EDGE:
				_set_state(h, HereticSim.State.EDGE)
				count("edge_waits")
			h.state_ticks += 1
			h.facing = RigData.facing_toward(h.pos, watched.sim_position)
			if h.state_ticks >= edge_wait_ticks():
				_set_state(h, HereticSim.State.RETURN)
				h.has_target = false
			return
		h.has_target = false
		if h.pos.distance_to(h.home) > 2.0:
			_set_state(h, HereticSim.State.RETURN)
			_go_home(h)
		else:
			_set_state(h, HereticSim.State.IDLE)
		return
	h.has_target = true
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
	var dir: Vector2i = Vector2i(0 if absf(d.x) < 0.5 else (1 if d.x > 0.0 else -1), 0 if absf(d.y) < 0.5 else (1 if d.y > 0.0 else -1))
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
	if before <= 1.5 or not _move_toward(h, h.home) or h.pos.distance_to(h.home) >= before - 0.01:
		h.stuck += 1
	else:
		h.stuck = 0
	if h.pos.distance_to(h.home) <= 1.5 or h.stuck >= 60:
		h.home = h.pos
		_set_state(h, HereticSim.State.IDLE)
		h.walking = false


## Damage on heretic `h`: staggered (an attack it started goes on unless
## Config.HERETIC_HURT_INTERRUPTS_ATTACK), or dead at 0.
func hit_heretic(h: HereticSim, amount: int) -> void:
	if not h.alive():
		return
	h.hp = maxi(h.hp - amount, 0)
	h.flash_ticks = Config.HIT_FLASH_TICKS
	count("heretic_hits")
	if h.hp == 0:
		h.state = HereticSim.State.DEAD
		h.state_ticks = 0
		h.walking = false
		count("killed")
		return
	if h.state == HereticSim.State.ATTACK and not Config.HERETIC_HURT_INTERRUPTS_ATTACK:
		return
	h.state = HereticSim.State.HURT
	h.state_ticks = 0


## The heretic whose body a point is within Config.BODY_HIT_RADIUS_PX of (lowest id), or null.
func heretic_at(point: Vector2) -> HereticSim:
	for h: HereticSim in heretics:
		if h.alive() and Combat.body_point(h.pos).distance_to(point) <= Config.BODY_HIT_RADIUS_PX:
			return h
	return null


# --- players' attacks ------------------------------------------------------------------------------

## Player `p`'s weapon `item` lands (its hit frame) along aim code `aim`: a melee arc hits every heretic
## (and the standing shrine) in it, a bow or holy light lets a shot go. Returns world edits (the shrine
## breaking).
func player_attack(p: Player, item: StringName, aim: int, players: Array[Player] = []) -> Array[EditLog.WorldEdit]:
	var edits: Array[EditLog.WorldEdit] = []
	var a: Combat.Attack = Combat.attack_for(item)
	if a == null:
		return edits
	var dir: Vector2 = Combat.aim_vector(aim)
	count("player_attacks")
	if a.kind == Combat.Kind.MELEE:
		for h: HereticSim in heretics:
			if h.alive() and Combat.melee_hits(data, p.sim_position, dir, h.pos, a.reach, a.arc_deg):
				hit_heretic(h, a.damage)
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
	shots.append(s)
	count("shots")
	return edits


func _step_shot(s: Shot, players: Array[Player]) -> Array[EditLog.WorldEdit]:
	var edits: Array[EditLog.WorldEdit] = []
	if s.done:
		return edits
	var dist: float = s.speed / Config.NET_TICK_RATE
	var steps: int = maxi(ceili(dist / Config.SHOT_STEP_PX), 1)
	for i: int in steps:
		s.pos += s.dir * (dist / steps)
		var c: Vector2i = Aim.cell_of(s.pos)
		var rect: Rect2i = shrine_rect()
		if rect.has_area() and rect.has_point(c):
			edits.append_array(damage_shrine(s.damage))
			_stop(s, "shrine")
			return edits
		if Combat.blocks_line(data, c):
			_stop(s, "wall")
			return edits
		var h: HereticSim = heretic_at(s.pos)
		if h != null:
			hit_heretic(h, s.damage)
			_stop(s, "heretic")
			return edits
		if Config.FRIENDLY_FIRE:
			for o: Player in players:
				if o.get_instance_id() != s.owner_id and o.vitals.alive() \
						and Combat.body_point(o.sim_position).distance_to(s.pos) <= Config.BODY_HIT_RADIUS_PX:
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
	for attempt: int in 24:
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
