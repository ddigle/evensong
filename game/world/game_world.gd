class_name GameWorld
extends Node2D
## Root of scenes/world.tscn: the surface world of one seed (WorldData + chunked GroundView),
## a free camera (until players exist, stage G2) and the debug overlay (F3).

signal generated

## Generate in _ready from the --seed flag (Config.DEFAULT_SEED without it). Tests turn this off
## and call generate() themselves.
@export var auto_generate: bool = true

var data: WorldData
var generation_ms: float = 0.0
var view_ms: float = 0.0

@onready var ground: GroundView = $Ground
@onready var camera: FreeCamera = $FreeCamera
@onready var overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	if auto_generate:
		generate(CliOptions.current().world_seed)
		overlay.visible = CliOptions.current().overlay


func generate(world_seed: int, size: Vector2i = Config.MAP_SIZE) -> void:
	var t0: int = Time.get_ticks_usec()
	data = SurfaceGen.generate(world_seed, size)
	var t1: int = Time.get_ticks_usec()
	ground.setup(data)
	var t2: int = Time.get_ticks_usec()
	generation_ms = (t1 - t0) / 1000.0
	view_ms = (t2 - t1) / 1000.0
	camera.bounds = map_rect_px()
	camera.position = camera.clamp_to_bounds(data.altar_center_px())
	camera.reset_smoothing()
	overlay.setup(data)
	generated.emit()


## Sets the floor terrain at vertex v; returns the redrawn display cells (see GroundView).
func set_terrain(v: Vector2i, terrain: int) -> Array[Vector2i]:
	return ground.set_terrain(v, terrain)


func map_rect_px() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(data.size * Config.TILE))
