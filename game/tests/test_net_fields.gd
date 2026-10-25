extends "res://tests/test_net_potions.gd"
## M5c: farming, purification and moving the altar in sessions, in one process: the real SessionHost and SessionClient
## flows on the rig of tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients'
## packets back, an optional fixed one-way delay). tests/test_net_farm.gd and tests/test_net_purify.gd run real sessions.
##   - the wire (protocol v7): the CHANNEL, ALTAR_LIFT and ALTAR_PLACE requests; the channel in a state's action bits and
##     the carried altar in its held-item byte; round trips, every field out of range and every truncation
##   - the host against a malicious client: tilling outside the light, planting the poison herb as a paladin, harvesting
##     an unripe crop (a heretic on it is not cut), a sickle out of reach, seed spam, another map, while down; holy water
##     far away or on clean ground, a channel by a non-paladin or far from corruption, channel spam, a channel broken by
##     a step; lifting the altar too early or from too far, putting it down without carrying it, into the dungeon, on the
##     entrance's arrival point, on corruption, on a body, spam; what a carrier may not do
##   - flows: two players farm one field and both see it grow (the paladin plants healing, the herbalist harvests FINE,
##     the paladin harvests COMMON); a paladin client channels at a zone's edge (predicted, the host purifies, the spawn
##     ring shrinks, another client sees the channel) and pours holy water; the host moves the altar while a client stands
##     in the old light (the light, the spawn slots, the respawn and the heretic follow); the dead wait while it is carried;
##     a late joiner gets the fields, the withered crops and the moved altar, and one while it is carried appears where it
##     was picked up and sees it carried; four players with a delay agree
##   - traffic: idle with a growing field, a purification (README "측정")

## Seed 1 (README "M5c"): the paladin channels from the grass east of the north zone's edge; the archer watches from two
## tiles east of it; the client farms standing on a lit tile between the altar's south-west and the M1 soil patch.
const ZONE_EDGE: Vector2i = Vector2i(60, 15)
const FARM_FEET: Vector2i = Vector2i(61, 49)
const CLIENT_FIELD: Vector2i = Vector2i(62, 49)
const HOST_FIELD: Vector2i = Vector2i(60, 49)
const HOST_FARM_FEET: Vector2i = Vector2i(59, 48)
## Where the host puts the altar down in the flows (feet tile, target tile; M5b's screenshot place, footprint at 49,45).
const ALTAR_FEET: Vector2i = Vector2i(50, 48)
const ALTAR_AIM: Vector2i = Vector2i(50, 47)
const ALTAR_NEW: Vector2i = Vector2i(49, 45)
## M5-fix: the place by a zone (AltarTest.by_zone).
const AltarTest := preload("res://tests/test_altar_move.gd")


func run() -> Array[String]:
	_check_fields_codec()
	await _check_farm_requests()
	await _check_purify_requests()
	await _check_altar_requests()
	await _check_hold_rules()
	await _check_channel_hold()
	await _check_join_while_carried()
	await _check_farming_flow()
	await _check_channel_flow()
	await _check_altar_flow()
	await _check_respawn_waits()
	await _check_late_join_fields()
	await _check_four_fields()
	await _measure_fields_traffic()
	return failures


# --- helpers -----------------------------------------------------------------------------------------

## Feet low in tile `c` (the feet tile is `c`).
static func feet_in(c: Vector2i) -> Vector2:
	return Arena.spawn_feet(c)


static func centre_of(c: Vector2i) -> Vector2:
	return Vector2(c * Config.TILE) + Vector2(Config.TILE, Config.TILE) / 2.0


## Member `m`'s frame `f` straight into the host (no wire, no arena step).
func run_one(r: Rig, m: NetMember, f: NetProtocol.InputFrame) -> void:
	m.player.begin_tick()
	r.host.run_frame(m, f)


## `n` empty frames of member `m` on the host.
func run_empty(r: Rig, m: NetMember, n: int) -> void:
	for i: int in n:
		run_one(r, m, NetProtocol.InputFrame.new())


## A frame with F held (and aiming toward tile `at`'s side: the look is unused by the host's hold count).
static func held_frame() -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	f.interact = true
	return f


static func lift_frame(cell: Vector2i) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.ALTAR_LIFT, Config.MAP_SURFACE, cell)
	f.interact = true
	return f


static func place_frame(cell: Vector2i) -> NetProtocol.InputFrame:
	return _op(NetProtocol.Op.ALTAR_PLACE, Config.MAP_SURFACE, cell)


static func channel_frame(map: int = Config.MAP_SURFACE) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	f.op = NetProtocol.Op.CHANNEL
	f.map = map
	return f


## Swings of member `m` that landed on nothing for `why` (NetMember.swings_missed).
static func missed(m: NetMember, why: String) -> int:
	var n: int = m.swings_missed.get(why, 0)
	return n


## A full request budget for member `m` (the checks below each want a fresh one).
static func refill(m: NetMember) -> void:
	for t: int in Config.NET_OP_BURST * Config.NET_OP_INTERVAL_TICKS:
		m.refill_ops()


## A grass tile well outside the light with nothing on it that may become soil (no ash near).
static func dark_grass(data: WorldData) -> Vector2i:
	for y: int in range(4, data.size.y - 4):
		for x: int in range(4, data.size.x - 4):
			var c: Vector2i = Vector2i(x, y)
			if data.terrain_at(c) == Terrain.GRASS and data.get_value(WorldData.Layer.VEGETATION, c) == 0 \
					and data.get_value(WorldData.Layer.PLACEABLE, c) == 0 and data.can_set_terrain(c, Terrain.SOIL) \
					and not Farming.near_corruption(data, c) \
					and Vector2(c * Config.TILE).distance_to(data.altar_center_px()) > Config.safe_radius_px() + 64.0:
				return c
	return Vector2i(-1, -1)


## Written out here (not Purify.channel_area): the corrupted tiles whose centre lies within PURIFY_RADIUS_TILES of tile
## `centre`'s centre.
static func disc_corrupted(data: WorldData, centre: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r: int = Config.PURIFY_RADIUS_TILES
	for y: int in range(centre.y - r, centre.y + r + 1):
		for x: int in range(centre.x - r, centre.x + r + 1):
			var c: Vector2i = Vector2i(x, y)
			if Vector2(c - centre).length() <= float(r) + 0.0001 and data.get_value(WorldData.Layer.CORRUPTION, c) != 0:
				out.append(c)
	return out


## Lifts the altar for member `m` on the host: F held Config.ALTAR_PICKUP_HOLD_TICKS frames, the last one with the
## request aimed at tile `at`.
func lift_altar(r: Rig, m: NetMember, at: Vector2i) -> void:
	for i: int in Config.ALTAR_PICKUP_HOLD_TICKS - 1:
		run_one(r, m, held_frame())
	refill(m)
	run_one(r, m, lift_frame(at))


## A (feet tile, target tile) for a carrier near `around` (within 5 tiles) whose footprint place_refusal refuses for
## `why` exactly (on `data` with `bodies` besides the carrier's feet); [] when none.
static func spot_refused(data: WorldData, around: Vector2i, why: String, bodies: Array[Vector2] = []) -> Array[Vector2i]:
	for dy: int in range(-5, 6):
		for dx: int in range(-5, 6):
			var f: Vector2i = around + Vector2i(dx, dy)
			var feet: Vector2 = feet_in(f)
			if not data.in_bounds(f) or not Movement.can_stand(data, feet):
				continue
			for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var all: Array[Vector2] = [feet]
				all.append_array(bodies)
				if AltarMove.place_refusal(data, AltarMove.place_rect(feet, f + d), all) == why:
					return [f, f + d]
	return []


## A (feet tile, target tile) within 6 tiles of `around` where holy water may be poured (corruption in the target's 3x3);
## [] when none.
static func pour_spot(data: WorldData, around: Vector2i) -> Array[Vector2i]:
	for dy: int in range(-6, 7):
		for dx: int in range(-6, 7):
			var f: Vector2i = around + Vector2i(dx, dy)
			if not data.in_bounds(f) or not Movement.can_stand(data, feet_in(f)):
				continue
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1)]:
				if Purify.holy_water_refusal(data, feet_in(f), f + d).is_empty():
					return [f, f + d]
	return []


## The fields of `data` as SessionReport writes them (tests compare them across machines).
static func fields(data: WorldData) -> Dictionary:
	return SessionReport.fields_of(data)


# --- the wire (protocol v7) ------------------------------------------------------------------------------

func _check_fields_codec() -> void:
	check_eq(NetProtocol.VERSION, 8, "protocol version 8 (M5c: 7, M7c: 8)")
	check_eq(NetProtocol.CODE_COUNT, 180, "a frame is still one byte (the channel is a request, not a frame bit)")
	check(NetProtocol.op_has_map(NetProtocol.Op.CHANNEL) and NetProtocol.op_has_map(NetProtocol.Op.ALTAR_LIFT)
		and NetProtocol.op_has_map(NetProtocol.Op.ALTAR_PLACE), "the three new requests carry the map")
	check_eq([NetProtocol.OP_SIZES[NetProtocol.Op.CHANNEL], NetProtocol.OP_SIZES[NetProtocol.Op.ALTAR_LIFT],
		NetProtocol.OP_SIZES[NetProtocol.Op.ALTAR_PLACE]], [1, 5, 5], "CHANNEL 1 B, ALTAR_LIFT and ALTAR_PLACE 5 B")
	var frames: Array[NetProtocol.InputFrame] = [NetProtocol.InputFrame.new(40, Vector2i.ZERO),
		NetProtocol.InputFrame.new(41, Vector2i.ZERO), NetProtocol.InputFrame.new(42, Vector2i(1, 0))]
	frames[0].op = NetProtocol.Op.CHANNEL
	frames[0].map = Config.MAP_SURFACE
	frames[1].op = NetProtocol.Op.ALTAR_LIFT
	frames[1].map = Config.MAP_SURFACE
	frames[1].cell = Vector2i(62, 47)
	frames[1].interact = true
	frames[2].op = NetProtocol.Op.ALTAR_PLACE
	frames[2].map = Config.MAP_SURFACE
	frames[2].cell = Vector2i(-3, 300)
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	var same: bool = p.ok and p.frames.size() == 3
	for i: int in 3:
		same = same and p.frames[i].same_request(frames[i])
	check(same and p.frames[0].channel and not p.frames[1].channel and p.frames[1].interact,
		"CHANNEL / ALTAR_LIFT / ALTAR_PLACE round trip (the channel flag comes back from the op)")
	check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 3 + 1 + (2 + 1) + (2 + 5) + (2 + 5), "their packet size")
	var cut_ok: int = 0
	for n: int in range(NetProtocol.INPUT_HEADER + 3 + 1, bytes.size()):
		if NetProtocol.decode_inputs(bytes.slice(0, n)).ok:
			cut_ok += 1
	check_eq(cut_ok, 0, "every truncation of their requests is refused")
	var bad: PackedByteArray = bytes.duplicate()
	bad[NetProtocol.INPUT_HEADER + 3 + 1 + 2] = Config.MAP_COUNT  # CHANNEL's map
	check(not NetProtocol.decode_inputs(bad).ok, "a map out of range is refused")
	# States: the channel in the action bits, the carried altar in the held byte.
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.slot = 3
	s.pos = Vector2(970.25, 251.5)
	s.channel = 90
	s.held = &"holy_water"
	var b: PackedByteArray = NetProtocol.encode_states(77, [s] as Array[NetProtocol.PlayerState])
	var got: NetProtocol.StateBatch = NetProtocol.decode_states(b)
	check(got.ok and got.states[0].same_as(s) and got.states[0].channel == 90 and got.states[0].action == -1,
		"a channelling state round trips (channel 90, no action)")
	check_eq(b.size(), NetProtocol.STATE_HEADER + NetProtocol.STATE_SIZE, "still 17 B")
	var s2: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s2.carrying = true
	s2.held = ItemDB.id_at(ItemDB.count() - 1)
	s2.vitals = Vitals.new()
	s2.vitals.hp = 40
	var b2: PackedByteArray = NetProtocol.encode_states(78, [s2] as Array[NetProtocol.PlayerState])
	var got2: NetProtocol.StateBatch = NetProtocol.decode_states(b2)
	check(got2.ok and got2.states[0].carrying and got2.states[0].held == s2.held and got2.states[0].same_as(s2),
		"a carrier (with the last item held, hurt) round trips")
	var bad_tick: PackedByteArray = b.duplicate()
	bad_tick[NetProtocol.STATE_HEADER + 14] = 0
	check(not NetProtocol.decode_states(bad_tick).ok, "a channel at tick 0 is refused")
	bad_tick[NetProtocol.STATE_HEADER + 14] = Config.PURIFY_CHANNEL_TICKS
	check(not NetProtocol.decode_states(bad_tick).ok, "a channel at its full time is refused (it has ended then)")
	var bad_held: PackedByteArray = b2.duplicate()
	bad_held[NetProtocol.STATE_HEADER + 15] = NetProtocol.CARRYING_FLAG | (ItemDB.count() + 1)
	check(not NetProtocol.decode_states(bad_held).ok, "the carrier flag with an unknown item is refused")
	var info: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
	info.class_index = NetProtocol.class_index("paladin")
	info.state = s
	var ib: PackedByteArray = NetProtocol.encode_info(info)
	var ig: NetProtocol.PlayerInfo = NetProtocol.decode_info(ib)
	check(ig != null and ig.state.same_as(s) and ib.size() == NetProtocol.INFO_SIZE, "a channelling player's info (18 B)")
	check(Config.PURIFY_CHANNEL_TICKS <= 256, "the channel's ticks fit the action-frames byte (%d)" % Config.PURIFY_CHANNEL_TICKS)
	check(ItemDB.count() < NetProtocol.CARRYING_FLAG, "item indices stay below the carrier flag (%d)" % ItemDB.count())


# --- the host against a malicious client ------------------------------------------------------------------

func _check_farm_requests() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var c: Client = await _join_quiet(r, 101, "paladin", feet_in(FARM_FEET))
	var m: NetMember = hm(r, c)
	var inv: Inventory = m.player.inventory
	give(m, &"hoe", 1)
	give(m, &"seed_poison", 2)
	give(m, &"seed_healing", 12)
	give(m, &"sickle", 1)
	give(m, &"watering_can", 1)
	var hoe: int = slot_of(inv, &"hoe")
	var poison: int = slot_of(inv, &"seed_poison")
	var healing: int = slot_of(inv, &"seed_healing")
	var sickle: int = slot_of(inv, &"sickle")
	var can: int = slot_of(inv, &"watering_can")
	var log: EditLog = r.s.log_for(Config.MAP_SURFACE)
	# Tilling outside the light: the hoe swings (an adjacent tile, a tool), the host refuses the till where it lands.
	var dark: Vector2i = dark_grass(data)
	m.player.teleport(feet_in(dark + Vector2i(0, 1)))
	var edits: int = log.size()
	run_one(r, m, _use(Config.MAP_SURFACE, dark, hoe, 64))
	run_empty(r, m, PlayerSim.action_ticks(RigData.Anim.HOE))
	check(data.terrain_at(dark) == Terrain.GRASS and log.size() == edits and missed(m, Farming.WHY_DARK) == 1,
		"a malicious client tilling outside the light: the hoe swings, nothing is tilled (%s)" % m.swings_missed)
	# A lit tile: tilled, one edit.
	m.player.teleport(feet_in(FARM_FEET))
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD, hoe, 0))
	run_empty(r, m, PlayerSim.action_ticks(RigData.Anim.HOE))
	check(data.terrain_at(CLIENT_FIELD) == Terrain.SOIL and log.size() == edits + 1, "a lit grass tile: tilled (one edit)")
	# The poison herb as a paladin: refused (● R37), the seed kept.
	refill(m)
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD, poison, 0))
	check(m.refused(Farming.WHY_HERBALIST) == 1 and inv.count_of(&"seed_poison") == 2 and Farming.field_at(data, CLIENT_FIELD) == null,
		"planting the poison herb as a paladin: herbalist only, nothing planted, no seed used")
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD, healing, 0))
	var crop: Farming.Field = Farming.field_at(data, CLIENT_FIELD)
	check(crop != null and crop.kind == Farming.KIND_HEALING and not crop.fast and inv.count_of(&"seed_healing") == 11,
		"the healing herb: planted by the paladin (common speed), one seed used")
	# The unripe crop under the sickle: no harvest, and the heretic standing on it is not cut (the sickle is no weapon there).
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(feet_in(CLIENT_FIELD))
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD, sickle, 0))
	run_empty(r, m, PlayerSim.action_ticks(RigData.Anim.SICKLE))
	check(missed(m, Farming.WHY_NOT_RIPE) == 1 and h.hp == Config.HERETIC_HP and Farming.field_at(data, CLIENT_FIELD) != null,
		"harvesting an unripe crop: refused (not ripe), the crop stays, the heretic on it untouched")
	arena.hit_heretic(h, Config.HERETIC_HP)
	# The sickle three tiles off: out of reach (the use itself).
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD + Vector2i(3, 0), sickle, 0))
	check_eq(m.refused(WorldItems.WHY_REACH), 1, "a sickle aimed 3 tiles away: out of reach")
	# Seed spam: ten USEs in one tick on the M1 soil: the budget's four are checked (one plants, three find it planted),
	# six are "rate".
	refill(m)
	var soil: Vector2i = HOST_FIELD
	var rate: int = m.refused("rate")
	var planted: int = m.refused(Farming.WHY_PLANTED)
	for i: int in 10:
		run_one(r, m, _use(Config.MAP_SURFACE, soil, healing, 0))
	check(m.refused("rate") - rate == 6 and m.refused(Farming.WHY_PLANTED) - planted == 3 and inv.count_of(&"seed_healing") == 10,
		"ten seed USEs in a tick: one planted, three already planted, six rate (one seed used)")
	# Another map, and while down.
	refill(m)
	run_one(r, m, _use(Config.MAP_DUNGEON, CLIENT_FIELD + Vector2i(0, 1), healing, 0))
	check_eq(m.refused(WorldItems.WHY_WRONG_MAP), 1, "a seed USE naming the dungeon: wrong map")
	# The watering can: wet on its frame.
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD, can, 0))
	run_empty(r, m, PlayerSim.action_ticks(RigData.Anim.WATERING))
	check(Farming.field_at(data, CLIENT_FIELD).wet, "the watering can wets the crop on its frame")
	# A wild herb picked where it grows gives its crop's seed on the host too (M5a's rule, Farming.seeds_from_wild).
	var herb_cell: Vector2i = Vector2i(-1, -1)
	for g: Vector2i in WorldItems.gatherable_cells(data):
		if herb_cell.x < 0 and WorldItems.gatherable_at(data, g) == &"wild_buff":
			herb_cell = g
	if check(herb_cell.x >= 0, "a wild buff herb grows on the seed-1 surface"):
		m.player.teleport(feet_in(herb_cell + Vector2i(0, 1)))
		refill(m)
		var seeds: int = inv.count_of(&"seed_buff")
		run_one(r, m, _op(NetProtocol.Op.PICKUP, Config.MAP_SURFACE, herb_cell))
		check(inv.count_of(&"wild_buff") == 1 and inv.count_of(&"seed_buff") == seeds + Config.SEEDS_PER_WILD_HERB,
			"a wild herb picked in a session gives its seed (%s)" % inv.describe())
	m.player.take_hit(Config.PLAYER_HP_MAX)
	run_one(r, m, _use(Config.MAP_SURFACE, CLIENT_FIELD, healing, 0))
	check_eq(m.refused(SessionHost.WHY_DOWN), 1, "while down: refused")
	_free_rig(r)


func _check_purify_requests() -> void:
	var r: Rig = _rig("cleric")
	await await_frames(1)
	var data: WorldData = r.surface.data
	var c: Client = await _join_quiet(r, 101, "paladin", feet_in(ZONE_EDGE))
	var m: NetMember = hm(r, c)
	give(m, Purify.HOLY_WATER, 4)
	var water: int = slot_of(m.player.inventory, Purify.HOLY_WATER)
	var corrupted: int = Purify.corrupted_count(data)
	# Holy water far away, and on clean ground.
	run_one(r, m, _use(Config.MAP_SURFACE, ZONE_EDGE + Vector2i(-3, 0), water, 128))
	check_eq(m.refused(WorldItems.WHY_REACH), 1, "holy water aimed 3 tiles away: out of reach")
	run_one(r, m, _use(Config.MAP_SURFACE, ZONE_EDGE + Vector2i(1, 0), water, 0))
	check_eq(m.refused(Purify.WHY_NOTHING), 1, "holy water on clean ground: nothing to purify")
	check(m.player.inventory.count_of(Purify.HOLY_WATER) == 4 and Purify.corrupted_count(data) == corrupted and m.player.action_anim < 0,
		"neither started or used anything")
	# A channel by a non-paladin, by a paladin far from corruption, naming the dungeon.
	var a2: Client = await _join_quiet(r, 102, "archer", feet_in(ZONE_EDGE + Vector2i(0, 1)))
	var ma: NetMember = hm(r, a2)
	run_one(r, ma, channel_frame())
	check(ma.refused(Purify.WHY_PALADIN) == 1 and ma.player.channel_tick == 0, "a channel by an archer: paladin only")
	var far: Client = await _join_quiet(r, 103, "paladin", r.surface.spawn_point(3))
	var mf: NetMember = hm(r, far)
	run_one(r, mf, channel_frame())
	check(mf.refused(Purify.WHY_NOTHING) == 1 and mf.player.channel_tick == 0, "a paladin's channel at the altar: nothing to purify")
	run_one(r, m, channel_frame(Config.MAP_DUNGEON))
	check(m.refused(WorldItems.WHY_WRONG_MAP) == 1 and m.player.channel_tick == 0, "a channel naming the dungeon: wrong map")
	# A channel request with a step in its frame does not start (the player must stand); a started one breaks on a step.
	var walk: NetProtocol.InputFrame = channel_frame()
	walk.dir = Vector2i(0, 1)
	run_one(r, m, walk)
	check_eq(m.player.channel_tick, 0, "a CHANNEL frame that walks starts nothing")
	m.player.teleport(feet_in(ZONE_EDGE))
	run_one(r, m, channel_frame())
	run_empty(r, m, 40)
	run_one(r, m, NetProtocol.InputFrame.new(0, Vector2i(1, 0)))
	check(m.player.channel_tick == 0 and Purify.corrupted_count(data) == corrupted and m.combat_count("channel_broken") == 1,
		"a step at frame 42 breaks it: nothing purified")
	# Spam: a CHANNEL on every one of 40 frames: one start, 39 busy (the channel runs on).
	m.player.teleport(feet_in(ZONE_EDGE))
	var busy: int = m.refused(SessionHost.WHY_BUSY)
	for i: int in 40:
		run_one(r, m, channel_frame())
	check(m.refused(SessionHost.WHY_BUSY) - busy == 39 and m.player.channel_tick == 40,
		"40 CHANNEL frames: one channel (now at 40), 39 busy")
	# It completes: exactly the corrupted tiles of the disc (written out here) are purified; the spawn ring shrinks.
	var want: Array[Vector2i] = disc_corrupted(data, ZONE_EDGE)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	arena.sync_world()
	var ring: int = arena.spawn_cells.size()
	run_empty(r, m, Config.PURIFY_CHANNEL_TICKS - 40)
	var left: int = 0
	for cell: Vector2i in want:
		if Purify.is_corrupted(data, cell):
			left += 1
	check(want.size() > 3 and left == 0 and Purify.corrupted_count(data) == corrupted - want.size(),
		"the channel's %d frames done: the disc's %d corrupted tiles purified, nothing else" % [Config.PURIFY_CHANNEL_TICKS, want.size()])
	check(arena.spawn_cells.size() < ring, "the heretics' spawn ring shrank on the host (%d -> %d)" % [ring, arena.spawn_cells.size()])
	check_eq(r.host.purified, want.size(), "the host counted them")
	# Holy water spam: ten USEs in a tick, one pour.
	var pour: Array[Vector2i] = pour_spot(data, ZONE_EDGE)
	if not check(not pour.is_empty(), "corruption left to pour holy water on near the edge"):
		_free_rig(r)
		return
	m.player.teleport(feet_in(pour[0]))
	var ash: Vector2i = pour[1]
	busy = m.refused(SessionHost.WHY_BUSY)
	for i: int in 10:
		run_one(r, m, _use(Config.MAP_SURFACE, ash, water, 128))
	run_empty(r, m, PlayerSim.action_ticks(Config.HOLY_WATER_ANIM))
	check(m.refused(SessionHost.WHY_BUSY) - busy == 9 and m.player.inventory.count_of(Purify.HOLY_WATER) == 3,
		"ten holy water USEs in a tick: one pour (one used), nine busy")
	_free_rig(r)


func _check_altar_requests() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var home: Rect2i = data.altar_rect
	var below: Vector2i = Vector2i(home.position.x + 1, home.end.y)  # the tile just south of the altar's middle
	var c: Client = await _join_quiet(r, 101, "paladin", feet_in(below))
	var m: NetMember = hm(r, c)
	var at: Vector2i = below + Vector2i(0, -1)
	# Too early: one frame of F.
	refill(m)
	run_one(r, m, lift_frame(at))
	check(m.refused(AltarMove.WHY_HOLD) == 1 and data.altar_rect == home, "an ALTAR_LIFT after one frame of F: refused")
	# From two tiles: M5-fix, F held where no altar tile is in reach counts nothing; in reach of one, a request aimed at
	# another (the top row) is out of reach.
	m.player.teleport(feet_in(below + Vector2i(0, 1)))
	lift_altar(r, m, at)
	check(m.refused(AltarMove.WHY_HOLD) == 2 and data.altar_rect == home, "from two tiles away: F held there counts nothing")
	m.player.teleport(feet_in(below))
	lift_altar(r, m, Vector2i(below.x, home.position.y))
	check(m.refused(WorldItems.WHY_REACH) == 1 and data.altar_rect == home, "aimed at a tile out of reach: refused")
	# Putting it down without carrying it.
	run_one(r, m, place_frame(below + Vector2i(0, 2)))
	check_eq(m.refused(AltarMove.WHY_NOT_CARRYING), 1, "an ALTAR_PLACE without the altar: refused")
	# Into the dungeon: a member down there cannot lift it (the altar stays on the surface), the carrier cannot travel.
	var d: Client = await _join_quiet(r, 102, "miner", feet_in(below + Vector2i(3, 2)))
	var md: NetMember = hm(r, d)
	r.host.move_to_map(md, Config.MAP_DUNGEON)
	var dl: NetProtocol.InputFrame = lift_frame(Aim.feet_cell(md.player.sim_position) + Vector2i(0, -1))
	dl.map = Config.MAP_DUNGEON
	for i: int in Config.ALTAR_PICKUP_HOLD_TICKS - 1:
		run_one(r, md, held_frame())
	refill(md)
	run_one(r, md, dl)
	check(md.refused(AltarMove.WHY_HOLD) == 1 and md.altar_hold == 0 and data.altar_rect == home,
		"an ALTAR_LIFT in the dungeon: refused (M5-fix: no altar in reach there, F held counts nothing)")
	# Lifted properly.
	m.player.teleport(feet_in(below))
	var edits: int = r.s.log_for(Config.MAP_SURFACE).size()
	lift_altar(r, m, at)
	check(m.player.carrying_altar and not data.altar_rect.has_area() and r.s.log_for(Config.MAP_SURFACE).size() == edits + 9,
		"F held %d frames, then ALTAR_LIFT: carried, nine edits" % Config.ALTAR_PICKUP_HOLD_TICKS)
	check_eq(r.host.altar_home, home, "the host keeps where it was picked up")
	# What a carrier may not do.
	refill(m)
	var carrying: int = m.refused(AltarMove.WHY_CARRYING)
	run_one(r, m, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, SurfaceGen.entrance_rect(data).position))
	run_one(r, m, channel_frame())
	run_one(r, m, _use(Config.MAP_SURFACE, below + Vector2i(1, 0), Config.START_WEAPON_SLOT, 0))
	run_one(r, m, _throw(Config.MAP_SURFACE, below + Vector2i(1, 0), 0, Vector2(500, 500)))
	check_eq(m.refused(AltarMove.WHY_CARRYING) - carrying, 4, "the carrier: travel (into the dungeon), channel, use, throw refused")
	# On the entrance's arrival point (a spot where players appear).
	var reserved: Array[Vector2i] = spot_refused(data, Aim.feet_cell(DungeonGen.arrival_below(SurfaceGen.entrance_rect(data))),
		WorldItems.WHY_RESERVED)
	if check(not reserved.is_empty(), "a footprint over the entrance's arrival point exists near it"):
		m.player.teleport(feet_in(reserved[0]))
		refill(m)
		run_one(r, m, place_frame(reserved[1]))
		check(m.refused(WorldItems.WHY_RESERVED) == 1 and m.player.carrying_altar, "put down over the arrival point: refused")
	# On corruption, on a body.
	var ash: Array[Vector2i] = spot_refused(data, ZONE_EDGE, AltarMove.WHY_CORRUPTED)
	if check(not ash.is_empty(), "a footprint on the ash exists near the zone's edge"):
		m.player.teleport(feet_in(ash[0]))
		refill(m)
		run_one(r, m, place_frame(ash[1]))
		check_eq(m.refused(AltarMove.WHY_CORRUPTED), 1, "put down on corruption: refused")
	m.player.teleport(feet_in(ALTAR_FEET))
	var body: Client = await _join_quiet(r, 103, "archer", feet_in(ALTAR_NEW + Vector2i(1, 1)))
	refill(m)
	run_one(r, m, place_frame(ALTAR_AIM))
	check(m.refused(WorldItems.WHY_BODY) == 1 and m.player.carrying_altar, "put down on an archer's feet: refused")
	# Spam: ten ALTAR_PLACEs in a tick (still on the body): four checked, six rate.
	refill(m)
	var rate: int = m.refused("rate")
	for i: int in 10:
		run_one(r, m, place_frame(ALTAR_AIM))
	check_eq(m.refused("rate") - rate, 6, "ten ALTAR_PLACEs in a tick: six rate")
	hm(r, body).player.teleport(feet_in(ALTAR_NEW + Vector2i(1, 5)))
	refill(m)
	run_one(r, m, place_frame(ALTAR_AIM))
	check(not m.player.carrying_altar and data.altar_rect == Rect2i(ALTAR_NEW, Config.ALTAR_FOOTPRINT),
		"put down on open ground: the altar at %s" % data.altar_rect)
	check(r.surface.spawn_point(0) == AltarMove.slot_feet(data.altar_rect)[0] and r.surface.is_in_safe_zone(
		AltarMove.centre_px(data.altar_rect)) and not r.surface.is_in_safe_zone(AltarMove.centre_px(home)),
		"the spawn slots and the safe zone moved with it")
	# The carrier goes down: set down near it; the carrier leaves: set down too.
	m.player.teleport(feet_in(ALTAR_FEET))
	lift_altar(r, m, ALTAR_AIM)
	check(m.player.carrying_altar, "lifted again")
	m.player.take_hit(Config.PLAYER_HP_MAX)
	r.host._check_carriers()
	check(not m.player.carrying_altar and data.altar_rect.has_area(),
		"the carrier went down: set down at %s" % data.altar_rect)
	var leaver: Client = await _join_quiet(r, 104, "miner", feet_in(below))
	var ml: NetMember = hm(r, leaver)
	ml.player.teleport(feet_in(Vector2i(data.altar_rect.position.x + 1, data.altar_rect.end.y)))
	lift_altar(r, ml, Vector2i(data.altar_rect.position.x + 1, data.altar_rect.end.y - 1))
	check(ml.player.carrying_altar, "a miner carries it")
	r.host.on_peer_disconnected(104)
	check(data.altar_rect.has_area() and not r.s.members.has(ml.slot), "the carrier left: the altar came down (%s)" % data.altar_rect)
	_free_rig(r)


## M5-fix: what counts toward a lift on the host (NetMember.altar_hold) and on the client (SessionHost.hold_altar): F held
## far from the altar never counts (a client cannot hold F anywhere and lift on its first frame in reach), nor F held
## beside a downed ally (that is a revive), nor during a channel; a carrier's F next to the ash is no CHANNEL.
func _check_hold_rules() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var home: Rect2i = data.altar_rect
	var below: Vector2i = Vector2i(home.position.x + 1, home.end.y)
	var at: Vector2i = below + Vector2i(0, -1)
	var c: Client = await _join_quiet(r, 101, "miner", feet_in(below + Vector2i(0, 8)))
	var m: NetMember = hm(r, c)
	for i: int in Config.ALTAR_PICKUP_HOLD_TICKS + 10:
		run_one(r, m, held_frame())
	check_eq(m.altar_hold, 0, "F held 8 tiles from the altar: the host counts nothing")
	m.player.teleport(feet_in(below))
	refill(m)
	run_one(r, m, lift_frame(at))
	check(m.refused(AltarMove.WHY_HOLD) == 1 and data.altar_rect == home and not m.player.carrying_altar,
		"then one ALTAR_LIFT in reach: refused (the 2 s are counted in reach)")
	# A downed archer beside the miner: F held there revives it; no count until it is up.
	var d: Client = await _join_quiet(r, 102, "archer", feet_in(below) + Vector2(18, 0))
	var md: NetMember = hm(r, d)
	md.player.take_hit(Config.PLAYER_HP_MAX)
	check_eq(md.player.vitals.life, Vitals.Life.DOWN, "the archer is down beside the miner")
	for i2: int in Config.ALTAR_PICKUP_HOLD_TICKS + 10:
		run_one(r, m, held_frame())
	check_eq(m.altar_hold, 0, "F held beside a downed ally: the host counts nothing (a revive)")
	refill(m)
	run_one(r, m, lift_frame(at))
	check(m.refused(AltarMove.WHY_HOLD) == 2 and data.altar_rect == home, "its ALTAR_LIFT: refused")
	# The client's own count, by the same rule (a Player of its own, as the client has it).
	var q: Player = Player.new()
	q.setup(data, "miner", feet_in(below))
	q.purify_on = true
	q.aim_cell = at
	var alone: Array[Player] = [q]
	var with_down: Array[Player] = [q, md.player]
	SessionHost.hold_altar(q, held_frame(), alone)
	check_eq(q.altar_hold_ticks, 1, "the client counts F held on the altar")
	SessionHost.hold_altar(q, held_frame(), with_down)
	check_eq(q.altar_hold_ticks, 0, "not beside a downed ally (starts over)")
	q.channel_tick = 5
	SessionHost.hold_altar(q, held_frame(), alone)
	check_eq(q.altar_hold_ticks, 0, "not while its channel runs")
	q.channel_tick = 0
	q.free()
	# A carrying paladin's F next to the ash is no CHANNEL (wants_channel), and neither is F aimed at the altar.
	var pal: Player = Player.new()
	pal.setup(data, "paladin", feet_in(ZONE_EDGE))
	pal.purify_on = true
	check(SessionHost.wants_channel(pal, ZONE_EDGE + Vector2i(-1, 0)), "the paladin's F next to the ash: CHANNEL")
	pal.set_carrying_altar(true)
	check(not SessionHost.wants_channel(pal, ZONE_EDGE + Vector2i(-1, 0)), "carrying the altar: no CHANNEL")
	pal.free()
	var copy: WorldData = WorldSnapshot.decode_raw(WorldSnapshot.raw_bytes(data))
	var spot: Array = AltarTest.by_zone(copy)
	if check(not spot.is_empty(), "a place by a zone"):
		var zr: Rect2i = spot[0]
		var zt: Vector2i = spot[1]
		var za: Vector2i = spot[2]
		var zg: Vector2i = spot[3]
		AltarTest.apply(copy, AltarMove.pickup_edits(copy))
		AltarTest.apply(copy, AltarMove.place_edits(zr))
		var by: Player = Player.new()
		by.setup(copy, "paladin", feet_in(zt))
		by.purify_on = true
		check(not SessionHost.wants_channel(by, za) and SessionHost.wants_channel(by, zg),
			"by the moved altar: F aimed at it is no CHANNEL, F aimed beside it is")
		by.free()
	_free_rig(r)


## M5-fix: with the altar moved beside a zone, a paladin client's channel (a hit breaks one: counted and logged on the
## host) and F held on the altar through another: the host counts nothing until it ends, refuses a lift meanwhile, and
## lifts after the hold.
func _check_channel_hold() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	# A hit between two frames (the arena's knife) breaks a channel: counted and logged like any break.
	var hit_pal: Client = await _join_quiet(r, 101, "paladin", feet_in(ZONE_EDGE))
	var mh: NetMember = hm(r, hit_pal)
	run_one(r, mh, channel_frame())
	run_empty(r, mh, 5)
	check(mh.player.channel_tick > 0, "a paladin channels at the zone's edge")
	mh.player.take_hit(1)
	run_empty(r, mh, 3)
	check(mh.player.channel_tick == 0 and mh.combat_count("channel_broken") == 1,
		"a hit broke it: the host counted it (%d)" % mh.combat_count("channel_broken"))
	var spot: Array = AltarTest.by_zone(data)
	if not check(not spot.is_empty(), "a place by a zone"):
		_free_rig(r)
		return
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		r.host.apply_world_edit(e)
	var zr: Rect2i = spot[0]
	var zt: Vector2i = spot[1]
	var za: Vector2i = spot[2]
	for e2: EditLog.WorldEdit in AltarMove.place_edits(zr):
		r.host.apply_world_edit(e2)
	check_eq(data.altar_rect, zr, "the altar by the zone")
	var c: Client = await _join_quiet(r, 102, "paladin", feet_in(zt))
	var m: NetMember = hm(r, c)
	run_one(r, m, channel_frame())
	check_eq(m.player.channel_tick, 1, "the paladin beside the moved altar channels")
	var most: int = 0
	var frames: int = 1
	while m.player.channel_tick > 0 and frames < Config.PURIFY_CHANNEL_TICKS + 10:
		run_one(r, m, held_frame())
		most = maxi(most, m.altar_hold)
		frames += 1
		if frames == Config.ALTAR_PICKUP_HOLD_TICKS + 5:
			refill(m)
			run_one(r, m, lift_frame(za))
			frames += 1
	check(most <= 1 and not m.player.carrying_altar and data.altar_rect == zr and r.host.purified > 0,
		"F held through the channel: the host counted at most %d, nothing lifted, the channel purified (%d)" % [most,
		r.host.purified])
	check_eq(m.refused(AltarMove.WHY_HOLD), 1, "an ALTAR_LIFT during the channel: refused")
	lift_altar(r, m, za)
	check(m.player.carrying_altar and not data.altar_rect.has_area(), "after the channel, held on: lifted")
	_free_rig(r)


## M5-fix: while the altar is carried, the spots where joiners appear (its spawn slots where it was picked up) are kept
## clear like a standing altar's: a table over one is refused "where players appear"; a joiner stands; a slot blocked
## past the rules is skipped. A client's world keeps where it stood and puts it back there (Main.restore_altar_at, a
## client that lost the host while someone else carried it).
func _check_join_while_carried() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var home: Rect2i = data.altar_rect
	var watcher: Client = _join(r, 101, "archer", feet_in(Vector2i(home.position.x + 1, home.end.y + 4)), false)
	var hp: Player = r.s.local.player
	hp.teleport(feet_in(Vector2i(home.position.x - 1, home.position.y + 1)))
	lift_altar(r, r.s.local, Vector2i(home.position.x, home.position.y + 1))
	_tick(r, 3)
	check(hp.carrying_altar and not data.altar_rect.has_area(), "the host carries the altar")
	var slots: Array[Vector2] = AltarMove.slot_feet(home)
	check_eq(r.host.carried_reserved_feet(), slots, "its spawn slots where it was picked up are kept clear meanwhile")
	# A table over one of them: the world's own rule would allow it; the host refuses it.
	var found: Array = []
	for s: int in slots.size():
		var sc: Vector2i = Aim.feet_cell(slots[s])
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var cell: Vector2i = sc + Vector2i(dx, dy)
				for n: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var f: Vector2i = cell + n
					if not found.is_empty() or not Movement.can_stand(data, feet_in(f)):
						continue
					var inv: Inventory = Inventory.new()
					inv.add(&"alchemy_table", 1)
					if not WorldItems.place(data, feet_in(f), inv, 0, cell).ok():
						continue
					inv.add(&"alchemy_table", 1)
					if WorldItems.place(data, feet_in(f), inv, 0, cell, [] as Array[Vector2], slots).why == WorldItems.WHY_RESERVED:
						found = [f, cell, s]
	if check(not found.is_empty(), "a table spot over a home slot that the world alone would allow"):
		var ft: Vector2i = found[0]
		var fc: Vector2i = found[1]
		var mc: Client = await _join_quiet(r, 102, "miner", feet_in(ft))
		var mm: NetMember = hm(r, mc)
		mm.player.teleport(feet_in(ft))
		give(mm, &"alchemy_table", 1)
		refill(mm)
		run_one(r, mm, _use(Config.MAP_SURFACE, fc, slot_of(mm.player.inventory, &"alchemy_table"), 0))
		check(mm.refused(WorldItems.WHY_RESERVED) == 1 and data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_ALCHEMY) == 0,
			"a table over a spot where joiners appear while it is carried: refused")
		# Past the rules (put straight into the data), the joiner's slot is skipped for a standable one.
		var k: int = found[2]
		var blocked: Vector2i = Aim.feet_cell(slots[k])
		data.put_placeable(Rect2i(blocked - Vector2i(1, 0), Vector2i(3, 1)), WorldData.PLACEABLE_ALCHEMY)
		check(not Movement.can_stand(data, slots[k]), "slot %d blocked past the rules" % k)
		var sf: Vector2 = r.host.spawn_feet(k)
		check(sf != slots[k] and Movement.can_stand(data, sf), "spawn_feet skips it for a standable spot (%s)" % sf)
		var joiner: Client = _join(r, 103, "cleric", null, false)
		var jm: NetMember = hm(r, joiner)
		check(Movement.can_stand(data, jm.player.sim_position), "a joiner while it is carried stands where it appears (%s)" % jm.player.sim_position)
		data.put_placeable(Rect2i(blocked - Vector2i(1, 0), Vector2i(3, 1)), WorldData.PLACEABLE_NONE)
	# The client's world: no altar, but where it stood is kept; put back there when it plays on alone.
	check(not watcher.surface.data.altar_rect.has_area() and watcher.surface.last_altar_rect == home,
		"the client's world has no altar and keeps where it stood")
	var none: Array[Vector2] = []
	var got: Rect2i = Main.restore_altar_at(watcher.surface, watcher.s.local.player.sim_position, none)
	check(got == home and watcher.surface.data.altar_rect == home and watcher.surface.is_in_safe_zone(AltarMove.centre_px(home)),
		"playing on alone: the altar back where it stood (its light, its safe zone)")
	_free_rig(r)


# --- flows ---------------------------------------------------------------------------------------------

## The host (herbalist) and a paladin client farm one field: the client tills a lit tile, plants healing (anyone, ●
## R37) and waters it; the host plants poison on the M1 soil and waters it. With --test-crop-ticks 30 both ripen; the
## client sees every stage of both crops arrive as edits. The host harvests the client's crop: FINE; the client harvests
## the host's: COMMON (the harvester decides). Both worlds agree at every stage.
func _check_farming_flow() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	r.host.farm_of(Config.MAP_SURFACE).stage_ticks_base = 30
	var data: WorldData = r.surface.data
	var hp: Player = r.s.local.player
	hp.teleport(feet_in(HOST_FARM_FEET))
	give(r.s.local, &"seed_poison", 2)
	give(r.s.local, &"watering_can", 1)
	var c: Client = _join(r, 101, "paladin", feet_in(FARM_FEET), false)
	var m: NetMember = hm(r, c)
	give(m, &"hoe", 1)
	give(m, &"seed_healing", 2)
	give(m, &"watering_can", 1)
	give(m, &"sickle", 1)
	_tick(r, 2)
	var inv: Inventory = c.s.local.player.inventory
	check(slot_of(inv, &"hoe") >= 0 and slot_of(inv, &"sickle") >= 0, "the client got its tools (host inventory)")
	# The client: hoe, seed, can on its tile east of it.
	press(r, null, c, _select(slot_of(inv, &"hoe")))
	press(r, null, c, click_at(centre_of(CLIENT_FIELD)))
	_tick(r, PlayerSim.action_ticks(RigData.Anim.HOE) + 2)
	check(data.terrain_at(CLIENT_FIELD) == Terrain.SOIL and c.surface.data.terrain_at(CLIENT_FIELD) == Terrain.SOIL,
		"the client's hoe tilled its tile on the host, and it sees the soil")
	press(r, null, c, _select(slot_of(inv, &"seed_healing")))
	press(r, null, c, click_at(centre_of(CLIENT_FIELD)))
	_tick(r, 2)
	press(r, null, c, _select(slot_of(inv, &"watering_can")))
	press(r, null, c, click_at(centre_of(CLIENT_FIELD)))
	# The host: poison on the M1 soil, watered.
	hp.inventory.select(slot_of(hp.inventory, &"seed_poison"))
	press(r, click_at(centre_of(HOST_FIELD)))
	hp.inventory.select(slot_of(hp.inventory, &"watering_can"))
	press(r, click_at(centre_of(HOST_FIELD)))
	var seen_client: Array[int] = []
	var seen_host: Array[int] = []
	var differ: int = 0
	var t: int = 0
	while t < 600:
		_tick(r)
		t += 1
		var a: Farming.Field = Farming.field_at(c.surface.data, CLIENT_FIELD)
		var b: Farming.Field = Farming.field_at(c.surface.data, HOST_FIELD)
		if a != null and (seen_client.is_empty() or seen_client.back() != a.stage):
			seen_client.append(a.stage)
		if b != null and (seen_host.is_empty() or seen_host.back() != b.stage):
			seen_host.append(b.stage)
		if c.surface.data.content_hash() != data.content_hash():
			differ += 1
		if a != null and a.ripe() and b != null and b.ripe():
			break
	check_eq(seen_client, [0, 1, 2, 3, 4], "the client saw its healing crop grow 0..4 (edits)")
	check_eq(seen_host, [0, 1, 2, 3, 4], "and the host's poison crop")
	check(differ <= 2 * (seen_client.size() + seen_host.size()), "its world = the host's but for the tick an edit is on its way (%d ticks)" % differ)
	var fast: Farming.Field = Farming.field_at(data, HOST_FIELD)
	check(fast != null and fast.fast and fast.kind == Farming.KIND_POISON, "the herbalist's poison crop (planted fast)")
	# The host harvests the client's crop: FINE. The client harvests the host's: COMMON.
	hp.teleport(feet_in(CLIENT_FIELD + Vector2i(1, 1)))
	hp.inventory.select(Config.START_WEAPON_SLOT)
	_tick(r, 2)
	press(r, click_at(centre_of(CLIENT_FIELD)))
	_tick(r, PlayerSim.action_ticks(RigData.Anim.SICKLE) + 2)
	check_eq(hp.inventory.count_of(&"wild_healing", ItemDB.Grade.FINE), Config.CROP_HARVEST_HERBS,
		"the herbalist host cut the paladin's crop: %d FINE healing herbs" % Config.CROP_HARVEST_HERBS)
	press(r, null, c, _select(slot_of(inv, &"sickle")))
	press(r, null, c, click_at(centre_of(HOST_FIELD)))
	_tick(r, PlayerSim.action_ticks(RigData.Anim.SICKLE) + 3)
	check(m.player.inventory.count_of(&"wild_poison", ItemDB.Grade.COMMON) == Config.CROP_HARVEST_HERBS
		and m.player.inventory.count_of(&"seed_poison") == Config.CROP_HARVEST_SEEDS,
		"the paladin cut the herbalist's crop: COMMON poison herbs and a seed (%s)" % m.player.inventory.describe())
	check_eq(inv.describe(), m.player.inventory.describe(), "the client's inventory = the host's copy")
	check_eq(c.surface.data.content_hash(), data.content_hash(), "both worlds the same at the end")
	check(Farming.field_at(data, CLIENT_FIELD) != null and Farming.field_at(data, CLIENT_FIELD).kind == Farming.KIND_NONE,
		"the cut tiles are bare soil (wet)")
	check_prediction("farming / paladin", c)
	_free_rig(r)


## A paladin client at the north zone's edge presses F with nothing to pick up: its channel starts at once in its
## prediction (a CHANNEL request), the host runs it from its frames and purifies its disc when it is done; an archer
## client sees it channel. The spawn ring shrinks on the host. Then the paladin pours holy water.
func _check_channel_flow() -> void:
	var r: Rig = _rig("cleric")
	await await_frames(1)
	var data: WorldData = r.surface.data
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	arena.sync_world()
	var ring: int = arena.spawn_cells.size()
	var c: Client = _join(r, 101, "paladin", feet_in(ZONE_EDGE), false)
	var o: Client = _join(r, 102, "archer", feet_in(ZONE_EDGE + Vector2i(2, 1)), false)
	var m: NetMember = hm(r, c)
	give(m, Purify.HOLY_WATER, 3)
	_tick(r, 2)
	var want: Array[Vector2i] = disc_corrupted(data, ZONE_EDGE)
	var corrupted: int = Purify.corrupted_count(data)
	var pick: NetBot.Action = NetBot.Action.new()
	pick.mouse = centre_of(ZONE_EDGE + Vector2i(-1, 0))
	pick.aiming = true
	pick.op = NetProtocol.InputFrame.new()
	pick.op.op = NetProtocol.Op.PICKUP
	press(r, null, c, pick)
	check_eq(c.s.client.prediction.sim.channel_tick, 1, "F with nothing to pick up: the channel starts at once in the prediction")
	_tick(r, 2)
	check(m.player.channel_tick > 0, "and on the host (CHANNEL)")
	var seen_by_other: int = 0
	var shown_off: int = 0
	var host_ch: Dictionary[int, int] = {}
	var t: int = 0
	while t < Config.PURIFY_CHANNEL_TICKS + 20 and r.host.purified == 0:
		_tick(r)
		t += 1
		host_ch[r.s.tick] = m.player.channel_tick
		draw_at_rig_time(r, o)
		var mine: NetMember = o.s.members.get(m.slot, null)
		if mine != null and mine.player.channel_tick > 0:
			seen_by_other += 1
			# Drawn 100 ms behind (Config.NET_INTERP_DELAY_MS), counted on between batches like an action.
			var then: int = host_ch.get(r.s.tick - roundi(SessionClient.interp_delay_ticks()), -1)
			if then > 0 and then != mine.player.channel_tick:
				shown_off += 1
	_tick(r, 3)
	check_eq(r.host.purified, want.size(), "the host purified the disc's %d corrupted tiles" % want.size())
	check_eq(Purify.corrupted_count(data), corrupted - want.size(), "nothing else")
	check(arena.spawn_cells.size() < ring, "the heretics' spawn ring shrank on the host (%d -> %d)" % [ring, arena.spawn_cells.size()])
	for x: Client in [c, o]:
		check_eq(x.surface.data.content_hash(), data.content_hash(), "%s: the purified world = the host's" % x.s.local_class())
		check_eq(x.s.client.purify_flashes, want.size(), "%s: flashed each purified tile" % x.s.local_class())
	check(seen_by_other > Config.PURIFY_CHANNEL_TICKS / 2 and shown_off == 0,
		"the archer saw the paladin channel (%d frames), each at the host's tick of it 100 ms before (%d off)" % [seen_by_other, shown_off])
	var channels: int = m.ops_done.get("channel", 0)
	check_eq(channels, 1, "one channel counted on the host")
	check_prediction("channel / paladin", c)
	# Holy water: the client walks three tiles west (to the purified disc's edge) and pours on the ash next to it; the
	# host purifies its 3x3 and the client's count goes down.
	var west: NetBot.Action = NetBot.Action.new()
	west.dir = Vector2i(-1, 0)
	c.action = west
	_tick(r, roundi(3.0 * Config.TILE / (Config.WALK_SPEED / Config.NET_TICK_RATE)))
	c.action = null
	_tick(r, 4)
	var cell: Vector2i = Vector2i(-1, -1)
	var feet: Vector2i = Aim.feet_cell(m.player.sim_position)
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if cell.x < 0 and Vector2i(dx, dy) != Vector2i.ZERO \
					and Purify.holy_water_refusal(data, m.player.sim_position, feet + Vector2i(dx, dy)).is_empty():
				cell = feet + Vector2i(dx, dy)
	if check(cell.x >= 0, "corruption still in reach around the paladin for holy water"):
		var before: int = Purify.corrupted_count(data)
		press(r, null, c, _select(slot_of(c.s.local.player.inventory, Purify.HOLY_WATER)))
		press(r, null, c, click_at(centre_of(cell)))
		_tick(r, PlayerSim.action_ticks(Config.HOLY_WATER_ANIM) + 3)
		check(Purify.corrupted_count(data) < before and c.s.local.player.inventory.count_of(Purify.HOLY_WATER) == 2,
			"the client's holy water purified %d tiles, one used (its inventory from the host)" % (before - Purify.corrupted_count(data)))
		check_eq(c.surface.data.content_hash(), data.content_hash(), "the client's world = the host's")
		check_prediction("holy water / paladin", c)
	_free_rig(r)


## The host (herbalist) lifts the altar while an archer client stands in its light, 3 tiles south of it, a heretic
## waiting outside: while it stands, the heretic never cuts it. Carried: the client's world has no altar, it draws the
## host carrying. The host puts it down 13 tiles west: the client's light, safe zone, spawn slot (its respawn) follow,
## and the heretic now comes for the client standing outside the new light. The client dies and respawns at the new slot,
## predicted.
func _check_altar_flow() -> void:
	var start: Dictionary[String, int] = {"archer": 12}
	var r: Rig = _rig(HERB, false, start)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var home: Rect2i = data.altar_rect
	var spot: Vector2i = Vector2i(home.position.x + 1, home.end.y + 4)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(feet_in(spot + Vector2i(0, 6)))
	var c: Client = _join(r, 101, "archer", feet_in(spot), false)
	var m: NetMember = hm(r, c)
	check(r.surface.is_in_safe_zone(m.player.sim_position), "the archer stands in the altar light")
	_tick(r, 300)
	check(m.combat_count("hurt") == 0 and m.player.vitals.hp == 12, "in the light the heretic never cuts it (%s)" % HereticSim.STATE_NAMES[h.state])
	# The host lifts it.
	var hp: Player = r.s.local.player
	var below: Vector2i = Vector2i(home.position.x - 1, home.position.y + 1)
	hp.teleport(feet_in(below))
	var hold: NetBot.Action = NetBot.Action.new()
	hold.interact = true
	hold.aiming = true
	hold.mouse = centre_of(below + Vector2i(1, 0))
	r.action = hold
	tick_until(r, func() -> bool: return hp.carrying_altar, Config.ALTAR_PICKUP_HOLD_TICKS + 10)
	r.action = null
	_tick(r, 12)
	check(hp.carrying_altar and not data.altar_rect.has_area(), "the host carries the altar (F held %d ticks)" % Config.ALTAR_PICKUP_HOLD_TICKS)
	check(not c.surface.data.altar_rect.has_area() and c.surface.altar == null and not c.surface.is_in_safe_zone(m.player.sim_position),
		"the client: no altar, no light, no safe zone")
	draw_at_rig_time(r, c)
	var host_on_c: NetMember = c.s.members.get(r.s.local.slot, null)
	check(host_on_c != null and host_on_c.player.carrying_altar and host_on_c.player.altar_mark.visible,
		"the client draws the host carrying it")
	# Put down 13 tiles west.
	hp.teleport(feet_in(ALTAR_FEET))
	_tick(r, 2)
	press(r, click_at(centre_of(ALTAR_AIM)))
	_tick(r, 2)
	var moved: Rect2i = Rect2i(ALTAR_NEW, Config.ALTAR_FOOTPRINT)
	check(data.altar_rect == moved and not hp.carrying_altar, "the host put it down at %s" % data.altar_rect)
	check(c.surface.data.altar_rect == moved and c.surface.altar != null, "the client's world: the altar there")
	check(c.surface.is_in_safe_zone(AltarMove.centre_px(moved)) and not c.surface.is_in_safe_zone(m.player.sim_position),
		"its safe zone follows (the archer is outside it now)")
	check_eq(c.s.client.prediction.respawn_feet(), r.surface.spawn_point(m.slot), "its respawn slot follows (prediction)")
	check(WorldItems.reserved_feet(c.surface.data).has(r.surface.spawn_point(0)), "and the spots placeables keep clear")
	# The heretic comes for the archer now; it goes down, gives up, respawns at the new slot.
	var hit_tick: int = tick_until(r, func() -> bool: return m.player.vitals.life != Vitals.Life.ALIVE, 900)
	check(hit_tick < 900 and m.combat_count("hurt") >= 1, "outside the new light the heretic cut it down (%d ticks)" % hit_tick)
	c.action = holding_f()
	tick_until(r, func() -> bool: return m.player.vitals.life == Vitals.Life.DEAD, Config.GIVE_UP_HOLD_TICKS + 30)
	c.action = null
	arena.hit_heretic(h, Config.HERETIC_HP)
	tick_until(r, func() -> bool: return m.player.vitals.life == Vitals.Life.ALIVE, Config.RESPAWN_TICKS + 60)
	_tick(r, 6)
	check_eq(m.player.sim_position, r.surface.spawn_point(m.slot), "it respawned at its slot around the moved altar")
	check_eq(c.s.client.prediction.sim.pos, m.player.sim_position, "where its prediction put it")
	check(c.s.client.prediction.respawns >= 1, "the respawn was predicted (%d)" % c.s.client.prediction.respawns)
	check_prediction("altar move / archer", c)
	_free_rig(r)


## The dead wait while the altar is carried: a client dies, the host lifts the altar before its respawn time; it stays
## dead past that (on the host and in its prediction); the host puts it down and it comes back at its new slot.
func _check_respawn_waits() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var home: Rect2i = data.altar_rect
	var c: Client = _join(r, 101, "miner", feet_in(Vector2i(home.position.x + 1, home.end.y + 2)), false)
	var m: NetMember = hm(r, c)
	m.player.take_hit(Config.PLAYER_HP_MAX)
	c.action = holding_f()
	tick_until(r, func() -> bool: return m.player.vitals.life == Vitals.Life.DEAD, Config.GIVE_UP_HOLD_TICKS + 30)
	c.action = null
	check_eq(m.player.vitals.life, Vitals.Life.DEAD, "the miner gave up: dead")
	var hp: Player = r.s.local.player
	var mh: NetMember = r.s.local
	hp.teleport(feet_in(Vector2i(home.position.x - 1, home.position.y + 1)))
	lift_altar(r, mh, Vector2i(home.position.x, home.position.y + 1))
	check(hp.carrying_altar, "the host carries the altar")
	_tick(r, Config.RESPAWN_TICKS + 60)
	check(m.player.vitals.life == Vitals.Life.DEAD and m.respawn_pending, "past its respawn time it waits (no altar)")
	check_eq(c.s.client.prediction.sim.vit.life, Vitals.Life.DEAD, "its prediction waits too")
	hp.teleport(feet_in(ALTAR_FEET))
	press(r, click_at(centre_of(ALTAR_AIM)))
	_tick(r, 8)
	check(m.player.vitals.alive() and m.player.sim_position == r.surface.spawn_point(m.slot),
		"the altar down: it respawned at its new slot (%s)" % m.player.sim_position)
	check_eq(c.s.client.prediction.sim.pos, m.player.sim_position, "the client has it there")
	_free_rig(r)


## A late joiner after the altar moved away from a field: it gets the fields with their withered crops and the moved
## altar (its light, safe zone and spawn slot); a second joiner while the host carries it appears around the place it
## was picked up and sees the host carrying it.
func _check_late_join_fields() -> void:
	var r: Rig = _rig(HERB)
	await await_frames(1)
	var data: WorldData = r.surface.data
	var farm: Farm = r.host.farm_of(Config.MAP_SURFACE)
	var entries: Array[Array] = [[Vector2i(57, 45), Farming.KIND_HEALING, 2, true, false],
		[Vector2i(58, 45), Farming.KIND_BUFF, 3, false, true], [Vector2i(59, 46), Farming.KIND_POISON, 4, true, true],
		[Vector2i(64, 43), Farming.KIND_HEALING, 1, false, false]]
	Main.put_test_fields(r.surface, farm, entries)
	var hp: Player = r.s.local.player
	var home: Rect2i = data.altar_rect
	hp.teleport(feet_in(Vector2i(home.position.x - 1, home.position.y + 1)))
	lift_altar(r, r.s.local, Vector2i(home.position.x, home.position.y + 1))
	hp.teleport(feet_in(ALTAR_FEET))
	refill(r.s.local)
	run_one(r, r.s.local, place_frame(ALTAR_AIM))
	_tick(r, 3)
	var f: Dictionary = fields(data)
	var withered: int = f.get("withered", 0)
	check(data.altar_rect == Rect2i(ALTAR_NEW, Config.ALTAR_FOOTPRINT) and withered >= 3,
		"the altar moved west; the old fields withered (%s)" % [f])
	var late: Client = _join(r, 103, "cleric", null, false)
	check_eq(late.surface.data.content_hash(), data.content_hash(), "the late joiner's world = the host's")
	check_eq(fields(late.surface.data), f, "its fields, withered crops included = the host's")
	check(late.surface.data.altar_rect == data.altar_rect and late.surface.is_in_safe_zone(AltarMove.centre_px(data.altar_rect)),
		"the moved altar and its light")
	check_eq(late.s.local.player.sim_position, r.surface.spawn_point(hm(r, late).slot), "it appeared at its slot around the moved altar")
	check_eq(late.s.client.prediction.respawn_feet(), r.surface.spawn_point(hm(r, late).slot), "its respawn slot there")
	# While carried: a joiner appears around where it was picked up and sees the host carry it.
	var moved: Rect2i = data.altar_rect
	hp.teleport(feet_in(Vector2i(moved.position.x - 1, moved.position.y + 1)))
	lift_altar(r, r.s.local, Vector2i(moved.position.x, moved.position.y + 1))
	_tick(r, 2)
	var late2: Client = _join(r, 104, "miner", null, false)
	var s2: int = hm(r, late2).slot
	check_eq(late2.s.local.player.sim_position, AltarMove.slot_feet(moved)[s2 % Config.SPAWN_SLOTS.size()],
		"a joiner while it is carried appears at its slot around where it was picked up")
	check(not late2.surface.data.altar_rect.has_area(), "its world has no altar")
	_tick(r, 4)
	draw_at_rig_time(r, late2)
	var host_seen: NetMember = late2.s.members.get(r.s.local.slot, null)
	check(host_seen != null and host_seen.player.carrying_altar, "it draws the host carrying the altar")
	_free_rig(r)


## Four players with a 3-tick delay: the host (herbalist) plants poison and waters it, a paladin channels at the zone's
## edge, an archer tills and plants healing, a miner waters the archer's tile; everyone's world and positions agree, the
## predictions only took the host's events.
func _check_four_fields() -> void:
	var r: Rig = _rig(HERB)
	r.delay = 3
	await await_frames(1)
	r.host.farm_of(Config.MAP_SURFACE).stage_ticks_base = 40
	var data: WorldData = r.surface.data
	var hp: Player = r.s.local.player
	hp.teleport(feet_in(HOST_FARM_FEET))
	give(r.s.local, &"seed_poison", 1)
	give(r.s.local, &"watering_can", 1)
	var pal: Client = _join(r, 101, "paladin", feet_in(ZONE_EDGE), false)
	var arc: Client = _join(r, 102, "archer", feet_in(FARM_FEET), false)
	var mnr: Client = _join(r, 103, "miner", feet_in(CLIENT_FIELD + Vector2i(1, 0)), false)
	give(hm(r, arc), &"hoe", 1)
	give(hm(r, arc), &"seed_healing", 1)
	give(hm(r, mnr), &"watering_can", 1)
	_tick(r, 10)
	var pick: NetBot.Action = NetBot.Action.new()
	pick.mouse = centre_of(ZONE_EDGE + Vector2i(-1, 0))
	pick.aiming = true
	pick.op = NetProtocol.InputFrame.new()
	pick.op.op = NetProtocol.Op.PICKUP
	press(r, null, pal, pick)
	var ainv: Inventory = arc.s.local.player.inventory
	press(r, null, arc, _select(slot_of(ainv, &"hoe")))
	press(r, null, arc, click_at(centre_of(CLIENT_FIELD)))
	hp.inventory.select(slot_of(hp.inventory, &"seed_poison"))
	press(r, click_at(centre_of(HOST_FIELD)))
	_tick(r, PlayerSim.action_ticks(RigData.Anim.HOE) + 8)
	press(r, null, arc, _select(slot_of(ainv, &"seed_healing")))
	press(r, null, arc, click_at(centre_of(CLIENT_FIELD)))
	hp.inventory.select(slot_of(hp.inventory, &"watering_can"))
	press(r, click_at(centre_of(HOST_FIELD)))
	_tick(r, 10)
	var minv: Inventory = mnr.s.local.player.inventory
	press(r, null, mnr, _select(slot_of(minv, &"watering_can")))
	press(r, null, mnr, click_at(centre_of(CLIENT_FIELD)))
	_tick(r, Config.PURIFY_CHANNEL_TICKS + 40)
	var crop: Farming.Field = Farming.field_at(data, CLIENT_FIELD)
	check(crop != null and crop.kind == Farming.KIND_HEALING and crop.wet and crop.stage >= 1,
		"four: the archer's healing crop, watered by the miner, grows (%s)" % (crop.describe() if crop != null else "none"))
	check(r.host.purified > 0, "four: the paladin's channel purified (%d)" % r.host.purified)
	# Settle: the crops ripen and stop changing, then everyone agrees.
	_tick(r, 6 * 40 + 20)
	for x: Client in [pal, arc, mnr]:
		check_eq(x.surface.data.content_hash(), data.content_hash(), "four/%s: its world = the host's" % x.s.local_class())
		draw_at_rig_time(r, x)
		check_eq(x.s.positions_hash(), r.s.positions_hash(), "four/%s: positions = the host's (drawn)" % x.s.local_class())
		check_prediction("four/%s" % x.s.local_class(), x)
	_free_rig(r)


# --- traffic ---------------------------------------------------------------------------------------------

## README "측정" (M5c): the host and two clients stand (rest), then the 19 M1 soil tiles hold wet crops growing at the real
## Config times for 75 s (a stage every Config.CROP_STAGE_TICKS, drying after Config.WATER_TICKS: the farm's edits),
## then a paladin client channels once (its frames, its state at 20 Hz, the purified tiles' edits). The host's bytes
## to the clients by message kind per second (ENet payloads), and the edits' peak per tick.
func _measure_fields_traffic() -> void:
	var r: Rig = _rig(HERB)
	r.delay = 1
	await await_frames(1)
	var data: WorldData = r.surface.data
	var a: Client = _join(r, 101, "paladin", feet_in(ZONE_EDGE), false)
	var b: Client = _join(r, 102, "archer", feet_in(FARM_FEET), false)
	_tick(r, 60)
	var lines: PackedStringArray = []
	var before: Dictionary[String, int] = r.bytes_by_kind.duplicate()
	_tick(r, 240)
	var rest: float = _rate_since(r, before, 240, lines, "rest")
	var entries: Array[Array] = []
	var soil: Array[Vector2i] = []
	for y: int in data.size.y:
		for x: int in data.size.x:
			if data.terrain_at(Vector2i(x, y)) == Terrain.SOIL:
				soil.append(Vector2i(x, y))
	for i: int in soil.size():
		entries.append([soil[i], 1 + i % 3, 0, true, i % 2 == 0])
	# M5-fix: through the host's edit log (the clients get the planted crops), not past it like --test-field, so the
	# clients' worlds are the host's throughout and the end checks it.
	var farm: Farm = r.host.farm_of(Config.MAP_SURFACE)
	for entry: Array in entries:
		var at: Vector2i = entry[0]
		var kind: int = entry[1]
		var stage: int = entry[2]
		var is_wet: bool = entry[3]
		var fast: bool = entry[4]
		r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, at,
			Farming.Field.new(kind, stage, is_wet, fast).value()))
		farm.sync_cell(at)
	_tick(r, 3)
	check(a.surface.data.content_hash() == data.content_hash() and b.surface.data.content_hash() == data.content_hash(),
		"the planted field reached both clients")
	before = r.bytes_by_kind.duplicate()
	var ticks: int = Config.WATER_TICKS + Config.WATER_TICKS / 4
	var peak: int = 0
	var edits_before: int = r.s.log_for(Config.MAP_SURFACE).size()
	for t: int in ticks:
		var n: int = r.s.log_for(Config.MAP_SURFACE).size()
		_tick(r)
		peak = maxi(peak, r.s.log_for(Config.MAP_SURFACE).size() - n)
	var edits: int = r.s.log_for(Config.MAP_SURFACE).size() - edits_before
	var growing: float = _rate_since(r, before, ticks, lines, "%d wet crops growing" % soil.size())
	note("growing field: %d edits in %.0f s (peak %d in one tick), %d B a stage edit message" % [edits,
		ticks / float(Config.NET_TICK_RATE), peak, EditLog.encode_one(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION,
		Vector2i(60, 49), 80), 1, 0).size()])
	check(edits >= soil.size() and growing < 200.0, "a growing field costs edits only: %.1f B/s to two clients (%d edits)" % [growing, edits])
	before = r.bytes_by_kind.duplicate()
	var pick: NetBot.Action = NetBot.Action.new()
	pick.mouse = centre_of(ZONE_EDGE + Vector2i(-1, 0))
	pick.aiming = true
	pick.op = NetProtocol.InputFrame.new()
	pick.op.op = NetProtocol.Op.PICKUP
	press(r, null, a, pick)
	_tick(r, Config.PURIFY_CHANNEL_TICKS + 10)
	var channel: float = _rate_since(r, before, Config.PURIFY_CHANNEL_TICKS + 11, lines, "a channel (3 s, %d tiles)" % r.host.purified)
	check(rest == 0.0 and r.host.purified > 0 and channel > growing, "at rest nothing; a channel sends its state at 20 Hz and its edits")
	_tick(r, 5)
	check(a.surface.data.content_hash() == data.content_hash() and b.surface.data.content_hash() == data.content_hash(),
		"after the growing field and the channel both clients' worlds = the host's")
	note("fields traffic, one process, ENet payload bytes host -> 2 clients: %s" % "; ".join(lines))
	b.ticking = false
	_free_rig(r)


## Bytes per second the host sent to the clients since `before` over `ticks`, by kind, appended to `lines`.
func _rate_since(r: Rig, before: Dictionary[String, int], ticks: int, lines: PackedStringArray, label: String) -> float:
	var sent: int = 0
	var parts: PackedStringArray = []
	for k: String in r.bytes_by_kind:
		var was: int = before.get(k, 0)
		var d: int = r.bytes_by_kind[k] - was
		if d > 0:
			sent += d
			parts.append("%s %.1f" % [k, d * float(Config.NET_TICK_RATE) / ticks])
	var rate: float = sent * float(Config.NET_TICK_RATE) / ticks
	lines.append("%s: %.1f B/s (%s)" % [label, rate, ", ".join(parts)])
	return rate
