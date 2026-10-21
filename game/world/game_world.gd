class_name GameWorld
extends Node2D
## Root of scenes/world.tscn: the surface world of one seed and what stands on it.
##   Ground        GroundView (chunked dual grid floor)
##   Entities      y-sorted by feet: the Altar (created by generate()), the gatherables and drops
##                 (ItemView, M2b) and the characters that scenes add (main.tscn adds the players)
##   Lighting      evening darkness + the altar light (F4 toggles, --no-evening starts off)
##   DebugOverlay  F3
##   FreeCamera    map viewer camera; removed when `free_camera` is off (main.tscn uses PlayerCamera)
##
## is_in_safe_zone() is the one safe-zone rule (light/safe_zone.gd); the altar light textures are
## built from the same SafeZone.

signal generated

## Generate in _ready from the --seed flag (Config.DEFAULT_SEED without it). Tests turn this off
## and call generate() themselves.
@export var auto_generate: bool = true
## Keep the free camera (world.tscn on its own). main.tscn turns it off.
@export var free_camera: bool = true

var data: WorldData
var safe_zone: SafeZone
var altar: Altar
## Gatherables and drops (M2b, world/item_view.gd).
var items: ItemView
var generation_ms: float = 0.0
var view_ms: float = 0.0

@onready var ground: GroundView = $Ground
@onready var entities: Node2D = $Entities
@onready var lighting: Lighting = $Lighting
@onready var overlay: DebugOverlay = $DebugOverlay
@onready var camera: FreeCamera = $FreeCamera


func _ready() -> void:
	if not free_camera:
		remove_child(camera)
		camera.free()
		camera = null
	if auto_generate:
		generate(CliOptions.current().world_seed)
		overlay.visible = CliOptions.current().overlay
		lighting.set_evening(not CliOptions.current().no_evening)


func generate(world_seed: int, size: Vector2i = Config.MAP_SIZE) -> void:
	var t0: int = Time.get_ticks_usec()
	var generated_data: WorldData = SurfaceGen.generate(world_seed, size)
	generation_ms = (Time.get_ticks_usec() - t0) / 1000.0
	load_data(generated_data)


## Shows `p_data` (generated here, or a late joiner's world received from the host): draws the
## ground, places the altar and its light, resets the free camera and the overlay.
func load_data(p_data: WorldData) -> void:
	data = p_data
	var t1: int = Time.get_ticks_usec()
	ground.setup(data)
	view_ms = (Time.get_ticks_usec() - t1) / 1000.0
	safe_zone = SafeZone.for_world(data)
	_place_altar()
	if items == null:
		items = ItemView.new(entities)
	items.setup(data)
	lighting.setup(safe_zone, lighting.evening_on)
	if camera != null:
		camera.bounds = map_rect_px()
		camera.position = camera.clamp_to_bounds(data.altar_center_px())
		camera.reset_smoothing()
	overlay.setup(data)
	generated.emit()


func _place_altar() -> void:
	if altar != null:
		entities.remove_child(altar)
		altar.free()
		altar = null
	if not data.altar_rect.has_area():
		return
	altar = Altar.new()
	altar.name = &"Altar"
	altar.setup(data.altar_rect)
	entities.add_child(altar)
	entities.move_child(altar, 0)


## THE safe-zone rule for game logic (the light shows the same zone).
func is_in_safe_zone(pos: Vector2) -> bool:
	return safe_zone != null and safe_zone.is_in_safe_zone(pos)


## Feet position of spawn slot i (Config.SPAWN_SLOTS, around the altar).
func spawn_point(slot: int) -> Vector2:
	return data.altar_center_px() + Vector2(Config.SPAWN_SLOTS[slot % Config.SPAWN_SLOTS.size()])


## Sets the floor terrain at vertex v; returns the redrawn display cells (see GroundView).
func set_terrain(v: Vector2i, terrain: int) -> Array[Vector2i]:
	return ground.set_terrain(v, terrain)


## Applies a world edit the host has checked (net/edit_log.gd) and redraws what it touches. The host
## and every client apply edits through here, so the same log gives the same world. False when the
## edit does not fit the data.
func apply_edit(edit: EditLog.WorldEdit) -> bool:
	if not EditLog.apply_to_data(data, edit):
		return false
	match edit.kind:
		EditLog.Kind.DROP_PUT, EditLog.Kind.DROP_REMOVE:
			items.update_drop(edit.drop_id)
		_:
			if edit.layer == WorldData.Layer.FLOOR:
				ground.redraw_vertex(edit.cell)
			elif edit.layer == WorldData.Layer.VEGETATION:
				items.update_cell(edit.cell)
	return true


func map_rect_px() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(data.size * Config.TILE))
