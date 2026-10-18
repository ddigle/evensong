extends RefCounted
## Transport interface of the net spike. Game code talks only to Godot's high-level multiplayer
## (SceneMultiplayer: RPCs, MultiplayerSpawner, MultiplayerSynchronizer); a transport just
## creates and configures the MultiplayerPeer underneath. ENet (enet_transport.gd) is used now;
## Steam (steam_transport.gd, GodotSteam's SteamMultiplayerPeer) can replace it without
## touching anything else. Pick one with transports.gd.
##
## `address` is transport specific: an IP for ENet, a Steam ID (or lobby ID) for Steam.
## `port` is a UDP port for ENet, a virtual port for Steam.

var peer: MultiplayerPeer = null


func kind() -> String:
	return "none"


## False when the transport cannot work in this build (e.g. GodotSteam is not installed).
func is_available() -> bool:
	return false


func create_host(_port: int, _max_clients: int) -> Error:
	return ERR_UNAVAILABLE


func create_client(_address: String, _port: int) -> Error:
	return ERR_UNAVAILABLE


func get_peer() -> MultiplayerPeer:
	return peer


## Bytes the transport put on the wire since the last call (its own headers included,
## UDP/IP headers not), or -1 when it cannot tell.
func pop_sent_bytes() -> int:
	return -1


func pop_received_bytes() -> int:
	return -1


## Datagrams the transport sent since the last call, or -1. Each one also costs a UDP/IP
## header on the wire (28 bytes for IPv4) that pop_sent_bytes() does not count.
func pop_sent_packets() -> int:
	return -1


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
