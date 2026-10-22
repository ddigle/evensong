extends "res://tests/base_test.gd"
## M4a, the player's side of combat (offline first): the dash (distance, stamina, cooldown, walls and the
## altar, invulnerability, when it may not start), the stagger, down, revive (cleric at once, others
## after Config.REVIVE_TICKS, the reach, letting go), death (Config.DOWN_TICKS, giving up) and respawn
## timings, the basic attack of every class (reach, arc, walls in the way, shots that stop, friendly
## fire off, the miner's pickaxe rule), the death bag (both '일부' rules, the bag tile, F takes it back,
## full inventories, MAX_DROPS, through the world's edits and snapshot), the shared simulation
## (offline == host run_frame == client prediction, vitals included) and main.tscn offline (the start
## weapon, a fight, dying alone, the bag, the respawn at the altar).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_dash()
	_check_dash_collision()
	_check_stagger()
	_check_down_and_death()
	_check_revive()
	_check_weapons_table()
	_check_melee()
	_check_shots()
	_check_shot_aim()
	_check_shot_corners()
	_check_step_cost()
	_check_friendly_fire()
	_check_pickaxe_rule()
	_check_bag_rules()
	_check_bag_cell_and_recovery()
	_check_bag_through_edits()
	_check_shared_sim()
	await _check_main_offline()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------

## An open dungeon-kind map (no altar, so no light) of `size` tiles.
static func open_world(size: Vector2i = Vector2i(30, 20)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_DUNGEON
	return d


static func wall(d: WorldData, c: Vector2i) -> void:
	d.set_value(WorldData.Layer.WALL, c, Walls.pack(Walls.KIND_ROCK, 0))


## Feet at the centre of tile `c`, low in it (the spawn / arrival rule).
static func feet(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	_nodes.append(p)
	return p


static func frame(dir: Vector2i = Vector2i.ZERO, dash: bool = false, interact: bool = false) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, dir)
	f.dash = dash
	f.interact = interact
	return f


static func tick(p: Player, f: NetProtocol.InputFrame) -> void:
	p.begin_tick()
	p.step_frame(f, TICK)


# --- dash ------------------------------------------------------------------------------------------

func _check_dash() -> void:
	var d: WorldData = open_world()
	var s: PlayerSim = PlayerSim.new()
	s.pos = feet(Vector2i(5, 10))
	var start: Vector2 = s.pos
	var ev: int = s.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true)
	check(ev & PlayerSim.DASHED != 0, "Space starts a dash")
	check_eq(s.vit.stamina, Config.STAMINA_MAX - Config.DASH_STAMINA, "the dash costs DASH_STAMINA")
	for i: int in Config.DASH_TICKS - 1:
		check_eq(s.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK, true) & PlayerSim.DASHED, 0,
			"no second dash while one lasts")
	var dash_px: float = Config.DASH_SPEED * Config.DASH_TICKS / Config.NET_TICK_RATE
	check_between(s.pos.x - start.x, dash_px - 0.01, dash_px + 0.01, "a dash goes DASH_SPEED x DASH_TICKS (%.2f px)" % dash_px)
	check_eq(s.pos.y, start.y, "straight east")
	check_eq(s.vit.dash_ticks, 0, "the dash is over")
	# Cooldown: Space every tick, the next dash starts DASH_COOLDOWN_TICKS after the first one ended.
	var next_at: int = -1
	for t: int in 120:
		if s.step(d, Vector2i(-1, 0), -1, -1, Vector2i.ZERO, TICK, true) & PlayerSim.DASHED:
			next_at = t
			break
	check_eq(next_at, Config.DASH_COOLDOWN_TICKS, "the next dash waits out the cooldown after the dash")
	# Stamina: no regen during the wait after spending, then one point every STAMINA_REGEN_TICKS.
	var r: PlayerSim = PlayerSim.new()
	r.pos = feet(Vector2i(20, 10))
	r.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK, true)
	var before: int = r.vit.stamina
	check_eq(before, Config.STAMINA_MAX - Config.DASH_STAMINA, "spent")
	for t: int in Config.STAMINA_REGEN_DELAY_TICKS:
		r.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK)
	check_eq(r.vit.stamina, before, "no regen during STAMINA_REGEN_DELAY_TICKS")
	for t: int in 10 * Config.STAMINA_REGEN_TICKS:
		r.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK)
	check_eq(r.vit.stamina, before + 10, "then one point every STAMINA_REGEN_TICKS")
	# Not enough stamina: no dash.
	var low: PlayerSim = PlayerSim.new()
	low.pos = feet(Vector2i(5, 5))
	low.vit.stamina = Config.DASH_STAMINA - 1
	check_eq(low.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true) & PlayerSim.DASHED, 0, "too little stamina: no dash")
	# No dash in the facing direction without input: the facing (south) is used.
	var still: PlayerSim = PlayerSim.new()
	still.pos = feet(Vector2i(5, 5))
	still.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK, true)
	check(still.pos.y > feet(Vector2i(5, 5)).y and still.pos.x == feet(Vector2i(5, 5)).x, "no input: the dash goes the facing way")
	# Not during an action, a stagger or while down.
	var acting: PlayerSim = PlayerSim.new()
	acting.pos = feet(Vector2i(5, 5))
	acting.step(d, Vector2i.ZERO, -1, RigData.Anim.SWORD, Aim.feet_cell(acting.pos) + Vector2i(1, 0), TICK)
	check_eq(acting.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true) & PlayerSim.DASHED, 0, "no dash during an action")
	var hit: PlayerSim = PlayerSim.new()
	hit.pos = feet(Vector2i(5, 5))
	hit.hurt(5)
	check_eq(hit.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true) & PlayerSim.DASHED, 0, "no dash while staggered")
	var down: PlayerSim = PlayerSim.new()
	down.pos = feet(Vector2i(5, 5))
	down.hurt(Config.PLAYER_HP_MAX)
	var at: Vector2 = down.pos
	check_eq(down.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true) & PlayerSim.DASHED, 0, "no dash while down")
	check_eq(down.pos, at, "a downed player does not move")
	# Invulnerable while dashing (Config.DASH_INVULNERABLE).
	var dodge: PlayerSim = PlayerSim.new()
	dodge.pos = feet(Vector2i(5, 5))
	dodge.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true)
	check_eq(dodge.hurt(10), 0 if Config.DASH_INVULNERABLE else PlayerSim.HURT, "a hit during the dash (DASH_INVULNERABLE)")
	check_eq(dodge.vit.hp, Config.PLAYER_HP_MAX if Config.DASH_INVULNERABLE else Config.PLAYER_HP_MAX - 10, "HP after it")
	# M4-fix: going to another map (Player.set_world: TRAVEL, Main.travel) stops a dash under way; it does
	# not carry on from the arrival point (its cooldown runs on).
	var traveller: Player = player(d, "archer", feet(Vector2i(5, 12)))
	tick(traveller, frame(Vector2i(1, 0), true))
	check(traveller.vitals.dash_ticks > 0, "dashing")
	var other: WorldData = open_world()
	var arrive: Vector2 = feet(Vector2i(10, 4))
	traveller.set_world(other, arrive)
	tick(traveller, frame())
	check(traveller.sim_position == arrive and traveller.vitals.dash_ticks == 0 and traveller.vitals.dash_dir == Vector2i.ZERO
		and traveller.vitals.dash_cooldown > 0, "set_world stops the dash: it stays at the arrival point (cooldown %d)" % traveller.vitals.dash_cooldown)


## Dashes use walking's collision: straight into a wall stops flush; thousands of random dashes in the
## seed-1 dungeon and around the surface altar never leave the player on a blocked tile or inside the
## altar's footprint or side bands.
func _check_dash_collision() -> void:
	var d: WorldData = open_world()
	for y: int in d.size.y:
		wall(d, Vector2i(12, y))
	var s: PlayerSim = PlayerSim.new()
	s.pos = feet(Vector2i(10, 8))
	s.step(d, Vector2i(1, 0), -1, -1, Vector2i.ZERO, TICK, true)
	for i: int in Config.DASH_TICKS:
		s.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK)
	check_eq(s.pos.x, 12.0 * Config.TILE - Config.FEET_HALF_WIDTH, "a dash into a wall stops flush against it")
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 404
	var bad: int = 0
	var dashes: int = 0
	var moved: float = 0.0
	for world: WorldData in [dungeon, surface]:
		var p: PlayerSim = PlayerSim.new()
		p.pos = DungeonGen.arrival_point(world) if world == dungeon else world.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0])
		var dir: Vector2i = Vector2i(1, 0)
		for t: int in 3000:
			if t % 20 == 0:
				dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
			var from: Vector2 = p.pos
			if p.step(world, dir, -1, -1, Vector2i.ZERO, TICK, rng.randf() < 0.2) & PlayerSim.DASHED:
				dashes += 1
			p.vit.stamina = Config.STAMINA_MAX
			moved += from.distance_to(p.pos)
			if not Movement.can_stand(world, p.pos):
				bad += 1
	check_eq(bad, 0, "random dashes never end a tick on a wall, a face, a fixture or the altar (%d dashes)" % dashes)
	check(dashes > 100 and moved > 3000.0, "the random run dashed a lot (%d dashes, %.0f px)" % [dashes, moved])


# --- stagger, down, death, respawn ------------------------------------------------------------------

func _check_stagger() -> void:
	var d: WorldData = open_world()
	var p: Player = player(d, "paladin", feet(Vector2i(5, 5)))
	p.inventory.add(&"sword", 1)
	var use: NetProtocol.InputFrame = frame()
	use.op = NetProtocol.Op.USE
	use.anim = RigData.Anim.SWORD
	use.item = &"sword"
	use.cell = Aim.feet_cell(p.sim_position) + Vector2i(1, 0)
	tick(p, use)
	check_eq(p.action_anim, RigData.Anim.SWORD, "swinging")
	check_eq(p.take_hit(10), PlayerSim.HURT, "a hit lands")
	check_eq([p.vitals.hp, p.vitals.hurt_ticks, p.vitals.invuln_ticks], [Config.PLAYER_HP_MAX - 10, Config.HURT_TICKS,
		Config.HURT_INVULN_TICKS], "HP, stagger and invulnerability after it")
	check_eq(p.action_anim, -1, "the hit cuts the swing off")
	check_eq(p.character.action, RigData.Anim.HURT, "the hurt pose shows")
	check(p.character.modulate == Player.HIT_FLASH, "with the hit flash")
	check_eq(p.take_hit(10), 0, "no second hit while invulnerable")
	var at: Vector2 = p.sim_position
	for t: int in Config.HURT_TICKS:
		tick(p, frame(Vector2i(1, 0)))
		check_eq(p.sim_position, at, "staggered: no moving (tick %d)" % t)
	check_eq(p.character.action, -1, "the hurt pose is over after HURT_TICKS")
	tick(p, frame(Vector2i(1, 0)))
	check(p.sim_position.x > at.x, "then it walks again")
	check(p.character.modulate == Color.WHITE, "the flash is gone")
	var frames: Array[int] = []
	var q: Player = player(d, "archer", feet(Vector2i(8, 8)))
	q.take_hit(1)
	for t: int in Config.HURT_TICKS:
		frames.append(q.character.frame)
		tick(q, frame())
	check_eq(frames[0], 0, "hurt starts on frame 0")
	check_eq(frames[Config.HURT_TICKS - 1], RigData.frame_count(RigData.Anim.HURT) - 1, "and plays all 6 frames")


func _check_down_and_death() -> void:
	var d: WorldData = open_world()
	var p: Player = player(d, "miner", feet(Vector2i(5, 5)))
	var died: Array[int] = []
	var respawned: Array[int] = []
	var t_now: Array[int] = [0]
	p.died.connect(func() -> void: died.append(t_now[0]))
	p.respawn_due.connect(func() -> void: respawned.append(t_now[0]))
	check_eq(p.take_hit(Config.PLAYER_HP_MAX), PlayerSim.HURT | PlayerSim.DOWNED, "a hit to 0 HP downs the player")
	check_eq(p.vitals.life, Vitals.Life.DOWN, "down")
	check_eq(p.take_hit(5), 0, "no damage while down")
	var at: Vector2 = p.sim_position
	var act: NetProtocol.InputFrame = frame(Vector2i(1, 1), true)
	act.anim = RigData.Anim.PICKAXE
	act.cell = Aim.feet_cell(at) + Vector2i(1, 0)
	for t: int in Config.DOWN_TICKS + Config.RESPAWN_TICKS + 5:
		t_now[0] = t
		tick(p, act)
		if t == 3:
			check(p.sim_position == at and p.action_anim < 0, "downed: no moving, no action, no dash")
			check_eq(p.character.action, RigData.Anim.DEATH, "the death pose shows")
		if t == 3 * Config.DEATH_FRAME_TICKS * RigData.frame_count(RigData.Anim.DEATH):
			check_eq(p.character.frame, RigData.frame_count(RigData.Anim.DEATH) - 1, "then lying (the last death frame)")
			check(not p.character.signature_sprite().visible, "no signature on the lying body")
	check_eq(died, [Config.DOWN_TICKS - 1] as Array[int], "it dies after DOWN_TICKS down (30 s, §2.6)")
	# M4-fix: due RESPAWN_TICKS later and on every frame after until someone respawns it (nobody does here),
	# the count stopping at RESPAWN_TICKS.
	var due: int = Config.DOWN_TICKS - 1 + Config.RESPAWN_TICKS
	var want_due: Array[int] = []
	for t: int in range(due, Config.DOWN_TICKS + Config.RESPAWN_TICKS + 5):
		want_due.append(t)
	check_eq(respawned, want_due, "respawn due RESPAWN_TICKS later, then every frame until respawned")
	check_eq(p.vitals.life_ticks, Config.RESPAWN_TICKS, "the dead count stops at RESPAWN_TICKS")
	check(not p.character.visible, "a dead player is not drawn")
	# M4-fix: a dead player handed over past its respawn tick (a client that lost its host while dead in the
	# dungeon, waiting for the surface) is due on its next frame.
	var late: PlayerSim = PlayerSim.new()
	late.vit.life = Vitals.Life.DEAD
	late.vit.life_ticks = Config.RESPAWN_TICKS + 40
	check(late.step(d, Vector2i.ZERO, -1, -1, Vector2i.ZERO, TICK) & PlayerSim.RESPAWN != 0,
		"dead past the respawn tick: due at once")
	p.respawn_vitals()
	check(p.vitals.alive() and p.vitals.hp == Config.RESPAWN_HP and p.character.visible, "respawned: up, full, drawn")
	# Alone: holding F gives up.
	var q: Player = player(d, "cleric", feet(Vector2i(8, 5)))
	var gave: Array[int] = []
	q.died.connect(func() -> void: gave.append(t_now[0]))
	q.take_hit(Config.PLAYER_HP_MAX)
	for t: int in Config.GIVE_UP_HOLD_TICKS + 2:
		t_now[0] = t
		tick(q, frame(Vector2i.ZERO, false, t != 10))
	check_eq(gave.size(), 0, "letting go of F restarts the give-up hold")
	for t: int in Config.GIVE_UP_HOLD_TICKS:
		t_now[0] = 1000 + t
		tick(q, frame(Vector2i.ZERO, false, true))
	check(gave.size() == 1 and q.vitals.life == Vitals.Life.DEAD, "holding F GIVE_UP_HOLD_TICKS gives up (dies) (%s)" % [gave])


func _check_revive() -> void:
	var d: WorldData = open_world()
	var arena: Arena = Arena.new()
	arena.setup(d, 1)
	arena.spawning = false
	for reviver_class: String in ["paladin", "cleric"]:
		var down: Player = player(d, "archer", feet(Vector2i(5, 5)))
		var helper: Player = player(d, reviver_class, down.sim_position + Vector2(Config.REVIVE_REACH_PX - 1.0, 0))
		var players: Array[Player] = [down, helper]
		down.take_hit(Config.PLAYER_HP_MAX)
		var need: int = Config.REVIVE_TICKS_CLERIC if reviver_class == "cleric" else Config.REVIVE_TICKS
		var up_at: int = -1
		for t: int in Config.REVIVE_TICKS + 10:
			tick(down, frame())
			tick(helper, frame(Vector2i.ZERO, false, true))
			arena.step(players)
			if down.vitals.alive():
				up_at = t
				break
		check_eq(up_at, maxi(need, 1) - 1, "%s holding F revives in %d ticks (§2.6: cleric at once, others 5 s)" % [reviver_class, need])
		check_eq(down.vitals.hp, Config.REVIVE_HP, "revived with REVIVE_HP")
	# M4-fix: two holding F, a paladin and a cleric, in either order of the players: the cleric's instant
	# revive counts (● §2.6 "성직자는 즉시"), not the first one's 5 s; the view's revive bar uses the same one.
	for order: Array in [["paladin", "cleric"], ["cleric", "paladin"]]:
		var class_a: String = order[0]
		var class_b: String = order[1]
		var down2: Player = player(d, "archer", feet(Vector2i(24, 15)))
		var first: Player = player(d, class_a, down2.sim_position + Vector2(10, 0))
		var second: Player = player(d, class_b, down2.sim_position + Vector2(-10, 0))
		var three: Array[Player] = [down2, first, second]
		down2.take_hit(Config.PLAYER_HP_MAX)
		tick(first, frame(Vector2i.ZERO, false, true))
		tick(second, frame(Vector2i.ZERO, false, true))
		var fastest: Player = Arena.reviver_for(down2, three)
		check(fastest != null and fastest.class_id() == "cleric", "%s then %s holding F: the cleric is the reviver" % order)
		tick(down2, frame())
		arena.step(three)
		check(down2.vitals.alive(), "%s then %s holding F: up on the first tick (the cleric's instant revive)" % order)
	# Out of reach, or letting go: no revive, the progress resets.
	var far: Player = player(d, "miner", feet(Vector2i(10, 10)))
	var near: Player = player(d, "herbalist", far.sim_position + Vector2(Config.REVIVE_REACH_PX + 2.0, 0))
	var two: Array[Player] = [far, near]
	far.take_hit(Config.PLAYER_HP_MAX)
	for t: int in 30:
		tick(far, frame())
		tick(near, frame(Vector2i.ZERO, false, true))
		arena.step(two)
	check_eq(far.vitals.revive_ticks, 0, "out of reach: no progress")
	near.teleport(far.sim_position + Vector2(10, 0))
	for t: int in 100:
		tick(far, frame())
		tick(near, frame(Vector2i.ZERO, false, true))
		arena.step(two)
	check_eq(far.vitals.revive_ticks, 100, "in reach: progress")
	tick(far, frame())
	tick(near, frame())
	arena.step(two)
	check_eq(far.vitals.revive_ticks, 0, "letting go resets it")
	# The down timer keeps running during a revive: too late, it dies first.
	var late: Player = player(d, "paladin", feet(Vector2i(14, 5)))
	var friend: Player = player(d, "archer", late.sim_position + Vector2(8, 0))
	var pair: Array[Player] = [late, friend]
	late.take_hit(Config.PLAYER_HP_MAX)
	late.vitals.life_ticks = Config.DOWN_TICKS - 60
	for t: int in 80:
		tick(late, frame())
		tick(friend, frame(Vector2i.ZERO, false, true))
		arena.step(pair)
	check_eq(late.vitals.life, Vitals.Life.DEAD, "a slow revive that outlasts the down time fails")
	# A downed reviver, an acting one: nobody revives.
	var a: Player = player(d, "paladin", feet(Vector2i(20, 12)))
	var b: Player = player(d, "cleric", a.sim_position + Vector2(8, 0))
	var ab: Array[Player] = [a, b]
	a.take_hit(Config.PLAYER_HP_MAX)
	b.take_hit(Config.PLAYER_HP_MAX)
	tick(a, frame())
	tick(b, frame(Vector2i.ZERO, false, true))
	arena.step(ab)
	check(a.vitals.life == Vitals.Life.DOWN and b.vitals.life == Vitals.Life.DOWN, "a downed cleric revives nobody")


# --- basic attacks -----------------------------------------------------------------------------------

func _check_weapons_table() -> void:
	for class_id: String in Config.CLASSES:
		var weapon: StringName = Combat.class_weapon(class_id)
		var a: Combat.Attack = Combat.attack_for(weapon)
		var def: ItemDB.ItemDef = ItemDB.get_def(weapon)
		if not check(a != null and def != null and def.is_tool(), "%s's weapon %s is a tool with an attack" % [class_id, weapon]):
			continue
		check(a.hit_frame >= 0 and a.hit_frame < RigData.frame_count(def.action), "%s hits on a frame of its action" % weapon)
	check_eq(Combat.attack_for(&"sword").kind, Combat.Kind.MELEE, "paladin sword: melee arc")
	check_eq(Combat.attack_for(&"bow").kind, Combat.Kind.ARROW, "archer bow: arrow")
	check_eq(Combat.attack_for(&"holy_light").kind, Combat.Kind.BOLT, "cleric holy light: bolt")
	check_eq(ItemDB.get_def(&"holy_light").action, RigData.Anim.MAGIC, "the holy light plays the magic action")
	check_eq(Combat.attack_for(&"pickaxe").kind, Combat.Kind.MELEE, "miner pickaxe: melee")
	check(Combat.attack_for(&"hoe") == null and Combat.attack_for(&"watering_can") == null and Combat.attack_for(&"torch") == null,
		"hoe, watering can and torch do not attack")
	check_eq(Combat.impact_tick(&"pickaxe"), Mining.impact_tick(), "the pickaxe's attack lands on the mining frame")
	check_eq(Combat.impact_tick(&"sword"), Combat.attack_for(&"sword").hit_frame * Config.ACTION_FRAME_TICKS, "sword hit tick")
	var corner: Array[Vector2i] = Combat.cells_on_line(Vector2(8, 26), Vector2(16, 16))
	var last: Vector2i = corner.back()
	check(last == Vector2i(1, 1) and not corner.has(Vector2i(0, 0)),
		"a line ending exactly on a tile corner ends in the tile under its end (%s)" % [corner])
	check_eq(Combat.cells_on_line(Vector2(4, 4), Vector2(60, 4)), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)] as Array[Vector2i],
		"a straight line visits every tile")
	for code: int in [0, 1, 63, 64, 128, 200, 255]:
		check_eq(Combat.aim_code(Combat.aim_vector(code) * 37.0), code, "aim code %d round trip" % code)


## Melee weapons: hit inside the reach and the arc, miss beyond either, never through a wall.
func _check_melee() -> void:
	for weapon: StringName in [&"sword", &"pickaxe", &"sickle"]:
		var a: Combat.Attack = Combat.attack_for(weapon)
		var d: WorldData = open_world()
		var arena: Arena = Arena.new()
		arena.setup(d, 1)
		arena.spawning = false
		var p: Player = player(d, "paladin", feet(Vector2i(10, 10)))
		var east: int = Combat.aim_code(Vector2.RIGHT)
		var cases: Array[Array] = [
			[Vector2(a.reach - 1.0, 0.0), true, "in reach, straight ahead"],
			[Vector2(a.reach + 1.0, 0.0), false, "just beyond the reach"],
			[Vector2.from_angle(deg_to_rad(a.arc_deg / 2.0 - 4.0)) * (a.reach - 2.0), true, "inside the arc's edge"],
			[Vector2.from_angle(deg_to_rad(a.arc_deg / 2.0 + 4.0)) * (a.reach - 2.0), false, "outside the arc"],
			[Vector2(-10.0, 0.0), false, "behind"],
		]
		for c: Array in cases:
			var off: Vector2 = c[0]
			var want: bool = c[1]
			var h: HereticSim = arena.spawn_heretic(p.sim_position + off)
			arena.player_attack(p, weapon, east)
			check_eq(h.hp < Config.HERETIC_HP, want, "%s: %s" % [weapon, c[2]])
			arena.heretics.clear()
		# A wall between: a heretic across a wall column. A wall tile (16 px) and two half feet boxes keep it
		# out of every weapon's reach anyway, so the line rule is checked with this weapon's arc and a
		# reach long enough to cross the wall: the same pair hits on open ground and not through the wall.
		var walled: WorldData = open_world()
		for y: int in walled.size.y:
			wall(walled, Vector2i(11, y))
		var q_at: Vector2 = Vector2(11 * Config.TILE - Config.FEET_HALF_WIDTH, feet(Vector2i(10, 10)).y)
		var h_at: Vector2 = Vector2(12 * Config.TILE + Config.FEET_HALF_WIDTH, q_at.y)
		check(Combat.melee_hits(open_world(), q_at, Vector2.RIGHT, h_at, 40.0, a.arc_deg), "%s: in the open the long swing hits" % weapon)
		check(not Combat.melee_hits(walled, q_at, Vector2.RIGHT, h_at, 40.0, a.arc_deg), "%s: not through a wall" % weapon)
		var arena2: Arena = Arena.new()
		arena2.setup(walled, 1)
		var q: Player = player(walled, "paladin", q_at)
		var behind: HereticSim = arena2.spawn_heretic(h_at)
		arena2.player_attack(q, weapon, east)
		check_eq(behind.hp, Config.HERETIC_HP, "%s: a real swing at a wall hits nobody behind it" % weapon)
	# Damage and kills: the sword's swings to kill a heretic.
	var d2: WorldData = open_world()
	var arena3: Arena = Arena.new()
	arena3.setup(d2, 1)
	var s: Player = player(d2, "paladin", feet(Vector2i(5, 5)))
	var foe: HereticSim = arena3.spawn_heretic(s.sim_position + Vector2(12, 0))
	var swings: int = 0
	while foe.alive() and swings < 20:
		arena3.player_attack(s, &"sword", Combat.aim_code(Vector2.RIGHT))
		swings += 1
	check_eq(swings, ceili(float(Config.HERETIC_HP) / Combat.attack_for(&"sword").damage), "sword swings to kill a heretic")
	check_eq(foe.state, HereticSim.State.DEAD, "dead")
	check_eq(arena3.stats.get("killed", 0), 1, "counted")


## Shots (arrow, bolt): fly at their speed along the aim, hit the first heretic, stop at walls and
## blocking fixtures, are spent after their reach.
func _check_shots() -> void:
	for weapon: StringName in [&"bow", &"holy_light"]:
		var a: Combat.Attack = Combat.attack_for(weapon)
		var d: WorldData = open_world(Vector2i(40, 20))
		var arena: Arena = Arena.new()
		arena.setup(d, 1)
		arena.spawning = false
		var p: Player = player(d, "archer", feet(Vector2i(3, 10)))
		var none: Array[Player] = []
		var target: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(a.reach - 12.0, 0))
		var far: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(a.reach - 4.0, 0))
		arena.player_attack(p, weapon, Combat.aim_code(Vector2.RIGHT))
		check_eq(arena.shots.size(), 1, "%s lets a shot go" % weapon)
		var shot: Arena.Shot = arena.shots[0]
		check_eq(shot.kind, a.kind, "%s shot kind" % weapon)
		var ticks: int = 0
		while not arena.shots.is_empty() and ticks < 600:
			arena.step(none)
			ticks += 1
		var want_ticks: int = ceili((a.reach - 12.0 - Config.BODY_HIT_RADIUS_PX) / (a.speed / Config.NET_TICK_RATE))
		check_between(ticks, want_ticks - 1, want_ticks + 1, "%s: flies at its speed (%d ticks, about %d)" % [weapon, ticks, want_ticks])
		check(target.hp < Config.HERETIC_HP and far.hp == Config.HERETIC_HP, "%s: the first heretic is hit, not the one behind" % weapon)
		check_eq(shot.stopped_by, "heretic", "%s stopped by the heretic" % weapon)
		# Beyond the reach: spent.
		arena.heretics.clear()
		var out: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(a.reach + 20.0, 0))
		arena.player_attack(p, weapon, Combat.aim_code(Vector2.RIGHT))
		var spent: Arena.Shot = arena.shots[0]
		for t: int in 600:
			arena.step(none)
		check(spent.stopped_by == "spent" and out.hp == Config.HERETIC_HP, "%s: spent after its reach" % weapon)
		# A wall in the way.
		arena.heretics.clear()
		for y: int in d.size.y:
			wall(d, Vector2i(6, y))
		var behind: HereticSim = arena.spawn_heretic(feet(Vector2i(8, 10)))
		arena.player_attack(p, weapon, Combat.aim_code(Vector2.RIGHT))
		var blocked: Arena.Shot = arena.shots[0]
		for t: int in 600:
			arena.step(none)
		check(blocked.stopped_by == "wall" and behind.hp == Config.HERETIC_HP, "%s: a wall stops it (%s)" % [weapon, blocked.stopped_by])
		check(blocked.pos.x < 6 * Config.TILE + Config.SHOT_STEP_PX + 0.01, "%s: it stopped at the wall (x %.1f)" % [weapon, blocked.pos.x])
	# The surface altar blocks shots too (a fixture that blocks walking).
	var surface: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var arena2: Arena = Arena.new()
	arena2.setup(surface, 1)
	arena2.spawning = false
	var w: Player = player(surface, "archer", surface.altar_center_px() + Vector2(Config.SPAWN_SLOTS[0]))
	var across: HereticSim = arena2.spawn_heretic(surface.altar_center_px() + Vector2(-Config.SPAWN_SLOTS[0].x, Config.SPAWN_SLOTS[0].y))
	arena2.player_attack(w, &"bow", Combat.aim_code(Vector2.RIGHT))
	var s2: Arena.Shot = arena2.shots[0]
	var nobody: Array[Player] = []
	for t: int in 120:
		arena2.step(nobody)
	check(s2.stopped_by == "wall" and across.hp == Config.HERETIC_HP, "the altar stops an arrow (%s)" % s2.stopped_by)


## M4-fix: aiming a bow or the holy light at a heretic's figure hits wherever on the figure the mouse is:
## the aim comes from Player.make_frame (the real mouse rule: from where the shot is drawn leaving the
## shooter, Combat.aim_origin), so the drawn shot flies through the cursor, and the hit box is the drawn
## figure (Combat.shot_hits_body). Distances 40 / 80 / 120 px, every 30°, the mouse 2..26 px above the
## heretic's feet (its figure is opaque from 1 to 29 px up; an aim code is 1.4°, about 1.5 px at 120 px, so
## the very edge can go either way). Before, only clicks within about 8 px of its feet hit on level shots
## (review probe). Level shots at the mouse 6 px above its head miss (the figure, not more).
func _check_shot_aim() -> void:
	var tries: int = 0
	var missed: Array[String] = []
	var over_head_hits: Array[String] = []
	for weapon: StringName in [&"bow", &"holy_light"]:
		var a: Combat.Attack = Combat.attack_for(weapon)
		var d: WorldData = open_world(Vector2i(40, 40))
		var arena: Arena = Arena.new()
		arena.setup(d, 1)
		arena.spawning = false
		var p: Player = player(d, "archer", feet(Vector2i(20, 20)))
		var none: Array[Player] = []
		for dist: float in [40.0, 80.0, 120.0]:
			if dist > a.reach - 2.0 * Config.BODY_HIT_RADIUS_PX:
				continue
			for deg: int in range(0, 360, 30):
				var at: Vector2 = p.sim_position + Vector2.from_angle(deg_to_rad(float(deg))) * dist
				for lift: float in [2.0, 6.0, 10.0, 14.0, 20.0, 26.0, Config.BODY_HIT_HEIGHT_PX + 6.0]:
					arena.heretics.clear()
					var h: HereticSim = arena.spawn_heretic(at)
					var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, at - Vector2(0.0, lift), true, false, false)
					arena.player_attack(p, weapon, f.aim)
					for t: int in 120:
						if arena.shots.is_empty():
							break
						arena.step(none)
					arena.shots.clear()
					var hit: bool = h.hp < Config.HERETIC_HP
					var label: String = "%s %d px %d deg %.0f px up" % [weapon, roundi(dist), deg, lift]
					if lift <= Config.BODY_HIT_HEIGHT_PX:
						tries += 1
						if not hit:
							missed.append(label)
					elif (deg == 0 or deg == 180) and hit:
						over_head_hits.append(label)
	check(missed.is_empty(), "%d shots at the heretic's figure (2..26 px above its feet): every one hits (missed %s)" % [tries, missed])
	check(over_head_hits.is_empty(), "level shots 6 px above its head miss (%s)" % [over_head_hits])
	# The drawn shot goes through the cursor: the aim from aim_origin, the shot drawn SHOT_DRAW_LIFT_PX above
	# its ground point that starts at the body point.
	var o: Vector2 = Combat.aim_origin(Vector2(100, 100))
	check_eq(o, Combat.body_point(Vector2(100, 100)) - Vector2(0, Config.SHOT_DRAW_LIFT_PX), "aim origin = where the shot is drawn leaving")


## M4-fix: a line of walls that touch only at their corners (x + y == 20) stops every shot crossing it:
## the steps of a shot count every tile between them (an exact grid walk, as line of sight does), not only
## the tile under each step. Before, about 3 % of such arrows ended up on the far side (review probe).
func _check_shot_corners() -> void:
	var d: WorldData = open_world(Vector2i(40, 40))
	for x: int in 21:
		wall(d, Vector2i(x, 20 - x))
	var arena: Arena = Arena.new()
	arena.setup(d, 1)
	arena.spawning = false
	var none: Array[Player] = []
	var shots: int = 0
	var crossed: int = 0
	var sight_crossed: int = 0
	for ox: int in 5:
		for oy: int in 5:
			var p: Player = player(d, "archer", Vector2(8 * Config.TILE + 3.3 * ox, 8 * Config.TILE + 2.9 * oy + 1.0))
			for code: int in range(0, Combat.AIM_STEPS / 4 + 1):
				arena.player_attack(p, &"bow", code)
				var s: Arena.Shot = arena.shots.back()
				for t: int in 120:
					if s.done:
						break
					arena.step(none)
				shots += 1
				var c: Vector2i = Aim.cell_of(s.pos)
				if c.x + c.y > 20:
					crossed += 1
					if Combat.line_clear(d, Combat.body_point(p.sim_position), s.pos):
						sight_crossed += 1
				arena.shots.clear()
	check_eq(crossed, 0, "%d arrows at a line of corner-touching walls: none ends up beyond it" % shots)
	check_eq(sight_crossed, 0, "(and line of sight agrees)")


## M4-fix: the cost of one arena tick with shots in the air on the seed-1 surface (the shrine footprint is
## cached now: it was a whole-map scan per shot step). Measured, not checked against a bound.
func _check_step_cost() -> void:
	var surf: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var arena: Arena = Arena.new()
	arena.setup(surf, 1)
	arena.spawning = false
	var c: Vector2 = surf.altar_center_px() + Vector2(0, 200)
	var ps: Array[Player] = []
	for i: int in 9:
		ps.append(player(surf, "archer", c + Vector2(i * 4, 0)))
	var lines: PackedStringArray = []
	for n: int in [0, 9, 27]:
		arena.shots.clear()
		for i: int in n:
			var s: Arena.Shot = Arena.Shot.new()
			s.id = 1000 + i
			s.kind = Combat.Kind.ARROW
			s.dir = Vector2.RIGHT
			s.speed = 220.0
			s.left = 1000000
			s.damage = 1
			arena.shots.append(s)
		var t0: int = Time.get_ticks_usec()
		for k: int in 60:
			for s: Arena.Shot in arena.shots:
				s.pos = c + Vector2(0, -(s.id - 1000))  # back in the open each tick
			arena.step(ps)
		lines.append("%d arrows %.0f us" % [n, (Time.get_ticks_usec() - t0) / 60.0])
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var da: Arena = Arena.new()
	da.setup(dungeon, 1)
	var t1: int = Time.get_ticks_usec()
	for k: int in 1000:
		da.shrine_rect()
	check(da.shrine_rect().has_area(), "the dungeon's shrine footprint is found")
	note("Arena.step, seed-1 surface, 9 players: %s per tick; Arena.shrine_rect (dungeon, cached) %.2f us per call" % [
		", ".join(lines), (Time.get_ticks_usec() - t1) / 1000.0])


## Friendly fire off: a sword arc and an arrow pass players by.
func _check_friendly_fire() -> void:
	check(not Config.FRIENDLY_FIRE, "friendly fire is off (PROVISIONAL)")
	var d: WorldData = open_world(Vector2i(40, 20))
	var arena: Arena = Arena.new()
	arena.setup(d, 1)
	arena.spawning = false
	var p: Player = player(d, "paladin", feet(Vector2i(5, 10)))
	var ally: Player = player(d, "cleric", p.sim_position + Vector2(10, 0))
	var players: Array[Player] = [p, ally]
	var h: HereticSim = arena.spawn_heretic(p.sim_position + Vector2(14, 0))
	arena.player_attack(p, &"sword", Combat.aim_code(Vector2.RIGHT), players)
	check(ally.vitals.hp == Config.PLAYER_HP_MAX and h.hp < Config.HERETIC_HP, "the sword hits the heretic, not the ally in the arc")
	var archer: Player = player(d, "archer", feet(Vector2i(5, 14)))
	var friend: Player = player(d, "miner", archer.sim_position + Vector2(30, 0))
	var foe: HereticSim = arena.spawn_heretic(archer.sim_position + Vector2(80, 0))
	var two: Array[Player] = [archer, friend]
	arena.player_attack(archer, &"bow", Combat.aim_code(Vector2.RIGHT), two)
	for t: int in 60:
		arena.step(two)
	check(friend.vitals.hp == Config.PLAYER_HP_MAX and foe.hp < Config.HERETIC_HP, "the arrow passes the ally and hits the heretic")


## The miner's pickaxe: aimed at a wall or a wall's face it mines (and hits nobody); aimed at open floor
## it attacks (and mines nothing).
func _check_pickaxe_rule() -> void:
	var d: WorldData = open_world()
	wall(d, Vector2i(10, 5))
	check(Combat.is_mining_swing(d, &"pickaxe", Vector2i(10, 5)), "pickaxe at a wall: mining")
	check(Combat.is_mining_swing(d, &"pickaxe", Vector2i(10, 6)), "pickaxe at a wall's face: mining")
	check(not Combat.is_mining_swing(d, &"pickaxe", Vector2i(10, 7)), "pickaxe at open floor: an attack")
	check(not Combat.is_mining_swing(d, &"sword", Vector2i(10, 5)), "a sword never mines")


# --- the death bag -----------------------------------------------------------------------------------

static func kit(inv: Inventory) -> void:
	inv.add(&"sword", 1)
	inv.add(&"pickaxe", 1)
	inv.add(&"stone_a", 30)
	inv.add(&"wild_healing", 3, ItemDB.Grade.FINE)
	inv.add(&"torch", 5)
	inv.add(&"ore_copper", 1)
	inv.add(&"mushroom_a", 7)


func _check_bag_rules() -> void:
	var inv: Inventory = Inventory.new()
	kit(inv)
	var half: Dictionary[int, int] = WorldItems.death_drop_counts(inv, Config.DEATH_DROP_HALF, 0)
	var by_id: Dictionary[StringName, int] = {}
	for slot: int in half:
		by_id[inv.stack_at(slot).id] = half[slot]
	check_eq(by_id, {&"stone_a": 15, &"wild_healing": 2, &"torch": 3, &"ore_copper": 1, &"mushroom_a": 4} as Dictionary[StringName, int],
		"half rule: half of every material / consumable stack, rounded up; tools stay")
	var kinds_seen: Dictionary[String, bool] = {}
	for seed_value: int in 40:
		var three: Dictionary[int, int] = WorldItems.death_drop_counts(inv, Config.DEATH_DROP_KINDS, seed_value)
		var ids: Array[String] = []
		for slot: int in three:
			var st: ItemStack = inv.stack_at(slot)
			check_eq(three[slot], st.count, "kinds rule: the whole stack")
			check(not st.def().is_tool(), "kinds rule: never a tool")
			ids.append(String(st.id))
		ids.sort()
		check_eq(ids.size(), Config.DEATH_DROP_RANDOM_KINDS, "kinds rule: %d kinds" % Config.DEATH_DROP_RANDOM_KINDS)
		kinds_seen[",".join(ids)] = true
		check_eq(WorldItems.death_drop_counts(inv, Config.DEATH_DROP_KINDS, seed_value), three, "same seed, same pick")
	check(kinds_seen.size() > 3, "kinds rule: the pick varies with the seed (%d different picks)" % kinds_seen.size())
	var few: Inventory = Inventory.new()
	few.add(&"bow", 1)
	few.add(&"stone_b", 2)
	check_eq(WorldItems.death_drop_counts(few, Config.DEATH_DROP_KINDS, 1).size(), 1, "kinds rule with fewer kinds: what there is")
	var tools_only: Inventory = Inventory.new()
	tools_only.add(&"sword", 1)
	var d: WorldData = open_world()
	var o: WorldItems.Outcome = WorldItems.death_drop(d, feet(Vector2i(5, 5)), tools_only)
	check(not o.ok() and o.why == WorldItems.WHY_NOTHING_TO_DROP and o.edits.is_empty(), "only tools: no bag")


func _check_bag_cell_and_recovery() -> void:
	var d: WorldData = open_world()
	var inv: Inventory = Inventory.new()
	kit(inv)
	var at: Vector2 = feet(Vector2i(6, 6))
	var o: WorldItems.Outcome = WorldItems.death_drop(d, at, inv, Config.DEATH_DROP_HALF)
	if not check(o.ok(), "a death drops a bag (%s)" % o.why):
		return
	for e: EditLog.WorldEdit in o.edits:
		EditLog.apply_to_data(d, e)
	var cell: Vector2i = Aim.feet_cell(at)
	check_eq(d.get_value(WorldData.Layer.PLACEABLE, cell), WorldData.PLACEABLE_BAG, "the bag lies on the death tile")
	check_eq(d.drops_at(cell).size(), 5, "one drop per dropped stack in it")
	check_eq([inv.count_of(&"stone_a"), inv.count_of(&"sword"), inv.count_of(&"pickaxe")], [15, 1, 1], "the rest and the tools stay")
	check(Movement.can_stand(d, Arena.spawn_feet(cell)), "the bag does not block")
	# A second death on the same tile: the bag goes to the nearest free tile.
	var inv2: Inventory = Inventory.new()
	inv2.add(&"stone_c", 4)
	var o2: WorldItems.Outcome = WorldItems.death_drop(d, at, inv2, Config.DEATH_DROP_HALF)
	var c2: Vector2i = o2.edits[0].cell
	check(o2.ok() and c2 != cell and maxi(absi(c2.x - cell.x), absi(c2.y - cell.y)) == 1, "a second bag next to the first (%s)" % c2)
	for e: EditLog.WorldEdit in o2.edits:
		EditLog.apply_to_data(d, e)
	# Recovery: anyone picks it all up with F; partly when nearly full; refused when full.
	var finder: Inventory = Inventory.new()
	for i: int in Config.INVENTORY_SLOTS - 2:
		finder.add(&"stone_block", 99)
	var stand: Vector2 = feet(cell + Vector2i(-1, 0))
	var part: WorldItems.Outcome = WorldItems.pickup(d, stand, "paladin", finder, cell)
	check(part.ok() and part.count > 0, "nearly full: part of the bag")
	check_eq(d.get_value(WorldData.Layer.PLACEABLE, cell), WorldData.PLACEABLE_BAG, "before the edits apply the bag is there")
	for e: EditLog.WorldEdit in part.edits:
		EditLog.apply_to_data(d, e)
	check(d.get_value(WorldData.Layer.PLACEABLE, cell) == WorldData.PLACEABLE_BAG and not d.drops_at(cell).is_empty(),
		"what did not fit stays in the bag")
	var full: WorldItems.Outcome = WorldItems.pickup(d, stand, "paladin", finder, cell)
	check(not full.ok() and full.why == WorldItems.WHY_FULL, "a full inventory takes nothing (%s)" % full.why)
	var owner: Inventory = Inventory.new()
	var rest: WorldItems.Outcome = WorldItems.pickup(d, stand, "miner", owner, cell)
	for e: EditLog.WorldEdit in rest.edits:
		EditLog.apply_to_data(d, e)
	check(rest.ok() and d.drops_at(cell).is_empty() and d.get_value(WorldData.Layer.PLACEABLE, cell) == WorldData.PLACEABLE_NONE,
		"F takes the rest and the bag is gone")
	check(WorldItems.pickup(d, feet(c2 + Vector2i(0, 1)), "cleric", Inventory.new(), c2).ok(), "the other bag too (anyone may)")
	# Full map of drops (MAX_DROPS): the bag holds what still fits, the rest stays in the inventory.
	var crowded: WorldData = open_world(Vector2i(40, 40))
	for i: int in Config.MAX_DROPS - 2:
		var dr: WorldData.Drop = WorldData.Drop.new(crowded.new_drop_id(), &"stone_a", 1, 0, Vector2i(8 + (i % 30) * 16, 400 + (i / 30) * 16))
		crowded.drops[dr.id] = dr
	var many: Inventory = Inventory.new()
	kit(many)
	var o3: WorldItems.Outcome = WorldItems.death_drop(crowded, feet(Vector2i(5, 5)), many, Config.DEATH_DROP_HALF)
	var puts: int = 0
	for e: EditLog.WorldEdit in o3.edits:
		if e.kind == EditLog.Kind.DROP_PUT:
			puts += 1
	check_eq(puts, 2, "only MAX_DROPS fit: two stacks fall")
	check_eq(many.count_of(&"stone_a"), 15, "the first stack fell")
	check_eq(many.count_of(&"mushroom_a"), 7, "the last one stayed")
	# M4-fix: MAX_DROPS already on the ground: not even one fits, so no (empty) bag and nothing lost.
	for i: int in 2:
		var dr2: WorldData.Drop = WorldData.Drop.new(crowded.new_drop_id(), &"stone_a", 1, 0, Vector2i(8 + i * 16, 600))
		crowded.drops[dr2.id] = dr2
	check_eq(crowded.drops.size(), Config.MAX_DROPS, "the map holds MAX_DROPS drops")
	var none_fit: Inventory = Inventory.new()
	kit(none_fit)
	var o5: WorldItems.Outcome = WorldItems.death_drop(crowded, feet(Vector2i(20, 5)), none_fit, Config.DEATH_DROP_HALF)
	check(not o5.ok() and o5.why == WorldItems.WHY_TOO_MANY and o5.edits.is_empty() and o5.count == 0,
		"MAX_DROPS on the map: refused (%s), no bag edit" % o5.why)
	check(none_fit.count_of(&"stone_a") == 30 and none_fit.count_of(&"mushroom_a") == 7, "and nothing left the inventory")
	# No free tile near: no bag, nothing lost.
	var walled: WorldData = open_world(Vector2i(12, 12))
	for y: int in 12:
		for x: int in 12:
			if Vector2i(x, y) != Vector2i(6, 6):
				wall(walled, Vector2i(x, y))
	walled.set_value(WorldData.Layer.PLACEABLE, Vector2i(6, 6), WorldData.PLACEABLE_TORCH)
	var keep: Inventory = Inventory.new()
	kit(keep)
	var o4: WorldItems.Outcome = WorldItems.death_drop(walled, feet(Vector2i(6, 6)), keep, Config.DEATH_DROP_HALF)
	check(not o4.ok() and keep.count_of(&"stone_a") == 30, "no free tile: no bag, nothing lost (%s)" % o4.why)


## The bag is ordinary world data: the edits (a placeable tile + drop puts) through GameWorld.apply_edit
## draw it (the bag sprite, no drop icons), the late-join snapshot carries it, the content hash covers it.
func _check_bag_through_edits() -> void:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	add_node(w)
	w.generate(Config.DEFAULT_SEED)
	var copy: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var inv: Inventory = Inventory.new()
	kit(inv)
	var at: Vector2 = w.data.altar_center_px() + Vector2(0, 160)
	var o: WorldItems.Outcome = WorldItems.death_drop(w.data, at, inv, Config.DEATH_DROP_HALF)
	for e: EditLog.WorldEdit in o.edits:
		check(w.apply_edit(e), "edit applies (%s)" % e.describe())
		EditLog.apply_to_data(copy, e)
	var cell: Vector2i = o.edits[0].cell
	check_eq(w.data.content_hash(), copy.content_hash(), "the same edits on plain data give the same world")
	check_eq(w.fixtures.verify()["mismatches"], 0, "the bag is drawn (FixtureView)")
	check_eq(w.fixtures.verify()["bags"], 1, "one bag")
	check(w.fixtures.nodes.has(cell) and w.fixtures.nodes[cell].name == StringName("Bag_%d_%d" % [cell.x, cell.y]), "a bag node on its tile")
	check_eq(w.items.verify()["mismatches"], 0, "the drops in it are not drawn as icons")
	check_eq(w.items.drops.size(), 0, "no drop icon")
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(w.data)
	var back: WorldData = WorldSnapshot.unpack(packed.bytes, packed.raw_size)
	check(back != null and back.content_hash() == w.data.content_hash() and back.get_value(WorldData.Layer.PLACEABLE, cell) == WorldData.PLACEABLE_BAG,
		"the snapshot carries the bag and its drops")
	var take: WorldItems.Outcome = WorldItems.pickup(w.data, Arena.spawn_feet(cell + Vector2i(0, 1)), "archer", Inventory.new(), cell)
	for e: EditLog.WorldEdit in take.edits:
		w.apply_edit(e)
	check(w.fixtures.verify()["bags"] == 0 and w.fixtures.verify()["mismatches"] == 0 and w.items.verify()["mismatches"] == 0,
		"taken: the bag and its drops are gone from the picture")


# --- the shared simulation ---------------------------------------------------------------------------

## The same frames (walking, dashes, sword swings with aims, F held) and the same hits give the same
## state, vitals included, tick by tick: offline (Player.step_frame), the host (SessionHost.run_frame on a
## member, no transport) and a client's prediction (Prediction.step_frame), and a prediction replay.
func _check_shared_sim() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"CombatTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var start: Vector2 = world.data.altar_center_px() + Vector2(0, 140)
	var m: NetMember = s.add_member(2, 7, "paladin", start, RigData.Dir.SOUTH)
	m.gate = InputGate.new()
	m.player.inventory.add(&"sword", 1)
	var offline: Player = player(world.data, "paladin", start)
	offline.inventory.add(&"sword", 1)
	var pred: Prediction = Prediction.new()
	pred.setup(world.data, start, RigData.Dir.SOUTH, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	var mismatch: int = 0
	var first_bad: String = ""
	var dashes: int = 0
	var swings: int = 0
	var hits: int = 0
	var dir: Vector2i = Vector2i.ZERO
	# M4-fix: the prediction's state at the end of tick REPLAY_FROM and its next frame number (no hit or
	# revive comes after it: the hits fall on t % 97 == 50, the revives on t % 97 == 60).
	const REPLAY_FROM: int = 1418
	var replay_base: PlayerSim = null
	var replay_seq: int = 0
	for t: int in 1500:
		if t % 25 == 0:
			dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var f: NetProtocol.InputFrame = frame(dir, rng.randf() < 0.05, rng.randf() < 0.1)
		f.seq = t + 1
		if rng.randf() < 0.08:
			f.op = NetProtocol.Op.USE
			f.slot = 0
			var sector: int = rng.randi_range(0, 7)
			f.cell = Aim.target_cell(offline.sim_position, sector)
			f.aim = rng.randi_range(0, 255)
			f.look = Aim.facing(Vector2(Aim.SECTOR_OFFSETS[sector]), offline.facing)
		# Resolve the use like make_frame does (offline / prediction), the host resolves it itself.
		var local: NetProtocol.InputFrame = _copy_frame(f)
		if f.op == NetProtocol.Op.USE:
			local.anim = WorldItems.use_action(offline.sim_position, offline.inventory, 0, f.cell)
			local.item = &"sword" if local.anim >= 0 else &""
			if offline.to_sim().busy_next():
				local.anim = -1
		var before: int = offline.vitals.dash_cooldown
		tick(offline, local)
		if offline.vitals.dash_ticks == Config.DASH_TICKS - 1 and before == 0:
			dashes += 1
		if offline.action_anim >= 0 and offline.action_tick == 0:
			swings += 1
		m.player.begin_tick()
		host.run_frame(m, _copy_frame(f))
		pred.step_frame(_copy_frame(local))
		if t % 97 == 50:
			var dmg: int = rng.randi_range(5, 30)
			var a: int = offline.take_hit(dmg)
			var b: int = m.player.take_hit(dmg)
			var c: int = pred.sim.hurt(dmg)
			if a != 0:
				hits += 1
			if a != b or a != c:
				mismatch += 1
		if offline.vitals.life != Vitals.Life.ALIVE and t % 97 == 60:
			# Back up (as a revive would) so the run keeps moving.
			offline.revive_now()
			m.player.revive_now()
			pred.sim.revive()
		var so: PlayerSim = offline.to_sim()
		if not so.same_all(m.player.to_sim()) or not so.same_all(pred.sim):
			mismatch += 1
			if first_bad.is_empty():
				first_bad = "tick %d: offline %s / host %s / pred %s" % [t, so.vit.describe(), m.player.vitals.describe(), pred.sim.vit.describe()]
		if t == REPLAY_FROM:
			replay_base = pred.sim.copy()
			replay_seq = pred.next_seq
	check_eq(mismatch, 0, "offline == host == prediction every tick, vitals included %s" % first_bad)
	check(dashes > 10 and swings > 10 and hits > 5, "the run dashed, swung and took hits (%d, %d, %d)" % [dashes, swings, hits])
	# M4-fix (the check was only "a base exists"): a prediction replay (Prediction._replay, what reconcile
	# runs on a host state) of the frames recorded after tick REPLAY_FROM, from the state then, lands on the
	# prediction's state now, vitals included.
	var again: Prediction = Prediction.new()
	again.data = pred.data
	again.map = pred.map
	var replayed_frames: int = 0
	for pd: Prediction.Pending in pred.pending:
		if pd.frame.seq >= replay_seq:
			var copy: Prediction.Pending = Prediction.Pending.new()
			copy.frame = pd.frame
			again.pending.append(copy)
			replayed_frames += 1
	if check(replay_base != null and replayed_frames > 20, "frames to replay after tick %d (%d)" % [REPLAY_FROM, replayed_frames]):
		again._replay(replay_base)
		check(again.sim.same_all(pred.sim), "the replay of %d frames lands on the predicted state (%s / %s)" % [replayed_frames,
			again.sim.vit.describe(), pred.sim.vit.describe()])
	note("shared sim: 1500 ticks, %d dashes, %d swings, %d hits, no mismatch" % [dashes, swings, hits])


static func _copy_frame(f: NetProtocol.InputFrame) -> NetProtocol.InputFrame:
	var c: NetProtocol.InputFrame = NetProtocol.InputFrame.new(f.seq, f.dir)
	c.look = f.look
	c.op = f.op
	c.slot = f.slot
	c.cell = f.cell
	c.map = f.map
	c.anim = f.anim
	c.item = f.item
	c.dash = f.dash
	c.interact = f.interact
	c.aim = f.aim
	return c


# --- main.tscn offline -------------------------------------------------------------------------------

## main.tscn offline: the class weapon in hotbar 8; a sword swing kills a heretic standing next to the
## player outside the light; downed alone, F held gives up; the bag lies on the death tile; the
## respawn puts the player back at spawn slot 0 on the surface, full; F there takes the bag back.
func _check_main_offline() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null and main.arenas.size() == 2 and main.combat_views.size() == 2, "main has a player and two arenas"):
		return
	check_eq(p.inventory.stack_at(Config.START_WEAPON_SLOT).id, &"sword", "the paladin starts with the sword in hotbar 8")
	check(main.hud.player == p, "the HUD shows the local player's vitals")
	p.local_input = false
	var data: WorldData = main.world.data
	var out: Vector2 = data.altar_center_px() + Vector2(0, Config.safe_radius_px() + 40.0)
	p.teleport(out)
	var arena: Arena = main.arenas[Config.MAP_SURFACE]
	arena.spawning = false
	var h: HereticSim = arena.spawn_heretic(out + Vector2(14, 0))
	p.inventory.select(Config.START_WEAPON_SLOT)
	var east: Vector2 = out + Vector2(40, 0)
	var swings: int = 0
	for t: int in 400:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, east, true, false, true, TICK)
		main.step_combat(TICK)
		if p.action_anim >= 0 and p.action_tick == 0:
			swings += 1
		if not h.alive():
			break
	check(not h.alive(), "held left click with the sword kills the heretic (%d swings)" % swings)
	check(main.combat_views[Config.MAP_SURFACE].heretics.has(h.id), "its corpse is drawn")
	check(p.vitals.hp < Config.PLAYER_HP_MAX, "it hit back first (hp %d)" % p.vitals.hp)
	# Dying alone: down, F held gives up, the bag, the respawn.
	p.inventory.add(&"stone_a", 20)
	p.inventory.add(&"wild_buff", 3)
	p.take_hit(Config.PLAYER_HP_MAX)
	var spot: Vector2 = p.sim_position
	check_eq(p.vitals.life, Vitals.Life.DOWN, "down")
	var lying: WorldData.Drop = WorldData.Drop.new(data.new_drop_id(), &"stone_b", 2, 0,
		Aim.target_cell(p.sim_position, p.aim_sector) * Config.TILE + Vector2i(8, 8))
	data.drops[lying.id] = lying
	main.pick_up()
	check(data.drops.has(lying.id), "down: F picks nothing up")
	data.drops.erase(lying.id)
	for t: int in Config.GIVE_UP_HOLD_TICKS:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, east, false, false, false, TICK, false, true)
		main.step_combat(TICK)
	check_eq(p.vitals.life, Vitals.Life.DEAD, "F held gives up")
	var bag: Vector2i = Aim.feet_cell(spot)
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, bag), WorldData.PLACEABLE_BAG, "the bag on the death tile")
	check_eq(p.inventory.count_of(&"stone_a"), 10, "half the stones went into it")
	check_eq(p.inventory.count_of(&"sword"), 1, "the sword stays")
	check(main.world.fixtures.nodes.has(bag), "the bag is drawn")
	for t: int in Config.RESPAWN_TICKS:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, east, false, false, false, TICK)
		main.step_combat(TICK)
	check(p.vitals.alive() and p.vitals.hp == Config.RESPAWN_HP, "respawned full after RESPAWN_TICKS")
	check_eq(p.sim_position, main.world.spawn_point(0), "at spawn slot 0 by the altar")
	check(main.world.is_in_safe_zone(p.sim_position), "inside the light")
	p.teleport(Arena.spawn_feet(bag + Vector2i(-1, 0)))
	p.test_aim = Vector2(16, 0)
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, p.mouse_world(), true, false, false, TICK)
	main.pick_up()
	check(p.inventory.count_of(&"stone_a") == 20 and data.get_value(WorldData.Layer.PLACEABLE, bag) == WorldData.PLACEABLE_NONE,
		"F on the bag takes it all back")
	# Dying in the dungeon: the respawn is still at the altar on the surface; the bag stays below.
	check(main.travel(Config.MAP_DUNGEON), "down to the dungeon")
	p.inventory.add(&"ore_iron", 4)
	p.take_hit(Config.PLAYER_HP_MAX)
	var below: Vector2i = Aim.feet_cell(p.sim_position)
	for t: int in Config.GIVE_UP_HOLD_TICKS + Config.RESPAWN_TICKS:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, p.mouse_world(), false, false, false, TICK, false, true)
		main.step_combat(TICK)
	check(main.current_map == Config.MAP_SURFACE and p.data == data and p.sim_position == main.world.spawn_point(0),
		"died in the dungeon: back at the surface altar")
	check_eq(main.worlds[Config.MAP_DUNGEON].data.get_value(WorldData.Layer.PLACEABLE, below), WorldData.PLACEABLE_BAG,
		"the bag stays in the dungeon")
	check_eq(main.camera.target, p, "the camera follows the respawned player")
