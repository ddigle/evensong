extends "res://tests/base_test.gd"
## M9b, the weapon skills and the signatures (offline, on the M9a framework): the tables (the ten new rows, the impact frames on
## the weapons' own, the costs, the point skills), the held-weapon rule of key 2 (nothing, another class's weapon, a tool, the base
## and the tier-1 weapon, a broken one with Gear.broken_unusable, the tier-1's 150% and its wear, the weapon leaving its slot),
## every new skill's cooldown and its refusals (states, cooldown, not enough resource), each skill's effect and numbers (the
## crushing blow's arc and stun, the stun's rules: still for its ticks, cancels an attack, no stagger on top, the longer kept, the
## shrine; the fan's three arrows; the holy burst's circle and point; the heavy strike that never mines; the sweep's wide arc and
## the slow: speed, expiry, stacking, with poison, with a buffed ally, a death, the map emptying; reach_point; the oath's ward:
## who, how much, with armour, the minimum, its time, poison, death, the mark, a fizzle; the arrow rain's spend-all, damage from
## focus, delay and circle; the blessing's ring that follows, pulses, the cap, no faith, its end, its threat; the rockfall's
## delay, circle, stun and no world edit; the healing mist's herbs (exact counts, partial stacks, grades), its cloud, a fizzle),
## the light rules and threat with them, no friendly fire, determinism, what is drawn, the HUD, and main.tscn offline.

const TICK: float = 1.0 / 60.0
const WEAPON_SKILLS: Dictionary[String, StringName] = {"paladin": &"crushing_blow", "archer": &"fan_shot",
	"cleric": &"holy_burst", "miner": &"heavy_strike", "herbalist": &"sweep"}
const SIGNATURES: Dictionary[String, StringName] = {"paladin": &"guardian_oath", "archer": &"arrow_rain",
	"cleric": &"blessing", "miner": &"rockfall", "herbalist": &"healing_mist"}

var _nodes: Array[Node] = []
## The last skill that landed through wire() (its result).
var _landed: Skills.Landed


func run() -> Array[String]:
	_check_tables()
	_check_weapon_rule()
	_check_tier1_and_wear()
	_check_cooldowns()
	_check_refusals()
	_check_crushing_blow()
	_check_stun_rules()
	_check_fan_shot()
	_check_reach_point()
	_check_holy_burst()
	_check_heavy_strike()
	_check_sweep()
	_check_slow_rules()
	_check_oath()
	_check_arrow_rain()
	_check_blessing()
	_check_rockfall()
	_check_healing_mist()
	_check_light()
	_check_threat()
	_check_no_friendly_fire()
	_check_determinism()
	_check_views()
	_check_hud()
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


static func ticks(p: Player, n: int) -> void:
	for i: int in n:
		tick(p)


## Presses the key of skill slot `slot` with the mouse at `mouse` and steps the player one tick. Returns the frame.
static func press(p: Player, slot: int, mouse: Vector2) -> NetProtocol.InputFrame:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i.ZERO, mouse, true, false, false, false, false,
		slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	p.step_frame(f, TICK)
	return f


## Main's offline wiring for a test player: the near-cursor pick over `party`, a skill's impact lands on `a` (its world edits go
## into `a`'s data; the result is kept in _landed).
func wire(p: Player, a: Arena, party: Array[Player]) -> void:
	p.party_provider = func() -> Array[Player]: return party
	p.action_impact.connect(_impact.bind(p, a, party))


func _impact(item: StringName, _anim: int, _cell: Vector2i, p: Player, a: Arena, party: Array[Player]) -> void:
	if Skills.is_skill(item):
		_landed = Skills.land(p, item, a, party)
		for e: EditLog.WorldEdit in _landed.edits:
			EditLog.apply_to_data(a.data, e)


static func steps(a: Arena, players: Array[Player], n: int) -> void:
	for i: int in n:
		a.step(players)


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


## Puts item `id` in the hand (added when missing, then selected). Returns its slot.
static func hold(p: Player, id: StringName) -> int:
	if slot_of(p.inventory, id) < 0:
		p.inventory.add(id, 1)
	var s: int = slot_of(p.inventory, id)
	p.inventory.select(s)
	return s


## The mouse `dist` px from player `p`'s aim origin along `dir` (a weapon skill's aim).
static func aim_at(p: Player, dir: Vector2, dist: float = 60.0) -> Vector2:
	return Combat.aim_origin(p.sim_position) + dir.normalized() * dist


## Fills player `p`'s class resource (the meter to its cap; the herbalist: `herbs` healing herbs).
static func fill(p: Player, herbs: int = 9) -> void:
	if p.class_id() == "herbalist":
		var have: int = p.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM)
		if have < herbs:
			p.inventory.add(Config.HERBALIST_MATERIAL_ITEM, herbs - have)
	else:
		p.skills.resource = Skills.resource_cap(p.class_id())


## Collects player `p`'s refusals ("<slot>:<why>").
static func refusals(p: Player) -> Array[String]:
	var got: Array[String] = []
	p.skill_refused.connect(func(s: int, _id: StringName, w: String) -> void: got.append("%d:%s" % [s, w]))
	return got


static func _last(lines: Array[String]) -> String:
	return lines[lines.size() - 1] if not lines.is_empty() else ""


static func burst_of(a: Arena, kind: int) -> Arena.Burst:
	for b: Arena.Burst in a.bursts:
		if b.kind == kind:
			return b
	return null


static func opaque(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a8 > 0:
				n += 1
	return n


# --- the tables ------------------------------------------------------------------------------------------

func _check_tables() -> void:
	var own: Dictionary[StringName, Array] = {
		&"crushing_blow": ["damage", "reach_px", "arc_deg", "stun_ticks"],
		&"fan_shot": ["damage", "arrows", "spread_aim", "reach_px", "speed"],
		&"holy_burst": ["damage", "range_px", "radius_px"],
		&"heavy_strike": ["damage", "reach_px", "arc_deg"],
		&"sweep": ["damage", "reach_px", "arc_deg", "slow_pct", "slow_ticks"],
		&"guardian_oath": ["radius_px", "ward_pct", "ward_ticks"],
		&"arrow_rain": ["range_px", "radius_px", "delay_ticks", "damage", "damage_per_focus_pct"],
		&"blessing": ["radius_px", "duration_ticks", "interval_ticks", "heal_hp"],
		&"rockfall": ["range_px", "radius_px", "delay_ticks", "damage", "stun_ticks"],
		&"healing_mist": ["range_px", "radius_px", "duration_ticks", "interval_ticks", "heal_hp"],
	}
	for c: String in Config.CLASSES:
		var weapon: StringName = WEAPON_SKILLS[c]
		check_eq(Skills.kit_skill(c, Skills.Slot.WEAPON), weapon, "%s: key 2 = %s (its weapon's)" % [c, weapon])
		check(Skills.built(weapon) and Skills.slot_of(c, weapon) == Skills.Slot.WEAPON, "%s: the weapon skill is built" % c)
		check_eq(Skills.impact_tick(weapon), Combat.impact_tick(Combat.class_weapon(c)),
			"%s: %s lands on its weapon's own hit frame" % [c, weapon])
		var sig: StringName = SIGNATURES[c]
		check_eq(Skills.kit_skill(c, Skills.Slot.SIGNATURE), sig, "%s: key R = %s" % [c, sig])
		check(Skills.built(sig) and Skills.signature_cost(c) > 0, "%s: the signature is built and costs %d" % [c, Skills.signature_cost(c)])
	for id: StringName in own:
		var row: Dictionary = Config.SKILLS[id]
		for key: String in ["cooldown", "anim", "impact"]:
			check(row.has(key), "%s has %s" % [id, key])
		for key2: Variant in own[id]:
			var k: String = key2
			var v: float = row.get(k, 0.0)
			check(row.has(k) and v > 0.0, "%s has %s > 0" % [id, k])
		check(Skills.cooldown_ticks(id) > 0, "%s has a cooldown" % id)
		check(RigData.is_action(Skills.anim(id)), "%s plays a body action the slice has" % id)
		check(Skills.num_i(id, "impact") < RigData.frame_count(Skills.anim(id)), "%s lands inside its action" % id)
		check(SkillIcons.MAPS.has(id) and SkillIcons.map_for(id) != SkillIcons.LATER_MAP, "%s has its own icon" % id)
		check(not ItemDB.has(id) and Skills.is_skill(id), "%s is a skill id, no item id" % id)
	check_eq(Skills.POINT_SKILLS, [Skills.HOLY_BURST, Skills.ARROW_RAIN, Skills.ROCKFALL, Skills.HEALING_MIST] as Array[StringName],
		"the skills aimed at a point")
	check_eq(Skills.num_f(Skills.HEALING_MIST, "range_px"), Config.THROW_RANGE_PX, "the mist reaches as far as a throw")
	check_eq(Skills.impact_tick(Skills.HEALING_MIST), Potions.impact_tick(RigData.Anim.THROW), "the mist leaves the hand like a bottle")
	check_eq(Config.SKILL_SIGNATURE_COST, {"paladin": 50, "archer": 30, "cleric": 50, "miner": 40, "herbalist": 3} as Dictionary[String, int],
		"the signature costs (M9a's table)")
	check_eq(Skills.num_i(Skills.FAN_SHOT, "arrows"), 3, "the fan: three arrows")


# --- the held-weapon rule (key 2) --------------------------------------------------------------------------

func _check_weapon_rule() -> void:
	var d: WorldData = open_world()
	var others: Dictionary[String, StringName] = {"paladin": &"bow", "archer": &"sword", "cleric": &"pickaxe",
		"miner": &"sickle", "herbalist": &"holy_light"}
	for c: String in Config.CLASSES:
		var p: Player = player(d, c, Arena.spawn_feet(Vector2i(10, 10)))
		var got: Array[String] = refusals(p)
		var mouse: Vector2 = aim_at(p, Vector2.RIGHT)
		press(p, Skills.Slot.WEAPON, mouse)
		check(_last(got) == "1:%s" % Skills.WHY_NO_WEAPON and p.action_anim == -1, "%s: key 2 with nothing held: refused" % c)
		check(p.skills.shows_refusal(Skills.Slot.WEAPON), "%s: the HUD marks slot 2" % c)
		hold(p, others[c])
		press(p, Skills.Slot.WEAPON, mouse)
		check(_last(got) == "1:%s" % Skills.WHY_NO_WEAPON and p.action_anim == -1, "%s: another class's weapon: refused" % c)
		hold(p, &"torch")
		press(p, Skills.Slot.WEAPON, mouse)
		check(_last(got) == "1:%s" % Skills.WHY_NO_WEAPON and p.action_anim == -1, "%s: a torch: refused" % c)
		var weapon: StringName = Combat.class_weapon(c)
		hold(p, weapon)
		var f: NetProtocol.InputFrame = press(p, Skills.Slot.WEAPON, mouse)
		check(f.skill == WEAPON_SKILLS[c] and f.skill_slot == Skills.Slot.WEAPON and f.slot == p.inventory.selected,
			"%s: the class weapon held: %s starts (%s), the frame carries its slot" % [c, WEAPON_SKILLS[c], f.skill])
		check_eq(p.action_anim, Skills.anim(WEAPON_SKILLS[c]), "%s: its body action" % c)
		check_eq(p.action_slot, p.inventory.selected, "%s: the action remembers the weapon's slot" % c)
		ticks(p, 60)
		p.skills.start_cooldown(Skills.Slot.WEAPON, 0)
		hold(p, StringName(String(weapon) + "_t1"))
		check_eq(Skills.refusal(p, Skills.Slot.WEAPON), "", "%s: the tier-1 weapon held: it may start" % c)
		# Gear.broken_unusable (Config.GEAR_BROKEN_UNUSABLE off): a broken weapon is refused like its basic attack.
		p.gear_on = true
		p.inventory.selected_stack().durability = 0
		check_eq(Skills.refusal(p, Skills.Slot.WEAPON), "", "%s: broken, Config.GEAR_BROKEN_UNUSABLE off: it works as the base" % c)
		Gear.broken_unusable = true
		check_eq(Skills.refusal(p, Skills.Slot.WEAPON), Skills.WHY_BROKEN, "%s: broken while broken_unusable: refused" % c)
		p.gear_on = false
		check_eq(Skills.refusal(p, Skills.Slot.WEAPON), "", "%s: without the gear rules (gear_on off) no broken check" % c)
		Gear.broken_unusable = Config.GEAR_BROKEN_UNUSABLE


func _check_tier1_and_wear() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var pal: Player = player(d, "paladin", Vector2(200, 200))
	pal.gear_on = true
	var party: Array[Player] = [pal]
	wire(pal, a, party)
	var east: Vector2 = aim_at(pal, Vector2.RIGHT)
	var base: int = Skills.num_i(Skills.CRUSHING_BLOW, "damage")
	var impact: int = Skills.impact_tick(Skills.CRUSHING_BLOW)
	var results: Array[int] = []
	for weapon: StringName in [&"sword", &"sword_t1"]:
		var h: HereticSim = a.spawn_heretic(Vector2(220, 200))
		var s: int = hold(pal, weapon)
		var dur: int = pal.inventory.stack_at(s).durability
		press(pal, Skills.Slot.WEAPON, east)
		ticks(pal, impact)
		results.append(Config.HERETIC_HP - h.hp)
		if weapon == &"sword_t1":
			check_eq(pal.inventory.stack_at(s).durability, dur - Config.GEAR_WEAR_PER_ATTACK, "a tier-1 sword wears once per use")
			check(_landed.wore, "the result says it wore")
		else:
			check(not _landed.wore and pal.inventory.stack_at(s).durability == dur, "the base sword has no durability")
		h.pos = Vector2(600, 450)
		h.home = h.pos
		ticks(pal, 60)
		pal.skills.start_cooldown(Skills.Slot.WEAPON, 0)
	check_eq(results, [base, base * Config.GEAR_T1_DAMAGE_PCT / 100] as Array[int], "base %d, tier-1 %d%% (like the basic attack)" % [
		base, Config.GEAR_T1_DAMAGE_PCT])
	# A use that hits nothing wears too (like an attack swing).
	var st: ItemStack = pal.inventory.stack_at(slot_of(pal.inventory, &"sword_t1"))
	var before: int = st.durability
	hold(pal, &"sword_t1")
	press(pal, Skills.Slot.WEAPON, aim_at(pal, Vector2.LEFT))
	ticks(pal, impact)
	check(_landed.hits == 0 and st.durability == before - Config.GEAR_WEAR_PER_ATTACK, "a use at nothing wears once")
	ticks(pal, 60)
	pal.skills.start_cooldown(Skills.Slot.WEAPON, 0)
	# Broken (Config.GEAR_BROKEN_UNUSABLE off): it lands at the base damage and wears no further.
	st.durability = 0
	var hb: HereticSim = a.spawn_heretic(Vector2(220, 200))
	press(pal, Skills.Slot.WEAPON, east)
	ticks(pal, impact)
	check(hb.hp == Config.HERETIC_HP - base and st.durability == 0, "broken: the base damage, no wear below 0")
	hb.pos = Vector2(600, 450)
	ticks(pal, 60)
	pal.skills.start_cooldown(Skills.Slot.WEAPON, 0)
	# The weapon leaves its slot before the impact frame: the base damage, nothing worn (like an attack).
	st.durability = 100
	var s2: int = hold(pal, &"sword_t1")
	var hc: HereticSim = a.spawn_heretic(Vector2(220, 200))
	press(pal, Skills.Slot.WEAPON, east)
	pal.inventory.move(s2, 12)
	ticks(pal, impact)
	check(hc.hp == Config.HERETIC_HP - base and st.durability == 100, "the weapon moved away mid-swing: base damage, no wear")
	hc.pos = Vector2(600, 450)
	# gear_on off (a session's rule until M9c): no tier-1 bonus, no wear.
	pal.gear_on = false
	pal.action_slot = slot_of(pal.inventory, &"sword_t1")
	check_eq(Skills.weapon_damage(pal, base), base, "gear_on off: the base damage")
	check(not Skills.wear_weapon(pal), "gear_on off: no wear")
	# Each class's tier-1 weapon gives its skill the 150% (Skills.weapon_damage on the stack in the action's slot).
	for c: String in Config.CLASSES:
		var q: Player = player(d, c, Vector2(100, 100))
		q.gear_on = true
		q.action_slot = hold(q, StringName(String(Combat.class_weapon(c)) + "_t1"))
		var id: StringName = WEAPON_SKILLS[c]
		check_eq(Skills.weapon_damage(q, Skills.num_i(id, "damage")), Skills.num_i(id, "damage") * Config.GEAR_T1_DAMAGE_PCT / 100,
			"%s: %s with the tier-1 weapon" % [c, id])


# --- cooldowns -------------------------------------------------------------------------------------------

func _check_cooldowns() -> void:
	for c: String in Config.CLASSES:
		for slot: int in [Skills.Slot.WEAPON, Skills.Slot.SIGNATURE]:
			var d: WorldData = open_world()
			var a: Arena = arena_for(d)
			var p: Player = player(d, c, Arena.spawn_feet(Vector2i(10, 10)))
			var party: Array[Player] = [p]
			wire(p, a, party)
			hold(p, Combat.class_weapon(c))
			fill(p)
			var id: StringName = Skills.kit_skill(c, slot)
			var mouse: Vector2 = aim_at(p, Vector2.RIGHT, 30.0)
			var before: int = Skills.resource_of(p)
			var f: NetProtocol.InputFrame = press(p, slot, mouse)
			check(f.skill == id and p.action_skill == id, "%s key %s: %s starts" % [c, Skills.SLOT_KEYS[slot], id])
			var impact: int = Skills.impact_tick(id)
			ticks(p, impact - 1)
			check_eq(p.skills.cooldown(slot), 0, "%s: no cooldown before it lands" % id)
			if slot == Skills.Slot.SIGNATURE:
				check(Skills.resource_of(p) >= before, "%s: nothing spent before it lands" % id)
			tick(p)
			check_eq(p.skills.cooldown(slot), Skills.cooldown_ticks(id), "%s: the cooldown starts when it lands" % id)
			if slot == Skills.Slot.SIGNATURE:
				var left: int = 0 if c == "archer" else before - Skills.signature_cost(c)
				check_eq(Skills.resource_of(p), left, "%s: spent when it lands (%d -> %d)" % [id, before, left])
			ticks(p, Skills.cooldown_ticks(id) - 1)
			check_eq(p.skills.cooldown(slot), 1, "%s: one tick left" % id)
			fill(p)
			var got: Array[String] = refusals(p)
			press(p, slot, mouse)
			check(_last(got) == "%d:%s" % [slot, Skills.WHY_COOLDOWN] and p.action_anim == -1, "%s: a tick early: cooling down" % id)
			press(p, slot, mouse)
			check_eq(p.action_skill, id, "%s: ready again exactly its cooldown after it landed" % id)


# --- refusals for keys 2 and R -----------------------------------------------------------------------------

func _check_refusals() -> void:
	var d: WorldData = open_world()
	var feet: Vector2 = Arena.spawn_feet(Vector2i(10, 10))
	var p: Player = player(d, "paladin", feet)
	hold(p, &"sword")
	p.skills.resource = 100
	var got: Array[String] = refusals(p)
	var mouse: Vector2 = aim_at(p, Vector2.RIGHT)
	for slot: int in [Skills.Slot.WEAPON, Skills.Slot.SIGNATURE]:
		p.set_carrying_altar(true)
		press(p, slot, mouse)
		check(_last(got) == "%d:%s" % [slot, Skills.WHY_CARRYING] and p.action_anim == -1, "key %s carrying the altar" % Skills.SLOT_KEYS[slot])
		p.set_carrying_altar(false)
		p.ui_locked = true
		p.begin_tick()
		p.tick_controls(Vector2i.ZERO, mouse, true, false, false, TICK, false, false, false, slot)
		check(_last(got) == "%d:%s" % [slot, Skills.WHY_PANEL] and p.action_anim == -1, "key %s with a panel open" % Skills.SLOT_KEYS[slot])
		p.ui_locked = false
		p.begin_tick()
		p.step_frame(p.make_frame(Vector2i.ZERO, mouse, true, true, true), TICK)
		check_eq(p.action_anim, RigData.Anim.SWORD, "setup: swinging")
		press(p, slot, mouse)
		check(_last(got) == "%d:%s" % [slot, Skills.WHY_BUSY], "key %s mid-swing" % Skills.SLOT_KEYS[slot])
		ticks(p, 60)
		p.skills.start_cooldown(slot, 5)
		press(p, slot, mouse)
		check(_last(got) == "%d:%s" % [slot, Skills.WHY_COOLDOWN], "key %s cooling down" % Skills.SLOT_KEYS[slot])
		ticks(p, 5)
	check(p.skills.resource == 100 and p.skills.cooldowns == PackedInt32Array([0, 0, 0, 0]), "nothing spent by the refusals")
	p.take_hit(Config.PLAYER_HP_MAX)
	for slot2: int in [Skills.Slot.WEAPON, Skills.Slot.SIGNATURE]:
		press(p, slot2, mouse)
		check_eq(_last(got), "%d:%s" % [slot2, Skills.WHY_DOWN], "key %s down" % Skills.SLOT_KEYS[slot2])
	p.vitals.life = Vitals.Life.DEAD
	for slot3: int in [Skills.Slot.WEAPON, Skills.Slot.SIGNATURE]:
		press(p, slot3, mouse)
		check_eq(_last(got), "%d:%s" % [slot3, Skills.WHY_DEAD], "key %s dead" % Skills.SLOT_KEYS[slot3])
	# Not enough resource for R: one short is refused (nothing spent), the cost itself may start.
	for c: String in Config.CLASSES:
		var q: Player = player(d, c, feet)
		var cost: int = Skills.signature_cost(c)
		if c == "herbalist":
			q.inventory.add(Config.HERBALIST_MATERIAL_ITEM, cost - 1)
		else:
			q.skills.resource = cost - 1
		var qgot: Array[String] = refusals(q)
		press(q, Skills.Slot.SIGNATURE, aim_at(q, Vector2.RIGHT, 30.0))
		check(_last(qgot) == "3:%s" % Skills.WHY_RESOURCE and q.action_anim == -1 and Skills.resource_of(q) == cost - 1,
			"%s: R with %d of %d: refused, nothing spent" % [c, cost - 1, cost])
		if c == "herbalist":
			q.inventory.add(Config.HERBALIST_MATERIAL_ITEM, 1)
		else:
			q.skills.resource = cost
		check_eq(Skills.refusal(q, Skills.Slot.SIGNATURE), "", "%s: R with exactly %d may start" % [c, cost])


# --- the crushing blow and the stun --------------------------------------------------------------------------

func _check_crushing_blow() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var pal: Player = player(d, "paladin", Vector2(200, 200))
	var party: Array[Player] = [pal]
	wire(pal, a, party)
	hold(pal, &"sword")
	var dmg: int = Skills.num_i(Skills.CRUSHING_BLOW, "damage")
	var stun: int = Skills.num_i(Skills.CRUSHING_BLOW, "stun_ticks")
	var ahead: HereticSim = a.spawn_heretic(Vector2(220, 200))
	var side: HereticSim = a.spawn_heretic(Vector2(200, 224))
	var far: HereticSim = a.spawn_heretic(Vector2(229, 200))
	press(pal, Skills.Slot.WEAPON, aim_at(pal, Vector2.RIGHT))
	check_eq(pal.action_anim, RigData.Anim.SWORD, "key 2: the sword action")
	ticks(pal, Skills.impact_tick(Skills.CRUSHING_BLOW) - 1)
	check_eq(ahead.hp, Config.HERETIC_HP, "not before its frame")
	tick(pal)
	check_eq(ahead.hp, Config.HERETIC_HP - dmg, "the one ahead takes %d on frame %d" % [dmg, Skills.num_i(Skills.CRUSHING_BLOW, "impact")])
	check(side.hp == Config.HERETIC_HP and far.hp == Config.HERETIC_HP, "outside the 120 degree arc and beyond 28 px: untouched")
	check(ahead.stunned() and ahead.stun_ticks == stun and not side.stunned(), "stunned for %d ticks" % stun)
	check_eq(ahead.threat_of(pal.get_instance_id()), dmg, "threat for the paladin")
	var b: Arena.Burst = burst_of(a, Arena.BurstKind.CRUSH)
	check(b != null and b.aim == 0 and b.arc_deg == 120.0 and b.radius == 28.0, "an arc burst along the aim")
	check_eq(pal.skills.cooldown(Skills.Slot.WEAPON), Skills.cooldown_ticks(Skills.CRUSHING_BLOW), "its cooldown")
	check_eq(_landed.hits, 1, "one hit")
	# The stun holds it still for exactly its ticks, then it goes after the paladin again (he stands in its reach: it attacks).
	var at: Vector2 = ahead.pos
	steps(a, party, stun - 1)
	check(ahead.stunned() and ahead.stun_ticks == 1 and ahead.pos == at and ahead.state != HereticSim.State.ATTACK,
		"still stunned one tick before the end, not moved, no attack")
	check(ahead.anim() == HereticSim.Anim.HURT and ahead.frame() == Config.SKILL_STUN_FRAME, "it shows the hurt pose held")
	a.step(party)
	check(not ahead.stunned() and ahead.pos == at, "the stun ran out")
	var attacked: bool = false
	for t: int in 10:
		a.step(party)
		attacked = attacked or ahead.state == HereticSim.State.ATTACK
	check(attacked, "then it attacks again")
	# The shrine (dungeon): the blow hits it like a sword swing; breaking it gives the edits.
	var dungeon: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var da: Arena = arena_for(dungeon)
	var rect: Rect2i = da.shrine_rect()
	var below: Vector2 = Vector2(FixtureView.foot_of(rect).x, (rect.end.y + 1) * Config.TILE - 4.0)
	var dp: Player = player(dungeon, "paladin", below)
	dp.action_slot = hold(dp, &"sword")
	dp.action_aim = Combat.aim_code(Vector2.UP)
	var dparty: Array[Player] = [dp]
	var r: Skills.Landed = Skills.land(dp, Skills.CRUSHING_BLOW, da, dparty)
	check(da.shrine_hp == Config.SHRINE_HP - dmg and r.edits.is_empty(), "the shrine takes %d (%d left)" % [dmg, da.shrine_hp])
	da.shrine_hp = dmg
	r = Skills.land(dp, Skills.CRUSHING_BLOW, da, dparty)
	check_eq(r.edits.size(), rect.size.x * rect.size.y, "breaking it: the footprint's edits")
	for e: EditLog.WorldEdit in r.edits:
		EditLog.apply_to_data(dungeon, e)
	check_eq(dungeon.footprints(WorldData.PLACEABLE_SHRINE_BROKEN), [rect] as Array[Rect2i], "the shrine broken")


func _check_stun_rules() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var q: Player = player(d, "archer", Vector2(200, 200))
	var party: Array[Player] = [q]
	# A stun during the wind-up cancels the attack: no knife, the attack cooldown follows.
	var h: HereticSim = a.spawn_heretic(Vector2(215, 200))
	h.has_target = true
	h.target_id = q.get_instance_id()
	h.state = HereticSim.State.ATTACK
	h.state_ticks = 10
	h.attack_dir = Vector2.LEFT
	check(a.stun_heretic(h, 60), "stunned mid-wind-up")
	check(h.state == HereticSim.State.CHASE and h.cooldown == Config.HERETIC_ATTACK_COOLDOWN_TICKS, "its attack cancelled, cooldown %d" % h.cooldown)
	check_eq(a.stat("attacks_stunned"), 1, "counted")
	for t: int in 100:
		tick(q)
		a.step(party)
	check(q.vitals.hp == Config.PLAYER_HP_MAX and a.stat("knife_swings") == 0, "no knife for the stun plus the cooldown (%d swings)" % a.stat("knife_swings"))
	# A hit on a stunned heretic adds no stagger; a second stun keeps the longer.
	var h2: HereticSim = a.spawn_heretic(Vector2(400, 400))
	a.stun_heretic(h2, 50)
	a.hit_heretic(h2, 5, q.get_instance_id())
	check(h2.state == HereticSim.State.IDLE and h2.hp == Config.HERETIC_HP - 5 and h2.stun_ticks == 50,
		"hit while stunned: the damage, no stagger, the stun goes on")
	a.stun_heretic(h2, 30)
	check_eq(h2.stun_ticks, 50, "a shorter stun keeps the longer")
	a.stun_heretic(h2, 80)
	check_eq(h2.stun_ticks, 80, "a longer one replaces it")
	# A stun ends a stagger (it stands still the stun's time, not the stagger on top) and nothing for the dead.
	var h3: HereticSim = a.spawn_heretic(Vector2(400, 300))
	a.hit_heretic(h3, 5, 0)
	check_eq(h3.state, HereticSim.State.HURT, "setup: staggered")
	a.stun_heretic(h3, 10)
	check(h3.state == HereticSim.State.IDLE and h3.stunned(), "the stun replaces the stagger")
	a.hit_heretic(h3, Config.HERETIC_HP, 0)
	check(not h3.stunned() and h3.stun_ticks == 0 and not a.stun_heretic(h3, 10), "a death ends it; the dead cannot be stunned")
	# The map emptying ends a stun.
	a.stun_heretic(h2, 80)
	a.on_emptied()
	check(not h2.stunned(), "the map emptying ends the stun")
	# A stun during the light-edge watch: the watch counts on (the M4-fix rule through a stagger).
	var h4: HereticSim = a.spawn_heretic(Vector2(300, 300))
	h4.state = HereticSim.State.EDGE
	h4.watch_ticks = 100
	a.stun_heretic(h4, 60)
	steps(a, party, 60)
	check_eq(h4.watch_ticks, 160, "the light-edge watch counts on while stunned")


# --- the fan shot ----------------------------------------------------------------------------------------------

func _check_fan_shot() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var arc: Player = player(d, "archer", Vector2(100, 200))
	var party: Array[Player] = [arc]
	wire(arc, a, party)
	hold(arc, &"bow")
	var spread: int = Skills.num_i(Skills.FAN_SHOT, "spread_aim")
	var dmg: int = Skills.num_i(Skills.FAN_SHOT, "damage")
	press(arc, Skills.Slot.WEAPON, aim_at(arc, Vector2.RIGHT, 80.0))
	check_eq(arc.action_anim, RigData.Anim.BOW, "key 2: the bow action")
	ticks(arc, Skills.impact_tick(Skills.FAN_SHOT))
	var aims: Array[int] = []
	for s: Arena.Shot in a.shots:
		aims.append(s.aim)
		check(s.damage == dmg and s.kind == Combat.Kind.ARROW and not s.pierce and s.item == Skills.FAN_SHOT,
			"an ordinary arrow of %d" % dmg)
	check_eq(aims, [Combat.AIM_STEPS - spread, 0, spread] as Array[int], "three arrows %d aim codes apart around the aim" % spread)
	check_eq(arc.skills.cooldown(Skills.Slot.WEAPON), Skills.cooldown_ticks(Skills.FAN_SHOT), "its cooldown")
	# Each arrow hits the heretic on its line (and stops there).
	var a2: Arena = arena_for(open_world())
	var arc2: Player = player(a2.data, "archer", Vector2(100, 200))
	var p2: Array[Player] = [arc2]
	var body: Vector2 = Combat.body_point(arc2.sim_position)
	var on_lines: Array[HereticSim] = []
	for off: int in [-spread, 0, spread]:
		on_lines.append(a2.spawn_heretic(body + Combat.aim_vector(off) * 130.0))  # beyond their sight: they stand still
	var behind: HereticSim = a2.spawn_heretic(body + Vector2(150, 0))
	var shots: Array[Arena.Shot] = a2.fan_shot(arc2, Skills.FAN_SHOT, 0, dmg, 3, spread, 160.0, 220.0)
	check_eq(shots.size(), 3, "three shots")
	steps(a2, p2, 50)
	var hps: Array[int] = []
	for h: HereticSim in on_lines:
		hps.append(h.hp)
	check_eq(hps, [40 - dmg, 40 - dmg, 40 - dmg] as Array[int], "each arrow hits its own heretic once")
	check(behind.hp == Config.HERETIC_HP and a2.stat("shot_heretic") == 3, "the middle arrow stopped at the first one")


# --- reach_point (the point skills) ------------------------------------------------------------------------

func _check_reach_point() -> void:
	var d: WorldData = open_world()
	var feet: Vector2 = Vector2(100, 100)
	check_eq(Skills.reach_point(d, feet, Vector2(150.4, 120.6), 112.0), Vector2(150, 121), "within range: the cursor, whole px")
	check_eq(Skills.reach_point(d, feet, Vector2(400, 100), 112.0), Vector2(212, 100), "beyond: pulled in to the range")
	check_eq(Skills.reach_point(null, feet, Vector2(100, 400), 50.0), Vector2(100, 150), "no world: the range only")
	check_eq(Skills.reach_point(d, feet, feet, 112.0), feet, "on the feet: the feet")
	# A wall between: the farthest point before it.
	var wall: Vector2i = Vector2i(9, 6)
	d.set_value(WorldData.Layer.WALL, wall, Walls.pack(Walls.KIND_ROCK, 0))
	var q: Vector2 = Skills.reach_point(d, feet, Vector2(180, 100), 112.0)
	check(Combat.line_clear(d, feet, q) and q.x < float(wall.x * Config.TILE) and q.x >= float(wall.x * Config.TILE) - 2.0
		and q.y == 100.0, "behind a wall: the last point before it (%s)" % q)
	check(not Combat.line_clear(d, feet, q + Vector2(1, 0)), "one px further is blocked")


# --- the holy burst ----------------------------------------------------------------------------------------------

func _check_holy_burst() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var cle: Player = player(d, "cleric", Vector2(100, 100))
	var party: Array[Player] = [cle]
	wire(cle, a, party)
	hold(cle, &"holy_light")
	var point: Vector2 = Vector2(160, 100)
	var radius: float = Skills.num_f(Skills.HOLY_BURST, "radius_px")
	var dmg: int = Skills.num_i(Skills.HOLY_BURST, "damage")
	var near: HereticSim = a.spawn_heretic(point + Vector2(10, 0))
	var edge: HereticSim = a.spawn_heretic(point + Vector2(0, -radius))
	var out: HereticSim = a.spawn_heretic(point + Vector2(radius + 2.0, 0))
	d.set_value(WorldData.Layer.WALL, Aim.cell_of(point + Vector2(0, 12)), Walls.pack(Walls.KIND_ROCK, 0))
	var walled: HereticSim = a.spawn_heretic(point + Vector2(0, radius))
	var f: NetProtocol.InputFrame = press(cle, Skills.Slot.WEAPON, point)
	check(f.skill == Skills.HOLY_BURST and f.throw_to == point, "key 2: the holy burst aimed at the cursor point")
	check_eq(cle.action_target, point, "the action keeps the point")
	ticks(cle, Skills.impact_tick(Skills.HOLY_BURST) - 1)
	check_eq(near.hp, Config.HERETIC_HP, "not before its frame")
	tick(cle)
	check(near.hp == 40 - dmg and edge.hp == 40 - dmg, "in the %.0f px circle: %d each" % [radius, dmg])
	check(out.hp == 40 and walled.hp == 40, "beyond the circle and behind a wall from the point: untouched")
	check_eq(near.threat_of(cle.get_instance_id()), dmg, "threat for the cleric")
	var b: Arena.Burst = burst_of(a, Arena.BurstKind.HOLY)
	check(b != null and b.pos == point and b.radius == radius, "a holy burst ring on the point")
	check_eq(cle.skills.cooldown(Skills.Slot.WEAPON), Skills.cooldown_ticks(Skills.HOLY_BURST), "its cooldown")
	# The cursor far away: the burst lands at its range.
	ticks(cle, 40)
	cle.skills.start_cooldown(Skills.Slot.WEAPON, 0)
	var f2: NetProtocol.InputFrame = press(cle, Skills.Slot.WEAPON, Vector2(100, 400))
	check_eq(f2.throw_to, Vector2(100, 100 + Skills.num_f(Skills.HOLY_BURST, "range_px")), "pulled in to its range")


# --- the heavy strike ----------------------------------------------------------------------------------------

func _check_heavy_strike() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var m: Player = player(d, "miner", Vector2(200, 200))
	var party: Array[Player] = [m]
	wire(m, a, party)
	hold(m, &"pickaxe")
	var dmg: int = Skills.num_i(Skills.HEAVY_STRIKE, "damage")
	var ahead: HereticSim = a.spawn_heretic(Vector2(220, 200))
	var off_arc: HereticSim = a.spawn_heretic(Vector2(200, 220))
	var far: HereticSim = a.spawn_heretic(Vector2(226, 200))
	press(m, Skills.Slot.WEAPON, aim_at(m, Vector2.RIGHT))
	check_eq(m.action_anim, RigData.Anim.PICKAXE, "key 2: the pickaxe action")
	ticks(m, Skills.impact_tick(Skills.HEAVY_STRIKE))
	check_eq(ahead.hp, Config.HERETIC_HP - dmg, "the one ahead takes %d" % dmg)
	check(off_arc.hp == 40 and far.hp == 40, "outside the 90 degree arc and beyond 24 px: untouched")
	check(not ahead.stunned() and not ahead.slowed() and ahead.state == HereticSim.State.HURT, "a plain hit (the M4 stagger)")
	check(burst_of(a, Arena.BurstKind.HEAVY) != null, "a copper arc")
	# Aimed at a wall: combat only, it mines nothing (the world is untouched).
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var m2: Player = player(d2, "miner", Arena.spawn_feet(Vector2i(10, 10)))
	var p2: Array[Player] = [m2]
	wire(m2, a2, p2)
	hold(m2, &"pickaxe")
	var wall: Vector2i = Vector2i(11, 10)
	d2.set_value(WorldData.Layer.WALL, wall, Walls.pack(Walls.KIND_ROCK, 0))
	var hits: int = Walls.hits_at(d2, wall)
	var hash_before: String = d2.content_hash()
	press(m2, Skills.Slot.WEAPON, Vector2(wall * Config.TILE) + Vector2(8, 8))
	ticks(m2, Skills.impact_tick(Skills.HEAVY_STRIKE))
	check(Walls.is_wall(d2, wall) and Walls.hits_at(d2, wall) == hits and d2.content_hash() == hash_before,
		"aimed at a wall: nothing mined, the world untouched")
	check(m2.skills.cooldown(Skills.Slot.WEAPON) > 0 and m2.skills.resource == 0, "it landed (cooldown), no endurance from it")


# --- the sweep and the slow ------------------------------------------------------------------------------------

func _check_sweep() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var herb: Player = player(d, "herbalist", Vector2(200, 200))
	var party: Array[Player] = [herb]
	wire(herb, a, party)
	hold(herb, &"sickle")
	var dmg: int = Skills.num_i(Skills.SWEEP, "damage")
	var pct: int = Skills.num_i(Skills.SWEEP, "slow_pct")
	var slow: int = Skills.num_i(Skills.SWEEP, "slow_ticks")
	var east: HereticSim = a.spawn_heretic(Vector2(220, 200))
	var north: HereticSim = a.spawn_heretic(Vector2(200, 176))
	var west: HereticSim = a.spawn_heretic(Vector2(176, 200))
	var far: HereticSim = a.spawn_heretic(Vector2(232, 200))
	press(herb, Skills.Slot.WEAPON, aim_at(herb, Vector2.RIGHT))
	check_eq(herb.action_anim, RigData.Anim.SICKLE, "key 2: the sickle action")
	ticks(herb, Skills.impact_tick(Skills.SWEEP))
	check(east.hp == 40 - dmg and north.hp == 40 - dmg, "a 240 degree arc: ahead and to the side take %d" % dmg)
	check(west.hp == 40 and far.hp == 40 and not west.slowed() and not far.slowed(), "behind and beyond 26 px: untouched")
	check(east.slowed() and east.slow_pct == pct and east.slow_ticks == slow and north.slowed(), "slowed %d%% for %d ticks" % [pct, slow])
	check(burst_of(a, Arena.BurstKind.SWEEP) != null and burst_of(a, Arena.BurstKind.SWEEP).arc_deg == 240.0, "a wide arc")
	check(Skills.is_skill(Skills.SWEEP), "the sweep is a skill (Main lands it as one: it never harvests)")


func _check_slow_rules() -> void:
	var pct: int = Skills.num_i(Skills.SWEEP, "slow_pct")
	var slow: int = Skills.num_i(Skills.SWEEP, "slow_ticks")
	# Speed: a slowed heretic chasing walks (100 - slow)% as far.
	var dist: Array[float] = []
	for slowed: bool in [false, true]:
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var target: Player = player(d, "paladin", Vector2(300, 200))
		var players: Array[Player] = [target]
		var h: HereticSim = a.spawn_heretic(Vector2(210, 200))
		if slowed:
			a.slow_heretic(h, pct, slow)
		var start: float = h.pos.x
		steps(a, players, 30)
		dist.append(h.pos.x - start)
	check_between(dist[0], 30.0 * Config.HERETIC_SPEED / 60.0 - 0.6, 30.0 * Config.HERETIC_SPEED / 60.0 + 0.1, "unslowed: %.1f px in 30 ticks" % dist[0])
	check_between(dist[1] / dist[0], (100 - pct) / 100.0 - 0.03, (100 - pct) / 100.0 + 0.03, "slowed: %.0f%% of that (%.1f px)" % [100.0 * dist[1] / dist[0], dist[1]])
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var nobody: Array[Player] = []
	var h2: HereticSim = a2.spawn_heretic(Vector2(300, 300))
	a2.slow_heretic(h2, pct, slow)
	check_eq(Arena.heretic_speed(h2), Config.HERETIC_SPEED * (100 - pct) / 100.0, "heretic_speed while slowed")
	# Expiry: exactly its ticks.
	steps(a2, nobody, slow - 1)
	check(h2.slowed() and h2.slow_ticks == 1, "still slowed one tick before the end")
	a2.step(nobody)
	check(not h2.slowed() and h2.slow_pct == 0 and Arena.heretic_speed(h2) == Config.HERETIC_SPEED, "the slow ran out")
	# Stacking (Config.EFFECT_REFRESH_KEEPS_STRONGER): the stronger percent and the longer time.
	a2.slow_heretic(h2, 20, 300)
	a2.slow_heretic(h2, 40, 100)
	check(h2.slow_pct == 40 and h2.slow_ticks == 300, "a stronger, shorter slow: 40%%, the longer time (%d%% %d)" % [h2.slow_pct, h2.slow_ticks])
	a2.slow_heretic(h2, 10, 600)
	check(h2.slow_pct == 40 and h2.slow_ticks == 600, "a weaker, longer one: still 40%%, 600 ticks")
	check(not a2.slow_heretic(h2, 0, 100) and not a2.slow_heretic(h2, 20, 0), "nothing for 0")
	# With poison: both run.
	var h3: HereticSim = a2.spawn_heretic(Vector2(100, 100))
	a2.poison_heretic(h3, 3, 120, 0)
	a2.slow_heretic(h3, pct, slow)
	steps(a2, nobody, Config.POISON_INTERVAL_TICKS)
	check(h3.hp == Config.HERETIC_HP - 3 and h3.slowed() and h3.poisoned(), "slowed and poisoned at once: both run")
	# A death or the map emptying ends it.
	a2.hit_heretic(h3, Config.HERETIC_HP, 0)
	check(not h3.slowed() and h3.slow_ticks == 0 and not a2.slow_heretic(h3, pct, slow), "a death ends it")
	a2.on_emptied()
	check(not h2.slowed(), "the map emptying ends it")
	# Only heretics: a buffed ally in the sweep keeps its buff, its speed and its HP (no friendly fire, the buff is a player's).
	var d4: WorldData = open_world()
	var a4: Arena = arena_for(d4)
	var herb: Player = player(d4, "herbalist", Vector2(200, 200))
	var ally: Player = player(d4, "paladin", Vector2(220, 202))
	var party: Array[Player] = [herb, ally]
	wire(herb, a4, party)
	hold(herb, &"sickle")
	ally.apply_potion(&"potion_buff", ItemDB.Grade.COMMON)
	var speed: float = ally.to_sim().walk_speed()
	var buff: int = ally.vitals.buff_ticks
	press(herb, Skills.Slot.WEAPON, aim_at(herb, Vector2.RIGHT))
	ticks(herb, Skills.impact_tick(Skills.SWEEP))
	check(ally.vitals.hp == Config.PLAYER_HP_MAX and ally.vitals.buffed() and ally.vitals.buff_ticks == buff
		and ally.to_sim().walk_speed() == speed and speed > Config.WALK_SPEED, "a buffed ally in the arc: unhurt, buff and speed kept")


# --- the guardian oath ---------------------------------------------------------------------------------------

func _check_oath() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var pal: Player = player(d, "paladin", Vector2(200, 200))
	var near: Player = player(d, "archer", Vector2(240, 200))
	var far: Player = player(d, "cleric", Vector2(300, 200))
	var down: Player = player(d, "miner", Vector2(210, 220))
	down.take_hit(Config.PLAYER_HP_MAX)
	var party: Array[Player] = [pal, near, far, down]
	wire(pal, a, party)
	var pct: int = Skills.num_i(Skills.GUARDIAN_OATH, "ward_pct")
	var ward: int = Skills.num_i(Skills.GUARDIAN_OATH, "ward_ticks")
	pal.skills.resource = 60
	var f: NetProtocol.InputFrame = press(pal, Skills.Slot.SIGNATURE, aim_at(pal, Vector2.RIGHT))
	check(f.skill == Skills.GUARDIAN_OATH and pal.action_anim == Skills.anim(Skills.GUARDIAN_OATH), "key R: the oath")
	ticks(pal, Skills.impact_tick(Skills.GUARDIAN_OATH) - 1)
	check(pal.skills.resource == 60 and not near.skills.warded(), "nothing before its frame")
	tick(pal)
	check_eq(pal.skills.resource, 60 - Skills.signature_cost("paladin"), "spent %d conviction" % Skills.signature_cost("paladin"))
	check(pal.skills.warded() and near.skills.warded() and near.skills.ward_pct == pct and near.skills.ward_ticks == ward,
		"he and the ally within 64 px: warded %d%% for %d ticks" % [pct, ward])
	check(not far.skills.warded() and not down.skills.warded(), "beyond the radius and down: not")
	check_eq(_landed.warded, 2, "two warded")
	var b: Arena.Burst = burst_of(a, Arena.BurstKind.OATH)
	check(b != null and b.radius == Skills.num_f(Skills.GUARDIAN_OATH, "radius_px") and b.follow_id == pal.get_instance_id(),
		"an ivory ring around him")
	check_eq(pal.skills.cooldown(Skills.Slot.SIGNATURE), Skills.cooldown_ticks(Skills.GUARDIAN_OATH), "its cooldown")
	tick(near)
	check(near.effect_marks.shown.has(EffectMarks.Kind.WARD), "the ward's mark over the ally")
	# How much: a knife hit of 12 takes 6.
	near.take_hit(Config.HERETIC_DAMAGE, true)
	check_eq(near.vitals.hp, Config.PLAYER_HP_MAX - Config.HERETIC_DAMAGE * (100 - pct) / 100, "a warded knife hit: %d%% off" % pct)
	# With armour: after the armour (12 - 4 = 8), then the ward (4).
	var armoured: Player = player(d, "paladin", Vector2(100, 100))
	armoured.gear_on = true
	armoured.inventory.wear(ItemStack.new(&"armor_t1", 1, 0, Config.GEAR_DURABILITY[&"armor_t1"]))
	armoured.skills.add_ward(pct, ward)
	armoured.take_hit(Config.HERETIC_DAMAGE, true)
	check_eq(armoured.vitals.hp, Config.PLAYER_HP_MAX - (Config.HERETIC_DAMAGE - Config.ARMOR_T1_DEFENCE) * (100 - pct) / 100,
		"after the armour, then the ward")
	check_eq(Skills.after_ward(1, armoured.skills), Config.SKILL_WARD_MIN_DAMAGE, "never below the minimum (1 -> 1)")
	check_eq(Skills.after_ward(3, armoured.skills), 1, "3 -> 1 (rounded down)")
	check_eq(Skills.after_ward(0, armoured.skills), 0, "nothing stays nothing")
	check_eq(Skills.after_ward(12, SkillState.new()), 12, "no ward: unchanged")
	# Its time: exactly ward_ticks on the ally's own clock; then full damage.
	var left: int = near.skills.ward_ticks
	ticks(near, left - 1)
	check(near.skills.warded() and near.skills.ward_ticks == 1, "still warded one tick before the end")
	tick(near)
	check(not near.skills.warded() and not near.effect_marks.shown.has(EffectMarks.Kind.WARD), "the ward ran out, its mark gone")
	var hp: int = near.vitals.hp
	near.take_hit(Config.HERETIC_DAMAGE, true)
	check_eq(near.vitals.hp, hp - Config.HERETIC_DAMAGE, "then a full hit")
	# Poison ticks are not hits (not warded); a death ends the ward; a second ward keeps the stronger and longer.
	var pz: Player = player(d, "archer", Vector2(100, 150))
	pz.skills.add_ward(pct, ward)
	pz.apply_potion(&"potion_poison", ItemDB.Grade.COMMON)
	ticks(pz, Config.POISON_INTERVAL_TICKS)
	check_eq(pz.vitals.hp, Config.PLAYER_HP_MAX - Config.POISON_DAMAGE[ItemDB.Grade.COMMON], "a poison tick: full (not a hit)")
	pz.skills.on_death()
	check(not pz.skills.warded(), "a death ends the ward")
	var s: SkillState = SkillState.new()
	s.add_ward(50, 250)
	s.add_ward(30, 100)
	check(s.ward_pct == 50 and s.ward_ticks == 250, "a weaker, shorter ward: kept")
	s.add_ward(60, 400)
	check(s.ward_pct == 60 and s.ward_ticks == 400, "a stronger, longer one: taken")
	check(not s.add_ward(0, 10) and not s.add_ward(10, 0), "nothing for 0")
	# A fizzle: the conviction fell below the cost between the press and the frame: nothing spent, no ward, no cooldown.
	var d2: WorldData = open_world()
	var a2: Arena = arena_for(d2)
	var p2: Player = player(d2, "paladin", Vector2(200, 200))
	var party2: Array[Player] = [p2]
	wire(p2, a2, party2)
	p2.skills.resource = Skills.signature_cost("paladin")
	press(p2, Skills.Slot.SIGNATURE, aim_at(p2, Vector2.RIGHT))
	p2.skills.resource -= 1
	ticks(p2, Skills.impact_tick(Skills.GUARDIAN_OATH))
	check(_landed.why == Skills.WHY_RESOURCE and not p2.skills.warded() and p2.skills.resource == Skills.signature_cost("paladin") - 1
		and p2.skills.cooldown(Skills.Slot.SIGNATURE) == 0, "too little at its frame: it fizzles, nothing spent, no cooldown")


# --- the arrow rain --------------------------------------------------------------------------------------------

func _check_arrow_rain() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var arc: Player = player(d, "archer", Vector2(100, 200))
	var party: Array[Player] = [arc]
	wire(arc, a, party)
	var radius: float = Skills.num_f(Skills.ARROW_RAIN, "radius_px")
	var delay: int = Skills.num_i(Skills.ARROW_RAIN, "delay_ticks")
	# 150 px away (out of the heretics' sight: they stand still) and within its range.
	var point: Vector2 = Vector2(250, 200)
	var inside: HereticSim = a.spawn_heretic(point + Vector2(0, 5))
	var edge: HereticSim = a.spawn_heretic(point + Vector2(radius, 0))
	var out: HereticSim = a.spawn_heretic(point + Vector2(0, -radius - 3.0))
	arc.skills.resource = 80
	var f: NetProtocol.InputFrame = press(arc, Skills.Slot.SIGNATURE, point)
	check(f.skill == Skills.ARROW_RAIN and f.throw_to == point and arc.action_anim == RigData.Anim.BOW, "key R: the arrow rain on the point")
	ticks(arc, Skills.impact_tick(Skills.ARROW_RAIN))
	check_eq(arc.skills.resource, 0, "all of the focus spent")
	check(_landed.spent >= 80, "spent %d (all he had, at least what he pressed with)" % _landed.spent)
	var want: int = Skills.num_i(Skills.ARROW_RAIN, "damage") + _landed.spent * Skills.num_i(Skills.ARROW_RAIN, "damage_per_focus_pct") / 100
	var s: Arena.Strike = _landed.strike
	check(s != null and a.strikes.size() == 1 and s.kind == Arena.StrikeKind.ARROWS and s.pos == point and s.radius == radius
		and s.delay == delay and s.damage == want and s.owner_id == arc.get_instance_id(), "a strike of %d on the point, %d ticks away" % [want, delay])
	check_eq(arc.skills.cooldown(Skills.Slot.SIGNATURE), Skills.cooldown_ticks(Skills.ARROW_RAIN), "its cooldown")
	steps(a, party, delay - 1)
	check(inside.hp == 40 and a.strikes.size() == 1 and s.left() == 1, "nothing before its delay (1 tick left)")
	a.step(party)
	check(inside.hp == 40 - want and edge.hp == 40 - want, "after exactly %d ticks: %d in the circle" % [delay, want])
	check(out.hp == 40 and a.strikes.is_empty() and s.landed and s.hits == 2, "beyond the circle untouched; landed (2 hits)")
	check(burst_of(a, Arena.BurstKind.RAIN) != null and not inside.stunned(), "the rain's ring where it landed; no stun")
	check_eq(inside.threat_of(arc.get_instance_id()), want, "threat for the archer")
	# Damage from the focus spent: the least (30) and the most (100).
	for focus: int in [Skills.signature_cost("archer"), Skills.resource_cap("archer")]:
		var q: Player = player(d, "archer", Vector2(100, 100))
		q.skills.resource = focus
		q.action_target = Vector2(150, 100)
		var qp: Array[Player] = [q]
		var r: Skills.Landed = Skills.land(q, Skills.ARROW_RAIN, a, qp)
		check(r.spent == focus and r.damage == Skills.num_i(Skills.ARROW_RAIN, "damage") + focus * Skills.num_i(Skills.ARROW_RAIN, "damage_per_focus_pct") / 100,
			"focus %d: damage %d" % [focus, r.damage])
	# A wall between the strike's point and a heretic in its circle: untouched.
	var d3: WorldData = open_world()
	var a3: Arena = arena_for(d3)
	d3.set_value(WorldData.Layer.WALL, Aim.cell_of(point + Vector2(0, 16)), Walls.pack(Walls.KIND_ROCK, 0))
	var walled: HereticSim = a3.spawn_heretic(point + Vector2(0, 28))
	a3.add_strike(Arena.StrikeKind.ARROWS, point, radius, 1, 10, 0, 0)
	var none: Array[Player] = []
	a3.step(none)
	check_eq(walled.hp, Config.HERETIC_HP, "behind a wall from the point: untouched")


# --- the blessing -----------------------------------------------------------------------------------------------

func _check_blessing() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var cle: Player = player(d, "cleric", Vector2(200, 200))
	var near: Player = player(d, "paladin", Vector2(240, 200))
	var far: Player = player(d, "archer", Vector2(300, 200))
	var down: Player = player(d, "miner", Vector2(210, 215))
	down.take_hit(Config.PLAYER_HP_MAX)
	near.vitals.hp = 50
	far.vitals.hp = 50
	cle.vitals.hp = 90
	var party: Array[Player] = [cle, near, far, down]
	wire(cle, a, party)
	var interval: int = Skills.num_i(Skills.BLESSING, "interval_ticks")
	var heal: int = Skills.num_i(Skills.BLESSING, "heal_hp")
	var duration: int = Skills.num_i(Skills.BLESSING, "duration_ticks")
	cle.skills.resource = Skills.signature_cost("cleric")
	press(cle, Skills.Slot.SIGNATURE, aim_at(cle, Vector2.RIGHT))
	ticks(cle, Skills.impact_tick(Skills.BLESSING))
	check_eq(cle.skills.resource, 0, "spent its faith")
	var z: Arena.Zone = _landed.zone
	check(z != null and a.zones.size() == 1 and z.kind == Arena.ZoneKind.BLESSING and z.follow_id == cle.get_instance_id()
		and z.radius == Skills.num_f(Skills.BLESSING, "radius_px") and z.duration == duration, "a ring following the cleric")
	# A heretic engaged with the ally near the cleric (held still): the heals are a little threat for the cleric.
	var foe: HereticSim = a.spawn_heretic(Vector2(400, 400))
	a.stun_heretic(foe, 10000)
	foe.has_target = true
	foe.target_id = near.get_instance_id()
	foe.hp = 20
	steps(a, party, interval - 1)
	check(near.vitals.hp == 50 and z.pulses == 0, "nothing before the first interval")
	a.step(party)
	check(near.vitals.hp == 50 + heal and cle.vitals.hp == 90 + heal, "a pulse heals %d to everyone up inside (the cleric too)" % heal)
	check(far.vitals.hp == 50 and down.vitals.life == Vitals.Life.DOWN and down.vitals.hp == 0, "not beyond the ring, not the downed")
	check_eq(foe.threat_of(cle.get_instance_id()), 2 * maxi(heal * Config.THREAT_HEAL_PCT / 100, 1),
		"a little threat per healed player near its target (the ally and the cleric: the M9a heal rule)")
	check_eq(foe.hp, 20, "heretics are never healed")
	steps(a, party, duration - interval)
	check_eq(near.vitals.hp, 50 + heal * duration / interval, "%d pulses x %d = %d" % [duration / interval, heal, heal * duration / interval])
	check_eq(cle.vitals.hp, Config.PLAYER_HP_MAX, "never past the maximum (the cleric: 90 -> 100)")
	check(a.zones.is_empty() and z.pulses == duration / interval, "it ended after %d ticks" % duration)
	check_eq(cle.skills.resource, 0, "its heals grow no faith")
	# It follows the cleric; it ends when he goes down.
	var z2: Arena.Zone = a.add_zone(Arena.ZoneKind.BLESSING, cle.sim_position, 64.0, 300, 30, 5, cle.get_instance_id(), cle.get_instance_id())
	cle.teleport(Vector2(400, 300))
	far.teleport(Vector2(420, 300))
	near.vitals.hp = 50
	steps(a, party, 30)
	check(z2.pos == cle.sim_position and far.vitals.hp == 55 and near.vitals.hp == 50, "it moved with him: the one beside him now is healed")
	cle.take_hit(Config.PLAYER_HP_MAX)
	a.step(party)
	check(a.zones.is_empty() and a.stat("zones_broken") == 1, "he went down: it ended")


# --- the rockfall ----------------------------------------------------------------------------------------------

func _check_rockfall() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var m: Player = player(d, "miner", Vector2(100, 200))
	var party: Array[Player] = [m]
	wire(m, a, party)
	var radius: float = Skills.num_f(Skills.ROCKFALL, "radius_px")
	var delay: int = Skills.num_i(Skills.ROCKFALL, "delay_ticks")
	var dmg: int = Skills.num_i(Skills.ROCKFALL, "damage")
	var stun: int = Skills.num_i(Skills.ROCKFALL, "stun_ticks")
	var point: Vector2 = Vector2(220, 200)
	var inside: HereticSim = a.spawn_heretic(point)
	var edge: HereticSim = a.spawn_heretic(point + Vector2(radius, 0))
	var out: HereticSim = a.spawn_heretic(point + Vector2(0, radius + 2.0))
	var hash_before: String = d.content_hash()
	m.skills.resource = Skills.signature_cost("miner")
	var f: NetProtocol.InputFrame = press(m, Skills.Slot.SIGNATURE, point)
	check(f.skill == Skills.ROCKFALL and f.throw_to == point and m.action_anim == RigData.Anim.PICKAXE, "key R: the rockfall on the point")
	ticks(m, Skills.impact_tick(Skills.ROCKFALL))
	check_eq(m.skills.resource, 0, "spent its endurance")
	var s: Arena.Strike = _landed.strike
	check(s != null and s.kind == Arena.StrikeKind.ROCKS and s.delay == delay and s.damage == dmg and s.stun_ticks == stun,
		"rocks: %d, a %d tick stun, %d ticks of warning" % [dmg, stun, delay])
	steps(a, party, delay - 1)
	check_eq(inside.hp, Config.HERETIC_HP, "nothing during the warning")
	a.step(party)
	check(inside.hp == 40 - dmg and edge.hp == 40 - dmg and out.hp == 40, "then %d in the circle, nothing beyond" % dmg)
	check(inside.stunned() and inside.stun_ticks == stun and edge.stunned() and not out.stunned(), "and stunned %d ticks" % stun)
	check(burst_of(a, Arena.BurstKind.ROCKS) != null, "the rocks' ring where they fell")
	check_eq(d.content_hash(), hash_before, "no world edit (no rubble, no wall)")
	check_eq(inside.threat_of(m.get_instance_id()), dmg, "threat for the miner")
	# A kill does not stun the corpse.
	var weak: HereticSim = a.spawn_heretic(point)
	weak.hp = 5
	a.add_strike(Arena.StrikeKind.ROCKS, point, radius, 1, dmg, stun, m.get_instance_id())
	a.step(party)
	check(not weak.alive() and not weak.stunned(), "killed: no stun")


# --- the healing mist ---------------------------------------------------------------------------------------------

func _check_healing_mist() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var herb: Player = player(d, "herbalist", Vector2(100, 100))
	var ally: Player = player(d, "paladin", Vector2(190, 100))
	ally.vitals.hp = 50
	var party: Array[Player] = [herb, ally]
	wire(herb, a, party)
	# Healing herbs in four stacks, two grades, among other items.
	var stacks: Array[ItemStack] = []
	stacks.resize(Config.INVENTORY_SLOTS)
	stacks[0] = ItemStack.new(&"wild_healing", 2, ItemDB.Grade.COMMON)
	stacks[3] = ItemStack.new(&"wild_healing", 1, ItemDB.Grade.FINE)
	stacks[5] = ItemStack.new(&"wild_buff", 4, ItemDB.Grade.COMMON)
	stacks[10] = ItemStack.new(&"wild_healing", 1, ItemDB.Grade.COMMON)
	stacks[12] = ItemStack.new(&"potion_healing", 1, ItemDB.Grade.COMMON)
	herb.inventory.load_state(stacks, 0)
	check_eq(Skills.resource_of(herb), 4, "four healing herbs, any grade")
	var point: Vector2 = Vector2(180, 100)
	var f: NetProtocol.InputFrame = press(herb, Skills.Slot.SIGNATURE, point)
	check(f.skill == Skills.HEALING_MIST and f.throw_to == point and herb.action_anim == RigData.Anim.THROW, "key R: the mist on the point")
	ticks(herb, Skills.impact_tick(Skills.HEALING_MIST) - 1)
	check_eq(Skills.resource_of(herb), 4, "nothing spent before it leaves the hand")
	tick(herb)
	check_eq(_landed.spent, Skills.signature_cost("herbalist"), "spent %d herbs" % Skills.signature_cost("herbalist"))
	check(herb.inventory.stack_at(10) == null and herb.inventory.stack_at(3) == null, "the last stacks first: slot 11 (1) and 4 (the fine one)")
	check(herb.inventory.stack_at(0) != null and herb.inventory.stack_at(0).count == 1, "then 1 of the 2 in slot 1 (a partial stack)")
	check(herb.inventory.count_of(&"wild_buff") == 4 and herb.inventory.count_of(&"potion_healing") == 1, "nothing else taken")
	check_eq(Skills.resource_of(herb), 1, "one herb left")
	var z: Arena.Zone = _landed.zone
	var interval: int = Skills.num_i(Skills.HEALING_MIST, "interval_ticks")
	var heal: int = Skills.num_i(Skills.HEALING_MIST, "heal_hp")
	var duration: int = Skills.num_i(Skills.HEALING_MIST, "duration_ticks")
	check(z != null and z.kind == Arena.ZoneKind.MIST and z.pos == point and z.follow_id == 0
		and z.radius == Skills.num_f(Skills.HEALING_MIST, "radius_px"), "a cloud on the point")
	check_eq(herb.skills.cooldown(Skills.Slot.SIGNATURE), Skills.cooldown_ticks(Skills.HEALING_MIST), "its cooldown")
	var foe: HereticSim = a.spawn_heretic(point + Vector2(0, 10))
	a.stun_heretic(foe, 10000)
	foe.hp = 20
	steps(a, party, interval)
	check(ally.vitals.hp == 50 + heal and herb.vitals.hp == Config.PLAYER_HP_MAX, "a pulse: %d to the ally in the cloud (the herbalist is outside it)" % heal)
	steps(a, party, duration - interval)
	check(ally.vitals.hp == 50 + heal * duration / interval and a.zones.is_empty(), "%d pulses, then it is gone" % (duration / interval))
	check_eq(foe.hp, 20, "heretics in it are never healed")
	# Two herbs: refused, nothing taken. A herb dropped between the press and the frame: it fizzles, nothing spent.
	ticks(herb, 30)
	herb.skills.start_cooldown(Skills.Slot.SIGNATURE, 0)
	herb.inventory.add(&"wild_healing", 1, ItemDB.Grade.COMMON)
	var got: Array[String] = refusals(herb)
	press(herb, Skills.Slot.SIGNATURE, point)
	check(_last(got) == "3:%s" % Skills.WHY_RESOURCE and Skills.resource_of(herb) == 2, "two herbs: refused, both kept")
	herb.inventory.add(&"wild_healing", 1, ItemDB.Grade.FINE)
	press(herb, Skills.Slot.SIGNATURE, point)
	check_eq(herb.action_skill, Skills.HEALING_MIST, "three: it starts")
	herb.inventory.remove(slot_of(herb.inventory, &"wild_healing"), 1)
	ticks(herb, Skills.impact_tick(Skills.HEALING_MIST))
	check(_landed.why == Skills.WHY_RESOURCE and Skills.resource_of(herb) == 2 and a.zones.is_empty()
		and herb.skills.cooldown(Skills.Slot.SIGNATURE) == 0, "a herb gone before it leaves the hand: it fizzles, nothing spent")
	# The cursor beyond the throw's range: the cloud at its range.
	var f2: NetProtocol.InputFrame = press(herb, Skills.Slot.SIGNATURE, Vector2(100, 400))
	check(f2.skill.is_empty() or f2.throw_to == Vector2(100, 100 + Config.THROW_RANGE_PX), "pulled in to the throw's range")
	check_eq(Skills.reach_point(d, herb.sim_position, Vector2(100, 400), Skills.num_f(Skills.HEALING_MIST, "range_px")),
		Vector2(100, 100 + Config.THROW_RANGE_PX), "the mist's point at the throw's range")


# --- the light rules -----------------------------------------------------------------------------------------------

func _check_light() -> void:
	var sd: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var sa: Arena = arena_for(sd)
	var c: Vector2 = sd.altar_center_px()
	var rad: float = Config.safe_radius_px()
	# A miner inside the light drops rocks on a heretic just outside it: hit and stunned where it stands, never in the light.
	var m: Player = player(sd, "miner", c + Vector2(0, rad - 24.0))
	var party: Array[Player] = [m]
	var h: HereticSim = sa.spawn_heretic(c + Vector2(0, rad + 10.0))
	check(Combat.box_outside_light(sd, sa.safe, h.pos), "setup: the heretic outside the light")
	m.skills.resource = Skills.signature_cost("miner")
	m.action_target = h.pos
	var r: Skills.Landed = Skills.land(m, Skills.ROCKFALL, sa, party)
	check(r.ok() and r.strike != null, "the rockfall cast from inside the light")
	var inside_light: int = 0
	for t: int in Skills.num_i(Skills.ROCKFALL, "delay_ticks") + 120:
		sa.step(party)
		if not Combat.box_outside_light(sd, sa.safe, h.pos):
			inside_light += 1
	check(h.hp == Config.HERETIC_HP - Skills.num_i(Skills.ROCKFALL, "damage") and inside_light == 0,
		"it took the rocks and never set foot in the light (%d)" % inside_light)
	check(m.vitals.hp == Config.PLAYER_HP_MAX, "and never hurt the miner in the light")
	# A slowed heretic chasing a player who steps into the light stops at its edge all the same.
	var sa2: Arena = arena_for(sd)
	var q: Player = player(sd, "archer", c + Vector2(0, rad - 8.0))
	var qs: Array[Player] = [q]
	var h2: HereticSim = sa2.spawn_heretic(c + Vector2(0, rad + 40.0))
	sa2.slow_heretic(h2, 40, 600)
	var stepped_in: int = 0
	for t2: int in 300:
		sa2.step(qs)
		if not Combat.box_outside_light(sd, sa2.safe, h2.pos):
			stepped_in += 1
	check(stepped_in == 0 and q.vitals.hp == Config.PLAYER_HP_MAX, "slowed: still never into the light, never hurts the one inside")
	# The oath and the blessing work on players inside the light too (they are players' effects).
	var pal: Player = player(sd, "paladin", c + Vector2(0, 20))
	pal.skills.resource = 100
	var pals: Array[Player] = [pal]
	check(Skills.land(pal, Skills.GUARDIAN_OATH, sa2, pals).warded == 1, "the oath in the light")


# --- threat ----------------------------------------------------------------------------------------------------------

func _check_threat() -> void:
	# A heretic goes after the paladin beside it (the nearest, no threat); the archer's arrow rain turns it onto him.
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var pal: Player = player(d, "paladin", Vector2(200, 200))
	var arc: Player = player(d, "archer", Vector2(290, 200))
	var players: Array[Player] = [pal, arc]
	var h: HereticSim = a.spawn_heretic(Vector2(215, 200))
	a.step(players)
	check_eq(h.target_id, pal.get_instance_id(), "setup: it goes after the nearest (the paladin)")
	arc.skills.resource = 30
	arc.action_target = h.pos
	var r: Skills.Landed = Skills.land(arc, Skills.ARROW_RAIN, a, players)
	steps(a, players, Skills.num_i(Skills.ARROW_RAIN, "delay_ticks"))
	check_eq(h.threat_of(arc.get_instance_id()), r.damage, "the rain's damage is the archer's threat")
	check(a.pick_target(h, players) == arc, "it turns onto the archer")
	# The rockfall's, the holy burst's and the sweep's damage too.
	var foe: HereticSim = a.spawn_heretic(Vector2(400, 400))
	a.stun_heretic(foe, 10000)  # held still under the rocks
	var m: Player = player(d, "miner", Vector2(300, 400))
	var ms: Array[Player] = [m]
	m.skills.resource = 40
	m.action_target = foe.pos
	Skills.land(m, Skills.ROCKFALL, a, ms)
	steps(a, ms, Skills.num_i(Skills.ROCKFALL, "delay_ticks"))
	check_eq(foe.threat_of(m.get_instance_id()), Skills.num_i(Skills.ROCKFALL, "damage"), "the rockfall's threat for the miner")
	var cle: Player = player(d, "cleric", Vector2(350, 400))
	cle.action_slot = hold(cle, &"holy_light")
	cle.action_target = foe.pos
	var cs: Array[Player] = [cle]
	Skills.land(cle, Skills.HOLY_BURST, a, cs)
	check_eq(foe.threat_of(cle.get_instance_id()), Skills.num_i(Skills.HOLY_BURST, "damage"), "the holy burst's for the cleric")
	# The paladin's taunt still wins over any damage while it lasts (M9a), stunned or not.
	a.taunt(pal, 64.0, 240)
	check(a.pick_target(h, players) == pal, "the taunt forces it back onto the paladin")


# --- no friendly fire -----------------------------------------------------------------------------------------------

func _check_no_friendly_fire() -> void:
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var ally: Player = player(d, "cleric", Vector2(220, 200))
	for c: String in Config.CLASSES:
		var p: Player = player(d, c, Vector2(200, 200))
		var party: Array[Player] = [p, ally]
		p.action_slot = hold(p, Combat.class_weapon(c))
		p.action_aim = 0
		p.action_target = ally.sim_position
		fill(p)
		for id: StringName in [WEAPON_SKILLS[c], SIGNATURES[c]]:
			var r: Skills.Landed = Skills.land(p, id, a, party)
			check(r.ok(), "%s lands (%s)" % [id, r.why])
			fill(p)
		steps(a, party, 120)
		check(ally.vitals.hp == Config.PLAYER_HP_MAX and not ally.vitals.staggered(), "%s's skills never hurt the ally in their way" % c)
		check(p.vitals.hp == Config.PLAYER_HP_MAX, "nor himself")
		p.teleport(Vector2(600, 450))
	check(ally.to_sim().walk_speed() == Config.WALK_SPEED, "the ally is not slowed (only heretics are)")


# --- determinism ----------------------------------------------------------------------------------------------------

func _check_determinism() -> void:
	var runs: Array[String] = []
	for run_i: int in 2:
		var d: WorldData = open_world()
		var a: Arena = arena_for(d)
		var pal: Player = player(d, "paladin", Vector2(200, 200))
		var arc: Player = player(d, "archer", Vector2(150, 230))
		var herb: Player = player(d, "herbalist", Vector2(230, 240))
		var party: Array[Player] = [pal, arc, herb]
		for q: Player in party:
			wire(q, a, party)
			hold(q, Combat.class_weapon(q.class_id()))
			fill(q)
		for x: int in [240, 260, 280]:
			a.spawn_heretic(Vector2(x, 200))
		var trace: PackedStringArray = []
		for t: int in 600:
			for q2: Player in party:
				var slot: int = -1
				if t % 150 == 10 + party.find(q2) * 7:
					slot = Skills.Slot.WEAPON
				elif t % 300 == 80 + party.find(q2) * 11:
					slot = Skills.Slot.SIGNATURE
				q2.begin_tick()
				var f: NetProtocol.InputFrame = q2.make_frame(Vector2i.ZERO, Vector2(260, 205), true, false, false, false, false,
					false, slot)
				q2.step_frame(f, TICK)
			a.step(party)
			if t % 20 == 0:
				for h: HereticSim in a.heretics:
					trace.append("%d:%d,%.3f,%.3f,%d,%d" % [h.id, h.hp, h.pos.x, h.pos.y, h.stun_ticks, h.slow_ticks])
				for q3: Player in party:
					trace.append("%s:%d,%s" % [q3.class_id(), q3.vitals.hp, q3.skills.describe()])
		runs.append(",".join(trace))
	check(runs[0] == runs[1] and runs[0].length() > 1000, "the same frames: the same fight, tick for tick (%d chars)" % runs[0].length())


# --- what is drawn ------------------------------------------------------------------------------------------------

func _check_views() -> void:
	# Arcs: only the dots within half the arc of the aim.
	for kind: int in [Arena.BurstKind.CRUSH, Arena.BurstKind.HEAVY, Arena.BurstKind.SWEEP]:
		check(CombatView.is_arc(kind), "kind %d is an arc" % kind)
		for frame: int in CombatView.BURST_FRAMES:
			var img: Image = CombatView.burst_image(kind, frame, 28.0, 0, 120.0)
			var half: int = CombatView.burst_half(28.0)
			var wrong: int = 0
			for y: int in img.get_height():
				for x: int in img.get_width():
					if img.get_pixel(x, y).a8 > 0 and absf(Vector2(x - half, y - half).angle()) > deg_to_rad(60.0 + 12.0):
						wrong += 1
			var full: Image = CombatView.burst_image(kind, frame, 28.0, 0, 360.0)
			check(wrong == 0 and opaque(img) > 0 and opaque(img) < opaque(full), "arc %d frame %d: only in front (%d of %d px)" % [kind, frame, opaque(img), opaque(full)])
	var west: Image = CombatView.burst_image(Arena.BurstKind.SWEEP, 2, 26.0, Combat.AIM_STEPS / 2, 120.0)
	var east: Image = CombatView.burst_image(Arena.BurstKind.SWEEP, 2, 26.0, 0, 120.0)
	var wh: int = CombatView.burst_half(26.0)
	var west_right: int = 0
	var east_left: int = 0
	for y5: int in west.get_height():
		for x5: int in west.get_width():
			if west.get_pixel(x5, y5).a8 > 0 and x5 > wh + 2:
				west_right += 1
			if east.get_pixel(x5, y5).a8 > 0 and x5 < wh - 2:
				east_left += 1
	check(west_right == 0 and east_left == 0 and opaque(west) > 0, "an arc turns with its aim (west / east)")
	for kind2: int in [Arena.BurstKind.OATH, Arena.BurstKind.HOLY, Arena.BurstKind.RAIN, Arena.BurstKind.ROCKS]:
		var ring: Image = CombatView.burst_image(kind2, 2, 32.0)
		var half2: int = CombatView.burst_half(32.0)
		var off: int = 0
		for y2: int in ring.get_height():
			for x2: int in ring.get_width():
				if ring.get_pixel(x2, y2).a8 > 0 and absf(Vector2(x2 - half2, y2 - half2).length() - 32.0) > 2.5:
					off += 1
		check(off == 0 and opaque(ring) >= CombatView.BURST_MIN_DOTS * 3, "ring %d: its dots on the ring" % kind2)
	# The strike's warning: the outer ring at the radius, the inner ring at frame / STRIKE_FRAMES of it, the plus.
	for frame2: int in CombatView.STRIKE_FRAMES:
		var s_img: Image = CombatView.strike_image(Arena.StrikeKind.ROCKS, frame2, 28.0)
		var hh: int = CombatView.burst_half(28.0)
		var outer: int = 0
		var inner: int = 0
		var stray: int = 0
		var inner_r: float = 28.0 * frame2 / CombatView.STRIKE_FRAMES
		for y3: int in s_img.get_height():
			for x3: int in s_img.get_width():
				var px: Color = s_img.get_pixel(x3, y3)
				if px.a8 == 0:
					continue
				var dist: float = Vector2(x3 - hh, y3 - hh).length()
				if absf(dist - 28.0) <= 0.75:
					outer += 1
				elif frame2 > 0 and absf(dist - inner_r) <= 0.75:
					inner += 1
				elif dist > 1.01:
					stray += 1
		check(outer >= ceili(TAU * 28.0 / CombatView.STRIKE_DOT_SPACING_PX) - 2 and stray == 0 and (frame2 == 0 or inner > 0),
			"warning frame %d: outer %d, inner %d, stray %d" % [frame2, outer, inner, stray])
	check(CombatView.strike_frame(0, 60) == 0 and CombatView.strike_frame(59, 60) == 3 and CombatView.strike_frame(30, 60) == 2,
		"the warning fills in over the delay")
	check(CombatView.fall_offset(Config.SKILL_FALL_TICKS + 1) == -1 and CombatView.fall_offset(Config.SKILL_FALL_TICKS) == Config.SKILL_FALL_HEIGHT_PX
		and CombatView.fall_offset(0) == 0, "the shapes are seen falling only in the last %d ticks" % Config.SKILL_FALL_TICKS)
	var fall: Image = CombatView.fall_image(Arena.StrikeKind.ARROWS, 32.0)
	var fh: int = CombatView.burst_half(32.0)
	var tips: int = 0
	for spot: Vector2i in CombatView.fall_spots(32.0):
		check(spot.length() <= 32.0 * CombatView.STRIKE_SHAPE_SPREAD + 1.0, "a falling shape inside the circle")
		if fall.get_pixel(fh + spot.x, fh + spot.y).to_rgba32() == ItemIcons.PALETTE["h"].to_rgba32():
			tips += 1
	check_eq(tips, CombatView.STRIKE_SHAPES, "each arrow's iron tip on its spot")
	# The zones: the blessing's ring on its radius; the mist's puffs and its edge.
	var bless: Image = CombatView.zone_image(Arena.ZoneKind.BLESSING, 1, 64.0)
	var bh: int = CombatView.burst_half(64.0)
	var boff: int = 0
	for y4: int in bless.get_height():
		for x4: int in bless.get_width():
			if bless.get_pixel(x4, y4).a8 > 0 and absf(Vector2(x4 - bh, y4 - bh).length() - 64.0) > 2.5:
				boff += 1
	check(boff == 0 and opaque(bless) > 100, "the blessing: a ring of dots on its radius")
	var mist: Image = CombatView.zone_image(Arena.ZoneKind.MIST, 0, 32.0)
	var mh: int = CombatView.burst_half(32.0)
	var middles: int = 0
	for spot2: Vector2i in CombatView.mist_spots(0, 32.0):
		if mist.get_pixel(mh + spot2.x, mh + spot2.y).to_rgba32() == ItemIcons.PALETTE["s"].to_rgba32():
			middles += 1
	check(middles >= CombatView.MIST_PUFFS / 2 and opaque(mist) > CombatView.MIST_PUFFS * 10,
		"the mist's puffs with their ivory hearts (%d middles, %d px)" % [middles, opaque(mist)])
	check(CombatView.mist_spots(1, 32.0) != CombatView.mist_spots(0, 32.0) and CombatView.zone_frame(CombatView.ZONE_FRAME_TICKS) == 1,
		"the mist drifts from frame to frame")
	# The view's nodes: a ring on the ground layer, the falling shapes with the entities, the zone on the ground layer.
	var d: WorldData = open_world()
	var a: Arena = arena_for(d)
	var holder: Node2D = Node2D.new()
	add_node(holder)
	var ents: Node2D = Node2D.new()
	holder.add_child(ents)
	var view: CombatView = CombatView.new()
	add_node(view)
	view.setup(a, ents)
	var pl: Player = player(d, "miner", Vector2(100, 100))
	var none: Array[Player] = [pl]
	var s: Arena.Strike = a.add_strike(Arena.StrikeKind.ROCKS, Vector2(200, 200), 28.0, 60, 10, 30, pl.get_instance_id())
	var z: Arena.Zone = a.add_zone(Arena.ZoneKind.MIST, Vector2(150, 150), 32.0, 90, 30, 4, pl.get_instance_id())
	view.sync(none)
	check(view.ground != null and view.ground.get_parent() == holder and view.ground.get_index() < ents.get_index(),
		"a ground layer just before the entities")
	check(view.strike_rings.has(s.id) and view.strike_rings[s.id].get_parent() == view.ground, "the strike's ring on the ground layer")
	check(view.strike_falls.has(s.id) and view.strike_falls[s.id].get_parent() == ents and not view.strike_falls[s.id].visible,
		"its falling shapes with the entities, not seen yet")
	check(view.zones.has(z.id) and view.zones[z.id].get_parent() == view.ground, "the zone on the ground layer")
	steps(a, none, 60 - Config.SKILL_FALL_TICKS)
	view.sync(none)
	var fall_node: Node2D = view.strike_falls[s.id]
	var sprite: Sprite2D = fall_node.get_node(^"Sprite") as Sprite2D
	check(fall_node.visible and sprite.position.y == -CombatView.burst_half(28.0) - Config.SKILL_FALL_HEIGHT_PX, "the rocks start falling from above")
	steps(a, none, Config.SKILL_FALL_TICKS)
	view.sync(none)
	check(view.strike_rings.is_empty() and view.strike_falls.is_empty(), "landed: the strike's nodes gone")
	steps(a, none, 30)
	view.sync(none)
	check(view.zones.is_empty(), "the zone's node gone when it ends")
	# Heretics' marks and pose; the warded player's mark.
	var h: HereticSim = a.spawn_heretic(Vector2(300, 300))
	a.stun_heretic(h, 30)
	a.slow_heretic(h, 40, 90)
	view.sync(none)
	var hn: Heretic = view.heretics[h.id]
	check(hn.marks.shown.has(EffectMarks.Kind.STUN) and hn.marks.shown.has(EffectMarks.Kind.SLOW), "a stunned and slowed heretic shows both marks")
	check(hn.anim == HereticSim.Anim.HURT and hn.frame == Config.SKILL_STUN_FRAME, "and the hurt pose held")
	view.clear()
	check(view.ground == null and holder.get_child_count() == 1, "clear() frees the ground layer")
	for kind3: int in [EffectMarks.Kind.WARD, EffectMarks.Kind.STUN, EffectMarks.Kind.SLOW]:
		check(EffectMarks.image(kind3).get_size() == Vector2i(7, 7) and opaque(EffectMarks.image(kind3)) > 10, "mark %d is drawn" % kind3)


# --- the HUD ---------------------------------------------------------------------------------------------------------

func _check_hud() -> void:
	# The ten icons' maps, pinned (the render check skills_hud draws a map against itself: a stray edit of a map would pass it).
	# A deliberate new icon updates its digest here.
	var digests: Dictionary[StringName, String] = {
		&"crushing_blow": "2facb106faa74efe1121addc3cd350eb", &"fan_shot": "fd649cb4f6fe198d8c3fd86b72dc88d2",
		&"holy_burst": "e7aaece377bae3364df4d7521a0e381a", &"heavy_strike": "690f0f0f404ad9d3481d42ea39f34766",
		&"sweep": "6bfc4ad9cf703ecf6c69e44103165b24", &"guardian_oath": "7a2142443d29785862d36005da09b950",
		&"arrow_rain": "4d32bb62a17b4a90a8c56adea9d799c4", &"blessing": "bccfd98387f17dc3ca20abe213da3847",
		&"rockfall": "edee770b830b7eb90620df5f530258e8", &"healing_mist": "c16479c2e8f69fa0f779bf2aced3a4b1",
	}
	var maps_seen: Dictionary[String, StringName] = {}
	for icon: StringName in digests:
		var rows: PackedStringArray = []
		for row: Variant in SkillIcons.MAPS[icon]:
			var line: String = row
			rows.append(line)
		var joined: String = "\n".join(rows)
		check_eq(joined.md5_text(), digests[icon], "%s's icon map as drawn (pinned)" % icon)
		check(not maps_seen.has(joined), "%s's icon differs from the others" % icon)
		maps_seen[joined] = icon
	var d: WorldData = open_world()
	for c: String in Config.CLASSES:
		var p: Player = player(d, c, Vector2(100, 100))
		for slot: int in [Skills.Slot.WEAPON, Skills.Slot.SIGNATURE]:
			var id: StringName = Skills.kit_skill(c, slot)
			check(SkillIcons.map_for(id) == SkillIcons.MAPS[id] and SkillIcons.texture_for(id) != null,
				"%s: slot %s shows %s's icon" % [c, Skills.SLOT_KEYS[slot], id])
			p.skills.start_cooldown(slot, Skills.cooldown_ticks(id) / 2)
			check_eq(Hud.skill_veil_rows(p, slot), 7, "%s: %s half cooled: half veiled" % [c, id])


# --- main.tscn offline ------------------------------------------------------------------------------------------------

func _check_main() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn("paladin")
	var p: Player = main.player
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	p.inventory.select(Config.START_WEAPON_SLOT)
	check_eq(p.inventory.selected_stack().id, &"sword", "main: the paladin holds his sword")
	var foe: HereticSim = main.arenas[Config.MAP_SURFACE].spawn_heretic(p.sim_position + Vector2(20, 0))
	var mouse: Vector2 = aim_at(p, Vector2.RIGHT)
	_tick_main(main, p, mouse, Skills.Slot.WEAPON)
	check_eq(p.action_skill, Skills.CRUSHING_BLOW, "main: key 2 = the crushing blow")
	for t: int in Skills.impact_tick(Skills.CRUSHING_BLOW):
		_tick_main(main, p, mouse, -1)
	check(foe.hp == Config.HERETIC_HP - Skills.num_i(Skills.CRUSHING_BLOW, "damage") and foe.stunned(), "main: it hit and stunned (%d)" % foe.hp)
	check_eq(main.skills_landed, 1, "main: landed")
	check(main.combat_views[Config.MAP_SURFACE].bursts.size() >= 1, "main: its arc drawn")
	# The shrine broken by a crushing blow through Main (its edits go into the world).
	main.travel(Config.MAP_DUNGEON)
	main.arenas[Config.MAP_DUNGEON].spawning = false
	var w: GameWorld = main.current_world()
	var rect: Rect2i = DungeonGen.shrine_rect(w.data)
	var below: Vector2 = Vector2(FixtureView.foot_of(rect).x, (rect.end.y + 1) * Config.TILE - 4.0)
	p.teleport(below)
	main.arenas[Config.MAP_DUNGEON].shrine_hp = 5
	var up: Vector2 = aim_at(p, Vector2.UP, 30.0)
	for t3: int in 40:
		_tick_main(main, p, up, -1)
	p.skills.start_cooldown(Skills.Slot.WEAPON, 0)
	_tick_main(main, p, up, Skills.Slot.WEAPON)
	for t2: int in Skills.impact_tick(Skills.CRUSHING_BLOW):
		_tick_main(main, p, up, -1)
	check_eq(w.data.footprints(WorldData.PLACEABLE_SHRINE_BROKEN), [rect] as Array[Rect2i], "main: the shrine broken by the blow")
	# The miner's rockfall through Main and its bot key (--test-resource's meter).
	main.travel(Config.MAP_SURFACE)
	main.spawn(Mining.MINER_CLASS)
	var m: Player = main.player
	m.local_input = false
	m.skills.resource = Skills.signature_cost("miner")
	m.teleport(Arena.spawn_feet(Vector2i(63, 57)))  # open ground south of the light (the altar would stop the point short)
	check(Combat.line_clear(m.data, m.sim_position, m.sim_position + Vector2(40, 0)), "setup: open ground east of the miner")
	var rock_foe: HereticSim = main.arenas[Config.MAP_SURFACE].spawn_heretic(m.sim_position + Vector2(40, 0))
	main.arenas[Config.MAP_SURFACE].stun_heretic(rock_foe, 10000)
	main.bot = NetBot.new()
	main.bot.parse("aim:40,0;wait:2;skill:r;wait:120")
	for i: int in Skills.impact_tick(Skills.ROCKFALL) + Skills.num_i(Skills.ROCKFALL, "delay_ticks") + 12:
		await tree.physics_frame
	main.bot = null
	check_eq(rock_foe.hp, Config.HERETIC_HP - Skills.num_i(Skills.ROCKFALL, "damage"), "main: the bot's R dropped the rocks")
	check_eq(m.skills.resource, 0, "main: its endurance spent")
	# The heavy strike aimed at a dungeon wall through Main: it never mines.
	main.travel(Config.MAP_DUNGEON)
	var w2: GameWorld = main.current_world()
	var exit: Rect2i = DungeonGen.exit_rect(w2.data)
	var face: Vector2i = Vector2i(exit.end.x + 1, exit.position.y)
	var feet_cell: Vector2i = face + Vector2i(0, 1)
	m.teleport(Vector2(feet_cell.x * 16 + 8, feet_cell.y * 16 + 14))
	m.inventory.select(Config.START_WEAPON_SLOT)
	check_eq(m.inventory.selected_stack().id, &"pickaxe", "main: the miner holds his pickaxe")
	var hits: int = Walls.hits_at(w2.data, face)
	var hash_before: String = w2.data.content_hash()
	var at_wall: Vector2 = Vector2(face * Config.TILE) + Vector2(8, 8)
	for t4: int in 40:
		_tick_main(main, m, at_wall, -1)
	_tick_main(main, m, at_wall, Skills.Slot.WEAPON)
	check_eq(m.action_skill, Skills.HEAVY_STRIKE, "main: key 2 = the heavy strike")
	for t5: int in Skills.impact_tick(Skills.HEAVY_STRIKE) + 2:
		_tick_main(main, m, at_wall, -1)
	check(Walls.hits_at(w2.data, face) == hits and w2.data.content_hash() == hash_before and m.skills.resource == 0,
		"main: the heavy strike at a wall mined nothing (the world unchanged, no endurance either)")


## One offline tick of main: the player's controls (`slot` = a skill key 2 / 3 / R this tick, -1 none), then the combat.
static func _tick_main(main: Main, p: Player, mouse: Vector2, slot: int) -> void:
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, mouse, true, false, false, TICK, false, false, false, slot)
	main.step_combat(TICK)
