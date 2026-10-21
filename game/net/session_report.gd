class_name SessionReport
extends RefCounted
## What a session instance writes for tests (--net-out): the result JSON at the end and marker
## files along the way, plus the positions hash every instance must agree on.


## md5 of every player's slot, class, exact float32 position and facing, by slot ("" for none).
static func positions_hash(members: Dictionary[int, NetMember]) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	for slot: int in sorted_slots(members):
		var m: NetMember = members[slot]
		var entry: PackedByteArray = PackedByteArray()
		entry.resize(11)
		entry.encode_u8(0, slot)
		entry.encode_u8(1, NetProtocol.class_index(m.class_id))
		entry.encode_float(2, m.player.sim_position.x)
		entry.encode_float(6, m.player.sim_position.y)
		entry.encode_u8(10, m.player.facing)
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


static func build(s: NetSession, reason: String) -> Dictionary:
	var players: Array = []
	var gates: Dictionary = {}
	var ops: Dictionary = {}
	for slot: int in sorted_slots(s.members):
		var m: NetMember = s.members[slot]
		var entry: Dictionary = {"slot": slot, "class": m.class_id, "x": m.player.sim_position.x,
			"y": m.player.sim_position.y, "facing": m.player.facing, "walking": m.player.walking,
			"held": String(m.player.held_id()), "action": m.player.action_anim, "actions": m.actions_seen}
		# Inventories: the host has everyone's, a client only its own.
		if s.host != null or m == s.local:
			entry["inventory"] = m.player.inventory.describe()
		if s.host != null:
			ops[str(slot)] = {"done": m.ops_done, "refused": m.ops_refused}
		players.append(entry)
		if m.gate != null:
			gates[str(slot)] = m.gate.to_dict()
	var view: Dictionary[String, int] = s.world.ground.verify()
	var drops: Array = []
	for id: int in s.world.data.drop_ids():
		drops.append(s.world.data.drops[id].describe())
	var out: Dictionary = {
		"name": s.instance_name(), "role": NetSession.ROLE_NAMES[s.role], "ended": reason,
		"slot": s.local.slot if s.local != null else -1, "class": s.local_class(), "ticks": s.tick,
		"wall_sec": s.seconds_running(), "players": players, "positions_hash": positions_hash(s.members),
		"world_hash": s.world.data.content_hash(), "generator_hash": s.generator_hash, "edits": s.edit_log.size(),
		"view": view, "view_hash": s.world.ground.view_hash(), "stats": s.stats.to_dict(),
		"link": s.link.to_dict(), "bad_messages": s.bad_messages, "unknown_senders": s.unknown_senders,
		"stalled_ms": s.stalled_ms,
		# M2b: what lies in the world and whether it is drawn, the requests (host), inventories (client).
		"gatherables": WorldItems.gatherable_cells(s.world.data).size(), "drops": drops,
		"items_view": s.world.items.verify(), "ops": ops, "pickups": 0, "inventories": 0,
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
