class_name NetTransport
extends RefCounted
## Transport interface (spike RESULTS §6: keep the transport swappable, configure it through one
## object, report connecting by signal so a Steam lobby flow fits later).
##
## Game code talks only to Godot's high-level multiplayer (SceneMultiplayer RPCs on NetSession).
## A transport creates the MultiplayerPeer underneath, puts it on the given MultiplayerAPI and
## says by signal when that API is usable:
##   host(api)  -> `opened` once the host listens, or `open_failed(reason)`
##   join(api)  -> `opened` once connected to the host, or `open_failed(reason)`
## Both signals are emitted later (never inside host()/join()), at most once per call.
## The player cap (Config.MAX_PLAYERS) is NOT the transport's job: the host counts players
## (net/roster.gd); `Options.peer_limit` only bounds raw connections.
##
## Implementations: EnetTransport (built in), SteamTransport (placeholder until GodotSteam is
## installed). Pick one by name with Transports.make().

signal opened
signal open_failed(reason: String)

## Settings for host()/join(). `address` is transport specific (an IP or host name for ENet, a
## Steam ID or lobby ID for Steam); `port` is a UDP port for ENet, a virtual port for Steam.
class Options:
	extends RefCounted
	var address: String = ""
	var port: int = Config.DEFAULT_PORT
	var peer_limit: int = Config.NET_TRANSPORT_PEER_LIMIT


## Bytes and datagrams since the last pop_stats() call. -1 = the transport cannot tell.
## Bytes include the transport's own headers but not UDP/IP headers (28 B per IPv4 datagram).
class Stats:
	extends RefCounted
	var sent_bytes: int = -1
	var received_bytes: int = -1
	var sent_packets: int = -1


enum State { IDLE, OPENING, OPEN, FAILED, CLOSED }

var options: Options = Options.new()
var state: State = State.IDLE
var api: MultiplayerAPI


func kind() -> String:
	return "none"


## False when the transport cannot work in this build (e.g. GodotSteam is not installed).
func is_available() -> bool:
	return false


func configure(opts: Options) -> void:
	options = opts


## Starts hosting on `p_api`. Result by signal.
func host(p_api: MultiplayerAPI) -> void:
	api = p_api
	_fail.call_deferred("%s transport cannot host" % kind())


## Starts joining a host on `p_api`. Result by signal.
func join(p_api: MultiplayerAPI) -> void:
	api = p_api
	_fail.call_deferred("%s transport cannot join" % kind())


func get_peer() -> MultiplayerPeer:
	return null


## True while a message to `peer_id` can still go out (connected, not on its way out). The session
## asks before each send so a peer that is disconnecting does not produce engine errors.
func can_send_to(peer_id: int) -> bool:
	return api != null and api.get_peers().has(peer_id)


func pop_stats() -> Stats:
	return Stats.new()


## Closes the peer and leaves `api` with an offline peer. Safe to call more than once.
func close() -> void:
	state = State.CLOSED


func _open() -> void:
	if state != State.OPENING:
		return
	state = State.OPEN
	opened.emit()


func _fail(reason: String) -> void:
	if state == State.OPEN or state == State.CLOSED or state == State.FAILED:
		return
	state = State.FAILED
	open_failed.emit(reason)
