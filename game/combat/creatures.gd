class_name Creatures
extends RefCounted
## The surface's creatures (M11a): one herd per world, the Arena of the surface holds it (Arena.herd) so that every attack that can
## hit a heretic can hit a creature, and whoever runs the world steps it on the game clock (Main.step_creatures, every map's
## tick, like the farms and the shop). Pure data and rules, no nodes of its own: the picture is actors/creature_view.gd
## through CombatView. Values are PROVISIONAL (Config "M11a", one table Config.CREATURES).
##
## None attacks. An unalarmed creature stands, then walks to a spot near home; a player up inside its alert radius, or a hit, makes
## it bolt (a burst faster than a player walks) straight away, then it stops and rests, when a walking player catches it. Fleeing
## and wandering share the player's collision (Movement.step: walls, built pieces, fixtures, closed doors, the map's edge; the
## slice has no water) and keep out of the altar's light and off corrupted tiles (can_walk); a creature that stands where can_walk says
## no (the altar's new light lies on it, and the light may cover corruption) walks to ground it may stand on (_walk_clear). It ignores
## heretics and they ignore it: nothing here reads them, and Arena's heretic rules take players only.
##
## Spawning: at the start every prey kind up to its cap, and a dead one's place is taken Config row `respawn_ticks` of game time
## later (a Respawn waits; a try that finds no tile waits Config.CREATURE_SPAWN_RETRY_TICKS more). spawn_ok reads the live world,
## so what players built or purified since counts at once.
##
## Determinism: its own RandomNumberGenerator, seeded from the world seed and Config.CREATURE_SALT, and its own ids: heretic spawns,
## prayer directions, the generators and every id of the Arena stay as they were (no world edit but a kill's drops).
##
## Killing: the killing blow's class decides the drops (● gameplay-design §3.0 R11, §3.4: Config.HUNTER_CLASS gets `drops_hunter`,
## anyone else `drops_other`; no dice). They go out as ordinary drops (EditLog.WorldEdit.drop_put, `edits`: the caller applies them,
## like the other world rules). What happened goes into `kills` for the caller's log.
##
## M11b: the rare zone (world/rare_zone.gd, placed in setup, data.rare_zone): the rare kinds spawn only inside it and never leave it
## (CreatureSim.bound, can_walk). ● "희귀 생물 포획·사냥은 아처만": a blow on a rare creature by anyone but the archer does nothing but show that it
## did nothing (shut_out, refuse: Arena's every attack path asks first). A snare holds one (hold) and takes it (capture: no corpse, no
## drops, its place waits like a death's). A kill and a capture go to the world's collection (items/collection.gd), when it has one.
##
## M11c: a session's host holds the same herd in its surface Arena and steps it every tick (SessionHost._step_creatures); a client's mirror
## arena holds a Creatures with no rules running (Creatures.mirror: only `list`, filled from the host's batches, net/net_combat.gd).

## What a kill did (for the log and tests). M11b: also a refused blow's kind and class (`refusals`).
class Kill:
	extends RefCounted
	var kind: StringName = &""
	var who: String = ""
	## M11c: the blow's player (node instance id, 0 = nobody): the host's log names its slot.
	var by: int = 0
	var at: Vector2i = Vector2i.ZERO
	## [item, count] rows.
	var drops: Array = []


## A dead creature's place waiting to be taken (`due` on the herd's clock).
class Respawn:
	extends RefCounted
	var kind: StringName = &""
	var due: int = 0


## The eight walking directions, a turn in order (dir_of; the tries around the way it wants to go).
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
	Vector2i(0, -1), Vector2i(1, -1)]
## Steps of STEPS tried around the way it wants to go, in order.
const FLEE_TURNS: Array[int] = [0, 1, -1, 2, -2]
## Every way of STEPS around the one straight out, in order (_way_clear: between two as near, the straighter).
const CLEAR_TURNS: Array[int] = [0, 1, -1, 2, -2, 3, -3, 4]

var data: WorldData
var safe: SafeZone
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var list: Array[CreatureSim] = []
var waiting: Array[Respawn] = []
var next_id: int = 1
## Game ticks stepped.
var clock: int = 0
## Natural spawning on / off (--test-no-creatures, tests); spawn() still puts one down.
var spawning: bool = true
## The world edits of kills since the caller last took them (step() hands them over), and what happened (the caller clears it).
var edits: Array[EditLog.WorldEdit] = []
var kills: Array[Kill] = []
## M11b: the blows refused since the caller last looked (it clears them).
var refusals: Array[Kill] = []
## Counters for logs and tests.
var stats: Dictionary[String, int] = {}
var _synced_altar: Rect2i = Rect2i()


## For the surface `p_data` (another map has no creatures: M11a's rule, the herd stays empty). `world_seed` makes it repeatable; with
## `p_spawning` it fills up at once (the world's start: no players yet).
func setup(p_data: WorldData, world_seed: int, p_spawning: bool = true) -> void:
	data = p_data
	safe = SafeZone.for_world(data)
	_synced_altar = data.altar_rect
	rng.seed = hash([world_seed, Config.CREATURE_SALT])
	spawning = p_spawning and data.map_id == Config.MAP_SURFACE
	list.clear()
	waiting.clear()
	edits.clear()
	kills.clear()
	refusals.clear()
	next_id = 1
	clock = 0
	if data.map_id == Config.MAP_SURFACE and data.rare_zone == null:
		data.rare_zone = RareZone.place(data, world_seed)  # M11b: also with spawning off (the picture shows it)
	if not spawning:
		return
	for kind: StringName in Config.CREATURES:
		if spawns_now(kind):
			for i: int in cap_of(kind):
				if try_spawn(kind, [] as Array[Player]) == null:
					_wait(kind, Config.CREATURE_SPAWN_RETRY_TICKS)


## M11c: a herd of nothing for a client's mirror arena (never stepped): net/net_combat.gd fills `list` for CombatView, Capture.target_at and
## the bots.
static func mirror(p_data: WorldData) -> Creatures:
	var h: Creatures = Creatures.new()
	h.data = p_data
	h.safe = SafeZone.for_world(p_data)
	h.spawning = false
	return h


## Whether kind `kind` spawns by itself here: the prey anywhere, the rare ones where the world has its zone (M11b).
func spawns_now(kind: StringName) -> bool:
	return not is_rare(kind) or data.rare_zone != null


static func is_rare(kind: StringName) -> bool:
	var rare: bool = Config.CREATURES[kind]["rare"]
	return rare


func stat(key: String) -> int:
	var v: int = stats.get(key, 0)
	return v


func count(key: String, n: int = 1) -> void:
	stats[key] = stat(key) + n


## How many of `kind` live (every kind for &"").
func alive_count(kind: StringName = &"") -> int:
	var n: int = 0
	for c: CreatureSim in list:
		if c.alive() and (kind.is_empty() or c.kind == kind):
			n += 1
	return n


# --- one tick ------------------------------------------------------------------------------------

## One game tick; `players` = the players on the surface. Returns the world edits of the kills since the last step (the caller
## applies them).
func step(players: Array[Player]) -> Array[EditLog.WorldEdit]:
	clock += 1
	if data.altar_rect != _synced_altar:
		_synced_altar = data.altar_rect
		safe = SafeZone.for_world(data)  # the altar was picked up or put down: another light
	for c: CreatureSim in list:
		_step_one(c, players)
	var staying: Array[CreatureSim] = []
	for c: CreatureSim in list:
		if not c.finished():
			staying.append(c)
	list = staying
	if spawning:
		_step_respawns(players)
	return take_edits()


## The kills' edits so far (emptied).
func take_edits() -> Array[EditLog.WorldEdit]:
	var out: Array[EditLog.WorldEdit] = edits
	edits = []
	return out


func _step_one(c: CreatureSim, players: Array[Player]) -> void:
	c.clock += 1
	c.walking = false
	if c.flash_ticks > 0:
		c.flash_ticks -= 1
	if c.refused_ticks > 0:
		c.refused_ticks -= 1
	if not c.alive():
		c.state_ticks += 1
		return
	if c.poison_ticks > 0:
		_tick_poison(c)
		if not c.alive():
			return
	if c.slow_ticks > 0:
		c.slow_ticks -= 1
		if c.slow_ticks == 0:
			c.slow_pct = 0
	if c.hold_ticks > 0:
		c.hold_ticks -= 1  # M11b: a snare holds it until its throw lands or runs out
		return
	if c.stun_ticks > 0:
		c.stun_ticks -= 1
		return
	c.state_ticks += 1
	if not can_walk(c.pos):
		_walk_clear(c)
		return
	var near: Player = _nearest_alarm(c, players)
	match c.state:
		CreatureSim.State.FLEE:
			if near != null:
				c.flee_from = near.sim_position
			_step_flee(c)
			if c.state_ticks >= c.num_i("flee_ticks"):
				_set_state(c, CreatureSim.State.REST)
			return
		CreatureSim.State.REST:
			if c.state_ticks >= c.num_i("rest_ticks"):
				_begin_idle(c)
			return
	if near != null:
		bolt(c, near.sim_position)
		_step_flee(c)
		return
	if c.state == CreatureSim.State.WANDER:
		_step_wander(c)
	elif c.state_ticks >= c.idle_ticks:
		_begin_wander(c)


func _set_state(c: CreatureSim, s: int) -> void:
	c.state = s
	c.state_ticks = 0


## The nearest player up on this map inside `c`'s alert radius, or null.
func _nearest_alarm(c: CreatureSim, players: Array[Player]) -> Player:
	var best: Player = null
	var best_d: float = c.num_f("alert_px")
	for p: Player in players:
		if not p.vitals.alive():
			continue
		var d: float = p.sim_position.distance_to(c.pos)
		if d <= best_d:
			best = p
			best_d = d
	return best


func _begin_idle(c: CreatureSim) -> void:
	_set_state(c, CreatureSim.State.IDLE)
	c.idle_ticks = rng.randi_range(Config.CREATURE_IDLE_TICKS_MIN, Config.CREATURE_IDLE_TICKS_MAX)


## Picks a spot within its wander radius of home and sets off; one it may not stand on is no spot: it stands on.
func _begin_wander(c: CreatureSim) -> void:
	var a: float = rng.randf() * TAU
	var r: float = sqrt(rng.randf()) * c.num_f("wander_px")
	var spot: Vector2 = c.home + Vector2.from_angle(a) * r
	if not Movement.can_stand(data, spot) or not can_walk(spot, c):
		_begin_idle(c)
		return
	c.target = spot
	_set_state(c, CreatureSim.State.WANDER)


func _step_wander(c: CreatureSim) -> void:
	var d: Vector2 = c.target - c.pos
	if d.length() <= Config.CREATURE_ARRIVE_PX or not _walk(c, d, c.num_f("walk_speed"), [0] as Array[int]):
		_begin_idle(c)


## Makes `c` bolt from point `from` (an alarm, a hit), whatever it was doing; a dead one stays dead.
func bolt(c: CreatureSim, from: Vector2) -> void:
	if not c.alive():
		return
	c.flee_from = from
	_set_state(c, CreatureSim.State.FLEE)
	count("bolts")


func _step_flee(c: CreatureSim) -> void:
	var away: Vector2 = c.pos - c.flee_from
	if away.length_squared() < 0.0001:
		away = Vector2(PlayerSim.facing_vector(c.facing))
	_walk(c, away, c.num_f("flee_speed"), FLEE_TURNS)


## One step along `dir` (the nearest of the eight ways, then the tries `turns` around it) at `speed`, by the player's collision
## (Movement.step: it slides along what it meets), where can_walk allows. Returns whether it moved.
func _walk(c: CreatureSim, dir: Vector2, speed: float, turns: Array[int]) -> bool:
	var i: int = dir_of(dir)
	for t: int in turns:
		var way: Vector2i = STEPS[posmod(i + t, STEPS.size())]
		var next: Vector2 = Movement.step(data, c.pos, way, Config.NET_TICK, c.speed_now(speed))
		if next == c.pos or not can_walk(next, c):
			continue
		c.pos = next
		c.walking = true
		c.facing = Movement.facing_for(way, c.facing)
		return true
	return false


## `c` stands where can_walk says no: the altar's new light lies on it, or corrupted ground is under it (the light may cover corruption, so
## the way out of one can end there). It goes the shortest straight way to ground it may stand on (_way_clear), by the walls' rule alone
## (every step on that way is one can_walk refuses), and home moves with it. M11b: one bound to the rare zone stays in it (the light may
## cover it: it stands where the zone ends).
func _walk_clear(c: CreatureSim) -> void:
	var i: int = _way_clear(c)
	for t: int in FLEE_TURNS:
		var way: Vector2i = STEPS[posmod(i + t, STEPS.size())]
		var next: Vector2 = Movement.step(data, c.pos, way, Config.NET_TICK, c.num_f("flee_speed"))
		if next != c.pos and _stays_in_zone(next, c):
			c.pos = next
			c.walking = true
			c.facing = Movement.facing_for(way, c.facing)
			c.home = c.pos
			return


## The index in STEPS of the way whose straight line from `c` first reaches ground it may stand on, within Config.CREATURE_CLEAR_REACH_PX
## and not through anything that blocks (nor through the light, when it stands outside it). None: straight out of the light.
func _way_clear(c: CreatureSim) -> int:
	var lit: bool = not Combat.box_outside_light(data, safe, c.pos)
	var out: Vector2 = c.pos - safe.center
	var straight: int = dir_of(out if out.length_squared() > 0.0001 else Vector2.DOWN)
	var best: int = straight
	var best_px: float = Config.CREATURE_CLEAR_REACH_PX + 1.0
	for t: int in CLEAR_TURNS:
		var i: int = posmod(straight + t, STEPS.size())
		var along: Vector2 = Vector2(STEPS[i]).normalized()
		var px: float = Config.CREATURE_CLEAR_STEP_PX
		while px < best_px:
			var q: Vector2 = c.pos + along * px
			if not Movement.can_stand(data, q) or (not lit and not Combat.box_outside_light(data, safe, q)):
				break
			if can_walk(q, c):
				best = i
				best_px = px
				break
			px += Config.CREATURE_CLEAR_STEP_PX
	return best


## The index in STEPS of the way nearest vector `v`.
static func dir_of(v: Vector2) -> int:
	return posmod(roundi(v.angle() / TAU * STEPS.size()), STEPS.size())


## M11b: creature `c`'s feet may be at `feet` as far as the rare zone goes: one that is not bound to it may be anywhere.
func _stays_in_zone(feet: Vector2, c: CreatureSim) -> bool:
	return c == null or not c.bound or data.rare_zone == null or data.rare_zone.holds(feet)


## A creature's feet may be at `feet` as far as the world's zones go: its box wholly outside the light and on no corrupted tile. M11b:
## creature `c`, bound to the rare zone, keeps its box inside it. (What blocks walking is Movement's.)
func can_walk(feet: Vector2, c: CreatureSim = null) -> bool:
	if not _stays_in_zone(feet, c) or not Combat.box_outside_light(data, safe, feet):
		return false
	for cell: Vector2i in Arena.cells_under(Movement.feet_box(feet)):
		if data.get_value(WorldData.Layer.CORRUPTION, cell) != 0:
			return false
	return true


# --- spawning ------------------------------------------------------------------------------------

func _wait(kind: StringName, ticks: int) -> void:
	var r: Respawn = Respawn.new()
	r.kind = kind
	r.due = clock + ticks
	waiting.append(r)


func _step_respawns(players: Array[Player]) -> void:
	if waiting.is_empty():
		return
	var still: Array[Respawn] = []
	for r: Respawn in waiting:
		if r.due > clock:
			still.append(r)
			continue
		if alive_count(r.kind) >= cap_of(r.kind) or not spawns_now(r.kind):
			continue  # a test put one down meanwhile: the place is taken (M11b: a rare kind with no zone to come back to)
		if try_spawn(r.kind, players) == null:
			r.due = clock + Config.CREATURE_SPAWN_RETRY_TICKS
			still.append(r)
	waiting = still


static func cap_of(kind: StringName) -> int:
	var v: int = Config.CREATURES[kind]["cap"]
	return v


## One spawn try for `kind`: below its cap, random tiles until one whose feet point (Arena.spawn_feet) passes spawn_ok. Returns the
## creature or null. M11b: a rare kind's tiles are the rare zone's, and it stays there.
func try_spawn(kind: StringName, players: Array[Player]) -> CreatureSim:
	if alive_count(kind) >= cap_of(kind):
		return null
	var rare: bool = is_rare(kind)
	if rare and data.rare_zone == null:
		return null
	for attempt: int in Config.CREATURE_SPAWN_TRIES:
		var c: Vector2i = _rare_tile() if rare else Vector2i(rng.randi_range(0, data.size.x - 1), rng.randi_range(0, data.size.y - 1))
		var feet: Vector2 = Arena.spawn_feet(c)
		if spawn_ok(feet, players, rare):
			var out: CreatureSim = spawn(kind, feet)
			out.bound = rare
			return out
	count("spawn_misses")
	return null


## M11b: a random tile of the rare zone's bounding square.
func _rare_tile() -> Vector2i:
	var z: RareZone = data.rare_zone
	return Vector2i(rng.randi_range(z.center.x - z.radius, z.center.x + z.radius),
		rng.randi_range(z.center.y - z.radius, z.center.y + z.radius))


## Whether a creature may be put down at `feet` now (the live world): the rows of Config "M11a". M11b: `in_zone` (a rare kind) also
## inside the rare zone, Config.RARE_SPAWN_INSET_PX from its rim.
func spawn_ok(feet: Vector2, players: Array[Player], in_zone: bool = false) -> bool:
	if data.map_id != Config.MAP_SURFACE:
		return false
	if in_zone and (data.rare_zone == null or not data.rare_zone.holds(feet, Config.RARE_SPAWN_INSET_PX)):
		return false
	var cell: Vector2i = Aim.feet_cell(feet)
	var edge: int = Config.CREATURE_SPAWN_EDGE_TILES
	if cell.x < edge or cell.y < edge or cell.x >= data.size.x - edge or cell.y >= data.size.y - edge:
		return false
	if data.terrain_at(cell) != Terrain.GRASS or not Movement.can_stand(data, feet) or Arena.in_doorway(data, feet):
		return false
	if data.get_value(WorldData.Layer.PLACEABLE, cell) != WorldData.PLACEABLE_NONE:
		return false  # M11 review: a fixture that blocks nothing either (a torch, a death bag)
	if not can_walk(feet) or near_corruption(cell):
		return false
	if data.altar_rect.has_area():
		var clear: float = Config.safe_radius_px() + Config.CREATURE_SPAWN_LIGHT_CLEARANCE_TILES * Config.TILE
		if feet.distance_to(data.altar_center_px()) < clear:
			return false
	for p: Player in players:
		if p.sim_position.distance_to(feet) < Config.CREATURE_SPAWN_MIN_PLAYER_PX:
			return false
	return true


## A corrupted tile lies within Config.CREATURE_SPAWN_ASH_CLEARANCE_TILES (Chebyshev) of tile `cell`.
func near_corruption(cell: Vector2i) -> bool:
	var r: int = Config.CREATURE_SPAWN_ASH_CLEARANCE_TILES
	for y: int in range(cell.y - r, cell.y + r + 1):
		for x: int in range(cell.x - r, cell.x + r + 1):
			if data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
				return true
	return false


## M11a, test flags: where a creature goes around feet `from` in direction `angle`: Config.CREATURE_TEST_RING_PX away, else the first spot
## farther out or nearer in (a tile at a time) where it may stand and walk, or null.
func spot_near(from: Vector2, angle: float) -> Variant:
	var dir: Vector2 = Vector2.from_angle(angle)
	var t: float = float(Config.TILE)
	for k: int in 10:
		for sign_of: int in [1, -1]:
			var feet: Vector2 = (from + dir * (Config.CREATURE_TEST_RING_PX + sign_of * k * t)).round()
			if Movement.can_stand(data, feet) and can_walk(feet):
				return feet
	return null


## The next id no creature here has: an id on the wire is a u16 from 1 (M11c), so they wrap, and a batch naming one twice would be refused whole
## (M11 review: past a creature that outlived a whole round of ids).
func _take_id() -> int:
	while by_id(next_id) != null:
		next_id = next_id % NetProtocol.CREATURE_ID_MAX + 1
	var id: int = next_id
	next_id = next_id % NetProtocol.CREATURE_ID_MAX + 1
	return id


## Puts a creature of `kind` at feet `feet` (its home), past the rules (try_spawn's end, the test flags). Returns it.
func spawn(kind: StringName, feet: Vector2) -> CreatureSim:
	var c: CreatureSim = CreatureSim.new()
	c.id = _take_id()
	c.kind = kind
	c.pos = feet
	c.home = feet
	c.hp = c.hp_max()
	list.append(c)
	_begin_idle(c)
	count("spawned")
	return c


# --- what happens to it ----------------------------------------------------------------------------

## M11b, ● game-concept §4 "희귀 생물 포획·사냥은 아처만": `c` is rare and the player with node instance id `by` is no archer (or nobody): a blow of
## theirs does nothing to it.
static func shut_out(c: CreatureSim, by: int) -> bool:
	return c.rare() and class_of(by) != Config.HUNTER_CLASS


## M11b: a blow by the player with node instance id `by` did nothing to `c`: its refused mark shows (no flash, no bolt), the log hears.
func refuse(c: CreatureSim, by: int) -> void:
	c.refused_ticks = Config.CREATURE_REFUSED_SHOW_TICKS
	count("refused")
	var k: Kill = Kill.new()
	k.kind = c.kind
	k.who = class_of(by)
	k.by = by
	k.at = Aim.feet_cell(c.pos)
	refusals.append(k)


## M11b: the creature with id `id` here, or null.
func by_id(id: int) -> CreatureSim:
	for c: CreatureSim in list:
		if c.id == id:
			return c
	return null


## M11b: a snare holds `c` for `ticks`, thrown from point `from` (Capture.begin). M11c: by the player with node instance id `by`.
func hold(c: CreatureSim, ticks: int, from: Vector2, by: int = 0) -> void:
	if c.alive() and ticks > 0:
		c.hold_ticks = ticks
		c.held_from = from
		c.held_by = by
		c.walking = false
		count("held")


## M11b: a snare takes `c` (Capture.land checked it): it is gone at once with no corpse and no drops, its place waits for its
## `respawn_ticks`, and the world's collection hears.
func capture(c: CreatureSim) -> void:
	_set_state(c, CreatureSim.State.DEAD)
	c.walking = false
	c.hold_ticks = 0
	list.erase(c)
	count("captured")
	_wait(c.kind, c.num_i("respawn_ticks"))
	var col: Collection = Collection.of(data)
	if col != null:
		col.note_capture(c.kind)


## M11c: the feet of the live creatures (bodies a blocking piece may not cover, M11a's rule: the host's and a client's mirror's).
func feet() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c: CreatureSim in list:
		if c.alive():
			out.append(c.pos)
	return out


## M11a: --test-creature: [kind, n] `entries` on a ring of Config.CREATURE_TEST_RING_PX from feet `from` (a turn divided among them, the
## nearest spot on each line that can_walk and Movement allow; none: left out). M11c: offline Main's and a session host's.
func put_ring(entries: Array[Array], from: Vector2) -> void:
	var total: int = 0
	for e: Array in entries:
		var n: int = e[1]
		total += n
	var i: int = 0
	for e: Array in entries:
		var kind: StringName = e[0]
		var n: int = e[1]
		for k: int in n:
			var at: Variant = spot_near(from, TAU * i / total)
			i += 1
			if at != null:
				var spot: Vector2 = at
				spawn(kind, spot)


## M11b: --test-near-creature: a creature of `kind` out of breath at `spot`, at `pct` percent HP. M11c: offline Main's and a session
## host's (the bot's `creature` with a percent too).
func put_resting(kind: StringName, spot: Vector2, pct: int) -> CreatureSim:
	var c: CreatureSim = spawn(kind, spot)
	c.hp = maxi(c.hp_max() * pct / 100, 1)
	rest(c)
	return c


## M11b, test flag: `c` stands out of breath (CreatureSim.State.REST), as after a burst.
func rest(c: CreatureSim) -> void:
	if c.alive():
		_set_state(c, CreatureSim.State.REST)


## M11b: `how_many` of `item` lie down as an ordinary drop where feet `feet` stand (drop_cell, like a kill's).
func lay_down(feet: Vector2, item: StringName, how_many: int) -> void:
	var k: Kill = Kill.new()
	k.at = drop_cell(feet)
	k.drops = [[item, how_many]]
	_put_drops(k)

## A shot whose ground point is `ground` hits `c`: the drawn shot inside its drawn box (Combat.shot_hits_box at its kind's size).
static func shot_hits(ground: Vector2, c: CreatureSim) -> bool:
	return Combat.shot_hits_box(ground, c.pos, c.num_f("hit_radius_px"), c.num_f("hit_height_px"))


## The middle of `c`'s figure: where to put the mouse to aim at it (bots, tests).
static func aim_point(c: CreatureSim) -> Vector2:
	return c.pos - Vector2(0.0, c.num_f("hit_height_px") / 2.0)


## The class of the player with node instance id `by`, "" when there is none (gone, or no player).
static func class_of(by: int) -> String:
	var p: Player = _player_of(by)
	return p.class_id() if p != null else ""


static func _player_of(by: int) -> Player:
	if by == 0 or not is_instance_id_valid(by):
		return null
	return instance_from_id(by) as Player


## `amount` of damage on live creature `c` by the player with node instance id `by` (Arena's every attack path). It flashes, and
## bolts from its attacker, or dies. A stun holds it (the bolt waits for the stun to end). Returns whether it died.
func hit(c: CreatureSim, amount: int, by: int) -> bool:
	if not c.alive():
		return false
	c.hp = maxi(c.hp - amount, 0)
	c.flash_ticks = Config.HIT_FLASH_TICKS
	count("hits")
	if c.hp == 0:
		_die(c, by)
		return true
	var p: Player = _player_of(by)
	bolt(c, p.sim_position if p != null else c.pos)
	return false


## A hit's stun (Arena's crushing blow, rockfall): the longer of two.
func stun(c: CreatureSim, ticks: int) -> void:
	if c.alive() and ticks > 0:
		c.stun_ticks = maxi(c.stun_ticks, ticks)
		c.walking = false
		count("stunned")


## A hit's slow (the sweep; Config.EFFECT_REFRESH_KEEPS_STRONGER like a heretic's).
func slow(c: CreatureSim, pct: int, ticks: int) -> void:
	if not c.alive() or pct <= 0 or ticks <= 0:
		return
	if c.slow_ticks > 0 and Config.EFFECT_REFRESH_KEEPS_STRONGER:
		c.slow_pct = maxi(c.slow_pct, pct)
		c.slow_ticks = maxi(c.slow_ticks, ticks)
	else:
		c.slow_pct = clampi(pct, 0, 100)
		c.slow_ticks = ticks
	count("slowed")


## The ground slam's push: `dist` px along unit vector `dir`, a px at a time, stopping where it could not stand or walk (M11b: out of
## its zone either).
func push(c: CreatureSim, dir: Vector2, dist: float) -> void:
	var gone: float = 0.0
	while c.alive() and gone < dist:
		var step: float = minf(1.0, dist - gone)
		var next: Vector2 = c.pos + dir * step
		if not Movement.can_stand(data, next) or not can_walk(next, c):
			break
		c.pos = next
		gone += step


## A splash of poison on `c` (Arena._splash, Config.POISON_*: M6's rule on a heretic): `damage` every Config.POISON_INTERVAL_TICKS for
## `ticks`, one already poisoned keeps the longer and the larger. It bolts from the splash's thrower. `by`: the thrower's node instance
## id, whose class a death by poison counts as.
func poison(c: CreatureSim, damage: int, ticks: int, by: int) -> bool:
	if not c.alive() or damage <= 0 or ticks <= 0:
		return false
	if c.poison_ticks > 0 and Config.EFFECT_REFRESH_KEEPS_STRONGER:
		c.poison_damage = maxi(c.poison_damage, damage)
		c.poison_ticks = maxi(c.poison_ticks, ticks)
	else:
		c.poison_damage = damage
		c.poison_ticks = ticks
		c.poison_timer = Config.POISON_INTERVAL_TICKS
	c.poison_by = by
	var p: Player = _player_of(by)
	if p != null:
		bolt(c, p.sim_position)
	count("poisoned")
	return true


func _tick_poison(c: CreatureSim) -> void:
	c.poison_ticks -= 1
	c.poison_timer -= 1
	if c.poison_timer <= 0:
		c.poison_timer = Config.POISON_INTERVAL_TICKS
		c.hp = maxi(c.hp - c.poison_damage, 0)
		c.flash_ticks = Config.HIT_FLASH_TICKS
		count("poison_hits")
		if c.hp == 0:
			_die(c, c.poison_by)
			return
	if c.poison_ticks <= 0:
		c.poison_ticks = 0
		c.poison_damage = 0
		c.poison_timer = 0


## `c` dies by a blow of the player with node instance id `by`: its drops by that player's class (● §3.4) lie on its tile, its place
## waits for `respawn_ticks`. M11b: the world's collection counts the kill (a rare kind's entry takes a capture: a kill gives it none).
func _die(c: CreatureSim, by: int) -> void:
	_set_state(c, CreatureSim.State.DEAD)
	c.walking = false
	c.stun_ticks = 0
	c.slow_pct = 0
	c.slow_ticks = 0
	c.poison_ticks = 0
	c.poison_damage = 0
	c.poison_timer = 0
	c.hold_ticks = 0
	var k: Kill = Kill.new()
	k.kind = c.kind
	k.who = class_of(by)
	k.by = by
	k.at = drop_cell(c.pos)
	k.drops = drops_for(c.kind, k.who)
	_put_drops(k)
	kills.append(k)
	count("killed")
	_wait(c.kind, c.num_i("respawn_ticks"))
	var col: Collection = Collection.of(data)
	if col != null:
		col.note_kill(c.kind)


## The [item, count] rows a kill of `kind` by class `class_id` gives (● §3.0 R11, §3.4).
static func drops_for(kind: StringName, class_id: String) -> Array:
	var rows: Array = Config.CREATURES[kind]["drops_hunter" if class_id == Config.HUNTER_CLASS else "drops_other"]
	return rows


## The tile a kill at feet `feet` drops on: the feet tile, or the nearest free one, by the death bag's rule (WorldItems.bag_cell: never a
## doorway, where F would work the door and no drop could be picked up, nor a tile with a gatherable or another drop); with none
## near, the feet tile.
func drop_cell(feet: Vector2) -> Vector2i:
	var c: Vector2i = WorldItems.bag_cell(data, feet)
	return c if c != Walls.NO_CELL else Aim.feet_cell(feet)


## [item, count] rows as one word for the log ("hide_fine:2+meat:2", "none").
static func describe_drops(rows: Array) -> String:
	var parts: PackedStringArray = []
	for row: Array in rows:
		parts.append("%s:%d" % [row[0], row[1]])
	return "+".join(parts) if not parts.is_empty() else "none"


## Kill `k`'s rows as ordinary drops on its tile, Config.CREATURE_DROP_SPREAD_PX apart; at Config.MAX_DROPS on the map the rest is lost
## (logged by count, like a debug drop refused).
func _put_drops(k: Kill) -> void:
	var centre: Vector2i = k.at * Config.TILE + Vector2i(Config.TILE / 2, Config.TILE / 2)
	var n: int = k.drops.size()
	for i: int in n:
		if data.drops.size() + edits.size() >= Config.MAX_DROPS:
			count("drops_lost")
			continue
		var row: Array = k.drops[i]
		var item: StringName = row[0]
		var how_many: int = row[1]
		var at: Vector2i = centre + Vector2i((2 * i - (n - 1)) * Config.CREATURE_DROP_SPREAD_PX / 2, 0)
		edits.append(EditLog.WorldEdit.drop_put(WorldData.Drop.new(data.new_drop_id(), item, how_many, ItemDB.normalize_grade(item), at)))
