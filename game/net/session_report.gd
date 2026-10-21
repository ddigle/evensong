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
	for slot: int in sorted_slots(s.members):
		var m: NetMember = s.members[slot]
		players.append({"slot": slot, "class": m.class_id, "x": m.player.sim_position.x, "y": m.player.sim_position.y,
			"facing": m.player.facing, "walking": m.player.walking})
		if m.gate != null:
			gates[str(slot)] = m.gate.to_dict()
	var view: Dictionary[String, int] = s.world.ground.verify()
	return {
		"name": s.instance_name(), "role": NetSession.ROLE_NAMES[s.role], "ended": reason,
		"slot": s.local.slot if s.local != null else -1, "class": s.local_class(), "ticks": s.tick,
		"wall_sec": s.seconds_running(), "players": players, "positions_hash": positions_hash(s.members),
		"world_hash": s.world.data.content_hash(), "pristine_hash": s.pristine_hash, "edits": s.edit_log.size(),
		"view": view, "stats": s.stats.to_dict(), "prediction": s.prediction.to_dict() if s.prediction != null else {},
		"gates": gates, "refusals": s.refusals, "refused": s.refused_reason, "done_peers": s.done_count(),
		"link": s.link.to_dict(), "batches": s.broadcast.batches, "keyframes": s.broadcast.keyframes,
		"quiet_violations": s.broadcast.quiet_violations,
		"bad_messages": s.bad_messages, "stale_batches": s.stale_batches, "unknown_senders": s.unknown_senders,
		"interp_samples": s.interp_samples, "interp_starved": s.interp_starved,
		"bot_finished": s.bot.finished if s.bot != null else true,
		"max_players": s.roster.max_players if s.roster != null else 0,
	}


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
