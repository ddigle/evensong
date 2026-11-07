extends "res://tests/base_test.gd"
## M11a, hunting (● gameplay-design §3.0 R11 archer row, §3.4; every number PROVISIONAL, README "임시값" M11a): every attack path reaches a
## creature (the basic attack of each class and weapon, the tier-1's damage and wear, every damaging skill, the piercing arrow once
## per creature, a thrown poison, zeal on all of them), walls still stop them, the drops go by the killing blow's class and kind
## (the archer against each other class, exact counts, a shot's owner, a poison's thrower, a killer gone), lie on the ground through
## the ordinary drop path and are picked up; the meat through the M6 drink path (a heal, refused at full HP, cut by a hit, nothing
## thrown, the host's path); the shop's two offers and prices; the items; main.tscn offline (the herd on the game clock, a bot's
## hunt, the kills' drops in the world, a session's arena with no herd, the flags and bot commands).

const TICK: float = 1.0 / 60.0
const WEAPONS: Dictionary[String, StringName] = {"paladin": &"sword", "miner": &"pickaxe", "herbalist": &"sickle", "archer": &"bow",
	"cleric": &"holy_light"}

var _nodes: Array[Node] = []
## The last skill that landed through wire().
var _landed: Skills.Landed


func run() -> Array[String]:
	_check_items()
	_check_basic_attacks()
	_check_walls()
	_check_corpses()
	_check_tier1()
	_check_skills()
	_check_piercing()
	_check_poison()
	_check_zeal()
	_check_drops()
	_check_pickup()
	_check_meat()
	_check_shop()
	_check_cli_and_bot()
	await _check_main()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------

## An open surface-kind map with no altar (no light).
static func open_world(size: Vector2i = Vector2i(60, 40)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_SURFACE
	return d


## An arena on `d` with a herd and nothing spawning.
static func arena_for(d: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	a.herd = Creatures.new()
	a.herd.setup(d, 1, false)
	return a


func player(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.skills_on = true
	p.potions_on = true
	_nodes.append(p)
	return p


static func tick(p: Player, f: NetProtocol.InputFrame = null) -> int:
	p.begin_tick()
	return p.step_frame(f if f != null else NetProtocol.InputFrame.new(), TICK)


static func ticks(p: Player, n: int) -> void:
	for i: int in n:
		tick(p)


## Holds a creature still (no flee, no wander) so a test can look at the numbers.
static func held(a: Arena, kind: StringName, at: Vector2) -> CreatureSim:
	var c: CreatureSim = a.herd.spawn(kind, at)
	c.idle_ticks = 1000000
	return c


## The arena and the herd step `n` ticks with `players` (a kill's drops go into the data). The herd meets nobody: a creature a test
## holds still stays there.
static func run_world(a: Arena, players: Array[Player], n: int) -> void:
	for i: int in n:
		for p: Player in players:
			tick(p)
		a.step(players)
		for e: EditLog.WorldEdit in a.herd.step([] as Array[Player]):
			EditLog.apply_to_data(a.data, e)


## The aim code from `p`'s aim origin to the middle of creature `c`.
static func aim_of(p: Player, c: CreatureSim) -> int:
	return Combat.aim_code(Creatures.aim_point(c) - Combat.aim_origin(p.sim_position))


## Main's offline wiring for a test player: a skill's impact lands on `a`, a potion's release goes into `a`.
func wire(p: Player, a: Arena, party: Array[Player]) -> void:
	p.party_provider = func() -> Array[Player]: return party
	p.action_impact.connect(_impact.bind(p, a, party))


func _impact(item: StringName, anim: int, _cell: Vector2i, p: Player, a: Arena, party: Array[Player]) -> void:
	if Skills.is_skill(item):
		_landed = Skills.land(p, item, a, party)
	elif Potions.is_drink(item):
		Potions.release(p, item, anim, a, 255, null)


static func press(p: Player, slot: int, mouse: Vector2) -> NetProtocol.InputFrame:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, mouse, true, false, false, false, false,
		slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	p.step_frame(f, TICK)
	return f


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


static func hold(p: Player, id: StringName) -> int:
	if slot_of(p.inventory, id) < 0:
		p.inventory.add(id, 1)
	var s: int = slot_of(p.inventory, id)
	p.inventory.select(s)
	return s


## The drops on `d` as "item:count" words, sorted.
static func drops_of(d: WorldData) -> String:
	var parts: PackedStringArray = []
	for id: int in d.drop_ids():
		parts.append("%s:%d" % [d.drops[id].item, d.drops[id].count])
	parts.sort()
	return "+".join(parts)


# --- the items ---------------------------------------------------------------------------------------

func _check_items() -> void:
	for id: StringName in [&"hide_fine", &"hide_worn"]:
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		check(def != null and def.kind == ItemDB.Kind.MATERIAL, "%s is a material" % id)
		check(not def.graded, "%s has no grade (two items, not a grade)" % id)
		check(FileAccess.file_exists(def.icon_path), "%s has its art" % id)
		check(ItemIcons.texture_for(id) != null, "%s has an icon" % id)
	check_ne(ItemDB.get_def(&"hide_fine").icon_path, ItemDB.get_def(&"hide_worn").icon_path, "the two hides look different")
	var meat: ItemDB.ItemDef = ItemDB.get_def(&"meat")
	check(meat != null and meat.is_food(), "the meat is food")
	check_eq(meat.icon_code, &"meat", "its icon is drawn in code")
	check(ItemIcons.texture_for(&"meat") != null, "its icon draws")
	check(not meat.is_potion(), "the meat is no potion")
	check(Potions.is_drink(&"meat") and not Potions.is_potion(&"meat"), "eaten through the drink path")
	check_eq(Potions.effect_of(&"meat"), -1, "no potion effect: it cannot splash")
	# Appended at the end (the wire sends items by index).
	var ids: Array[StringName] = ItemDB.ids()
	check_eq(ids.slice(54, 57), [&"hide_fine", &"hide_worn", &"meat"] as Array[StringName], "the new items come after money")
	check(ItemDB.index_of(ItemDB.MONEY) < ItemDB.index_of(&"hide_fine"), "after what was there")


# --- every attack path -----------------------------------------------------------------------------------

func _check_basic_attacks() -> void:
	for class_id: String in WEAPONS:
		var item: StringName = WEAPONS[class_id]
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var p: Player = player(d, class_id, Vector2(200, 200))
		var party: Array[Player] = [p]
		var c: CreatureSim = held(a, &"deer", Vector2(218, 200))
		var attack: Combat.Attack = Combat.attack_for(item)
		var dmg: int = attack.damage
		a.player_attack(p, item, aim_of(p, c), party)
		if attack.kind == Combat.Kind.MELEE:
			check_eq(c.hp, c.hp_max() - dmg, "%s's %s swing hits a creature in its arc" % [class_id, item])
		else:
			check_eq(a.shots.size(), 1, "%s's %s lets a shot go" % [class_id, item])
			for t: int in 10:
				a.step(party)
			check_eq(c.hp, c.hp_max() - dmg, "%s's %s shot hits a creature" % [class_id, item])
			check(a.shots.is_empty(), "the shot stopped at it")
			check_eq(a.stat("shot_creature"), 1, "stopped by the creature")
		check_eq(a.stat("creature_hits"), 1, "one creature hit counted")
		check_eq(c.flash_ticks, Config.HIT_FLASH_TICKS, "it flashes")
		check_eq(c.state, CreatureSim.State.FLEE, "it bolts")
		check_eq(a.stat("heretic_hits"), 0, "no heretic hit")
	# Melee outside the arc or reach misses; a shot past the box flies on.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var q: Player = player(d2, "paladin", Vector2(200, 200))
	var c2: CreatureSim = held(a2, &"hare", Vector2(218, 200))
	a2.player_attack(q, &"sword", Combat.aim_code(Vector2.LEFT), [q] as Array[Player])
	check_eq(c2.hp, c2.hp_max(), "a swing the other way misses")
	c2.pos = Vector2(200 + Combat.attack_for(&"sword").reach + 2.0, 200)
	a2.player_attack(q, &"sword", Combat.aim_code(Vector2.RIGHT), [q] as Array[Player])
	check_eq(c2.hp, c2.hp_max(), "a swing out of reach misses")
	# A heretic in the arc is hit too: one swing, both.
	c2.pos = Vector2(218, 200)
	var h: HereticSim = a2.spawn_heretic(Vector2(216, 196))
	a2.player_attack(q, &"sword", Combat.aim_code(Vector2.RIGHT), [q] as Array[Player])
	check_eq(h.hp, Config.HERETIC_HP - Combat.attack_for(&"sword").damage, "the swing hits the heretic")
	check(c2.hp < c2.hp_max(), "and the creature beside it")
	check_eq(h.threat_of(q.get_instance_id()), Combat.attack_for(&"sword").damage, "threat from the heretic's damage alone")
	# A shot hits what it meets first: a creature in front of a heretic takes it.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var r: Player = player(d3, "archer", Vector2(200, 200))
	var c3: CreatureSim = held(a3, &"deer", Vector2(240, 200))
	var h3: HereticSim = a3.spawn_heretic(Vector2(270, 200))
	a3.player_attack(r, &"bow", aim_of(r, c3), [r] as Array[Player])
	for t: int in 30:
		a3.step([r] as Array[Player])
	check(c3.hp < c3.hp_max(), "the creature in front took the arrow")
	check_eq(h3.hp, Config.HERETIC_HP, "the heretic behind it did not")
	# And the arrow goes through empty space beside a small hare: a box of its size, not a person's.
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var s: Player = player(d4, "archer", Vector2(200, 200))
	var c4: CreatureSim = held(a4, &"hare", Vector2(280, 200))
	a4.player_attack(s, &"bow", Combat.aim_code(Vector2.RIGHT), [s] as Array[Player])
	for t: int in 40:
		a4.step([s] as Array[Player])
	check_eq(c4.hp, c4.hp_max(), "a level shot flies over a hare's head (drawn 14 px up, the hare is 12 tall)")
	var feet: Vector2 = c4.pos
	check(Creatures.shot_hits(feet + Vector2(0.0, Config.SHOT_DRAW_LIFT_PX - c4.num_f("hit_height_px")), c4), "the top of its box")
	check(not Creatures.shot_hits(feet + Vector2(0.0, Config.SHOT_DRAW_LIFT_PX - c4.num_f("hit_height_px") - 1.0), c4), "a px above it")
	check(Combat.shot_hits_body(Vector2(100, 112), Vector2(100, 100)) == Combat.shot_hits_box(Vector2(100, 112), Vector2(100, 100),
		Config.BODY_HIT_RADIUS_PX, Config.BODY_HIT_HEIGHT_PX), "a body's rule is the box's")


func _check_walls() -> void:
	var d: WorldData = open_world()
	d.set_value(WorldData.Layer.WALL, Vector2i(14, 12), Walls.pack(Walls.KIND_STONE, 0))
	var a: Arena = arena_for(d)
	var y: float = 12.8 * Config.TILE
	var p: Player = player(d, "paladin", Vector2(14 * Config.TILE - 6, y))
	var c: CreatureSim = held(a, &"deer", Vector2(15 * Config.TILE + 3, y))
	check(p.sim_position.distance_to(c.pos) <= Combat.attack_for(&"sword").reach, "in the sword's reach")
	a.player_attack(p, &"sword", Combat.aim_code(Vector2.RIGHT), [p] as Array[Player])
	check_eq(c.hp, c.hp_max(), "a swing does not reach through a wall")
	d.set_value(WorldData.Layer.WALL, Vector2i(14, 12), 0)
	a.player_attack(p, &"sword", Combat.aim_code(Vector2.RIGHT), [p] as Array[Player])
	check_eq(c.hp, c.hp_max() - Combat.attack_for(&"sword").damage, "with the wall gone the same swing lands")
	c.hp = c.hp_max()
	d.set_value(WorldData.Layer.WALL, Vector2i(14, 12), Walls.pack(Walls.KIND_STONE, 0))
	var r: Player = player(d, "archer", Vector2(11.5 * Config.TILE, y))
	a.player_attack(r, &"bow", aim_of(r, c), [r] as Array[Player])
	for t: int in 60:
		a.step([r] as Array[Player])
	check_eq(c.hp, c.hp_max(), "an arrow stops at the wall")
	check_eq(a.stat("shot_wall"), 1, "stopped by it")
	# A wall between a burst's point and the creature shelters it.
	check(not a.creature_in_circle(Vector2(13.5 * Config.TILE, 12.8 * Config.TILE), 64.0, c), "a circle stops at a wall")
	check(a.creature_in_circle(c.pos + Vector2(10.0, 0.0), 64.0, c), "and reaches it on its side")


## M11 review: a corpse is no target: a shot flies on through it to what stands behind.
func _check_corpses() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var y: float = 12.8 * Config.TILE
	var r: Player = player(d, "archer", Vector2(10.0 * Config.TILE, y))
	var party: Array[Player] = [r]
	var dead: CreatureSim = held(a, &"deer", Vector2(14.0 * Config.TILE, y))
	var live: CreatureSim = held(a, &"deer", Vector2(18.0 * Config.TILE, y))
	var aim: int = aim_of(r, live)
	a.herd.hit(dead, dead.hp, 0)
	check(not dead.alive(), "it lies there")
	check(Creatures.shot_hits(Creatures.aim_point(dead), dead), "its box is still where it lay")
	check_eq(a.creature_at(Creatures.aim_point(dead)), null, "but a shot there hits nobody")
	a.player_attack(r, &"bow", aim, party)
	for t: int in 60:
		a.step(party)
	check(live.hp < live.hp_max(), "the arrow flew through the corpse to the deer behind it")


func _check_tier1() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "paladin", Vector2(200, 200))
	var party: Array[Player] = [p]
	var c: CreatureSim = held(a, &"deer", Vector2(218, 200))
	var st_slot: int = hold(p, &"sword_t1")
	var st: ItemStack = p.inventory.stack_at(st_slot)
	var dmg: int = Gear.attack_damage(st, Combat.attack_for(&"sword_t1").damage)
	check_eq(dmg, Combat.attack_for(&"sword").damage * Config.GEAR_T1_DAMAGE_PCT / 100, "the tier-1 sword's damage")
	a.player_attack(p, &"sword_t1", Combat.aim_code(Vector2.RIGHT), party, 255, dmg)
	check_eq(c.hp, c.hp_max() - dmg, "a tier-1 weapon lands its tier-1 damage on a creature")


func _check_skills() -> void:
	# Each row: class, slot, skill, weapon held, resource, where the creature stands, the damage it should take.
	var rows: Array[Array] = [
		["archer", Skills.Slot.IDENTITY, Skills.PIERCING_ARROW, &"", Vector2(60, 0), Skills.num_i(Skills.PIERCING_ARROW, "damage")],
		["miner", Skills.Slot.IDENTITY, Skills.GROUND_SLAM, &"", Vector2(24, 0), Skills.num_i(Skills.GROUND_SLAM, "damage")],
		["paladin", Skills.Slot.WEAPON, Skills.CRUSHING_BLOW, &"sword", Vector2(18, 0), Skills.num_i(Skills.CRUSHING_BLOW, "damage")],
		["archer", Skills.Slot.WEAPON, Skills.FAN_SHOT, &"bow", Vector2(60, 0), Skills.num_i(Skills.FAN_SHOT, "damage")],
		["cleric", Skills.Slot.WEAPON, Skills.HOLY_BURST, &"holy_light", Vector2(60, 0), Skills.num_i(Skills.HOLY_BURST, "damage")],
		["miner", Skills.Slot.WEAPON, Skills.HEAVY_STRIKE, &"pickaxe", Vector2(18, 0), Skills.num_i(Skills.HEAVY_STRIKE, "damage")],
		["herbalist", Skills.Slot.WEAPON, Skills.SWEEP, &"sickle", Vector2(18, 0), Skills.num_i(Skills.SWEEP, "damage")],
		["archer", Skills.Slot.SIGNATURE, Skills.ARROW_RAIN, &"", Vector2(60, 0), 26],
		["miner", Skills.Slot.SIGNATURE, Skills.ROCKFALL, &"", Vector2(60, 0), Skills.num_i(Skills.ROCKFALL, "damage")],
	]
	var seen: Array[StringName] = []
	for row: Array in rows:
		var class_id: String = row[0]
		var slot: int = row[1]
		var id: StringName = row[2]
		var weapon: StringName = row[3]
		var offset: Vector2 = row[4]
		var want: int = row[5]
		seen.append(id)
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var p: Player = player(d, class_id, Vector2(200, 200))
		var party: Array[Player] = [p]
		wire(p, a, party)
		var c: CreatureSim = held(a, &"deer", p.sim_position + offset)
		if not weapon.is_empty():
			hold(p, weapon)
		p.skills.resource = Skills.resource_cap(class_id)
		var mouse: Vector2 = Creatures.aim_point(c)
		press(p, slot, mouse)
		check_eq(p.action_skill, id, "%s's %s starts" % [class_id, id])
		ticks(p, Skills.impact_tick(id))
		run_world(a, party, 80)
		check_eq(c.hp_max() - c.hp, want, "%s lands %d on a creature" % [id, want])
		check(a.stat("creature_hits") >= 1, "%s counted" % id)
	# Every damaging skill of the slice is in the list (the README's nine).
	var damaging: Array[StringName] = [Skills.PIERCING_ARROW, Skills.GROUND_SLAM, Skills.CRUSHING_BLOW, Skills.FAN_SHOT, Skills.HOLY_BURST,
		Skills.HEAVY_STRIKE, Skills.SWEEP, Skills.ARROW_RAIN, Skills.ROCKFALL]
	for s: StringName in damaging:
		check(seen.has(s), "%s is tried" % s)
	# The stun of the blow and the rocks, the sweep's slow, the slam's push land on a creature.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var pal: Player = player(d2, "paladin", Vector2(200, 200))
	var party2: Array[Player] = [pal]
	wire(pal, a2, party2)
	var c2: CreatureSim = held(a2, &"deer", Vector2(218, 200))
	hold(pal, &"sword")
	press(pal, Skills.Slot.WEAPON, Creatures.aim_point(c2))
	ticks(pal, Skills.impact_tick(Skills.CRUSHING_BLOW))
	check(c2.stunned(), "the crushing blow stuns a creature")
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var her: Player = player(d3, "herbalist", Vector2(200, 200))
	var party3: Array[Player] = [her]
	wire(her, a3, party3)
	var c3: CreatureSim = held(a3, &"deer", Vector2(218, 200))
	hold(her, &"sickle")
	press(her, Skills.Slot.WEAPON, Creatures.aim_point(c3))
	ticks(her, Skills.impact_tick(Skills.SWEEP))
	check(c3.slowed(), "the sweep slows a creature")
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var min4: Player = player(d4, "miner", Vector2(200, 200))
	var party4: Array[Player] = [min4]
	wire(min4, a4, party4)
	var c4: CreatureSim = held(a4, &"deer", Vector2(224, 200))
	press(min4, Skills.Slot.IDENTITY, c4.pos)
	ticks(min4, Skills.impact_tick(Skills.GROUND_SLAM))
	check_eq(c4.pos.x, 224.0 + Skills.num_f(Skills.GROUND_SLAM, "push_px"), "the slam pushes a creature")
	# The taunt: nothing to a creature (heretics only).
	var d5: WorldData = open_world()
	var a5: Arena = arena_for(d5)
	var pal5: Player = player(d5, "paladin", Vector2(200, 200))
	var c5: CreatureSim = held(a5, &"deer", Vector2(220, 200))
	check_eq(a5.taunt(pal5, 64.0, 60), 0, "the taunt finds no heretic")
	check_eq(c5.state, CreatureSim.State.IDLE, "and leaves the creature as it was")


func _check_piercing() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "archer", Vector2(200, 200))
	var party: Array[Player] = [p]
	var dmg: int = 16
	var c1: CreatureSim = held(a, &"deer", Vector2(240, 200))
	var c2: CreatureSim = held(a, &"deer", Vector2(280, 200))
	var h: HereticSim = a.spawn_heretic(Vector2(260, 200))
	var s: Arena.Shot = a.skill_shot(p, Skills.PIERCING_ARROW, Combat.aim_code(Vector2(80, 0) + Vector2(0, 2)), dmg, 240.0, 260.0, true)
	for t: int in 60:
		a.step(party)
	check_eq(c1.hp_max() - c1.hp, dmg, "the piercing arrow hits the first creature once")
	check_eq(c2.hp_max() - c2.hp, dmg, "flies on to the second, once")
	check_eq(Config.HERETIC_HP - h.hp, dmg, "and the heretic between them")
	check(s.pierced.has(-c1.id) and s.pierced.has(h.id), "ids apart (a creature's negated)")


func _check_poison() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "herbalist", Vector2(200, 200))
	var party: Array[Player] = [p]
	var c: CreatureSim = held(a, &"hare", Vector2(240, 200))
	var f: Arena.Flask = a.throw_potion(p, &"potion_poison", ItemDB.Grade.COMMON, Vector2(240, 198))
	for t: int in 40:
		a.step(party)
	check(f.done, "the bottle landed")
	check(c.poisoned(), "a thrown poison reaches a creature")
	check_eq(a.stat("splash_creatures"), 1, "counted")
	check_eq(c.state, CreatureSim.State.FLEE, "it bolts from the thrower")
	# Killed by poison: the thrower's class decides (a herbalist: the worn hide).
	run_world(a, party, 300)
	check(not c.alive(), "ten HP go in five ticks of poison")
	check_eq(drops_of(d), "hide_worn:1", "the thrower's class decides the drops")
	check_eq(a.herd.kills[0].who, "herbalist", "the kill is the thrower's")
	# The poison's owner is the one who counts: an archer's poison (a test's, nobody else throws: Config.THROW_HERBALIST_ONLY) keeps the hide.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var r: Player = player(d2, "archer", Vector2(200, 200))
	var c2: CreatureSim = held(a2, &"hare", Vector2(240, 200))
	check(a2.herd.poison(c2, 20, 60, r.get_instance_id()), "poisoned")
	run_world(a2, [] as Array[Player], Config.POISON_INTERVAL_TICKS + 1)
	check_eq(drops_of(d2), "hide_fine:1+meat:1", "a death by an archer's poison is the archer's")
	# M11 review: a second splash takes the poison over: its thrower's class is the one that counts, either way round.
	for pair: Array in [["archer", "herbalist", "hide_worn:1"], ["herbalist", "archer", "hide_fine:1+meat:1"]]:
		var first_class: String = pair[0]
		var second_class: String = pair[1]
		var d3: WorldData = open_world()
		var a3: Arena = arena_for(d3)
		var by_first: Player = player(d3, first_class, Vector2(200, 200))
		var by_second: Player = player(d3, second_class, Vector2(200, 220))
		var c3: CreatureSim = held(a3, &"hare", Vector2(240, 200))
		a3.herd.poison(c3, 20, 60, by_first.get_instance_id())
		a3.herd.poison(c3, 20, 60, by_second.get_instance_id())
		run_world(a3, [] as Array[Player], Config.POISON_INTERVAL_TICKS + 1)
		check_eq(drops_of(d3), pair[2], "%s's poison, then %s's: the second's drops" % [first_class, second_class])


func _check_zeal() -> void:
	# Basic attack, skill, strike: zeal on all of them (Prayer.zeal_damage is in the damage before it reaches a creature).
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "paladin", Vector2(200, 200))
	var party: Array[Player] = [p]
	var c: CreatureSim = held(a, &"deer", Vector2(218, 200))
	p.skills.add_zeal(25, 600, true)
	var base: int = Combat.attack_for(&"sword").damage
	var want: int = Prayer.zeal_damage(base, p)
	check(want > base, "zeal raises it")
	a.player_attack(p, &"sword", Combat.aim_code(Vector2.RIGHT), party)
	check_eq(c.hp_max() - c.hp, want, "a swing: zeal on a creature")
	var r: Player = player(d, "archer", Vector2(200, 240))
	r.skills.add_zeal(25, 600, true)
	var c2: CreatureSim = held(a, &"deer", Vector2(240, 240))
	a.player_attack(r, &"bow", aim_of(r, c2), [r] as Array[Player])
	for t: int in 30:
		a.step([r] as Array[Player])
	check_eq(c2.hp_max() - c2.hp, Prayer.zeal_damage(Combat.attack_for(&"bow").damage, r), "an arrow: zeal on a creature")
	var m: Player = player(d, "miner", Vector2(400, 240))
	m.skills.add_zeal(25, 600, true)
	wire(m, a, [m] as Array[Player])
	var c3: CreatureSim = held(a, &"deer", Vector2(424, 240))
	press(m, Skills.Slot.IDENTITY, c3.pos)
	ticks(m, Skills.impact_tick(Skills.GROUND_SLAM))
	check_eq(c3.hp_max() - c3.hp, Prayer.zeal_damage(Skills.num_i(Skills.GROUND_SLAM, "damage"), m), "a skill: zeal on a creature")


# --- the drops ---------------------------------------------------------------------------------------------

func _check_drops() -> void:
	var want_hare: Dictionary[String, String] = {"archer": "hide_fine:1+meat:1"}
	var want_deer: Dictionary[String, String] = {"archer": "hide_fine:2+meat:2"}
	for class_id: String in Config.CLASSES:
		for kind: StringName in [&"hare", &"deer"]:
			var d: WorldData = open_world()
			var a: Arena = arena_for(d)
			var p: Player = player(d, class_id, Vector2(200, 200))
			var c: CreatureSim = held(a, kind, Vector2(218, 200))
			a.hit_creature(c, c.hp, p.get_instance_id())
			check(not c.alive(), "%s kills a %s" % [class_id, kind])
			for e: EditLog.WorldEdit in a.herd.take_edits():
				check(EditLog.apply_to_data(d, e), "the drop goes into the world by the edit path")
			var want: String = (want_hare if kind == &"hare" else want_deer).get(class_id, "hide_worn:1" if kind == &"hare" else "hide_worn:1+meat:1")
			check_eq(drops_of(d), want, "%s's %s: exact items and counts" % [class_id, kind])
			if class_id != Config.HUNTER_CLASS:
				check(not drops_of(d).contains("hide_fine"), "%s never gets the whole hide" % class_id)
			check_eq(a.herd.kills.size(), 1, "the kill is told")
			check_eq(a.herd.kills[0].who, class_id, "by class")
			check_eq(a.herd.kills[0].at, Aim.feet_cell(c.pos), "on its tile")
			for id: int in d.drop_ids():
				check_eq(d.drops[id].cell(), Aim.feet_cell(c.pos), "the drop lies on its tile")
	# Each rare kind by the archer: hide and meat (M11b's capture is what gives more).
	for kind2: StringName in [&"lamp_fox", &"silver_stag", &"ash_owl"]:
		var d2: WorldData = open_world()
		var a2: Arena = arena_for(d2)
		var r: Player = player(d2, "archer", Vector2(200, 200))
		var c2: CreatureSim = held(a2, kind2, Vector2(240, 200))
		a2.hit_creature(c2, c2.hp, r.get_instance_id())
		for e: EditLog.WorldEdit in a2.herd.take_edits():
			EditLog.apply_to_data(d2, e)
		check_eq(drops_of(d2), Creatures.describe_drops(Creatures.drops_for(kind2, "archer")), "%s: its row" % kind2)
	# Only the killing blow counts: a paladin's hit then an archer's arrow = the archer's hide, and the other way round.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var pal: Player = player(d3, "paladin", Vector2(200, 200))
	var arc: Player = player(d3, "archer", Vector2(200, 260))
	var c3: CreatureSim = held(a3, &"deer", Vector2(218, 200))
	a3.hit_creature(c3, c3.hp - 1, pal.get_instance_id())
	a3.hit_creature(c3, 1, arc.get_instance_id())
	for e: EditLog.WorldEdit in a3.herd.take_edits():
		EditLog.apply_to_data(d3, e)
	check_eq(drops_of(d3), "hide_fine:2+meat:2", "the archer's last blow keeps the hide whole")
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var pal4: Player = player(d4, "paladin", Vector2(200, 200))
	var arc4: Player = player(d4, "archer", Vector2(200, 260))
	var c4: CreatureSim = held(a4, &"deer", Vector2(218, 200))
	a4.hit_creature(c4, c4.hp - 1, arc4.get_instance_id())
	a4.hit_creature(c4, 1, pal4.get_instance_id())
	for e: EditLog.WorldEdit in a4.herd.take_edits():
		EditLog.apply_to_data(d4, e)
	check_eq(drops_of(d4), "hide_worn:1+meat:1", "the paladin's last blow damages it")
	# An arrow's owner, a killer gone, nobody.
	var d5: WorldData = open_world()
	var a5: Arena = arena_for(d5)
	var s: Player = player(d5, "archer", Vector2(200, 200))
	var c5: CreatureSim = held(a5, &"hare", Vector2(240, 200))
	a5.player_attack(s, &"bow", aim_of(s, c5), [s] as Array[Player])
	for t: int in 20:
		a5.step([s] as Array[Player])
	check_eq(a5.herd.kills.size(), 1, "the arrow killed the hare")
	check_eq(a5.herd.kills[0].who, "archer", "the arrow's owner's class")
	var d6: WorldData = open_world()
	var a6: Arena = arena_for(d6)
	var c6: CreatureSim = held(a6, &"hare", Vector2(240, 200))
	var gone: Player = Player.new()
	gone.setup(d6, "archer", Vector2(200, 200))
	var gone_id: int = gone.get_instance_id()
	gone.free()
	a6.hit_creature(c6, c6.hp, gone_id)
	check_eq(a6.herd.kills[0].who, "", "a killer gone counts as nobody")
	check_eq(Creatures.describe_drops(a6.herd.kills[0].drops), "hide_worn:1", "no class, no whole hide")
	var c7: CreatureSim = held(a6, &"hare", Vector2(280, 200))
	a6.hit_creature(c7, c7.hp, 0)
	check_eq(a6.herd.kills[1].who, "", "no killer at all")
	# A dead one takes nothing more and gives nothing more.
	var was: int = a6.herd.edits.size()
	check(not a6.herd.hit(c7, 5, 0), "a corpse takes no hit")
	check_eq(a6.herd.edits.size(), was, "and drops nothing more")
	# The world's drop cap: the rest is lost, counted.
	var d7: WorldData = open_world()
	var a7: Arena = arena_for(d7)
	for i: int in Config.MAX_DROPS - 1:
		d7.drops[i + 1] = WorldData.Drop.new(i + 1, &"stone_a", 1, 0, Vector2i(8, 8))
	var r7: Player = player(d7, "archer", Vector2(200, 200))
	var c8: CreatureSim = held(a7, &"deer", Vector2(240, 200))
	a7.hit_creature(c8, c8.hp, r7.get_instance_id())
	check_eq(a7.herd.edits.size(), 1, "one more fits")
	check_eq(a7.herd.stat("drops_lost"), 1, "the other is lost and counted")
	# Never in a doorway (F there works the door, no drop could be picked up) nor on a gatherable or another drop: the nearest free tile.
	var d9: WorldData = open_world()
	var a9: Arena = arena_for(d9)
	var door: Vector2i = Vector2i(20, 12)
	d9.set_value(WorldData.Layer.WALL, door, Walls.pack(Walls.KIND_DOOR_OPEN, 0))
	var c10: CreatureSim = held(a9, &"hare", Arena.spawn_feet(door))
	check_eq(a9.herd.drop_cell(c10.pos) != door, true, "not on an open door's tile")
	a9.hit_creature(c10, c10.hp, 0)
	for e: EditLog.WorldEdit in a9.herd.take_edits():
		check(EditLog.apply_to_data(d9, e), "the edit applies")
		check_eq(Building.door_cell(d9, e.drop.cell()), Walls.NO_CELL, "a tile F can pick it up from")
	var plant: Vector2i = Vector2i(30, 20)
	d9.set_value(WorldData.Layer.VEGETATION, plant, WorldItems.value_of(&"wild_healing"))
	check_ne(a9.herd.drop_cell(Arena.spawn_feet(plant)), plant, "not on a gatherable")
	var d10: WorldData = open_world()
	var a10: Arena = arena_for(d10)
	var c11: CreatureSim = held(a10, &"hare", Vector2(200, 204))
	var free_cell: Vector2i = a10.herd.drop_cell(c11.pos)
	check_eq(free_cell, Aim.feet_cell(c11.pos), "a free tile: its own")
	# Two drops lie apart on the tile (both show) and stay on it.
	var d8: WorldData = open_world()
	var a8: Arena = arena_for(d8)
	var r8: Player = player(d8, "archer", Vector2(200, 200))
	var c9: CreatureSim = held(a8, &"deer", Vector2(240, 204))
	a8.hit_creature(c9, c9.hp, r8.get_instance_id())
	var es: Array[EditLog.WorldEdit] = a8.herd.take_edits()
	check_eq(es.size(), 2, "two rows, two drops")
	check_eq(absi(es[0].drop.pos.x - es[1].drop.pos.x), Config.CREATURE_DROP_SPREAD_PX, "apart")
	check_ne(es[0].drop.id, es[1].drop.id, "two ids, though neither is in the world yet")
	check_eq(es[0].drop.cell(), es[1].drop.cell(), "on one tile")
	check_eq(a8.herd.waiting.size(), 1, "its place waits for the respawn")


func _check_pickup() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "archer", Vector2(200, 200))
	var c: CreatureSim = held(a, &"deer", Vector2(218, 196))
	a.hit_creature(c, c.hp, p.get_instance_id())
	for e: EditLog.WorldEdit in a.herd.take_edits():
		EditLog.apply_to_data(d, e)
	var tile: Vector2i = Aim.feet_cell(c.pos)
	var feet: Vector2 = Arena.spawn_feet(tile + Vector2i(1, 0))
	var o1: WorldItems.Outcome = WorldItems.pickup(d, feet, "archer", p.inventory, tile)
	check(o1.ok(), "F picks the first up: %s" % o1.why)
	for e: EditLog.WorldEdit in o1.edits:
		EditLog.apply_to_data(d, e)
	var o2: WorldItems.Outcome = WorldItems.pickup(d, feet, "archer", p.inventory, tile)
	check(o2.ok(), "F picks the second up")
	for e: EditLog.WorldEdit in o2.edits:
		EditLog.apply_to_data(d, e)
	check_eq(p.inventory.count_of(&"hide_fine"), 2, "two whole hides in the bag")
	check_eq(p.inventory.count_of(&"meat"), 2, "two meats")
	check(d.drops.is_empty(), "nothing left")


# --- the meat -----------------------------------------------------------------------------------------------

## A click with `mouse` beside the player.
static func click(p: Player) -> int:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, p.sim_position + Vector2(0, 20), true, true, true)
	return p.step_frame(f, TICK)


func _check_meat() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "paladin", Vector2(200, 200))
	wire(p, a, [p] as Array[Player])
	var refused: Array[String] = []
	p.potion_refused.connect(func(what: String, why: String) -> void: refused.append("%s:%s" % [what, why]))
	p.inventory.add(&"meat", 3)
	p.inventory.select(slot_of(p.inventory, &"meat"))
	# Full HP: refused, nothing used.
	click(p)
	check_eq(p.action_anim, -1, "full HP: no action")
	check_eq(refused, ["drink:%s" % Potions.WHY_FULL_HP] as Array[String], "refused as a drink is")
	check_eq(p.inventory.count_of(&"meat"), 3, "nothing used")
	# Hurt: left click plays the drink's action and the heal lands on its frame.
	p.vitals.hp = 50
	ticks(p, 2)
	click(p)
	check_eq(p.action_anim, Config.DRINK_ANIM, "a click plays the drink's action")
	check_eq(p.vitals.hp, 50, "not healed yet")
	ticks(p, Potions.impact_tick(Config.DRINK_ANIM) - 1)
	check_eq(p.vitals.hp, 50, "one tick before the effect frame")
	ticks(p, 1)
	check_eq(p.vitals.hp, 50 + Config.MEAT_HEAL_HP, "the meat heals its HP on the effect frame")
	check_eq(p.inventory.count_of(&"meat"), 2, "one eaten")
	check(Config.MEAT_HEAL_HP < Config.POTION_HEAL_HP[ItemDB.Grade.COMMON], "less than a healing potion")
	ticks(p, 60)
	# Not past the maximum.
	p.vitals.hp = Config.PLAYER_HP_MAX - 3
	click(p)
	ticks(p, Potions.impact_tick(Config.DRINK_ANIM))
	check_eq(p.vitals.hp, Config.PLAYER_HP_MAX, "never past the maximum")
	ticks(p, 60)
	# A hit before the frame cuts it: nothing used.
	p.vitals.hp = 50
	click(p)
	var meat_left: int = p.inventory.count_of(&"meat")
	p.take_hit(5)
	ticks(p, 30)
	check_eq(p.inventory.count_of(&"meat"), meat_left, "a hit cuts it off: nothing used")
	check_eq(p.vitals.hp, 45, "and no heal")
	# Holding the button does not repeat (one bite per click, as a drink).
	ticks(p, 60)
	# Nobody throws it.
	check_eq(Potions.throw_refusal("herbalist", ItemStack.new(&"meat", 1, 0)), Potions.WHY_NOT_POTION, "the herbalist cannot throw meat")
	check(not Skills.throw_picks_ally(&"meat"), "it is no thrown heal")
	# It never affects the splash table.
	check_eq(Potions.drink_refusal(&"hide_fine", 0, p.vitals), Potions.WHY_NOT_POTION, "a hide is no food")
	# A down player eats nothing.
	var v: Vitals = Vitals.new()
	v.life = Vitals.Life.DOWN
	check_eq(Potions.drink_refusal(&"meat", 0, v), Potions.WHY_NOT_UP, "not while down")
	# The host's path: a USE of a hotbar slot holding meat is a drink.
	var inv_slot: int = slot_of(p.inventory, &"meat")
	if inv_slot >= 0 and inv_slot < p.inventory.hotbar_size:
		check(SessionHost._potion_in(p, inv_slot), "the host takes the meat's USE as a drink")
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	f.op = NetProtocol.Op.USE
	f.item = &"meat"
	check_eq(SessionHost._action_op_name(f), "drink", "and counts it as one")
	check_eq(Player.impact_tick_of(&"meat", Config.DRINK_ANIM), Potions.impact_tick(Config.DRINK_ANIM), "its effect frame is the drink's")


# --- the shop ---------------------------------------------------------------------------------------------------

func _check_shop() -> void:
	check_eq(Shop.offers().size(), 13, "the two offers: 13")
	check_eq(Shop.offer_at(11).item, &"hide_worn", "the shop's 일반 가죽 (● R11) at the end")
	check_eq(Shop.offer_at(12).item, &"meat", "and the meat")
	check_eq(Shop.offer_of(&"hide_fine"), null, "● the whole hide is not for sale: the archer's alone")
	check(Shop.pays_for(&"hide_worn") < Shop.price_of(&"hide_worn"), "never as much paid as asked (hide)")
	check(Shop.pays_for(&"meat") < Shop.price_of(&"meat"), "never as much paid as asked (meat)")
	check(Shop.pays_for(&"hide_fine") > Shop.pays_for(&"hide_worn"), "the whole hide fetches more than the worn one")
	var shop: Shop = Shop.new()
	var inv: Inventory = Inventory.new()
	inv.add(ItemDB.MONEY, 100)
	var bought: Shop.Deal = shop.buy(inv, 11)
	check(bought.ok() and inv.count_of(&"hide_worn") == 1, "a worn hide bought: %s" % bought.why)
	var ate: Shop.Deal = shop.buy(inv, 12)
	check(ate.ok() and inv.count_of(&"meat") == 1, "a meat bought: %s" % ate.why)
	var money: int = Shop.money_in(inv)
	var sold: Shop.Deal = shop.sell(inv, slot_of(inv, &"hide_worn"), false)
	check(sold.ok(), "the worn hide sells: %s" % sold.why)
	check_eq(Shop.money_in(inv), money + Shop.pays_for(&"hide_worn"), "at its price")
	inv.add(&"hide_fine", 1)
	var fine: Shop.Deal = shop.sell(inv, slot_of(inv, &"hide_fine"), false)
	check(fine.ok(), "a whole hide sells: %s" % fine.why)
	# The stock comes back like every offer.
	check_eq(shop.left_at(11), Shop.offer_at(11).cap - 1, "one fewer in stock")
	# The offers' stocks are small like the others (no sustained supply).
	check(Shop.offer_at(11).cap <= 5 and Shop.offer_at(12).cap <= 5, "a small stock")


# --- flags and bot --------------------------------------------------------------------------------------------

func _check_cli_and_bot() -> void:
	var o: CliOptions = CliOptions.parse(PackedStringArray(["--test-creature=hare:2,deer:1", "--test-no-creatures"]))
	check(o.errors.is_empty(), "good flags: %s" % ", ".join(o.errors))
	check_eq(o.test_creatures, [[&"hare", 2], [&"deer", 1]] as Array[Array], "the rows")
	check(o.test_no_creatures, "natural spawns off")
	for bad: String in ["--test-creature=", "--test-creature=hare", "--test-creature=wolf:1", "--test-creature=hare:0",
			"--test-creature=hare:99", "--test-creature=hare:x", "--test-creature=hare:1,deer"]:
		check(not CliOptions.parse(PackedStringArray([bad])).errors.is_empty(), "%s is refused" % bad)
	check_eq(NetBot.new().parse("aimprey;hunt:60;hunt:60,1;hunt:60,1,24;waitprey:0;waitprey:2,300;creature:deer,10,12"), "", "the bot's commands parse")
	for bad2: String in ["aimprey:1", "hunt", "hunt:x", "hunt:0", "hunt:1,2,3,4", "waitprey", "waitprey:x", "creature:wolf,1,2", "creature:hare,1",
			"creature:hare,x,2"]:
		check_ne(NetBot.new().parse(bad2), "", "%s is refused" % bad2)
	var bot: NetBot = NetBot.new()
	bot.parse("aimprey;hunt:5,0,20")
	bot.prey = [Vector2(100, 0), Vector2(30, 0)] as Array[Vector2]
	var a: NetBot.Action = bot.step(Vector2.ZERO)
	check(a.aiming, "aimprey aims")
	check_eq(a.mouse, Vector2(30, 0), "at the nearest")
	check_eq(a.dir, Vector2i(1, 0), "hunt walks up when past its px")
	check(not a.use_held, "no swing yet")
	var b: NetBot.Action = bot.step(Vector2(15, 0))
	check(b.use_held, "within its px it holds the use button")
	bot.prey = [] as Array[Vector2]
	var c: NetBot.Action = bot.step(Vector2(15, 0))
	check(not c.use_held and bot.finished, "nothing left: the bot goes on")
	var bot2: NetBot = NetBot.new()
	bot2.parse("waitprey:1,3;creature:hare,7,8")
	bot2.prey = [Vector2.ZERO, Vector2.ONE] as Array[Vector2]
	bot2.step(Vector2.ZERO)
	check(not bot2.finished, "waitprey waits")
	bot2.prey = [Vector2.ZERO] as Array[Vector2]
	bot2.step(Vector2.ZERO)
	var d: NetBot.Action = bot2.step(Vector2.ZERO)
	check_eq(d.creature, &"hare", "creature: the kind")
	check_eq(d.creature_cell, Vector2i(7, 8), "and the tile")


# --- main.tscn ---------------------------------------------------------------------------------------------------

## M11a's rule through offline Main: a live creature is a body. M11 review: under the altar's footprint too, the way players are.
func _check_main_bodies(main: Main, herd: Creatures) -> void:
	main.spawn("paladin")
	var p: Player = main.player
	p.local_input = false
	var at: Vector2 = main.world.data.altar_center_px() + Vector2(-Config.safe_radius_px() - 80.0, 0.0)
	var feet_cell: Vector2i = Aim.feet_cell(at)
	p.teleport(Arena.spawn_feet(feet_cell))
	# A blocking station on its tile: refused; with it gone, it goes down.
	var target: Vector2i = feet_cell + Vector2i(0, 1)
	var deer: CreatureSim = herd.spawn(&"deer", Arena.spawn_feet(target))
	herd.rest(deer)
	deer.state_ticks = -100000
	p.inventory.add(&"alchemy_table", 1)
	var slot: int = slot_of(p.inventory, &"alchemy_table")
	main._on_place_requested(slot, target)
	check_eq(p.inventory.count_of(&"alchemy_table"), 1, "main: a station is not put down on a creature")
	check_eq(main.world.data.get_value(WorldData.Layer.PLACEABLE, target), WorldData.PLACEABLE_NONE, "main: nothing there")
	herd.list.erase(deer)
	main._on_place_requested(slot, target)
	check_eq(p.inventory.count_of(&"alchemy_table"), 0, "main: with the creature gone it goes down")
	for x: int in range(target.x - 1, target.x + 2):
		main.world.apply_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(x, target.y), WorldData.PLACEABLE_NONE))
	# The altar: lifted, then put down on a resting creature: refused, the ghost says so.
	main.pick_up_altar(p)
	check(p.carrying_altar, "main: carried")
	var rect: Rect2i = AltarMove.place_rect(p.sim_position, target)
	p.aim_cell = target
	main._show_altar_ghost(p)
	check(main._altar_ghost_ok, "main: the ghost is green on open ground")
	var deer2: CreatureSim = herd.spawn(&"deer", Arena.spawn_feet(rect.get_center()))
	herd.rest(deer2)
	deer2.state_ticks = -100000
	check(main.altar_bodies(Config.MAP_SURFACE).has(deer2.pos), "main: its feet count")
	check_eq(main.creatures_on(Config.MAP_DUNGEON), [] as Array[Vector2], "main: no creature down there")
	main._show_altar_ghost(p)
	check(not main._altar_ghost_ok, "main: the ghost goes red at once over a creature")
	check_eq(main.place_altar(p, target), WorldItems.WHY_BODY, "main: the altar is not put down on a creature")
	check(p.carrying_altar, "main: still carried")
	# Going down, the same: a creature stands where it would have come down.
	herd.list.erase(deer2)
	var would: Rect2i = AltarMove.set_down_fallback(main.world.data, p.sim_position, main.world.last_altar_rect, main.bodies_on(Config.MAP_SURFACE),
		main.heretics_on(Config.MAP_SURFACE))
	var deer3: CreatureSim = herd.spawn(&"deer", Arena.spawn_feet(would.get_center()))
	herd.rest(deer3)
	deer3.state_ticks = -100000
	check(main.set_altar_down(p), "main: the carrier's set down")
	check(main.world.data.altar_rect != would, "main: not on the place it would have taken")
	check(not AltarMove.covers_a_body(main.world.data.altar_rect, [deer3.pos] as Array[Vector2]), "main: not on the creature (%s)" % main.world.data.altar_rect)
	herd.list.erase(deer3)
	main.step_creatures()
	await await_frames(1)


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	check(herd != null, "offline: the surface arena has a herd")
	check_eq(main.arenas[Config.MAP_DUNGEON].herd, null, "the dungeon's has none")
	var caps: int = 0
	for kind: StringName in Config.CREATURES:
		caps += Creatures.cap_of(kind)
	check_eq(herd.alive_count(), caps, "at their caps (M11b: the rare kinds in their zone)")
	check_eq(herd.data, main.world.data, "on the surface's data")
	# The herd's clock: every tick, with the local player on the surface or below.
	var was: int = herd.clock
	main.step_creatures()
	check_eq(herd.clock, was + 1, "a tick")
	var view: CombatView = main.combat_views[Config.MAP_SURFACE]
	check_eq(view.creatures.size(), herd.list.size(), "the view has a node per creature")
	main.spawn("archer")
	var p: Player = main.player
	p.local_input = false
	# Kill one with the local player's arrow: the drop lands in the world and shows.
	herd.spawning = false
	var c: CreatureSim = herd.spawn(&"hare", main.world.data.altar_center_px() + Vector2(0.0, Config.safe_radius_px() + 32.0))
	c.idle_ticks = 100000
	c.hp = 1
	p.teleport(c.pos + Vector2(0.0, -c.num_f("alert_px") - 8.0))
	var bow_slot: int = slot_of(p.inventory, &"bow")
	p.inventory.select(bow_slot)
	var mouse: Vector2 = Creatures.aim_point(c)
	for t: int in 90:
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, mouse, true, t == 0, t == 0, TICK)
		main.step_combat(TICK)
		main.step_creatures()
		if not c.alive():
			break
	check(not c.alive(), "main: the arrow killed the hare")
	var here: Array[WorldData.Drop] = main.world.data.drops_at(Aim.feet_cell(c.pos))
	check_eq(here.size(), 2, "main: its drops lie on its tile")
	var items: Array[StringName] = []
	for dr: WorldData.Drop in here:
		items.append(dr.item)
	items.sort()
	check_eq(items, [&"hide_fine", &"meat"] as Array[StringName], "main: the archer's hide and meat")
	check_eq(main.world.items.verify()["mismatches"], 0, "main: the view shows them")
	check(herd.kills.is_empty(), "main: the kill was logged and cleared")
	# Every tier-1 weapon's wear on a hit (the same swing rule as a heretic's).
	main.spawn("paladin")
	var q: Player = main.player
	q.local_input = false
	q.inventory.add(&"sword_t1", 1)
	var s: int = slot_of(q.inventory, &"sword_t1")
	q.inventory.select(s)
	var st: ItemStack = q.inventory.stack_at(s)
	var dur: int = st.durability
	var deer: CreatureSim = herd.spawn(&"deer", main.world.data.altar_center_px() + Vector2(0.0, Config.safe_radius_px() + 40.0))
	deer.idle_ticks = 100000
	q.teleport(deer.pos + Vector2(0.0, -18.0))
	var hp: int = deer.hp
	var aim: Vector2 = Creatures.aim_point(deer)
	for t2: int in 40:
		q.begin_tick()
		q.tick_controls(Vector2i.ZERO, aim, true, t2 == 0, t2 == 0, TICK)
		main.step_combat(TICK)
	check_eq(deer.hp, hp - Gear.attack_damage(st, Combat.attack_for(&"sword_t1").damage), "main: a tier-1 sword's damage on a creature")
	check_eq(st.durability, dur - Config.GEAR_WEAR_PER_ATTACK, "main: it wears one swing's wear, as on a heretic")
	await _check_main_bodies(main, herd)
	# The dungeon: the local player away, the herd's clock runs on.
	main.spawn("paladin")
	main.player.local_input = false
	main.travel(Config.MAP_DUNGEON)
	main.arenas[Config.MAP_DUNGEON].spawning = false
	var c0: int = herd.clock
	main.step_creatures()
	check_eq(herd.clock, c0 + 1, "main: the local player below: the herd's clock runs on (game time)")
	# Bodies: a creature under a wall piece is someone standing there.
	main.travel(Config.MAP_SURFACE)
	var bodies: Array[Vector2] = main._other_bodies()
	check(bodies.has(herd.list[0].pos) or not herd.list[0].alive(), "main: the build rules see the creatures")
	# Eating through Main: a click, the effect frame, the heal, one gone.
	var eater: Player = main.player
	eater.inventory.add(&"meat", 2)
	eater.inventory.select(slot_of(eater.inventory, &"meat"))
	eater.vitals.hp = 40
	for t3: int in Potions.impact_tick(Config.DRINK_ANIM) + 1:
		eater.begin_tick()
		eater.tick_controls(Vector2i.ZERO, eater.sim_position + Vector2(0, 30), true, t3 == 0, t3 == 0, TICK)
	check_eq(eater.vitals.hp, 40 + Config.MEAT_HEAL_HP, "main: the meat eaten by a click")
	check_eq(eater.inventory.count_of(&"meat"), 1, "main: one gone")
	# A test creature near the local player, on the ring outside the alert radius of the prey.
	var before: int = herd.alive_count(&"deer")
	var options: Array[Array] = [[&"deer", 1]]
	main.put_test_creatures(options)
	check_eq(herd.alive_count(&"deer"), before + 1, "main: --test-creature puts one down")
	var last: CreatureSim = herd.list[herd.list.size() - 1]
	check(Movement.can_stand(main.world.data, last.pos) and herd.can_walk(last.pos), "main: where it may stand")
	check(last.pos.distance_to(main.player.sim_position) > last.num_f("alert_px"), "main: outside its alert radius")
	# A world with no herd (the dungeon's arena) leaves every attack as it was.
	var a2: Arena = Arena.new()
	a2.setup(main.world.data, 1)
	a2.spawning = false
	var who: Player = player(main.world.data, "paladin", main.world.data.altar_center_px() + Vector2(0.0, Config.safe_radius_px() + 40.0))
	a2.player_attack(who, &"sword", 0, [who] as Array[Player])
	check_eq(a2.stat("creature_hits"), 0, "no herd: nothing to hit, no error")
