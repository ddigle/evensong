class_name NetProtocol
extends RefCounted
## Wire format of the session. Every RPC carries one PackedByteArray built here (little endian).
## Decoders check sizes and ranges first and return ok = false instead of reading past the end,
## so a malformed packet is counted and dropped without engine errors.
##
## Channels (one ordered stream each, so the streams do not hold each other up):
##   CH_CONTROL 0 reliable            hello, world chunks, welcome, refused, joined, left, edits,
##                                    keyframe, inventory, map entry, go, done, finish (one ordered
##                                    stream: a joiner gets its world chunks, then the welcome, then
##                                    the rest; M3b: a player entering a map gets that map's chunks,
##                                    then the map entry, then that map's edits)
##   CH_INPUT   1 unreliable ordered  client -> host input frames (and the requests riding on them)
##   CH_STATE   2 unreliable ordered  host -> clients player-state batches
##   CH_ENEMY   3 unreliable ordered  host -> the clients on one map: that map's enemy batches (M4b)
##
## Input packet  u32 first_seq, u8 count, count x u8 frame code (frames first_seq, first_seq+1, ...),
##               then, only when some of those frames carry a request (M2b): u8 op count, and per op
##               u8 frame index (ascending, one op per frame), u8 op, the op's fields:
##                 USE     u8 map, u8 hotbar slot, s16 x, s16 y (target tile), u8 aim (M4b: Combat.aim_code
##                         toward the mouse; a weapon's attack goes that way)   start that tool's action
##                 PICKUP  u8 map, s16 x, s16 y (target tile)                  F: pick up what lies there
##                 SELECT  u8 hotbar slot                                      Q / E
##                 DROP    u8 map, u8 slot, u8 count (0 = all), s16 x, s16 y   debug: drop onto the tile
##                 GIVE    u8 item index (255 = debug kit), u8 count, u8 grade debug, test builds only
##                 TRAVEL  u8 map, s16 x, s16 y (the entrance / stairs tile)   M3b: F on a way to another map
##                 THROW   u8 map, u8 hotbar slot, s16 x, s16 y (target tile: the facing), u8 aim, s16 x,
##                         s16 y (M6b: the point the bottle is thrown at, world px; the host clamps it to
##                         Config.THROW_RANGE_PX from where it has the thrower)   the skill key 1
##                 CRAFT   u8 map, u8 recipe (index in Crafting.recipes())     M6b: the crafting panel
##               M3b: a request aimed at a tile names the map it was aimed on (the map the sender
##               was on when it made the frame); the host refuses it on any other map ("wrong map").
##               M6b: a USE of a potion is a drink (the host resolves it from the slot, like a tool).
##               frame code = (dx + 1) + 3 * (dy + 1) + 9 * (look + 1) + 45 * dash + 90 * F held, 0..179:
##               8 ways + none, the look = the facing toward the mouse while aiming (0..3) or -1 (the
##               facing follows the movement; the host derives it with the client's rule,
##               Movement.facing_for), M4b: Space pressed this frame (a dash) and F held (a revive of
##               someone next to you, giving up while down). Codes 0..8 are M1's frames, 0..44 M2b's.
##               Requests repeat with their frame until the host acknowledges it, and the host handles
##               them when it handles that frame, at that position.
## State batch   u32 host_tick, u8 count, count x state (17 B):
##               u8 slot, f32 x, f32 y, u8 flags (bits 0-1 facing, bit 2 walking, bits 3-6 body
##               action: 0 = none, else the RigData action anim), u32 ack, u8 action frames so far,
##               u8 held item (0 = empty hand, else item index + 1), u8 map (M3b: the map the player
##               is on; a client draws only the players on its own map)
##               M4b: flags bit 7 = a vitals block follows (16 B, VITALS_SIZE): u8 hp, u8 stamina, u8
##               life, u8 stamina wait, u8 regen tick, u8 dash ticks, u8 dash direction (0..8 like a frame
##               code), u8 dash cooldown, u8 hurt ticks, u8 invulnerable ticks, u8 hit flash, u8 give-up
##               hold, u16 life ticks, u16 revive ticks. Without it the player is at rest (full HP and
##               stamina, no timer running, up: Vitals.at_rest), so a session without a fight sends M3b's
##               17 B states. A state is 17 or 33 B.
##               M6b: the life byte's bit 7 = an effects block follows the vitals block (7 B, EFFECTS_SIZE):
##               u8 buff percent, u16 buff ticks, u8 poison damage, u16 poison ticks, u8 poison timer. Only
##               while a buff or a poison runs (a player with one is never at rest), so a state is 17, 33 or
##               40 B.
##               Positions are the host's float32 simulation values, sent exactly, so a client that
##               replays its unacknowledged frames from them lands where the host will (M4b: the vitals
##               too: they are part of what the replay starts from).
## Player info   u8 class index + state (18 or 34 B), in welcome and joined
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
## Map entry     host -> the player who went to another map (M3b), after that map's world chunks:
##               u8 map, u32 edit position (that map's edits already in the snapshot), u32 raw size,
##               u32 packed size, u32 chunk count, 16 B packed md5, 16 B world md5, then the
##               player's own state (17 or 33 B, ack = its last frame the host handled) on the new map
## Enemy batch   host -> the clients on one map (M4b), unreliable on CH_ENEMY while anything changes, then
##               once reliable (keyframe), and reliable right after a welcome / map entry: u32 host tick,
##               u8 map, u16 shrine HP (0 = none standing), u8 count, count x enemy (17 B): u32 id, f32 x,
##               f32 y, u8 flags (bits 0-1 facing, bit 2 walking, bits 3-5 HereticSim.State), u16 state
##               start (host tick - state ticks, low 16 bits; 0 for the untimed states idle / chase /
##               return), u8 hp, u8 hit flash ticks left. An enemy missing from a batch is gone.
##               M6b: flags bit 6 = poisoned (the mark over its head; the HP is the host's).
## Shot events   host -> the clients on one map (M4b), reliable: u8 map, u8 count, then per event
##               u8 kind: 0 = let go (u32 id, u8 weapon item index, u8 shooter slot (255 = none), u32 host
##               tick, f32 x, f32 y (the body point it starts from), u8 aim code: 20 B), 1 = stopped
##               (u32 id, u32 host tick, f32 x, f32 y, u8 why (SHOT_STOPS): 18 B). The client flies the
##               shot itself between the two (Combat's speed for the weapon, the same aim vector).
##               M6b, a thrown potion: 2 = thrown (u32 id, u8 potion item index, u8 thrower slot, u32 host
##               tick, f32 x, f32 y (where it left the hand), f32 x, f32 y (where it lands at most): 27 B),
##               3 = broke (u32 id, u8 potion item index, u32 host tick, f32 x, f32 y (the splash), u8 why
##               (FLASK_STOPS): 19 B). The client flies the bottle itself (Arena.flask_points, the host's
##               own steps) and shows the splash from the tick it broke.

## 2: facing left the input frames (the host derives it); late join gets the world as a snapshot.
## 3 (M2b): frames carry the look and requests, states the body action and held item, inventories,
## drop edits, gatherables and drops in the world snapshot.
## 4 (M3b): maps in sessions: states carry the map, tile requests the map they aim on, TRAVEL, edits
## the map they change, the snapshot header its map, the map entry message.
## 5 (M4b): combat in sessions: frame codes carry the dash and F held, a USE its aim, states the vitals
## block, the enemy batches and the shot events per map.
## 6 (M6b): potions and crafting in sessions: THROW and CRAFT requests, the effects block after the vitals,
## the heretic's poison flag, the thrown and broke events of a thrown potion.
const VERSION: int = 6

const CH_CONTROL: int = 0
const CH_INPUT: int = 1
const CH_STATE: int = 2
const CH_ENEMY: int = 3

## Why the host refused a hello. Names are what the logs and test results print.
enum Refusal { NONE, FULL, VERSION, CLASS, CLASS_TAKEN, BAD_HELLO }
const REFUSAL_NAMES: PackedStringArray = ["none", "full", "version", "class", "class_taken", "bad_hello"]

## Requests riding on input frames (M2b). M6b: THROW (the skill key 1), CRAFT (the crafting panel).
enum Op { NONE, USE, PICKUP, SELECT, DROP, GIVE, TRAVEL, THROW, CRAFT }
const OP_NAMES: PackedStringArray = ["none", "use", "pickup", "select", "drop", "give", "travel", "throw", "craft"]
## Field bytes per op (after the frame index and the op byte). M4b: USE + the aim byte.
const OP_SIZES: PackedInt32Array = [0, 7, 5, 1, 7, 3, 5, 11, 2]

const INPUT_HEADER: int = 5
const STATE_HEADER: int = 5
## A state without its vitals block (and with it: STATE_SIZE + VITALS_SIZE, M4b).
const STATE_SIZE: int = 17
const INFO_SIZE: int = 18
const VITALS_SIZE: int = 16
const VITALS_FLAG: int = 0x80
## M6b: the effects block after the vitals block (its flag: bit 7 of the vitals block's life byte).
const EFFECTS_SIZE: int = 7
const EFFECTS_FLAG: int = 0x80
## M6b: the enemy flag of a poisoned heretic.
const ENEMY_POISONED: int = 0x40
## M4b: enemy batches and shot events.
const ENEMY_HEADER: int = 4 + 1 + 2 + 1
const ENEMY_SIZE: int = 17
## Most enemies one batch carries (lowest ids first; the slice's caps are 4 and 6 alive, plus corpses).
const ENEMY_BATCH_MAX: int = 64
const SHOT_SPAWN_SIZE: int = 20
const SHOT_END_SIZE: int = 18
## M6b: a thrown potion's events.
const FLASK_THROW_SIZE: int = 27
const FLASK_SPLASH_SIZE: int = 19
## IMPL (named in M6-fix): a thrown event whose landing point is farther than Config.THROW_RANGE_PX + this (px) from
## where it left the hand is refused (the host clamps it to the range; the slack takes float rounding).
const FLASK_RANGE_SLACK_PX: float = 1.0
const SHOT_EVENTS_MAX: int = 255
## Why a shot stopped (Arena.Shot.stopped_by), by wire index.
const SHOT_STOPS: PackedStringArray = ["spent", "wall", "heretic", "shrine", "player"]
## M6b: why a thrown potion broke (Arena.Flask.stopped_by), by wire index.
const FLASK_STOPS: PackedStringArray = ["landed", "wall"]
const HELLO_SIZE: int = 3
const WELCOME_FIXED: int = 2 + 1 + 1 + 4 + 1 + 4 + 4 + 4 + 4 + 16 + 16 + 16
const INVENTORY_HEADER: int = 6
## The map entry with an at-rest state (+ VITALS_SIZE with a vitals block, M4b).
const MAP_ENTRY_SIZE: int = 1 + 4 + 4 + 4 + 4 + 16 + 16 + STATE_SIZE
## Where the map entry's state starts (its fixed head; named in M4-fix).
const MAP_ENTRY_STATE_AT: int = MAP_ENTRY_SIZE - STATE_SIZE
const INVENTORY_SLOT_BYTES: int = 3
## Directions (9) x looks (none + 4 facings) x dash (M4b) x F held (M4b).
const CODE_COUNT: int = 180
const DIR_CODES: int = 9
const LOOK_CODES: int = 45
const DASH_CODE: int = 45
const INTERACT_CODE: int = 90


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
	## M3b: the map a tile request (USE, PICKUP, DROP, TRAVEL) was aimed on.
	var map: int = Config.MAP_SURFACE
	## Resolved, not sent: the body action a USE starts (-1 = none) and the item playing it.
	var anim: int = -1
	var item: StringName = &""
	## M6a: a potion throw's landing point (world px, clamped to Config.THROW_RANGE_PX, Potions.throw_target).
	## M6b: sent with a THROW in whole px (the host clamps it again from where it has the thrower).
	var throw_to: Vector2 = Vector2.ZERO
	## M6b: a CRAFT's recipe (its index in Crafting.recipes()).
	var recipe: int = 0
	## M4a, on the wire since M4b: Space this frame (a dash), F held (revive someone / give up while down),
	## and a USE's aim (Combat.aim_code, -1 = toward the tile; on the wire a USE always carries one: -1 is
	## sent as 0, and the game always sets it, Player.make_frame).
	var dash: bool = false
	var interact: bool = false
	var aim: int = -1

	func _init(p_seq: int = 0, p_dir: Vector2i = Vector2i.ZERO) -> void:
		seq = p_seq
		dir = p_dir

	## The request part equals `o`'s (op and its fields).
	func same_request(o: InputFrame) -> bool:
		return o != null and op == o.op and slot == o.slot and cell == o.cell and count == o.count \
			and item_index == o.item_index and grade == o.grade and (map == o.map or not NetProtocol.op_has_map(op)) \
			and (op != Op.THROW or throw_to == o.throw_to) and (op != Op.CRAFT or recipe == o.recipe)

	func describe_op() -> String:
		match op:
			Op.USE:
				return "use map=%d slot=%d at=%d,%d aim=%d" % [map, slot, cell.x, cell.y, aim]
			Op.PICKUP:
				return "pickup map=%d at=%d,%d" % [map, cell.x, cell.y]
			Op.SELECT:
				return "select slot=%d" % slot
			Op.DROP:
				return "drop map=%d slot=%d count=%d at=%d,%d" % [map, slot, count, cell.x, cell.y]
			Op.GIVE:
				return "give item=%d count=%d grade=%d" % [item_index, count, grade]
			Op.TRAVEL:
				return "travel map=%d at=%d,%d" % [map, cell.x, cell.y]
			Op.THROW:
				return "throw map=%d slot=%d at=%d,%d to=%d,%d" % [map, slot, cell.x, cell.y, roundi(throw_to.x),
					roundi(throw_to.y)]
			Op.CRAFT:
				return "craft map=%d recipe=%d" % [map, recipe]
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
	## M3b: the map the player is on.
	var map: int = Config.MAP_SURFACE
	## M4b: the player's vitals, or null when they are at rest (Vitals.at_rest: full, up, no timer).
	var vitals: Vitals = null

	func same_as(o: PlayerState) -> bool:
		return o != null and slot == o.slot and pos == o.pos and facing == o.facing and walking == o.walking \
			and ack == o.ack and action == o.action and action_tick == o.action_tick and held == o.held and map == o.map \
			and NetProtocol.same_vitals(vitals, o.vitals)

	## The vitals (a fresh, full set when at rest).
	func vitals_or_full() -> Vitals:
		return vitals.copy() if vitals != null else Vitals.new()


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


## M3b: what a player who went to another map gets after that map's world chunks: which map, the
## snapshot's numbers (checked like the welcome's) and its own state there.
class MapEntry:
	extends RefCounted
	var ok: bool = false
	var map: int = Config.MAP_SURFACE
	## Edits of that map already in the snapshot (the index of its next live edit).
	var edit_position: int = 0
	var raw_size: int = 0
	var packed_size: int = 0
	var chunk_count: int = 0
	var packed_md5: PackedByteArray = PackedByteArray()
	var world_md5: PackedByteArray = PackedByteArray()
	var state: PlayerState = PlayerState.new()


## A player's inventory as the host sends it to its owner (M2b).
class InventoryState:
	extends RefCounted
	var ok: bool = false
	var ack: int = 0
	var selected: int = 0
	var stacks: Array[ItemStack] = []


## M4b: one heretic as the host sends it (HereticSim's drawn part).
class EnemyState:
	extends RefCounted
	var id: int = 0
	var pos: Vector2 = Vector2.ZERO
	var facing: int = RigData.Dir.SOUTH
	var walking: bool = false
	var state: int = HereticSim.State.IDLE
	## Host tick the state started (low 16 bits), 0 for the untimed states (NetProtocol.timed_state).
	var since: int = 0
	var hp: int = Config.HERETIC_HP
	var flash: int = 0
	## M6b: poisoned (flags bit 6).
	var poisoned: bool = false

	func same_as(o: EnemyState) -> bool:
		return o != null and id == o.id and pos == o.pos and facing == o.facing and walking == o.walking \
			and state == o.state and since == o.since and hp == o.hp and flash == o.flash and poisoned == o.poisoned


## M4b: one map's enemies and its shrine at a host tick.
class EnemyBatch:
	extends RefCounted
	var ok: bool = false
	var tick: int = 0
	var map: int = Config.MAP_SURFACE
	var shrine_hp: int = 0
	var enemies: Array[EnemyState] = []


## M4b: a shot let go (SPAWN) or stopped (END). M6b: a potion thrown (THROW) or broken (SPLASH).
class ShotEvent:
	extends RefCounted
	enum Kind { SPAWN, END, THROW, SPLASH }
	var kind: int = Kind.SPAWN
	var id: int = 0
	## SPAWN: the weapon item, the shooter's slot (255 = none), the aim code. THROW / SPLASH: the potion item;
	## THROW: the thrower's slot.
	var item: StringName = &""
	var owner: int = 255
	var aim: int = 0
	## The host tick it was let go / stopped, where (the body point it flies at), why it stopped (END: SHOT_STOPS,
	## SPLASH: FLASK_STOPS). THROW: `pos` = where it left the hand, `target` = where it lands at most.
	var tick: int = 0
	var pos: Vector2 = Vector2.ZERO
	var why: int = 0
	var target: Vector2 = Vector2.ZERO

	func same_as(o: ShotEvent) -> bool:
		return o != null and kind == o.kind and id == o.id and item == o.item and owner == o.owner and aim == o.aim \
			and tick == o.tick and pos == o.pos and why == o.why and target == o.target


class ShotEvents:
	extends RefCounted
	var ok: bool = false
	var map: int = Config.MAP_SURFACE
	var events: Array[ShotEvent] = []


# --- frame codes -----------------------------------------------------------------------------

static func frame_code(dir: Vector2i, look: int = -1, dash: bool = false, interact: bool = false) -> int:
	return (clampi(dir.x, -1, 1) + 1) + 3 * (clampi(dir.y, -1, 1) + 1) + DIR_CODES * (clampi(look, -1, 3) + 1) \
		+ (DASH_CODE if dash else 0) + (INTERACT_CODE if interact else 0)


## Frame for a code, or null for a code outside 0..CODE_COUNT - 1.
static func frame_from_code(code: int, seq: int) -> InputFrame:
	if code < 0 or code >= CODE_COUNT:
		return null
	var d: int = code % DIR_CODES
	var f: InputFrame = InputFrame.new(seq, Vector2i(d % 3 - 1, d / 3 - 1))
	f.look = (code % LOOK_CODES) / DIR_CODES - 1
	f.dash = (code % INTERACT_CODE) >= DASH_CODE
	f.interact = code >= INTERACT_CODE
	return f


## A direction (-1..1 per axis) as 0..8 (a frame code's direction part), and back.
static func dir_code(dir: Vector2i) -> int:
	return (clampi(dir.x, -1, 1) + 1) + 3 * (clampi(dir.y, -1, 1) + 1)


static func dir_from_code(code: int) -> Vector2i:
	return Vector2i(code % 3 - 1, code / 3 - 1)


## Whether requests of kind `op` carry a map (they aim at a tile of it; M6b: a throw, a craft at a station of it).
static func op_has_map(op: int) -> bool:
	return op == Op.USE or op == Op.PICKUP or op == Op.DROP or op == Op.TRAVEL or op == Op.THROW or op == Op.CRAFT


static func valid_map(map: int) -> bool:
	return map >= 0 and map < Config.MAP_COUNT


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
		out.encode_u8(INPUT_HEADER + i, frame_code(frames[i].dir, frames[i].look, frames[i].dash, frames[i].interact))
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
	if op_has_map(f.op):
		out.encode_u8(at, f.map)
		at += 1
	match f.op:
		Op.USE:
			out.encode_u8(at, f.slot)
			out.encode_s16(at + 1, f.cell.x)
			out.encode_s16(at + 3, f.cell.y)
			out.encode_u8(at + 5, clampi(f.aim, 0, Combat.AIM_STEPS - 1))
		Op.PICKUP, Op.TRAVEL:
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
		Op.THROW:
			out.encode_u8(at, f.slot)
			out.encode_s16(at + 1, f.cell.x)
			out.encode_s16(at + 3, f.cell.y)
			out.encode_u8(at + 5, clampi(f.aim, 0, Combat.AIM_STEPS - 1))
			out.encode_s16(at + 6, clampi(roundi(f.throw_to.x), -32768, 32767))
			out.encode_s16(at + 8, clampi(roundi(f.throw_to.y), -32768, 32767))
		Op.CRAFT:
			out.encode_u8(at, clampi(f.recipe, 0, 255))


## The op's fields at `at` into `f`; false when a field is out of range (map, slots, item, grade).
static func _get_op(bytes: PackedByteArray, at: int, op: int, f: InputFrame) -> bool:
	f.op = op
	if op_has_map(op):
		f.map = bytes.decode_u8(at)
		at += 1
		if not valid_map(f.map):
			return false
	match op:
		Op.USE:
			f.slot = bytes.decode_u8(at)
			f.cell = Vector2i(bytes.decode_s16(at + 1), bytes.decode_s16(at + 3))
			f.aim = bytes.decode_u8(at + 5)
			return f.slot < Config.HOTBAR_SLOTS
		Op.PICKUP, Op.TRAVEL:
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
		Op.THROW:
			f.slot = bytes.decode_u8(at)
			f.cell = Vector2i(bytes.decode_s16(at + 1), bytes.decode_s16(at + 3))
			f.aim = bytes.decode_u8(at + 5)
			f.throw_to = Vector2(bytes.decode_s16(at + 6), bytes.decode_s16(at + 8))
			return f.slot < Config.HOTBAR_SLOTS
		Op.CRAFT:
			f.recipe = bytes.decode_u8(at)
			return f.recipe < Crafting.recipe_count()
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
	out.resize(STATE_HEADER)
	out.encode_u32(0, tick)
	out.encode_u8(4, states.size())
	for s: PlayerState in states:
		var at: int = out.size()
		out.resize(at + state_size(s))
		_put_state(out, at, s)
	return out


static func decode_states(bytes: PackedByteArray) -> StateBatch:
	var b: StateBatch = StateBatch.new()
	if bytes.size() < STATE_HEADER:
		return b
	var count: int = bytes.decode_u8(4)
	if count > Config.MAX_PLAYERS or bytes.size() < STATE_HEADER + STATE_SIZE * count:
		return b
	b.tick = bytes.decode_u32(0)
	var at: int = STATE_HEADER
	for i: int in count:
		var n: int = state_size_at(bytes, at)
		if n < 0:
			return b
		var s: PlayerState = _get_state(bytes, at)
		if s == null:
			return b
		b.states.append(s)
		at += n
	b.ok = at == bytes.size()
	return b


## M4b: a state's size on the wire (17 B, or 33 B with its vitals block; M6b: 40 B with its effects block).
static func state_size(s: PlayerState) -> int:
	return STATE_SIZE + vitals_size(s.vitals)


## M6b: the bytes vitals `v` take after a state: none at rest, the vitals block, plus the effects block while a
## buff or a poison runs.
static func vitals_size(v: Vitals) -> int:
	if v == null or v.at_rest():
		return 0
	return VITALS_SIZE + (EFFECTS_SIZE if v.has_effects() else 0)


## The size of the state at `at` from its flags byte (M6b: and its vitals block's life byte), or -1 when it
## does not fit in `bytes`.
static func state_size_at(bytes: PackedByteArray, at: int) -> int:
	if at < 0 or bytes.size() < at + STATE_SIZE:
		return -1
	var n: int = STATE_SIZE
	if (bytes.decode_u8(at + 9) & VITALS_FLAG) != 0:
		n += VITALS_SIZE
		if bytes.size() < at + n:
			return -1
		if (bytes.decode_u8(at + STATE_SIZE + 2) & EFFECTS_FLAG) != 0:
			n += EFFECTS_SIZE
	return n if bytes.size() >= at + n else -1


static func _put_state(out: PackedByteArray, at: int, s: PlayerState) -> void:
	var action: int = s.action if RigData.is_action(s.action) else 0
	var with_vitals: bool = s.vitals != null and not s.vitals.at_rest()
	out.encode_u8(at, s.slot)
	out.encode_float(at + 1, s.pos.x)
	out.encode_float(at + 5, s.pos.y)
	out.encode_u8(at + 9, (s.facing & 3) | (4 if s.walking else 0) | (action << 3) | (VITALS_FLAG if with_vitals else 0))
	out.encode_u32(at + 10, s.ack)
	out.encode_u8(at + 14, s.action_tick if action != 0 else 0)
	out.encode_u8(at + 15, ItemDB.index_of(s.held) + 1 if not s.held.is_empty() else 0)
	out.encode_u8(at + 16, s.map)
	if with_vitals:
		put_vitals(out, at + STATE_SIZE, s.vitals)


## The state at `at` (its vitals block too: the caller checked the size with state_size_at), or null.
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
	s.map = bytes.decode_u8(at + 16)
	if s.slot >= Config.MAX_PLAYERS or not (is_finite(s.pos.x) and is_finite(s.pos.y)) or not valid_map(s.map):
		return null
	if (flags & VITALS_FLAG) != 0:
		if state_size_at(bytes, at) < 0:
			return null
		s.vitals = get_vitals(bytes, at + STATE_SIZE)
		if s.vitals == null or s.vitals.at_rest():
			return null  # an at-rest block is never sent: one is malformed
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
	out.resize(1 + state_size(info.state))
	out.encode_u8(0, info.class_index)
	_put_state(out, 1, info.state)
	return out


## Info at `at`, or null when it does not fit or is out of range.
static func decode_info(bytes: PackedByteArray, at: int = 0) -> PlayerInfo:
	if at < 0 or bytes.size() < at + INFO_SIZE or state_size_at(bytes, at + 1) < 0:
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


## M4b: the size of the info at `at` (18 or 34 B), or -1.
static func info_size_at(bytes: PackedByteArray, at: int) -> int:
	var n: int = state_size_at(bytes, at + 1)
	return 1 + n if n > 0 else -1


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
	if count > Config.MAX_PLAYERS or bytes.size() < at + INFO_SIZE * count:
		return w
	for i: int in count:
		var n: int = info_size_at(bytes, at)
		var info: PlayerInfo = decode_info(bytes, at) if n > 0 else null
		if info == null:
			return w
		w.players.append(info)
		at += n
	if at != bytes.size():
		return w
	# Chunk size is the host's (WorldSnapshot.chunk_bytes): the receiver checks the exact count.
	w.ok = w.slot < Config.MAX_PLAYERS and w.max_players >= 1 and w.max_players <= Config.MAX_PLAYERS \
		and w.packed_size > 0 and w.chunk_count >= WorldSnapshot.chunks_for(w.packed_size, Config.NET_SNAPSHOT_CHUNK_BYTES) \
		and w.chunk_count <= w.packed_size
	return w


static func _put_md5(out: PackedByteArray, at: int, md5: PackedByteArray) -> void:
	for i: int in 16:
		out.encode_u8(at + i, md5[i] if i < md5.size() else 0)


# --- map entry (M3b) -------------------------------------------------------------------------

static func encode_map_entry(e: MapEntry) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(MAP_ENTRY_SIZE - STATE_SIZE + state_size(e.state))
	out.encode_u8(0, e.map)
	out.encode_u32(1, e.edit_position)
	out.encode_u32(5, e.raw_size)
	out.encode_u32(9, e.packed_size)
	out.encode_u32(13, e.chunk_count)
	_put_md5(out, 17, e.packed_md5)
	_put_md5(out, 33, e.world_md5)
	_put_state(out, MAP_ENTRY_STATE_AT, e.state)
	return out


## The map entry, or ok = false (size, map id, chunk count against the packed size, the state).
static func decode_map_entry(bytes: PackedByteArray) -> MapEntry:
	var e: MapEntry = MapEntry.new()
	if bytes.size() < MAP_ENTRY_SIZE or bytes.size() != MAP_ENTRY_STATE_AT + state_size_at(bytes, MAP_ENTRY_STATE_AT):
		return e
	e.map = bytes.decode_u8(0)
	e.edit_position = bytes.decode_u32(1)
	e.raw_size = bytes.decode_u32(5)
	e.packed_size = bytes.decode_u32(9)
	e.chunk_count = bytes.decode_u32(13)
	e.packed_md5 = bytes.slice(17, 33)
	e.world_md5 = bytes.slice(33, MAP_ENTRY_STATE_AT)
	var st: PlayerState = _get_state(bytes, MAP_ENTRY_STATE_AT)
	if st == null or not valid_map(e.map) or st.map != e.map:
		return e
	e.state = st
	e.ok = e.packed_size > 0 and e.chunk_count >= WorldSnapshot.chunks_for(e.packed_size, Config.NET_SNAPSHOT_CHUNK_BYTES) \
		and e.chunk_count <= e.packed_size
	return e


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


# --- vitals (M4b) --------------------------------------------------------------------------------

## Both null (at rest) or the same replicated vitals.
static func same_vitals(a: Vitals, b: Vitals) -> bool:
	var x: Vitals = a if a != null else Vitals.new()
	var y: Vitals = b if b != null else Vitals.new()
	return x.same_wire(y)


## The vitals block (VITALS_SIZE) at `at`; M6b: then the effects block (EFFECTS_SIZE) while a buff or a poison
## runs, flagged in the life byte's bit 7 (`out` holds vitals_size(v) bytes from `at`).
static func put_vitals(out: PackedByteArray, at: int, v: Vitals) -> void:
	var effects: bool = v.has_effects()
	out.encode_u8(at, clampi(v.hp, 0, 255))
	out.encode_u8(at + 1, clampi(v.stamina, 0, 255))
	out.encode_u8(at + 2, v.life | (EFFECTS_FLAG if effects else 0))
	out.encode_u8(at + 3, clampi(v.stamina_wait, 0, 255))
	out.encode_u8(at + 4, clampi(v.regen_tick, 0, 255))
	out.encode_u8(at + 5, clampi(v.dash_ticks, 0, 255))
	out.encode_u8(at + 6, dir_code(v.dash_dir))
	out.encode_u8(at + 7, clampi(v.dash_cooldown, 0, 255))
	out.encode_u8(at + 8, clampi(v.hurt_ticks, 0, 255))
	out.encode_u8(at + 9, clampi(v.invuln_ticks, 0, 255))
	out.encode_u8(at + 10, clampi(v.flash_ticks, 0, 255))
	out.encode_u8(at + 11, clampi(v.give_up_ticks, 0, 255))
	out.encode_u16(at + 12, clampi(v.life_ticks, 0, 65535))
	out.encode_u16(at + 14, clampi(v.revive_ticks, 0, 65535))
	if effects:
		var e: int = at + VITALS_SIZE
		out.encode_u8(e, clampi(v.buff_pct, 0, 255))
		out.encode_u16(e + 1, clampi(v.buff_ticks, 0, 65535))
		out.encode_u8(e + 3, clampi(v.poison_damage, 0, 255))
		out.encode_u16(e + 4, clampi(v.poison_ticks, 0, 65535))
		out.encode_u8(e + 6, clampi(v.poison_timer, 0, 255))


## The vitals block at `at` (M6b: with its effects block when flagged), or null when a field is out of its
## range (the Config limits it can reach) or the block does not fit.
static func get_vitals(bytes: PackedByteArray, at: int) -> Vitals:
	if at < 0 or bytes.size() < at + VITALS_SIZE:
		return null
	var v: Vitals = Vitals.new()
	v.hp = bytes.decode_u8(at)
	v.stamina = bytes.decode_u8(at + 1)
	var life: int = bytes.decode_u8(at + 2)
	v.life = life & ~EFFECTS_FLAG
	v.stamina_wait = bytes.decode_u8(at + 3)
	v.regen_tick = bytes.decode_u8(at + 4)
	v.dash_ticks = bytes.decode_u8(at + 5)
	var dir: int = bytes.decode_u8(at + 6)
	v.dash_cooldown = bytes.decode_u8(at + 7)
	v.hurt_ticks = bytes.decode_u8(at + 8)
	v.invuln_ticks = bytes.decode_u8(at + 9)
	v.flash_ticks = bytes.decode_u8(at + 10)
	v.give_up_ticks = bytes.decode_u8(at + 11)
	v.life_ticks = bytes.decode_u16(at + 12)
	v.revive_ticks = bytes.decode_u16(at + 14)
	if v.hp > Config.PLAYER_HP_MAX or v.stamina > Config.STAMINA_MAX or v.life > Vitals.Life.DEAD \
			or v.stamina_wait > Config.STAMINA_REGEN_DELAY_TICKS or v.regen_tick >= maxi(Config.STAMINA_REGEN_TICKS, 1) \
			or v.dash_ticks > Config.DASH_TICKS or dir >= DIR_CODES \
			or v.dash_cooldown > Config.DASH_COOLDOWN_TICKS + Config.DASH_TICKS or v.hurt_ticks > Config.HURT_TICKS \
			or v.invuln_ticks > Config.HURT_INVULN_TICKS or v.flash_ticks > Config.HIT_FLASH_TICKS \
			or v.give_up_ticks > Config.GIVE_UP_HOLD_TICKS:
		return null
	v.dash_dir = dir_from_code(dir)
	if (life & EFFECTS_FLAG) != 0:
		if bytes.size() < at + VITALS_SIZE + EFFECTS_SIZE:
			return null
		var e: int = at + VITALS_SIZE
		v.buff_pct = bytes.decode_u8(e)
		v.buff_ticks = bytes.decode_u16(e + 1)
		v.poison_damage = bytes.decode_u8(e + 3)
		v.poison_ticks = bytes.decode_u16(e + 4)
		v.poison_timer = bytes.decode_u8(e + 6)
		if not effects_valid(v) or not v.has_effects():
			return null  # a flagged block with no effect is never sent
	return v


## M6b: the effects within the values the rules can give them (Config "M6a"): a buff's percent and time, a
## poison's damage, time and timer.
static func effects_valid(v: Vitals) -> bool:
	var max_pct: int = 100
	for p: int in Config.BUFF_SPEED_PCT:
		max_pct = maxi(max_pct, p)
	var max_buff: int = 0
	for t: int in Config.BUFF_TICKS:
		max_buff = maxi(max_buff, t)
	var max_damage: int = 0
	for d: int in Config.POISON_DAMAGE:
		max_damage = maxi(max_damage, d)
	var max_poison: int = 0
	for t2: int in Config.POISON_TICKS:
		max_poison = maxi(max_poison, t2)
	return v.buff_ticks <= max_buff and v.buff_pct <= max_pct and v.buff_pct >= 100 and v.poison_ticks <= max_poison \
		and v.poison_damage <= max_damage and v.poison_timer <= Config.POISON_INTERVAL_TICKS


# --- enemies and shots (M4b) ---------------------------------------------------------------------

## Whether a heretic state counts its ticks (the batch sends when it started; the others send 0).
static func timed_state(state: int) -> bool:
	return state == HereticSim.State.ATTACK or state == HereticSim.State.HURT or state == HereticSim.State.EDGE \
		or state == HereticSim.State.DEAD


## A heretic's state at host tick `tick`.
static func enemy_of(h: HereticSim, tick: int) -> EnemyState:
	var e: EnemyState = EnemyState.new()
	e.id = h.id
	e.pos = h.pos
	e.facing = h.facing
	e.walking = h.walking
	e.state = h.state
	e.since = (tick - h.state_ticks) & 0xFFFF if timed_state(h.state) else 0
	e.hp = h.hp
	e.flash = h.flash_ticks
	e.poisoned = h.alive() and h.poisoned()
	return e


static func encode_enemies(tick: int, map: int, shrine_hp: int, enemies: Array[EnemyState]) -> PackedByteArray:
	var n: int = mini(enemies.size(), ENEMY_BATCH_MAX)
	var out: PackedByteArray = PackedByteArray()
	out.resize(ENEMY_HEADER + ENEMY_SIZE * n)
	out.encode_u32(0, tick)
	out.encode_u8(4, map)
	out.encode_u16(5, clampi(shrine_hp, 0, 65535))
	out.encode_u8(7, n)
	for i: int in n:
		var e: EnemyState = enemies[i]
		var at: int = ENEMY_HEADER + ENEMY_SIZE * i
		out.encode_u32(at, e.id)
		out.encode_float(at + 4, e.pos.x)
		out.encode_float(at + 8, e.pos.y)
		out.encode_u8(at + 12, (e.facing & 3) | (4 if e.walking else 0) | ((e.state & 7) << 3) | (ENEMY_POISONED if e.poisoned else 0))
		out.encode_u16(at + 13, e.since & 0xFFFF)
		out.encode_u8(at + 15, clampi(e.hp, 0, 255))
		out.encode_u8(at + 16, clampi(e.flash, 0, 255))
	return out


## The batch, or ok = false (size, map, count, a state or field out of range, a NaN, ids twice).
static func decode_enemies(bytes: PackedByteArray) -> EnemyBatch:
	var b: EnemyBatch = EnemyBatch.new()
	if bytes.size() < ENEMY_HEADER:
		return b
	var count: int = bytes.decode_u8(7)
	if count > ENEMY_BATCH_MAX or bytes.size() != ENEMY_HEADER + ENEMY_SIZE * count:
		return b
	b.tick = bytes.decode_u32(0)
	b.map = bytes.decode_u8(4)
	b.shrine_hp = bytes.decode_u16(5)
	if not valid_map(b.map) or b.shrine_hp > Config.SHRINE_HP:
		return b
	var ids: Dictionary[int, bool] = {}
	for i: int in count:
		var at: int = ENEMY_HEADER + ENEMY_SIZE * i
		var e: EnemyState = EnemyState.new()
		e.id = bytes.decode_u32(at)
		e.pos = Vector2(bytes.decode_float(at + 4), bytes.decode_float(at + 8))
		var flags: int = bytes.decode_u8(at + 12)
		e.facing = flags & 3
		e.walking = (flags & 4) != 0
		e.state = (flags >> 3) & 7
		e.poisoned = (flags & ENEMY_POISONED) != 0
		e.since = bytes.decode_u16(at + 13)
		e.hp = bytes.decode_u8(at + 15)
		e.flash = bytes.decode_u8(at + 16)
		if (flags & 0x80) != 0 or (e.poisoned and e.state == HereticSim.State.DEAD) or e.state >= HereticSim.STATE_NAMES.size() or not (is_finite(e.pos.x) and is_finite(e.pos.y)) \
				or e.hp > Config.HERETIC_HP or e.flash > Config.HIT_FLASH_TICKS or ids.has(e.id) \
				or (e.since != 0 and not timed_state(e.state)):
			return b
		ids[e.id] = true
		b.enemies.append(e)
	b.ok = true
	return b


static func encode_shots(map: int, events: Array[ShotEvent]) -> PackedByteArray:
	var n: int = mini(events.size(), SHOT_EVENTS_MAX)
	var out: PackedByteArray = PackedByteArray([map, n])
	for i: int in n:
		var e: ShotEvent = events[i]
		var at: int = out.size()
		if e.kind == ShotEvent.Kind.SPAWN:
			out.resize(at + SHOT_SPAWN_SIZE)
			out.encode_u8(at, ShotEvent.Kind.SPAWN)
			out.encode_u32(at + 1, e.id)
			out.encode_u8(at + 5, ItemDB.index_of(e.item))
			out.encode_u8(at + 6, clampi(e.owner, 0, 255))
			out.encode_u32(at + 7, e.tick)
			out.encode_float(at + 11, e.pos.x)
			out.encode_float(at + 15, e.pos.y)
			out.encode_u8(at + 19, clampi(e.aim, 0, Combat.AIM_STEPS - 1))
		elif e.kind == ShotEvent.Kind.THROW:
			out.resize(at + FLASK_THROW_SIZE)
			out.encode_u8(at, ShotEvent.Kind.THROW)
			out.encode_u32(at + 1, e.id)
			out.encode_u8(at + 5, ItemDB.index_of(e.item))
			out.encode_u8(at + 6, clampi(e.owner, 0, 255))
			out.encode_u32(at + 7, e.tick)
			out.encode_float(at + 11, e.pos.x)
			out.encode_float(at + 15, e.pos.y)
			out.encode_float(at + 19, e.target.x)
			out.encode_float(at + 23, e.target.y)
		elif e.kind == ShotEvent.Kind.SPLASH:
			out.resize(at + FLASK_SPLASH_SIZE)
			out.encode_u8(at, ShotEvent.Kind.SPLASH)
			out.encode_u32(at + 1, e.id)
			out.encode_u8(at + 5, ItemDB.index_of(e.item))
			out.encode_u32(at + 6, e.tick)
			out.encode_float(at + 10, e.pos.x)
			out.encode_float(at + 14, e.pos.y)
			out.encode_u8(at + 18, e.why)
		else:
			out.resize(at + SHOT_END_SIZE)
			out.encode_u8(at, ShotEvent.Kind.END)
			out.encode_u32(at + 1, e.id)
			out.encode_u32(at + 5, e.tick)
			out.encode_float(at + 9, e.pos.x)
			out.encode_float(at + 13, e.pos.y)
			out.encode_u8(at + 17, e.why)
	return out


## The events, or ok = false (size, map, a kind, a weapon that shoots nothing, a NaN, a why).
static func decode_shots(bytes: PackedByteArray) -> ShotEvents:
	var s: ShotEvents = ShotEvents.new()
	if bytes.size() < 2:
		return s
	s.map = bytes.decode_u8(0)
	var count: int = bytes.decode_u8(1)
	if not valid_map(s.map):
		return s
	var at: int = 2
	for i: int in count:
		if at >= bytes.size():
			return s
		var e: ShotEvent = ShotEvent.new()
		e.kind = bytes.decode_u8(at)
		if e.kind == ShotEvent.Kind.SPAWN:
			if at + SHOT_SPAWN_SIZE > bytes.size():
				return s
			e.id = bytes.decode_u32(at + 1)
			var item: int = bytes.decode_u8(at + 5)
			e.owner = bytes.decode_u8(at + 6)
			e.tick = bytes.decode_u32(at + 7)
			e.pos = Vector2(bytes.decode_float(at + 11), bytes.decode_float(at + 15))
			e.aim = bytes.decode_u8(at + 19)
			e.item = ItemDB.id_at(item) if item < ItemDB.count() else &""
			var a: Combat.Attack = Combat.attack_for(e.item) if not e.item.is_empty() else null
			if a == null or a.kind == Combat.Kind.MELEE or not (is_finite(e.pos.x) and is_finite(e.pos.y)):
				return s
			at += SHOT_SPAWN_SIZE
		elif e.kind == ShotEvent.Kind.END:
			if at + SHOT_END_SIZE > bytes.size():
				return s
			e.id = bytes.decode_u32(at + 1)
			e.tick = bytes.decode_u32(at + 5)
			e.pos = Vector2(bytes.decode_float(at + 9), bytes.decode_float(at + 13))
			e.why = bytes.decode_u8(at + 17)
			if e.why >= SHOT_STOPS.size() or not (is_finite(e.pos.x) and is_finite(e.pos.y)):
				return s
			at += SHOT_END_SIZE
		elif e.kind == ShotEvent.Kind.THROW:
			if at + FLASK_THROW_SIZE > bytes.size():
				return s
			e.id = bytes.decode_u32(at + 1)
			e.item = _potion_at(bytes.decode_u8(at + 5))
			e.owner = bytes.decode_u8(at + 6)
			e.tick = bytes.decode_u32(at + 7)
			e.pos = Vector2(bytes.decode_float(at + 11), bytes.decode_float(at + 15))
			e.target = Vector2(bytes.decode_float(at + 19), bytes.decode_float(at + 23))
			if e.item.is_empty() or not (is_finite(e.pos.x) and is_finite(e.pos.y) and is_finite(e.target.x) 					and is_finite(e.target.y)) or e.pos.distance_to(e.target) > Config.THROW_RANGE_PX + FLASK_RANGE_SLACK_PX:
				return s
			at += FLASK_THROW_SIZE
		elif e.kind == ShotEvent.Kind.SPLASH:
			if at + FLASK_SPLASH_SIZE > bytes.size():
				return s
			e.id = bytes.decode_u32(at + 1)
			e.item = _potion_at(bytes.decode_u8(at + 5))
			e.tick = bytes.decode_u32(at + 6)
			e.pos = Vector2(bytes.decode_float(at + 10), bytes.decode_float(at + 14))
			e.why = bytes.decode_u8(at + 18)
			if e.item.is_empty() or e.why >= FLASK_STOPS.size() or not (is_finite(e.pos.x) and is_finite(e.pos.y)):
				return s
			at += FLASK_SPLASH_SIZE
		else:
			return s
		s.events.append(e)
	s.ok = at == bytes.size()
	return s


## M6b: the potion at item index `index` (&"" when it is no potion).
static func _potion_at(index: int) -> StringName:
	var id: StringName = ItemDB.id_at(index) if index < ItemDB.count() else &""
	return id if not id.is_empty() and Potions.is_potion(id) else &""
