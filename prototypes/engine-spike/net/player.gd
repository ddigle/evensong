extends Node2D
## One player of the net spike, created by the MultiplayerSpawner's spawn function (net_main.gd)
## on the host and on every client. The host simulates movement from the replicated input
## (box collision against the wall layer); everyone else only sees the position that
## "PositionSync" (authority = host) replicates.

const TileWorld := preload("res://net/tile_world.gd")
const PlayerInput := preload("res://net/player_input.gd")

const SPEED: float = 60.0
const HALF: Vector2 = Vector2(5.0, 5.0)

var peer_id: int = 1
var spawn_index: int = 0
var spawn_cell: Vector2i = Vector2i.ZERO
## Host only: simulate movement against `world`.
var simulate: bool = false
var world: TileWorld = null
var input: PlayerInput = null
var position_sync: MultiplayerSynchronizer = null
var moved_last_tick: bool = false


## sync_mode: SceneReplicationConfig.REPLICATION_MODE_ALWAYS or _ON_CHANGE.
## sync_interval: seconds between position updates (0 = every network frame).
func setup(id: int, index: int, cell: Vector2i, sync_mode: int, sync_interval: float) -> void:
	peer_id = id
	spawn_index = index
	spawn_cell = cell
	name = str(id)
	position = TileWorld.cell_center(cell)

	var body: ColorRect = ColorRect.new()
	body.name = "Body"
	body.size = Vector2(10.0, 12.0)
	body.position = Vector2(-5.0, -8.0)
	body.color = color_for(id)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)

	position_sync = MultiplayerSynchronizer.new()
	position_sync.name = "PositionSync"
	position_sync.root_path = NodePath("..")
	var path: NodePath = NodePath(".:position")
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, sync_mode as SceneReplicationConfig.ReplicationMode)
	position_sync.replication_config = config
	position_sync.replication_interval = sync_interval
	position_sync.delta_interval = sync_interval
	add_child(position_sync)

	input = PlayerInput.new()
	input.setup(id, sync_interval)
	add_child(input)


static func color_for(id: int) -> Color:
	return Color.from_hsv(fmod(float(id % 9973) * 0.618034, 1.0), 0.55, 0.95)


func _physics_process(delta: float) -> void:
	if not simulate or world == null:
		moved_last_tick = false
		return
	var before: Vector2 = position
	var dir: Vector2 = input.direction.limit_length(1.0)
	if dir != Vector2.ZERO:
		var step: Vector2 = dir * SPEED * delta
		var next_x: Vector2 = position + Vector2(step.x, 0.0)
		if not world.box_hits_wall(next_x, HALF):
			position = next_x
		var next_y: Vector2 = position + Vector2(0.0, step.y)
		if not world.box_hits_wall(next_y, HALF):
			position = next_y
	moved_last_tick = position != before
