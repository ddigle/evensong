extends "res://tests/test_net_combat.gd"
## M11c: hunting, capture and the collection in sessions, in one process: the real SessionHost and SessionClient flows on the rig of
## tests/test_net_combat.gd (the host's messages captured and delivered in order, the clients' packets back). tests/test_net_hunt.gd and
## tests/test_net_herd.gd run real sessions.
##   - the wire (protocol v13): the CAPTURE request, the creature batch, the collection message: round trips, sizes, every truncation,
##     every field out of range; the rare zone and the collection in the surface's snapshot and its content hash
##   - the host against a malicious client: a non-archer capturing, a healthy creature, a far target, a stale or fake id, prey, the
##     wrong map, a map with no creatures, down, dead, carrying, praying, busy, a dash, no snare, a snare in another slot, a wall in
##     between, a far target tile, spam past the request budget: refused with nothing spent
##   - flows: a capture landing on the impact frame on the host's clock (one snare, one material, one entry; held, drawn on the clients),
##     cut off, a full inventory, two archers at one creature; the killing blow's class on every machine; a rare creature refusing a
##     non-archer on every machine; who gets what (the view box, nothing while nothing changes, another map, a keyframe on returning,
##     interpolation); a late joiner and a map entry; the benefits with the host's numbers; bodies; a client's own click; traffic at the
##     caps; a version 12 hello is refused
##   - M11 review: the box at the map's edge, a creature back in view before its going was drawn, what a welcome's keyframe holds, the altar
##     and creatures on the host's rule, a snare's thrower gone and its slot taken

const ARCHER: String = "archer"
const PALADIN: String = "paladin"
const CLERIC: String = "cleric"
const FOX: StringName = &"lamp_fox"
const DEER: StringName = &"deer"
const HARE: StringName = &"hare"
## IMPL (tests): how far a creature as drawn may be from where the host had it at that time (px): the quarter px of the wire and the lerp.
const DRAW_BOUND_PX: float = 3.5
## IMPL (tests): the most creature bytes a second one client may get with every creature in the caps moving in its view (README "측정"):
## 20 batches of 5 + 10 x 13 B.
const CAPS_MAX_BPS: float = 2800.0


func run() -> Array[String]:
	_check_capture_codec()
	_check_creature_codec()
	_check_collection_codec()
	_check_snapshot()
	_check_ids()
	await _check_host_herd()
	await _check_capture_refusals()
	await _check_capture_budget()
	await _check_capture_landing()
	await _check_capture_cut_off()
	await _check_two_archers()
	await _check_full_inventory()
	await _check_killing_blow()
	await _check_rare_refused()
	await _check_view_and_quiet()
	await _check_view_at_the_edge()
	await _check_back_in_view()
	await _check_interpolation()
	await _check_late_join()
	await _check_map_entry()
	await _check_benefits()
	await _check_bodies()
	await _check_altar_bodies()
	await _check_holder_left()
	await _check_recipes()
	await _check_attack_paths()
	await _check_client_click()
	await _check_host_click()
	await _check_traffic()
	await _check_v12_refused()
	return failures


# --- helpers -----------------------------------------------------------------------------------------------

static func _cap(map: int, cell: Vector2i, slot: int, id: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.CAPTURE, map, cell, slot)
	f.capture_id = id
	f.aim = 7
	return f


static func slot_of(inv: Inventory, id: StringName) -> int:
	for i: int in inv.size():
		var st: ItemStack = inv.stack_at(i)
		if st != null and st.id == id:
			return i
	return -1


## A CAPTURE of member `m` at creature id `id` from the slot its snare is in.
static func cap_for(m: NetMember, id: int) -> NetProtocol.InputFrame:
	var cell: Vector2i = Aim.feet_cell(m.player.sim_position) + Vector2i(1, 0)
	return _cap(m.map_id, cell, maxi(slot_of(m.player.inventory, Capture.SNARE), 0), id)


## Frame `f` runs for member `m`; it must be refused with `why` and leave everything as it was.
func _refused(r: Rig, m: NetMember, f: NetProtocol.InputFrame, why: String, label: String) -> void:
	var snares: int = m.player.inventory.count_of(Capture.SNARE)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var before: int = r.host.capture_refusals.get(why, 0)
	var alive: int = herd.alive_count()
	var collected: int = r.host.collection().count()
	m.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(m, f)
	var after: int = r.host.capture_refusals.get(why, 0)
	check_eq(after, before + 1, "%s: refused, %s (%s)" % [label, why, r.host.capture_refusals])
	check(m.player.action_anim < 0 and f.anim < 0, "%s: no action started" % label)
	check_eq(m.player.inventory.count_of(Capture.SNARE), snares, "%s: no snare spent" % label)
	check(herd.alive_count() == alive and r.host.collection().count() == collected, "%s: nothing taken, nothing registered" % label)


## Member `m`'s throw runs out (a client that stays quiet: the host runs its frames here, one a tick).
func _land(r: Rig, m: NetMember) -> void:
	for i: int in 120:
		r.host.run_frame(m, NetProtocol.InputFrame.new())
		if m.player.action_anim < 0:
			return


## How many lines of `event` client `c` logged.
static func _logged(c: Client, event: String) -> int:
	var n: int = 0
	for line: String in c.s.logged:
		if line.begins_with(event + " "):
			n += 1
	return n


## The creatures client `c` draws now, by id.
func _drawn(r: Rig, c: Client) -> Dictionary[int, CreatureSim]:
	c.s.client.combat.sample(float(r.s.tick - r.delay), SessionClient.interp_delay_ticks())
	var out: Dictionary[int, CreatureSim] = {}
	for s: CreatureSim in c.s.client.combat.arena.herd.list:
		out[s.id] = s
	return out


# --- the wire -----------------------------------------------------------------------------------------------

func _check_capture_codec() -> void:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(9, Vector2i(1, 0))
	f.op = NetProtocol.Op.CAPTURE
	f.map = Config.MAP_SURFACE
	f.slot = 2
	f.cell = Vector2i(-3, 400)
	f.aim = 12
	f.capture_id = 65535
	var frames: Array[NetProtocol.InputFrame] = [f]
	var bytes: PackedByteArray = NetProtocol.encode_inputs(frames)
	check_eq(NetProtocol.OP_SIZES[NetProtocol.Op.CAPTURE], 9, "CAPTURE: 9 B after its op byte (map, slot, tile, aim, id)")
	check_eq(NetProtocol.OP_NAMES[NetProtocol.Op.CAPTURE], "capture", "its name")
	check_eq(NetProtocol.OP_SIZES.size(), NetProtocol.OP_NAMES.size(), "the op tables agree")
	check(NetProtocol.op_has_map(NetProtocol.Op.CAPTURE), "it names the map")
	var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
	check(p.ok and p.frames.size() == 1, "it decodes")
	var g: NetProtocol.InputFrame = p.frames[0]
	check(g.op == f.op and g.map == f.map and g.slot == 2 and g.cell == f.cell and g.aim == 12 and g.capture_id == 65535, "round trip")
	check(g.same_request(f) and f.same_request(g), "same_request")
	var other: NetProtocol.InputFrame = NetProtocol.decode_inputs(bytes).frames[0]
	other.capture_id = 5
	check(not other.same_request(f), "another creature is another request")
	check(g.describe_op().contains("creature=65535"), "its log line")
	for n: int in bytes.size():
		var cut: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes.slice(0, n))
		check(not cut.ok or n <= NetProtocol.INPUT_HEADER + 1, "cut at %d is refused" % n)
	var at: int = bytes.size() - 9
	var bad: Array[Array] = [[at, 200, "the map"], [at + 1, Config.HOTBAR_SLOTS, "the slot"]]
	for row: Array in bad:
		var w: PackedByteArray = bytes.duplicate()
		var where: int = row[0]
		var value: int = row[1]
		w[where] = value
		check(not NetProtocol.decode_inputs(w).ok, "%s out of range is refused" % str(row[2]))
	var z: PackedByteArray = bytes.duplicate()
	z.encode_u16(bytes.size() - 2, 0)
	check(not NetProtocol.decode_inputs(z).ok, "creature id 0 (ids count from 1) is refused")
	var one: NetProtocol.InputFrame = NetProtocol.decode_inputs(bytes).frames[0]
	one.capture_id = 65535 + 2
	var back: NetProtocol.InputFrame = NetProtocol.decode_inputs(NetProtocol.encode_inputs([one] as Array[NetProtocol.InputFrame])).frames[0]
	check_eq(back.capture_id, 1, "the id's low 16 bits go")


## A state of every field set, for the batch tests.
static func _state(id: int, kind: StringName) -> NetProtocol.CreatureState:
	var e: NetProtocol.CreatureState = NetProtocol.CreatureState.new()
	e.id = id
	e.kind = kind
	e.pos = Vector2(1024.25, 767.75)
	e.facing = RigData.Dir.WEST
	e.walking = true
	e.state = CreatureSim.State.FLEE
	var full: int = Config.CREATURES[kind]["hp"]
	e.hp = full
	e.flash = Config.HIT_FLASH_TICKS
	e.poisoned = true
	e.stunned = true
	e.slowed = true
	e.refused = true
	e.holder = Config.MAX_PLAYERS - 1
	return e


func _check_creature_codec() -> void:
	check_eq(NetProtocol.CH_CREATURE, 4, "a channel of its own")
	check(NetProtocol.CREATURE_POS_UNITS * Config.TILE * maxi(Config.MAP_SIZE.x, Config.MAP_SIZE.y) < 65536.0, "the surface fits a u16 position")
	check(NetProtocol.CREATURE_POS_UNITS * Config.TILE * WorldSnapshot.MAX_SIDE < 65536.0, "so does the biggest map a snapshot may claim")
	check(Config.HIT_FLASH_TICKS <= 15 and Config.MAX_PLAYERS + 1 <= 15, "the flash and the holder fit their four bits")
	check(Config.CREATURES.size() <= NetProtocol.CREATURE_KIND_MASK + 1, "every kind fits three bits")
	var list: Array[NetProtocol.CreatureState] = []
	var id: int = 1
	for kind: StringName in Config.CREATURES:
		list.append(_state(id, kind))
		id += 1
	var bytes: PackedByteArray = NetProtocol.encode_creatures(4242, list)
	check_eq(bytes.size(), NetProtocol.CREATURE_HEADER + NetProtocol.CREATURE_SIZE * list.size(), "5 + 10 B a creature")
	check_eq(NetProtocol.CREATURE_HEADER + NetProtocol.CREATURE_SIZE, 15, "one creature: 15 B")
	var b: NetProtocol.CreatureBatch = NetProtocol.decode_creatures(bytes)
	check(b.ok and b.tick == 4242 and b.creatures.size() == list.size(), "it decodes")
	for i: int in list.size():
		check(b.creatures[i].same_as(list[i]), "%s: round trip" % list[i].kind)
	check(NetProtocol.decode_creatures(NetProtocol.encode_creatures(1, [] as Array[NetProtocol.CreatureState])).ok, "an empty batch: nothing in view")
	var none: NetProtocol.CreatureState = _state(9, HARE)
	none.holder = NetProtocol.NO_SLOT
	var back: NetProtocol.CreatureBatch = NetProtocol.decode_creatures(NetProtocol.encode_creatures(1, [none] as Array[NetProtocol.CreatureState]))
	check(back.ok and back.creatures[0].holder == NetProtocol.NO_SLOT, "nobody holds it: a 0 on the wire")
	var slot_zero: NetProtocol.CreatureState = _state(9, HARE)
	slot_zero.holder = 0
	check_eq(NetProtocol.decode_creatures(NetProtocol.encode_creatures(1, [slot_zero] as Array[NetProtocol.CreatureState])).creatures[0].holder, 0, "slot 0 holds it")
	for n: int in bytes.size():
		check(not NetProtocol.decode_creatures(bytes.slice(0, n)).ok, "cut at %d is refused" % n)
	var more: PackedByteArray = bytes.duplicate()
	more.append(0)
	check(not NetProtocol.decode_creatures(more).ok, "a byte more is refused")
	var many: Array[NetProtocol.CreatureState] = []
	for i: int in NetProtocol.CREATURE_BATCH_MAX + 5:
		many.append(_state(i + 1, HARE))
	var capped: NetProtocol.CreatureBatch = NetProtocol.decode_creatures(NetProtocol.encode_creatures(1, many))
	check(capped.ok and capped.creatures.size() == NetProtocol.CREATURE_BATCH_MAX, "a batch carries at most %d" % NetProtocol.CREATURE_BATCH_MAX)
	var over: PackedByteArray = NetProtocol.encode_creatures(1, [] as Array[NetProtocol.CreatureState])
	over[4] = NetProtocol.CREATURE_BATCH_MAX + 1
	over.resize(NetProtocol.CREATURE_HEADER + NetProtocol.CREATURE_SIZE * (NetProtocol.CREATURE_BATCH_MAX + 1))
	check(not NetProtocol.decode_creatures(over).ok, "a count past the most is refused")
	# Fields out of range, on a live creature (the first of one).
	var one: PackedByteArray = NetProtocol.encode_creatures(1, [_state(1, HARE)] as Array[NetProtocol.CreatureState])
	var at: int = NetProtocol.CREATURE_HEADER
	check(NetProtocol.decode_creatures(one).ok, "the good one")
	var hare_hp: int = Config.CREATURES[HARE]["hp"]
	var bad: Array[Array] = [
		[at + 6, one[at + 6] | 0x40, "a flag bit that means nothing"],
		[at + 6, (one[at + 6] & 0xC7) | (7 << 3), "a state past the last"],
		[at + 7, (one[at + 7] & ~NetProtocol.CREATURE_KIND_MASK) | 7, "a kind past the last"],
		[at + 7, one[at + 7] | 0x40, "a mark that means nothing"],
		[at + 8, hare_hp + 1, "HP past its kind's"],
		[at + 8, 0, "a live creature with no HP"],
		[at + 9, Config.HIT_FLASH_TICKS + 1, "a flash past its time"],
		[at + 9, (Config.MAX_PLAYERS + 1) << 4, "a holder past the last slot"],
	]
	for row: Array in bad:
		var w: PackedByteArray = one.duplicate()
		var where: int = row[0]
		var value: int = row[1]
		w[where] = value
		check(not NetProtocol.decode_creatures(w).ok, "%s is refused" % str(row[2]))
	var noid: PackedByteArray = one.duplicate()
	noid.encode_u16(at, 0)
	check(not NetProtocol.decode_creatures(noid).ok, "id 0 is refused")
	var twice: PackedByteArray = NetProtocol.encode_creatures(1, [_state(3, HARE), _state(3, HARE)] as Array[NetProtocol.CreatureState])
	check(not NetProtocol.decode_creatures(twice).ok, "an id twice is refused")
	# A corpse.
	var dead: NetProtocol.CreatureState = NetProtocol.CreatureState.new()
	dead.id = 4
	dead.kind = DEER
	dead.state = CreatureSim.State.DEAD
	var body: PackedByteArray = NetProtocol.encode_creatures(1, [dead] as Array[NetProtocol.CreatureState])
	check(NetProtocol.decode_creatures(body).ok, "a corpse decodes")
	var marked: PackedByteArray = body.duplicate()
	marked[at + 7] = marked[at + 7] | NetProtocol.CREATURE_POISONED
	check(not NetProtocol.decode_creatures(marked).ok, "a corpse with a mark is refused")
	var walking: PackedByteArray = body.duplicate()
	walking[at + 6] = walking[at + 6] | 4
	check(not NetProtocol.decode_creatures(walking).ok, "a walking corpse is refused")
	var held: PackedByteArray = body.duplicate()
	held[at + 9] = 1 << 4
	check(not NetProtocol.decode_creatures(held).ok, "a held corpse is refused")
	var breathing: PackedByteArray = body.duplicate()
	breathing[at + 8] = 1
	check(not NetProtocol.decode_creatures(breathing).ok, "a corpse with HP is refused")
	# creature_of: what a live one and a dead one say.
	var c: CreatureSim = CreatureSim.new()
	c.id = 7
	c.kind = FOX
	c.hp = 10
	c.pos = Vector2(100.0, 200.0)
	c.refused_ticks = 3
	c.hold_ticks = 2
	var e: NetProtocol.CreatureState = NetProtocol.creature_of(c, 4)
	check(e.refused and e.holder == 4 and e.hp == 10, "a held creature names its holder, a refused blow its mark")
	c.hold_ticks = 0
	c.refused_ticks = 0
	var free: NetProtocol.CreatureState = NetProtocol.creature_of(c, 4)
	check(not free.refused and free.holder == NetProtocol.NO_SLOT, "nobody holds it now, whatever the table says")
	c.state = CreatureSim.State.DEAD
	c.hp = 0
	c.refused_ticks = 9
	c.hold_ticks = 9
	var gone: PackedByteArray = NetProtocol.encode_creatures(1, [NetProtocol.creature_of(c, 4)] as Array[NetProtocol.CreatureState])
	check(NetProtocol.decode_creatures(gone).ok, "whatever a corpse's timers say, it goes out clean")


func _check_collection_codec() -> void:
	check_eq(NetProtocol.COLLECTION_SIZE, 6, "the collection message: 6 B")
	check(Collection.total() <= 16, "the table fits the u16")
	var col: Collection = Collection.new()
	check_eq(col.bits(), 0, "an empty one")
	col.put_test(5, 321)
	var bytes: PackedByteArray = NetProtocol.encode_collection(col)
	check_eq(bytes.size(), NetProtocol.COLLECTION_SIZE, "its size")
	var c: NetProtocol.CollectionState = NetProtocol.decode_collection(bytes)
	check(c.ok and c.bits == 0b11111 and c.kills == 321, "round trip")
	for n: int in bytes.size():
		check(not NetProtocol.decode_collection(bytes.slice(0, n)).ok, "cut at %d is refused" % n)
	var more: PackedByteArray = bytes.duplicate()
	more.append(0)
	check(not NetProtocol.decode_collection(more).ok, "a byte more is refused")
	var far: PackedByteArray = bytes.duplicate()
	far.encode_u16(0, 1 << Collection.total())
	check(not NetProtocol.decode_collection(far).ok, "an entry the table does not have is refused")
	# take_state: absolute, and what is new is news.
	var copy: Collection = Collection.new()
	var seen: int = copy.revision
	check(copy.take_state(c.bits, c.kills), "something changed")
	check(copy.revision != seen and copy.bits() == col.bits() and copy.kills == 321, "the same state")
	check_eq(copy.take_fresh().size(), 5, "five new entries")
	check(not copy.take_state(c.bits, c.kills), "the same again changes nothing")
	check(copy.take_state(0b1, 2) and copy.count() == 1 and copy.kills == 2, "absolute: what the host does not have goes")
	check(copy.benefit(&"class") == false, "and its benefit with it")


func _check_snapshot() -> void:
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	check_eq(data.content_hash(), SurfaceGen.GOLDEN_HASH, "a generated world has no zone and no collection: its golden hash")
	var bare: PackedByteArray = WorldSnapshot.raw_bytes(data)
	check(bare[bare.size() - 1] == 0 and bare[bare.size() - 2] == 0, "no zone, no collection: a 0 each")
	var d2: WorldData = WorldSnapshot.decode_raw(bare)
	check(d2 != null and d2.rare_zone == null and d2.collection == null, "and none on the other side")
	# With both.
	var herd: Creatures = Creatures.new()
	herd.setup(data, Config.DEFAULT_SEED, false)
	check(data.rare_zone != null, "the herd placed the zone")
	var with_zone: String = data.content_hash()
	check(with_zone != SurfaceGen.GOLDEN_HASH, "the zone is in the content hash")
	data.collection = Collection.new()
	var empty: String = data.content_hash()
	check(empty != with_zone, "the collection too")
	data.collection.put_test(3, 0)
	var entries_only: String = data.content_hash()
	check(entries_only != empty, "and its entries")
	data.collection.kills = 12
	var filled: String = data.content_hash()
	check(filled != entries_only, "and its kills")
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(data)
	check_eq(raw.size(), bare.size() + WorldSnapshot.ZONE_BYTES + WorldSnapshot.COLLECTION_BYTES, "5 + 6 B more")
	var back: WorldData = WorldSnapshot.decode_raw(raw)
	check(back != null and back.rare_zone != null and back.rare_zone.center == data.rare_zone.center
		and back.rare_zone.radius == data.rare_zone.radius, "the zone comes across")
	check(back != null and back.collection != null and back.collection.bits() == 0b111 and back.collection.kills == 12, "the collection too")
	check(back != null and back.content_hash() == filled, "the same hash on the other side")
	check(raw.size() < WorldSnapshot.MAX_RAW, "within the limit")
	var p: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	check(WorldSnapshot.unpack(p.bytes, p.raw_size) != null, "packed and unpacked")
	# Every way it can be wrong.
	var col_at: int = raw.size() - 1 - WorldSnapshot.COLLECTION_BYTES
	var zone_at: int = col_at - WorldSnapshot.ZONE_BYTES - 1
	check_eq(raw[zone_at], 1, "the zone's flag")
	check_eq(raw[col_at], 1, "the collection's flag")
	var bad: Array[Array] = []
	var w: PackedByteArray = raw.duplicate()
	w[zone_at] = 2
	bad.append([w, "a zone flag of 2"])
	w = raw.duplicate()
	w[col_at] = 2
	bad.append([w, "a collection flag of 2"])
	w = raw.duplicate()
	w.encode_u8(zone_at + 5, 0)
	bad.append([w, "a zone of radius 0"])
	w = raw.duplicate()
	w.encode_u16(zone_at + 1, 2)
	bad.append([w, "a zone hanging off the west edge"])
	w = raw.duplicate()
	w.encode_u16(zone_at + 3, Config.MAP_SIZE.y - 2)
	bad.append([w, "a zone hanging off the south edge"])
	w = raw.duplicate()
	w.encode_u16(col_at + 1, 1 << Collection.total())
	bad.append([w, "an entry the table does not have"])
	w = raw.duplicate()
	w.append(0)
	bad.append([w, "a byte after it"])
	bad.append([raw.slice(0, raw.size() - 1), "a byte short"])
	bad.append([raw.slice(0, col_at), "the collection's flag cut off"])
	bad.append([raw.slice(0, zone_at), "the zone's flag cut off"])
	for row: Array in bad:
		var bytes: PackedByteArray = row[0]
		check(WorldSnapshot.decode_raw(bytes) == null, "%s is refused" % str(row[1]))
	# Another map: one object on both maps' data, only the surface's snapshot and hash carry it.
	var cave: WorldData = DungeonGen.generate(Config.DEFAULT_SEED)
	var cave_hash: String = cave.content_hash()
	cave.collection = data.collection
	check_eq(cave.content_hash(), cave_hash, "the dungeon's hash does not move with the world's collection")
	var cave_raw: PackedByteArray = WorldSnapshot.raw_bytes(cave)
	check(cave_raw[cave_raw.size() - 1] == 0 and cave_raw[cave_raw.size() - 2] == 0, "the dungeon's snapshot has neither")
	var forged: PackedByteArray = cave_raw.slice(0, cave_raw.size() - 1)
	forged.append(1)
	forged.append_array(NetProtocol.encode_collection(data.collection))
	check(WorldSnapshot.decode_raw(forged) == null, "a dungeon snapshot with a collection is refused")
	forged = cave_raw.slice(0, cave_raw.size() - 2)
	var inside: PackedByteArray = PackedByteArray()
	inside.resize(1 + WorldSnapshot.ZONE_BYTES)
	inside.encode_u8(0, 1)
	inside.encode_u16(1, 30)  # a disc that would fit that map
	inside.encode_u16(3, 20)
	inside.encode_u8(5, 5)
	forged.append_array(inside)
	forged.append(0)
	check(WorldSnapshot.decode_raw(forged) == null, "a dungeon snapshot with a rare zone is refused")


## An id on the wire is a u16 from 1.
func _check_ids() -> void:
	var d: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var herd: Creatures = Creatures.new()
	herd.setup(d, Config.DEFAULT_SEED, false)
	herd.next_id = NetProtocol.CREATURE_ID_MAX
	var last: CreatureSim = herd.spawn(HARE, Vector2(100, 100))
	var first: CreatureSim = herd.spawn(HARE, Vector2(120, 100))
	check(last.id == NetProtocol.CREATURE_ID_MAX and first.id == 1, "ids wrap from %d to 1 (%d, %d)" % [NetProtocol.CREATURE_ID_MAX, last.id, first.id])
	var mirror: Creatures = Creatures.mirror(d)
	check(mirror.list.is_empty() and not mirror.spawning and mirror.data == d, "a mirror herd: empty, spawning nothing")


## The host's herd is the world's: the offline stream from the world seed, the zone placed and shown, one collection on both maps.
func _check_host_herd() -> void:
	var offline_data: WorldData = SurfaceGen.generate(SEED)
	var offline: Creatures = Creatures.new()
	offline.setup(offline_data, SEED)
	var r: Rig = _rig(PALADIN, false, {}, true)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	check_eq(herd.list.size(), 13, "the natural herd, all thirteen")
	var same: bool = herd.list.size() == offline.list.size()
	for i: int in mini(herd.list.size(), offline.list.size()):
		same = same and herd.list[i].pos == offline.list[i].pos and herd.list[i].kind == offline.list[i].kind and herd.list[i].id == offline.list[i].id
	check(same, "the same creatures on the same spots as offline: the world seed's own stream")
	check(r.surface.data.rare_zone != null and r.surface.rare_view != null, "the zone is placed and shown on the host")
	check(r.dungeon.data.rare_zone == null, "none in the dungeon")
	check(r.surface.data.collection != null and r.surface.data.collection == r.dungeon.data.collection, "one collection on both maps' data")
	var c: Client = _join(r, 101, ARCHER, spot(r))
	_tick(r, 3)
	check_eq(c.surface.data.rare_zone.describe(), offline_data.rare_zone.describe(), "the client's zone: the host's, by its snapshot")
	var feet: Vector2 = herd.list[0].pos
	var hold_ok: bool = false
	herd.list[0].state = CreatureSim.State.WANDER
	herd.list[0].target = feet + Vector2(0, 8)
	_tick(r, 2)
	hold_ok = herd.list[0].pos != feet
	check(hold_ok, "the herd steps on the host's clock")
	var at_home: int = herd.clock
	r.host.move_to_map(r.s.local, Config.MAP_DUNGEON)
	member_of_peer(r, 101).player.teleport(r.surface.arrival_point())
	r.host.move_to_map(member_of_peer(r, 101), Config.MAP_DUNGEON)
	_tick(r, 10)
	check_eq(herd.clock, at_home + 10, "with nobody on the surface too (the game clock, as offline)")
	# M11 creature art review: the herd's clock is the host tick, and so is every creature's (CreatureSim.clock), one put down late too: a
	# client draws the walk frame and the ring's blink by the host tick it draws, so both show the same frame.
	check_eq(herd.clock, r.s.tick, "the herd's clock is the host tick")
	var late: CreatureSim = herd.spawn(&"hare", herd.list[0].pos + Vector2(32, 0))
	_tick(r, 3)
	var off: int = 0
	for c2: CreatureSim in herd.list:
		if c2.clock != r.s.tick:
			off += 1
	check(late.clock == r.s.tick and off == 0, "every creature's clock is the host tick (%d), the late one too (%d); %d off" % [r.s.tick, late.clock, off])
	_free_rig(r)


# --- the host against a malicious client ----------------------------------------------------------------------

func _check_capture_refusals() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	await _join_quiet(r, 101, ARCHER, f)
	await _join_quiet(r, 102, PALADIN, f + Vector2(0, 64))
	var m: NetMember = member_of_peer(r, 101)
	var other: NetMember = member_of_peer(r, 102)
	m.player.inventory.add(Capture.SNARE, 3)
	other.player.inventory.add(Capture.SNARE, 3)
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	var hale: CreatureSim = herd.put_resting(&"ash_owl", f + Vector2(-24, 0), 100)
	var prey: CreatureSim = herd.put_resting(DEER, f + Vector2(0, -24), 10)
	var near_other: CreatureSim = herd.put_resting(FOX, other.player.sim_position + Vector2(24, 0), 30)
	_refused(r, other, cap_for(other, near_other.id), Capture.WHY_NOT_ARCHER, "a paladin with a snare")
	check_eq(near_other.refused_ticks, Config.CREATURE_REFUSED_SHOW_TICKS, "the creature shows it did nothing")
	_refused(r, m, cap_for(m, hale.id), Capture.WHY_HEALTHY, "a healthy creature")
	# The threshold, exactly.
	var limit: int = hale.hp_max() * Config.CAPTURE_HP_PCT / 100
	hale.hp = limit + 1
	_refused(r, m, cap_for(m, hale.id), Capture.WHY_HEALTHY, "one HP above the threshold")
	_refused(r, m, cap_for(m, prey.id), Capture.WHY_PREY, "prey")
	_refused(r, m, cap_for(m, 999), Capture.WHY_NOTHING, "a fake id")
	# A far target, exactly.
	fox.pos = m.player.sim_position + Vector2(Config.CAPTURE_REACH_PX + 1.0, 0.0)
	_refused(r, m, cap_for(m, fox.id), Capture.WHY_REACH, "a creature past the reach")
	fox.pos = m.player.sim_position + Vector2(Config.CAPTURE_REACH_PX, 0.0)
	var far_tile: NetProtocol.InputFrame = cap_for(m, fox.id)
	far_tile.cell = Aim.feet_cell(m.player.sim_position) + Vector2i(9, 0)
	_refused(r, m, far_tile, WorldItems.WHY_REACH, "a target tile out of reach")
	var dungeon: NetProtocol.InputFrame = cap_for(m, fox.id)
	dungeon.map = Config.MAP_DUNGEON
	var budget: int = NetMember.OP_BUDGET_MAX
	_refused(r, m, dungeon, WorldItems.WHY_WRONG_MAP, "another map's frame")
	check_eq(m.op_budget, budget, "a wrong map costs no budget")
	var wrong_slot: NetProtocol.InputFrame = cap_for(m, fox.id)
	wrong_slot.slot = WEAPON_SLOT
	_refused(r, m, wrong_slot, Capture.WHY_NO_SNARE, "the slot it names holds no snare")
	var from_past: NetProtocol.InputFrame = cap_for(m, fox.id)
	from_past.slot = Config.HOTBAR_SLOTS - 1
	_refused(r, m, from_past, Capture.WHY_NO_SNARE, "an empty slot")
	var dashing: NetProtocol.InputFrame = cap_for(m, fox.id)
	dashing.dash = true
	m.op_budget = NetMember.OP_BUDGET_MAX
	var before: int = m.op_budget
	r.host.run_frame(m, dashing)
	check(m.op_budget == before and r.host.capture_refusals.has(Skills.WHY_BUSY), "a dash in the same frame wins, no budget (as for a skill)")
	check_eq(fox.hold_ticks, 0, "and it holds nothing")
	await await_frames(1)
	for i: int in 40:
		r.host.run_frame(m, NetProtocol.InputFrame.new())  # the dash runs out
	fox.pos = m.player.sim_position + Vector2(24.0, 0.0)
	# Busy.
	m.player.start_action(RigData.Anim.THROW, &"bow")
	m.op_budget = NetMember.OP_BUDGET_MAX
	var snares_busy: int = m.player.inventory.count_of(Capture.SNARE)
	var busy_frame: NetProtocol.InputFrame = cap_for(m, fox.id)
	r.host.run_frame(m, busy_frame)
	check(r.host.capture_refusals.has(SessionHost.WHY_BUSY) and busy_frame.anim < 0, "an action still playing: busy")
	check_eq(m.player.action_item, &"bow", "the old action plays on")
	check_eq(m.player.inventory.count_of(Capture.SNARE), snares_busy, "nothing spent")
	check_eq(fox.hold_ticks, 0, "nothing held")
	_land(r, m)
	# A wall between them (a stone wall right between their body points).
	var wall: Vector2i = Aim.feet_cell(m.player.sim_position + Vector2(12.0, 0.0))
	r.surface.data.set_value(WorldData.Layer.WALL, wall, Walls.KIND_STONE)
	_refused(r, m, cap_for(m, fox.id), Capture.WHY_REACH, "a wall in between")
	r.surface.data.set_value(WorldData.Layer.WALL, wall, Walls.KIND_NONE)
	# No snare at all.
	var snares: int = m.player.inventory.count_of(Capture.SNARE)
	var snare_slot: int = slot_of(m.player.inventory, Capture.SNARE)
	m.player.inventory.remove(snare_slot, snares)
	_refused(r, m, _cap(Config.MAP_SURFACE, Aim.feet_cell(m.player.sim_position) + Vector2i(1, 0), snare_slot, fox.id), Capture.WHY_NO_SNARE, "no snare")
	m.player.inventory.add(Capture.SNARE, snares)
	# States.
	m.player.set_carrying_altar(true)
	_refused(r, m, cap_for(m, fox.id), AltarMove.WHY_CARRYING, "carrying the altar")
	check_eq(m.op_budget, NetMember.OP_BUDGET_MAX, "refused before the budget, like a carrier's other requests")
	m.player.set_carrying_altar(false)
	m.player.prayer_role = Prayer.Role.PRAYING
	_refused(r, m, cap_for(m, fox.id), Skills.WHY_PRAYING, "praying")
	m.player.prayer_role = Prayer.Role.NONE
	m.player.take_hit(Config.PLAYER_HP_MAX)
	check(not m.player.vitals.alive(), "the archer is down")
	_refused(r, m, cap_for(m, fox.id), SessionHost.WHY_DOWN, "while down")
	m.player.vitals.life = Vitals.Life.DEAD
	_refused(r, m, cap_for(m, fox.id), SessionHost.WHY_DOWN, "while dead")
	m.player.vitals.life = Vitals.Life.ALIVE
	m.player.vitals.hp = Config.PLAYER_HP_MAX
	# A map with no creatures: the frame names the map the player is on.
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	var there: NetProtocol.InputFrame = _cap(Config.MAP_DUNGEON, Aim.feet_cell(m.player.sim_position) + Vector2i(1, 0),
		slot_of(m.player.inventory, Capture.SNARE), fox.id)
	_refused(r, m, there, Capture.WHY_NOTHING, "the dungeon has no creatures")
	# A stale id: the creature it saw is gone.
	var fresh: CreatureSim = herd.put_resting(FOX, other.player.sim_position + Vector2(-24, 0), 30)
	herd.capture(fresh)
	r.host.move_to_map(m, Config.MAP_SURFACE)
	m.player.teleport(other.player.sim_position + Vector2(0, 16))
	_refused(r, m, cap_for(m, fresh.id), Capture.WHY_NOTHING, "a stale id (taken a moment ago)")
	check_eq(r.host.captures, 0, "not one capture landed")
	note("refused captures: %s" % r.host.capture_refusals)
	_free_rig(r)


func _check_capture_budget() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	await _join_quiet(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	m.player.inventory.add(Capture.SNARE, 5)
	var hale: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 100)
	m.op_budget = NetMember.OP_BUDGET_MAX
	var refused: int = 0
	var rate_before: int = r.host.capture_refusals.get("rate", 0)
	for i: int in Config.NET_OP_BURST + 6:
		r.host.run_frame(m, cap_for(m, hale.id))
		refused += 1
	var rate: int = r.host.capture_refusals.get("rate", 0) - rate_before
	check_eq(rate, 6, "spam past the budget: the burst of %d is looked at, the rest are `rate`" % Config.NET_OP_BURST)
	check_eq(r.host.capture_refusals.get(Capture.WHY_HEALTHY, 0), Config.NET_OP_BURST, "those burst are refused by the rule")
	check_eq(m.player.inventory.count_of(Capture.SNARE), 5, "nothing spent")
	# A valid one past the budget is refused too: the budget comes first.
	hale.hp = 1
	r.host.run_frame(m, cap_for(m, hale.id))
	check_eq(r.host.capture_refusals.get("rate", 0) - rate_before, 7, "even a good one, with no budget left")
	check_eq(m.player.action_anim, -1, "no throw")
	_free_rig(r)


# --- capture flows ---------------------------------------------------------------------------------------------

func _check_capture_landing() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = await _join_quiet(r, 101, ARCHER, f)
	var p2: Client = await _join_quiet(r, 102, CLERIC, f + Vector2(64, 0))
	c.ticking = false
	var m: NetMember = member_of_peer(r, 101)
	m.player.inventory.add(Capture.SNARE, 2)
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	_tick(r, 3)
	var request: NetProtocol.InputFrame = cap_for(m, fox.id)
	r.host.run_frame(m, request)
	check_eq(m.player.action_anim, Config.CAPTURE_ANIM, "the throw plays on the host")
	check_eq(m.player.action_capture, fox.id, "at that creature")
	check_eq(m.ops_done.get("capture", 0), 1, "counted once when it started")
	check(fox.held() and fox.held_by == m.player.get_instance_id(), "the throw's start holds it (by that archer)")
	check_eq(fox.held_from, Combat.body_point(m.player.sim_position), "the rope goes to it")
	for t: int in Capture.impact_tick():
		check(herd.by_id(fox.id) == fox and m.player.inventory.count_of(Capture.SNARE) == 2, "tick %d: nothing yet" % t)
		r.host.run_frame(m, NetProtocol.InputFrame.new())
	check(herd.by_id(fox.id) == null, "the impact frame takes it, no dice")
	check_eq(m.player.inventory.count_of(Capture.SNARE), 1, "one snare")
	check_eq(m.player.inventory.count_of(Config.RARE_MATERIAL), Config.CAPTURE_MATERIAL_COUNT, "the rare material")
	check_eq(r.host.collection().has(&"take_lamp_fox"), true, "the entry")
	check_eq(r.host.captures, 1, "one capture")
	check_eq(herd.stat("captured"), 1, "the herd counted it")
	check_eq(herd.waiting.size(), 1, "its place waits")
	check(m.inventory_dirty, "the owner gets its inventory")
	_tick(r, 2 + r.delay)
	check(r.host.collection().has(&"first_rare_essence"), "holding the material is an entry too")
	for peer: Client in [c, p2]:
		check_eq(peer.s.client.collection.bits(), r.host.collection().bits(), "client %d has the entries" % peer.peer)
		check_eq(peer.s.client.collection.describe(), r.host.collection().describe(), "client %d: the same words" % peer.peer)
	check_eq(p2.s.client.tally_msgs, 2, "the late one's welcome message and one change of two entries in a tick")
	var seen: Dictionary = p2.s.client.combat.bursts_seen
	check_eq(seen.get("CAPTURE", 0), 1, "the catch shows on the others' machines")
	_free_rig(r)


## The throw's cut short: the archer is hit (the action ends), the creature dies meanwhile, the hold runs out.
func _check_capture_cut_off() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	await _join_quiet(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	m.player.inventory.add(Capture.SNARE, 2)
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	r.host.run_frame(m, cap_for(m, fox.id))
	check(fox.held(), "held")
	herd.hit(fox, fox.hp, m.player.get_instance_id())
	check(not fox.alive() and not fox.held(), "killed under the snare: no hold")
	_land(r, m)
	check_eq(m.player.inventory.count_of(Capture.SNARE), 2, "a kill under the snare: nothing spent")
	check_eq(m.player.inventory.count_of(Config.RARE_MATERIAL), 0, "no material")
	check_eq(r.host.collection().has(&"take_lamp_fox"), false, "a rare kill registers no entry")
	check_eq(r.host.capture_refusals.get(Capture.WHY_GONE, 0), 1, "refused on landing: it is gone")
	_tick(r)
	var drops: Array[int] = []
	drops.assign(r.surface.data.drops.keys())
	check(not drops.is_empty(), "its hide lies on the ground")
	var fox2: CreatureSim = herd.put_resting(FOX, m.player.sim_position + Vector2(24, 0), 30)
	r.host.run_frame(m, cap_for(m, fox2.id))
	check(m.player.action_anim == Config.CAPTURE_ANIM and fox2.held(), "thrown")
	m.player.take_hit(5, true)
	r.host.run_frame(m, NetProtocol.InputFrame.new())
	check_eq(m.player.action_anim, -1, "a hit cuts the throw off")
	_land(r, m)
	check(herd.by_id(fox2.id) == fox2 and m.player.inventory.count_of(Capture.SNARE) == 2, "nothing spent, nothing taken")
	_free_rig(r)


func _check_two_archers() -> void:
	var r: Rig = _rig(ARCHER)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	r.s.local.player.teleport(f)
	await _join_quiet(r, 101, ARCHER, f + Vector2(32, 0))
	var a: NetMember = r.s.local
	var b: NetMember = member_of_peer(r, 101)
	a.player.inventory.add(Capture.SNARE, 1)
	b.player.inventory.add(Capture.SNARE, 1)
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(16, 0), 30)
	r.host.run_frame(a, cap_for(a, fox.id))
	r.host.run_frame(b, cap_for(b, fox.id))
	check(a.player.action_anim == Config.CAPTURE_ANIM and b.player.action_anim == Config.CAPTURE_ANIM, "both throw (it is held, not taken)")
	for t: int in Capture.impact_tick() + 2:
		r.host.run_frame(a, NetProtocol.InputFrame.new())
		r.host.run_frame(b, NetProtocol.InputFrame.new())
	check_eq(r.host.captures, 1, "exactly one takes it")
	check_eq(a.player.inventory.count_of(Config.RARE_MATERIAL) + b.player.inventory.count_of(Config.RARE_MATERIAL), 1, "one material")
	check_eq(a.player.inventory.count_of(Capture.SNARE) + b.player.inventory.count_of(Capture.SNARE), 1, "one snare spent")
	check_eq(a.player.inventory.count_of(Capture.SNARE), 0, "the lower slot, the first frame")
	check_eq(r.host.capture_refusals.get(Capture.WHY_GONE, 0), 1, "the other finds it gone, spends nothing")
	_free_rig(r)


func _check_full_inventory() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = await _join_quiet(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	var inv: Inventory = m.player.inventory
	inv.add(Capture.SNARE, 1)
	var fill: int = 0
	while inv.room_for(&"stone_a", ItemDB.Grade.NONE) > 0 and fill < 400:
		inv.add(&"stone_a", 99)
		fill += 1
	check_eq(inv.room_for(Config.RARE_MATERIAL, ItemDB.Grade.NONE), 0, "the inventory is full")
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	var at: Vector2i = Aim.feet_cell(fox.pos)
	var slot: int = slot_of(inv, Capture.SNARE)
	check(inv.stack_at(slot).count == 1, "one snare, its last: its slot empties")
	r.host.run_frame(m, cap_for(m, fox.id))
	for t: int in Capture.impact_tick() + 1:
		r.host.run_frame(m, NetProtocol.InputFrame.new())
	check_eq(r.host.captures, 1, "captured")
	_tick(r, 2)
	var given: int = inv.count_of(Config.RARE_MATERIAL)
	var lying: int = 0
	for id: int in r.surface.data.drops:
		var d: WorldData.Drop = r.surface.data.drops[id]
		if d.item == Config.RARE_MATERIAL:
			lying += d.count
	check_eq(given + lying, Config.CAPTURE_MATERIAL_COUNT, "the material is in the snare's slot or on the ground, nothing lost")
	check(given == 1 or lying == 1, "(%d in hand, %d on tile %s)" % [given, lying, at])
	check_eq(c.surface.data.drops.size(), r.surface.data.drops.size(), "the client has the host's drops")
	_free_rig(r)


# --- the killing blow ------------------------------------------------------------------------------------------

## The drops of `data`, sorted as one word.
static func _drop_word(data: WorldData) -> String:
	var out: PackedStringArray = []
	for id: int in data.drop_ids():
		out.append("%s x%d" % [data.drops[id].item, data.drops[id].count])
	return ", ".join(out)


func _check_killing_blow() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var a: Arena = r.host.arenas[Config.MAP_SURFACE]
	var f: Vector2 = spot(r)
	r.s.local.player.teleport(f)
	var c: Client = _join(r, 101, ARCHER, f + Vector2(0, 32))
	var m: NetMember = member_of_peer(r, 101)
	# The paladin wounds it, the archer's blow kills it: the whole hide.
	var deer: CreatureSim = herd.spawn(DEER, f + Vector2(32, 0))
	a.hit_creature(deer, deer.hp - 1, r.s.local.player.get_instance_id())
	a.hit_creature(deer, 1, m.player.get_instance_id())
	_tick(r, 2)
	check_eq(_drop_word(r.surface.data), "hide_fine x2, meat x2", "the archer's blow: the whole hide, two and two")
	check_eq(_drop_word(c.surface.data), "hide_fine x2, meat x2", "the client's world says so")
	check_eq(r.s.local.combat_count("creature_hits"), 1, "the paladin's hit is counted")
	check_eq(m.combat_count("creature_hits"), 1, "the archer's")
	check_eq(m.combat_count("creature_kills"), 1, "the kill is the archer's")
	check_eq(r.host.hunt_kills, 1, "one kill")
	# And the other way round: damaged, fewer.
	for id: int in r.surface.data.drop_ids():
		r.host.apply_world_edit(EditLog.WorldEdit.drop_remove(id), Config.MAP_SURFACE)
	var deer2: CreatureSim = herd.spawn(DEER, f + Vector2(-32, 0))
	a.hit_creature(deer2, deer2.hp - 1, m.player.get_instance_id())
	a.hit_creature(deer2, 1, r.s.local.player.get_instance_id())
	_tick(r, 2)
	check_eq(_drop_word(r.surface.data), "hide_worn x1, meat x1", "the paladin's blow: the damaged hide, fewer")
	check_eq(_drop_word(c.surface.data), "hide_worn x1, meat x1", "on every machine")
	check_eq(r.surface.data.content_hash(), c.surface.data.content_hash(), "the same world, the collection in it")
	check(r.host.collection().has(&"hunt_deer"), "the entry")
	check_eq(c.s.client.collection.kills, 2, "two kills on the client")
	_free_rig(r)


func _check_rare_refused() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var a: Arena = r.host.arenas[Config.MAP_SURFACE]
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f + Vector2(0, 32))
	var fox: CreatureSim = herd.spawn(FOX, f + Vector2(32, 0))
	var full: int = fox.hp
	r.s.local.player.teleport(f)
	a.hit_creature(fox, 10, r.s.local.player.get_instance_id())
	check_eq(fox.hp, full, "a paladin's blow on a rare creature does nothing")
	check_eq(fox.state, CreatureSim.State.IDLE, "it does not even bolt")
	check_eq(fox.refused_ticks, Config.CREATURE_REFUSED_SHOW_TICKS, "its refused mark")
	_tick(r, 3 + r.delay)
	check_eq(r.host.hunt_refused, 1, "the host counted the refused blow")
	check_eq(r.s.local.combat_count("creature_refused"), 1, "as the paladin's")
	var marks: int = c.s.client.combat.creature_marks.get("refused", 0)
	check(marks > 0, "the client's batches show the mark (%s)" % c.s.client.combat.creature_marks)
	var drawn: Dictionary[int, CreatureSim] = _drawn(r, c)
	check(drawn.has(fox.id) and drawn[fox.id].refused_ticks > 0, "and it draws it (%s)" % drawn.keys())
	# The archer's blow does.
	a.hit_creature(fox, 10, member_of_peer(r, 101).player.get_instance_id())
	check_eq(fox.hp, full - 10, "the archer's blow hurts it")
	_tick(r, 4 + r.delay)
	check_eq(c.s.client.combat.creature_hp.get(fox.id, []), [full, full - 10], "the client saw its HP go")
	_free_rig(r)


# --- who gets what ---------------------------------------------------------------------------------------------

func _check_view_and_quiet() -> void:
	# The box, exactly.
	var box: Vector2 = Config.NET_CREATURE_VIEW_PX
	check(box.x >= 320.0 + 16.0 and box.y >= Config.VIEW_SIZE.y / 2.0 + 16.0, "the box covers a 21:9 view and a margin")
	var e: NetProtocol.CreatureState = _state(1, HARE)
	e.pos = Vector2(1000.0 + box.x, 500.0 + box.y)
	var one: Array[NetProtocol.CreatureState] = [e]
	var map: Rect2 = Rect2(0.0, 0.0, 4000.0, 4000.0)
	check_eq(SessionHost.in_view(one, Vector2(1000.0, 500.0), map).size(), 1, "on the box's corner: seen")
	e.pos.x += 0.25
	check_eq(SessionHost.in_view(one, Vector2(1000.0, 500.0), map).size(), 0, "a quarter px past it: not")
	e.pos.x -= 0.25
	e.pos.y += 0.25
	check_eq(SessionHost.in_view(one, Vector2(1000.0, 500.0), map).size(), 0, "south of it: not")
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var far: Client = _join(r, 102, CLERIC, f + Vector2(0, -320))
	_tick(r, 10)
	var keys: int = r.bytes_by_kind.get("wild_key", 0)
	check_eq(keys, 2 * NetProtocol.CREATURE_HEADER, "each client's first keyframe: nothing in view, 5 B")
	var deer: CreatureSim = herd.spawn(DEER, f + Vector2(600, 0))
	var walking: int = 0
	for t: int in 300:
		deer.state = CreatureSim.State.WANDER
		deer.target = deer.home + Vector2(0, 90 if t % 200 < 100 else -90)
		_tick(r)
		walking += 1
	check_eq(r.bytes_by_kind.get("wild", 0), 0, "a creature walking off screen sends nothing, %d ticks" % walking)
	check_eq(c.s.client.wild_msgs, 1, "only the first keyframe has come")
	# Into the box.
	deer.pos = f + Vector2(30, 0)
	deer.home = deer.pos
	deer.target = deer.pos + Vector2(0, 40)
	deer.state = CreatureSim.State.WANDER
	_tick(r, 9)
	var sent_in_view: int = r.bytes_by_kind.get("wild", 0)
	check(sent_in_view > 0, "in view: batches")
	check_eq(c.s.client.combat.creature_last.creatures.size(), 1, "the client has it")
	check_eq(far.s.client.combat.creature_last.creatures.size(), 0, "the one 320 px north does not (the box is %s high)" % box.y)
	check_eq(far.s.client.wild_msgs, 1, "and got nothing")
	# It stops: one keyframe, then nothing.
	herd.rest(deer)
	deer.home = deer.pos
	_tick(r, 15)
	var settled: int = c.s.client.wild_msgs
	var bytes_then: int = r.bytes_by_kind.get("wild", 0)
	var batches_then: int = r.host.creature_batches_sent
	for t: int in 40:
		herd.rest(deer)
		_tick(r)
	check_eq(c.s.client.wild_msgs, settled, "standing still: not a byte")
	check_eq(r.bytes_by_kind.get("wild", 0), bytes_then, "the same")
	check_eq(r.host.creature_batches_sent, batches_then, "the same on the host's count")
	check_eq(c.s.client.combat.creature_keyframes >= 2, true, "a keyframe after the last batch")
	# It leaves the box: a batch without it.
	deer.pos = f + Vector2(600, 0)
	_tick(r, 9)
	check_eq(c.s.client.combat.creature_last.creatures.size(), 0, "out of view: gone from the batches")
	check(not _drawn(r, c).has(deer.id), "and from the picture")
	# It comes back while the client is away: nothing goes to the dungeon, a keyframe on return.
	var m: NetMember = member_of_peer(r, 101)
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	_tick(r, 8)
	check_eq(c.s.local_map(), Config.MAP_DUNGEON, "the client is down")
	var down: int = c.s.client.wild_msgs
	deer.pos = r.surface.arrival_point() + Vector2(30, 0)
	deer.home = deer.pos
	deer.target = deer.pos + Vector2(0, 60)
	deer.state = CreatureSim.State.WANDER
	_tick(r, 12)
	check_eq(c.s.client.wild_msgs, down, "in the dungeon: no creature message")
	check(c.s.client.combat.arena.herd == null, "the dungeon's mirror has no herd")
	var late: NetProtocol.CreatureBatch = NetProtocol.CreatureBatch.new()
	late.ok = true
	check(not c.s.client.combat.on_creatures(late, false), "a batch overtaking the entry is skipped")
	r.host.move_to_map(m, Config.MAP_SURFACE)
	_tick(r, 8)
	check_eq(c.s.local_map(), Config.MAP_SURFACE, "the client is back")
	check(c.s.client.combat.arena.herd != null and c.s.client.combat.creature_last != null \
		and c.s.client.combat.creature_last.creatures.size() == 1, "its keyframe brought the deer")
	_free_rig(r)


## M11 review: the camera stops at the map's edge, so the player walks on past the middle of the screen. Every corner of the screen is
## in the box there, at every edge and corner of the map, at 16:9 and 21:9.
func _check_view_at_the_edge() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, Vector2(128 * Config.TILE, 96 * Config.TILE))
	var e: NetProtocol.CreatureState = _state(1, HARE)
	var one: Array[NetProtocol.CreatureState] = [e]
	var missed: int = 0
	var points: int = 0
	var w: float = area.size.x
	var h: float = area.size.y
	for view: Vector2 in [Vector2(Config.VIEW_SIZE), Vector2(640.0, 270.0)]:
		for feet: Vector2 in [Vector2(w - 2.0, h / 2.0), Vector2(2.0, h / 2.0), Vector2(w / 2.0, 2.0), Vector2(w / 2.0, h - 2.0),
				Vector2(2.0, 2.0), Vector2(w - 2.0, 2.0), Vector2(2.0, h - 2.0), Vector2(w - 2.0, h - 2.0), Vector2(w - 96.0, 1008.0)]:
			var centre: Vector2 = PlayerCamera.clamp_center(feet, area, view)
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					e.pos = (centre + Vector2(sx, sy) * view / 2.0).clamp(area.position, area.end)
					points += 1
					if SessionHost.in_view(one, feet, area).is_empty():
						missed += 1
	check_eq(missed, 0, "every corner of every screen is in the box (%d points)" % points)
	# And a real client: inside the rare zone of the default seed, near the east edge, a deer at the screen's west side.
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var feet2: Vector2 = Vector2(w - 96.0, 1008.0)
	var c: Client = _join(r, 101, ARCHER, feet2)
	var screen_west: float = PlayerCamera.clamp_center(feet2, area, Vector2(Config.VIEW_SIZE)).x - Config.VIEW_SIZE.x / 2.0
	var deer: CreatureSim = herd.put_resting(DEER, Vector2(screen_west + 24.0, 1008.0), 100)
	check(feet2.x - deer.pos.x > Config.NET_CREATURE_VIEW_PX.x, "farther from the feet than the box's half width")
	_tick(r, 9)
	check(_drawn(r, c).has(deer.id), "on its screen, so it is drawn")
	_free_rig(r)


## M11 review: a creature out of the box and back before its going was drawn stays in the picture.
func _check_back_in_view() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var near: Vector2 = f + Vector2(60, 0)
	var deer: CreatureSim = herd.put_resting(DEER, near, 100)
	_tick(r, 9)
	var tracks: Dictionary[int, NetCombat.CreatureTrack] = c.s.client.combat.creatures
	check(_drawn(r, c).has(deer.id), "in view: drawn")
	deer.pos = f + Vector2(600, 0)
	_tick(r, 3)
	var track: NetCombat.CreatureTrack = tracks.get(deer.id, null)
	if not check(track != null and track.gone_at >= 0, "a batch without it: its going is noted"):
		_free_rig(r)
		return
	check(float(r.s.tick) - SessionClient.interp_delay_ticks() < float(track.gone_at), "and not drawn yet")
	deer.pos = near
	_tick(r, 3)
	check_eq(track.gone_at, -1, "back in a batch: it has not gone after all")
	_tick(r, ceili(SessionClient.interp_delay_ticks()) + 3)
	check(_drawn(r, c).has(deer.id), "still drawn when its going would have come")
	_free_rig(r)


func _check_interpolation() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	r.delay = 2
	var hare: CreatureSim = herd.spawn(HARE, f + Vector2(20, 0))
	var at: Dictionary[int, Vector2] = {}
	herd.bolt(hare, f)
	var worst: float = 0.0
	var drawn_samples: int = 0
	for t: int in 70:
		_tick(r)
		at[r.s.tick] = hare.pos
		var t_fresh: float = float(r.s.tick - r.delay)
		var delay: float = SessionClient.interp_delay_ticks()
		c.s.client.combat.sample(t_fresh, delay)
		var list: Array[CreatureSim] = c.s.client.combat.arena.herd.list
		var tick_drawn: int = floori(t_fresh - delay)
		if list.is_empty() or not at.has(tick_drawn):
			continue
		worst = maxf(worst, list[0].pos.distance_to(at[tick_drawn]))
		drawn_samples += 1
	check(drawn_samples > 20, "the client drew it (%d samples)" % drawn_samples)
	check(worst <= DRAW_BOUND_PX, "as the host had it then: within %.1f px (worst %.2f)" % [DRAW_BOUND_PX, worst])
	# The marks on the mirror.
	hare.flash_ticks = Config.HIT_FLASH_TICKS
	hare.stun_ticks = 90
	hare.slow_pct = 30
	hare.slow_ticks = 90
	hare.poison_ticks = 90
	hare.poison_damage = 1
	hare.poison_timer = 60
	_tick(r, 12 + r.delay)
	var s: CreatureSim = _drawn(r, c).get(hare.id, null)
	check(s != null and s.stunned() and s.slowed() and s.poisoned(), "stunned, slowed, poisoned on the client")
	# An older batch that comes late changes nothing.
	var combat: NetCombat = c.s.client.combat
	var stale_before: int = combat.creature_stale
	var old: NetProtocol.CreatureBatch = NetProtocol.CreatureBatch.new()
	old.ok = true
	old.tick = combat.creature_tick - 3
	check(combat.on_creatures(old, false) and combat.creature_stale == stale_before + 1 and combat.creature_last != old, "a late batch is stale")
	# The flash runs down with the drawing time, the rope goes to the thrower as drawn here.
	var tr: NetCombat.CreatureTrack = NetCombat.CreatureTrack.new()
	tr.id = 9
	var snap: NetCombat.CreatureSnap = NetCombat.CreatureSnap.new()
	snap.tick = 100
	snap.e = _state(9, HARE)
	snap.e.state = CreatureSim.State.IDLE
	snap.e.flash = 5
	snap.e.holder = 2
	tr.snaps.append(snap)
	var seen: Dictionary[int, Vector2] = {2: Vector2(40, 60)}
	var drawn_now: CreatureSim = NetCombat.sample_creature(tr, 102.0, seen)
	check_eq(drawn_now.flash_ticks, 3, "the flash two ticks on")
	check(drawn_now.held() and drawn_now.held_from == Combat.body_point(Vector2(40, 60)), "held, its rope to the holder as drawn here")
	var nobody: Dictionary[int, Vector2] = {}
	var away: CreatureSim = NetCombat.sample_creature(tr, 102.0, nobody)
	check(away.held() and away.held_from == away.pos, "a holder not drawn here: no rope")
	r.delay = 0
	# A corpse draws dead, then goes.
	herd.hit(hare, hare.hp, 0)
	_tick(r, 12)
	var d: CreatureSim = _drawn(r, c).get(hare.id, null)
	check(d != null and not d.alive() and not d.can_be_taken(), "a corpse")
	_tick(r, Config.CREATURE_CORPSE_TICKS + 12)
	check(not _drawn(r, c).has(hare.id), "then gone")
	_free_rig(r)


func _check_late_join() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var first: Client = _join(r, 101, ARCHER, f)
	r.host.collection().put_test(4, 7)
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	var far_off: CreatureSim = herd.put_resting(DEER, f + Vector2(600, 0), 100)
	_tick(r, 6)
	check_eq(first.s.client.collection.count(), 4, "the first client heard the change")
	var late: Client = _join(r, 102, CLERIC, f + Vector2(-30, 0))
	_tick(r, 2)
	check_eq(late.s.client.collection.describe(), r.host.collection().describe(), "the late joiner has the whole collection")
	check_eq(_logged(late, "collection"), 0, "what its snapshot held is no news for its log")
	if check(not late.wild_keys.is_empty(), "a keyframe on joining"):
		var first_key: Array[NetProtocol.CreatureState] = late.wild_keys[0].creatures
		check(first_key.size() == 1 and first_key[0].id == fox.id, "of what it sees, not the whole herd (%d, the deer %d is far off)" % [first_key.size(), far_off.id])
	check_eq(late.surface.data.collection, late.s.client.collection, "on its world, one object")
	check(late.surface.data.rare_zone != null, "the zone")
	check_eq(late.surface.data.rare_zone.describe(), r.surface.data.rare_zone.describe(), "the host's")
	check(late.surface.rare_view != null, "drawn")
	check_eq(late.surface.data.content_hash(), r.surface.data.content_hash(), "the same world hash")
	var drawn: Dictionary[int, CreatureSim] = _drawn(r, late)
	check(drawn.has(fox.id), "its keyframe brought the fox")
	check(drawn[fox.id].can_be_taken(), "hurt enough: the glow shows on its machine")
	check_eq(drawn[fox.id].hp, fox.hp, "with the host's HP")
	check_eq(late.s.client.tally_msgs, 1, "one message after the welcome")
	# Malformed messages are counted and dropped.
	var bad_before: int = late.s.bad_messages
	var kept: String = late.s.client.collection.describe()
	late.s.client.on_tally(PackedByteArray([1, 2, 3]))
	check_eq(late.s.client.bad_tally, 1, "a short collection message is counted")
	check_eq(late.s.bad_messages, bad_before + 1, "as a bad message")
	check_eq(late.s.client.collection.describe(), kept, "and changes nothing")
	late.s.client._apply_wild(PackedByteArray([1, 2]), false)
	check_eq(late.s.bad_messages, bad_before + 2, "a short creature batch too")
	late.s.bad_messages = bad_before
	r.host.collection().register(&"take_ash_owl")
	_tick(r, 3)
	check_eq(_logged(late, "collection"), 1, "what is new is news")
	_free_rig(r)


func _check_map_entry() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	var seen: CreatureSim = herd.put_resting(DEER, f + Vector2(40, 0), 100)
	_tick(r, 6)
	check(c.s.client.combat.creatures.has(seen.id), "a creature in view has its track")
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	_tick(r, 8)
	check(c.s.client.combat.creatures.is_empty(), "no track comes along to the dungeon (M11 review)")
	check_eq(c.dungeon.data.collection, c.s.client.collection, "the dungeon's data has the same object")
	check_eq(r.dungeon.data.collection, r.surface.data.collection, "on the host too")
	# A kill on the surface while it is down: it hears (its panel shows it there).
	var hare: CreatureSim = herd.spawn(HARE, f + Vector2(32, 0))
	herd.hit(hare, hare.hp, r.s.local.player.get_instance_id())
	_tick(r, 3)
	check_eq(c.s.client.collection.kills, 1, "the kill reached the dungeon")
	check(c.s.client.collection.has(&"hunt_hare"), "the entry")
	check_eq(c.dungeon.data.content_hash(), r.dungeon.data.content_hash(), "the dungeon's hash does not care")
	# Back up, while a change comes in during the stream: small chunks, so the live message overtakes the snapshot taken before it.
	WorldSnapshot.chunk_bytes = 16
	r.host.move_to_map(m, Config.MAP_SURFACE)
	_tick(r, 2)
	check(r.host.streams.has(101), "the surface is still on its way")
	r.host.collection().register(&"hunt_deer")
	_tick(r, 2)
	check(c.s.client.collection.has(&"hunt_deer"), "the change came first, live")
	check(r.host.streams.has(101), "and the snapshot, older than it, is still on its way")
	_tick(r, 14)
	WorldSnapshot.chunk_bytes = Config.NET_SNAPSHOT_CHUNK_BYTES
	check_eq(c.s.local_map(), Config.MAP_SURFACE, "the client is up")
	check_eq(c.s.client.collection.describe(), r.host.collection().describe(), "after the entry: the host's, the change included")
	check_eq(c.surface.data.collection, c.s.client.collection, "the same object on the new surface data")
	check_eq(c.surface.data.content_hash(), r.surface.data.content_hash(), "the same world")
	_free_rig(r)


# --- the benefits ----------------------------------------------------------------------------------------------

func _check_benefits() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var col: Collection = r.host.collection()
	var deer: CreatureSim = herd.put_resting(DEER, f + Vector2(90, 0), 100)
	check_eq(Collection.arrow_damage(12, m.player), 12, "no entries: a bow's 12")
	check_eq(Collection.defence_bonus(m.player.data), 0, "no defence")
	col.put_test(3, 0)
	_tick(r, 2)
	check(c.s.client.collection.benefit(&"class"), "the client lights the class benefit")
	check_eq(Collection.arrow_damage(12, m.player), 13, "the host's number: 13")
	check_eq(Collection.arrow_damage(12, r.s.local.player), 12, "the paladin's stay")
	# A real arrow from the client's frame.
	c.action = _click(Creatures.aim_point(deer))
	_tick(r)
	c.action = null
	_tick(r, 60)
	check_eq(deer.hp_max() - deer.hp, 13, "the arrow landed with the host's number (hp %d)" % deer.hp)
	var stopped: bool = false
	for e: NetProtocol.ShotEvent in c.shot_events:
		if e.kind == NetProtocol.ShotEvent.Kind.END and NetProtocol.SHOT_STOPS[e.why] == "creature":
			stopped = true
	check(stopped, "the shot's end on the wire says a creature stopped it")
	var hps: Array = c.s.client.combat.creature_hp.get(deer.id, [])
	check_eq(hps.back(), deer.hp, "and the client saw it")
	c.action = null
	# In the dungeon too, the benefit is the world's.
	col.put_test(5, 0)
	_tick(r, 2)
	r.host.move_to_map(m, Config.MAP_DUNGEON)
	_tick(r, 8)
	check_eq(Collection.defence_bonus(m.player.data), Config.COLLECTION_DEFENCE, "the defence holds in the dungeon: the same object")
	var hp: int = m.player.vitals.hp
	m.player.take_hit(12, true)
	check_eq(hp - m.player.vitals.hp, 11, "a knife's 12 lands as 11 with no armour on")
	r.host.move_to_map(m, Config.MAP_SURFACE)
	_tick(r, 8)
	check(c.s.client.collection.benefit(&"all"), "the client lights the all benefit")
	# The restock: seven minutes at eight entries, on the host's clock.
	var sh: Shop = r.host.shop()
	check_eq(sh.restock_ticks, Config.SHOP_RESTOCK_TICKS, "ten minutes")
	sh.clock = Config.COLLECTION_RESTOCK_TICKS - 2
	var restocks: int = r.host.restocks
	_tick(r, 3)
	check_eq(r.host.restocks, restocks, "at seven minutes with five entries: not yet")
	col.put_test(8, 0)
	_tick(r, 2)
	check(c.s.client.collection.world_benefit(), "the client lights the world benefit")
	check_eq(r.host.restocks, restocks + 1, "eight entries: the running clock is past seven minutes, the next tick restocks")
	_free_rig(r)


func _check_bodies() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	await _join_quiet(r, 101, ARCHER, f)
	var target: Vector2i = Aim.feet_cell(f) + Vector2i(0, 1)
	var deer: CreatureSim = herd.spawn(DEER, Arena.spawn_feet(target + Vector2i(1, 0)))
	check(r.host.creature_feet(Config.MAP_SURFACE).has(deer.pos), "its feet count on the surface")
	check(r.host.creature_feet(Config.MAP_DUNGEON).is_empty(), "nothing in the dungeon")
	var m: NetMember = member_of_peer(r, 101)
	check(r.host.bodies_but(Config.MAP_SURFACE, m.player).has(deer.pos), "a body a piece may not cover (M11a's rule)")
	check(r.s.bots.creature_feet().has(deer.pos), "the host's machine: the build ghost's bodies")
	# A placed station on its tile is refused; with the creature gone it goes down.
	m.player.inventory.add(&"alchemy_table", 1)
	var slot: int = slot_of(m.player.inventory, &"alchemy_table")
	var place: NetProtocol.InputFrame = _op(NetProtocol.Op.USE, Config.MAP_SURFACE, target, slot)
	r.host.run_frame(m, place)
	check_eq(m.player.inventory.count_of(&"alchemy_table"), 1, "a blocking station is not put down on a creature")
	check_eq(m.ops_refused.get(WorldItems.WHY_BODY, 0), 1, "the host refused it: a body is there (%s)" % m.ops_refused)
	herd.hit(deer, deer.hp, 0)
	check(not r.host.creature_feet(Config.MAP_SURFACE).has(deer.pos), "a corpse does not")
	m.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_SURFACE, target, slot))
	check_eq(m.ops_done.get("place", 0), 1, "with the creature dead it goes down (%s)" % m.ops_refused)
	_free_rig(r)


## M11 review: a footprint walls in what stands under it, so the altar keeps off creatures on the host's rule too, a click's and a fallback's.
func _check_altar_bodies() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	await _join_quiet(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	var data: WorldData = r.surface.data
	for e: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		r.host.apply_world_edit(e)
	m.player.set_carrying_altar(true)
	var aim: Vector2i = Aim.feet_cell(f) + Vector2i(1, 0)
	var rect: Rect2i = AltarMove.place_rect(f, aim)
	var deer: CreatureSim = herd.put_resting(DEER, Arena.spawn_feet(rect.get_center()), 100)
	deer.state_ticks = -100000
	var bodies: Array[Vector2] = [deer.pos]
	check(AltarMove.covers_a_body(rect, bodies), "it stands under the footprint")
	check_eq(AltarMove.place_refusal(data, rect, [f] as Array[Vector2]), "", "and the place is free but for it")
	var place: NetProtocol.InputFrame = _op(NetProtocol.Op.ALTAR_PLACE, Config.MAP_SURFACE, aim)
	r.host.run_frame(m, place)
	check_eq(m.refused(WorldItems.WHY_BODY), 1, "the host refuses it")
	check(m.player.carrying_altar and not data.altar_rect.has_area(), "still carried")
	# Without the creature the same click puts it down.
	herd.list.erase(deer)
	m.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(m, _op(NetProtocol.Op.ALTAR_PLACE, Config.MAP_SURFACE, aim))
	check_eq(data.altar_rect, rect, "with the creature gone it goes down there")
	# Going down, the same: a creature stands where it would have come down.
	for e2: EditLog.WorldEdit in AltarMove.pickup_edits(data):
		r.host.apply_world_edit(e2)
	m.player.set_carrying_altar(true)
	var no_one: Array[Vector2] = []
	var would: Rect2i = AltarMove.set_down_fallback(data, f, r.host.altar_home, r.host.bodies_on(Config.MAP_SURFACE), no_one)
	var deer2: CreatureSim = herd.put_resting(DEER, Arena.spawn_feet(would.get_center()), 100)
	deer2.state_ticks = -100000
	check(r.host._set_altar_down(m), "the carrier's set down")
	check(data.altar_rect != would, "not on the place it would have taken")
	check(not AltarMove.covers_a_body(data.altar_rect, [deer2.pos] as Array[Vector2]), "not on the creature (%s)" % data.altar_rect)
	_free_rig(r)


## M11 review: the thrower left and its slot went to someone else: the rope is nobody's, not the newcomer's.
func _check_holder_left() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	herd.hold(fox, 120, Combat.body_point(f), m.player.get_instance_id())
	_tick(r, 1)
	var slot: int = m.slot
	check_eq(r.host._creature_states(herd)[0].holder, slot, "its slot, while it is there")
	c.ticking = false
	r.host.on_peer_disconnected(101)
	_tick(r, 1)
	check_eq(r.host._creature_states(herd)[0].holder, NetProtocol.NO_SLOT, "gone: nobody's")
	await _join_quiet(r, 102, CLERIC, f + Vector2(0, 30))
	check_eq(member_of_peer(r, 102).slot, slot, "the newcomer has its slot")
	check(fox.held(), "the hold runs on")
	check_eq(r.host._creature_states(herd)[0].holder, NetProtocol.NO_SLOT, "the rope is not the newcomer's")
	_free_rig(r)


## The new recipes through the M6 / M7 request path, the first-acquire rule on the client too, the rare armour on the wire.
func _check_recipes() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var o: Client = _join(r, 102, PALADIN, f + Vector2(0, 16))
	var m: NetMember = member_of_peer(r, 101)
	var q: NetMember = member_of_peer(r, 102)
	var at: Vector2i = Aim.feet_cell(f) + Vector2i(2, 0)
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at, WorldData.PLACEABLE_WORKBENCH))
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, at + Vector2i(0, 2), WorldData.PLACEABLE_ANVIL))
	for who: NetMember in [m, q]:
		who.player.inventory.add(&"planks", 1)
		who.player.inventory.add(&"hide_worn", 1)
		who.player.inventory.add(&"hide_fine", 2)
		who.player.inventory.add(Config.RARE_MATERIAL, 3)
		who.inventory_dirty = true
	_tick(r, 3)
	var snare: int = Crafting.index_of(Capture.SNARE)
	var armor: int = Crafting.index_of(&"armor_rare")
	check(Crafting.unlocked(Crafting.recipe(&"armor_rare"), c.s.local.player.inventory), "the first-acquire rule on the client: the armour's unlocked there")
	var craft: NetProtocol.InputFrame = _op(NetProtocol.Op.CRAFT, Config.MAP_SURFACE, Vector2i.ZERO)
	craft.recipe = snare
	r.host.run_frame(q, craft)
	check_eq(q.ops_refused.get("archer only", 0), 1, "a paladin may not make a snare, on the host either")
	check_eq(q.player.inventory.count_of(Capture.SNARE), 0, "none made")
	var craft2: NetProtocol.InputFrame = _op(NetProtocol.Op.CRAFT, Config.MAP_SURFACE, Vector2i.ZERO)
	craft2.recipe = snare
	r.host.run_frame(m, craft2)
	check_eq(m.player.inventory.count_of(Capture.SNARE), 2, "the archer's: two snares from the one wood and the one hide")
	check_eq(m.player.inventory.count_of(&"planks"), 0, "the wood went")
	_tick(r, 3)
	check_eq(c.s.local.player.inventory.count_of(Capture.SNARE), 2, "the client has them")
	var craft3: NetProtocol.InputFrame = _op(NetProtocol.Op.CRAFT, Config.MAP_SURFACE, Vector2i.ZERO)
	craft3.recipe = armor
	r.host.run_frame(q, craft3)
	check_eq(q.player.inventory.count_of(&"armor_rare"), 1, "anyone may make the rare armour at the anvil: the paladin's")
	check_eq(q.player.inventory.count_of(Config.RARE_MATERIAL), 0, "it took the material")
	var wear: NetProtocol.InputFrame = _op(NetProtocol.Op.ARMOR, Config.MAP_SURFACE, Vector2i.ZERO, slot_of(q.player.inventory, &"armor_rare"))
	q.op_budget = NetMember.OP_BUDGET_MAX
	r.host.run_frame(q, wear)
	check(q.player.inventory.armor != null and q.player.inventory.armor.id == &"armor_rare", "worn on the host")
	_tick(r, 3)
	var mine: Inventory = o.s.local.player.inventory
	check(mine.armor != null and mine.armor.id == &"armor_rare" and mine.armor.durability == q.player.inventory.armor.durability, "and on the client, with its durability")
	var hp: int = q.player.vitals.hp
	q.player.take_hit(12, true)
	check_eq(hp - q.player.vitals.hp, 6, "a knife's 12 less the rare armour's 6")
	_free_rig(r)


# --- the host's attack paths -------------------------------------------------------------------------------------

## A client's swing, skill and thrown poison reach a creature through the host's Arena, with the host's numbers.
func _check_attack_paths() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	# A tier-1 sword's swing: its damage and its wear.
	await _join_quiet(r, 101, PALADIN, f)
	var pal: NetMember = member_of_peer(r, 101)
	pal.player.inventory.add(&"sword_t1", 1)
	var t1: int = slot_of(pal.player.inventory, &"sword_t1")
	var full: int = pal.player.inventory.stack_at(t1).durability
	var deer: CreatureSim = herd.put_resting(DEER, f + Vector2(18, 0), 100)
	var aim: int = Combat.aim_code(deer.pos - Combat.aim_origin(f))
	r.host.run_frame(pal, _use(Config.MAP_SURFACE, Aim.feet_cell(f) + Vector2i(1, 0), t1, aim))
	check(pal.player.action_anim >= 0, "the swing plays")
	_land(r, pal)
	_tick(r)
	var dmg: int = Gear.attack_damage(pal.player.inventory.stack_at(t1), Combat.attack_for(&"sword").damage)
	check(dmg > Combat.attack_for(&"sword").damage, "tier 1 hits harder")
	check_eq(deer.hp_max() - deer.hp, dmg, "the swing landed with the tier-1 damage")
	check(pal.player.inventory.stack_at(t1).durability < full, "and wore the sword")
	check_eq(deer.state, CreatureSim.State.FLEE, "it bolts")
	# The archer's piercing arrow.
	await _join_quiet(r, 102, ARCHER, f + Vector2(0, 48))
	var arc: NetMember = member_of_peer(r, 102)
	var hare: CreatureSim = herd.put_resting(DEER, arc.player.sim_position + Vector2(70, 0), 100)
	arc.player.skills.resource = Skills.resource_cap(ARCHER)
	var sk: NetProtocol.InputFrame = _op(NetProtocol.Op.SKILL, Config.MAP_SURFACE, Aim.feet_cell(arc.player.sim_position) + Vector2i(1, 0), WEAPON_SLOT)
	sk.skill_slot = Skills.Slot.IDENTITY
	sk.cursor = Creatures.aim_point(hare)
	sk.aim = Combat.aim_code(sk.cursor - Combat.aim_origin(arc.player.sim_position))
	sk.pick = NetProtocol.NO_SLOT
	r.host.run_frame(arc, sk)
	check(arc.player.action_anim >= 0, "the skill plays (%s)" % arc.ops_refused)
	_land(r, arc)
	_tick(r, 40)
	check_eq(hare.hp_max() - hare.hp, Skills.num_i(Skills.PIERCING_ARROW, "damage"), "the piercing arrow hit it with the skill's damage")
	# A herbalist's thrown poison.
	await _join_quiet(r, 103, "herbalist", f + Vector2(0, -48))
	var her: NetMember = member_of_peer(r, 103)
	her.player.inventory.add(&"potion_poison", 1)
	var bottle: int = slot_of(her.player.inventory, &"potion_poison")
	var doe: CreatureSim = herd.put_resting(DEER, her.player.sim_position + Vector2(70, 0), 100)
	var th: NetProtocol.InputFrame = _op(NetProtocol.Op.THROW, Config.MAP_SURFACE, Aim.feet_cell(her.player.sim_position) + Vector2i(1, 0), bottle)
	th.cursor = doe.pos
	th.aim = Combat.aim_code(th.cursor - Combat.aim_origin(her.player.sim_position))
	th.pick = NetProtocol.NO_SLOT
	r.host.run_frame(her, th)
	check(her.player.action_anim >= 0, "the throw plays (%s)" % her.ops_refused)
	_land(r, her)
	_tick(r, 40)
	check(doe.poisoned(), "the splash poisoned it")
	_free_rig(r)


# --- a client's click ------------------------------------------------------------------------------------------

func _check_client_click() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var m: NetMember = member_of_peer(r, 101)
	m.player.inventory.add(Capture.SNARE, 2)
	m.inventory_dirty = true
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 100)
	_tick(r, 6)
	var me: Player = c.s.local.player
	check(me.capture_on, "the session turned the snare on")
	check_eq(me.herd_here(), c.s.client.combat.arena.herd, "on the mirror's herd")
	var slot: int = slot_of(me.inventory, Capture.SNARE)
	check(slot >= 0, "the client has its snares from the host")
	c.action = _select(slot)
	_tick(r, 3)
	var drawn: Dictionary[int, CreatureSim] = _drawn(r, c)
	check(drawn.has(fox.id), "it draws the fox")
	# Healthy: refused on this machine, nothing goes up.
	var refused: Array[String] = []
	me.capture_refused.connect(func(why: String, _c: CreatureSim) -> void: refused.append(why))
	var sent: int = r.host.capture_refusals.size()
	c.action = _click(Creatures.aim_point(drawn[fox.id]))
	_tick(r)
	c.action = null
	_tick(r)
	check_eq(refused, [Capture.WHY_HEALTHY] as Array[String], "this machine says why")
	check_eq(r.host.capture_refusals.size(), sent, "and the host heard nothing")
	c.s.client.combat.mark_refused(fox.id)
	check(_drawn(r, c)[fox.id].refused_ticks > 0, "the refused mark shows here at once")
	# Hurt: the throw is predicted, the capture is the host's.
	fox.hp = fox.hp_max() * Config.CAPTURE_HP_PCT / 100
	herd.rest(fox)
	_tick(r, 8)
	drawn = _drawn(r, c)
	check(drawn[fox.id].can_be_taken(), "it reads as takeable here")
	c.action = _click(Creatures.aim_point(drawn[fox.id]))
	_tick(r)
	c.action = null
	check_eq(c.s.client.prediction.sim.action, Config.CAPTURE_ANIM, "the throw plays at once on the client")
	check_eq(me.inventory.count_of(Capture.SNARE), 2, "nothing spent there")
	_tick(r, Capture.impact_tick() + 12)
	check_eq(r.host.captures, 1, "the host took it")
	check_eq(me.inventory.count_of(Capture.SNARE), 1, "the host's inventory came back")
	check_eq(me.inventory.count_of(Config.RARE_MATERIAL), 1, "with the material")
	check(c.s.client.collection.has(&"take_lamp_fox"), "and the entry")
	check_eq(c.s.client.prediction.action_corrections, 0, "the predicted action = the host's")
	check_eq(c.s.client.prediction.corrections, 0, "no position corrections")
	# What it holds rides the batches while the throw plays.
	check_eq(c.s.client.combat.creature_marks.get("held", 0) > 0, true, "the hold reached the client")
	_free_rig(r)


## The host's own player: its click runs the same rule on the host's own herd, through the same request.
func _check_host_click() -> void:
	var r: Rig = _rig(ARCHER)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var me: Player = r.s.local.player
	me.teleport(f)
	me.inventory.add(Capture.SNARE, 1)
	me.inventory.select(slot_of(me.inventory, Capture.SNARE))
	check(me.capture_on and me.herd_here() == herd, "the host's own player has the snare on its herd")
	var fox: CreatureSim = herd.put_resting(FOX, f + Vector2(24, 0), 30)
	r.action = _click(Creatures.aim_point(fox))
	_tick(r)
	r.action = null
	check_eq(r.s.local.ops_done.get("capture", 0), 1, "its click is a CAPTURE")
	check(fox.held(), "held")
	check_eq(fox.hold_ticks, Capture.impact_tick() + Config.CAPTURE_HOLD_SLACK_TICKS + Config.NET_CAPTURE_HOLD_SLACK_TICKS - 1,
		"held the host's longer time (a client's frames can come late), one tick gone")
	_tick(r, Capture.impact_tick() + 2)
	check_eq(r.host.captures, 1, "taken")
	check_eq(me.inventory.count_of(Config.RARE_MATERIAL), 1, "into its inventory")
	_free_rig(r)


## A click at `at` this tick (pressed, not held on).
static func _click(at: Vector2) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = at
	a.aiming = true
	a.use_pressed = true
	return a


# --- traffic ------------------------------------------------------------------------------------------------------

func _check_traffic() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	var herd: Creatures = r.host.herd_on(Config.MAP_SURFACE)
	var f: Vector2 = spot(r)
	var c: Client = _join(r, 101, ARCHER, f)
	var caps: int = 0
	var list: Array[CreatureSim] = []
	for kind: StringName in Config.CREATURES:
		for i: int in Creatures.cap_of(kind):
			list.append(herd.spawn(kind, f + Vector2(48 + 8 * caps, 0)))
			caps += 1
	check_eq(caps, 13, "the caps add up to thirteen alive")
	_tick(r, 3)
	r.bytes_by_kind.clear()
	var ticks: int = 300
	for t: int in ticks:
		for s: CreatureSim in list:
			s.state = CreatureSim.State.WANDER
			s.target = f + Vector2(48, 120 if t % 120 < 60 else -40)
		_tick(r)
	var wild_bytes: int = r.bytes_by_kind.get("wild", 0)
	var bps: float = float(wild_bytes) / (float(ticks) / Config.NET_TICK_RATE)
	note("creature traffic at the caps, one client: %.0f B/s" % bps)
	check(bps > 0.0 and bps <= CAPS_MAX_BPS, "every creature moving in view: %.0f B/s, at most %.0f" % [bps, CAPS_MAX_BPS])
	check(c.s.client.combat.creature_last.creatures.size() == caps, "all thirteen in the batch")
	_free_rig(r)
	# The natural herd of seed 1 for two minutes: how often a batch of the whole herd would change, how often the box around the altar's.
	var data: WorldData = SurfaceGen.generate(Config.DEFAULT_SEED)
	var nat: Creatures = Creatures.new()
	nat.setup(data, Config.DEFAULT_SEED)
	var at: Vector2 = data.altar_center_px()
	var whole: StateBroadcast = StateBroadcast.new()
	var box: StateBroadcast = StateBroadcast.new()
	var checks: int = 0
	for t: int in 7200:
		nat.step([] as Array[Player])
		if t % (Config.NET_TICK_RATE / Config.NET_STATE_HZ) != 0:
			continue
		checks += 1
		var states: Array[NetProtocol.CreatureState] = []
		for s: CreatureSim in nat.list:
			states.append(NetProtocol.creature_of(s, NetProtocol.NO_SLOT))
		whole.decide_encoded(t, NetProtocol.encode_creatures(t, states))
		box.decide_encoded(t, NetProtocol.encode_creatures(t, SessionHost.in_view(states, at, Rect2(Vector2.ZERO, Vector2(nat.data.size * Config.TILE)))))
	note("the natural herd, two minutes, %d batch ticks: the whole herd's batch changes on %d, a client at the altar's on %d" % [checks, whole.batches, box.batches])
	check(whole.batches * 10 >= checks * 9, "someone is nearly always walking: a batch of the whole herd would rarely rest")
	check(box.batches * 4 < whole.batches, "a client at the altar gets far fewer")


func _check_v12_refused() -> void:
	var r: Rig = _rig(PALADIN)
	await await_frames(1)
	r.host.on_hello(170, NetProtocol.encode_hello(NetProtocol.class_index(ARCHER), 12))
	var to_peer: Array[Array] = r.s.take_for(170)
	var refusal: PackedByteArray = PackedByteArray()
	if to_peer.size() == 1:
		refusal = to_peer[0][2]
	check(to_peer.size() == 1 and str(to_peer[0][1]) == "refused" and NetProtocol.decode_refusal(refusal) == "version"
		and member_of_peer(r, 170) == null and not r.host.streams.has(170), "a version 12 hello: one refusal (version), no member, no world")
	_free_rig(r)
