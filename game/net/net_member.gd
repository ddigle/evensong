class_name NetMember
extends RefCounted
## One player of a session: spawn slot, peer, class and the Player node in the world. The host
## gives a remote client's member an InputGate; a client gives every other player an Interpolation.
## M2b: the host keeps every member's inventory (Player.inventory, the one copy that counts), counts
## its requests (done, refused by reason) and rate-limits them (request tokens); a client's own
## member holds the inventory the host last sent it.

var slot: int = -1
## Peer id on the host (1 = the host itself); 0 on clients, which only know slots.
var peer_id: int = 0
var class_id: String = ""
var player: Player
## Host: input check of a remote client's frames.
var gate: InputGate
## Client: another player's received states.
var interp: Interpolation
## Host (M2b): request budget in ticks (a request costs Config.NET_OP_INTERVAL_TICKS, a tick adds 1,
## at most NET_OP_BURST requests' worth), requests handled by op name and refused by reason, and
## whether the owner needs its inventory sent.
var op_budget: int = OP_BUDGET_MAX
var ops_done: Dictionary[String, int] = {}
var ops_refused: Dictionary[String, int] = {}
var inventory_dirty: bool = false
## Actions this member's player started (host: simulated; client: seen), by action name.
var actions_seen: Dictionary[String, int] = {}
const OP_BUDGET_MAX: int = Config.NET_OP_BURST * Config.NET_OP_INTERVAL_TICKS
var _last_action: int = -1
var _last_action_start: float = -1.0


## A member with a new Player (driven by the session, not the keys) added under `parent`.
static func create(data: WorldData, parent: Node, p_slot: int, p_peer_id: int, p_class_id: String, pos: Vector2,
		facing: int) -> NetMember:
	var m: NetMember = NetMember.new()
	m.slot = p_slot
	m.peer_id = p_peer_id
	m.class_id = p_class_id
	m.player = Player.new()
	m.player.name = StringName("Player%d" % p_slot)
	m.player.local_input = false
	m.player.setup(data, p_class_id, pos, facing)
	parent.add_child(m.player)
	return m


## Removes the Player node from the world.
func remove_player() -> void:
	if is_instance_valid(player):
		player.get_parent().remove_child(player)
		player.free()
	player = null


func state() -> NetProtocol.PlayerState:
	var s: NetProtocol.PlayerState = NetProtocol.PlayerState.new()
	s.slot = slot
	s.pos = player.sim_position
	s.facing = player.facing
	s.walking = player.walking
	s.ack = gate.last_seq if gate != null else 0
	s.action = player.action_anim
	s.action_tick = player.action_tick
	s.held = player.held_id()
	return s


func info() -> NetProtocol.PlayerInfo:
	var i: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
	i.class_index = NetProtocol.class_index(class_id)
	i.state = state()
	return i


## Host: one tick of request budget.
func refill_ops() -> void:
	op_budget = mini(op_budget + 1, OP_BUDGET_MAX)


## Host: pays for a request; false when the member is over its rate.
func take_op() -> bool:
	if op_budget < Config.NET_OP_INTERVAL_TICKS:
		return false
	op_budget -= Config.NET_OP_INTERVAL_TICKS
	return true


## Counts an action this member's player started (host: run; client: its own, predicted).
func count_action(action: int) -> void:
	var name: String = RigData.ANIM_NAMES[action]
	var n: int = actions_seen.get(name, 0)
	actions_seen[name] = n + 1


func count_done(op_name: String) -> void:
	var n: int = ops_done.get(op_name, 0)
	ops_done[op_name] = n + 1


## Counts a refused request; returns how many were refused for `why` so far.
func count_refused(why: String) -> int:
	var n: int = ops_refused.get(why, 0)
	n += 1
	ops_refused[why] = n
	return n


## Notes an action shown at host tick `t` (with its frames so far): counts each start once.
func note_action(action: int, action_tick: int, t: float) -> void:
	if action < 0:
		_last_action = -1
		return
	var start: float = t - action_tick
	if action != _last_action or absf(start - _last_action_start) > 1.5:
		var name: String = RigData.ANIM_NAMES[action]
		var n: int = actions_seen.get(name, 0)
		actions_seen[name] = n + 1
	_last_action = action
	_last_action_start = start
