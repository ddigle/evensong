extends "res://tests/base_test.gd"
## M6a, potions and effects (offline first): drinking (Config.DRINK_*: the HP cap, refused at full HP, not
## while down, the buff and its duration, the poison potion harms), the buff on walking speed (the dash
## untouched), poison on players (ticks, no stagger, invulnerability does not stop it, death by poison, effects
## end on down and respawn) and on heretics (ticks, no stagger, death counted like any kill, logged for the
## thrower), the herbalist's throw (range, walls, the splash area, allies vs enemies, friendly fire off, bodies
## do not stop it, controls), the shared simulation with effects (offline == host == prediction) and
## main.tscn (drink with a click, throw with key 1, the marks over heads and in the HUD).

const SessionHostScript := preload("res://net/session_host.gd")
const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_drink_rules()
	_check_drink_controls()
	_check_buff_speed()
	_check_player_poison()
	_check_heretic_poison()
	_check_throw_flight()
	_check_splash()
	_check_throw_controls()
	_check_marks()
	_check_shared_sim()
	_check_release_refusals()
	_check_effect_edges()
	await _check_main_flow()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------

## An open dungeon-kind map (no altar, so no light).
static func open_world(size: Vector2i = Vector2i(40, 30)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_DUNGEON
	return d


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.potions_on = true
	_nodes.append(p)
	return p


static func tick(p: Player, f: NetProtocol.InputFrame = null) -> int:
	p.begin_tick()
	return p.step_frame(f if f != null else NetProtocol.InputFrame.new(), TICK)


static func step_sim(s: PlayerSim, d: WorldData, dir: Vector2i = Vector2i.ZERO, dash: bool = false) -> int:
	return s.step(d, dir, -1, -1, Vector2i.ZERO, TICK, dash)


static func arena_for(d: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	return a


# --- drinking ---------------------------------------------------------------------------------------

func _check_drink_rules() -> void:
	var v: Vitals = Vitals.new()
	check_eq(Potions.drink_refusal(&"potion_healing", ItemDB.Grade.COMMON, v), "" if Config.DRINK_AT_FULL_HP else Potions.WHY_FULL_HP,
		"healing at full HP (Config.DRINK_AT_FULL_HP)")
	v.hp = 40
	check_eq(Potions.drink_refusal(&"potion_healing", ItemDB.Grade.COMMON, v), "", "healing when hurt")
	check_eq(Potions.drink_refusal(&"potion_buff", ItemDB.Grade.COMMON, Vitals.new()), "", "the buff at full HP")
	check_eq(Potions.drink_refusal(&"potion_poison", ItemDB.Grade.COMMON, Vitals.new()),
		"" if Config.DRINK_POISON_HARMS else Potions.WHY_NOT_DRINKABLE, "poison (Config.DRINK_POISON_HARMS)")
	v.life = Vitals.Life.DOWN
	check_eq(Potions.drink_refusal(&"potion_healing", ItemDB.Grade.COMMON, v), Potions.WHY_NOT_UP, "not while down")
	check_eq(Potions.drink_refusal(&"sword", ItemDB.Grade.NONE, Vitals.new()), Potions.WHY_NOT_POTION, "a sword is no potion")
	# Healing: by grade, capped at the maximum.
	for g: int in [ItemDB.Grade.COMMON, ItemDB.Grade.FINE]:
		var s: PlayerSim = PlayerSim.new()
		s.vit.hp = 10
		check_eq(Potions.apply(s, &"potion_healing", g), PlayerSim.HEALED, "heals (%s)" % ItemDB.GRADE_NAMES[g])
		check_eq(s.vit.hp, 10 + Config.POTION_HEAL_HP[g], "by POTION_HEAL_HP[%s]" % ItemDB.GRADE_NAMES[g])
	var cap: PlayerSim = PlayerSim.new()
	cap.vit.hp = Config.PLAYER_HP_MAX - 5
	Potions.apply(cap, &"potion_healing", ItemDB.Grade.FINE)
	check_eq(cap.vit.hp, Config.PLAYER_HP_MAX, "never past the maximum")
	check_eq(Potions.apply(cap, &"potion_healing", ItemDB.Grade.FINE), 0, "at full HP it does nothing")
	var down: PlayerSim = PlayerSim.new()
	down.hurt(Config.PLAYER_HP_MAX)
	check_eq(Potions.apply(down, &"potion_healing", ItemDB.Grade.FINE), 0, "a downed player is not healed (F revives)")
	check_eq(down.vit.hp, 0, "still 0")
	# The buff: percent and duration by grade, counts down to none; refresh keeps the stronger.
	var d: WorldData = open_world()
	for g2: int in [ItemDB.Grade.COMMON, ItemDB.Grade.FINE]:
		var b: PlayerSim = PlayerSim.new()
		b.pos = Arena.spawn_feet(Vector2i(10, 10))
		check_eq(Potions.apply(b, &"potion_buff", g2), PlayerSim.BUFFED, "buffs (%s)" % ItemDB.GRADE_NAMES[g2])
		check_eq([b.vit.buff_pct, b.vit.buff_ticks], [Config.BUFF_SPEED_PCT[g2], Config.BUFF_TICKS[g2]], "pct and ticks")
		var lasted: int = 0
		while b.vit.buffed() and lasted < 10000:
			step_sim(b, d)
			lasted += 1
		check_eq(lasted, Config.BUFF_TICKS[g2], "it lasts BUFF_TICKS ticks exactly")
		check_eq(b.vit.buff_pct, 100, "then it is gone")
	var r: PlayerSim = PlayerSim.new()
	r.add_buff(Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE], 100)
	r.add_buff(Config.BUFF_SPEED_PCT[ItemDB.Grade.COMMON], 500)
	if Config.EFFECT_REFRESH_KEEPS_STRONGER:
		check_eq([r.vit.buff_pct, r.vit.buff_ticks], [Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE], 500],
			"a second buff: the longer time and the larger percent")
	# The poison potion drunk poisons the drinker.
	var tox: PlayerSim = PlayerSim.new()
	check_eq(Potions.apply(tox, &"potion_poison", ItemDB.Grade.COMMON), PlayerSim.POISONED, "drunk poison poisons")
	check_eq([tox.vit.poison_damage, tox.vit.poison_ticks], [Config.POISON_DAMAGE[1], Config.POISON_TICKS[1]], "its numbers")


## make_frame: a click with a potion drinks it (the drink action), held does not repeat; it works on the
## effect frame (Potions.impact_tick) and only then; refused at full HP; off without potions_on.
func _check_drink_controls() -> void:
	var d: WorldData = open_world()
	var p: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	p.inventory.add(&"potion_healing", 3, ItemDB.Grade.FINE)
	var refused: Array[String] = []
	p.potion_refused.connect(func(what: String, why: String) -> void: refused.append("%s:%s" % [what, why]))
	var east: Vector2 = p.sim_position + Vector2(30, 0)
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, east, true, true, true)
	check_eq(f.op, NetProtocol.Op.NONE, "at full HP the click drinks nothing")
	check_eq(refused, ["drink:%s" % Potions.WHY_FULL_HP] as Array[String], "refused: full hp")
	p.vitals.hp = 20
	var impacts: Array[int] = []
	p.action_impact.connect(func(_item: StringName, _anim: int, _c: Vector2i) -> void: impacts.append(p.action_tick))
	f = p.make_frame(Vector2i.ZERO, east, true, true, true)
	check(f.op == NetProtocol.Op.USE and f.anim == Config.DRINK_ANIM and f.item == &"potion_healing",
		"a click with a potion: the drink action")
	tick(p, f)
	check_eq(p.action_anim, Config.DRINK_ANIM, "drinking")
	check_eq([p.action_slot, p.action_grade], [0, ItemDB.Grade.FINE], "which stack: slot 0, FINE")
	var held: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, east, true, false, true)
	check_eq(held.op, NetProtocol.Op.NONE, "held: no second drink queued")
	for t: int in PlayerSim.action_ticks(Config.DRINK_ANIM):
		tick(p, p.make_frame(Vector2i.ZERO, east, true, false, true))
	check_eq(impacts, [Potions.impact_tick(Config.DRINK_ANIM)] as Array[int], "the effect frame comes once")
	check_eq(Potions.impact_tick(Config.DRINK_ANIM), Config.DRINK_EFFECT_FRAME * Config.ACTION_FRAME_TICKS, "DRINK_EFFECT_FRAME")
	check_eq(Potions.impact_tick(RigData.Anim.THROW), Config.THROW_RELEASE_FRAME * Config.ACTION_FRAME_TICKS, "THROW_RELEASE_FRAME")
	# Off in sessions until M6b.
	p.potions_on = false
	check_eq(p.make_frame(Vector2i.ZERO, east, true, true, true).op, NetProtocol.Op.NONE, "potions off: nothing")
	check_eq(p.make_frame(Vector2i.ZERO, east, true, false, false, false, false, true).op, NetProtocol.Op.NONE,
		"potions off: no throw either")
	# Down: no drink (no action starts).
	p.potions_on = true
	p.take_hit(Config.PLAYER_HP_MAX)
	check_eq(p.make_frame(Vector2i.ZERO, east, true, true, true).op, NetProtocol.Op.NONE, "down: no drink")
	# Potions.take_one: from the slot, else the first stack of it; none left = false.
	var inv: Inventory = Inventory.new()
	inv.add(&"potion_buff", 2)
	inv.add(&"potion_buff", 1, ItemDB.Grade.FINE)
	check(Potions.take_one(inv, 1, &"potion_buff", ItemDB.Grade.FINE) and inv.stack_at(1) == null, "from its slot")
	check(Potions.take_one(inv, 5, &"potion_buff", ItemDB.Grade.COMMON) and inv.count_of(&"potion_buff") == 1,
		"moved: from the first stack of it")
	check(not Potions.take_one(inv, 0, &"potion_buff", ItemDB.Grade.FINE), "none of that grade left")


func _check_buff_speed() -> void:
	var d: WorldData = open_world(Vector2i(80, 30))
	var plain: PlayerSim = PlayerSim.new()
	var fast: PlayerSim = PlayerSim.new()
	plain.pos = Arena.spawn_feet(Vector2i(5, 10))
	fast.pos = plain.pos
	fast.add_buff(Config.BUFF_SPEED_PCT[ItemDB.Grade.COMMON], 600)
	for t: int in 120:
		step_sim(plain, d, Vector2i(1, 0))
		step_sim(fast, d, Vector2i(1, 0))
	var a: float = plain.pos.x - Arena.spawn_feet(Vector2i(5, 10)).x
	var b: float = fast.pos.x - Arena.spawn_feet(Vector2i(5, 10)).x
	check_between(a, 143.9, 144.1, "plain: WALK_SPEED for 2 s")
	check_between(b / a, Config.BUFF_SPEED_PCT[ItemDB.Grade.COMMON] / 100.0 - 0.001,
		Config.BUFF_SPEED_PCT[ItemDB.Grade.COMMON] / 100.0 + 0.001, "the buff walks BUFF_SPEED_PCT faster (%.2f / %.2f)" % [b, a])
	check_eq(fast.walk_speed(), Config.WALK_SPEED * Config.BUFF_SPEED_PCT[ItemDB.Grade.COMMON] / 100.0, "walk_speed()")
	# The dash is not buffed.
	var d1: PlayerSim = PlayerSim.new()
	var d2: PlayerSim = PlayerSim.new()
	d1.pos = Arena.spawn_feet(Vector2i(5, 20))
	d2.pos = d1.pos
	d2.add_buff(Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE], 600)
	step_sim(d1, d, Vector2i(1, 0), true)
	step_sim(d2, d, Vector2i(1, 0), true)
	for t2: int in Config.DASH_TICKS - 1:
		step_sim(d1, d)
		step_sim(d2, d)
	check_eq(d2.pos, d1.pos, "a dash goes as far with the buff")


func _check_player_poison() -> void:
	var d: WorldData = open_world()
	var s: PlayerSim = PlayerSim.new()
	s.pos = Arena.spawn_feet(Vector2i(10, 10))
	var g: int = ItemDB.Grade.COMMON
	s.add_poison(Config.POISON_DAMAGE[g], Config.POISON_TICKS[g])
	var hits_at: Array[int] = []
	var hp0: int = s.vit.hp
	var t: int = 0
	while s.vit.poisoned() and t < 10000:
		t += 1
		var ev: int = step_sim(s, d, Vector2i(1, 0))
		if ev & PlayerSim.POISON_TICK:
			hits_at.append(t)
	var want: Array[int] = []
	for k: int in range(Config.POISON_INTERVAL_TICKS, Config.POISON_TICKS[g] + 1, Config.POISON_INTERVAL_TICKS):
		want.append(k)
	check_eq(hits_at, want, "a poison tick every POISON_INTERVAL_TICKS for POISON_TICKS")
	check_eq(hp0 - s.vit.hp, want.size() * Config.POISON_DAMAGE[g], "POISON_DAMAGE each")
	check_eq(s.vit.hurt_ticks, 0, "no stagger")
	check_eq(s.vit.invuln_ticks, 0, "no invulnerability")
	check(s.pos.x > Arena.spawn_feet(Vector2i(10, 10)).x + 100.0, "it kept walking all along")
	# Invulnerability (a dash, after a hit) does not stop it; an action goes on.
	var inv: PlayerSim = PlayerSim.new()
	inv.pos = Arena.spawn_feet(Vector2i(10, 15))
	inv.add_poison(5, 60)
	inv.hurt(10)
	check(inv.vit.invulnerable(), "setup: invulnerable after a hit")
	var hp1: int = inv.vit.hp
	for t2: int in Config.POISON_INTERVAL_TICKS:
		step_sim(inv, d)
	check_eq(hp1 - inv.vit.hp, 5, "the poison tick lands through the invulnerability")
	var act: PlayerSim = PlayerSim.new()
	act.pos = Arena.spawn_feet(Vector2i(10, 20))
	act.add_poison(1, 120)
	act.step(d, Vector2i.ZERO, -1, RigData.Anim.SWORD, Vector2i(11, 20), TICK)
	for t3: int in Config.POISON_INTERVAL_TICKS:
		step_sim(act, d)
	check(act.action == RigData.Anim.SWORD and act.vit.hp == Config.PLAYER_HP_MAX - 1, "a swing goes on through a poison tick")
	# Death by poison: down at 0, the effects end; then dead after DOWN_TICKS like any down.
	var dying: PlayerSim = PlayerSim.new()
	dying.pos = Arena.spawn_feet(Vector2i(15, 10))
	dying.vit.hp = Config.POISON_DAMAGE[ItemDB.Grade.FINE] * 2
	dying.add_buff(140, 5000)
	dying.add_poison(Config.POISON_DAMAGE[ItemDB.Grade.FINE], Config.POISON_TICKS[ItemDB.Grade.FINE])
	var downed_at: int = -1
	for t4: int in 200:
		var ev2: int = step_sim(dying, d)
		if ev2 & PlayerSim.DOWNED:
			downed_at = t4 + 1
			break
	check_eq(downed_at, 2 * Config.POISON_INTERVAL_TICKS, "down on the second poison tick")
	check_eq(dying.vit.life, Vitals.Life.DOWN, "down")
	check(not dying.vit.poisoned() and not dying.vit.buffed(), "the effects end on down (Config.EFFECTS_END_ON_DOWN)")
	var died: bool = false
	for t5: int in Config.DOWN_TICKS:
		died = died or step_sim(dying, d) & PlayerSim.DIED != 0
	check(died and dying.vit.life == Vitals.Life.DEAD, "then dead after DOWN_TICKS")
	# A hit to 0 ends them too; a respawn has none; nothing lands while down.
	var hit: PlayerSim = PlayerSim.new()
	hit.add_buff(125, 999)
	hit.add_poison(2, 300)
	hit.hurt(Config.PLAYER_HP_MAX)
	check(not hit.vit.buffed() and not hit.vit.poisoned(), "down by a hit: effects gone")
	check(not hit.add_poison(2, 300) and not hit.add_buff(125, 10), "no effect lands while down")
	hit.revive()
	hit.add_poison(2, 300)
	hit.respawn(Vector2(100, 100))
	check(not hit.vit.poisoned() and hit.vit.at_rest(), "a respawn clears them")
	# Player.step_frame reports a poison tick as a hurt (log, HUD).
	var pl: Player = player(d, "cleric", Arena.spawn_feet(Vector2i(20, 10)))
	var hurts: Array[int] = []
	pl.hurt.connect(func(amount: int, _down: bool) -> void: hurts.append(amount))
	pl.apply_potion(&"potion_poison", ItemDB.Grade.FINE)
	for t6: int in Config.POISON_INTERVAL_TICKS:
		tick(pl)
	check_eq(hurts, [Config.POISON_DAMAGE[ItemDB.Grade.FINE]] as Array[int], "the poison tick is a hurt signal of its damage")


func _check_heretic_poison() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	a.logging = true
	var h: HereticSim = a.spawn_heretic(Arena.spawn_feet(Vector2i(10, 10)))
	var g: int = ItemDB.Grade.COMMON
	check(a.poison_heretic(h, Config.POISON_DAMAGE[g], Config.POISON_TICKS[g], 77), "poisoned")
	var none: Array[Player] = []
	var states: Array[int] = []
	for t: int in Config.POISON_TICKS[g]:
		a.step(none)
		states.append(h.state)
	check_eq(h.hp, Config.HERETIC_HP - (Config.POISON_TICKS[g] / Config.POISON_INTERVAL_TICKS) * Config.POISON_DAMAGE[g],
		"HERETIC_HP less ten poison ticks")
	check(not h.poisoned() and h.poison_damage == 0, "it wore off")
	check(not states.has(HereticSim.State.HURT), "a poison tick does not stagger it")
	check_eq(a.stat("poison_hits"), Config.POISON_TICKS[g] / Config.POISON_INTERVAL_TICKS, "counted")
	check_eq(a.stat("heretic_hits"), 0, "not as weapon hits")
	check_eq(a.hits.size(), 10, "logged for the host (Hit records)")
	check(a.hits[0].by_id == 77 and a.hits[0].amount == Config.POISON_DAMAGE[g], "by the thrower")
	# Death by poison: counted like any kill, the last record says KILLED for the thrower.
	a.hits.clear()
	h.hp = 3
	a.poison_heretic(h, 2, 300, 88)
	var killed_at: int = -1
	for t2: int in 120:
		a.step(none)
		if not h.alive():
			killed_at = t2 + 1
			break
	check_eq(killed_at, 2 * Config.POISON_INTERVAL_TICKS, "dies on the second poison tick")
	check_eq(a.stat("killed"), 1, "a kill like any other")
	check_eq(a.stat("poison_kills"), 1, "by poison")
	var last: Arena.Hit = a.hits.back() if not a.hits.is_empty() else null
	check(last != null and last.killed and last.by_id == 88, "the kill is the thrower's")
	check(not h.poisoned(), "a dead heretic's poison ends")
	check(not a.poison_heretic(h, 2, 300), "a dead one is not poisoned again")
	# An attack it started goes on through a poison tick (no stagger), and refresh keeps the stronger.
	var b: HereticSim = a.spawn_heretic(Arena.spawn_feet(Vector2i(20, 10)))
	b.state = HereticSim.State.ATTACK
	b.state_ticks = 0
	b.attack_dir = Vector2.RIGHT
	a.poison_heretic(b, 3, 300)
	a.poison_heretic(b, 1, 900)
	if Config.EFFECT_REFRESH_KEEPS_STRONGER:
		check_eq([b.poison_damage, b.poison_ticks], [3, 900], "a second poison: the larger damage, the longer time")
	for t3: int in Config.POISON_INTERVAL_TICKS:
		a.step(none)
	check(b.state == HereticSim.State.ATTACK and b.hp == Config.HERETIC_HP - 3, "the attack goes on, 3 off")
	a.on_emptied()
	check(b.poisoned(), "an emptied map keeps its heretics' poison (it ticks when the map runs again)")


## The bottle: range clamp, flight time, walls stop it, bodies do not.
func _check_throw_flight() -> void:
	var d: WorldData = open_world(Vector2i(60, 30))
	var a: Arena = arena_for(d)
	var p: Player = player(d, "herbalist", Arena.spawn_feet(Vector2i(10, 10)))
	var origin: Vector2 = Combat.body_point(p.sim_position)
	check_eq(Potions.throw_target(origin, origin + Vector2(300, 0)), origin + Vector2(Config.THROW_RANGE_PX, 0),
		"clamped to THROW_RANGE_PX")
	check_eq(Potions.throw_target(origin, origin + Vector2(30, 40)), origin + Vector2(30, 40), "nearer: where the mouse is")
	var f: Arena.Flask = a.throw_potion(p, &"potion_buff", ItemDB.Grade.COMMON, origin + Vector2(300, 0))
	check_eq(f.target, origin + Vector2(Config.THROW_RANGE_PX, 0), "the flask's target is clamped too")
	var none: Array[Player] = []
	var ticks: int = 0
	while not f.done and ticks < 300:
		a.step(none)
		ticks += 1
	check_eq(ticks, ceili((Config.THROW_RANGE_PX - Arena.FLASK_ARRIVE_PX) / (Config.THROW_SPEED / Config.NET_TICK_RATE)),
		"flight ticks = range / speed")
	check(f.stopped_by == "landed" and f.pos == f.target, "landed on its target")
	check_eq(a.splashes.size(), 1, "a splash")
	check(a.flasks.is_empty(), "no bottle left")
	# A wall in the way: it breaks just before it.
	var wall: Vector2i = Vector2i(14, 9)
	for y: int in range(8, 12):
		d.set_value(WorldData.Layer.WALL, Vector2i(14, y), Walls.pack(Walls.KIND_ROCK, 0))
	var g: Arena.Flask = a.throw_potion(p, &"potion_poison", ItemDB.Grade.COMMON, origin + Vector2(80, 0))
	var behind: HereticSim = a.spawn_heretic(Arena.spawn_feet(Vector2i(16, 10)))
	for t: int in 120:
		a.step(none)
	check_eq(g.stopped_by, "wall", "stopped by the wall")
	check(g.pos.x <= wall.x * Config.TILE and g.pos.x > wall.x * Config.TILE - 4.0, "just before it (x %.1f)" % g.pos.x)
	check(not behind.poisoned(), "the heretic behind the wall is untouched")
	# A heretic in the way does not stop it (lobbed): it lands beyond.
	var e: WorldData = open_world(Vector2i(60, 30))
	var b: Arena = arena_for(e)
	var q: Player = player(e, "herbalist", Arena.spawn_feet(Vector2i(10, 20)))
	var o2: Vector2 = Combat.body_point(q.sim_position)
	var mid: HereticSim = b.spawn_heretic(Arena.spawn_feet(Vector2i(12, 20)))
	var far: HereticSim = b.spawn_heretic(q.sim_position + Vector2(80, 0))
	var h: Arena.Flask = b.throw_potion(q, &"potion_poison", ItemDB.Grade.COMMON, o2 + Vector2(80, 0))
	for t2: int in 120:
		b.step(none)
	check(h.stopped_by == "landed" and far.poisoned() and not mid.poisoned(), "over the near heretic onto the far one")
	b.on_emptied()
	check(b.flasks.is_empty() and b.splashes.is_empty(), "an emptied map has no bottle or splash")


## The splash: who it reaches (radius, walls), healing and the buff on players up (the thrower too), poison
## on heretics only (friendly fire off).
func _check_splash() -> void:
	var d: WorldData = open_world(Vector2i(60, 40))
	var a: Arena = arena_for(d)
	var thrower: Player = player(d, "herbalist", Arena.spawn_feet(Vector2i(10, 10)))
	# 60 px south of the thrower, 2 px east of a tile's west edge (x 162: the wall column 9 is 144..160).
	var at: Vector2 = Combat.body_point(thrower.sim_position) + Vector2(-6, 60)
	var r: float = Config.THROW_SPLASH_RADIUS_PX
	var inside: Player = player(d, "paladin", at + Vector2(r - 2.0, 2.0))
	var edge_out: Player = player(d, "archer", at + Vector2(0, r + 4.0))
	var downed: Player = player(d, "cleric", at + Vector2(-6, 2))
	downed.take_hit(Config.PLAYER_HP_MAX)
	for p: Player in [thrower, inside, edge_out]:
		p.vitals.hp = 50
	var players: Array[Player] = [thrower, inside, edge_out, downed]
	var f: Arena.Flask = a.throw_potion(thrower, &"potion_healing", ItemDB.Grade.COMMON, at)
	for t: int in 60:
		a.step(players)
	check(f.done, "landed")
	var heal: int = Config.POTION_HEAL_HP[ItemDB.Grade.COMMON]
	check_eq(inside.vitals.hp, 50 + heal, "healing: a player within the radius")
	check_eq(edge_out.vitals.hp, 50, "not one beyond it")
	check_eq(thrower.vitals.hp, 50, "not the thrower 60 px away")
	check_eq(downed.vitals.hp, 0, "not a downed one (F revives)")
	check_eq(a.stat("splash_players"), 1, "one player reached")
	# On the thrower's own feet: it heals the thrower too.
	var self_f: Arena.Flask = a.throw_potion(thrower, &"potion_healing", ItemDB.Grade.FINE, Combat.body_point(thrower.sim_position))
	a.step(players)
	check(self_f.done and thrower.vitals.hp == 50 + Config.POTION_HEAL_HP[ItemDB.Grade.FINE], "a splash at its feet heals the thrower")
	# The buff on players.
	a.throw_potion(thrower, &"potion_buff", ItemDB.Grade.FINE, at)
	for t2: int in 60:
		a.step(players)
	check(inside.vitals.buffed() and inside.vitals.buff_pct == Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE], "the buff splash buffs")
	check(not edge_out.vitals.buffed(), "not beyond the radius")
	# Poison: heretics in the radius, never the players (friendly fire off), not through a wall.
	var near: HereticSim = a.spawn_heretic(at + Vector2(r - 3.0, 2.0))
	var away: HereticSim = a.spawn_heretic(at + Vector2(r + 6.0, 2.0))
	var walled: HereticSim = a.spawn_heretic(at + Vector2(-19.0, 2.0))  # body 19 px west, in column 8
	var wall_c: Vector2i = Aim.cell_of(at + Vector2(-10, 0))
	check_eq(wall_c.x, 9, "setup: the wall column between")
	for y: int in range(wall_c.y - 1, wall_c.y + 2):
		d.set_value(WorldData.Layer.WALL, Vector2i(wall_c.x, y), Walls.pack(Walls.KIND_ROCK, 0))
	a.throw_potion(thrower, &"potion_poison", ItemDB.Grade.COMMON, at)
	for t3: int in 60:
		a.step(players)
	check(near.poisoned(), "the poison splash poisons a heretic within the radius")
	check(not away.poisoned(), "not one beyond it")
	check(not walled.poisoned(), "not one behind a wall")
	check_eq(Config.FRIENDLY_FIRE, false, "friendly fire is off")
	check(not inside.vitals.poisoned() and not thrower.vitals.poisoned(), "players are never poisoned by a splash")
	check_eq(a.stat("splash_heretics"), 1, "one heretic reached")
	check(a.in_splash(at, at + Vector2(0, 2)) and not a.in_splash(at, at + Vector2(0, r + 3.0)), "in_splash: radius")
	# The splash shows SPLASH_SHOW_TICKS, then goes.
	var b: Arena = arena_for(open_world())
	b.throw_potion(thrower, &"potion_buff", ItemDB.Grade.COMMON, Combat.body_point(thrower.sim_position))
	var empty: Array[Player] = []
	b.step(empty)
	var shown: int = 0
	while not b.splashes.is_empty() and shown < 100:
		b.step(empty)
		shown += 1
	check_eq(shown, Config.SPLASH_SHOW_TICKS, "shown SPLASH_SHOW_TICKS ticks (the landing tick and the ones after, gone on the next)")


func _check_throw_controls() -> void:
	var d: WorldData = open_world()
	var herb: Player = player(d, "herbalist", Arena.spawn_feet(Vector2i(10, 10)))
	herb.inventory.add(&"potion_poison", 2, ItemDB.Grade.FINE)
	var far_mouse: Vector2 = herb.sim_position + Vector2(200, -40)
	var f: NetProtocol.InputFrame = herb.make_frame(Vector2i.ZERO, far_mouse, true, false, false, false, false, true)
	check(f.op == NetProtocol.Op.THROW and f.anim == RigData.Anim.THROW and f.item == &"potion_poison",
		"key 1: the throw action (M6b: a THROW request, M6a's was a USE)")
	var origin: Vector2 = Combat.body_point(herb.sim_position)
	# M6-fix: in whole px (what the wire carries), so offline throws at the host's point; the arena clamps it again.
	check(f.throw_to == Potions.throw_target(origin, far_mouse).round() and absf(f.throw_to.distance_to(origin) - Config.THROW_RANGE_PX) < 1.0,
		"toward the mouse, at most THROW_RANGE_PX, in whole px (%s)" % f.throw_to)
	tick(herb, f)
	check_eq(herb.action_anim, RigData.Anim.THROW, "throwing (base_body_v02_throw)")
	check_eq(herb.action_target, f.throw_to, "it remembers where")
	check_eq(herb.facing, RigData.Dir.EAST, "facing the mouse")
	var refused: Array[String] = []
	var pal: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(20, 10)))
	pal.potion_refused.connect(func(what: String, why: String) -> void: refused.append("%s:%s" % [what, why]))
	pal.inventory.add(&"potion_poison", 1)
	var g: NetProtocol.InputFrame = pal.make_frame(Vector2i.ZERO, far_mouse, true, false, false, false, false, true)
	check_eq(g.op, NetProtocol.Op.NONE if Config.THROW_HERBALIST_ONLY else NetProtocol.Op.THROW,
		"a paladin's key 1 (Config.THROW_HERBALIST_ONLY)")
	if Config.THROW_HERBALIST_ONLY:
		check_eq(refused, ["throw:%s" % Potions.WHY_HERBALIST] as Array[String], "refused: herbalist only")
	var empty_hand: Player = player(d, "herbalist", Arena.spawn_feet(Vector2i(25, 10)))
	empty_hand.inventory.add(&"sword", 1)
	check_eq(empty_hand.make_frame(Vector2i.ZERO, far_mouse, true, false, false, false, false, true).op, NetProtocol.Op.NONE,
		"a sword cannot be thrown")
	check_eq(Potions.throw_refusal("herbalist", null), Potions.WHY_NOT_POTION, "an empty hand")


## M6-fix: Potions.release's refusals on the effect / release frame: the potion gone meanwhile (WHY_GONE: nothing
## works, nothing used), another stack of the same grade used when the slot holds something else, a throw with no
## arena (WHY_NO_ARENA).
func _check_release_refusals() -> void:
	var d: WorldData = open_world()
	var p: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	p.inventory.add(&"potion_healing", 1, ItemDB.Grade.FINE)
	p.vitals.hp = 40
	var east: Vector2 = p.sim_position + Vector2(30, 0)
	tick(p, p.make_frame(Vector2i.ZERO, east, true, true, true))
	check(p.action_anim == Config.DRINK_ANIM and p.action_slot == 0, "drinking from slot 0")
	p.inventory.remove(0, 1)  # dropped (or moved away) before the effect frame
	var gone: Potions.Released = Potions.release(p, &"potion_healing", Config.DRINK_ANIM, null)
	check(gone.why == Potions.WHY_GONE and p.vitals.hp == 40, "the potion gone by the effect frame: %s, no heal" % gone.why)
	# The slot now holds a COMMON one, a FINE one lies further on: the FINE one is used (the action's grade).
	p.inventory.add(&"potion_healing", 2, ItemDB.Grade.COMMON)
	p.inventory.add(&"potion_healing", 1, ItemDB.Grade.FINE)
	var other: Potions.Released = Potions.release(p, &"potion_healing", Config.DRINK_ANIM, null)
	check(other.ok() and p.vitals.hp == 40 + Config.POTION_HEAL_HP[ItemDB.Grade.FINE]
		and p.inventory.count_of(&"potion_healing", ItemDB.Grade.FINE) == 0
		and p.inventory.count_of(&"potion_healing", ItemDB.Grade.COMMON) == 2,
		"another stack of the action's grade is used, the COMMON one in its slot stays (%s)" % other.why)
	var herb: Player = player(d, "herbalist", Arena.spawn_feet(Vector2i(20, 10)))
	herb.inventory.add(&"potion_poison", 1)
	var none: Potions.Released = Potions.release(herb, &"potion_poison", RigData.Anim.THROW, null)
	check(none.why == Potions.WHY_NO_ARENA and herb.inventory.count_of(&"potion_poison") == 1,
		"a throw with no arena: %s, nothing used" % none.why)


## M6-fix: the effects' edges the review found. A poison that runs out leaves no field set whatever the life state
## (Config.EFFECTS_END_ON_DOWN false left its damage and timer after a down on its last tick: has_effects() for good);
## a down on the last poison tick then a revive: no effect. The effects go on through map travel (Player.set_world).
## A heretic killed by a weapon while poisoned is not poisoned. A bottle in the air when its map empties is gone
## with its potion (no splash); a heretic's poison waits for the map to run again.
func _check_effect_edges() -> void:
	var s: PlayerSim = PlayerSim.new()
	s.add_poison(3, 1)
	s.vit.life = Vitals.Life.DOWN  # as after a down with Config.EFFECTS_END_ON_DOWN false
	s._tick_effects()
	check(not s.vit.has_effects(), "a poison that ran out leaves nothing set, also while down (%s)" % s.vit.describe())
	var last: PlayerSim = PlayerSim.new()
	last.vit.hp = 3
	last.add_poison(3, Config.POISON_INTERVAL_TICKS)
	var d: WorldData = open_world()
	var downed: bool = false
	for t: int in Config.POISON_INTERVAL_TICKS:
		downed = downed or step_sim(last, d) & PlayerSim.DOWNED != 0
	check(downed and last.vit.life == Vitals.Life.DOWN, "down on the poison's last tick")
	last.revive()
	check(not last.vit.has_effects(), "revived: no effect left (%s)" % last.vit.describe())
	# Map travel keeps them.
	var p: Player = player(d, "archer", Arena.spawn_feet(Vector2i(10, 10)))
	p.apply_potion(&"potion_buff", ItemDB.Grade.FINE)
	p.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	for t2: int in 31:
		tick(p)
	var before: Vitals = p.vitals.copy()
	var other: WorldData = open_world()
	other.map_id = Config.MAP_SURFACE
	p.set_world(other, Arena.spawn_feet(Vector2i(5, 5)))
	check(p.vitals.has_effects() and p.vitals.same_effects(before), "map travel keeps the buff and the poison (%s)" % p.vitals.describe())
	tick(p)
	check_eq(p.vitals.buff_ticks, before.buff_ticks - 1, "and they go on counting on the new map")
	# A weapon kill ends a heretic's poison.
	var a: Arena = arena_for(open_world())
	var h: HereticSim = a.spawn_heretic(Arena.spawn_feet(Vector2i(10, 10)))
	a.poison_heretic(h, 2, 300)
	a.hit_heretic(h, Config.HERETIC_HP)
	check(not h.alive() and not h.poisoned() and h.poison_ticks == 0 and h.poison_damage == 0,
		"killed by a weapon while poisoned: no poison left on the corpse")
	# An emptied map: the bottle in the air is gone (its potion was used), the poison waits.
	var e: Arena = arena_for(open_world())
	var thrower: Player = player(e.data, "herbalist", Arena.spawn_feet(Vector2i(10, 10)))
	var foe: HereticSim = e.spawn_heretic(Arena.spawn_feet(Vector2i(20, 10)))
	e.poison_heretic(foe, 2, 300)
	e.throw_potion(thrower, &"potion_poison", ItemDB.Grade.COMMON, Combat.body_point(thrower.sim_position) + Vector2(80, 0))
	e.step([thrower] as Array[Player])
	var hp_then: int = foe.hp
	var ticks_then: int = foe.poison_ticks
	e.idle_tick()
	for t3: int in 120:
		e.idle_tick()
	check(e.flasks.is_empty() and e.stat("splashes") == 0, "an emptied map: the bottle in the air is gone, no splash")
	check(foe.hp == hp_then and foe.poison_ticks == ticks_then, "its heretic's poison waits (README \"M6-fix 빈 지도의 병과 독\")")


## The marks over heads (EffectMarks) and in the HUD.
func _check_marks() -> void:
	var d: WorldData = open_world()
	var p: Player = player(d, "herbalist", Arena.spawn_feet(Vector2i(10, 10)))
	check(p.effect_marks.shown.is_empty(), "no mark")
	p.apply_potion(&"potion_buff", ItemDB.Grade.COMMON)
	check_eq(p.effect_marks.shown, [EffectMarks.Kind.BUFF] as Array[int], "the buff mark")
	p.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	check_eq(p.effect_marks.shown, [EffectMarks.Kind.BUFF, EffectMarks.Kind.POISON] as Array[int], "both")
	check_eq(p.effect_marks.get_child_count(), 2, "two icons")
	var s0: Sprite2D = p.effect_marks.get_child(0) as Sprite2D
	check_eq(Vector2i(s0.position), EffectMarks.icon_offset(0, 2), "laid out above the head")
	check(s0.material == FixtureView.unshaded_material(), "unshaded (read in the dark)")
	check(EffectMarks.icon_offset(0, 1).y + EffectMarks.SIZE <= -37, "above the head and the cleric's halo")
	p.take_hit(Config.PLAYER_HP_MAX)
	check(p.effect_marks.shown.is_empty(), "down: the marks go with the effects")
	var h: Heretic = Heretic.new()
	_nodes.append(h)
	var hs: HereticSim = HereticSim.new()
	hs.poison_ticks = 10
	h.show_sim(hs)
	check_eq(h.marks.shown, [EffectMarks.Kind.POISON] as Array[int], "a poisoned heretic's mark")
	hs.poison_ticks = 0
	h.show_sim(hs)
	check(h.marks.shown.is_empty(), "gone with the poison")
	for k: int in EffectMarks.MAPS.size():
		var img: Image = EffectMarks.image(k)
		var opaque: int = 0
		for y: int in EffectMarks.SIZE:
			for x: int in EffectMarks.SIZE:
				if img.get_pixel(x, y).a8 > 0:
					opaque += 1
		check(opaque > 15, "mark %d drawn (%d px)" % [k, opaque])
	check_eq(Hud.effect_fill(0, Config.BUFF_TICKS), -1, "the HUD's time-left bar: none")
	check_eq(Hud.effect_fill(Config.BUFF_TICKS[ItemDB.Grade.FINE], Config.BUFF_TICKS), EffectMarks.SIZE, "full")
	check_eq(Hud.effect_fill(1, Config.BUFF_TICKS), 1, "at least 1 px while on")


# --- the shared simulation ----------------------------------------------------------------------------

## The same frames and the same potions give the same state, effects included, tick by tick: offline
## (Player.step_frame), the host (SessionHost.run_frame on a member, no transport) and a client's prediction
## (Prediction.step_frame).
func _check_shared_sim() -> void:
	var world: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	world.auto_generate = false
	world.free_camera = false
	add_node(world)
	world.generate(Config.DEFAULT_SEED)
	var s: NetSession = NetSession.new()
	s.name = &"PotionTestNet"
	add_node(s)
	s.world = world
	s.options = CliOptions.new()
	s.role = NetSession.Role.HOST
	var host: SessionHost = SessionHostScript.new(s)
	s.host = host
	var start: Vector2 = world.data.altar_center_px() + Vector2(0, 140)
	var m: NetMember = s.add_member(2, 7, "herbalist", start, RigData.Dir.SOUTH)
	m.gate = InputGate.new()
	var offline: Player = player(world.data, "herbalist", start)
	var pred: Prediction = Prediction.new()
	pred.setup(world.data, start, RigData.Dir.SOUTH, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 606
	var mismatch: int = 0
	var first_bad: String = ""
	var dir: Vector2i = Vector2i.ZERO
	var potions: Array[StringName] = [&"potion_buff", &"potion_poison", &"potion_healing"]
	var applied: int = 0
	var poison_ticks: int = 0
	var downs: int = 0
	var buffed_ticks: int = 0
	for t: int in 2400:
		if t % 20 == 0:
			dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(t + 1, dir)
		f.dash = rng.randf() < 0.03
		var ev: int = tick(offline, _copy(f))
		if ev & PlayerSim.POISON_TICK:
			poison_ticks += 1
		if ev & PlayerSim.DOWNED:
			downs += 1
		m.player.begin_tick()
		host.run_frame(m, _copy(f))
		pred.step_frame(_copy(f))
		if t % 150 == 70:
			var id: StringName = potions[rng.randi_range(0, 2)]
			var g: int = rng.randi_range(1, 2)
			var a: int = offline.apply_potion(id, g)
			var b: int = m.player.apply_potion(id, g)
			var c: int = Potions.apply(pred.sim, id, g)
			if a != b or a != c:
				mismatch += 1
			if a != 0:
				applied += 1
		if t % 150 == 140 and offline.vitals.hp > 20:
			offline.take_hit(15)
			m.player.take_hit(15)
			pred.sim.hurt(15)
		if offline.vitals.life == Vitals.Life.DOWN and t % 50 == 0:
			offline.revive_now()
			m.player.revive_now()
			pred.sim.revive()
		if offline.vitals.buffed():
			buffed_ticks += 1
		var so: PlayerSim = offline.to_sim()
		if not so.same_all(m.player.to_sim()) or not so.same_all(pred.sim):
			mismatch += 1
			if first_bad.is_empty():
				first_bad = "tick %d: offline %s / host %s / pred %s" % [t, so.vit.describe(), m.player.vitals.describe(),
					pred.sim.vit.describe()]
	check_eq(mismatch, 0, "offline == host == prediction every tick, effects included %s" % first_bad)
	check(applied > 8 and poison_ticks > 10 and buffed_ticks > 300, "the run drank potions, was poisoned and buffed (%d, %d, %d)" % [
		applied, poison_ticks, buffed_ticks])
	note("shared sim with effects: 2400 ticks, %d potions, %d poison ticks, %d buffed ticks, %d downs, no mismatch" % [applied,
		poison_ticks, buffed_ticks, downs])


static func _copy(f: NetProtocol.InputFrame) -> NetProtocol.InputFrame:
	var c: NetProtocol.InputFrame = NetProtocol.InputFrame.new(f.seq, f.dir)
	c.look = f.look
	c.dash = f.dash
	c.interact = f.interact
	return c


# --- main.tscn ---------------------------------------------------------------------------------------

## Offline: a herbalist drinks (healing used on the effect frame, refused at full HP), throws poison at a
## heretic outside the light with key 1 (it is poisoned, then dies of it: a kill), drinks the buff (marks over
## the head and in the HUD); the throw's bot command; the alchemy table brews what is thrown.
func _check_main_flow() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	var p: Player = main.player
	if not check(p != null and p.potions_on, "main: offline player with potions on"):
		return
	p.local_input = false
	main.spawn("herbalist")
	p = main.player
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	p.inventory.add(&"potion_healing", 2)
	p.inventory.add(&"potion_poison", 2, ItemDB.Grade.FINE)
	p.inventory.add(&"potion_buff", 1)
	var data: WorldData = main.world.data
	var out: Vector2 = data.altar_center_px() + Vector2(0, Config.safe_radius_px() + 60.0)
	p.teleport(out)
	p.inventory.select(_slot_of(p.inventory, &"potion_healing"))
	var east: Vector2 = out + Vector2(40, 0)
	# Full HP: the click is refused, nothing used.
	_tick_main(main, p, east, true)
	check_eq(p.action_anim, -1, "full HP: no drink")
	check_eq(p.inventory.count_of(&"potion_healing"), 2, "nothing used")
	# Hurt: drink; the potion goes on the effect frame.
	p.vitals.hp = 30
	_tick_main(main, p, east, true)
	check_eq(p.action_anim, Config.DRINK_ANIM, "drinking")
	for t: int in Potions.impact_tick(Config.DRINK_ANIM) - 1:
		_tick_main(main, p, east, false)
	check(p.inventory.count_of(&"potion_healing") == 2 and p.vitals.hp == 30, "not yet before the effect frame")
	_tick_main(main, p, east, false)
	check_eq(p.inventory.count_of(&"potion_healing"), 1, "one used on the effect frame")
	check_eq(p.vitals.hp, 30 + Config.POTION_HEAL_HP[ItemDB.Grade.COMMON], "healed")
	for t2: int in 60:
		_tick_main(main, p, east, false)
	# A hit before the effect frame cuts the drink off: nothing used.
	_tick_main(main, p, east, true)
	_tick_main(main, p, east, false)
	p.take_hit(5)
	for t3: int in 60:
		_tick_main(main, p, east, false)
	check_eq(p.inventory.count_of(&"potion_healing"), 1, "a hit cut the drink off: nothing used")
	# Full HP again by the effect frame (healed meanwhile): refused there too, nothing used.
	p.vitals.hp = Config.PLAYER_HP_MAX - 1
	_tick_main(main, p, east, true)
	check_eq(p.action_anim, Config.DRINK_ANIM, "drinking at 99 HP")
	p.vitals.hp = Config.PLAYER_HP_MAX
	for t7: int in 60:
		_tick_main(main, p, east, false)
	check_eq(p.inventory.count_of(&"potion_healing"), 1 if not Config.DRINK_AT_FULL_HP else 0,
		"full HP on the effect frame: refused, nothing used")
	# From inside the light, throw poison at a heretic standing outside it (key 1); it does not come for a
	# player in the light, so it stands where the bottle lands.
	var arena: Arena = main.arenas[Config.MAP_SURFACE]
	var inside: Vector2 = data.altar_center_px() + Vector2(0, Config.safe_radius_px() - 16.0)
	p.teleport(inside)
	var foe: HereticSim = arena.spawn_heretic(inside + Vector2(0, 48))
	check(not main.world.is_in_safe_zone(foe.pos) and main.world.is_in_safe_zone(p.sim_position), "setup: player in, heretic out")
	foe.hp = 20
	p.inventory.select(_slot_of(p.inventory, &"potion_poison"))
	var aim: Vector2 = Combat.body_centre(foe.pos)
	for t4: int in 90:
		_tick_main(main, p, aim, false, t4 == 0)
		if foe.poisoned():
			break
	check(foe.poisoned(), "the thrown poison reached the heretic")
	check_eq(p.inventory.count_of(&"potion_poison"), 1, "one thrown")
	var view: CombatView = main.combat_views[Config.MAP_SURFACE]
	var poison_mark: Array[int] = [EffectMarks.Kind.POISON]
	check(view.heretics.has(foe.id) and view.heretics[foe.id].marks.shown == poison_mark,
		"the heretic shows the poison mark")
	check(not view.splashes.is_empty(), "the splash is drawn")
	var kills: int = arena.stat("killed")
	for t5: int in 600:
		_tick_main(main, p, aim, false)
		if not foe.alive():
			break
	check(not foe.alive(), "the heretic died of the poison (hp %d)" % foe.hp)
	check_eq(arena.stat("killed"), kills + 1, "counted as a kill")
	check_eq(arena.stat("poison_kills"), 1, "by poison")
	# Drink the buff: the mark over the head and in the HUD.
	p.vitals.hp = Config.PLAYER_HP_MAX
	p.teleport(data.altar_center_px() + Vector2(0, 80))
	p.inventory.select(_slot_of(p.inventory, &"potion_buff"))
	_tick_main(main, p, east, true)
	for t6: int in Potions.impact_tick(Config.DRINK_ANIM):
		_tick_main(main, p, east, false)
	check(p.vitals.buffed(), "the buff drunk")
	check_eq(p.effect_marks.shown, [EffectMarks.Kind.BUFF] as Array[int], "its mark over the head")
	check(main.hud.vitals_key().ends_with("/%d/-1" % Hud.effect_fill(p.vitals.buff_ticks, Config.BUFF_TICKS)),
		"the HUD shows its time left (%s)" % main.hud.vitals_key())


static func _slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


## One offline tick of main: the player's controls (click = use pressed this tick), then the combat.
static func _tick_main(main: Main, p: Player, mouse: Vector2, click: bool, skill: bool = false) -> void:
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, mouse, true, click, click, TICK, false, false, skill)
	main.step_combat(TICK)
