class_name NetProtocol
extends RefCounted
## Wire format of the M1 session. Every RPC carries one PackedByteArray built here (little endian).
## Decoders check sizes and ranges first and return ok = false instead of reading past the end,
## so a malformed packet is counted and dropped without engine errors.
##
## Channels (one ordered stream each, so the streams do not hold each other up):
##   CH_CONTROL 0 reliable            hello, world chunks, welcome, refused, joined, left, edits,
##                                    keyframe, go, done, finish (one ordered stream: a joiner gets
##                                    its world chunks, then the welcome, then everything else)
##   CH_INPUT   1 unreliable ordered  client -> host input frames
##   CH_STATE   2 unreliable ordered  host -> clients player-state batches
##
## Input packet  u32 first_seq, u8 count, count x u8 frame code (frames first_seq, first_seq+1, ...)
##               frame code = (dx + 1) + 3 * (dy + 1), 0..8 (8 ways + none). No facing: the host
##               derives it from the direction with the client's rule (Movement.facing_for)
## State batch   u32 host_tick, u8 count, count x state (14 B):
##               u8 slot, f32 x, f32 y, u8 flags (bits 0-1 facing, bit 2 walking), u32 ack
##               Positions are the host's float32 simulation values, sent exactly, so a client that
##               replays its unacknowledged frames from them lands where the host will.
## Player info   u8 class index + state (15 B), in welcome and joined
## Hello         u16 version, u8 class index
## World chunk   u32 index + at most NET_SNAPSHOT_CHUNK_BYTES of the packed world (net/world_snapshot.gd),
##               reliable, before the welcome
## Welcome       u16 version, u8 your slot, u8 max players, u32 host tick, u8 bots started,
##               u32 edit position (edits already in the world snapshot; later ones follow as edits),
##               snapshot: u32 raw size, u32 packed size, u32 chunk count, 16 B packed md5,
##               16 B world md5, diagnostic: 16 B generator md5 (the host's generator's world for
##               the seed in the snapshot header, before any edit), u8 player count + player infos
## Refused       u8 reason (Refusal)

## 2: facing left the input frames (the host derives it); late join gets the world as a snapshot.
const VERSION: int = 2

const CH_CONTROL: int = 0
const CH_INPUT: int = 1
const CH_STATE: int = 2

## Why the host refused a hello. Names are what the logs and test results print.
enum Refusal { NONE, FULL, VERSION, CLASS, CLASS_TAKEN, BAD_HELLO }
const REFUSAL_NAMES: PackedStringArray = ["none", "full", "version", "class", "class_taken", "bad_hello"]

const INPUT_HEADER: int = 5
const STATE_HEADER: int = 5
const STATE_SIZE: int = 14
const INFO_SIZE: int = 15
const HELLO_SIZE: int = 3
const WELCOME_FIXED: int = 2 + 1 + 1 + 4 + 1 + 4 + 4 + 4 + 4 + 16 + 16 + 16
const CODE_COUNT: int = 9


## One tick of a player's input: an 8-way direction (-1/0/1 per axis). The facing is not sent:
## host and client both derive it with Movement.facing_for (host-side authority, nothing to trust).
class InputFrame:
	extends RefCounted
	var seq: int = 0
	var dir: Vector2i = Vector2i.ZERO

	func _init(p_seq: int = 0, p_dir: Vector2i = Vector2i.ZERO) -> void:
		seq = p_seq
		dir = p_dir


## A player's replicated state. `ack` = the last input frame of this player the host has handled.
class PlayerState:
	extends RefCounted
	var slot: int = 0
	var pos: Vector2 = Vector2.ZERO
	var facing: int = RigData.Dir.SOUTH
	var walking: bool = false
	var ack: int = 0

	func same_as(o: PlayerState) -> bool:
		return o != null and slot == o.slot and pos == o.pos and facing == o.facing and walking == o.walking \
			and ack == o.ack


## Who a player is (class) and where they are.
class PlayerInfo:
	extends RefCounted
	var class_index: int = 0
	var state: PlayerState = PlayerState.new()


class InputPacket:
	extends RefCounted
	var ok: bool = false
	var frames: Array[InputFrame] = []
	## Frames with an invalid code (dropped; their seq is still used up).
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


# --- frame codes -----------------------------------------------------------------------------

static func frame_code(dir: Vector2i) -> int:
	return (clampi(dir.x, -1, 1) + 1) + 3 * (clampi(dir.y, -1, 1) + 1)


## Frame for a code, or null for a code outside 0..8.
static func frame_from_code(code: int, seq: int) -> InputFrame:
	if code < 0 or code >= CODE_COUNT:
		return null
	return InputFrame.new(seq, Vector2i(code % 3 - 1, code / 3 - 1))


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
	for i: int in frames.size():
		out.encode_u8(INPUT_HEADER + i, frame_code(frames[i].dir))
	return out


static func decode_inputs(bytes: PackedByteArray) -> InputPacket:
	var p: InputPacket = InputPacket.new()
	if bytes.size() < INPUT_HEADER:
		return p
	var first: int = bytes.decode_u32(0)
	var count: int = bytes.decode_u8(4)
	if count < 1 or count > Config.NET_MAX_FRAMES_PER_PACKET or bytes.size() != INPUT_HEADER + count:
		return p
	for i: int in count:
		var frame: InputFrame = frame_from_code(bytes[INPUT_HEADER + i], first + i)
		if frame == null:
			p.bad_frames += 1
		else:
			p.frames.append(frame)
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
	out.encode_u8(at, s.slot)
	out.encode_float(at + 1, s.pos.x)
	out.encode_float(at + 5, s.pos.y)
	out.encode_u8(at + 9, (s.facing & 3) | (4 if s.walking else 0))
	out.encode_u32(at + 10, s.ack)


static func _get_state(bytes: PackedByteArray, at: int) -> PlayerState:
	var s: PlayerState = PlayerState.new()
	s.slot = bytes.decode_u8(at)
	s.pos = Vector2(bytes.decode_float(at + 1), bytes.decode_float(at + 5))
	var flags: int = bytes.decode_u8(at + 9)
	s.facing = flags & 3
	s.walking = (flags & 4) != 0
	s.ack = bytes.decode_u32(at + 10)
	if s.slot >= Config.MAX_PLAYERS or (flags & ~7) != 0 or not (is_finite(s.pos.x) and is_finite(s.pos.y)):
		return null
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
