extends "res://tests/test_net_fields.gd"
## M7c: the workbench chain, gear, the storage chest, building, doors and trees in sessions, in one process: the real
## SessionHost and SessionClient flows on the rig of tests/test_net_combat.gd (the host's messages captured and delivered in
## order, the clients' packets back, an optional fixed one-way delay). tests/test_net_house.gd and test_net_stock.gd run real
## sessions.
##   - the wire (protocol v8): DEMOLISH, DOOR, ARMOR and CHEST round trips, sizes, every truncation, every field out of
##     range; the inventory with durability and the armour slot; the chest slot edit (round trip, refusals, where it may
##     apply); the snapshot's chests (round trip = the same world hash, every malformed chest refused)
##   - the host against a malicious client: building out of reach, outside the map, on a spot where players appear, on
##     another player or next to one (M7c clearance), on another map, while down, spam; taking down a dungeon wall,
##     nothing, out of reach, spam; a door out of reach, closing it on someone near; putting on armour it does not have,
##     taking it off with none worn or a full inventory; a repair without its material or with nothing worn; a craft far
##     from the station; the chest from too far, a tile that is no chest, an empty slot, a full chest; chopping without
##     an axe, out of reach, spam
##   - flows: two players build a room (the host most of it, the client two walls through the wire) and both walk in
##     through the door; a door does not close on a player near it and closes on one farther away, who then walks into
##     it exactly as the host has it; a heretic outside the closed room never gets in; two clients take from one chest
##     in one tick (nothing doubles, nothing is lost) and a late joiner gets the chest's contents; a client crafts a
##     tier-1 sword at the host's anvil, it wears on attacks and on the client's death, and the client's inventory holds
##     the host's durability throughout; a client chops a tree to a stump both see, a late joiner gets the stump, the
##     walls, the doors and the chest; four players with a delay build, chop and use the chest and agree
##   - traffic: building, a door, a chest session (README "측정")

## Seed 1 (README "M7c"): the room south of the light (outside it: the heretic test), its walls, the door in the bottom row.
const ROOM_LEFT: int = 60
const ROOM_RIGHT: int = 65
const ROOM_TOP: int = 57
const ROOM_BOTTOM: int = 61
const DOOR_CELL: Vector2i = Vector2i(61, 61)
## The two walls the client builds (bottom right), and from where.
const CLIENT_WALLS: Array[Vector2i] = [Vector2i(64, 61), Vector2i(65, 61)]
const CLIENT_STANDS: Array[Vector2i] = [Vector2i(63, 62), Vector2i(66, 62)]
## Inside the room: the far corner (beyond Config.BLOCK_CLEARANCE_PX of the doorway) and the tile above the door.
const INSIDE_FAR: Vector2i = Vector2i(64, 59)
const INSIDE_DOOR: Vector2i = Vector2i(61, 60)
## Outside below the door: next to its face (within the clearance) and farther away.
const OUTSIDE_NEAR: Vector2i = Vector2i(61, 63)
const OUTSIDE_FAR: Vector2i = Vector2i(61, 66)
## The chest in the light (north of the altar, test_storage.gd's spot) and where a player opens it from.
const CHEST_AT: Vector2i = Vector2i(63, 44)
const CHEST_FEET: Vector2i = Vector2i(63, 43)
## The tree a client chops (20 tiles east of the altar) and where it stands.
const TREE: Vector2i = Vector2i(83, 52)
const TREE_FEET: Vector2i = Vector2i(83, 53)


func run() -> Array[String]:
	_check_m7_codec()
	_check_inventory_codec_v8()
	_check_chest_edit_codec()
	_check_snapshot_chests()
	await _check_build_requests()
	await _check_gear_requests()
	await _check_chest_requests()
	await _check_chop_requests()
	await _check_room_flow()
	await _check_door_opens_on_pusher()
	await _check_chest_flow()
	await _check_gear_flow()
	await _check_chop_flow()
	await _check_four_builders()
	await _measure_build_traffic()
	return failures


# --- helpers -----------------------------------------------------------------------------------------------------------

## Every cell of the room's walls (the door left out), row by row.
static func room_walls() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in range(ROOM_LEFT, ROOM_RIGHT + 1):
		out.append(Vector2i(x, ROOM_TOP))
	for y: int in range(ROOM_TOP + 1, ROOM_BOTTOM):
		out.append(Vector2i(ROOM_LEFT, y))
		out.append(Vector2i(ROOM_RIGHT, y))
	for x2: int in range(ROOM_LEFT, ROOM_RIGHT + 1):
		if Vector2i(x2, ROOM_BOTTOM) != DOOR_CELL:
			out.append(Vector2i(x2, ROOM_BOTTOM))
	return out


## A feet tile next to tile `c` from which `piece` may go down on `data` (Building.refusal with `others`), or (-1, -1).
## The tiles below (south) are tried last: a wall's face is there.
static func stand_for(data: WorldData, piece: StringName, c: Vector2i, others: Array[Vector2] = []) -> Vector2i:
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1),
			Vector2i(1, 1), Vector2i(0, 1)]:
		var f: Vector2i = c + d
		if not data.in_bounds(f) or not Movement.can_stand(data, feet_in(f)):
			continue
		if Building.refusal(data, feet_in(f), piece, c, 99, [] as Array[Vector2], [] as Array[Vector2], others).is_empty():
			return f
	return Vector2i(-1, -1)


## The host's own player builds `piece` on tile `c`: teleported to a tile next to it (stand_for) with that piece selected,
## one click aimed at it. Returns whether the piece went down.
func host_builds(r: Rig, piece: StringName, c: Vector2i) -> bool:
	var hp: Player = r.s.local.player
	var others: Array[Vector2] = r.host.others_on(Config.MAP_SURFACE, hp)
	var f: Vector2i = stand_for(r.surface.data, piece, c, others)
	if f.x < 0:
		return false
	hp.teleport(feet_in(f))
	var slot: int = slot_of(hp.inventory, piece)
	if hp.inventory.selected != slot:
		press(r, _select(slot))
	var before: int = r.host.builds_done
	press(r, click_at(centre_of(c)))
	_tick(r, Config.NET_OP_INTERVAL_TICKS)  # the host's own requests pay the budget too
	return r.host.builds_done == before + 1


## Client `c`'s bot runs `script` (NetBot) until it finishes (at most `limit` ticks), the rig ticking meanwhile (the host's
## own input: `host_script` when given, idle otherwise). Returns the ticks it took.
func bot_run(r: Rig, c: Client, script: String, limit: int = 900, host_script: String = "") -> int:
	var bot: NetBot = NetBot.new()
	var why: String = bot.parse(script)
	check(why.is_empty(), "bot script parses (%s)" % why)
	var hbot: NetBot = null
	if not host_script.is_empty():
		hbot = NetBot.new()
		hbot.parse(host_script)
	var t: int = 0
	while t < limit and (not bot.finished or (hbot != null and not hbot.finished)):
		c.action = bot.step(c.s.local.player.sim_position) if not bot.finished else null
		r.action = hbot.step(r.s.local.player.sim_position) if hbot != null and not hbot.finished else null
		_tick(r)
		t += 1
	c.action = null
	r.action = null
	return t


## The host's own player runs `script` (NetBot) to its end (at most `limit` ticks).
func host_run(r: Rig, script: String, limit: int = 900) -> int:
	var bot: NetBot = NetBot.new()
	var why: String = bot.parse(script)
	check(why.is_empty(), "host bot script parses (%s)" % why)
	var t: int = 0
	while t < limit and not bot.finished:
		r.action = bot.step(r.s.local.player.sim_position)
		_tick(r)
		t += 1
	r.action = null
	return t


## F aimed at tile `c` (a pick up request: a door's F, the chest's panel), for the host's own player or a client.
static func f_at(c: Vector2i) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = centre_of(c)
	a.aiming = true
	a.op = NetProtocol.InputFrame.new()
	a.op.op = NetProtocol.Op.PICKUP
	return a


## A request frame for member `m` straight into the host: op `op` on the surface aimed at tile `c`.
static func req(op: int, c: Vector2i = Vector2i.ZERO, slot: int = 0) -> NetProtocol.InputFrame:
	return _op(op, Config.MAP_SURFACE, c, slot)


static func chest_req(c: Vector2i, take_it: bool, slot: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = req(NetProtocol.Op.CHEST, c, slot)
	f.chest_take = take_it
	return f


## A CHEST request on a client's action this tick (the panel's click: SessionHost.attach_local_op puts it on the frame).
static func chest_click(key: Vector2i, take_it: bool, slot: int) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.op = chest_req(key, take_it, slot)
	return a


## What chest `key` of `data` holds (WorldData.Chest.describe; "" for none).
static func _chest_text(data: WorldData, key: Vector2i) -> String:
	return data.chests[key].describe() if data.chests.has(key) else ""


## Whether every client's world (surface) equals the host's.
static func worlds_agree(r: Rig) -> bool:
	for c: Client in r.clients:
		if c.s.active and c.s.local != null and c.s.local.map_id == Config.MAP_SURFACE \
				and c.surface.data.content_hash() != r.surface.data.content_hash():
			return false
	return true


## The host's world with the whole room standing (straight edits, past the rules: a late joiner's or a later check's
## starting point), the door closed or open.
func put_room(r: Rig, door_open: bool) -> void:
	for c: Vector2i in room_walls():
		r.host.apply_world_edit(Building.edit_for(Building.STONE_WALL, c))
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.WALL, DOOR_CELL,
		Walls.pack(Walls.KIND_DOOR_OPEN if door_open else Walls.KIND_DOOR, 0)))


# --- the wire (protocol v8) --------------------------------------------------------------------------------------------

func _check_m7_codec() -> void:
	check_eq(NetProtocol.VERSION, 8, "protocol version 8 (M7c)")
	check_eq(NetProtocol.CODE_COUNT, 180, "the frame is still one byte (180 codes)")
	var cases: Array[NetProtocol.InputFrame] = []
	var d: NetProtocol.InputFrame = _op(NetProtocol.Op.DEMOLISH, Config.MAP_DUNGEON, Vector2i(-3, 700))
	var door: NetProtocol.InputFrame = _op(NetProtocol.Op.DOOR, Config.MAP_SURFACE, Vector2i(61, 61))
	var on: NetProtocol.InputFrame = _op(NetProtocol.Op.ARMOR, Config.MAP_SURFACE, Vector2i.ZERO, Config.HOTBAR_SLOTS - 1)
	var off: NetProtocol.InputFrame = _op(NetProtocol.Op.ARMOR, Config.MAP_SURFACE, Vector2i.ZERO, NetProtocol.ARMOR_OFF)
	var store: NetProtocol.InputFrame = chest_req(Vector2i(63, 44), false, Config.INVENTORY_SLOTS - 1)
	var take: NetProtocol.InputFrame = chest_req(Vector2i(65, 44), true, Config.CHEST_SLOTS - 1)
	cases.append_array([d, door, on, off, store, take])
	var sizes: Array[int] = [5, 5, 1, 1, 7, 7]
	for i: int in cases.size():
		var f: NetProtocol.InputFrame = cases[i]
		f.seq = 10
		var bytes: PackedByteArray = NetProtocol.encode_inputs([f] as Array[NetProtocol.InputFrame])
		check_eq(bytes.size(), NetProtocol.INPUT_HEADER + 1 + 1 + 2 + sizes[i], "%s: %d B of fields" % [f.describe_op(), sizes[i]])
		var p: NetProtocol.InputPacket = NetProtocol.decode_inputs(bytes)
		check(p.ok and p.frames.size() == 1 and p.frames[0].same_request(f), "%s round trips (%s)" % [f.describe_op(),
			p.frames[0].describe_op() if p.ok and not p.frames.is_empty() else "refused"])
		var short_ok: int = 0
		for n: int in range(NetProtocol.INPUT_HEADER + 2, bytes.size()):  # + 1 alone is a valid frame without its request
			if NetProtocol.decode_inputs(bytes.slice(0, n)).ok:
				short_ok += 1
		check_eq(short_ok, 0, "%s: every truncation refused" % f.describe_op())
	check(not NetProtocol.op_has_map(NetProtocol.Op.ARMOR) and NetProtocol.op_has_map(NetProtocol.Op.CHEST)
		and NetProtocol.op_has_map(NetProtocol.Op.DOOR) and NetProtocol.op_has_map(NetProtocol.Op.DEMOLISH),
		"DEMOLISH, DOOR and CHEST name their map; ARMOR does not")
	# Out of range: the map, the armour slot, the chest move byte, the slots.
	var bad: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = NetProtocol.encode_inputs([door] as Array[NetProtocol.InputFrame])
	b[NetProtocol.INPUT_HEADER + 1 + 1 + 2] = Config.MAP_COUNT
	bad["DOOR on map %d" % Config.MAP_COUNT] = b
	b = NetProtocol.encode_inputs([on] as Array[NetProtocol.InputFrame])
	b[NetProtocol.INPUT_HEADER + 1 + 1 + 2] = Config.HOTBAR_SLOTS
	bad["ARMOR slot %d (outside the hotbar, not 255)" % Config.HOTBAR_SLOTS] = b
	b = NetProtocol.encode_inputs([store] as Array[NetProtocol.InputFrame])
	b[NetProtocol.INPUT_HEADER + 1 + 1 + 2 + 5] = 2
	bad["CHEST move 2"] = b
	b = NetProtocol.encode_inputs([store] as Array[NetProtocol.InputFrame])
	b[NetProtocol.INPUT_HEADER + 1 + 1 + 2 + 6] = Config.INVENTORY_SLOTS
	bad["CHEST store from inventory slot %d" % Config.INVENTORY_SLOTS] = b
	b = NetProtocol.encode_inputs([take] as Array[NetProtocol.InputFrame])
	b[NetProtocol.INPUT_HEADER + 1 + 1 + 2 + 6] = Config.CHEST_SLOTS
	bad["CHEST take chest slot %d" % Config.CHEST_SLOTS] = b
	b = NetProtocol.encode_inputs([door] as Array[NetProtocol.InputFrame])
	b[NetProtocol.INPUT_HEADER + 1 + 1 + 1] = NetProtocol.OP_SIZES.size()
	bad["an op past CHEST"] = b
	for label: String in bad:
		check(not NetProtocol.decode_inputs(bad[label]).ok, "refused: %s" % label)


func _check_inventory_codec_v8() -> void:
	var inv: Inventory = Inventory.new()
	inv.add(&"sword_t1", 1)
	inv.add(&"stone_a", 40)
	inv.add(&"bow_t1", 1)
	inv.add(&"armor_t1", 1)
	inv.stack_at(0).durability = 77
	inv.stack_at(2).durability = 0
	Gear.equip(inv, 3)  # the armour on (the slot is empty again)
	inv.armor.durability = 61
	inv.select(2)
	var bytes: PackedByteArray = NetProtocol.encode_inventory(inv, 12345)
	check_eq(bytes.size(), NetProtocol.INVENTORY_HEADER + 3 * (Config.INVENTORY_SLOTS + 1) + 2 * 3,
		"inventory = 6 + 3 B x (24 slots + armour) + 2 B durability for each of the sword, the bow and the armour")
	var back: NetProtocol.InventoryState = NetProtocol.decode_inventory(bytes)
	check(back.ok and back.ack == 12345 and back.selected == 2, "the inventory decodes")
	if back.ok:
		check(back.stacks[0].id == &"sword_t1" and back.stacks[0].durability == 77 and back.stacks[2].durability == 0
			and back.stacks[1].count == 40 and back.stacks[1].durability == 0, "durability rides with each gear stack (77, 0)")
		check(back.armor != null and back.armor.id == &"armor_t1" and back.armor.durability == 61, "the armour worn and its 61")
		var mine: Inventory = Inventory.new()
		SessionClient.take_inventory(mine, back, back.selected)
		check(mine.describe() == inv.describe() and Gear.describe(mine.armor) == Gear.describe(inv.armor),
			"a client takes it whole (%s | %s)" % [mine.describe(), Gear.describe(mine.armor)])
	var empty: Inventory = Inventory.new()
	check_eq(NetProtocol.encode_inventory(empty, 0).size(), NetProtocol.INVENTORY_HEADER + 3 * (Config.INVENTORY_SLOTS + 1),
		"an empty inventory: no durability bytes")
	var short_ok: int = 0
	for n: int in bytes.size():
		if NetProtocol.decode_inventory(bytes.slice(0, n)).ok:
			short_ok += 1
	check_eq(short_ok, 0, "every truncated inventory is refused")
	var cases: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = bytes.duplicate()
	b.encode_u16(NetProtocol.INVENTORY_HEADER + 3, Gear.max_durability(&"sword_t1") + 1)
	cases["a sword with more than its full durability"] = b
	b = bytes.duplicate()
	b.append(0)
	cases["a byte after the armour slot"] = b
	var stone_armour: Inventory = Inventory.new()
	stone_armour.armor = ItemStack.new(&"stone_a", 3, ItemDB.Grade.NONE)
	cases["stones in the armour slot"] = NetProtocol.encode_inventory(stone_armour, 0)
	for label: String in cases:
		check(not NetProtocol.decode_inventory(cases[label]).ok, "inventory refused: %s" % label)


func _check_chest_edit_codec() -> void:
	var e: EditLog.WorldEdit = EditLog.WorldEdit.chest_slot(Vector2i(62, 44), 15, ItemStack.new(&"sword_t1", 1, 0, 33))
	var bytes: PackedByteArray = EditLog.encode_one(e, 9, Config.MAP_SURFACE)
	check_eq(bytes.size(), 16, "a chest slot edit is 16 B")
	var back: Array = EditLog.decode_one(bytes)
	var be: EditLog.WorldEdit = back[1]
	var idx: int = back[0]
	check(idx == 9 and be != null and be.kind == EditLog.Kind.CHEST and be.cell == Vector2i(62, 44) and be.value == 15
		and be.stack != null and be.stack.id == &"sword_t1" and be.stack.durability == 33, "the chest slot edit round trips")
	var empty_e: Array = EditLog.decode_one(EditLog.encode_one(EditLog.WorldEdit.chest_slot(Vector2i(1, 2), 0, null), 0))
	var ee: EditLog.WorldEdit = empty_e[1]
	var eidx: int = empty_e[0]
	check(eidx == 0 and ee != null and ee.stack == null, "an emptied slot round trips")
	var cases: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = bytes.duplicate()
	b[EditLog.HEADER_SIZE + 5] = Config.CHEST_SLOTS
	cases["slot %d" % Config.CHEST_SLOTS] = b
	b = bytes.duplicate()
	b.encode_u16(EditLog.HEADER_SIZE + 9, 121)
	cases["durability 121 on a sword"] = b
	b = bytes.duplicate()
	b[EditLog.HEADER_SIZE + 7] = 2
	cases["two swords in one slot"] = b
	b = bytes.duplicate()
	b[EditLog.HEADER_SIZE + 6] = ItemDB.count() + 1
	cases["an unknown item"] = b
	b = bytes.duplicate()
	b.append(0)
	cases["one byte too many"] = b
	b = EditLog.encode_one(EditLog.WorldEdit.chest_slot(Vector2i(1, 2), 0, ItemStack.new(&"stone_a", 5, 0)), 0)
	b.encode_u16(EditLog.HEADER_SIZE + 9, 4)
	cases["durability on stones"] = b
	for label: String in cases:
		var got: Array = EditLog.decode_one(cases[label])
		check_eq(got[0], -1, "chest slot edit refused: %s" % label)
	# Where it applies: a chest's top-left tile only.
	var data: WorldData = SurfaceGen.generate(SEED, Config.MAP_SIZE)
	data.put_placeable(Rect2i(62, 44, 3, 1), WorldData.PLACEABLE_CHEST)
	var st: ItemStack = ItemStack.new(&"stone_a", 30, ItemDB.Grade.NONE)
	check(not EditLog.apply_to_data(data, EditLog.WorldEdit.chest_slot(Vector2i(63, 44), 0, st)), "not on the chest's middle tile")
	check(not EditLog.apply_to_data(data, EditLog.WorldEdit.chest_slot(Vector2i(60, 44), 0, st)), "not on a tile with no chest")
	var hash_before: String = data.content_hash()
	check(EditLog.apply_to_data(data, EditLog.WorldEdit.chest_slot(Vector2i(62, 44), 3, st)), "on its top-left tile")
	check(data.chest_at(Vector2i(62, 44)).slots[3] != null and data.chest_at(Vector2i(62, 44)).slots[3].count == 30
		and data.content_hash() != hash_before, "the slot holds 30 stones and the world hash covers it")
	check(EditLog.apply_to_data(data, EditLog.WorldEdit.chest_slot(Vector2i(62, 44), 3, st)), "again: absolute, the same")
	check(EditLog.apply_to_data(data, EditLog.WorldEdit.chest_slot(Vector2i(62, 44), 3, null)) and data.content_hash() == hash_before,
		"emptied: the hash of a world whose chests hold nothing")


func _check_snapshot_chests() -> void:
	var data: WorldData = SurfaceGen.generate(SEED, Config.MAP_SIZE)
	data.put_placeable(Rect2i(62, 44, 3, 1), WorldData.PLACEABLE_CHEST)
	data.put_placeable(Rect2i(66, 44, 3, 1), WorldData.PLACEABLE_CHEST)
	data.put_placeable(Rect2i(60, 52, 3, 1), WorldData.PLACEABLE_CHEST)  # an empty one: not carried
	data.chest_at(Vector2i(62, 44)).slots[0] = ItemStack.new(&"stone_a", 99, ItemDB.Grade.NONE)
	data.chest_at(Vector2i(62, 44)).slots[15] = ItemStack.new(&"armor_t1", 1, ItemDB.Grade.NONE, 17)
	data.chest_at(Vector2i(66, 44)).slots[4] = ItemStack.new(&"wild_healing", 3, ItemDB.Grade.FINE)
	data.chest_at(Vector2i(60, 52))
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(data)
	var cells: int = data.size.x * data.size.y
	check_eq(raw.size(), WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * cells + 2 + 2 + 2 * WorldSnapshot.CHEST_BYTES,
		"the raw snapshot carries the two chests that hold something (%d B each)" % WorldSnapshot.CHEST_BYTES)
	var back: WorldData = WorldSnapshot.decode_raw(raw)
	check(back != null and back.content_hash() == data.content_hash(), "round trip: the same world hash (contents, durability)")
	if back != null:
		check(back.chests.size() == 2 and back.chest_at(Vector2i(62, 44)).slots[15].durability == 17,
			"two chests back, the armour's 17 kept")
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(data)
	var un: WorldData = WorldSnapshot.unpack(packed.bytes, packed.raw_size)
	check(un != null and un.content_hash() == data.content_hash(), "packed and unpacked: the same")
	var at: int = WorldSnapshot.HEADER_SIZE + WorldData.LAYER_COUNT * cells + 2
	var cases: Dictionary[String, PackedByteArray] = {}
	var b: PackedByteArray = raw.duplicate()
	b.encode_u16(at + 2, 63)
	cases["a chest key on the chest's middle tile"] = b
	b = raw.duplicate()
	b.encode_u16(at + 2 + WorldSnapshot.CHEST_BYTES, 62)
	cases["the same chest twice"] = b
	b = raw.duplicate()
	b.encode_u16(at + 2, 40)
	cases["a key with no chest"] = b
	b = raw.duplicate()
	b[at + 2 + 4 + 1] = 100
	cases["100 stones in a slot"] = b
	b = raw.duplicate()
	for i: int in WorldSnapshot.CHEST_BYTES - 4:
		b[at + 2 + WorldSnapshot.CHEST_BYTES + 4 + i] = 0
	cases["an empty chest carried"] = b
	b = raw.duplicate()
	b.encode_u16(at, 3)
	cases["a count beyond the bytes"] = b
	b = raw.slice(0, raw.size() - 1)
	cases["one byte short"] = b
	for label: String in cases:
		check(WorldSnapshot.decode_raw(cases[label]) == null, "snapshot refused: %s" % label)


# --- the host against a malicious client -------------------------------------------------------------------------------

func _check_build_requests() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	var c: Client = await _join_quiet(r, 101, "miner", feet_in(Vector2i(66, 54)))
	var b: Client = await _join_quiet(r, 102, "archer", feet_in(Vector2i(70, 54)))
	var m: NetMember = hm(r, c)
	var mb: NetMember = hm(r, b)
	m.player.inventory.clear()
	give(m, &"stone_wall", 40)
	give(m, &"door", 4)
	var here: Vector2i = Aim.feet_cell(m.player.sim_position)
	var edits: int = r.s.log_for(Config.MAP_SURFACE).size()
	# Out of reach: 2, 3 and 40 tiles off; outside the map.
	for far: Vector2i in [here + Vector2i(0, -2), here + Vector2i(3, 0), here + Vector2i(40, 0), Vector2i(-1, 3)]:
		refill(m)
		run_one(r, m, req(NetProtocol.Op.USE, far, 0))
	check_eq(m.refused(WorldItems.WHY_REACH), 3, "a wall 2, 3 and 40 tiles away: out of reach (the host measures from its player)")
	check_eq(m.refused(WorldItems.WHY_OUTSIDE) + m.refused(WorldItems.WHY_REACH), 4, "and one off the map is refused too")
	# On a spot where players appear: a spawn slot (61,50), the entrance's arrival (73,48).
	for spot: Vector2i in [Vector2i(61, 50), Vector2i(73, 48)]:
		m.player.teleport(feet_in(spot + Vector2i(1, -1)))
		refill(m)
		run_one(r, m, req(NetProtocol.Op.USE, spot, 0))
	check_eq(m.refused(WorldItems.WHY_RESERVED), 2, "a wall on a spawn slot and on the entrance's arrival point: where players appear")
	# On another player, next to one (M7c clearance), clear of it.
	m.player.teleport(feet_in(Vector2i(66, 54)))
	mb.player.teleport(feet_in(Vector2i(67, 56)))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.USE, Vector2i(67, 55), 0))
	check_eq(m.refused(WorldItems.WHY_BODY), 1, "a wall whose face covers the archer's feet: someone stands there")
	mb.player.teleport(feet_in(Vector2i(68, 57)))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.USE, Vector2i(67, 55), 0))
	check_eq(m.refused(Building.WHY_NEAR), 1, "the archer a tile off the face: someone is too close (M7c)")
	mb.player.teleport(feet_in(Vector2i(70, 58)))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.USE, Vector2i(67, 55), 0))
	check_eq(Walls.kind_at(data, Vector2i(67, 55)), Walls.KIND_STONE, "%d px clear of the archer: built" % roundi(Config.BLOCK_CLEARANCE_PX))
	check_eq(m.player.inventory.count_of(&"stone_wall"), 40 - Config.BUILD_COST_OUTSIDE_LIGHT, "for %d outside the light" % (
		Config.BUILD_COST_OUTSIDE_LIGHT))
	check_eq(r.s.log_for(Config.MAP_SURFACE).size(), edits + 1, "one edit only (every refusal changed nothing)")
	# Another map, while down.
	refill(m)
	var wrong: NetProtocol.InputFrame = req(NetProtocol.Op.USE, Vector2i(65, 55), 0)
	wrong.map = Config.MAP_DUNGEON
	run_one(r, m, wrong)
	check_eq(m.refused(WorldItems.WHY_WRONG_MAP), 1, "a wall aimed on the dungeon: wrong map")
	# Spam: ten in one tick: four pay the budget, six are "rate".
	var rate_before: int = m.refused("rate")
	for t: int in Config.NET_OP_BURST * Config.NET_OP_INTERVAL_TICKS:
		m.refill_ops()
	var reach_before: int = m.refused(WorldItems.WHY_REACH)
	for i: int in 10:
		m.player.begin_tick()
		r.host.run_frame(m, req(NetProtocol.Op.USE, here + Vector2i(5, 0), 0))
	check_eq(m.refused("rate") - rate_before, 10 - Config.NET_OP_BURST, "ten builds in one tick: %d rate" % (10 - Config.NET_OP_BURST))
	check_eq(m.refused(WorldItems.WHY_REACH) - reach_before, Config.NET_OP_BURST, "the %d on the budget checked (out of reach)" % (
		Config.NET_OP_BURST))
	# Demolish: a dungeon wall (mined, not taken down), nothing, out of reach, the wall it built.
	var dm: Client = await _join_quiet(r, 103, "cleric", feet_in(Vector2i(70, 50)))
	var md: NetMember = hm(r, dm)
	r.host.move_to_map(md, Config.MAP_DUNGEON)
	var dd: WorldData = r.dungeon.data
	var rock: Vector2i = Vector2i(-1, -1)
	var arrive: Vector2i = Aim.feet_cell(md.player.sim_position)
	for y: int in range(arrive.y - 1, 0, -1):
		if Walls.is_natural(dd, Vector2i(arrive.x - 3, y)):
			rock = Vector2i(arrive.x - 3, y)
			break
	md.player.teleport(feet_in(rock + Vector2i(1, 1)))
	refill(md)
	var dw: NetProtocol.InputFrame = req(NetProtocol.Op.DEMOLISH, rock)
	dw.map = Config.MAP_DUNGEON
	run_one(r, md, dw)
	check_eq(md.refused(Building.WHY_NATURAL), 1, "right-click on a dungeon wall %s: a dungeon wall is mined" % rock)
	check(Walls.is_natural(dd, rock), "the dungeon wall stands")
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DEMOLISH, Aim.feet_cell(m.player.sim_position) + Vector2i(-1, 0)))
	check_eq(m.refused(Building.WHY_NOT_BUILT), 1, "right-click on bare grass: nothing built there")
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DEMOLISH, Vector2i(67, 55) + Vector2i(3, 0)))
	check(m.refused(WorldItems.WHY_REACH) >= 4, "right-click 3 tiles off: out of reach")
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DEMOLISH, Vector2i(67, 55)))
	check(Walls.kind_at(data, Vector2i(67, 55)) == Walls.KIND_NONE and m.player.inventory.count_of(&"stone_wall") >= 39,
		"its own wall taken down, one piece back")
	# Doors: out of reach, closing on someone near (M7c), closing with them farther.
	refill(m)
	m.player.teleport(feet_in(Vector2i(66, 54)))
	run_one(r, m, req(NetProtocol.Op.USE, Vector2i(67, 53), slot_of(m.player.inventory, &"door")))
	check(Walls.is_door(data, Vector2i(67, 53)), "a door built at (67,53) (refusals %s)" % m.ops_refused)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DOOR, Vector2i(67, 53)))
	check(Walls.is_open_door(data, Vector2i(67, 53)), "F opened it")
	mb.player.teleport(feet_in(Vector2i(67, 55)))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DOOR, Vector2i(67, 53)))
	check(m.refused(Building.WHY_NEAR) == 2 and Walls.is_open_door(data, Vector2i(67, 53)),
		"the archer a tile below the doorway: closing refused, someone is too close (M7c)")
	mb.player.teleport(feet_in(Vector2i(67, 54)))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DOOR, Vector2i(67, 53)))
	check(m.refused(Building.WHY_DOORWAY) == 1 and Walls.is_open_door(data, Vector2i(67, 53)), "in the doorway: someone stands in the doorway")
	mb.player.teleport(feet_in(Vector2i(70, 58)))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DOOR, Vector2i(67, 53)))
	check(Walls.is_door(data, Vector2i(67, 53)) and not Walls.is_open_door(data, Vector2i(67, 53)), "farther away: it closes")
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DOOR, Vector2i(67, 53) + Vector2i(0, -3)))
	check(m.refused(WorldItems.WHY_REACH) >= 5, "F on a door 3 tiles off: out of reach")
	# Carrying the altar: a right-click is refused (offline Main.demolish refuses it too).
	refill(m)
	run_one(r, m, req(NetProtocol.Op.USE, Vector2i(65, 55), 0))
	m.player.set_carrying_altar(true)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.DEMOLISH, Vector2i(65, 55)))
	check(m.refused(AltarMove.WHY_CARRYING) == 1, "carrying the altar: right-click refused, carrying the altar (%s)" % m.ops_refused)
	m.player.set_carrying_altar(false)
	# While down: a build, a door, a right-click are "down".
	m.player.take_hit(Config.PLAYER_HP_MAX)
	var down_before: int = m.refused(SessionHost.WHY_DOWN)
	for op: int in [NetProtocol.Op.USE, NetProtocol.Op.DOOR, NetProtocol.Op.DEMOLISH]:
		refill(m)
		run_one(r, m, req(op, Vector2i(67, 53), 0))
	check_eq(m.refused(SessionHost.WHY_DOWN) - down_before, 3, "down: build, door and right-click refused")
	_tick(r, 3)
	check(worlds_agree(r), "every client's world = the host's")
	_free_rig(r)


func _check_gear_requests() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var c: Client = await _join_quiet(r, 101, "miner", feet_in(Vector2i(63, 52)))
	var m: NetMember = hm(r, c)
	m.player.inventory.clear()
	# Armour it does not have: an empty slot, a slot of stones, none worn to take off.
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, 0))
	give(m, &"stone_a", 5)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, 0))
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, NetProtocol.ARMOR_OFF))
	check(m.refused(Gear.WHY_EMPTY) == 1 and m.refused(Gear.WHY_NOT_ARMOR) == 1 and m.refused(Gear.WHY_NO_ARMOR) == 1,
		"armour from an empty slot, stones as armour, taking off none: refused (%s)" % m.ops_refused)
	check(m.player.inventory.armor == null, "nothing worn")
	# Put on, take off with a full inventory (refused), with room.
	give(m, &"armor_t1", 1)
	var slot: int = slot_of(m.player.inventory, &"armor_t1")
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, slot))
	check(m.player.inventory.armor != null and m.player.inventory.armor.id == &"armor_t1", "the armour on")
	for i: int in m.player.inventory.size():
		if m.player.inventory.stack_at(i) == null:
			m.player.inventory.slots[i] = ItemStack.new(&"stone_b", 1, ItemDB.Grade.NONE)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, NetProtocol.ARMOR_OFF))
	check(m.refused(Gear.WHY_FULL) == 1 and m.player.inventory.armor != null, "taking it off into a full inventory: refused")
	m.player.inventory.remove(5, 1)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, NetProtocol.ARMOR_OFF))
	check(m.player.inventory.armor == null and m.player.inventory.count_of(&"armor_t1") == 1, "with room: off, in slot 5")
	# Spam: ten ARMOR in one tick, four on the budget.
	var rate_before: int = m.refused("rate")
	for t: int in Config.NET_OP_BURST * Config.NET_OP_INTERVAL_TICKS:
		m.refill_ops()
	for i: int in 10:
		m.player.begin_tick()
		r.host.run_frame(m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, 5 if i % 2 == 0 else NetProtocol.ARMOR_OFF))
	check_eq(m.refused("rate") - rate_before, 10 - Config.NET_OP_BURST, "ten ARMOR in one tick: %d rate" % (10 - Config.NET_OP_BURST))
	# Down: taking it off works, putting it on is refused (offline the click puts it on only when free).
	if m.player.inventory.armor == null:
		refill(m)
		run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, slot_of(m.player.inventory, &"armor_t1")))
	m.player.take_hit(Config.PLAYER_HP_MAX)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, NetProtocol.ARMOR_OFF))
	var down_before: int = m.refused(SessionHost.WHY_DOWN)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.ARMOR, Vector2i.ZERO, slot_of(m.player.inventory, &"armor_t1")))
	check(m.player.inventory.armor == null and m.refused(SessionHost.WHY_DOWN) == down_before + 1,
		"down: taking it off works, putting it on is refused (down)")
	m.player.revive_now()
	# Repairs at an anvil the host placed: nothing worn, no material, then done.
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(62, 51), WorldData.PLACEABLE_ANVIL))
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(63, 51), WorldData.PLACEABLE_ANVIL))
	m.player.inventory.clear()
	give(m, &"sword_t1", 1)
	give(m, &"ingot_iron", 1)
	m.player.inventory.remove(slot_of(m.player.inventory, &"ingot_iron"), 1)  # seen, not held
	refill(m)
	run_one(r, m, _craft(Config.MAP_SURFACE, &"repair_sword_t1"))
	check_eq(m.refused(Crafting.WHY_MISSING), 1, "a repair with no iron ingot: missing inputs")
	give(m, &"ingot_iron", 1)
	refill(m)
	run_one(r, m, _craft(Config.MAP_SURFACE, &"repair_sword_t1"))
	check(m.refused(Crafting.WHY_NOTHING_TO_REPAIR) == 1 and m.player.inventory.count_of(&"ingot_iron") == 1,
		"a repair with nothing worn: nothing to repair, the ingot kept")
	m.player.inventory.stack_at(slot_of(m.player.inventory, &"sword_t1")).durability = 40
	m.player.teleport(feet_in(Vector2i(63, 56)))
	refill(m)
	run_one(r, m, _craft(Config.MAP_SURFACE, &"repair_sword_t1"))
	check_eq(m.refused(Crafting.WHY_NO_STATION), 1, "a repair 5 tiles from the anvil: no station")
	m.player.teleport(feet_in(Vector2i(63, 52)))
	refill(m)
	run_one(r, m, _craft(Config.MAP_SURFACE, &"repair_sword_t1"))
	check(m.player.inventory.stack_at(slot_of(m.player.inventory, &"sword_t1")).durability == 120
		and m.player.inventory.count_of(&"ingot_iron") == 0, "at the anvil: repaired to 120 for the ingot")
	# A hand recipe needs no station (the axe from two stones, anywhere).
	give(m, &"stone_a", 2)
	m.player.teleport(feet_in(Vector2i(70, 60)))
	refill(m)
	run_one(r, m, _craft(Config.MAP_SURFACE, &"axe"))
	check_eq(m.player.inventory.count_of(&"axe"), 1, "the axe by hand, far from any station")
	_free_rig(r)


func _check_chest_requests() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	var c: Client = await _join_quiet(r, 101, "miner", feet_in(CHEST_FEET))
	var m: NetMember = hm(r, c)
	m.player.inventory.clear()
	give(m, &"storage_chest", 1)
	refill(m)
	run_one(r, m, req(NetProtocol.Op.USE, CHEST_AT, 0))
	var key: Vector2i = CHEST_AT + Vector2i(-1, 0)
	check(data.get_value(WorldData.Layer.PLACEABLE, CHEST_AT) == WorldData.PLACEABLE_CHEST and data.footprint_at(CHEST_AT).position == key,
		"the host placed the client's chest in the light (refusals %s)" % m.ops_refused)
	give(m, &"stone_a", 99)
	give(m, &"stone_a", 50)
	var stones: int = m.player.inventory.count_of(&"stone_a")
	# A tile with no chest; an empty slot; from too far.
	refill(m)
	run_one(r, m, chest_req(CHEST_AT + Vector2i(0, -1), false, 0))
	check_eq(m.refused(Storage.WHY_NO_CHEST), 1, "a CHEST request on a tile with no chest: no chest there")
	refill(m)
	run_one(r, m, chest_req(CHEST_AT, true, 0))
	check_eq(m.refused(Storage.WHY_EMPTY), 1, "taking an empty chest slot: empty slot")
	refill(m)
	run_one(r, m, chest_req(CHEST_AT, false, slot_of(m.player.inventory, &"stone_a")))
	check(data.chest_at(key).slots[0] != null and data.chest_at(key).slots[0].count == 99, "stored 99 stones")
	m.player.teleport(feet_in(CHEST_FEET + Vector2i(0, -2)))
	refill(m)
	run_one(r, m, chest_req(CHEST_AT, true, 0))
	check(m.refused(Storage.WHY_REACH) == 1 and data.chest_at(key).slots[0].count == 99,
		"taking from 3 tiles off the chest (%d is the reach): out of reach, the chest unchanged" % Config.STATION_REACH_TILES)
	m.player.teleport(feet_in(CHEST_FEET))
	# Another map, while down; a full chest.
	refill(m)
	var wrong: NetProtocol.InputFrame = chest_req(CHEST_AT, true, 0)
	wrong.map = Config.MAP_DUNGEON
	run_one(r, m, wrong)
	check_eq(m.refused(WorldItems.WHY_WRONG_MAP), 1, "a CHEST request naming the dungeon: wrong map")
	for i: int in Config.CHEST_SLOTS:
		data.chest_at(key).slots[i] = ItemStack.new(&"stone_b", 99, ItemDB.Grade.NONE)
	refill(m)
	run_one(r, m, chest_req(CHEST_AT, false, slot_of(m.player.inventory, &"stone_a")))
	check_eq(m.refused(Storage.WHY_CHEST_FULL), 1, "storing into a full chest: chest full")
	check_eq(m.player.inventory.count_of(&"stone_a") + 99, stones, "the stones the full chest refused stayed in the inventory")
	# Spam.
	var rate_before: int = m.refused("rate")
	for t: int in Config.NET_OP_BURST * Config.NET_OP_INTERVAL_TICKS:
		m.refill_ops()
	for i: int in 10:
		m.player.begin_tick()
		r.host.run_frame(m, chest_req(CHEST_AT, true, i % Config.CHEST_SLOTS))
	check_eq(m.refused("rate") - rate_before, 10 - Config.NET_OP_BURST, "ten CHEST in one tick: %d rate" % (10 - Config.NET_OP_BURST))
	_free_rig(r)


func _check_chop_requests() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, TREE), WorldData.PLACEABLE_TREE, "seed 1 has a tree at (83,52)")
	var c: Client = await _join_quiet(r, 101, "herbalist", feet_in(TREE_FEET))
	var m: NetMember = hm(r, c)
	m.player.inventory.clear()
	give(m, &"pickaxe", 1)
	give(m, &"axe", 1)
	# Without an axe: the pickaxe swings at the trunk (an attack swing: no wall), nothing is chopped.
	run_one(r, m, req(NetProtocol.Op.USE, TREE, 0))
	run_empty(r, m, PlayerSim.action_ticks(RigData.Anim.PICKAXE))
	var chops: int = m.ops_done.get("chop", 0)
	check(data.get_value(WorldData.Layer.PLACEABLE, TREE) == WorldData.PLACEABLE_TREE and r.host.forest_of(0).hits.size() == 0
		and chops == 0, "a pickaxe swing at the tree chops nothing")
	# Out of reach: the axe's use 3 tiles off is refused; aimed beside the tree it swings at nothing.
	run_one(r, m, req(NetProtocol.Op.USE, TREE + Vector2i(3, 0), 1))
	check_eq(m.refused(WorldItems.WHY_REACH), 1, "an axe use 3 tiles off: out of reach")
	run_one(r, m, req(NetProtocol.Op.USE, TREE_FEET + Vector2i(1, 0), 1))
	run_empty(r, m, PlayerSim.action_ticks(RigData.Anim.AXE))
	check_eq(missed(m, Forest.WHY_NO_TREE), 1, "an axe swing at the grass beside it: no tree there")
	# Spam: an axe USE on every frame of one swing starts one swing; the tree takes one hit.
	var busy_before: int = m.refused("busy")
	var ticks: int = PlayerSim.action_ticks(RigData.Anim.AXE)
	for i: int in ticks:
		run_one(r, m, req(NetProtocol.Op.USE, TREE, 1))
	check_eq(m.refused("busy") - busy_before, ticks - 1, "%d axe uses in one swing: %d busy" % [ticks, ticks - 1])
	check_eq(r.host.forest_of(0).hits.get(TREE, 0), 1, "the tree took one hit")
	check(c.surface.data.get_value(WorldData.Layer.PLACEABLE, TREE) == WorldData.PLACEABLE_TREE, "the client still sees the tree")
	_free_rig(r)


# --- flows ---------------------------------------------------------------------------------------------------------------

## Two players build the room (the host most walls by clicks, the client two through the wire), the host puts the door in
## from inside, opens it and walks out; both walk in through the door. Then the door does not close on the client near it,
## closes on it farther away, and the client walks into the closed door exactly as the host has it. A heretic outside the
## closed room never gets in or hurts anyone. With a 3-tick one-way delay.
func _check_room_flow() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 3
	await await_frames(1)
	var data: WorldData = r.surface.data
	var hp: Player = r.s.local.player
	hp.inventory.clear()
	give(r.s.local, &"stone_wall", 60)
	give(r.s.local, &"door", 2)
	var c: Client = _join(r, 101, "miner", feet_in(Vector2i(66, 65)), false)
	var m: NetMember = hm(r, c)
	m.player.inventory.clear()
	give(m, &"stone_wall", 10)
	_tick(r, 2 * r.delay + 2)
	var cinv: Inventory = c.s.local.player.inventory
	check_eq(cinv.count_of(&"stone_wall"), 10, "the client holds its walls (the host's inventory)")
	# The client's two walls: walk, aim, click (the frame's USE goes to the host).
	var wall_slot: int = slot_of(cinv, &"stone_wall") + 1
	# The east one first from below-right, then around (row 63) to below-left of the other: a wall's face blocks the row.
	var pause: int = 2 * r.delay + 4
	var script: String = ("select:%d;walkto:%d,%d;aimat:%d,%d;use:1;wait:%d;walkto:66,63;walkto:63,63;walkto:%d,%d;" +
		"aimat:%d,%d;use:1;wait:%d;walkto:63,63;walkto:68,66") % [wall_slot, CLIENT_STANDS[1].x, CLIENT_STANDS[1].y,
		CLIENT_WALLS[1].x, CLIENT_WALLS[1].y, pause, CLIENT_STANDS[0].x, CLIENT_STANDS[0].y, CLIENT_WALLS[0].x, CLIENT_WALLS[0].y, pause]
	bot_run(r, c, script, 1200)
	for w: Vector2i in CLIENT_WALLS:
		check_eq(Walls.kind_at(data, w), Walls.KIND_STONE, "the client's wall at %s stands on the host" % w)
	check_eq(m.ops_done.get("build", 0), 2, "two builds by the client")
	# The host builds the rest from outside, the door from inside.
	var host_built: int = 0
	for w2: Vector2i in room_walls():
		if Walls.is_wall(data, w2):
			continue
		if host_builds(r, Building.STONE_WALL, w2):
			host_built += 1
	check_eq(host_built, room_walls().size() - CLIENT_WALLS.size(), "the host built the other %d walls" % (
		room_walls().size() - CLIENT_WALLS.size()))
	hp.teleport(feet_in(INSIDE_DOOR))
	press(r, _select(slot_of(hp.inventory, &"door")))
	press(r, click_at(centre_of(DOOR_CELL)))
	check(Walls.is_door(data, DOOR_CELL) and not Walls.is_open_door(data, DOOR_CELL), "the host put the door in from inside")
	_tick(r, 2 * r.delay + 2)
	check(worlds_agree(r), "the client's world = the host's: the room with its door")
	check_eq(c.surface.builds.verify().get("mismatches", -1), 0, "the client draws the room = its data")
	# The host opens it, walks out; both walk in through the doorway.
	press(r, f_at(DOOR_CELL))
	check(Walls.is_open_door(data, DOOR_CELL), "F from inside opened it (a DOOR request)")
	host_run(r, "walkto:61,63;walkto:63,64")
	check_eq(Aim.feet_cell(hp.sim_position), Vector2i(63, 64), "the host walked out through the doorway")
	_tick(r, 2 * r.delay + 2)
	bot_run(r, c, "walkto:%d,%d;walkto:%d,%d;walkto:%d,%d" % [OUTSIDE_NEAR.x, OUTSIDE_NEAR.y, INSIDE_DOOR.x, INSIDE_DOOR.y,
		INSIDE_FAR.x, INSIDE_FAR.y], 900)
	host_run(r, "walkto:61,63;walkto:61,60;walkto:62,60")
	_tick(r, 2 * r.delay + 4)
	check(Aim.feet_cell(m.player.sim_position) == INSIDE_FAR and Aim.feet_cell(c.s.local.player.sim_position) == INSIDE_FAR,
		"the client walked in through the door (host %s, predicted %s)" % [Aim.feet_cell(m.player.sim_position),
		Aim.feet_cell(c.s.local.player.sim_position)])
	check_eq(Aim.feet_cell(hp.sim_position), Vector2i(62, 60), "the host walked in too")
	check_prediction("room: walking in", c)
	# The door does not close on the client near it; it closes once the client is farther; the client walks into it.
	bot_run(r, c, "walkto:%d,%d;walkto:%d,%d;walkto:%d,%d" % [INSIDE_DOOR.x, INSIDE_DOOR.y, OUTSIDE_NEAR.x, OUTSIDE_NEAR.y,
		OUTSIDE_NEAR.x, OUTSIDE_NEAR.y], 600)
	press(r, f_at(DOOR_CELL))
	check(Walls.is_open_door(data, DOOR_CELL) and r.s.local.refused(Building.WHY_NEAR) == 1,
		"the client right below the doorway: the door does not close (someone is too close)")
	bot_run(r, c, "walkto:%d,%d" % [OUTSIDE_FAR.x, OUTSIDE_FAR.y], 300)
	_tick(r, 2 * r.delay + 2)
	press(r, f_at(DOOR_CELL))
	check(Walls.is_door(data, DOOR_CELL) and not Walls.is_open_door(data, DOOR_CELL), "the client farther away: it closes")
	var corrections_before: int = c.s.client.prediction.corrections
	bot_run(r, c, "walkto:%d,%d,150" % [INSIDE_DOOR.x, INSIDE_DOOR.y], 160)
	_tick(r, 2 * r.delay + 4)
	var blocked_at: Vector2 = m.player.sim_position
	var edge: float = (DOOR_CELL.y + 2) * Config.TILE + Config.FEET_HEIGHT
	check(blocked_at.y >= edge - 0.01 and blocked_at.y <= edge + Config.WALK_SPEED / Config.NET_TICK_RATE + 0.01,
		"the client walked into the closed door: stopped at its face's lower edge (feet y %.2f, edge %.0f)" % [blocked_at.y, edge])
	check(c.s.local.player.sim_position == blocked_at, "its prediction stopped exactly there too (%s / host %s)" % [
		c.s.local.player.sim_position, blocked_at])
	check_eq(c.s.client.prediction.corrections - corrections_before, 0, "not pulled back: no correction (the rule, README \"M7c 예측\")")
	check_prediction("room: the door closed on it", c)
	# The host opens (the client waits for the edit: README "M7c 예측", a door opening on someone pushing at it is the other
	# check), the client comes in to the far corner, the host closes again; a heretic outside never gets in.
	press(r, f_at(DOOR_CELL))
	_tick(r, 2 * r.delay + 2)
	bot_run(r, c, "walkto:%d,%d;walkto:%d,%d" % [INSIDE_DOOR.x, INSIDE_DOOR.y, INSIDE_FAR.x, INSIDE_FAR.y], 400)
	_tick(r, 2 * r.delay + 2)
	press(r, f_at(DOOR_CELL))
	check(Walls.is_door(data, DOOR_CELL) and not Walls.is_open_door(data, DOOR_CELL), "both inside, the door closed")
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(feet_in(Vector2i(70, 63)))
	var hurt_before: int = r.s.local.combat_count("hurt") + m.combat_count("hurt")
	var inside: Rect2 = Rect2(Vector2(ROOM_LEFT + 1, ROOM_TOP + 1) * Config.TILE, Vector2(ROOM_RIGHT - ROOM_LEFT - 1,
		ROOM_BOTTOM - ROOM_TOP - 1) * Config.TILE)
	var got_in: bool = false
	var nearest: float = INF
	for t: int in 600:
		_tick(r)
		if inside.has_point(h.pos):
			got_in = true
		nearest = minf(nearest, h.pos.distance_to(m.player.sim_position))
	check(not got_in and h.alive(), "the heretic outside the closed room never got in (closest %.0f px to the client)" % nearest)
	check_eq(r.s.local.combat_count("hurt") + m.combat_count("hurt") - hurt_before, 0, "nobody inside was hurt in 600 ticks")
	var last: NetProtocol.EnemyBatch = c.batches.back() if not c.batches.is_empty() else null
	check(last != null and last.enemies.size() == 1 and not inside.has_point(last.enemies[0].pos),
		"the client's last enemy batch has the heretic, outside the room")
	check(worlds_agree(r), "worlds agree at the end")
	check_prediction("room: the heretic outside", c)
	_free_rig(r)


## A client pushing north against the closed door when the host opens it (one-way delay 3 ticks): the host lets the frames
## it gets after the opening through while the client's prediction had them blocked until the edit came, so the next states
## pull the client forward once: at most the walk of a round trip plus the input buffering (README "M7c 예측": no rule
## keeps a door shut for someone at it; a door never closes on anyone near, that one is the rule). Measured here.
func _check_door_opens_on_pusher() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 3
	await await_frames(1)
	put_room(r, false)
	r.s.local.player.teleport(feet_in(INSIDE_DOOR))
	var c: Client = _join(r, 101, "miner", feet_in(OUTSIDE_FAR), false)
	_tick(r, 2 * r.delay + 2)
	var push: NetBot.Action = NetBot.Action.new()
	push.dir = Vector2i(0, -1)
	c.action = push
	_tick(r, 80)
	var p: Prediction = c.s.client.prediction
	var corr: int = p.corrections
	var at_door: Vector2 = hm(r, c).player.sim_position
	r.action = f_at(DOOR_CELL)
	_tick(r)
	r.action = null
	_tick(r, 40)
	c.action = null
	_tick(r, 2 * r.delay + 4)
	var bound: float = Config.WALK_SPEED / Config.NET_TICK_RATE * (2 * r.delay + 3) + 0.01
	note("a door opening on a client pushing at it (one-way %d ticks): %d corrections, largest error so far %.2f px (bound %.1f)" % [
		r.delay, p.corrections - corr, p.max_error_px, bound])
	check(at_door.y < (DOOR_CELL.y + 3) * Config.TILE and hm(r, c).player.sim_position.y < (DOOR_CELL.y) * Config.TILE + 4.0,
		"it pushed at the door, then walked through once it opened (%s -> %s)" % [at_door, hm(r, c).player.sim_position])
	check(p.corrections - corr <= 2 and p.max_error_px <= bound,
		"pulled forward at most twice and at most %.1f px (%d, %.2f px)" % [bound, p.corrections - corr, p.max_error_px])
	check_eq(c.s.local.player.sim_position, hm(r, c).player.sim_position, "and then where the host has it")
	_free_rig(r)


## A chest the host placed with 99 stones in slot 0: two clients take slot 0 in the same tick (the lower slot gets it all
## but what does not fit, the other the rest: nothing doubles, nothing is lost); both store and take through the panel's
## requests; a late joiner gets the chest's contents in its snapshot.
func _check_chest_flow() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	var hp: Player = r.s.local.player
	hp.inventory.clear()
	give(r.s.local, &"storage_chest", 1)
	hp.inventory.select(slot_of(hp.inventory, &"storage_chest"))
	hp.teleport(feet_in(CHEST_FEET))
	press(r, click_at(centre_of(CHEST_AT)))
	var key: Vector2i = data.footprint_at(CHEST_AT).position
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, CHEST_AT), WorldData.PLACEABLE_CHEST, "the host placed the chest")
	hp.teleport(feet_in(Vector2i(58, 47)))
	var a: Client = _join(r, 101, "miner", feet_in(CHEST_FEET + Vector2i(-2, 0)), false)
	var b: Client = _join(r, 102, "archer", feet_in(CHEST_FEET + Vector2i(2, 0)), false)
	var ma: NetMember = hm(r, a)
	var mb: NetMember = hm(r, b)
	check(ma.slot < mb.slot, "the miner has the lower slot (%d, %d)" % [ma.slot, mb.slot])
	ma.player.inventory.clear()
	mb.player.inventory.clear()
	for i: int in Config.INVENTORY_SLOTS - 1:
		ma.player.inventory.slots[i] = ItemStack.new(&"stone_b", 99, ItemDB.Grade.NONE)  # one free slot only
	ma.player.inventory.add(&"stone_a", 69)  # the free slot holds 69: room for 30 more
	ma.inventory_dirty = true
	mb.inventory_dirty = true
	r.host.apply_world_edit(EditLog.WorldEdit.chest_slot(key, 0, ItemStack.new(&"stone_a", 99, ItemDB.Grade.NONE)))
	_tick(r, 3)
	check(a.surface.data.chest_at(key).slots[0] != null and b.surface.data.chest_at(key).slots[0].count == 99,
		"both clients see 99 stones in the chest (a chest slot edit)")
	var total_before: int = data.chest_at(key).slots[0].count + ma.player.inventory.count_of(&"stone_a") \
		+ mb.player.inventory.count_of(&"stone_a")
	# Same tick: both take slot 0 (the archer's packet reaches the host first: the host still runs slot order).
	b.action = chest_click(key, true, 0)
	a.action = chest_click(key, true, 0)
	r.clients.reverse()
	_tick(r)
	r.clients.reverse()
	a.action = null
	b.action = null
	_tick(r, 3)
	var left: ItemStack = data.chest_at(key).slots[0]
	check_eq(ma.player.inventory.count_of(&"stone_a"), 99, "the miner (lower slot) took what fitted: 30 more (69 -> 99)")
	check_eq(mb.player.inventory.count_of(&"stone_a"), 69, "the archer took the 69 left in the same tick")
	check(left == null, "the chest slot is empty")
	var total_after: int = (left.count if left != null else 0) + ma.player.inventory.count_of(&"stone_a") \
		+ mb.player.inventory.count_of(&"stone_a")
	check_eq(total_after, total_before, "nothing doubled, nothing lost (%d stones)" % total_before)
	check(a.s.local.player.inventory.describe() == ma.player.inventory.describe()
		and b.s.local.player.inventory.describe() == mb.player.inventory.describe(), "each client's inventory = the host's copy")
	check(worlds_agree(r), "both clients' chests = the host's")
	# Same tick, one stack, both have room: one gets it, the other is refused (empty slot).
	r.host.apply_world_edit(EditLog.WorldEdit.chest_slot(key, 5, ItemStack.new(&"ingot_iron", 7, ItemDB.Grade.NONE)))
	_tick(r, 3)
	a.action = chest_click(key, true, 5)
	b.action = chest_click(key, true, 5)
	ma.player.inventory.remove(0, 99)
	_tick(r)
	a.action = null
	b.action = null
	_tick(r, 3)
	check(ma.player.inventory.count_of(&"ingot_iron") == 7 and mb.player.inventory.count_of(&"ingot_iron") == 0
		and mb.refused(Storage.WHY_EMPTY) == 1, "seven ingots: the lower slot took them, the other found the slot empty")
	# Stores through the wire: the archer stores its stones, the miner a worn tier-1 sword (its durability goes in).
	ma.player.inventory.remove(1, 99)  # room for the sword
	ma.player.inventory.add(&"sword_t1", 1)
	var sword: int = slot_of(ma.player.inventory, &"sword_t1")
	ma.player.inventory.stack_at(sword).durability = 55
	ma.inventory_dirty = true
	_tick(r, 3)
	press(r, null, a, chest_click(key, false, sword))
	press(r, null, b, chest_click(key, false, slot_of(b.s.local.player.inventory, &"stone_a")))
	_tick(r, 4)
	var held: String = data.chests[key].describe()
	check(held.contains("sword_t1 x1 [55/120]") and held.contains("stone_a x69"), "the chest holds the worn sword and the stones (%s)" % held)
	check(worlds_agree(r), "the clients' chests = the host's (%s)" % _chest_text(a.surface.data, key))
	# A late joiner: the chest's contents in its snapshot.
	var late: Client = _join(r, 103, "cleric", feet_in(Vector2i(58, 50)), false)
	check(late.s.active and late.surface.data.content_hash() == data.content_hash(), "the late joiner has the host's world")
	check_eq(_chest_text(late.surface.data, key), held, "with the chest's contents")
	_free_rig(r)


## A client crafts a tier-1 sword at the anvil the host placed (a CRAFT of the chain), puts armour on (ARMOR), fights a
## heretic (the sword wears per attack, the armour per knife) and dies (the death wear): at every inventory the host sends
## its durability is the host's.
func _check_gear_flow() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var data: WorldData = r.surface.data
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(62, 51), WorldData.PLACEABLE_ANVIL))
	r.host.apply_world_edit(EditLog.WorldEdit.new(WorldData.Layer.PLACEABLE, Vector2i(63, 51), WorldData.PLACEABLE_ANVIL))
	var c: Client = _join(r, 101, "paladin", feet_in(Vector2i(63, 52)), false)
	var m: NetMember = hm(r, c)
	m.player.inventory.clear()
	give(m, &"ingot_iron", 5)
	give(m, &"planks", 2)
	give(m, &"armor_t1", 1)
	_tick(r, 3)
	var cinv: Inventory = c.s.local.player.inventory
	var craft: NetBot.Action = NetBot.Action.new()
	craft.op = Main.craft_request(Crafting.index_of(&"sword_t1"))
	press(r, null, c, craft)
	_tick(r, 3)
	check_eq(cinv.count_of(&"sword_t1"), 1, "the client crafted a tier-1 sword at the host's anvil (a CRAFT)")
	var sword_slot: int = slot_of(cinv, &"sword_t1")
	check_eq(cinv.stack_at(sword_slot).durability, 120, "new: full durability")
	var on: NetBot.Action = NetBot.Action.new()
	on.op = Main.request(NetProtocol.Op.ARMOR, slot_of(cinv, &"armor_t1"))
	press(r, null, c, on)
	_tick(r, 3)
	check(cinv.armor != null and cinv.armor.id == &"armor_t1" and m.player.inventory.armor != null, "the armour on (ARMOR), on both")
	# Fight a heretic outside the light: attacks wear the sword, knives the armour.
	press(r, null, c, _select(sword_slot))
	var f: Vector2 = spot(r)
	var h: HereticSim = r.host.arenas[Config.MAP_SURFACE].spawn_heretic(f)
	var walk: int = bot_run(r, c, "walkto:%d,%d" % [Aim.feet_cell(f).x, Aim.feet_cell(f).y - 2], 400)
	check(walk < 400, "the client walked to the heretic")
	var mism: int = 0
	var inventories: int = c.s.client.inventories
	var ticks: int = 0
	while h.alive() and ticks < 900:
		c.action = swing_at(_drawn_foe(r, c, h.id, h.pos))
		_tick(r)
		ticks += 1
		if c.s.client.inventories != inventories:
			inventories = c.s.client.inventories
			if Gear.describe(cinv.stack_at(sword_slot)) != Gear.describe(m.player.inventory.stack_at(sword_slot)) \
					and r.delay == 0:
				mism += 1
	c.action = null
	_tick(r, 4)
	var attacks: int = m.combat_count("attacks")
	var hurt: int = m.combat_count("hurt")
	check(not h.alive() and attacks > 0, "the heretic died (%d attacks)" % attacks)
	check_eq(m.player.inventory.stack_at(sword_slot).durability, 120 - attacks, "the host's sword wore one per attack")
	check_eq(cinv.stack_at(sword_slot).durability, 120 - attacks, "and the client's inventory says the same")
	check_eq(m.player.inventory.armor.durability, 100 - hurt, "the armour wore one per knife (%d)" % hurt)
	check_eq(cinv.armor.durability, 100 - hurt, "and the client's says the same")
	check_eq(mism, 0, "every inventory the client got carried the host's durability")
	# Death on the client's machine: down, give up (F held), the bag, the death wear.
	m.player.take_hit(Config.PLAYER_HP_MAX)
	c.action = holding_f()
	var t2: int = 0
	while m.player.vitals.life != Vitals.Life.DEAD and t2 < 200:
		_tick(r)
		t2 += 1
	c.action = null
	_tick(r, 4)
	var sword_after: int = 120 - attacks - Gear.death_wear_points(&"sword_t1")
	check_eq(m.player.vitals.life, Vitals.Life.DEAD, "the client gave up: dead")
	check_eq(m.player.inventory.stack_at(sword_slot).durability, sword_after, "the death wore the sword by %d on the host" % (
		Gear.death_wear_points(&"sword_t1")))
	check_eq(cinv.stack_at(sword_slot).durability, sword_after, "the client's inventory holds the host's %d" % sword_after)
	check_eq(cinv.armor.durability, 100 - hurt - Gear.death_wear_points(&"armor_t1"), "the armour too")
	check(data.get_value(WorldData.Layer.PLACEABLE, Aim.feet_cell(m.player.sim_position)) == WorldData.PLACEABLE_BAG
		or not data.drops.is_empty(), "a bag fell with part of the materials")
	_free_rig(r)


## A client chops a tree to a stump (five swings, predicted like any action, the stump an edit both see); the host and a
## late joiner see the stump; the logs are in the client's inventory; the stump grows back on the host's forest and the
## client sees that edit too.
func _check_chop_flow() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 2
	await await_frames(1)
	var data: WorldData = r.surface.data
	var c: Client = _join(r, 101, "herbalist", feet_in(TREE_FEET), false)
	var m: NetMember = hm(r, c)
	m.player.inventory.clear()
	give(m, &"axe", 1)
	_tick(r, 2 * r.delay + 2)
	var cinv: Inventory = c.s.local.player.inventory
	press(r, null, c, _select(slot_of(cinv, &"axe")))
	var swing: NetBot.Action = NetBot.Action.new()
	swing.mouse = centre_of(TREE)
	swing.aiming = true
	swing.use_held = true
	c.action = swing
	var ticks: int = tick_until(r, func() -> bool: return data.get_value(WorldData.Layer.PLACEABLE, TREE) == WorldData.PLACEABLE_STUMP,
		Config.TREE_CHOP_HITS * PlayerSim.action_ticks(RigData.Anim.AXE) + 60)
	c.action = null
	_tick(r, PlayerSim.action_ticks(RigData.Anim.AXE) + 2 * r.delay + 4)
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, TREE), WorldData.PLACEABLE_STUMP, "the client's axe felled the tree on the host (%d ticks)" % ticks)
	check_eq(c.surface.data.get_value(WorldData.Layer.PLACEABLE, TREE), WorldData.PLACEABLE_STUMP, "the client sees the stump")
	check_eq(m.ops_done.get("chop", 0), Config.TREE_CHOP_HITS, "five chops")
	check_eq(cinv.count_of(&"log"), Config.TREE_LOGS, "the logs reached the client's inventory")
	var axes: int = m.actions_seen.get("axe", 0)
	check(axes >= Config.TREE_CHOP_HITS, "the host played the axe swings")
	check_eq(c.s.client.prediction.action_corrections, 0, "the client predicted every swing (no action correction)")
	check_prediction("chop", c)
	check_eq(c.surface.fixtures.verify().get("mismatches", -1), 0, "the client draws the stump = its data")
	var late: Client = _join(r, 102, "cleric", feet_in(Vector2i(80, 54)), false)
	check_eq(late.surface.data.get_value(WorldData.Layer.PLACEABLE, TREE), WorldData.PLACEABLE_STUMP, "a late joiner gets the stump")
	var f: Forest = r.host.forest_of(Config.MAP_SURFACE)
	var left: int = f.regrow.get(TREE, -1)
	check(left > 0 and left < Config.TREE_REGROW_TICKS, "the host's forest counts the stump down (%d ticks left)" % left)
	f.regrow[TREE] = 2
	_tick(r, 2 + 2 * r.delay + 2)
	check(data.get_value(WorldData.Layer.PLACEABLE, TREE) == WorldData.PLACEABLE_TREE
		and c.surface.data.get_value(WorldData.Layer.PLACEABLE, TREE) == WorldData.PLACEABLE_TREE
		and late.surface.data.get_value(WorldData.Layer.PLACEABLE, TREE) == WorldData.PLACEABLE_TREE,
		"it grew back on the host and both clients saw the edit")
	check(worlds_agree(r), "worlds agree")
	_free_rig(r)


## Four players with a 3-tick one-way delay: the host builds a wall row, the archer chops the tree, the miner and the cleric
## use the chest at once; every world, position and inventory agrees and the predictions got only the host's events wrong.
func _check_four_builders() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 3
	await await_frames(1)
	var data: WorldData = r.surface.data
	var hp: Player = r.s.local.player
	hp.inventory.clear()
	give(r.s.local, &"stone_wall", 20)
	give(r.s.local, &"storage_chest", 1)
	hp.inventory.select(slot_of(hp.inventory, &"storage_chest"))
	hp.teleport(feet_in(CHEST_FEET))
	press(r, click_at(centre_of(CHEST_AT)))
	var key: Vector2i = data.footprint_at(CHEST_AT).position
	r.host.apply_world_edit(EditLog.WorldEdit.chest_slot(key, 0, ItemStack.new(&"planks", 40, ItemDB.Grade.NONE)))
	r.host.apply_world_edit(EditLog.WorldEdit.chest_slot(key, 1, ItemStack.new(&"stone_a", 40, ItemDB.Grade.NONE)))
	var archer: Client = _join(r, 101, "archer", feet_in(TREE_FEET), false)
	var miner: Client = _join(r, 102, "miner", feet_in(CHEST_FEET + Vector2i(-2, 0)), false)
	var cleric: Client = _join(r, 103, "cleric", feet_in(CHEST_FEET + Vector2i(2, 0)), false)
	give(hm(r, archer), &"axe", 1)
	_tick(r, 2 * r.delay + 2)
	press(r, null, archer, _select(slot_of(archer.s.local.player.inventory, &"axe")))
	var swing: NetBot.Action = NetBot.Action.new()
	swing.mouse = centre_of(TREE)
	swing.aiming = true
	swing.use_held = true
	archer.action = swing
	miner.action = chest_click(key, true, 0)
	cleric.action = chest_click(key, true, 1)
	_tick(r)
	miner.action = null
	cleric.action = null
	# The host builds a row of walls south of the light meanwhile (its own clicks).
	hp.inventory.select(slot_of(hp.inventory, &"stone_wall"))
	for x: int in range(56, 61):
		host_builds(r, Building.STONE_WALL, Vector2i(x, 60))
	_tick(r, Config.TREE_CHOP_HITS * PlayerSim.action_ticks(RigData.Anim.AXE) + 10)
	archer.action = null
	_tick(r, 2 * r.delay + 30)
	check_eq(data.get_value(WorldData.Layer.PLACEABLE, TREE), WorldData.PLACEABLE_STUMP, "four: the archer felled the tree")
	check(hm(r, miner).player.inventory.count_of(&"planks") == 40 and hm(r, cleric).player.inventory.count_of(&"stone_a") == 40,
		"four: the miner took the planks, the cleric the stones, in one tick")
	check_eq(r.host.builds_done, 5, "four: the host built five walls")
	check(worlds_agree(r), "four: every world = the host's")
	for c: Client in [archer, miner, cleric]:
		check_eq(c.s.local.player.inventory.describe(), hm(r, c).player.inventory.describe(), "four: %s's inventory = the host's" % c.s.local.class_id)
		check_eq(c.s.local.player.sim_position, hm(r, c).player.sim_position, "four: %s stands where the host has it" % c.s.local.class_id)
		check_prediction("four: %s" % c.s.local.class_id, c)
	_free_rig(r)


# --- traffic ---------------------------------------------------------------------------------------------------------------

## ENet payload bytes to two clients (one process, host -> clients): a piece built, a door toggled, a piece taken down; a
## chest session (two clients storing and taking a stack every 20 ticks for 4 s).
func _measure_build_traffic() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 1
	await await_frames(1)
	var data: WorldData = r.surface.data
	var hp: Player = r.s.local.player
	hp.inventory.clear()
	give(r.s.local, &"stone_wall", 10)
	give(r.s.local, &"door", 2)
	give(r.s.local, &"storage_chest", 1)
	var a: Client = _join(r, 101, "miner", feet_in(CHEST_FEET + Vector2i(-2, 0)), false)
	var b: Client = _join(r, 102, "archer", feet_in(CHEST_FEET + Vector2i(2, 0)), false)
	_tick(r, 60)
	var lines: PackedStringArray = []
	var before: Dictionary[String, int] = r.bytes_by_kind.duplicate()
	var edits_before: int = r.s.log_for(Config.MAP_SURFACE).size()
	hp.teleport(feet_in(Vector2i(66, 54)))
	hp.inventory.select(slot_of(hp.inventory, &"stone_wall"))
	press(r, click_at(centre_of(Vector2i(67, 55))))
	_tick(r, 59)
	var one_wall: float = _rate_since(r, before, 60, lines, "one wall built (1 s window)")
	var wall_bytes: int = 0
	for k: String in r.bytes_by_kind:
		var was: int = before.get(k, 0)
		wall_bytes += r.bytes_by_kind[k] - was
	before = r.bytes_by_kind.duplicate()
	hp.inventory.select(slot_of(hp.inventory, &"door"))
	press(r, click_at(centre_of(Vector2i(67, 53))))
	press(r, f_at(Vector2i(67, 53)))
	press(r, f_at(Vector2i(67, 53)))
	_tick(r, 57)
	var door_rate: float = _rate_since(r, before, 60, lines, "a door built, opened and closed (1 s window)")
	before = r.bytes_by_kind.duplicate()
	press(r, NetBot.Action.new())
	var wreck: NetBot.Action = NetBot.Action.new()
	wreck.op = Main.request(NetProtocol.Op.DEMOLISH)
	wreck.mouse = centre_of(Vector2i(67, 55))
	wreck.aiming = true
	press(r, wreck)
	_tick(r, 58)
	var wreck_rate: float = _rate_since(r, before, 60, lines, "a wall taken down (1 s window)")
	var edits: int = r.s.log_for(Config.MAP_SURFACE).size() - edits_before
	check(edits == 5 and one_wall > 0.0 and one_wall < 300.0 and door_rate < 400.0 and wreck_rate < 300.0,
		"building costs a few edits and one inventory: %d edits, a wall %.0f B/s, door %.0f B/s, wreck %.0f B/s" % [edits,
		one_wall, door_rate, wreck_rate])
	note("one wall built = %d B to two clients (11 B edit each + the builder's own inventory)" % wall_bytes)
	# The chest session.
	hp.inventory.select(slot_of(hp.inventory, &"storage_chest"))
	hp.teleport(feet_in(CHEST_FEET))
	press(r, click_at(centre_of(CHEST_AT)))
	hp.teleport(feet_in(Vector2i(58, 47)))
	var key: Vector2i = data.footprint_at(CHEST_AT).position
	give(hm(r, a), &"stone_a", 60)
	give(hm(r, b), &"planks", 30)
	_tick(r, 30)
	before = r.bytes_by_kind.duplicate()
	var moves: int = 0
	for i: int in 12:
		var store: bool = i % 2 == 0
		press(r, null, a, chest_click(key, not store, 0 if not store else slot_of(a.s.local.player.inventory, &"stone_a")))
		_tick(r, 9)
		b.action = chest_click(key, not store, 1 if not store else slot_of(b.s.local.player.inventory, &"planks"))
		_tick(r)
		b.action = null
		_tick(r, 9)
		moves += 2
	var chest_rate: float = _rate_since(r, before, 12 * 20, lines, "two players storing and taking (%d moves in 4 s)" % moves)
	var own: int = 0
	for k2: String in ["edit", "inventory"]:
		var was2: int = before.get(k2, 0)
		own += r.bytes_by_kind.get(k2, 0) - was2
	var own_rate: float = own * float(Config.NET_TICK_RATE) / (12 * 20)
	check(r.host.chest_moves >= moves - 2 and own_rate < 800.0 and chest_rate < 3000.0,
		"a chest session: %.0f B/s to two clients for %d moves, of which the chest's own (edits + inventories) %.0f B/s" % [
		chest_rate, r.host.chest_moves, own_rate])
	note("one chest slot edit = 16 B (+ 2 B RPC); a move changes 1..2 slots and sends the mover its inventory (%d B)" % (
		NetProtocol.encode_inventory(hm(r, a).player.inventory, 0).size()))
	check(worlds_agree(r), "traffic: worlds agree")
	note("M7c traffic, one process, ENet payload bytes host -> two clients: %s" % "; ".join(lines))
	_free_rig(r)
