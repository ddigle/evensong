class_name SessionHost
extends RefCounted
## Host flow of the session (net/session.gd holds the shared state and the RPC table): admitting
## or refusing joiners, streaming each joiner its world snapshot and then welcoming it, world edits,
## input frames, the host tick and the state batches, dropping silent connections.
##
## A joiner's way in: hello -> admitted (roster slot, a member at its spawn slot, the other players
## hear "joined") -> the world packed at that moment (WorldSnapshot) goes out in chunks, at most
## Config.NET_SNAPSHOT_CHUNKS_PER_TICK per tick -> after the last chunk, in the same tick: welcome
## (players as they are now, the snapshot's edit log position) + every edit made since the snapshot.
## Only then does it count as a remote peer (state batches, edits, joined / left, go): everything
## on the reliable channel reaches it after the world, in order.
##
## M2b: each tick the host builds its own player's frame from its keys / mouse / bot (Player.make_frame)
## and runs it like a client's: run_frame() checks the frame's request at that frame's position and
## applies it before the frame is stepped (PlayerSim.step). Use: the slot must hold a tool, the target
## tile must be next to the feet, no action may still be playing ("busy"); a refused use is simply not
## started (the client's prediction is corrected by the next state). Select, pick up, drop and give
## also pass the request rate (NetMember tokens, "rate"); give from a client only in debug builds or
## with --test-allow-give ("give off"). World changes go out as numbered edits (apply_world_edit); a
## member whose inventory changed gets it after the tick (ack = its last handled frame). Members are
## handled in slot order, frames in seq order, edits applied at once: two players picking up the same
## thing in one tick -> the lower slot gets it, the other finds nothing.
##
## M3a: a USE of a placeable (the torch) places it on the target tile (WorldItems.place, request rate
## like pick up) instead of starting an action; a pickaxe swing that lands (Mining.impact_tick) mines
## (items/mining.gd): on the surface there are no walls, so nothing changes there.
##
## M3b (maps): every member is on a map (NetMember.map_id) and every request runs on that map's data.
## A request aimed at a tile names the map it was aimed on; on any other map it is refused ("wrong
## map": frames a client made before it heard that it moved, or a forged id). TRAVEL (F on the
## entrance / the exit stairs): request rate like pick up, refused while the member's last map entry
## is still streaming ("still loading"), then WorldItems.travel (in reach, a way there). Applied at
## once: the member moves to the other map's arrival point (its Player node into that map's world),
## the frame then steps there. A client gets that map like a joiner gets the world: a stream of the
## map's snapshot (WorldSnapshot, the same chunks and rate), then the map entry (its own state there),
## then that map's edits made since the snapshot. Edits are numbered per map and go only to the
## members on that map whose entry is complete (peers_on). Mining is checked twice: the use (tool in
## the slot, the target next to the feet, not busy: one swing at a time, so the action's length is
## its rate) and the swing that lands (a wall there whose hardness is within the class's cap). Two
## swings landing on one tile in one tick: members in slot order, edits at once, so the lower slot's
## breaks it and the other one finds no wall.
##
## M4b (combat): every member (the host's own player too) gets its class weapon when it joins
## (Config.START_WEAPON_SLOT). One Arena per map (combat/arena.gd), stepped each tick after every member's
## frames when someone is on that map, like offline. Frames carry the dash, F held and a USE's aim; the
## host checks them where it checks the rest: a request while down or dead is refused ("down"), a use while
## dashing or staggered is "busy". On a weapon's hit frame (Combat.impact_tick) the host resolves the
## attack from its own state of that player at that tick (Arena.player_attack: the reach, the arc and the
## walls measured from where the host has the player, the aim the frame carried; the pickaxe aimed at a
## wall mines instead, M4a's rule). Hits on players, revives (F held, Arena), deaths (the bag:
## WorldItems.death_drop, world edits) and respawns (PlayerSim.respawn at the member's spawn slot on the
## surface; from the dungeon the member is moved there and its client is sent the surface) all happen
## here, on host time, with no rewind (README "M4b 판정"). M4-fix: while a member's timers run its frames
## are held to host time (run_client_frames: never ahead of it; more than Config.NET_HOST_STEPS_AFTER_TICKS
## behind, the host steps it itself), so a client can neither hold its down time, its invulnerability or its
## respawn by not sending (or by sending a frame now and then), nor cut its stagger or its dash cooldown
## short with saved-up frames. A map whose last player leaves is emptied (Arena.on_emptied: attacks stop
## without their knife, shots in the air are gone).
## What clients get: the vitals in every state batch (NetProtocol's vitals block), each map's enemies as
## an enemy batch to the members on that map (peers_on) every Config.NET_STATE_HZ tick while they change,
## at once on a tick an attack starts (Config.NET_ENEMY_SEND_ON_ATTACK), a reliable keyframe when they stop,
## and a keyframe right after a welcome or a map entry (with the shots in flight); the shot events of each
## map (let go, stopped) at the end of the tick.
##
## M6b (potions and crafting): a USE of a potion is a drink (the host checks it like a tool's use: in reach,
## not busy, and Potions.drink_refusal: not at full HP), THROW (the skill key 1) a throw (Potions.throw_refusal:
## a potion, the herbalist's; in reach, not busy; the point it goes to rides along and is clamped to
## Config.THROW_RANGE_PX from where the host has the thrower when it leaves the hand). On the effect / release
## frame the host runs Potions.release (the offline rule): the potion is used, the drink works, the bottle goes
## into the map's arena, whose thrown / broke events go out with the shot events. CRAFT (the crafting panel):
## request rate, then a station within reach of where the host has the player on that map
## (Crafting.station_near) and Crafting.craft on its inventory (class, grades, inputs, room); the owner gets its
## inventory. The alchemy table is placed like a torch (WorldItems.place with the bodies on that map). The
## effects travel in the vitals block (players) and the enemy batches (a heretic's poison); a late client and a
## map entry get the bottles in the air and the splashes being shown as events after the enemy keyframe.

## M4b: why a request is refused while its player is down or dead.
const WHY_DOWN: String = "down"


## A joiner whose world is still being sent, or (M3b, `entry`) a member being sent the map it went to.
class Stream:
	extends RefCounted
	var peer: int = 0
	var slot: int = 0
	## M3b: the map being sent, and whether this is a map entry (true) or the join (false).
	var map: int = Config.MAP_SURFACE
	var entry: bool = false
	var snapshot: WorldSnapshot.Packed
	var sender: WorldSnapshot.Sender
	## Edit log position when the snapshot was taken.
	var edit_position: int = 0
	var started_ms: int = 0
	## Host ticks that sent chunks to this joiner.
	var ticks: int = 0


var s: NetSession
var roster: Roster
## Batch / keyframe / quiet decisions.
var broadcast: StateBroadcast = StateBroadcast.new()
var refusals: Dictionary[String, int] = {}
## Joiners still receiving their world, and (M3b) members still receiving the map they went to, by peer.
var streams: Dictionary[int, Stream] = {}
var snapshots_sent: int = 0
## M3b: map entries completed, travels done.
var map_entries: int = 0
var travels: int = 0
var snapshot_bytes_sent: int = 0
## Every finished stream, for the test results: slot, chunks, ticks, edit position, catch-up edits
## (the last Config.NET_STREAM_RECORDS_MAX).
var streams_done: Array[Dictionary] = []
## Ticks whose traffic still counts as joining (NetStats bucket "joining", not "<moving>/<players>"):
## the tick that sent chunks or a welcome and the next two, since ENet sends at the end of the frame
## and the bytes are counted on the next tick.
var joining_ticks: int = 0
## M3b: the same for map entries (NetStats bucket "entering").
var entering_ticks: int = 0

var connected_ms: Dictionary[int, int] = {}
var refused_ms: Dictionary[int, int] = {}
## Gatherables picked and drops picked up (whole or in part) in this session, for the results.
var pickups: int = 0
var _last_take_usec: int = 0
## Something a request changed this tick (a selection shows in the state batch: not quiet).
var _changed: bool = false
## Remote frames handled this tick (each moves the acknowledgement in the next state batch).
var _frames: int = 0
## M4b: the arenas, their views and their enemy broadcasts by map; deaths so far (the bag's seed);
## counters for the results.
var arenas: Dictionary[int, Arena] = {}
var views: Dictionary[int, CombatView] = {}
var enemy_casts: Dictionary[int, StateBroadcast] = {}
var deaths: int = 0
var enemy_batches_sent: int = 0
var enemy_keyframes_sent: int = 0
var enemy_urgent_sends: int = 0
var shot_messages_sent: int = 0


func _init(p_session: NetSession) -> void:
	s = p_session
	roster = Roster.new(s.options.max_players)


func on_opened() -> void:
	var slot: int = roster.admit(1, s.local_class())
	s.local = s.add_member(slot, 1, s.local_class(), s.world.spawn_point(slot), Config.SPAWN_FACING)
	s.local.player.potions_on = true  # M6b: the host's own player drinks and throws (its frames go through run_frame)
	_equip(s.local)
	_setup_combat()
	s.active = true
	_last_take_usec = Time.get_ticks_usec()
	s.log_event("hosting", "port=%d slot=%d class=%s" % [s.options.port, slot, s.local.class_id])
	s.local_player_ready.emit(s.local.player)
	s.bots.mark("ready")
	if s.options.net_start <= 0:
		s.bots.start_bots()


func on_peer_connected(peer_id: int) -> void:
	connected_ms[peer_id] = Time.get_ticks_msec()


func on_peer_disconnected(peer_id: int) -> void:
	connected_ms.erase(peer_id)
	refused_ms.erase(peer_id)
	streams.erase(peer_id)
	if not roster.has(peer_id):
		return
	var slot: int = roster.release(peer_id)
	broadcast.note_activity(s.tick)
	s.bots.note_gone(peer_id)  # a player who left will not finish a bot any more
	s.remove_member(slot)
	if not s.bots.finishing:  # after "finish" the clients' lists are frozen and they are leaving too
		var payload: PackedByteArray = PackedByteArray([slot])
		for peer: int in remote_peers():
			s.send_left(peer, payload)
	s.log_event("left", "peer=%d slot=%d players=%d" % [peer_id, slot, roster.count()])


## A joiner introduces itself.
func on_hello(peer_id: int, payload: PackedByteArray) -> void:
	if not s.active or s.over:
		return
	if roster.has(peer_id) or refused_ms.has(peer_id):
		s.bad_messages += 1
		return
	connected_ms.erase(peer_id)
	var hello: NetProtocol.Hello = NetProtocol.decode_hello(payload)
	var class_id: String = NetProtocol.class_name_of(hello.class_index)
	var reason: NetProtocol.Refusal = NetProtocol.Refusal.NONE
	if not hello.ok:
		reason = NetProtocol.Refusal.BAD_HELLO
	elif hello.version != NetProtocol.VERSION:
		reason = NetProtocol.Refusal.VERSION
	else:
		reason = roster.refusal_for(class_id)
	if reason != NetProtocol.Refusal.NONE:
		_refuse(peer_id, reason)
		return
	var slot: int = roster.admit(peer_id, class_id)
	var m: NetMember = s.add_member(slot, peer_id, class_id, s.world.spawn_point(slot), Config.SPAWN_FACING)
	m.gate = InputGate.new()
	_equip(m)
	broadcast.note_activity(s.tick)
	var stream: Stream = _stream(peer_id, slot, Config.MAP_SURFACE, false)
	streams[peer_id] = stream
	var joined: PackedByteArray = NetProtocol.encode_info(m.info())
	for peer: int in remote_peers():
		s.send_joined(peer, joined)
	s.log_event("joined", "peer=%d slot=%d class=%s players=%d world_bytes=%d raw=%d chunks=%d encode_us=%d" % [
		peer_id, slot, class_id, roster.count(), stream.snapshot.bytes.size(), stream.snapshot.raw_size,
		stream.snapshot.chunk_count(), stream.snapshot.encode_usec])


func _refuse(peer_id: int, reason: NetProtocol.Refusal) -> void:
	var name: String = NetProtocol.REFUSAL_NAMES[reason]
	var seen: int = refusals.get(name, 0)
	refusals[name] = seen + 1
	refused_ms[peer_id] = Time.get_ticks_msec()
	# The refused client disconnects itself after reading this (disconnect_peer() here would drop
	# the message unsent); the host only cuts it off after NET_REFUSE_GRACE_SEC.
	s.send_refused(peer_id, NetProtocol.encode_refusal(reason))
	s.log_event("refused", "peer=%d reason=%s players=%d" % [peer_id, name, roster.count()])


## A stream of map `map`'s world (packed now, with that map's log position) to `peer`.
func _stream(peer_id: int, slot: int, map: int, entry: bool) -> Stream:
	var stream: Stream = Stream.new()
	stream.peer = peer_id
	stream.slot = slot
	stream.map = map
	stream.entry = entry
	stream.snapshot = WorldSnapshot.encode(s.world_of(map).data)
	stream.sender = WorldSnapshot.Sender.new(stream.snapshot)
	stream.edit_position = s.log_for(map).size()
	stream.started_ms = Time.get_ticks_msec()
	return stream


## Sends every joiner (and, M3b, every member entering a map) its next chunks; a joiner whose last
## chunk went out is welcomed, an entering member gets its map entry.
func _pump_streams() -> void:
	for peer: int in streams.keys():
		var st: Stream = streams[peer]
		if not s.transport.can_send_to(peer):
			continue
		var chunks: Array[PackedByteArray] = st.sender.take(Config.NET_SNAPSHOT_CHUNKS_PER_TICK)
		for chunk: PackedByteArray in chunks:
			s.send_world(peer, chunk)
			snapshot_bytes_sent += chunk.size()
		if not chunks.is_empty():
			st.ticks += 1
		if st.entry:
			entering_ticks = 3
		else:
			joining_ticks = 3
		if st.sender.done():
			streams.erase(peer)
			if st.entry:
				_enter_map(st)
			else:
				_welcome(st)


## The edits of the stream's map made since its snapshot, to its peer (after the welcome / map entry).
func _catch_up(st: Stream) -> int:
	var log: EditLog = s.log_for(st.map)
	var n: int = 0
	for index: int in range(st.edit_position, log.size()):
		s.send_edit(st.peer, EditLog.encode_one(log.edit_at(index), index, st.map))
		n += 1
	return n


func _record_stream(st: Stream, catch_up: int) -> void:
	snapshots_sent += 1
	streams_done.append({"slot": st.slot, "chunks": st.snapshot.chunk_count(), "bytes": st.snapshot.bytes.size(),
		"ticks": st.ticks, "edit_position": st.edit_position, "catch_up_edits": catch_up,
		"kind": "map" if st.entry else "join", "map": st.map, "raw": st.snapshot.raw_size,
		"ms": Time.get_ticks_msec() - st.started_ms})
	if streams_done.size() > Config.NET_STREAM_RECORDS_MAX:
		streams_done.pop_front()  # test results only (M3-fix: TRAVEL has no cooldown, so no unbounded list)


func _welcome(st: Stream) -> void:
	s.send_welcome(st.peer, NetProtocol.encode_welcome(_welcome_for(st)))
	var catch_up: int = _catch_up(st)
	send_combat_snapshot(st.peer, st.map)
	_record_stream(st, catch_up)
	s.log_event("welcomed", "peer=%d slot=%d chunks=%d bytes=%d ticks=%d edit_position=%d catch_up_edits=%d stream_ms=%d" % [
		st.peer, st.slot, st.snapshot.chunk_count(), st.snapshot.bytes.size(), st.ticks, st.edit_position, catch_up,
		Time.get_ticks_msec() - st.started_ms])
	if not s.bots.bots_started and s.options.net_start > 0 and remote_peers().size() >= s.options.net_start:
		s.bots.start_bots()


## M3b: the member of stream `st` has its map's chunks: the map entry (with its state there), then the
## map's edits made since.
func _enter_map(st: Stream) -> void:
	if not s.members.has(st.slot) or s.members[st.slot].peer_id != st.peer or s.members[st.slot].map_id != st.map:
		return  # gone (or moved on, which TRAVEL refuses while streaming)
	var m: NetMember = s.members[st.slot]
	var e: NetProtocol.MapEntry = NetProtocol.MapEntry.new()
	e.map = st.map
	e.edit_position = st.edit_position
	e.raw_size = st.snapshot.raw_size
	e.packed_size = st.snapshot.bytes.size()
	e.chunk_count = st.snapshot.chunk_count()
	e.packed_md5 = st.snapshot.packed_md5
	e.world_md5 = st.snapshot.world_md5
	e.state = m.state()
	s.send_map_entry(st.peer, NetProtocol.encode_map_entry(e))
	var catch_up: int = _catch_up(st)
	send_combat_snapshot(st.peer, st.map)
	map_entries += 1
	_record_stream(st, catch_up)
	s.log_event("entered", "peer=%d slot=%d map=%s chunks=%d bytes=%d raw=%d ticks=%d edit_position=%d catch_up_edits=%d stream_ms=%d" % [
		st.peer, st.slot, Config.MAP_NAMES[st.map], st.snapshot.chunk_count(), st.snapshot.bytes.size(), st.snapshot.raw_size,
		st.ticks, st.edit_position, catch_up, Time.get_ticks_msec() - st.started_ms])


func _welcome_for(st: Stream) -> NetProtocol.Welcome:
	var w: NetProtocol.Welcome = NetProtocol.Welcome.new()
	w.slot = st.slot
	w.max_players = roster.max_players
	w.tick = s.tick
	w.bots_started = s.bots.bots_started
	w.edit_position = st.edit_position
	w.raw_size = st.snapshot.raw_size
	w.packed_size = st.snapshot.bytes.size()
	w.chunk_count = st.snapshot.chunk_count()
	w.packed_md5 = st.snapshot.packed_md5
	w.world_md5 = st.snapshot.world_md5
	w.generator_md5 = s.generator_hash.hex_decode()
	for slot: int in s.slots():
		w.players.append(s.members[slot].info())
	return w


# --- world edits -----------------------------------------------------------------------------

## The debug floor edit (bot "edit"): checks (EditLog.check), applies, logs and sends. Returns "" or
## why it was refused.
func edit(world_edit: EditLog.WorldEdit) -> String:
	var why: String = EditLog.check(s.world.data, world_edit)
	if not why.is_empty():
		s.log_event("edit_refused", "%s: %s" % [world_edit.describe(), why])
		return why
	apply_world_edit(world_edit)
	return ""


## Applies, logs and sends an edit the rules already allowed (debug edit, or a request's outcome) on
## map `map` (M3b: numbered in that map's log, sent to the members on that map).
func apply_world_edit(world_edit: EditLog.WorldEdit, map: int = Config.MAP_SURFACE) -> void:
	var w: GameWorld = s.world_of(map)
	var log: EditLog = s.log_for(map)
	w.apply_edit(world_edit)
	var payload: PackedByteArray = EditLog.encode_one(world_edit, log.size(), map)
	log.append(world_edit)
	for peer: int in peers_on(map):
		s.send_edit(peer, payload)
	s.log_event("edit", "%s index=%d map=%d world=%s" % [world_edit.describe(), log.size() - 1, map,
		w.data.content_hash().left(12)])


# --- requests (M2b) --------------------------------------------------------------------------

## Runs one input frame of member `m`: its request first (checked at this frame's position), then the
## step. The frame's `anim` is decided here, whatever the sender resolved.
func run_frame(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	frame.anim = -1
	frame.item = &""
	if m.gate != null:
		_frames += 1
	if frame.op != NetProtocol.Op.NONE:
		s.request_ticks = 3
	if NetProtocol.op_has_map(frame.op) and frame.map != m.map_id:
		_refuse_op(m, frame, WorldItems.WHY_WRONG_MAP)
	elif NetProtocol.op_has_map(frame.op) and not p.vitals.alive():
		_refuse_op(m, frame, WHY_DOWN)  # M4b: nothing but F held (give up) and Q / E while down or dead
	elif frame.op == NetProtocol.Op.TRAVEL:
		_travel(m, frame)
	elif frame.op == NetProtocol.Op.USE and WorldItems.placeable_in(p.inventory, frame.slot) != WorldData.PLACEABLE_NONE:
		_place(m, frame)
	elif frame.op == NetProtocol.Op.USE and _potion_in(p, frame.slot):
		_drink(m, frame)
	elif frame.op == NetProtocol.Op.USE:
		var why: Array[String] = []
		var anim: int = WorldItems.use_action(p.sim_position, p.inventory, frame.slot, frame.cell, why)
		if anim >= 0 and busy(p):
			anim = -1
			why.append(WHY_BUSY)
		if anim >= 0:
			frame.anim = anim
			frame.item = p.inventory.stack_at(frame.slot).id
			m.count_done("use")
		else:
			_refuse_op(m, frame, why[0])
	elif frame.op == NetProtocol.Op.THROW:
		_throw(m, frame)
	elif frame.op == NetProtocol.Op.CRAFT:
		_craft(m, frame)
	elif frame.op != NetProtocol.Op.NONE:
		_run_op(m, frame)
	var events: int = p.step_frame(frame, Config.NET_TICK)
	if p.action_anim >= 0 and p.action_tick == 0:
		m.count_action(p.action_anim)
		s.log_event("action", "slot=%d item=%s action=%s target=%d,%d aim=%d" % [m.slot, p.action_item,
			RigData.ANIM_NAMES[p.action_anim], p.action_cell.x, p.action_cell.y, p.action_aim])
	if p.action_anim >= 0 and p.action_tick == Player.impact_tick_of(p.action_item, p.action_anim):
		if Potions.is_potion(p.action_item):
			_potion(m)  # M6b: the drink's effect frame, the throw's release frame
		else:
			_impact(m)
	if events & PlayerSim.DASHED:
		m.count_combat("dashes")
	if events & PlayerSim.DIED:
		_died(m)
	if events & PlayerSim.RESPAWN:
		_respawn(m)


## M4b: member `m`'s action reached its hit frame (Combat.impact_tick). The pickaxe aimed at a wall or a
## wall's face mines (M3b's _mine); any other weapon swing is an attack from the host's state of the
## player now (M4a's pickaxe rule: never both; a pickaxe swing that is no mining swing counts as
## "no wall", as in M3b).
func _impact(m: NetMember) -> void:
	var p: Player = m.player
	var item: StringName = p.action_item
	if item == Mining.PICKAXE and p.action_anim == RigData.Anim.PICKAXE:
		if Combat.is_mining_swing(p.data, item, p.action_cell):
			_mine(m)
			return
		var n: int = m.swings_missed.get(Mining.WHY_NO_WALL, 0)
		m.swings_missed[Mining.WHY_NO_WALL] = n + 1
	if Combat.attack_for(item) != null:
		_attack(m, item)


## M4b: member `m`'s weapon lands on its map's arena (host state, host time: no rewind).
func _attack(m: NetMember, item: StringName) -> void:
	var a: Arena = arenas.get(m.map_id, null)
	if a == null:
		return
	m.count_combat("attacks")
	var edits: Array[EditLog.WorldEdit] = a.player_attack(m.player, item, m.player.action_aim, players_on(m.map_id), m.slot)
	for e: EditLog.WorldEdit in edits:
		apply_world_edit(e, m.map_id)
		_changed = true
	if not edits.is_empty():
		s.log_event("shrine_broken", "slot=%d map=%d at=%d,%d" % [m.slot, m.map_id, edits[0].cell.x, edits[0].cell.y])


## M4b: member `m` died (down time over, or it gave up): part of its materials and consumables fall in a
## bag on its tile (● gameplay-design §2.6, WorldItems.death_drop: world edits on its map, so every client
## there and every later one gets it), its owner gets its inventory.
func _died(m: NetMember) -> void:
	var p: Player = m.player
	deaths += 1
	m.count_combat("died")
	var o: WorldItems.Outcome = WorldItems.death_drop(p.data, p.sim_position, p.inventory, Config.DEATH_DROP_RULE,
		hash([p.data.world_seed, deaths]))
	for e: EditLog.WorldEdit in o.edits:
		apply_world_edit(e, m.map_id)
	if o.ok():
		m.inventory_dirty = true
		_changed = true
	s.log_event("died", "slot=%d map=%s bag=%s items=%d" % [m.slot, Config.MAP_NAMES[m.map_id],
		"%d,%d" % [o.edits[0].cell.x, o.edits[0].cell.y] if o.ok() else "none (%s)" % o.why, o.count])


## M4b: member `m`'s respawn time is up: back at its spawn slot on the surface (● §2.6 "부활 지점: 제단"),
## PlayerSim.respawn (the prediction does the same on the same frame when the client is on the surface).
## From the dungeon it is moved to the surface first (its client is sent the surface, like a TRAVEL);
## while its last map is still streaming the respawn waits (respawn_pending).
func _respawn(m: NetMember) -> void:
	if m.map_id != Config.MAP_SURFACE:
		if streams.has(m.peer_id):
			m.respawn_pending = true
			return
		move_to_map(m, Config.MAP_SURFACE)
	m.respawn_pending = false
	m.player.respawn_at(s.world.data, s.world.spawn_point(m.slot))
	m.count_combat("respawned")
	broadcast.note_activity(s.tick)
	_changed = true
	s.log_event("respawn", "slot=%d feet=%d,%d" % [m.slot, roundi(m.player.sim_position.x), roundi(m.player.sim_position.y)])


## M3a: the swing of member `m` lands on its action's target tile (M3b: on its map; refused swings
## are counted by reason: "no wall", "too hard"; Mining.strike's "out of reach" cannot happen while
## Config.ACTION_LOCKS_MOVEMENT holds the feet still, see there).
func _mine(m: NetMember) -> void:
	var p: Player = m.player
	var r: Mining.Result = Mining.strike(p.data, p.sim_position, m.class_id, p.inventory, p.action_cell)
	if not r.ok():
		var n: int = m.swings_missed.get(r.why, 0)
		m.swings_missed[r.why] = n + 1
		return
	for e: EditLog.WorldEdit in r.edits:
		apply_world_edit(e, m.map_id)
	if not r.gained.is_empty():
		m.inventory_dirty = true
	_changed = true
	m.count_done("mine")
	s.log_event("mine", "slot=%d map=%d tick=%d at=%d,%d %s" % [m.slot, m.map_id, s.tick, p.action_cell.x, p.action_cell.y,
		r.describe()])


## M3b: TRAVEL (F on the entrance / the exit stairs): rate, not while the last map entry streams, then
## WorldItems.travel on the member's map; the member moves to the map it leads to.
func _travel(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	if not m.take_op():
		_refuse_op(m, frame, "rate")
		return
	if streams.has(m.peer_id):
		_refuse_op(m, frame, WorldItems.WHY_LOADING)
		return
	var why: Array[String] = []
	var to: int = WorldItems.travel(p.data, p.sim_position, frame.cell, why)
	if to < 0 or s.world_of(to) == null:
		_refuse_op(m, frame, why[0] if not why.is_empty() else WorldItems.WHY_NOT_PORTAL)
		return
	var from: int = m.map_id
	move_to_map(m, to)
	m.count_done("travel")
	travels += 1
	_changed = true
	s.log_event("travel", "slot=%d from=%s to=%s at=%d,%d feet=%d,%d" % [m.slot, Config.MAP_NAMES[from], Config.MAP_NAMES[to],
		frame.cell.x, frame.cell.y, roundi(p.sim_position.x), roundi(p.sim_position.y)])


## M3b: member `m` goes to map `to`: its arrival point there (facing south, any action stopped), its
## Player node into that map's world; a client is sent the map (a stream, then the map entry), the
## host's own player shows the map at once (local_map_changed).
func move_to_map(m: NetMember, to: int) -> void:
	var w: GameWorld = s.world_of(to)
	m.map_id = to
	NetSession.move_player_node(m, w)
	m.player.set_world(w.data, w.arrival_point())
	broadcast.note_activity(s.tick)
	if m == s.local:
		s.local_map_changed.emit(to)
	elif m.gate != null:
		streams[m.peer_id] = _stream(m.peer_id, m.slot, to, true)


## M3a: a USE of a placeable item: rate, then WorldItems.place. M6b: the alchemy table too (M6a refused it in a
## session), its footprint clear of every body on that map (the other players, the heretics), like offline.
func _place(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	if not m.take_op():
		_refuse_op(m, frame, "rate")
		return
	var bodies: Array[Vector2] = []
	for other: Player in players_on(m.map_id):
		if other != p:
			bodies.append(other.sim_position)
	var a: Arena = arenas.get(m.map_id, null)
	if a != null:
		for h: HereticSim in a.heretics:
			bodies.append(h.pos)
	var o: WorldItems.Outcome = WorldItems.place(p.data, p.sim_position, p.inventory, frame.slot, frame.cell, bodies)
	if not o.ok():
		_refuse_op(m, frame, o.why)
		return
	for e: EditLog.WorldEdit in o.edits:
		apply_world_edit(e, m.map_id)
	m.count_done("place")
	m.inventory_dirty = true
	_changed = true
	s.log_event("place", "slot=%d map=%d item=%s at=%d,%d" % [m.slot, m.map_id, o.item, frame.cell.x, frame.cell.y])


## M4b / M6b: why a use, a drink or a throw is refused while an action still plays, a dash or a stagger runs.
const WHY_BUSY: String = "busy"


## The player cannot start an action in its next frame (one plays on, it dashes or it is staggered).
static func busy(p: Player) -> bool:
	return p.to_sim().busy_next() or p.vitals.dashing() or p.vitals.staggered()


## M6b: hotbar slot `slot` of `p` holds a potion.
static func _potion_in(p: Player, slot: int) -> bool:
	if slot < 0 or slot >= p.inventory.hotbar_size:
		return false
	var st: ItemStack = p.inventory.stack_at(slot)
	return st != null and Potions.is_potion(st.id)


## M6b: a USE of a potion = a drink (Config.DRINK_ANIM): in reach (the target tile only sets the facing, as for a
## tool), not busy, and drinkable now (Potions.drink_refusal on the host's vitals: not at full HP ...).
func _drink(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	var st: ItemStack = p.inventory.stack_at(frame.slot)
	var why: String = Potions.drink_refusal(st.id, st.grade, p.vitals)
	if why.is_empty() and not WorldItems.in_reach(p.sim_position, frame.cell):
		why = WorldItems.WHY_REACH
	if why.is_empty() and busy(p):
		why = WHY_BUSY
	if not why.is_empty():
		_refuse_op(m, frame, why)
		return
	frame.anim = Config.DRINK_ANIM
	frame.item = st.id
	m.count_done("drink")


## M6b: THROW (the skill key 1): the selected potion, the thrower's class (Potions.throw_refusal), in reach (the
## target tile sets the facing), not busy. The point thrown at rides on the frame (Player.action_target); the
## arena clamps it to Config.THROW_RANGE_PX from where the host has the thrower when it leaves the hand.
func _throw(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	var st: ItemStack = p.inventory.stack_at(frame.slot) if frame.slot < p.inventory.hotbar_size else null
	var why: String = Potions.throw_refusal(m.class_id, st)
	if why.is_empty() and not WorldItems.in_reach(p.sim_position, frame.cell):
		why = WorldItems.WHY_REACH
	if why.is_empty() and busy(p):
		why = WHY_BUSY
	if not why.is_empty():
		_refuse_op(m, frame, why)
		return
	frame.anim = RigData.Anim.THROW
	frame.item = st.id
	m.count_done("throw")


## M6b: member `m`'s potion reaches its effect / release frame: Potions.release (the offline rule) on the host's
## state of it; the potion used shows in its inventory, a throw's bottle flies in its map's arena (its events go
## to that map's clients).
func _potion(m: NetMember) -> void:
	var p: Player = m.player
	var item: StringName = p.action_item
	var a: Arena = arenas.get(m.map_id, null)
	var r: Potions.Released = Potions.release(p, item, p.action_anim, a, m.slot)
	if not r.ok():
		var n: int = m.count_refused(r.why)
		s.log_event("potion_refused", "slot=%d %s item=%s: %s n=%d" % [m.slot, "throw" if r.thrown else "drink", item,
			r.why, n])
		return
	m.inventory_dirty = true
	_changed = true
	if r.thrown:
		m.count_combat("throws")
		s.log_event("throw", "slot=%d map=%d item=%s grade=%s id=%d from=%d,%d to=%d,%d" % [m.slot, m.map_id, item,
			ItemDB.GRADE_NAMES[r.grade], r.flask.id, roundi(r.flask.origin.x), roundi(r.flask.origin.y),
			roundi(r.flask.target.x), roundi(r.flask.target.y)])
		return
	m.count_combat("drinks")
	s.log_event("drink", "slot=%d map=%d item=%s grade=%s hp=%d buff=%d poison=%d%s" % [m.slot, m.map_id, item,
		ItemDB.GRADE_NAMES[r.grade], p.vitals.hp, p.vitals.buff_ticks, p.vitals.poison_ticks,
		"" if r.events != 0 else " (no effect)"])


## M6b: CRAFT: request rate (like a pick up), a recipe that exists, a station of its kind within
## Config.STATION_REACH_TILES of where the host has the player on its map (Crafting.station_near), then
## Crafting.craft on the player's inventory (unlocked, the class, the inputs of the recipe's grade, room: all or
## nothing). The owner gets its inventory.
func _craft(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	if not m.take_op():
		_refuse_op(m, frame, "rate")
		return
	var r: Crafting.Recipe = Crafting.recipe_at(frame.recipe)
	if r == null:
		_refuse_op(m, frame, Crafting.WHY_BAD_RECIPE)
		return
	var at: Crafting.StationAt = Crafting.station_near(p.data, p.sim_position)
	if at == null or at.kind != r.station:
		_refuse_op(m, frame, Crafting.WHY_NO_STATION)
		return
	var o: Crafting.Outcome = Crafting.craft(r, m.class_id, p.inventory)
	if not o.ok():
		_refuse_op(m, frame, o.why)
		return
	m.count_done("craft")
	m.inventory_dirty = true
	_changed = true
	s.log_event("craft", "slot=%d map=%d recipe=%s item=%s count=%d grade=%s station=%d,%d" % [m.slot, m.map_id, r.id,
		o.item, o.count, ItemDB.GRADE_NAMES[o.grade], at.rect.position.x, at.rect.position.y])


## Select, then pick up, drop, give: rate, then the rules (items/world_items.gd).
func _run_op(m: NetMember, frame: NetProtocol.InputFrame) -> void:
	var p: Player = m.player
	if frame.op == NetProtocol.Op.SELECT:
		# Not rate limited: at most one per frame, frames are limited by the input gate, and it changes
		# no world state (only the held item in the state batches). The client predicted it, so an
		# accepted one sends nothing back; a refused one sends the owner its inventory (_refuse_op).
		if frame.slot < 0 or frame.slot >= p.inventory.hotbar_size:
			_refuse_op(m, frame, WorldItems.WHY_BAD_SLOT)
			return
		p.inventory.select(frame.slot)
		m.count_done("select")
		_changed = true
		return
	if not m.take_op():
		_refuse_op(m, frame, "rate")
		return
	var o: WorldItems.Outcome = null
	match frame.op:
		NetProtocol.Op.PICKUP:
			o = WorldItems.pickup(p.data, p.sim_position, m.class_id, p.inventory, frame.cell)
		NetProtocol.Op.DROP:
			# Debug F7: a client's only where its give would be honoured (an exported release refuses
			# it, so a client cannot grow the edit log by dropping and picking up in a loop).
			if m.peer_id != 1 and not s.give_allowed:
				_refuse_op(m, frame, "drop off")
				return
			var slot: int = frame.slot if frame.slot >= 0 else p.inventory.selected
			o = WorldItems.drop(p.data, p.sim_position, p.inventory, slot, frame.count, frame.cell)
		NetProtocol.Op.GIVE:
			if m.peer_id != 1 and not s.give_allowed:
				_refuse_op(m, frame, "give off")
				return
			o = WorldItems.give(p.inventory, frame.item_index, frame.count, frame.grade)
	if o == null:
		_refuse_op(m, frame, "unknown request")
		return
	if not o.ok():
		_refuse_op(m, frame, o.why)
		return
	for e: EditLog.WorldEdit in o.edits:
		apply_world_edit(e, m.map_id)
	var op_name: String = NetProtocol.OP_NAMES[frame.op]
	m.count_done(op_name)
	m.inventory_dirty = true
	_changed = true
	if frame.op == NetProtocol.Op.PICKUP:
		pickups += 1
	s.log_event(op_name, "slot=%d item=%s count=%d grade=%s at=%d,%d" % [m.slot, o.item, o.count,
		ItemDB.GRADE_NAMES[clampi(o.grade, 0, 2)], frame.cell.x, frame.cell.y])


## Counts a refused request. A client predicted its hotbar selection, so a refused select sends the
## owner its inventory (the host's selection and ack). The log line is thinned per member and reason
## (the first Config.NET_REFUSAL_LOG_FIRST, then every NET_REFUSAL_LOG_EVERY-th, with the count), so a
## client sending a refused request every frame cannot flood the host log; the counters see them all.
func _refuse_op(m: NetMember, frame: NetProtocol.InputFrame, why: String) -> void:
	var n: int = m.count_refused(why)
	if frame.op == NetProtocol.Op.SELECT and m.gate != null:
		m.inventory_dirty = true
	if n <= Config.NET_REFUSAL_LOG_FIRST or n % Config.NET_REFUSAL_LOG_EVERY == 0:
		s.log_event("request_refused", "slot=%d %s: %s n=%d" % [m.slot, frame.describe_op(), why, n])


## The host's own frame for this tick (keys / mouse / bot) with one waiting local request attached.
func _local_frame(action: NetBot.Action) -> NetProtocol.InputFrame:
	var p: Player = s.local.player
	var f: NetProtocol.InputFrame = p.make_frame(action.dir, action.mouse, action.aiming, action.use_pressed,
		action.use_held, action.dash, action.interact, action.skill)
	attach_local_op(s, p, f, action)
	return f


## Puts a request on frame `f` unless it already carries a use: the bot's request of this tick at
## once (a script that spams requests really sends them every frame), else the next waiting one from
## the keys, paced like the host's rate (NetSession.take_local_token; a select is not rate limited and
## goes on the next free frame) so key presses and --give normally are not refused as "rate" (they
## still can be when the host gets them bunched, after a lost packet or a host hitch: README).
## PICKUP / DROP aim at the target tile; a DROP without a slot drops the selected one. A client
## applies a hotbar selection at once (predicted). M3b: F (PICKUP) on an entrance or stairs tile of the
## player's map is a TRAVEL there, and every tile request names the map the player is on.
static func attach_local_op(session: NetSession, p: Player, f: NetProtocol.InputFrame, action: NetBot.Action) -> void:
	var q: NetProtocol.InputFrame = null
	if action.op != null:
		if f.op != NetProtocol.Op.NONE:
			session.queue_op(action.op)
			return
		q = action.op
		if session.role == NetSession.Role.CLIENT and q.op == NetProtocol.Op.SELECT:
			p.inventory.select(q.slot)
	elif f.op == NetProtocol.Op.NONE and not session.local_ops.is_empty() \
			and (session.local_ops[0].op == NetProtocol.Op.SELECT or session.take_local_token()):
		q = session.local_ops.pop_front()
	if q == null:
		return
	f.op = q.op
	f.slot = q.slot
	f.count = q.count
	f.item_index = q.item_index
	f.grade = q.grade
	f.cell = q.cell
	f.recipe = q.recipe
	if q.op == NetProtocol.Op.PICKUP or q.op == NetProtocol.Op.DROP:
		f.cell = p.aim_cell
	if q.op == NetProtocol.Op.PICKUP and p.data != null and WorldItems.is_portal(p.data, f.cell):
		f.op = NetProtocol.Op.TRAVEL
	if q.op == NetProtocol.Op.DROP and q.slot < 0:
		f.slot = p.inventory.selected
	if p.data != null and NetProtocol.op_has_map(f.op):
		f.map = p.data.map_id


## Each member whose inventory changed gets it (its own only), with its last handled frame.
func _send_inventories() -> void:
	var peers: Array[int] = remote_peers()
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if not m.inventory_dirty or m.gate == null or not peers.has(m.peer_id):
			continue
		m.inventory_dirty = false
		s.send_inventory(m.peer_id, NetProtocol.encode_inventory(m.player.inventory, m.gate.last_seq))


# --- movement --------------------------------------------------------------------------------

## A client's input frames.
func on_input(peer_id: int, payload: PackedByteArray) -> void:
	if s.over:
		return
	var slot: int = roster.slot_of(peer_id)
	if slot < 0 or not s.members.has(slot) or s.members[slot].gate == null:
		s.unknown_senders += 1
		return
	s.members[slot].gate.receive(NetProtocol.decode_inputs(payload))


func tick(action: NetBot.Action, now: int) -> void:
	_changed = false
	for map: int in arenas:
		arenas[map].now = s.tick
	for slot: int in s.slots():
		s.members[slot].refill_ops()
	# Every player runs the same frame rule (run_frame): the facing follows the look or the direction
	# (Movement.facing_for), requests are checked at the frame's position.
	run_frame(s.local, _local_frame(action))
	# Real time since the last tick refills the input gates (a hitch's lost ticks included).
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_ticks: float = InputGate.ticks_between(_last_take_usec, now_usec)
	_last_take_usec = now_usec
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if m.gate == null:
			continue
		run_client_frames(m, m.gate.take(elapsed_ticks))
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if m.respawn_pending and not streams.has(m.peer_id):
			_respawn(m)
	_step_arenas()
	# A request's change, or any client frame handled (its acknowledgement goes out): not quiet.
	if _changed or _frames > 0:
		broadcast.note_activity(s.tick)
	_frames = 0
	for slot: int in s.members:
		var pl: Player = s.members[slot].player
		if pl.walking or pl.action_anim >= 0 or not pl.vitals.idle():
			broadcast.note_activity(s.tick)  # before this tick's batch decision (M4b: a timer runs)
			break
	if action.edit != null:
		edit(EditLog.WorldEdit.new(WorldData.Layer.FLOOR, action.edit.cell, action.edit.terrain))
	if not action.mark.is_empty():
		s.bots.mark(action.mark)
	if action.leave:
		s.log_event("bot", "leave is for clients; the host ignores it")
	if action.stall_ms > 0:
		s.stall_after_tick(action.stall_ms)
	_drop_silent_peers(now)
	_pump_streams()
	var batch_tick: bool = s.tick % (Config.NET_TICK_RATE / Config.NET_STATE_HZ) == 0
	if batch_tick:
		_send_states()
	_send_enemies(batch_tick)
	_send_shot_events()
	_send_inventories()
	s.bots.host_after_tick(now)


## Runs the frames the input gate gave client member `m` this host tick, against host time (M4-fix,
## Config.NET_HOST_STEPS_AFTER_TICKS): while the member is timed (vitals running a timer, or a body action
## playing) its clock debt grows by one a host tick and shrinks by one a frame it runs; a frame that would
## run with no debt left waits for a later tick (put back in the gate), so its timers (stagger, dash and its
## cooldown, invulnerability, down and respawn time, the action) never run faster than the host's clock.
## When its vitals run and the debt passes the threshold (a client that went quiet, or sends a frame now and
## then), the host steps it itself with an empty frame each tick. Idle, the debt is 0.
func run_client_frames(m: NetMember, frames: Array[NetProtocol.InputFrame]) -> void:
	if timed(m):
		m.clock_debt += 1
	else:
		m.clock_debt = 0
	var ran: int = 0
	for frame: NetProtocol.InputFrame in frames:
		var was_timed: bool = timed(m)
		if was_timed and m.clock_debt <= 0:
			break
		run_frame(m, frame)
		ran += 1
		if was_timed:
			m.clock_debt -= 1
	if ran < frames.size():
		var held: Array[NetProtocol.InputFrame] = []
		held.assign(frames.slice(ran))
		m.gate.put_back(held)
		m.frames_held += held.size()
	if not timed(m):
		m.clock_debt = 0
		m.host_stepping = false
		return
	if m.clock_debt <= Config.NET_HOST_STEPS_AFTER_TICKS:
		if m.clock_debt < Config.NET_HOST_STEPS_AFTER_TICKS:
			m.host_stepping = false
		return
	if m.player.vitals.idle():
		m.clock_debt = Config.NET_HOST_STEPS_AFTER_TICKS  # only an action plays: it waits for the client's frames
		return
	if not m.host_stepping:
		m.host_stepping = true
		s.log_event("host_steps", "slot=%d: %d ticks behind the host while %s" % [m.slot, m.clock_debt,
			m.player.vitals.describe()])
	m.host_steps += 1
	run_frame(m, NetProtocol.InputFrame.new())
	m.clock_debt -= 1


## M4-fix: member `m` is timed: its vitals run a timer (Vitals.idle false) or a body action plays. Its
## frames are then its clock (a client records one every tick, Prediction.step_frame).
static func timed(m: NetMember) -> bool:
	return not m.player.vitals.idle() or m.player.action_anim >= 0


## One state batch for everybody while something changed, a reliable keyframe once it stops.
func _send_states() -> void:
	var states: Array[NetProtocol.PlayerState] = []
	for slot: int in s.slots():
		states.append(s.members[slot].state())
	match broadcast.decide(s.tick, states):
		StateBroadcast.Send.BATCH:
			for peer: int in remote_peers():
				s.send_state(peer, broadcast.payload)
		StateBroadcast.Send.KEYFRAME:
			for peer: int in remote_peers():
				s.send_keyframe(peer, broadcast.payload)


func _drop_silent_peers(now: int) -> void:
	var peer: MultiplayerPeer = s.multiplayer.multiplayer_peer
	for id: int in connected_ms.keys():
		if now - connected_ms[id] > int(Config.NET_HELLO_TIMEOUT_SEC * 1000.0):
			connected_ms.erase(id)
			s.log_event("dropped", "peer=%d reason=no_hello" % id)
			peer.disconnect_peer(id)
	for id: int in refused_ms.keys():
		if now - refused_ms[id] > int(Config.NET_REFUSE_GRACE_SEC * 1000.0):
			refused_ms.erase(id)
			s.log_event("dropped", "peer=%d reason=refused_still_connected" % id)
			peer.disconnect_peer(id)


## Welcomed clients (not the host itself, not a joiner still loading its world) a message can
## still reach.
func remote_peers() -> Array[int]:
	var out: Array[int] = []
	for peer: int in roster.peers():
		if peer != 1 and not (streams.has(peer) and not streams[peer].entry) and s.transport.can_send_to(peer):
			out.append(peer)
	return out


## M3b: the welcomed clients on map `map` whose entry to it is complete (they get its live edits; one
## still receiving the map gets the edits made meanwhile after its map entry).
func peers_on(map: int) -> Array[int]:
	var out: Array[int] = []
	for peer: int in remote_peers():
		var slot: int = roster.slot_of(peer)
		if slot < 0 or not s.members.has(slot) or s.members[slot].map_id != map:
			continue
		if streams.has(peer) and streams[peer].entry:
			continue
		out.append(peer)
	return out


## Nobody is half-way in: no connection without hello, no refused one still there, no world still
## being sent.
func settled() -> bool:
	return connected_ms.is_empty() and refused_ms.is_empty() and streams.is_empty()


# --- combat (M4b) ----------------------------------------------------------------------------------

## A new member's start: its class weapon in Config.START_WEAPON_SLOT (as offline), the test start HP
## (--test-start-hp=<class>:<hp>), its hits logged and counted.
func _equip(m: NetMember) -> void:
	Main.give_start_weapon(m.player)
	m.inventory_dirty = true
	if s.options.test_start_hp.has(m.class_id):
		m.player.vitals.hp = clampi(s.options.test_start_hp[m.class_id], 1, Config.PLAYER_HP_MAX)
	m.player.hurt.connect(_on_member_hurt.bind(m))
	m.player.revived.connect(_on_member_revived.bind(m))


func _on_member_hurt(amount: int, downed: bool, m: NetMember) -> void:
	m.count_combat("hurt")
	if downed:
		m.count_combat("downed")
	s.log_event("hurt", "slot=%d map=%d amount=%d hp=%d%s" % [m.slot, m.map_id, amount, m.player.vitals.hp,
		" DOWN" if downed else ""])


func _on_member_revived(m: NetMember) -> void:
	m.count_combat("revived")
	s.log_event("revived", "slot=%d map=%d hp=%d" % [m.slot, m.map_id, m.player.vitals.hp])


## One Arena (and its view, and its enemy broadcast) per map this host has, like offline (Main.setup_combat);
## spawns from the world seed unless --test-no-spawns; the test heretics (--test-heretic on the surface,
## --test-dungeon-heretic) and the shrine's test HP (--test-shrine-hp).
func _setup_combat() -> void:
	for map: int in s.worlds:
		var w: GameWorld = s.worlds[map]
		if w == null or w.data == null:
			continue
		var a: Arena = Arena.new()
		a.setup(w.data, w.data.world_seed)
		a.logging = true
		a.spawning = not s.options.test_no_spawns
		arenas[map] = a
		enemy_casts[map] = StateBroadcast.new()
		var v: CombatView = CombatView.new()
		v.name = &"Combat"
		w.add_child(v)
		v.setup(a, w.entities)
		views[map] = v
	if arenas.has(Config.MAP_SURFACE):
		for c: Vector2i in s.options.test_heretics:
			arenas[Config.MAP_SURFACE].spawn_heretic(Arena.spawn_feet(c))
	if arenas.has(Config.MAP_DUNGEON):
		for c: Vector2i in s.options.test_dungeon_heretics:
			arenas[Config.MAP_DUNGEON].spawn_heretic(Arena.spawn_feet(c))
		if s.options.test_shrine_hp > 0 and arenas[Config.MAP_DUNGEON].shrine_rect().has_area():
			arenas[Config.MAP_DUNGEON].shrine_hp = s.options.test_shrine_hp


## The players on map `map` in slot order (the arena's fixed order).
func players_on(map: int) -> Array[Player]:
	var out: Array[Player] = []
	for slot: int in s.slots():
		if s.members[slot].map_id == map:
			out.append(s.members[slot].player)
	return out


## The member whose Player node has instance id `id`, or null.
func member_of(id: int) -> NetMember:
	for slot: int in s.members:
		if s.members[slot].player != null and s.members[slot].player.get_instance_id() == id:
			return s.members[slot]
	return null


## Every map with a player on it steps its arena (revives, heretics, shots, spawns; a map nobody is on
## waits, M4a); its world edits (the shrine breaking) go out like any other; the hits are logged.
func _step_arenas() -> void:
	var maps: Array[int] = []
	maps.assign(arenas.keys())
	maps.sort()
	for map: int in maps:
		var players: Array[Player] = players_on(map)
		var a: Arena = arenas[map]
		if not players.is_empty():
			var edits: Array[EditLog.WorldEdit] = a.step(players)
			if a.attacks_started > 0:
				for h: HereticSim in a.heretics:
					if h.state == HereticSim.State.ATTACK and h.state_ticks == 0:
						var target: NetMember = member_of(h.target_id)
						s.log_event("heretic_attack", "map=%d heretic=%d slot=%d at=%d,%d" % [map, h.id,
							target.slot if target != null else -1, roundi(h.pos.x), roundi(h.pos.y)])
			for e: EditLog.WorldEdit in edits:
				apply_world_edit(e, map)
				_changed = true
			if not edits.is_empty():
				s.log_event("shrine_broken", "map=%d at=%d,%d (a shot)" % [map, edits[0].cell.x, edits[0].cell.y])
			for sp: Arena.Splash in a.splashes:
				if sp.age == 0:  # M6b: broke this tick
					_changed = true
					s.log_event("splash", "map=%d id=%d item=%s at=%d,%d why=%s players=%d heretics=%d" % [map, sp.id,
						sp.item, roundi(sp.pos.x), roundi(sp.pos.y), sp.why, sp.players, sp.heretics])
		var emptied: bool = players.is_empty() and a.occupied
		if emptied:
			# M4-fix: its last player left: attacks stop without the knife, the shots in the air are gone
			# (README "M4-fix 빈 지도"); the map then waits as before.
			var cancelled: int = a.stat("attacks_cancelled")
			a.idle_tick()
			s.log_event("map_emptied", "map=%d heretics=%d attacks_cancelled=%d" % [map, a.heretics.size(),
				a.stat("attacks_cancelled") - cancelled])
		_flush_hits(map)
		# M4-fix: a map nobody is on is drawn once more when it empties, then left alone (it does not change).
		if (emptied or not players.is_empty()) and views.has(map) and is_instance_valid(views[map]):
			views[map].sync(players)


## The hits on map `map`'s heretics since the last tick: logged, counted per member.
func _flush_hits(map: int) -> void:
	var a: Arena = arenas[map]
	for h: Arena.Hit in a.hits:
		var m: NetMember = member_of(h.by_id)
		var slot: int = m.slot if m != null else -1
		if m != null:
			m.count_combat("hits")
			if h.killed:
				m.count_combat("kills")
		s.log_event("hit", "slot=%d map=%d heretic=%d amount=%d hp=%d%s" % [slot, map, h.heretic_id, h.amount, h.hp_after,
			" KILLED" if h.killed else ""])
	a.hits.clear()


## Each map's enemy batch to the members on it (peers_on): on a batch tick while something changed, a
## reliable keyframe once it stops (StateBroadcast per map), and at once on a tick a heretic starts an
## attack (Config.NET_ENEMY_SEND_ON_ATTACK).
func _send_enemies(batch_tick: bool) -> void:
	for map: int in arenas:
		var a: Arena = arenas[map]
		var urgent: bool = Config.NET_ENEMY_SEND_ON_ATTACK and a.attacks_started > 0
		if not batch_tick and not urgent:
			continue
		var bc: StateBroadcast = enemy_casts[map]
		bc.note_activity(s.tick)
		var payload: PackedByteArray = NetProtocol.encode_enemies(s.tick, map, a.shrine_hp_now(), a.enemy_states(s.tick))
		match bc.decide_encoded(s.tick, payload):
			StateBroadcast.Send.BATCH:
				if urgent and not batch_tick:
					enemy_urgent_sends += 1
				for peer: int in peers_on(map):
					s.send_enemies(peer, payload)
					enemy_batches_sent += 1
			StateBroadcast.Send.KEYFRAME:
				for peer: int in peers_on(map):
					s.send_enemy_keyframe(peer, payload)
					enemy_keyframes_sent += 1


## A member who just arrived on map `map` (welcome, map entry): its enemies as a reliable keyframe and the
## shots in the air there (as let-go events).
func send_combat_snapshot(peer: int, map: int) -> void:
	var a: Arena = arenas.get(map, null)
	if a == null:
		return
	s.send_enemy_keyframe(peer, NetProtocol.encode_enemies(s.tick, map, a.shrine_hp_now(), a.enemy_states(s.tick)))
	enemy_keyframes_sent += 1
	var flying: Array[NetProtocol.ShotEvent] = []
	for shot: Arena.Shot in a.shots:
		if shot.done:
			continue
		var e: NetProtocol.ShotEvent = NetProtocol.ShotEvent.new()
		e.kind = NetProtocol.ShotEvent.Kind.SPAWN
		e.id = shot.id
		e.item = shot.item
		e.owner = shot.owner_slot
		e.aim = shot.aim
		e.tick = shot.born
		e.pos = shot.origin
		flying.append(e)
	# M6b: the thrown potions in the air and the splashes still shown.
	for f: Arena.Flask in a.flasks:
		if not f.done:
			flying.append(Arena.flask_event(f))
	for sp: Arena.Splash in a.splashes:
		flying.append(Arena.splash_event(sp))
	if not flying.is_empty():
		s.send_shots(peer, NetProtocol.encode_shots(map, flying))
		shot_messages_sent += 1


## Each map's shot events of this tick to the members on it.
func _send_shot_events() -> void:
	for map: int in arenas:
		var a: Arena = arenas[map]
		if a.shot_events.is_empty():
			continue
		var payload: PackedByteArray = NetProtocol.encode_shots(map, a.shot_events)
		for peer: int in peers_on(map):
			s.send_shots(peer, payload)
			shot_messages_sent += 1
		a.shot_events.clear()


## Something fighting on a map with players (the traffic's "fight" bucket).
func fighting() -> bool:
	for map: int in arenas:
		if arenas[map].fighting() and not players_on(map).is_empty():
			return true
	return false


## Every map's enemies quiet (their last batch followed by a keyframe) and no shot in the air: a test
## session may finish (its clients then hold the host's last enemy state).
func combat_quiet() -> bool:
	for map: int in arenas:
		var a: Arena = arenas[map]
		if enemy_casts[map].dirty or not a.shots.is_empty() or not a.flasks.is_empty() or not a.splashes.is_empty():
			return false
	return true


## md5 of map `map`'s enemy batch body now (NetCombat.latest_hash on a client that got the last one).
func combat_hash(map: int) -> String:
	var a: Arena = arenas.get(map, null)
	if a == null:
		return ""
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(NetProtocol.encode_enemies(s.tick, map, a.shrine_hp_now(), a.enemy_states(s.tick)).slice(4))
	return ctx.finish().hex_encode()


## The live heretics on the local player's map (the host's bot aims at them).
func foe_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var a: Arena = arenas.get(s.local_map(), null)
	if a != null:
		for h: HereticSim in a.heretics:
			if h.alive():
				out.append(h.pos)
	return out


func combat_result() -> Dictionary:
	var maps: Dictionary = {}
	for map: int in arenas:
		var a: Arena = arenas[map]
		maps[str(map)] = {"hash": combat_hash(map), "heretics": a.heretics.size(), "alive": a.alive_heretics(),
			"shrine_hp": a.shrine_hp_now(), "stats": a.stats, "shots": a.shots.size(),
			"enemy_batches": enemy_casts[map].batches, "enemy_keyframes": enemy_casts[map].keyframes}
	return {"maps": maps, "deaths": deaths, "enemy_batches_sent": enemy_batches_sent,
		"enemy_keyframes_sent": enemy_keyframes_sent, "enemy_urgent_sends": enemy_urgent_sends,
		"shot_messages_sent": shot_messages_sent}
