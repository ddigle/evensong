extends "res://tests/test_net_combat.gd"
## M6b: potions and crafting in sessions, in one process: the real SessionHost and SessionClient flows on the rig
## of tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients' packets back,
## an optional fixed one-way delay). tests/test_net_brew.gd runs real sessions.
##   - the wire (protocol v6): THROW and CRAFT requests, the effects block after the vitals, the heretic's poison
##     flag, a thrown potion's thrown / broke events; round trips, every field out of range and every truncation
##   - the host against a malicious client: a craft far from a station, with missing inputs, locked, with no
##     room, a herbalist-only recipe as another class, another map, while down, spam (rate), an unknown recipe;
##     a throw too far (clamped from where the host has the thrower), into a wall, while down, spam (one throw,
##     one potion), by a paladin, of a sword, out of reach; a drink at full HP, spam, while down; the alchemy
##     table on a body and beside one
##   - flows: a herbalist client poisons a heretic to death (both see the poison, the bottles, the splash and the
##     death; the host counts the kill for the client); a host herbalist heals a hurt client, buffs it (its walk
##     predicted at the buffed speed), and a healing splash does not get a downed client up
##     (Config.THROW_HEAL_REVIVES off); a client crafts at the table the host placed (welcome snapshot, edits);
##     a late joiner sees the poisoned heretic, the buffed player and the bottle in the air; a map entry carries a
##     table on that map; four players with a delay; offline = host = prediction with real drink and throw frames

const HERB: String = "herbalist"


func run() -> Array[String]:
	_check_codec()
	await _check_craft_requests()
	await _check_throw_requests()
	await _check_poison_kill()
	await _check_heal_and_buff()
	await _check_client_crafts()
	await _check_late_join_effects()
	await _check_four_potions()
	await _check_shared_sim_frames()
	await _check_session_ui()
	await _measure_idle_effects()
	return failures


# --- helpers -----------------------------------------------------------------------------------------

## The seed-1 surface around the altar: the tile `dy` tiles south of the altar's centre tile.
static func south_of_altar(r: Rig, dy: int) -> Vector2i:
	return Aim.cell_of(r.surface.data.altar_center_px()) + Vector2i(0, dy)


## Items into member `m`'s inventory on the host (its owner gets the inventory after the tick).
static func give(m: NetMember, id: StringName, count: int, grade: int = -1) -> int:
	var before: int = m.player.inventory.count_of(id)
	m.player.inventory.add(id, count, grade)
	m.inventory_dirty = true
	return m.player.inventory.count_of(id) - before


## The first slot holding `id` (-1 = none).
static func slot_of(inv: Inventory, id: StringName, grade: int = -1) -> int:
	for i: int in inv.size():
		var st: ItemStack = inv.stack_at(i)
		if st != null and st.id == id and (grade < 0 or st.grade == grade):
			return i
	return -1


static func _throw(map: int, cell: Vector2i, slot: int, to: Vector2) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.THROW, map, cell, slot)
	f.throw_to = to
	f.aim = 64
	return f


static func _craft(map: int, recipe: StringName) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	f.op = NetProtocol.Op.CRAFT
	f.map = map
	f.recipe = Crafting.index_of(recipe)
	return f


## Member `m`'s frame `f` on the host, then the arena of its map one tick (flasks fly there), like a host tick for
## a quiet client.
func host_frame(r: Rig, m: NetMember, f: NetProtocol.InputFrame) -> void:
	r.s.tick += 1
	var a: Arena = r.host.arenas[m.map_id]
	a.now = r.s.tick
	m.player.begin_tick()
	r.host.run_frame(m, f)
	a.step(r.host.players_on(m.map_id))
	a.shot_events.clear()
	a.hits.clear()


## A throw aimed at ground point `at` this tick (the skill key with the mouse there), for the host's own player or
## a client (its action).
static func throw_at(at: Vector2) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = at
	a.aiming = true
	a.skill = true
	return a


## A click with the mouse at `at` (a drink with a potion selected, a placement with the table).
static func click_at(at: Vector2) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = at
	a.aiming = true
	a.use_pressed = true
	return a


## One tick of the rig with the host's action `ha` and client `c`'s action `ca` (each for that tick only).
func press(r: Rig, ha: NetBot.Action, c: Client = null, ca: NetBot.Action = null) -> void:
	r.action = ha
	if c != null:
		c.action = ca
	_tick(r)
	r.action = null
	if c != null:
		c.action = null


## Ticks until `cond` holds (at most `limit`); returns the ticks it took (limit when it never did).
func tick_until(r: Rig, cond: Callable, limit: int) -> int:
	var t: int = 0
	while not cond.call() and t < limit:
		_tick(r)
		t += 1
	return t


## Alchemy tables world `w` draws (FixtureView nodes of a table footprint).
static func tables_drawn(w: GameWorld) -> int:
	var n: int = 0
	for anchor: Vector2i in w.fixtures.nodes:
		var node: Node2D = w.fixtures.nodes[anchor]
		if is_instance_valid(node) and node.has_meta(&"table_rect"):
			n += 1
	return n


## A prediction's vitals `p` and the host's `h`: the same HP and life, the same buff and poison (the prediction runs
## up to `slack` frames ahead of the host's last state, so their time left may be that much shorter).
static func effects_close(p: Vitals, h: Vitals, slack: int) -> bool:
	return p.hp == h.hp and p.life == h.life and p.buff_pct == h.buff_pct and p.poison_damage == h.poison_damage 		and p.buff_ticks <= h.buff_ticks and h.buff_ticks - p.buff_ticks <= slack and p.poison_ticks <= h.poison_ticks 		and h.poison_ticks - p.poison_ticks <= slack


## Ticks until player `p` plays no action (a throw finished).
func wait_free(r: Rig, p: Player) -> void:
	tick_until(r, func() -> bool: return p.action_anim < 0, 120)


## The flask track `id` of client `c` (null when it has none).
static func track(c: Client, id: int) -> NetCombat.FlaskTrack:
	var raw: Variant = c.s.client.combat.flasks.get(id, null)
	if raw == null:
		return null
	var tr: NetCombat.FlaskTrack = raw
	return tr


## The flask events client `c` got, of kind `kind`.
static func flask_events(c: Client, kind: int) -> int:
	var n: int = 0
	for e: NetProtocol.ShotEvent in c.shot_events:
		if e.kind == kind:
			n += 1
	return n


# --- the wire -----------------------------------------------------------------------------------------

func _check_codec() -> void:
	# THROW and CRAFT ride on frames like the other requests.
	var frames: Array[NetProtocol.InputFrame] = [NetProtocol.InputFrame.new(10, Vector2i(1, 0)),
		NetProtocol.InputFrame.new(11, Vector2i.ZERO), NetProtocol.InputFrame.new(12, Vector2i(0, -1))]
	frames[0].op = NetProtocol.Op.THROW
	frames[0].map = Config.MAP_DUNGEON
	frames[0].slot = 2
	frames[0].cell = Vector2i(40, -1)
	frames[0].aim = 201
	frames[0].throw_to = Vector2(700.4, -3.6)
	frames[2].op = NetProtocol.Op.CRAFT
	frames[2].recipe = Crafting.recipe_count() - 1
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 3 + 1 + (2 + 11) + (2 + 2), "a THROW is 11 B, a CRAFT 2 B (with the map)")
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 3 and p.frames[0].op == NetProtocol.Op.THROW and p.frames[0].slot == 2
		and p.frames[0].cell == Vector2i(40, -1) and p.frames[0].aim == 201 and p.frames[0].map == Config.MAP_DUNGEON
		and p.frames[0].throw_to == Vector2(700, -4), "a THROW round trips (the point in whole px: %s)" % (
		p.frames[0].throw_to if p.ok else Vector2.INF))
	check(p.ok and p.frames[2].op == NetProtocol.Op.CRAFT and p.frames[2].recipe == Crafting.recipe_count() - 1
		and p.frames[2].map == Config.MAP_SURFACE and p.frames[1].op == NetProtocol.Op.NONE, "a CRAFT round trips")
	check(NetProtocol.op_has_map(NetProtocol.Op.THROW) and NetProtocol.op_has_map(NetProtocol.Op.CRAFT),
		"both name the map they were made on (\"wrong map\" on any other)")
	var at: int = NetProtocol.INPUT_HEADER + 3 + 1
	var cases: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = bytes.duplicate()
	b[at + 3] = Config.HOTBAR_SLOTS  # throw: slot after its map byte
	cases["throw from a slot outside the hotbar"] = b
	b = bytes.duplicate()
	b[at + 2] = Config.MAP_COUNT
	cases["throw on an unknown map"] = b
	b = bytes.duplicate()
	b[bytes.size() - 1] = Crafting.recipe_count()
	cases["craft: no such recipe"] = b
	b = bytes.duplicate()
	b[bytes.size() - 2] = Config.MAP_COUNT
	cases["craft on an unknown map"] = b
	b = bytes.duplicate()
	b.remove_at(at + 2 + 10)  # a THROW one byte short (the next op's bytes shift)
	cases["a short THROW"] = b
	for label: String in cases:
		check(not NetProtocol.decode_inputs(cases[label]).ok, "input packet refused: %s" % label)
	var short_ok: int = 0
	for n: int in range(NetProtocol.INPUT_HEADER + 3 + 1, bytes.size()):
		if NetProtocol.decode_inputs(bytes.slice(0, n)).ok:
			short_ok += 1
	check_eq(short_ok, 0, "every truncated THROW / CRAFT section is refused")
	_check_effects_codec()
	_check_poison_flag_codec()
	_check_flask_codec()


## The effects block: only while a buff or a poison runs; 17 / 33 / 40 B states; every field, an empty block and
## every truncation refused; an info and a map entry carry it.
func _check_effects_codec() -> void:
	var states: Array[NetProtocol.PlayerState] = []
	for i: int in 4:
		var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
		st.slot = i
		st.pos = Vector2(100.25 + i, 200.5)
		states.append(st)
	var hurt: Vitals = Vitals.new()
	hurt.hp = 50
	var both: Vitals = Vitals.new()
	both.hp = 80
	both.buff_pct = Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE]
	both.buff_ticks = Config.BUFF_TICKS[ItemDB.Grade.FINE] - 1
	both.poison_damage = Config.POISON_DAMAGE[ItemDB.Grade.FINE]
	both.poison_ticks = Config.POISON_TICKS[ItemDB.Grade.FINE] - 1
	both.poison_timer = Config.POISON_INTERVAL_TICKS
	var buffed: Vitals = Vitals.new()
	buffed.buff_pct = Config.BUFF_SPEED_PCT[ItemDB.Grade.COMMON]
	buffed.buff_ticks = 7
	check(not buffed.at_rest() and not buffed.idle() and buffed.has_effects(), "a buffed player at full HP is not at rest (M6b)")
	states[1].vitals = hurt
	states[2].vitals = both
	states[3].vitals = buffed
	check_eq([NetProtocol.state_size(states[0]), NetProtocol.state_size(states[1]), NetProtocol.state_size(states[2]),
		NetProtocol.state_size(states[3])], [17, 33, 40, 40], "states: at rest 17 B, hurt 33 B, with effects 40 B")
	var bytes: PackedByteArray = NetProtocol.encode_states(9, states)
	var back: NetProtocol.StateBatch = NetProtocol.decode_states(bytes)
	check(back.ok and back.states.size() == 4 and back.states[0].vitals == null and back.states[1].vitals.same_wire(hurt)
		and back.states[2].vitals.same_wire(both) and back.states[3].vitals.same_wire(buffed) and back.states[2].same_as(states[2]),
		"the effects round trip field for field")
	var e: int = NetProtocol.STATE_HEADER + 17 + 33 + 17 + NetProtocol.VITALS_SIZE  # the second effects block (states[2])
	var max_pct: int = Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE]
	var limits: Array[Array] = [[0, max_pct + 1, "buff percent"], [0, 99, "buff under 100 %"], [3, Config.POISON_DAMAGE[2] + 1,
		"poison damage"], [6, Config.POISON_INTERVAL_TICKS + 1, "poison timer"]]
	for lim: Array in limits:
		var bad: PackedByteArray = bytes.duplicate()
		var off: int = lim[0]
		var v: int = lim[1]
		bad[e + off] = v
		check(not NetProtocol.decode_states(bad).ok, "effects refused: %s" % lim[2])
	var long_buff: PackedByteArray = bytes.duplicate()
	long_buff.encode_u16(e + 1, Config.BUFF_TICKS[ItemDB.Grade.FINE] + 1)
	check(not NetProtocol.decode_states(long_buff).ok, "effects refused: buff longer than any")
	var long_poison: PackedByteArray = bytes.duplicate()
	long_poison.encode_u16(e + 4, Config.POISON_TICKS[ItemDB.Grade.FINE] + 1)
	check(not NetProtocol.decode_states(long_poison).ok, "effects refused: poison longer than any")
	var empty: PackedByteArray = bytes.duplicate()
	empty[e] = 100
	for k: int in range(1, NetProtocol.EFFECTS_SIZE):
		empty[e + k] = 0
	check(not NetProtocol.decode_states(empty).ok, "a flagged effects block with no effect (never sent) is refused")
	var short_ok: int = 0
	for n: int in range(NetProtocol.STATE_HEADER, bytes.size()):
		if NetProtocol.decode_states(bytes.slice(0, n)).ok:
			short_ok += 1
	check_eq(short_ok, 0, "every truncated batch with effects blocks is refused")
	var info: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
	info.class_index = 4
	info.state = states[2]
	var ib: PackedByteArray = NetProtocol.encode_info(info)
	var ib_back: NetProtocol.PlayerInfo = NetProtocol.decode_info(ib)
	check(ib.size() == 41 and ib_back != null and ib_back.state.same_as(states[2]) and NetProtocol.info_size_at(ib, 0) == 41,
		"an info with effects is 41 B and round trips (a late joiner sees them)")
	var me: NetProtocol.MapEntry = NetProtocol.MapEntry.new()
	me.map = Config.MAP_DUNGEON
	me.packed_size = 300
	me.chunk_count = 1
	me.state = states[3]
	me.state.map = Config.MAP_DUNGEON
	var mb: PackedByteArray = NetProtocol.encode_map_entry(me)
	var mback: NetProtocol.MapEntry = NetProtocol.decode_map_entry(mb)
	check(mb.size() == NetProtocol.MAP_ENTRY_SIZE + NetProtocol.VITALS_SIZE + NetProtocol.EFFECTS_SIZE and mback.ok
		and mback.state.same_as(me.state), "a map entry carries the entering player's effects")
	check(Config.BUFF_TICKS[ItemDB.Grade.FINE] <= 65535 and Config.POISON_TICKS[ItemDB.Grade.FINE] <= 65535
		and max_pct <= 255 and Config.POISON_DAMAGE[ItemDB.Grade.FINE] <= 255, "the effects fit their fields")


func _check_poison_flag_codec() -> void:
	var list: Array[NetProtocol.EnemyState] = []
	for i: int in 3:
		var h: HereticSim = HereticSim.new()
		h.id = 50 + i
		h.pos = Vector2(10.5 * i, 20.25)
		h.poison_ticks = 120 if i != 1 else 0
		h.state = HereticSim.State.DEAD if i == 2 else HereticSim.State.IDLE
		list.append(NetProtocol.enemy_of(h, 1000))
	check(list[0].poisoned and not list[1].poisoned and not list[2].poisoned, "poisoned: alive and poisoned only (a corpse is not)")
	var bytes: PackedByteArray = NetProtocol.encode_enemies(1000, Config.MAP_SURFACE, 0, list)
	check_eq(bytes.size(), NetProtocol.ENEMY_HEADER + NetProtocol.ENEMY_SIZE * 3, "the poison costs no byte (flags bit 6)")
	var b: NetProtocol.EnemyBatch = NetProtocol.decode_enemies(bytes)
	check(b.ok and b.enemies[0].poisoned and not b.enemies[1].poisoned and b.enemies[0].same_as(list[0]), "the poison flag round trips")
	var bad: PackedByteArray = bytes.duplicate()
	bad[NetProtocol.ENEMY_HEADER + 2 * NetProtocol.ENEMY_SIZE + 12] |= NetProtocol.ENEMY_POISONED
	check(not NetProtocol.decode_enemies(bad).ok, "a poisoned corpse (never sent) is refused")


func _check_flask_codec() -> void:
	var t: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	t.kind = NetProtocol.ShotEvent.Kind.THROW
	t.id = 77
	t.item = &"potion_poison"
	t.owner = 2
	t.tick = 9000
	t.pos = Vector2(1016.5, 851.25)
	t.target = t.pos + Vector2(0, Config.THROW_RANGE_PX)
	var sp: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
	sp.kind = NetProtocol.ShotEvent.Kind.SPLASH
	sp.id = 77
	sp.item = &"potion_poison"
	sp.tick = 9030
	sp.pos = Vector2(1016.5, 900.0)
	sp.why = NetProtocol.FLASK_STOPS.find("wall")
	var bytes: PackedByteArray = NetProtocol.encode_shots(Config.MAP_SURFACE, [t, sp] as Array[NetProtocol.ShotEvent])
	check_eq(bytes.size(), 2 + NetProtocol.FLASK_THROW_SIZE + NetProtocol.FLASK_SPLASH_SIZE, "flask events: 2 B + 27 B thrown + 19 B broke")
	var back: NetProtocol.ShotEvents = NetProtocol.decode_shots(bytes)
	check(back.ok and back.events.size() == 2 and back.events[0].same_as(t) and back.events[1].same_as(sp), "flask events round trip")
	var cases: Dictionary[String, PackedByteArray] = {}
	var c: PackedByteArray = bytes.duplicate()
	c[2 + 5] = ItemDB.index_of(&"bow")
	cases["a thrown bow"] = c
	c = bytes.duplicate()
	c[2 + NetProtocol.FLASK_THROW_SIZE + 5] = ItemDB.index_of(&"sword")
	cases["a broken sword"] = c
	c = bytes.duplicate()
	c.encode_float(2 + 23, t.pos.y + Config.THROW_RANGE_PX + 8.0)
	cases["thrown farther than the range"] = c
	c = bytes.duplicate()
	c.encode_float(2 + 19, NAN)
	cases["a NaN target"] = c
	c = bytes.duplicate()
	c[bytes.size() - 1] = NetProtocol.FLASK_STOPS.size()
	cases["unknown break reason"] = c
	c = bytes.duplicate()
	c[2] = 4
	cases["unknown kind"] = c
	for label: String in cases:
		check(not NetProtocol.decode_shots(cases[label]).ok, "flask events refused: %s" % label)
	var short_ok: int = 0
	for n: int in range(2, bytes.size()):
		if NetProtocol.decode_shots(bytes.slice(0, n)).ok:
			short_ok += 1
	check_eq(short_ok, 0, "every truncated flask event is refused")


# --- the host against a malicious client: crafting ------------------------------------------------------

## The table placed by the host's own frame; CRAFT requests handed straight to run_frame (no wire).
func _check_craft_requests() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var hostm: NetMember = r.s.local
	var table_tile: Vector2i = south_of_altar(r, 4)
	hostm.player.teleport(_feet(table_tile + Vector2i(0, -1)))
	give(hostm, &"alchemy_table", 2)
	var tslot: int = slot_of(hostm.player.inventory, &"alchemy_table")
	var pal: Client = await _join_quiet(r, 101, "paladin", _feet(table_tile + Vector2i(-1, 0)))
	var mp: NetMember = hm(r, pal)
	# The table on the paladin's feet is refused; beside him it stands (three edits on the surface's log).
	host_frame(r, hostm, _use(Config.MAP_SURFACE, table_tile, tslot, 0))
	check_eq(hostm.refused(WorldItems.WHY_BODY), 1, "the table over another player's feet: refused (%s)" % hostm.ops_refused)
	mp.player.teleport(_feet(table_tile + Vector2i(-2, 1)))
	for i: int in Config.NET_OP_INTERVAL_TICKS:
		hostm.refill_ops()
	var log_before: int = r.s.log_for(Config.MAP_SURFACE).size()
	host_frame(r, hostm, _use(Config.MAP_SURFACE, table_tile, tslot, 0))
	var rects: Array[Rect2i] = r.surface.data.footprints(WorldData.PLACEABLE_ALCHEMY)
	check(rects.size() == 1 and rects[0] == WorldItems.place_rect(WorldData.PLACEABLE_ALCHEMY, table_tile),
		"the host placed the table in the session (%s)" % [rects])
	check_eq(r.s.log_for(Config.MAP_SURFACE).size() - log_before, 3, "three numbered edits on the surface")
	check_eq(hostm.player.inventory.count_of(&"alchemy_table"), 1, "one table used")
	# A paladin with herbs.
	give(mp, &"wild_healing", 2)
	give(mp, &"wild_poison", 2)
	var refill: Callable = func() -> void:
		for i: int in Config.NET_OP_INTERVAL_TICKS * Config.NET_OP_BURST:
			mp.refill_ops()
	# Far from the table: no station (the host measures from where it has the player, 6 tiles off).
	mp.player.teleport(_feet(table_tile + Vector2i(0, 7)))
	host_frame(r, mp, _craft(Config.MAP_SURFACE, &"potion_healing_common"))
	check_eq(mp.refused(Crafting.WHY_NO_STATION), 1, "a craft 6 tiles from the table: no station")
	check_eq(mp.player.inventory.count_of(&"wild_healing"), 2, "nothing used")
	mp.player.teleport(_feet(table_tile + Vector2i(0, Config.STATION_REACH_TILES)))
	refill.call()
	host_frame(r, mp, _craft(Config.MAP_SURFACE, &"potion_poison_common"))
	check_eq(mp.refused(Crafting.WHY_CLASS), 1, "the poison potion as a paladin: herbalist only (● §3.0)")
	host_frame(r, mp, _craft(Config.MAP_SURFACE, &"potion_healing_fine"))
	check_eq(mp.refused(Crafting.WHY_CLASS), 2, "a FINE potion as a paladin: herbalist only (● §3.0)")
	host_frame(r, mp, _craft(Config.MAP_SURFACE, &"potion_buff_common"))
	check_eq(mp.refused(Crafting.WHY_LOCKED), 1, "the buff potion with no buff herb ever had: locked")
	host_frame(r, mp, _craft(Config.MAP_DUNGEON, &"potion_healing_common"))
	check_eq(mp.refused(WorldItems.WHY_WRONG_MAP), 1, "a craft naming the dungeon from the surface: wrong map")
	refill.call()
	var bogus: NetProtocol.InputFrame = _craft(Config.MAP_SURFACE, &"potion_healing_common")
	bogus.recipe = 200  # past the decoder (which refuses it): the host's own check
	host_frame(r, mp, bogus)
	check_eq(mp.refused(Crafting.WHY_BAD_RECIPE), 1, "recipe 200: no such recipe")
	# Spam: ten crafts in one tick: the budget takes four, six are "rate"; the inputs make one potion.
	refill.call()
	var rate_before: int = mp.refused("rate")
	r.s.tick += 1
	for i: int in 10:
		r.host.run_frame(mp, _craft(Config.MAP_SURFACE, &"potion_healing_common"))
	check_eq(mp.refused("rate") - rate_before, 6, "ten crafts in one tick: six over the request rate")
	check_eq(mp.player.inventory.count_of(&"potion_healing"), 1, "one potion from two herbs (the rest: missing inputs)")
	check_eq(mp.refused(Crafting.WHY_MISSING), 3, "the other three: missing inputs")
	check_eq(mp.player.inventory.count_of(&"wild_healing"), 0, "both herbs used")
	check(mp.inventory_dirty, "its owner gets the inventory")
	# Down: refused before anything is checked.
	refill.call()
	give(mp, &"wild_healing", 2)
	mp.player.take_hit(Config.PLAYER_HP_MAX)
	host_frame(r, mp, _craft(Config.MAP_SURFACE, &"potion_healing_common"))
	check_eq(mp.refused(SessionHost.WHY_DOWN), 1, "a craft while down: down")
	mp.player.revive_now()
	# No room: a full inventory whose herb stack stays (four herbs, two used).
	var herb: Client = await _join_quiet(r, 102, HERB, _feet(table_tile + Vector2i(2, 1)))
	var mh: NetMember = hm(r, herb)
	give(mh, &"wild_buff", 4)
	var fill: Array[StringName] = [&"stone_a", &"stone_b", &"stone_c", &"stone_mossy", &"mushroom_a", &"mushroom_b",
		&"mushroom_c", &"mushroom_d", &"mushroom_ash", &"herb_clump", &"stone_block", &"ore_copper", &"ore_iron", &"torch",
		&"pickaxe", &"hoe", &"watering_can", &"sword", &"bow", &"holy_light", &"stone_veined", &"stone_mould"]
	for id: StringName in fill:
		if mh.player.inventory.room_for(id, -1) > 0:
			mh.player.inventory.add(id, 1)
	check_eq(mh.player.inventory.room_for(&"potion_buff", ItemDB.Grade.COMMON), 0, "the herbalist's inventory is full")
	for i: int in Config.NET_OP_INTERVAL_TICKS * Config.NET_OP_BURST:
		mh.refill_ops()
	host_frame(r, mh, _craft(Config.MAP_SURFACE, &"potion_buff_common"))
	check_eq(mh.refused(Crafting.WHY_NO_ROOM), 1, "no room for the potion: refused (%s)" % mh.ops_refused)
	check_eq(mh.player.inventory.count_of(&"wild_buff"), 4, "all or nothing: the herbs stay")
	# The herbalist brews the poison potion the paladin may not.
	mh.player.inventory.remove(slot_of(mh.player.inventory, &"stone_a"), 1)
	give(mh, &"wild_poison", 2)
	host_frame(r, mh, _craft(Config.MAP_SURFACE, &"potion_poison_common"))
	var crafted: int = mh.ops_done.get("craft", 0)
	check(mh.player.inventory.count_of(&"potion_poison") == 1 and crafted == 1,
		"the herbalist brews the poison potion at the table (%s)" % mh.ops_refused)
	_free_rig(r)


# --- the host against a malicious client: throwing and drinking ------------------------------------------

func _check_throw_requests() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var spot_tile: Vector2i = south_of_altar(r, 14)
	var hb: Client = await _join_quiet(r, 101, HERB, _feet(spot_tile))
	var m: NetMember = hm(r, hb)
	give(m, &"potion_poison", 6, ItemDB.Grade.FINE)
	var pslot: int = slot_of(m.player.inventory, &"potion_poison")
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var throw_ticks: int = PlayerSim.action_ticks(RigData.Anim.THROW)
	var feet: Vector2 = m.player.sim_position
	var below: Vector2i = Aim.feet_cell(feet) + Vector2i(0, 1)
	# Too far: a point 400 px off is clamped to the range from where the host has the thrower.
	var flasks_before: int = arena.stat("throws")
	host_frame(r, m, _throw(Config.MAP_SURFACE, below, pslot, feet + Vector2(0, 400)))
	var flask: Arena.Flask = null
	for i: int in throw_ticks:
		host_frame(r, m, NetProtocol.InputFrame.new())
		if flask == null and not arena.flasks.is_empty():
			flask = arena.flasks.back()
	check(arena.stat("throws") - flasks_before == 1 and flask != null, "one bottle thrown")
	if flask != null:
		check(absf(flask.origin.distance_to(flask.target) - Config.THROW_RANGE_PX) < 0.01 and flask.target.y > flask.origin.y
			and absf(flask.target.x - flask.origin.x) < 0.01, "thrown 400 px off: it lands %.2f px away (THROW_RANGE_PX, from the host's thrower)" % [
			flask.origin.distance_to(flask.target)])
	check_eq(m.player.inventory.count_of(&"potion_poison"), 5, "one potion used, on the release frame")
	for i: int in 40:
		host_frame(r, m, NetProtocol.InputFrame.new())
	# Spam: a THROW on each of 40 frames: one throw (the action lasts THROW frames), the rest busy, one potion.
	var busy_before: int = m.refused(SessionHost.WHY_BUSY)
	var used_before: int = m.player.inventory.count_of(&"potion_poison")
	var thrown_before: int = arena.stat("throws")
	for i: int in 40:
		host_frame(r, m, _throw(Config.MAP_SURFACE, below, pslot, feet + Vector2(0, 50)))
	for i: int in throw_ticks:
		host_frame(r, m, NetProtocol.InputFrame.new())
	check_eq(arena.stat("throws") - thrown_before, 1, "40 THROWs in 40 frames: one bottle (one per %d-frame throw)" % throw_ticks)
	check_eq(m.refused(SessionHost.WHY_BUSY) - busy_before, 39, "the other 39 busy")
	check_eq(used_before - m.player.inventory.count_of(&"potion_poison"), 1, "and one potion used")
	# Out of reach (the tile sets the facing; a far one is refused like a use's), a sword, another map.
	host_frame(r, m, _throw(Config.MAP_SURFACE, below + Vector2i(0, 3), pslot, feet + Vector2(0, 50)))
	check_eq(m.refused(WorldItems.WHY_REACH), 1, "a throw aimed with a tile 4 tiles off: out of reach")
	host_frame(r, m, _throw(Config.MAP_SURFACE, below, WEAPON_SLOT, feet + Vector2(0, 50)))
	check_eq(m.refused(Potions.WHY_NOT_POTION), 1, "the sickle (hotbar 8): not a potion")
	host_frame(r, m, _throw(Config.MAP_DUNGEON, below, pslot, feet + Vector2(0, 50)))
	check_eq(m.refused(WorldItems.WHY_WRONG_MAP), 1, "a throw naming the dungeon: wrong map")
	# A paladin may not throw (the herbalist's skill, Config.THROW_HERBALIST_ONLY).
	var pal: Client = await _join_quiet(r, 102, "paladin", _feet(spot_tile + Vector2i(4, 0)))
	var mp: NetMember = hm(r, pal)
	give(mp, &"potion_healing", 2)
	var pal_slot: int = slot_of(mp.player.inventory, &"potion_healing")
	host_frame(r, mp, _throw(Config.MAP_SURFACE, Aim.feet_cell(mp.player.sim_position) + Vector2i(0, 1), pal_slot,
		mp.player.sim_position + Vector2(0, 40)))
	check(mp.refused(Potions.WHY_HERBALIST) == 1 and mp.player.action_anim == -1, "a paladin's THROW: herbalist only, no action")
	# Drinking: full HP refused (nothing used), spam = one drink, the heal on the effect frame.
	var dcell: Vector2i = Aim.feet_cell(mp.player.sim_position) + Vector2i(0, 1)
	host_frame(r, mp, _use(Config.MAP_SURFACE, dcell, pal_slot, 64))
	check(mp.refused(Potions.WHY_FULL_HP) == 1 and mp.player.inventory.count_of(&"potion_healing") == 2,
		"a drink at full HP: refused, nothing used")
	mp.player.vitals.hp = 40
	var drink_ticks: int = PlayerSim.action_ticks(Config.DRINK_ANIM)
	var dbusy: int = mp.refused(SessionHost.WHY_BUSY)
	for i: int in drink_ticks:
		host_frame(r, mp, _use(Config.MAP_SURFACE, dcell, pal_slot, 64))
	check(mp.refused(SessionHost.WHY_BUSY) - dbusy == drink_ticks - 1 and mp.player.vitals.hp == 40 + Config.POTION_HEAL_HP[1]
		and mp.player.inventory.count_of(&"potion_healing") == 1, "a drink on each of %d frames: one drink (+%d HP, one potion), the rest busy" % [
		drink_ticks, Config.POTION_HEAL_HP[1]])
	# Down: a throw and a drink are refused.
	for i: int in 4:
		host_frame(r, m, NetProtocol.InputFrame.new())
	m.player.take_hit(Config.PLAYER_HP_MAX)
	mp.player.take_hit(Config.PLAYER_HP_MAX)
	var down_m: int = m.refused(SessionHost.WHY_DOWN)
	var down_p: int = mp.refused(SessionHost.WHY_DOWN)
	host_frame(r, m, _throw(Config.MAP_SURFACE, below, pslot, feet + Vector2(0, 50)))
	host_frame(r, mp, _use(Config.MAP_SURFACE, dcell, pal_slot, 64))
	check(m.refused(SessionHost.WHY_DOWN) - down_m == 1 and mp.refused(SessionHost.WHY_DOWN) - down_p == 1
		and m.player.action_anim == -1 and mp.player.action_anim == -1, "down: a throw and a drink are refused (\"down\")")
	# Into a wall (the dungeon): the bottle breaks before the wall; a heretic behind it is not poisoned.
	m.player.revive_now()
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	var d: WorldData = r.dungeon.data
	var darena: Arena = r.host.arenas[Config.MAP_DUNGEON]
	var wall_feet: Vector2 = m.player.sim_position
	var up: int = 0
	while up < 10 and not Walls.blocks(d, Aim.feet_cell(wall_feet) + Vector2i(0, -1)):
		wall_feet.y -= Config.TILE
		up += 1
	m.player.teleport(wall_feet)
	var behind: HereticSim = darena.spawn_heretic(wall_feet + Vector2(0, -48))
	for i: int in 30:
		host_frame(r, m, NetProtocol.InputFrame.new())
	var wall_splashes: int = darena.stat("splashes")
	host_frame(r, m, _throw(Config.MAP_DUNGEON, Aim.feet_cell(wall_feet) + Vector2i(1, 0), pslot,
		Combat.body_point(behind.pos)))
	var broke: Arena.Splash = null
	for i: int in throw_ticks + 30:
		host_frame(r, m, NetProtocol.InputFrame.new())
		if broke == null and not darena.splashes.is_empty():
			broke = darena.splashes.back()
	check(darena.stat("splashes") - wall_splashes == 1 and broke != null and broke.why == "wall",
		"thrown at a heretic behind the dungeon wall: it broke on the wall (%s)" % (broke.why if broke != null else "none"))
	if broke != null:
		check(broke.pos.y > wall_feet.y - Config.TILE - Config.FEET_HEIGHT and broke.heretics == 0 and not behind.poisoned(),
			"before the wall (at y %.1f, feet %.1f); the heretic behind it is not poisoned" % [broke.pos.y, wall_feet.y])
	_free_rig(r)


# --- flows ---------------------------------------------------------------------------------------------

## A herbalist client inside the light throws poison at a heretic outside it, twice (FINE: 30 HP each, the
## heretic has 40): the heretic dies of the poison. The client drew its bottles where the host had them each tick,
## saw the poison and the splash, saw the heretic die; the host counted the kill for the client.
func _check_poison_kill() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(Arena.spawn_feet(south_of_altar(r, 10)))
	var c: Client = _join(r, 101, HERB, Arena.spawn_feet(south_of_altar(r, 6)), false)
	var m: NetMember = hm(r, c)
	give(m, &"potion_poison", 3, ItemDB.Grade.FINE)
	_tick(r, 2)
	var slot: int = slot_of(c.s.local.player.inventory, &"potion_poison")
	check(slot >= 0, "the client got its potions from the host (slot %d)" % slot)
	press(r, null, c, _select(slot))
	var flask_ticks: int = 0
	var flask_mismatch: int = 0
	var drawn_flask: int = 0
	var drawn_splash: int = 0
	var marked: int = 0
	for throw: int in 2:
		press(r, null, c, throw_at(Combat.body_point(h.pos)))
		var t: int = 0
		while (throw == 0 and (h.poison_ticks > 0 or not arena.flasks.is_empty() or t < 30)) or (throw == 1 and h.alive() and t < 600):
			_tick(r)
			t += 1
			for f: Arena.Flask in arena.flasks:
				flask_ticks += 1
				var tr: NetCombat.FlaskTrack = track(c, f.id)
				if tr == null or tr.pos_at(float(r.s.tick)) != f.pos:
					flask_mismatch += 1
			c.s.client.combat.sample(float(r.s.tick), SessionClient.interp_delay_ticks())
			drawn_flask += c.s.client.combat.arena.flasks.size()
			drawn_splash += c.s.client.combat.arena.splashes.size()
			c.s.client.combat_view.sync([] as Array[Player])
			var node: Heretic = c.s.client.combat_view.heretics.get(h.id, null)
			if node != null and node.marks.shown.has(EffectMarks.Kind.POISON):
				marked += 1
	_tick(r, 30)
	check(not h.alive() and arena.stat("poison_kills") == 1, "two FINE poisons killed the heretic (poison kill %d)" % arena.stat("poison_kills"))
	check_eq(m.combat_count("kills"), 1, "the host counted the kill for the herbalist")
	check_eq(m.combat_count("throws"), 2, "two throws on the host")
	check_eq(c.s.local.player.inventory.count_of(&"potion_poison"), 1, "the client's inventory: one potion left")
	check(flask_ticks > 10 and flask_mismatch == 0, "every tick a bottle flew on the host (%d), the client's track had it at the host's point (%d off)" % [
		flask_ticks, flask_mismatch])
	check(drawn_flask > 10 and drawn_splash > 10, "the client drew the bottles (%d) and the splashes (%d)" % [drawn_flask, drawn_splash])
	check_eq([flask_events(c, NetProtocol.ShotEvent.Kind.THROW), flask_events(c, NetProtocol.ShotEvent.Kind.SPLASH)], [2, 2],
		"the client got two thrown and two broke events")
	var combat: NetCombat = c.s.client.combat
	check(combat.poisoned_seen.has(h.id) and marked > 30, "the client saw the heretic poisoned (%d frames with the mark)" % marked)
	var seen: Array = combat.hp_seen(h.id)
	var last_hp: int = seen.back() if not seen.is_empty() else -1
	check(_follows(seen, host_hp_seq(r, h.id)) and last_hp == 0, "the client saw its HP go %s (host %s) down to 0" % [seen,
		host_hp_seq(r, h.id)])
	check_eq(hp_mismatches(r, c), 0, "every batch decoded to the host's HP at that tick")
	check_prediction("poison kill / herbalist", c)
	_free_rig(r)


## A host herbalist throws healing at a hurt paladin client (it heals: the client's prediction takes it as the
## host's event), then the buff (the client walks at the buffed speed, predicted exactly), then healing at it down:
## it stays down (Config.THROW_HEAL_REVIVES off). A second client sees the buff on the first.
func _check_heal_and_buff() -> void:
	var start: Dictionary[String, int] = {"paladin": 40}
	var r: Rig = _rig(HERB, false, start)
	await await_frames(1)
	var hp: Player = r.s.local.player
	var here: Vector2 = Arena.spawn_feet(south_of_altar(r, 3))
	hp.teleport(here)
	give(r.s.local, &"potion_healing", 3, ItemDB.Grade.FINE)
	give(r.s.local, &"potion_buff", 2, ItemDB.Grade.FINE)
	var c: Client = _join(r, 101, "paladin", here + Vector2(56, 0), false)
	var c2: Client = _join(r, 102, "archer", here + Vector2(-40, 30), false)
	var m: NetMember = hm(r, c)
	check_eq(m.player.vitals.hp, 40, "the paladin starts hurt (--test-start-hp)")
	hp.inventory.select(slot_of(hp.inventory, &"potion_healing"))
	var events_before: int = c.s.client.prediction.event_corrections
	press(r, throw_at(Combat.body_point(m.player.sim_position)))
	var t: int = tick_until(r, func() -> bool: return m.player.vitals.hp > 40, 120)
	_tick(r, 6)
	check(m.player.vitals.hp == 40 + Config.POTION_HEAL_HP[ItemDB.Grade.FINE] and t < 120,
		"the host's thrown FINE healing healed the paladin to %d after %d ticks" % [m.player.vitals.hp, t])
	check_eq(c.s.client.prediction.sim.vit.hp, m.player.vitals.hp, "the client has the host's HP")
	check(c.s.client.prediction.event_corrections > events_before, "a heal by a splash is the host's event for the prediction")
	check_eq(hp.vitals.hp, Config.PLAYER_HP_MAX, "the host was outside the splash (and full anyway)")
	# The buff: thrown at the paladin, who then walks east for a second.
	hp.inventory.select(slot_of(hp.inventory, &"potion_buff"))
	wait_free(r, hp)
	press(r, throw_at(Combat.body_point(m.player.sim_position)))
	tick_until(r, func() -> bool: return m.player.vitals.buffed(), 120)
	_tick(r, 8)
	check(m.player.vitals.buffed() and m.player.vitals.buff_pct == Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE],
		"the paladin is buffed (%d %%)" % m.player.vitals.buff_pct)
	check(effects_close(c.s.client.prediction.sim.vit, m.player.vitals, 6), "the client's prediction has the host's buff (%s / host %s)" % [
		c.s.client.prediction.sim.vit.describe(), m.player.vitals.describe()])
	var on_c2: NetMember = c2.s.members[m.slot]
	check(on_c2.interp.latest() != null and on_c2.interp.latest().vitals != null and on_c2.interp.latest().vitals.buffed(),
		"the other client gets the buff in the paladin's state")
	c2.s.client.draw_others()
	check(on_c2.player.effect_marks.shown == ([EffectMarks.Kind.BUFF] as Array[int]), "and draws its mark (%s)" % [on_c2.player.effect_marks.shown])
	var x0: float = m.player.sim_position.x
	var walk: NetBot.Action = NetBot.Action.new()
	walk.dir = Vector2i(1, 0)
	c.action = walk
	_tick(r, 60)
	c.action = null
	_tick(r, 6)
	var walked: float = m.player.sim_position.x - x0
	var want: float = 60.0 * Config.WALK_SPEED * Config.BUFF_SPEED_PCT[ItemDB.Grade.FINE] / 100.0 / Config.NET_TICK_RATE
	check(absf(walked - want) < 0.5, "it walked %.1f px in a second (buffed %.1f)" % [walked, want])
	check_eq(c.s.local.player.sim_position, m.player.sim_position, "where the host has it")
	# Down: a healing splash does not get it up.
	m.player.take_hit(Config.PLAYER_HP_MAX)
	_tick(r, 4)
	hp.inventory.select(slot_of(hp.inventory, &"potion_healing"))
	wait_free(r, hp)
	hp.teleport(m.player.sim_position + Vector2(-56, 0))
	_tick(r, 2)
	var splashes: int = r.host.arenas[Config.MAP_SURFACE].stat("splashes")
	press(r, throw_at(Combat.body_point(m.player.sim_position)))
	tick_until(r, func() -> bool: return r.host.arenas[Config.MAP_SURFACE].stat("splashes") > splashes, 120)
	_tick(r, 4)
	check(m.player.vitals.life == Vitals.Life.DOWN and m.player.vitals.hp == 0 and not m.player.vitals.has_effects(),
		"thrown healing on the downed paladin: still down at 0 HP (Config.THROW_HEAL_REVIVES off), its buff ended when it went down")
	check_eq(r.host.arenas[Config.MAP_SURFACE].stat("splash_revives"), 0, "no splash revive")
	check_eq(c.s.client.prediction.sim.vit.life, Vitals.Life.DOWN, "the client: down too")
	check_prediction("heal and buff / paladin", c)
	check_prediction("heal and buff / archer", c2)
	_free_rig(r)


## The host places the table before a client joins (the welcome's snapshot has it); a herbalist client crafts there
## through the wire (CRAFT on its frame), the host answers with its inventory; a client far away is refused.
func _check_client_crafts() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var hp: Player = r.s.local.player
	var table_tile: Vector2i = south_of_altar(r, 4)
	hp.teleport(_feet(table_tile + Vector2i(0, -1)))
	give(r.s.local, &"alchemy_table", 1)
	hp.inventory.select(slot_of(hp.inventory, &"alchemy_table"))
	press(r, click_at(Vector2(table_tile * Config.TILE) + Vector2(8, 8)))
	check_eq(r.surface.data.footprints(WorldData.PLACEABLE_ALCHEMY).size(), 1, "the host clicked the table down")
	var c: Client = _join(r, 101, HERB, _feet(table_tile + Vector2i(2, 1)), false)
	var far: Client = _join(r, 102, HERB, _feet(table_tile + Vector2i(0, 9)), false)
	check_eq(c.surface.data.footprints(WorldData.PLACEABLE_ALCHEMY).size(), 1, "the joiner's world snapshot has the table")
	check_eq(tables_drawn(c.surface), 1, "and draws it (FixtureView, one alchemy table)")
	var at: Crafting.StationAt = Crafting.station_near(c.surface.data, c.s.local.player.sim_position)
	check(at != null and at.kind == Crafting.ALCHEMY, "the client is at the station on its own data")
	give(hm(r, c), &"wild_healing", 2, ItemDB.Grade.FINE)
	give(hm(r, far), &"wild_healing", 2, ItemDB.Grade.FINE)
	_tick(r, 2)
	check(c.s.local.player.inventory.has_seen(&"wild_healing"), "the client's inventory remembers the herb (unlock)")
	check_eq(Crafting.shown_recipes(Crafting.ALCHEMY, c.s.local.player.inventory).size(), 2,
		"so the panel shows its two recipes on the client")
	var a: NetBot.Action = NetBot.Action.new()
	a.op = Main.craft_request(Crafting.index_of(&"potion_healing_fine"))
	press(r, null, c, a)
	var fa: NetBot.Action = NetBot.Action.new()
	fa.op = Main.craft_request(Crafting.index_of(&"potion_healing_fine"))
	far.action = fa
	_tick(r, 6)
	far.action = null
	check(c.s.local.player.inventory.count_of(&"potion_healing", ItemDB.Grade.FINE) == 1
		and c.s.local.player.inventory.count_of(&"wild_healing") == 0, "the client brewed a FINE healing potion at the host's table")
	var c_crafted: int = hm(r, c).ops_done.get("craft", 0)
	check(hm(r, c).player.inventory.count_of(&"potion_healing") == 1 and c_crafted == 1,
		"(the host's inventory of it)")
	check(hm(r, far).refused(Crafting.WHY_NO_STATION) == 1 and far.s.local.player.inventory.count_of(&"wild_healing") == 2,
		"the client 9 tiles off: no station, its herbs stay")
	check_prediction("craft / herbalist", c)
	_free_rig(r)


## A late joiner after a poison and a buff and while a bottle is in the air: its welcome has the buffed player, its
## enemy keyframe the poisoned heretic (it draws the mark), the combat snapshot the bottle, and the splash comes
## live. A client sent down to the dungeon, where the host put a table, gets the table in its map snapshot.
func _check_late_join_effects() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(Arena.spawn_feet(south_of_altar(r, 10)))
	var hp: Player = r.s.local.player
	hp.teleport(Arena.spawn_feet(south_of_altar(r, 5)))
	give(r.s.local, &"potion_poison", 3, ItemDB.Grade.FINE)
	give(r.s.local, &"potion_buff", 1)
	var a: Client = _join(r, 101, "paladin", hp.sim_position + Vector2(-40, 0), false)
	var ma: NetMember = hm(r, a)
	hp.inventory.select(slot_of(hp.inventory, &"potion_buff"))
	press(r, throw_at(Combat.body_point(ma.player.sim_position)))
	tick_until(r, func() -> bool: return ma.player.vitals.buffed(), 120)
	hp.inventory.select(slot_of(hp.inventory, &"potion_poison"))
	wait_free(r, hp)
	press(r, throw_at(Combat.body_point(h.pos)))
	tick_until(r, func() -> bool: return h.poisoned(), 120)
	wait_free(r, hp)
	press(r, throw_at(Combat.body_point(h.pos) + Vector2(20, 0)))
	tick_until(r, func() -> bool: return not arena.flasks.is_empty(), 60)
	check(not arena.flasks.is_empty() and h.poisoned() and ma.player.vitals.buffed(), "a bottle in the air, the heretic poisoned, the paladin buffed")
	var in_air: int = arena.flasks[0].id if not arena.flasks.is_empty() else -1
	var late: Client = _join(r, 102, "cleric", null, false)
	check(late.s.active, "a late joiner came in")
	var on_late: NetMember = late.s.members[ma.slot]
	check(on_late.interp.latest() != null and on_late.interp.latest().vitals != null and on_late.interp.latest().vitals.buffed(),
		"its welcome had the paladin buffed")
	late.s.client.draw_others()
	check(on_late.player.effect_marks.shown == ([EffectMarks.Kind.BUFF] as Array[int]), "it draws the buff mark")
	var lc: NetCombat = late.s.client.combat
	check(lc.poisoned_seen.has(h.id), "its enemy keyframe had the heretic poisoned")
	lc.sample(float(r.s.tick), SessionClient.interp_delay_ticks())
	late.s.client.combat_view.sync([] as Array[Player])
	var node: Heretic = late.s.client.combat_view.heretics.get(h.id, null)
	check(node != null and node.marks.shown.has(EffectMarks.Kind.POISON), "and draws its poison mark")
	check(track(late, in_air) != null and track(late, in_air).thrown, "the bottle in the air came as a thrown event after the welcome")
	tick_until(r, func() -> bool: return arena.flasks.is_empty(), 60)
	_tick(r, 3)
	check(track(late, in_air) != null and track(late, in_air).end_tick >= 0, "its splash came live")
	check_eq(late.s.client.combat.latest_hash(), r.host.combat_hash(Config.MAP_SURFACE), "its enemy view = the host's")
	# The dungeon: the host puts a table there; a client sent down gets it in the map snapshot.
	var d: WorldData = r.dungeon.data
	var arrive: Vector2i = Aim.feet_cell(DungeonGen.arrival_point(d))
	var cell: Vector2i = arrive + Vector2i(0, 2)
	for e: EditLog.WorldEdit in WorldItems.place(d, _feet(cell + Vector2i(0, -1)), _table_inv(), 0, cell).edits:
		r.host.apply_world_edit(e, Config.MAP_DUNGEON)
	check_eq(d.footprints(WorldData.PLACEABLE_ALCHEMY).size(), 1, "a table in the dungeon (host)")
	r.host.move_to_map(ma, Config.MAP_DUNGEON)
	tick_until(r, func() -> bool: return a.s.local.map_id == Config.MAP_DUNGEON, 30)
	check(a.s.local.map_id == Config.MAP_DUNGEON and a.dungeon.data != null
		and a.dungeon.data.footprints(WorldData.PLACEABLE_ALCHEMY).size() == 1 and tables_drawn(a.dungeon) == 1,
		"the client's dungeon (map entry) has the table and draws it")
	check(a.dungeon.data != null and a.dungeon.data.content_hash() == d.content_hash(), "its dungeon = the host's")
	_free_rig(r)


static func _table_inv() -> Inventory:
	var inv: Inventory = Inventory.new()
	inv.add(&"alchemy_table", 1)
	return inv


## Four players with a 3-tick delay each way: two herbalists (the host, a client) throw poison at two heretics and
## the buff at the archer and the paladin, who fight. Both heretics die; every client's enemy view, HP orders and
## its own state end as the host's; the buffed players' effects reached everyone; the predictions took only host
## events.
func _check_four_potions() -> void:
	var r: Rig = _rig(HERB)
	r.delay = 3
	await await_frames(1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var f: Vector2 = Arena.spawn_feet(south_of_altar(r, 13))
	var h1: HereticSim = arena.spawn_heretic(f)
	var h2: HereticSim = arena.spawn_heretic(f + Vector2(48, 0))
	var hp: Player = r.s.local.player
	hp.teleport(Arena.spawn_feet(south_of_altar(r, 7)))
	give(r.s.local, &"potion_poison", 4, ItemDB.Grade.FINE)
	give(r.s.local, &"potion_buff", 2, ItemDB.Grade.FINE)
	var ch: Client = _join(r, 101, HERB, Arena.spawn_feet(south_of_altar(r, 7)) + Vector2(48, 0), false)
	var arc: Client = _join(r, 102, "archer", f + Vector2(24, -60))
	var pal: Client = _join(r, 103, "paladin", f + Vector2(-20, 0))
	var cs: Array[Client] = [ch, arc, pal]
	give(hm(r, ch), &"potion_poison", 4, ItemDB.Grade.FINE)
	give(hm(r, ch), &"potion_buff", 2, ItemDB.Grade.FINE)
	_tick(r, 8)
	press(r, null, ch, _select(slot_of(ch.s.local.player.inventory, &"potion_buff")))
	hp.inventory.select(slot_of(hp.inventory, &"potion_buff"))
	_tick(r, 8)
	# The buffs first (the host's at the paladin, the client's at the archer), then poison and fighting.
	press(r, throw_at(Combat.body_point(hm(r, pal).player.sim_position)), ch, throw_at(Combat.body_point(hm(r, arc).player.sim_position)))
	_tick(r, 60)
	var buffed_seen: int = 0
	for c: Client in cs:
		for other: Client in cs:
			if other != c:
				var view: NetMember = c.s.members[hm(r, other).slot]
				if view.interp.latest() != null and view.interp.latest().vitals != null and view.interp.latest().vitals.buffed():
					buffed_seen += 1
	check(hm(r, pal).player.vitals.buffed() and hm(r, arc).player.vitals.buffed(), "both fighters buffed by the herbalists' bottles")
	check(buffed_seen >= 2, "the clients see the buffs in each other's states (%d views)" % buffed_seen)
	press(r, null, ch, _select(slot_of(ch.s.local.player.inventory, &"potion_poison")))
	hp.inventory.select(slot_of(hp.inventory, &"potion_poison"))
	var t: int = 0
	var host_next: int = 0
	var ch_next: int = 10
	while (h1.alive() or h2.alive()) and t < 1500:
		var target: HereticSim = h1 if h1.alive() else h2
		var ha: NetBot.Action = null
		if t >= host_next and hp.action_anim < 0 and hp.inventory.count_of(&"potion_poison") > 0 and target.poison_ticks < 60:
			ha = throw_at(Combat.body_point(target.pos))
			host_next = t + 90
		r.action = ha
		var other: HereticSim = h2 if h2.alive() else h1
		if t >= ch_next and ch.s.local.player.inventory.count_of(&"potion_poison") > 0 and other.poison_ticks < 60:
			ch.action = throw_at(_drawn_foe(r, ch, other.id, Combat.body_point(other.pos)))
			ch_next = t + 90
		else:
			ch.action = null
		arc.action = swing_at(_drawn_foe(r, arc, target.id, target.pos))
		pal.action = swing_at(_drawn_foe(r, pal, target.id, target.pos))
		_tick(r)
		t += 1
	r.action = null
	for c: Client in cs:
		c.action = null
	_tick(r, Config.HERETIC_CORPSE_TICKS + 60)
	check(not h1.alive() and not h2.alive(), "four players killed two heretics in %d ticks (poison kills %d)" % [t, arena.stat("poison_kills")])
	check(arena.stat("poisoned") >= 2 and r.s.local.combat_count("throws") + hm(r, ch).combat_count("throws") >= 4,
		"the herbalists threw (%d, %d) and poisoned (%d)" % [r.s.local.combat_count("throws"), hm(r, ch).combat_count("throws"),
		arena.stat("poisoned")])
	for c: Client in cs:
		check_eq(hp_mismatches(r, c), 0, "four/peer %d: every batch = the host's HP at its tick" % c.peer)
		check(_follows(c.s.client.combat.hp_seen(h1.id), host_hp_seq(r, h1.id))
			and _follows(c.s.client.combat.hp_seen(h2.id), host_hp_seq(r, h2.id)), "four/peer %d: both heretics' HP the host's way" % c.peer)
		check_eq(c.s.client.combat.latest_hash(), r.host.combat_hash(Config.MAP_SURFACE), "four/peer %d: its last enemy view = the host's" % c.peer)
		check(c.s.client.combat.poisoned_seen.has(h1.id) or c.s.client.combat.poisoned_seen.has(h2.id), "four/peer %d: saw a poisoned heretic" % c.peer)
		check(flask_events(c, NetProtocol.ShotEvent.Kind.THROW) >= 4, "four/peer %d: got the bottles (%d)" % [c.peer,
			flask_events(c, NetProtocol.ShotEvent.Kind.THROW)])
		check_eq(c.s.local.player.sim_position, hm(r, c).player.sim_position, "four/peer %d: where the host has it" % c.peer)
		check(effects_close(c.s.client.prediction.sim.vit, hm(r, c).player.vitals, 2 * r.delay + 4),
			"four/peer %d: its vitals and effects = the host's (%s / host %s)" % [c.peer, c.s.client.prediction.sim.vit.describe(),
			hm(r, c).player.vitals.describe()])
		check_prediction("four potions/peer %d" % c.peer, c)
	var total: int = 0
	for k: String in r.bytes_by_kind:
		total += r.bytes_by_kind[k]
	note("four with potions, host -> 3 clients over %d ticks: %s (all %d B)" % [r.s.tick, r.bytes_by_kind, total])
	_free_rig(r)

## Offline (Player.make_frame + step_frame + Potions.release on an offline arena) = the host (the frames the client
## records, through the wire codec into SessionHost.run_frame and its own release; the host's arena) every tick
## (PlayerSim.same_all), the bottles flying the same way; and a client's prediction (it plays the drink and the
## throw, never the effect) reconciled with the host's states 6 ticks late: it got only the host's events wrong
## (the heals, buffs and poisons a potion put on it, the hits), never a timer or a step.
func _check_shared_sim_frames() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var start: Vector2 = Arena.spawn_feet(south_of_altar(r, 9))
	var c: Client = await _join_quiet(r, 101, HERB, start)
	var m: NetMember = hm(r, c)
	var off: Player = Player.new()
	off.local_input = false
	off.potions_on = true
	off.setup(r.surface.data, HERB, start, RigData.Dir.SOUTH)
	add_node(off)
	var off_arena: Arena = Arena.new()
	off_arena.setup(r.surface.data, SEED)
	off_arena.spawning = false
	var host_arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var pred: Prediction = Prediction.new()
	pred.setup(r.surface.data, start, RigData.Dir.SOUTH, 0)
	var items: Array[Array] = [[&"potion_healing", 1, 4], [&"potion_buff", 2, 4], [&"potion_poison", 2, 4]]
	for it: Array in items:
		var id: StringName = it[0]
		var g: int = it[1]
		var n: int = it[2]
		off.inventory.add(id, n, g)
		m.player.inventory.add(id, n, g)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6062
	var mismatch: int = 0
	var first_bad: String = ""
	var throws: int = 0
	var drinks: int = 0
	var flask_off: int = 0
	var dir: Vector2i = Vector2i.ZERO
	var last_seq: int = 0
	var states: Array[Array] = []
	var host_events: int = 0
	for t: int in 1500:
		if t % 25 == 0:
			dir = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))
		var mouse: Vector2 = (off.sim_position + Vector2(rng.randi_range(-60, 60), rng.randi_range(-60, 60))).round()
		var click: bool = t % 97 == 40
		var skill: bool = t % 131 == 70
		if click or skill:
			var pick: int = rng.randi_range(0, 2)
			var id2: StringName = items[pick][0]
			var s2: int = slot_of(off.inventory, id2)
			if s2 >= 0 and s2 < off.inventory.hotbar_size:
				off.inventory.select(s2)
		if t % 211 == 100 and off.vitals.hp > 40:
			off.take_hit(25)
			m.player.take_hit(25)
			host_events += 1
		var f: NetProtocol.InputFrame = off.make_frame(dir, mouse, true, click, click, false, false, skill)
		# Offline.
		off.begin_tick()
		off.step_frame(f, Config.NET_TICK)
		if off.action_anim >= 0 and off.action_tick == Player.impact_tick_of(off.action_item, off.action_anim) \
				and Potions.is_potion(off.action_item):
			var rel: Potions.Released = Potions.release(off, off.action_item, off.action_anim, off_arena)
			if rel.ok():
				if rel.thrown:
					throws += 1
				else:
					drinks += 1
					host_events += 1
		off_arena.now = t
		off_arena.step([off] as Array[Player])
		# The client: its prediction steps the frame (the action it resolved) and records it when it matters.
		var cf: NetProtocol.InputFrame = _wire(f)
		cf.anim = f.anim
		cf.item = f.item
		var rec: NetProtocol.InputFrame = pred.step_frame(cf)
		# The host: the recorded frames through the wire (the selection rides along like a SELECT request).
		m.player.inventory.select(off.inventory.selected)
		r.s.tick = t
		host_arena.now = t
		m.player.begin_tick()
		if rec != null:
			r.host.run_frame(m, _wire(rec))
			last_seq = rec.seq
		var splashes_before: int = host_arena.stat("splash_players")
		host_arena.step(r.host.players_on(Config.MAP_SURFACE))
		host_events += host_arena.stat("splash_players") - splashes_before
		host_arena.shot_events.clear()
		host_arena.hits.clear()
		# The host's state of it, 6 ticks late, every third tick.
		if t % 3 == 0:
			var st: NetProtocol.PlayerState = m.state()
			st.ack = last_seq
			states.append([t + 6, st])
		while not states.is_empty():
			var head: Array = states[0]
			var due_tick: int = head[0]
			if due_tick > t:
				break
			var due: NetProtocol.PlayerState = head[1]
			states.pop_front()
			pred.reconcile(due)
		var so: PlayerSim = off.to_sim()
		if not so.same_all(m.player.to_sim()):
			mismatch += 1
			if first_bad.is_empty():
				first_bad = "tick %d: offline %s / host %s" % [t, so.vit.describe(), m.player.vitals.describe()]
		if off_arena.flasks.size() != host_arena.flasks.size():
			flask_off += 1
		else:
			for i: int in off_arena.flasks.size():
				if off_arena.flasks[i].pos.distance_to(host_arena.flasks[i].pos) > 0.01:
					flask_off += 1
	check_eq(mismatch, 0, "offline == host every tick with drink and throw frames through the wire %s" % first_bad)
	check_eq(flask_off, 0, "the bottles flew the same offline and on the host")
	check(throws >= 4 and drinks >= 2, "the run threw (%d) and drank (%d)" % [throws, drinks])
	for it: Array in items:
		var id3: StringName = it[0]
		check_eq(m.player.inventory.count_of(id3), off.inventory.count_of(id3), "%s: the same left offline and on the host" % id3)
	check(pred.corrections == 0 and pred.facing_corrections == 0 and pred.action_corrections == 0 and pred.vitals_corrections == 0,
		"the prediction (states 6 ticks late) got no step, facing, action or timer wrong (%d / %d / %d / %d; %s)" % [pred.corrections,
		pred.facing_corrections, pred.action_corrections, pred.vitals_corrections, pred.last_vitals_mismatch])
	check(pred.event_corrections > 0 and host_events > 0, "the potions' effects and the hits were the host's events (%d states, %d events)" % [
		pred.event_corrections, host_events])
	note("shared sim with frames: 1500 ticks, %d throws, %d drinks, %d host events; offline = host, prediction events only" % [throws,
		drinks, host_events])
	_owned_nodes.erase(off)
	off.get_parent().remove_child(off)
	off.free()
	_free_rig(r)


## The session's local input while a panel holds the keys (Player.ui_locked): a bot's move, F and skill become a
## standing frame; its Tab and craft row go to Main first (NetSession.bot_ui), locked or not.
func _check_session_ui() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var got: Array[Vector2i] = []
	r.s.bot_ui.connect(func(tab: bool, row: int) -> void: got.append(Vector2i(1 if tab else 0, row)))
	var bot: NetBot = NetBot.new()
	check_eq(bot.parse("move:1,0,3;tab;craft:3;hold:2;throw;throw"), "", "the bot parses")
	r.s.bots.bot = bot
	r.s.bots.bots_started = true
	var p: Player = r.s.local.player
	var a: NetBot.Action = r.s.bots.local_action()
	check_eq(a.dir, Vector2i(1, 0), "open: the bot walks")
	p.ui_locked = true
	a = r.s.bots.local_action()
	check_eq(a.dir, Vector2i.ZERO, "a panel open: the player stands")
	r.s.bots.local_action()
	r.s.bots.local_action()
	r.s.bots.local_action()
	check_eq(got, [Vector2i(1, -1), Vector2i(0, 2)] as Array[Vector2i], "the bot's Tab and craft row 3 reached Main (bot_ui)")
	a = r.s.bots.local_action()
	check(not a.interact, "locked: no F held")
	r.s.bots.local_action()
	a = r.s.bots.local_action()
	check(not a.skill, "locked: no skill key")
	p.ui_locked = false
	a = r.s.bots.local_action()
	check(a.skill, "open again: the skill key goes through")
	_free_rig(r)


## Traffic of effects on players who stand still (README "측정"): the host and two clients stand, then one client
## gets the FINE buff, then a heretic standing in the open gets poisoned; the host's bytes to the clients by message
## kind and the buffed client's input bytes, per second, in each phase. At rest nothing goes (after the keyframe);
## a buff is a timer (Vitals.idle), so the buffed client sends a frame every tick and its state (40 B) goes out at
## 20 Hz; a poisoned heretic's batch goes when its HP and hit flash change (every Config.POISON_INTERVAL_TICKS).
func _measure_idle_effects() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 1  # each client packet waits one tick in r.up, where it is counted once
	await await_frames(1)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(Arena.spawn_feet(south_of_altar(r, 14)))
	var a: Client = _join(r, 101, HERB, Arena.spawn_feet(south_of_altar(r, 5)), false)
	var b: Client = _join(r, 102, "archer", Arena.spawn_feet(south_of_altar(r, 5)) + Vector2(40, 0), false)
	_tick(r, 60)
	var phases: Array[String] = ["rest", "buffed", "buffed + poisoned heretic"]
	var lines: PackedStringArray = []
	var rates: Array[float] = []
	for phase: int in 3:
		if phase == 1:
			hm(r, a).player.apply_potion(&"potion_buff", ItemDB.Grade.FINE)
			_tick(r, 30)
		elif phase == 2:
			arena.poison_heretic(h, Config.POISON_DAMAGE[ItemDB.Grade.FINE], Config.POISON_TICKS[ItemDB.Grade.FINE])
		var before: Dictionary[String, int] = r.bytes_by_kind.duplicate()
		var up: int = 0
		var ticks: int = 240
		for t: int in ticks:
			for u: Array in r.up:
				var bytes: PackedByteArray = u[3]
				up += bytes.size()
			_tick(r)
		var sent: int = 0
		var parts: PackedStringArray = []
		for k: String in r.bytes_by_kind:
			var was: int = before.get(k, 0)
			var d: int = r.bytes_by_kind[k] - was
			if d > 0:
				sent += d
				parts.append("%s %d" % [k, roundi(d * float(Config.NET_TICK_RATE) / ticks)])
		var rate: float = sent * float(Config.NET_TICK_RATE) / ticks
		rates.append(rate)
		lines.append("%s: host -> 2 clients %.0f B/s (%s), the buffed client's input %.0f B/s" % [phases[phase], rate,
			", ".join(parts), up * float(Config.NET_TICK_RATE) / ticks])
	check(rates[0] == 0.0, "at rest nothing goes to the clients (%.0f B/s)" % rates[0])
	check(rates[1] > 1000.0, "a buffed player's state goes at 20 Hz while its buff runs (%.0f B/s)" % rates[1])
	check(rates[2] > rates[1], "a poisoned heretic adds its batches (%.0f B/s)" % rates[2])
	check(h.poisoned() or h.hp < Config.HERETIC_HP, "the heretic took poison")
	note("idle with effects, one process, ENet payload bytes: %s" % "; ".join(lines))
	_free_rig(r)


## Frame `f` as the host gets it: through the wire codec (its request's fields as sent).
static func _wire(f: NetProtocol.InputFrame) -> NetProtocol.InputFrame:
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(NetProtocol.encode_inputs([f] as Array[NetProtocol.InputFrame]))
	return p.frames[0] if p.ok and not p.frames.is_empty() else NetProtocol.InputFrame.new(f.seq, f.dir)
