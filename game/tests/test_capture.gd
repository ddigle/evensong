extends "res://tests/base_test.gd"
## M11b, the rare creatures' rule and the snare (● game-concept §3, §4 "희귀 생물 포획·사냥은 아처만"; ○ gameplay-design §3.4; every number PROVISIONAL,
## README "임시값" M11b): every attack path by anyone but the archer does nothing to a rare creature (written out path by path: no damage, no
## flash, no bolt, no stun, slow, push or poison, the refused mark) and works for the archer; prey can be hunted by anyone and captured by
## nobody; each refusal of the snare with exactly nothing spent, one at a time (class, no snare, nothing there, prey, reach, wall, HP; down,
## dead, praying, carrying the altar, a panel open); a capture spends exactly one snare on its impact frame and gives exactly the
## material and the entry, its place waits for the respawn, no drop; what cuts a throw off (a hit, the creature killed meanwhile, the snare
## gone) spends nothing; a full inventory; killing a rare creature gives hide and meat and no entry; the HP the arrows can land on; the
## creature's marks (notch, ring, rope, refused cross); Main's wiring in main.tscn.

const TICK: float = 1.0 / 60.0
const RARE: Array[StringName] = [&"lamp_fox", &"silver_stag", &"ash_owl"]
const OTHERS: Array[String] = ["paladin", "miner", "cleric", "herbalist"]

var _nodes: Array[Node] = []
var _landed: Capture.Landed
var _refused: String = ""
var _refused_at: CreatureSim


func run() -> Array[String]:
	_check_table()
	_check_items()
	_check_shut_out()
	_check_prey_open()
	_check_target()
	_check_refusals()
	_check_states()
	_check_threshold()
	_check_success()
	_check_full_inventory()
	_check_cut_off()
	_check_kill()
	_check_arrows_land()
	_check_marks()
	await _check_main()
	for n: Node in _nodes:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers ---------------------------------------------------------------------------------------

static func open_world(size: Vector2i = Vector2i(60, 40)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_SURFACE
	return d


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


## Main's offline wiring for a test player.
func wire(p: Player, a: Arena) -> void:
	p.capture_on = true
	p.herd_provider = func() -> Creatures: return a.herd
	p.capture_refused.connect(_on_refused)
	p.action_started.connect(_on_started.bind(p, a))
	p.action_impact.connect(_on_impact.bind(p, a))


func _on_refused(why: String, c: CreatureSim) -> void:
	_refused = why
	_refused_at = c


func _on_started(item: StringName, _anim: int, _cell: Vector2i, p: Player, a: Arena) -> void:
	if Capture.is_snare(item):
		Capture.begin(p, a.herd, a.herd.by_id(p.action_capture))


func _on_impact(item: StringName, _anim: int, _cell: Vector2i, p: Player, a: Arena) -> void:
	if Capture.is_snare(item):
		_landed = Capture.land(p, a.herd, p.action_capture)


## Holds a creature still (no flee, no wander).
static func held_still(a: Arena, kind: StringName, at: Vector2) -> CreatureSim:
	var c: CreatureSim = a.herd.spawn(kind, at)
	c.idle_ticks = 1000000
	return c


## A player with `n` snares selected.
static func with_snares(p: Player, n: int) -> void:
	p.inventory.add(Capture.SNARE, n)
	for i: int in p.inventory.size():
		var s: ItemStack = p.inventory.stack_at(i)
		if s != null and s.id == Capture.SNARE:
			p.inventory.select(i)


## One left click (pressed this tick) at `mouse`.
static func click(p: Player, mouse: Vector2) -> NetProtocol.InputFrame:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, mouse, true, true, true)
	p.step_frame(f, TICK)
	return f


## `n` empty ticks of `p` and the herd; what the herd lays down goes into the world.
static func ticks(p: Player, a: Arena, n: int) -> void:
	for i: int in n:
		p.begin_tick()
		p.step_frame(NetProtocol.InputFrame.new(), TICK)
		for e: EditLog.WorldEdit in a.herd.step([] as Array[Player]):
			EditLog.apply_to_data(a.data, e)


## What `inv` holds, as a line (nothing spent = the same line).
static func holds(p: Player) -> String:
	return p.inventory.describe()


func _check_table() -> void:
	check_eq(Config.CAPTURE_HP_PCT, 30, "the threshold (the design's default)")
	check_eq(Config.CAPTURE_MATERIAL_COUNT, 1, "one material a capture")
	check_eq(Config.RARE_MATERIAL, &"rare_essence", "the material")
	check_eq(Capture.impact_tick(), Config.CAPTURE_IMPACT_FRAME * Config.ACTION_FRAME_TICKS, "the impact tick")
	check(Capture.impact_tick() < Player.action_ticks(Config.CAPTURE_ANIM), "inside the throw")
	check_eq(Player.impact_tick_of(Capture.SNARE, Config.CAPTURE_ANIM), Capture.impact_tick(), "the player's impact tick")
	# It is a burst's rest away: reachable from a walk (Config.WALK_SPEED) while a creature rests.
	for kind: StringName in RARE:
		var row: Dictionary = Config.CREATURES[kind]
		var rest: int = row["rest_ticks"]
		check(Config.CAPTURE_REACH_PX < Config.WALK_SPEED * rest / Config.NET_TICK_RATE, "%s: a rest is long enough to walk into reach" % kind)


func _check_items() -> void:
	var snare: ItemDB.ItemDef = ItemDB.get_def(Capture.SNARE)
	if check(snare != null, "the snare is an item"):
		check_eq(snare.kind, ItemDB.Kind.CONSUMABLE, "used up")
		check_eq(snare.stack_max, Config.STACK_SNARE, "its stack")
		check_eq(snare.action, -1, "no tool action: the click is Capture's")
	var essence: ItemDB.ItemDef = ItemDB.get_def(Config.RARE_MATERIAL)
	if check(essence != null, "the material is an item"):
		check_eq(essence.kind, ItemDB.Kind.MATERIAL, "a material")
	var armor: ItemDB.ItemDef = ItemDB.get_def(&"armor_rare")
	if check(armor != null, "the armour is an item"):
		check(armor.is_armor(), "armour")
		check_eq(armor.stack_max, 1, "it does not stack")
		check_eq(armor.durability, Config.GEAR_DURABILITY[&"armor_rare"], "its durability")
	check_eq(ItemDB.index_of(Capture.SNARE), 57, "appended after the meat (the wire sends items by index)")
	check_eq(ItemDB.index_of(Config.RARE_MATERIAL), 58, "then the material")
	check_eq(ItemDB.index_of(&"armor_rare"), 59, "then the armour")
	for id: StringName in [Capture.SNARE, Config.RARE_MATERIAL, &"armor_rare"]:
		var tex: Texture2D = ItemIcons.texture_for(id)
		check(tex != null and Vector2i(tex.get_size()) == Vector2i(16, 16), "%s: a 16x16 icon" % id)


# --- ● 희귀 생물 포획·사냥은 아처만: every path, the archer's and everyone else's ---------------------------------------

## `c` stood through a blow that did nothing, and shows it.
func _untouched(c: CreatureSim, at: Vector2, a: Arena, what: String) -> void:
	check_eq(c.hp, c.hp_max(), "%s: no damage" % what)
	check_eq(c.flash_ticks, 0, "%s: no flash" % what)
	check_eq(c.state, CreatureSim.State.IDLE, "%s: no bolt" % what)
	check_eq(c.pos, at, "%s: no push" % what)
	check(not c.stunned() and not c.slowed() and not c.poisoned(), "%s: no stun, slow or poison" % what)
	check_eq(c.refused_ticks, Config.CREATURE_REFUSED_SHOW_TICKS, "%s: the refused mark" % what)
	check(a.herd.stat("refused") > 0, "%s: counted" % what)
	check_eq(a.stat("creature_hits"), 0, "%s: no hit counted" % what)


func _check_shut_out() -> void:
	var at: Vector2 = Vector2(240, 200)
	var feet: Vector2 = Vector2(218, 200)
	for class_id: String in OTHERS:
		for kind: StringName in RARE:
			# A swing: every class's melee path (the bow's path is the shot below).
			var d: WorldData = open_world()
			var a: Arena = arena_for(d)
			var p: Player = player(d, class_id, feet)
			var c: CreatureSim = held_still(a, kind, feet + Vector2(20, 0))
			a.player_attack(p, &"sword", 0, [p] as Array[Player])
			_untouched(c, feet + Vector2(20, 0), a, "%s's swing on %s" % [class_id, kind])
			check_eq(a.herd.refusals.size(), 1, "the log hears of it")
			check_eq(a.herd.refusals[0].who, class_id, "whose blow")
	# Each other path, one class and one kind (the rule is one function; these prove every path asks it).
	for path: String in ["slam", "melee", "area", "strike", "poison", "shot", "fan", "rain"]:
		var d2: WorldData = open_world()
		var a2: Arena = arena_for(d2)
		var p2: Player = player(d2, "paladin", feet)
		var party: Array[Player] = [p2]
		var c2: CreatureSim = held_still(a2, &"lamp_fox", at)
		var pid: int = p2.get_instance_id()
		match path:
			"slam":
				check_eq(a2.slam(p2, 40.0, 10, 24.0), 0, "slam: no hit")
			"melee":
				var edits: Array[EditLog.WorldEdit] = []
				check_eq(a2.melee_skill(p2, 0, 10, 40.0, 120.0, 60, 50, 60, Arena.BurstKind.CRUSH, edits), 0, "melee skill: no hit")
			"area":
				check_eq(a2.area_hit(p2, at, 24.0, 10, Arena.BurstKind.HOLY), 0, "area: no hit")
			"strike":
				var s: Arena.Strike = a2.add_strike(Arena.StrikeKind.ROCKS, at, 24.0, 0, 10, 60, pid)
				check_eq(s.hits, 0, "strike: no hit")
			"poison":
				a2.throw_potion(p2, &"potion_poison", ItemDB.Grade.COMMON, at + Vector2(0, -2))
				for t: int in 40:
					a2.step(party)
				check_eq(a2.stat("splash_creatures"), 0, "poison: not reached")
			"shot":
				var shot: Arena.Shot = a2.skill_shot(p2, &"bow", Combat.aim_code(Creatures.aim_point(c2) - Combat.aim_origin(feet)), 10, 160.0, 220.0, false)
				for t2: int in 30:
					a2.step(party)
				check_eq(shot.stopped_by, "creature", "shot: it stops at the body, as any")
			"fan":
				var aim: int = Combat.aim_code(Creatures.aim_point(c2) - Combat.aim_origin(feet))
				a2.fan_shot(p2, &"fan_shot", aim, 10, 1, 0, 160.0, 220.0)
				for t3: int in 30:
					a2.step(party)
			"rain":
				a2.add_strike(Arena.StrikeKind.ARROWS, at, 24.0, 5, 10, 0, pid)
				for t4: int in 8:
					a2.step(party)
		_untouched(c2, at, a2, path)
	# A pierce goes through what it may not touch: the same blow shape by a non-archer's arrow does nothing.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var p3: Player = player(d3, "miner", feet)
	var c3: CreatureSim = held_still(a3, &"silver_stag", at)
	var party3: Array[Player] = [p3]
	a3.skill_shot(p3, &"piercing_arrow", Combat.aim_code(Creatures.aim_point(c3) - Combat.aim_origin(feet)), 10, 160.0, 220.0, true)
	for t5: int in 30:
		a3.step(party3)
	_untouched(c3, at, a3, "pierce")
	# Nobody at all (an arrow whose archer left): no blow on a rare creature either.
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var c4: CreatureSim = held_still(a4, &"ash_owl", at)
	check(not a4.hit_creature(c4, 10, 0), "no owner: no blow")
	_untouched(c4, at, a4, "no owner")
	# The refused mark runs out on the herd's clock.
	a4.herd.step([] as Array[Player])
	check_eq(c4.refused_ticks, Config.CREATURE_REFUSED_SHOW_TICKS - 1, "the mark runs down")
	# The archer: every path works.
	var d5: WorldData = open_world()
	var a5: Arena = arena_for(d5)
	var r: Player = player(d5, "archer", feet)
	var c5: CreatureSim = held_still(a5, &"silver_stag", feet + Vector2(20, 0))
	a5.player_attack(r, &"sword", 0, [r] as Array[Player])
	check(c5.hp < c5.hp_max(), "the archer's blow lands")
	check_eq(c5.refused_ticks, 0, "no refused mark")
	check_eq(c5.state, CreatureSim.State.FLEE, "it bolts")
	var hp: int = c5.hp
	a5.slam(r, 40.0, 3, 0.0)
	check_eq(c5.hp, hp - 3, "the slam's path too")
	hp = c5.hp
	var edits5: Array[EditLog.WorldEdit] = []
	a5.melee_skill(r, 0, 3, 40.0, 120.0, 9, 50, 60, Arena.BurstKind.CRUSH, edits5)
	check(c5.hp == hp - 3 and c5.stunned() and c5.slowed(), "the melee skill's, with its stun and slow")
	hp = c5.hp
	a5.area_hit(r, c5.pos, 24.0, 3, Arena.BurstKind.HOLY)
	check_eq(c5.hp, hp - 3, "the area's")
	hp = c5.hp
	a5.add_strike(Arena.StrikeKind.ARROWS, c5.pos, 24.0, 0, 3, 0, r.get_instance_id())
	check_eq(c5.hp, hp - 3, "the strike's")
	check(a5.herd.poison(c5, 2, 60, r.get_instance_id()), "the poison's (a test's: nobody else throws)")


func _check_prey_open() -> void:
	for class_id: String in OTHERS:
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var p: Player = player(d, class_id, Vector2(218, 200))
		var c: CreatureSim = held_still(a, &"deer", Vector2(238, 200))
		a.player_attack(p, &"sword", 0, [p] as Array[Player])
		check(c.hp < c.hp_max(), "%s hunts prey (● 누구나 사냥)" % class_id)
		check_eq(c.refused_ticks, 0, "no refused mark on prey")
		check_eq(a.herd.stat("refused"), 0, "nothing refused")


# --- the snare ---------------------------------------------------------------------------------------

func _check_target() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	check_eq(Capture.target_at(null, Vector2.ZERO), null, "no herd, nothing there")
	var c: CreatureSim = held_still(a, &"silver_stag", Vector2(200, 200))
	var mid: Vector2 = Creatures.aim_point(c)
	check_eq(Capture.target_at(a.herd, mid), c, "the mouse on it")
	var reach: float = c.num_f("hit_height_px") / 2.0 + Config.CAPTURE_GRAB_PX
	check_eq(Capture.target_at(a.herd, mid + Vector2(reach, 0.0)), c, "at the edge of its grab")
	check_eq(Capture.target_at(a.herd, mid + Vector2(reach + 1.0, 0.0)), null, "a px past it")
	var c2: CreatureSim = held_still(a, &"ash_owl", Vector2(216, 200))
	check_eq(Capture.target_at(a.herd, Creatures.aim_point(c2)), c2, "the nearer of two")
	var c3: CreatureSim = held_still(a, &"lamp_fox", Vector2(400, 200))
	check_eq(Capture.target_at(a.herd, Creatures.aim_point(c3)), c3, "one alone")
	c3.hp = 0
	c3.state = CreatureSim.State.DEAD
	check_eq(Capture.target_at(a.herd, Creatures.aim_point(c3)), null, "a dead one is nobody")


## Everything right but one thing: refused, nothing started, nothing spent.
func _refused_click(p: Player, a: Arena, mouse: Vector2, why: String, what: String) -> void:
	var before: String = holds(p)
	var alive: int = a.herd.alive_count()
	_refused = ""
	var f: NetProtocol.InputFrame = click(p, mouse)
	check_eq(_refused, why, what)
	check_eq(f.anim, -1, "%s: no action" % what)
	check_eq(f.op, NetProtocol.Op.NONE, "%s: no request" % what)
	check_eq(p.action_anim, -1, "%s: nothing plays" % what)
	ticks(p, a, Capture.impact_tick() + 2)
	check_eq(holds(p), before, "%s: nothing spent" % what)
	check_eq(a.herd.alive_count(), alive, "%s: nothing taken" % what)


func _check_refusals() -> void:
	var feet: Vector2 = Vector2(200, 200)
	var near: Vector2 = feet + Vector2(30, 0)
	# Not an archer.
	for class_id: String in OTHERS:
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var p: Player = player(d, class_id, feet)
		wire(p, a)
		with_snares(p, 3)
		var c: CreatureSim = held_still(a, &"lamp_fox", near)
		c.hp = 1
		_refused_click(p, a, Creatures.aim_point(c), Capture.WHY_NOT_ARCHER, "%s" % class_id)
		check_eq(_refused_at, c, "the refusal names the creature (its mark)")
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var r: Player = player(d2, "archer", feet)
	wire(r, a2)
	with_snares(r, 3)
	# Nothing under the mouse.
	var rare: CreatureSim = held_still(a2, &"lamp_fox", near)
	rare.hp = 1
	_refused_click(r, a2, feet + Vector2(0, -200), Capture.WHY_NOTHING, "nothing there")
	check_eq(_refused_at, null, "no creature named")
	# Prey: never, whatever its HP.
	var hare: CreatureSim = held_still(a2, &"hare", feet + Vector2(-30, 0))
	hare.hp = 1
	_refused_click(r, a2, Creatures.aim_point(hare), Capture.WHY_PREY, "a hare (포획 불가)")
	var deer: CreatureSim = held_still(a2, &"deer", feet + Vector2(0, 30))
	deer.hp = 1
	_refused_click(r, a2, Creatures.aim_point(deer), Capture.WHY_PREY, "a deer")
	# Healthy.
	rare.hp = rare.hp_max()
	_refused_click(r, a2, Creatures.aim_point(rare), Capture.WHY_HEALTHY, "too healthy")
	rare.hp = 1
	# Out of reach: the px past it, feet to feet.
	var reach: float = Config.CAPTURE_REACH_PX
	r.teleport(rare.pos - Vector2(reach + 1.0, 0))
	_refused_click(r, a2, Creatures.aim_point(rare), Capture.WHY_REACH, "a px out of reach")
	r.teleport(rare.pos - Vector2(reach, 0))
	check_eq(Capture.refusal(r, rare), "", "at its reach")
	# A wall between.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var q: Player = player(d3, "archer", Vector2(10 * 16 + 8, 200))
	wire(q, a3)
	with_snares(q, 1)
	var c3: CreatureSim = held_still(a3, &"ash_owl", Vector2(12 * 16 + 8, 200))
	c3.hp = 1
	var wall: Vector2i = Vector2i(11, 12)
	check_eq(Capture.refusal(q, c3), "", "before the wall")
	d3.set_value(WorldData.Layer.WALL, wall, Walls.pack(Walls.KIND_STONE, 0))
	_refused_click(q, a3, Creatures.aim_point(c3), Capture.WHY_REACH, "a wall between")
	# No snare: the click goes nowhere (a bow would shoot); the rule says so on its own.
	var e: Player = player(d2, "archer", rare.pos - Vector2(20, 0))
	check_eq(Capture.refusal(e, rare), Capture.WHY_NO_SNARE, "no snare")
	e.inventory.add(Capture.SNARE, 1)
	check_eq(Capture.refusal(e, rare), "", "one snare will do")
	check_eq(Capture.refusal(e, null), Capture.WHY_NOTHING, "nothing there, the rule")
	# Off: the click makes no frame and no refusal.
	var off: Player = player(d2, "archer", rare.pos - Vector2(20, 0))
	off.inventory.add(Capture.SNARE, 1)
	off.inventory.select(0)
	var f: NetProtocol.InputFrame = click(off, Creatures.aim_point(rare))
	check(f.anim == -1 and f.op == NetProtocol.Op.NONE, "capture off: the click does nothing")
	check_eq(off.inventory.count_of(Capture.SNARE), 1, "capture off: nothing spent")


## The player's own states, each with everything else right.
func _check_states() -> void:
	for state: String in ["down", "dead", "praying", "carrying", "panel", "mid-action"]:
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var p: Player = player(d, "archer", Vector2(200, 200))
		wire(p, a)
		with_snares(p, 2)
		var c: CreatureSim = held_still(a, &"lamp_fox", Vector2(230, 200))
		c.hp = 1
		var mouse: Vector2 = Creatures.aim_point(c)
		var before: String = holds(p)
		var why: String = ""
		match state:
			"down":
				p.take_hit(Config.PLAYER_HP_MAX)
				why = Capture.WHY_NOT_UP
			"dead":
				p.take_hit(Config.PLAYER_HP_MAX)
				p.vitals.life = Vitals.Life.DEAD
				why = Capture.WHY_NOT_UP
			"praying":
				p.prayer_role = Prayer.Role.PRAYING
				why = Capture.WHY_PRAYING
			"carrying":
				p.set_carrying_altar(true)
				why = Capture.WHY_CARRYING
			"panel":
				p.ui_locked = true
				why = Capture.WHY_PANEL
			"mid-action":
				p.start_action(RigData.Anim.BOW, &"bow")
		check_eq(Capture.refusal(p, c), why, "%s: the rule" % state)
		_refused = ""
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, mouse, true, true, true, TICK)
		check_eq(_refused, "", "%s: the click never reaches the snare" % state)
		check(p.action_anim != Config.CAPTURE_ANIM, "%s: no throw" % state)
		ticks(p, a, Capture.impact_tick() + 2)
		check_eq(holds(p), before, "%s: nothing spent" % state)
		check(c.alive() and a.herd.by_id(c.id) == c, "%s: nothing taken" % state)
		check_eq(c.hold_ticks, 0, "%s: nothing held" % state)
	# And land() itself, for the same states (the impact frame checks everything again).
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var q: Player = player(d2, "archer", Vector2(200, 200))
	with_snares(q, 2)
	var c2: CreatureSim = held_still(a2, &"lamp_fox", Vector2(230, 200))
	c2.hp = 1
	q.ui_locked = true
	check_eq(Capture.land(q, a2.herd, c2.id).why, Capture.WHY_PANEL, "land: a panel open")
	q.ui_locked = false
	check_eq(Capture.land(q, null, c2.id).why, Capture.WHY_GONE, "land: no herd")
	check_eq(Capture.land(q, a2.herd, 999).why, Capture.WHY_GONE, "land: no such creature")
	check_eq(q.inventory.count_of(Capture.SNARE), 2, "land refused: nothing spent")


func _check_threshold() -> void:
	var want: Dictionary[StringName, int] = {&"lamp_fox": 13, &"silver_stag": 16, &"ash_owl": 13}
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "archer", Vector2(200, 200))
	p.inventory.add(Capture.SNARE, 1)
	for kind: StringName in RARE:
		var c: CreatureSim = held_still(a, kind, Vector2(230, 200))
		c.hp = want[kind]
		check(c.can_be_taken(), "%s: %d HP is 30%% or less of %d" % [kind, c.hp, c.hp_max()])
		check_eq(Capture.refusal(p, c), "", "%s: at the threshold" % kind)
		c.hp = want[kind] + 1
		check(not c.can_be_taken(), "%s: a HP more is not" % kind)
		check_eq(Capture.refusal(p, c), Capture.WHY_HEALTHY, "%s: a HP above it" % kind)
		a.herd.list.erase(c)
	var hare: CreatureSim = held_still(a, &"hare", Vector2(230, 200))
	hare.hp = 1
	check(not hare.can_be_taken(), "prey never")


func _check_success() -> void:
	for kind: StringName in RARE:
		var d: WorldData = open_world()
		d.collection = Collection.new()
		var a: Arena = arena_for(d)
		var p: Player = player(d, "archer", Vector2(200, 200))
		wire(p, a)
		with_snares(p, 3)
		var c: CreatureSim = held_still(a, kind, Vector2(230, 200))
		c.hp = 2
		var respawn: int = c.num_i("respawn_ticks")
		var f: NetProtocol.InputFrame = click(p, Creatures.aim_point(c))
		check_eq(f.op, NetProtocol.Op.CAPTURE, "%s: a CAPTURE (M11c: its own request, offline the same frame)" % kind)
		check_eq(f.anim, Config.CAPTURE_ANIM, "%s: the throw" % kind)
		check_eq(f.capture_id, c.id, "%s: at it" % kind)
		check_eq(p.action_capture, c.id, "%s: the action remembers" % kind)
		check(c.held(), "%s: held from the click" % kind)
		check_eq(p.inventory.count_of(Capture.SNARE), 3, "%s: nothing spent yet" % kind)
		_landed = null
		# action_tick is 0 on the click's frame.
		ticks(p, a, Capture.impact_tick() - 1)
		check(_landed == null and c.alive(), "%s: one tick before the impact frame, nothing" % kind)
		check(c.held(), "%s: still held" % kind)
		check_eq(d.collection.count(), 0, "%s: no entry yet" % kind)
		ticks(p, a, 1)
		if not check(_landed != null and _landed.ok(), "%s: the impact frame takes it" % kind):
			continue
		check_eq(_landed.kind, kind, "%s: landed kind" % kind)
		check_eq(p.inventory.count_of(Capture.SNARE), 2, "%s: exactly one snare" % kind)
		check_eq(p.inventory.count_of(Config.RARE_MATERIAL), 1, "%s: exactly the material" % kind)
		check_eq(_landed.given, 1, "%s: given" % kind)
		check_eq(_landed.dropped, 0, "%s: nothing on the ground" % kind)
		check(d.drops.is_empty(), "%s: no drop, no corpse's hide" % kind)
		check_eq(a.herd.by_id(c.id), null, "%s: gone at once" % kind)
		check_eq(a.herd.alive_count(kind), 0, "%s: none left" % kind)
		check_eq(a.herd.stat("captured"), 1, "%s: counted" % kind)
		check_eq(a.herd.stat("killed"), 0, "%s: no kill" % kind)
		check(d.collection.has(StringName("take_%s" % kind)), "%s: its entry" % kind)
		check_eq(d.collection.count(), 1, "%s: exactly that entry" % kind)
		check_eq(d.collection.kills, 0, "%s: a capture is no kill" % kind)
		check_eq(a.herd.waiting.size(), 1, "%s: its place waits" % kind)
		check_eq(a.herd.waiting[0].kind, kind, "%s: for its kind" % kind)
		check_eq(a.herd.waiting[0].due, a.herd.clock - 1 + respawn, "%s: its respawn time, from the tick before this step of the herd's" % kind)
		# The rest of the throw plays out, no second capture.
		_landed = null
		ticks(p, a, Player.action_ticks(Config.CAPTURE_ANIM))
		check(_landed == null, "%s: one impact" % kind)
		check_eq(p.action_capture, 0, "%s: the action forgets" % kind)
	# A snare in another slot than the selected one's stack ends: the last snare goes too, the slot empties.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var q: Player = player(d2, "archer", Vector2(200, 200))
	wire(q, a2)
	with_snares(q, 1)
	var c2: CreatureSim = held_still(a2, &"ash_owl", Vector2(230, 200))
	c2.hp = 1
	click(q, Creatures.aim_point(c2))
	ticks(q, a2, Capture.impact_tick())
	check(_landed.ok() and q.inventory.count_of(Capture.SNARE) == 0, "the last snare")
	# A click, not repeated: the button held with nothing pressed starts nothing.
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var h: Player = player(d4, "archer", Vector2(200, 200))
	wire(h, a4)
	with_snares(h, 1)
	var c4: CreatureSim = held_still(a4, &"ash_owl", Vector2(230, 200))
	c4.hp = 1
	h.begin_tick()
	var f4: NetProtocol.InputFrame = h.make_frame(Vector2i.ZERO, Creatures.aim_point(c4), true, false, true)
	check_eq(f4.anim, -1, "held, not pressed: no throw")
	# A resting creature stays through the throw (the hold): a walking archer's catch.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var r: Player = player(d3, "archer", Vector2(200, 200))
	wire(r, a3)
	with_snares(r, 1)
	var c3: CreatureSim = a3.herd.spawn(&"lamp_fox", Vector2(230, 200))
	c3.hp = 1
	a3.herd.rest(c3)
	c3.state_ticks = c3.num_i("rest_ticks") - 2  # its rest ends right after the click
	click(r, Creatures.aim_point(c3))
	for t: int in Capture.impact_tick():
		r.begin_tick()
		r.step_frame(NetProtocol.InputFrame.new(), TICK)
		a3.herd.step([r] as Array[Player])
		check_eq(c3.pos, Vector2(230, 200), "tick %d: held where it stood" % t)
	check(_landed.ok() and a3.herd.alive_count() == 0, "caught though its rest ended")


func _check_full_inventory() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "archer", Vector2(200, 200))
	wire(p, a)
	for i: int in p.inventory.size():
		p.inventory.add(&"sword_t1", 1)  # a stack of one each: no room
	check_eq(p.inventory.free_slots(), 0, "full")
	p.inventory.remove(0, 1)
	p.inventory.add(Capture.SNARE, 2)
	p.inventory.select(0)
	check_eq(p.inventory.stack_at(0).id, Capture.SNARE, "two snares in the first slot: no room for anything else")
	var c: CreatureSim = held_still(a, &"lamp_fox", Vector2(230, 200))
	c.hp = 1
	click(p, Creatures.aim_point(c))
	ticks(p, a, Capture.impact_tick())
	check(_landed != null and _landed.ok(), "caught")
	check(_landed.given == 0 and _landed.dropped == 1, "the material lies down for want of room")
	check_eq(p.inventory.count_of(Capture.SNARE), 1, "one snare out")
	check_eq(p.inventory.count_of(Config.RARE_MATERIAL), 0, "none in the bag")
	ticks(p, a, 1)
	var here: Array[WorldData.Drop] = d.drops_at(Aim.feet_cell(Vector2(230, 200)))
	check_eq(here.size(), 1, "one drop on the creature's tile")
	if not here.is_empty():
		check(here[0].item == Config.RARE_MATERIAL and here[0].count == 1, "the material")


func _check_cut_off() -> void:
	# A hit on the archer before the impact frame: nothing spent, the hold runs out, the creature goes on.
	var d: WorldData = open_world()
	d.collection = Collection.new()
	var a: Arena = arena_for(d)
	var p: Player = player(d, "archer", Vector2(200, 200))
	wire(p, a)
	with_snares(p, 2)
	var c: CreatureSim = held_still(a, &"lamp_fox", Vector2(230, 200))
	c.hp = 1
	click(p, Creatures.aim_point(c))
	ticks(p, a, 4)
	_landed = null
	p.take_hit(5)
	ticks(p, a, Capture.impact_tick() + Config.CAPTURE_HOLD_SLACK_TICKS)
	check_eq(_landed, null, "cut off: no impact")
	check_eq(p.inventory.count_of(Capture.SNARE), 2, "cut off: nothing spent")
	check(c.alive() and not c.held(), "cut off: it stands free again")
	check_eq(d.collection.count(), 0, "cut off: no entry")
	# Killed between the click and the impact frame: nothing spent.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var q: Player = player(d2, "archer", Vector2(200, 200))
	wire(q, a2)
	with_snares(q, 2)
	var c2: CreatureSim = held_still(a2, &"ash_owl", Vector2(230, 200))
	c2.hp = 1
	click(q, Creatures.aim_point(c2))
	ticks(q, a2, 3)
	a2.hit_creature(c2, 5, q.get_instance_id())
	check(not c2.alive() and c2.hold_ticks == 0, "killed while held")
	ticks(q, a2, Capture.impact_tick())
	check(_landed != null and _landed.why == Capture.WHY_GONE, "killed meanwhile: the snare comes up empty")
	check_eq(q.inventory.count_of(Capture.SNARE), 2, "killed meanwhile: nothing spent")
	check_eq(q.inventory.count_of(Config.RARE_MATERIAL), 0, "killed meanwhile: no material")
	# The snare gone between the click and the impact frame: nothing, the creature stays.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var r: Player = player(d3, "archer", Vector2(200, 200))
	wire(r, a3)
	with_snares(r, 1)
	var c3: CreatureSim = held_still(a3, &"ash_owl", Vector2(230, 200))
	c3.hp = 1
	click(r, Creatures.aim_point(c3))
	ticks(r, a3, 3)
	r.inventory.remove(r.inventory.selected, 1)
	ticks(r, a3, Capture.impact_tick())
	check_eq(_landed.why, Capture.WHY_NO_SNARE, "the snare gone: refused")
	check(c3.alive() and a3.herd.by_id(c3.id) == c3, "the creature stays")
	check_eq(a3.herd.stat("captured"), 0, "nothing captured")


func _check_kill() -> void:
	var want: Dictionary[StringName, Array] = {&"lamp_fox": [&"hide_fine", 2, 1], &"silver_stag": [&"hide_fine", 3, 2], &"ash_owl": [&"hide_fine", 1, 1]}
	for kind: StringName in RARE:
		var d: WorldData = open_world()
		d.collection = Collection.new()
		var a: Arena = arena_for(d)
		var p: Player = player(d, "archer", Vector2(200, 200))
		var c: CreatureSim = held_still(a, kind, Vector2(216, 200))
		a.hit_creature(c, c.hp, p.get_instance_id())
		var got: Dictionary[StringName, int] = {}
		for e: EditLog.WorldEdit in a.herd.take_edits():
			var had: int = got.get(e.drop.item, 0)
			got[e.drop.item] = had + e.drop.count
		check_eq(got.get(&"hide_fine", 0), want[kind][1], "%s killed: whole hides" % kind)
		check_eq(got.get(&"meat", 0), want[kind][2], "%s killed: meat" % kind)
		check_eq(got.get(Config.RARE_MATERIAL, 0), 0, "%s killed: no rare material" % kind)
		check_eq(d.collection.count(), 0, "%s killed: no entry" % kind)
		check_eq(d.collection.kills, 1, "%s killed: a kill all the same" % kind)
		check_eq(a.herd.waiting.size(), 1, "%s killed: its place waits" % kind)


## The rare kinds' HP (M11b raised two of M11a's): each single arrow's damage can land each of them inside the threshold, not over it.
func _check_arrows_land() -> void:
	check_eq(Config.CREATURES[&"lamp_fox"]["hp"], 46, "the fox's HP")
	check_eq(Config.CREATURES[&"silver_stag"]["hp"], 56, "the stag's HP")
	check_eq(Config.CREATURES[&"ash_owl"]["hp"], 44, "the owl's HP")
	var bow: int = Combat.attack_for(&"bow").damage
	var t1: int = bow * Config.GEAR_T1_DAMAGE_PCT / 100
	var arrows: Array[int] = [bow, Collection.arrow_hit(bow), t1, Collection.arrow_hit(t1)]
	check_eq(arrows, [12, 13, 18, 20] as Array[int], "a bow, with the benefit, a tier-1 bow, with the benefit")
	for kind: StringName in RARE:
		var full: int = Config.CREATURES[kind]["hp"]
		for dmg: int in arrows:
			var hp: int = full
			var landed: int = -1
			var hits: int = 0
			while hp > 0:
				if hp * 100 <= full * Config.CAPTURE_HP_PCT:
					landed = hits
					break
				hp -= dmg
				hits += 1
			check(landed > 0, "%s (%d HP): %d-damage arrows land inside 30%% (%d hits)" % [kind, full, dmg, hits])


func _check_marks() -> void:
	var c: CreatureSim = CreatureSim.new()
	c.kind = &"lamp_fox"
	c.hp = c.hp_max()
	var v: CreatureView = CreatureView.new()
	_nodes.append(v)
	v.show_sim(c)
	check(not v.halo.visible, "healthy: no ring")
	check_eq(v.glow_phase, -1, "no phase")
	c.hp = 13
	v.show_sim(c)
	check(v.halo.visible and v.glow_phase == 0, "low enough: the ring")
	c.clock = CreatureView.GLOW_STEP_TICKS
	v.show_sim(c)
	check_eq(v.glow_phase, 1, "it blinks")
	c.hp = 14
	v.show_sim(c)
	check(not v.halo.visible, "a HP above: none")
	var hare: CreatureSim = CreatureSim.new()
	hare.kind = &"hare"
	hare.hp = 1
	v.show_sim(hare)
	check(not v.halo.visible, "prey: none")
	check_eq(CreatureView.notch_x(), 4, "the notch at 30% of the 14 px bar")
	# The ring's dots: on an ellipse round the feet, the two phases apart.
	var a0: Array[Vector2i] = CreatureView.glow_pixels(&"lamp_fox", 0)
	var a1: Array[Vector2i] = CreatureView.glow_pixels(&"lamp_fox", 1)
	check(a0.size() >= 6 and a1.size() >= 6, "dots in both phases")
	for p: Vector2i in a0:
		check(not a1.has(p), "the phases differ at %s" % p)
		check(absi(p.x) <= 13 and p.y >= -4 and p.y <= 2, "%s round the feet" % p)
	# The rope: dashes from the creature to the throw's point.
	var rope: Array[Vector2i] = CreatureView.rope_pixels(Vector2i(-30, -4))
	check(rope.has(Vector2i(0, -4)), "from the creature")
	check_eq(rope.size(), 16, "two lit of each four over 31 px")
	check(rope.has(Vector2i(-1, -4)) and not rope.has(Vector2i(-2, -4)) and not rope.has(Vector2i(-3, -4)) and rope.has(Vector2i(-4, -4)), "dashed")
	c.hp = 2
	c.hold_ticks = 5
	c.held_from = c.pos + Vector2(-30, -6)
	v.show_sim(c)
	check_eq(v.rope_to, Vector2i(-30, -6), "the rope shows while held")
	c.hold_ticks = 0
	v.show_sim(c)
	check_eq(v.rope_to, Vector2i.ZERO, "and goes")
	# The refused cross.
	c.refused_ticks = 3
	v.show_sim(c)
	check(v.marks.shown.has(EffectMarks.Kind.REFUSED), "the refused mark shows")
	c.refused_ticks = 0
	v.show_sim(c)
	check(not v.marks.shown.has(EffectMarks.Kind.REFUSED), "and goes")
	check_eq(EffectMarks.MAPS.size(), EffectMarks.Kind.size(), "a map per mark")
	check_eq(CombatView.BURST_COLOURS.size(), Arena.BurstKind.size(), "colours per burst")


func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.arenas[Config.MAP_SURFACE].spawning = false
	main.spawn("archer")
	var p: Player = main.player
	p.local_input = false
	var herd: Creatures = main.arenas[Config.MAP_SURFACE].herd
	herd.spawning = false
	var col: Collection = main.world_collection()
	check(col != null, "main: the world's collection")
	check(p.capture_on and p.herd_here() == herd, "main: the local player's snare on the surface's herd")
	var fox: CreatureSim = null
	for c: CreatureSim in herd.list:
		if c.kind == &"lamp_fox":
			fox = c
	if not check(fox != null, "main: the fox"):
		return
	# A non-archer's blow through Main's log path: refused, cleared.
	p.teleport(fox.pos + Vector2(-Config.CAPTURE_TEST_NEAR_PX, 0.0))
	herd.rest(fox)
	fox.state_ticks = -100000
	p.inventory.add(Capture.SNARE, 2)
	var slot: int = -1
	for i: int in p.inventory.size():
		var s: ItemStack = p.inventory.stack_at(i)
		if s != null and s.id == Capture.SNARE:
			slot = i
	p.inventory.select(slot)
	var mouse: Vector2 = Creatures.aim_point(fox)
	# Too healthy: Main marks the creature.
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, mouse, true, true, true, TICK)
	check_eq(p.inventory.count_of(Capture.SNARE), 2, "main: too healthy: nothing spent")
	check_eq(fox.refused_ticks, Config.CREATURE_REFUSED_SHOW_TICKS, "main: the refused mark")
	check_eq(p.action_anim, -1, "main: no throw")
	fox.hp = 4
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, mouse, true, true, true, TICK)
	check_eq(p.action_anim, Config.CAPTURE_ANIM, "main: the throw")
	check(fox.held(), "main: the action's start held it")
	var view: CombatView = main.combat_views[Config.MAP_SURFACE]
	main.step_creatures()
	var node: CreatureView = view.creatures[fox.id]
	check(node.rope_to != Vector2i.ZERO and node.halo.visible, "main: the rope and the ring show")
	for t: int in Capture.impact_tick():
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, mouse, true, false, false, TICK)
		main.step_combat(TICK)
		main.step_creatures()
	check_eq(herd.by_id(fox.id), null, "main: taken on the impact frame")
	check_eq(p.inventory.count_of(Capture.SNARE), 1, "main: one snare")
	check_eq(p.inventory.count_of(Config.RARE_MATERIAL), 1, "main: the material")
	check(col.has(&"take_lamp_fox"), "main: the entry")
	check(col.has(&"first_rare_essence"), "main: the first material's entry too (the inventory)")
	check_eq(col.count(), 2, "main: exactly those")
	check(col.take_fresh().is_empty(), "main: logged and cleared")
	var burst: bool = false
	for b: Arena.Burst in main.arenas[Config.MAP_SURFACE].bursts:
		burst = burst or b.kind == Arena.BurstKind.CAPTURE
	check(burst, "main: the catch shows")
	check(not view.creatures.has(fox.id), "main: its node is gone")
	# Down in the dungeon there is no herd: the click finds nothing.
	main.travel(Config.MAP_DUNGEON)
	check_eq(p.herd_here(), null, "main: no herd below")
	main.travel(Config.MAP_SURFACE)
	# Bot commands parse.
	for good: String in ["huntrare:600", "huntrare:600,100", "snare:300", "collection"]:
		check_eq(NetBot.new().parse(good), "", "bot: %s" % good)
	for bad: String in ["huntrare", "huntrare:x", "snare", "snare:0", "collection:1"]:
		check_ne(NetBot.new().parse(bad), "", "bot: %s refused" % bad)
	# What the bot does with what it is told: walks up to the nearest rare creature, shoots until a snare could take it, clicks in reach.
	var hunter: NetBot = NetBot.new()
	hunter.parse("huntrare:400,100;snare:50")
	hunter.rare = [Vector2(300, 0), Vector2(200, 0)] as Array[Vector2]
	hunter.rare_ready = [false, false] as Array[bool]
	var far: NetBot.Action = hunter.step(Vector2.ZERO)
	check(far.dir == Vector2i(1, 0) and not far.use_held, "bot: past its px it walks")
	check_eq(far.mouse, Vector2(200, 0), "bot: at the nearest")
	var shots: int = 0
	for t: int in 200:
		var near: NetBot.Action = hunter.step(Vector2(120, 0))
		check_eq(near.dir, Vector2i.ZERO, "bot: within its px it stands")
		if near.use_pressed:
			shots += 1
	check_eq(shots, 2, "bot: one press every %d ticks, no arrow on top of another" % NetBot.RARE_SHOT_TICKS)
	hunter.rare_ready = [false, true] as Array[bool]
	var ready_far: NetBot.Action = hunter.step(Vector2(120, 0))
	check(ready_far.dir == Vector2i(1, 0) and not ready_far.use_pressed, "bot: ready, it walks into the snare's reach")
	var ready_near: NetBot.Action = hunter.step(Vector2(180, 0))
	var ready_next: NetBot.Action = hunter.step(Vector2(180, 0))
	check(ready_near.use_pressed != ready_next.use_pressed and ready_near.dir == Vector2i.ZERO, "bot: in reach it clicks, every other tick")
	hunter.rare = [] as Array[Vector2]
	hunter.rare_ready = [] as Array[bool]
	hunter.step(Vector2(180, 0))
	check(hunter.finished, "bot: none left, it goes on")
