class_name Roster
extends RefCounted
## Host-side list of the players in a session: peer id -> spawn slot and class.
##
## ● at most Config.MAX_PLAYERS (9) players, the host included (game-concept §7 R11). The host
## counts here, not the transport (spike RESULTS §6: Steam peers have no client limit, and a
## transport-level refusal cannot tell the joiner why). `max_players` can only be lowered (tests use
## a small cap so a refusal needs few processes).
## Slots index Config.SPAWN_SLOTS. A joiner gets the lowest free slot, so a slot freed by a player
## who left is used again (the spike numbered joins upwards and put a tenth join on the host's spot).

var max_players: int = Config.MAX_PLAYERS
var _slot_of: Dictionary[int, int] = {}
var _class_of: Dictionary[int, String] = {}


func _init(p_max_players: int = Config.MAX_PLAYERS) -> void:
	max_players = clampi(p_max_players, 1, Config.MAX_PLAYERS)


func count() -> int:
	return _slot_of.size()


func is_full() -> bool:
	return count() >= max_players


func has(peer_id: int) -> bool:
	return _slot_of.has(peer_id)


## Why `class_id` cannot join now (NetProtocol.Refusal.NONE = it can).
func refusal_for(class_id: String) -> NetProtocol.Refusal:
	if not Config.CLASSES.has(class_id):
		return NetProtocol.Refusal.CLASS
	if is_full():
		return NetProtocol.Refusal.FULL
	if Config.NET_UNIQUE_CLASSES and _class_of.values().has(class_id):
		return NetProtocol.Refusal.CLASS_TAKEN
	return NetProtocol.Refusal.NONE


## Adds a player and returns its slot, or -1 when refused (see refusal_for) or already in.
func admit(peer_id: int, class_id: String) -> int:
	if has(peer_id) or refusal_for(class_id) != NetProtocol.Refusal.NONE:
		return -1
	var slot: int = lowest_free_slot()
	_slot_of[peer_id] = slot
	_class_of[peer_id] = class_id
	return slot


## Removes a player; returns the freed slot or -1 if the peer was not in.
func release(peer_id: int) -> int:
	if not has(peer_id):
		return -1
	var slot: int = _slot_of[peer_id]
	_slot_of.erase(peer_id)
	_class_of.erase(peer_id)
	return slot


func slot_of(peer_id: int) -> int:
	return _slot_of.get(peer_id, -1)


func class_of(peer_id: int) -> String:
	return _class_of.get(peer_id, "")


## Peer on `slot`, 0 if free.
func peer_at(slot: int) -> int:
	for peer_id: int in _slot_of:
		if _slot_of[peer_id] == slot:
			return peer_id
	return 0


## Admitted peers, by slot.
func peers() -> Array[int]:
	var out: Array[int] = []
	out.assign(_slot_of.keys())
	out.sort_custom(func(a: int, b: int) -> bool: return _slot_of[a] < _slot_of[b])
	return out


func lowest_free_slot() -> int:
	var used: Array[int] = []
	used.assign(_slot_of.values())
	for slot: int in Config.MAX_PLAYERS:
		if not used.has(slot):
			return slot
	return -1
