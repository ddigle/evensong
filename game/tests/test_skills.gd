extends "res://tests/base_test.gd"
## M9a, the skill kit (offline first): the tables (four slots per class, the slice's fifteen skills named, five identity skills
## built, actions and impact frames, icons, keys), the framework (cooldowns on the game clock and their determinism, the
## refusals in every listed state with the HUD's mark, a hit before the impact frame costs nothing), the class resources (gain,
## fade, spend, cap for all five), the near-cursor ally pick (● gameplay-design §2.1 R42: several allies, the caster, ties, the
## grab radius, the range, down and dead allies, heretics, other maps), threat (damage order, heals, the taunt and its expiry,
## the light rules unchanged, no threat = the M4 nearest, forgetting, the switch), each identity skill's effect and numbers (the
## taunt, the piercing arrow, the heal, the ground slam, the herbalist's throw retargeted: healing and buff to the ally nearest
## the cursor, poison still aimed, the session path untouched), the HUD row's rules, the drawn effects, and main.tscn offline.

const TICK: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func run() -> Array[String]:
	_check_tables()
	_check_cooldowns()
	_check_refusals()
	_check_resources()
	_check_pick()
	_check_threat()
	_check_threat_light()
	_check_taunt()
	_check_piercing_arrow()
	_check_heal()
	_check_ground_slam()
	_check_throw_retarget()
	_check_hud_rules()
	_check_views()
	await _check_main()
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
	p.skills_on = true
	p.potions_on = true
	_nodes.append(p)
	return p


static func arena_for(d: WorldData, threat: bool = true) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = threat
	return a


static func tick(p: Player, f: NetProtocol.InputFrame = null) -> int:
	p.begin_tick()
	return p.step_frame(f if f != null else NetProtocol.InputFrame.new(), TICK)


static func walk(p: Player, dir: Vector2i) -> int:
	return tick(p, NetProtocol.InputFrame.new(0, dir))


## Presses the key of skill slot `slot` with the mouse at `mouse` and steps the player one tick. Returns the frame.
static func press(p: Player, slot: int, mouse: Vector2) -> NetProtocol.InputFrame:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, mouse, true, false, false, false, false,
		slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	p.step_frame(f, TICK)
	return f


## Main's offline wiring for a test player: the near-cursor pick over `party`, a skill's impact lands on `a`, a potion's release
## goes into `a` (a healing or buff throw following the ally picked, Main.potion_impact).
func wire(p: Player, a: Arena, party: Array[Player]) -> void:
	p.party_provider = func() -> Array[Player]: return party
	p.action_impact.connect(_impact.bind(p, a, party))


func _impact(item: StringName, anim: int, _cell: Vector2i, p: Player, a: Arena, party: Array[Player]) -> void:
	if Skills.is_skill(item):
		Skills.land(p, item, a, party)
	elif Potions.is_potion(item):
		var follow: Player = null
		for q: Player in party:
			if q.get_instance_id() == p.action_skill_target:
				follow = q
		Potions.release(p, item, anim, a, 255, follow)


## Every player stands a tick, then the arena steps.
static func step_all(players: Array[Player], a: Arena, n: int = 1) -> void:
	for i: int in n:
		for p: Player in players:
			tick(p)
		a.step(players)


static func _last(lines: Array[String]) -> String:
	return lines[lines.size() - 1] if not lines.is_empty() else ""


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


# --- the tables ------------------------------------------------------------------------------------------

func _check_tables() -> void:
	var identity: Dictionary[String, StringName] = {"paladin": Skills.TAUNT, "archer": Skills.PIERCING_ARROW,
		"cleric": Skills.HEAL, "miner": Skills.GROUND_SLAM, "herbalist": Skills.POTION_THROW}
	var named: Dictionary[StringName, bool] = {}
	for c: String in Config.CLASSES:
		var kit: Array = Config.SKILL_KITS.get(c, [])
		check_eq(kit.size(), SkillState.SLOT_COUNT, "%s: four slots (● R42)" % c)
		check_eq(Skills.kit_skill(c, Skills.Slot.IDENTITY), identity[c], "%s: its identity skill" % c)
		check(Skills.built(Skills.kit_skill(c, Skills.Slot.IDENTITY)), "%s: the identity skill is built (M9a)" % c)
		check_eq(Skills.kit_skill(c, Skills.Slot.CHOICE), &"", "%s: no choice skill (not in the slice count)" % c)
		var sig: StringName = Skills.kit_skill(c, Skills.Slot.SIGNATURE)
		var weapon: StringName = Skills.kit_skill(c, Skills.Slot.WEAPON)
		check(not sig.is_empty() and Skills.built(sig), "%s: the signature is named and built (M9b): %s" % [c, sig])
		check(not weapon.is_empty() and Skills.built(weapon), "%s: the weapon skill is named and built (M9b)" % c)
		check_eq(weapon, Config.SKILL_BY_WEAPON.get(Combat.class_weapon(c), &""), "%s: the weapon skill is its weapon's" % c)
		for id: StringName in [Skills.kit_skill(c, Skills.Slot.IDENTITY), weapon, sig]:
			named[id] = true
		check_eq(Skills.slot_of(c, identity[c]), Skills.Slot.IDENTITY, "%s: slot_of the identity skill" % c)
		check_eq(Skills.resource_cap(c), 0 if c == "herbalist" else 100, "%s: the meter's cap" % c)
	check_eq(named.size(), 15, "5 classes x (identity + signature) + 5 weapon skills = 15 (● R42 slice count)")
	check_eq(Config.SKILLS.size(), 15, "M9a built the five identity skills, M9b the other ten")
	var anims: Dictionary[StringName, int] = {Skills.TAUNT: RigData.Anim.MAGIC, Skills.PIERCING_ARROW: RigData.Anim.BOW,
		Skills.HEAL: RigData.Anim.MAGIC, Skills.GROUND_SLAM: RigData.Anim.PICKAXE, Skills.POTION_THROW: RigData.Anim.THROW,
		Skills.CRUSHING_BLOW: RigData.Anim.SWORD, Skills.FAN_SHOT: RigData.Anim.BOW, Skills.HOLY_BURST: RigData.Anim.MAGIC,
		Skills.HEAVY_STRIKE: RigData.Anim.PICKAXE, Skills.SWEEP: RigData.Anim.SICKLE, Skills.GUARDIAN_OATH: RigData.Anim.MAGIC,
		Skills.ARROW_RAIN: RigData.Anim.BOW, Skills.BLESSING: RigData.Anim.MAGIC, Skills.ROCKFALL: RigData.Anim.PICKAXE,
		Skills.HEALING_MIST: RigData.Anim.THROW}
	for id: StringName in Config.SKILLS:
		var row: Dictionary = Config.SKILLS[id]
		for key: String in ["cooldown", "anim", "impact"]:
			check(row.has(key), "%s has %s" % [id, key])
		check(RigData.is_action(Skills.anim(id)), "%s plays a body action the slice has" % id)
		check_eq(Skills.anim(id), anims[id], "%s's action" % id)
		check(Skills.num_i(id, "impact") >= 0 and Skills.num_i(id, "impact") < RigData.frame_count(Skills.anim(id)),
			"%s lands inside its action" % id)
		check(Skills.cooldown_ticks(id) >= 0, "%s's cooldown" % id)
		check(not ItemDB.has(id), "%s is no item id (action_item holds it)" % id)
		check(SkillIcons.MAPS.has(id), "%s has an icon" % id)
	check_eq(Skills.cooldown_ticks(Skills.POTION_THROW), 0, "the throw keeps M6's rate (no cooldown)")
	check_eq(Skills.impact_tick(Skills.POTION_THROW), Potions.impact_tick(RigData.Anim.THROW), "the throw lands on M6's release frame")
	check(Skills.is_skill(Skills.TAUNT) and not Skills.is_skill(Skills.POTION_THROW) and not Skills.is_skill(&"sword"),
		"is_skill: a skill's action item (the throw keeps its potion)")
	check_eq(Player.impact_tick_of(Skills.HEAL, RigData.Anim.MAGIC), 3 * Config.ACTION_FRAME_TICKS, "a skill's impact tick")
	check_eq(Player.impact_tick_of(&"potion_healing", RigData.Anim.THROW), Potions.impact_tick(RigData.Anim.THROW),
		"a potion's impact tick unchanged")
	var maps: Array[Array] = [SkillIcons.LATER_MAP, SkillIcons.LOCK_MAP]
	for id2: StringName in SkillIcons.MAPS:
		maps.append(SkillIcons.MAPS[id2])
	for m: Array in maps:
		var ok: bool = m.size() == SkillIcons.SIZE
		for row2: Variant in m:
			var line: String = row2
			ok = ok and line.length() == SkillIcons.SIZE
		check(ok, "an icon map is 12 x 12")
	check(SkillIcons.texture_for(Skills.TAUNT).get_size() == Vector2(12, 12), "an icon texture is 12 x 12")
	check(SkillIcons.map_for(&"guardian_oath") != SkillIcons.LATER_MAP and SkillIcons.map_for(&"no_such_skill") == SkillIcons.LATER_MAP,
		"M9b: every built skill has its own icon; a skill without a map: the dim diamond")
	check_eq(SkillIcons.R_GLYPH.size(), 5, "the R glyph has 5 rows")
	var keys: Dictionary[String, int] = {"skill_1": KEY_1, "skill_2": KEY_2, "skill_3": KEY_3, "skill_signature": KEY_R}
	for action: String in keys:
		var found: bool = false
		if InputMap.has_action(action):
			for e: InputEvent in InputMap.action_get_events(action):
				if e is InputEventKey and (e as InputEventKey).physical_keycode == keys[action]:
					found = true
		check(found, "input action %s on its key (○ §1: 1 2 3 R)" % action)


# --- cooldowns ------------------------------------------------------------------------------------------

func _check_cooldowns() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var pal: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	var party: Array[Player] = [pal]
	wire(pal, a, party)
	var east: Vector2 = pal.sim_position + Vector2(30, 0)
	var f: NetProtocol.InputFrame = press(pal, Skills.Slot.IDENTITY, east)
	check(f.skill == Skills.TAUNT and f.skill_slot == Skills.Slot.IDENTITY and f.anim == RigData.Anim.MAGIC,
		"key 1: the taunt's action (%s %d %d)" % [f.skill, f.skill_slot, f.anim])
	check(pal.action_anim == RigData.Anim.MAGIC and pal.action_skill == Skills.TAUNT and pal.action_item == Skills.TAUNT,
		"the paladin plays it")
	var impact: int = Skills.impact_tick(Skills.TAUNT)
	for t: int in impact - 1:
		tick(pal)
	check_eq(pal.skills.cooldown(Skills.Slot.IDENTITY), 0, "no cooldown before it lands")
	tick(pal)
	check_eq(pal.skills.cooldown(Skills.Slot.IDENTITY), Skills.cooldown_ticks(Skills.TAUNT), "the cooldown starts when it lands")
	check_eq(a.stat("taunts"), 1, "it landed once")
	for t2: int in Skills.cooldown_ticks(Skills.TAUNT) - 1:
		tick(pal)
	check_eq(pal.skills.cooldown(Skills.Slot.IDENTITY), 1, "one tick left after cooldown - 1 ticks")
	var refused: Array[String] = []
	pal.skill_refused.connect(func(slot: int, id: StringName, why: String) -> void: refused.append("%d:%s:%s" % [slot, id, why]))
	press(pal, Skills.Slot.IDENTITY, east)
	check_eq(refused, ["0:taunt:%s" % Skills.WHY_COOLDOWN] as Array[String], "pressed a tick early: cooling down")
	check_eq(pal.action_anim, -1, "nothing started")
	press(pal, Skills.Slot.IDENTITY, east)
	check_eq(pal.action_skill, Skills.TAUNT, "ready again exactly cooldown ticks after it landed")
	# Determinism: two paladins given the same frames hold the same skill state on every tick.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var a3: Arena = arena_for(open_world())
	var p2: Player = player(d2, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	var p3: Player = player(a3.data, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	var party2: Array[Player] = [p2]
	var party3: Array[Player] = [p3]
	wire(p2, a2, party2)
	wire(p3, a3, party3)
	var same: int = 0
	for t3: int in 1300:
		var key: bool = t3 % 97 == 0
		var dir: Vector2i = Vector2i(1, 0) if t3 % 200 < 20 else Vector2i.ZERO
		for q: Player in [p2, p3]:
			q.begin_tick()
			var fq: NetProtocol.InputFrame = q.make_frame(dir, q.sim_position + Vector2(30, 0), true, false, false, false,
				false, key)
			q.step_frame(fq, TICK)
			if q == p2:
				a2.step(party2)
			else:
				a3.step(party3)
		if p2.skills.same_as(p3.skills) and p2.skills.cooldowns == p3.skills.cooldowns:
			same += 1
	check_eq(same, 1300, "the same frames: the same cooldowns on every tick (deterministic)")
	check(a2.stat("taunts") >= 2 and a2.stat("taunts") == a3.stat("taunts"), "and the same taunts (%d)" % a2.stat("taunts"))
	# The game clock runs while down and dead too.
	var cd: int = p2.skills.cooldown(Skills.Slot.IDENTITY)
	if cd < 100:
		p2.skills.start_cooldown(Skills.Slot.IDENTITY, 400)
		cd = 400
	p2.take_hit(Config.PLAYER_HP_MAX)
	check_eq(p2.vitals.life, Vitals.Life.DOWN, "setup: down")
	for t4: int in 50:
		tick(p2)
	check_eq(p2.skills.cooldown(Skills.Slot.IDENTITY), cd - 50, "the cooldown runs while down")
	p2.vitals.life = Vitals.Life.DEAD
	p2.vitals.life_ticks = 0
	for t5: int in 30:
		tick(p2)
	check_eq(p2.skills.cooldown(Skills.Slot.IDENTITY), cd - 80, "and while dead")
	# A hit before the impact frame cuts the skill off: nothing lands, no cooldown.
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var p4: Player = player(d4, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	var party4: Array[Player] = [p4]
	wire(p4, a4, party4)
	press(p4, Skills.Slot.IDENTITY, p4.sim_position + Vector2(30, 0))
	for t6: int in impact - 3:
		tick(p4)
	p4.take_hit(5)
	for t7: int in 60:
		tick(p4)
	check(a4.stat("taunts") == 0 and p4.skills.cooldown(Skills.Slot.IDENTITY) == 0,
		"a hit before the impact frame: nothing landed, no cooldown (the M6 drink rule)")


# --- refusals -------------------------------------------------------------------------------------------

## Presses `slot` on player `p` (made ready by `setup`) and checks the refusal `why`: the HUD's mark on that slot, the signal,
## no action, no cooldown, the meter unchanged.
func _refused(p: Player, slot: int, why: String, label: String) -> void:
	var got: Array[String] = []
	var cb: Callable = func(s: int, _id: StringName, w: String) -> void: got.append("%d:%s" % [s, w])
	p.skill_refused.connect(cb)
	var before_anim: int = p.action_anim
	var before_cd: PackedInt32Array = p.skills.cooldowns.duplicate()
	var before_res: int = p.skills.resource
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, p.sim_position + Vector2(20, 0), true, false, false, false,
		false, slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	check(f.skill.is_empty() and (f.anim < 0 or not Skills.built(f.item)), "%s: no skill in the frame" % label)
	check_eq(got, ["%d:%s" % [slot, why]] as Array[String], "%s: refused (%s)" % [label, why])
	check(p.skills.shows_refusal(slot) and p.skills.refused_why == why
		and p.skills.refused_ticks == Config.SKILL_REFUSED_SHOW_TICKS, "%s: the HUD marks slot %d" % [label, slot])
	check(p.action_anim == before_anim and p.skills.cooldowns == before_cd and p.skills.resource == before_res,
		"%s: nothing started or spent" % label)
	p.skill_refused.disconnect(cb)


func _check_refusals() -> void:
	var d: WorldData = open_world()
	var feet: Vector2 = Arena.spawn_feet(Vector2i(10, 10))
	var p: Player = player(d, "paladin", feet)
	_refused(p, Skills.Slot.CHOICE, Skills.WHY_LOCKED, "key 3 (the choice slot)")
	_refused(p, Skills.Slot.WEAPON, Skills.WHY_NO_WEAPON, "key 2, nothing held")
	p.inventory.add(&"bow", 1)
	p.inventory.select(slot_of(p.inventory, &"bow"))
	_refused(p, Skills.Slot.WEAPON, Skills.WHY_NO_WEAPON, "key 2, another class's weapon")
	p.inventory.add(&"sword_t1", 1)
	p.inventory.select(slot_of(p.inventory, &"sword_t1"))
	check_eq(Skills.refusal(p, Skills.Slot.WEAPON), "", "key 2, the class weapon (tier 1): it may start (M9b builds it)")
	_refused(p, Skills.Slot.SIGNATURE, Skills.WHY_RESOURCE, "key R with an empty meter (M9b builds it)")
	for t: int in Config.SKILL_REFUSED_SHOW_TICKS:
		tick(p)
	check(not p.skills.shows_refusal(Skills.Slot.SIGNATURE) and p.skills.refused_slot == -1, "the mark fades after its ticks")
	# Mid-action: a sword swing plays.
	p.inventory.add(&"sword", 1)
	p.inventory.select(slot_of(p.inventory, &"sword"))
	p.begin_tick()
	p.step_frame(p.make_frame(Vector2i.ZERO, p.sim_position + Vector2(20, 0), true, true, true), TICK)
	check_eq(p.action_anim, RigData.Anim.SWORD, "setup: swinging")
	_refused(p, Skills.Slot.IDENTITY, Skills.WHY_BUSY, "mid-action")
	for t2: int in 60:
		tick(p)
	# Dashing.
	tick(p, test_dash())
	check(p.vitals.dashing(), "setup: dashing")
	_refused(p, Skills.Slot.IDENTITY, Skills.WHY_BUSY, "dashing")
	for t3: int in 60:
		tick(p)
	# Staggered.
	p.take_hit(5)
	check(p.vitals.staggered(), "setup: staggered")
	_refused(p, Skills.Slot.IDENTITY, Skills.WHY_BUSY, "staggered")
	for t4: int in 60:
		tick(p)
	# Carrying the altar.
	p.set_carrying_altar(true)
	_refused(p, Skills.Slot.IDENTITY, Skills.WHY_CARRYING, "carrying the altar")
	p.set_carrying_altar(false)
	# A panel open (tick_controls with ui_locked).
	p.ui_locked = true
	var got: Array[String] = []
	p.skill_refused.connect(func(s: int, _id: StringName, w: String) -> void: got.append("%d:%s" % [s, w]))
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, p.sim_position + Vector2(20, 0), true, false, false, TICK, false, false, true)
	check_eq(got, ["0:%s" % Skills.WHY_PANEL] as Array[String], "a panel open: refused")
	check(p.action_anim == -1 and p.skills.shows_refusal(Skills.Slot.IDENTITY), "a panel open: nothing, the HUD marks it")
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, p.sim_position + Vector2(20, 0), true, false, false, TICK, false, false, false,
		Skills.Slot.SIGNATURE)
	check_eq(got.back(), "3:%s" % Skills.WHY_PANEL, "a panel open: key R too")
	p.ui_locked = false
	# Down, then dead.
	p.take_hit(Config.PLAYER_HP_MAX)
	_refused(p, Skills.Slot.IDENTITY, Skills.WHY_DOWN, "down")
	p.vitals.life = Vitals.Life.DEAD
	_refused(p, Skills.Slot.IDENTITY, Skills.WHY_DEAD, "dead")
	# The refusal rule itself, for every state at once (the order the checks run in).
	var q: Player = player(d, "cleric", feet)
	check_eq(Skills.refusal(q, Skills.Slot.IDENTITY), "", "a fresh cleric may heal")
	q.skills.start_cooldown(Skills.Slot.IDENTITY, 10)
	check_eq(Skills.refusal(q, Skills.Slot.IDENTITY), Skills.WHY_COOLDOWN, "cooling down")
	# The signature's resource check (M9b builds the signatures; the spend rule is M9a's).
	check(not Skills.can_spend_signature(q), "an empty meter cannot pay the signature")


static func test_dash() -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i(1, 0))
	f.dash = true
	return f


# --- resources ------------------------------------------------------------------------------------------

func _check_resources() -> void:
	var d: WorldData = open_world()
	var feet: Vector2 = Arena.spawn_feet(Vector2i(10, 10))
	# Paladin: conviction from damage taken.
	var pal: Player = player(d, "paladin", feet)
	pal.take_hit(12)
	check_eq(pal.skills.resource, 12 * Config.PALADIN_CONVICTION_PER_HP, "paladin: +1 per HP taken")
	pal.take_hit(12)
	check_eq(pal.skills.resource, 12, "a hit that does not land (invulnerable) gives nothing")
	for t: int in Config.HURT_INVULN_TICKS:
		tick(pal)
	pal.gear_on = true
	pal.inventory.wear(ItemStack.new(&"armor_t1", 1, 0, Config.GEAR_DURABILITY[&"armor_t1"]))
	pal.take_hit(Config.HERETIC_DAMAGE, true)
	check_eq(pal.skills.resource, 12 + Config.HERETIC_DAMAGE - Config.ARMOR_T1_DEFENCE, "armour: only what landed counts")
	pal.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	var before_poison: int = pal.skills.resource
	for t2: int in Config.POISON_INTERVAL_TICKS:
		tick(pal)
	check_eq(pal.skills.resource, before_poison + Config.POISON_DAMAGE[ItemDB.Grade.COMMON], "a poison tick is damage taken")
	pal.vitals.clear_effects()
	pal.skills.on_hurt("paladin", 500)
	check_eq(pal.skills.resource, Skills.resource_cap("paladin"), "the cap")
	# The fade: nothing for the delay, then 1 per PALADIN_CONVICTION_DECAY_TICKS.
	for t3: int in Config.PALADIN_CONVICTION_DECAY_DELAY_TICKS + Config.PALADIN_CONVICTION_DECAY_TICKS - 1:
		tick(pal)
	check_eq(pal.skills.resource, 100, "no fading until the delay and one rhythm have passed")
	tick(pal)
	check_eq(pal.skills.resource, 99, "then 1")
	for t4: int in Config.PALADIN_CONVICTION_DECAY_TICKS * 9:
		tick(pal)
	check_eq(pal.skills.resource, 90, "1 per %d ticks" % Config.PALADIN_CONVICTION_DECAY_TICKS)
	pal.take_hit(1)
	for t5: int in Config.PALADIN_CONVICTION_DECAY_DELAY_TICKS:
		tick(pal)
	check_eq(pal.skills.resource, 91, "damage taken starts the wait over")
	# Death loses it.
	pal.take_hit(Config.PLAYER_HP_MAX)
	var gave_up: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	gave_up.interact = true
	for t6: int in Config.GIVE_UP_HOLD_TICKS + 2:
		tick(pal, gave_up)
	check(pal.vitals.life == Vitals.Life.DEAD and pal.skills.resource == 0, "death loses the meter (%d)" % pal.skills.resource)
	# Archer: focus standing, drained moving.
	var arc: Player = player(d, "archer", feet)
	for t7: int in 60:
		tick(arc)
	check_eq(arc.skills.resource, 60 / Config.ARCHER_FOCUS_GAIN_TICKS, "archer: +1 per %d ticks standing" % Config.ARCHER_FOCUS_GAIN_TICKS)
	for t8: int in 10:
		walk(arc, Vector2i(1, 0))
	check_eq(arc.skills.resource, 10 - 10 / Config.ARCHER_FOCUS_DRAIN_TICKS, "-1 per %d ticks moving" % Config.ARCHER_FOCUS_DRAIN_TICKS)
	for t9: int in 40:
		walk(arc, Vector2i(-1, 0))
	check_eq(arc.skills.resource, 0, "never below 0")
	for t10: int in 100 * Config.ARCHER_FOCUS_GAIN_TICKS + 30:
		tick(arc)
	check_eq(arc.skills.resource, 100, "the cap")
	tick(arc, test_dash())
	var during: int = arc.skills.resource
	for t11: int in 6:
		tick(arc)
	check(during <= 100 and arc.skills.resource < 100, "a dash counts as moving (%d)" % arc.skills.resource)
	for t11b: int in Config.DASH_TICKS:
		tick(arc)
	arc.take_hit(Config.PLAYER_HP_MAX)
	check_eq(arc.vitals.life, Vitals.Life.DOWN, "setup: the archer is down")
	var down_at: int = arc.skills.resource
	for t12: int in 60:
		tick(arc)
	check_eq(arc.skills.resource, down_at, "no focus while down")
	check_eq(arc.skills.on_hurt("archer", 30), 0, "an archer's damage gives nothing")
	# Cleric: faith from HP healed (Skills.land, below); the rule itself.
	var cle: Player = player(d, "cleric", feet)
	check_eq(cle.skills.on_heal_done("cleric", 25), 25 * Config.CLERIC_FAITH_PER_HP, "cleric: +1 per HP healed")
	check_eq(cle.skills.on_heal_done("cleric", 500), 75, "up to the cap")
	check_eq(cle.skills.on_heal_done("paladin", 10), 0, "nobody else's heal counts")
	for t13: int in 600:
		tick(cle)
	check_eq(cle.skills.resource, 100, "faith does not fade")
	# Miner: endurance per block broken.
	var mnr: Player = player(d, "miner", feet)
	check_eq(mnr.skills.on_mined("miner", 9), 9 * Config.MINER_ENDURANCE_PER_BLOCK, "miner: per block broken")
	check_eq(mnr.skills.on_mined("miner", 100), 100 - 9 * Config.MINER_ENDURANCE_PER_BLOCK, "up to the cap")
	check_eq(SkillState.new().on_mined("paladin", 9), 0, "nobody else's mining counts")
	# Herbalist: no meter, the healing herbs carried.
	var herb: Player = player(d, "herbalist", feet)
	check_eq(Skills.resource_of(herb), 0, "herbalist: no herbs")
	herb.inventory.add(Config.HERBALIST_MATERIAL_ITEM, 2, ItemDB.Grade.COMMON)
	herb.inventory.add(Config.HERBALIST_MATERIAL_ITEM, 1, ItemDB.Grade.FINE)
	herb.inventory.add(&"wild_buff", 5)
	check_eq(Skills.resource_of(herb), 3, "his material = the healing herbs carried, any grade")
	check_eq(herb.skills.gain("herbalist", 10), 0, "no meter to fill")
	check(Skills.can_spend_signature(herb), "three herbs pay his signature (%d)" % Skills.signature_cost("herbalist"))
	check_eq(Skills.spend_signature(herb), 3, "spent three")
	check(Skills.resource_of(herb) == 0 and herb.inventory.count_of(&"wild_buff") == 5, "the healing herbs gone, the rest kept")
	herb.inventory.add(Config.HERBALIST_MATERIAL_ITEM, 2)
	check(Skills.spend_signature(herb) == 0 and Skills.resource_of(herb) == 2, "two: not enough, nothing taken")
	# The signature's spend: all or nothing; the archer spends all of his focus.
	var pal2: Player = player(d, "paladin", feet)
	pal2.skills.resource = 60
	check(Skills.spend_signature(pal2) == 50 and pal2.skills.resource == 10, "paladin: 50 of 60")
	check(Skills.spend_signature(pal2) == 0 and pal2.skills.resource == 10, "10: not enough, nothing spent")
	var arc2: Player = player(d, "archer", feet)
	arc2.skills.resource = 70
	check(Skills.spend_signature(arc2) == 70 and arc2.skills.resource == 0, "archer: all 70 of his focus")
	arc2.skills.resource = Skills.signature_cost("archer") - 1
	check_eq(Skills.spend_signature(arc2), 0, "archer: below his minimum, nothing")
	check(not arc2.skills.spend(-1) and arc2.skills.spend(0), "spend: never negative")


# --- the near-cursor ally pick (● §2.1 R42) -------------------------------------------------------------

func _check_pick() -> void:
	var d: WorldData = open_world()
	var c: Player = player(d, "cleric", Vector2(100, 100))
	var a1: Player = player(d, "paladin", Vector2(160, 100))
	var b: Player = player(d, "archer", Vector2(100, 160))
	var e: Player = player(d, "miner", Vector2(150, 150))
	var party: Array[Player] = [c, a1, b, e]
	var r: float = 112.0
	check(Skills.pick_ally(party, c, a1.sim_position + Vector2(5, -10), r) == a1, "the ally nearest the cursor")
	check(Skills.pick_ally(party, c, b.sim_position + Vector2(-3, -20), r) == b, "another one")
	check(Skills.pick_ally(party, c, c.sim_position + Vector2(2, -12), r) == c, "the caster itself")
	check(Skills.pick_ally(party, c, Vector2(153, 130), r) == e, "between two: the nearer figure")
	# A tie: the first in the party order (the lower slot). M9 review: measured to the middle of each figure (Combat.body_centre).
	var f1: Player = player(d, "miner", Vector2(130, 60))
	var f2: Player = player(d, "archer", Vector2(130, 100))
	var tie: Vector2 = (Combat.body_centre(f1.sim_position) + Combat.body_centre(f2.sim_position)) / 2.0
	var tied1: Array[Player] = [c, f1, f2]
	var tied2: Array[Player] = [c, f2, f1]
	check(Skills.pick_ally(tied1, c, tie, r) == f1 and Skills.pick_ally(tied2, c, tie, r) == f2, "a tie: the first in order")
	# The grab radius (from the middle of the figure).
	var edge: Vector2 = Combat.body_centre(a1.sim_position) + Vector2(Config.SKILL_GRAB_RADIUS_PX, 0)
	check(Skills.pick_ally(party, c, edge, r) == a1, "at the grab radius: picked")
	check(Skills.pick_ally(party, c, edge + Vector2(1, 0), 500.0) == null, "beyond it: nobody")
	check_eq(Skills.cursor_distance(a1, a1.sim_position), Config.BODY_HIT_HEIGHT_PX / 2.0,
		"the cursor on the feet is half a figure from its middle")
	# M9 review: two allies stacked one above the other, the cursor on the front one's torso or head: the front one gets it (the
	# feet would have handed it to the one behind).
	var front: Player = player(d, "paladin", Vector2(200, 200))
	var behind: Player = player(d, "archer", Vector2(200, 184))
	var stacked: Array[Player] = [c, behind, front]
	var torso_ok: bool = true
	for up: int in [0, 4, 8, 12, 14, 18]:
		if Skills.pick_ally(stacked, c, front.sim_position - Vector2(0, up), 300.0) != front:
			torso_ok = false
	check(torso_ok, "the cursor on the front ally's feet, torso or chest picks him, not the one standing behind")
	check(Skills.pick_ally(stacked, c, Combat.body_centre(behind.sim_position), 300.0) == behind,
		"the cursor on the middle of the one behind picks him")
	# M9 review: the host's pick with its sender's hint (Config.SKILL_PICK_LAG_PX): the hinted ally while it is within the radius plus
	# the allowance, else the host's own nearest.
	var near_cursor: Vector2 = Combat.body_centre(front.sim_position)
	check(Skills.pick_with_hint(stacked, c, near_cursor, 300.0, null) == front, "no hint: the nearest")
	check(Skills.pick_with_hint(stacked, c, near_cursor + Vector2(0, -16), 300.0, front) == front, "a hint near the cursor: taken")
	var lag_edge: Vector2 = Combat.body_centre(behind.sim_position) + Vector2(Config.SKILL_GRAB_RADIUS_PX + Config.SKILL_PICK_LAG_PX, 0)
	check(Skills.pick_with_hint(stacked, c, lag_edge, 300.0, behind) == behind,
		"a hint at the radius plus the lag allowance: taken (the sender drew him there)")
	check(Skills.pick_with_hint(stacked, c, lag_edge + Vector2(1, 0), 300.0, behind) != behind,
		"a hint one px farther: the host's own pick instead")
	check(Skills.pick_with_hint(stacked, c, near_cursor, 10.0, front) == null,
		"a hint out of the skill's range: not taken (nor anyone else in range)")
	var stranger: Player = player(open_world(), "miner", front.sim_position)
	check(Skills.pick_with_hint(stacked, c, near_cursor, 300.0, stranger) == front, "a hint not in the party: the host's own pick")
	behind.take_hit(Config.PLAYER_HP_MAX)
	check(Skills.pick_with_hint(stacked, c, Combat.body_centre(behind.sim_position), 300.0, behind) == front,
		"a downed hint: the host's own pick")
	# The range (feet to feet from the caster).
	var far: Player = player(d, "paladin", Vector2(100 + 120, 220))
	var with_far: Array[Player] = [c, far]
	check(Skills.pick_ally(with_far, c, far.sim_position, r) == null, "out of the skill's range: nobody (%.0f px)" % c.sim_position.distance_to(far.sim_position))
	check(Skills.pick_ally(with_far, c, far.sim_position, 300.0) == far, "in a longer range: picked")
	# Down and dead allies are skipped; the next nearest within the radius gets it.
	var g1: Player = player(d, "archer", Vector2(200, 60))
	var g2: Player = player(d, "miner", Vector2(220, 60))
	var downs: Array[Player] = [c, g1, g2]
	g1.take_hit(Config.PLAYER_HP_MAX)
	check(Skills.pick_ally(downs, c, g1.sim_position, 300.0) == g2, "a downed ally is skipped")
	g2.vitals.life = Vitals.Life.DEAD
	check(Skills.pick_ally(downs, c, g1.sim_position, 300.0) == null, "a dead one too")
	# Another map's player is never picked; heretics are never in the party.
	var other: Player = player(open_world(), "paladin", Vector2(160, 100))
	var mixed: Array[Player] = [c, other]
	check(Skills.pick_ally(mixed, c, other.sim_position, r) == null, "another map's player: never")
	var arena: Arena = arena_for(d)
	var foe: HereticSim = arena.spawn_heretic(Vector2(260, 100))
	var near_foe: Player = player(d, "miner", Vector2(260, 130))
	var with_foe: Array[Player] = [c, near_foe]
	check(Skills.pick_ally(with_foe, c, foe.pos, 300.0) == near_foe, "a heretic at the cursor: the ally beside it gets it")
	# aim_target: the cleric's heal while ready, the herbalist's healing / buff throw.
	check(Skills.aim_target(c, party, a1.sim_position) == a1, "the cleric's heal: the ring goes under that ally")
	c.skills.start_cooldown(Skills.Slot.IDENTITY, 5)
	check(Skills.aim_target(c, party, a1.sim_position) == null, "on cooldown: no ring")
	var h: Player = player(d, "herbalist", Vector2(100, 100))
	var hparty: Array[Player] = [h, a1, far]
	check(Skills.aim_target(h, hparty, a1.sim_position) == null, "nothing selected: no ring")
	h.inventory.add(&"potion_buff", 1)
	h.inventory.select(slot_of(h.inventory, &"potion_buff"))
	check(Skills.aim_target(h, hparty, a1.sim_position) == a1, "a buff potion selected: the ring")
	check(Skills.aim_target(h, hparty, far.sim_position) == null, "beyond the throw's range: none")
	h.inventory.clear()
	h.inventory.add(&"potion_poison", 1)
	h.inventory.select(0)
	check(Skills.aim_target(h, hparty, a1.sim_position) == null, "poison: no ring (aimed at the point)")
	check(Skills.aim_target(a1, party, a1.sim_position) == null, "a paladin has no heal")
	# M9 review: no ring while a panel is open or the altar is carried (the key would be refused); a dim ring on a full-HP ally.
	var c2: Player = player(d, "cleric", Vector2(100, 100))
	var party2: Array[Player] = [c2, a1]
	check(Skills.aim_target(c2, party2, a1.sim_position) == a1 and Skills.aim_refused(c2, a1),
		"the heal's ring on a full-HP ally: shown, marked refused")
	a1.vitals.hp = 70
	check(not Skills.aim_refused(c2, a1), "a hurt ally: not refused")
	c2.ui_locked = true
	check(Skills.aim_target(c2, party2, a1.sim_position) == null, "a panel open: no ring")
	c2.ui_locked = false
	c2.carrying_altar = true
	check(Skills.aim_target(c2, party2, a1.sim_position) == null, "carrying the altar: no ring")
	c2.carrying_altar = false
	h.inventory.clear()
	h.inventory.add(&"potion_buff", 1)
	h.inventory.select(0)
	a1.vitals.hp = Config.PLAYER_HP_MAX
	check(Skills.aim_target(h, hparty, a1.sim_position) == a1 and not Skills.aim_refused(h, a1),
		"a buff throw at a full-HP ally: not refused (a buff, not a heal)")


# --- threat (○ §2.3) ------------------------------------------------------------------------------------

func _check_threat() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var p1: Player = player(d, "paladin", Vector2(100, 200))
	var p2: Player = player(d, "archer", Vector2(160, 200))
	var players: Array[Player] = [p1, p2]
	var h: HereticSim = a.spawn_heretic(Vector2(120, 140))
	var id1: int = p1.get_instance_id()
	var id2: int = p2.get_instance_id()
	check(a.pick_target(h, players) == p1, "no threat: the nearest (M4)")
	a.hit_heretic(h, 12, id2)
	check_eq(h.threat_of(id2), 12 * Config.THREAT_PER_DAMAGE, "damage adds threat for its dealer")
	check(a.pick_target(h, players) == p2, "the highest threat, though farther")
	a.hit_heretic(h, 12, id1)
	check(a.pick_target(h, players) == p1, "equal threat: the nearer")
	a.hit_heretic(h, 1, id1)
	check(a.pick_target(h, players) == p1, "13 > 12")
	a.add_threat(h, id2, 5)
	check(a.pick_target(h, players) == p2, "17 > 13: damage order decides")
	a.hit_heretic(h, 3, 0)
	check(not h.threat.has(0), "an unknown dealer adds nothing")
	# Threat off (a session's host until M9c): the M4 rule, and nothing is kept.
	var off: Arena = arena_for(d, false)
	var h2: HereticSim = off.spawn_heretic(Vector2(120, 140))
	off.hit_heretic(h2, 12, id2)
	check(h2.threat.is_empty() and off.pick_target(h2, players) == p1, "threat off: the nearest, no threat kept")
	off.taunt(p2, 200.0, 240)
	check(off.pick_target(h2, players) == p1, "threat off: a taunt forces nothing")
	# A valid target only: a high threat out of sight does not count.
	var p3: Player = player(d, "cleric", Vector2(500, 400))
	var h3: HereticSim = a.spawn_heretic(Vector2(130, 140))
	a.add_threat(h3, p3.get_instance_id(), 999)
	var three: Array[Player] = [p1, p2, p3]
	check(a.pick_target(h3, three) == p1, "a high threat out of sight: the nearest valid one")
	# Heals: a little threat for the healer on every heretic engaged with someone near the healed ally.
	var hc: Player = player(d, "cleric", Vector2(300, 260))
	var near_heal: HereticSim = a.spawn_heretic(Vector2(150, 150))
	near_heal.has_target = true
	near_heal.target_id = id2
	var far_heal: HereticSim = a.spawn_heretic(Vector2(400, 100))
	var p_far: Player = player(d, "miner", Vector2(400, 150))
	far_heal.has_target = true
	far_heal.target_id = p_far.get_instance_id()
	var idle: HereticSim = a.spawn_heretic(Vector2(170, 150))
	var all: Array[Player] = [p1, p2, hc, p_far]
	var n: int = a.heal_threat(hc.get_instance_id(), p2, 25, all)
	check_eq(n, 1, "one heretic is engaged near the healed ally")
	check_eq(near_heal.threat_of(hc.get_instance_id()), 25 * Config.THREAT_HEAL_PCT / 100, "it gets %d%% of the heal" % Config.THREAT_HEAL_PCT)
	check(far_heal.threat.is_empty() and idle.threat.is_empty(), "one engaged far away and an idle one get none")
	a.heal_threat(hc.get_instance_id(), p2, 1, all)
	check_eq(near_heal.threat_of(hc.get_instance_id()), 25 * Config.THREAT_HEAL_PCT / 100 + 1, "a heal of 1: at least 1")
	check_eq(a.heal_threat(hc.get_instance_id(), p2, 0, all), 0, "no HP healed: none")
	# Poison: the thrower's threat on every poison tick.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var q1: Player = player(d2, "paladin", Vector2(100, 200))
	var q2: Player = player(d2, "herbalist", Vector2(160, 200))
	var qs: Array[Player] = [q1, q2]
	var hp: HereticSim = a2.spawn_heretic(Vector2(120, 150))
	a2.poison_heretic(hp, 3, 300, q2.get_instance_id())
	step_all(qs, a2, Config.POISON_INTERVAL_TICKS)
	check_eq(hp.threat_of(q2.get_instance_id()), 3 * Config.THREAT_PER_DAMAGE, "a poison tick: the thrower's threat")
	check(hp.target_id == q2.get_instance_id(), "and it goes after the thrower")
	# Forgetting: no valid target left (everyone gone out of sight), walking home, the map emptied.
	q1.teleport(Vector2(600, 450))
	q2.teleport(Vector2(620, 450))
	step_all(qs, a2, 1)
	check(hp.threat.is_empty() and not hp.has_target, "no valid target: the threat is forgotten")
	var hl: HereticSim = a2.spawn_heretic(Vector2(300, 300))
	a2.add_threat(hl, q1.get_instance_id(), 10)
	hl.taunt_by = q1.get_instance_id()
	hl.taunt_ticks = 100
	hl.pos = hl.home + Vector2(Config.HERETIC_LEASH_PX + 1, 0)
	a2.step(qs)
	check(hl.state == HereticSim.State.RETURN and hl.threat.is_empty() and not hl.taunted(), "walking home: forgotten")
	var he: HereticSim = a2.spawn_heretic(Vector2(310, 300))
	a2.add_threat(he, q1.get_instance_id(), 10)
	a2.occupied = true
	a2.idle_tick()
	check(he.threat.is_empty(), "the map emptied: forgotten")


## The M4 light rules hold with threat on: a heretic never steps into the light, never goes after or hurts a player inside it,
## whatever its threat or a taunt says.
func _check_threat_light() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var a: Arena = arena_for(data)
	var center: Vector2 = data.altar_center_px()
	var rad: float = Config.safe_radius_px()
	var inside: Player = player(data, "paladin", center + Vector2(0, rad - 6.0))
	var outside: Player = player(data, "archer", center + Vector2(40, rad + 30.0))
	var players: Array[Player] = [inside, outside]
	var h: HereticSim = a.spawn_heretic(center + Vector2(0, rad + 50.0))
	a.add_threat(h, inside.get_instance_id(), 500)
	check(a.pick_target(h, players) == outside, "the high threat is in the light: the valid one outside")
	var alone: Array[Player] = [inside]
	check(a.pick_target(h, alone) == null, "only the one in the light: nobody")
	a.taunt(inside, 200.0, 600)
	var entered: int = 0
	var hurt_inside: int = 0
	var targeted_inside: int = 0
	for t: int in 400:
		step_all(alone, a, 1)
		if not Combat.box_outside_light(data, a.safe, h.pos):
			entered += 1
		if h.has_target and h.target_id == inside.get_instance_id() and h.state == HereticSim.State.CHASE:
			targeted_inside += 1
	hurt_inside = Config.PLAYER_HP_MAX - inside.vitals.hp
	check_eq(entered, 0, "taunted from inside the light: never a foot in it")
	check_eq(hurt_inside, 0, "never hurts the paladin inside")
	check_eq(targeted_inside, 0, "never chases him in")


# --- the taunt ------------------------------------------------------------------------------------------

func _check_taunt() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var pal: Player = player(d, "paladin", Vector2(200, 200))
	var arc: Player = player(d, "archer", Vector2(240, 200))
	var players: Array[Player] = [pal, arc]
	var h: HereticSim = a.spawn_heretic(Vector2(215, 150))
	var pid: int = pal.get_instance_id()
	var aid: int = arc.get_instance_id()
	a.add_threat(h, aid, 30)
	check(a.pick_target(h, players) == arc, "setup: it goes after the archer")
	var radius: float = Skills.num_f(Skills.TAUNT, "radius_px")
	var ticks: int = Skills.num_i(Skills.TAUNT, "taunt_ticks")
	var out: HereticSim = a.spawn_heretic(pal.sim_position + Vector2(-radius - 4.0, 0))
	var homebound: HereticSim = a.spawn_heretic(pal.sim_position + Vector2(0, 40))
	homebound.state = HereticSim.State.RETURN
	var dead: HereticSim = a.spawn_heretic(pal.sim_position + Vector2(10, 30))
	a.hit_heretic(dead, Config.HERETIC_HP, aid)
	# A wall between (west of him, away from the archer's line): not taunted.
	var wall_cell: Vector2i = Aim.cell_of(Combat.body_point(pal.sim_position) + Vector2(-24, 0))
	d.set_value(WorldData.Layer.WALL, wall_cell, Walls.pack(Walls.KIND_ROCK, 0))
	var walled: HereticSim = a.spawn_heretic(pal.sim_position + Vector2(-48, 0))
	out.pos = pal.sim_position + Vector2(0, radius + 4.0)
	out.home = out.pos
	var n: int = a.taunt(pal, radius, ticks)
	check_eq(n, 1, "one heretic in reach (out of reach, walking home, dead and behind a wall: not)")
	check(h.taunted() and h.taunt_by == pid and h.taunt_ticks == ticks, "taunted for %d ticks" % ticks)
	check_eq(h.threat_of(pid), 30 + Config.TAUNT_THREAT_MARGIN, "his threat goes to the top")
	check(not out.taunted() and not homebound.taunted() and not dead.taunted() and not walled.taunted(),
		"the others are not")
	check(a.pick_target(h, players) == pal, "forced onto the paladin")
	a.add_threat(h, aid, 100)
	check(a.pick_target(h, players) == pal, "forced for its time, whatever the threat")
	check(a.bursts.size() == 1 and a.bursts[0].kind == Arena.BurstKind.TAUNT and a.bursts[0].radius == radius,
		"a taunt burst around him")
	# It runs out exactly after its ticks; then the highest threat again.
	for gone: HereticSim in [out, walled, homebound]:
		gone.pos = Vector2(600, 450)
		gone.home = gone.pos
	var forced: int = 0
	for t: int in ticks - 1:
		step_all(players, a, 1)
		if h.target_id == pid:
			forced += 1
	check(h.taunted() and h.taunt_ticks == 1, "still taunted one tick before the end (%d)" % h.taunt_ticks)
	check_eq(forced, ticks - 1, "on the paladin all that time")
	step_all(players, a, 1)
	check(not h.taunted() and h.taunt_by == 0, "the taunt ran out")
	check(a.pick_target(h, players) == arc, "then the highest threat (130 > 31)")
	check(pal.vitals.hp < Config.PLAYER_HP_MAX, "the paladin took its knife meanwhile (%d)" % pal.vitals.hp)
	# Through the key: the paladin's action, the impact frame, the cooldown, the mark on the heretic.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var p2: Player = player(d2, "paladin", Vector2(200, 200))
	var party: Array[Player] = [p2]
	wire(p2, a2, party)
	var h2: HereticSim = a2.spawn_heretic(Vector2(220, 160))
	press(p2, Skills.Slot.IDENTITY, Vector2(260, 200))
	for t2: int in Skills.impact_tick(Skills.TAUNT):
		tick(p2)
	check(h2.taunted() and h2.taunt_by == p2.get_instance_id(), "key 1 taunts on its impact frame")
	check_eq(p2.skills.cooldown(Skills.Slot.IDENTITY), Skills.cooldown_ticks(Skills.TAUNT), "and its cooldown starts")


# --- the piercing arrow ------------------------------------------------------------------------------------

func _check_piercing_arrow() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var arc: Player = player(d, "archer", Vector2(100, 200))
	var players: Array[Player] = [arc]
	var line: Array[HereticSim] = []
	for x: int in [140, 170, 200]:
		line.append(a.spawn_heretic(Vector2(x, 200)))
	var beyond: HereticSim = a.spawn_heretic(Vector2(100 + Skills.num_f(Skills.PIERCING_ARROW, "reach_px") + 20.0, 200))
	var dmg: int = Skills.num_i(Skills.PIERCING_ARROW, "damage")
	var s: Arena.Shot = a.skill_shot(arc, Skills.PIERCING_ARROW, 0, dmg, Skills.num_f(Skills.PIERCING_ARROW, "reach_px"),
		Skills.num_f(Skills.PIERCING_ARROW, "speed"), true)
	check(s.pierce and s.left == ceili(240.0 / 260.0 * 60.0), "a piercing shot: %d ticks of flight" % s.left)
	for t: int in 80:
		a.step(players)
		for hh: HereticSim in line:
			if hh.state == HereticSim.State.HURT:
				pass
	var hps: Array[int] = []
	for hh2: HereticSim in line:
		hps.append(hh2.hp)
	check_eq(hps, [40 - dmg, 40 - dmg, 40 - dmg] as Array[int], "it passed through all three, each hit once")
	check_eq(beyond.hp, Config.HERETIC_HP, "not beyond its reach")
	check(s.done and s.stopped_by == "spent", "spent at its reach (%s)" % s.stopped_by)
	check_eq(a.stat("pierce_hits"), 3, "three pierce hits")
	check_eq(line[0].threat_of(arc.get_instance_id()), dmg, "each hit is threat for the archer")
	# A wall stops it.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var arc2: Player = player(d2, "archer", Vector2(100, 200))
	var two: Array[HereticSim] = [a2.spawn_heretic(Vector2(140, 200)), a2.spawn_heretic(Vector2(200, 200))]
	d2.set_value(WorldData.Layer.WALL, Aim.cell_of(Vector2(170, 198)), Walls.pack(Walls.KIND_ROCK, 0))
	var s2: Arena.Shot = a2.skill_shot(arc2, Skills.PIERCING_ARROW, 0, dmg, 240.0, 260.0, true)
	var p2s: Array[Player] = [arc2]
	for t2: int in 80:
		a2.step(p2s)
	check(two[0].hp == 40 - dmg and two[1].hp == 40 and s2.stopped_by == "wall", "a wall stops it (%s)" % s2.stopped_by)
	# The bow's basic arrow still stops at the first heretic.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var arc3: Player = player(d3, "archer", Vector2(100, 200))
	var three: Array[HereticSim] = [a3.spawn_heretic(Vector2(140, 200)), a3.spawn_heretic(Vector2(170, 200))]
	a3.player_attack(arc3, &"bow", 0)
	var p3s: Array[Player] = [arc3]
	for t3: int in 80:
		a3.step(p3s)
	check(three[0].hp < 40 and three[1].hp == 40, "the bow's arrow does not pierce")
	# Through the key.
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var arc4: Player = player(d4, "archer", Vector2(100, 200))
	var party: Array[Player] = [arc4]
	wire(arc4, a4, party)
	press(arc4, Skills.Slot.IDENTITY, Combat.aim_origin(arc4.sim_position) + Vector2(80, 0))
	check_eq(arc4.action_anim, RigData.Anim.BOW, "key 1: the bow action")
	for t4: int in Skills.impact_tick(Skills.PIERCING_ARROW):
		tick(arc4)
	check(a4.shots.size() == 1 and a4.shots[0].pierce and a4.shots[0].damage == dmg and a4.shots[0].item == Skills.PIERCING_ARROW,
		"on frame %d the piercing arrow leaves" % Skills.num_i(Skills.PIERCING_ARROW, "impact"))
	check(a4.shots.size() == 1 and a4.shots[0].aim == 0, "along the aim (east)")
	check_eq(arc4.skills.cooldown(Skills.Slot.IDENTITY), Skills.cooldown_ticks(Skills.PIERCING_ARROW), "its cooldown")


# --- the heal ---------------------------------------------------------------------------------------------

func _check_heal() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var cle: Player = player(d, "cleric", Vector2(100, 100))
	var ally: Player = player(d, "paladin", Vector2(140, 100))
	var party: Array[Player] = [cle, ally]
	wire(cle, a, party)
	var amount: int = Skills.num_i(Skills.HEAL, "heal_hp")
	# Full HP: refused, nothing spent.
	var why: Array[String] = []
	cle.skill_refused.connect(func(_s: int, _id: StringName, w: String) -> void: why.append(w))
	press(cle, Skills.Slot.IDENTITY, ally.sim_position)
	check(_last(why) == Skills.WHY_FULL_HP and cle.action_anim == -1, "the ally nearest the cursor is at full HP: refused")
	ally.vitals.hp = 50
	press(cle, Skills.Slot.IDENTITY, ally.sim_position + Vector2(0, 60))
	check(_last(why) == Skills.WHY_NO_ALLY and cle.action_anim == -1, "nobody near the cursor: refused, nothing spent")
	var f: NetProtocol.InputFrame = press(cle, Skills.Slot.IDENTITY, ally.sim_position + Vector2(3, -10))
	check(f.skill == Skills.HEAL and f.skill_target == ally.get_instance_id(), "key 1 near the ally: the heal goes to it")
	check_eq(cle.action_anim, RigData.Anim.MAGIC, "the magic action")
	var foe: HereticSim = a.spawn_heretic(ally.sim_position + Vector2(0, 30))
	foe.has_target = true
	foe.target_id = ally.get_instance_id()
	for t: int in Skills.impact_tick(Skills.HEAL) - 1:
		tick(cle)
	check_eq(ally.vitals.hp, 50, "not before the impact frame")
	tick(cle)
	check_eq(ally.vitals.hp, 50 + amount, "healed %d on frame %d" % [amount, Skills.num_i(Skills.HEAL, "impact")])
	check_eq(cle.skills.resource, amount * Config.CLERIC_FAITH_PER_HP, "the cleric's faith grew by the HP healed")
	check_eq(cle.skills.cooldown(Skills.Slot.IDENTITY), Skills.cooldown_ticks(Skills.HEAL), "the cooldown")
	check_eq(foe.threat_of(cle.get_instance_id()), amount * Config.THREAT_HEAL_PCT / 100, "a little threat on the heretic engaged with it")
	check(a.bursts.size() == 1 and a.bursts[0].kind == Arena.BurstKind.HEAL and a.bursts[0].follow_id == ally.get_instance_id(),
		"the heal's sparks over the ally")
	# Never past the maximum; faith only for what was healed.
	for t1: int in 30:
		tick(cle)
	cle.skills.start_cooldown(Skills.Slot.IDENTITY, 0)
	ally.vitals.hp = Config.PLAYER_HP_MAX - 10
	var res: int = cle.skills.resource
	press(cle, Skills.Slot.IDENTITY, ally.sim_position)
	for t2: int in Skills.impact_tick(Skills.HEAL):
		tick(cle)
	check(ally.vitals.hp == Config.PLAYER_HP_MAX and cle.skills.resource == res + 10, "up to the maximum, faith +10")
	# Himself, when the cursor is on him.
	for t3: int in 60:
		tick(cle)
	cle.skills.start_cooldown(Skills.Slot.IDENTITY, 0)
	cle.vitals.hp = 60
	press(cle, Skills.Slot.IDENTITY, cle.sim_position + Vector2(0, -8))
	for t4: int in Skills.impact_tick(Skills.HEAL):
		tick(cle)
	check_eq(cle.vitals.hp, 60 + amount, "the cleric heals himself")
	# Out of range: nobody.
	for t5: int in 60:
		tick(cle)
	cle.skills.start_cooldown(Skills.Slot.IDENTITY, 0)
	ally.vitals.hp = 50
	ally.teleport(cle.sim_position + Vector2(Skills.num_f(Skills.HEAL, "range_px") + 10.0, 0))
	press(cle, Skills.Slot.IDENTITY, ally.sim_position)
	check(_last(why) == Skills.WHY_NO_ALLY and cle.action_anim == -1, "the ally out of range: refused")
	# The ally goes down before the impact frame: it fizzles (nothing spent, no cooldown).
	ally.teleport(cle.sim_position + Vector2(40, 0))
	press(cle, Skills.Slot.IDENTITY, ally.sim_position)
	check_eq(cle.action_skill, Skills.HEAL, "setup: healing")
	ally.take_hit(Config.PLAYER_HP_MAX)
	res = cle.skills.resource
	for t6: int in Skills.impact_tick(Skills.HEAL):
		tick(cle)
	check(ally.vitals.life == Vitals.Life.DOWN and cle.skills.cooldown(Skills.Slot.IDENTITY) == 0 and cle.skills.resource == res,
		"down before it landed: it fizzles, no cooldown, no faith")
	check(Skills.land(cle, Skills.HEAL, null, party).why == Skills.WHY_NO_ARENA, "no arena: nothing")


# --- the ground slam --------------------------------------------------------------------------------------

func _check_ground_slam() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var m: Player = player(d, "miner", Vector2(200, 200))
	var radius: float = Skills.num_f(Skills.GROUND_SLAM, "radius_px")
	var dmg: int = Skills.num_i(Skills.GROUND_SLAM, "damage")
	var push: float = Skills.num_f(Skills.GROUND_SLAM, "push_px")
	var h1: HereticSim = a.spawn_heretic(Vector2(220, 200))
	var h2: HereticSim = a.spawn_heretic(Vector2(200, 239))
	var h3: HereticSim = a.spawn_heretic(Vector2(200 + radius + 5.0, 205))
	d.set_value(WorldData.Layer.WALL, Aim.cell_of(Vector2(184, 198)), Walls.pack(Walls.KIND_ROCK, 0))
	var h4: HereticSim = a.spawn_heretic(Vector2(170, 200))
	var h5: HereticSim = a.spawn_heretic(Vector2(215, 215))
	h5.state = HereticSim.State.ATTACK
	var hash_before: String = d.content_hash()
	var n: int = a.slam(m, radius, dmg, push)
	check_eq(n, 3, "three in reach with nothing between (one too far, one behind a wall)")
	check(h1.hp == 40 - dmg and h2.hp == 40 - dmg and h5.hp == 40 - dmg, "each took %d" % dmg)
	check(h3.hp == 40 and h4.hp == 40, "the far one and the walled one untouched")
	check_between(h1.pos.distance_to(m.sim_position), 20.0 + push - 0.01, 20.0 + push + 0.01, "pushed %.0f px away" % push)
	check_between(h2.pos.distance_to(m.sim_position), 39.0 + push - 0.01, 39.0 + push + 0.01, "the other too")
	check(h1.state == HereticSim.State.HURT and h2.state == HereticSim.State.HURT, "staggered (the M4 rule)")
	check(h5.state == HereticSim.State.ATTACK and h5.pos.distance_to(m.sim_position) > 21.3 + push - 0.5,
		"one mid-swing keeps its swing (Config.HERETIC_HURT_INTERRUPTS_ATTACK off) but is pushed")
	check_eq(h1.threat_of(m.get_instance_id()), dmg, "threat for the miner")
	check_eq(d.content_hash(), hash_before, "no world edit")
	check(a.bursts.size() == 1 and a.bursts[0].kind == Arena.BurstKind.SLAM and a.bursts[0].radius == radius, "a slam burst")
	# A wall behind stops the push.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var m2: Player = player(d2, "miner", Vector2(200, 200))
	var stop_cell: Vector2i = Aim.cell_of(Vector2(232, 200))
	d2.set_value(WorldData.Layer.WALL, stop_cell, Walls.pack(Walls.KIND_ROCK, 0))
	var h6: HereticSim = a2.spawn_heretic(Vector2(218, 200))
	a2.slam(m2, radius, dmg, push)
	check(h6.pos.x < float(stop_cell.x * Config.TILE) and Movement.can_stand(d2, h6.pos) and h6.pos.x > 218.0,
		"a wall behind stops the push (%.1f)" % h6.pos.x)
	# Never into the light.
	var sd: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var sa: Arena = arena_for(sd)
	var c: Vector2 = sd.altar_center_px()
	var rad: float = Config.safe_radius_px()
	var edge_h: HereticSim = sa.spawn_heretic(c + Vector2(0, rad + 8.0))
	var sm: Player = player(sd, "miner", c + Vector2(0, rad + 28.0))
	sa.slam(sm, radius, dmg, push)
	check(Combat.box_outside_light(sd, sa.safe, edge_h.pos), "never pushed into the light")
	# Through the key: the pickaxe action, no mining even aimed at a wall.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	var m3: Player = player(d3, "miner", Arena.spawn_feet(Vector2i(10, 10)))
	var party: Array[Player] = [m3]
	wire(m3, a3, party)
	var wall: Vector2i = Vector2i(11, 10)
	d3.set_value(WorldData.Layer.WALL, wall, Walls.pack(Walls.KIND_ROCK, 0))
	var hits_before: int = Walls.hits_at(d3, wall)
	var h7: HereticSim = a3.spawn_heretic(m3.sim_position + Vector2(0, 30))
	press(m3, Skills.Slot.IDENTITY, Vector2(wall * Config.TILE) + Vector2(8, 8))
	check_eq(m3.action_anim, RigData.Anim.PICKAXE, "key 1: the pickaxe action")
	for t: int in Skills.impact_tick(Skills.GROUND_SLAM):
		tick(m3)
	check(h7.hp == 40 - dmg, "it slams on frame %d" % Skills.num_i(Skills.GROUND_SLAM, "impact"))
	check(Walls.is_wall(d3, wall) and Walls.hits_at(d3, wall) == hits_before, "and mines nothing")
	check_eq(m3.skills.cooldown(Skills.Slot.IDENTITY), Skills.cooldown_ticks(Skills.GROUND_SLAM), "its cooldown")


# --- the herbalist's throw (● R42 retarget) ----------------------------------------------------------------

func _check_throw_retarget() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var herb: Player = player(d, "herbalist", Vector2(100, 100))
	var ally: Player = player(d, "paladin", Vector2(130, 110))
	var party: Array[Player] = [herb, ally]
	wire(herb, a, party)
	herb.inventory.add(&"potion_healing", 3)
	herb.inventory.add(&"potion_buff", 1)
	herb.inventory.add(&"potion_poison", 2)
	herb.inventory.select(slot_of(herb.inventory, &"potion_healing"))
	ally.vitals.hp = 40
	var origin: Vector2 = Combat.body_point(herb.sim_position)
	var f: NetProtocol.InputFrame = press(herb, Skills.Slot.IDENTITY, ally.sim_position + Vector2(6, -8))
	check(f.op == NetProtocol.Op.THROW and f.item == &"potion_healing" and f.skill == Skills.POTION_THROW, "key 1: the throw")
	check_eq(f.skill_target, ally.get_instance_id(), "a healing potion goes to the ally nearest the cursor (● R42)")
	check_eq(f.throw_to, Combat.body_point(ally.sim_position).round(), "thrown at the ally's body point")
	# The ally walks on while the bottle flies: it follows and lands on the ally.
	var landed_at: Vector2 = Vector2.INF
	var ally_body: Vector2 = Vector2.ZERO
	for t: int in 80:
		tick(herb)
		walk(ally, Vector2(1, 0))
		var splashes: int = a.stat("splashes")
		a.step(party)
		if a.stat("splashes") > splashes:
			var sp: Arena.Splash = a.splashes[a.splashes.size() - 1]
			landed_at = sp.pos
			ally_body = Combat.body_point(ally.sim_position)
	check(landed_at.distance_to(ally_body) < 0.01, "it lands on the ally where it walked to (%s vs %s)" % [landed_at, ally_body])
	check(ally.sim_position.x > 160.0, "setup: the ally walked (%.0f)" % ally.sim_position.x)
	check_eq(ally.vitals.hp, 40 + Config.POTION_HEAL_HP[ItemDB.Grade.COMMON], "and heals it")
	check_eq(herb.inventory.count_of(&"potion_healing"), 2, "one used")
	# Again at once (cooldown 0, M6's rate): a buff to the ally.
	ally.teleport(herb.sim_position + Vector2(40, 0))
	herb.inventory.select(slot_of(herb.inventory, &"potion_buff"))
	var g: NetProtocol.InputFrame = press(herb, Skills.Slot.IDENTITY, ally.sim_position)
	check(g.skill_target == ally.get_instance_id() and herb.action_anim == RigData.Anim.THROW, "the buff too, right after")
	for t2: int in 80:
		step_all(party, a, 1)
	check(ally.vitals.buffed(), "the ally is buffed")
	# Nobody near the cursor: refused, nothing thrown or used.
	herb.inventory.select(slot_of(herb.inventory, &"potion_healing"))
	var why: Array[String] = []
	herb.skill_refused.connect(func(_s: int, _id: StringName, w: String) -> void: why.append(w))
	var throws: int = a.stat("throws")
	press(herb, Skills.Slot.IDENTITY, ally.sim_position + Vector2(0, 80))
	check(_last(why) == Skills.WHY_NO_ALLY and herb.action_anim == -1 and a.stat("throws") == throws
		and herb.inventory.count_of(&"potion_healing") == 2, "nobody near the cursor: refused, nothing used")
	# Beyond the throw's range: not picked.
	ally.teleport(herb.sim_position + Vector2(Config.THROW_RANGE_PX + 8.0, 0))
	press(herb, Skills.Slot.IDENTITY, ally.sim_position)
	check(_last(why) == Skills.WHY_NO_ALLY and herb.action_anim == -1, "the ally beyond the throw's range: refused")
	# The herbalist himself.
	herb.vitals.hp = 50
	var s: NetProtocol.InputFrame = press(herb, Skills.Slot.IDENTITY, herb.sim_position + Vector2(0, -10))
	check(s.skill_target == herb.get_instance_id() and s.throw_to == origin.round(), "the cursor on himself: at his own feet")
	for t3: int in 80:
		step_all(party, a, 1)
	check_eq(herb.vitals.hp, 50 + Config.POTION_HEAL_HP[ItemDB.Grade.COMMON], "and heals himself")
	# Poison stays aimed at the cursor (a debuff, not a heal or buff), an ally near it or not.
	ally.teleport(herb.sim_position + Vector2(50, 0))
	herb.inventory.select(slot_of(herb.inventory, &"potion_poison"))
	var cursor: Vector2 = ally.sim_position + Vector2(4, -6)
	var pz: NetProtocol.InputFrame = press(herb, Skills.Slot.IDENTITY, cursor)
	check(pz.skill_target == 0 and pz.throw_to == Potions.throw_target(origin, cursor).round(), "poison: aimed at the cursor point")
	# Skills off (a session's player until M9c): M6's aimed throw, untouched.
	var old: Player = player(d, "herbalist", Vector2(300, 100))
	old.skills_on = false
	old.inventory.add(&"potion_healing", 1)
	old.inventory.select(0)
	var mate: Player = player(d, "paladin", Vector2(340, 100))
	var mouse: Vector2 = mate.sim_position + Vector2(10, 10)
	var of: NetProtocol.InputFrame = old.make_frame(Vector2i.ZERO, mouse, true, false, false, false, false, true)
	check(of.op == NetProtocol.Op.THROW and of.skill.is_empty() and of.skill_target == 0
		and of.throw_to == Potions.throw_target(Combat.body_point(old.sim_position), mouse).round(),
		"skills off: M6's throw at the mouse point (the session path)")
	check(old.party().size() == 1 and old.party()[0] == old, "no party provider: alone")


# --- the HUD row's rules (pixels: tools/check_render.gd "skills_hud") -------------------------------------

func _check_hud_rules() -> void:
	for view: Vector2i in [Vector2i(480, 270), Vector2i(540, 270), Vector2i(480, 360), Vector2i(640, 270)]:
		var h: int = Config.HOTBAR_SLOTS
		var last: Vector2i = Hud.slot_origin(h - 1, h, view)
		var first_skill: Vector2i = Hud.skill_slot_origin(0, h, view)
		check_eq(first_skill, Vector2i(last.x + Hud.SLOT + Hud.SKILL_GAP, last.y), "the row starts %d px right of the hotbar (%s)" % [Hud.SKILL_GAP, view])
		var r_slot: Vector2i = Hud.skill_slot_origin(Skills.Slot.SIGNATURE, h, view)
		check(r_slot.x + Hud.SLOT <= view.x, "the R slot inside the view (%s)" % view)
		for s: int in SkillState.SLOT_COUNT:
			check_eq(Hud.skill_slot_origin(s, h, view).x - first_skill.x, s * (Hud.SLOT + Hud.GAP), "slot %d apart (%s)" % [s, view])
		var bar: Rect2i = Hud.skill_bar_rect(h, view)
		check_eq(bar.end.y + 1 + Hud.SKILL_BAR_GAP, first_skill.y, "the bar's frame %d px above the slots (%s)" % [Hud.SKILL_BAR_GAP, view])
		check(bar.position.x - 1 == first_skill.x and bar.end.x + 1 == r_slot.x + Hud.SLOT, "the bar's frame spans the row")
		var grid_right: int = Hud.slot_origin(Config.INVENTORY_SLOTS - 1, h, view).x + Hud.SLOT
		check(first_skill.x > grid_right, "clear of the inventory grid")
	check_eq(Hud.skill_pips(Config.HOTBAR_SLOTS, Vector2i(480, 270)), 12, "twelve herb pips fit")
	check_eq(Hud.skill_cost_x(50, 100, 76), 37, "the cost tick where a meter of 50 ends")
	check_eq(Hud.skill_cost_x(30, 100, 76), 22, "the archer's minimum")
	var d: WorldData = open_world()
	var p: Player = player(d, "paladin", Arena.spawn_feet(Vector2i(10, 10)))
	var full: int = Skills.cooldown_ticks(Skills.TAUNT)
	check_eq(Hud.skill_veil_rows(p, 0), 0, "ready: no veil")
	p.skills.start_cooldown(0, full)
	check_eq(Hud.skill_veil_rows(p, 0), 14, "just landed: the whole slot veiled")
	p.skills.start_cooldown(0, full / 2)
	check_eq(Hud.skill_veil_rows(p, 0), 7, "half way: half")
	p.skills.start_cooldown(0, 1)
	check_eq(Hud.skill_veil_rows(p, 0), 1, "one tick left: one row")
	var hud: Hud = Hud.new()
	add_node(hud)
	hud.bind(p.inventory)
	hud.bind_player(p)
	var k1: String = hud.skills_key()
	p.skills.refuse(Skills.Slot.CHOICE, Skills.WHY_LOCKED)
	var k2: String = hud.skills_key()
	p.skills.resource = 40
	var k3: String = hud.skills_key()
	check(not k1.is_empty() and k1 != k2 and k2 != k3, "the row redraws for a cooldown, a refusal, the meter")
	p.skills_on = false
	check(hud.skills_key().is_empty(), "skills off (a session until M9c): no row")


# --- what is drawn -----------------------------------------------------------------------------------------

func _check_views() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var ents: Node2D = Node2D.new()
	add_node(ents)
	var view: CombatView = CombatView.new()
	add_node(view)
	view.setup(a, ents)
	var pal: Player = player(d, "paladin", Vector2(200, 200))
	var ally: Player = player(d, "archer", Vector2(240, 200))
	var players: Array[Player] = [pal, ally]
	var h: HereticSim = a.spawn_heretic(Vector2(215, 160))
	a.taunt(pal, 64.0, 240)
	a.add_burst(Arena.BurstKind.SLAM, pal.sim_position, 40.0)
	a.add_burst(Arena.BurstKind.HEAL, ally.sim_position, Config.SKILL_HEAL_SHOW_RADIUS_PX, ally.get_instance_id())
	view.sync(players)
	check_eq(view.bursts.size(), 3, "a node per burst")
	check(view.heretics.has(h.id) and view.heretics[h.id].marks.shown.has(EffectMarks.Kind.TAUNT), "the taunt mark over the heretic")
	# A ring's dots lie on its ring.
	for kind: int in [Arena.BurstKind.TAUNT, Arena.BurstKind.SLAM]:
		for frame: int in CombatView.BURST_FRAMES:
			var img: Image = CombatView.burst_image(kind, frame, 64.0)
			var half: int = CombatView.burst_half(64.0)
			var ring: float = 64.0 * (frame + 1) / CombatView.BURST_FRAMES
			var off_ring: int = 0
			var opaque: int = 0
			for y: int in img.get_height():
				for x: int in img.get_width():
					if img.get_pixel(x, y).a8 > 0:
						opaque += 1
						var dist: float = Vector2(x - half, y - half).length()
						if dist < ring - 2.5 or dist > ring + 2.5:
							off_ring += 1
			check(opaque >= CombatView.BURST_MIN_DOTS * 3 and off_ring == 0, "burst %d frame %d: dots on the ring (%d px, %d off)" % [kind, frame, opaque, off_ring])
	var heal_img: Image = CombatView.burst_image(Arena.BurstKind.HEAL, 0, Config.SKILL_HEAL_SHOW_RADIUS_PX)
	var heal_px: int = 0
	for y2: int in heal_img.get_height():
		for x2: int in heal_img.get_width():
			if heal_img.get_pixel(x2, y2).a8 > 0:
				heal_px += 1
	check_eq(heal_px, 4 * 5, "the heal: four plus signs")
	# The heal follows the ally; the bursts end after their ticks.
	ally.teleport(Vector2(260, 210))
	step_all(players, a, 1)
	view.sync(players)
	var heal_node: Node2D = null
	for b: Arena.Burst in a.bursts:
		if b.kind == Arena.BurstKind.HEAL:
			heal_node = view.bursts[b.id]
	check(heal_node != null and heal_node.position == ally.sim_position.round(), "the heal's sparks follow the ally")
	step_all(players, a, Config.SKILL_BURST_TICKS)
	view.sync(players)
	check(a.bursts.is_empty() and view.bursts.is_empty(), "gone after %d ticks" % Config.SKILL_BURST_TICKS)
	# The piercing arrow's picture.
	var s: Arena.Shot = a.skill_shot(pal, Skills.PIERCING_ARROW, 0, 16, 240.0, 260.0, true)
	view.sync(players)
	var sp: Sprite2D = view.shots[s.id].get_node(^"Sprite") as Sprite2D
	check(sp.texture == CombatView.pierce_texture() and sp.texture != CombatView.arrow_texture(), "the piercing arrow's own picture")
	view.clear()
	# The ally ring.
	var mark: AllyMark = AllyMark.new()
	add_node(mark)
	mark.show_for(ally)
	check(mark.visible and mark.position == ally.position and mark.target == ally, "the ring under the ally")
	mark.show_for(null)
	check(not mark.visible and mark.target == null, "hidden with nobody")
	var ring: Image = AllyMark.image()
	var gold: int = 0
	for row: Variant in AllyMark.MAP:
		var line: String = row
		gold += line.count("g")
	var drawn: int = 0
	for y3: int in ring.get_height():
		for x3: int in ring.get_width():
			if ring.get_pixel(x3, y3).a8 > 0:
				drawn += 1
				check(ring.get_pixel(x3, y3).to_rgba32() == AllyMark.GOLD.to_rgba32(), "a ring pixel is faith gold")
	check_eq(drawn, gold, "the ring's pixels = its map")


# --- main.tscn offline ------------------------------------------------------------------------------------

func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn("cleric")
	var p: Player = main.player
	p.local_input = false
	check(p.skills_on and p.party_provider.is_valid(), "main: the offline player has the skill kit")
	check(main.arenas[Config.MAP_SURFACE].threat_on, "main: the offline arenas have threat on")
	main.arenas[Config.MAP_SURFACE].spawning = false
	var ally: Player = main.add_ally("paladin", false)
	check(ally.skills_on, "an ally's meter runs too")
	ally.vitals.hp = 50
	check(p.party().size() == 2 and p.party()[0] == p and p.party()[1] == ally, "the party: the local player, then the ally")
	# The ring under the ally the heal would go to (Main shows Player.skill_aim_target).
	var mouse: Vector2 = ally.sim_position + Vector2(2, -10)
	_tick_main(main, p, mouse, false)
	check(p.skill_aim_target == ally, "the heal is ready: it would go to the ally")
	await tree.physics_frame
	await tree.physics_frame
	check(main.ally_mark.visible and main.ally_mark.target == ally, "main: the ring under it")
	_tick_main(main, p, mouse, true)
	check_eq(p.action_skill, Skills.HEAL, "key 1: the heal")
	for t: int in Skills.impact_tick(Skills.HEAL):
		_tick_main(main, p, mouse, false)
	check_eq(ally.vitals.hp, 50 + Skills.num_i(Skills.HEAL, "heal_hp"), "main: the ally healed")
	check(main.skills_landed == 1 and p.skills.resource > 0, "main: landed, faith grew")
	check(not main.hud.skills_key().is_empty(), "main: the HUD's skill row is shown")
	_tick_main(main, p, mouse, false)
	await tree.physics_frame
	await tree.physics_frame
	check(not main.ally_mark.visible, "on cooldown: no ring")
	# The miner's endurance from mining through Main (the bot swings at a dungeon wall).
	main.spawn(Mining.MINER_CLASS)
	main.player.inventory.add(&"pickaxe", 1)
	main.player.inventory.select(0)
	main.travel(Config.MAP_DUNGEON)
	main.arenas[Config.MAP_DUNGEON].spawning = false
	var w: GameWorld = main.current_world()
	var exit: Rect2i = DungeonGen.exit_rect(w.data)
	var face: Vector2i = Vector2i(exit.end.x + 1, exit.position.y)
	var feet_cell: Vector2i = face + Vector2i(0, 1)
	main.player.teleport(Vector2(feet_cell.x * 16 + 8, feet_cell.y * 16 + 14))
	main.bot = NetBot.new()
	main.bot.parse("aimat:%d,%d;use:%d" % [face.x, face.y, PlayerSim.action_ticks(RigData.Anim.PICKAXE) * 4])
	main.player.local_input = false
	for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE) * 4 + 4:
		await tree.physics_frame
	check(main.player.skills.resource >= Config.MINER_ENDURANCE_PER_BLOCK, "main: mining gave the miner endurance (%d)" % main.player.skills.resource)
	# A bot's skill key (the slam) through Main.
	var foe: HereticSim = main.arenas[Config.MAP_DUNGEON].spawn_heretic(main.player.sim_position + Vector2(0, 20))
	main.player.skills.start_cooldown(Skills.Slot.IDENTITY, 0)
	main.bot = NetBot.new()
	check(main.bot.parse("skill:1;wait:40").is_empty() and main.bot.parse("skill:x").contains("skill"), "the bot's skill key")
	main.bot.parse("wait:10;skill:1;wait:40")
	for i2: int in 52:
		await tree.physics_frame
	check(foe.hp == Config.HERETIC_HP - Skills.num_i(Skills.GROUND_SLAM, "damage"), "main: the bot's key 1 slams (%d)" % foe.hp)
	main.bot = null


## One offline tick of main: the player's controls (`skill` = key 1 this tick), then the combat.
static func _tick_main(main: Main, p: Player, mouse: Vector2, skill: bool) -> void:
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, mouse, true, false, false, TICK, false, false, skill)
	main.step_combat(TICK)
