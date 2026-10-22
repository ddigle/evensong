extends "res://tests/base_test.gd"
## M4b: combat in sessions, in one process: the real SessionHost and SessionClient flows, the host's
## messages captured and delivered to real clients in order, the clients' input packets back to the host,
## optionally with a fixed one-way delay (tests/test_net_session.gd runs real sessions; tests/test_net_fight.gd
## the combat ones).
##   - the host's checks against a malicious client: an attack from far away (from where the host has the
##     player, the reach and the target tile), too fast (one action at a time), while down (every tile
##     request "down", no dash, no move), a revive from too far, another map's bag ("wrong map")
##   - flows: two players fight one heretic and see the same HP at every batch; a client's arrows kill a
##     heretic (shot events); a client goes down and the host revives it, the reverse, and a cleric's
##     instant revive; death -> the bag -> another player takes it, the respawn at the altar predicted
##     exactly; a client breaks the shrine and the dungeon spawns no more for anyone, a late joiner of the
##     dungeon gets it broken; a surface player gets no dungeon enemy or shot message; a late joiner mid-
##     fight gets the heretic, its wind-up and the downed player; four players fight two heretics with a
##     delay and all agree
##   - the telegraph against the one-way delay: how late after the wind-up appears a dash still dodges
##     (README "M4b 판정"), with and without the fresh wind-up
##   - the host's own clock for a silent client: its invulnerability ends and its down time runs out

const SEED: int = Config.DEFAULT_SEED
## The fight spot on the seed-1 surface: 13 tiles south of the altar's centre (outside the light).
const FIGHT_OFFSET: Vector2 = Vector2(0, 208)
const WEAPON_SLOT: int = Config.START_WEAPON_SLOT


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

	func send_refused(peer: int, payload: PackedByteArray) -> void:
		wire.append([peer, "refused", payload])

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

	func send_finish(peer: int) -> void:
		wire.append([peer, "finish", PackedByteArray()])

	func send_input(payload: PackedByteArray) -> void:
		wire.append([1, "input", payload])

	func send_hello(payload: PackedByteArray) -> void:
		wire.append([1, "hello", payload])

	func send_done() -> void:
		wire.append([1, "done", PackedByteArray()])

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


class OpenTransport:
	extends NetTransport

	func can_send_to(_peer_id: int) -> bool:
		return true


class Client:
	extends RefCounted
	var s: CaptureSession
	var peer: int = 0
	var surface: GameWorld
	var dungeon: GameWorld
	## This tick's input (the test sets it; idle when null).
	var action: NetBot.Action
	## Off: the client sends nothing (a silent or gone client).
	var ticking: bool = true
	## Every shot event delivered to it, decoded.
	var shot_events: Array[NetProtocol.ShotEvent] = []
	## Every enemy batch delivered to it (decoded), oldest first.
	var batches: Array[NetProtocol.EnemyBatch] = []


class Rig:
	extends RefCounted
	var s: CaptureSession
	var host: SessionHost
	var surface: GameWorld
	var dungeon: GameWorld
	var clients: Array[Client] = []
	## One-way delay in ticks (both ways).
	var delay: int = 0
	## The host's own input this tick (idle when null).
	var action: NetBot.Action
	## Client -> host [due tick, peer, payload] and host -> client [due tick, peer, kind, payload].
	var up: Array[Array] = []
	var down: Array[Array] = []
	## The host's HP of every heretic by host tick (id -> {tick: hp}), for the "same HP" checks.
	var hp_at: Dictionary[int, Dictionary] = {}
	## Most messages (kind -> bytes) to clients, for the traffic estimate.
	var bytes_by_kind: Dictionary[String, int] = {}


func run() -> Array[String]:
	await _check_malicious()
	await _check_two_fight_one()
	await _check_arrow_kill()
	await _check_revives()
	await _check_death_bag()
	await _check_shrine_and_maps()
	await _check_late_join_mid_fight()
	await _check_four_fight()
	await _check_telegraph_window()
	await _check_silent_client()
	return failures


# --- the rig ---------------------------------------------------------------------------------------

func _world(map: int, generate: bool) -> GameWorld:
	var w: GameWorld = (load("res://scenes/world.tscn") as PackedScene).instantiate() as GameWorld
	w.auto_generate = false
	w.free_camera = false
	w.map_id = map
	add_node(w)
	if generate:
		w.generate(SEED)
	return w


## A host (its own player: `host_class` on spawn slot 0) with both maps; spawns off unless `spawns`;
## `start_hp` = --test-start-hp.
func _rig(host_class: String = "paladin", spawns: bool = false, start_hp: Dictionary[String, int] = {}) -> Rig:
	var r: Rig = Rig.new()
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
	r.s.options.class_id = host_class
	r.s.options.test_no_spawns = not spawns
	r.s.options.test_start_hp = start_hp
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
	r.s.local.player.inventory.select(WEAPON_SLOT)
	return r


## A client of `class_id` joining as peer `peer`; its host player stands at `at` (Vector2) when it is
## welcomed (null: its spawn slot). Returns once welcomed, its class weapon selected.
func _join(r: Rig, peer: int, class_id: String, at: Variant = null, select_weapon: bool = true) -> Client:
	var c: Client = Client.new()
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
		c.surface.visible = map == Config.MAP_SURFACE
		c.dungeon.visible = map == Config.MAP_DUNGEON)
	r.clients.append(c)
	r.host.on_hello(peer, NetProtocol.encode_hello(NetProtocol.class_index(class_id)))
	var m: NetMember = member_of_peer(r, peer)
	if m != null and at != null:
		var p: Vector2 = at
		m.player.teleport(p)
	for i: int in 4 + r.delay:
		_tick(r)
		if c.s.active:
			break
	if select_weapon and c.s.active:
		c.action = _select(WEAPON_SLOT)
		_tick(r)
	return c


static func member_of_peer(r: Rig, peer: int) -> NetMember:
	for slot: int in r.s.members:
		if r.s.members[slot].peer_id == peer:
			return r.s.members[slot]
	return null


## The host's member of client `c`.
static func hm(r: Rig, c: Client) -> NetMember:
	return member_of_peer(r, c.peer)


static func idle_for(p: Player) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = p.sim_position
	return a


static func _select(slot: int) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.op = NetProtocol.InputFrame.new()
	a.op.op = NetProtocol.Op.SELECT
	a.op.slot = slot
	return a


## Aim at `at` holding the use button (and optionally other inputs).
static func swing_at(at: Vector2) -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.mouse = at
	a.aiming = true
	a.use_held = true
	return a


static func holding_f() -> NetBot.Action:
	var a: NetBot.Action = NetBot.Action.new()
	a.interact = true
	return a


## One tick of the whole session: every client builds and predicts its frame (its packets go up with the
## delay), the due packets reach the host, the host ticks (its own input: r.action), the host's messages
## go down with the delay and the due ones are delivered in order. Inputs are set per tick by the caller
## (c.action, r.action) and kept.
func _tick(r: Rig, n: int = 1) -> void:
	for i: int in n:
		var next: int = r.s.tick + 1
		for c: Client in r.clients:
			if not c.s.active or not c.ticking or c.s.over:
				continue
			c.s.tick += 1
			var a: NetBot.Action = c.action if c.action != null else idle_for(c.s.local.player)
			if c.action != null and not c.action.aiming:
				c.action.mouse = c.s.local.player.sim_position
			c.s.client.tick(a)
			if c.action != null:
				c.action.op = null  # a request goes once
				c.action.dash = false
			for msg: Array in c.s.take_for(1):
				r.up.append([next + r.delay, c.peer, msg[1], msg[2]])
		var rest: Array[Array] = []
		for u: Array in r.up:
			var due: int = u[0]
			if due > next:
				rest.append(u)
				continue
			var kind: String = u[2]
			var peer: int = u[1]
			var payload: PackedByteArray = u[3]
			if kind == "input":
				r.host.on_input(peer, payload)
		r.up = rest
		r.s.tick = next
		r.host._last_take_usec = Time.get_ticks_usec() - 16667  # one tick of real time per host tick
		var ha: NetBot.Action = r.action if r.action != null else idle_for(r.s.local.player)
		if r.action != null and not r.action.aiming:
			r.action.mouse = r.s.local.player.sim_position
		r.host.tick(ha, Time.get_ticks_msec())
		if r.action != null:
			r.action.op = null
			r.action.dash = false
		_note_hp(r)
		for c: Client in r.clients:
			for msg: Array in r.s.take_for(c.peer):
				var bytes: PackedByteArray = msg[2]
				var kind: String = msg[1]
				var seen: int = r.bytes_by_kind.get(kind, 0)
				r.bytes_by_kind[kind] = seen + bytes.size()
				r.down.append([next + r.delay, c.peer, kind, bytes])
		var later: Array[Array] = []
		for d: Array in r.down:
			var due: int = d[0]
			if due > next:
				later.append(d)
				continue
			var peer: int = d[1]
			var kind: String = d[2]
			var payload: PackedByteArray = d[3]
			for c: Client in r.clients:
				if c.peer == peer:
					_deliver(c, kind, payload)
		r.down = later


func _note_hp(r: Rig) -> void:
	for map: int in r.host.arenas:
		for h: HereticSim in r.host.arenas[map].heretics:
			var by: Dictionary = r.hp_at.get(h.id, {})
			by[r.s.tick] = h.hp
			r.hp_at[h.id] = by


func _deliver(c: Client, kind: String, payload: PackedByteArray) -> void:
	if c.s.over:
		return
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
		"enemies", "enemy_key":
			c.batches.append(NetProtocol.decode_enemies(payload))
			c.s.client._apply_enemies(payload, kind == "enemy_key")
		"shots":
			c.shot_events.append_array(NetProtocol.decode_shots(payload).events)
			c.s.client.on_shots(payload)


## The fight spot on the surface.
static func spot(r: Rig) -> Vector2:
	return r.surface.data.altar_center_px() + FIGHT_OFFSET


## The batches client `c` got whose heretic HP differ from the host's HP at that batch's tick.
static func hp_mismatches(r: Rig, c: Client) -> int:
	var n: int = 0
	for b: NetProtocol.EnemyBatch in c.batches:
		for e: NetProtocol.EnemyState in b.enemies:
			var by: Dictionary = r.hp_at.get(e.id, {})
			if not by.has(b.tick):
				continue
			var want: int = by[b.tick]
			if want != e.hp:
				n += 1
	return n


## `seen` (a client's HP values in order) is a part of `all` (the host's) in the same order, from its
## first value to its last (a batch can miss a value between two hits, never invent or reorder one).
static func _follows(seen: Array, all: Array) -> bool:
	if seen.is_empty() or all.is_empty() or seen[0] != all[0] or seen.back() != all.back():
		return false
	var i: int = 0
	for v: Variant in seen:
		while i < all.size() and all[i] != v:
			i += 1
		if i >= all.size():
			return false
	return true


## Frees a rig's worlds and sessions (each holds four or more worlds; the next check makes its own).
func _free_rig(r: Rig) -> void:
	var nodes: Array[Node] = [r.surface, r.dungeon, r.s]
	for c: Client in r.clients:
		nodes.append_array([c.surface, c.dungeon, c.s])
	for n: Node in nodes:
		if is_instance_valid(n):
			_owned_nodes.erase(n)
			n.get_parent().remove_child(n)
			n.free()


## The host's HP sequence of heretic `id` (consecutive repeats dropped).
static func host_hp_seq(r: Rig, id: int) -> Array:
	var out: Array = []
	var by: Dictionary = r.hp_at.get(id, {})
	var ticks: Array = by.keys()
	ticks.sort()
	for t: Variant in ticks:
		var hp: int = by[t]
		var last: int = out.back() if not out.is_empty() else -1
		if hp != last:
			out.append(hp)
	return out


## The client's prediction counters that must stay 0 (what the prediction itself got wrong).
func check_prediction(label: String, c: Client) -> void:
	var p: Prediction = c.s.client.prediction
	check(p.corrections == 0 and p.facing_corrections == 0 and p.action_corrections == 0 and p.vitals_corrections == 0,
		"%s: the prediction got only the host's events wrong (corrections %d, facing %d, action %d, vitals %d; host events %d)" % [
		label, p.corrections, p.facing_corrections, p.action_corrections, p.vitals_corrections, p.event_corrections])


# --- the host's checks against a malicious client ----------------------------------------------------

## Requests handed straight to run_frame (no wire): the host judges from its own state.
func _check_malicious() -> void:
	var r: Rig = _rig()
	await await_frames(1)
	var f: Vector2 = spot(r)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(f)
	var c: Client = await _join_quiet(r, 101, "paladin", f + Vector2(70, 0))
	var m: NetMember = hm(r, c)
	m.player.inventory.select(WEAPON_SLOT)
	# Far away: the swing is legal (an adjacent tile), but the host measures from where it has the player.
	var cell: Vector2i = Aim.feet_cell(m.player.sim_position) + Vector2i(-1, 0)
	var use: NetProtocol.InputFrame = _use(Config.MAP_SURFACE, cell, WEAPON_SLOT, Combat.aim_code(h.pos - m.player.sim_position))
	r.host.run_frame(m, use)
	for i: int in PlayerSim.action_ticks(RigData.Anim.SWORD):
		r.host.run_frame(m, NetProtocol.InputFrame.new())
	check(m.combat_count("attacks") == 1 and h.hp == Config.HERETIC_HP,
		"a swing from 70 px away hits nothing: the reach is measured from the host's player (%d attacks, hp %d)" % [
		m.combat_count("attacks"), h.hp])
	r.host.run_frame(m, _use(Config.MAP_SURFACE, Aim.feet_cell(h.pos), WEAPON_SLOT, 128))
	check_eq(m.refused(WorldItems.WHY_REACH), 1, "a use aimed at the heretic's own tile 4 tiles off: out of reach")
	# Too fast: a use on every frame of one packet starts one swing per swing length; the rest are busy.
	m.player.teleport(h.pos + Vector2(14, 0))
	var frames: Array[NetProtocol.InputFrame] = []
	for i: int in 40:
		frames.append(_use(Config.MAP_SURFACE, Aim.feet_cell(m.player.sim_position) + Vector2i(-1, 0), WEAPON_SLOT, 128))
	var hits_before: int = arena.stat("heretic_hits")
	for fr: NetProtocol.InputFrame in frames:
		r.host.run_frame(m, fr)
	var swing: int = PlayerSim.action_ticks(RigData.Anim.SWORD)
	check_eq(m.refused("busy"), 40 - ceili(40.0 / swing), "40 uses in 40 frames: %d start (one per %d-frame swing), the rest busy" % [
		ceili(40.0 / swing), swing])
	check(arena.stat("heretic_hits") - hits_before <= 1, "so at most one sword hit lands in 40 frames")
	arena.hit_heretic(h, Config.HERETIC_HP)  # out of the way for the rest
	# While down: every tile request is refused, a dash and a move do nothing.
	for i: int in swing:
		r.host.run_frame(m, NetProtocol.InputFrame.new())
	m.player.take_hit(Config.PLAYER_HP_MAX)
	check_eq(m.player.vitals.life, Vitals.Life.DOWN, "the member is down")
	var at: Vector2 = m.player.sim_position
	var refused_before: int = m.refused(SessionHost.WHY_DOWN)
	r.host.run_frame(m, _use(Config.MAP_SURFACE, Aim.feet_cell(at) + Vector2i(-1, 0), WEAPON_SLOT, 128))
	r.host.run_frame(m, _op(NetProtocol.Op.PICKUP, Config.MAP_SURFACE, Aim.feet_cell(at) + Vector2i(1, 0)))
	r.host.run_frame(m, _op(NetProtocol.Op.DROP, Config.MAP_SURFACE, Aim.feet_cell(at) + Vector2i(1, 0)))
	r.host.run_frame(m, _op(NetProtocol.Op.TRAVEL, Config.MAP_SURFACE, SurfaceGen.entrance_rect(r.surface.data).position))
	check_eq(m.refused(SessionHost.WHY_DOWN) - refused_before, 4, "down: use, pick up, drop and travel are refused (\"down\")")
	var dash: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i(1, 0))
	dash.dash = true
	r.host.run_frame(m, dash)
	r.host.run_frame(m, NetProtocol.InputFrame.new(0, Vector2i(0, 1)))
	check(m.player.sim_position == at and m.player.vitals.dash_ticks == 0, "down: no dash, no step (still at %s)" % m.player.sim_position)
	# A revive from too far: a member holding F 60 px off adds nothing; next to it, it revives.
	var b: Client = await _join_quiet(r, 102, "miner", at + Vector2(60, 0))
	var mb: NetMember = hm(r, b)
	var held: NetProtocol.InputFrame = NetProtocol.InputFrame.new()
	held.interact = true
	for i: int in Config.REVIVE_TICKS + 30:
		r.host.run_frame(mb, held)
		arena.step(r.host.players_on(Config.MAP_SURFACE))
	check(m.player.vitals.life == Vitals.Life.DOWN and m.player.vitals.revive_ticks == 0,
		"F held from 60 px for %d ticks: no revive progress at all" % (Config.REVIVE_TICKS + 30))
	mb.player.teleport(at + Vector2(Config.REVIVE_REACH_PX - 4.0, 0))
	var ticks: int = 0
	while m.player.vitals.life == Vitals.Life.DOWN and ticks < Config.REVIVE_TICKS + 5:
		r.host.run_frame(mb, held)
		arena.step(r.host.players_on(Config.MAP_SURFACE))
		ticks += 1
	check(m.player.vitals.alive() and ticks == Config.REVIVE_TICKS, "within %.0f px: revived after %d ticks (%d)" % [
		Config.REVIVE_REACH_PX, Config.REVIVE_TICKS, ticks])
	# Another map's bag: a bag in the dungeon; a surface player's pick up naming the dungeon is "wrong map",
	# naming the surface finds nothing there.
	var d: WorldData = r.dungeon.data
	var bag_feet: Vector2 = DungeonGen.arrival_point(d) + Vector2(0, 32)
	var inv: Inventory = Inventory.new()
	inv.add(&"stone_a", 10)
	var o: WorldItems.Outcome = WorldItems.death_drop(d, bag_feet, inv)
	for e: EditLog.WorldEdit in o.edits:
		r.host.apply_world_edit(e, Config.MAP_DUNGEON)
	var bag: Vector2i = o.edits[0].cell if o.ok() else Vector2i.ZERO
	check_eq(d.get_value(WorldData.Layer.PLACEABLE, bag), WorldData.PLACEABLE_BAG, "a bag lies in the dungeon")
	mb.player.teleport(_feet(bag + Vector2i(1, 0)))
	for t: int in Config.NET_OP_INTERVAL_TICKS * Config.NET_OP_BURST:
		mb.refill_ops()
	r.host.run_frame(mb, _op(NetProtocol.Op.PICKUP, Config.MAP_DUNGEON, bag))
	check_eq(mb.refused(WorldItems.WHY_WRONG_MAP), 1, "a surface player picking the dungeon's bag: wrong map")
	r.host.run_frame(mb, _op(NetProtocol.Op.PICKUP, Config.MAP_SURFACE, bag))
	check(d.get_value(WorldData.Layer.PLACEABLE, bag) == WorldData.PLACEABLE_BAG and mb.player.inventory.count_of(&"stone_a") == 0,
		"the same tile on its own map takes nothing of it; the bag stays (refusals %s)" % mb.ops_refused)
	_free_rig(r)


## A client joined without the per-tick loop (for run_frame checks): it is welcomed, nothing more.
func _join_quiet(r: Rig, peer: int, class_id: String, at: Vector2) -> Client:
	var c: Client = _join(r, peer, class_id, at, false)
	c.ticking = false
	await await_frames(1)
	return c


static func _feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * Config.TILE + Config.TILE / 2.0, cell.y * Config.TILE + Config.TILE - 2)


static func _op(op: int, map: int, cell: Vector2i, slot: int = 0) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = NetProtocol.InputFrame.new(0, Vector2i.ZERO)
	f.op = op
	f.map = map
	f.cell = cell
	f.slot = slot
	return f


static func _use(map: int, cell: Vector2i, slot: int, aim: int) -> NetProtocol.InputFrame:
	var f: NetProtocol.InputFrame = _op(NetProtocol.Op.USE, map, cell, slot)
	f.aim = aim
	return f


# --- flows -----------------------------------------------------------------------------------------

## The host (paladin, sword) and a client (archer, bow) fight one heretic; at every enemy batch the client
## gets, the heretic's HP is the host's at that batch's tick; both land hits; it dies on both.
func _check_two_fight_one() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var f: Vector2 = spot(r)
	var h: HereticSim = r.host.arenas[Config.MAP_SURFACE].spawn_heretic(f)
	r.s.local.player.teleport(f + Vector2(-18, 0))
	var c: Client = _join(r, 101, "archer", f + Vector2(72, 0))
	var ticks: int = 0
	while h.alive() and ticks < 900:
		r.action = swing_at(h.pos)
		c.action = swing_at(_drawn_foe(r, c, h.id, h.pos))
		_tick(r)
		ticks += 1
	_tick(r, 20)
	var hm1: NetMember = hm(r, c)
	check(not h.alive(), "the heretic died in %d ticks" % ticks)
	check(r.s.local.combat_count("hits") > 0 and hm1.combat_count("hits") > 0,
		"both landed hits (host sword %d, client bow %d)" % [r.s.local.combat_count("hits"), hm1.combat_count("hits")])
	check_eq(r.s.local.combat_count("kills") + hm1.combat_count("kills"), 1, "one kill")
	check(c.batches.size() > 5, "the client got enemy batches (%d)" % c.batches.size())
	check_eq(hp_mismatches(r, c), 0, "every batch the client got had the host's HP at that tick")
	var seen: Array = c.s.client.combat.hp_seen(h.id)
	check(_follows(seen, host_hp_seq(r, h.id)), "the client saw the heretic's HP go %s, in the host's order %s" % [seen,
		host_hp_seq(r, h.id)])
	var last: NetProtocol.EnemyBatch = c.batches.back()
	check(last.enemies.is_empty() or last.enemies[0].state == HereticSim.State.DEAD, "its last batch: the heretic dead or gone")
	check_prediction("two fight one / client", c)
	_free_rig(r)


## The heretic as client `c` draws it now (its position), or `fallback` when it has none.
func _drawn_foe(r: Rig, c: Client, id: int, fallback: Vector2) -> Vector2:
	if c.s.client.combat == null:
		return fallback
	c.s.client.combat.sample(float(r.s.tick - r.delay), SessionClient.interp_delay_ticks())
	for hh: HereticSim in c.s.client.combat.arena.heretics:
		if hh.id == id:
			return hh.pos
	return fallback


## A client's arrows alone kill a heretic: every hit is its own, the shot events reach it (let go, stopped
## at the heretic), and the client draws arrows in the air between them.
func _check_arrow_kill() -> void:
	var r: Rig = _rig("cleric")
	r.delay = 3
	await await_frames(1)
	var f: Vector2 = spot(r)
	var h: HereticSim = r.host.arenas[Config.MAP_SURFACE].spawn_heretic(f)
	r.s.local.player.teleport(r.surface.data.altar_center_px() + Vector2(0, 40))  # in the light, out of sight
	var c: Client = _join(r, 101, "archer", f + Vector2(80, 0))
	var drawn_shots: int = 0
	var ticks: int = 0
	var worst_gap: float = 0.0
	while h.alive() and ticks < 900:
		var drawn: Vector2 = _drawn_foe(r, c, h.id, h.pos)
		if h.walking:
			worst_gap = maxf(worst_gap, drawn.distance_to(h.pos))
		c.action = swing_at(drawn)
		_tick(r)
		drawn_shots = maxi(drawn_shots, c.s.client.combat.arena.shots.size())
		ticks += 1
	_tick(r, 30)
	var m: NetMember = hm(r, c)
	check(not h.alive() and m.combat_count("kills") == 1 and r.s.local.combat_count("hits") == 0,
		"the archer's arrows killed it alone in %d ticks (%d hits)" % [ticks, m.combat_count("hits")])
	var spawns: int = 0
	var at_heretic: int = 0
	for e: NetProtocol.ShotEvent in c.shot_events:
		if e.kind == NetProtocol.ShotEvent.Kind.SPAWN and e.owner == m.slot and e.item == &"bow":
			spawns += 1
		elif e.kind == NetProtocol.ShotEvent.Kind.END and NetProtocol.SHOT_STOPS[e.why] == "heretic":
			at_heretic += 1
	check(spawns >= ceili(float(Config.HERETIC_HP) / 12.0) and at_heretic == m.combat_count("hits"),
		"shot events: %d arrows let go by its slot, %d stopped at the heretic (= its hits)" % [spawns, at_heretic])
	check(drawn_shots >= 1, "the client drew its arrows in the air")
	check_prediction("arrow kill / client", c)
	check(worst_gap > 0.0 and worst_gap <= Config.HERETIC_SPEED * (2 * r.delay + SessionClient.interp_delay_ticks() + 3) / 60.0,
		"a chasing heretic is drawn at most its speed x (delay + buffer) from the host's (%.1f px)" % worst_gap)
	note("arrow kill (3-tick delay each way): the chasing heretic was drawn up to %.1f px from where the host had it; the archer shot at that and killed it (host time, no rewind)" % worst_gap)
	_free_rig(r)


## A client goes down (a heretic's knife, start HP 12) and the host holds F next to it: back up after
## Config.REVIVE_TICKS host ticks, seen by the client; the reverse; a cleric revives at once.
func _check_revives() -> void:
	var start: Dictionary[String, int] = {"archer": 12}
	var r: Rig = _rig("paladin", false, start)
	await await_frames(1)
	var f: Vector2 = spot(r)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(f)
	r.s.local.player.teleport(r.surface.data.altar_center_px() + Vector2(0, 40))
	var c: Client = _join(r, 101, "archer", f + Vector2(16, 0))
	var m: NetMember = hm(r, c)
	var ticks: int = 0
	while m.player.vitals.alive() and ticks < 200:
		_tick(r)
		ticks += 1
	_tick(r, 3)
	check(m.player.vitals.life == Vitals.Life.DOWN and c.s.local.player.vitals.life == Vitals.Life.DOWN,
		"the heretic downed the client (12 HP) after %d ticks; the client shows itself down" % ticks)
	arena.hit_heretic(h, Config.HERETIC_HP)  # out of the way (it would go for the reviver)
	r.s.local.player.teleport(m.player.sim_position + Vector2(12, 0))
	r.action = holding_f()
	var revive_ticks: int = 0
	var mid_seen: int = 0
	while m.player.vitals.life == Vitals.Life.DOWN and revive_ticks < Config.REVIVE_TICKS + 10:
		_tick(r)
		revive_ticks += 1
		mid_seen = maxi(mid_seen, c.s.local.player.vitals.revive_ticks)
	r.action = null
	_tick(r, 3)
	check(m.player.vitals.alive() and revive_ticks == Config.REVIVE_TICKS, "the host (paladin) revived it in %d ticks (%d)" % [
		Config.REVIVE_TICKS, revive_ticks])
	check(mid_seen > Config.REVIVE_TICKS / 2, "the client saw the revive's progress (up to %d ticks)" % mid_seen)
	check(c.s.local.player.vitals.alive() and c.s.local.player.vitals.hp == Config.REVIVE_HP,
		"the client is up again with %d HP" % Config.REVIVE_HP)
	check(c.s.client.prediction.event_corrections >= 2, "going down and getting up were the host's events (%d)" % c.s.client.prediction.event_corrections)
	check_prediction("revived client", c)
	# The reverse: the host is down, the archer holds F next to it.
	_tick(r, Config.HURT_INVULN_TICKS + 5)
	r.s.local.player.take_hit(Config.PLAYER_HP_MAX)
	_tick(r, 2)
	c.action = holding_f()
	var back_ticks: int = 0
	while not r.s.local.player.vitals.alive() and back_ticks < Config.REVIVE_TICKS + 10:
		_tick(r)
		back_ticks += 1
	c.action = null
	_tick(r, 3)
	check(r.s.local.player.vitals.alive() and absi(back_ticks - Config.REVIVE_TICKS) <= 2,
		"the client (archer) revived the host in %d ticks (%d: its F reaches the host a tick or two late)" % [Config.REVIVE_TICKS, back_ticks])
	# A cleric revives at once.
	var cl: Client = _join(r, 102, "cleric", m.player.sim_position + Vector2(-14, 0))
	_tick(r, Config.HURT_INVULN_TICKS + 5)
	m.player.take_hit(Config.PLAYER_HP_MAX)
	_tick(r, 2)
	cl.action = holding_f()
	var instant: int = 0
	while not m.player.vitals.alive() and instant < 20:
		_tick(r)
		instant += 1
	cl.action = null
	_tick(r, 3)
	check(m.player.vitals.alive() and instant <= 2, "a cleric revives at once (%d ticks after its F frame was sent)" % instant)
	check(c.s.local.player.vitals.alive(), "the archer sees itself up again")
	check_prediction("cleric reviver", cl)
	_free_rig(r)


## A client gives up while down: its bag (world edits) reaches everyone on the map; another client takes
## it; the dead one respawns at its spawn slot on the very frame the host does (no correction).
func _check_death_bag() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var f: Vector2 = spot(r)
	var a: Client = _join(r, 101, "herbalist", f)
	var b: Client = _join(r, 102, "miner", f + Vector2(16, 0))
	var ma: NetMember = hm(r, a)
	var mb: NetMember = hm(r, b)
	ma.player.inventory.add(&"stone_a", 20)
	ma.player.inventory.add(&"wild_healing", 6)
	ma.inventory_dirty = true
	_tick(r, 3)
	ma.player.take_hit(Config.PLAYER_HP_MAX)
	_tick(r, 3)
	a.action = holding_f()
	var t: int = 0
	while ma.player.vitals.life != Vitals.Life.DEAD and t < Config.GIVE_UP_HOLD_TICKS + 20:
		_tick(r)
		t += 1
	a.action = null
	_tick(r, 3)
	var bag: Vector2i = _find_bag(r.surface.data)
	check(ma.player.vitals.life == Vitals.Life.DEAD and r.surface.data.get_value(WorldData.Layer.PLACEABLE, bag) == WorldData.PLACEABLE_BAG,
		"held F %d ticks while down: dead, a bag at %s" % [t, bag])
	check(ma.player.inventory.count_of(&"stone_a") == 10 and ma.player.inventory.count_of(&"wild_healing") == 3
		and ma.player.inventory.count_of(&"sickle") == 1, "half of each stack fell (the weapon stays): %s" % ma.player.inventory.describe())
	for c: Client in [a, b]:
		check(c.surface.data.get_value(WorldData.Layer.PLACEABLE, bag) == WorldData.PLACEABLE_BAG
			and c.surface.data.drops.size() == r.surface.data.drops.size() and c.surface.data.content_hash() == r.surface.data.content_hash(),
			"peer %d: the bag and its drops came as edits (world = host's)" % c.peer)
	b.action = NetBot.Action.new()
	b.action.mouse = _feet(bag) - Vector2(0, 2)
	b.action.aiming = true
	_tick(r, 2)
	b.action.op = NetProtocol.InputFrame.new()
	b.action.op.op = NetProtocol.Op.PICKUP
	_tick(r, 4)
	b.action = null
	_tick(r, 3)
	check(mb.player.inventory.count_of(&"stone_a") == 10 and mb.player.inventory.count_of(&"wild_healing") == 3
		and r.surface.data.get_value(WorldData.Layer.PLACEABLE, bag) == WorldData.PLACEABLE_NONE,
		"the miner took the whole bag (%s); it is gone" % mb.player.inventory.describe())
	check(b.s.local.player.inventory.count_of(&"stone_a") == 10 and b.surface.data.content_hash() == r.surface.data.content_hash()
		and a.surface.data.content_hash() == r.surface.data.content_hash(), "both clients see it gone; the miner's inventory came back")
	var left: int = Config.RESPAWN_TICKS + 10
	while not ma.player.vitals.alive() and left > 0:
		_tick(r)
		left -= 1
	_tick(r, 4)
	check(ma.player.vitals.alive() and ma.player.sim_position == r.surface.spawn_point(ma.slot)
		and a.s.local.player.sim_position == ma.player.sim_position and a.s.client.prediction.respawns == 1,
		"respawned at its spawn slot %s; the client predicted the same respawn" % ma.player.sim_position)
	check_prediction("dead and respawned client", a)
	_free_rig(r)


## The one bag tile of `data` (Walls.NO_CELL when none).
static func _find_bag(data: WorldData) -> Vector2i:
	for y: int in data.size.y:
		for x: int in data.size.x:
			if data.get_value(WorldData.Layer.PLACEABLE, Vector2i(x, y)) == WorldData.PLACEABLE_BAG:
				return Vector2i(x, y)
	return Walls.NO_CELL


## A client breaks the shrine: the dungeon spawns no more (for everyone: there is one host arena), every
## client below gets the broken shrine as edits, a late arrival gets it in its map snapshot. Meanwhile a
## surface player gets no enemy or shot message of the dungeon.
func _check_shrine_and_maps() -> void:
	var r: Rig = _rig("cleric", true)
	await await_frames(1)
	var d: WorldData = r.dungeon.data
	var da: Arena = r.host.arenas[Config.MAP_DUNGEON]
	var rect: Rect2i = da.shrine_rect()
	check(rect.has_area() and da.spawning, "the dungeon has a standing shrine and spawns")
	r.s.local.player.teleport(r.surface.data.altar_center_px() + Vector2(0, 40))
	var up: Client = _join(r, 103, "herbalist", r.surface.data.altar_center_px() + Vector2(24, 40))
	var a: Client = _join(r, 101, "paladin")
	var b: Client = _join(r, 102, "archer")
	var shrine_side: Vector2 = Vector2((rect.position.x + rect.size.x / 2.0) * Config.TILE, (rect.end.y + 1) * Config.TILE - 2)
	for c: Client in [a, b]:
		var m: NetMember = hm(r, c)
		r.host.move_to_map(m, Config.MAP_DUNGEON)
		m.player.teleport(shrine_side + (Vector2(0, 0) if c == a else Vector2(20, 0)))
	_tick(r, 4)
	check(a.s.local.map_id == Config.MAP_DUNGEON and b.s.local.map_id == Config.MAP_DUNGEON, "two clients went down")
	da.shrine_hp = 2 * 14 + 1  # three sword hits
	var spawned_before: int = da.stat("spawned")
	_tick(r, Config.HERETIC_SPAWN_INTERVAL_TICKS + 2)
	var spawned_open: int = da.stat("spawned") - spawned_before
	check(spawned_open >= 1, "with the shrine standing the dungeon spawned (%d)" % spawned_open)
	var shrine_mid: Vector2 = Vector2(rect.get_center() * Config.TILE)
	var t: int = 0
	while da.shrine_rect().has_area() and t < 400:
		a.action = swing_at(shrine_mid)
		b.action = swing_at(shrine_mid)
		_tick(r)
		t += 1
	a.action = null
	b.action = null
	_tick(r, 6)
	check(not da.shrine_rect().has_area() and da.shrine_hp == 0, "the client paladin and archer broke the shrine in %d ticks" % t)
	var broken_by: int = hm(r, a).combat_count("attacks") + hm(r, b).combat_count("attacks")
	check(broken_by > 0, "by their attacks (%d)" % broken_by)
	for c: Client in [a, b]:
		check(c.dungeon.data.count_value(WorldData.Layer.PLACEABLE, WorldData.PLACEABLE_SHRINE_BROKEN) == rect.size.x * rect.size.y
			and c.dungeon.data.content_hash() == d.content_hash(), "peer %d: the broken shrine came as edits (dungeon = host's)" % c.peer)
		check_eq(c.s.client.combat.shrine_hp_at(float(r.s.tick)), 0, "peer %d: its shrine HP is 0" % c.peer)
	var after: int = da.stat("spawned")
	_tick(r, 3 * Config.HERETIC_SPAWN_INTERVAL_TICKS)
	check(not da.spawns_now() and da.stat("spawned") == after,
		"three spawn intervals later: no new heretic in the dungeon (spawned %d -> %d)" % [after, da.stat("spawned")])
	# The surface player got nothing of the dungeon's combat; the two below did.
	var upr: SessionClient = up.s.client
	check(upr.enemy_msgs_on(Config.MAP_DUNGEON) == 0 and upr.shot_msgs_on(Config.MAP_DUNGEON) == 0
		and upr.combat.other_map == 0, "the surface player got no dungeon enemy or shot message (enemy %d, shot %d)" % [
		upr.enemy_msgs_on(Config.MAP_DUNGEON), upr.shot_msgs_on(Config.MAP_DUNGEON)])
	check(a.s.client.enemy_msgs_on(Config.MAP_DUNGEON) > 0 and b.s.client.shot_msgs_on(Config.MAP_DUNGEON) > 0,
		"the two below got the dungeon's enemies (%d) and shots (%d)" % [a.s.client.enemy_msgs_on(Config.MAP_DUNGEON),
		b.s.client.shot_msgs_on(Config.MAP_DUNGEON)])
	# The surface player goes down later: the shrine is broken in its map snapshot, its enemies = the host's.
	r.host.move_to_map(hm(r, up), Config.MAP_DUNGEON)
	_tick(r, 4)
	check(up.s.local.map_id == Config.MAP_DUNGEON and up.dungeon.data.count_value(WorldData.Layer.PLACEABLE,
		WorldData.PLACEABLE_SHRINE_BROKEN) == rect.size.x * rect.size.y, "a later arrival got the broken shrine in its map snapshot")
	check_eq(upr.combat.latest_hash(), r.host.combat_hash(Config.MAP_DUNGEON), "and the dungeon's heretics as the host has them")
	check_prediction("shrine breaker", a)
	_free_rig(r)


## A late joiner mid-fight: the welcome has the downed host (vitals), the keyframe after it the heretic in
## its wind-up with the host's numbers; drawn at once, the wind-up shows.
func _check_late_join_mid_fight() -> void:
	var r: Rig = _rig("paladin")
	await await_frames(1)
	var f: Vector2 = spot(r)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h: HereticSim = arena.spawn_heretic(f)
	var a: Client = _join(r, 101, "archer", f + Vector2(18, 0))
	r.s.local.player.teleport(f + Vector2(-60, 0))
	r.s.local.player.take_hit(Config.PLAYER_HP_MAX)
	var t: int = 0
	while not (h.state == HereticSim.State.ATTACK and h.state_ticks >= 10) and t < 400:
		a.action = swing_at(f)
		_tick(r)
		t += 1
	a.action = null
	check(h.state == HereticSim.State.ATTACK, "mid-fight: the heretic is %d ticks into an attack" % h.state_ticks)
	var late: Client = _join(r, 102, "cleric", null, false)
	check(late.s.active, "a late joiner came in")
	var on_late: NetMember = late.s.members[r.s.local.slot]
	late.s.client.draw_others()
	check(on_late.interp.latest().vitals != null and on_late.interp.latest().vitals.life == Vitals.Life.DOWN,
		"its welcome had the host down")
	check_eq(late.s.client.combat.latest_hash(), r.host.combat_hash(Config.MAP_SURFACE),
		"its keyframe after the welcome: the heretic as the host has it")
	late.s.client.combat.sample(float(r.s.tick - r.delay), SessionClient.interp_delay_ticks())
	var shown: HereticSim = null
	for hh: HereticSim in late.s.client.combat.arena.heretics:
		if hh.id == h.id:
			shown = hh
	check(shown != null and shown.state == HereticSim.State.ATTACK and absi(shown.state_ticks - h.state_ticks) <= 1
		and shown.hp == h.hp, "drawn at once: the wind-up %d ticks in (host %d), HP %d" % [shown.state_ticks if shown != null else -1,
		h.state_ticks, h.hp])
	_free_rig(r)


## Four players (host + 3 clients) fight two heretics with a 3-tick delay each way: everyone's HP view
## matches the host's at every batch, both die, the enemy view ends equal, the predictions only took host
## events. Also measured: how far a client draws a heretic from where the host has it (delay + buffer).
func _check_four_fight() -> void:
	var r: Rig = _rig("paladin")
	r.delay = 3
	await await_frames(1)
	var f: Vector2 = spot(r)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	var h1: HereticSim = arena.spawn_heretic(f)
	var h2: HereticSim = arena.spawn_heretic(f + Vector2(48, 0))
	r.s.local.player.teleport(f + Vector2(-18, 0))
	var cs: Array[Client] = [_join(r, 101, "archer", f + Vector2(24, -60)), _join(r, 102, "miner", f + Vector2(66, 0)),
		_join(r, 103, "cleric", f + Vector2(24, 70))]
	var worst_gap: float = 0.0
	var t: int = 0
	while (h1.alive() or h2.alive()) and t < 1500:
		var target: HereticSim = h1 if h1.alive() else h2
		r.action = swing_at(target.pos)
		for c: Client in cs:
			var mine: HereticSim = h2 if (c.peer == 102 and h2.alive()) or not h1.alive() else h1
			var drawn: Vector2 = _drawn_foe(r, c, mine.id, mine.pos)
			worst_gap = maxf(worst_gap, drawn.distance_to(mine.pos))
			c.action = swing_at(drawn)
		_tick(r)
		t += 1
	r.action = null
	for c: Client in cs:
		c.action = null
	_tick(r, Config.HERETIC_CORPSE_TICKS + 60)
	check(not h1.alive() and not h2.alive(), "four players killed two heretics in %d ticks" % t)
	var kills: int = r.s.local.combat_count("kills")
	for c: Client in cs:
		kills += hm(r, c).combat_count("kills")
		check_eq(hp_mismatches(r, c), 0, "four/peer %d: every batch had the host's HP at that tick" % c.peer)
		check(_follows(c.s.client.combat.hp_seen(h1.id), host_hp_seq(r, h1.id))
			and _follows(c.s.client.combat.hp_seen(h2.id), host_hp_seq(r, h2.id)),
			"four/peer %d: both heretics' HP went the host's way (%s, %s)" % [c.peer, c.s.client.combat.hp_seen(h1.id),
			c.s.client.combat.hp_seen(h2.id)])
		check_eq(c.s.client.combat.latest_hash(), r.host.combat_hash(Config.MAP_SURFACE), "four/peer %d: its last enemy view = the host's" % c.peer)
		c.s.client.combat.sample(float(r.s.tick - r.delay), SessionClient.interp_delay_ticks())
		check(c.s.client.combat.arena.heretics.is_empty() and r.host.arenas[Config.MAP_SURFACE].heretics.is_empty(),
			"four/peer %d: the corpses are gone on the host and from its picture" % c.peer)
		check_eq(c.s.local.player.sim_position, hm(r, c).player.sim_position, "four/peer %d: where the host has it" % c.peer)
		check_prediction("four/peer %d" % c.peer, c)
	check_eq(kills, 2, "two kills")
	var total: int = 0
	for k: String in r.bytes_by_kind:
		total += r.bytes_by_kind[k]
	note("four fight, host -> 3 clients over %d ticks: %s (all %d B)" % [r.s.tick, r.bytes_by_kind, total])
	_free_rig(r)


# --- the telegraph against the delay ---------------------------------------------------------------

## A client stands in a heretic's reach; the heretic starts its attack at host tick T. With a one-way delay
## of D ticks, the client draws the wind-up from tick T + D on (the batch goes at once, the wind-up is
## drawn fresh); a dash pressed R ticks after that dodges the knife (lands at T + 30) while the dash frame
## reaches the host by then: R <= 29 - 2 D. Measured for D = 0, 3, 6, 9 by trying every R.
func _check_telegraph_window() -> void:
	var lines: PackedStringArray = []
	for d: int in [0, 3, 6, 9]:
		var expect: int = Config.HERETIC_TELEGRAPH_TICKS - 1 - 2 * d
		var early: Array = await _dodge_try(d, 0)
		var last_in: Array = await _dodge_try(d, expect)
		var too_late: Array = await _dodge_try(d, expect + 1)
		var seen_after: int = last_in[1]
		var e0: bool = early[0]
		var l0: bool = last_in[0]
		var t0: bool = too_late[0]
		var latest: int = expect if e0 and l0 and not t0 else -1
		check(e0 and l0 and not t0,
			"delay %d ticks each way: a dash pressed 0 or %d ticks after the wind-up shows dodges, %d ticks after is hit (%s %s %s)" % [
			d, expect, expect + 1, early[0], last_in[0], too_late[0]])
		check_eq(seen_after, d, "delay %d: the wind-up shows %d ticks after the host started it" % [d, d])
		lines.append("one-way %d ms: wind-up seen %d ms after it started, dash still in time up to %d ms after (%d ms without the fresh wind-up)" % [
			roundi(d * 1000.0 / 60.0), roundi(seen_after * 1000.0 / 60.0), roundi((latest + 1) * 1000.0 / 60.0),
			roundi((latest + 1 - SessionClient.interp_delay_ticks()) * 1000.0 / 60.0)])
	note("telegraph %d ms, host time, no rewind: %s" % [roundi(Config.HERETIC_TELEGRAPH_TICKS * 1000.0 / 60.0), "; ".join(lines)])


## One try: [dodged, ticks from the attack's start until the client drew the wind-up].
func _dodge_try(d: int, react: int) -> Array:
	var r: Rig = _rig("cleric")
	r.delay = d
	await await_frames(1)
	var f: Vector2 = spot(r)
	var arena: Arena = r.host.arenas[Config.MAP_SURFACE]
	r.s.local.player.teleport(r.surface.data.altar_center_px() + Vector2(0, 40))
	var c: Client = _join(r, 101, "miner", f + Vector2(16, 0), false)
	var m: NetMember = hm(r, c)
	var h: HereticSim = arena.spawn_heretic(f)
	h.cooldown = 0
	var start: int = -1
	var seen: int = -1
	var dashed: bool = false
	var hp: int = m.player.vitals.hp
	for t: int in 120:
		if start < 0 and h.state == HereticSim.State.ATTACK:
			start = r.s.tick
		if seen >= 0 and not dashed and r.s.tick >= seen + react:
			c.action = NetBot.Action.new()
			c.action.dir = Vector2i(1, 0)
			c.action.dash = true
			dashed = true
		elif dashed:
			c.action = null
		_tick(r)
		if start < 0 and h.state == HereticSim.State.ATTACK:
			start = r.s.tick
		if start >= 0 and seen < 0:
			c.s.client.combat.sample(float(r.s.tick - d), SessionClient.interp_delay_ticks())
			for hh: HereticSim in c.s.client.combat.arena.heretics:
				if hh.state == HereticSim.State.ATTACK:
					seen = r.s.tick
		if start >= 0 and r.s.tick > start + Config.HERETIC_TELEGRAPH_TICKS + 2:
			break
	var dodged: bool = m.player.vitals.hp == hp and start >= 0
	_free_rig(r)
	return [dodged, seen - start if seen >= 0 and start >= 0 else -1]


# --- the host's clock for a silent client --------------------------------------------------------

## A client that stops sending after a hit: its invulnerability still ends (the host steps it after
## Config.NET_HOST_STEPS_AFTER_TICKS); downed and silent, it still dies on time.
func _check_silent_client() -> void:
	var r: Rig = _rig("cleric")
	await await_frames(1)
	var c: Client = _join(r, 101, "miner", spot(r))
	var m: NetMember = hm(r, c)
	c.ticking = false
	m.player.take_hit(10)
	var t: int = 0
	while m.player.vitals.invuln_ticks > 0 and t < 200:
		_tick(r)
		t += 1
	check(m.player.vitals.invuln_ticks == 0 and t <= Config.HURT_INVULN_TICKS + Config.NET_HOST_STEPS_AFTER_TICKS + 2,
		"a silent client's invulnerability ended on host time after %d ticks (stepped by the host %d times)" % [t, m.host_steps])
	_tick(r, 10)
	m.player.take_hit(Config.PLAYER_HP_MAX)
	t = 0
	while m.player.vitals.life == Vitals.Life.DOWN and t < Config.DOWN_TICKS + 200:
		_tick(r)
		t += 1
	check(m.player.vitals.life == Vitals.Life.DEAD and t <= Config.DOWN_TICKS + Config.NET_HOST_STEPS_AFTER_TICKS + 2,
		"a silent downed client died after %d ticks (down time %d + the host's wait)" % [t, Config.DOWN_TICKS])
	c.ticking = true
	_tick(r, Config.RESPAWN_TICKS + 40)
	check(m.player.vitals.alive(), "and it respawned when it was due")
	_free_rig(r)
