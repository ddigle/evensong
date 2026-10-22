class_name SessionReport
extends RefCounted
## What a session instance writes for tests (--net-out): the result JSON at the end and marker
## files along the way, plus the positions hash every instance must agree on.
## M3b: the result has every map this instance holds (`maps`: the host all of them, a client the one it
## is on) with its hash, picture and edits, and per player its map and whether it is drawn here; the
## top-level world fields are the local player's map's. Markers hold what the instance sees then (seen).


## md5 of every player's slot, class, exact float32 position, facing and (M3b) map, by slot ("" for none).
static func positions_hash(members: Dictionary[int, NetMember]) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	for slot: int in sorted_slots(members):
		var m: NetMember = members[slot]
		var entry: PackedByteArray = PackedByteArray()
		entry.resize(12)
		entry.encode_u8(0, slot)
		entry.encode_u8(1, NetProtocol.class_index(m.class_id))
		entry.encode_float(2, m.player.sim_position.x)
		entry.encode_float(6, m.player.sim_position.y)
		entry.encode_u8(10, m.player.facing)
		entry.encode_u8(11, m.map_id)
		bytes.append_array(entry)
	if bytes.is_empty():
		return ""  # HashingContext.update() refuses empty data with an engine error
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


static func sorted_slots(members: Dictionary[int, NetMember]) -> Array[int]:
	var slots: Array[int] = []
	slots.assign(members.keys())
	slots.sort()
	return slots


## What this machine sees (marker files): tick, its map, per slot that player's map and whether it is
## drawn here (visible in a shown world).
static func seen(s: NetSession) -> Dictionary:
	var players: Dictionary = {}
	for slot: int in sorted_slots(s.members):
		var m: NetMember = s.members[slot]
		players[str(slot)] = {"map": m.map_id, "drawn": drawn(m)}
	return {"tick": s.tick, "map": s.local_map(), "players": players}


## Whether member `m` is drawn on this machine (its node visible and in a shown world).
static func drawn(m: NetMember) -> bool:
	return is_instance_valid(m.player) and m.player.is_inside_tree() and m.player.is_visible_in_tree()


## One map's world as this instance has it: content hash, picture (hash and check against the data),
## gatherables, drops, fixtures, its edit log position, walls and how many of them are cracked.
static func map_result(s: NetSession, map: int) -> Dictionary:
	var w: GameWorld = s.world_of(map)
	var drops: Array = []
	for id: int in w.data.drop_ids():
		drops.append(w.data.drops[id].describe())
	var cracked: int = 0
	var walls: Array[Vector2i] = Walls.wall_cells(w.data)
	for c: Vector2i in walls:
		if Walls.hits_at(w.data, c) > 0:
			cracked += 1
	return {"hash": w.data.content_hash(), "view_hash": w.view_hash(), "view": w.view_check(),
		"items_view": w.items.verify(), "fixtures": w.fixtures.verify(), "gatherables": WorldItems.gatherable_cells(w.data).size(),
		"drops": drops, "edits": s.log_for(map).size(), "walls": walls.size(), "cracked": cracked,
		"torches": w.data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TORCH)}


static func build(s: NetSession, reason: String) -> Dictionary:
	var players: Array = []
	var gates: Dictionary = {}
	var ops: Dictionary = {}
	for slot: int in sorted_slots(s.members):
		var m: NetMember = s.members[slot]
		var entry: Dictionary = {"slot": slot, "class": m.class_id, "x": m.player.sim_position.x,
			"y": m.player.sim_position.y, "facing": m.player.facing, "walking": m.player.walking,
			"held": String(m.player.held_id()), "action": m.player.action_anim, "actions": m.actions_seen,
			"map": m.map_id, "drawn": drawn(m)}
		# Inventories: the host has everyone's, a client only its own.
		if s.host != null or m == s.local:
			entry["inventory"] = m.player.inventory.describe()
		if s.host != null:
			ops[str(slot)] = {"done": m.ops_done, "refused": m.ops_refused, "swings_missed": m.swings_missed}
		players.append(entry)
		if m.gate != null:
			gates[str(slot)] = m.gate.to_dict()
	# M3b: the host has every map, a client the one it is on (it keeps no other).
	var maps: Dictionary = {}
	for map: int in s.worlds:
		var w: GameWorld = s.worlds[map]
		if w.data != null and (s.role != NetSession.Role.CLIENT or map == s.local_map()):
			maps[str(map)] = map_result(s, map)
	var here: Dictionary = maps.get(str(s.local_map()), {})
	if here.is_empty():
		here = map_result(s, Config.MAP_SURFACE)
	var out: Dictionary = {
		"name": s.instance_name(), "role": NetSession.ROLE_NAMES[s.role], "ended": reason,
		"slot": s.local.slot if s.local != null else -1, "class": s.local_class(), "ticks": s.tick,
		"wall_sec": s.seconds_running(), "players": players, "positions_hash": positions_hash(s.members),
		"map": s.local_map(), "maps": maps,
		"world_hash": here["hash"], "generator_hash": s.generator_hash, "edits": here["edits"],
		"view": here["view"], "view_hash": here["view_hash"], "stats": s.stats.to_dict(),
		"link": s.link.to_dict(), "bad_messages": s.bad_messages, "unknown_senders": s.unknown_senders,
		"stalled_ms": s.stalled_ms,
		# M2b: what lies in the world and whether it is drawn, the requests (host), inventories (client).
		"gatherables": here["gatherables"], "drops": here["drops"],
		"items_view": here["items_view"], "ops": ops, "pickups": 0, "inventories": 0,
		"bot_finished": s.bots.bot.finished if s.bots.bot != null else true, "done_peers": s.bots.done_count(),
		# Host side (defaults on a client).
		"gates": gates, "refusals": {}, "batches": 0, "keyframes": 0, "quiet_violations": 0, "max_players": 0,
		"snapshots_sent": 0, "snapshot_bytes_sent": 0, "streams": [],
		# Client side (defaults on the host).
		"prediction": {}, "refused": "", "stale_batches": 0, "interp_samples": 0, "interp_starved": 0,
		"join_ms": -1.0, "world_build_ms": -1.0, "snapshot_bytes": 0, "snapshot_raw": 0, "snapshot_chunks": 0,
		"host_generator_hash": "", "generator_match": false,
	}
	if s.host != null:
		out["refusals"] = s.host.refusals
		out["batches"] = s.host.broadcast.batches
		out["keyframes"] = s.host.broadcast.keyframes
		out["quiet_violations"] = s.host.broadcast.quiet_violations
		out["max_players"] = s.host.roster.max_players
		out["snapshots_sent"] = s.host.snapshots_sent
		out["snapshot_bytes_sent"] = s.host.snapshot_bytes_sent
		out["streams"] = s.host.streams_done
		out["pickups"] = s.host.pickups
		out["map_entries"] = s.host.map_entries
		out["travels"] = s.host.travels
	if s.client != null:
		var c: SessionClient = s.client
		out["prediction"] = c.prediction.to_dict() if c.prediction != null else {}
		out["refused"] = c.refused_reason
		out["stale_batches"] = c.stale_batches
		out["interp_samples"] = c.interp_samples
		out["interp_starved"] = c.interp_starved
		out["join_ms"] = c.join_ms
		out["world_build_ms"] = c.world_build_ms
		out["snapshot_bytes"] = c.snapshot_bytes
		out["snapshot_raw"] = c.snapshot_raw
		out["snapshot_chunks"] = c.snapshot_chunks
		out["host_generator_hash"] = c.host_generator_hash
		out["generator_match"] = c.generator_match
		out["inventories"] = c.inventories
		out["map_entries"] = c.map_entries
		out["last_entry"] = c.last_entry
		out["left_maps"] = c.left_maps
		out["others_on_welcome"] = c.others_on_welcome
		out["wrong_map_edits"] = c.wrong_map_edits
	return out


## Writes <dir>/<name>.json. False if it could not.
static func write_json(dir: String, name: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join(name + ".json"), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## Writes <dir>/<name>.<marker>.marker containing `text`.
static func write_marker(dir: String, name: String, marker: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join("%s.%s.marker" % [name, marker]), FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
