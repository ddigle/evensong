class_name NetProtocol
extends RefCounted
## Wire format of the session. Every RPC carries one PackedByteArray built here (little endian).
## Decoders check sizes and ranges first and return ok = false instead of reading past the end,
## so a malformed packet is counted and dropped without engine errors.
##
## Channels (one ordered stream each, so the streams do not hold each other up):
##   CH_CONTROL 0 reliable            hello, world chunks, welcome, refused, joined, left, edits,
##                                    keyframe, inventory, go, done, finish (one ordered stream: a
##                                    joiner gets its world chunks, then the welcome, then the rest)
##   CH_INPUT   1 unreliable ordered  client -> host input frames (and the requests riding on them)
##   CH_STATE   2 unreliable ordered  host -> clients player-state batches
##
## Input packet  u32 first_seq, u8 count, count x u8 frame code (frames first_seq, first_seq+1, ...),
##               then, only when some of those frames carry a request (M2b): u8 op count, and per op
##               u8 frame index (ascending, one op per frame), u8 op, the op's fields:
##                 USE     u8 hotbar slot, s16 x, s16 y (target tile)          start that tool's action
##                 PICKUP  s16 x, s16 y (target tile)                          F: pick up what lies there
##                 SELECT  u8 hotbar slot                                      Q / E
##                 DROP    u8 slot, u8 count (0 = all), s16 x, s16 y           debug: drop onto the tile
##                 GIVE    u8 item index (255 = debug kit), u8 count, u8 grade debug, test builds only
##               frame code = (dx + 1) + 3 * (dy + 1) + 9 * (look + 1), 0..44: 8 ways + none, and the
##               look = the facing toward the mouse while aiming (0..3) or -1 (the facing follows the
##               movement; the host derives it with the client's rule, Movement.facing_for). Codes
##               0..8 are M1's frames. Requests repeat with their frame until the host acknowledges
##               it, and the host handles them when it handles that frame, at that position.
## State batch   u32 host_tick, u8 count, count x state (16 B):
##               u8 slot, f32 x, f32 y, u8 flags (bits 0-1 facing, bit 2 walking, bits 3-6 body
##               action: 0 = none, else the RigData action anim), u32 ack, u8 action frames so far,
##               u8 held item (0 = empty hand, else item index + 1)
##               Positions are the host's float32 simulation values, sent exactly, so a client that
##               replays its unacknowledged frames from them lands where the host will.
## Player info   u8 class index + state (17 B), in welcome and joined
## Hello         u16 version, u8 class index
## World chunk   u32 index + at most NET_SNAPSHOT_CHUNK_BYTES of the packed world (net/world_snapshot.gd),
##               reliable, before the welcome
## Welcome       u16 version, u8 your slot, u8 max players, u32 host tick, u8 bots started,
##               u32 edit position (edits already in the world snapshot; later ones follow as edits),
##               snapshot: u32 raw size, u32 packed size, u32 chunk count, 16 B packed md5,
##               16 B world md5, diagnostic: 16 B generator md5 (the host's generator's world for
##               the seed in the snapshot header, before any edit), u8 player count + player infos
## Refused       u8 reason (Refusal)
## Inventory     host -> its owner only (M2b): u32 ack (the owner's last frame the host handled when it
##               sent this), u8 selected hotbar slot, u8 slot count, per slot u8 item (0 = empty, else
##               index + 1), u8 count, u8 grade

## 2: facing left the input frames (the host derives it); late join gets the world as a snapshot.
## 3 (M2b): frames carry the look and requests, states the body action and held item, inventories,
## drop edits, gatherables and drops in the world snapshot.
const VERSION: int = 3

const CH_CONTROL: int = 0
const CH_INPUT: int = 1
const CH_STATE: int = 2

## Why the host refused a hello. Names are what the logs and test results print.
enum Refusal { NONE, FULL, VERSION, CLASS, CLASS_TAKEN, BAD_HELLO }
const REFUSAL_NAMES: PackedStringArray = ["none", "full", "version", "class", "class_taken", "bad_hello"]

## Requests riding on input frames (M2b).
enum Op { NONE, USE, PICKUP, SELECT, DROP, GIVE }
const OP_NAMES: PackedStringArray = ["none", "use", "pickup", "select", "drop", "give"]
## Field bytes per op (after the frame index and the op byte).
const OP_SIZES: PackedInt32Array = [0, 5, 4, 1, 6, 3]

const INPUT_HEADER: int = 5
const STATE_HEADER: int = 5
const STATE_SIZE: int = 16
const INFO_SIZE: int = 17
const HELLO_SIZE: int = 3
const WELCOME_FIXED: int = 2 + 1 + 1 + 4 + 1 + 4 + 4 + 4 + 4 + 16 + 16 + 16
const INVENTORY_HEADER: int = 6
const INVENTORY_SLOT_BYTES: int = 3
## Directions (9) x looks (none + 4 facings).
const CODE_COUNT: int = 45
const DIR_CODES: int = 9


## One tick of a player's input: an 8-way direction (-1/0/1 per axis), the look (facing toward the
## mouse while aiming, -1 = none: the host derives the facing from the direction with the client's
## rule), and at most one request (op) with its fields. `anim` and `item` are not sent: whoever runs
## the frame resolves a USE into the action and the item it plays (the host from its inventory).
class InputFrame:
	extends RefCounted
	var seq: int = 0
	var dir: Vector2i = Vector2i.ZERO
	var look: int = -1
	var op: int = Op.NONE
	var slot: int = 0
	var cell: Vector2i = Vector2i.ZERO
	var count: int = 0
	var item_index: int = 0
	var grade: int = 0
	## Resolved, not sent: the body action a USE starts (-1 = none) and the item playing it.
	var anim: int = -1
	var item: StringName = &""

	func _init(p_seq: int = 0, p_dir: Vector2i = Vector2i.ZERO) -> void:
		seq = p_seq
		dir = p_dir

	## The request part equals `o`'s (op and its fields).
	func same_request(o: InputFrame) -> bool:
		return o != null and op == o.op and slot == o.slot and cell == o.cell and count == o.count \
			and item_index == o.item_index and grade == o.grade

	func describe_op() -> String:
		match op:
			Op.USE:
				return "use slot=%d at=%d,%d" % [slot, cell.x, cell.y]
			Op.PICKUP:
				return "pickup at=%d,%d" % [cell.x, cell.y]
			Op.SELECT:
				return "select slot=%d" % slot
			Op.DROP:
				return "drop slot=%d count=%d at=%d,%d" % [slot, count, cell.x, cell.y]
			Op.GIVE:
				return "give item=%d count=%d grade=%d" % [item_index, count, grade]
		return "none"


## A player's replicated state. `ack` = the last input frame of this player the host has handled.
class PlayerState:
	extends RefCounted
	var slot: int = 0
	var pos: Vector2 = Vector2.ZERO
	var facing: int = RigData.Dir.SOUTH
	var walking: bool = false
	var ack: int = 0
	## M2b: the body action playing (RigData action anim, -1 = none), its frames so far, the held item.
	var action: int = -1
	var action_tick: int = 0
	var held: StringName = &""

	func same_as(o: PlayerState) -> bool:
		return o != null and slot == o.slot and pos == o.pos and facing == o.facing and walking == o.walking \
			and ack == o.ack and action == o.action and action_tick == o.action_tick and held == o.held


## Who a player is (class) and where they are.
class PlayerInfo:
	extends RefCounted
	var class_index: int = 0
	var state: PlayerState = PlayerState.new()


class InputPacket:
	extends RefCounted
	var ok: bool = false
	var frames: Array[InputFrame] = []
	## Frames with an invalid code (dropped with their request; their seq is still used up).
	var bad_frames: int = 0


class StateBatch:
	extends RefCounted
	var ok: bool = false
	var tick: int = 0
	var states: Array[PlayerState] = []


class Hello:
	extends RefCounted
	var ok: bool = false
	var version: int = 0
	var class_index: int = -1


class Welcome:
	extends RefCounted
	var ok: bool = false
	var version: int = VERSION
	var slot: int = 0
	var max_players: int = Config.MAX_PLAYERS
	var tick: int = 0
	var bots_started: bool = false
	## Edits already contained in the snapshot (the index of the next live edit).
	var edit_position: int = 0
	var raw_size: int = 0
	var packed_size: int = 0
	var chunk_count: int = 0
	var packed_md5: PackedByteArray = PackedByteArray()
	var world_md5: PackedByteArray = PackedByteArray()
	## Diagnostic only: hash of the world the host's generator makes from the seed (no edits). The
	## seed itself is in the snapshot header (WorldData.world_seed).
	var generator_md5: PackedByteArray = PackedByteArray()
	var players: Array[PlayerInfo] = []


## A player's inventory as the host sends it to its owner (M2b).
class InventoryState:
	extends RefCounted
	var ok: bool = false
	var ack: int = 0
	var selected: int = 0
	var stacks: Array[ItemStack] = []


# --- frame codes -----------------------------------------------------------------------------

static func frame_code(dir: Vector2i, look: int = -1) -> int:
	return (clampi(dir.x, -1, 1) + 1) + 3 * (clampi(dir.y, -1, 1) + 1) + DIR_CODES * (clampi(look, -1, 3) + 1)


## Frame for a code, or null for a code outside 0..CODE_COUNT - 1.
static func frame_from_code(code: int, seq: int) -> InputFrame:
	if code < 0 or code >= CODE_COUNT:
		return null
	var d: int = code % DIR_CODES
	var f: InputFrame = InputFrame.new(seq, Vector2i(d % 3 - 1, d / 3 - 1))
	f.look = code / DIR_CODES - 1
	return f


static func class_index(class_id: String) -> int:
	return Config.CLASSES.find(class_id)


## Class id for an index, "" when out of range.
static func class_name_of(index: int) -> String:
	return Config.CLASSES[index] if index >= 0 and index < Config.CLASSES.size() else ""


# --- input -----------------------------------------------------------------------------------

## Consecutive frames (frames[i].seq = frames[0].seq + i), at most NET_MAX_FRAMES_PER_PACKET.
static func encode_inputs(frames: Array[InputFrame]) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	if frames.is_empty():
		return out
	out.resize(INPUT_HEADER + frames.size())
	out.encode_u32(0, frames[0].seq)
	out.encode_u8(4, frames.size())
	var ops: int = 0
	for i: int in frames.size():
		out.encode_u8(INPUT_HEADER + i, frame_code(frames[i].dir, frames[i].look))
		if frames[i].op != Op.NONE:
			ops += 1
	if ops == 0:
		return out
	out.append(ops)
	for i: int in frames.size():
		var f: InputFrame = frames[i]
		if f.op == Op.NONE:
			continue
		var at: int = out.size()
		out.resize(at + 2 + OP_SIZES[f.op])
		out.encode_u8(at, i)
		out.encode_u8(at + 1, f.op)
		_put_op(out, at + 2, f)
	return out


static func _put_op(out: PackedByteArray, at: int, f: InputFrame) -> void:
	match f.op:
		Op.USE:
			out.encode_u8(at, f.slot)
			out.encode_s16(at + 1, f.cell.x)
			out.encode_s16(at + 3, f.cell.y)
		Op.PICKUP:
			out.encode_s16(at, f.cell.x)
			out.encode_s16(at + 2, f.cell.y)
		Op.SELECT:
			out.encode_u8(at, f.slot)
		Op.DROP:
			out.encode_u8(at, f.slot)
			out.encode_u8(at + 1, f.count)
			out.encode_s16(at + 2, f.cell.x)
			out.encode_s16(at + 4, f.cell.y)
		Op.GIVE:
			out.encode_u8(at, f.item_index)
			out.encode_u8(at + 1, f.count)
			out.encode_u8(at + 2, f.grade)


## The op's fields at `at` into `f`; false when a field is out of range (slots, item, grade).
static func _get_op(bytes: PackedByteArray, at: int, op: int, f: InputFrame) -> bool:
	f.op = op
	match op:
		Op.USE:
			f.slot = bytes.decode_u8(at)
			f.cell = Vector2i(bytes.decode_s16(at + 1), bytes.decode_s16(at + 3))
			return f.slot < Config.HOTBAR_SLOTS
		Op.PICKUP:
			f.cell = Vector2i(bytes.decode_s16(at), bytes.decode_s16(at + 2))
			return true
		Op.SELECT:
			f.slot = bytes.decode_u8(at)
			return f.slot < Config.HOTBAR_SLOTS
		Op.DROP:
			f.slot = bytes.decode_u8(at)
			f.count = bytes.decode_u8(at + 1)
			f.cell = Vector2i(bytes.decode_s16(at + 2), bytes.decode_s16(at + 4))
			return f.slot < Config.INVENTORY_SLOTS
		Op.GIVE:
			f.item_index = bytes.decode_u8(at)
			f.count = bytes.decode_u8(at + 1)
			f.grade = bytes.decode_u8(at + 2)
			return (f.item_index < ItemDB.count() or f.item_index == WorldItems.GIVE_KIT) and f.grade < ItemDB.GRADE_NAMES.size()
	return false


static func decode_inputs(bytes: PackedByteArray) -> InputPacket:
	var p: InputPacket = InputPacket.new()
	if bytes.size() < INPUT_HEADER:
		return p
	var first: int = bytes.decode_u32(0)
	var count: int = bytes.decode_u8(4)
	if count < 1 or count > Config.NET_MAX_FRAMES_PER_PACKET or bytes.size() < INPUT_HEADER + count:
		return p
	var frames: Array[InputFrame] = []
	for i: int in count:
		frames.append(frame_from_code(bytes[INPUT_HEADER + i], first + i))
	var at: int = INPUT_HEADER + count
	if at < bytes.size():
		var ops: int = bytes.decode_u8(at)
		at += 1
		if ops < 1 or ops > count:
			return p
		var last_index: int = -1
		for k: int in ops:
			if at + 2 > bytes.size():
				return p
			var index: int = bytes.decode_u8(at)
			var op: int = bytes.decode_u8(at + 1)
			if index <= last_index or index >= count or op <= Op.NONE or op >= OP_SIZES.size() \
					or at + 2 + OP_SIZES[op] > bytes.size():
				return p
			last_index = index
			var target: InputFrame = frames[index] if frames[index] != null else InputFrame.new()
			if not _get_op(bytes, at + 2, op, target):
				return p
			at += 2 + OP_SIZES[op]
		if at != bytes.size():
			return p
	for f: InputFrame in frames:
		if f == null:
			p.bad_frames += 1
		else:
			p.frames.append(f)
	p.ok = true
	return p


# --- states ----------------------------------------------------------------------------------

static func encode_states(tick: int, states: Array[PlayerState]) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(STATE_HEADER + STATE_SIZE * states.size())
	out.encode_u32(0, tick)
	out.encode_u8(4, states.size())
	for i: int in states.size():
		_put_state(out, STATE_HEADER + STATE_SIZE * i, states[i])
	return out


static func decode_states(bytes: PackedByteArray) -> StateBatch:
	var b: StateBatch = StateBatch.new()
	if bytes.size() < STATE_HEADER:
		return b
	var count: int = bytes.decode_u8(4)
	if count > Config.MAX_PLAYERS or bytes.size() != STATE_HEADER + STATE_SIZE * count:
		return b
	b.tick = bytes.decode_u32(0)
	for i: int in count:
		var s: PlayerState = _get_state(bytes, STATE_HEADER + STATE_SIZE * i)
		if s == null:
			return b
		b.states.append(s)
	b.ok = true
	return b


static func _put_state(out: PackedByteArray, at: int, s: PlayerState) -> void:
	var action: int = s.action if RigData.is_action(s.action) else 0
	out.encode_u8(at, s.slot)
	out.encode_float(at + 1, s.pos.x)
	out.encode_float(at + 5, s.pos.y)
	out.encode_u8(at + 9, (s.facing & 3) | (4 if s.walking else 0) | (action << 3))
	out.encode_u32(at + 10, s.ack)
	out.encode_u8(at + 14, s.action_tick if action != 0 else 0)
	out.encode_u8(at + 15, ItemDB.index_of(s.held) + 1 if not s.held.is_empty() else 0)


static func _get_state(bytes: PackedByteArray, at: int) -> PlayerState:
	var s: PlayerState = PlayerState.new()
	s.slot = bytes.decode_u8(at)
	s.pos = Vector2(bytes.decode_float(at + 1), bytes.decode_float(at + 5))
	var flags: int = bytes.decode_u8(at + 9)
	s.facing = flags & 3
	s.walking = (flags & 4) != 0
	var action: int = (flags >> 3) & 15
	s.ack = bytes.decode_u32(at + 10)
	var tick: int = bytes.decode_u8(at + 14)
	var held: int = bytes.decode_u8(at + 15)
	if s.slot >= Config.MAX_PLAYERS or (flags & 0x80) != 0 or not (is_finite(s.pos.x) and is_finite(s.pos.y)):
		return null
	if action == 0:
		if tick != 0:
			return null
	elif not RigData.is_action(action) or tick >= PlayerSim.action_ticks(action):
		return null
	if held > ItemDB.count():
		return null
	s.action = action if action != 0 else -1
	s.action_tick = tick
	s.held = ItemDB.id_at(held - 1) if held > 0 else &""
	return s


# --- player info -----------------------------------------------------------------------------

static func encode_info(info: PlayerInfo) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(INFO_SIZE)
	out.encode_u8(0, info.class_index)
	_put_state(out, 1, info.state)
	return out


## Info at `at`, or null when it does not fit or is out of range.
static func decode_info(bytes: PackedByteArray, at: int = 0) -> PlayerInfo:
	if at < 0 or bytes.size() < at + INFO_SIZE:
		return null
	var info: PlayerInfo = PlayerInfo.new()
	info.class_index = bytes.decode_u8(at)
	if class_name_of(info.class_index).is_empty():
		return null
	var s: PlayerState = _get_state(bytes, at + 1)
	if s == null:
		return null
	info.state = s
	return info


# --- hello / refused -------------------------------------------------------------------------

static func encode_hello(p_class_index: int, version: int = VERSION) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(HELLO_SIZE)
	out.encode_u16(0, version)
	out.encode_u8(2, p_class_index)
	return out


static func decode_hello(bytes: PackedByteArray) -> Hello:
	var h: Hello = Hello.new()
	if bytes.size() != HELLO_SIZE:
		return h
	h.version = bytes.decode_u16(0)
	h.class_index = bytes.decode_u8(2)
	h.ok = true
	return h


static func encode_refusal(reason: Refusal) -> PackedByteArray:
	return PackedByteArray([int(reason)])


## Refusal name, "bad_refusal" for a malformed payload.
static func decode_refusal(bytes: PackedByteArray) -> String:
	if bytes.size() != 1 or bytes[0] >= REFUSAL_NAMES.size():
		return "bad_refusal"
	return REFUSAL_NAMES[bytes[0]]


# --- welcome ---------------------------------------------------------------------------------

static func encode_welcome(w: Welcome) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(WELCOME_FIXED)
	out.encode_u16(0, w.version)
	out.encode_u8(2, w.slot)
	out.encode_u8(3, w.max_players)
	out.encode_u32(4, w.tick)
	out.encode_u8(8, 1 if w.bots_started else 0)
	out.encode_u32(9, w.edit_position)
	out.encode_u32(13, w.raw_size)
	out.encode_u32(17, w.packed_size)
	out.encode_u32(21, w.chunk_count)
	_put_md5(out, 25, w.packed_md5)
	_put_md5(out, 41, w.world_md5)
	_put_md5(out, 57, w.generator_md5)
	out.append(w.players.size())
	for info: PlayerInfo in w.players:
		out.append_array(encode_info(info))
	return out


static func decode_welcome(bytes: PackedByteArray) -> Welcome:
	var w: Welcome = Welcome.new()
	if bytes.size() < WELCOME_FIXED + 1:
		return w
	w.version = bytes.decode_u16(0)
	w.slot = bytes.decode_u8(2)
	w.max_players = bytes.decode_u8(3)
	w.tick = bytes.decode_u32(4)
	w.bots_started = bytes.decode_u8(8) != 0
	w.edit_position = bytes.decode_u32(9)
	w.raw_size = bytes.decode_u32(13)
	w.packed_size = bytes.decode_u32(17)
	w.chunk_count = bytes.decode_u32(21)
	w.packed_md5 = bytes.slice(25, 41)
	w.world_md5 = bytes.slice(41, 57)
	w.generator_md5 = bytes.slice(57, 73)
	var at: int = WELCOME_FIXED
	var count: int = bytes.decode_u8(at)
	at += 1
	if count > Config.MAX_PLAYERS or bytes.size() != at + INFO_SIZE * count:
		return w
	for i: int in count:
		var info: PlayerInfo = decode_info(bytes, at + INFO_SIZE * i)
		if info == null:
			return w
		w.players.append(info)
	# Chunk size is the host's (WorldSnapshot.chunk_bytes): the receiver checks the exact count.
	w.ok = w.slot < Config.MAX_PLAYERS and w.max_players >= 1 and w.max_players <= Config.MAX_PLAYERS \
		and w.packed_size > 0 and w.chunk_count >= WorldSnapshot.chunks_for(w.packed_size, Config.NET_SNAPSHOT_CHUNK_BYTES) \
		and w.chunk_count <= w.packed_size
	return w


static func _put_md5(out: PackedByteArray, at: int, md5: PackedByteArray) -> void:
	for i: int in 16:
		out.encode_u8(at + i, md5[i] if i < md5.size() else 0)


# --- inventory (M2b) -------------------------------------------------------------------------

static func encode_inventory(inv: Inventory, ack: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(INVENTORY_HEADER + INVENTORY_SLOT_BYTES * inv.size())
	out.encode_u32(0, ack)
	out.encode_u8(4, inv.selected)
	out.encode_u8(5, inv.size())
	for i: int in inv.size():
		var st: ItemStack = inv.stack_at(i)
		var at: int = INVENTORY_HEADER + INVENTORY_SLOT_BYTES * i
		if st != null:
			out.encode_u8(at, ItemDB.index_of(st.id) + 1)
			out.encode_u8(at + 1, st.count)
			out.encode_u8(at + 2, st.grade)
	return out


## The inventory, or ok = false for a malformed one (slot count, selection, item, count within its
## stack size, a grade the item can have, an empty slot with fields).
static func decode_inventory(bytes: PackedByteArray) -> InventoryState:
	var inv: InventoryState = InventoryState.new()
	if bytes.size() < INVENTORY_HEADER:
		return inv
	var slots: int = bytes.decode_u8(5)
	if slots != Config.INVENTORY_SLOTS or bytes.size() != INVENTORY_HEADER + INVENTORY_SLOT_BYTES * slots:
		return inv
	inv.ack = bytes.decode_u32(0)
	inv.selected = bytes.decode_u8(4)
	if inv.selected >= Config.HOTBAR_SLOTS:
		return inv
	for i: int in slots:
		var at: int = INVENTORY_HEADER + INVENTORY_SLOT_BYTES * i
		var item: int = bytes.decode_u8(at)
		var count: int = bytes.decode_u8(at + 1)
		var grade: int = bytes.decode_u8(at + 2)
		if item == 0:
			if count != 0 or grade != 0:
				return inv
			inv.stacks.append(null)
			continue
		var id: StringName = ItemDB.id_at(item - 1)
		var def: ItemDB.ItemDef = ItemDB.get_def(id)
		if def == null or count < 1 or count > def.stack_max or not ItemDB.valid_grade(id, grade):
			return inv
		inv.stacks.append(ItemStack.new(id, count, grade))
	inv.ok = true
	return inv
