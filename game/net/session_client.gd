class_name SessionClient
extends RefCounted
## Client flow of the session (net/session.gd holds the shared state and the RPC table): hello,
## the world snapshot and the welcome, refusal, other players joining and leaving, live world
## edits, host states (own player: prediction; others: interpolation), the client tick that sends
## input frames, and drawing the other players each frame.
##
## Late join: the world comes from the host, not from this machine's generator. The chunks
## (WorldSnapshot.Receiver) are checked on the welcome (count, size, md5 of the packed bytes, then
## the world's content hash) and the world is built and drawn from them (GameWorld.load_data). Any
## failure there ends the session with EXIT_WORLD_MISMATCH. The seed and the host's generator hash
## only feed a diagnostic: whether this machine's generator would have made the same world
## (logged as generator=match|differs, never fatal).
##
## M2b: the local player's frames come from Player.make_frame (keys, mouse, use button) with one
## waiting request attached; the prediction steps them at once (body actions included) and the
## host's state wins. The own inventory is the host's (on_inventory), with the hotbar selections not
## yet handled by the host laid on top. Other players are drawn with their action and held item from
## the states. World edits from requests (gatherables picked, drops) arrive like M1's edits.
##
## M3b (maps): the client keeps only the map it is on (NetMember.map_id of its own member). F on the
## entrance or stairs sends a TRAVEL request (not predicted: the player goes on stepping on the old map
## until the host's answer). The host then sends that map's chunks (the join path: WorldSnapshot.Receiver)
## and the map entry: the client checks the map like a joined world (count, size, md5s, world hash, map
## id), loads it into that map's GameWorld (main.tscn: the surface's World or the Dungeon it added),
## moves its own and the other players' nodes there, drops the old map's edit log, switches the
## prediction to the new data from the host's state and replays the frames after it
## (Prediction.switch_map), and tells Main to show that map (local_map_changed). Edits carry their map:
## one for another map than the client's is a malformed message. The other players are drawn only while
## their (interpolated) state is on the client's map; their positions are still followed elsewhere.
##
## M4b (combat): frames carry Space (dash) and F held, a USE its aim; the prediction steps the vitals too
## (dash, stagger, down, dead, respawn on the surface) and takes the host's in every state; a hit, a revive
## and the revive's progress are the host's events (Prediction.event_corrections). The own player and the
## others are drawn with their vitals (hurt / down poses, the hit flash, the HUD's bars). The heretics and
## shots of the client's map come as enemy batches (CH_ENEMY, unreliable, through the link simulation like
## the states; a reliable keyframe after a welcome, a map entry and when they go quiet) and shot events
## (reliable) into a NetCombat (net/net_combat.gd), drawn every frame by a CombatView in the map's world:
## positions a buffer behind like the players, the wind-up at once. Enemy messages for another map than
## the loaded one (an unreliable batch overtaking a map entry) are skipped, never applied.
##
## M6b (potions and crafting): the own player drinks (a USE of a potion) and throws (THROW, the skill key 1) with
## the offline controls; the prediction plays the drink / throw action at once, never its effect: a potion used,
## a heal, a buff or a poison come with the host's inventory and state (the vitals block's effects; a hit or a
## heal by a splash is a host event for the prediction). Thrown bottles come as the host's thrown / broke events
## and fly here like the shots (net/net_combat.gd); a heretic's poison rides on the enemy batches. A crafting
## panel row is a CRAFT request (Main.craft_row, not predicted). The inventory the host sends marks what it holds
## as seen (Inventory.seen), so the recipes unlock here as they do on the host.
##
## M5c (farming, purification, the altar): the own player tills, plants, waters, harvests, pours holy water, channels
## (F with nothing to pick up next to corruption: a CHANNEL request, predicted like an action) and lifts / puts down the
## altar (F held: ALTAR_LIFT; the click while carrying: ALTAR_PLACE) with the offline controls; every result is the host's:
## fields, crops, purified ground and the altar's place come as edits (a corrupted tile made clean flashes here), the
## carried altar in the states (the carrier's mark, this player's own carrying), the respawn at the slot of the altar
## where this world has it.
##
## M7c (stations, gear, the chest, building, doors, trees): the own player places stations and the chest, builds (a USE of a
## piece), takes pieces down (DEMOLISH), opens and closes doors (F: DOOR), puts the armour on and off (ARMOR), moves stacks in
## an open chest panel (CHEST) and chops (the axe's USE) with the offline controls; the axe swing is predicted like any body
## action, nothing it or the requests change is: pieces, doors, stumps and stations come as cell edits, a chest's slots as
## chest slot edits (an open panel reads them), the gear's durability and the armour with the host's inventory. The
## prediction walks this machine's world, built walls and closed doors included (Walls.blocks), as the host does; a door
## never closes and a piece never goes down within Config.BLOCK_CLEARANCE_PX of another player (README "M7c 예측").

var s: NetSession
var prediction: Prediction
var clock: Interpolation.RemoteClock = Interpolation.RemoteClock.new()
var receiver: WorldSnapshot.Receiver = WorldSnapshot.Receiver.new()
var stale_batches: int = 0
## Frames that drew a walking player, and how many of them had no newer state to move to.
var interp_samples: int = 0
var interp_starved: int = 0
var refused_reason: String = ""
## Inventories received from the host (M2b).
var inventories: int = 0
## Join: when the transport connected, how long until the world was ready, what came in.
var connected_usec: int = 0
var join_ms: float = -1.0
var world_build_ms: float = -1.0
var snapshot_bytes: int = 0
var snapshot_raw: int = 0
var snapshot_chunks: int = 0
## Diagnostic: the host's generator hash for its seed, and whether this machine's matches it.
var host_generator_hash: String = ""
var generator_match: bool = false
## M3b: map entries received, and the last one's numbers (for the results).
var map_entries: int = 0
var last_entry: Dictionary = {}
## M3b: when the map left last was left: its id, hash and edit count then (the test compares them
## with the host's log).
var left_maps: Array[Dictionary] = []

## M3b: players on another map than the joiner's when it was welcomed, and edits of another map
## (malformed).
var others_on_welcome: int = 0
var wrong_map_edits: int = 0
## M6b: the players whose welcome state had a buff or a poison running (slot: Vitals.describe), for the results.
var effects_on_welcome: Dictionary = {}
## M4b: the combat of the loaded map and its view; enemy and shot messages received by map (a client
## only ever gets its own map's: tests check the other count stays 0); malformed ones.
var combat: NetCombat
var combat_view: CombatView
var enemy_msgs: Dictionary[int, int] = {}
var shot_msgs: Dictionary[int, int] = {}
var bad_combat: int = 0
## M5c: tiles flashed as purified (from the host's edits).
var purify_flashes: int = 0

var _last_state_tick: int = -1


func _init(p_session: NetSession) -> void:
	s = p_session


func on_opened() -> void:
	connected_usec = Time.get_ticks_usec()
	s.log_event("connected", "to=%s:%d" % [s.options.join_address, s.options.port])
	s.send_hello(NetProtocol.encode_hello(NetProtocol.class_index(s.local_class())))


## Before a tick: the link simulation, and the connect timeout. False when the session ended.
func before_tick(now: int, start_ms: int) -> bool:
	s.link.poll(now)
	if not s.active and now - start_ms > int(Config.NET_CONNECT_TIMEOUT_SEC * 1000.0):
		if receiver.chunks == 0:
			s.end_session("failed: not admitted within %.0f s" % Config.NET_CONNECT_TIMEOUT_SEC, NetSession.EXIT_FAILED)
		else:  # admitted, but the world is too big or the link too slow for the timeout
			s.end_session("failed: world not complete within %.0f s (%d chunks, %d B so far)" % [
				Config.NET_CONNECT_TIMEOUT_SEC, receiver.chunks, receiver.bytes.size()], NetSession.EXIT_FAILED)
		return false
	return true


func on_server_disconnected() -> void:
	if s.bots.finish_wait >= 0 or s.bots.leave_wait >= 0:
		return
	s.end_session("lost the host", NetSession.EXIT_FAILED)


# --- joining ---------------------------------------------------------------------------------

## A chunk of the world (before the welcome) or, M3b, of the map this player went to (before its map
## entry).
func on_world_chunk(payload: PackedByteArray) -> void:
	if s.over:
		return
	if not receiver.add(payload):
		_world_failed("bad world chunk: %s" % receiver.error)


## Admitted: build the world from the snapshot, check it, create the players.
func on_welcome(payload: PackedByteArray) -> void:
	if s.local != null or s.over:
		return
	var w: NetProtocol.Welcome = NetProtocol.decode_welcome(payload)
	if not w.ok or w.version != NetProtocol.VERSION:
		s.end_session("failed: bad welcome", NetSession.EXIT_FAILED)
		return
	others_on_welcome = 0
	for info: NetProtocol.PlayerInfo in w.players:
		if info.state.slot != w.slot and info.state.map != Config.MAP_SURFACE:
			others_on_welcome += 1
	var t0: int = Time.get_ticks_usec()
	var data: WorldData = receiver.finish(w.chunk_count, w.packed_size, w.packed_md5, w.raw_size, w.world_md5,
		Config.MAP_SURFACE)
	if data == null:
		_world_failed(receiver.error)
		return
	s.world.load_data(data)
	s.worlds[Config.MAP_SURFACE] = s.world
	world_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	snapshot_bytes = w.packed_size
	snapshot_raw = w.raw_size
	snapshot_chunks = w.chunk_count
	receiver = WorldSnapshot.Receiver.new()
	s.edit_logs.clear()
	s.edit_log = EditLog.new()
	s.edit_log.base = w.edit_position
	# Diagnostic only: would this machine's generator have made the host's seed world? (The seed
	# comes with the snapshot.)
	s.generator_hash = SurfaceGen.generate(data.world_seed, data.size).content_hash()
	host_generator_hash = w.generator_md5.hex_encode()
	generator_match = s.generator_hash == host_generator_hash
	for info: NetProtocol.PlayerInfo in w.players:
		var m: NetMember = s.add_member(info.state.slot, 0, NetProtocol.class_name_of(info.class_index), info.state.pos,
			info.state.facing, info.state.map)
		if info.state.slot == w.slot:
			s.local = m
		else:
			_as_remote(m, info.state)
			m.interp.push(w.tick, info.state)
	if s.local == null or s.local.map_id != Config.MAP_SURFACE:
		s.end_session("failed: welcome without my player on the surface", NetSession.EXIT_FAILED)
		return
	_show_others()
	s.local.player.potions_on = true  # M6b: drinking and throwing in a session (the host decides the effect)
	s.local.player.farming_on = true  # M5c: farming, purifying and carrying the altar too (the host decides the result)
	s.local.player.purify_on = true
	prediction = Prediction.new()
	var me: NetProtocol.PlayerState = s.local.state()
	prediction.setup(s.world.data, me.pos, me.facing, 0)
	prediction.spawn_feet = s.world.spawn_point(w.slot)
	prediction.spawn_slot = w.slot  # M5c: the respawn follows the altar (Prediction.respawn_feet)
	for info: NetProtocol.PlayerInfo in w.players:
		if info.state.slot == w.slot and info.state.vitals != null:
			prediction.sim.vit = info.state.vitals.copy()
			prediction.base.vit = info.state.vitals.copy()
	_combat_on(Config.MAP_SURFACE, s.world)
	clock.observe(w.tick, Interpolation.RemoteClock.now_ticks())
	_last_state_tick = w.tick
	s.active = true
	join_ms = (Time.get_ticks_usec() - connected_usec) / 1000.0
	var fields: Dictionary = SessionReport.fields_of(data)  # M5c: what the snapshot brought of the fields and the altar
	var crops: Dictionary = fields["crops"]
	var built: Dictionary = SessionReport.builds_of(data)  # M7c: and of the built pieces, doors, stumps, stations, chests (M7-rf: floors)
	s.log_event("welcome", ("slot=%d class=%s players=%d max=%d seed=%d edits=%d world=%s world_bytes=%d raw=%d " +
		"chunks=%d build_ms=%.1f join_ms=%.1f gatherables=%d drops=%d elsewhere=%d altar=%s tilled=%d crops=%d withered=%d " +
		"corrupted=%d walls=%d doors=%d open_doors=%d floors=%d stumps=%d stations=%d chests=%d chest_items=%d generator=%s") % [w.slot,
		s.local.class_id,
		s.members.size(), w.max_players, data.world_seed, s.edit_log.size(), data.content_hash().left(12), w.packed_size,
		w.raw_size, w.chunk_count, world_build_ms, join_ms, WorldItems.gatherable_cells(data).size(), data.drops.size(),
		others_on_welcome, "%d,%d" % [data.altar_rect.position.x, data.altar_rect.position.y] if data.altar_rect.has_area() else "none",
		fields["tilled"], crops.size(), fields["withered"], Purify.corrupted_count(data), built["walls"], built["doors"],
		built["open_doors"], built["floors"], built["stumps"], built["workbenches"] + built["anvils"] + built["relic_benches"], built["chest_count"],
		_chest_items(data), "match" if generator_match else "differs (local %s, host %s)" % [s.generator_hash.left(12), host_generator_hash.left(12)]])
	for info2: NetProtocol.PlayerInfo in w.players:
		if info2.state.vitals != null and info2.state.vitals.has_effects():
			effects_on_welcome[str(info2.state.slot)] = info2.state.vitals.describe()
	if not effects_on_welcome.is_empty():
		s.log_event("welcome_effects", JSON.stringify(effects_on_welcome))
	s.local_player_ready.emit(s.local.player)
	s.bots.mark("welcome")
	if w.bots_started:
		s.bots.start_bots()


## M3b: the host moved this player to another map and sent that map (its chunks came first): check
## and load it, move the players' nodes there, switch the prediction, show it.
func on_map_entry(payload: PackedByteArray) -> void:
	if not s.active or s.local == null or s.over:
		return
	var e: NetProtocol.MapEntry = NetProtocol.decode_map_entry(payload)
	if not e.ok or e.state.slot != s.local.slot:
		s.bad_messages += 1
		_world_failed("bad map entry")
		return
	var w: GameWorld = s.world_of(e.map)
	if w == null:
		_world_failed("no world for map %d" % e.map)
		return
	var t0: int = Time.get_ticks_usec()
	var data: WorldData = receiver.finish(e.chunk_count, e.packed_size, e.packed_md5, e.raw_size, e.world_md5, e.map)
	var error: String = receiver.error
	receiver = WorldSnapshot.Receiver.new()
	if data == null:
		_world_failed("map %d: %s" % [e.map, error])
		return
	var old: int = s.local.map_id
	var old_world: GameWorld = s.world_of(old)
	if old_world != null and old_world.data != null:
		left_maps.append({"map": old, "hash": old_world.data.content_hash(), "edits": s.log_for(old).size()})
		if left_maps.size() > Config.NET_STREAM_RECORDS_MAX:
			left_maps.pop_front()  # test results only (M3-fix: a client travelling all session long)
		s.log_event("map_left", "map=%s edits=%d world=%s" % [Config.MAP_NAMES[old], s.log_for(old).size(),
			old_world.data.content_hash().left(12)])
	w.load_data(data)
	s.edit_logs.erase(old)
	s.edit_logs.erase(e.map)
	s.log_for(e.map).base = e.edit_position
	s.local.map_id = e.map
	NetSession.move_player_node(s.local, w)
	s.local.player.set_world(data, e.state.pos)
	for slot: int in s.members:
		if s.members[slot] != s.local:
			NetSession.move_player_node(s.members[slot], w)
	prediction.switch_map(data, e.map, e.state)
	_show_predicted(false)
	_show_others()
	_combat_on(e.map, w)
	map_entries += 1
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	last_entry = {"map": e.map, "bytes": e.packed_size, "raw": e.raw_size, "chunks": e.chunk_count,
		"edit_position": e.edit_position, "build_ms": ms}
	s.log_event("map", "entered map=%s world=%s bytes=%d raw=%d chunks=%d edits=%d drops=%d torches=%d cracked=%d build_ms=%.1f" % [
		Config.MAP_NAMES[e.map], data.content_hash().left(12), e.packed_size, e.raw_size, e.chunk_count, e.edit_position,
		data.drops.size(), data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TORCH), _cracked(data), ms])
	s.local_map_changed.emit(e.map)


## M7c: the items lying in every chest of `data` (the stacks' counts summed).
static func _chest_items(data: WorldData) -> int:
	var n: int = 0
	for key: Vector2i in data.chests:
		for st: ItemStack in data.chests[key].slots:
			if st != null:
				n += st.count
	return n


static func _cracked(data: WorldData) -> int:
	var n: int = 0
	for c: Vector2i in Walls.wall_cells(data):
		if Walls.hits_at(data, c) > 0:
			n += 1
	return n


## The other players: shown where their state is on this client's map, hidden elsewhere.
func _show_others() -> void:
	for slot: int in s.members:
		var m: NetMember = s.members[slot]
		if m != s.local:
			m.player.visible = m.map_id == s.local.map_id


func _world_failed(why: String) -> void:
	s.log_event("world_mismatch", why)
	s.end_session("world mismatch: %s" % why, NetSession.EXIT_WORLD_MISMATCH)


func on_refused(payload: PackedByteArray) -> void:
	if s.over:
		return
	refused_reason = NetProtocol.decode_refusal(payload)
	s.end_session("refused: %s" % refused_reason, NetSession.EXIT_REFUSED)


func on_joined(payload: PackedByteArray) -> void:
	if not s.active or s.bots.finish_wait >= 0:
		return
	var info: NetProtocol.PlayerInfo = NetProtocol.decode_info(payload)
	if info == null or payload.size() != NetProtocol.info_size_at(payload, 0) or s.members.has(info.state.slot):
		s.bad_messages += 1
		return
	var m: NetMember = s.add_member(info.state.slot, 0, NetProtocol.class_name_of(info.class_index), info.state.pos,
		info.state.facing, info.state.map)
	_as_remote(m, info.state)
	m.interp.push(maxi(_last_state_tick, 0), info.state)
	s.log_event("joined", "slot=%d class=%s players=%d" % [m.slot, m.class_id, s.members.size()])


## Another player: drawn from received states (Interpolation), holding what they say.
func _as_remote(m: NetMember, state: NetProtocol.PlayerState) -> void:
	m.interp = Interpolation.new()
	m.player.held_from_state = true
	m.player.state_held = state.held


func on_left(payload: PackedByteArray) -> void:
	# After "finish" the player list is frozen: clients that already left must stay in the result.
	if not s.active or s.bots.finish_wait >= 0:
		return
	if payload.size() != 1 or not s.members.has(payload[0]) or s.members[payload[0]] == s.local:
		s.bad_messages += 1
		return
	s.remove_member(payload[0])
	s.log_event("left", "slot=%d players=%d" % [payload[0], s.members.size()])


## A numbered edit of the map this client is on (M3b: an edit of another map is malformed: the host
## sends a map's edits only to the players on it, and only after their map entry).
func on_edit(payload: PackedByteArray) -> void:
	if not s.active:
		return
	var decoded: Array = EditLog.decode_one(payload)
	var index: int = decoded[0]
	if index < 0:
		s.bad_messages += 1
		return
	var edit: EditLog.WorldEdit = decoded[1]
	var map: int = decoded[2]
	var w: GameWorld = s.world_of(map)
	if map != s.local_map() or w == null or w.data == null:
		s.bad_messages += 1
		wrong_map_edits += 1
		return
	var log: EditLog = s.log_for(map)
	if index != log.size():
		s.bad_messages += 1
	# M5c: a corrupted tile made clean is purified ground: it flashes here as on the host (world/purify_view.gd).
	var purifies: bool = edit.kind == EditLog.Kind.CELL and edit.layer == WorldData.Layer.CORRUPTION and edit.value == 0 \
		and Purify.is_corrupted(w.data, edit.cell)
	if w.apply_edit(edit):
		log.append(edit)
		if purifies and w.purify_view != null:
			w.purify_view.flash([edit.cell] as Array[Vector2i])
			purify_flashes += 1
	else:
		s.bad_messages += 1
	s.log_event("edit", "%s index=%d map=%d world=%s" % [edit.describe(), index, map, w.data.content_hash().left(12)])


## The own inventory as the host has it after frame `ack`; hotbar selections the host has not handled
## yet (frames after `ack`, and requests not sent yet) stay selected.
func on_inventory(payload: PackedByteArray) -> void:
	if not s.active or s.local == null:
		return
	var inv: NetProtocol.InventoryState = NetProtocol.decode_inventory(payload)
	if not inv.ok:
		s.bad_messages += 1
		return
	inventories += 1
	var mine: Inventory = s.local.player.inventory
	var selected: int = inv.selected
	for f: NetProtocol.InputFrame in prediction.pending_ops(NetProtocol.Op.SELECT, inv.ack):
		selected = f.slot
	for q: NetProtocol.InputFrame in s.local_ops:
		if q.op == NetProtocol.Op.SELECT:
			selected = q.slot
	take_inventory(mine, inv, selected)


## The host's inventory `inv` into `mine` with hotbar slot `selected`. M6b: what it holds counts as had here (the
## recipes' unlock, Inventory.seen) before the load tells the crafting panel to read it again. M7c: the stacks keep the
## host's durability, and the armour worn is the host's.
static func take_inventory(mine: Inventory, inv: NetProtocol.InventoryState, selected: int) -> void:
	for st: ItemStack in inv.stacks:
		if st != null:
			mine.seen[st.id] = true
	if inv.armor != null:
		mine.seen[inv.armor.id] = true
	mine.armor = inv.armor.copy() if inv.armor != null else null
	mine.load_state(inv.stacks, selected)


# --- movement --------------------------------------------------------------------------------

func on_state(payload: PackedByteArray) -> void:
	if not s.active:
		return
	s.link.pass_through(_apply_states.bind(payload), Time.get_ticks_msec())


func on_keyframe(payload: PackedByteArray) -> void:
	if not s.active:
		return
	_apply_states(payload)


func _apply_states(payload: PackedByteArray) -> void:
	if not s.active or s.over:
		return
	var batch: NetProtocol.StateBatch = NetProtocol.decode_states(payload)
	if not batch.ok:
		s.bad_messages += 1
		return
	if batch.tick <= _last_state_tick:
		stale_batches += 1
		return
	_last_state_tick = batch.tick
	clock.observe(batch.tick, Interpolation.RemoteClock.now_ticks())
	for st: NetProtocol.PlayerState in batch.states:
		if st.slot == s.local.slot:
			# M3b: a state on another map than the loaded one (the host moved this player, its map entry
			# is still on the way) is skipped by the prediction.
			var off: int = prediction.vitals_corrections
			if prediction.reconcile(st) >= 0.0:
				_show_predicted(false)
			if prediction.vitals_corrections > off:
				s.log_event("vitals_correction", prediction.last_vitals_mismatch)
			if st.map == s.local.map_id and s.local.player.carrying_altar != st.carrying:
				s.local.player.set_carrying_altar(st.carrying)  # M5c: the host says this player carries the altar (or not)
		elif s.members.has(st.slot) and s.members[st.slot].interp != null:
			s.members[st.slot].interp.push(batch.tick, st)
			s.members[st.slot].map_id = st.map


## The own player as predicted (`tick`: this tick's step, drawn from the tick's start).
func _show_predicted(tick: bool) -> void:
	var me: Player = s.local.player
	var st: PlayerSim = prediction.sim
	me.show_state(st.pos, st.facing, st.walking, tick, st.action, st.action_tick, st.vit, st.channel_tick)
	me.action_cell = st.action_cell
	me.channel_cell = st.channel_cell
	me.refresh_aim()


func tick(action: NetBot.Action) -> void:
	var me: Player = s.local.player
	var f: NetProtocol.InputFrame = me.make_frame(action.dir, action.mouse, action.aiming, action.use_pressed,
		action.use_held, action.dash, action.interact, action.skill)
	SessionHost.attach_local_op(s, me, f, action)
	var frame: NetProtocol.InputFrame = prediction.step_frame(f)
	_show_predicted(true)
	if f.op != NetProtocol.Op.NONE:
		s.request_ticks = 3
	if f.anim >= 0 and prediction.sim.action == f.anim and prediction.sim.action_tick == 0:
		me.action_item = f.item
		s.local.count_action(f.anim)
		s.log_event("action", "slot=%d item=%s action=%s target=%d,%d predicted" % [s.local.slot, f.item,
			RigData.ANIM_NAMES[f.anim], f.cell.x, f.cell.y])
	var interval: int = Config.NET_TICK_RATE / Config.NET_INPUT_HZ
	# Send every 2nd tick while frames are unacknowledged, and at once when a move starts.
	if prediction.has_unacked() and (s.tick % interval == 0 or (frame != null and prediction.pending.size() == 1)):
		s.link.pass_through(s.send_input.bind(NetProtocol.encode_inputs(prediction.frames_to_send())),
			Time.get_ticks_msec())
	if action.edit != null:
		s.log_event("bot", "edit ignored: only the host edits the world")
	if action.heretic != null:
		s.log_event("bot", "heretic ignored: only the host has the heretics")
	if not action.mark.is_empty():
		s.bots.mark(action.mark)
	if action.stall_ms > 0:
		s.stall_after_tick(action.stall_ms)
	s.bots.client_after_tick(action)


## Every frame: the other players 100 ms behind the host (Interpolation).
func draw_others() -> void:
	var t: float = clock.host_tick_at(Interpolation.RemoteClock.now_ticks()) - interp_delay_ticks()
	for slot: int in s.members:
		var m: NetMember = s.members[slot]
		if m.interp == null:
			continue
		var newest: Interpolation.Snap = m.interp.latest()
		var here: bool = newest != null and newest.map == s.local.map_id
		if here and newest.walking:
			interp_samples += 1
			if t > newest.tick:
				interp_starved += 1  # drawing past the newest state of a walking player: buffer ran dry
		var smp: Interpolation.Snap = m.interp.sample(t)
		if smp != null:
			# M3b: drawn only on this client's map; elsewhere followed (positions) but hidden.
			m.player.visible = smp.map == s.local.map_id
			m.player.state_held = smp.held
			m.player.show_state(smp.pos, smp.facing, smp.walking, false, smp.action, smp.action_tick, smp.vitals, smp.channel)
			if m.player.carrying_altar != smp.carrying:
				m.player.set_carrying_altar(smp.carrying)  # M5c: the altar over its head
			if m.player.visible:
				m.note_action(smp.action, smp.action_tick, t)
	_draw_combat(t + interp_delay_ticks())


# --- combat (M4b) ----------------------------------------------------------------------------------

## The combat of map `map` (world `w`) from now on: a fresh NetCombat (the host's keyframe follows) and
## its view in that world.
func _combat_on(map: int, w: GameWorld) -> void:
	if combat == null:
		combat = NetCombat.new()
	combat.reset(map, w.data)
	combat.local_slot = s.local.slot if s.local != null else -1
	if combat_view != null and is_instance_valid(combat_view):
		combat_view.clear()
		combat_view.get_parent().remove_child(combat_view)
		combat_view.free()
	combat_view = CombatView.new()
	combat_view.name = &"Combat"
	w.add_child(combat_view)
	combat_view.setup(combat.arena, w.entities)


## After losing the host (continue_offline): the host's heretics and shots are gone from the picture.
func drop_combat() -> void:
	if combat_view != null and is_instance_valid(combat_view):
		combat_view.clear()
		combat_view.get_parent().remove_child(combat_view)
		combat_view.free()
	combat_view = null
	combat = null


## Every frame: the heretics, shots and shrine of this client's map at host time `t_fresh` (net/net_combat.gd).
func _draw_combat(t_fresh: float) -> void:
	if combat == null or combat_view == null or not is_instance_valid(combat_view):
		return
	combat.sample(t_fresh, interp_delay_ticks())
	var players: Array[Player] = []
	for slot: int in s.slots():
		var m: NetMember = s.members[slot]
		if m.map_id == s.local.map_id and m.player.visible:
			players.append(m.player)
	combat_view.sync(players)


## An enemy batch (unreliable: through the link simulation like the states).
func on_enemies(payload: PackedByteArray) -> void:
	if not s.active:
		return
	s.link.pass_through(_apply_enemies.bind(payload, false), Time.get_ticks_msec())


func on_enemy_keyframe(payload: PackedByteArray) -> void:
	if not s.active:
		return
	_apply_enemies(payload, true)


func _apply_enemies(payload: PackedByteArray, keyframe: bool) -> void:
	if not s.active or s.over or combat == null:
		return
	var b: NetProtocol.EnemyBatch = NetProtocol.decode_enemies(payload)
	if not b.ok:
		bad_combat += 1
		s.bad_messages += 1
		return
	var n: int = enemy_msgs.get(b.map, 0)
	enemy_msgs[b.map] = n + 1
	clock.observe(b.tick, Interpolation.RemoteClock.now_ticks())
	combat.on_batch(b, payload, keyframe)


func on_shots(payload: PackedByteArray) -> void:
	if not s.active or s.over or combat == null:
		return
	var e: NetProtocol.ShotEvents = NetProtocol.decode_shots(payload)
	if not e.ok:
		bad_combat += 1
		s.bad_messages += 1
		return
	var n: int = shot_msgs.get(e.map, 0)
	shot_msgs[e.map] = n + 1
	combat.on_shots(e)


## Enemy batches / shot messages received for map `map` (tests).
func enemy_msgs_on(map: int) -> int:
	var n: int = enemy_msgs.get(map, 0)
	return n


func shot_msgs_on(map: int) -> int:
	var n: int = shot_msgs.get(map, 0)
	return n


func combat_result() -> Dictionary:
	var out: Dictionary = combat.to_dict() if combat != null else {}
	var em: Dictionary = {}
	for map: int in enemy_msgs:
		em[str(map)] = enemy_msgs[map]
	var sm: Dictionary = {}
	for map: int in shot_msgs:
		sm[str(map)] = shot_msgs[map]
	out["enemy_msgs"] = em
	out["shot_msgs"] = sm
	out["bad"] = bad_combat
	return out


static func interp_delay_ticks() -> float:
	return Config.NET_INTERP_DELAY_MS * Config.NET_TICK_RATE / 1000.0
