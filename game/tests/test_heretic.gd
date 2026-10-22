extends "res://tests/base_test.gd"
## M4a, the heretic (one melee enemy, 03-pixel heretic_v02): its picture (sheet rows south / east / north,
## west = east mirrored, the feet origin of 32 and 64 cells, the HP bar once hurt), the attack (the
## telegraph with the knife raised, the hit on the hit column in every direction, a dash dodges it),
## its behaviour (chase the nearest player in sight, not through walls, the leash, the altar light: it
## never steps in, never hurts anyone inside, waits at the edge then walks home), the spawner (never in
## the light over many seeds and a long run, the first try after one interval, the cap, the distance from
## players, the dungeon's spawn tiles away from the arrival room, only maps with a player), the shrine
## (hit points, broken by combat, broken stops the dungeon spawns, still blocks, fire off) and main.tscn
## (maps tick only with the player on them, the miner's pickaxe: a wall or a heretic, not both).

const TICK: float = 1.0 / 60.0
const C := preload("res://tests/test_combat.gd")

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_view()
	_check_attack_timing()
	_check_dodge()
	_check_chase_and_sight()
	_check_leash()
	_check_light_edge()
	_check_light_long_run()
	_check_spawn_never_in_light()
	_check_spawner()
	_check_shrine()
	_check_emptied()
	await _check_main()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


static func stand(p: Player) -> void:
	p.begin_tick()
	p.step_frame(NetProtocol.InputFrame.new(), TICK)


static func stat(a: Arena, key: String) -> int:
	var v: int = a.stats.get(key, 0)
	return v


func _arena(d: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	return a


# --- the picture -------------------------------------------------------------------------------------

func _check_view() -> void:
	var h: HereticSim = HereticSim.new()
	h.pos = Vector2(100.4, 200.6)
	var view: Heretic = Heretic.new()
	_nodes.append(view)
	var rows: Dictionary[int, int] = {RigData.Dir.SOUTH: 0, RigData.Dir.EAST: 1, RigData.Dir.NORTH: 2, RigData.Dir.WEST: 1}
	for dir: int in rows:
		h.facing = dir
		for st: Array in [[HereticSim.State.IDLE, false, HereticSim.Anim.IDLE], [HereticSim.State.CHASE, true, HereticSim.Anim.WALK],
				[HereticSim.State.ATTACK, false, HereticSim.Anim.ATTACK], [HereticSim.State.HURT, false, HereticSim.Anim.HURT],
				[HereticSim.State.DEAD, false, HereticSim.Anim.DEATH]]:
			h.state = st[0]
			h.walking = st[1]
			h.state_ticks = 0
			view.show_sim(h)
			var a: int = st[2]
			var c: int = HereticSim.CELLS[a]
			check_eq(view.anim, a, "%s %s anim" % [RigData.DIR_NAMES[dir], HereticSim.STATE_NAMES[st[0]]])
			check(view.body.texture == Heretic.SHEETS[a], "%s sheet" % HereticSim.ANIM_NAMES[a])
			check_eq(view.body.region_rect, Rect2((HereticSim.FIRST_COLUMN[a] + view.frame) * c, rows[dir] * c, c, c),
				"%s %s: row %d (west = east)" % [RigData.DIR_NAMES[dir], HereticSim.ANIM_NAMES[a], rows[dir]])
			check_eq(view.rig.scale.x, -1.0 if dir == RigData.Dir.WEST else 1.0, "%s mirrored only facing west" % RigData.DIR_NAMES[dir])
			var feet_in_cell: Vector2i = Vector2i(16, 32) if c == 32 else Vector2i(32, 48)
			check_eq(view.body.position, -Vector2(feet_in_cell), "%s feet origin (the cell's (%d, %d) on the node)" % [
				HereticSim.ANIM_NAMES[a], feet_in_cell.x, feet_in_cell.y])
	check_eq(view.position, Vector2(100, 201), "the node on the rounded feet")
	h.state = HereticSim.State.IDLE
	h.hp = Config.HERETIC_HP
	view.show_sim(h)
	check(not view.bar.visible, "no HP bar at full HP")
	h.hp = Config.HERETIC_HP / 2
	view.show_sim(h)
	check(view.bar.visible and is_equal_approx(view.hp_ratio, 0.5), "the HP bar once hurt")
	check_eq(Heretic.bar_fill(0.5), Heretic.BAR_SIZE.x / 2, "half filled")
	check_eq(Heretic.bar_fill(0.01), 1, "a sliver stays visible while alive")
	h.state = HereticSim.State.DEAD
	view.show_sim(h)
	check(not view.bar.visible, "no bar on the dead")
	# The sheets: rows x frames as the 13차 hand-off says.
	for a: int in HereticSim.ANIM_NAMES.size():
		var tex: Texture2D = Heretic.SHEETS[a]
		var c2: int = HereticSim.CELLS[a]
		check_eq(Vector2i(tex.get_size()), Vector2i(c2 * (HereticSim.FIRST_COLUMN[a] + HereticSim.FRAME_COUNTS[a]), 3 * c2),
			"heretic %s sheet size" % HereticSim.ANIM_NAMES[a])
	check_eq(Array(HereticSim.FRAME_COUNTS), [6, 4, 8, 6, 7], "frames walk, idle, attack, hurt, death (13차)")
	check_eq(Array(HereticSim.CELLS), [32, 32, 64, 32, 32], "cells")
	check_eq(Array(HereticSim.FIRST_COLUMN), [0, 0, 1, 0, 0], "first columns")


# --- the attack ----------------------------------------------------------------------------------------

## For each direction: the attack starts when the player is in range; during the telegraph the frames
## stay before the hit column with the knife out (the last one held); the knife lands on the hit
## column exactly Config.HERETIC_TELEGRAPH_TICKS after the start; the rest of the swing plays; the next
## attack waits the cooldown.
func _check_attack_timing() -> void:
	var offsets: Dictionary[int, Vector2] = {RigData.Dir.SOUTH: Vector2(0, 14), RigData.Dir.EAST: Vector2(14, 0),
		RigData.Dir.NORTH: Vector2(0, -14), RigData.Dir.WEST: Vector2(-14, 0)}
	for dir: int in offsets:
		var d: WorldData = C.open_world()
		var a: Arena = _arena(d)
		var h: HereticSim = a.spawn_heretic(C.feet(Vector2i(10, 10)))
		var p: Player = player(d, "archer", h.pos + offsets[dir])
		var players: Array[Player] = [p]
		var row: int = RigData.sheet_row(dir)
		var hit_tick: int = -1
		var started: int = -1
		var frames: Array[int] = []
		var view: Heretic = Heretic.new()
		_nodes.append(view)
		var hit_region_x: float = -1.0
		var second: int = -1
		for t: int in 200:
			stand(p)
			var hp_before: int = p.vitals.hp
			a.step(players)
			if started < 0 and h.state == HereticSim.State.ATTACK:
				started = t
			elif started >= 0 and second < 0 and t > started + HereticSim.attack_ticks(row) and h.state == HereticSim.State.ATTACK:
				second = t
			if h.state == HereticSim.State.ATTACK and started >= 0 and second < 0:
				frames.append(h.frame())
				view.show_sim(h)
				check(h.knife_out(), "%s: the knife is out through the attack" % RigData.DIR_NAMES[dir])
			if p.vitals.hp < hp_before and hit_tick < 0:
				hit_tick = t
				hit_region_x = view.body.region_rect.position.x
			p.vitals.invuln_ticks = 0
			p.vitals.hurt_ticks = 0
		check_eq(started, 0, "%s: the attack starts at once in range" % RigData.DIR_NAMES[dir])
		check_eq(h.facing, dir, "%s: it faces the player" % RigData.DIR_NAMES[dir])
		check_eq(hit_tick - started, Config.HERETIC_TELEGRAPH_TICKS, "%s: the knife lands after the telegraph" % RigData.DIR_NAMES[dir])
		var hit_frame: int = Config.HERETIC_HIT_COLUMN[row] - 1
		check_eq(HereticSim.hit_frame(row), hit_frame, "%s: hit frame = hit column - 1" % RigData.DIR_NAMES[dir])
		check_eq(hit_region_x, float(Config.HERETIC_HIT_COLUMN[row] * 64), "%s: the hit shows sheet column %d" % [
			RigData.DIR_NAMES[dir], Config.HERETIC_HIT_COLUMN[row]])
		var telegraph: Array = frames.slice(0, Config.HERETIC_TELEGRAPH_TICKS)
		var hi: int = telegraph.max()
		var lo: int = telegraph.min()
		check(hi == hit_frame - 1 and lo == 0, "%s: the telegraph frames run up to the column before the hit %s" % [
			RigData.DIR_NAMES[dir], str(telegraph)])
		check_eq(frames.size(), HereticSim.attack_ticks(row), "%s: the attack lasts attack_ticks" % RigData.DIR_NAMES[dir])
		check_eq(frames[frames.size() - 1], HereticSim.FRAME_COUNTS[HereticSim.Anim.ATTACK] - 1, "%s: to the last frame" % RigData.DIR_NAMES[dir])
		check_eq(second - started, HereticSim.attack_ticks(row) + Config.HERETIC_ATTACK_COOLDOWN_TICKS,
			"%s: the next attack after the cooldown" % RigData.DIR_NAMES[dir])
	check_eq(Array(Config.HERETIC_HIT_COLUMN), [3, 4, 5], "hit columns: the first of each 13차 candidate pair (S 3-4, E 4-5, N 5-6)")


## A dash out of the arc during the telegraph, or through the hit with Config.DASH_INVULNERABLE: no damage.
func _check_dodge() -> void:
	var d: WorldData = C.open_world()
	var a: Arena = _arena(d)
	var h: HereticSim = a.spawn_heretic(C.feet(Vector2i(10, 10)))
	var p: Player = player(d, "paladin", h.pos + Vector2(14, 0))
	var players: Array[Player] = [p]
	for t: int in Config.HERETIC_TELEGRAPH_TICKS + 20:
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i(1, 0) if t >= 20 else Vector2i.ZERO)
		f.dash = t == 20
		p.begin_tick()
		p.step_frame(f, TICK)
		a.step(players)
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "a dash away during the telegraph dodges the knife")
	check_eq(stat(a, "knife_swings"), 1, "the knife swung")


# --- behaviour -----------------------------------------------------------------------------------------

func _check_chase_and_sight() -> void:
	var d: WorldData = C.open_world(Vector2i(40, 20))
	var a: Arena = _arena(d)
	var h: HereticSim = a.spawn_heretic(C.feet(Vector2i(10, 10)))
	var near: Player = player(d, "miner", h.pos + Vector2(80, 0))
	var far: Player = player(d, "cleric", h.pos + Vector2(-100, 0))
	var players: Array[Player] = [far, near]
	for t: int in 60:
		stand(near)
		stand(far)
		a.step(players)
	check_eq(h.target_id, near.get_instance_id(), "it goes after the nearest player")
	check_between(h.pos.x - C.feet(Vector2i(10, 10)).x, Config.HERETIC_SPEED - 1.0, Config.HERETIC_SPEED + 0.1,
		"at HERETIC_SPEED for a second")
	check(h.walking, "walking (the walk frames)")
	# Out of sight range: it stays home.
	var d2: WorldData = C.open_world(Vector2i(40, 20))
	var a2: Arena = _arena(d2)
	var h2: HereticSim = a2.spawn_heretic(C.feet(Vector2i(10, 10)))
	var away: Player = player(d2, "archer", h2.pos + Vector2(Config.HERETIC_SIGHT_PX + 2.0, 0))
	var one: Array[Player] = [away]
	for t: int in 60:
		stand(away)
		a2.step(one)
	check(h2.state == HereticSim.State.IDLE and h2.pos == h2.home, "beyond HERETIC_SIGHT_PX it stays idle")
	# A wall between (in range): no target.
	var d3: WorldData = C.open_world(Vector2i(40, 20))
	for y: int in d3.size.y:
		C.wall(d3, Vector2i(13, y))
	var a3: Arena = _arena(d3)
	var h3: HereticSim = a3.spawn_heretic(C.feet(Vector2i(10, 10)))
	var behind: Player = player(d3, "paladin", C.feet(Vector2i(16, 10)))
	var b: Array[Player] = [behind]
	for t: int in 60:
		stand(behind)
		a3.step(b)
	check(h3.state == HereticSim.State.IDLE and not h3.has_target, "a wall between: unseen")
	# A downed player is no target.
	var d4: WorldData = C.open_world()
	var a4: Arena = _arena(d4)
	var h4: HereticSim = a4.spawn_heretic(C.feet(Vector2i(10, 10)))
	var down: Player = player(d4, "herbalist", h4.pos + Vector2(40, 0))
	down.take_hit(Config.PLAYER_HP_MAX)
	var dl: Array[Player] = [down]
	for t: int in 30:
		stand(down)
		a4.step(dl)
	check(not h4.has_target, "a downed player is no target")


## Kept in sight but pulled away: past HERETIC_LEASH_PX from home it gives up and walks back.
func _check_leash() -> void:
	var d: WorldData = C.open_world(Vector2i(60, 20))
	var a: Arena = _arena(d)
	var home: Vector2 = C.feet(Vector2i(5, 10))
	var h: HereticSim = a.spawn_heretic(home)
	var p: Player = player(d, "archer", home + Vector2(60, 0))
	var players: Array[Player] = [p]
	var gave_up_at: float = -1.0
	var farthest: float = 0.0
	for t: int in 2000:
		if h.state == HereticSim.State.CHASE:
			p.teleport(h.pos + Vector2(60, 0))
		stand(p)
		a.step(players)
		farthest = maxf(farthest, h.pos.distance_to(home))
		if gave_up_at < 0.0 and h.state == HereticSim.State.RETURN:
			gave_up_at = farthest
		if gave_up_at >= 0.0 and h.state == HereticSim.State.IDLE:
			break
	check_between(gave_up_at, Config.HERETIC_LEASH_PX, Config.HERETIC_LEASH_PX + 1.0, "it gives up just past the leash (%.1f px)" % gave_up_at)
	check(h.state == HereticSim.State.IDLE and h.pos.distance_to(home) <= 1.5, "and walks home (%.1f px off)" % h.pos.distance_to(home))


## The altar light (Config.HERETIC_ENTERS_LIGHT false): chasing a player into the light it stops at the
## edge (never a foot in), waits facing the player (Config.HERETIC_LIGHT_EDGE_WAIT_SEC), never hurts it,
## then walks home; out of the light the player is fair game again.
func _check_light_edge() -> void:
	check(not Config.HERETIC_ENTERS_LIGHT, "heretics keep out of the altar light (PROVISIONAL default)")
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var a: Arena = _arena(data)
	var center: Vector2 = data.altar_center_px()
	var r: float = Config.safe_radius_px()
	var inside: Vector2 = center + Vector2(0, r - 6.0)
	var h: HereticSim = a.spawn_heretic(center + Vector2(0, r + 50.0))
	var p: Player = player(data, "paladin", center + Vector2(0, r + 20.0))
	var players: Array[Player] = [p]
	var entered: int = 0
	var states: Dictionary[String, int] = {}
	for t: int in 40:
		stand(p)
		a.step(players)
	p.teleport(inside)
	for t: int in Arena.edge_wait_ticks() + 300:
		stand(p)
		a.step(players)
		if not Combat.box_outside_light(data, a.safe, h.pos):
			entered += 1
		states[HereticSim.STATE_NAMES[h.state]] = states.get(HereticSim.STATE_NAMES[h.state], 0) + 1
	check_eq(entered, 0, "never a foot in the light")
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "never hurts the player inside")
	var edge_ticks: int = states.get("edge", 0)
	check_between(edge_ticks, Arena.edge_wait_ticks() - 1, Arena.edge_wait_ticks() + 1, "waits at the edge %s" % [states])
	check(states.has("return") or h.state == HereticSim.State.IDLE, "then walks home %s" % [states])
	check(stat(a, "edge_waits") >= 1, "counted an edge wait")
	# Out of the light again (just south of it, away from the altar): chased and hit.
	p.teleport(h.pos + Vector2(0, 14))
	check(not a.in_light(p.sim_position), "the player stepped out")
	for t: int in 300:
		stand(p)
		a.step(players)
		p.vitals.invuln_ticks = 0
	check(p.vitals.hp < Config.PLAYER_HP_MAX, "outside the light it attacks again")
	# An attack started outside: the player steps into the light (still in reach) before the knife lands:
	# no hit.
	var a2: Arena = _arena(data)
	var victim: Player = player(data, "cleric", center + Vector2(0, r + 0.5))
	var h2: HereticSim = a2.spawn_heretic(center + Vector2(0, r + 18.0))
	var vs: Array[Player] = [victim]
	for t: int in Config.HERETIC_TELEGRAPH_TICKS + 5:
		if t == 10:
			victim.teleport(center + Vector2(0, r - 4.0))
		stand(victim)
		a2.step(vs)
		if t == 0:
			check_eq(h2.state, HereticSim.State.ATTACK, "the attack starts while the player is outside")
	check(h2.pos.distance_to(victim.sim_position) < Config.HERETIC_HIT_REACH_PX, "the player stayed in reach")
	check_eq(stat(a2, "knife_swings"), 1, "the knife swung")
	check_eq(victim.vitals.hp, Config.PLAYER_HP_MAX, "but it lands on nobody inside the light")
	# A chase whose path cuts through the light (both outside, the light's rim between them): the heretic
	# never sets a foot in; with no path finding (PROVISIONAL) it stops at the rim.
	var a3: Arena = _arena(data)
	var runner: Player = player(data, "archer", center + Vector2(50.0, 108.0))
	var h3: HereticSim = a3.spawn_heretic(center + Vector2(-50.0, 108.0))
	check(Combat.box_outside_light(data, a3.safe, h3.pos) and not a3.in_light(runner.sim_position), "both start outside")
	check(a3.in_light(h3.pos.lerp(runner.sim_position, 0.5)), "the straight line between them crosses the light")
	var rs: Array[Player] = [runner]
	var crossed: int = 0
	for t: int in 300:
		stand(runner)
		a3.step(rs)
		runner.vitals.invuln_ticks = 0
		if not Combat.box_outside_light(data, a3.safe, h3.pos):
			crossed += 1
	check_eq(crossed, 0, "chasing across the light's rim, never a foot in")
	check(h3.pos.x > center.x - 50.0, "it did move toward the player (to %.1f, %.1f)" % [h3.pos.x - center.x, h3.pos.y - center.y])
	_check_edge_sniping(data)


## M4-fix: a player inside the light shooting the heretic that waits at the edge (a hit every 1 or 2 s)
## cannot keep it there: the wait counts from when it started watching, the hits' staggers included, so it
## walks home about Config.HERETIC_LIGHT_EDGE_WAIT_SEC after it stopped at the edge (before, every hit
## started the wait over and it stood at the edge until it died; review probe: 61 hits, still at the edge).
func _check_edge_sniping(data: WorldData) -> void:
	var center: Vector2 = data.altar_center_px()
	var r: float = Config.safe_radius_px()
	for every: int in [60, 120]:
		var a: Arena = _arena(data)
		var h: HereticSim = a.spawn_heretic(center + Vector2(0, r + 50.0))
		h.hp = 1000  # alive for the whole run
		var p: Player = player(data, "archer", center + Vector2(0, r + 20.0))
		var players: Array[Player] = [p]
		for t: int in 40:
			stand(p)
			a.step(players)
		p.teleport(center + Vector2(0, r - 6.0))
		var watch_start: int = -1
		var left_at: int = -1
		var hits: int = 0
		for t: int in Arena.edge_wait_ticks() + 400:
			stand(p)
			a.step(players)
			if watch_start < 0 and h.state == HereticSim.State.EDGE:
				watch_start = t
			if watch_start >= 0 and left_at < 0 and h.state == HereticSim.State.RETURN:
				left_at = t
			if watch_start >= 0 and left_at < 0 and (t - watch_start) % every == every / 2:
				a.hit_heretic(h, 1, p.get_instance_id())
				hits += 1
		check(left_at >= 0 and left_at - watch_start <= Arena.edge_wait_ticks() + 1,
			"hit every %d ticks from inside the light while it waits (%d hits): it still walks home %d ticks after it began watching (wait %d)" % [
			every, hits, left_at - watch_start, Arena.edge_wait_ticks()])
		check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "the player inside was never hurt")


## M4-fix (README "M4-fix 빈 지도"): an arena its last player left (idle_tick after a step) empties once: an
## attack under way stops without its knife and the attack cooldown follows, a stagger ends, targets and
## the edge watch are forgotten, the shots in the air are gone, the spawn timer starts over, nothing counts
## as a fresh attack; a second idle tick changes nothing. Then a returning player at the heretic's side is
## not hit before a whole new telegraph.
func _check_emptied() -> void:
	var d: WorldData = C.open_world(Vector2i(30, 20))
	var a: Arena = _arena(d)
	a.spawning = true
	var p: Player = player(d, "paladin", C.feet(Vector2i(10, 10)))
	var h: HereticSim = a.spawn_heretic(p.sim_position + Vector2(14, 0))
	var hurt: HereticSim = a.spawn_heretic(C.feet(Vector2i(20, 15)))
	var players: Array[Player] = [p]
	for t: int in 12:
		stand(p)
		a.step(players)
	check(h.state == HereticSim.State.ATTACK and h.state_ticks > 0 and h.state_ticks < Config.HERETIC_TELEGRAPH_TICKS,
		"mid wind-up (%s, %d ticks)" % [HereticSim.STATE_NAMES[h.state], h.state_ticks])
	a.hit_heretic(hurt, 1)
	a.player_attack(p, &"bow", Combat.aim_code(Vector2.LEFT))
	check(not a.shots.is_empty() and a.spawn_timer > 0 and a.occupied, "a shot in the air, the spawn timer running")
	a.idle_tick()
	check(h.state == HereticSim.State.IDLE and not h.has_target and h.cooldown == Config.HERETIC_ATTACK_COOLDOWN_TICKS,
		"emptied: the attack stopped without its knife (%s, cooldown %d)" % [HereticSim.STATE_NAMES[h.state], h.cooldown])
	check(hurt.state == HereticSim.State.IDLE and hurt.flash_ticks == 0, "the stagger ended")
	check(a.shots.is_empty() and a.spawn_timer == 0 and a.attacks_started == 0 and not a.occupied,
		"the shot is gone, the spawn timer starts over, no fresh attack")
	check_eq(stat(a, "knife_swings"), 0, "no knife swung")
	check_eq(stat(a, "attacks_cancelled"), 1, "one attack cancelled")
	a.idle_tick()
	check_eq(stat(a, "emptied"), 1, "a second idle tick changes nothing")
	# Back: the player at its side is not hit before a whole telegraph (and the cooldown) has passed.
	var hp: int = p.vitals.hp
	var first_hit: int = -1
	for t: int in Config.HERETIC_ATTACK_COOLDOWN_TICKS + Config.HERETIC_TELEGRAPH_TICKS + 30:
		stand(p)
		a.step(players)
		p.vitals.invuln_ticks = 0
		if first_hit < 0 and p.vitals.hp < hp:
			first_hit = t
	check(first_hit >= Config.HERETIC_TELEGRAPH_TICKS, "back at its side: the first hit only after a whole new telegraph (tick %d)" % first_hit)
	# The first spawn try comes one interval after the return, not at once.
	var spawn_a: Arena = Arena.new()
	spawn_a.setup(SurfaceGen.generate(Config.DEFAULT_SEED), 1)
	var sp: Player = player(spawn_a.data, "miner", spawn_a.data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]))
	var sps: Array[Player] = [sp]
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS - 1:
		spawn_a.step(sps)
	spawn_a.idle_tick()
	spawn_a.step(sps)
	check_eq(stat(spawn_a, "spawned"), 0, "a tick after coming back: no spawn yet (the timer started over)")
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS - 1:
		spawn_a.step(sps)
	check_eq(stat(spawn_a, "spawned"), 1, "one interval after coming back: the first spawn")


## A long run around the altar with the spawner on: a player goes out to a heretic (to lure it) and back
## into the light, over and over; every tick every heretic stays wholly outside the light, and no hit
## lands while the player stands inside.
func _check_light_long_run() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var a: Arena = Arena.new()
	a.setup(data, 3)
	var p: Player = player(data, "miner", data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]))
	var players: Array[Player] = [p]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var dir: Vector2i = Vector2i.ZERO
	var inside_hits: int = 0
	var outside: int = 0
	var bad: int = 0
	var center: Vector2 = data.altar_center_px()
	for t: int in 20000:
		var goal: Vector2 = center + (p.sim_position - center).normalized() * (Config.safe_radius_px() - 12.0)
		if (t / 400) % 2 == 1 and not a.heretics.is_empty():
			goal = a.heretics[(t / 800) % a.heretics.size()].pos
		var to_goal: Vector2 = goal - p.sim_position
		dir = Vector2i(0 if absf(to_goal.x) < 2.0 else (1 if to_goal.x > 0.0 else -1),
			0 if absf(to_goal.y) < 2.0 else (1 if to_goal.y > 0.0 else -1))
		if t % 37 == 0 and rng.randf() < 0.3:
			dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var hp: int = p.vitals.hp
		var was_inside: bool = a.in_light(p.sim_position)
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(0, dir), TICK)
		a.step(players)
		if p.vitals.hp < hp and was_inside:
			inside_hits += 1
		if not was_inside:
			outside += 1
		for h: HereticSim in a.heretics:
			if not Combat.box_outside_light(data, a.safe, h.pos):
				bad += 1
		if p.vitals.life != Vitals.Life.ALIVE:
			p.respawn_vitals()
		p.vitals.hp = Config.PLAYER_HP_MAX
	check_eq(bad, 0, "20,000 ticks: no heretic ever in the light")
	check_eq(inside_hits, 0, "no hit on the player while inside")
	check(stat(a, "spawned") >= 4 and outside > 2000 and stat(a, "edge_waits") > 3 and stat(a, "knife_swings") > 3,
		"the run had heretics, chases to the edge, attacks and time outside (%s, %d ticks outside)" % [a.stats, outside])
	note("light long run: %s" % a.stats)


func _check_spawn_never_in_light() -> void:
	var bad: int = 0
	var spawned: int = 0
	var near: int = 0
	for seed_value: int in range(1, 31):
		var data: WorldData = SurfaceGen.generate(seed_value)
		var zone: SafeZone = SafeZone.for_world(data)
		var cells: Array[Vector2i] = Arena.surface_spawn_cells(data, zone)
		for c: Vector2i in cells:
			if not Combat.box_outside_light(data, zone, Arena.spawn_feet(c)):
				bad += 1
			var ash_near: bool = false
			for y: int in range(c.y - Config.HERETIC_SPAWN_ASH_REACH_TILES, c.y + Config.HERETIC_SPAWN_ASH_REACH_TILES + 1):
				for x: int in range(c.x - Config.HERETIC_SPAWN_ASH_REACH_TILES, c.x + Config.HERETIC_SPAWN_ASH_REACH_TILES + 1):
					if data.get_value(WorldData.Layer.CORRUPTION, Vector2i(x, y)) != 0:
						ash_near = true
			if not ash_near:
				near += 1
		var a: Arena = Arena.new()
		a.setup(data, seed_value)
		var p: Player = player(data, "archer", data.altar_center_px() + Vector2(0, Config.safe_radius_px() + 4.0))
		var players: Array[Player] = [p]
		for i: int in 20:
			var h: HereticSim = a.try_spawn(players)
			if h != null:
				spawned += 1
				if not Combat.box_outside_light(data, zone, h.pos) or h.pos.distance_to(p.sim_position) < Config.HERETIC_SPAWN_MIN_PLAYER_PX:
					bad += 1
			a.heretics.clear()
	check_eq(bad, 0, "30 seeds: no spawn tile, no spawn in the light or near a player")
	# The spawn check itself refuses the light (not only the tile list): every standable tile in it.
	var s1: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var a1: Arena = Arena.new()
	a1.setup(s1, 1)
	var refused: int = 0
	var lit: int = 0
	var nobody: Array[Player] = []
	var c0: Vector2i = Aim.cell_of(s1.altar_center_px())
	for y: int in range(c0.y - Config.SAFE_RADIUS_TILES - 1, c0.y + Config.SAFE_RADIUS_TILES + 2):
		for x: int in range(c0.x - Config.SAFE_RADIUS_TILES - 1, c0.x + Config.SAFE_RADIUS_TILES + 2):
			var f: Vector2 = Arena.spawn_feet(Vector2i(x, y))
			if Movement.can_stand(s1, f) and not Combat.box_outside_light(s1, a1.safe, f):
				lit += 1
				if not a1.spawn_ok(f, nobody):
					refused += 1
	check(lit > 100 and refused == lit, "spawn_ok refuses every standable spot touching the light (%d of %d)" % [refused, lit])
	check_eq(near, 0, "every surface spawn tile is in or around a corruption zone")
	check(spawned > 500, "spawns happened (%d)" % spawned)
	for seed_value: int in range(1, 11):
		var dungeon: WorldData = DungeonGen.generate(seed_value)
		var dist: Dictionary[Vector2i, int] = Arena.arrival_distances(dungeon)
		var close: int = 0
		var cells: Array[Vector2i] = Arena.dungeon_spawn_cells(dungeon)
		for c: Vector2i in cells:
			if dist.get(c, 0) < Config.HERETIC_SPAWN_ARRIVAL_MIN_TILES:
				close += 1
		check(not cells.is_empty() and close == 0, "seed %d dungeon: spawn tiles %d, all away from the arrival room" % [seed_value, cells.size()])


func _check_spawner() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var a: Arena = Arena.new()
	a.setup(data, 1)
	var p: Player = player(data, "paladin", data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]))
	var players: Array[Player] = [p]
	var first: int = -1
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS * 30:
		stand(p)
		a.step(players)
		if first < 0 and not a.heretics.is_empty():
			first = t
		check(a.alive_heretics() <= Config.HERETIC_CAP_SURFACE, "never above the cap")
	check_eq(first, Config.HERETIC_SPAWN_INTERVAL_TICKS - 1, "the first spawn one interval after the map is entered")
	check_eq(a.alive_heretics(), Config.HERETIC_CAP_SURFACE, "filled up to the cap")
	var none: Array[Player] = []
	var timer: int = a.spawn_timer
	var count_before: int = stat(a, "spawned")
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS * 3:
		a.step(none)
	check(a.spawn_timer == timer and stat(a, "spawned") == count_before, "no player on the map: no spawning")
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var b: Arena = Arena.new()
	b.setup(dungeon, 1)
	var q: Player = player(dungeon, "miner", DungeonGen.arrival_point(dungeon))
	var qs: Array[Player] = [q]
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS * 10:
		stand(q)
		b.step(qs)
	check_eq(b.alive_heretics(), Config.HERETIC_CAP_DUNGEON, "the dungeon fills to its cap")
	var dist: Dictionary[Vector2i, int] = Arena.arrival_distances(dungeon)
	for h: HereticSim in b.heretics:
		var steps: int = dist.get(Aim.feet_cell(h.home), 0)
		check(steps >= Config.HERETIC_SPAWN_ARRIVAL_MIN_TILES, "dungeon heretic %d spawned away from the arrival room" % h.id)


func _check_shrine() -> void:
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var a: Arena = Arena.new()
	a.setup(dungeon, 1)
	var rect: Rect2i = a.shrine_rect()
	check(rect.has_area() and a.shrine_hp == Config.SHRINE_HP, "the shrine stands with SHRINE_HP")
	check(a.spawns_now(), "and the dungeon spawns")
	var below: Vector2 = Vector2(FixtureView.foot_of(rect).x, (rect.end.y + 1) * Config.TILE - 4.0)
	check(Movement.can_stand(dungeon, below), "a spot just south of the shrine")
	var p: Player = player(dungeon, "paladin", below)
	var north: int = Combat.aim_code(Vector2.UP)
	var swings: int = 0
	var edits: Array[EditLog.WorldEdit] = []
	while a.shrine_rect().has_area() and swings < 40:
		var hp: int = a.shrine_hp
		edits = a.player_attack(p, &"sword", north)
		swings += 1
		if a.shrine_hp > 0:
			check_eq(a.shrine_hp, hp - Combat.attack_for(&"sword").damage, "a sword hit takes its damage off")
		for e: EditLog.WorldEdit in edits:
			EditLog.apply_to_data(dungeon, e)
	check_eq(swings, ceili(float(Config.SHRINE_HP) / Combat.attack_for(&"sword").damage), "the sword breaks it (● §3.0: by combat)")
	check_eq(edits.size(), rect.size.x * rect.size.y, "its footprint becomes the broken shrine")
	check_eq(dungeon.footprints(WorldData.PLACEABLE_SHRINE_BROKEN), [rect] as Array[Rect2i], "the broken footprint")
	check(not a.spawns_now(), "a broken shrine stops the dungeon spawns (SHRINE_STOPS_SPAWNS)")
	var q: Player = player(dungeon, "miner", DungeonGen.arrival_point(dungeon))
	var qs: Array[Player] = [q]
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS * 5:
		stand(q)
		a.step(qs)
	check_eq(stat(a, "spawned"), 0, "no heretic spawns after it")
	check(Movement.is_blocked(dungeon, rect.position), "the broken shrine still blocks")
	check_eq(a.player_attack(p, &"sword", north).size(), 0, "a broken shrine takes no more hits")
	# A shot breaks a standing one too; the view shows standing, hurt (bar) and broken, never a fire.
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = Config.MAP_DUNGEON
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	var b: Arena = Arena.new()
	b.setup(w.data, 1)
	var view: CombatView = CombatView.new()
	w.add_child(view)
	view.setup(b, w.entities)
	var archer: Player = player(w.data, "archer", Vector2(FixtureView.foot_of(rect).x, (rect.end.y + 2) * Config.TILE - 4.0))
	b.player_attack(archer, &"bow", north)
	var none: Array[Player] = []
	for t: int in 60:
		for e: EditLog.WorldEdit in b.step(none):
			w.apply_edit(e)
	view.sync(none)
	check_eq(b.shrine_hp, Config.SHRINE_HP - Combat.attack_for(&"bow").damage, "an arrow hits the shrine")
	check(view.shrine_bar != null and view.shrine_bar.visible, "the hurt shrine shows its HP bar")
	b.shrine_hp = 1
	b.player_attack(archer, &"holy_light", north)
	for t: int in 60:
		for e: EditLog.WorldEdit in b.step(none):
			w.apply_edit(e)
	view.sync(none)
	check(not b.shrine_rect().has_area() and view.shrine_bar == null, "a bolt breaks it; no bar")
	check(w.fixtures.nodes.has(rect.position) and w.fixtures.nodes[rect.position].name == &"ShrineBroken", "the broken shrine is drawn")
	check_eq(w.fixtures.verify()["mismatches"], 0, "fixtures = data")
	check(not w.fixtures.light_nodes.has(rect.position) and w.fixtures.nodes[rect.position].get_node_or_null(^"Flame") == null,
		"its fire stays off (? fire colour)")
	view.clear()
	# M4-fix: the footprint is cached (Arena.shrine_rect). A client's mirror arena whose world gets the break
	# as edits one tile at a time never shows the whole footprint once a tile of it is broken, and ends empty.
	var copy: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var mirror: Arena = Arena.mirror(copy)
	check_eq(mirror.shrine_rect(), rect, "the mirror finds the standing shrine")
	var stale: int = 0
	for e: EditLog.WorldEdit in edits:
		EditLog.apply_to_data(copy, e)
		if mirror.shrine_rect() == rect:
			stale += 1
	check(stale == 0 and not mirror.shrine_rect().has_area() and mirror.shrine_hp_now() == 0,
		"edit by edit the cached footprint follows the data and ends empty (stale %d)" % stale)


# --- main.tscn -------------------------------------------------------------------------------------------

## Offline main.tscn: only the local player's map ticks (the dungeon waits while it is on the surface);
## heretics stay on their map; the miner's pickaxe mines a wall it is aimed at (the heretic next to it
## untouched) and hits a heretic when aimed at open floor (no wall touched).
func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null and main.arenas.has(Config.MAP_DUNGEON), "main has a player and a dungeon arena"):
		return
	p.local_input = false
	var below: Arena = main.arenas[Config.MAP_DUNGEON]
	for t: int in Config.HERETIC_SPAWN_INTERVAL_TICKS + 10:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK)
		main.step_combat(TICK)
	check(below.spawn_timer == 0 and below.heretics.is_empty(), "the dungeon does not tick while the player is on the surface")
	check(stat(main.arenas[Config.MAP_SURFACE], "spawned") >= 1, "the surface does")
	for h: HereticSim in main.arenas[Config.MAP_SURFACE].heretics:
		check(main.world.data.in_bounds(Aim.feet_cell(h.pos)), "surface heretics on the surface map")
	# M4-fix: a heretic in its wind-up beside the entrance when the player goes down; the player comes back up
	# at the arrival point, at its side: the knife does not land before a whole new telegraph (before, the
	# frozen wind-up went on and struck about 20 ticks after the return).
	var surf: Arena = main.arenas[Config.MAP_SURFACE]
	surf.spawning = false
	surf.heretics.clear()
	var arrive: Vector2 = main.world.arrival_point()
	p.teleport(arrive)
	var foe0: HereticSim = surf.spawn_heretic(arrive + Vector2(14, 0))
	check(not surf.in_light(arrive) and not surf.in_light(foe0.pos), "the entrance's arrival point is outside the light")
	var wind: int = 0
	while not (foe0.state == HereticSim.State.ATTACK and foe0.state_ticks >= 10) and wind < 120:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK)
		main.step_combat(TICK)
		wind += 1
	check(foe0.state == HereticSim.State.ATTACK and foe0.state_ticks < Config.HERETIC_TELEGRAPH_TICKS, "the heretic is mid wind-up")
	check(main.travel(Config.MAP_DUNGEON), "the player goes down mid wind-up")
	for t: int in 60:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK)
		main.step_combat(TICK)
	check(foe0.state != HereticSim.State.ATTACK and stat(surf, "knife_swings") == 0, "the surface emptied: its attack stopped, no knife")
	check(main.travel(Config.MAP_SURFACE), "and comes back up at its side")
	var hp0: int = p.vitals.hp
	for t: int in Config.HERETIC_TELEGRAPH_TICKS + 2:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, p.sim_position, false, false, false, TICK)
		main.step_combat(TICK)
	check(p.vitals.hp == hp0 and p.sim_position.distance_to(foe0.pos) < Config.HERETIC_HIT_REACH_PX,
		"no knife within a telegraph of coming back (hp %d, %.1f px from it)" % [p.vitals.hp, p.sim_position.distance_to(foe0.pos)])
	surf.heretics.clear()
	check(main.travel(Config.MAP_DUNGEON), "down")
	main.arenas[Config.MAP_DUNGEON].spawning = false
	# The miner (re-spawn as miner, in the dungeon).
	main.spawn("miner")
	check(main.travel(Config.MAP_DUNGEON), "the miner goes down")
	p = main.player
	p.local_input = false
	check_eq(p.inventory.stack_at(Config.START_WEAPON_SLOT).id, &"pickaxe", "the miner starts with the pickaxe")
	p.inventory.select(Config.START_WEAPON_SLOT)
	var data: WorldData = main.current_world().data
	var arena: Arena = main.arenas[Config.MAP_DUNGEON]
	arena.spawning = false
	# Find a wall face tile just north of open floor in the arrival room: stand south of it.
	var feet_cell: Vector2i = Aim.feet_cell(p.sim_position)
	var face: Vector2i = Walls.NO_CELL
	for dx: int in range(-4, 5):
		var c: Vector2i = feet_cell + Vector2i(dx, -1)
		if Walls.is_face(data, c) and not Movement.is_blocked(data, c + Vector2i(0, 1)) and Walls.hardness(data, c + Vector2i(0, -1)) <= Config.HARDNESS_CAP_MINER \
				and data.get_value(WorldData.Layer.PLACEABLE, c + Vector2i(0, -1)) == 0 and Walls.hardness(data, c + Vector2i(0, -1)) > 0:
			face = c
			break
	if not check(face != Walls.NO_CELL, "a breakable wall face near the arrival point"):
		return
	p.teleport(Arena.spawn_feet(face + Vector2i(0, 1)))
	# Beside the swing, inside the pickaxe's arc and reach toward the wall: a swing that also attacked would hit it.
	var foe: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(8, -10))
	check(Combat.melee_hits(data, p.sim_position, Vector2.UP, foe.pos, Combat.attack_for(&"pickaxe").reach,
		Combat.attack_for(&"pickaxe").arc_deg), "the heretic is in the swing's arc")
	foe.cooldown = 1000000  # it stands by, it does not strike (the miner's swings must not be cut off)
	var owner: Vector2i = face + Vector2i(0, -1)
	var hits_before: int = Walls.hits_at(data, owner)
	_swing(main, p, Arena.spawn_feet(face) - Vector2(0, 6))
	check(Walls.hits_at(data, owner) > hits_before or not Walls.is_wall(data, owner), "aimed at the wall: the pickaxe mines it")
	check_eq(foe.hp, Config.HERETIC_HP, "and the heretic beside it is not hit")
	var floor_cell: Vector2i = Aim.feet_cell(p.sim_position) + Vector2i(1, 0)
	if Movement.is_blocked(data, floor_cell):
		floor_cell = Aim.feet_cell(p.sim_position) + Vector2i(-1, 0)
	foe.pos = Arena.spawn_feet(floor_cell)
	var wall_hash: String = data.content_hash()
	_swing(main, p, Arena.spawn_feet(floor_cell) - Vector2(0, 6))
	check(foe.hp < Config.HERETIC_HP, "aimed at open floor with a heretic there: it hits the heretic")
	check_eq(data.content_hash(), wall_hash, "and mines nothing")


func _swing(main: Main, p: Player, mouse: Vector2) -> void:
	for t: int in Player.action_ticks(RigData.Anim.PICKAXE) + 2:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, mouse, true, t == 0, t == 0, TICK)
		main.step_combat(TICK)
