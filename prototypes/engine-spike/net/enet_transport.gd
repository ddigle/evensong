extends "res://net/net_transport.gd"
## ENet transport (built into Godot): ENetMultiplayerPeer over UDP. Byte counts come from
## ENetConnection host statistics (ENet headers included, UDP/IP headers not).

## One of ENetConnection.COMPRESS_*. Host and clients must use the same mode.
var compression: int = ENetConnection.COMPRESS_NONE


func kind() -> String:
	return "enet"


func is_available() -> bool:
	return true


func create_host(port: int, max_clients: int) -> Error:
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = enet.create_server(port, max_clients)
	if err != OK:
		return err
	enet.host.compress(compression as ENetConnection.CompressionMode)
	peer = enet
	return OK


func create_client(address: String, port: int) -> Error:
	var enet: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = enet.create_client(address, port)
	if err != OK:
		return err
	enet.host.compress(compression as ENetConnection.CompressionMode)
	peer = enet
	return OK


func _connection() -> ENetConnection:
	var enet: ENetMultiplayerPeer = peer as ENetMultiplayerPeer
	if enet == null:
		return null
	return enet.host


func pop_sent_bytes() -> int:
	var host: ENetConnection = _connection()
	if host == null:
		return -1
	return int(host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))


func pop_received_bytes() -> int:
	var host: ENetConnection = _connection()
	if host == null:
		return -1
	return int(host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))


func pop_sent_packets() -> int:
	var host: ENetConnection = _connection()
	if host == null:
		return -1
	return int(host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS))
