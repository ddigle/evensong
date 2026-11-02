class_name NetPrayer
extends RefCounted
## M10b: a session client's picture of the host's prayer at the surface altar (net/session_client.gd keeps one). The host owns the
## prayer (net/session_host.gd: its Prayer, the offline rule); this mirror only takes its events (NetProtocol prayer message) and
## keeps what Main draws from: `mirror`, a Prayer whose state is set from the events, never stepped by its rules (its players by
## node instance id, its clock the host tick as this client last heard of it), so the circle, the lamps and the marks over the
## heads are drawn from it by the same code as offline and on the host (Main.show_prayer_from).
##
## The events carry the host's prayer clock they happened at, so ages (a lamp's flicker, the joined and left marks, the gather's
## creeping circle, a meditation's bar) are the host's at the same host tick. The local player's own turn is not: its prompt
## shows from the tick its TURN event arrived here and its window runs Config.PRAYER_ANSWER_WINDOW_TICKS from then (● R45: the
## window survives the round trip; the host takes the answer up to Config.PRAYER_ANSWER_LAG_TICKS after its own window). A key
## pressed from rest in that window becomes the ANSWER request (attach, the same rule the host's own player uses); then the prompt
## goes and the pressed key shows dim until the host's RESULT comes (Config.PRAYER_SENT_SHOW_TICKS at most): that key is all the
## client predicts (README "M10b 예측"). The local player's role (praying, meditating) comes from the events too: while it prays its
## frames do not move it (attach zeroes the keys, it faces the altar) as the host does not.
##
## Zeal: every player's (percent, the host tick it runs out) from the ZEAL events, wherever it is; each tick set on the players'
## skill states (Player.show_zeal: the mark over the head, the local HUD's icon and bar), none while dead. The prayer's own events
## are the surface's: on another map they are skipped (off_map), and the mirror is cleared when this client enters a map (the
## snapshot of the surface follows the entry).

## The mirror (Main draws it), the zeal by slot (x = percent, y = the host tick it runs out), the meditations under way by slot (the
## host tick they began), the slots by node id met in the prayer.
var mirror: Prayer = Prayer.new()
var zeal: Dictionary[int, Vector2i] = {}
var meditating: Dictionary[int, int] = {}
## The node id each slot's player had when the mirror met it (a player who left the session is still named by its slot).
var ids: Dictionary[int, int] = {}
## M10-fix: whether each slot's zeal is a prayer's (not only a meditation's: whose zeal blocks a new prayer; kept on the skill state
## should this client go on alone).
var zeal_prayer: Dictionary[int, bool] = {}
## M10-fix: the host tick of this client's welcome. A slot is reused: an event naming this client's own slot from then or before
## is its former player's (a participant who left the session), so the mirror keeps it under GHOST_ID - slot, never this player.
var welcomed_at: int = -1
const GHOST_ID: int = -100
## The tick the prayer's phase began (the gather: its START's; the turns: turn 0's) and the turn under way's (its TURN's).
var phase_tick: int = 0
var turn_tick: int = 0
## The local player's turn: its turn (-1 = none open here), the client tick its event arrived (its window runs from then), the key
## it sent (-1 = none) and when; the keys of its last frame (a press is from rest).
var my_turn: int = -1
var seen_at: int = 0
var sent_dir: int = -1
var sent_at: int = 0
var keys: Vector2i = Vector2i.ZERO
## Counters (results, tests): events taken, prayer events skipped off the surface, answers sent, results for this player's
## answers (by how: ok, wrong, late, left).
var taken: int = 0
var off_map: int = 0
var answers_sent: int = 0
var my_results: Dictionary[String, int] = {}


func setup(data: WorldData) -> void:
	mirror = Prayer.new()
	mirror.setup(data, data.world_seed if data != null else Config.DEFAULT_SEED)
	mirror.answers_from_keys = false
	mirror.directions.resize(Config.PRAYER_TURNS)
	mirror.directions.fill(-1)
	meditating.clear()
	my_turn = -1
	sent_dir = -1


## The surface's prayer is no more this client's to show (it entered a map, or is about to get the surface's snapshot): the
## mirror empty, its roles released. The zeal stays (it is the players', on every map).
func clear(s: NetSession) -> void:
	for slot: int in s.members:
		var p: Player = s.members[slot].player
		if p != null and is_instance_valid(p):
			p.prayer_role = Prayer.Role.NONE
	var data: WorldData = mirror.data
	setup(data)


## The player of slot `slot` on this machine (null: none, or freed).
static func _player(s: NetSession, slot: int) -> Player:
	var m: NetMember = s.members.get(slot, null)
	if m == null or m.player == null or not is_instance_valid(m.player):
		return null
	return m.player


## The node id of slot `slot`'s player `p` (null: gone from this machine: a `left` came before its prayer events; the id it had
## when the mirror met it, so its LEAVE still finds it).
func _id_of(p: Player, slot: int) -> int:
	if p != null:
		ids[slot] = p.get_instance_id()
		return ids[slot]
	return ids.get(slot, -1 - slot)


## `p` prays (Prayer.Role) facing `face`, or stops (NONE) when it had role `from`.
static func _role(p: Player, role: int, face: int = -1, from: int = -1) -> void:
	if p == null:
		return
	if role == Prayer.Role.NONE and p.prayer_role != from:
		return
	p.prayer_role = role
	if face >= 0:
		p.prayer_face = face


## Takes the events of a prayer message (`local_tick`: this client's tick now, the local player's window starts at it;
## `on_surface`: this client's map is the surface).
func apply(s: NetSession, events: Array[NetProtocol.PrayerEvent], local_tick: int, on_surface: bool) -> void:
	for e: NetProtocol.PrayerEvent in events:
		if e.kind == NetProtocol.PrayerEvent.Kind.ZEAL:
			if e.pct > 0:
				zeal[e.slot] = Vector2i(e.pct, e.tick + e.ticks)
				zeal_prayer[e.slot] = e.prayer_zeal
			else:
				zeal.erase(e.slot)
				zeal_prayer.erase(e.slot)
			taken += 1
			continue
		if not on_surface:
			off_map += 1
			continue
		_apply_one(s, e, local_tick)
		taken += 1


func _apply_one(s: NetSession, e: NetProtocol.PrayerEvent, local_tick: int) -> void:
	var m: Prayer = mirror
	# M10-fix: an event of this client's slot from its welcome or before is its former player's (the snapshot of a prayer under way).
	var ghost: bool = s.local != null and e.slot == s.local.slot and welcomed_at >= 0 and e.tick <= welcomed_at
	var p: Player = null if ghost else _player(s, e.slot)
	var id: int = GHOST_ID - e.slot if ghost else _id_of(p, e.slot)
	var local: bool = not ghost and s.local != null and e.slot == s.local.slot
	match e.kind:
		NetProtocol.PrayerEvent.Kind.START:
			_release_all(s)
			m.prayers = e.number
			m.phase = Prayer.Phase.GATHER
			phase_tick = e.tick
			m.phase_ticks = 0
			m.cleric_id = id
			m.members = [id]
			m.order = [id]
			m.left_at.clear()
			m.joined_at.clear()
			m.joined_at[id] = e.tick
			m.people.clear()
			if p != null:
				m.people[id] = p
			m.directions.fill(-1)
			m.lamps.fill(Prayer.Lamp.UNLIT)
			m.lamp_ticks.fill(e.tick)
			m.turn = -1
			m.turn_owner = 0
			m.turn_ticks = 0
			m.answered = false
			m.shown_until = 0
			my_turn = -1
			sent_dir = -1
			_role(p, Prayer.Role.PRAYING, e.face)
		NetProtocol.PrayerEvent.Kind.JOIN:
			if not m.members.has(id):
				m.members.append(id)
			m.order.erase(id)
			m.order.append(id)
			m.left_at.erase(id)
			m.joined_at[id] = e.tick
			if p != null:
				m.people[id] = p
			_role(p, Prayer.Role.PRAYING, e.face)
		NetProtocol.PrayerEvent.Kind.LEAVE:
			m.members.erase(id)
			m.left_at[id] = e.tick
			_role(p, Prayer.Role.NONE, -1, Prayer.Role.PRAYING)
			if local:
				my_turn = -1
				sent_dir = -1
		NetProtocol.PrayerEvent.Kind.STOP, NetProtocol.PrayerEvent.Kind.END:
			var r: Prayer.Result = Prayer.Result.new()
			r.stopped = e.kind == NetProtocol.PrayerEvent.Kind.STOP
			r.why = Prayer.STOP_WHYS[e.why] if r.stopped else ("" if e.pct > 0 else Prayer.WHY_FAITH)
			r.lit = m.lit_count() if r.stopped else e.lit
			r.participants = m.members.size() if r.stopped else e.participants
			r.zeal_pct = e.pct
			r.faith = e.faith
			r.lamps = m.lamps.duplicate()
			m.last = r
			_release_all(s)
			m.members.clear()
			m.phase = Prayer.Phase.IDLE
			if not r.stopped:
				m.turn = -1
				m.answered = false
			m.shown_until = e.tick + Config.PRAYER_RESULT_SHOW_TICKS
			my_turn = -1
			sent_dir = -1
		NetProtocol.PrayerEvent.Kind.TURN:
			if m.phase == Prayer.Phase.GATHER:
				phase_tick = e.tick
			m.phase = Prayer.Phase.TURNS
			m.turn = e.turn
			m.turn_owner = id
			m.directions[e.turn] = e.dir
			m.answered = false
			turn_tick = e.tick
			if local:
				my_turn = e.turn
				seen_at = local_tick  # the window runs from the event's arrival (a snapshot never holds this player's turn: it is new)
				sent_dir = -1
		NetProtocol.PrayerEvent.Kind.RESULT:
			m.lamps[e.turn] = Prayer.Lamp.LIT if e.why == 0 else Prayer.Lamp.OUT
			m.lamp_ticks[e.turn] = e.tick
			if e.turn == m.turn:
				m.answered = true
			if e.turn == my_turn:
				var how: String = Prayer.ANSWER_WHYS[e.why]  # a RESULT names no player: the turn is this player's own
				my_results[how] = my_results.get(how, 0) + 1
				my_turn = -1
				sent_dir = -1
		NetProtocol.PrayerEvent.Kind.MEDITATE:
			meditating[e.slot] = e.tick
			m.meditators[id] = 0
			if p != null:
				m.people[id] = p
			_role(p, Prayer.Role.MEDITATING, e.face)
		NetProtocol.PrayerEvent.Kind.MEDITATED, NetProtocol.PrayerEvent.Kind.BROKEN:
			meditating.erase(e.slot)
			m.meditators.erase(id)
			_role(p, Prayer.Role.NONE, -1, Prayer.Role.MEDITATING)


## Every participant's role back to none (the prayer ended or stopped).
func _release_all(s: NetSession) -> void:
	for slot: int in s.members:
		var p: Player = _player(s, slot)
		if p != null and mirror.members.has(p.get_instance_id()):
			_role(p, Prayer.Role.NONE, -1, Prayer.Role.PRAYING)


## A player left the session: its zeal, meditation and part go with it (offline the host's events say it left the prayer too).
func forget(slot: int) -> void:
	zeal.erase(slot)
	zeal_prayer.erase(slot)
	meditating.erase(slot)


## Once a client tick (`host_now`: the host tick as heard plus the ticks since): the mirror's clock and ages, the meditations' ticks,
## every player's zeal on its skill state (none while dead).
func tick(s: NetSession, host_now: int) -> void:
	var m: Prayer = mirror
	m.clock = host_now
	m.phase_ticks = maxi(host_now - phase_tick, 0) if m.running() else 0
	m.turn_ticks = maxi(host_now - turn_tick, 0) if m.phase == Prayer.Phase.TURNS else 0
	for slot: int in meditating:
		var p: Player = _player(s, slot)
		if p != null:
			m.meditators[p.get_instance_id()] = clampi(host_now - meditating[slot], 0, Config.MEDITATE_TICKS)
	for slot: int in s.members:
		var q: Player = _player(s, slot)
		if q == null:
			continue
		var z: Vector2i = zeal.get(slot, Vector2i.ZERO)
		var left: int = z.y - host_now if z.x > 0 else 0
		if left <= 0 or q.vitals.life == Vitals.Life.DEAD:
			q.show_zeal(0, 0)
		else:
			var from_prayer: bool = zeal_prayer.get(slot, true)
			q.show_zeal(z.x, left, from_prayer)


## The local player's turn's window is open for the frame built at client tick `local_tick` (1..window ticks after its event came,
## not answered yet).
func window_open(local_tick: int) -> bool:
	var elapsed: int = local_tick - seen_at
	return my_turn >= 0 and sent_dir < 0 and elapsed >= 1 and elapsed <= Config.PRAYER_ANSWER_WINDOW_TICKS


## The direction the local player's HUD prompts now (-1 = none): its turn open here and not answered.
func prompt(local_tick: int) -> int:
	if my_turn < 0 or sent_dir >= 0 or local_tick - seen_at >= Config.PRAYER_ANSWER_WINDOW_TICKS:
		return -1
	var d: int = mirror.directions[my_turn] if my_turn < mirror.directions.size() else -1
	return d


## The ticks of the local player's window left at client tick `local_tick` (its HUD bar).
func window_left(local_tick: int) -> int:
	return maxi(Config.PRAYER_ANSWER_WINDOW_TICKS - (local_tick - seen_at), 0) if prompt(local_tick) >= 0 else 0


## The key the local player sent for its turn, shown dim until the host's result (-1 = none).
func sent(local_tick: int) -> int:
	if sent_dir < 0 or local_tick - sent_at >= Config.PRAYER_SENT_SHOW_TICKS:
		return -1
	return sent_dir


## The local player's frame `f` built at client tick `local_tick` (session_client.gd, before its other requests): attach.
func attach_local(p: Player, f: NetProtocol.InputFrame, local_tick: int) -> void:
	var before: Vector2i = keys
	keys = f.dir
	var press: int = attach(p, f, before, window_open(local_tick), mirror.number(), my_turn)
	if f.op == NetProtocol.Op.ANSWER:
		answers_sent += 1
		sent_dir = press if press >= 0 else Prayer.WIRE_SEVERAL
		sent_at = local_tick


## While `p` prays (its machine's view): its move keys in frame `f` are no move (zeroed; it faces the altar, p.prayer_face) and a key
## pressed from rest (`before`: its last frame's keys) while its turn's window is `open` on this machine becomes the ANSWER request
## for prayer `number`, turn `turn` (two keys at once: Prayer.WIRE_SEVERAL), when the frame carries no other request. Returns the
## press (Prayer.answer_of: NO_PRESS when none or not praying). The host's own player and a client use it alike.
static func attach(p: Player, f: NetProtocol.InputFrame, before: Vector2i, open: bool, number: int, turn: int) -> int:
	if p.prayer_role != Prayer.Role.PRAYING:
		return Prayer.NO_PRESS
	var press: int = Prayer.answer_of(f.dir, before)
	f.dir = Vector2i.ZERO
	f.look = p.prayer_face
	f.dash = false
	if press == Prayer.NO_PRESS or not open or f.op != NetProtocol.Op.NONE:
		return Prayer.NO_PRESS
	f.op = NetProtocol.Op.ANSWER
	f.map = Config.MAP_SURFACE
	f.prayer_no = number & 0xFF
	f.turn = turn
	f.answer = Prayer.WIRE_SEVERAL if press == Prayer.SEVERAL else press
	return press


## Lamps as one word, a letter each (l lit, o out, u unlit: "llouuuuuu"; results, tests).
static func lamps_word(lamps: PackedInt32Array) -> String:
	var out: String = ""
	for s: int in lamps:
		out += "l" if s == Prayer.Lamp.LIT else ("o" if s == Prayer.Lamp.OUT else "u")
	return out


## M10b results: the mirror's phase, lamps and last result, every zeal (% and the host tick it runs out), counters.
func to_dict() -> Dictionary:
	var z: Dictionary = {}
	for slot: int in zeal:
		z[str(slot)] = [zeal[slot].x, zeal[slot].y]
	var last: Dictionary = {}
	if mirror.last != null:
		last = {"stopped": mirror.last.stopped, "why": mirror.last.why, "lit": mirror.last.lit,
			"participants": mirror.last.participants, "zeal": mirror.last.zeal_pct, "faith": mirror.last.faith,
			"lamps": lamps_word(mirror.last.lamps)}
	return {"phase": Prayer.PHASE_NAMES[mirror.phase], "prayers": mirror.prayers, "lamps": lamps_word(mirror.lamps), "last": last,
		"zeal": z, "taken": taken, "off_map": off_map, "answers_sent": answers_sent, "my_results": my_results}
