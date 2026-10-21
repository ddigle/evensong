class_name Transports
extends RefCounted
## Transport factory: the only place that names concrete transports (--transport=<kind>).

const KINDS: PackedStringArray = ["enet", "steam"]
const DEFAULT_KIND: String = "enet"


## A new transport of `kind`, or null for an unknown kind.
static func make(kind: String) -> NetTransport:
	match kind:
		"enet":
			return EnetTransport.new()
		"steam":
			return SteamTransport.new()
	return null
