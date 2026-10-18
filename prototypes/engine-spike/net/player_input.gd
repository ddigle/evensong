extends MultiplayerSynchronizer
## Input of one player (child "Input" of the player). Its multiplayer authority is the owning
## peer, so the owner writes `direction` and this synchronizer sends it to the host only
## (ON_CHANGE: reliable, only when it changes). The host simulates; the input never goes to
## other clients.

var direction: Vector2 = Vector2.ZERO


func setup(owner_peer: int, interval: float) -> void:
	name = "Input"
	root_path = NodePath(".")
	var path: NodePath = NodePath(".:direction")
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(path)
	config.property_set_spawn(path, false)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	replication_config = config
	delta_interval = interval
	public_visibility = false
	set_visibility_for(1, true)
	set_multiplayer_authority(owner_peer)
