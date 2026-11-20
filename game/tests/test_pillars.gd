extends "res://tests/base_test.gd"
## M12b, the cracked support pillars on their own (● game-concept §12 R49: the miner breaks them and their debris falls, four picture states;
## ● gameplay-design §3.0 R11 the class-only column "보스전 지형 상호작용": the miner's alone; every number PROVISIONAL, README "임시값" M12a
## 기둥): their spots on seeds the M12a test does not walk (31..60) and the default seed's (deterministic, a free ring round each inside the
## room, never on or beside a doorway, the doorways and the home free, every floor tile still reached from the doorways, a free tile
## beside each), every class's every blow (the other four classes' swings, weapon skills and shots refused with the mark, the cleric's
## burst and the arrow rain passing them by, a miner swinging a sword refused; the miner's pick, tier-1 pick and his three damaging skills
## one blow each), exactly hits_per_state blows a state and nothing once it broke, the view's picture per state, the debris's timing (not
## a tick early) and its circle (the boss and players just inside and just outside it, a dashing and a downed player, a sleeping boss, a
## boss walking home), its stun over the immunity and the exposure (its own damage never raised by an exposure), a reset restoring every
## pillar, the kill leaving them as they are, and no tile edit (the dungeon's golden hash and its layers byte for byte after a whole
## pillar fight on the generated dungeon).

const TICK: float = 1.0 / 60.0
const ROOM: Rect2i = Rect2i(8, 6, 26, 20)
## The pillar most checks use (the boss's home (21, 16) is 9 tiles east, beyond every blow aimed at it).
const SPOT: Vector2i = Vector2i(12, 20)

var _nodes: Array[Node] = []
var _landed: Skills.Landed


func run() -> Array[String]:
	_check_spots()
	_check_blows()
	_check_skill_blows()
	_check_states()
	_check_debris_timing()
	_check_debris_area()
	_check_stun_and_exposure()
	_check_reset_restores()
	_check_kill_keeps()
	_check_no_tile_edits()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------------------------

static func open_dungeon() -> WorldData:
	var d: WorldData = WorldData.new(Vector2i(48, 36))
	d.map_id = Config.MAP_DUNGEON
	d.world_seed = 1
	return d


static func test_room(pillars: Array[Vector2i]) -> BossRoom.Layout:
	var r: BossRoom.Layout = BossRoom.Layout.new()
	r.room = ROOM
	r.walk = BossRoom.walk_of(ROOM)
	r.room_index = 0
	r.home_tile = r.walk.position + r.walk.size / 2
	r.pillars = pillars
	return r


static func fight_on(d: WorldData, room: BossRoom.Layout) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	a.boss = BossFight.new()
	a.boss.setup_with(a, room, 1)
	return a


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.skills_on = true
	_nodes.append(p)
	return p


static func tick(p: Player) -> void:
	p.begin_tick()
	p.step_frame(NetProtocol.InputFrame.new(), TICK)


static func run_world(a: Arena, players: Array[Player], n: int) -> void:
	for i: int in n:
		for p: Player in players:
			tick(p)
		for e: EditLog.WorldEdit in a.step(players):
			EditLog.apply_to_data(a.data, e)


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


static func hold(p: Player, id: StringName) -> void:
	if slot_of(p.inventory, id) < 0:
		p.inventory.add(id, 1)
	p.inventory.select(slot_of(p.inventory, id))


## The aim code from `p`'s body point to pillar `pi`'s middle.
static func aim_at(p: Player, pi: BossFight.Pillar) -> int:
	return Combat.aim_code(pi.centre() - Combat.body_point(p.sim_position))


func wire(p: Player, a: Arena, party: Array[Player]) -> void:
	p.party_provider = func() -> Array[Player]: return party
	p.action_impact.connect(_impact.bind(p, a, party))


func _impact(item: StringName, _anim: int, _cell: Vector2i, p: Player, a: Arena, party: Array[Player]) -> void:
	if Skills.is_skill(item):
		_landed = Skills.land(p, item, a, party)


static func press(p: Player, slot: int, mouse: Vector2) -> void:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, mouse, true, false, false, false, false,
		slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	p.step_frame(f, TICK)


## Breaks pillar `i` with `by`'s blows (hits_per_state x 3).
static func break_pillar(f: BossFight, i: int, by: Player) -> void:
	for k: int in BossFight.Pillar.hits_per_state() * 3:
		f.blow(i, by.get_instance_id(), true)


# --- the spots -----------------------------------------------------------------------------------------------------------

func _check_spots() -> void:
	var gap_kept: int = 0
	var counts: Dictionary[int, int] = {}
	for s: int in range(31, 61):
		var built: Array = DungeonGen.build(s)
		var data: WorldData = built[0]
		var r: BossRoom.Layout = BossRoom.for_seed(s)
		if not check(r.has_room(), "seed %d: a boss room" % s):
			continue
		check_eq(BossRoom.for_seed(s).describe(), r.describe(), "seed %d: the same pillars twice" % s)
		var n: int = r.pillars.size()
		counts[n] = counts.get(n, 0) + 1
		check(n >= roundi(Config.BOSS_PILLARS["min_count"]) and n <= roundi(Config.BOSS_PILLARS["count"]), "seed %d: 3 or 4 (%d)" % [s, n])
		var all_gap: bool = true
		for p: Vector2i in r.pillars:
			check(r.walk.grow(-roundi(Config.BOSS_PILLARS["margin_tiles"])).has_point(p), "seed %d: %s a free ring inside the room" % [s, p])
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					check(not Arena.terrain_blocked(data, p + Vector2i(ox, oy)), "seed %d: nothing of the room's round %s" % [s, p])
			check(p != r.home_tile and BossRoom.cheb(p, r.home_tile) >= 2, "seed %d: %s off the home" % [s, p])
			for door: Vector2i in r.doors:
				check(BossRoom.cheb(p, door) >= 1, "seed %d: %s not on a doorway" % [s, p])
				if BossRoom.cheb(p, door) < roundi(Config.BOSS_PILLARS["door_gap_tiles"]):
					all_gap = false
		if all_gap:
			gap_kept += 1
		else:
			# A pillar beside a doorway only when the full door gap leaves fewer than min_count (BossRoom.pick_pillars cuts it then).
			var full: Array[Vector2i] = BossRoom._pick(data, r, s, roundi(Config.BOSS_PILLARS["count"]),
				roundi(Config.BOSS_PILLARS["door_gap_tiles"]), roundi(Config.BOSS_PILLARS["home_gap_tiles"]))
			check(full.size() < roundi(Config.BOSS_PILLARS["min_count"]), "seed %d: beside a doorway only because the full gap fits %d" % [s,
				full.size()])
		# The pillars standing: the doorways and the home free, every floor tile reached from the doorways, a free tile beside each.
		for p2: Vector2i in r.pillars:
			data.blockers[p2] = true
		for door2: Vector2i in r.doors:
			check(not Movement.is_blocked(data, door2), "seed %d: doorway %s free" % [s, door2])
		check(not Movement.is_blocked(data, r.home_tile), "seed %d: the home free" % s)
		var reach: Dictionary[Vector2i, bool] = {}
		var queue: Array[Vector2i] = []
		for door3: Vector2i in r.doors:
			reach[door3] = true
			queue.append(door3)
		var k: int = 0
		while k < queue.size():
			var c: Vector2i = queue[k]
			k += 1
			for st: Vector2i in DungeonGen.STEPS:
				var nb: Vector2i = c + st
				if r.walk.has_point(nb) and not reach.has(nb) and not Movement.is_blocked(data, nb):
					reach[nb] = true
					queue.append(nb)
		var floor_tiles: int = 0
		for y: int in range(r.walk.position.y, r.walk.end.y):
			for x: int in range(r.walk.position.x, r.walk.end.x):
				if not Movement.is_blocked(data, Vector2i(x, y)):
					floor_tiles += 1
		check_eq(reach.size(), floor_tiles, "seed %d: every floor tile reached from the doorways" % s)
		for p3: Vector2i in r.pillars:
			var beside: int = 0
			for st2: Vector2i in DungeonGen.STEPS:
				if reach.has(p3 + st2):
					beside += 1
			check_eq(beside, 4, "seed %d: free on all four sides of %s" % [s, p3])
	note("pillar spots on seeds 31..60: counts %s, the door gap %d kept on %d of 30 seeds" % [counts,
		roundi(Config.BOSS_PILLARS["door_gap_tiles"]), gap_kept])
	# The default seed's (the README's, the smoke's): a regression would move them.
	var r1: BossRoom.Layout = BossRoom.for_seed(Config.DEFAULT_SEED)
	check_eq(str(r1.pillars), "[(49, 39), (56, 35), (56, 40), (48, 35)]", "seed 1's four pillars")
	check_eq(r1.room, Rect2i(47, 33, 11, 9), "seed 1's room")


# --- every class's blows -------------------------------------------------------------------------------------------------------

## Basic attacks: the other four classes' weapons (and the paladin with a pickaxe, a miner with a sword) refused with the mark; the
## miner's pick and tier-1 pick one blow each.
func _check_blows() -> void:
	var rows: Array[Array] = [
		["paladin", &"sword", false], ["paladin", &"pickaxe", false], ["herbalist", &"sickle", false], ["archer", &"bow", false],
		["cleric", &"holy_light", false], ["miner", &"sword", false], ["miner", &"pickaxe", true], ["miner", &"pickaxe_t1", true],
	]
	for row: Array in rows:
		var class_id: String = row[0]
		var item: StringName = row[1]
		var counts: bool = row[2]
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room([SPOT] as Array[Vector2i]))
		var f: BossFight = a.boss
		var shot: bool = Combat.attack_for(item).kind != Combat.Kind.MELEE
		var at: Vector2i = SPOT + (Vector2i(-4, 0) if shot else Vector2i(-1, 0))
		var p: Player = player(d, class_id, Arena.spawn_feet(at))
		var party: Array[Player] = [p]
		f.wake(party)
		f.frozen = true  # awake (the player is in its room) but standing: only the blows count here
		hold(p, item)
		var aim: int = Combat.aim_code(Vector2.RIGHT) if shot else aim_at(p, f.pillars[0])
		a.player_attack(p, item, aim, party)
		run_world(a, party, 40 if shot else 1)
		check_eq(f.pillars[0].hits, 1 if counts else 0, "%s's %s: %s" % [class_id, item, "a blow" if counts else "nothing"])
		check_eq(f.stat("pillar_refused"), 0 if counts else 1, "%s's %s: %s" % [class_id, item, "not refused" if counts else "refused"])
		if not counts:
			check(f.pillars[0].refused_ticks > 0 or f.stat("pillar_refused") == 1, "%s's %s: the refused mark" % [class_id, item])
			check_eq(f.pillars[0].flash_ticks, 0, "%s's %s: no hit flash" % [class_id, item])
		if shot:
			check_eq(a.stat("shot_pillar"), 1, "%s's shot stops at the pillar" % class_id)
		check_eq(f.sim.hp, f.sim.hp_max, "%s: the boss 9 tiles off untouched" % class_id)


## Skills aimed at the pillar: the miner's three damaging skills are a blow each; the other classes' weapon skills and shots are refused
## (a skill that misses it does nothing), the cleric's burst and the arrow rain pass it by (no blow, no mark: area strikes ignore pillars).
func _check_skill_blows() -> void:
	# [class, slot, skill, weapon held, the player's tile from the pillar, the mouse from the pillar's middle, blows, refused at least]
	var rows: Array[Array] = [
		["miner", Skills.Slot.IDENTITY, Skills.GROUND_SLAM, &"", Vector2i(-1, 0), Vector2.ZERO, 1, 0],
		["miner", Skills.Slot.WEAPON, Skills.HEAVY_STRIKE, &"pickaxe", Vector2i(-1, 0), Vector2.ZERO, 1, 0],
		["miner", Skills.Slot.SIGNATURE, Skills.ROCKFALL, &"", Vector2i(-3, 0), Vector2.ZERO, 1, 0],
		["paladin", Skills.Slot.WEAPON, Skills.CRUSHING_BLOW, &"sword", Vector2i(-1, 0), Vector2.ZERO, 0, 1],
		["herbalist", Skills.Slot.WEAPON, Skills.SWEEP, &"sickle", Vector2i(-1, 0), Vector2.ZERO, 0, 1],
		["archer", Skills.Slot.IDENTITY, Skills.PIERCING_ARROW, &"", Vector2i(-4, 0), Vector2(0, 0), 0, 1],
		["archer", Skills.Slot.WEAPON, Skills.FAN_SHOT, &"bow", Vector2i(-4, 0), Vector2(0, 0), 0, 1],
		["archer", Skills.Slot.SIGNATURE, Skills.ARROW_RAIN, &"", Vector2i(-3, 0), Vector2.ZERO, 0, 0],
		["cleric", Skills.Slot.WEAPON, Skills.HOLY_BURST, &"holy_light", Vector2i(-3, 0), Vector2.ZERO, 0, 0],
	]
	for row: Array in rows:
		var class_id: String = row[0]
		var slot: int = row[1]
		var id: StringName = row[2]
		var weapon: StringName = row[3]
		var off: Vector2i = row[4]
		var mouse_off: Vector2 = row[5]
		var want: int = row[6]
		var refused: int = row[7]
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room([SPOT] as Array[Vector2i]))
		var f: BossFight = a.boss
		var p: Player = player(d, class_id, Arena.spawn_feet(SPOT + off))
		var party: Array[Player] = [p]
		wire(p, a, party)
		f.wake(party)
		f.frozen = true
		if not weapon.is_empty():
			hold(p, weapon)
		p.skills.resource = Skills.resource_cap(class_id)
		_landed = null
		var shot_skill: bool = id == Skills.PIERCING_ARROW or id == Skills.FAN_SHOT
		var mouse: Vector2 = f.pillars[0].centre() + mouse_off
		if shot_skill:
			mouse = Combat.aim_origin(p.sim_position) + Vector2(80, 0)  # straight east along the pillar's row
		press(p, slot, mouse)
		check_eq(p.action_skill, id, "%s's %s starts" % [class_id, id])
		for t: int in Skills.impact_tick(id):
			tick(p)
		for e: EditLog.WorldEdit in a.step(party):
			EditLog.apply_to_data(d, e)
		run_world(a, party, 90)
		check(_landed != null and _landed.ok(), "%s landed" % id)
		check_eq(f.pillars[0].hits, want, "%s's %s: %d blow(s) on the pillar" % [class_id, id, want])
		check(f.stat("pillar_refused") >= refused, "%s's %s: refused %d time(s) (at least %d)" % [class_id, id, f.stat("pillar_refused"), refused])
		if refused == 0:
			check_eq(f.stat("pillar_refused"), 0, "%s's %s: no refused mark" % [class_id, id])


# --- states ---------------------------------------------------------------------------------------------------------------------

func _check_states() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room([SPOT] as Array[Vector2i]))
	var f: BossFight = a.boss
	var m: Player = player(d, "miner", Arena.spawn_feet(SPOT + Vector2i(-1, 0)))
	var view: BossFightView = BossFightView.new()
	_nodes.append(view)
	var holder: Node2D = Node2D.new()
	var entities: Node2D = Node2D.new()
	holder.add_child(entities)
	_nodes.append(holder)
	view.setup(f, entities)
	check_eq(view.pillar_nodes.size(), 1, "a node for the pillar")
	var per: int = BossFight.Pillar.hits_per_state()
	check_eq(per, 3, "three blows a state (the task's provisional number)")
	var seen: Array[int] = []
	for k: int in per * 3:
		check(f.blow(0, m.get_instance_id(), true), "blow %d lands" % (k + 1))
		seen.append(f.pillars[0].look())
		view.sync()
		var s: Sprite2D = view.pillar_nodes[0].get_node(^"Sprite") as Sprite2D
		check(s.texture == PillarArt.texture(f.pillars[0].look()), "blow %d: the view shows state %d" % [k + 1, f.pillars[0].look()])
	check_eq(seen, [0, 0, 1, 1, 1, 2, 2, 2, 3] as Array[int], "intact, cracked, badly cracked: three blows each, the ninth breaks it")
	check(not f.blow(0, m.get_instance_id(), true), "breaking: a tenth blow does not land")
	check_eq(f.pillars[0].hits, per * 3, "nine")
	run_world(a, [m] as Array[Player], roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1)
	check(f.pillars[0].fallen, "fallen")
	check(not f.blow(0, m.get_instance_id(), true), "rubble takes no blow")
	check_eq(f.stat("pillar_hits"), per * 3, "nine blows counted")
	check_eq(f.stat("pillars_broken"), 1, "broken once")
	# The pictures' crack pixels grow state by state (state 1 reads beside the intact one: M12b's third crack).
	var cracks: Array[int] = []
	for look: int in 3:
		var img: Image = PillarArt.image(look)
		var n: int = 0
		for y: int in img.get_height():
			for x: int in img.get_width():
				if img.get_pixel(x, y) == PillarArt.CRACK:
					n += 1
		cracks.append(n)
	check(cracks[1] >= cracks[0] + 30, "cracked: at least 30 crack px more than intact (%d -> %d; M12b's third crack)" % [cracks[0], cracks[1]])
	check(cracks[2] >= cracks[1] + 40, "badly cracked: 40 more again (%d)" % cracks[2])
	view.clear()


# --- the debris -----------------------------------------------------------------------------------------------------------------

func _check_debris_timing() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room([SPOT] as Array[Vector2i]))
	var f: BossFight = a.boss
	var m: Player = player(d, "miner", f.pillars[0].centre() + Vector2(0, 20))
	var party: Array[Player] = [m]
	f.wake(party)
	f.frozen = true
	f.sim.pos = f.pillars[0].centre() + Vector2(-12, 14)
	var hp: int = f.sim.hp
	break_pillar(f, 0, m)
	var telegraph: int = roundi(Config.BOSS_PILLARS["telegraph_ticks"])
	check_eq(telegraph, 48, "0.8 s of dust (the task's provisional number)")
	for t: int in telegraph - 1:
		run_world(a, party, 1)
		if f.sim.hp != hp or m.vitals.hp != Config.PLAYER_HP_MAX:
			fail("damage %d ticks into the dust" % (t + 1))
			break
		if not Movement.is_blocked(d, SPOT):
			fail("the stub stopped blocking %d ticks into the dust" % (t + 1))
			break
	check_eq(f.pillars[0].falling, 1, "a tick of dust left")
	check(f.debris.is_empty(), "nothing landed yet")
	run_world(a, party, 1)
	check(f.pillars[0].fallen, "it lands on the telegraph's last tick")
	check_eq(f.debris.size(), 1, "the debris shows")
	check(f.sim.hp < hp, "the boss under it hurt now")
	check(m.vitals.hp < Config.PLAYER_HP_MAX, "the miner under it too")
	run_world(a, party, BossFight.DEBRIS_SHOW_TICKS)
	check(f.debris.is_empty(), "its dust settles after %d ticks" % BossFight.DEBRIS_SHOW_TICKS)


func _check_debris_area() -> void:
	var r: float = Config.BOSS_PILLARS["fall_radius_px"]
	check_eq(r, 32.0, "a 2-tile fall circle (the task's provisional number)")
	# The boss just inside and just outside; players just inside, just outside, dashing, downed.
	for inside: bool in [true, false]:
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room([SPOT] as Array[Vector2i]))
		var f: BossFight = a.boss
		var c: Vector2 = f.pillars[0].centre()
		var under: Player = player(d, "paladin", c + Vector2(0, r - 0.5 if inside else r + 0.5))
		var miner: Player = player(d, "miner", c + Vector2(-(r + 6.0), 0))
		var party: Array[Player] = [under, miner]
		f.wake(party)
		f.frozen = true
		f.sim.pos = c + Vector2(r - 0.5 if inside else r + 0.5, 0)
		var hp: int = f.sim.hp
		break_pillar(f, 0, miner)
		run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]))
		var what: String = "inside" if inside else "outside"
		if inside:
			check_eq(hp - f.sim.hp, maxi(ceili(f.sim.hp_max * Config.BOSS["debris_damage_pct"] / 100.0), 1), "the boss just inside: 12%")
			check_eq(f.sim.stun_ticks, roundi(Config.BOSS["debris_stun_ticks"]), "stunned")
			check_eq(f.sim.exposed_ticks, roundi(Config.BOSS["exposed_ticks"]), "exposed")
			check_eq(under.vitals.hp, Config.PLAYER_HP_MAX - roundi(Config.BOSS_PILLARS["player_damage"]), "a player just inside: 20")
			check(under.vitals.staggered(), "and staggered")
			check(f.debris[0].boss_hit and f.debris[0].players_hit == 1, "the debris says so")
		else:
			check_eq(f.sim.hp, hp, "the boss just outside: unhurt")
			check_eq(f.sim.stun_ticks, 0, "not stunned")
			check(not f.sim.exposed(), "not exposed")
			check_eq(under.vitals.hp, Config.PLAYER_HP_MAX, "a player just outside: unhurt")
			check(not under.vitals.staggered(), "not staggered")
		check_eq(miner.vitals.hp, Config.PLAYER_HP_MAX, "the miner %s px off: unhurt (%s run)" % [roundi(r + 6.0), what])
	# A dashing player and a downed one under it take nothing.
	var d2: WorldData = open_dungeon()
	var a2: Arena = fight_on(d2, test_room([SPOT] as Array[Vector2i]))
	var f2: BossFight = a2.boss
	var c2: Vector2 = f2.pillars[0].centre()
	var dasher: Player = player(d2, "archer", c2 + Vector2(0, 20))
	var downed: Player = player(d2, "cleric", c2 + Vector2(0, -20))
	var m2: Player = player(d2, "miner", c2 + Vector2(-40, 0))
	downed.take_hit(Config.PLAYER_HP_MAX)
	check(not downed.vitals.alive(), "the cleric is down")
	var down_hp: int = downed.vitals.hp
	break_pillar(f2, 0, m2)
	var party2: Array[Player] = [dasher, downed, m2]
	for t: int in roundi(Config.BOSS_PILLARS["telegraph_ticks"]):
		for p: Player in party2:
			tick(p)
		dasher.vitals.dash_ticks = 2  # dashing as it lands
		a2.step(party2)
	check(Config.DASH_INVULNERABLE, "a dash is invulnerable (M4a)")
	check_eq(dasher.vitals.hp, Config.PLAYER_HP_MAX, "a dashing player under it: unhurt")
	check_eq(downed.vitals.hp, down_hp, "a downed one: nothing more")
	check_eq(f2.debris[0].players_hit, 0, "nobody hit")
	# A sleeping boss under it: it wakes, takes it, is stunned and exposed.
	var d3: WorldData = open_dungeon()
	var a3: Arena = fight_on(d3, test_room([SPOT] as Array[Vector2i]))
	var f3: BossFight = a3.boss
	var m3: Player = player(d3, "miner", f3.pillars[0].centre() + Vector2(-40, 0))
	f3.sim.pos = f3.pillars[0].centre() + Vector2(10, 10)
	break_pillar(f3, 0, m3)
	run_world(a3, [] as Array[Player], roundi(Config.BOSS_PILLARS["telegraph_ticks"]))
	check(f3.sim.awake(), "a sleeping boss under it wakes")
	check_eq(f3.sim.hp, f3.sim.hp_max - maxi(ceili(f3.sim.hp_max * Config.BOSS["debris_damage_pct"] / 100.0), 1), "and takes it")
	check(f3.sim.stunned() and f3.sim.exposed(), "stunned and exposed")
	# A boss walking home takes nothing (no blow lands then).
	var d4: WorldData = open_dungeon()
	var a4: Arena = fight_on(d4, test_room([SPOT] as Array[Vector2i]))
	var f4: BossFight = a4.boss
	var m4: Player = player(d4, "miner", f4.pillars[0].centre() + Vector2(-40, 0))
	f4.wake([m4] as Array[Player])
	f4.sim.pos = f4.pillars[0].centre() + Vector2(10, 10)
	f4._start_return("test")
	break_pillar(f4, 0, m4)
	var hp4: int = f4.sim.hp
	for t2: int in roundi(Config.BOSS_PILLARS["telegraph_ticks"]):
		f4.sim.pos = f4.pillars[0].centre() + Vector2(10, 10)  # held under it while it would walk home
		a4.step([m4] as Array[Player])
	check_eq(f4.sim.hp, hp4, "walking home: the debris does nothing to it")
	check(not f4.debris.is_empty() and not f4.debris[0].boss_hit, "not counted as a hit")


func _check_stun_and_exposure() -> void:
	var d: WorldData = open_dungeon()
	var a: Arena = fight_on(d, test_room([SPOT, Vector2i(18, 22)] as Array[Vector2i]))
	var f: BossFight = a.boss
	var pal: Player = player(d, "paladin", f.pillars[0].centre() + Vector2(-40, 0))
	var m: Player = player(d, "miner", f.pillars[0].centre() + Vector2(-44, 12))
	var party: Array[Player] = [pal, m]
	f.wake(party)
	f.frozen = true
	f.sim.pos = f.pillars[0].centre() + Vector2(8, 16)
	# A skill's stun: the immunity starts.
	check(f.stun(Skills.num_i(Skills.CRUSHING_BLOW, "stun_ticks")), "the paladin's stun takes")
	check(f.sim.stun_immune > 0, "immune now")
	check(not f.stun(60), "another is refused")
	var immune_before: int = f.sim.stun_immune
	break_pillar(f, 0, m)
	run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]))
	check_eq(f.sim.stun_ticks, roundi(Config.BOSS["debris_stun_ticks"]), "the debris's whole stun over the immunity (%d left)" % immune_before)
	check_eq(f.sim.stun_immune, f.sim.stun_ticks + roundi(Config.BOSS["stun_immune_ticks"]), "then the immunity follows it")
	check(not f.stun(60), "a skill's stun still refused")
	# Exposed: every hit x1.5 for its ticks, then as before.
	var base: int = 20
	var before: int = f.sim.hp
	f.hit(base, pal.get_instance_id())
	check_eq(before - f.sim.hp, ceili(base * Config.BOSS["exposed_damage_pct"] / 100.0), "exposed: 150%")
	# A second debris while exposed: its own damage is still 12%, not raised.
	f.sim.pos = f.pillars[1].centre() + Vector2(-6, 12)
	var hp2: int = f.sim.hp
	break_pillar(f, 1, m)
	run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]))
	check_eq(hp2 - f.sim.hp, maxi(ceili(f.sim.hp_max * Config.BOSS["debris_damage_pct"] / 100.0), 1), "a second debris while exposed: 12%, not 18%")
	check_eq(f.sim.exposed_ticks, roundi(Config.BOSS["exposed_ticks"]), "the exposure starts over")
	run_world(a, party, roundi(Config.BOSS["exposed_ticks"]))
	check(not f.sim.exposed(), "the exposure ends after %d ticks" % roundi(Config.BOSS["exposed_ticks"]))
	var hp3: int = f.sim.hp
	f.hit(base, pal.get_instance_id())
	check_eq(hp3 - f.sim.hp, base, "then as before")


# --- the reset and the kill ----------------------------------------------------------------------------------------------------

func _check_reset_restores() -> void:
	var spots: Array[Vector2i] = [SPOT, Vector2i(14, 10), Vector2i(28, 22)]
	for why: String in ["left alone", "emptied"]:
		var d: WorldData = open_dungeon()
		var a: Arena = fight_on(d, test_room(spots))
		var f: BossFight = a.boss
		var m: Player = player(d, "miner", Arena.spawn_feet(SPOT + Vector2i(-3, 1)))
		var party: Array[Player] = [m]
		run_world(a, party, 1)
		check(f.sim.awake(), "%s: awake" % why)
		f.frozen = true
		break_pillar(f, 0, m)
		run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1)
		break_pillar(f, 1, m)  # still coming down at the reset
		for k: int in BossFight.Pillar.hits_per_state():
			f.blow(2, m.get_instance_id(), true)  # cracked
		check(f.pillars[0].fallen and f.pillars[1].falling >= 0 and f.pillars[2].look() == 1, "%s: rubble, falling, cracked" % why)
		check(not d.blockers.has(spots[0]), "%s: the rubble does not block" % why)
		if why == "emptied":
			a.idle_tick()
		else:
			f.frozen = false
			run_world(a, [] as Array[Player], roundi(Config.BOSS["reset_ticks"]) + 600)  # the miner gone from the map
		check_eq(f.sim.state, BossSim.State.SLEEP, "%s: reset" % why)
		for i: int in spots.size():
			var p: BossFight.Pillar = f.pillars[i]
			check(p.whole() and p.hits == 0 and p.falling < 0 and not p.fallen and p.broken_by == 0, "%s: pillar %d whole again" % [why, i])
			check(d.blockers.has(spots[i]), "%s: pillar %d blocks again" % [why, i])
		check(f.debris.is_empty(), "%s: no debris shown" % why)
		check_eq(m.vitals.hp, Config.PLAYER_HP_MAX, "%s: the pillar coming down at the reset hurt nobody" % why)


func _check_kill_keeps() -> void:
	var d: WorldData = open_dungeon()
	d.progress = WorldProgress.new()
	var spots: Array[Vector2i] = [SPOT, Vector2i(14, 10), Vector2i(28, 22)]
	var a: Arena = fight_on(d, test_room(spots))
	var f: BossFight = a.boss
	var m: Player = player(d, "miner", f.pillars[1].centre() + Vector2(0, 20))
	var party: Array[Player] = [m]
	run_world(a, party, 1)
	f.frozen = true
	break_pillar(f, 0, m)
	run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1)
	break_pillar(f, 1, m)  # coming down when it dies, the miner under it
	f.hit(f.sim.hp_max, m.get_instance_id())
	check(not f.sim.alive(), "dead")
	check(f.pillars[0].fallen, "the broken one stays rubble")
	check(f.pillars[1].fallen and f.pillars[1].falling < 0, "the falling one lies as rubble at once")
	check(f.pillars[2].whole() and d.blockers.has(spots[2]), "the whole one stands")
	run_world(a, party, 120)
	check_eq(m.vitals.hp, Config.PLAYER_HP_MAX, "the quiet arena: nobody hurt by it")
	a.idle_tick()
	run_world(a, party, roundi(Config.BOSS["reset_ticks"]) + 10)
	check(f.pillars[0].fallen and f.pillars[1].fallen, "no reset after the kill: still rubble")


# --- no tile edit ---------------------------------------------------------------------------------------------------------------

func _check_no_tile_edits() -> void:
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var fresh: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	dungeon.progress = WorldProgress.new()
	var a: Arena = Arena.new()
	a.setup(dungeon, Config.DEFAULT_SEED)
	a.spawning = false
	a.threat_on = true
	a.boss = BossFight.new()
	a.boss.setup(a, Config.DEFAULT_SEED)
	var f: BossFight = a.boss
	check_eq(f.pillars.size(), 4, "seed 1: four pillars")
	var m: Player = player(dungeon, "miner", f.room.home_feet() + Vector2(0, 20))
	var party: Array[Player] = [m]
	run_world(a, party, 1)
	f.frozen = true
	for i: int in f.pillars.size():
		f.sim.pos = f.pillars[i].centre() + Vector2(6, 10)
		m.teleport(f.pillars[i].centre() + Vector2(0, 48))
		break_pillar(f, i, m)
		run_world(a, party, roundi(Config.BOSS_PILLARS["telegraph_ticks"]) + 1)
	check_eq(f.stat("debris_boss"), 4, "four debris on the boss")
	while f.sim.alive():
		f.hit(200, m.get_instance_id())
	run_world(a, party, 30)
	check(dungeon.blockers.is_empty(), "all rubble: nothing blocks")
	check_eq(dungeon.content_hash(), DungeonGen.GOLDEN_HASH, "the golden hash after a whole pillar fight")
	var same: bool = true
	for layer: int in dungeon.layers.size():
		if dungeon.layers[layer] != fresh.layers[layer]:
			same = false
			fail("layer %d differs from a fresh dungeon" % layer)
	check(same, "every layer byte for byte as generated")
	check_eq(m.inventory.count_of(Config.BOSS_RELIC), 1, "the relic in the inventory (no drop on the map)")
	check(dungeon.drops.is_empty(), "no drop")
