class_name SessionBots
extends RefCounted
## Bot and test flow of the session (net/session.gd): the local action each tick (--bot script or
## the keys), starting the bots (host "go"), clients reporting "done", the host finishing a test
## session (--net-expect) and the clients settling and leaving, marker files and the result JSON
## (--net-out, SessionReport).

## Ticks a client lets pass after "finish" before it writes its result (the other players' drawn
## positions reach the last state).
const FINISH_SETTLE_TICKS: int = 12
## Ticks a leaving client keeps its connection so its last reliable messages go out.
const LEAVE_FLUSH_TICKS: int = 10
const HOST_DRAIN_SEC: float = 5.0

var s: NetSession
var bot: NetBot
var bots_started: bool = false
## Host: peers that finished their bot or left.
var done_peers: Array[int] = []
## Host: "finish" went out; the session ends when everybody left or after HOST_DRAIN_SEC.
var finishing: bool = false
## Client: ticks left before it writes its result and leaves (-1 = not finishing / not leaving).
var finish_wait: int = -1
var leave_wait: int = -1

var _drain_until_ms: int = 0
var _sent_done: bool = false


func _init(p_session: NetSession) -> void:
	s = p_session


func setup(script: String) -> void:
	if not script.is_empty():
		bot = NetBot.new()
		bot.parse(script)


func local_action() -> NetBot.Action:
	if bot != null:
		if bots_started:
			return bot.step()
		return NetBot.Action.new()
	var a: NetBot.Action = NetBot.Action.new()
	a.dir = Player.read_input()
	return a


func start_bots() -> void:
	if bots_started:
		return
	bots_started = true
	if s.role == NetSession.Role.HOST:
		for peer: int in s.host.remote_peers():
			s.send_go(peer)
	s.log_event("go", "players=%d" % s.members.size())


## Client: the host started the bots.
func on_go() -> void:
	if s.active:
		start_bots()


## Host: a client's bot finished its script.
func on_done(peer_id: int) -> void:
	if s.host.roster.has(peer_id) and not done_peers.has(peer_id):
		done_peers.append(peer_id)
		s.log_event("done", "peer=%d slot=%d done=%d" % [peer_id, s.host.roster.slot_of(peer_id), done_peers.size()])


## Host: a player who left will not finish a bot any more.
func note_gone(peer_id: int) -> void:
	if not done_peers.has(peer_id):
		done_peers.append(peer_id)


## Host, end of each tick: finish the test session when it is ready, end it once drained.
func host_after_tick(now: int) -> void:
	if finishing:
		if s.host.roster.count() <= 1 or now >= _drain_until_ms:
			s.end_session("finished", NetSession.EXIT_OK)
	elif _ready_to_finish():
		_host_finish(now)


func _ready_to_finish() -> bool:
	if s.options.net_expect < 0 or not bots_started or s.host.broadcast.dirty:
		return false
	if bot != null and not bot.finished:
		return false
	var refused_total: int = 0
	for key: String in s.host.refusals:
		refused_total += s.host.refusals[key]
	if done_peers.size() < s.options.net_expect or refused_total < s.options.net_expect_refused:
		return false
	for slot: int in s.members:
		if s.members[slot].gate != null and not s.members[slot].gate.waiting.is_empty():
			return false
	return s.host.settled()


func _host_finish(now: int) -> void:
	finishing = true
	_drain_until_ms = now + int(HOST_DRAIN_SEC * 1000.0)
	for peer: int in s.host.remote_peers():
		s.send_finish(peer)
	s.log_event("finish", "players=%d edits=%d world=%s" % [s.members.size(), s.edit_log.size(),
		s.world.data.content_hash().left(12)])
	write_result("finished")


## Client: the host is done; settle, write the result, leave.
func on_finish() -> void:
	if s.active and finish_wait < 0:
		finish_wait = FINISH_SETTLE_TICKS


## Client, end of each tick: report "done", leave, or finish.
func client_after_tick(action: NetBot.Action) -> void:
	# Done = the bot finished and the host has handled every frame (its final state includes them).
	if bot != null and bots_started and bot.finished and not _sent_done and not s.client.prediction.has_unacked():
		_sent_done = true
		s.send_done()
	if action.leave and leave_wait < 0:
		leave_wait = LEAVE_FLUSH_TICKS
		s.log_event("leaving", "slot=%d" % s.local.slot)
	if leave_wait >= 0:
		leave_wait -= 1
		if leave_wait < 0:
			s.end_session("left", NetSession.EXIT_OK)
			return
	if finish_wait >= 0:
		finish_wait -= 1
		if finish_wait < 0:
			s.end_session("finished", NetSession.EXIT_OK)


## Host: clients that finished their bot or left.
func done_count() -> int:
	return done_peers.size()


func write_result(reason: String) -> void:
	if s.options == null or s.options.net_out.is_empty():
		return
	if not SessionReport.write_json(s.options.net_out, s.instance_name(), s.result(reason)):
		printerr("EVENSONG_NET cannot write %s" % s.options.net_out.path_join(s.instance_name() + ".json"))


func mark(marker: String) -> void:
	s.log_event("mark", marker)
	if s.options != null and not s.options.net_out.is_empty():
		SessionReport.write_marker(s.options.net_out, s.instance_name(), marker, str(s.tick))
