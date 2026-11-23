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

## M13b: ● one player per class at a time (Config.NET_UNIQUE_CLASSES, R54): a class a connected player holds (the host's own player
## included: it is admitted here too, peer 1) is refused as CLASS_TAKEN; releasing a player frees its class. `allow_duplicates` (test
## only, --test-duplicate-classes: the 9-player structure needs more players than the slice's classes) turns the rule off.
var max_players: int = Config.MAX_PLAYERS
var allow_duplicates: bool = false
var _slot_of: Dictionary[int, int] = {}
var _class_of: Dictionary[int, String] = {}


func _init(p_max_players: int = Config.MAX_PLAYERS, p_allow_duplicates: bool = false) -> void:
	max_players = clampi(p_max_players, 1, Config.MAX_PLAYERS)
	allow_duplicates = p_allow_duplicates


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
	if unique_classes() and _class_of.values().has(class_id):
		return NetProtocol.Refusal.CLASS_TAKEN
	return NetProtocol.Refusal.NONE


## M13b: whether a class may be held by one player only now (● R54, unless the test flag allows duplicates).
func unique_classes() -> bool:
	return Config.NET_UNIQUE_CLASSES and not allow_duplicates


## M13b: the classes the admitted players hold now (Config.CLASSES order, each once): what a CLASS_TAKEN refusal tells the joiner.
func taken_classes() -> PackedStringArray:
	var out: PackedStringArray = []
	for c: String in Config.CLASSES:
		if _class_of.values().has(c):
			out.append(c)
	return out


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
