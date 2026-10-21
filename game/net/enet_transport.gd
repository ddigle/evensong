class_name EnetTransport
extends NetTransport
## ENet transport (built into Godot): ENetMultiplayerPeer over UDP. The host binds every interface
## (LAN, Tailscale 100.x). Byte counts come from ENetConnection statistics. Every connection gets
## Config.NET_ENET_THROTTLE (ENet's packet throttle never lowers, so it never drops state batches).

var _peer: ENetMultiplayerPeer


func kind() -> String:
	return "enet"


func is_available() -> bool:
	return true


func host(p_api: MultiplayerAPI) -> void:
	api = p_api
	state = State.OPENING
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(options.port, options.peer_limit)
	if err != OK:
		_fail.call_deferred("cannot listen on port %d (%s)" % [options.port, error_string(err)])
		return
	_peer = peer
	peer.peer_connected.connect(_configure_peer)
	api.multiplayer_peer = peer
	_open.call_deferred()


func join(p_api: MultiplayerAPI) -> void:
	api = p_api
	state = State.OPENING
	if options.address.is_empty():
		_fail.call_deferred("no address to join")
		return
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(options.address, options.port)
	if err != OK:
		_fail.call_deferred("cannot connect to %s:%d (%s)" % [options.address, options.port, error_string(err)])
		return
	_peer = peer
	api.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	api.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	api.multiplayer_peer = peer


func get_peer() -> MultiplayerPeer:
	return _peer


func can_send_to(peer_id: int) -> bool:
	if _peer == null or not super.can_send_to(peer_id):
		return false
	var p: ENetPacketPeer = _peer.get_peer(peer_id)
	return p != null and p.get_state() == ENetPacketPeer.STATE_CONNECTED


func pop_stats() -> Stats:
	var s: Stats = Stats.new()
	if _peer == null or _peer.host == null:
		return s
	s.sent_bytes = int(_peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA))
	s.received_bytes = int(_peer.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA))
	s.sent_packets = int(_peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS))
	return s


func close() -> void:
	if api != null:
		if api.connected_to_server.is_connected(_on_connected):
			api.connected_to_server.disconnect(_on_connected)
		if api.connection_failed.is_connected(_on_connection_failed):
			api.connection_failed.disconnect(_on_connection_failed)
		if _peer != null and api.multiplayer_peer == _peer:
			api.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _peer != null:
		_peer.close()
	_peer = null
	state = State.CLOSED


func _on_connected() -> void:
	if api.connection_failed.is_connected(_on_connection_failed):
		api.connection_failed.disconnect(_on_connection_failed)
	_configure_peer(1)
	_open()


## A new connection (the host's to a client, a client's to the host): Config.NET_ENET_THROTTLE.
func _configure_peer(peer_id: int) -> void:
	if _peer == null:
		return
	var p: ENetPacketPeer = _peer.get_peer(peer_id)
	if p != null:
		var t: Vector3i = Config.NET_ENET_THROTTLE
		p.throttle_configure(t.x, t.y, t.z)


func _on_connection_failed() -> void:
	if api.connected_to_server.is_connected(_on_connected):
		api.connected_to_server.disconnect(_on_connected)
	_fail("could not reach %s:%d" % [options.address, options.port])
