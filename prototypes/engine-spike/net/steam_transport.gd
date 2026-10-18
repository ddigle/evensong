extends "res://net/net_transport.gd"
## Steam transport placeholder: GodotSteam's SteamMultiplayerPeer (Steam Networking Sockets,
## Valve relay = no NAT problems). Not installed in the spike; this file only shows that the
## swap is one class. Everything goes through ClassDB/call() so the script parses without
## GodotSteam. Steam must be initialised before create_*(): either the project settings
## steam/initialization/processes/initialize_on_startup + embed_callbacks (GodotSteam 4.20+),
## or Steam.steamInitEx() by hand plus Steam.run_callbacks() every frame.
##
## GodotSteam API (checked 2026-10-18 against godotsteam.com/classes/multiplayer_peer and the
## godot4 branch source, GodotSteam 4.23 = Godot 4.7.2 builds, GDExtension 4.23.1 = Godot 4.4+):
##   create_host(virtual_port = 0)              host_with_lobby(lobby_id)
##   create_client(steam_id, virtual_port = 0)  connect_to_lobby(lobby_id)
## Differences from ENet that matter here (see notes/net.md):
## - the peer's server_relay property is false by default, so clients cannot reach each other
##   through the host. The net spike never needs that (run the test with --net-relay=off).
## - there is no max-clients argument: the host has to refuse a tenth player itself.
## - TRANSFER_MODE_UNRELIABLE_ORDERED is sent reliable. Channels: project setting
##   steam/multiplayer_peer/max_channels (default 4; the spike uses 0 and 1).

const PEER_CLASS: StringName = &"SteamMultiplayerPeer"


func kind() -> String:
	return "steam"


func is_available() -> bool:
	return ClassDB.class_exists(PEER_CLASS) and Engine.has_singleton("Steam")


func create_host(port: int, _max_clients: int) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	var steam_peer: MultiplayerPeer = ClassDB.instantiate(PEER_CLASS) as MultiplayerPeer
	var err: int = steam_peer.call("create_host", port)
	if err != OK:
		return err as Error
	peer = steam_peer
	return OK


## address = the host's Steam ID (64-bit, as text).
func create_client(address: String, port: int) -> Error:
	if not is_available():
		return ERR_UNAVAILABLE
	if not address.is_valid_int():
		return ERR_INVALID_PARAMETER
	var steam_peer: MultiplayerPeer = ClassDB.instantiate(PEER_CLASS) as MultiplayerPeer
	var err: int = steam_peer.call("create_client", address.to_int(), port)
	if err != OK:
		return err as Error
	peer = steam_peer
	return OK
