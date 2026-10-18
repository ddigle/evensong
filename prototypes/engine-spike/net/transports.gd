extends RefCounted
## Transport factory: "enet" (default) or "steam". The rest of the net module never names a
## concrete peer class.

const EnetTransport := preload("res://net/enet_transport.gd")
const SteamTransport := preload("res://net/steam_transport.gd")
const NetTransport := preload("res://net/net_transport.gd")

const KINDS: PackedStringArray = ["enet", "steam"]


## Returns null for an unknown kind.
static func make(kind: String) -> NetTransport:
	match kind:
		"enet":
			return EnetTransport.new()
		"steam":
			return SteamTransport.new()
	return null


## "none" | "range" | "fastlz" | "zlib" | "zstd" -> ENetConnection.COMPRESS_*, -1 if unknown.
static func enet_compression(mode: String) -> int:
	match mode:
		"none":
			return ENetConnection.COMPRESS_NONE
		"range":
			return ENetConnection.COMPRESS_RANGE_CODER
		"fastlz":
			return ENetConnection.COMPRESS_FASTLZ
		"zlib":
			return ENetConnection.COMPRESS_ZLIB
		"zstd":
			return ENetConnection.COMPRESS_ZSTD
	return -1
