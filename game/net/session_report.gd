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
	# M7c: and where this machine has its own player's feet (a session test reads where a door stopped it).
	var feet: String = "%.2f,%.2f" % [s.local.player.sim_position.x, s.local.player.sim_position.y] if s.local != null else ""
	return {"tick": s.tick, "map": s.local_map(), "players": players, "feet": feet}


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
		"torches": w.data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TORCH),
		# M5c: where the altar is ("none" while carried), the fields and the corruption left.
		"altar": "%d,%d" % [w.data.altar_rect.position.x, w.data.altar_rect.position.y] if w.data.altar_rect.has_area() else "none",
		"fields": fields_of(w.data), "corrupted": Purify.corrupted_count(w.data),
		# M7c: the built pieces, doors, trees, stumps, stations and chests, and the build view against the data.
		"builds": builds_of(w.data), "builds_view": w.builds.verify() if w.builds != null else {}}


## M7c: what is built and standing on `data`: built walls, closed and open doors, floor pieces, lantern posts, trees, stumps,
## the stations by kind and every chest's contents by its tile ("x,y" -> WorldData.Chest.describe(), held ones only).
static func builds_of(data: WorldData) -> Dictionary:
	var walls: int = 0
	var doors: int = 0
	var open_doors: int = 0
	var floors: int = 0
	for y: int in data.size.y:
		for x: int in data.size.x:
			var k: int = Walls.kind_at(data, Vector2i(x, y))
			if k == Walls.KIND_STONE:
				walls += 1
			elif k == Walls.KIND_DOOR:
				doors += 1
			elif k == Walls.KIND_DOOR_OPEN:
				open_doors += 1
			elif k == Walls.KIND_FLOOR:
				floors += 1
	var chests: Dictionary = {}
	for key: Vector2i in data.held_chests():
		chests["%d,%d" % [key.x, key.y]] = data.chests[key].describe()
	return {"walls": walls, "doors": doors, "open_doors": open_doors, "floors": floors,
		"lanterns": data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_LANTERN),
		"trees": data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_TREE),
		"stumps": data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_STUMP),
		"workbenches": data.footprints(WorldData.PLACEABLE_WORKBENCH).size(),
		"anvils": data.footprints(WorldData.PLACEABLE_ANVIL).size(),
		"relic_benches": data.footprints(WorldData.PLACEABLE_RELIC).size(),
		"chest_count": data.footprints(WorldData.PLACEABLE_CHEST).size(), "chests": chests}


## M5c: the fields of `data`: tilled tiles, crops (and of them withered, ripe), wet tiles, and the crops by tile
## ("x,y" -> Farming.Field.describe()).
static func fields_of(data: WorldData) -> Dictionary:
	var crops: Dictionary = {}
	var withered: int = 0
	var ripe: int = 0
	var wet: int = 0
	for c: Vector2i in Farming.field_cells(data):
		var f: Farming.Field = Farming.field_at(data, c)
		if f.wet:
			wet += 1
		if f.kind == Farming.KIND_NONE:
			continue
		crops["%d,%d" % [c.x, c.y]] = f.describe()
		if f.withered:
			withered += 1
		if f.ripe():
			ripe += 1
	return {"tilled": data.count_value(WorldData.Layer.FLOOR, Terrain.SOIL), "crops": crops, "withered": withered,
		"ripe": ripe, "wet": wet}


static func build(s: NetSession, reason: String) -> Dictionary:
	var players: Array = []
	var gates: Dictionary = {}
	var ops: Dictionary = {}
	for slot: int in sorted_slots(s.members):
		var m: NetMember = s.members[slot]
		var entry: Dictionary = {"slot": slot, "class": m.class_id, "x": m.player.sim_position.x,
			"y": m.player.sim_position.y, "facing": m.player.facing, "walking": m.player.walking,
			"held": String(m.player.held_id()), "action": m.player.action_anim, "actions": m.actions_seen,
			"map": m.map_id, "drawn": drawn(m), "hp": m.player.vitals.hp, "life": m.player.vitals.life,
			"vitals": m.player.vitals.describe(), "carrying": m.player.carrying_altar, "channel": m.player.channel_tick}
		# Inventories: the host has everyone's, a client only its own.
		if s.host != null or m == s.local:
			entry["inventory"] = m.player.inventory.describe()
			entry["armor"] = Gear.describe(m.player.inventory.armor)  # M7c: the armour worn and its durability
			entry["gear"] = gear_of(m.player.inventory)
		if s.host != null:
			ops[str(slot)] = {"done": m.ops_done, "refused": m.ops_refused, "swings_missed": m.swings_missed,
				"combat": m.combat, "host_steps": m.host_steps, "frames_held": m.frames_held}
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
		out["combat"] = s.host.combat_result()
		out["fields"] = s.host.fields_result()  # M5c
		out["builds"] = s.host.builds_result()  # M7c
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
		out["combat"] = c.combat_result()
		out["effects_on_welcome"] = c.effects_on_welcome
		out["purify_flashes"] = c.purify_flashes  # M5c
	return out


## M7c: every item with durability in `inv` ("<slot>:<item> <left>/<full>", the worn armour as "armor:..."), for the results.
static func gear_of(inv: Inventory) -> Array:
	var out: Array = []
	for i: int in inv.size():
		var st: ItemStack = inv.stack_at(i)
		if st != null and st.max_durability() > 0:
			out.append("%d:%s" % [i, Gear.describe(st)])
	if inv.armor != null:
		out.append("armor:%s" % Gear.describe(inv.armor))
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
