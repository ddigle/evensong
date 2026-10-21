class_name SteamTransport
extends NetTransport
## Steam transport placeholder (Steam is not part of M1). Without GodotSteam it reports
## "unavailable" by signal; with GodotSteam installed it still reports that M1 has no Steam flow.
##
## Notes for the stage that adds Steam (spike notes/net.md "GodotSteam 호환", checked 2026-10-18:
## GodotSteam 4.23 builds for Godot 4.7.2, GDExtension 4.23.1 for any Godot >= 4.4):
## - SteamMultiplayerPeer: create_host(virtual_port), create_client(steam_id, virtual_port),
##   host_with_lobby(lobby_id), connect_to_lobby(lobby_id). The lobby is created or joined first
##   (asynchronous callbacks), which is why host()/join() report by signal.
## - It has no max-clients argument: the host refuses a tenth player itself (net/roster.gd does
##   that for every transport already).
## - TRANSFER_MODE_UNRELIABLE_ORDERED is sent reliable; channels come from the project setting
##   steam/multiplayer_peer/max_channels (the session uses 0..2).
## - Steam must be initialised first (initialize_on_startup + embed_callbacks, or steamInitEx()
##   and run_callbacks() every frame).

const PEER_CLASS: StringName = &"SteamMultiplayerPeer"


func kind() -> String:
	return "steam"


func is_available() -> bool:
	return ClassDB.class_exists(PEER_CLASS) and Engine.has_singleton("Steam")


func host(p_api: MultiplayerAPI) -> void:
	api = p_api
	state = State.OPENING
	_fail.call_deferred(_why_not())


func join(p_api: MultiplayerAPI) -> void:
	api = p_api
	state = State.OPENING
	_fail.call_deferred(_why_not())


func _why_not() -> String:
	if not is_available():
		return "unavailable: GodotSteam is not installed in this build"
	return "unavailable: the Steam lobby flow is not part of M1"
