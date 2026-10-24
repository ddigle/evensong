extends "res://tests/base_test.gd"
## M3b: maps in sessions, in one process (tests/test_net_session.gd runs the real sessions).
##   - wire: the map entry message (round trip, every truncation, a state on another map, unknown map
##     ids), edits naming their map, the snapshot header's map id (the joiner refuses a map it did not
##     expect), interpolation never blending two maps
##   - the host's request checks on maps (a real NetSession + SessionHost, no transport): TRAVEL in and
##     out of reach, on a tile with no way, spammed (rate), while the last map entry still streams
##     (loading), a PICKUP on the entrance; requests aimed on the wrong map (use, pick up, drop,
##     travel); a malicious client mining far tiles, the bedrock border and the exit's bedrock (M3-fix:
##     the miner's 3x3 too), spamming uses during a swing (busy), spamming torch USEs (rate, M3-fix)
##   - two swings landing on one tile in the same host tick (SessionHost.tick): exactly one break,
##     the item to the member whose hit broke it (common players and miners, a tile one hit short and
##     two hits short)
##   - the whole map flow host -> clients over a captured wire (CaptureSession: the host's real
##     messages, delivered in channel order to real SessionClient flows): a joiner on the surface does
##     not get the dungeon's edits and does not draw the host down there; it goes down and gets the
##     dungeon as the host has it (cracks, breaks, torch, drop), then live edits; a late joiner while
##     both are below sees nobody on the surface, goes down and gets everything; an edit of another
##     map is malformed; going back up gets the surface back (the dungeon left = the host's)
##   - prediction against a host that broke walls the client has not heard of yet: corrected while
##     the edit is on its way, never again after it (no runaway), same final position
##   - the bot's waitmap command, and the cost of a map entry and of a miner's swing in bytes

const SEED: int = Config.DEFAULT_SEED
## Seed-1 dungeon (README M3b): the arrival room is x 34..41, rows 15..16 above the corridor rows
## 17..18; rock (42,15) east of it with its face (42,16), rock (33,15) west with its face (33,16).
const EAST_ROCK: Vector2i = Vector2i(42, 15)
const EAST_STAND: Vector2i = Vector2i(41, 15)
const EAST_STAND_LOW: Vector2i = Vector2i(41, 16)


## A NetSession whose messages are captured instead of sent: [peer, kind, payload].
class CaptureSession:
	extends NetSession
	var wire: Array[Array] = []

	func send_world(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "world", payload])

	func send_welcome(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "welcome", payload])

	func send_joined(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "joined", payload])

	func send_left(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "left", payload])

	func send_edit(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "edit", payload])

	func send_inventory(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "inventory", payload])

	func send_map_entry(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "map", payload])

	func send_state(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "state", payload])

	func send_keyframe(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "keyframe", payload])

	func send_enemies(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "enemies", payload])

	func send_enemy_keyframe(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "enemy_key", payload])

	func send_shots(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "shots", payload])

	func send_go(peer: int) -> void:
		wire.append([peer, "go", PackedByteArray()])

	func send_input(payload: PackedByteArray) -> void:
		wire.append([1, "input", payload])

	## Captured messages to `peer` (and forgets them).
	func take_for(peer: int) -> Array[Array]:
		var out: Array[Array] = []
		var rest: Array[Array] = []
		for m: Array in wire:
			var to: int = m[0]
			if to == peer:
				out.append(m)
			else:
				rest.append(m)
		wire = rest
		return out


## Every message can go out (no real connection).
class OpenTransport:
	extends NetTransport

	func can_send_to(_peer_id: int) -> bool:
		return true


class HostRig:
	extends RefCounted
	var s: CaptureSession
	var host: SessionHost
	var surface: GameWorld
	var dungeon: GameWorld


class ClientRig:
	extends RefCounted
	var s: CaptureSession
	var peer: int = 0
	var surface: GameWorld
	var dungeon: GameWorld
	var maps_changed: Array[int] = []


func run() -> Array[String]:
	_check_map_entry_codec()
	_check_edit_maps()
	_check_snapshot_map()
	_check_interpolation_maps()
	_check_bot_waitmap()
	await _check_travel_requests()
	await _check_wrong_map_requests()
	await _check_malicious_mining()
	await _check_same_tick_mining()
	await _check_map_flow()
	_check_phantom_wall_prediction()
	_check_prediction_maps()
	return failures


# --- wire ------------------------------------------------------------------------------------------

func _check_map_entry_codec() -> void:
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(DungeonGen.generate(SEED))
	var e: NetProtocol.MapEntry = NetProtocol.MapEntry.new()
	e.map = Config.MAP_DUNGEON
	e.edit_position = 123456
	e.raw_size = packed.raw_size
	e.packed_size = packed.bytes.size()
	e.chunk_count = packed.chunk_count()
	e.packed_md5 = packed.packed_md5
	e.world_md5 = packed.world_md5
	e.state.slot = 4
	e.state.pos = Vector2(608.0, 252.000366)
	e.state.facing = RigData.Dir.SOUTH
	e.state.ack = 4000000000
	e.state.map = Config.MAP_DUNGEON
	var bytes: PackedByteArray = NetProtocol.encode_map_entry(e)
	check_eq(bytes.size(), NetProtocol.MAP_ENTRY_SIZE, "map entry = %d B" % NetProtocol.MAP_ENTRY_SIZE)
	var back: NetProtocol.MapEntry = NetProtocol.decode_map_entry(bytes)
	check(back.ok and back.map == e.map and back.edit_position == e.edit_position and back.raw_size == e.raw_size
		and back.packed_size == e.packed_size and back.chunk_count == e.chunk_count and back.packed_md5 == e.packed_md5
		and back.world_md5 == e.world_md5 and back.state.same_as(e.state), "map entry round trip (state bit for bit)")
	var short_ok: int = 0
	for n: int in bytes.size():
		if NetProtocol.decode_map_entry(bytes.slice(0, n)).ok:
			short_ok += 1
	check_eq(short_ok, 0, "every truncation of a map entry is refused (%d lengths)" % bytes.size())
	var longer: PackedByteArray = bytes.duplicate()
	longer.append(0)
	check(not NetProtocol.decode_map_entry(longer).ok, "a map entry with a trailing byte is refused")
	var bad: PackedByteArray = bytes.duplicate()
	bad[0] = Config.MAP_COUNT
	check(not NetProtocol.decode_map_entry(bad).ok, "a map entry for a map that does not exist is refused")
	bad = bytes.duplicate()
	bad[0] = Config.MAP_SURFACE
	check(not NetProtocol.decode_map_entry(bad).ok, "a map entry whose own state is on another map is refused")
	e.chunk_count = e.packed_size + 1
	check(not NetProtocol.decode_map_entry(NetProtocol.encode_map_entry(e)).ok, "more chunks than packed bytes: refused")
	e.chunk_count = 0
	check(not NetProtocol.decode_map_entry(NetProtocol.encode_map_entry(e)).ok, "no chunks: refused")
	check_eq(NetProtocol.VERSION, 7, "protocol version 7 (M3b: 4; M4b: 5; M6b: 6; M5c: 7)")
	var info: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
	info.class_index = 1
	info.state.map = Config.MAP_DUNGEON
	var ib: NetProtocol.PlayerInfo = NetProtocol.decode_info(NetProtocol.encode_info(info))
	check(ib != null and ib.state.map == Config.MAP_DUNGEON, "player info (welcome, joined) carries the map")


func _check_edit_maps() -> void:
	var e: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(42, 15), Walls.pack(Walls.KIND_ROCK, 3))
	var wire: PackedByteArray = EditLog.encode_one(e, 77, Config.MAP_DUNGEON)
	var back: Array = EditLog.decode_one(wire)
	var index: int = back[0]
	var map: int = back[2]
	var edit: EditLog.WorldEdit = back[1]
	check(index == 77 and map == Config.MAP_DUNGEON and edit.layer == WorldData.Layer.WALL and edit.cell == e.cell
		and edit.value == e.value, "a wall edit round trips with its map")
	wire[4] = Config.MAP_COUNT
	var bad: Array = EditLog.decode_one(wire)
	var bad_index: int = bad[0]
	check_eq(bad_index, -1, "an edit of a map that does not exist is malformed")
	var d: WorldData.Drop = WorldData.Drop.new(9, &"ore_iron", 1, ItemDB.Grade.NONE, Vector2i(680, 248))
	for kind: EditLog.WorldEdit in [EditLog.WorldEdit.drop_put(d), EditLog.WorldEdit.drop_remove(9)]:
		var w2: Array = EditLog.decode_one(EditLog.encode_one(kind, 3, Config.MAP_DUNGEON))
		var m2: int = w2[2]
		check_eq(m2, Config.MAP_DUNGEON, "a drop edit names its map too")


func _check_snapshot_map() -> void:
	var dungeon: WorldData = DungeonGen.generate(SEED)
	var packed: WorldSnapshot.Packed = WorldSnapshot.encode(dungeon)
	var rx: WorldSnapshot.Receiver = _receive(packed)
	var got: WorldData = rx.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size,
		packed.world_md5, Config.MAP_DUNGEON)
	check(got != null and got.map_id == Config.MAP_DUNGEON and got.content_hash() == dungeon.content_hash(),
		"the dungeon goes through the join snapshot path: same world, its map id from the header (%s)" % rx.error)
	var rx2: WorldSnapshot.Receiver = _receive(packed)
	check(rx2.finish(packed.chunk_count(), packed.bytes.size(), packed.packed_md5, packed.raw_size, packed.world_md5,
		Config.MAP_SURFACE) == null and rx2.error.begins_with("map"), "a snapshot of another map than expected is refused (%s)" % rx2.error)
	var raw: PackedByteArray = WorldSnapshot.raw_bytes(dungeon)
	check_eq(raw[21], Config.MAP_DUNGEON, "raw header byte 21 = the map id")
	raw[21] = Config.MAP_COUNT
	check(WorldSnapshot.decode_raw(raw) == null, "a snapshot naming a map that does not exist is refused")
	note("dungeon map snapshot (seed 1, 64x48): %d B packed of %d B raw, %d chunk(s), encode %d us" % [packed.bytes.size(),
		packed.raw_size, packed.chunk_count(), packed.encode_usec])


func _receive(packed: WorldSnapshot.Packed) -> WorldSnapshot.Receiver:
	var rx: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
	for i: int in packed.chunk_count():
		rx.add(packed.chunk(i))
	return rx


func _check_interpolation_maps() -> void:
	var it: Interpolation = Interpolation.new()
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.pos = Vector2(1168, 780)
	s.map = Config.MAP_SURFACE
	it.push(30, s)
	s.pos = Vector2(1170, 770)
	it.push(33, s)
	var down: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	down.pos = Vector2(608, 252)
	down.map = Config.MAP_DUNGEON
	it.push(36, down)
	var smp: Interpolation.Snap = it.sample(34.5)
	check(smp != null and smp.map == Config.MAP_DUNGEON and smp.pos == Vector2(608, 252),
		"a state on another map drops the old map's: never drawn half way between two maps (%s)" % (smp.pos if smp != null else Vector2.ZERO))
	check_eq(it.snaps.size(), 1, "only the new map's state is kept")


func _check_bot_waitmap() -> void:
	var bot: NetBot = NetBot.new()
	check_eq(bot.parse("waitmap:2,dungeon;move:1,0,2"), "", "waitmap parses (map by name)")
	check_eq(bot.parse("waitmap:1,0,30"), "", "waitmap parses (map by id, limit)")
	check_ne(bot.parse("waitmap:1,cellar"), "", "an unknown map is an error")
	check_ne(bot.parse("waitmap:0,1"), "", "waitmap needs at least one player")
	bot.parse("waitmap:2,dungeon;move:1,0,2")
	bot.map_counts = {Config.MAP_SURFACE: 2}
	var waited: int = 0
	for i: int in 5:
		if bot.step().dir == Vector2i.ZERO:
			waited += 1
	check_eq(waited, 5, "it waits while fewer players are on that map")
	bot.map_counts = {Config.MAP_SURFACE: 1, Config.MAP_DUNGEON: 2}
	bot.step()
	check_eq(bot.step().dir, Vector2i(1, 0), "and goes on once they are")
	bot.parse("waitmap:3,1,4;move:0,1,1")
	bot.map_counts = {}
	for i: int in 4:
		bot.step()
	check_eq(bot.step().dir, Vector2i(0, 1), "it gives up after its limit")


# --- rigs ------------------------------------------------------------------------------------------

func _world(map: int, generate: bool) -> GameWorld:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = map
	add_node(w)
	if generate:
		w.generate(SEED)
	return w


## A host with both maps and its own player (slot 0, paladin) on the surface; nothing ticks by itself.
func _host_rig() -> HostRig:
	var r: HostRig = HostRig.new()
	r.surface = _world(Config.MAP_SURFACE, true)
	r.dungeon = _world(Config.MAP_DUNGEON, true)
	r.dungeon.visible = false
	r.s = CaptureSession.new()
	r.s.name = &"HostNet"
	add_node(r.s)
	r.s.set_physics_process(false)
	r.s.set_process(false)
	r.s.world = r.surface
	r.s.worlds = {Config.MAP_SURFACE: r.surface, Config.MAP_DUNGEON: r.dungeon}
	r.s.options = CliOptions.new()
	r.s.options.test_no_spawns = true  # M4b: these are M3b's map checks; no heretic walks in
	r.s.role = NetSession.Role.HOST
	r.s.give_allowed = true
	r.s.transport = OpenTransport.new()
	r.host = SessionHost.new(r.s)
	r.s.host = r.host
	r.s.active = true
	r.s.local_map_changed.connect(func(map: int) -> void:
		r.surface.visible = map == Config.MAP_SURFACE
		r.dungeon.visible = map == Config.MAP_DUNGEON)
	r.host.on_opened()
	return r


## A remote member admitted on the host without the join messages (request checks).
func _member(r: HostRig, peer: int, class_id: String, map: int, cell: Vector2i) -> NetMember:
	var slot: int = r.host.roster.admit(peer, class_id)
	var m: NetMember = r.s.add_member(slot, peer, class_id, _feet(cell), RigData.Dir.SOUTH, map)
	m.gate = InputGate.new()
	return m


static func _feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * Config.TILE + Config.TILE / 2.0, cell.y * Config.TILE + Config.TILE - 2)


static func _op(op: int, map: int, cell: Vector2i, slot: int = 0) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i.ZERO)
	f.op = op
	f.map = map
	f.cell = cell
	f.slot = slot
	return f


## A client session (not connected: messages are delivered by hand) with a surface world and an empty
## dungeon world, like main.tscn makes for a client.
func _client_rig(peer: int, class_id: String) -> ClientRig:
	var c: ClientRig = ClientRig.new()
	c.peer = peer
	c.surface = _world(Config.MAP_SURFACE, false)
	c.dungeon = _world(Config.MAP_DUNGEON, false)
	c.dungeon.visible = false
	c.s = CaptureSession.new()
	c.s.name = StringName("ClientNet%d" % peer)
	add_node(c.s)
	c.s.set_physics_process(false)
	c.s.set_process(false)
	c.s.world = c.surface
	c.s.worlds = {Config.MAP_SURFACE: c.surface, Config.MAP_DUNGEON: c.dungeon}
	c.s.options = CliOptions.new()
	c.s.options.class_id = class_id
	c.s.role = NetSession.Role.CLIENT
	c.s.client = SessionClient.new(c.s)
	c.s.local_map_changed.connect(func(map: int) -> void:
		c.maps_changed.append(map)
		c.surface.visible = map == Config.MAP_SURFACE  # as Main shows the local player's map
		c.dungeon.visible = map == Config.MAP_DUNGEON)
	return c


## Delivers the host's captured messages to client `c` in order (one reliable channel, and the
## state batches with them: on localhost nothing reorders).
func _deliver(r: HostRig, c: ClientRig) -> void:
	for m: Array in r.s.take_for(c.peer):
		var kind: String = m[1]
		var payload: PackedByteArray = m[2]
		match kind:
			"world":
				c.s.client.on_world_chunk(payload)
			"welcome":
				c.s.client.on_welcome(payload)
			"joined":
				c.s.client.on_joined(payload)
			"left":
				c.s.client.on_left(payload)
			"edit":
				c.s.client.on_edit(payload)
			"map":
				c.s.client.on_map_entry(payload)
			"inventory":
				c.s.client.on_inventory(payload)
			"state", "keyframe":
				c.s.client._apply_states(payload)
			"enemies":
				c.s.client._apply_enemies(payload, false)
			"enemy_key":
				c.s.client._apply_enemies(payload, true)
			"shots":
				c.s.client.on_shots(payload)


## One host tick with the host's own player idle: frames, streams, a state batch every 3rd tick.
func _tick(r: HostRig, n: int = 1) -> void:
	for i: int in n:
		r.s.tick += 1
		var idle: NetBot.Action = NetBot.Action.new()
		idle.mouse = r.s.local.player.sim_position
		r.host.tick(idle, Time.get_ticks_msec())


## The member's frames (seq numbered from its gate), queued as one packet.
static func _send(m: NetMember, frames: Array[NetProtocol.InputFrame]) -> void:
	var seq: int = m.gate.last_seq + m.gate.waiting.size()
	for f: NetProtocol.InputFrame in frames:
		seq += 1
		f.seq = seq
	m.gate.receive(NetProtocol.decode_inputs(NetProtocol.encode_inputs(frames)))


# --- the host's checks -------------------------------------------------------------------------

func _check_travel_requests() -> void:
	var r: HostRig = _host_rig()
	await await_frames(1)
	var entrance: Rect2i = SurfaceGen.entrance_rect(r.surface.data)
	var below: Vector2i = Aim.feet_cell(DungeonGen.arrival_below(entrance))
	var far: NetMember = _member(r, 100, "cleric", Config.MAP_SURFACE, below + Vector2i(0, 2))
	r.host.run_frame(far, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, entrance.position))
	check_eq(far.ops_refused.get(WorldItems.WHY_REACH, 0), 1, "TRAVEL from three tiles away: out of reach")
	check_eq(far.map_id, Config.MAP_SURFACE, "and it stays on the surface")
	var near: NetMember = _member(r, 101, "miner", Config.MAP_SURFACE, below)
	r.host.run_frame(near, _op(NetProtocol.Op.PICKUP, Config.MAP_SURFACE, entrance.position))
	check_eq(near.ops_refused.get(WorldItems.WHY_PORTAL, 0), 1, "a PICKUP on the entrance: a way, not a thing")
	r.host.run_frame(near, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, below + Vector2i(1, 0)))
	check_eq(near.ops_refused.get(WorldItems.WHY_NOT_PORTAL, 0), 1, "TRAVEL on a plain tile: no way there")
	r.host.run_frame(near, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, Vector2i(-1, 3)))
	check_eq(near.ops_refused.get(WorldItems.WHY_OUTSIDE, 0), 1, "TRAVEL off the map: outside")
	for i: int in 10:
		r.host.run_frame(near, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, below + Vector2i(1, 0)))
	var rated: int = near.ops_refused.get("rate", 0)
	check(rated >= 8, "spammed TRAVEL is refused as rate (%s)" % near.ops_refused)
	for t: int in 4 * Config.NET_OP_INTERVAL_TICKS:
		near.refill_ops()
	var edits_before: int = r.s.log_for(Config.MAP_DUNGEON).size() + r.s.edit_log.size()
	r.host.run_frame(near, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, entrance.position))
	check(near.map_id == Config.MAP_DUNGEON and near.player.data == r.dungeon.data and near.player.get_parent() == r.dungeon.entities
		and near.player.sim_position == r.dungeon.arrival_point(), "TRAVEL next to the entrance: down at the dungeon's arrival point")
	check(near.player.facing == RigData.Dir.SOUTH and near.player.action_anim == -1, "facing south, no action")
	check(r.host.streams.has(101) and r.host.streams[101].entry and r.host.streams[101].map == Config.MAP_DUNGEON,
		"its client is being sent the dungeon")
	check_eq(r.s.log_for(Config.MAP_DUNGEON).size() + r.s.edit_log.size(), edits_before, "travelling changes no map")
	# While the dungeon still streams to it, another TRAVEL (a forged one naming the dungeon) is refused.
	r.host.run_frame(near, _op(NetProtocol.Op.TRAVEL, Config.MAP_DUNGEON, DungeonGen.exit_rect(r.dungeon.data).position))
	check_eq(near.ops_refused.get(WorldItems.WHY_LOADING, 0), 1, "TRAVEL while the map entry streams: still loading")
	check_eq(near.map_id, Config.MAP_DUNGEON, "it stays down")
	# The stream completes (the entry goes out), then the stairs take it back up.
	r.s.wire.clear()
	r.host._pump_streams()
	var msgs: Array[Array] = r.s.take_for(101)
	var kinds: PackedStringArray = []
	for m: Array in msgs:
		kinds.append(str(m[1]))
	# M4b: after the map entry come that map's enemies (a keyframe) and nothing else of another kind.
	var entry_at: int = kinds.find("map")
	check(kinds.size() >= 2 and entry_at > 0 and kinds[0] == "world" and kinds.slice(entry_at + 1) == PackedStringArray(["enemy_key"]),
		"chunks, then the map entry, then its enemies (%s)" % ", ".join(kinds))
	for t: int in Config.NET_OP_INTERVAL_TICKS:
		near.refill_ops()
	r.host.run_frame(near, _op(NetProtocol.Op.TRAVEL, Config.MAP_DUNGEON, DungeonGen.exit_rect(r.dungeon.data).position))
	check(near.map_id == Config.MAP_SURFACE and near.player.sim_position == r.surface.arrival_point(),
		"TRAVEL on the exit stairs: back south of the entrance")
	check(r.host.streams.has(101) and r.host.streams[101].map == Config.MAP_SURFACE, "and the surface is sent to it again")
	note("travel checks: far %s, near %s" % [far.ops_refused, near.ops_refused])


func _check_wrong_map_requests() -> void:
	var r: HostRig = _host_rig()
	await await_frames(1)
	var m: NetMember = _member(r, 100, "miner", Config.MAP_DUNGEON, EAST_STAND)
	m.player.inventory.add(&"pickaxe", 1)
	m.player.inventory.add(&"torch", 2)
	m.player.inventory.add(&"stone_a", 5)
	r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_SURFACE, EAST_ROCK, 0))
	var wrong: int = m.ops_refused.get(WorldItems.WHY_WRONG_MAP, 0)
	check(m.player.action_anim == -1 and wrong == 1, "a swing aimed on the surface while in the dungeon: refused, no action")
	r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_SURFACE, EAST_STAND + Vector2i(0, 1), 1))
	r.host.run_frame(m, _op(NetProtocol.Op.PICKUP, Config.MAP_SURFACE, EAST_STAND + Vector2i(-1, 0)))
	var drop: NetProtocol.InputFrame = _op(NetProtocol.Op.DROP, Config.MAP_SURFACE, EAST_STAND + Vector2i(-1, 0), 2)
	r.host.run_frame(m, drop)
	r.host.run_frame(m, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, SurfaceGen.entrance_rect(r.surface.data).position))
	check_eq(m.ops_refused.get(WorldItems.WHY_WRONG_MAP, 0), 5, "a torch, a pick up, a drop and a travel aimed on the surface: all wrong map")
	check(m.map_id == Config.MAP_DUNGEON and m.player.inventory.count_of(&"torch") == 2 and r.dungeon.data.drops.is_empty()
		and r.s.log_for(Config.MAP_DUNGEON).size() == 0 and r.s.edit_log.size() == 0, "and nothing changed anywhere")
	check_eq(m.op_budget, NetMember.OP_BUDGET_MAX, "a wrong-map request costs no request budget (refused before it)")
	r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0))
	check_eq(m.player.action_anim, RigData.Anim.PICKAXE, "the same swing aimed on the dungeon starts")
	# M3-fix: torch USEs take the request budget like a pick up: ten in one tick on one open tile, the
	# first places it, the next three find it taken (not open floor), the rest are refused as rate.
	var t: NetMember = _member(r, 101, "cleric", Config.MAP_DUNGEON, EAST_STAND + Vector2i(-2, 0))
	t.player.inventory.add(&"torch", 10)
	var spot: Vector2i = EAST_STAND + Vector2i(-2, 1)
	for i: int in 10:
		r.host.run_frame(t, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, spot, 0))
	var rate: int = t.ops_refused.get("rate", 0)
	var taken_spot: int = t.ops_refused.get(WorldItems.WHY_NOT_OPEN, 0)
	check(rate == 10 - _op_burst() and taken_spot == _op_burst() - 1
		and t.player.inventory.count_of(&"torch") == 9 and r.dungeon.data.get_value(WorldData.Layer.PLACEABLE, spot) == WorldData.PLACEABLE_TORCH,
		"ten torch USEs in one tick: one placed, the budget (%d) spent, the rest rate (%s)" % [_op_burst(), t.ops_refused])


func _check_malicious_mining() -> void:
	var r: HostRig = _host_rig()
	await await_frames(1)
	var d: WorldData = r.dungeon.data
	var m: NetMember = _member(r, 100, "cleric", Config.MAP_DUNGEON, EAST_STAND)
	m.player.inventory.add(&"pickaxe", 1)
	# Far tiles: two, three and forty tiles away, and off the map.
	for cell: Vector2i in [EAST_ROCK + Vector2i(1, 0), EAST_ROCK + Vector2i(2, 0), Vector2i(2, 40), Vector2i(-5, -5)]:
		r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, cell, 0))
	var far: int = m.ops_refused.get(WorldItems.WHY_REACH, 0)
	check(far == 4 and m.player.action_anim == -1, "a client mining far tiles: every swing refused out of reach (%s)" % m.ops_refused)
	# A swing in reach; spamming uses during it: busy, one swing only.
	r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0))
	for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE) - 1:
		r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0))
	check_eq(m.ops_refused.get("busy", 0), PlayerSim.action_ticks(RigData.Anim.PICKAXE) - 1,
		"a use on every other frame of the swing: busy (one swing at a time)")
	check_eq(Walls.hits_at(d, EAST_ROCK), Config.MINING_POWER_COMMON, "one swing, one hit")
	for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE):
		r.host.run_frame(m, NetProtocol.InputFrame.new(0, Vector2i.ZERO))  # the swing ends
	# The bedrock border: a pocket dug next to it (data edit), a common player and a miner swing at it.
	for c: Vector2i in [Vector2i(2, 10), Vector2i(2, 11), Vector2i(3, 10), Vector2i(3, 11)]:
		d.set_value(WorldData.Layer.WALL, c, 0)
	r.dungeon.cave.setup(d)
	var border: Vector2i = Vector2i(1, 11)
	check(Walls.kind_at(d, border) == Walls.KIND_BEDROCK and Movement.can_stand(d, _feet(Vector2i(2, 11))), "a pocket next to the bedrock")
	var miner: NetMember = _member(r, 101, Mining.MINER_CLASS, Config.MAP_DUNGEON, Vector2i(2, 11))
	miner.player.inventory.add(&"pickaxe", 1)
	m.player.teleport(_feet(Vector2i(2, 11)))
	var before: int = r.s.log_for(Config.MAP_DUNGEON).size()
	for who: NetMember in [m, miner]:
		r.host.run_frame(who, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, border, 0))
		for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE):
			r.host.run_frame(who, NetProtocol.InputFrame.new(0, Vector2i.ZERO))
		check_eq(who.swings_missed.get(Mining.WHY_TOO_HARD, 0), 1, "%s swinging at the bedrock border: too hard" % who.class_id)
	check_eq(r.s.log_for(Config.MAP_DUNGEON).size(), before, "the border takes no hit (no edit)")
	check(Walls.kind_at(d, border) == Walls.KIND_BEDROCK and Walls.hits_at(d, border) == 0, "bedrock unchanged")
	# The exit stairs' bedrock (a common player at the arrival point swings at the stairs).
	m.player.teleport(r.dungeon.arrival_point())
	var stairs: Vector2i = DungeonGen.exit_rect(d).position
	r.host.run_frame(m, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, stairs, 0))
	for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE):
		r.host.run_frame(m, NetProtocol.InputFrame.new(0, Vector2i.ZERO))
	check_eq(m.swings_missed.get(Mining.WHY_TOO_HARD, 0), 2, "the bedrock above the exit stairs: too hard")
	check(WorldItems.is_portal(d, stairs), "the stairs are still there")
	# M3-fix: the miner too: its 3x3 does not reach around the stairs' bedrock (it broke the rock beside
	# and behind it: 13 tiles in three swings).
	var miner_before: int = r.s.log_for(Config.MAP_DUNGEON).size()
	var dungeon_before: String = d.content_hash()
	miner.player.teleport(r.dungeon.arrival_point())
	for k: int in 3:
		r.host.run_frame(miner, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, stairs + Vector2i(k % 2, 0), 0))
		for i: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE):
			r.host.run_frame(miner, NetProtocol.InputFrame.new(0, Vector2i.ZERO))
	check_eq(miner.swings_missed.get(Mining.WHY_TOO_HARD, 0), 4, "the miner's three swings at the stairs: too hard (and one at the border)")
	check(r.s.log_for(Config.MAP_DUNGEON).size() == miner_before and d.content_hash() == dungeon_before,
		"the miner at the stairs: no edit, the dungeon unchanged")
	note("malicious mining: cleric refused %s, missed %s; miner missed %s" % [m.ops_refused, m.swings_missed, miner.swings_missed])


## Two swings landing on one tile in one host tick (SessionHost.tick: members in slot order, edits at
## once): the lower slot's hit is applied first; the tile breaks exactly once and its item goes to the
## member whose hit broke it. a swings east at the rock from beside it, b at the rock's face from the
## tile below: the same wall. Cases: the tile one hit short (a breaks it, b's swing finds no wall);
## two hits short (both hit, b breaks it); two miners two swings short (their 3x3s overlap: b breaks
## every overlapping tile, a gets nothing, each broken tile's item to exactly one).
func _check_same_tick_mining() -> void:
	for case: Array in [["cleric", "archer", 1], ["cleric", "archer", 2], [Mining.MINER_CLASS, Mining.MINER_CLASS, 2]]:
		var class_a: String = case[0]
		var class_b: String = case[1]
		var short: int = case[2]
		var r: HostRig = _host_rig()
		await await_frames(1)
		var d: WorldData = r.dungeon.data
		# b's member is added (and its frame queued) first, so slot order is not arrival order.
		var b: NetMember = _member(r, 102, class_b, Config.MAP_DUNGEON, EAST_STAND_LOW)
		var a: NetMember = _member(r, 101, class_a, Config.MAP_DUNGEON, EAST_STAND)
		if a.slot > b.slot:
			var tmp: NetMember = a
			a = b
			b = tmp
			var cell_a: Vector2 = a.player.sim_position
			a.player.teleport(b.player.sim_position)
			b.player.teleport(cell_a)
		for who: NetMember in [a, b]:
			who.player.inventory.add(&"pickaxe", 1)
		var power: int = Mining.power(class_a)
		var cells: Array[Vector2i] = []
		for c: Vector2i in Walls.wall_cells(d):
			if absi(c.x - EAST_ROCK.x) <= 3 and absi(c.y - EAST_ROCK.y) <= 3 and Walls.max_hits(d, c) > 0:
				d.set_value(WorldData.Layer.WALL, c, Walls.pack(Walls.kind_at(d, c), Walls.max_hits(d, c) - short * power))
				cells.append(c)
		r.dungeon.cave.setup(d)
		_send(b, [_op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK + Vector2i(0, 1), 0)] as Array[NetProtocol.InputFrame])
		_send(a, [_op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0)] as Array[NetProtocol.InputFrame])
		var log: EditLog = r.s.log_for(Config.MAP_DUNGEON)
		var landed: Array[int] = []
		for t: int in PlayerSim.action_ticks(RigData.Anim.PICKAXE) + 2:
			var before: int = log.size()
			_tick(r)
			if log.size() > before:
				landed.append(t)
			_send(a, [NetProtocol.InputFrame.new(0, Vector2i.ZERO)] as Array[NetProtocol.InputFrame])
			_send(b, [NetProtocol.InputFrame.new(0, Vector2i.ZERO)] as Array[NetProtocol.InputFrame])
		var label: String = "%s (slot %d) + %s (slot %d), %d swing(s) short" % [class_a, a.slot, class_b, b.slot, short]
		var a_used: int = a.ops_done.get("use", 0)
		var b_used: int = b.ops_done.get("use", 0)
		check(a_used == 1 and b_used == 1 and landed.size() == 1,
			"%s: both swings started together and landed in one tick (%s)" % [label, landed])
		var breaks: int = 0
		for e: EditLog.WorldEdit in log.edits:
			if e.kind == EditLog.Kind.CELL and e.layer == WorldData.Layer.WALL and e.cell == EAST_ROCK and e.value == 0:
				breaks += 1
		check_eq(breaks, 1, "%s: the tile breaks exactly once" % label)
		check(not Walls.is_wall(d, EAST_ROCK), "%s: and is gone" % label)
		var got_a: int = _mined_items(a)
		var got_b: int = _mined_items(b)
		var a_mined: int = a.ops_done.get("mine", 0)
		var b_mined: int = b.ops_done.get("mine", 0)
		var b_missed: int = b.swings_missed.get(Mining.WHY_NO_WALL, 0)
		if short == 1:
			check(a_mined == 1 and got_a == 1 and b_mined == 0 and got_b == 0 and b_missed == 1,
				"%s: the lower slot's hit breaks it and gets the stone; the other swing finds no wall (a %d, b %d)" % [label, got_a, got_b])
		elif class_a == Mining.MINER_CLASS:
			check(a_mined == 1 and b_mined == 1 and got_a == 0 and got_b == _broken(log) and _broken(log) >= 4,
				"%s: both 3x3s land, b breaks every tile they share, items to exactly one (a %d, b %d, %d broken)" % [
				label, got_a, got_b, _broken(log)])
		else:
			check(a_mined == 1 and b_mined == 1 and got_a == 0 and got_b == 1,
				"%s: both hits land, the second breaks it and gets the stone (a %d, b %d)" % [label, got_a, got_b])
		var broken_twice: int = 0
		for c: Vector2i in cells:
			var n: int = 0
			for e: EditLog.WorldEdit in log.edits:
				if e.kind == EditLog.Kind.CELL and e.layer == WorldData.Layer.WALL and e.cell == c and e.value == 0:
					n += 1
			if n > 1:
				broken_twice += 1
		check_eq(broken_twice, 0, "%s: no tile breaks twice" % label)
		var v: Dictionary[String, int] = r.dungeon.cave.verify()
		check(v["mismatches"] == 0 and v["overlay_mismatches"] == 0, "%s: the host's cave view follows %s" % [label, v])


## The request budget a member starts with (Config.NET_OP_BURST).
static func _op_burst() -> int:
	return Config.NET_OP_BURST


## Items a member got from mining (stones and ores).
static func _mined_items(m: NetMember) -> int:
	return m.player.inventory.count_of(Config.MINED_ROCK_ITEM) + m.player.inventory.count_of(&"ore_copper") \
		+ m.player.inventory.count_of(&"ore_iron")


static func _broken(log: EditLog) -> int:
	var n: int = 0
	for e: EditLog.WorldEdit in log.edits:
		if e.kind == EditLog.Kind.CELL and e.layer == WorldData.Layer.WALL and e.value == 0:
			n += 1
	return n


# --- the whole flow over a captured wire -----------------------------------------------------------

func _check_map_flow() -> void:
	var r: HostRig = _host_rig()
	await await_frames(1)
	var hd: WorldData = r.dungeon.data
	var entrance: Rect2i = SurfaceGen.entrance_rect(r.surface.data)
	var below: Vector2i = Aim.feet_cell(DungeonGen.arrival_below(entrance))
	# A joins (cleric) and lands on the surface.
	var a: ClientRig = _client_rig(100, "cleric")
	r.host.on_hello(100, NetProtocol.encode_hello(NetProtocol.class_index("cleric")))
	_tick(r)
	_deliver(r, a)
	if not check(a.s.active and a.s.local != null and a.s.local.map_id == Config.MAP_SURFACE, "A joined on the surface"):
		return
	var ma: NetMember = r.s.members[a.s.local.slot]
	# The host goes down and mines one swing (its own player: the frame from its keys).
	var hp: Player = r.s.local.player
	hp.teleport(DungeonGen.arrival_below(entrance))
	var travel: NetProtocol.InputFrame = _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, entrance.position)
	r.host.run_frame(r.s.local, travel)
	check(r.s.local.map_id == Config.MAP_DUNGEON and not r.host.streams.has(1), "the host's own player went down (nothing to stream)")
	hp.inventory.add(&"pickaxe", 1)
	hp.inventory.add(&"torch", 3)
	hp.inventory.add(&"stone_a", 4)
	hp.teleport(_feet(EAST_STAND))
	r.host.run_frame(r.s.local, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0))
	_tick(r, PlayerSim.action_ticks(RigData.Anim.PICKAXE) + 3)
	r.host.run_frame(r.s.local, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_STAND + Vector2i(-1, 1), 1))  # a torch
	r.host.run_frame(r.s.local, _op(NetProtocol.Op.DROP, Config.MAP_DUNGEON, EAST_STAND + Vector2i(-1, 0), 2))  # stones
	_tick(r, 3)
	var dlog: EditLog = r.s.log_for(Config.MAP_DUNGEON)
	check(dlog.size() >= 3 and Walls.hits_at(hd, EAST_ROCK) > 0 and hd.drops.size() == 1
		and hd.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TORCH) == 1, "the host cracked rock, placed a torch, dropped stones down there")
	var to_a: Array[Array] = r.s.take_for(100)
	var edits_to_a: int = 0
	var states_to_a: Array[PackedByteArray] = []
	for m: Array in to_a:
		if str(m[1]) == "edit":
			edits_to_a += 1
		if str(m[1]) == "state" or str(m[1]) == "keyframe":
			var p: PackedByteArray = m[2]
			states_to_a.append(p)
	check_eq(edits_to_a, 0, "A on the surface got none of the dungeon's %d edits" % dlog.size())
	for p: PackedByteArray in states_to_a:
		a.s.client._apply_states(p)
	a.s.client.draw_others()
	var host_on_a: NetMember = a.s.members[0]
	check(host_on_a.map_id == Config.MAP_DUNGEON and not SessionReport.drawn(host_on_a), "A knows the host is below and does not draw it")
	check(SessionReport.drawn(a.s.local), "A draws itself")
	# A goes down: chunks, the map entry, then (none yet) edits; it gets the dungeon as the host has it.
	ma.player.teleport(DungeonGen.arrival_below(entrance))
	_send(ma, [_op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, entrance.position)] as Array[NetProtocol.InputFrame])
	_tick(r, 2)
	check_eq(ma.map_id, Config.MAP_DUNGEON, "the host moved A down")
	_deliver(r, a)
	check(a.s.local.map_id == Config.MAP_DUNGEON and a.maps_changed == ([Config.MAP_DUNGEON] as Array[int]), "A switched to the dungeon")
	check(host_on_a.player.visible, "M3-fix: the map entry itself shows the players already down there (before draw_others)")
	check_eq(a.dungeon.data.content_hash(), hd.content_hash(), "A's dungeon = the host's (crack, torch, drop)")
	check(a.dungeon.data.drops.size() == 1 and Walls.hits_at(a.dungeon.data, EAST_ROCK) == Walls.hits_at(hd, EAST_ROCK),
		"the drop and the crack came in the map snapshot")
	check_eq(a.s.log_for(Config.MAP_DUNGEON).size(), dlog.size(), "A's dungeon log position = the host's")
	check(not a.s.edit_logs.has(Config.MAP_SURFACE), "A keeps no surface log any more")
	check(a.s.local.player.get_parent() == a.dungeon.entities and a.s.client.prediction.map == Config.MAP_DUNGEON
		and a.s.client.prediction.data == a.dungeon.data, "A's player and prediction are in the dungeon")
	a.s.client.draw_others()
	check(SessionReport.drawn(host_on_a), "A draws the host now")
	var av: Dictionary[String, int] = a.dungeon.cave.verify()
	check(av["mismatches"] == 0 and av["missing"] == 0 and av["overlay_mismatches"] == 0 and a.dungeon.view_hash() == r.dungeon.view_hash(),
		"A draws the host's dungeon (cave view hash equal) %s" % av)
	# Live: the host finishes the rock, A gets the edits and the break.
	r.host.run_frame(r.s.local, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0))
	var swings: int = 0
	while Walls.is_wall(hd, EAST_ROCK) and swings < 10:
		r.host.run_frame(r.s.local, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK, 0))
		_tick(r, PlayerSim.action_ticks(RigData.Anim.PICKAXE))
		swings += 1
	_deliver(r, a)
	check(not Walls.is_wall(a.dungeon.data, EAST_ROCK) and a.dungeon.data.content_hash() == hd.content_hash()
		and a.s.bad_messages == 0, "A saw the break live, same dungeon, no malformed message")
	# B joins late while both are below: on the surface it draws nobody else.
	var b: ClientRig = _client_rig(101, "herbalist")
	r.host.on_hello(101, NetProtocol.encode_hello(NetProtocol.class_index("herbalist")))
	_tick(r)
	_deliver(r, b)
	_deliver(r, a)
	if not check(b.s.active and b.s.local != null, "B joined"):
		return
	b.s.client.draw_others()
	var others_drawn: int = 0
	for slot: int in b.s.members:
		if b.s.members[slot] != b.s.local and SessionReport.drawn(b.s.members[slot]):
			others_drawn += 1
	check(b.s.client.others_on_welcome == 2 and others_drawn == 0, "B, welcomed with both below, draws nobody on the surface")
	check(b.s.members[0].map_id == Config.MAP_DUNGEON and b.s.members[a.s.local.slot].map_id == Config.MAP_DUNGEON,
		"B knows where they are")
	# B goes down: all breaks, cracks, the torch and the drop. Its map comes in 32-byte chunks over several
	# ticks, and the host mines meanwhile: those edits must reach B after its map entry (catch-up).
	var mb: NetMember = r.s.members[b.s.local.slot]
	mb.player.teleport(DungeonGen.arrival_below(entrance))
	WorldSnapshot.chunk_bytes = 1
	_send(mb, [_op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, entrance.position)] as Array[NetProtocol.InputFrame])
	_tick(r)
	var streaming: bool = r.host.streams.has(101) and r.host.streams[101].entry
	var before_edits: int = dlog.size()
	r.host.run_frame(r.s.local, _op(NetProtocol.Op.USE, Config.MAP_DUNGEON, EAST_ROCK + Vector2i(0, -1), 0))
	var waited: int = 0
	while r.host.streams.has(101) and waited < 600:
		_tick(r)
		waited += 1
	WorldSnapshot.chunk_bytes = Config.NET_SNAPSHOT_CHUNK_BYTES
	var b_entry: Dictionary = r.host.streams_done.back()
	check(streaming and dlog.size() > before_edits and roundi(_num(b_entry, "catch_up_edits")) == dlog.size() - before_edits
		and roundi(_num(b_entry, "ticks")) > 1, "the host mined while B's map streamed (%d ticks): those edits follow its map entry (%s)" % [
		roundi(_num(b_entry, "ticks")), b_entry])
	var b_msgs: Array[Array] = r.s.take_for(101)
	var order: PackedStringArray = []
	for m: Array in b_msgs:
		var kind: String = m[1]
		if kind != "state" and (order.is_empty() or order[order.size() - 1] != kind):
			order.append(kind)
	check(order.has("map") and order.find("edit") > order.find("map") and order.find("world") < order.find("map"),
		"B gets the chunks, then its map entry, then the edits (%s)" % ", ".join(order))
	for m: Array in b_msgs:
		r.s.wire.append(m)
	_deliver(r, b)
	_deliver(r, a)
	check(b.s.local.map_id == Config.MAP_DUNGEON and b.dungeon.data.content_hash() == hd.content_hash() and b.s.bad_messages == 0,
		"B went down and has the host's dungeon (everything so far, and what came during its stream)")
	b.s.client.draw_others()
	check(SessionReport.drawn(b.s.members[0]) and SessionReport.drawn(b.s.members[a.s.local.slot]), "B draws the two below")
	# An edit of the other map is malformed for B (the host never sends one).
	var stray: PackedByteArray = EditLog.encode_one(EditLog.WorldEdit.new(WorldData.Layer.VEGETATION, Vector2i(10, 10), 0),
		r.s.edit_log.size(), Config.MAP_SURFACE)
	b.s.client.on_edit(stray)
	check(b.s.bad_messages == 1 and b.s.client.wrong_map_edits == 1, "an edit of the surface while B is below: malformed, not applied")
	# A goes back up: the surface again; the dungeon it left was the host's.
	var exit: Rect2i = DungeonGen.exit_rect(hd)
	ma.player.teleport(r.dungeon.arrival_point())
	_send(ma, [_op(NetProtocol.Op.TRAVEL, Config.MAP_DUNGEON, exit.position)] as Array[NetProtocol.InputFrame])
	_tick(r, 2)
	_deliver(r, a)
	_deliver(r, b)
	check(a.s.local.map_id == Config.MAP_SURFACE and a.surface.data.content_hash() == r.surface.data.content_hash(),
		"A is back on the surface with the host's surface")
	var left: Dictionary = a.s.client.left_maps.back() if not a.s.client.left_maps.is_empty() else {}
	var left_map: int = left.get("map", -1)
	check(left_map == Config.MAP_DUNGEON and str(left.get("hash", "")) == hd.content_hash(),
		"the dungeon A left was the host's")
	_tick(r, 4)
	_deliver(r, a)
	_deliver(r, b)
	a.s.client.draw_others()
	b.s.client.draw_others()
	check(not SessionReport.drawn(a.s.members[0]) and not SessionReport.drawn(a.s.members[b.s.local.slot]), "A draws neither of the two below")
	check(not SessionReport.drawn(b.s.members[a.s.local.slot]) and SessionReport.drawn(b.s.members[0]), "B draws the host, not A")
	check_eq(SessionReport.positions_hash(a.s.members), SessionReport.positions_hash(r.s.members), "A: positions and maps = the host's")
	check_eq(SessionReport.positions_hash(b.s.members), SessionReport.positions_hash(r.s.members), "B: positions and maps = the host's")
	check(a.s.bad_messages == 0 and b.s.bad_messages == 1, "no other malformed message (A %d, B %d)" % [a.s.bad_messages, b.s.bad_messages])
	var entries: Array = r.host.streams_done
	var map_streams: int = 0
	for item: Variant in entries:
		var st: Dictionary = item
		if str(st.get("kind", "")) == "map":
			map_streams += 1
	check_eq(map_streams, 3, "three map entries streamed (A down, B down, A up)")
	note("map flow: dungeon log %d edits, entries %s" % [dlog.size(), entries])


# --- prediction and walls the host already broke ------------------------------------------------

## The host breaks three rocks east of the arrival room at tick 0; the client hears of it EDIT_AT
## ticks later (as if the edit were slow) while it walks east into them, states every 3 ticks with a
## DELAY tick delay each way. The client is corrected while it still thinks the walls are there, and
## never once their edit is in; both end on the same float32 position.
func _check_phantom_wall_prediction() -> void:
	const DELAY: int = 6
	for edit_at: int in [0, 30, 90]:
		var hd: WorldData = DungeonGen.generate(SEED)
		var cd: WorldData = DungeonGen.generate(SEED)
		var edits: Array[EditLog.WorldEdit] = []
		for x: int in range(EAST_ROCK.x, EAST_ROCK.x + 3):
			var e: EditLog.WorldEdit = EditLog.WorldEdit.new(WorldData.Layer.WALL, Vector2i(x, EAST_ROCK.y), 0)
			EditLog.apply_to_data(hd, e)
			edits.append(e)
		var start: Vector2 = _feet(EAST_STAND_LOW)
		var host: PlayerSim = PlayerSim.new()
		host.pos = start
		var client: Prediction = Prediction.new()
		client.setup(cd, start, RigData.Dir.SOUTH, 0)
		var to_host: Array[Array] = []
		var to_client: Array[Array] = []
		var last_correction: int = -1
		var corrections: int = 0
		var edit_in: int = -1
		var east: float = start.x
		for t: int in 240:
			var dir: Vector2i = Vector2i(1, 0) if t < 120 else (Vector2i(-1, 0) if t < 180 else Vector2i.ZERO)
			if t == edit_at:
				for e: EditLog.WorldEdit in edits:
					EditLog.apply_to_data(cd, e)
				edit_in = t
			var sent: NetProtocol.InputFrame = client.step_frame(NetProtocol.InputFrame.new(0, dir))
			if sent != null:
				to_host.append([t + DELAY, sent])
			while not to_host.is_empty() and _due(to_host) <= t:
				var item: Array = to_host.pop_front()
				var f: NetProtocol.InputFrame = item[1]
				host.step(hd, f.dir, f.look, -1, Vector2i.ZERO, Config.NET_TICK)
				east = maxf(east, host.pos.x)
				var st: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
				st.pos = host.pos
				st.facing = host.facing
				st.walking = host.walking
				st.ack = f.seq
				st.map = Config.MAP_DUNGEON
				if f.seq % 3 == 0 or to_host.is_empty():
					to_client.append([t + DELAY, st])
			while not to_client.is_empty() and _due(to_client) <= t:
				var item2: Array = to_client.pop_front()
				var state: NetProtocol.PlayerState = item2[1]
				var before: int = client.corrections
				client.reconcile(state)
				if client.corrections > before:
					corrections += 1
					last_correction = t
		var label: String = "walls broken, the client hears of it at tick %d" % edit_at
		check(east > start.x + 2.5 * Config.TILE, "%s: the host walked into the opened rock (%.1f px east)" % [label, east - start.x])
		check(last_correction <= edit_in + 2 * DELAY + 3, "%s: no correction after the edit is in (last at tick %d)" % [label, last_correction])
		check(corrections <= (edit_in + 2 * DELAY) / 3 + 2, "%s: bounded corrections (%d), no runaway" % [label, corrections])
		check_eq(client.pos, host.pos, "%s: the same final position" % label)
		check(Movement.can_stand(hd, host.pos), "%s: the host never stands in a wall" % label)
		if edit_at > 0:
			check(corrections > 0, "%s: the case really corrected (%d)" % [label, corrections])
		note("%s: %d corrections, last at tick %d, max error %.2f px" % [label, corrections, last_correction, client.max_error_px])


## The prediction on maps: a state on another map is not reconciled (it waits for the map entry), the
## map switch takes the host's state there and replays the frames after it, and a use aimed on the old
## map starts no action in that replay (the host refuses it: wrong map).
func _check_prediction_maps() -> void:
	var surface: WorldData = SurfaceGen.generate(SEED)
	var dungeon: WorldData = DungeonGen.generate(SEED)
	var p: Prediction = Prediction.new()
	var start: Vector2 = DungeonGen.arrival_below(SurfaceGen.entrance_rect(surface))
	p.setup(surface, start, RigData.Dir.NORTH, 0)
	check_eq(p.map, Config.MAP_SURFACE, "the prediction starts on its data's map")
	var travel: NetProtocol.InputFrame = _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, SurfaceGen.entrance_rect(surface).position)
	p.step_frame(travel)
	var use: NetProtocol.InputFrame = _op(NetProtocol.Op.USE, Config.MAP_SURFACE, Aim.feet_cell(start) + Vector2i(1, 0), 0)
	use.anim = RigData.Anim.PICKAXE
	p.step_frame(use)
	check_eq(p.sim.action, RigData.Anim.PICKAXE, "on the old map the use is predicted")
	for i: int in 3:
		p.step_frame(NetProtocol.InputFrame.new(0, Vector2i(1, 0)))
	var down: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	down.pos = DungeonGen.arrival_point(dungeon)
	down.facing = RigData.Dir.SOUTH
	down.ack = travel.seq
	down.map = Config.MAP_DUNGEON
	var pos_before: Vector2 = p.pos
	check(p.reconcile(down) < 0.0 and p.other_map == 1 and p.pos == pos_before and p.pending.size() == 5,
		"a state on another map is not reconciled (nothing dropped, nothing moved)")
	p.switch_map(dungeon, Config.MAP_DUNGEON, down)
	check(p.map == Config.MAP_DUNGEON and p.data == dungeon and p.pending.size() == 4 and p.base_seq == travel.seq,
		"the map entry switches the prediction to the dungeon from the host's state")
	check_eq(p.sim.action, -1, "the use aimed on the surface starts nothing in the replay on the dungeon")
	var replay: PlayerSim = PlayerSim.new()
	replay.pos = down.pos
	replay.facing = RigData.Dir.SOUTH
	replay.step(dungeon, Vector2i.ZERO, -1, -1, Vector2i.ZERO, Config.NET_TICK)
	for i: int in 3:
		replay.step(dungeon, Vector2i(1, 0), -1, -1, Vector2i.ZERO, Config.NET_TICK)
	check_eq(p.pos, replay.pos, "the frames after the travel are replayed on the dungeon")
	check(p.corrections == 0 and p.max_error_px == 0.0 and p.switches == 1, "a map switch is no correction")


static func _num(d: Dictionary, key: String, fallback: float = -1.0) -> float:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		return f
	if typeof(v) == TYPE_INT:
		var i: int = v
		return float(i)
	return fallback


static func _due(queue: Array[Array]) -> int:
	var t: int = queue[0][0]
	return t
