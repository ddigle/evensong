extends "res://tests/test_net_skills.gd"
## M9 review: the fixes the independent reviewers' findings asked for, offline and in sessions (the rig of tests/test_net_combat.gd):
##   - offline: a skill key pressed in the dash's tick is refused (the HUD's mark) instead of vanishing; the heal fizzles when its
##     ally is at full HP by the impact frame (nothing spent, no cooldown) or changed maps; a splash heal and a drunk heal add
##     heal threat (Main's drink and throw through main.tscn, the bottle following the ally); a heretic whose target is stale
##     (has_target off) gets no heal threat; the oath's ward counts down while its player is down; a taunt ends once its paladin
##     is down or gone (its mark with it); the ally ring is off while a panel is open and ash grey on a full-HP ally; with
##     Config.THROW_HERBALIST_ONLY off nobody else throws (key 1 is each class's identity skill)
##   - sessions: the host heals the ally the cleric's ring showed although that ally walked on (the request's picked ally within
##     Config.SKILL_PICK_LAG_PX); key 2 plays the hotbar slot the request names (a SELECT queued in the same tick cannot swap the
##     weapon: tier-1 damage and wear on the right stack, the client's inventory shows the wear); the healing mist's herbs leave
##     the client's inventory; a client's drawn healing bottle bends toward the walking ally it follows; a drunk heal adds heal
##     threat on the host; a SKILL counts once as "skill" when it starts, a SKILL with the dash in its frame is refused before the
##     budget; a blessing whose cleric goes down sends its early end; a dead player's shield and a leaver's are erased on the
##     other machines; another class's THROW is refused with the switch off (its identity cooldown untouched)

const HEALING: StringName = &"potion_healing"


func run() -> Array[String]:
	_check_dash_refuses()
	_check_heal_fizzles()
	_check_heal_threat_paths()
	_check_ward_while_down()
	_check_taunt_ends()
	_check_ring_rules()
	_check_herbalist_switch_offline()
	await _check_main_paths()
	await _check_pick_follows_the_ring()
	await _check_queued_select()
	await _check_mist_herbs()
	await _check_flask_bends()
	await _check_host_drink_threat()
	await _check_counts_and_dash()
	await _check_zone_end_and_wards()
	await _check_throw_switch_host()
	for n: Node in _made:
		if is_instance_valid(n) and n.get_parent() == null:
			n.free()
	return failures


# --- helpers -------------------------------------------------------------------------------------------------

var _made: Array[Node] = []


## An open dungeon-kind map (no altar, so no light).
static func _open_world(size: Vector2i = Vector2i(40, 30)) -> WorldData:
	var d: WorldData = WorldData.new(size)
	d.map_id = Config.MAP_DUNGEON
	return d


## An offline player with the skill kit and potions.
func _mk(d: WorldData, class_id: String, at: Vector2) -> Player:
	var p: Player = Player.new()
	p.setup(d, class_id, at)
	p.skills_on = true
	p.potions_on = true
	_made.append(p)
	return p


static func _arena(d: WorldData) -> Arena:
	var a: Arena = Arena.new()
	a.setup(d, 1)
	a.spawning = false
	a.threat_on = true
	return a


static func _stand(p: Player) -> int:
	p.begin_tick()
	return p.step_frame(NetProtocol.InputFrame.new(), 1.0 / 60.0)


## Presses key `slot` with the mouse at `mouse` (optionally with the dash) and steps one tick. Returns the frame.
static func _key(p: Player, slot: int, mouse: Vector2, dash: bool = false) -> NetProtocol.InputFrame:
	p.begin_tick()
	var f: NetProtocol.InputFrame = p.make_frame(Vector2i(1, 0) if dash else Vector2i.ZERO, mouse, true, false, false, dash, false,
		slot == Skills.Slot.IDENTITY, slot if slot != Skills.Slot.IDENTITY else -1)
	p.step_frame(f, 1.0 / 60.0)
	return f


## A heretic on `a` held still (stunned for a long while) that is after player `t` (has a target): heal threat reaches it.
static func _engaged(a: Arena, at: Vector2, t: Player) -> HereticSim:
	var h: HereticSim = a.spawn_heretic(at)
	h.stun_ticks = 6000
	h.has_target = true
	h.target_id = t.get_instance_id()
	h.state = HereticSim.State.CHASE
	return h


# --- offline -------------------------------------------------------------------------------------------------

func _check_dash_refuses() -> void:
	var d: WorldData = _open_world()
	var m: Player = _mk(d, "miner", Vector2(160, 160))
	var why: Array[String] = []
	m.skill_refused.connect(func(_slot: int, _id: StringName, w: String) -> void: why.append(w))
	var f: NetProtocol.InputFrame = _key(m, Skills.Slot.IDENTITY, m.sim_position + Vector2(20, 0), true)
	check(f.anim < 0 and f.op == NetProtocol.Op.NONE and f.skill.is_empty() and why.size() == 1 and why[0] == Skills.WHY_BUSY,
		"a skill key in the dash's tick: refused mid-action (%s), nothing in the frame" % [why])
	check(m.skills.refused_slot == Skills.Slot.IDENTITY and m.skills.refused_ticks > 0 and m.vitals.dashing() and m.action_anim < 0,
		"the HUD marks key 1, the dash goes on, no action")
	check_eq(m.skills.cooldown(Skills.Slot.IDENTITY), 0, "nothing spent")
	for i: int in Config.DASH_TICKS + Config.DASH_COOLDOWN_TICKS + 2:
		_stand(m)
	var f2: NetProtocol.InputFrame = _key(m, Skills.Slot.IDENTITY, m.sim_position + Vector2(20, 0))
	check(f2.skill == Skills.GROUND_SLAM and m.action_skill == Skills.GROUND_SLAM, "the same key without the dash: the slam starts")


func _check_heal_fizzles() -> void:
	var d: WorldData = _open_world()
	var c: Player = _mk(d, "cleric", Vector2(100, 100))
	var a: Player = _mk(d, "paladin", Vector2(150, 100))
	var party: Array[Player] = [c, a]
	c.party_provider = func() -> Array[Player]: return party
	var arena: Arena = _arena(d)
	a.vitals.hp = 50
	_key(c, Skills.Slot.IDENTITY, Combat.body_centre(a.sim_position))
	check(c.action_skill == Skills.HEAL and c.action_skill_target == a.get_instance_id(), "the heal starts on the paladin")
	a.vitals.hp = Config.PLAYER_HP_MAX  # another heal got there first
	var r: Skills.Landed = Skills.land(c, Skills.HEAL, arena, party)
	check(r.why == Skills.WHY_FULL_HP and r.healed == 0 and c.skills.cooldown(Skills.Slot.IDENTITY) == 0 and c.skills.resource == 0,
		"the ally is full by the impact frame: it fizzles (full hp), no cooldown, no faith (%s)" % r.why)
	a.vitals.hp = 50
	var away: WorldData = _open_world()
	a.set_world(away, a.sim_position)
	var r2: Skills.Landed = Skills.land(c, Skills.HEAL, arena, party)
	check(r2.why == Skills.WHY_NO_ALLY and a.vitals.hp == 50 and c.skills.cooldown(Skills.Slot.IDENTITY) == 0,
		"the ally changed maps before the impact frame: it fizzles, nothing healed")
	a.set_world(d, a.sim_position)
	var r3: Skills.Landed = Skills.land(c, Skills.HEAL, arena, party)
	check(r3.ok() and a.vitals.hp == 50 + Skills.num_i(Skills.HEAL, "heal_hp"), "back on the map, hurt: it lands")


func _check_heal_threat_paths() -> void:
	var d: WorldData = _open_world()
	var hb: Player = _mk(d, "herbalist", Vector2(100, 160))
	var a: Player = _mk(d, "paladin", Vector2(150, 160))
	var party: Array[Player] = [hb, a]
	var arena: Arena = _arena(d)
	var h: HereticSim = _engaged(arena, Vector2(400, 160), a)
	a.vitals.hp = 40
	arena.throw_potion(hb, HEALING, ItemDB.Grade.FINE, Combat.body_point(a.sim_position), 255, a)
	for i: int in 40:
		arena.step(party)
	check(a.vitals.hp > 40 and h.threat_of(hb.get_instance_id()) > 0,
		"a thrown healing potion that heals the paladin: heal threat for the herbalist on the heretic after him (%d)" % (
		h.threat_of(hb.get_instance_id())))
	# A heretic that lost its target keeps a stale target_id; has_target is off, so a heal near that player is no threat for it.
	var stale: HereticSim = arena.spawn_heretic(Vector2(420, 200))
	stale.stun_ticks = 6000
	stale.has_target = false
	stale.target_id = a.get_instance_id()
	a.vitals.hp = 40
	var engaged: int = arena.heal_threat(hb.get_instance_id(), a, 20, party)
	check(engaged == 1 and stale.threat_of(hb.get_instance_id()) == 0,
		"a heretic with a stale target id (has_target off) gets no heal threat; the engaged one does (%d)" % engaged)


func _check_ward_while_down() -> void:
	var d: WorldData = _open_world()
	var p: Player = _mk(d, "archer", Vector2(100, 100))
	check(p.skills.add_ward(50, 300), "warded for 300 ticks")
	p.take_hit(Config.PLAYER_HP_MAX * 4)
	check(p.vitals.life == Vitals.Life.DOWN, "then downed")
	var left: int = p.skills.ward_ticks
	for i: int in 30:
		_stand(p)
	check_eq(p.skills.ward_ticks, left - 30, "the ward counts down while its player is down (the receiver's game clock)")


func _check_taunt_ends() -> void:
	var d: WorldData = _open_world()
	var pl: Player = _mk(d, "paladin", Vector2(160, 160))
	var other: Player = _mk(d, "archer", Vector2(160, 260))
	var arena: Arena = _arena(d)
	var h: HereticSim = arena.spawn_heretic(Vector2(200, 160))
	check(arena.taunt(pl, 64.0, 240) == 1 and h.taunted() and h.taunt_by == pl.get_instance_id(), "taunted by the paladin")
	var both: Array[Player] = [pl, other]
	arena.step(both)
	check(h.taunted(), "it holds while he is up")
	pl.take_hit(Config.PLAYER_HP_MAX * 4)
	arena.step(both)
	check(not h.taunted() and h.taunt_by == 0 and h.taunt_ticks == 0, "he went down: the taunt ends at once (no mark)")
	check(not NetProtocol.enemy_of(h, 1).taunted, "and the enemy batch carries no taunt mark")
	pl.revive_now()
	var h2: HereticSim = arena.spawn_heretic(Vector2(200, 180))
	arena.taunt(pl, 64.0, 240)
	check(h2.taunted(), "taunted again")
	var others: Array[Player] = [other]
	arena.step(others)
	check(not h2.taunted(), "he left the map (not among its players): the taunt ends")


func _check_ring_rules() -> void:
	var d: WorldData = _open_world()
	var c: Player = _mk(d, "cleric", Vector2(100, 100))
	var a: Player = _mk(d, "paladin", Vector2(140, 100))
	var party: Array[Player] = [c, a]
	c.party_provider = func() -> Array[Player]: return party
	var mouse: Vector2 = Combat.body_centre(a.sim_position)
	c.begin_tick()
	c.tick_controls(Vector2i.ZERO, mouse, true, false, false, 1.0 / 60.0)
	check(c.skill_aim_target == a and c.skill_aim_refused, "a full-HP ally: the ring under him, marked refused")
	a.vitals.hp = 60
	c.begin_tick()
	c.tick_controls(Vector2i.ZERO, mouse, true, false, false, 1.0 / 60.0)
	check(c.skill_aim_target == a and not c.skill_aim_refused, "a hurt ally: the plain ring")
	c.ui_locked = true
	c.begin_tick()
	c.tick_controls(Vector2i.ZERO, mouse, true, false, false, 1.0 / 60.0)
	check(c.skill_aim_target == null, "a panel open: no ring (the key would be refused)")
	c.ui_locked = false
	var mark: AllyMark = AllyMark.new()
	_made.append(mark)
	mark.show_for(a, true)
	var img: Image = mark.sprite.texture.get_image()
	check(mark.visible and mark.dim and img.get_pixel(4, 0) == AllyMark.DIM, "the dim ring is ash grey")
	mark.show_for(a)
	img = mark.sprite.texture.get_image()
	check(mark.visible and not mark.dim and img.get_pixel(4, 0) == AllyMark.GOLD, "the plain ring is gold")
	mark.show_for(null, true)
	check(not mark.visible and not mark.dim, "nobody: hidden")


func _check_herbalist_switch_offline() -> void:
	var d: WorldData = _open_world()
	var pl: Player = _mk(d, "paladin", Vector2(100, 100))
	pl.inventory.add(HEALING, 1)
	pl.inventory.select(test_slot_of(pl.inventory, HEALING))
	Potions.herbalist_only = false
	var f: NetProtocol.InputFrame = _key(pl, Skills.Slot.IDENTITY, pl.sim_position + Vector2(30, 0))
	Potions.herbalist_only = Config.THROW_HERBALIST_ONLY
	check(f.op != NetProtocol.Op.THROW and pl.action_skill == Skills.TAUNT and pl.inventory.count_of(HEALING) == 1,
		"THROW_HERBALIST_ONLY off: a paladin's key 1 is still his taunt (nobody else throws with the skill kit on)")


static func test_slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		if inv.stack_at(i) != null and inv.stack_at(i).id == id:
			return i
	return -1


## Offline Main (main.tscn): a healing throw follows the ally the ring showed (Main.potion_impact passes it), a drunk heal adds
## heal threat on the heretic after the drinker.
func _check_main_paths() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	add_node(main)
	await await_frames(2)
	main.spawn("herbalist")
	var p: Player = main.player
	p.local_input = false
	main.arenas[Config.MAP_SURFACE].spawning = false
	var ally: Player = main.add_ally("paladin", false)
	ally.vitals.hp = 50
	p.inventory.add(HEALING, 2, ItemDB.Grade.FINE)
	p.inventory.select(test_slot_of(p.inventory, HEALING))
	var mouse: Vector2 = Combat.body_centre(ally.sim_position)
	_main_tick(main, p, mouse, false, true)
	check(p.action_skill == Skills.POTION_THROW and p.action_skill_target == ally.get_instance_id(), "main: key 1 throws at the ally")
	var arena: Arena = main.arenas[Config.MAP_SURFACE]
	var follows: bool = false
	for t: int in Skills.impact_tick(Skills.POTION_THROW) + 2:
		_main_tick(main, p, mouse, false, false)
		for fl: Arena.Flask in arena.flasks:
			if fl.follow_id == ally.get_instance_id():
				follows = true
	check(follows, "main: the bottle follows the ally (Main passes him to the throw)")
	for t2: int in 60:
		_main_tick(main, p, mouse, false, false)
	check(ally.vitals.hp > 50, "main: the ally healed (%d)" % ally.vitals.hp)
	var h: HereticSim = _engaged(arena, p.sim_position + Vector2(300, 0), p)
	p.vitals.hp = 40
	_main_tick(main, p, p.sim_position + Vector2(0, -20), true, false)
	for t3: int in PlayerSim.action_ticks(Config.DRINK_ANIM) + 2:
		_main_tick(main, p, p.sim_position + Vector2(0, -20), false, false)
	check(p.vitals.hp > 40 and h.threat_of(p.get_instance_id()) > 0,
		"main: a drunk healing potion adds heal threat on the heretic after the drinker (%d)" % h.threat_of(p.get_instance_id()))


static func _main_tick(main: Main, p: Player, mouse: Vector2, use: bool, skill: bool) -> void:
	p.begin_tick()
	p.tick_controls(Vector2i.ZERO, mouse, true, use, false, 1.0 / 60.0, false, false, skill)
	main.step_combat(1.0 / 60.0)


# --- sessions ------------------------------------------------------------------------------------------------

## The cleric client heals the archer its ring shows while the archer walks on; the host's own positions would pick the paladin
## standing beside where the cleric draws the archer. The request's picked ally wins (within the lag allowance).
func _check_pick_follows_the_ring() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 6
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var host_p: Player = r.s.local.player
	host_p.teleport(base + Vector2(40, 0))
	host_p.vitals.hp = 60
	var cl: Client = _join(r, 101, CLERIC, base + Vector2(40, 40))
	var ar: Client = _join(r, 102, ARCHER, base + Vector2(-50, 0))
	var cm: NetMember = hm(r, cl)
	var am: NetMember = hm(r, ar)
	am.player.vitals.hp = 40
	_tick(r, 14)
	var walk: NetBot.Action = NetBot.Action.new()
	walk.dir = Vector2i(1, 0)
	ar.action = walk
	var drawn_ar: Player = cl.s.members[am.slot].player
	var drawn_pal: Player = cl.s.members[r.s.local.slot].player
	var t: int = 0
	while t < 240:
		_tick(r)
		draw_all(r)
		if drawn_ar.sim_position.x >= drawn_pal.sim_position.x - 6.0:
			break
		t += 1
	var cursor: Vector2 = Combat.body_centre(drawn_ar.sim_position)
	press(r, null, cl, key_at(Skills.Slot.IDENTITY, cursor))
	var sent: NetProtocol.InputFrame = null
	for pe: Prediction.Pending in cl.s.client.prediction.pending:
		if pe.frame.op == NetProtocol.Op.SKILL:
			sent = pe.frame
	check(cl.s.local.player.skill_aim_target == drawn_ar and sent != null and sent.pick == am.slot,
		"the cleric's ring is on the archer as drawn, and the SKILL names him (pick %d)" % (sent.pick if sent != null else -1))
	var started: int = tick_until(r, func() -> bool: return cm.player.action_skill == Skills.HEAL, 40)
	var host_own: Player = Skills.pick_ally(r.host.players_on(Config.MAP_SURFACE), cm.player,
		Vector2(NetProtocol.wire_point(cursor)), Skills.num_f(Skills.HEAL, "range_px"))
	check(started < 40 and host_own == host_p,
		"when it reaches the host the archer has walked on: the host's own positions would pick the paladin (%.1f px vs %.1f px)" % [
		Skills.cursor_distance(am.player, cursor), Skills.cursor_distance(host_p, cursor)])
	check(cm.player.action_skill_target == am.player.get_instance_id(), "the host takes the ally the cleric's ring showed")
	_tick(r, Skills.impact_tick(Skills.HEAL) + 2)
	check(am.player.vitals.hp == 40 + Skills.num_i(Skills.HEAL, "heal_hp") and host_p.vitals.hp == 60,
		"the archer healed (%d), the paladin not (%d)" % [am.player.vitals.hp, host_p.vitals.hp])
	ar.action = null
	_free_rig(r)


## An archer client queues a SELECT of its tier-1 bow and presses key 2 in the same tick (the SELECT goes out a frame later):
## the host plays the fan shot with the stack the request names (tier-1 damage, its wear), and the client's inventory shows it.
func _check_queued_select() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 2
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var ar: Client = _join(r, 101, ARCHER, base)
	var am: NetMember = hm(r, ar)
	give(am, &"bow_t1", 1)
	var t1: int = slot_of(am.player.inventory, &"bow_t1")
	if t1 >= am.player.inventory.hotbar_size:
		am.player.inventory.move(t1, 0)  # into the hotbar (swapping out whatever was in slot 0)
		t1 = slot_of(am.player.inventory, &"bow_t1")
	_tick(r, 2 * r.delay + 4)
	check(t1 >= 0 and t1 < am.player.inventory.hotbar_size and am.player.inventory.selected == WEAPON_SLOT,
		"the base bow selected, the tier-1 bow in hotbar slot %d" % t1)
	var full: int = am.player.inventory.stack_at(t1).durability
	var sel: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	sel.op = NetProtocol.Op.SELECT
	sel.slot = t1
	ar.s.queue_op(sel)
	press(r, null, ar, key_at(Skills.Slot.WEAPON, base + Vector2(60, 0)))
	var started: int = tick_until(r, func() -> bool: return am.player.action_skill == Skills.FAN_SHOT, 30)
	check(started < 30 and am.player.action_slot == t1, "the host plays the fan shot with the tier-1 bow's slot (%d)" % am.player.action_slot)
	_tick(r, Skills.impact_tick(Skills.FAN_SHOT) + 1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var dmg: int = arena.shots.back().damage if not arena.shots.is_empty() else -1
	check(dmg == Gear.attack_damage(am.player.inventory.stack_at(t1), Skills.num_i(Skills.FAN_SHOT, "damage")) and dmg > Skills.num_i(Skills.FAN_SHOT, "damage"),
		"its arrows land the tier-1 damage (%d)" % dmg)
	check(am.player.inventory.stack_at(t1).durability == full - Config.GEAR_WEAR_PER_ATTACK, "the tier-1 bow wore once on the host")
	_tick(r, 2 * r.delay + 6)
	var mine: ItemStack = ar.s.local.player.inventory.stack_at(t1)
	check(mine != null and mine.durability == full - Config.GEAR_WEAR_PER_ATTACK and ar.s.client.prediction.action_corrections == 0,
		"the client's inventory shows the wear (%d), its predicted action needed no correction" % (mine.durability if mine != null else -1))
	_free_rig(r)


## The herbalist client's healing mist spends three herbs on the host; its inventory shows one left.
func _check_mist_herbs() -> void:
	var r: Rig = _rig(PALADIN)
	r.delay = 2
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var hb: Client = _join(r, 101, HERB, base, false)
	var hbm: NetMember = hm(r, hb)
	give(hbm, Config.HERBALIST_MATERIAL_ITEM, 4)
	_tick(r, 2 * r.delay + 4)
	check_eq(hb.s.local.player.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM), 4, "the client has four herbs")
	press(r, null, hb, key_at(Skills.Slot.SIGNATURE, base + Vector2(30, 0)))
	tick_until(r, func() -> bool: return hbm.player.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM) == 1, 60)
	_tick(r, 2 * r.delay + 4)
	check(hbm.player.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM) == 1
		and hb.s.local.player.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM) == 1,
		"the mist spent three: one left on the host and on the client (%d)" % hb.s.local.player.inventory.count_of(Config.HERBALIST_MATERIAL_ITEM))
	_free_rig(r)


## A healing bottle thrown at a walking paladin client: every machine's drawn flight bends toward him (the thrown event names the
## ally it follows), its end near his body point as drawn there.
func _check_flask_bends() -> void:
	var r: Rig = _rig(ARCHER)
	r.delay = 3
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var hb: Client = _join(r, 101, HERB, base, false)
	var pl: Client = _join(r, 102, PALADIN, base + Vector2(50, 0))
	var hbm: NetMember = hm(r, hb)
	var plm: NetMember = hm(r, pl)
	give(hbm, HEALING, 1, ItemDB.Grade.FINE)
	plm.player.vitals.hp = 30
	_tick(r, 8)
	press(r, null, hb, _select(slot_of(hb.s.local.player.inventory, HEALING)))
	_tick(r, 8)
	draw_all(r)
	var drawn: Player = hb.s.members[plm.slot].player
	press(r, null, hb, throw_at(Combat.body_centre(drawn.sim_position)))
	var walk: NetBot.Action = NetBot.Action.new()
	walk.dir = Vector2i(1, 0)
	pl.action = walk
	var got: int = tick_until(r, func() -> bool: return not skill_events_of(hb, NetProtocol.ShotEvent.Kind.THROW).is_empty(), 60)
	var ev: NetProtocol.ShotEvent = skill_events_of(hb, NetProtocol.ShotEvent.Kind.THROW)[0] if got < 60 else null
	check(ev != null and ev.follow == plm.slot, "the thrown event names the paladin as the ally it follows (%d)" % (ev.follow if ev != null else -1))
	_tick(r, 4)
	draw_all(r)
	for c: Client in [hb, pl] as Array[Client]:
		var tr: NetCombat.FlaskTrack = track(c, ev.id) if ev != null else null
		var him: Player = c.s.members[plm.slot].player if c != pl else c.s.local.player
		var want: Vector2 = Potions.throw_target(tr.origin, Combat.body_point(him.sim_position)) if tr != null else Vector2.INF
		check(tr != null and tr.follow == plm.slot and tr.target.distance_to(ev.target) > 0.5 and tr.target.distance_to(want) < 0.01,
			"peer %d: the drawn flight bends toward the walking paladin as drawn (%.1f px from the throw's first aim)" % [c.peer,
			tr.target.distance_to(ev.target) if tr != null else -1.0])
	pl.action = null
	_tick(r, 40)
	check(plm.player.vitals.hp > 30, "the bottle healed him on the host (%d)" % plm.player.vitals.hp)
	_free_rig(r)


## A client drinks a healing potion while a heretic is after it: the host adds heal threat (SessionHost._potion).
func _check_host_drink_threat() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var ar: Client = _join(r, 101, ARCHER, base, false)
	var am: NetMember = hm(r, ar)
	give(am, HEALING, 1)
	am.player.vitals.hp = 40
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = _engaged(arena, base + Vector2(0, 200), am.player)
	_tick(r, 4)
	press(r, null, ar, _select(slot_of(ar.s.local.player.inventory, HEALING)))
	_tick(r, 4)
	press(r, null, ar, click_at(base + Vector2(0, -20)))
	tick_until(r, func() -> bool: return am.player.vitals.hp > 40, 60)
	check(am.player.vitals.hp > 40 and h.threat_of(am.player.get_instance_id()) > 0,
		"a drunk healing potion on the host: heal threat on the heretic after the drinker (%d)" % h.threat_of(am.player.get_instance_id()))
	_free_rig(r)


## A SKILL counts once, as "skill", when its action starts; a SKILL with the dash in its frame is refused before the budget.
func _check_counts_and_dash() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var ac: Client = await _join_quiet(r, 101, ARCHER, base)
	var am: NetMember = hm(r, ac)
	am.player.inventory.select(WEAPON_SLOT)
	skill_frame(r, am, _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.IDENTITY, base + Vector2(60, 0)))
	var skills_done: int = am.ops_done.get("skill", 0)
	check(am.player.action_skill == Skills.PIERCING_ARROW and skills_done == 1 and not am.ops_done.has("use"),
		"a piercing arrow: counted once as a skill when it started (%s)" % am.ops_done)
	idle_ticks(r, am, PlayerSim.action_ticks(RigData.Anim.BOW) + 2)
	am.op_budget = NetMember.OP_BUDGET_MAX
	var f: NetProtocol.InputFrame = _skill(Config.MAP_SURFACE, beside(am), Skills.Slot.WEAPON, base + Vector2(60, 0))
	f.dash = true
	skill_frame(r, am, f)
	var skills_after: int = am.ops_done.get("skill", 0)
	check(am.refused(Skills.WHY_BUSY) == 1 and am.player.action_anim < 0 and skills_after == 1,
		"a SKILL with the dash in its frame: refused mid-action, nothing starts, not counted")
	check_eq(am.op_budget, NetMember.OP_BUDGET_MAX, "and it spent no request budget")
	_free_rig(r)


## A host cleric's blessing ends early when he goes down: the clients get its end. A ward over a client that dies, and over one
## that leaves, is erased on the other machines.
func _check_zone_end_and_wards() -> void:
	var r: Rig = _rig(CLERIC)
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var host_p: Player = r.s.local.player
	host_p.teleport(base)
	var ar: Client = _join(r, 101, ARCHER, base + Vector2(20, 0))
	var pl: Client = _join(r, 102, PALADIN, base + Vector2(-20, 0))
	var mi: Client = _join(r, 103, MINER, base + Vector2(0, 20))
	var am: NetMember = hm(r, ar)
	var pm: NetMember = hm(r, pl)
	var mm: NetMember = hm(r, mi)
	host_p.skills.resource = 60
	press(r, key_at(Skills.Slot.SIGNATURE, base))
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	tick_until(r, func() -> bool: return not arena.zones.is_empty(), 40)
	_tick(r, 6)
	check(not skill_events_of(ar, NetProtocol.ShotEvent.Kind.ZONE).is_empty(), "the archer's machine got the blessing")
	host_p.take_hit(Config.PLAYER_HP_MAX * 4)
	_tick(r, 4)
	var ends: Array[NetProtocol.ShotEvent] = skill_events_of(ar, NetProtocol.ShotEvent.Kind.ZONE_END)
	check(arena.zones.is_empty() and ends.size() == 1, "the cleric went down: the blessing ends, the clients get its early end")
	# The paladin's oath wards the archer and the miner; the archer dies, the miner leaves.
	pm.player.skills.resource = 60
	_tick(r, 6)  # his machine hears it (the skills message) before he presses R
	press(r, null, pl, key_at(Skills.Slot.SIGNATURE, pm.player.sim_position))
	tick_until(r, func() -> bool: return am.player.skills.ward_ticks > 0 and mm.player.skills.ward_ticks > 0, 60)
	_tick(r, 10)  # past the drawing buffer (the others are drawn 100 ms behind)
	draw_all(r)
	var seen_ar: Player = pl.s.members[am.slot].player
	var seen_mi: Player = pl.s.members[mm.slot].player
	check(seen_ar.skills.ward_ticks > 0 and seen_mi.skills.ward_ticks > 0, "the paladin's machine draws both shields (%d, %d; host %d, %d; events %d)" % [
		seen_ar.skills.ward_ticks, seen_mi.skills.ward_ticks, am.player.skills.ward_ticks, mm.player.skills.ward_ticks,
		skill_events_of(pl, NetProtocol.ShotEvent.Kind.WARD).size()])
	am.player.take_hit(Config.PLAYER_HP_MAX * 4)
	am.player.vitals.life_ticks = Config.DOWN_TICKS - 2
	tick_until(r, func() -> bool: return am.player.vitals.life == Vitals.Life.DEAD, 30)
	_tick(r, 12)
	draw_all(r)
	check(seen_ar.skills.ward_ticks == 0 and not pl.s.client.combat.wards.has(am.slot),
		"the archer died: his shield is erased on the paladin's machine")
	mi.ticking = false
	r.host.on_peer_disconnected(103)
	_tick(r, 4)
	draw_all(r)
	check(not pl.s.members.has(mm.slot) and not pl.s.client.combat.wards.has(mm.slot), "the miner left: his ward went with him")
	_free_rig(r)


## With Config.THROW_HERBALIST_ONLY off a paladin's crafted THROW is still refused on the host (his key 1 is his taunt), and his
## taunt's cooldown is untouched.
func _check_throw_switch_host() -> void:
	var r: Rig = _rig(ARCHER)
	await await_frames(1)
	var base: Vector2 = Arena.spawn_feet(south_of_altar(r, 2))
	var pc: Client = await _join_quiet(r, 101, PALADIN, base)
	var pm: NetMember = hm(r, pc)
	give(pm, HEALING, 1)
	var ps: int = slot_of(pm.player.inventory, HEALING)
	pm.player.skills.start_cooldown(Skills.Slot.IDENTITY, 200)
	Potions.herbalist_only = false
	skill_frame(r, pm, _throw(Config.MAP_SURFACE, beside(pm), ps, base + Vector2(20, 0)))
	Potions.herbalist_only = Config.THROW_HERBALIST_ONLY
	check(pm.refused(Skills.WHY_NO_SKILL) == 1 and pm.player.action_anim < 0 and pm.player.inventory.count_of(HEALING) == 1
		and pm.player.skills.cooldown(Skills.Slot.IDENTITY) >= 198,
		"switch off: a paladin's THROW refused (no skill in that slot), the potion kept, his taunt's cooldown untouched (%d)" % (
		pm.player.skills.cooldown(Skills.Slot.IDENTITY)))
	_free_rig(r)
