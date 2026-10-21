class_name NetMember
extends RefCounted
## One player of a session: spawn slot, peer, class and the Player node in the world. The host
## gives a remote client's member an InputGate; a client gives every other player an Interpolation.

var slot: int = -1
## Peer id on the host (1 = the host itself); 0 on clients, which only know slots.
var peer_id: int = 0
var class_id: String = ""
var player: Player
## Host: input check of a remote client's frames.
var gate: InputGate
## Client: another player's received states.
var interp: Interpolation


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
	return s


func info() -> NetProtocol.PlayerInfo:
	var i: NetProtocol.PlayerInfo = NetProtocol.PlayerInfo.new()
	i.class_index = NetProtocol.class_index(class_id)
	i.state = state()
	return i
